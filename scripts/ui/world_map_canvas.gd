class_name WorldMapCanvas
extends Control

signal layout_changed

# Lightweight persistent travel-map renderer.

const ICON_SIZE := Vector2(28.0, 28.0)
const MARKER_RADIUS := 17.0
const BACKGROUND_PATH := "res://assets/art/map_backgrounds/cyberpunk_city_overhead.png"
const MAP_ICON_DIR := "res://assets/art/map_icons"
const SELECTED_FOCUS_ZOOM := 0.86
const SELECTED_FOCUS_LERP_SPEED := 22.0
const MAP_BOUNDS_SNAP_EPSILON := 0.00035

var snapshot: Dictionary = {}
var icon_texture_cache: Dictionary = {}
var background_texture_cache: Dictionary = {}
var nodes_by_id_cache: Dictionary = {}
var node_screen_position_cache: Dictionary = {}
var map_view_bounds_cache := Rect2(Vector2.ZERO, Vector2.ONE)
var target_map_view_bounds_cache := Rect2(Vector2.ZERO, Vector2.ONE)
var travel_edge_ids_cache: Array = []
var enabled_travel_edge_ids_cache: Array = []
var cached_layout_size := Vector2(-1.0, -1.0)
var snapshot_signature := ""
var map_view_bounds_signature := ""
var map_view_basis_signature := ""
var map_view_focus_node_ids_cache: Array = []
var map_view_selected_node_id_cache := ""
var stable_layout_size := Vector2(-1.0, -1.0)
var replay_keyframes: Array = []
var replay_segments: Array = []
var replay_progress := 1.0
var replay_reduce_motion := false


func _ready() -> void:
	_background_texture()
	_prewarm_map_icon_directory()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_ensure_layout_cache()
	if _map_bounds_equal(map_view_bounds_cache, target_map_view_bounds_cache):
		return
	var previous_bounds := map_view_bounds_cache
	var weight := _bounds_lerp_weight(delta)
	map_view_bounds_cache = _lerp_map_bounds(map_view_bounds_cache, target_map_view_bounds_cache, weight)
	if _map_bounds_equal(map_view_bounds_cache, target_map_view_bounds_cache):
		map_view_bounds_cache = target_map_view_bounds_cache
	if not _map_bounds_equal(previous_bounds, map_view_bounds_cache):
		_rebuild_node_screen_position_cache()
		layout_changed.emit()
		queue_redraw()


func set_map_snapshot(map_snapshot: Dictionary) -> void:
	var next_signature := JSON.stringify(map_snapshot)
	if next_signature == snapshot_signature:
		return
	snapshot_signature = next_signature
	snapshot = map_snapshot.duplicate(true)
	_rebuild_snapshot_cache()
	queue_redraw()


func set_run_report_replay(keyframes: Array, reduce_motion: bool, segments: Array = []) -> void:
	replay_keyframes = keyframes.duplicate(true)
	replay_segments = segments.duplicate(true)
	replay_reduce_motion = reduce_motion
	replay_progress = 1.0 if reduce_motion else 0.0
	queue_redraw()


func set_run_report_replay_progress(progress: float) -> void:
	var next := clampf(progress, 0.0, 1.0)
	if is_equal_approx(next, replay_progress):
		return
	replay_progress = next
	queue_redraw()


func clear_run_report_replay() -> void:
	replay_keyframes = []
	replay_segments = []
	replay_progress = 1.0
	replay_reduce_motion = false
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
			"attribute_badges": _copy_array(node.get("attribute_badges", [])),
		})
	view["icon_markers"] = markers
	var bounds := map_view_bounds_cache
	view["canvas_size"] = {
		"x": size.x,
		"y": size.y,
	}
	view["map_bounds"] = {
		"x": bounds.position.x,
		"y": bounds.position.y,
		"width": bounds.size.x,
		"height": bounds.size.y,
	}
	var target_bounds := target_map_view_bounds_cache
	view["target_map_bounds"] = {
		"x": target_bounds.position.x,
		"y": target_bounds.position.y,
		"width": target_bounds.size.x,
		"height": target_bounds.size.y,
	}
	var background_texture := _background_texture()
	if background_texture != null:
		var texture_size := background_texture.get_size()
		var source_size := Vector2(bounds.size.x * texture_size.x, bounds.size.y * texture_size.y)
		var destination_rect := _aspect_fitted_destination_rect(Rect2(Vector2.ZERO, size), source_size)
		view["background_texture_size"] = {"x": texture_size.x, "y": texture_size.y}
		view["background_source_size"] = {"x": source_size.x, "y": source_size.y}
		view["background_source_aspect"] = source_size.x / maxf(1.0, source_size.y)
		view["background_destination_size"] = {"x": destination_rect.size.x, "y": destination_rect.size.y}
		view["background_destination_aspect"] = destination_rect.size.x / maxf(1.0, destination_rect.size.y)
		view["background_fills_canvas"] = destination_rect.size.distance_to(size) <= 0.5
	view["selected_focus_zoom_active"] = _selected_focus_zoom_active()
	view["selected_focus_zoom_animating"] = not _map_bounds_equal(map_view_bounds_cache, target_map_view_bounds_cache)
	view["run_report_replay"] = _replay_marker_state()
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
	_draw_replay_marker()
	draw_rect(rect.grow(-1.0), Color("#2ee9ff", 0.32), false, 2.0)


