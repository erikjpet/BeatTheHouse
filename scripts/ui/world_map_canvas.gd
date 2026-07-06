class_name WorldMapCanvas
extends Control

signal layout_changed

# Lightweight persistent travel-map renderer.

const ICON_SIZE := Vector2(28.0, 28.0)
const MARKER_RADIUS := 17.0
const BACKGROUND_PATH := "res://assets/art/map_backgrounds/cyberpunk_city_overhead.png"

var snapshot: Dictionary = {}
var icon_texture_cache: Dictionary = {}
var background_texture_cache: Dictionary = {}
var nodes_by_id_cache: Dictionary = {}
var node_screen_position_cache: Dictionary = {}
var map_view_bounds_cache := Rect2(Vector2.ZERO, Vector2.ONE)
var travel_edge_ids_cache: Array = []
var enabled_travel_edge_ids_cache: Array = []
var cached_layout_size := Vector2(-1.0, -1.0)


func set_map_snapshot(map_snapshot: Dictionary) -> void:
	snapshot = map_snapshot.duplicate(true)
	_rebuild_snapshot_cache()
	queue_redraw()


func current_view_snapshot() -> Dictionary:
	_ensure_layout_cache()
	var view := snapshot.duplicate(true)
	var markers: Array = []
	for node_value in _array_view(snapshot.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if not node_is_in_view(node_id):
			continue
		var center := _normalized_position(_copy_dict(node.get("position", {})))
		markers.append({
			"id": node_id,
			"position": _copy_dict(node.get("position", {})),
			"screen_center": {"x": center.x, "y": center.y},
			"icon_path": str(node.get("icon_path", "")),
			"travel_target": bool(node.get("travel_target", false)),
			"travel_enabled": bool(node.get("travel_enabled", false)),
		})
	view["icon_markers"] = markers
	var bounds := map_view_bounds_cache
	view["map_bounds"] = {
		"x": bounds.position.x,
		"y": bounds.position.y,
		"width": bounds.size.x,
		"height": bounds.size.y,
	}
	return view


func local_position_for_node(node_id: String) -> Vector2:
	_ensure_layout_cache()
	if not node_screen_position_cache.has(node_id):
		return Vector2.ZERO
	return node_screen_position_cache.get(node_id, Vector2.ZERO) as Vector2


func node_is_in_view(node_id: String) -> bool:
	_ensure_layout_cache()
	if not node_screen_position_cache.has(node_id):
		return false
	return _point_in_view(node_screen_position_cache.get(node_id, Vector2.ZERO) as Vector2, MARKER_RADIUS + 8.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_rebuild_layout_cache()
		if size.x > 0.0 and size.y > 0.0:
			layout_changed.emit()
		queue_redraw()


func _draw() -> void:
	_ensure_layout_cache()
	var rect := Rect2(Vector2.ZERO, size)
	_draw_background(rect)
	_draw_edges()
	_draw_path()
	_draw_nodes()
	draw_rect(rect.grow(-1.0), Color("#2ee9ff", 0.32), false, 2.0)


func _draw_background(rect: Rect2) -> void:
	var texture := _background_texture()
	if texture != null:
		var bounds := map_view_bounds_cache
		var texture_size := texture.get_size()
		var source_rect := Rect2(
			Vector2(bounds.position.x * texture_size.x, bounds.position.y * texture_size.y),
			Vector2(bounds.size.x * texture_size.x, bounds.size.y * texture_size.y)
		)
		draw_texture_rect_region(texture, rect, source_rect, Color(1.0, 1.0, 1.0, 0.92))
	else:
		draw_rect(rect, Color("#07091a"))
	draw_rect(rect, Color("#03040a", 0.30))


func _draw_edges() -> void:
	var nodes := nodes_by_id_cache
	for edge_value in _array_view(snapshot.get("edges", [])):
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		var a := _node_position(nodes, str(edge.get("a", "")))
		var b := _node_position(nodes, str(edge.get("b", "")))
		if a.x < 0.0 or b.x < 0.0:
			continue
		if not _segment_in_view(a, b):
			continue
		var distance := str(edge.get("distance", "near"))
		var edge_id := str(edge.get("id", _edge_id(str(edge.get("a", "")), str(edge.get("b", "")))))
		var color := Color("#6f6aa8", 0.34)
		var width := 1.5
		if distance == "far" or distance == "remote":
			color = Color("#a56a62", 0.32)
		if travel_edge_ids_cache.has(edge_id):
			color = Color("#ffd36a", 0.50)
			width = 2.2
		if enabled_travel_edge_ids_cache.has(edge_id):
			color = Color("#5df2a2", 0.86)
			width = 3.0
		draw_line(a, b, color, width)


func _draw_path() -> void:
	var nodes := nodes_by_id_cache
	var path := _string_array(snapshot.get("visited_path", []))
	for index in range(path.size() - 1):
		var a := _node_position(nodes, str(path[index]))
		var b := _node_position(nodes, str(path[index + 1]))
		if a.x < 0.0 or b.x < 0.0:
			continue
		if not _segment_in_view(a, b):
			continue
		draw_line(a, b, Color("#ffd36a", 0.46), 4.0)


func _draw_nodes() -> void:
	var current_id := str(snapshot.get("current_node_id", ""))
	var selected_id := str(snapshot.get("selected_node_id", ""))
	for node_value in _array_view(snapshot.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		var pos := _node_position(nodes_by_id_cache, node_id)
		if not _point_in_view(pos, MARKER_RADIUS + 8.0):
			continue
		var state := str(node.get("state", "hidden"))
		var radius := MARKER_RADIUS
		var is_current := node_id == current_id
		var travel_enabled := bool(node.get("travel_enabled", false))
		var travel_target := bool(node.get("travel_target", false))
		var alpha := 1.0 if is_current or travel_enabled else 0.38
		if travel_target and not travel_enabled:
			alpha = 0.55
		if node_id == selected_id:
			alpha = maxf(alpha, 0.76)
		var color := Color("#89dceb", alpha)
		var fill := Color("#101832", 0.90 * alpha)
		if state == "visited":
			color = Color("#ffd36a", alpha)
			fill = Color("#4a3c1d", 0.94 * alpha)
		if travel_enabled:
			color = Color("#5df2a2", 1.0)
			fill = Color("#123b31", 0.95)
		if is_current:
			color = Color("#5df2a2", 1.0)
			fill = Color("#173927", 0.98)
		if node_id == selected_id:
			draw_circle(pos, radius + 7.0, Color("#f27fb3", 0.36))
		draw_circle(pos, radius, fill)
		draw_circle(pos, radius, color, false, 2.0)
		if travel_enabled and not is_current:
			draw_circle(pos, radius + 4.0, Color("#5df2a2", 0.44), false, 2.0)
		var texture := _texture_for_node(node)
		if texture != null:
			var icon_rect := Rect2(pos - ICON_SIZE * 0.5, ICON_SIZE)
			var tint := Color(1.0, 1.0, 1.0, 1.0 if is_current or travel_enabled else alpha)
			draw_texture_rect(texture, icon_rect, false, tint)
		else:
			draw_circle(pos, 7.0, color if is_current or travel_enabled else Color(color.r, color.g, color.b, alpha))
		if is_current:
			draw_circle(pos, radius + 3.0, Color("#5df2a2", 0.22), false, 2.0)


func _rebuild_snapshot_cache() -> void:
	nodes_by_id_cache = {}
	for node_value in _array_view(snapshot.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if not node_id.is_empty():
			nodes_by_id_cache[node_id] = node
	_warm_texture_cache()
	_rebuild_layout_cache()
	travel_edge_ids_cache = _travel_edge_ids(false)
	enabled_travel_edge_ids_cache = _travel_edge_ids(true)


func _warm_texture_cache() -> void:
	_background_texture()
	for node_value in _array_view(snapshot.get("nodes", [])):
		if typeof(node_value) == TYPE_DICTIONARY:
			_texture_for_node(node_value)


func _ensure_layout_cache() -> void:
	if cached_layout_size != size:
		_rebuild_layout_cache()


func _rebuild_layout_cache() -> void:
	map_view_bounds_cache = _compute_map_view_bounds()
	cached_layout_size = size
	node_screen_position_cache = {}
	for node_id_value in nodes_by_id_cache.keys():
		var node_id := str(node_id_value)
		var node: Dictionary = nodes_by_id_cache.get(node_id, {})
		node_screen_position_cache[node_id] = _normalized_position_from_variant(node.get("position", {}))


func _node_position(nodes: Dictionary, node_id: String) -> Vector2:
	if node_screen_position_cache.has(node_id):
		return node_screen_position_cache.get(node_id, Vector2(-1.0, -1.0)) as Vector2
	if not nodes.has(node_id):
		return Vector2(-1.0, -1.0)
	var node: Dictionary = nodes.get(node_id, {})
	return _normalized_position_from_variant(node.get("position", {}))


func _normalized_position_from_variant(value: Variant) -> Vector2:
	if typeof(value) != TYPE_DICTIONARY:
		return _normalized_position({})
	return _normalized_position(value as Dictionary)


func _normalized_position(position: Dictionary) -> Vector2:
	var inset := Vector2(32.0, 28.0)
	var drawable := Vector2(maxf(1.0, size.x - inset.x * 2.0), maxf(1.0, size.y - inset.y * 2.0))
	var bounds := map_view_bounds_cache
	var x := clampf(float(position.get("x", 0.5)), 0.0, 1.0)
	var y := clampf(float(position.get("y", 0.5)), 0.0, 1.0)
	var local_x := (x - bounds.position.x) / maxf(0.001, bounds.size.x)
	var local_y := (y - bounds.position.y) / maxf(0.001, bounds.size.y)
	return inset + Vector2(local_x, local_y) * drawable


func _compute_map_view_bounds() -> Rect2:
	var nodes := _bounds_focus_nodes()
	if nodes.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ONE)
	var min_x := 1.0
	var min_y := 1.0
	var max_x := 0.0
	var max_y := 0.0
	for node_value in nodes:
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var position_value: Variant = node.get("position", {})
		var position: Dictionary = {}
		if typeof(position_value) == TYPE_DICTIONARY:
			position = position_value as Dictionary
		var x := clampf(float(position.get("x", 0.5)), 0.0, 1.0)
		var y := clampf(float(position.get("y", 0.5)), 0.0, 1.0)
		min_x = minf(min_x, x)
		min_y = minf(min_y, y)
		max_x = maxf(max_x, x)
		max_y = maxf(max_y, y)
	var center := Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
	var width := maxf(0.34, (max_x - min_x) + 0.20)
	var height := maxf(0.34, (max_y - min_y) + 0.20)
	var drawable := Vector2(maxf(1.0, size.x - 64.0), maxf(1.0, size.y - 56.0))
	var aspect := drawable.x / drawable.y
	if width / height < aspect:
		width = height * aspect
	else:
		height = width / aspect
	width = minf(1.0, width)
	height = minf(1.0, height)
	var x0 := clampf(center.x - width * 0.5, 0.0, 1.0 - width)
	var y0 := clampf(center.y - height * 0.5, 0.0, 1.0 - height)
	return Rect2(Vector2(x0, y0), Vector2(width, height))


func _bounds_focus_nodes() -> Array:
	var nodes := _array_view(snapshot.get("nodes", []))
	var focus_ids := _string_array(snapshot.get("map_focus_node_ids", []))
	if focus_ids.is_empty():
		return nodes
	var focus_lookup: Dictionary = {}
	for focus_id in focus_ids:
		focus_lookup[str(focus_id)] = true
	var result: Array = []
	for node_value in nodes:
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		if focus_lookup.has(str(node.get("id", ""))):
			result.append(node)
	return result if not result.is_empty() else nodes


func _point_in_view(point: Vector2, margin: float = 0.0) -> bool:
	return point.x >= -margin and point.y >= -margin and point.x <= size.x + margin and point.y <= size.y + margin


func _segment_in_view(a: Vector2, b: Vector2) -> bool:
	if _point_in_view(a) or _point_in_view(b):
		return true
	var min_x := minf(a.x, b.x)
	var max_x := maxf(a.x, b.x)
	var min_y := minf(a.y, b.y)
	var max_y := maxf(a.y, b.y)
	return max_x >= 0.0 and min_x <= size.x and max_y >= 0.0 and min_y <= size.y


func _travel_edge_ids(enabled_only: bool) -> Array:
	var result: Array = []
	for path_value in _array_view(snapshot.get("travel_paths", [])):
		if typeof(path_value) != TYPE_DICTIONARY:
			continue
		var path_data: Dictionary = path_value
		if enabled_only and not bool(path_data.get("enabled", false)):
			continue
		var path := _string_array(path_data.get("path", []))
		for index in range(path.size() - 1):
			var edge_id := _edge_id(str(path[index]), str(path[index + 1]))
			if not edge_id.is_empty() and not result.has(edge_id):
				result.append(edge_id)
	return result


func _edge_id(a: String, b: String) -> String:
	var left := a.strip_edges()
	var right := b.strip_edges()
	if left.is_empty() or right.is_empty() or left == right:
		return ""
	if left < right:
		return "%s--%s" % [left, right]
	return "%s--%s" % [right, left]


func _background_texture() -> Texture2D:
	var path := str(snapshot.get("background_path", BACKGROUND_PATH)).strip_edges()
	if path.is_empty():
		path = BACKGROUND_PATH
	if background_texture_cache.has(path):
		return background_texture_cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		var image := Image.new()
		if image.load(path) != OK:
			background_texture_cache[path] = null
			return null
		var image_texture := ImageTexture.create_from_image(image)
		background_texture_cache[path] = image_texture
		return image_texture
	var texture := load(path) as Texture2D
	background_texture_cache[path] = texture
	return texture


func _texture_for_node(node: Dictionary) -> Texture2D:
	var path := str(node.get("icon_path", "")).strip_edges()
	if path.is_empty():
		path = "res://assets/art/map_icons/%s.png" % str(node.get("archetype_id", node.get("id", "")))
	if path.is_empty():
		return null
	if icon_texture_cache.has(path):
		return icon_texture_cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		var image := Image.new()
		if image.load(path) != OK:
			icon_texture_cache[path] = null
			return null
		var image_texture := ImageTexture.create_from_image(image)
		icon_texture_cache[path] = image_texture
		return image_texture
	var texture := load(path) as Texture2D
	icon_texture_cache[path] = texture
	return texture


static func _array_view(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return value as Array


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
