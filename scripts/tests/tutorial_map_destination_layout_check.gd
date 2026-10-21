extends SceneTree

# Focused native layout reproduction of the reported First Night map overlap.
# This uses isolated tutorial state, not a player save or a Web playtest.
const MainScene := preload("res://scenes/main.tscn")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const ProfileInventoryScript := preload("res://scripts/core/profile_inventory.gd")

var failures: Array[String] = []
var cases: Array[Dictionary] = []
var setup_pass := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, "user://map_layout_settings.json")
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, "user://map_layout_meta.json")
	OS.set_environment(ProfileInventoryScript.INVENTORY_PATH_ENV, "user://map_layout_profile.json")
	var settings: UserSettings = UserSettingsScript.new()
	settings.reset()
	settings.save()
	root.size = Vector2i(1280, 720)
	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	await _settle()
	app.call("_on_start_pressed")
	await _settle()
	var run_state: RunState = app.get("run_state")
	if run_state == null or not run_state.is_tutorial_run():
		failures.append("Setup did not start the isolated tutorial.")
		_finish(app)
		return
	var completed := {
		"tutorial_apartment_xray": true,
		"tutorial_inventory_xray": true,
		"tutorial_open_map_corner": true,
	}
	run_state.narrative_flags["tutorial_lessons_completed"] = completed.duplicate(true)
	run_state.retire_pending_talk_events()
	var coach: Control = app.get("coach_overlay")
	coach.call("begin_tutorial_run", completed)
	app.call("_refresh")
	if not bool(app.call("open_world_map")):
		failures.append("Setup could not open the first tutorial map.")
		_finish(app)
		return
	await _settle()
	if not bool(app.call("select_world_map_node", "corner_store")):
		failures.append("Setup could not select the authored Corner Store destination.")
		_finish(app)
		return
	await _settle()
	coach.call("notify_dialogue_completed", "tutorial_travel_corner")
	run_state.retire_pending_talk_events()
	app.call("_refresh")
	await _settle()
	setup_pass = str(coach.call("active_lesson_id")) == "tutorial_travel_corner"
	if not setup_pass:
		failures.append("Setup did not retain the matching travel lesson.")
		_finish(app)
		return
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = viewport_size
		app.size = Vector2(viewport_size)
		app.call("_layout_world_map_panel")
		app.call("_refresh")
		await _settle()
		coach.call("update_active_anchor_context", app.call("_coach_anchor_rects"))
		await _settle()
		var controller = app.get("world_map_overlay_controller")
		var detail: Control = controller.get("detail_popup")
		var travel: Control = controller.get("confirm_button")
		var panel: Control = coach.get("panel")
		var card_rect := detail.get_global_rect()
		var bubble_rect := panel.get_global_rect()
		var travel_rect := travel.get_global_rect()
		var overlap := bubble_rect.intersection(card_rect).get_area()
		var visible_geometry := detail.is_visible_in_tree() and panel.is_visible_in_tree() and travel.is_visible_in_tree() and card_rect.has_area() and bubble_rect.has_area()
		var label := "%dx%d" % [viewport_size.x, viewport_size.y]
		if not visible_geometry:
			failures.append(label + ": selected destination, Travel and Pal panel must be visible.")
		if overlap > 0.5:
			failures.append(label + ": Pal panel covers the selected destination card.")
		var safe := Rect2(Vector2(12, 12), Vector2(viewport_size) - Vector2(24, 24))
		if not safe.encloses(bubble_rect):
			failures.append(label + ": Pal panel must remain inside viewport margins.")
		cases.append({"viewport": str(viewport_size), "card": _rect(card_rect), "bubble": _rect(bubble_rect), "travel": _rect(travel_rect), "overlap_area": overlap, "visible_geometry": visible_geometry})
	_finish(app)


func _settle() -> void:
	for _frame in range(5):
		await process_frame


func _rect(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y}


func _finish(app: Control) -> void:
	var report := {"passed": failures.is_empty(), "setup_pass": setup_pass, "cases": cases, "failures": failures, "scope": "Native isolated tutorial map layout; no Web or player-save claim"}
	var report_path := OS.get_environment("BTH_MAP_COACH_LAYOUT_REPORT")
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t") + "\n")
	print("TUTORIAL_MAP_DESTINATION_LAYOUT " + ("PASS" if failures.is_empty() else "FAIL"))
	for failure in failures:
		push_error(failure)
	app.queue_free()
	quit(0 if failures.is_empty() else 1)
