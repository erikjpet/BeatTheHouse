extends RefCounted

# Focused contract. The private genuine-offer runner supplies a normally
# restored RunState; this helper never reads a user profile or opens a save.
const EngineScript := preload("res://scripts/core/scenario_engine.gd")
const RuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const FixtureScript := preload("res://scripts/tests/foundation/scenario_sequence_contract.gd")

class ObservedRun extends RunState:
	var flushes: Array = []
	func scenario_flush_facts(boundary_serial: int = -1) -> Dictionary:
		var result := super.scenario_flush_facts(boundary_serial)
		flushes.append({"ok": result.get("ok"), "unchanged": result.get("unchanged", false), "processed": result.get("processed", []).duplicate()})
		return result


class FullCommitRun extends RunState:
	func scenario_flush_facts(boundary_serial: int = -1) -> Dictionary:
		var candidate := current_environment.duplicate(false)
		var target := _crew_action_index() if boundary_serial < 0 else boundary_serial
		var result := EngineScript.flush_sequence_facts(candidate, _scenario_sequence_definition_readonly(), target)
		return _publish_scenario_membership_candidate(candidate, result, "fact flush")


static func check(restored: RunState, library: ContentLibrary) -> Dictionary:
	var failures: Array = []
	var checked: Array = []
	var expect := func(ok: bool, label: String) -> void:
		checked.append(label)
		if not ok: failures.append(label)
	# A cold restore does not retain runtime compilation receipts. The first full
	# flush establishes one; only the redundant subsequent boundary may reuse it.
	var primed := _clone(restored)
	_force_flush(primed)
	var fast := _clone(primed)
	var legacy := _clone(primed)
	var before := var_to_bytes(fast.to_dict())
	var revision := fast.room_presentation_revision()
	var diagnostic := _diagnostic(fast)
	var result := fast.scenario_flush_facts()
	var reference := _force_flush(legacy)
	expect.call(bool(result.get("ok", false)) and bool(result.get("unchanged", false)), "authenticated_empty_flush_skips_republication")
	expect.call(before == var_to_bytes(fast.to_dict()) and fast.room_presentation_revision() == revision, "empty_flush_preserves_full_state_rng_publication")
	expect.call(fast.to_dict() == legacy.to_dict() and _without_marker(result) == reference, "empty_flush_matches_full_commit")
	var retained: Dictionary = result.duplicate(true)
	var publication: RefCounted = fast._room_presentation_publication
	var definition_at_flush := fast._scenario_sequence_definition_readonly()
	expect.call(not publication.repeat_verified_empty_flush(fast.current_environment, definition_at_flush, fast._crew_action_index()).is_empty(), "verified_flush_receipt_is_available")
	expect.call(publication.repeat_verified_empty_flush(fast.current_environment, definition_at_flush, fast._crew_action_index() + 1).is_empty(), "different_boundary_cannot_reuse_empty_flush")
	var changed_definition := definition_at_flush.duplicate(true)
	changed_definition["display_name"] = "changed after verification"
	expect.call(publication.repeat_verified_empty_flush(fast.current_environment, changed_definition, fast._crew_action_index()).is_empty(), "changed_definition_cannot_reuse_empty_flush")
	(result["state"] as Dictionary).clear()
	(result["projection"] as Dictionary).clear()
	expect.call(before == var_to_bytes(fast.to_dict()), "noop_outputs_are_owned")
	expect.call(fast.scenario_flush_facts() == retained, "retained_empty_flush_result_is_owned_and_exact")
	var invalid_environment := fast.current_environment.duplicate(true)
	var invalid_records: Array = []
	invalid_records.resize(RuntimeScript.MAX_RECEIPTS + 1)
	invalid_records.fill({})
	invalid_environment["scenario_sequence_state"]["fact_receipt_records"] = invalid_records
	var invalid_publication: RefCounted = publication.get_script().new(invalid_environment, publication.get("_proof"))
	var invalid_result := retained.duplicate(true)
	invalid_result["state"] = invalid_environment["scenario_sequence_state"]
	invalid_publication.retain_verified_empty_flush(definition_at_flush, fast._crew_action_index(), invalid_result)
	expect.call(invalid_publication.repeat_verified_empty_flush(invalid_environment, definition_at_flush, fast._crew_action_index()).is_empty(), "runtime_capacity_rejection_cannot_mint_empty_flush_receipt")

	# Aliases changed after publication cannot retain its no-op authorization.
	for field in ["scenario_sequence_projection", "layout", "service_ids", "scenario_layout_context", "scenario_sequence_state"]:
		fast = _clone(primed)
		legacy = _clone(primed)
		fast.scenario_flush_facts()
		_mutate(fast.current_environment, field)
		_mutate(legacy.current_environment, field)
		result = fast.scenario_flush_facts()
		reference = _force_flush(legacy)
		expect.call(not bool(result.get("unchanged", false)) and result == reference and fast.to_dict() == legacy.to_dict(), "aliased_" + field + "_uses_original_rejection_or_commit")

	# Even a newly captured physical publication is not sufficient to authorize a
	# stale causal projection/materialization; Engine checks those separately.
	fast = _clone(primed)
	fast.scenario_flush_facts()
	(fast.current_environment["scenario_sequence_projection"] as Dictionary)["last_feedback"] = "stale"
	fast.publish_room_presentation()
	result = fast.scenario_flush_facts()
	expect.call(not bool(result.get("unchanged", false)), "physical_publication_is_not_causal_readiness_bypass")
	fast = _clone(primed)
	var rollback := fast._environment_turn_snapshot()
	before = var_to_bytes(fast.to_dict())
	revision = fast.room_presentation_revision()
	fast.scenario_flush_facts()
	fast.current_environment = {}
	fast._apply_environment_turn_snapshot(rollback, false)
	expect.call(before == var_to_bytes(fast.to_dict()) and fast.room_presentation_revision() == revision, "rollback_restores_full_state_rng_and_publication")

	# Real room subscription through the full Engine/RunState publication seam.
	fast = _clone(primed)
	legacy = _clone(primed)
	fast.scenario_flush_facts()
	var payload := {"source_id": fast.current_world_node_id(), "target_id": "motel_node", "travel_kind": "world"}
	var ingress := fast.scenario_enqueue_fact("travel_departed", "travel", payload, "empty-flush:travel:1")
	legacy.scenario_enqueue_fact("travel_departed", "travel", payload, "empty-flush:travel:1")
	result = fast.scenario_flush_facts()
	reference = _force_flush(legacy)
	expect.call(bool(ingress.get("ok", false)) and bool(result.get("ok", false)) and not bool(result.get("unchanged", false)) and result.get("processed", []) == ["empty-flush:travel:1"], "observed_room_event_requires_normal_publication")
	expect.call(result == reference and fast.to_dict() == legacy.to_dict(), "observed_room_event_matches_full_commit")

	var observed := ObservedRun.new()
	observed._apply_environment_turn_snapshot(restored._environment_turn_snapshot(), false)
	observed.current_environment = restored.current_environment.duplicate(true)
	observed.publish_room_presentation()
	var event := EventModule.new()
	event.setup(library.event("back_alley_offer"), library)
	var cash := observed.bankroll
	var rng := [observed.rng_seed, observed.rng_state]
	result = event.resolve(observed, observed.current_environment, "take_cash", true, true)
	expect.call(bool(result.get("ok", false)) and observed.bankroll == cash + 8 and rng == [observed.rng_seed, observed.rng_state], "genuine_offer_effects_rng_unchanged")
	expect.call(not observed.flushes.is_empty() and bool((observed.flushes.back() as Dictionary).get("unchanged", false)), "actual_offer_second_flush_is_authenticated_noop")
	var full_commit := FullCommitRun.new()
	full_commit._apply_environment_turn_snapshot(restored._environment_turn_snapshot(), false)
	full_commit.current_environment = restored.current_environment.duplicate(true)
	full_commit.publish_room_presentation()
	var full_result := event.resolve(full_commit, full_commit.current_environment, "take_cash", true, false)
	var offer_parity_differences := _different_paths(observed.to_dict(), full_commit.to_dict())
	# Event membership deliberately invalidates this optimization cache key at
	# RunState.prepare_resolved_event_membership_for_publication(). An unrelated
	# empty causal flush must not force layout generation merely to refill it.
	# Preserve the raw difference, require it to be exactly that named cache
	# invalidation, then compare EVERY field at the next normal layout boundary.
	expect.call(offer_parity_differences.size() == 1 and offer_parity_differences[0]["path"] == ".current_environment.layout.grounding_signature" and not observed.current_environment["layout"].has("grounding_signature") and str(full_commit.current_environment["layout"].get("grounding_signature", "")).length() == 64, "offer_only_retains_explicit_grounding_cache_invalidation")
	var canonical := observed.current_environment.duplicate(true)
	canonical["layout"] = EnvironmentInstance.ensure_generated_layout(canonical)
	observed.current_environment = canonical
	observed.publish_room_presentation()
	var canonical_parity_differences := _different_paths(observed.to_dict(), full_commit.to_dict())
	expect.call(bool(full_result.get("ok", false)) and observed.to_dict() == full_commit.to_dict(), "actual_offer_full_state_exact_at_next_layout_boundary")

	# A subscribed event remains a real causal batch, including its original
	# pending-boundary, receipt order, and exactly-once behavior.
	var definition := FixtureScript._runtime_definition()
	var initial := RuntimeScript.initial_state(definition, "bar_node", "empty-flush-countercase", FixtureScript._fixture_host_semantics(definition))
	var fact := RuntimeScript.fact("event_result", "event", "bar_node", "empty-flush:event:1", 1, 7, FixtureScript._fact_payload("event_result"))
	var queued := RuntimeScript.enqueue_fact(initial, definition, fact)
	expect.call(bool(queued.get("ok", false)), "subscribed_event_fact_accepted")
	var queued_state: Dictionary = queued.get("state", {})
	var waiting := RuntimeScript.flush_facts(queued_state, definition, 6, true)
	expect.call(bool(waiting.get("ok", false)) and is_same(waiting.get("state"), queued_state) and (waiting.get("processed", []) as Array).is_empty(), "future_event_not_consumed_early")
	var flushed := RuntimeScript.flush_facts(queued_state, definition, 7, true)
	var next: Dictionary = flushed.get("state", {})
	expect.call(bool(flushed.get("ok", false)) and not is_same(next, queued_state) and flushed.get("processed", []) == ["empty-flush:event:1"], "subscribed_event_crosses_real_commit_boundary")
	expect.call((next.get("fact_flush_batch_records", []) as Array).size() == 1 and (next.get("fact_receipts", []) as Array) == ["empty-flush:event:1"], "subscribed_event_receipt_order_preserved")
	var repeated := RuntimeScript.flush_facts(next, definition, 8, true)
	expect.call(bool(repeated.get("ok", false)) and is_same(repeated.get("state"), next) and (repeated.get("processed", []) as Array).is_empty(), "subscribed_event_not_replayed")
	var cleaned := next.duplicate(true)
	cleaned["status"] = RuntimeScript.STATUS_CLEANED
	expect.call(not bool(RuntimeScript.flush_facts(cleaned, definition, 8, true).get("ok", true)), "cleaned_state_rejection_precedes_noop")
	var over_capacity := next.duplicate(true)
	var oversized: Array = []
	oversized.resize(RuntimeScript.MAX_RECEIPTS + 1)
	oversized.fill(fact)
	over_capacity["fact_queue"] = oversized
	expect.call(not bool(RuntimeScript.flush_facts(over_capacity, definition, 6, true).get("ok", true)), "capacity_rejection_precedes_noop")
	return {"passed": failures.is_empty(), "checks": checked, "failures": failures, "offer_flushes": observed.flushes, "diagnostic": diagnostic, "offer_parity_differences": offer_parity_differences, "canonical_parity_differences": canonical_parity_differences}


