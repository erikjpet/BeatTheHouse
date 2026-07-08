class_name PixelSceneCanvas
extends Control

# Draws first-person venue scenes as hard-edged pixel art directly on Godot's canvas.

signal object_hovered(object_id: String)
signal object_focused(object_id: String)
signal object_activated(object_id: String)

const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const IconSpriteRendererScript := preload("res://scripts/ui/icon_sprite_renderer.gd")
const AttributeBadgeRowScript := preload("res://scripts/ui/attribute_badge_row.gd")
const DrunkDistortionOverlayScript := preload("res://scripts/ui/drunk_distortion_overlay.gd")

const C_DARK := VisualStyleScript.DARK
const C_DARK_2 := VisualStyleScript.DARK_2
const C_DARK_3 := VisualStyleScript.DARK_3
const C_PINK := VisualStyleScript.PINK
const C_PINK_2 := VisualStyleScript.PINK_2
const C_HOT := VisualStyleScript.HOT
const C_CYAN := VisualStyleScript.CYAN
const C_CYAN_2 := VisualStyleScript.CYAN_2
const C_TEAL := VisualStyleScript.TEAL
const C_YELLOW := VisualStyleScript.YELLOW
const C_AMBER := VisualStyleScript.AMBER
const C_PURPLE := VisualStyleScript.PURPLE
const C_PURPLE_2 := VisualStyleScript.PURPLE_2
const C_ORANGE := VisualStyleScript.ORANGE
const C_WHITE := VisualStyleScript.WHITE
const C_SOFT := VisualStyleScript.SOFT
const C_SHADOW := VisualStyleScript.SHADOW
const C_BLUE := VisualStyleScript.BLUE
const C_POLICE_RED := Color("#ff173d")
const C_POLICE_BLUE := Color("#1f64ff")
const BOARD_SIZE := VisualStyleScript.ENVIRONMENT_BOARD_SIZE
const FOCUS_ZOOM := 1.38
const FOCUS_LERP_SPEED := 9.5
const ROOM_LERP_SPEED := 7.0
const CAMERA_MAX_SMOOTH_DELTA := 1.0 / 30.0
const CAMERA_ZOOM_SNAP_EPSILON := 0.001
const CAMERA_OFFSET_SNAP_EPSILON := 0.35
const OBJECT_LAYOUT_MARGIN := 16.0
const OBJECT_LAYOUT_GAP := 8.0
const OBJECT_LAYOUT_MAX_OVERLAP_AREA := 0.01
const OBJECT_INFO_WIDTH := 326.0
const OBJECT_INFO_ITEM_WIDTH := 286.0
const OBJECT_INFO_MIN_WIDTH := 148.0
const OBJECT_INFO_MIN_HEIGHT := 58.0
const OBJECT_INFO_LINE_HEIGHT := 12.0
const OBJECT_INFO_MAX_LINES := 6
const OBJECT_INFO_MAX_CHARS := 52
const OBJECT_INFO_ITEM_MAX_CHARS := 44
const OBJECT_INFO_DESCRIPTION_MAX_CHARS := 52
const OBJECT_INFO_GAP := 8.0
const OBJECT_INFO_PADDING_X := 6.0
const OBJECT_INFO_TYPE_GAP := 8.0
const OBJECT_INFO_HEADER_Y := 13.0
const OBJECT_INFO_HEADER_RULE_Y := 18.0
const OBJECT_INFO_BODY_Y := 31.0
const OBJECT_INFO_ACTION_HEIGHT := 16.0
const OBJECT_INFO_ACTION_GAP := 5.0
const OBJECT_INFO_INLINE_ACTION_HEIGHT := 19.0
const OBJECT_INFO_INLINE_ACTION_DETAIL_HEIGHT := 11.0
const OBJECT_INFO_INLINE_ACTION_GAP := 5.0
const OBJECT_INFO_INLINE_ACTION_MAX := 3
const OBJECT_INFO_BOTTOM_PADDING := 8.0
const OBJECT_INFO_ANIMATION_SPEED := 14.0
const OBJECT_INFO_RECT_SNAP_EPSILON := 0.25
const OBJECT_LABEL_MAX_WIDTH := 126.0
const OBJECT_LABEL_HEIGHT := 15.0
const OBJECT_LABEL_GAP := 4.0
# Godot can deliver touch plus emulated mouse after a stalled frame.
const EMULATED_TOUCH_SUPPRESS_MS := 750
const EMULATED_TOUCH_SUPPRESS_DISTANCE := 18.0
const DRUNK_TIME_SCALE_MIN := 0.33
const SCENE_IDLE_ANIMATION_FPS := 60.0
const SCENE_IDLE_ANIMATION_INTERVAL_SEC := 1.0 / SCENE_IDLE_ANIMATION_FPS
const ITEM_ICON_TEXTURE_CACHE_LIMIT := 32
const SCENE_SPARKLES_CORNER_STORE := [Vector2(384, 220), Vector2(478, 224), Vector2(668, 138), Vector2(746, 144)]
const SCENE_PUDDLES_BACK_ALLEY := [Vector2(180, 304), Vector2(420, 292), Vector2(710, 312)]
const SCENE_SPARKLES_BACK_ALLEY := [Vector2(112, 172), Vector2(792, 174)]
const SCENE_SPARKLES_MOTEL := [Vector2(420, 148), Vector2(524, 154), Vector2(746, 194)]
const SCENE_SPARKLES_BAR := [Vector2(98, 92), Vector2(190, 86), Vector2(362, 92), Vector2(780, 166)]
const SCENE_SPARKLES_JAZZ_CLUB := [Vector2(184, 118), Vector2(322, 116), Vector2(466, 118), Vector2(704, 196)]
const SCENE_SPARKLES_KITTY_CAT := [Vector2(168, 166), Vector2(318, 164), Vector2(456, 166), Vector2(704, 236)]
const SCENE_SPARKLES_DELTA_QUEEN := [Vector2(128, 96), Vector2(448, 96), Vector2(744, 96)]
const SCENE_SPARKLES_UNDERGROUND := [Vector2(154, 134), Vector2(505, 136), Vector2(772, 142)]
const SCENE_SPARKLES_GRAND_CASINO := [Vector2(132, 118), Vector2(728, 118), Vector2(444, 154)]

var environment_id: String = "corner_store"
var environment_name: String = "Corner Store"
var suspicion_level: int = 0
var drunk_level: int = 0
var drunk_time_scale := 1.0
var scene_objects: Array = []
var hovered_object_id: String = ""
var selected_object_id: String = ""
var foundation_snapshot: Dictionary = {}
var foundation_scene_objects: Array = []
var uses_foundation_snapshot := false
var background_texture: Texture2D
var use_external_background := false
var flicker: float = 0.0
var camera_zoom: float = 1.0
var camera_offset: Vector2 = Vector2.ZERO
var target_camera_zoom: float = 1.0
var target_camera_offset: Vector2 = Vector2.ZERO
var camera_focus_point: Vector2 = Vector2(0.5, 0.5)
var camera_focus_active := false
var camera_target_dirty := true
var camera_target_refresh_count := 0
var item_icon_texture_cache: Dictionary = {}
var item_icon_texture_cache_scope_key: String = ""
var icon_sprite_texture_cache: Dictionary = {}
var scene_objects_by_id_cache: Dictionary = {}
var draw_text_width_cache: Dictionary = {}
var fit_draw_text_cache: Dictionary = {}
var object_animation_phase_cache: Dictionary = {}
var drunk_distortion_overlay: DrunkDistortionOverlay
var drunk_effect_mode: String = "distortion"
var last_mouse_press_msec: int = -100000
var last_mouse_press_position: Vector2 = Vector2(-100000.0, -100000.0)
var info_card_visual_rect: Rect2 = Rect2()
var info_card_visual_object_id: String = ""
var info_card_animating := false
var reduce_motion := false
var scene_idle_animation_redraw_accumulator := 0.0
var scene_idle_animation_redraw_count := 0
var last_touch_press_msec: int = -100000
var last_touch_press_position: Vector2 = Vector2(-100000.0, -100000.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_ensure_drunk_distortion_overlay()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_invalidate_camera_target()
		_update_camera_target_if_needed()
		queue_redraw()


# Copies a foundation EnvironmentInstance view snapshot into canvas-local state.
func render_environment_snapshot(snapshot: Dictionary) -> void:
	uses_foundation_snapshot = true
	foundation_snapshot = snapshot.duplicate(true)
	environment_id = str(foundation_snapshot.get("archetype_id", foundation_snapshot.get("id", environment_id)))
	var texture_scope_key := str(foundation_snapshot.get("world_node_id", foundation_snapshot.get("id", environment_id))).strip_edges()
	if texture_scope_key.is_empty():
		texture_scope_key = environment_id
	if texture_scope_key != item_icon_texture_cache_scope_key:
		item_icon_texture_cache.clear()
		item_icon_texture_cache_scope_key = texture_scope_key
	environment_name = str(foundation_snapshot.get("display_name", foundation_snapshot.get("name", environment_name)))
	suspicion_level = int(foundation_snapshot.get("suspicion_level", suspicion_level))
	drunk_level = int(foundation_snapshot.get("drunk_level", drunk_level))
	drunk_time_scale = clampf(float(foundation_snapshot.get("drunk_time_scale", 1.0)), DRUNK_TIME_SCALE_MIN, 1.0)
	reduce_motion = bool(foundation_snapshot.get("reduce_motion", false))
	drunk_effect_mode = _normalized_drunk_effect_mode(str(foundation_snapshot.get("drunk_effect_mode", drunk_effect_mode)))
	_update_drunk_distortion_overlay()
	foundation_scene_objects = _objects_from_foundation_snapshot(foundation_snapshot)
	_rebuild_scene_object_cache()
	_clear_draw_text_caches()
	icon_sprite_texture_cache = {}
	if not selected_object_id.is_empty() and _scene_object(selected_object_id).is_empty():
		selected_object_id = ""
	if not hovered_object_id.is_empty() and _scene_object(hovered_object_id).is_empty():
		hovered_object_id = ""
	_invalidate_camera_target()
	_update_camera_target_if_needed()
	queue_redraw()


func debug_soak_snapshot() -> Dictionary:
	return {
		"environment_id": environment_id,
		"item_icon_texture_cache_scope_key": item_icon_texture_cache_scope_key,
		"foundation_object_count": foundation_scene_objects.size(),
		"scene_object_index_count": scene_objects_by_id_cache.size(),
		"item_icon_texture_cache_size": item_icon_texture_cache.size(),
		"icon_sprite_texture_cache_size": icon_sprite_texture_cache.size(),
		"draw_text_width_cache_size": draw_text_width_cache.size(),
		"fit_draw_text_cache_size": fit_draw_text_cache.size(),
		"object_animation_phase_cache_size": object_animation_phase_cache.size(),
		"background_texture_loaded": background_texture != null,
		"scene_idle_animation_redraw_count": scene_idle_animation_redraw_count,
	}


func _ensure_drunk_distortion_overlay() -> void:
	if drunk_distortion_overlay != null:
		return
	drunk_distortion_overlay = DrunkDistortionOverlayScript.new()
	drunk_distortion_overlay.name = "DrunkDistortionOverlay"
	drunk_distortion_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drunk_distortion_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(drunk_distortion_overlay)
	_update_drunk_distortion_overlay()


func _update_drunk_distortion_overlay() -> void:
	if drunk_distortion_overlay != null:
		drunk_distortion_overlay.set_reduce_motion(reduce_motion)
		drunk_distortion_overlay.set_drunk_level(drunk_level if drunk_effect_mode == "distortion" else 0)


func _normalized_drunk_effect_mode(value: String) -> String:
	return "classic" if value == "classic" else "distortion"


# Updates UI-local selection without changing simulation state.
func set_selected_object(object_id: String, snap_to_target: bool = true) -> void:
	if selected_object_id != object_id:
		selected_object_id = object_id
		_invalidate_camera_target()
	_update_camera_target_if_needed()
	if reduce_motion or (selected_object_id.is_empty() and snap_to_target):
		camera_zoom = target_camera_zoom
		camera_offset = target_camera_offset
		_snap_info_card_to_target()
	queue_redraw()


# Selects one rendered view object by index for smoke tests and keyboard/controller affordances.
func select_object_at(index: int) -> void:
	var objects := _active_scene_objects()
	if index < 0 or index >= objects.size():
		set_selected_object("")
		object_focused.emit("")
		return
	var object_data: Dictionary = objects[index]
	var object_id := str(object_data.get("id", ""))
	set_selected_object(object_id)
	object_focused.emit(object_id)


# Returns the rendered object id under a local canvas coordinate.
func object_id_at_local_position(local_position: Vector2) -> String:
	var board_position := _local_to_board_position(local_position)
	var objects := _active_scene_objects()
	for index in range(objects.size() - 1, -1, -1):
		var object_data: Dictionary = objects[index]
		if not bool(object_data.get("interactive", true)):
			continue
		if _board_rect_for_object(object_data).has_point(board_position):
			return str(object_data.get("id", ""))
	return ""


# Returns canvas-owned view data only; this is not a simulation source.
func current_view_snapshot() -> Dictionary:
	_update_camera_target_if_needed()
	var current_board_rect := _board_screen_rect(camera_offset, camera_zoom)
	var target_board_rect := _board_screen_rect(target_camera_offset, target_camera_zoom)
	var outcome_view := _scene_outcome_view_snapshot()
	return {
		"environment_id": environment_id,
		"environment_name": environment_name,
		"suspicion_level": suspicion_level,
		"drunk_level": drunk_level,
		"drunk_time_scale": drunk_time_scale,
		"drunk_time_scale_percent": int(round(drunk_time_scale * 100.0)),
		"hovered_object_id": hovered_object_id,
		"selected_object_id": selected_object_id,
		"scene_animation_time": flicker,
		"scene_idle_animation_active": _scene_idle_animation_active(),
		"scene_idle_animation_fps": SCENE_IDLE_ANIMATION_FPS,
		"scene_idle_animation_redraw_count": scene_idle_animation_redraw_count,
		"camera_focus_active": camera_focus_active,
		"camera_focus_point": camera_focus_point,
		"camera_offset": camera_offset,
		"target_camera_offset": target_camera_offset,
		"camera_zoom": camera_zoom,
		"target_camera_zoom": target_camera_zoom,
		"camera_target_refresh_count": camera_target_refresh_count,
		"clip_contents": clip_contents,
		"canvas_size": size,
		"board_rect": _rect_to_snapshot(current_board_rect),
		"target_board_rect": _rect_to_snapshot(target_board_rect),
		"board_scale": _board_base_scale() * camera_zoom,
		"target_board_scale": _board_base_scale() * target_camera_zoom,
		"board_aspect_ratio": float(BOARD_SIZE.x) / float(BOARD_SIZE.y),
		"preserves_aspect_ratio": true,
		"objects": _copy_array(_active_scene_objects()),
		"object_layout": _scene_object_layout_snapshot(_active_scene_objects()),
		"selected_info": _selected_object_info_snapshot(),
		"drunk_effect_mode": drunk_effect_mode,
		"drunk_distortion_visible": drunk_distortion_overlay != null and drunk_distortion_overlay.visible,
		"drunk_distortion_debug": drunk_distortion_overlay.debug_snapshot() if drunk_distortion_overlay != null else {},
		"uses_foundation_snapshot": uses_foundation_snapshot,
		"outcome_object_id": str(foundation_snapshot.get("outcome_object_id", "")) if uses_foundation_snapshot else "",
		"outcome_message": str(foundation_snapshot.get("outcome_message", "")) if uses_foundation_snapshot else "",
		"outcome_bankroll_delta": int(foundation_snapshot.get("outcome_bankroll_delta", 0)) if uses_foundation_snapshot else 0,
		"outcome_suspicion_delta": int(foundation_snapshot.get("outcome_suspicion_delta", 0)) if uses_foundation_snapshot else 0,
		"outcome_anchor": str(outcome_view.get("anchor", "")),
		"outcome_popup_rect": outcome_view.get("popup_rect", {}),
		"outcome_interaction_kind": str(outcome_view.get("interaction_kind", "")),
		"pit_boss_watch": _pit_boss_watch_snapshot(),
		"reduce_motion": reduce_motion,
	}


func local_position_for_selected_info_action_button() -> Vector2:
	var button_rect := _selected_info_action_button_rect()
	if button_rect.size.x <= 0.0 or button_rect.size.y <= 0.0:
		return Vector2(-1.0, -1.0)
	return _board_to_local_position(button_rect.get_center())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _selected_info_action_button_at_local_position((event as InputEventMouseMotion).position):
			_set_hovered_object(selected_object_id)
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			return
		_set_hovered_object(object_id_at_local_position((event as InputEventMouseMotion).position))
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _mouse_duplicates_recent_touch_press(mouse_event.position):
				accept_event()
				return
			_remember_mouse_press(mouse_event.position)
			if _activate_selected_info_action_at_local_position(mouse_event.position):
				accept_event()
				return
			if mouse_event.double_click:
				_activate_object_at_local_position(mouse_event.position)
			else:
				_focus_object_at_local_position(mouse_event.position)
			accept_event()
		return
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			if _touch_duplicates_recent_mouse_press(touch_event.position):
				accept_event()
				return
			_remember_touch_press(touch_event.position)
			if _activate_selected_info_action_at_local_position(touch_event.position):
				accept_event()
				return
			if touch_event.double_tap:
				_activate_object_at_local_position(touch_event.position)
			else:
				_focus_object_at_local_position(touch_event.position)
			accept_event()
		return
	if event is InputEventScreenDrag:
		_set_hovered_object(object_id_at_local_position((event as InputEventScreenDrag).position))


func _remember_mouse_press(position: Vector2) -> void:
	last_mouse_press_msec = Time.get_ticks_msec()
	last_mouse_press_position = position


func _remember_touch_press(position: Vector2) -> void:
	last_touch_press_msec = Time.get_ticks_msec()
	last_touch_press_position = position


func _touch_duplicates_recent_mouse_press(position: Vector2) -> bool:
	var elapsed := Time.get_ticks_msec() - last_mouse_press_msec
	if elapsed < 0 or elapsed > EMULATED_TOUCH_SUPPRESS_MS:
		return false
	return position.distance_to(last_mouse_press_position) <= EMULATED_TOUCH_SUPPRESS_DISTANCE


func _mouse_duplicates_recent_touch_press(position: Vector2) -> bool:
	var elapsed := Time.get_ticks_msec() - last_touch_press_msec
	if elapsed < 0 or elapsed > EMULATED_TOUCH_SUPPRESS_MS:
		return false
	return position.distance_to(last_touch_press_position) <= EMULATED_TOUCH_SUPPRESS_DISTANCE


# Keeps fluorescent and neon elements alive without using image files.
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var previous_zoom := camera_zoom
	var previous_offset := camera_offset
	var was_info_animating := info_card_animating
	if reduce_motion:
		flicker = 0.0
		_update_camera_target_if_needed()
		camera_zoom = target_camera_zoom
		camera_offset = target_camera_offset
		_snap_info_card_to_target()
		if absf(previous_zoom - camera_zoom) > CAMERA_ZOOM_SNAP_EPSILON or previous_offset.distance_squared_to(camera_offset) > CAMERA_OFFSET_SNAP_EPSILON * CAMERA_OFFSET_SNAP_EPSILON or was_info_animating:
			queue_redraw()
		return
	var scaled_delta := delta * drunk_time_scale
	flicker += scaled_delta
	_update_camera_target_if_needed()
	var speed := FOCUS_LERP_SPEED if camera_focus_active else ROOM_LERP_SPEED
	var weight := _camera_lerp_weight(scaled_delta, speed)
	camera_zoom = lerpf(camera_zoom, target_camera_zoom, weight)
	camera_offset = camera_offset.lerp(target_camera_offset, weight)
	_update_info_card_animation(scaled_delta)
	if absf(camera_zoom - target_camera_zoom) <= CAMERA_ZOOM_SNAP_EPSILON:
		camera_zoom = target_camera_zoom
	if camera_offset.distance_squared_to(target_camera_offset) <= CAMERA_OFFSET_SNAP_EPSILON * CAMERA_OFFSET_SNAP_EPSILON:
		camera_offset = target_camera_offset
	var camera_changed := absf(previous_zoom - camera_zoom) > CAMERA_ZOOM_SNAP_EPSILON or previous_offset.distance_squared_to(camera_offset) > CAMERA_OFFSET_SNAP_EPSILON * CAMERA_OFFSET_SNAP_EPSILON
	if camera_changed or info_card_animating or was_info_animating or _needs_continuous_scene_redraw() or _scene_idle_animation_redraw_due(scaled_delta):
		queue_redraw()


func _needs_continuous_scene_redraw() -> bool:
	if suspicion_level > 0:
		return true
	if drunk_effect_mode == "classic" and drunk_level >= 12:
		return true
	return drunk_distortion_overlay != null and drunk_distortion_overlay.visible


func _scene_idle_animation_active() -> bool:
	return not reduce_motion


func _scene_idle_animation_redraw_due(delta: float) -> bool:
	if not _scene_idle_animation_active():
		scene_idle_animation_redraw_accumulator = 0.0
		return false
	scene_idle_animation_redraw_accumulator += maxf(0.0, delta)
	if scene_idle_animation_redraw_accumulator < SCENE_IDLE_ANIMATION_INTERVAL_SEC:
		return false
	scene_idle_animation_redraw_accumulator = minf(
		scene_idle_animation_redraw_accumulator - SCENE_IDLE_ANIMATION_INTERVAL_SEC,
		SCENE_IDLE_ANIMATION_INTERVAL_SEC
	)
	scene_idle_animation_redraw_count += 1
	return true


# Selects the active venue drawing routine.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), C_DARK)
	_scale_canvas()
	_bg()
	if use_external_background and background_texture != null:
		draw_texture_rect(background_texture, Rect2(Vector2.ZERO, Vector2(BOARD_SIZE)), false)
	else:
		match environment_id:
			"corner_store":
				_draw_corner_store()
			"back_alley":
				_draw_back_alley()
			"motel":
				_draw_motel()
			"motel_room":
				_draw_motel_room()
			"apartment":
				_draw_apartment()
			"house":
				_draw_house()
			"bar":
				_draw_bar()
			"jazz_club":
				_draw_jazz_club()
			"kitty_cat_lounge":
				_draw_kitty_cat_lounge()
			"delta_queen":
				_draw_delta_queen()
			"beach":
				_draw_beach()
			"gas_station_casino":
				_draw_gas_station()
			"small_underground_casino":
				_draw_underground()
			"grand_casino":
				_draw_grand_casino()
			_:
				_draw_corner_store()
	_draw_scene_life()
	_draw_familiar_characters()
	_draw_focus_dim_overlay()
	_draw_scene_objects()
	_draw_scene_outcome_highlight()
	_draw_pressure_overlay()
	_draw_drunk_overlay()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_update_drunk_distortion_protected_rects()


# Maps all drawings to a stable low-resolution art board.
func _scale_canvas() -> void:
	var base_scale := _board_base_scale()
	var scale := base_scale * camera_zoom
	draw_set_transform(_board_base_offset(base_scale) + camera_offset, 0.0, Vector2(scale, scale))


func _board_base_scale() -> float:
	if size.x <= 0.0 or size.y <= 0.0:
		return 1.0
	var board_size := Vector2(BOARD_SIZE)
	return minf(size.x / board_size.x, size.y / board_size.y)


func _board_base_offset(scale: float) -> Vector2:
	var scaled_board := Vector2(BOARD_SIZE) * scale
	return Vector2(
		(size.x - scaled_board.x) * 0.5,
		(size.y - scaled_board.y) * 0.5
	)


func _board_screen_rect(offset: Vector2, zoom: float) -> Rect2:
	var base_scale := _board_base_scale()
	var scale := base_scale * zoom
	return Rect2(_board_base_offset(base_scale) + offset, Vector2(BOARD_SIZE) * scale)


# Base room gradient made from pixel bands.
func _bg() -> void:
	var board_size := Vector2(BOARD_SIZE)
	draw_rect(Rect2(Vector2.ZERO, board_size), C_DARK)
	for y in range(0, BOARD_SIZE.y, 17):
		var shade := C_DARK_2 if (y / 17) % 2 == 0 else C_DARK_3
		draw_rect(Rect2(0, y, board_size.x, 17), shade)
	draw_rect(Rect2(0, 250, board_size.x, board_size.y - 250), Color("#070710"))


func _draw_corner_store() -> void:
	# Narrow store aisle, glass counter, bored clerk, scratchers, beer neon, and boxes.
	draw_rect(Rect2(0, 0, 900, 245), Color("#10101d"))
	for x in [78, 212, 620, 758]:
		draw_rect(Rect2(x, 0, 18, 238), Color("#16162a"))
		draw_rect(Rect2(x + 4, 0, 4, 238), C_CYAN_2.darkened(0.35))
	for x in range(24, 830, 84):
		var a := 0.45 + sin(flicker * 9.0 + x) * 0.12
		draw_rect(Rect2(x, 22, 60, 8), Color(0.85, 1.0, 1.0, a))
	draw_rect(Rect2(42, 64, 258, 148), C_BLUE)
	draw_rect(Rect2(58, 84, 228, 12), C_TEAL)
	for y in [108, 136, 164, 192]:
		draw_rect(Rect2(60, y, 220, 8), C_SHADOW)
		for x in range(70, 268, 28):
			draw_rect(Rect2(x, y - 20, 16, 18), _cycle_color(x + y))
	draw_rect(Rect2(338, 92, 246, 114), Color("#070712"))
	draw_rect(Rect2(352, 106, 218, 88), Color("#181834"))
	draw_rect(Rect2(430, 116, 60, 72), Color("#111120"))
	_silhouette(Vector2(460, 158), 1.0, C_SHADOW)
	draw_rect(Rect2(352, 142, 218, 7), C_CYAN)
	draw_rect(Rect2(338, 206, 246, 48), Color("#20203c"))
	for x in range(360, 552, 38):
		draw_rect(Rect2(x, 216, 28, 28), C_AMBER)
		draw_rect(Rect2(x + 4, 220, 20, 4), C_PINK)
		draw_rect(Rect2(x + 6, 230, 16, 3), C_CYAN)
	_neon_text("LOTTO", Vector2(386, 78), 26, C_YELLOW)
	_neon_text("BEER", Vector2(646, 80), 30, C_CYAN)
	draw_rect(Rect2(642, 114, 168, 94), Color("#101028"))
	for x in range(656, 792, 42):
		draw_rect(Rect2(x, 134, 28, 56), C_ORANGE.darkened(0.15))
		draw_rect(Rect2(x + 6, 122, 16, 14), C_AMBER)
	for i in range(4):
		draw_rect(Rect2(642 + i * 48, 220 - i * 9, 42, 32), Color("#513315"))
		draw_rect(Rect2(648 + i * 48, 228 - i * 9, 16, 4), C_AMBER)
	_floor_reflections()


func _draw_back_alley() -> void:
	# Wet alley with brick walls, graffiti, a folding table, watches, trash, and neon rain.
	draw_rect(Rect2(Vector2.ZERO, Vector2(BOARD_SIZE)), Color("#090911"))
	for x in range(0, 900, 54):
		for y in range(0, 236, 24):
			draw_rect(Rect2(x + (27 if y % 48 == 0 else 0), y, 50, 20), Color("#23122a"))
			draw_rect(Rect2(x + (27 if y % 48 == 0 else 0), y + 18, 50, 2), Color("#321844"))
	_neon_text("NO HEAT", Vector2(54, 72), 24, C_PINK)
	_neon_text("PAY CASH", Vector2(642, 58), 22, C_CYAN)
	draw_line(Vector2(450, 0), Vector2(450, 104), C_SOFT, 2)
	draw_rect(Rect2(420, 104, 60, 16), C_AMBER)
	draw_rect(Rect2(432, 120, 36, 10), Color(1.0, 0.9, 0.35, 0.6))
	draw_rect(Rect2(282, 192, 336, 24), Color("#4a2d1f"))
	draw_rect(Rect2(318, 216, 14, 78), Color("#241717"))
	draw_rect(Rect2(572, 216, 14, 78), Color("#241717"))
	for x in [334, 388, 442, 496, 550]:
		draw_rect(Rect2(x, 172, 36, 20), _cycle_color(x))
		draw_rect(Rect2(x + 6, 177, 24, 4), C_WHITE)
	_silhouette(Vector2(102, 226), 1.15, C_SHADOW)
	_silhouette(Vector2(790, 228), 1.1, C_SHADOW)
	for x in [118, 742]:
		draw_rect(Rect2(x, 246, 42, 56), Color("#222232"))
		draw_rect(Rect2(x - 4, 238, 50, 10), C_CYAN_2.darkened(0.2))
	for x in range(0, 900, 36):
		draw_line(Vector2(x, 0), Vector2(x - 38, BOARD_SIZE.y), Color(0.0, 0.95, 1.0, 0.15), 1)
	_floor_reflections()


func _draw_motel() -> void:
	# Motel room with bedspread, cards, CRT static, window sign, vending glow, and curtain slit.
	draw_rect(Rect2(0, 0, 900, 246), Color("#141025"))
	draw_rect(Rect2(42, 56, 242, 168), Color("#221239"))
	draw_rect(Rect2(62, 72, 202, 116), Color("#090914"))
	_neon_text("MOTEL", Vector2(76, 112), 34, C_PINK)
	draw_rect(Rect2(288, 44, 26, 192), Color("#080812"))
	draw_rect(Rect2(586, 44, 26, 192), Color("#080812"))
	for x in range(326, 572, 18):
		draw_rect(Rect2(x, 50, 8, 178), Color("#10101c"))
	draw_rect(Rect2(260, 84, 86, 126), Color("#10131f"))
	draw_rect(Rect2(274, 98, 58, 112), Color("#1d2840"))
	draw_rect(Rect2(282, 112, 42, 72), Color("#111827"))
	draw_rect(Rect2(324, 142, 6, 6), C_AMBER)
	draw_line(Vector2(268, 90), Vector2(338, 72), C_PINK.darkened(0.25), 2)
	draw_rect(Rect2(96, 224, 452, 72), Color("#302049"))
	for x in range(116, 520, 36):
		draw_rect(Rect2(x, 240 + int(sin(float(x)) * 4.0), 22, 12), C_PINK_2.darkened(0.2))
	draw_rect(Rect2(370, 176, 258, 52), Color("#332a1f"))
	for x in range(408, 574, 42):
		_card_back(Rect2(x, 152, 30, 42))
	draw_rect(Rect2(664, 106, 146, 112), Color("#101018"))
	draw_rect(Rect2(680, 122, 114, 68), Color("#20203a"))
	for y in range(128, 186, 10):
		draw_line(Vector2(686, y), Vector2(788, y + 4), Color("#e0e0e0"), 1)
	draw_rect(Rect2(686, 196, 102, 10), C_PURPLE_2)
	draw_rect(Rect2(742, 58, 54, 146), Color("#13283a"))
	for y in range(78, 172, 22):
		draw_rect(Rect2(752, y, 34, 12), _cycle_color(y))
	_floor_reflections()


func _draw_motel_room() -> void:
	draw_rect(Rect2(0, 0, 900, 246), Color("#151024"))
	draw_rect(Rect2(52, 54, 260, 168), Color("#211536"))
	draw_rect(Rect2(72, 74, 220, 120), Color("#0a0a13"))
	_neon_text("NO VACANCY", Vector2(92, 120), 25, C_PINK)
	draw_rect(Rect2(352, 114, 286, 104), Color("#38264a"))
	draw_rect(Rect2(372, 130, 242, 34), Color("#55315e"))
	for x in range(390, 602, 34):
		draw_rect(Rect2(x, 154 + int(sin(flicker * 1.2 + x) * 2.0), 20, 12), C_PINK_2.darkened(0.25))
	draw_rect(Rect2(650, 84, 116, 148), Color("#171a28"))
	draw_rect(Rect2(668, 104, 78, 58), Color("#202b3e"))
	_draw_scan_bands(670, 744, 108, 158, C_SOFT, 0.12, 5.0)
	draw_rect(Rect2(744, 188, 82, 46), Color("#30241e"))
	draw_rect(Rect2(760, 174, 50, 18), Color("#4d3424"))
	draw_rect(Rect2(204, 236, 514, 58), Color("#241632"))
	_floor_reflections()


func _draw_apartment() -> void:
	draw_rect(Rect2(0, 0, 900, 246), Color("#111827"))
	draw_rect(Rect2(56, 48, 210, 154), Color("#16263a"))
	draw_rect(Rect2(76, 70, 170, 92), Color("#071727"))
	for x in range(86, 236, 30):
		draw_rect(Rect2(x, 82, 14, 70), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.16 + abs(sin(flicker * 2.0 + x)) * 0.12))
	draw_rect(Rect2(312, 132, 238, 82), Color("#2a1835"))
	draw_rect(Rect2(330, 110, 104, 38), Color("#362045"))
	draw_rect(Rect2(462, 112, 74, 42), Color("#1e2438"))
	draw_rect(Rect2(604, 76, 176, 150), Color("#1b1322"))
	draw_rect(Rect2(624, 96, 136, 18), C_AMBER.darkened(0.2))
	for y in [124, 152, 180]:
		draw_rect(Rect2(628, y, 126, 7), Color("#392448"))
		for x in range(638, 744, 34):
			draw_rect(Rect2(x, y - 19, 18, 16), _cycle_color(x + y))
	draw_rect(Rect2(132, 246, 606, 58), Color("#171221"))
	_floor_reflections()


