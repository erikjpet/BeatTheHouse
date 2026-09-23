extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const SettingsMenuScript := preload("res://scripts/ui/settings_menu.gd")
const TalkDockScript := preload("res://scripts/ui/talk_dock.gd")
const WorldMapOverlayControllerScript := preload("res://scripts/ui/world_map_overlay_controller.gd")
const SmallScreenPolicyScript := preload("res://scripts/ui/small_screen_policy.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")

const TEST_SETTINGS_PATH := "user://fixsweep06_1_accessibility_settings.json"
const POSTFIX_MODAL_SCOPE_PATH := "res://scripts/ui/modal_focus_scope.gd"
const POSTFIX_SAFE_MARGIN := 12.0
const POSTFIX_MIN_TARGET_HEIGHT := 52.0

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
	# Keep the postfix probes last so their deliberately hostile focus/input cases cannot
	# contaminate the established BTH accessibility regressions above.
	await _check_postfix_modal_focus_contract()
	await _check_postfix_responsive_overlay_contract()
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


func _check_postfix_modal_focus_contract() -> void:
	if not ResourceLoader.exists(POSTFIX_MODAL_SCOPE_PATH):
		failures.append("UIENV-PF-002/AIF-001: reusable ModalFocusScope script is missing.")
	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	await _settle_frames(4)
	app.call("start_foundation_run", "POSTFIX-MODAL-ACCESSIBILITY", {})
	await _settle_frames(12)

	var background := Button.new()
	background.name = "PostfixBackgroundAction"
	background.text = "Background action"
	background.focus_mode = Control.FOCUS_ALL
	app.add_child(background)
	var background_state := {"presses": 0}
	background.pressed.connect(func() -> void:
		background_state["presses"] = int(background_state.get("presses", 0)) + 1
	)

	var shared_scope: Variant = _property_value(app, "modal_focus_scope")
	if shared_scope == null:
		failures.append("UIENV-PF-002/AIF-001: FoundationMain has no reusable shared ModalFocusScope.")
	elif not shared_scope is Object:
		failures.append("UIENV-PF-002/AIF-001: FoundationMain's modal focus scope is not an Object.")
	else:
		var scope_object := shared_scope as Object
		for method_name in ["push_scope", "pop_scope", "refresh_scope", "handle_input", "active_root"]:
			if not scope_object.has_method(method_name):
				failures.append("UIENV-PF-002/AIF-001: ModalFocusScope lacks %s()." % method_name)

	background.grab_focus()
	await process_frame
	app.call("open_run_menu")
	await _settle_frames(3)
	var run_menu := app.get("run_menu_overlay") as Control
	_assert_initial_modal_focus(run_menu, "AIF-001 Run Menu")
	await _exercise_modal_containment(run_menu, background, background_state, "AIF-001 Run Menu")

	var journal_button := app.get("run_menu_journal_button") as Button
	if journal_button != null:
		journal_button.grab_focus()
	app.call("open_run_journal")
	await _settle_frames(3)
	var journal := app.get("run_journal_overlay") as Control
	_assert_initial_modal_focus(journal, "AIF-001 Run Journal over Run Menu")
	await _exercise_modal_containment(journal, background, background_state, "AIF-001 Run Journal")
	app.call("close_run_journal")
	await _settle_frames(3)
	if journal_button == null or root.gui_get_focus_owner() != journal_button:
		failures.append("AIF-001: closing topmost Run Journal did not restore its Run Menu opener.")
	app.call("close_run_menu")
	await _settle_frames(3)
	if root.gui_get_focus_owner() != background:
		failures.append("AIF-001: closing Run Menu did not restore the previously focused background control.")

	# Invalid prior owners must fall back to a visible control outside the closed modal.
	background.visible = true
	background.grab_focus()
	app.call("open_run_menu")
	await _settle_frames(2)
	background.visible = false
	app.call("close_run_menu")
	await _settle_frames(3)
	var fallback_owner := root.gui_get_focus_owner()
	if fallback_owner == null or not fallback_owner.is_visible_in_tree() or (run_menu != null and run_menu.is_ancestor_of(fallback_owner)):
		failures.append("AIF-001: Run Menu close has no visible safe fallback when its prior focus owner disappears.")
	background.visible = true

	background.grab_focus()
	app.call("open_run_inventory")
	await _settle_frames(3)
	var inventory := app.get("run_inventory_screen") as Control
	_assert_initial_modal_focus(inventory, "AIF-001 Run Inventory")
	_assert_shared_scope(inventory, shared_scope, "Run Inventory")
	await _exercise_modal_containment(inventory, background, background_state, "AIF-001 Run Inventory")
	app.call("close_run_inventory")
	await _settle_frames(3)
	if root.gui_get_focus_owner() != background:
		failures.append("AIF-001: closing Run Inventory did not restore the prior focus owner.")

	background.grab_focus()
	var meta_screen := app.get("meta_item_interaction_screen") as Control
	_assert_shared_scope(meta_screen, shared_scope, "Meta Item Interaction")
	if meta_screen == null:
		failures.append("AIF-001: Meta Item Interaction screen is unavailable.")
	else:
		meta_screen.call("open", {
			"title": "Meta Item Accessibility Fixture",
			"summary": "No item is required to exercise modal ownership.",
			"items": [],
			"global_actions": [],
		})
		await _settle_frames(3)
		_assert_initial_modal_focus(meta_screen, "AIF-001 Meta Item Interaction")
		await _exercise_modal_containment(meta_screen, background, background_state, "AIF-001 Meta Item Interaction")
		meta_screen.call("close")
		await _settle_frames(3)
		if root.gui_get_focus_owner() != background:
			failures.append("AIF-001: closing Meta Item Interaction did not restore the prior focus owner.")

	background.grab_focus()
	var opened := bool(app.call("open_world_map", true))
	await _settle_frames(8)
	var map_overlay := app.get("world_map_overlay") as Control
	if not opened or map_overlay == null or not map_overlay.visible:
		failures.append("UIENV-PF-002: World Map fixture did not open.")
	else:
		_assert_initial_modal_focus(map_overlay, "UIENV-PF-002 World Map")
		var map_nodes := _world_map_destination_buttons(app)
		var close_button := app.get("world_map_close_button") as Button
		var travel_button := app.get("world_map_confirm_button") as Button
		var initial_ring: Array[Control] = []
		for button in map_nodes:
			initial_ring.append(button)
		if close_button != null:
			initial_ring.append(close_button)
		if travel_button != null and travel_button.is_visible_in_tree() and not travel_button.disabled:
			failures.append("UIENV-PF-002: Travel is enabled before a World Map destination is selected.")
		await _assert_tab_ring(initial_ring, "UIENV-PF-002 World Map before selection", shared_scope as Object if shared_scope is Object else null)
		await _assert_controller_containment(map_overlay, initial_ring, "UIENV-PF-002 World Map before selection")

		var selected_enabled_destination := false
		var selected_destination_id := ""
		for button in map_nodes:
			var node_id := str(button.get_meta("node_id", ""))
			if node_id.is_empty():
				continue
			app.call("select_world_map_node", node_id)
			await _settle_frames(3)
			if travel_button != null and travel_button.is_visible_in_tree() and not travel_button.disabled:
				selected_enabled_destination = true
				selected_destination_id = node_id
				break
		if not selected_enabled_destination:
			failures.append("UIENV-PF-002: World Map fixture could not enable Travel after selection.")
		else:
			var animation_ready := await _wait_for_world_map_focus_animation(app, map_overlay, background, background_state, "UIENV-PF-002 World Map after selection")
			if animation_ready:
				map_nodes = _world_map_destination_buttons(app)
				var selected_destination_visible := false
				for button in map_nodes:
					if str(button.get_meta("node_id", "")) == selected_destination_id:
						selected_destination_visible = true
						break
				if not selected_destination_visible:
					failures.append("UIENV-PF-002: selected World Map destination is not visible after focus zoom settled.")
				if travel_button == null or not _control_is_focusable(travel_button):
					failures.append("UIENV-PF-002: Travel is not enabled after selected-focus zoom settled.")
				var selected_ring: Array[Control] = []
				for button in map_nodes:
					selected_ring.append(button)
				if travel_button != null and _control_is_focusable(travel_button):
					selected_ring.append(travel_button)
				if close_button != null:
					selected_ring.append(close_button)
				await _assert_tab_ring(selected_ring, "UIENV-PF-002 World Map after selection", shared_scope as Object if shared_scope is Object else null)
				await _assert_controller_containment(map_overlay, selected_ring, "UIENV-PF-002 World Map after selection")
		await _assert_background_activation_rejected(map_overlay, background, background_state, "UIENV-PF-002 World Map")
		app.call("close_world_map")
		await _settle_frames(3)
		if root.gui_get_focus_owner() != background:
			failures.append("UIENV-PF-002: closing World Map did not restore the prior focus owner.")

	app.call("_drain_script_prewarm_requests_for_shutdown")
	app.queue_free()
	await _settle_frames(4)


