extends SceneTree

# Game-surface performance regression probe. Every measured idle row gates its
# frame budget together with the matching scheduling counter floor. Floors are
# scaled from the 120-frame values below. Static-zero exceptions must be named
# in GAME_IDLE_LIVENESS with a reason; an animated row may never infer a zero
# floor from a stalled runtime flag. Budget and floor changes belong in the same
# justified commit because smooth-but-frozen and live-but-slow both fail release.

const MainScene := preload("res://scenes/main.tscn")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const PerfTelemetryOverlayScript := preload("res://scripts/ui/perf_telemetry_overlay.gd")
const PerformanceLivenessGuardScript := preload("res://scripts/ui/performance_liveness_guard.gd")
const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const REPORT_PATH := "user://foundation_performance_probe_report.json"
const TEST_META_COLLECTION_PATH := "user://foundation_performance_probe_meta_collection.json"
const META_COLLECTION_PATH_ENV := "BTH_META_COLLECTION_PATH"
const DEFAULT_SEED_PREFIX := "FOUNDATION-PERF"
const DEFAULT_RUN_COUNT := 8
const DEFAULT_FRAMES_PER_SURFACE := 120
const DEFAULT_RESOLVE_SAMPLE_COUNT := 48
const SCRATCH_POINTER_SAMPLE_COUNT := 60
const SCRATCH_POINTER_BUDGET := {"avg_ms": 0.75, "p95_ms": 1.5, "max_ms": 5.0}
const LOW_END_SCALE_FACTOR := 10.2
const LOW_END_FRAME_BUDGET_MS := 16.6
const MAX_SURFACE_DRAW_P95_MS := 5.0
# Static idle surfaces may report zero draw samples because they have no active
# animation liveness. Animated idle surfaces must redraw and use the active
# draw budget above; zero samples on an animated surface is a release failure.
const MAX_IDLE_SURFACE_DRAW_P95_MS := 1.5
const IDLE_SURFACE_DRAW_WAIVERS := {}
const ANIMATED_IDLE_SURFACE_DRAW_BUDGETS := {
	"roulette": 7.0,
	"scratch_tickets": 5.0,
}
const GAME_IDLE_LIVENESS := {
	"pull_tabs": {"counter": "surface_animation_redraw_count", "minimum_per_120_frames": 8},
	"scratch_tickets": {"counter": "surface_animation_redraw_count", "minimum_per_120_frames": 8},
	"slot": {"counter": "surface_animation_redraw_count", "minimum_per_120_frames": 0, "zero_reason": "The idle slot cabinet is static until autoplay or a spin animation starts."},
	"bar_dice": {"counter": "surface_animation_redraw_count", "minimum_per_120_frames": 8},
	"blackjack": {"counter": "surface_animation_redraw_count", "minimum_per_120_frames": 8},
	"baccarat": {"counter": "surface_animation_redraw_count", "minimum_per_120_frames": 8},
	"roulette": {"counter": "surface_animation_redraw_count", "minimum_per_120_frames": 8},
	"video_poker": {"counter": "surface_animation_redraw_count", "minimum_per_120_frames": 0, "zero_reason": "The idle video-poker cabinet is static until a deal or draw animation starts."},
}
const ENVIRONMENT_IDLE_LIVENESS := {
	"counter": "scene_idle_animation_redraw_count",
	"minimum_per_120_frames": 8,
}
const OVERLAY_COST_SAMPLE_FRAMES := 120
const OVERLAY_REMOVED_DISABLED_MAX_AVG_DELTA_MS := 0.25
const OVERLAY_ENABLED_FRAME_P95_BUDGET_MS := 16.0
const MAX_SEVERE_IDLE_AVG_MS := 45.0
const MAX_SEVERE_FOCUS_AVG_MS := 45.0
const MAX_FOCUS_CALL_MS := 10.0
const FOCUS_PROBE_FRAMES := 18
const MAX_FOCUS_OBJECTS_PER_SEED := 4
const GRAND_CASINO_LIVING_FLOOR_FRAME_P95_BUDGET_MS := 16.0
const NEW_SURFACE_SAMPLE_FRAMES := 120
const REQUIRED_GAME_IDS := [
	"pull_tabs",
	"scratch_tickets",
	"slot",
	"bar_dice",
	"blackjack",
	"baccarat",
	"roulette",
	"video_poker",
]
const RESOLVE_PROBE_CONFIGS := {
	"pull_tabs": {"action_id": "buy_tab", "stake": 1},
	"scratch_tickets": {"action_id": "buy_scratch_ticket", "stake": 2},
	"slot": {"action_id": "spin", "stake": 10},
	"bar_dice": {"action_id": "roll", "stake": 10},
	"blackjack": {"action_id": "play_basic", "stake": 10},
	"baccarat": {"action_id": "deal_baccarat", "stake": 20},
	"roulette": {"action_id": "spin_roulette", "stake": 10},
	"video_poker": {"action_id": "draw", "stake": 5},
}
const RESOLVE_BUDGETS := {
	"pull_tabs": {"avg_ms": 1.5, "p95_ms": 2.5, "max_ms": 4.0},
	"scratch_tickets": {"avg_ms": 1.5, "p95_ms": 2.5, "max_ms": 4.0},
	"slot": {"avg_ms": 6.0, "p95_ms": 8.0, "max_ms": 10.0},
	"bar_dice": {"avg_ms": 1.5, "p95_ms": 3.0, "max_ms": 4.0},
	"blackjack": {"avg_ms": 4.5, "p95_ms": 5.5, "max_ms": 7.0},
	"baccarat": {"avg_ms": 1.25, "p95_ms": 1.75, "max_ms": 3.0},
	"roulette": {"avg_ms": 2.0, "p95_ms": 3.0, "max_ms": 4.0},
	"video_poker": {"avg_ms": 2.5, "p95_ms": 4.5, "max_ms": 5.0},
}
const LOW_END_HEADROOM_WAIVERS := {
	"slot_autoplay_draw_p95": {
		"reason": "Active slot autoplay renderer is still above the 10.2x min-spec proxy headroom on the dev-box draw timer. The LD.1 web smoke gates the exported WebGL path directly while LD.2 keeps this as a release-gate row.",
		"web_gate": "tools/web_perf_smoke.ps1 slot_autoplay_active frame p95 budget",
	},
}
const NEW_SURFACE_BUDGETS := {
	"meta_home_open": {"call_ms": 700.0},
	"meta_home_idle": {"frame_p95_ms": 16.0, "sample_frames": NEW_SURFACE_SAMPLE_FRAMES},
	"talk_dock_active": {"frame_p95_ms": 16.0, "sample_frames": NEW_SURFACE_SAMPLE_FRAMES},
	"dialogue_active": {"frame_p95_ms": 16.0, "sample_frames": NEW_SURFACE_SAMPLE_FRAMES},
	"eviction_map_transition": {"frame_p95_ms": 16.0, "sample_frames": NEW_SURFACE_SAMPLE_FRAMES},
	"run_report_replay": {"frame_p95_ms": 16.0, "sample_frames": NEW_SURFACE_SAMPLE_FRAMES},
	"grand_casino_duel_idle": {"draw_p95_ms": MAX_SURFACE_DRAW_P95_MS, "sample_frames": NEW_SURFACE_SAMPLE_FRAMES},
}
const NEW_SURFACE_IDLE_LIVENESS := {
	"meta_home_idle": ENVIRONMENT_IDLE_LIVENESS,
}

var app: Control
var failures: Array = []
var warnings: Array = []
var observations: Array = []
var resolve_observations: Array = []
var budget_headroom_checks: Array = []
var renderer_coverage := {}
var game_surface_coverage := {}
var resolve_coverage := {}
var scratch_pointer_checked := false
var new_surface_coverage := {}
var liveness_observations: Array = []
var liveness_guard_proof: Dictionary = {}
var overlay_cost_observations: Array = []
var slot_autoplay_checked := false
var casino_slot_preview_checked := false
var grand_casino_living_floor_idle_checked := false
var run_count := DEFAULT_RUN_COUNT
var frames_per_surface := DEFAULT_FRAMES_PER_SURFACE
var resolve_sample_count := DEFAULT_RESOLVE_SAMPLE_COUNT
var seed_prefix := DEFAULT_SEED_PREFIX


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	run_count = _configured_non_negative_int("BTH_PERF_RUNS", DEFAULT_RUN_COUNT)
	frames_per_surface = _configured_int("BTH_PERF_FRAMES", DEFAULT_FRAMES_PER_SURFACE)
	resolve_sample_count = _configured_int("BTH_PERF_RESOLVE_SAMPLES", DEFAULT_RESOLVE_SAMPLE_COUNT)
	seed_prefix = OS.get_environment("BTH_PERF_SEED_PREFIX")
	if seed_prefix.strip_edges().is_empty():
		seed_prefix = DEFAULT_SEED_PREFIX
	_use_isolated_meta_collection_store(TEST_META_COLLECTION_PATH)
	await _open_fresh_app()
	for run_index in range(run_count):
		await _probe_seed("%s-%02d" % [seed_prefix, run_index + 1], run_index)
	if run_count <= 0:
		await _probe_default_environment_focus_smoke()
	await _probe_practice_game_surface_coverage()
	await _probe_casino_slot_preview_coverage()
	await _probe_grand_casino_living_floor_idle()
	await _probe_game_resolve_budgets()
	await _probe_scratch_pointer_budget()
	await _probe_synthetic_idle_surfaces()
	await _probe_liveness_guard_regression()
	await _probe_new_surface_budgets()
	await _probe_overlay_cost()
	_assert_required_game_surface_coverage()
	_assert_required_resolve_coverage()
	_assert_required_new_surface_coverage()
	_assert_low_end_budget_headroom()
	_write_report()
	_print_summary()
	if not failures.is_empty():
		for failure in failures:
			push_error(str(failure))
		quit(1)
		return
	quit(0)


