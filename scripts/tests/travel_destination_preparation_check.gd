extends "res://scripts/tests/standard_travel_integration_check.gd"

# Real Main, legal generated routes, capped native execution. The web_source
# case selects Main's production atomic-Web branch; it is not browser/WASM QA.
var preparation_evidence: Array = []
var interruption_evidence: Array = []
var natural_watch := false
var baseline := false
var drawn_frames := 0

func _on_frame_drawn() -> void:
	drawn_frames += 1

func _gameplay() -> Dictionary:
	var result := _state(app.run_state)
	result["inventory"] = app.run_state.inventory.duplicate(true)
	var sequence: Dictionary = app.run_state.current_environment.get("scenario_sequence_state", {})
	for key in ["event_request_queue", "event_request_delivery_receipts", "event_request_history"]:
		result[key] = sequence.get(key, []).duplicate(true)
	return result

func _fresh(web: bool) -> void:
	app._cancel_travel_presentation()
	app.pending_autosave = false
	_expect(app.start_foundation_run("STANDARD-TRAVEL-back_alley-0", {"modifiers":{"home_archetype_id":"back_alley"}}, false), "ordinary generated start")
	app.travel_transition_force_web_runtime_for_test = web

func _depart(target: String) -> void:
	var choice: Dictionary = app._travel_choice(target)
	_expect(bool(choice.get("enabled", false)), "legal enabled route " + target)
	var result: Dictionary = _menu_travel(target, app.travel_transition_force_web_runtime_for_test)
	_expect(bool(result.get("ok", false)), "synchronous route settles")

func _run() -> void:
	app = MainScene.instantiate()
	root.add_child(app)
	app.continuous_environment_clock_enabled = false
	app._build_travel_cinematic_overlay()
	natural_watch = "--natural-watch" in OS.get_cmdline_user_args()
	baseline = "--baseline" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() != "headless":
		RenderingServer.frame_post_draw.connect(_on_frame_drawn)
	for web in [false, true]:
		for target in ["corner_store", "gas_station_casino"]:
			await _measure_preparation(web, target)
	if not baseline:
		await _test_immediate_continue()
		await _test_immediate_skip()
		await _test_cancel_and_newer_journey()
		await _test_pending_reload()
	var report := {"suite":"travel_destination_preparation", "checks":checks,
		"passed":failures.is_empty(), "failures":failures, "runs":preparation_evidence,
		"interruptions":interruption_evidence, "natural_watch":natural_watch,
		"rendering_method":RenderingServer.get_current_rendering_method(),
		"display_server":DisplayServer.get_name(), "drawn_frames":drawn_frames,
		"platform":OS.get_name(), "baseline":baseline}
	var output := OS.get_environment("BTH_QA_EVIDENCE_DIR").path_join("destination-preparation.json")
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify(report))
	app._cancel_travel_presentation()
	app.pending_autosave = false
	app.save_service.wait_for_async_save()
	app.free()
	quit(0 if failures.is_empty() else 1)

