extends SceneTree

# Game-surface performance regression probe. It enters real foundation games,
# idles them for a fixed frame budget, and verifies the frame tick path is not
# rebuilding full surface snapshots when no surface automation is active.

const MainScene := preload("res://scenes/main.tscn")
const REPORT_PATH := "user://foundation_performance_probe_report.json"
const DEFAULT_SEED_PREFIX := "FOUNDATION-PERF"
const DEFAULT_RUN_COUNT := 8
const DEFAULT_FRAMES_PER_SURFACE := 120
const MAX_SURFACE_DRAW_P95_MS := 16.0
const MAX_SEVERE_IDLE_AVG_MS := 45.0
const MAX_SEVERE_FOCUS_AVG_MS := 45.0
const FOCUS_PROBE_FRAMES := 18
const MAX_FOCUS_OBJECTS_PER_SEED := 4
const REQUIRED_GAME_IDS := [
	"pull_tabs",
	"slot",
	"bar_dice",
	"blackjack",
	"baccarat",
	"roulette",
	"video_poker",
]

var app: Control
var failures: Array = []
var warnings: Array = []
var observations: Array = []
var renderer_coverage := {}
var game_surface_coverage := {}
var slot_autoplay_checked := false
var casino_slot_preview_checked := false
var run_count := DEFAULT_RUN_COUNT
var frames_per_surface := DEFAULT_FRAMES_PER_SURFACE
var seed_prefix := DEFAULT_SEED_PREFIX


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	run_count = _configured_int("BTH_PERF_RUNS", DEFAULT_RUN_COUNT)
	frames_per_surface = _configured_int("BTH_PERF_FRAMES", DEFAULT_FRAMES_PER_SURFACE)
	seed_prefix = OS.get_environment("BTH_PERF_SEED_PREFIX")
	if seed_prefix.strip_edges().is_empty():
		seed_prefix = DEFAULT_SEED_PREFIX
	await _open_fresh_app()
	for run_index in range(run_count):
		await _probe_seed("%s-%02d" % [seed_prefix, run_index + 1], run_index)
	await _probe_practice_game_surface_coverage()
	await _probe_casino_slot_preview_coverage()
	_assert_required_game_surface_coverage()
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
		if not bool(app.call("focus_interactable_object", object_id)):
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
			"elapsed_ms": float(elapsed_usec) / 1000.0,
			"avg_frame_ms": avg_ms,
			"camera_target_refresh_count": target_refresh_count,
			"target_recalculated_during_glide": target_recalculated,
		})
		if target_recalculated:
			failures.append("Environment focus target recalculated during glide for %s in seed %s." % [object_id, seed])
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
		canvas.queue_redraw()
		await process_frame
	var elapsed_usec := Time.get_ticks_usec() - start_usec
	var counters := _canvas_counters(canvas)
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
		"draw_samples": draw_samples,
		"full_snapshot_calls": int(counters.get("full_snapshot_calls", 0)),
		"runtime_status_calls": int(counters.get("runtime_status_calls", 0)),
	})
	if int(counters.get("full_snapshot_calls", 0)) > 0:
		failures.append("Idle %s surface rebuilt full snapshots %d times." % [renderer, int(counters.get("full_snapshot_calls", 0))])
	# FoundationMain polls this lightweight status while deciding whether a
	# surface needs automation or realtime advancement. Keep it in the report;
	# only full snapshot rebuilds indicate the expensive regression T7.1 guards.
	if avg_ms > MAX_SEVERE_IDLE_AVG_MS:
		failures.append("Idle %s surface averaged %.2f ms per frame, above %.2f ms." % [renderer, avg_ms, MAX_SEVERE_IDLE_AVG_MS])
	_assert_draw_budget("Idle %s surface" % renderer, draw_p95_ms, draw_samples)
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


func _assert_required_game_surface_coverage() -> void:
	for game_id_value in REQUIRED_GAME_IDS:
		var game_id := str(game_id_value)
		if int(game_surface_coverage.get(game_id, 0)) <= 0:
			failures.append("Performance probe did not cover game surface %s." % game_id)
	if not slot_autoplay_checked:
		failures.append("Performance probe did not exercise slot autoplay.")
	if not casino_slot_preview_checked:
		failures.append("Performance probe did not exercise casino slot preview coverage.")


func _assert_draw_budget(label: String, draw_p95_ms: float, draw_samples: int) -> void:
	if draw_samples <= 0:
		failures.append("%s did not record draw performance samples." % label)
	elif draw_p95_ms > MAX_SURFACE_DRAW_P95_MS:
		failures.append("%s draw p95 %.2f ms exceeded %.2f ms." % [label, draw_p95_ms, MAX_SURFACE_DRAW_P95_MS])


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


func _write_report() -> void:
	var report := {
		"tool": "foundation_performance_probe",
		"run_count": run_count,
		"frames_per_surface": frames_per_surface,
		"seed_prefix": seed_prefix,
		"renderer_coverage": renderer_coverage,
		"game_surface_coverage": game_surface_coverage,
		"slot_autoplay_checked": slot_autoplay_checked,
		"casino_slot_preview_checked": casino_slot_preview_checked,
		"observations": observations,
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
	if failures.is_empty():
		print("Foundation performance probe passed.")
	else:
		print("Foundation performance probe failed with %d failure(s)." % failures.size())
