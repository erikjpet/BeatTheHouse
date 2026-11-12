extends Control

# Presentation only. The caller owns time, actor placement and the source crop.
# Every polygon UV is relative to the FULL exterior PNG, never the cropped view.
# Two instances surround the actor: the back owns the aperture, and the front
# owns the actual textured door/frame only after the actor crosses the threshold.
const EPS := 0.000001
const MAX_ANGLE := 80.0
const INTERIOR := Color("#15121b")

var _white_polygon_colors := PackedColorArray([Color.WHITE])
var _texture: Texture2D
var _interior_texture: Texture2D
var _interior_source_uv := Rect2(Vector2.ZERO, Vector2.ONE)
var _configured := false
var _front := false
var _kind := ""
var _hinge_side := ""
var _polygon := PackedVector2Array()
var _bounds := Rect2()
var _triangles: Array[PackedVector2Array] = []
var _frame_polygons: Array[PackedVector2Array] = []
var _leaves: Array[Dictionary] = []
var _draw_plan: Dictionary = {}


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


func configure(texture: Texture2D, exterior_contract: Dictionary, front_layer: bool = false, interior_texture: Texture2D = null) -> void:
	_configured = false
	visible = false
	_texture = null
	_interior_texture = null
	_front = front_layer
	_polygon.clear()
	_triangles.clear()
	_frame_polygons.clear()
	_leaves.clear()
	_draw_plan.clear()
	queue_redraw()
	# Open streets, passages and docks must not acquire a made-up doorway.
	if texture == null or exterior_contract.get("arrival_kind") != "door": return
	if not exterior_contract.get("texture") is String or not exterior_contract["texture"].begins_with("res://"): return
	if not _number_pair(exterior_contract.get("reference_size")): return
	var reference := _pair(exterior_contract["reference_size"])
	if reference != Vector2(texture.get_width(), texture.get_height()) or reference.x <= 0.0 or reference.y <= 0.0: return
	_kind = str(exterior_contract.get("door_kind", ""))
	_hinge_side = str(exterior_contract.get("hinge_side", ""))
	if _kind not in ["hinged", "double_hinged"] or _hinge_side not in ["left", "right"]: return
	for key in ["threshold_uv", "inside_uv"]:
		if not _number_pair(exterior_contract.get(key)) or not _unit_point(_pair(exterior_contract[key])): return
	if not _unit_number(exterior_contract.get("road_y_uv")): return
	if exterior_contract.has("source_top_y_uv") and not _unit_number(exterior_contract["source_top_y_uv"]): return
	_polygon = _validated_polygon(exterior_contract.get("door_polygon_uv"))
	if _polygon.is_empty(): return
	_bounds = _polygon_bounds(_polygon)
	_triangles = _triangulate(_polygon)
	if _triangles.is_empty(): return
	_frame_polygons = _frame_strips(_polygon, reference)
	if _kind == "double_hinged":
		var middle := _bounds.get_center().x
		_leaves.append({"hinge_x": _bounds.position.x, "left": true, "split_x": middle})
		_leaves.append({"hinge_x": _bounds.end.x, "left": false, "split_x": middle})
	else:
		_leaves.append({"hinge_x": _bounds.position.x if _hinge_side == "left" else _bounds.end.x})
	_texture = texture
	_interior_texture = interior_texture
	if _interior_texture != null and exterior_contract.has("doorway_reference_size"):
		if not _number_pair(exterior_contract["doorway_reference_size"]) or _pair(exterior_contract["doorway_reference_size"]) != Vector2(_interior_texture.get_width(), _interior_texture.get_height()):
			_texture = null
			_interior_texture = null
			return
	_interior_source_uv = Rect2(Vector2.ZERO, Vector2.ONE)
	if _interior_texture != null:
		# Cover the actual opening without stretching the room. Align the image
		# bottom to the sill so its entry floor stays under the actor's feet.
		var portal_aspect := _bounds.size.x * reference.x / (_bounds.size.y * reference.y)
		var interior_aspect := float(_interior_texture.get_width()) / maxf(1.0, _interior_texture.get_height())
		if interior_aspect > portal_aspect:
			_interior_source_uv.size.x = portal_aspect / interior_aspect
			_interior_source_uv.position.x = (1.0 - _interior_source_uv.size.x) * 0.5
		else:
			_interior_source_uv.size.y = interior_aspect / portal_aspect
			_interior_source_uv.position.y = 1.0 - _interior_source_uv.size.y
	_configured = true