func _draw_house() -> void:
	draw_rect(Rect2(0, 0, 900, 246), Color("#10131d"))
	draw_rect(Rect2(42, 46, 490, 190), Color("#1d1730"))
	draw_rect(Rect2(554, 46, 298, 190), Color("#171b25"))
	draw_line(Vector2(536, 48), Vector2(536, 236), Color("#332744"), 3)
	draw_rect(Rect2(76, 72, 132, 94), Color("#08101b"))
	draw_rect(Rect2(92, 88, 100, 52), Color("#162f43"))
	for x in range(104, 184, 18):
		draw_rect(Rect2(x, 92, 8, 44), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.10 + abs(sin(flicker * 1.7 + x)) * 0.10))
	draw_rect(Rect2(250, 82, 170, 78), Color("#131722"))
	draw_rect(Rect2(264, 96, 142, 48), Color("#06131e"))
	draw_rect(Rect2(450, 102, 46, 74), Color("#2e1720"))
	draw_rect(Rect2(122, 174, 244, 50), Color("#382333"))
	draw_rect(Rect2(146, 150, 184, 42), Color("#4a2940"))
	draw_rect(Rect2(170, 134, 62, 28), Color("#352037"))
	draw_rect(Rect2(354, 184, 108, 38), Color("#342015"))
	draw_rect(Rect2(370, 166, 76, 22), Color("#50311f"))
	draw_rect(Rect2(576, 70, 248, 54), Color("#242b32"))
	draw_rect(Rect2(590, 84, 54, 26), Color("#334653"))
	draw_rect(Rect2(660, 84, 54, 26), Color("#334653"))
	draw_rect(Rect2(730, 84, 70, 26), Color("#3d3030"))
	draw_rect(Rect2(616, 150, 150, 60), Color("#37261c"))
	draw_rect(Rect2(642, 132, 96, 28), Color("#503520"))
	for x in [636, 704]:
		draw_rect(Rect2(x, 204, 14, 34), Color("#21140f"))
	for x in range(594, 796, 42):
		draw_rect(Rect2(x, 60 + int(abs(sin(flicker + x)) * 3.0), 16, 8), _cycle_color(x).darkened(0.15))
	draw_rect(Rect2(218, 234, 610, 62), Color("#191421"))
	_floor_reflections()


func _draw_bar() -> void:
	# Dive bar with bottle mirror, stools, pool table, video poker, neon signs, and patrons.
	draw_rect(Rect2(0, 0, 900, 244), Color("#0f1320"))
	draw_rect(Rect2(54, 52, 498, 130), Color("#151c2d"))
	draw_rect(Rect2(72, 70, 462, 84), Color("#202842"))
	for x in range(90, 518, 34):
		draw_rect(Rect2(x, 84, 14, 54), _cycle_color(x).darkened(0.15))
		draw_rect(Rect2(x + 3, 74, 8, 10), C_AMBER)
	_neon_text("DIVE", Vector2(620, 58), 28, C_PINK)
	_neon_text("COLD BEER", Vector2(604, 104), 22, C_CYAN)
	draw_rect(Rect2(38, 178, 548, 56), Color("#3a1c16"))
	for x in [106, 186, 266, 346, 426, 506]:
		draw_rect(Rect2(x, 230, 42, 12), C_SHADOW)
		draw_rect(Rect2(x + 16, 242, 10, 48), C_SHADOW)
	_silhouette(Vector2(186, 174), 0.9, C_SHADOW)
	_silhouette(Vector2(496, 174), 0.85, C_SHADOW)
	draw_rect(Rect2(598, 188, 224, 76), Color("#12412e"))
	draw_rect(Rect2(612, 200, 196, 48), Color("#176b4d"))
	draw_rect(Rect2(654, 124, 112, 14), C_AMBER)
	draw_line(Vector2(710, 80), Vector2(710, 124), C_SOFT, 2)
	draw_rect(Rect2(768, 144, 86, 112), Color("#111120"))
	draw_rect(Rect2(782, 158, 58, 48), C_PURPLE)
	draw_rect(Rect2(792, 170, 38, 18), C_CYAN)
	_floor_reflections()


func _draw_jazz_club() -> void:
	# Late-1960s jazz room: low amber stage, smoky tables, trio players, bar, and pull-tabs.
	draw_rect(Rect2(0, 0, 900, 246), Color("#120d17"))
	for x in range(0, 900, 72):
		var panel_color := Color("#1a111c") if int(x / 72) % 2 == 0 else Color("#211420")
		draw_rect(Rect2(x, 0, 72, 246), panel_color)
		draw_line(Vector2(x + 70, 0), Vector2(x + 70, 246), Color(0.0, 0.0, 0.0, 0.24), 1)
	draw_rect(Rect2(0, 0, 900, 28), Color("#0a0710"))
	draw_rect(Rect2(0, 28, 900, 5), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.34))
	draw_rect(Rect2(48, 58, 510, 190), Color("#21101a"))
	draw_rect(Rect2(70, 76, 466, 138), Color("#120b12"))
	for x in range(84, 526, 54):
		draw_rect(Rect2(x, 70, 26, 148), Color("#2b1420"))
		draw_rect(Rect2(x + 5, 76, 5, 132), Color("#3a1b2a"))
	draw_rect(Rect2(66, 208, 476, 34), Color("#3a2114"))
	draw_rect(Rect2(82, 216, 444, 8), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.36))
	_draw_light_cone(Vector2(190, 34), Vector2(-54, 194), C_AMBER, 0.12)
	_draw_light_cone(Vector2(330, 34), Vector2(0, 194), C_AMBER, 0.10)
	_draw_light_cone(Vector2(470, 34), Vector2(54, 194), C_AMBER, 0.12)
	_neon_text("AFTER HOURS", Vector2(126, 62), 18, C_CYAN)
	_neon_text("JAZZ", Vector2(374, 62), 24, C_YELLOW)
	_draw_jazz_player(Vector2(178, 202), 0.72, "sax")
	_draw_jazz_player(Vector2(322, 206), 0.76, "cello")
	_draw_jazz_player(Vector2(466, 202), 0.70, "drums")
	draw_rect(Rect2(600, 72, 254, 122), Color("#17101a"))
	draw_rect(Rect2(618, 88, 218, 62), Color("#241622"))
	for x in range(630, 826, 28):
		draw_rect(Rect2(x, 104, 10, 36), _cycle_color(x).darkened(0.22))
		draw_rect(Rect2(x + 2, 96, 6, 8), C_AMBER)
	draw_rect(Rect2(590, 188, 284, 48), Color("#3b1f15"))
	draw_line(Vector2(602, 197), Vector2(862, 197), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.48), 3)
	_neon_text("PULL TABS", Vector2(704, 162), 14, C_PINK)
	draw_rect(Rect2(704, 176, 76, 64), Color("#090912"))
	draw_rect(Rect2(714, 184, 56, 20), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.24))
	for i in range(4):
		draw_rect(Rect2(716, 210 + i * 6, 52, 3), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.52))
	for table_x in [112, 244, 612]:
		var table_y := 304 + int(sin(float(table_x)) * 5.0)
		draw_rect(Rect2(table_x - 38, table_y, 76, 14), Color("#241315"))
		draw_rect(Rect2(table_x - 28, table_y + 4, 56, 6), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.18))
		_silhouette(Vector2(table_x - 26, table_y - 6), 0.32, Color("#05050a"))
		_silhouette(Vector2(table_x + 28, table_y - 4), 0.30, Color("#05050a"))
	for x in range(0, 900, 45):
		draw_rect(Rect2(x, 246, 45, 184), Color("#130b0d") if int(x / 45) % 2 == 0 else Color("#1a0f10"))
	for y in range(270, 416, 28):
		draw_line(Vector2(0, y), Vector2(900, y + 34), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.045), 1)
	_floor_reflections()


func _draw_jazz_player(foot: Vector2, scale_value: float, instrument: String) -> void:
	_silhouette(foot, scale_value, Color("#05050a"))
	var accent := C_YELLOW if instrument == "sax" else C_CYAN if instrument == "cello" else C_AMBER
	draw_rect(Rect2(foot + Vector2(-15, -43) * scale_value, Vector2(30, 4) * scale_value), accent)
	match instrument:
		"sax":
			var horn := foot + Vector2(16, -38) * scale_value
			draw_line(foot + Vector2(2, -34) * scale_value, horn, accent, maxf(2.0, 4.0 * scale_value))
			draw_circle(horn + Vector2(10, 10) * scale_value, 11.0 * scale_value, Color(accent.r, accent.g, accent.b, 0.70))
			draw_circle(horn + Vector2(10, 10) * scale_value, 5.0 * scale_value, Color("#120d17"))
		"cello":
			var body := Rect2(foot + Vector2(-9, -38) * scale_value, Vector2(32, 54) * scale_value)
			draw_rect(body, Color("#5a2a17"))
			draw_rect(body, Color(accent.r, accent.g, accent.b, 0.18), false, 2)
			draw_line(body.position + Vector2(body.size.x * 0.5, -18 * scale_value), body.position + Vector2(body.size.x * 0.5, body.size.y + 18 * scale_value), C_AMBER, maxf(1.0, 2.0 * scale_value))
			draw_line(foot + Vector2(-24, -34) * scale_value, foot + Vector2(24, -22) * scale_value, C_SOFT, maxf(1.0, 2.0 * scale_value))
		"drums":
			draw_circle(foot + Vector2(-24, -16) * scale_value, 20.0 * scale_value, Color("#362120"))
			draw_circle(foot + Vector2(-24, -16) * scale_value, 14.0 * scale_value, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.42))
			draw_circle(foot + Vector2(24, -16) * scale_value, 20.0 * scale_value, Color("#362120"))
			draw_circle(foot + Vector2(24, -16) * scale_value, 14.0 * scale_value, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.42))
			draw_circle(foot + Vector2(0, -48) * scale_value, 18.0 * scale_value, Color(accent.r, accent.g, accent.b, 0.64))
			draw_line(foot + Vector2(-28, -50) * scale_value, foot + Vector2(-44, -66) * scale_value, C_SOFT, maxf(1.0, 2.0 * scale_value))
			draw_line(foot + Vector2(28, -50) * scale_value, foot + Vector2(44, -66) * scale_value, C_SOFT, maxf(1.0, 2.0 * scale_value))


func _draw_kitty_cat_lounge() -> void:
	# Velvet lounge with a stage, champagne bar, house wheel, and forgiving staff.
	draw_rect(Rect2(0, 0, 900, 246), Color("#130918"))
	for x in range(0, 900, 60):
		var panel := Color("#241022") if int(x / 60) % 2 == 0 else Color("#1a0d1d")
		draw_rect(Rect2(x, 0, 60, 246), panel)
	draw_rect(Rect2(0, 0, 900, 32), Color("#09060c"))
	draw_rect(Rect2(0, 32, 900, 6), C_PINK_2)
	draw_rect(Rect2(62, 58, 470, 184), Color("#24101a"))
	draw_rect(Rect2(82, 78, 430, 126), Color("#10080e"))
	draw_rect(Rect2(94, 196, 406, 38), Color("#3a1818"))
	_draw_light_cone(Vector2(180, 34), Vector2(-42, 190), C_PINK, 0.12)
	_draw_light_cone(Vector2(318, 34), Vector2(0, 190), C_AMBER, 0.10)
	_draw_light_cone(Vector2(456, 34), Vector2(42, 190), C_CYAN, 0.11)
	_neon_text("KITTY CAT", Vector2(126, 62), 26, C_PINK)
	_neon_text("LOUNGE", Vector2(354, 66), 22, C_YELLOW)
	for x in [142, 250, 358]:
		_silhouette(Vector2(x, 205), 0.72, Color("#05050a"))
		draw_rect(Rect2(x - 14, 164, 28, 5), C_AMBER)
	draw_rect(Rect2(584, 72, 260, 124), Color("#170b12"))
	draw_rect(Rect2(602, 88, 222, 64), Color("#2a1118"))
	for x in range(620, 808, 28):
		draw_rect(Rect2(x, 104, 10, 34), _cycle_color(x).darkened(0.18))
		draw_rect(Rect2(x + 2, 94, 6, 8), C_AMBER)
	draw_rect(Rect2(584, 190, 268, 48), Color("#3d1b14"))
	draw_line(Vector2(596, 199), Vector2(840, 199), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.46), 3)
	draw_circle(Vector2(704, 274), 48, Color("#2a1220"))
	draw_circle(Vector2(704, 274), 38, Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.26))
	for i in range(8):
		var angle := float(i) * TAU / 8.0 + flicker * 0.08
		draw_line(Vector2(704, 274), Vector2(704, 274) + Vector2(cos(angle), sin(angle)) * 42.0, _cycle_color(i * 19), 2)
	draw_circle(Vector2(704, 274), 9, C_YELLOW)
	for table_x in [130, 300, 472]:
		draw_rect(Rect2(table_x - 42, 308, 84, 14), Color("#251015"))
		draw_rect(Rect2(table_x - 20, 298, 12, 20), C_AMBER)
		draw_rect(Rect2(table_x + 12, 300, 10, 18), C_PINK_2)
	_floor_reflections()


func _draw_delta_queen() -> void:
	# Riverboat casino deck with brass rails, mid-stakes tables, and dock lights out the windows.
	draw_rect(Rect2(0, 0, 900, 246), Color("#071018"))
	for x in range(0, 900, 72):
		draw_rect(Rect2(x, 0, 72, 246), Color("#0d1822") if int(x / 72) % 2 == 0 else Color("#101b26"))
	draw_rect(Rect2(0, 28, 900, 8), C_AMBER)
	for x in range(42, 846, 92):
		draw_rect(Rect2(x, 54, 58, 112), Color("#071421"))
		draw_rect(Rect2(x + 6, 62, 46, 86), Color("#132b3a"))
		draw_line(Vector2(x + 4, 132), Vector2(x + 54, 104), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.28), 2)
	_neon_text("DELTA QUEEN", Vector2(266, 62), 28, C_YELLOW)
	draw_rect(Rect2(64, 178, 238, 84), Color("#123f30"))
	draw_rect(Rect2(84, 194, 198, 46), Color("#1a7755"))
	draw_rect(Rect2(360, 170, 212, 92), Color("#143b31"))
	draw_rect(Rect2(378, 188, 176, 48), Color("#1b7555"))
	for x in [122, 172, 222, 410, 460, 510]:
		_card_back(Rect2(x, 154 + (x % 3) * 4, 26, 36))
	_slot_machine(Rect2(626, 132, 76, 124), C_CYAN)
	_slot_machine(Rect2(724, 132, 76, 124), C_PINK)
	draw_rect(Rect2(0, 292, 900, 16), Color("#493116"))
	for x in range(0, 900, 60):
		draw_line(Vector2(x, 278), Vector2(x + 28, 328), C_AMBER, 3)
	draw_line(Vector2(0, 278), Vector2(900, 278), C_AMBER, 4)
	draw_line(Vector2(0, 328), Vector2(900, 328), C_AMBER, 3)
	for i in range(7):
		var y := 352 + i * 9 + int(sin(flicker * 1.4 + i) * 3.0)
		draw_line(Vector2(0, y), Vector2(900, y + 10), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.13), 2)
	_floor_reflections()


func _draw_beach() -> void:
	# Night beach below the casino docks with surf, boardwalk neon, towels, and a suspicious sand pile.
	draw_rect(Rect2(0, 0, 900, 246), Color("#071221"))
	draw_rect(Rect2(0, 0, 900, 80), Color("#061025"))
	for x in range(0, 900, 120):
		draw_rect(Rect2(x + 18, 26, 64, 8), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.16))
		draw_rect(Rect2(x + 40, 42, 84, 6), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.12))
	draw_rect(Rect2(0, 78, 900, 112), Color("#08233a"))
	for i in range(8):
		var y := 90 + i * 13 + int(sin(flicker * 1.1 + i) * 2.0)
		draw_line(Vector2(0, y), Vector2(900, y - 8), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.14), 2)
	draw_rect(Rect2(0, 180, 900, 120), Color("#a36832"))
	for x in range(0, 900, 48):
		draw_rect(Rect2(x, 184 + int(sin(float(x)) * 3.0), 34, 3), Color("#d18d45"))
	draw_rect(Rect2(0, 238, 900, 78), Color("#3c2517"))
	for x in range(0, 900, 64):
		draw_line(Vector2(x, 238), Vector2(x + 16, 316), Color("#6b4624"), 2)
	draw_line(Vector2(0, 238), Vector2(900, 238), C_AMBER, 3)
	draw_rect(Rect2(76, 198, 170, 36), Color("#151025"))
	draw_rect(Rect2(88, 206, 146, 10), C_PINK_2.darkened(0.10))
	draw_rect(Rect2(106, 214, 112, 7), C_CYAN.darkened(0.20))
	draw_line(Vector2(300, 198), Vector2(300, 272), C_AMBER, 3)
	draw_line(Vector2(300, 198), Vector2(248, 232), C_PINK, 8)
	draw_line(Vector2(300, 198), Vector2(352, 232), C_PINK, 8)
	draw_line(Vector2(248, 232), Vector2(352, 232), C_PINK, 5)
	draw_line(Vector2(300, 198), Vector2(270, 238), C_CYAN, 7)
	draw_line(Vector2(300, 198), Vector2(330, 238), C_CYAN, 7)
	draw_line(Vector2(270, 238), Vector2(330, 238), C_CYAN, 4)
	draw_rect(Rect2(616, 192, 130, 42), Color("#080d16"))
	_neon_text("BEACH", Vector2(634, 220), 21, C_YELLOW)
	draw_rect(Rect2(650, 66, 132, 44), Color("#101a25"))
	draw_rect(Rect2(662, 76, 108, 16), C_AMBER.darkened(0.10))
	_slot_machine(Rect2(704, 112, 72, 118), C_CYAN)
	_floor_reflections()


func _draw_gas_station() -> void:
	# Converted gas station with canopy, highway window, slot row, cage, camera, and fluorescents.
	draw_rect(Rect2(0, 0, 900, 248), Color("#101122"))
	draw_rect(Rect2(0, 34, 900, 36), Color("#1f1f31"))
	draw_rect(Rect2(0, 70, 900, 8), C_CYAN_2)
	for x in [90, 412, 770]:
		draw_rect(Rect2(x, 0, 22, 212), Color("#25253a"))
	draw_rect(Rect2(50, 96, 258, 96), Color("#060611"))
	draw_line(Vector2(64, 154), Vector2(294, 132), C_PINK, 2)
	draw_line(Vector2(64, 170), Vector2(294, 160), C_PURPLE_2, 2)
	_neon_text("HIGHWAY", Vector2(82, 116), 18, C_CYAN)
	for x in [348, 444, 540]:
		_slot_machine(Rect2(x, 122, 74, 120), _cycle_color(x))
	draw_rect(Rect2(660, 104, 166, 120), Color("#171726"))
	for x in range(672, 810, 18):
		draw_line(Vector2(x, 106), Vector2(x, 222), C_SOFT.darkened(0.2), 1)
	_silhouette(Vector2(744, 182), 0.8, C_SHADOW)
	draw_rect(Rect2(720, 70, 38, 24), C_SHADOW)
	draw_line(Vector2(739, 94), Vector2(782, 126), C_CYAN, 2)
	draw_rect(Rect2(780, 124, 20, 16), Color("#05050b"))
	_floor_reflections()


func _draw_underground() -> void:
	# Basement casino with low ceiling, felt tables, guard, string lights, smoke, and bar cart.
	draw_rect(Rect2(0, 0, 900, 245), Color("#0d0a18"))
	for y in [34, 68, 102]:
		draw_rect(Rect2(0, y, 900, 8), Color("#1d1730"))
	draw_rect(Rect2(0, 0, 900, 26), Color("#21173a"))
	for x in range(54, 850, 72):
		draw_line(Vector2(x, 28), Vector2(x + 42, 56), C_SHADOW, 2)
		draw_circle(Vector2(x + 42, 56), 5, _cycle_color(x))
	draw_rect(Rect2(100, 154, 242, 86), Color("#12402f"))
	draw_rect(Rect2(118, 168, 206, 54), Color("#176d4f"))
	draw_rect(Rect2(438, 142, 258, 98), Color("#123c30"))
	draw_rect(Rect2(456, 158, 222, 62), Color("#187452"))
	for x in [150, 196, 242, 504, 550, 596]:
		_card_back(Rect2(x, 134 + (x % 2) * 8, 28, 38))
	_silhouette(Vector2(790, 190), 1.35, C_SHADOW)
	draw_rect(Rect2(744, 88, 108, 178), Color("#08080f"))
	draw_rect(Rect2(40, 188, 70, 82), Color("#352214"))
	draw_rect(Rect2(48, 168, 54, 20), C_AMBER)
	draw_rect(Rect2(58, 146, 12, 22), C_PURPLE_2)
	draw_rect(Rect2(78, 142, 12, 26), C_TEAL)
	for i in range(8):
		draw_rect(Rect2(i * 120, 96 + i % 3 * 16, 240, 28), Color(1.0, 0.45, 0.7, 0.035))
	_floor_reflections()


func _draw_grand_casino() -> void:
	# Boss-floor casino: broad pit, velvet ropes, watched tables, slot wall, cameras, and pit boss.
	draw_rect(Rect2(0, 0, 900, 246), Color("#090914"))
	for x in range(0, 900, 90):
		draw_rect(Rect2(x, 0, 48, 246), Color("#11112a"))
		draw_rect(Rect2(x + 48, 0, 42, 246), Color("#0d0d1a"))
	draw_rect(Rect2(0, 0, 900, 34), Color("#1b1034"))
	draw_rect(Rect2(0, 34, 900, 6), C_PINK)
	_neon_text("GRAND", Vector2(340, 62), 42, C_YELLOW)
	_neon_text("NO CUTE MOVES", Vector2(300, 104), 20, C_CYAN)
	for x in [96, 208, 692, 804]:
		draw_rect(Rect2(x, 46, 64, 118), Color("#120b24"))
		draw_rect(Rect2(x + 8, 56, 48, 74), Color("#251044"))
		draw_rect(Rect2(x + 18, 132, 28, 10), C_AMBER)
	for x in [238, 348, 552, 662]:
		_slot_machine(Rect2(x, 124, 70, 116), _cycle_color(x))
	draw_rect(Rect2(82, 184, 258, 82), Color("#123f30"))
	draw_rect(Rect2(104, 198, 214, 46), Color("#1a7755"))
	draw_rect(Rect2(562, 184, 258, 82), Color("#123f30"))
	draw_rect(Rect2(584, 198, 214, 46), Color("#1a7755"))
	for x in [146, 196, 246, 626, 676, 726]:
		_card_back(Rect2(x, 166 + (x % 3) * 5, 26, 36))
	for x in [82, 340, 560, 820]:
		draw_line(Vector2(x, 246), Vector2(x, 294), C_AMBER, 4)
	for x in [82, 340, 560]:
		draw_line(Vector2(x, 254), Vector2(x + 220, 254), C_PINK_2, 3)
	draw_rect(Rect2(392, 132, 116, 152), Color("#05050b"))
	_silhouette(Vector2(450, 206), 1.38, Color("#05050b"))
	draw_rect(Rect2(416, 154, 68, 8), C_PINK)
	draw_rect(Rect2(426, 170, 48, 6), C_CYAN)
	for x in [252, 450, 648]:
		draw_line(Vector2(x, 40), Vector2(x, 74), C_SOFT.darkened(0.2), 2)
		draw_rect(Rect2(x - 16, 74, 32, 18), C_SHADOW)
		draw_line(Vector2(x, 92), Vector2(x + 56, 132), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.28), 3)
	for x in range(36, 864, 72):
		draw_rect(Rect2(x, 286 + int(sin(flicker * 2.2 + x) * 3.0), 42, 4), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.32))
		draw_rect(Rect2(x + 10, 302, 76, 2), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.22))


