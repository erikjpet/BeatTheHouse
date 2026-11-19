extends SceneTree

# Rendered native input acceptance. Launch only through the maintained guarded
# QA Job with a fresh E: profile; this script never chooses another save path.
# All launches and Leave actions below use the ordinary rendered player input.

const MainScene := preload("res://scenes/main.tscn")
const APPROVED_ROOT := "e:/codexqa/bth/"
const MAX_RETURN_FRAMES := 600

var app: Control
var menu: Control
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var screenshots: Array[String] = []
var click_attempts: Array[Dictionary] = []
var checks := 0
var evidence_dir := ""
var started_msec := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	started_msec = Time.get_ticks_msec()
	if not _guarded_rendered_environment():
		_finish()
		return
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "crt_console_navigation_fresh")
	root.add_child(app)
	await _settle(3)
	_check(not bool(app.call("_has_foundation_save")), "The disposable navigation slot starts without a Continue save.")
	if not await _open_games_by_pointer():
		_finish()
		return
	menu = app.get("game_test_menu") as Control
	_check_catalog()
	_check_layout("default", false)
	await _capture("crt-default.png")
	# Replay the screenshot's double-hide teardown with the pointer definitely
	# outside the TV, then reopen before the full hover/input/Leave checks.
	await _move_pointer(Vector2(4, 4))
	await _key_tap(KEY_ESCAPE)
	_check_title_origin("Outside-pointer CRT teardown")
	if not await _open_games_by_pointer():
		_finish()
		return

	var first := _game_button("scratch_tickets")
	var second := _game_button("pull_tabs")
	var lower := _game_button("baccarat")
	_check(_focus_owner() == first, "Opening Games focuses the first retained game tile.")
	await _key_tap(KEY_TAB)
	_check(_focus_owner() == second, "Tab moves once to the next tile in reading order.")
	await _key_tap(KEY_LEFT)
	_check(_focus_owner() == first, "Left moves once to the preceding game tile.")
	await _key_tap(KEY_RIGHT)
	_check(_focus_owner() == second, "Right moves once to the following game tile.")
	await _joy_tap(JOY_BUTTON_DPAD_DOWN)
	_check(_focus_owner() == lower, "Controller Down moves one row in the four-column game grid.")
	await _joy_tap(JOY_BUTTON_DPAD_UP)
	_check(_focus_owner() == second, "Controller Up restores the preceding row in the same column.")
	await _joy_tap(JOY_BUTTON_A)
	await _settle(3)
	_check(_current_game_id() == "pull_tabs", "Controller A launches the focused production Pull Tabs game.")
	if _current_game_id() == "pull_tabs":
		await _capture("crt-pull-tabs.png")
		if not await _leave_by_pointer():
			_finish()
			return
	else:
		_finish()
		return
	_check(menu == app.get("game_test_menu"), "Leave restores the same CRT control instance.")
	_check(str(menu.get("selected_game_id")) == "pull_tabs", "Leave retains the selected game tile.")

	var generation := menu.get("generation_button") as Button
	if not await _click_control(generation, "Generation options"):
		_finish()
		return
	await _settle(3)
	_check_generation_defaults()
	await _edit_seed_by_keyboard()
	await _edit_json_by_keyboard()
	await _check_security_popup_back()
	_check_layout("advanced-default", true)
	await _capture("crt-advanced-default.png")
	var settings: Variant = app.get("user_settings")
	settings.ui_scale = 1.15
	settings.text_size = "large"
	app.call("_apply_accessibility_settings")
	await _settle(4)
	await _check_setup_reachability("large-font-setup")
	_check_layout("advanced-large", true)
	await _capture("crt-advanced-large.png")
	settings.ui_scale = 1.0
	settings.text_size = "normal"
	app.call("_apply_accessibility_settings")
	await _settle(3)
	var setup_done := menu.find_child("SetupDone", true, false) as Button
	if not await _click_control(setup_done, "Done with generation options"):
		_finish()
		return
	await _settle(3)
	_check_layout("collapsed-after-edit", false)
	await _check_reduced_motion()
	if not await _check_resized_layouts():
		_finish()
		return

	var last := _game_button("coin_pusher")
	if not await _click_control(last, "Last game tile", Vector2(0.94, 0.5)):
		_finish()
		return
	await _settle(3)
	_check(_current_game_id() == "coin_pusher", "Pointer selection opens the production Quarter Falls environment.")
	if _current_game_id() != "coin_pusher":
		_finish()
		return
	await _capture("crt-quarter-falls.png")
	if not await _leave_by_pointer():
		_finish()
		return
	_check(str(menu.get("selected_game_id")) == "coin_pusher", "Quarter Falls Leave retains the last selected game.")
	var seed := app.get("game_test_seed_input") as LineEdit
	_check(seed.text == "CRT-QA-42", "Repeated game and Leave loops retain the edited generation seed.")
	_check((app.get("game_test_generation_overrides_text") as TextEdit).text == "{}", "Repeated loops retain the edited JSON input.")

	await _key_tap(KEY_ESCAPE)
	_check_title_origin("Keyboard Escape")
	if not await _open_games_by_pointer():
		_finish()
		return
	_check(menu == app.get("game_test_menu") and str(menu.get("selected_game_id")) == "coin_pusher", "Reopening Games retains the selector and selection.")
	await _joy_tap(JOY_BUTTON_B)
	_check_title_origin("Controller B")
	if not await _open_games_by_pointer():
		_finish()
		return
	var exit_button := menu.get("exit_button") as Button
	_check(exit_button != null and exit_button.is_visible_in_tree(), "The CRT Exit TV touch target is visible.")
	if exit_button != null:
		await _touch_tap(_hit_point(exit_button, Vector2(0.1, 0.5)))
	_check_title_origin("Touch Exit TV")
	await _capture("crt-title-restored.png")
	_finish()


