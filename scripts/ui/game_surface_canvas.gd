class_name GameSurfaceCanvas
extends Control

# Hosts the active gambling surface. Game-specific drawing lives in the active
# GameModule; this canvas only owns scaling, hit regions, overlays, and input.

signal surface_action(action: String, index: int, confirm_requested: bool)
signal surface_action_blocked(action: String, reason: String)
signal surface_pointer_action(action: String, index: int, phase: String, board_position: Vector2)
signal surface_music_cue(cue_id: String, context: Dictionary)

const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const SmallScreenPolicyScript := preload("res://scripts/ui/small_screen_policy.gd")
const SfxPlayerScript := preload("res://scripts/ui/sfx_player.gd")
const DrunkDistortionOverlayScript := preload("res://scripts/ui/drunk_distortion_overlay.gd")
const HeatFeedbackVisualsScript := preload("res://scripts/ui/heat_feedback_visuals.gd")

const C_DARK := VisualStyleScript.DARK
const C_DARK_2 := VisualStyleScript.DARK_2
const C_PANEL := VisualStyleScript.DARK_3
const C_PINK := VisualStyleScript.PINK
const C_PINK_2 := VisualStyleScript.PINK_2
const C_HOT := VisualStyleScript.HOT
const C_CYAN := VisualStyleScript.CYAN
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
const BOARD_SIZE := VisualStyleScript.GAME_BOARD_SIZE
const SLOT_BOARD_SIZE := Vector2(960, 540)
const MIN_SURFACE_TOUCH_HIT_SIZE := Vector2(44.0, 44.0)
const DRUNK_TIME_SCALE_MIN := 0.33
const PERF_DRAW_SAMPLE_LIMIT := 512
# Godot can deliver touch plus emulated mouse after a stalled frame.
const EMULATED_TOUCH_SUPPRESS_MS := 750
const EMULATED_TOUCH_SUPPRESS_DISTANCE := 18.0
const SURFACE_ANIMATION_FPS := 60.0
const SURFACE_ANIMATION_INTERVAL_SEC := 1.0 / SURFACE_ANIMATION_FPS
const DEFAULT_WEB_IDLE_ANIMATION_FPS := 1.0
const TRANSIENT_SURFACE_LOOP_HOLD_MSEC := 95

var game_id: String = ""
var state: Dictionary = {}
var view_data: Dictionary = {}
var selected_view_index: int = -1
var uses_foundation_snapshot := false
var background_texture: Texture2D
var use_external_background := false
var flicker: float = 0.0
var hit_regions: Array = []
var hovered_surface_action: String = ""
var hovered_surface_index: int = -1
var captured_surface_action: String = ""
var captured_surface_index: int = -1
var captured_surface_board_position := Vector2.ZERO
var captured_surface_keyboard := false
var captured_pointer_move_pending := false
var captured_pointer_move_position := Vector2.ZERO
var surface_animation_channels: Dictionary = {}
var surface_sfx_player: Node
var drunk_distortion_overlay: DrunkDistortionOverlay
var drunk_effect_mode: String = "distortion"
var surface_game_module: GameModule
var continuous_redraw_was_active := false
var last_audio_profile_id: String = ""
var perf_full_snapshot_calls := 0
var perf_runtime_status_calls := 0
var perf_draw_frame_usec_samples: Array = []
var perf_draw_frame_total_count := 0
var perf_patch_redraw_requests := 0
var perf_reduced_motion_measurement_redraw_requests := 0
var surface_label_fit_cache: Dictionary = {}
var surface_text_protected_rects: Array = []
var hit_region_group_cache: Dictionary = {}
var active_design_scale := Vector2.ONE
var active_design_offset := Vector2.ZERO
var active_design_local_offset := Vector2.ZERO
var design_space_active := false
var reduce_motion := false
var small_screen_mode := false
var drunk_time_scale := 1.0
var last_mouse_press_msec: int = -100000
var last_mouse_press_position := Vector2(-100000.0, -100000.0)
var last_touch_press_msec: int = -100000
var last_touch_press_position := Vector2(-100000.0, -100000.0)
var surface_animation_redraw_accumulator := 0.0
var surface_animation_redraw_count := 0
var perf_surface_animation_scheduler_elapsed_sec := 0.0
var surface_animation_handoff_until_msec := 0
var surface_render_elapsed_sec := 0.0
var surface_simulation_clock_msec := 0.0
var surface_presentation_clock_msec := 0.0
var transient_surface_loop_deadline_msec := 0
var transient_surface_loop_id := ""
var environment_activity_paused := false
var surface_render_state_dirty := false
var _surface_audio_authority := RefCounted.new()
var _surface_audio_authority_bound := false


func bind_surface_audio_authority(authority: RefCounted) -> void:
	if authority == null or _surface_audio_authority_bound:
		return
	_surface_audio_authority = authority
	_surface_audio_authority_bound = true
	if surface_sfx_player != null and surface_sfx_player.has_method("bind_surface_audio_authority"):
		surface_sfx_player.call("bind_surface_audio_authority", _surface_audio_authority)


func set_game_module(game_module: GameModule) -> void:
	if surface_game_module == game_module:
		return
	surface_game_module = game_module
	surface_render_state_dirty = true
	queue_redraw()


func set_environment_activity_paused(paused: bool) -> void:
	if environment_activity_paused == paused:
		return
	environment_activity_paused = paused
	if paused:
		_cancel_captured_surface_pointer()
	queue_redraw()


func clear_runtime_state() -> void:
	_cancel_captured_surface_pointer()
	stop_surface_audio()
	surface_game_module = null
	game_id = ""
	state = {}
	view_data = {}
	selected_view_index = -1
	uses_foundation_snapshot = false
	background_texture = null
	use_external_background = false
	hit_regions = []
	hovered_surface_action = ""
	hovered_surface_index = -1
	captured_surface_action = ""
	captured_surface_index = -1
	captured_surface_board_position = Vector2.ZERO
	captured_surface_keyboard = false
	captured_pointer_move_pending = false
	captured_pointer_move_position = Vector2.ZERO
	surface_animation_channels = {}
	continuous_redraw_was_active = false
	last_audio_profile_id = ""
	surface_label_fit_cache.clear()
	hit_region_group_cache.clear()
	perf_draw_frame_usec_samples = []
	perf_draw_frame_total_count = 0
	surface_animation_redraw_accumulator = 0.0
	surface_animation_redraw_count = 0
	perf_surface_animation_scheduler_elapsed_sec = 0.0
	surface_animation_handoff_until_msec = 0
	surface_render_elapsed_sec = 0.0
	surface_simulation_clock_msec = 0.0
	surface_presentation_clock_msec = 0.0
	transient_surface_loop_deadline_msec = 0
	transient_surface_loop_id = ""
	surface_render_state_dirty = false
	_update_drunk_distortion_overlay()
	queue_redraw()


func render_game_snapshot(snapshot: Dictionary) -> void:
	uses_foundation_snapshot = true
	surface_render_elapsed_sec = 0.0
	view_data = snapshot.duplicate(false)
	# Patch-routing metadata is never renderer state. Entry assembly can merge a
	# module patch before this boundary, so consume it defensively here as well as
	# in apply_surface_state_patch().
	view_data.erase("surface_defer_patch_redraw")
	game_id = str(view_data.get("game_id", game_id))
	state = view_data
	surface_simulation_clock_msec = float(state.get("surface_time_msec", surface_simulation_clock_msec))
	surface_presentation_clock_msec = float(state.get("surface_presentation_time_msec", state.get("surface_time_msec", surface_presentation_clock_msec)))
	reduce_motion = bool(state.get("reduce_motion", false))
	drunk_time_scale = clampf(float(state.get("drunk_time_scale", 1.0)), DRUNK_TIME_SCALE_MIN, 1.0)
	drunk_effect_mode = _normalized_drunk_effect_mode(str(state.get("drunk_effect_mode", drunk_effect_mode)))
	_update_drunk_distortion_overlay()
	_update_surface_animation_channels()
	surface_render_state_dirty = true
	_prepare_surface_render_state()
	queue_redraw()


func apply_surface_state_patch(patch: Dictionary) -> void:
	if patch.is_empty():
		return
	var defer_redraw := bool(patch.get("surface_defer_patch_redraw", false))
	for key in patch.keys():
		if str(key) == "surface_defer_patch_redraw":
			continue
		view_data[key] = patch[key]
	state = view_data
	if patch.has("surface_time_msec"):
		surface_simulation_clock_msec = float(state.get("surface_time_msec", surface_simulation_clock_msec))
	if patch.has("surface_presentation_time_msec"):
		surface_presentation_clock_msec = float(state.get("surface_presentation_time_msec", surface_presentation_clock_msec))
	if patch.has("reduce_motion"):
		reduce_motion = bool(state.get("reduce_motion", false))
	if patch.has("drunk_time_scale"):
		drunk_time_scale = clampf(float(state.get("drunk_time_scale", 1.0)), DRUNK_TIME_SCALE_MIN, 1.0)
	if patch.has("drunk_effect_mode"):
		drunk_effect_mode = _normalized_drunk_effect_mode(str(state.get("drunk_effect_mode", drunk_effect_mode)))
	if patch.has("drunk_level") or patch.has("drunk_effect_mode") or patch.has("reduce_motion"):
		_update_drunk_distortion_overlay()
	if patch.has("surface_animation_channels"):
		_update_surface_animation_channels()
	surface_render_state_dirty = true
	# A deferred patch advances authoritative simulation state without making a
	# frame visible. Preparing its dense render batch here rebuilt the complete
	# Coin Pusher projection at authority cadence, then discarded most batches
	# before the Web presentation scheduler could draw them.
	if not defer_redraw:
		_prepare_surface_render_state()
	if not defer_redraw:
		perf_patch_redraw_requests += 1
		queue_redraw()


func _prepare_surface_render_state() -> void:
	if not surface_render_state_dirty:
		return
	if surface_game_module != null and surface_game_module.has_method("prepare_surface_render_state"):
		surface_game_module.call("prepare_surface_render_state", state)
	surface_render_state_dirty = false


func set_selected_index(index: int) -> void:
	selected_view_index = index
	queue_redraw()


func set_small_screen_mode(enabled: bool) -> void:
	if small_screen_mode == enabled:
		return
	small_screen_mode = enabled
	hit_regions.clear()
	queue_redraw()


