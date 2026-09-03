class_name CrewTurnContract
extends RefCounted

const RunStateScript := preload("res://scripts/core/run_state.gd")
const CrewHeistModelScript := preload("res://scripts/core/crew_heist_model.gd")
const CrewTurnModelScript := preload("res://scripts/core/crew_turn_model.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const DeliveryRunModelScript := preload("res://scripts/core/delivery_run_model.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const RunReportViewModelScript := preload("res://scripts/ui/run_report_view_model.gd")
const RunSaveCodecScript := preload("res://scripts/core/run_save_codec.gd")
const SaveServiceScript := preload("res://scripts/core/save_service.gd")
const GameModuleScript := preload("res://scripts/core/game_module.gd")
const CrewHeistContractScript := preload("res://scripts/tests/foundation/crew_heist_contract.gd")


static func check(_library: ContentLibrary, failures: Array) -> void:
	failures.append_array(CrewTurnModelScript.validate_tuning(_tuning()))
	_check_eligibility_and_clean_hands(failures)
	_check_weighting(failures)
	_check_emissions(failures)
	_check_choices_and_save(failures)
	_check_plan_beats(_library, failures)


static func _check_eligibility_and_clean_hands(failures: Array) -> void:
	var met := CrewStateModelScript.MEMBER_IDS.duplicate()
	for plan_id in CrewHeistModelScript.PLAN_IDS:
		var expected := ["crew_knuckles", "crew_switch", "crew_mags", "crew_lucky", "crew_velvet"] if plan_id == CrewHeistModelScript.PLAN_COUNT else ["crew_knuckles", "crew_switch", "crew_bishop", "crew_lucky"]
		expected.sort()
		var eligible := CrewTurnModelScript.eligible_members(CrewHeistModelScript.plan(plan_id), met, CrewStateModelScript.MEMBER_IDS)
		if eligible != expected:
			failures.append("Hidden heist pool for %s was %s, expected %s." % [plan_id, JSON.stringify(eligible), JSON.stringify(expected)])
		var ledgers: Array = []
		for member_id in eligible:
			ledgers.append({"member_id": member_id, "weight": 9})
		for seed in range(1, 601):
			var selected := str(CrewTurnModelScript.resolve(CrewHeistModelScript.plan(plan_id), met, ledgers, CrewStateModelScript.MEMBER_IDS, {"chance_percent_per_weight": 100, "chance_percent_cap": 100, "wrong_choice_chance_percent": 18}, _rng(seed)).get("m", ""))
			if not eligible.has(selected) or selected == "crew_rook" or _array(CrewHeistModelScript.plan(plan_id).get("architects", [])).has(selected):
				failures.append("Hidden heist pool selected an ineligible chair for %s at seed %d." % [plan_id, seed])
				break
		var zero_hits := 0
		for seed in range(1, 1201):
			if not str(CrewTurnModelScript.resolve(CrewHeistModelScript.plan(plan_id), met, [], CrewStateModelScript.MEMBER_IDS, _tuning(), _rng(seed)).get("m", "")).is_empty():
				zero_hits += 1
		if zero_hits != 0:
			failures.append("Clean crew produced %d hidden failures for %s." % [zero_hits, plan_id])


static func _check_weighting(failures: Array) -> void:
	var ledgers := [{"member_id": "crew_switch", "weight": 1}, {"member_id": "crew_lucky", "weight": 8}]
	var counts := {"crew_switch": 0, "crew_lucky": 0}
	for seed in range(1, 1801):
		var member_id := str(CrewTurnModelScript.resolve(CrewHeistModelScript.plan(CrewHeistModelScript.PLAN_COUNT), CrewStateModelScript.MEMBER_IDS, ledgers, CrewStateModelScript.MEMBER_IDS, {"chance_percent_per_weight": 100, "chance_percent_cap": 100, "wrong_choice_chance_percent": 18}, _rng(seed)).get("m", ""))
		if counts.has(member_id):
			counts[member_id] = int(counts.get(member_id, 0)) + 1
	if int(counts.get("crew_lucky", 0)) < int(counts.get("crew_switch", 0)) * 4:
		failures.append("Ledger weighting did not materially favor the heavier member: %s." % JSON.stringify(counts))
	var base_hits := 0
	var escalated_hits := 0
	for seed in range(1, 2401):
		if not str(CrewTurnModelScript.resolve(CrewHeistModelScript.plan(CrewHeistModelScript.PLAN_COUNT), CrewStateModelScript.MEMBER_IDS, [{"member_id": "crew_switch", "weight": 1}], CrewStateModelScript.MEMBER_IDS, _tuning(), _rng(seed), 0).get("m", "")).is_empty():
			base_hits += 1
		if not str(CrewTurnModelScript.resolve(CrewHeistModelScript.plan(CrewHeistModelScript.PLAN_COUNT), CrewStateModelScript.MEMBER_IDS, [{"member_id": "crew_switch", "weight": 1}], CrewStateModelScript.MEMBER_IDS, _tuning(), _rng(seed), 1).get("m", "")).is_empty():
			escalated_hits += 1
	if escalated_hits <= base_hits:
		failures.append("Wrong-name escalation did not raise the real member's deterministic resolution curve: %d <= %d." % [escalated_hits, base_hits])


static func _check_emissions(failures: Array) -> void:
	var unlearned := _run("TURN-SKILL-OFF")
	_prepare(unlearned, "crew_switch", [CrewTurnModelScript.SIGNAL_PATTERN])
	var off := _heist_choice(unlearned, "crew_planning_table", "table_talk")
	if CrewTurnModelScript.witnessed_count(_dict(unlearned.crew_heist_state.get("x", {})), CrewStateModelScript.MEMBER_IDS) != 0 or str(off.get("message", "")).contains("No cards"):
		failures.append("Unlearned planning pattern became distinguishable.")
	var learned := _run("TURN-SKILL-ON")
	_prepare(learned, "crew_switch", [CrewTurnModelScript.SIGNAL_PATTERN])
	for _index in range(3):
		learned.crew_record_pattern("crew_switch", "p07")
	var on := _heist_choice(learned, "crew_planning_table", "table_talk")
	if CrewTurnModelScript.witnessed_count(_dict(learned.crew_heist_state.get("x", {})), CrewStateModelScript.MEMBER_IDS) != 1 or not str(on.get("message", "")).contains("No cards"):
		failures.append("Learned planning pattern did not become witnessable.")

	var route := _run("TURN-ROUTE")
	_prepare(route, "crew_switch", [CrewTurnModelScript.SIGNAL_ROUTE])
	var route_hidden := _dict(route.crew_heist_state.get("x", {}))
	route_hidden["e"] = [CrewTurnModelScript.SIGNAL_PATTERN]
	route.crew_heist_state["x"] = route_hidden
	route.world_map = {"nodes": [
		{"id": "bar", "label": "Low Tide", "state": "visited", "environment": {"entered_game_clock_minutes": 540, "departed_game_clock_minutes": 600, "crew_presence": [{"member_id": "crew_switch"}]}},
		{"id": "motel", "label": "Motor Court", "state": "visited", "environment": {}},
	]}
	_heist_choice(route, "crew_planning_table", "table_talk")
	if CrewTurnModelScript.witnessed_count(_dict(route.crew_heist_state.get("x", {})), CrewStateModelScript.MEMBER_IDS) != 1:
		failures.append("Contradictable itinerary line did not land through a visited world record.")
	var no_record := _run("TURN-NO-ROUTE")
	_prepare(no_record, "crew_switch", [CrewTurnModelScript.SIGNAL_ROUTE])
	var no_record_hidden := _dict(no_record.crew_heist_state.get("x", {}))
	no_record_hidden["e"] = [CrewTurnModelScript.SIGNAL_PATTERN]
	no_record.crew_heist_state["x"] = no_record_hidden
	no_record.world_map = {"nodes": [{"id": "bar", "label": "Low Tide", "state": "revealed", "environment": {"crew_presence": [{"member_id": "crew_switch"}]}}]}
	_heist_choice(no_record, "crew_planning_table", "table_talk")
	if CrewTurnModelScript.witnessed_count(_dict(no_record.crew_heist_state.get("x", {})), CrewStateModelScript.MEMBER_IDS) != 0:
		failures.append("Itinerary line landed without player-checkable evidence.")

	var payment := _run("TURN-PAYMENT")
	_prepare(payment, "crew_switch", [CrewTurnModelScript.SIGNAL_PAYMENT])
	var job_id := "fixture_job:0001"
	var job := {"id": job_id, "definition_id": "fixture_job", "label": "Fixture job", "member_id": "crew_switch", "kind": "package_run", "min_rank": "associate", "status": "active", "outcome": "", "payload": {}, "expiry_in_actions": 8, "offered_action": 0, "accepted_action": 0, "active_action": 0, "expires_at_action": 8, "rewards": {"cash": 40, "trust": 1}, "failure": {"trust": -1, "grievance_kind": "job_abandoned", "grievance_weight": 1}}
	payment.crew_jobs[job_id] = job
	payment.active_delivery_run = DeliveryRunModelScript.begin({"run_id": "fixture_route", "job_id": str(job.get("id", "")), "start_node_id": "bar", "targets": [{"node_id": "motel"}], "deadline_actions": 4}, 0)
	payment.active_delivery_run = DeliveryRunModelScript.apply_host_action(payment.active_delivery_run, "pickup", "turn:payment:pickup", {
		"schema_version": 1, "node_id": "bar", "destination_node_id": "", "target_id": "delivery_pickup", "place_id": "",
		"cover_id": "", "signal_id": "", "reason": "", "attention": 0, "action_index": 0,
	})
	payment.active_delivery_run = DeliveryRunModelScript.apply_host_action(payment.active_delivery_run, "move", "turn:payment:move", {
		"schema_version": 1, "node_id": "bar", "destination_node_id": "motel", "target_id": "", "place_id": "",
		"cover_id": "", "signal_id": "", "reason": "fixture_route", "attention": 0, "action_index": 1,
	})
	payment.current_environment["world_node_id"] = "motel"
	payment.world_map["current_node_id"] = "motel"
	var paid := payment.delivery_complete_handoff("motel")
	var receipt := _dict(_dict(paid.get("snapshot", {})).get("receipt", {}))
	if int(receipt.get("posted_cash", 0)) != 40 or int(receipt.get("paid_cash", 40)) >= 40 or not str(paid.get("message", "")).contains("board says $40"):
		failures.append("Production handoff did not surface the light envelope's checkable posted figure.")


static func _check_choices_and_save(failures: Array) -> void:
	var correct := _run("TURN-RIGHT")
	_prepare(correct, "crew_switch", [CrewTurnModelScript.SIGNAL_PATTERN, CrewTurnModelScript.SIGNAL_ROUTE], true)
	var correct_result := _heist_choice(correct, "crew_planning_table", "close_door_switch")
	if not bool(correct_result.get("ok", false)) or not bool(_dict(correct.crew_heist_state.get("x", {})).get("c", false)) or int(_dict(correct.crew_heist_state.get("play", {})).get("free_play", 0)) != 1:
		failures.append("Correct two-signal close-out failed to cancel and grant one coordinated use.")
	var wrong := _run("TURN-WRONG")
	_prepare(wrong, "crew_switch", [CrewTurnModelScript.SIGNAL_PATTERN, CrewTurnModelScript.SIGNAL_ROUTE], true)
	wrong.grievance_add({"member_id": "crew_switch", "kind": "job_abandoned", "weight": 1, "source_ref": "fixture_real"})
	var before := wrong.crew_trust("crew_lucky")
	var wrong_result := _heist_choice(wrong, "crew_planning_table", "close_door_lucky")
	var wrong_hidden := _dict(wrong.crew_heist_state.get("x", {}))
	if not bool(wrong_result.get("ok", false)) or wrong.crew_trust("crew_lucky") >= before or wrong.crew_grievances("crew_lucky").is_empty() or not ["", "crew_switch"].has(str(wrong_hidden.get("m", ""))) or int(wrong_hidden.get("f", 0)) != 1 or (str(wrong_hidden.get("m", "")).is_empty() and (not _array(wrong_hidden.get("e", [])).is_empty() or not _array(wrong_hidden.get("w", [])).is_empty())):
		failures.append("Wrong close-out missed its personal debt, crew trust cost, re-resolution, or darkened mood.")
	var hedge := _run("TURN-HEDGE")
	_prepare(hedge, "crew_switch", [CrewTurnModelScript.SIGNAL_PATTERN], true)
	var hedge_result := _heist_choice(hedge, "crew_planning_table", "change_seat")
	if not bool(hedge_result.get("ok", false)) or not bool(_dict(hedge.crew_heist_state.get("x", {})).get("h", false)):
		failures.append("Exactly-one-signal role change was not available.")
	var empty_hedge := _run("TURN-HEDGE-CLEAN")
	_prepare(empty_hedge, "", [CrewTurnModelScript.SIGNAL_PATTERN], true)
	var empty_trust_before := empty_hedge.crew_trust("crew_rook")
	if not bool(_heist_choice(empty_hedge, "crew_planning_table", "change_seat").get("ok", false)) or empty_hedge.crew_trust("crew_rook") != empty_trust_before - int(_tuning().get("hedge_trust_cost", 2)):
		failures.append("A clean-table hedge did not charge the documented minor crew trust cost.")

	var action_surfaces: Array = [
		correct_result,
		wrong_result,
		hedge_result,
	]
	var observe_probe := _run("TURN-DISCIPLINE-OBSERVE")
	_prepare(observe_probe, "crew_switch", [CrewTurnModelScript.SIGNAL_PATTERN])
	action_surfaces.append(_heist_choice(observe_probe, "crew_planning_table", "table_talk"))
	wrong.story_log = []
	var clean_save_text := JSON.stringify(_run("TURN-CLEAN-SAVE").to_save_snapshot()).to_lower()
	if clean_save_text.contains("grievance"):
		failures.append("A clean persistent save names the hidden ledger.")
	var save_service := SaveServiceScript.new()
	var sync_payload := _dict(save_service.call("_save_payload", wrong, "fixture"))
	var expected_encoded := RunSaveCodecScript.encode(wrong.to_save_snapshot())
	if JSON.stringify(sync_payload.get("run_state", {})) != JSON.stringify(expected_encoded):
		failures.append("Synchronous save projection diverged from the opaque async snapshot path.")
	var report := RunReportViewModelScript.build(wrong.to_dict())
	var public_save := wrong.to_save_snapshot()
	public_save["crew_state"].erase("a")
	public_save["crew_state"].erase("z")
	var surfaces := JSON.stringify(wrong.crew_heist_table_choices()) + JSON.stringify(public_save) + JSON.stringify(wrong.story_log) + JSON.stringify(action_surfaces) + JSON.stringify(report) + JSON.stringify(wrong.act_two_seam_payload()) + FileAccess.get_file_as_string("res://data/challenges/challenges.json")
	for forbidden in ["traitor", "clue", "betrayal", "the_turn", "grievance"]:
		if surfaces.to_lower().contains(forbidden):
			failures.append("Hidden heist discipline leaked '%s' through choices, action results, save, or story." % forbidden)
	var restored := RunStateScript.new()
	restored.from_dict(wrong.to_save_snapshot())
	if JSON.stringify(_ledger_semantics(restored.crew_grievances())) != JSON.stringify(_ledger_semantics(wrong.crew_grievances())):
		failures.append("Opaque ledger did not round-trip.")
	var legacy := _run("TURN-LEGACY")
	var legacy_data := legacy.to_dict()
	legacy_data["crew_state"].erase("a")
	legacy_data["crew_state"].erase("z")
	legacy_data["crew_state"]["grievances"] = [{"id": "old", "member_id": "crew_switch", "kind": "job_abandoned", "weight": 2, "turn_recorded": 3, "source_ref": "old_job"}]
	legacy_data["crew_state"]["grievance_sequence"] = 1
	var legacy_restored := RunStateScript.new()
	legacy_restored.from_dict(legacy_data)
	if legacy_restored.crew_grievances("crew_switch").size() != 1 or JSON.stringify(legacy_restored.to_save_snapshot()).to_lower().contains("grievance"):
		failures.append("Legacy semantic crew debt did not migrate into the opaque persistent projection.")
	var twin_a := _run("TURN-DETERMINISM")
	var twin_b := _run("TURN-DETERMINISM")
	_prepare(twin_a, "crew_switch", [CrewTurnModelScript.SIGNAL_PATTERN, CrewTurnModelScript.SIGNAL_ROUTE], true)
	_prepare(twin_b, "crew_switch", [CrewTurnModelScript.SIGNAL_PATTERN, CrewTurnModelScript.SIGNAL_ROUTE], true)
	twin_a.grievance_add({"member_id": "crew_switch", "kind": "job_abandoned", "weight": 1, "source_ref": "fixture_real"})
	twin_b.grievance_add({"member_id": "crew_switch", "kind": "job_abandoned", "weight": 1, "source_ref": "fixture_real"})
	var twin_result_a := _heist_choice(twin_a, "crew_planning_table", "close_door_lucky")
	var twin_result_b := _heist_choice(twin_b, "crew_planning_table", "close_door_lucky")
	if JSON.stringify(twin_result_a) != JSON.stringify(twin_result_b) or JSON.stringify(twin_a.crew_heist_state) != JSON.stringify(twin_b.crew_heist_state):
		failures.append("Identical wrong-name sequences did not reproduce byte-identically.")


static func _check_plan_beats(library: ContentLibrary, failures: Array) -> void:
	var count := _run("TURN-BEAT-COUNT")
	_prepare(count, "crew_switch", [], true, CrewHeistModelScript.PLAN_COUNT)
	count.crew_heist_state["status"] = CrewHeistModelScript.STATUS_GETAWAY
	count.crew_heist_state["play"] = {"round": 3, "score": 100, "decisions": {"go": "hold", "distraction": "sit", "exit": "dock"}}
	var count_heat := count.suspicion_level()
	count._crew_heist_apply_delivery_resolution("heist:%s:getaway" % CrewHeistModelScript.PLAN_COUNT, true, {"status": "success"})
	var count_snapshot := count.crew_heist_snapshot()
	if str(count_snapshot.get("status", "")) != CrewHeistModelScript.STATUS_COMPLETED or str(count_snapshot.get("outcome", "")) != "closed" or str(_dict(count_snapshot.get("getaway", {})).get("scar", "")) != "corridor_breach" or not bool(_dict(count_snapshot.get("getaway", {})).get("corridor_failed", false)) or count.suspicion_level() <= count_heat or count.run_status != RunStateScript.RUN_STATUS_ENDED:
		failures.append("Plan A did not collapse mechanically at the corridor with its story scar.")

	var whale := _whale_play_run("TURN-BEAT-WHALE", false)
	var whale_heat := whale.suspicion_level()
	var whale_result := _settle_whale_blackjack(whale, library)
	var whale_snapshot := whale.crew_heist_snapshot()
	if not bool(whale_result.get("resolved", false)) or str(whale_snapshot.get("outcome", "")) != "closed" or str(_dict(whale_snapshot.get("play", {})).get("scar", "")) != "rig_exposure" or str(_dict(whale_snapshot.get("play", {})).get("interrupted", "")) != "house_points_at_rig" or whale.grand_casino_chips != 0 or whale.suspicion_level() <= whale_heat or whale.run_status != RunStateScript.RUN_STATUS_ENDED:
		failures.append("Plan B did not expose the rig mechanically during the live Play.")

	var hedged_whale := _whale_play_run("TURN-BEAT-WHALE-HEDGE", true)
	var hedge_bankroll := hedged_whale.bankroll
	var hedge_result := _settle_whale_blackjack(hedged_whale, library)
	var hedge_payout := int(hedge_result.get("payout", 0))
	if str(hedged_whale.crew_heist_snapshot().get("outcome", "")) != "out_hot" or hedge_payout < 227 or hedge_payout > 357 or hedged_whale.bankroll != hedge_bankroll + hedge_payout:
		failures.append("A Plan B changed seat did not convert the mid-game break into deterministic Out Hot partial haul.")

	var cancelled := _run("TURN-CANCEL-FINALE")
	_prepare(cancelled, "crew_switch", [CrewTurnModelScript.SIGNAL_PATTERN, CrewTurnModelScript.SIGNAL_ROUTE], true)
	_heist_choice(cancelled, "crew_planning_table", "close_door_switch")
	cancelled.crew_heist_state["status"] = CrewHeistModelScript.STATUS_GETAWAY
	cancelled.crew_heist_state["play"] = {"round": 3, "score": 100, "decisions": {"go": "hold", "distraction": "sit", "exit": "dock"}, "free_play": 1}
	cancelled._crew_heist_apply_delivery_resolution("heist:%s:getaway" % CrewHeistModelScript.PLAN_COUNT, true, {"status": "success"})
	if str(cancelled.crew_heist_snapshot().get("outcome", "")) == "closed" or cancelled.run_status != RunStateScript.RUN_STATUS_ENDED:
		failures.append("Correct cancellation did not survive through the ordinary finale.")
	for plan_id in CrewHeistModelScript.PLAN_IDS:
		if not CrewHeistModelScript.ending_line(plan_id, "closed").contains("The Turn"):
			failures.append("Plan %s lacks its ending-only named copy." % plan_id)


static func _whale_play_run(seed: String, hedged: bool) -> RunState:
	var run := _run(seed)
	_prepare(run, "crew_bishop", [CrewTurnModelScript.SIGNAL_PATTERN], true, CrewHeistModelScript.PLAN_WHALE)
	var hidden := _dict(run.crew_heist_state.get("x", {}))
	hidden["h"] = hedged
	run.crew_heist_state["x"] = hidden
	run.crew_heist_state["status"] = CrewHeistModelScript.STATUS_PLAY
	run.crew_heist_state["play"] = {"round": 1, "score": 100, "pot": 650, "decisions": {}, "hazards": [], "lifelines_used": []}
	run.current_environment = {"id": "fixture_high_limit", "archetype_id": "grand_casino_high_limit"}
	run.grand_casino_chips = 650
	return run


static func _heist_choice(run: RunState, event_id: String, choice_id: String) -> Dictionary:
	var event_ids := _array(run.current_environment.get("event_ids", []))
	if not event_ids.has(event_id): event_ids.append(event_id)
	run.current_environment["event_ids"] = event_ids
	run.current_environment["resolved_event_ids"] = []
	run.current_environment["world_node_id"] = str(run.current_environment.get("world_node_id", "fixture_node"))
	if str(run.current_environment.get("world_node_id", "")).is_empty(): run.current_environment["world_node_id"] = "fixture_node"
	run.world_map["current_node_id"] = str(run.current_environment.get("world_node_id", "fixture_node"))
	var choices := run.crew_heist_table_choices() if event_id == "crew_planning_table" else run.crew_heist_live_table_choices()
	var hooks: Array = []
	for choice_value in choices:
		var choice := _dict(choice_value)
		if str(choice.get("id", "")) == choice_id:
			hooks = _array(_dict(choice.get("consequences", {})).get("event_hooks", []))
			break
	return run.crew_record_heist_event_result({"ok": true, "type": "event", "event_id": event_id, "choice_id": choice_id, "deltas": {"event_hooks": hooks}})


static func _settle_whale_blackjack(run: RunState, library: ContentLibrary) -> Dictionary:
	CrewHeistContractScript._apply_authoritative_blackjack(run, library, 20)
	var state := run.crew_heist_snapshot()
	return {"resolved": str(state.get("status", "")) == CrewHeistModelScript.STATUS_COMPLETED, "payout": int(state.get("payout", 0))}


static func _prepare(run: RunState, member_id: String, emitted: Array, witnessed: bool = false, plan_id: String = CrewHeistModelScript.PLAN_COUNT) -> void:
	for crew_member_id in CrewStateModelScript.MEMBER_IDS:
		run.crew_trust_by_member[crew_member_id] = 40
	run.crew_heist_state = CrewHeistModelScript.begin(plan_id, 0)
	run.crew_heist_state["x"] = {"v": 1, "m": member_id, "e": emitted.duplicate() if witnessed else [], "w": emitted.duplicate() if witnessed else [], "h": false, "c": false, "f": 0}


static func _ledger_semantics(entries: Array) -> Array:
	var result: Array = []
	for value in entries:
		var entry := _dict(value)
		result.append({"member_id": str(entry.get("member_id", "")), "kind": str(entry.get("kind", "")), "weight": int(entry.get("weight", 0)), "turn_recorded": int(entry.get("turn_recorded", 0))})
	return result


static func _run(seed: String) -> RunState:
	var run := RunStateScript.new()
	run.start_new(seed, RunStateScript.standard_challenge(seed))
	return run


static func _rng(seed: int) -> RngStream:
	var rng := RngStreamScript.new()
	rng.configure(seed, seed)
	return rng


static func _tuning() -> Dictionary:
	return _dict(CrewHeistModelScript.config().get("hidden_resolution", {}))


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
