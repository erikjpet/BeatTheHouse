extends SceneTree

const Foundation := preload("res://scripts/ui/foundation_main.gd")
const Codec := preload("res://scripts/core/run_save_codec.gd")

class ClockHost extends Foundation:
	var test_msec := 100000
	func _environment_simulation_time_msec() -> int:
		return test_msec

var checks := 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var app := ClockHost.new()
	app.continuous_environment_clock_enabled = false
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	var started: Dictionary = app.start_game_test_session("roulette")
	_check(bool(started.get("ok", false)), "Roulette must enter through the ordinary sealed host.")
	if not bool(started.get("ok", false)):
		_finish(app)
		return
	_sample(app)
	var targets: Array = app.game_surface_canvas.state.get("bet_targets", [])
	var red := -1
	for i in range(targets.size()):
		if str((targets[i] as Dictionary).get("type", "")) == "red":
			red = i
	_check(red >= 0, "The ordinary RED target must be available.")
	if red < 0:
		_finish(app)
		return
	app._on_game_surface_action("roulette_bet", red)
	var wager := _pending_total(app)
	_check(wager > 0, "One normal chip must stage an affordable wager.")
	app._on_game_surface_action("roulette_spin", 0)
	app._on_game_surface_action("roulette_spin", 0)
	var result: Dictionary = app.last_game_result.duplicate(true)
	_check(bool(result.get("ok", false)) and int(result.get("roulette_total_wager", 0)) == wager, "The confirmed spin must commit the staged wager once.")
	_check(_pending_total(app) == 0, "Committed chips must leave the authenticated pending layout.")
	_answer_table(app)
	app.autosave_slot_id = "roulette-consumed-wager"
	var saved_cash := app.run_state.bankroll
	var saved_rng := app.run_state.rng_state
	_check(app.save_service.save_run(app.run_state, app.autosave_slot_id) == OK and app.load_foundation_run() and app.enter_game("roulette"), "The completed hand must Save/Continue through the normal host.")
	_check(app.run_state.bankroll == saved_cash and app.run_state.rng_state == saved_rng and _pending_total(app) == 0, "Continue must retain money/RNG without re-staging consumed chips.")
	app.test_msec += 10000
	_sample(app)
	var before_auto := app.run_state.bankroll
	app.test_msec += 41000
	_sample(app)
	var auto_result: Dictionary = app.last_game_result.duplicate(true)
	print("ROULETTE_AUTO_ROUND_DIAGNOSTIC " + JSON.stringify({"ok": auto_result.get("ok"), "sat_out": auto_result.get("roulette_sat_out"), "wager": auto_result.get("roulette_total_wager"), "message": auto_result.get("message")}))
	_check(bool(auto_result.get("ok", false)) and bool(auto_result.get("roulette_sat_out", false)) and int(auto_result.get("roulette_total_wager", -1)) == 0, "The next automatic table round must sit the player out without fresh chips.")
	_check(app.run_state.bankroll == before_auto, "An automatic unwagered round must not charge or pay the old layout.")
	var after_rng := app.run_state.rng_state
	_sample(app)
	_sample(app)
	_check(app.run_state.bankroll == before_auto and app.run_state.rng_state == after_rng, "Presentation refreshes must not replay the round or settlement.")
	_answer_table(app)
	app.test_msec += 10000
	_sample(app)
	app._on_game_surface_action("roulette_rebet", 0)
	_check(_pending_total(app) == wager, "Explicit REBET must retain the previous paid layout after a sit-out round.")
	_check(app.save_service.save_run(app.run_state, app.autosave_slot_id) == OK and app.load_foundation_run() and app.enter_game("roulette"), "A newly staged REBET must Save/Continue.")
	_check(_pending_total(app) == wager, "Continue must preserve newly staged chips rather than clear them as consumed.")
	app.test_msec += 10000
	_sample(app)
	app._on_game_surface_action("roulette_undo", 0)
	_check(_pending_total(app) == 0, "UNDO may remove an explicit REBET without reviving consumed chips.")
	app._on_game_surface_action("roulette_rebet", 0)
	var before_repeat := app.run_state.bankroll
	app._on_game_surface_action("roulette_spin", 0)
	app._on_game_surface_action("roulette_spin", 0)
	var repeat_result: Dictionary = app.last_game_result.duplicate(true)
	_check(bool(repeat_result.get("ok", false)) and int(repeat_result.get("roulette_total_wager", 0)) == wager and _pending_total(app) == 0, "An explicitly confirmed REBET must commit once and consume its chips.")
	_check(app.run_state.bankroll == before_repeat + int(repeat_result.get("bankroll_delta", 0)), "The repeated hand must apply only its own settlement.")
	_check_actual_legacy_projection(app)
	_finish(app)

