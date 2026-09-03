extends RefCounted

# Permanent chain06_1 contract: authored inventory, deterministic anchoring,
# optional prefixes, all Cass endings, bounded effects, favor closure, gifts,
# staff register, true-rumor payoff, and save compatibility.

const CharacterChainModelScript := preload("res://scripts/core/character_chain_model.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")


static func check(library: ContentLibrary, failures: Array) -> void:
	_check_inventory(library, failures)
	_check_deterministic_world_anchors(failures)
	_check_cass_endings_and_bounds(library, failures)
	_check_scenario_itinerary_and_pressure_conditions(library, failures)
	_check_sal_and_trio_consumers(library, failures)
	_check_nico_favor_resolution(library, failures)
	_check_rourke_staff_register(failures)
	_check_dave_true_rumor(library, failures)
	_check_prefix_and_save_properties(library, failures)


static func _check_inventory(library: ContentLibrary, failures: Array) -> void:
	var chains := CharacterChainModelScript.chains()
	if chains.size() != 6:
		failures.append("Character chains must define exactly six chains, found %d." % chains.size())
	var expected := {"cass_venn": 5, "sal_estate_lot": 5, "nico_soft_loans": 3, "rourke_scouts": 3, "the_trio": 2, "dave_true_stories": 3}
	var seen := {}
	for chain in chains:
		var chain_id := str(chain.get("id", ""))
		seen[chain_id] = true
		var beats := _dict_array(chain.get("beats", []))
		if not expected.has(chain_id) or beats.size() != int(expected.get(chain_id, -1)):
			failures.append("Character chain %s has the wrong beat inventory: %d." % [chain_id, beats.size()])
		for beat in beats:
			var event_id := str(beat.get("event_id", ""))
			if library.event(event_id).is_empty():
				failures.append("Character chain beat %s references missing event %s." % [str(beat.get("id", "")), event_id])
	for chain_id in expected.keys():
		if not seen.has(chain_id):
			failures.append("Character chain inventory is missing %s." % chain_id)
	var tuning := CharacterChainModelScript.tuning()
	if int(tuning.get("cass_tipoff_heat", 999)) > 8 or int(tuning.get("cass_flameout_heat", 999)) > 4 \
			or int(tuning.get("cass_flameout_attention_actions", 999)) > 6:
		failures.append("Cass tuning exceeds the bounded release contract.")


static func _check_deterministic_world_anchors(failures: Array) -> void:
	var first := _world_run("CHAIN-ANCHORS")
	var twin := _world_run("CHAIN-ANCHORS")
	first.set_story_flag("chain06_sal_item_taken", true)
	twin.set_story_flag("chain06_sal_item_taken", true)
	var environment := _environment("bar", "bar", "bar_payday_rush")
	CharacterChainModelScript.apply_to_environment(first, environment)
	CharacterChainModelScript.apply_to_environment(twin, _environment("bar", "bar", "bar_payday_rush"))
	var targets: Array = []
	for index in range(1, 4):
		var key := "chain06_sal_target_%d" % index
		targets.append(str(first.story_flags.get(key, "")))
		if first.story_flags.get(key) != twin.story_flags.get(key):
			failures.append("Sal world anchors drifted for an identical seed at target %d." % index)
	var unique := {}
	for target in targets:
		unique[str(target)] = true
	if unique.size() != 3:
		failures.append("Sal's estate trail must select three distinct world venues: %s." % JSON.stringify(targets))
	environment = _environment(str(targets[0]), str(targets[0]), "")
	CharacterChainModelScript.apply_to_environment(first, environment)
	if not _strings(environment.get("event_ids", [])).has("chain06_sal_trail_one"):
		failures.append("Character-chain projection did not inject placed optional events.")


