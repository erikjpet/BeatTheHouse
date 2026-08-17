class_name CharacterChainModel
extends RefCounted

# Data-driven, run-local sequencing support for optional character chains.
# Progress remains authoritative in RunState.story_flags; this model only
# selects deterministic world anchors and projects eligible event fixtures.

const DATA_PATH := "res://data/story/character_chains.json"
const INJECTED_EVENT_IDS_KEY := "character_chain_event_ids"
const INJECTED_AMBIENT_LINE_KEY := "character_chain_ambient_line"
const SAL_TARGET_PREFIX := "chain06_sal_target_"
const DAVE_RUMOR_ID := "character_chain:dave_true_stop"

static var _data_cache: Dictionary = {}


static func data() -> Dictionary:
	if _data_cache.is_empty():
		_data_cache = _load_dictionary(DATA_PATH)
	return _data_cache.duplicate(true)


static func chains() -> Array:
	return _dictionary_array(data().get("chains", []))


static func tuning() -> Dictionary:
	return _dictionary(data().get("tuning", {})).duplicate(true)


static func apply_to_environment(run_state: RunState, environment: Dictionary) -> void:
	if run_state == null or environment.is_empty():
		return
	_ensure_run_anchors(run_state)
	_ensure_dave_true_rumor(run_state)
	var event_ids := _string_array(environment.get("event_ids", []))
	for prior_id in _string_array(environment.get(INJECTED_EVENT_IDS_KEY, [])):
		event_ids.erase(prior_id)
	var injected: Array = []
	for chain in chains():
		for beat in _dictionary_array(chain.get("beats", [])):
			if not _placement_matches(_dictionary(beat.get("placement", {})), environment):
				continue
			var event_id := str(beat.get("event_id", "")).strip_edges()
			if event_id.is_empty() or injected.has(event_id):
				continue
			injected.append(event_id)
			if not event_ids.has(event_id):
				event_ids.append(event_id)
	environment[INJECTED_EVENT_IDS_KEY] = injected
	environment["event_ids"] = event_ids
	_apply_cass_environment_effects(run_state, environment)
	_apply_rourke_staff_register(run_state, environment)


static func advance(run_state: RunState, amount: int) -> void:
	if run_state == null or amount <= 0:
		return
	var remaining_key := "chain06_cass_flameout_attention_remaining"
	if run_state.story_flags.has(remaining_key):
		var remaining := maxi(0, int(run_state.story_flags.get(remaining_key, 0)) - amount)
		run_state.set_story_flag(remaining_key, remaining)
		if remaining <= 0:
			run_state.set_story_flag("chain06_cass_flameout_attention_active", false)
			run_state.set_story_flag("chain06_cass_flameout_attention_expired", true)
	if not run_state.current_environment.is_empty():
		_apply_cass_environment_effects(run_state, run_state.current_environment)


static func scenario_weight_multiplier(run_state: RunState, archetype_id: String, scenario_id: String) -> float:
	if run_state == null:
		return 1.0
	if archetype_id == "pawn_shop" and scenario_id == "pawn_shop_sals_mood" \
			and bool(run_state.story_flags.get("chain06_sal_ending_changed", false)):
		return maxf(1.0, float(tuning().get("sal_mood_weight_multiplier", 1.75)))
	return 1.0


static func contextualize_choice(event_id: String, choice_data: Dictionary, run_state: RunState) -> Dictionary:
	if run_state == null:
		return choice_data
	var resolved := choice_data.duplicate(true)
	if event_id == "chain06_trio_rent_payoff":
		var memory := trio_gift_memory(run_state)
		var names := _string_array(memory.get("names", []))
		var phrase := "the nights you stayed" if names.is_empty() else ", ".join(names)
		resolved["text"] = str(resolved.get("text", "")).replace("{gift_memory}", phrase)
		resolved["trio_gift_memory"] = memory
	return resolved