func _check_postfix_responsive_overlay_contract() -> void:
	var original_root_size := root.size
	var original_content_scale_size := root.content_scale_size
	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	await _settle_frames(4)
	var started := bool(app.call("start_foundation_run", "POSTFIX-RESPONSIVE-ACCESSIBILITY", {}))
	await _settle_frames(8)
	if not started:
		failures.append("AIF-002/AIF-003: responsive live fixture could not start its production run.")
		app.call("_drain_script_prewarm_requests_for_shutdown")
		app.queue_free()
		root.content_scale_size = original_content_scale_size
		root.size = original_root_size
		await _settle_frames(4)
		return
	var settings := app.get("user_settings") as UserSettings
	if settings == null:
		failures.append("AIF-002/AIF-003: responsive live fixture has no production UserSettings.")
		app.call("_drain_script_prewarm_requests_for_shutdown")
		app.queue_free()
		root.content_scale_size = original_content_scale_size
		root.size = original_root_size
		await _settle_frames(4)
		return
	var run_menu_scroll := _property_value(app, "run_menu_scroll") as ScrollContainer
	var journal_scroll := _property_value(app, "run_journal_scroll") as ScrollContainer
	var journal_close := _property_value(app, "run_journal_close_button") as Button
	if run_menu_scroll == null or not run_menu_scroll.follow_focus:
		failures.append("AIF-002: Run Menu has no bounded focus-following scroll body.")
	if journal_scroll == null or not journal_scroll.follow_focus or journal_close == null:
		failures.append("AIF-003: Run Journal does not retain a fixed Close control above a focus-following scroll body.")
	# This contract must inspect the live production tree. A synthetic rectangle
	# oracle can agree with its own layout math while the actual Containers clip.
	if app.has_method("debug_apply_accessibility_viewport"):
		failures.append("AIF-002/AIF-003: production still exposes the synthetic responsive-layout oracle instead of relying on live nodes.")
	settings.play_on_small_screen = false
	settings.text_size = "normal"
	settings.ui_scale = 1.0
	app.call("_apply_accessibility_settings")
	await _set_live_viewport(app, Vector2(640, 360))
	await _assert_live_responsive_overlays(app, "(640, 360) empty journal default settings", false)
	var run: Variant = app.get("run_state")
	if run is Object and (run as Object).has_method("log_story"):
		for entry_index in range(24):
			(run as Object).call("log_story", {
				"type": "accessibility_fixture",
				"message": "Responsive journal entry %02d carries enough detail to require the real scroll body." % entry_index,
				"environment_id": "corner_store",
			})

	for viewport_size in [Vector2(640, 360), Vector2(800, 450), Vector2(960, 540)]:
		for text_size in ["normal", "large"]:
			for ui_scale in [1.0, 1.30]:
				for small_screen in [false, true]:
					settings.play_on_small_screen = small_screen
					settings.text_size = text_size
					settings.ui_scale = ui_scale
					app.call("_apply_accessibility_settings")
					await _set_live_viewport(app, viewport_size)
					var label := "%s small=%s text=%s scale=%.2f" % [str(viewport_size), str(small_screen), text_size, ui_scale]
					await _assert_live_responsive_overlays(app, label)
	await _assert_live_open_overlay_relayout(app, settings)
	await _assert_live_tutorial_menu_action(app, settings)

	app.call("_drain_script_prewarm_requests_for_shutdown")
	app.queue_free()
	root.content_scale_size = original_content_scale_size
	root.size = original_root_size
	await _settle_frames(4)


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
	var original_root_size := root.size
	var original_content_scale_size := root.content_scale_size
	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	await process_frame
	await process_frame
	if not bool(app.call("_ensure_run_ui_built")):
		failures.append("BTH-036/BTH-037: production run UI could not be built for live viewport validation.")
		app.call("_drain_script_prewarm_requests_for_shutdown")
		app.queue_free()
		root.content_scale_size = original_content_scale_size
		root.size = original_root_size
		await _settle_frames(2)
		return
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
	var world_map_overlay := app.get("world_map_overlay") as Control
	var world_map_panel := app.get("world_map_panel") as Control
	if world_map_overlay == null or world_map_panel == null:
		failures.append("BTH-036: production World Map controls are unavailable for live viewport validation.")
	else:
		world_map_overlay.visible = true
		for viewport_size in [Vector2(1280, 720), Vector2(960, 540), Vector2(800, 450), Vector2(640, 360)]:
			await _set_live_viewport(app, viewport_size)
			app.call("_layout_world_map_panel")
			await _settle_frames(2)
			var bounds := _live_viewport_rect(app, viewport_size)
			var map_rect := world_map_panel.get_global_rect()
			if not map_rect.has_area() or not _rect_encloses_with_tolerance(bounds, map_rect):
				failures.append("BTH-036: live world-map panel escaped %s: %s." % [str(viewport_size), str(map_rect)])
		world_map_overlay.visible = false

	await _set_live_viewport(app, Vector2(640, 360))
	for small_screen in [false, true]:
		for text_size in ["small", "normal", "large"]:
			for ui_scale in [0.85, 1.0, 1.30]:
				settings.play_on_small_screen = small_screen
				settings.text_size = text_size
				settings.ui_scale = ui_scale
				app.call("_apply_accessibility_settings")
				app.call("open_settings_menu")
				await _settle_frames(3)
				var settings_panel := app.get("settings_panel") as Control
				var live_settings_menu := app.get("settings_menu") as Control
				var settings_bounds := _live_viewport_rect(app, Vector2(640, 360))
				var label := "small=%s text=%s scale=%s" % [str(small_screen), text_size, str(ui_scale)]
				if settings_panel == null or not settings_panel.is_visible_in_tree() or not _rect_encloses_with_tolerance(settings_bounds, settings_panel.get_global_rect()):
					failures.append("BTH-037: live Settings escaped 640x360 for %s." % label)
				if live_settings_menu == null or not live_settings_menu.has_method("action_buttons"):
					failures.append("BTH-037: live Settings exposes no fixed action row for %s." % label)
				else:
					for action_value in live_settings_menu.call("action_buttons"):
						if action_value is Control:
							var action := action_value as Control
							if not action.is_visible_in_tree() or not _rect_encloses_with_tolerance(settings_bounds, action.get_global_rect()):
								failures.append("BTH-037: live fixed Settings action escaped 640x360 for %s." % label)
				app.call("close_settings_menu")
				await _settle_frames(2)
	app.call("_drain_script_prewarm_requests_for_shutdown")
	app.queue_free()
	root.content_scale_size = original_content_scale_size
	root.size = original_root_size
	await process_frame
	await process_frame


