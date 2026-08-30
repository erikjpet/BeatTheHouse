extends RefCounted

# Wave-2 Tonight content contract. Launch-cut contracts remain separate; this
# guard validates only the appended backlog and then proves the full combined
# catalog is still reachable through the production selector.

const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const SEED_COUNT := 20
const AUTHORIZED_CATALOG_TOTAL := 55
const EVENT_CHOICE_LABEL_WIDTH_CEILING := 22
const LAUNCH_BY_ARCHETYPE := {
	"corner_store": ["corner_store_delivery_day", "corner_store_lotto_fever", "corner_store_aftermath", "corner_store_dead_shift"],
	"back_alley": ["back_alley_street_craps", "back_alley_cruiser_parked", "back_alley_fence_night"],
	"motel": ["motel_conventioneers", "motel_stakeout", "motel_weekly_rates"],
	"bar": ["bar_wake", "bar_fight_night", "bar_payday_rush", "bar_lock_in"],
	"gas_station_casino": ["gas_station_trucker_convoy", "gas_station_tour_bus_stop", "gas_station_graveyard_shift"],
	"small_underground_casino": ["punchline_open_mic_night", "punchline_headliner_night", "punchline_bringer_show", "punchline_high_stakes_night", "punchline_greased_week", "punchline_debt_court"],
	"jazz_club": ["jazz_club_guest_legend", "jazz_club_rent_party", "jazz_club_recording_night"],
	"kitty_cat_lounge": ["kitty_cat_lounge_amateur_night", "kitty_cat_lounge_buyout", "kitty_cat_lounge_slow_night"],
	"delta_queen": ["delta_queen_wedding_charter", "delta_queen_whale_aboard", "delta_queen_fog_delay", "delta_queen_engine_trouble"],
	"beach": ["beach_bonfire_night", "beach_storm_coming", "beach_festival_weekend"],
	"pawn_shop": ["pawn_shop_estate_lot_day", "pawn_shop_serial_check_day", "pawn_shop_sals_mood"],
	"grand_casino": ["grand_casino_gala_night", "grand_casino_convention_crowd", "grand_casino_audit_night"],
}
const BACKLOG_BY_ARCHETYPE := {
	"corner_store": ["corner_store_inventory_night"],
	"back_alley": ["back_alley_nothing_moving"],
	"motel": ["motel_wedding_overflow"],
	"bar": ["bar_darts_league_night", "bar_live_band", "bar_dead_tuesday"],
	"gas_station_casino": ["gas_station_road_crew_payday", "gas_station_storm_shelter"],
	"small_underground_casino": ["punchline_new_muscle", "punchline_raid_jitters"],
	"jazz_club": ["jazz_club_union_trouble"],
	"kitty_cat_lounge": ["kitty_cat_lounge_bachelorette_storm"],
	"delta_queen": ["delta_queen_captains_invitational"],
}
const PHASE_ARCS := {
	"bar_darts_league_night": ["league_play", "decider"],
	"gas_station_storm_shelter": ["gathering", "waiting_out", "clearing"],
	"delta_queen_captains_invitational": ["entry", "rounds", "final"],
}
const TIER1_ARCHETYPES := ["corner_store", "back_alley", "motel", "bar", "gas_station_casino"]
const TIER2_ARCHETYPES := ["small_underground_casino", "jazz_club", "kitty_cat_lounge", "delta_queen", "beach", "pawn_shop", "grand_casino"]