static func _check_cass_endings_and_bounds(library: ContentLibrary, failures: Array) -> void:
	var truce := _fresh_run("CASS-TRUCE")
	_resolve(library, truce, "chain06_cass_first_contact", "share_the_read")
	_resolve(library, truce, "chain06_cass_escalation", "take_the_mark")
	_resolve(library, truce, "chain06_cass_proposition", "split_the_town")
	if not bool(truce.story_flags.get("chain06_cass_ending_truce", false)):
		failures.append("Cass truce ending did not land.")
	var tipoff := _fresh_run("CASS-TIPOFF")
	_resolve(library, tipoff, "chain06_cass_first_contact", "share_the_read")
	_resolve(library, tipoff, "chain06_cass_escalation", "take_the_mark")
	_resolve(library, tipoff, "chain06_cass_proposition", "cross_her")
	var heat_before := tipoff.suspicion_level()
	_resolve(library, tipoff, "chain06_cass_tipoff", "take_the_burn")
	if not bool(tipoff.story_flags.get("chain06_cass_ending_tipoff", false)) or tipoff.suspicion_level() - heat_before > int(CharacterChainModelScript.tuning().get("cass_tipoff_heat", 8)):
		failures.append("Cass tip-off ending or bounded heat spike failed.")
	var flameout := _fresh_run("CASS-FLAMEOUT")
	_resolve(library, flameout, "chain06_cass_first_contact", "share_the_read")
	_resolve(library, flameout, "chain06_cass_escalation", "leave_it_clean")
	_resolve(library, flameout, "chain06_cass_proposition", "stay_clean")
	flameout.set_environment(_environment("grand_casino", "grand_casino", "grand_casino_gala_night"))
	heat_before = flameout.suspicion_level()
	_resolve(library, flameout, "chain06_cass_flameout", "watch_the_floor_close")
	if not bool(flameout.story_flags.get("chain06_cass_ending_flameout", false)) or flameout.suspicion_level() - heat_before > int(CharacterChainModelScript.tuning().get("cass_flameout_heat", 4)):
		failures.append("Cass flameout ending or bounded aftermath spike failed.")
	if int(_dict(flameout.current_environment.get("security_profile", {})).get("cass_chain_attention_delta", 0)) != 1:
		failures.append("Cass flameout did not project its bounded floor-attention window.")
	CharacterChainModelScript.advance(flameout, int(CharacterChainModelScript.tuning().get("cass_flameout_attention_actions", 6)))
	if bool(flameout.story_flags.get("chain06_cass_flameout_attention_active", true)) or int(_dict(flameout.current_environment.get("security_profile", {})).get("cass_chain_attention_delta", 0)) != 0:
		failures.append("Cass flameout floor-attention window did not expire.")


static func _check_scenario_itinerary_and_pressure_conditions(library: ContentLibrary, failures: Array) -> void:
	var run_state := _fresh_run("CHAIN-CONDITIONS")
	var estate := _environment("pawn_shop", "pawn_shop", "pawn_shop_estate_lot_day")
	var wrong_estate := _environment("pawn_shop", "pawn_shop", "pawn_shop_serial_check_day")
	if not _can_trigger(library, run_state, "chain06_sal_estate_item", estate) or _can_trigger(library, run_state, "chain06_sal_estate_item", wrong_estate):
		failures.append("Sal's opening beat escaped Estate Lot Day anchoring.")
	var weekly := _environment("motel", "motel", "motel_weekly_rates")
	var wrong_weekly := _environment("motel", "motel", "motel_stakeout")
	if not _can_trigger(library, run_state, "chain06_nico_weekly_door", weekly) or _can_trigger(library, run_state, "chain06_nico_weekly_door", wrong_weekly):
		failures.append("Nico's opening beat escaped Weekly Rates anchoring.")
	_set_traveler(run_state, "cass_rival_counter", "bar")
	var cass_here := _environment("bar", "bar", "bar_payday_rush")
	var cass_elsewhere := _environment("jazz_club", "jazz_club", "jazz_club_recording_night")
	if not _can_trigger(library, run_state, "chain06_cass_first_contact", cass_here) or _can_trigger(library, run_state, "chain06_cass_first_contact", cass_elsewhere):
		failures.append("Cass first contact ignored her authoritative itinerary position.")
	var grand := _environment("grand_casino", "grand_casino", "grand_casino_gala_night")
	run_state.bankroll = 124
	if _can_trigger(library, run_state, "chain06_rourke_noticed", grand):
		failures.append("Rourke noticed beat fired below both pressure bands.")
	run_state.bankroll = 125
	if not _can_trigger(library, run_state, "chain06_rourke_noticed", grand):
		failures.append("Rourke noticed beat did not fire on its winnings band.")