func _probe_seed(seed: String, run_index: int) -> void:
	app.call("start_foundation_run", seed)
	await _settle(3)
	var environment_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	await _probe_environment_focus(seed, run_index, str(environment_snapshot.get("id", "")))
	var game_ids := _string_array(environment_snapshot.get("game_ids", []))
	if game_ids.is_empty():
		warnings.append("Seed %s did not generate any games." % seed)
		return
	for game_id in game_ids:
		await _probe_game(seed, run_index, str(environment_snapshot.get("id", "")), game_id)


func _probe_default_environment_focus_smoke() -> void:
	var focus_seed := "%s-focus" % seed_prefix
	app.call("start_foundation_run", focus_seed)
	await _settle(3)
	var environment_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	await _probe_environment_focus(focus_seed, -1, str(environment_snapshot.get("id", "")))


func _probe_environment_focus(seed: String, run_index: int, environment_id: String) -> void:
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.has_method("current_view_snapshot"):
		failures.append("Environment canvas was missing focus diagnostics for seed %s." % seed)
		return
	var spatial_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	var objects: Array = spatial_snapshot.get("objects", [])
	var checked := 0
	for object_value in objects:
		if checked >= MAX_FOCUS_OBJECTS_PER_SEED:
			break
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = object_value
		var object_id := str(object_data.get("object_id", ""))
		if object_id.is_empty():
			continue
		var focus_call_start_usec := Time.get_ticks_usec()
		var focus_result := bool(app.call("focus_interactable_object_from_view", object_data)) if app.has_method("focus_interactable_object_from_view") else bool(app.call("focus_interactable_object", object_id))
		var focus_call_usec := Time.get_ticks_usec() - focus_call_start_usec
		if not focus_result:
			failures.append("Focus probe could not focus %s in seed %s." % [object_id, seed])
			continue
		await _settle(1)
		var start_snapshot: Dictionary = canvas.call("current_view_snapshot")
		var target_refresh_count := int(start_snapshot.get("camera_target_refresh_count", -1))
		var target_offset: Vector2 = start_snapshot.get("target_camera_offset", Vector2.ZERO)
		var target_zoom := float(start_snapshot.get("target_camera_zoom", 1.0))
		var start_usec := Time.get_ticks_usec()
		var target_recalculated := false
		for _frame_index in range(FOCUS_PROBE_FRAMES):
			await process_frame
			var frame_snapshot: Dictionary = canvas.call("current_view_snapshot")
			if int(frame_snapshot.get("camera_target_refresh_count", -1)) != target_refresh_count:
				target_recalculated = true
			var frame_target_offset: Vector2 = frame_snapshot.get("target_camera_offset", Vector2.ZERO)
			var frame_target_zoom := float(frame_snapshot.get("target_camera_zoom", 1.0))
			if frame_target_offset.distance_to(target_offset) > 0.25 or absf(frame_target_zoom - target_zoom) > 0.001:
				target_recalculated = true
		var elapsed_usec := Time.get_ticks_usec() - start_usec
		var avg_ms := float(elapsed_usec) / float(FOCUS_PROBE_FRAMES) / 1000.0
		observations.append({
			"seed": seed,
			"run_index": run_index,
			"environment_id": environment_id,
			"object_id": object_id,
			"object_type": str(object_data.get("object_type", "")),
			"mode": "environment_focus",
			"frames": FOCUS_PROBE_FRAMES,
			"focus_call_ms": float(focus_call_usec) / 1000.0,
			"elapsed_ms": float(elapsed_usec) / 1000.0,
			"avg_frame_ms": avg_ms,
			"camera_target_refresh_count": target_refresh_count,
			"target_recalculated_during_glide": target_recalculated,
		})
		if target_recalculated:
			failures.append("Environment focus target recalculated during glide for %s in seed %s." % [object_id, seed])
		if float(focus_call_usec) / 1000.0 > MAX_FOCUS_CALL_MS:
			failures.append("Environment focus call for %s took %.3f ms, above %.3f ms." % [object_id, float(focus_call_usec) / 1000.0, MAX_FOCUS_CALL_MS])
		if avg_ms > MAX_SEVERE_FOCUS_AVG_MS:
			failures.append("Environment focus for %s averaged %.2f ms per frame, above %.2f ms." % [object_id, avg_ms, MAX_SEVERE_FOCUS_AVG_MS])
		checked += 1
		app.call("clear_interaction_focus", true)
		await _settle(3)
	if checked <= 0:
		warnings.append("Seed %s did not expose environment focus objects for the performance probe." % seed)


func _probe_game(seed: String, run_index: int, environment_id: String, game_id: String) -> void:
	app.call("enter_game", game_id)
	await _settle(3)
	var game_snapshot: Dictionary = app.call("current_game_view_snapshot")
	var renderer := str(game_snapshot.get("surface_renderer", ""))
	if renderer.is_empty():
		renderer = game_id
	renderer_coverage[renderer] = int(renderer_coverage.get(renderer, 0)) + 1
	game_surface_coverage[game_id] = int(game_surface_coverage.get(game_id, 0)) + 1
	var canvas := _game_surface_canvas()
	if canvas == null:
		failures.append("Game surface canvas was missing for %s in seed %s." % [game_id, seed])
		app.call("back_to_environment")
		await _settle(2)
		return
	if canvas.has_method("reset_performance_counters"):
		canvas.call("reset_performance_counters")
	var start_usec := Time.get_ticks_usec()
	for _frame_index in range(frames_per_surface):
		await process_frame
	var elapsed_usec := Time.get_ticks_usec() - start_usec
	var counters := _canvas_counters(canvas)
	var runtime_status: Dictionary = canvas.call("surface_runtime_status") if canvas.has_method("surface_runtime_status") else {}
	var animation_liveness_active := bool(runtime_status.get("surface_animation_liveness_active", false))
	var liveness_spec := _game_idle_liveness_spec(game_id)
	var liveness_counter := str(liveness_spec.get("counter", "surface_animation_redraw_count"))
	var liveness_floor := _scaled_liveness_floor(liveness_spec, frames_per_surface)
	var liveness_measured := int(counters.get(liveness_counter, 0))
	var avg_ms := float(elapsed_usec) / float(maxi(1, frames_per_surface)) / 1000.0
	var draw_p95_ms := float(counters.get("draw_p95_ms", 0.0))
	var draw_samples := _array_size(counters.get("draw_frame_usec_samples", []))
	observations.append({
		"seed": seed,
		"run_index": run_index,
		"environment_id": environment_id,
		"game_id": game_id,
		"renderer": renderer,
		"mode": "idle_surface",
		"frames": frames_per_surface,
		"elapsed_ms": float(elapsed_usec) / 1000.0,
		"avg_frame_ms": avg_ms,
		"draw_avg_ms": float(counters.get("draw_avg_ms", 0.0)),
		"draw_p95_ms": draw_p95_ms,
		"draw_max_ms": float(counters.get("draw_max_ms", 0.0)),
		"draw_samples": draw_samples,
		"animation_liveness_active": animation_liveness_active,
		"liveness_counter": liveness_counter,
		"liveness_floor": liveness_floor,
		"liveness_measured": liveness_measured,
		"liveness_zero_reason": str(liveness_spec.get("zero_reason", "")),
		"full_snapshot_calls": int(counters.get("full_snapshot_calls", 0)),
		"runtime_status_calls": int(counters.get("runtime_status_calls", 0)),
		"idle_draw_budget_ms": _animated_idle_draw_budget(renderer) if animation_liveness_active else MAX_IDLE_SURFACE_DRAW_P95_MS,
	})
	if int(counters.get("full_snapshot_calls", 0)) > 0:
		failures.append("Idle %s surface rebuilt full snapshots %d times." % [renderer, int(counters.get("full_snapshot_calls", 0))])
	# FoundationMain polls this lightweight status while deciding whether a
	# surface needs automation or realtime advancement. Keep it in the report;
	# only full snapshot rebuilds indicate the expensive regression T7.1 guards.
	if avg_ms > MAX_SEVERE_IDLE_AVG_MS:
		failures.append("Idle %s surface averaged %.2f ms per frame, above %.2f ms." % [renderer, avg_ms, MAX_SEVERE_IDLE_AVG_MS])
	_assert_idle_draw_budget("Idle %s surface" % renderer, renderer, draw_p95_ms, draw_samples, animation_liveness_active)
	_assert_liveness("Idle %s surface" % renderer, liveness_counter, liveness_floor, liveness_measured, str(liveness_spec.get("zero_reason", "")))
	if renderer == "slot_machine" and not slot_autoplay_checked:
		await _probe_slot_autoplay(seed, run_index, environment_id, game_id, canvas)
	app.call("back_to_environment")
	await _settle(2)


