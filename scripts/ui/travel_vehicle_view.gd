extends Control

# Presentation-only, deterministic layers. The parent supplies traveled-distance
# wheel rotation and suspension motion; this view owns no clock or gameplay state.
# Wheel centers/radii are UVs within source_rect, not within the entire PNG.
const WHEEL_SEGMENTS := 48
const MAX_BOB_HEIGHT_RATIO := 0.012
const LUG_COLOR := Color(0.66, 0.40, 0.78, 0.72)

var _white_polygon_colors := PackedColorArray([Color.WHITE])
var _texture: Texture2D
var _interior_texture: Texture2D
var _interior_bounds := Rect2()
var _interior_source_uv := Rect2(Vector2.ZERO, Vector2.ONE)
var _source := Rect2()
var _door_uv := Rect2()
var _wheels: Array[Dictionary] = []
var _door_animation: Dictionary = {}
var _configured := false
var _draw_plan: Dictionary = {}


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


func configure(texture: Texture2D, source_rect: Rect2, door_rect_uv: Rect2, wheel_contract: Array, door_animation: Dictionary = {}, interior_texture: Texture2D = null) -> void:
	_texture = texture
	_interior_texture = interior_texture
	_source = source_rect
	_door_uv = door_rect_uv
	_wheels.clear()
	_door_animation.clear()
	_draw_plan.clear()
	_configured = false
	visible = false
	if texture == null or not _finite_rect(source_rect) or not source_rect.has_area():
		queue_redraw()
		return
	var native := Vector2(texture.get_width(), texture.get_height())
	if not Rect2(Vector2.ZERO, native).encloses(source_rect) or not _unit_rect(door_rect_uv) or wheel_contract.size() != 2:
		queue_redraw()
		return
	for entry in wheel_contract:
		if not entry is Dictionary or not _number_pair(entry.get("center_uv")) or not _number_pair(entry.get("radius_uv")):
			_wheels.clear()
			queue_redraw()
			return
		var center := Vector2(float(entry["center_uv"][0]), float(entry["center_uv"][1]))
		var radius := Vector2(float(entry["radius_uv"][0]), float(entry["radius_uv"][1]))
		if not _unit_rect(Rect2(center - radius, radius * 2.0)):
			_wheels.clear()
			queue_redraw()
			return
		_wheels.append({"center_uv": center, "radius_uv": radius})
	_door_animation = _validated_door_animation(door_animation)
	if _door_animation.is_empty():
		_door_animation = _fallback_door_animation()
	var aperture: PackedVector2Array = _door_animation["aperture_polygon_uv"]
	_interior_bounds = Rect2(aperture[0], Vector2.ZERO)
	for point in aperture:
		_interior_bounds = _interior_bounds.expand(point)
	_interior_source_uv = Rect2(Vector2.ZERO, Vector2.ONE)
	if _interior_texture != null:
		var aperture_aspect := _interior_bounds.size.x * _source.size.x / (_interior_bounds.size.y * _source.size.y)
		var interior_aspect := float(_interior_texture.get_width()) / maxf(1.0, _interior_texture.get_height())
		if interior_aspect > aperture_aspect:
			_interior_source_uv.size.x = aperture_aspect / interior_aspect
			_interior_source_uv.position.x = (1.0 - _interior_source_uv.size.x) * 0.5
		else:
			_interior_source_uv.size.y = interior_aspect / aperture_aspect
			_interior_source_uv.position.y = 1.0 - _interior_source_uv.size.y
	_configured = true
	queue_redraw()


func set_frame(target_rect: Rect2, wheel_angle: float, body_bob: float, door_open: float, shown: bool) -> void:
	_draw_plan.clear()
	visible = shown and _configured and _finite_rect(target_rect) and target_rect.has_area()
	visible = visible and is_finite(wheel_angle) and is_finite(body_bob) and is_finite(door_open)
	if not visible:
		queue_redraw()
		return
	var angle := fposmod(wheel_angle, TAU)
	var bob_limit := target_rect.size.y * MAX_BOB_HEIGHT_RATIO
	var bob := clampf(body_bob, -bob_limit, bob_limit)
	var body := Rect2(target_rect.position + Vector2(0.0, bob), target_rect.size)
	var wheel_draws: Array[Dictionary] = []
	for wheel in _wheels:
		wheel_draws.append(_wheel_plan(target_rect, wheel, angle))
	var opening := clampf(door_open, 0.0, 1.0)
	var door := Rect2(body.position + body.size * _door_uv.position, body.size * _door_uv.size * Vector2(opening, 1.0))
	_draw_plan = {"body_rect": body, "body_source": _source, "body_bob": bob,
		"wheels": wheel_draws, "wheel_angle": angle, "door_rect": door,
		"door_inner_rect": door.grow(-minf(3.0, target_rect.size.y * 0.018)), "door_open": opening}
	_draw_plan.merge(_door_plan(body, opening))
	queue_redraw()