static func _check_sal_and_trio_consumers(library: ContentLibrary, failures: Array) -> void:
	var sal := _fresh_run("SAL-END")
	sal.set_story_flag("chain06_sal_trail_three_done", true)
	_resolve(library, sal, "chain06_sal_sellback", "leave_it_with_him")
	if not bool(sal.story_flags.get("chain06_sal_ending_changed", false)) \
			or CharacterChainModelScript.scenario_weight_multiplier(sal, "pawn_shop", "pawn_shop_sals_mood") <= 1.0:
		failures.append("Sal's ending did not weight his Mood scenario afterward.")
	var trio := _fresh_run("TRIO-MEMORY")
	trio.narrative_flags["jazz_sax_coin_obtained"] = true
	trio.narrative_flags["jazz_drummer_glasses_obtained"] = true
	var memory := CharacterChainModelScript.trio_gift_memory(trio)
	if int(memory.get("count", 0)) != 2 or not _strings(memory.get("names", [])).has("the drummer's glasses"):
		failures.append("The Trio did not remember every gift held this run.")
	trio.set_story_flag("chain06_trio_gifts_named", true)
	var module := EventModuleScript.new()
	module.setup(library.event("chain06_trio_rent_payoff"), library)
	var choice := module.choice("carry_the_hat", trio, _environment("jazz_club", "jazz_club", "jazz_club_rent_party"))
	if not str(choice.get("text", "")).contains("sax coin") or not str(choice.get("text", "")).contains("glasses"):
		failures.append("Rent Party payoff did not name the run's remembered gifts.")


static func _check_nico_favor_resolution(library: ContentLibrary, failures: Array) -> void:
	var honored := _fresh_run("NICO-HONOR")
	honored.set_story_flag("chain06_nico_cover_seen", true)
	honored.narrative_flags["debt_favor_owed"] = true
	honored.debt = [{"id": "motel_friend_note", "lender_id": "motel_friend", "balance": 24, "status": "overdue", "default_consequence": "favor_owed"}]
	var result := _resolve(library, honored, "chain06_nico_favor_call", "carry_the_box")
	if not bool(honored.story_flags.get("chain06_nico_favor_honored", false)) or not honored.debt.is_empty() \
			or not bool(_dict(result.get("lender_favor_result", {})).get("ok", false)):
		failures.append("Nico's honored favor did not clear the dangling soft note.")
	var refused := _fresh_run("NICO-REFUSE")
	refused.set_story_flag("chain06_nico_cover_seen", true)
	refused.narrative_flags["debt_favor_owed"] = true
	refused.debt = [{"id": "motel_friend_note", "lender_id": "motel_friend", "balance": 24, "status": "overdue", "default_consequence": "favor_owed"}]
	_resolve(library, refused, "chain06_nico_favor_call", "leave_him_the_note")
	var note := _dict(refused.debt[0]) if not refused.debt.is_empty() else {}
	if str(note.get("default_consequence", "")) != "forced_repayment" or int(note.get("turns_remaining", 0)) != 2:
		failures.append("Nico's refused favor did not become a bounded ordinary note.")


static func _check_rourke_staff_register(failures: Array) -> void:
	var run_state := _fresh_run("ROURKE-REGISTER")
	var environment := _environment("grand_casino", "grand_casino", "grand_casino_gala_night")
	for stage in ["noticed", "named", "expected"]:
		run_state.set_story_flag("chain06_rourke_%s" % stage, true)
		CharacterChainModelScript.apply_to_environment(run_state, environment)
		var line := str(environment.get("character_chain_ambient_line", ""))
		if line.is_empty() or stage == "named" and not line.contains("Rourke") or stage == "expected" and not line.contains("expected"):
			failures.append("Rourke staff register did not recolor the %s stage." % stage)


