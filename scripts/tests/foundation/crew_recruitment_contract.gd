extends RefCounted

# Permanent crew06_5 acceptance contract: all seven primary/fallback paths,
# optionality, rank perks, save migration, and hidden deterministic presence.

const CrewRecruitmentModelScript := preload("res://scripts/core/crew_recruitment_model.gd")
const CrewIgnoredGoldenProbeScript := preload("res://scripts/tests/foundation/crew_ignored_golden_probe.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")
const IGNORED_BASELINE_PATH := "res://scripts/tests/fixtures/crew06_5_ignored_run_baseline.json"
const IGNORED_BASELINE_CHANGE_COMMIT := "a0d2b6ff7155484830909728f3051f587dc5dc4d"
const JSON_EXACT_INTEGER_LIMIT := 9007199254740991.0


static func check(library: ContentLibrary, failures: Array) -> void:
	for failure in CrewRecruitmentModelScript.validate_content():
		failures.append("Crew recruitment content: %s" % str(failure))
	_check_event_presentation_contract(library, failures)
	_check_placement_matrix(library, failures)
	_check_production_reachability(library, failures)
	_check_rook_paths(library, failures)
	_check_rook_signposts(library, failures)
	_check_bishop_grand_casino_presence(library, failures)
	_check_perks_and_save(failures)
	_check_contact_surfaces(library, failures)
	_check_crew_ignoring_regression(library, failures)
	_check_presence_determinism(failures)


static func _check_event_presentation_contract(library: ContentLibrary, failures: Array) -> void:
	var event_ids := CrewRecruitmentModelScript.recruitment_event_ids()
	event_ids.append("recruitment_rook_leads")
	event_ids.append_array(CrewRecruitmentModelScript.contact_event_ids())
	for event_id_value in event_ids:
		var event_id := str(event_id_value)
		var definition := library.event(event_id)
		if definition.is_empty():
			failures.append("Crew recruitment event %s is missing." % event_id)
			continue
		if str(definition.get("type", "")) != "crew":
			failures.append("Crew recruitment event %s must use the crew event class." % event_id)
		var speaker := _dict(definition.get("speaker", {}))
		var expected_member_id := _event_member_id(event_id)
		if not ["patron", "staff", "stranger", "lender"].has(str(speaker.get("role", ""))) \
			or expected_member_id.is_empty() or str(speaker.get("character_id", "")) != expected_member_id:
			failures.append("Crew recruitment event %s must retain its exact Crew character through normalized speaker schema." % event_id)
		if event_id.begins_with("crew_contact_") and bool(speaker.get("environment_actor", true)):
			failures.append("Crew contact %s must reuse its seeded presence actor." % event_id)
	var knuckles := library.event("recruitment_knuckles")
	var knuckles_speaker := _dict(knuckles.get("speaker", {}))
	if str(knuckles.get("asset_path", "")) != "res://assets/art/events/rowdy_regular.png" \
		or str(knuckles.get("icon_key", "")) != "rowdy_regular" \
		or str(knuckles.get("environment_prop", "")) != "rowdy_patron" \
		or not bool(knuckles_speaker.get("environment_actor", false)):
		failures.append("Knuckles recruitment must remain an actor-present rowdy encounter, not a door prop.")


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
	var velvet_negative := _marked_run("CREW-RECRUIT-VELVET-NOT-SLOW")
	_set_fixture_world(velvet_negative, ["kitty_cat_lounge"])
	var non_slow_environment := {
		"id": "crew_velvet_non_slow_fixture",
		"archetype_id": "kitty_cat_lounge",
		"world_node_id": "kitty_cat_lounge",
		"kind": "casino",
		"scenario_id": "kitty_cat_lounge_regular_night",
		"event_ids": [],
		"resolved_event_ids": [],
	}
	CrewRecruitmentModelScript.apply_to_environment(velvet_negative, non_slow_environment)
	if _string_array(non_slow_environment.get("event_ids", [])).has("recruitment_velvet"):
		failures.append("Velvet fallback leaked outside the authored Slow Night beat.")


