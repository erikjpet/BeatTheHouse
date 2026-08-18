class_name CoinPusherRenderer
extends RefCounted

const DESIGN_SIZE := Vector2(900, 430)
const RAIL_DRAG_RECT := Rect2(176, 154, 548, 44)
const PLAYFIELD_RECT := Rect2(158, 152, 584, 165)
const SCHEMA_DEFAULT_WIDTH := 100000.0
const SCHEMA_DEFAULT_BACK_Y := 63000.0
const SCHEMA_DEFAULT_COIN_HEIGHT := 1700.0
const REAR_WIDTH_FACTOR := 0.78
const COIN_RX := 17.0
const COIN_RY := 12.0
const Z_LAYER_OFFSET := 11.0
const ELLIPSE_SEGMENTS := 12
const BATCH_CAPACITY := 600
const ATLAS_FRAME_SIZE := Vector2i(40, 32)
const ROTATION_VARIANTS := [-0.12, -0.04, 0.04, 0.12]
const AIRBORNE_SHADOW_OFFSET := Vector2(12, 10)

const NEUTRAL_CABINET := {
	"identity": "generic", "marquee": "COIN PUSHER", "palette": "neutral", "topper_style": "none", "marquee_subline": "",
	"backglass_display": {"style": "none"},
	"body_colors": {"default": "#c9c5b8"}, "body_labels": {},
	"colors": {"body": "#454851", "side": "#252831", "trim": "#b8b4a8", "light": "#f4f1e8", "glass": "#8ba3ad", "deck": "#24343a", "platform": "#77746b", "backglass": "#30343c"},
}

var _coin_texture: Texture2D
var _coin_multimesh: MultiMesh
var _coin_mesh: QuadMesh
var _sorted_body_cache: Array = []
var _sorted_body_cache_key := ""
var _coin_instance_color_cache: Array = []
var _palette_cache_key := ""
var _palette_cache: Dictionary = {}
var _world_width := SCHEMA_DEFAULT_WIDTH
var _world_back_y := SCHEMA_DEFAULT_BACK_Y
var _coin_height := SCHEMA_DEFAULT_COIN_HEIGHT


func draw(surface, state: Dictionary) -> bool:
	if str(state.get("surface_renderer", "")) != "coin_pusher":
		return false
	_ensure_coin_batch()
	_configure_projection(state)
	surface.surface_begin_design_space(DESIGN_SIZE)
	var cabinet := _cabinet(state)
	var colors := _colors(cabinet)
	if bool(state.get("coin_pusher_locked", false)):
		colors = _locked_colors(colors)
	_draw_floor_and_shell(surface, cabinet, colors)
	_draw_backglass(surface, state, cabinet, colors)
	_draw_playfield(surface, state, colors, cabinet)
	_draw_glass(surface, colors)
	_draw_hardware(surface, state, colors)
	surface.surface_end_design_space()
	return true


func render_signature(state: Dictionary) -> Dictionary:
	_configure_projection(state)
	var cabinet := _cabinet(state)
	var bodies: Array = state.get("coin_pusher_bodies", []) if typeof(state.get("coin_pusher_bodies", [])) == TYPE_ARRAY else []
	var airborne := 0
	var stacked := 0
	var riding := 0
	for body_value in bodies:
		if typeof(body_value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = body_value
		airborne += 1 if str(body.get("rest_state", "")) == "falling" else 0
		stacked += 1 if int(body.get("z", 0)) >= int(state.get("coin_pusher_coin_height", 1700)) else 0
		riding += 1 if str(body.get("support_kind", "")) == "platform" else 0
	return {
		"identity": str(cabinet.get("identity", "")),
		"marquee": str(cabinet.get("marquee", "")),
		"palette": str(cabinet.get("palette", "")),
		"topper_style": str(cabinet.get("topper_style", "")),
		"rear_width_factor": REAR_WIDTH_FACTOR,
		"projection_width": _world_width,
		"projection_back_y": _world_back_y,
		"projection_coin_height": _coin_height,
		"coin_rx": COIN_RX,
		"coin_ry": COIN_RY,
		"z_layer_offset": Z_LAYER_OFFSET,
		"rotation_frames": 4,
		"depth_sorted": true,
		"batch_draws": 1,
		"batched_nodes": 0,
		"per_coin_nodes": 0,
		"draw_order": ["shadows", "coin_batch", "feature_labels", "glass", "hardware"],
		"body_count": bodies.size(),
		"airborne_count": airborne,
		"stacked_count": stacked,
		"riding_count": riding,
		"tray_heap_count": int(state.get("coin_pusher_tray_count", 0)),
		"delivery_board": debug_delivery_board_for_test(state),
		"entry_hardware": _entry_hardware_layout(state),
		"airborne_shadow_offset": AIRBORNE_SHADOW_OFFSET,
		"locked_dark": bool(state.get("coin_pusher_locked", false)),
		"hardware_actions": _hardware_actions(state),
		"hardware_catalog": _hardware_catalog(state),
	}


func _locked_colors(colors: Dictionary) -> Dictionary:
	var result := colors.duplicate(false)
	for key in result.keys():
		if result[key] is Color:
			result[key] = (result[key] as Color).darkened(0.78)
	return result


func _draw_floor_and_shell(surface, cabinet: Dictionary, colors: Dictionary) -> void:
	var body: Color = colors["body"]
	var side: Color = colors["side"]
	var trim: Color = colors["trim"]
	var light: Color = colors["light"]
	surface.draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color("#090b12"))
	surface.surface_filled_polygon(PackedVector2Array([Vector2(72, 411), Vector2(828, 411), Vector2(756, 383), Vector2(144, 383)]), Color(0, 0, 0, 0.56)) # SA2_PER_FRAME_OK: bounded authored cabinet geometry under the measured draw budget.
	surface.draw_rect(Rect2(91, 56, 718, 337), body)
	surface.surface_filled_polygon(PackedVector2Array([Vector2(91, 56), Vector2(123, 74), Vector2(123, 393), Vector2(91, 393)]), side.darkened(0.22)) # SA2_PER_FRAME_OK: fixed four-point cabinet side.
	surface.surface_filled_polygon(PackedVector2Array([Vector2(809, 56), Vector2(777, 74), Vector2(777, 393), Vector2(809, 393)]), side.darkened(0.28)) # SA2_PER_FRAME_OK: fixed four-point cabinet side.
	surface.draw_rect(Rect2(108, 72, 684, 304), side)
	surface.draw_rect(Rect2(116, 79, 668, 290), body.darkened(0.08))
	surface.draw_rect(Rect2(91, 56, 718, 337), trim, false, 3.0)
	_draw_topper(surface, str(cabinet.get("topper_style", "none")), trim, light)
	var marquee := Rect2(143, 28, 614, 64)
	surface.draw_rect(Rect2(marquee.position + Vector2(5, 6), marquee.size), Color(0, 0, 0, 0.55))
	surface.draw_rect(marquee, body.lightened(0.08))
	surface.draw_rect(marquee, trim, false, 3.0)
	var title_rect := Rect2(marquee.position + Vector2(8, 4), Vector2(marquee.size.x - 16, 40))
	surface.surface_label_centered(str(cabinet.get("marquee", "COIN PUSHER")), title_rect, 25, light)
	var subline := str(cabinet.get("marquee_subline", ""))
	if not subline.is_empty():
		surface.surface_label_centered(subline, Rect2(159, 70, 582, 14), 8, Color(light, 0.82))