func _draw_scene_life() -> void:
	# Venue animation overlays run on both production PNGs and procedural fallback art.
	# They sit below interactable props so motion never hides gameplay-critical clicks.
	_draw_floor_sheen()
	match environment_id:
		"corner_store":
			_draw_sign_pulse(Rect2(642, 64, 172, 58), C_CYAN, 0.20, 4.6)
			_draw_sign_pulse(Rect2(376, 42, 168, 34), C_YELLOW, 0.18, 6.2)
			_draw_scan_bands(36, 820, 20, 72, C_SOFT, 0.10, 1.9)
			var scan_x := 372 + int(abs(sin(flicker * 3.0)) * 164.0)
			draw_rect(Rect2(scan_x, 206, 22, 5), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.72))
			draw_rect(Rect2(452, 114 + int(sin(flicker * 2.0) * 2.0), 16, 4), C_SOFT)
			_draw_sparkles(SCENE_SPARKLES_CORNER_STORE, C_TEAL, 0.18)
		"back_alley":
			var bulb_alpha: float = 0.18 + absf(sin(flicker * 4.0)) * 0.18
			draw_rect(Rect2(374, 124, 152, 102), Color(1.0, 0.85, 0.28, bulb_alpha))
			_draw_light_cone(Vector2(450, 116), Vector2(0, 128), C_AMBER, 0.10 + bulb_alpha * 0.22)
			_draw_rain_streaks(18, 92.0, C_CYAN, 0.18)
			for i in range(8):
				var x := int(fmod(flicker * 90.0 + float(i * 113), float(BOARD_SIZE.x)))
				draw_rect(Rect2(x, 282 + i % 3 * 12, 34, 2), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.28))
			_draw_puddle_ripples(SCENE_PUDDLES_BACK_ALLEY, C_CYAN)
			_draw_sparkles(SCENE_SPARKLES_BACK_ALLEY, C_ORANGE, 0.30)
		"motel":
			_draw_sign_pulse(Rect2(62, 72, 202, 116), C_PINK, 0.16, 5.0)
			for i in range(10):
				var y := 126 + i * 6
				draw_rect(Rect2(684, y, 106, 2), Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.12 + fmod(flicker + i, 1.0) * 0.18))
			draw_rect(Rect2(82, 118, 150, 8), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.22 + abs(sin(flicker * 5.0)) * 0.18))
			_draw_scan_bands(680, 790, 126, 188, C_SOFT, 0.16, 8.0)
			_draw_sparkles(SCENE_SPARKLES_MOTEL, C_CYAN, 0.16)
		"motel_room":
			_draw_sign_pulse(Rect2(72, 74, 220, 120), C_PINK, 0.14, 4.8)
			_draw_scan_bands(670, 744, 108, 158, C_SOFT, 0.14, 6.0)
			draw_rect(Rect2(372, 130, 242, 6), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.18 + abs(sin(flicker * 3.0)) * 0.15))
		"apartment":
			_draw_sign_pulse(Rect2(76, 70, 170, 92), C_CYAN, 0.09, 3.2)
			_draw_smoke_bands(324, 546, 108, C_CYAN, 0.022)
			draw_rect(Rect2(624, 96, 136, 8), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.18 + abs(sin(flicker * 2.4)) * 0.12))
		"house":
			_draw_sign_pulse(Rect2(648, 88, 136, 110), C_YELLOW, 0.08, 2.8)
			_draw_smoke_bands(342, 536, 112, C_AMBER, 0.024)
			draw_rect(Rect2(350, 116, 188, 7), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.12 + abs(sin(flicker * 2.1)) * 0.10))
		"bar":
			_draw_sign_pulse(Rect2(616, 52, 122, 40), C_PINK, 0.22, 4.0)
			_draw_sign_pulse(Rect2(596, 102, 172, 34), C_CYAN, 0.17, 5.4)
			draw_circle(Vector2(642 + sin(flicker * 1.5) * 7.0, 222), 5, C_WHITE)
			draw_circle(Vector2(756 + cos(flicker * 1.7) * 5.0, 232), 4, C_WHITE)
			draw_rect(Rect2(780, 158, 58, 48), Color(C_PURPLE.r, C_PURPLE.g, C_PURPLE.b, 0.20 + abs(sin(flicker * 6.0)) * 0.18))
			_draw_smoke_bands(96, 520, 72, C_CYAN, 0.035)
			_draw_sparkles(SCENE_SPARKLES_BAR, C_YELLOW, 0.20)
		"jazz_club":
			_draw_sign_pulse(Rect2(116, 38, 302, 54), C_AMBER, 0.16, 3.6)
			_draw_sign_pulse(Rect2(696, 146, 124, 34), C_PINK, 0.20, 4.8)
			_draw_smoke_bands(58, 826, 76, C_AMBER, 0.045)
			_draw_smoke_bands(140, 760, 132, C_CYAN, 0.026)
			var cymbal_alpha := 0.22 + absf(sin(flicker * 8.0)) * 0.24
			draw_circle(Vector2(466, 168), 15, Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, cymbal_alpha))
			draw_rect(Rect2(718, 184, 48, 18), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.18 + absf(sin(flicker * 5.2)) * 0.16))
			_draw_sparkles(SCENE_SPARKLES_JAZZ_CLUB, C_YELLOW, 0.18)
		"kitty_cat_lounge":
			_draw_sign_pulse(Rect2(116, 46, 404, 48), C_PINK, 0.18, 3.8)
			_draw_smoke_bands(70, 820, 92, C_PINK, 0.044)
			_draw_smoke_bands(120, 760, 138, C_CYAN, 0.026)
			draw_circle(Vector2(704, 274), 40, Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.10 + absf(sin(flicker * 3.0)) * 0.14))
			for x in [122, 292, 464, 622, 762]:
				draw_rect(Rect2(x, 302 + int(sin(flicker * 2.0 + x) * 2.0), 16, 4), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.30))
			_draw_sparkles(SCENE_SPARKLES_KITTY_CAT, C_YELLOW, 0.20)
		"delta_queen":
			_draw_sign_pulse(Rect2(254, 46, 372, 52), C_YELLOW, 0.14, 3.5)
			for i in range(7):
				var y := 354 + i * 10 + int(sin(flicker * 1.7 + i) * 4.0)
				draw_line(Vector2(0, y), Vector2(900, y + 9), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.10), 2)
			var dock_x := int(fmod(flicker * 28.0, 960.0)) - 60
			draw_rect(Rect2(dock_x, 108, 52, 8), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.32))
			draw_rect(Rect2(dock_x + 8, 116, 6, 42), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.22))
			_draw_sparkles(SCENE_SPARKLES_DELTA_QUEEN, C_CYAN, 0.16)
		"beach":
			for i in range(8):
				var y := 92 + i * 13 + int(sin(flicker * 1.6 + i) * 4.0)
				draw_line(Vector2(0, y), Vector2(900, y - 8), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.12), 2)
			var boat_x := int(fmod(flicker * 16.0, 980.0)) - 80
			draw_rect(Rect2(boat_x, 72, 64, 9), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.26))
			draw_rect(Rect2(boat_x + 16, 56, 28, 16), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.20))
			_draw_sign_pulse(Rect2(650, 66, 132, 44), C_YELLOW, 0.12, 4.2)
			_draw_sparkles(SCENE_SPARKLES_DELTA_QUEEN, C_YELLOW, 0.12)
		"gas_station_casino":
			var sweep := 724 + int(abs(sin(flicker * 1.8)) * 72.0)
			var hot := sin(flicker * 1.8) > 0.25
			var laser_color := C_PINK if hot else C_CYAN
			_draw_camera_sweep(Vector2(739, 94), Vector2(sweep, 190), laser_color, 0.42)
			draw_rect(Rect2(sweep - 10, 190, 20, 5), Color(laser_color.r, laser_color.g, laser_color.b, 0.36))
			for x in [348, 444, 540]:
				draw_rect(Rect2(x + 12, 132, 50, 8), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.18 + abs(sin(flicker * 5.0 + x)) * 0.22))
			_draw_headlights()
			_draw_scan_bands(0, 900, 42, 76, C_SOFT, 0.08, 2.4)
		"small_underground_casino":
			for i in range(6):
				var x := int(fmod(flicker * 16.0 + float(i * 160), 1040.0)) - 120
				draw_rect(Rect2(x, 116 + i * 18, 260, 16), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.045))
			draw_rect(Rect2(770, 140, 38, 5), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.28 + abs(sin(flicker * 3.0)) * 0.18))
			_draw_smoke_bands(24, 840, 92, C_PINK, 0.05)
			_draw_string_lights()
			_draw_sparkles(SCENE_SPARKLES_UNDERGROUND, C_TEAL, 0.16)
		"grand_casino":
			for i in range(5):
				var x := 250 + i * 100
				draw_rect(Rect2(x, 124, 52, 8), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.14 + abs(sin(flicker * 5.0 + i)) * 0.20))
			var watch_status := _pit_boss_watch_snapshot()
			var sweep := 250 + int(abs(sin(flicker * 1.35)) * 400.0)
			var watched := bool(watch_status.get("watched", false))
			var beam := C_PINK if watched else C_CYAN
			var primary_alpha := 0.42 if watched else 0.20
			_draw_camera_sweep(Vector2(450, 92), Vector2(sweep, 226), beam, primary_alpha)
			_draw_camera_sweep(Vector2(252, 92), Vector2(170 + int(abs(sin(flicker * 1.0)) * 210.0), 220), C_CYAN, 0.18)
			_draw_camera_sweep(Vector2(648, 92), Vector2(520 + int(abs(cos(flicker * 1.1)) * 210.0), 220), C_CYAN, 0.18)
			var boss_x := 414 + sin(flicker * 0.75) * (32.0 if watched else 86.0)
			_silhouette(Vector2(boss_x, 218), 0.70, Color("#05050b"))
			var badge_color := C_POLICE_RED if watched else C_CYAN
			draw_rect(Rect2(386, 150, 128, 18), Color(0.0, 0.0, 0.0, 0.50))
			draw_rect(Rect2(392, 154, 116, 5), Color(badge_color.r, badge_color.g, badge_color.b, 0.34 + abs(sin(flicker * 2.4)) * 0.28))
			_neon_text("WATCHED" if watched else "CLEAR", Vector2(414, 164), 12, badge_color)
			_draw_sign_pulse(Rect2(336, 58, 226, 54), C_YELLOW, 0.14, 3.8)
			_draw_sparkles(SCENE_SPARKLES_GRAND_CASINO, C_YELLOW, 0.18)


func _draw_familiar_characters() -> void:
	# Recurring venue characters provide social pressure and make rooms readable.
	match environment_id:
		"corner_store":
			_draw_named_character("mara", Vector2(465, 198), 0.78, "clerk")
		"back_alley":
			_draw_named_character("vince", Vector2(110, 240), 0.88, "watcher")
			_draw_named_character("lena", Vector2(780, 242), 0.82, "dealer")
		"motel":
			_draw_named_character("june", Vector2(610, 214), 0.82, "dealer")
			_draw_named_character("marco", Vector2(748, 222), 0.72, "fixer")
		"bar":
			_draw_named_character("rafi", Vector2(188, 184), 0.76, "bartender")
			_draw_named_character("dot", Vector2(500, 184), 0.70, "regular")
		"jazz_club":
			_draw_named_character("rafi", Vector2(824, 206), 0.66, "bartender")
			_draw_named_character("dot", Vector2(614, 248), 0.52, "regular")
		"kitty_cat_lounge":
			_draw_named_character("iris", Vector2(618, 204), 0.70, "host")
			_draw_named_character("dot", Vector2(304, 236), 0.58, "regular")
		"delta_queen":
			_draw_named_character("sable", Vector2(436, 176), 0.70, "dealer")
			_draw_named_character("ox", Vector2(790, 210), 0.86, "deck_boss")
		"gas_station_casino":
			_draw_named_character("nell", Vector2(746, 190), 0.76, "attendant")
			_draw_watch_camera(Vector2(744, 72), C_PINK)
		"small_underground_casino":
			_draw_named_character("sable", Vector2(505, 155), 0.72, "dealer")
			_draw_named_character("ox", Vector2(794, 205), 1.02, "bouncer")
		"grand_casino":
			_draw_named_character("rourke", Vector2(450 + sin(flicker * 0.75) * 70.0, 222), 1.04, "pit_boss")
			_draw_named_character("iris", Vector2(632, 180), 0.76, "dealer")


func _draw_named_character(id: String, foot: Vector2, scale_value: float, role: String) -> void:
	var style := _character_style(id)
	var skin: Color = style["skin"]
	var hair: Color = style["hair"]
	var jacket: Color = style["jacket"]
	var accent: Color = style["accent"]
	var sway := sin(flicker * float(style["tempo"]) + float(style["phase"])) * 2.0
	var pos := foot + Vector2(sway, 0)
	var head := Rect2(pos + Vector2(-10, -66) * scale_value, Vector2(20, 20) * scale_value)
	var body := Rect2(pos + Vector2(-17, -46) * scale_value, Vector2(34, 44) * scale_value)
	var shoulder_y := pos.y - 38 * scale_value
	draw_rect(Rect2(pos.x - 18 * scale_value, pos.y - 6 * scale_value, 36 * scale_value, 4 * scale_value), Color(0.0, 0.0, 0.0, 0.36))
	draw_rect(body, Color("#06070c"))
	draw_rect(Rect2(body.position + Vector2(3, 4) * scale_value, body.size - Vector2(6, 7) * scale_value), jacket)
	draw_rect(Rect2(pos + Vector2(-23, -36) * scale_value, Vector2(8, 35) * scale_value), Color("#05060a"))
	draw_rect(Rect2(pos + Vector2(15, -36) * scale_value, Vector2(8, 35) * scale_value), Color("#05060a"))
	draw_rect(head, skin)
	draw_rect(Rect2(head.position + Vector2(0, 0), Vector2(head.size.x, 7 * scale_value)), hair)
	draw_rect(Rect2(head.position + Vector2(4, 9) * scale_value, Vector2(4, 3) * scale_value), Color("#05060a"))
	draw_rect(Rect2(head.position + Vector2(13, 9) * scale_value, Vector2(4, 3) * scale_value), Color("#05060a"))
	draw_rect(Rect2(pos + Vector2(-15, -48) * scale_value, Vector2(30, 5) * scale_value), accent)
	draw_line(Vector2(pos.x - 24 * scale_value, shoulder_y), Vector2(pos.x + 24 * scale_value, shoulder_y), Color(accent.r, accent.g, accent.b, 0.45), maxf(1.0, 3.0 * scale_value))
	match role:
		"watcher", "bouncer", "pit_boss":
			draw_rect(Rect2(pos + Vector2(14, -55) * scale_value, Vector2(10, 4) * scale_value), C_PINK)
		"dealer":
			_card_back(Rect2(pos + Vector2(-25, -26) * scale_value, Vector2(16, 22) * scale_value))
		"bartender", "attendant", "clerk":
			draw_rect(Rect2(pos + Vector2(16, -24) * scale_value, Vector2(7, 16) * scale_value), C_AMBER)
		"regular", "fixer":
			draw_rect(Rect2(pos + Vector2(-25, -20) * scale_value, Vector2(16, 5) * scale_value), C_CYAN)


func _character_style(id: String) -> Dictionary:
	var styles := {
		"mara": {"skin": Color("#d9a36a"), "hair": Color("#271018"), "jacket": Color("#24404a"), "accent": C_CYAN, "tempo": 1.0, "phase": 0.2},
		"vince": {"skin": Color("#a66a50"), "hair": Color("#06070c"), "jacket": Color("#34102b"), "accent": C_PINK, "tempo": 1.6, "phase": 2.1},
		"lena": {"skin": Color("#c98665"), "hair": Color("#161025"), "jacket": Color("#273344"), "accent": C_AMBER, "tempo": 1.3, "phase": 0.7},
		"june": {"skin": Color("#d0a07c"), "hair": Color("#332010"), "jacket": Color("#21363a"), "accent": C_TEAL, "tempo": 0.9, "phase": 1.8},
		"marco": {"skin": Color("#bd7b5d"), "hair": Color("#0f0b0a"), "jacket": Color("#3d2142"), "accent": C_ORANGE, "tempo": 1.1, "phase": 2.5},
		"rafi": {"skin": Color("#b7755c"), "hair": Color("#08090e"), "jacket": Color("#2f1a18"), "accent": C_YELLOW, "tempo": 1.4, "phase": 0.4},
		"dot": {"skin": Color("#dfb28d"), "hair": Color("#551b42"), "jacket": Color("#26315a"), "accent": C_PINK_2, "tempo": 1.8, "phase": 1.0},
		"nell": {"skin": Color("#c48968"), "hair": Color("#513315"), "jacket": Color("#27384f"), "accent": C_YELLOW, "tempo": 0.8, "phase": 1.4},
		"sable": {"skin": Color("#b87a63"), "hair": Color("#05060a"), "jacket": Color("#1b2f2a"), "accent": C_TEAL, "tempo": 0.7, "phase": 2.0},
		"ox": {"skin": Color("#8f5a48"), "hair": Color("#05060a"), "jacket": Color("#11131f"), "accent": C_ORANGE, "tempo": 0.55, "phase": 0.0},
		"rourke": {"skin": Color("#d1a072"), "hair": Color("#ede0b5"), "jacket": Color("#161017"), "accent": C_PINK, "tempo": 0.65, "phase": 1.2},
		"iris": {"skin": Color("#cca17e"), "hair": Color("#2b1630"), "jacket": Color("#20203c"), "accent": C_CYAN, "tempo": 0.85, "phase": 2.6},
	}
	return styles.get(id, styles["mara"])


func _draw_watch_camera(pos: Vector2, accent: Color) -> void:
	draw_rect(Rect2(pos + Vector2(-20, -10), Vector2(40, 20)), Color("#05060a"))
	draw_rect(Rect2(pos + Vector2(-8, -5), Vector2(16, 10)), C_SHADOW)
	draw_rect(Rect2(pos + Vector2(-3, -3), Vector2(6, 6)), accent)


func _draw_interactable_light(rect: Rect2, accent: Color, selected: bool) -> void:
	var alpha := 0.14 + absf(sin(flicker * 2.4 + rect.position.x * 0.02)) * 0.08
	if selected:
		alpha += 0.16
	var cone_top := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.05)
	var left := rect.position + Vector2(rect.size.x * 0.04, rect.size.y * 0.82)
	var right := rect.position + Vector2(rect.size.x * 0.96, rect.size.y * 0.82)
	draw_polygon([cone_top, right, left], [Color(accent.r, accent.g, accent.b, alpha * 0.16)])
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.10, rect.size.y * 0.74), Vector2(rect.size.x * 0.80, 8)), Color(accent.r, accent.g, accent.b, alpha))


func _draw_floor_sheen() -> void:
	for i in range(7):
		var x := int(fmod(flicker * (18.0 + float(i) * 2.5) + float(i * 137), 1040.0)) - 90
		var y := 274 + (i % 4) * 14
		var color := _cycle_color(i * 31)
		draw_rect(Rect2(x, y, 72 - i * 4, 2), Color(color.r, color.g, color.b, 0.08))


func _draw_sign_pulse(rect: Rect2, color: Color, base_alpha: float, speed: float) -> void:
	var alpha := base_alpha + absf(sin(flicker * speed + rect.position.x * 0.01)) * base_alpha
	draw_rect(rect.grow(4.0), Color(color.r, color.g, color.b, alpha * 0.18))
	draw_rect(Rect2(rect.position + Vector2(4, rect.size.y - 6), Vector2(rect.size.x - 8, 3)), Color(color.r, color.g, color.b, alpha))


func _draw_scan_bands(x0: int, x1: int, y0: int, y1: int, color: Color, alpha: float, speed: float) -> void:
	var height := maxi(1, y1 - y0)
	var band_y := y0 + int(fmod(flicker * speed * 20.0, float(height)))
	draw_rect(Rect2(x0, band_y, x1 - x0, 2), Color(color.r, color.g, color.b, alpha))
	draw_rect(Rect2(x0, y0 + int(fmod(float(band_y - y0 + 19), float(height))), x1 - x0, 1), Color(color.r, color.g, color.b, alpha * 0.55))


func _draw_sparkles(points: Array, color: Color, alpha: float) -> void:
	for i in range(points.size()):
		var p: Vector2 = points[i]
		var pulse := alpha + absf(sin(flicker * 4.2 + float(i) * 1.7)) * alpha
		draw_rect(Rect2(p + Vector2(-1, -4), Vector2(2, 8)), Color(color.r, color.g, color.b, pulse))
		draw_rect(Rect2(p + Vector2(-4, -1), Vector2(8, 2)), Color(color.r, color.g, color.b, pulse))


func _draw_light_cone(origin: Vector2, fall: Vector2, color: Color, alpha: float) -> void:
	var top := origin + Vector2(-38, 0)
	var bottom_left := origin + Vector2(-118, fall.y)
	var bottom_right := origin + Vector2(118, fall.y)
	draw_polygon([top, origin + Vector2(38, 0), bottom_right, bottom_left], [Color(color.r, color.g, color.b, alpha)])


func _draw_rain_streaks(count: int, speed: float, color: Color, alpha: float) -> void:
	for i in range(count):
		var x := int(fmod(flicker * speed + float(i * 53), 960.0)) - 40
		var y := int(fmod(flicker * (speed * 1.7) + float(i * 71), 360.0)) - 20
		draw_line(Vector2(x, y), Vector2(x - 16, y + 48), Color(color.r, color.g, color.b, alpha), 1)


func _draw_puddle_ripples(points: Array, color: Color) -> void:
	for i in range(points.size()):
		var p: Vector2 = points[i]
		var phase := absf(sin(flicker * 2.8 + float(i)))
		var w := 18.0 + phase * 34.0
		draw_rect(Rect2(p + Vector2(-w * 0.5, 0), Vector2(w, 2)), Color(color.r, color.g, color.b, 0.16 * (1.0 - phase * 0.35)))


func _draw_smoke_bands(x0: int, x1: int, y: int, color: Color, alpha: float) -> void:
	for i in range(5):
		var x := int(fmod(flicker * (10.0 + i * 2.0) + float(i * 150), float(x1 - x0 + 220))) + x0 - 110
		var yy := y + i * 18 + int(sin(flicker * 1.4 + float(i)) * 5.0)
		draw_rect(Rect2(x, yy, 180 - i * 16, 10), Color(color.r, color.g, color.b, alpha))


func _draw_camera_sweep(origin: Vector2, target: Vector2, color: Color, alpha: float) -> void:
	draw_line(origin, target, Color(color.r, color.g, color.b, alpha), 3)
	draw_line(origin + Vector2(-8, 0), target + Vector2(-18, 8), Color(color.r, color.g, color.b, alpha * 0.30), 1)
	draw_line(origin + Vector2(8, 0), target + Vector2(18, 8), Color(color.r, color.g, color.b, alpha * 0.30), 1)


func _draw_headlights() -> void:
	var x := int(fmod(flicker * 150.0, 980.0)) - 80
	draw_rect(Rect2(x, 150, 58, 3), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.34))
	draw_rect(Rect2(x + 24, 166, 86, 2), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.20))


func _draw_string_lights() -> void:
	for i in range(10):
		var x := 58 + i * 74
		var alpha := 0.16 + absf(sin(flicker * 3.2 + float(i) * 0.8)) * 0.24
		var color := _cycle_color(x)
		draw_rect(Rect2(x + 39, 55, 8, 8), Color(color.r, color.g, color.b, alpha))


func _draw_scene_objects() -> void:
	# Interactable props are rendered here; transparent buttons only provide hit testing.
	for object_data in _active_scene_objects():
		var rect := _board_rect_for_object(object_data)
		var object_id := str(object_data.get("id", ""))
		var object_type := str(object_data.get("type", "item"))
		var selected := object_id == selected_object_id
		var hovered := object_id == hovered_object_id
		var disabled := bool(object_data.get("disabled", false))
		_draw_object_shadow(rect, selected or hovered)
		match object_type:
			"game":
				_draw_game_prop(rect, object_data, selected or hovered)
			"travel":
				_draw_travel_prop(rect, object_data, selected or hovered)
			"event":
				_draw_event_prop(rect, object_data, selected or hovered)
			"drink":
				_draw_drink_prop(rect, selected or hovered)
			_:
				_draw_item_prop(rect, object_data, selected or hovered, str(object_data.get("surface", "counter")))
		if disabled:
			_draw_disabled_scene_mark(rect)
		if disabled and (selected or hovered):
			_draw_disabled_focus_mark(rect, selected)
		elif selected:
			_draw_selected_scene_mark(rect)
			if object_type in ["item", "drink"]:
				_draw_selected_item_frame(rect, object_type)
		elif hovered:
			_draw_hover_scene_mark(rect)
		elif not disabled:
			_draw_hotspot_hint(rect, object_type)
		_draw_object_label(rect, str(object_data.get("label", "")), object_type, disabled, selected or hovered)
	_draw_selected_object_info()


func _draw_selected_object_info() -> void:
	var info := _selected_object_info()
	if info.is_empty():
		return
	var object_data: Dictionary = info.get("object", {})
	var object_type := str(object_data.get("type", "item"))
	var card := _animated_info_card_rect(info)
	var title := str(info.get("title", "")).strip_edges()
	var lines: Array = info.get("lines", [])
	var accent := _color_for_object_type(object_type)
	var header_color := C_WHITE if title.is_empty() else accent
	draw_rect(card, Color(0.0, 0.0, 0.0, 0.82))
	draw_rect(card, Color(accent.r, accent.g, accent.b, 0.30))
	draw_rect(card, Color(accent.r, accent.g, accent.b, 0.82), false, 1)
	draw_line(card.position + Vector2(0, OBJECT_INFO_HEADER_RULE_Y), Vector2(card.end.x, card.position.y + OBJECT_INFO_HEADER_RULE_Y), Color(accent.r, accent.g, accent.b, 0.34), 1)
	var font := get_theme_default_font()
	var type_text := _player_facing_object_type(object_type)
	var title_text := title if not title.is_empty() else type_text
	var type_width := _object_info_type_width(type_text, font)
	var title_width := maxf(20.0, card.size.x - type_width - OBJECT_INFO_PADDING_X * 2.0 - OBJECT_INFO_TYPE_GAP)
	draw_string(font, card.position + Vector2(OBJECT_INFO_PADDING_X, OBJECT_INFO_HEADER_Y), _fit_draw_text(title_text, font, 11, title_width), HORIZONTAL_ALIGNMENT_LEFT, title_width, 11, header_color)
	draw_string(font, card.position + Vector2(card.size.x - OBJECT_INFO_PADDING_X - type_width, OBJECT_INFO_HEADER_Y), _fit_draw_text(type_text, font, 8, type_width), HORIZONTAL_ALIGNMENT_RIGHT, type_width, 8, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.82))
	var y := card.position.y + OBJECT_INFO_BODY_Y
	if lines.is_empty():
		lines = [_fallback_object_description(object_data)]
	var badges := _array_view(object_data.get("attribute_badges", []))
	if not badges.is_empty():
		var row_rect := AttributeBadgeRowScript.draw_canvas(self, badges, Vector2(card.position.x + OBJECT_INFO_PADDING_X, y), card.size.x - OBJECT_INFO_PADDING_X * 2.0, 12)
		y += row_rect.size.y + 4.0
	var action_area_height := _selected_info_action_area_height(object_data)
	var body_bottom := card.end.y - OBJECT_INFO_BOTTOM_PADDING
	if action_area_height > 0.0:
		body_bottom -= OBJECT_INFO_ACTION_GAP + action_area_height
	for line in lines:
		if y > body_bottom:
			break
		draw_string(font, Vector2(card.position.x + OBJECT_INFO_PADDING_X, y), _fit_draw_text(str(line), font, 9, card.size.x - OBJECT_INFO_PADDING_X * 2.0), HORIZONTAL_ALIGNMENT_LEFT, card.size.x - OBJECT_INFO_PADDING_X * 2.0, 9, C_SOFT)
		y += OBJECT_INFO_LINE_HEIGHT
	if _selected_info_has_action_button(object_data):
		var mouse_board_position := _local_to_board_position(get_local_mouse_position())
		for entry in _selected_info_action_entries_for_rect(info, card):
			var button_rect: Rect2 = entry.get("button_rect", Rect2())
			if button_rect.size.x <= 0.0 or button_rect.size.y <= 0.0:
				continue
			var detail_rect: Rect2 = entry.get("detail_rect", Rect2())
			var hovered := button_rect.has_point(mouse_board_position)
			var selected := bool(entry.get("selected", false))
			var button_alpha := 0.22
			if selected:
				button_alpha = 0.30
			if hovered:
				button_alpha = 0.40
			draw_rect(button_rect, Color(accent.r, accent.g, accent.b, button_alpha))
			draw_rect(button_rect, C_WHITE if hovered else accent, false, 1)
			var label_font_size := 11 if bool(entry.get("inline", false)) else 9
			var label_baseline := 13.0 if bool(entry.get("inline", false)) else 12.0
			draw_string(font, button_rect.position + Vector2(0.0, label_baseline), _fit_draw_text(str(entry.get("label", "")), font, label_font_size, button_rect.size.x - 8.0), HORIZONTAL_ALIGNMENT_CENTER, button_rect.size.x, label_font_size, C_WHITE)
			var detail := str(entry.get("detail", "")).strip_edges()
			if not detail.is_empty() and detail_rect.size.x > 0.0 and detail_rect.size.y > 0.0:
				draw_string(font, detail_rect.position + Vector2(0.0, 9.0), _fit_draw_text(detail, font, 8, detail_rect.size.x), HORIZONTAL_ALIGNMENT_CENTER, detail_rect.size.x, 8, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.86))


func _update_info_card_animation(delta: float) -> void:
	var info := _selected_object_info()
	if info.is_empty():
		info_card_visual_rect = Rect2()
		info_card_visual_object_id = ""
		info_card_animating = false
		return
	var object_id := str(info.get("object_id", ""))
	var target_rect: Rect2 = info.get("rect", Rect2())
	if target_rect.size.x <= 0.0 or target_rect.size.y <= 0.0:
		return
	if info_card_visual_object_id != object_id or info_card_visual_rect.size.x <= 0.0 or info_card_visual_rect.size.y <= 0.0:
		info_card_visual_object_id = object_id
		info_card_visual_rect = target_rect
		info_card_animating = false
		return
	var weight := _camera_lerp_weight(delta, OBJECT_INFO_ANIMATION_SPEED)
	info_card_visual_rect = _lerp_rect(info_card_visual_rect, target_rect, weight)
	if _rect_nearly_equal(info_card_visual_rect, target_rect, OBJECT_INFO_RECT_SNAP_EPSILON):
		info_card_visual_rect = target_rect
		info_card_animating = false
	else:
		info_card_animating = true


func _snap_info_card_to_target() -> void:
	var info := _selected_object_info()
	if info.is_empty():
		info_card_visual_rect = Rect2()
		info_card_visual_object_id = ""
		info_card_animating = false
		return
	info_card_visual_object_id = str(info.get("object_id", ""))
	var rect_value: Variant = info.get("rect", Rect2())
	info_card_visual_rect = rect_value if typeof(rect_value) == TYPE_RECT2 else Rect2()
	info_card_animating = false


func _animated_info_card_rect(info: Dictionary) -> Rect2:
	var target_rect: Rect2 = info.get("rect", Rect2())
	var object_id := str(info.get("object_id", ""))
	if object_id.is_empty() or object_id != info_card_visual_object_id:
		return target_rect
	if info_card_visual_rect.size.x <= 0.0 or info_card_visual_rect.size.y <= 0.0:
		return target_rect
	return info_card_visual_rect


func _lerp_rect(from_rect: Rect2, to_rect: Rect2, weight: float) -> Rect2:
	return Rect2(
		from_rect.position.lerp(to_rect.position, weight),
		from_rect.size.lerp(to_rect.size, weight)
	)


func _rect_nearly_equal(a: Rect2, b: Rect2, epsilon: float) -> bool:
	if a.position.distance_squared_to(b.position) > epsilon * epsilon:
		return false
	return a.size.distance_squared_to(b.size) <= epsilon * epsilon


func _draw_focus_dim_overlay() -> void:
	if not camera_focus_active:
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(BOARD_SIZE)), Color(0.0, 0.0, 0.0, 0.24))
	var selected_object := _scene_object(selected_object_id)
	if selected_object.is_empty():
		return
	var rect := _board_rect_for_object(selected_object)
	var glow_alpha := 0.18 + absf(sin(flicker * 4.2)) * 0.10
	var glow_color := _color_for_object_type(str(selected_object.get("type", "item")))
	_draw_prop_underlight(rect, glow_color, glow_alpha * 1.6)
	_draw_prop_glints(rect, glow_color, glow_alpha)


func _draw_scene_outcome_highlight() -> void:
	var outcome_view := _scene_outcome_view_snapshot()
	if not bool(outcome_view.get("visible", false)):
		return
	var outcome_object_id := str(outcome_view.get("object_id", ""))
	var object_data := _scene_object(outcome_object_id)
	if object_data.is_empty():
		return
	var object_rect := _board_rect_for_object(object_data)
	var accent := _color_for_object_type(str(object_data.get("type", "item")))
	var pulse := 0.34 + absf(sin(flicker * 5.6)) * 0.22
	_draw_prop_underlight(object_rect, accent, pulse)
	_draw_prop_glints(object_rect, accent, pulse * 0.65)


func _scene_outcome_view_snapshot() -> Dictionary:
	var message := str(foundation_snapshot.get("outcome_message", ""))
	var bankroll_delta := int(foundation_snapshot.get("outcome_bankroll_delta", 0))
	var suspicion_delta := int(foundation_snapshot.get("outcome_suspicion_delta", 0))
	if not _has_scene_outcome_feedback():
		return {"visible": false}
	return {
		"visible": true,
		"anchor": "environment_panel_top_right",
		"interaction_kind": "informational_result",
		"dismissible": true,
		"object_id": str(foundation_snapshot.get("outcome_object_id", "")),
		"message": message,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"popup_rect": {},
	}


func _has_scene_outcome_feedback() -> bool:
	if not uses_foundation_snapshot:
		return false
	var message := str(foundation_snapshot.get("outcome_message", ""))
	var bankroll_delta := int(foundation_snapshot.get("outcome_bankroll_delta", 0))
	var suspicion_delta := int(foundation_snapshot.get("outcome_suspicion_delta", 0))
	return not message.is_empty() or bankroll_delta != 0 or suspicion_delta != 0


func _active_scene_objects() -> Array:
	if uses_foundation_snapshot:
		return foundation_scene_objects
	return scene_objects


func _rebuild_scene_object_cache() -> void:
	scene_objects_by_id_cache = {}
	for object_value in _active_scene_objects():
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = object_value
		var object_id := str(object_data.get("id", ""))
		if not object_id.is_empty():
			scene_objects_by_id_cache[object_id] = object_data
		AttributeBadgeRowScript.warm_cache(_copy_array(object_data.get("attribute_badges", [])), 14)