static func _check_dave_true_rumor(library: ContentLibrary, failures: Array) -> void:
	var run_state := _world_run("DAVE-TRUE")
	run_state.town_state.seed_scenario_for_node("bar", {"id": "bar_wake", "archetype_id": "bar", "display_name": "The Wake"})
	run_state.register_rumor_fact("scenario", CharacterChainModelScript.DAVE_RUMOR_ID, {"target_node_id": "bar", "source_id": "bar_wake", "scenario_id": "bar_wake", "scenario_name": "The Wake"})
	run_state.set_story_flag("chain06_dave_last_stop", true)
	var environment := _environment("bar", "bar", "bar_wake")
	run_state.current_environment = environment
	var before := run_state.world_map.duplicate(true)
	_resolve(library, run_state, "chain06_dave_true_stop", "mark_the_true_stop")
	var heard := run_state.heard_rumor_for_node("bar")
	if heard.is_empty() or not run_state.town_state.rumor_trace_is_live(heard) or not bool(run_state.story_flags.get("chain06_dave_true_rumor_heard", false)):
		failures.append("Dave's useful story did not pay off as a live true rumor.")
	if JSON.stringify(before) == JSON.stringify(run_state.world_map):
		failures.append("Dave's true rumor did not upgrade the map's heard tier.")


static func _check_prefix_and_save_properties(library: ContentLibrary, failures: Array) -> void:
	for chain in CharacterChainModelScript.chains():
		var chain_id := str(chain.get("id", ""))
		var beats := _dict_array(chain.get("beats", []))
		var accumulated := {}
		for prefix_size in range(beats.size() + 1):
			var run_state := _fresh_run("PREFIX-%s-%d" % [chain_id, prefix_size])
			for key in accumulated.keys():
				run_state.set_story_flag(str(key), accumulated[key])
			var environment := _environment("bar", "bar", "bar_payday_rush")
			environment["event_ids"] = ["rowdy_regular"]
			CharacterChainModelScript.apply_to_environment(run_state, environment)
			if not _strings(environment.get("event_ids", [])).has("rowdy_regular") or run_state.is_terminal():
				failures.append("Character chain %s prefix %d blocked unrelated content or ended the run." % [chain_id, prefix_size])
			var restored := RunStateScript.new()
			restored.from_dict(run_state.to_dict())
			if JSON.stringify(restored.story_flags) != JSON.stringify(run_state.story_flags):
				failures.append("Character chain %s prefix %d did not survive save/load." % [chain_id, prefix_size])
			if prefix_size < beats.size():
				var event := library.event(str(beats[prefix_size].get("event_id", "")))
				for choice in _dict_array(_dict(event.get("payload", {})).get("choices", [])):
					for key in _dict(_dict(choice.get("consequences", {})).get("story_flags_set", {})).keys():
						accumulated[str(key)] = _dict(_dict(choice.get("consequences", {})).get("story_flags_set", {})).get(key)
	var legacy := _fresh_run("PRE-06")
	var legacy_data := legacy.to_dict()
	legacy_data.erase("story_flags")
	var migrated := RunStateScript.new()
	migrated.from_dict(legacy_data)
	if not migrated.story_flags.is_empty():
		failures.append("Pre-0.6 save migration invented character-chain progress.")