func _draw_topper(surface, style: String, trim: Color, light: Color) -> void:
	match style:
		"peak":
			surface.surface_filled_polygon(PackedVector2Array([Vector2(317, 28), Vector2(450, 3), Vector2(583, 28)]), trim.darkened(0.12)) # SA2_PER_FRAME_OK: fixed three-point topper.
			surface.surface_polyline(PackedVector2Array([Vector2(317, 28), Vector2(450, 3), Vector2(583, 28)]), light, 3.0) # SA2_PER_FRAME_OK: fixed three-point topper trim.
		"dial":
			surface.draw_circle(Vector2(450, 28), 27.0, Color("#263b43"))
			surface.draw_circle(Vector2(450, 28), 22.0, trim, false, 3.0)
			for angle in range(0, 360, 45):
				var direction := Vector2.RIGHT.rotated(deg_to_rad(float(angle)))
				surface.draw_line(Vector2(450, 28) + direction * 14.0, Vector2(450, 28) + direction * 20.0, light, 2.0)
		"crown_lights":
			for index in range(5):
				var center := Vector2(414 + index * 18, 22 - abs(index - 2) * 4)
				surface.draw_circle(center, 12.0, trim.darkened(float(index % 2) * 0.12))
				surface.draw_circle(center, 8.0, light, false, 2.0)


func _draw_backglass(surface, state: Dictionary, cabinet: Dictionary, colors: Dictionary) -> void:
	var rect := Rect2(139, 99, 622, 48)
	surface.draw_rect(rect, colors["backglass"])
	surface.draw_rect(rect, colors["trim"], false, 2.0)
	var display: Dictionary = cabinet.get("backglass_display", {}) if typeof(cabinet.get("backglass_display", {})) == TYPE_DICTIONARY else {}
	match str(display.get("style", "none")):
		"value_lamps":
			var value := maxi(0, int(state.get(str(display.get("value_state_key", "")), 0)))
			var lamp_count := maxi(1, int(display.get("lamp_count", 5)))
			for index in range(lamp_count):
				var lamp := Vector2(270 + index * 90, 125)
				var lit := index < value
				surface.draw_circle(lamp, 10.0, colors["light"] if lit else Color(colors["light"], 0.16))
			surface.surface_label_centered(str(display.get("label_template", "%d")) % value, rect, 14, colors["light"])
		"dual_value_dial":
			var primary := maxi(0, int(state.get(str(display.get("primary_state_key", "")), 0)))
			var secondary := maxi(0, int(state.get(str(display.get("secondary_state_key", "")), 0)))
			surface.draw_circle(Vector2(194, 125), 18.0, colors["trim"], false, 3.0)
			surface.draw_line(Vector2(194, 125), Vector2(194, 112), colors["light"], 3.0)
			surface.surface_label_centered(str(display.get("label_template", "%d  %d")) % [primary, secondary], Rect2(225, 104, 510, 42), 16, colors["light"])
		"prize_showcase":
			var prize_count := maxi(0, int(state.get(str(display.get("count_state_key", "")), 0)))
			var case_symbols: Array = display.get("case_symbols", []) if typeof(display.get("case_symbols", [])) == TYPE_ARRAY else []
			var case_captions: Array = display.get("case_captions", []) if typeof(display.get("case_captions", [])) == TYPE_ARRAY else []
			var case_width := 88.0
			var case_gap := 12.0
			var cases_width := float(case_symbols.size()) * case_width + float(maxi(0, case_symbols.size() - 1)) * case_gap
			var case_start_x := rect.get_center().x - cases_width * 0.5
			for case_index in range(case_symbols.size()):
				var case_rect := Rect2(case_start_x + float(case_index) * (case_width + case_gap), rect.position.y + 4.0, case_width, rect.size.y - 8.0)
				var live_case := case_index < prize_count
				surface.draw_rect(case_rect, colors["trim"].darkened(0.15) if live_case else colors["side"].darkened(0.18))
				surface.draw_rect(case_rect, colors["light"] if live_case else Color(colors["trim"], 0.55), false, 2.0)
				surface.surface_reel_symbol_label(str(case_symbols[case_index]), Rect2(case_rect.position + Vector2(3, 1), Vector2(case_rect.size.x - 6, 22)), 12, colors["light"] if live_case else Color(colors["light"], 0.50))
				if case_index < case_captions.size():
					surface.surface_label_centered(str(case_captions[case_index]), Rect2(case_rect.position + Vector2(2, 25), Vector2(case_rect.size.x - 4, 9)), 7, colors["light"] if live_case else Color(colors["light"], 0.44))
			if case_symbols.is_empty():
				surface.surface_label_centered(str(display.get("label_template", "%d")) % prize_count, rect, 11, colors["light"])


func _draw_playfield(surface, state: Dictionary, colors: Dictionary, cabinet: Dictionary) -> void:
	var geometry: Dictionary = state.get("coin_pusher_geometry", {}) if typeof(state.get("coin_pusher_geometry", {})) == TYPE_DICTIONARY else {}
	var apparatus: Dictionary = state.get("coin_pusher_apparatus", {}) if typeof(state.get("coin_pusher_apparatus", {})) == TYPE_DICTIONARY else {}
	var current_face_y := float(state.get("coin_pusher_face_position_y", 28000))
	var previous_face_y := float(state.get("coin_pusher_previous_face_position_y", current_face_y))
	var interpolation_alpha := 1.0 if bool(state.get("reduce_motion", false)) else clampf(float(state.get("coin_pusher_interpolation_alpha", 1.0)), 0.0, 1.0)
	var face_y := int(round(lerpf(previous_face_y, current_face_y, interpolation_alpha)))
	var platform_top_z := int(geometry.get("platform_top_z", 3600))
	var back_plate_y := int(geometry.get("back_plate_y", 63000))
	var tray_lip_y := int(geometry.get("tray_lip_y", 6000))
	surface.draw_rect(PLAYFIELD_RECT, Color("#07131c"))
	_draw_delivery_board(surface, apparatus, geometry, colors)
	# Back plate, fixed deck, and the moving platform are projected from authored geometry.
	var back_left := _project(0, back_plate_y, 0)
	var back_right := _project(int(geometry.get("width", 100000)), back_plate_y, 0)
	surface.surface_filled_polygon(PackedVector2Array([back_left + Vector2(0, -20), back_right + Vector2(0, -20), back_right + Vector2(0, 6), back_left + Vector2(0, 6)]), colors["trim"].darkened(0.35)) # SA2_PER_FRAME_OK: four projected public geometry points.
	var lip_left := _project(0, tray_lip_y, 0)
	var lip_right := _project(int(geometry.get("width", 100000)), tray_lip_y, 0)
	var face_left := _project(0, face_y, 0)
	var face_right := _project(int(geometry.get("width", 100000)), face_y, 0)
	var authored_deck := _project_deck_polygon(geometry)
	surface.surface_filled_polygon(authored_deck if authored_deck.size() >= 3 else PackedVector2Array([lip_left, lip_right, face_right, face_left]), colors["deck"]) # SA2_PER_FRAME_OK: bounded authored public geometry.
	var top_face_left := _project(0, face_y, platform_top_z)
	var top_face_right := _project(int(geometry.get("width", 100000)), face_y, platform_top_z)
	var top_back_left := _project(0, back_plate_y, platform_top_z)
	var top_back_right := _project(int(geometry.get("width", 100000)), back_plate_y, platform_top_z)
	surface.surface_filled_polygon(PackedVector2Array([top_face_left, top_face_right, top_back_right, top_back_left]), colors["platform"].lightened(0.15)) # SA2_PER_FRAME_OK: four projected public geometry points.
	surface.surface_filled_polygon(PackedVector2Array([face_left, face_right, top_face_right, top_face_left]), colors["platform"].darkened(0.24)) # SA2_PER_FRAME_OK: four projected public geometry points.
	surface.draw_line(top_face_left, top_face_right, colors["light"], 2.0)
	_draw_gutters(surface, geometry, colors)
	_draw_delivery_pegs(surface, apparatus, geometry, colors)
	_draw_interpolated_bodies(surface, state, colors, cabinet)
	_draw_tray_lip(surface, lip_left, lip_right, colors)