func _wheel_plan(target: Rect2, wheel: Dictionary, angle: float) -> Dictionary:
	var center_uv: Vector2 = wheel["center_uv"]
	var radius_uv: Vector2 = wheel["radius_uv"]
	var center := target.position + target.size * center_uv
	var radius := target.size * radius_uv
	var source_center := _source.position + _source.size * center_uv
	var source_radius := _source.size * radius_uv
	var native := Vector2(_texture.get_width(), _texture.get_height())
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for index in range(WHEEL_SEGMENTS):
		var theta := TAU * float(index) / WHEEL_SEGMENTS
		points.append(center + Vector2.from_angle(theta) * radius)
		# Fixed circular geometry, inverse-rotated source UVs. This rotates actual
		# tire/rim pixels without dragging the wheel arch or square crop corners.
		uvs.append((source_center + Vector2.from_angle(theta - angle) * source_radius) / native)
	var lugs: Array[PackedVector2Array] = []
	for index in range(3):
		var theta := angle + TAU * float(index) / 3.0
		var lug := PackedVector2Array()
		for corner in [Vector2(0.26, -0.045), Vector2(0.42, -0.045), Vector2(0.42, 0.045), Vector2(0.26, 0.045)]:
			lug.append(center + corner.rotated(theta) * radius)
		lugs.append(lug)
	return {"center": center, "radius": radius, "points": points, "uvs": uvs, "lugs": lugs}


func _draw() -> void:
	if _draw_plan.is_empty() or _texture == null:
		return
	draw_texture_rect_region(_texture, _draw_plan["body_rect"], _draw_plan["body_source"])
	for wheel in _draw_plan["wheels"]:
		draw_polygon(wheel["points"], _white_polygon_colors, wheel["uvs"], _texture)
		for lug in wheel["lugs"]:
			draw_colored_polygon(lug, LUG_COLOR)
	# The original closed sprite is exact. While opening, replace only the
	# measured door silhouette with its interior and hinge the actual PNG pixels.
	if bool(_draw_plan["door_active"]):
		if _interior_texture != null:
			draw_polygon(_draw_plan["door_aperture"], _white_polygon_colors, _draw_plan["door_interior_uvs"], _interior_texture)
		else:
			draw_colored_polygon(_draw_plan["door_aperture"], _draw_plan["door_interior_color"])
			draw_colored_polygon(_draw_plan["door_step"], _draw_plan["door_step_color"])
		for panel in _draw_plan["door_panels"]:
			draw_polygon(panel["points"], panel["colors"], panel["uvs"], _texture)
			draw_polyline(panel["outline"], _draw_plan["door_edge_color"], _draw_plan["door_edge_width"])


func _door_plan(body: Rect2, opening: float) -> Dictionary:
	var panels: Array[Dictionary] = []
	var interior_uvs := PackedVector2Array()
	for point in _door_animation["aperture_polygon_uv"]:
		interior_uvs.append(_interior_source_uv.position + (point - _interior_bounds.position) / _interior_bounds.size * _interior_source_uv.size)
	var native := Vector2(_texture.get_width(), _texture.get_height())
	for panel: Dictionary in _door_animation["panels"]:
		var polygon: PackedVector2Array = panel["polygon_uv"]
		var hinge: PackedVector2Array = panel["hinge_uv"]
		var radians := deg_to_rad(float(panel["max_angle_degrees"])) * opening
		var width := 0.00001
		for point in polygon:
			width = maxf(width, absf(point.x - hinge[0].x))
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		for point in polygon:
			var distance := point.x - hinge[0].x
			var projected := Vector2(hinge[0].x + distance * cos(radians), point.y)
			projected += panel["depth_uv"] * sin(radians) * absf(distance) / width
			points.append(body.position + body.size * projected)
			uvs.append((_source.position + _source.size * point) / native)
		var outline := points.duplicate()
		outline.append(points[0])
		var tint := Color.WHITE.lerp(Color(0.65, 0.67, 0.76), sin(radians) * 0.40)
		panels.append({"points": points, "uvs": uvs, "outline": outline,
			"hinge": _map_polygon(hinge, body), "angle_radians": radians,
			"tint": tint, "colors": PackedColorArray([tint])})
	return {"door_active": opening > 0.0, "door_kind": _door_animation["kind"],
		"door_aperture": _map_polygon(_door_animation["aperture_polygon_uv"], body),
		"door_step": _map_polygon(_door_animation["step_polygon_uv"], body),
		"door_interior_color": _door_animation["interior_color"],
		"door_interior_texture_path": _interior_texture.resource_path if _interior_texture != null else "",
		"door_interior_uvs": interior_uvs, "door_interior_source_uv": _interior_source_uv,
		"door_step_color": _door_animation["step_color"],
		"door_edge_color": _door_animation["edge_color"],
		"door_edge_width": maxf(1.0, body.size.y * 0.003), "door_panels": panels}