func _property_value(target: Object, property_name: String) -> Variant:
	if target == null:
		return null
	for property_value in target.get_property_list():
		if typeof(property_value) == TYPE_DICTIONARY and str((property_value as Dictionary).get("name", "")) == property_name:
			return target.get(property_name)
	return null


func _assert_shared_scope(screen: Control, shared_scope: Variant, label: String) -> void:
	if screen == null:
		return
	var screen_scope: Variant = _property_value(screen, "modal_focus_scope")
	if shared_scope == null or screen_scope == null or screen_scope != shared_scope:
		failures.append("AIF-001: %s does not use FoundationMain's shared ModalFocusScope." % label)


func _assert_initial_modal_focus(modal_root: Control, label: String) -> void:
	if modal_root == null or not modal_root.is_visible_in_tree():
		failures.append("%s did not expose a visible modal root." % label)
		return
	var owner := root.gui_get_focus_owner()
	if owner == null or not modal_root.is_ancestor_of(owner) or not _control_is_focusable(owner):
		failures.append("%s did not acquire meaningful initial focus inside the topmost modal." % label)


func _exercise_modal_containment(modal_root: Control, background: Button, background_state: Dictionary, label: String) -> void:
	if modal_root == null or not modal_root.is_visible_in_tree():
		return
	var controls := _focusable_controls(modal_root)
	if controls.is_empty():
		failures.append("%s exposes no visible enabled focus targets." % label)
		return
	controls[controls.size() - 1].grab_focus()
	_send_key(KEY_TAB)
	await _settle_frames(2)
	_assert_focus_within(modal_root, label + " forward Tab")
	controls[0].grab_focus()
	_send_key(KEY_TAB, true)
	await _settle_frames(2)
	_assert_focus_within(modal_root, label + " reverse Tab")
	await _assert_controller_containment(modal_root, controls, label)
	await _assert_background_activation_rejected(modal_root, background, background_state, label)