static func _check_production_reachability(library: ContentLibrary, failures: Array) -> void:
	for member_id in CrewRecruitmentModelScript.MEMBER_IDS:
		if member_id == "crew_rook":
			continue
		for path_kind in ["primary", "fallback"]:
			var generated := _generated_path(library, member_id, path_kind)
			var run_state: RunState = generated.get("run_state") as RunState
			var event_id := str(CrewRecruitmentModelScript.member_definition(member_id).get("event_id", ""))
			if run_state == null or not bool(generated.get("entered", false)) \
				or not _string_array(run_state.current_environment.get("event_ids", [])).has(event_id):
				failures.append("Production generation did not expose %s's %s recruitment path." % [member_id, path_kind])
				continue
			var module := EventModuleScript.new()
			module.setup(library.event(event_id), library)
			if not module.can_trigger(run_state, run_state.current_environment):
				failures.append("Production %s %s encounter was not actionable." % [member_id, path_kind])
				continue
			if member_id == "crew_bishop":
				var first := module.resolve(run_state, run_state.current_environment, "wait_for_bishop")
				if not bool(first.get("ok", false)):
					failures.append("Production Bishop %s first beat did not resolve." % path_kind)
					continue
			var result := module.resolve(run_state, run_state.current_environment, "work_with_%s" % member_id.trim_prefix("crew_"))
			if not bool(result.get("ok", false)) or run_state.crew_rank(member_id) != "associate":
				failures.append("Production %s %s path did not complete through the real event action." % [member_id, path_kind])


static func _check_rook_paths(library: ContentLibrary, failures: Array) -> void:
	var primary := RunStateScript.new()
	primary.start_new("CREW-ROOK-LOAN")
	primary.set_environment({
		"id": "crew_rook_loan_fixture",
		"archetype_id": "delta_queen",
		"world_node_id": "delta_queen",
		"kind": "casino",
		"lender_hooks": ["the_crew"],
		"event_ids": [],
		"resolved_event_ids": [],
	})
	var resolver := RunActionServiceScript.new()
	resolver.setup(library, primary)
	var loan_result := resolver.use_hook("lender", "the_crew")
	if not bool(loan_result.get("ok", false)) or primary.crew_rank("crew_rook") != "marker":
		failures.append("Rook's primary Crew-loan path did not resolve through the shipped lender action and reach Marker.")
	if not primary.pending_triggered_events.is_empty() \
			or not primary.next_pending_triggered_event().is_empty() \
			or primary.pending_talk_event_count() != 0 \
			or not primary.next_pending_talk_event().is_empty():
		failures.append("The shipped Crew lender action enqueued a post-loan triggered or talk event instead of ending at Marker.")
	var legacy_data := RunStateScript.new().to_dict()
	legacy_data.erase("crew_state")
	legacy_data["narrative_flags"] = {"crew_marker_open": true}
	legacy_data["debt"] = [{"id": "the_crew_marker", "lender_id": "the_crew", "balance": 2, "status": "active", "debt_kind": "favor"}]
	var fallback := RunStateScript.new()
	fallback.from_dict(legacy_data)
	if fallback.crew_rank("crew_rook") != "marker":
		failures.append("Rook's legacy Marker compatibility migration did not preserve meetability.")


