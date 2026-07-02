class_name WorldMapCanvas
extends Control

# Lightweight persistent travel-map renderer.

var snapshot: Dictionary = {}


func set_map_snapshot(map_snapshot: Dictionary) -> void:
	snapshot = map_snapshot.duplicate(true)
	queue_redraw()


func current_view_snapshot() -> Dictionary:
	return snapshot.duplicate(true)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color("#07091a"))
	draw_rect(rect.grow(-1.0), Color("#101832"), false, 2.0)
	_draw_edges()
	_draw_path()
	_draw_nodes()


func _draw_edges() -> void:
	var nodes := _nodes_by_id()
	for edge_value in _copy_array(snapshot.get("edges", [])):
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		var a := _node_position(nodes, str(edge.get("a", "")))
		var b := _node_position(nodes, str(edge.get("b", "")))
		if a.x < 0.0 or b.x < 0.0:
			continue
		var distance := str(edge.get("distance", "near"))
		var color := Color("#6f6aa8", 0.66)
		if distance == "far" or distance == "remote":
			color = Color("#a56a62", 0.62)
		draw_line(a, b, color, 2.0)


func _draw_path() -> void:
	var nodes := _nodes_by_id()
	var path := _string_array(snapshot.get("visited_path", []))
	for index in range(path.size() - 1):
		var a := _node_position(nodes, str(path[index]))
		var b := _node_position(nodes, str(path[index + 1]))
		if a.x < 0.0 or b.x < 0.0:
			continue
		draw_line(a, b, Color("#ffd36a", 0.9), 4.0)


func _draw_nodes() -> void:
	var current_id := str(snapshot.get("current_node_id", ""))
	var selected_id := str(snapshot.get("selected_node_id", ""))
	for node_value in _copy_array(snapshot.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		var pos := _normalized_position(_copy_dict(node.get("position", {})))
		var state := str(node.get("state", "hidden"))
		var radius := 8.0
		var color := Color("#89dceb")
		if state == "visited":
			color = Color("#ffd36a")
			radius = 10.0
		if node_id == current_id:
			color = Color("#5df2a2")
			radius = 12.0
		if node_id == selected_id:
			draw_circle(pos, radius + 6.0, Color("#f27fb3", 0.32))
		draw_circle(pos, radius, color if state == "visited" or node_id == current_id else Color(color.r, color.g, color.b, 0.18))
		draw_circle(pos, radius, color, false, 2.0)


func _nodes_by_id() -> Dictionary:
	var result: Dictionary = {}
	for node_value in _copy_array(snapshot.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if not node_id.is_empty():
			result[node_id] = node
	return result


func _node_position(nodes: Dictionary, node_id: String) -> Vector2:
	if not nodes.has(node_id):
		return Vector2(-1.0, -1.0)
	var node: Dictionary = nodes.get(node_id, {})
	return _normalized_position(_copy_dict(node.get("position", {})))


func _normalized_position(position: Dictionary) -> Vector2:
	var inset := Vector2(32.0, 28.0)
	var drawable := Vector2(maxf(1.0, size.x - inset.x * 2.0), maxf(1.0, size.y - inset.y * 2.0))
	return inset + Vector2(clampf(float(position.get("x", 0.5)), 0.0, 1.0), clampf(float(position.get("y", 0.5)), 0.0, 1.0)) * drawable


static func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var text := str(entry).strip_edges()
		if not text.is_empty():
			result.append(text)
	return result