static func check(library: ContentLibrary, failures: Array) -> void:
	var backlog_ids := _backlog_ids()
	if backlog_ids.size() != 13:
		failures.append("Scenario backlog contract must declare exactly 13 scenarios.")
	_check_authorized_catalog(library, failures)
	var base_event_ids := _base_event_ids(library)
	var claimed_event_ids: Dictionary = {}
	for archetype_id_value in BACKLOG_BY_ARCHETYPE.keys():
		var archetype_id := str(archetype_id_value)
		var expected_ids: Array = BACKLOG_BY_ARCHETYPE.get(archetype_id, [])
		for scenario_id_value in expected_ids:
			_check_scenario(library, archetype_id, str(scenario_id_value), base_event_ids, claimed_event_ids, failures)
	if claimed_event_ids.size() != 13:
		failures.append("Scenario backlog must own exactly 13 unique exclusive events, found %d." % claimed_event_ids.size())
	_check_phase_arcs(library, failures)
	_check_weight_and_layer_seams(library, failures)
	_check_tutorial_neutrality(library, failures)
	_check_full_catalog_reach(library, failures)
	_check_launch_cut_reach(library, failures)


static func _check_scenario(library: ContentLibrary, archetype_id: String, scenario_id: String, base_event_ids: Dictionary, claimed_event_ids: Dictionary, failures: Array) -> void:
	var definition := library.scenario(scenario_id)
	if definition.is_empty() or str(definition.get("archetype_id", "")) != archetype_id:
		failures.append("Scenario backlog is missing %s under %s." % [scenario_id, archetype_id])
		return
	if bool(definition.get("placeholder", false)):
		failures.append("Scenario backlog entry %s is still a placeholder." % scenario_id)
	var mutations := _dict(definition.get("mutations", {}))
	if _mutation_axis_count(mutations) < 3:
		failures.append("Scenario backlog entry %s mutates fewer than three Tonight axes." % scenario_id)
	var presentation := _dict(mutations.get("presentation", {}))
	for key in ["palette_tint", "crowd_density", "signage_line"]:
		if str(presentation.get(key, "")).strip_edges().is_empty():
			failures.append("Scenario backlog entry %s is missing presentation.%s." % [scenario_id, key])
	if _dict(mutations.get("music_profile_override", {})).is_empty():
		failures.append("Scenario backlog entry %s has no authored music distinction." % scenario_id)
	if not _dict(mutations.get("hook_flags", {})).is_empty():
		failures.append("Scenario backlog entry %s invented a hook flag outside the roadmap catalog." % scenario_id)
	var event_ids := _strings(mutations.get("event_pool_add", []))
	if event_ids.size() < 1 or event_ids.size() > 3:
		failures.append("Scenario backlog entry %s must own one to three exclusive events." % scenario_id)
		return
	var opportunity_id := str(_dict(mutations.get("exclusive_opportunity", {})).get("event_id", ""))
	if opportunity_id.is_empty() or not event_ids.has(opportunity_id):
		failures.append("Scenario backlog entry %s does not guarantee one of its exclusive events." % scenario_id)
	var archetype := library.environment_archetype(archetype_id)
	var layer_id := str(definition.get("layer_id", "")).strip_edges()
	for event_id in event_ids:
		if not event_id.begins_with("scenario_"):
			failures.append("Scenario backlog event %s does not use the required scenario_ prefix." % event_id)
		if base_event_ids.has(event_id):
			failures.append("Scenario backlog event %s leaked into a base archetype pool." % event_id)
		if claimed_event_ids.has(event_id):
			failures.append("Scenario backlog event %s is shared by more than one authored scenario." % event_id)
		claimed_event_ids[event_id] = scenario_id
		_check_event(library, archetype, definition, layer_id, event_id, failures)