static func _check_bishop_grand_casino_presence(library: ContentLibrary, failures: Array) -> void:
	var selected_seed := ""
	for seed_index in range(128):
		var candidate := _marked_run("CREW-BISHOP-CAGE-PRESENCE-%03d" % seed_index)
		candidate.crew_recruit_member("crew_bishop")
		_set_fixture_world(candidate, [RunState.GRAND_CASINO_ARCHETYPE_ID])
		var cage_probe := {
			"id": "bishop_cage_seed_probe",
			"archetype_id": RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID,
			"world_node_id": RunState.GRAND_CASINO_ARCHETYPE_ID,
			"kind": "casino",
			"event_ids": [],
			"resolved_event_ids": [],
			"scenario_patron_ids": [],
		}
		CrewRecruitmentModelScript.apply_to_environment(candidate, cage_probe)
		if _presence_has_member(cage_probe, "crew_bishop"):
			selected_seed = candidate.seed_text
			break
	if selected_seed.is_empty():
		failures.append("No deterministic Bishop itinerary seed selected the Grand Casino cage window.")
		return
	var run_state := _marked_run(selected_seed)
	run_state.crew_recruit_member("crew_bishop")
	_set_fixture_world(run_state, [RunState.GRAND_CASINO_ARCHETYPE_ID])
	run_state.narrative_flags["grand_casino_high_limit_access"] = true
	var generator := RunGeneratorScript.new(library)
	generator.next_environment(run_state, RunState.GRAND_CASINO_ARCHETYPE_ID, true)
	var selected_rooms: Array = []
	if _presence_has_member(run_state.current_environment, "crew_bishop"):
		selected_rooms.append(RunState.GRAND_CASINO_ARCHETYPE_ID)
	if not generator.enter_grand_casino_room(run_state, RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID):
		failures.append("Bishop cage presence fixture could not enter the production cage room.")
		return
	if _presence_has_member(run_state.current_environment, "crew_bishop"):
		selected_rooms.append(RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID)
	if not _presence_has_contact(run_state.current_environment, "crew_bishop"):
		failures.append("Bishop's selected cage presence did not retain its contextual contact seam.")
	if not generator.enter_grand_casino_room(run_state, RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID):
		failures.append("Bishop cage presence fixture could not enter the production high-limit room.")
		return
	if _presence_has_member(run_state.current_environment, "crew_bishop"):
		selected_rooms.append(RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID)
	if selected_rooms != [RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID]:
		failures.append("Bishop itinerary must select exactly one physical Grand Casino room; got %s." % JSON.stringify(selected_rooms))
	# Re-entry must recompute from canonical world-node identity rather than
	# trusting a stale serialized room actor snapshot.
	if not generator.enter_grand_casino_room(run_state, RunState.GRAND_CASINO_ARCHETYPE_ID):
		failures.append("Bishop cage presence fixture could not return to the main floor.")
		return
	var stored_cage := run_state.peek_grand_casino_room_environment(RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID)
	stored_cage["crew_presence"] = [{"member_id": "crew_rook", "rank": "marker", "line": "stale"}]
	stored_cage["scenario_patron_ids"] = ["crew_rook"]
	if not generator.enter_grand_casino_room(run_state, RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID) \
		or not _presence_has_member(run_state.current_environment, "crew_bishop") \
		or not _presence_has_contact(run_state.current_environment, "crew_bishop") \
		or _presence_has_member(run_state.current_environment, "crew_rook"):
		failures.append("Restored Grand Casino cage did not refresh Bishop's seeded presence on revisit.")


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
		var heard_round_trip := RunStateScript.new()
		heard_round_trip.from_dict(presence_run.to_dict())
		if not bool(heard_round_trip.narrative_flags.get("crew_rook_lead_heard:crew_switch", false)) \
			or not CrewRecruitmentModelScript.rook_signpost_choices(heard_round_trip).is_empty():
			failures.append("Rook's one-hearing lead retirement did not survive save/load.")


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


