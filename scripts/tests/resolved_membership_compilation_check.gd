extends RefCounted

const Publication := preload("res://scripts/core/room_presentation_publication.gd")
const Placement := preload("res://scripts/core/environment_placement.gd")
const Manifest := preload("res://scripts/core/environment_object_manifest.gd")

class OriginalMembershipRun extends RunState:
	func prepare_resolved_event_membership_for_publication(event_id: String, profile_stages: bool = false, next_archetype_additions: Array = []) -> Dictionary:
		# Select the unchanged implementation retained immediately below the owned
		# compiler. The old implementation never consumed this runtime publication.
		_room_presentation_publication = null
		return super.prepare_resolved_event_membership_for_publication(event_id, profile_stages, next_archetype_additions)


static func check(restored: RunState, library: ContentLibrary) -> Dictionary:
	var checks: Array = []
	var failures: Array = []
	var expect := func(ok: bool, label: String) -> void:
		checks.append(label)
		if not ok: failures.append(label)
	var original_bytes := var_to_bytes(restored.to_dict())
	var fast := _clone(restored, false)
	var slow := _clone(restored, true)
	var prior: RefCounted = fast._room_presentation_publication
	var prior_bytes := var_to_bytes(prior.snapshot())
	var prior_environment: Dictionary = prior.snapshot()["environment"]
	var before := Time.get_ticks_usec()
	var slow_result := slow.resolve_event("back_alley_offer")
	var original_usec := Time.get_ticks_usec() - before
	before = Time.get_ticks_usec()
	var fast_result := fast.resolve_event("back_alley_offer", true)
	var compiled_usec := Time.get_ticks_usec() - before
	expect.call(str(fast._room_presentation_publication._compilation_kind) == "authenticated_event_removal", "genuine_resolution_uses_authenticated_removal_law")
	fast_result.erase("debug_membership_usec")
	expect.call(fast_result == slow_result and var_to_bytes(fast.to_dict()) == var_to_bytes(slow.to_dict()), "genuine_resolution_complete_state_and_result_exact")
	expect.call(fast._room_presentation_publication != null and fast._room_presentation_publication != prior, "genuine_resolution_committed_owned_generation")
	expect.call(fast._room_presentation_publication.snapshot() == slow._room_presentation_publication.snapshot() and fast.validate_room_action_authority() == Publication.validate(fast.current_environment), "compiled_proof_and_snapshot_equal_full_validation")
	expect.call(var_to_bytes(prior.snapshot()) == prior_bytes, "prior_generation_unchanged")
	var changed_keys: Array = []
	for key in fast.current_environment:
		if key != "game_states" and var_to_bytes(fast.current_environment[key]) != var_to_bytes(prior_environment.get(key)): changed_keys.append(key)
	var exposed := fast.room_presentation_snapshot()
	exposed["environment"]["layout"].clear()
	exposed["proof"].clear()
	expect.call(not fast.room_presentation_snapshot()["environment"]["layout"].is_empty() and var_to_bytes(prior.snapshot()) == prior_bytes, "compiled_output_aliases_detached")
	for field in ["description", "layout", "object_manifest", "scenario_layout_audit", "unknown_future_field"]:
		fast = _clone(restored, false)
		fast.current_environment["resolved_event_ids"].append("back_alley_offer")
		var compiled: RefCounted = fast._room_presentation_publication.compile_resolved_event_membership(fast.current_environment, "back_alley_offer")
		expect.call(compiled != null, "prepare_for_commit_mutation_" + field)
		if compiled == null: continue
		if typeof(fast.current_environment.get(field)) == TYPE_DICTIONARY: fast.current_environment[field]["unexpected_mutation"] = true
		else: fast.current_environment[field] = "changed after compilation"
		var mutated := var_to_bytes(fast.current_environment)
		expect.call(not compiled.commit_compiled_event_membership(fast.current_environment) and mutated == var_to_bytes(fast.current_environment), "commit_rejects_and_preserves_" + field)
	fast = _clone(restored, false)
	fast.current_environment["typed_future_input"] = {"value":1}
	fast.publish_room_presentation()
	fast.current_environment["resolved_event_ids"].append("back_alley_offer")
	var typed: RefCounted = fast._room_presentation_publication.compile_resolved_event_membership(fast.current_environment, "back_alley_offer")
	fast.current_environment["typed_future_input"]["value"] = 1.0
	expect.call(typed != null and not typed.commit_compiled_event_membership(fast.current_environment), "commit_rejects_equal_valued_different_nested_numeric_type")
	fast = _clone(restored, false)
	fast.current_environment["unknown_opaque_input"] = RefCounted.new()
	expect.call(fast._room_presentation_publication.compile_resolved_event_membership(fast.current_environment, "back_alley_offer") == null, "opaque_input_uses_original_path")
	fast = _clone(restored, false)
	fast.current_environment["resolved_event_ids"].append("back_alley_offer")
	var surface_compiled: RefCounted = fast._room_presentation_publication.compile_resolved_event_membership(fast.current_environment, "back_alley_offer")
	var surface := Placement.surface_map(fast.current_environment)
	var old_surface_version: Variant = surface.get("slot_schema_version")
	surface["slot_schema_version"] = -1
	expect.call(surface_compiled != null and not surface_compiled.commit_compiled_event_membership(fast.current_environment), "external_surface_alias_cannot_commit_old_compilation")
	surface["slot_schema_version"] = old_surface_version
	fast = _clone(restored, false)
	fast.current_environment["resolved_event_ids"].append("back_alley_offer")
	var game_compiled: RefCounted = fast._room_presentation_publication.compile_resolved_event_membership(fast.current_environment, "back_alley_offer")
	fast.current_environment["game_ids"].append("pull_tabs")
	fast.current_environment["game_states"]["pull_tabs"] = {"environment_hooks":[{"id":"changed_hook"}]}
	expect.call(game_compiled != null and not game_compiled.commit_compiled_event_membership(fast.current_environment), "new_game_hook_between_compile_and_commit_rejected")
	fast = _clone(restored, false)
	fast.current_environment["future_nested_input"] = {"value":null}
	fast.publish_room_presentation()
	fast.current_environment["resolved_event_ids"].append("back_alley_offer")
	fast.current_environment["future_nested_input"]["value"] = RefCounted.new()
	expect.call(fast._room_presentation_publication.compile_resolved_event_membership(fast.current_environment, "back_alley_offer") == null, "nested_null_to_opaque_cannot_match_owned_transition")
	# Adding physical membership must retain the complete slot-allocation path.
	fast = _clone(restored, false)
	fast.current_environment["resolved_event_ids"].append("back_alley_offer")
	fast.current_environment["game_ids"].append("pull_tabs")
	expect.call(fast._room_presentation_publication.compile_resolved_event_membership(fast.current_environment, "back_alley_offer") == null, "new_physical_membership_uses_original_slot_allocation")
	# Reordered cheap rejection must never turn a malformed/stale retained
	# manifest into authority. The previous predicates are the exact reference.
	var valid_manifest: Dictionary = restored.current_environment["object_manifest"]
	for kind in ["valid", "wrong_source", "wrong_room", "bad_digest", "bad_rows", "typed_identity"]:
		var value := valid_manifest.duplicate(true)
		if kind == "wrong_source": value["source_digest"] = "different"
		elif kind == "wrong_room": value["environment_id"] = "different"
		elif kind == "bad_digest": value["digest"] = "different"
		elif kind == "bad_rows": value["rows"].append({"invalid":true})
		elif kind == "typed_identity": value["environment_id"] = StringName(value["environment_id"])
		var env := restored.current_environment
		var digest := str(valid_manifest["source_digest"])
		var old_seed := Manifest.validate(value).is_empty() and str(value.get("source_digest", "")) == digest \
				and str(value.get("environment_id", "")) == str(env.get("id", env.get("world_node_id", env.get("archetype_id", "")))).strip_edges() \
				and str(value.get("archetype_id", "")) == str(env.get("archetype_id", "")).strip_edges() \
				and str(value.get("layer_id", "")) == str(env.get("current_layer_id", env.get("layer_id", ""))).strip_edges()
		var old_match := Manifest.validate(value).is_empty() and str(value.get("source_digest", "")) == digest \
				and str(value.get("environment_id", "")) == str(env.get("id", env.get("world_node_id", env.get("archetype_id", "")))) \
				and str(value.get("archetype_id", "")) == str(env.get("archetype_id", "")) \
				and str(value.get("layer_id", "")) == str(env.get("current_layer_id", env.get("layer_id", "")))
		expect.call(Manifest._manifest_can_seed_scenario_retention(value, env, digest) == old_seed and Manifest._manifest_matches(value, env, valid_manifest["rows"], digest) == old_match, "manifest_early_rejection_parity_" + kind)
	# Mutations rejected by the original publication still take that exact path;
	# the compiler cannot authenticate a changed renderer seal or slot envelope.
	for field in ["scenario_layout_audit", "layout"]:
		fast = _clone(restored, false)
		slow = _clone(restored, true)
		if field == "scenario_layout_audit":
			fast.current_environment[field]["valid"] = false
			slow.current_environment[field]["valid"] = false
		else:
			fast.current_environment[field]["slot_map_digest"] = "invalid"
			slow.current_environment[field]["slot_map_digest"] = "invalid"
		var fr := fast.resolve_event("back_alley_offer")
		var sr := slow.resolve_event("back_alley_offer")
		expect.call(fr == sr and var_to_bytes(fast.to_dict()) == var_to_bytes(slow.to_dict()) and fast.room_presentation_snapshot() == slow.room_presentation_snapshot(), "invalid_" + field + "_fallback_exact")
	# One complete actual EventModule result, including clock, RNG and rollback.
	fast = _clone(restored, false)
	slow = _clone(restored, true)
	var event := EventModule.new()
	event.setup(library.event("back_alley_offer"), library)
	var result := event.resolve(fast, fast.current_environment, "take_cash", true, false)
	var reference := event.resolve(slow, slow.current_environment, "take_cash", true, false)
	expect.call(result == reference and var_to_bytes(fast.to_dict()) == var_to_bytes(slow.to_dict()) and [fast.rng_seed,fast.rng_state] == [slow.rng_seed,slow.rng_state], "complete_offer_ordering_clock_rng_exact")
	var rollback := fast._environment_turn_snapshot()
	var accepted_bytes := var_to_bytes(fast.to_dict())
	fast.current_environment["description"] = "later rejected mutation"
	fast._apply_environment_turn_snapshot(rollback, false)
	expect.call(accepted_bytes == var_to_bytes(fast.to_dict()) and fast.validate_room_action_authority() == Publication.validate(fast.current_environment), "rollback_restores_compiled_publication")
	expect.call(original_bytes == var_to_bytes(restored.to_dict()), "genuine_fixture_unchanged")
	return {"passed":failures.is_empty(), "checks":checks, "failures":failures, "changed_environment_keys":changed_keys, "same_input_native_membership_usec":{"original":original_usec,"compiled":compiled_usec}, "scope":"Changed event-membership compiler only; no broad suite or Web latency claim."}


static func _clone(source: RunState, original: bool) -> RunState:
	var run: RunState = OriginalMembershipRun.new() if original else RunState.new()
	run._apply_environment_turn_snapshot(source._environment_turn_snapshot(), false)
	run.current_environment = source.current_environment.duplicate(true)
	run.publish_room_presentation()
	return run
