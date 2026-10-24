extends SceneTree

const Foundation := preload("res://scripts/ui/foundation_main.gd")

class ClockHost extends Foundation:
	var test_msec := 100000
	func _environment_simulation_time_msec() -> int:
		return test_msec

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var app := ClockHost.new()
	app.continuous_environment_clock_enabled = false
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	var started: Dictionary = app.start_game_test_session("craps")
	_check(bool(started.get("ok", false)), "Craps must enter through the ordinary host.")
	if not bool(started.get("ok", false)):
		_finish(app)
		return
	# Native fixture: reach a point using ordinary chip/bet/THROW commands.
	# Only the presentation clock is controlled; no dice outcomes are replaced.
	for _attempt in range(8):
		_sample(app)
		if int(app.game_surface_canvas.state.get("point", 0)) != 0:
			break
		var targets: Array = app.game_surface_canvas.state.get("bet_targets", [])
		var pass_index := -1
		for i in range(targets.size()):
			if str((targets[i] as Dictionary).get("id", "")) == "pass_line":
				pass_index = i
		if pass_index < 0:
			break
		app._on_game_surface_action("craps_chip", 1)
		app._on_game_surface_action("craps_bet", pass_index)
		app._on_game_surface_action("craps_throw", 0)
		_check(bool(app.last_game_result.get("ok", false)) and int(app.last_game_result.get("craps_total_wager", 0)) == 5, "An explicitly staged five-unit wager must still commit once.")
		_answer_table(app)
		app.test_msec += 10000
	_sample(app)
	var point := int(app.game_surface_canvas.state.get("point", 0))
	_check(point != 0, "Bounded normal rolls must reach a point for the continuation case.")
	if point == 0:
		_finish(app)
		return
	var cash := app.run_state.bankroll
	var chips := app.run_state.grand_casino_chips
	var rng := app.run_state.rng_state
	app.autosave_slot_id = "craps-zero-new-wager"
	_check(app.save_service.save_run(app.run_state, app.autosave_slot_id) == OK, "The working line wager must save.")
	_check(app.load_foundation_run(), "Continue must restore the working line wager.")
	_check(app.run_state.bankroll == cash and app.run_state.grand_casino_chips == chips and app.run_state.rng_state == rng, "Continue must preserve wallet and RNG.")
	_check(app.enter_game("craps"), "The saved table must reopen.")
	app.test_msec += 10000
	_sample(app)
	_check(int(app.game_surface_canvas.state.get("point", 0)) == point, "Continue must preserve the point.")
	var before := app.run_state.wager_capacity_for_game("craps", app.run_state.current_environment)
	app._on_game_surface_action("craps_throw", 0)
	var result: Dictionary = app.last_game_result.duplicate(true)
	print("CRAPS_CONTINUATION_DIAGNOSTIC " + JSON.stringify({"ok": result.get("ok"), "message": result.get("message"), "stake": result.get("stake"), "wager": result.get("craps_total_wager"), "focus": app._current_game_surface_ui_state().get("focused_talk_speaker", {}), "talk": app._pending_talk_entries()}))
	_check(bool(result.get("ok", false)), "A continuation THROW without new chips must resolve.")
	_check(int(result.get("craps_total_wager", -1)) == 0, "A continuation THROW must not invent another Pass/Come wager.")
	var table: Dictionary = app.current_game._table_state_preview(app.run_state, app.run_state.current_environment)
	_check((table.get("last_committed_bets", {}) as Dictionary).is_empty(), "No unstaged wager may enter the committed bet set.")
	_check(app.run_state.wager_capacity_for_game("craps", app.run_state.current_environment) == before + int(result.get("bankroll_delta", 0)), "Only the existing wager settlement may change funds.")
	var after_rng := app.run_state.rng_state
	var after_cash := app.run_state.bankroll
	var after_chips := app.run_state.grand_casino_chips
	_sample(app)
	_sample(app)
	_check(app.run_state.rng_state == after_rng and app.run_state.bankroll == after_cash and app.run_state.grand_casino_chips == after_chips, "Presentation refreshes must not repeat the roll or accounting.")
	_check(app.current_game.wager_cost_for_context("roll_craps", 5, app.run_state, app.run_state.current_environment, {}) == 5, "Legacy calls without explicit staged-bet context must retain their stake shorthand.")
	# Boundary fixture: all spendable funds are on an existing line wager.
	# Reuse the real saved point, then remove only uncommitted fixture funds.
	_answer_table(app)
	_check(app.load_foundation_run() and app.enter_game("craps"), "The saved point must remain usable for another isolated boundary case.")
	app.run_state.bankroll = 0
	app.run_state.grand_casino_chips = 0
	app.test_msec += 10000
	_sample(app)
	app._on_game_surface_action("craps_throw", 0)
	_check(bool(app.last_game_result.get("ok", false)) and int(app.last_game_result.get("craps_total_wager", -1)) == 0, "An existing point must remain rollable with zero spendable funds.")
	_finish(app)

func _answer_table(app: ClockHost) -> void:
	for entry in app._pending_talk_entries():
		app._on_talk_dock_choice_requested(str((entry as Dictionary).get("event_id", "")), "ignore")

func _sample(app: ClockHost) -> void:
	app.last_game_surface_realtime_refresh_msec = 0
	app._advance_game_surface_realtime_state()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _finish(app: ClockHost) -> void:
	if app.save_service.async_save_in_flight():
		app.save_service.wait_for_async_save()
	app.queue_free()
	print("CRAPS_ZERO_NEW_WAGER_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
