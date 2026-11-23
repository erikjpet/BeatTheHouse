extends RefCounted

const ProjectionScript := preload("res://scripts/core/persistent_environment_projection.gd")
const CodecScript := preload("res://scripts/core/run_save_codec.gd")


# Observe the real budget/admission path without replacing the projector.
class DeclinedProjectionRun extends RunState:
	var observed_decline: Dictionary = {}

	func _inactive_storage_projection(key: String, environment: Dictionary, declined_projection: Dictionary = {}) -> RefCounted:
		var compiled: RefCounted = super._inactive_storage_projection(key, environment, declined_projection)
		observed_decline = declined_projection.duplicate(false)
		return compiled


static func check(run: RunState) -> Dictionary:
	var failures: Array = []
	var checks: Array = []
	var expect := func(ok: bool, label: String) -> void:
		checks.append(label)
		if not ok: failures.append(label)
	_check_match_receipts(expect)
	_check_declined_projection_fallback(expect)
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
	var world_entries := 0
	var remaining_bytes := 0
	for cache_key in run._inactive_storage_projections:
		if not str(cache_key).begins_with(RunState.INACTIVE_CASINO_STORAGE_PREFIX): world_entries += 1
		remaining_bytes += run._inactive_storage_projections[cache_key].retained_bytes
	expect.call(world_entries == 0 and run._inactive_storage_projection_bytes == remaining_bytes, "removed_world_rooms_release_retained_projection_without_evicting_casino")
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
	expect.call(cached.retained_bytes == var_to_bytes(cached._source).size() + var_to_bytes(cached._projection).size() + var_to_bytes(cached._encoded_projection).size() + cached._source_receipt.size(), "encoded_graph_counts_toward_same_byte_budget")
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
	var original_rooms: Dictionary = run.grand_casino_room_states
	var casino_capture := run._grand_casino_room_states_for_save(false, true)
	var casino_legacy := run._grand_casino_room_states_for_save(false)
	var casino_encoded := CodecScript.encode({"rooms":casino_capture})
	expect.call(not casino_capture.is_empty() and casino_encoded == CodecScript.encode({"rooms":casino_legacy}), "stored_casino_room_compilation_matches_original_codec")
	var room_id: String = casino_capture.keys()[0]
	var casino_key := RunState.INACTIVE_CASINO_STORAGE_PREFIX + room_id
	expect.call(run._inactive_storage_projections.has(casino_key), "inactive_casino_room_admitted_to_same_bounded_cache")
	var changed_rooms: Dictionary = ProjectionScript.owned(original_rooms)
	changed_rooms[room_id]["description"] = "mutated stored casino room"
	run.grand_casino_room_states = changed_rooms
	var next_casino := run._grand_casino_room_states_for_save(false, true)
	expect.call(CodecScript.encode({"rooms":next_casino}) == CodecScript.encode({"rooms":run._grand_casino_room_states_for_save(false)}), "stored_casino_alias_mutation_invalidates_compilation")
	expect.call(CodecScript.encode({"rooms":casino_capture}) == casino_encoded, "prior_casino_generation_remains_owned_after_invalidation")
	var prior_environment: Dictionary = run.current_environment
	run.current_environment = changed_rooms[room_id]
	var active_casino := run._grand_casino_room_states_for_save(false, true)
	expect.call(not active_casino.has(room_id) and not run._inactive_storage_projections.has(casino_key), "room_activation_releases_inactive_compilation_and_uses_current_environment")
	expect.call(CodecScript.encode({"rooms":active_casino}) == CodecScript.encode({"rooms":run._grand_casino_room_states_for_save(false)}), "active_room_exclusion_retains_legacy_codec_parity")
	run.current_environment = prior_environment
	run.grand_casino_room_states = {}
	run._grand_casino_room_states_for_save(false, true)
	expect.call(not run._inactive_storage_projections.has(casino_key), "removed_casino_room_releases_compilation")
	run.grand_casino_room_states = original_rooms
	run._prime_inactive_storage_projections()
	expect.call(var_to_bytes(run.to_dict()) == before and [run.rng_seed,run.rng_state] == rng, "casino_cache_checks_restore_full_live_state_and_rng")
	var started := Time.get_ticks_usec()
	RunState._world_map_for_save_snapshot(run.world_map)
	var original_usec := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	run._owned_world_map_for_save_snapshot(run.world_map, true)
	var compiled_usec := Time.get_ticks_usec() - started
	return {"passed":failures.is_empty(), "checks":checks, "failures":failures,
		"same_input_native_world_projection_usec":{"original":original_usec,"compiled":compiled_usec},
		"cache_serialized_bytes":run._inactive_storage_projection_bytes}


