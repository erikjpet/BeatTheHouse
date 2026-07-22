extends SceneTree

const WorldMapCanvasScript := preload("res://scripts/ui/world_map_canvas.gd")
const RunReportViewModelScript := preload("res://scripts/ui/run_report_view_model.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_zoomed_route_geometry_survives()
	await _check_run_report_map_fits_missing_final_location()
	if failures.is_empty():
		print("WORLD_MAP_CANVAS_ROUTE_VISIBILITY_CHECK PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_zoomed_route_geometry_survives() -> void:
	var canvas: WorldMapCanvas = WorldMapCanvasScript.new()
	canvas.size = Vector2(360, 220)
	root.add_child(canvas)
	canvas.set_map_snapshot({
		"current_node_id": "west",
		"selected_node_id": "east",
		"map_focus_node_ids": ["west", "east"],
		"nodes": [
			{"id": "west", "display_name": "West", "icon_path": "res://assets/art/map_icons/bar.png", "state": "visited", "position": {"x": 0.08, "y": 0.48}},
			{"id": "east", "display_name": "East", "icon_path": "res://assets/art/map_icons/grand_casino.png", "state": "revealed", "travel_target": true, "travel_enabled": true, "position": {"x": 0.92, "y": 0.50}},
			{"id": "north", "display_name": "North", "icon_path": "res://assets/art/map_icons/pawn_shop.png", "state": "revealed", "travel_target": true, "travel_enabled": true, "position": {"x": 0.55, "y": 0.08}},
		],
		"edges": [
			{"id": "west--east", "a": "west", "b": "east", "distance": "near"},
			{"id": "west--north", "a": "west", "b": "north", "distance": "near"},
		],
		"travel_paths": [
			{"target_id": "east", "path": ["west", "east"], "enabled": true},
			{"target_id": "north", "path": ["west", "north"], "enabled": true},
		],
		"route_path_geometry": [
			{"target_id": "east", "enabled": true, "points": [{"id": "west", "x": 0.08, "y": 0.48}, {"id": "east", "x": 0.92, "y": 0.50}]},
			{"target_id": "north", "enabled": true, "points": [{"id": "west", "x": 0.08, "y": 0.48}, {"id": "north", "x": 0.55, "y": 0.08}]},
		],
	})
	await process_frame
	var initial_view := canvas.current_view_snapshot()
	_check(_array(initial_view.get("visible_route_segments", [])).size() >= 2, "Initial map did not expose travel route segments.")
	var selected_snapshot := initial_view.duplicate(true)
	selected_snapshot["selected_node_id"] = "north"
	selected_snapshot["map_focus_node_ids"] = ["north"]
	canvas.set_map_snapshot(selected_snapshot)
	for _index in range(12):
		await process_frame
	var focused_view := canvas.current_view_snapshot()
	_check(_array(focused_view.get("visible_route_segments", [])).size() >= 1, "Focused map dropped all travel route segments when endpoints were cropped.")
	canvas.queue_free()


func _check_run_report_map_fits_missing_final_location() -> void:
	var world_map := {
		"current_node_id": "missing_final_room",
		"visited_path": ["bar", "casino", "missing_final_room"],
		"nodes": [
			{"id": "bar", "display_name": "Bar", "icon_path": "res://assets/art/map_icons/bar.png", "state": "visited", "position": {"x": 0.08, "y": 0.45}},
			{"id": "casino", "display_name": "Casino", "icon_path": "res://assets/art/map_icons/grand_casino.png", "state": "visited", "position": {"x": 0.92, "y": 0.52}},
		],
		"edges": [{"id": "bar--casino", "a": "bar", "b": "casino", "distance": "near"}],
	}
	var timeline := {
		"visited_node_ids": ["bar", "casino", "missing_final_room"],
		"travel_keyframes": [
			{"node_id": "bar", "position": {"x": 0.08, "y": 0.45}},
			{"node_id": "casino", "position": {"x": 0.92, "y": 0.52}},
			{"node_id": "missing_final_room", "position": {"x": 0.55, "y": 0.84}},
		],
	}
	var report_map := RunReportViewModelScript.build_report_map_snapshot(world_map, timeline)
	_check(str(report_map.get("current_node_id", "")) == "missing_final_room", "Run report map did not mark the final location as current.")
	_check(_node_ids(report_map).has("missing_final_room"), "Run report map dropped the final location when it was missing from source nodes.")
	var canvas: WorldMapCanvas = WorldMapCanvasScript.new()
	canvas.size = Vector2(420, 260)
	root.add_child(canvas)
	canvas.set_map_snapshot(report_map)
	await process_frame
	var view := canvas.current_view_snapshot()
	var marker_ids := _marker_ids(view)
	for node_id in ["bar", "casino", "missing_final_room"]:
		_check(marker_ids.has(node_id), "Run report map did not fit/show visited location: %s." % node_id)
	_check(_array(view.get("visible_route_segments", [])).size() >= 2, "Run report map did not preserve route lines between visited locations.")
	canvas.queue_free()


func _node_ids(map_snapshot: Dictionary) -> Array:
	var result: Array = []
	for node_value in _array(map_snapshot.get("nodes", [])):
		if typeof(node_value) == TYPE_DICTIONARY:
			result.append(str((node_value as Dictionary).get("id", "")))
	return result


func _marker_ids(view: Dictionary) -> Array:
	var result: Array = []
	for marker_value in _array(view.get("icon_markers", [])):
		if typeof(marker_value) == TYPE_DICTIONARY:
			result.append(str((marker_value as Dictionary).get("id", "")))
	return result


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