func current_view_snapshot() -> Dictionary:
	perf_full_snapshot_calls += 1
	return {
		"game_id": game_id,
		"state": view_data.duplicate(true),
		"selected_view_index": selected_view_index,
		"uses_foundation_snapshot": uses_foundation_snapshot,
		"surface_renderer": _surface_renderer(),
		"surface_life": _surface_life(),
		"surface_cast": _surface_cast(),
		"board_rect": _rect_snapshot(board_rect()),
		"board_size": _vector_snapshot(_active_board_size()),
		"board_aspect_ratio": _active_board_aspect_ratio(),
		"preserves_aspect_ratio": true,
		"small_screen_mode": small_screen_mode,
		"minimum_touch_hit_size": SmallScreenPolicyScript.surface_hit_size(small_screen_mode, MIN_SURFACE_TOUCH_HIT_SIZE),
		"surface_hit_actions": _hit_region_snapshots(),
		"outcome_message": str(state.get("outcome_message", state.get("result_message", ""))),
		"outcome_bankroll_delta": int(state.get("outcome_bankroll_delta", state.get("bankroll_delta", 0))),
		"outcome_suspicion_delta": int(state.get("outcome_suspicion_delta", state.get("suspicion_delta", 0))),
		"drunk_effect_mode": drunk_effect_mode,
		"drunk_time_scale": drunk_time_scale,
		"drunk_time_scale_percent": int(round(drunk_time_scale * 100.0)),
		"reduce_motion": reduce_motion,
		"surface_simulation_time_msec": surface_simulation_time_msec(),
		"surface_presentation_time_msec": surface_presentation_time_msec(),
		"surface_text_protected_rect_count": surface_text_protected_rects.size(),
		"drunk_distortion_visible": drunk_distortion_overlay != null and drunk_distortion_overlay.visible,
		"drunk_distortion_debug": drunk_distortion_overlay.debug_snapshot() if drunk_distortion_overlay != null else {},
		"surface_animations": _surface_animation_status_snapshot(),
		"surface_animation_target_fps": SURFACE_ANIMATION_FPS,
		"surface_idle_animation_fps": surface_idle_animation_fps(),
		"surface_animation_redraw_count": surface_animation_redraw_count,
		"surface_animation_scheduler_elapsed_msec": maxi(0, int(round(perf_surface_animation_scheduler_elapsed_sec * 1000.0))),
		"surface_continuous_redraw_active": _needs_continuous_redraw(),
		"surface_animation_liveness_active": surface_animation_liveness_active(),
		"surface_animation_handoff_active": _surface_animation_handoff_active(),
	}


func realtime_surface_state() -> Dictionary:
	return state


func surface_runtime_status() -> Dictionary:
	perf_runtime_status_calls += 1
	return {
		"game_id": game_id,
		"selected_view_index": selected_view_index,
		"uses_foundation_snapshot": uses_foundation_snapshot,
		"surface_renderer": _surface_renderer(),
		"surface_life": _surface_life(),
		"surface_cast": _surface_cast(),
		"board_rect": _rect_snapshot(board_rect()),
		"board_size": _vector_snapshot(_active_board_size()),
		"board_aspect_ratio": _active_board_aspect_ratio(),
		"preserves_aspect_ratio": true,
		"small_screen_mode": small_screen_mode,
		"outcome_message": str(state.get("outcome_message", state.get("result_message", ""))),
		"outcome_bankroll_delta": int(state.get("outcome_bankroll_delta", state.get("bankroll_delta", 0))),
		"outcome_suspicion_delta": int(state.get("outcome_suspicion_delta", state.get("suspicion_delta", 0))),
		"drunk_effect_mode": drunk_effect_mode,
		"drunk_time_scale": drunk_time_scale,
		"drunk_time_scale_percent": int(round(drunk_time_scale * 100.0)),
		"reduce_motion": reduce_motion,
		"surface_simulation_time_msec": surface_simulation_time_msec(),
		"surface_presentation_time_msec": surface_presentation_time_msec(),
		"surface_text_protected_rect_count": surface_text_protected_rects.size(),
		"drunk_distortion_visible": drunk_distortion_overlay != null and drunk_distortion_overlay.visible,
		"drunk_distortion_debug": drunk_distortion_overlay.debug_snapshot() if drunk_distortion_overlay != null else {},
		"surface_animations": _surface_animation_status_snapshot(),
		"surface_animation_target_fps": SURFACE_ANIMATION_FPS,
		"surface_idle_animation_fps": surface_idle_animation_fps(),
		"surface_animation_redraw_count": surface_animation_redraw_count,
		"surface_animation_scheduler_elapsed_msec": maxi(0, int(round(perf_surface_animation_scheduler_elapsed_sec * 1000.0))),
		"surface_continuous_redraw_active": _needs_continuous_redraw(),
		"surface_animation_liveness_active": surface_animation_liveness_active(),
		"surface_animation_handoff_active": _surface_animation_handoff_active(),
	}


func surface_realtime_ui_status() -> Dictionary:
	perf_runtime_status_calls += 1
	return {
		"surface_animations": _surface_animation_status_snapshot(),
		"surface_animation_handoff_active": _surface_animation_handoff_active(),
	}


func surface_realtime_state_refresh_enabled() -> bool:
	return uses_foundation_snapshot and bool(state.get("surface_realtime_state_refresh", false))


func surface_animation_liveness_active() -> bool:
	return _surface_animation_liveness_active()


# This is the production idle cadence, not a test floor. Web intentionally
# renders low-detail idle motion less often; native keeps the full cadence.
func surface_idle_animation_fps() -> float:
	if reduce_motion or not bool(state.get("surface_animates_idle", false)):
		return 0.0
	if not OS.has_feature("web"):
		return SURFACE_ANIMATION_FPS
	return _requested_web_idle_animation_fps()


# A lightweight boundary query for UI owners that must wait until a finite
# presentation channel has rebuilt its final hit regions. Idle renderer motion
# is intentionally excluded: it does not live in surface_animation_channels.
func surface_transition_animation_active() -> bool:
	for channel_id_value in surface_animation_channels.keys():
		if surface_animation_active(str(channel_id_value)):
			return true
	return false


func surface_bankroll_presentation_active() -> bool:
	# Bankroll reveal ownership needs only the transition/handoff booleans. The
	# former caller rebuilt the complete diagnostic runtime status every frame,
	# including geometry, effects and all animation snapshots, after each wager.
	return surface_transition_animation_active() or _surface_animation_handoff_active()


func reset_performance_counters() -> void:
	perf_full_snapshot_calls = 0
	perf_runtime_status_calls = 0
	perf_draw_frame_usec_samples = []
	perf_draw_frame_total_count = 0
	perf_patch_redraw_requests = 0
	perf_reduced_motion_measurement_redraw_requests = 0
	surface_animation_redraw_count = 0
	perf_surface_animation_scheduler_elapsed_sec = 0.0
	if surface_game_module != null and surface_game_module.has_method("reset_renderer_performance_counters"):
		surface_game_module.call("reset_renderer_performance_counters")
	# Reduced motion intentionally freezes the animation scheduler. A performance
	# sample still needs one real production-canvas draw after its counters reset
	# so the measured state cannot be a stale pre-reset frame.
	if reduce_motion:
		perf_reduced_motion_measurement_redraw_requests += 1
		queue_redraw()


func performance_counters() -> Dictionary:
	var result := {
		"full_snapshot_calls": perf_full_snapshot_calls,
		"runtime_status_calls": perf_runtime_status_calls,
		"patch_redraw_requests": perf_patch_redraw_requests,
		"reduced_motion_measurement_redraw_requests": perf_reduced_motion_measurement_redraw_requests,
		"surface_animation_redraw_count": surface_animation_redraw_count,
		"surface_animation_scheduler_elapsed_msec": maxi(0, int(round(perf_surface_animation_scheduler_elapsed_sec * 1000.0))),
		"surface_idle_animation_fps": surface_idle_animation_fps(),
		"surface_animation_liveness_active": surface_animation_liveness_active(),
		"draw_sample_count": perf_draw_frame_total_count,
		"draw_sample_buffer_count": perf_draw_frame_usec_samples.size(),
		"draw_frame_usec_samples": perf_draw_frame_usec_samples.duplicate(),
		"draw_avg_ms": _draw_average_ms(),
		"draw_p95_ms": _draw_percentile_ms(0.95),
		"draw_max_ms": _draw_max_ms(),
	}
	if surface_game_module != null and surface_game_module.has_method("renderer_performance_counters"):
		result["renderer_stage_usec_samples"] = surface_game_module.call("renderer_performance_counters")
	return result


func performance_live_status() -> Dictionary:
	return {
		"surface_animation_redraw_count": surface_animation_redraw_count,
		"surface_animation_scheduler_elapsed_msec": maxi(0, int(round(perf_surface_animation_scheduler_elapsed_sec * 1000.0))),
		"surface_idle_animation_fps": surface_idle_animation_fps(),
		"surface_animation_liveness_active": surface_animation_liveness_active(),
		"draw_sample_count": perf_draw_frame_total_count,
		"draw_sample_buffer_count": perf_draw_frame_usec_samples.size(),
		"draw_avg_ms": _draw_average_ms(),
	}


func debug_advance_idle_liveness(delta: float) -> Dictionary:
	if reduce_motion:
		return surface_runtime_status()
	var clamped_delta := maxf(0.0, delta)
	flicker += clamped_delta
	surface_render_elapsed_sec += clamped_delta
	_schedule_surface_animation_redraws(clamped_delta)
	return surface_runtime_status()


func surface_render_elapsed_msec() -> int:
	return maxi(0, int(round(surface_render_elapsed_sec * 1000.0)))


func debug_surface_motion_sample() -> Dictionary:
	if surface_game_module != null and surface_game_module.has_method("surface_motion_signature"):
		var sample: Variant = surface_game_module.call("surface_motion_signature", self, state)
		if typeof(sample) == TYPE_DICTIONARY:
			return sample as Dictionary
	return {
		"surface_flicker_bucket": int(round(surface_flicker() * 1000.0)),
	}


func debug_soak_snapshot() -> Dictionary:
	return {
		"game_id": game_id,
		"state_key_count": state.size(),
		"view_data_key_count": view_data.size(),
		"surface_animation_channel_count": surface_animation_channels.size(),
		"surface_label_fit_cache_size": surface_label_fit_cache.size(),
		"hit_region_group_cache_size": hit_region_group_cache.size(),
		"hit_region_count": hit_regions.size(),
		"draw_sample_count": perf_draw_frame_total_count,
		"draw_sample_buffer_count": perf_draw_frame_usec_samples.size(),
		"surface_sfx": surface_sfx_player.call("debug_soak_snapshot") if surface_sfx_player != null and surface_sfx_player.has_method("debug_soak_snapshot") else {},
	}


func _record_draw_performance(start_usec: int) -> void:
	var elapsed := maxi(0, Time.get_ticks_usec() - start_usec)
	perf_draw_frame_total_count += 1
	perf_draw_frame_usec_samples.append(elapsed)
	if perf_draw_frame_usec_samples.size() > PERF_DRAW_SAMPLE_LIMIT:
		perf_draw_frame_usec_samples.pop_front()


func _draw_average_ms() -> float:
	if perf_draw_frame_usec_samples.is_empty():
		return 0.0
	var total := 0
	for sample_value in perf_draw_frame_usec_samples:
		total += int(sample_value)
	return float(total) / float(perf_draw_frame_usec_samples.size()) / 1000.0


func _draw_percentile_ms(percentile: float) -> float:
	if perf_draw_frame_usec_samples.is_empty():
		return 0.0
	var sorted_samples := perf_draw_frame_usec_samples.duplicate() # SA2_PER_FRAME_OK: performance counter read, not rendering/per-frame.
	sorted_samples.sort()
	var index := clampi(int(ceil(percentile * float(sorted_samples.size()))) - 1, 0, sorted_samples.size() - 1)
	return float(int(sorted_samples[index])) / 1000.0


func _draw_max_ms() -> float:
	var max_usec := 0
	for sample_value in perf_draw_frame_usec_samples:
		max_usec = maxi(max_usec, int(sample_value))
	return float(max_usec) / 1000.0