static func _check_match_receipts(expect: Callable) -> void:
	var identity := func(body: Dictionary) -> Dictionary: return body
	var negative: float = PackedByteArray([0,0,0,0,0,0,0,128]).decode_double(0)
	var negative32: float = PackedByteArray([0,0,0,128]).decode_float(0)
	var numeric: Script = load("res://scripts/core/storage_numeric_json.gd")
	expect.call(numeric._bits(negative) != numeric._bits(0.0) and numeric._bits(negative32) != numeric._bits(0.0), "runtime_negative_zero_fixture_bits")
	var typed: Array[int] = [1,2]
	var typed_dict: Dictionary[String,int] = {"a":1}
	var cases := [{"n":1}, {"n":negative}, {"n":PackedFloat32Array([negative32])}, {"n":PackedFloat64Array([negative])}, {"typed":typed,"dict":typed_dict}]
	for source in cases:
		var entry := ProjectionScript.compile(source, identity, 65536)
		expect.call(not entry._source_receipt.is_empty() and entry.matches(source), "exact_receipt_accepts_original")
		var changed: Dictionary = ProjectionScript.owned(source)
		if source.has("n"):
			if typeof(source.n) == TYPE_INT: changed.n = 1.0
			elif typeof(source.n) == TYPE_FLOAT: changed.n = 0.0
			elif typeof(source.n) == TYPE_PACKED_FLOAT32_ARRAY: changed.n = PackedFloat32Array([0.0])
			else: changed.n = PackedFloat64Array([0.0])
			var original_match: bool = changed == entry._source and CodecScript._storage_numeric_refinement(changed, entry._source)
			expect.call(not original_match and not entry.matches(changed), "receipt_preserves_original_numeric_rejection")
		var snapshot := var_to_bytes(entry.snapshot())
		var encoded := var_to_bytes(entry._encoded_projection)
		var old_bytes: int = entry.retained_bytes
		var receipt_bytes: int = entry._source_receipt.size()
		expect.call(entry.release_source_receipt() == receipt_bytes and entry.retained_bytes == old_bytes - receipt_bytes, "receipt_release_exact_accounting")
		expect.call(entry.release_source_receipt() == 0, "receipt_release_idempotent")
		expect.call(entry.matches(source) and var_to_bytes(entry.snapshot()) == snapshot and var_to_bytes(entry._encoded_projection) == encoded, "release_preserves_core_and_matching")
		if source.has("n"): expect.call(not entry.matches(changed), "released_receipt_preserves_numeric_rejection")
	var ordered := {"a":1,"b":2}
	var entry := ProjectionScript.compile(ordered, identity, 8192)
	expect.call(entry.matches({"b":2,"a":1}), "reordered_dictionary_keeps_legacy_fallback")
	var run := RunState.new()
	var baseline_bytes := 0
	var source := {"id":"receipt_pressure", "archetype_id":"back_alley", "game_states":{}, "description":"x".repeat(180000)}
	var projector := func(body: Dictionary) -> Dictionary: return run._environment_for_persistent_storage(body, false)
	for index in range(8):
		var expected := ProjectionScript.compile(source, projector, RunState.INACTIVE_STORAGE_PROJECTION_BUDGET - baseline_bytes)
		if expected != null:
			expected.release_source_receipt()
			baseline_bytes += expected.retained_bytes
		var actual := run._inactive_storage_projection("pressure_%d" % index, source)
		expect.call((expected == null) == (actual == null), "receipt_pressure_preserves_core_admission")
		if actual != null:
			expect.call(var_to_bytes(actual.snapshot()) == var_to_bytes(expected.snapshot()) and var_to_bytes(actual._encoded_projection) == var_to_bytes(expected._encoded_projection), "receipt_pressure_preserves_encoded_core")
		expect.call(run._inactive_storage_projection_bytes <= RunState.INACTIVE_STORAGE_PROJECTION_BUDGET, "receipt_pressure_aggregate_bounded")
	var sum := 0
	var receipts := 0
	for cached in run._inactive_storage_projections.values():
		sum += cached.retained_bytes
		receipts += cached._source_receipt.size()
	expect.call(sum == run._inactive_storage_projection_bytes, "receipt_pressure_exact_aggregate")
	var before := run._inactive_storage_projection_bytes
	expect.call(run._inactive_storage_projection("opaque_decline", {"opaque":RefCounted.new()}) == null, "failed_compile_declines")
	var after_receipts := 0
	for cached in run._inactive_storage_projections.values(): after_receipts += cached._source_receipt.size()
	expect.call(run._inactive_storage_projection_bytes == before and after_receipts == receipts, "failed_compile_keeps_existing_receipts")