static func _check_event(library: ContentLibrary, archetype: Dictionary, scenario: Dictionary, layer_id: String, event_id: String, failures: Array) -> void:
	var event_definition := library.event(event_id)
	var choices := _array(_dict(event_definition.get("payload", {})).get("choices", []))
	if event_definition.is_empty() or str(event_definition.get("interaction_mode", "")) != "interactable" or choices.is_empty():
		failures.append("Scenario backlog event %s is not a usable interactable event." % event_id)
		return
	if not layer_id.is_empty() and not _strings(event_definition.get("scopes", [])).has(layer_id):
		failures.append("Layered scenario event %s is not scoped to %s." % [event_id, layer_id])
	var authored_environment: Dictionary = {}
	for candidate_layer in ["club", "casino"] if not layer_id.is_empty() else [""]:
		var generated := EnvironmentInstanceScript.from_archetype_layer(archetype, candidate_layer, 2, _run_rng("BACKLOG-LAYER-%s-%s" % [event_id, candidate_layer]), library, {}, scenario).to_dict() if not candidate_layer.is_empty() else EnvironmentInstanceScript.from_archetype(archetype, 1, _run_rng("BACKLOG-EVENT-%s" % event_id), library, {}, scenario).to_dict()
		var attached := _strings(generated.get("event_ids", [])).has(event_id)
		if (candidate_layer.is_empty() or candidate_layer == layer_id) and not attached:
			failures.append("Scenario backlog event %s did not attach to its authored environment." % event_id)
		elif candidate_layer.is_empty() or candidate_layer == layer_id:
			authored_environment = generated
		elif not candidate_layer.is_empty() and candidate_layer != layer_id and attached:
			failures.append("Scenario backlog event %s leaked from %s into %s." % [event_id, layer_id, candidate_layer])
	if not layer_id.is_empty():
		var back_room := EnvironmentInstanceScript.from_archetype_layer(archetype, "back_room", 2, _run_rng("BACKLOG-LAYER-%s-back-room" % event_id), library, {}, scenario).to_dict()
		if _strings(back_room.get("event_ids", [])).has(event_id):
			failures.append("Scenario backlog event %s leaked into the Punchline back room." % event_id)
	for choice_value in choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			failures.append("Scenario backlog event %s contains a malformed choice." % event_id)
			continue
		var choice := choice_value as Dictionary
		_check_choice_voice_and_width(event_id, choice, failures)
		var run_state := RunStateScript.new()
		run_state.start_new("BACKLOG-RESOLVE-%s-%s" % [event_id, str(choice.get("id", ""))])
		run_state.bankroll = 100
		run_state.set_environment(authored_environment.duplicate(true))
		var event_module := EventModuleScript.new()
		event_module.setup(event_definition, library)
		if not event_module.can_trigger(run_state, run_state.current_environment):
			failures.append("Scenario backlog event %s cannot trigger in its authored environment." % event_id)
			continue
		var result := event_module.resolve(run_state, run_state.current_environment, str(choice.get("id", "")))
		if not bool(result.get("ok", false)) or not _strings(run_state.current_environment.get("resolved_event_ids", [])).has(event_id):
			failures.append("Scenario backlog event %s choice %s did not resolve through EventModule." % [event_id, str(choice.get("id", ""))])


static func _check_authorized_catalog(library: ContentLibrary, failures: Array) -> void:
	var authorized: Dictionary = {}
	for archetype_id_value in LAUNCH_BY_ARCHETYPE.keys():
		var archetype_id := str(archetype_id_value)
		for scenario_id_value in LAUNCH_BY_ARCHETYPE.get(archetype_id, []):
			authorized[str(scenario_id_value)] = archetype_id
	for archetype_id_value in BACKLOG_BY_ARCHETYPE.keys():
		var archetype_id := str(archetype_id_value)
		for scenario_id_value in BACKLOG_BY_ARCHETYPE.get(archetype_id, []):
			var scenario_id := str(scenario_id_value)
			if authorized.has(scenario_id):
				failures.append("Scenario backlog id %s duplicates the authorized launch catalog." % scenario_id)
			authorized[scenario_id] = archetype_id
	if authorized.size() != AUTHORIZED_CATALOG_TOTAL:
		failures.append("Authorized scenario catalog declares %d ids; expected %d." % [authorized.size(), AUTHORIZED_CATALOG_TOTAL])
	var actual: Dictionary = {}
	for archetype_id_value in library.environment_scenarios.keys():
		var archetype_id := str(archetype_id_value)
		for definition_value in library.scenarios_for_archetype(archetype_id):
			if typeof(definition_value) != TYPE_DICTIONARY:
				continue
			var scenario_id := str((definition_value as Dictionary).get("id", ""))
			actual[scenario_id] = archetype_id
			if not authorized.has(scenario_id):
				failures.append("Scenario catalog contains unauthorized id %s under %s." % [scenario_id, archetype_id])
			elif str(authorized.get(scenario_id, "")) != archetype_id:
				failures.append("Scenario catalog places %s under %s; authorized archetype is %s." % [scenario_id, archetype_id, str(authorized.get(scenario_id, ""))])
	if actual.size() != AUTHORIZED_CATALOG_TOTAL:
		failures.append("Scenario catalog contains %d unique ids; expected the exact authorized %d." % [actual.size(), AUTHORIZED_CATALOG_TOTAL])
	for scenario_id_value in authorized.keys():
		if not actual.has(str(scenario_id_value)):
			failures.append("Scenario catalog is missing authorized id %s." % str(scenario_id_value))