func set_frame(source_window_uv: Rect2, opening: float, player_inside: bool, shown: bool) -> void:
	_draw_plan.clear()
	visible = shown and _configured and _unit_rect(source_window_uv) and is_finite(opening)
	visible = visible and size.is_finite() and size.x > 0.0 and size.y > 0.0
	if not visible:
		queue_redraw()
		return
	var amount := clampf(opening, 0.0, 1.0)
	var aperture := _map_polygon(_polygon, source_window_uv)
	var interior_uvs := PackedVector2Array()
	for point in _polygon:
		interior_uvs.append(_interior_source_uv.position + (point - _bounds.position) / _bounds.size * _interior_source_uv.size)
	var portal := _polygon_bounds(aperture).intersection(Rect2(Vector2.ZERO, size))
	var panels: Array[Dictionary] = []
	var frames: Array[Dictionary] = []
	var owns_panels := player_inside == _front
	# At closed/outside the underlying exterior is untouched, pixel for pixel.
	# At closed/inside the front must restore the door to occlude the actor.
	if owns_panels and (amount > 0.0 or player_inside):
		if amount == 0.0:
			panels.append({"hinge_x_uv": _leaves[0]["hinge_x"], "angle_radians": 0.0,
				"fragments": [{"points": aperture, "uvs": _polygon.duplicate()}]})
		else:
			for leaf in _leaves:
				panels.append(_leaf_plan(leaf, source_window_uv, amount))
	if _front and player_inside:
		for polygon in _frame_polygons:
			frames.append({"points": _map_polygon(polygon, source_window_uv), "uvs": polygon.duplicate()})
	_draw_plan = {"source_window_uv": source_window_uv, "stage_rect": Rect2(Vector2.ZERO, size),
		"portal_rect": portal, "aperture": aperture, "aperture_uvs": _polygon.duplicate(),
		"draw_interior": not _front and (amount > 0.0 or player_inside), "interior_color": INTERIOR,
		"interior_texture_path": _interior_texture.resource_path if _interior_texture != null else "",
		"interior_source_uv": _interior_source_uv, "interior_uvs": interior_uvs,
		"panels": panels, "frame_strips": frames, "opening": amount, "player_inside": player_inside,
		"front_layer": _front, "door_kind": _kind, "clip_contents": clip_contents}
	queue_redraw()


func is_configured() -> bool:
	return _configured


func portal_rect() -> Rect2:
	return _draw_plan.get("portal_rect", Rect2())


func draw_snapshot() -> Dictionary:
	# This plan is consumed below, not a parallel test-only reconstruction.
	return _draw_plan.duplicate(true)


func _draw() -> void:
	if _draw_plan.is_empty() or _texture == null: return
	if _draw_plan["draw_interior"]:
		if _interior_texture != null:
			draw_polygon(_draw_plan["aperture"], _white_polygon_colors, _draw_plan["interior_uvs"], _interior_texture)
		else:
			draw_colored_polygon(_draw_plan["aperture"], _draw_plan["interior_color"])
	for panel in _draw_plan["panels"]:
		for fragment in panel["fragments"]:
			draw_polygon(fragment["points"], _white_polygon_colors, fragment["uvs"], _texture)
	for strip in _draw_plan["frame_strips"]:
		draw_polygon(strip["points"], _white_polygon_colors, strip["uvs"], _texture)


