extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const SettingsMenuScript := preload("res://scripts/ui/settings_menu.gd")
const TalkDockScript := preload("res://scripts/ui/talk_dock.gd")
const WorldMapOverlayControllerScript := preload("res://scripts/ui/world_map_overlay_controller.gd")
const SmallScreenPolicyScript := preload("res://scripts/ui/small_screen_policy.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")

const TEST_SETTINGS_PATH := "user://fixsweep06_1_accessibility_settings.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, TEST_SETTINGS_PATH)
	var isolated := UserSettingsScript.new()
	isolated.reset()
	isolated.save()
	_check_controller_actions()
	await _check_world_map_keyboard_contract()
	await _check_settings_cancel_contract()
	await _check_small_screen_policy_contract()
	await _check_talk_dock_reduce_motion_contract()
	await _check_host_accessibility_contracts()
	for child in root.get_children():
		child.queue_free()
	for frame in range(4):
		await process_frame
	if failures.is_empty():
		print("FIXSWEEP06_1_ACCESSIBILITY PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_controller_actions() -> void:
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	var cancel := InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_B
	cancel.pressed = true
	if not InputMap.event_is_action(accept, "ui_accept"):
		failures.append("BTH-038: controller south/A is not mapped to ui_accept.")
	if not InputMap.event_is_action(cancel, "ui_cancel"):
		failures.append("BTH-038: controller east/B is not mapped to ui_cancel.")
	var enter_preserved := false
	var escape_preserved := false
	for event in InputMap.action_get_events("ui_accept"):
		if event is InputEventKey and ((event as InputEventKey).keycode == KEY_ENTER or (event as InputEventKey).physical_keycode == KEY_ENTER):
			enter_preserved = true
	for event in InputMap.action_get_events("ui_cancel"):
		if event is InputEventKey and ((event as InputEventKey).keycode == KEY_ESCAPE or (event as InputEventKey).physical_keycode == KEY_ESCAPE):
			escape_preserved = true
	if not enter_preserved or not escape_preserved:
		failures.append("BTH-038: explicit controller actions did not preserve Enter and Escape keyboard bindings.")


func _check_world_map_keyboard_contract() -> void:
	var host := Control.new()
	host.size = Vector2(640, 360)
	root.add_child(host)
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)
	var holder := Control.new()
	holder.size = Vector2(600, 300)
	overlay.add_child(holder)
	var layer := Control.new()
	layer.size = holder.size
	holder.add_child(layer)
	var title := Label.new()
	var popup := PanelContainer.new()
	var detail := Label.new()
	var badges := VBoxContainer.new()
	var confirm := Button.new()
	confirm.text = "Travel"
	var keyboard_state := {"selected": "", "confirmed": 0}
	confirm.pressed.connect(func() -> void: keyboard_state["confirmed"] = int(keyboard_state.get("confirmed", 0)) + 1)
	for node in [title, popup, detail, badges, confirm]:
		overlay.add_child(node)
	var controller = WorldMapOverlayControllerScript.new()
	controller.node_pressed.connect(func(node_id: String) -> void: keyboard_state["selected"] = node_id)
	controller.configure_nodes(overlay, holder, layer, title, popup, detail, badges, confirm)
	controller.sync_node_buttons({"nodes": [
		{"id": "stop_a", "label": "Stop A", "position": {"x": 0.2, "y": 0.5}},
		{"id": "stop_b", "label": "Stop B", "position": {"x": 0.8, "y": 0.5}},
	]})
	await process_frame
	var buttons: Array[Button] = []
	for child in layer.get_children():
		if child is Button and (child as Button).visible and not (child as Button).disabled:
			buttons.append(child as Button)
	if buttons.size() != 2:
		failures.append("BTH-028: world-map fixture did not expose both destination buttons.")
	else:
		for button in buttons:
			if button.focus_mode == Control.FOCUS_NONE or button.text.strip_edges().is_empty() or button.accessibility_name.strip_edges().is_empty():
				failures.append("BTH-028: a world-map destination is not focusable with visible and accessible identity text.")
				break
		if not controller.has_method("focus_first_available"):
			failures.append("BTH-028: world-map controller has no deterministic keyboard entry focus.")
		else:
			controller.call("focus_first_available")
			await process_frame
			if not buttons.has(root.gui_get_focus_owner()):
				failures.append("BTH-028: focus did not enter a revealed destination.")
		if buttons[0].focus_neighbor_right.is_empty() or buttons[1].focus_neighbor_left.is_empty():
			failures.append("BTH-028: world-map destinations have no explicit spatial focus neighbors.")
		_send_key(KEY_RIGHT)
		await process_frame
		if root.gui_get_focus_owner() != buttons[1]:
			failures.append("BTH-028: directional key input did not focus the next spatial destination.")
		_send_key(KEY_ENTER)
		await process_frame
		if str(keyboard_state.get("selected", "")) != "stop_b":
			failures.append("BTH-028: ui_accept did not select the keyboard-focused destination.")
		_send_key(KEY_TAB)
		await process_frame
		if root.gui_get_focus_owner() != confirm:
			failures.append("BTH-028: Tab did not advance from destinations to Travel.")
		_send_key(KEY_ENTER)
		await process_frame
		if int(keyboard_state.get("confirmed", 0)) != 1:
			failures.append("BTH-028: keyboard-only map traversal did not confirm Travel.")
	host.queue_free()
	await process_frame


