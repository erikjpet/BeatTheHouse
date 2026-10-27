extends SceneTree

const State := preload("res://scripts/core/run_state.gd")
const Evaluator := preload("res://scripts/core/run_terminal_evaluator.gd")
const Module := preload("res://scripts/core/game_module.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _fixture(machine: Dictionary) -> RunState:
	var run := State.new()
	run.start_new("PUSHER-PAID-BOUNDARY")
	run.current_environment = {"id": "paid-pusher", "archetype_id": "corner_store", "game_ids": ["coin_pusher"], "game_states": {"coin_pusher": machine}}
	return run

func _run() -> void:
	var pending := {"schema": "coin_pusher_discrete_pile", "paid_drop_pending": true, "total_cost": 5, "tray_value": 0}
	var run := _fixture(pending)
	var initial_rng := run.rng_state
	var result := Module.build_canonical_owned_action_result({"source_id": "coin_pusher", "game_id": "coin_pusher", "action_id": "drop_quarter", "action_kind": "legal", "stake": 100, "environment_id": "paid-pusher", "deltas": {"bankroll_delta": -100, "story_log": [{"type": "paid_drop_test_receipt"}]}})
	var applied := Module.apply_result(run, result)
	_expect(bool(applied.get("ok", false)) and run.bankroll == 0, "final payment commits")
	_expect(not run.is_terminal() and run.has_pending_coin_pusher_resolution(), "paid resolution stays active")
	_expect(run.story_log.any(func(row): return row.get("type", "") == "paid_drop_test_receipt"), "charge receipt publishes before bankruptcy")
	_expect(run.rng_state == initial_rng, "pending guard does not spend RNG")
	_expect(bool(Evaluator.evaluate_terminal(run).get("bankroll_zero_deferred", false)), "terminal evaluator respects pending physics")
	run.evaluate_immediate_terminal_state()
	_expect(not run.is_terminal(), "immediate boundary respects pending physics")
	# Synthetic winning payout: existing money boundary may recover the run.
	run.change_bankroll(7)
	pending["paid_drop_pending"] = false
	_expect(run.bankroll == 7 and not run.is_terminal(), "winning physics payout is retained")
	_expect(not run.has_pending_coin_pusher_resolution() and not bool(Evaluator.evaluate_terminal(run).get("terminal", false)), "paid receipt releases after winning settlement")
	# Synthetic empty settlement: clearing the receipt restores ordinary failure.
	var losing := _fixture(pending.duplicate(true))
	losing.current_environment["game_states"]["coin_pusher"]["paid_drop_pending"] = true
	losing.change_bankroll(-100)
	losing.current_environment["game_states"]["coin_pusher"]["paid_drop_pending"] = false
	_expect(bool(Evaluator.evaluate_terminal(losing).get("failed", false)), "losing settlement restores bankruptcy")
	losing.evaluate_immediate_terminal_state()
	_expect(losing.is_terminal(), "empty completed settlement cannot keep zero-cash run alive")
	for bad in [{}, {"schema": "wrong", "paid_drop_pending": true, "total_cost": 5}, {"schema": "coin_pusher_discrete_pile", "paid_drop_pending": "true", "total_cost": 5}, {"schema": "coin_pusher_discrete_pile", "paid_drop_pending": true, "total_cost": 0}]:
		var invalid := _fixture(bad)
		_expect(not invalid.has_pending_coin_pusher_resolution(), "malformed/unpaid marker is not a pending paid drop")
		invalid.change_bankroll(-100)
		_expect(invalid.is_terminal(), "unpaid marker preserves ordinary zero-cash failure")
	var casino := _fixture(pending.duplicate(true))
	casino.current_environment["archetype_id"] = "grand_casino"
	casino.current_environment["game_states"]["coin_pusher"]["paid_drop_pending"] = true
	casino.bankroll = 0
	casino.grand_casino_chips = 5
	casino.change_grand_casino_chips(-5)
	_expect(not casino.is_terminal() and casino.grand_casino_chips == 0, "Grand chip-funded final drop keeps same pending boundary")
	casino.current_environment["game_states"]["coin_pusher"]["paid_drop_pending"] = false
	casino.evaluate_immediate_terminal_state()
	_expect(casino.is_terminal(), "Grand empty completed drop still ends an empty account")
	var tray := _fixture({"schema": "coin_pusher_discrete_pile", "tray_value": 2})
	tray.change_bankroll(-100)
	_expect(not tray.is_terminal(), "existing positive tray can still resolve")
	var captured := _fixture(pending.duplicate(true))
	captured.current_environment["game_states"]["coin_pusher"]["paid_drop_pending"] = true
	captured.change_bankroll(-100)
	captured.add_suspicion("capture", 100, "test", true)
	_expect(captured.is_terminal() and captured.run_failure_reason == State.FAILURE_POLICE_CAPTURE, "paid drops do not suppress Heat capture")
	var old_terminal := _fixture(pending.duplicate(true))
	old_terminal.fail_run(State.FAILURE_BANKROLL_ZERO, "preserved terminal")
	old_terminal.current_environment["game_states"]["coin_pusher"]["paid_drop_pending"] = true
	Evaluator.evaluate_terminal_and_apply(old_terminal)
	_expect(old_terminal.is_terminal() and old_terminal.run_failure_message == "preserved terminal", "terminal state is not resurrected by pending marker")
	var report := {"checks": checks, "failures": failures, "fidelity": "Synthetic native payment/receipt/terminal boundaries including positive payout, empty settlement, malformed/unpaid marker and Heat capture; actual F54 host physics separately qualified."}
	var file := FileAccess.open(OS.get_environment("BTH_TARGET_OUTPUT"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("PUSHER_PAID_RESOLUTION checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