func _probe_slot_autoplay(seed: String, run_index: int, environment_id: String, game_id: String, canvas: Control) -> void:
	slot_autoplay_checked = true
	canvas.emit_signal("surface_action", "slot_auto_toggle", 0, false)
	await _settle(4)
	var active_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if not bool(active_snapshot.get("slot_autoplay_active", false)):
		failures.append("Slot autoplay did not persist in the active machine state for seed %s." % seed)
	if canvas.has_method("reset_performance_counters"):
		canvas.call("reset_performance_counters")
	var frames := maxi(45, int(frames_per_surface * 0.5))
	var start_usec := Time.get_ticks_usec()
	for _frame_index in range(frames):
		canvas.queue_redraw()
		await process_frame
	var elapsed_usec := Time.get_ticks_usec() - start_usec
	var counters := _canvas_counters(canvas)
	var avg_ms := float(elapsed_usec) / float(maxi(1, frames)) / 1000.0
	var draw_p95_ms := float(counters.get("draw_p95_ms", 0.0))
	var draw_samples := _array_size(counters.get("draw_frame_usec_samples", []))
	observations.append({
		"seed": seed,
		"run_index": run_index,
		"environment_id": environment_id,
		"game_id": game_id,
		"renderer": "slot_machine",
		"mode": "slot_autoplay",
		"frames": frames,
		"elapsed_ms": float(elapsed_usec) / 1000.0,
		"avg_frame_ms": avg_ms,
		"draw_avg_ms": float(counters.get("draw_avg_ms", 0.0)),
		"draw_p95_ms": draw_p95_ms,
		"draw_max_ms": float(counters.get("draw_max_ms", 0.0)),
		"draw_samples": draw_samples,
		"full_snapshot_calls": int(counters.get("full_snapshot_calls", 0)),
		"runtime_status_calls": int(counters.get("runtime_status_calls", 0)),
	})
	if int(counters.get("full_snapshot_calls", 0)) > 0:
		failures.append("Slot autoplay rebuilt full snapshots %d times." % int(counters.get("full_snapshot_calls", 0)))
	if avg_ms > MAX_SEVERE_IDLE_AVG_MS:
		failures.append("Slot autoplay averaged %.2f ms per frame, above %.2f ms." % [avg_ms, MAX_SEVERE_IDLE_AVG_MS])
	_assert_draw_budget("Slot autoplay", draw_p95_ms, draw_samples)
	await _probe_slot_offscreen_autoplay(seed, game_id)


func _probe_slot_offscreen_autoplay(seed: String, game_id: String) -> void:
	var run_state: RunState = app.get("run_state")
	if run_state == null:
		failures.append("Slot offscreen autoplay probe could not access RunState for seed %s." % seed)
		return
	app.call("back_to_environment")
	await _settle(3)
	var machine_before := _slot_machine_state(run_state, game_id)
	if not bool(machine_before.get("slot_autoplay_active", false)):
		failures.append("Slot autoplay was lost after leaving the surface for seed %s." % seed)
		return
	var spin_count_before := int(machine_before.get("spin_count", 0))
	var duration_msec := maxi(1, int(machine_before.get("slot_animation_duration_msec", 3000)))
	machine_before["slot_animation_started_msec"] = Time.get_ticks_msec() - duration_msec - 80
	machine_before["slot_autoplay_next_msec"] = 0
	_write_slot_machine_state(run_state, game_id, machine_before)
	await _settle(4)
	var machine_after := _slot_machine_state(run_state, game_id)
	observations.append({
		"seed": seed,
		"environment_id": str(run_state.current_environment.get("id", "")),
		"game_id": game_id,
		"renderer": "slot_machine",
		"mode": "slot_offscreen_autoplay",
		"spin_count_before": spin_count_before,
		"spin_count_after": int(machine_after.get("spin_count", 0)),
		"autoplay_active": bool(machine_after.get("slot_autoplay_active", false)),
	})
	if int(machine_after.get("spin_count", 0)) <= spin_count_before:
		failures.append("Slot autoplay did not advance while the surface was closed for seed %s." % seed)
	if not bool(machine_after.get("slot_autoplay_active", false)):
		failures.append("Slot autoplay stopped after offscreen runtime tick for seed %s." % seed)
	var environment_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var game_object := _interactable_object_by_id(environment_snapshot.get("interactable_objects", []), "game:%s" % game_id)
	var runtime_state: Dictionary = game_object.get("runtime_state", {})
	if runtime_state.is_empty() or not bool(runtime_state.get("active", false)):
		failures.append("Slot environment icon did not expose active runtime state after leaving the surface for seed %s." % seed)
	if str(runtime_state.get("status_label", "")).strip_edges().is_empty():
		failures.append("Slot environment icon runtime state did not expose a status label for seed %s." % seed)
	app.call("enter_game", game_id)
	await _settle(3)
	var reentered_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if not bool(reentered_snapshot.get("slot_autoplay_active", false)):
		failures.append("Slot autoplay was not visible after re-entering the machine for seed %s." % seed)
	if int(reentered_snapshot.get("spin_count", 0)) < int(machine_after.get("spin_count", 0)):
		failures.append("Slot re-entry did not preserve the offscreen machine spin count for seed %s." % seed)


func _probe_practice_game_surface_coverage() -> void:
	for game_id_value in REQUIRED_GAME_IDS:
		var game_id := str(game_id_value)
		app.call("start_game_test_session", game_id)
		await _settle(4)
		var environment_snapshot: Dictionary = app.call("current_environment_view_snapshot")
		var environment_id := str(environment_snapshot.get("id", "practice_%s" % game_id))
		if not _string_array(environment_snapshot.get("game_ids", [])).has(game_id):
			failures.append("Practice performance probe could not build a %s environment." % game_id)
			continue
		await _probe_game("practice:%s" % game_id, -1, environment_id, game_id)


func _probe_casino_slot_preview_coverage() -> void:
	app.call("start_game_test_session", "slot")
	await _settle(4)
	app.call("back_to_environment")
	await _settle(4)
	var environment_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var environment_id := str(environment_snapshot.get("id", "practice_slot"))
	var kind := str(environment_snapshot.get("kind", ""))
	var game_ids := _string_array(environment_snapshot.get("game_ids", []))
	var game_object := _interactable_object_by_id(environment_snapshot.get("interactable_objects", []), "game:slot")
	var runtime_state: Dictionary = game_object.get("runtime_state", {}) if typeof(game_object.get("runtime_state", {})) == TYPE_DICTIONARY else {}
	var visual_state: Dictionary = game_object.get("visual_state", {}) if typeof(game_object.get("visual_state", {})) == TYPE_DICTIONARY else {}
	casino_slot_preview_checked = game_ids.has("slot") and not game_object.is_empty()
	observations.append({
		"seed": "practice:slot_preview",
		"run_index": -1,
		"environment_id": environment_id,
		"game_id": "slot",
		"renderer": "slot_machine",
		"mode": "casino_slot_preview",
		"kind": kind,
		"preview_active": casino_slot_preview_checked,
		"runtime_state": runtime_state,
		"visual_state": visual_state,
	})
	if not casino_slot_preview_checked:
		failures.append("Performance probe did not sample a casino room slot preview.")
	if kind != "casino":
		warnings.append("Slot preview practice room kind was %s, expected casino-like coverage." % kind)


func _probe_grand_casino_living_floor_idle() -> void:
	var canvas: Control = PixelSceneCanvasScript.new()
	canvas.size = Vector2(VisualStyleScript.ENVIRONMENT_BOARD_SIZE)
	root.add_child(canvas)
	canvas.call("render_environment_snapshot", {
		"id": "grand_casino_living_perf",
		"archetype_id": "grand_casino",
		"display_name": "Grand Casino Main Floor",
		"pit_boss_watch": {"active": true, "watched": true},
		"grand_casino_living_floor": {
			"player_room": "grand_casino",
			"rourke": {"present": true, "on_floor": true, "room": "grand_casino", "spot": "main_center", "facing": "right"},
			"rivals": [
				{"id": "perf_rival_one", "tell": "chip_riffle", "spot": 0, "idle_phase": 10},
				{"id": "perf_rival_two", "tell": "heel_tap", "spot": 1, "idle_phase": 20},
				{"id": "perf_rival_three", "tell": "glance_loop", "spot": 2, "idle_phase": 30},
			],
			"rival_count": 3,
			"escort": {},
		},
		"interactable_objects": [],
	})
	await _settle(3)
	canvas.call("reset_performance_counters")
	var frame_stats := await _measure_frame_phase(frames_per_surface)
	var live_status: Dictionary = canvas.call("performance_live_status")
	var liveness_counter := str(ENVIRONMENT_IDLE_LIVENESS.get("counter", "scene_idle_animation_redraw_count"))
	var liveness_floor := _scaled_liveness_floor(ENVIRONMENT_IDLE_LIVENESS, frames_per_surface)
	var liveness_measured := int(live_status.get(liveness_counter, 0))
	grand_casino_living_floor_idle_checked = true
	observations.append({
		"seed": "synthetic:grand_casino_living_floor",
		"run_index": -1,
		"environment_id": "grand_casino",
		"mode": "grand_casino_living_floor_idle",
		"frames": frames_per_surface,
		"character_count": 5,
		"frame_time": frame_stats,
		"frame_p95_budget_ms": GRAND_CASINO_LIVING_FLOOR_FRAME_P95_BUDGET_MS,
		"liveness_counter": liveness_counter,
		"liveness_floor": liveness_floor,
		"liveness_measured": liveness_measured,
	})
	if float(frame_stats.get("p95_ms", 0.0)) > GRAND_CASINO_LIVING_FLOOR_FRAME_P95_BUDGET_MS:
		failures.append("Grand Casino living-floor idle frame p95 %.3f ms exceeded %.3f ms with Rourke and three rivals animating." % [float(frame_stats.get("p95_ms", 0.0)), GRAND_CASINO_LIVING_FLOOR_FRAME_P95_BUDGET_MS])
	_assert_liveness("Grand Casino living floor", liveness_counter, liveness_floor, liveness_measured)
	canvas.queue_free()
	await _settle(1)