func stop_surface_audio() -> void:
	if surface_sfx_player != null:
		surface_sfx_player.stop_all()
	last_audio_profile_id = ""


func local_position_for_surface_action(action: String, index: int = -1) -> Vector2:
	_ensure_snapshot_proxy_hit_regions()
	var exact_position := _local_position_for_hit_region(action, index)
	if exact_position.x >= 0.0 and exact_position.y >= 0.0:
		return exact_position
	var resolved := _resolved_surface_action_binding(action, index)
	action = str(resolved.get("action", action))
	index = int(resolved.get("index", index))
	return _local_position_for_hit_region(action, index)


func global_rect_for_surface_action(action: String, index: int = -1) -> Rect2:
	_ensure_snapshot_proxy_hit_regions()
	var board_hit_rect := _board_hit_rect_for_action(action, index)
	if not board_hit_rect.has_area():
		var resolved := _resolved_surface_action_binding(action, index)
		board_hit_rect = _board_hit_rect_for_action(str(resolved.get("action", action)), int(resolved.get("index", index)))
	if not board_hit_rect.has_area():
		return Rect2()
	var board_scale := _board_scale()
	var local_rect := Rect2(_board_to_screen(board_hit_rect.position), board_hit_rect.size * board_scale)
	var transform := get_global_transform()
	var corner_a := transform * local_rect.position
	var corner_b := transform * Vector2(local_rect.end.x, local_rect.position.y)
	var corner_c := transform * local_rect.end
	var corner_d := transform * Vector2(local_rect.position.x, local_rect.end.y)
	var minimum := Vector2(minf(minf(corner_a.x, corner_b.x), minf(corner_c.x, corner_d.x)), minf(minf(corner_a.y, corner_b.y), minf(corner_c.y, corner_d.y)))
	var maximum := Vector2(maxf(maxf(corner_a.x, corner_b.x), maxf(corner_c.x, corner_d.x)), maxf(maxf(corner_a.y, corner_b.y), maxf(corner_c.y, corner_d.y)))
	return Rect2(minimum, maximum - minimum)


func _board_hit_rect_for_action(action: String, index: int = -1) -> Rect2:
	for region_value in hit_regions:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		if str(region.get("action", "")) != action:
			continue
		if index >= 0 and int(region.get("index", -1)) != index:
			continue
		var rect_value: Variant = region.get("rect", Rect2())
		return rect_value if typeof(rect_value) == TYPE_RECT2 else Rect2()
	return Rect2()


func _local_position_for_hit_region(action: String, index: int = -1) -> Vector2:
	for region in hit_regions:
		if typeof(region) != TYPE_DICTIONARY:
			continue
		var region_action := str(region.get("action", ""))
		var region_index := int(region.get("index", -1))
		if region_action != action:
			continue
		if index >= 0 and region_index != index:
			continue
		var rect: Rect2 = region.get("rect", Rect2())
		return _board_to_screen(rect.get_center())
	return Vector2(-1.0, -1.0)


func board_rect() -> Rect2:
	var scale := _board_scale()
	return Rect2(_board_offset(scale), _active_board_size() * scale)


func surface_board_size() -> Vector2:
	return _active_board_size()


func surface_begin_design_space(design_size: Vector2) -> void:
	surface_begin_design_space_inset(design_size, Vector2.ZERO)


func surface_begin_design_space_inset(design_size: Vector2, inset: Vector2) -> void:
	var transform := _design_space_transform_values(design_size, inset, Vector2.ZERO)
	active_design_scale = transform.get("design_scale", Vector2.ONE)
	active_design_offset = transform.get("design_offset", Vector2.ZERO)
	active_design_local_offset = Vector2.ZERO
	design_space_active = true
	draw_set_transform(transform.get("position", Vector2.ZERO), 0.0, transform.get("scale", Vector2.ONE))


func surface_set_design_space_local_offset(local_offset: Vector2) -> void:
	if not design_space_active:
		return
	active_design_local_offset = local_offset
	var scale := _board_scale()
	draw_set_transform(
		_board_offset(scale) + active_design_offset * scale + local_offset * active_design_scale * scale,
		0.0,
		active_design_scale * scale
	)


func debug_design_space_transform(design_size: Vector2, local_offset: Vector2 = Vector2.ZERO) -> Dictionary:
	return _design_space_transform_values(design_size, Vector2.ZERO, local_offset)


func surface_end_design_space() -> void:
	active_design_scale = Vector2.ONE
	active_design_offset = Vector2.ZERO
	active_design_local_offset = Vector2.ZERO
	design_space_active = false
	_scale_canvas()


func surface_filled_polygon(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)


func surface_polyline(points: PackedVector2Array, color: Color, width: float = -1.0) -> void:
	draw_polyline(points, color, width)


func surface_present_multimesh_batch(multimesh: MultiMesh, texture: Texture2D, batch_material: Material, design_size: Vector2) -> void:
	# CanvasItem.draw_multimesh records the batch in this parent's draw command
	# stream at the exact call site. A child MultiMeshInstance2D would render only
	# after the parent's complete _draw(), placing coins above labels/glass/hardware.
	# Cabinet batches currently use no private material; preserve the argument so
	# generic harnesses retain a stable seam.
	if multimesh == null or texture == null or design_size.x <= 0.0 or design_size.y <= 0.0:
		return
	if batch_material != null:
		push_warning("Surface in-order MultiMesh batches inherit the canvas material.")
	draw_multimesh(multimesh, texture)


func _design_space_transform_values(design_size: Vector2, inset: Vector2, local_offset: Vector2) -> Dictionary:
	var safe_design := Vector2(maxf(1.0, design_size.x), maxf(1.0, design_size.y))
	var board_size := _active_board_size()
	var scale := _board_scale()
	var safe_inset := Vector2(
		clampf(inset.x, 0.0, board_size.x * 0.25),
		clampf(inset.y, 0.0, board_size.y * 0.25)
	)
	var usable_size := Vector2(
		maxf(1.0, board_size.x - safe_inset.x * 2.0),
		maxf(1.0, board_size.y - safe_inset.y * 2.0)
	)
	var design_scale_value := minf(usable_size.x / safe_design.x, usable_size.y / safe_design.y)
	var design_scale := Vector2(design_scale_value, design_scale_value)
	var design_offset := safe_inset + (usable_size - safe_design * design_scale_value) * 0.5
	return {
		"position": _board_offset(scale) + design_offset * scale + local_offset * design_scale * scale,
		"scale": design_scale * scale,
		"design_scale": design_scale,
		"design_offset": design_offset,
		"local_offset": local_offset,
	}


func surface_flicker() -> float:
	if reduce_motion:
		return 0.0
	return flicker


func surface_simulation_time_msec() -> int:
	return maxi(0, int(round(surface_simulation_clock_msec)))


func surface_presentation_time_msec() -> int:
	return maxi(0, int(round(surface_presentation_clock_msec)))


func surface_elapsed(channel_id: String) -> float:
	var channel := _surface_animation_channel(channel_id)
	if channel.is_empty() or not bool(channel.get("active", false)):
		return 999.0
	if reduce_motion:
		return surface_animation_duration(channel_id)
	var started_msec := int(channel.get("started_msec", 0))
	if started_msec <= 0:
		return 999.0
	# Persistent game events are authored against the pause-safe surface clock,
	# while UI-local transitions with no authored start time use engine time.
	# Mixing the two makes an animation appear already over after a long run has
	# accumulated time in dialogue, menus, or other paused presentation states.
	var clock_source := str(channel.get("clock_source", "realtime"))
	var now_msec := Time.get_ticks_msec()
	if clock_source == "surface":
		now_msec = surface_simulation_time_msec()
	elif clock_source == "presentation":
		now_msec = surface_presentation_time_msec()
	var elapsed_msec := maxi(0, now_msec - started_msec)
	# Resume offsets are captured from surface_elapsed(), so they are already in
	# presentation-time units. Scale only the new UI-local clock delta.
	var elapsed_offset_msec := maxi(0, int(channel.get("elapsed_offset_msec", 0)))
	return (float(elapsed_msec) * drunk_time_scale + float(elapsed_offset_msec)) / 1000.0


func surface_animation_duration(channel_id: String) -> float:
	var channel := _surface_animation_channel(channel_id)
	return float(maxi(0, int(channel.get("duration_msec", 0)))) / 1000.0


func surface_animation_active(channel_id: String) -> bool:
	if reduce_motion:
		return false
	var channel := _surface_animation_channel(channel_id)
	if channel.is_empty() or not bool(channel.get("active", false)):
		return false
	if str(channel.get("active_id", "")).is_empty():
		return false
	var duration := surface_animation_duration(channel_id)
	if duration <= 0.0:
		return true
	return surface_elapsed(channel_id) < duration


func surface_low_detail_idle() -> bool:
	if not OS.has_feature("web"):
		return false
	if reduce_motion or not bool(state.get("surface_animates_idle", false)):
		return false
	if _screen_effect_overlay_needs_redraw() or _surface_dynamic_overlay_channel_active() or _surface_animation_handoff_active():
		return false
	for channel_id in surface_animation_channels.keys():
		if surface_animation_active(str(channel_id)):
			return false
	return true


func surface_animation_progress(channel_id: String) -> float:
	if reduce_motion:
		return 1.0
	var duration := surface_animation_duration(channel_id)
	if duration <= 0.0:
		return 0.0 if surface_animation_active(channel_id) else 1.0
	return clampf(surface_elapsed(channel_id) / duration, 0.0, 1.0)


func surface_animation_active_id(channel_id: String) -> String:
	return str(_surface_animation_channel(channel_id).get("active_id", ""))


func surface_animation_metadata(channel_id: String) -> Dictionary:
	return _copy_dict(_surface_animation_channel(channel_id).get("metadata", {}))


func surface_play_audio_cue(cue_id: String, context: Dictionary = {}, authority: Variant = null) -> void:
	if authority != _surface_audio_authority:
		return
	var normalized_cue := cue_id.strip_edges()
	if normalized_cue.is_empty():
		return
	_ensure_surface_sfx_player()
	surface_sfx_player.play_surface_cue(normalized_cue, context, state, _surface_audio_authority)


func surface_start_audio_loop(cue_id: String, volume_db: float = -10.0, pitch: float = 1.0, authority: Variant = null) -> void:
	if authority != _surface_audio_authority:
		return
	var normalized_cue := cue_id.strip_edges()
	if normalized_cue.is_empty():
		return
	_ensure_surface_sfx_player()
	if normalized_cue == "scratch_paper_foley_loop":
		transient_surface_loop_id = normalized_cue
		transient_surface_loop_deadline_msec = Time.get_ticks_msec() + TRANSIENT_SURFACE_LOOP_HOLD_MSEC
	if surface_sfx_player.has_method("start_surface_loop"):
		surface_sfx_player.call("start_surface_loop", normalized_cue, volume_db, pitch, _surface_audio_authority)


func surface_stop_audio_loop(cue_id: String = "", authority: Variant = null) -> void:
	if authority != _surface_audio_authority:
		return
	transient_surface_loop_deadline_msec = 0
	transient_surface_loop_id = ""
	if surface_sfx_player != null and surface_sfx_player.has_method("stop_surface_loop"):
		surface_sfx_player.call("stop_surface_loop", cue_id, _surface_audio_authority)