func _leaf_plan(leaf: Dictionary, window: Rect2, opening: float) -> Dictionary:
	var radians := deg_to_rad(MAX_ANGLE) * opening
	var hinge := float(leaf["hinge_x"])
	var width := _bounds.size.x * (0.5 if _kind == "double_hinged" else 1.0)
	var fragments: Array[Dictionary] = []
	for triangle in _triangles:
		var source := triangle
		if leaf.has("split_x"):
			source = _split_at_x(source, leaf["split_x"], leaf["left"])
		if source.size() < 3 or absf(_signed_area(source)) < EPS: continue
		var projected := PackedVector2Array()
		for uv in source:
			var fraction := absf(uv.x - hinge) / maxf(width, EPS)
			# A restrained perspective depth retains the facade's measured silhouette.
			projected.append(Vector2(hinge + (uv.x - hinge) * cos(radians),
				uv.y + _bounds.size.y * 0.025 * sin(radians) * fraction))
		# Clip transformed textured triangles to the original aperture. This keeps
		# a stepped door from painting across the jamb or neighboring wall.
		for aperture_triangle in _triangles:
			var clipped := _clip_textured(projected, source, aperture_triangle)
			if clipped["points"].size() >= 3 and absf(_signed_area(clipped["points"])) > EPS:
				fragments.append({"points": _map_polygon(clipped["points"], window), "uvs": clipped["uvs"]})
	return {"hinge_x_uv": hinge, "angle_radians": radians, "fragments": fragments}


func _clip_textured(points: PackedVector2Array, uvs: PackedVector2Array, boundary: PackedVector2Array) -> Dictionary:
	var result_points := points.duplicate()
	var result_uvs := uvs.duplicate()
	var winding := 1.0 if _signed_area(boundary) > 0.0 else -1.0
	for index in boundary.size():
		if result_points.is_empty(): break
		var a := boundary[index]
		var b := boundary[(index + 1) % boundary.size()]
		var next_points := PackedVector2Array()
		var next_uvs := PackedVector2Array()
		var previous := result_points.size() - 1
		for current in result_points.size():
			var previous_distance := (b - a).cross(result_points[previous] - a) * winding
			var current_distance := (b - a).cross(result_points[current] - a) * winding
			var previous_inside := previous_distance >= -EPS * 0.01
			var current_inside := current_distance >= -EPS * 0.01
			if previous_inside != current_inside:
				var weight := previous_distance / (previous_distance - current_distance)
				next_points.append(result_points[previous].lerp(result_points[current], weight))
				next_uvs.append(result_uvs[previous].lerp(result_uvs[current], weight))
			if current_inside:
				next_points.append(result_points[current])
				next_uvs.append(result_uvs[current])
			previous = current
		result_points = next_points
		result_uvs = next_uvs
	return {"points": result_points, "uvs": result_uvs}


func _split_at_x(polygon: PackedVector2Array, x: float, keep_left: bool) -> PackedVector2Array:
	var bounds := PackedVector2Array([Vector2(0.0 if keep_left else x, 0.0), Vector2(x if keep_left else 1.0, 0.0),
		Vector2(x if keep_left else 1.0, 1.0), Vector2(0.0 if keep_left else x, 1.0)])
	return _clip_textured(polygon, polygon, bounds)["points"]


func _frame_strips(polygon: PackedVector2Array, reference: Vector2) -> Array[PackedVector2Array]:
	# Scanline bands build the source-textured complement, including concave step
	# corners inside the actor's rectangular clip. No hole triangulation or tinted
	# replacement wall is needed. The two-source-pixel rim also covers raster seams.
	var margin := Vector2(2.0, 2.0) / reference
	var outer := Rect2((_bounds.position - margin).clamp(Vector2.ZERO, Vector2.ONE), Vector2.ZERO)
	outer.end = (_bounds.end + margin).clamp(Vector2.ZERO, Vector2.ONE)
	var rows: Array[float] = [outer.position.y, outer.end.y]
	for point in polygon:
		if not rows.has(point.y): rows.append(point.y)
	rows.sort()
	var strips: Array[PackedVector2Array] = []
	for row in range(rows.size() - 1):
		var y0 := rows[row]
		var y1 := rows[row + 1]
		if y1 - y0 <= EPS: continue
		var middle := (y0 + y1) * 0.5
		var crossings: Array[Dictionary] = []
		for index in polygon.size():
			var a := polygon[index]
			var b := polygon[(index + 1) % polygon.size()]
			if middle > minf(a.y, b.y) and middle < maxf(a.y, b.y):
				crossings.append({"x": _edge_x(a, b, middle), "top": _edge_x(a, b, y0), "bottom": _edge_x(a, b, y1)})
		crossings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["x"] < b["x"])
		var left_top := outer.position.x
		var left_bottom := outer.position.x
		for index in range(0, crossings.size(), 2):
			_append_strip(strips, left_top, left_bottom, crossings[index]["top"], crossings[index]["bottom"], y0, y1)
			left_top = crossings[index + 1]["top"]
			left_bottom = crossings[index + 1]["bottom"]
		_append_strip(strips, left_top, left_bottom, outer.end.x, outer.end.x, y0, y1)
	return strips


