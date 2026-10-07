extends SceneTree

const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const SettingsMenuScript := preload("res://scripts/ui/settings_menu.gd")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")

const TEST_SETTINGS_PATH := "user://pixel_scene_object_labels_settings.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_settings_option()
	await _check_saturated_tether_policy()
	var canvas: PixelSceneCanvas = PixelSceneCanvasScript.new()
	canvas.size = Vector2(900.0, 430.0)
	root.add_child(canvas)
	canvas.uses_foundation_snapshot = true
	canvas.foundation_scene_objects = [
		_object("scenario::cashier", "Rush Bartender", Vector2(0.40, 0.32), 1),
		_object("scenario::envelopes", "Open Tab Envelopes", Vector2(0.44, 0.32), 2),
		_object("scenario::tray", "Lift First Tray", Vector2(0.48, 0.32), 3),
	]
	canvas.call("_rebuild_scene_object_cache")
	await process_frame
	var view: Dictionary = canvas.current_view_snapshot()
	var object_layout: Dictionary = view.get("object_layout", {})
	var label_layout: Dictionary = object_layout.get("label_layout", {})
	_check(int(label_layout.get("default_label_overlap_count", 0)) > 0, "Fixture must exercise labels that collide at their default positions.")
	_check(int(label_layout.get("resolved_label_overlap_count", -1)) == 0, "Resolved room labels must not overlap each other.")
	_check(int(label_layout.get("resolved_object_overlap_count", -1)) == 0, "Resolved room labels must not cover unrelated interactables.")
	_check(int(label_layout.get("detached_label_count", -1)) == 0, "Resolved room labels must remain tethered to their owning objects.")
	for entry_value in object_layout.get("objects", []):
		var entry := entry_value as Dictionary
		var object_rect := _rect_from_snapshot(entry.get("rect", {}))
		var label_rect := _rect_from_snapshot(entry.get("label_rect", {}))
		_check(label_rect.has_area(), "Enabled object labels must expose a resolved rectangle.")
		_check(_horizontal_overlap(object_rect, label_rect) > 0.0, "A crowded label must remain horizontally associated with its owning object.")
		_check(_rect_edge_gap(object_rect, label_rect) <= 30.01, "A crowded label must remain tethered within 30 pixels of its owning object.")
	var cache_snapshot: Dictionary = canvas.debug_soak_snapshot()
	_check(int(cache_snapshot.get("active_scene_object_cache_size", -1)) == 3, "Ordered scene objects must be retained in the room-refresh cache.")
	_check(int(cache_snapshot.get("object_label_rect_cache_size", -1)) == 3, "Resolved label rectangles must be retained in the room-refresh cache.")
	var first_active: Array = canvas.call("_active_scene_objects")
	var second_active: Array = canvas.call("_active_scene_objects")
	_check(is_same(first_active, second_active), "Repeated room draws must reuse the ordered object array instead of duplicating and sorting it.")
	var moving_object := _object("scenario::walker", "Walker", Vector2(0.25, 0.50), 4)
	moving_object["actor_route_stage"] = {"duration_sec": 1.0}
	moving_object["actor_route_points"] = [Vector2(0.25, 0.50), Vector2(0.75, 0.50)]
	var moving_label_start: Rect2 = canvas.call("_resolved_label_rect_for_object", moving_object, Rect2(Vector2(180.0, 190.0), Vector2(92.0, 60.0)))
	var moving_label_end: Rect2 = canvas.call("_resolved_label_rect_for_object", moving_object, Rect2(Vector2(630.0, 190.0), Vector2(92.0, 60.0)))
	_check(not moving_label_start.is_equal_approx(moving_label_end), "A moving character's label must follow its current rendered position instead of a cached route origin.")
	canvas.set_object_labels_and_borders_enabled(false)
	var first_entry := (object_layout.get("objects", []) as Array)[0] as Dictionary
	var first_object_rect := _rect_from_snapshot(first_entry.get("rect", {}))
	var hit_position := first_object_rect.position + Vector2(4.0, first_object_rect.size.y * 0.5)
	_check(canvas.object_id_at_local_position(hit_position) == "scenario::cashier", "Hiding room-object labels and borders must not disable object hit testing.")
	canvas.set_selected_object("scenario::cashier")
	var hidden_view: Dictionary = canvas.current_view_snapshot()
	var hidden_layout: Dictionary = hidden_view.get("object_layout", {})
	var selected_info: Dictionary = hidden_view.get("selected_info", {})
	_check(not bool(hidden_view.get("object_labels_and_borders_enabled", true)), "The room-object visibility setting must be reflected by the canvas snapshot.")
	_check(int((hidden_layout.get("label_layout", {}) as Dictionary).get("label_count", -1)) == 0, "Turning off labels and borders must clear resolved label geometry.")
	_check(int(canvas.debug_soak_snapshot().get("object_label_rect_cache_size", -1)) == 0, "Hidden labels must not remain in the room-refresh cache.")
	_check(bool(selected_info.get("visible", false)) and bool(selected_info.get("interaction_available", false)), "Hiding labels and borders must preserve the selected object's details and interaction.")
	_check(JSON.stringify(selected_info.get("lines", [])).contains("Keeps the rush moving"), "Hiding visual labels must preserve the selected object's description text.")
	_check(canvas.tooltip_text == "Rush Bartender" and canvas.accessibility_name == "Rush Bartender", "Hiding visual labels must preserve the object's tooltip and accessibility name.")
	for entry_value in hidden_layout.get("objects", []):
		var hidden_entry := entry_value as Dictionary
		_check(not _rect_from_snapshot(hidden_entry.get("label_rect", {})).has_area(), "Hidden room-object labels must not reserve visible layout space.")
	canvas.set_object_labels_and_borders_enabled(true)
	_check(int(canvas.debug_soak_snapshot().get("object_label_rect_cache_size", -1)) == 3, "Re-enabling labels and borders must rebuild their room-refresh cache.")
	canvas.queue_free()
	await process_frame
	if failures.is_empty():
		print("PIXEL_SCENE_LABEL_LAYOUT_CHECK PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_settings_option() -> void:
	var previous_settings_path := OS.get_environment(UserSettingsScript.SETTINGS_PATH_ENV)
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, TEST_SETTINGS_PATH)
	_remove_test_settings()
	var settings: UserSettings = UserSettingsScript.new()
	var menu: SettingsMenu = SettingsMenuScript.new()
	root.add_child(menu)
	menu.setup(settings)
	menu.open()
	_check(menu.object_labels_and_borders != null and menu.object_labels_and_borders.button_pressed, "Settings must expose object labels and borders as enabled by default.")
	menu.object_labels_and_borders.set_pressed_no_signal(false)
	menu.call("_on_object_labels_and_borders", false)
	_check(not bool(menu.current_settings_snapshot().get("object_labels_and_borders_enabled", true)), "The object-label option must update the settings draft.")
	menu.apply_draft()
	_check(not settings.object_labels_and_borders_enabled, "Applying Settings must disable object labels and borders in the active preferences.")
	var reloaded: UserSettings = UserSettingsScript.new()
	reloaded.load()
	_check(not reloaded.object_labels_and_borders_enabled, "The object-label preference must survive a save and reload.")
	menu.call("_on_defaults")
	_check(settings.object_labels_and_borders_enabled and menu.object_labels_and_borders.button_pressed, "Restoring defaults must turn object labels and borders back on.")
	menu.queue_free()
	await process_frame
	_remove_test_settings()
	if previous_settings_path.is_empty():
		OS.unset_environment(UserSettingsScript.SETTINGS_PATH_ENV)
	else:
		OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, previous_settings_path)