static func _check_declined_projection_fallback(expect: Callable) -> void:
	var typed: Array[int] = [1, 2]
	var typed_dict: Dictionary[String, int] = {"n": 3}
	var negative: float = PackedByteArray([0,0,0,0,0,0,0,128]).decode_double(0)
	var source := {"nested": [{"packed": PackedByteArray([11,22])}], "typed": typed, "typed_dict": typed_dict, "n": negative, "large_int": 9007199254740993}
	var calls := [0]
	var identity := func(body: Dictionary) -> Dictionary:
		calls[0] += 1
		return body
	var declined := {"stale": true}
	var source_before := var_to_bytes(source)
	var expected_bytes := var_to_bytes(CodecScript.encode({"room": source}))
	var rejected := ProjectionScript.compile(source, identity, source_before.size(), declined)
	expect.call(rejected == null and calls[0] == 1 and declined.has("projection"), "late_decline_exposes_one_projector_result")
	if not declined.has("projection"): return
	var captured: Dictionary = declined["projection"]
	expect.call(var_to_bytes(CodecScript.encode({"room": captured})) == expected_bytes, "declined_typed_packed_numeric_exact_encoded_bytes")
	captured["nested"][0]["packed"][0] = 99
	expect.call(var_to_bytes(source) == source_before, "declined_output_owns_mutable_leaves")
	source["typed"][0] = 7
	expect.call(captured["typed"][0] == 1, "declined_source_mutation_cannot_change_output")
	ProjectionScript.compile(source, identity, 1, declined)
	expect.call(declined.is_empty() and calls[0] == 1, "source_budget_decline_clears_carrier_without_projecting")
	declined["projection"] = {"stale": true}
	ProjectionScript.compile({"opaque": RefCounted.new()}, identity, 65536, declined)
	expect.call(declined.is_empty() and calls[0] == 1, "opaque_decline_clears_carrier_without_projecting")
	var empty_calls := [0]
	var empty_projector := func(_body: Dictionary) -> Dictionary:
		empty_calls[0] += 1
		return {}
	var plain := {"id": "declined_empty", "kind": "test", "game_states": {}}
	var empty_entry := ProjectionScript.compile(plain, empty_projector, var_to_bytes(plain).size(), declined)
	expect.call(empty_entry == null and empty_calls[0] == 1 and declined.has("projection") and (declined["projection"] as Dictionary).is_empty(), "empty_projection_is_present_not_a_missing_fallback")
	expect.call(var_to_bytes(CodecScript.encode({"room": declined.get("projection")})) == var_to_bytes(CodecScript.encode({"room": {}})), "empty_projection_keeps_existing_encoding")
	var plain_identity := func(body: Dictionary) -> Dictionary: return body
	var admitted := ProjectionScript.compile(plain, plain_identity, var_to_bytes(plain).size() * 2, declined)
	expect.call(admitted != null and admitted._encoded_projection.is_empty() and declined.is_empty(), "optional_encode_cache_decline_keeps_existing_compilation")
	var cache_probe := RunState.new()
	var cached := cache_probe._inactive_storage_projection("hit", plain, declined)
	declined["projection"] = {"stale": true}
	var hit := cache_probe._inactive_storage_projection("hit", plain, declined)
	expect.call(cached != null and is_same(cached, hit) and declined.is_empty(), "cache_hit_clears_stale_declined_projection")
	expect.call(cache_probe._inactive_storage_projection_bytes == cached.retained_bytes and cache_probe._inactive_storage_projection_bytes <= RunState.INACTIVE_STORAGE_PROJECTION_BUDGET, "admitted_cache_accounting_unchanged")
	# Exercise both real callers at the real cap. No fabricated cache accounting.
	var room := {"id": "declined_room", "archetype_id": "back_alley", "kind": "test", "game_states": {}, "description": "x".repeat(RunState.INACTIVE_STORAGE_PROJECTION_BUDGET / 2 + 4096), "nested": [{"packed": PackedByteArray([11,22])}], "typed": typed, "typed_dict": typed_dict, "n": negative}
	var projected := RunState._environment_for_persistent_storage(room, false)
	var source_size := var_to_bytes(room).size()
	var rejected_size := source_size + var_to_bytes(projected).size()
	var valid_budget_case := source_size <= RunState.INACTIVE_STORAGE_PROJECTION_BUDGET and rejected_size > RunState.INACTIVE_STORAGE_PROJECTION_BUDGET
	expect.call(valid_budget_case, "real_caller_fixture_measures_post_projection_budget_rejection")
	if not valid_budget_case: return
	var probe := DeclinedProjectionRun.new()
	var rng_before := [probe.rng_seed, probe.rng_state]
	var map := {"nodes": [{"id": "declined_room", "environment": room}]}
	var room_before := var_to_bytes(room)
	var expected_world := RunState._world_map_for_save_snapshot(map)
	var world := probe._owned_world_map_for_save_snapshot(map, true)
	expect.call(probe.observed_decline.has("projection") and is_same(world["nodes"][0]["environment"], probe.observed_decline.get("projection")), "world_encoding_consumes_exact_declined_value_without_reprojection")
	expect.call(var_to_bytes(CodecScript.encode(world)) == var_to_bytes(CodecScript.encode(expected_world)), "declined_world_exact_encoded_bytes")
	expect.call(var_to_bytes(probe._owned_world_map_for_save_snapshot(map, false)) == var_to_bytes(expected_world), "declined_nonencoding_world_keeps_raw_snapshot_types")
	world["nodes"][0]["environment"]["nested"][0]["packed"][0] = 33
	expect.call(var_to_bytes(room) == room_before, "world_declined_projection_has_no_live_mutable_alias")
	var room_id: String = probe.GRAND_CASINO_ARCHETYPE_IDS[0]
	probe.grand_casino_room_states[room_id] = room
	var expected_rooms := probe._grand_casino_room_states_for_save(false)
	var rooms := probe._grand_casino_room_states_for_save(false, true)
	expect.call(probe.observed_decline.has("projection") and is_same(rooms[room_id], probe.observed_decline.get("projection")), "grand_encoding_consumes_exact_declined_value_without_reprojection")
	expect.call(var_to_bytes(CodecScript.encode({"rooms": rooms})) == var_to_bytes(CodecScript.encode({"rooms": expected_rooms})), "declined_grand_exact_encoded_bytes")
	var deep_rooms := probe._grand_casino_room_states_for_save(true, true)
	expect.call(not is_same(deep_rooms[room_id], probe.observed_decline.get("projection")) and var_to_bytes(deep_rooms[room_id]) == var_to_bytes(RunState._environment_for_persistent_storage(room, true)), "grand_deep_copy_fallback_unchanged")
	rooms[room_id]["nested"][0]["packed"][0] = 44
	expect.call(var_to_bytes(room) == room_before and [probe.rng_seed, probe.rng_state] == rng_before, "grand_declined_projection_preserves_live_state_and_rng")
	expect.call(probe._inactive_storage_projections.is_empty() and probe._inactive_storage_projection_bytes == 0, "late_declines_retain_zero_cache_entries_and_bytes")