func _measure_preparation(web: bool, target: String) -> void:
	_fresh(web)
	var departure_draw_count := drawn_frames
	var started := Time.get_ticks_usec()
	var departure_started := started
	_depart(target)
	var transaction_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var committed := _gameplay()
	if not baseline:
		var initial: Dictionary = app.current_travel_destination_preparation_snapshot()
		_expect(int(initial.get("stage", -1)) == 0 and int(initial.get("canvas_publications", -1)) == 0, "no heavy render before first cutscene frame")
		_expect(app._room_publication_save_blocked(), "save waits for destination rather than validating departure canvas")
	var frames: Array = []
	var ready_frame := -1
	var previous := Time.get_ticks_usec()
	for index in range(24):
		await process_frame
		var now := Time.get_ticks_usec()
		var stale: bool = app._environment_canvas_snapshot_is_stale()
		var job: Dictionary = app.current_travel_destination_preparation_snapshot() if app.has_method("current_travel_destination_preparation_snapshot") else {}
		frames.append({"index":index, "interval_ms":float(now - previous) / 1000.0, "canvas_stale":stale, "drawn_frames_since_departure":drawn_frames - departure_draw_count, "job":job})
		if ready_frame < 0 and not stale: ready_frame = index
		previous = now
	_expect(_same_saved_values(committed, _gameplay()), "preparation does not change gameplay or consume event requests")
	_expect(app.travel_presentation_active, "overlay retains input ownership while room prepares")
	_expect(ready_frame >= 0, "destination rendered behind overlay")
	if not baseline:
		var prepared: Dictionary = app.current_travel_destination_preparation_snapshot()
		_expect(bool(prepared.get("ready", false)) and int(prepared.get("stage", -1)) == 6, "all six preparation stages finish during cutscene")
		_expect(not app._room_publication_save_blocked(), "destination publication releases autosave gate while cutscene still owns input")
		var last_frame := int(prepared.get("start_frame", -1)) + 1
		for stage in prepared.get("stages", []):
			_expect(int(stage["frame"]) > last_frame and not bool(stage["drained"]), "presentation stages yield distinct frames after first overlay draw opportunity")
			last_frame = int(stage["frame"])
		_expect(int(prepared.get("canvas_publications", -1)) == 1, "destination canvas published once during cutscene")
		_expect(app._modal_contract_blocks_player_input() and app._simulation_progression_paused(), "prepared room remains input- and simulation-blocked")
	var watch_frames := 0
	var watch_started := Time.get_ticks_usec()
	var last_frame_usec := watch_started
	var max_watch_frame_ms := 0.0
	if natural_watch:
		while app.travel_presentation_active and Time.get_ticks_usec() - watch_started < 25000000:
			await process_frame
			var now := Time.get_ticks_usec()
			max_watch_frame_ms = maxf(max_watch_frame_ms, float(now - last_frame_usec) / 1000.0)
			last_frame_usec = now
			watch_frames += 1
		_expect(not app.travel_presentation_active and not app.travel_cinematic_overlay.active, "natural frames enter destination without Continue")
		_expect(is_equal_approx(float(app.travel_cinematic_overlay.elapsed), 8.0), "automatic entry occurs at eight cinematic seconds")
	else:
		app.travel_cinematic_overlay.skip_to_receipt()
		await process_frame
		_expect(not app.travel_presentation_active, "Skip enters destination automatically")
	var automatic_entry_ms := float(Time.get_ticks_usec() - departure_started) / 1000.0
	started = Time.get_ticks_usec()
	app.travel_cinematic_overlay.acknowledge()
	var completion_ms := float(Time.get_ticks_usec() - started) / 1000.0
	_expect(not app.travel_presentation_active, "receipt releases input")
	_expect(app.environment_canvas.is_visible_in_tree() and not app._environment_canvas_snapshot_is_stale(), "automatic handoff exposes the current destination canvas")
	_expect(not app.coach_overlay.presentation_suspended and app.modal_focus_scope.active_root() != app.travel_cinematic_overlay, "automatic handoff restores Coach eligibility and releases modal focus")
	_expect(_same_saved_values(committed, _gameplay()), "completion preserves settlement")
	var final_job: Dictionary = app.current_travel_destination_preparation_snapshot() if not baseline else {}
	if not baseline:
		_expect(int(final_job.get("canvas_publications", -1)) == 1, "completion reuses destination without a second render")
		_expect(final_job.get("stages", []).size() == 6, "completion does not repeat preparation")
	if DisplayServer.get_name() == "headless":
		await process_frame
	else:
		await RenderingServer.frame_post_draw
	var handoff_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var snapshot_path := ""
	if natural_watch and DisplayServer.get_name() != "headless":
		snapshot_path = OS.get_environment("BTH_QA_EVIDENCE_DIR").path_join("prepared-room-%s-%s.png" % ["web_source" if web else "native", target])
		root.get_texture().get_image().save_png(snapshot_path)
	preparation_evidence.append({"path":"web_source" if web else "native", "target":target,
		"transaction_ms":transaction_ms, "ready_frame":ready_frame, "completion_ms":completion_ms,
		"automatic_entry_ms":automatic_entry_ms, "cinematic_elapsed_seconds":app.travel_cinematic_overlay.elapsed,
		"watch_frames":watch_frames, "max_watch_frame_ms":max_watch_frame_ms,
		"completion_to_next_frame_ms":handoff_ms, "first_destination_frame_png":snapshot_path,
		"frames":frames, "final_job":final_job})