func _guarded_rendered_environment() -> bool:
	if DisplayServer.get_name() == "headless":
		_check(false, "Rendered navigation requires a native display, without --headless.")
		return false
	for env_name in ["BTH_QA_WORKSPACE", "BTH_QA_RUN_DIR", "BTH_QA_PROFILE_DIR", "BTH_SAVE_DIR", "BTH_USER_SETTINGS_PATH", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_QA_EVIDENCE_DIR"]:
		if not _approved_path(OS.get_environment(env_name)):
			_check(false, "Missing or non-approved guarded QA path: %s." % env_name)
			return false
	if not _approved_path(ProjectSettings.globalize_path("res://")) or not _approved_path(OS.get_user_data_dir()):
		_check(false, "Both the QA checkout and engine user data must stay under the approved E: root.")
		return false
	evidence_dir = OS.get_environment("BTH_QA_EVIDENCE_DIR").replace("\\", "/").simplify_path()
	if not DirAccess.dir_exists_absolute(evidence_dir):
		_check(false, "The storage guard must prepare the evidence directory before launch.")
		return false
	return true


func _approved_path(value: String) -> bool:
	return value.replace("\\", "/").simplify_path().to_lower().begins_with(APPROVED_ROOT)


func _check_catalog() -> void:
	var library: ContentLibrary = app.get("library")
	var ids: Array = app.call("_implemented_game_ids")
	_check(ids.size() == 11, "The canonical registry exposes all eleven playable games.")
	var titles := menu.find_children("GameTitle", "Label", true, false)
	_check(titles.size() == 1 and (titles[0] as Label).text == "Beat the House", "The CRT game title is Beat the House.")
	var count := 0
	for id_value in ids:
		var game_id := str(id_value)
		var button := _game_button(game_id)
		var definition: Dictionary = library.game(game_id)
		_check(button != null, "A selectable tile exists for canonical game %s." % game_id)
		if button == null:
			continue
		count += 1
		_check(button.text == str(definition.get("display_name", "")), "The %s tile uses its canonical display name." % game_id)
		_check(button.icon != null and str(button.get_meta("game_icon_asset_path", "")) == str(definition.get("asset_path", "")), "The %s tile uses its existing canonical icon." % game_id)
		var name_label := button.find_child("NameLabel", true, false) as Label
		_check(name_label != null and name_label.is_visible_in_tree() and name_label.text == str(definition.get("display_name", "")) and name_label.get_theme_color("font_color").a > 0.5, "The %s tile visibly renders its complete canonical name." % game_id)
		_check(not button.disabled and button.size.y >= 40.0, "The %s tile is enabled with a usable display-space target." % game_id)
	_check(count == 11, "Exactly eleven canonical icon/name tiles are selectable.")


func _check_layout(case_name: String, advanced: bool) -> void:
	var viewport_rect := root.get_visible_rect()
	var display: SubViewport = menu.call("get_display_viewport")
	var display_rect := Rect2(Vector2.ZERO, Vector2(display.size))
	var texture := menu.find_child("CrtDisplayTexture", true, false) as TextureRect
	var row := {"case": case_name, "viewport": _rect_data(viewport_rect), "window_pixels": _point_data(Vector2(root.size)), "display": _rect_data(display_rect), "font_scale": app.call("_accessibility_font_scale"), "controls": {}}
	_check(display.size == Vector2i(768, 576), "%s: the actual menu is rendered into a 4:3 display." % case_name)
	_check(texture != null and texture.is_visible_in_tree(), "%s: the curved CRT display texture is visible." % case_name)
	if texture != null:
		var rect := texture.get_global_rect()
		row["texture"] = _rect_data(rect)
		_check(rect.has_area() and viewport_rect.grow(1.0).encloses(rect), "%s: the complete CRT glass fits the native viewport." % case_name)
		_check(absf(rect.size.x / maxf(1.0, rect.size.y) - 4.0 / 3.0) < 0.01, "%s: the fitted glass preserves the 4:3 image aspect." % case_name)
	var bezel := menu.find_child("TelevisionBezel", true, false) as Control
	_check(bezel != null and bezel.is_visible_in_tree() and viewport_rect.grow(1.0).encloses(bezel.get_global_rect()), "%s: the full television bezel is visible." % case_name)
	var controls: Dictionary = {"title": menu.find_child("GameTitle", true, false), "seed": app.get("game_test_seed_input"), "generation": menu.get("generation_button"), "exit": menu.get("exit_button")}
	if advanced:
		controls.merge({"generation_panel": menu.find_child("GenerationInputs", true, false), "setup_scroll": menu.find_child("SetupScroll", true, false)})
	for key in controls:
		var control := controls[key] as Control
		_check(control != null and control.is_visible_in_tree(), "%s: %s is visible." % [case_name, key])
		if control == null:
			continue
		var rect: Rect2 = menu.call("display_control_rect", control)
		row["controls"][key] = _rect_data(rect)
		_check(rect.has_area() and display_rect.grow(1.0).encloses(rect), "%s: %s stays inside the composited menu." % [case_name, key])
		if control.focus_mode != Control.FOCUS_NONE:
			_check_mapped_target(control, case_name + ": " + str(key))
	if advanced:
		# Scrolled content need not be visible simultaneously. Keep its current
		# clipped bounds as evidence; reachability is proved separately by reveal,
		# actual mapped pointer focus and keyboard editing in each field.
		var setup_controls: Dictionary = {"bankroll": app.get("game_test_bankroll_input"), "stake_min": app.get("game_test_stake_floor_input"), "stake_max": app.get("game_test_stake_ceiling_input"), "security": app.get("game_test_security_option"), "overrides": app.get("game_test_generation_overrides_text"), "setup_done": menu.find_child("SetupDone", true, false)}
		row["setup_content"] = {}
		for key in setup_controls:
			var control := setup_controls[key] as Control
			_check(control != null and control.is_visible_in_tree(), "%s: %s is mounted in the open Setup content." % [case_name, key])
			if control != null:
				var rect: Rect2 = menu.call("display_control_rect", control)
				row["setup_content"][key] = {"content_rect": _rect_data(rect), "currently_clipped_rect": _rect_data(rect.intersection(_visible_display_clip(control)))}
	if not advanced:
		for id_value in app.call("_implemented_game_ids"):
			var button := _game_button(str(id_value))
			if button == null:
				continue
			var rect: Rect2 = menu.call("display_control_rect", button)
			_check(display_rect.encloses(rect), "%s: %s is entirely visible without scrolling." % [case_name, str(id_value)])
			var name_label := button.find_child("NameLabel", true, false) as Label
			if name_label != null:
				var name_rect: Rect2 = menu.call("display_control_rect", name_label)
				_check(rect.grow(1.0).encloses(name_rect), "%s: %s name remains inside its tile after font scaling." % [case_name, str(id_value)])
			_check_mapped_target(button, case_name + ": " + str(id_value))
	cases.append(row)


func _check_mapped_target(control: Control, label: String) -> void:
	var rect: Rect2 = menu.call("display_control_rect", control)
	for normalized in [Vector2(0.08, 0.5), Vector2(0.5, 0.5), Vector2(0.92, 0.5)]:
		var expected: Vector2 = rect.position + rect.size * normalized
		var screen_point: Vector2 = menu.call("display_hit_point", control, normalized)
		var remapped: Vector2 = menu.call("global_to_display", screen_point)
		_check(root.get_visible_rect().has_point(screen_point), "%s: its warped edge/center point remains on screen." % label)
		_check(expected.distance_to(remapped) <= 1.0 and rect.has_point(remapped), "%s: rendering and pointer remap agree within one display pixel at edges and center." % label)


func _check_reduced_motion() -> void:
	var settings: Variant = app.get("user_settings")
	var previous: bool = bool(settings.reduce_motion)
	settings.reduce_motion = true
	app.call("_apply_accessibility_settings")
	await _rendered_frames(4)
	var material: ShaderMaterial = menu.call("get_shader_material")
	_check(material != null and bool(material.get_shader_parameter("reduce_motion")), "Reduce Motion reaches the CRT shader.")
	var first := root.get_texture().get_image()
	await _rendered_frames(24)
	var second := root.get_texture().get_image()
	_check(first != null and second != null and first.get_data() == second.get_data(), "Reduce Motion leaves the focused CRT image static across idle rendered frames.")
	await _capture("crt-reduced-motion.png")
	settings.reduce_motion = false
	app.call("_apply_accessibility_settings")
	await _rendered_frames(4)
	_check(material != null and not bool(material.get_shader_parameter("reduce_motion")), "The existing motion setting can re-enable subtle CRT motion.")
	var moving_baseline := root.get_texture().get_image()
	var image_changed := false
	# Analog bursts are deliberately intermittent. Observe a bounded idle window
	# without pointer/keyboard events rather than requiring every frame to move.
	for _sample in range(8):
		await _rendered_frames(30)
		var moving_frame := root.get_texture().get_image()
		if moving_baseline != null and moving_frame != null and moving_baseline.get_data() != moving_frame.get_data():
			image_changed = true
			break
	_check(image_changed, "Enabled CRT motion changes the rendered image without pointer input.")
	settings.reduce_motion = previous
	app.call("_apply_accessibility_settings")
	await _rendered_frames(3)


func _check_resized_layouts() -> bool:
	# Windows retains the authored logical viewport when its OS window resizes.
	# Qualify mobile dimensions on the actual supported Web/mobile policy;
	# Windows pixel coordinates are not those logical input coordinates.
	if not bool(app.call("_mobile_viewport_platform_supported")):
		cases.append({"case": "mobile-size-policy", "status": "requires_actual_web_or_mobile_runtime", "native_logical_viewport": _rect_data(root.get_visible_rect())})
		return true
	var passed := true
	for pixels in [Vector2i(844, 390), Vector2i(390, 844)]:
		root.size = pixels
		await _rendered_frames(6)
		var label := "native-window-%dx%d" % [pixels.x, pixels.y]
		_check_layout(label, false)
		await _capture("crt-%s.png" % label)
		var generation := menu.get("generation_button") as Button
		if await _click_control(generation, label + " Setup edge", Vector2(0.1, 0.5)):
			await _rendered_frames(3)
			await _check_setup_reachability(label)
			_check_layout(label + "-setup", true)
			await _edit_seed_by_keyboard()
			await _capture("crt-%s-setup.png" % label)
			await _key_tap(KEY_ESCAPE)
			_check(not bool(menu.call("is_generation_open")) and str(app.get("current_screen")) == "CRT", "%s: Back closes Setup while retaining the selector." % label)
		var touch_game := _game_button("scratch_tickets")
		await _touch_tap(_hit_point(touch_game, Vector2(0.08, 0.5)))
		await _rendered_frames(3)
		_check(_current_game_id() == "scratch_tickets", "%s: an actual touch near a curved tile edge launches its exact game." % label)
		if _current_game_id() != "scratch_tickets":
			passed = false
			break
		if not await _leave_by_pointer():
			passed = false
			break
	root.size = Vector2i(1280, 720)
	await _rendered_frames(6)
	_check_layout("native-restored-desktop", false)
	return passed


func _check_generation_defaults() -> void:
	_check(bool((menu.find_child("GenerationInputs", true, false) as Control).visible), "Generation options expand through the real button.")
	_check(int((app.get("game_test_bankroll_input") as SpinBox).value) == 100000, "The existing practice bankroll default is retained.")
	_check(int((app.get("game_test_stake_floor_input") as SpinBox).value) == 1, "The existing minimum stake default is retained.")
	_check(int((app.get("game_test_stake_ceiling_input") as SpinBox).value) == 200, "The existing maximum stake default is retained.")
	var security := app.get("game_test_security_option") as OptionButton
	_check(security.item_count == 3 and str(security.get_item_metadata(security.selected)) == "boss", "Low, High and Boss security options retain the Boss default.")
	_check((app.get("game_test_generation_overrides_text") as TextEdit).text == "{}", "The existing JSON override default is retained.")


func _check_setup_reachability(label: String) -> void:
	for field in ["game_test_bankroll_input", "game_test_stake_floor_input", "game_test_stake_ceiling_input"]:
		var spin := app.get(field) as SpinBox
		if spin == null:
			_check(false, "%s: %s remains available." % [label, field])
			continue
		var editor := spin.get_line_edit()
		var retained_value := int(spin.value)
		if not await _click_control(editor, label + ": " + field):
			continue
		_check(_focus_owner() == editor, "%s: %s accepts real mapped keyboard focus after scrolling." % [label, field])
		await _key_tap(KEY_A, 0, true)
		await _type_text(str(retained_value))
		await _key_tap(KEY_ENTER)
		_check(int(spin.value) == retained_value and str(app.get("current_screen")) == "CRT", "%s: %s supports keyboard editing without losing its value or CRT context." % [label, field])
	await _edit_json_by_keyboard()
	await _capture("crt-%s-json-visible.png" % label)
	await _check_security_popup_back()
	var done := menu.find_child("SetupDone", true, false) as Button
	if done != null and await _reveal_setup_control(done, label + ": Setup Done"):
		await _move_pointer(_hit_point(done))
		var hovered := done.get_viewport().gui_get_hovered_control()
		_check(hovered == done or hovered != null and done.is_ancestor_of(hovered), "%s: Done remains reachable after editing the last scrolled field." % label)


func _visible_display_clip(control: Control) -> Rect2:
	var clip := control.get_viewport().get_visible_rect()
	var ancestor := control.get_parent()
	while ancestor != null and ancestor != control.get_viewport():
		if ancestor is Control and (ancestor as Control).clip_contents:
			clip = clip.intersection((ancestor as Control).get_global_rect())
		ancestor = ancestor.get_parent()
	return clip


func _reveal_setup_control(control: Control, label: String) -> bool:
	var ancestor := control.get_parent()
	var scroll: ScrollContainer
	while ancestor != null and ancestor != control.get_viewport():
		if ancestor is ScrollContainer and str(ancestor.name) == "SetupScroll":
			scroll = ancestor as ScrollContainer
			break
		ancestor = ancestor.get_parent()
	if scroll == null:
		return true
	# Use the ScrollContainer's normal reveal seam, then independently require
	# complete clipped visibility and a mapped player pointer in _click_control.
	scroll.ensure_control_visible(control)
	await _rendered_frames(4)
	var rect := control.get_global_rect()
	var clip := _visible_display_clip(control)
	var reachable := rect.has_area() and clip.grow(1.0).encloses(rect)
	_check(reachable, "%s becomes fully visible within the real Setup scroll viewport." % label)
	cases.append({"case": "setup-field-reachability", "control": label, "scroll_vertical": scroll.scroll_vertical, "content_rect": _rect_data(rect), "visible_clip": _rect_data(clip), "fully_visible": reachable})
	return reachable


func _check_security_popup_back() -> void:
	var security := app.get("game_test_security_option") as OptionButton
	if not await _click_control(security, "Security generation choices"):
		return
	await _rendered_frames(2)
	_check(security.get_popup().visible, "The real security selector opens its embedded popup.")
	await _key_tap(KEY_ESCAPE)
	_check(not security.get_popup().visible and bool(menu.call("is_generation_open")) and str(app.get("current_screen")) == "CRT", "Back closes the security popup before Setup or CRT ownership.")
	_check((app.get("game_test_seed_input") as LineEdit).text == "CRT-QA-42", "Popup cancellation retains the edited seed.")


func _edit_seed_by_keyboard() -> void:
	var seed := app.get("game_test_seed_input") as LineEdit
	await _click_control(seed, "Seed input")
	await _key_tap(KEY_END)
	var end_column := seed.caret_column
	await _key_tap(KEY_LEFT)
	_check(seed.caret_column == end_column - 1 and _focus_owner() == seed, "Left edits the seed caret without navigating away.")
	await _key_tap(KEY_RIGHT)
	_check(seed.caret_column == end_column and _focus_owner() == seed, "Right edits the seed caret without navigating away.")
	await _key_tap(KEY_A, 0, true)
	await _type_text("CRT-QA-42")
	_check(seed.text == "CRT-QA-42" and str(app.get("current_screen")) == "CRT", "Native text input replaces the seed while the selector stays open.")


func _edit_json_by_keyboard() -> void:
	var overrides := app.get("game_test_generation_overrides_text") as TextEdit
	await _click_control(overrides, "JSON override input")
	await _key_tap(KEY_END)
	var end_column := overrides.get_caret_column()
	await _key_tap(KEY_LEFT)
	_check(overrides.get_caret_column() == end_column - 1 and _focus_owner() == overrides, "Left edits the JSON caret without modal focus traversal.")
	await _key_tap(KEY_RIGHT)
	_check(overrides.get_caret_column() == end_column and _focus_owner() == overrides, "Right edits the JSON caret without modal focus traversal.")
	await _key_tap(KEY_A, 0, true)
	await _type_text("{}")
	_check(overrides.text == "{}" and _focus_owner() == overrides, "Native text input replaces the JSON override without leaving its editor.")


func _leave_by_pointer() -> bool:
	var surface := app.get("game_surface_canvas") as Control
	if surface == null:
		_check(false, "The real game surface exists for Leave.")
		return false
	var leave_rect: Rect2 = surface.call("global_rect_for_surface_action", "surface_back", -1)
	_check(leave_rect.has_area(), "The actual rendered game exposes its normal Leave hit target.")
	if not leave_rect.has_area():
		return false
	await _move_pointer(leave_rect.get_center())
	await _mouse_tap(leave_rect.get_center())
	for _frame in range(MAX_RETURN_FRAMES):
		if str(app.get("current_screen")) == "CRT" and menu.is_visible_in_tree() and app.get("current_game") == null:
			_check(true, "Normal rendered Leave returns to the CRT selector.")
			await _settle(2)
			return true
		await process_frame
	_check(false, "Normal rendered Leave did not return to the CRT within the bounded settle window.")
	return false


func _open_games_by_pointer() -> bool:
	var button := app.get("game_library_button") as Button
	if not await _click_control(button, "Title Games"):
		return false
	await _settle(3)
	var current_menu := app.get("game_test_menu") as Control
	var opened := current_menu != null and current_menu.is_visible_in_tree() and str(app.get("current_screen")) == "CRT"
	_check(opened, "Pointer Games opens the dedicated CRT environment.")
	return opened


func _check_title_origin(route: String) -> void:
	_check(str(app.get("current_screen")) == "START" and app.get("run_state") == null and not bool(app.call("_crt_practice_active")), "%s restores the title origin and clears practice ownership." % route)
	_check((app.get("start_screen") as Control).is_visible_in_tree() and not menu.is_visible_in_tree(), "%s restores visible title controls." % route)


func _game_button(game_id: String) -> Button:
	return menu.find_child("Launch_%s" % game_id, true, false) as Button


func _focus_owner() -> Control:
	if menu != null and menu.is_visible_in_tree() and menu.has_method("get_display_focus_owner"):
		return menu.call("get_display_focus_owner")
	return root.gui_get_focus_owner()


func _current_game_id() -> String:
	var game: GameModule = app.get("current_game")
	return game.get_id() if game != null and str(app.get("current_screen")) == "GAME" else ""


func _click_control(control: Control, label: String, normalized: Vector2 = Vector2(0.5, 0.5)) -> bool:
	if control == null or not control.is_visible_in_tree() or not control.get_global_rect().has_area():
		_check(false, "%s has a visible pointer target." % label)
		return false
	if not await _reveal_setup_control(control, label):
		return false
	var attempts: Array[Dictionary] = []
	# Font changes queue container reflow and GUI picking independently. Observe
	# rendered geometry before moving, then require the same target after two
	# rendered frames; never click a cached center through a different control.
	for attempt in range(3):
		await _rendered_frames(2)
		if not is_instance_valid(control) or not control.is_visible_in_tree():
			break
		var before_rect := control.get_global_rect()
		var position := _hit_point(control, normalized)
		await _move_pointer(position)
		var after_rect := control.get_global_rect()
		var hovered := control.get_viewport().gui_get_hovered_control()
		var display_point := _control_point(control, position)
		var stable := before_rect.is_equal_approx(after_rect)
		var correct_hover := hovered == control or (hovered != null and control.is_ancestor_of(hovered))
		var observation := {
			"control": label, "attempt": attempt + 1,
			"before_rect": _rect_data(before_rect), "after_rect": _rect_data(after_rect),
			"requested_position": _point_data(position), "display_position": _point_data(display_point), "root_mouse_position": _point_data(root.get_mouse_position()),
			"hovered_name": str(hovered.name) if hovered != null else "nothing",
			"hovered_path": str(hovered.get_path()) if hovered != null else "",
			"stable_rect": stable, "correct_hover": correct_hover,
		}
		attempts.append(observation)
		click_attempts.append(observation)
		if stable and correct_hover and after_rect.has_point(display_point) and _visible_display_clip(control).has_point(display_point):
			await _mouse_tap(position)
			return true
	_check(false, "%s never exposed a stable, uncovered rendered center: %s." % [label, JSON.stringify(attempts)])
	return false


func _hit_point(control: Control, normalized: Vector2 = Vector2(0.5, 0.5)) -> Vector2:
	var current_menu := app.get("game_test_menu") as Control
	if current_menu != null and current_menu.has_method("get_display_viewport") and control.get_viewport() == current_menu.call("get_display_viewport"):
		return current_menu.call("display_hit_point", control, normalized)
	return control.get_global_rect().position + control.get_global_rect().size * normalized


func _control_point(control: Control, global_point: Vector2) -> Vector2:
	var current_menu := app.get("game_test_menu") as Control
	if current_menu != null and current_menu.has_method("get_display_viewport") and control.get_viewport() == current_menu.call("get_display_viewport"):
		return current_menu.call("global_to_display", global_point)
	return global_point


func _move_pointer(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	motion.relative = position - root.get_mouse_position()
	Input.parse_input_event(motion)
	await _rendered_frames(2)


func _rendered_frames(count: int) -> void:
	for _frame in range(maxi(1, count)):
		await process_frame
		await RenderingServer.frame_post_draw


func _mouse_tap(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = position
	event.global_position = position
	event.pressed = true
	Input.parse_input_event(event)
	await _settle(2)
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	Input.parse_input_event(event)
	await _settle(2)


func _key_tap(key: Key, unicode_value: int = 0, control: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.unicode = unicode_value
	event.ctrl_pressed = control
	event.pressed = true
	Input.parse_input_event(event)
	await _settle(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _settle(2)


func _type_text(value: String) -> void:
	for index in range(value.length()):
		await _key_tap(KEY_NONE, value.unicode_at(index))


func _joy_tap(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await _settle(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _settle(2)


func _touch_tap(position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = true
	Input.parse_input_event(event)
	await _settle(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _settle(3)


func _capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	if capture == null or capture.is_empty():
		_check(false, "A rendered viewport image exists for %s." % filename)
		return
	var path := evidence_dir.path_join(filename)
	var error := capture.save_png(path)
	_check(error == OK and capture.get_size() == root.size, "Rendered screenshot %s saves at the requested native window size." % filename)
	if error == OK:
		screenshots.append(path)


func _rect_data(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}


func _point_data(point: Vector2) -> Dictionary:
	return {"x": point.x, "y": point.y}


func _settle(frames: int) -> void:
	for _frame in range(maxi(1, frames)):
		await process_frame


func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		if not failures.has(message):
			failures.append(message)
		push_error(message)


func _finish() -> void:
	print("CRT_CONSOLE_NAVIGATION %s" % JSON.stringify({
		"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"cases": cases, "screenshots": screenshots, "click_attempts": click_attempts,
		"elapsed_msec": Time.get_ticks_msec() - started_msec,
		"fidelity": "Rendered native fresh QA state, real pointer/keyboard/controller/screen-touch input through Input.parse_input_event, production game launch and rendered Leave. No player profile or browser claim.",
	}))
	quit(0 if failures.is_empty() else 1)
