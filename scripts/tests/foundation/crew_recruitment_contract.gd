extends RefCounted

# Permanent crew06_5 acceptance contract: all seven primary/fallback paths,
# optionality, rank perks, save migration, and hidden deterministic presence.

const CrewRecruitmentModelScript := preload("res://scripts/core/crew_recruitment_model.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")


static func check(library: ContentLibrary, failures: Array) -> void:
	for failure in CrewRecruitmentModelScript.validate_content():
		failures.append("Crew recruitment content: %s" % str(failure))
	_check_placement_matrix(library, failures)
	_check_rook_paths(failures)
	_check_rook_signposts(library, failures)
	_check_perks_and_save(failures)
	_check_crew_ignoring_regression(failures)
	_check_presence_determinism(failures)


static func _check_placement_matrix(library: ContentLibrary, failures: Array) -> void:
	for member_id in CrewRecruitmentModelScript.MEMBER_IDS:
		if member_id == "crew_rook":
			continue
		var definition := CrewRecruitmentModelScript.member_definition(member_id)
		for path_kind in ["primary", "fallback"]:
			var run_state := _marked_run("CREW-RECRUIT-%s-%s" % [member_id, path_kind])
			var location := _dict(definition.get(path_kind, {}))
			var archetypes := _string_array(location.get("archetype_ids", []))
			var scenarios := _string_array(location.get("scenario_ids", []))
			var layers := _string_array(location.get("layer_ids", []))
			if archetypes.is_empty():
				failures.append("Crew recruitment %s %s fixture has no archetype." % [member_id, path_kind])
				continue
			if path_kind == "fallback":
				_set_fixture_world(run_state, [str(archetypes[0])])
			var environment := {
				"id": "%s_%s_fixture" % [member_id, path_kind],
				"archetype_id": str(archetypes[0]),
				"world_node_id": str(archetypes[0]),
				"kind": "casino",
				"tier": 2,
				"scenario_id": str(scenarios[0]) if not scenarios.is_empty() else "",
				"current_layer_id": str(layers[0]) if not layers.is_empty() else "",
				"event_ids": [],
				"resolved_event_ids": [],
			}
			CrewRecruitmentModelScript.apply_to_environment(run_state, environment)
			var event_id := str(definition.get("event_id", ""))
			if not _string_array(environment.get("event_ids", [])).has(event_id):
				failures.append("Crew recruitment %s did not place its %s encounter." % [member_id, path_kind])
				continue
			run_state.set_environment(environment)
			var module := EventModuleScript.new()
			module.setup(library.event(event_id), library)
			if not module.can_trigger(run_state, run_state.current_environment):
				failures.append("Crew recruitment %s %s encounter was not actionable." % [member_id, path_kind])
				continue
			if member_id == "crew_bishop":
				var first := module.resolve(run_state, run_state.current_environment, "wait_for_bishop")
				var between_beats := RunStateScript.new()
				between_beats.from_dict(run_state.to_dict())
				run_state = between_beats
				module.setup(library.event(event_id), library)
				if not bool(first.get("ok", false)) or run_state.crew_rank(member_id) != "marker" \
					or not bool(run_state.narrative_flags.get("bishop_recruitment_first_beat", false)) \
					or module.choice("work_with_bishop", run_state, run_state.current_environment).is_empty():
					failures.append("Bishop's quiet first beat failed on the %s path." % path_kind)
			var result := module.resolve(run_state, run_state.current_environment, "work_with_%s" % member_id.trim_prefix("crew_"))
			if not bool(result.get("ok", false)) or run_state.crew_rank(member_id) != "associate":
				failures.append("Crew recruitment %s %s choice did not grant Associate." % [member_id, path_kind])
			if not run_state.crew_member_job_available(member_id):
				failures.append("Crew recruitment %s %s did not open Associate jobs." % [member_id, path_kind])
			var recruited_round_trip := RunStateScript.new()
			recruited_round_trip.from_dict(run_state.to_dict())
			if recruited_round_trip.crew_rank(member_id) != "associate" or not recruited_round_trip.crew_member_job_available(member_id):
				failures.append("Crew recruitment %s %s did not survive its post-intro save/load." % [member_id, path_kind])