func _draw_gutters(surface, geometry: Dictionary, colors: Dictionary) -> void:
	var gutter := int(geometry.get("gutter_x", 3000))
	var width := int(geometry.get("width", 100000))
	for x in [gutter, width - gutter]:
		var front := _project(x, int(geometry.get("tray_lip_y", 6000)) + 6000, 0)
		surface.surface_filled_polygon(PackedVector2Array([front + Vector2(-16, -4), front + Vector2(16, -4), front + Vector2(12, 10), front + Vector2(-12, 10)]), Color("#020508")) # SA2_PER_FRAME_OK: bounded four-point gutter geometry.
		surface.surface_polyline(PackedVector2Array([front + Vector2(-16, -4), front + Vector2(16, -4), front + Vector2(12, 10)]), colors["trim"].darkened(0.45), 2.0) # SA2_PER_FRAME_OK: bounded three-point gutter trim.


func _draw_delivery_board(surface, apparatus: Dictionary, geometry: Dictionary, colors: Dictionary) -> void:
	var board := _delivery_board(apparatus, geometry)
	var x_min := float(board["x_min"])
	var x_max := float(board["x_max"])
	var z_top := float(board["z_top"])
	var z_bottom := float(board["z_bottom"])
	var corners := PackedVector2Array([ # SA2_PER_FRAME_OK: fixed four-point delivery-board geometry.
		_project_delivery_board_point(board, x_min, z_top),
		_project_delivery_board_point(board, x_max, z_top),
		_project_delivery_board_point(board, x_max, z_bottom),
		_project_delivery_board_point(board, x_min, z_bottom),
	])
	surface.surface_filled_polygon(corners, Color(colors["backglass"], 0.84)) # SA2_PER_FRAME_OK: fixed authored four-point delivery surface.
	corners.append(corners[0])
	surface.surface_polyline(corners, colors["trim"], 2.0)
	# The lower board edge is the exact upper-platform catchment seam.
	var landing_left := _project_delivery_board_point(board, x_min, z_bottom)
	var landing_right := _project_delivery_board_point(board, x_max, z_bottom)
	surface.draw_line(landing_left, landing_right, Color(colors["light"], 0.72), 2.0)


func _draw_delivery_pegs(surface, apparatus: Dictionary, geometry: Dictionary, colors: Dictionary) -> void:
	var board := _delivery_board(apparatus, geometry)
	var pegs: Array = apparatus.get("pegs", []) if typeof(apparatus.get("pegs", [])) == TYPE_ARRAY else []
	for peg_value in pegs:
		if typeof(peg_value) != TYPE_DICTIONARY:
			continue
		var peg: Dictionary = peg_value
		var peg_projection := _project_delivery_peg(board, peg)
		var point: Vector2 = peg_projection["center"]
		var radius: Vector2 = peg_projection["radius"]
		_draw_ellipse(surface, point + Vector2(1, 2), radius.x + 1.0, radius.y + 1.0, Color(0, 0, 0, 0.48), 0)
		_draw_ellipse(surface, point, radius.x, radius.y, colors["trim"], 0)
		_draw_ellipse(surface, point - Vector2(1, 1), radius.x * 0.42, radius.y * 0.42, colors["light"], 0)


