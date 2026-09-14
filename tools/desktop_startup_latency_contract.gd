extends SceneTree

# Runtime startup contract: the default menu must become interactive before full
# content validation and run-overlay construction, while immediate Play remains safe.

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAX_READY_TO_MENU_MSEC := 1000
const TEST_SAVE_SLOT := "desktop_startup_latency_contract"

var cleanup_save_service: Object


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene := load(MAIN_SCENE_PATH) as PackedScene
	if main_scene == null:
		_fail("Main scene could not load.")
		return
	var app := main_scene.instantiate() as Control
	app.set("autosave_slot_id", TEST_SAVE_SLOT)
	root.add_child(app)
	await process_frame
	var telemetry: Dictionary = app.call("boot_telemetry_snapshot")
	var menu_event := _event(telemetry.get("events", []), "main_menu_interactive")
	var content: Dictionary = telemetry.get("content_library", {}) if typeof(telemetry.get("content_library", {})) == TYPE_DICTIONARY else {}
	if menu_event.is_empty():
		_fail("Startup telemetry did not publish an interactive-menu boundary.")
		return
	if int(menu_event.get("relative_msec", MAX_READY_TO_MENU_MSEC + 1)) > MAX_READY_TO_MENU_MSEC:
		_fail("Interactive menu exceeded the %d ms ready-phase budget: %s" % [MAX_READY_TO_MENU_MSEC, JSON.stringify(menu_event)])
		return
	if not bool(content.get("start_menu_only", false)) or not bool(content.get("validation_deferred", false)):
		_fail("Release startup loaded or validated run-only content before the menu: %s" % JSON.stringify(content))
		return
	var play_started := Time.get_ticks_msec()
	if not bool(app.call("start_foundation_run", "DESKTOP-STARTUP-IMMEDIATE-PLAY", {}, false)):
		_fail("Immediate Play failed while deferred startup work was incomplete.")
		return
	if app.get("run_state") == null or str(app.get("current_screen")) != "ENVIRONMENT":
		_fail("Immediate Play did not enter a live environment.")
		return
	var immediate_run: RunState = app.get("run_state")
	if str(immediate_run.challenge_config.get("mode", "")) != "standard" \
			or immediate_run.challenge_modifiers().has("content_groups"):
		_fail("Immediate Play derived a custom content-group run from the partial menu catalog.")
		return
	immediate_run = null
	var immediate_play_msec := Time.get_ticks_msec() - play_started
	cleanup_save_service = app.get("save_service")
	if cleanup_save_service == null or int(cleanup_save_service.call("save_run", app.get("run_state"), TEST_SAVE_SLOT)) != OK:
		_fail("Immediate Play fixture could not create its isolated Continue save.")
		return
	app.queue_free()
	await process_frame
	var continue_app := main_scene.instantiate() as Control
	continue_app.set("autosave_slot_id", TEST_SAVE_SLOT)
	root.add_child(continue_app)
	await process_frame
	var continue_started := Time.get_ticks_msec()
	if not bool(continue_app.call("load_foundation_run")):
		_fail("Immediate Continue failed while deferred startup work was incomplete.")
		return
	var continued_run: Variant = continue_app.get("run_state")
	if continued_run == null or str(continued_run.get("seed_text")) != "DESKTOP-STARTUP-IMMEDIATE-PLAY":
		_fail("Immediate Continue did not restore the isolated run.")
		return
	print("DESKTOP_STARTUP_LATENCY status=PASS ready_to_menu_msec=%d immediate_play_msec=%d immediate_continue_msec=%d" % [
		int(menu_event.get("relative_msec", 0)),
		immediate_play_msec,
		Time.get_ticks_msec() - continue_started,
	])
	cleanup_save_service.call("clear_run", TEST_SAVE_SLOT)
	continue_app.queue_free()
	await process_frame
	quit(0)


func _event(events_value: Variant, event_id: String) -> Dictionary:
	if typeof(events_value) != TYPE_ARRAY:
		return {}
	for event_value in events_value as Array:
		if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("id", "")) == event_id:
			return (event_value as Dictionary).duplicate(true)
	return {}


func _fail(message: String) -> void:
	if cleanup_save_service != null:
		cleanup_save_service.call("clear_run", TEST_SAVE_SLOT)
	push_error(message)
	quit(1)