static func _check_rook_paths(failures: Array) -> void:
	var primary := RunStateScript.new()
	primary.start_new("CREW-ROOK-LOAN")
	var marker := CrewStateModelScript.rank_threshold("marker")
	primary.crew_add_trust("crew_rook", marker, "crew_loan_fixture")
	if primary.crew_rank("crew_rook") != "marker":
		failures.append("Rook's primary Crew-loan path did not reach Marker.")
	var legacy_data := RunStateScript.new().to_dict()
	legacy_data.erase("crew_state")
	legacy_data["narrative_flags"] = {"crew_marker_open": true}
	legacy_data["debt"] = [{"id": "the_crew_marker", "lender_id": "the_crew", "balance": 2, "status": "active", "debt_kind": "favor"}]
	var fallback := RunStateScript.new()
	fallback.from_dict(legacy_data)
	if fallback.crew_rank("crew_rook") != "marker":
		failures.append("Rook's legacy-marker fallback migration did not preserve meetability.")


static func _check_rook_signposts(library: ContentLibrary, failures: Array) -> void:
	var run_state := _marked_run("CREW-ROOK-SIGNPOSTS")
	_set_fixture_world(run_state, ["back_alley"])
	var choices := CrewRecruitmentModelScript.rook_signpost_choices(run_state)
	var choice_ids: Array = []
	for value in choices:
		if typeof(value) == TYPE_DICTIONARY:
			choice_ids.append(str((value as Dictionary).get("id", "")))
	if choice_ids != ["ask_switch", "keep_moving"]:
		failures.append("Rook signposted members who were not genuinely meetable in the fixture: %s." % JSON.stringify(choice_ids))
	var rook_definition := CrewRecruitmentModelScript.member_definition("crew_rook")
	var leads_placed := false
	for location_value in _array(rook_definition.get("presence", [])):
		var location := str(location_value)
		var environment := {
			"id": "%s_fixture" % location,
			"archetype_id": location,
			"world_node_id": location,
			"kind": "casino",
			"event_ids": [],
			"scenario_patron_ids": [],
		}
		CrewRecruitmentModelScript.apply_to_environment(run_state, environment)
		if _string_array(environment.get("event_ids", [])).has("recruitment_rook_leads"):
			leads_placed = true
			break
	if not leads_placed:
		failures.append("Rook's seeded presence did not expose his contextual meetable-member leads.")
	run_state.crew_recruit_member("crew_switch")
	if not CrewRecruitmentModelScript.rook_signpost_choices(run_state).is_empty():
		failures.append("Rook kept signposting a member after their intro was complete.")
	var presence_run := _marked_run("CREW-ROOK-SIGNPOSTS")
	_set_fixture_world(presence_run, ["back_alley"])
	var environment := {"id": "rook_leads_fixture", "archetype_id": "back_alley", "world_node_id": "back_alley", "kind": "casino", "event_ids": [], "resolved_event_ids": []}
	CrewRecruitmentModelScript.apply_to_environment(presence_run, environment)
	if not _string_array(environment.get("event_ids", [])).has("recruitment_rook_leads"):
		failures.append("Rook's seeded presence did not expose his reusable leads encounter.")
	else:
		presence_run.set_environment(environment)
		var module := EventModuleScript.new()
		module.setup(library.event("recruitment_rook_leads"), library)
		var first := module.resolve(presence_run, presence_run.current_environment, "ask_switch")
		if not bool(first.get("ok", false)) or _string_array(presence_run.current_environment.get("resolved_event_ids", [])).has("recruitment_rook_leads") \
			or not bool(presence_run.narrative_flags.get("crew_rook_lead_heard:crew_switch", false)) \
			or not module.choice("ask_switch", presence_run, presence_run.current_environment).is_empty() \
			or _string_array(presence_run.current_environment.get("event_ids", [])).has("recruitment_rook_leads") \
			or module.can_trigger(presence_run, presence_run.current_environment):
			failures.append("Rook's presence-bound lead did not retire after its one authored hearing.")