static func _check_contact_surfaces(library: ContentLibrary, failures: Array) -> void:
	for member_id in CrewRecruitmentModelScript.MEMBER_IDS:
		var event_id := str(CrewRecruitmentModelScript.member_definition(member_id).get("contact_event_id", ""))
		if library.event(event_id).is_empty():
			failures.append("Crew contact event is missing for %s." % member_id)
		var below := _marked_run("CREW-CONTACT-BELOW-%s" % member_id)
		if member_id != "crew_rook":
			below.crew_meet_member(member_id)
		if not CrewRecruitmentModelScript.contact_choices(below, {}, member_id, library).is_empty():
			failures.append("Crew contact actions leaked below Associate for %s." % member_id)

	var rook_run := _marked_run("CREW-CONTACT-ROOK")
	rook_run.crew_add_trust("crew_rook", CrewStateModelScript.rank_threshold("associate") - rook_run.crew_trust("crew_rook"), "contact_fixture")
	var rook_environment := _presence_environment(rook_run, "crew_rook")
	if not _contact_is_embedded(rook_environment, "crew_rook"):
		failures.append("Rook's generated presence did not expose his Associate work contact.")
	else:
		rook_run.set_environment(rook_environment)
		var rook_module := EventModuleScript.new()
		rook_module.setup(library.event("crew_contact_rook"), library)
		var rook_result := rook_module.resolve(rook_run, rook_run.current_environment, "job_crew_favor_delivery")
		if not bool(rook_result.get("ok", false)) or not rook_run.triggered_event_pending("crew_favor_delivery"):
			failures.append("Rook's contextual contact did not offer the existing Crew job through the real event pipeline.")

	var switch_run := _marked_run("CREW-CONTACT-SWITCH")
	switch_run.crew_recruit_member("crew_switch")
	var switch_nodes := ["bar", "gas_station_casino", "back_alley", "motel", "corner_store"]
	_set_fixture_world(switch_run, switch_nodes)
	for node_id in switch_nodes:
		switch_run.seed_scenario_for_node(node_id, {"id": "fixture_%s" % node_id, "archetype_id": node_id, "display_name": node_id.replace("_", " ").capitalize()})
	var switch_environment := _presence_environment(switch_run, "crew_switch", false)
	if not _contact_is_embedded(switch_environment, "crew_switch"):
		failures.append("Switch's seeded presence did not become her player-facing Associate contact.")
	else:
		switch_run.set_environment(switch_environment)
		var switch_module := EventModuleScript.new()
		switch_module.setup(library.event("crew_contact_switch"), library)
		var initial_choices := switch_module.choices(switch_run, switch_run.current_environment)
		var reveal_ids: Array = []
		for choice_value in initial_choices:
			if typeof(choice_value) == TYPE_DICTIONARY and str((choice_value as Dictionary).get("id", "")).begins_with("reveal_"):
				reveal_ids.append(str((choice_value as Dictionary).get("id", "")))
		if switch_module.choice("read_sweep", switch_run, switch_run.current_environment).is_empty() or reveal_ids.size() < 2:
			failures.append("Switch's contact did not expose sweep intel plus capped remote reveals.")
		else:
			for reveal_index in range(2):
				var reveal_id := str(reveal_ids[reveal_index])
				if not switch_module.can_trigger(switch_run, switch_run.current_environment) \
					or switch_module.choice(reveal_id, switch_run, switch_run.current_environment).is_empty():
					failures.append("Switch's normal contact surface closed before its per-visit reveal cap was spent.")
					break
				var reveal_result := switch_module.resolve(switch_run, switch_run.current_environment, str(reveal_id))
				if not bool(reveal_result.get("ok", false)) or not bool(_dict(reveal_result.get("crew_service_result", {})).get("ok", false)):
					failures.append("Switch's contact reveal did not invoke the real scouting pipeline.")
			var switch_status := switch_run.crew_switch_intel_status()
			if int(switch_status.get("uses", 0)) != int(switch_status.get("cap", -1)) or bool(switch_status.get("available", true)):
				failures.append("Switch's contact did not enforce its data-capped per-visit reveal allowance.")

	var knuckles_run := _marked_run("CREW-CONTACT-KNUCKLES")
	knuckles_run.crew_recruit_member("crew_knuckles")
	knuckles_run.inventory = [{"id": "marked_cards", "copy": "first"}, {"id": "marked_cards", "copy": "second"}]
	var knuckles_environment := _presence_environment(knuckles_run, "crew_knuckles")
	if not _contact_is_embedded(knuckles_environment, "crew_knuckles"):
		failures.append("Knuckles' seeded presence did not become his player-facing stash contact.")
	else:
		knuckles_run.set_environment(knuckles_environment)
		var knuckles_module := EventModuleScript.new()
		knuckles_module.setup(library.event("crew_contact_knuckles"), library)
		var stash_result := knuckles_module.resolve(knuckles_run, knuckles_run.current_environment, "stash_marked_cards_1")
		if not bool(stash_result.get("ok", false)) or knuckles_run.inventory.size() != 1 or knuckles_run.crew_contraband_stash.size() != 1 \
			or str(_dict(knuckles_run.inventory[0]).get("copy", "")) != "first" \
			or str(_dict(knuckles_run.crew_contraband_stash[0]).get("copy", "")) != "second":
			failures.append("Knuckles' contact did not stash the selected exact entry before the action boundary.")
		else:
			if not knuckles_module.can_trigger(knuckles_run, knuckles_run.current_environment) \
				or knuckles_module.choice("retrieve_marked_cards_0", knuckles_run, knuckles_run.current_environment).is_empty():
				failures.append("Knuckles' normal contact surface did not expose retrieval after stashing.")
			var retrieve_result := knuckles_module.resolve(knuckles_run, knuckles_run.current_environment, "retrieve_marked_cards_0")
			if not bool(retrieve_result.get("ok", false)) or not bool(_dict(retrieve_result.get("crew_service_result", {})).get("ok", false)) \
				or not knuckles_run.crew_contraband_stash.is_empty() or knuckles_run.inventory.size() != 2:
				failures.append("Knuckles' contact did not expose retrieval through the same normal interaction surface.")

	var lucky_run := _marked_run("CREW-CONTACT-LUCKY")
	lucky_run.crew_recruit_member("crew_lucky")
	_set_fixture_world(lucky_run, ["small_underground_casino", "bar", "motel", "gas_station_casino", "corner_store"])
	var lucky_presence_probe := _presence_environment(lucky_run, "crew_lucky", false)
	var lucky_location := str(lucky_presence_probe.get("world_node_id", ""))
	var lucky_generator := RunGeneratorScript.new(library)
	if not lucky_location.is_empty():
		lucky_generator.next_environment(lucky_run, lucky_location, true)
	var lucky_environment := lucky_run.current_environment
	if not _contact_is_embedded(lucky_environment, "crew_lucky"):
		failures.append("Lucky's generated seeded presence did not expose his available Numbers work.")
	else:
		var lucky_module := EventModuleScript.new()
		lucky_module.setup(library.event("crew_contact_lucky"), library)
		var lucky_choice_ids: Array = []
		for choice_value in lucky_module.choices(lucky_run, lucky_run.current_environment):
			if typeof(choice_value) == TYPE_DICTIONARY:
				lucky_choice_ids.append(str((choice_value as Dictionary).get("id", "")))
		var lucky_result := lucky_module.resolve(lucky_run, lucky_run.current_environment, "start_numbers_collection")
		if not bool(lucky_result.get("ok", false)) or not bool(_dict(lucky_result.get("crew_service_result", {})).get("ok", false)) \
			or not lucky_run.delivery_has_active_run():
			var action_index := int(lucky_run.event_cadence.get("action_index", 0))
			var numbers_action_index := int(lucky_run.numbers_state.action_index)
			var numbers_day := lucky_run.numbers_state.day_at(action_index)
			var numbers_post_action := lucky_run.numbers_state.post_action(numbers_day)
			failures.append("Lucky's contextual contact did not start the existing Numbers route work: %s" % JSON.stringify({
				"service_path": "EventModule.resolve -> crew_lucky_collection -> RunState.numbers_begin_collection_route",
				"world_cursor": lucky_run.current_world_node_id(),
				"environment_world_node": str(lucky_run.current_environment.get("world_node_id", "")),
				"environment_archetype": str(lucky_run.current_environment.get("archetype_id", "")),
				"action_index": action_index,
				"numbers_action_index": numbers_action_index,
				"day": numbers_day,
				"post_action": numbers_post_action,
				"remaining_actions": numbers_post_action - action_index,
				"choice_ids": lucky_choice_ids,
				"contact_result": lucky_result,
				"service_result": lucky_result.get("crew_service_result", {}),
				"delivery_active": lucky_run.delivery_has_active_run(),
				"delivery_snapshot": lucky_run.delivery_snapshot(),
			}))