func _check_actual_legacy_projection(app: ClockHost) -> void:
	var path := OS.get_environment("BTH_ROULETTE_LEGACY_SAVE")
	if path.is_empty():
		return
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var state := RunState.new()
	state.from_dict(Codec.decode(Codec.unpack_from_storage(envelope.get("run_state", {}))))
	var before := JSON.stringify(state.to_dict())
	var table: Dictionary = state.current_environment.get("game_states", {}).get("roulette", {})
	var settled_msec := int(table.get("last_result", {}).get("resolved_at_msec", 0)) + 10000
	var frame := {"surface_time_msec": settled_msec, "surface_presentation_time_msec": settled_msec, "drunk_scaled_surface_time_msec": settled_msec}
	var view: Dictionary = app.current_game.surface_state(state, state.current_environment, frame)
	_check(int(view.get("total_wager_cost", -1)) == 0, "The retained actual old Web save must not re-stage its last committed intent.")
	var rebet: Dictionary = app.current_game.surface_action_command("roulette_rebet", 0, false, frame, state, state.current_environment)
	print("ROULETTE_LEGACY_REBET_DIAGNOSTIC " + JSON.stringify({"message": rebet.get("message")}))
	_check(int(app.current_game._total_wager((rebet.get("ui_state", {}) as Dictionary).get("roulette_bets", []))) == 9, "Explicit REBET must still recover the actual old save's nine-unit layout.")
	_check(JSON.stringify(state.to_dict()) == before, "Legacy presentation and command proposal must not mutate saved authority, money or RNG.")
	# Native cold-clock boundary using the unchanged actual Web save. A fresh
	# browser's monotonic epoch must not wait to catch up with the old timer.
	var cold_frame := {"surface_time_msec": 1000, "surface_presentation_time_msec": 1000, "drunk_scaled_surface_time_msec": 1000}
	var cold_cash := state.bankroll
	var cold_rng := state.rng_state
	_check(app.current_game._table_game_host_needs_auto_tick(1000, state, state.current_environment), "A future saved timer must request a non-economic cold-clock reconciliation.")
	app.current_game.surface_auto_action_command(cold_frame, state, state.current_environment, {})
	var rebased_table: Dictionary = state.current_environment.get("game_states", {}).get("roulette", {})
	_check(int(rebased_table.get("table_round_timer_started_msec", 0)) == 1000, "A future saved deadline must restart from the current host clock.")
	_check(state.bankroll == cold_cash and state.rng_state == cold_rng, "Clock reconciliation must not fund, resolve, pay or advance RNG.")
	var due_frame := {"surface_time_msec": 42000, "surface_presentation_time_msec": 42000, "drunk_scaled_surface_time_msec": 42000}
	var due: Dictionary = app.current_game.surface_auto_action_command(due_frame, state, state.current_environment, {})
	_check(bool(due.get("direct_resolve", false)) and bool((due.get("ui_state", {}) as Dictionary).get("roulette_sit_out", false)), "The rebased automatic deadline must produce an ordinary unwagered round.")

func _pending_total(app: ClockHost) -> int:
	var table: Dictionary = app.run_state.current_environment.get("game_states", {}).get("roulette", {})
	var session: Dictionary = table.get("_blackjack_action_authority", {}).get("session", {})
	return int(app.current_game._total_wager(session.get("roulette_bets", [])))

func _sample(app: ClockHost) -> void:
	app.last_game_surface_realtime_refresh_msec = 0
	app._advance_game_surface_automation()
	app._advance_game_surface_realtime_state()

func _answer_table(app: ClockHost) -> void:
	for entry in app._pending_talk_entries():
		app._on_talk_dock_choice_requested(str((entry as Dictionary).get("event_id", "")), "ignore")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _finish(app: ClockHost) -> void:
	if app.save_service.async_save_in_flight():
		app.save_service.wait_for_async_save()
	app.queue_free()
	print("ROULETTE_CONSUMED_WAGER_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