func _test_immediate_continue() -> void:
	_fresh(true)
	_depart("corner_store")
	var committed := _gameplay()
	app.travel_cinematic_overlay.skip_to_receipt()
	app.travel_cinematic_overlay.acknowledge()
	app.travel_cinematic_overlay.acknowledge()
	var drained: Dictionary = app.current_travel_destination_preparation_snapshot()
	_expect(bool(drained.get("ready", false)) and int(drained.get("canvas_publications", -1)) == 1, "immediate Continue drains unfinished presentation once")
	_expect(drained.get("stages", []).size() == 6, "early Continue has six stages, not two room renders")
	for stage in drained.get("stages", []): _expect(bool(stage.get("drained", false)), "early stage explicitly reported as synchronous drain")
	for index in range(10): await process_frame
	_expect(app.current_travel_destination_preparation_snapshot() == drained, "late Web deferred refresh cannot repeat acknowledged work")
	_expect(_same_saved_values(committed, _gameplay()), "early Continue and late callback do not commit gameplay")
	interruption_evidence.append({"flow":"immediate_continue", "job":drained})

func _test_immediate_skip() -> void:
	_fresh(true)
	app.autosave_slot_id = "auto_entry_acknowledged"
	var return_focus := Button.new()
	root.add_child(return_focus)
	return_focus.grab_focus()
	_depart("corner_store")
	var committed := _gameplay()
	var initial: Dictionary = app.current_travel_destination_preparation_snapshot()
	_expect(not initial.get("ready", true) and int(initial.get("stage", -1)) == 0, "Skip test starts before destination preparation")
	_expect(app.modal_focus_scope.active_root() == app.travel_cinematic_overlay, "cinematic owns focus before Skip")
	app.travel_cinematic_overlay.skip_to_receipt()
	app.travel_cinematic_overlay.skip_to_receipt()
	_expect(app.travel_presentation_active, "duplicate Skip cannot synchronously reenter host completion")
	await process_frame
	var prepared: Dictionary = app.current_travel_destination_preparation_snapshot()
	_expect(not app.travel_presentation_active and not app.travel_cinematic_overlay.active and prepared.get("ready", false), "Skip automatically enters only after the existing preparation drain")
	_expect(app.environment_canvas.is_visible_in_tree() and not app._environment_canvas_snapshot_is_stale(), "early Skip shows the ready current destination canvas")
	_expect(prepared.get("stages", []).size() == 6 and int(prepared.get("canvas_publications", -1)) == 1, "Skip drains all unfinished stages and publishes exactly once")
	_expect(root.gui_get_focus_owner() == return_focus and app.modal_focus_scope.active_root() != app.travel_cinematic_overlay, "auto-entry releases focus scope and restores live previous focus")
	_expect(not app.coach_overlay.presentation_suspended, "auto-entry releases the coach presentation owner")
	app.travel_cinematic_overlay.acknowledge()
	app.travel_cinematic_overlay.skip_to_receipt()
	for index in range(10): await process_frame
	_expect(app.current_travel_destination_preparation_snapshot() == prepared and _same_saved_values(committed, _gameplay()), "duplicate Skip/Continue and late Web callback cannot repeat preparation or settlement")
	app.pending_autosave_after_frame = -1
	app.pending_autosave_not_before_msec = 0
	app._flush_pending_autosave_if_ready()
	app.save_service.wait_for_async_save()
	_expect(app.save_service.has_run(app.autosave_slot_id), "automatic completion persists the acknowledged receipt")
	app._cancel_travel_presentation()
	_expect(app._load_foundation_run_from_slot(false), "automatically completed journey reloads through production bridge")
	_expect(not app.travel_presentation_active and not app.run_state.travel_journey_receipt.get("receipt_pending", true) and _same_saved_values(committed, _gameplay()), "completed reload has no presentation or repeated settlement")
	interruption_evidence.append({"flow":"immediate_duplicate_skip_auto_entry", "initial":initial, "job":prepared})
	return_focus.free()