static func _check_crew_ignoring_regression(library: ContentLibrary, failures: Array) -> void:
	_check_ignored_numeric_normalizer(failures)
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
	var generated_a := CrewIgnoredGoldenProbeScript.capture(library)
	var generated_b := CrewIgnoredGoldenProbeScript.capture(library)
	if JSON.stringify(generated_a) != JSON.stringify(generated_b):
		failures.append("Crew-ignoring production capture was not byte-identical for same-seed twins.")
	var baseline: Variant = JSON.parse_string(FileAccess.get_file_as_string(IGNORED_BASELINE_PATH)) if FileAccess.file_exists(IGNORED_BASELINE_PATH) else null
	if typeof(baseline) != TYPE_DICTIONARY:
		failures.append("Crew-ignoring accepted-main golden fixture is missing or invalid.")
	else:
		var provenance := _dict((baseline as Dictionary).get("provenance", {}))
		if str(provenance.get("change_commit", "")) != IGNORED_BASELINE_CHANGE_COMMIT \
			or str(provenance.get("reason", "")).strip_edges().is_empty() \
			or str(provenance.get("proof", "")).strip_edges().is_empty():
			failures.append("Crew-ignoring golden fixture lacks the audited authored-state provenance.")
		var expected_capture := _normalize_ignored_capture_numeric_types(_dict((baseline as Dictionary).get("capture", {})))
		if JSON.stringify(generated_a) != JSON.stringify(expected_capture):
			failures.append("Crew-ignoring full RunState/current/world environment bytes shifted from accepted main outside authorized anchor ambience.")
			_append_ignored_capture_diff(expected_capture, generated_a, failures)


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
			edges.append({"a": str(node_ids[index - 1]), "b": node_id})
	var start_id := str(node_ids[0]) if not node_ids.is_empty() else ""
	run_state.set_world_map({"version": 3, "seed_text": run_state.seed_text, "start_node_id": start_id, "current_node_id": start_id, "nodes": nodes, "edges": edges, "visited_path": [start_id] if not start_id.is_empty() else []})