func surface_add_hit(rect: Rect2, action: String, index: int = -1, expand_touch_hit: bool = true) -> void:
	hit_regions.append({"rect": _touch_hit_rect(rect, expand_touch_hit), "action": action, "index": index})
	if not bool(state.get("surface_debug_hit_regions", false)):
		return
	draw_rect(rect, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.09), false, 2)
	draw_rect(Rect2(rect.position + Vector2(4, 4), rect.size - Vector2(8, 8)), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.14), false, 1)


func surface_add_invisible_hit(rect: Rect2, action: String, index: int = -1, expand_touch_hit: bool = true) -> void:
	hit_regions.append({"rect": _touch_hit_rect(rect, expand_touch_hit), "action": action, "index": index})


func surface_add_exact_hit(rect: Rect2, action: String, index: int = -1) -> void:
	surface_add_hit(rect, action, index, false)


# Registers a normal click/touch target that also activates once when the mouse
# enters it. Repeated motion inside the same target does not emit again.
func surface_add_exact_hover_hit(rect: Rect2, action: String, index: int = -1) -> void:
	surface_add_hit(rect, action, index, false)
	if not hit_regions.is_empty():
		(hit_regions[-1] as Dictionary)["activate_on_hover"] = true


func surface_add_cached_exact_hits(cache_key: String, rect_sources: Array, action: String) -> void:
	if cache_key.is_empty() or action.is_empty():
		return
	if not hit_region_group_cache.has(cache_key):
		var cached_regions: Array = []
		for index in range(rect_sources.size()):
			var rect := _hit_rect_from_source(rect_sources[index])
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				continue
			cached_regions.append({"rect": rect, "action": action, "index": index})
		if hit_region_group_cache.size() > 64:
			hit_region_group_cache.clear()
		hit_region_group_cache[cache_key] = cached_regions
	hit_regions.append_array(hit_region_group_cache.get(cache_key, []))


func surface_add_exact_invisible_hit(rect: Rect2, action: String, index: int = -1) -> void:
	surface_add_invisible_hit(rect, action, index, false)


func surface_add_drag_hit(rect: Rect2, action: String, index: int = -1) -> void:
	hit_regions.append({"rect": rect, "action": action, "index": index, "drag": true})


# A captured pointer target that also supports the platform-neutral confirm
# action. Games opt in per region; the canvas never names a game or command.
func surface_add_hold_hit(rect: Rect2, action: String, index: int = -1) -> void:
	hit_regions.append({"rect": rect, "action": action, "index": index, "drag": true, "keyboard_hold": true})


# Opt-in adapter for GameRitualLayout.compile_pointer_hits(). Existing games do
# not call this method, so their hit registration and input traces are unchanged.
func surface_add_ritual_hits(compiled_hits: Array) -> void:
	for index in range(compiled_hits.size()):
		var hit_value: Variant = compiled_hits[index]
		if typeof(hit_value) != TYPE_DICTIONARY:
			continue
		var hit: Dictionary = hit_value
		var rect: Rect2 = hit.get("rect", Rect2())
		var action := str(hit.get("action", ""))
		if not rect.has_area() or action.is_empty():
			continue
		var verb := str(hit.get("verb", ""))
		if verb == "hold":
			surface_add_hold_hit(rect, action, index)
		elif bool(hit.get("capture", false)):
			surface_add_drag_hit(rect, action, index)
		else:
			surface_add_exact_hit(rect, action, index)
		var registered: Dictionary = hit_regions[-1]
		registered["ritual_pointer_id"] = str(hit.get("pointer_id", ""))
		registered["ritual_target_region"] = str(hit.get("target_region", ""))
		hit_regions[-1] = registered


func surface_region_hovered(action: String, index: int = -1) -> bool:
	return hovered_surface_action == action and (index < 0 or hovered_surface_index == index)


func surface_hovered_index(action: String) -> int:
	return hovered_surface_index if hovered_surface_action == action else -1


func surface_action_is_blocked(action: String) -> bool:
	return _surface_action_blocked(action)


func surface_native_action_selected(action: String) -> bool:
	var selected_regions: Array = state.get("native_selected_surface_actions", [])
	for selected_region in selected_regions:
		if str(selected_region) == action:
			return true
	return false