func _assert_focus_within(modal_root: Control, label: String) -> void:
	var owner := root.gui_get_focus_owner()
	if owner == null or not modal_root.is_ancestor_of(owner) or not owner.is_visible_in_tree():
		failures.append("%s allowed focus to leave the topmost modal." % label)


func _focusable_controls(modal_root: Control) -> Array[Control]:
	var controls: Array[Control] = []
	if modal_root == null:
		return controls
	for node in modal_root.find_children("*", "Control", true, false):
		if node is Control and _control_is_focusable(node as Control):
			controls.append(node as Control)
	return controls


func _control_is_focusable(control: Control) -> bool:
	if control == null or not control.is_inside_tree() or not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
		return false
	if control.focus_mode == Control.FOCUS_ACCESSIBILITY and not control.get_tree().is_accessibility_enabled():
		return false
	if control is BaseButton and (control as BaseButton).disabled:
		return false
	return true


func _world_map_destination_buttons(app: Control) -> Array[Button]:
	var buttons: Array[Button] = []
	var layer := app.get("world_map_nodes_layer") as Control
	if layer == null:
		return buttons
	for node in layer.find_children("*", "Button", true, false):
		if not node is Button:
			continue
		var button := node as Button
		var node_id := str(button.get_meta("node_id", "")).strip_edges()
		if not node_id.is_empty() and _control_is_focusable(button) and (not layer.has_method("node_is_in_view") or bool(layer.call("node_is_in_view", node_id))):
			buttons.append(button)
	return buttons


