extends RefCounted

const PublicationScript := preload("res://scripts/core/room_presentation_publication.gd")

class ObservedRun extends RunState:
	var flushes: Array = []
	var clock_writes: Array = []
	func _advance_published_turn_counter(previous: int, next: int) -> void:
		var shell := current_environment.duplicate(false)
		shell["turns"] = previous
		var published: Dictionary = _room_presentation_publication.get("_environment") if _room_presentation_publication != null else {}
		var old_revision := room_presentation_revision()
		var observation := {"previous_type":typeof(previous), "published_type":typeof(published.get("turns")), "mismatches":differences(published, shell)}
		super._advance_published_turn_counter(previous, next)
		observation["advanced"] = old_revision != room_presentation_revision()
		clock_writes.append(observation)
	func _detached_environment_turn_candidate() -> RunState:
		var candidate := super._detached_environment_turn_candidate() as ObservedRun
		candidate.flushes = flushes
		return candidate
	func scenario_flush_facts(boundary_serial: int = -1) -> Dictionary:
		var published: Dictionary = _room_presentation_publication.get("_environment") if _room_presentation_publication != null else {}
		var mismatches := differences(published, current_environment)
		var engine := preload("res://scripts/core/scenario_engine.gd")
		var runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
		var definition := _scenario_sequence_definition_readonly()
		var diagnostic := current_environment.duplicate(true)
		var prior: Dictionary = diagnostic.get("scenario_sequence_state", {})
		var prepared := engine.prepare_sequence_fact_flush(diagnostic, definition, _crew_action_index() if boundary_serial < 0 else boundary_serial)
		var state: Dictionary = prepared["result"].get("state", {})
		var projection := runtime.public_projection(state, definition, true)
		var stored: Dictionary = diagnostic.get("scenario_sequence_projection", {})
		var materialized := diagnostic.duplicate(true)
		engine._materialize_sequence_services_games_routes(materialized, stored)
		var evidence := {"unchanged_state":prepared.get("unchanged_state"),
			"trusted_host_match":engine._trusted_host_semantics_match(diagnostic, prior.get("semantic_state", {})),
			"trusted_state_fingerprint_matches":str(diagnostic.get(engine.TRUSTED_STATE_REFERENCE_KEY, "")) == runtime.content_fingerprint(prior),
			"layout_input_matches":str(diagnostic.get(engine.TRUSTED_LAYOUT_INPUT_DIGEST_KEY, "")) == engine._sequence_layout_input_digest(diagnostic, projection),
			"projection_differences":differences(stored, projection), "materialization_differences":differences(diagnostic, materialized),
			"authenticated_result_available":not engine.unchanged_sequence_flush_result(diagnostic, prepared).is_empty()}
		var result := super.scenario_flush_facts(boundary_serial)
		flushes.append({"ok":result.get("ok", false), "unchanged":result.get("unchanged", false), "processed":result.get("processed", []), "mismatches":mismatches, "engine_boundary":evidence})
		return result
	static func differences(left: Dictionary, right: Dictionary, prefix: String = "") -> Array:
		var result: Array = []
		var keys := left.keys()
		for key in right.keys():
			if not keys.has(key): keys.append(key)
		for key in keys:
			if prefix.is_empty() and key == "game_states": continue
			var path := prefix + "." + str(key)
			if not left.has(key) or not right.has(key): result.append(path + ":presence")
			elif typeof(left[key]) == TYPE_DICTIONARY and typeof(right[key]) == TYPE_DICTIONARY: result.append_array(differences(left[key], right[key], path))
			elif left[key] != right[key]: result.append(path)
		return result

class LegacyRun extends ObservedRun:
	func _advance_published_turn_counter(_previous: int, _next: int) -> void:
		pass


