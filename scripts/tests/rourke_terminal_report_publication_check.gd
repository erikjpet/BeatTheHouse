extends SceneTree

const Host := preload("res://scripts/ui/foundation_main.gd")
const FIXTURE := "res://scripts/tests/fixtures/integ06_1/v0_5_1/v051_grand_casino_back_room_duel.json"
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _run() -> void:
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	app._ensure_run_ui_built()
	for outcome in [RunState.RUN_STATUS_FAILED, RunState.RUN_STATUS_ENDED]:
		var slot: String = "report_publication_" + str(outcome)
		var path: String = app.save_service.run_save_path(slot)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(FIXTURE)); file.close()
		var run: RunState = app.save_service.load_run(slot)
		_expect(run != null, "official preserved fixture loads")
		if run == null: continue
		run.run_status = outcome
		if outcome == RunState.RUN_STATUS_FAILED:
			run.run_failure_reason = RunState.FAILURE_CASINO_TAKEN_OUT_BACK
		app.run_state = run
		app.current_screen = Host.SCREEN_FAILURE if outcome == RunState.RUN_STATUS_FAILED else Host.SCREEN_VICTORY
		app.run_report_screen.hide()
		app.run_report_screen.clear_report()
		app.run_report_model_key = ""
		var game := preload("res://scripts/games/blackjack.gd").new()
		app.current_game = game
		app.game_surface_canvas.set_game_module(game)
		app.game_surface_canvas.render_game_snapshot({"game_id":"blackjack","display_name":"Rourke table"})
		app._rourke_resolution = {"step":5}
		app._clear_terminal_interaction_state()
		_expect(app.current_game == null and app.game_surface_canvas.game_id == "blackjack", "terminal input clears while prior table presentation is retained")
		var before := JSON.stringify(run.to_dict())
		for step in [5, 6]:
			app._rourke_resolution["step"] = step
			app._rourke_resolution_dispatch_active = true
			app._finish_foundation_refresh(step == 6)
			_expect(not app.run_report_screen.visible and app.run_report_screen.report_model.is_empty(), "phase5/6 do not publish blank or stale report, including prepared-room path")
			_expect(bool(app._rourke_resolution.get("terminal_presentation_pending",false)), "publication remains scheduled for phase7")
			_expect(app.game_surface_canvas.game_id == "blackjack", "no generic Foundation Game fallback during deferred report")
		app._rourke_resolution["step"] = 7
		app._present_terminal_run_screen()
		_expect(app.run_report_screen.visible and not app.run_report_screen.report_model.is_empty(), "phase7 immediately publishes populated final report")
		_expect(not app.game_surface_canvas.visible and app.game_surface_canvas.game_id.is_empty(), "table resources clear only after terminal layout replaces them")
		_expect(app.run_report_screen.seed_label.text == "Seed: " + run.seed_text, "published result belongs to current run")
		var installs: int = app.run_report_screen.timeline_install_count
		app._present_terminal_run_screen()
		_expect(app.run_report_screen.timeline_install_count == installs, "repeated terminal presentation reuses complete report")
		_expect(JSON.stringify(run.to_dict()) == before, "publication changes no authoritative run state")
		app._rourke_resolution = {}
		app._rourke_resolution_dispatch_active = false
		_expect(app.save_service.save_run(run,slot) == OK, "terminal checkpoint saves normally")
		var cold: RunState = app.save_service.load_run(slot)
		_expect(cold != null and cold.run_status == outcome and cold.rng_state == run.rng_state and cold.bankroll == run.bankroll, "cold Continue retains ending, money and RNG")
		app.run_state = cold
		app.run_report_screen.hide()
		app.run_report_model_key = ""
		app._present_terminal_run_screen()
		_expect(app.run_report_screen.visible and not app.run_report_screen.report_model.is_empty(), "cold terminal presentation needs no deferred phase")
	var output := FileAccess.open(OS.get_environment("BTH_TARGET_OUTPUT"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures,"fidelity":"Native UI phase-state fixtures on production-loaded preserved save; failure/success, phase5/6, phase7, repeat, checkpoint and cold load. Actual Web action separately qualified."},"  ")); output.close()
	app.queue_free(); await process_frame; await process_frame
	print("ROURKE_REPORT_PUBLICATION checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