func _check_settings_cancel_contract() -> void:
	var host := Control.new()
	host.size = Vector2(640, 360)
	root.add_child(host)
	var prior := Button.new()
	prior.text = "Open Settings"
	host.add_child(prior)
	var menu = SettingsMenuScript.new()
	menu.size = host.size
	host.add_child(menu)
	var settings := UserSettingsScript.new()
	settings.reset()
	menu.setup(settings)
	var back_state := {"count": 0}
	menu.back_requested.connect(func() -> void:
		back_state["count"] = int(back_state.get("count", 0)) + 1
		menu.visible = false
	)
	prior.grab_focus()
	await process_frame
	menu.open()
	await process_frame
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	menu._input(cancel)
	await process_frame
	await process_frame
	if int(back_state.get("count", 0)) != 1 or menu.visible:
		failures.append("BTH-029: Settings did not close exactly once on ui_cancel.")
	if root.gui_get_focus_owner() != prior:
		failures.append("BTH-029: Settings did not restore focus after ui_cancel.")
	host.queue_free()
	await process_frame


func _check_small_screen_policy_contract() -> void:
	if SmallScreenPolicyScript.ENVIRONMENT_ACTION_HEIGHT < SmallScreenPolicyScript.CONTROL_TOUCH_TARGET_HEIGHT:
		failures.append("BTH-030: primary environment action target remains below the 52 px small-screen policy.")
	if SmallScreenPolicyScript.ENVIRONMENT_INLINE_ACTION_HEIGHT < SmallScreenPolicyScript.CONTROL_TOUCH_TARGET_HEIGHT:
		failures.append("BTH-030: inline environment action target remains below the 52 px small-screen policy.")
	var canvas = PixelSceneCanvasScript.new()
	canvas.size = Vector2(640, 360)
	root.add_child(canvas)
	canvas.set_small_screen_mode(true)
	canvas.render_owned_environment_snapshot({
		"id": "accessibility_action_fixture",
		"display_name": "Accessibility Fixture",
		"interactable_objects": [{
			"object_id": "game:bar_dice",
			"object_type": "game",
			"visual_type": "game",
			"label": "Bar Dice",
			"interactive": true,
			"enabled": true,
			"normalized_rect": {"x": 0.25, "y": 0.45, "w": 0.15, "h": 0.16},
			"available_actions": [{"id": "enter_game", "label": "Enter"}],
			"confirm_action_id": "enter_game",
		}],
	})
	canvas.set_selected_object("game:bar_dice")
	await process_frame
	var audit: Dictionary = canvas.accessibility_clickable_rect_audit()
	var has_action := false
	for entry_value in audit.get("entries", []):
		if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("kind", "")) == "action":
			has_action = true
	if not has_action or not bool(audit.get("valid", false)):
		failures.append("BTH-030: custom-drawn small-screen clickable-rect audit did not cover a valid environment action: %s." % JSON.stringify(audit))
	canvas.queue_free()
	await process_frame