func _objects_from_foundation_snapshot(snapshot: Dictionary) -> Array:
	var interactable_objects: Array = snapshot.get("interactable_objects", [])
	if not interactable_objects.is_empty():
		return _objects_from_interactable_records(interactable_objects)
	var objects: Array = []
	var games := _string_array(snapshot.get("game_ids", []))
	for index in range(games.size()):
		objects.append({
			"id": "game:%s" % games[index],
			"type": "game",
			"position": Vector2(0.28 + float(index % 3) * 0.18, 0.56 + float(index / 3) * 0.13),
			"size": Vector2(118, 72),
		})
	var events := _string_array(snapshot.get("event_ids", []))
	for index in range(events.size()):
		objects.append({
			"id": "event:%s" % events[index],
			"type": "event",
			"position": Vector2(0.68 + float(index % 2) * 0.12, 0.42 + float(index / 2) * 0.14),
			"size": Vector2(100, 64),
		})
	var offers: Array = snapshot.get("item_offers", [])
	for index in range(offers.size()):
		if typeof(offers[index]) != TYPE_DICTIONARY:
			continue
		var offer: Dictionary = offers[index]
		var item_id := str(offer.get("id", "item_%d" % index))
		objects.append({
			"id": "item:%s" % item_id,
			"type": "item",
			"label": str(offer.get("display_name", item_id)),
			"surface": "counter",
			"asset_path": str(offer.get("asset_path", "")),
			"icon_key": str(offer.get("icon_key", item_id)),
			"position": Vector2(0.30 + float(index % 4) * 0.12, 0.76),
			"size": Vector2(90, 54),
		})
	var travel_targets := _string_array(snapshot.get("next_archetypes", []))
	if travel_targets.is_empty():
		travel_targets = _string_array(snapshot.get("travel_hooks", []))
	if not travel_targets.is_empty():
		objects.append({
			"id": "travel:leave",
			"type": "travel",
			"label": "Leave",
			"prop": "door",
			"position": Vector2(0.78, 0.64),
			"size": Vector2(118, 64),
		})
	return objects


func _objects_from_interactable_records(records: Array) -> Array:
	var objects: Array = []
	for index in range(records.size()):
		if typeof(records[index]) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = records[index]
		var object_id := str(record.get("object_id", ""))
		if object_id.is_empty():
			continue
		var interaction_type := str(record.get("object_type", "info"))
		var object_type := str(record.get("visual_type", interaction_type))
		var normalized_rect := _normalized_rect_from_record(record)
		var focus_point := normalized_rect.position + normalized_rect.size * 0.5
		var scene_object := {
			"id": object_id,
			"type": object_type,
			"interaction_type": interaction_type,
			"source_id": str(record.get("source_id", "")),
			"label": str(record.get("label", "")),
			"description": str(record.get("short_description", "")),
			"identity_summary": str(record.get("identity_summary", "")),
			"presence": str(record.get("presence", "dynamic")),
			"interactive": bool(record.get("interactive", true)),
			"decorative": bool(record.get("decorative", not bool(record.get("interactive", true)))),
			"position": focus_point,
			"size": Vector2(
				maxf(normalized_rect.size.x * float(BOARD_SIZE.x), 72.0),
				maxf(normalized_rect.size.y * float(BOARD_SIZE.y), 48.0)
			),
			"disabled": not bool(record.get("enabled", true)),
			"disabled_reason": str(record.get("disabled_reason", "")),
			"action_summary": str(record.get("action_summary", "")),
			"status_summary": str(record.get("status_summary", "")),
			"effect_summary": str(record.get("effect_summary", "")),
			"impact_summary": str(record.get("impact_summary", "")),
			"choice_summary": str(record.get("choice_summary", "")),
			"risk_summary": str(record.get("risk_summary", "")),
			"cost_summary": str(record.get("cost_summary", "")),
			"attribute_badges": _copy_array(record.get("attribute_badges", [])),
			"runtime_state": (record.get("runtime_state", {}) as Dictionary).duplicate(true) if typeof(record.get("runtime_state", {})) == TYPE_DICTIONARY else {},
			"visual_state": (record.get("visual_state", {}) as Dictionary).duplicate(true) if typeof(record.get("visual_state", {})) == TYPE_DICTIONARY else {},
			"state_badge": str(record.get("state_badge", "")),
			"visual_key": str(record.get("visual_key", "")),
			"prop": str(record.get("prop", "")),
			"surface": str(record.get("surface", "")),
			"icon_key": str(record.get("icon_key", "")),
			"asset_path": str(record.get("asset_path", "")),
			"available_actions": _copy_array(record.get("available_actions", [])),
			"inline_actions": _copy_array(record.get("inline_actions", [])),
			"confirm_action_id": str(record.get("confirm_action_id", "")),
		}
		objects.append(_apply_draw_hints(scene_object, object_type, index))
	return objects


func _object_layout_footprint(object_data: Dictionary, position: Vector2) -> Rect2:
	var object_rect := _board_rect_for_object_at_position(object_data, position)
	var footprint := object_rect.grow(OBJECT_LAYOUT_GAP)
	return _clamp_board_rect(footprint)


func _scene_object_layout_snapshot(objects: Array) -> Dictionary:
	var entries: Array = []
	var overlaps: Array = []
	for index in range(objects.size()):
		if typeof(objects[index]) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = objects[index]
		var object_rect := _board_rect_for_object(object_data)
		var footprint := _object_layout_footprint(object_data, object_data.get("position", Vector2(0.5, 0.5)))
		var entry := {
			"id": str(object_data.get("id", "")),
			"type": str(object_data.get("type", "")),
			"rect": _rect_to_snapshot(object_rect),
			"footprint": _rect_to_snapshot(footprint),
		}
		entries.append(entry)
	for a in range(entries.size()):
		var a_rect := _snapshot_to_rect((entries[a] as Dictionary).get("footprint", {}))
		for b in range(a + 1, entries.size()):
			var b_rect := _snapshot_to_rect((entries[b] as Dictionary).get("footprint", {}))
			if a_rect.intersects(b_rect):
				var intersection := a_rect.intersection(b_rect)
				var area := maxf(0.0, intersection.size.x) * maxf(0.0, intersection.size.y)
				if area > OBJECT_LAYOUT_MAX_OVERLAP_AREA:
					overlaps.append({
						"a": str((entries[a] as Dictionary).get("id", "")),
						"b": str((entries[b] as Dictionary).get("id", "")),
						"area": area,
					})
	return {
		"objects": entries,
		"overlap_count": overlaps.size(),
		"overlaps": overlaps,
		"gap": OBJECT_LAYOUT_GAP,
		"margin": OBJECT_LAYOUT_MARGIN,
	}


func _apply_draw_hints(object_data: Dictionary, object_type: String, index: int) -> Dictionary:
	match object_type:
		"game":
			if not str(object_data.get("prop", "")).strip_edges().is_empty():
				return object_data
			object_data["prop"] = "card_table"
		"travel":
			object_data["prop"] = "door" if index == 0 else "arrow"
		"event":
			if str(object_data.get("prop", "")).strip_edges().is_empty():
				object_data["prop"] = _fallback_event_prop(str(object_data.get("visual_key", "")), str(object_data.get("icon_key", "")))
		"service":
			if str(object_data.get("surface", "")).strip_edges().is_empty():
				object_data["surface"] = "counter_case"
		"shopkeeper":
			object_data["surface"] = "counter_case"
		"lender":
			object_data["surface"] = "wire_cage"
		"home_tenure":
			object_data["surface"] = "counter"
			if str(object_data.get("prop", "")).strip_edges().is_empty():
				object_data["prop"] = "paper_note"
		"home_storage":
			object_data["surface"] = "floor"
		"home_container":
			object_data["surface"] = "floor"
		"save", "load":
			object_data["surface"] = "counter"
		_:
			if not object_data.has("surface"):
				object_data["surface"] = "counter"
	return object_data


func _normalized_rect_from_record(record: Dictionary) -> Rect2:
	var rect := _rect_from_dict(record.get("normalized_rect", record.get("focus_rect", {})))
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		var focus_point := _vector2_from_dict(record.get("focus_point", {}), Vector2(0.5, 0.5))
		rect = Rect2(focus_point - Vector2(0.08, 0.14) * 0.5, Vector2(0.08, 0.14))
	return Rect2(
		Vector2(clampf(rect.position.x, 0.02, 0.96), clampf(rect.position.y, 0.04, 0.92)),
		Vector2(clampf(rect.size.x, 0.08, 0.22), clampf(rect.size.y, 0.12, 0.28))
	)


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var id := str(entry)
		if not id.is_empty():
			result.append(id)
	return result


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _array_view(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return value as Array


func _copy_dictionary(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _scene_object(object_id: String) -> Dictionary:
	if scene_objects_by_id_cache.has(object_id):
		var cached_value: Variant = scene_objects_by_id_cache.get(object_id, {})
		if typeof(cached_value) == TYPE_DICTIONARY:
			return cached_value as Dictionary
	for object_data in _active_scene_objects():
		if typeof(object_data) == TYPE_DICTIONARY and str((object_data as Dictionary).get("id", "")) == object_id:
			return object_data as Dictionary
	return {}


func _pit_boss_watch_snapshot() -> Dictionary:
	if not uses_foundation_snapshot:
		return {}
	var value: Variant = foundation_snapshot.get("pit_boss_watch", {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _selected_object_info_snapshot() -> Dictionary:
	var info := _selected_object_info()
	if info.is_empty():
		return {"visible": false}
	var object_data: Dictionary = info.get("object", {})
	var action_entries := _selected_info_action_entries_from_info(info)
	var action_button_rect := _selected_info_action_button_rect_from_entries(action_entries)
	var visual_rect := _animated_info_card_rect(info)
	return {
		"visible": true,
		"object_id": str(info.get("object_id", "")),
		"title": str(info.get("title", "")),
		"lines": _copy_array(info.get("lines", [])),
		"rect": _rect_to_snapshot(info.get("rect", Rect2())),
		"visual_rect": _rect_to_snapshot(visual_rect),
		"animating": info_card_animating,
		"object_rect": _rect_to_snapshot(info.get("object_rect", Rect2())),
		"visible_board_rect": _rect_to_snapshot(_visible_board_rect()),
		"max_line_chars": maxi(OBJECT_INFO_MAX_CHARS, OBJECT_INFO_DESCRIPTION_MAX_CHARS),
		"action_available": _selected_info_has_action_button(object_data),
		"action_label": _selected_info_action_label(object_data),
		"action_button_rect": _rect_to_snapshot(action_button_rect),
		"actions": _selected_info_action_snapshot_list(action_entries),
		"attribute_badges": _copy_array(object_data.get("attribute_badges", [])),
	}


func _selected_object_info() -> Dictionary:
	var object_id := selected_object_id
	if object_id.is_empty():
		object_id = hovered_object_id
	if object_id.is_empty():
		return {}
	var object_data := _scene_object(object_id)
	if object_data.is_empty():
		return {}
	var title := str(object_data.get("label", "")).strip_edges()
	var lines := _object_info_lines(object_data)
	if title.is_empty() and lines.is_empty():
		return {}
	var object_rect := _board_rect_for_object(object_data)
	return {
		"object": object_data,
		"object_id": object_id,
		"title": title,
		"lines": lines,
		"rect": _object_info_rect(object_rect, title, lines, str(object_data.get("type", "item")), object_data),
		"object_rect": object_rect,
	}


func _object_info_lines(object_data: Dictionary) -> Array:
	var lines: Array = []
	var object_type := str(object_data.get("type", "info"))
	var max_chars := _object_info_line_chars(object_type)
	var identity := str(object_data.get("identity_summary", "")).strip_edges()
	if not identity.is_empty():
		_append_wrapped_info_lines(lines, identity, max_chars, 1)
	var description := str(object_data.get("description", "")).strip_edges()
	if description.is_empty():
		description = _fallback_object_description(object_data)
	if not description.is_empty():
		_append_wrapped_info_lines(lines, description, max_chars, 2)
	var status := str(object_data.get("status_summary", "")).strip_edges()
	if not status.is_empty():
		_append_wrapped_info_lines(lines, status, max_chars, 1)
	var choice_summary := str(object_data.get("choice_summary", "")).strip_edges()
	if not choice_summary.is_empty():
		_append_wrapped_info_lines(lines, choice_summary, max_chars, 2)
	var cost := str(object_data.get("cost_summary", "")).strip_edges()
	if not cost.is_empty():
		_append_wrapped_info_lines(lines, cost, max_chars, 1)
	var effect := str(object_data.get("effect_summary", "")).strip_edges()
	if not effect.is_empty():
		_append_wrapped_info_lines(lines, "Effect: %s" % effect, max_chars, 2)
	var impact := str(object_data.get("impact_summary", "")).strip_edges()
	if not impact.is_empty():
		_append_wrapped_info_lines(lines, "Impact: %s" % impact, max_chars, 2)
	var risk := str(object_data.get("risk_summary", "")).strip_edges()
	if not risk.is_empty():
		_append_wrapped_info_lines(lines, "Risk: %s" % risk if not risk.begins_with("Risk:") else risk, max_chars, 1)
	var action := str(object_data.get("action_summary", "")).strip_edges()
	if bool(object_data.get("disabled", false)):
		var reason := str(object_data.get("disabled_reason", "")).strip_edges()
		if not reason.is_empty():
			_append_wrapped_info_lines(lines, reason, max_chars, 1)
	elif not action.is_empty():
		_append_wrapped_info_lines(lines, action, max_chars, 1)
	var capped: Array = []
	for index in range(mini(lines.size(), OBJECT_INFO_MAX_LINES)):
		capped.append(lines[index])
	return capped


func _fallback_object_description(object_data: Dictionary) -> String:
	match str(object_data.get("type", "info")):
		"game":
			return "A playable table or machine."
		"event":
			return "Something is happening here."
		"item":
			return "Useful gear or a quick edge."
		"drink":
			return "A drink service."
		"travel":
			return "A route to another place."
		"service":
			return "A service counter."
		"shopkeeper":
			return "A merchant watching the counter."
		"lender":
			return "Fast cash with strings attached."
		"prestige":
			return "A possible way to finish the run."
		_:
			return str(object_data.get("action_summary", "")).strip_edges()


func _player_facing_object_type(object_type: String) -> String:
	match object_type:
		"game":
			return "Game"
		"event":
			return "Event"
		"item":
			return "Item"
		"drink":
			return "Drink"
		"travel":
			return "Travel"
		"service":
			return "Service"
		"shopkeeper":
			return "Shopkeeper"
		"lender":
			return "Lender"
		"prestige":
			return "Goal"
		"home_tenure":
			return "Home"
		"home_storage":
			return "Storage"
		"home_container":
			return "Container"
		_:
			return "Info"


func _fit_info_line(text: String, max_chars: int = OBJECT_INFO_MAX_CHARS) -> String:
	var one_line := _compact_info_text(text)
	while one_line.find("  ") != -1:
		one_line = one_line.replace("  ", " ")
	if one_line.length() <= max_chars:
		return one_line
	return one_line.left(max_chars).strip_edges()


func _append_wrapped_info_lines(lines: Array, text: String, max_chars: int, max_lines: int) -> void:
	var compact := _compact_info_text(text)
	while compact.find("  ") != -1:
		compact = compact.replace("  ", " ")
	if compact.is_empty() or max_lines <= 0:
		return
	var words := compact.split(" ", false)
	var current := ""
	for word in words:
		var word_text := str(word)
		var candidate := word_text if current.is_empty() else "%s %s" % [current, word_text]
		if candidate.length() <= max_chars or current.is_empty():
			current = _fit_info_line(candidate, max_chars)
			continue
		lines.append(current)
		if lines.size() >= OBJECT_INFO_MAX_LINES or max_lines <= 1:
			return
		max_lines -= 1
		current = _fit_info_line(word_text, max_chars)
	if not current.is_empty() and lines.size() < OBJECT_INFO_MAX_LINES:
		lines.append(current)


func _object_info_line_chars(object_type: String) -> int:
	match object_type:
		"item", "drink":
			return OBJECT_INFO_ITEM_MAX_CHARS
	return OBJECT_INFO_MAX_CHARS


func _fit_draw_text(text: String, font: Font, font_size: int, max_width: float) -> String:
	var compact := text.replace("\n", " ").replace("\t", " ").strip_edges()
	while compact.find("  ") != -1:
		compact = compact.replace("  ", " ")
	var cache_key := _fit_draw_text_cache_key(compact, font, font_size, max_width)
	if fit_draw_text_cache.has(cache_key):
		return str(fit_draw_text_cache.get(cache_key, compact))
	var fitted := compact
	if font != null and not compact.is_empty() and _draw_text_width(compact, font, font_size) > max_width:
		fitted = ""
		var available := compact.length()
		while available > 0:
			var candidate := compact.left(available).strip_edges()
			if _draw_text_width(candidate, font, font_size) <= max_width:
				fitted = candidate
				break
			available -= 1
	_store_fit_draw_text(cache_key, fitted)
	return fitted


func _fit_draw_text_cache_key(text: String, font: Font, font_size: int, max_width: float) -> String:
	var font_id := 0
	if font != null:
		font_id = int(font.get_instance_id())
	return "%d|%d|%.1f|%s" % [font_id, font_size, max_width, text]


func _store_fit_draw_text(cache_key: String, value: String) -> void:
	if fit_draw_text_cache.size() > 1024:
		fit_draw_text_cache.clear()
	fit_draw_text_cache[cache_key] = value


func _selected_info_has_action_button(object_data: Dictionary) -> bool:
	if not _selected_info_inline_actions(object_data).is_empty():
		return true
	return _selected_info_has_single_action_button(object_data)


func _selected_info_has_single_action_button(object_data: Dictionary) -> bool:
	if selected_object_id.is_empty() or object_data.is_empty():
		return false
	if str(object_data.get("id", "")) != selected_object_id:
		return false
	if bool(object_data.get("disabled", false)):
		return false
	if not str(object_data.get("confirm_action_id", "")).strip_edges().is_empty():
		return true
	return not _array_view(object_data.get("available_actions", [])).is_empty()


func _selected_info_inline_actions(object_data: Dictionary) -> Array:
	if selected_object_id.is_empty() or object_data.is_empty():
		return []
	if str(object_data.get("id", "")) != selected_object_id:
		return []
	if bool(object_data.get("disabled", false)):
		return []
	var actions := _array_view(object_data.get("inline_actions", []))
	var result: Array = []
	for action in actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var action_data: Dictionary = action
		var label := str(action_data.get("label", "")).strip_edges()
		var emit_object_id := str(action_data.get("emit_object_id", action_data.get("id", ""))).strip_edges()
		if label.is_empty() or emit_object_id.is_empty():
			continue
		result.append(action_data)
		if result.size() >= OBJECT_INFO_INLINE_ACTION_MAX:
			break
	return result


func _selected_info_action_area_height(object_data: Dictionary) -> float:
	var inline_actions := _selected_info_inline_actions(object_data)
	if not inline_actions.is_empty():
		var count := mini(inline_actions.size(), OBJECT_INFO_INLINE_ACTION_MAX)
		return float(count) * (OBJECT_INFO_INLINE_ACTION_HEIGHT + OBJECT_INFO_INLINE_ACTION_DETAIL_HEIGHT) + float(maxi(0, count - 1)) * OBJECT_INFO_INLINE_ACTION_GAP
	if _selected_info_has_single_action_button(object_data):
		return OBJECT_INFO_ACTION_HEIGHT
	return 0.0


func _selected_info_action_label(object_data: Dictionary) -> String:
	if object_data.is_empty():
		return ""
	var inline_actions := _selected_info_inline_actions(object_data)
	if not inline_actions.is_empty() and typeof(inline_actions[0]) == TYPE_DICTIONARY:
		return str((inline_actions[0] as Dictionary).get("label", "")).strip_edges().capitalize()
	var action_id := str(object_data.get("confirm_action_id", "")).strip_edges()
	var actions := _array_view(object_data.get("available_actions", []))
	var label := ""
	if not actions.is_empty() and typeof(actions[0]) == TYPE_DICTIONARY:
		label = str((actions[0] as Dictionary).get("label", "")).strip_edges()
		if action_id.is_empty():
			action_id = str((actions[0] as Dictionary).get("id", "")).strip_edges()
	if label.begins_with("Double-click to "):
		label = label.replace("Double-click to ", "")
	if label == "Double-click this machine to enter":
		label = "Enter"
	match action_id:
		"enter_game":
			label = "Enter"
		"buy_item":
			label = "Buy"
		"talk_shopkeeper":
			label = "Talk"
		"confirm_travel", "select_travel":
			label = "Travel"
		"buy_prestige":
			label = "Claim"
	if label.is_empty():
		match str(object_data.get("type", "info")):
			"game":
				label = "Enter"
			"event":
				label = "Respond"
			"item":
				label = "Buy"
			"travel":
				label = "Travel"
			"shopkeeper":
				label = "Talk"
			"service", "lender", "drink":
				label = "Use"
			"prestige":
				label = "Claim"
			_:
				label = "Select"
	return label.capitalize()


func _selected_info_action_button_rect() -> Rect2:
	var info := _selected_object_info()
	if info.is_empty():
		return Rect2()
	return _selected_info_action_button_rect_from_entries(_selected_info_action_entries_for_rect(info, _animated_info_card_rect(info)))


func _selected_info_action_button_rect_from_info(info: Dictionary) -> Rect2:
	return _selected_info_action_button_rect_from_entries(_selected_info_action_entries_from_info(info))


func _selected_info_action_button_rect_from_entries(entries: Array) -> Rect2:
	if entries.is_empty() or typeof(entries[0]) != TYPE_DICTIONARY:
		return Rect2()
	var entry: Dictionary = entries[0]
	return entry.get("button_rect", Rect2())


func _selected_info_action_entries_from_info(info: Dictionary) -> Array:
	if info.is_empty():
		return []
	var rect_value: Variant = info.get("rect", Rect2())
	var card: Rect2 = rect_value if typeof(rect_value) == TYPE_RECT2 else Rect2()
	return _selected_info_action_entries_for_rect(info, card)


func _selected_info_action_entries_for_rect(info: Dictionary, card: Rect2) -> Array:
	if info.is_empty():
		return []
	var object_data: Dictionary = info.get("object", {})
	if not _selected_info_has_action_button(object_data):
		return []
	if card.size.x <= 0.0 or card.size.y <= 0.0:
		return []
	var width := card.size.x - OBJECT_INFO_PADDING_X * 2.0
	if width <= 0.0:
		return []
	var left := card.position.x + OBJECT_INFO_PADDING_X
	var entries: Array = []
	var inline_actions := _selected_info_inline_actions(object_data)
	if not inline_actions.is_empty():
		var area_height := _selected_info_action_area_height(object_data)
		var y := card.end.y - OBJECT_INFO_BOTTOM_PADDING - area_height
		for action in inline_actions:
			if typeof(action) != TYPE_DICTIONARY:
				continue
			var action_data: Dictionary = action
			var button_rect := Rect2(Vector2(left, y), Vector2(width, OBJECT_INFO_INLINE_ACTION_HEIGHT))
			var detail_rect := Rect2(Vector2(left, button_rect.end.y), Vector2(width, OBJECT_INFO_INLINE_ACTION_DETAIL_HEIGHT))
			entries.append({
				"inline": true,
				"label": str(action_data.get("label", "")),
				"detail": _selected_info_inline_action_detail(action_data),
				"emit_object_id": str(action_data.get("emit_object_id", action_data.get("id", ""))),
				"button_rect": button_rect,
				"detail_rect": detail_rect,
				"selected": bool(action_data.get("selected", false)),
			})
			y += OBJECT_INFO_INLINE_ACTION_HEIGHT + OBJECT_INFO_INLINE_ACTION_DETAIL_HEIGHT + OBJECT_INFO_INLINE_ACTION_GAP
		return entries
	if _selected_info_has_single_action_button(object_data):
		entries.append({
			"inline": false,
			"label": _selected_info_action_label(object_data),
			"detail": "",
			"emit_object_id": "",
			"button_rect": Rect2(
				card.position + Vector2(OBJECT_INFO_PADDING_X, card.size.y - OBJECT_INFO_BOTTOM_PADDING - OBJECT_INFO_ACTION_HEIGHT),
				Vector2(width, OBJECT_INFO_ACTION_HEIGHT)
			),
			"detail_rect": Rect2(),
			"selected": false,
		})
	return entries


func _selected_info_inline_action_detail(action_data: Dictionary) -> String:
	var text := str(action_data.get("text", "")).strip_edges()
	var impact := str(action_data.get("impact_summary", action_data.get("consequence_summary", ""))).strip_edges()
	if text.is_empty() and impact.is_empty():
		return ""
	if text.is_empty():
		return "Effect: %s" % impact
	if impact.is_empty():
		return text
	return "%s Effect: %s" % [text, impact]


func _selected_info_action_snapshot_list(entries: Array) -> Array:
	var snapshots: Array = []
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var action_entry: Dictionary = entry
		snapshots.append({
			"label": str(action_entry.get("label", "")),
			"detail": str(action_entry.get("detail", "")),
			"emit_object_id": str(action_entry.get("emit_object_id", "")),
			"button_rect": _rect_to_snapshot(action_entry.get("button_rect", Rect2())),
			"detail_rect": _rect_to_snapshot(action_entry.get("detail_rect", Rect2())),
			"inline": bool(action_entry.get("inline", false)),
			"selected": bool(action_entry.get("selected", false)),
		})
	return snapshots


func _selected_info_action_entry_at_local_position(local_position: Vector2) -> Dictionary:
	var info := _selected_object_info()
	if info.is_empty():
		return {}
	var visual_info := info.duplicate(false)
	visual_info["rect"] = _animated_info_card_rect(info)
	var board_position := _local_to_board_position(local_position)
	for entry in _selected_info_action_entries_from_info(visual_info):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var action_entry: Dictionary = entry
		var button_rect: Rect2 = action_entry.get("button_rect", Rect2())
		if button_rect.has_point(board_position):
			return action_entry
	return {}


func _selected_info_action_button_at_local_position(local_position: Vector2) -> bool:
	return not _selected_info_action_entry_at_local_position(local_position).is_empty()


func _activate_selected_info_action_at_local_position(local_position: Vector2) -> bool:
	var action_entry := _selected_info_action_entry_at_local_position(local_position)
	if action_entry.is_empty():
		return false
	var info := _selected_object_info()
	var object_id := str(info.get("object_id", selected_object_id))
	if object_id.is_empty():
		return false
	set_selected_object(object_id)
	object_focused.emit(object_id)
	var emit_object_id := str(action_entry.get("emit_object_id", "")).strip_edges()
	object_activated.emit(emit_object_id if not emit_object_id.is_empty() else object_id)
	return true


func _compact_info_text(text: String) -> String:
	var compact := text.replace("\n", " ").replace("\t", " ").strip_edges()
	var phrase_replacements := {
		"clean-play odds": "clean odds",
		"better odds": "odds",
		"risky-play heat": "risky heat",
		"loss cushion": "loss cut",
		"win payout": "win pay",
		"story changes": "story",
	}
	for phrase in phrase_replacements.keys():
		compact = compact.replace(str(phrase), str(phrase_replacements[phrase]))
	var replacements := {
		"Buy this item.": "Useful shop item.",
		"Double-click to sell gear.": "Double-click to sell.",
		"Double-click this machine to enter.": "Double-click to enter.",
		"Double-click to review this response.": "Double-click to review.",
		"Choose where to go next. Double-click to travel.": "Double-click to travel.",
		"Needs more bankroll before it can be used.": "Needs more bankroll.",
		"Merchant sales.": "Sell items.",
	}
	if replacements.has(compact):
		return str(replacements[compact])
	return compact


func _object_info_rect(object_rect: Rect2, title: String, lines: Array, object_type: String, object_data: Dictionary = {}) -> Rect2:
	var visible_rect := _visible_board_rect().grow(-OBJECT_LAYOUT_MARGIN)
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		visible_rect = Rect2(Vector2(OBJECT_LAYOUT_MARGIN, OBJECT_LAYOUT_MARGIN), Vector2(BOARD_SIZE) - Vector2(OBJECT_LAYOUT_MARGIN * 2.0, OBJECT_LAYOUT_MARGIN * 2.0))
	var card_size := _object_info_size(title, lines, object_type, visible_rect, object_data)
	return _object_info_rect_for_visible(object_rect, card_size, visible_rect)


func _object_info_rect_for_visible(object_rect: Rect2, card_size: Vector2, visible_rect: Rect2) -> Rect2:
	var candidates := _object_info_candidate_rects(object_rect, card_size, visible_rect)
	var exclusion_rect := object_rect.grow(OBJECT_INFO_GAP)
	var best_rect := Rect2(visible_rect.position, card_size)
	var best_score := INF
	for index in range(candidates.size()):
		var candidate: Rect2 = candidates[index]
		var overlap_area := _rect_overlap_area(candidate, exclusion_rect)
		var center_delta := candidate.get_center().distance_squared_to(object_rect.get_center()) * 0.001
		var score := overlap_area * 1000000.0 + center_delta + float(index) * 0.01
		if score < best_score:
			best_score = score
			best_rect = candidate
		if overlap_area <= 0.01:
			return candidate
	return best_rect


func _object_info_candidate_rects(object_rect: Rect2, card_size: Vector2, visible_rect: Rect2) -> Array:
	var center_y := object_rect.position.y + object_rect.size.y * 0.5 - card_size.y * 0.5
	var center_x := object_rect.position.x + object_rect.size.x * 0.5 - card_size.x * 0.5
	var right_x := object_rect.end.x + OBJECT_INFO_GAP
	var left_x := object_rect.position.x - OBJECT_INFO_GAP - card_size.x
	var above_y := object_rect.position.y - OBJECT_INFO_GAP - card_size.y
	var below_y := object_rect.end.y + OBJECT_INFO_GAP
	var raw_positions := [
		Vector2(right_x, center_y),
		Vector2(left_x, center_y),
		Vector2(center_x, above_y),
		Vector2(center_x, below_y),
		Vector2(right_x, visible_rect.position.y),
		Vector2(right_x, visible_rect.end.y - card_size.y),
		Vector2(left_x, visible_rect.position.y),
		Vector2(left_x, visible_rect.end.y - card_size.y),
		Vector2(visible_rect.position.x, above_y),
		Vector2(visible_rect.end.x - card_size.x, above_y),
		Vector2(visible_rect.position.x, below_y),
		Vector2(visible_rect.end.x - card_size.x, below_y),
	]
	var candidates: Array = []
	for position in raw_positions:
		_append_unique_info_rect(candidates, _clamp_rect_to_visible(Rect2(position, card_size), visible_rect))
	if candidates.is_empty():
		candidates.append(Rect2(visible_rect.position, card_size))
	return candidates


func _append_unique_info_rect(candidates: Array, rect: Rect2) -> void:
	for existing in candidates:
		if typeof(existing) == TYPE_RECT2 and (existing as Rect2).position.distance_squared_to(rect.position) < 0.01:
			return
	candidates.append(rect)


func _object_info_size(title: String, lines: Array, object_type: String, visible_rect: Rect2, object_data: Dictionary = {}) -> Vector2:
	var max_width := minf(_object_info_width(object_type), visible_rect.size.x)
	var min_width := minf(OBJECT_INFO_MIN_WIDTH, max_width)
	var font := get_theme_default_font()
	var type_text := _player_facing_object_type(object_type)
	var title_text := title.strip_edges()
	if title_text.is_empty():
		title_text = type_text
	var content_width := _object_info_header_width(title_text, type_text, font)
	for line in lines:
		content_width = maxf(content_width, _draw_text_width(str(line), font, 9) + OBJECT_INFO_PADDING_X * 2.0)
	if lines.is_empty():
		content_width = maxf(content_width, min_width)
	var badge_height := _object_info_badge_height(object_data)
	if badge_height > 0.0:
		content_width = maxf(content_width, min_width)
	var width := clampf(ceilf(content_width), min_width, max_width)
	var line_count := maxi(1, lines.size())
	var height := maxf(OBJECT_INFO_MIN_HEIGHT, OBJECT_INFO_BODY_Y + badge_height + float(line_count) * OBJECT_INFO_LINE_HEIGHT + OBJECT_INFO_BOTTOM_PADDING)
	var action_area_height := _selected_info_action_area_height(object_data)
	if action_area_height > 0.0:
		height += OBJECT_INFO_ACTION_GAP + action_area_height
	height = minf(ceilf(height), visible_rect.size.y)
	return Vector2(width, height)


func _object_info_badge_height(object_data: Dictionary) -> float:
	return 22.0 if not _array_view(object_data.get("attribute_badges", [])).is_empty() else 0.0


func _object_info_header_width(title: String, type_text: String, font: Font) -> float:
	return _draw_text_width(title, font, 11) + _object_info_type_width(type_text, font) + OBJECT_INFO_PADDING_X * 2.0 + OBJECT_INFO_TYPE_GAP


func _object_info_type_width(type_text: String, font: Font) -> float:
	return maxf(42.0, _draw_text_width(type_text, font, 8) + 4.0)


func _draw_text_width(text: String, font: Font, font_size: int) -> float:
	if font == null or text.is_empty():
		return float(text.length()) * float(font_size) * 0.58
	var cache_key := "%d|%d|%s" % [int(font.get_instance_id()), font_size, text]
	if draw_text_width_cache.has(cache_key):
		return float(draw_text_width_cache.get(cache_key, 0.0))
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	if draw_text_width_cache.size() > 1024:
		draw_text_width_cache.clear()
	draw_text_width_cache[cache_key] = width
	return width


func _clear_draw_text_caches() -> void:
	draw_text_width_cache = {}
	fit_draw_text_cache = {}


func _clamp_rect_to_visible(rect: Rect2, visible_rect: Rect2) -> Rect2:
	var x := clampf(rect.position.x, visible_rect.position.x, visible_rect.end.x - rect.size.x)
	var y := clampf(rect.position.y, visible_rect.position.y, visible_rect.end.y - rect.size.y)
	return Rect2(Vector2(x, y), rect.size)


func _rect_overlap_area(a: Rect2, b: Rect2) -> float:
	if not a.intersects(b):
		return 0.0
	var intersection := a.intersection(b)
	return maxf(0.0, intersection.size.x) * maxf(0.0, intersection.size.y)


func _object_info_width(object_type: String) -> float:
	match object_type:
		"item", "drink":
			return OBJECT_INFO_ITEM_WIDTH
	return OBJECT_INFO_WIDTH


func _visible_board_rect() -> Rect2:
	var base_scale := _board_base_scale()
	var scale := base_scale * camera_zoom
	if scale <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return Rect2(Vector2.ZERO, Vector2(BOARD_SIZE))
	var offset := _board_base_offset(base_scale) + camera_offset
	var visible := Rect2(-offset / scale, size / scale)
	return visible.intersection(Rect2(Vector2.ZERO, Vector2(BOARD_SIZE)))


func _invalidate_camera_target() -> void:
	camera_target_dirty = true


func _update_camera_target_if_needed() -> void:
	if not camera_target_dirty:
		return
	_update_camera_target()


func _camera_lerp_weight(delta: float, speed: float) -> float:
	var step_delta := clampf(delta, 0.0, CAMERA_MAX_SMOOTH_DELTA)
	return clampf(1.0 - exp(-speed * step_delta), 0.0, 1.0)


func _update_camera_target() -> void:
	camera_target_dirty = false
	camera_target_refresh_count += 1
	var object_data := _scene_object(selected_object_id) if not selected_object_id.is_empty() else {}
	if object_data.is_empty():
		camera_focus_active = false
		camera_focus_point = Vector2(0.5, 0.5)
		target_camera_zoom = 1.0
		target_camera_offset = Vector2.ZERO
		return
	var object_rect := _board_rect_for_object(object_data)
	var board_size := Vector2(BOARD_SIZE)
	camera_focus_point = Vector2(
		clampf((object_rect.position.x + object_rect.size.x * 0.5) / board_size.x, 0.0, 1.0),
		clampf((object_rect.position.y + object_rect.size.y * 0.5) / board_size.y, 0.0, 1.0)
	)
	camera_focus_active = true
	target_camera_zoom = FOCUS_ZOOM
	target_camera_offset = _camera_offset_for_focus(camera_focus_point, target_camera_zoom)
	target_camera_offset = _camera_offset_with_info_clearance(object_data, object_rect, target_camera_zoom, target_camera_offset)


func _camera_offset_for_focus(focus_point: Vector2, zoom: float) -> Vector2:
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	var board_size := Vector2(BOARD_SIZE)
	var base_scale := _board_base_scale()
	var base_offset := _board_base_offset(base_scale)
	var scale := base_scale * zoom
	var scaled_board_size := board_size * scale
	var focus_board := Vector2(focus_point.x * board_size.x, focus_point.y * board_size.y)
	var desired := size * 0.5 - base_offset - focus_board * scale
	return Vector2(
		_camera_axis_offset(size.x, scaled_board_size.x, base_offset.x, desired.x),
		_camera_axis_offset(size.y, scaled_board_size.y, base_offset.y, desired.y)
	)


func _camera_axis_offset(canvas_length: float, scaled_length: float, base_offset_axis: float, desired_axis: float) -> float:
	if scaled_length <= canvas_length:
		return (canvas_length - scaled_length) * 0.5 - base_offset_axis
	var min_offset := canvas_length - scaled_length - base_offset_axis
	var max_offset := -base_offset_axis
	return clampf(desired_axis, minf(min_offset, max_offset), maxf(min_offset, max_offset))


func _camera_offset_with_info_clearance(object_data: Dictionary, object_rect: Rect2, zoom: float, fallback_offset: Vector2) -> Vector2:
	var fallback_visible := _visible_board_rect_for_camera(fallback_offset, zoom)
	var fallback_usable := _usable_info_visible_rect(fallback_visible)
	var object_type := str(object_data.get("type", "item"))
	var title := str(object_data.get("label", "")).strip_edges()
	var lines := _object_info_lines(object_data)
	var card_size := _object_info_size(title, lines, object_type, fallback_usable, object_data)
	var fallback_card := _object_info_rect_for_visible(object_rect, card_size, fallback_usable)
	if _rect_overlap_area(fallback_card, object_rect.grow(OBJECT_INFO_GAP)) <= 0.01:
		return fallback_offset
	var visible_size := _raw_visible_board_size_for_zoom(zoom)
	if visible_size.x <= 0.0 or visible_size.y <= 0.0:
		return fallback_offset
	var board_size := Vector2(BOARD_SIZE)
	var max_visible_x := maxf(0.0, board_size.x - visible_size.x)
	var max_visible_y := maxf(0.0, board_size.y - visible_size.y)
	var fallback_position := fallback_visible.position
	var right_fit_x := object_rect.end.x + OBJECT_INFO_GAP + card_size.x - visible_size.x + OBJECT_LAYOUT_MARGIN
	var left_fit_x := object_rect.position.x - OBJECT_INFO_GAP - card_size.x - OBJECT_LAYOUT_MARGIN
	var above_fit_y := object_rect.position.y - OBJECT_INFO_GAP - card_size.y - OBJECT_LAYOUT_MARGIN
	var below_fit_y := object_rect.end.y + OBJECT_INFO_GAP + card_size.y - visible_size.y + OBJECT_LAYOUT_MARGIN
	var candidate_positions := [
		Vector2(right_fit_x, fallback_position.y),
		Vector2(left_fit_x, fallback_position.y),
		Vector2(fallback_position.x, below_fit_y),
		Vector2(fallback_position.x, above_fit_y),
		Vector2(right_fit_x, below_fit_y),
		Vector2(left_fit_x, below_fit_y),
		Vector2(right_fit_x, above_fit_y),
		Vector2(left_fit_x, above_fit_y),
		fallback_position,
	]
	var best_offset := fallback_offset
	var best_score := INF
	for position in candidate_positions:
		var visible_position := Vector2(
			clampf((position as Vector2).x, 0.0, max_visible_x),
			clampf((position as Vector2).y, 0.0, max_visible_y)
		)
		var visible_rect := Rect2(visible_position, visible_size).intersection(Rect2(Vector2.ZERO, board_size))
		var usable_rect := _usable_info_visible_rect(visible_rect)
		var candidate_card := _object_info_rect_for_visible(object_rect, card_size, usable_rect)
		var overlap_area := _rect_overlap_area(candidate_card, object_rect.grow(OBJECT_INFO_GAP))
		var movement_cost := visible_position.distance_squared_to(fallback_position) * 0.01
		var score := overlap_area * 1000000.0 + movement_cost
		if score < best_score:
			best_score = score
			best_offset = _camera_offset_for_visible_board_position(visible_position, zoom)
		if overlap_area <= 0.01:
			return best_offset
	return best_offset


func _visible_board_rect_for_camera(offset: Vector2, zoom: float) -> Rect2:
	var base_scale := _board_base_scale()
	var scale := base_scale * zoom
	if scale <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return Rect2(Vector2.ZERO, Vector2(BOARD_SIZE))
	var visible := Rect2(-(_board_base_offset(base_scale) + offset) / scale, size / scale)
	return visible.intersection(Rect2(Vector2.ZERO, Vector2(BOARD_SIZE)))


func _raw_visible_board_size_for_zoom(zoom: float) -> Vector2:
	var base_scale := _board_base_scale()
	var scale := base_scale * zoom
	if scale <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return Vector2(BOARD_SIZE)
	return size / scale


func _camera_offset_for_visible_board_position(visible_position: Vector2, zoom: float) -> Vector2:
	var base_scale := _board_base_scale()
	var scale := base_scale * zoom
	if scale <= 0.0:
		return Vector2.ZERO
	var board_size := Vector2(BOARD_SIZE)
	var base_offset := _board_base_offset(base_scale)
	var scaled_board_size := board_size * scale
	var desired := -visible_position * scale - base_offset
	return Vector2(
		_camera_axis_offset(size.x, scaled_board_size.x, base_offset.x, desired.x),
		_camera_axis_offset(size.y, scaled_board_size.y, base_offset.y, desired.y)
	)


func _usable_info_visible_rect(visible_rect: Rect2) -> Rect2:
	var usable := visible_rect.grow(-OBJECT_LAYOUT_MARGIN)
	if usable.size.x <= 0.0 or usable.size.y <= 0.0:
		return Rect2(Vector2(OBJECT_LAYOUT_MARGIN, OBJECT_LAYOUT_MARGIN), Vector2(BOARD_SIZE) - Vector2(OBJECT_LAYOUT_MARGIN * 2.0, OBJECT_LAYOUT_MARGIN * 2.0))
	return usable


func _set_hovered_object(object_id: String) -> void:
	if hovered_object_id == object_id:
		return
	hovered_object_id = object_id
	var hovered_object := _scene_object(object_id)
	var enabled_hover := not hovered_object.is_empty() and not bool(hovered_object.get("disabled", false))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled_hover else Control.CURSOR_ARROW
	object_hovered.emit(object_id)
	queue_redraw()


func _focus_object_at_local_position(local_position: Vector2) -> void:
	var object_id := object_id_at_local_position(local_position)
	if object_id.is_empty():
		_set_hovered_object("")
		set_selected_object("", false)
		object_focused.emit("")
		return
	set_selected_object(object_id)
	object_focused.emit(object_id)


func _activate_object_at_local_position(local_position: Vector2) -> void:
	var object_id := object_id_at_local_position(local_position)
	if object_id.is_empty():
		_set_hovered_object("")
		set_selected_object("", false)
		object_focused.emit("")
		return
	set_selected_object(object_id)
	object_focused.emit(object_id)
	object_activated.emit(object_id)


func _local_to_board_position(local_position: Vector2) -> Vector2:
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	var base_scale := _board_base_scale()
	var scale := base_scale * camera_zoom
	if scale <= 0.0:
		return Vector2.ZERO
	var offset := _board_base_offset(base_scale) + camera_offset
	return (local_position - offset) / scale


func _board_to_local_position(board_position: Vector2) -> Vector2:
	var base_scale := _board_base_scale()
	var scale := base_scale * camera_zoom
	return _board_base_offset(base_scale) + camera_offset + board_position * scale


func _board_rect_to_local_rect(board_rect: Rect2) -> Rect2:
	var base_scale := _board_base_scale()
	var scale := base_scale * camera_zoom
	return Rect2(_board_base_offset(base_scale) + camera_offset + board_rect.position * scale, board_rect.size * scale)


func _update_drunk_distortion_protected_rects() -> void:
	if drunk_distortion_overlay == null or not drunk_distortion_overlay.visible:
		return
	var protected_rects: Array = []
	var selected_info := _selected_object_info()
	if not selected_info.is_empty():
		var card_rect := _animated_info_card_rect(selected_info)
		if card_rect.size.x > 0.0 and card_rect.size.y > 0.0:
			protected_rects.append(_board_rect_to_local_rect(card_rect.grow(4.0)))
	for object_data in _active_scene_objects():
		if typeof(object_data) != TYPE_DICTIONARY:
			continue
		var object_rect := _board_rect_for_object(object_data)
		var label_rect := _label_rect_for_object(object_rect, str((object_data as Dictionary).get("label", "")))
		if label_rect.size.x > 0.0 and label_rect.size.y > 0.0:
			protected_rects.append(_board_rect_to_local_rect(label_rect.grow(3.0)))
	drunk_distortion_overlay.set_ui_protected_rects(protected_rects)


func _board_rect_for_object(object_data: Dictionary) -> Rect2:
	return _board_rect_for_object_at_position(object_data, object_data.get("position", Vector2(0.5, 0.5)))


func _board_rect_for_object_at_position(object_data: Dictionary, pos_norm: Vector2) -> Rect2:
	var board_size := Vector2(BOARD_SIZE)
	var object_size: Vector2 = object_data.get("size", Vector2(128, 68))
	var center := Vector2(pos_norm.x * board_size.x, pos_norm.y * board_size.y)
	return Rect2(center - object_size * 0.5, object_size)


func _label_rect_for_object(rect: Rect2, label: String) -> Rect2:
	var text := label.strip_edges()
	if text.is_empty():
		return Rect2()
	var width := minf(maxf(48.0, float(text.length()) * 5.8 + 12.0), OBJECT_LABEL_MAX_WIDTH)
	var x := rect.position.x + rect.size.x * 0.5 - width * 0.5
	var y := rect.position.y - OBJECT_LABEL_HEIGHT - OBJECT_LABEL_GAP
	if y < OBJECT_LAYOUT_MARGIN:
		y = rect.end.y + OBJECT_LABEL_GAP
	return _clamp_board_rect(Rect2(Vector2(x, y), Vector2(width, OBJECT_LABEL_HEIGHT)))


func _clamp_board_rect(rect: Rect2) -> Rect2:
	var board_size := Vector2(BOARD_SIZE)
	var position := Vector2(
		clampf(rect.position.x, OBJECT_LAYOUT_MARGIN, board_size.x - OBJECT_LAYOUT_MARGIN),
		clampf(rect.position.y, OBJECT_LAYOUT_MARGIN, board_size.y - OBJECT_LAYOUT_MARGIN)
	)
	var end := Vector2(
		clampf(rect.end.x, OBJECT_LAYOUT_MARGIN, board_size.x - OBJECT_LAYOUT_MARGIN),
		clampf(rect.end.y, OBJECT_LAYOUT_MARGIN, board_size.y - OBJECT_LAYOUT_MARGIN)
	)
	return Rect2(position, Vector2(maxf(0.0, end.x - position.x), maxf(0.0, end.y - position.y)))


func _rect_from_dict(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value as Rect2
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = value
	return Rect2(
		Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))),
		Vector2(float(data.get("w", 0.0)), float(data.get("h", 0.0)))
	)


func _rect_to_snapshot(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"w": rect.size.x,
		"h": rect.size.y,
		"aspect_ratio": rect.size.x / rect.size.y if rect.size.y > 0.0 else 0.0,
	}


func _snapshot_to_rect(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value as Rect2
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = value
	return Rect2(
		Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))),
		Vector2(float(data.get("w", 0.0)), float(data.get("h", 0.0)))
	)


