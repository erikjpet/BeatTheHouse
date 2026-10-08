class_name PixelSceneCanvas
extends Control

const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")

# Draws and interacts with first-person venue scenes as hard-edged pixel art.
# It owns camera/focus animation, object hit regions, selection feedback, and the
# developer placement overlay, but consumes sealed room geometry from core.

signal object_hovered(object_id: String)
signal object_focused(object_id: String)
signal object_activated(object_id: String)
signal view_geometry_changed
signal developer_placement_lock_requested(request: Dictionary)
signal developer_placement_reset_requested(request: Dictionary)
signal developer_placement_promote_requested
signal developer_placement_refresh_requested
signal developer_placement_export_requested(request: Dictionary)
signal developer_layout_save_requested(request: Dictionary)
signal developer_slot_layer_requested(request: Dictionary)

const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const SmallScreenPolicyScript := preload("res://scripts/ui/small_screen_policy.gd")
const IconSpriteRendererScript := preload("res://scripts/ui/icon_sprite_renderer.gd")
const AttributeBadgeRowScript := preload("res://scripts/ui/attribute_badge_row.gd")
const DrunkDistortionOverlayScript := preload("res://scripts/ui/drunk_distortion_overlay.gd")
const HeatFeedbackVisualsScript := preload("res://scripts/ui/heat_feedback_visuals.gd")
const TableGameVisualsScript := preload("res://scripts/games/table_game_visuals.gd")
const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentObjectManifestScript := preload("res://scripts/core/environment_object_manifest.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")
const PersistencePathsScript := preload("res://scripts/core/persistence_paths.gd")
const CoinPusherRoomPropScript := preload("res://scripts/ui/game_props/coin_pusher_room_prop.gd")
const ScratchTicketRoomPropScript := preload("res://scripts/ui/game_props/scratch_ticket_room_prop.gd")
const CrapsRoomPropScript := preload("res://scripts/ui/game_props/craps_room_prop.gd")
const BarDiceRoomPropScript := preload("res://scripts/ui/game_props/bar_dice_room_prop.gd")
const SLOT_COLLECTION_FIELDS := ["fixed_slots", "event_slots", "scenario_slots", "exit_slots"]
const SLOT_FAMILIES := ["fixed", "event", "scenario", "exit"]
const SLOT_FILTER_OPTIONS := ["fixed", "event", "scenario", "exit", "all"]
const SLOT_DRAW_LAYERS := {"behind": -1, "standard": 0, "front": 1}
const DEVELOPER_PANEL_MARGIN := 8.0
const DEVELOPER_PANEL_MIN_WIDTH := 320.0
const DEVELOPER_PANEL_PREFERRED_WIDTH := 552.0
const DEVELOPER_PANEL_FIXED_HEIGHT := 404.0
const DEVELOPER_PANEL_RESTORE_MIN_WIDTH := 156.0
const DEVELOPER_PANEL_FONT_SIZE := 11
const DEVELOPER_PANEL_CONTROL_HEIGHT := 30.0
const DEVELOPER_PANEL_FILTER_MIN_WIDTH := 96.0
const DEVELOPER_PANEL_INFO_HEIGHT := 58.0
const DEVELOPER_ROUTE_COLLISION_EDGE_TOLERANCE := 1.01

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
const CONVERSATION_OVERLAY_CLEARANCE := 12.0
const CONVERSATION_RESERVED_FOCUS_PADDING := 4.0
const CONVERSATION_RESERVED_EDGE_THRESHOLD := 48.0
const OBJECT_LAYOUT_GAP := 8.0
const OBJECT_LAYOUT_MAX_OVERLAP_AREA := 0.01
const DEFAULT_OBJECT_VISUAL_MIN_SIZE := Vector2(72.0, 48.0)
const SAL_SHELF_VISUAL_MIN_SIZE := Vector2(44.0, 44.0)
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
const OBJECT_INFO_STATUS_ICON_SIZE := 12.0
const OBJECT_INFO_STATUS_ICON_GAP := 5.0
const OBJECT_INFO_BADGE_RAISE := 5.0
const OBJECT_INFO_ACTION_HEIGHT := 16.0
const OBJECT_INFO_ACTION_GAP := 5.0
const OBJECT_INFO_INLINE_ACTION_HEIGHT := 19.0
const OBJECT_INFO_INLINE_ACTION_DETAIL_HEIGHT := 11.0
const OBJECT_INFO_INLINE_ACTION_DETAIL_LINE_HEIGHT := 10.0
const OBJECT_INFO_INLINE_ACTION_DETAIL_MAX_LINES := 4
const OBJECT_INFO_INLINE_ACTION_GAP := 5.0
const OBJECT_INFO_INLINE_ACTION_MAX := 8
const OBJECT_INFO_BOTTOM_PADDING := 8.0
const OBJECT_INFO_ANIMATION_SPEED := 14.0
const OBJECT_INFO_RECT_SNAP_EPSILON := 0.25
const OBJECT_LABEL_MAX_WIDTH := 126.0
const OBJECT_LABEL_HEIGHT := 15.0
const OBJECT_LABEL_TWO_LINE_HEIGHT := 26.0
const OBJECT_LABEL_GAP := 2.0
const OBJECT_LABEL_MAX_OFFSET_STEPS := 2
const OBJECT_LABEL_FONT_SIZE := 10
const OBJECT_LABEL_TEXT_PADDING_X := 3.0
const OBJECT_LABEL_BASELINE_Y := 11.0
const OBJECT_LABEL_LINE_HEIGHT := 11.0
const OBJECT_LABEL_MAX_TETHER_GAP := OBJECT_LABEL_GAP + float(OBJECT_LABEL_MAX_OFFSET_STEPS) * (OBJECT_LABEL_LINE_HEIGHT + 2.0)
# Godot can deliver touch plus emulated mouse after a stalled frame.
const EMULATED_TOUCH_SUPPRESS_MS := 750
const EMULATED_TOUCH_SUPPRESS_DISTANCE := 18.0
const DRUNK_TIME_SCALE_MIN := 0.33
const SCENE_IDLE_ANIMATION_FPS := 60.0
const SCENE_IDLE_ANIMATION_INTERVAL_SEC := 1.0 / SCENE_IDLE_ANIMATION_FPS
const WEB_SCENE_IDLE_ANIMATION_FPS := 30.0
const WEB_GRAND_CASINO_IDLE_ANIMATION_FPS := 15.0
const DEVELOPER_DRAG_REDRAW_INTERVAL_MSEC := 33
const ITEM_ICON_TEXTURE_CACHE_LIMIT := 32
const SLOT_PROP_STATIC_LAYER_CACHE_LIMIT := 64
const CHARACTER_IDLE_PROFILE_CACHE_LIMIT := 768
const MAX_CONCURRENT_PERSON_TRANSITS := 8
const PERSON_TRANSIT_SPEED_PIXELS_PER_SEC := 82.0
const PERSON_TRANSIT_MIN_DURATION_SEC := 0.75
const PERSON_TRANSIT_MAX_DURATION_SEC := 8.0
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
const SCENE_SPARKLES_PAWN_SHOP := [Vector2(150, 84), Vector2(414, 118), Vector2(690, 154)]
const SCENARIO_CROWD_POINTS := [Vector2(82, 254), Vector2(219, 271), Vector2(356, 288), Vector2(493, 271), Vector2(630, 254), Vector2(767, 271), Vector2(164, 288), Vector2(301, 254), Vector2(438, 288), Vector2(575, 271)]
const SCENARIO_CROWD_COLOR := Color(0.02, 0.025, 0.05, 0.56)

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
var active_scene_objects_cache: Array = []
var behind_counter_scene_objects_cache: Array = []
var room_front_scene_objects_cache: Array = []
var room_top_scene_objects_cache: Array = []
var scene_object_cache_valid := false
var scene_has_live_actor_routes := false
var object_label_rect_cache: Dictionary = {}
var object_label_layout_stats: Dictionary = {}
var object_labels_and_borders_enabled := true
var draw_text_width_cache: Dictionary = {}
var fit_draw_text_cache: Dictionary = {}
var object_animation_phase_cache: Dictionary = {}
var character_idle_profile_cache: Dictionary = {}
var slot_prop_static_layer_cache: Dictionary = {}
var actor_route_started_at_cache: Dictionary = {}
var actor_position_receipt_cache: Dictionary = {}
var actor_position_route_room_key := ""
var actor_route_time := 0.0
var person_transits: Dictionary = {}
var person_transit_ids: Array[String] = []
var settled_person_objects_cache: Dictionary = {}
var person_transit_room_key := ""
var drunk_distortion_overlay: DrunkDistortionOverlay
var drunk_effect_mode: String = "distortion"
var last_mouse_press_msec: int = -100000
var last_mouse_press_position: Vector2 = Vector2(-100000.0, -100000.0)
var info_card_visual_rect: Rect2 = Rect2()
var info_card_visual_object_id: String = ""
var info_card_animating := false
var selected_info_badge_hit_entries: Array = []
var selected_info_badge_hover_text := ""
var selected_info_badge_hover_local_position := Vector2.ZERO
var reduce_motion := false
var small_screen_mode := false
var scene_idle_animation_redraw_accumulator := 0.0
var scene_idle_animation_redraw_count := 0
var last_touch_press_msec: int = -100000
var last_touch_press_position: Vector2 = Vector2(-100000.0, -100000.0)
var reserved_overlay_global_rect := Rect2()
var overlay_repositioned_object_ids: Array[String] = []
var environment_activity_paused := false
var scenario_presentation: Dictionary = {}
var scenario_palette_overlay := Color.TRANSPARENT
var scenario_crowd_count := 0
var scenario_signage := ""
var selected_info_action_index := 0
# Mutable draw geometry is allocated once per canvas and rewritten in place.
# Building PackedVector2Array values inside _draw_* ran at idle animation rate.
var _scenario_route_arrow_points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _scenario_vehicle_canopy_points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _scenario_hazard_fill_points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _scenario_hazard_outline_points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var developer_placement_mode := false
var developer_placement_dragging := false
var developer_drag_redraw_pending := false
var developer_drag_last_redraw_msec := -100000
var developer_placement_drag_offset := Vector2.ZERO
var developer_placement_original_rect := Rect2()
var developer_placement_pending_rect := Rect2()
var developer_placement_valid := false
var developer_placement_surface_id := ""
var developer_placement_overlap_ids: Array[String] = []
var developer_placement_surface_map_cache: Dictionary = {}
var developer_placement_surface_map_cache_valid := false
var room_surface_slots_by_id_cache: Dictionary = {}
var room_surface_counters_by_id_cache: Dictionary = {}
var room_foreground_counters_cache: Array = []
var room_surface_draw_cache_valid := false
var developer_placement_panel: PanelContainer
var developer_placement_panel_shell: VBoxContainer
var developer_placement_panel_header: HBoxContainer
var developer_placement_content: MarginContainer
var developer_placement_stack: VBoxContainer
var developer_placement_minimize_button: Button
var developer_placement_restore_button: Button
var developer_placement_panel_minimized := false
var developer_placement_label: Label
var developer_placement_lock_button: Button
var developer_placement_reset_button: Button
var developer_placement_export_button: Button
var developer_placement_promote_button: Button
var developer_layout_save_button: Button
var developer_layout_save_next_button: Button
var developer_slot_placement_mode := false
var developer_slot_selected_id := ""
var developer_slot_dragging := false
var developer_slot_drag_offset := Vector2.ZERO
var developer_slot_original_rect := Rect2()
var developer_slot_pending_rect := Rect2()
var developer_slot_pending_position := Vector2.ZERO
var developer_slot_valid := false
var developer_slot_overlap_ids: Array[String] = []
var developer_slots_cache: Array = []
var developer_available_slots_cache: Array = []
var developer_visible_slots_cache: Array = []
var developer_slots_by_id_cache: Dictionary = {}
var developer_slot_rects_by_id_cache: Dictionary = {}
var developer_slot_positions_by_id_cache: Dictionary = {}
var developer_slots_cache_valid := false
var developer_available_slots_cache_valid := false
var developer_visible_slots_cache_valid := false
var developer_slot_occupants_by_id_cache: Dictionary = {}
var developer_required_slot_ids_cache: Dictionary = {}
var developer_slot_overlay_rows_cache: Array = []
var developer_slot_overlay_cache_valid := false
var developer_slot_overlap_summary_cache: Dictionary = {}
var developer_slot_overlap_summary_cache_valid := false
var developer_slot_scene_object_baseline: Array = []
var developer_slot_scene_object_baseline_valid := false
var developer_slot_filter_row: HBoxContainer
var developer_slot_filter_buttons: Dictionary = {}
var developer_slot_family_button_group: ButtonGroup
var developer_slot_visibility_row: HBoxContainer
var developer_slot_show_empty_button: CheckBox
var developer_slot_show_reserves_button: CheckBox
var developer_slot_edit_shared_button: CheckBox
var developer_slot_context_label: Label
var developer_slot_layer_row: HBoxContainer
var developer_slot_layer_buttons: Dictionary = {}
var developer_slot_layer_button_group: ButtonGroup
var developer_slot_show_empty_capacity := true
var developer_slot_show_runtime_reserves := true
var developer_slot_edit_shared_in_scenario := false
var developer_slot_hovered_id := ""
var developer_slot_context_change_locking := false
var developer_placement_panel_layout_queued := false
var developer_slot_review_context_key := ""
var developer_slot_reviewed_families: Dictionary = {}
var scene_object_cache_rebuild_count := 0
var developer_slot_cache_rebuild_count := 0
var developer_placement_panel_update_count := 0
var developer_slot_overlay_cache_rebuild_count := 0
var developer_slot_overlap_audit_count := 0
var object_label_layout_rebuild_count := 0
var environment_snapshot_render_generation := 0
var developer_placement_authority_dirty := false
var developer_slot_family_filters := {
	"fixed": true,
	"event": false,
	"scenario": false,
	"exit": false,
	"all": false,
}


func _ready() -> void:
	# Animation liveness is owned by this canvas. Pointer input may request extra
	# redraws for hover state, but must never be the heartbeat for room motion.
	_arm_animation_heartbeat()
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	_ensure_drunk_distortion_overlay()
	_ensure_developer_placement_panel()


func set_developer_placement_mode(enabled: bool) -> void:
	if developer_placement_mode == enabled:
		return
	if enabled and developer_slot_placement_mode:
		_finish_developer_slot_placement_edit()
		developer_slot_placement_mode = false
		developer_slot_selected_id = ""
		_restore_developer_slot_scene_objects()
	if not enabled:
		_finish_developer_placement_edit()
	developer_placement_mode = enabled
	_ensure_developer_placement_panel()
	_sync_developer_placement_panel_visibility()
	_update_developer_placement_panel()
	_invalidate_camera_target()
	_update_camera_target_if_needed()
	queue_redraw()
	if not enabled:
		_flush_deferred_developer_placement_authority()


func set_developer_slot_placement_mode(enabled: bool) -> void:
	if developer_slot_placement_mode == enabled:
		return
	if enabled and developer_placement_mode:
		clear_developer_placement_preview()
		developer_placement_mode = false
	if not enabled:
		_finish_developer_slot_placement_edit()
		developer_slot_selected_id = ""
	developer_slot_placement_mode = enabled
	_invalidate_developer_placement_geometry_caches()
	if developer_slot_filter_row != null:
		developer_slot_filter_row.visible = enabled
	if developer_slot_visibility_row != null:
		developer_slot_visibility_row.visible = enabled
	if developer_slot_context_label != null:
		developer_slot_context_label.visible = enabled
	if developer_slot_layer_row != null:
		developer_slot_layer_row.visible = enabled
	if enabled:
		# A placement pass must expose every authored coordinate by default. The
		# owner can still hide capacity temporarily, but a newly opened context
		# never looks complete while silently concealing positions.
		developer_slot_show_empty_capacity = true
		developer_slot_show_runtime_reserves = true
		developer_slot_edit_shared_in_scenario = false
		_capture_developer_slot_scene_object_baseline()
	else:
		developer_slot_hovered_id = ""
		_restore_developer_slot_scene_objects()
	_ensure_developer_placement_panel()
	_configure_developer_slot_context(enabled)
	_sync_developer_placement_panel_visibility()
	_apply_authoring_slot_positions_to_scene_objects()
	_update_developer_placement_panel()
	_invalidate_camera_target()
	_update_camera_target_if_needed()
	queue_redraw()
	if not enabled:
		_flush_deferred_developer_placement_authority()


func developer_placement_snapshot() -> Dictionary:
	return {
		"enabled": developer_placement_mode,
		"panel_minimized": developer_placement_panel_minimized,
		"selected_object_id": selected_object_id,
		"dragging": developer_placement_dragging,
		"pending": developer_placement_pending_rect.has_area(),
		"valid": developer_placement_valid,
		"surface_id": developer_placement_surface_id,
		"overlap_ids": developer_placement_overlap_ids.duplicate(),
		"request": _developer_placement_request(),
	}


func developer_slot_placement_snapshot() -> Dictionary:
	var review_status := _developer_slot_review_status()
	return {
		"enabled": developer_slot_placement_mode,
		"panel_minimized": developer_placement_panel_minimized,
		"selected_slot_id": developer_slot_selected_id,
		"dragging": developer_slot_dragging,
		"pending": developer_slot_pending_rect.has_area(),
		"valid": developer_slot_valid,
		"overlap_ids": developer_slot_overlap_ids.duplicate(),
		"visible_slot_count": _developer_slots().size(),
		"total_slot_count": _developer_slots(true).size(),
		"family_filters": developer_slot_family_filters.duplicate(true),
		"active_family": _developer_slot_active_family(),
		"show_empty_capacity": developer_slot_show_empty_capacity,
		"show_runtime_reserves": developer_slot_show_runtime_reserves,
		"edit_shared_in_scenario": developer_slot_edit_shared_in_scenario,
		"hovered_slot_id": developer_slot_hovered_id,
		"preview_context": _developer_slot_preview_context(),
		"placement_progress": _copy_dictionary(foundation_snapshot.get("developer_placement_progress", {})),
		"required_review_families": review_status.get("required", []).duplicate(),
		"reviewed_families": review_status.get("reviewed", []).duplicate(),
		"missing_review_families": review_status.get("missing", []).duplicate(),
		"review_ready": bool(review_status.get("ready", false)),
		"marker_label_ids": _developer_slot_label_ids(),
		"overlap_summary": _developer_slot_overlap_summary(),
		"request": _developer_slot_placement_request(),
	}


func set_developer_slot_family_visible(family: String, visible: bool) -> void:
	var normalized_family := family.strip_edges().to_lower()
	if normalized_family not in SLOT_FILTER_OPTIONS:
		return
	# Scenario slots are meaningful only while an exact scenario owns the current
	# room/layer. Shared runtime reserves remain in the placement map for delivery
	# and chain binding, but they are not base-room authoring choices.
	if visible and normalized_family != "all" and not _developer_slot_family_available(normalized_family):
		return
	# Families are tabs, not accumulating checkboxes. Only one lifecycle family
	# is presented at a time so a room never opens as a wall of every possible
	# slot. The active tab cannot be unpressed without selecting another one.
	if not visible and bool(developer_slot_family_filters.get(normalized_family, false)):
		return
	if visible:
		_ensure_developer_slot_review_context()
		if normalized_family == "all":
			for family_value in SLOT_FAMILIES:
				var reviewed_family := str(family_value)
				if _developer_slot_family_available(reviewed_family):
					developer_slot_reviewed_families[reviewed_family] = true
		else:
			developer_slot_reviewed_families[normalized_family] = true
		for family_value in SLOT_FAMILIES:
			var candidate_family := str(family_value)
			developer_slot_family_filters[candidate_family] = normalized_family == "all" \
				and _developer_slot_family_available(candidate_family) \
				or candidate_family == normalized_family
		developer_slot_family_filters["all"] = normalized_family == "all"
		# Choosing a shared family is an explicit request to edit the shared room,
		# even while a scenario is previewed. Keep the warning toggle synchronized
		# instead of leaving the selected markers visible but immovable.
		if _developer_slot_has_active_scenario():
			set_developer_slot_edit_shared_in_scenario(normalized_family != "scenario")
	for family_value in SLOT_FILTER_OPTIONS:
		var candidate_family := str(family_value)
		var button_value: Variant = developer_slot_filter_buttons.get(candidate_family)
		if button_value is BaseButton:
			(button_value as BaseButton).set_pressed_no_signal(bool(developer_slot_family_filters.get(candidate_family, false)))
	_invalidate_developer_slot_derived_caches()
	var selected := _developer_slot(developer_slot_selected_id)
	if not selected.is_empty() and not _developer_slot_visible_in_preview(selected):
		_finish_developer_slot_placement_edit()
		developer_slot_selected_id = ""
	developer_slot_hovered_id = ""
	_update_developer_placement_panel()
	queue_redraw()


func set_developer_slot_show_empty_capacity(visible: bool) -> void:
	developer_slot_show_empty_capacity = visible
	_invalidate_developer_slot_derived_caches()
	if developer_slot_show_empty_button != null:
		developer_slot_show_empty_button.set_pressed_no_signal(visible)
	_prune_hidden_developer_slot_selection()
	_update_developer_placement_panel()
	queue_redraw()


func set_developer_slot_show_runtime_reserves(visible: bool) -> void:
	developer_slot_show_runtime_reserves = visible
	_invalidate_developer_slot_derived_caches()
	if developer_slot_show_reserves_button != null:
		developer_slot_show_reserves_button.set_pressed_no_signal(visible)
	_prune_hidden_developer_slot_selection()
	_update_developer_placement_panel()
	queue_redraw()


func set_developer_slot_edit_shared_in_scenario(enabled: bool) -> void:
	if not _developer_slot_has_active_scenario():
		enabled = false
	if developer_slot_edit_shared_in_scenario == enabled:
		return
	var selected := _developer_slot(developer_slot_selected_id)
	if not selected.is_empty() and _developer_slot_scope(selected) == "room_shared":
		_finish_developer_slot_placement_edit()
	developer_slot_edit_shared_in_scenario = enabled
	_invalidate_developer_slot_derived_caches()
	if developer_slot_edit_shared_button != null:
		developer_slot_edit_shared_button.set_pressed_no_signal(enabled)
	_update_developer_placement_panel()
	queue_redraw()


func _configure_developer_slot_context(reset_family: bool) -> void:
	var exact_scenario := _developer_slot_has_active_scenario()
	if not exact_scenario and bool(developer_slot_family_filters.get("scenario", false)):
		# A same-canvas transition from a scenario layout to its base room must not
		# leave the now-unavailable Scenario tab selected.
		reset_family = true
	if reset_family:
		# Every newly opened layout starts as a complete review surface. Filters
		# are a temporary convenience inside one context and must not silently
		# carry hidden authored positions into Load Next Missing.
		developer_slot_show_empty_capacity = true
		developer_slot_show_runtime_reserves = true
		developer_slot_edit_shared_in_scenario = false
	elif not exact_scenario:
		developer_slot_edit_shared_in_scenario = false
	if developer_slot_show_empty_button != null:
		developer_slot_show_empty_button.set_pressed_no_signal(developer_slot_show_empty_capacity)
	if developer_slot_show_reserves_button != null:
		developer_slot_show_reserves_button.set_pressed_no_signal(developer_slot_show_runtime_reserves)
	if developer_slot_edit_shared_button != null:
		developer_slot_edit_shared_button.visible = developer_slot_placement_mode and exact_scenario
		developer_slot_edit_shared_button.set_pressed_no_signal(developer_slot_edit_shared_in_scenario)
	for family_value in SLOT_FILTER_OPTIONS:
		var family := str(family_value)
		var button_value: Variant = developer_slot_filter_buttons.get(family)
		if button_value is BaseButton:
			var available := family == "all" or _developer_slot_family_available(family)
			(button_value as BaseButton).visible = available
			(button_value as BaseButton).disabled = not available
	if not reset_family:
		return
	var preferred_family := "scenario" if exact_scenario else "fixed"
	for family_value in SLOT_FAMILIES:
		var family := str(family_value)
		developer_slot_family_filters[family] = family == preferred_family
		var button_value: Variant = developer_slot_filter_buttons.get(family)
		if button_value is BaseButton:
			(button_value as BaseButton).set_pressed_no_signal(family == preferred_family)
	developer_slot_family_filters["all"] = false
	var all_button_value: Variant = developer_slot_filter_buttons.get("all")
	if all_button_value is BaseButton:
		(all_button_value as BaseButton).set_pressed_no_signal(false)
	developer_slot_selected_id = ""
	developer_slot_hovered_id = ""
	developer_slot_review_context_key = _developer_slot_snapshot_context_key(foundation_snapshot)
	developer_slot_reviewed_families.clear()
	developer_slot_reviewed_families[preferred_family] = true
	_invalidate_developer_slot_derived_caches()


func _ensure_developer_slot_review_context() -> void:
	var context_key := _developer_slot_snapshot_context_key(foundation_snapshot)
	if context_key == developer_slot_review_context_key:
		return
	developer_slot_review_context_key = context_key
	developer_slot_reviewed_families.clear()


func _developer_slot_required_review_families() -> Array[String]:
	var required: Array[String] = []
	if _developer_slot_has_active_scenario():
		required.append("scenario")
		return required
	for family_value in SLOT_FAMILIES:
		var family := str(family_value)
		if int(_developer_slot_family_counts(family).get("total", 0)) > 0:
			required.append(family)
	return required


func _developer_slot_review_status() -> Dictionary:
	_ensure_developer_slot_review_context()
	var required := _developer_slot_required_review_families()
	var reviewed: Array[String] = []
	var missing: Array[String] = []
	for family in required:
		if bool(developer_slot_reviewed_families.get(family, false)):
			reviewed.append(family)
		else:
			missing.append(family)
	return {
		"required": required,
		"reviewed": reviewed,
		"missing": missing,
		"ready": missing.is_empty(),
	}


func _developer_slot_has_active_scenario() -> bool:
	return not EnvironmentPlacementScript.active_scenario_id(foundation_snapshot).is_empty()


func _developer_slot_family_available(family: String) -> bool:
	var normalized_family := family.strip_edges().to_lower()
	return normalized_family in SLOT_FAMILIES \
		and (normalized_family != "scenario" or _developer_slot_has_active_scenario())


func _developer_slot_scope(slot: Dictionary) -> String:
	return "scenario_local" if bool(slot.get("scenario_instance", false)) else "room_shared"


func _developer_slot_is_editable(slot: Dictionary) -> bool:
	if slot.is_empty() or not _developer_slot_family_available(_developer_slot_family(slot)):
		return false
	if _developer_slot_scope(slot) == "scenario_local":
		return not slot.is_empty()
	return not _developer_slot_has_active_scenario() or developer_slot_edit_shared_in_scenario


func _developer_slot_hidden_detail_count() -> int:
	var result := 0
	for slot_value in _developer_slots(true):
		if not _developer_slot_visible_by_detail(slot_value as Dictionary):
			result += 1
	return result


func _prune_hidden_developer_slot_selection() -> void:
	var selected := _developer_slot(developer_slot_selected_id)
	if not selected.is_empty() and not _developer_slot_visible_in_preview(selected):
		_finish_developer_slot_placement_edit()
		developer_slot_selected_id = ""
	var hovered := _developer_slot(developer_slot_hovered_id)
	if not hovered.is_empty() and not _developer_slot_visible_in_preview(hovered):
		developer_slot_hovered_id = ""


func clear_developer_placement_preview(refresh_panel: bool = true, redraw: bool = true) -> void:
	developer_placement_dragging = false
	developer_drag_redraw_pending = false
	developer_placement_original_rect = Rect2()
	developer_placement_pending_rect = Rect2()
	developer_placement_valid = false
	developer_placement_surface_id = ""
	developer_placement_overlap_ids.clear()
	if refresh_panel:
		_update_developer_placement_panel()
	if redraw:
		queue_redraw()


func clear_developer_slot_placement_preview(refresh_panel: bool = true, redraw: bool = true) -> void:
	developer_slot_dragging = false
	developer_drag_redraw_pending = false
	developer_slot_drag_offset = Vector2.ZERO
	developer_slot_original_rect = Rect2()
	developer_slot_pending_rect = Rect2()
	developer_slot_pending_position = Vector2.ZERO
	developer_slot_valid = false
	developer_slot_overlap_ids.clear()
	if refresh_panel:
		_update_developer_placement_panel()
	if redraw:
		queue_redraw()


func _flush_deferred_developer_placement_authority() -> void:
	if not developer_placement_authority_dirty:
		return
	developer_placement_refresh_requested.emit()


func acknowledge_developer_placement_authority_refresh() -> void:
	developer_placement_authority_dirty = false


func _invalidate_developer_placement_geometry_caches() -> void:
	# Effective surface maps are shared immutable cache values. Drop this canvas's
	# reference instead of clearing the dictionary owned by EnvironmentPlacement.
	developer_placement_surface_map_cache = {}
	developer_placement_surface_map_cache_valid = false
	room_surface_slots_by_id_cache.clear()
	room_surface_counters_by_id_cache.clear()
	room_foreground_counters_cache = []
	room_surface_draw_cache_valid = false
	developer_slots_cache = []
	developer_available_slots_cache = []
	developer_visible_slots_cache = []
	developer_slots_by_id_cache.clear()
	developer_slot_rects_by_id_cache.clear()
	developer_slot_positions_by_id_cache.clear()
	developer_slots_cache_valid = false
	developer_available_slots_cache_valid = false
	_invalidate_developer_slot_derived_caches()


func _invalidate_developer_slot_derived_caches() -> void:
	developer_available_slots_cache = []
	developer_available_slots_cache_valid = false
	developer_visible_slots_cache = []
	developer_visible_slots_cache_valid = false
	developer_slot_overlay_rows_cache = []
	developer_slot_overlay_cache_valid = false
	developer_slot_overlap_summary_cache.clear()
	developer_slot_overlap_summary_cache_valid = false


func _ensure_developer_placement_panel() -> void:
	if developer_placement_panel != null:
		return
	developer_placement_panel = PanelContainer.new()
	developer_placement_panel.name = "DeveloperPlacementPanel"
	developer_placement_panel.position = Vector2.ONE * DEVELOPER_PANEL_MARGIN
	developer_placement_panel.custom_minimum_size = Vector2.ZERO
	developer_placement_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	developer_placement_panel.clip_contents = true
	developer_placement_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#090b18f2")
	panel_style.border_color = Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.82)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(4)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		panel_style.set_content_margin(side, 8.0)
	developer_placement_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(developer_placement_panel)

	developer_placement_restore_button = Button.new()
	developer_placement_restore_button.name = "RestoreDeveloperPlacementPanel"
	developer_placement_restore_button.text = "Placement Menu"
	developer_placement_restore_button.custom_minimum_size = Vector2(DEVELOPER_PANEL_RESTORE_MIN_WIDTH, DEVELOPER_PANEL_CONTROL_HEIGHT)
	developer_placement_restore_button.tooltip_text = "Restore the placement menu. (F2)"
	developer_placement_restore_button.visible = false
	developer_placement_restore_button.pressed.connect(_restore_developer_placement_panel)
	add_child(developer_placement_restore_button)

	developer_placement_panel_shell = VBoxContainer.new()
	developer_placement_panel_shell.name = "DeveloperPlacementPanelShell"
	developer_placement_panel_shell.mouse_filter = Control.MOUSE_FILTER_PASS
	developer_placement_panel_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	developer_placement_panel_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	developer_placement_panel_shell.add_theme_constant_override("separation", 4)
	developer_placement_panel.add_child(developer_placement_panel_shell)

	developer_placement_panel_header = HBoxContainer.new()
	developer_placement_panel_header.name = "DeveloperPlacementPanelHeader"
	developer_placement_panel_header.mouse_filter = Control.MOUSE_FILTER_PASS
	developer_placement_panel_header.custom_minimum_size.y = DEVELOPER_PANEL_CONTROL_HEIGHT
	developer_placement_panel_header.add_theme_constant_override("separation", 6)
	developer_placement_panel_shell.add_child(developer_placement_panel_header)
	var panel_title := Label.new()
	panel_title.name = "DeveloperPlacementPanelTitle"
	panel_title.text = "SLOT PLACEMENT"
	panel_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_title.add_theme_color_override("font_color", C_CYAN)
	developer_placement_panel_header.add_child(panel_title)
	developer_placement_minimize_button = Button.new()
	developer_placement_minimize_button.name = "MinimizeDeveloperPlacementPanel"
	developer_placement_minimize_button.text = "Hide (F2)"
	developer_placement_minimize_button.custom_minimum_size = Vector2(112.0, DEVELOPER_PANEL_CONTROL_HEIGHT)
	developer_placement_minimize_button.tooltip_text = "Hide this menu so objects underneath it can be selected. (F2 restores it.)"
	developer_placement_minimize_button.pressed.connect(_minimize_developer_placement_panel)
	developer_placement_panel_header.add_child(developer_placement_minimize_button)

	developer_placement_content = MarginContainer.new()
	developer_placement_content.name = "DeveloperPlacementContent"
	developer_placement_content.mouse_filter = Control.MOUSE_FILTER_PASS
	developer_placement_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	developer_placement_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	developer_placement_panel_shell.add_child(developer_placement_content)

	developer_placement_stack = VBoxContainer.new()
	developer_placement_stack.name = "DeveloperPlacementStack"
	developer_placement_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	developer_placement_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	developer_placement_stack.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	developer_placement_stack.add_theme_constant_override("separation", 4)
	developer_placement_content.add_child(developer_placement_stack)
	var stack := developer_placement_stack

	developer_slot_filter_row = HBoxContainer.new()
	developer_slot_filter_row.name = "SlotFamilyFilters"
	developer_slot_filter_row.custom_minimum_size.y = DEVELOPER_PANEL_CONTROL_HEIGHT
	developer_slot_filter_row.add_theme_constant_override("separation", 4)
	developer_slot_filter_row.visible = developer_slot_placement_mode
	stack.add_child(developer_slot_filter_row)
	developer_slot_family_button_group = ButtonGroup.new()
	developer_slot_family_button_group.allow_unpress = false
	for family_value in SLOT_FILTER_OPTIONS:
		var family := str(family_value)
		var button := Button.new()
		button.name = "%sSlots" % family.capitalize()
		button.text = "All" if family == "all" else family.capitalize()
		button.toggle_mode = true
		button.button_group = developer_slot_family_button_group
		button.button_pressed = bool(developer_slot_family_filters.get(family, true))
		button.custom_minimum_size = Vector2(DEVELOPER_PANEL_FILTER_MIN_WIDTH, DEVELOPER_PANEL_CONTROL_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_stretch_ratio = 1.0
		button.tooltip_text = "Show every available slot family together." if family == "all" else "Show only %s.* authoring slots." % family
		button.add_theme_color_override("font_color", _developer_slot_family_color(family))
		button.toggled.connect(_on_developer_slot_family_filter_toggled.bind(family))
		developer_slot_filter_buttons[family] = button
		developer_slot_filter_row.add_child(button)

	developer_slot_visibility_row = HBoxContainer.new()
	developer_slot_visibility_row.name = "SlotVisibilityFilters"
	developer_slot_visibility_row.custom_minimum_size.y = DEVELOPER_PANEL_CONTROL_HEIGHT
	developer_slot_visibility_row.add_theme_constant_override("separation", 4)
	developer_slot_visibility_row.visible = developer_slot_placement_mode
	stack.add_child(developer_slot_visibility_row)
	developer_slot_show_empty_button = CheckBox.new()
	developer_slot_show_empty_button.name = "ShowEmptyCapacity"
	developer_slot_show_empty_button.text = "Empty slots"
	developer_slot_show_empty_button.custom_minimum_size = Vector2(0.0, DEVELOPER_PANEL_CONTROL_HEIGHT)
	developer_slot_show_empty_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	developer_slot_show_empty_button.size_flags_stretch_ratio = 1.0
	developer_slot_show_empty_button.button_pressed = developer_slot_show_empty_capacity
	developer_slot_show_empty_button.tooltip_text = "Show unused capacity in the active family. Required missing positions stay visible."
	developer_slot_show_empty_button.toggled.connect(set_developer_slot_show_empty_capacity)
	developer_slot_visibility_row.add_child(developer_slot_show_empty_button)
	developer_slot_show_reserves_button = CheckBox.new()
	developer_slot_show_reserves_button.name = "ShowRuntimeReserves"
	developer_slot_show_reserves_button.text = "Reserves"
	developer_slot_show_reserves_button.custom_minimum_size = Vector2(0.0, DEVELOPER_PANEL_CONTROL_HEIGHT)
	developer_slot_show_reserves_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	developer_slot_show_reserves_button.size_flags_stretch_ratio = 1.0
	developer_slot_show_reserves_button.button_pressed = developer_slot_show_runtime_reserves
	developer_slot_show_reserves_button.tooltip_text = "Show positions reserved for delivery and other runtime-injected content."
	developer_slot_show_reserves_button.toggled.connect(set_developer_slot_show_runtime_reserves)
	developer_slot_visibility_row.add_child(developer_slot_show_reserves_button)
	developer_slot_edit_shared_button = CheckBox.new()
	developer_slot_edit_shared_button.name = "EditSharedRoomSlots"
	developer_slot_edit_shared_button.text = "Shared room"
	developer_slot_edit_shared_button.custom_minimum_size = Vector2(0.0, DEVELOPER_PANEL_CONTROL_HEIGHT)
	developer_slot_edit_shared_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	developer_slot_edit_shared_button.size_flags_stretch_ratio = 1.0
	developer_slot_edit_shared_button.button_pressed = developer_slot_edit_shared_in_scenario
	developer_slot_edit_shared_button.tooltip_text = "Exact scenarios normally lock room-shared fixed, event, reserve, and exit positions. Enable only to deliberately change the base room; doing so resets completion for that room and all of its scenarios."
	developer_slot_edit_shared_button.toggled.connect(set_developer_slot_edit_shared_in_scenario)
	developer_slot_edit_shared_button.visible = developer_slot_placement_mode and _developer_slot_has_active_scenario()
	developer_slot_visibility_row.add_child(developer_slot_edit_shared_button)

	developer_slot_context_label = Label.new()
	developer_slot_context_label.name = "SlotPreviewContext"
	developer_slot_context_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	developer_slot_context_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	developer_slot_context_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	developer_slot_context_label.custom_minimum_size.y = DEVELOPER_PANEL_INFO_HEIGHT
	developer_slot_context_label.max_lines_visible = 4
	developer_slot_context_label.visible = developer_slot_placement_mode
	stack.add_child(developer_slot_context_label)

	developer_placement_label = Label.new()
	developer_placement_label.name = "PlacementSelectionSummary"
	developer_placement_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	developer_placement_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	developer_placement_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	developer_placement_label.custom_minimum_size.y = DEVELOPER_PANEL_INFO_HEIGHT
	developer_placement_label.max_lines_visible = 4
	developer_placement_label.text = "PLACEMENT\nNo marker selected\nDrag a marker to reposition it.\nLock saves the pending position."
	stack.add_child(developer_placement_label)

	developer_slot_layer_row = HBoxContainer.new()
	developer_slot_layer_row.name = "SlotDrawLayers"
	developer_slot_layer_row.custom_minimum_size.y = DEVELOPER_PANEL_CONTROL_HEIGHT
	developer_slot_layer_row.add_theme_constant_override("separation", 4)
	developer_slot_layer_row.tooltip_text = "Choose whether occupants of this slot draw behind, within, or in front of normal room objects."
	developer_slot_layer_row.visible = developer_slot_placement_mode
	stack.add_child(developer_slot_layer_row)
	developer_slot_layer_button_group = ButtonGroup.new()
	developer_slot_layer_button_group.allow_unpress = false
	for layer_name_value in ["behind", "standard", "front"]:
		var layer_name := str(layer_name_value)
		var layer_button := Button.new()
		layer_button.name = "%sDrawLayer" % layer_name.capitalize()
		layer_button.text = layer_name.capitalize()
		layer_button.toggle_mode = true
		layer_button.button_group = developer_slot_layer_button_group
		layer_button.custom_minimum_size = Vector2(0.0, DEVELOPER_PANEL_CONTROL_HEIGHT)
		layer_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		layer_button.size_flags_stretch_ratio = 1.0
		layer_button.disabled = true
		layer_button.tooltip_text = "%s draw layer (%d). Higher layers appear above lower layers." % [layer_name.capitalize(), int(SLOT_DRAW_LAYERS.get(layer_name, 0))]
		layer_button.toggled.connect(_on_developer_slot_layer_toggled.bind(layer_name))
		developer_slot_layer_buttons[layer_name] = layer_button
		developer_slot_layer_row.add_child(layer_button)

	var layout_actions := HBoxContainer.new()
	layout_actions.name = "LayoutActions"
	layout_actions.custom_minimum_size.y = DEVELOPER_PANEL_CONTROL_HEIGHT
	layout_actions.add_theme_constant_override("separation", 4)
	stack.add_child(layout_actions)
	developer_layout_save_next_button = Button.new()
	developer_layout_save_next_button.name = "SaveAndLoadNextLayout"
	developer_layout_save_next_button.text = "Save & Load Next Missing"
	developer_layout_save_next_button.custom_minimum_size = Vector2(0.0, DEVELOPER_PANEL_CONTROL_HEIGHT)
	developer_layout_save_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	developer_layout_save_next_button.size_flags_stretch_ratio = 1.0
	developer_layout_save_next_button.tooltip_text = "Save this reviewed layout, then immediately generate the next missing environment/scenario layout."
	developer_layout_save_next_button.visible = developer_slot_placement_mode
	developer_layout_save_next_button.pressed.connect(_save_and_load_next_developer_slot_layout)
	layout_actions.add_child(developer_layout_save_next_button)
	developer_layout_save_button = Button.new()
	developer_layout_save_button.name = "SaveCurrentLayout"
	developer_layout_save_button.text = "Save Current Layout"
	developer_layout_save_button.custom_minimum_size = Vector2(0.0, DEVELOPER_PANEL_CONTROL_HEIGHT)
	developer_layout_save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	developer_layout_save_button.size_flags_stretch_ratio = 1.0
	developer_layout_save_button.tooltip_text = "Save every active slot position for this exact environment and scenario layout, then update completion coverage."
	developer_layout_save_button.visible = developer_slot_placement_mode
	developer_layout_save_button.pressed.connect(_save_current_developer_slot_layout)
	layout_actions.add_child(developer_layout_save_button)

	var actions := HBoxContainer.new()
	actions.name = "PlacementActions"
	actions.custom_minimum_size.y = DEVELOPER_PANEL_CONTROL_HEIGHT
	actions.add_theme_constant_override("separation", 4)
	stack.add_child(actions)
	developer_placement_lock_button = Button.new()
	developer_placement_lock_button.text = "Lock"
	developer_placement_lock_button.custom_minimum_size = Vector2(0.0, DEVELOPER_PANEL_CONTROL_HEIGHT)
	developer_placement_lock_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	developer_placement_lock_button.size_flags_stretch_ratio = 1.0
	developer_placement_lock_button.tooltip_text = "Save the current object or four-family slot position."
	developer_placement_lock_button.pressed.connect(_lock_active_developer_placement)
	actions.add_child(developer_placement_lock_button)
	var cancel_button := Button.new()
	cancel_button.name = "CancelPlacement"
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(0.0, DEVELOPER_PANEL_CONTROL_HEIGHT)
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.size_flags_stretch_ratio = 1.0
	cancel_button.pressed.connect(_cancel_active_developer_placement_preview)
	actions.add_child(cancel_button)
	developer_placement_reset_button = Button.new()
	developer_placement_reset_button.text = "Reset"
	developer_placement_reset_button.custom_minimum_size = Vector2(0.0, DEVELOPER_PANEL_CONTROL_HEIGHT)
	developer_placement_reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	developer_placement_reset_button.size_flags_stretch_ratio = 1.0
	developer_placement_reset_button.tooltip_text = "Remove the local override for this room/object pair."
	developer_placement_reset_button.pressed.connect(_reset_active_developer_placement)
	actions.add_child(developer_placement_reset_button)
	var project_actions := HBoxContainer.new()
	project_actions.name = "ProjectActions"
	project_actions.mouse_filter = Control.MOUSE_FILTER_PASS
	project_actions.custom_minimum_size.y = DEVELOPER_PANEL_CONTROL_HEIGHT
	project_actions.add_theme_constant_override("separation", 4)
	stack.add_child(project_actions)
	developer_placement_promote_button = Button.new()
	developer_placement_promote_button.name = "SavePlacementToProject"
	developer_placement_promote_button.text = "Save to Project"
	developer_placement_promote_button.custom_minimum_size = Vector2(0.0, DEVELOPER_PANEL_CONTROL_HEIGHT)
	developer_placement_promote_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	developer_placement_promote_button.size_flags_stretch_ratio = 1.0
	developer_placement_promote_button.tooltip_text = "Lock the pending position and promote all locked positions into a writable source checkout."
	developer_placement_promote_button.pressed.connect(_save_active_developer_placement_to_project)
	developer_placement_promote_button.visible = not PersistencePathsScript.distribution_build()
	project_actions.add_child(developer_placement_promote_button)
	developer_placement_export_button = Button.new()
	developer_placement_export_button.name = "ExportPlacementReport"
	developer_placement_export_button.text = "Export Report"
	developer_placement_export_button.custom_minimum_size = Vector2(0.0, DEVELOPER_PANEL_CONTROL_HEIGHT)
	developer_placement_export_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	developer_placement_export_button.size_flags_stretch_ratio = 1.0
	developer_placement_export_button.tooltip_text = "Lock the pending position and export the complete effective placement authority to a shareable JSON report. Works from an EXE build."
	developer_placement_export_button.pressed.connect(_export_active_developer_placement_report)
	project_actions.add_child(developer_placement_export_button)
	_apply_developer_panel_fixed_metrics(developer_placement_panel)
	_apply_developer_panel_fixed_metrics(developer_placement_restore_button)
	_sync_developer_placement_panel_visibility()
	_update_developer_placement_panel()
	_queue_developer_placement_panel_layout()


func _apply_developer_panel_fixed_metrics(node: Node) -> void:
	var control := node as Control
	if control != null and (control is Label or control is BaseButton):
		control.add_theme_font_size_override("font_size", DEVELOPER_PANEL_FONT_SIZE)
	if control is BaseButton:
		control.custom_minimum_size.y = DEVELOPER_PANEL_CONTROL_HEIGHT
	for child in node.get_children():
		_apply_developer_panel_fixed_metrics(child)


func _developer_placement_mode_active() -> bool:
	return developer_placement_mode or developer_slot_placement_mode


func _sync_developer_placement_panel_visibility() -> void:
	var active := _developer_placement_mode_active()
	if not active:
		developer_placement_panel_minimized = false
	if developer_placement_panel != null:
		developer_placement_panel.visible = active and not developer_placement_panel_minimized
	if developer_placement_restore_button != null:
		developer_placement_restore_button.visible = active and developer_placement_panel_minimized
	_queue_developer_placement_panel_layout()


func _set_developer_placement_panel_minimized(minimized: bool) -> void:
	developer_placement_panel_minimized = minimized and _developer_placement_mode_active()
	_sync_developer_placement_panel_visibility()


func _minimize_developer_placement_panel() -> void:
	_set_developer_placement_panel_minimized(true)
	if developer_placement_restore_button != null:
		developer_placement_restore_button.grab_focus()


func _restore_developer_placement_panel() -> void:
	_set_developer_placement_panel_minimized(false)
	if developer_placement_minimize_button != null:
		developer_placement_minimize_button.grab_focus()


func _toggle_developer_placement_panel_minimized() -> void:
	if developer_placement_panel_minimized:
		_restore_developer_placement_panel()
	else:
		_minimize_developer_placement_panel()


func _queue_developer_placement_panel_layout() -> void:
	if developer_placement_panel_layout_queued or not is_inside_tree():
		return
	developer_placement_panel_layout_queued = true
	call_deferred("_layout_developer_placement_panel")


func _layout_developer_placement_panel() -> void:
	developer_placement_panel_layout_queued = false
	if developer_placement_panel == null or developer_placement_content == null or developer_placement_stack == null:
		return
	_apply_developer_panel_fixed_metrics(developer_placement_panel)
	_apply_developer_panel_fixed_metrics(developer_placement_restore_button)
	var available_size := Vector2(
		maxf(0.0, size.x - DEVELOPER_PANEL_MARGIN * 2.0),
		maxf(0.0, size.y - DEVELOPER_PANEL_MARGIN * 2.0)
	)
	if available_size.x <= 0.0 or available_size.y <= 0.0:
		return
	if developer_placement_restore_button != null:
		var restore_size := Vector2(
			minf(DEVELOPER_PANEL_RESTORE_MIN_WIDTH, available_size.x),
			minf(DEVELOPER_PANEL_CONTROL_HEIGHT, available_size.y)
		)
		developer_placement_restore_button.size = restore_size
		developer_placement_restore_button.position = Vector2(
			maxf(DEVELOPER_PANEL_MARGIN, size.x - DEVELOPER_PANEL_MARGIN - restore_size.x),
			DEVELOPER_PANEL_MARGIN
		)
	var panel_width := minf(maxf(DEVELOPER_PANEL_MIN_WIDTH, DEVELOPER_PANEL_PREFERRED_WIDTH), available_size.x)
	var panel_height := minf(DEVELOPER_PANEL_FIXED_HEIGHT, available_size.y)
	developer_placement_panel.position = Vector2.ONE * DEVELOPER_PANEL_MARGIN
	developer_placement_panel.custom_minimum_size = Vector2.ZERO
	developer_placement_panel.size = Vector2(maxf(1.0, panel_width), maxf(1.0, panel_height))


func _on_developer_slot_family_filter_toggled(pressed: bool, family: String) -> void:
	if pressed:
		set_developer_slot_family_visible(family, true)


func _update_developer_placement_panel() -> void:
	if developer_placement_panel == null or developer_placement_label == null:
		return
	developer_placement_panel_update_count += 1
	_sync_developer_placement_panel_visibility()
	_queue_developer_placement_panel_layout()
	if developer_layout_save_button != null:
		developer_layout_save_button.visible = developer_slot_placement_mode
	if developer_layout_save_next_button != null:
		var progress := _copy_dictionary(foundation_snapshot.get("developer_placement_progress", {}))
		developer_layout_save_next_button.visible = developer_slot_placement_mode and bool(progress.get("practice_session", false))
	if developer_placement_promote_button != null:
		developer_placement_promote_button.visible = not PersistencePathsScript.distribution_build()
	if developer_slot_placement_mode:
		if developer_slot_filter_row != null:
			developer_slot_filter_row.visible = true
		if developer_slot_visibility_row != null:
			developer_slot_visibility_row.visible = true
		if developer_slot_context_label != null:
			developer_slot_context_label.visible = true
		if developer_slot_layer_row != null:
			developer_slot_layer_row.visible = true
		_update_developer_slot_placement_panel()
		return
	if developer_slot_filter_row != null:
		developer_slot_filter_row.visible = false
	if developer_slot_visibility_row != null:
		developer_slot_visibility_row.visible = false
	if developer_slot_context_label != null:
		developer_slot_context_label.visible = false
	if developer_slot_layer_row != null:
		developer_slot_layer_row.visible = false
	var object_data := _scene_object(selected_object_id)
	if object_data.is_empty():
		developer_placement_label.text = "Placement mode: drag an object; release to keep it. Right-click or Escape cancels. F2 hides this panel."
		developer_placement_lock_button.disabled = true
		developer_placement_reset_button.disabled = true
		return
	var identity := _developer_placement_identity(object_data)
	var status_text := "unchanged"
	if developer_placement_pending_rect.has_area():
		status_text = "on %s" % developer_placement_surface_id if not developer_placement_surface_id.is_empty() else "free placement"
		if not developer_placement_overlap_ids.is_empty():
			var shown_overlaps := developer_placement_overlap_ids.slice(0, mini(3, developer_placement_overlap_ids.size()))
			status_text += "; overlaps %s" % ", ".join(shown_overlaps)
			if developer_placement_overlap_ids.size() > shown_overlaps.size():
				status_text += " +%d" % (developer_placement_overlap_ids.size() - shown_overlaps.size())
	var target_label := str(identity.get("slot_id", selected_object_id))
	if not str(identity.get("category", "")).is_empty():
		target_label = "%s category slot %d" % [str(identity.get("category", "")).capitalize(), int(identity.get("category_index", 0)) + 1]
	developer_placement_label.text = "%s | %s\n%s | %s" % [
		str(foundation_snapshot.get("archetype_id", environment_id)),
		str(foundation_snapshot.get("current_layer_id", foundation_snapshot.get("layer_id", "main"))),
		target_label,
		status_text,
	]
	developer_placement_lock_button.disabled = not developer_placement_pending_rect.has_area() or not developer_placement_valid
	developer_placement_reset_button.disabled = false


func _update_developer_slot_placement_panel() -> void:
	var review_status := _developer_slot_review_status()
	var progress := _copy_dictionary(foundation_snapshot.get("developer_placement_progress", {}))
	_update_developer_slot_filter_labels()
	var review_ready := bool(review_status.get("ready", false))
	if developer_layout_save_button != null:
		developer_layout_save_button.disabled = not review_ready
	if developer_layout_save_next_button != null:
		developer_layout_save_next_button.disabled = not review_ready
	var preview_context := _developer_slot_preview_context()
	if developer_slot_context_label != null:
		var context_name := str(preview_context.get("label", "No active scenario")).trim_prefix("Active preview: ")
		var layout_id := str(progress.get("layout_id", "")).strip_edges()
		if not layout_id.is_empty():
			context_name = layout_id
		var context_lines: Array[String] = ["CONTEXT | %s" % context_name]
		if _developer_slot_has_active_scenario():
			if developer_slot_edit_shared_in_scenario:
				context_lines.append("SCOPE | Scenario + shared room (room progress resets)")
			else:
				context_lines.append("SCOPE | Scenario slots; shared room is locked")
		else:
			context_lines.append("SCOPE | Shared room; applies to every scenario")
		var reviewed_families: Array = review_status.get("reviewed", [])
		var missing_review_families: Array = review_status.get("missing", [])
		var review_line := "REVIEW | READY | %s" % ", ".join(reviewed_families)
		if not missing_review_families.is_empty():
			review_line = "REVIEW | TODO | %s" % ", ".join(missing_review_families)
		var overlap_summary := _developer_slot_overlap_summary()
		var issue_parts: Array[String] = []
		var active_overlap_count := int(overlap_summary.get("active_count", 0))
		if active_overlap_count > 0:
			issue_parts.append("%d active overlap(s)" % active_overlap_count)
		var alternative_overlap_count := int(overlap_summary.get("alternative_count", 0))
		if alternative_overlap_count > 0:
			issue_parts.append("%d allowed alternative(s)" % alternative_overlap_count)
		var hidden_detail_count := _developer_slot_hidden_detail_count()
		if hidden_detail_count > 0:
			issue_parts.append("%d hidden marker(s)" % hidden_detail_count)
		if not issue_parts.is_empty():
			review_line += " | %s" % ", ".join(issue_parts)
		context_lines.append(review_line)
		var progress_line := "PROGRESS | Local draft"
		if not progress.is_empty():
			var saved_label := "SAVED" if bool(progress.get("saved", false)) else "NOT SAVED"
			progress_line = "PROGRESS | %s | %d/%d saved | %d left" % [
				saved_label,
				int(progress.get("saved_layout_count", 0)),
				int(progress.get("expected_layout_count", 0)),
				int(progress.get("missing_layout_count", 0)),
			]
			var next_missing := str(progress.get("next_missing_layout_id", "")).strip_edges()
			if not next_missing.is_empty() and not bool(progress.get("complete", false)):
				progress_line += " | Next: %s" % next_missing
		context_lines.append(progress_line)
		developer_slot_context_label.text = "\n".join(context_lines)
		developer_slot_context_label.tooltip_text = "\n".join(context_lines)
	var family := _developer_slot_active_family()
	var family_counts := _developer_slot_family_counts(family)
	var count_summary := "%s %d/%d shown" % [
		family.capitalize(),
		int(family_counts.get("visible", 0)),
		int(family_counts.get("total", 0)),
	]
	var slot := _developer_slot(developer_slot_selected_id)
	var showing_hover := false
	if slot.is_empty():
		slot = _developer_slot(developer_slot_hovered_id)
		showing_hover = not slot.is_empty()
	if slot.is_empty():
		_sync_developer_slot_layer_buttons({}, false)
		var visibility_summary := "Occupied slots"
		if developer_slot_show_empty_capacity:
			visibility_summary = "Empty slots shown"
		if developer_slot_show_runtime_reserves:
			visibility_summary += " | Reserves shown"
		developer_placement_label.text = "SELECTION | %s\nNo slot selected\n%s\nHover or drag a marker to inspect it." % [count_summary, visibility_summary]
		developer_placement_label.tooltip_text = "Select or drag a visible slot marker to inspect and reposition it."
		developer_placement_lock_button.disabled = true
		developer_placement_reset_button.disabled = true
		return
	var slot_id := str(slot.get("id", developer_slot_selected_id))
	family = _developer_slot_family(slot)
	var scope_label := "SCENARIO-LOCAL" if _developer_slot_scope(slot) == "scenario_local" else "ROOM-SHARED"
	var editable := _developer_slot_is_editable(slot)
	_sync_developer_slot_layer_buttons(slot, not showing_hover and editable)
	var kind := str(slot.get("kind", family))
	var placement_class := str(slot.get("footprint_class", "unknown"))
	var support := str(slot.get("support_id", "free"))
	var occupants := _developer_slot_occupants(slot_id)
	var primary_label := _developer_slot_primary_label(slot)
	var occupancy := "Empty capacity" if occupants.is_empty() else "Occupant: %s" % ", ".join(occupants)
	var known_claimants := _developer_slot_claimant_labels(slot)
	var slot_state := _developer_slot_state(slot)
	var requirement := "required" if bool(slot_state.get("required", false)) else "optional capacity"
	if _developer_slot_is_runtime_reserve(slot):
		var reserve_reason := _developer_slot_reserve_reason(slot)
		requirement = "runtime reserve" if reserve_reason.is_empty() else "runtime reserve: %s" % reserve_reason
	var warnings: Array = slot_state.get("warnings", [])
	var status_text := "hover preview" if showing_hover else "unchanged"
	var draw_layer_label := _developer_slot_draw_layer_label(_developer_slot_draw_layer(slot))
	if developer_slot_pending_rect.has_area():
		status_text = "position %.0f, %.0f" % [developer_slot_pending_position.x, developer_slot_pending_position.y]
		if not developer_slot_overlap_ids.is_empty():
			status_text += "; %s overlap: %s" % [
				"blocked route" if not developer_slot_valid else "advisory",
				", ".join(developer_slot_overlap_ids.slice(0, mini(3, developer_slot_overlap_ids.size()))),
			]
	if not warnings.is_empty():
		status_text += "; WARNING: %s" % "; ".join(warnings)
	developer_placement_label.text = "%s | %s | %s\n%s\n%s | %s | %s\n%s | %s | %s | %s" % [
		str(foundation_snapshot.get("archetype_id", environment_id)),
		str(foundation_snapshot.get("current_layer_id", foundation_snapshot.get("layer_id", "main"))),
		count_summary,
		primary_label,
		slot_id,
		"%s%s" % [scope_label, " / LOCKED" if not editable else ""],
		"%s / %s" % [family if kind == family else "%s:%s" % [family, kind], placement_class],
		occupancy,
		"Layer: %s" % draw_layer_label,
		requirement,
		status_text,
	]
	var tooltip_lines: Array[String] = [
		primary_label,
		"Slot: %s" % slot_id,
		"Scope: %s" % scope_label,
		"Class: %s | Support: %s" % [placement_class, support],
		"Draw layer: %s" % draw_layer_label,
		occupancy,
		"Status: %s" % status_text,
	]
	if not known_claimants.is_empty():
		tooltip_lines.append("Known roles: %s" % ", ".join(known_claimants))
	developer_placement_label.tooltip_text = "\n".join(tooltip_lines)
	developer_placement_lock_button.disabled = showing_hover or not editable or not developer_slot_pending_rect.has_area() or not developer_slot_valid
	developer_placement_reset_button.disabled = showing_hover or not editable


func _developer_slot_draw_layer(slot: Dictionary) -> int:
	if slot.has("draw_layer"):
		return clampi(int(slot.get("draw_layer", 0)), -1, 1)
	return -1 if str(slot.get("footprint_class", "")) == "behind_counter_person" else 0


func _developer_slot_draw_layer_label(layer: int) -> String:
	match clampi(layer, -1, 1):
		-1: return "Behind"
		1: return "Front"
		_: return "Standard"


func _sync_developer_slot_layer_buttons(slot: Dictionary, editable: bool) -> void:
	var active_layer := _developer_slot_draw_layer(slot) if not slot.is_empty() else 99
	for layer_name_value in SLOT_DRAW_LAYERS.keys():
		var layer_name := str(layer_name_value)
		var button_value: Variant = developer_slot_layer_buttons.get(layer_name)
		if not (button_value is BaseButton):
			continue
		var button := button_value as BaseButton
		button.disabled = slot.is_empty() or not editable
		button.set_pressed_no_signal(active_layer == int(SLOT_DRAW_LAYERS.get(layer_name, 0)))


func _on_developer_slot_layer_toggled(pressed: bool, layer_name: String) -> void:
	if not pressed or not SLOT_DRAW_LAYERS.has(layer_name):
		return
	var slot := _developer_slot(developer_slot_selected_id)
	if slot.is_empty() or not _developer_slot_is_editable(slot):
		_sync_developer_slot_layer_buttons(slot, false)
		return
	var request := {
		"environment": _developer_slot_environment(),
		"slot_id": developer_slot_selected_id,
		"layer": int(SLOT_DRAW_LAYERS.get(layer_name, 0)),
		"_slot_layer_handled": false,
		"_slot_layer_persisted": false,
	}
	developer_slot_layer_requested.emit(request)
	if bool(request.get("_slot_layer_handled", false)) and not bool(request.get("_slot_layer_persisted", false)):
		_sync_developer_slot_layer_buttons(slot, true)
		return
	_invalidate_developer_placement_geometry_caches()
	_update_developer_placement_panel()
	queue_redraw()


func _lock_active_developer_placement() -> void:
	if developer_slot_placement_mode:
		_lock_developer_slot_placement()
	else:
		_lock_developer_placement()


func _cancel_active_developer_placement_preview() -> void:
	if developer_slot_placement_mode:
		_cancel_developer_slot_placement_preview()
	else:
		_cancel_developer_placement_preview()


func _reset_active_developer_placement() -> void:
	if developer_slot_placement_mode:
		_reset_developer_slot_placement()
	else:
		_reset_developer_placement()


func _save_active_developer_placement_to_project() -> void:
	if developer_slot_placement_mode:
		_save_developer_slot_placement_to_project()
	else:
		_save_developer_placement_to_project()


func _export_active_developer_placement_report() -> void:
	var request: Dictionary = {}
	if developer_slot_placement_mode:
		if developer_slot_pending_rect.has_area():
			if not developer_slot_valid:
				return
			request = _developer_slot_placement_request()
			clear_developer_slot_placement_preview()
	else:
		if developer_placement_pending_rect.has_area():
			if not developer_placement_valid:
				return
			request = _developer_placement_request()
			clear_developer_placement_preview()
	developer_placement_export_requested.emit(request)


func _save_and_load_next_developer_slot_layout() -> void:
	_save_current_developer_slot_layout(true)


func _save_current_developer_slot_layout(load_next_missing: bool = false) -> void:
	if not developer_slot_placement_mode:
		return
	var review_status := _developer_slot_review_status()
	if not bool(review_status.get("ready", false)):
		_update_developer_placement_panel()
		return
	var pending_request: Dictionary = {}
	if developer_slot_pending_rect.has_area():
		if not developer_slot_valid:
			return
		pending_request = _developer_slot_placement_request()
	var request := _developer_full_slot_layout_request()
	# The complete layout transaction owns the pending coordinate too. Avoid a
	# separate durable single-slot write and full room refresh immediately before
	# this full-layout save.
	if not pending_request.is_empty():
		var full_positions: Dictionary = request.get("full_positions", {})
		full_positions[str(pending_request.get("slot_id", ""))] = pending_request.get("position", Vector2.ZERO)
		request["full_positions"] = full_positions
		request["slot_count"] = full_positions.size()
	request["load_next_missing"] = load_next_missing
	request["reviewed_families"] = (review_status.get("reviewed", []) as Array).duplicate()
	var render_generation := environment_snapshot_render_generation
	developer_slot_dragging = false
	developer_layout_save_requested.emit(request)
	if _developer_layout_save_failed(request):
		_update_developer_placement_panel()
		queue_redraw()
		return
	if environment_snapshot_render_generation == render_generation:
		clear_developer_slot_placement_preview(false, false)
		developer_placement_authority_dirty = true
		_invalidate_developer_placement_geometry_caches()
		if _apply_authoring_slot_positions_to_scene_objects():
			_capture_developer_slot_scene_object_baseline()
		_update_developer_placement_panel()
		queue_redraw()


func _developer_layout_save_failed(request: Dictionary) -> bool:
	return bool(request.get("_developer_layout_save_handled", false)) \
		and not bool(request.get("_developer_layout_save_persisted", false))


func _developer_full_slot_layout_request() -> Dictionary:
	var environment := _developer_slot_environment()
	var full_positions: Dictionary = {}
	# Full saves preserve hidden shared runtime-reserve geometry even though the
	# base-room placement list no longer offers those scenario-family markers.
	for slot_value in _developer_authored_slots():
		var slot := slot_value as Dictionary
		var slot_id := str(slot.get("id", "")).strip_edges()
		if slot_id.is_empty():
			continue
		full_positions[slot_id] = _developer_slot_position(slot)
	return {
		"environment": environment,
		"field": "slot_positions",
		"full_positions": full_positions,
		"slot_count": full_positions.size(),
		"preview_context": _developer_slot_preview_context(),
	}


func _developer_placement_identity(object_data: Dictionary) -> Dictionary:
	# Schema-v2 object placement is a convenience view over the reusable slot
	# authority. Moving an occupied object therefore moves its authored slot; it
	# must never recreate the retired per-object/category coordinate overlays.
	var occupied_slot_id := str(object_data.get("slot_id", "")).strip_edges()
	var occupied_slot_family := str(object_data.get("slot_family", object_data.get("family", ""))).strip_edges()
	if occupied_slot_family.is_empty() and occupied_slot_id.contains("."):
		occupied_slot_family = occupied_slot_id.get_slice(".", 0)
	if occupied_slot_family in SLOT_FAMILIES and occupied_slot_id.begins_with("%s." % occupied_slot_family):
		return {
			"field": "slot_positions",
			"slot_id": occupied_slot_id,
			"owner_namespace": str(object_data.get("owner_namespace", "")).strip_edges(),
			"stable_object_id": str(object_data.get("stable_object_id", "")).strip_edges(),
		}
	return {}


func _developer_placement_request() -> Dictionary:
	var object_data := _scene_object(selected_object_id)
	if object_data.is_empty():
		return {}
	var identity := _developer_placement_identity(object_data)
	if identity.is_empty():
		return {}
	var placement_class := str(object_data.get("placement_class", "")).strip_edges()
	if placement_class.is_empty():
		placement_class = EnvironmentPlacementScript.classify(object_data, str(object_data.get("interaction_type", object_data.get("type", ""))), selected_object_id, str(object_data.get("prop", object_data.get("icon_key", ""))))
	var object_rect := developer_placement_pending_rect if developer_placement_pending_rect.has_area() else _developer_edit_rect_for_object(object_data)
	var slot_position := object_rect.position
	var slot := _developer_slot(str(identity.get("slot_id", "")))
	if not slot.is_empty():
		var source_rect := developer_placement_original_rect if developer_placement_original_rect.has_area() else _developer_slot_rect(slot)
		slot_position += _developer_slot_position(slot) - source_rect.position
	return {
		"environment": {
			"archetype_id": str(foundation_snapshot.get("archetype_id", foundation_snapshot.get("id", environment_id))),
			"current_layer_id": str(foundation_snapshot.get("current_layer_id", foundation_snapshot.get("layer_id", ""))),
			"scenario_id": str(foundation_snapshot.get("scenario_id", "")),
		},
		"object_id": selected_object_id,
		"owner_namespace": str(identity.get("owner_namespace", "")),
		"stable_object_id": str(identity.get("stable_object_id", "")),
		"field": str(identity.get("field", "slot_positions")),
		"slot_id": str(identity.get("slot_id", selected_object_id)),
		# Slot overrides store the authored contact/anchor, not the visual hit
		# rectangle's top-left. Keep both so persistence and immediate preview use
		# the coordinate appropriate to each representation.
		"position": slot_position,
		"preview_top_left": object_rect.position,
		"size": object_rect.size,
		"placement_class": placement_class,
		"surface_id": developer_placement_surface_id,
		"category": str(identity.get("category", "")),
		"category_index": int(identity.get("category_index", -1)),
	}


func set_environment_activity_paused(paused: bool) -> void:
	if environment_activity_paused == paused:
		return
	environment_activity_paused = paused
	scene_idle_animation_redraw_accumulator = 0.0
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_queue_developer_placement_panel_layout()
		_invalidate_camera_target()
		_update_camera_target_if_needed()
		queue_redraw()
		view_geometry_changed.emit()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready() and is_visible_in_tree():
		_arm_animation_heartbeat()


# Copies a foundation EnvironmentInstance view snapshot into canvas-local state.
func render_environment_snapshot(snapshot: Dictionary) -> void:
	_render_owned_environment_snapshot(snapshot.duplicate(true))


# Internal ownership-transfer path for a freshly assembled presentation value.
# The canvas treats foundation_snapshot as immutable; callers that retain or may
# mutate their dictionary must continue using render_environment_snapshot().
func render_owned_environment_snapshot(snapshot: Dictionary) -> void:
	_render_owned_environment_snapshot(snapshot)


func _render_owned_environment_snapshot(snapshot: Dictionary) -> void:
	# Re-arm presentation processing at every live-content boundary. This repairs
	# a canvas disabled by a prior lifecycle/test owner without waiting for input.
	_arm_animation_heartbeat()
	environment_snapshot_render_generation += 1
	var previous_slot_context := _developer_slot_snapshot_context_key(foundation_snapshot)
	var next_slot_context := _developer_slot_snapshot_context_key(snapshot)
	_preserve_developer_slot_edit_before_context_change(snapshot)
	uses_foundation_snapshot = true
	foundation_snapshot = snapshot
	if previous_slot_context != next_slot_context:
		developer_placement_authority_dirty = false
	_invalidate_developer_placement_geometry_caches()
	var archetype_id := str(foundation_snapshot.get("archetype_id", foundation_snapshot.get("id", environment_id)))
	var visual_context: Dictionary = foundation_snapshot.get("visual_context", {}) if typeof(foundation_snapshot.get("visual_context", {})) == TYPE_DICTIONARY else {}
	var art_key := str(visual_context.get("art_key", archetype_id)).strip_edges()
	environment_id = art_key if ["punchline_club", "punchline_back_room"].has(art_key) else archetype_id
	var texture_scope_key := str(foundation_snapshot.get("world_node_id", foundation_snapshot.get("id", environment_id))).strip_edges()
	if texture_scope_key.is_empty():
		texture_scope_key = environment_id
	if texture_scope_key != item_icon_texture_cache_scope_key:
		item_icon_texture_cache.clear()
		item_icon_texture_cache_scope_key = texture_scope_key
	environment_name = str(foundation_snapshot.get("display_name", foundation_snapshot.get("name", environment_name)))
	var presentation_value: Variant = foundation_snapshot.get("scenario_presentation", {})
	scenario_presentation = presentation_value as Dictionary if typeof(presentation_value) == TYPE_DICTIONARY else {}
	_cache_scenario_presentation()
	suspicion_level = int(foundation_snapshot.get("suspicion_level", suspicion_level))
	drunk_level = int(foundation_snapshot.get("drunk_level", drunk_level))
	drunk_time_scale = clampf(float(foundation_snapshot.get("drunk_time_scale", 1.0)), DRUNK_TIME_SCALE_MIN, 1.0)
	reduce_motion = bool(foundation_snapshot.get("reduce_motion", false))
	drunk_effect_mode = _normalized_drunk_effect_mode(str(foundation_snapshot.get("drunk_effect_mode", drunk_effect_mode)))
	_update_drunk_distortion_overlay()
	foundation_scene_objects = _objects_from_foundation_snapshot(foundation_snapshot)
	if developer_slot_placement_mode:
		_capture_developer_slot_scene_object_baseline()
		if previous_slot_context != next_slot_context:
			developer_slot_edit_shared_in_scenario = false
			_configure_developer_slot_context(true)
	# The incoming snapshot replaces either preview, so clear their presentation
	# state before deriving labels and scene caches from authoritative geometry.
	clear_developer_placement_preview(false, false)
	clear_developer_slot_placement_preview(false, false)
	_apply_authoring_slot_positions_to_scene_objects(false)
	_sync_person_transits()
	_sync_actor_route_starts()
	overlay_repositioned_object_ids.clear()
	_rebuild_scene_object_cache()
	_prune_object_animation_phase_cache()
	if not selected_object_id.is_empty() and _scene_object(selected_object_id).is_empty():
		selected_object_id = ""
	if not hovered_object_id.is_empty() and _scene_object(hovered_object_id).is_empty():
		hovered_object_id = ""
	if not developer_slot_selected_id.is_empty() and _developer_slot(developer_slot_selected_id).is_empty():
		developer_slot_selected_id = ""
	# Same-context refreshes remain non-committing. Exact context transitions have
	# already retained a valid changed nudge above, against the outgoing layout.
	_update_developer_placement_panel()
	_invalidate_camera_target()
	_update_camera_target_if_needed()
	queue_redraw()
	view_geometry_changed.emit()


func _preserve_developer_slot_edit_before_context_change(next_snapshot: Dictionary) -> void:
	if not developer_slot_placement_mode or not developer_slot_pending_rect.has_area() \
			or developer_slot_context_change_locking:
		return
	var current_context := _developer_slot_snapshot_context_key(foundation_snapshot)
	var next_context := _developer_slot_snapshot_context_key(next_snapshot)
	if current_context.is_empty() or current_context == next_context:
		return
	developer_slot_context_change_locking = true
	_finish_developer_slot_placement_edit()
	developer_slot_context_change_locking = false


func _developer_slot_snapshot_context_key(snapshot: Dictionary) -> String:
	if snapshot.is_empty():
		return ""
	var archetype_id := str(snapshot.get("archetype_id", snapshot.get("id", ""))).strip_edges()
	var layer_id := str(snapshot.get("current_layer_id", snapshot.get("layer_id", ""))).strip_edges()
	var map_id := "%s:%s" % [archetype_id, layer_id] if not layer_id.is_empty() else archetype_id
	var scenario_id := EnvironmentPlacementScript.active_scenario_id(snapshot)
	return "%s::%s" % [map_id, scenario_id if not scenario_id.is_empty() else "base"]


func settle_person_transits() -> void:
	for object_id in person_transit_ids:
		var transit_value: Variant = person_transits.get(object_id, {})
		if typeof(transit_value) != TYPE_DICTIONARY:
			continue
		var transit := transit_value as Dictionary
		if str(transit.get("kind", "")) == "arrival":
			_restore_arrived_person(object_id, _copy_dictionary(transit.get("settled_object", {})))
		else:
			_remove_scene_object(object_id)
	person_transits.clear()
	person_transit_ids.clear()
	actor_route_started_at_cache.clear()
	person_transit_room_key = "__settled_reload__"
	settled_person_objects_cache = _settled_person_objects(foundation_scene_objects)
	for value in foundation_scene_objects:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var object_data := value as Dictionary
		object_data.erase("person_transit_active")
		object_data.erase("person_transit_kind")
		object_data.erase("person_transit_settled_position")
	_rebuild_scene_object_cache()
	queue_redraw()


func set_small_screen_mode(enabled: bool) -> void:
	if small_screen_mode == enabled:
		return
	small_screen_mode = enabled
	info_card_visual_rect = Rect2()
	info_card_visual_object_id = ""
	_rebuild_scene_object_cache()
	_invalidate_camera_target()
	queue_redraw()
	view_geometry_changed.emit()


func set_object_labels_and_borders_enabled(enabled: bool) -> void:
	if object_labels_and_borders_enabled == enabled:
		return
	object_labels_and_borders_enabled = enabled
	_rebuild_object_label_rect_cache(_active_scene_objects())
	queue_redraw()


# Keeps camera focus clear of a live conversation without changing stable room
# object placement. TalkDock owns target avoidance; the canvas never relocates
# generated environment objects in response to overlay motion.
func set_reserved_overlay_rect(global_rect: Rect2) -> bool:
	if global_rect.is_equal_approx(reserved_overlay_global_rect):
		return false
	reserved_overlay_global_rect = global_rect
	_invalidate_camera_target()
	_update_camera_target_if_needed()
	queue_redraw()
	view_geometry_changed.emit()
	return true


# Exact board-space reserve consumed by scenario layout validation. This is a
# read-only presentation snapshot and never authorizes sequence behavior.
func scenario_layout_context() -> Dictionary:
	var local_rect := _reserved_overlay_local_rect()
	var board_rect := Rect2()
	if local_rect.has_area():
		var start := _local_to_board_position(local_rect.position)
		var finish := _local_to_board_position(local_rect.end)
		board_rect = Rect2(start, finish - start).intersection(Rect2(Vector2.ZERO, Vector2(BOARD_SIZE)))
	return {
		"reserved_overlay_board_rect": _rect_to_snapshot(board_rect),
		"small_screen_mode": small_screen_mode,
		"reduce_motion": reduce_motion,
		"production_canvas": true,
	}


func debug_soak_snapshot() -> Dictionary:
	return {
		"environment_id": environment_id,
		"item_icon_texture_cache_scope_key": item_icon_texture_cache_scope_key,
		"foundation_object_count": foundation_scene_objects.size(),
		"active_scene_object_cache_size": active_scene_objects_cache.size(),
		"scene_object_index_count": scene_objects_by_id_cache.size(),
		"object_label_rect_cache_size": object_label_rect_cache.size(),
		"object_label_layout": object_label_layout_stats.duplicate(true),
		"object_labels_and_borders_enabled": object_labels_and_borders_enabled,
		"item_icon_texture_cache_size": item_icon_texture_cache.size(),
		"icon_sprite_texture_cache_size": icon_sprite_texture_cache.size(),
		"draw_text_width_cache_size": draw_text_width_cache.size(),
		"fit_draw_text_cache_size": fit_draw_text_cache.size(),
		"object_animation_phase_cache_size": object_animation_phase_cache.size(),
		"character_idle_profile_cache_size": character_idle_profile_cache.size(),
		"slot_prop_static_layer_cache_size": slot_prop_static_layer_cache.size(),
		"actor_route_started_at_cache_size": actor_route_started_at_cache.size(),
		"actor_route_time": actor_route_time,
		"background_texture_loaded": background_texture != null,
		"scene_idle_animation_redraw_count": scene_idle_animation_redraw_count,
		"scene_object_cache_rebuild_count": scene_object_cache_rebuild_count,
		"developer_slot_cache_rebuild_count": developer_slot_cache_rebuild_count,
		"developer_placement_panel_update_count": developer_placement_panel_update_count,
		"developer_slot_overlay_cache_rebuild_count": developer_slot_overlay_cache_rebuild_count,
		"developer_slot_overlap_audit_count": developer_slot_overlap_audit_count,
		"object_label_layout_rebuild_count": object_label_layout_rebuild_count,
		"environment_snapshot_render_generation": environment_snapshot_render_generation,
		"developer_placement_authority_dirty": developer_placement_authority_dirty,
		"person_transit_count": person_transit_ids.size(),
		"person_transit_cap": MAX_CONCURRENT_PERSON_TRANSITS,
		"person_transit_ids": person_transit_ids.duplicate(),
		"reserved_overlay_global_rect": reserved_overlay_global_rect,
		"overlay_repositioned_object_ids": overlay_repositioned_object_ids.duplicate(),
	}


func reset_performance_counters() -> void:
	scene_idle_animation_redraw_count = 0
	scene_object_cache_rebuild_count = 0
	developer_slot_cache_rebuild_count = 0
	developer_placement_panel_update_count = 0
	developer_slot_overlay_cache_rebuild_count = 0
	developer_slot_overlap_audit_count = 0
	object_label_layout_rebuild_count = 0


func performance_live_status() -> Dictionary:
	return {
		"scene_idle_animation_redraw_count": scene_idle_animation_redraw_count,
		"scene_idle_animation_active": _scene_idle_animation_active(),
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
	var previous_zoom := camera_zoom
	var previous_offset := camera_offset
	# Selection and hover share the inspection card. Tutorial focus can move to
	# another authored target while the pointer is still resting over the prior
	# one; clearing only the selection would therefore leave that stale hover
	# card rendered over the new target until the player moved the mouse.
	if object_id.is_empty() and not hovered_object_id.is_empty():
		_set_hovered_object("")
	if selected_object_id != object_id:
		selected_object_id = object_id
		selected_info_action_index = 0
		_invalidate_camera_target()
	_update_object_label_accessibility()
	_update_camera_target_if_needed()
	# Reduced-motion and explicit room resets snap. A tutorial conversation only
	# freezes autonomous room activity; player-driven focus presentation remains
	# animated while simulation time is stopped.
	if reduce_motion or (selected_object_id.is_empty() and snap_to_target):
		camera_zoom = target_camera_zoom
		camera_offset = target_camera_offset
		_snap_info_card_to_target()
	queue_redraw()
	if absf(previous_zoom - camera_zoom) > CAMERA_ZOOM_SNAP_EPSILON or previous_offset.distance_squared_to(camera_offset) > CAMERA_OFFSET_SNAP_EPSILON * CAMERA_OFFSET_SNAP_EPSILON:
		view_geometry_changed.emit()


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
	var object_ids := _object_ids_at_local_position(local_position, false)
	return object_ids[0] if not object_ids.is_empty() else ""


# Returns the already-rendered interaction record for an input callback. The
# host treats this as read-only and avoids rebuilding or deep-copying the room
# catalog for an object the canvas has just proven is current.
func interactable_object_view(object_id: String) -> Dictionary:
	for object_value in _array_view(foundation_snapshot.get("interactable_objects", [])):
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data := object_value as Dictionary
		if str(object_data.get("object_id", "")) == object_id:
			return object_data
	return {}


# Applies a simulation-owned state change to one already-rendered room object.
# Background fixtures use this path so an AUTO spin can become visible without
# rebuilding the complete room catalog, layout, text caches, and actor routes.
func apply_interactable_object_state_patch(object_id: String, object_state: Dictionary) -> bool:
	if not uses_foundation_snapshot or object_id.is_empty() or object_state.is_empty():
		return false
	var runtime_state := _copy_dictionary(object_state.get("runtime_state", {}))
	var visual_state := _copy_dictionary(object_state.get("visual_state", {}))
	var patched := false
	for object_value in foundation_scene_objects:
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data := object_value as Dictionary
		if str(object_data.get("id", "")) != object_id:
			continue
		object_data["status_summary"] = str(object_state.get("status_summary", ""))
		object_data["state_badge"] = str(object_state.get("state_badge", ""))
		object_data["runtime_state"] = runtime_state
		object_data["visual_state"] = visual_state
		patched = true
		break
	for object_value in _array_view(foundation_snapshot.get("interactable_objects", [])):
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var interaction_record := object_value as Dictionary
		if str(interaction_record.get("object_id", "")) != object_id:
			continue
		interaction_record["status_summary"] = str(object_state.get("status_summary", ""))
		interaction_record["state_badge"] = str(object_state.get("state_badge", ""))
		interaction_record["runtime_state"] = runtime_state.duplicate(true)
		interaction_record["visual_state"] = visual_state.duplicate(true)
		patched = true
		break
	if patched:
		queue_redraw()
	return patched


# Returns rendered objects under a point from front to back. Actionable objects
# remain ahead of view-only scenery when their hit regions overlap so a passive
# prop cannot conceal a usable interaction. Hover/focus may include passive
# objects; activation and keyboard traversal retain the interactive-only path.
func _object_ids_at_local_position(local_position: Vector2, interactive_only: bool = true) -> Array[String]:
	var board_position := _local_to_board_position(local_position)
	var objects := _active_scene_objects()
	var interactive_ids: Array[String] = []
	var passive_ids: Array[String] = []
	for index in range(objects.size() - 1, -1, -1):
		var object_data: Dictionary = objects[index]
		if _interaction_rect_for_object(object_data).has_point(board_position):
			var object_id := str(object_data.get("id", ""))
			if object_id.is_empty():
				continue
			if bool(object_data.get("interactive", true)):
				if not interactive_ids.has(object_id):
					interactive_ids.append(object_id)
			elif not interactive_only and not passive_ids.has(object_id):
				passive_ids.append(object_id)
	if not interactive_only:
		interactive_ids.append_array(passive_ids)
	return interactive_ids


# Returns canvas-owned view data only; this is not a simulation source.
func current_view_snapshot() -> Dictionary:
	_update_camera_target_if_needed()
	var current_board_rect := _board_screen_rect(camera_offset, camera_zoom)
	var target_board_rect := _board_screen_rect(target_camera_offset, target_camera_zoom)
	var outcome_view := _scene_outcome_view_snapshot()
	return {
		"environment_id": environment_id,
		"environment_name": environment_name,
		"scenario_presentation": scenario_presentation.duplicate(true),
		"scenario_palette_active": scenario_palette_overlay.a > 0.0,
		"scenario_crowd_count": scenario_crowd_count,
		"scenario_signage": scenario_signage,
		"suspicion_level": suspicion_level,
		"drunk_level": drunk_level,
		"drunk_time_scale": drunk_time_scale,
		"drunk_time_scale_percent": int(round(drunk_time_scale * 100.0)),
		"hovered_object_id": hovered_object_id,
		"selected_object_id": selected_object_id,
		"object_labels_and_borders_enabled": object_labels_and_borders_enabled,
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
		"small_screen_mode": small_screen_mode,
		"minimum_environment_hit_size": SmallScreenPolicyScript.environment_hit_size(small_screen_mode),
		"reserved_overlay_global_rect": reserved_overlay_global_rect,
		"overlay_repositioned_object_ids": overlay_repositioned_object_ids.duplicate(),
		"objects": JsonCoerceScript._copy_array(_active_scene_objects()),
		"object_layout": _scene_object_layout_snapshot(_active_scene_objects()),
		"scenario_layout_audit": _copy_dictionary(foundation_snapshot.get("scenario_layout_audit", {})) if uses_foundation_snapshot else {},
		"scenario_layout_authority_digest": str(foundation_snapshot.get("scenario_layout_authority_digest", "")) if uses_foundation_snapshot else "",
		"scenario_layout_evidence": _scenario_layout_evidence(_active_scene_objects()),
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
		"grand_casino_living_floor": _grand_casino_living_floor_snapshot(),
		"grand_casino_staffing": _grand_casino_staffing_snapshot(),
		"grand_casino_entry_cue": foundation_snapshot.get("grand_casino_entry_cue", {}) if uses_foundation_snapshot else {},
		"reduce_motion": reduce_motion,
		"developer_placement": developer_placement_snapshot(),
		"developer_slot_placement": developer_slot_placement_snapshot(),
	}


# Hot-path camera diagnostics used while measuring or polling a focus glide.
# The full public snapshot intentionally includes deep object/layout evidence;
# callers that need only target stability must not rebuild that O(n^2) audit on
# every animation frame.
func focus_runtime_status() -> Dictionary:
	_update_camera_target_if_needed()
	return {
		"camera_target_refresh_count": camera_target_refresh_count,
		"target_camera_offset": target_camera_offset,
		"target_camera_zoom": target_camera_zoom,
	}


func local_position_for_selected_info_action_button(action_index: int = 0) -> Vector2:
	var info := _selected_object_info()
	if info.is_empty():
		return Vector2(-1.0, -1.0)
	var entries := _selected_info_action_entries_for_rect(info, _animated_info_card_rect(info))
	if action_index < 0 or action_index >= entries.size() or typeof(entries[action_index]) != TYPE_DICTIONARY:
		return Vector2(-1.0, -1.0)
	var button_rect: Rect2 = (entries[action_index] as Dictionary).get("button_rect", Rect2())
	if button_rect.size.x <= 0.0 or button_rect.size.y <= 0.0:
		return Vector2(-1.0, -1.0)
	return _board_to_local_position(button_rect.get_center())


func _gui_input(event: InputEvent) -> void:
	if developer_slot_placement_mode and _handle_developer_slot_placement_input(event):
		accept_event()
		return
	if developer_placement_mode and _handle_developer_placement_input(event):
		accept_event()
		return
	# Authored action bindings own their declared input. Navigation is the
	# fallback only when the selected interaction does not consume the event.
	if _activate_selected_info_action_for_authored_input(event):
		accept_event()
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		var direction := -1 if event.is_action_pressed("ui_left") else 1
		if _cycle_interactive_object(direction):
			accept_event()
			return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		var entries := _selected_info_action_entries_from_info(_selected_object_info())
		if not entries.is_empty():
			var direction := -1 if event.is_action_pressed("ui_up") else 1
			selected_info_action_index = posmod(selected_info_action_index + direction, entries.size())
			accept_event()
			queue_redraw()
			return
	if event.is_action_pressed("ui_accept") and _activate_selected_info_action_by_index():
		accept_event()
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var badge_tooltip := _selected_info_badge_tooltip_at_local_position(motion.position)
		if not badge_tooltip.is_empty():
			tooltip_text = ""
			selected_info_badge_hover_text = badge_tooltip
			selected_info_badge_hover_local_position = motion.position
			_set_hovered_object(selected_object_id)
			mouse_default_cursor_shape = Control.CURSOR_ARROW
			queue_redraw()
			return
		tooltip_text = ""
		if not selected_info_badge_hover_text.is_empty():
			selected_info_badge_hover_text = ""
			queue_redraw()
		if _selected_info_action_button_at_local_position(motion.position):
			_set_hovered_object(selected_object_id)
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			return
		_set_hovered_object(object_id_at_local_position(motion.position))
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
			if _focus_hovered_info_at_local_position(mouse_event.position):
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
			if _focus_hovered_info_at_local_position(touch_event.position):
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


# Buttons inside the placement menu own keyboard focus while they are used.
# F2 must still reach the menu toggle in that state, including when focus has
# moved to the sibling Restore button after minimizing.
func _unhandled_key_input(event: InputEvent) -> void:
	if not _developer_placement_mode_active():
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_F2:
		_toggle_developer_placement_panel_minimized()
		get_viewport().set_input_as_handled()


func _handle_developer_placement_input(event: InputEvent) -> bool:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_F2:
		_toggle_developer_placement_panel_minimized()
		return true
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if developer_placement_dragging:
			_update_developer_placement_preview(_local_to_board_position(motion.position) - developer_placement_drag_offset)
		else:
			_set_hovered_object(_developer_object_id_at_local_position(motion.position))
		return true
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_begin_developer_placement_drag(mouse_event.position)
			else:
				_finish_developer_placement_edit()
			return true
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_cancel_developer_placement_preview()
			return true
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_developer_placement_drag(touch.position)
		else:
			_finish_developer_placement_edit()
		return true
	if event is InputEventScreenDrag:
		if developer_placement_dragging:
			var drag := event as InputEventScreenDrag
			_update_developer_placement_preview(_local_to_board_position(drag.position) - developer_placement_drag_offset)
		return true
	if event.is_action_pressed("ui_cancel"):
		_cancel_developer_placement_preview()
		return true
	if event.is_action_pressed("ui_accept") and developer_placement_pending_rect.has_area():
		_lock_developer_placement()
		return true
	var nudge := Vector2.ZERO
	if event.is_action_pressed("ui_left"):
		nudge.x = -1.0
	elif event.is_action_pressed("ui_right"):
		nudge.x = 1.0
	elif event.is_action_pressed("ui_up"):
		nudge.y = -1.0
	elif event.is_action_pressed("ui_down"):
		nudge.y = 1.0
	if not nudge.is_zero_approx() and not selected_object_id.is_empty():
		if event is InputEventKey and (event as InputEventKey).shift_pressed:
			nudge *= 10.0
		var object_data := _scene_object(selected_object_id)
		if not object_data.is_empty():
			if not developer_placement_original_rect.has_area():
				developer_placement_original_rect = _developer_edit_rect_for_object(object_data)
			var current_rect := developer_placement_pending_rect if developer_placement_pending_rect.has_area() else _developer_edit_rect_for_object(object_data)
			_update_developer_placement_preview(current_rect.position + nudge)
		return true
	return false


func _developer_object_id_at_local_position(local_position: Vector2) -> String:
	var board_position := _local_to_board_position(local_position)
	var objects := _active_scene_objects()
	for index in range(objects.size() - 1, -1, -1):
		if typeof(objects[index]) != TYPE_DICTIONARY:
			continue
		var object_data := objects[index] as Dictionary
		if _developer_edit_rect_for_object(object_data).has_point(board_position):
			return str(object_data.get("id", ""))
	return ""


func _begin_developer_placement_drag(local_position: Vector2) -> void:
	var object_id := _developer_object_id_at_local_position(local_position)
	if object_id.is_empty():
		_finish_developer_placement_edit()
		set_selected_object("")
		_update_developer_placement_panel()
		return
	if object_id != selected_object_id:
		_finish_developer_placement_edit()
		set_selected_object(object_id, false)
	var object_data := _scene_object(object_id)
	if object_data.is_empty():
		return
	var rect := developer_placement_pending_rect if developer_placement_pending_rect.has_area() else _developer_edit_rect_for_object(object_data)
	if not developer_placement_original_rect.has_area():
		developer_placement_original_rect = rect
	developer_placement_pending_rect = rect
	developer_placement_drag_offset = _local_to_board_position(local_position) - rect.position
	developer_placement_dragging = true
	_validate_developer_placement_preview()


func _update_developer_placement_preview(top_left: Vector2) -> void:
	var object_data := _scene_object(selected_object_id)
	if object_data.is_empty():
		return
	var size_value := developer_placement_pending_rect.size if developer_placement_pending_rect.has_area() else _developer_edit_rect_for_object(object_data).size
	var bounded := Vector2(
		clampf(top_left.x, 0.0, maxf(0.0, BOARD_SIZE.x - size_value.x)),
		clampf(top_left.y, 0.0, maxf(0.0, BOARD_SIZE.y - size_value.y))
	)
	var next_rect := Rect2(bounded.round(), size_value)
	if developer_placement_pending_rect.has_area() and developer_placement_pending_rect.is_equal_approx(next_rect):
		return
	developer_placement_pending_rect = next_rect
	_validate_developer_placement_preview(not developer_placement_dragging)
	_queue_developer_drag_redraw()


func _set_developer_preview_object_rect(rect: Rect2) -> void:
	for index in range(foundation_scene_objects.size()):
		if typeof(foundation_scene_objects[index]) != TYPE_DICTIONARY:
			continue
		var current := foundation_scene_objects[index] as Dictionary
		if str(current.get("id", "")) != selected_object_id:
			continue
		var current_position_value: Variant = current.get("position", Vector2.ZERO)
		var current_position: Vector2 = current_position_value if typeof(current_position_value) == TYPE_VECTOR2 else Vector2.ZERO
		var current_size_value: Variant = current.get("size", Vector2.ZERO)
		var current_size: Vector2 = current_size_value if typeof(current_size_value) == TYPE_VECTOR2 else Vector2.ZERO
		var target_position := rect.get_center() / Vector2(BOARD_SIZE)
		if current_position.is_equal_approx(target_position) and current_size.is_equal_approx(rect.size):
			return
		var object_data := current.duplicate(false)
		object_data["position"] = target_position
		object_data["size"] = rect.size
		foundation_scene_objects[index] = object_data
		break
	_rebuild_scene_object_cache()
	_invalidate_camera_target()
	_update_camera_target_if_needed()


func _developer_placement_surface_map() -> Dictionary:
	if not developer_placement_surface_map_cache_valid:
		developer_placement_surface_map_cache = EnvironmentPlacementScript.surface_map(_developer_slot_environment())
		developer_placement_surface_map_cache_valid = true
	return developer_placement_surface_map_cache


func _ensure_room_surface_draw_cache() -> void:
	if room_surface_draw_cache_valid:
		return
	room_surface_slots_by_id_cache = {}
	room_surface_counters_by_id_cache = {}
	room_foreground_counters_cache = []
	var surface_map := _developer_placement_surface_map()
	for field in SLOT_COLLECTION_FIELDS:
		for slot_value in _array_view(surface_map.get(field, [])):
			if typeof(slot_value) != TYPE_DICTIONARY:
				continue
			var slot := slot_value as Dictionary
			room_surface_slots_by_id_cache[str(slot.get("id", ""))] = slot
	for counter_value in _array_view(surface_map.get("counters", [])):
		if typeof(counter_value) != TYPE_DICTIONARY:
			continue
		var counter := counter_value as Dictionary
		room_surface_counters_by_id_cache[str(counter.get("id", ""))] = counter
		if not str(counter.get("foreground_art_id", "")).is_empty():
			room_foreground_counters_cache.append(counter)
	room_foreground_counters_cache.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		return str((left_value as Dictionary).get("id", "")) < str((right_value as Dictionary).get("id", ""))
	)
	room_surface_draw_cache_valid = true


func _validate_developer_placement_preview(refresh_panel: bool = true) -> void:
	developer_placement_valid = false
	developer_placement_surface_id = ""
	developer_placement_overlap_ids.clear()
	var object_data := _scene_object(selected_object_id)
	if object_data.is_empty() or not developer_placement_pending_rect.has_area():
		if refresh_panel:
			_update_developer_placement_panel()
		return
	var placement_class := str(object_data.get("placement_class", "")).strip_edges()
	if placement_class.is_empty():
		placement_class = EnvironmentPlacementScript.classify(object_data, str(object_data.get("interaction_type", object_data.get("type", ""))), selected_object_id, str(object_data.get("prop", object_data.get("icon_key", ""))))
	var support := EnvironmentPlacementScript.support_for_rect_on_surfaces(_developer_placement_surface_map(), placement_class, developer_placement_pending_rect)
	# Developer placement is direct composition authoring. Physical surfaces and
	# overlaps remain useful diagnostics, but they never veto an intentional
	# in-bounds coordinate selected by the owner.
	developer_placement_valid = Rect2(Vector2.ZERO, Vector2(BOARD_SIZE)).encloses(developer_placement_pending_rect)
	developer_placement_surface_id = str(support.get("surface_id", ""))
	for other_value in _active_scene_objects():
		if typeof(other_value) != TYPE_DICTIONARY:
			continue
		var other := other_value as Dictionary
		var other_id := str(other.get("id", ""))
		if other_id.is_empty() or other_id == selected_object_id:
			continue
		if developer_placement_pending_rect.intersects(_developer_edit_rect_for_object(other)):
			developer_placement_overlap_ids.append(other_id)
	if refresh_panel:
		_update_developer_placement_panel()


func _cancel_developer_placement_preview() -> void:
	clear_developer_placement_preview()


func _finish_developer_placement_edit() -> void:
	developer_placement_dragging = false
	if not developer_placement_pending_rect.has_area():
		_update_developer_placement_panel()
		return
	var changed := not developer_placement_original_rect.has_area() \
			or not developer_placement_pending_rect.position.is_equal_approx(developer_placement_original_rect.position) \
			or not developer_placement_pending_rect.size.is_equal_approx(developer_placement_original_rect.size)
	if changed and developer_placement_valid:
		_lock_developer_placement()
		return
	clear_developer_placement_preview()


func _developer_edit_rect_for_object(object_data: Dictionary) -> Rect2:
	# Small-screen expansion and actor-route animation are presentation
	# derivatives. Author only the canonical 900x430 placement rectangle.
	if developer_placement_mode and developer_placement_pending_rect.has_area() \
			and str(object_data.get("id", "")) == selected_object_id:
		return developer_placement_pending_rect
	return _board_rect_for_object_at_position(object_data, object_data.get("position", Vector2(0.5, 0.5)))


func _lock_developer_placement() -> void:
	if not developer_placement_valid or not developer_placement_pending_rect.has_area():
		return
	var request := _developer_placement_request()
	request["defer_refresh"] = true
	var render_generation := environment_snapshot_render_generation
	clear_developer_placement_preview(false, false)
	developer_placement_lock_requested.emit(request)
	if _developer_placement_lock_failed(request):
		return
	if environment_snapshot_render_generation == render_generation:
		developer_placement_authority_dirty = true
		_invalidate_developer_placement_geometry_caches()
		_update_developer_placement_panel()
	# Normal locks update locally and defer the authoritative room rebuild. Keep
	# the exact accepted position visible; this also protects against a custom
	# synchronous host returning a stale interaction projection.
	_apply_saved_developer_placement(request)


func _save_developer_placement_to_project() -> void:
	# This is intentionally one gesture. Previously this button promoted only an
	# older locked value, so a newly dragged preview disappeared on the next room
	# refresh even though the player had just asked to save it to the project.
	var saved_request: Dictionary = {}
	var render_generation := environment_snapshot_render_generation
	if developer_placement_pending_rect.has_area():
		if not developer_placement_valid:
			return
		saved_request = _developer_placement_request()
		saved_request["defer_refresh"] = true
		clear_developer_placement_preview(false, false)
		developer_placement_lock_requested.emit(saved_request)
		if _developer_placement_lock_failed(saved_request):
			return
	developer_placement_promote_requested.emit()
	if environment_snapshot_render_generation == render_generation:
		developer_placement_authority_dirty = true
		_invalidate_developer_placement_geometry_caches()
		_update_developer_placement_panel()
	if not saved_request.is_empty():
		_apply_saved_developer_placement(saved_request)


func _developer_placement_lock_failed(request: Dictionary) -> bool:
	return bool(request.get("_placement_lock_handled", false)) \
		and not bool(request.get("_placement_lock_persisted", false))


func _apply_saved_developer_placement(request: Dictionary) -> void:
	var object_id := str(request.get("object_id", "")).strip_edges()
	if object_id.is_empty() or object_id != selected_object_id:
		return
	var object_data := _scene_object(object_id)
	if object_data.is_empty():
		return
	var position_value: Variant = request.get("preview_top_left", request.get("position", Vector2.ZERO))
	if typeof(position_value) != TYPE_VECTOR2:
		return
	var size_value: Variant = request.get("size", Vector2.ZERO)
	var size: Vector2 = size_value if typeof(size_value) == TYPE_VECTOR2 else Vector2.ZERO
	if size.x <= 0.0 or size.y <= 0.0:
		size = _developer_edit_rect_for_object(object_data).size
	_set_developer_preview_object_rect(Rect2(position_value as Vector2, size))
	queue_redraw()


func _reset_developer_placement() -> void:
	var request := _developer_placement_request()
	if request.is_empty():
		return
	var render_generation := environment_snapshot_render_generation
	clear_developer_placement_preview(false, false)
	developer_placement_reset_requested.emit(request)
	if environment_snapshot_render_generation == render_generation:
		_invalidate_developer_placement_geometry_caches()
		_update_developer_placement_panel()
		queue_redraw()


func _developer_slot_environment() -> Dictionary:
	return {
		"archetype_id": str(foundation_snapshot.get("archetype_id", foundation_snapshot.get("id", environment_id))),
		"current_layer_id": str(foundation_snapshot.get("current_layer_id", foundation_snapshot.get("layer_id", ""))),
		"scenario_id": str(foundation_snapshot.get("scenario_id", "")),
		"scenario_state": _copy_dictionary(foundation_snapshot.get("scenario_state", {})),
		"scenario_sequence_state": _copy_dictionary(foundation_snapshot.get("scenario_sequence_state", {})),
	}


func _developer_slots(include_hidden: bool = false) -> Array:
	if foundation_snapshot.is_empty() and environment_id.is_empty():
		return []
	var available_slots := _developer_available_slots()
	if include_hidden:
		return available_slots
	if developer_visible_slots_cache_valid:
		return developer_visible_slots_cache
	var slots: Array = []
	for slot_value in available_slots:
		var slot := slot_value as Dictionary
		if _developer_slot_visible_in_preview(slot):
			slots.append(slot)
	developer_visible_slots_cache = slots
	developer_visible_slots_cache_valid = true
	return developer_visible_slots_cache


func _developer_available_slots() -> Array:
	_ensure_developer_slot_cache()
	if developer_available_slots_cache_valid:
		return developer_available_slots_cache
	var slots: Array = []
	for slot_value in developer_slots_cache:
		var slot := slot_value as Dictionary
		if _developer_slot_family_available(_developer_slot_family(slot)):
			slots.append(slot)
	developer_available_slots_cache = slots
	developer_available_slots_cache_valid = true
	return developer_available_slots_cache


func _developer_authored_slots() -> Array:
	_ensure_developer_slot_cache()
	return developer_slots_cache


func _ensure_developer_slot_cache() -> void:
	if developer_slots_cache_valid:
		return
	developer_slot_cache_rebuild_count += 1
	var surface_map := _developer_placement_surface_map()
	var slots: Array = []
	var slots_by_id: Dictionary = {}
	var slot_rects_by_id: Dictionary = {}
	var slot_positions_by_id: Dictionary = {}
	for field in SLOT_COLLECTION_FIELDS:
		for slot_value in _array_view(surface_map.get(field, [])):
			if typeof(slot_value) != TYPE_DICTIONARY:
				continue
			var slot := slot_value as Dictionary
			var slot_id := str(slot.get("id", "")).strip_edges()
			if slot_id.is_empty():
				continue
			slots.append(slot)
			slots_by_id[slot_id] = slot
			var position := _developer_slot_position(slot)
			var rect_values := _array_view(slot.get("hit_rect", []))
			var rect := Rect2(position - Vector2(22.0, 22.0), Vector2(44.0, 44.0))
			if rect_values.size() >= 4:
				rect = Rect2(float(rect_values[0]), float(rect_values[1]), float(rect_values[2]), float(rect_values[3]))
			slot_positions_by_id[slot_id] = position
			slot_rects_by_id[slot_id] = rect
	slots.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left := left_value as Dictionary
		var right := right_value as Dictionary
		var left_kind := str(left.get("kind", ""))
		var right_kind := str(right.get("kind", ""))
		return str(left.get("id", "")) < str(right.get("id", "")) if left_kind == right_kind else left_kind < right_kind
	)
	developer_slots_cache = slots
	developer_slots_by_id_cache = slots_by_id
	developer_slot_rects_by_id_cache = slot_rects_by_id
	developer_slot_positions_by_id_cache = slot_positions_by_id
	developer_slots_cache_valid = true


func _developer_slot_active_family() -> String:
	if bool(developer_slot_family_filters.get("all", false)):
		return "all"
	for family_value in SLOT_FAMILIES:
		var family := str(family_value)
		if bool(developer_slot_family_filters.get(family, false)):
			return family
	return "fixed"


func _developer_slot_visible_in_preview(slot: Dictionary) -> bool:
	if not _developer_slot_family_visible(_developer_slot_family(slot)):
		return false
	return _developer_slot_visible_by_detail(slot)


func _developer_slot_visible_by_detail(slot: Dictionary) -> bool:
	if not _developer_slot_occupant_records(str(slot.get("id", ""))).is_empty():
		return true
	if _developer_slot_is_required(slot):
		return true
	if _developer_slot_is_runtime_reserve(slot):
		return developer_slot_show_runtime_reserves
	return developer_slot_show_empty_capacity


func _developer_slot_is_runtime_reserve(slot: Dictionary) -> bool:
	if bool(slot.get("runtime_reserve", false)):
		return true
	var capacity_role := str(slot.get("capacity_role", "")).strip_edges().to_lower()
	if capacity_role == "runtime_reserve":
		return true
	var metadata := _copy_dictionary(slot.get("metadata", {}))
	return bool(metadata.get("runtime_reserve", false)) \
			or str(metadata.get("capacity_role", "")).strip_edges().to_lower() == "runtime_reserve"


func _developer_slot_reserve_reason(slot: Dictionary) -> String:
	var reason := str(slot.get("reserve_reason", "")).strip_edges()
	if reason.is_empty():
		reason = str(_copy_dictionary(slot.get("metadata", {})).get("reserve_reason", "")).strip_edges()
	return reason.replace("_", " ").capitalize()


func _developer_slot_is_required(slot: Dictionary) -> bool:
	if bool(slot.get("occupancy_required", false)):
		return true
	var slot_id := str(slot.get("id", "")).strip_edges()
	if scene_object_cache_valid:
		return developer_required_slot_ids_cache.has(slot_id)
	for row_value in _developer_manifest_rows():
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row := row_value as Dictionary
		if bool(row.get("active", true)) and bool(row.get("physical", true)) \
				and bool(row.get("required", false)) \
				and str(row.get("exact_slot_id", "")).strip_edges() == slot_id:
			return true
	for occupant_value in _developer_slot_occupant_records(slot_id):
		if typeof(occupant_value) == TYPE_DICTIONARY \
				and bool((occupant_value as Dictionary).get("manifest_required", false)):
			return true
	return false


func _developer_slot_family_counts(family: String) -> Dictionary:
	var total := 0
	var visible := 0
	for slot_value in _developer_slots(true):
		var slot := slot_value as Dictionary
		if family != "all" and _developer_slot_family(slot) != family:
			continue
		total += 1
		if _developer_slot_visible_by_detail(slot):
			visible += 1
	return {"visible": visible, "total": total}


func _update_developer_slot_filter_labels() -> void:
	var required_review_families := _developer_slot_required_review_families()
	var family_labels := {
		"fixed": "Fixed",
		"event": "Events",
		"scenario": "Scenario",
		"exit": "Exits",
		"all": "All",
	}
	for family_value in SLOT_FILTER_OPTIONS:
		var family := str(family_value)
		var button_value: Variant = developer_slot_filter_buttons.get(family)
		if not (button_value is BaseButton):
			continue
		var available := family == "all" or _developer_slot_family_available(family)
		(button_value as BaseButton).visible = available
		(button_value as BaseButton).disabled = not available
		var counts := _developer_slot_family_counts(family)
		var review_status := "All available families" if family == "all" else "Optional"
		if family != "all" and required_review_families.has(family):
			review_status = "Reviewed" if bool(developer_slot_reviewed_families.get(family, false)) else "TODO"
		(button_value as BaseButton).text = str(family_labels.get(family, family.capitalize()))
		(button_value as BaseButton).tooltip_text = "%s slots: %d/%d shown. Review: %s." % [
			family.capitalize(),
			int(counts.get("visible", 0)),
			int(counts.get("total", 0)),
			review_status,
		]


func _developer_slot_preview_context() -> Dictionary:
	var sequence_state := _copy_dictionary(foundation_snapshot.get("scenario_sequence_state", {}))
	var scenario_state := _copy_dictionary(foundation_snapshot.get("scenario_state", {}))
	var projection := _copy_dictionary(foundation_snapshot.get("scenario_sequence_projection", {}))
	# Use the same layer-aware scenario identity as placement composition and
	# persistence. A club scenario cursor can remain in run state while the
	# player views the casino floor, but it is not the active placement context.
	var scenario_id := EnvironmentPlacementScript.active_scenario_id(foundation_snapshot)
	var scenario_name := str(foundation_snapshot.get("scenario_display_name", scenario_state.get("display_name", ""))).strip_edges()
	if scenario_name.is_empty():
		scenario_name = _developer_friendly_identifier(scenario_id)
	var phase_id := str(projection.get("phase_id", sequence_state.get("phase_id", ""))).strip_edges()
	var status := str(projection.get("status", sequence_state.get("status", ""))).strip_edges()
	var resolved_outcomes := _array_view(projection.get("resolved_outcomes", sequence_state.get("resolved_outcomes", [])))
	var outcome_id := str(resolved_outcomes.back()).strip_edges() if not resolved_outcomes.is_empty() else ""
	var label := "Active preview: no scenario"
	if not scenario_id.is_empty():
		label = "Active preview: %s" % scenario_name
		if not phase_id.is_empty():
			label += " · %s" % _developer_friendly_identifier(phase_id)
		elif not outcome_id.is_empty():
			label += " · Aftermath: %s" % _developer_friendly_identifier(outcome_id)
		elif not status.is_empty() and status.to_lower() != "active":
			label += " · %s" % _developer_friendly_identifier(status)
	return {
		"scenario_id": scenario_id,
		"scenario_name": scenario_name,
		"phase_id": phase_id,
		"status": status,
		"outcome_id": outcome_id,
		"label": label,
	}


func _developer_friendly_identifier(value: String) -> String:
	var friendly := value.strip_edges().replace("_", " ").replace("-", " ")
	return friendly.capitalize() if not friendly.is_empty() else ""


func _developer_slot(slot_id: String) -> Dictionary:
	var clean_id := slot_id.strip_edges()
	if clean_id.is_empty() or (foundation_snapshot.is_empty() and environment_id.is_empty()):
		return {}
	_ensure_developer_slot_cache()
	var slot_value: Variant = developer_slots_by_id_cache.get(clean_id, {})
	return slot_value as Dictionary if typeof(slot_value) == TYPE_DICTIONARY else {}


func _developer_slot_rect(slot: Dictionary) -> Rect2:
	var slot_id := str(slot.get("id", "")).strip_edges()
	var cached_value: Variant = developer_slot_rects_by_id_cache.get(slot_id)
	if typeof(cached_value) == TYPE_RECT2:
		return cached_value
	var values := _array_view(slot.get("hit_rect", []))
	if values.size() >= 4:
		return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
	var position := _developer_slot_position(slot)
	return Rect2(position - Vector2(22.0, 22.0), Vector2(44.0, 44.0))


func _developer_slot_position(slot: Dictionary) -> Vector2:
	var slot_id := str(slot.get("id", "")).strip_edges()
	var cached_value: Variant = developer_slot_positions_by_id_cache.get(slot_id)
	if typeof(cached_value) == TYPE_VECTOR2:
		return cached_value
	var values := _array_view(slot.get("pos", []))
	if values.size() < 2:
		return Vector2.ZERO
	return Vector2(float(values[0]), float(values[1]))


func _developer_slot_occupants(slot_id: String) -> Array[String]:
	var occupants: Array[String] = []
	for object_data in _developer_slot_occupant_records(slot_id):
		var label := str(object_data.get("label", "")).strip_edges()
		if label.is_empty():
			label = _developer_friendly_identifier(str(object_data.get("id", "object")).get_slice(":", 1))
		if label.is_empty():
			label = "Object"
		if not occupants.has(label):
			occupants.append(label)
	occupants.sort()
	return occupants


func _developer_slot_occupant_records(slot_id: String) -> Array:
	if scene_object_cache_valid:
		var cached_value: Variant = developer_slot_occupants_by_id_cache.get(slot_id, [])
		return cached_value as Array if typeof(cached_value) == TYPE_ARRAY else []
	var occupants: Array = []
	for object_value in foundation_scene_objects:
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data := object_value as Dictionary
		if str(object_data.get("slot_id", "")) == slot_id:
			occupants.append(object_data)
	return occupants


func _developer_slot_primary_label(slot: Dictionary) -> String:
	var label := _developer_slot_unqualified_label(slot)
	if not bool(slot.get("scenario_instance", false)) or not _developer_slot_label_repeats(label, slot):
		return label
	var qualifier := _developer_slot_zone_label(slot)
	if qualifier.is_empty():
		qualifier = "Position %d" % int(slot.get("scenario_ordinal", 0))
	elif _developer_slot_label_and_zone_repeat(label, qualifier, slot):
		qualifier += " %d" % int(slot.get("scenario_ordinal", 0))
	return "%s - %s" % [label, qualifier]


func _developer_slot_unqualified_label(slot: Dictionary) -> String:
	var occupants := _developer_slot_occupants(str(slot.get("id", "")))
	if occupants.size() == 1:
		return occupants[0]
	if occupants.size() > 1:
		return "%s +%d" % [occupants[0], occupants.size() - 1]
	if bool(slot.get("scenario_instance", false)):
		var claimant_labels := _developer_slot_claimant_labels(slot)
		if claimant_labels.size() == 1:
			return claimant_labels[0]
		if claimant_labels.size() > 1:
			var alternate_count := claimant_labels.size() - 1
			return "%s (+%d alternate%s)" % [
				claimant_labels[0],
				alternate_count,
				"" if alternate_count == 1 else "s",
			]
	return _developer_slot_capacity_label(slot)


func _developer_slot_label_repeats(label: String, slot: Dictionary) -> bool:
	var normalized := label.strip_edges().to_lower()
	if normalized.is_empty():
		return false
	for candidate_value in _developer_slots(true):
		var candidate := candidate_value as Dictionary
		if str(candidate.get("id", "")) == str(slot.get("id", "")) \
				or not bool(candidate.get("scenario_instance", false)):
			continue
		if _developer_slot_unqualified_label(candidate).strip_edges().to_lower() == normalized:
			return true
	return false


func _developer_slot_label_and_zone_repeat(label: String, qualifier: String, slot: Dictionary) -> bool:
	var normalized_label := label.strip_edges().to_lower()
	var normalized_zone := qualifier.strip_edges().to_lower()
	for candidate_value in _developer_slots(true):
		var candidate := candidate_value as Dictionary
		if str(candidate.get("id", "")) == str(slot.get("id", "")) \
				or not bool(candidate.get("scenario_instance", false)):
			continue
		if _developer_slot_unqualified_label(candidate).strip_edges().to_lower() == normalized_label \
				and _developer_slot_zone_label(candidate).strip_edges().to_lower() == normalized_zone:
			return true
	return false


func _developer_slot_zone_label(slot: Dictionary) -> String:
	var zone_ids := _array_view(slot.get("scenario_zone_ids", []))
	var zone_id := str(zone_ids[0]).strip_edges() if not zone_ids.is_empty() else ""
	if zone_id.is_empty():
		zone_id = str(slot.get("zone_id", "")).strip_edges()
	return _developer_friendly_identifier(zone_id)


func _developer_slot_capacity_label(slot: Dictionary) -> String:
	var physical_role := str(slot.get("physical_role", "")).strip_edges()
	var slot_id := str(slot.get("id", "")).strip_edges()
	var family := _developer_slot_family(slot)
	var identity := slot_id.get_slice(".", 1) if slot_id.contains(".") else slot_id
	var suffix := identity.get_slice("_", identity.get_slice_count("_") - 1)
	if not physical_role.is_empty():
		if suffix.is_valid_int() and not physical_role.ends_with(" %s" % suffix):
			return "%s %s" % [physical_role, suffix]
		return physical_role
	if family in ["fixed", "exit"]:
		return _developer_friendly_identifier(identity)
	var placement_class := str(slot.get("footprint_class", "capacity")).strip_edges()
	var label := _developer_friendly_identifier(placement_class)
	if suffix.is_valid_int():
		label += " %s" % suffix
	return label


func _developer_slot_known_claimants(slot: Dictionary) -> Array[String]:
	var claimants: Array[String] = []
	for claimant_value in _array_view(slot.get("occupant_ids", [])):
		var claimant := str(claimant_value).strip_edges()
		if not claimant.is_empty() and not claimants.has(claimant):
			claimants.append(claimant)
	claimants.sort()
	return claimants


func _developer_slot_claimant_labels(slot: Dictionary) -> Array[String]:
	# Room-shared slots already lead with the live occupant when one exists and
	# otherwise use their authored capacity role. Their raw occupant_ids are
	# stable migration/runtime aliases, not owner-facing names. Exact scenario
	# slots carry explicit scenario_occupant_labels and retain this detail.
	if not bool(slot.get("scenario_instance", false)):
		return []
	var candidates: Array[Dictionary] = []
	var authored_labels := _array_view(slot.get("scenario_occupant_labels", []))
	for label_value in authored_labels:
		var authored_label := str(label_value).strip_edges()
		if authored_label.is_empty():
			continue
		candidates.append({
			"label": authored_label,
			"priority": 10 if authored_label.to_lower().begins_with("aftermath:") else 0,
		})
	var scenario_id := str(slot.get("scenario_id", "")).strip_edges()
	if candidates.is_empty():
		for claimant in _developer_slot_known_claimants(slot):
			var label := _developer_slot_claimant_label(claimant, scenario_id)
			if label.is_empty():
				continue
			candidates.append({
				"label": label,
				"priority": 10 if claimant.to_lower().contains("aftermath_") else 0,
			})
	candidates.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left := left_value as Dictionary
		var right := right_value as Dictionary
		var left_priority := int(left.get("priority", 0))
		var right_priority := int(right.get("priority", 0))
		return str(left.get("label", "")) < str(right.get("label", "")) if left_priority == right_priority else left_priority < right_priority
	)
	var labels: Array[String] = []
	var normalized_labels: Dictionary = {}
	for candidate in candidates:
		var label := str(candidate.get("label", ""))
		var normalized := label.strip_edges().to_lower()
		if normalized.is_empty() or normalized_labels.has(normalized):
			continue
		normalized_labels[normalized] = true
		labels.append(label)
	return labels


func _developer_slot_claimant_label(claimant_id: String, scenario_id: String) -> String:
	var identity := claimant_id.strip_edges()
	if identity.begins_with("meta_sal_shelf:"):
		var shelf_index := identity.get_slice(":", 1)
		if shelf_index.is_valid_int():
			return "Sal's Shelf Slot %d" % (int(shelf_index) + 1)
	if _developer_slot_claimant_is_action_only(identity):
		return ""
	var double_separator := identity.find("::")
	if double_separator >= 0:
		identity = identity.substr(double_separator + 2)
	else:
		var separator := identity.find(":")
		if separator >= 0:
			identity = identity.substr(separator + 1)
	var scenario_prefix := "%s_" % scenario_id
	if not scenario_id.is_empty() and identity.begins_with(scenario_prefix):
		identity = identity.trim_prefix(scenario_prefix)
	if identity.begins_with("scenario_"):
		identity = identity.trim_prefix("scenario_")
	var aftermath := identity.begins_with("aftermath_")
	if aftermath:
		identity = identity.trim_prefix("aftermath_")
	for suffix in ["_actor", "_prop"]:
		if identity.ends_with(suffix):
			identity = identity.left(identity.length() - suffix.length())
	var label := _developer_friendly_identifier(identity)
	return "Aftermath: %s" % label if aftermath and not label.is_empty() else label


func _developer_slot_claimant_is_action_only(identity: String) -> bool:
	var tokens := identity.to_lower().split("_", false)
	var count := tokens.size()
	if count >= 2 and tokens[count - 2] == "task" and tokens[count - 1].is_valid_int():
		return true
	return count >= 4 \
		and tokens[count - 4] == "work" \
		and tokens[count - 3].is_valid_int() \
		and tokens[count - 2] == "choice" \
		and tokens[count - 1].is_valid_int()


func _developer_slot_family(slot: Dictionary) -> String:
	var family := str(slot.get("kind", "")).strip_edges().to_lower()
	if family in SLOT_FAMILIES:
		return family
	var slot_id := str(slot.get("id", "")).strip_edges().to_lower()
	var separator := slot_id.find(".")
	if separator > 0:
		family = slot_id.left(separator)
	return family if family in SLOT_FAMILIES else "unknown"


func _developer_slot_family_visible(family: String) -> bool:
	return bool(developer_slot_family_filters.get(family, false))


func _developer_slot_family_color(family: String) -> Color:
	match family:
		"fixed": return C_CYAN
		"event": return C_AMBER
		"scenario": return C_PURPLE_2
		"exit": return C_PINK
	return C_SOFT


func _developer_manifest_rows() -> Array:
	var manifest_value: Variant = foundation_snapshot.get("object_manifest", {})
	if typeof(manifest_value) != TYPE_DICTIONARY:
		return []
	return _array_view((manifest_value as Dictionary).get("rows", []))


func _developer_slot_state(slot: Dictionary, comparison_slots: Array = []) -> Dictionary:
	var slot_id := str(slot.get("id", "")).strip_edges()
	var family := _developer_slot_family(slot)
	var placement_class := str(slot.get("footprint_class", "")).strip_edges()
	var support_id := str(slot.get("support_id", "")).strip_edges()
	var required := _developer_slot_is_required(slot)
	var occupants := _developer_slot_occupant_records(slot_id)
	var warnings: Array[String] = []
	if str(slot.get("kind", family)).strip_edges().to_lower() != family:
		warnings.append("kind/prefix mismatch")
	if required and occupants.is_empty():
		warnings.append("required occupant missing")
	if occupants.size() > 1:
		warnings.append("multiple occupants")
	var slot_rect := _developer_slot_rect(slot)
	var diagnose_overlap := slot_id == developer_slot_selected_id or _developer_slot_is_context_active(slot)
	if diagnose_overlap:
		var slots_to_compare := comparison_slots if not comparison_slots.is_empty() else _developer_slot_overlap_candidates(slot_id)
		for other_value in slots_to_compare:
			var other := other_value as Dictionary
			var other_id := str(other.get("id", ""))
			if other_id != slot_id \
					and _developer_slot_is_context_active(slot) \
					and _developer_slot_is_context_active(other) \
					and slot_rect.intersects(_developer_slot_rect(other)):
				warnings.append("overlaps %s" % other_id)
				break
	for occupant_value in occupants:
		var occupant := occupant_value as Dictionary
		var occupant_family := str(occupant.get("manifest_family", occupant.get("slot_family", ""))).strip_edges().to_lower()
		if occupant_family.is_empty():
			var occupant_slot := str(occupant.get("slot_id", ""))
			var separator := occupant_slot.find(".")
			if separator > 0:
				occupant_family = occupant_slot.left(separator)
		if not occupant_family.is_empty() and occupant_family != family:
			warnings.append("family crossover: %s" % occupant_family)
		var occupant_class := str(occupant.get("placement_class", "")).strip_edges()
		if not placement_class.is_empty() and not occupant_class.is_empty() and occupant_class != placement_class:
			warnings.append("class mismatch: %s" % occupant_class)
		var metadata := _copy_dictionary(occupant.get("manifest_metadata", {}))
		var occupant_support := str(occupant.get("support_id", metadata.get("support_id", ""))).strip_edges()
		if not support_id.is_empty() and not occupant_support.is_empty() and occupant_support != support_id:
			warnings.append("support mismatch: %s" % occupant_support)
	return {
		"family": family,
		"required": required,
		"occupants": occupants,
		"warnings": warnings,
	}


func _developer_slot_is_context_active(slot: Dictionary) -> bool:
	var slot_id := str(slot.get("id", "")).strip_edges()
	return _developer_slot_is_required(slot) or not _developer_slot_occupant_records(slot_id).is_empty()


func _developer_slot_overlap_candidates(selected_slot_id: String = "") -> Array:
	var candidates: Array = []
	for slot_value in _developer_slots(true):
		var slot := slot_value as Dictionary
		var slot_id := str(slot.get("id", ""))
		if slot_id != selected_slot_id:
			candidates.append(slot)
	return candidates


func _developer_slot_overlap_summary() -> Dictionary:
	if developer_slot_overlap_summary_cache_valid:
		return developer_slot_overlap_summary_cache
	developer_slot_overlap_audit_count += 1
	var slots := _developer_slots(true)
	var active_pairs: Array[String] = []
	var alternative_pairs: Array[String] = []
	for left_index in range(slots.size()):
		var left := slots[left_index] as Dictionary
		var left_id := str(left.get("id", ""))
		var left_rect := _developer_slot_rect(left)
		for right_index in range(left_index + 1, slots.size()):
			var right := slots[right_index] as Dictionary
			if not left_rect.intersects(_developer_slot_rect(right)):
				continue
			var right_id := str(right.get("id", ""))
			var pair_label := "%s / %s" % [left_id, right_id]
			if _developer_slot_is_context_active(left) and _developer_slot_is_context_active(right):
				active_pairs.append(pair_label)
			else:
				alternative_pairs.append(pair_label)
	developer_slot_overlap_summary_cache = {
		"active_count": active_pairs.size(),
		"active_pairs": active_pairs,
		"alternative_count": alternative_pairs.size(),
		"alternative_pairs": alternative_pairs,
	}
	developer_slot_overlap_summary_cache_valid = true
	return developer_slot_overlap_summary_cache


func _developer_slot_label_ids() -> Array[String]:
	var result: Array[String] = []
	for slot_id in [developer_slot_selected_id, developer_slot_hovered_id]:
		var clean_id := str(slot_id).strip_edges()
		if clean_id.is_empty() or result.has(clean_id):
			continue
		var slot := _developer_slot(clean_id)
		if not slot.is_empty() and _developer_slot_visible_in_preview(slot):
			result.append(clean_id)
	return result


func _developer_slot_id_at_local_position(local_position: Vector2) -> String:
	var board_position := _local_to_board_position(local_position)
	var selected := _developer_slot(developer_slot_selected_id)
	if not selected.is_empty():
		var selected_rect := developer_slot_pending_rect if developer_slot_pending_rect.has_area() else _developer_slot_rect(selected)
		if selected_rect.has_point(board_position):
			return developer_slot_selected_id
	var slots := _developer_slots()
	for index in range(slots.size() - 1, -1, -1):
		var slot := slots[index] as Dictionary
		if _developer_slot_rect(slot).has_point(board_position):
			return str(slot.get("id", ""))
	return ""


func _handle_developer_slot_placement_input(event: InputEvent) -> bool:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_F2:
		_toggle_developer_placement_panel_minimized()
		return true
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if developer_slot_dragging:
			_update_developer_slot_placement_preview(_local_to_board_position(motion.position) - developer_slot_drag_offset)
		else:
			var hovered_slot_id := _developer_slot_id_at_local_position(motion.position)
			if hovered_slot_id != developer_slot_hovered_id:
				developer_slot_hovered_id = hovered_slot_id
				var hovered_slot := _developer_slot(hovered_slot_id)
				if hovered_slot.is_empty():
					tooltip_text = ""
				else:
					var hover_scope := "SCENARIO-LOCAL" if _developer_slot_scope(hovered_slot) == "scenario_local" else "ROOM-SHARED"
					if not _developer_slot_is_editable(hovered_slot):
						hover_scope += " / LOCKED"
					tooltip_text = "%s\n%s\n%s" % [_developer_slot_primary_label(hovered_slot), hovered_slot_id, hover_scope]
					var known_claimants := _developer_slot_claimant_labels(hovered_slot)
					if not known_claimants.is_empty():
						var shown_claimants := known_claimants.slice(0, mini(5, known_claimants.size()))
						tooltip_text += "\nKnown roles: %s" % ", ".join(shown_claimants)
						if known_claimants.size() > shown_claimants.size():
							tooltip_text += " +%d" % (known_claimants.size() - shown_claimants.size())
				_update_developer_placement_panel()
				queue_redraw()
		return true
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_begin_developer_slot_placement_drag(mouse_event.position)
			else:
				_finish_developer_slot_placement_edit()
			return true
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_cancel_developer_slot_placement_preview()
			return true
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_developer_slot_placement_drag(touch.position)
		else:
			_finish_developer_slot_placement_edit()
		return true
	if event is InputEventScreenDrag:
		if developer_slot_dragging:
			var drag := event as InputEventScreenDrag
			_update_developer_slot_placement_preview(_local_to_board_position(drag.position) - developer_slot_drag_offset)
		return true
	if event.is_action_pressed("ui_cancel"):
		_cancel_developer_slot_placement_preview()
		return true
	if event.is_action_pressed("ui_accept") and developer_slot_pending_rect.has_area():
		_lock_developer_slot_placement()
		return true
	var nudge := Vector2.ZERO
	if event.is_action_pressed("ui_left"):
		nudge.x = -1.0
	elif event.is_action_pressed("ui_right"):
		nudge.x = 1.0
	elif event.is_action_pressed("ui_up"):
		nudge.y = -1.0
	elif event.is_action_pressed("ui_down"):
		nudge.y = 1.0
	if not nudge.is_zero_approx() and not developer_slot_selected_id.is_empty():
		if event is InputEventKey and (event as InputEventKey).shift_pressed:
			nudge *= 10.0
		var slot := _developer_slot(developer_slot_selected_id)
		if not slot.is_empty() and _developer_slot_is_editable(slot):
			if not developer_slot_original_rect.has_area():
				developer_slot_original_rect = _developer_slot_rect(slot)
			var current_rect := developer_slot_pending_rect if developer_slot_pending_rect.has_area() else developer_slot_original_rect
			_update_developer_slot_placement_preview(current_rect.position + nudge)
		return true
	return false


func _begin_developer_slot_placement_drag(local_position: Vector2) -> void:
	var slot_id := _developer_slot_id_at_local_position(local_position)
	if slot_id.is_empty():
		_finish_developer_slot_placement_edit()
		developer_slot_selected_id = ""
		developer_slot_hovered_id = ""
		_update_developer_placement_panel()
		queue_redraw()
		return
	if slot_id != developer_slot_selected_id:
		_finish_developer_slot_placement_edit()
		developer_slot_selected_id = slot_id
	developer_slot_hovered_id = slot_id
	var slot := _developer_slot(slot_id)
	if slot.is_empty():
		return
	if not _developer_slot_is_editable(slot):
		clear_developer_slot_placement_preview()
		developer_slot_selected_id = slot_id
		developer_slot_hovered_id = slot_id
		_update_developer_placement_panel()
		queue_redraw()
		return
	developer_slot_original_rect = _developer_slot_rect(slot)
	developer_slot_pending_rect = developer_slot_original_rect
	developer_slot_pending_position = _developer_slot_position(slot)
	developer_slot_drag_offset = _local_to_board_position(local_position) - developer_slot_original_rect.position
	developer_slot_dragging = true
	_validate_developer_slot_placement_preview()
	queue_redraw()


func _update_developer_slot_placement_preview(top_left: Vector2) -> void:
	var slot := _developer_slot(developer_slot_selected_id)
	if slot.is_empty() or not _developer_slot_is_editable(slot):
		return
	if not developer_slot_original_rect.has_area():
		developer_slot_original_rect = _developer_slot_rect(slot)
	var size_value := developer_slot_original_rect.size
	var bounded := Vector2(
		clampf(top_left.x, 0.0, maxf(0.0, BOARD_SIZE.x - size_value.x)),
		clampf(top_left.y, 0.0, maxf(0.0, BOARD_SIZE.y - size_value.y))
	).round()
	var next_rect := Rect2(bounded, size_value)
	if developer_slot_pending_rect.has_area() and developer_slot_pending_rect.is_equal_approx(next_rect):
		return
	developer_slot_pending_rect = next_rect
	developer_slot_pending_position = _developer_slot_position(slot) + bounded - developer_slot_original_rect.position
	_validate_developer_slot_placement_preview(not developer_slot_dragging)
	_queue_developer_drag_redraw()


func _queue_developer_drag_redraw() -> void:
	developer_drag_redraw_pending = true
	_flush_developer_drag_redraw()


func _flush_developer_drag_redraw() -> void:
	if not developer_drag_redraw_pending:
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec - developer_drag_last_redraw_msec < DEVELOPER_DRAG_REDRAW_INTERVAL_MSEC:
		return
	developer_drag_redraw_pending = false
	developer_drag_last_redraw_msec = now_msec
	queue_redraw()


func _validate_developer_slot_placement_preview(refresh_panel: bool = true) -> void:
	developer_slot_valid = developer_slot_pending_rect.has_area() and Rect2(Vector2.ZERO, Vector2(BOARD_SIZE)).encloses(developer_slot_pending_rect)
	developer_slot_overlap_ids.clear()
	if not developer_slot_valid:
		if refresh_panel:
			_update_developer_placement_panel()
		return
	# Manual placement is the one opportunity to inspect future capacity. Warn
	# against every authored marker in this exact context, including currently
	# empty and injected-content reserves. Ordinary alternative-stage overlap is
	# advisory, but a live route endpoint must remain usable at its expanded
	# small-screen size or scenario finalization would reject the room later.
	for slot_value in _developer_slots(true):
		var slot := slot_value as Dictionary
		var slot_id := str(slot.get("id", ""))
		if slot_id == developer_slot_selected_id:
			continue
		var other_rect := _developer_slot_rect(slot)
		if developer_slot_pending_rect.intersects(other_rect):
			developer_slot_overlap_ids.append(slot_id)
		var route_sensitive := _developer_slot_is_route_endpoint(developer_slot_selected_id) \
				or _developer_slot_is_route_endpoint(slot_id)
		if route_sensitive \
				and (_developer_slot_is_context_active(slot) or _developer_slot_is_route_endpoint(slot_id)) \
				and _developer_slot_rects_meaningfully_intersect(
					_developer_slot_expanded_rect(developer_slot_pending_rect),
					_developer_slot_expanded_rect(other_rect)
				):
			if not developer_slot_overlap_ids.has(slot_id):
				developer_slot_overlap_ids.append(slot_id)
			developer_slot_valid = false
	if refresh_panel:
		_update_developer_placement_panel()


func _developer_slot_is_route_endpoint(slot_id: String) -> bool:
	if slot_id.is_empty():
		return false
	for route_value in _array_view(_developer_placement_surface_map().get("actor_routes", [])):
		if typeof(route_value) != TYPE_DICTIONARY:
			continue
		var route := route_value as Dictionary
		if slot_id in [
			str(route.get("start_slot_id", "")),
			str(route.get("end_slot_id", "")),
			str(route.get("reduced_motion_slot_id", "")),
		]:
			return true
	return false


func _developer_slot_expanded_rect(rect: Rect2) -> Rect2:
	if not rect.has_area():
		return Rect2()
	var minimum := Vector2(SmallScreenPolicyScript.ENVIRONMENT_OBJECT_HIT_SIZE)
	var expanded_size := Vector2(maxf(rect.size.x, minimum.x), maxf(rect.size.y, minimum.y))
	var expanded := Rect2(rect.get_center() - expanded_size * 0.5, expanded_size)
	expanded.position = Vector2(
		clampf(expanded.position.x, 0.0, float(BOARD_SIZE.x) - expanded.size.x),
		clampf(expanded.position.y, 0.0, float(BOARD_SIZE.y) - expanded.size.y)
	)
	return expanded


func _developer_slot_rects_meaningfully_intersect(left: Rect2, right: Rect2) -> bool:
	if not left.has_area() or not right.has_area() or not left.intersects(right):
		return false
	var overlap := left.intersection(right)
	return overlap.size.x > DEVELOPER_ROUTE_COLLISION_EDGE_TOLERANCE \
		and overlap.size.y > DEVELOPER_ROUTE_COLLISION_EDGE_TOLERANCE


func _developer_slot_placement_request() -> Dictionary:
	var slot := _developer_slot(developer_slot_selected_id)
	if slot.is_empty() or not _developer_slot_is_editable(slot):
		return {}
	return {
		"environment": _developer_slot_environment(),
		"field": "slot_positions",
		"slot_id": developer_slot_selected_id,
		"position": developer_slot_pending_position if developer_slot_pending_rect.has_area() else _developer_slot_position(slot),
		"size": _developer_slot_rect(slot).size,
		"slot_kind": str(slot.get("kind", "")),
		"placement_class": str(slot.get("footprint_class", "")),
		"support_id": str(slot.get("support_id", "")),
	}


func _cancel_developer_slot_placement_preview() -> void:
	clear_developer_slot_placement_preview()


func _finish_developer_slot_placement_edit() -> void:
	developer_slot_dragging = false
	if not developer_slot_pending_rect.has_area():
		_update_developer_placement_panel()
		return
	var changed := not developer_slot_pending_rect.position.is_equal_approx(developer_slot_original_rect.position)
	if changed and developer_slot_valid:
		_lock_developer_slot_placement()
		return
	clear_developer_slot_placement_preview()


func _lock_developer_slot_placement() -> void:
	if not developer_slot_valid or not developer_slot_pending_rect.has_area():
		return
	var request := _developer_slot_placement_request()
	request["defer_refresh"] = true
	var render_generation := environment_snapshot_render_generation
	clear_developer_slot_placement_preview(false, false)
	developer_placement_lock_requested.emit(request)
	if _developer_placement_lock_failed(request):
		return
	# Normal locks deliberately defer the authoritative room rebuild. Apply the
	# saved surface map locally, while still avoiding duplicate work if a custom
	# host rendered a fresh snapshot synchronously.
	if environment_snapshot_render_generation == render_generation:
		developer_placement_authority_dirty = true
		_invalidate_developer_placement_geometry_caches()
		if _apply_authoring_slot_positions_to_scene_objects():
			_capture_developer_slot_scene_object_baseline()
		_update_developer_placement_panel()
		queue_redraw()


func _save_developer_slot_placement_to_project() -> void:
	var render_generation := environment_snapshot_render_generation
	if developer_slot_pending_rect.has_area():
		if not developer_slot_valid:
			return
		var request := _developer_slot_placement_request()
		request["defer_refresh"] = true
		clear_developer_slot_placement_preview(false, false)
		developer_placement_lock_requested.emit(request)
		if _developer_placement_lock_failed(request):
			return
	developer_placement_promote_requested.emit()
	if environment_snapshot_render_generation == render_generation:
		developer_placement_authority_dirty = true
		_invalidate_developer_placement_geometry_caches()
		if _apply_authoring_slot_positions_to_scene_objects():
			_capture_developer_slot_scene_object_baseline()
		_update_developer_placement_panel()
		queue_redraw()


func _reset_developer_slot_placement() -> void:
	var request := _developer_slot_placement_request()
	if request.is_empty():
		return
	var render_generation := environment_snapshot_render_generation
	clear_developer_slot_placement_preview(false, false)
	developer_placement_reset_requested.emit(request)
	if environment_snapshot_render_generation == render_generation:
		developer_placement_authority_dirty = true
		_invalidate_developer_placement_geometry_caches()
		if _apply_authoring_slot_positions_to_scene_objects():
			_capture_developer_slot_scene_object_baseline()
		_update_developer_placement_panel()
		queue_redraw()


func _capture_developer_slot_scene_object_baseline() -> void:
	developer_slot_scene_object_baseline = []
	for object_value in foundation_scene_objects:
		developer_slot_scene_object_baseline.append(
			(object_value as Dictionary).duplicate(false) if typeof(object_value) == TYPE_DICTIONARY else object_value
		)
	developer_slot_scene_object_baseline_valid = true


func _restore_developer_slot_scene_objects() -> void:
	if not developer_slot_scene_object_baseline_valid:
		return
	foundation_scene_objects = []
	for object_value in developer_slot_scene_object_baseline:
		foundation_scene_objects.append(
			(object_value as Dictionary).duplicate(false) if typeof(object_value) == TYPE_DICTIONARY else object_value
		)
	developer_slot_scene_object_baseline.clear()
	developer_slot_scene_object_baseline_valid = false
	_rebuild_scene_object_cache()
	_invalidate_camera_target()
	_update_camera_target_if_needed()


func _apply_authoring_slot_positions_to_scene_objects(refresh_caches: bool = true) -> bool:
	if not developer_slot_placement_mode or foundation_scene_objects.is_empty():
		return false
	_ensure_developer_slot_cache()
	var changed := false
	for index in range(foundation_scene_objects.size()):
		if typeof(foundation_scene_objects[index]) != TYPE_DICTIONARY:
			continue
		var current := foundation_scene_objects[index] as Dictionary
		var slot_id := str(current.get("slot_id", ""))
		if not developer_slots_by_id_cache.has(slot_id):
			continue
		var rect := _developer_slot_rect(developer_slots_by_id_cache.get(slot_id, {}) as Dictionary)
		var target_position := rect.get_center() / Vector2(BOARD_SIZE)
		var current_position_value: Variant = current.get("position", Vector2.ZERO)
		var current_position: Vector2 = current_position_value if typeof(current_position_value) == TYPE_VECTOR2 else Vector2.ZERO
		var current_size_value: Variant = current.get("size", Vector2.ZERO)
		var current_size: Vector2 = current_size_value if typeof(current_size_value) == TYPE_VECTOR2 else Vector2.ZERO
		if current_position.is_equal_approx(target_position) and current_size.is_equal_approx(rect.size) \
				and not current.has("actor_route_stage"):
			continue
		var object_data := current.duplicate(false)
		object_data["position"] = target_position
		object_data["size"] = rect.size
		object_data.erase("actor_route_stage")
		foundation_scene_objects[index] = object_data
		changed = true
	if changed and refresh_caches:
		_rebuild_scene_object_cache()
		_invalidate_camera_target()
		_update_camera_target_if_needed()
	return changed


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
	_flush_developer_drag_redraw()
	var previous_zoom := camera_zoom
	var previous_offset := camera_offset
	var was_info_animating := info_card_animating
	var person_transit_changed := _advance_person_transits()
	if reduce_motion:
		flicker = 0.0
		_update_camera_target_if_needed()
		camera_zoom = target_camera_zoom
		camera_offset = target_camera_offset
		_snap_info_card_to_target()
		var snapped_camera_changed := absf(previous_zoom - camera_zoom) > CAMERA_ZOOM_SNAP_EPSILON or previous_offset.distance_squared_to(camera_offset) > CAMERA_OFFSET_SNAP_EPSILON * CAMERA_OFFSET_SNAP_EPSILON
		if snapped_camera_changed or was_info_animating or person_transit_changed:
			queue_redraw()
		if snapped_camera_changed or person_transit_changed:
			view_geometry_changed.emit()
		return
	var scaled_delta := maxf(0.0, delta) * drunk_time_scale
	# Environment animation is presentation, not simulation. It remains alive
	# while Pal freezes tutorial clocks and game progression.
	flicker += scaled_delta
	actor_route_time += scaled_delta
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
	if camera_changed or info_card_animating or was_info_animating or person_transit_changed or _scene_idle_animation_redraw_due(scaled_delta):
		queue_redraw()
	# Arrival/departure completion changes both the visible object rectangle and
	# whether it can receive input. Guided interactions cache those live hit
	# regions, so settling a person must publish geometry just like a camera move.
	if camera_changed or person_transit_changed:
		view_geometry_changed.emit()


func _scene_idle_animation_active() -> bool:
	# Release-gated invariant: authoring overlays may optimize their own geometry,
	# but they cannot make room animation depend on hover/drag pointer redraws.
	return not reduce_motion


func _arm_animation_heartbeat() -> void:
	# PROCESS_MODE_PAUSABLE opts out of an accidentally disabled inherited mode
	# while still respecting an intentional SceneTree pause.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(true)


func _scene_idle_animation_redraw_due(delta: float) -> bool:
	if not _scene_idle_animation_active():
		scene_idle_animation_redraw_accumulator = 0.0
		return false
	scene_idle_animation_redraw_accumulator += maxf(0.0, delta)
	var redraw_interval := _scene_idle_animation_interval_sec()
	if scene_idle_animation_redraw_accumulator < redraw_interval:
		return false
	scene_idle_animation_redraw_accumulator = minf(
		scene_idle_animation_redraw_accumulator - redraw_interval,
		redraw_interval
	)
	scene_idle_animation_redraw_count += 1
	return true


func _scene_idle_animation_interval_sec() -> float:
	var target_fps := WEB_SCENE_IDLE_ANIMATION_FPS if OS.has_feature("web") else SCENE_IDLE_ANIMATION_FPS
	if _grand_casino_web_low_detail():
		target_fps = WEB_GRAND_CASINO_IDLE_ANIMATION_FPS
	return 1.0 / maxf(1.0, target_fps)


func _grand_casino_web_low_detail() -> bool:
	if not OS.has_feature("web"):
		return false
	match environment_id:
		"grand_casino", "grand_casino_high_limit", "grand_casino_back_room", "grand_casino_cage":
			return true
		_:
			return false


# Selects the active venue drawing routine.
func _draw() -> void:
	selected_info_badge_hit_entries = []
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
			"pawn_shop":
				_draw_pawn_shop()
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
			"punchline_club":
				_draw_punchline_club()
			"punchline_back_room":
				_draw_punchline_back_room()
			"grand_casino":
				_draw_grand_casino()
			"grand_casino_high_limit":
				_draw_grand_casino_private_room("HIGH LIMIT", "PRIVATE TABLES", C_CYAN)
			"grand_casino_back_room":
				_draw_grand_casino_private_room("BACK ROOM", "ROURKE'S TABLES", C_PINK)
			"grand_casino_cage":
				_draw_grand_casino_cage()
			_:
				_draw_corner_store()
	# These closed, authored fixture faces are part of the room art. The exact
	# same routine is replayed after live behind-counter bodies, so occlusion
	# cannot recolor or approximate the original counter.
	_draw_authored_counter_foregrounds()
	_draw_scenario_palette()
	_draw_scene_life()
	_draw_focus_dim_overlay()
	_draw_scene_objects()
	_draw_scene_outcome_highlight()
	_draw_pressure_overlay()
	_draw_drunk_overlay()
	_draw_developer_slot_overlay()
	_draw_developer_placement_outline()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_update_drunk_distortion_protected_rects()


func _draw_developer_placement_outline() -> void:
	if not developer_placement_mode or selected_object_id.is_empty():
		return
	var object_data := _scene_object(selected_object_id)
	if object_data.is_empty():
		return
	var rect := developer_placement_pending_rect if developer_placement_pending_rect.has_area() else _developer_edit_rect_for_object(object_data)
	var color := C_CYAN
	if developer_placement_pending_rect.has_area():
		color = C_TEAL if developer_placement_valid else C_HOT
	draw_rect(rect.grow(3.0), color, false, 3.0)
	draw_circle(rect.position, 4.0, color)


func _draw_developer_slot_overlay() -> void:
	if not developer_slot_placement_mode:
		return
	var font := ThemeDB.fallback_font
	for row_value in _developer_slot_overlay_rows():
		var row := row_value as Dictionary
		var slot := row.get("slot", {}) as Dictionary
		var slot_id := str(slot.get("id", ""))
		var rect := _developer_slot_rect(slot)
		if slot_id == developer_slot_selected_id and developer_slot_pending_rect.has_area():
			rect = developer_slot_pending_rect
		var family := _developer_slot_family(slot)
		var color := _developer_slot_family_color(family)
		var selected := slot_id == developer_slot_selected_id
		var hovered := slot_id == developer_slot_hovered_id
		var editable := bool(row.get("editable", false))
		if not editable:
			color = C_SOFT
		elif selected:
			color = C_TEAL if developer_slot_valid or not developer_slot_pending_rect.has_area() else C_HOT
		var occupied := bool(row.get("occupied", false))
		var has_warnings := bool(row.get("has_warnings", false))
		if has_warnings and not selected:
			color = C_HOT
		var fill_alpha := 0.08 if not editable else (0.19 if occupied else 0.10)
		if selected:
			fill_alpha = 0.30
		draw_rect(rect, Color(color.r, color.g, color.b, fill_alpha), true)
		draw_rect(rect, Color(color.r, color.g, color.b, 0.96), false, 3.0 if selected else 1.5)
		var center := rect.get_center()
		draw_line(center - Vector2(5.0, 0.0), center + Vector2(5.0, 0.0), color, 1.0)
		draw_line(center - Vector2(0.0, 5.0), center + Vector2(0.0, 5.0), color, 1.0)
		if occupied:
			draw_circle(center, 3.0, color)
		# Keep the full room readable: every slot retains its compact marker, while
		# only the hovered/selected slot expands into a text label and stable ID.
		if not selected and not hovered:
			continue
		var label_width := maxf(112.0, minf(200.0, maxf(rect.size.x, 160.0)))
		var primary_lines := _wrap_developer_slot_label(str(row.get("primary_label", "")), font, 8, label_width - 6.0)
		var label_lines: Array[String] = []
		label_lines.append_array(primary_lines)
		label_lines.append_array(_wrap_developer_slot_label(slot_id, font, 7, label_width - 6.0))
		var label_line_height := 9.0
		var label_height := maxf(11.0, float(label_lines.size()) * label_line_height + 3.0)
		var label_y := rect.position.y - label_height
		if label_y < 1.0:
			label_y = minf(BOARD_SIZE.y - label_height - 1.0, rect.end.y + 1.0)
		var label_rect := Rect2(
			Vector2(clampf(rect.position.x, 0.0, BOARD_SIZE.x - label_width), label_y),
			Vector2(label_width, label_height)
		)
		draw_rect(label_rect, Color(C_DARK.r, C_DARK.g, C_DARK.b, 0.88), true)
		for line_index in range(label_lines.size()):
			var line_color := color if line_index < primary_lines.size() else C_SOFT
			var line_font_size := 8 if line_index < primary_lines.size() else 7
			draw_string(
				font,
				label_rect.position + Vector2(3.0, 9.0 + float(line_index) * label_line_height),
				label_lines[line_index],
				HORIZONTAL_ALIGNMENT_LEFT,
				label_rect.size.x - 6.0,
				line_font_size,
				line_color
			)


func _developer_slot_overlay_rows() -> Array:
	if developer_slot_overlay_cache_valid:
		return developer_slot_overlay_rows_cache
	developer_slot_overlay_cache_rebuild_count += 1
	var comparison_slots := _developer_slots(true)
	var rows: Array = []
	for slot_value in _developer_slots():
		var slot := slot_value as Dictionary
		var slot_id := str(slot.get("id", ""))
		var slot_state := _developer_slot_state(slot, comparison_slots)
		rows.append({
			"slot": slot,
			"editable": _developer_slot_is_editable(slot),
			"occupied": not _developer_slot_occupant_records(slot_id).is_empty(),
			"has_warnings": not (slot_state.get("warnings", []) as Array).is_empty(),
			"primary_label": _developer_slot_primary_label(slot),
		})
	developer_slot_overlay_rows_cache = rows
	developer_slot_overlay_cache_valid = true
	return developer_slot_overlay_rows_cache


# Wraps stable slot IDs without deleting or replacing any character. Semantic
# separators are preferred as line endings so IDs remain easy to scan.
func _wrap_developer_slot_label(text: String, font: Font, font_size: int, max_width: float) -> Array[String]:
	var lines: Array[String] = []
	var remaining := text
	var safe_width := maxf(8.0, max_width)
	while not remaining.is_empty():
		if font == null or _draw_text_width(remaining, font, font_size) <= safe_width:
			lines.append(remaining)
			break
		var fit_chars := 0
		for length in range(1, remaining.length() + 1):
			if _draw_text_width(remaining.left(length), font, font_size) > safe_width:
				break
			fit_chars = length
		fit_chars = maxi(1, fit_chars)
		var break_chars := fit_chars
		for index in range(fit_chars - 1, 0, -1):
			if "._:-/".contains(remaining.substr(index, 1)):
				break_chars = index + 1
				break
		lines.append(remaining.left(break_chars))
		remaining = remaining.substr(break_chars)
	return lines


func _draw_scenario_palette() -> void:
	if scenario_palette_overlay.a <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(BOARD_SIZE)), scenario_palette_overlay)


func _cache_scenario_presentation() -> void:
	scenario_palette_overlay = Color.TRANSPARENT
	scenario_crowd_count = 0
	scenario_signage = str(scenario_presentation.get("signage_line", "")).strip_edges().left(64)
	var tint_text := str(scenario_presentation.get("palette_tint", "")).strip_edges()
	if not tint_text.is_empty() and Color.html_is_valid(tint_text):
		var tint := Color.from_string(tint_text, Color.TRANSPARENT)
		scenario_palette_overlay = Color(tint.r, tint.g, tint.b, 0.12)
	match str(scenario_presentation.get("crowd_density", "")).strip_edges().to_lower():
		"sparse":
			scenario_crowd_count = 2
		"medium":
			scenario_crowd_count = 4
		"dense":
			scenario_crowd_count = 7
		"packed":
			scenario_crowd_count = 10


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
	# Narrow store aisle, glass counter, scratchers, beer neon, and boxes.
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
	# A dedicated service ledge keeps the payphone physically supported instead
	# of floating over the aisle floor.
	draw_rect(Rect2(170, 270, 100, 16), Color("#2b2036"))
	draw_line(Vector2(174, 270), Vector2(266, 270), C_CYAN_2.darkened(0.20), 3)
	draw_rect(Rect2(180, 286, 10, 58), Color("#151522"))
	draw_rect(Rect2(250, 286, 10, 58), Color("#151522"))
	draw_rect(Rect2(194, 292, 52, 24), Color("#11111d"))
	draw_line(Vector2(202, 304), Vector2(238, 304), C_AMBER.darkened(0.35), 2)
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
	# The low phone desk is an authored interaction support on the room floor.
	# Keep its top/front aligned with placement_surfaces.json (286 / 324).
	draw_rect(Rect2(450, 286, 224, 38), Color("#241a2d"))
	draw_line(Vector2(454, 286), Vector2(670, 286), C_CYAN_2.darkened(0.28), 3)
	draw_rect(Rect2(466, 324, 12, 48), Color("#11111d"))
	draw_rect(Rect2(646, 324, 12, 48), Color("#11111d"))
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
	# Compact city apartment: a curtained skyline window, lived-in sofa,
	# framed print, floor lamp, and a small kitchenette make the room read as a
	# home before any interactive storage or rent props are layered on top.
	draw_rect(Rect2(0, 0, 900, 246), Color("#171a2a"))
	draw_rect(Rect2(0, 34, 900, 212), Color("#202038"))
	draw_rect(Rect2(0, 232, 900, 14), Color("#30213b"))
	# Window, distant buildings, and curtains.
	draw_rect(Rect2(42, 42, 230, 152), Color("#0b0c18"))
	draw_rect(Rect2(52, 52, 210, 132), Color("#071727"))
	for building_index in range(7):
		var building_x := 58 + building_index * 29
		var building_height := 42 + (building_index * 17) % 58
		draw_rect(Rect2(building_x, 178 - building_height, 22, building_height), Color("#10283a"))
		for light_y in range(144 - int(building_height / 2), 172, 16):
			draw_rect(Rect2(building_x + 5, light_y, 4, 3), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.22))
	draw_line(Vector2(157, 52), Vector2(157, 184), Color("#28485d"), 3)
	draw_line(Vector2(52, 116), Vector2(262, 116), Color("#28485d"), 3)
	draw_rect(Rect2(32, 38, 24, 166), Color("#44234c"))
	draw_rect(Rect2(258, 38, 24, 166), Color("#44234c"))
	draw_rect(Rect2(32, 116, 28, 8), Color("#b43a73"))
	draw_rect(Rect2(254, 116, 28, 8), Color("#b43a73"))
	# Framed Miami print above the sofa.
	draw_rect(Rect2(354, 48, 146, 64), Color("#0c0d18"))
	draw_rect(Rect2(362, 56, 130, 48), Color("#29304c"))
	draw_rect(Rect2(370, 84, 114, 12), Color("#e95f77"))
	draw_circle(Vector2(458, 72), 10, Color("#ffbf69"))
	draw_line(Vector2(374, 84), Vector2(406, 64), Color("#34cfe0"), 3)
	# Sofa with visible arms, cushions, and feet.
	draw_rect(Rect2(304, 132, 252, 82), Color("#2b1835"))
	draw_rect(Rect2(320, 118, 220, 70), Color("#46254d"))
	draw_rect(Rect2(328, 126, 98, 46), Color("#54305b"))
	draw_rect(Rect2(434, 126, 98, 46), Color("#3a294a"))
	draw_rect(Rect2(312, 172, 236, 34), Color("#39203f"))
	draw_rect(Rect2(296, 154, 24, 58), Color("#512a51"))
	draw_rect(Rect2(540, 154, 24, 58), Color("#512a51"))
	draw_rect(Rect2(326, 210, 12, 12), Color("#15101d"))
	draw_rect(Rect2(522, 210, 12, 12), Color("#15101d"))
	# Floor lamp beside the seating area.
	draw_line(Vector2(592, 96), Vector2(592, 220), Color("#b75f75"), 4)
	draw_rect(Rect2(568, 84, 48, 18), Color("#ffad66"))
	draw_rect(Rect2(576, 72, 32, 14), Color("#ffd27d"))
	draw_rect(Rect2(572, 218, 40, 8), Color("#3a2439"))
	# Small kitchenette with upper cabinets, counter, sink, and fridge.
	draw_rect(Rect2(626, 48, 224, 178), Color("#171722"))
	draw_rect(Rect2(638, 60, 126, 62), Color("#3b2940"))
	for cabinet_x in [642, 704]:
		draw_rect(Rect2(cabinet_x, 66, 54, 48), Color("#51334e"))
		draw_rect(Rect2(cabinet_x + 44, 88, 4, 4), Color("#e3b36b"))
	draw_rect(Rect2(632, 132, 142, 14), Color("#d17a66"))
	draw_rect(Rect2(644, 146, 126, 68), Color("#302334"))
	draw_rect(Rect2(650, 150, 50, 8), Color("#172f3b"))
	draw_line(Vector2(670, 150), Vector2(670, 140), C_CYAN.darkened(0.25), 3)
	draw_rect(Rect2(784, 60, 54, 154), Color("#293141"))
	draw_line(Vector2(788, 130), Vector2(834, 130), Color("#59606d"), 2)
	draw_rect(Rect2(790, 94, 4, 24), Color("#d7c6b4"))
	# Rug anchors the interactive belongings without adding another prop.
	draw_rect(Rect2(260, 246, 374, 58), Color("#24162f"))
	for stripe_x in range(278, 620, 44):
		draw_rect(Rect2(stripe_x, 258, 26, 5), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.26))
		draw_rect(Rect2(stripe_x + 12, 280, 26, 4), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.20))
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


func _draw_pawn_shop() -> void:
	draw_rect(Rect2(0, 0, 900, 246), Color("#0d1018"))
	for x in range(0, 900, 90):
		draw_rect(Rect2(x, 0, 90, 246), Color("#141824") if int(x / 90) % 2 == 0 else Color("#10131d"))
	draw_rect(Rect2(0, 0, 900, 32), Color("#07090f"))
	draw_rect(Rect2(0, 32, 900, 6), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.36))
	_neon_text("SAL'S PAWN", Vector2(306, 58), 31, C_YELLOW)
	_neon_text("BUY SELL TRADE", Vector2(330, 94), 16, C_CYAN)
	draw_rect(Rect2(56, 70, 218, 146), Color("#151321"))
	draw_rect(Rect2(72, 86, 186, 104), Color("#080a10"))
	for y in [98, 126, 154, 182]:
		draw_rect(Rect2(78, y, 174, 5), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.18))
		for x in range(92, 236, 36):
			draw_rect(Rect2(x, y - 18, 20, 14), _cycle_color(x + y).darkened(0.18))
	draw_rect(Rect2(316, 92, 268, 132), Color("#07080e"))
	for x in range(332, 570, 22):
		draw_line(Vector2(x, 96), Vector2(x - 24, 222), Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.20), 1)
	draw_rect(Rect2(342, 116, 214, 74), Color("#151b23"))
	draw_rect(Rect2(358, 132, 182, 42), Color("#222b34"))
	draw_rect(Rect2(408, 148, 76, 16), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.42))
	draw_rect(Rect2(316, 224, 268, 54), Color("#3b2a18"))
	draw_line(Vector2(330, 232), Vector2(570, 232), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.42), 3)
	draw_rect(Rect2(612, 72, 224, 150), Color("#111621"))
	draw_rect(Rect2(630, 92, 188, 108), Color("#080b12"))
	for x in [648, 690, 732, 774]:
		draw_rect(Rect2(x, 108, 22, 42), Color("#2c2230"))
		draw_rect(Rect2(x + 4, 114, 14, 5), C_AMBER)
		draw_rect(Rect2(x + 5, 132, 12, 4), C_PINK_2)
	draw_rect(Rect2(652, 170, 142, 18), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.16))
	draw_rect(Rect2(58, 236, 792, 62), Color("#18161f"))
	for x in range(84, 826, 68):
		draw_rect(Rect2(x, 248 + int(sin(float(x)) * 3.0), 42, 5), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.14))
	_floor_reflections()


func _draw_bar() -> void:
	# Dive bar with bottle mirror, stools, pool table, neon signs, and patrons.
	draw_rect(Rect2(0, 0, 900, 244), Color("#0f1320"))
	draw_rect(Rect2(54, 52, 498, 130), Color("#151c2d"))
	draw_rect(Rect2(72, 70, 462, 84), Color("#202842"))
	for x in range(90, 518, 34):
		draw_rect(Rect2(x, 84, 14, 54), _cycle_color(x).darkened(0.15))
		draw_rect(Rect2(x + 3, 74, 8, 10), C_AMBER)
	_neon_text("DIVE", Vector2(620, 58), 28, C_PINK)
	_neon_text("COLD BEER", Vector2(604, 104), 22, C_CYAN)
	# The dartboard gives league-night display props a real wall fixture.
	draw_circle(Vector2(824, 92), 24, Color("#1a1422"))
	draw_circle(Vector2(824, 92), 19, C_AMBER.darkened(0.25))
	draw_circle(Vector2(824, 92), 13, Color("#4b1730"))
	draw_circle(Vector2(824, 92), 5, C_CYAN_2)
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
	# A low wall booth supports the one seated aftermath patron.
	draw_rect(Rect2(654, 302, 142, 42), Color("#23172b"))
	draw_rect(Rect2(662, 310, 126, 22), Color("#42213a"))
	draw_rect(Rect2(670, 332, 110, 14), C_PINK_2.darkened(0.38))
	draw_rect(Rect2(672, 346, 10, 38), Color("#16101c"))
	draw_rect(Rect2(768, 346, 10, 38), Color("#16101c"))
	_floor_reflections()


func _draw_jazz_club() -> void:
	# Late-1960s jazz room architecture: low amber stage, smoky tables, and bar.
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
	draw_rect(Rect2(66, 146, 476, 8), Color("#3a2114"))
	draw_line(Vector2(78, 146), Vector2(530, 146), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.30), 2)
	_draw_light_cone(Vector2(190, 34), Vector2(-54, 194), C_AMBER, 0.12)
	_draw_light_cone(Vector2(330, 34), Vector2(0, 194), C_AMBER, 0.10)
	_draw_light_cone(Vector2(470, 34), Vector2(54, 194), C_AMBER, 0.12)
	_neon_text("AFTER HOURS", Vector2(126, 62), 18, C_CYAN)
	_neon_text("JAZZ", Vector2(374, 62), 24, C_YELLOW)
	draw_rect(Rect2(600, 72, 254, 122), Color("#17101a"))
	draw_rect(Rect2(618, 88, 218, 62), Color("#241622"))
	for x in range(630, 826, 28):
		draw_rect(Rect2(x, 104, 10, 36), _cycle_color(x).darkened(0.22))
		draw_rect(Rect2(x + 2, 96, 6, 8), C_AMBER)
	draw_rect(Rect2(590, 188, 284, 48), Color("#3b1f15"))
	draw_line(Vector2(602, 197), Vector2(862, 197), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.48), 3)
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
	draw_rect(Rect2(40, 400, 820, 8), Color("#3a2114"))
	draw_line(Vector2(50, 408), Vector2(850, 408), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.26), 2)
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
	# Velvet lounge architecture with a stage, champagne bar, tables, and low lighting.
	draw_rect(Rect2(0, 0, 900, 246), Color("#130918"))
	for x in range(0, 900, 60):
		var panel := Color("#241022") if int(x / 60) % 2 == 0 else Color("#1a0d1d")
		draw_rect(Rect2(x, 0, 60, 246), panel)
	draw_rect(Rect2(0, 0, 900, 32), Color("#09060c"))
	draw_rect(Rect2(0, 32, 900, 6), C_PINK_2)
	draw_rect(Rect2(62, 58, 470, 184), Color("#24101a"))
	draw_rect(Rect2(82, 78, 430, 126), Color("#10080e"))
	draw_rect(Rect2(94, 196, 406, 38), Color("#3a1818"))
	draw_rect(Rect2(94, 146, 406, 8), Color("#3a1818"))
	draw_line(Vector2(106, 146), Vector2(488, 146), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.30), 2)
	_draw_light_cone(Vector2(180, 34), Vector2(-42, 190), C_PINK, 0.12)
	_draw_light_cone(Vector2(318, 34), Vector2(0, 190), C_AMBER, 0.10)
	_draw_light_cone(Vector2(456, 34), Vector2(42, 190), C_CYAN, 0.11)
	_neon_text("KITTY CAT", Vector2(126, 62), 26, C_PINK)
	_neon_text("LOUNGE", Vector2(354, 66), 22, C_YELLOW)
	for x in [142, 250, 358]:
		_silhouette(Vector2(x, 205), 0.72, Color("#05050a"))
		draw_rect(Rect2(x - 14, 164, 28, 5), C_AMBER)
	draw_rect(Rect2(516, 154, 64, 80), Color("#10080e"))
	draw_rect(Rect2(522, 204, 56, 30), Color("#3a181f"))
	draw_line(Vector2(522, 204), Vector2(578, 204), C_AMBER.darkened(0.25), 3)
	draw_rect(Rect2(584, 72, 260, 124), Color("#170b12"))
	draw_rect(Rect2(602, 88, 222, 64), Color("#2a1118"))
	for x in range(620, 808, 28):
		draw_rect(Rect2(x, 104, 10, 34), _cycle_color(x).darkened(0.18))
		draw_rect(Rect2(x + 2, 94, 6, 8), C_AMBER)
	draw_rect(Rect2(584, 190, 268, 48), Color("#3d1b14"))
	draw_line(Vector2(596, 199), Vector2(840, 199), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.46), 3)
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
	draw_rect(Rect2(42, 46, 816, 8), Color("#493116"))
	draw_line(Vector2(52, 54), Vector2(848, 54), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.34), 2)
	draw_rect(Rect2(42, 146, 816, 8), Color("#493116"))
	draw_line(Vector2(52, 146), Vector2(848, 146), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.42), 2)
	draw_rect(Rect2(64, 178, 238, 84), Color("#123f30"))
	draw_rect(Rect2(84, 194, 198, 46), Color("#1a7755"))
	draw_rect(Rect2(360, 170, 212, 92), Color("#143b31"))
	draw_rect(Rect2(378, 188, 176, 48), Color("#1b7555"))
	for x in [122, 172, 222, 410, 460, 510]:
		_card_back(Rect2(x, 154 + (x % 3) * 4, 26, 36))
	draw_rect(Rect2(0, 292, 900, 16), Color("#493116"))
	for x in range(0, 900, 60):
		draw_line(Vector2(x, 278), Vector2(x + 28, 328), C_AMBER, 3)
	draw_line(Vector2(0, 278), Vector2(900, 278), C_AMBER, 4)
	draw_line(Vector2(0, 328), Vector2(900, 328), C_AMBER, 3)
	draw_rect(Rect2(100, 346, 550, 6), Color("#493116"))
	draw_rect(Rect2(700, 346, 150, 6), Color("#493116"))
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
	_floor_reflections()


func _draw_gas_station() -> void:
	# Converted gas station with canopy, highway window, slot row, cage, camera, and fluorescents.
	draw_rect(Rect2(0, 0, 900, 248), Color("#101122"))
	draw_rect(Rect2(0, 34, 900, 36), Color("#1f1f31"))
	draw_rect(Rect2(0, 70, 900, 8), C_CYAN_2)
	# Two raised merchandise/service ledges support the compact back rows used by
	# crowded gas-casino compositions; they are physical fixtures, not UI lanes.
	draw_rect(Rect2(16, 78, 868, 6), Color("#343447"))
	draw_line(Vector2(24, 84), Vector2(876, 84), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.24), 2)
	draw_rect(Rect2(16, 166, 868, 6), Color("#343447"))
	draw_line(Vector2(24, 172), Vector2(876, 172), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.20), 2)
	for x in [90, 412, 770]:
		draw_rect(Rect2(x, 0, 22, 212), Color("#25253a"))
	draw_rect(Rect2(50, 96, 258, 96), Color("#060611"))
	draw_line(Vector2(64, 154), Vector2(294, 132), C_PINK, 2)
	draw_line(Vector2(64, 170), Vector2(294, 160), C_PURPLE_2, 2)
	_neon_text("HIGHWAY", Vector2(82, 116), 18, C_CYAN)
	# Authored counter contacts for the drink, ticket, and staff stations.
	for shelf in [Rect2(320, 76, 104, 8), Rect2(532, 76, 104, 8), Rect2(660, 76, 104, 8), Rect2(788, 76, 96, 8)]:
		draw_rect(shelf, Color("#493116"))
		draw_line(Vector2(shelf.position.x, shelf.end.y), Vector2(shelf.end.x, shelf.end.y), C_AMBER.darkened(0.22), 2)
	draw_rect(Rect2(408, 192, 104, 8), Color("#493116"))
	draw_line(Vector2(408, 200), Vector2(512, 200), C_AMBER.darkened(0.22), 2)
	draw_rect(Rect2(660, 104, 166, 120), Color("#171726"))
	for x in range(672, 810, 18):
		draw_line(Vector2(x, 106), Vector2(x, 222), C_SOFT.darkened(0.2), 1)
	_silhouette(Vector2(744, 182), 0.8, C_SHADOW)
	draw_rect(Rect2(720, 70, 38, 24), C_SHADOW)
	draw_line(Vector2(739, 94), Vector2(782, 126), C_CYAN, 2)
	draw_rect(Rect2(780, 124, 20, 16), Color("#05050b"))
	# Low utility rail for scenario controls (cooler locks, monitor, shutters).
	draw_rect(Rect2(100, 244, 700, 10), Color("#202838"))
	draw_line(Vector2(108, 254), Vector2(792, 254), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.30), 2)
	for post_x in [116, 450, 784]:
		draw_rect(Rect2(post_x, 254, 4, 72), C_SOFT.darkened(0.48))
	draw_rect(Rect2(100, 400, 700, 8), Color("#343447"))
	draw_line(Vector2(110, 408), Vector2(790, 408), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.24), 2)
	_floor_reflections()


func _draw_underground() -> void:
	# Basement casino with low ceiling, felt tables, string lights, smoke, and bar cart.
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
	draw_rect(Rect2(744, 88, 108, 178), Color("#08080f"))
	draw_rect(Rect2(40, 188, 70, 82), Color("#352214"))
	draw_rect(Rect2(48, 168, 54, 20), C_AMBER)
	draw_rect(Rect2(58, 146, 12, 22), C_PURPLE_2)
	draw_rect(Rect2(78, 142, 12, 26), C_TEAL)
	for i in range(8):
		draw_rect(Rect2(i * 120, 96 + i % 3 * 16, 240, 28), Color(1.0, 0.45, 0.7, 0.035))
	_floor_reflections()


func _draw_punchline_club() -> void:
	# Public-facing comedy room: a small stage, bad brickwork, two-drink tables,
	# and one deliberately unremarkable side door.
	draw_rect(Rect2(0, 0, 900, 245), Color("#130d18"))
	for y in range(18, 238, 28):
		for x in range(-12 if int(y / 28) % 2 == 0 else 20, 900, 64):
			draw_rect(Rect2(x, y, 58, 22), Color("#321b26"))
	draw_rect(Rect2(248, 62, 404, 192), Color("#08070d"))
	draw_rect(Rect2(264, 80, 372, 150), Color("#50142d"))
	draw_rect(Rect2(302, 202, 296, 50), Color("#25121f"))
	draw_circle(Vector2(450, 138), 36, Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.14))
	draw_line(Vector2(450, 120), Vector2(450, 192), C_SOFT, 3)
	draw_circle(Vector2(450, 116), 8, C_SHADOW)
	_neon_text("THE PUNCHLINE", Vector2(319, 42), 24, C_YELLOW)
	_draw_punchline_table(Vector2(108, 194))
	_draw_punchline_table(Vector2(202, 222))
	_draw_punchline_table(Vector2(704, 194))
	_draw_punchline_table(Vector2(790, 222))
	_silhouette(Vector2(122, 168), 0.72, C_SHADOW)
	_silhouette(Vector2(716, 166), 0.78, C_SHADOW)
	_silhouette(Vector2(798, 192), 0.66, C_SHADOW)
	draw_rect(Rect2(814, 78, 64, 164), Color("#17121d"))
	draw_rect(Rect2(826, 96, 40, 108), Color("#23182b"))
	draw_circle(Vector2(854, 156), 3, C_AMBER)
	_floor_reflections()


func _draw_punchline_table(position: Vector2) -> void:
	draw_circle(position, 28, Color("#241628"))
	draw_circle(position, 20, Color("#563247"))
	draw_rect(Rect2(position.x - 3, position.y - 15, 6, 18), C_AMBER)


func _draw_punchline_back_room() -> void:
	# Furnished crew floor: each gameplay surface has a stable diegetic zone.
	draw_rect(Rect2(0, 0, 900, 245), Color("#090b10"))
	for x in range(0, 900, 76):
		draw_rect(Rect2(x, 0, 38, 245), Color("#10151d"))
		draw_rect(Rect2(x + 38, 0, 38, 245), Color("#0c1117"))
	_neon_text("THE BACK ROOM", Vector2(326, 34), 22, C_PINK)
	# Job board and pinned cards.
	draw_rect(Rect2(42, 54, 170, 104), Color("#402c20"))
	draw_rect(Rect2(49, 61, 156, 90), Color("#6b4a2d"))
	for note in [Rect2(60, 70, 38, 26), Rect2(108, 68, 42, 32), Rect2(159, 78, 34, 24), Rect2(76, 110, 48, 28), Rect2(139, 114, 46, 26)]:
		draw_rect(note, C_SOFT.darkened(0.12))
		draw_circle(note.position + Vector2(note.size.x * 0.5, 4), 2, C_PINK)
	_neon_text("WORK", Vector2(92, 49), 13, C_AMBER)
	# Planning table in the center; the clean middle is reserved for crew06_8.
	draw_rect(Rect2(264, 151, 372, 74), Color("#1b2027"))
	draw_rect(Rect2(282, 162, 336, 44), Color("#3d464b"))
	draw_rect(Rect2(382, 170, 136, 28), Color("#27343b"))
	for x in [304, 346, 552, 592]:
		_card_back(Rect2(x, 135 + (x % 3) * 4, 24, 34))
	# Numbers desk and adding machine.
	draw_rect(Rect2(42, 184, 170, 52), Color("#26201c"))
	draw_rect(Rect2(58, 173, 64, 30), Color("#d3c39a"))
	for y in [181, 188, 195]:
		draw_line(Vector2(64, y), Vector2(114, y), Color("#5c5544"), 1)
	draw_rect(Rect2(142, 168, 46, 36), Color("#232a2d"))
	# Mags' bench and Practice Rig occupy the right wall.
	draw_rect(Rect2(680, 62, 154, 46), Color("#33281e"))
	for x in [694, 732, 770, 808]:
		draw_rect(Rect2(x, 48, 20, 18), C_AMBER.darkened(0.45))
	_neon_text("MAGS", Vector2(731, 42), 12, C_CYAN)
	draw_rect(Rect2(674, 142, 172, 82), Color("#18252a"))
	draw_line(Vector2(698, 196), Vector2(742, 152), C_TEAL, 5)
	draw_line(Vector2(778, 152), Vector2(822, 196), C_TEAL, 5)
	draw_circle(Vector2(760, 177), 12, C_YELLOW.darkened(0.2))
	draw_circle(Vector2(760, 177), 4, C_SHADOW)
	_neon_text("RIG", Vector2(742, 132), 12, C_YELLOW)
	# The exit remains the normal travel seam; Rook is rendered by the manifest.
	draw_rect(Rect2(790, 70, 80, 174), Color("#12151b"))
	draw_circle(Vector2(808, 158), 3, C_AMBER)
	_floor_reflections()


func _draw_grand_casino() -> void:
	# Boss-floor casino arranged as a legible working room: one machine bank,
	# two staffed felt tables, and a central host station. The room art supplies
	# physical supports; live game objects and people occupy the authored slots.
	draw_rect(Rect2(0, 0, 900, 430), Color("#090914"))
	for x in range(0, 900, 90):
		draw_rect(Rect2(x, 0, 48, 246), Color("#11112a"))
		draw_rect(Rect2(x + 48, 0, 42, 246), Color("#0d0d1a"))
	draw_rect(Rect2(0, 0, 900, 32), Color("#1b1034"))
	draw_rect(Rect2(0, 32, 900, 5), C_PINK)
	_neon_text("GRAND CASINO", Vector2(330, 48), 24, C_YELLOW)
	draw_line(Vector2(282, 72), Vector2(618, 72), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.32), 2)

	# Five equal machine bays form a single uninterrupted row.
	for machine_x in [90, 246, 402, 558, 714]:
		draw_rect(Rect2(machine_x - 6, 78, 108, 120), Color("#160f27"))
		draw_rect(Rect2(machine_x, 84, 96, 108), Color("#21113a"), false, 2)
		draw_rect(Rect2(machine_x + 10, 94, 76, 48), Color("#080914"))
		draw_rect(Rect2(machine_x + 14, 150, 68, 28), Color("#100d1c"))
		draw_line(Vector2(machine_x + 12, 186), Vector2(machine_x + 84, 186), C_AMBER.darkened(0.20), 4)

	# A distinct ticket kiosk and cocktail shelf bookend the machine bank.
	draw_rect(Rect2(8, 84, 72, 112), Color("#161226"))
	draw_rect(Rect2(14, 96, 60, 52), Color("#080914"))
	_neon_text("CAGE", Vector2(16, 88), 10, C_CYAN)
	draw_rect(Rect2(16, 156, 56, 30), Color("#21182b"))
	draw_rect(Rect2(816, 112, 76, 72), Color("#151326"))
	_neon_text("BAR", Vector2(830, 122), 12, C_PINK)
	draw_rect(Rect2(816, 170, 76, 14), C_AMBER.darkened(0.24))

	# Tabletop art extends above the authored contact edge at y=258; the darker
	# apron below it is replayed after any behind-table staff are drawn.
	for table_x in [82, 546]:
		draw_rect(Rect2(table_x, 206, 272, 88), Color("#0c2e25"))
		draw_rect(Rect2(table_x + 12, 214, 248, 44), Color("#1a7755"))
		draw_rect(Rect2(table_x + 22, 222, 228, 28), Color("#145b43"), false, 2)
		draw_rect(Rect2(table_x, 258, 272, 36), Color("#123f30"))
		draw_line(Vector2(table_x, 258), Vector2(table_x + 272, 258), C_AMBER.darkened(0.10), 4)
		draw_line(Vector2(table_x + 20, 286), Vector2(table_x + 252, 286), Color("#08231c"), 3)

	# The central host desk has a clear work position and a solid foreground.
	draw_rect(Rect2(344, 318, 212, 48), Color("#171225"))
	draw_line(Vector2(344, 318), Vector2(556, 318), C_AMBER, 4)
	draw_rect(Rect2(364, 330, 172, 20), Color("#0e0b18"))
	_neon_text("HOST", Vector2(418, 334), 14, C_CYAN)
	draw_line(Vector2(370, 366), Vector2(364, 394), C_SOFT.darkened(0.45), 4)
	draw_line(Vector2(530, 366), Vector2(536, 394), C_SOFT.darkened(0.45), 4)

	# Low floor bands define the public circulation area without implying routes.
	draw_rect(Rect2(72, 302, 756, 6), Color("#2d2037"))
	draw_rect(Rect2(96, 398, 708, 6), C_AMBER.darkened(0.35))
	_floor_reflections()


func _draw_grand_casino_private_room(title: String, subtitle: String, accent: Color) -> void:
	# High Limit and the Back Room share the main floor's exact felt geometry so
	# their fixed game slots remain truthful, but they do not inherit the public
	# machine bank, cocktail shelf, or host signage.
	draw_rect(Rect2(0, 0, 900, 430), Color("#080812"))
	for x in range(0, 900, 112):
		draw_rect(Rect2(x, 0, 56, 246), Color("#111126"))
		draw_rect(Rect2(x + 56, 0, 56, 246), Color("#0c0c18"))
	draw_rect(Rect2(0, 0, 900, 32), Color("#1b1034"))
	draw_rect(Rect2(0, 32, 900, 5), accent)
	_neon_text(title, Vector2(450.0 - float(title.length()) * 8.0, 48), 24, C_YELLOW)
	_neon_text(subtitle, Vector2(450.0 - float(subtitle.length()) * 5.0, 78), 12, accent)
	# Two quiet felt pits replace the public machine row. Their apron edges match
	# the authored counter contacts used by both private-room maps.
	for table_x in [82, 546]:
		draw_rect(Rect2(table_x, 206, 272, 88), Color("#0c2e25"))
		draw_rect(Rect2(table_x + 12, 214, 248, 44), Color("#1a7755"))
		draw_rect(Rect2(table_x + 22, 222, 228, 28), Color("#145b43"), false, 2)
		draw_rect(Rect2(table_x, 258, 272, 36), Color("#123f30"))
		draw_line(Vector2(table_x, 258), Vector2(table_x + 272, 258), C_AMBER.darkened(0.10), 4)
		draw_line(Vector2(table_x + 20, 286), Vector2(table_x + 252, 286), Color("#08231c"), 3)
	# A private central desk supports the room's stationary contact without
	# presenting the public-floor HOST identity.
	draw_rect(Rect2(344, 318, 212, 48), Color("#171225"))
	draw_line(Vector2(344, 318), Vector2(556, 318), accent, 4)
	draw_rect(Rect2(364, 330, 172, 20), Color("#0e0b18"))
	_neon_text("VIP" if environment_id == "grand_casino_high_limit" else "OFFICE", Vector2(420, 334), 14, accent)
	draw_line(Vector2(370, 366), Vector2(364, 394), C_SOFT.darkened(0.45), 4)
	draw_line(Vector2(530, 366), Vector2(536, 394), C_SOFT.darkened(0.45), 4)
	# Real framed notices occupy the wall areas; no route or status graphics are
	# painted into the player view.
	draw_rect(Rect2(8, 36, 72, 48), Color("#171326"))
	draw_rect(Rect2(16, 44, 56, 32), Color(accent.r, accent.g, accent.b, 0.16), false, 2)
	draw_rect(Rect2(820, 36, 72, 48), Color("#171326"))
	draw_rect(Rect2(828, 44, 56, 32), Color(accent.r, accent.g, accent.b, 0.16), false, 2)
	draw_rect(Rect2(72, 302, 756, 6), Color("#2d2037"))
	draw_rect(Rect2(96, 398, 708, 6), C_AMBER.darkened(0.35))
	_floor_reflections()


func _draw_grand_casino_cage() -> void:
	# A room-native Cage: teller bars dominate the center while ATM, gift case,
	# and return door remain visually and spatially separate.
	draw_rect(Rect2(0, 0, 900, 420), Color("#080914"))
	for x in range(0, 900, 72):
		draw_rect(Rect2(x, 0, 34, 250), Color("#11132a"))
		draw_rect(Rect2(x + 34, 0, 38, 250), Color("#0c0d1d"))
	draw_rect(Rect2(0, 0, 900, 34), Color("#1b1034"))
	draw_rect(Rect2(0, 34, 900, 5), C_CYAN)
	_neon_text("THE CAGE", Vector2(350, 66), 30, C_YELLOW)
	# Gift case at left.
	draw_rect(Rect2(54, 124, 190, 150), Color("#090b16"))
	draw_rect(Rect2(62, 132, 174, 112), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.13))
	for shelf_y in [178, 238]:
		draw_line(Vector2(66, shelf_y), Vector2(232, shelf_y), C_SOFT.darkened(0.35), 3)
	var shop_state: Dictionary = foundation_snapshot.get("cage_gift_shop_state", {}) if typeof(foundation_snapshot.get("cage_gift_shop_state", {})) == TYPE_DICTIONARY else {}
	var available_stock: Array = []
	for stock_value in shop_state.get("stock", []):
		if typeof(stock_value) == TYPE_DICTIONARY and not bool((stock_value as Dictionary).get("sold", false)):
			available_stock.append(stock_value)
	# Live shelf stock is drawn by the normal item-object renderer so each offer
	# uses its authored icon and owns an independent click target.
	if available_stock.is_empty():
		_neon_text("EMPTY", Vector2(116, 198), 13, C_SOFT.darkened(0.25))
	draw_rect(Rect2(60, 246, 178, 20), Color("#241331"))
	_neon_text("CHIPS ONLY", Vector2(92, 260), 12, C_PINK)
	# Counter, trays, ledger, and barred teller windows.
	draw_rect(Rect2(274, 112, 356, 168), Color("#050711"))
	for window_index in range(3):
		var window_x := 286 + window_index * 112
		draw_rect(Rect2(window_x, 124, 98, 112), Color("#13152b"))
		for bar_x in range(window_x + 8, window_x + 98, 15):
			draw_rect(Rect2(bar_x, 124, 4, 112), Color("#6b7080"))
		draw_rect(Rect2(window_x + 10, 218, 78, 10), Color("#020309"))
	draw_rect(Rect2(260, 260, 388, 56), Color("#2b1a25"))
	draw_rect(Rect2(270, 270, 368, 34), Color("#5b3a38"))
	for tray_x in [304, 416, 528]:
		draw_rect(Rect2(tray_x, 280, 72, 15), Color("#11131d"))
		draw_rect(Rect2(tray_x + 8, 283, 56, 5), C_AMBER.darkened(0.3))
	draw_rect(Rect2(464, 246, 58, 10), Color("#d5d0b2"))
	for line_y in range(248, 255, 3):
		draw_line(Vector2(470, line_y), Vector2(516, line_y), Color("#43384a"), 1)
	# Queue rails keep the counter zone readable.
	for rail_x in [296, 430, 604]:
		draw_line(Vector2(rail_x, 320), Vector2(rail_x, 370), C_AMBER, 4)
	draw_line(Vector2(296, 330), Vector2(430, 330), C_PINK_2, 3)
	draw_line(Vector2(430, 330), Vector2(604, 330), C_PINK_2, 3)
	# ATM at right, separated from the counter by a lit wall strip.
	draw_rect(Rect2(668, 116, 104, 174), Color("#10172a"))
	draw_rect(Rect2(680, 132, 80, 54), Color("#143f49"))
	draw_rect(Rect2(690, 144, 60, 10), C_CYAN.darkened(0.25))
	draw_rect(Rect2(692, 198, 56, 8), C_SOFT.darkened(0.4))
	for key_index in range(12):
		var key_x := 688 + (key_index % 3) * 21
		var key_y := 218 + int(key_index / 3) * 15
		draw_rect(Rect2(key_x, key_y, 13, 8), Color("#51566b"))
	draw_rect(Rect2(782, 102, 5, 204), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.35))
	# Main-floor return door.
	draw_rect(Rect2(812, 118, 70, 206), Color("#23152e"))
	draw_rect(Rect2(820, 128, 54, 184), Color("#100d1d"))
	draw_rect(Rect2(862, 220, 7, 7), C_YELLOW)
	_neon_text("FLOOR", Vector2(824, 152), 11, C_CYAN)
	_floor_reflections()


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
		"pawn_shop":
			_draw_sign_pulse(Rect2(292, 42, 320, 68), C_YELLOW, 0.13, 4.0)
			_draw_scan_bands(332, 570, 98, 218, C_SOFT, 0.12, 3.6)
			draw_rect(Rect2(410, 148, 72, 14), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.20 + abs(sin(flicker * 3.4)) * 0.16))
			_draw_smoke_bands(66, 826, 86, C_CYAN, 0.018)
			_draw_sparkles(SCENE_SPARKLES_PAWN_SHOP, C_YELLOW, 0.18)
		"bar":
			_draw_sign_pulse(Rect2(616, 52, 122, 40), C_PINK, 0.22, 4.0)
			_draw_sign_pulse(Rect2(596, 102, 172, 34), C_CYAN, 0.17, 5.4)
			draw_circle(Vector2(642 + sin(flicker * 1.5) * 7.0, 222), 5, C_WHITE)
			draw_circle(Vector2(756 + cos(flicker * 1.7) * 5.0, 232), 4, C_WHITE)
			_draw_smoke_bands(96, 520, 72, C_CYAN, 0.035)
			_draw_sparkles(SCENE_SPARKLES_BAR, C_YELLOW, 0.20)
		"jazz_club":
			_draw_sign_pulse(Rect2(116, 38, 302, 54), C_AMBER, 0.16, 3.6)
			_draw_sign_pulse(Rect2(696, 146, 124, 34), C_PINK, 0.20, 4.8)
			_draw_smoke_bands(58, 826, 76, C_AMBER, 0.045)
			_draw_smoke_bands(140, 760, 132, C_CYAN, 0.026)
			_draw_sparkles(SCENE_SPARKLES_JAZZ_CLUB, C_YELLOW, 0.18)
		"kitty_cat_lounge":
			_draw_sign_pulse(Rect2(116, 46, 404, 48), C_PINK, 0.18, 3.8)
			_draw_smoke_bands(70, 820, 92, C_PINK, 0.044)
			_draw_smoke_bands(120, 760, 138, C_CYAN, 0.026)
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
			_draw_headlights()
			_draw_scan_bands(0, 900, 42, 76, C_SOFT, 0.08, 2.4)
		"small_underground_casino":
			for i in range(6):
				var x := int(fmod(flicker * 16.0 + float(i * 160), 1040.0)) - 120
				draw_rect(Rect2(x, 116 + i * 18, 260, 16), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.045))
			_draw_smoke_bands(24, 840, 92, C_PINK, 0.05)
			_draw_string_lights()
			_draw_sparkles(SCENE_SPARKLES_UNDERGROUND, C_TEAL, 0.16)
		"grand_casino", "grand_casino_high_limit", "grand_casino_back_room":
			var low_detail := _grand_casino_web_low_detail()
			var light_count := 3 if low_detail else 5
			for i in range(light_count):
				var x := 300 + i * 150 if low_detail else 250 + i * 100
				draw_rect(Rect2(x, 124, 52, 8), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.12 + abs(sin(flicker * 3.2 + i)) * (0.12 if low_detail else 0.20)))
			_draw_sign_pulse(Rect2(336, 58, 226, 54), C_YELLOW, 0.14, 3.8)
			if not low_detail:
				_draw_sparkles(SCENE_SPARKLES_GRAND_CASINO, C_YELLOW, 0.18)
		"grand_casino_cage":
			_draw_sign_pulse(Rect2(338, 40, 224, 48), C_YELLOW, 0.12, 3.4)
			var terminal_scan := 138 + int(abs(sin(flicker * 1.6)) * 38.0)
			draw_rect(Rect2(682, terminal_scan, 76, 3), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.30))
			for bar_x in range(294, 620, 30):
				draw_rect(Rect2(bar_x, 124, 3, 112), Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.12 + abs(sin(flicker * 1.8 + bar_x)) * 0.08))


func _draw_linda_cage_silhouette(authored_feet: Vector2) -> void:
	var cage_state: Dictionary = foundation_snapshot.get("linda_cage", {}) if typeof(foundation_snapshot.get("linda_cage", {})) == TYPE_DICTIONARY else {}
	var pose_index := clampi(int(cage_state.get("pose_index", 1)), 0, 3)
	var facing := str(cage_state.get("facing", "left"))
	var feet := authored_feet
	var idle_y: float = 0.0 if reduce_motion else sin(flicker * 1.7 + float(pose_index)) * 1.5
	var pos: Vector2 = feet + Vector2(0, idle_y)
	# Featureless by contract: opaque head/body only, with no skin, eye, nose,
	# mouth, or hair layers. The bars are redrawn across her afterward.
	draw_rect(Rect2(pos.x - 16, pos.y - 74, 32, 30), Color("#03040a"))
	draw_rect(Rect2(pos.x - 25, pos.y - 46, 50, 48), Color("#04050b"))
	draw_rect(Rect2(pos.x - 31 if facing == "left" else pos.x + 21, pos.y - 39, 10, 38), Color("#03040a"))
	draw_rect(Rect2(pos.x - 19, pos.y - 43, 38, 5), Color(C_PURPLE.r, C_PURPLE.g, C_PURPLE.b, 0.35))
	for bar_x in range(294, 620, 15):
		draw_rect(Rect2(bar_x, 124, 4, 112), Color("#6b7080"))


func _draw_named_character(id: String, foot: Vector2, scale_value: float, role: String, facing: String = "right") -> void:
	var style := _character_style(id)
	var skin: Color = style["skin"]
	var hair: Color = style["hair"]
	var jacket: Color = style["jacket"]
	var accent: Color = style["accent"]
	var idle_profile := _character_idle_profile("named:%s" % id, role, style)
	var idle_state := _character_idle_state(idle_profile, flicker)
	var pose := str(idle_state.get("pose", "idle"))
	var pos := foot + Vector2(float(idle_state.get("sway", 0.0)), float(idle_state.get("bob", 0.0)))
	var head_shift := Vector2(float(idle_state.get("head_x", 0.0)), float(idle_state.get("head_y", 0.0))) * scale_value
	var head := Rect2(pos + Vector2(-10, -66) * scale_value, Vector2(20, 20) * scale_value)
	head.position += head_shift
	var body := Rect2(pos + Vector2(-17, -46) * scale_value, Vector2(34, 44) * scale_value)
	var shoulder_y := pos.y - 38 * scale_value
	draw_rect(Rect2(pos.x - 18 * scale_value, pos.y - 6 * scale_value, 36 * scale_value, 4 * scale_value), Color(0.0, 0.0, 0.0, 0.36))
	draw_rect(body, Color("#06070c"))
	draw_rect(Rect2(body.position + Vector2(3, 4) * scale_value, body.size - Vector2(6, 7) * scale_value), jacket)
	var gesture_amount := float(idle_state.get("gesture_amount", 0.0))
	_draw_named_character_arm(pos, scale_value, accent, skin, pose, true, gesture_amount)
	_draw_named_character_arm(pos, scale_value, accent, skin, pose, false, gesture_amount)
	draw_rect(head, skin)
	draw_rect(Rect2(head.position + Vector2(0, 0), Vector2(head.size.x, 7 * scale_value)), hair)
	var eye_offset := float(idle_state.get("eye_offset", 0.0)) * scale_value
	var left_eye := head.position + Vector2(4, 9) * scale_value + Vector2(eye_offset, 0.0)
	var right_eye := head.position + Vector2(13, 9) * scale_value + Vector2(eye_offset, 0.0)
	var eye_height := 1.0 if bool(idle_state.get("blink", false)) else 3.0
	draw_rect(Rect2(left_eye, Vector2(4, eye_height) * scale_value), Color("#05060a"))
	draw_rect(Rect2(right_eye, Vector2(4, eye_height) * scale_value), Color("#05060a"))
	var effective_facing := facing
	if pose == "lookaround":
		effective_facing = "left" if float(idle_state.get("eye_offset", 0.0)) < 0.0 else "right"
	var nose_x := head.position.x - 2.0 * scale_value if effective_facing == "left" else head.end.x
	draw_rect(Rect2(nose_x, head.position.y + 12.0 * scale_value, 3.0 * scale_value, 3.0 * scale_value), skin)
	draw_rect(Rect2(pos + Vector2(-15, -48) * scale_value, Vector2(30, 5) * scale_value), accent)
	draw_line(Vector2(pos.x - 24 * scale_value, shoulder_y), Vector2(pos.x + 24 * scale_value, shoulder_y), Color(accent.r, accent.g, accent.b, 0.45), maxf(1.0, 3.0 * scale_value))
	var prop_lift := -2.0 * float(idle_state.get("gesture_amount", 0.0)) * scale_value
	match role:
		"watcher", "bouncer", "pit_boss":
			draw_rect(Rect2(pos + Vector2(14, -55) * scale_value + Vector2(0.0, prop_lift), Vector2(10, 4) * scale_value), C_PINK)
		"dealer":
			_card_back(Rect2(pos + Vector2(-25, -26) * scale_value + Vector2(0.0, prop_lift), Vector2(16, 22) * scale_value))
		"bartender", "attendant", "clerk":
			draw_rect(Rect2(pos + Vector2(16, -24) * scale_value + Vector2(0.0, prop_lift), Vector2(7, 16) * scale_value), C_AMBER)
		"regular", "fixer":
			draw_rect(Rect2(pos + Vector2(-25, -20) * scale_value + Vector2(0.0, prop_lift), Vector2(16, 5) * scale_value), C_CYAN)


func _draw_named_character_arm(pos: Vector2, scale_value: float, accent: Color, skin: Color, pose: String, left: bool, gesture_amount: float) -> void:
	var side := -1.0 if left else 1.0
	var shoulder := pos + Vector2(side * 18.0, -37.0) * scale_value
	var resting_hand := pos + Vector2(side * 22.0, -8.0) * scale_value
	var hand := resting_hand
	match pose:
		"arms_folded":
			hand = pos + Vector2(-side * 9.0, -27.0) * scale_value
		"chin_touch":
			if not left:
				hand = pos + Vector2(8.0, -52.0) * scale_value
		"pocket_check":
			if left:
				hand = pos + Vector2(-9.0, -16.0) * scale_value
		"adjust_cuff":
			hand = pos + Vector2(-side * 5.0, -21.0 if left else -25.0) * scale_value
		"counter_tap", "card_check":
			hand = pos + Vector2(side * 14.0, -19.0 if left else -16.0) * scale_value
		"shoulder_roll":
			hand = pos + Vector2(side * (28.0 if left else 18.0), -19.0 if left else -11.0) * scale_value
		"lookaround":
			hand = pos + Vector2(side * 24.0, -13.0) * scale_value
	hand = resting_hand.lerp(hand, clampf(gesture_amount, 0.0, 1.0))
	draw_line(shoulder, hand, Color("#05060a"), maxf(2.0, 7.0 * scale_value))
	draw_line(shoulder, hand, Color(accent.r, accent.g, accent.b, 0.30), maxf(1.0, 2.0 * scale_value))
	draw_rect(Rect2(hand - Vector2(2.5, 2.0) * scale_value, Vector2(5.0, 5.0) * scale_value), skin)


func _draw_rival_cheater(rival: Dictionary, foot: Vector2) -> void:
	var tell := str(rival.get("tell", "chip_riffle"))
	_draw_rival_cheater_tell(tell, int(rival.get("idle_phase", 0)), foot)


func _draw_rival_cheater_tell(tell: String, idle_phase: int, foot: Vector2) -> void:
	var style_id := "dot"
	match tell:
		"sleeve_check":
			style_id = "marco"
		"heel_tap":
			style_id = "vince"
		"glance_loop":
			style_id = "lena"
		"ring_turn":
			style_id = "june"
		"counting_lips":
			style_id = "sable"
	var phase := float(idle_phase % 628) / 100.0
	var tell_motion := sin(flicker * (2.2 if tell == "heel_tap" else 1.4) + phase)
	var animated_foot := foot + Vector2(0.0, tell_motion * (3.0 if tell == "heel_tap" else 1.2))
	_draw_named_character(style_id, animated_foot, 0.74, "regular", "left" if tell == "glance_loop" and tell_motion < 0.0 else "right")
	match tell:
		"chip_riffle":
			draw_circle(animated_foot + Vector2(-18, -18 + tell_motion * 3.0), 4, C_YELLOW)
			draw_circle(animated_foot + Vector2(-10, -16 - tell_motion * 3.0), 4, C_PINK)
		"sleeve_check":
			draw_rect(Rect2(animated_foot + Vector2(16 + tell_motion * 4.0, -34), Vector2(12, 5)), C_CYAN)
		"heel_tap":
			draw_line(animated_foot + Vector2(8, -1), animated_foot + Vector2(22 + tell_motion * 5.0, 1), C_PINK, 3)
		"glance_loop":
			draw_line(animated_foot + Vector2(-10, -52), animated_foot + Vector2(12 * tell_motion, -52), C_CYAN, 2)
		"ring_turn":
			draw_circle(animated_foot + Vector2(19, -27), 4 + absf(tell_motion) * 2.0, C_AMBER, false, 2)
		"counting_lips":
			draw_rect(Rect2(animated_foot + Vector2(-6, -42), Vector2(12 + tell_motion * 3.0, 3)), C_PINK)


func _character_style(id: String) -> Dictionary:
	var styles := {
		"mara": {"skin": Color("#d9a36a"), "hair": Color("#271018"), "jacket": Color("#24404a"), "accent": C_CYAN, "tempo": 1.0, "phase": 0.2, "idle_primary": "counter_tap", "idle_secondary": "lookaround"},
		"alley_merchant": {"skin": Color("#9c684f"), "hair": Color("#241910"), "jacket": Color("#28301f"), "accent": C_AMBER, "tempo": 0.75, "phase": 1.5, "idle_primary": "pocket_check", "idle_secondary": "chin_touch"},
		"motel_clerk": {"skin": Color("#c99572"), "hair": Color("#1c2630"), "jacket": Color("#30404a"), "accent": C_TEAL, "tempo": 0.8, "phase": 2.8, "idle_primary": "adjust_cuff", "idle_secondary": "lookaround"},
		"silas": {"skin": Color("#b77a62"), "hair": Color("#19151f"), "jacket": Color("#1d2535"), "accent": C_PURPLE_2, "tempo": 1.15, "phase": 0.9, "idle_primary": "chin_touch", "idle_secondary": "card_check"},
		"vince": {"skin": Color("#a66a50"), "hair": Color("#06070c"), "jacket": Color("#34102b"), "accent": C_PINK, "tempo": 1.6, "phase": 2.1, "idle_primary": "shoulder_roll", "idle_secondary": "lookaround"},
		"lena": {"skin": Color("#c98665"), "hair": Color("#161025"), "jacket": Color("#273344"), "accent": C_AMBER, "tempo": 1.3, "phase": 0.7, "idle_primary": "lookaround", "idle_secondary": "adjust_cuff"},
		"june": {"skin": Color("#d0a07c"), "hair": Color("#332010"), "jacket": Color("#21363a"), "accent": C_TEAL, "tempo": 0.9, "phase": 1.8, "idle_primary": "card_check", "idle_secondary": "arms_folded"},
		"marco": {"skin": Color("#bd7b5d"), "hair": Color("#0f0b0a"), "jacket": Color("#3d2142"), "accent": C_ORANGE, "tempo": 1.1, "phase": 2.5, "idle_primary": "pocket_check", "idle_secondary": "shoulder_roll"},
		"rafi": {"skin": Color("#b7755c"), "hair": Color("#08090e"), "jacket": Color("#2f1a18"), "accent": C_YELLOW, "tempo": 1.4, "phase": 0.4, "idle_primary": "counter_tap", "idle_secondary": "arms_folded"},
		"dot": {"skin": Color("#dfb28d"), "hair": Color("#551b42"), "jacket": Color("#26315a"), "accent": C_PINK_2, "tempo": 1.8, "phase": 1.0, "idle_primary": "adjust_cuff", "idle_secondary": "shoulder_roll"},
		"nell": {"skin": Color("#c48968"), "hair": Color("#513315"), "jacket": Color("#27384f"), "accent": C_YELLOW, "tempo": 0.8, "phase": 1.4, "idle_primary": "chin_touch", "idle_secondary": "lookaround"},
		"sable": {"skin": Color("#b87a63"), "hair": Color("#05060a"), "jacket": Color("#1b2f2a"), "accent": C_TEAL, "tempo": 0.7, "phase": 2.0, "idle_primary": "arms_folded", "idle_secondary": "pocket_check"},
		"ox": {"skin": Color("#8f5a48"), "hair": Color("#05060a"), "jacket": Color("#11131f"), "accent": C_ORANGE, "tempo": 0.55, "phase": 0.0, "idle_primary": "arms_folded", "idle_secondary": "shoulder_roll"},
		"rourke": {"skin": Color("#d1a072"), "hair": Color("#ede0b5"), "jacket": Color("#161017"), "accent": C_PINK, "tempo": 0.65, "phase": 1.2, "idle_primary": "chin_touch", "idle_secondary": "adjust_cuff"},
		"iris": {"skin": Color("#cca17e"), "hair": Color("#2b1630"), "jacket": Color("#20203c"), "accent": C_CYAN, "tempo": 0.85, "phase": 2.6, "idle_primary": "card_check", "idle_secondary": "lookaround"},
		"sal": {"skin": Color("#bf8366"), "hair": Color("#1b1210"), "jacket": Color("#24212a"), "accent": C_YELLOW, "tempo": 0.60, "phase": 1.7, "idle_primary": "counter_tap", "idle_secondary": "pocket_check"},
	}
	return styles.get(id, styles["mara"])
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
	var sheen_count := 3 if _grand_casino_web_low_detail() else 7
	for i in range(sheen_count):
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
	var low_detail := _grand_casino_web_low_detail()
	var objects := _active_scene_objects()
	# Static rooms retain the layout built with their scene cache. Only authored
	# live routes need a global relayout each frame; placement previews resolve the
	# moving owner's label directly without the all-pairs label pass.
	if scene_has_live_actor_routes:
		_rebuild_object_label_rect_cache(objects)
	var behind_counter := behind_counter_scene_objects_cache
	var room_standard := room_front_scene_objects_cache
	var room_front := room_top_scene_objects_cache
	if not scene_object_cache_valid:
		behind_counter = []
		room_standard = []
		room_front = []
		for object_value in objects:
			var object_data := object_value as Dictionary
			match _scene_object_draw_layer(object_data):
				-1: behind_counter.append(object_data)
				1: room_front.append(object_data)
				_: room_standard.append(object_data)
	# The three authored layers are strict: counter fronts separate Behind from
	# Standard, and Front is painted last above every lower object layer.
	for object_value in behind_counter:
		_draw_scene_object_body(object_value as Dictionary)
	_draw_room_foreground_occluders(behind_counter)
	for object_value in room_standard:
		_draw_scene_object_body(object_value as Dictionary)
	for object_value in room_front:
		_draw_scene_object_body(object_value as Dictionary)
	# Labels and focus affordances stay above fixtures and remain fully usable.
	for object_value in objects:
		_draw_scene_object_adornments(object_value as Dictionary, low_detail)
	if not developer_placement_mode and not developer_slot_placement_mode:
		_draw_selected_object_info()


func _draw_scene_object_body(object_data: Dictionary) -> void:
	var rect := _natural_model_rect_for_object(object_data)
	var object_id := str(object_data.get("id", ""))
	var object_type := str(object_data.get("type", "item"))
	var active := object_labels_and_borders_enabled and (object_id == selected_object_id or object_id == hovered_object_id)
	_draw_object_shadow(rect, active, str(object_data.get("shadow_kind", "base")))
	if _draw_manifest_specific_object(rect, object_data, active):
		return
	match object_type:
		"game":
			_draw_game_prop(rect, object_data, active)
		"travel":
			_draw_travel_prop(rect, object_data, active)
		"event":
			_draw_event_prop(rect, object_data, active)
		"character":
			_draw_character_actor(rect, object_data)
		"scenario_actor":
			_draw_scenario_actor(rect, object_data, active)
		"scenario_object":
			_draw_scenario_prop(rect, object_data, active)
		"drink":
			_draw_drink_prop(rect, active)
		_:
			_draw_item_prop(rect, object_data, active, str(object_data.get("surface", "counter")))


func _draw_manifest_specific_object(rect: Rect2, object_data: Dictionary, active: bool) -> bool:
	if not bool(object_data.get("manifest_physical", false)):
		return false
	var render_key := str(object_data.get("manifest_render_key", object_data.get("visual_key", ""))).strip_edges().to_lower()
	var metadata := _copy_dictionary(object_data.get("manifest_metadata", {}))
	var feet := Vector2(rect.get_center().x, rect.end.y - 2.0)
	if render_key == "fixed_host_linda":
		_draw_linda_cage_silhouette(feet)
		if active:
			draw_rect(rect.grow(2.0), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.34), false, 2.0)
		return true
	if render_key == "grand_rourke":
		_draw_named_character("rourke", feet, clampf(rect.size.y / 80.0, 0.58, 1.15), "pit_boss", str(metadata.get("facing", "right")))
		if active:
			draw_rect(rect.grow(2.0), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.34), false, 2.0)
		return true
	if render_key == "grand_rival":
		_draw_rival_cheater(metadata, feet)
		if active:
			draw_rect(rect.grow(2.0), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.34), false, 2.0)
		return true

	var character_id := ""
	var character_role := "regular"
	match render_key:
		"fixed_host_mara":
			character_id = "mara"
			character_role = "clerk"
		"fixed_host_back_alley_merchant":
			character_id = "alley_merchant"
			character_role = "fixer"
		"fixed_host_motel_clerk":
			character_id = "motel_clerk"
			character_role = "clerk"
		"fixed_host_rafi", "jazz_bartender":
			character_id = "rafi"
			character_role = "bartender"
		"fixed_host_iris":
			character_id = "iris"
			character_role = "host"
		"fixed_host_sable":
			character_id = "sable"
			character_role = "dealer"
		"fixed_host_ox":
			character_id = "ox"
			character_role = "bouncer"
		"fixed_host_sal":
			character_id = "sal"
			character_role = "clerk"
		"fixed_host_june":
			character_id = "june"
			character_role = "dealer"
		"fixed_host_marco":
			character_id = "marco"
			character_role = "fixer"
		"fixed_host_vince":
			character_id = "vince"
			character_role = "watcher"
		"fixed_host_lena":
			character_id = "lena"
			character_role = "dealer"
		"fixed_host_dot":
			character_id = "dot"
			character_role = "regular"
		"fixed_host_nell":
			character_id = "nell"
			character_role = "attendant"
		"numbers_silas":
			character_id = "silas"
			character_role = "watcher"
	if not character_id.is_empty():
		_draw_named_character(character_id, feet, clampf(rect.size.y / 80.0, 0.48, 1.15), character_role, str(metadata.get("facing", "right")))
		if active:
			draw_rect(rect.grow(2.0), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.34), false, 2.0)
		return true
	match render_key:
		"jazz_musician_sax", "jazz_musician_cello", "jazz_musician_drummer":
			var instrument := "sax" if render_key.ends_with("_sax") else "cello" if render_key.ends_with("_cello") else "drums"
			var scale_value := clampf(rect.size.y / 88.0, 0.48, 1.15)
			_draw_jazz_player(Vector2(rect.get_center().x, rect.end.y - 2.0), scale_value, instrument)
			if active:
				draw_rect(rect.grow(2.0), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.34), false, 2.0)
			return true
		"jazz_tip_jar":
			var jar := Rect2(
				rect.position + Vector2(rect.size.x * 0.30, rect.size.y * 0.22),
				Vector2(rect.size.x * 0.40, rect.size.y * 0.58)
			)
			draw_rect(jar, Color("#21131a"))
			draw_rect(jar, C_AMBER if active else C_CYAN, false, 2.0)
			draw_rect(Rect2(jar.position + Vector2(jar.size.x * 0.12, -3.0), Vector2(jar.size.x * 0.76, 4.0)), C_SOFT)
			_neon_text("TIP", jar.position + Vector2(2.0, jar.size.y * 0.62), 8, C_YELLOW)
			return true
		"jazz_band_stage":
			var mark := Rect2(rect.position + Vector2(rect.size.x * 0.08, rect.size.y * 0.58), Vector2(rect.size.x * 0.84, maxf(5.0, rect.size.y * 0.18)))
			draw_rect(mark, Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.20 if not active else 0.38))
			draw_line(mark.position, Vector2(mark.end.x, mark.position.y), C_AMBER, 2.0)
			return true
	return false


func _draw_scene_object_adornments(object_data: Dictionary, low_detail: bool) -> void:
	var rect := _natural_model_rect_for_object(object_data)
	var object_id := str(object_data.get("id", ""))
	var object_type := str(object_data.get("type", "item"))
	var selected := object_id == selected_object_id
	var hovered := object_id == hovered_object_id
	var disabled := bool(object_data.get("disabled", false))
	if disabled:
		_draw_disabled_scene_mark(rect)
	if not object_labels_and_borders_enabled:
		return
	if disabled and (selected or hovered):
		_draw_disabled_focus_mark(rect, selected)
	elif selected:
		_draw_selected_scene_mark(rect)
		if object_type in ["item", "drink"]:
			_draw_selected_item_frame(rect, object_type)
	elif hovered:
		_draw_hover_scene_mark(rect)
	elif should_draw_hotspot_hint(object_data, low_detail):
		_draw_hotspot_hint(rect, object_type)
	_draw_object_label(rect, str(object_data.get("label", "")), object_type, disabled, selected or hovered, object_data)


func _draw_scenario_prop(rect: Rect2, object_data: Dictionary, active: bool) -> void:
	var role := str(object_data.get("role", "prop"))
	var accent := C_ORANGE if role == "obstacle" else C_PURPLE_2 if role == "exit" else C_CYAN_2
	# Scenario props use the same concrete icon vocabulary as ordinary event
	# props. The semantic icon key chooses paper, furniture, barriers, lights,
	# refreshments, machinery, or doors. Room placement never authorizes the
	# generic room-fixture fallback.
	_draw_event_prop(rect, object_data, active)
	if role in ["obstacle", "exit"]:
		var mark := "!" if role == "obstacle" else ">"
		_neon_text(mark, rect.position + Vector2(5.0, 14.0), 12, C_WHITE)
	if not str(object_data.get("state", "")).is_empty():
		draw_line(rect.position + Vector2(8.0, rect.size.y - 9.0), rect.end - Vector2(8.0, 9.0), accent, 3.0)
		_draw_public_prop_state_marker(rect, object_data)


func _draw_scenario_actor(rect: Rect2, object_data: Dictionary, active: bool) -> void:
	var behavior := str(object_data.get("behavior", "idle"))
	var pose := str(object_data.get("pose", "idle"))
	var accent := C_ORANGE if behavior in ["guard", "fight", "flee"] else C_TEAL
	var object_id := str(object_data.get("id", object_data.get("source_id", "scenario_actor")))
	var idle_profile := _character_idle_profile("object:%s/scenario" % object_id, behavior)
	var idle_state := _character_idle_state(idle_profile, flicker)
	var idle_pose := str(idle_state.get("pose", "idle")) if pose in ["", "idle", "watch", "watching"] else pose
	var center := rect.get_center() + Vector2(float(idle_state.get("sway", 0.0)), float(idle_state.get("bob", 0.0)))
	var head_radius := clampf(rect.size.x * 0.15, 6.0, 12.0)
	var head_center := Vector2(center.x, rect.position.y + head_radius + 4.0 + float(idle_state.get("bob", 0.0))) + Vector2(float(idle_state.get("head_x", 0.0)), float(idle_state.get("head_y", 0.0)))
	draw_circle(head_center, head_radius, C_SOFT.darkened(0.15))
	var body_top := rect.position.y + head_radius * 2.0 + 6.0
	var body := Rect2(Vector2(center.x - rect.size.x * 0.20, body_top), Vector2(rect.size.x * 0.40, maxf(16.0, rect.end.y - body_top - 8.0)))
	draw_rect(body, accent.darkened(0.42))
	draw_rect(body, accent.lightened(0.15) if active else accent, false, 2.0)
	var arm_y := body.position.y + body.size.y * 0.38
	var arm_spread := rect.size.x * (0.38 if pose in ["fight", "warning"] else 0.28)
	var gesture_amount := float(idle_state.get("gesture_amount", 0.0))
	var left_hand_y := arm_y
	var right_hand_y := arm_y
	match idle_pose:
		"arms_folded", "card_check", "adjust_cuff":
			arm_spread = lerpf(arm_spread, rect.size.x * 0.12, gesture_amount)
			left_hand_y += 5.0 * gesture_amount
			right_hand_y -= 2.0 * gesture_amount
		"chin_touch":
			right_hand_y -= head_radius * 2.2 * gesture_amount
		"pocket_check", "counter_tap":
			left_hand_y += 8.0 * gesture_amount
		"shoulder_roll":
			left_hand_y -= 6.0 * gesture_amount
			right_hand_y += 5.0 * gesture_amount
	draw_line(Vector2(center.x, arm_y), Vector2(center.x - arm_spread, left_hand_y), accent, 3.0)
	draw_line(Vector2(center.x, arm_y), Vector2(center.x + arm_spread, right_hand_y), accent, 3.0)
	if behavior in ["guard", "watch", "patrol"]:
		_neon_text("EYE", Vector2(center.x - 10.0, rect.end.y - 4.0), 8, C_WHITE)


func _draw_selected_object_info() -> void:
	var info := _selected_object_info()
	if info.is_empty():
		return
	var object_data: Dictionary = info.get("object", {})
	var expanded := bool(info.get("expanded", false))
	var object_type := str(object_data.get("type", "item"))
	var interaction_type := str(object_data.get("interaction_type", object_type))
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
	var type_text := _player_facing_object_type(interaction_type)
	var title_text := title if not title.is_empty() else type_text
	var type_width := _object_info_type_width(type_text, font)
	var status_icon_rect := Rect2(
		Vector2(card.end.x - OBJECT_INFO_PADDING_X - type_width - OBJECT_INFO_TYPE_GAP - OBJECT_INFO_STATUS_ICON_SIZE, card.position.y + 3.0),
		Vector2(OBJECT_INFO_STATUS_ICON_SIZE, OBJECT_INFO_STATUS_ICON_SIZE)
	)
	var title_width := maxf(20.0, status_icon_rect.position.x - card.position.x - OBJECT_INFO_PADDING_X - OBJECT_INFO_STATUS_ICON_GAP)
	draw_string(font, card.position + Vector2(OBJECT_INFO_PADDING_X, OBJECT_INFO_HEADER_Y), _fit_draw_text(title_text, font, 11, title_width), HORIZONTAL_ALIGNMENT_LEFT, title_width, 11, header_color)
	_draw_object_interaction_status_icon(status_icon_rect, _object_info_is_actionable(object_data))
	draw_string(font, card.position + Vector2(card.size.x - OBJECT_INFO_PADDING_X - type_width, OBJECT_INFO_HEADER_Y), _fit_draw_text(type_text, font, 8, type_width), HORIZONTAL_ALIGNMENT_RIGHT, type_width, 8, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.82))
	var y := card.position.y + OBJECT_INFO_BODY_Y
	if lines.is_empty():
		lines = [_fallback_object_description(object_data)]
	var badges := _array_view(object_data.get("attribute_badges", []))
	if expanded and not badges.is_empty():
		var badge_entries := _selected_info_badge_entries_for_rect(object_data, card, y)
		var row_rect := AttributeBadgeRowScript.draw_canvas(self, badges, Vector2(card.position.x + OBJECT_INFO_PADDING_X, y - OBJECT_INFO_BADGE_RAISE), card.size.x - OBJECT_INFO_PADDING_X * 2.0, 16)
		selected_info_badge_hit_entries = badge_entries
		y += row_rect.size.y + 4.0
	var action_area_height := _selected_info_action_area_height(object_data, card.size.x - OBJECT_INFO_PADDING_X * 2.0) if expanded else 0.0
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
				draw_multiline_string(font, detail_rect.position + Vector2(0.0, 9.0), detail, HORIZONTAL_ALIGNMENT_CENTER, detail_rect.size.x, 8, OBJECT_INFO_INLINE_ACTION_DETAIL_MAX_LINES, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.86), TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND)
	_draw_selected_info_badge_hover_text(font)


func _draw_object_interaction_status_icon(rect: Rect2, actionable: bool) -> void:
	var color := C_TEAL if actionable else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.66)
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.52))
	draw_rect(rect, color, false, 1.0)
	if actionable:
		var center := rect.get_center()
		var left := Vector2(rect.position.x + 3.0, center.y)
		var right := Vector2(rect.end.x - 3.0, center.y)
		draw_line(left, right, color, 2.0)
		draw_line(right, right + Vector2(-3.0, -3.0), color, 2.0)
		draw_line(right, right + Vector2(-3.0, 3.0), color, 2.0)
	else:
		draw_line(rect.position + Vector2(3.0, 3.0), rect.end - Vector2(3.0, 3.0), color, 2.0)
		draw_line(Vector2(rect.end.x - 3.0, rect.position.y + 3.0), Vector2(rect.position.x + 3.0, rect.end.y - 3.0), color, 2.0)


func _draw_selected_info_badge_hover_text(font: Font) -> void:
	var text := selected_info_badge_hover_text.strip_edges()
	if text.is_empty():
		return
	var mouse_board_position := _local_to_board_position(selected_info_badge_hover_local_position)
	var text_width := minf(176.0, maxf(58.0, _draw_text_width(text, font, 9) + 10.0))
	var rect := Rect2(mouse_board_position + Vector2(10.0, 10.0), Vector2(text_width, 18.0))
	if rect.end.x > BOARD_SIZE.x - 4.0:
		rect.position.x = maxf(4.0, BOARD_SIZE.x - 4.0 - rect.size.x)
	if rect.end.y > BOARD_SIZE.y - 4.0:
		rect.position.y = maxf(4.0, mouse_board_position.y - rect.size.y - 10.0)
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.90))
	draw_rect(rect, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.86), false, 1.0)
	draw_string(font, rect.position + Vector2(5.0, 12.5), _fit_draw_text(text, font, 9, rect.size.x - 10.0), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 10.0, 9, C_WHITE)


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
	var rect := _natural_model_rect_for_object(selected_object)
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
	var object_rect := _natural_model_rect_for_object(object_data)
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
	if scene_object_cache_valid:
		return active_scene_objects_cache
	return _ordered_scene_objects()


func _ordered_scene_objects() -> Array:
	var active := foundation_scene_objects if uses_foundation_snapshot else scene_objects
	var has_layout_authority := false
	for value in active:
		if typeof(value) == TYPE_DICTIONARY and bool((value as Dictionary).get("scenario_layout_resolved", false)):
			has_layout_authority = true
			break
	if not has_layout_authority:
		return active
	var ordered := active.duplicate()
	ordered.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left: Dictionary = left_value if typeof(left_value) == TYPE_DICTIONARY else {}
		var right: Dictionary = right_value if typeof(right_value) == TYPE_DICTIONARY else {}
		var left_key := _scene_object_z_key(left)
		var right_key := _scene_object_z_key(right)
		return left_key < right_key if left_key != right_key else str(left.get("id", "")) < str(right.get("id", ""))
	)
	return ordered


func _rebuild_scene_object_cache() -> void:
	scene_object_cache_rebuild_count += 1
	active_scene_objects_cache = _ordered_scene_objects()
	behind_counter_scene_objects_cache = []
	room_front_scene_objects_cache = []
	room_top_scene_objects_cache = []
	scene_object_cache_valid = true
	_rebuild_object_label_rect_cache(active_scene_objects_cache)
	scene_objects_by_id_cache = {}
	scene_has_live_actor_routes = false
	developer_slot_occupants_by_id_cache = {}
	developer_required_slot_ids_cache = {}
	for row_value in _developer_manifest_rows():
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row := row_value as Dictionary
		var required_slot_id := str(row.get("exact_slot_id", "")).strip_edges()
		if not required_slot_id.is_empty() and bool(row.get("active", true)) \
				and bool(row.get("physical", true)) and bool(row.get("required", false)):
			developer_required_slot_ids_cache[required_slot_id] = true
	for object_value in active_scene_objects_cache:
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = object_value
		match _scene_object_draw_layer(object_data):
			-1: behind_counter_scene_objects_cache.append(object_data)
			1: room_top_scene_objects_cache.append(object_data)
			_: room_front_scene_objects_cache.append(object_data)
		var object_id := str(object_data.get("id", ""))
		if not object_id.is_empty():
			scene_objects_by_id_cache[object_id] = object_data
		var slot_id := str(object_data.get("slot_id", "")).strip_edges()
		if not slot_id.is_empty():
			var occupants_value: Variant = developer_slot_occupants_by_id_cache.get(slot_id, [])
			var occupants: Array = occupants_value as Array if typeof(occupants_value) == TYPE_ARRAY else []
			occupants.append(object_data)
			developer_slot_occupants_by_id_cache[slot_id] = occupants
			if bool(object_data.get("manifest_required", false)):
				developer_required_slot_ids_cache[slot_id] = true
		var route_stage_value: Variant = object_data.get("actor_route_stage", {})
		var route_points_value: Variant = object_data.get("actor_route_points", [])
		if typeof(route_stage_value) == TYPE_DICTIONARY and not (route_stage_value as Dictionary).is_empty() \
				and typeof(route_points_value) == TYPE_ARRAY and (route_points_value as Array).size() >= 2:
			scene_has_live_actor_routes = true
		AttributeBadgeRowScript.warm_cache(_array_view(object_data.get("attribute_badges", [])), 14)
		_warm_object_info_layout_cache(object_data)
	_invalidate_developer_slot_derived_caches()


func _objects_from_foundation_snapshot(snapshot: Dictionary) -> Array:
	var interactable_objects: Array = snapshot.get("interactable_objects", [])
	var objects: Array = []
	if not interactable_objects.is_empty():
		objects = _objects_from_interactable_records(interactable_objects)
		# The composed interaction catalog is the room. It already contains ordinary
		# environment records and scenario additions with their final shared-plane
		# geometry, so no renderer-only layer may relocate or supplement it.
		objects.sort_custom(Callable(PixelSceneCanvas, "_sort_composed_scene_objects"))
		return objects
	else:
		var games := JsonCoerceScript._raw_string_array(snapshot.get("game_ids", []))
		for index in range(games.size()):
			objects.append({
			"id": "game:%s" % games[index],
			"type": "game",
			"position": Vector2(0.28 + float(index % 3) * 0.18, 0.56 + float(index / 3) * 0.13),
			"size": Vector2(118, 72),
			})
		var events := JsonCoerceScript._raw_string_array(snapshot.get("event_ids", []))
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
		var travel_targets := JsonCoerceScript._raw_string_array(snapshot.get("next_archetypes", []))
		if travel_targets.is_empty():
			travel_targets = JsonCoerceScript._raw_string_array(snapshot.get("travel_hooks", []))
		if not travel_targets.is_empty():
			objects.append({
			"id": "travel:leave",
			"type": "travel",
			"label": "Leave",
			"prop": "door",
			"position": Vector2(0.78, 0.64),
			"size": Vector2(118, 64),
			})
	var ids: Dictionary = {}
	for object_value in objects:
		if typeof(object_value) == TYPE_DICTIONARY:
			ids[str((object_value as Dictionary).get("id", ""))] = true
	var render_snapshot_value: Variant = snapshot.get("scenario_render_snapshot", {})
	var render_snapshot: Dictionary = render_snapshot_value as Dictionary if typeof(render_snapshot_value) == TYPE_DICTIONARY else {}
	if not EnvironmentObjectManifestScript.has_causal_scenario_renderer_snapshot(snapshot):
		objects.sort_custom(Callable(PixelSceneCanvas, "_sort_composed_scene_objects"))
		return objects
	# Active-stage text is public room status, not a physical prop. Its actions
	# remain available in the room action list; the canvas only renders authored
	# physical visual_objects, so no generic status boxes float along the wall.
	for visual_value in _array_view(render_snapshot.get("visual_objects", [])):
		if typeof(visual_value) != TYPE_DICTIONARY:
			continue
		var visual := visual_value as Dictionary
		var object_id := str(visual.get("object_id", ""))
		if object_id.is_empty() or ids.has(object_id) or not bool(visual.get("visible", true)):
			continue
		objects.append_array(_objects_from_interactable_records([visual]))
		ids[object_id] = true
	objects.sort_custom(Callable(PixelSceneCanvas, "_sort_composed_scene_objects"))
	return objects
func _objects_from_interactable_records(records: Array) -> Array:
	var objects: Array = []
	var rendered_slot_holders: Dictionary = {}
	var rendered_object_ids: Dictionary = {}
	for index in range(records.size()):
		if typeof(records[index]) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = records[index]
		if not bool(record.get("visible", true)) or str(record.get("presentation_mode", "room")) == "overflow":
			continue
		var object_id := str(record.get("object_id", ""))
		if object_id.is_empty():
			continue
		if rendered_object_ids.has(object_id):
			# Binding and placement audits retain the duplicate identities. The
			# renderer only needs a deterministic last-line defense, and may be
			# exercised repeatedly by diagnostic fixtures without flooding stderr.
			continue
		var slot_id := str(record.get("slot_id", "")).strip_edges()
		var slot_holder := str(rendered_slot_holders.get(slot_id, "")) if not slot_id.is_empty() else ""
		if not slot_holder.is_empty():
			continue
		rendered_object_ids[object_id] = true
		if not slot_id.is_empty():
			rendered_slot_holders[slot_id] = object_id
		var interaction_type := str(record.get("object_type", "info"))
		var object_type := str(record.get("visual_type", interaction_type))
		var normalized_rect := _normalized_rect_from_record(record)
		var focus_point := normalized_rect.position + normalized_rect.size * 0.5
		var layout_resolved := bool(record.get("scenario_layout_resolved", false)) or bool(record.get("fixed_slot_geometry", false))
		var minimum_visual_size := Vector2.ZERO if layout_resolved else _minimum_object_visual_size(object_type)
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
				maxf(normalized_rect.size.x * float(BOARD_SIZE.x), minimum_visual_size.x),
				maxf(normalized_rect.size.y * float(BOARD_SIZE.y), minimum_visual_size.y)
			),
			"disabled": not bool(record.get("enabled", true)),
			"disabled_reason": str(record.get("disabled_reason", "")),
			"action_summary": str(record.get("action_summary", "")),
			"status_summary": str(record.get("status_summary", "")),
			"effect_summary": str(record.get("effect_summary", "")),
			"impact_summary": str(record.get("impact_summary", "")),
			"choice_summary": str(record.get("choice_summary", "")),
			"risk_summary": str(record.get("risk_summary", "")),
			"classification_summary": str(record.get("classification_summary", "")),
			"addition_count": maxi(0, int(record.get("addition_count", 0))),
			"cost_summary": str(record.get("cost_summary", "")),
			"attribute_badges": _array_view(record.get("attribute_badges", [])),
			"runtime_state": record.get("runtime_state", {}) as Dictionary if typeof(record.get("runtime_state", {})) == TYPE_DICTIONARY else {},
			"visual_state": record.get("visual_state", {}) as Dictionary if typeof(record.get("visual_state", {})) == TYPE_DICTIONARY else {},
			"character_actor": record.get("character_actor", {}) as Dictionary if typeof(record.get("character_actor", {})) == TYPE_DICTIONARY else {},
			"owner_namespace": str(record.get("owner_namespace", "")),
			"stable_object_id": str(record.get("stable_object_id", "")),
			"semantic_role": str(record.get("semantic_role", "")),
			"semantic_state": str(record.get("semantic_state", "")),
			"semantic_appearance": str(record.get("semantic_appearance", "")),
			"anchor_id": str(record.get("anchor_id", "")),
			"zone_id": str(record.get("zone_id", "")),
			"actor_id": str(record.get("actor_id", "")),
			"actor_pose": str(record.get("actor_pose", "")),
			"actor_behavior": str(record.get("actor_behavior", "")),
			"actor_route_id": str(record.get("actor_route_id", "")),
			"actor_route_points": _array_view(record.get("actor_route_points", [])),
			"actor_route_stage": record.get("actor_route_stage", {}) as Dictionary if typeof(record.get("actor_route_stage", {})) == TYPE_DICTIONARY else {},
			"small_screen_rect": record.get("small_screen_rect", {}) as Dictionary if typeof(record.get("small_screen_rect", {})) == TYPE_DICTIONARY else {},
			"label_rect": record.get("label_rect", {}) as Dictionary if typeof(record.get("label_rect", {})) == TYPE_DICTIONARY else {},
			"small_screen_label_rect": record.get("small_screen_label_rect", {}) as Dictionary if typeof(record.get("small_screen_label_rect", {})) == TYPE_DICTIONARY else {},
			"fixed_slot_geometry": bool(record.get("fixed_slot_geometry", false)),
			"scenario_z_order": int(record.get("scenario_z_order", index)),
			"scenario_layout_resolved": bool(record.get("scenario_layout_resolved", false)),
			"scenario_layout_authority_identity": str(record.get("scenario_layout_authority_identity", "")),
			"scenario_layout_authority_digest": str(record.get("scenario_layout_authority_digest", "")),
			"source_order": index,
			"state_badge": str(record.get("state_badge", "")),
			"visual_key": str(record.get("visual_key", record.get("manifest_render_key", ""))),
			"prop": str(record.get("prop", "")),
			"surface": str(record.get("surface", "")),
			"icon_key": str(record.get("icon_key", "")),
			"asset_path": str(record.get("asset_path", "")),
			"available_actions": _array_view(record.get("available_actions", [])),
			"inline_actions": _array_view(record.get("inline_actions", [])),
			"attached_room_actions": _array_view(record.get("attached_room_actions", [])),
			"confirm_action_id": str(record.get("confirm_action_id", "")),
			"scenario_owner_namespace": str(record.get("scenario_owner_namespace", "")),
			"scenario_stable_object_id": str(record.get("scenario_stable_object_id", "")),
			"scenario_command_id": str(record.get("scenario_command_id", "")),
			"role": str(record.get("role", "")),
			"state": str(record.get("state", "")),
			"appearance": str(record.get("appearance", "")),
			"pose": str(record.get("pose", "")),
			"behavior": str(record.get("behavior", "")),
			"route_id": str(record.get("route_id", "")),
			"authored_position_route_id": str(record.get("authored_position_route_id", "")),
			"route_points": _array_view(record.get("route_points", [])),
			"non_color_state": str(record.get("non_color_state", "")),
			"z_order": int(record.get("z_order", 0)),
			"z_order_explicit": bool(record.get("z_order_explicit", record.has("z_order"))),
			"focus_order": maxi(0, int(record.get("focus_order", 0))),
			"layout_index": maxi(0, int(record.get("layout_index", 0))),
			"layout_spot_field": str(record.get("layout_spot_field", "")),
			"placement_class": str(record.get("placement_class", "")),
			"slot_id": slot_id,
			"slot_family": str(record.get("slot_family", record.get("manifest_family", ""))),
			"manifest_object_id": str(record.get("manifest_object_id", "")),
			"manifest_presentation_id": str(record.get("manifest_presentation_id", "")),
			"manifest_family": str(record.get("manifest_family", record.get("slot_family", ""))),
			"manifest_source_kind": str(record.get("manifest_source_kind", "")),
			"manifest_source_id": str(record.get("manifest_source_id", "")),
			"manifest_exact_slot_id": str(record.get("manifest_exact_slot_id", "")),
			"manifest_required": bool(record.get("manifest_required", false)),
			"manifest_physical": bool(record.get("manifest_physical", false)),
			"manifest_render_key": str(record.get("manifest_render_key", "")),
			"manifest_action_ids": _array_view(record.get("manifest_action_ids", [])),
			"manifest_metadata": record.get("manifest_metadata", {}) as Dictionary if typeof(record.get("manifest_metadata", {})) == TYPE_DICTIONARY else {},
			"presentation_mode": str(record.get("presentation_mode", "room")),
			"contact": str(record.get("contact", "")),
		}
		objects.append(_apply_draw_hints(scene_object, object_type, index))
	return objects


func _sync_person_transits() -> void:
	var room_key := _person_transit_snapshot_key(foundation_snapshot)
	var current_settled := _settled_person_objects(foundation_scene_objects)
	if room_key != person_transit_room_key or reduce_motion:
		person_transit_room_key = room_key
		person_transits.clear()
		person_transit_ids.clear()
		actor_route_started_at_cache.clear()
		settled_person_objects_cache = current_settled
		return
	var arrivals: Array[String] = []
	var departures: Array[String] = []
	for id_value in current_settled.keys():
		var object_id := str(id_value)
		if not settled_person_objects_cache.has(object_id) and not person_transits.has(object_id):
			arrivals.append(object_id)
	for id_value in settled_person_objects_cache.keys():
		var object_id := str(id_value)
		if not current_settled.has(object_id) and not person_transits.has(object_id):
			departures.append(object_id)
	arrivals.sort()
	departures.sort()
	for object_id in arrivals:
		if person_transit_ids.size() >= MAX_CONCURRENT_PERSON_TRANSITS:
			break
		_start_person_transit(object_id, current_settled.get(object_id, {}), "arrival")
	for object_id in departures:
		if person_transit_ids.size() >= MAX_CONCURRENT_PERSON_TRANSITS:
			break
		_start_person_transit(object_id, settled_person_objects_cache.get(object_id, {}), "departure")
	settled_person_objects_cache = current_settled
	for object_id in person_transit_ids:
		var transit_value: Variant = person_transits.get(object_id, {})
		if typeof(transit_value) != TYPE_DICTIONARY:
			continue
		var transit := transit_value as Dictionary
		if str(transit.get("kind", "")) == "arrival" and current_settled.has(object_id):
			transit["settled_object"] = (current_settled.get(object_id, {}) as Dictionary).duplicate(true)
			_apply_person_transit_to_scene_object(object_id, transit)
		elif str(transit.get("kind", "")) == "departure":
			var departing := _copy_dictionary(transit.get("settled_object", {}))
			_apply_person_transit_fields(departing, transit)
			foundation_scene_objects.append(departing)


func _person_transit_snapshot_key(snapshot: Dictionary) -> String:
	return "%s|%s|%s|%s" % [
		str(snapshot.get("id", "")),
		str(snapshot.get("world_node_id", "")),
		str(snapshot.get("environment_visit_id", snapshot.get("entered_game_clock_minutes", ""))),
		str(snapshot.get("current_layer_id", "")),
	]


func _settled_person_objects(objects: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in objects:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var object_data := value as Dictionary
		var object_id := str(object_data.get("id", "")).strip_edges()
		if object_id.is_empty() or not _scene_object_represents_person(object_data):
			continue
		var settled := object_data.duplicate(true)
		settled.erase("person_transit_active")
		settled.erase("person_transit_kind")
		settled.erase("person_transit_settled_position")
		result[object_id] = settled
	return result


static func _scene_object_represents_person(object_data: Dictionary) -> bool:
	if not EnvironmentPlacementScript.is_person_class(str(object_data.get("placement_class", ""))):
		return false
	var visual_type := str(object_data.get("type", "")).strip_edges().to_lower()
	if visual_type in ["actor", "character", "npc", "scenario_actor"]:
		return true
	if not str(object_data.get("actor_id", "")).strip_edges().is_empty():
		return true
	var actor_value: Variant = object_data.get("character_actor", {})
	return typeof(actor_value) == TYPE_DICTIONARY and not (actor_value as Dictionary).is_empty()


func _start_person_transit(object_id: String, settled_value: Variant, kind: String) -> void:
	if typeof(settled_value) != TYPE_DICTIONARY or kind not in ["arrival", "departure"]:
		return
	var settled := (settled_value as Dictionary).duplicate(true)
	var route := _person_transit_route(settled, kind)
	if route.is_empty():
		return
	var stage: Dictionary = route.get("stage", {})
	var transit := {
		"kind": kind,
		"settled_object": settled,
		"route_points": route.get("points", []),
		"route_stage": stage,
		"ends_at": actor_route_time + float(stage.get("duration_sec", PERSON_TRANSIT_MIN_DURATION_SEC)),
	}
	person_transits[object_id] = transit
	person_transit_ids.append(object_id)
	if kind == "arrival":
		_apply_person_transit_to_scene_object(object_id, transit)


func _person_transit_route(settled: Dictionary, kind: String) -> Dictionary:
	var surfaces := _developer_placement_surface_map()
	var settled_slot_id := str(settled.get("slot_id", "")).strip_edges()
	if settled_slot_id.is_empty():
		return {}
	var exit_slots := JsonCoerceScript._copy_array(surfaces.get("exit_slots", []))
	exit_slots.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left := _copy_dictionary(left_value)
		var right := _copy_dictionary(right_value)
		var left_priority := int(left.get("priority", 0))
		var right_priority := int(right.get("priority", 0))
		return str(left.get("id", "")) < str(right.get("id", "")) if left_priority == right_priority else left_priority < right_priority
	)
	if exit_slots.is_empty():
		return {}
	var exit_slot := _copy_dictionary(exit_slots[0])
	var exit_rect := _pixel_bounds_rect(exit_slot.get("hit_rect", []))
	if not exit_rect.has_area():
		return {}
	var settled_slot := _surface_slot_by_id(surfaces, settled_slot_id)
	if settled_slot.is_empty():
		return {}
	var settled_lane_ids := JsonCoerceScript._copy_array(settled_slot.get("walk_lane_ids", []))
	var lane_ids: Array = []
	for lane_id_value in JsonCoerceScript._copy_array(exit_slot.get("walk_lane_ids", [])):
		if settled_lane_ids.has(lane_id_value):
			lane_ids.append(lane_id_value)
	var pixel_points := EnvironmentSlotBinderScript.authored_route_points(surfaces, exit_slot, settled_slot, lane_ids)
	if pixel_points.size() < 2:
		return {}
	if kind == "departure":
		pixel_points.reverse()
	var points: Array = []
	var distance := 0.0
	for index in range(pixel_points.size()):
		points.append(_person_transit_normalized_point(pixel_points[index]))
		if index > 0:
			distance += (pixel_points[index - 1] as Vector2).distance_to(pixel_points[index] as Vector2)
	var endpoint: Vector2 = pixel_points.back()
	var small_rect := _rect_from_dict(settled.get("small_screen_rect", {}))
	var small_endpoint := small_rect.get_center() if small_rect.has_area() else endpoint / Vector2(BOARD_SIZE)
	if kind == "departure":
		small_endpoint = exit_rect.get_center() / Vector2(BOARD_SIZE)
	var stage := {
		"mode": "to_endpoint",
		"duration_sec": clampf(distance / PERSON_TRANSIT_SPEED_PIXELS_PER_SEC, PERSON_TRANSIT_MIN_DURATION_SEC, PERSON_TRANSIT_MAX_DURATION_SEC),
		"reduced_motion_endpoint": _person_transit_normalized_point(endpoint),
		"start": points[0],
		"endpoint": points.back(),
		"small_screen_start": points[0],
		"small_screen_endpoint": {"x": small_endpoint.x, "y": small_endpoint.y},
	}
	return {"points": points, "stage": stage}


func _surface_slot_by_id(surfaces: Dictionary, slot_id: String) -> Dictionary:
	for field in SLOT_COLLECTION_FIELDS:
		for slot_value in JsonCoerceScript._copy_array(surfaces.get(field, [])):
			var slot := _copy_dictionary(slot_value)
			if str(slot.get("id", "")) == slot_id:
				return slot
	return {}


func _apply_person_transit_to_scene_object(object_id: String, transit: Dictionary) -> void:
	for value in foundation_scene_objects:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == object_id:
			_apply_person_transit_fields(value as Dictionary, transit)
			return


func _apply_person_transit_fields(object_data: Dictionary, transit: Dictionary) -> void:
	object_data["person_transit_active"] = true
	object_data["person_transit_kind"] = str(transit.get("kind", ""))
	object_data["person_transit_settled_position"] = object_data.get("position", Vector2(0.5, 0.5))
	object_data["interactive"] = false
	object_data["disabled"] = false
	object_data["actor_route_points"] = JsonCoerceScript._copy_array(transit.get("route_points", []))
	object_data["actor_route_stage"] = _copy_dictionary(transit.get("route_stage", {}))


func _advance_person_transits() -> bool:
	var changed := false
	for index in range(person_transit_ids.size() - 1, -1, -1):
		var object_id := person_transit_ids[index]
		var transit_value: Variant = person_transits.get(object_id, {})
		if typeof(transit_value) != TYPE_DICTIONARY or actor_route_time < float((transit_value as Dictionary).get("ends_at", INF)):
			continue
		var transit := transit_value as Dictionary
		if str(transit.get("kind", "")) == "arrival":
			_restore_arrived_person(object_id, _copy_dictionary(transit.get("settled_object", {})))
		else:
			_remove_scene_object(object_id)
		person_transits.erase(object_id)
		person_transit_ids.remove_at(index)
		changed = true
	if changed:
		_sync_actor_route_starts()
		_rebuild_scene_object_cache()
	return changed


func _restore_arrived_person(object_id: String, settled: Dictionary) -> void:
	for index in range(foundation_scene_objects.size()):
		var value: Variant = foundation_scene_objects[index]
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == object_id:
			foundation_scene_objects[index] = settled
			return


func _remove_scene_object(object_id: String) -> void:
	for index in range(foundation_scene_objects.size() - 1, -1, -1):
		var value: Variant = foundation_scene_objects[index]
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == object_id:
			foundation_scene_objects.remove_at(index)
			return


static func _person_transit_normalized_point(point: Vector2) -> Dictionary:
	return {"x": point.x / BOARD_SIZE.x, "y": point.y / BOARD_SIZE.y}


static func _pixel_bounds_rect(value: Variant) -> Rect2:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() < 4:
		return Rect2()
	var bounds := value as Array
	return Rect2(float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3]))


static func _sort_composed_scene_objects(a: Dictionary, b: Dictionary) -> bool:
	var az := _composed_z_order(a)
	var bz := _composed_z_order(b)
	return str(a.get("id", "")) < str(b.get("id", "")) if az == bz else az < bz


static func _composed_z_order(value: Dictionary) -> int:
	if bool(value.get("z_order_explicit", false)):
		return int(value.get("z_order", 0))
	var position_value: Variant = value.get("position", Vector2.ZERO)
	if typeof(position_value) != TYPE_VECTOR2:
		return 0
	return int(round(float((position_value as Vector2).y) * BOARD_SIZE.y))


static func should_draw_hotspot_hint(object_data: Dictionary, low_detail: bool) -> bool:
	return bool(object_data.get("interactive", true)) and not bool(object_data.get("disabled", false)) and not low_detail


func _reserved_overlay_local_rect() -> Rect2:
	if reserved_overlay_global_rect.size.x <= 0.0 or reserved_overlay_global_rect.size.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return Rect2()
	var canvas_global_rect := get_global_rect()
	if not canvas_global_rect.intersects(reserved_overlay_global_rect):
		return Rect2()
	var intersection := canvas_global_rect.intersection(reserved_overlay_global_rect)
	var inverse_transform := get_global_transform().affine_inverse()
	var global_corners := [
		intersection.position,
		Vector2(intersection.end.x, intersection.position.y),
		Vector2(intersection.position.x, intersection.end.y),
		intersection.end,
	]
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for corner in global_corners:
		var local_corner: Vector2 = inverse_transform * (corner as Vector2)
		minimum.x = minf(minimum.x, local_corner.x)
		minimum.y = minf(minimum.y, local_corner.y)
		maximum.x = maxf(maximum.x, local_corner.x)
		maximum.y = maxf(maximum.y, local_corner.y)
	return Rect2(minimum, maximum - minimum).grow(CONVERSATION_RESERVED_FOCUS_PADDING).intersection(Rect2(Vector2.ZERO, size))


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
		var object_rect := _natural_model_rect_for_object(object_data)
		var footprint := _object_layout_footprint(object_data, object_data.get("position", Vector2(0.5, 0.5)))
		var entry := {
			"id": str(object_data.get("id", "")),
			"type": str(object_data.get("type", "")),
			"rect": _rect_to_snapshot(object_rect),
			"footprint": _rect_to_snapshot(footprint),
			"interaction_rect": _rect_to_snapshot(_interaction_rect_for_object(object_data)),
			"label_rect": _rect_to_snapshot(_resolved_label_rect_for_object(object_data, object_rect)),
			"z_order": int(object_data.get("scenario_z_order", object_data.get("source_order", index))),
			"layout_authority_identity": str(object_data.get("scenario_layout_authority_identity", "")),
			"actor_route_stage": _copy_dictionary(object_data.get("actor_route_stage", {})),
			"actor_route_position": _actor_route_position(object_data),
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
		"small_screen_mode": small_screen_mode,
		"deterministic_z_order": true,
		"label_layout": object_label_layout_stats.duplicate(true),
	}


func accessibility_clickable_rect_audit() -> Dictionary:
	var entries: Array = []
	var violations: Array = []
	for object_data in _active_scene_objects():
		if typeof(object_data) != TYPE_DICTIONARY or not bool((object_data as Dictionary).get("interactive", true)):
			continue
		var object_rect := _interaction_rect_for_object(object_data as Dictionary)
		entries.append({"id": str((object_data as Dictionary).get("id", "")), "kind": "object", "rect": _rect_to_snapshot(object_rect)})
		if small_screen_mode and (object_rect.size.x < SmallScreenPolicyScript.ENVIRONMENT_OBJECT_HIT_SIZE.x or object_rect.size.y < SmallScreenPolicyScript.ENVIRONMENT_OBJECT_HIT_SIZE.y):
			violations.append("object:%s" % str((object_data as Dictionary).get("id", "")))
	var info := _selected_object_info()
	if not info.is_empty():
		for entry_value in _selected_info_action_entries_from_info(info):
			if typeof(entry_value) != TYPE_DICTIONARY:
				continue
			var entry := entry_value as Dictionary
			if not bool(entry.get("enabled", true)):
				continue
			var action_rect: Rect2 = entry.get("button_rect", Rect2())
			entries.append({"id": str(entry.get("emit_object_id", entry.get("label", ""))), "kind": "action", "rect": _rect_to_snapshot(action_rect)})
			if small_screen_mode and action_rect.size.y < SmallScreenPolicyScript.CONTROL_TOUCH_TARGET_HEIGHT:
				violations.append("action:%s" % str(entry.get("emit_object_id", entry.get("label", ""))))
	return {
		"small_screen_mode": small_screen_mode,
		"minimum_action_height": SmallScreenPolicyScript.CONTROL_TOUCH_TARGET_HEIGHT if small_screen_mode else 0.0,
		"entries": entries,
		"violations": violations,
		"valid": violations.is_empty(),
	}


func _apply_draw_hints(object_data: Dictionary, object_type: String, index: int) -> Dictionary:
	match object_type:
		"game":
			object_data["prop"] = _production_game_prop(object_data)
		"travel":
			object_data["prop"] = "door" if index == 0 else "arrow"
		"event":
			if str(object_data.get("prop", "")).strip_edges().is_empty():
				object_data["prop"] = _fallback_event_prop(str(object_data.get("visual_key", "")), str(object_data.get("icon_key", "")), str(object_data.get("state", "")))
		"scenario_object":
			if str(object_data.get("prop", "")).strip_edges().is_empty():
				var scenario_prop := _fallback_event_prop(str(object_data.get("visual_key", "")), str(object_data.get("icon_key", "")), str(object_data.get("state", "")))
				# A scenario-authored object with no more specific icon still needs a
				# physical fixture silhouette. Ordinary events retain their 0.5-era
				# conversational fallback below.
				var icon_hint := str(object_data.get("icon_key", "")).strip_edges().to_lower()
				var authored_patron := icon_hint == "patron_talk" or icon_hint.begins_with("scenario_scene ")
				object_data["prop"] = "room_fixture" if scenario_prop == "patron_talk" and not authored_patron else scenario_prop
			var public_state := str(object_data.get("state", ""))
			var state_variant := _public_prop_state_variant(public_state)
			object_data["prop_state_variant"] = state_variant
			object_data["prop_state_pattern"] = state_variant.trim_prefix("public_")
			object_data["prop_state_label"] = _public_prop_state_label(public_state)
			var first_code := str(object_data["prop_state_pattern"]).unicode_at(0) if not str(object_data["prop_state_pattern"]).is_empty() else 48
			var first_nibble := first_code - 48 if first_code <= 57 else first_code - 87
			object_data["prop_state_color_index"] = first_nibble % 4
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
		"home_sleep":
			object_data["surface"] = "floor"
			object_data["prop"] = "bed"
		"home_storage":
			object_data["surface"] = "floor"
		"home_container":
			object_data["surface"] = "floor"
		"meta_bag":
			object_data["surface"] = "floor"
			if str(object_data.get("prop", "")).strip_edges().is_empty():
				object_data["prop"] = "paper_bag"
		"meta_upgrade":
			object_data["surface"] = "wall"
			if str(object_data.get("prop", "")).strip_edges().is_empty():
				object_data["prop"] = "sign"
		"meta_trade_up":
			object_data["surface"] = "counter"
			if str(object_data.get("prop", "")).strip_edges().is_empty():
				object_data["prop"] = "workbench"
		"meta_pawn_counter":
			object_data["surface"] = "counter_case"
		"save", "load":
			object_data["surface"] = "counter"
		_:
			if not object_data.has("surface"):
				object_data["surface"] = "counter"
	var placement_class := str(object_data.get("placement_class", ""))
	if placement_class.is_empty():
		placement_class = EnvironmentPlacementScript.classify(object_data, object_type, str(object_data.get("id", "")), str(object_data.get("prop", object_data.get("icon_key", ""))))
	object_data["placement_class"] = placement_class
	object_data["shadow_kind"] = EnvironmentPlacementScript.shadow_kind(placement_class)
	return object_data


func _production_game_prop(object_data: Dictionary) -> String:
	var source_id := str(object_data.get("source_id", object_data.get("icon_key", ""))).strip_edges().to_lower()
	var family := str(object_data.get("visual_key", "")).strip_edges().to_lower()
	var authored := str(object_data.get("prop", "")).strip_edges().to_lower()
	# Coin Pusher was authored with the historical slot_machine alias, which the
	# room renderer did not implement and therefore drew as a card table.
	if source_id == "coin_pusher" or family == "coin_pusher":
		return "coin_pusher_room"
	if source_id == "scratch_tickets":
		return "scratch_ticket_room"
	if source_id == "craps":
		return "craps_room"
	if source_id == "bar_dice":
		return "bar_dice_room"
	if source_id == "video_poker" or authored == "video_poker_machine":
		return "video_poker_machine"
	if source_id == "roulette" or family == "wheel" or authored == "roulette_table":
		return "roulette_table"
	if source_id in ["slot", "pull_tabs"] or family in ["slots", "novelty"]:
		return "machine"
	if not authored.is_empty():
		return authored
	if family == "dice":
		return "dice_table"
	return "card_table"


func _normalized_rect_from_record(record: Dictionary) -> Rect2:
	var layout_resolved := bool(record.get("scenario_layout_resolved", false)) or bool(record.get("fixed_slot_geometry", false))
	var rect := _rect_from_dict(record.get("normalized_rect", record.get("focus_rect", {})))
	if layout_resolved:
		# Finalized scenario records are already board-bounded and digested by the
		# layout resolver. Legacy visual minima and position clamps must not alter
		# the exact rectangle after validation.
		return rect
	var object_type := str(record.get("visual_type", record.get("object_type", "info")))
	var minimum_visual_size := _minimum_object_visual_size(object_type)
	var minimum_normalized_size := Vector2(
		minimum_visual_size.x / float(BOARD_SIZE.x),
		minimum_visual_size.y / float(BOARD_SIZE.y)
	)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		var focus_point := _vector2_from_dict(record.get("focus_point", {}), Vector2(0.5, 0.5))
		rect = Rect2(focus_point - Vector2(0.08, 0.14) * 0.5, Vector2(0.08, 0.14))
	return Rect2(
		Vector2(clampf(rect.position.x, 0.02, 0.96), clampf(rect.position.y, 0.04, 0.92)),
		Vector2(
			clampf(rect.size.x, minimum_normalized_size.x, 0.22),
			clampf(rect.size.y, minimum_normalized_size.y, 0.28)
		)
	)


func _minimum_object_visual_size(object_type: String) -> Vector2:
	if object_type == "meta_sal_shelf":
		return SAL_SHELF_VISUAL_MIN_SIZE
	return DEFAULT_OBJECT_VISUAL_MIN_SIZE


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


func _warm_object_info_layout_cache(object_data: Dictionary) -> void:
	var title := str(object_data.get("label", "")).strip_edges()
	var lines := _object_info_lines(object_data)
	if title.is_empty() and lines.is_empty():
		return
	var object_rect := _natural_model_rect_for_object(object_data)
	if object_rect.size.x <= 0.0 or object_rect.size.y <= 0.0:
		return
	_object_info_rect(object_rect, title, lines, str(object_data.get("type", "item")), object_data)


func _pit_boss_watch_snapshot() -> Dictionary:
	if not uses_foundation_snapshot:
		return {}
	var value: Variant = foundation_snapshot.get("pit_boss_watch", {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value as Dictionary


func _grand_casino_living_floor_snapshot() -> Dictionary:
	if not uses_foundation_snapshot:
		return {}
	var value: Variant = foundation_snapshot.get("grand_casino_living_floor", {})
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _grand_casino_staffing_snapshot() -> Dictionary:
	if not uses_foundation_snapshot:
		return {}
	var value: Variant = foundation_snapshot.get("grand_casino_staffing", {})
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
func _selected_object_info_snapshot() -> Dictionary:
	var info := _selected_object_info()
	if info.is_empty():
		return {"visible": false}
	var object_data: Dictionary = info.get("object", {})
	var expanded := bool(info.get("expanded", false))
	var action_entries := _selected_info_action_entries_from_info(info)
	var action_button_rect := _selected_info_action_button_rect_from_entries(action_entries)
	var visual_rect := _animated_info_card_rect(info)
	return {
		"visible": true,
		"object_id": str(info.get("object_id", "")),
		"title": str(info.get("title", "")),
		"lines": JsonCoerceScript._copy_array(info.get("lines", [])),
		"expanded": expanded,
		"interaction_available": _object_info_is_actionable(object_data),
		"interaction_status": _object_info_interaction_status(object_data),
		"interaction_icon": "action" if _object_info_is_actionable(object_data) else "view_only",
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
		"attribute_badges": JsonCoerceScript._copy_array(object_data.get("attribute_badges", [])) if expanded else [],
		"badge_hit_entries": _selected_info_badge_snapshot_list(_selected_info_badge_entries_for_rect(object_data, visual_rect, visual_rect.position.y + OBJECT_INFO_BODY_Y)) if expanded else [],
		"body_text_start_y": _selected_info_body_text_start_y(object_data, visual_rect, expanded),
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
	var expanded := not selected_object_id.is_empty() and object_id == selected_object_id
	var lines := _object_info_lines(object_data) if expanded else _hover_object_info_lines(object_data)
	if title.is_empty() and lines.is_empty():
		return {}
	var object_rect := _natural_model_rect_for_object(object_data)
	return {
		"object": object_data,
		"object_id": object_id,
		"title": title,
		"lines": lines,
		"expanded": expanded,
		"rect": _object_info_rect(object_rect, title, lines, str(object_data.get("type", "item")), object_data, expanded),
		"object_rect": object_rect,
	}


func _hover_object_info_lines(object_data: Dictionary) -> Array:
	var full_lines := _object_info_lines(object_data)
	var lines: Array = []
	if not full_lines.is_empty():
		lines.append(full_lines[0])
	else:
		var fallback := _fallback_object_description(object_data).strip_edges()
		if not fallback.is_empty():
			lines.append(fallback)
	lines.append("Interactive — click for details." if _object_info_is_actionable(object_data) else "View only — click for details.")
	return lines


func _object_info_is_actionable(object_data: Dictionary) -> bool:
	return not object_data.is_empty() \
		and bool(object_data.get("interactive", true)) \
		and not bool(object_data.get("disabled", false))


func _object_info_interaction_status(object_data: Dictionary) -> String:
	return "Interactive" if _object_info_is_actionable(object_data) else "View only"


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
	var cost := str(object_data.get("cost_summary", "")).strip_edges()
	if not cost.is_empty():
		_append_wrapped_info_lines(lines, cost, max_chars, 1)
	var addition_count := maxi(0, int(object_data.get("addition_count", 0)))
	if addition_count > 0:
		_append_wrapped_info_lines(lines, "+%d addition%s" % [addition_count, "" if addition_count == 1 else "s"], max_chars, 1)
	var classification := str(object_data.get("classification_summary", "")).strip_edges()
	if not classification.is_empty():
		_append_wrapped_info_lines(lines, "Discovery: %s" % classification.capitalize(), max_chars, 1)
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
		"character":
			return "Someone waiting to talk."
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
		"character":
			return "Character"
		"home_tenure":
			return "Home"
		"home_sleep":
			return "Rest"
		"home_storage":
			return "Storage"
		"home_container":
			return "Container"
		"meta_bag":
			return "Bag"
		"meta_upgrade":
			return "Upgrade"
		"meta_trade_up":
			return "Trade-Up"
		"meta_pawn_counter":
			return "Pawn"
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
		var ellipsis := "…"
		var ellipsis_width := _draw_text_width(ellipsis, font, font_size)
		var available := compact.length()
		while available > 0:
			var candidate := compact.left(available).strip_edges().trim_suffix(".")
			if _draw_text_width(candidate, font, font_size) + ellipsis_width <= max_width:
				fitted = candidate + ellipsis
				break
			available -= 1
		if fitted.is_empty() and ellipsis_width <= max_width:
			fitted = ellipsis
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
	var authored_actions := _array_view(object_data.get("available_actions", []))
	var visible_actions := _selected_info_available_actions(object_data)
	# If action records exist, their presentation visibility is authoritative.
	# An object-level confirm id must not resurrect an explicitly hidden action.
	if not authored_actions.is_empty() and visible_actions.is_empty():
		return false
	if not str(object_data.get("confirm_action_id", "")).strip_edges().is_empty():
		return true
	return not visible_actions.is_empty()


func _selected_info_action_is_visible(action_data: Dictionary) -> bool:
	return bool(action_data.get("visible", true)) \
		and bool(action_data.get("presentation_visible", true)) \
		and not bool(action_data.get("hidden", false)) \
		and not bool(action_data.get("hidden_only", false))


func _selected_info_available_actions(object_data: Dictionary) -> Array:
	var result: Array = []
	for action_value in _array_view(object_data.get("available_actions", [])):
		if typeof(action_value) != TYPE_DICTIONARY:
			continue
		var action_data: Dictionary = action_value
		if _selected_info_action_is_visible(action_data):
			result.append(action_data)
	return result


func _selected_info_inline_actions(object_data: Dictionary) -> Array:
	if selected_object_id.is_empty() or object_data.is_empty():
		return []
	if str(object_data.get("id", "")) != selected_object_id:
		return []
	var actions := _array_view(object_data.get("inline_actions", []))
	var result: Array = []
	for action in actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var action_data: Dictionary = action
		if not _selected_info_action_is_visible(action_data):
			continue
		var label := str(action_data.get("label", "")).strip_edges()
		var emit_object_id := str(action_data.get("emit_object_id", action_data.get("id", ""))).strip_edges()
		if label.is_empty() or emit_object_id.is_empty():
			continue
		result.append(action_data)
		if result.size() >= OBJECT_INFO_INLINE_ACTION_MAX:
			break
	return result


func _selected_info_action_area_height(object_data: Dictionary, content_width: float = OBJECT_INFO_WIDTH - OBJECT_INFO_PADDING_X * 2.0) -> float:
	var inline_actions := _selected_info_inline_actions(object_data)
	if not inline_actions.is_empty():
		var height := 0.0
		for action_value in inline_actions:
			if typeof(action_value) != TYPE_DICTIONARY:
				continue
			if height > 0.0:
				height += OBJECT_INFO_INLINE_ACTION_GAP
			height += _selected_info_inline_action_height()
			height += _selected_info_inline_action_detail_height(action_value as Dictionary, content_width)
		return height
	if _selected_info_has_single_action_button(object_data):
		return _selected_info_action_height()
	return 0.0


func _selected_info_inline_action_detail_height(action_data: Dictionary, content_width: float) -> float:
	var detail := _selected_info_inline_action_detail(action_data)
	if detail.is_empty() or content_width <= 0.0:
		return 0.0
	var font := get_theme_default_font()
	if font == null:
		var approximate_chars_per_line := maxi(1, int(floor(content_width / 4.7)))
		return float(clampi(int(ceil(float(detail.length()) / float(approximate_chars_per_line))), 1, OBJECT_INFO_INLINE_ACTION_DETAIL_MAX_LINES)) * OBJECT_INFO_INLINE_ACTION_DETAIL_LINE_HEIGHT
	var measured := font.get_multiline_string_size(detail, HORIZONTAL_ALIGNMENT_CENTER, content_width, 8, OBJECT_INFO_INLINE_ACTION_DETAIL_MAX_LINES, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND)
	return maxf(OBJECT_INFO_INLINE_ACTION_DETAIL_HEIGHT, ceilf(measured.y))


func _selected_info_action_height() -> float:
	return SmallScreenPolicyScript.ENVIRONMENT_ACTION_HEIGHT if small_screen_mode else OBJECT_INFO_ACTION_HEIGHT


func _selected_info_inline_action_height() -> float:
	return SmallScreenPolicyScript.ENVIRONMENT_INLINE_ACTION_HEIGHT if small_screen_mode else OBJECT_INFO_INLINE_ACTION_HEIGHT


func _selected_info_action_label(object_data: Dictionary) -> String:
	if object_data.is_empty():
		return ""
	var inline_actions := _selected_info_inline_actions(object_data)
	if not inline_actions.is_empty() and typeof(inline_actions[0]) == TYPE_DICTIONARY:
		return str((inline_actions[0] as Dictionary).get("label", "")).strip_edges().capitalize()
	var action_id := str(object_data.get("confirm_action_id", "")).strip_edges()
	var actions := _selected_info_available_actions(object_data)
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
			var action_summary := str(object_data.get("action_summary", "")).strip_edges().to_lower()
			label = "Pick up" if label.to_lower().contains("pickup") or action_summary.contains("pickup") else "Buy"
		"talk_shopkeeper":
			label = "Talk"
		"confirm_travel", "select_travel":
			label = "Travel"
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
			_:
				label = "Select"
	return label.capitalize()


func _selected_info_single_action_enabled(object_data: Dictionary) -> bool:
	if object_data.is_empty() or bool(object_data.get("disabled", false)) or not bool(object_data.get("enabled", true)):
		return false
	var actions := _array_view(object_data.get("available_actions", []))
	if not actions.is_empty() and typeof(actions[0]) == TYPE_DICTIONARY:
		var action := actions[0] as Dictionary
		return bool(action.get("enabled", true)) and not bool(action.get("disabled", false))
	return not str(object_data.get("confirm_action_id", "")).strip_edges().is_empty()


func _selected_info_action_button_rect() -> Rect2:
	var info := _selected_object_info()
	if info.is_empty():
		return Rect2()
	return _selected_info_action_button_rect_from_entries(_selected_info_action_entries_for_rect(info, _animated_info_card_rect(info)))


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
		var area_height := _selected_info_action_area_height(object_data, width)
		var y := card.end.y - OBJECT_INFO_BOTTOM_PADDING - area_height
		for action in inline_actions:
			if typeof(action) != TYPE_DICTIONARY:
				continue
			var action_data: Dictionary = action
			var button_height := _selected_info_inline_action_height()
			var button_rect := Rect2(Vector2(left, y), Vector2(width, button_height))
			var detail := _selected_info_inline_action_detail(action_data)
			var detail_height := _selected_info_inline_action_detail_height(action_data, width)
			var detail_rect := Rect2(Vector2(left, button_rect.end.y), Vector2(width, detail_height))
			entries.append({
				"inline": true,
				"label": str(action_data.get("label", "")),
				"detail": detail,
				"emit_object_id": str(action_data.get("emit_object_id", action_data.get("id", ""))),
				"button_rect": button_rect,
				"detail_rect": detail_rect,
				"selected": entries.size() == selected_info_action_index,
				"input_action": str(action_data.get("input_action", "")),
				"enabled": not bool(object_data.get("disabled", false))
					and bool(object_data.get("enabled", true))
					and not bool(action_data.get("disabled", false))
					and bool(action_data.get("enabled", true)),
			})
			y += button_height + detail_height + OBJECT_INFO_INLINE_ACTION_GAP
		return entries
	if _selected_info_has_single_action_button(object_data):
		var action_height := _selected_info_action_height()
		var available_actions := _selected_info_available_actions(object_data)
		var first_action: Dictionary = {}
		if not available_actions.is_empty() and typeof(available_actions[0]) == TYPE_DICTIONARY:
			first_action = available_actions[0]
		var single_enabled := _selected_info_single_action_enabled(object_data) \
			and not bool(object_data.get("disabled", false)) \
			and bool(object_data.get("enabled", true)) \
			and not bool(first_action.get("disabled", false)) \
			and bool(first_action.get("enabled", true)) \
			and not str(object_data.get("confirm_action_id", "")).strip_edges().is_empty()
		entries.append({
			"inline": false,
			"label": _selected_info_action_label(object_data),
			"detail": "",
			"emit_object_id": "",
			"button_rect": Rect2(
				card.position + Vector2(OBJECT_INFO_PADDING_X, card.size.y - OBJECT_INFO_BOTTOM_PADDING - action_height),
				Vector2(width, action_height)
			),
			"detail_rect": Rect2(),
			"selected": false,
			"enabled": single_enabled,
		})
	return entries


func _selected_info_inline_action_detail(action_data: Dictionary) -> String:
	return str(action_data.get("text", "")).strip_edges()


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
			"enabled": bool(action_entry.get("enabled", false)),
		})
	return snapshots


func _selected_info_badge_entries_for_rect(object_data: Dictionary, card: Rect2, y: float) -> Array:
	var badges := _array_view(object_data.get("attribute_badges", []))
	if badges.is_empty() or card.size.x <= 0.0:
		return []
	return AttributeBadgeRowScript.canvas_hit_entries(
		badges,
		Vector2(card.position.x + OBJECT_INFO_PADDING_X, y - OBJECT_INFO_BADGE_RAISE),
		card.size.x - OBJECT_INFO_PADDING_X * 2.0,
		16
	)


func _selected_info_badge_snapshot_list(entries: Array) -> Array:
	var snapshots: Array = []
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		snapshots.append({
			"rect": _rect_to_snapshot(entry.get("rect", Rect2())),
			"tooltip": str(entry.get("tooltip", "")),
		})
	return snapshots


func _selected_info_body_text_start_y(object_data: Dictionary, card: Rect2, include_badges: bool = true) -> float:
	var y := card.position.y + OBJECT_INFO_BODY_Y
	if include_badges and not _array_view(object_data.get("attribute_badges", [])).is_empty():
		var entries := _selected_info_badge_entries_for_rect(object_data, card, y)
		if not entries.is_empty() and typeof(entries[0]) == TYPE_DICTIONARY:
			var first_entry: Dictionary = entries[0]
			var rect: Rect2 = first_entry.get("rect", Rect2())
			y += rect.size.y + 4.0
	return y


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


func _selected_info_badge_tooltip_at_local_position(local_position: Vector2) -> String:
	if selected_info_badge_hit_entries.is_empty():
		return ""
	var board_position := _local_to_board_position(local_position)
	for entry_value in selected_info_badge_hit_entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var rect: Rect2 = entry.get("rect", Rect2())
		if rect.has_point(board_position):
			return str(entry.get("tooltip", "")).strip_edges()
	return ""


func _activate_selected_info_action_at_local_position(local_position: Vector2) -> bool:
	var action_entry := _selected_info_action_entry_at_local_position(local_position)
	if action_entry.is_empty() or not bool(action_entry.get("enabled", false)):
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


func _activate_selected_info_action_by_index() -> bool:
	var entries := _selected_info_action_entries_from_info(_selected_object_info())
	if entries.is_empty():
		return false
	selected_info_action_index = clampi(selected_info_action_index, 0, entries.size() - 1)
	return _activate_selected_info_action_entry(entries[selected_info_action_index])


func _activate_selected_info_action_for_authored_input(event: InputEvent) -> bool:
	var entries := _selected_info_action_entries_from_info(_selected_object_info())
	for index in range(entries.size()):
		var entry := _copy_dictionary(entries[index])
		var input_action := str(entry.get("input_action", "")).strip_edges()
		if input_action.is_empty() or not InputMap.has_action(input_action):
			continue
		if event.is_action_pressed(input_action):
			selected_info_action_index = index
			return _activate_selected_info_action_entry(entry)
	return false


func _activate_selected_info_action_entry(action_entry: Dictionary) -> bool:
	if action_entry.is_empty() or not bool(action_entry.get("enabled", false)):
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


func keyboard_reachable_object_ids() -> Array:
	var ids: Array = []
	var candidates: Array = []
	for object_value in _active_scene_objects():
		var object_data := _copy_dictionary(object_value)
		if not bool(object_data.get("interactive", true)) or not bool(object_data.get("visible", true)):
			continue
		var object_id := str(object_data.get("id", "")).strip_edges()
		if not object_id.is_empty(): candidates.append(object_data)
	candidates.sort_custom(Callable(PixelSceneCanvas, "_sort_keyboard_objects"))
	for candidate_value in candidates:
		ids.append(str(_copy_dictionary(candidate_value).get("id", "")))
	return ids


static func _sort_keyboard_objects(a: Dictionary, b: Dictionary) -> bool:
	var af := maxi(0, int(a.get("focus_order", 0)))
	var bf := maxi(0, int(b.get("focus_order", 0)))
	return str(a.get("id", "")) < str(b.get("id", "")) if af == bf else af < bf


func _cycle_interactive_object(direction: int) -> bool:
	var ids := keyboard_reachable_object_ids()
	if ids.is_empty():
		return false
	var current_index := ids.find(selected_object_id)
	if current_index < 0:
		current_index = 0 if direction >= 0 else ids.size() - 1
	else:
		current_index = posmod(current_index + (-1 if direction < 0 else 1), ids.size())
	var object_id := str(ids[current_index])
	set_selected_object(object_id)
	object_focused.emit(object_id)
	return true


func _focus_hovered_info_at_local_position(local_position: Vector2) -> bool:
	if not selected_object_id.is_empty() or hovered_object_id.is_empty():
		return false
	var info := _selected_object_info()
	if info.is_empty():
		return false
	var info_rect := _animated_info_card_rect(info)
	if not info_rect.has_point(_local_to_board_position(local_position)):
		return false
	set_selected_object(hovered_object_id)
	object_focused.emit(hovered_object_id)
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


func _object_info_rect(object_rect: Rect2, title: String, lines: Array, object_type: String, object_data: Dictionary = {}, include_details: bool = true) -> Rect2:
	var visible_rect := _visible_board_rect().grow(-OBJECT_LAYOUT_MARGIN)
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		visible_rect = Rect2(Vector2(OBJECT_LAYOUT_MARGIN, OBJECT_LAYOUT_MARGIN), Vector2(BOARD_SIZE) - Vector2(OBJECT_LAYOUT_MARGIN * 2.0, OBJECT_LAYOUT_MARGIN * 2.0))
	var card_size := _object_info_size(title, lines, object_type, visible_rect, object_data, include_details)
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


func _object_info_size(title: String, lines: Array, object_type: String, visible_rect: Rect2, object_data: Dictionary = {}, include_details: bool = true) -> Vector2:
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
	if include_details:
		content_width = maxf(content_width, _object_info_action_content_width(object_data, font))
	if lines.is_empty():
		content_width = maxf(content_width, min_width)
	var badge_height := _object_info_badge_height(object_data) if include_details else 0.0
	if badge_height > 0.0:
		content_width = maxf(content_width, _object_info_badge_width(object_data))
	var width := clampf(ceilf(content_width), min_width, max_width)
	var line_count := maxi(1, lines.size())
	var height := maxf(OBJECT_INFO_MIN_HEIGHT, OBJECT_INFO_BODY_Y + badge_height + float(line_count) * OBJECT_INFO_LINE_HEIGHT + OBJECT_INFO_BOTTOM_PADDING)
	var action_area_height := _selected_info_action_area_height(object_data, width - OBJECT_INFO_PADDING_X * 2.0) if include_details else 0.0
	if action_area_height > 0.0:
		height += OBJECT_INFO_ACTION_GAP + action_area_height
	height = minf(ceilf(height), visible_rect.size.y)
	return Vector2(width, height)


func _object_info_badge_height(object_data: Dictionary) -> float:
	return 28.0 if not _array_view(object_data.get("attribute_badges", [])).is_empty() else 0.0


func _object_info_badge_width(object_data: Dictionary) -> float:
	var badge_count := _array_view(object_data.get("attribute_badges", [])).size()
	if badge_count <= 0:
		return 0.0
	return float(badge_count) * 30.0 + OBJECT_INFO_PADDING_X * 2.0


func _object_info_action_content_width(object_data: Dictionary, font: Font) -> float:
	var content_width := 0.0
	var inline_actions := _selected_info_inline_actions(object_data)
	if not inline_actions.is_empty():
		for action_value in inline_actions:
			if typeof(action_value) != TYPE_DICTIONARY:
				continue
			var action_data: Dictionary = action_value
			content_width = maxf(content_width, _draw_text_width(str(action_data.get("label", "")), font, 11) + 20.0)
			var detail := _selected_info_inline_action_detail(action_data)
			if not detail.is_empty():
				content_width = maxf(content_width, _draw_text_width(detail, font, 8) + OBJECT_INFO_PADDING_X * 2.0)
	elif _selected_info_has_single_action_button(object_data):
		content_width = _draw_text_width(_selected_info_action_label(object_data), font, 9) + 20.0
	return content_width


func _object_info_header_width(title: String, type_text: String, font: Font) -> float:
	return _draw_text_width(title, font, 11) \
		+ _object_info_type_width(type_text, font) \
		+ OBJECT_INFO_PADDING_X * 2.0 \
		+ OBJECT_INFO_TYPE_GAP \
		+ OBJECT_INFO_STATUS_ICON_SIZE \
		+ OBJECT_INFO_STATUS_ICON_GAP


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
	if developer_placement_mode or developer_slot_placement_mode:
		camera_focus_active = false
		camera_focus_point = Vector2(0.5, 0.5)
		target_camera_zoom = 1.0
		target_camera_offset = Vector2.ZERO
		return
	var object_data := _scene_object(selected_object_id) if not selected_object_id.is_empty() else {}
	if object_data.is_empty():
		camera_focus_active = false
		camera_focus_point = Vector2(0.5, 0.5)
		target_camera_zoom = 1.0
		target_camera_offset = Vector2.ZERO
		return
	var object_rect := _natural_model_rect_for_object(object_data)
	var board_size := Vector2(BOARD_SIZE)
	camera_focus_point = Vector2(
		clampf((object_rect.position.x + object_rect.size.x * 0.5) / board_size.x, 0.0, 1.0),
		clampf((object_rect.position.y + object_rect.size.y * 0.5) / board_size.y, 0.0, 1.0)
	)
	camera_focus_active = true
	target_camera_zoom = FOCUS_ZOOM
	target_camera_offset = _camera_offset_for_focus(camera_focus_point, target_camera_zoom)
	target_camera_offset = _camera_offset_with_info_clearance(object_data, object_rect, target_camera_zoom, target_camera_offset)
	target_camera_offset = _camera_offset_with_reserved_overlay_clearance(object_data, object_rect, target_camera_zoom, target_camera_offset)


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


func _camera_offset_with_reserved_overlay_clearance(object_data: Dictionary, object_rect: Rect2, zoom: float, fallback_offset: Vector2) -> Vector2:
	var reserved_local_rect := _reserved_overlay_local_rect()
	if reserved_local_rect.size.x <= 0.0 or reserved_local_rect.size.y <= 0.0:
		return fallback_offset
	var base_scale := _board_base_scale()
	var scale := base_scale * zoom
	var base_offset := _board_base_offset(base_scale)
	var fallback_composition := _focus_composition_local_rect_for_camera(object_data, object_rect, zoom, fallback_offset).grow(CONVERSATION_OVERLAY_CLEARANCE)
	if not fallback_composition.intersects(reserved_local_rect):
		return fallback_offset
	var translations: Array[Vector2] = [
		Vector2(0.0, reserved_local_rect.position.y - fallback_composition.end.y),
		Vector2(reserved_local_rect.end.x - fallback_composition.position.x, 0.0),
		Vector2(reserved_local_rect.position.x - fallback_composition.end.x, 0.0),
	]
	var scaled_board_size := Vector2(BOARD_SIZE) * scale
	var best_offset := fallback_offset
	var screen_rect := Rect2(Vector2.ZERO, size)
	var fallback_overflow := fallback_composition.size.x * fallback_composition.size.y - _rect_overlap_area(fallback_composition, screen_rect)
	var best_score := fallback_overflow * 1000000000.0 + _rect_overlap_area(fallback_composition, reserved_local_rect) * 1000000.0
	for translation in translations:
		var candidate_offset := Vector2(
			_camera_axis_offset_with_reserved_space(size.x, scaled_board_size.x, base_offset.x, fallback_offset.x + translation.x, reserved_local_rect.position.x, size.x - reserved_local_rect.end.x),
			_camera_axis_offset_with_reserved_space(size.y, scaled_board_size.y, base_offset.y, fallback_offset.y + translation.y, reserved_local_rect.position.y, size.y - reserved_local_rect.end.y)
		)
		for _refinement in range(4):
			var refinement_composition := _focus_composition_local_rect_for_camera(object_data, object_rect, zoom, candidate_offset).grow(CONVERSATION_OVERLAY_CLEARANCE)
			if not refinement_composition.intersects(reserved_local_rect):
				break
			var correction_x := 0.0
			if size.x - reserved_local_rect.end.x <= CONVERSATION_RESERVED_EDGE_THRESHOLD:
				correction_x = reserved_local_rect.position.x - refinement_composition.end.x
			elif reserved_local_rect.position.x <= CONVERSATION_RESERVED_EDGE_THRESHOLD:
				correction_x = reserved_local_rect.end.x - refinement_composition.position.x
			if is_zero_approx(correction_x):
				break
			var refined_x := _camera_axis_offset_with_reserved_space(size.x, scaled_board_size.x, base_offset.x, candidate_offset.x + correction_x, reserved_local_rect.position.x, size.x - reserved_local_rect.end.x)
			if is_equal_approx(refined_x, candidate_offset.x):
				break
			candidate_offset.x = refined_x
		var candidate_composition := _focus_composition_local_rect_for_camera(object_data, object_rect, zoom, candidate_offset).grow(CONVERSATION_OVERLAY_CLEARANCE)
		var overflow_area := candidate_composition.size.x * candidate_composition.size.y - _rect_overlap_area(candidate_composition, screen_rect)
		var overlap_area := _rect_overlap_area(candidate_composition, reserved_local_rect)
		var movement_cost := candidate_offset.distance_squared_to(fallback_offset) * 0.01
		var score := overflow_area * 1000000000.0 + overlap_area * 1000000.0 + movement_cost
		if score < best_score:
			best_score = score
			best_offset = candidate_offset
	return best_offset


func _camera_axis_offset_with_reserved_space(canvas_length: float, scaled_length: float, base_offset_axis: float, desired_axis: float, reserved_start_gap: float, reserved_end_gap: float) -> float:
	var regular_min := canvas_length - scaled_length - base_offset_axis
	var regular_max := -base_offset_axis
	var minimum := minf(regular_min, regular_max)
	var maximum := maxf(regular_min, regular_max)
	if size.x > 720.0:
		return clampf(desired_axis, minimum, maximum)
	if reserved_start_gap <= CONVERSATION_RESERVED_EDGE_THRESHOLD:
		maximum += maxf(0.0, canvas_length - reserved_end_gap)
	if reserved_end_gap <= CONVERSATION_RESERVED_EDGE_THRESHOLD:
		minimum -= maxf(0.0, canvas_length - reserved_start_gap)
	return clampf(desired_axis, minimum, maximum)


func _focus_composition_local_rect_for_camera(object_data: Dictionary, object_rect: Rect2, zoom: float, camera_offset_value: Vector2) -> Rect2:
	var base_scale := _board_base_scale()
	var scale := base_scale * zoom
	var base_offset := _board_base_offset(base_scale)
	var object_local_rect := Rect2(base_offset + camera_offset_value + object_rect.position * scale, object_rect.size * scale)
	var visible_rect := _visible_board_rect_for_camera(camera_offset_value, zoom)
	var usable_rect := _usable_info_visible_rect(visible_rect)
	var object_type := str(object_data.get("type", "item"))
	var title := str(object_data.get("label", "")).strip_edges()
	var lines := _object_info_lines(object_data)
	var card_size := _object_info_size(title, lines, object_type, usable_rect, object_data)
	var card_rect := _object_info_rect_for_visible(object_rect, card_size, usable_rect)
	var card_local_rect := Rect2(base_offset + camera_offset_value + card_rect.position * scale, card_rect.size * scale)
	return object_local_rect.merge(card_local_rect)


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
	var enabled_hover := _object_info_is_actionable(hovered_object)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled_hover else Control.CURSOR_ARROW
	_update_object_label_accessibility()
	object_hovered.emit(object_id)
	queue_redraw()


func _focus_object_at_local_position(local_position: Vector2) -> void:
	var object_ids := _object_ids_at_local_position(local_position, false)
	var object_id := ""
	if not object_ids.is_empty():
		object_id = object_ids[0]
		var selected_hit_index := object_ids.find(selected_object_id)
		if selected_hit_index >= 0 and object_ids.size() > 1:
			object_id = object_ids[(selected_hit_index + 1) % object_ids.size()]
	if object_id.is_empty():
		_set_hovered_object("")
		set_selected_object("", false)
		object_focused.emit("")
		return
	set_selected_object(object_id)
	object_focused.emit(object_id)


func _activate_object_at_local_position(local_position: Vector2) -> void:
	var object_ids := _object_ids_at_local_position(local_position)
	var object_id := selected_object_id if object_ids.has(selected_object_id) else ""
	if object_id.is_empty() and not object_ids.is_empty():
		object_id = object_ids[0]
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


# Returns the live viewport-space rectangle after the current camera pan/zoom.
# Cached canvas object data keeps this path free of environment snapshot copies.
func global_rect_for_object(object_id: String) -> Rect2:
	var object_data := _scene_object(object_id)
	if object_data.is_empty():
		return Rect2()
	return _local_rect_to_global_rect(_board_rect_to_local_rect(_interaction_rect_for_object(object_data)))


# Converts sealed scenario authority geometry without depending on the current
# presentation object cache. This lets TalkDock choose a safe corner before its
# own reserve causes the room projection to be revalidated.
func global_rect_for_normalized_board_rect(value: Variant) -> Rect2:
	var normalized := _rect_from_dict(value)
	if not normalized.has_area():
		return Rect2()
	var board_rect := Rect2(normalized.position * Vector2(BOARD_SIZE), normalized.size * Vector2(BOARD_SIZE))
	return _local_rect_to_global_rect(_board_rect_to_local_rect(board_rect))


func global_rect_for_selected_object_action(object_id: String) -> Rect2:
	if selected_object_id != object_id:
		return Rect2()
	var action_rect := _selected_info_action_button_rect()
	if not action_rect.has_area():
		return Rect2()
	return _local_rect_to_global_rect(_board_rect_to_local_rect(action_rect))


func global_rect_for_selected_composition() -> Rect2:
	if selected_object_id.is_empty():
		return Rect2()
	var object_data := _scene_object(selected_object_id)
	if object_data.is_empty():
		return Rect2()
	var composition := _board_rect_to_local_rect(_natural_model_rect_for_object(object_data))
	var info := _selected_object_info()
	if not info.is_empty():
		var info_rect: Variant = info.get("rect", Rect2())
		if typeof(info_rect) == TYPE_RECT2 and (info_rect as Rect2).has_area():
			composition = composition.merge(_board_rect_to_local_rect(info_rect as Rect2))
	return _local_rect_to_global_rect(composition)


func _local_rect_to_global_rect(local_rect: Rect2) -> Rect2:
	var canvas_transform := get_global_transform()
	var top_left := canvas_transform * local_rect.position
	var top_right := canvas_transform * Vector2(local_rect.end.x, local_rect.position.y)
	var bottom_left := canvas_transform * Vector2(local_rect.position.x, local_rect.end.y)
	var bottom_right := canvas_transform * local_rect.end
	var minimum := Vector2(
		minf(minf(top_left.x, top_right.x), minf(bottom_left.x, bottom_right.x)),
		minf(minf(top_left.y, top_right.y), minf(bottom_left.y, bottom_right.y))
	)
	var maximum := Vector2(
		maxf(maxf(top_left.x, top_right.x), maxf(bottom_left.x, bottom_right.x)),
		maxf(maxf(top_left.y, top_right.y), maxf(bottom_left.y, bottom_right.y))
	)
	return Rect2(minimum, maximum - minimum)


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
		var object_rect := _natural_model_rect_for_object(object_data)
		var label_rect := _resolved_label_rect_for_object(object_data, object_rect)
		if label_rect.size.x > 0.0 and label_rect.size.y > 0.0:
			protected_rects.append(_board_rect_to_local_rect(label_rect.grow(3.0)))
	drunk_distortion_overlay.set_ui_protected_rects(protected_rects)


# Sealed fixed/scenario rectangles are exact draw, interaction, and label
# authority. Legacy and otherwise unslotted room models retain their natural
# dimensions and are anchored to the slot's physical contact.
func _natural_model_rect_for_object(object_data: Dictionary) -> Rect2:
	var slot_rect := _board_rect_for_object(object_data)
	if bool(object_data.get("fixed_slot_geometry", false)) \
			or bool(object_data.get("scenario_layout_resolved", false)):
		return slot_rect
	var model_size := _natural_model_size_for_object(object_data)
	if small_screen_mode and bool(object_data.get("interactive", true)):
		model_size.x = maxf(model_size.x, SmallScreenPolicyScript.ENVIRONMENT_OBJECT_HIT_SIZE.x)
		model_size.y = maxf(model_size.y, SmallScreenPolicyScript.ENVIRONMENT_OBJECT_HIT_SIZE.y)
	var placement_class := str(object_data.get("placement_class", "")).strip_edges()
	if placement_class.is_empty():
		placement_class = EnvironmentPlacementScript.classify(
			object_data,
			str(object_data.get("interaction_type", object_data.get("type", ""))),
			str(object_data.get("id", "")),
			str(object_data.get("prop", object_data.get("icon_key", "")))
		)
	var center := slot_rect.get_center()
	if placement_class not in ["wall_mounted", "hanging", "doorway"]:
		center.y = slot_rect.end.y - model_size.y * 0.5
	return Rect2(center - model_size * 0.5, model_size)


func _natural_model_size_for_object(object_data: Dictionary) -> Vector2:
	var interaction_type := str(object_data.get("interaction_type", "")).strip_edges().to_lower()
	var size := _natural_model_size_for_type(interaction_type)
	if size.x > 0.0 and size.y > 0.0:
		return size
	var visual_type := str(object_data.get("type", "")).strip_edges().to_lower()
	size = _natural_model_size_for_type(visual_type)
	if size.x > 0.0 and size.y > 0.0:
		return size
	var prop := str(object_data.get("prop", object_data.get("icon_key", ""))).strip_edges().to_lower()
	match prop:
		"bed":
			return Vector2(150.0, 74.0)
		"door", "motel_door", "side_door":
			return Vector2(104.0, 64.0)
		"machine", "slot_machine", "video_poker_machine", "coin_pusher_room":
			return Vector2(110.0, 72.0)
	var placement_class := str(object_data.get("placement_class", "")).strip_edges()
	if placement_class.is_empty():
		placement_class = EnvironmentPlacementScript.classify(
			object_data,
			visual_type,
			str(object_data.get("id", "")),
			prop
		)
	match placement_class:
		"standing_person":
			return Vector2(102.0, 64.0)
		"behind_counter_person":
			return Vector2(108.0, 70.0)
		"seated_person":
			return Vector2(100.0, 64.0)
		"group":
			return Vector2(118.0, 72.0)
		"floor_fixture":
			return Vector2(110.0, 72.0)
		"ground_marker":
			return Vector2(104.0, 58.0)
		"surface_item", "shop_item":
			return Vector2(90.0, 54.0)
		"wall_mounted":
			return Vector2(96.0, 54.0)
		"hanging":
			return Vector2(104.0, 58.0)
		"doorway":
			return Vector2(104.0, 64.0)
	return DEFAULT_OBJECT_VISUAL_MIN_SIZE


# Canonical pre-slot canvas footprints. These are model dimensions, not source
# texture dimensions and not lower bounds to be reconciled with a slot.
func _natural_model_size_for_type(object_type: String) -> Vector2:
	match object_type:
		"game":
			return Vector2(110.0, 72.0)
		"event":
			return Vector2(100.0, 64.0)
		"item":
			return Vector2(90.0, 54.0)
		"shopkeeper":
			return Vector2(108.0, 70.0)
		"game_hook":
			return Vector2(104.0, 58.0)
		"travel":
			return Vector2(104.0, 64.0)
		"service":
			return Vector2(96.0, 54.0)
		"lender":
			return Vector2(102.0, 58.0)
		"numbers", "numbers_silas":
			return Vector2(106.0, 62.0)
		"environment_layer":
			return Vector2(118.0, 72.0)
		"home_tenure":
			return Vector2(116.0, 58.0)
		"home_sleep":
			return Vector2(150.0, 74.0)
		"home_storage":
			return Vector2(108.0, 58.0)
		"home_container":
			return Vector2(104.0, 58.0)
		"drink":
			return Vector2(90.0, 54.0)
		"meta_sal_shelf":
			return SAL_SHELF_VISUAL_MIN_SIZE
	return Vector2.ZERO


func _board_rect_for_object(object_data: Dictionary) -> Rect2:
	# Placement previews are presentation-only until the owner locks the edit.
	# Keeping authored objects immutable here avoids rebuilding every scene,
	# label, badge, and camera cache for each mouse-motion event.
	if developer_placement_mode and developer_placement_pending_rect.has_area() \
			and str(object_data.get("id", "")) == selected_object_id:
		return developer_placement_pending_rect
	if developer_slot_placement_mode and developer_slot_pending_rect.has_area() \
			and str(object_data.get("slot_id", "")) == developer_slot_selected_id:
		return developer_slot_pending_rect
	var route_position := _actor_route_position(object_data)
	if route_position.x >= 0.0 and route_position.y >= 0.0:
		var route_rect := _board_rect_for_object_at_position(object_data, route_position)
		if small_screen_mode:
			if bool(object_data.get("scenario_layout_resolved", false)) or bool(object_data.get("fixed_slot_geometry", false)):
				var sealed_small := _rect_from_dict(object_data.get("small_screen_rect", {}))
				var sealed_size := sealed_small.size * Vector2(BOARD_SIZE)
				return Rect2(route_rect.get_center() - sealed_size * 0.5, sealed_size)
			var route_size := Vector2(maxf(route_rect.size.x, SmallScreenPolicyScript.ENVIRONMENT_OBJECT_HIT_SIZE.x), maxf(route_rect.size.y, SmallScreenPolicyScript.ENVIRONMENT_OBJECT_HIT_SIZE.y))
			return _clamp_board_rect(Rect2(route_rect.get_center() - route_size * 0.5, route_size))
		return route_rect
	if small_screen_mode:
		var small_rect := _rect_from_dict(object_data.get("small_screen_rect", {}))
		if small_rect.has_area():
			var board_size := Vector2(BOARD_SIZE)
			return Rect2(small_rect.position * board_size, small_rect.size * board_size)
	return _board_rect_for_object_at_position(object_data, object_data.get("position", Vector2(0.5, 0.5)))


func _interaction_rect_for_object(object_data: Dictionary) -> Rect2:
	if bool(object_data.get("person_transit_active", false)):
		return Rect2()
	return _natural_model_rect_for_object(object_data)


func _actor_route_position(object_data: Dictionary) -> Vector2:
	var stage_value: Variant = object_data.get("actor_route_stage", {})
	var points_value: Variant = object_data.get("actor_route_points", [])
	if typeof(stage_value) != TYPE_DICTIONARY or typeof(points_value) != TYPE_ARRAY:
		return Vector2(-1.0, -1.0)
	var stage := stage_value as Dictionary
	var points := points_value as Array
	if stage.is_empty() or points.size() < 2:
		return Vector2(-1.0, -1.0)
	var start := _actor_route_point(points, 0, stage, object_data)
	var endpoint := _actor_route_point(points, points.size() - 1, stage, object_data)
	if start.x < 0.0 or endpoint.x < 0.0:
		return Vector2(-1.0, -1.0)
	if reduce_motion:
		if small_screen_mode:
			return endpoint
		return _vector2_from_dict(stage.get("reduced_motion_endpoint", points.back()), endpoint)
	var route_key := _actor_route_cache_key(object_data)
	var started_at := float(actor_route_started_at_cache.get(route_key, actor_route_time))
	var duration := maxf(0.001, float(stage.get("duration_sec", 1.0)))
	var progress := clampf((actor_route_time - started_at) / duration, 0.0, 1.0)
	if str(stage.get("mode", "to_endpoint")) == "ping_pong":
		progress = 1.0 - absf(fposmod((actor_route_time - started_at) / duration, 2.0) - 1.0)
	if points.size() == 2:
		return start.lerp(endpoint, progress)
	var total_distance := 0.0
	for index in range(1, points.size()):
		total_distance += _actor_route_point(points, index - 1, stage, object_data).distance_to(_actor_route_point(points, index, stage, object_data))
	if total_distance <= 0.001:
		return endpoint
	var target_distance := total_distance * progress
	var traversed := 0.0
	for index in range(1, points.size()):
		var segment_start := _actor_route_point(points, index - 1, stage, object_data)
		var segment_end := _actor_route_point(points, index, stage, object_data)
		var segment_distance := segment_start.distance_to(segment_end)
		if target_distance <= traversed + segment_distance or index == points.size() - 1:
			return segment_start.lerp(segment_end, clampf((target_distance - traversed) / maxf(0.001, segment_distance), 0.0, 1.0))
		traversed += segment_distance
	return endpoint


func _actor_route_point(points: Array, index: int, stage: Dictionary, object_data: Dictionary) -> Vector2:
	var point := _vector2_from_dict(points[index], Vector2(-1.0, -1.0))
	if not small_screen_mode:
		return point
	if index == 0:
		return _vector2_from_dict(stage.get("small_screen_start", points[index]), point)
	if index == points.size() - 1:
		return _vector2_from_dict(stage.get("small_screen_endpoint", points[index]), point)
	return point


func _actor_route_cache_key(object_data: Dictionary) -> String:
	if bool(object_data.get("person_transit_active", false)):
		return "person-transit:%s:%s" % [str(object_data.get("id", "")), str(object_data.get("person_transit_kind", ""))]
	var route_identity := str(object_data.get("id", ""))
	if bool(object_data.get("scenario_layout_resolved", false)):
		route_identity = str(object_data.get("scenario_layout_authority_identity", ""))
	return "%s:%s" % [route_identity, JSON.stringify(object_data.get("actor_route_stage", {})).sha256_text()]


func _sync_actor_route_starts() -> void:
	var room_key := _person_transit_snapshot_key(foundation_snapshot)
	var fresh_room_snapshot := room_key != actor_position_route_room_key
	if fresh_room_snapshot:
		actor_position_route_room_key = room_key
		actor_position_receipt_cache.clear()
		actor_route_started_at_cache.clear()
	var active: Dictionary = {}
	var active_receipts: Dictionary = {}
	for value in foundation_scene_objects:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var object_data := value as Dictionary
		var object_id := str(object_data.get("id", "")).strip_edges()
		var receipt_id := str(object_data.get("authored_position_route_id", "")).strip_edges()
		if not object_id.is_empty():
			active_receipts[object_id] = true
		if _copy_dictionary(object_data.get("actor_route_stage", {})).is_empty():
			if not object_id.is_empty():
				actor_position_receipt_cache[object_id] = receipt_id
			continue
		var key := _actor_route_cache_key(object_data)
		active[key] = true
		if receipt_id.is_empty():
			# Authored patrol/ambient routes retain their normal live animation.
			if not actor_route_started_at_cache.has(key):
				actor_route_started_at_cache[key] = actor_route_time
		else:
			var had_actor := actor_position_receipt_cache.has(object_id)
			var previous_receipt := str(actor_position_receipt_cache.get(object_id, ""))
			var duration := maxf(0.001, float(_copy_dictionary(object_data.get("actor_route_stage", {})).get("duration_sec", 1.0)))
			if not fresh_room_snapshot and had_actor and previous_receipt != receipt_id:
				# Only an already-rendered actor receiving a new persisted movement
				# receipt animates. Reconstruction and revisit seal directly at endpoint.
				actor_route_started_at_cache[key] = actor_route_time
			elif not actor_route_started_at_cache.has(key):
				actor_route_started_at_cache[key] = actor_route_time - duration
			actor_position_receipt_cache[object_id] = receipt_id
	for key_value in actor_route_started_at_cache.keys():
		if not active.has(str(key_value)):
			actor_route_started_at_cache.erase(key_value)
	for object_id_value in actor_position_receipt_cache.keys():
		if not active_receipts.has(str(object_id_value)):
			actor_position_receipt_cache.erase(object_id_value)


func _scene_object_z_key(object_data: Dictionary) -> int:
	if bool(object_data.get("scenario_layout_resolved", false)):
		return 10000 + int(object_data.get("scenario_z_order", 0))
	return int(object_data.get("source_order", 0))


func _scene_object_draw_layer(object_data: Dictionary) -> int:
	var slot_id := str(object_data.get("slot_id", "")).strip_edges()
	if not slot_id.is_empty():
		var slot := _developer_slot(slot_id)
		if not slot.is_empty():
			return _developer_slot_draw_layer(slot)
	return -1 if str(object_data.get("placement_class", "")) == "behind_counter_person" else 0


func _scenario_layout_evidence(objects: Array) -> Dictionary:
	var entries: Array = []
	var digests: Dictionary = {}
	for value in objects:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var object_data := value as Dictionary
		var identity := str(object_data.get("scenario_layout_authority_identity", ""))
		if identity.is_empty():
			continue
		var digest := str(object_data.get("scenario_layout_authority_digest", ""))
		if not digest.is_empty():
			digests[digest] = true
		entries.append({
			"identity": identity,
			"draw_rect": _rect_to_snapshot(_natural_model_rect_for_object(object_data)),
			"hit_rect": _rect_to_snapshot(_interaction_rect_for_object(object_data)),
			"z_order": int(object_data.get("scenario_z_order", 0)),
			"route_stage": _copy_dictionary(object_data.get("actor_route_stage", {})),
			"route_position": _actor_route_position(object_data),
		})
	return {
		"authority_count": entries.size(),
		"authority_digest_count": digests.size(),
		"objects": entries,
		"small_screen_mode": small_screen_mode,
		"reduce_motion": reduce_motion,
		"reserved_overlay_board_rect": scenario_layout_context().get("reserved_overlay_board_rect", {}),
	}


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
	var height := OBJECT_LABEL_TWO_LINE_HEIGHT if float(text.length()) * 5.8 + 12.0 > OBJECT_LABEL_MAX_WIDTH else OBJECT_LABEL_HEIGHT
	var x := rect.position.x + rect.size.x * 0.5 - width * 0.5
	var y := rect.position.y - height - OBJECT_LABEL_GAP
	if y < OBJECT_LAYOUT_MARGIN:
		y = rect.end.y + OBJECT_LABEL_GAP
	return _clamp_board_rect(Rect2(Vector2(x, y), Vector2(width, height)))


func _object_label_lines(text: String, font: Font, font_size: int, max_width: float) -> Array[String]:
	var compact := text.replace("\n", " ").replace("\t", " ").strip_edges()
	while compact.find("  ") != -1:
		compact = compact.replace("  ", " ")
	if compact.is_empty():
		return []
	if font == null or _draw_text_width(compact, font, font_size) <= max_width:
		return [compact]
	var words := compact.split(" ", false)
	var first := ""
	var split_index := 0
	for index in range(words.size()):
		var candidate := str(words[index]) if first.is_empty() else "%s %s" % [first, str(words[index])]
		if not first.is_empty() and _draw_text_width(candidate, font, font_size) > max_width:
			split_index = index
			break
		first = candidate
		split_index = index + 1
	if first.is_empty():
		return [_fit_draw_text(compact, font, font_size, max_width)]
	var remainder := " ".join(words.slice(split_index))
	if remainder.is_empty():
		return [_fit_draw_text(first, font, font_size, max_width)]
	return [_fit_draw_text(first, font, font_size, max_width), _fit_draw_text(remainder, font, font_size, max_width)]


func object_label_accessibility_snapshot(full_label: String) -> Dictionary:
	var full := full_label.strip_edges()
	var lines := _object_label_lines(full, ThemeDB.fallback_font, OBJECT_LABEL_FONT_SIZE, OBJECT_LABEL_MAX_WIDTH - OBJECT_LABEL_TEXT_PADDING_X * 2.0)
	return {
		"tooltip": full,
		"accessibility_name": full,
		"line_count": lines.size(),
		"rendered_lines": lines,
	}


func _update_object_label_accessibility() -> void:
	var focus_id := hovered_object_id if not hovered_object_id.is_empty() else selected_object_id
	var object_data := _scene_object(focus_id)
	var full_label := str(object_data.get("label", "")).strip_edges()
	tooltip_text = full_label
	accessibility_name = full_label if not full_label.is_empty() else "Environment scene"


func _resolved_label_rect_for_object(object_data: Dictionary, object_rect: Rect2) -> Rect2:
	if not object_labels_and_borders_enabled:
		return Rect2()
	if _object_has_live_placement_preview(object_data):
		return _label_rect_for_object(object_rect, str(object_data.get("label", "")))
	var object_id := str(object_data.get("id", ""))
	if object_label_rect_cache.has(object_id):
		return object_label_rect_cache[object_id] as Rect2
	return _label_rect_for_object(object_rect, str(object_data.get("label", "")))


func _object_has_live_placement_preview(object_data: Dictionary) -> bool:
	if developer_placement_mode and developer_placement_pending_rect.has_area() \
			and str(object_data.get("id", "")) == selected_object_id:
		return true
	return developer_slot_placement_mode and developer_slot_pending_rect.has_area() \
			and str(object_data.get("slot_id", "")) == developer_slot_selected_id


func _rebuild_object_label_rect_cache(objects: Array) -> void:
	object_label_layout_rebuild_count += 1
	object_label_rect_cache = {}
	if not object_labels_and_borders_enabled:
		object_label_layout_stats = {
			"enabled": false,
			"label_count": 0,
			"moved_count": 0,
			"default_label_overlap_count": 0,
			"resolved_label_overlap_count": 0,
			"default_object_overlap_count": 0,
			"resolved_object_overlap_count": 0,
			"detached_label_count": 0,
			"max_owner_gap": 0.0,
			"owner_tether_limit": OBJECT_LABEL_MAX_TETHER_GAP,
			"overlap_policy": "bounded_tether",
		}
		return
	var live_objects: Array[Dictionary] = []
	var object_rects: Array[Rect2] = []
	var default_label_rects: Array[Rect2] = []
	var resolved_label_rects: Array[Rect2] = []
	var moved_count := 0
	var detached_label_count := 0
	var max_owner_gap := 0.0
	for value in objects:
		var object_data: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
		live_objects.append(object_data)
		object_rects.append(_natural_model_rect_for_object(object_data))
	for index in range(live_objects.size()):
		var object_data := live_objects[index]
		var object_rect := object_rects[index]
		var default_rect := _label_rect_for_object(object_rect, str(object_data.get("label", "")))
		default_label_rects.append(default_rect)
		var occupied := resolved_label_rects.duplicate()
		for other_index in range(object_rects.size()):
			if other_index != index:
				occupied.append(object_rects[other_index])
		var resolved := _resolve_object_label_overlap(default_rect, object_rect, occupied)
		var object_id := str(object_data.get("id", ""))
		if not object_id.is_empty() and resolved.has_area():
			object_label_rect_cache[object_id] = resolved
		if resolved.position != default_rect.position:
			moved_count += 1
		var owner_gap := _rect_edge_gap(object_rect, resolved)
		max_owner_gap = maxf(max_owner_gap, owner_gap)
		if owner_gap > OBJECT_LABEL_MAX_TETHER_GAP + 0.01:
			detached_label_count += 1
		resolved_label_rects.append(resolved)
	object_label_layout_stats = {
		"enabled": true,
		"label_count": object_label_rect_cache.size(),
		"moved_count": moved_count,
		"default_label_overlap_count": _rect_pair_overlap_count(default_label_rects),
		"resolved_label_overlap_count": _rect_pair_overlap_count(resolved_label_rects),
		"default_object_overlap_count": _label_object_overlap_count(default_label_rects, object_rects),
		"resolved_object_overlap_count": _label_object_overlap_count(resolved_label_rects, object_rects),
		"detached_label_count": detached_label_count,
		"max_owner_gap": max_owner_gap,
		"owner_tether_limit": OBJECT_LABEL_MAX_TETHER_GAP,
		"overlap_policy": "bounded_tether",
	}


func _resolve_object_label_overlap(label_rect: Rect2, object_rect: Rect2, occupied: Array[Rect2]) -> Rect2:
	if not label_rect.has_area() or not _rect_overlaps_any(label_rect, occupied):
		return label_rect
	var board_height := float(BOARD_SIZE.y)
	var step := OBJECT_LABEL_LINE_HEIGHT + 2.0
	var above := label_rect.get_center().y < object_rect.get_center().y
	var directions := [-1.0, 1.0] if above else [1.0, -1.0]
	var best := label_rect
	var best_overlap := _label_overlap_area(label_rect, occupied)
	# Labels are identifiers, not free-floating annotations. Search only a small
	# tether around the owning object; in a very crowded room, a little overlap
	# is preferable to a perfectly clear label that appears to name something else.
	for offset_index in range(OBJECT_LABEL_MAX_OFFSET_STEPS + 1):
		for direction_value in directions:
			var direction := float(direction_value)
			var side_start_y := object_rect.position.y - label_rect.size.y - OBJECT_LABEL_GAP if direction < 0.0 else object_rect.end.y + OBJECT_LABEL_GAP
			var y := side_start_y + direction * step * float(offset_index)
			if y < OBJECT_LAYOUT_MARGIN or y + label_rect.size.y > board_height - OBJECT_LAYOUT_MARGIN:
				continue
			var candidate := Rect2(Vector2(label_rect.position.x, y), label_rect.size)
			var overlap := _label_overlap_area(candidate, occupied)
			if overlap <= 0.01:
				return candidate
			if overlap + 0.01 < best_overlap:
				best = candidate
				best_overlap = overlap
	return best


func _rect_overlaps_any(rect: Rect2, others: Array[Rect2]) -> bool:
	return _label_overlap_area(rect, others) > 0.01


func _rect_edge_gap(a: Rect2, b: Rect2) -> float:
	if not a.has_area() or not b.has_area():
		return 0.0
	var horizontal_gap := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var vertical_gap := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(horizontal_gap, vertical_gap).length()


func _label_overlap_area(rect: Rect2, others: Array[Rect2]) -> float:
	var total := 0.0
	for other in others:
		total += _rect_overlap_area(rect, other)
	return total


func _rect_pair_overlap_count(rects: Array[Rect2]) -> int:
	var count := 0
	for first_index in range(rects.size()):
		if not rects[first_index].has_area():
			continue
		for second_index in range(first_index + 1, rects.size()):
			if _rect_overlap_area(rects[first_index], rects[second_index]) > 0.01:
				count += 1
	return count


func _label_object_overlap_count(labels: Array[Rect2], object_rects: Array[Rect2]) -> int:
	var count := 0
	for label_index in range(labels.size()):
		if not labels[label_index].has_area():
			continue
		for object_index in range(object_rects.size()):
			if label_index != object_index and _rect_overlap_area(labels[label_index], object_rects[object_index]) > 0.01:
				count += 1
	return count


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


func _draw_object_shadow(rect: Rect2, selected: bool, shadow_kind: String) -> void:
	if shadow_kind == "none":
		return
	var glow := C_YELLOW if selected else C_CYAN
	var shadow_y := rect.end.y - (3.0 if shadow_kind in ["feet", "contact"] else 7.0)
	var shadow_height := 3.0 if shadow_kind == "contact" else 6.0
	draw_rect(Rect2(Vector2(rect.position.x + rect.size.x * 0.15, shadow_y), Vector2(rect.size.x * 0.7, shadow_height)), Color(0.0, 0.0, 0.0, 0.42))
	draw_rect(Rect2(Vector2(rect.position.x + rect.size.x * 0.22, shadow_y + shadow_height), Vector2(rect.size.x * 0.56, 2)), Color(glow.r, glow.g, glow.b, 0.18))
	if selected:
		draw_rect(Rect2(Vector2(rect.position.x + rect.size.x * 0.08, shadow_y - 4.0), Vector2(rect.size.x * 0.84, 4)), Color(glow.r, glow.g, glow.b, 0.32))


func _draw_room_foreground_occluders(behind_counter_objects: Array) -> void:
	if behind_counter_objects.is_empty():
		return
	_ensure_room_surface_draw_cache()
	if room_surface_slots_by_id_cache.is_empty() and room_surface_counters_by_id_cache.is_empty():
		return
	var support_ids: Dictionary = {}
	for object_value in behind_counter_objects:
		var object_data := object_value as Dictionary
		var slot := room_surface_slots_by_id_cache.get(str(object_data.get("slot_id", "")), {}) as Dictionary
		var support_id := str(slot.get("support_id", ""))
		if room_surface_counters_by_id_cache.has(support_id):
			support_ids[support_id] = true
	var ordered_supports := support_ids.keys()
	ordered_supports.sort()
	for support_id_value in ordered_supports:
		var support_id := str(support_id_value)
		var counter := room_surface_counters_by_id_cache.get(support_id, {}) as Dictionary
		_draw_counter_foreground_art(counter)


func _draw_authored_counter_foregrounds() -> void:
	_ensure_room_surface_draw_cache()
	for counter_value in room_foreground_counters_cache:
		_draw_counter_foreground_art(counter_value as Dictionary)


func _draw_counter_foreground_art(counter: Dictionary) -> bool:
	var art_id := str(counter.get("foreground_art_id", ""))
	var x0 := float(counter.get("x0", 0.0))
	var x1 := float(counter.get("x1", 0.0))
	var top_y := float(counter.get("top_y", 0.0))
	var front_y := float(counter.get("front_y", top_y))
	var front := Rect2(Vector2(x0, top_y), Vector2(x1 - x0, front_y - top_y))
	if not front.has_area():
		return false
	match art_id:
		"corner_store_register":
			draw_rect(front, Color("#20203c"))
			draw_line(front.position, Vector2(front.end.x, front.position.y), C_CYAN, 3.0)
			for x in range(int(front.position.x) + 20, int(front.end.x) - 12, 38):
				draw_rect(Rect2(x, front.position.y + 10, 28, maxf(4.0, front.size.y - 20.0)), C_AMBER.darkened(0.18))
		"back_alley_crate_display":
			draw_rect(front, Color("#4a2d1f"))
			draw_line(front.position, Vector2(front.end.x, front.position.y), C_AMBER.darkened(0.18), 3.0)
			for x in range(int(front.position.x) + 8, int(front.end.x), 42):
				draw_line(Vector2(x, front.position.y + 5), Vector2(x + 24, front.end.y - 5), Color("#2a1812"), 3.0)
		"motel_merchandise_counter", "motel_lobby_table":
			draw_rect(front, Color("#18161f"))
			draw_line(front.position, Vector2(front.end.x, front.position.y), C_PINK.darkened(0.30), 3.0)
			draw_line(front.position + Vector2(8, front.size.y - 7), front.end - Vector2(8, 7), Color("#0e0c14"), 3.0)
		"bar_main_counter":
			draw_rect(front, Color("#3a1c16"))
			draw_line(front.position, Vector2(front.end.x, front.position.y), C_AMBER.darkened(0.12), 4.0)
			for x in range(int(front.position.x) + 24, int(front.end.x), 80):
				draw_line(Vector2(x, front.position.y + 8), Vector2(x + 18, front.end.y - 8), Color("#24100d"), 3.0)
		"gas_station_staff_window":
			draw_rect(front, Color("#493116"))
			draw_line(front.position, Vector2(front.end.x, front.position.y), C_AMBER.darkened(0.22), 2.0)
		"punchline_right_table":
			draw_rect(front, Color("#123c30"))
			draw_line(front.position, Vector2(front.end.x, front.position.y), Color("#187452"), 4.0)
			draw_line(front.position + Vector2(12, front.size.y - 8), front.end - Vector2(12, 8), Color("#0b2b22"), 3.0)
		"jazz_bar":
			draw_rect(front, Color("#3b1f15"))
			draw_line(front.position, Vector2(front.end.x, front.position.y), C_AMBER, 3.0)
			for x in range(int(front.position.x) + 16, int(front.end.x), 44):
				draw_rect(Rect2(x, front.position.y + 10, 26, maxf(3.0, front.size.y - 18.0)), Color("#21100d"))
		"kitty_champagne_bar":
			draw_rect(front, Color("#3a1932"))
			draw_line(front.position, Vector2(front.end.x, front.position.y), C_PINK, 3.0)
			for x in range(int(front.position.x) + 18, int(front.end.x), 48):
				draw_circle(Vector2(x, front.position.y + front.size.y * 0.56), 4.0, C_YELLOW.darkened(0.10))
		"delta_right_table":
			draw_rect(front, Color("#362319"))
			draw_line(front.position, Vector2(front.end.x, front.position.y), C_AMBER, 4.0)
			draw_line(front.position + Vector2(10, front.size.y - 9), front.end - Vector2(10, 9), Color("#21150f"), 3.0)
		"beach_towel_stall":
			draw_rect(front, Color("#6b4327"))
			draw_line(front.position, Vector2(front.end.x, front.position.y), C_YELLOW.darkened(0.16), 3.0)
			for x in range(int(front.position.x) + 12, int(front.end.x), 34):
				draw_rect(Rect2(x, front.position.y + 8, 20, maxf(4.0, front.size.y - 16.0)), _cycle_color(x).darkened(0.25))
		"pawn_counter", "pawn_estate_shelf":
			draw_rect(front, Color("#4a2d1f"))
			draw_line(front.position, Vector2(front.end.x, front.position.y), C_AMBER.darkened(0.20), 3.0)
			draw_line(front.position + Vector2(8, front.size.y - 6), front.end - Vector2(8, 6), Color("#241717"), 2.0)
		"grand_host_station":
			draw_rect(front, Color("#171225"))
			draw_line(front.position, Vector2(front.end.x, front.position.y), C_AMBER.darkened(0.18), 3.0)
			draw_line(front.position + Vector2(8, front.size.y - 5), front.end - Vector2(8, 5), Color("#090914"), 2.0)
		"grand_table_left", "grand_table_right":
			draw_rect(front, Color("#123f30"))
			draw_line(front.position, Vector2(front.end.x, front.position.y), C_AMBER.darkened(0.10), 4.0)
			draw_line(front.position + Vector2(20, front.size.y - 8), front.end - Vector2(20, 8), Color("#08231c"), 3.0)
		"grand_cage_teller_counter":
			draw_rect(front, Color("#2b1a25"))
			draw_line(front.position, Vector2(front.end.x, front.position.y), C_CYAN.darkened(0.24), 4.0)
			for tray_x in range(int(front.position.x) + 44, int(front.end.x) - 72, 112):
				draw_rect(Rect2(tray_x, front.position.y + 20, 72, 15), Color("#11131d"))
				draw_rect(Rect2(tray_x + 8, front.position.y + 23, 56, 5), C_AMBER.darkened(0.30))
		_:
			return false
	return true


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
		"item", "drink", "service", "shopkeeper", "lender", "character":
			return C_YELLOW
		"home_tenure":
			return C_AMBER
		"home_sleep":
			return C_CYAN
		"home_storage", "home_container":
			return C_TEAL
		"meta_bag", "meta_upgrade", "meta_trade_up", "meta_pawn_counter":
			return C_YELLOW
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


func _draw_object_label(rect: Rect2, label: String, object_type: String, disabled: bool, active: bool, object_data: Dictionary = {}) -> void:
	var text := label.strip_edges()
	if text.is_empty():
		return
	var label_rect := _resolved_label_rect_for_object(object_data, rect)
	if label_rect.size.x <= 0.0 or label_rect.size.y <= 0.0:
		return
	var color := _color_for_object_type(object_type)
	var alpha := 0.94 if active else 0.72
	if disabled:
		color = C_SOFT
		alpha = 0.56
	var font := get_theme_default_font()
	var text_width := label_rect.size.x - OBJECT_LABEL_TEXT_PADDING_X * 2.0
	var lines := _object_label_lines(text, font, OBJECT_LABEL_FONT_SIZE, text_width)
	for index in range(mini(2, lines.size())):
		var text_pos := label_rect.position + Vector2(OBJECT_LABEL_TEXT_PADDING_X, OBJECT_LABEL_BASELINE_Y + float(index) * OBJECT_LABEL_LINE_HEIGHT)
		draw_string(font, text_pos + Vector2(1.0, 1.0), lines[index], HORIZONTAL_ALIGNMENT_CENTER, text_width, OBJECT_LABEL_FONT_SIZE, Color(0.0, 0.0, 0.0, 0.80 if active else 0.58))
		draw_string(font, text_pos, lines[index], HORIZONTAL_ALIGNMENT_CENTER, text_width, OBJECT_LABEL_FONT_SIZE, Color(color.r, color.g, color.b, alpha))
	var rule_y := label_rect.end.y - 1.0 if label_rect.get_center().y < rect.get_center().y else label_rect.position.y + 1.0
	draw_line(
		Vector2(label_rect.position.x + 8.0, rule_y),
		Vector2(label_rect.end.x - 8.0, rule_y),
		Color(color.r, color.g, color.b, alpha * (0.28 if active else 0.10)),
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
	var cache_key := "%s|%d|%s|%d|%s" % [
		object_id,
		hash(icon_sprite),
		accent.to_html(true),
		texture_size,
		"high_contrast" if VisualStyleScript.high_contrast_enabled else "standard",
	]
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


func _prune_object_animation_phase_cache() -> void:
	var active_keys := {}
	for object_value in _active_scene_objects():
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = object_value
		for key_field in ["id", "source_id", "icon_key"]:
			var key := str(object_data.get(key_field, "")).strip_edges()
			if not key.is_empty():
				active_keys[key] = true
	for key_value in object_animation_phase_cache.keys():
		var key := str(key_value)
		if not bool(active_keys.get(key, false)):
			object_animation_phase_cache.erase(key)
	for profile_key_value in character_idle_profile_cache.keys():
		var profile_key := str(profile_key_value)
		if not profile_key.begins_with("object:"):
			continue
		var object_key := profile_key.trim_prefix("object:").get_slice("/", 0)
		if not bool(active_keys.get(object_key, false)):
			character_idle_profile_cache.erase(profile_key_value)


func _stable_character_animation_hash(value: String, salt: int = 0) -> int:
	var hash_value := 97 + salt * 131
	for index in range(value.length()):
		hash_value = int(fposmod(float(hash_value * 37 + value.unicode_at(index) + salt), 1000003.0))
	return hash_value


func _character_idle_gestures_for_role(role: String) -> Array:
	match role.to_lower():
		"watcher", "bouncer", "pit_boss", "guard", "security":
			return ["arms_folded", "lookaround", "shoulder_roll", "chin_touch"]
		"dealer", "card_dealer", "croupier":
			return ["card_check", "adjust_cuff", "lookaround", "counter_tap"]
		"bartender", "attendant", "clerk", "cashier", "vendor":
			return ["counter_tap", "adjust_cuff", "lookaround", "chin_touch"]
		"regular", "fixer", "patron", "customer", "guest":
			return ["pocket_check", "chin_touch", "lookaround", "arms_folded", "shoulder_roll"]
		"runner", "messenger", "lookout":
			return ["lookaround", "pocket_check", "shoulder_roll", "counter_tap"]
		_:
			return ["lookaround", "adjust_cuff", "chin_touch", "pocket_check", "arms_folded", "counter_tap", "shoulder_roll"]


func _character_idle_profile(identity: String, role: String, authored: Dictionary = {}) -> Dictionary:
	var normalized_identity := identity.strip_edges()
	if normalized_identity.is_empty():
		normalized_identity = "anonymous"
	var cache_key := "%s|%s" % [normalized_identity, role.to_lower()]
	if character_idle_profile_cache.has(cache_key):
		return character_idle_profile_cache.get(cache_key, {})
	var hash_a := _stable_character_animation_hash(cache_key, 11)
	var hash_b := _stable_character_animation_hash(cache_key, 29)
	var hash_c := _stable_character_animation_hash(cache_key, 47)
	var gestures := _character_idle_gestures_for_role(role)
	var primary := str(authored.get("idle_primary", gestures[hash_a % gestures.size()]))
	var secondary := str(authored.get("idle_secondary", gestures[hash_b % gestures.size()]))
	if secondary == primary:
		secondary = str(gestures[(hash_b + 1) % gestures.size()])
	var authored_tempo := float(authored.get("tempo", 0.0))
	var authored_phase := float(authored.get("phase", -1.0))
	var profile := {
		"identity": normalized_identity,
		"signature": "%s:%d:%d:%d" % [normalized_identity, hash_a, hash_b, hash_c],
		"primary_pose": primary,
		"secondary_pose": secondary,
		"tempo": authored_tempo if authored_tempo > 0.0 else 0.72 + float(hash_a % 47) / 100.0,
		"phase": authored_phase if authored_phase >= 0.0 else float(hash_b % 628) / 100.0,
		"cycle_duration": 6.8 + float(hash_c % 420) / 100.0,
		"primary_start": 0.32 + float(hash_a % 13) / 100.0,
		"primary_duration": 0.12 + float(hash_b % 7) / 100.0,
		"secondary_start": 0.68 + float(hash_c % 10) / 100.0,
		"secondary_duration": 0.11 + float(hash_a % 8) / 100.0,
		"sway_amount": 0.35 + float(hash_b % 130) / 100.0,
		"sway_tempo": 0.38 + float(hash_c % 42) / 100.0,
		"bob_amount": 0.22 + float(hash_a % 85) / 100.0,
		"breath_tempo": 0.72 + float(hash_b % 55) / 100.0,
		"eye_range": 0.18 + float(hash_c % 68) / 100.0,
		"eye_tempo": 0.22 + float(hash_a % 49) / 100.0,
		"blink_period": 3.4 + float(hash_b % 390) / 100.0,
		"blink_offset": float(hash_c % 300) / 100.0,
		"double_blink": hash_a % 5 == 0,
	}
	if character_idle_profile_cache.size() >= CHARACTER_IDLE_PROFILE_CACHE_LIMIT:
		character_idle_profile_cache.clear()
	character_idle_profile_cache[cache_key] = profile
	return profile


func _character_idle_state(profile: Dictionary, clock: float) -> Dictionary:
	if reduce_motion:
		return {"pose": "idle", "gesture_amount": 0.0, "sway": 0.0, "bob": 0.0, "head_x": 0.0, "head_y": 0.0, "eye_offset": 0.0, "blink": false}
	var tempo := float(profile.get("tempo", 1.0))
	var phase := float(profile.get("phase", 0.0))
	var cycle_duration := maxf(4.0, float(profile.get("cycle_duration", 8.0)))
	var animation_clock := clock * tempo + phase
	var cycle_position := fposmod(animation_clock, cycle_duration) / cycle_duration
	var pose := "idle"
	var gesture_amount := 0.0
	var primary_start := float(profile.get("primary_start", 0.38))
	var primary_duration := float(profile.get("primary_duration", 0.16))
	var secondary_start := float(profile.get("secondary_start", 0.72))
	var secondary_duration := float(profile.get("secondary_duration", 0.14))
	if cycle_position >= primary_start and cycle_position < primary_start + primary_duration:
		pose = str(profile.get("primary_pose", "lookaround"))
		gesture_amount = sin(((cycle_position - primary_start) / primary_duration) * PI)
	elif cycle_position >= secondary_start and cycle_position < secondary_start + secondary_duration:
		pose = str(profile.get("secondary_pose", "adjust_cuff"))
		gesture_amount = sin(((cycle_position - secondary_start) / secondary_duration) * PI)
	var eye_offset := sin(clock * float(profile.get("eye_tempo", 0.5)) + phase * 0.7) * float(profile.get("eye_range", 0.5))
	if pose == "lookaround":
		eye_offset += lerpf(-0.8, 0.8, gesture_amount)
	var blink_position := fposmod(clock + float(profile.get("blink_offset", 0.0)), float(profile.get("blink_period", 4.5)))
	var blinking := blink_position < 0.11
	if bool(profile.get("double_blink", false)):
		blinking = blinking or (blink_position > 0.22 and blink_position < 0.31)
	var head_x := 0.0
	var head_y := sin(clock * float(profile.get("breath_tempo", 1.0)) * 0.53 + phase) * 0.24
	match pose:
		"chin_touch":
			head_x = gesture_amount * 0.8
			head_y += gesture_amount * 0.7
		"shoulder_roll":
			head_x = -gesture_amount * 0.7
		"counter_tap", "card_check":
			head_y += gesture_amount * 0.8
		"lookaround":
			head_x = signf(eye_offset) * gesture_amount * 0.8
	return {
		"pose": pose,
		"gesture_amount": gesture_amount,
		"sway": sin(clock * float(profile.get("sway_tempo", 0.55)) + phase) * float(profile.get("sway_amount", 1.0)),
		"bob": sin(clock * float(profile.get("breath_tempo", 1.0)) + phase) * float(profile.get("bob_amount", 0.6)),
		"head_x": head_x,
		"head_y": head_y,
		"eye_offset": eye_offset,
		"blink": blinking,
	}


func _character_actor_identity(object_data: Dictionary, actor: Dictionary, member: Dictionary, member_index: int) -> String:
	var object_id := str(object_data.get("id", object_data.get("source_id", object_data.get("icon_key", "character")))).strip_edges()
	var model: Dictionary = member.get("model", {}) if typeof(member.get("model", {})) == TYPE_DICTIONARY else {}
	var member_id := ""
	for candidate in [member.get("character_id", ""), member.get("id", ""), member.get("name", ""), model.get("id", ""), model.get("name", "")]:
		member_id = str(candidate).strip_edges()
		if not member_id.is_empty():
			break
	if member_id.is_empty():
		member_id = str(actor.get("character_id", actor.get("id", "member_%d" % member_index))).strip_edges()
	return "object:%s/member:%d:%s" % [object_id, member_index, member_id]


func debug_character_idle_profile(object_data: Dictionary, member_index: int = 0) -> Dictionary:
	var actor: Dictionary = object_data.get("character_actor", {}) if typeof(object_data.get("character_actor", {})) == TYPE_DICTIONARY else {}
	var members: Array = actor.get("members", []) if typeof(actor.get("members", [])) == TYPE_ARRAY else []
	var member: Dictionary = members[member_index] if member_index >= 0 and member_index < members.size() and typeof(members[member_index]) == TYPE_DICTIONARY else {}
	var identity := _character_actor_identity(object_data, actor, member, member_index)
	var role := str(member.get("role", actor.get("role", "staff")))
	return _character_idle_profile(identity, role).duplicate(true)


func debug_named_character_idle_profile(character_id: String, role: String) -> Dictionary:
	return _character_idle_profile("named:%s" % character_id, role, _character_style(character_id)).duplicate(true)


func debug_character_idle_state(profile: Dictionary, clock: float) -> Dictionary:
	return _character_idle_state(profile, clock).duplicate(true)


func _draw_character_actor(rect: Rect2, object_data: Dictionary) -> void:
	var actor: Dictionary = object_data.get("character_actor", {}) if typeof(object_data.get("character_actor", {})) == TYPE_DICTIONARY else {}
	if actor.is_empty():
		return
	var members: Array = actor.get("members", []) if typeof(actor.get("members", [])) == TYPE_ARRAY else []
	var portrait_count := clampi(int(actor.get("portrait_count", maxi(1, members.size()))), 1, 3)
	var faceless := str(actor.get("presentation", "")) == "faceless_silhouette"
	var width_requirement := 54.0 + float(portrait_count - 1) * 38.0
	var base_scale := clampf(minf(rect.size.y / 86.0, rect.size.x / width_requirement), 0.42, 0.74)
	var foot_y := rect.end.y - 2.0
	if portrait_count >= 2:
		var left_member: Dictionary = members[1] if members.size() > 1 and typeof(members[1]) == TYPE_DICTIONARY else {}
		_draw_character_actor_member(object_data, actor, left_member, 1, faceless, Vector2(rect.position.x + rect.size.x * 0.30, foot_y - 1.0), base_scale * 0.82 * _character_actor_scale(left_member))
	if portrait_count >= 3:
		var right_member: Dictionary = members[2] if members.size() > 2 and typeof(members[2]) == TYPE_DICTIONARY else {}
		_draw_character_actor_member(object_data, actor, right_member, 2, faceless, Vector2(rect.position.x + rect.size.x * 0.70, foot_y - 1.0), base_scale * 0.82 * _character_actor_scale(right_member))
	var lead_member: Dictionary = members[0] if not members.is_empty() and typeof(members[0]) == TYPE_DICTIONARY else {}
	_draw_character_actor_member(object_data, actor, lead_member, 0, faceless, Vector2(rect.position.x + rect.size.x * 0.50, foot_y), base_scale * _character_actor_scale(lead_member))
	# Talk events keep their person in the room while the authored event badge
	# identifies why that person is selectable (rumor, offer, warning, and so on).
	var event_icon := _texture_for_asset_path(str(object_data.get("asset_path", "")))
	if event_icon != null:
		var icon_size := clampf(minf(rect.size.x, rect.size.y) * 0.30, 22.0, 32.0)
		var icon_rect := Rect2(rect.end - Vector2(icon_size + 3.0, icon_size + 3.0), Vector2(icon_size, icon_size))
		_draw_live_texture_icon(event_icon, icon_rect, object_data, C_CYAN_2, object_labels_and_borders_enabled and str(object_data.get("id", "")) == selected_object_id, bool(object_data.get("disabled", false)))


func _draw_character_actor_member(object_data: Dictionary, actor: Dictionary, member: Dictionary, member_index: int, faceless: bool, foot: Vector2, scale_value: float) -> void:
	var role := str(member.get("role", actor.get("role", "staff")))
	var identity := _character_actor_identity(object_data, actor, member, member_index)
	var idle_profile := _character_idle_profile(identity, role)
	var idle_state := _character_idle_state(idle_profile, flicker)
	var animated_foot := foot + Vector2(float(idle_state.get("sway", 0.0)), float(idle_state.get("bob", 0.0)))
	TableGameVisualsScript._draw_table_character(self, _character_actor_style(member, actor, faceless, idle_state), animated_foot, scale_value, flicker)


func _character_actor_style(member: Dictionary, actor: Dictionary, faceless: bool, idle_state: Dictionary) -> Dictionary:
	var model: Dictionary = member.get("model", {}) if typeof(member.get("model", {})) == TYPE_DICTIONARY else {}
	return {
		"name": "",
		"skin": C_DARK_3 if faceless else _character_actor_color(model, "skin_color", Color("#c49371")),
		"hair": C_DARK if faceless else _character_actor_color(model, "hair_color", _character_actor_color(actor, "hair_color", C_SHADOW)),
		"jacket": C_SHADOW if faceless else _character_actor_color(model, "jacket_color", _character_actor_color(actor, "jacket_color", C_BLUE)),
		"accent": C_SOFT if faceless else _character_actor_color(model, "accent_color", C_CYAN_2),
		"role": str(member.get("role", actor.get("role", "staff"))),
		"pose": str(idle_state.get("pose", "idle")),
		"gesture_amount": float(idle_state.get("gesture_amount", 0.0)),
		"eye_offset": float(idle_state.get("eye_offset", 0.0)),
		"blink": bool(idle_state.get("blink", false)),
		"head_x": float(idle_state.get("head_x", 0.0)),
		"head_y": float(idle_state.get("head_y", 0.0)),
		"sway_amount": 0.0,
		"holding_card": false,
		"silhouette": str(model.get("silhouette", actor.get("silhouette", "coat"))),
		"faceless": faceless,
	}


func _character_actor_color(source: Dictionary, field: String, fallback: Color) -> Color:
	var text := str(source.get(field, "")).strip_edges()
	return Color(text) if not text.is_empty() and Color.html_is_valid(text) else fallback


func _character_actor_scale(member: Dictionary) -> float:
	var model: Dictionary = member.get("model", {}) if typeof(member.get("model", {})) == TYPE_DICTIONARY else {}
	var authored_scale := clampf(float(model.get("scale", 1.0)), 0.75, 1.25)
	return lerpf(0.90, 1.08, (authored_scale - 0.75) / 0.50)


func _draw_item_prop(rect: Rect2, object_data: Dictionary, selected: bool, surface: String) -> void:
	var prop := str(object_data.get("prop", "")).strip_edges()
	if prop == "sand_pile":
		_draw_sand_pile_prop(rect, selected)
		return
	if prop == "bed":
		_draw_bed_prop(rect, selected)
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


func _draw_bed_prop(rect: Rect2, selected: bool) -> void:
	var accent := C_YELLOW if selected else C_CYAN
	_draw_interactable_light(rect, accent, selected)
	var frame := Rect2(rect.position + Vector2(rect.size.x * 0.08, rect.size.y * 0.34), Vector2(rect.size.x * 0.84, rect.size.y * 0.44))
	draw_rect(frame, C_SHADOW)
	draw_rect(Rect2(frame.position + Vector2(5, 5), frame.size - Vector2(10, 10)), Color("#50315c"))
	draw_rect(Rect2(frame.position + Vector2(10, 9), Vector2(frame.size.x * 0.25, frame.size.y - 18)), Color("#d8c9b5"))
	draw_rect(Rect2(frame.position + Vector2(frame.size.x * 0.34, 9), Vector2(frame.size.x * 0.56, frame.size.y - 18)), Color("#6b3b73"))
	for stripe in range(3):
		var stripe_x := frame.position.x + frame.size.x * (0.48 + float(stripe) * 0.15)
		draw_rect(Rect2(stripe_x, frame.position.y + 11, 7, frame.size.y - 22), C_PINK_2.darkened(0.22))
	draw_line(frame.position + Vector2(0, frame.size.y), frame.position + Vector2(0, frame.size.y + 9), C_SHADOW, 4)
	draw_line(frame.position + Vector2(frame.size.x, frame.size.y), frame.position + Vector2(frame.size.x, frame.size.y + 9), C_SHADOW, 4)
	if selected:
		draw_rect(frame.grow(4), Color(accent.r, accent.g, accent.b, 0.82), false, 2)


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
	var resource := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
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
	var prop := str(object_data.get("prop", "card_table"))
	var game_key := str(object_data.get("source_id", object_data.get("icon_key", "")))
	# Generated machines keep their own cabinet identity on every platform. The
	# Grand Casino's Web simplification remains available to other game props,
	# but may never replace a live machine with placeholder art.
	if prop == "machine":
		_draw_interactable_light(rect, accent, selected)
		if game_key == "pull_tabs":
			_draw_pull_tab_machine_prop(rect, object_data, accent, selected, disabled)
		else:
			_draw_slot_cabinet_prop(rect, object_data, accent, selected, disabled)
		_draw_game_runtime_badge(rect, object_data, accent)
		return
	if _grand_casino_web_low_detail() and not selected:
		_draw_low_detail_game_prop(rect, object_data, accent, disabled)
		_draw_game_runtime_badge(rect, object_data, accent)
		return
	_draw_interactable_light(rect, accent, selected)
	if prop == "coin_pusher_room":
		CoinPusherRoomPropScript.draw(self, rect, object_data, accent, selected, disabled, flicker)
	elif prop == "scratch_ticket_room":
		ScratchTicketRoomPropScript.draw(self, rect, object_data, accent, selected, disabled, flicker)
	elif prop == "craps_room":
		CrapsRoomPropScript.draw(self, rect, object_data, accent, selected, disabled, flicker)
	elif prop == "bar_dice_room":
		BarDiceRoomPropScript.draw(self, rect, object_data, accent, selected, disabled, flicker)
	elif prop == "video_poker_machine":
		_draw_video_poker_machine_prop(rect, object_data, accent, selected, disabled)
	elif prop == "baccarat_table":
		_draw_baccarat_table_prop(rect, object_data, accent, selected, disabled)
	elif prop == "roulette_table":
		_draw_roulette_room_prop(rect, object_data, accent, selected, disabled)
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


func _draw_low_detail_game_prop(rect: Rect2, object_data: Dictionary, accent: Color, disabled: bool = false) -> void:
	var prop := str(object_data.get("prop", "card_table"))
	var base_alpha := 0.18 if disabled else 0.30
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.82), Vector2(rect.size.x * 0.76, 4)), Color(accent.r, accent.g, accent.b, base_alpha))
	if prop == "coin_pusher_room":
		CoinPusherRoomPropScript.draw_low_detail(self, rect, object_data, accent, disabled, flicker)
		return
	if prop == "scratch_ticket_room":
		ScratchTicketRoomPropScript.draw_low_detail(self, rect, object_data, accent, disabled, flicker)
		return
	if prop == "craps_room":
		CrapsRoomPropScript.draw_low_detail(self, rect, object_data, accent, disabled, flicker)
		return
	if prop == "bar_dice_room":
		BarDiceRoomPropScript.draw_low_detail(self, rect, object_data, accent, disabled, flicker)
		return
	if prop == "video_poker_machine":
		var cabinet := Rect2(rect.position + Vector2(rect.size.x * 0.24, rect.size.y * 0.18), Vector2(rect.size.x * 0.52, rect.size.y * 0.58))
		draw_rect(cabinet, Color("#090a14"))
		draw_rect(cabinet, Color(accent.r, accent.g, accent.b, 0.18), false, 1)
		var screen := Rect2(cabinet.position + Vector2(cabinet.size.x * 0.18, cabinet.size.y * 0.26), Vector2(cabinet.size.x * 0.64, cabinet.size.y * 0.26))
		draw_rect(screen, Color("#07131b"))
		draw_rect(screen, Color(accent.r, accent.g, accent.b, 0.28), false, 1)
		for i in range(3):
			var reel := Rect2(screen.position + Vector2(3.0 + float(i) * screen.size.x * 0.30, 3.0), Vector2(screen.size.x * 0.18, maxf(5.0, screen.size.y - 6.0)))
			draw_rect(reel, _cycle_color(i * 23 + int(rect.position.x)).darkened(0.10))
		var font := get_theme_default_font()
		draw_string(font, cabinet.position + Vector2(2.0, cabinet.size.y * 0.82), _fit_draw_text("POKER", font, 7, cabinet.size.x - 4.0), HORIZONTAL_ALIGNMENT_CENTER, cabinet.size.x - 4.0, 7, C_YELLOW)
	else:
		var table := Rect2(rect.position + Vector2(rect.size.x * 0.08, rect.size.y * 0.44), Vector2(rect.size.x * 0.84, rect.size.y * 0.30))
		draw_rect(table, Color("#123f30"))
		draw_rect(Rect2(table.position + Vector2(table.size.x * 0.08, table.size.y * 0.18), Vector2(table.size.x * 0.84, table.size.y * 0.48)), Color("#1a7755"))
		draw_rect(table, Color(accent.r, accent.g, accent.b, 0.20), false, 1)
		for i in range(2):
			_card_back(Rect2(table.position + Vector2(table.size.x * (0.28 + float(i) * 0.24), -8.0 + float(i) * 2.0), Vector2(16, 22)))
	if disabled:
		draw_rect(rect.grow(-3.0), Color(0.0, 0.0, 0.0, 0.38))


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


func _fallback_event_prop(visual_key: String, icon_key: String, public_state: String = "") -> String:
	var explicit_icon := icon_key.strip_edges().to_lower()
	if explicit_icon in [
		"paper_note", "room_seating", "room_barrier", "room_signal", "room_refreshment",
		"room_surface", "room_storage", "room_display", "room_vehicle", "room_hazard",
		"payphone", "security_camera", "security_exit", "side_door", "room_route",
		"trunk_offer", "jammed_machine", "clerk_counter", "clerk_talk", "patron_talk",
		"room_trace", "room_fixture", "motel_door",
	]:
		return explicit_icon
	if explicit_icon.begins_with("scenario_scene ") or explicit_icon.begins_with("scenario_actor "):
		return _fallback_scenario_semantic_prop(explicit_icon)
	# Public semantic state participates in fallback selection. Authored physical
	# icons remain authoritative, while an un-authored changed object can now use
	# its visible state to select a concrete prop. Private local_state never
	# reaches this renderer.
	var key := ("%s %s %s" % [visual_key, icon_key, public_state]).to_lower()
	if key.find("manifest") != -1 or key.find("paper") != -1 or key.find("label") != -1 or key.find("evidence") != -1:
		return "paper_note"
	if key.find("ledger") != -1 or key.find("record") != -1 or key.find("ticket") != -1 or key.find("badge") != -1 or key.find("clipboard") != -1 or key.find("entry card") != -1:
		return "paper_note"
	if key.find("crate") != -1 or key.find("carton") != -1 or key.find("stock") != -1 or key.find("goods") != -1 or key.find("case") != -1 or key.find("luggage") != -1 or key.find("trunk") != -1:
		return "trunk_offer"
	if key.find("rope") != -1 or key.find("rail") != -1 or key.find("barrier") != -1 or key.find("barricade") != -1 or key.find("fence") != -1 or key.find("picket") != -1 or key.find("windbreak") != -1 or key.find("cage") != -1:
		return "room_barrier"
	if key.find("chair") != -1 or key.find("seat") != -1 or key.find("booth") != -1 or key.find("bench") != -1:
		return "room_seating"
	if key.find("light") != -1 or key.find("lamp") != -1 or key.find("sign") != -1 or key.find("signal") != -1 or key.find("beacon") != -1:
		return "room_signal"
	if key.find("bottle") != -1 or key.find("drink") != -1 or key.find("glass") != -1 or key.find("keg") != -1 or key.find("food") != -1:
		return "room_refreshment"
	if key.find("table") != -1 or key.find("counter") != -1 or key.find("desk") != -1 or key.find("stage") != -1 or key.find("platform") != -1 or key.find("surface") != -1 or key.find("stand") != -1 or key.find("stall") != -1:
		return "room_surface"
	if key.find("machine") != -1 or key.find("workstation") != -1 or key.find("terminal") != -1 or key.find("engine") != -1 or key.find("pump") != -1 or key.find("repair") != -1 or key.find("tool") != -1 or key.find("speaker") != -1 or key.find("equipment") != -1 or key.find("panel") != -1 or key.find("job") != -1:
		return "jammed_machine"
	if key.find("bed") != -1 or key.find("furniture") != -1 or key.find("rack") != -1 or key.find("shelf") != -1 or key.find("cart") != -1 or key.find("tray") != -1 or key.find("trolley") != -1:
		return "room_storage"
	if key.find("gauge") != -1 or key.find("instrument") != -1 or key.find("board") != -1 or key.find("score") != -1 or key.find("bracket") != -1 or key.find("display") != -1:
		return "room_display"
	if key.find("vehicle") != -1 or key.find("rig") != -1 or key.find("cruiser") != -1 or key.find("bus") != -1 or key.find("dolly") != -1:
		return "room_vehicle"
	if key.find("fire") != -1 or key.find("smoke") != -1 or key.find("fog") != -1 or key.find("storm") != -1 or key.find("flood") != -1 or key.find("leak") != -1:
		return "room_hazard"
	if key.find("phone") != -1:
		return "payphone"
	if key.find("camera") != -1 or key.find("sky") != -1:
		return "security_camera"
	if key.find("security") != -1 or key.find("heat") != -1:
		return "security_exit"
	if key.find("progression") != -1 or key.find("door") != -1 or key.find("exit") != -1 or key.find("lane") != -1:
		return "side_door"
	if key.find("route") != -1 or key.find("marker") != -1 or key.find("path") != -1 or key.find("corridor") != -1 or key.find("hallway") != -1 or key.find("gangway") != -1 or key.find("ring") != -1 or key.find("zone") != -1:
		return "room_route"
	if key.find("note") != -1 or key.find("tip") != -1:
		return "paper_note"
	if key.find("offer") != -1:
		return "trunk_offer"
	if key.find("clerk") != -1 or key.find("server") != -1 or key.find("staff") != -1 or key.find("worker") != -1:
		return "clerk_talk"
	if key.find("actor") != -1 or key.find("person") != -1 or key.find("patron") != -1 or key.find("guest") != -1 or key.find("witness") != -1 or key.find("crowd") != -1 or key.find("audience") != -1:
		return "patron_talk"
	# Lifecycle words are useful only when the author supplied no physical noun.
	# Keep them last so an aftermath tray remains a tray and an interrupted row
	# of chairs remains seating in the unlabeled room.
	if key.find("trace") != -1 or key.find("aftermath") != -1 or key.find("debris") != -1 or key.find("abandoned") != -1 or key.find("interrupted") != -1:
		return "room_trace"
	return "patron_talk"


func _public_prop_state_variant(public_state: String) -> String:
	var normalized := public_state.strip_edges().to_lower()
	if normalized.is_empty():
		return ""
	# The input is the validated public scene-object DTO, never scenario
	# local_state. Persist only a presentation fingerprint in the canvas object;
	# the authored state string is not republished under a new field.
	return "public_%s" % normalized.sha256_text().left(10)


func _public_prop_state_label(public_state: String) -> String:
	var normalized := public_state.strip_edges().to_lower()
	for prefix in ["changed_by_", "acted_", "state_"]:
		if normalized.begins_with(prefix):
			normalized = normalized.trim_prefix(prefix)
			break
	var tokens := normalized.split("_", false)
	for preferred in ["opened", "open", "closed", "cleared", "released", "ready", "lit", "fixed", "repaired", "moved", "failed", "fail", "refused", "refuse", "complete", "completed"]:
		if tokens.has(preferred):
			return preferred.to_upper().substr(0, 9)
	if tokens.is_empty():
		return ""
	# Never turn arbitrary state tokens into player-facing text. The explicit
	# vocabulary above is presentation-safe; every other public state gets a
	# generic non-color acknowledgement.
	return "CHANGED"


func _draw_public_prop_state_marker(rect: Rect2, object_data: Dictionary) -> void:
	var variant := str(object_data.get("prop_state_variant", ""))
	if variant.is_empty():
		return
	var fingerprint := str(object_data.get("prop_state_pattern", ""))
	var marker_color := C_CYAN
	match int(object_data.get("prop_state_color_index", 0)):
		1: marker_color = C_YELLOW
		2: marker_color = C_PINK
		3: marker_color = C_TEAL
	# Keep the state cue inside the object's lower edge. A perimeter around the
	# complete model reads like a leftover placeholder in dense floor layouts.
	var rail := Rect2(rect.position + Vector2(5.0, rect.size.y - 7.0), Vector2(maxf(1.0, rect.size.x - 10.0), 3.0))
	draw_rect(rail, Color(0.02, 0.02, 0.05, 0.72))
	# Ten hexadecimal cells expose forty deterministic non-color bits. Actual
	# authored states remain collision-audited by the presentation gate.
	for column in range(mini(10, fingerprint.length())):
		var code := fingerprint.unicode_at(column)
		var nibble := code - 48 if code <= 57 else code - 87
		for bit in range(4):
			var bit_rect := Rect2(rail.position + Vector2(2.0 + float(column) * 4.5, float(bit) * 0.75), Vector2(3.0, 0.65))
			if (nibble & (1 << bit)) != 0:
				draw_rect(bit_rect, marker_color)
			else:
				draw_rect(bit_rect, Color(marker_color.r, marker_color.g, marker_color.b, 0.18), false, 1.0)
	draw_line(rect.position + Vector2(3.0, rect.size.y - 10.0), rect.position + Vector2(3.0, rect.size.y - 2.0), marker_color, 2.0)
	draw_line(rect.end - Vector2(3.0, 10.0), rect.end - Vector2(3.0, 2.0), marker_color, 2.0)


func _fallback_scenario_semantic_prop(value: String) -> String:
	var tokens: Dictionary = {}
	var normalized := value.to_lower()
	for separator in ["_", "-", "/", "\\", ".", ",", ":", ";", "!", "?", "'", "(", ")"]:
		normalized = normalized.replace(separator, " ")
	for token_value in normalized.split(" ", false): tokens[str(token_value)] = true
	if normalized.begins_with("scenario actor "):
		return "clerk_talk" if _tokens_have(tokens, ["clerk", "server", "worker"]) else "patron_talk"
	if _tokens_have(tokens, ["exit", "door", "doorway", "gangway"]): return "side_door"
	if _tokens_have(tokens, ["route", "lane", "corridor", "path", "aisle", "trail", "ring"]): return "room_route"
	if _tokens_have(tokens, ["manifest", "paper", "label", "evidence", "ledger", "record", "ticket", "badge", "clipboard", "note", "card", "cards", "tag", "sheet", "slip", "receipt", "pencil", "placard", "placards"]): return "paper_note"
	if _tokens_have(tokens, ["crate", "carton", "stock", "goods", "case", "luggage", "trunk", "pallet", "box", "boxes", "pouch"]): return "trunk_offer"
	if _tokens_have(tokens, ["rope", "rail", "barrier", "barricade", "fence", "picket", "windbreak", "cage", "cordon", "gate", "gates", "shutter", "shutters"]): return "room_barrier"
	if _tokens_have(tokens, ["chair", "chairs", "seat", "seats", "booth", "bench", "benches", "stool"]): return "room_seating"
	if _tokens_have(tokens, ["light", "lights", "flashlight", "lamp", "sign", "signal", "beacon", "marker"]): return "room_signal"
	if _tokens_have(tokens, ["bottle", "drink", "glass", "keg", "food", "cup", "coffee"]): return "room_refreshment"
	if _tokens_have(tokens, ["table", "tables", "counter", "desk", "lectern", "stage", "platform", "surface", "stand", "stall", "station"]): return "room_surface"
	if _tokens_have(tokens, ["machine", "workstation", "terminal", "engine", "generator", "pump", "repair", "tool", "tools", "speaker", "equipment", "panel", "microphone", "cable", "circuit", "cooler", "sink", "job", "jobs"]): return "jammed_machine"
	if _tokens_have(tokens, ["bed", "furniture", "rack", "shelf", "cart", "tray", "trolley", "stack", "dock", "coat"]): return "room_storage"
	if _tokens_have(tokens, ["gauge", "instrument", "board", "score", "scoreboard", "bracket", "display", "slate", "tally"]): return "room_display"
	if _tokens_have(tokens, ["vehicle", "rig", "cruiser", "bus", "dolly", "patrol", "car"]): return "room_vehicle"
	if _tokens_have(tokens, ["fire", "smoke", "fog", "storm", "flood", "leak", "hazard"]): return "room_hazard"
	if _tokens_have(tokens, ["phone", "payphone"]): return "payphone"
	if _tokens_have(tokens, ["camera"]): return "security_camera"
	if _tokens_have(tokens, ["security", "heat"]): return "security_exit"
	if _tokens_have(tokens, ["clerk", "server", "worker"]): return "clerk_talk"
	if _tokens_have(tokens, ["actor", "person", "patron", "guest", "witness", "crowd", "audience", "queue", "staff", "brawler", "passenger", "bartender", "judges"]): return "patron_talk"
	if _tokens_have(tokens, ["trace", "traces", "clue", "clues", "aftermath", "debris", "abandoned", "interrupted"]): return "room_trace"
	return "room_fixture"


func _tokens_have(tokens: Dictionary, candidates: Array) -> bool:
	for candidate_value in candidates:
		if tokens.has(str(candidate_value)): return true
	return false


func _draw_event_prop(rect: Rect2, object_data: Dictionary, selected: bool) -> void:
	var prop := str(object_data.get("prop", "")).strip_edges()
	if prop.is_empty():
		prop = _fallback_event_prop(str(object_data.get("visual_key", "")), str(object_data.get("icon_key", "")), str(object_data.get("state", "")))
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
		"room_barrier":
			_draw_scenario_barrier_prop(rect, accent)
		"room_seating":
			_draw_scenario_seating_prop(rect, accent)
		"room_signal":
			_draw_scenario_signal_prop(rect, accent)
		"room_refreshment":
			_draw_scenario_refreshment_prop(rect, accent)
		"room_surface":
			_draw_scenario_surface_prop(rect, accent)
		"room_fixture":
			_draw_scenario_fixture_prop(rect, accent)
		"room_trace":
			_draw_scenario_trace_prop(rect, accent)
		"room_route":
			_draw_scenario_route_prop(rect, accent)
		"room_storage":
			_draw_scenario_storage_prop(rect, accent)
		"room_display":
			_draw_scenario_display_prop(rect, accent)
		"room_vehicle":
			_draw_scenario_vehicle_prop(rect, accent)
		"room_hazard":
			_draw_scenario_hazard_prop(rect, accent)
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


func _draw_scenario_barrier_prop(rect: Rect2, accent: Color) -> void:
	var floor_y := rect.position.y + rect.size.y * 0.78
	for x_ratio in [0.22, 0.78]:
		var x: float = rect.position.x + rect.size.x * float(x_ratio)
		draw_line(Vector2(x, floor_y), Vector2(x, rect.position.y + rect.size.y * 0.30), C_SHADOW, 5)
		draw_circle(Vector2(x, rect.position.y + rect.size.y * 0.27), 4, accent)
	draw_line(rect.position + Vector2(rect.size.x * 0.22, rect.size.y * 0.44), rect.position + Vector2(rect.size.x * 0.78, rect.size.y * 0.58), accent, 4)
	draw_line(rect.position + Vector2(rect.size.x * 0.16, floor_y), rect.position + Vector2(rect.size.x * 0.84, floor_y), Color(accent.r, accent.g, accent.b, 0.28), 3)


func _draw_scenario_seating_prop(rect: Rect2, accent: Color) -> void:
	for x_ratio in [0.28, 0.62]:
		var chair: Rect2 = Rect2(rect.position + Vector2(rect.size.x * float(x_ratio), rect.size.y * 0.34), Vector2(rect.size.x * 0.22, rect.size.y * 0.30))
		draw_rect(chair, Color("#281a31"))
		draw_rect(chair, accent, false, 2)
		draw_line(chair.position + Vector2(2, chair.size.y), chair.position + Vector2(0, chair.size.y + rect.size.y * 0.20), C_SHADOW, 3)
		draw_line(chair.end - Vector2(2, 0), chair.end + Vector2(0, rect.size.y * 0.20), C_SHADOW, 3)


func _draw_scenario_signal_prop(rect: Rect2, accent: Color) -> void:
	var center := rect.get_center()
	draw_line(center + Vector2(0, rect.size.y * 0.35), center - Vector2(0, rect.size.y * 0.12), C_SHADOW, 5)
	draw_circle(center - Vector2(0, rect.size.y * 0.22), minf(rect.size.x, rect.size.y) * 0.16, accent)
	for radius in [0.25, 0.34]:
		draw_arc(center - Vector2(0, rect.size.y * 0.22), minf(rect.size.x, rect.size.y) * radius, PI * 1.12, PI * 1.88, 12, Color(accent.r, accent.g, accent.b, 0.42), 2)


func _draw_scenario_refreshment_prop(rect: Rect2, accent: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.70), Vector2(rect.size.x * 0.76, 5)), C_SHADOW)
	for index in range(3):
		var bottle := Rect2(rect.position + Vector2(rect.size.x * (0.25 + index * 0.20), rect.size.y * (0.30 + (index % 2) * 0.08)), Vector2(8, rect.size.y * 0.34))
		draw_rect(bottle, accent.darkened(float(index) * 0.10))
		draw_rect(Rect2(bottle.position + Vector2(2, -5), Vector2(4, 6)), C_YELLOW)


func _draw_scenario_surface_prop(rect: Rect2, accent: Color) -> void:
	var top := Rect2(rect.position + Vector2(rect.size.x * 0.08, rect.size.y * 0.50), Vector2(rect.size.x * 0.84, rect.size.y * 0.18))
	draw_rect(top, Color("#34213a"))
	draw_rect(top, accent, false, 2)
	draw_line(top.position + Vector2(top.size.x * 0.16, top.size.y), top.position + Vector2(top.size.x * 0.12, rect.size.y * 0.42), C_SHADOW, 4)
	draw_line(top.position + Vector2(top.size.x * 0.84, top.size.y), top.position + Vector2(top.size.x * 0.88, rect.size.y * 0.42), C_SHADOW, 4)


func _draw_scenario_fixture_prop(rect: Rect2, accent: Color) -> void:
	var fixture := Rect2(rect.position + Vector2(rect.size.x * 0.22, rect.size.y * 0.28), Vector2(rect.size.x * 0.56, rect.size.y * 0.46))
	draw_rect(fixture, Color("#19172b"))
	draw_rect(fixture, accent, false, 2)
	draw_line(fixture.position + Vector2(5, fixture.size.y * 0.34), fixture.end - Vector2(5, fixture.size.y * 0.66), Color(accent.r, accent.g, accent.b, 0.45), 2)
	draw_line(fixture.position + Vector2(5, fixture.size.y * 0.66), fixture.end - Vector2(5, fixture.size.y * 0.34), Color(accent.r, accent.g, accent.b, 0.45), 2)


func _draw_scenario_trace_prop(rect: Rect2, accent: Color) -> void:
	var baseline := rect.position.y + rect.size.y * 0.72
	draw_line(Vector2(rect.position.x + rect.size.x * 0.12, baseline), Vector2(rect.end.x - rect.size.x * 0.12, baseline), Color(accent.r, accent.g, accent.b, 0.35), 2)
	for index in range(4):
		var center := rect.position + Vector2(rect.size.x * (0.20 + float(index) * 0.19), rect.size.y * (0.38 + float(index % 2) * 0.16))
		draw_circle(center, 4.0 + float(index % 2), accent.darkened(float(index) * 0.08))
		draw_line(center + Vector2(-5, 7), center + Vector2(6, 10), C_SHADOW, 2)


func _draw_scenario_route_prop(rect: Rect2, accent: Color) -> void:
	var start := rect.position + Vector2(rect.size.x * 0.14, rect.size.y * 0.68)
	var finish := rect.position + Vector2(rect.size.x * 0.78, rect.size.y * 0.32)
	draw_dashed_line(start, finish, accent, 3.0, 7.0, true)
	_scenario_route_arrow_points[0] = finish
	_scenario_route_arrow_points[1] = finish + Vector2(-10, -1)
	_scenario_route_arrow_points[2] = finish + Vector2(-3, 9)
	draw_colored_polygon(_scenario_route_arrow_points, accent)


func _draw_scenario_storage_prop(rect: Rect2, accent: Color) -> void:
	var frame := Rect2(rect.position + Vector2(rect.size.x * 0.14, rect.size.y * 0.24), Vector2(rect.size.x * 0.72, rect.size.y * 0.54))
	draw_rect(frame, Color("#21182d"))
	draw_rect(frame, accent, false, 2)
	for y_ratio in [0.34, 0.66]:
		draw_line(Vector2(frame.position.x + 3, frame.position.y + frame.size.y * float(y_ratio)), Vector2(frame.end.x - 3, frame.position.y + frame.size.y * float(y_ratio)), accent.darkened(0.22), 2)


func _draw_scenario_display_prop(rect: Rect2, accent: Color) -> void:
	var board := Rect2(rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.18), Vector2(rect.size.x * 0.76, rect.size.y * 0.55))
	draw_rect(board, Color("#161b2d"))
	draw_rect(board, accent, false, 2)
	for index in range(3):
		var y := board.position.y + board.size.y * (0.25 + float(index) * 0.23)
		draw_line(Vector2(board.position.x + 7, y), Vector2(board.end.x - 7 - index * 5, y), accent.lightened(0.10), 2)
	draw_line(board.get_center() + Vector2(0, board.size.y * 0.50), board.get_center() + Vector2(0, board.size.y * 0.72), C_SHADOW, 4)


func _draw_scenario_vehicle_prop(rect: Rect2, accent: Color) -> void:
	var body := Rect2(rect.position + Vector2(rect.size.x * 0.10, rect.size.y * 0.40), Vector2(rect.size.x * 0.80, rect.size.y * 0.30))
	draw_rect(body, accent.darkened(0.50))
	draw_rect(body, accent, false, 2)
	_scenario_vehicle_canopy_points[0] = body.position + Vector2(body.size.x * 0.22, 0)
	_scenario_vehicle_canopy_points[1] = body.position + Vector2(body.size.x * 0.38, -rect.size.y * 0.18)
	_scenario_vehicle_canopy_points[2] = body.position + Vector2(body.size.x * 0.68, -rect.size.y * 0.18)
	_scenario_vehicle_canopy_points[3] = body.position + Vector2(body.size.x * 0.82, 0)
	draw_colored_polygon(_scenario_vehicle_canopy_points, accent.darkened(0.36))
	draw_circle(body.position + Vector2(body.size.x * 0.24, body.size.y), 5, C_SHADOW)
	draw_circle(body.position + Vector2(body.size.x * 0.76, body.size.y), 5, C_SHADOW)


func _draw_scenario_hazard_prop(rect: Rect2, accent: Color) -> void:
	var center := rect.get_center()
	_scenario_hazard_fill_points[0] = center + Vector2(0, -rect.size.y * 0.32)
	_scenario_hazard_fill_points[1] = center + Vector2(rect.size.x * 0.34, rect.size.y * 0.28)
	_scenario_hazard_fill_points[2] = center + Vector2(-rect.size.x * 0.34, rect.size.y * 0.28)
	_scenario_hazard_outline_points[0] = _scenario_hazard_fill_points[0]
	_scenario_hazard_outline_points[1] = _scenario_hazard_fill_points[1]
	_scenario_hazard_outline_points[2] = _scenario_hazard_fill_points[2]
	_scenario_hazard_outline_points[3] = _scenario_hazard_fill_points[0]
	draw_colored_polygon(_scenario_hazard_fill_points, accent.darkened(0.42))
	draw_polyline(_scenario_hazard_outline_points, accent, 2)
	_neon_text("!", center + Vector2(-4, 8), 16, C_WHITE)


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
	# This is damaged event equipment, not a playable generated slot cabinet.
	# Keep it visibly inert instead of borrowing any slot-machine renderer.
	draw_rect(machine, Color("#0b0c13"))
	draw_rect(machine, Color(accent.r, accent.g, accent.b, 0.24), false, 2)
	var service_panel := Rect2(machine.position + Vector2(machine.size.x * 0.16, machine.size.y * 0.18), Vector2(machine.size.x * 0.68, machine.size.y * 0.42))
	draw_rect(service_panel, Color("#171421"))
	draw_line(service_panel.position + Vector2(2, service_panel.size.y * 0.72), service_panel.end - Vector2(2, service_panel.size.y * 0.72), accent.darkened(0.18), 2)
	draw_line(service_panel.position + Vector2(service_panel.size.x * 0.30, 3), service_panel.position + Vector2(service_panel.size.x * 0.54, service_panel.size.y - 3), C_PINK, 2)
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
	HeatFeedbackVisualsScript.draw_police_pressure(self, Vector2(BOARD_SIZE), level, 0.0 if reduce_motion else flicker)
	if level >= 70:
		_silhouette(Vector2(846, 220), 1.4, Color("#05050b"))


func pressure_overlay_debug_profile(elapsed_sec: float = -1.0) -> Dictionary:
	var sample_time := (0.0 if reduce_motion else flicker) if elapsed_sec < 0.0 else maxf(0.0, elapsed_sec)
	return HeatFeedbackVisualsScript.police_pressure_profile(suspicion_level, sample_time)


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
	var low_detail := _grand_casino_web_low_detail()
	var step := 108 if low_detail else 54
	for x in range(24, 880, step):
		var color := _cycle_color(x)
		draw_rect(Rect2(x, reflection_y + int(sin(flicker * 2.0 + x) * 4.0), 38, 4), Color(color.r, color.g, color.b, 0.35))
		if not low_detail:
			draw_rect(Rect2(x + 8, glint_y, 68, 2), Color(color.r, color.g, color.b, 0.18))


func _silhouette(pos: Vector2, scale_value: float, color: Color) -> void:
	draw_circle(pos + Vector2(0, -42) * scale_value, 15 * scale_value, color)
	draw_rect(Rect2(pos.x - 18 * scale_value, pos.y - 30 * scale_value, 36 * scale_value, 58 * scale_value), color)
	draw_rect(Rect2(pos.x - 30 * scale_value, pos.y - 14 * scale_value, 12 * scale_value, 48 * scale_value), color)
	draw_rect(Rect2(pos.x + 18 * scale_value, pos.y - 14 * scale_value, 12 * scale_value, 48 * scale_value), color)


func _draw_roulette_room_prop(rect: Rect2, object_data: Dictionary, accent: Color, selected: bool, disabled: bool = false) -> void:
	var table := Rect2(rect.position + Vector2(rect.size.x * 0.06, rect.size.y * 0.48), Vector2(rect.size.x * 0.88, rect.size.y * 0.30))
	draw_rect(table, Color("#14503c"))
	draw_rect(table, accent, false, 2.0)
	var wheel_center := rect.position + Vector2(rect.size.x * 0.30, rect.size.y * 0.38)
	var wheel_radius := minf(rect.size.x, rect.size.y) * 0.20
	draw_circle(wheel_center, wheel_radius, Color("#351322"))
	draw_circle(wheel_center, wheel_radius * 0.78, C_AMBER)
	for index in range(8):
		var angle := float(index) * TAU / 8.0
		draw_line(wheel_center, wheel_center + Vector2(cos(angle), sin(angle)) * wheel_radius, C_SHADOW, 1.0)
	draw_circle(wheel_center, maxf(2.0, wheel_radius * 0.12), C_YELLOW)
	for column in range(4):
		var cell := Rect2(table.position + Vector2(table.size.x * (0.52 + float(column) * 0.10), table.size.y * 0.18), Vector2(table.size.x * 0.08, table.size.y * 0.56))
		draw_rect(cell, C_PINK if column % 2 == 0 else C_DARK)
	_draw_game_object_icon(object_data, _centered_icon_rect(rect, 22.0, Vector2(rect.size.x * 0.32, -rect.size.y * 0.25)), accent, selected, disabled)
	if selected: draw_rect(table.grow(3.0), C_WHITE, false, 2.0)
	if disabled: draw_rect(rect.grow(-2.0), Color(0.0, 0.0, 0.0, 0.48))


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
	var static_layer := _slot_prop_static_layer(rect, object_data, accent)
	var phase := float(static_layer.get("phase", 0.0))
	var profile: Dictionary = static_layer.get("profile", {})
	var runtime := _slot_prop_runtime_state(object_data)
	var preview := _slot_prop_preview_state(object_data)
	var preview_phase := str(preview.get("phase", "idle"))
	var live_preview := bool(preview.get("active", false)) or ["spinning", "win", "near_miss", "bonus", "nudge_chain"].has(preview_phase)
	var pulse_speed := 4.8 if preview_phase == "spinning" else 4.1 if live_preview else 3.5 if selected else 2.1
	var pulse := 0.38 + absf(sin(flicker * pulse_speed + phase * TAU)) * (0.34 if live_preview else 0.30 if selected else 0.14)
	var safe: Rect2 = static_layer.get("safe", rect)
	var reel_count := int(static_layer.get("reel_count", 3))
	var row_count := int(static_layer.get("row_count", 1))
	var video_feature := bool(static_layer.get("video_feature", false))
	var classic := bool(static_layer.get("classic", true))
	var slot_accent: Color = profile.get("accent", accent)
	var slot_light: Color = profile.get("light", C_CYAN)
	var slot_trim: Color = profile.get("trim", C_YELLOW)
	var primary: Color = profile.get("primary", Color("#0b0d18"))
	var secondary: Color = profile.get("secondary", Color("#07070c"))
	var glass: Color = profile.get("glass", Color("#f2efe2"))
	var base: Rect2 = static_layer.get("base", Rect2())
	var body: Rect2 = static_layer.get("body", Rect2())
	var topper: Rect2 = static_layer.get("topper", Rect2())
	var screen: Rect2 = static_layer.get("screen", Rect2())
	var feature_panel: Rect2 = static_layer.get("feature_panel", Rect2())
	var deck: Rect2 = static_layer.get("deck", Rect2())
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
		var feature_strip: Rect2 = static_layer.get("feature_strip", Rect2())
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
	var light_count := int(static_layer.get("light_count", 3))
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


func _slot_prop_static_layer(rect: Rect2, object_data: Dictionary, fallback_accent: Color) -> Dictionary:
	var object_id := str(object_data.get("id", object_data.get("label", "generated_machine")))
	# Spin previews are animated independently and can be large. Key this static
	# cabinet geometry only by the profile fields it actually consumes.
	var visual := _slot_prop_visual_state(object_data)
	var signature := hash([
		rect,
		fallback_accent,
		visual.get("machine_family", ""),
		visual.get("machine_format", ""),
		visual.get("cabinet_identity", ""),
		visual.get("cabinet_title", ""),
		visual.get("reel_count", null),
		visual.get("row_count", null),
		visual.get("cabinet_palette", {}),
	])
	var cached_value: Variant = slot_prop_static_layer_cache.get(object_id, {})
	if typeof(cached_value) == TYPE_DICTIONARY:
		var cached := cached_value as Dictionary
		if int(cached.get("signature", -1)) == signature:
			return cached
	var profile := _slot_prop_profile(object_data, fallback_accent)
	var phase := float(abs(hash(object_id)) % 1000) / 1000.0
	var safe := Rect2(
		rect.position + Vector2(rect.size.x * 0.14, rect.size.y * 0.03),
		Vector2(rect.size.x * 0.72, rect.size.y * 0.92)
	)
	var format_id := str(profile.get("format_id", "classic_3_reel"))
	var reel_count := maxi(3, int(profile.get("reel_count", 3)))
	var row_count := maxi(1, int(profile.get("row_count", 1)))
	var video_feature := format_id == "video_feature"
	var classic := format_id == "classic_3_reel" or row_count <= 1
	var base := Rect2(safe.position + Vector2(safe.size.x * (0.10 if classic else 0.08), safe.size.y * 0.86), Vector2(safe.size.x * (0.80 if classic else 0.84), safe.size.y * 0.10))
	var body := Rect2(safe.position + Vector2(safe.size.x * (0.15 if classic else 0.08), safe.size.y * (0.20 if classic else 0.15)), Vector2(safe.size.x * (0.70 if classic else 0.84), safe.size.y * (0.68 if classic else 0.73)))
	var topper := Rect2(safe.position + Vector2(safe.size.x * (0.10 if classic else 0.04), safe.size.y * 0.04), Vector2(safe.size.x * (0.80 if classic else 0.92), safe.size.y * (0.17 if classic else 0.15)))
	var screen := Rect2(body.position + Vector2(body.size.x * (0.18 if classic else 0.10), body.size.y * (0.30 if classic else 0.22)), Vector2(body.size.x * (0.64 if classic else 0.80), body.size.y * (0.26 if classic else 0.42)))
	if video_feature:
		screen = Rect2(body.position + Vector2(body.size.x * 0.09, body.size.y * 0.20), Vector2(body.size.x * 0.58, body.size.y * 0.48))
	var feature_panel := Rect2(body.position + Vector2(body.size.x * 0.72, body.size.y * 0.19), Vector2(body.size.x * 0.18, body.size.y * 0.48))
	var deck := Rect2(body.position + Vector2(body.size.x * 0.10, body.size.y * (0.70 if classic else 0.72)), Vector2(body.size.x * 0.80, body.size.y * (0.13 if classic else 0.12)))
	var feature_strip := Rect2(body.position + Vector2(body.size.x * 0.18, body.size.y * (0.60 if classic else 0.66)), Vector2(body.size.x * 0.64, body.size.y * (0.08 if classic else 0.05)))
	var layer := {
		"signature": signature,
		"phase": phase,
		"profile": profile,
		"safe": safe,
		"reel_count": reel_count,
		"row_count": row_count,
		"video_feature": video_feature,
		"classic": classic,
		"base": base,
		"body": body,
		"topper": topper,
		"screen": screen,
		"feature_panel": feature_panel,
		"deck": deck,
		"feature_strip": feature_strip,
		"light_count": maxi(3, int(safe.size.x / 16.0)),
	}
	if slot_prop_static_layer_cache.size() >= SLOT_PROP_STATIC_LAYER_CACHE_LIMIT and not slot_prop_static_layer_cache.has(object_id):
		slot_prop_static_layer_cache.erase(slot_prop_static_layer_cache.keys()[0])
	slot_prop_static_layer_cache[object_id] = layer
	return layer


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
	var title := str(visual.get("cabinet_title", "")).strip_edges().to_upper()
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
	var palette := _copy_dictionary(visual.get("cabinet_palette", {}))
	for key in ["primary", "secondary", "accent", "light", "trim", "glass"]:
		var color_text := str(palette.get(key, "")).strip_edges()
		if not color_text.is_empty():
			profile[key] = Color(color_text)
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
	var title := str(profile.get("title", "")).left(10)
	var status := str(preview.get("status_label", "")).strip_edges()
	if not status.is_empty() and preview_phase != "idle":
		title = status.left(10)
	if not title.is_empty():
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
	for cell_value in JsonCoerceScript._copy_array(preview.get("win_cells", [])):
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
	var coins: Array = JsonCoerceScript._copy_array(chain.get("coins", []))
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
