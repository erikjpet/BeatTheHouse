extends RefCounted

class OriginalMembershipRun extends RunState:
	func prepare_resolved_event_membership_for_publication(event_id: String, profile_stages: bool = false, next_archetype_additions: Array = []) -> Dictionary:
		_room_presentation_publication = null
		return super.prepare_resolved_event_membership_for_publication(event_id, profile_stages, next_archetype_additions)


static func check(restored: RunState, library: ContentLibrary) -> Dictionary:
	var failures: Array = []
	var checks: Array = []
	var expect := func(ok: bool, label: String) -> void:
		checks.append(label)
		if not ok: failures.append(label)
	var original := var_to_bytes(restored.to_dict())
	var fast := _clone(restored, false)
	var slow := _clone(restored, true)
	var prior: RefCounted = fast._room_presentation_publication
	var prior_bytes := var_to_bytes(prior.snapshot())
	var event := EventModule.new()
	event.setup(library.event("parking_lot_tip"), library)
	var result := event.resolve(fast, fast.current_environment, "follow_tip", true)
	var reference := event.resolve(slow, slow.current_environment, "follow_tip", true)
	expect.call(bool(result.get("ok", false)) and fast._room_presentation_publication._compilation_kind == "authenticated_event_removal", "actual_note_uses_owned_compilation")
	expect.call(result == reference and var_to_bytes(fast.to_dict()) == var_to_bytes(slow.to_dict()), "complete_result_state_clock_rng_match_original")
	expect.call(fast.room_presentation_snapshot() == slow.room_presentation_snapshot(), "full_snapshot_and_strong_proof_match_original")
	expect.call(var_to_bytes(prior.snapshot()) == prior_bytes, "prior_generation_unchanged")
	for mutation in ["extra_route", "typed_route", "description", "game_hook"]:
		fast = _clone(restored, false)
		fast.add_next_archetypes(["small_underground_casino"])
		fast.current_environment["resolved_event_ids"].append("parking_lot_tip")
		if mutation == "extra_route": fast.current_environment["next_archetypes"].append("unexpected_route")
		elif mutation == "typed_route": fast.current_environment["next_archetypes"][-1] = StringName("small_underground_casino")
		elif mutation == "description": fast.current_environment["description"] = "unexpected"
		else:
			fast.current_environment["game_ids"].append("unexpected")
			fast.current_environment["game_states"]["unexpected"] = {"environment_hooks":[{"id":"unexpected"}]}
		expect.call(fast._room_presentation_publication.compile_resolved_event_membership(fast.current_environment, "parking_lot_tip", ["small_underground_casino"]) == null, "unexpected_input_rejected_" + mutation)
	fast = _clone(restored, false)
	fast.add_next_archetypes(["small_underground_casino"])
	fast.current_environment["resolved_event_ids"].append("parking_lot_tip")
	var additions := ["small_underground_casino"]
	var compiled: RefCounted = fast._room_presentation_publication.compile_resolved_event_membership(fast.current_environment, "parking_lot_tip", additions)
	expect.call(compiled != null, "owned_command_prepares")
	additions[0] = "later_command_alias"
	expect.call(compiled != null and compiled.commit_compiled_event_membership(fast.current_environment), "command_alias_cannot_rewrite_owned_compilation")
	if compiled != null: fast._room_presentation_publication = compiled
	var exposed := fast.room_presentation_snapshot()
	exposed["environment"]["next_archetypes"].clear()
	expect.call(not fast.room_presentation_snapshot()["environment"]["next_archetypes"].is_empty(), "returned_route_alias_detached")
	expect.call(original == var_to_bytes(restored.to_dict()), "original_fixture_unchanged")
	return {"passed":failures.is_empty(), "checks":checks, "failures":failures}


static func _clone(source: RunState, original: bool) -> RunState:
	var run: RunState = OriginalMembershipRun.new() if original else RunState.new()
	run._apply_environment_turn_snapshot(source._environment_turn_snapshot(), false)
	run.current_environment = source.current_environment.duplicate(true)
	run.publish_room_presentation()
	return run
