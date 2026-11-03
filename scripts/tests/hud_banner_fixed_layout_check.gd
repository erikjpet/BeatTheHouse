extends SceneTree

# Render the production run shell with synthetic presentation models. No run is
# started, no profile/save is read, and package callbacks never touch gameplay.
class ShellOnly:
	extends "res://scripts/ui/foundation_main.gd"
	var package_model: Dictionary = {"actions": [], "timing_text": ""}
	var selected_package_action := ""
	var synthetic_meta := false

	func _ready() -> void:
		set_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)

	func _delivery_action_model() -> Dictionary:
		return package_model.duplicate(true)

	func _activate_delivery_physical_action(verb: String) -> bool:
		selected_package_action = verb
		return true

	func _is_meta_session() -> bool:
		return synthetic_meta


const Settings := preload("res://scripts/core/user_settings.gd")
const UIArt := preload("res://scripts/ui/ui_art.gd")
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_locked_web_profile()
	# Physical portrait/landscape use this same fixed logical viewport. The
	# larger direct viewport also checks that content cannot change the band.
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for large_text in [false, true]:
			await _exercise(viewport_size, large_text)
	var report := {"passed": failures.is_empty(), "checks": checks, "fidelity": "rendered production shell; synthetic scalar HUD and package models; no game/save actions", "cases": cases, "failures": failures}
	var report_path := OS.get_environment("BTH_HUD_LAYOUT_REPORT")
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t") + "\n")
	print("HUD_BANNER_FIXED_LAYOUT " + ("PASS" if failures.is_empty() else "FAIL") + " checks=%d" % checks)
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check_locked_web_profile() -> void:
	# Native Godot includes classes deliberately removed from the shipped Web
	# engine; native parsing alone cannot establish this export compatibility.
	var profile: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://native/coin_pusher/godot_web_release_build_profile.json"))
	_check(profile is Dictionary, "locked Web build profile must load")
	if not profile is Dictionary:
		return
	var source := FileAccess.get_file_as_string("res://scripts/ui/foundation_hud_bar.gd")
	for class_name_value in profile.get("disabled_classes", []):
		var class_id := str(class_name_value)
		var forbidden := RegEx.new()
		forbidden.compile("\\b%s\\s*\\.\\s*new\\s*\\(|:\\s*%s\\b|\\b(?:as|is)\\s+%s\\b" % [class_id, class_id, class_id])
		_check(forbidden.search(source) == null, "HUD must not require disabled Web class " + class_id)


