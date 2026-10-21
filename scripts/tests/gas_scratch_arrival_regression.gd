extends "res://scripts/tests/gas_scratch_membership_one_arrival.gd"

# Reuses the exact original one-arrival host sequence. Only successful runs
# proceed to another physical room interaction and the real host save path.
var ending := false


func _finish(forced_exit_code: int = -1) -> void:
	if forced_exit_code >= 0 or not failures.is_empty():
		super._finish(forced_exit_code)
		return
	if not ending:
		ending = true
		call_deferred("_qualify_arrival_end")


func _qualify_arrival_end() -> void:
	observations["stage"] = "arrival"
	var interacted := false
	var canvas: Control = app.get("environment_canvas")
	for value in canvas.get("foundation_scene_objects"):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = value
		var identity := str(object_data.get("id", ""))
		if identity.begins_with("game:") and identity != "game:scratch_tickets" \
				and bool(object_data.get("interactive", false)) and not bool(object_data.get("disabled", false)):
			interacted = bool(app.call("activate_interactable_object", identity)) and str(app.get("current_screen")) == "GAME"
			observations["other_room_object"] = identity
			_require(interacted, "Another real room object refused interaction after File")
			app.call("back_to_environment")
			await process_frame
			await process_frame
			break
	_require(interacted, "No second physical game completed a normal room interaction")
	var controller: Script = load("res://scripts/ui/environment_interaction_controller.gd")
	var proof: Dictionary = controller._object_manifest_join_proof(run.current_environment.duplicate(true))
	observations["final_strict_join"] = {"ok": bool(proof.get("ok", false)), "errors": proof.get("errors", [])}
	_require(bool(proof.get("ok", false)), "Exact arrival sequence ended with invalid strict room authority")
	var saved := bool(app.call("_autosave_foundation_run", "Exact arrival regression saved", true))
	observations["real_host_save_succeeded"] = saved
	_require(saved, "The exact arrival sequence could not save through the normal host")
	observations["removal_unit_passed"] = false
	if failures.is_empty():
		_exercise_detached_scalper_removal(controller)
	super._finish()


func _exercise_detached_scalper_removal(controller: Script) -> void:
	# This is one producer-removal check on an owned copy, not another host run.
	var candidate := RunState.new()
	candidate.from_dict(run.to_dict())
	var library: ContentLibrary = app.get("library")
	var baseline := candidate.scenario_finalize_installed_environment(library)
	var details := {"baseline_finalization_ok": bool(baseline.get("ok", false)), "baseline_errors": baseline.get("errors", [])}
	observations["removal_unit"] = details
	if not _require(bool(baseline.get("ok", false)), "Detached removal baseline could not finalize"):
		return
	var baseline_proof: Dictionary = controller._object_manifest_join_proof(candidate.current_environment.duplicate(true))
	if not _require(bool(baseline_proof.get("ok", false)), "Detached removal baseline failed strict room authority"):
		return
	var environment := candidate.current_environment
	var states: Dictionary = environment.get("game_states", {})
	var machine: Dictionary = states.get("scratch_tickets", {})
	if not _require(bool(machine.get("scalper_present", false)), "Removal unit did not begin with the arrived scalper"):
		return
	var original_digest := str(environment.get("scenario_semantic_digest", ""))
	var original_version := int(environment.get("scenario_semantic_inventory_version", 0))
	# Baseline finalization may perform the normal cold reentry. Capture the
	# journal only after that finishes, then change precisely one producer flag.
	var before := _removal_signature(candidate)
	var failure_count := failures.size()
	machine["scalper_present"] = false
	states["scratch_tickets"] = machine
	environment["game_states"] = states
	var membership := candidate.prepare_current_environment_object_membership_for_publication()
	details["membership_ok"] = bool(membership.get("ok", false))
	details["membership_errors"] = membership.get("errors", [])
	if not _require(bool(membership.get("ok", false)), "Detached scalper removal failed normal membership publication"):
		return
	var finalized := candidate.scenario_finalize_installed_environment(library)
	details["finalization_ok"] = bool(finalized.get("ok", false))
	details["finalization_errors"] = finalized.get("errors", [])
	_require(bool(finalized.get("ok", false)), "Detached scalper removal invalidated the scenario")
	environment = candidate.current_environment
	var matching_row := false
	for row_value in (environment.get("object_manifest", {}) as Dictionary).get("rows", []):
		var row: Dictionary = row_value
		if str(row.get("presentation_object_id", row.get("object_id", ""))) == "dialogue:scratch_ticket_scalper":
			matching_row = true
	_require(not matching_row, "Removed scalper retained a physical manifest row")
	_require(not (environment.get("scenario_sequence_base_layout_object_rects", {}) as Dictionary).has("dialogue:scratch_ticket_scalper"), "Removed scalper survived in the immutable baseline hint")
	var proof: Dictionary = controller._object_manifest_join_proof(environment.duplicate(true))
	details["strict_join"] = {"ok": bool(proof.get("ok", false)), "errors": proof.get("errors", [])}
	_require(bool(proof.get("ok", false)), "Detached scalper removal failed complete strict room authority")
	_require(bool(candidate.call("_scenario_semantic_ready")), "Detached scalper removal lost semantic readiness")
	_require(str(environment.get("scenario_semantic_digest", "")) == original_digest and int(environment.get("scenario_semantic_inventory_version", 0)) == original_version, "Detached scalper removal changed the original scenario seal")
	var after := _removal_signature(candidate)
	details["before_state_sha256"] = JSON.stringify(before).sha256_text()
	details["after_state_sha256"] = JSON.stringify(after).sha256_text()
	_require(before == after, "Detached scalper removal changed cash, RNG, clock, tickets or causal journal")
	observations["removal_unit_passed"] = failures.size() == failure_count


func _removal_signature(candidate: RunState) -> Dictionary:
	var environment := candidate.current_environment
	var machine: Dictionary = (environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	var ticket_fields: Dictionary = {}
	for field_value in RunState.PORTABLE_TICKET_PLAYER_FIELDS.get("scratch_tickets", []):
		var field := str(field_value)
		if machine.has(field):
			var value: Variant = machine.get(field)
			ticket_fields[field] = value.duplicate(true) if typeof(value) in [TYPE_ARRAY, TYPE_DICTIONARY] else value
	return {
		"cash": candidate.bankroll,
		"rng_state": candidate.rng_state,
		"game_clock_minutes": candidate.game_clock_minutes,
		"portable_ticket_piles": candidate.portable_ticket_piles.duplicate(true),
		"machine_player_fields": ticket_fields,
		"scenario_sequence_state": (environment.get("scenario_sequence_state", {}) as Dictionary).duplicate(true),
		"scenario_host_transaction_ledger": candidate.scenario_host_transaction_ledger.duplicate(true),
	}