static func _generated_path(library: ContentLibrary, member_id: String, path_kind: String) -> Dictionary:
	var run_state := _marked_run("CREW-PRODUCTION-%s-%s" % [member_id, path_kind])
	var definition := CrewRecruitmentModelScript.member_definition(member_id)
	var location := _dict(definition.get(path_kind, {}))
	var archetypes := _string_array(location.get("archetype_ids", []))
	if archetypes.is_empty():
		return {"run_state": run_state, "entered": false}
	var generator := RunGeneratorScript.new(library)
	if member_id == "crew_bishop" and path_kind == "fallback":
		_set_fixture_world(run_state, ["grand_casino"])
		generator.next_environment(run_state, "grand_casino", true)
		return {"run_state": run_state, "entered": generator.enter_grand_casino_room(run_state, "grand_casino_cage")}
	var archetype_id := str(archetypes[0])
	_set_fixture_world(run_state, [archetype_id])
	var scenarios := _string_array(location.get("scenario_ids", []))
	if scenarios.is_empty():
		scenarios = _string_array(location.get("preferred_scenario_ids", []))
	if not scenarios.is_empty():
		var scenario := library.scenario(str(scenarios[0]))
		if not scenario.is_empty():
			run_state.seed_scenario_for_node(archetype_id, scenario)
	generator.next_environment(run_state, archetype_id, true)
	var entered := true
	var layers := _string_array(location.get("layer_ids", []))
	if not layers.is_empty() and str(run_state.current_environment.get("current_layer_id", "")) != str(layers[0]):
		entered = bool(generator.enter_environment_layer(run_state, str(layers[0]), false).get("ok", false))
	return {"run_state": run_state, "entered": entered}