func surface_label(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	_register_surface_text_rect(text, pos, font_size)
	draw_string(get_theme_default_font(), pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.0, 0.0, 0.0, 0.62))
	draw_string(get_theme_default_font(), pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func surface_label_plain(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	_register_surface_text_rect(text, pos, font_size)
	draw_string(get_theme_default_font(), pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func surface_label_centered(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	_register_surface_text_panel_rect(rect)
	var font := get_theme_default_font()
	var fitted_size := _centered_label_fit_size(font, text, rect, font_size)
	var ascent := font.get_ascent(fitted_size)
	var descent := font.get_descent(fitted_size)
	var baseline_y := rect.position.y + (rect.size.y - ascent - descent) * 0.5 + ascent
	var shadow := Color(0.0, 0.0, 0.0, 0.62)
	draw_string(font, Vector2(rect.position.x + 1.0, baseline_y + 1.0), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fitted_size, shadow)
	draw_string(font, Vector2(rect.position.x, baseline_y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fitted_size, color)


func surface_label_centered_plain(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	_register_surface_text_panel_rect(rect)
	var font := get_theme_default_font()
	var fitted_size := _centered_label_fit_size(font, text, rect, font_size)
	var ascent := font.get_ascent(fitted_size)
	var descent := font.get_descent(fitted_size)
	var baseline_y := rect.position.y + (rect.size.y - ascent - descent) * 0.5 + ascent
	draw_string(font, Vector2(rect.position.x, baseline_y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fitted_size, color)


# Reel symbols redraw at 60 fps while a visible machine spins. Their labels are
# already short and size-bounded by the renderer, so avoid general-purpose text
# fitting, shadow, and protected-UI bookkeeping on this hot path.
func surface_reel_symbol_label(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var baseline_y := rect.position.y + (rect.size.y - ascent - descent) * 0.5 + ascent
	draw_string(font, Vector2(rect.position.x, baseline_y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, color)


func _centered_label_fit_size(font: Font, text: String, rect: Rect2, font_size: int) -> int:
	var cache_key := "%s|%.1f|%.1f|%d" % [text, rect.size.x, rect.size.y, font_size]
	if surface_label_fit_cache.has(cache_key):
		return int(surface_label_fit_cache.get(cache_key, font_size))
	var fitted_size := maxi(1, font_size)
	while fitted_size > 6:
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted_size)
		var line_height := font.get_ascent(fitted_size) + font.get_descent(fitted_size)
		if text_size.x <= rect.size.x and line_height <= rect.size.y:
			break
		fitted_size -= 1
	if surface_label_fit_cache.size() > 512:
		surface_label_fit_cache.clear()
	surface_label_fit_cache[cache_key] = fitted_size
	return fitted_size


func _register_surface_text_rect(text: String, pos: Vector2, font_size: int) -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		return
	var estimated_width := clampf(float(clean.length()) * float(maxi(1, font_size)) * 0.62 + 4.0, 18.0, _active_board_size().x)
	_register_surface_text_panel_rect(Rect2(pos + Vector2(-2.0, -float(font_size) - 2.0), Vector2(estimated_width, float(font_size) + 8.0)))


func _register_surface_text_panel_rect(rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if surface_text_protected_rects.size() >= DrunkDistortionOverlay.MAX_UI_PROTECTED_RECTS:
		return
	surface_text_protected_rects.append(rect)


func surface_register_text_protected_rect(rect: Rect2) -> void:
	# Retained renderer layers still own live readability metadata. Route their
	# exact design-space rectangles through the same cap and validation as text
	# drawn directly on this production surface.
	_register_surface_text_panel_rect(rect)


func surface_title(text: String, pos: Vector2, color: Color) -> void:
	surface_label(text, pos + Vector2(2, 0), 30, Color(color.r, color.g, color.b, 0.28))
	surface_label(text, pos, 30, color)


func surface_draw_ready_badge(rect: Rect2, label: String) -> void:
	var width := clampf(float(label.length()) * 6.2 + 10.0, 42.0, rect.size.x)
	var badge := Rect2(rect.position + Vector2(rect.size.x - width - 4.0, -15.0), Vector2(width, 14.0))
	draw_rect(badge, Color(0.0, 0.0, 0.0, 0.76))
	draw_rect(badge, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.78), false, 1)
	surface_label(label, badge.position + Vector2(5, 11), 9, C_YELLOW)


func surface_draw_stake_control(rect: Rect2, label: String, enabled: bool, action: String) -> void:
	var hovered := surface_region_hovered(action)
	var fill := Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.24 if hovered else 0.16) if enabled else Color(0.04, 0.04, 0.07, 0.74)
	draw_rect(rect, fill)
	draw_rect(rect, C_WHITE if hovered and enabled else C_YELLOW if enabled else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.28), false, 2 if hovered else 1)
	surface_label_centered(label, rect.grow(-2.0), 18, C_YELLOW if enabled else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.52))
	if enabled:
		surface_add_hit(rect, action)


func surface_draw_native_stake_strip(pos: Vector2) -> void:
	if _surface_renderer() == "slot_machine":
		return
	var stake_text := "Stake -"
	var enabled := bool(state.get("has_valid_stake", false))
	if enabled:
		stake_text = "Stake %d" % int(state.get("selected_stake", 0))
	surface_label(stake_text, pos + Vector2(0, 22), 15, C_YELLOW)
	surface_draw_stake_control(Rect2(pos + Vector2(74, 0), Vector2(26, 34)), "-", enabled, "surface_stake_down")
	surface_draw_stake_control(Rect2(pos + Vector2(104, 0), Vector2(26, 34)), "+", enabled, "surface_stake_up")
	surface_draw_stake_control(Rect2(pos + Vector2(134, 0), Vector2(44, 34)), "MAX", enabled, "surface_stake_max")


func surface_draw_action_button(rect: Rect2, label: String, action: String, index: int, accent: Color) -> void:
	var hovered := surface_region_hovered(action, index)
	var selected := surface_native_action_selected(action)
	var fill := Color(accent.r, accent.g, accent.b, 0.26 if selected else 0.16 if hovered else 0.10)
	draw_rect(rect, fill)
	draw_rect(rect, C_WHITE if hovered or selected else accent, false, 2 if hovered or selected else 1)
	surface_label_centered(label.left(22), Rect2(rect.position + Vector2(6.0, 6.0), Vector2(rect.size.x - 12.0, rect.size.y - 12.0)), 15, accent)
	if selected:
		surface_draw_ready_badge(rect, "CLICK AGAIN")
	elif hovered:
		surface_draw_ready_badge(rect, "CLICK")
	surface_add_hit(rect, action, index)


func surface_draw_guidance_border(rect: Rect2, label: String = "", active: bool = true) -> void:
	var color := C_YELLOW if active else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.42)
	var hovered := active and _hit_region_hovered_rect(rect)
	var border_width := 4 if hovered and not reduce_motion else 3
	var glow_alpha := 0.20 if reduce_motion else (0.30 + 0.12 * sin(float(Time.get_ticks_msec()) / 90.0))
	if active:
		draw_rect(rect.grow(8.0), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, glow_alpha), false, 3)
	draw_rect(rect.grow(3.0), C_WHITE if hovered else color, false, border_width)
	draw_rect(rect.grow(-2.0), color, false, 1)
	if not label.strip_edges().is_empty():
		var badge_width := clampf(float(label.length()) * 7.0 + 18.0, 52.0, rect.size.x + 18.0)
		var badge := Rect2(rect.position + Vector2((rect.size.x - badge_width) * 0.5, -24.0), Vector2(badge_width, 20.0))
		draw_rect(badge, Color(0.0, 0.0, 0.0, 0.82))
		draw_rect(badge, color, false, 1)
		surface_label_centered(label.to_upper(), badge.grow(-2.0), 10, color)


func _hit_region_hovered_rect(rect: Rect2) -> bool:
	for region_value in hit_regions:
		var region: Dictionary = region_value if typeof(region_value) == TYPE_DICTIONARY else {}
		var hit_rect: Rect2 = region.get("rect", Rect2())
		if hit_rect.intersects(rect):
			if surface_region_hovered(str(region.get("action", "")), int(region.get("index", -1))):
				return true
	return false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	_ensure_surface_sfx_player()
	_ensure_drunk_distortion_overlay()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton:
		if event is InputEventKey and (event as InputEventKey).echo:
			return
		var joy_confirm := event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A
		if event.is_action_pressed("ui_accept") or (joy_confirm and (event as InputEventJoypadButton).pressed):
			_activate_keyboard_hold()
		elif event.is_action_released("ui_accept") or (joy_confirm and not (event as InputEventJoypadButton).pressed):
			_release_keyboard_hold()
		return
	var motion_event := event as InputEventMouseMotion
	if motion_event != null:
		_set_hovered_surface_region(motion_event.position)
		if not captured_surface_action.is_empty() and (motion_event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_queue_or_emit_captured_pointer_move(motion_event.position)
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null:
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if _mouse_duplicates_recent_touch_press(mouse_event.position):
				accept_event()
				return
			_remember_mouse_press(mouse_event.position)
			_activate_surface_at_position(mouse_event.position, mouse_event.double_click)
		elif not mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and not captured_surface_action.is_empty():
			_flush_captured_pointer_move()
			_emit_captured_surface_pointer("end", mouse_event.position)
		return
	var touch_event := event as InputEventScreenTouch
	if touch_event != null:
		if touch_event.pressed:
			if _touch_duplicates_recent_mouse_press(touch_event.position):
				accept_event()
				return
			_remember_touch_press(touch_event.position)
			_activate_surface_at_position(touch_event.position, touch_event.double_tap)
		elif not touch_event.pressed and not captured_surface_action.is_empty():
			_flush_captured_pointer_move()
			_emit_captured_surface_pointer("end", touch_event.position)
		return
	var drag_event := event as InputEventScreenDrag
	if drag_event != null and not captured_surface_action.is_empty():
		_queue_or_emit_captured_pointer_move(drag_event.position)
		return


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


func _activate_surface_at_position(position: Vector2, confirm_requested: bool) -> void:
	var board_point := _screen_to_board(position)
	for i in range(hit_regions.size() - 1, -1, -1):
		var region: Dictionary = hit_regions[i]
		var rect: Rect2 = region.get("rect", Rect2())
		if rect.has_point(board_point):
			var raw_action := str(region.get("action", ""))
			var raw_index := int(region.get("index", -1))
			var resolved := _resolved_surface_action_binding(raw_action, raw_index)
			hovered_surface_action = str(resolved.get("action", raw_action))
			hovered_surface_index = int(resolved.get("index", raw_index))
			var block_reason := _surface_action_block_reason(hovered_surface_action)
			if not block_reason.is_empty():
				surface_action_blocked.emit(hovered_surface_action, block_reason)
				accept_event()
				return
			if bool(region.get("drag", false)):
				captured_surface_action = hovered_surface_action
				captured_surface_index = hovered_surface_index
				captured_surface_board_position = board_point
				captured_surface_keyboard = false
				if is_inside_tree():
					grab_focus()
				surface_pointer_action.emit(captured_surface_action, captured_surface_index, "begin", board_point)
				accept_event()
				return
			var audio_cue := _surface_action_audio_cue(hovered_surface_action)
			if not audio_cue.is_empty():
				surface_play_audio_cue(audio_cue, {
					"action": hovered_surface_action,
					"index": hovered_surface_index,
				}, _surface_audio_authority)
			surface_action.emit(hovered_surface_action, hovered_surface_index, confirm_requested)
			accept_event()
			return


func _emit_captured_surface_pointer(phase: String, screen_position: Vector2) -> void:
	if captured_surface_action.is_empty():
		return
	var action := captured_surface_action
	var index := captured_surface_index
	captured_surface_board_position = _screen_to_board(screen_position)
	surface_pointer_action.emit(action, index, phase, captured_surface_board_position)
	if phase == "end":
		_clear_captured_surface_pointer_state()
	accept_event()


func _activate_keyboard_hold() -> void:
	if not captured_surface_action.is_empty():
		accept_event()
		return
	var selected_region: Dictionary = {}
	for region_value in hit_regions:
		var region: Dictionary = region_value if typeof(region_value) == TYPE_DICTIONARY else {}
		if not bool(region.get("keyboard_hold", false)):
			continue
		if surface_region_hovered(str(region.get("action", "")), int(region.get("index", -1))):
			selected_region = region
			break
		if selected_region.is_empty():
			selected_region = region
	if selected_region.is_empty():
		return
	var raw_action := str(selected_region.get("action", ""))
	var raw_index := int(selected_region.get("index", -1))
	var resolved := _resolved_surface_action_binding(raw_action, raw_index)
	var action := str(resolved.get("action", raw_action))
	var index := int(resolved.get("index", raw_index))
	var block_reason := _surface_action_block_reason(action)
	if not block_reason.is_empty():
		surface_action_blocked.emit(action, block_reason)
		accept_event()
		return
	var rect: Rect2 = selected_region.get("rect", Rect2())
	captured_surface_action = action
	captured_surface_index = index
	captured_surface_board_position = rect.get_center()
	captured_surface_keyboard = true
	if is_inside_tree():
		grab_focus()
	surface_pointer_action.emit(action, index, "begin", captured_surface_board_position)
	accept_event()


func _release_keyboard_hold() -> void:
	if not captured_surface_keyboard or captured_surface_action.is_empty():
		return
	surface_pointer_action.emit(captured_surface_action, captured_surface_index, "end", captured_surface_board_position)
	_clear_captured_surface_pointer_state()
	accept_event()


func _cancel_captured_surface_pointer() -> void:
	if captured_surface_action.is_empty():
		return
	surface_pointer_action.emit(captured_surface_action, captured_surface_index, "cancel", captured_surface_board_position)
	_clear_captured_surface_pointer_state()


func _clear_captured_surface_pointer_state() -> void:
	captured_surface_action = ""
	captured_surface_index = -1
	captured_surface_board_position = Vector2.ZERO
	captured_surface_keyboard = false
	captured_pointer_move_pending = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_EXIT:
		_cancel_captured_surface_pointer()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready() and not is_visible_in_tree():
		_cancel_captured_surface_pointer()


func _queue_or_emit_captured_pointer_move(screen_position: Vector2) -> void:
	if bool(state.get("surface_pointer_coalesce_moves", false)):
		captured_pointer_move_position = screen_position
		captured_pointer_move_pending = true
		accept_event()
		return
	_emit_captured_surface_pointer("move", screen_position)


func _flush_captured_pointer_move() -> void:
	if not captured_pointer_move_pending or captured_surface_action.is_empty():
		return
	captured_pointer_move_pending = false
	_emit_captured_surface_pointer("move", captured_pointer_move_position)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_flush_captured_pointer_move()
	if transient_surface_loop_deadline_msec > 0 and Time.get_ticks_msec() >= transient_surface_loop_deadline_msec:
		surface_stop_audio_loop(transient_surface_loop_id, _surface_audio_authority)
	# Reduced motion freezes presentation clocks and redraws, not state-driven
	# audio. Sync before the visual early return so completed actions still land
	# their terminal cues without advancing any presentation state.
	_sync_surface_audio()
	if reduce_motion:
		flicker = 0.0
		surface_render_elapsed_sec = 0.0
		continuous_redraw_was_active = false
		surface_animation_redraw_accumulator = 0.0
		return
	var clamped_delta := maxf(0.0, delta)
	flicker += clamped_delta
	surface_render_elapsed_sec += clamped_delta
	# Presentation must remain live while a tutorial conversation freezes game
	# logic. Channels opt into this clock explicitly; the simulation clock below
	# still stops, so timers and automated game actions cannot advance.
	surface_presentation_clock_msec += clamped_delta * 1000.0
	if not environment_activity_paused:
		surface_simulation_clock_msec += clamped_delta * 1000.0
	_schedule_surface_animation_redraws(clamped_delta)


func _schedule_surface_animation_redraws(delta: float) -> void:
	var redraw_demand := _surface_animation_redraw_demand()
	var main_redraw := bool(redraw_demand.get("main", false))
	if main_redraw:
		perf_surface_animation_scheduler_elapsed_sec += maxf(0.0, delta)
		if _surface_animation_redraw_due(delta):
			_prepare_surface_render_state()
			queue_redraw()
	elif continuous_redraw_was_active:
		surface_animation_redraw_accumulator = 0.0
		_prepare_surface_render_state()
		queue_redraw()
	else:
		surface_animation_redraw_accumulator = 0.0
	continuous_redraw_was_active = main_redraw


func _draw() -> void:
	var draw_started_usec := Time.get_ticks_usec()
	# Safety net for non-scheduler redraw sources (resize/theme/editor). Ordinary
	# realtime presentation prepares before queueing the frame above, keeping this
	# call a cheap dirty-bit check on the measured path.
	_prepare_surface_render_state()
	# Surface renderers may opt into one conditional batch material for a draw;
	# always clear it before dispatch so materials cannot leak between games.
	material = null
	hit_regions.clear()
	surface_text_protected_rects.clear()
	active_design_scale = Vector2.ONE
	active_design_offset = Vector2.ZERO
	design_space_active = false
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(Vector2.ZERO, size), C_DARK)
	_scale_canvas()
	var board_size := _active_board_size()
	var renderer_owns_board_background := uses_foundation_snapshot and bool(state.get("surface_renderer_opaque", false))
	if not renderer_owns_board_background:
		draw_rect(Rect2(Vector2.ZERO, board_size), C_DARK)
		if use_external_background and background_texture != null:
			draw_texture_rect(background_texture, Rect2(Vector2.ZERO, board_size), false)
		else:
			for y in range(0, int(ceil(board_size.y)), 16):
				draw_rect(Rect2(0, y, board_size.x, 16), C_DARK_2 if (y / 16) % 2 == 0 else C_PANEL)
	var rendered := false
	if surface_game_module != null and uses_foundation_snapshot:
		rendered = bool(surface_game_module.draw_surface(self, state, {
			"selected_view_index": selected_view_index,
			"surface_dynamic_overlay_active": _surface_dynamic_overlay_channel_active(),
		}))
	surface_end_design_space()
	if not rendered:
		_draw_foundation_result()
	_draw_foundation_result_burst()
	_draw_pressure_overlay()
	_draw_drunk_overlay()
	_draw_foundation_play_overlay()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_update_drunk_distortion_protected_rects()
	_ensure_snapshot_proxy_hit_regions()
	_record_draw_performance(draw_started_usec)


func _ensure_surface_sfx_player() -> void:
	if surface_sfx_player != null:
		return
	surface_sfx_player = SfxPlayerScript.new()
	if surface_sfx_player.has_method("bind_surface_audio_authority"):
		surface_sfx_player.call("bind_surface_audio_authority", _surface_audio_authority)
	if surface_sfx_player.has_signal("music_cue_requested"):
		surface_sfx_player.music_cue_requested.connect(_on_surface_sfx_music_cue)
	add_child(surface_sfx_player)


func _screen_effect_overlay_needs_redraw() -> bool:
	if int(state.get("suspicion_level", 0)) > 0:
		return true
	if drunk_distortion_overlay != null and drunk_distortion_overlay.visible:
		return true
	if drunk_effect_mode == "classic" and int(state.get("drunk_level", 0)) >= 12:
		return true
	return false


func _surface_dynamic_overlay_channel_active() -> bool:
	var channels_value: Variant = state.get("surface_dynamic_overlay_channels", [])
	if typeof(channels_value) != TYPE_ARRAY:
		return false
	var channels: Array = channels_value as Array
	for value in channels:
		var channel_id := str(value)
		if not channel_id.is_empty() and surface_animation_active(channel_id):
			return true
	return false


func _on_surface_sfx_music_cue(cue_id: String, context: Dictionary) -> void:
	surface_music_cue.emit(cue_id, context)


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
		var level := clampi(int(state.get("drunk_level", 0)), 0, 100)
		drunk_distortion_overlay.set_drunk_level(level if drunk_effect_mode == "distortion" else 0)


func _normalized_drunk_effect_mode(value: String) -> String:
	return "classic" if value == "classic" else "distortion"


func _update_surface_animation_channels() -> void:
	var next_ids := {}
	var now_msec := Time.get_ticks_msec()
	for channel_value in _dictionary_array(state.get("surface_animation_channels", [])):
		var channel: Dictionary = channel_value
		var channel_id := str(channel.get("id", ""))
		if channel_id.is_empty():
			continue
		next_ids[channel_id] = true
		var incoming_active_id := str(channel.get("active_id", ""))
		var incoming_active := bool(channel.get("active", not incoming_active_id.is_empty()))
		var incoming_started := int(channel.get("started_msec", 0))
		var restart_on_id_change := bool(channel.get("restart_on_active_id_change", true))
		var current := _copy_dict(surface_animation_channels.get(channel_id, {}))
		var was_active := _surface_channel_record_active(current)
		var current_active_id := str(current.get("active_id", ""))
		if current.is_empty() or (restart_on_id_change and current_active_id != incoming_active_id):
			current = channel.duplicate(true)
			current["started_msec"] = incoming_started if incoming_started > 0 else now_msec
		else:
			current["active_id"] = incoming_active_id
			current["duration_msec"] = maxi(0, int(channel.get("duration_msec", current.get("duration_msec", 0))))
			# The incoming offset is authoritative. A changed cumulative resume
			# offset rebases the UI-local clock so elapsed time is not counted twice;
			# omission explicitly clears a previously transient resume projection.
			var current_offset := maxi(0, int(current.get("elapsed_offset_msec", 0)))
			var incoming_offset := maxi(0, int(channel.get("elapsed_offset_msec", 0)))
			current["elapsed_offset_msec"] = incoming_offset
			current["metadata"] = _copy_dict(channel.get("metadata", current.get("metadata", {})))
			current["clock_source"] = str(channel.get("clock_source", current.get("clock_source", "realtime")))
			if incoming_started > 0:
				current["started_msec"] = incoming_started
			elif incoming_offset != current_offset:
				current["started_msec"] = now_msec
		current["id"] = channel_id
		current["active"] = incoming_active
		current["restart_on_active_id_change"] = restart_on_id_change
		if not current.has("metadata"):
			current["metadata"] = {}
		surface_animation_channels[channel_id] = current
		var is_active := _surface_channel_record_active(current)
		if was_active and not is_active:
			_mark_surface_animation_handoff(now_msec)
	for existing_id in surface_animation_channels.keys():
		if not next_ids.has(str(existing_id)):
			if _surface_channel_record_active(_copy_dict(surface_animation_channels.get(existing_id, {}))):
				_mark_surface_animation_handoff(now_msec)
			surface_animation_channels.erase(existing_id)


func _sync_surface_audio() -> void:
	var audio := _surface_audio_spec()
	var profile_id := str(audio.get("profile_id", ""))
	if profile_id != last_audio_profile_id:
		if surface_sfx_player != null:
			surface_sfx_player.stop_all()
		last_audio_profile_id = profile_id
	if profile_id.is_empty():
		return
	var sync_spec := _copy_dict(audio.get("state_sync", {}))
	if sync_spec.is_empty():
		return
	_ensure_surface_sfx_player()
	if surface_sfx_player.has_method("prewarm_surface_profile"):
		surface_sfx_player.call("prewarm_surface_profile", profile_id, _surface_audio_authority)
	surface_sfx_player.sync_surface_state(state, sync_spec, _surface_audio_timing(sync_spec), _surface_audio_authority)


func _surface_audio_timing(sync_spec: Dictionary) -> Dictionary:
	var timing: Dictionary = {}
	for raw_key in sync_spec.keys():
		var key := str(raw_key)
		if key != "animation_channel" and not key.ends_with("_channel"):
			continue
		var channel_id := str(sync_spec.get(key, ""))
		timing[key] = {
			"channel_id": channel_id,
			"elapsed": surface_elapsed(channel_id),
			"active": surface_animation_active(channel_id),
			"active_id": surface_animation_active_id(channel_id),
		}
	return timing


func _needs_continuous_redraw() -> bool:
	return bool(_surface_animation_redraw_demand().get("main", false))


func _surface_animation_liveness_active() -> bool:
	var demand := _surface_animation_redraw_demand()
	return bool(demand.get("main", false))


func _surface_animation_redraw_demand() -> Dictionary:
	var main := _surface_main_animation_redraw_active()
	return {
		"main": main,
		"handoff": _surface_animation_handoff_active(),
	}


func _surface_main_animation_redraw_active() -> bool:
	if reduce_motion:
		return false
	for channel_id in surface_animation_channels.keys():
		var normalized_id := str(channel_id)
		if surface_animation_active(normalized_id):
			return true
	if int(state.get("suspicion_level", 0)) > 0:
		return true
	if drunk_distortion_overlay != null and drunk_distortion_overlay.visible:
		return true
	if drunk_effect_mode == "classic" and int(state.get("drunk_level", 0)) >= 12:
		return true
	if _surface_animation_handoff_active():
		return true
	return bool(state.get("surface_animates_idle", false))


func _surface_channel_record_active(channel: Dictionary) -> bool:
	return bool(channel.get("active", false)) and not str(channel.get("active_id", "")).is_empty()


func _mark_surface_animation_handoff(now_msec: int) -> void:
	surface_animation_handoff_until_msec = maxi(surface_animation_handoff_until_msec, now_msec + 250)


func _surface_animation_handoff_active() -> bool:
	return surface_animation_handoff_until_msec > Time.get_ticks_msec()


func _surface_animation_redraw_due(delta: float) -> bool:
	surface_animation_redraw_accumulator += maxf(0.0, delta)
	var target_interval := _web_idle_animation_interval() if surface_low_detail_idle() else SURFACE_ANIMATION_INTERVAL_SEC
	if surface_animation_redraw_accumulator < target_interval:
		return false
	surface_animation_redraw_accumulator = minf(
		surface_animation_redraw_accumulator - target_interval,
		target_interval
	)
	surface_animation_redraw_count += 1
	return true


func _web_idle_animation_interval() -> float:
	return 1.0 / _requested_web_idle_animation_fps()


func _requested_web_idle_animation_fps() -> float:
	return clampf(float(state.get("surface_web_idle_animation_fps", DEFAULT_WEB_IDLE_ANIMATION_FPS)), DEFAULT_WEB_IDLE_ANIMATION_FPS, SURFACE_ANIMATION_FPS)


func _scale_canvas() -> void:
	var scale := _board_scale()
	draw_set_transform(_board_offset(scale), 0.0, Vector2(scale, scale))


func _board_scale() -> float:
	if size.x <= 0.0 or size.y <= 0.0:
		return 1.0
	var board_size := _active_board_size()
	return minf(size.x / maxf(1.0, board_size.x), size.y / maxf(1.0, board_size.y))


func _board_offset(scale: float) -> Vector2:
	if scale <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	var rendered_size := _active_board_size() * scale
	return (size - rendered_size) * 0.5


func _active_board_size() -> Vector2:
	if _surface_renderer() == "slot_machine" or _surface_renderer() == "card_machine":
		return SLOT_BOARD_SIZE
	return Vector2(BOARD_SIZE)


func _active_board_aspect_ratio() -> float:
	var board_size := _active_board_size()
	if board_size.y <= 0.0:
		return 1.0
	return board_size.x / board_size.y


func _design_rect_to_board(rect: Rect2) -> Rect2:
	if not design_space_active:
		return rect
	return Rect2(active_design_offset + (rect.position + active_design_local_offset) * active_design_scale, rect.size * active_design_scale)


func _touch_hit_rect(rect: Rect2, expand_touch_hit: bool) -> Rect2:
	var board_rect := _design_rect_to_board(rect)
	if not expand_touch_hit:
		return board_rect
	var min_size := SmallScreenPolicyScript.surface_hit_size(small_screen_mode, MIN_SURFACE_TOUCH_HIT_SIZE)
	var next_size := Vector2(maxf(board_rect.size.x, min_size.x), maxf(board_rect.size.y, min_size.y))
	var board_size := _active_board_size()
	next_size.x = minf(next_size.x, board_size.x)
	next_size.y = minf(next_size.y, board_size.y)
	var next_pos := board_rect.get_center() - next_size * 0.5
	next_pos.x = clampf(next_pos.x, 0.0, maxf(0.0, board_size.x - next_size.x))
	next_pos.y = clampf(next_pos.y, 0.0, maxf(0.0, board_size.y - next_size.y))
	return Rect2(next_pos, next_size)


func _hit_rect_from_source(source: Variant) -> Rect2:
	var rect_value: Variant = source
	if typeof(source) == TYPE_DICTIONARY:
		rect_value = (source as Dictionary).get("rect", {})
	if typeof(rect_value) == TYPE_RECT2:
		return _design_rect_to_board(rect_value as Rect2)
	if typeof(rect_value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = rect_value
	var x := float(data.get("x", data.get("left", 0.0)))
	var y := float(data.get("y", data.get("top", 0.0)))
	var width := float(data.get("w", data.get("width", -1.0)))
	var height := float(data.get("h", data.get("height", -1.0)))
	if width < 0.0 and data.has("right"):
		width = float(data.get("right", x)) - x
	if height < 0.0 and data.has("bottom"):
		height = float(data.get("bottom", y)) - y
	return _design_rect_to_board(Rect2(Vector2(x, y), Vector2(maxf(0.0, width), maxf(0.0, height))))


func _screen_to_board(point: Vector2) -> Vector2:
	var scale := _board_scale()
	if scale <= 0.0:
		return point
	return (point - _board_offset(scale)) / scale


func _board_to_screen(point: Vector2) -> Vector2:
	var scale := _board_scale()
	return _board_offset(scale) + point * scale


func _board_rect_to_screen_rect(rect: Rect2) -> Rect2:
	var scale := _board_scale()
	return Rect2(_board_offset(scale) + rect.position * scale, rect.size * scale)


func _update_drunk_distortion_protected_rects() -> void:
	if drunk_distortion_overlay == null or not drunk_distortion_overlay.visible:
		return
	var protected_rects: Array = []
	for rect in _surface_ui_protected_board_rects():
		if typeof(rect) == TYPE_RECT2:
			protected_rects.append(_board_rect_to_screen_rect((rect as Rect2).grow(5.0)))
	drunk_distortion_overlay.set_ui_protected_rects(protected_rects)


func _surface_ui_protected_board_rects() -> Array:
	var protected_rects: Array = []
	for rect in surface_text_protected_rects:
		if typeof(rect) == TYPE_RECT2:
			protected_rects.append(rect)
	for rect in _surface_state_rects("surface_ui_protected_regions"):
		protected_rects.append(rect)
	for rect in _surface_state_rects("surface_hover_ui_protected_regions", true):
		protected_rects.append(rect)
	for region in hit_regions:
		if typeof(region) != TYPE_DICTIONARY:
			continue
		var region_rect: Rect2 = (region as Dictionary).get("rect", Rect2())
		if region_rect.size.x > 0.0 and region_rect.size.y > 0.0:
			protected_rects.append(region_rect)
	if bool(state.get("surface_controls_native", false)):
		protected_rects.append(Rect2(776, 22, 86, 34))
		if not bool(state.get("surface_embeds_outcomes", false)) and not bool(state.get("surface_suppresses_game_result_burst", false)) and not str(state.get("result_message", "")).is_empty():
			protected_rects.append(Rect2(560, 266, 316, 36))
	else:
		protected_rects.append(Rect2(22, 248, 856, 72))
	if bool(state.get("has_recent_outcome", false)) and not bool(state.get("surface_embeds_outcomes", false)) and not bool(state.get("surface_suppresses_game_result_burst", false)):
		protected_rects.append(Rect2(250, 70, 400, 54))
	return protected_rects


func _surface_state_rects(key: String, hover_filtered: bool = false) -> Array:
	var rects: Array = []
	for region in _dictionary_array(state.get(key, [])):
		if hover_filtered and not _surface_hover_region_matches(region):
			continue
		var rect := _surface_state_rect(region)
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			rects.append(rect)
	return rects


func _surface_hover_region_matches(region: Dictionary) -> bool:
	var action := str(region.get("action", ""))
	if action.is_empty() or hovered_surface_action != action:
		return false
	var index := int(region.get("index", -1))
	return index < 0 or hovered_surface_index == index


func _surface_state_rect(region: Dictionary) -> Rect2:
	var x := float(region.get("x", region.get("left", 0.0)))
	var y := float(region.get("y", region.get("top", 0.0)))
	var width := float(region.get("w", region.get("width", -1.0)))
	var height := float(region.get("h", region.get("height", -1.0)))
	if width < 0.0 and region.has("right"):
		width = float(region.get("right", x)) - x
	if height < 0.0 and region.has("bottom"):
		height = float(region.get("bottom", y)) - y
	return Rect2(Vector2(x, y), Vector2(maxf(0.0, width), maxf(0.0, height)))


func _resolved_surface_action_binding(action: String, index: int) -> Dictionary:
	var bindings: Dictionary = state.get("surface_action_bindings", {})
	var binding_value: Variant = bindings.get(action, {})
	var binding_missing := typeof(binding_value) != TYPE_DICTIONARY or (binding_value as Dictionary).is_empty()
	if binding_missing and (action == "surface_legal" or action == "surface_cheat"):
		var kind := "legal" if action == "surface_legal" else "cheat"
		binding_value = bindings.get(kind, {})
	if typeof(binding_value) != TYPE_DICTIONARY:
		return {"action": action, "index": index}
	var binding: Dictionary = binding_value
	var resolved_action := str(binding.get("action", action))
	if resolved_action.is_empty():
		resolved_action = action
	return {
		"action": resolved_action,
		"index": int(binding.get("index", index)),
	}


func _set_hovered_surface_region(local_position: Vector2) -> void:
	var board_point := _screen_to_board(local_position)
	for i in range(hit_regions.size() - 1, -1, -1):
		var region: Dictionary = hit_regions[i]
		var rect: Rect2 = region.get("rect", Rect2())
		if rect.has_point(board_point):
			var next_action := str(region.get("action", ""))
			var next_index := int(region.get("index", -1))
			if hovered_surface_action == next_action and hovered_surface_index == next_index:
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				return
			hovered_surface_action = next_action
			hovered_surface_index = next_index
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			queue_redraw()
			if bool(region.get("activate_on_hover", false)):
				var block_reason := _surface_action_block_reason(next_action)
				if not block_reason.is_empty():
					surface_action_blocked.emit(next_action, block_reason)
					return
				var audio_cue := _surface_action_audio_cue(next_action)
				if not audio_cue.is_empty():
					surface_play_audio_cue(audio_cue, {"action": next_action, "index": next_index}, _surface_audio_authority)
				surface_action.emit(next_action, next_index, false)
			return
	if hovered_surface_action.is_empty():
		return
	hovered_surface_action = ""
	hovered_surface_index = -1
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()


func _hit_region_snapshots() -> Array:
	var snapshots: Array = []
	for region in hit_regions:
		if typeof(region) != TYPE_DICTIONARY:
			continue
		var rect: Rect2 = region.get("rect", Rect2())
		snapshots.append({
			"action": str(region.get("action", "")),
			"index": int(region.get("index", -1)),
			"rect": rect,
		})
	return snapshots


func _ensure_snapshot_proxy_hit_regions() -> void:
	if not uses_foundation_snapshot or surface_game_module != null:
		return
	if _surface_renderer() == "slot_machine":
		return
	if bool(state.get("has_valid_stake", false)):
		_add_proxy_hit_region(Rect2(98, 258, 26, 42), "surface_stake_down", -1)
		_add_proxy_hit_region(Rect2(128, 258, 26, 42), "surface_stake_up", -1)
		_add_proxy_hit_region(Rect2(158, 258, 44, 42), "surface_stake_max", -1)
	if not _dictionary_array(state.get("legal_actions", [])).is_empty():
		_add_proxy_hit_region(Rect2(212, 258, 150, 42), "surface_legal", 0)
	if not _dictionary_array(state.get("cheat_actions", [])).is_empty():
		_add_proxy_hit_region(Rect2(372, 258, 174, 42), "surface_cheat", 0)


func _add_proxy_hit_region(rect: Rect2, action: String, index: int = -1) -> void:
	if _has_hit_region(action, index):
		return
	hit_regions.append({"rect": rect, "action": action, "index": index})


func _has_hit_region(action: String, index: int = -1) -> bool:
	for region in hit_regions:
		if typeof(region) != TYPE_DICTIONARY:
			continue
		if str((region as Dictionary).get("action", "")) != action:
			continue
		if index >= 0 and int((region as Dictionary).get("index", -1)) != index:
			continue
		return true
	return false


func _rect_snapshot(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"w": rect.size.x,
		"h": rect.size.y,
	}


func _vector_snapshot(value: Vector2) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y,
	}


func _surface_renderer() -> String:
	if uses_foundation_snapshot:
		return str(state.get("surface_renderer", "result"))
	return str(state.get("surface_renderer", game_id))


func _surface_life() -> String:
	return str(state.get("surface_life", _surface_renderer()))


func _surface_cast() -> String:
	return str(state.get("surface_cast", "none"))


func _surface_animation_channel(channel_id: String) -> Dictionary:
	if channel_id.is_empty() or not surface_animation_channels.has(channel_id):
		return {}
	var value: Variant = surface_animation_channels.get(channel_id, {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _surface_animation_status_snapshot() -> Dictionary:
	var snapshot := {}
	for channel_id in surface_animation_channels.keys():
		var normalized_id := str(channel_id)
		var channel := _surface_animation_channel(normalized_id)
		snapshot[normalized_id] = {
			"id": normalized_id,
			"active_id": str(channel.get("active_id", "")),
			"active": surface_animation_active(normalized_id),
			"elapsed": surface_elapsed(normalized_id),
			"progress": surface_animation_progress(normalized_id),
			"duration": surface_animation_duration(normalized_id),
			"time_scale": drunk_time_scale,
			"duration_msec": int(channel.get("duration_msec", 0)),
			"started_msec": int(channel.get("started_msec", 0)),
			"elapsed_offset_msec": int(channel.get("elapsed_offset_msec", 0)),
			"metadata": _copy_dict(channel.get("metadata", {})),
		}
	return snapshot


func _surface_action_blocked(action: String) -> bool:
	return not _surface_action_block_reason(action).is_empty()


func _surface_action_block_reason(action: String) -> String:
	for block_value in _dictionary_array(state.get("surface_action_blocks", [])):
		var block: Dictionary = block_value
		var blocked_action := str(block.get("action", ""))
		if blocked_action != action:
			var blocked_actions := _string_array(block.get("actions", []))
			if not blocked_actions.has(action):
				continue
		var channel_id := str(block.get("while_animation", ""))
		if not channel_id.is_empty() and not surface_animation_active(channel_id):
			continue
		var unless_flag := str(block.get("unless_state_flag", ""))
		if not unless_flag.is_empty() and bool(state.get(unless_flag, false)):
			continue
		var reason := str(block.get("reason", ""))
		return reason if not reason.is_empty() else "That control is waiting on the current reveal. Let the table finish."
	return ""


func _surface_audio_spec() -> Dictionary:
	var audio := _copy_dict(state.get("surface_audio", {}))
	if not audio.has("profile_id"):
		audio["profile_id"] = ""
	if not audio.has("action_cues"):
		audio["action_cues"] = {}
	if not audio.has("state_sync"):
		audio["state_sync"] = {}
	return audio


func _surface_action_audio_cue(action: String) -> String:
	var audio := _surface_audio_spec()
	var action_cues := _copy_dict(audio.get("action_cues", {}))
	if not action_cues.has(action):
		return ""
	var cue_value: Variant = action_cues.get(action, "")
	if typeof(cue_value) == TYPE_DICTIONARY:
		return str((cue_value as Dictionary).get("cue_id", ""))
	return str(cue_value)


func _draw_foundation_result() -> void:
	var title := str(state.get("display_name", "Foundation Game"))
	surface_title(title.to_upper().left(28), Vector2(260, 46), C_CYAN)
	draw_rect(Rect2(142, 96, 616, 168), Color("#101022"))
	draw_rect(Rect2(154, 108, 592, 144), Color("#06060d"))
	surface_label("BANKROLL " + str(state.get("bankroll", 0)), Vector2(184, 136), 20, C_YELLOW)
	surface_label("HEAT " + str(state.get("suspicion_level", 0)), Vector2(520, 136), 20, C_PINK_2)
	var message := str(state.get("result_message", state.get("message", "")))
	if message.is_empty():
		message = "Choose an action to resolve the game."
	surface_label(message.left(74), Vector2(184, 178), 16, C_SOFT)
	var bankroll_delta := int(state.get("bankroll_delta", 0))
	var suspicion_delta := int(state.get("suspicion_delta", 0))
	surface_label("BANKROLL %+d" % bankroll_delta, Vector2(268, 226), 18, C_TEAL if bankroll_delta >= 0 else C_ORANGE)
	surface_label("HEAT %+d" % suspicion_delta, Vector2(510, 226), 18, C_PINK if suspicion_delta > 0 else C_CYAN)


func _draw_foundation_play_overlay() -> void:
	if not uses_foundation_snapshot:
		return
	if _surface_renderer() == "slot_machine":
		return
	if bool(state.get("surface_controls_native", false)):
		var back_rect := Rect2(776, 22, 86, 34)
		if _surface_renderer() == "card_machine":
			back_rect = Rect2(806, 22, 86, 34)
		_draw_surface_back_control(back_rect)
		if surface_game_module == null:
			_draw_foundation_control_strip(Rect2(22, 248, 856, 72), true)
			return
		if bool(state.get("surface_embeds_outcomes", false)) or bool(state.get("surface_suppresses_game_result_burst", false)):
			return
		var message := str(state.get("result_message", ""))
		if not message.is_empty():
			draw_rect(Rect2(560, 266, 316, 36), Color(0.02, 0.02, 0.05, 0.76))
			draw_rect(Rect2(560, 266, 316, 36), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.22), false, 1)
			var bankroll_delta := int(state.get("bankroll_delta", 0))
			var suspicion_delta := int(state.get("suspicion_delta", 0))
			var result_text := message.left(32)
			if bankroll_delta != 0 or suspicion_delta != 0:
				result_text = "%s  $%+d / heat %+d" % [result_text.left(18), bankroll_delta, suspicion_delta]
			surface_label(result_text.left(34), Vector2(572, 289), 14, C_WHITE)
		return
	var panel := Rect2(22, 248, 856, 72)
	_draw_foundation_control_strip(panel, true)


func _draw_foundation_control_strip(panel: Rect2, include_back: bool) -> void:
	draw_rect(panel, Color(0.02, 0.02, 0.05, 0.84))
	draw_rect(panel, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.28), false, 1)
	var stake_text := "Stake -"
	if bool(state.get("has_valid_stake", false)):
		stake_text = "Stake %d" % int(state.get("selected_stake", 0))
	surface_label(stake_text, Vector2(38, 280), 15, C_YELLOW)
	surface_draw_stake_control(Rect2(98, 258, 26, 42), "-", bool(state.get("has_valid_stake", false)), "surface_stake_down")
	surface_draw_stake_control(Rect2(128, 258, 26, 42), "+", bool(state.get("has_valid_stake", false)), "surface_stake_up")
	surface_draw_stake_control(Rect2(158, 258, 44, 42), "MAX", bool(state.get("has_valid_stake", false)), "surface_stake_max")
	var legal_actions := _dictionary_array(state.get("legal_actions", []))
	var cheat_actions := _dictionary_array(state.get("cheat_actions", []))
	var legal_action := _first_dictionary(legal_actions)
	var cheat_action := _first_dictionary(cheat_actions)
	_draw_surface_action_tile(Rect2(212, 258, 150, 42), "Safe: %s" % _surface_action_label(legal_action, "Safe action"), _surface_action_summary(legal_action, "legal"), "legal", not legal_action.is_empty(), _surface_action_selected("legal", legal_action), "surface_legal", 0)
	_draw_surface_action_tile(Rect2(372, 258, 174, 42), "Risk: %s" % _surface_action_label(cheat_action, "Risky move"), _surface_action_summary(cheat_action, "cheat"), "cheat", not cheat_action.is_empty(), _surface_action_selected("cheat", cheat_action), "surface_cheat", 0)
	if include_back:
		_draw_surface_back_control(Rect2(776, 258, 86, 42))
	surface_label("Click surface controls. Click selected action again to resolve.", Vector2(38, 314), 12, C_SOFT)
	var message := str(state.get("result_message", ""))
	if message.is_empty():
		message = "Resolve an action to see what happens."
	var bankroll_delta := int(state.get("bankroll_delta", 0))
	var suspicion_delta := int(state.get("suspicion_delta", 0))
	var result_text := message.left(30)
	if bankroll_delta != 0 or suspicion_delta != 0:
		result_text = "%s  $%+d / heat %+d" % [result_text.left(20), bankroll_delta, suspicion_delta]
	surface_label(result_text.left(28), Vector2(564, 280), 14, C_WHITE)


func _draw_surface_back_control(rect: Rect2) -> void:
	var hovered := surface_region_hovered("surface_back")
	var fill := Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.24 if hovered else 0.14)
	draw_rect(rect, fill)
	draw_rect(rect, C_WHITE if hovered else C_CYAN, false, 2 if hovered else 1)
	surface_label("LEAVE", rect.position + Vector2(14, 23), 16, C_CYAN)
	if hovered:
		surface_draw_ready_badge(rect, "BACK")
	surface_add_hit(rect, "surface_back")


func _draw_surface_action_tile(rect: Rect2, label: String, summary: String, kind: String, enabled: bool, selected: bool, action: String, index: int) -> void:
	var accent := C_PINK_2 if kind == "cheat" else C_TEAL
	var hovered := surface_region_hovered(action, index)
	var fill := Color(accent.r, accent.g, accent.b, 0.22) if selected else Color(0.08, 0.09, 0.14, 0.88)
	if hovered and not selected:
		fill = Color(accent.r, accent.g, accent.b, 0.16)
	if not enabled:
		fill = Color(0.04, 0.04, 0.07, 0.74)
	draw_rect(rect, fill)
	draw_rect(rect, C_WHITE if hovered and enabled else accent if enabled else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.28), false, 2 if selected or hovered else 1)
	surface_label(label.left(21), rect.position + Vector2(10, 18), 13, accent if enabled else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.52))
	if not summary.is_empty():
		surface_label(summary.left(30), rect.position + Vector2(10, 34), 10, C_SOFT if enabled else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.42))
	if selected:
		surface_draw_ready_badge(rect, "CLICK AGAIN")
	elif hovered and enabled:
		surface_draw_ready_badge(rect, "CLICK")
	if enabled:
		surface_add_hit(rect, action, index)