func _vector2_from_dict(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value as Vector2
	if typeof(value) != TYPE_DICTIONARY:
		return fallback
	var data: Dictionary = value
	return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))


func _draw_object_shadow(rect: Rect2, selected: bool) -> void:
	var glow := C_YELLOW if selected else C_CYAN
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.15, rect.size.y * 0.78), Vector2(rect.size.x * 0.7, 7)), Color(0.0, 0.0, 0.0, 0.42))
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.22, rect.size.y * 0.84), Vector2(rect.size.x * 0.56, 3)), Color(glow.r, glow.g, glow.b, 0.18))
	if selected:
		draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.08, rect.size.y * 0.72), Vector2(rect.size.x * 0.84, 5)), Color(glow.r, glow.g, glow.b, 0.32))


func _draw_hotspot_hint(rect: Rect2, object_type: String) -> void:
	var color := _color_for_object_type(object_type)
	var pulse: float = 0.22 + absf(sin(flicker * 2.8 + rect.position.x * 0.03)) * 0.16
	var base_y := rect.position.y + rect.size.y * 0.76
	for point in [
		rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.24),
		rect.position + Vector2(rect.size.x * 0.82, rect.size.y * 0.30),
		rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.88),
	]:
		draw_circle(point, 3.0, Color(color.r, color.g, color.b, pulse * 0.72))
		draw_circle(point, 7.0, Color(color.r, color.g, color.b, pulse * 0.12))
	draw_line(Vector2(rect.position.x + rect.size.x * 0.28, base_y), Vector2(rect.position.x + rect.size.x * 0.72, base_y), Color(color.r, color.g, color.b, pulse * 0.70), 2)


func _color_for_object_type(object_type: String) -> Color:
	match object_type:
		"event":
			return C_PINK
		"travel":
			return C_ORANGE
		"item", "drink", "service", "shopkeeper", "lender":
			return C_YELLOW
		"home_tenure":
			return C_AMBER
		"home_storage", "home_container":
			return C_TEAL
		"save", "load":
			return C_PURPLE_2
		_:
			return C_CYAN


func _draw_hover_scene_mark(rect: Rect2) -> void:
	var pulse := 0.48 + absf(sin(flicker * 5.0)) * 0.22
	_draw_prop_underlight(rect, C_CYAN, pulse * 0.95)
	_draw_prop_glints(rect, C_CYAN, pulse)


func _draw_selected_scene_mark(rect: Rect2) -> void:
	var pulse := 0.62 + absf(sin(flicker * 4.4)) * 0.24
	_draw_prop_underlight(rect, C_YELLOW, pulse)
	_draw_prop_glints(rect, C_YELLOW, pulse)


func _draw_selected_item_frame(rect: Rect2, object_type: String) -> void:
	var color := _color_for_object_type(object_type)
	var frame := _clamp_board_rect(rect.grow(5.0))
	draw_rect(frame, Color(color.r, color.g, color.b, 0.08))
	draw_rect(frame, Color(color.r, color.g, color.b, 0.34), false, 1)


func _draw_disabled_scene_mark(rect: Rect2) -> void:
	_draw_prop_underlight(rect, C_ORANGE, 0.28)
	draw_line(rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.72), rect.position + Vector2(rect.size.x * 0.82, rect.size.y * 0.30), Color(0.0, 0.0, 0.0, 0.68), 4)
	draw_line(rect.position + Vector2(rect.size.x * 0.82, rect.size.y * 0.30), rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.72), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.45), 2)


func _draw_disabled_focus_mark(rect: Rect2, selected: bool) -> void:
	var color := C_ORANGE if selected else C_SOFT
	var pulse := 0.36 + absf(sin(flicker * 4.0)) * 0.16
	_draw_prop_underlight(rect, color, pulse * 0.75)
	_draw_prop_glints(rect, color, pulse * 0.55)


func _draw_object_label(rect: Rect2, label: String, object_type: String, disabled: bool, active: bool) -> void:
	var text := label.strip_edges()
	if text.is_empty():
		return
	var label_rect := _label_rect_for_object(rect, text)
	if label_rect.size.x <= 0.0 or label_rect.size.y <= 0.0:
		return
	var color := _color_for_object_type(object_type)
	var alpha := 0.86 if active else 0.68
	if disabled:
		color = C_SOFT
		alpha = 0.46
	var font := get_theme_default_font()
	var fitted := _fit_draw_text(text, font, 8, label_rect.size.x - 6.0)
	var text_pos := label_rect.position + Vector2(3.0, 10.0)
	draw_string(font, text_pos + Vector2(1.0, 1.0), fitted, HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x - 6.0, 8, Color(0.0, 0.0, 0.0, 0.78))
	draw_string(font, text_pos, fitted, HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x - 6.0, 8, Color(color.r, color.g, color.b, alpha))
	draw_line(
		Vector2(label_rect.position.x + 8.0, label_rect.end.y - 1.0),
		Vector2(label_rect.end.x - 8.0, label_rect.end.y - 1.0),
		Color(color.r, color.g, color.b, alpha * 0.32),
		1
	)


func _centered_icon_rect(rect: Rect2, size: float, offset: Vector2 = Vector2.ZERO) -> Rect2:
	var icon_size := Vector2(size, size)
	return Rect2(rect.position + rect.size * 0.5 - icon_size * 0.5 + offset, icon_size)


func _draw_prop_underlight(rect: Rect2, color: Color, alpha: float) -> void:
	var base := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.86)
	draw_circle(base, rect.size.x * 0.34, Color(color.r, color.g, color.b, alpha * 0.12))
	draw_rect(Rect2(base + Vector2(-rect.size.x * 0.28, -2), Vector2(rect.size.x * 0.56, 4)), Color(color.r, color.g, color.b, alpha * 0.34))


func _draw_prop_glints(rect: Rect2, color: Color, alpha: float) -> void:
	var points := [
		rect.position + Vector2(rect.size.x * 0.28, rect.size.y * 0.20),
		rect.position + Vector2(rect.size.x * 0.74, rect.size.y * 0.34),
		rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.70),
	]
	for point in points:
		draw_circle(point, 2.0, Color(color.r, color.g, color.b, alpha * 0.78))
		draw_circle(point, 5.0, Color(color.r, color.g, color.b, alpha * 0.12))


func _draw_live_texture_icon(texture: Texture2D, icon_rect: Rect2, object_data: Dictionary, accent: Color, selected: bool, disabled: bool = false) -> void:
	var phase := _object_animation_phase(object_data)
	var bob := sin(flicker * (2.0 + fposmod(phase, 0.7)) + phase) * (1.35 if selected else 0.75)
	var live_rect := Rect2(icon_rect.position + Vector2(0.0, bob), icon_rect.size)
	var opacity := 0.46 if disabled else 1.0
	_draw_live_icon_backdrop(live_rect, accent, phase, selected, disabled)
	if _icon_glitch_active(phase) and not disabled:
		var glitch_rect := Rect2(live_rect.position + Vector2(2.0, 0.0), live_rect.size)
		draw_texture_rect(texture, glitch_rect, false, Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.28))
		glitch_rect.position += Vector2(-4.0, 1.0)
		draw_texture_rect(texture, glitch_rect, false, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.22))
	draw_texture_rect(texture, live_rect, false, Color(1.0, 1.0, 1.0, opacity))
	_draw_live_icon_overlay(live_rect, accent, phase, selected, disabled)


func _draw_live_sprite_icon(icon_sprite: Dictionary, icon_rect: Rect2, object_data: Dictionary, accent: Color, selected: bool, disabled: bool = false) -> void:
	var phase := _object_animation_phase(object_data)
	var bob := sin(flicker * (2.0 + fposmod(phase, 0.7)) + phase) * (1.1 if selected else 0.55)
	var live_rect := Rect2(icon_rect.position + Vector2(0.0, bob), icon_rect.size)
	_draw_live_icon_backdrop(live_rect, accent, phase, selected, disabled)
	var sprite_texture := _texture_for_icon_sprite(icon_sprite, object_data, accent, maxi(1, roundi(maxf(live_rect.size.x, live_rect.size.y))))
	if _icon_glitch_active(phase) and not disabled:
		var pink_texture := _texture_for_icon_sprite(icon_sprite, object_data, C_PINK, maxi(1, roundi(maxf(live_rect.size.x, live_rect.size.y))))
		var cyan_texture := _texture_for_icon_sprite(icon_sprite, object_data, C_CYAN, maxi(1, roundi(maxf(live_rect.size.x, live_rect.size.y))))
		if pink_texture != null:
			draw_texture_rect(pink_texture, Rect2(live_rect.position + Vector2(2.0, 0.0), live_rect.size), false, Color(1.0, 1.0, 1.0, 0.72))
		if cyan_texture != null:
			draw_texture_rect(cyan_texture, Rect2(live_rect.position + Vector2(-2.0, 1.0), live_rect.size), false, Color(1.0, 1.0, 1.0, 0.66))
	if sprite_texture != null:
		draw_texture_rect(sprite_texture, live_rect, false, Color(1.0, 1.0, 1.0, 0.42 if disabled else 1.0))
	else:
		IconSpriteRendererScript.draw_canvas(self, icon_sprite, live_rect, accent)
	_draw_live_icon_overlay(live_rect, accent, phase, selected, disabled)


func _texture_for_icon_sprite(icon_sprite: Dictionary, object_data: Dictionary, accent: Color, texture_size: int) -> Texture2D:
	if icon_sprite.is_empty():
		return null
	var object_id := str(object_data.get("id", object_data.get("source_id", object_data.get("icon_key", "")))).strip_edges()
	if object_id.is_empty():
		object_id = "sprite"
	var cache_key := "%s|%s|%d" % [object_id, accent.to_html(true), texture_size]
	if icon_sprite_texture_cache.has(cache_key):
		return icon_sprite_texture_cache[cache_key] as Texture2D
	var texture := IconSpriteRendererScript.texture(icon_sprite, texture_size, accent, false)
	if icon_sprite_texture_cache.size() > 256:
		icon_sprite_texture_cache.clear()
	icon_sprite_texture_cache[cache_key] = texture
	return texture


func _draw_live_icon_backdrop(icon_rect: Rect2, accent: Color, phase: float, selected: bool, disabled: bool) -> void:
	var pulse := 0.08 + absf(sin(flicker * 3.6 + phase)) * (0.14 if selected else 0.08)
	if disabled:
		pulse *= 0.32
	draw_rect(icon_rect.grow(4.0), Color(accent.r, accent.g, accent.b, pulse * 0.24))
	draw_rect(Rect2(icon_rect.position + Vector2(3.0, icon_rect.size.y - 5.0), Vector2(icon_rect.size.x - 6.0, 2.0)), Color(accent.r, accent.g, accent.b, pulse * 1.55))
	if selected:
		draw_rect(icon_rect.grow(2.0), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.18 + pulse * 0.32), false, 1)


func _draw_live_icon_overlay(icon_rect: Rect2, accent: Color, phase: float, selected: bool, disabled: bool) -> void:
	var alpha_scale := 0.36 if disabled else 1.0
	var scan_y := icon_rect.position.y + fposmod(flicker * (18.0 + fposmod(phase * 7.0, 10.0)) + phase * 19.0, maxf(1.0, icon_rect.size.y))
	draw_rect(Rect2(icon_rect.position.x + 5.0, scan_y, icon_rect.size.x - 10.0, 2.0), Color(accent.r, accent.g, accent.b, 0.16 * alpha_scale))
	for i in range(3):
		var line_y := icon_rect.position.y + 7.0 + float(i) * icon_rect.size.y * 0.24
		draw_rect(Rect2(icon_rect.position.x + 5.0, line_y, icon_rect.size.x - 10.0, 1.0), Color(0.0, 0.0, 0.0, 0.18 * alpha_scale))
	var glitch_phase := fposmod(flicker * 6.5 + phase, 5.0)
	if glitch_phase < 0.18 and not disabled:
		var band_y := icon_rect.position.y + 6.0 + fposmod(phase * 31.0 + flicker * 42.0, maxf(1.0, icon_rect.size.y - 12.0))
		draw_rect(Rect2(icon_rect.position.x + 4.0, band_y, icon_rect.size.x - 8.0, 2.0), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.34))
		draw_rect(Rect2(icon_rect.position.x + 6.0, band_y + 2.0, icon_rect.size.x - 14.0, 1.0), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.30))
	var corner_alpha := (0.30 + absf(sin(flicker * 4.8 + phase)) * 0.36) * alpha_scale
	draw_rect(Rect2(icon_rect.position + Vector2(4.0, 4.0), Vector2(7.0, 2.0)), Color(accent.r, accent.g, accent.b, corner_alpha))
	draw_rect(Rect2(icon_rect.position + Vector2(4.0, 4.0), Vector2(2.0, 7.0)), Color(accent.r, accent.g, accent.b, corner_alpha))
	draw_rect(Rect2(icon_rect.end - Vector2(11.0, 6.0), Vector2(7.0, 2.0)), Color(C_PINK.r, C_PINK.g, C_PINK.b, corner_alpha * (1.0 if selected else 0.72)))
	draw_rect(Rect2(icon_rect.end - Vector2(6.0, 11.0), Vector2(2.0, 7.0)), Color(C_PINK.r, C_PINK.g, C_PINK.b, corner_alpha * (1.0 if selected else 0.72)))


func _icon_glitch_active(phase: float) -> bool:
	return fposmod(flicker * 3.8 + phase, 6.0) < 0.16


func _object_animation_phase(object_data: Dictionary) -> float:
	var key := str(object_data.get("id", object_data.get("source_id", object_data.get("icon_key", ""))))
	if key.is_empty():
		key = str(object_data)
	if object_animation_phase_cache.has(key):
		return float(object_animation_phase_cache.get(key, 0.0))
	var hash_value := 17
	for i in range(key.length()):
		hash_value = int(fposmod(float(hash_value * 31 + key.unicode_at(i)), 9973.0))
	var phase := float(hash_value) * 0.013
	if object_animation_phase_cache.size() > 512:
		object_animation_phase_cache.clear()
	object_animation_phase_cache[key] = phase
	return phase