static func _presence_environment(run_state: RunState, member_id: String, configure_world: bool = true) -> Dictionary:
	var definition := CrewRecruitmentModelScript.member_definition(member_id)
	var locations := _string_array(definition.get("presence", []))
	if configure_world:
		_set_fixture_world(run_state, locations)
	var world_ids: Array = []
	for node_value in _array(run_state.world_map.get("nodes", [])):
		if typeof(node_value) == TYPE_DICTIONARY:
			world_ids.append(str((node_value as Dictionary).get("id", "")))
	for location in locations:
		if not world_ids.is_empty() and not world_ids.has(location):
			continue
		var environment := {
			"id": "%s_contact_fixture" % location,
			"archetype_id": location,
			"world_node_id": location,
			"kind": "casino",
			"event_ids": [],
			"resolved_event_ids": [],
			"scenario_patron_ids": [],
		}
		CrewRecruitmentModelScript.apply_to_environment(run_state, environment)
		for presence_value in _array(environment.get("crew_presence", [])):
			if typeof(presence_value) == TYPE_DICTIONARY and str((presence_value as Dictionary).get("member_id", "")) == member_id:
				return environment
	return {}


static func _contact_is_embedded(environment: Dictionary, member_id: String) -> bool:
	if environment.is_empty():
		return false
	var contact_event_id := str(CrewRecruitmentModelScript.member_definition(member_id).get("contact_event_id", ""))
	if not _string_array(environment.get("event_ids", [])).has(contact_event_id):
		return false
	for presence_value in _array(environment.get("crew_presence", [])):
		if typeof(presence_value) == TYPE_DICTIONARY and str((presence_value as Dictionary).get("member_id", "")) == member_id \
			and str((presence_value as Dictionary).get("contact_event_id", "")) == contact_event_id:
			return true
	return false


static func _event_member_id(event_id: String) -> String:
	if event_id in ["recruitment_rook_signpost", "recruitment_rook_leads"]:
		return "crew_rook"
	if event_id.begins_with("crew_contact_"):
		return "crew_%s" % event_id.trim_prefix("crew_contact_")
	if event_id.begins_with("recruitment_"):
		return "crew_%s" % event_id.trim_prefix("recruitment_")
	return ""


static func _presence_has_member(environment: Dictionary, member_id: String) -> bool:
	for presence_value in _array(environment.get("crew_presence", [])):
		if typeof(presence_value) == TYPE_DICTIONARY and str((presence_value as Dictionary).get("member_id", "")) == member_id:
			return true
	return false


static func _presence_has_contact(environment: Dictionary, member_id: String) -> bool:
	var expected_contact := str(CrewRecruitmentModelScript.member_definition(member_id).get("contact_event_id", ""))
	for presence_value in _array(environment.get("crew_presence", [])):
		if typeof(presence_value) == TYPE_DICTIONARY and str((presence_value as Dictionary).get("member_id", "")) == member_id \
			and str((presence_value as Dictionary).get("contact_event_id", "")) == expected_contact:
			return true
	return false


static func _append_ignored_capture_diff(expected: Dictionary, actual: Dictionary, failures: Array) -> void:
	if int(expected.get("schema_version", -1)) != int(actual.get("schema_version", -2)):
		failures.append("Crew-ignoring golden schema changed: expected %s, actual %s." % [expected.get("schema_version"), actual.get("schema_version")])
	var actual_runs := {}
	for run_value in _array(actual.get("runs", [])):
		if typeof(run_value) == TYPE_DICTIONARY:
			actual_runs[str((run_value as Dictionary).get("seed", ""))] = run_value
	for expected_run_value in _array(expected.get("runs", [])):
		if typeof(expected_run_value) != TYPE_DICTIONARY:
			continue
		var expected_run: Dictionary = expected_run_value
		var seed := str(expected_run.get("seed", ""))
		var actual_run := _dict(actual_runs.get(seed, {}))
		if actual_run.is_empty():
			failures.append("Crew-ignoring golden lost seed %s." % seed)
			continue
		var actual_checkpoints := {}
		for checkpoint_value in _array(actual_run.get("checkpoints", [])):
			if typeof(checkpoint_value) == TYPE_DICTIONARY:
				actual_checkpoints[str((checkpoint_value as Dictionary).get("label", ""))] = checkpoint_value
		for expected_checkpoint_value in _array(expected_run.get("checkpoints", [])):
			if typeof(expected_checkpoint_value) != TYPE_DICTIONARY:
				continue
			var expected_checkpoint: Dictionary = expected_checkpoint_value
			var label := str(expected_checkpoint.get("label", ""))
			var actual_checkpoint := _dict(actual_checkpoints.get(label, {}))
			if actual_checkpoint.is_empty():
				failures.append("Crew-ignoring golden %s lost checkpoint %s." % [seed, label])
				continue
			for field in ["run_state_bytes", "run_state_sha256", "current_environment_bytes", "current_environment_sha256", "world_environments_bytes", "world_environments_sha256"]:
				if expected_checkpoint.get(field) != actual_checkpoint.get(field):
					failures.append("Crew-ignoring golden %s/%s %s changed: expected %s, actual %s." % [seed, label, field, expected_checkpoint.get(field), actual_checkpoint.get(field)])