func _probe_game_resolve_budgets() -> void:
	for game_id_value in REQUIRED_GAME_IDS:
		var game_id := str(game_id_value)
		var config := _dict(RESOLVE_PROBE_CONFIGS.get(game_id, {}))
		var action_id := str(config.get("action_id", ""))
		if action_id.is_empty():
			failures.append("Resolve performance probe has no action configured for %s." % game_id)
			continue
		app.call("start_game_test_session", game_id)
		await _settle(4)
		var run_state: RunState = app.get("run_state")
		var game: GameModule = app.get("current_game") as GameModule
		if run_state == null or game == null:
			failures.append("Resolve performance probe could not enter %s." % game_id)
			continue
		var stake := int(config.get("stake", 1))
		var baseline_environment: Dictionary = run_state.current_environment.duplicate(true)
		var baseline_rng_seed := int(run_state.rng_seed)
		var baseline_rng_state := int(run_state.rng_state)
		var baseline_suspicion: Dictionary = run_state.suspicion.duplicate(true)
		var samples: Array = []
		var ok_count := 0
		var failure_messages: Array = []
		for sample_index in range(resolve_sample_count):
			_prepare_run_for_resolve_probe(run_state, game_id, baseline_environment, baseline_rng_seed, baseline_rng_state, baseline_suspicion)
			var rng := run_state.create_rng("perf_resolve:%s:%d" % [game_id, sample_index])
			var environment: Dictionary = run_state.current_environment
			var ui_state := _resolve_probe_ui_state(game_id, sample_index, game, run_state, environment)
			var start_usec := Time.get_ticks_usec()
			var result: Dictionary = game.resolve_with_context(action_id, stake, run_state, environment, rng, ui_state)
			var elapsed_usec := Time.get_ticks_usec() - start_usec
			samples.append(float(elapsed_usec) / 1000.0)
			if bool(result.get("ok", false)):
				ok_count += 1
			elif failure_messages.size() < 3:
				var failure_message := str(result.get("message", "Resolve returned ok=false.")).strip_edges()
				if not failure_messages.has(failure_message):
					failure_messages.append(failure_message)
		var stats := _timing_stats(samples)
		var budget := _dict(RESOLVE_BUDGETS.get(game_id, {}))
		stats["seed"] = "practice:%s" % game_id
		stats["run_index"] = -1
		stats["game_id"] = game_id
		stats["action_id"] = action_id
		stats["mode"] = "resolve_path"
		stats["sample_count"] = samples.size()
		stats["ok_count"] = ok_count
		stats["failure_messages"] = failure_messages
		stats["budget"] = budget
		resolve_observations.append(stats)
		observations.append(stats)
		resolve_coverage[game_id] = int(resolve_coverage.get(game_id, 0)) + 1
		if ok_count <= 0:
			failures.append("Resolve performance probe did not get a successful %s result: %s" % [game_id, "; ".join(failure_messages)])
		elif ok_count < samples.size():
			failures.append("Resolve performance probe only got %d/%d successful %s results." % [ok_count, samples.size(), game_id])
		_assert_resolve_budget(game_id, stats, budget)


func _probe_scratch_pointer_budget() -> void:
	app.call("start_game_test_session", "scratch_tickets")
	await _settle(4)
	var run_state: RunState = app.get("run_state")
	var game: GameModule = app.get("current_game") as GameModule
	if run_state == null or game == null:
		failures.append("Scratch pointer performance probe could not enter Scratch Tickets.")
		return
	var environment: Dictionary = run_state.current_environment
	var machine: Dictionary = game.call("_ensure_machine_state", run_state, environment, true)
	var ticket_type: Dictionary = game.call("_ticket_type", "two_fer")
	var ticket: Dictionary = game.call("_roll_ticket", ticket_type, run_state.create_rng("perf_scratch_pointer"), 0, "pointer-budget")
	if ticket.is_empty():
		failures.append("Scratch pointer performance probe could not build its ticket fixture.")
		return
	machine["active_ticket"] = ticket
	app.call("_refresh")
	var start := Vector2(342.0, 160.0)
	app.call("_on_game_surface_pointer_action", "scratch_scrub", 0, "begin", start)
	var samples: Array = []
	for sample_index in range(SCRATCH_POINTER_SAMPLE_COUNT):
		var point := Vector2(342.0 + float((sample_index * 17) % 278), 160.0 + float((sample_index % 3) * 4))
		var started_usec := Time.get_ticks_usec()
		app.call("_on_game_surface_pointer_action", "scratch_scrub", 0, "move", point)
		samples.append(float(Time.get_ticks_usec() - started_usec) / 1000.0)
	app.call("_on_game_surface_pointer_action", "scratch_scrub", 0, "end", Vector2(620.0, 168.0))
	var stats := _timing_stats(samples)
	stats["seed"] = "practice:scratch_pointer"
	stats["run_index"] = -1
	stats["game_id"] = "scratch_tickets"
	stats["mode"] = "scratch_pointer_path"
	stats["sample_count"] = samples.size()
	stats["budget"] = SCRATCH_POINTER_BUDGET
	observations.append(stats)
	scratch_pointer_checked = true
	_assert_resolve_budget("scratch pointer", stats, SCRATCH_POINTER_BUDGET)


func _probe_synthetic_idle_surfaces() -> void:
	for snapshot in [_synthetic_blackjack_idle_snapshot()]:
		var canvas: Control = GameSurfaceCanvasScript.new()
		canvas.size = Vector2(VisualStyleScript.GAME_BOARD_SIZE)
		root.add_child(canvas)
		canvas.call("render_game_snapshot", snapshot)
		await _settle(3)
		canvas.set_process(false)
		if canvas.has_method("reset_performance_counters"):
			canvas.call("reset_performance_counters")
		var start_usec := Time.get_ticks_usec()
		for _frame_index in range(frames_per_surface):
			canvas.set("flicker", float(canvas.get("flicker")) + (1.0 / 60.0))
			canvas.queue_redraw()
			await process_frame
		var elapsed_usec := Time.get_ticks_usec() - start_usec
		var counters := _canvas_counters(canvas)
		var renderer := str(snapshot.get("surface_renderer", ""))
		var draw_samples := _array_size(counters.get("draw_frame_usec_samples", []))
		var runtime_status: Dictionary = canvas.call("surface_runtime_status") if canvas.has_method("surface_runtime_status") else {}
		var expects_idle_redraw := bool(runtime_status.get("surface_animation_liveness_active", false))
		observations.append({
			"seed": "synthetic:idle_surface",
			"run_index": -1,
			"environment_id": "synthetic_idle_surface",
			"game_id": str(snapshot.get("game_id", "")),
			"renderer": renderer,
			"mode": "synthetic_forced_draw",
			"frames": frames_per_surface,
			"elapsed_ms": float(elapsed_usec) / 1000.0,
			"avg_frame_ms": float(elapsed_usec) / float(maxi(1, frames_per_surface)) / 1000.0,
			"draw_avg_ms": float(counters.get("draw_avg_ms", 0.0)),
			"draw_p95_ms": float(counters.get("draw_p95_ms", 0.0)),
			"draw_max_ms": float(counters.get("draw_max_ms", 0.0)),
			"draw_samples": draw_samples,
			"animation_liveness_active": expects_idle_redraw,
			"full_snapshot_calls": int(counters.get("full_snapshot_calls", 0)),
			"runtime_status_calls": int(counters.get("runtime_status_calls", 0)),
			"idle_draw_budget_ms": _animated_idle_draw_budget(renderer) if expects_idle_redraw else MAX_IDLE_SURFACE_DRAW_P95_MS,
		})
		if expects_idle_redraw and draw_samples <= 0:
			failures.append("Synthetic %s idle surface produced no draw samples." % renderer)
		elif not expects_idle_redraw and draw_samples > 0:
			failures.append("Synthetic %s static idle surface redrew %d time(s)." % [renderer, draw_samples])
		canvas.queue_free()
		await _settle(1)
		if expects_idle_redraw:
			await _probe_synthetic_idle_surface_liveness(snapshot)


