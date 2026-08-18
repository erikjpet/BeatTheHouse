class_name CrewHeistContract
extends RefCounted

const RunStateScript := preload("res://scripts/core/run_state.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const CrewHeistModelScript := preload("res://scripts/core/crew_heist_model.gd")
const RunReportViewModelScript := preload("res://scripts/ui/run_report_view_model.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const GameModuleScript := preload("res://scripts/core/game_module.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")


static func check(_library: ContentLibrary, failures: Array) -> void:
	failures.append_array(CrewHeistModelScript.validate_content())
	if _array(CrewHeistModelScript.plan("the_count").get("architects", [])) != ["crew_bishop"] or _array(CrewHeistModelScript.plan("the_whale_game").get("architects", [])) != ["crew_velvet", "crew_mags"]:
		failures.append("The crew06_9 seam lost its exact plan architect arrays.")
	_check_gating(failures)
	_check_production_paths(_library, failures)
	_check_plan_a(_library, failures)
	_check_plan_b(_library, failures)
	_check_abort_and_save(failures)
	_check_seam_regressions(failures)
	_check_determinism(failures)


static func _check_gating(failures: Array) -> void:
	var hidden := _run("HEIST-GATE-HIDDEN", {})
	if bool(hidden.crew_heist_planning_status().get("visible", true)):
		failures.append("Planning table appeared without an Inner Circle member.")
	var count := _run("HEIST-GATE-COUNT", {"audit_night": true})
	_set_inner(count, "crew_bishop")
	var count_rows := _rows(count)
	if not bool(_dict(count_rows.get("the_count", {})).get("live", false)) or bool(_dict(count_rows.get("the_whale_game", {})).get("live", false)):
		failures.append("Plan A gating did not require Audit Night plus Bishop alone.")
	var whale := _run("HEIST-GATE-WHALE", {"heist_plan_b_criteria": true})
	_set_inner(whale, "crew_velvet")
	var whale_rows := _rows(whale)
	if not bool(_dict(whale_rows.get("the_whale_game", {})).get("live", false)) or bool(_dict(whale_rows.get("the_count", {})).get("live", false)):
		failures.append("Plan B gating did not require a whale anchor plus Velvet alone.")
	var missing := _run("HEIST-GATE-MISSING", {})
	_set_inner(missing, "crew_bishop")
	var missing_row := _dict(_rows(missing).get("the_count", {}))
	if bool(missing_row.get("live", true)) or not _strings(missing_row.get("missing_stars", [])).has("No audit on the books this season."):
		failures.append("Planning table did not tell the truth about the missing Audit Night star.")
	var gala := _run("HEIST-GATE-GALA", {"gala_night": true})
	_set_inner(gala, "crew_velvet")
	if not bool(_dict(_rows(gala).get("the_whale_game", {})).get("live", false)):
		failures.append("Plan B did not accept Gala Night as its alternate seeded whale anchor.")


static func _check_production_paths(library: ContentLibrary, failures: Array) -> void:
	var count := _run("HEIST-PRODUCTION-COUNT", {"audit_night": true})
	_set_inner(count, "crew_bishop")
	var planning := EventModuleScript.new()
	planning.setup(library.event("crew_planning_table"), library)
	var planning_ids: Array = []
	for choice_value in planning.choices(count, count.current_environment):
		planning_ids.append(str(_dict(choice_value).get("id", "")))
	if not planning_ids.has("lock_the_count") or not bool(planning.resolve(count, count.current_environment, "lock_the_count").get("ok", false)) or str(count.crew_heist_snapshot().get("plan_id", "")) != "the_count":
		failures.append("The production planning-table EventModule path did not lock Plan A.")
		return
	# The shared result contract also carries early legal actions.  Without a
	# shipped blackjack settlement payload they must not count at all.
	GameModuleScript.apply_result(count, GameModuleScript.build_action_result({"ok": true, "type": "game_action", "source_id": "blackjack", "game_id": "blackjack", "action_id": "hit", "action_kind": "legal", "stake": 12, "bankroll_delta": 0, "deltas": {"bankroll_delta": 0, "suspicion_delta": 0}, "environment_archetype_id": "grand_casino"}))
	if int(_dict(count.crew_heist_snapshot().get("setup", {})).get("identity_sessions", 0)) != 0:
		failures.append("An early, nonterminal blackjack action credited a furniture session.")
	# Three settled hand results in one visit are one furniture session, not three.
	for _index in range(3):
		GameModuleScript.apply_result(count, _settled_blackjack_result(12, 0, "grand_casino"))
	if int(_dict(count.crew_heist_snapshot().get("setup", {})).get("identity_sessions", 0)) != 1:
		failures.append("Repeated actions in one Grand Casino visit counted as distinct furniture sessions.")
	# Start through the planning event, then travel through RunGenerator and use
	# the production in-room handoff API; no test mutates current_node_id here.
	count.crew_heist_state["setup"] = {"identity": true, "identity_sessions": 3, "identity_session_ids": ["a", "b", "c"]}
	if not bool(planning.resolve(count, count.current_environment, "count_schedule").get("ok", false)):
		failures.append("Planning-table schedule action did not start the production hold.")
	else:
		var generator := RunGeneratorScript.new(library)
		generator.next_environment(count, "grand_casino_cage", true)
		count.advance_environment_turns(2)
	if not bool(_dict(count.crew_heist_snapshot().get("setup", {})).get("schedule", false)):
		failures.append("Ordinary generated travel did not complete the production schedule hold.")
	var whale := _run("HEIST-PRODUCTION-WHALE", {"heist_plan_b_criteria": true})
	_set_inner(whale, "crew_velvet")
	whale.bankroll = 500
	planning.resolve(whale, whale.current_environment, "lock_the_whale_game")
	whale.set_environment({"id": "delta_queen", "world_node_id": "delta_queen", "archetype_id": "delta_queen", "kind": "casino", "turns": 0, "visit_id": "whale_visit_1", "scenario_hook_flags": {"heist_plan_b_criteria": true}, "event_ids": ["scenario_whale_aboard_vouch"], "resolved_event_ids": []})
	var whale_event := EventModuleScript.new()
	whale_event.setup(library.event("scenario_whale_aboard_vouch"), library)
	whale_event.resolve(whale, whale.current_environment, "stake_his_table")
	var whale_anchor_environment := whale.current_environment.duplicate(true)
	whale.set_environment({"id": "small_underground_casino", "world_node_id": "small_underground_casino", "archetype_id": "small_underground_casino", "kind": "casino", "turns": 0, "visit_id": "unrelated_loss", "scenario_hook_flags": {}, "event_ids": [], "resolved_event_ids": []})
	GameModuleScript.apply_result(whale, _settled_blackjack_result(42, -42, "small_underground_casino"))
	if int(_dict(whale.crew_heist_snapshot().get("setup", {})).get("vouch_rounds", 0)) != 0:
		failures.append("An unrelated casino loss advanced the Whale vouch away from the authored anchor table.")
	whale.set_environment(whale_anchor_environment)
	GameModuleScript.apply_result(whale, _settled_blackjack_result(42, -42, "delta_queen"))
	var whale_setup := _dict(whale.crew_heist_snapshot().get("setup", {}))
	if not bool(whale.narrative_flags.get("heist_plan_b_whale_vouch", false)) or not bool(whale_setup.get("vouch", false)):
		failures.append("The shipped whale event plus real game-result route did not complete the vouch.")
	whale.add_item("false_bottom_cup")
	whale.narrative_flags["craps_setting_trained"] = true
	whale.record_score_spending(120, "fixture_production_spend")
	whale.advance_environment_turns(1)
	whale.current_environment["visit_id"] = "whale_visit_2"
	whale.advance_environment_turns(1)
	whale.crew_heist_table_choices()
	whale_setup = _dict(whale.crew_heist_snapshot().get("setup", {}))
	if not bool(whale_setup.get("rig", false)) or not bool(whale_setup.get("name", false)):
		failures.append("Existing Estate Lot item, craps training, spending, and distinct visit producers did not complete Plan B setup.")
	var public_text := JSON.stringify({"save": whale.to_dict(), "choices": whale.crew_heist_table_choices(), "story": whale.story_log}).to_lower()
	for forbidden in ["traitor", "no_turn", "nobody turns", "traitor_resolution"]:
		if public_text.find(forbidden) != -1:
			failures.append("Hidden crew06_9 state leaked through a save, planning choice, or story log.")


static func _check_plan_a(library: ContentLibrary, failures: Array) -> void:
	var run := _run("HEIST-A-E2E", {"audit_night": true})
	_set_inner(run, "crew_bishop")
	if not bool(run.crew_heist_lock("the_count").get("ok", false)):
		failures.append("Plan A could not lock from its truthful live gate.")
		return
	if _dict(run.crew_heist_snapshot().get("r", {})) != {"v": 1, "s": "0"}:
		failures.append("Plan lock did not write the neutral crew06_9 handoff seam.")
	for _index in range(3):
		run.crew_heist_record_count_session(12, 8, 12, true, "count_session_%d" % _index)
	if not bool(run.crew_heist_begin_count_schedule().get("ok", false)):
		failures.append("Plan A schedule did not start a real delivery hold.")
	else:
		_move(run, "grand_casino_cage")
		run.advance_environment_turns(2)
	if not bool(_dict(run.crew_heist_snapshot().get("setup", {})).get("schedule", false)):
		failures.append("Plan A schedule hold did not complete at the real cage node.")
	if not bool(run.crew_heist_begin_count_swap_cart().get("ok", false)):
		failures.append("Plan A swap cart did not start a real package run.")
	else:
		_move(run, "grand_casino")
		run.delivery_resolve_travel_arrival()
		run.delivery_complete_handoff()
	if not bool(_dict(run.crew_heist_snapshot().get("setup", {})).get("swap_cart", false)):
		failures.append("Plan A swap cart did not complete through the real-map handoff.")
	run.narrative_flags["debt_court_settlement"] = true
	run.crew_trust_by_member["crew_knuckles"] = CrewStateModelScript.rank_threshold("associate")
	if not bool(run.crew_heist_begin_play().get("ok", false)):
		failures.append("Plan A did not enter the Play after all mandatory setup.")
		return
	if not _array(run.current_environment.get("event_ids", [])).has("heist_live_table"):
		failures.append("Plan A did not mount its production crew event at the designated table.")
	var live_table := EventModuleScript.new()
	live_table.setup(library.event("heist_live_table"), library)
	run.advance_environment_turns(1)
	var mid_window := RunStateScript.new()
	mid_window.from_dict(run.to_dict())
	if JSON.stringify(mid_window.crew_heist_snapshot()) != JSON.stringify(run.crew_heist_snapshot()):
		failures.append("Plan A save/load changed the live action-boundary window.")
	if bool(run.crew_heist_decide("distraction", "sit").get("ok", false)):
		failures.append("Plan A allowed its second decision before the first live-table round boundary.")
	var expected_choices := [["go_hold", "distraction_sit"], ["distraction_sit", "exit_corridor"], ["exit_corridor", "begin_getaway"]]
	for round_index in range(3):
		var before_ids := _choice_ids(live_table.choices(run, run.current_environment))
		if not before_ids.has(str(expected_choices[round_index][0])) or before_ids.has(str(expected_choices[round_index][1])):
			failures.append("Plan A live-table beat %d was early, missing, or front-loaded." % round_index)
		var decision_choice := str(expected_choices[round_index][0])
		if not bool(live_table.resolve(run, run.current_environment, decision_choice).get("ok", false)):
			failures.append("Plan A production crew event rejected %s." % decision_choice)
		GameModuleScript.apply_result(run, _settled_blackjack_result(12, 0, "grand_casino"))
	if int(_dict(run.crew_heist_snapshot().get("play", {})).get("round", 0)) != 3:
		failures.append("Plan A real settled hands did not interleave all three crew beats.")
	var dock := RunStateScript.new()
	dock.from_dict(run.to_dict())
	dock.crew_heist_state["play"]["decisions"]["exit"] = "dock"
	if not bool(dock.crew_heist_begin_getaway().get("ok", false)) or int(dock.delivery_snapshot().get("pursuit_pressure", -1)) != 4 or str(_dict(dock.crew_heist_snapshot().get("getaway", {})).get("exit", "")) != "dock":
		failures.append("Plan A fast/loud dock route lost its historical pressure-4 contract.")
	if not bool(live_table.resolve(run, run.current_environment, "begin_getaway").get("ok", false)) or str(run.delivery_snapshot().get("mode", "")) != "getaway":
		failures.append("Plan A did not enter the real getaway mode.")
		return
	if int(run.delivery_snapshot().get("pursuit_pressure", -1)) != 1 or str(_dict(run.crew_heist_snapshot().get("getaway", {})).get("exit", "")) != "corridor":
		failures.append("Plan A slow/quiet corridor route lost its distinct pressure-1 contract.")
	_move(run, "grand_casino_cage")
	run.delivery_resolve_travel_arrival()
	if run.run_status != RunState.RUN_STATUS_ENDED or str(run.crew_heist_snapshot().get("outcome", "")) != "clean_sweep" or run.bankroll < 1000:
		failures.append("Plan A clean route did not produce its deterministic flat payout and Act 1 victory.")
	var no_guard := _run("HEIST-A-NO-GUARD", {"audit_night": true})
	_set_inner(no_guard, "crew_bishop")
	no_guard.crew_heist_lock("the_count")
	var no_guard_state := no_guard.crew_heist_snapshot()
	no_guard_state["setup"] = {"identity": true, "schedule": true, "swap_cart": true}
	no_guard.crew_heist_state = no_guard_state
	no_guard.crew_heist_begin_play()
	_move(no_guard, "grand_casino")
	no_guard.crew_heist_state["play"]["round"] = 2
	no_guard.crew_heist_state["play"]["decisions"] = {"go": "hold", "distraction": "sit"}
	if bool(no_guard.crew_heist_decide("exit", "corridor").get("ok", false)) or not bool(no_guard.crew_heist_decide("exit", "dock").get("ok", false)):
		failures.append("Plan A exit availability did not derive from the optional Debt Court guard setup.")
	var late := RunStateScript.new()
	late.from_dict(mid_window.to_dict())
	late.advance_environment_turns(10)
	var late_play := _dict(late.crew_heist_snapshot().get("play", {}))
	if not bool(late_play.get("late", false)) or not bool(late_play.get("corridor_blown", false)) or int(late_play.get("score", 100)) >= 100:
		failures.append("Plan A idle actions did not expire and degrade the deterministic live window.")
	var left := RunStateScript.new()
	left.from_dict(mid_window.to_dict())
	_move(left, "delta_queen")
	left.advance_environment_turns(1)
	if not bool(_dict(left.crew_heist_snapshot().get("play", {})).get("left_table", false)) or _array(left.current_environment.get("event_ids", [])).has("heist_live_table"):
		failures.append("Leaving Plan A's live session did not record its boundary-driven consequence.")
	var blown := RunStateScript.new()
	blown.from_dict(mid_window.to_dict())
	blown.crew_heist_state["play"]["round"] = 2
	blown.crew_heist_state["play"]["decisions"] = {"go": "hold", "distraction": "sit", "exit": "corridor"}
	blown.crew_heist_play_round({"game_id": "blackjack", "bet": 12, "heat_delta": 15})
	if not bool(blown.crew_heist_begin_getaway().get("ok", false)) or str(_dict(blown.crew_heist_snapshot().get("getaway", {})).get("exit", "")) != "dock":
		failures.append("A Plan A heat spike did not blow the corridor and force the dock.")
	if CrewHeistModelScript.ladder(65, true) != "out_hot" or CrewHeistModelScript.ladder(90, false) != "out_hot" or CrewHeistModelScript.ladder(50, false) != "somebody_got_pinched":
		failures.append("Plan A ladder fixtures lost their clean/hot/pinched bands.")


static func _check_plan_b(library: ContentLibrary, failures: Array) -> void:
	var run := _run("HEIST-B-E2E", {"heist_plan_b_criteria": true})
	_set_inner(run, "crew_velvet")
	if not bool(run.crew_heist_lock("the_whale_game").get("ok", false)):
		failures.append("Plan B could not lock from its truthful live gate.")
		return
	run.crew_heist_record_whale_vouch(-30, true)
	run.crew_heist_record_whale_vouch(-35, true)
	for source in ["practice_rig", "street_craps"]:
		var source_run := _run("HEIST-B-RIG-%s" % source, {"heist_plan_b_criteria": true})
		_set_inner(source_run, "crew_velvet")
		source_run.crew_heist_lock("the_whale_game")
		source_run.add_item("false_bottom_cup")
		source_run.narrative_flags["craps_setting_trained"] = true
		if not bool(source_run.crew_heist_record_whale_rig().get("complete", false)):
			failures.append("Plan B rig rejected the %s training source." % source)
	run.add_item("false_bottom_cup")
	run.narrative_flags["craps_setting_trained"] = true
	run.crew_heist_record_whale_rig()
	run.crew_heist_record_whale_name(120, true)
	run.crew_heist_record_whale_name(0, true)
	if not bool(run.crew_heist_begin_play().get("ok", false)):
		failures.append("Plan B did not seed Lucky's drunk and enter the invitational.")
		return
	_move(run, "grand_casino_high_limit")
	run.current_environment["crew_presence"] = [{"member_id": "crew_velvet", "rank": "inner_circle"}]
	var invitational_start := RunStateScript.new()
	invitational_start.from_dict(run.to_dict())
	var craps_caught := RunStateScript.new()
	craps_caught.from_dict(invitational_start.to_dict())
	GameModuleScript.apply_result(craps_caught, _cheating_settled_game_result("craps", 42, -20, "grand_casino_high_limit"))
	if not bool(_dict(craps_caught.crew_heist_snapshot().get("play", {})).get("made", false)):
		failures.append("A production-shaped caught Craps cheat remained clean in the invitational.")
	var blackjack_caught := RunStateScript.new()
	blackjack_caught.from_dict(invitational_start.to_dict())
	GameModuleScript.apply_result(blackjack_caught, _settled_game_result("craps", 42, 0, "grand_casino_high_limit"))
	GameModuleScript.apply_result(blackjack_caught, _cheating_settled_game_result("blackjack", 42, -20, "grand_casino_high_limit"))
	var blackjack_play := _dict(blackjack_caught.crew_heist_snapshot().get("play", {}))
	if not bool(blackjack_play.get("made", false)) or bool(_dict(_array(blackjack_play.get("hazards", []))[0]).get("honest", true)):
		failures.append("Production Blackjack cheat/caught fields did not fail the honesty hazard and mark the name.")
	var peek_then_settle := RunStateScript.new()
	peek_then_settle.from_dict(invitational_start.to_dict())
	GameModuleScript.apply_result(peek_then_settle, _settled_game_result("craps", 42, 0, "grand_casino_high_limit"))
	GameModuleScript.apply_result(peek_then_settle, _nonterminal_cheat_result("blackjack", "grand_casino_high_limit", true))
	var peek_play := _dict(peek_then_settle.crew_heist_snapshot().get("play", {}))
	if int(peek_play.get("round", 0)) != 1 or not bool(peek_play.get("made", false)) or int(peek_play.get("score", 100)) != 75:
		failures.append("A caught nonterminal Blackjack peek did not mark the name without advancing the round.")
	GameModuleScript.apply_result(peek_then_settle, _settled_game_result("blackjack", 42, 0, "grand_casino_high_limit"))
	peek_play = _dict(peek_then_settle.crew_heist_snapshot().get("play", {}))
	if int(peek_play.get("score", 100)) != 45 or bool(_dict(_array(peek_play.get("hazards", []))[-1]).get("honest", true)):
		failures.append("A later legal Blackjack settlement lost or double-penalized its pending dishonest/made fact.")
	var baccarat_caught := RunStateScript.new()
	baccarat_caught.from_dict(invitational_start.to_dict())
	for game_id in ["craps", "blackjack", "craps"]:
		GameModuleScript.apply_result(baccarat_caught, _settled_game_result(game_id, 42, 0, "grand_casino_high_limit"))
	GameModuleScript.apply_result(baccarat_caught, _cheating_settled_game_result("baccarat", 42, -20, "grand_casino_high_limit"))
	var baccarat_play := _dict(baccarat_caught.crew_heist_snapshot().get("play", {}))
	if not bool(baccarat_play.get("made", false)) or bool(_dict(_array(baccarat_play.get("hazards", []))[-1]).get("honest", true)):
		failures.append("Production Baccarat edge-sort/blown fields did not fail the honesty hazard and mark the name.")
	var edge_then_settle := RunStateScript.new()
	edge_then_settle.from_dict(invitational_start.to_dict())
	for game_id in ["craps", "blackjack", "craps"]:
		GameModuleScript.apply_result(edge_then_settle, _settled_game_result(game_id, 42, 0, "grand_casino_high_limit"))
	GameModuleScript.apply_result(edge_then_settle, _nonterminal_cheat_result("baccarat", "grand_casino_high_limit", false))
	if int(_dict(edge_then_settle.crew_heist_snapshot().get("play", {})).get("round", 0)) != 3:
		failures.append("A nonterminal Baccarat Edge Sort action advanced the invitational round.")
	GameModuleScript.apply_result(edge_then_settle, _settled_game_result("baccarat", 42, 0, "grand_casino_high_limit"))
	if bool(_dict(_array(_dict(edge_then_settle.crew_heist_snapshot().get("play", {})).get("hazards", []))[-1]).get("honest", true)):
		failures.append("A later legal Baccarat hand forgot its pending Edge Sort dishonesty.")
	GameModuleScript.apply_result(run, _settled_blackjack_result(42, 40, "grand_casino_high_limit"))
	if int(_dict(run.crew_heist_snapshot().get("play", {})).get("round", 0)) != 0:
		failures.append("Plan B advanced on the wrong game before the required craps opener.")
	var sequence := ["craps", "blackjack", "craps", "baccarat", "blackjack"]
	for round_index in range(1, 6):
		if round_index == 3 and not bool(run.crew_play_activate("distraction", "craps", run.current_environment).get("ok", false)):
			failures.append("Plan B could not activate its real coordinated-play lifeline.")
		GameModuleScript.apply_result(run, _settled_game_result(str(sequence[round_index - 1]), 42, 40, "grand_casino_high_limit"))
		if int(_dict(run.crew_heist_snapshot().get("play", {})).get("round", 0)) != round_index:
			failures.append("Plan B rejected the real %s result at invitational round %d." % [sequence[round_index - 1], round_index])
	if _array(_dict(run.crew_heist_snapshot().get("play", {})).get("lifelines_used", [])).size() != 1:
		failures.append("Plan B did not consume exactly one real coordinated-play activation as a finite lifeline.")
	if _array(_dict(run.crew_heist_snapshot().get("play", {})).get("hazards", [])).size() != 2:
		failures.append("Plan B did not record both counter-rig hazard rounds.")
	if int(_dict(run.crew_heist_snapshot().get("play", {})).get("pot", 0)) != run.grand_casino_chips or run.grand_casino_chips <= 650:
		failures.append("Plan B wins did not grow the authoritative Grand Casino chip pot.")
	var loser := RunStateScript.new()
	loser.from_dict(invitational_start.to_dict())
	for round_index in range(1, 6):
		GameModuleScript.apply_result(loser, _settled_game_result(str(sequence[round_index - 1]), 42, -130, "grand_casino_high_limit"))
	var loser_play := _dict(loser.crew_heist_snapshot().get("play", {}))
	if loser.grand_casino_chips != 0 or int(loser_play.get("pot", -1)) != 0 or not bool(loser_play.get("bust", false)):
		failures.append("Plan B's real losing mixed sequence did not bust the authoritative chip pot.")
	var attention := RunStateScript.new()
	attention.from_dict(invitational_start.to_dict())
	attention.add_suspicion("fixture_rourke_attention", 100, "fixture", true)
	attention.evaluate_immediate_terminal_state()
	if attention.run_status != RunState.RUN_STATUS_ACTIVE or attention.suspicion_level() != 99 or not bool(_dict(attention.crew_heist_snapshot().get("play", {})).get("made", false)):
		failures.append("Grand Casino 100 heat bypassed the Whale Game's Rourke-attention made semantics.")
	var hot := RunStateScript.new()
	hot.from_dict(run.to_dict())
	hot.crew_heist_state["play"]["score"] = 70
	var live_table := EventModuleScript.new()
	live_table.setup(library.event("heist_live_table"), library)
	if not bool(live_table.resolve(hot, hot.current_environment, "begin_interview").get("ok", false)) or bool(hot.crew_heist_begin_getaway().get("ok", false)) or not bool(live_table.resolve(hot, hot.current_environment, "interview_cut_short").get("ok", false)) or int(hot.delivery_snapshot().get("pursuit_pressure", 0)) != 3 or not bool(_dict(hot.crew_heist_snapshot().get("getaway", {})).get("chase", false)):
		failures.append("Plan B hot front-door path did not turn into its authored chase.")
	if not bool(live_table.resolve(run, run.current_environment, "begin_interview").get("ok", false)) or bool(run.crew_heist_begin_getaway().get("ok", false)) or not bool(live_table.resolve(run, run.current_environment, "interview_show_receipt").get("ok", false)):
		failures.append("Plan B did not begin its front-door getaway.")
		return
	if int(run.delivery_snapshot().get("pursuit_pressure", -1)) != 0 or bool(_dict(run.crew_heist_snapshot().get("getaway", {})).get("chase", true)):
		failures.append("Plan B clean front-door walk incorrectly began as a chase.")
	run.advance_environment_turns(2)
	if int(run.delivery_snapshot().get("pursuit_pressure", -1)) != 0 or str(run.delivery_snapshot().get("status", "")) != "active":
		failures.append("Plan B clean front-door walk silently became a chase across ordinary boundaries.")
	_move(run, "small_underground_casino")
	run.delivery_resolve_travel_arrival()
	if _array(run.current_environment.get("event_ids", [])).has("heist_live_table") or bool(run.narrative_flags.get("heist_live_table_active", true)):
		failures.append("The transient heist live-table event survived getaway completion.")
	var seam := run.act_two_seam_payload()
	if str(seam.get("victory_route", "")) != "crew_heist" or int(seam.get("schema_version", 0)) != 2 or str(_dict(seam.get("route_payload", {})).get("hook", "")) != "town_remembers":
		failures.append("Plan B victory did not write the schema-v2 crew_heist town_remembers seam.")
	var report := RunReportViewModelScript.build(run.to_dict(), {"outcomes": RunReportViewModelScript.load_outcome_registry()})
	if str(_dict(report.get("outcome", {})).get("key", "")) != "heist_clean_sweep":
		failures.append("The victory report did not preserve the heist outcome rung.")
	if CrewHeistModelScript.ladder(90, true, true, false) != "out_hot" or CrewHeistModelScript.ladder(90, true, false, true) != "out_hot" or CrewHeistModelScript.ladder(60, false, true, true) != "somebody_got_pinched":
		failures.append("Plan B made/clean and rich/bust ladder fixtures lost deterministic bands.")


static func _check_abort_and_save(failures: Array) -> void:
	for progress in range(3):
		var run := _run("HEIST-ABORT-%d" % progress, {"audit_night": true})
		_set_inner(run, "crew_bishop")
		run.crew_heist_lock("the_count")
		for _index in range(progress):
			run.crew_heist_record_count_session(12, 0, 0, true)
		var result := run.crew_heist_abort("fixture")
		if not bool(result.get("ok", false)) or bool(result.get("run_ended", true)) or run.run_status != RunState.RUN_STATUS_ACTIVE or run.bankroll <= 0:
			failures.append("A pre-Play abort ended the run or failed to charge a survivable cost at progress %d." % progress)
		if bool(run.crew_heist_lock("the_whale_game").get("ok", false)):
			failures.append("An aborted heist allowed a second heist in the same run.")
	var saved := _run("HEIST-SAVE", {"audit_night": true})
	_set_inner(saved, "crew_bishop")
	saved.crew_heist_lock("the_count")
	saved.crew_heist_record_count_session(12, 0, 0, true)
	var restored := RunStateScript.new()
	restored.from_dict(saved.to_dict())
	if JSON.stringify(restored.crew_heist_snapshot()) != JSON.stringify(saved.crew_heist_snapshot()):
		failures.append("Mid-heist save/load did not restore the phase state exactly.")
	for phase in CrewHeistModelScript.STATUSES:
		var phase_run := _run("HEIST-SAVE-%s" % phase, {"audit_night": true})
		phase_run.crew_heist_state = CrewHeistModelScript.begin("the_count", 4)
		phase_run.crew_heist_state["status"] = phase
		phase_run.crew_heist_state["setup"] = {"identity_sessions": 2, "schedule": phase != "setup"}
		phase_run.crew_heist_state["play"] = {"round": 2, "score": 73, "decisions": {"go": "hold"}, "hazards": [], "lifelines_used": []}
		var phase_loaded := RunStateScript.new()
		phase_loaded.from_dict(phase_run.to_dict())
		if JSON.stringify(phase_loaded.crew_heist_snapshot()) != JSON.stringify(phase_run.crew_heist_snapshot()):
			failures.append("Heist save/load changed the exact %s phase." % phase)
	var ignored := _run("HEIST-IGNORED", {})
	var ignored_crew := _dict(ignored.to_dict().get("crew_state", {}))
	if ignored_crew.has("crew_heist") or ignored_crew.has("crew_heist_schema_version"):
		failures.append("Crew-ignoring runs gained heist save bytes.")
	var ignored_before := JSON.stringify(ignored.to_dict())
	ignored.call("_crew_heist_boundary_sync")
	if JSON.stringify(ignored.to_dict()) != ignored_before:
		failures.append("A crew-ignoring action boundary mutated serialized run bytes through the live-table lifecycle.")
	var identity_shortfall := _run("HEIST-IDENTITY-SHORTFALL", {"audit_night": true})
	_set_inner(identity_shortfall, "crew_bishop")
	identity_shortfall.crew_heist_lock("the_count")
	identity_shortfall.crew_heist_state["setup"] = {"schedule": true, "swap_cart": true}
	var identity_bankroll := identity_shortfall.bankroll
	var identity_result := identity_shortfall.crew_heist_begin_play()
	var identity_abort := _dict(identity_shortfall.crew_heist_snapshot().get("abort", {}))
	if not bool(identity_result.get("forced", false)) or str(identity_shortfall.crew_heist_snapshot().get("status", "")) != "aborted" or str(identity_abort.get("reason", "")) != "identity_shortfall" or identity_shortfall.bankroll >= identity_bankroll or identity_shortfall.run_status != RunState.RUN_STATUS_ACTIVE:
		failures.append("Plan A identity shortfall did not force a costed abort while preserving the active run.")
	var ordinary_gap := _run("HEIST-ORDINARY-SETUP-GAP", {"audit_night": true})
	_set_inner(ordinary_gap, "crew_bishop")
	ordinary_gap.crew_heist_lock("the_count")
	ordinary_gap.crew_heist_state["setup"] = {"identity": true, "identity_sessions": 3, "identity_session_ids": ["a", "b", "c"], "swap_cart": true}
	var ordinary_bankroll := ordinary_gap.bankroll
	var ordinary_result := ordinary_gap.crew_heist_begin_play()
	if bool(ordinary_result.get("ok", false)) or str(ordinary_gap.crew_heist_snapshot().get("status", "")) != "setup" or ordinary_gap.bankroll != ordinary_bankroll:
		failures.append("An ordinary missing schedule/cart setup guardrail was incorrectly converted into a forced abort.")


static func _check_seam_regressions(failures: Array) -> void:
	var players := _terminal_route("high_roller_cashout")
	var players_expected := {"schema_version": 1, "source_act": 1, "target_act": 2, "victory_route": "players_card_cashout", "demo_victory_route": "high_roller_cashout", "final_bankroll_band": "walking_money", "story_flags": {}, "route_payload": {"hook": "players_card_open_rooms", "house_attention": "valued_guest", "tone": "invited"}}
	if JSON.stringify(players.act_two_seam_payload()) != JSON.stringify(players_expected):
		failures.append("Players Card Act seam bytes changed after the heist extension.")
	var duel := _terminal_route("pit_boss_showdown")
	var duel_expected := {"schema_version": 1, "source_act": 1, "target_act": 2, "victory_route": "showdown", "demo_victory_route": "pit_boss_showdown", "final_bankroll_band": "walking_money", "story_flags": {}, "route_payload": {"hook": "rourke_remembers", "house_attention": "watched_exit", "tone": "marked"}}
	if JSON.stringify(duel.act_two_seam_payload()) != JSON.stringify(duel_expected):
		failures.append("Rourke showdown Act seam bytes changed after the heist extension.")


static func _check_determinism(failures: Array) -> void:
	var a := _run("HEIST-DETERMINISM", {"audit_night": true})
	var b := _run("HEIST-DETERMINISM", {"audit_night": true})
	_set_inner(a, "crew_bishop")
	_set_inner(b, "crew_bishop")
	a.crew_heist_lock("the_count")
	b.crew_heist_lock("the_count")
	if JSON.stringify(a.crew_heist_snapshot()) != JSON.stringify(b.crew_heist_snapshot()):
		failures.append("Identical heist seeds and boundaries produced different state.")


static func _settled_blackjack_result(stake: int, bankroll_delta: int, venue_id: String) -> Dictionary:
	var result := GameModuleScript.build_action_result({"ok": true, "type": "game_action", "source_id": "blackjack", "game_id": "blackjack", "action_id": "stand", "action_kind": "legal", "stake": stake, "bankroll_delta": bankroll_delta, "deltas": {"bankroll_delta": bankroll_delta, "suspicion_delta": 0}, "environment_archetype_id": venue_id})
	# Blackjack.perform_action appends this after the shared builder only when
	# the hand reaches settlement.  The contract mirrors that shipped boundary.
	result["blackjack_hand_results"] = [{"outcome": "push" if bankroll_delta == 0 else "loss"}]
	return result


static func _settled_game_result(game_id: String, stake: int, bankroll_delta: int, venue_id: String) -> Dictionary:
	if game_id == "blackjack":
		return _settled_blackjack_result(stake, bankroll_delta, venue_id)
	var action_id := "roll_craps" if game_id == "craps" else "deal_baccarat"
	var result := GameModuleScript.build_action_result({"ok": true, "type": "game_action", "source_id": game_id, "game_id": game_id, "action_id": action_id, "action_kind": "legal", "stake": stake, "bankroll_delta": bankroll_delta, "deltas": {"bankroll_delta": bankroll_delta, "suspicion_delta": 0}, "environment_archetype_id": venue_id})
	if game_id == "craps":
		result["craps_roll"] = {"dice": [3, 4], "total": 7}
		result["craps_bet_results"] = [{"bet": "pass", "outcome": "win"}]
	else:
		result["baccarat_winner"] = "player"
		result["baccarat_hand"] = {"player": [{"rank": "9"}], "banker": [{"rank": "8"}]}
	return result


static func _cheating_settled_game_result(game_id: String, stake: int, bankroll_delta: int, venue_id: String) -> Dictionary:
	var result := _settled_game_result(game_id, stake, bankroll_delta, venue_id)
	result["action_kind"] = "cheat"
	result["skill_outcome"] = "caught"
	result["skill_grade"] = "blown"
	if game_id == "blackjack":
		result["player_cheat_used"] = true
		result["blackjack_cheat_caught"] = true
		result["dealer_caught_cheat"] = true
	elif game_id == "baccarat":
		result["baccarat_edge_sort_edge_used"] = true
	return result


static func _nonterminal_cheat_result(game_id: String, venue_id: String, caught: bool) -> Dictionary:
	var result := GameModuleScript.build_action_result({"ok": true, "type": "game_action", "source_id": game_id, "game_id": game_id, "action_id": "peek_hole_card" if game_id == "blackjack" else "edge_sort", "action_kind": "cheat", "stake": 0, "bankroll_delta": 0, "deltas": {"bankroll_delta": 0, "suspicion_delta": 5}, "environment_archetype_id": venue_id})
	result["skill_outcome"] = "caught" if caught else "applied"
	result["skill_grade"] = "blown" if caught else "good"
	if game_id == "blackjack":
		result["player_cheat_used"] = true
		result["blackjack_cheat_caught"] = caught
		result["dealer_caught_cheat"] = caught
	else:
		result["baccarat_edge_sort"] = true
	return result


static func _run(seed: String, hooks: Dictionary) -> RunState:
	var run: RunState = RunStateScript.new()
	run.start_new(seed)
	var nodes := [
		{"id": "small_underground_casino", "archetype_id": "small_underground_casino", "kind": "crew", "state": "visited", "seen": true, "environment": {}},
		{"id": "grand_casino", "archetype_id": "grand_casino", "kind": "casino", "state": "visited", "seen": true, "environment": {}},
		{"id": "grand_casino_high_limit", "archetype_id": "grand_casino_high_limit", "kind": "casino", "state": "visited", "seen": true, "environment": {}},
		{"id": "grand_casino_cage", "archetype_id": "grand_casino_cage", "kind": "casino", "state": "visited", "seen": true, "environment": {}},
		{"id": "delta_queen", "archetype_id": "delta_queen", "kind": "casino", "state": "visited", "seen": true, "environment": {}},
	]
	var edges := [{"a": "small_underground_casino", "b": "grand_casino"}, {"a": "grand_casino", "b": "grand_casino_high_limit"}, {"a": "grand_casino", "b": "grand_casino_cage"}, {"a": "grand_casino", "b": "delta_queen"}]
	run.set_world_map({"version": 3, "seed_text": seed, "start_node_id": "small_underground_casino", "current_node_id": "small_underground_casino", "nodes": nodes, "edges": edges, "visited_path": ["small_underground_casino"]})
	run.set_environment({"id": "small_underground_casino", "world_node_id": "small_underground_casino", "archetype_id": "small_underground_casino", "kind": "crew", "turns": 0, "scenario_hook_flags": hooks.duplicate(true), "event_ids": ["crew_planning_table"], "resolved_event_ids": []})
	return run


static func _move(run: RunState, node_id: String) -> void:
	run.world_map["current_node_id"] = node_id
	var archetype_id := node_id
	run.set_environment({"id": node_id, "world_node_id": node_id, "archetype_id": archetype_id, "kind": "casino", "turns": 0, "event_ids": [], "resolved_event_ids": []})


static func _set_inner(run: RunState, member_id: String) -> void:
	run.crew_trust_by_member[member_id] = CrewStateModelScript.rank_threshold("inner_circle")


static func _rows(run: RunState) -> Dictionary:
	var result := {}
	for value in _array(run.crew_heist_planning_status().get("plans", [])):
		var row := _dict(value)
		result[str(row.get("id", ""))] = row
	return result


static func _choice_ids(choices: Array) -> Array:
	var result: Array = []
	for value in choices:
		result.append(str(_dict(value).get("id", "")))
	return result


static func _terminal_route(route: String) -> RunState:
	var run: RunState = RunStateScript.new()
	run.start_new("HEIST-SEAM-%s" % route)
	run.run_status = RunState.RUN_STATUS_ENDED
	run.narrative_flags["demo_victory"] = true
	run.narrative_flags["demo_victory_route"] = route
	return run


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _strings(value: Variant) -> Array:
	var result: Array = []
	for entry in _array(value):
		result.append(str(entry))
	return result