func _wait_for_world_map_focus_animation(app: Control, modal_root: Control, background: Button, background_state: Dictionary, label: String) -> bool:
	var layer := app.get("world_map_nodes_layer") as Control
	if layer == null or not layer.has_method("current_view_snapshot"):
		failures.append("%s has no selected-focus animation snapshot." % label)
		return false
	var prior_background_presses := int(background_state.get("presses", 0))
	var background_activation_probed := false
	var settled := false
	for frame_index in range(120):
		var view: Dictionary = layer.call("current_view_snapshot")
		if not bool(view.get("selected_focus_zoom_animating", false)):
			settled = true
			break
		if not background_activation_probed:
			background.grab_focus()
			_send_joy_button(JOY_BUTTON_A)
			background_activation_probed = true
		else:
			_send_key(KEY_TAB, frame_index % 2 == 1)
		await process_frame
		if not _assert_live_world_map_focus(app, modal_root, "%s animation frame %d" % [label, frame_index]):
			return false
		if int(background_state.get("presses", 0)) != prior_background_presses:
			failures.append("%s allowed background activation during selected-focus animation." % label)
			return false
	if not settled:
		failures.append("%s selected-focus animation did not settle within 120 frames." % label)
		return false
	# layout_changed is reconciled through a deferred host relayout. Give that
	# final visibility update one frame before capturing the exact settled ring.
	await process_frame
	return _assert_live_world_map_focus(app, modal_root, label + " settled layout")


func _assert_live_world_map_focus(app: Control, modal_root: Control, label: String) -> bool:
	var owner := root.gui_get_focus_owner()
	if owner == null or modal_root == null or not modal_root.is_ancestor_of(owner) or not _control_is_focusable(owner):
		failures.append("%s did not retain visible, focusable ownership inside World Map." % label)
		return false
	var node_id := str(owner.get_meta("node_id", "")).strip_edges()
	var layer := app.get("world_map_nodes_layer") as Control
	if not node_id.is_empty() and layer != null and layer.has_method("node_is_in_view") and not bool(layer.call("node_is_in_view", node_id)):
		failures.append("%s retained focus on an out-of-view destination '%s'." % [label, node_id])
		return false
	return true


func _assert_tab_ring(controls: Array[Control], label: String, debug_scope: Object = null) -> void:
	var ring: Array[Control] = []
	for control in controls:
		if _control_is_focusable(control) and not ring.has(control):
			ring.append(control)
	if ring.is_empty():
		failures.append("%s has no enabled focus ring." % label)
		return
	var expected_order: Array[String] = []
	for control in ring:
		expected_order.append(_focus_control_identity(control))
	var start := ring[0]
	start.grab_focus()
	await process_frame
	var seen := {}
	var observed_forward: Array[String] = []
	for _step in range(ring.size()):
		var owner := root.gui_get_focus_owner()
		observed_forward.append(_focus_control_identity(owner))
		if owner == null or not ring.has(owner):
			failures.append("%s forward Tab escaped its enabled ring. expected=%s observed=%s" % [label, JSON.stringify(expected_order), JSON.stringify(observed_forward)])
			break
		seen[owner.get_instance_id()] = true
		_send_key(KEY_TAB)
		await _settle_frames(2)
	if seen.size() != ring.size() or root.gui_get_focus_owner() != start:
		failures.append("%s forward Tab did not visit every enabled control exactly once and wrap. expected=%s observed=%s final=%s" % [label, JSON.stringify(expected_order), JSON.stringify(observed_forward), _focus_control_identity(root.gui_get_focus_owner())])

	start.grab_focus()
	await process_frame
	seen.clear()
	if debug_scope != null and debug_scope.has_method("clear_debug_movement_history"):
		debug_scope.call("clear_debug_movement_history")
	var observed_reverse: Array[String] = []
	for _step in range(ring.size()):
		var owner := root.gui_get_focus_owner()
		observed_reverse.append(_focus_control_identity(owner))
		if owner == null or not ring.has(owner):
			failures.append("%s reverse Tab escaped its enabled ring. expected=%s observed=%s" % [label, JSON.stringify(expected_order), JSON.stringify(observed_reverse)])
			break
		seen[owner.get_instance_id()] = true
		_send_key(KEY_TAB, true)
		await _settle_frames(2)
	if seen.size() != ring.size() or root.gui_get_focus_owner() != start:
		var scope_history: Array = debug_scope.call("debug_movement_history") if debug_scope != null and debug_scope.has_method("debug_movement_history") else []
		failures.append("%s reverse Tab did not visit every enabled control exactly once and wrap. expected=%s observed=%s final=%s scope_history=%s" % [label, JSON.stringify(expected_order), JSON.stringify(observed_reverse), _focus_control_identity(root.gui_get_focus_owner()), JSON.stringify(scope_history)])


func _focus_control_identity(control: Control) -> String:
	if control == null:
		return "<null>"
	var node_id := str(control.get_meta("node_id", "")).strip_edges()
	var text := (control as Button).text.strip_edges() if control is Button else ""
	return "%s[node_id=%s,text=%s,id=%d]" % [control.name, node_id, text, control.get_instance_id()]


func _assert_controller_containment(modal_root: Control, controls: Array[Control], label: String) -> void:
	if controls.is_empty():
		return
	controls[controls.size() - 1].grab_focus()
	await process_frame
	for button_index in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP]:
		_send_joy_button(button_index)
		await _settle_frames(2)
		_assert_focus_within(modal_root, label + " controller navigation")


