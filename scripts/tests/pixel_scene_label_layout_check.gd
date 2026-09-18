extends SceneTree

const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
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
	canvas.queue_free()
	await process_frame
	if failures.is_empty():
		print("PIXEL_SCENE_LABEL_LAYOUT_CHECK PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _object(object_id: String, label: String, position: Vector2, z_order: int) -> Dictionary:
	return {
		"id": object_id,
		"type": "scenario_object",
		"label": label,
		"position": position,
		"size": Vector2(92.0, 60.0),
		"scenario_layout_resolved": true,
		"scenario_z_order": z_order,
		"interactive": true,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
