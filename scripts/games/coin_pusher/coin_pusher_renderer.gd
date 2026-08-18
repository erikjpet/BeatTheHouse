class_name CoinPusherRenderer
extends RefCounted

const DESIGN_SIZE := Vector2(900, 430)
const RAIL_DRAG_RECT := Rect2(176, 142, 548, 112)
const PLAYFIELD_RECT := Rect2(158, 152, 584, 165)
const WORLD_BACK_Y := 63000.0
const COIN_HEIGHT := 1700.0
const REAR_WIDTH_FACTOR := 0.78
const COIN_RX := 17.0
const COIN_RY := 12.0
const Z_LAYER_OFFSET := 11.0
const ELLIPSE_SEGMENTS := 12
const BATCH_CAPACITY := 600
const ATLAS_FRAME_SIZE := Vector2i(40, 32)
const ROTATION_VARIANTS := [-0.12, -0.04, 0.04, 0.12]

const DEFAULT_CABINETS := {
	"quarter_falls": {
		"identity": "quarter_falls", "marquee": "QUARTER FALLS", "palette": "carnival_brass_red", "topper_style": "coin_crown",
		"colors": {"body": "#6f2028", "side": "#3c111b", "trim": "#e7b84f", "light": "#fff0a6", "glass": "#82c9d8", "deck": "#173b42", "platform": "#d49c42", "backglass": "#46131c"},
	},
	"jackpot_ridge": {
		"identity": "jackpot_ridge", "marquee": "JACKPOT RIDGE", "palette": "ridge_purple_gold", "topper_style": "ridge_peak",
		"colors": {"body": "#45205f", "side": "#241135", "trim": "#efc04d", "light": "#ffe68a", "glass": "#9c88dc", "deck": "#211b4e", "platform": "#754ea1", "backglass": "#311544"},
	},
	"vault_drop": {
		"identity": "vault_drop", "marquee": "THE VAULT DROP", "palette": "vault_steel_teal", "topper_style": "vault_dial",
		"colors": {"body": "#354b55", "side": "#1c2b32", "trim": "#4bd8c8", "light": "#b9fff1", "glass": "#72bac2", "deck": "#17343b", "platform": "#5e8790", "backglass": "#203c43"},
	},
}

var _coin_texture: Texture2D
var _coin_multimesh: MultiMesh
var _coin_mesh: QuadMesh
var _sorted_body_cache: Array = []
var _sorted_body_cache_key := ""
var _coin_instance_color_cache: Array = []
var _palette_cache_key := ""
var _palette_cache: Dictionary = {}


func draw(surface, state: Dictionary) -> bool:
	if str(state.get("surface_renderer", "")) != "coin_pusher":
		return false
	_ensure_coin_batch()
	surface.surface_begin_design_space(DESIGN_SIZE)
	var cabinet := _cabinet(state)
	var colors := _colors(cabinet)
	_draw_floor_and_shell(surface, cabinet, colors)
	_draw_backglass(surface, state, cabinet, colors)
	_draw_playfield(surface, state, colors)
	_draw_glass(surface, colors)
	_draw_hardware(surface, state, colors)
	surface.surface_end_design_space()
	return true


func render_signature(state: Dictionary) -> Dictionary:
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
		"coin_rx": COIN_RX,
		"coin_ry": COIN_RY,
		"z_layer_offset": Z_LAYER_OFFSET,
		"rotation_frames": 4,
		"depth_sorted": true,
		"batched_nodes": 1,
		"per_coin_nodes": 0,
		"body_count": bodies.size(),
		"airborne_count": airborne,
		"stacked_count": stacked,
		"riding_count": riding,
		"tray_heap_count": int(state.get("coin_pusher_tray_count", 0)),
		"hardware_actions": ["coin_pusher_carriage_drag", "coin_pusher_carriage_left", "coin_pusher_carriage_right", "coin_pusher_drop", "coin_pusher_skill_stop", "coin_pusher_collect"],
	}


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
	_draw_topper(surface, str(cabinet.get("topper_style", "coin_crown")), trim, light)
	var marquee := Rect2(143, 28, 614, 64)
	surface.draw_rect(Rect2(marquee.position + Vector2(5, 6), marquee.size), Color(0, 0, 0, 0.55))
	surface.draw_rect(marquee, body.lightened(0.08))
	surface.draw_rect(marquee, trim, false, 3.0)
	var title_rect := Rect2(marquee.position + Vector2(8, 4), Vector2(marquee.size.x - 16, 40))
	surface.surface_label_centered(str(cabinet.get("marquee", "COIN PUSHER")), title_rect, 25, light)
	if str(cabinet.get("identity", "")) == "quarter_falls":
		surface.surface_label_centered("A QUARTER IN MOTION IS A QUARTER WITH A CHANCE", Rect2(159, 70, 582, 14), 8, Color(light, 0.82))


