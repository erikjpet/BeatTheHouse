extends "res://scripts/tests/mobile_coach_dialogue_input_owner_check.gd"

# Reuses the unchanged real-Main/ScreenTouch helpers. Native platform/window
# substitution is explicit; Web framebuffer attachment is qualified separately.

func _run() -> void:
	var mode := OS.get_environment("BTH31_BOUNDARY_CASE")
	var private_root := OS.get_environment("BTH31_PRIVATE_ROOT")
	if not ["375", "390", "rotate", "desktop"].has(mode) or private_root.is_empty() \
			or not ProjectSettings.globalize_path("user://").begins_with(private_root + "/"):
		quit(2)
		return
	root.size = Vector2i(375, 667) if mode == "375" else Vector2i(1280, 720) if mode == "desktop" else Vector2i(390, 844)
	Input.use_accumulated_input = false
	observer = WholeApp.Observer.new()
	root.add_child(observer)
	var settings: UserSettings = WholeApp.PhoneSettings.new()
	settings.ui_scale = 1.3
	settings.text_size = "large"
	settings.play_on_small_screen = true
	_check(settings.save() == OK, "fresh key-local maximum accessibility preferences saved")
	app = MainScene.instantiate()
	app.set_script(WholeApp.App)
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	await _settle(16)
	_check(app._ensure_run_ui_built(), "actual run UI builds")
	app._ensure_full_content_library_loaded()
	await _settle(12)
	if not await _tap(app.new_run_button, "ordinary_max_font_Play"):
		_finish(mode)
		return
	await _settle(20)
	var run: RunState = app.run_state
	if not _check(run != null and run.is_tutorial_run(), "ordinary Play creates authored guided run"):
		_finish(mode)
		return
	var protected_before := _protected(run)
	var lesson: String = app.coach_overlay.active_lesson_id()
	var seen_before := var_to_bytes(app.coach_overlay.seen)
	await _tap(app.talk_dock.collapse_button, "initial_Pal_Close")
	_check(not app.talk_dock.visible and app.coach_overlay.panel.is_visible_in_tree(), "one touch closes Pal while retaining unfinished coach")
	await _settings_bounds(mode)
	_check(app.coach_overlay.panel.is_visible_in_tree() and app.coach_overlay.active_lesson_id() == lesson,
		"Settings Back restores the same unfinished coach")
	await _tap(app.top_inventory_button, "maximum_font_Inventory")
	_check(app._run_inventory_popup_is_visible() and not app.coach_overlay.panel.is_visible_in_tree(), "Inventory owns its full detail surface without coach interference")
	await _tap(app.run_inventory_screen._close_button, "maximum_font_Inventory_Close")
	_check(not app._run_inventory_popup_is_visible() and app.coach_overlay.panel.is_visible_in_tree(), "Inventory Close restores coach without Skip tip")
	var flags := -1
	for connection in root.size_changed.get_connections():
		if connection.callable == Callable(app, "_apply_mobile_viewport_policy"):
			flags = int(connection.flags)
	_check(flags >= 0 and (flags & CONNECT_DEFERRED) != 0, "root resize policy is deferred outside the engine viewport-update stack")
	if mode == "rotate":
		for requested in [Vector2i(375, 667), Vector2i(844, 390), Vector2i(390, 844), Vector2i(1280, 720), Vector2i(375, 667), Vector2i(390, 844)]:
			var old_scale := root.content_scale_size
			root.size = requested
			_check(root.content_scale_size == old_scale, "physical resize never re-enters logical sizing inline " + str(requested))
			await _settle(16)
			var expected: Vector2i = WholeApp.Policy.target_size(requested, true)
			_check(root.content_scale_size == expected, "deferred policy binds latest physical size " + str(requested))
			_check(app.get_global_rect().is_equal_approx(root.get_visible_rect()), "actual Main root covers settled viewport " + str(requested))
			_check(not app.mobile_viewport_policy_applying, "resize guard releases after settled application")
			await _settings_bounds("rotation_" + str(requested), false)
			facts[str(requested)] = {"window": root.size, "logical": root.content_scale_size,
				"viewport": root.get_visible_rect(), "Main": app.get_global_rect(), "input_transform": root.get_final_transform()}
	_check(app.coach_overlay.active_lesson_id() == lesson and var_to_bytes(app.coach_overlay.seen) == seen_before,
		"modal and rotation lifecycle neither complete nor skip authored lesson")
	_check(_protected(run) == protected_before, "all observed settings/modal/rotation actions preserve finance, inventory, paid games, debt, history and RNG")
	_finish(mode)