func _exercise(viewport_size: Vector2i, large_text: bool) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.disable_3d = true
	root.add_child(viewport)
	var app := ShellOnly.new()
	app.size = Vector2(viewport_size)
	app.user_settings = Settings.new()
	if large_text:
		app.user_settings.ui_scale = 1.18
		app.user_settings.text_size = "large"
		app.user_settings.play_on_small_screen = true
	viewport.add_child(app)
	_check(app._ensure_run_ui_stage_scripts(0), "production shell scripts must load")
	_check(app._ensure_run_ui_stage_scripts(4), "shared popup controller must load")
	app.run_screen = Control.new()
	app.run_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	app.add_child(app.run_screen)
	app._build_run_screen()
	app._build_event_choice_popup_overlay()
	app.structured_hud.set_compact_mode(app._compact_run_hud_enabled())
	app._apply_accessibility_to_node(app, app._accessibility_font_scale(), app._accessibility_control_scale())
	var hud = app.structured_hud
	var prefix := "%dx%d %s" % [viewport_size.x, viewport_size.y, "large/touch" if large_text else "default"]
	var model := {"bankroll": 80, "chips": 0, "show_chips": false, "heat_level": 0, "drunk_level": 0, "clock_day": 1, "clock_minute_of_day": 540, "clock_exact_display": "9:00 AM", "clock_tooltip": "Ordinary clocks show the latest 15-minute mark. Pocket Watch shows exact minutes.", "status_icons": []}
	hud.render(model)
	await _settle_layout(app)
	var normal := _geometry(app, prefix + " normal", large_text)
	var normal_play := app.visual_panel_container.get_global_rect()

	var statuses: Array[Dictionary] = []
	for index in range(12):
		statuses.append({"id": "status_%d" % index, "icon": "debt", "label": "Status %d" % index, "tooltip": "STATUS_SENTINEL_%d: " % index + "A long conditional status explanation remains available in full. ".repeat(5)})
	model.merge({"bankroll": 2147483647, "chips": 2147483647, "show_chips": true, "heat_level": 99, "drunk_level": 99, "pending_drunk_absorption": 99, "clock_day": 2147483647, "clock_minute_of_day": 1439, "clock_exact_display": "11:59 PM", "status_icons": statuses}, true)
	hud.render(model)
	hud.present_heat_gain(99)
	hud.present_money_feedback([{"currency": "cash", "delta": 2147483647, "text": "+$2147483647", "tone": "success"}, {"currency": "chips", "delta": 2147483647, "text": "+2147483647 chips", "tone": "success"}])
	app.active_item_button.text = "Use: Firework ..."
	app.active_item_button.icon = UIArt.icon("alert")
	app.active_item_button.tooltip_text = "The full unusually long active-item name and its description."
	await _settle_layout(app)
	var worst := _geometry(app, prefix + " worst", large_text)
	_check(app.visual_panel_container.get_global_rect() == normal_play, prefix + ": variable values/status/feedback must preserve play area")
	_check(hud.wallet_value.text == "$2147483647" and hud.chips_value.text == "2147483647", prefix + ": exact displayed values must remain in the model")
	_check(hud.wallet_delta.text.contains("2147483647") and hud.wallet_delta_panel.modulate.a > 0.0, prefix + ": real money feedback must actually be visible")
	var balance_text_height: float = hud.wallet_value.get_theme_font("font").get_height(hud.wallet_value.get_theme_font_size("font_size"))
	_check(hud.wallet_value.size.x >= 60.0, prefix + ": balance refresh must retain its allocated column")
	_check(hud.wallet_delta_panel.get_global_rect().end.y <= hud.wallet_value.get_global_rect().end.y - balance_text_height + 1.0, prefix + ": money feedback must not cover balance: badge %s, value %s, line %s" % [str(hud.wallet_delta_panel.get_global_rect()), str(hud.wallet_value.get_global_rect()), str(balance_text_height)])
	_check(int(hud.current_snapshot().get("status_icon_count", 0)) == statuses.size(), prefix + ": all status information must be retained")

	# The real disclosure button opens its modal; exact values and every status
	# remain reachable without relying on hover tooltips on a touch screen.
	hud.time_button.grab_focus()
	hud.time_button.pressed.emit()
	await _settle()
	var details_overlay := hud.get("details_overlay") as Control
	var details_panel := hud.get("details_panel") as Control
	var details_scroll := hud.get("details_scroll") as ScrollContainer
	var details_text := hud.get("details_text") as Label
	var details_close := hud.get("details_close") as Button
	_check(details_overlay != null and details_overlay.visible, prefix + ": clock must open the details disclosure")
	_check(details_overlay.is_set_as_top_level() or not app.run_screen.is_ancestor_of(details_overlay), prefix + ": details must escape the clipped run screen")
	_check(details_overlay.z_index > 100, prefix + ": details must cover TalkDock and item-found overlays")
	_check(app._talk_dock_input_is_blocked() and app._modal_contract_blocks_player_input(), prefix + ": details must block underlying conversation and room input")
	if details_overlay != null and details_overlay.visible and details_panel != null and details_text != null and details_scroll != null and details_close != null:
		_check(details_overlay.is_set_as_top_level(), prefix + ": disclosure must escape the clipped HUD without a platform-specific layer")
		_check(details_overlay.get_global_rect() == Rect2(Vector2.ZERO, Vector2(viewport_size)), prefix + ": disclosure backdrop must cover the complete viewport")
		_check(_encloses(Rect2(Vector2.ZERO, Vector2(viewport_size)), details_panel.get_global_rect()), prefix + ": details must fit the viewport")
		_check(details_scroll.follow_focus, prefix + ": details must follow keyboard focus")
		_check(details_text.text.contains("2147483647") and details_text.text.contains("11:59 PM") and details_text.text.contains("Pocket Watch"), prefix + ": exact values and clock explanation must be available in details")
		for index in range(statuses.size()):
			_check(details_text.text.contains("STATUS_SENTINEL_%d" % index), prefix + ": all status explanations must be present")
		_check(details_text.max_lines_visible == -1, prefix + ": details must retain all lines")
		_check(details_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, prefix + ": long details must be scrollable")
		# Dispatch the real keyboard press/release through the production host as
		# well as the HUD. A tutorial highlight behind the shade can resemble a
		# focus ring; check the actual owner and the resulting Close action.
		app.set_process_input(true)
		for expected in [details_scroll, details_close, details_scroll, details_close]:
			for pressed in [true, false]:
				var tab := InputEventKey.new()
				tab.keycode = KEY_TAB
				tab.pressed = pressed
				viewport.push_input(tab, true)
			await _settle()
			_check(viewport.gui_get_focus_owner() == expected, prefix + ": Tab must cycle only within run details")
		for pressed in [true, false]:
			var accept := InputEventKey.new()
			accept.keycode = KEY_ENTER
			accept.pressed = pressed
			viewport.push_input(accept, true)
		await _settle()
		_check(not details_overlay.visible, prefix + ": keyboard activation of Close must dismiss details")
		_check(viewport.gui_get_focus_owner() == hud.time_button, prefix + ": keyboard close must restore its opener")
		app.set_process_input(false)
		hud.time_button.pressed.emit()
		await _settle()
		details_close.grab_focus()
		await _settle()
		_check(_encloses(details_scroll.get_global_rect(), details_close.get_global_rect()) or _encloses(details_panel.get_global_rect(), details_close.get_global_rect()), prefix + ": close must remain accessible")
		details_close.pressed.emit()
		await _settle()
		_check(not details_overlay.visible, prefix + ": details must close")
		_check(viewport.gui_get_focus_owner() == hud.time_button, prefix + ": closing details must restore clock focus")
		for corner in [Vector2(2, 2), Vector2(viewport_size.x - 2, 2), Vector2(2, viewport_size.y - 2), Vector2(viewport_size.x - 2, viewport_size.y - 2)]:
			hud.time_button.pressed.emit()
			await _settle()
			for pressed in [true, false]:
				var pointer := InputEventMouseButton.new()
				pointer.button_index = MOUSE_BUTTON_LEFT
				pointer.pressed = pressed
				pointer.position = corner
				viewport.push_input(pointer, true)
			await _settle()
			_check(not details_overlay.visible, prefix + ": backdrop pointer at %s must reach the disclosure instead of the room" % corner)
		hud.time_button.pressed.emit()
		viewport.size = viewport_size + Vector2i(160, 90)
		await _settle()
		_check(details_overlay.get_global_rect() == Rect2(Vector2.ZERO, Vector2(viewport.size)), prefix + ": an open disclosure must follow viewport resize")
		_check(_encloses(Rect2(Vector2.ZERO, Vector2(viewport.size)), details_panel.get_global_rect()), prefix + ": resized disclosure must remain reachable")
		viewport.size = viewport_size
		await _settle()
		hud.hide()
		await _settle()
		_check(not details_overlay.visible, prefix + ": hiding the HUD must dismiss its top-level disclosure")
		hud.show()
	await _settle_layout(app)
	_check(app.visual_panel_container.get_global_rect() == normal_play, prefix + ": opening/closing clock detail must preserve play area")

	# Package timing and any number of street actions use the shipped popup.
	var package_actions: Array[Dictionary] = []
	for index in range(6):
		package_actions.append({"id": "verb_%d" % index, "label": "Street action %d" % index, "message": "ACTION_SENTINEL_%d: " % index + "The complete street action explanation and its consequences. ".repeat(6)})
	var timing := "TIMING_SENTINEL: Jazz club appointment 11:00 PM to 11:15 PM. " + "The entire delivery schedule remains readable. ".repeat(12)
	app.package_model = {"actions": package_actions, "timing_text": timing}
	app._refresh_delivery_action_button()
	await _settle_layout(app)
	var package_geometry := _geometry(app, prefix + " package", large_text)
	_check(app.visual_panel_container.get_global_rect() == normal_play, prefix + ": package availability must preserve play area")
	app.delivery_action_button.grab_focus()
	app.delivery_action_button.pressed.emit()
	await _settle()
	app._position_event_choice_popup()
	await _settle()
	_check(app.event_choice_popup_overlay.visible, prefix + ": package button must open its actions")
	_check(_find_label(app.event_choice_popup_choices_list, timing) != null, prefix + ": full timing must remain present")
	_check(_encloses(Rect2(Vector2.ZERO, Vector2(viewport_size)), app.event_choice_popup_panel.get_global_rect()), prefix + ": package popup must fit the viewport")
	var controls: Array[Control] = app._event_choice_focus_controls()
	_check(controls.size() == package_actions.size() + 1, prefix + ": every package action plus Back must be available")
	for control in controls:
		control.grab_focus()
		app.event_choice_popup_scroll.ensure_control_visible(control)
		await _settle()
		_check(control.focus_mode == Control.FOCUS_ALL, prefix + ": package action must remain focusable")
		_check(control.size.y >= (52.0 if large_text else 40.0), prefix + ": package action must retain its touch target")
		_check(_encloses(app.event_choice_popup_scroll.get_global_rect(), control.get_global_rect()), prefix + ": focused package action must be scroll-reachable: %s in %s" % [str(control.get_global_rect()), str(app.event_choice_popup_scroll.get_global_rect())])
	for index in range(package_actions.size()):
		var text := str(package_actions[index].get("message", ""))
		var body := _find_label(app.event_choice_popup_choices_list, text)
		_check(body != null and body.max_lines_visible == -1, prefix + ": package action explanation must not truncate")
	if not controls.is_empty():
		(controls[0] as Button).pressed.emit()
		await _settle()
		_check(app.selected_package_action == "verb_0", prefix + ": disclosed button must reach its normal action callback")
		_check(not app.event_choice_popup_overlay.visible, prefix + ": package action must dismiss its stale popup")
		_check(viewport.gui_get_focus_owner() == app.delivery_action_button, prefix + ": package close must restore opener focus")
	app.package_model = {"actions": [], "timing_text": "Package missed. " + "The failure receipt remains readable. ".repeat(8)}
	app._refresh_delivery_action_button()
	await _settle_layout(app)
	_check(app.delivery_action_button.visible, prefix + ": a delivery failure receipt must stay accessible")
	_check(app.visual_panel_container.get_global_rect() == normal_play, prefix + ": delivery failure receipt must preserve play area")
	app.package_model = {"actions": [], "timing_text": ""}
	app._refresh_delivery_action_button()

	app.synthetic_meta = true
	app._apply_hud_mode_visibility()
	hud.render({"mode": "meta", "location_text": "The unusually long restored home location name", "gold_text": "2147483647g", "next_goal_text": "The complete next housing tier and its full purchase price"})
	await _settle_layout(app)
	_check(app.run_hud_panel.size.y == 72.0, prefix + ": meta content must preserve the fixed banner")
	_check(app.visual_panel_container.get_global_rect() == normal_play, prefix + ": meta content must preserve play area")
	_check(not app.top_inventory_button.visible and not app.active_item_button.visible, prefix + ": meta mode must retain existing action visibility")
	cases.append({"viewport": {"width": viewport_size.x, "height": viewport_size.y}, "large_touch": large_text, "font_scale": app._accessibility_font_scale(), "control_scale": app._accessibility_control_scale(), "normal": normal, "worst": worst, "package": package_geometry, "package_action_count": controls.size(), "full_status_count": statuses.size(), "play_rect_unchanged": app.visual_panel_container.get_global_rect() == normal_play})
	var disclosure_ref: WeakRef = weakref(details_overlay)
	viewport.queue_free()
	await _settle()
	_check(disclosure_ref.get_ref() == null, prefix + ": HUD disposal must release its top-level disclosure")