func _draw_foundation_result_burst() -> void:
	if not uses_foundation_snapshot:
		return
	if not bool(state.get("has_recent_outcome", false)):
		return
	if bool(state.get("surface_embeds_outcomes", false)) or bool(state.get("surface_suppresses_game_result_burst", false)):
		return
	var message := str(state.get("outcome_message", state.get("result_message", "")))
	var bankroll_delta := int(state.get("outcome_bankroll_delta", state.get("bankroll_delta", 0)))
	var suspicion_delta := int(state.get("outcome_suspicion_delta", state.get("suspicion_delta", 0)))
	if message.is_empty() and bankroll_delta == 0 and suspicion_delta == 0:
		return
	var accent := C_CYAN
	if suspicion_delta > 0:
		accent = C_PINK_2
	elif bankroll_delta < 0:
		accent = C_ORANGE
	elif bankroll_delta > 0:
		accent = C_TEAL
	var pulse := 0.28 + absf(sin(flicker * 5.0)) * 0.18
	var panel := Rect2(250, 70, 400, 54)
	draw_rect(panel, Color(0.0, 0.0, 0.0, 0.72))
	draw_rect(panel, Color(accent.r, accent.g, accent.b, 0.72), false, 2)
	draw_rect(Rect2(panel.position - Vector2(6, 6), panel.size + Vector2(12, 12)), Color(accent.r, accent.g, accent.b, pulse), false, 2)
	var delta_text := ""
	if bankroll_delta != 0:
		delta_text += "Bankroll %+d" % bankroll_delta
	if suspicion_delta != 0:
		if not delta_text.is_empty():
			delta_text += "  "
		delta_text += "Heat %+d" % suspicion_delta
	if delta_text.is_empty():
		delta_text = "Outcome"
	surface_label(message.left(44), panel.position + Vector2(12, 22), 13, C_WHITE)
	surface_label(delta_text.left(36), panel.position + Vector2(12, 42), 12, accent)


