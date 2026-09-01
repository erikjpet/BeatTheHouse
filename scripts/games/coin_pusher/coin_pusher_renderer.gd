class_name CoinPusherRenderer
extends RefCounted

const CoinPusherSolverAPI := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")
const DESIGN_SIZE := Vector2(900, 430)
const CABINET_RECT := Rect2(34, 18, 832, 400)
const MARQUEE_RECT := Rect2(170, 4, 560, 38)
const BACKGLASS_RECT := Rect2(76, 42, 748, 26)
const PLAYFIELD_RECT := Rect2(52, 70, 796, 276)
const SCHEMA_DEFAULT_WIDTH := 100000.0
const SCHEMA_DEFAULT_BACK_Y := 78000.0
const SCHEMA_DEFAULT_COIN_HEIGHT := 950.0
const SCHEMA_DEFAULT_COIN_RADIUS := 2350.0
const REAR_WIDTH_FACTOR := 0.78
const COIN_RX := SCHEMA_DEFAULT_COIN_RADIUS / SCHEMA_DEFAULT_WIDTH * PLAYFIELD_RECT.size.x * 0.91
const COIN_RY := 12.0
const Z_LAYER_OFFSET := 10.0
const ELLIPSE_SEGMENTS := 12
const PEG_OCTAGON := [
	Vector2(1.0, 0.0), Vector2(0.70710678, 0.70710678),
	Vector2(0.0, 1.0), Vector2(-0.70710678, 0.70710678),
	Vector2(-1.0, 0.0), Vector2(-0.70710678, -0.70710678),
	Vector2(0.0, -1.0), Vector2(0.70710678, -0.70710678),
]
const BATCH_CAPACITY := 600
# Match the pre-expansion 17x12 coin artwork exactly. The 68 px atlas belonged
# to the temporary 31 px radius; retaining it with a 17 px ellipse compressed
# the textured quad horizontally and made flat coins read as upright circles.
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
var _sorted_body_cache_source: Array = []
var _coin_transform_buffer := PackedVector2Array()
var _coin_color_buffer := PackedColorArray()
var _palette_cache_key := ""
var _palette_cache: Dictionary = {}
var _static_cache_viewports: Array[SubViewport] = []
var _static_cache_canvases: Array[Control] = []
var _static_cache_key := ""
var _static_cache_pending := true
var _static_cache_pending_layers := [true, true, true]
var _static_cache_host: Control
var _static_cache_font: Font
var _static_cache_render_serial := 0
var _static_cache_rebuild_serial := 0
var _static_cache_fallback_reason := "cold"
var _static_cache_pixel_size := Vector2i.ZERO
var _world_width := SCHEMA_DEFAULT_WIDTH
var _world_back_y := SCHEMA_DEFAULT_BACK_Y
var _coin_height := SCHEMA_DEFAULT_COIN_HEIGHT
var _coin_radius := SCHEMA_DEFAULT_COIN_RADIUS
var _perf_stage_samples: Dictionary = {}


func draw(surface, state: Dictionary) -> bool:
	if str(state.get("surface_renderer", "")) != "coin_pusher":
		return false
	var capture_stages := bool(state.get("coin_pusher_perf_stage_capture", false))
	var stage_started_usec := Time.get_ticks_usec() if capture_stages else 0
	_ensure_coin_batch()
	_configure_projection(state)
	surface.surface_begin_design_space(DESIGN_SIZE)
	var cabinet := _cabinet(state)
	var colors := _colors(cabinet)
	if bool(state.get("coin_pusher_locked", false)):
		colors = _locked_colors(colors)
	var static_cached := _prepare_static_cache(surface, state)
	stage_started_usec = _capture_perf_stage("setup_cache", stage_started_usec, capture_stages)
	if not static_cached:
		_draw_floor_and_shell(surface, cabinet, colors)
	else:
		_draw_static_cache_texture(surface, 0)
	stage_started_usec = _capture_perf_stage("shell", stage_started_usec, capture_stages)
	_draw_backglass(surface, state, cabinet, colors)
	stage_started_usec = _capture_perf_stage("backglass", stage_started_usec, capture_stages)
	if not static_cached:
		_draw_playfield(surface, state, colors, cabinet)
		stage_started_usec = _capture_perf_stage("playfield_uncached", stage_started_usec, capture_stages)
	else:
		_draw_static_cache_texture(surface, 1)
		stage_started_usec = _capture_perf_stage("static_pre", stage_started_usec, capture_stages)
		_draw_playfield(surface, state, colors, cabinet, false, true, false, false)
		stage_started_usec = _capture_perf_stage("platform", stage_started_usec, capture_stages)
		_draw_static_cache_texture(surface, 2)
		stage_started_usec = _capture_perf_stage("static_post", stage_started_usec, capture_stages)
		_draw_playfield(surface, state, colors, cabinet, false, false, false, true)
		stage_started_usec = _capture_perf_stage("bodies", stage_started_usec, capture_stages)
	_draw_glass(surface, colors)
	stage_started_usec = _capture_perf_stage("glass", stage_started_usec, capture_stages)
	_draw_hardware(surface, state, colors)
	stage_started_usec = _capture_perf_stage("hardware", stage_started_usec, capture_stages)
	surface.surface_end_design_space()
	_capture_perf_stage("end_design_space", stage_started_usec, capture_stages)
	return true


func reset_performance_stage_counters() -> void:
	_perf_stage_samples.clear()


func performance_stage_counters() -> Dictionary:
	return _perf_stage_samples.duplicate(true)


func _capture_perf_stage(stage_id: String, started_usec: int, enabled: bool) -> int:
	if not enabled:
		return 0
	var finished_usec := Time.get_ticks_usec()
	var samples: Array = _perf_stage_samples.get(stage_id, [])
	samples.append(finished_usec - started_usec)
	_perf_stage_samples[stage_id] = samples
	return finished_usec


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
		stacked += 1 if int(body.get("z", 0)) >= int(state.get("coin_pusher_coin_height", 950)) else 0
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
		"coin_atlas_frame_size": ATLAS_FRAME_SIZE,
		"front_contact_radius_px": _projected_contact_radius_x(0.0, _coin_radius),
		"rear_contact_radius_px": _projected_contact_radius_x(_world_back_y, _coin_radius),
		"z_layer_offset": Z_LAYER_OFFSET,
		"rotation_frames": 4,
		"depth_sorted": true,
		"batch_draws": 1,
		"batched_nodes": 0,
		"per_coin_nodes": 0,
		"draw_order": ["shadows", "coin_batch", "feature_labels", "payout_edge_face", "glass", "hardware"],
		"body_count": bodies.size(),
		"airborne_count": airborne,
		"stacked_count": stacked,
		"riding_count": riding,
		"tray_heap_count": int(state.get("coin_pusher_tray_count", 0)),
		"cabinet_rect": CABINET_RECT,
		"marquee_rect": MARQUEE_RECT,
		"backglass_rect": BACKGLASS_RECT,
		"playfield_rect": PLAYFIELD_RECT,
		"playfield_width_ratio": PLAYFIELD_RECT.size.x / CABINET_RECT.size.x,
		"playfield_height_ratio": PLAYFIELD_RECT.size.y / CABINET_RECT.size.y,
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
	surface.surface_filled_polygon(PackedVector2Array([Vector2(18, 425), Vector2(882, 425), Vector2(826, 400), Vector2(74, 400)]), Color(0, 0, 0, 0.56)) # SA2_PER_FRAME_OK: bounded authored cabinet geometry under the measured draw budget.
	surface.draw_rect(CABINET_RECT, body)
	surface.surface_filled_polygon(PackedVector2Array([Vector2(34, 18), Vector2(48, 30), Vector2(48, 414), Vector2(34, 418)]), side.darkened(0.22)) # SA2_PER_FRAME_OK: fixed four-point cabinet side.
	surface.surface_filled_polygon(PackedVector2Array([Vector2(866, 18), Vector2(852, 30), Vector2(852, 414), Vector2(866, 418)]), side.darkened(0.28)) # SA2_PER_FRAME_OK: fixed four-point cabinet side.
	surface.draw_rect(Rect2(44, 28, 8, 376), side)
	surface.draw_rect(Rect2(848, 28, 8, 376), side.darkened(0.08))
	surface.draw_rect(Rect2(48, 346, 804, 58), body.darkened(0.08))
	surface.draw_rect(CABINET_RECT, trim, false, 3.0)
	_draw_topper(surface, str(cabinet.get("topper_style", "none")), trim, light)
	var marquee := MARQUEE_RECT
	surface.draw_rect(Rect2(marquee.position + Vector2(5, 6), marquee.size), Color(0, 0, 0, 0.55))
	surface.draw_rect(marquee, body.lightened(0.08))
	surface.draw_rect(marquee, trim, false, 3.0)
	var title_rect := Rect2(marquee.position + Vector2(8, 2), Vector2(marquee.size.x - 16, 24))
	surface.surface_label_centered(str(cabinet.get("marquee", "COIN PUSHER")), title_rect, 18, light)
	var subline := str(cabinet.get("marquee_subline", ""))
	if not subline.is_empty():
		surface.surface_label_centered(subline, Rect2(marquee.position.x + 12, 28, marquee.size.x - 24, 10), 7, Color(light, 0.82))


