extends RefCounted

# Exact pre-fix producer coordinator retained as the behavioral reference.
class OriginalProjectionRun extends RunState:
	func _sync_all_runtime_object_manifest_entries(environment: Dictionary) -> bool:
		var prior_entries := JsonCoerceScript._copy_array(environment.get("runtime_object_manifest_entries", []))
		var changed := _sync_contextual_runtime_object_manifest_entries(environment)
		changed = _sync_numbers_runtime_object_manifest_entries(environment) or changed
		changed = _sync_crew_heist_runtime_object_manifest_entries(environment) or changed
		changed = _sync_grand_casino_runtime_object_manifest_entries(environment) or changed
		# Repair baselines captured by older builds while a runtime occupant was
		# visible. Include both sides of the projection update so an actor that leaves
		# on this boundary cannot reappear as immutable scenario geometry.
		if environment.has("scenario_sequence_base_layout_object_rects"):
			var baseline_rects := JsonCoerceScript._copy_dict(environment.get("scenario_sequence_base_layout_object_rects", {}))
			var repaired := false
			for entry_value in prior_entries + JsonCoerceScript._copy_array(environment.get("runtime_object_manifest_entries", [])):
				var entry := JsonCoerceScript._copy_dict(entry_value)
				if str(entry.get("runtime_owner", "")).strip_edges().is_empty() \
						and str(entry.get("spot_field", "")) != "runtime_object_manifest_entries":
					continue
				var presentation_id := str(entry.get("presentation_object_id", entry.get("object_id", ""))).strip_edges()
				if not presentation_id.is_empty() and baseline_rects.erase(presentation_id):
					repaired = true
			# The scratch machine directly projects its one visit-scoped person, so
			# it need not have a row in the separate RunState owner array. Remove the
			# known runtime hint even after departure, when no live row remains. An
			# older immutable seal is reconstructed separately against its exact digest.
			if _scratch_scalper_environment(environment) and baseline_rects.erase("dialogue:scratch_ticket_scalper"):
				repaired = true
			if repaired:
				environment["scenario_sequence_base_layout_object_rects"] = baseline_rects
				changed = true
		return changed


static func check(restored: RunState, library: ContentLibrary) -> Dictionary:
	var checks: Array = []
	var failures: Array = []
	var expect := func(ok: bool, label: String) -> void:
		checks.append(label)
		if not ok: failures.append(label)
	var original := var_to_bytes(restored.to_dict())
	var fast := _clone(restored, false)
	var slow := _clone(restored, true)
	var before_entries := var_to_bytes(fast.current_environment.get("runtime_object_manifest_entries", []))
	expect.call(not fast._sync_all_runtime_object_manifest_entries(fast.current_environment) and slow._sync_all_runtime_object_manifest_entries(slow.current_environment), "stable_multiowner_projection_is_authenticated_noop")
	expect.call(before_entries == var_to_bytes(fast.current_environment.get("runtime_object_manifest_entries", [])) and var_to_bytes(fast.to_dict()) == var_to_bytes(slow.to_dict()), "producer_outputs_and_complete_state_exact")
	fast = _clone(restored, false)
	slow = _clone(restored, true)
	var turn := fast.advance_environment_turns_with_external_rollback(1)
	var reference_turn := slow.advance_environment_turns_with_external_rollback(1)
	expect.call(turn == reference_turn and bool(turn.get("ok", false)) and var_to_bytes(fast.to_dict()) == var_to_bytes(slow.to_dict()), "complete_turn_state_clock_rng_exact")
	expect.call(fast.room_presentation_snapshot() == slow.room_presentation_snapshot() and fast.validate_room_action_authority() == slow.validate_room_action_authority(), "strong_publication_and_snapshot_equal_full_rebuild")
	for mutation in ["home_exit_removed", "metadata_changed", "unknown_owner", "authority_changed", "unowned_room"]:
		fast = _clone(restored, false)
		if mutation == "home_exit_removed": fast.home_state["active"] = false
		elif mutation == "metadata_changed": fast.current_environment["runtime_object_manifest_entries"][0]["label"] = "stale label"
		elif mutation == "unknown_owner": fast.current_environment["runtime_object_manifest_entries"].append({"object_id":"unknown","runtime_owner":"future_owner","physical":true})
		elif mutation == "authority_changed": fast.current_environment["layout"]["slot_map_digest"] = "unowned mutation"
		var environment := fast.current_environment.duplicate(true) if mutation == "unowned_room" else fast.current_environment
		expect.call(fast._sync_all_runtime_object_manifest_entries(environment), "real_or_unowned_change_retains_rebuild_" + mutation)
	# Real membership removal still executes the same complete repair and binding.
	fast = _clone(restored, false)
	slow = _clone(restored, true)
	fast.home_state["active"] = false
	slow.home_state["active"] = false
	turn = fast.advance_environment_turns_with_external_rollback(1)
	reference_turn = slow.advance_environment_turns_with_external_rollback(1)
	expect.call(turn == reference_turn and var_to_bytes(fast.to_dict()) == var_to_bytes(slow.to_dict()) and fast.room_presentation_snapshot() == slow.room_presentation_snapshot(), "actual_exit_removal_full_rebuild_exact")
	fast = _clone(restored, false)
	slow = _clone(restored, true)
	var event := EventModule.new()
	event.setup(library.event("parking_lot_tip"), library)
	var result := event.resolve(fast, fast.current_environment, "follow_tip", true)
	var reference := event.resolve(slow, slow.current_environment, "follow_tip", true)
	expect.call(result == reference and var_to_bytes(fast.to_dict()) == var_to_bytes(slow.to_dict()) and fast.room_presentation_snapshot() == slow.room_presentation_snapshot(), "actual_note_complete_result_state_rng_and_proof_exact")
	expect.call(original == var_to_bytes(restored.to_dict()), "genuine_fixture_unchanged")
	return {"passed":failures.is_empty(), "checks":checks, "failures":failures}


static func _clone(source: RunState, original: bool) -> RunState:
	var run: RunState = OriginalProjectionRun.new() if original else RunState.new()
	run._apply_environment_turn_snapshot(source._environment_turn_snapshot(), false)
	run.current_environment = source.current_environment.duplicate(true)
	run.publish_room_presentation()
	return run
