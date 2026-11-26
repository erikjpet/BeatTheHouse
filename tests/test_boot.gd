extends SceneTree

const MAIN := preload("res://scenes/main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var diagnostics_requested := OS.get_cmdline_user_args().has("--bth_perf=1")
	if diagnostics_requested:
		OS.set_environment("BTH_DISTRIBUTION_BUILD", "1")
	var app := MAIN.instantiate()
	root.add_child(app)
	await process_frame
	var diagnostics_blocked: bool = app.perf_telemetry_overlay == null
	# Disable periodic autosaves, not startup logic. The runner isolates all
	# storage regardless, so no existing run or profile is used.
	app.continuous_environment_clock_enabled = false
	app._queue_player_start(Callable(app, "start_foundation_run").bind("CORE-BOOT", {}, false))
	var queued: bool = app.run_state == null and app._pending_player_start.is_valid()
	var deadline := Time.get_ticks_msec() + 20000
	while app._pending_player_start.is_valid() and Time.get_ticks_msec() < deadline:
		await process_frame
	var run: RunState = app.run_state
	var passed: bool = queued and run != null and not run.is_terminal() \
		and not run.current_world_node_id().is_empty() and not run.current_environment.is_empty()
	if not passed:
		push_error("Main could not start an active seeded run in a generated room.")
	app.pending_autosave = false
	app.save_service.wait_for_async_save()
	app.queue_free()
	await process_frame
	if diagnostics_requested:
		OS.unset_environment("BTH_DISTRIBUTION_BUILD")
		var qa_app := MAIN.instantiate()
		root.add_child(qa_app)
		await process_frame
		if not diagnostics_blocked or qa_app.perf_telemetry_overlay == null:
			push_error("Diagnostics must stay disabled in distribution builds and available in QA.")
			passed = false
		qa_app.queue_free()
		await process_frame
	quit(0 if passed else 1)