func _geometry(app: ShellOnly, label: String, large_text: bool) -> Dictionary:
	var banner := app.run_hud_panel.get_global_rect()
	var play := app.visual_panel_container.get_global_rect()
	_check(is_equal_approx(banner.size.y, 72.0), label + ": banner must remain exactly 72px")
	_check(is_equal_approx(play.position.y - app.run_screen.global_position.y, 72.0), label + ": play area must begin below the fixed banner")
	var hud = app.structured_hud
	var controls: Array[Control] = [hud.time_button, hud.status_button, app.top_menu_button, app.top_settings_button, app.top_inventory_button, app.active_item_button]
	if app.delivery_action_button.visible:
		controls.append(app.delivery_action_button)
	var action_rects: Array[Dictionary] = []
	for index in range(controls.size()):
		var control := controls[index]
		if not control.visible:
			continue
		var rect := control.get_global_rect()
		_check(_encloses(banner, rect), label + ": " + control.name + " must be entirely inside the banner")
		_check(rect.size.y >= (52.0 if large_text else 40.0), label + ": " + control.name + " must keep its touch target")
		_check(control.focus_mode == Control.FOCUS_ALL, label + ": " + control.name + " must keep keyboard focus")
		for earlier in range(index):
			if controls[earlier].visible:
				_check(not rect.intersects(controls[earlier].get_global_rect()), label + ": action targets must not overlap")
		action_rects.append({"name": str(control.name), "rect": str(rect)})
	for metric in [hud.wallet_chip, hud.chips_chip, hud.heat_meter, hud.drunk_meter, hud.time_day_label, hud.time_exact_label]:
		if metric.visible and metric.is_visible_in_tree():
			_check(_encloses(hud.get_global_rect(), metric.get_global_rect()), label + ": metric must remain inside its bounded HUD column")
	return {"banner": str(banner), "play": str(play), "structured": str(hud.get_global_rect()), "actions": action_rects}


func _find_label(node: Node, text: String) -> Label:
	if node is Label and node.text == text:
		return node as Label
	for child in node.get_children():
		var found := _find_label(child, text)
		if found != null:
			return found
	return null


func _settle_layout(app: ShellOnly) -> void:
	await _settle()
	app._invalidate_run_screen_layout()
	app._apply_run_screen_layout()
	await _settle()


func _settle() -> void:
	for frame in range(6):
		await process_frame


func _encloses(outer: Rect2, inner: Rect2) -> bool:
	# Scroll offsets are integral, while accessibility target heights can have
	# fractional pixels (52 * 1.3). Allow the same 1px rounding as the menu check.
	return outer.grow(1.0).encloses(inner) and inner.has_area()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
