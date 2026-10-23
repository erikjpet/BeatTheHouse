extends RefCounted

const ProjectionScript := preload("res://scripts/core/persistent_environment_projection.gd")
const CodecScript := preload("res://scripts/core/run_save_codec.gd")


static func check(run: RunState) -> Dictionary:
	var failures: Array = []
	var checks: Array = []
	var expect := func(ok: bool, label: String) -> void:
		checks.append(label)
		if not ok: failures.append(label)
	var input := ProjectionScript.owned(run.world_map) as Dictionary
	var before := var_to_bytes(run.to_dict())
	var rng := [run.rng_seed, run.rng_state]
	var original := RunState._world_map_for_save_snapshot(input)
	var projected := run._owned_world_map_for_save_snapshot(input)
	expect.call(projected == original, "complete_world_projection_matches_original")
	expect.call(run._inactive_storage_projection_bytes <= RunState.INACTIVE_STORAGE_PROJECTION_BUDGET, "retained_serialized_payload_budget_bounded")
	var selected_index := -1
	for index in range(input.get("nodes", []).size()):
		var node: Variant = input["nodes"][index]
		if typeof(node) == TYPE_DICTIONARY and typeof(node.get("environment")) == TYPE_DICTIONARY and not node["environment"].is_empty():
			selected_index = index
			break
	expect.call(selected_index >= 0, "genuine_fixture_has_stored_room")
	if selected_index < 0: return {"passed":false, "checks":checks, "failures":failures}
	var node: Dictionary = input["nodes"][selected_index]
	var key := str(node.get("id", ""))
	var first := run._inactive_storage_projection(key, node["environment"])
	expect.call(first != null and is_same(first, run._inactive_storage_projection(key, node["environment"])), "unchanged_owned_compilation_reused")
	projected["nodes"][selected_index]["environment"]["description"] = "mutated returned snapshot"
	expect.call(run._owned_world_map_for_save_snapshot(input) == original, "returned_snapshot_cannot_mutate_compilation")
	for field in ["description", "layout", "scenario_sequence_state", "layer_states", "game_states", "runtime_object_manifest_entries"]:
		var changed: Dictionary = ProjectionScript.owned(input)
		var body: Dictionary = changed["nodes"][selected_index]["environment"]
		if field == "description": body[field] = "new room copy"
		elif field == "runtime_object_manifest_entries": body[field] = []
		elif field == "game_states": body[field] = {"private_marker":{"packed":PackedByteArray([1,2,3]),"nested":[{"n":2}]}}
		elif field == "layer_states": body[field] = {"private_layer":{"id":"private_layer", "archetype_id":"back_alley", "game_states":{}, "active_game_id":"must_strip"}}
		elif field == "layout": body[field] = (body.get(field,{}) as Dictionary).duplicate(true); body[field]["private_mutation"] = true
		else: body.erase(field)
		var expected := RunState._world_map_for_save_snapshot(changed)
		var next := run._owned_world_map_for_save_snapshot(changed)
		expect.call(next == expected, "aliased_%s_mutation_uses_original_projection" % field)
	# Restore the genuine fixture's original receipt and verify no mutation/RNG
	# escaped into the live graph during either compilation or output capture.
	run._owned_world_map_for_save_snapshot(run.world_map)
	expect.call(var_to_bytes(run.to_dict()) == before and [run.rng_seed,run.rng_state] == rng, "live_full_state_and_rng_unchanged")
	var restored := RunState.new()
	restored.from_dict(run.to_dict())
	expect.call(restored._owned_world_map_for_save_snapshot(restored.world_map) == RunState._world_map_for_save_snapshot(restored.world_map), "cold_restore_compilation_matches_original")
	var token := run._environment_turn_snapshot()
	run._apply_environment_turn_snapshot(token, false)
	expect.call(run._owned_world_map_for_save_snapshot(run.world_map) == RunState._world_map_for_save_snapshot(run.world_map), "rollback_graph_uses_exact_projection")
	var leaf := {"packed":PackedByteArray([11,22]), "nested":[{"packed":PackedInt64Array([9007199254740993])}]}
	var identity := func(body: Dictionary) -> Dictionary: return body
	var entry := ProjectionScript.compile(leaf, identity, 4096)
	expect.call(entry != null, "packed_fixture_compiles")
	var captured: Dictionary = entry.snapshot()
	leaf["packed"][0] = 99
	leaf["nested"][0]["packed"][0] = 8
	expect.call(not entry.matches(leaf) and captured["packed"][0] == 11 and captured["nested"][0]["packed"][0] == 9007199254740993, "packed_source_mutation_detected_and_generation_owned")
	captured["packed"][0] = 55
	captured["nested"][0]["packed"][0] = 4
	expect.call(entry.snapshot()["packed"][0] == 11 and entry.snapshot()["nested"][0]["packed"][0] == 9007199254740993, "nested_packed_output_aliases_detached")
	expect.call(ProjectionScript.compile({"large":PackedByteArray([1,2,3])}, identity, 1) == null, "over_budget_declines_compilation")
	expect.call(ProjectionScript.compile({"opaque":RefCounted.new()}, identity, 4096) == null, "opaque_mutable_reference_declines_compilation")
	var removed := input.duplicate(true)
	removed["nodes"] = []
	run._owned_world_map_for_save_snapshot(removed)
	expect.call(run._inactive_storage_projections.is_empty() and run._inactive_storage_projection_bytes == 0, "removed_rooms_release_retained_projection")
	run._prime_inactive_storage_projections()
	var expected_encoded := CodecScript.encode(run.to_save_snapshot(false))
	var captured_generation := run.to_save_snapshot_for_encoding()
	expect.call(CodecScript.encode(captured_generation) == expected_encoded, "compiled_generation_exact_encoded_format_parity")
	var retained_map := run.world_map
	var mutated_map: Dictionary = ProjectionScript.owned(run.world_map)
	mutated_map["nodes"][selected_index]["environment"]["description"] = "later generation"
	run.world_map = mutated_map
	var later_generation := run.to_save_snapshot_for_encoding()
	expect.call(CodecScript.encode(captured_generation) == expected_encoded, "earlier_generation_survives_live_mutation_and_cache_replacement")
	expect.call(CodecScript.encode(later_generation) == CodecScript.encode(run.to_save_snapshot(false)), "later_generation_rebuilds_exact_encoded_output")
	run.world_map = retained_map
	var actual_encoded := CodecScript.encode(captured_generation)
	for ref in actual_encoded["environment_registry"]:
		var body: Dictionary = actual_encoded["environment_registry"][ref]
		body["description"] = "mutated encoded output"
		if typeof(body.get("layout")) == TYPE_DICTIONARY:
			body["layout"]["cache_alias_probe"] = true
	expect.call(CodecScript.encode(captured_generation) == expected_encoded, "nested_encoded_output_cannot_mutate_compiled_generation")
	actual_encoded["environment_registry"].clear()
	expect.call(CodecScript.encode(captured_generation) == expected_encoded, "encoded_output_cannot_mutate_compiled_generation")
	var plain := {"id":"encoded_cache_probe", "kind":"test", "game_states":{}, "nested":[{"n":7}]}
	var cached := ProjectionScript.compile(plain, identity, 8192)
	expect.call(not cached._encoded_projection.is_empty(), "plain_graph_uses_encoded_cache")
	expect.call(cached.retained_bytes == var_to_bytes(cached._source).size() + var_to_bytes(cached._projection).size() + var_to_bytes(cached._encoded_projection).size(), "encoded_graph_counts_toward_same_byte_budget")
	var shallow_budget := var_to_bytes(plain).size() * 2
	var uncached := ProjectionScript.compile(plain, identity, shallow_budget)
	expect.call(uncached != null and uncached._encoded_projection.is_empty() and uncached.retained_bytes <= shallow_budget, "encoded_cache_declines_without_growing_budget")
	var packed_room := plain.duplicate(true)
	packed_room["nested"][0]["bytes"] = PackedByteArray([1,2,3])
	var packed_entry := ProjectionScript.compile(packed_room, identity, 8192)
	expect.call(packed_entry._encoded_projection.is_empty(), "packed_mutable_leaf_retains_explicit_owned_codec_path")
	var expected_registry: Dictionary = {}
	var expected_fingerprints: Dictionary = {}
	var expected_ref := CodecScript._encode_environment_reference(packed_room, expected_registry, expected_fingerprints)
	var actual_registry: Dictionary = {}
	var actual_ref: Dictionary = packed_entry.encode_into(actual_registry, {})
	expect.call(actual_ref == expected_ref and actual_registry == expected_registry, "packed_fallback_preserves_full_reference_bytes")
	actual_registry[actual_ref[CodecScript.ENVIRONMENT_REF_KEY]]["nested"][0]["bytes"][0] = 99
	var fresh_registry: Dictionary = {}
	packed_entry.encode_into(fresh_registry, {})
	expect.call(fresh_registry == expected_registry, "packed_output_alias_cannot_mutate_compilation")
	run._prime_inactive_storage_projections()
	var started := Time.get_ticks_usec()
	RunState._world_map_for_save_snapshot(run.world_map)
	var original_usec := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	run._owned_world_map_for_save_snapshot(run.world_map, true)
	var compiled_usec := Time.get_ticks_usec() - started
	return {"passed":failures.is_empty(), "checks":checks, "failures":failures,
		"same_input_native_world_projection_usec":{"original":original_usec,"compiled":compiled_usec},
		"cache_serialized_bytes":run._inactive_storage_projection_bytes}