func _draw_pressure_overlay() -> void:
	var level := clampi(int(state.get("suspicion_level", 0)), 0, 100)
	HeatFeedbackVisualsScript.draw_police_pressure(self, _active_board_size(), level, 0.0 if reduce_motion else flicker)


func pressure_overlay_debug_profile(elapsed_sec: float = -1.0) -> Dictionary:
	var sample_time := (0.0 if reduce_motion else flicker) if elapsed_sec < 0.0 else maxf(0.0, elapsed_sec)
	return HeatFeedbackVisualsScript.police_pressure_profile(int(state.get("suspicion_level", 0)), sample_time)


func _draw_drunk_overlay() -> void:
	_draw_drunk_overlay_on(self)


func _draw_drunk_overlay_on(canvas: Control) -> void:
	if drunk_effect_mode != "classic":
		return
	var level := clampi(int(state.get("drunk_level", 0)), 0, 100)
	if level < 12:
		return
	var board_size := _active_board_size()
	var normalized := clampf(float(level - 12) / 88.0, 0.0, 1.0)
	var alpha := 0.018 + pow(normalized, 1.25) * 0.070
	canvas.draw_rect(Rect2(Vector2.ZERO, board_size), Color(0.08, 0.04, 0.13, alpha))
	var spacing := 18
	var phase := int(fmod(flicker * 10.0, float(spacing)))
	for y in range(-spacing + phase, int(ceil(board_size.y)) + spacing, spacing):
		var color := C_PINK_2 if int(y / spacing) % 2 == 0 else C_CYAN
		canvas.draw_rect(Rect2(0, y, board_size.x, 2), Color(color.r, color.g, color.b, alpha * 1.55))
		if level >= 45:
			canvas.draw_rect(Rect2(0, y + 6, board_size.x, 1), Color(color.r, color.g, color.b, alpha * 0.85))


