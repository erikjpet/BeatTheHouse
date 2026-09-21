extends SceneTree

const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const SettingsMenuScript := preload("res://scripts/ui/settings_menu.gd")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const FoundationWidgetsScript := preload("res://scripts/ui/foundation_widgets.gd")

const TEST_SETTINGS_PATH := "user://fixsweep06_1_lifecycle_settings.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, TEST_SETTINGS_PATH)
	await _check_application_pause_owner()
	await _check_surface_pause_and_hold_recovery()
	await _check_settings_cancel_matrix()
	for child in root.get_children():
		child.queue_free()
	for frame in range(4):
		await process_frame
	if failures.is_empty():
		print("FIXSWEEP06_1_LIFECYCLE PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_application_pause_owner() -> void:
	var app: Control = FoundationMainScript.new()
	app.set("continuous_environment_clock_enabled", true)
	var environment_canvas = PixelSceneCanvasScript.new()
	var game_canvas = GameSurfaceCanvasScript.new()
	app.set("environment_canvas", environment_canvas)
	app.set("game_surface_canvas", game_canvas)
	if not app.has_method("set_application_pause_owner") or not app.has_method("application_lifecycle_snapshot"):
		failures.append("BTH-052: FoundationMain exposes no application focus/minimize pause owner.")
	else:
		var run_state = RunStateScript.new()
		run_state.start_new("FIXSWEEP-LIFECYCLE")
		app.set("run_state", run_state)
		app.set("current_screen", "ENVIRONMENT")
		var before := JSON.stringify(run_state.to_dict()) if run_state != null else ""
		app.call("set_application_pause_owner", "focus_out", true)
		app.call("_advance_run_game_clock", 3.0)
		var paused_snapshot: Dictionary = app.call("application_lifecycle_snapshot")
		var after := JSON.stringify(run_state.to_dict()) if run_state != null else ""
		if not bool(paused_snapshot.get("simulation_paused", false)) or before != after:
			failures.append("BTH-052: player-affecting run state changed while the application pause owner was active.")
		if not bool(paused_snapshot.get("environment_canvas_paused", false)) or not bool(paused_snapshot.get("game_canvas_paused", false)):
			failures.append("BTH-052/BTH-047: application pause did not reach both production canvases.")
		app.call("set_application_pause_owner", "focus_out", false)
		var resumed_snapshot: Dictionary = app.call("application_lifecycle_snapshot")
		if bool(resumed_snapshot.get("application_paused", true)):
			failures.append("BTH-052: clearing the requested lifecycle owner left application pause active: %s." % JSON.stringify(resumed_snapshot))
	game_canvas.free()
	environment_canvas.free()
	app.free()


func _check_surface_pause_and_hold_recovery() -> void:
	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.size = Vector2(768, 432)
	root.add_child(canvas)
	await process_frame
	if not canvas.has_method("set_modal_activity_paused") or not canvas.has_method("handle_application_lifecycle"):
		failures.append("BTH-047/BTH-053: game surface has no centralized timed-feedback pause and application-lifecycle recovery contract.")
		canvas.queue_free()
		await process_frame
		return
	var before_sim := int(canvas.call("surface_simulation_time_msec"))
	var before_presentation := int(canvas.call("surface_presentation_time_msec"))
	canvas.call("set_modal_activity_paused", true)
	canvas.call("_process", 0.35)
	var paused_debug: Dictionary = canvas.call("debug_pause_contract_snapshot")
	if int(canvas.call("surface_simulation_time_msec")) != before_sim or int(canvas.call("surface_presentation_time_msec")) != before_presentation:
		failures.append("BTH-047: paused surface clocks advanced behind Run Menu/Settings.")
	if not bool(paused_debug.get("timed_feedback_paused", false)) or not bool((paused_debug.get("surface_sfx", {}) as Dictionary).get("surface_activity_paused", false)):
		failures.append("BTH-047: surface SFX did not receive the pause owner.")
	canvas.call("set_modal_activity_paused", false)
	canvas.call("_process", 0.35)
	if int(canvas.call("surface_simulation_time_msec")) <= before_sim or int(canvas.call("surface_presentation_time_msec")) <= before_presentation:
		failures.append("BTH-047: surface clocks did not resume after the pause owner cleared.")
	var phases: Array[String] = []
	canvas.surface_pointer_action.connect(func(_action: String, _index: int, phase: String, _position: Vector2) -> void: phases.append(phase))
	for modality in ["mouse", "touch", "key", "joy"]:
		canvas.call("surface_add_hold_hit", Rect2(40, 40, 80, 60), "fixture_hold")
		_send_hold_event(canvas, modality, true)
		canvas.call("handle_application_lifecycle", false)
		canvas.call("handle_application_lifecycle", false)
		_send_hold_event(canvas, modality, false)
		canvas.call("handle_application_lifecycle", true)
		_send_hold_event(canvas, modality, true)
		_send_hold_event(canvas, modality, false)
	var expected: Array[String] = []
	for modality in ["mouse", "touch", "key", "joy"]:
		expected.append_array(["begin", "cancel", "begin", "end"])
	if phases != expected:
		failures.append("BTH-053: application focus loss did not cancel each hold exactly once or rejected a fresh gesture: %s." % JSON.stringify(phases))
	var final_debug: Dictionary = canvas.call("debug_pause_contract_snapshot")
	if not str(final_debug.get("captured_surface_action", "")).is_empty() or bool(final_debug.get("captured_pointer_move_pending", true)):
		failures.append("BTH-053: lifecycle recovery left capture/coalesced movement armed.")
	canvas.queue_free()
	await process_frame


func _send_hold_event(canvas: Control, modality: String, pressed: bool) -> void:
	var position := Vector2(80, 70)
	match modality:
		"mouse":
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.position = position
			canvas.call("_gui_input", event)
		"touch":
			if pressed:
				canvas.set("last_mouse_press_msec", -100000)
			var event := InputEventScreenTouch.new()
			event.pressed = pressed
			event.position = position
			canvas.call("_gui_input", event)
		"key":
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.pressed = pressed
			canvas.call("_gui_input", event)
		"joy":
			var event := InputEventJoypadButton.new()
			event.button_index = JOY_BUTTON_A
			event.pressed = pressed
			canvas.call("_gui_input", event)


func _check_settings_cancel_matrix() -> void:
	var committed := UserSettingsScript.new()
	committed.reset()
	committed.high_contrast = false
	VisualStyleScript.set_high_contrast_enabled(false)
	var baseline := committed.to_dict()
	for field in ["text_size", "ui_scale", "play_on_small_screen", "reduce_motion", "audio_calm"]:
		var host := Control.new()
		host.size = Vector2(640, 360)
		root.add_child(host)
		var menu = SettingsMenuScript.new()
		host.add_child(menu)
		menu.setup(committed)
		menu.open()
		await process_frame
		var draft: UserSettings = menu.get("draft")
		draft.high_contrast = true
		match field:
			"text_size": draft.text_size = "large"
			"ui_scale": draft.ui_scale = 1.30
			"play_on_small_screen": draft.play_on_small_screen = true
			"reduce_motion": draft.reduce_motion = true
			"audio_calm": draft.audio_calm = true
		menu.call("_apply_accessibility_settings")
		var cancel := InputEventAction.new()
		cancel.action = "ui_cancel"
		cancel.pressed = true
		menu._input(cancel)
		await process_frame
		var fresh_button := FoundationWidgetsScript.button("Fresh", Callable(self, "_noop"))
		if committed.to_dict() != baseline or VisualStyleScript.high_contrast_enabled or fresh_button.get_theme_color("font_color") != VisualStyleScript.WHITE:
			failures.append("BTH-054: canceling draft field %s leaked settings or global palette state." % field)
		fresh_button.free()
		host.queue_free()
		await process_frame


func _noop() -> void:
	pass