func _draw_topper(surface, style: String, trim: Color, light: Color) -> void:
	match style:
		"peak":
			surface.surface_filled_polygon(PackedVector2Array([Vector2(326, 8), Vector2(450, 0), Vector2(574, 8)]), trim.darkened(0.12)) # SA2_PER_FRAME_OK: fixed three-point topper.
			surface.surface_polyline(PackedVector2Array([Vector2(326, 8), Vector2(450, 0), Vector2(574, 8)]), light, 2.0) # SA2_PER_FRAME_OK: fixed three-point topper trim.
		"dial":
			surface.draw_circle(Vector2(450, 8), 14.0, Color("#263b43"))
			surface.draw_circle(Vector2(450, 8), 11.0, trim, false, 2.0)
			for angle in range(0, 360, 45):
				var direction := Vector2.RIGHT.rotated(deg_to_rad(float(angle)))
				surface.draw_line(Vector2(450, 8) + direction * 7.0, Vector2(450, 8) + direction * 11.0, light, 1.0)
		"crown_lights":
			for index in range(5):
				var center := Vector2(422 + index * 14, 7 - abs(index - 2) * 2)
				surface.draw_circle(center, 7.0, trim.darkened(float(index % 2) * 0.12))
				surface.draw_circle(center, 4.0, light, false, 1.0)


func _draw_backglass(surface, state: Dictionary, cabinet: Dictionary, colors: Dictionary) -> void:
	var rect := BACKGLASS_RECT
	surface.draw_rect(rect, colors["backglass"])
	surface.draw_rect(rect, colors["trim"], false, 2.0)
	var goal: Dictionary = state.get("coin_pusher_goal", {}) if typeof(state.get("coin_pusher_goal", {})) == TYPE_DICTIONARY else {}
	if not goal.is_empty():
		_draw_goal_backglass(surface, rect, goal, colors)
		return
	var display: Dictionary = cabinet.get("backglass_display", {}) if typeof(cabinet.get("backglass_display", {})) == TYPE_DICTIONARY else {}
	match str(display.get("style", "none")):
		"value_lamps":
			var value := maxi(0, int(state.get(str(display.get("value_state_key", "")), 0)))
			var lamp_count := maxi(1, int(display.get("lamp_count", 5)))
			for index in range(lamp_count):
				var lamp := Vector2(288 + index * 80, rect.get_center().y)
				var lit := index < value
				surface.draw_circle(lamp, 7.0, colors["light"] if lit else Color(colors["light"], 0.16))
			surface.surface_label_centered(str(display.get("label_template", "%d")) % value, rect, 11, colors["light"])
		"dual_value_dial":
			var primary := maxi(0, int(state.get(str(display.get("primary_state_key", "")), 0)))
			var secondary := maxi(0, int(state.get(str(display.get("secondary_state_key", "")), 0)))
			surface.draw_circle(Vector2(112, rect.get_center().y), 9.0, colors["trim"], false, 2.0)
			surface.draw_line(Vector2(112, rect.get_center().y), Vector2(112, rect.position.y + 4), colors["light"], 2.0)
			surface.surface_label_centered(str(display.get("label_template", "%d  %d")) % [primary, secondary], Rect2(132, rect.position.y, 660, rect.size.y), 12, colors["light"])
		"prize_showcase":
			var prize_count := maxi(0, int(state.get(str(display.get("count_state_key", "")), 0)))
			var case_symbols: Array = display.get("case_symbols", []) if typeof(display.get("case_symbols", [])) == TYPE_ARRAY else []
			var case_captions: Array = display.get("case_captions", []) if typeof(display.get("case_captions", [])) == TYPE_ARRAY else []
			var case_width := 82.0
			var case_gap := 8.0
			var cases_width := float(case_symbols.size()) * case_width + float(maxi(0, case_symbols.size() - 1)) * case_gap
			var case_start_x := rect.get_center().x - cases_width * 0.5
			for case_index in range(case_symbols.size()):
				var case_rect := Rect2(case_start_x + float(case_index) * (case_width + case_gap), rect.position.y + 2.0, case_width, rect.size.y - 4.0)
				var live_case := case_index < prize_count
				surface.draw_rect(case_rect, colors["trim"].darkened(0.15) if live_case else colors["side"].darkened(0.18))
				surface.draw_rect(case_rect, colors["light"] if live_case else Color(colors["trim"], 0.55), false, 2.0)
				surface.surface_reel_symbol_label(str(case_symbols[case_index]), Rect2(case_rect.position + Vector2(3, 0), Vector2(case_rect.size.x - 6, 14)), 9, colors["light"] if live_case else Color(colors["light"], 0.50))
				if case_index < case_captions.size():
					surface.surface_label_centered(str(case_captions[case_index]), Rect2(case_rect.position + Vector2(2, 14), Vector2(case_rect.size.x - 4, 8)), 6, colors["light"] if live_case else Color(colors["light"], 0.44))
			if case_symbols.is_empty():
				surface.surface_label_centered(str(display.get("label_template", "%d")) % prize_count, rect, 11, colors["light"])


func _draw_goal_backglass(surface, rect: Rect2, goal: Dictionary, colors: Dictionary) -> void:
	var target := maxi(1, int(goal.get("target", 1)))
	var progress := clampi(int(goal.get("progress", 0)), 0, target)
	var active := bool(goal.get("active", false))
	var title_color: Color = Color.WHITE if active else colors["light"]
	surface.surface_label_centered(str(goal.get("title", "MACHINE GOAL")), Rect2(rect.position + Vector2(8, 2), Vector2(154, 14)), 9, title_color)
	surface.surface_label_centered(str(goal.get("instruction", "PUSH THE FEATURE PIECES")), Rect2(rect.position + Vector2(164, 1), Vector2(430, 15)), 8, colors["light"])
	var bonus := maxi(0, int(goal.get("bonus_tokens", 0)))
	var progress_label := "%d/%d" % [progress, target]
	if bonus > 0:
		progress_label += "  +%d TOKENS" % bonus
	surface.surface_label_centered(progress_label, Rect2(rect.position + Vector2(596, 1), Vector2(144, 15)), 8, title_color)
	var gap := 3.0
	var segment_width := minf(36.0, (rect.size.x - 20.0 - gap * float(target - 1)) / float(target))
	var total_width := segment_width * float(target) + gap * float(target - 1)
	var start_x := rect.get_center().x - total_width * 0.5
	for index in range(target):
		var segment := Rect2(start_x + float(index) * (segment_width + gap), rect.end.y - 6.0, segment_width, 3.0)
		surface.draw_rect(segment, colors["light"] if index < progress or active else Color(colors["light"], 0.18))


