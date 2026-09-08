extends SceneTree

# Guards the user-visible startup cadence. The menu may appear quickly while
# deferred run UI work still causes multi-second frames, so ready-to-menu timing
# alone cannot detect the regression this contract covers.

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const TEST_SAVE_SLOT := "menu_prewarm_performance_contract"
const MAX_PREWARM_MSEC := 20_000
const MAX_MENU_FRAME_MSEC := 250.0
const MAX_PREWARMED_PLAY_MSEC := 2_000

var cleanup_save_service: Object


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene := load(MAIN_SCENE_PATH) as PackedScene
	if main_scene == null:
		_fail("Main scene could not load.")
		return
	var app := main_scene.instantiate() as Control
	app.set("force_deferred_startup_for_test", true)
	app.set("autosave_slot_id", TEST_SAVE_SLOT)
	root.add_child(app)
	await process_frame
	cleanup_save_service = app.get("save_service")
	var started_msec := Time.get_ticks_msec()
	var previous_usec := Time.get_ticks_usec()
	var worst_frame_msec := 0.0
	var frame_count := 0
	while not bool(app.get("run_ui_built")):
		await process_frame
		var now_usec := Time.get_ticks_usec()
		worst_frame_msec = maxf(worst_frame_msec, float(now_usec - previous_usec) / 1000.0)
		previous_usec = now_usec
		frame_count += 1
		if Time.get_ticks_msec() - started_msec > MAX_PREWARM_MSEC:
			_fail("Run UI prewarm exceeded %d ms (stage %d)." % [MAX_PREWARM_MSEC, int(app.get("run_ui_build_stage"))])
			return
	if worst_frame_msec > MAX_MENU_FRAME_MSEC:
		_fail("Deferred run UI prewarm blocked an interactive-menu frame for %.3f ms (budget %.1f ms)." % [worst_frame_msec, MAX_MENU_FRAME_MSEC])
		return
	if str(app.get("current_screen")) != "START":
		_fail("Background run UI prewarm navigated away from the main menu.")
		return
	var play_started := Time.get_ticks_msec()
	if not bool(app.call("start_foundation_run", "MENU-PREWARM-PERFORMANCE", {}, false)):
		_fail("Play failed after background run UI prewarm.")
		return
	var play_msec := Time.get_ticks_msec() - play_started
	if play_msec > MAX_PREWARMED_PLAY_MSEC:
		_fail("Prewarmed Play exceeded %d ms: %d ms." % [MAX_PREWARMED_PLAY_MSEC, play_msec])
		return
	if app.get("run_state") == null or str(app.get("current_screen")) != "ENVIRONMENT":
		_fail("Prewarmed Play did not enter a live environment.")
		return
	print("MENU_PREWARM_PERFORMANCE status=PASS prewarm_msec=%d frames=%d worst_menu_frame_msec=%.3f prewarmed_play_msec=%d" % [
		Time.get_ticks_msec() - started_msec,
		frame_count,
		worst_frame_msec,
		play_msec,
	])
	_cleanup()
	app.queue_free()
	await process_frame
	quit(0)


func _cleanup() -> void:
	if cleanup_save_service != null:
		cleanup_save_service.call("clear_run", TEST_SAVE_SLOT)


func _fail(message: String) -> void:
	_cleanup()
	push_error(message)
	quit(1)