static func _resolve(library: ContentLibrary, run_state: RunState, event_id: String, choice_id: String) -> Dictionary:
	var definition := library.event(event_id)
	var conditions := _dict(definition.get("conditions", {}))
	var environment := run_state.current_environment.duplicate(true)
	var allowed_archetypes := _strings(conditions.get("archetype_ids", []))
	var archetype_id := str(environment.get("archetype_id", ""))
	if not allowed_archetypes.is_empty() and not allowed_archetypes.has(archetype_id):
		archetype_id = str(allowed_archetypes[0])
	if archetype_id.is_empty():
		var scopes := _strings(definition.get("scopes", []))
		archetype_id = "pawn_shop" if scopes.has("shop") else ("jazz_club" if scopes.has("club") else ("grand_casino" if scopes.has("boss") else "bar"))
	var node_id := str(environment.get("world_node_id", environment.get("id", archetype_id))).strip_edges()
	if node_id.is_empty() or str(environment.get("archetype_id", "")) != archetype_id:
		node_id = archetype_id
	var scenario_ids := _strings(conditions.get("scenario_ids", []))
	var scenario_id := str(environment.get("scenario_id", ""))
	if not scenario_ids.is_empty() and not scenario_ids.has(scenario_id):
		scenario_id = str(scenario_ids[0])
	environment["id"] = node_id
	environment["world_node_id"] = node_id
	environment["archetype_id"] = archetype_id
	environment["kind"] = "shop" if archetype_id in ["pawn_shop", "motel"] else ("club" if archetype_id in ["jazz_club", "kitty_cat_lounge"] else ("boss" if archetype_id == "grand_casino" else "casino"))
	environment["scenario_id"] = scenario_id
	environment["scenario_state"] = {"id": scenario_id}
	var event_ids := _strings(environment.get("event_ids", []))
	if not event_ids.has(event_id):
		event_ids.append(event_id)
	environment["event_ids"] = event_ids
	if not environment.has("resolved_event_ids"):
		environment["resolved_event_ids"] = []
	run_state.current_environment = environment
	for character_id in _strings(conditions.get("requires_traveler_here", [])):
		_set_traveler(run_state, character_id, node_id)
	var module := EventModuleScript.new()
	module.setup(definition, library)
	return module.resolve(run_state, run_state.current_environment, choice_id)


static func _can_trigger(library: ContentLibrary, run_state: RunState, event_id: String, environment: Dictionary) -> bool:
	var candidate := environment.duplicate(true)
	var ids := _strings(candidate.get("event_ids", []))
	if not ids.has(event_id):
		ids.append(event_id)
	candidate["event_ids"] = ids
	var module := EventModuleScript.new()
	module.setup(library.event(event_id), library)
	return module.can_trigger(run_state, candidate)


static func _fresh_run(seed: String) -> RunState:
	var run_state := RunStateScript.new()
	run_state.start_new(seed)
	return run_state


static func _world_run(seed: String) -> RunState:
	var run_state := _fresh_run(seed)
	var node_ids := ["bar", "corner_store", "jazz_club", "motel", "gas_station_casino", "delta_queen", "pawn_shop", "grand_casino"]
	var nodes: Array = []
	var edges: Array = []
	for index in range(node_ids.size()):
		var node_id := str(node_ids[index])
		nodes.append({"id": node_id, "archetype_id": node_id, "kind": "casino", "tier": 2, "state": "revealed", "seen": true, "environment": {}})
		if index > 0:
			edges.append({"a": str(node_ids[index - 1]), "b": node_id})
	run_state.set_world_map({"version": 3, "seed_text": seed, "start_node_id": "bar", "current_node_id": "bar", "nodes": nodes, "edges": edges, "visited_path": ["bar"]})
	run_state.configure_town_world(run_state.world_map)
	return run_state


static func _set_traveler(run_state: RunState, character_id: String, node_id: String) -> void:
	if run_state.town_state == null or run_state.town_state.living_world == null:
		return
	run_state.town_state.living_world.itinerary_schedules[character_id] = [{"node_id": node_id, "start_action": 0, "end_action": 999}]


static func _environment(archetype_id: String, node_id: String, scenario_id: String) -> Dictionary:
	return {
		"id": node_id,
		"archetype_id": archetype_id,
		"world_node_id": node_id,
		"kind": "shop" if archetype_id in ["pawn_shop", "motel", "jazz_club"] else ("boss" if archetype_id == "grand_casino" else "casino"),
		"tier": 2,
		"scenario_id": scenario_id,
		"scenario_state": {"id": scenario_id},
		"event_ids": [],
		"resolved_event_ids": [],
		"security_profile": {},
	}


static func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


static func _dict_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value as Array:
			if typeof(entry) == TYPE_DICTIONARY:
				result.append(entry)
	return result


static func _strings(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value as Array:
			var text := str(entry).strip_edges()
			if not text.is_empty() and not result.has(text):
				result.append(text)
	return result