func _draw_background(rect: Rect2) -> void:
	draw_rect(rect, Color("#07091a"))
	var texture := _background_texture()
	if texture != null:
		var bounds := map_view_bounds_cache
		var texture_size := texture.get_size()
		var source_rect := Rect2(
			Vector2(bounds.position.x * texture_size.x, bounds.position.y * texture_size.y),
			Vector2(bounds.size.x * texture_size.x, bounds.size.y * texture_size.y)
		)
		var destination_rect := _aspect_fitted_destination_rect(rect, source_rect.size)
		draw_texture_rect_region(texture, destination_rect, source_rect, Color(1.0, 1.0, 1.0, 0.92))
	draw_rect(rect, Color("#03040a", 0.30))


func _aspect_fitted_destination_rect(destination_rect: Rect2, source_size: Vector2) -> Rect2:
	if destination_rect.size.x <= 0.0 or destination_rect.size.y <= 0.0 or source_size.x <= 0.0 or source_size.y <= 0.0:
		return destination_rect
	var source_aspect := source_size.x / source_size.y
	var destination_aspect := destination_rect.size.x / destination_rect.size.y
	var fitted_size := destination_rect.size
	if source_aspect > destination_aspect:
		fitted_size.y = fitted_size.x / source_aspect
	else:
		fitted_size.x = fitted_size.y * source_aspect
	return Rect2(destination_rect.position + (destination_rect.size - fitted_size) * 0.5, fitted_size)


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
		if replay_keyframes.is_empty() or replay_reduce_motion:
			draw_line(a, b, Color("#ffd36a", 0.46), 4.0)
			continue
		var start_progress := float((replay_keyframes[index] as Dictionary).get("progress", 0.0)) if index < replay_keyframes.size() else float(index) / float(maxi(1, path.size() - 1))
		var end_progress := float((replay_keyframes[index + 1] as Dictionary).get("progress", 1.0)) if index + 1 < replay_keyframes.size() else float(index + 1) / float(maxi(1, path.size() - 1))
		var travel_segment := _travel_segment_for_leg(index)
		if not travel_segment.is_empty():
			start_progress = float(travel_segment.get("start_progress", start_progress))
			end_progress = float(travel_segment.get("end_progress", end_progress))
		if replay_progress <= start_progress:
			continue
		var leg_progress := clampf((replay_progress - start_progress) / maxf(0.0001, end_progress - start_progress), 0.0, 1.0)
		draw_line(a, a.lerp(b, leg_progress), Color("#ffd36a", 0.78), 4.0)