func _draw_item_prop(rect: Rect2, object_data: Dictionary, selected: bool, surface: String) -> void:
	var prop := str(object_data.get("prop", "")).strip_edges()
	if prop == "sand_pile":
		_draw_sand_pile_prop(rect, selected)
		return
	var accent := C_YELLOW if selected else C_TEAL
	_draw_interactable_light(rect, accent, selected)
	_draw_item_surface(rect, surface, accent)
	var icon_rect := _centered_icon_rect(rect, 52.0, Vector2(0, -5))
	var icon_texture := _texture_for_asset_path(str(object_data.get("asset_path", "")))
	if icon_texture != null:
		var disabled := bool(object_data.get("disabled", false))
		_draw_live_texture_icon(icon_texture, icon_rect, object_data, accent, selected, disabled)
	else:
		_draw_live_sprite_icon(object_data.get("icon_sprite", {}), icon_rect, object_data, accent, selected, bool(object_data.get("disabled", false)))


func _draw_sand_pile_prop(rect: Rect2, selected: bool) -> void:
	var accent := C_YELLOW if selected else C_TEAL
	_draw_interactable_light(rect, accent, selected)
	var base := rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.68)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.76), Vector2(rect.size.x * 0.64, 6)), Color(0.0, 0.0, 0.0, 0.34))
	for i in range(5):
		var width := rect.size.x * (0.62 - float(i) * 0.08)
		var height := rect.size.y * (0.14 - float(i) * 0.012)
		var y := base.y - float(i) * rect.size.y * 0.07
		var color := Color("#c7833c") if i % 2 == 0 else Color("#d89b52")
		draw_rect(Rect2(Vector2(base.x - width * 0.5, y), Vector2(width, height)), color)
	draw_circle(base + Vector2(-rect.size.x * 0.12, -rect.size.y * 0.16), rect.size.x * 0.06, Color("#e2ac61"))
	draw_circle(base + Vector2(rect.size.x * 0.10, -rect.size.y * 0.11), rect.size.x * 0.045, Color("#f0bf70"))
	draw_rect(Rect2(base + Vector2(rect.size.x * 0.10, -rect.size.y * 0.30), Vector2(rect.size.x * 0.18, rect.size.y * 0.05)), Color(C_ORANGE.r, C_ORANGE.g, C_ORANGE.b, 0.78))
	draw_rect(Rect2(base + Vector2(rect.size.x * 0.15, -rect.size.y * 0.27), Vector2(rect.size.x * 0.05, rect.size.y * 0.09)), Color(C_WHITE.r, C_WHITE.g, C_WHITE.b, 0.80))
	if selected:
		draw_line(base + Vector2(-rect.size.x * 0.34, -rect.size.y * 0.02), base + Vector2(rect.size.x * 0.34, -rect.size.y * 0.09), accent, 2)


func _texture_for_asset_path(asset_path: String) -> Texture2D:
	var path := asset_path.strip_edges()
	if path.is_empty():
		return null
	if item_icon_texture_cache.has(path):
		return item_icon_texture_cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		return _load_uncached_image_texture(path)
	var resource := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
	var texture := resource as Texture2D
	_remember_item_icon_texture(path, texture)
	return texture


func _load_uncached_image_texture(path: String) -> Texture2D:
	var image := Image.new()
	if image.load(path) != OK:
		_remember_item_icon_texture(path, null)
		return null
	var image_texture := ImageTexture.create_from_image(image)
	_remember_item_icon_texture(path, image_texture)
	return image_texture


func _remember_item_icon_texture(path: String, texture: Texture2D) -> void:
	if item_icon_texture_cache.size() >= ITEM_ICON_TEXTURE_CACHE_LIMIT and not item_icon_texture_cache.has(path):
		item_icon_texture_cache.clear()
	item_icon_texture_cache[path] = texture


func _draw_game_object_icon(object_data: Dictionary, icon_rect: Rect2, accent: Color, selected: bool, disabled: bool = false) -> void:
	var icon_texture := _texture_for_asset_path(str(object_data.get("asset_path", "")))
	if icon_texture != null:
		_draw_live_texture_icon(icon_texture, icon_rect, object_data, accent, selected, disabled)
	else:
		_draw_live_sprite_icon(object_data.get("icon_sprite", {}), icon_rect, object_data, accent, selected, disabled)


func _draw_item_surface(rect: Rect2, surface: String, accent: Color) -> void:
	var base_y := rect.position.y + rect.size.y * 0.72
	match surface:
		"fridge_shelf", "vending_slot":
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.10), Vector2(rect.size.x * 0.64, rect.size.y * 0.76)), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.10))
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.20, rect.size.y * 0.66), Vector2(rect.size.x * 0.60, 5)), C_SOFT.darkened(0.15))
			draw_line(rect.position + Vector2(rect.size.x * 0.24, rect.size.y * 0.16), rect.position + Vector2(rect.size.x * 0.24, rect.size.y * 0.80), Color(C_WHITE.r, C_WHITE.g, C_WHITE.b, 0.18), 1)
		"counter_case", "wire_cage", "door_case":
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.10, rect.size.y * 0.42), Vector2(rect.size.x * 0.80, rect.size.y * 0.34)), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.13))
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.72), Vector2(rect.size.x * 0.76, 7)), C_SHADOW)
			draw_line(rect.position + Vector2(rect.size.x * 0.14, rect.size.y * 0.48), rect.position + Vector2(rect.size.x * 0.84, rect.size.y * 0.48), Color(C_WHITE.r, C_WHITE.g, C_WHITE.b, 0.30), 1)
		"folding_table", "card_table", "felt_table", "boss_table", "pool_table":
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.08, rect.size.y * 0.56), Vector2(rect.size.x * 0.84, rect.size.y * 0.18)), Color("#14533f"))
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.16, rect.size.y * 0.62), Vector2(rect.size.x * 0.68, 4)), Color("#1b8b63"))
			draw_line(rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.76), rect.position + Vector2(rect.size.x * 0.10, rect.size.y * 0.94), C_SHADOW, 3)
			draw_line(rect.position + Vector2(rect.size.x * 0.82, rect.size.y * 0.76), rect.position + Vector2(rect.size.x * 0.90, rect.size.y * 0.94), C_SHADOW, 3)
		"bar_top", "lotto_counter":
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.04, rect.size.y * 0.60), Vector2(rect.size.x * 0.92, rect.size.y * 0.18)), Color("#422018"))
			draw_line(Vector2(rect.position.x + rect.size.x * 0.08, base_y), Vector2(rect.position.x + rect.size.x * 0.92, base_y), accent.darkened(0.18), 3)
		"bottle_shelf", "store_shelf":
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.10, rect.size.y * 0.72), Vector2(rect.size.x * 0.80, 5)), C_SHADOW)
			draw_line(Vector2(rect.position.x + rect.size.x * 0.12, base_y), Vector2(rect.position.x + rect.size.x * 0.88, base_y), accent.darkened(0.10), 3)
			for i in range(3):
				var x := rect.position.x + rect.size.x * (0.26 + float(i) * 0.20)
				draw_rect(Rect2(x, rect.position.y + rect.size.y * 0.30, 8, rect.size.y * 0.30), _cycle_color(int(x)).darkened(0.12))
				draw_rect(Rect2(x + 2, rect.position.y + rect.size.y * 0.22, 4, 6), C_AMBER)
		"box_stack", "trash_crate", "floor_stub":
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.56), Vector2(rect.size.x * 0.64, rect.size.y * 0.26)), Color("#57351a"))
			draw_line(rect.position + Vector2(rect.size.x * 0.22, rect.size.y * 0.62), rect.position + Vector2(rect.size.x * 0.78, rect.size.y * 0.62), C_AMBER.darkened(0.18), 2)
		"bar_cart":
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.58), Vector2(rect.size.x * 0.76, 8)), C_AMBER.darkened(0.15))
			draw_line(rect.position + Vector2(rect.size.x * 0.22, rect.size.y * 0.68), rect.position + Vector2(rect.size.x * 0.22, rect.size.y * 0.92), C_SHADOW, 3)
			draw_line(rect.position + Vector2(rect.size.x * 0.78, rect.size.y * 0.68), rect.position + Vector2(rect.size.x * 0.78, rect.size.y * 0.92), C_SHADOW, 3)
			draw_circle(rect.position + Vector2(rect.size.x * 0.22, rect.size.y * 0.94), 4, C_CYAN_2)
			draw_circle(rect.position + Vector2(rect.size.x * 0.78, rect.size.y * 0.94), 4, C_CYAN_2)
		_:
			draw_line(Vector2(rect.position.x + rect.size.x * 0.18, base_y), Vector2(rect.position.x + rect.size.x * 0.82, base_y), accent.darkened(0.28), 3)
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.22, rect.size.y * 0.68), Vector2(rect.size.x * 0.56, 6)), Color(0.0, 0.0, 0.0, 0.32))


func _draw_game_prop(rect: Rect2, object_data: Dictionary, selected: bool) -> void:
	var disabled := bool(object_data.get("disabled", false))
	var accent := C_PINK if selected else C_CYAN
	if disabled:
		accent = C_SOFT
	_draw_interactable_light(rect, accent, selected)
	var prop := str(object_data.get("prop", "card_table"))
	if prop == "machine":
		var game_key := str(object_data.get("source_id", object_data.get("icon_key", "")))
		if game_key == "pull_tabs":
			_draw_pull_tab_machine_prop(rect, object_data, accent, selected, disabled)
		else:
			_draw_slot_cabinet_prop(rect, object_data, accent, selected, disabled)
	elif prop == "video_poker_machine":
		_draw_video_poker_machine_prop(rect, object_data, accent, selected, disabled)
	elif prop == "baccarat_table":
		_draw_baccarat_table_prop(rect, object_data, accent, selected, disabled)
	else:
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y * 0.36), Vector2(rect.size.x, rect.size.y * 0.42)), Color("#12503a"))
		draw_rect(Rect2(rect.position + Vector2(10, rect.size.y * 0.44), Vector2(rect.size.x - 20, rect.size.y * 0.20)), Color("#1c8a62"))
		if prop == "dice_table":
			_draw_game_object_icon(object_data, _centered_icon_rect(rect, 42.0, Vector2(0, -15)), accent, selected, disabled)
		else:
			for i in range(3):
				_card_back(Rect2(rect.position + Vector2(26 + i * 28, 6 + i % 2 * 6), Vector2(20, 28)))
			_draw_game_object_icon(object_data, _centered_icon_rect(rect, 32.0, Vector2(34, -9)), accent, selected, disabled)
	_draw_game_runtime_badge(rect, object_data, accent)


func _draw_game_runtime_badge(rect: Rect2, object_data: Dictionary, accent: Color) -> void:
	var runtime: Dictionary = object_data.get("runtime_state", {})
	if runtime.is_empty() or not bool(runtime.get("active", false)):
		return
	var label := str(runtime.get("status_label", "")).strip_edges()
	if label.is_empty():
		label = "ACTIVE"
	label = label.left(18)
	var font := get_theme_default_font()
	var width := clampf(_draw_text_width(label, font, 8) + 10.0, 42.0, rect.size.x + 14.0)
	var badge := Rect2(rect.position + Vector2(rect.size.x * 0.5 - width * 0.5, rect.size.y - 14.0), Vector2(width, 14.0))
	var pulse := 0.54 + absf(sin(flicker * 5.8)) * 0.22
	draw_rect(badge, Color(0.0, 0.0, 0.0, 0.78))
	draw_rect(badge, Color(accent.r, accent.g, accent.b, 0.20 + pulse * 0.12))
	draw_rect(badge, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, pulse), false, 1)
	draw_string(font, badge.position + Vector2(5.0, 10.0), _fit_draw_text(label, font, 8, badge.size.x - 10.0), HORIZONTAL_ALIGNMENT_CENTER, badge.size.x - 10.0, 8, C_YELLOW)


func _draw_travel_prop(rect: Rect2, object_data: Dictionary, selected: bool) -> void:
	var accent := C_YELLOW if selected else C_ORANGE
	_draw_interactable_light(rect, accent, selected)
	var prop := str(object_data.get("prop", "arrow"))
	match prop:
		"door":
			_draw_travel_door(rect, accent)
		"bus_stop":
			_draw_travel_bus_stop(rect, accent)
		"payphone":
			_draw_travel_payphone(rect, accent)
		"ride":
			_draw_travel_ride(rect, accent)
		_:
			_draw_travel_arrow(rect, accent)
	var travel_icon := _centered_icon_rect(rect, 30.0, Vector2(rect.size.x * 0.22, -rect.size.y * 0.20))
	var travel_icon_texture := _texture_for_icon_sprite(object_data.get("icon_sprite", {}), object_data, accent, 30)
	if travel_icon_texture != null:
		draw_texture_rect(travel_icon_texture, travel_icon, false)
	else:
		IconSpriteRendererScript.draw_canvas(self, object_data.get("icon_sprite", {}), travel_icon, accent)


func _draw_travel_door(rect: Rect2, accent: Color) -> void:
	var door := Rect2(rect.position + Vector2(rect.size.x * 0.34, rect.size.y * 0.10), Vector2(rect.size.x * 0.34, rect.size.y * 0.72))
	draw_rect(door, C_SHADOW)
	draw_rect(Rect2(door.position + Vector2(4, 4), door.size - Vector2(8, 4)), Color("#171735"))
	draw_rect(Rect2(door.position + Vector2(door.size.x - 9, door.size.y * 0.48), Vector2(4, 4)), C_YELLOW)
	draw_line(door.position + Vector2(door.size.x, 8), door.position + Vector2(door.size.x + rect.size.x * 0.18, 0), accent, 2)
	draw_line(door.position + Vector2(door.size.x, door.size.y - 8), door.position + Vector2(door.size.x + rect.size.x * 0.18, door.size.y), accent.darkened(0.1), 2)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.20, rect.size.y * 0.82), Vector2(rect.size.x * 0.60, 5)), Color(accent.r, accent.g, accent.b, 0.35))


func _draw_travel_bus_stop(rect: Rect2, accent: Color) -> void:
	var pole_x := rect.position.x + rect.size.x * 0.30
	draw_line(Vector2(pole_x, rect.position.y + rect.size.y * 0.18), Vector2(pole_x, rect.position.y + rect.size.y * 0.86), C_SHADOW, 4)
	draw_rect(Rect2(pole_x - 14, rect.position.y + rect.size.y * 0.16, 28, 18), accent)
	_neon_text("BUS", Vector2(pole_x - 13, rect.position.y + rect.size.y * 0.31), 9, C_DARK)
	var bus := Rect2(rect.position + Vector2(rect.size.x * 0.42, rect.size.y * 0.42), Vector2(rect.size.x * 0.44, rect.size.y * 0.25))
	draw_rect(bus, Color("#14233f"))
	draw_rect(Rect2(bus.position + Vector2(5, 4), Vector2(bus.size.x - 10, 8)), C_CYAN)
	draw_circle(bus.position + Vector2(10, bus.size.y + 2), 4, C_PINK)
	draw_circle(bus.position + Vector2(bus.size.x - 10, bus.size.y + 2), 4, C_PINK)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.86), Vector2(rect.size.x * 0.68, 4)), Color(accent.r, accent.g, accent.b, 0.26))


func _draw_travel_payphone(rect: Rect2, accent: Color) -> void:
	var booth := Rect2(rect.position + Vector2(rect.size.x * 0.34, rect.size.y * 0.12), Vector2(rect.size.x * 0.34, rect.size.y * 0.70))
	draw_rect(booth, Color("#101028"))
	draw_rect(Rect2(booth.position + Vector2(4, 4), Vector2(booth.size.x - 8, booth.size.y * 0.30)), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.42))
	draw_rect(Rect2(booth.position + Vector2(booth.size.x * 0.28, booth.size.y * 0.42), Vector2(booth.size.x * 0.44, booth.size.y * 0.22)), C_SHADOW)
	for i in range(3):
		for j in range(2):
			draw_rect(Rect2(booth.position + Vector2(booth.size.x * 0.30 + i * 6, booth.size.y * 0.70 + j * 6), Vector2(3, 3)), accent)
	draw_line(booth.position + Vector2(booth.size.x * 0.74, booth.size.y * 0.44), booth.position + Vector2(booth.size.x + 10, booth.size.y * 0.28), C_YELLOW, 2)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.22, rect.size.y * 0.84), Vector2(rect.size.x * 0.56, 4)), Color(accent.r, accent.g, accent.b, 0.26))


func _draw_travel_ride(rect: Rect2, accent: Color) -> void:
	var car := Rect2(rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.50), Vector2(rect.size.x * 0.64, rect.size.y * 0.22))
	draw_rect(car, Color("#241024"))
	draw_rect(Rect2(car.position + Vector2(car.size.x * 0.22, -car.size.y * 0.42), Vector2(car.size.x * 0.36, car.size.y * 0.44)), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.30))
	draw_circle(car.position + Vector2(car.size.x * 0.20, car.size.y + 2), 5, C_YELLOW)
	draw_circle(car.position + Vector2(car.size.x * 0.78, car.size.y + 2), 5, C_YELLOW)
	_silhouette(rect.position + Vector2(rect.size.x * 0.72, rect.size.y * 0.56), 0.32, C_SHADOW)
	draw_line(rect.position + Vector2(rect.size.x * 0.70, rect.size.y * 0.38), rect.position + Vector2(rect.size.x * 0.86, rect.size.y * 0.24), accent, 3)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.84), Vector2(rect.size.x * 0.64, 4)), Color(accent.r, accent.g, accent.b, 0.26))


func _draw_travel_arrow(rect: Rect2, accent: Color) -> void:
	var base := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.72)
	draw_line(base + Vector2(-32, 18), base + Vector2(-32, -18), C_SHADOW, 4)
	draw_line(base + Vector2(32, 18), base + Vector2(32, -18), C_SHADOW, 4)
	draw_line(base + Vector2(-40, -20), base + Vector2(40, -20), accent, 5)
	draw_line(base + Vector2(40, -20), base + Vector2(26, -34), accent, 5)
	draw_line(base + Vector2(40, -20), base + Vector2(26, -6), accent, 5)
	draw_line(base + Vector2(-26, 2), base + Vector2(20, -10), C_CYAN, 3)


func _fallback_event_prop(visual_key: String, icon_key: String) -> String:
	var key := ("%s %s" % [visual_key, icon_key]).to_lower()
	if key.find("phone") != -1:
		return "payphone"
	if key.find("camera") != -1 or key.find("sky") != -1:
		return "security_camera"
	if key.find("security") != -1 or key.find("heat") != -1:
		return "security_exit"
	if key.find("progression") != -1 or key.find("door") != -1:
		return "side_door"
	if key.find("note") != -1 or key.find("tip") != -1:
		return "paper_note"
	if key.find("offer") != -1:
		return "trunk_offer"
	return "patron_talk"


func _draw_event_prop(rect: Rect2, object_data: Dictionary, selected: bool) -> void:
	var prop := str(object_data.get("prop", "")).strip_edges()
	if prop.is_empty():
		prop = _fallback_event_prop(str(object_data.get("visual_key", "")), str(object_data.get("icon_key", "")))
	var accent := _event_prop_accent(prop, selected)
	_draw_interactable_light(rect, accent, selected)
	match prop:
		"clerk_counter", "clerk_talk":
			_draw_event_clerk_prop(rect, accent, prop == "clerk_talk")
		"paper_note":
			_draw_event_paper_prop(rect, accent)
		"trunk_offer":
			_draw_event_trunk_prop(rect, accent)
		"motel_door", "side_door":
			_draw_event_door_prop(rect, accent, prop == "motel_door")
		"jammed_machine":
			_draw_event_machine_prop(rect, accent)
		"security_exit":
			_draw_event_security_prop(rect, accent)
		"security_camera":
			_draw_event_camera_prop(rect, accent)
		"pit_boss":
			_draw_event_patron_prop(rect, accent, 0.72, true)
		"casino_host":
			_draw_event_host_prop(rect, accent)
		"rowdy_patron":
			_draw_event_patron_prop(rect, accent, 0.64, false, true)
		"payphone", "counter_phone":
			_draw_travel_payphone(rect, accent)
		_:
			_draw_event_patron_prop(rect, accent)
	var icon_texture := _texture_for_asset_path(str(object_data.get("asset_path", "")))
	if icon_texture != null:
		_draw_live_texture_icon(icon_texture, _event_icon_rect(rect, prop), object_data, accent, selected, bool(object_data.get("disabled", false)))


func _event_prop_accent(prop: String, selected: bool) -> Color:
	if selected:
		return C_YELLOW
	if prop in ["security_exit", "security_camera", "pit_boss", "jammed_machine"]:
		return C_PINK
	if prop in ["paper_note", "side_door", "motel_door", "payphone", "counter_phone"]:
		return C_ORANGE
	return C_PURPLE_2


func _event_icon_rect(rect: Rect2, prop: String) -> Rect2:
	match prop:
		"paper_note":
			return _centered_icon_rect(rect, 32.0, Vector2(18, -14))
		"security_camera":
			return _centered_icon_rect(rect, 30.0, Vector2(20, 10))
		"motel_door", "side_door":
			return _centered_icon_rect(rect, 30.0, Vector2(22, -10))
		"jammed_machine":
			return _centered_icon_rect(rect, 30.0, Vector2(22, -18))
		"payphone", "counter_phone":
			return _centered_icon_rect(rect, 26.0, Vector2(24, -10))
	return _centered_icon_rect(rect, 34.0, Vector2(24, -18))


func _draw_event_clerk_prop(rect: Rect2, accent: Color, talking: bool) -> void:
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.08, rect.size.y * 0.58), Vector2(rect.size.x * 0.84, rect.size.y * 0.18)), Color("#241327"))
	draw_line(rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.61), rect.position + Vector2(rect.size.x * 0.88, rect.size.y * 0.61), accent, 3)
	_silhouette(rect.position + Vector2(rect.size.x * 0.38, rect.size.y * 0.64), 0.44, C_SHADOW)
	if talking:
		_draw_event_speech_bubble(rect.position + Vector2(rect.size.x * 0.58, rect.size.y * 0.20), accent)
	else:
		draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.56, rect.size.y * 0.30), Vector2(32, 18)), C_YELLOW)
		draw_line(rect.position + Vector2(rect.size.x * 0.59, rect.size.y * 0.40), rect.position + Vector2(rect.size.x * 0.79, rect.size.y * 0.33), C_PINK, 2)


func _draw_event_paper_prop(rect: Rect2, accent: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.16, rect.size.y * 0.66), Vector2(rect.size.x * 0.68, 5)), Color(accent.r, accent.g, accent.b, 0.32))
	var paper := Rect2(rect.position + Vector2(rect.size.x * 0.34, rect.size.y * 0.22), Vector2(rect.size.x * 0.34, rect.size.y * 0.42))
	draw_rect(paper, C_SOFT)
	draw_rect(paper, accent, false, 2)
	for i in range(3):
		draw_line(paper.position + Vector2(6, 9 + i * 8), paper.position + Vector2(paper.size.x - 7, 9 + i * 8), Color(0.0, 0.0, 0.0, 0.34), 1)
	draw_line(paper.position + Vector2(paper.size.x * 0.82, 0), paper.position + Vector2(paper.size.x, paper.size.y * 0.18), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.75), 2)


func _draw_event_trunk_prop(rect: Rect2, accent: Color) -> void:
	var car := Rect2(rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.54), Vector2(rect.size.x * 0.70, rect.size.y * 0.22))
	draw_rect(car, Color("#15101d"))
	draw_rect(Rect2(car.position + Vector2(car.size.x * 0.08, -car.size.y * 0.30), Vector2(car.size.x * 0.40, car.size.y * 0.32)), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.28))
	draw_line(car.position + Vector2(car.size.x * 0.55, 0), car.position + Vector2(car.size.x * 0.78, -rect.size.y * 0.24), accent, 4)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.52, rect.size.y * 0.30), Vector2(28, 22)), Color("#4a2d13"))
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.58, rect.size.y * 0.27), Vector2(12, 5)), C_YELLOW)
	draw_circle(car.position + Vector2(12, car.size.y + 2), 5, C_PINK)
	draw_circle(car.position + Vector2(car.size.x - 12, car.size.y + 2), 5, C_PINK)


func _draw_event_door_prop(rect: Rect2, accent: Color, motel: bool) -> void:
	var door := Rect2(rect.position + Vector2(rect.size.x * 0.34, rect.size.y * 0.10), Vector2(rect.size.x * 0.34, rect.size.y * 0.72))
	draw_rect(door, C_SHADOW)
	draw_rect(Rect2(door.position + Vector2(4, 4), door.size - Vector2(8, 4)), Color("#1a1830"))
	draw_rect(Rect2(door.position + Vector2(door.size.x - 9, door.size.y * 0.48), Vector2(4, 4)), C_YELLOW)
	if motel:
		_neon_text("NO", door.position + Vector2(7, 19), 9, C_PINK)
		for i in range(3):
			draw_line(door.position + Vector2(door.size.x + 6 + i * 5, door.size.y * 0.28), door.position + Vector2(door.size.x + 12 + i * 5, door.size.y * 0.36), accent, 1)
	else:
		draw_line(door.position + Vector2(door.size.x, 8), door.position + Vector2(door.size.x + rect.size.x * 0.18, 0), accent, 2)
		draw_line(door.position + Vector2(door.size.x, door.size.y - 8), door.position + Vector2(door.size.x + rect.size.x * 0.18, door.size.y), accent.darkened(0.1), 2)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.20, rect.size.y * 0.82), Vector2(rect.size.x * 0.60, 5)), Color(accent.r, accent.g, accent.b, 0.35))


func _draw_event_machine_prop(rect: Rect2, accent: Color) -> void:
	var machine := Rect2(rect.position + Vector2(rect.size.x * 0.26, 6), Vector2(rect.size.x * 0.48, rect.size.y * 0.74))
	_slot_machine(machine, accent)
	draw_line(machine.position + Vector2(machine.size.x * 0.18, machine.size.y * 0.24), machine.position + Vector2(machine.size.x * 0.82, machine.size.y * 0.45), C_PINK, 3)
	var badge := Rect2(rect.position + Vector2(rect.size.x * 0.66, rect.size.y * 0.18), Vector2(rect.size.x * 0.18, rect.size.y * 0.22))
	draw_rect(badge, Color(0.05, 0.04, 0.08, 0.86))
	draw_rect(badge, C_YELLOW, false, 2)
	_neon_text("!", badge.position + Vector2(badge.size.x * 0.28, badge.size.y * 0.78), 18, C_YELLOW)


func _draw_event_security_prop(rect: Rect2, accent: Color) -> void:
	_silhouette(rect.position + Vector2(rect.size.x * 0.42, rect.size.y * 0.78), 0.52, C_SHADOW)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.62, rect.size.y * 0.28), Vector2(24, 34)), Color("#111120"))
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.65, rect.size.y * 0.34), Vector2(16, 8)), C_POLICE_BLUE)
	draw_line(rect.position + Vector2(rect.size.x * 0.24, rect.size.y * 0.82), rect.position + Vector2(rect.size.x * 0.78, rect.size.y * 0.82), Color(accent.r, accent.g, accent.b, 0.45), 3)


func _draw_event_camera_prop(rect: Rect2, accent: Color) -> void:
	var mount := rect.position + Vector2(rect.size.x * 0.52, rect.size.y * 0.22)
	draw_line(mount + Vector2(-18, -12), mount, C_SHADOW, 4)
	draw_rect(Rect2(mount + Vector2(-18, 0), Vector2(36, 20)), Color("#141423"))
	draw_circle(mount + Vector2(18, 10), 9, Color(C_POLICE_BLUE.r, C_POLICE_BLUE.g, C_POLICE_BLUE.b, 0.68))
	for i in range(3):
		draw_line(mount + Vector2(16, 18), mount + Vector2(40 + i * 10, 42 + i * 8), Color(accent.r, accent.g, accent.b, 0.18), 1)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.20, rect.size.y * 0.78), Vector2(rect.size.x * 0.60, 4)), Color(accent.r, accent.g, accent.b, 0.28))


func _draw_event_host_prop(rect: Rect2, accent: Color) -> void:
	_draw_event_patron_prop(rect, accent, 0.58)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.60, rect.size.y * 0.42), Vector2(24, 16)), C_YELLOW)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.63, rect.size.y * 0.38), Vector2(11, 16)), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.65))


func _draw_event_patron_prop(rect: Rect2, accent: Color, scale_value: float = 0.58, suited: bool = false, noisy: bool = false) -> void:
	_silhouette(rect.position + Vector2(rect.size.x * 0.42, rect.size.y * 0.78), scale_value, C_SHADOW)
	if suited:
		draw_line(rect.position + Vector2(rect.size.x * 0.35, rect.size.y * 0.48), rect.position + Vector2(rect.size.x * 0.42, rect.size.y * 0.66), C_WHITE, 2)
		draw_line(rect.position + Vector2(rect.size.x * 0.49, rect.size.y * 0.48), rect.position + Vector2(rect.size.x * 0.42, rect.size.y * 0.66), C_WHITE, 2)
		draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.56, rect.size.y * 0.30), Vector2(18, 30)), accent)
	elif noisy:
		_draw_event_speech_bubble(rect.position + Vector2(rect.size.x * 0.58, rect.size.y * 0.18), accent)
		draw_line(rect.position + Vector2(rect.size.x * 0.30, rect.size.y * 0.56), rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.42), accent, 3)
	else:
		_draw_event_speech_bubble(rect.position + Vector2(rect.size.x * 0.58, rect.size.y * 0.22), accent)
	draw_line(rect.position + Vector2(rect.size.x * 0.22, rect.size.y * 0.84), rect.position + Vector2(rect.size.x * 0.78, rect.size.y * 0.84), Color(accent.r, accent.g, accent.b, 0.42), 3)


func _draw_event_speech_bubble(position: Vector2, accent: Color) -> void:
	var bubble := Rect2(position, Vector2(34, 20))
	draw_rect(bubble, Color(0.05, 0.04, 0.08, 0.82))
	draw_rect(bubble, accent, false, 2)
	draw_line(bubble.position + Vector2(8, bubble.size.y), bubble.position + Vector2(2, bubble.size.y + 8), accent, 2)
	draw_line(bubble.position + Vector2(9, 7), bubble.position + Vector2(25, 7), Color(C_WHITE.r, C_WHITE.g, C_WHITE.b, 0.52), 1)
	draw_line(bubble.position + Vector2(9, 13), bubble.position + Vector2(21, 13), Color(C_WHITE.r, C_WHITE.g, C_WHITE.b, 0.36), 1)