static func _check_perks_and_save(failures: Array) -> void:
	var run_state := _marked_run("CREW-PERKS")
	if run_state.crew_rook_escort_available():
		failures.append("Rook's L3 escort leaked below Made.")
	if run_state.crew_capability_active("sweep_intel") or bool(run_state.crew_switch_intel_status().get("available", false)):
		failures.append("Switch intel leaked below Associate.")
	run_state.crew_recruit_member("crew_switch")
	if not run_state.crew_capability_active("sweep_intel") or not bool(run_state.crew_switch_intel_status().get("available", false)):
		failures.append("Switch Associate did not activate sweep intel and remote reveal.")
	_set_fixture_world(run_state, ["bar", "gas_station_casino", "back_alley", "motel"])
	run_state.configure_town_world(run_state.world_map)
	for target_id in ["gas_station_casino", "back_alley", "motel"]:
		run_state.seed_scenario_for_node(target_id, {"id": "fixture_%s" % target_id, "archetype_id": target_id, "display_name": "Fixture"})
	run_state.current_environment = {"id": "bar_fixture", "archetype_id": "bar", "world_node_id": "bar", "event_ids": [], "resolved_event_ids": []}
	var reveal_a := run_state.crew_switch_reveal_node("gas_station_casino")
	var reveal_b := run_state.crew_switch_reveal_node("back_alley")
	var reveal_c := run_state.crew_switch_reveal_node("motel")
	if not bool(reveal_a.get("ok", false)) or not bool(reveal_b.get("ok", false)) or bool(reveal_c.get("ok", false)) \
		or not bool(WorldMapScript.node_by_id(run_state.world_map, "gas_station_casino").get("scouted", false)) \
		or int(run_state.crew_switch_intel_status().get("uses", 0)) != 2:
		failures.append("Switch remote reveal did not use the heard/scouted pipeline with its per-visit cap.")
	var exhausted_visit := run_state.current_environment.duplicate(true)
	run_state.set_environment({"id": "motel_visit_fixture", "archetype_id": "motel", "world_node_id": "motel"})
	run_state.set_environment(exhausted_visit)
	if not bool(run_state.crew_switch_intel_status().get("available", false)) or int(run_state.crew_switch_intel_status().get("uses", -1)) != 0:
		failures.append("Switch remote reveal uses did not reset on a later visit to the same venue.")
	run_state.crew_add_trust("crew_rook", CrewStateModelScript.rank_threshold("made") - run_state.crew_trust("crew_rook"), "made_fixture")
	if not run_state.crew_rook_escort_available() or not bool(run_state.narrative_flags.get("rook_escort_punchline_back_room", false)):
		failures.append("Rook Made did not wire the Punchline L3 escort flag.")
	run_state.inventory.append("marked_cards")
	if bool(run_state.crew_knuckles_stash_status().get("available", false)):
		failures.append("Knuckles stash leaked below Associate.")
	run_state.crew_recruit_member("crew_knuckles")
	var stashed := run_state.crew_knuckles_stash_item("marked_cards")
	if not bool(stashed.get("ok", false)) or run_state.inventory.has("marked_cards") or run_state._carried_contraband_ids().has("marked_cards"):
		failures.append("Knuckles stash did not remove contraband from sweep-visible inventory.")
	for _index in range(3):
		run_state.inventory.append("marked_cards")
	var stash_two := run_state.crew_knuckles_stash_item("marked_cards")
	var stash_three := run_state.crew_knuckles_stash_item("marked_cards")
	var stash_over_cap := run_state.crew_knuckles_stash_item("marked_cards")
	if not bool(stash_two.get("ok", false)) or not bool(stash_three.get("ok", false)) or bool(stash_over_cap.get("ok", false)) \
		or int(run_state.crew_knuckles_stash_status().get("count", 0)) != 3:
		failures.append("Knuckles stash did not enforce its data cap.")
	run_state.inventory.erase("marked_cards")
	var saved := run_state.to_dict()
	var loaded := RunStateScript.new()
	loaded.from_dict(saved)
	if loaded.crew_rank("crew_switch") != "associate" or loaded.crew_rank("crew_knuckles") != "associate" or not loaded.crew_rook_escort_available():
		failures.append("Crew met/rank/perk state did not survive save/load.")
	if not _string_array(loaded.crew_knuckles_stash_status().get("item_ids", [])).has("marked_cards") or loaded._carried_contraband_ids().has("marked_cards"):
		failures.append("Knuckles' capped stash did not survive a sweep-safe save round trip.")
	var legacy := RunStateScript.new()
	var legacy_data := RunStateScript.new().to_dict()
	legacy_data["crew_state"] = _dict(legacy_data.get("crew_state", {}))
	legacy.from_dict(legacy_data)
	if not _string_array(legacy.crew_knuckles_stash_status().get("item_ids", [])).is_empty():
		failures.append("Pre-recruitment crew saves did not migrate to an empty stash.")


