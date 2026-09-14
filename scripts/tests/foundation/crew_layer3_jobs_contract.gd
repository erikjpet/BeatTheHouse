class_name CrewLayer3JobsContract
extends RefCounted

const CrewRecruitmentModelScript := preload("res://scripts/core/crew_recruitment_model.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const DeliveryRunModelScript := preload("res://scripts/core/delivery_run_model.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")


static func check(library: ContentLibrary, failures: Array) -> void:
	_check_catalog(library, failures)
	_check_host_authority(failures)
	_check_residency(failures)
	_check_board_and_decline(library, failures)
	_check_delivery_kinds(failures)
	_check_stake_horse(failures)
	_check_collection(failures)
	_check_services_and_training(failures)
	_check_save_round_trip(failures)


static func _check_host_authority(failures: Array) -> void:
	var hostile := _crew_run("L3-HOSTILE")
	var before := hostile.to_dict()
	for definition_value in CrewStateModelScript.job_definitions():
		if not hostile.job_offer(definition_value).is_empty():
			failures.append("Caller-authored %s offer crossed the host-only job boundary." % str((definition_value as Dictionary).get("id", "")))
	if hostile.to_dict() != before or not hostile.job_accept("forged").is_empty() or not hostile.job_activate("forged").is_empty() or not hostile.job_resolve("forged", "success").is_empty():
		failures.append("Caller-authored job lifecycle mutated RunState.")
	var recruit_before := hostile.crew_trust("crew_switch")
	if bool(hostile.crew_recruit_member("crew_switch").get("ok", true)) or hostile.crew_trust("crew_switch") != recruit_before:
		failures.append("Caller-authored recruitment crossed the host-only event boundary.")
	for definition_value in CrewStateModelScript.job_definitions():
		var definition: Dictionary = definition_value
		var run := _crew_run("L3-HOST-%s" % str(definition.get("id", "")))
		var member_id := str(definition.get("member_id", ""))
		var required_trust := CrewStateModelScript.rank_threshold(str(definition.get("min_rank", "associate")))
		if run.crew_trust(member_id) < required_trust:
			run.crew_add_trust(member_id, required_trust - run.crew_trust(member_id), "layer3_host_fixture")
		run.current_environment["crew_presence"] = [{"member_id": member_id}]
		var started := run.crew_job_accept_definition(str(definition.get("id", "")))
		if not bool(started.get("ok", false)) or str(_job_by_definition(run, str(definition.get("id", ""))).get("status", "")) != "active":
			failures.append("Host-rooted surface did not activate shipped job %s." % str(definition.get("id", "")))


static func _check_catalog(library: ContentLibrary, failures: Array) -> void:
	var rows := CrewStateModelScript.job_definitions()
	if rows.size() < 10 or rows.size() > 14:
		failures.append("Layer 3 launch catalog must contain 10–14 jobs; found %d." % rows.size())
	var kinds := {}
	var members := {}
	for row_value in rows:
		var row: Dictionary = row_value
		if str(row.get("id", "")) == "crew_favor_delivery":
			continue
		kinds[str(row.get("kind", ""))] = true
		members[str(row.get("member_id", ""))] = true
		if not CrewStateModelScript.RANK_IDS.has(str(row.get("min_rank", ""))) or int(row.get("expiry_in_actions", 0)) <= 0:
			failures.append("Layer 3 job %s lost its rank gate or expiry." % str(row.get("id", "")))
	for kind in ["package_run", "numbers_route", "lookout_hold", "stake_horse", "collection"]:
		if not kinds.has(kind):
			failures.append("Layer 3 launch catalog is missing %s." % kind)
	for member_id in CrewStateModelScript.MEMBER_IDS:
		if not members.has(member_id):
			failures.append("Layer 3 launch catalog has no new work for %s." % member_id)
	for event_id in ["crew_job_board", "crew_planning_table", "crew_practice_rig", "crew_rook_ride", "crew_mags_bench", "numbers_desk"]:
		if library.event(event_id).is_empty():
			failures.append("Layer 3 furniture event %s is missing." % event_id)


static func _check_residency(failures: Array) -> void:
	var a := _crew_run("L3-RESIDENCY")
	var b := _crew_run("L3-RESIDENCY")
	var env := _back_room_environment()
	CrewRecruitmentModelScript.apply_to_environment(a, env)
	var same := _back_room_environment()
	CrewRecruitmentModelScript.apply_to_environment(b, same)
	if JSON.stringify(env.get("crew_presence", [])) != JSON.stringify(same.get("crew_presence", [])):
		failures.append("Layer 3 residency is not seeded and deterministic.")
	var present := a.crew_present_member_ids(env)
	if present.size() < 2 or present.size() > 4:
		failures.append("Layer 3 residency must place two to four met members.")
	for member_id in CrewStateModelScript.MEMBER_IDS:
		if a.crew_member_present(member_id, env) != present.has(member_id):
			failures.append("Layer 3 shared presence readers disagree for %s." % member_id)
	var rotated := _back_room_environment()
	for _index in range(6):
		a.town_state.advance_actions(6)
		CrewRecruitmentModelScript.apply_to_environment(a, rotated)
		if JSON.stringify(rotated.get("crew_presence", [])) != JSON.stringify(env.get("crew_presence", [])):
			break
	if JSON.stringify(rotated.get("crew_presence", [])) == JSON.stringify(env.get("crew_presence", [])):
		failures.append("Layer 3 residency did not rotate across six seeded schedule segments.")


static func _check_board_and_decline(library: ContentLibrary, failures: Array) -> void:
	var run := _crew_run("L3-BOARD")
	run.current_environment = _back_room_environment()
	CrewRecruitmentModelScript.apply_to_environment(run, run.current_environment)
	for member_id in run.crew_present_member_ids():
		var has_direct_offer := false
		for choice_value in CrewRecruitmentModelScript.contact_choices(run, run.current_environment, member_id, library):
			var choice: Dictionary = choice_value
			for hook_value in ((choice.get("consequences", {}) as Dictionary).get("event_hooks", []) as Array):
				if typeof(hook_value) == TYPE_DICTIONARY and str((hook_value as Dictionary).get("type", "")) == "crew_job_accept":
					has_direct_offer = true
		if not has_direct_offer:
			failures.append("Present Layer 3 member %s did not offer launch work in person." % member_id)
	var offers := run.crew_job_board_offers()
	var expected_offer_count := 0
	for definition_value in CrewStateModelScript.job_definitions():
		var definition: Dictionary = definition_value
		if str(definition.get("id", "")) != "crew_favor_delivery" \
			and run.crew_member_present(str(definition.get("member_id", ""))) \
			and CrewStateModelScript.RANK_IDS.find(run.crew_rank(str(definition.get("member_id", "")))) >= CrewStateModelScript.RANK_IDS.find(str(definition.get("min_rank", "associate"))):
			expected_offer_count += 1
	if offers.size() != expected_offer_count:
		failures.append("Layer 3 board did not surface every present, rank-eligible launch job; expected %d, found %d." % [expected_offer_count, offers.size()])
	var absent_member_found := false
	for member_id in CrewStateModelScript.MEMBER_IDS:
		if not run.crew_member_present(member_id):
			absent_member_found = true
	for offer_value in offers:
		if not run.crew_member_present(str((offer_value as Dictionary).get("member_id", ""))):
			failures.append("Layer 3 board exposed work for an absent crew member.")
	if not absent_member_found:
		failures.append("Layer 3 board fixture did not leave an absent member to prove the presence filter.")
	var event := EventModuleScript.new()
	event.setup(library.event("crew_job_board"), library)
	var initial_choices := event.choices(run, run.current_environment)
	var flavor_lines: Array = ((library.event("crew_job_board").get("payload", {}) as Dictionary).get("flavor_lines", []) as Array)
	var flavor_occurrences := 0
	for choice_value in initial_choices:
		var choice_text := str((choice_value as Dictionary).get("text", ""))
		for flavor_value in flavor_lines:
			if choice_text.contains(str(flavor_value)):
				flavor_occurrences += 1
	if initial_choices.size() > 2 and flavor_occurrences != 1:
		failures.append("Layer 3 job-board flavor must appear once, not repeat down a multi-offer board.")
	var same_seed := _crew_run("L3-BOARD")
	same_seed.current_environment = _back_room_environment()
	CrewRecruitmentModelScript.apply_to_environment(same_seed, same_seed.current_environment)
	if JSON.stringify(initial_choices) != JSON.stringify(event.choices(same_seed, same_seed.current_environment)):
		failures.append("Layer 3 job-board flavor is not seeded and deterministic.")
	run.event_cadence_advance_actions(1)
	var rotated_choices := event.choices(run, run.current_environment)
	if not initial_choices.is_empty() and not rotated_choices.is_empty() \
		and str((initial_choices[0] as Dictionary).get("text", "")) == str((rotated_choices[0] as Dictionary).get("text", "")):
		failures.append("Layer 3 job-board flavor did not rotate at an action boundary.")
	var before := run.crew_grievance_ledger.size()
	var result := event.resolve(run, run.current_environment, "leave")
	if not bool(result.get("ok", false)) or run.crew_grievance_ledger.size() != before:
		failures.append("Declining the Layer 3 board wrote a grievance or failed to resolve safely.")


static func _check_delivery_kinds(failures: Array) -> void:
	for definition_id in ["rook_quiet_package", "switch_two_stop_signal", "bishop_camera_window"]:
		var run := _crew_run("L3-DELIVERY-%s" % definition_id)
		var started := _accept_job(run, definition_id)
		if not bool(started.get("ok", false)):
			failures.append("Layer 3 job %s did not enter the real-map delivery framework: %s" % [definition_id, str(started.get("message", ""))])
			continue
		var expected_mode := "package" if definition_id == "rook_quiet_package" else "multi_stop" if definition_id == "switch_two_stop_signal" else "hold"
		if str(run.delivery_snapshot().get("mode", "")) != expected_mode:
			failures.append("Layer 3 job %s used the wrong delivery mode." % definition_id)
		if expected_mode == "hold":
			var target := str(((run.delivery_snapshot().get("targets", []) as Array)[0] as Dictionary).get("node_id", ""))
			run.world_map["current_node_id"] = target
			run.advance_environment_turns(3)
			if str(_job_by_definition(run, definition_id).get("outcome", "")) != "success":
				failures.append("Layer 3 lookout hold did not resolve through delivery boundaries.")
		else:
			_complete_all_handoffs(run)
			if str(_job_by_definition(run, definition_id).get("outcome", "")) != "success":
				failures.append("Layer 3 %s did not complete end to end." % definition_id)


static func _check_stake_horse(failures: Array) -> void:
	var win := _crew_run("L3-STAKE-WIN")
	var started := _accept_job(win, "mags_low_roller_stake")
	var job_id := str(started.get("job_id", ""))
	win.crew_record_game_result({"game_id": "blackjack", "environment_archetype_id": "small_underground_casino"}, {"bankroll_delta": 12})
	if str(win.crew_jobs.get(job_id, {}).get("outcome", "")) != "success":
		failures.append("Stake-horse target win did not split and resolve success.")
	for choice_id in ["repay", "shrug"]:
		var loss := _crew_run("L3-STAKE-%s" % choice_id)
		var loss_start := _accept_job(loss, "lucky_slot_stake")
		loss.crew_record_game_result({"game_id": "slot", "environment_archetype_id": "gas_station_casino"}, {"bankroll_delta": -18})
		var resolved := loss.crew_resolve_stake_horse_loss(choice_id)
		var grievance_count := 0
		for grievance_value in loss.crew_grievance_ledger:
			if str((grievance_value as Dictionary).get("kind", "")) == "stake_horse_loss_shrugged":
				grievance_count += 1
		if not bool(resolved.get("ok", false)) or grievance_count != (1 if choice_id == "shrug" else 0):
			failures.append("Stake-horse %s choice wrote the wrong grievance count." % choice_id)
		if str(loss.crew_jobs.get(str(loss_start.get("job_id", "")), {}).get("outcome", "")) != "failed":
			failures.append("Stake-horse %s choice did not close the job." % choice_id)


static func _check_collection(failures: Array) -> void:
	for choice_id in ["friendly", "press"]:
		var run := _crew_run("L3-COLLECTION-%s" % choice_id)
		var started := _accept_job(run, "knuckles_friendly_collection")
		_complete_all_handoffs(run)
		var before_heat := run.suspicion_level()
		var result := run.crew_resolve_collection(choice_id)
		if not bool(result.get("ok", false)) or str(run.crew_jobs.get(str(started.get("job_id", "")), {}).get("outcome", "")) != "success":
			failures.append("Collection %s beat did not resolve the two-beat chain." % choice_id)
		if choice_id == "friendly" and run.suspicion_level() != before_heat:
			failures.append("Friendly collection unexpectedly raised heat.")
		if choice_id == "press" and run.suspicion_level() <= before_heat:
			failures.append("Hard collection did not trade heat for cash.")


static func _check_services_and_training(failures: Array) -> void:
	var run := _crew_run("L3-SERVICES")
	run.current_environment = _back_room_environment()
	run.current_environment["travel_lock_remaining"] = 2
	if bool(run.crew_rook_begin_ride().get("ok", false)):
		failures.append("Rook's ride bypassed a canonical travel lock.")
	run.current_environment["travel_lock_remaining"] = 0
	var route := {"cost": 10, "distance": "near", "travel_method_kind": "car"}
	var baseline_cost := int(run.travel_route_status(route).get("cost", -1))
	var ride := run.crew_rook_begin_ride()
	var ride_cost := int(run.travel_route_status(route).get("cost", -1))
	if not bool(ride.get("ok", false)) or ride_cost != int(ceil(float(baseline_cost) * 0.5)):
		failures.append("Associate Rook ride did not apply its data-tuned 50% route discount.")
	run.crew_rook_finish_ride()
	if int(run.crew_rook_ride_status().get("uses_remaining", -1)) != 0:
		failures.append("Rook's ride did not consume its rank-capped use.")
	for _index in range(2):
		var target := str(run.crew_practice_rig_readout().get("target_window", ""))
		if not bool(run.crew_practice_rig_session(target).get("hit", false)):
			failures.append("Practice Rig rejected its deterministic target window.")
	if int(run.narrative_flags.get("craps_setting_street_progress", 0)) != 2 or not bool(run.narrative_flags.get("craps_setting_trained", false)):
		failures.append("Practice Rig did not grant the shared Street Craps training pool and flag.")
	if not bool(run.crew_mags_bench_status().get("available", false)) or not bool(run.crew_mags_bench_status().get("catalog_ready", false)):
		failures.append("Mags' bench did not expose its content06_1 catalog.")


static func _check_save_round_trip(failures: Array) -> void:
	var run := _crew_run("L3-SAVE")
	run.current_environment = _back_room_environment()
	CrewRecruitmentModelScript.apply_to_environment(run, run.current_environment)
	var target := str(run.crew_practice_rig_readout().get("target_window", ""))
	run.crew_practice_rig_session(target)
	_accept_job(run, "mags_low_roller_stake")
	var before := {"offers": run.crew_job_board_offers(), "presence": run.crew_present_member_ids(), "rig": run.crew_practice_rig_readout()}
	var restored := RunStateScript.new()
	restored.from_dict(run.to_dict())
	var after := {"offers": restored.crew_job_board_offers(), "presence": restored.crew_present_member_ids(), "rig": restored.crew_practice_rig_readout()}
	if JSON.stringify(before) != JSON.stringify(after):
		failures.append("Layer 3 board, residency, or Practice Rig progress failed save/load round-trip.")


static func _crew_run(seed: String) -> RunState:
	var run := RunStateScript.new()
	run.start_new(seed)
	for member_id in CrewStateModelScript.MEMBER_IDS:
		run.crew_add_trust(member_id, CrewStateModelScript.rank_threshold("associate"), "layer3_fixture")
	_set_fixture_world(run)
	run.current_environment = _back_room_environment()
	return run


static func _set_fixture_world(run: RunState) -> void:
	var ids := ["small_underground_casino", "bar", "gas_station_casino", "kitty_cat_lounge", "delta_queen", "grand_casino", "motel"]
	var nodes: Array = []
	var edges: Array = []
	for index in range(ids.size()):
		var node_id := str(ids[index])
		nodes.append({"id": node_id, "archetype_id": node_id, "kind": "casino", "tier": 2, "state": "visited", "seen": true, "environment": {}})
		if index > 0:
			edges.append({"a": str(ids[index - 1]), "b": node_id})
	run.set_world_map({"version": 3, "seed_text": run.seed_text, "start_node_id": ids[0], "current_node_id": ids[0], "nodes": nodes, "edges": edges, "visited_path": [ids[0]]})


static func _back_room_environment() -> Dictionary:
	return {"id": "l3_fixture", "archetype_id": "small_underground_casino", "world_node_id": "small_underground_casino", "current_layer_id": "back_room", "kind": "crew", "event_ids": ["crew_job_board", "crew_planning_table", "crew_practice_rig", "crew_rook_ride", "crew_mags_bench", "numbers_desk"], "resolved_event_ids": [], "scenario_patron_ids": [], "turns": 0}


static func _complete_all_handoffs(run: RunState) -> void:
	var physical: Dictionary = run.delivery_snapshot().get("physical", {})
	if str(physical.get("cargo_state", "")) == "pickup_pending":
		run.delivery_apply_physical_action("pickup", "crew_layer3:pickup:%s" % str(run.active_delivery_run.get("run_id", "delivery")))
	while run.delivery_has_active_run():
		var snapshot := run.delivery_snapshot()
		var pending := ""
		for target_value in snapshot.get("targets", []):
			var target: Dictionary = target_value
			if str(target.get("status", "pending")) == "pending":
				pending = str(target.get("node_id", ""))
				break
		if pending.is_empty():
			break
		run.world_map["current_node_id"] = pending
		run.delivery_resolve_travel_arrival()
		run.delivery_complete_handoff(pending)


static func _accept_job(run: RunState, definition_id: String) -> Dictionary:
	var definition := CrewStateModelScript.job_definition(definition_id)
	var member_id := str(definition.get("member_id", ""))
	run.current_environment["crew_presence"] = [{"member_id": member_id}]
	return run.crew_job_accept_definition(definition_id)


static func _job_by_definition(run: RunState, definition_id: String) -> Dictionary:
	for job_value in run.crew_jobs.values():
		if typeof(job_value) == TYPE_DICTIONARY and str((job_value as Dictionary).get("definition_id", "")) == definition_id:
			return (job_value as Dictionary).duplicate(true)
	return {}