func _assert_background_activation_rejected(modal_root: Control, background: Button, background_state: Dictionary, label: String) -> void:
	var prior_presses := int(background_state.get("presses", 0))
	background.grab_focus()
	await _settle_frames(2)
	_assert_focus_within(modal_root, label + " background-focus rejection")
	_send_joy_button(JOY_BUTTON_A)
	await _settle_frames(2)
	if int(background_state.get("presses", 0)) != prior_presses:
		failures.append("%s allowed controller activation of a background action." % label)
	var controls := _focusable_controls(modal_root)
	if not controls.is_empty():
		controls[0].grab_focus()
		await process_frame


func _assert_live_responsive_overlays(app: Control, label: String, expect_populated_journal: bool = true) -> void:
	app.call("open_run_menu")
	await _settle_frames(3)
	var viewport_rect := _live_viewport_rect(app, app.size)
	var safe_rect := Rect2(
		viewport_rect.position + Vector2(POSTFIX_SAFE_MARGIN, POSTFIX_SAFE_MARGIN),
		Vector2(maxf(1.0, viewport_rect.size.x - POSTFIX_SAFE_MARGIN * 2.0), maxf(1.0, viewport_rect.size.y - POSTFIX_SAFE_MARGIN * 2.0))
	)
	var menu_overlay := app.get("run_menu_overlay") as Control
	var menu_panel := app.get("run_menu_panel") as Control
	var menu_header := app.get("run_menu_header") as Control
	var menu_scroll := app.get("run_menu_scroll") as ScrollContainer
	var menu_actions: Array = app.get("run_menu_action_controls") as Array
	if menu_overlay == null or not menu_overlay.is_visible_in_tree():
		failures.append("AIF-002: live Run Menu did not open for %s." % label)
	elif menu_panel == null or menu_header == null or menu_scroll == null:
		failures.append("AIF-002: live Run Menu structure is incomplete for %s." % label)
	else:
		var panel_rect := menu_panel.get_global_rect()
		var header_rect := menu_header.get_global_rect()
		var scroll_rect := menu_scroll.get_global_rect()
		if not panel_rect.has_area() or not _rect_encloses_with_tolerance(safe_rect, panel_rect):
			failures.append("AIF-002: live Run Menu escaped 12px safe margins for %s: %s." % [label, str(panel_rect)])
		if not header_rect.has_area() or not _rect_encloses_with_tolerance(panel_rect, header_rect):
			failures.append("AIF-002: live Run Menu fixed header escaped its panel for %s." % label)
		if not scroll_rect.has_area() or not _rect_encloses_with_tolerance(panel_rect, scroll_rect) or header_rect.end.y > scroll_rect.position.y + 0.75:
			failures.append("AIF-002: live Run Menu scroll body overlaps or escapes its header for %s." % label)
		if not menu_scroll.follow_focus or menu_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
			failures.append("AIF-002: live Run Menu scroll body does not follow focus for %s." % label)
		if menu_actions.size() != 8:
			failures.append("AIF-002: live Run Menu exposes %d actions instead of eight for %s." % [menu_actions.size(), label])
		var focusable_actions: Array[Control] = []
		for action_value in menu_actions:
			if not action_value is Control:
				failures.append("AIF-002: live Run Menu contains a non-Control action for %s." % label)
				continue
			var action := action_value as Control
			if not menu_scroll.is_ancestor_of(action):
				failures.append("AIF-002: live Run Menu action %s is not owned by its scroll subtree for %s." % [action.name, label])
			if action.size.y + 0.5 < POSTFIX_MIN_TARGET_HEIGHT:
				failures.append("AIF-002: live Run Menu action %s is below 52px for %s." % [action.name, label])
			if action is Button and not (action as Button).has_theme_stylebox_override("focus"):
				failures.append("AIF-002: live Run Menu action %s has no visible focus style for %s." % [action.name, label])
			if not _control_is_focusable(action):
				continue
			focusable_actions.append(action)
			action.grab_focus()
			await _settle_frames(2)
			if root.gui_get_focus_owner() != action or not _rect_encloses_with_tolerance(scroll_rect, action.get_global_rect(), 1.5):
				failures.append("AIF-002: live Run Menu could not scroll focused action %s '%s' fully into view for %s. action=%s scroll=%s" % [action.name, (action as Button).text if action is Button else "", label, str(action.get_global_rect()), str(scroll_rect)])
		if focusable_actions.is_empty():
			failures.append("AIF-002: live Run Menu exposes no enabled focusable actions for %s." % label)
		else:
			focusable_actions[focusable_actions.size() - 1].grab_focus()
			_send_key(KEY_TAB)
			await _settle_frames(2)
			_assert_focus_within(menu_overlay, "AIF-002 %s forward traversal" % label)
			focusable_actions[0].grab_focus()
			_send_key(KEY_TAB, true)
			await _settle_frames(2)
			_assert_focus_within(menu_overlay, "AIF-002 %s reverse traversal" % label)
			await _assert_controller_containment(menu_overlay, focusable_actions, "AIF-002 %s" % label)

	app.call("open_run_journal")
	await _settle_frames(3)
	var journal_overlay := app.get("run_journal_overlay") as Control
	var journal_panel := app.get("run_journal_panel") as Control
	var journal_header := app.get("run_journal_header") as Control
	var journal_scroll := app.get("run_journal_scroll") as ScrollContainer
	var journal_close := app.get("run_journal_close_button") as Button
	var journal_list := app.get("run_journal_list") as Control
	if journal_overlay == null or not journal_overlay.is_visible_in_tree():
		failures.append("AIF-003: live Run Journal did not open for %s." % label)
	elif journal_panel == null or journal_header == null or journal_scroll == null or journal_close == null or journal_list == null:
		failures.append("AIF-003: live Run Journal structure is incomplete for %s." % label)
	else:
		var panel_rect := journal_panel.get_global_rect()
		var header_rect := journal_header.get_global_rect()
		var scroll_rect := journal_scroll.get_global_rect()
		var close_rect := journal_close.get_global_rect()
		if not panel_rect.has_area() or not _rect_encloses_with_tolerance(safe_rect, panel_rect):
			failures.append("AIF-003: live Run Journal escaped 12px safe margins for %s: %s." % [label, str(panel_rect)])
		if not header_rect.has_area() or not _rect_encloses_with_tolerance(panel_rect, header_rect):
			failures.append("AIF-003: live Run Journal fixed header escaped its panel for %s." % label)
		if not close_rect.has_area() or not _rect_encloses_with_tolerance(header_rect, close_rect) or close_rect.size.y + 0.5 < POSTFIX_MIN_TARGET_HEIGHT:
			failures.append("AIF-003: live Run Journal fixed Close target is clipped or below 52px for %s." % label)
		if not scroll_rect.has_area() or not _rect_encloses_with_tolerance(panel_rect, scroll_rect) or header_rect.end.y > scroll_rect.position.y + 0.75:
			failures.append("AIF-003: live Run Journal body overlaps or escapes its fixed header for %s." % label)
		if not journal_scroll.follow_focus or journal_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
			failures.append("AIF-003: live Run Journal body is not a focus-following scroll region for %s." % label)
		if journal_scroll.scroll_vertical != 0:
			failures.append("AIF-003: live Run Journal reopened at stale scroll offset %d for %s." % [journal_scroll.scroll_vertical, label])
		var journal_bar := journal_scroll.get_v_scroll_bar()
		if expect_populated_journal and (journal_bar == null or journal_bar.max_value <= journal_bar.page + 0.5):
			failures.append("AIF-003: populated live Run Journal does not expose its lower content through scrolling for %s." % label)
		var journal_entries: Array[Control] = []
		if expect_populated_journal:
			for child_value in journal_list.get_children():
				if child_value is Control:
					journal_entries.append(child_value as Control)
			if journal_entries.size() != 24:
				failures.append("AIF-003: populated live Run Journal exposes %d cards instead of 24 for %s." % [journal_entries.size(), label])
			for entry in journal_entries:
				if not _control_is_focusable(entry):
					failures.append("AIF-003: live journal entry %s is not keyboard/controller focusable for %s." % [entry.name, label])
					continue
				if entry.accessibility_name.strip_edges().is_empty():
					failures.append("AIF-003: live journal entry %s has no accessible name for %s." % [entry.name, label])
				entry.grab_focus()
				await _settle_frames(2)
				if root.gui_get_focus_owner() != entry or not _rect_encloses_with_tolerance(scroll_rect, entry.get_global_rect(), 1.5):
					failures.append("AIF-003: live Run Journal could not scroll focused entry %s fully into view for %s." % [entry.name, label])
			if not journal_entries.is_empty():
				journal_entries[journal_entries.size() - 1].grab_focus()
				_send_key(KEY_TAB)
				await _settle_frames(2)
				_assert_focus_within(journal_overlay, "AIF-003 %s forward traversal" % label)
				journal_entries[0].grab_focus()
				_send_key(KEY_TAB, true)
				await _settle_frames(2)
				_assert_focus_within(journal_overlay, "AIF-003 %s reverse traversal" % label)
				await _assert_controller_containment(journal_overlay, journal_entries, "AIF-003 %s" % label)
		journal_close.grab_focus()
		await _settle_frames(2)
		if root.gui_get_focus_owner() != journal_close or not _rect_encloses_with_tolerance(header_rect, journal_close.get_global_rect()):
			failures.append("AIF-003: live Run Journal Close focus is not visible for %s." % label)

	app.call("close_run_journal")
	await _settle_frames(2)
	app.call("close_run_menu")
	await _settle_frames(2)