static func _check_choice_voice_and_width(event_id: String, choice: Dictionary, failures: Array) -> void:
	var label := str(choice.get("label", ""))
	if label.length() > EVENT_CHOICE_LABEL_WIDTH_CEILING:
		failures.append("Scenario backlog event %s choice %s label exceeds the %d-character events.json ceiling." % [event_id, str(choice.get("id", "")), EVENT_CHOICE_LABEL_WIDTH_CEILING])
	var consequences := _dict(choice.get("consequences", {}))
	if not consequences.has("bankroll_delta"):
		return
	var amount := absi(int(consequences.get("bankroll_delta", 0)))
	var number_word := _number_word(amount)
	if number_word.is_empty():
		return
	var flavor := "%s %s" % [label, str(choice.get("text", ""))]
	var padded_flavor := " %s " % flavor.to_lower().replace(".", " ").replace(",", " ").replace("'", " ").replace("-", " ")
	if padded_flavor.contains(" %s " % number_word):
		failures.append("Scenario backlog event %s choice %s spells its exact bankroll amount in flavor prose." % [event_id, str(choice.get("id", ""))])


static func _number_word(value: int) -> String:
	var words := {
		1: "one",
		2: "two",
		3: "three",
		4: "four",
		5: "five",
		6: "six",
		7: "seven",
		8: "eight",
		9: "nine",
		10: "ten",
		11: "eleven",
		12: "twelve",
		13: "thirteen",
		14: "fourteen",
		15: "fifteen",
		20: "twenty",
	}
	return str(words.get(value, ""))