func _draw_topper(surface, style: String, trim: Color, light: Color) -> void:
	match style:
		"ridge_peak":
			surface.surface_filled_polygon(PackedVector2Array([Vector2(317, 28), Vector2(450, 3), Vector2(583, 28)]), trim.darkened(0.12)) # SA2_PER_FRAME_OK: fixed three-point topper.
			surface.surface_polyline(PackedVector2Array([Vector2(317, 28), Vector2(450, 3), Vector2(583, 28)]), light, 3.0) # SA2_PER_FRAME_OK: fixed three-point topper trim.
		"vault_dial":
			surface.draw_circle(Vector2(450, 28), 27.0, Color("#263b43"))
			surface.draw_circle(Vector2(450, 28), 22.0, trim, false, 3.0)
			for angle in range(0, 360, 45):
				var direction := Vector2.RIGHT.rotated(deg_to_rad(float(angle)))
				surface.draw_line(Vector2(450, 28) + direction * 14.0, Vector2(450, 28) + direction * 20.0, light, 2.0)
		_:
			for index in range(5):
				var center := Vector2(414 + index * 18, 22 - abs(index - 2) * 4)
				surface.draw_circle(center, 12.0, trim.darkened(float(index % 2) * 0.12))
				surface.draw_circle(center, 8.0, light, false, 2.0)


func _draw_backglass(surface, state: Dictionary, cabinet: Dictionary, colors: Dictionary) -> void:
	var rect := Rect2(139, 99, 622, 48)
	surface.draw_rect(rect, colors["backglass"])
	surface.draw_rect(rect, colors["trim"], false, 2.0)
	var variation := str(state.get("coin_pusher_variation_id", "quarter_falls"))
	match variation:
		"jackpot_ridge":
			var multiplier := maxi(1, int(state.get("coin_pusher_ridge_multiplier", 1)))
			for index in range(5):
				var lamp := Vector2(270 + index * 90, 125)
				var lit := index < multiplier
				surface.draw_circle(lamp, 10.0, colors["light"] if lit else Color(colors["light"], 0.16))
			surface.surface_label_centered("RIDGE MULTIPLIER  x%d" % multiplier, rect, 14, colors["light"])
		"vault_drop":
			var meter := maxi(0, int(state.get("coin_pusher_vault_meter", 0)))
			var fragments := maxi(0, int(state.get("coin_pusher_vault_fragments", 0)))
			surface.draw_circle(Vector2(194, 125), 18.0, colors["trim"], false, 3.0)
			surface.draw_line(Vector2(194, 125), Vector2(194, 112), colors["light"], 3.0)
			surface.surface_label_centered("VAULT  $%d   KEY FRAGMENTS %d" % [meter, fragments], Rect2(225, 104, 510, 42), 16, colors["light"])
		_:
			for index in range(7):
				var lamp_position := Vector2(264 + index * 62, 123)
				surface.draw_circle(lamp_position, 6.0, colors["trim"].darkened(0.18))
				surface.draw_circle(lamp_position - Vector2(1, 1), 2.2, colors["light"])


