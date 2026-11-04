extends Node

# Focused transient-input contracts. Pending future ticks and rejected host
# boundaries are synthetic fixtures through production APIs; no player save or
# rendered-performance claim is made here.
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const CoinPusherGameScript := preload("res://scripts/games/coin_pusher.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const SolverScript := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")
const LiveSessionScript := preload("res://scripts/games/coin_pusher/coin_pusher_live_session.gd")
const RESULT_MARKER := "COIN_PUSHER_INPUT_COMPACTION_RESULT="


func _ready() -> void:
	call_deferred("_run_check")


func _run_check() -> void:
	var failures: Array[String] = []
	var library := ContentLibraryScript.new()
	library.load(false)
	var definition: Dictionary = library.game("coin_pusher")
	var machine_definition: Dictionary = definition.get("coin_pusher_machine", {})
	if machine_definition.is_empty():
		_publish({"ok": false, "failures": ["Authored machine missing."]})
		return
	var rng := RngStreamScript.new()
	rng.configure(611040030)
	var machine: Dictionary = {"simulation": SolverScript.create_machine(rng, machine_definition, 0), "motor_started": true}
	var session: Dictionary = LiveSessionScript.begin(machine, machine_definition, 611040030, true)
	var simulation: Dictionary = machine["simulation"]
	var clock := 0
	LiveSessionScript.advance(machine, clock, false)
	var threshold := int(LiveSessionScript.INPUT_TRACE_COMPACT_MIN_CONSUMED)
	for index in range(threshold - 1):
		LiveSessionScript.queue_input(machine, {"kind": "carriage", "x": 10000 + index % 600 * 120})
		clock += 17
		LiveSessionScript.advance(machine, clock, false)
	LiveSessionScript.queue_input(machine, {"kind": "carriage", "x": 41000})
	var future_tick := int(simulation.get("tick", 0)) + 8
	var future_stop: Dictionary = LiveSessionScript.queue_input(machine, {"kind": "skill_stop", "engaged": true})
	future_stop["tick"] = future_tick
	var future_carriage: Dictionary = LiveSessionScript.queue_input(machine, {"kind": "carriage", "x": 62000})
	future_carriage["tick"] = future_tick
	var future_release: Dictionary = LiveSessionScript.queue_input(machine, {"kind": "skill_stop", "engaged": false})
	future_release["tick"] = future_tick
	var future_last_carriage: Dictionary = LiveSessionScript.queue_input(machine, {"kind": "carriage", "x": 71000})
	future_last_carriage["tick"] = future_tick
	var pending_before: Array = [future_stop.duplicate(true), future_carriage.duplicate(true), future_release.duplicate(true), future_last_carriage.duplicate(true)]
	var expected_input_count := threshold + 4
	clock += 17
	LiveSessionScript.advance(machine, clock, false)
	var preserved_pending := (session.get("input_trace", []) as Array) == pending_before \
		and int(session.get("input_cursor", -1)) == 0 \
		and LiveSessionScript.total_input_count(machine) == expected_input_count
	if not preserved_pending:
		failures.append("Compaction did not preserve the exact mixed pending suffix and cumulative count.")
	while int(simulation.get("tick", 0)) < future_tick:
		clock = _advance_one_tick(machine, clock)
	var authored_tick_preserved := int(simulation.get("tick", -1)) == future_tick \
		and int(simulation.get("carriage_x", -1)) == 41000 \
		and not bool(simulation.get("skill_stop_engaged", true))
	clock = _advance_one_tick(machine, clock)
	# Conflicting same-tick carriage and stop inputs make execution order visible.
	var pending_consumed := authored_tick_preserved \
		and int(simulation.get("tick", -1)) == future_tick + 1 \
		and int(session.get("input_cursor", -1)) == 4 \
		and int(simulation.get("carriage_x", -1)) == 71000 \
		and not bool(simulation.get("skill_stop_engaged", true)) \
		and LiveSessionScript.total_input_count(machine) == expected_input_count
	if not pending_consumed:
		failures.append("Preserved mixed inputs did not execute once in their original order at their authored tick.")
	LiveSessionScript.queue_input(machine, {"kind": "carriage", "x": 53000})
	LiveSessionScript.queue_input(machine, {"kind": "skill_stop", "engaged": true})
	expected_input_count += 2
	clock = _advance_one_tick(machine, clock)
	clock = _advance_one_tick(machine, clock)
	var no_replay := int(simulation.get("carriage_x", -1)) == 53000 \
		and bool(simulation.get("skill_stop_engaged", false)) \
		and int(session.get("input_cursor", -1)) == 6 \
		and LiveSessionScript.total_input_count(machine) == expected_input_count
	if not no_replay:
		failures.append("Consumed conflicting inputs replayed on a later tick.")
	LiveSessionScript.queue_input(machine, {"kind": "skill_stop", "engaged": true})
	var trace_before_exit: Array = (session.get("input_trace", []) as Array).duplicate(true)
	var settle_begin: Dictionary = LiveSessionScript.begin_chunked_settle(machine)
	var settlement_preserved := (session.get("input_trace", []) as Array) == trace_before_exit \
		and int(session.get("input_cursor", -1)) == trace_before_exit.size() \
		and int(settle_begin.get("pending_inputs_drained", -1)) == 1 \
		and not bool(simulation.get("skill_stop_engaged", true)) \
		and LiveSessionScript.total_input_count(machine) == expected_input_count + 1
	if not settlement_preserved:
		failures.append("Exit settlement changed its existing pending-input drain or trace ownership.")
	var invariants: Dictionary = simulation.get("last_invariants", {})
	if not bool(invariants.get("conservation_ok", false)):
		failures.append("Compaction changed coin conservation.")
	var rollback_preserved := _check_rejected_drop_rollback(library, definition, threshold, failures)
	var legacy_preserved := _check_legacy_session_count(machine_definition, threshold, failures)
	_publish({"ok": failures.is_empty(), "failures": failures, "web_feature": OS.has_feature("web"),
		"solver_backend": SolverScript.last_step_backend_for_test(), "compaction_threshold": threshold,
		"mixed_pending_suffix_preserved": preserved_pending, "pending_inputs_consumed_once": pending_consumed,
		"authored_tick_preserved": authored_tick_preserved, "no_replay_next_tick": no_replay,
		"exit_settlement_preserved": settlement_preserved, "rejected_drop_rollback_preserved": rollback_preserved,
		"legacy_session_count_preserved": legacy_preserved})


