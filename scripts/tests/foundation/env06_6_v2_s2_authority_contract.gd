extends SceneTree

const RunStateScript := preload("res://scripts/core/run_state.gd")
const ScenarioSequenceContractScript := preload("res://scripts/tests/foundation/scenario_sequence_contract.gd")


func _initialize() -> void:
	var failures: Array = []
	ScenarioSequenceContractScript._check_augment_availability(failures)
	_check_named_restore_equivalence(failures)
	if failures.is_empty():
		print("env06_6 V2/S2 authority contract passed")
		quit(0)
		return
	for failure in failures:
		push_error(str(failure))
	quit(1)


func _check_named_restore_equivalence(failures: Array) -> void:
	var causal_state := {
		"schema_version": 2,
		"scenario_id": "restore_fixture",
		"status": "active",
		"phase_id": "arrival",
		"boundary_serial": 3,
		"resolved_branches": ["branch:kept"],
		"resolved_outcomes": {"outcome:kept": "success"},
		"command_receipts": ["command:kept"],
		"semantic_state": {
			"base_interactions": [{"owner_namespace": "base", "stable_object_id": "door", "enabled": true, "interactive": true}],
			"target_inventory": {"interactions": ["base::door"]},
			"transition_queue": [{"receipt_id": "transition:kept"}],
		},
	}
	var live := {
		"id": "restore_fixture_environment",
		"environment_visit_id": "visit:restore_fixture",
		"scenario_sequence_state": causal_state,
		"scenario_semantic_ready": true,
		"scenario_semantic_inventory": {"kind": "instance", "digest": "authority:kept"},
		"scenario_base_interactions": causal_state["semantic_state"]["base_interactions"],
		"scenario_base_actors": [],
		"scenario_base_producer_context": {"producer": "trusted_host"},
		"scenario_semantic_action_digest": "action:kept",
		"scenario_event_choices": {"event": {"choice": "kept"}},
		"scenario_layout_authority": {"base::door": {"rect": {"x": 0.1, "y": 0.1, "w": 0.2, "h": 0.2}}},
		"scenario_layout_authority_digest": "layout:kept",
		"scenario_sequence_projection": {"derived": true},
		"scenario_render_snapshot": {"derived": true},
		"scenario_layout_context": {"derived": true},
		"scenario_layout_audit": {"derived": true},
	}
	var stored := RunStateScript._environment_for_persistent_storage(live)
	if str(stored.get("scenario_restore_contract", "")) != RunStateScript.ENV06_6B_SEMANTIC_RESTORE_EQUIVALENCE_V1:
		failures.append("S2 storage omitted the named semantic restore-equivalence contract.")
	for exact_key in ["scenario_semantic_inventory", "scenario_base_interactions", "scenario_base_producer_context", "scenario_semantic_action_digest", "scenario_event_choices", "scenario_layout_authority", "scenario_layout_authority_digest"]:
		if JSON.stringify(stored.get(exact_key)) != JSON.stringify(live.get(exact_key)):
			failures.append("S2 storage changed exact authority field %s." % exact_key)
	var stored_state := stored.get("scenario_sequence_state", {}) as Dictionary
	for exact_key in ["resolved_branches", "resolved_outcomes", "command_receipts", "semantic_state"]:
		if JSON.stringify(stored_state.get(exact_key)) != JSON.stringify(causal_state.get(exact_key)):
			failures.append("S2 storage changed exact causal sequence field %s." % exact_key)
	for derived_key in RunStateScript.SCENARIO_DERIVED_NONCAUSAL_ENVIRONMENT_FIELDS:
		if stored.has(str(derived_key)):
			failures.append("S2 storage retained derived noncausal field %s." % str(derived_key))
	if not RunStateScript.scenario_restore_equivalent(live, stored):
		failures.append("S2 named comparator rejected a save differing only in declared derived noncausal fields.")