func _draw_playfield(surface, state: Dictionary, colors: Dictionary) -> void:
	var geometry: Dictionary = state.get("coin_pusher_geometry", {}) if typeof(state.get("coin_pusher_geometry", {})) == TYPE_DICTIONARY else {}
	var apparatus: Dictionary = state.get("coin_pusher_apparatus", {}) if typeof(state.get("coin_pusher_apparatus", {})) == TYPE_DICTIONARY else {}
	var face_y := int(state.get("coin_pusher_face_position_y", 28000))
	var platform_top_z := int(geometry.get("platform_top_z", 3600))
	var back_plate_y := int(geometry.get("back_plate_y", 63000))
	var tray_lip_y := int(geometry.get("tray_lip_y", 6000))
	surface.draw_rect(PLAYFIELD_RECT, Color("#07131c"))
	# Back plate, fixed deck, and the moving platform are projected from authored geometry.
	var back_left := _project(0, back_plate_y, 0)
	var back_right := _project(int(geometry.get("width", 100000)), back_plate_y, 0)
	surface.surface_filled_polygon(PackedVector2Array([back_left + Vector2(0, -20), back_right + Vector2(0, -20), back_right + Vector2(0, 6), back_left + Vector2(0, 6)]), colors["trim"].darkened(0.35)) # SA2_PER_FRAME_OK: four projected public geometry points.
	var lip_left := _project(0, tray_lip_y, 0)
	var lip_right := _project(int(geometry.get("width", 100000)), tray_lip_y, 0)
	var face_left := _project(0, face_y, 0)
	var face_right := _project(int(geometry.get("width", 100000)), face_y, 0)
	surface.surface_filled_polygon(PackedVector2Array([lip_left, lip_right, face_right, face_left]), colors["deck"]) # SA2_PER_FRAME_OK: four projected public geometry points.
	var top_face_left := _project(0, face_y, platform_top_z)
	var top_face_right := _project(int(geometry.get("width", 100000)), face_y, platform_top_z)
	var top_back_left := _project(0, back_plate_y, platform_top_z)
	var top_back_right := _project(int(geometry.get("width", 100000)), back_plate_y, platform_top_z)
	surface.surface_filled_polygon(PackedVector2Array([top_face_left, top_face_right, top_back_right, top_back_left]), colors["platform"].lightened(0.15)) # SA2_PER_FRAME_OK: four projected public geometry points.
	surface.surface_filled_polygon(PackedVector2Array([face_left, face_right, top_face_right, top_face_left]), colors["platform"].darkened(0.24)) # SA2_PER_FRAME_OK: four projected public geometry points.
	surface.draw_line(top_face_left, top_face_right, colors["light"], 2.0)
	_draw_gutters(surface, geometry, colors)
	_draw_pegs(surface, apparatus, colors)
	_draw_interpolated_bodies(surface, state, colors)
	_draw_tray_lip(surface, lip_left, lip_right, colors)


func _draw_gutters(surface, geometry: Dictionary, colors: Dictionary) -> void:
	var gutter := int(geometry.get("gutter_x", 3000))
	var width := int(geometry.get("width", 100000))
	for x in [gutter, width - gutter]:
		var front := _project(x, int(geometry.get("tray_lip_y", 6000)) + 6000, 0)
		surface.surface_filled_polygon(PackedVector2Array([front + Vector2(-16, -4), front + Vector2(16, -4), front + Vector2(12, 10), front + Vector2(-12, 10)]), Color("#020508")) # SA2_PER_FRAME_OK: bounded four-point gutter geometry.
		surface.surface_polyline(PackedVector2Array([front + Vector2(-16, -4), front + Vector2(16, -4), front + Vector2(12, 10)]), colors["trim"].darkened(0.45), 2.0) # SA2_PER_FRAME_OK: bounded three-point gutter trim.


func _draw_pegs(surface, apparatus: Dictionary, colors: Dictionary) -> void:
	var pegs: Array = apparatus.get("pegs", []) if typeof(apparatus.get("pegs", [])) == TYPE_ARRAY else []
	for peg_value in pegs:
		if typeof(peg_value) != TYPE_DICTIONARY:
			continue
		var peg: Dictionary = peg_value
		var point := _project(int(peg.get("x", 50000)), int(apparatus.get("drop_y", 40000)), int(peg.get("z", 9000)))
		var radius := clampf(float(int(peg.get("r", 1200))) / 1200.0 * 4.0, 3.0, 7.0)
		surface.draw_circle(point + Vector2(1, 2), radius + 1.0, Color(0, 0, 0, 0.48))
		surface.draw_circle(point, radius, colors["trim"])
		surface.draw_circle(point - Vector2(1, 1), radius * 0.42, colors["light"])