func _draw_drink_prop(rect: Rect2, selected: bool) -> void:
	var accent := C_TEAL if selected else C_AMBER
	_draw_interactable_light(rect, accent, selected)
	draw_rect(Rect2(rect.position + Vector2(8, rect.size.y * 0.58), Vector2(rect.size.x - 16, 18)), Color("#3a1c16"))
	for i in range(3):
		var x := rect.position.x + 28 + i * 24
		draw_rect(Rect2(x, rect.position.y + 20 - i % 2 * 8, 12, 34), accent.darkened(0.15))
		draw_rect(Rect2(x + 3, rect.position.y + 12 - i % 2 * 8, 6, 9), C_SOFT)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 36, 26), Vector2(22, 28)), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.32))


func _draw_pressure_overlay() -> void:
	# Heat reads as distant patrol lights, while the HUD carries exact status.
	var level := clampi(suspicion_level, 0, 100)
	if level <= 0:
		return
	var cycle := fposmod(flicker * 4.2, 2.0)
	var red_active := cycle < 1.0
	var strobe := 0.58 + 0.42 * absf(sin(flicker * 18.0))
	var red_phase := strobe if red_active else 0.06
	var blue_phase := strobe if not red_active else 0.06
	if level < 50:
		var subtle := clampf(float(level) / 50.0, 0.0, 1.0)
		var alpha := 0.010 + subtle * 0.035
		_draw_pressure_side_band(C_POLICE_BLUE, alpha * blue_phase, true)
		if level >= 25:
			_draw_pressure_side_band(C_POLICE_RED, alpha * 0.85 * red_phase, false)
		return
	var high := clampf(float(level - 50) / 50.0, 0.0, 1.0)
	var base_alpha := 0.040 + high * 0.135
	var active_color := C_POLICE_RED if red_active else C_POLICE_BLUE
	var inactive_color := C_POLICE_BLUE if red_active else C_POLICE_RED
	var active_phase := red_phase if red_active else blue_phase
	var inactive_phase := blue_phase if red_active else red_phase
	draw_rect(Rect2(Vector2.ZERO, Vector2(BOARD_SIZE)), Color(active_color.r, active_color.g, active_color.b, 0.020 + high * 0.055 * active_phase))
	_draw_pressure_side_band(C_POLICE_RED, base_alpha * red_phase, false)
	_draw_pressure_side_band(C_POLICE_BLUE, base_alpha * blue_phase, true)
	var top_alpha := base_alpha * (0.55 + active_phase * 0.32)
	draw_rect(Rect2(0, 0, BOARD_SIZE.x, 10), Color(active_color.r, active_color.g, active_color.b, top_alpha * active_phase))
	draw_rect(Rect2(0, 10, BOARD_SIZE.x, 8), Color(inactive_color.r, inactive_color.g, inactive_color.b, top_alpha * inactive_phase * 0.35))
	draw_rect(Rect2(0, BOARD_SIZE.y - 12, BOARD_SIZE.x, 12), Color(active_color.r, active_color.g, active_color.b, top_alpha * active_phase * 0.55))
	var sweep_x := fposmod(flicker * (180.0 + high * 120.0), float(BOARD_SIZE.x) + 220.0) - 110.0
	draw_rect(Rect2(sweep_x, 0, 72 + high * 54, BOARD_SIZE.y), Color(active_color.r, active_color.g, active_color.b, base_alpha * 0.28 * active_phase))
	if level >= 70:
		_silhouette(Vector2(846, 220), 1.4, Color("#05050b"))


func _draw_pressure_side_band(color: Color, alpha: float, left_side: bool) -> void:
	for i in range(5):
		var width := 18.0 + float(i) * 12.0
		var band_alpha := alpha * (1.0 - float(i) * 0.16)
		var x := 0.0 if left_side else float(BOARD_SIZE.x) - width
		draw_rect(Rect2(x, 0, width, BOARD_SIZE.y), Color(color.r, color.g, color.b, maxf(0.0, band_alpha)))


func _draw_drunk_overlay() -> void:
	if drunk_effect_mode != "classic":
		return
	var level := clampi(drunk_level, 0, 100)
	if level < 12:
		return
	var normalized := clampf(float(level - 12) / 88.0, 0.0, 1.0)
	var alpha := 0.018 + pow(normalized, 1.25) * 0.070
	draw_rect(Rect2(Vector2.ZERO, Vector2(BOARD_SIZE)), Color(0.08, 0.04, 0.13, alpha))
	var spacing := 18
	var phase := int(fmod(flicker * 10.0, float(spacing)))
	for y in range(-spacing + phase, BOARD_SIZE.y + spacing, spacing):
		var color := C_PINK_2 if int(y / spacing) % 2 == 0 else C_CYAN
		draw_rect(Rect2(0, y, BOARD_SIZE.x, 2), Color(color.r, color.g, color.b, alpha * 1.55))
		if level >= 45:
			draw_rect(Rect2(0, y + 6, BOARD_SIZE.x, 1), Color(color.r, color.g, color.b, alpha * 0.85))


func _floor_reflections() -> void:
	var reflection_y := float(BOARD_SIZE.y) - 52.0
	var glint_y := float(BOARD_SIZE.y) - 38.0
	for x in range(24, 880, 54):
		var color := _cycle_color(x)
		draw_rect(Rect2(x, reflection_y + int(sin(flicker * 2.0 + x) * 4.0), 38, 4), Color(color.r, color.g, color.b, 0.35))
		draw_rect(Rect2(x + 8, glint_y, 68, 2), Color(color.r, color.g, color.b, 0.18))


func _silhouette(pos: Vector2, scale_value: float, color: Color) -> void:
	draw_circle(pos + Vector2(0, -42) * scale_value, 15 * scale_value, color)
	draw_rect(Rect2(pos.x - 18 * scale_value, pos.y - 30 * scale_value, 36 * scale_value, 58 * scale_value), color)
	draw_rect(Rect2(pos.x - 30 * scale_value, pos.y - 14 * scale_value, 12 * scale_value, 48 * scale_value), color)
	draw_rect(Rect2(pos.x + 18 * scale_value, pos.y - 14 * scale_value, 12 * scale_value, 48 * scale_value), color)


func _slot_machine(rect: Rect2, accent: Color) -> void:
	_draw_slot_cabinet_prop(rect, {"label": "SLOT", "source_id": "ambient_slot"}, accent, false, false)


func _draw_pull_tab_machine_prop(rect: Rect2, object_data: Dictionary, accent: Color, selected: bool, disabled: bool = false) -> void:
	var phase := float(abs(hash(str(object_data.get("id", object_data.get("label", "pull_tabs"))))) % 1000) / 1000.0
	var pulse := 0.34 + absf(sin(flicker * (3.0 if selected else 1.7) + phase * TAU)) * (0.26 if selected else 0.12)
	var safe := Rect2(
		rect.position + Vector2(rect.size.x * 0.10, rect.size.y * 0.03),
		Vector2(rect.size.x * 0.80, rect.size.y * 0.92)
	)
	if safe.size.x < 32.0 or safe.size.y < 44.0:
		draw_rect(rect.grow(-2.0), Color("#111019"))
		return
	var base := Rect2(safe.position + Vector2(safe.size.x * 0.12, safe.size.y * 0.86), Vector2(safe.size.x * 0.76, safe.size.y * 0.10))
	var cabinet := Rect2(safe.position + Vector2(safe.size.x * 0.08, safe.size.y * 0.16), Vector2(safe.size.x * 0.84, safe.size.y * 0.72))
	var flare := Rect2(cabinet.position + Vector2(cabinet.size.x * 0.10, cabinet.size.y * 0.10), Vector2(cabinet.size.x * 0.80, cabinet.size.y * 0.30))
	var tray := Rect2(cabinet.position + Vector2(cabinet.size.x * 0.12, cabinet.size.y * 0.70), Vector2(cabinet.size.x * 0.76, cabinet.size.y * 0.13))
	draw_rect(Rect2(safe.position + Vector2(safe.size.x * 0.18, safe.size.y * 0.94), Vector2(safe.size.x * 0.64, safe.size.y * 0.035)), Color(accent.r, accent.g, accent.b, 0.22))
	draw_rect(base, Color("#06060a"))
	draw_rect(cabinet, Color("#141018"))
	draw_rect(cabinet, Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.12 + pulse * 0.08), false, 2)
	draw_rect(Rect2(cabinet.position + Vector2(-safe.size.x * 0.035, cabinet.size.y * 0.08), Vector2(safe.size.x * 0.045, cabinet.size.y * 0.78)), Color(accent.r, accent.g, accent.b, 0.22 + pulse * 0.16))
	draw_rect(Rect2(cabinet.position + Vector2(cabinet.size.x - safe.size.x * 0.010, cabinet.size.y * 0.08), Vector2(safe.size.x * 0.045, cabinet.size.y * 0.78)), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.18 + pulse * 0.14))
	var marquee := Rect2(safe.position + Vector2(safe.size.x * 0.08, safe.size.y * 0.04), Vector2(safe.size.x * 0.84, safe.size.y * 0.15))
	draw_rect(marquee, Color("#1f1119"))
	draw_rect(marquee, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.16 + pulse * 0.12), false, 2)
	var font := get_theme_default_font()
	var title := str(object_data.get("label", "PULL TABS")).to_upper()
	draw_string(font, marquee.position + Vector2(3.0, marquee.size.y * 0.68), _fit_draw_text(title.left(10), font, 8, marquee.size.x - 6.0), HORIZONTAL_ALIGNMENT_CENTER, marquee.size.x - 6.0, 8, C_YELLOW)
	draw_rect(flare, Color("#251520"))
	draw_rect(flare, Color(accent.r, accent.g, accent.b, 0.18 + pulse * 0.12), false, 1)
	for row in range(4):
		var row_y := flare.position.y + 4.0 + float(row) * maxf(5.0, flare.size.y * 0.22)
		var row_color := _cycle_color(row * 37 + int(phase * 100.0))
		draw_rect(Rect2(flare.position.x + 5.0, row_y, flare.size.x - 10.0, maxf(2.0, flare.size.y * 0.10)), Color(row_color.r, row_color.g, row_color.b, 0.52))
		for mark in range(3):
			draw_rect(Rect2(flare.position.x + 9.0 + mark * flare.size.x * 0.24, row_y + 2.0, 5.0, 2.0), Color("#f7e8c8"))
	var window_area := Rect2(cabinet.position + Vector2(cabinet.size.x * 0.13, cabinet.size.y * 0.46), Vector2(cabinet.size.x * 0.74, cabinet.size.y * 0.18))
	for i in range(4):
		var ticket := Rect2(window_area.position + Vector2(float(i) * window_area.size.x * 0.25 + 2.0, 0.0), Vector2(window_area.size.x * 0.20, window_area.size.y))
		draw_rect(ticket, Color("#f3dfb8"))
		draw_rect(ticket, Color("#2a1818"), false, 1)
		draw_line(ticket.position + Vector2(3.0, ticket.size.y * 0.38), ticket.position + Vector2(ticket.size.x - 3.0, ticket.size.y * 0.38), C_PINK, 1)
	draw_rect(tray, Color("#08090d"))
	draw_rect(tray, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.16 + pulse * 0.10), false, 1)
	for i in range(3):
		draw_rect(Rect2(tray.position + Vector2(6.0 + i * tray.size.x * 0.26, tray.size.y * 0.28), Vector2(tray.size.x * 0.20, tray.size.y * 0.34)), Color("#f6dfb6"))
	var plunger := Rect2(cabinet.position + Vector2(cabinet.size.x * 0.76, cabinet.size.y * 0.58), Vector2(cabinet.size.x * 0.11, cabinet.size.y * 0.11))
	draw_rect(plunger, C_PINK)
	draw_circle(plunger.position + plunger.size * 0.5, maxf(2.0, plunger.size.x * 0.30), C_YELLOW)
	if selected:
		draw_rect(safe.grow(2.0), Color(C_WHITE.r, C_WHITE.g, C_WHITE.b, 0.70), false, 2)
	if disabled:
		draw_rect(safe, Color(0.0, 0.0, 0.0, 0.48))
		draw_line(safe.position + Vector2(safe.size.x * 0.12, safe.size.y * 0.20), safe.position + Vector2(safe.size.x * 0.88, safe.size.y * 0.78), C_SOFT, 3)


func _draw_slot_cabinet_prop(rect: Rect2, object_data: Dictionary, accent: Color, selected: bool, disabled: bool = false) -> void:
	var phase := float(abs(hash(str(object_data.get("id", object_data.get("label", "slot"))))) % 1000) / 1000.0
	var profile := _slot_prop_profile(object_data, accent)
	var runtime := _slot_prop_runtime_state(object_data)
	var preview := _slot_prop_preview_state(object_data)
	var preview_phase := str(preview.get("phase", "idle"))
	var live_preview := bool(preview.get("active", false)) or ["spinning", "win", "near_miss", "bonus", "nudge_chain"].has(preview_phase)
	var pulse_speed := 4.8 if preview_phase == "spinning" else 4.1 if live_preview else 3.5 if selected else 2.1
	var pulse := 0.38 + absf(sin(flicker * pulse_speed + phase * TAU)) * (0.34 if live_preview else 0.30 if selected else 0.14)
	var safe := Rect2(
		rect.position + Vector2(rect.size.x * 0.14, rect.size.y * 0.03),
		Vector2(rect.size.x * 0.72, rect.size.y * 0.92)
	)
	if safe.size.x < 28.0 or safe.size.y < 42.0:
		draw_rect(rect.grow(-2.0), Color("#111120"))
		return
	var format_id := str(profile.get("format_id", "classic_3_reel"))
	var reel_count := maxi(3, int(profile.get("reel_count", 3)))
	var row_count := maxi(1, int(profile.get("row_count", 1)))
	var video_feature := format_id == "video_feature"
	var classic := format_id == "classic_3_reel" or row_count <= 1
	var slot_accent: Color = profile.get("accent", accent)
	var slot_light: Color = profile.get("light", C_CYAN)
	var slot_trim: Color = profile.get("trim", C_YELLOW)
	var primary: Color = profile.get("primary", Color("#0b0d18"))
	var secondary: Color = profile.get("secondary", Color("#07070c"))
	var glass: Color = profile.get("glass", Color("#f2efe2"))
	var base := Rect2(safe.position + Vector2(safe.size.x * (0.10 if classic else 0.08), safe.size.y * 0.86), Vector2(safe.size.x * (0.80 if classic else 0.84), safe.size.y * 0.10))
	var body := Rect2(safe.position + Vector2(safe.size.x * (0.15 if classic else 0.08), safe.size.y * (0.20 if classic else 0.15)), Vector2(safe.size.x * (0.70 if classic else 0.84), safe.size.y * (0.68 if classic else 0.73)))
	var topper := Rect2(safe.position + Vector2(safe.size.x * (0.10 if classic else 0.04), safe.size.y * 0.04), Vector2(safe.size.x * (0.80 if classic else 0.92), safe.size.y * (0.17 if classic else 0.15)))
	var screen := Rect2(body.position + Vector2(body.size.x * (0.18 if classic else 0.10), body.size.y * (0.30 if classic else 0.22)), Vector2(body.size.x * (0.64 if classic else 0.80), body.size.y * (0.26 if classic else 0.42)))
	if video_feature:
		screen = Rect2(body.position + Vector2(body.size.x * 0.09, body.size.y * 0.20), Vector2(body.size.x * 0.58, body.size.y * 0.48))
	var feature_panel := Rect2(body.position + Vector2(body.size.x * 0.72, body.size.y * 0.19), Vector2(body.size.x * 0.18, body.size.y * 0.48))
	var deck := Rect2(body.position + Vector2(body.size.x * 0.10, body.size.y * (0.70 if classic else 0.72)), Vector2(body.size.x * 0.80, body.size.y * (0.13 if classic else 0.12)))
	var rail_alpha := 0.34 + pulse * 0.24
	draw_rect(Rect2(safe.position + Vector2(safe.size.x * 0.16, safe.size.y * 0.94), Vector2(safe.size.x * 0.68, safe.size.y * 0.035)), Color(slot_accent.r, slot_accent.g, slot_accent.b, 0.22))
	draw_rect(base, Color("#06060b"))
	draw_rect(base, Color(slot_trim.r, slot_trim.g, slot_trim.b, 0.14 + pulse * 0.08))
	draw_rect(body, primary)
	draw_rect(body, Color(slot_accent.r, slot_accent.g, slot_accent.b, 0.08 + pulse * 0.06), false, 2)
	draw_rect(Rect2(body.position + Vector2(0, body.size.y * 0.06), Vector2(body.size.x, 3)), Color(1.0, 1.0, 1.0, 0.11))
	draw_rect(Rect2(body.position + Vector2(-safe.size.x * 0.035, body.size.y * 0.09), Vector2(safe.size.x * 0.045, body.size.y * 0.76)), Color(slot_light.r, slot_light.g, slot_light.b, rail_alpha))
	draw_rect(Rect2(body.position + Vector2(body.size.x - safe.size.x * 0.010, body.size.y * 0.09), Vector2(safe.size.x * 0.045, body.size.y * 0.76)), Color(slot_accent.r, slot_accent.g, slot_accent.b, rail_alpha))
	draw_rect(topper, secondary)
	draw_rect(topper, Color(slot_trim.r, slot_trim.g, slot_trim.b, 0.16 + pulse * 0.12), false, 2)
	_draw_slot_prop_topper(topper, profile, pulse, phase, preview)
	draw_rect(screen, Color("#03040a"))
	draw_rect(Rect2(screen.position + Vector2(2, 2), screen.size - Vector2(4, 4)), Color("#06080f"))
	draw_rect(screen, Color(slot_light.r, slot_light.g, slot_light.b, 0.16 + pulse * 0.08), false, 1)
	_draw_slot_prop_reels(screen, reel_count, row_count, profile, glass, phase, preview)
	_draw_slot_prop_nudge_chain_overlay(screen, preview, profile, phase, pulse)
	if video_feature:
		_draw_slot_prop_feature_panel(feature_panel, profile, pulse, phase, preview)
	else:
		var feature_strip := Rect2(body.position + Vector2(body.size.x * 0.18, body.size.y * (0.60 if classic else 0.66)), Vector2(body.size.x * 0.64, body.size.y * (0.08 if classic else 0.05)))
		_draw_slot_prop_feature_strip(feature_strip, profile, pulse, phase, preview)
	draw_rect(deck, Color("#12080f"))
	draw_rect(deck, Color(slot_trim.r, slot_trim.g, slot_trim.b, 0.18 + pulse * 0.08), false, 1)
	for i in range(5):
		var button_pos := deck.position + Vector2(deck.size.x * (0.14 + float(i) * 0.18), deck.size.y * 0.52)
		var button_color: Color = _cycle_color(i * 29 + int(phase * 100.0)).lightened(0.08)
		if i == 0:
			button_color = slot_accent
		elif i == 4:
			button_color = slot_light
		draw_circle(button_pos, maxf(2.0, minf(deck.size.x, deck.size.y) * 0.11), button_color)
	_draw_slot_prop_runtime_marker(body, deck, runtime, profile, pulse, preview)
	if classic:
		var lever_x := body.position.x + body.size.x * 0.93
		draw_line(Vector2(lever_x, body.position.y + body.size.y * 0.28), Vector2(lever_x, body.position.y + body.size.y * 0.55), slot_trim, 2)
		draw_circle(Vector2(lever_x, body.position.y + body.size.y * 0.25), maxf(2.0, safe.size.x * 0.035), C_YELLOW)
	var light_count := maxi(3, int(safe.size.x / 16.0))
	for i in range(light_count):
		var t := 0.0 if light_count <= 1 else float(i) / float(light_count - 1)
		var pos := topper.position + Vector2(topper.size.x * t, -1.0)
		var bulb := slot_light if i % 2 == 0 else slot_accent
		draw_circle(pos, 1.6 + pulse * 1.2, Color(bulb.r, bulb.g, bulb.b, 0.28 + pulse * 0.30))
	if selected:
		draw_rect(safe.grow(2.0), Color(C_WHITE.r, C_WHITE.g, C_WHITE.b, 0.70), false, 2)
	if disabled:
		draw_rect(safe, Color(0.0, 0.0, 0.0, 0.48))
		draw_line(safe.position + Vector2(safe.size.x * 0.12, safe.size.y * 0.20), safe.position + Vector2(safe.size.x * 0.88, safe.size.y * 0.78), C_SOFT, 3)


func _slot_prop_visual_state(object_data: Dictionary) -> Dictionary:
	var value: Variant = object_data.get("visual_state", {})
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary)
	return {}


func _slot_prop_runtime_state(object_data: Dictionary) -> Dictionary:
	var value: Variant = object_data.get("runtime_state", {})
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary)
	return {}


func _slot_prop_preview_state(object_data: Dictionary) -> Dictionary:
	var visual := _slot_prop_visual_state(object_data)
	var value: Variant = visual.get("slot_preview", {})
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary)
	return {}


func _slot_prop_profile(object_data: Dictionary, fallback_accent: Color) -> Dictionary:
	var visual := _slot_prop_visual_state(object_data)
	var family := str(visual.get("machine_family", "")).to_lower()
	var format_id := str(visual.get("machine_format", "")).to_lower()
	var identity := str(visual.get("cabinet_identity", "")).to_lower()
	if format_id.is_empty():
		format_id = "classic_3_reel"
	var title := str(visual.get("cabinet_title", object_data.get("label", "SLOT"))).strip_edges().to_upper()
	if title.is_empty():
		title = "SLOT"
	var reel_count := int(visual.get("reel_count", 5 if format_id != "classic_3_reel" else 3))
	var row_count := int(visual.get("row_count", 3 if format_id != "classic_3_reel" else 1))
	var profile := {
		"identity": identity,
		"family": family,
		"format_id": format_id,
		"title": title,
		"reel_count": reel_count,
		"row_count": row_count,
		"primary": Color("#0b0d18"),
		"secondary": Color("#161020"),
		"accent": fallback_accent,
		"light": C_CYAN,
		"trim": C_YELLOW,
		"glass": Color("#f2efe2"),
		"marker": "generic",
	}
	match identity:
		"em_bumper_drop":
			profile.merge({
				"title": "EM BUMP",
				"primary": Color("#3b2418"),
				"secondary": Color("#15100c"),
				"accent": Color("#c99242"),
				"light": Color("#ffe48a"),
				"trim": Color("#b77b35"),
				"glass": Color("#f6e6c8"),
				"marker": "bumpers",
			}, true)
		"lane_multiball":
			profile.merge({
				"title": "LANES",
				"primary": Color("#20304d"),
				"secondary": Color("#080b14"),
				"accent": Color("#ff7a2f"),
				"light": Color("#59d8ff"),
				"trim": Color("#ffd45a"),
				"glass": Color("#d9fbff"),
				"marker": "lanes",
			}, true)
		"full_table":
			profile.merge({
				"title": "TABLE",
				"primary": Color("#141827"),
				"secondary": Color("#05070f"),
				"accent": Color("#6ff3ff"),
				"light": Color("#ff4fd8"),
				"trim": Color("#f8fafc"),
				"glass": Color("#dffbff"),
				"marker": "table",
			}, true)
		"heritage":
			profile.merge({
				"title": "HERITAGE",
				"primary": Color("#352110"),
				"secondary": Color("#160d07"),
				"accent": Color("#d09a42"),
				"light": Color("#f3d27a"),
				"trim": Color("#7b3f1a"),
				"glass": Color("#f8dfad"),
				"marker": "horns",
			}, true)
		"ways":
			profile.merge({
				"title": "WAYS",
				"primary": Color("#5b2c17"),
				"secondary": Color("#130907"),
				"accent": Color("#ef6a24"),
				"light": Color("#ffd16a"),
				"trim": Color("#f4c15d"),
				"glass": Color("#ffe0a5"),
				"marker": "sunset",
			}, true)
		"link_arena":
			profile.merge({
				"title": "LINK",
				"primary": Color("#25140d"),
				"secondary": Color("#070504"),
				"accent": Color("#ffb44f"),
				"light": Color("#65f0ff"),
				"trim": Color("#d94c26"),
				"glass": Color("#ffe0ad"),
				"marker": "wheel",
			}, true)
		_:
			if family == "buffalo":
				profile.merge({
					"primary": Color("#432514"),
					"secondary": Color("#120807"),
					"accent": Color("#ef6a24"),
					"light": Color("#ffd16a"),
					"trim": Color("#c9903d"),
					"glass": Color("#ffe0a5"),
					"marker": "sunset",
				}, true)
			elif format_id == "video_feature":
				profile.merge({
					"primary": Color("#141827"),
					"secondary": Color("#05070f"),
					"accent": Color("#6ff3ff"),
					"light": Color("#ff4fd8"),
					"trim": Color("#f8fafc"),
					"glass": Color("#dffbff"),
					"marker": "table",
				}, true)
	return profile


func _draw_slot_prop_topper(topper: Rect2, profile: Dictionary, pulse: float, phase: float, preview: Dictionary = {}) -> void:
	var accent_color: Color = profile.get("accent", C_PINK)
	var light_color: Color = profile.get("light", C_CYAN)
	var trim_color: Color = profile.get("trim", C_YELLOW)
	var marker := str(profile.get("marker", "generic"))
	var preview_phase := str(preview.get("phase", "idle"))
	match marker:
		"horns":
			var center := topper.position + topper.size * 0.5
			draw_line(center + Vector2(-8, 2), center + Vector2(-topper.size.x * 0.34, -topper.size.y * 0.20), trim_color, 2)
			draw_line(center + Vector2(8, 2), center + Vector2(topper.size.x * 0.34, -topper.size.y * 0.20), trim_color, 2)
			var head_color := light_color if preview_phase == "win" else accent_color
			draw_circle(center + Vector2(0, -pulse * 1.8 if preview_phase == "bonus" else 0), maxf(3.0, topper.size.y * 0.22), head_color)
		"sunset":
			for i in range(3):
				var band_y := topper.position.y + topper.size.y * (0.20 + float(i) * 0.20)
				draw_rect(Rect2(topper.position.x + 4.0, band_y, topper.size.x - 8.0, maxf(2.0, topper.size.y * 0.10)), Color(accent_color.r, accent_color.g, accent_color.b, 0.20 + float(i) * 0.12))
			draw_circle(topper.position + Vector2(topper.size.x * 0.72, topper.size.y * 0.42), maxf(3.0, topper.size.y * 0.16), light_color)
		"lanes":
			for i in range(4):
				var x := topper.position.x + topper.size.x * (0.18 + float(i) * 0.16)
				draw_line(Vector2(x, topper.position.y + topper.size.y * 0.72), Vector2(x + topper.size.x * 0.10, topper.position.y + topper.size.y * 0.20), Color(light_color.r, light_color.g, light_color.b, 0.50 + pulse * 0.20), 1)
		"table":
			draw_rect(Rect2(topper.position + Vector2(5.0, topper.size.y * 0.25), Vector2(topper.size.x - 10.0, maxf(3.0, topper.size.y * 0.16))), Color(light_color.r, light_color.g, light_color.b, 0.34 + pulse * 0.22))
			draw_rect(Rect2(topper.position + Vector2(5.0, topper.size.y * 0.54), Vector2(topper.size.x - 10.0, maxf(3.0, topper.size.y * 0.16))), Color(accent_color.r, accent_color.g, accent_color.b, 0.34 + pulse * 0.22))
		"wheel":
			var wheel := topper.position + Vector2(topper.size.x * 0.75, topper.size.y * 0.48)
			var wheel_angle := flicker * (2.8 if preview_phase == "bonus" else 1.2)
			draw_circle(wheel, maxf(4.0, topper.size.y * 0.25), Color(light_color.r, light_color.g, light_color.b, 0.24 + pulse * 0.18))
			draw_line(wheel, wheel + Vector2(cos(wheel_angle), sin(wheel_angle)) * maxf(4.0, topper.size.y * 0.24), trim_color, 1)
			draw_circle(wheel, maxf(2.0, topper.size.y * 0.11), trim_color)
		_:
			for i in range(3):
				var score := Rect2(topper.position + Vector2(topper.size.x * (0.17 + float(i) * 0.22), topper.size.y * 0.24), Vector2(topper.size.x * 0.13, topper.size.y * 0.24))
				draw_rect(score, Color("#05050a"))
				draw_rect(score, Color(trim_color.r, trim_color.g, trim_color.b, 0.22 + pulse * 0.10), false, 1)
	var font := get_theme_default_font()
	var title_size := clampi(int(topper.size.y * 0.34), 7, 13)
	var title := str(profile.get("title", "SLOT")).left(10)
	var status := str(preview.get("status_label", "")).strip_edges()
	if not status.is_empty() and preview_phase != "idle":
		title = status.left(10)
	draw_string(font, topper.position + Vector2(4.0, topper.size.y * 0.66), _fit_draw_text(title, font, title_size, topper.size.x - 8.0), HORIZONTAL_ALIGNMENT_CENTER, topper.size.x - 8.0, title_size, C_YELLOW)


func _draw_slot_prop_reels(screen: Rect2, reel_count: int, row_count: int, profile: Dictionary, glass: Color, phase: float, preview: Dictionary = {}) -> void:
	var family := str(profile.get("family", ""))
	var accent_color: Color = profile.get("accent", C_PINK)
	var light_color: Color = profile.get("light", C_CYAN)
	var preview_phase := str(preview.get("phase", "idle"))
	var spin_active := preview_phase == "spinning"
	var reel_gap := maxf(1.0, screen.size.x * 0.020)
	var reel_w := (screen.size.x - reel_gap * float(reel_count + 1)) / float(reel_count)
	var reel_h := screen.size.y * 0.76
	for i in range(reel_count):
		var reel := Rect2(screen.position + Vector2(reel_gap + float(i) * (reel_w + reel_gap), screen.size.y * 0.12), Vector2(reel_w, reel_h))
		draw_rect(reel, glass)
		draw_rect(reel, Color("#0f1220"), false, 1)
		if row_count <= 1:
			if spin_active:
				var cell_h := reel.size.y * 0.42
				var scroll := fposmod(flicker * (42.0 + float(i) * 5.0), cell_h)
				for band in range(3):
					var symbol_rect := Rect2(reel.position + Vector2(reel.size.x * 0.18, reel.size.y * 0.06 + float(band) * cell_h - scroll), Vector2(reel.size.x * 0.64, cell_h * 0.70))
					_draw_slot_prop_symbol(symbol_rect, _slot_prop_preview_symbol(preview, i, band), family, i + band, phase, false)
			else:
				var symbol := Rect2(reel.position + reel.size * 0.22, reel.size * 0.56)
				_draw_slot_prop_symbol(symbol, _slot_prop_preview_symbol(preview, i, 0), family, i, phase, _slot_prop_preview_cell_highlight(preview, i, 0))
		else:
			var cell_gap := maxf(1.0, reel.size.y * 0.035)
			var cell_h := (reel.size.y - cell_gap * float(row_count + 1)) / float(row_count)
			var scroll := fposmod(flicker * (38.0 + float(i) * 4.0), cell_h + cell_gap) if spin_active else 0.0
			for row in range(row_count):
				var cell := Rect2(reel.position + Vector2(reel.size.x * 0.18, cell_gap + float(row) * (cell_h + cell_gap) - scroll), Vector2(reel.size.x * 0.64, cell_h))
				var symbol_id := _slot_prop_preview_symbol(preview, i, row + (1 if spin_active else 0))
				if symbol_id == "BLANK" and row == 1:
					symbol_id = "BUFFALO" if family == "buffalo" and i % 2 == 0 else "BALL"
				var highlight := _slot_prop_preview_cell_highlight(preview, i, row)
				_draw_slot_prop_symbol(cell, symbol_id, family, i + row * 7, phase, highlight)
			if spin_active:
				draw_rect(reel, Color(light_color.r, light_color.g, light_color.b, 0.10 + absf(sin(flicker * 10.0 + float(i))) * 0.12))


