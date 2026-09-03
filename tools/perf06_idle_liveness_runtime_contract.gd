extends SceneTree

const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")

var failures: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.size = Vector2(960, 540)
	root.add_child(canvas)
	canvas.call("render_game_snapshot", {
		"game_id": "perf06_idle_contract",
		"surface_renderer": "blackjack",
		"surface_animates_idle": true,
		"reduce_motion": false,
	})
	await process_frame
	canvas.call("reset_performance_counters")
	for _frame_index in range(120):
		canvas.call("debug_advance_idle_liveness", 1.0 / 60.0)
	await process_frame
	await process_frame
	var counters: Dictionary = canvas.call("performance_counters")
	var runtime: Dictionary = canvas.call("surface_runtime_status")
	var live: Dictionary = canvas.call("performance_live_status")
	_check(int(counters.get("surface_animation_scheduler_elapsed_msec", -1)) >= 2000, "Scheduler elapsed did not preserve the complete reset-scoped interval.")
	_check(int(counters.get("surface_animation_redraw_count", 0)) >= 120, "Native idle scheduler did not record the full production cadence.")
	_check(is_equal_approx(float(counters.get("surface_idle_animation_fps", 0.0)), 60.0), "Performance counters omitted the native effective idle FPS.")
	_check(int(counters.get("draw_sample_count", 0)) > 0, "Scheduled idle redraws produced no paired canvas draw.")
	_check(int(runtime.get("surface_animation_scheduler_elapsed_msec", -1)) == int(counters.get("surface_animation_scheduler_elapsed_msec", -2)) and is_equal_approx(float(runtime.get("surface_idle_animation_fps", 0.0)), 60.0), "Runtime status omitted cadence or scheduler elapsed.")
	_check(int(live.get("surface_animation_scheduler_elapsed_msec", -1)) == int(counters.get("surface_animation_scheduler_elapsed_msec", -2)) and is_equal_approx(float(live.get("surface_idle_animation_fps", 0.0)), 60.0), "Lightweight live status omitted cadence or scheduler elapsed.")

	canvas.call("reset_performance_counters")
	for _sample_index in range(520):
		canvas.call("_record_draw_performance", Time.get_ticks_usec())
	var saturated: Dictionary = canvas.call("performance_counters")
	_check(int(saturated.get("draw_sample_count", -1)) == 520, "The liveness draw total saturated with the timing buffer.")
	_check(int(saturated.get("draw_sample_buffer_count", -1)) == 512, "The draw timing buffer lost its bounded 512-sample contract.")
	canvas.call("reset_performance_counters")
	var reset: Dictionary = canvas.call("performance_counters")
	_check(int(reset.get("draw_sample_count", -1)) == 0, "Reset retained the monotonic draw total.")
	_check(int(reset.get("draw_sample_buffer_count", -1)) == 0, "Reset retained buffered draw samples.")
	_check(int(reset.get("surface_animation_scheduler_elapsed_msec", -1)) == 0, "Reset retained scheduler elapsed time.")

	canvas.queue_free()
	await process_frame
	if failures.is_empty():
		print("PERF06_IDLE_LIVENESS_RUNTIME_CONTRACT PASS")
		quit(0)
		return
	for failure_value in failures:
		push_error(str(failure_value))
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