func _draw_interpolated_bodies(surface, state: Dictionary, colors: Dictionary) -> void:
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
		var point := _project_f(x, y, z)
		var falling := str(body.get("rest_state", "")) == "falling"
		var body_color := _body_color(str(body.get("kind", "coin")))
		var frame := posmod(body_id.hash(), ROTATION_VARIANTS.size())
		var rotation: float = ROTATION_VARIANTS[frame]
		_coin_multimesh.set_instance_transform_2d(index, Transform2D(rotation, point))
		if _coin_instance_color_cache[index] != body_color:
			_coin_multimesh.set_instance_color(index, body_color)
			_coin_instance_color_cache[index] = body_color
		if falling:
			var shadow_point := _project_f(x, y, 0.0)
			airborne_shadows.append(shadow_point)
		if str(body.get("kind", "coin")) != "coin":
			feature_labels.append({"kind": str(body.get("kind", "")), "point": point})
	for shadow_value in airborne_shadows:
		_draw_ellipse(surface, (shadow_value as Vector2) + Vector2(3, 4), COIN_RX * 0.88, COIN_RY * 0.72, Color(0, 0, 0, 0.30), 0)
	# One ordered batch is the exact depth order above; seeded rotation variants
	# are per instance and never repartition or reorder overlapping bodies.
	surface.surface_present_multimesh_batch(_coin_multimesh, _coin_texture, null, DESIGN_SIZE)
	for feature_value in feature_labels:
		var feature: Dictionary = feature_value
		var point: Vector2 = feature["point"]
		var kind := str(feature.get("kind", ""))
		surface.surface_reel_symbol_label("P" if kind == "puck" else "K" if kind == "fragment" else "R", Rect2(point - Vector2(9, 8), Vector2(18, 16)), 10, Color("#111722"))


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


func _body_color(kind: String) -> Color:
	match kind:
		"puck": return Color("#a77cff")
		"fragment": return Color("#58ead9")
		"rider": return Color("#ff866e")
	return Color("#e3b94d")