func _check_talk_dock_reduce_motion_contract() -> void:
	var host := Control.new()
	host.size = Vector2(640, 360)
	root.add_child(host)
	var dock = TalkDockScript.new()
	dock.size = host.size
	host.add_child(dock)
	await process_frame
	dock.set_reduce_motion(true)
	for serial in range(2):
		dock.set_entry({
			"event_id": "reduce_motion_%d" % serial,
			"speaker": {"role": "patron", "name": "Mara"},
		}, {
			"display_name": "Quiet entry %d" % serial,
			"summary": "This entry must appear already settled.",
			"choices": [{"id": "ok", "label": "Okay", "text": "Continue."}],
		}, 0)
		var panel: Control = dock.get("panel")
		var portrait: Control = dock.get("portrait_model")
		var tweens: Array = dock.attention_tween_lifecycle_snapshot()
		if not tweens.is_empty() or panel == null or panel.modulate != Color.WHITE or portrait == null or portrait.scale != Vector2.ONE:
			failures.append("BTH-032: Reduce Motion TalkDock entry %d created motion or unsettled transforms." % serial)
	host.queue_free()
	await process_frame


func _check_host_accessibility_contracts() -> void:
	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	await process_frame
	await process_frame
	app.set("WagerConfirmationControllerScript", load("res://scripts/ui/wager_confirmation_controller.gd"))
	var settings: UserSettings = app.get("user_settings")
	settings.play_on_small_screen = true
	settings.ui_scale = 1.30
	settings.text_size = "large"
	app.call("_apply_accessibility_settings")
	var stack := VBoxContainer.new()
	app.add_child(stack)
	var dynamic_button: Button = app.call("_add_card_button", stack, "Dynamic environment action", Callable(self, "_noop"), false, false)
	if dynamic_button.custom_minimum_size.y < SmallScreenPolicyScript.CONTROL_TOUCH_TARGET_HEIGHT or dynamic_button.get_theme_font_size("font_size") <= 13:
		failures.append("BTH-031: rebuilt environment action did not inherit active target and font scaling.")
	if app.get("event_choice_popup_choices_list") == null:
		app.call("_build_event_choice_popup_overlay")
	var popup_list: VBoxContainer = app.get("event_choice_popup_choices_list")
	app.call("_clear_event_choice_popup_choices")
	app.call("_add_wager_confirmation_card", "Event choice", "Choose this response.", "No consequence.", Callable(self, "_noop"), false)
	var event_button := popup_list.find_children("*", "Button", true, false)[0] as Button if not popup_list.find_children("*", "Button", true, false).is_empty() else null
	if event_button == null or event_button.custom_minimum_size.y < SmallScreenPolicyScript.CONTROL_TOUCH_TARGET_HEIGHT or event_button.get_theme_font_size("font_size") <= 13:
		failures.append("BTH-031: rebuilt event-popup action did not inherit active target and font scaling.")
	app.call("_clear_event_choice_popup_choices")
	var background := app.get("start_menu_settings_button") as Button
	if background == null:
		background = Button.new()
		background.text = "Background"
		app.add_child(background)
	background.grab_focus()
	app.call("_show_meta_popup", "Decision", "Choose inside this popup.", "accessibility_probe")
	app.call("_add_meta_close_card")
	await process_frame
	await process_frame
	var choices: Control = app.get("event_choice_popup_choices_list")
	var focus_owner := root.gui_get_focus_owner()
	if focus_owner == background or choices == null or not choices.is_ancestor_of(focus_owner):
		failures.append("BTH-035: dismissible decision popup did not acquire keyboard focus.")
	app.call("open_settings_menu")
	if app.get("settings_overlay") != null and (app.get("settings_overlay") as Control).visible:
		failures.append("BTH-035: a background Settings action opened behind the decision popup.")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	app.call("_input", cancel)
	await process_frame
	await process_frame
	if (app.get("event_choice_popup_overlay") as Control).visible:
		failures.append("BTH-035: dismissible decision popup ignored ui_cancel.")
	if root.gui_get_focus_owner() != background:
		failures.append("BTH-035: closing a decision popup did not restore its prior focus owner.")
	app.call("_show_meta_popup", "Blocking Decision", "This one requires an explicit choice.", "blocking_probe")
	app.call("_add_meta_close_card")
	var blocking_snapshot: Dictionary = app.get("pending_event_choice_popup_snapshot")
	blocking_snapshot["blocking"] = true
	blocking_snapshot["dismissible"] = false
	app.set("pending_event_choice_popup_snapshot", blocking_snapshot)
	app.call("_input", cancel)
	await process_frame
	if not (app.get("event_choice_popup_overlay") as Control).visible:
		failures.append("BTH-035: ui_cancel dismissed a decision whose snapshot forbids cancellation.")
	app.call("_hide_event_choice_popup")
	if not app.has_method("debug_apply_accessibility_viewport"):
		failures.append("BTH-036/BTH-037: host has no shared viewport-bounded modal layout contract.")
	else:
		for viewport_size in [Vector2(1280, 720), Vector2(960, 540), Vector2(800, 450), Vector2(640, 360)]:
			var snapshot: Dictionary = app.call("debug_apply_accessibility_viewport", viewport_size)
			var bounds := Rect2(Vector2.ZERO, viewport_size)
			var map_rect: Rect2 = snapshot.get("world_map_panel_rect", Rect2())
			if not map_rect.has_area() or not bounds.encloses(map_rect):
				failures.append("BTH-036: world-map panel escaped %s: %s." % [str(viewport_size), str(map_rect)])
		var settings_bounds := Rect2(Vector2.ZERO, Vector2(640, 360))
		for small_screen in [false, true]:
			for text_size in ["small", "normal", "large"]:
				for ui_scale in [0.85, 1.0, 1.30]:
					settings.play_on_small_screen = small_screen
					settings.text_size = text_size
					settings.ui_scale = ui_scale
					app.call("_apply_accessibility_settings")
					var settings_snapshot: Dictionary = app.call("debug_apply_accessibility_viewport", Vector2(640, 360))
					var settings_rect: Rect2 = settings_snapshot.get("settings_panel_rect", Rect2())
					if not settings_rect.has_area() or not settings_bounds.encloses(settings_rect):
						failures.append("BTH-037: Settings escaped 640x360 for small=%s text=%s scale=%s." % [str(small_screen), text_size, str(ui_scale)])
					for action_rect_value in settings_snapshot.get("settings_action_rects", []):
						if action_rect_value is Rect2 and not settings_bounds.encloses(action_rect_value as Rect2):
							failures.append("BTH-037: fixed Settings actions escaped 640x360 for small=%s text=%s scale=%s." % [str(small_screen), text_size, str(ui_scale)])
	app.call("_drain_script_prewarm_requests_for_shutdown")
	app.queue_free()
	await process_frame
	await process_frame


func _noop() -> void:
	pass


func _send_key(keycode: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.pressed = true
	root.push_input(pressed)
	var released := InputEventKey.new()
	released.keycode = keycode
	released.pressed = false
	root.push_input(released)