func _probe_synthetic_idle_surface_liveness(snapshot: Dictionary) -> void:
	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.size = Vector2(VisualStyleScript.GAME_BOARD_SIZE)
	root.add_child(canvas)
	canvas.call("render_game_snapshot", snapshot)
	await _settle(3)
	if canvas.has_method("reset_performance_counters"):
		canvas.call("reset_performance_counters")
	var start_usec := Time.get_ticks_usec()
	for _frame_index in range(frames_per_surface):
		await process_frame
	var elapsed_usec := Time.get_ticks_usec() - start_usec
	var counters := _canvas_counters(canvas)
	var renderer := str(snapshot.get("surface_renderer", ""))
	var draw_samples := _array_size(counters.get("draw_frame_usec_samples", []))
	var runtime_status: Dictionary = canvas.call("surface_runtime_status") if canvas.has_method("surface_runtime_status") else {}
	var liveness_active := bool(runtime_status.get("surface_animation_liveness_active", false))
	var liveness_spec := _game_idle_liveness_spec(str(snapshot.get("game_id", "")))
	var liveness_counter := str(liveness_spec.get("counter", "surface_animation_redraw_count"))
	var liveness_floor := _scaled_liveness_floor(liveness_spec, frames_per_surface)
	var liveness_measured := int(counters.get(liveness_counter, 0))
	observations.append({
		"seed": "synthetic:idle_surface_liveness",
		"run_index": -1,
		"environment_id": "synthetic_idle_surface",
		"game_id": str(snapshot.get("game_id", "")),
		"renderer": renderer,
		"mode": "synthetic_idle_surface_liveness",
		"frames": frames_per_surface,
		"elapsed_ms": float(elapsed_usec) / 1000.0,
		"avg_frame_ms": float(elapsed_usec) / float(maxi(1, frames_per_surface)) / 1000.0,
		"draw_avg_ms": float(counters.get("draw_avg_ms", 0.0)),
		"draw_p95_ms": float(counters.get("draw_p95_ms", 0.0)),
		"draw_max_ms": float(counters.get("draw_max_ms", 0.0)),
		"draw_samples": draw_samples,
		"animation_liveness_active": liveness_active,
		"liveness_counter": liveness_counter,
		"liveness_floor": liveness_floor,
		"liveness_measured": liveness_measured,
		"full_snapshot_calls": int(counters.get("full_snapshot_calls", 0)),
		"runtime_status_calls": int(counters.get("runtime_status_calls", 0)),
		"idle_draw_budget_ms": _animated_idle_draw_budget(renderer) if liveness_active else MAX_IDLE_SURFACE_DRAW_P95_MS,
	})
	if not liveness_active:
		failures.append("Synthetic %s idle surface lost animation liveness before sampling." % renderer)
	elif draw_samples <= 0:
		failures.append("Synthetic %s idle surface did not redraw from _process without input/hover." % renderer)
	_assert_liveness("Synthetic %s idle surface" % renderer, liveness_counter, liveness_floor, liveness_measured)
	canvas.queue_free()
	await _settle(1)


func _probe_liveness_guard_regression() -> void:
	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.size = Vector2(VisualStyleScript.GAME_BOARD_SIZE)
	root.add_child(canvas)
	canvas.call("render_game_snapshot", _synthetic_blackjack_idle_snapshot())
	await _settle(3)
	canvas.set_process(false)
	canvas.call("reset_performance_counters")
	for _frame_index in range(24):
		await process_frame
	var suppressed_counters := _canvas_counters(canvas)
	var counter := "surface_animation_redraw_count"
	var suppressed_measured := int(suppressed_counters.get(counter, 0))
	var suppressed_check := PerformanceLivenessGuardScript.evaluate("Synthetic blackjack idle surface", counter, 1, suppressed_measured)
	if bool(suppressed_check.get("passed", true)):
		failures.append("Forced liveness suppression unexpectedly passed the guard.")
	var proof_message := str(suppressed_check.get("message", ""))
	if proof_message.find("Synthetic blackjack idle surface") == -1 or proof_message.find(counter) == -1:
		failures.append("Forced liveness suppression message did not name the surface and counter: %s" % proof_message)
	canvas.set_process(true)
	canvas.call("reset_performance_counters")
	for _frame_index in range(120):
		await process_frame
	var restored_counters := _canvas_counters(canvas)
	var restored_measured := int(restored_counters.get(counter, 0))
	var restored_check := PerformanceLivenessGuardScript.evaluate("Synthetic blackjack idle surface", counter, 1, restored_measured)
	if not bool(restored_check.get("passed", false)):
		failures.append("Restored liveness scheduling did not pass: %s" % str(restored_check.get("message", "")))
	liveness_guard_proof = {
		"surface": "Synthetic blackjack idle surface",
		"counter": counter,
		"suppressed_measured": suppressed_measured,
		"suppressed_passed": bool(suppressed_check.get("passed", true)),
		"suppressed_failure_message": proof_message,
		"restored_measured": restored_measured,
		"restored_passed": bool(restored_check.get("passed", false)),
	}
	canvas.queue_free()
	await _settle(1)


func _probe_new_surface_budgets() -> void:
	await _probe_meta_home_surface_budget()
	await _probe_talk_dock_surface_budget()
	await _probe_dialogue_surface_budget()
	await _probe_eviction_map_transition_budget()
	await _probe_run_report_replay_budget()
	await _probe_rourke_duel_surface_budget()


func _probe_rourke_duel_surface_budget() -> void:
	var mode := "grand_casino_duel_idle"
	var budget := _dict(NEW_SURFACE_BUDGETS.get(mode, {}))
	var sample_frames := maxi(1, int(budget.get("sample_frames", NEW_SURFACE_SAMPLE_FRAMES)))
	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.size = Vector2(VisualStyleScript.GAME_BOARD_SIZE)
	root.add_child(canvas)
	canvas.call("render_game_snapshot", _synthetic_rourke_duel_idle_snapshot())
	await _settle(3)
	canvas.call("reset_performance_counters")
	for _frame_index in range(sample_frames):
		await process_frame
	var counters := _canvas_counters(canvas)
	var draw_p95 := float(counters.get("draw_p95_ms", 0.0))
	var draw_samples := _array_size(counters.get("draw_frame_usec_samples", []))
	var measured := int(counters.get("surface_animation_redraw_count", 0))
	var floor_count := _scaled_liveness_floor(_dict(GAME_IDLE_LIVENESS.get("blackjack", {})), sample_frames)
	observations.append({
		"seed": "new_surface:%s" % mode,
		"run_index": -1,
		"environment_id": "grand_casino_back_room",
		"game_id": "blackjack",
		"mode": mode,
		"label": "Grand Casino Rourke duel idle",
		"frames": sample_frames,
		"draw_avg_ms": float(counters.get("draw_avg_ms", 0.0)),
		"draw_p95_ms": draw_p95,
		"draw_max_ms": float(counters.get("draw_max_ms", 0.0)),
		"draw_samples": draw_samples,
		"liveness_counter": "surface_animation_redraw_count",
		"liveness_floor": floor_count,
		"liveness_measured": measured,
		"full_snapshot_calls": int(counters.get("full_snapshot_calls", 0)),
		"budget": budget,
	})
	new_surface_coverage[mode] = int(new_surface_coverage.get(mode, 0)) + 1
	if draw_samples <= 0:
		failures.append("Grand Casino Rourke duel idle did not record draw samples.")
	elif draw_p95 > float(budget.get("draw_p95_ms", 0.0)):
		failures.append("Grand Casino Rourke duel idle draw p95 %.3f ms exceeded %.3f ms." % [draw_p95, float(budget.get("draw_p95_ms", 0.0))])
	_assert_liveness("Grand Casino Rourke duel idle", "surface_animation_redraw_count", floor_count, measured)
	canvas.queue_free()
	await _settle(1)


func _probe_overlay_cost() -> void:
	app.call("start_foundation_run", "%s-overlay-cost" % seed_prefix)
	await _settle(4)
	var removed_stats := await _measure_frame_phase(OVERLAY_COST_SAMPLE_FRAMES)
	var disabled_overlay: Control = PerfTelemetryOverlayScript.new()
	app.add_child(disabled_overlay)
	var disabled_stats := await _measure_frame_phase(OVERLAY_COST_SAMPLE_FRAMES)
	disabled_overlay.queue_free()
	await _settle(2)
	var enabled_overlay: Control = PerfTelemetryOverlayScript.new()
	app.add_child(enabled_overlay)
	app.set("perf_telemetry_overlay", enabled_overlay)
	enabled_overlay.call("configure_for_probe", app, true)
	var enabled_stats := await _measure_frame_phase(OVERLAY_COST_SAMPLE_FRAMES)
	var overlay_overhead: Dictionary = enabled_overlay.call("overhead_snapshot")
	var attribution: Dictionary = enabled_overlay.call("foundation_attribution_snapshot")
	app.set("perf_telemetry_overlay", null)
	enabled_overlay.queue_free()
	await _settle(2)
	var removed_avg := float(removed_stats.get("avg_ms", 0.0))
	var disabled_avg := float(disabled_stats.get("avg_ms", 0.0))
	var disabled_delta := absf(disabled_avg - removed_avg)
	overlay_cost_observations = [
		{"mode": "removed", "frames": OVERLAY_COST_SAMPLE_FRAMES, "frame_time": removed_stats},
		{"mode": "disabled", "frames": OVERLAY_COST_SAMPLE_FRAMES, "frame_time": disabled_stats, "avg_delta_vs_removed_ms": disabled_delta},
		{"mode": "enabled", "frames": OVERLAY_COST_SAMPLE_FRAMES, "frame_time": enabled_stats, "telemetry_overhead": overlay_overhead, "foundation_attribution": attribution},
	]
	if disabled_delta > OVERLAY_REMOVED_DISABLED_MAX_AVG_DELTA_MS:
		failures.append("Disabled telemetry overlay avg frame delta %.3f ms was distinguishable from removed (limit %.3f ms)." % [disabled_delta, OVERLAY_REMOVED_DISABLED_MAX_AVG_DELTA_MS])
	var enabled_p95 := float(enabled_stats.get("p95_ms", 0.0))
	if enabled_p95 > OVERLAY_ENABLED_FRAME_P95_BUDGET_MS:
		failures.append("Enabled telemetry overlay frame p95 %.3f ms exceeded %.3f ms." % [enabled_p95, OVERLAY_ENABLED_FRAME_P95_BUDGET_MS])