func _draw_replay_marker() -> void:
	if replay_keyframes.is_empty():
		return
	var replay_state := _replay_marker_state()
	if not replay_segments.is_empty() and not replay_state.is_empty():
		var from_node_id := str(replay_state.get("from_node_id", replay_state.get("node_id", "")))
		var to_node_id := str(replay_state.get("to_node_id", from_node_id))
		var segment_a := _node_position(nodes_by_id_cache, from_node_id)
		var segment_b := _node_position(nodes_by_id_cache, to_node_id)
		if segment_a.x < 0.0:
			return
		if segment_b.x < 0.0:
			segment_b = segment_a
		var segment_marker := segment_a.lerp(segment_b, float(replay_state.get("amount", 0.0)))
		_draw_replay_marker_at(segment_marker, str(replay_state.get("label", from_node_id.replace("_", " ").capitalize())))
		return
	var frame_a: Dictionary = replay_keyframes[0]
	var frame_b: Dictionary = frame_a
	for index in range(replay_keyframes.size() - 1):
		var candidate_a: Dictionary = replay_keyframes[index]
		var candidate_b: Dictionary = replay_keyframes[index + 1]
		frame_a = candidate_a
		frame_b = candidate_b
		if replay_progress <= float(candidate_b.get("progress", 1.0)):
			break
	var a := _node_position(nodes_by_id_cache, str(frame_a.get("node_id", "")))
	var b := _node_position(nodes_by_id_cache, str(frame_b.get("node_id", "")))
	if a.x < 0.0:
		return
	if b.x < 0.0:
		b = a
	var start_progress := float(frame_a.get("progress", 0.0))
	var end_progress := float(frame_b.get("progress", start_progress))
	var amount := clampf((replay_progress - start_progress) / maxf(0.0001, end_progress - start_progress), 0.0, 1.0)
	var marker := a.lerp(b, amount)
	var label := str(frame_a.get("label", frame_a.get("node_id", "Venue")))
	if amount >= 0.5:
		label = str(frame_b.get("label", frame_b.get("node_id", label)))
	_draw_replay_marker_at(marker, label)


func _draw_replay_marker_at(marker: Vector2, label: String) -> void:
	draw_circle(marker, 10.0, Color("#05060a", 0.92))
	draw_circle(marker, 8.0, Color("#00f5ff"))
	draw_circle(marker, 11.0, Color("#ffffff", 0.74), false, 2.0)
	draw_string(ThemeDB.fallback_font, marker + Vector2(14.0, -9.0), label.left(22), HORIZONTAL_ALIGNMENT_LEFT, 170.0, 11, Color("#ffffff"))


func _replay_marker_state() -> Dictionary:
	if replay_segments.is_empty():
		return {"progress": replay_progress, "segment_count": 0}
	var selected := _copy_dict(replay_segments[-1])
	for segment_value in replay_segments:
		if typeof(segment_value) != TYPE_DICTIONARY:
			continue
		var segment: Dictionary = segment_value
		selected = segment
		if replay_progress <= float(segment.get("end_progress", 1.0)) + 0.00001:
			break
	var kind := str(selected.get("kind", "dwell"))
	var from_node_id := str(selected.get("from_node_id", selected.get("node_id", "")))
	var to_node_id := str(selected.get("to_node_id", from_node_id))
	var start_progress := float(selected.get("start_progress", 0.0))
	var end_progress := float(selected.get("end_progress", start_progress))
	var amount := 0.0
	if kind == "travel":
		amount = clampf((replay_progress - start_progress) / maxf(0.0001, end_progress - start_progress), 0.0, 1.0)
	var label := str(selected.get("from_label", from_node_id.replace("_", " ").capitalize()))
	if kind == "travel" and amount >= 1.0:
		label = str(selected.get("to_label", to_node_id.replace("_", " ").capitalize()))
	return {"progress": replay_progress, "segment_count": replay_segments.size(), "kind": kind, "node_id": from_node_id if kind == "dwell" else "", "from_node_id": from_node_id, "to_node_id": to_node_id, "amount": amount, "label": label, "leg_index": int(selected.get("leg_index", 0))}


func _travel_segment_for_leg(leg_index: int) -> Dictionary:
	for segment_value in replay_segments:
		if typeof(segment_value) != TYPE_DICTIONARY:
			continue
		var segment: Dictionary = segment_value
		if str(segment.get("kind", "")) == "travel" and int(segment.get("leg_index", -1)) == leg_index:
			return segment
	return {}


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
		if travel_target:
			var status_color := Color("#5df2a2", alpha)
			if bool(node.get("closing_soon", false)):
				status_color = Color("#ffd36a", alpha)
			elif not bool(node.get("open_now", true)):
				status_color = Color("#f26d7d", alpha)
			draw_circle(pos + Vector2(radius - 2.0, -radius + 2.0), 4.0, status_color)

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
			var node: Dictionary = node_value
			_texture_for_node(node)


func _ensure_layout_cache() -> void:
	if cached_layout_size != size:
		_rebuild_layout_cache()