static func check(restored: RunState, library: ContentLibrary) -> Dictionary:
	var failures: Array = []
	var checks: Array = []
	var expect := func(ok: bool, label: String) -> void:
		checks.append(label)
		if not ok: failures.append(label)
	var before := var_to_bytes(restored.to_dict())
	var fast := _clone(restored, false)
	var legacy := _clone(restored, true)
	var event := EventModule.new()
	event.setup(library.event("back_alley_offer"), library)
	var cash := fast.bankroll
	var rng := [fast.rng_seed, fast.rng_state]
	var started := Time.get_ticks_usec()
	var reference := event.resolve(legacy, legacy.current_environment, "take_cash", true, false)
	var legacy_usec := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var result := event.resolve(fast, fast.current_environment, "take_cash", true, false)
	var candidate_usec := Time.get_ticks_usec() - started
	expect.call(bool(result.get("ok", false)) and result == reference, "genuine_offer_result_matches_original")
	expect.call(fast.bankroll == cash + 8 and [fast.rng_seed, fast.rng_state] == rng, "genuine_offer_cash_rng_preserved")
	var offer_differences := _different_paths(fast.to_dict(), legacy.to_dict())
	var offer_flushes := fast.flushes.duplicate(true)
	var clock_writes := fast.clock_writes.duplicate(true)
	expect.call(offer_differences.is_empty(), "genuine_offer_complete_state_clock_save_exact")
	expect.call(fast.flushes.size() == 2 and legacy.flushes.size() == 2 and bool(fast.flushes[0].get("unchanged", false)) and not bool(legacy.flushes[0].get("unchanged", false)) and bool(fast.flushes[1].get("unchanged", false)), "clock_only_first_flush_avoids_reconstruction")

	var room := restored.current_environment.duplicate(true)
	var publication := PublicationScript.new(room, {"private_test_proof":{"owned":[1]}})
	var previous: Variant = room.get("turns", 0)
	var next_turn := int(previous) + 1
	room["turns"] = next_turn
	var advanced := publication.advanced_turn_counter(room, previous, next_turn)
	expect.call(advanced != null and advanced.matches_environment(room) and not publication.matches_environment(room), "writer_advances_only_owned_counter_generation")
	var accepted := room.duplicate(true)
	room["description"] = "mutated caller alias"
	expect.call(advanced != null and advanced.matches_environment(accepted) and not advanced.matches_environment(room), "advanced_publication_owns_input_graph")
	var exposed: Dictionary = advanced.snapshot()
	exposed["environment"]["description"] = "mutated public output"
	exposed["proof"]["private_test_proof"]["owned"].append(2)
	expect.call(advanced.matches_environment(accepted) and advanced.snapshot()["proof"]["private_test_proof"]["owned"] == [1], "advanced_publication_owns_output_and_proof")
	room = restored.current_environment.duplicate(true)
	room["turns"] = next_turn
	for field in ["description", "layout", "scenario_sequence_state", "runtime_object_manifest_entries", "service_ids", "unknown_future_authority"]:
		var changed := room.duplicate(true)
		if field == "description": changed[field] = "changed"
		elif field == "unknown_future_authority": changed[field] = {"new":true}
		elif typeof(changed.get(field)) == TYPE_ARRAY: changed[field].append({"unexpected":true})
		elif typeof(changed.get(field)) == TYPE_DICTIONARY: changed[field]["unexpected"] = true
		else: changed[field] = {"unexpected":true}
		expect.call(publication.advanced_turn_counter(changed, previous, next_turn) == null, "simultaneous_" + field + "_mutation_requires_full_boundary")
	expect.call(publication.advanced_turn_counter(room, previous + 2, next_turn) == null and publication.advanced_turn_counter(room, previous, previous) == null, "invalid_counter_transition_rejected")
	room["turns"] = float(next_turn)
	expect.call(publication.advanced_turn_counter(room, previous, next_turn) == null, "counter_type_change_not_normalized_away")
	for bad_previous in [-1, 0.5, INF, "0"]:
		var bad_room := restored.current_environment.duplicate(true)
		bad_room["turns"] = bad_previous
		var bad_publication := PublicationScript.new(bad_room, {})
		bad_room["turns"] = 1
		expect.call(bad_publication.advanced_turn_counter(bad_room, 0, 1) == null, "invalid_old_counter_" + str(bad_previous) + "_uses_full_boundary")

	# A real subscribed event remains a full ordered causal commit. Advancing the
	# clock must not authenticate its queued mutation as an unchanged room.
	fast = _clone(restored, false)
	legacy = _clone(restored, true)
	var payload := {"source_id": fast.current_world_node_id(), "target_id":"motel_node", "travel_kind":"world"}
	var ingress := fast.scenario_enqueue_fact("travel_departed", "travel", payload, "turn-counter:travel:1")
	legacy.scenario_enqueue_fact("travel_departed", "travel", payload, "turn-counter:travel:1")
	result = fast.advance_environment_turns(1)
	reference = legacy.advance_environment_turns(1)
	expect.call(bool(ingress.get("ok", false)) and bool(result.get("ok", false)) and result == reference and fast.to_dict() == legacy.to_dict(), "subscribed_event_complete_state_order_matches_original")
	expect.call(not fast.flushes.is_empty() and not bool(fast.flushes[0].get("unchanged", false)) and (fast.flushes[0].get("processed", []) as Array).has("turn-counter:travel:1"), "subscribed_event_forces_full_publication")
	var repeated := fast.scenario_flush_facts()
	expect.call(bool(repeated.get("ok", false)) and (repeated.get("processed", []) as Array).is_empty(), "subscribed_event_not_replayed")

	for stage in ["environment", "world_fact"]:
		fast = _clone(restored, false)
		var state_before := var_to_bytes(fast.to_dict())
		var revision := fast.room_presentation_revision()
		var original_publication: RefCounted = fast._room_presentation_publication
		fast._turn_transaction_test_failure_stage = stage
		result = fast.advance_environment_turns(1)
		expect.call(not bool(result.get("ok", true)) and result.get("failure_stage") == stage and state_before == var_to_bytes(fast.to_dict()) and fast.room_presentation_revision() == revision and is_same(fast._room_presentation_publication, original_publication), "late_" + stage + "_rejection_restores_full_state_rng_publication")
	expect.call(before == var_to_bytes(restored.to_dict()), "original_genuine_fixture_unchanged")
	return {"passed":failures.is_empty(), "checks":checks, "failures":failures,
		"offer_differences":offer_differences, "offer_flushes":offer_flushes, "clock_writes":clock_writes,
		"same_input_native_offer_usec":{"original":legacy_usec,"candidate":candidate_usec},
		"timing_scope":"native contextual; not a Web speed claim"}


static func _clone(source: RunState, legacy: bool) -> ObservedRun:
	var result: ObservedRun = LegacyRun.new() if legacy else ObservedRun.new()
	result._apply_environment_turn_snapshot(source._environment_turn_snapshot(), false)
	result.current_environment = source.current_environment.duplicate(true)
	result.publish_room_presentation()
	return result


static func _different_paths(left: Variant, right: Variant, path: String = "") -> Array:
	if left == right: return []
	var differences: Array = []
	if typeof(left) == TYPE_DICTIONARY and typeof(right) == TYPE_DICTIONARY:
		var keys: Array = left.keys()
		for key in right.keys():
			if not keys.has(key): keys.append(key)
		for key in keys:
			differences.append_array(_different_paths(left.get(key), right.get(key), path + "." + str(key)))
	else:
		differences.append(path)
	return differences