func _measure_frame_phase(frames: int) -> Dictionary:
	var samples: Array = []
	for _frame_index in range(maxi(1, frames)):
		var start_usec := Time.get_ticks_usec()
		await process_frame
		samples.append(float(Time.get_ticks_usec() - start_usec) / 1000.0)
	return _timing_stats(samples)


func _probe_meta_home_surface_budget() -> void:
	var open_budget := _dict(NEW_SURFACE_BUDGETS.get("meta_home_open", {}))
	var open_start_usec := Time.get_ticks_usec()
	app.call("open_meta_home")
	var open_ms := float(Time.get_ticks_usec() - open_start_usec) / 1000.0
	await _settle(8)
	var environment_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	if str(environment_snapshot.get("kind", "")) != "home":
		failures.append("New-surface performance probe did not enter meta home.")
		return
	var spatial_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	if _array_size(spatial_snapshot.get("objects", [])) <= 0:
		failures.append("Meta home performance probe did not expose walkable room objects.")
	observations.append({
		"seed": "new_surface:meta_home_open",
		"run_index": -1,
		"environment_id": str(environment_snapshot.get("id", "")),
		"mode": "meta_home_open",
		"open_call_ms": open_ms,
		"object_count": _array_size(spatial_snapshot.get("objects", [])),
		"budget": open_budget,
	})
	new_surface_coverage["meta_home_open"] = int(new_surface_coverage.get("meta_home_open", 0)) + 1
	var call_budget := float(open_budget.get("call_ms", 0.0))
	if call_budget > 0.0 and open_ms > call_budget:
		failures.append("Meta home open call %.3f ms exceeded %.3f ms." % [open_ms, call_budget])
	await _record_new_surface_phase("meta_home_idle", "Meta home idle")


func _probe_talk_dock_surface_budget() -> void:
	app.call("start_foundation_run", "%s-talk-dock" % seed_prefix)
	await _settle(4)
	var run_state: RunState = app.get("run_state")
	var library: ContentLibrary = app.get("library")
	if run_state == null or library == null:
		failures.append("Talk dock performance probe could not access RunState or ContentLibrary.")
		return
	var event_id := "blackjack_counter_probe"
	var event_definition := library.event(event_id)
	if event_definition.is_empty():
		failures.append("Talk dock performance probe could not find event %s." % event_id)
		return
	var environment := run_state.current_environment.duplicate(true)
	environment["id"] = "perf_talk_table"
	environment["archetype_id"] = "bar"
	environment["kind"] = "bar"
	environment["tier"] = 1
	environment["game_ids"] = ["blackjack"]
	environment["event_ids"] = []
	environment["resolved_event_ids"] = []
	run_state.set_environment(environment)
	run_state.suspicion["level"] = 10
	var context := {
		"trigger": "table_approach",
		"type": "table_approach",
		"game_id": "blackjack",
		"hands_played": 2,
		"environment_snapshot": run_state.current_environment.duplicate(true),
	}
	var speaker := {
		"role": "patron",
		"name": "Mara",
		"silhouette": "coat",
		"bind": "table_patron",
		"patron_index": 0,
	}
	var overrides: Dictionary = app.call("_triggered_entry_overrides", event_definition, speaker)
	overrides["presentation"] = "talk"
	if not run_state.enqueue_triggered_event(event_id, "perf_probe", context, overrides):
		failures.append("Talk dock performance probe could not enqueue %s." % event_id)
		return
	app.call("_refresh")
	await _settle(4)
	var talk_snapshot: Dictionary = app.call("current_talk_dock_snapshot")
	if not bool(talk_snapshot.get("visible", false)):
		failures.append("Talk dock performance probe did not expose an active dock.")
		return
	await _record_new_surface_phase("talk_dock_active", "Talk dock active")


func _probe_dialogue_surface_budget() -> void:
	app.call("start_foundation_run", "%s-dialogue" % seed_prefix)
	await _settle(4)
	var run_state: RunState = app.get("run_state")
	if run_state == null:
		failures.append("Dialogue performance probe could not access RunState.")
		return
	var environment := run_state.current_environment.duplicate(true)
	environment["id"] = "perf_dialogue_pull_tabs"
	environment["archetype_id"] = "corner_store"
	environment["kind"] = "shop"
	environment["tier"] = 1
	environment["game_ids"] = ["pull_tabs"]
	environment["event_ids"] = []
	environment["resolved_event_ids"] = []
	environment["next_archetypes"] = ["bar"]
	run_state.set_environment(environment)
	if not bool(app.call("start_dialogue", "pull_tab_clerk", {})):
		failures.append("Dialogue performance probe could not start pull_tab_clerk.")
		return
	await _settle(4)
	var talk_snapshot: Dictionary = app.call("current_talk_dock_snapshot")
	if not bool(talk_snapshot.get("visible", false)) or str(talk_snapshot.get("event_id", "")) != "dialogue:pull_tab_clerk":
		failures.append("Dialogue performance probe did not expose pull_tab_clerk in the talk dock.")
		return
	await _record_new_surface_phase("dialogue_active", "Dialogue active")


func _probe_eviction_map_transition_budget() -> void:
	app.call("start_foundation_run", "%s-eviction-map" % seed_prefix)
	await _settle(4)
	var run_state: RunState = app.get("run_state")
	if run_state == null:
		failures.append("Eviction/map transition performance probe could not access RunState.")
		return
	run_state.begin_closing_time(run_state.current_environment, run_state.game_minute_of_day(), 0)
	run_state.force_closing_time_travel()
	app.call("_refresh")
	var opened := bool(app.call("open_world_map", true))
	await _settle(6)
	var screen_snapshot: Dictionary = app.call("current_screen_snapshot")
	if not opened or not bool(screen_snapshot.get("world_map_overlay_visible", false)):
		failures.append("Eviction/map transition performance probe did not expose forced world-map travel.")
		return
	await _record_new_surface_phase("eviction_map_transition", "Eviction map transition")


func _probe_run_report_replay_budget() -> void:
	app.call("start_foundation_run", "%s-run-report" % seed_prefix)
	await _settle(4)
	var run_state: RunState = app.get("run_state")
	if run_state == null:
		failures.append("Run report performance probe could not access RunState.")
		return
	for index in range(12):
		run_state.advance_environment_turns(1)
		run_state.add_suspicion("perf_report_%d" % index, 3 if index % 2 == 0 else -2, "probe", true, {"environment_id": str(run_state.current_environment.get("id", ""))})
	run_state.fail_run(RunState.FAILURE_ABANDONED, RunState.ABANDONED_FAILURE_MESSAGE)
	app.call("_refresh")
	await _settle(6)
	var report := app.get("run_report_screen") as Control
	if report == null or not report.visible:
		failures.append("Run report performance probe did not expose the terminal report.")
		return
	report.call("_on_play_pressed")
	await _record_new_surface_phase("run_report_replay", "Run report replay")


func _record_new_surface_phase(mode: String, label: String) -> void:
	var budget := _dict(NEW_SURFACE_BUDGETS.get(mode, {}))
	if budget.is_empty():
		failures.append("New-surface performance probe has no budget for %s." % mode)
		return
	var sample_frames := maxi(1, int(budget.get("sample_frames", NEW_SURFACE_SAMPLE_FRAMES)))
	var liveness_spec := _dict(NEW_SURFACE_IDLE_LIVENESS.get(mode, {}))
	var liveness_counter := str(liveness_spec.get("counter", ""))
	var liveness_floor := _scaled_liveness_floor(liveness_spec, sample_frames)
	var environment_canvas := app.get("environment_canvas") as Control
	var start_count := 0
	if not liveness_spec.is_empty():
		if environment_canvas == null or not environment_canvas.has_method("performance_live_status"):
			failures.append("%s did not expose environment liveness counter %s." % [label, liveness_counter])
			return
		var start_liveness: Dictionary = environment_canvas.call("performance_live_status")
		start_count = int(start_liveness.get(liveness_counter, 0))
	var samples: Array = []
	for _frame_index in range(sample_frames):
		var start_usec := Time.get_ticks_usec()
		await process_frame
		samples.append(float(Time.get_ticks_usec() - start_usec) / 1000.0)
	var stats := _timing_stats(samples)
	var liveness_measured := 0
	if not liveness_spec.is_empty():
		var end_liveness: Dictionary = environment_canvas.call("performance_live_status")
		liveness_measured = maxi(0, int(end_liveness.get(liveness_counter, 0)) - start_count)
	var p95_budget := float(budget.get("frame_p95_ms", 0.0))
	observations.append({
		"seed": "new_surface:%s" % mode,
		"run_index": -1,
		"environment_id": str(app.call("current_environment_view_snapshot").get("id", "")) if app.has_method("current_environment_view_snapshot") else "",
		"mode": mode,
		"label": label,
		"frames": sample_frames,
		"avg_frame_ms": float(stats.get("avg_ms", 0.0)),
		"p95_frame_ms": float(stats.get("p95_ms", 0.0)),
		"max_frame_ms": float(stats.get("max_ms", 0.0)),
		"budget": budget,
	})
	var observation: Dictionary = observations[observations.size() - 1]
	if not liveness_spec.is_empty():
		observation["liveness_counter"] = liveness_counter
		observation["liveness_floor"] = liveness_floor
		observation["liveness_measured"] = liveness_measured
		observations[observations.size() - 1] = observation
	new_surface_coverage[mode] = int(new_surface_coverage.get(mode, 0)) + 1
	if p95_budget > 0.0 and float(stats.get("p95_ms", 0.0)) > p95_budget:
		failures.append("%s frame p95 %.3f ms exceeded %.3f ms." % [label, float(stats.get("p95_ms", 0.0)), p95_budget])
	if not liveness_spec.is_empty():
		_assert_liveness(label, liveness_counter, liveness_floor, liveness_measured)


