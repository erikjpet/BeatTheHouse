extends SceneTree

const WorldMapCanvasScript := preload("res://scripts/ui/world_map_canvas.gd")
const WorldMapOverlayControllerScript := preload("res://scripts/ui/world_map_overlay_controller.gd")
const RunReportViewModelScript := preload("res://scripts/ui/run_report_view_model.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_zoomed_route_geometry_survives()
	await _check_scroll_zoom_and_drag_pan()
	await _check_overlay_routes_navigation_events()
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


func _check_overlay_routes_navigation_events() -> void:
	var holder := Control.new()
	holder.size = Vector2(800.0, 430.0)
	root.add_child(holder)
	var canvas: WorldMapCanvas = WorldMapCanvasScript.new()
	canvas.size = holder.size
	holder.add_child(canvas)
	var map_snapshot := {
		"current_node_id": "center",
		"map_focus_node_ids": ["center", "east"],
		"nodes": [
			{"id": "center", "state": "visited", "icon_path": "res://assets/art/map_icons/bar.png", "position": {"x": 0.5, "y": 0.5}},
			{"id": "east", "state": "revealed", "icon_path": "res://assets/art/map_icons/pawn_shop.png", "position": {"x": 0.85, "y": 0.5}},
		],
	}
	canvas.set_map_snapshot(map_snapshot)
	await process_frame
	var controller: WorldMapOverlayController = WorldMapOverlayControllerScript.new()
	controller.holder = holder
	controller.nodes_layer = canvas
	var click_events: Array = []
	controller.node_pressed.connect(func(node_id: String) -> void: click_events.append(node_id))
	controller.sync_node_buttons(map_snapshot)
	var test_button: Button = null
	for child in canvas.get_children():
		if child is Button and (child as Button).visible and not (child as Button).disabled:
			test_button = child as Button
			break
	_check(test_button != null, "Travel-map overlay did not create a clickable location target.")
	if test_button != null:
		_check(test_button.get_signal_connection_list("mouse_entered").is_empty(), "Map location target still has a hover-selection callback.")
		test_button.mouse_entered.emit()
		await process_frame
		test_button.pressed.emit()
		_check(click_events.size() == 1, "Clicking a map location did not emit exactly one explicit selection.")
	var before: Dictionary = canvas.current_view_snapshot().get("map_bounds", {})
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(400.0, 215.0)
	_check(controller.handle_holder_gui_input(wheel), "Travel-map overlay did not route mouse-wheel zoom to the shared map camera.")
	var zoom_target: Dictionary = canvas.current_view_snapshot().get("target_map_bounds", {})
	_check(float(zoom_target.get("width", 1.0)) < float(before.get("width", 0.0)), "Travel-map overlay wheel routing did not set a closer camera zoom target.")
	for _index in range(18):
		await process_frame
	var zoomed: Dictionary = canvas.current_view_snapshot().get("map_bounds", {})
	_check(float(zoomed.get("width", 1.0)) < float(before.get("width", 0.0)), "Travel-map overlay wheel zoom did not animate toward its target.")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	_check(controller.handle_holder_gui_input(press), "Travel-map overlay did not begin a blank-map drag.")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(170.0, 150.0)
	_check(controller.handle_holder_gui_input(motion), "Travel-map overlay did not route drag movement to the shared map camera.")
	var dragged: Dictionary = canvas.current_view_snapshot().get("map_bounds", {})
	_check(JSON.stringify(dragged) != JSON.stringify(zoomed), "Travel-map overlay drag routing did not move the shared map camera.")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = motion.position
	_check(controller.handle_holder_gui_input(release), "Travel-map overlay did not finish the camera drag cleanly.")
	holder.queue_free()
	await process_frame


func _check_scroll_zoom_and_drag_pan() -> void:
	var canvas: WorldMapCanvas = WorldMapCanvasScript.new()
	canvas.size = Vector2(360, 220)
	root.add_child(canvas)
	canvas.set_map_snapshot({
		"current_node_id": "center",
		"selected_node_id": "center",
		"map_focus_node_ids": ["center"],
		"nodes": [
			{"id": "center", "display_name": "Center", "icon_path": "res://assets/art/map_icons/bar.png", "state": "visited", "seen": true, "position": {"x": 0.50, "y": 0.50}},
			{"id": "pawn", "display_name": "Pawn Shop", "icon_path": "res://assets/art/map_icons/pawn_shop.png", "state": "revealed", "seen": true, "position": {"x": 0.92, "y": 0.86}},
		],
		"edges": [{"id": "center--pawn", "a": "center", "b": "pawn", "distance": "near"}],
	})
	await process_frame
	var before: Dictionary = canvas.current_view_snapshot().get("map_bounds", {})
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	wheel_up.position = Vector2(180.0, 110.0)
	_check(canvas.handle_navigation_input(wheel_up), "Mouse-wheel zoom-in event was not handled.")
	var immediate: Dictionary = canvas.current_view_snapshot().get("map_bounds", {})
	var zoom_target: Dictionary = canvas.current_view_snapshot().get("target_map_bounds", {})
	_check(is_equal_approx(float(immediate.get("width", 0.0)), float(before.get("width", 1.0))), "Mouse-wheel zoom snapped instead of starting a smooth transition.")
	_check(float(zoom_target.get("width", 1.0)) < float(before.get("width", 0.0)), "Mouse-wheel zoom-in did not set a closer bounds target by one increment.")
	await process_frame
	var in_motion: Dictionary = canvas.current_view_snapshot().get("map_bounds", {})
	_check(float(in_motion.get("width", 1.0)) < float(before.get("width", 0.0)) and float(in_motion.get("width", 0.0)) > float(zoom_target.get("width", 1.0)), "Mouse-wheel zoom did not interpolate smoothly between its old and new bounds.")
	for _index in range(18):
		await process_frame
	var zoomed: Dictionary = canvas.current_view_snapshot().get("map_bounds", {})
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(180.0, 110.0)
	canvas.handle_navigation_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(125.0, 75.0)
	_check(canvas.handle_navigation_input(motion), "Click-drag map motion was not handled.")
	var dragged: Dictionary = canvas.current_view_snapshot().get("map_bounds", {})
	_check(not is_equal_approx(float(dragged.get("x", 0.0)), float(zoomed.get("x", 0.0))) or not is_equal_approx(float(dragged.get("y", 0.0)), float(zoomed.get("y", 0.0))), "Click-drag did not move the map camera.")
	_check(is_equal_approx(float(dragged.get("width", 0.0)), float(zoomed.get("width", 1.0))), "Click-drag changed zoom instead of only panning the camera.")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = motion.position
	canvas.handle_navigation_input(release)
	var wheel_down := InputEventMouseButton.new()
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down.pressed = true
	wheel_down.position = Vector2(180.0, 110.0)
	for _index in range(20):
		canvas.handle_navigation_input(wheel_down)
	var minimum_zoom: Dictionary = canvas.current_view_snapshot().get("navigation", {})
	_check(bool(minimum_zoom.get("at_minimum_zoom", false)), "Mouse-wheel zoom-out did not stop at its minimum zoom bound.")
	for _index in range(30):
		canvas.handle_navigation_input(wheel_up)
	var maximum_zoom: Dictionary = canvas.current_view_snapshot().get("navigation", {})
	_check(bool(maximum_zoom.get("at_maximum_zoom", false)), "Mouse-wheel zoom-in did not stop at its maximum zoom bound.")
	canvas.queue_free()


func _check_run_report_map_fits_missing_final_location() -> void:
	var world_map := {
		"current_node_id": "missing_final_room",
		"visited_path": ["bar", "casino", "missing_final_room"],
		"nodes": [
			{"id": "bar", "display_name": "Bar", "icon_path": "res://assets/art/map_icons/bar.png", "state": "visited", "position": {"x": 0.0, "y": 0.0}},
			{"id": "casino", "display_name": "Casino", "icon_path": "res://assets/art/map_icons/grand_casino.png", "state": "visited", "position": {"x": 1.0, "y": 1.0}},
		],
		"edges": [{"id": "bar--casino", "a": "bar", "b": "casino", "distance": "near"}],
	}
	var timeline := {
		"visited_node_ids": ["bar", "casino", "missing_final_room"],
		"travel_keyframes": [
			{"node_id": "bar", "position": {"x": 0.0, "y": 0.0}},
			{"node_id": "casino", "position": {"x": 1.0, "y": 1.0}},
			{"node_id": "missing_final_room", "position": {"x": 0.55, "y": 0.98}},
		],
	}
	var report_map := RunReportViewModelScript.build_report_map_snapshot(world_map, timeline)
	_check(str(report_map.get("current_node_id", "")) == "missing_final_room", "Run report map did not mark the final location as current.")
	_check(_node_ids(report_map).has("missing_final_room"), "Run report map dropped the final location when it was missing from source nodes.")
	_check(bool(report_map.get("fit_all_nodes", false)), "Run report map was not generated in fit-all-locations mode.")
	for node_value in _array(report_map.get("nodes", [])):
		var position: Dictionary = (node_value as Dictionary).get("position", {})
		_check(float(position.get("x", 0.0)) >= 0.12 and float(position.get("x", 1.0)) <= 0.88 and float(position.get("y", 0.0)) >= 0.12 and float(position.get("y", 1.0)) <= 0.88, "Run report generation left a location in the cropped edge region.")
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