func _assert_live_open_overlay_relayout(app: Control, settings: UserSettings) -> void:
	settings.play_on_small_screen = false
	settings.text_size = "normal"
	settings.ui_scale = 1.0
	app.call("_apply_accessibility_settings")
	await _set_live_viewport(app, Vector2(960, 540))
	app.call("open_run_menu")
	await _settle_frames(2)
	app.call("open_run_journal")
	await _settle_frames(2)
	settings.play_on_small_screen = true
	settings.text_size = "large"
	settings.ui_scale = 1.30
	app.call("_apply_accessibility_settings")
	await _set_live_viewport(app, Vector2(640, 360))
	var viewport_rect := _live_viewport_rect(app, Vector2(640, 360))
	var safe_rect := Rect2(viewport_rect.position + Vector2(POSTFIX_SAFE_MARGIN, POSTFIX_SAFE_MARGIN), viewport_rect.size - Vector2(POSTFIX_SAFE_MARGIN * 2.0, POSTFIX_SAFE_MARGIN * 2.0))
	for descriptor in [
		{"id": "AIF-002 Run Menu", "panel": app.get("run_menu_panel")},
		{"id": "AIF-003 Run Journal", "panel": app.get("run_journal_panel")},
	]:
		var panel := descriptor.get("panel") as Control
		if panel == null or not panel.is_visible_in_tree() or not _rect_encloses_with_tolerance(safe_rect, panel.get_global_rect()):
			failures.append("%s did not relayout inside 640x360 while already open under maximum accessibility settings." % str(descriptor.get("id", "Overlay")))
	var journal_close := app.get("run_journal_close_button") as Button
	if journal_close != null:
		journal_close.grab_focus()
		await _settle_frames(2)
		_assert_focus_within(app.get("run_journal_overlay") as Control, "AIF-003 open-overlay resize/settings change")
	app.call("close_run_journal")
	await _settle_frames(2)
	app.call("close_run_menu")
	await _settle_frames(2)