static func _check_phase_arcs(library: ContentLibrary, failures: Array) -> void:
	for scenario_id_value in PHASE_ARCS.keys():
		var scenario_id := str(scenario_id_value)
		var definition := library.scenario(scenario_id)
		var phases := _array(definition.get("phases", []))
		var actual_ids: Array = []
		for phase_value in phases:
			actual_ids.append(str((phase_value as Dictionary).get("id", "")) if typeof(phase_value) == TYPE_DICTIONARY else "")
		if actual_ids != PHASE_ARCS.get(scenario_id, []):
			failures.append("Scenario backlog phase arc mismatch for %s: %s." % [scenario_id, JSON.stringify(actual_ids)])
			continue
		if phases.size() > 3:
			failures.append("Scenario backlog phase arc %s exceeds three phases." % scenario_id)
			continue
		var run_state := RunStateScript.new()
		run_state.start_new("BACKLOG-PHASE-%s" % scenario_id)
		var archetype := library.environment_archetype(str(definition.get("archetype_id", "")))
		run_state.set_environment(EnvironmentInstanceScript.from_archetype(archetype, 2, run_state.create_rng("phase"), library, {}, definition).to_dict())
		for phase_index in range(phases.size() - 1):
			var threshold := int((phases[phase_index] as Dictionary).get("advance_after_actions", 0))
			if threshold < 2:
				failures.append("Scenario backlog phase %s/%s has no mid-phase save boundary." % [scenario_id, actual_ids[phase_index]])
				break
			run_state.advance_environment_turns(1)
			var restored := RunStateScript.new()
			restored.from_dict(run_state.to_dict())
			if int(restored.current_environment.get("scenario_phase_index", -1)) != phase_index \
				or int(restored.current_environment.get("scenario_phase_action_counter", -1)) != 1 \
				or JSON.stringify(restored.current_environment.get("scenario_state", {})) != JSON.stringify(run_state.current_environment.get("scenario_state", {})):
				failures.append("Scenario backlog phase %s/%s did not survive save/load mid-phase." % [scenario_id, actual_ids[phase_index]])
				break
			run_state = restored
			run_state.advance_environment_turns(threshold - 1)
			if int(run_state.current_environment.get("scenario_phase_index", -1)) != phase_index + 1 \
				or int(run_state.current_environment.get("scenario_phase_action_counter", -1)) != 0:
				failures.append("Scenario backlog phase %s/%s did not advance on its authored action boundary." % [scenario_id, actual_ids[phase_index]])
				break


static func _check_weight_and_layer_seams(library: ContentLibrary, failures: Array) -> void:
	var storm_tags := _strings(library.scenario("gas_station_storm_shelter").get("town_weight_tags", []))
	if not storm_tags.has("weather:rain") or not storm_tags.has("weather:storm"):
		failures.append("Storm Shelter must up-weight through both rain and storm town tags.")
	if not _strings(library.scenario("punchline_raid_jitters").get("town_weight_tags", [])).has("law:pressure"):
		failures.append("Raid Jitters lost the Police Sweep pressure weight seam.")
	var expected_layers := {
		"punchline_new_muscle": "casino",
		"punchline_debt_court": "club",
		"punchline_raid_jitters": "club",
	}
	for scenario_id_value in expected_layers.keys():
		var scenario_id := str(scenario_id_value)
		if str(library.scenario(scenario_id).get("layer_id", "")) != str(expected_layers.get(scenario_id, "")):
			failures.append("Punchline backlog scenario %s lost its exact authored layer scope." % scenario_id)


static func _check_tutorial_neutrality(library: ContentLibrary, failures: Array) -> void:
	var config := library.challenge_config_for("tutorial_first_card", "BACKLOG-TUTORIAL")
	var run_state := RunStateScript.new()
	run_state.start_new("BACKLOG-TUTORIAL", config)
	var selected: Dictionary = RunGeneratorScript.new(library).call("_select_scenario", run_state, "corner_store", run_state.create_rng("tutorial"))
	if str(selected.get("id", "")) != "corner_store_delivery_day" \
		or not _dict(selected.get("mutations", {})).is_empty() \
		or not _array(selected.get("phases", [])).is_empty():
		failures.append("Scenario backlog changed the tutorial's neutral Delivery Day pin.")


static func _check_full_catalog_reach(library: ContentLibrary, failures: Array) -> void:
	var expected: Dictionary = {}
	for archetype_id_value in library.environment_scenarios.keys():
		for definition_value in library.scenarios_for_archetype(str(archetype_id_value)):
			if typeof(definition_value) == TYPE_DICTIONARY:
				expected[str((definition_value as Dictionary).get("id", ""))] = true
	var reached: Dictionary = {}
	for seed_index in range(SEED_COUNT):
		var run_state := RunStateScript.new()
		run_state.start_new("BACKLOG-REACH-%02d" % seed_index)
		var generator := RunGeneratorScript.new(library)
		for archetype_id_value in library.environment_scenarios.keys():
			var archetype_id := str(archetype_id_value)
			var selected: Dictionary = generator.call("_select_scenario", run_state, archetype_id, run_state.create_rng("backlog_reach:%s" % archetype_id))
			var scenario_id := str(selected.get("id", ""))
			if not scenario_id.is_empty():
				reached[scenario_id] = true
	for scenario_id_value in expected.keys():
		if not reached.has(str(scenario_id_value)):
			failures.append("Full-catalog 20-seed selector sweep starved %s." % str(scenario_id_value))


