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
	_check(bool(started.get("ok", false)), "Ordinary Craps host must start.")
	if not bool(started.get("ok", false)):
		_finish(app)
		return
	_sample(app)
	var targets: Array = app.game_surface_canvas.state.get("bet_targets", [])
	var pass_index := -1
	for i in range(targets.size()):
		if str((targets[i] as Dictionary).get("id", "")) == "pass_line":
			pass_index = i
	_check(pass_index >= 0, "Pass Line target must be present.")
	if pass_index < 0:
		_finish(app)
		return
	# Use real host chip/bet/throw actions, with no Save/Continue to clear the
	# transient draft between rolls. Presentation time alone is controlled.
	for attempt in range(8):
		app._on_game_surface_action("craps_chip", 1)
		app._on_game_surface_action("craps_bet", pass_index)
		app._on_game_surface_action("craps_throw", 0)
		_check(bool(app.last_game_result.get("ok", false)) and int(app.last_game_result.get("craps_total_wager", 0)) == 5, "Explicit five-unit draft must commit once.")
		_answer_table(app)
		app.test_msec += 10000
		_sample(app)
		if int(app.game_surface_canvas.state.get("point", 0)) != 0:
			break
	var point := int(app.game_surface_canvas.state.get("point", 0))
	_check(point != 0, "Bounded ordinary rolls must establish a point.")
	var ui := app._current_game_surface_ui_state()
	_check((ui.get("craps_pending_bets", {}) as Dictionary).is_empty(), "A paid draft must not remain staged after settlement.")
	_check((ui.get("craps_pending_history", []) as Array).is_empty(), "Undo history must not revive an already paid draft.")
	_check(int(ui.get("selected_chip", 0)) == 5, "Settlement must retain the chosen chip denomination.")
	_check(not bool(app.game_surface_canvas.state.get("can_clear", true)), "No consumed draft may remain clearable.")
	app._on_game_surface_action("craps_undo", 0)
	_check((app._current_game_surface_ui_state().get("craps_pending_bets", {}) as Dictionary).is_empty(), "Undo after settlement must not re-stage paid chips.")
	# A synthetic illegal draft exercises the adjacent rejection boundary. Only
	# a successful settlement consumes UI state; rejected drafts keep their input.
	var invalid_ui := ui.duplicate(true)
	invalid_ui["craps_pending_bets"] = {"pass_line": 5}
	var rejection_rng := app.run_state.rng_state
	var rejection_funds := app.run_state.wager_capacity_for_game("craps", app.run_state.current_environment)
	var rejected := app.current_game.resolve_with_context("roll_craps", 5, app.run_state, app.run_state.current_environment, app.run_state.create_rng(), invalid_ui)
	_check(not bool(rejected.get("ok", true)) and not rejected.has("ui_state") and invalid_ui["craps_pending_bets"] == {"pass_line": 5}, "A rejected draft must not be consumed or rewritten.")
	_check(app.run_state.rng_state == rejection_rng and app.run_state.wager_capacity_for_game("craps", app.run_state.current_environment) == rejection_funds, "Rejected drafts must not draw RNG or change funds.")
	var funds := app.run_state.wager_capacity_for_game("craps", app.run_state.current_environment)
	var before_count := int(app.current_game._table_state_preview(app.run_state, app.run_state.current_environment).get("roll_count", 0))
	app._on_game_surface_action("craps_throw", 0)
	var result := app.last_game_result.duplicate(true)
	var table: Dictionary = app.current_game._table_state_preview(app.run_state, app.run_state.current_environment)
	print("CRAPS_CONSUMED_DRAFT_DIAGNOSTIC " + JSON.stringify({"point": point, "pending": ui.get("craps_pending_bets", {}), "ok": result.get("ok"), "message": result.get("message"), "wager": result.get("craps_total_wager"), "roll_before": before_count, "roll_after": table.get("roll_count")}))
	_check(bool(result.get("ok", false)) and int(result.get("craps_total_wager", -1)) == 0, "Next same-session THROW must resolve with no invented wager.")
	_check(int(table.get("roll_count", 0)) == before_count + 1, "Exactly one continuation roll must occur.")
	_check((table.get("last_committed_bets", {}) as Dictionary).is_empty(), "Continuation must commit no unstaged wager.")
	_check(app.run_state.wager_capacity_for_game("craps", app.run_state.current_environment) == funds + int(result.get("bankroll_delta", 0)), "Only settlement of existing stakes may change funds.")
	var after_rng := app.run_state.rng_state
	var after_funds := app.run_state.wager_capacity_for_game("craps", app.run_state.current_environment)
	_sample(app)
	_sample(app)
	_check(app.run_state.rng_state == after_rng and app.run_state.wager_capacity_for_game("craps", app.run_state.current_environment) == after_funds, "Presentation refresh must not repeat RNG or money.")
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
	print("CRAPS_CONSUMED_DRAFT_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