static func trio_gift_memory(run_state: RunState) -> Dictionary:
	var definitions := [
		{"flag": "jazz_sax_coin_obtained", "name": "the sax coin"},
		{"flag": "jazz_cello_coin_obtained", "name": "the cello coin"},
		{"flag": "jazz_drummer_coin_obtained", "name": "the drummer's coin"},
		{"flag": "jazz_drummer_glasses_obtained", "name": "the drummer's glasses"},
	]
	var flags: Array = []
	var names: Array = []
	for definition in definitions:
		var flag_id := str(definition.get("flag", ""))
		if bool(run_state.narrative_flags.get(flag_id, run_state.story_flags.get(flag_id, false))):
			flags.append(flag_id)
			names.append(str(definition.get("name", flag_id)))
	return {"count": flags.size(), "flags": flags, "names": names}


static func resolve_lender_favor(run_state: RunState, lender_id: String, resolution: String) -> Dictionary:
	if run_state == null:
		return {"ok": false, "message": "No run is active."}
	return run_state.resolve_lender_favor(lender_id, resolution)


static func validation_errors(event_ids: Dictionary = {}) -> Array:
	var errors: Array = []
	var seen_chains := {}
	var seen_beats := {}
	for chain in chains():
		var chain_id := str(chain.get("id", "")).strip_edges()
		var prefix := str(chain.get("flag_prefix", "")).strip_edges()
		if chain_id.is_empty() or seen_chains.has(chain_id):
			errors.append("character chain has a missing or duplicate id: %s" % chain_id)
		seen_chains[chain_id] = true
		if prefix.is_empty():
			errors.append("character chain %s is missing flag_prefix." % chain_id)
		for beat in _dictionary_array(chain.get("beats", [])):
			var beat_id := str(beat.get("id", "")).strip_edges()
			var event_id := str(beat.get("event_id", "")).strip_edges()
			var compound := "%s:%s" % [chain_id, beat_id]
			if beat_id.is_empty() or seen_beats.has(compound):
				errors.append("character chain %s has a missing or duplicate beat id: %s" % [chain_id, beat_id])
			seen_beats[compound] = true
			if event_id.is_empty() or not event_ids.is_empty() and not bool(event_ids.get(event_id, false)):
				errors.append("character chain %s beat %s references unknown event: %s" % [chain_id, beat_id, event_id])
			if _dictionary(beat.get("placement", {})).is_empty():
				errors.append("character chain %s beat %s needs explicit placement." % [chain_id, beat_id])
		for ending_flag in _string_array(chain.get("ending_flags", [])):
			if not ending_flag.begins_with(prefix):
				errors.append("character chain %s ending flag escapes prefix: %s" % [chain_id, ending_flag])
	return errors


static func _ensure_run_anchors(run_state: RunState) -> void:
	if bool(run_state.story_flags.get("chain06_world_anchors_seeded", false)):
		return
	var candidates: Array = []
	var nodes_value: Variant = run_state.world_map.get("nodes", [])
	if typeof(nodes_value) == TYPE_ARRAY:
		for node_value in nodes_value as Array:
			if typeof(node_value) != TYPE_DICTIONARY:
				continue
			var node: Dictionary = node_value
			var node_id := str(node.get("id", "")).strip_edges()
			var archetype_id := str(node.get("archetype_id", node_id)).strip_edges()
			if node_id.is_empty() or ["pawn_shop", "grand_casino", "apartment", "house", "motel_room"].has(archetype_id):
				continue
			candidates.append({"id": node_id, "score": _stable_hash("%s:sal:%s" % [run_state.seed_text, node_id])})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_score := int(a.get("score", 0))
		var b_score := int(b.get("score", 0))
		return a_score < b_score or a_score == b_score and str(a.get("id", "")) < str(b.get("id", ""))
	)
	var fallbacks := ["bar", "corner_store", "jazz_club"]
	for index in range(3):
		var target := str((candidates[index] as Dictionary).get("id", "")) if index < candidates.size() else str(fallbacks[index])
		run_state.set_story_flag("%s%d" % [SAL_TARGET_PREFIX, index + 1], target)
	run_state.set_story_flag("chain06_world_anchors_seeded", true)