func _rebuild_layout_cache() -> void:
	var next_basis_signature := _map_view_basis_signature()
	var next_selected_node_id := str(snapshot.get("selected_node_id", "")).strip_edges()
	if next_selected_node_id.is_empty():
		map_view_selected_node_id_cache = ""
		map_view_focus_node_ids_cache = []
	elif next_basis_signature != map_view_basis_signature or map_view_selected_node_id_cache != next_selected_node_id:
		map_view_basis_signature = next_basis_signature
		map_view_focus_node_ids_cache = _string_array(snapshot.get("map_focus_node_ids", []))
		map_view_selected_node_id_cache = next_selected_node_id
		stable_layout_size = _current_or_default_layout_size()
	var next_bounds_signature := _map_view_bounds_signature(next_basis_signature)
	if next_bounds_signature != map_view_bounds_signature:
		var first_bounds := map_view_bounds_signature.is_empty()
		target_map_view_bounds_cache = _compute_map_view_bounds()
		if first_bounds:
			map_view_bounds_cache = target_map_view_bounds_cache
		map_view_bounds_signature = next_bounds_signature
	cached_layout_size = size
	_rebuild_node_screen_position_cache()


func _rebuild_node_screen_position_cache() -> void:
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
	var layout_size := _stable_layout_size()
	var drawable := Vector2(maxf(1.0, layout_size.x - inset.x * 2.0), maxf(1.0, layout_size.y - inset.y * 2.0))
	var bounds := map_view_bounds_cache
	var x := clampf(float(position.get("x", 0.5)), 0.0, 1.0)
	var y := clampf(float(position.get("y", 0.5)), 0.0, 1.0)
	var local_x := (x - bounds.position.x) / maxf(0.001, bounds.size.x)
	var local_y := (y - bounds.position.y) / maxf(0.001, bounds.size.y)
	return inset + Vector2(local_x, local_y) * drawable


func _compute_map_view_bounds() -> Rect2:
	var nodes := _bounds_focus_nodes(map_view_focus_node_ids_cache)
	if nodes.is_empty():
		return _full_map_view_bounds()
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
	var aspect := _normalized_view_aspect()
	if width / height < aspect:
		width = height * aspect
	else:
		height = width / aspect
	var fit_scale := minf(1.0, minf(1.0 / maxf(0.001, width), 1.0 / maxf(0.001, height)))
	width *= fit_scale
	height *= fit_scale
	var x0 := clampf(center.x - width * 0.5, 0.0, 1.0 - width)
	var y0 := clampf(center.y - height * 0.5, 0.0, 1.0 - height)
	var base_bounds := Rect2(Vector2(x0, y0), Vector2(width, height))
	return _selected_focus_bounds(base_bounds)


func _selected_focus_bounds(base_bounds: Rect2) -> Rect2:
	if not _selected_focus_zoom_active():
		return base_bounds
	var node: Dictionary = nodes_by_id_cache.get(map_view_selected_node_id_cache, {})
	var position_value: Variant = node.get("position", {})
	var position: Dictionary = {}
	if typeof(position_value) == TYPE_DICTIONARY:
		position = position_value as Dictionary
	var focus := Vector2(
		clampf(float(position.get("x", base_bounds.get_center().x)), 0.0, 1.0),
		clampf(float(position.get("y", base_bounds.get_center().y)), 0.0, 1.0)
	)
	var minimum_zoom_scale := maxf(0.18 / maxf(0.001, base_bounds.size.x), 0.18 / maxf(0.001, base_bounds.size.y))
	var zoom_scale := clampf(maxf(SELECTED_FOCUS_ZOOM, minimum_zoom_scale), 0.0, 1.0)
	var zoom_size := base_bounds.size * zoom_scale
	var blend := 0.42
	var center := base_bounds.get_center().lerp(focus, blend)
	var x0 := clampf(center.x - zoom_size.x * 0.5, 0.0, 1.0 - zoom_size.x)
	var y0 := clampf(center.y - zoom_size.y * 0.5, 0.0, 1.0 - zoom_size.y)
	return Rect2(Vector2(x0, y0), zoom_size)


func _full_map_view_bounds() -> Rect2:
	var aspect := _normalized_view_aspect()
	var bounds_size := Vector2.ONE
	if aspect >= 1.0:
		bounds_size.y = 1.0 / aspect
	else:
		bounds_size.x = aspect
	return Rect2((Vector2.ONE - bounds_size) * 0.5, bounds_size)