func _draw_playfield(surface, state: Dictionary, colors: Dictionary, cabinet: Dictionary, draw_static_pre: bool = true, draw_platform: bool = true, draw_static_post: bool = true, draw_bodies: bool = true) -> void:
	var geometry: Dictionary = state.get("coin_pusher_geometry", {}) if typeof(state.get("coin_pusher_geometry", {})) == TYPE_DICTIONARY else {}
	var apparatus: Dictionary = state.get("coin_pusher_apparatus", {}) if typeof(state.get("coin_pusher_apparatus", {})) == TYPE_DICTIONARY else {}
	var current_face_y := float(state.get("coin_pusher_face_position_y", 43000))
	var previous_face_y := float(state.get("coin_pusher_previous_face_position_y", current_face_y))
	var interpolation_alpha := 1.0 if bool(state.get("reduce_motion", false)) else clampf(float(state.get("coin_pusher_interpolation_alpha", 1.0)), 0.0, 1.0)
	var face_y := int(round(lerpf(previous_face_y, current_face_y, interpolation_alpha)))
	var platform_top_z := int(geometry.get("platform_top_z", 3600))
	var back_plate_y := int(geometry.get("back_plate_y", 78000))
	var tray_lip_y := int(geometry.get("tray_lip_y", 4000))
	var payout_ramp_run := maxi(1, int(geometry.get("payout_ramp_run", 6500)))
	var payout_ramp_rise := maxi(0, int(geometry.get("payout_ramp_rise", 900)))
	var payout_apron_drop := maxi(1, int(geometry.get("payout_apron_drop", 3000)))
	if draw_static_pre:
		surface.draw_rect(PLAYFIELD_RECT, Color("#07131c"))
		_draw_delivery_board(surface, apparatus, geometry, colors)
	# Back plate, fixed deck, and the moving platform are projected from authored geometry.
	var back_left := _project(0, back_plate_y, 0)
	var back_right := _project(int(geometry.get("width", 100000)), back_plate_y, 0)
	if draw_static_pre:
		surface.surface_filled_polygon(PackedVector2Array([back_left + Vector2(0, -20), back_right + Vector2(0, -20), back_right + Vector2(0, 6), back_left + Vector2(0, 6)]), colors["trim"].darkened(0.35)) # SA2_PER_FRAME_OK: four projected public geometry points.
	var lip_left := _project(0, tray_lip_y, payout_ramp_rise)
	var lip_right := _project(int(geometry.get("width", 100000)), tray_lip_y, payout_ramp_rise)
	var ramp_back_left := _project(0, tray_lip_y + payout_ramp_run, 0)
	var ramp_back_right := _project(int(geometry.get("width", 100000)), tray_lip_y + payout_ramp_run, 0)
	var face_left := _project(0, face_y, 0)
	var face_right := _project(int(geometry.get("width", 100000)), face_y, 0)
	var authored_deck := _project_deck_polygon(geometry)
	if (authored_deck.size() >= 3 and draw_static_pre) or (authored_deck.size() < 3 and draw_platform):
		surface.surface_filled_polygon(authored_deck if authored_deck.size() >= 3 else PackedVector2Array([ramp_back_left, ramp_back_right, face_right, face_left]), colors["deck"]) # SA2_PER_FRAME_OK: bounded authored public geometry.
	# Real payout edges are inclined plates, not invisible trigger lines. Coins
	# climb this raised band before tipping into the win chute.
	if draw_static_pre:
		surface.surface_filled_polygon(PackedVector2Array([lip_left, lip_right, ramp_back_right, ramp_back_left]), colors["deck"].lightened(0.16)) # SA2_PER_FRAME_OK: fixed four-point edge plate.
		surface.draw_line(ramp_back_left, ramp_back_right, Color(colors["light"], 0.52), 1.5)
		surface.draw_line(lip_left, lip_right, colors["light"], 2.0)
	var top_face_left := _project(0, face_y, platform_top_z)
	var top_face_right := _project(int(geometry.get("width", 100000)), face_y, platform_top_z)
	var top_back_left := _project(0, back_plate_y, platform_top_z)
	var top_back_right := _project(int(geometry.get("width", 100000)), back_plate_y, platform_top_z)
	if draw_platform:
		surface.surface_filled_polygon(PackedVector2Array([top_face_left, top_face_right, top_back_right, top_back_left]), colors["platform"].lightened(0.15)) # SA2_PER_FRAME_OK: four projected public geometry points.
		surface.surface_filled_polygon(PackedVector2Array([face_left, face_right, top_face_right, top_face_left]), colors["platform"].darkened(0.24)) # SA2_PER_FRAME_OK: four projected public geometry points.
		surface.draw_line(top_face_left, top_face_right, colors["light"], 2.0)
	if draw_static_post:
		_draw_gutters(surface, geometry, colors)
		_draw_delivery_pegs(surface, apparatus, geometry, colors)
		_draw_delivery_targets(surface, apparatus, geometry, colors)
	if draw_bodies:
		_draw_interpolated_bodies(surface, state, colors, cabinet)
	# The steel front apron is foreground hardware. Drawing its opaque face after
	# the coin batch hides a coin while it is still behind the shelf edge; the
	# coin reappears naturally only after its physical fall clears the bottom.
	var apron_bottom_z := payout_ramp_rise - payout_apron_drop
	var apron_bottom_left := _project(0, tray_lip_y, apron_bottom_z)
	var apron_bottom_right := _project(int(geometry.get("width", 100000)), tray_lip_y, apron_bottom_z)
	if draw_bodies:
		_draw_payout_edge_face(surface, lip_left, lip_right, apron_bottom_left, apron_bottom_right, colors)


func _draw_gutters(surface, geometry: Dictionary, colors: Dictionary) -> void:
	var gutter := int(geometry.get("gutter_x", 3000))
	var width := int(geometry.get("width", 100000))
	for x in [gutter, width - gutter]:
		var front := _project(x, int(geometry.get("tray_lip_y", 4000)) + int(geometry.get("payout_ramp_run", 6500)) + 3000, 0)
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
		# Pins are only a few pixels across. The generic ellipse helper emits a
		# fill and outline and recalculates trigonometry. A precomputed two-layer
		# pixel-art pin keeps the readable body/highlight with two submissions.
		_draw_filled_peg_ellipse(surface, point, radius.x, radius.y, colors["trim"])
		_draw_filled_peg_ellipse(surface, point - Vector2(1, 1), radius.x * 0.42, radius.y * 0.42, colors["light"])


func _draw_delivery_targets(surface, apparatus: Dictionary, geometry: Dictionary, colors: Dictionary) -> void:
	var board := _delivery_board(apparatus, geometry)
	var targets: Array = apparatus.get("targets", []) if typeof(apparatus.get("targets", [])) == TYPE_ARRAY else []
	for target_value in targets:
		if typeof(target_value) != TYPE_DICTIONARY:
			continue
		var target: Dictionary = target_value
		var target_x := float(target.get("x", 0))
		var target_z := float(target.get("z", board.get("z_bottom", 3600)))
		var center := _project_delivery_board_point(board, target_x, target_z)
		var mouth_radius := maxf(1.0, float(target.get("mouth_radius", 2200)))
		var rx := maxf(7.0, center.distance_to(_project_delivery_board_point(board, target_x + mouth_radius, target_z)))
		var cup_depth := maxf(2400.0, float(target.get("cup_depth", 5200)))
		var bottom := _project_delivery_board_point(board, target_x, target_z - cup_depth)
		var reward: Dictionary = target.get("reward", {}) if typeof(target.get("reward", {})) == TYPE_DICTIONARY else {}
		var label := str(target.get("label", "+%d" % int(reward.get("count", 0))))
		# A readable catch cup has a wide illuminated mouth, side walls, and a
		# visible bucket below the capture plane.  The prior concentric circles read
		# as abstract score dots and hid which side of the target actually caught a
		# descending token.
		var depth_px := clampf(bottom.y - center.y, 13.0, 28.0)
		var lip_left := center + Vector2(-rx - 4.0, 0.0)
		var lip_right := center + Vector2(rx + 4.0, 0.0)
		var bucket_left := center + Vector2(-rx * 0.62, depth_px)
		var bucket_right := center + Vector2(rx * 0.62, depth_px)
		surface.surface_filled_polygon(PackedVector2Array([lip_left, lip_right, bucket_right, bucket_left]), colors["side"].darkened(0.12))
		surface.draw_line(lip_left, bucket_left, colors["trim"], 3.0)
		surface.draw_line(lip_right, bucket_right, colors["trim"], 3.0)
		surface.draw_line(bucket_left, bucket_right, colors["trim"], 3.0)
		surface.draw_line(lip_left, lip_right, colors["light"], 5.0)
		surface.draw_line(lip_left + Vector2(3, 1), lip_right - Vector2(3, -1), Color("#06090c"), 2.0)
		surface.surface_label_centered(label, Rect2(center.x - 22.0, center.y + 5.0, 44.0, depth_px - 4.0), 9, colors["light"])