func _slot_prop_symbol_color(family: String, index: int, phase: float) -> Color:
	if family == "buffalo":
		var colors := [Color("#f4c15d"), Color("#7b3f1a"), Color("#ef6a24"), Color("#ffd16a")]
		return colors[posmod(index + int(phase * 10.0), colors.size())]
	var pinball_colors := [C_PINK, C_CYAN, C_YELLOW, C_ORANGE]
	return pinball_colors[posmod(index + int(phase * 10.0), pinball_colors.size())]


func _slot_prop_symbol_color_for_id(symbol: String, family: String, index: int, phase: float) -> Color:
	match symbol:
		"GOLD_TOKEN", "COIN":
			return Color("#ffd45a")
		"BUFFALO":
			return Color("#c67832")
		"SUNSET", "SUNSET_2X", "SUNSET_3X", "WILD", "DOUBLE", "DOUBLE_7":
			return Color("#65f0ff")
		"7":
			return Color("#ff3f75")
		"BAR":
			return Color("#f8fafc")
		"CHERRY":
			return Color("#ff4f5f")
		"BALL", "BUMPER", "SPINNER":
			return Color("#59d8ff")
		"BLANK", "":
			return Color("#1b1d2d")
		_:
			if family == "buffalo":
				return _slot_prop_symbol_color(family, index, phase)
			return _slot_prop_symbol_color(family, index, phase)


func _slot_prop_symbol_short(symbol: String) -> String:
	match symbol:
		"GOLD_TOKEN", "COIN":
			return "$"
		"SUNSET_2X", "DOUBLE", "DOUBLE_7":
			return "2"
		"SUNSET_3X":
			return "3"
		"BUFFALO":
			return "B"
		"CHERRY":
			return "C"
		"BUMPER":
			return "O"
		"SPINNER":
			return "*"
		"BALL":
			return "o"
		"WOLF":
			return "W"
		"HORSE":
			return "H"
		"EAGLE":
			return "E"
		"ELK":
			return "E"
		"BLANK", "":
			return ""
		_:
			return symbol.left(1)


func _draw_slot_prop_symbol(rect: Rect2, symbol: String, family: String, index: int, phase: float, highlight: bool = false) -> void:
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var color := _slot_prop_symbol_color_for_id(symbol, family, index, phase)
	var alpha := 0.94 if symbol != "BLANK" else 0.36
	if symbol == "GOLD_TOKEN" or symbol == "COIN":
		var center := rect.position + rect.size * 0.5
		var radius := minf(rect.size.x, rect.size.y) * 0.42
		draw_circle(center, radius, Color(color.r, color.g, color.b, alpha))
		draw_circle(center + Vector2(-radius * 0.24, -radius * 0.24), radius * 0.28, Color(1.0, 1.0, 1.0, 0.42))
		draw_circle(center, radius * 0.72, Color("#7b4f13"), false, 1)
	else:
		draw_rect(rect, Color(color.r, color.g, color.b, alpha))
		draw_rect(rect.grow(-1.0), Color(1.0, 1.0, 1.0, 0.11), false, 1)
	if highlight:
		draw_rect(rect.grow(1.5), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.66), false, 2)
	var label := _slot_prop_symbol_short(symbol)
	if not label.is_empty() and rect.size.x >= 8.0 and rect.size.y >= 8.0:
		var font := get_theme_default_font()
		var label_size := clampi(int(minf(rect.size.x, rect.size.y) * 0.62), 6, 10)
		draw_string(font, rect.position + Vector2(1.0, rect.size.y * 0.68), _fit_draw_text(label, font, label_size, rect.size.x - 2.0), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 2.0, label_size, Color("#070812"))


func _slot_prop_preview_symbol(preview: Dictionary, reel_index: int, row_index: int) -> String:
	var grid_value: Variant = preview.get("grid", [])
	if typeof(grid_value) != TYPE_ARRAY:
		return "BLANK"
	var grid: Array = grid_value as Array
	if grid.is_empty():
		return "BLANK"
	var safe_reel := posmod(reel_index, grid.size())
	if typeof(grid[safe_reel]) != TYPE_ARRAY:
		return "BLANK"
	var column: Array = grid[safe_reel] as Array
	if column.is_empty():
		return "BLANK"
	return str(column[posmod(row_index, column.size())])


func _slot_prop_preview_cell_highlight(preview: Dictionary, reel_index: int, row_index: int) -> bool:
	for cell_value in _copy_array(preview.get("win_cells", [])):
		if typeof(cell_value) != TYPE_DICTIONARY:
			continue
		var cell: Dictionary = cell_value
		if int(cell.get("reel", -1)) == reel_index and int(cell.get("row", -1)) == row_index:
			return true
	return false


func _draw_slot_prop_feature_strip(strip: Rect2, profile: Dictionary, pulse: float, phase: float, preview: Dictionary = {}) -> void:
	var marker := str(profile.get("marker", "generic"))
	var accent_color: Color = profile.get("accent", C_PINK)
	var light_color: Color = profile.get("light", C_CYAN)
	var bonus: Dictionary = _copy_dictionary(preview.get("bonus", {}))
	var bonus_active := bool(bonus.get("active", false))
	draw_rect(strip, Color("#07070c"))
	draw_rect(strip, Color(accent_color.r, accent_color.g, accent_color.b, 0.16 + pulse * (0.18 if bonus_active else 0.10)), false, 1)
	match marker:
		"bumpers":
			for i in range(3):
				draw_circle(strip.position + Vector2(strip.size.x * (0.25 + float(i) * 0.25), strip.size.y * 0.50), maxf(2.0, strip.size.y * 0.24), _cycle_color(i * 33))
		"lanes":
			for i in range(5):
				var x := strip.position.x + strip.size.x * (0.12 + float(i) * 0.18)
				draw_line(Vector2(x, strip.position.y + strip.size.y * 0.78), Vector2(x + strip.size.x * 0.10, strip.position.y + strip.size.y * 0.20), light_color, 1)
		"sunset", "horns":
			draw_rect(Rect2(strip.position + Vector2(strip.size.x * 0.12, strip.size.y * 0.35), Vector2(strip.size.x * 0.76, maxf(2.0, strip.size.y * 0.20))), Color(light_color.r, light_color.g, light_color.b, 0.44))
			draw_rect(Rect2(strip.position + Vector2(strip.size.x * 0.32, strip.size.y * 0.20), Vector2(strip.size.x * 0.18, strip.size.y * 0.42)), Color("#22130b"))
		_:
			for i in range(4):
				var x := strip.position.x + fposmod(phase * strip.size.x + float(i) * strip.size.x * 0.25, strip.size.x)
				draw_rect(Rect2(x, strip.position.y + strip.size.y * 0.30, maxf(3.0, strip.size.x * 0.08), maxf(2.0, strip.size.y * 0.34)), Color(light_color.r, light_color.g, light_color.b, 0.42))
	if bonus_active:
		var total := maxi(1, int(bonus.get("total_steps", bonus.get("remaining_steps", 1))))
		var remaining := clampi(int(bonus.get("remaining_steps", 0)), 0, total)
		var filled := 1.0 - float(remaining) / float(total)
		draw_rect(Rect2(strip.position + Vector2(2.0, strip.size.y - 4.0), Vector2(maxf(2.0, (strip.size.x - 4.0) * filled), 2.0)), Color(light_color.r, light_color.g, light_color.b, 0.72))


func _draw_slot_prop_feature_panel(panel: Rect2, profile: Dictionary, pulse: float, phase: float, preview: Dictionary = {}) -> void:
	var marker := str(profile.get("marker", "generic"))
	var accent_color: Color = profile.get("accent", C_PINK)
	var light_color: Color = profile.get("light", C_CYAN)
	var trim_color: Color = profile.get("trim", C_YELLOW)
	var bonus: Dictionary = _copy_dictionary(preview.get("bonus", {}))
	var bonus_active := bool(bonus.get("active", false))
	draw_rect(panel, Color("#05060b"))
	draw_rect(panel, Color(light_color.r, light_color.g, light_color.b, 0.12 + pulse * (0.20 if bonus_active else 0.12)), false, 1)
	match marker:
		"wheel":
			var center := panel.position + panel.size * Vector2(0.50, 0.32)
			draw_circle(center, maxf(5.0, panel.size.x * 0.34), Color(light_color.r, light_color.g, light_color.b, 0.26 + pulse * 0.16))
			draw_circle(center, maxf(2.0, panel.size.x * 0.12), trim_color)
			for i in range(4):
				draw_rect(Rect2(panel.position + Vector2(panel.size.x * 0.22, panel.size.y * (0.58 + float(i) * 0.09)), Vector2(panel.size.x * 0.56, maxf(2.0, panel.size.y * 0.035))), Color(accent_color.r, accent_color.g, accent_color.b, 0.35 + float(i) * 0.08))
		"table":
			var playfield := Rect2(panel.position + Vector2(panel.size.x * 0.16, panel.size.y * 0.12), Vector2(panel.size.x * 0.68, panel.size.y * 0.72))
			draw_rect(playfield, Color("#10151d"))
			draw_line(playfield.position + Vector2(playfield.size.x * 0.22, playfield.size.y * 0.80), playfield.position + Vector2(playfield.size.x * 0.46, playfield.size.y * 0.62), accent_color, 2)
			draw_line(playfield.position + Vector2(playfield.size.x * 0.78, playfield.size.y * 0.80), playfield.position + Vector2(playfield.size.x * 0.54, playfield.size.y * 0.62), light_color, 2)
			draw_circle(playfield.position + Vector2(playfield.size.x * 0.52, playfield.size.y * 0.34), maxf(2.0, playfield.size.x * 0.12), trim_color)
		_:
			for i in range(5):
				var y := panel.position.y + panel.size.y * (0.14 + float(i) * 0.15)
				draw_rect(Rect2(panel.position.x + panel.size.x * 0.20, y, panel.size.x * 0.60, maxf(2.0, panel.size.y * 0.04)), Color(_cycle_color(i * 41 + int(phase * 100.0)).r, _cycle_color(i * 41 + int(phase * 100.0)).g, _cycle_color(i * 41 + int(phase * 100.0)).b, 0.46))
	if bonus_active:
		var remaining := int(bonus.get("remaining_steps", bonus.get("free_spins", 0)))
		var font := get_theme_default_font()
		var bonus_text := "B" + str(remaining)
		draw_string(font, panel.position + Vector2(1.0, panel.size.y - 5.0), _fit_draw_text(bonus_text, font, 7, panel.size.x - 2.0), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 2.0, 7, trim_color)


func _draw_slot_prop_nudge_chain_overlay(screen: Rect2, preview: Dictionary, profile: Dictionary, phase: float, pulse: float) -> void:
	var chain: Dictionary = _copy_dictionary(preview.get("nudge_chain", {}))
	if not bool(chain.get("active", false)):
		return
	var coins: Array = _copy_array(chain.get("coins", []))
	var row_count := maxi(1, int(preview.get("row_count", 1)))
	var active_index := clampi(int(chain.get("active_index", 0)), 0, maxi(0, coins.size() - 1))
	var active_coin: Dictionary = _copy_dictionary(coins[active_index]) if active_index < coins.size() else {}
	var active_row := clampi(int(active_coin.get("row", active_index)), 0, row_count - 1)
	var side := str(active_coin.get("side", "left"))
	var trim_color: Color = profile.get("trim", C_YELLOW)
	var light_color: Color = profile.get("light", C_CYAN)
	var accent_color: Color = profile.get("accent", C_PINK)
	var row_h := screen.size.y * 0.76 / float(row_count)
	var y := screen.position.y + screen.size.y * 0.12 + row_h * (float(active_row) + 0.5)
	var peek := 0.22 + 0.78 * absf(sin(flicker * 3.9 + phase * TAU))
	var radius := clampf(minf(screen.size.x, screen.size.y) * 0.09, 3.0, 9.0)
	var edge_x := screen.position.x + 2.0 if side == "left" else screen.end.x - 2.0
	var x := edge_x - radius + peek * radius * 2.0 if side == "left" else edge_x + radius - peek * radius * 2.0
	var zone := Rect2(Vector2(edge_x - radius * 1.5, y - radius * 1.6), Vector2(radius * 3.0, radius * 3.2)) if side == "left" else Rect2(Vector2(edge_x - radius * 1.5, y - radius * 1.6), Vector2(radius * 3.0, radius * 3.2))
	draw_rect(zone, Color(accent_color.r, accent_color.g, accent_color.b, 0.24 + pulse * 0.22), false, 1)
	draw_circle(Vector2(x, y), radius, Color(trim_color.r, trim_color.g, trim_color.b, 0.92))
	draw_circle(Vector2(x - radius * 0.25, y - radius * 0.25), radius * 0.28, Color(1.0, 1.0, 1.0, 0.45))
	var collected := int(chain.get("collected_count", 0))
	if collected > 0:
		var font := get_theme_default_font()
		var chain_text := str(collected) + "/$" + str(int(chain.get("banked_payout", 0)))
		draw_string(font, screen.position + Vector2(2.0, screen.size.y - 3.0), _fit_draw_text(chain_text, font, 7, screen.size.x - 4.0), HORIZONTAL_ALIGNMENT_CENTER, screen.size.x - 4.0, 7, light_color)


func _draw_slot_prop_runtime_marker(body: Rect2, deck: Rect2, runtime: Dictionary, profile: Dictionary, pulse: float, preview: Dictionary = {}) -> void:
	var visual_payout := 0
	var payout := maxi(int(preview.get("payout", runtime.get("slot_last_payout", visual_payout))), 0)
	var bonus: Dictionary = _copy_dictionary(preview.get("bonus", {}))
	var free_spins := int(bonus.get("free_spins", runtime.get("slot_free_spins", 0)))
	var bonus_active := bool(bonus.get("active", runtime.get("slot_bonus_active", false)))
	var pending_feature := bool(preview.get("pending_feature", runtime.get("slot_pending_feature", bonus_active)))
	var autoplay := bool(preview.get("autoplay_active", runtime.get("slot_autoplay_active", false)))
	var preview_phase := str(preview.get("phase", runtime.get("slot_preview_phase", "")))
	var trim_color: Color = profile.get("trim", C_YELLOW)
	var light_color: Color = profile.get("light", C_CYAN)
	var accent_color: Color = profile.get("accent", C_PINK)
	if payout > 0:
		var win_strip := Rect2(deck.position + Vector2(deck.size.x * 0.12, -deck.size.y * 0.52), Vector2(deck.size.x * 0.76, maxf(3.0, deck.size.y * 0.28)))
		draw_rect(win_strip, Color(trim_color.r, trim_color.g, trim_color.b, 0.34 + pulse * 0.24))
		for i in range(3):
			draw_circle(win_strip.position + Vector2(win_strip.size.x * (0.24 + float(i) * 0.26), win_strip.size.y * 0.50), maxf(1.5, win_strip.size.y * 0.24), C_YELLOW)
	if free_spins > 0 or bonus_active or pending_feature:
		var bonus_lamp := body.position + Vector2(body.size.x * 0.12, body.size.y * 0.12)
		var lamp_radius := maxf(2.0, body.size.x * (0.052 if pending_feature else 0.035))
		draw_circle(bonus_lamp, lamp_radius * 1.75, Color(light_color.r, light_color.g, light_color.b, 0.14 + pulse * 0.18))
		draw_circle(bonus_lamp, lamp_radius, Color(light_color.r, light_color.g, light_color.b, 0.62 + pulse * 0.30))
	if autoplay:
		var auto_lamp := body.position + Vector2(body.size.x * 0.88, body.size.y * 0.12)
		draw_circle(auto_lamp, maxf(2.0, body.size.x * 0.035), Color(accent_color.r, accent_color.g, accent_color.b, 0.52 + pulse * 0.28))
	if preview_phase == "spinning":
		var sweep_x := body.position.x + fposmod(flicker * 42.0, body.size.x)
		draw_rect(Rect2(Vector2(sweep_x, body.position.y + body.size.y * 0.25), Vector2(3.0, body.size.y * 0.40)), Color(light_color.r, light_color.g, light_color.b, 0.26))
	elif preview_phase == "near_miss":
		draw_rect(Rect2(deck.position + Vector2(deck.size.x * 0.16, -deck.size.y * 0.44), Vector2(deck.size.x * 0.68, maxf(3.0, deck.size.y * 0.22))), Color(accent_color.r, accent_color.g, accent_color.b, 0.26 + pulse * 0.18))
	var caption := str(preview.get("status_label", runtime.get("slot_preview_phase", ""))).strip_edges().to_upper()
	if pending_feature:
		caption = "FEATURE"
	if caption.is_empty() and autoplay:
		caption = "AUTO"
	if not caption.is_empty():
		var font := get_theme_default_font()
		var label_rect := Rect2(deck.position + Vector2(deck.size.x * 0.12, deck.size.y * 0.08), Vector2(deck.size.x * 0.76, deck.size.y * 0.36))
		draw_rect(label_rect, Color(0.0, 0.0, 0.0, 0.52))
		draw_string(font, label_rect.position + Vector2(2.0, label_rect.size.y - 2.0), _fit_draw_text(caption.left(8), font, 7, label_rect.size.x - 4.0), HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x - 4.0, 7, trim_color if preview_phase == "win" else light_color)


func _draw_video_poker_machine_prop(rect: Rect2, object_data: Dictionary, accent: Color, selected: bool, disabled: bool = false) -> void:
	var phase := float(abs(hash(str(object_data.get("id", object_data.get("label", "video_poker"))))) % 1000) / 1000.0
	var pulse := 0.34 + absf(sin(flicker * (3.2 if selected else 1.8) + phase * TAU)) * (0.30 if selected else 0.13)
	var safe := Rect2(
		rect.position + Vector2(rect.size.x * 0.09, rect.size.y * 0.04),
		Vector2(rect.size.x * 0.82, rect.size.y * 0.91)
	)
	if safe.size.x < 36.0 or safe.size.y < 46.0:
		draw_rect(rect.grow(-2.0), Color("#10121d"))
		return
	var base := Rect2(safe.position + Vector2(safe.size.x * 0.12, safe.size.y * 0.86), Vector2(safe.size.x * 0.76, safe.size.y * 0.10))
	var cabinet := Rect2(safe.position + Vector2(safe.size.x * 0.09, safe.size.y * 0.13), Vector2(safe.size.x * 0.82, safe.size.y * 0.75))
	var marquee := Rect2(safe.position + Vector2(safe.size.x * 0.14, safe.size.y * 0.04), Vector2(safe.size.x * 0.72, safe.size.y * 0.13))
	var screen := Rect2(cabinet.position + Vector2(cabinet.size.x * 0.10, cabinet.size.y * 0.18), Vector2(cabinet.size.x * 0.80, cabinet.size.y * 0.42))
	var paytable := Rect2(screen.position + Vector2(screen.size.x * 0.08, screen.size.y * 0.10), Vector2(screen.size.x * 0.84, screen.size.y * 0.16))
	var deck := Rect2(cabinet.position + Vector2(cabinet.size.x * 0.10, cabinet.size.y * 0.66), Vector2(cabinet.size.x * 0.80, cabinet.size.y * 0.16))
	var cabinet_glow := Color(accent.r, accent.g, accent.b, 0.08 + pulse * 0.06)
	draw_rect(Rect2(safe.position + Vector2(safe.size.x * 0.20, safe.size.y * 0.94), Vector2(safe.size.x * 0.60, safe.size.y * 0.035)), Color(accent.r, accent.g, accent.b, 0.22))
	draw_rect(base, Color("#06070d"))
	draw_rect(base, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.10 + pulse * 0.08))
	draw_rect(cabinet, Color("#0a0d18"))
	draw_rect(cabinet, cabinet_glow, false, 2)
	draw_rect(Rect2(cabinet.position + Vector2(-safe.size.x * 0.035, cabinet.size.y * 0.12), Vector2(safe.size.x * 0.05, cabinet.size.y * 0.70)), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.24 + pulse * 0.20))
	draw_rect(Rect2(cabinet.position + Vector2(cabinet.size.x - safe.size.x * 0.015, cabinet.size.y * 0.12), Vector2(safe.size.x * 0.05, cabinet.size.y * 0.70)), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.22 + pulse * 0.18))
	draw_rect(marquee, Color("#18111e"))
	draw_rect(marquee, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.14 + pulse * 0.12), false, 2)
	var font := get_theme_default_font()
	var title_size := clampi(int(marquee.size.y * 0.40), 7, 12)
	draw_string(font, marquee.position + Vector2(4.0, marquee.size.y * 0.66), _fit_draw_text("VIDEO POKER", font, title_size, marquee.size.x - 8.0), HORIZONTAL_ALIGNMENT_CENTER, marquee.size.x - 8.0, title_size, C_YELLOW)
	draw_rect(screen, C_SHADOW)
	draw_rect(Rect2(screen.position + Vector2(2, 2), screen.size - Vector2(4, 4)), Color("#041016"))
	draw_rect(screen, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.22 + pulse * 0.14), false, 1)
	draw_rect(paytable, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.18 + pulse * 0.10))
	for row in range(2):
		var row_y := paytable.position.y + 2.0 + float(row) * maxf(3.0, paytable.size.y * 0.34)
		draw_line(Vector2(paytable.position.x + 3.0, row_y), Vector2(paytable.position.x + paytable.size.x - 3.0, row_y), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.28), 1)
	var card_gap := maxf(1.0, screen.size.x * 0.025)
	var card_w := (screen.size.x - card_gap * 6.0) / 5.0
	var card_h := screen.size.y * 0.40
	for i in range(5):
		var card := Rect2(screen.position + Vector2(card_gap + float(i) * (card_w + card_gap), screen.size.y * 0.46), Vector2(card_w, card_h))
		draw_rect(card, Color("#f5f1df"))
		draw_rect(card, Color("#111423"), false, 1)
		var pip_color := C_PINK if i % 2 == 0 else C_SHADOW
		draw_rect(Rect2(card.position + Vector2(card.size.x * 0.24, card.size.y * 0.22), Vector2(maxf(2.0, card.size.x * 0.32), maxf(2.0, card.size.y * 0.22))), pip_color)
		draw_rect(Rect2(card.position + Vector2(card.size.x * 0.46, card.size.y * 0.56), Vector2(maxf(2.0, card.size.x * 0.28), maxf(2.0, card.size.y * 0.20))), C_CYAN)
	draw_rect(deck, Color("#170911"))
	draw_rect(deck, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.20 + pulse * 0.08), false, 1)
	for i in range(5):
		var hold_button := deck.position + Vector2(deck.size.x * (0.14 + float(i) * 0.18), deck.size.y * 0.36)
		draw_rect(Rect2(hold_button - Vector2(3.0, 2.0), Vector2(6.0, 4.0)), C_AMBER if i % 2 == 0 else C_CYAN)
	for i in range(3):
		var button_pos := deck.position + Vector2(deck.size.x * (0.28 + float(i) * 0.22), deck.size.y * 0.74)
		draw_circle(button_pos, maxf(2.0, minf(deck.size.x, deck.size.y) * 0.11), _cycle_color(i * 37 + int(phase * 100.0)).lightened(0.08))
	var bill_slot := Rect2(cabinet.position + Vector2(cabinet.size.x * 0.66, cabinet.size.y * 0.84), Vector2(cabinet.size.x * 0.18, maxf(3.0, cabinet.size.y * 0.035)))
	draw_rect(bill_slot, C_SHADOW)
	draw_rect(Rect2(bill_slot.position + Vector2(2, 1), bill_slot.size - Vector2(4, 2)), C_AMBER)
	var light_count := maxi(4, int(safe.size.x / 15.0))
	for i in range(light_count):
		var t := 0.0 if light_count <= 1 else float(i) / float(light_count - 1)
		var pos := marquee.position + Vector2(marquee.size.x * t, -1.0)
		draw_circle(pos, 1.4 + pulse * 1.0, Color(accent.r, accent.g, accent.b, 0.26 + pulse * 0.28))
	if selected:
		draw_rect(safe.grow(2.0), Color(C_WHITE.r, C_WHITE.g, C_WHITE.b, 0.70), false, 2)
	if disabled:
		draw_rect(safe, Color(0.0, 0.0, 0.0, 0.48))
		draw_line(safe.position + Vector2(safe.size.x * 0.12, safe.size.y * 0.20), safe.position + Vector2(safe.size.x * 0.88, safe.size.y * 0.78), C_SOFT, 3)


func _draw_baccarat_table_prop(rect: Rect2, object_data: Dictionary, accent: Color, selected: bool, disabled: bool = false) -> void:
	var phase := float(abs(hash(str(object_data.get("id", object_data.get("label", "baccarat"))))) % 1000) / 1000.0
	var pulse := 0.34 + absf(sin(flicker * (2.8 if selected else 1.5) + phase * TAU)) * (0.28 if selected else 0.12)
	var safe := Rect2(
		rect.position + Vector2(rect.size.x * 0.03, rect.size.y * 0.12),
		Vector2(rect.size.x * 0.94, rect.size.y * 0.76)
	)
	if safe.size.x < 54.0 or safe.size.y < 34.0:
		draw_rect(rect.grow(-2.0), Color("#103526"))
		return
	var table := Rect2(safe.position + Vector2(0, safe.size.y * 0.26), Vector2(safe.size.x, safe.size.y * 0.44))
	var felt := Rect2(table.position + Vector2(table.size.x * 0.06, table.size.y * 0.12), Vector2(table.size.x * 0.88, table.size.y * 0.66))
	draw_rect(Rect2(table.position + Vector2(table.size.x * 0.04, table.size.y * 0.76), Vector2(table.size.x * 0.92, table.size.y * 0.12)), Color(0.0, 0.0, 0.0, 0.30))
	draw_rect(table, Color("#0a342a"))
	draw_rect(table, Color(accent.r, accent.g, accent.b, 0.12 + pulse * 0.10), false, 2)
	draw_rect(felt, Color("#12724e"))
	draw_rect(felt, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.26), false, 1)
	for i in range(3):
		var zone := Rect2(felt.position + Vector2(felt.size.x * (0.12 + float(i) * 0.30), felt.size.y * 0.26), Vector2(felt.size.x * 0.20, felt.size.y * 0.38))
		var zone_color := C_CYAN if i == 0 else C_YELLOW if i == 1 else C_PINK
		draw_rect(zone, Color(zone_color.r, zone_color.g, zone_color.b, 0.18))
		draw_rect(zone, Color(zone_color.r, zone_color.g, zone_color.b, 0.42), false, 1)
	var shoe := Rect2(felt.position + Vector2(felt.size.x * 0.76, -felt.size.y * 0.32), Vector2(felt.size.x * 0.16, felt.size.y * 0.34))
	draw_rect(shoe, Color("#21111b"))
	draw_rect(Rect2(shoe.position + Vector2(3, 4), shoe.size - Vector2(8, 8)), Color("#f0ead5"))
	draw_rect(shoe, C_YELLOW, false, 1)
	var discard := Rect2(felt.position + Vector2(felt.size.x * 0.08, -felt.size.y * 0.26), Vector2(felt.size.x * 0.15, felt.size.y * 0.28))
	draw_rect(discard, Color("#090d15"))
	draw_rect(discard, C_CYAN, false, 1)
	for i in range(2):
		draw_rect(Rect2(discard.position + Vector2(5 + i * 6, 4 - i), Vector2(12, 16)), Color("#f5f1df"))
		draw_rect(Rect2(discard.position + Vector2(7 + i * 6, 7 - i), Vector2(8, 10)), C_PINK)
	_silhouette(safe.position + Vector2(safe.size.x * 0.50, safe.size.y * 0.26), 0.30, C_SHADOW)
	for i in range(4):
		var t := float(i) / 3.0
		var px := lerpf(safe.position.x + safe.size.x * 0.10, safe.position.x + safe.size.x * 0.90, t)
		_silhouette(Vector2(px, safe.position.y + safe.size.y * 0.92), 0.24, C_SHADOW)
	for i in range(3):
		var chip_pos := felt.position + Vector2(felt.size.x * (0.23 + float(i) * 0.28), felt.size.y * 0.78)
		draw_circle(chip_pos, maxf(2.0, safe.size.x * 0.030), _cycle_color(i * 31 + int(phase * 100.0)))
		draw_circle(chip_pos, maxf(1.0, safe.size.x * 0.015), Color("#f8f4dc"))
	var font := get_theme_default_font()
	var label_rect := Rect2(safe.position + Vector2(safe.size.x * 0.30, safe.size.y * 0.02), Vector2(safe.size.x * 0.40, safe.size.y * 0.16))
	draw_rect(label_rect, Color(0.0, 0.0, 0.0, 0.55))
	draw_string(font, label_rect.position + Vector2(2.0, label_rect.size.y * 0.72), _fit_draw_text("BACCARAT", font, 8, label_rect.size.x - 4.0), HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x - 4.0, 8, C_YELLOW)
	if selected:
		draw_rect(safe.grow(2.0), Color(C_WHITE.r, C_WHITE.g, C_WHITE.b, 0.70), false, 2)
	if disabled:
		draw_rect(safe, Color(0.0, 0.0, 0.0, 0.48))
		draw_line(safe.position + Vector2(safe.size.x * 0.12, safe.size.y * 0.24), safe.position + Vector2(safe.size.x * 0.88, safe.size.y * 0.76), C_SOFT, 3)


func _card_back(rect: Rect2) -> void:
	draw_rect(rect, C_SOFT)
	draw_rect(Rect2(rect.position + Vector2(3, 3), rect.size - Vector2(6, 6)), C_PINK)
	draw_rect(Rect2(rect.position + Vector2(8, 8), rect.size - Vector2(16, 16)), C_PURPLE)


func _neon_text(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	draw_string(font, pos + Vector2(2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color.r, color.g, color.b, 0.3))
	draw_string(font, pos + Vector2(-2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color.r, color.g, color.b, 0.3))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _cycle_color(seed: int) -> Color:
	var colors := [C_PINK, C_CYAN, C_TEAL, C_YELLOW, C_PURPLE_2, C_ORANGE]
	return colors[abs(seed) % colors.size()]