func _draw_interpolated_bodies(surface, state: Dictionary, colors: Dictionary, cabinet: Dictionary) -> void:
	_ensure_coin_batch()
	var current: Array = state.get("coin_pusher_bodies", []) if typeof(state.get("coin_pusher_bodies", [])) == TYPE_ARRAY else []
	var previous: Array = state.get("coin_pusher_previous_bodies", []) if typeof(state.get("coin_pusher_previous_bodies", [])) == TYPE_ARRAY else []
	var previous_by_id := {}
	var alpha := 1.0 if bool(state.get("reduce_motion", false)) else clampf(float(state.get("coin_pusher_interpolation_alpha", 1.0)), 0.0, 1.0)
	if alpha < 0.999:
		for value in previous:
			if typeof(value) == TYPE_DICTIONARY:
				previous_by_id[str((value as Dictionary).get("id", ""))] = value
	var sorted_bodies := _depth_sorted_bodies(current, int(state.get("coin_pusher_presentation_view_serial", state.get("coin_pusher_liveness_ticks", 0))))
	var count := mini(BATCH_CAPACITY, sorted_bodies.size())
	_coin_multimesh.visible_instance_count = count
	var feature_labels: Array = []
	var airborne_shadows: Array = []
	for index in range(count):
		var body: Dictionary = sorted_bodies[index]
		var body_id := str(body.get("id", ""))
		var x := float(int(body.get("x", 0)))
		var y := float(int(body.get("y", 0)))
		var z := float(int(body.get("z", 0)))
		if alpha < 0.999:
			var prior: Dictionary = previous_by_id.get(body_id, body)
			var previous_x := int(prior.get("x", body.get("x", 0)))
			var previous_y := int(prior.get("y", body.get("y", 0)))
			var previous_z := int(prior.get("z", body.get("z", 0)))
			x = lerpf(float(previous_x), x, alpha)
			y = lerpf(float(previous_y), y, alpha)
			z = lerpf(float(previous_z), z, alpha)
		var falling := str(body.get("rest_state", "")) == "falling"
		var geometry: Dictionary = state.get("coin_pusher_geometry", {}) if typeof(state.get("coin_pusher_geometry", {})) == TYPE_DICTIONARY else {}
		var apparatus: Dictionary = state.get("coin_pusher_apparatus", {}) if typeof(state.get("coin_pusher_apparatus", {})) == TYPE_DICTIONARY else {}
		var board := _delivery_board(apparatus, geometry)
		var on_delivery_board := falling and absi(int(round(y)) - int(board["y"])) <= int(body.get("radius", 4300)) and z >= float(board["z_bottom"])
		var point := _project_delivery_board_point(board, x, z) if on_delivery_board else _project_f(x, y, z)
		var body_color := _body_color(str(body.get("kind", "coin")), cabinet)
		var frame := posmod(body_id.hash(), ROTATION_VARIANTS.size())
		var rotation: float = ROTATION_VARIANTS[frame]
		_coin_multimesh.set_instance_transform_2d(index, Transform2D(rotation, point))
		if _coin_instance_color_cache[index] != body_color:
			_coin_multimesh.set_instance_color(index, body_color)
			_coin_instance_color_cache[index] = body_color
		if falling:
			var shadow_point := _project_delivery_board_point(board, x, z) if on_delivery_board and z > float(board["z_bottom"]) + _coin_height else _project_f(x, y, float(board["z_bottom"]))
			airborne_shadows.append(shadow_point)
		if str(body.get("kind", "coin")) != "coin":
			feature_labels.append({"kind": str(body.get("kind", "")), "point": point})
	for shadow_value in airborne_shadows:
		_draw_ellipse(surface, (shadow_value as Vector2) + AIRBORNE_SHADOW_OFFSET, COIN_RX * 0.94, COIN_RY * 0.76, Color(0, 0, 0, 0.80), 0)
	# One ordered batch is the exact depth order above; seeded rotation variants
	# are per instance and never repartition or reorder overlapping bodies.
	surface.surface_present_multimesh_batch(_coin_multimesh, _coin_texture, null, DESIGN_SIZE)
	for feature_value in feature_labels:
		var feature: Dictionary = feature_value
		var point: Vector2 = feature["point"]
		var kind := str(feature.get("kind", ""))
		var labels: Dictionary = cabinet.get("body_labels", {}) if typeof(cabinet.get("body_labels", {})) == TYPE_DICTIONARY else {}
		var label := str(labels.get(kind, kind.left(1).to_upper()))
		if not label.is_empty():
			surface.surface_reel_symbol_label(label, Rect2(point - Vector2(9, 8), Vector2(18, 16)), 10, Color("#111722"))


func _depth_sorted_bodies(bodies: Array, presentation_view_serial: int) -> Array:
	var first_id := str((bodies[0] as Dictionary).get("id", "")) if not bodies.is_empty() and typeof(bodies[0]) == TYPE_DICTIONARY else ""
	var last_id := str((bodies[bodies.size() - 1] as Dictionary).get("id", "")) if not bodies.is_empty() and typeof(bodies[bodies.size() - 1]) == TYPE_DICTIONARY else ""
	var key := "%d:%d:%s:%s" % [presentation_view_serial, bodies.size(), first_id, last_id]
	if key == _sorted_body_cache_key:
		return _sorted_body_cache
	_sorted_body_cache = bodies.duplicate(false)
	_sorted_body_cache.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_key := int(a.get("y", 0)) * 100000 - int(a.get("z", 0))
		var b_key := int(b.get("y", 0)) * 100000 - int(b.get("z", 0))
		return a_key > b_key if a_key != b_key else str(a.get("id", "")) < str(b.get("id", ""))
	)
	_sorted_body_cache_key = key
	return _sorted_body_cache


func debug_batch_body_order_for_test(bodies: Array, liveness_tick: int) -> Array:
	var result: Array = []
	for body_value in _depth_sorted_bodies(bodies, liveness_tick):
		result.append(str((body_value as Dictionary).get("id", "")))
	return result


func debug_depth_cache_key_for_test() -> String:
	return _sorted_body_cache_key


func _ensure_coin_batch() -> void:
	if _coin_multimesh != null:
		return
	_coin_texture = _make_coin_texture()
	_coin_mesh = QuadMesh.new()
	_coin_mesh.size = Vector2(COIN_RX * 2.0 + 2.0, COIN_RY * 2.0 + 4.0)
	_coin_multimesh = _new_coin_multimesh()


func _new_coin_multimesh() -> MultiMesh:
	var result := MultiMesh.new()
	result.transform_format = MultiMesh.TRANSFORM_2D
	result.use_colors = true
	result.instance_count = BATCH_CAPACITY
	result.visible_instance_count = 0
	result.mesh = _coin_mesh
	_coin_instance_color_cache.resize(BATCH_CAPACITY)
	_coin_instance_color_cache.fill(Color(-1, -1, -1, -1))
	return result