func _draw_filled_peg_ellipse(surface, center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array() # SA2_PER_FRAME_OK: fixed eight-point micro-pin primitive.
	for unit in PEG_OCTAGON:
		points.append(center + Vector2(unit.x * rx, unit.y * ry))
	surface.surface_filled_polygon(points, color)


func _draw_interpolated_bodies(surface, state: Dictionary, colors: Dictionary, cabinet: Dictionary) -> void:
	_ensure_coin_batch()
	var current: Array = state.get("coin_pusher_bodies", []) if typeof(state.get("coin_pusher_bodies", [])) == TYPE_ARRAY else []
	var previous: Array = state.get("coin_pusher_previous_bodies", []) if typeof(state.get("coin_pusher_previous_bodies", [])) == TYPE_ARRAY else []
	var alpha := 1.0 if bool(state.get("reduce_motion", false)) else clampf(float(state.get("coin_pusher_interpolation_alpha", 1.0)), 0.0, 1.0)
	if _draw_native_interpolated_bodies(surface, state, cabinet, current, previous, alpha):
		return
	var aligned_previous := alpha < 0.999 and _body_order_matches(current, previous)
	var previous_by_id := {}
	if alpha < 0.999 and not aligned_previous:
		for value in previous:
			if typeof(value) == TYPE_DICTIONARY:
				previous_by_id[str((value as Dictionary).get("id", ""))] = value
	var sorted_indices := _depth_sorted_body_indices(current, int(state.get("coin_pusher_presentation_view_serial", state.get("coin_pusher_liveness_ticks", 0))))
	var count := mini(BATCH_CAPACITY, sorted_indices.size())
	if _coin_multimesh.instance_count != count:
		_coin_multimesh.instance_count = count
	_coin_multimesh.visible_instance_count = count
	_coin_transform_buffer.resize(count * 3)
	_coin_color_buffer.resize(count)
	var feature_labels: Array = []
	var airborne_shadows: Array = []
	var geometry: Dictionary = state.get("coin_pusher_geometry", {}) if typeof(state.get("coin_pusher_geometry", {})) == TYPE_DICTIONARY else {}
	var apparatus: Dictionary = state.get("coin_pusher_apparatus", {}) if typeof(state.get("coin_pusher_apparatus", {})) == TYPE_DICTIONARY else {}
	var board := _delivery_board(apparatus, geometry)
	var board_y := int(board.get("y", 0))
	var board_z_bottom := float(board.get("z_bottom", 0.0))
	var body_colors: Dictionary = cabinet.get("body_colors", {}) if typeof(cabinet.get("body_colors", {})) == TYPE_DICTIONARY else {}
	var default_body_color := Color(str(body_colors.get("default", NEUTRAL_CABINET["body_colors"]["default"])))
	var body_color_cache := {"coin": default_body_color}
	var labels: Dictionary = cabinet.get("body_labels", {}) if typeof(cabinet.get("body_labels", {})) == TYPE_DICTIONARY else {}
	for instance_index in range(count):
		var body_index := int(sorted_indices[instance_index])
		var body: Dictionary = current[body_index]
		var body_id := str(body.get("id", ""))
		var kind := str(body.get("kind", "coin"))
		var x := float(int(body.get("x", 0)))
		var y := float(int(body.get("y", 0)))
		var z := float(int(body.get("z", 0)))
		if alpha < 0.999:
			var prior: Dictionary = previous[body_index] if aligned_previous else previous_by_id.get(body_id, body)
			var previous_x := int(prior.get("x", body.get("x", 0)))
			var previous_y := int(prior.get("y", body.get("y", 0)))
			var previous_z := int(prior.get("z", body.get("z", 0)))
			x = lerpf(float(previous_x), x, alpha)
			y = lerpf(float(previous_y), y, alpha)
			z = lerpf(float(previous_z), z, alpha)
		var falling := str(body.get("rest_state", "")) == "falling"
		var on_delivery_board := falling and absi(int(round(y)) - board_y) <= int(body.get("radius", 2350)) and z >= board_z_bottom
		var point := _project_delivery_board_point(board, x, z) if on_delivery_board else _project_f(x, y, z)
		if not body_color_cache.has(kind):
			body_color_cache[kind] = Color(str(body_colors.get(kind, body_colors.get("default", NEUTRAL_CABINET["body_colors"]["default"]))))
		var body_color: Color = body_color_cache.get(kind, default_body_color)
		var frame := posmod(body_id.hash(), ROTATION_VARIANTS.size())
		var rotation: float = ROTATION_VARIANTS[frame]
		var depth_scale := lerpf(1.0, REAR_WIDTH_FACTOR, clampf(y / _world_back_y, 0.0, 1.0))
		var radius_scale := float(body.get("radius", int(_coin_radius))) / _coin_radius
		var visual_scale := depth_scale * radius_scale
		var transform := Transform2D(rotation, Vector2(visual_scale, visual_scale), 0.0, point)
		var transform_offset := instance_index * 3
		_coin_transform_buffer[transform_offset] = transform.x
		_coin_transform_buffer[transform_offset + 1] = transform.y
		_coin_transform_buffer[transform_offset + 2] = transform.origin
		_coin_color_buffer[instance_index] = body_color
		if falling:
			var shadow_point := _project_delivery_board_point(board, x, z) if on_delivery_board and z > board_z_bottom + _coin_height else _project_f(x, y, board_z_bottom)
			airborne_shadows.append({"point": shadow_point, "scale": visual_scale})
		if kind != "coin":
			feature_labels.append({"kind": kind, "point": point})
	for shadow_value in airborne_shadows:
		var shadow: Dictionary = shadow_value
		var shadow_scale := float(shadow.get("scale", 1.0))
		_draw_ellipse(surface, (shadow.get("point", Vector2.ZERO) as Vector2) + AIRBORNE_SHADOW_OFFSET, COIN_RX * 0.94 * shadow_scale, COIN_RY * 0.76 * shadow_scale, Color(0, 0, 0, 0.80), 0)
	# One ordered batch is the exact depth order above; seeded rotation variants
	# are per instance and never repartition or reorder overlapping bodies.
	# These compatibility array setters cross GDScript/WebAssembly twice and run
	# the per-instance renderer updates below that boundary. The visible order,
	# transforms, colors and one draw_multimesh command are unchanged.
	_coin_multimesh.call("_set_transform_2d_array", _coin_transform_buffer)
	_coin_multimesh.call("_set_color_array", _coin_color_buffer)
	surface.surface_present_multimesh_batch(_coin_multimesh, _coin_texture, null, DESIGN_SIZE)
	for feature_value in feature_labels:
		var feature: Dictionary = feature_value
		var point: Vector2 = feature["point"]
		var kind := str(feature.get("kind", ""))
		var label := str(labels.get(kind, kind.left(1).to_upper()))
		if not label.is_empty():
			surface.surface_reel_symbol_label(label, Rect2(point - Vector2(9, 8), Vector2(18, 16)), 10, Color("#111722"))


func _draw_native_interpolated_bodies(surface, state: Dictionary, cabinet: Dictionary, current: Array, previous: Array, alpha: float) -> bool:
	var geometry: Dictionary = state.get("coin_pusher_geometry", {}) if typeof(state.get("coin_pusher_geometry", {})) == TYPE_DICTIONARY else {}
	var apparatus: Dictionary = state.get("coin_pusher_apparatus", {}) if typeof(state.get("coin_pusher_apparatus", {})) == TYPE_DICTIONARY else {}
	var body_colors: Dictionary = cabinet.get("body_colors", {}) if typeof(cabinet.get("body_colors", {})) == TYPE_DICTIONARY else {}
	var batch := CoinPusherSolverAPI.native_live_render_batch({
		"world_width": _world_width,
		"world_back_y": _world_back_y,
		"coin_height": _coin_height,
		"coin_radius": _coin_radius,
		"board": _delivery_board(apparatus, geometry),
		"body_colors": body_colors,
	}, current, previous, alpha)
	if batch.is_empty() or typeof(batch.get("buffer", null)) != TYPE_PACKED_FLOAT32_ARRAY:
		return false
	var count := int(batch.get("count", 0))
	if _coin_multimesh.instance_count != count:
		_coin_multimesh.instance_count = count
	_coin_multimesh.visible_instance_count = count
	for shadow_value in batch.get("shadows", []):
		var shadow: Dictionary = shadow_value
		var shadow_scale := float(shadow.get("scale", 1.0))
		_draw_ellipse(surface, (shadow.get("point", Vector2.ZERO) as Vector2) + AIRBORNE_SHADOW_OFFSET, COIN_RX * 0.94 * shadow_scale, COIN_RY * 0.76 * shadow_scale, Color(0, 0, 0, 0.80), 0)
	_coin_multimesh.buffer = batch["buffer"] as PackedFloat32Array
	surface.surface_present_multimesh_batch(_coin_multimesh, _coin_texture, null, DESIGN_SIZE)
	var labels: Dictionary = cabinet.get("body_labels", {}) if typeof(cabinet.get("body_labels", {})) == TYPE_DICTIONARY else {}
	for feature_value in batch.get("features", []):
		var feature: Dictionary = feature_value
		var point: Vector2 = feature["point"]
		var kind := str(feature.get("kind", ""))
		var label := str(labels.get(kind, kind.left(1).to_upper()))
		if not label.is_empty():
			surface.surface_reel_symbol_label(label, Rect2(point - Vector2(9, 8), Vector2(18, 16)), 10, Color("#111722"))
	return true


func draw_static_cache_layer(surface, state: Dictionary, layer_index: int) -> void:
	_configure_projection(state)
	var cabinet := _cabinet(state)
	var colors := _colors(cabinet)
	if bool(state.get("coin_pusher_locked", false)):
		colors = _locked_colors(colors)
	surface.surface_begin_design_space(DESIGN_SIZE)
	match layer_index:
		0:
			_draw_floor_and_shell(surface, cabinet, colors)
		1:
			_draw_playfield(surface, state, colors, cabinet, true, false, false, false)
		2:
			_draw_playfield(surface, state, colors, cabinet, false, false, true, false)
	surface.surface_end_design_space()


func _prepare_static_cache(surface, state: Dictionary) -> bool:
	# The cache contains only design-space commands whose complete dependencies
	# are listed here. Backglass content, moving platform/bodies, glass, hardware,
	# hover/hit/control state and overlays remain on the live surface every draw.
	if not OS.has_feature("web") and not bool(state.get("coin_pusher_static_cache_test", false)):
		_static_cache_fallback_reason = "non_web_runtime"
		return false
	var transform: Dictionary = surface.debug_design_space_transform(DESIGN_SIZE)
	var design_scale: Vector2 = transform.get("design_scale", Vector2.ONE)
	var board_rect: Rect2 = surface.board_rect()
	# Render at the live surface's complete logical-pixel extent. That gives the
	# cache canvas the identical board scale/offset as the production canvas and
	# lets the opaque cabinet texture composite one-for-one without resampling.
	if design_scale != Vector2.ONE or board_rect.size.x < 1.0 or board_rect.size.y < 1.0:
		_static_cache_key = ""
		_static_cache_pending = true
		_static_cache_fallback_reason = "unsupported_design_transform"
		return false
	var cache_pixel_size := Vector2i(maxi(1, int(round(surface.size.x))), maxi(1, int(round(surface.size.y))))
	if not is_instance_valid(_static_cache_host) or _static_cache_host != surface:
		_recreate_static_cache_for_host(surface)
	var effective_font: Font = surface.get_theme_default_font()
	_bind_static_cache_font(effective_font)
	var font_identity: int = effective_font.get_instance_id() if effective_font != null else 0
	# The full snapshot owns the nested static-content fingerprint. Keep the
	# live draw key scalar-only: serializing the authored peg/apparatus trees on
	# every Web draw was itself a material part of the measured draw callback.
	var key := "%d:%d|%.3f:%.3f:%.3f:%.3f|%.4f:%.4f|%d|%s|%d" % [
		cache_pixel_size.x,
		cache_pixel_size.y,
		board_rect.position.x,
		board_rect.position.y,
		board_rect.size.x,
		board_rect.size.y,
		(transform.get("scale", Vector2.ONE) as Vector2).x,
		(transform.get("scale", Vector2.ONE) as Vector2).y,
		font_identity,
		str(state.get("coin_pusher_static_content_key", "missing")),
		1 if bool(state.get("coin_pusher_locked", false)) else 0,
	]
	if _static_cache_viewports.is_empty():
		var canvas_script: Script = load("res://scripts/games/coin_pusher/coin_pusher_static_cache_canvas.gd")
		for layer_index in range(3):
			var viewport := SubViewport.new()
			viewport.name = "CoinPusherStaticCache%d" % layer_index
			viewport.size = cache_pixel_size
			viewport.transparent_bg = true
			viewport.disable_3d = true
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			var canvas: Control = canvas_script.new() as Control
			canvas.name = "StaticLayer%d" % layer_index
			canvas.set("static_renderer", self)
			canvas.set("static_layer_index", layer_index)
			canvas.theme = _static_cache_theme_for_font(effective_font)
			canvas.position = Vector2.ZERO
			canvas.size = Vector2(cache_pixel_size)
			canvas.connect("static_cache_drawn", _on_static_cache_drawn.bind(layer_index))
			viewport.add_child(canvas)
			surface.add_child(viewport)
			_static_cache_viewports.append(viewport)
			_static_cache_canvases.append(canvas)
	if key != _static_cache_key:
		_static_cache_key = key
		_static_cache_pixel_size = cache_pixel_size
		_static_cache_pending = true
		_static_cache_pending_layers = [true, true, true]
		_static_cache_rebuild_serial += 1
		_static_cache_fallback_reason = "rebuild_pending"
		for layer_index in range(3):
			var viewport := _static_cache_viewports[layer_index]
			var canvas := _static_cache_canvases[layer_index]
			viewport.size = cache_pixel_size
			canvas.size = Vector2(cache_pixel_size)
			canvas.theme = _static_cache_theme_for_font(effective_font)
			canvas.set("static_state", state.duplicate(false))
			canvas.queue_redraw()
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _static_cache_pending:
		return false
	_static_cache_fallback_reason = ""
	return true


func _draw_static_cache_texture(surface, layer_index: int) -> void:
	if layer_index < 0 or layer_index >= _static_cache_viewports.size():
		return
	# This method is entered inside the production design transform. Composite
	# the full-surface cache in unscaled surface pixels, then restore the exact
	# design transform for every live layer that follows.
	surface.surface_end_design_space()
	surface.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	surface.draw_texture_rect(_static_cache_viewports[layer_index].get_texture(), Rect2(Vector2.ZERO, surface.size), false)
	surface.surface_begin_design_space(DESIGN_SIZE)


func _on_static_cache_drawn(layer_index: int) -> void:
	if layer_index >= 0 and layer_index < _static_cache_pending_layers.size():
		_static_cache_pending_layers[layer_index] = false
	_static_cache_pending = _static_cache_pending_layers.has(true)
	_static_cache_render_serial += 1
	if not _static_cache_pending and is_instance_valid(_static_cache_host):
		_static_cache_host.queue_redraw()


func _recreate_static_cache_for_host(surface: Control) -> void:
	# A renderer instance survives surface re-entry. Never reuse a viewport that
	# is parented to the previous canvas: its inherited theme/layout and render
	# lifetime belong to that host.
	for viewport in _static_cache_viewports:
		if is_instance_valid(viewport):
			viewport.queue_free()
	_static_cache_viewports.clear()
	_static_cache_canvases.clear()
	_static_cache_host = surface
	_static_cache_key = ""
	_static_cache_pending = true
	_static_cache_pending_layers = [true, true, true]
	_static_cache_fallback_reason = "host_reentry"


func _bind_static_cache_font(font: Font) -> void:
	if _static_cache_font == font:
		return
	if is_instance_valid(_static_cache_font) and _static_cache_font.changed.is_connected(_on_static_cache_font_changed):
		_static_cache_font.changed.disconnect(_on_static_cache_font_changed)
	_static_cache_font = font
	if is_instance_valid(_static_cache_font) and not _static_cache_font.changed.is_connected(_on_static_cache_font_changed):
		_static_cache_font.changed.connect(_on_static_cache_font_changed)
	_static_cache_key = ""
	_static_cache_pending = true
	_static_cache_pending_layers = [true, true, true]
	_static_cache_fallback_reason = "effective_font_changed"


func _on_static_cache_font_changed() -> void:
	# The static layer supplies every color and size explicitly; the effective
	# default Font is its only theme-derived dependency and can mutate in place.
	_static_cache_key = ""
	_static_cache_pending = true
	_static_cache_pending_layers = [true, true, true]
	_static_cache_fallback_reason = "effective_font_changed"
	if is_instance_valid(_static_cache_host):
		_static_cache_host.queue_redraw()


func _static_cache_theme_for_font(font: Font) -> Theme:
	var cache_theme := Theme.new()
	cache_theme.default_font = font
	return cache_theme


func debug_static_cache_for_test() -> Dictionary:
	return {
		"active": not _static_cache_pending and not _static_cache_key.is_empty(),
		"pending": _static_cache_pending,
		"key": _static_cache_key,
		"host_instance_id": _static_cache_host.get_instance_id() if is_instance_valid(_static_cache_host) else 0,
		"viewport_count": _static_cache_viewports.size(),
		"viewport_parent_instance_id": _static_cache_viewports[0].get_parent().get_instance_id() if not _static_cache_viewports.is_empty() and is_instance_valid(_static_cache_viewports[0]) and is_instance_valid(_static_cache_viewports[0].get_parent()) else 0,
		"font_instance_id": _static_cache_font.get_instance_id() if is_instance_valid(_static_cache_font) else 0,
		"pixel_size": _static_cache_pixel_size,
		"render_serial": _static_cache_render_serial,
		"rebuild_serial": _static_cache_rebuild_serial,
		"fallback_reason": _static_cache_fallback_reason,
	}


func debug_static_cache_command_equivalence_for_test() -> Dictionary:
	# Layer textures replace only the commands named for that layer. Expanding
	# those textures at their three call sites yields the unchanged production
	# painter's order; every stateful/dynamic stage remains a live command.
	var uncached := [
		"shell", "backglass", "playfield_static_pre", "platform",
		"playfield_static_post", "bodies", "apron", "glass", "hardware",
	]
	var cached_expanded := [
		"shell", "backglass", "playfield_static_pre", "platform",
		"playfield_static_post", "bodies", "apron", "glass", "hardware",
	]
	return {
		"uncached": uncached,
		"cached_expanded": cached_expanded,
		"exact_order_match": uncached == cached_expanded,
		"layers": [
			{"index": 0, "commands": ["shell"]},
			{"index": 1, "commands": ["playfield_static_pre"]},
			{"index": 2, "commands": ["playfield_static_post"]},
		],
		"live_commands": ["backglass", "platform", "bodies", "apron", "glass", "hardware"],
	}


func _depth_sorted_body_indices(bodies: Array, presentation_view_serial: int) -> Array:
	var first_id := str((bodies[0] as Dictionary).get("id", "")) if not bodies.is_empty() and typeof(bodies[0]) == TYPE_DICTIONARY else ""
	var last_id := str((bodies[bodies.size() - 1] as Dictionary).get("id", "")) if not bodies.is_empty() and typeof(bodies[bodies.size() - 1]) == TYPE_DICTIONARY else ""
	var key := "%d:%d:%s:%s" % [presentation_view_serial, bodies.size(), first_id, last_id]
	# Presentation serials are session-local. A different machine can have the
	# same serial/count/end IDs while its middle bodies require another order.
	# Retaining the exact source Array makes cache reuse session-view-specific;
	# a changed serial on the same Array still misses through the key.
	if key == _sorted_body_cache_key and is_same(bodies, _sorted_body_cache_source):
		return _sorted_body_cache
	_sorted_body_cache.resize(bodies.size())
	for body_index in range(bodies.size()):
		_sorted_body_cache[body_index] = body_index
	_sorted_body_cache.sort_custom(func(a_index: int, b_index: int) -> bool:
		var a: Dictionary = bodies[a_index]
		var b: Dictionary = bodies[b_index]
		var a_key := int(a.get("y", 0)) * 100000 - int(a.get("z", 0))
		var b_key := int(b.get("y", 0)) * 100000 - int(b.get("z", 0))
		return a_key > b_key if a_key != b_key else str(a.get("id", "")) < str(b.get("id", ""))
	)
	_sorted_body_cache_key = key
	_sorted_body_cache_source = bodies
	return _sorted_body_cache


func debug_batch_body_order_for_test(bodies: Array, liveness_tick: int) -> Array:
	var result: Array = []
	for body_index in _depth_sorted_body_indices(bodies, liveness_tick):
		result.append(str((bodies[int(body_index)] as Dictionary).get("id", "")))
	return result


func debug_interpolated_bodies_for_test(current: Array, previous: Array, alpha: float, presentation_view_serial: int) -> Array:
	var aligned_previous := _body_order_matches(current, previous)
	var previous_by_id := {}
	if not aligned_previous:
		for value in previous:
			if typeof(value) == TYPE_DICTIONARY:
				previous_by_id[str((value as Dictionary).get("id", ""))] = value
	var result: Array = []
	for body_index_value in _depth_sorted_body_indices(current, presentation_view_serial):
		var body_index := int(body_index_value)
		var body: Dictionary = current[body_index]
		var prior: Dictionary = previous[body_index] if aligned_previous else previous_by_id.get(str(body.get("id", "")), body)
		result.append({
			"id": str(body.get("id", "")),
			"x": lerpf(float(prior.get("x", body.get("x", 0))), float(body.get("x", 0)), alpha),
			"y": lerpf(float(prior.get("y", body.get("y", 0))), float(body.get("y", 0)), alpha),
			"z": lerpf(float(prior.get("z", body.get("z", 0))), float(body.get("z", 0)), alpha),
		})
	return result


func _body_order_matches(current: Array, previous: Array) -> bool:
	if current.size() != previous.size():
		return false
	for body_index in range(current.size()):
		if typeof(current[body_index]) != TYPE_DICTIONARY or typeof(previous[body_index]) != TYPE_DICTIONARY \
				or str((current[body_index] as Dictionary).get("id", "")) != str((previous[body_index] as Dictionary).get("id", "")):
			return false
	return true


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
	result.instance_count = 0
	result.visible_instance_count = 0
	result.mesh = _coin_mesh
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


func _draw_payout_edge_face(surface, top_left: Vector2, top_right: Vector2, bottom_left: Vector2, bottom_right: Vector2, colors: Dictionary) -> void:
	var face := PackedVector2Array([top_left, top_right, bottom_right, bottom_left]) # SA2_PER_FRAME_OK: bounded four-point foreground apron.
	surface.surface_filled_polygon(face, colors["deck"].darkened(0.30)) # SA2_PER_FRAME_OK: fixed opaque four-point shelf apron.
	surface.draw_line(top_left, top_right, colors["trim"], 3.0)
	surface.draw_line(bottom_left, bottom_right, colors["side"].darkened(0.24), 2.0)
	surface.draw_line(top_left, bottom_left, colors["trim"].darkened(0.28), 1.0)
	surface.draw_line(top_right, bottom_right, colors["trim"].darkened(0.28), 1.0)


func _draw_glass(surface, colors: Dictionary) -> void:
	surface.draw_line(PLAYFIELD_RECT.position + Vector2(18, 18), PLAYFIELD_RECT.position + Vector2(244, 18), Color(1, 1, 1, 0.28), 3.0)
	surface.draw_line(PLAYFIELD_RECT.position + Vector2(20, 24), PLAYFIELD_RECT.position + Vector2(122, 154), Color(1, 1, 1, 0.09), 18.0)
	surface.draw_rect(PLAYFIELD_RECT, Color(colors["glass"], 0.45), false, 2.0)


func _draw_hardware(surface, state: Dictionary, colors: Dictionary) -> void:
	var bindings: Dictionary = state.get("surface_action_bindings", {}) if typeof(state.get("surface_action_bindings", {})) == TYPE_DICTIONARY else {}
	var apparatus: Dictionary = state.get("coin_pusher_apparatus", {}) if typeof(state.get("coin_pusher_apparatus", {})) == TYPE_DICTIONARY else {}
	var layout := _entry_hardware_layout(state)
	if str(apparatus.get("type", "rail_slot")) == "hole_set":
		var targets: Array = layout.get("targets", []) if typeof(layout.get("targets", [])) == TYPE_ARRAY else []
		for target_value in targets:
			if typeof(target_value) != TYPE_DICTIONARY:
				continue
			var target: Dictionary = target_value
			var hole_index := int(target.get("index", 0))
			var hole_rect: Rect2 = target.get("rect", Rect2())
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
		var drag_rect: Rect2 = layout.get("drag_rect", Rect2())
		var rail_start: Vector2 = layout.get("rail_start", drag_rect.position)
		var rail_end: Vector2 = layout.get("rail_end", drag_rect.end)
		var carriage_point: Vector2 = layout.get("carriage", drag_rect.get_center())
		var drag_enabled := _binding_enabled(bindings, "coin_pusher_carriage_left") and _binding_enabled(bindings, "coin_pusher_carriage_right")
		if drag_enabled:
			surface.surface_add_drag_hit(drag_rect, "coin_pusher_carriage_drag")
		surface.draw_line(rail_start, rail_end, colors["trim"].darkened(0.18), 6.0)
		surface.draw_rect(Rect2(carriage_point - Vector2(11, 21), Vector2(22, 42)), colors["side"])
		surface.draw_rect(Rect2(carriage_point - Vector2(11, 21), Vector2(22, 42)), colors["light"], false, 2.0)
		surface.draw_line(carriage_point + Vector2(0, 9), carriage_point + Vector2(0, 29), colors["light"], 3.0)
		_draw_small_hardware(surface, Rect2(54, 356, 42, 34), "<", "coin_pusher_carriage_left", colors, _binding_enabled(bindings, "coin_pusher_carriage_left"))
		_draw_small_hardware(surface, Rect2(102, 356, 42, 34), ">", "coin_pusher_carriage_right", colors, _binding_enabled(bindings, "coin_pusher_carriage_right"))
	var stop_engaged := bool(state.get("coin_pusher_skill_stop_engaged", false))
	var stop_rect := Rect2(154, 352, 88, 48)
	surface.draw_circle(stop_rect.get_center(), 27.0, colors["light"] if stop_engaged else Color("#b73538"))
	surface.draw_circle(stop_rect.get_center(), 27.0, Color.WHITE if surface.surface_region_hovered("coin_pusher_skill_stop") else colors["trim"], false, 3.0)
	surface.surface_label_centered("RELEASE" if stop_engaged else "STOP", stop_rect, 12, Color("#10141d"))
	if _binding_enabled(bindings, "coin_pusher_skill_stop"):
		surface.surface_add_hit(stop_rect, "coin_pusher_skill_stop")
	var tray_rect := Rect2(250, 352, 280, 58)
	surface.draw_rect(tray_rect, Color("#06090c"))
	surface.draw_rect(tray_rect, colors["trim"], false, 3.0)
	_draw_tray_heap(surface, tray_rect, int(state.get("coin_pusher_tray_count", 0)), colors)
	var collect_enabled := bool((bindings.get("coin_pusher_collect", {}) as Dictionary).get("enabled", false)) if typeof(bindings.get("coin_pusher_collect", {})) == TYPE_DICTIONARY else false
	var tray_label_rect := Rect2(tray_rect.position + Vector2(5, 3), Vector2(tray_rect.size.x - 10, 18))
	surface.surface_label_centered("COLLECT  %d  ($%d)" % [int(state.get("coin_pusher_tray_count", 0)), int(state.get("coin_pusher_tray_value", 0))], tray_label_rect, 11, colors["light"] if collect_enabled else Color(colors["light"], 0.44))
	if collect_enabled:
		surface.surface_add_hit(tray_rect, "coin_pusher_collect")
	var slot_rect := Rect2(540, 352, 72, 48)
	surface.draw_rect(slot_rect, colors["side"].lightened(0.08))
	surface.draw_circle(Vector2(576, 374), 19.0, colors["trim"].darkened(0.20))
	surface.draw_circle(Vector2(576, 374), 15.0, colors["side"])
	surface.draw_line(Vector2(566, 374), Vector2(586, 374), Color("#020305"), 5.0)
	var queued := maxi(0, int(state.get("coin_pusher_drop_queue_count", 0)))
	var charging := maxi(0, int(state.get("coin_pusher_drop_charge_count", 0)))
	var drop_label := "HOLD %d" % charging if charging > 0 else "QUEUE %d" % queued if queued > 0 else "DROP / HOLD"
	surface.surface_label_centered(drop_label, Rect2(538, 391, 76, 9), 8, colors["light"])
	var drop_enabled := _binding_enabled(bindings, "coin_pusher_drop")
	if drop_enabled:
		surface.surface_add_hold_hit(slot_rect, "coin_pusher_drop_charge")
	var nudge_rect := Rect2(620, 352, 88, 48)
	var nudge_enabled := _binding_enabled(bindings, "coin_pusher_nudge")
	var nudge_hovered: bool = nudge_enabled and bool(surface.surface_region_hovered("coin_pusher_nudge"))
	surface.draw_rect(nudge_rect, colors["side"].lightened(0.08 if nudge_hovered else 0.0))
	surface.draw_circle(Vector2(635, 363), 3.0, colors["trim"])
	surface.draw_circle(Vector2(693, 363), 3.0, colors["trim"])
	surface.draw_line(Vector2(642, 373), Vector2(686, 373), Color.WHITE if nudge_hovered else colors["trim"], 8.0)
	surface.draw_line(Vector2(642, 373), Vector2(642, 385), colors["trim"], 4.0)
	surface.draw_line(Vector2(686, 373), Vector2(686, 385), colors["trim"], 4.0)
	surface.surface_label_centered("NUDGE", Rect2(628, 384, 72, 12), 8, colors["light"] if nudge_enabled else Color(colors["light"], 0.38))
	if nudge_enabled:
		surface.surface_add_hit(nudge_rect, "coin_pusher_nudge")
	surface.surface_label_centered(str(state.get("coin_pusher_tell_label", "steady")).to_upper(), Rect2(716, 380, 116, 16), 9, colors["light"])
	_draw_feature_hardware(surface, state, bindings, colors)


func _draw_feature_hardware(surface, state: Dictionary, bindings: Dictionary, colors: Dictionary) -> void:
	var descriptor: Dictionary = state.get("coin_pusher_feature_hardware", {}) if typeof(state.get("coin_pusher_feature_hardware", {})) == TYPE_DICTIONARY else {}
	_draw_selector_groups(surface, descriptor, bindings, colors)
	_draw_feature_panels(surface, descriptor, bindings, colors)


func _draw_selector_groups(surface, descriptor: Dictionary, bindings: Dictionary, colors: Dictionary) -> void:
	var groups: Array = descriptor.get("selector_groups", []) if typeof(descriptor.get("selector_groups", [])) == TYPE_ARRAY else []
	for group_value in groups:
		var group: Dictionary = group_value
		var options: Array = group.get("options", []) if typeof(group.get("options", [])) == TYPE_ARRAY else []
		if options.is_empty():
			continue
		var group_rect: Rect2 = group.get("rect", Rect2())
		var width := group_rect.size.x / float(options.size())
		for option_index in range(options.size()):
			if typeof(options[option_index]) != TYPE_DICTIONARY:
				continue
			var option: Dictionary = options[option_index]
			var action := str(option.get("action", ""))
			var option_id := str(option.get("id", ""))
			var rect := Rect2(group_rect.position + Vector2(width * option_index, 0.0), Vector2(width - 2.0, group_rect.size.y))
			var enabled := _binding_enabled(bindings, action)
			var selected := option_id == str(group["selected"])
			surface.draw_rect(rect, colors["light"] if selected else colors["side"])
			surface.draw_rect(rect, colors["trim"] if enabled else Color(colors["trim"], 0.32), false, 1.0)
			surface.surface_label_centered(str(option.get("label", option_id)).to_upper(), rect.grow(-1.0), 7, Color("#10141d") if selected else Color(colors["light"], 0.85 if enabled else 0.32))
			if enabled and not action.is_empty():
				surface.surface_add_exact_hit(rect, action, int(option.get("index", option_index)))


func _draw_feature_panels(surface, descriptor: Dictionary, bindings: Dictionary, colors: Dictionary) -> void:
	var panels: Array = descriptor.get("panels", []) if typeof(descriptor.get("panels", [])) == TYPE_ARRAY else []
	for panel_value in panels:
		if typeof(panel_value) != TYPE_DICTIONARY:
			continue
		var panel: Dictionary = panel_value
		var panel_rect: Rect2 = panel.get("rect", Rect2())
		surface.draw_rect(panel_rect, colors["side"].darkened(0.12))
		surface.draw_rect(panel_rect, colors["trim"], false, 2.0)
		for control_value in panel.get("controls", []):
			if typeof(control_value) != TYPE_DICTIONARY:
				continue
			var control: Dictionary = control_value
			var rect: Rect2 = control.get("rect", Rect2())
			var action := str(control.get("action", ""))
			var selected := bool(control.get("selected", false))
			var enabled := _binding_enabled(bindings, action) if not action.is_empty() else false
			var fill: Color = colors["light"] if selected else colors["body"].lightened(0.10 if bool(control.get("lit", false)) else 0.0)
			surface.draw_rect(rect, fill)
			surface.draw_rect(rect, colors["light"] if selected else colors["trim"], false, 1.0)
			surface.surface_label_centered(str(control.get("label", "")), rect.grow(-1.0), int(control.get("font_size", 8)), Color("#10141d") if selected else colors["light"])
			if enabled:
				surface.surface_add_exact_hit(rect, action, int(control.get("index", 0)))


func _feature_hardware_action_ids(state: Dictionary) -> Array:
	var result: Array = []
	var descriptor: Dictionary = state.get("coin_pusher_feature_hardware", {}) if typeof(state.get("coin_pusher_feature_hardware", {})) == TYPE_DICTIONARY else {}
	for group_value in descriptor.get("selector_groups", []):
		if typeof(group_value) == TYPE_DICTIONARY:
			for option_value in (group_value as Dictionary).get("options", []):
				if typeof(option_value) == TYPE_DICTIONARY and not str((option_value as Dictionary).get("action", "")).is_empty():
					result.append(str((option_value as Dictionary).get("action", "")))
	for panel_value in descriptor.get("panels", []):
		if typeof(panel_value) == TYPE_DICTIONARY:
			for control_value in (panel_value as Dictionary).get("controls", []):
				if typeof(control_value) == TYPE_DICTIONARY and not str((control_value as Dictionary).get("action", "")).is_empty():
					result.append(str((control_value as Dictionary).get("action", "")))
	return result


func _hardware_actions(state: Dictionary) -> Array:
	var apparatus: Dictionary = state.get("coin_pusher_apparatus", {}) if typeof(state.get("coin_pusher_apparatus", {})) == TYPE_DICTIONARY else {}
	var bindings: Dictionary = state.get("surface_action_bindings", {}) if typeof(state.get("surface_action_bindings", {})) == TYPE_DICTIONARY else {}
	var actions: Array = []
	for action in ["coin_pusher_drop", "coin_pusher_drop_charge", "coin_pusher_skill_stop", "coin_pusher_collect", "coin_pusher_nudge"]:
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
	var result: Array = ["coin_pusher_drop", "coin_pusher_drop_charge", "coin_pusher_skill_stop", "coin_pusher_collect", "coin_pusher_nudge"]
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
	var geometry: Dictionary = state.get("coin_pusher_geometry", {}) if typeof(state.get("coin_pusher_geometry", {})) == TYPE_DICTIONARY else {}
	var board := _delivery_board(apparatus, geometry)
	var z_top := float(board.get("z_top", 24000))
	if str(apparatus.get("type", "rail_slot")) == "hole_set":
		var targets: Array = []
		var holes: Array = apparatus.get("holes", []) if typeof(apparatus.get("holes", [])) == TYPE_ARRAY else []
		for hole_index in range(holes.size()):
			var center := _project_delivery_board_point(board, float(holes[hole_index]), z_top)
			targets.append({"index": hole_index, "action": "coin_pusher_hole_%d" % hole_index, "center": center, "rect": Rect2(center - Vector2(22, 22), Vector2(44, 44))})
		return {"type": "hole_set", "targets": targets}
	var rail: Dictionary = apparatus.get("rail", {}) if typeof(apparatus.get("rail", {})) == TYPE_DICTIONARY else {}
	var rail_min := int(rail.get("x_min", 8000))
	var rail_max := maxi(rail_min + 1, int(rail.get("x_max", 92000)))
	var carriage := clampi(int(state.get("coin_pusher_carriage_x", (rail_min + rail_max) / 2)), rail_min, rail_max)
	var rail_start := _project_delivery_board_point(board, float(rail_min), z_top)
	var rail_end := _project_delivery_board_point(board, float(rail_max), z_top)
	var carriage_point := _project_delivery_board_point(board, float(carriage), z_top)
	return {"type": "rail_slot", "rail_start": rail_start, "rail_end": rail_end, "carriage": carriage_point, "drag_rect": Rect2(Vector2(minf(rail_start.x, rail_end.x), rail_start.y - 22.0), Vector2(absf(rail_end.x - rail_start.x), 44.0))}


func debug_entry_hardware_layout_for_test(state: Dictionary) -> Dictionary:
	_configure_projection(state)
	return _entry_hardware_layout(state)


func _draw_small_hardware(surface, rect: Rect2, label: String, action: String, colors: Dictionary, enabled: bool) -> void:
	var hovered: bool = bool(surface.surface_region_hovered(action))
	var body_color: Color = colors["body"]
	surface.draw_rect(rect, body_color.lightened(0.08 if hovered else 0.0))
	surface.draw_rect(rect, Color.WHITE if hovered else colors["trim"], false, 2.0)
	surface.surface_label_centered(label, rect.grow(-3.0), 12, colors["light"])
	if enabled:
		surface.surface_add_hit(rect, action)


func _draw_tray_heap(surface, rect: Rect2, count: int, colors: Dictionary) -> void:
	# The numeric readout remains exact; cap the decorative pile so a large
	# collect does not turn bounded presentation into per-frame polygon churn.
	var visible := mini(12, maxi(0, count))
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
	var screen_x := center_x + (x / _world_width - 0.5) * PLAYFIELD_RECT.size.x * 0.91 * width_factor
	var screen_y := PLAYFIELD_RECT.end.y - 8.0 - depth * PLAYFIELD_RECT.size.y * 0.34 - z / _coin_height * Z_LAYER_OFFSET
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
	_coin_radius = maxf(1.0, float(state.get("coin_pusher_coin_radius", SCHEMA_DEFAULT_COIN_RADIUS)))


func _projected_contact_radius_x(y: float, radius: float) -> float:
	var depth := clampf(y / _world_back_y, 0.0, 1.0)
	return radius / _world_width * PLAYFIELD_RECT.size.x * 0.91 * lerpf(1.0, REAR_WIDTH_FACTOR, depth)


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


func debug_payout_ramp_for_test(state: Dictionary) -> Dictionary:
	_configure_projection(state)
	var geometry: Dictionary = state.get("coin_pusher_geometry", {}) if typeof(state.get("coin_pusher_geometry", {})) == TYPE_DICTIONARY else {}
	var width := int(geometry.get("width", 100000))
	var lip := int(geometry.get("tray_lip_y", 4000))
	var run := maxi(1, int(geometry.get("payout_ramp_run", 6500)))
	var rise := maxi(0, int(geometry.get("payout_ramp_rise", 900)))
	var apron_drop := maxi(1, int(geometry.get("payout_apron_drop", 3000)))
	return {
		"run": run,
		"rise": rise,
		"apron_drop": apron_drop,
		"front_left": _project(0, lip, rise),
		"front_right": _project(width, lip, rise),
		"apron_bottom_left": _project(0, lip, rise - apron_drop),
		"apron_bottom_right": _project(width, lip, rise - apron_drop),
		"back_left": _project(0, lip + run, 0),
		"back_right": _project(width, lip + run, 0),
	}


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
	# Leave room for the largest selected entry control so the release hardware
	# remains fully inside the glass instead of bleeding into the backglass.
	# Keep the full-height Plinko field visually dominant while retaining enough
	# glass clearance for the largest nozzle control at the board crown.
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