func _check_saturated_tether_policy() -> void:
	var canvas: PixelSceneCanvas = PixelSceneCanvasScript.new()
	canvas.size = Vector2(900.0, 430.0)
	root.add_child(canvas)
	canvas.uses_foundation_snapshot = true
	for index in range(7):
		canvas.foundation_scene_objects.append(_object("scenario::dense_%d" % index, "Crowded Object Label %d" % index, Vector2(0.50, 0.46), index))
	canvas.call("_rebuild_scene_object_cache")
	await process_frame
	var layout: Dictionary = canvas.current_view_snapshot().get("object_layout", {})
	var label_layout: Dictionary = layout.get("label_layout", {})
	_check(int(label_layout.get("resolved_label_overlap_count", 0)) > 0, "The saturated fixture must exercise the bounded-overlap fallback.")
	_check(str(label_layout.get("overlap_policy", "")) == "bounded_tether", "Crowded labels must report the bounded-tether overlap policy.")
	_check(int(label_layout.get("detached_label_count", -1)) == 0, "Even a saturated label cluster must not detach labels from their owners.")
	_check(float(label_layout.get("max_owner_gap", INF)) <= float(label_layout.get("owner_tether_limit", 0.0)) + 0.01, "Saturated labels must remain within the declared owner tether.")
	for entry_value in layout.get("objects", []):
		var entry := entry_value as Dictionary
		var object_rect := _rect_from_snapshot(entry.get("rect", {}))
		var label_rect := _rect_from_snapshot(entry.get("label_rect", {}))
		_check(_horizontal_overlap(object_rect, label_rect) > 0.0 and _rect_edge_gap(object_rect, label_rect) <= 30.01, "Every saturated label must remain visibly associated with its owner.")
	canvas.queue_free()
	await process_frame


func _remove_test_settings() -> void:
	for suffix in ["", ".bak", ".tmp", ".rollback", ".bak.rollback"]:
		var path := "%s%s" % [TEST_SETTINGS_PATH, suffix]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _object(object_id: String, label: String, position: Vector2, z_order: int) -> Dictionary:
	return {
		"id": object_id,
		"type": "scenario_object",
		"label": label,
		"description": "Keeps the rush moving.",
		"position": position,
		"size": Vector2(92.0, 60.0),
		"scenario_layout_resolved": true,
		"scenario_z_order": z_order,
		"interactive": true,
	}


func _rect_from_snapshot(value: Variant) -> Rect2:
	var data: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	return Rect2(
		Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))),
		Vector2(float(data.get("w", 0.0)), float(data.get("h", 0.0)))
	)


func _horizontal_overlap(a: Rect2, b: Rect2) -> float:
	return maxf(0.0, minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x))


func _rect_edge_gap(a: Rect2, b: Rect2) -> float:
	var horizontal_gap := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var vertical_gap := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(horizontal_gap, vertical_gap).length()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