func _settings_bounds(label: String, scan_controls: bool = true) -> void:
	var settings_before := var_to_bytes(app.user_settings.to_dict())
	await _tap(app.top_settings_button, label + "_Settings")
	_check(app.settings_overlay.visible and app.settings_menu.is_visible_in_tree(), label + " actual Settings opens")
	_check(not app.coach_overlay.panel.is_visible_in_tree(), label + " Settings suppresses the card as well as highlight")
	var menu: SettingsMenu = app.settings_menu
	await _settle(12)
	var bounds := root.get_visible_rect()
	_check(bounds.encloses(app.settings_panel.get_global_rect()), label + " full Settings panel fits root at maximum text and UI scale")
	_check(bounds.encloses(menu.get_global_rect()), label + " full Settings menu fits root")
	var narrow: bool = bounds.size.x < 560.0
	_check(menu.action_row.vertical == narrow, label + " footer orientation follows viewport without hiding actions")
	for row in menu.responsive_rows:
		_check(row.vertical == narrow, label + " value row orientation follows viewport")
	for button in [menu.back_button, menu.defaults_button, menu.apply_button]:
		_check(button.is_visible_in_tree() and not button.disabled and bounds.encloses(button.get_global_rect()), label + " footer " + button.text + " is entirely visible and enabled")
	for control in menu.focus_controls:
		if not scan_controls or not menu.body_scroll.is_ancestor_of(control) or not control.is_visible_in_tree():
			continue
		var before_rect: Rect2 = control.get_global_rect()
		var before_scroll := menu.body_scroll.scroll_vertical
		menu.body_scroll.ensure_control_visible(control)
		await _settle(4)
		var scrollbar: VScrollBar = menu.body_scroll.get_v_scroll_bar()
		var actual_rect: Rect2 = control.get_global_rect()
		var scroll_rect: Rect2 = menu.body_scroll.get_global_rect()
		var capture: Dictionary = {"name": str(control.name), "type": control.get_class(),
			"text": str(control.text) if control is Button else "", "before_rect": before_rect,
			"after_rect": control.get_global_rect(), "scroll_rect": menu.body_scroll.get_global_rect(),
			"actual_rect_values": [actual_rect.position.x, actual_rect.position.y, actual_rect.size.x, actual_rect.size.y],
			"scroll_rect_values": [scroll_rect.position.x, scroll_rect.position.y, scroll_rect.size.x, scroll_rect.size.y],
			"before_scroll": before_scroll, "after_scroll": menu.body_scroll.scroll_vertical,
			"scroll_min": scrollbar.min_value, "scroll_max": scrollbar.max_value, "scroll_page": scrollbar.page,
			"custom_minimum": control.custom_minimum_size, "combined_minimum": control.get_combined_minimum_size(),
			"viewport": bounds, "visible_size": control.size}
		if not facts.has("scroll_controls"):
			facts["scroll_controls"] = []
		facts["scroll_controls"].append(capture)
		_check(bounds.encloses(control.get_global_rect()) and menu.body_scroll.get_global_rect().encloses(control.get_global_rect()),
			label + " scroll makes complete setting control reachable: " + control.name)
	facts[label] = {"viewport": bounds, "panel": app.settings_panel.get_global_rect(),
		"menu": menu.get_global_rect(), "footer": menu.action_row.get_global_rect(),
		"body": menu.body_scroll.get_global_rect(), "body_min": menu.body_scroll.get_combined_minimum_size()}
	await _tap(menu.back_button, label + "_Back")
	_check(not app.settings_overlay.visible, label + " one real touch Back closes Settings")
	_check(var_to_bytes(app.user_settings.to_dict()) == settings_before, label + " neutral Back preserves preferences/draft semantics")


func _finish(mode: String) -> void:
	var result := {"task_id": "BTH-31", "finding": "Settings maximum-text bounds/modal ownership and resize ordering",
		"case": mode, "checks": checks, "failures": failures, "facts": facts,
		"scope": "Actual authored Main and connected native ScreenTouch; phone platform/window fixture as previously documented. No copied key/profile or paid action. Actual Web framebuffer consistency remains a separate required check."}
	var out := FileAccess.open(OS.get_environment("BTH_TARGET_OUTPUT"), FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(result, "\t", false, true))
	print("BTH31_SETTINGS_ROTATION ", JSON.stringify(result, "", false, true))
	if is_instance_valid(app):
		root.remove_child(app)
		app.free()
	quit(0 if failures.is_empty() else 1)