func _append_strip(strips: Array[PackedVector2Array], left_top: float, left_bottom: float, right_top: float, right_bottom: float, y0: float, y1: float) -> void:
	var polygon := PackedVector2Array([Vector2(left_top, y0), Vector2(right_top, y0), Vector2(right_bottom, y1), Vector2(left_bottom, y1)])
	if absf(_signed_area(polygon)) > EPS:
		# Degenerate corners at a sloped aperture's extremum are harmless after
		# triangulation, but draw_polygon requires distinct adjacent vertices.
		var clean := PackedVector2Array()
		for point in polygon:
			if clean.is_empty() or not point.is_equal_approx(clean[-1]): clean.append(point)
		if clean.size() > 1 and clean[0].is_equal_approx(clean[-1]): clean.remove_at(clean.size() - 1)
		if clean.size() >= 3: strips.append(clean)


func _edge_x(a: Vector2, b: Vector2, y: float) -> float:
	return lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))


func _map_polygon(polygon: PackedVector2Array, window: Rect2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in polygon: result.append((point - window.position) / window.size * size)
	return result


func _triangulate(polygon: PackedVector2Array) -> Array[PackedVector2Array]:
	var indices := Geometry2D.triangulate_polygon(polygon)
	var triangles: Array[PackedVector2Array] = []
	for index in range(0, indices.size(), 3):
		triangles.append(PackedVector2Array([polygon[indices[index]], polygon[indices[index + 1]], polygon[indices[index + 2]]]))
	return triangles


func _validated_polygon(value: Variant) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	if not value is Array or value.size() < 3 or value.size() > 32: return polygon
	for entry in value:
		if not _number_pair(entry) or not _unit_point(_pair(entry)): return PackedVector2Array()
		var point := _pair(entry)
		for previous in polygon:
			if point.is_equal_approx(previous): return PackedVector2Array()
		polygon.append(point)
	if absf(_signed_area(polygon)) <= EPS: return PackedVector2Array()
	for first in polygon.size():
		var a := polygon[first]
		var b := polygon[(first + 1) % polygon.size()]
		for second in range(first + 1, polygon.size()):
			if second == first + 1 or (first == 0 and second == polygon.size() - 1): continue
			var c := polygon[second]
			var d := polygon[(second + 1) % polygon.size()]
			if _segments_touch(a, b, c, d): return PackedVector2Array()
	return polygon if not Geometry2D.triangulate_polygon(polygon).is_empty() else PackedVector2Array()


func _segments_touch(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	if Geometry2D.segment_intersects_segment(a, b, c, d) != null: return true
	for point in [c, d]:
		if absf((b - a).cross(point - a)) <= EPS and (point - a).dot(point - b) <= EPS: return true
	for point in [a, b]:
		if absf((d - c).cross(point - c)) <= EPS and (point - c).dot(point - d) <= EPS: return true
	return false


func _signed_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in polygon.size(): area += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return area * 0.5


func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	var rect := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon: rect = rect.expand(point)
	return rect


func _number_pair(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0]) and _number(value[1])


func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


func _unit_number(value: Variant) -> bool:
	return _number(value) and float(value) >= 0.0 and float(value) <= 1.0


func _pair(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


func _unit_point(point: Vector2) -> bool:
	return point.is_finite() and point.x >= 0.0 and point.x <= 1.0 and point.y >= 0.0 and point.y <= 1.0


func _unit_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite() and rect.size.x > 0.0 and rect.size.y > 0.0 and Rect2(Vector2.ZERO, Vector2(1.0, 1.30)).encloses(rect)