func _synthetic_blackjack_idle_snapshot() -> Dictionary:
	return {
		"game_id": "blackjack",
		"surface_renderer": "blackjack",
		"surface_animates_idle": true,
		"reduce_motion": false,
		"dealer_profile": {"attention_base": 28, "blink_offset": 120},
		"dealer_attention_pressure": 6,
		"suspicion_level": 5,
		"patrons": [
			{"name": "Seat 1", "snitch_risk": 22, "active_snitch_risk": 22, "watching_player": true, "animation_offset": 0, "silhouette": "coat"},
			{"name": "Seat 2", "snitch_risk": 10, "active_snitch_risk": 10, "watching_player": false, "animation_offset": 300, "silhouette": "cap"},
			{"name": "Seat 3", "snitch_risk": 36, "active_snitch_risk": 36, "watching_player": true, "animation_offset": 650, "silhouette": "vest"},
			{"name": "Seat 4", "snitch_risk": 18, "active_snitch_risk": 18, "watching_player": false, "animation_offset": 910, "silhouette": "jacket"},
		],
		"table_round_timer": {
			"active": true,
			"started_msec": Time.get_ticks_msec(),
			"duration_msec": 12000,
			"remaining_msec": 12000,
		},
	}


func _synthetic_rourke_duel_idle_snapshot() -> Dictionary:
	var snapshot := _synthetic_blackjack_idle_snapshot()
	snapshot["boss_variant"] = "rourke_duel"
	snapshot["boss_duel_active"] = true
	snapshot["dealer_name"] = "Rourke"
	snapshot["dealer_profile"] = {"style_id": "rourke", "attention_base": 100, "blink_offset": 120, "uniform_accent": "house_gold"}
	snapshot["patrons"] = []
	snapshot["boss_player_stack"] = 92
	snapshot["boss_rourke_stack"] = 108
	snapshot["boss_hand_number"] = 3
	snapshot["boss_hand_limit"] = 5
	snapshot["boss_bark"] = "Read the felt, not my face."
	snapshot["boss_tell"] = "His thumb stays under the down card."
	snapshot["boss_callouts"] = [{"id": "deck_stack", "label": "Call the Stack"}, {"id": "hole_swap", "label": "Call the Swap"}]
	snapshot["can_deal"] = true
	return snapshot


func _prepare_run_for_resolve_probe(run_state: RunState, game_id: String, baseline_environment: Dictionary, baseline_rng_seed: int, baseline_rng_state: int, baseline_suspicion: Dictionary) -> void:
	run_state.bankroll = 100000
	run_state.grand_casino_chips = 0
	if game_id == "pull_tabs" or game_id == "scratch_tickets":
		# Each timing sample is an independent first purchase. Portable player
		# ownership intentionally outlives the room, so reset that ownership with
		# the baseline machine instead of measuring an ever-growing pile.
		run_state.portable_ticket_piles = {}
		run_state.inventory.erase(RunState.PULL_TAB_PILE_ITEM_ID)
		run_state.inventory.erase(RunState.SCRATCH_TICKET_PILE_ITEM_ID)
	run_state.current_environment = baseline_environment.duplicate(true)
	if run_state.grand_casino_table_uses_chips(game_id, run_state.current_environment):
		run_state.buy_grand_casino_chips(run_state.bankroll, run_state.grand_casino_chip_exchange_rate())
	run_state.rng_seed = baseline_rng_seed
	run_state.rng_state = baseline_rng_state
	run_state.suspicion = baseline_suspicion.duplicate(true)
	run_state.story_log = []
	run_state.run_status = RunState.RUN_STATUS_ACTIVE
	run_state.run_failure_reason = RunState.FAILURE_NONE
	run_state.run_failure_message = ""
	run_state.defer_next_bankroll_zero_failure = false


func _resolve_probe_ui_state(game_id: String, sample_index: int, game: GameModule, run_state: RunState, environment: Dictionary) -> Dictionary:
	match game_id:
		"pull_tabs":
			return {"pull_tab_deal_index": sample_index % 4}
		"scratch_tickets":
			return {"scratch_stock_index": sample_index % 4}
		"bar_dice":
			var roll_command := game.surface_action_command("bar_dice_roll", 0, false, {}, run_state, environment)
			var ui: Dictionary = roll_command.get("ui_state", {})
			while int(ui.get("shake_number", 0)) < 3:
				var dice: Array = ui.get("dice", []) if typeof(ui.get("dice", [])) == TYPE_ARRAY else []
				if dice.size() != 5:
					break
				var suggested: Array = game.call("_suggested_reroll_for_ruleset", dice, "ship_captain_crew")
				if suggested.is_empty():
					break
				ui["reroll"] = suggested
				var shake_command := game.surface_action_command("bar_dice_shake", 0, false, ui, run_state, environment)
				ui = shake_command.get("ui_state", ui)
			return ui
		"video_poker":
			var bet_command := game.surface_action_command("video_poker_bet_max", 0, false, {}, run_state, environment)
			var ui: Dictionary = bet_command.get("ui_state", {})
			ui["hand_active"] = true
			var machine: Dictionary = game.call("_machine_state", run_state, environment)
			var variant: Dictionary = game.call("_variant", machine)
			var hand: Array = game.call("_opening_hand", run_state, machine)
			ui["holds"] = game.call("_suggested_holds", hand, variant)
			return ui
		_:
			return {}


func _assert_required_game_surface_coverage() -> void:
	for game_id_value in REQUIRED_GAME_IDS:
		var game_id := str(game_id_value)
		if int(game_surface_coverage.get(game_id, 0)) <= 0:
			failures.append("Performance probe did not cover game surface %s." % game_id)
	if not slot_autoplay_checked:
		failures.append("Performance probe did not exercise slot autoplay.")
	if not casino_slot_preview_checked:
		failures.append("Performance probe did not exercise casino slot preview coverage.")


func _assert_required_resolve_coverage() -> void:
	for game_id_value in REQUIRED_GAME_IDS:
		var game_id := str(game_id_value)
		if int(resolve_coverage.get(game_id, 0)) <= 0:
			failures.append("Performance probe did not cover resolve path %s." % game_id)
	if not scratch_pointer_checked:
		failures.append("Performance probe did not cover the Scratch Tickets pointer path.")


func _assert_required_new_surface_coverage() -> void:
	for mode_value in NEW_SURFACE_BUDGETS.keys():
		var mode := str(mode_value)
		if int(new_surface_coverage.get(mode, 0)) <= 0:
			failures.append("Performance probe did not cover new surface budget %s." % mode)


func _game_idle_liveness_spec(game_id: String) -> Dictionary:
	var spec := _dict(GAME_IDLE_LIVENESS.get(game_id, {}))
	if spec.is_empty():
		failures.append("Performance probe has no idle liveness floor data for %s." % game_id)
	return spec


func _scaled_liveness_floor(spec: Dictionary, frames: int) -> int:
	var baseline_floor := maxi(0, int(spec.get("minimum_per_120_frames", 0)))
	if baseline_floor <= 0:
		return 0
	return maxi(1, int(ceil(float(baseline_floor) * float(maxi(1, frames)) / 120.0)))


func _assert_liveness(label: String, counter: String, floor: int, measured: int, zero_reason: String = "") -> void:
	if floor <= 0 and zero_reason.strip_edges().is_empty():
		failures.append("%s has a zero liveness floor without a documented reason." % label)
	var check := PerformanceLivenessGuardScript.evaluate(label, counter, floor, measured)
	check["zero_reason"] = zero_reason
	liveness_observations.append(check)
	if not bool(check.get("passed", false)):
		failures.append(str(check.get("message", "%s liveness failed." % label)))


func _assert_draw_budget(label: String, draw_p95_ms: float, draw_samples: int) -> void:
	if draw_samples <= 0:
		failures.append("%s did not record draw performance samples." % label)
	elif draw_p95_ms > MAX_SURFACE_DRAW_P95_MS:
		failures.append("%s draw p95 %.2f ms exceeded %.2f ms." % [label, draw_p95_ms, MAX_SURFACE_DRAW_P95_MS])


func _assert_idle_draw_budget(label: String, renderer: String, draw_p95_ms: float, draw_samples: int, animation_liveness_active: bool) -> void:
	if animation_liveness_active:
		_assert_draw_budget_with_limit("%s animated idle" % label, draw_p95_ms, draw_samples, _animated_idle_draw_budget(renderer))
		return
	if draw_samples <= 0:
		return
	if draw_p95_ms <= MAX_IDLE_SURFACE_DRAW_P95_MS:
		return
	var waiver: Dictionary = _dict(IDLE_SURFACE_DRAW_WAIVERS.get(label, {}))
	var waiver_budget := float(waiver.get("p95_ms", 0.0))
	if waiver_budget > 0.0 and draw_p95_ms <= waiver_budget:
		warnings.append("%s idle draw p95 %.2f ms exceeded scaled-headroom budget %.2f ms but stayed within waiver %.2f ms (%s)." % [
			label,
			draw_p95_ms,
			MAX_IDLE_SURFACE_DRAW_P95_MS,
			waiver_budget,
			str(waiver.get("reason", "")),
		])
		return
	failures.append("%s idle draw p95 %.2f ms exceeded %.2f ms." % [label, draw_p95_ms, MAX_IDLE_SURFACE_DRAW_P95_MS])


