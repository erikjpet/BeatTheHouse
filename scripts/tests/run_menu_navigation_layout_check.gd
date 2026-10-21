extends SceneTree

# Exercise the shipped menu controls and layout without starting a run, loading
# a profile, or creating a game surface.
class MenuOnly:
	extends "res://scripts/ui/foundation_main.gd"

	func _ready() -> void:
		set_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)


var failures: Array[String] = []
var cases: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(360, 640), Vector2i(640, 360)]:
		await _check_layout(viewport_size)
	var report := {"passed": failures.is_empty(), "cases": cases, "failures": failures}
	var report_path := OS.get_environment("BTH_MENU_LAYOUT_REPORT")
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t") + "\n")
	print("RUN_MENU_NAVIGATION_LAYOUT " + ("PASS" if failures.is_empty() else "FAIL"))
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check_layout(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.disable_3d = true
	root.add_child(viewport)
	var app := MenuOnly.new()
	app.size = Vector2(viewport_size)
	viewport.add_child(app)
	app.call("_build_run_menu_overlay")
	var overlay := app.get("run_menu_overlay") as Control
	var panel := app.get("run_menu_panel") as Control
	var scroll := app.get("run_menu_scroll") as ScrollContainer
	var status := app.get("run_menu_status_label") as Label
	status.text = "Seed FIRST-NIGHT-ACE-17 | Corner Store | Bankroll 80 | Heat 0\nResume Slot ready. Save overwrites this slot; Load replaces this run."
	overlay.show()
	app.call("_layout_run_menu_panel")
	await _settle()
	# The production opening path reapplies this clamp after container minimums
	# settle. Match that lifecycle rather than measuring an unbounded first pass.
	app.call("_layout_run_menu_panel")
	await _settle()
	scroll.scroll_vertical = 0
	await _settle()
	var label := "%dx%d" % [viewport_size.x, viewport_size.y]
	var safe := Rect2(Vector2(12, 12), Vector2(viewport_size) - Vector2(24, 24))
	_check(_encloses(safe, panel.get_global_rect()), label + ": menu must keep 12px viewport margins")
	_check(scroll.follow_focus, label + ": keyboard focus must scroll into view")
	var actions: Array = app.get("run_menu_action_controls")
	var expected := ["Resume", "Save", "Load", "Journal", "Settings", "Abandon Run", "Main Menu", "Skip Lessons"]
	var initial: Array[Dictionary] = []
	var scroll_rect := scroll.get_global_rect()
	for index in range(actions.size()):
		var action := actions[index] as Button
		var rect := action.get_global_rect()
		_check(action.text == expected[index], label + ": action order and labels must stay unchanged")
		_check(action.focus_mode == Control.FOCUS_ALL, label + ": action must keep keyboard focus")
		_check(rect.size.y >= 52.0, label + ": touch target must stay at least 52px")
		var visible_without_scroll := _encloses(scroll_rect, rect)
		initial.append({"text": action.text, "visible_without_scroll": visible_without_scroll, "height": rect.size.y})
		if viewport_size.y >= 640:
			_check(visible_without_scroll, label + ": " + action.text + " must be visible when the menu opens")
		for earlier_index in range(index):
			_check(not rect.intersects((actions[earlier_index] as Control).get_global_rect()), label + ": action targets must not overlap")
	for action_value in actions:
		var action := action_value as Button
		action.grab_focus()
		app.call("_on_run_menu_action_focus_entered", action)
		await _settle()
		app.call("_clamp_run_menu_action_visibility", action)
		await _settle()
		_check(_encloses(scroll.get_global_rect(), action.get_global_rect()), label + ": focused " + action.text + " must be reachable on short screens")
	var glyph_label := _find_label(overlay, "Glyph Legend")
	_check(glyph_label != null, label + ": existing glyph help content must remain")
	if glyph_label != null:
		scroll.ensure_control_visible(glyph_label)
		await _settle()
		_check(_encloses(scroll.get_global_rect(), glyph_label.get_global_rect()), label + ": glyph help must remain reachable by scrolling")
	var slot_note := _find_label(overlay, "Resume Slot: one local save. Save overwrites it; Load replaces this run from it.")
	_check(slot_note != null, label + ": save/load explanation must remain")
	cases.append({"viewport": {"width": viewport_size.x, "height": viewport_size.y}, "panel_rect": str(panel.get_global_rect()), "scroll_rect": str(scroll.get_global_rect()), "initial_actions": initial, "glyph_help_retained": glyph_label != null, "slot_note_retained": slot_note != null})
	viewport.queue_free()
	await _settle()


func _find_label(node: Node, text: String) -> Label:
	if node is Label and node.text == text:
		return node as Label
	for child in node.get_children():
		var found := _find_label(child, text)
		if found != null:
			return found
	return null


func _encloses(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(1.0).encloses(inner) and inner.has_area()


func _settle() -> void:
	for frame in range(4):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