static func _different_paths(left: Variant, right: Variant, path: String = "") -> Array:
	if left == right: return []
	var differences: Array = []
	if typeof(left) == TYPE_DICTIONARY and typeof(right) == TYPE_DICTIONARY:
		var keys: Array = left.keys()
		for key in right.keys():
			if not keys.has(key): keys.append(key)
		for key in keys:
			differences.append_array(_different_paths(left.get(key), right.get(key), path + "." + str(key)))
			if differences.size() >= 32: break
	elif typeof(left) == TYPE_ARRAY and typeof(right) == TYPE_ARRAY and left.size() == right.size():
		for index in range(left.size()):
			differences.append_array(_different_paths(left[index], right[index], path + "." + str(index)))
			if differences.size() >= 32: break
	else:
		differences.append({"path": path, "left_type": typeof(left), "right_type": typeof(right), "left_sha256": var_to_bytes(left).hex_encode().sha256_text(), "right_sha256": var_to_bytes(right).hex_encode().sha256_text()})
	return differences


static func _diagnostic(state: RunState) -> Dictionary:
	var environment := state.current_environment
	var definition := state._scenario_sequence_definition_readonly()
	var prepared := EngineScript.prepare_sequence_fact_flush(environment, definition, state._crew_action_index())
	var next: Dictionary = prepared["result"].get("state", {})
	var projection := RuntimeScript.public_projection(next, definition, true)
	var stored: Dictionary = environment.get("scenario_sequence_projection", {})
	var differences: Array = []
	for key in projection.keys():
		if projection[key] != stored.get(key): differences.append(key)
	var materialized := environment.duplicate(false)
	EngineScript._materialize_sequence_services_games_routes(materialized, stored)
	var material_differences: Array = []
	for key in materialized.keys():
		if materialized[key] != environment.get(key): material_differences.append(key)
	return {"unchanged_state": prepared["unchanged_state"], "publication_matches": state._room_presentation_publication.matches_environment(environment), "audit": environment.get("scenario_layout_audit"), "projection_differences": differences, "layout_input_matches": environment.get(EngineScript.TRUSTED_LAYOUT_INPUT_DIGEST_KEY) == EngineScript._sequence_layout_input_digest(environment, projection), "material_differences": material_differences}


static func _clone(source: RunState) -> RunState:
	var result := source._detached_environment_turn_candidate()
	result.current_environment = source.current_environment.duplicate(true)
	result.publish_room_presentation()
	return result


static func _force_flush(state: RunState) -> Dictionary:
	var candidate := state.current_environment.duplicate(false)
	var result := EngineScript.flush_sequence_facts(candidate, state._scenario_sequence_definition_readonly(), state._crew_action_index())
	return state._publish_scenario_membership_candidate(candidate, result, "fact flush")


static func _without_marker(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	result.erase("unchanged")
	return result


static func _mutate(environment: Dictionary, field: String) -> void:
	match field:
		"scenario_sequence_projection": environment[field]["last_feedback"] = "alias mutation"
		"layout": environment[field]["slot_binding_digest"] = "0".repeat(64)
		"service_ids": environment[field].append("unexpected_service")
		"scenario_layout_context": environment[field]["mutation"] = true
		"scenario_sequence_state": environment[field]["semantic_state"]["inventory_digest"] = "0".repeat(64)