func _animated_idle_draw_budget(renderer: String) -> float:
	return float(ANIMATED_IDLE_SURFACE_DRAW_BUDGETS.get(renderer, MAX_SURFACE_DRAW_P95_MS))


func _assert_draw_budget_with_limit(label: String, draw_p95_ms: float, draw_samples: int, budget_ms: float) -> void:
	if draw_samples <= 0:
		failures.append("%s did not record draw performance samples." % label)
	elif draw_p95_ms > budget_ms:
		failures.append("%s draw p95 %.2f ms exceeded %.2f ms." % [label, draw_p95_ms, budget_ms])


func _assert_resolve_budget(game_id: String, stats: Dictionary, budget: Dictionary) -> void:
	if budget.is_empty():
		failures.append("Resolve performance probe has no budget for %s." % game_id)
		return
	var avg_budget := float(budget.get("avg_ms", 0.0))
	var p95_budget := float(budget.get("p95_ms", 0.0))
	var max_budget := float(budget.get("max_ms", 0.0))
	var avg_ms := float(stats.get("avg_ms", 0.0))
	var p95_ms := float(stats.get("p95_ms", 0.0))
	var max_ms := float(stats.get("max_ms", 0.0))
	if avg_budget > 0.0 and avg_ms > avg_budget:
		failures.append("%s resolve avg %.3f ms exceeded %.3f ms." % [game_id, avg_ms, avg_budget])
	if p95_budget > 0.0 and p95_ms > p95_budget:
		failures.append("%s resolve p95 %.3f ms exceeded %.3f ms." % [game_id, p95_ms, p95_budget])
	if max_budget > 0.0 and max_ms > max_budget:
		failures.append("%s resolve max %.3f ms exceeded %.3f ms." % [game_id, max_ms, max_budget])


func _assert_low_end_budget_headroom() -> void:
	_record_low_end_headroom("idle_surface_draw_p95", "Idle surface draw p95", MAX_IDLE_SURFACE_DRAW_P95_MS, false)
	_record_low_end_headroom("blackjack_idle_surface_draw_p95", "Blackjack idle surface draw p95", float(_dict(IDLE_SURFACE_DRAW_WAIVERS.get("Idle blackjack surface", {})).get("p95_ms", MAX_IDLE_SURFACE_DRAW_P95_MS)), true)
	_record_low_end_headroom("slot_autoplay_draw_p95", "Slot autoplay active draw p95", MAX_SURFACE_DRAW_P95_MS, true)


func _record_low_end_headroom(metric_id: String, label: String, budget_ms: float, waiver_allowed: bool) -> void:
	var scaled_ms := budget_ms * LOW_END_SCALE_FACTOR
	var waiver: Dictionary = _dict(LOW_END_HEADROOM_WAIVERS.get(metric_id, {}))
	var waived := waiver_allowed and not waiver.is_empty()
	var under_budget := scaled_ms <= LOW_END_FRAME_BUDGET_MS
	budget_headroom_checks.append({
		"metric_id": metric_id,
		"label": label,
		"dev_budget_ms": budget_ms,
		"low_end_scale_factor": LOW_END_SCALE_FACTOR,
		"scaled_budget_ms": scaled_ms,
		"low_end_frame_budget_ms": LOW_END_FRAME_BUDGET_MS,
		"under_scaled_budget": under_budget,
		"waived": waived,
		"waiver_reason": str(waiver.get("reason", "")) if waived else "",
		"waiver_web_gate": str(waiver.get("web_gate", "")) if waived else "",
	})
	if not under_budget and not waived:
		failures.append("%s dev budget %.3f ms scales to %.3f ms at %.1fx, exceeding %.3f ms." % [
			label,
			budget_ms,
			scaled_ms,
			LOW_END_SCALE_FACTOR,
			LOW_END_FRAME_BUDGET_MS,
		])


func _slot_machine_state(run_state: RunState, game_id: String) -> Dictionary:
	var environment: Dictionary = run_state.current_environment
	var game_states: Dictionary = environment.get("game_states", {})
	var machine: Variant = game_states.get(game_id, {})
	return (machine as Dictionary).duplicate(true) if typeof(machine) == TYPE_DICTIONARY else {}


func _write_slot_machine_state(run_state: RunState, game_id: String, machine: Dictionary) -> void:
	var environment: Dictionary = run_state.current_environment
	var game_states: Dictionary = environment.get("game_states", {})
	game_states[game_id] = machine.duplicate(true)
	environment["game_states"] = game_states
	run_state.current_environment = environment


func _interactable_object_by_id(objects: Array, object_id: String) -> Dictionary:
	for object_value in objects:
		if typeof(object_value) == TYPE_DICTIONARY and str((object_value as Dictionary).get("object_id", "")) == object_id:
			return (object_value as Dictionary).duplicate(true)
	return {}


func _open_fresh_app() -> void:
	if app != null and is_instance_valid(app):
		app.queue_free()
		await process_frame
	app = MainScene.instantiate()
	root.add_child(app)
	await _settle(3)


func _use_isolated_meta_collection_store(path: String) -> void:
	OS.set_environment(META_COLLECTION_PATH_ENV, path)
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _settle(frame_count: int = 2) -> void:
	for _index in range(frame_count):
		await process_frame


func _game_surface_canvas() -> Control:
	if app == null:
		return null
	return app.get("game_surface_canvas") as Control


func _canvas_counters(canvas: Control) -> Dictionary:
	if canvas != null and canvas.has_method("performance_counters"):
		return canvas.call("performance_counters")
	return {}


func _configured_int(env_name: String, fallback: int) -> int:
	var raw := OS.get_environment(env_name).strip_edges()
	if raw.is_empty() or not raw.is_valid_int():
		return fallback
	return maxi(1, int(raw))


func _configured_non_negative_int(env_name: String, fallback: int) -> int:
	var raw := OS.get_environment(env_name).strip_edges()
	if raw.is_empty() or not raw.is_valid_int():
		return fallback
	return maxi(0, int(raw))


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var id := str(entry)
		if not id.is_empty():
			result.append(id)
	return result


func _array_size(value: Variant) -> int:
	return (value as Array).size() if typeof(value) == TYPE_ARRAY else 0


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func _timing_stats(samples: Array) -> Dictionary:
	var sorted: Array = samples.duplicate()
	sorted.sort()
	var total := 0.0
	for sample_value in sorted:
		total += float(sample_value)
	var count := sorted.size()
	var avg := total / float(maxi(1, count))
	return {
		"avg_ms": avg,
		"p95_ms": _percentile(sorted, 0.95),
		"max_ms": float(sorted[count - 1]) if count > 0 else 0.0,
	}


func _percentile(sorted_samples: Array, percentile: float) -> float:
	if sorted_samples.is_empty():
		return 0.0
	var raw_index := int(ceil(float(sorted_samples.size()) * clampf(percentile, 0.0, 1.0))) - 1
	var index := clampi(raw_index, 0, sorted_samples.size() - 1)
	return float(sorted_samples[index])


func _write_report() -> void:
	var report := {
		"tool": "foundation_performance_probe",
		"run_count": run_count,
		"frames_per_surface": frames_per_surface,
		"seed_prefix": seed_prefix,
		"renderer_coverage": renderer_coverage,
		"game_surface_coverage": game_surface_coverage,
		"resolve_coverage": resolve_coverage,
		"scratch_pointer_checked": scratch_pointer_checked,
		"scratch_pointer_budget": SCRATCH_POINTER_BUDGET,
		"new_surface_coverage": new_surface_coverage,
		"slot_autoplay_checked": slot_autoplay_checked,
		"casino_slot_preview_checked": casino_slot_preview_checked,
		"grand_casino_living_floor_idle_checked": grand_casino_living_floor_idle_checked,
		"observations": observations,
		"resolve_observations": resolve_observations,
		"resolve_sample_count": resolve_sample_count,
		"resolve_budgets": RESOLVE_BUDGETS,
		"new_surface_budgets": NEW_SURFACE_BUDGETS,
		"game_idle_liveness_floors": GAME_IDLE_LIVENESS,
		"environment_idle_liveness_floors": NEW_SURFACE_IDLE_LIVENESS,
		"liveness_observations": liveness_observations,
		"liveness_guard_proof": liveness_guard_proof,
		"overlay_cost_observations": overlay_cost_observations,
		"low_end_scale_factor": LOW_END_SCALE_FACTOR,
		"low_end_frame_budget_ms": LOW_END_FRAME_BUDGET_MS,
		"budget_headroom_checks": budget_headroom_checks,
		"warnings": warnings,
		"failures": failures,
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write performance probe report.")
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify(report, "\t"))
	print("Foundation performance probe report written to %s" % ProjectSettings.globalize_path(REPORT_PATH))


func _print_summary() -> void:
	var surface_count := observations.size()
	print("Foundation performance probe checked %d observations across %d seed(s)." % [surface_count, run_count])
	print("Renderer coverage: %s" % JSON.stringify(renderer_coverage))
	print("Game surface coverage: %s" % JSON.stringify(game_surface_coverage))
	print("Resolve coverage: %s" % JSON.stringify(resolve_coverage))
	print("New surface coverage: %s" % JSON.stringify(new_surface_coverage))
	if failures.is_empty():
		print("Foundation performance probe passed.")
	else:
		print("Foundation performance probe failed with %d failure(s)." % failures.size())