func _assert_live_tutorial_menu_action(app: Control, settings: UserSettings) -> void:
	var run: Variant = app.get("run_state")
	if not run is Object:
		failures.append("AIF-002: tutorial-action fixture lost its production run state.")
		return
	var challenge: Dictionary = (run as Object).get("challenge_config")
	challenge["tutorial"] = true
	(run as Object).set("challenge_config", challenge)
	settings.play_on_small_screen = true
	settings.text_size = "large"
	settings.ui_scale = 1.30
	app.call("_apply_accessibility_settings")
	await _set_live_viewport(app, Vector2(640, 360))
	app.call("open_run_menu")
	await _settle_frames(3)
	var skip := app.get("run_menu_skip_tutorial_button") as Button
	var scroll := app.get("run_menu_scroll") as ScrollContainer
	if skip == null or scroll == null or not _control_is_focusable(skip):
		failures.append("AIF-002: visible tutorial Skip Lessons action is not focusable at 640x360 maximum settings.")
	else:
		skip.grab_focus()
		await _settle_frames(2)
		if root.gui_get_focus_owner() != skip or not _rect_encloses_with_tolerance(scroll.get_global_rect(), skip.get_global_rect(), 1.5):
			failures.append("AIF-002: tutorial Skip Lessons action did not scroll fully into view at 640x360 maximum settings.")
	app.call("close_run_menu")
	await _settle_frames(2)


func _set_live_viewport(app: Control, viewport_size: Vector2) -> void:
	var requested := Vector2i(int(round(viewport_size.x)), int(round(viewport_size.y)))
	# The project normally stretches its 1280x720 canvas into the physical window.
	# Set both dimensions so this headless regression exercises the production tree
	# at the logical safe-window size instead of merely scaling a 1280x720 snapshot.
	root.content_scale_size = requested
	root.size = requested
	await _settle_frames(5)
	if app.size.distance_to(viewport_size) > 1.0:
		failures.append("Accessibility fixture requested %s but the live root remained %s." % [str(viewport_size), str(app.size)])


func _live_viewport_rect(app: Control, requested_size: Vector2) -> Rect2:
	var app_rect := app.get_global_rect()
	if app_rect.has_area():
		return app_rect
	return Rect2(Vector2.ZERO, requested_size)


func _rect_encloses_with_tolerance(outer: Rect2, inner: Rect2, tolerance: float = 0.75) -> bool:
	return inner.position.x >= outer.position.x - tolerance \
		and inner.position.y >= outer.position.y - tolerance \
		and inner.end.x <= outer.end.x + tolerance \
		and inner.end.y <= outer.end.y + tolerance


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _noop() -> void:
	pass


func _send_key(keycode: Key, shift_pressed: bool = false) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.shift_pressed = shift_pressed
	pressed.pressed = true
	root.push_input(pressed)
	var released := InputEventKey.new()
	released.keycode = keycode
	released.shift_pressed = shift_pressed
	released.pressed = false
	root.push_input(released)


func _send_joy_button(button_index: int) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.button_index = button_index
	pressed.pressed = true
	root.push_input(pressed)
	var released := InputEventJoypadButton.new()
	released.button_index = button_index
	released.pressed = false
	root.push_input(released)