func _normalized_view_aspect() -> float:
	var layout_size := _stable_layout_size()
	var destination_aspect := layout_size.x / maxf(1.0, layout_size.y)
	var texture := _background_texture()
	if texture == null:
		return destination_aspect
	var texture_size := texture.get_size()
	var texture_aspect := texture_size.x / maxf(1.0, texture_size.y)
	return destination_aspect / maxf(0.001, texture_aspect)


func _selected_focus_zoom_active() -> bool:
	return not map_view_selected_node_id_cache.is_empty() and nodes_by_id_cache.has(map_view_selected_node_id_cache)


func _bounds_lerp_weight(delta: float) -> float:
	if delta <= 0.0:
		return 0.0
	return clampf(1.0 - exp(-SELECTED_FOCUS_LERP_SPEED * delta), 0.0, 1.0)


func _lerp_map_bounds(from_bounds: Rect2, to_bounds: Rect2, weight: float) -> Rect2:
	return Rect2(
		from_bounds.position.lerp(to_bounds.position, weight),
		from_bounds.size.lerp(to_bounds.size, weight)
	)


func _map_bounds_equal(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_squared_to(b.position) <= MAP_BOUNDS_SNAP_EPSILON * MAP_BOUNDS_SNAP_EPSILON and a.size.distance_squared_to(b.size) <= MAP_BOUNDS_SNAP_EPSILON * MAP_BOUNDS_SNAP_EPSILON


func _map_view_bounds_signature(basis_signature: String) -> String:
	var parts: Array[String] = [
		"%.2f" % _stable_layout_size().x,
		"%.2f" % _stable_layout_size().y,
		basis_signature,
		",".join(map_view_focus_node_ids_cache),
		map_view_selected_node_id_cache,
	]
	return "|".join(parts)


func _stable_layout_size() -> Vector2:
	if stable_layout_size.x <= 0.0 or stable_layout_size.y <= 0.0:
		stable_layout_size = _current_or_default_layout_size()
	return stable_layout_size


func _current_or_default_layout_size() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	return Vector2(540.0, 390.0)


func _map_view_basis_signature() -> String:
	var parts: Array[String] = []
	var node_ids := _sorted_string_keys(nodes_by_id_cache)
	for node_id in node_ids:
		var node: Dictionary = nodes_by_id_cache.get(node_id, {})
		var position: Dictionary = node.get("position", {}) if typeof(node.get("position", {})) == TYPE_DICTIONARY else {}
		parts.append("%s:%.5f:%.5f:%s" % [
			node_id,
			clampf(float(position.get("x", 0.5)), 0.0, 1.0),
			clampf(float(position.get("y", 0.5)), 0.0, 1.0),
			str(node.get("state", "")),
		])
	return "|".join(parts)


func _bounds_focus_nodes(focus_ids: Array) -> Array:
	var nodes := _array_view(snapshot.get("nodes", []))
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


func _sorted_string_keys(values: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key_value in values.keys():
		var key := str(key_value)
		if not key.is_empty():
			keys.append(key)
	keys.sort()
	return keys


func _point_in_view(point: Vector2, margin: float = 0.0) -> bool:
	var layout_size := _stable_layout_size()
	return point.x >= -margin and point.y >= -margin and point.x <= layout_size.x + margin and point.y <= layout_size.y + margin


func _segment_in_view(a: Vector2, b: Vector2) -> bool:
	if _point_in_view(a) or _point_in_view(b):
		return true
	var min_x := minf(a.x, b.x)
	var max_x := maxf(a.x, b.x)
	var min_y := minf(a.y, b.y)
	var max_y := maxf(a.y, b.y)
	var layout_size := _stable_layout_size()
	return max_x >= 0.0 and min_x <= layout_size.x and max_y >= 0.0 and min_y <= layout_size.y


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
	var texture := _texture_for_path(path)
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
	var texture := _texture_for_path(path)
	icon_texture_cache[path] = texture
	return texture


func _prewarm_map_icon_directory() -> void:
	var directory := DirAccess.open(MAP_ICON_DIR)
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".png"):
			var path := "%s/%s" % [MAP_ICON_DIR, file_name]
			if not icon_texture_cache.has(path):
				icon_texture_cache[path] = _texture_for_path(path)
		file_name = directory.get_next()
	directory.list_dir_end()


func _texture_for_path(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		var image := Image.new()
		if image.load(path) != OK:
			return null
		return ImageTexture.create_from_image(image)
	return ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D


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