static func _normalize_ignored_capture_numeric_types(value: Dictionary) -> Dictionary:
	# JSON fixtures load number tokens without preserving the runtime integer
	# Variant type. Normalize only those known numeric scalars in-place while
	# retaining every dictionary key, array entry, ordering, and extra field so
	# the following JSON equality remains a full exact-structure golden.
	var result := value.duplicate(true)
	if result.has("schema_version"):
		result["schema_version"] = _normalized_json_integer(result.get("schema_version"))
	var runs := _array(result.get("runs", []))
	for run_index in range(runs.size()):
		if typeof(runs[run_index]) != TYPE_DICTIONARY:
			continue
		var run: Dictionary = runs[run_index]
		var checkpoints := _array(run.get("checkpoints", []))
		for checkpoint_index in range(checkpoints.size()):
			if typeof(checkpoints[checkpoint_index]) != TYPE_DICTIONARY:
				continue
			var checkpoint: Dictionary = checkpoints[checkpoint_index]
			for field in ["run_state_bytes", "current_environment_bytes", "world_environments_bytes"]:
				if checkpoint.has(field):
					checkpoint[field] = _normalized_json_integer(checkpoint.get(field))
			checkpoints[checkpoint_index] = checkpoint
		run["checkpoints"] = checkpoints
		runs[run_index] = run
	result["runs"] = runs
	return result


static func _normalized_json_integer(value: Variant) -> Variant:
	if typeof(value) != TYPE_FLOAT:
		return value
	var number: float = value
	if not is_finite(number) or floor(number) != number or absf(number) > JSON_EXACT_INTEGER_LIMIT:
		return value
	return int(number)


static func _check_ignored_numeric_normalizer(failures: Array) -> void:
	var hostile := {
		"schema_version": "1",
		"runs": [{"seed": "HOSTILE", "checkpoints": [{
			"label": "hostile",
			"run_state_bytes": true,
			"current_environment_bytes": 1.5,
			"world_environments_bytes": "2",
		}]}],
	}
	var hostile_normalized := _normalize_ignored_capture_numeric_types(hostile)
	if JSON.stringify(hostile_normalized) != JSON.stringify(hostile):
		failures.append("Crew-ignoring golden numeric normalization coerced hostile string, bool, or fractional fixture data.")
	var valid_float := {
		"schema_version": 1.0,
		"runs": [{"seed": "VALID", "checkpoints": [{
			"label": "valid",
			"run_state_bytes": 42.0,
			"current_environment_bytes": 43.0,
			"world_environments_bytes": 44.0,
		}]}],
	}
	var valid_normalized := _normalize_ignored_capture_numeric_types(valid_float)
	var valid_checkpoint := _dict(_array(_dict(_array(valid_normalized.get("runs", []))[0]).get("checkpoints", []))[0])
	if typeof(valid_normalized.get("schema_version")) != TYPE_INT \
		or typeof(valid_checkpoint.get("run_state_bytes")) != TYPE_INT \
		or typeof(valid_checkpoint.get("current_environment_bytes")) != TYPE_INT \
		or typeof(valid_checkpoint.get("world_environments_bytes")) != TYPE_INT:
		failures.append("Crew-ignoring golden numeric normalization did not restore exact integral JSON fixture types.")


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