static func _check_crew_ignoring_regression(failures: Array) -> void:
	var run_state := RunStateScript.new()
	run_state.start_new("CREW-IGNORED")
	var environment := {"id": "ignored", "archetype_id": "bar", "kind": "casino", "event_ids": ["rowdy_regular"], "scenario_patron_ids": ["fight_crowd"]}
	var before_run := JSON.stringify(run_state.to_dict())
	var before_environment := JSON.stringify(environment)
	CrewRecruitmentModelScript.apply_to_environment(run_state, environment)
	if JSON.stringify(run_state.to_dict()) != before_run or JSON.stringify(environment) != before_environment:
		failures.append("Crew-ignoring run changed outside authored anchor ambience.")
	for member_id in CrewRecruitmentModelScript.MEMBER_IDS:
		if run_state.crew_trust(member_id) != 0:
			failures.append("Crew-ignoring run moved hidden trust for %s." % member_id)


static func _check_presence_determinism(failures: Array) -> void:
	var first := _marked_run("CREW-PRESENCE")
	var second := _marked_run("CREW-PRESENCE")
	for member_id in CrewRecruitmentModelScript.MEMBER_IDS:
		first.crew_add_trust(member_id, CrewStateModelScript.rank_threshold("associate") - first.crew_trust(member_id), "presence_fixture")
		second.crew_add_trust(member_id, CrewStateModelScript.rank_threshold("associate") - second.crew_trust(member_id), "presence_fixture")
	var environment := {"archetype_id": "small_underground_casino", "world_node_id": "small_underground_casino"}
	var a := CrewRecruitmentModelScript.presence_for_environment(first, environment)
	var b := CrewRecruitmentModelScript.presence_for_environment(second, environment)
	if JSON.stringify(a) != JSON.stringify(b):
		failures.append("Crew ambient presence was not deterministic for the same seed and action boundary.")
	var seen := {}
	var presence_by_location := {}
	for node_id in ["small_underground_casino", "gas_station_casino", "back_alley", "bar", "pawn_shop", "kitty_cat_lounge", "delta_queen", "grand_casino", "grand_casino_cage", "grand_casino_high_limit", "beach"]:
		for value in CrewRecruitmentModelScript.presence_for_environment(first, {"archetype_id": node_id, "world_node_id": node_id}):
			if typeof(value) == TYPE_DICTIONARY:
				var member_id := str((value as Dictionary).get("member_id", ""))
				seen[member_id] = int(seen.get(member_id, 0)) + 1
				presence_by_location["%s:%s" % [node_id, member_id]] = value
	for member_id in CrewRecruitmentModelScript.MEMBER_IDS:
		if int(seen.get(member_id, 0)) != 1:
			failures.append("Crew presence placed %s in %d itinerary locations at one boundary." % [member_id, int(seen.get(member_id, 0))])
	var twin_presence := {}
	for node_id in ["small_underground_casino", "gas_station_casino", "back_alley", "bar", "pawn_shop", "kitty_cat_lounge", "delta_queen", "grand_casino", "grand_casino_cage", "grand_casino_high_limit", "beach"]:
		for value in CrewRecruitmentModelScript.presence_for_environment(second, {"archetype_id": node_id, "world_node_id": node_id}):
			if typeof(value) == TYPE_DICTIONARY:
				twin_presence["%s:%s" % [node_id, str((value as Dictionary).get("member_id", ""))]] = value
	if JSON.stringify(presence_by_location) != JSON.stringify(twin_presence):
		failures.append("Crew itinerary placement differed between same-seed twins.")
	var stale_environment := {
		"id": "stale_crew_presence_fixture",
		"archetype_id": "motel",
		"world_node_id": "motel",
		"kind": "recovery",
		"event_ids": ["recruitment_rook_leads"],
		"scenario_patron_ids": CrewRecruitmentModelScript.MEMBER_IDS.duplicate(),
		"crew_presence": [{"member_id": "crew_rook", "rank": "marker", "line": "stale"}],
	}
	CrewRecruitmentModelScript.apply_to_environment(first, stale_environment)
	var stale_patrons := _string_array(stale_environment.get("scenario_patron_ids", []))
	var leaked_member := false
	for member_id in CrewRecruitmentModelScript.MEMBER_IDS:
		if stale_patrons.has(member_id):
			leaked_member = true
	if stale_environment.has("crew_presence") or leaked_member or _string_array(stale_environment.get("event_ids", [])).has("recruitment_rook_leads"):
		failures.append("Crew presence rotation left stale patrons or Rook leads in an empty room.")
	var recovery_run := _marked_run("CREW-PRESENCE-RECOVERY")
	var recovery_environment := {
		"id": "beach_fixture",
		"archetype_id": "beach",
		"world_node_id": "beach",
		"kind": "recovery",
		"event_ids": ["recruitment_rook_leads"],
		"scenario_patron_ids": ["bonfire_crowd", "crew_rook"],
		"crew_presence": [{"member_id": "crew_rook", "rank": "marker", "line": "stale"}],
	}
	CrewRecruitmentModelScript.apply_to_environment(recovery_run, recovery_environment)
	if recovery_environment.has("crew_presence") \
		or _string_array(recovery_environment.get("event_ids", [])).has("recruitment_rook_leads") \
		or _string_array(recovery_environment.get("scenario_patron_ids", [])).has("crew_rook") \
		or not _string_array(recovery_environment.get("scenario_patron_ids", [])).has("bonfire_crowd"):
		failures.append("Crew presence weakened the actor-free recovery-venue contract.")


static func _marked_run(seed: String) -> RunState:
	var run_state := RunStateScript.new()
	run_state.start_new(seed)
	run_state.crew_add_trust("crew_rook", CrewStateModelScript.rank_threshold("marker"), "marker_fixture")
	return run_state


static func _set_fixture_world(run_state: RunState, node_ids: Array) -> void:
	var nodes: Array = []
	var edges: Array = []
	for index in range(node_ids.size()):
		var node_id := str(node_ids[index])
		nodes.append({"id": node_id, "archetype_id": node_id, "kind": "casino", "tier": 2, "state": "revealed", "seen": true, "environment": {}})
		if index > 0:
			edges.append({"from": str(node_ids[index - 1]), "to": node_id})
	var start_id := str(node_ids[0]) if not node_ids.is_empty() else ""
	run_state.set_world_map({"version": 3, "seed_text": run_state.seed_text, "start_node_id": start_id, "current_node_id": start_id, "nodes": nodes, "edges": edges, "visited_path": [start_id] if not start_id.is_empty() else []})


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	for value_entry in _array(value):
		var entry := str(value_entry).strip_edges()
		if not entry.is_empty():
			result.append(entry)
	return result