func _test_cancel_and_newer_journey() -> void:
	_fresh(true)
	_depart("corner_store")
	var old_run: RunState = app.run_state
	var old_receipt: Dictionary = app.run_state.travel_journey_receipt.duplicate(true)
	var old_id := str(old_receipt.get("journey_id", ""))
	app._cancel_travel_presentation()
	for index in range(3): await process_frame
	_expect(app.current_travel_destination_preparation_snapshot().is_empty(), "cancel invalidates queued preparation")
	_expect(app.run_state.travel_journey_receipt == old_receipt, "cancel keeps durable pending receipt")
	_fresh(true)
	_depart("gas_station_casino")
	var newer := _gameplay()
	var new_job: Dictionary = app.current_travel_destination_preparation_snapshot()
	app._refresh_after_atomic_travel(old_run, old_id, true, old_run.current_environment)
	app._on_travel_presentation_completed(old_id)
	_expect(app.current_travel_destination_preparation_snapshot() == new_job, "old Web callback and old completion cannot touch a newer journey")
	# Replace a partially prepared destination before its canvas stage.
	while int(app.current_travel_destination_preparation_snapshot().get("stage", 0)) < 3:
		await process_frame
	var partial: Dictionary = app.current_travel_destination_preparation_snapshot()
	_expect(int(partial.get("canvas_publications", -1)) == 0, "interruption occurs after model but before canvas publication")
	_expect(_same_saved_values(newer, _gameplay()), "partial preparation does not commit gameplay")
	_fresh(false)
	var replacement_signature: String = app.rendered_environment_snapshot_signature
	var replacement := _gameplay()
	for index in range(12): await process_frame
	_expect(app.current_travel_destination_preparation_snapshot().is_empty() and app.rendered_environment_snapshot_signature == replacement_signature, "cancelled partial model cannot overwrite new-run canvas")
	_expect(_same_saved_values(replacement, _gameplay()), "new run is unchanged by obsolete preparation")
	interruption_evidence.append({"flow":"cancel_newer_and_partial_replacement", "partial_job":partial})

func _test_pending_reload() -> void:
	_fresh(true)
	app.autosave_slot_id = "destination_preparation_pending"
	_depart("corner_store")
	var committed := _gameplay()
	for index in range(16): await process_frame
	app.pending_autosave_after_frame = -1
	app.pending_autosave_not_before_msec = 0
	app._flush_pending_autosave_if_ready()
	app.save_service.wait_for_async_save()
	_expect(app.save_service.has_run(app.autosave_slot_id), "host saves pending receipt after staged publication")
	app._cancel_travel_presentation()
	_expect(app._load_foundation_run_from_slot(false), "production save-load bridge reloads pending receipt")
	_expect(app.travel_cinematic_overlay.phase == "receipt" and app.travel_presentation_active, "reload is static pending summary, never a second journey")
	for index in range(16): await process_frame
	var loaded_job: Dictionary = app.current_travel_destination_preparation_snapshot()
	_expect(bool(loaded_job.get("ready", false)), "loaded destination prepares behind static receipt")
	_expect(_same_saved_values(committed, _gameplay()), "reload does not change settlement or request queues")
	app.travel_cinematic_overlay.acknowledge()
	_expect(int(app.current_travel_destination_preparation_snapshot().get("canvas_publications", -1)) == 1, "loaded receipt releases without a second render")
	_expect(_same_saved_values(committed, _gameplay()), "loaded acknowledgment does not commit gameplay")
	interruption_evidence.append({"flow":"pending_reload", "job":loaded_job})
