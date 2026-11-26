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
	app.profile_inventory.tutorial_completed = true
	app.seed_input.text = "CORE-BOOT"
	app.new_run_button.pressed.emit()
	var queued: bool = app.run_state == null and app._pending_player_start.is_valid()
	await _wait_for_room(app)
	var run: RunState = app.run_state
	var passed: bool = queued and run != null and not run.is_terminal() and run.seed_text == "CORE-BOOT" \
		and not run.current_world_node_id().is_empty() and run.room_presentation_revision() != 0 \
		and app.environment_canvas != null and app.environment_canvas.is_visible_in_tree()
	if not passed:
		push_error("Main could not start an active seeded run in a generated room.")
	else:
		var node_id := run.current_world_node_id()
		var bankroll := run.bankroll
		var rng_state := run.rng_state
		if app.return_to_main_menu():
			app.new_run_button.pressed.emit()
			await _wait_for_room(app)
			var resumed: RunState = app.run_state
			passed = resumed != null and resumed != run and resumed.seed_text == run.seed_text \
				and resumed.current_world_node_id() == node_id and resumed.room_presentation_revision() != 0 \
				and resumed.bankroll == bankroll and resumed.rng_state == rng_state \
				and app.run_screen.is_visible_in_tree()
		else:
			passed = false
		if not passed:
			push_error("Continue failed to restore the newly saved room and its accounting.")
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


func _wait_for_room(app: Node) -> void:
	var deadline := Time.get_ticks_msec() + 20000
	while (app.run_screen == null or not app.run_screen.is_visible_in_tree()) and Time.get_ticks_msec() < deadline:
		await process_frame