func _draw_body(surface, body: Dictionary, point: Vector2, colors: Dictionary) -> void:
	var kind := str(body.get("kind", "coin"))
	var base := Color("#e3b94d")
	if kind == "puck":
		base = Color("#a77cff")
	elif kind == "fragment":
		base = Color("#58ead9")
	elif kind == "rider":
		base = Color("#ff866e")
	var frame := posmod(str(body.get("id", "")).hash(), 4)
	_draw_ellipse(surface, point, COIN_RX, COIN_RY, base.darkened(0.12), frame)
	_draw_ellipse(surface, point + Vector2(0, -2), COIN_RX - 2.2, COIN_RY - 2.2, base, frame)
	var highlight_angle := float(frame) * PI * 0.5 - PI * 0.75
	var highlight := point + Vector2(cos(highlight_angle) * 8.5, sin(highlight_angle) * 5.5 - 2.0)
	surface.draw_circle(highlight, 2.2, colors["light"])
	if kind != "coin":
		surface.surface_reel_symbol_label("P" if kind == "puck" else "K" if kind == "fragment" else "★", Rect2(point - Vector2(9, 8), Vector2(18, 16)), 10, Color("#111722"))


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
	var rail: Dictionary = (state.get("coin_pusher_apparatus", {}) as Dictionary).get("rail", {}) if typeof(state.get("coin_pusher_apparatus", {})) == TYPE_DICTIONARY else {}
	var rail_min := int(rail.get("x_min", 8000))
	var rail_max := maxi(rail_min + 1, int(rail.get("x_max", 92000)))
	var carriage := int(state.get("coin_pusher_carriage_x", 50000))
	var carriage_t := clampf(float(carriage - rail_min) / float(rail_max - rail_min), 0.0, 1.0)
	var rail_x := RAIL_DRAG_RECT.position.x + RAIL_DRAG_RECT.size.x * carriage_t
	# The drag region is deliberately broad over the physical chute so touch users can steer without precision.
	surface.surface_add_drag_hit(RAIL_DRAG_RECT, "coin_pusher_carriage_drag")
	surface.draw_line(Vector2(RAIL_DRAG_RECT.position.x, 160), Vector2(RAIL_DRAG_RECT.end.x, 160), colors["trim"].darkened(0.18), 6.0)
	surface.draw_rect(Rect2(rail_x - 11, 145, 22, 38), colors["side"])
	surface.draw_rect(Rect2(rail_x - 11, 145, 22, 38), colors["light"], false, 2.0)
	surface.draw_line(Vector2(rail_x, 176), Vector2(rail_x, 211), colors["light"], 3.0)
	_draw_small_hardware(surface, Rect2(126, 332, 42, 34), "◀", "coin_pusher_carriage_left", colors, true)
	_draw_small_hardware(surface, Rect2(174, 332, 42, 34), "▶", "coin_pusher_carriage_right", colors, true)
	var stop_engaged := bool(state.get("coin_pusher_skill_stop_engaged", false))
	var stop_rect := Rect2(229, 326, 90, 46)
	surface.draw_circle(stop_rect.get_center(), 27.0, colors["light"] if stop_engaged else Color("#b73538"))
	surface.draw_circle(stop_rect.get_center(), 27.0, Color.WHITE if surface.surface_region_hovered("coin_pusher_skill_stop") else colors["trim"], false, 3.0)
	surface.surface_label_centered("RELEASE" if stop_engaged else "STOP", stop_rect, 12, Color("#10141d"))
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
	var drop_enabled := bool((bindings.get("coin_pusher_drop", {}) as Dictionary).get("enabled", true)) if typeof(bindings.get("coin_pusher_drop", {})) == TYPE_DICTIONARY else true
	if drop_enabled:
		surface.surface_add_hit(slot_rect, "coin_pusher_drop")
	var nudge_rect := Rect2(684, 326, 90, 46)
	var nudge_hovered: bool = bool(surface.surface_region_hovered("coin_pusher_nudge"))
	surface.draw_rect(nudge_rect, colors["side"].lightened(0.08 if nudge_hovered else 0.0))
	surface.draw_circle(Vector2(699, 337), 3.0, colors["trim"])
	surface.draw_circle(Vector2(759, 337), 3.0, colors["trim"])
	surface.draw_line(Vector2(706, 347), Vector2(752, 347), Color.WHITE if nudge_hovered else colors["trim"], 8.0)
	surface.draw_line(Vector2(706, 347), Vector2(706, 359), colors["trim"], 4.0)
	surface.draw_line(Vector2(752, 347), Vector2(752, 359), colors["trim"], 4.0)
	surface.surface_label_centered("NUDGE", Rect2(693, 358, 72, 12), 8, colors["light"])
	surface.surface_add_hit(nudge_rect, "coin_pusher_nudge")
	surface.surface_label_centered(str(state.get("coin_pusher_tell_label", "steady")).to_upper(), Rect2(686, 375, 86, 16), 9, colors["light"])


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
	var depth := clampf(y / WORLD_BACK_Y, 0.0, 1.0)
	var width_factor := lerpf(1.0, REAR_WIDTH_FACTOR, depth)
	var center_x := PLAYFIELD_RECT.get_center().x
	var screen_x := center_x + (x / 100000.0 - 0.5) * PLAYFIELD_RECT.size.x * 0.90 * width_factor
	var screen_y := PLAYFIELD_RECT.end.y - 18.0 - depth * 139.0 - z / COIN_HEIGHT * Z_LAYER_OFFSET
	return Vector2(screen_x, screen_y)


func _cabinet(state: Dictionary) -> Dictionary:
	var authored: Dictionary = state.get("coin_pusher_cabinet", {}) if typeof(state.get("coin_pusher_cabinet", {})) == TYPE_DICTIONARY else {}
	if not authored.is_empty():
		return authored
	return (DEFAULT_CABINETS.get(str(state.get("coin_pusher_variation_id", "quarter_falls")), DEFAULT_CABINETS["quarter_falls"]) as Dictionary).duplicate(true)


func _colors(cabinet: Dictionary) -> Dictionary:
	var source: Dictionary = cabinet.get("colors", {}) if typeof(cabinet.get("colors", {})) == TYPE_DICTIONARY else {}
	var palette_key := "%s:%s" % [str(cabinet.get("identity", "quarter_falls")), str(cabinet.get("palette", ""))]
	if palette_key == _palette_cache_key:
		return _palette_cache
	var fallback: Dictionary = (DEFAULT_CABINETS["quarter_falls"] as Dictionary)["colors"]
	var result := {}
	for key in ["body", "side", "trim", "light", "glass", "deck", "platform", "backglass"]:
		result[key] = Color(str(source.get(key, fallback.get(key, "#ffffff"))))
	_palette_cache_key = palette_key
	_palette_cache = result
	return _palette_cache