func _map_polygon(polygon: PackedVector2Array, body: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in polygon:
		points.append(body.position + body.size * point)
	return points


func _validated_door_animation(value: Dictionary) -> Dictionary:
	var kind := str(value.get("kind", ""))
	if not kind in ["bus_fold", "hinged"]:
		return {}
	var aperture := _unit_polygon(value.get("aperture_polygon_uv"))
	var step := _unit_polygon(value.get("step_polygon_uv"))
	var source_panels: Variant = value.get("panels")
	if aperture.is_empty() or step.is_empty() or not source_panels is Array:
		return {}
	if source_panels.size() != (2 if kind == "bus_fold" else 1):
		return {}
	var panels: Array[Dictionary] = []
	for entry in source_panels:
		if not entry is Dictionary:
			return {}
		var polygon := _unit_polygon(entry.get("polygon_uv"))
		var axis: Variant = entry.get("hinge_uv")
		var degrees: Variant = entry.get("max_angle_degrees")
		if polygon.is_empty() or not axis is Array or axis.size() != 2 or not _number_pair(axis[0]) or not _number_pair(axis[1]):
			return {}
		var hinge := PackedVector2Array([Vector2(axis[0][0], axis[0][1]), Vector2(axis[1][0], axis[1][1])])
		if not _unit_point(hinge[0]) or not _unit_point(hinge[1]) or not is_equal_approx(hinge[0].x, hinge[1].x) or hinge[1].y <= hinge[0].y:
			return {}
		if not (degrees is float or degrees is int) or not is_finite(float(degrees)) or float(degrees) <= 0.0 or float(degrees) > 85.0:
			return {}
		if not _number_pair(entry.get("depth_uv")):
			return {}
		var depth := Vector2(entry["depth_uv"][0], entry["depth_uv"][1])
		if absf(depth.x) > 0.05 or absf(depth.y) > 0.08:
			return {}
		panels.append({"polygon_uv": polygon, "hinge_uv": hinge,
			"max_angle_degrees": float(degrees), "depth_uv": depth})
	for key in ["interior_color", "step_color", "edge_color"]:
		if not value.get(key) is String or not Color.html_is_valid(value[key]):
			return {}
	return {"kind": kind, "aperture_polygon_uv": aperture, "step_polygon_uv": step,
		"panels": panels, "interior_color": Color(value["interior_color"]),
		"step_color": Color(value["step_color"]), "edge_color": Color(value["edge_color"])}


func _fallback_door_animation() -> Dictionary:
	# Old four-argument callers still hinge their original textured door region.
	# No fabricated bright rectangle, and no assumptions about replacement art.
	var left := _door_uv.position.x
	var right := _door_uv.end.x
	var top := _door_uv.position.y
	var bottom := _door_uv.end.y
	var polygon := PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom)])
	return {"kind": "texture_hinge_fallback", "aperture_polygon_uv": polygon,
		"step_polygon_uv": PackedVector2Array([Vector2(left, bottom - _door_uv.size.y * 0.04), Vector2(right, bottom - _door_uv.size.y * 0.04), Vector2(right, bottom), Vector2(left, bottom)]),
		"interior_color": Color("#12101f"), "step_color": Color("#494052"), "edge_color": Color("#120d23"),
		"panels": [{"polygon_uv": polygon, "hinge_uv": PackedVector2Array([Vector2(right, top), Vector2(right, bottom)]),
			"max_angle_degrees": 72.0, "depth_uv": Vector2(0.0, 0.012)}]}


func _unit_polygon(value: Variant) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	if not value is Array or value.size() < 3 or value.size() > 32:
		return polygon
	for item in value:
		if not _number_pair(item):
			return PackedVector2Array()
		var point := Vector2(float(item[0]), float(item[1]))
		if not _unit_point(point):
			return PackedVector2Array()
		polygon.append(point)
	return polygon if not Geometry2D.triangulate_polygon(polygon).is_empty() else PackedVector2Array()


func _unit_point(point: Vector2) -> bool:
	return point.is_finite() and point.x >= 0.0 and point.x <= 1.0 and point.y >= 0.0 and point.y <= 1.0


func draw_snapshot() -> Dictionary:
	# This is the very plan consumed by _draw, not a parallel test-only model.
	return _draw_plan.duplicate(true)


func is_configured() -> bool:
	return _configured


func _finite_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite()


func _unit_rect(rect: Rect2) -> bool:
	return _finite_rect(rect) and rect.has_area() and Rect2(Vector2.ZERO, Vector2.ONE).encloses(rect)


func _number_pair(value: Variant) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for item in value:
		if not (item is float or item is int) or not is_finite(float(item)):
			return false
	return true