func _surface_action_selected(kind: String, action: Dictionary) -> bool:
	if action.is_empty():
		return false
	return str(state.get("selected_action_kind", "")) == kind and str(state.get("selected_action_id", "")) == str(action.get("id", ""))


func _surface_action_label(action: Dictionary, fallback: String) -> String:
	if action.is_empty():
		return fallback
	var label := str(action.get("label", ""))
	if label.is_empty():
		label = str(action.get("id", fallback)).replace("_", " ").capitalize()
	return label


func _surface_action_summary(action: Dictionary, kind: String) -> String:
	if action.is_empty():
		return ""
	var summary := str(action.get("summary", "")).strip_edges()
	if not summary.is_empty():
		return summary
	var parts: Array = []
	var win_chance := int(action.get("win_chance", 0))
	if win_chance > 0:
		parts.append("Win %d%%" % win_chance)
	var payout_mult := int(action.get("payout_mult", 0))
	if payout_mult > 0:
		parts.append("Pay %dx" % payout_mult)
	var heat := int(action.get("suspicion_delta", 0))
	if heat != 0:
		parts.append("heat %+d" % heat)
	elif kind == "cheat":
		parts.append("heat risk")
	return " / ".join(parts)


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append(entry)
	return result


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var text := str(entry)
		if not text.is_empty():
			result.append(text)
	return result


func _vector_from_dict(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if typeof(value) != TYPE_DICTIONARY:
		return fallback
	var data: Dictionary = value as Dictionary
	return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _first_dictionary(value: Array) -> Dictionary:
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			return entry
	return {}