func _advance_one_tick(machine: Dictionary, clock: int) -> int:
	var session: Dictionary = machine.get("live_session", {})
	var units := int(session.get("accumulator_units", 0))
	var elapsed := maxi(0, ceili(float(1000 - units) / 60.0))
	var next_clock := clock + elapsed
	LiveSessionScript.advance(machine, next_clock, false)
	return next_clock


func _check_legacy_session_count(machine_definition: Dictionary, threshold: int, failures: Array[String]) -> bool:
	var rng := RngStreamScript.new()
	rng.configure(611040031)
	var machine: Dictionary = {"simulation": SolverScript.create_machine(rng, machine_definition, 0)}
	var session: Dictionary = LiveSessionScript.begin(machine, machine_definition, 611040031)
	for index in range(threshold):
		LiveSessionScript.queue_input(machine, {"kind": "carriage", "x": 10000 + index % 600 * 120})
	session.erase("input_count")
	LiveSessionScript.advance(machine, 0, false)
	LiveSessionScript.advance(machine, 17, false)
	var recovered := (session.get("input_trace", []) as Array).is_empty() \
		and LiveSessionScript.total_input_count(machine) == threshold
	LiveSessionScript.queue_input(machine, {"kind": "carriage", "x": 47000})
	var passed := recovered and LiveSessionScript.total_input_count(machine) == threshold + 1
	if not passed:
		failures.append("Compaction lost a legacy session's cumulative count before its next queue_input.")
	return passed


func _check_rejected_drop_rollback(library: ContentLibrary, definition: Dictionary, threshold: int, failures: Array[String]) -> bool:
	var game := CoinPusherGameScript.new()
	game.setup(definition, library)
	var run_state := RunStateScript.new()
	run_state.start_new("PERF-AUDIT-COMPACTION-ROLLBACK")
	var environment: Dictionary = {"id": "pusher_compact_rollback", "world_node_id": "pusher_compact_rollback",
		"scenario_game_modifiers": {"coin_pusher": {"variation_id": "quarter_falls"}}, "game_states": {}}
	run_state.current_environment = environment
	environment["game_states"] = {"coin_pusher": game.generate_environment_state(run_state, environment, run_state.create_rng("generation"))}
	game.enter(run_state, environment)
	var machines: Dictionary = game.get("_live_machines")
	var machine: Dictionary = machines.values()[0]
	var session: Dictionary = machine.get("live_session", {})
	# A same-tick burst reaches the compaction boundary without a long physics
	# soak; the separate retention probe measures representative input cadence.
	for index in range(threshold):
		LiveSessionScript.queue_input(machine, {"kind": "carriage", "x": 10000 + index % 600 * 120})
	LiveSessionScript.advance(machine, 0, false)
	LiveSessionScript.advance(machine, 17, false)
	var compacted := (session.get("input_trace", []) as Array).is_empty() \
		and LiveSessionScript.total_input_count(machine) == threshold
	LiveSessionScript.queue_input(machine, {"kind": "carriage", "x": 42000})
	var trace_before := var_to_bytes(session.get("input_trace", []))
	var count_before := LiveSessionScript.total_input_count(machine)
	var cursor_before := int(session.get("input_cursor", -1))
	var durable_before := var_to_bytes(environment.get("game_states", {}))
	var queue_before := var_to_bytes(machine.get("drop_queue", []))
	var token: Dictionary = game.host_action_rollback_snapshot("drop_quarter", run_state, environment)
	var result: Dictionary = game.resolve_with_context("drop_quarter", 1, run_state, environment, run_state.create_rng("rejected-drop"), {})
	var reserved := bool(result.get("ok", false)) and not (machine.get("drop_queue", []) as Array).is_empty()
	# Model the host's rejected environment boundary using its production token.
	var restored := game.restore_host_action_rollback(token, run_state, environment)
	var surface: Dictionary = game.surface_state(run_state, environment, {})
	var passed := compacted and reserved and restored \
		and var_to_bytes(session.get("input_trace", [])) == trace_before \
		and int(session.get("input_cursor", -1)) == cursor_before \
		and LiveSessionScript.total_input_count(machine) == count_before \
		and int(surface.get("coin_pusher_input_trace_count", -1)) == count_before \
		and var_to_bytes(environment.get("game_states", {})) == durable_before \
		and var_to_bytes(machine.get("drop_queue", [])) == queue_before
	if not passed:
		failures.append("Rejected DROP rollback changed pending inputs, cumulative diagnostics, reservations, or durable state after compaction.")
	return passed


func _publish(report: Dictionary) -> void:
	var payload := JSON.stringify(report)
	print(RESULT_MARKER + payload)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.BTHCoinPusherInputCompaction = JSON.parse(%s); document.title = 'BTH_COIN_PUSHER_INPUT_COMPACTION_DONE';" % JSON.stringify(payload), true)
	else:
		get_tree().quit(0 if bool(report.get("ok", false)) else 1)