static func _check_launch_cut_reach(library: ContentLibrary, failures: Array) -> void:
	var backlog: Dictionary = {}
	for scenario_id in _backlog_ids():
		backlog[str(scenario_id)] = true
	var expected: Dictionary = {}
	for archetype_id in TIER1_ARCHETYPES + TIER2_ARCHETYPES:
		for definition_value in library.scenarios_for_archetype(str(archetype_id)):
			if typeof(definition_value) == TYPE_DICTIONARY:
				var scenario_id := str((definition_value as Dictionary).get("id", ""))
				if not backlog.has(scenario_id):
					expected[scenario_id] = true
	var reached: Dictionary = {}
	for seed_index in range(SEED_COUNT):
		var tier1_run := RunStateScript.new()
		tier1_run.start_new("TIER1-REACH-%02d" % seed_index)
		var tier1_generator := RunGeneratorScript.new(library)
		for archetype_id in TIER1_ARCHETYPES:
			var tier1_selected: Dictionary = tier1_generator.call("_select_scenario", tier1_run, str(archetype_id), tier1_run.create_rng("tier1_reach:%s" % str(archetype_id)))
			var tier1_id := str(tier1_selected.get("id", ""))
			if not tier1_id.is_empty():
				reached[tier1_id] = true
		var tier2_run := RunStateScript.new()
		tier2_run.start_new("TIER2-REACH-%02d" % seed_index)
		var tier2_generator := RunGeneratorScript.new(library)
		for archetype_id in TIER2_ARCHETYPES:
			var tier2_selected: Dictionary = tier2_generator.call("_select_scenario", tier2_run, str(archetype_id), tier2_run.create_rng("tier2_reach:%s" % str(archetype_id)))
			var tier2_id := str(tier2_selected.get("id", ""))
			if not tier2_id.is_empty():
				reached[tier2_id] = true
	for scenario_id_value in expected.keys():
		if not reached.has(str(scenario_id_value)):
			failures.append("Expanded catalog crowded launch scenario %s out of its legacy 20-seed sweep." % str(scenario_id_value))


static func _mutation_axis_count(mutations: Dictionary) -> int:
	var count := 0
	if mutations.has("patron_set") or mutations.has("staff_set"):
		count += 1
	if mutations.has("event_pool_add") or mutations.has("event_pool_remove"):
		count += 1
	for axis in ["economic_profile_overrides", "game_modifier_hooks", "service_add", "service_remove", "security_overrides", "presentation", "music_profile_override"]:
		if mutations.has(axis):
			count += 1
	return count


static func _base_event_ids(library: ContentLibrary) -> Dictionary:
	var result: Dictionary = {}
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype := archetype_value as Dictionary
		for event_id in _strings(archetype.get("event_pool", [])):
			result[event_id] = true
		for layer_value in _dict(archetype.get("layers", {})).values():
			if typeof(layer_value) == TYPE_DICTIONARY:
				for event_id in _strings((layer_value as Dictionary).get("event_pool", [])):
					result[event_id] = true
	return result


static func _backlog_ids() -> Array:
	var result: Array = []
	for ids_value in BACKLOG_BY_ARCHETYPE.values():
		result.append_array(ids_value as Array)
	return result


static func _run_rng(seed: String) -> RngStream:
	var run_state := RunStateScript.new()
	run_state.start_new(seed)
	return run_state.create_rng("environment")


static func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _strings(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for item in value as Array:
			result.append(str(item))
	return result