func _make_coin_texture() -> Texture2D:
	var image := Image.create(ATLAS_FRAME_SIZE.x, ATLAS_FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	var highlight := Vector2(ATLAS_FRAME_SIZE.x * 0.5 - 6.0, ATLAS_FRAME_SIZE.y * 0.5 - 6.0)
	for y in range(ATLAS_FRAME_SIZE.y):
		for x in range(ATLAS_FRAME_SIZE.x):
			var local := Vector2(float(x) - ATLAS_FRAME_SIZE.x * 0.5, float(y) - ATLAS_FRAME_SIZE.y * 0.5 - 1.0)
			var ellipse := local.x * local.x / (COIN_RX * COIN_RX) + local.y * local.y / (COIN_RY * COIN_RY)
			var color := Color(0, 0, 0, 0)
			var shadow_local := local - Vector2(2.0, 3.0)
			var shadow_ellipse := shadow_local.x * shadow_local.x / (COIN_RX * COIN_RX) + shadow_local.y * shadow_local.y / (COIN_RY * COIN_RY)
			if shadow_ellipse <= 1.0:
				color = Color(0.08, 0.08, 0.08, 0.42)
			if ellipse <= 1.0:
				var shade := 0.72 if ellipse > 0.72 else 0.92
				shade += clampf((1.0 - local.y / COIN_RY) * 0.06, 0.0, 0.12)
				if Vector2(float(x), float(y)).distance_to(highlight) <= 2.4:
					shade = 1.20
				color = Color(shade, shade, shade, 1.0)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _body_color(kind: String, cabinet: Dictionary) -> Color:
	var body_colors: Dictionary = cabinet.get("body_colors", {}) if typeof(cabinet.get("body_colors", {})) == TYPE_DICTIONARY else {}
	return Color(str(body_colors.get(kind, body_colors.get("default", NEUTRAL_CABINET["body_colors"]["default"]))))


func _draw_ellipse(surface, center: Vector2, rx: float, ry: float, color: Color, rotation_frame: int) -> void:
	var points := PackedVector2Array() # SA2_PER_FRAME_OK: bounded 12-segment fallback ellipse; coins use the batch node.
	var phase := float(rotation_frame) * PI * 0.5
	for index in range(ELLIPSE_SEGMENTS):
		var angle := float(index) / float(ELLIPSE_SEGMENTS) * TAU + phase
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	surface.surface_filled_polygon(points, color)
	points.append(points[0])
	surface.surface_polyline(points, color.lightened(0.20), 1.0)


func _draw_tray_lip(surface, left: Vector2, right: Vector2, colors: Dictionary) -> void:
	surface.draw_line(left, right, colors["trim"], 4.0)
	surface.draw_line(left + Vector2(0, 5), right + Vector2(0, 5), colors["side"], 4.0)


func _draw_glass(surface, colors: Dictionary) -> void:
	surface.draw_rect(PLAYFIELD_RECT, Color(colors["glass"], 0.08))
	surface.draw_line(Vector2(174, 120), Vector2(340, 120), Color(1, 1, 1, 0.28), 3.0)
	surface.draw_line(Vector2(175, 124), Vector2(250, 210), Color(1, 1, 1, 0.09), 18.0)
	surface.draw_rect(PLAYFIELD_RECT, Color(colors["glass"], 0.45), false, 2.0)


func _draw_hardware(surface, state: Dictionary, colors: Dictionary) -> void:
	var bindings: Dictionary = state.get("surface_action_bindings", {}) if typeof(state.get("surface_action_bindings", {})) == TYPE_DICTIONARY else {}
	var apparatus: Dictionary = state.get("coin_pusher_apparatus", {}) if typeof(state.get("coin_pusher_apparatus", {})) == TYPE_DICTIONARY else {}
	var rail: Dictionary = apparatus.get("rail", {}) if typeof(apparatus.get("rail", {})) == TYPE_DICTIONARY else {}
	var rail_min := int(rail.get("x_min", 8000))
	var rail_max := maxi(rail_min + 1, int(rail.get("x_max", 92000)))
	var carriage := int(state.get("coin_pusher_carriage_x", 50000))
	var carriage_t := clampf(float(carriage - rail_min) / float(rail_max - rail_min), 0.0, 1.0)
	var rail_x := RAIL_DRAG_RECT.position.x + RAIL_DRAG_RECT.size.x * carriage_t
	if str(apparatus.get("type", "rail_slot")) == "hole_set":
		var holes: Array = apparatus.get("holes", []) if typeof(apparatus.get("holes", [])) == TYPE_ARRAY else []
		for hole_index in range(holes.size()):
			var hole_x := 260.0 + float(hole_index) * 190.0
			var hole_rect := Rect2(hole_x - 22.0, 154.0, 44.0, 44.0)
			surface.draw_circle(hole_rect.get_center(), 20.0, colors["trim"])
			surface.draw_circle(hole_rect.get_center(), 15.0, Color("#020305"))
			if hole_index == int(state.get("coin_pusher_selected_hole", 0)):
				surface.draw_circle(hole_rect.get_center(), 22.0, colors["light"], false, 3.0)
			surface.surface_label_centered(str(hole_index + 1), hole_rect, 14, colors["light"])
			var hole_action := "coin_pusher_hole_%d" % hole_index
			if _binding_enabled(bindings, hole_action):
				surface.surface_add_exact_hit(hole_rect, hole_action, hole_index)
	else:
		# The rail owns only its 44 px hardware strip; it never blankets the board or pile.
		var drag_enabled := _binding_enabled(bindings, "coin_pusher_carriage_left") and _binding_enabled(bindings, "coin_pusher_carriage_right")
		if drag_enabled:
			surface.surface_add_drag_hit(RAIL_DRAG_RECT, "coin_pusher_carriage_drag")
		surface.draw_line(Vector2(RAIL_DRAG_RECT.position.x, 166), Vector2(RAIL_DRAG_RECT.end.x, 166), colors["trim"].darkened(0.18), 6.0)
		surface.draw_rect(Rect2(rail_x - 11, 154, 22, 42), colors["side"])
		surface.draw_rect(Rect2(rail_x - 11, 154, 22, 42), colors["light"], false, 2.0)
		surface.draw_line(Vector2(rail_x, 184), Vector2(rail_x, 204), colors["light"], 3.0)
		_draw_small_hardware(surface, Rect2(126, 332, 42, 34), "<", "coin_pusher_carriage_left", colors, _binding_enabled(bindings, "coin_pusher_carriage_left"))
		_draw_small_hardware(surface, Rect2(174, 332, 42, 34), ">", "coin_pusher_carriage_right", colors, _binding_enabled(bindings, "coin_pusher_carriage_right"))
	var stop_engaged := bool(state.get("coin_pusher_skill_stop_engaged", false))
	var stop_rect := Rect2(229, 326, 90, 46)
	surface.draw_circle(stop_rect.get_center(), 27.0, colors["light"] if stop_engaged else Color("#b73538"))
	surface.draw_circle(stop_rect.get_center(), 27.0, Color.WHITE if surface.surface_region_hovered("coin_pusher_skill_stop") else colors["trim"], false, 3.0)
	surface.surface_label_centered("RELEASE" if stop_engaged else "STOP", stop_rect, 12, Color("#10141d"))
	if _binding_enabled(bindings, "coin_pusher_skill_stop"):
		surface.surface_add_hit(stop_rect, "coin_pusher_skill_stop")
	var tray_rect := Rect2(332, 326, 244, 52)
	surface.draw_rect(tray_rect, Color("#06090c"))
	surface.draw_rect(tray_rect, colors["trim"], false, 3.0)
	_draw_tray_heap(surface, tray_rect, int(state.get("coin_pusher_tray_count", 0)), colors)
	var collect_enabled := bool((bindings.get("coin_pusher_collect", {}) as Dictionary).get("enabled", false)) if typeof(bindings.get("coin_pusher_collect", {})) == TYPE_DICTIONARY else false
	var tray_label_rect := Rect2(tray_rect.position + Vector2(5, 3), Vector2(tray_rect.size.x - 10, 18))
	surface.surface_label_centered("COLLECT  %d  ($%d)" % [int(state.get("coin_pusher_tray_count", 0)), int(state.get("coin_pusher_tray_value", 0))], tray_label_rect, 11, colors["light"] if collect_enabled else Color(colors["light"], 0.44))
	if collect_enabled:
		surface.surface_add_hit(tray_rect, "coin_pusher_collect")
	var slot_rect := Rect2(591, 326, 78, 46)
	surface.draw_rect(slot_rect, colors["side"].lightened(0.08))
	surface.draw_circle(Vector2(630, 348), 19.0, colors["trim"].darkened(0.20))
	surface.draw_circle(Vector2(630, 348), 15.0, colors["side"])
	surface.draw_line(Vector2(620, 348), Vector2(640, 348), Color("#020305"), 5.0)
	surface.surface_label_centered("DROP", Rect2(597, 365, 66, 10), 8, colors["light"])
	var drop_enabled := _binding_enabled(bindings, "coin_pusher_drop")
	if drop_enabled:
		surface.surface_add_hit(slot_rect, "coin_pusher_drop")
	var nudge_rect := Rect2(684, 326, 90, 46)
	var nudge_enabled := _binding_enabled(bindings, "coin_pusher_nudge")
	var nudge_hovered: bool = nudge_enabled and bool(surface.surface_region_hovered("coin_pusher_nudge"))
	surface.draw_rect(nudge_rect, colors["side"].lightened(0.08 if nudge_hovered else 0.0))
	surface.draw_circle(Vector2(699, 337), 3.0, colors["trim"])
	surface.draw_circle(Vector2(759, 337), 3.0, colors["trim"])
	surface.draw_line(Vector2(706, 347), Vector2(752, 347), Color.WHITE if nudge_hovered else colors["trim"], 8.0)
	surface.draw_line(Vector2(706, 347), Vector2(706, 359), colors["trim"], 4.0)
	surface.draw_line(Vector2(752, 347), Vector2(752, 359), colors["trim"], 4.0)
	surface.surface_label_centered("NUDGE", Rect2(693, 358, 72, 12), 8, colors["light"] if nudge_enabled else Color(colors["light"], 0.38))
	if nudge_enabled:
		surface.surface_add_hit(nudge_rect, "coin_pusher_nudge")
	surface.surface_label_centered(str(state.get("coin_pusher_tell_label", "steady")).to_upper(), Rect2(686, 375, 86, 16), 9, colors["light"])
	_draw_feature_hardware(surface, state, bindings, colors)


func _draw_feature_hardware(surface, state: Dictionary, bindings: Dictionary, colors: Dictionary) -> void:
	_draw_nudge_selectors(surface, state, bindings, colors)
	if str(state.get("coin_pusher_variation_id", "")) == "vault_drop":
		_draw_vault_hardware(surface, state, bindings, colors)


func _draw_nudge_selectors(surface, state: Dictionary, bindings: Dictionary, colors: Dictionary) -> void:
	var forces: Dictionary = state.get("coin_pusher_nudge_forces", {}) if typeof(state.get("coin_pusher_nudge_forces", {})) == TYPE_DICTIONARY else {}
	var force_options: Array = []
	for force in forces.keys():
		force_options.append({"id": str(force), "label": str(force).to_upper(), "action": "coin_pusher_force_%s" % str(force)})
	var direction_options: Array = []
	for direction in ["left", "front", "right"]:
		direction_options.append({"id": direction, "label": direction.left(1).to_upper(), "action": "coin_pusher_direction_%s" % direction})
	var selected_force := str(state.get("coin_pusher_nudge_force", "tap"))
	var selected_direction := str(state.get("coin_pusher_nudge_direction", "front"))
	var groups := [
		{"options": force_options, "selected": selected_force, "y": 300.0},
		{"options": direction_options, "selected": selected_direction, "y": 382.0},
	]
	for group_value in groups:
		var group: Dictionary = group_value
		var options: Array = group.get("options", []) if typeof(group.get("options", [])) == TYPE_ARRAY else []
		if options.is_empty():
			continue
		var width := 90.0 / float(options.size())
		for option_index in range(options.size()):
			if typeof(options[option_index]) != TYPE_DICTIONARY:
				continue
			var option: Dictionary = options[option_index]
			var action := str(option.get("action", ""))
			var option_id := str(option.get("id", ""))
			var rect := Rect2(684.0 + width * option_index, float(group["y"]), width - 2.0, 17.0)
			var enabled := _binding_enabled(bindings, action)
			var selected := option_id == str(group["selected"])
			surface.draw_rect(rect, colors["light"] if selected else colors["side"])
			surface.draw_rect(rect, colors["trim"] if enabled else Color(colors["trim"], 0.32), false, 1.0)
			surface.surface_label_centered(str(option.get("label", option_id)).to_upper(), rect.grow(-1.0), 7, Color("#10141d") if selected else Color(colors["light"], 0.85 if enabled else 0.32))
			if enabled and not action.is_empty():
				surface.surface_add_exact_hit(rect, action, int(option.get("index", option_index)))


func _draw_vault_hardware(surface, state: Dictionary, bindings: Dictionary, colors: Dictionary) -> void:
	var panel := Rect2(126, 382, 540, 38)
	surface.draw_rect(panel, colors["side"].darkened(0.12))
	surface.draw_rect(panel, colors["trim"], false, 2.0)
	var round_active := bool(state.get("coin_pusher_vault_round_active", false))
	var cells: Array = state.get("coin_pusher_vault_cells", []) if typeof(state.get("coin_pusher_vault_cells", [])) == TYPE_ARRAY else []
	var door_rect := Rect2(132, 387, 78, 27)
	surface.draw_rect(door_rect, colors["body"].darkened(0.20 if not round_active else 0.02))
	surface.draw_rect(door_rect, colors["trim"], false, 2.0)
	surface.surface_label_centered("VAULT %s" % ("OPEN" if round_active else "SHUT"), door_rect, 8, colors["light"])
	var cell_width := 31.0
	for cell_index in range(cells.size()):
		if typeof(cells[cell_index]) != TYPE_DICTIONARY:
			continue
		var cell: Dictionary = cells[cell_index]
		var rect := Rect2(216.0 + cell_width * cell_index, 387.0, cell_width - 3.0, 27.0)
		var action := str(cell.get("selection_action", "coin_pusher_vault_cell_%d" % cell_index))
		var selected := cell_index == int(state.get("coin_pusher_vault_selected_cell", -1))
		var opened := bool(cell.get("opened", false))
		var peeked := bool(cell.get("peeked", false))
		var fill: Color = colors["light"] if selected else colors["body"].lightened(0.10 if opened or peeked else 0.0)
		surface.draw_rect(rect, fill)
		surface.draw_rect(rect, colors["light"] if selected else colors["trim"], false, 1.0)
		surface.surface_label_centered(str(cell.get("label", "?")), rect.grow(-1.0), 8, Color("#10141d") if selected else colors["light"])
		if _binding_enabled(bindings, action):
			surface.surface_add_exact_hit(rect, action, cell_index)
	var action_ids := ["start_vault_round", "open_vault_cell", "stop_vault_round", "peek_vault_cell"]
	var action_labels := ["OPEN", "CELL", "STOP", "X-RAY"]
	for action_index in range(action_ids.size()):
		var action := str(action_ids[action_index])
		var rect := Rect2(410.0 + action_index * 62.0, 387.0, 58.0, 27.0)
		var enabled := _binding_enabled(bindings, action)
		_draw_small_hardware(surface, rect, str(action_labels[action_index]), action, colors, enabled)


func _feature_hardware_action_ids(state: Dictionary) -> Array:
	var result: Array = []
	var forces: Dictionary = state.get("coin_pusher_nudge_forces", {}) if typeof(state.get("coin_pusher_nudge_forces", {})) == TYPE_DICTIONARY else {}
	for force in forces.keys():
		result.append("coin_pusher_force_%s" % str(force))
	for direction in ["left", "front", "right"]:
		result.append("coin_pusher_direction_%s" % direction)
	if str(state.get("coin_pusher_variation_id", "")) == "vault_drop":
		var cells: Array = state.get("coin_pusher_vault_cells", []) if typeof(state.get("coin_pusher_vault_cells", [])) == TYPE_ARRAY else []
		for cell_index in range(cells.size()):
			var cell: Dictionary = cells[cell_index] if typeof(cells[cell_index]) == TYPE_DICTIONARY else {}
			result.append(str(cell.get("selection_action", "coin_pusher_vault_cell_%d" % cell_index)))
		result.append_array(["start_vault_round", "open_vault_cell", "stop_vault_round", "peek_vault_cell"])
	return result


func _hardware_actions(state: Dictionary) -> Array:
	var apparatus: Dictionary = state.get("coin_pusher_apparatus", {}) if typeof(state.get("coin_pusher_apparatus", {})) == TYPE_DICTIONARY else {}
	var bindings: Dictionary = state.get("surface_action_bindings", {}) if typeof(state.get("surface_action_bindings", {})) == TYPE_DICTIONARY else {}
	var actions: Array = []
	for action in ["coin_pusher_drop", "coin_pusher_skill_stop", "coin_pusher_collect", "coin_pusher_nudge"]:
		if _binding_enabled(bindings, action):
			actions.append(action)
	if str(apparatus.get("type", "rail_slot")) == "hole_set":
		for hole_index in range((apparatus.get("holes", []) as Array).size() if typeof(apparatus.get("holes", [])) == TYPE_ARRAY else 0):
			var action := "coin_pusher_hole_%d" % hole_index
			if _binding_enabled(bindings, action):
				actions.append(action)
	else:
		var left_enabled := _binding_enabled(bindings, "coin_pusher_carriage_left")
		var right_enabled := _binding_enabled(bindings, "coin_pusher_carriage_right")
		if left_enabled and right_enabled:
			actions.append("coin_pusher_carriage_drag")
		if left_enabled:
			actions.append("coin_pusher_carriage_left")
		if right_enabled:
			actions.append("coin_pusher_carriage_right")
	for action in _feature_hardware_action_ids(state):
		if _binding_enabled(bindings, str(action)):
			actions.append(action)
	return actions


func _hardware_catalog(state: Dictionary) -> Array:
	var apparatus: Dictionary = state.get("coin_pusher_apparatus", {}) if typeof(state.get("coin_pusher_apparatus", {})) == TYPE_DICTIONARY else {}
	var result: Array = ["coin_pusher_drop", "coin_pusher_skill_stop", "coin_pusher_collect", "coin_pusher_nudge"]
	if str(apparatus.get("type", "rail_slot")) == "hole_set":
		for hole_index in range((apparatus.get("holes", []) as Array).size() if typeof(apparatus.get("holes", [])) == TYPE_ARRAY else 0):
			result.append("coin_pusher_hole_%d" % hole_index)
	else:
		result.append_array(["coin_pusher_carriage_drag", "coin_pusher_carriage_left", "coin_pusher_carriage_right"])
	result.append_array(_feature_hardware_action_ids(state))
	return result


func _binding_enabled(bindings: Dictionary, action: String) -> bool:
	if not bindings.has(action) or typeof(bindings[action]) != TYPE_DICTIONARY:
		return false
	return bool((bindings[action] as Dictionary).get("enabled", false))


func _entry_hardware_layout(state: Dictionary) -> Dictionary:
	var apparatus: Dictionary = state.get("coin_pusher_apparatus", {}) if typeof(state.get("coin_pusher_apparatus", {})) == TYPE_DICTIONARY else {}
	if str(apparatus.get("type", "rail_slot")) == "hole_set":
		var targets: Array = []
		for hole_index in range((apparatus.get("holes", []) as Array).size() if typeof(apparatus.get("holes", [])) == TYPE_ARRAY else 0):
			targets.append({"index": hole_index, "action": "coin_pusher_hole_%d" % hole_index, "rect": Rect2(238.0 + float(hole_index) * 190.0, 154.0, 44.0, 44.0)})
		return {"type": "hole_set", "targets": targets}
	return {"type": "rail_slot", "drag_rect": RAIL_DRAG_RECT}


func _draw_small_hardware(surface, rect: Rect2, label: String, action: String, colors: Dictionary, enabled: bool) -> void:
	var hovered: bool = bool(surface.surface_region_hovered(action))
	var body_color: Color = colors["body"]
	surface.draw_rect(rect, body_color.lightened(0.08 if hovered else 0.0))
	surface.draw_rect(rect, Color.WHITE if hovered else colors["trim"], false, 2.0)
	surface.surface_label_centered(label, rect.grow(-3.0), 12, colors["light"])
	if enabled:
		surface.surface_add_hit(rect, action)


func _draw_tray_heap(surface, rect: Rect2, count: int, colors: Dictionary) -> void:
	var visible := mini(22, maxi(0, count))
	for index in range(visible):
		var row := index / 8
		var column := index % 8
		var point := Vector2(rect.position.x + 24 + column * 25 + (row % 2) * 10, rect.end.y - 11 - row * 7)
		_draw_ellipse(surface, point, 11.0, 5.0, colors["trim"].darkened(float(index % 3) * 0.05), index % 4)


func _project(x: int, y: int, z: int) -> Vector2:
	return _project_f(float(x), float(y), float(z))


func _project_f(x: float, y: float, z: float) -> Vector2:
	var depth := clampf(y / _world_back_y, 0.0, 1.0)
	var width_factor := lerpf(1.0, REAR_WIDTH_FACTOR, depth)
	var center_x := PLAYFIELD_RECT.get_center().x
	var screen_x := center_x + (x / _world_width - 0.5) * PLAYFIELD_RECT.size.x * 0.90 * width_factor
	var screen_y := PLAYFIELD_RECT.end.y - 5.0 - depth * 40.0 - z / _coin_height * Z_LAYER_OFFSET
	return Vector2(screen_x, screen_y)


func _cabinet(state: Dictionary) -> Dictionary:
	var authored: Dictionary = state.get("coin_pusher_cabinet", {}) if typeof(state.get("coin_pusher_cabinet", {})) == TYPE_DICTIONARY else {}
	if not authored.is_empty():
		return authored
	return NEUTRAL_CABINET


func _colors(cabinet: Dictionary) -> Dictionary:
	var source: Dictionary = cabinet.get("colors", {}) if typeof(cabinet.get("colors", {})) == TYPE_DICTIONARY else {}
	var palette_key := "%s:%s" % [str(cabinet.get("identity", "generic")), str(cabinet.get("palette", ""))]
	if palette_key == _palette_cache_key:
		return _palette_cache
	var fallback: Dictionary = NEUTRAL_CABINET["colors"]
	var result := {}
	for key in ["body", "side", "trim", "light", "glass", "deck", "platform", "backglass"]:
		result[key] = Color(str(source.get(key, fallback.get(key, "#ffffff"))))
	_palette_cache_key = palette_key
	_palette_cache = result
	return _palette_cache


func _configure_projection(state: Dictionary) -> void:
	var geometry: Dictionary = state.get("coin_pusher_geometry", {}) if typeof(state.get("coin_pusher_geometry", {})) == TYPE_DICTIONARY else {}
	_world_width = maxf(1.0, float(geometry.get("width", SCHEMA_DEFAULT_WIDTH)))
	_world_back_y = maxf(1.0, float(geometry.get("back_plate_y", SCHEMA_DEFAULT_BACK_Y)))
	_coin_height = maxf(1.0, float(state.get("coin_pusher_coin_height", SCHEMA_DEFAULT_COIN_HEIGHT)))


func debug_project_for_test(state: Dictionary, x: float, y: float, z: float) -> Vector2:
	_configure_projection(state)
	return _project_f(x, y, z)


func debug_project_delivery_board_point_for_test(state: Dictionary, x: float, z: float) -> Vector2:
	_configure_projection(state)
	var geometry: Dictionary = state.get("coin_pusher_geometry", {}) if typeof(state.get("coin_pusher_geometry", {})) == TYPE_DICTIONARY else {}
	var apparatus: Dictionary = state.get("coin_pusher_apparatus", {}) if typeof(state.get("coin_pusher_apparatus", {})) == TYPE_DICTIONARY else {}
	return _project_delivery_board_point(_delivery_board(apparatus, geometry), x, z)


func debug_interpolated_face_y_for_test(state: Dictionary) -> int:
	var current := float(state.get("coin_pusher_face_position_y", 0))
	if bool(state.get("reduce_motion", false)):
		return int(round(current))
	return int(round(lerpf(float(state.get("coin_pusher_previous_face_position_y", current)), current, clampf(float(state.get("coin_pusher_interpolation_alpha", 1.0)), 0.0, 1.0))))


func debug_deck_polygon_for_test(state: Dictionary) -> PackedVector2Array:
	_configure_projection(state)
	var geometry: Dictionary = state.get("coin_pusher_geometry", {}) if typeof(state.get("coin_pusher_geometry", {})) == TYPE_DICTIONARY else {}
	return _project_deck_polygon(geometry)


func debug_authored_cabinet_for_test(state: Dictionary, body_kind: String = "coin") -> Dictionary:
	var cabinet := _cabinet(state)
	var colors := _colors(cabinet)
	var display: Dictionary = cabinet.get("backglass_display", {}) if typeof(cabinet.get("backglass_display", {})) == TYPE_DICTIONARY else {}
	var labels: Dictionary = cabinet.get("body_labels", {}) if typeof(cabinet.get("body_labels", {})) == TYPE_DICTIONARY else {}
	return {
		"identity": str(cabinet.get("identity", "generic")),
		"display_style": str(display.get("style", "none")),
		"display_state_key": str(display.get("value_state_key", display.get("count_state_key", ""))),
		"body_color": _body_color(body_kind, cabinet).to_html(false),
		"body_label": str(labels.get(body_kind, body_kind.left(1).to_upper())),
		"backglass_color": (colors["backglass"] as Color).to_html(false),
	}


func debug_delivery_board_for_test(state: Dictionary) -> Dictionary:
	_configure_projection(state)
	var geometry: Dictionary = state.get("coin_pusher_geometry", {}) if typeof(state.get("coin_pusher_geometry", {})) == TYPE_DICTIONARY else {}
	var apparatus: Dictionary = state.get("coin_pusher_apparatus", {}) if typeof(state.get("coin_pusher_apparatus", {})) == TYPE_DICTIONARY else {}
	var board := _delivery_board(apparatus, geometry)
	var peg_projections: Array = []
	for peg_value in apparatus.get("pegs", []):
		if typeof(peg_value) == TYPE_DICTIONARY:
			var projection := _project_delivery_peg(board, peg_value)
			peg_projections.append({"source": (peg_value as Dictionary).duplicate(true), "center": projection["center"], "radius": projection["radius"]})
	return {
		"source": board.duplicate(true),
		"top_left": _project_delivery_board_point(board, float(board["x_min"]), float(board["z_top"])),
		"top_right": _project_delivery_board_point(board, float(board["x_max"]), float(board["z_top"])),
		"landing_left": _project_delivery_board_point(board, float(board["x_min"]), float(board["z_bottom"])),
		"landing_right": _project_delivery_board_point(board, float(board["x_max"]), float(board["z_bottom"])),
		"pegs": peg_projections,
	}


func _delivery_board(apparatus: Dictionary, geometry: Dictionary) -> Dictionary:
	var authored: Dictionary = apparatus.get("drop_board", {}) if typeof(apparatus.get("drop_board", {})) == TYPE_DICTIONARY else {}
	var width := int(geometry.get("width", SCHEMA_DEFAULT_WIDTH))
	var platform_top := int(geometry.get("platform_top_z", 3600))
	return {
		"y": int(authored.get("y", geometry.get("drop_y", SCHEMA_DEFAULT_BACK_Y))),
		"z_top": int(authored.get("z_top", geometry.get("drop_z", 24000))),
		"z_bottom": int(authored.get("z_bottom", platform_top)),
		"x_min": int(authored.get("x_min", 0)),
		"x_max": int(authored.get("x_max", width)),
	}


func _project_delivery_board_point(board: Dictionary, x: float, z: float) -> Vector2:
	# A single transform owns the board, pins, descent and catchment seam. Its
	# lower edge converges exactly on the authored upper-platform landing line.
	var z_bottom := float(board.get("z_bottom", 3600))
	var z_top := maxf(z_bottom + 1.0, float(board.get("z_top", 24000)))
	var t := clampf((z - z_bottom) / (z_top - z_bottom), 0.0, 1.0)
	var landing := _project_f(x, float(board.get("y", SCHEMA_DEFAULT_BACK_Y)), z_bottom)
	var top_y := PLAYFIELD_RECT.position.y + COIN_RY + 10.0
	return Vector2(landing.x, lerpf(landing.y, top_y, t))


func _project_delivery_peg(board: Dictionary, peg: Dictionary) -> Dictionary:
	var x := float(peg.get("x", 0))
	var z := float(peg.get("z", 0))
	var r := maxf(1.0, float(peg.get("r", 1)))
	var center := _project_delivery_board_point(board, x, z)
	var radius_x := center.distance_to(_project_delivery_board_point(board, x + r, z))
	var radius_z := center.distance_to(_project_delivery_board_point(board, x, z + r))
	return {"center": center, "radius": Vector2(maxf(1.0, radius_x), maxf(1.0, radius_z))}


func _project_deck_polygon(geometry: Dictionary) -> PackedVector2Array:
	var authored: Array = geometry.get("deck_polygon", []) if typeof(geometry.get("deck_polygon", [])) == TYPE_ARRAY else []
	var points := PackedVector2Array()
	for point_value in authored:
		if typeof(point_value) == TYPE_DICTIONARY:
			var point: Dictionary = point_value
			points.append(_project(int(point.get("x", 0)), int(point.get("y", 0)), int(point.get("z", 0))))
		elif typeof(point_value) == TYPE_ARRAY and (point_value as Array).size() >= 2:
			var point_array: Array = point_value
			points.append(_project(int(point_array[0]), int(point_array[1]), int(point_array[2]) if point_array.size() >= 3 else 0))
	return points