static func _ensure_dave_true_rumor(run_state: RunState) -> void:
	if run_state.town_state == null or not run_state.rumor_fact(DAVE_RUMOR_ID).is_empty():
		return
	var state := run_state.traveler_state("dave_bus_regular")
	if state.is_empty():
		return
	var target_node := str(state.get("previous_node_id", state.get("node_id", ""))).strip_edges()
	if target_node.is_empty():
		return
	var scenario := run_state.scenario_for_node(target_node)
	if scenario.is_empty():
		return
	run_state.register_rumor_fact("scenario", DAVE_RUMOR_ID, {
		"target_node_id": target_node,
		"source_id": str(scenario.get("id", "")),
		"scenario_id": str(scenario.get("id", "")),
		"scenario_name": str(scenario.get("display_name", "tonight's business")),
		"character_chain": "dave",
	})


static func _apply_cass_environment_effects(run_state: RunState, environment: Dictionary) -> void:
	var security := _dictionary(environment.get("security_profile", {})).duplicate(true)
	security.erase("cass_chain_attention_delta")
	if bool(run_state.story_flags.get("chain06_cass_ending_truce", false)):
		security.erase("rival_table_attention_delta")
	elif bool(run_state.story_flags.get("chain06_cass_flameout_attention_active", false)) \
			and int(run_state.story_flags.get("chain06_cass_flameout_attention_remaining", 0)) > 0 \
			and str(environment.get("archetype_id", "")) in ["grand_casino", "grand_casino_high_limit", "grand_casino_cage"]:
		security["cass_chain_attention_delta"] = int(tuning().get("cass_flameout_attention_risk_delta", 1))
	environment["security_profile"] = security


static func _apply_rourke_staff_register(run_state: RunState, environment: Dictionary) -> void:
	var prior_line := str(environment.get(INJECTED_AMBIENT_LINE_KEY, ""))
	var ambient := _string_array(environment.get("layer_ambient_lines", []))
	if not prior_line.is_empty():
		ambient.erase(prior_line)
	var line := ""
	if str(environment.get("archetype_id", "")) in ["grand_casino", "grand_casino_high_limit", "grand_casino_cage"]:
		if bool(run_state.story_flags.get("chain06_rourke_expected", false)):
			line = "Staff hold the door. Rourke expected you."
		elif bool(run_state.story_flags.get("chain06_rourke_named", false)):
			line = "The floor says Rourke softly. Courtesy gets exact."
		elif bool(run_state.story_flags.get("chain06_rourke_noticed", false)):
			line = "Staff check your face against the book."
	if not line.is_empty():
		ambient.append(line)
	environment[INJECTED_AMBIENT_LINE_KEY] = line
	environment["layer_ambient_lines"] = ambient
	if not line.is_empty():
		environment["layer_ambient_line"] = line


static func _placement_matches(placement: Dictionary, environment: Dictionary) -> bool:
	var archetype_ids := _string_array(placement.get("archetype_ids", []))
	if not archetype_ids.is_empty() and not archetype_ids.has(str(environment.get("archetype_id", ""))):
		return false
	var layer_ids := _string_array(placement.get("layer_ids", []))
	return layer_ids.is_empty() or layer_ids.has(str(environment.get("current_layer_id", "")))


static func _stable_hash(text: String) -> int:
	var value := 2166136261
	for byte in text.to_utf8_buffer():
		value = int((value ^ int(byte)) * 16777619) & 0x7fffffff
	return value


static func _load_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}


static func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


static func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append(entry)
	return result


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		var text := str(entry).strip_edges()
		if not text.is_empty() and not result.has(text):
			result.append(text)
	return result
