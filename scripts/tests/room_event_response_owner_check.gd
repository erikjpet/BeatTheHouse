extends RefCounted

class GuardedModule extends EventModule:
	func can_resolve_ordinary_atomically(_run_state: RunState, _choice_id: String) -> bool:
		return false

# Caller supplies a settled, disposable host and its authored room event.
# No fixture, profile or storage path is embedded here. This synchronous
# contract check does not claim that a browser painted between native steps.
static func check(app: Variant, event_id: String, choice_id: String) -> Dictionary:
	var failures: Array = []
	var verify := func(condition: bool, label: String) -> void:
		if not condition: failures.append(label)
	if app.run_state == null or app.pending_autosave or app.save_service.async_save_in_flight():
		return {"passed": false, "failures": ["A settled disposable run is required."]}
	var original: Dictionary = app._foundation_lifecycle_snapshot()
	verify.call(app.focus_interactable_object("event:" + event_id), "focus authored inline event")
	var focused: Dictionary = app._foundation_lifecycle_snapshot()
	var before := var_to_bytes(app.run_state.to_dict())
	var generation: int = app.autosave_dirty_generation
	verify.call(app._can_stage_room_event_response(event_id), "inline route is eligible")
	var selected: String = app.selected_object_id
	app.selected_object_id = "event:unrelated"
	verify.call(not app._can_stage_room_event_response(event_id), "unrelated focus cannot own response")
	app.selected_object_id = selected
	var context: String = app.current_context_mode
	app.current_context_mode = app.CONTEXT_MODE_ROOM
	verify.call(not app._can_stage_room_event_response(event_id), "unrelated context cannot own response")
	app.current_context_mode = context
	var reference_module := EventModule.new()
	reference_module.setup(app.library.event(event_id), app.library)
	var expects_atomic := reference_module.can_resolve_ordinary_atomically(app.run_state, choice_id)
	var reference_begin := reference_module.begin_owned_resolution(app.run_state, app.run_state.current_environment, choice_id)
	var expected_partial := var_to_bytes(app.run_state.to_dict())
	var reference_model_result: Dictionary = reference_begin["result"] if bool(reference_begin["complete"]) else reference_module.finish_owned_resolution()
	verify.call(bool(reference_model_result.get("ok", false)), "reference model resolves")
	var expected_model := var_to_bytes(app.run_state.to_dict())
	app._restore_foundation_lifecycle_snapshot(focused)
	app._refresh_after_foundation_lifecycle_rollback(focused)
	verify.call(app.activate_event_choice_action(event_id, choice_id), "reference synchronous action")
	var expected := var_to_bytes(app.run_state.to_dict())
	var expected_result: Dictionary = app.last_hook_result.duplicate(true)
	app._restore_foundation_lifecycle_snapshot(focused)
	app._refresh_after_foundation_lifecycle_rollback(focused)
	verify.call(app.activate_interactable_object("event_response:%s:%s" % [event_id, choice_id]), "actual canvas callback accepts once")
	var first_generation: int = app._event_response_transaction["generation"]
	verify.call(app._simulation_progression_paused() and app._guard_player_input_route(), "accepted owner gates clock/input")
	verify.call(not app.activate_event_choice_action(event_id, choice_id), "duplicate public action rejected")
	verify.call(not app._activate_event_response_action("event_response:%s:%s" % [event_id, choice_id]), "duplicate token rejected")
	verify.call(var_to_bytes(app.run_state.to_dict()) == before, "accepted input does not resolve early")
	app._advance_event_response_transaction(false)
	var canvas := var_to_bytes(app.environment_canvas.foundation_snapshot)
	app._advance_event_response_transaction(false)
	var atomic := bool(app._event_response_transaction.get("atomic_model", false))
	verify.call(atomic == expects_atomic and int(app._event_response_transaction.get("step", -1)) == (3 if atomic else 2), "bounded model atomic; world-map command retains guarded continuation")
	verify.call(var_to_bytes(app.run_state.to_dict()) == (expected_model if atomic else expected_partial), "owned model preserves complete state/RNG before presentation")
	verify.call(var_to_bytes(app.environment_canvas.foundation_snapshot) == canvas, "partial turn has no visible model alias")
	verify.call(app.autosave_dirty_generation == generation, "partial turn cannot queue persistence")
	var module: EventModule = app._event_response_transaction["prepared"]["module"]
	var partial := var_to_bytes(app.run_state.to_dict())
	var duplicate: Dictionary = module.begin_owned_resolution(app.run_state, app.run_state.current_environment, choice_id)
	verify.call(bool(duplicate["complete"]) and not bool(duplicate["result"].get("ok", false)), "module cannot acquire a second continuation")
	verify.call(var_to_bytes(app.run_state.to_dict()) == partial, "duplicate continuation has no effect")
	app._drain_event_response_before_exit()
	verify.call(app._event_response_transaction.is_empty() and not app.event_choice_resolution_pending, "finite close drain releases owner")
	verify.call(var_to_bytes(app.run_state.to_dict()) == expected and app.last_hook_result == expected_result, "full state/RNG/result/order match synchronous reference")
	verify.call(not bool(module.finish_owned_resolution().get("ok", false)), "finished model continuation cannot replay")
	app._drain_event_response_before_exit()
	verify.call(var_to_bytes(app.run_state.to_dict()) == expected, "second close drain is a no-op")
	app._restore_foundation_lifecycle_snapshot(focused)
	app._refresh_after_foundation_lifecycle_rollback(focused)
	for mutation in ["bankroll", "authority", "numbers_config"]:
		verify.call(app.activate_interactable_object("event_response:%s:%s" % [event_id, choice_id]), "accept late-writer countercase")
		app._advance_event_response_transaction(true, first_generation)
		verify.call(int(app._event_response_transaction["step"]) == 0, "retired callbacks cannot advance a new owner")
		app._advance_event_response_transaction(false)
		# Exercise the retained complex-provider path through the same real owner.
		# Its asynchronous boundary still requires exact late-writer rejection.
		var original_module: EventModule = app._event_response_transaction["prepared"]["module"]
		var guarded := GuardedModule.new()
		guarded.setup(original_module.definition, original_module.content_library)
		app._event_response_transaction["prepared"]["module"] = guarded
		app._advance_event_response_transaction(false)
		if mutation == "bankroll": app.run_state.bankroll += 1
		elif mutation == "authority": app.run_state.current_environment["scenario_layout_authority_digest"] = "late-unowned-writer"
		else: app.run_state.numbers_state.config["late_unowned_writer"] = true
		app._event_response_transaction["refresh_requested"] = true
		app._advance_event_response_transaction(false)
		verify.call(not bool(app._event_response_transaction["result"].get("ok", false)), "reject intervening writer: " + mutation)
		app._drain_event_response_before_exit()
		verify.call(var_to_bytes(app.run_state.to_dict()) == before and app.autosave_dirty_generation == generation, "rejected writer restores complete input without save: " + mutation)
		verify.call(not app.run_state.numbers_state.config.has("late_unowned_writer"), "restore mutable submodel")
		app._restore_foundation_lifecycle_snapshot(focused)
		app._refresh_after_foundation_lifecycle_rollback(focused)
	app._restore_foundation_lifecycle_snapshot(original)
	app._refresh_after_foundation_lifecycle_rollback(original)
	return {"passed": failures.is_empty(), "failures": failures}
