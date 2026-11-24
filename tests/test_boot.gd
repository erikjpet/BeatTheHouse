extends SceneTree

const MAIN := preload("res://scenes/main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var app := MAIN.instantiate()
	root.add_child(app)
	await process_frame
	# Disable periodic autosaves, not startup logic. The runner isolates all
	# storage regardless, so no existing run or profile is used.
	app.continuous_environment_clock_enabled = false
	var started: bool = app.start_foundation_run("CORE-BOOT", {}, false)
	var run: RunState = app.run_state
	var passed := started and run != null and not run.is_terminal() \
		and not run.current_world_node_id().is_empty() and not run.current_environment.is_empty()
	if not passed:
		push_error("Main could not start an active seeded run in a generated room.")
	app.pending_autosave = false
	app.save_service.wait_for_async_save()
	app.queue_free()
	await process_frame
	quit(0 if passed else 1)
