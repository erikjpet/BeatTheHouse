extends "res://scripts/tests/destination_travel_integration_check.gd"

# Reuse the real progressed route and full five-flow/save-load assertions. The
# additional checks exercise the boundary before deferred web presentation can
# refresh, then verify that subsequent drains and greetings are idempotent.
func _run() -> void:
	app = MainScene.instantiate()
	root.add_child(app)
	app.continuous_environment_clock_enabled = false
	app._build_travel_cinematic_overlay()
	_expect(is_instance_valid(app.get("travel_cinematic_overlay")), "Grand snapshot overlay constructs")
	if failures.is_empty():
		app.travel_cinematic_overlay.completed.connect(_on_presentation_completed)
		_test_comparison_boundaries()
		var started := _start_fixture("STANDARD-TRAVEL-back_alley-0", "back_alley", true, ["grand_casino"])
		_expect(started, "Grand snapshot progressed fixture starts")
		if started:
			_consider_route("grand_casino", "STANDARD-TRAVEL-back_alley-0", "back_alley", [], true)
		var fixture := _destination_fixture("grand_casino")
		_expect(not fixture.is_empty(), "Grand snapshot uses an actual enabled route")
		if not fixture.is_empty():
			await _test_destination(fixture)
			await _check_greeting_delivery(fixture)
	print(JSON.stringify({"suite":"grand_arrival_snapshot", "checks":checks, "failures":failures}))
	app._cancel_travel_presentation()
	app.pending_autosave = false
	app.save_service.wait_for_async_save()
	app.free()
	quit(0 if failures.is_empty() else 1)

func _check_greeting_delivery(fixture: Dictionary) -> void:
	for flow in ["desktop", "web_atomic", "desktop_reduced", "web_atomic_reduced"]:
		var web := str(flow).begins_with("web_atomic")
		var reduced := str(flow).ends_with("reduced")
		app.user_settings.reduce_motion = reduced
		app.travel_transition_force_web_runtime_for_test = web
		app.travel_cinematic_overlay.force_missing_art_for_test = false
		_restore(fixture["baseline"])
		var previous_environment: Dictionary = app.run_state.current_environment.duplicate(true)
		var choice: Dictionary = app._travel_choice("grand_casino")
		var result: Dictionary = app._travel_to("grand_casino", str(choice.get("label", "")), choice, web)
		var prefix := "Grand snapshot/" + str(flow) + ": "
		_expect(bool(result.get("ok", false)) and app.travel_presentation_active, prefix + "ordinary route settles synchronously")
		if not bool(result.get("ok", false)): continue
		var greeting: Dictionary = app.run_state.pending_talk_event("dialogue:normal_grand_host_greeting").duplicate(true)
		var environment: Dictionary = app.run_state.current_environment.duplicate(true)
		var sequence: Dictionary = environment.get("scenario_sequence_state", {})
		var snapshot_sequence: Dictionary = greeting.get("context", {}).get("environment_snapshot", {}).get("scenario_sequence_state", {})
		var live_snapshot: Dictionary = RunState.environment_context_snapshot(environment)
		_expect(not greeting.is_empty() and not snapshot_sequence.is_empty(), prefix + "one owned greeting has a scenario snapshot")
		_expect(snapshot_sequence == live_snapshot.get("scenario_sequence_state", {}), prefix + "greeting freezes the already delivered live sequence")
		_expect(sequence.get("semantic_state", {}).get("transition_queue", []).is_empty(), prefix + "no arrival transition remains before deferred rendering")
		_expect(sequence.get("transition_delivery_receipts", []).size() == 1, prefix + "arrival cue has exactly one delivery receipt")
		_expect(sequence.get("active_stages", []).size() == (0 if reduced else 1), prefix + "reduced motion retains receipt without starting a room stage")
		var settled := _state(app.run_state)
		var receipt: Dictionary = app.run_state.travel_journey_receipt.duplicate(true)
		var feedback: Dictionary = app.last_hook_result.duplicate(true)
		_expect(app._consume_scenario_transitions().is_empty(), prefix + "second drain emits no message")
		_expect(app.run_state.current_environment == environment, prefix + "second drain changes neither sequence nor gameplay request queue")
		app._queue_normal_grand_host_greeting(previous_environment)
		_expect(app._enqueue_normal_grand_host_greeting_without_refresh(true), prefix + "existing greeting is recognized")
		_expect(app.run_state.pending_talk_event("dialogue:normal_grand_host_greeting") == greeting and _state(app.run_state) == settled, prefix + "repeat greeting does not recapture or duplicate queued ownership")
		_expect(app.run_state.travel_journey_receipt == receipt and app.last_hook_result == feedback, prefix + "fare receipt and Result feedback remain visible")
		app._refresh()
		await process_frame
		_expect(app.run_state.current_environment.get("scenario_sequence_state", {}) == sequence and _state(app.run_state) == settled, prefix + "later refresh cannot redeliver stage or change event and gameplay outcomes")
		_expect(app.pending_autosave or app.save_service.has_run(app.autosave_slot_id), prefix + "ordinary autosave remains queued or written")
		app.travel_cinematic_overlay.skip_to_receipt()
		app.travel_cinematic_overlay.acknowledge()
		await process_frame
