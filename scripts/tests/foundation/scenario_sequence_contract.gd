extends RefCounted

const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const SequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const SequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const HostTransactionScript := preload("res://scripts/core/scenario_host_transaction.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const RolloutManifestScript := preload("res://scripts/core/scenario_sequence_rollout_manifest.gd")


static func check(library: ContentLibrary, failures: Array) -> void:
	_check_schema(failures)
	_check_catalog_rollout(library, failures)
	_check_registered_operations(failures)
	_check_interaction_identity(failures)
	_check_negative_fixtures(failures)
	_check_lifecycle_commands(failures)
	_check_handler_reducer_contracts(failures)
	_check_serialized_fact_ingress(failures)
	_check_atomic_runtime_failures(failures)
	_check_sequence_persistence_seam(failures)
	_check_authoritative_receipt_capacity(failures)
	_check_host_transaction_seam(failures)


static func _check_catalog_rollout(library: ContentLibrary, failures: Array) -> void:
	var definitions: Array = []
	for pool_value in library.environment_scenarios.values():
		definitions.append_array(_array(pool_value))
	var report := SequenceSchemaScript.catalog_rollout_report(definitions, RolloutManifestScript.expected_ids(), OperationRegistryScript, {}, RolloutManifestScript.required_sequence_ids())
	if RolloutManifestScript.EXPECTED_COUNT != 55 or RolloutManifestScript.expected_ids().size() != 55 or not bool(report.get("ok", false)):
		failures.append("Production sequence rollout manifest does not enforce the exact 55-id catalog without blocking pending env06_7 packages: %s" % JSON.stringify(report.get("failures", [])))
	var proof := _fixture_definition()
	proof["id"] = "proof"
	var pending := {"id": "pending"}
	var proof_report := SequenceSchemaScript.catalog_rollout_report([pending, proof], ["pending", "proof"], OperationRegistryScript, {}, ["proof"])
	if not bool(proof_report.get("ok", false)):
		failures.append("A valid declared sequence proof was blocked by an explicitly pending catalog id.")
	var missing_report := SequenceSchemaScript.catalog_rollout_report([pending, {"id": "proof"}], ["pending", "proof"], OperationRegistryScript, {}, ["proof"])
	if bool(missing_report.get("ok", true)) or not _contains_text(_array(missing_report.get("failures", [])), "missing its required sequence"):
		failures.append("Rollout manifest accepted a missing sequence-required proof.")


static func _check_schema(failures: Array) -> void:
	var definition := _fixture_definition()
	var errors := SequenceSchemaScript.validate_definition(definition, OperationRegistryScript)
	if not errors.is_empty():
		failures.append("Valid sequence schema fixture failed: %s" % JSON.stringify(errors))
	var defaults := SequenceSchemaScript.default_local_state(definition)
	if defaults != {"pressure": 0, "protected_exit": false, "side": "none"}:
		failures.append("Sequence local-state defaults are not typed/deterministic: %s." % JSON.stringify(defaults))
	var normalized := SequenceSchemaScript.normalize_local_state(definition, {"pressure": 99, "protected_exit": "yes", "side": "invalid", "unknown": true})
	if normalized != {"pressure": 5, "protected_exit": false, "side": "none"}:
		failures.append("Sequence local-state normalization did not clamp/reject invalid values: %s." % JSON.stringify(normalized))
	if SequenceSchemaScript.initial_phase_id(definition) != "arrival" or SequenceSchemaScript.phase_ids(definition) != ["arrival", "aftermath"]:
		failures.append("Sequence phase identity/order is unstable.")
	var signature_a := SequenceSchemaScript.normalized_signature(definition)
	var renamed := definition.duplicate(true)
	renamed["id"] = "renamed_fixture"
	renamed["display_name"] = "Different prose"
	if SequenceSchemaScript.signature_text(definition) != SequenceSchemaScript.signature_text(renamed) or SequenceSchemaScript.signature_similarity(signature_a, SequenceSchemaScript.normalized_signature(renamed)) != 1.0:
		failures.append("Calculated mechanic signature can be evaded by renaming display identity.")
	var identity_renamed := definition.duplicate(true)
	identity_renamed["sequence"]["phase_graph"]["phases"][0]["scene_ops"][0]["stable_object_id"] = "renamed_prop"
	identity_renamed["sequence"]["phase_graph"]["phases"][0]["scene_ops"][0]["receipt_id"] = "renamed_receipt"
	if SequenceSchemaScript.signature_text(definition) != SequenceSchemaScript.signature_text(identity_renamed):
		failures.append("Calculated mechanic signature changes under stable-id/receipt renaming.")
	var reordered := definition.duplicate(true)
	reordered["sequence"]["phase_graph"]["phases"].reverse()
	if SequenceSchemaScript.signature_text(definition) != SequenceSchemaScript.signature_text(reordered):
		failures.append("Calculated mechanic signature changes under phase reordering.")
	var mismatched_signature := definition.duplicate(true)
	mismatched_signature["sequence"]["sequence_signature"] = "forged"
	if not _contains_text(SequenceSchemaScript.validate_definition(mismatched_signature, OperationRegistryScript), "sequence_signature mismatch"):
		failures.append("Sequence schema accepted an authored/calculated signature mismatch.")
	var boundary_expectations := [[0.599, "pass"], [0.600, "warning"], [0.719, "warning"], [0.720, "blocking_review"], [0.819, "blocking_review"], [0.820, "fail"]]
	for expectation_value in boundary_expectations:
		var expectation := expectation_value as Array
		var score := float(expectation[0])
		var expected_band := str(expectation[1])
		if str(SequenceSchemaScript.uniqueness_band(score).get("status", "")) != expected_band:
			failures.append("Uniqueness band boundary %.3f did not resolve to %s." % [score, expected_band])
	if str(SequenceSchemaScript.uniqueness_band(0.1, true).get("status", "")) != "equal_hash_hard_fail":
		failures.append("Equal normalized mechanic hashes are not a hard failure.")
	var exact_count := SequenceSchemaScript.catalog_uniqueness_report([definition], 2, OperationRegistryScript)
	if bool(exact_count.get("ok", true)) or not _contains_text(_array(exact_count.get("failures", [])), "expected 2"):
		failures.append("Sequence rollout audit did not enforce exact catalog count.")


static func _check_registered_operations(failures: Array) -> void:
	var operations := OperationRegistryScript.registered_operations()
	var expected := {
		"scene_ops": ["spawn", "remove", "move", "replace", "reveal", "hide", "enable", "disable", "set_state", "set_appearance"],
		"interaction_ops": ["add", "remove", "replace", "gate", "retarget", "augment"],
		"actor_ops": ["spawn", "despawn", "set_position", "set_route", "set_pose", "set_behavior"],
		"transition_ops": ["stage", "sound", "music", "scene_change", "feedback"],
		"service_ops": ["add", "remove", "gate", "replace"],
		"game_ops": ["add", "remove", "gate", "set_modifier"],
		"route_ops": ["open", "close", "gate", "retarget"],
	}
	if operations != expected:
		failures.append("Scenario registered operation surface changed: %s." % JSON.stringify(operations))
	var state := _operation_semantic_seed()
	for family_value in expected.keys():
		var family := str(family_value)
		var family_operations: Array = []
		for index in range((expected[family] as Array).size()):
			family_operations.append(_operation_fixture(family, str((expected[family] as Array)[index]), index))
		var boundary_scope := "fixture:node:phase:%s" % family
		var applied := OperationRegistryScript.apply_operations(state, family, family_operations, boundary_scope)
		if not bool(applied.get("ok", false)):
			failures.append("Registered %s fixtures failed: %s." % [family, JSON.stringify(applied.get("errors", []))])
			continue
		state = _dict(applied.get("state", {}))
		var replay := OperationRegistryScript.apply_operations(state, family, family_operations, boundary_scope)
		if not bool(replay.get("ok", false)) or not _array(replay.get("applied", [])).is_empty() or JSON.stringify(replay.get("state", {})) != JSON.stringify(state):
			failures.append("Registered %s operations are not idempotent by boundary receipt." % family)
	if _array(state.get("operation_receipts", [])).size() != 39:
		failures.append("Registered operation fixture did not receipt every operation exactly once.")
	_check_golden_operation_state(state, failures)
	var before_atomic := JSON.stringify(state)
	var valid := _operation_fixture("scene_ops", "set_state", 901)
	var invalid := _operation_fixture("scene_ops", "set_state", 902)
	invalid["op"] = "reflect"
	var atomic := OperationRegistryScript.apply_operations(state, "scene_ops", [valid, invalid], "fixture:node:phase:atomic")
	if bool(atomic.get("ok", true)) or not _array(atomic.get("applied", [])).is_empty() or JSON.stringify(atomic.get("state", {})) != before_atomic:
		failures.append("Scenario operation batch was not prevalidated and atomic.")
	var duplicate_receipt_a := _operation_fixture("scene_ops", "set_state", 903)
	var duplicate_receipt_b := _operation_fixture("scene_ops", "set_appearance", 904)
	duplicate_receipt_b["receipt_id"] = duplicate_receipt_a["receipt_id"]
	if bool(OperationRegistryScript.apply_operations(state, "scene_ops", [duplicate_receipt_a, duplicate_receipt_b], "fixture:node:phase:duplicate").get("ok", true)):
		failures.append("Scenario operation batch accepted duplicate authored receipt ids.")
	var conflicting_replay := _operation_fixture("scene_ops", "set_state", 8)
	conflicting_replay["state"] = "conflicting"
	var conflict := OperationRegistryScript.apply_operations(state, "scene_ops", [conflicting_replay], "fixture:node:phase:scene_ops")
	if bool(conflict.get("ok", true)) or not _contains_text(_array(conflict.get("errors", [])), "conflicting content"):
		failures.append("Scenario operation receipt accepted conflicting replay content.")
	var wrong_family := _operation_fixture("scene_ops", "set_state", 905)
	wrong_family["family"] = "actor_ops"
	if OperationRegistryScript.validate_operation("scene_ops", wrong_family).is_empty():
		failures.append("Scenario operation accepted a mismatched family field.")
	if bool(OperationRegistryScript.apply_operations(state, "scene_ops", [valid], "unscoped").get("ok", true)):
		failures.append("Scenario operation batch accepted an unscoped boundary receipt.")
	var handlers := OperationRegistryScript.registered_handlers()
	for handler_id in ["set_local", "increment_local", "complete_objective_step", "record_outcome", "publish_feedback", "request_cleanup", "event_bridge"]:
		var handler := _dict(handlers.get(handler_id, {}))
		if handler.is_empty() or str(handler.get("rng", "")) != "none" or not handler.has("persistent") or _array(handler.get("outputs", [])).is_empty():
			failures.append("Scenario handler %s lacks explicit input/output/persistence/RNG contract." % handler_id)
	var absent_target := _operation_fixture("scene_ops", "set_state", 9999)
	var absent_result := OperationRegistryScript.apply_operations(state, "scene_ops", [absent_target], "fixture:node:phase:absent")
	if bool(absent_result.get("ok", true)) or JSON.stringify(absent_result.get("state", {})) != JSON.stringify(state):
		failures.append("Scenario operation synthesized an undeclared absent target.")
	var alias_left := OperationRegistryScript.structural_receipt_key("a:b:c:d", "scene_ops", "x:y")
	var alias_right := OperationRegistryScript.structural_receipt_key("a:b:c:d:x", "scene_ops", "y")
	if alias_left == alias_right:
		failures.append("Structural operation receipt identity aliases colon-delimited tuples.")


static func _check_interaction_identity(failures: Array) -> void:
	var base := [_interaction_record("base", "exit", "Leave", true)]
	var gate := _interaction_record("scenario", "exit_gate", "Fight blocks the door", false)
	gate["mode"] = "gate"
	gate["target_owner_namespace"] = "base"
	gate["target_stable_object_id"] = "exit"
	gate["disabled_reason"] = "Clear a readable path first."
	var resolved := OperationRegistryScript.resolve_interactions(base, [gate])
	var records := _array(resolved.get("records", []))
	if not bool(resolved.get("ok", false)) or records.size() != 1 or bool(_dict(records[0]).get("enabled", true)) or str(_dict(records[0]).get("disabled_reason", "")).is_empty():
		failures.append("Explicit scenario gate did not preserve and fail-close the base interaction identity.")
	var duplicate := OperationRegistryScript.resolve_interactions(base, [_interaction_record("base", "exit", "Hostile duplicate", true)])
	if bool(duplicate.get("ok", true)) or not _array(duplicate.get("records", [])).is_empty():
		failures.append("Illegal same-owner interaction collision did not fail closed.")
	var low_priority := _interaction_record("traveler", "bad_replace", "Traveler", true)
	low_priority["mode"] = "replace"
	low_priority["target_owner_namespace"] = "scenario"
	low_priority["target_stable_object_id"] = "high"
	var higher := _interaction_record("scenario", "high", "Scenario", true)
	var priority_result := OperationRegistryScript.resolve_interactions([higher], [low_priority])
	if bool(priority_result.get("ok", true)) or _array(priority_result.get("records", [])).size() != 1 or str(_dict(_array(priority_result.get("records", []))[0]).get("owner_namespace", "")) != "scenario":
		failures.append("Lower-priority interaction override did not fail closed.")
	var triple := OperationRegistryScript.resolve_interactions([
		_interaction_record("base", "triple", "One", true),
		_interaction_record("base", "triple", "Two", true),
		_interaction_record("base", "triple", "Three", true),
	], [])
	if bool(triple.get("ok", true)) or not _array(triple.get("records", [])).is_empty():
		failures.append("Triple duplicate interaction identity was not permanently tainted.")
	var invalid_owner := _interaction_record("intruder", "bad", "Bad", true)
	var invalid_mode := _interaction_record("scenario", "bad_mode", "Bad", true)
	invalid_mode["mode"] = "steal"
	var missing_target := _interaction_record("scenario", "missing_target", "Missing", true)
	missing_target["mode"] = "replace"
	missing_target["target_owner_namespace"] = "base"
	missing_target["target_stable_object_id"] = "absent"
	var hostile := OperationRegistryScript.resolve_interactions(base, [invalid_owner, invalid_mode, missing_target])
	if bool(hostile.get("ok", true)) or _array(hostile.get("records", [])).size() != 1 or str(_dict(_array(hostile.get("records", []))[0]).get("stable_object_id", "")) != "exit":
		failures.append("Invalid owner/mode/missing-target overlays leaked invalid interaction records.")
	var inaccessible := _interaction_record("scenario", "bad_accessibility", "Bad", true)
	inaccessible["focus_order"] = "first"
	inaccessible["hit_bounds"] = {"w": 43, "h": 44}
	inaccessible["min_target_size"] = 43
	inaccessible["safe_exit"] = "yes"
	inaccessible["input_actions"] = [7]
	var inaccessible_result := OperationRegistryScript.resolve_interactions(base, [inaccessible])
	if bool(inaccessible_result.get("ok", true)) or _array(inaccessible_result.get("records", [])).size() != 1:
		failures.append("Inaccessible interaction overlay did not fail closed without leaking a record.")
	var hostile_base := _interaction_record("base", "non_add_base", "Bad base", true)
	hostile_base["mode"] = "gate"
	hostile_base["target_owner_namespace"] = "base"
	hostile_base["target_stable_object_id"] = "exit"
	if bool(OperationRegistryScript.resolve_interactions([hostile_base], []).get("ok", true)):
		failures.append("Base interaction accepted a non-add overlay mode.")
	var competing := gate.duplicate(true)
	competing["stable_object_id"] = "exit_gate_two"
	var competing_result := OperationRegistryScript.resolve_interactions(base, [gate, competing])
	var competing_records := _array(competing_result.get("records", []))
	if bool(competing_result.get("ok", true)) or competing_records.size() != 1 or not bool(_dict(competing_records[0]).get("enabled", false)):
		failures.append("Competing interaction overlays did not fail closed before mutating their shared target.")


static func _check_golden_operation_state(state: Dictionary, failures: Array) -> void:
	var scene := _dict(state.get("scene_objects", {}))
	var interactions := _dict(state.get("interactions", {}))
	var actors := _dict(state.get("actors", {}))
	var services := _dict(state.get("services", {}))
	var games := _dict(state.get("games", {}))
	var routes := _dict(state.get("routes", {}))
	var checks := [
		[not scene.has("scenario::fixture_1"), "scene remove"],
		[str(_dict(scene.get("scenario::fixture_2", {})).get("anchor_id", "")) == "bar_floor_3", "scene move"],
		[bool(_dict(scene.get("scenario::fixture_4", {})).get("visible", false)), "scene reveal"],
		[not bool(_dict(scene.get("scenario::fixture_5", {})).get("visible", true)), "scene hide"],
		[bool(_dict(scene.get("scenario::fixture_6", {})).get("enabled", false)), "scene enable"],
		[not bool(_dict(scene.get("scenario::fixture_7", {})).get("enabled", true)), "scene disable"],
		[str(_dict(scene.get("scenario::fixture_8", {})).get("state", "")) == "ready", "scene state"],
		[str(_dict(scene.get("scenario::fixture_9", {})).get("appearance", "")) == "scuffed", "scene appearance"],
		[str(_dict(interactions.get("scenario::fixture_2", {})).get("mode", "")) == "replace", "interaction replace"],
		[not bool(_dict(interactions.get("scenario::fixture_3", {})).get("enabled", true)), "interaction gate"],
		[str(_dict(interactions.get("scenario::fixture_4", {})).get("source_id", "")) == "fixture_source", "interaction retarget"],
		[_array(_dict(interactions.get("scenario::fixture_5", {})).get("available_actions", [])).size() == 1, "interaction augment"],
		[not actors.has("scenario::fixture_1"), "actor despawn"],
		[str(_dict(actors.get("scenario::fixture_2", {})).get("anchor_id", "")) == "bar_actor_2", "actor position"],
		[str(_dict(actors.get("scenario::fixture_3", {})).get("route_id", "")) == "bar_route", "actor route"],
		[str(_dict(actors.get("scenario::fixture_4", {})).get("pose", "")) == "brace", "actor pose"],
		[str(_dict(actors.get("scenario::fixture_5", {})).get("behavior", "")) == "watch", "actor behavior"],
		[_array(state.get("transition_queue", [])).size() == 5, "transition reducers"],
		[services.has("scenario::fixture_0") and not services.has("scenario::fixture_1") and not bool(_dict(services.get("scenario::fixture_2", {})).get("enabled", true)) and services.has("scenario::fixture_3"), "service reducers"],
		[games.has("scenario::fixture_0") and not games.has("scenario::fixture_1") and not bool(_dict(games.get("scenario::fixture_2", {})).get("enabled", true)) and games.has("scenario::fixture_3") and not _dict(_dict(games.get("scenario::fixture_3", {})).get("modifier", {})).is_empty(), "game reducers"],
		[bool(_dict(routes.get("scenario::fixture_0", {})).get("enabled", false)), "route open"],
		[not bool(_dict(routes.get("scenario::fixture_1", {})).get("enabled", true)), "route close"],
		[not bool(_dict(routes.get("scenario::fixture_2", {})).get("enabled", true)), "route gate"],
		[str(_dict(routes.get("scenario::fixture_3", {})).get("source_id", "")) == "alternate_exit", "route retarget"],
	]
	for check_value in checks:
		var check := check_value as Array
		if not bool(check[0]):
			failures.append("Golden registered-operation state failed for %s." % str(check[1]))


static func _check_negative_fixtures(failures: Array) -> void:
	var invalid_operation := _operation_fixture("scene_ops", "spawn", 0)
	invalid_operation["object"]["asset"] = "res://untrusted/script.gd"
	if OperationRegistryScript.validate_operation("scene_ops", invalid_operation).is_empty():
		failures.append("Scenario operation registry accepted an arbitrary resource path.")
	if OperationRegistryScript.validate_operation("scene_ops", {"op": "reflect", "owner_namespace": "scenario", "stable_object_id": "bad"}).is_empty():
		failures.append("Scenario operation registry accepted an unregistered operation.")
	var invalid := _fixture_definition()
	invalid["sequence"]["phase_graph"]["phases"].append({"id": "orphan", "label": "Orphan", "arrival_feedback": "Nobody reaches this.", "exit_prompt": "Leave", "terminal": true, "branches": []})
	if not _contains_text(SequenceSchemaScript.validate_definition(invalid, OperationRegistryScript), "unreachable phase"):
		failures.append("Sequence schema accepted an unreachable phase.")
	var exception := _fixture_definition()
	exception["sequence"]["owner_exceptions"] = [{"row": "semantic_changes", "reason": "Owner decision"}]
	if not _contains_text(SequenceSchemaScript.validate_definition(exception, OperationRegistryScript), "owner exception"):
		failures.append("Sequence schema accepted an unsigned owner exception.")
	var invalid_fact := _fixture_definition()
	invalid_fact["sequence"]["fact_subscriptions"] = ["invented_fact"]
	if not _contains_text(SequenceSchemaScript.validate_definition(invalid_fact, OperationRegistryScript), "unregistered fact type"):
		failures.append("Sequence schema accepted an unregistered fact subscription.")
	var dead_end := _fixture_definition()
	dead_end["sequence"]["phase_graph"]["phases"][0]["branches"] = []
	if not _contains_text(SequenceSchemaScript.validate_definition(dead_end, OperationRegistryScript), "dead end"):
		failures.append("Sequence schema accepted a non-terminal dead end.")
	var duplicate_branch := _fixture_definition()
	duplicate_branch["sequence"]["phase_graph"]["phases"][1]["branches"][1]["id"] = "finish"
	if not _contains_text(SequenceSchemaScript.validate_definition(duplicate_branch, OperationRegistryScript), "duplicate branch"):
		failures.append("Sequence schema accepted duplicate branch ids.")
	var nonterminating := _fixture_definition()
	nonterminating["sequence"]["phase_graph"]["phases"][1]["terminal"] = false
	nonterminating["sequence"]["phase_graph"]["phases"][1]["branches"] = [{"id": "loop", "condition": {"type": "always"}, "next_phase": "arrival"}]
	if not _contains_text(SequenceSchemaScript.validate_definition(nonterminating, OperationRegistryScript), "no path to a terminal"):
		failures.append("Sequence schema accepted a reachable non-terminating cycle.")
	var mismatched_aftermath := _fixture_definition()
	mismatched_aftermath["sequence"]["aftermath"].erase("refused")
	if not _contains_text(SequenceSchemaScript.validate_definition(mismatched_aftermath, OperationRegistryScript), "exactly match reachable outcomes"):
		failures.append("Sequence schema accepted aftermath keys that do not match terminal outcomes.")
	var duplicate_effect := _fixture_definition()
	duplicate_effect["sequence"]["aftermath"]["refused"] = duplicate_effect["sequence"]["aftermath"]["repaired"].duplicate(true)
	if not _contains_text(SequenceSchemaScript.validate_definition(duplicate_effect, OperationRegistryScript), "duplicates the normalized material effect"):
		failures.append("Sequence schema accepted duplicate normalized aftermath effects.")
	var unknown_key := _fixture_definition()
	unknown_key["sequence"]["phase_graph"]["phases"][0]["mystery"] = true
	if not _contains_text(SequenceSchemaScript.validate_definition(unknown_key, OperationRegistryScript), "unknown key"):
		failures.append("Sequence schema accepted an unknown phase key.")
	var nonterminal_outcome := _fixture_definition()
	nonterminal_outcome["sequence"]["phase_graph"]["phases"][0]["branches"] = [{"id": "early", "condition": {"type": "always"}, "outcome": "repaired"}]
	if not _contains_text(SequenceSchemaScript.validate_definition(nonterminal_outcome, OperationRegistryScript), "non-terminal phase"):
		failures.append("Sequence schema accepted an outcome edge from a non-terminal phase.")
	var unknown_objective := _fixture_definition()
	unknown_objective["sequence"]["phase_graph"]["phases"][0]["objective_ids"] = ["missing_objective"]
	if not _contains_text(SequenceSchemaScript.validate_definition(unknown_objective, OperationRegistryScript), "unknown objective"):
		failures.append("Sequence schema accepted an unknown objective reference.")
	var unknown_local := _fixture_definition()
	unknown_local["sequence"]["phase_graph"]["phases"][0]["entry_conditions"] = [{"type": "local_equals", "key": "missing_local", "value": true}]
	if not _contains_text(SequenceSchemaScript.validate_definition(unknown_local, OperationRegistryScript), "unknown local state"):
		failures.append("Sequence schema accepted an unknown local-state reference.")
	var unsubscribed_fact := _fixture_definition()
	unsubscribed_fact["sequence"]["fact_subscriptions"].erase("heat_changed")
	if not _contains_text(SequenceSchemaScript.validate_definition(unsubscribed_fact, OperationRegistryScript), "unsubscribed fact"):
		failures.append("Sequence schema accepted a branch referencing an unsubscribed fact.")
	var unknown_receipt := _fixture_definition()
	unknown_receipt["sequence"]["phase_graph"]["phases"][0]["entry_conditions"] = [{"type": "receipt", "receipt_kind": "operation", "family": "scene_ops", "boundary_id": "scenario:node:phase:arrival", "receipt_id": "unknown_receipt"}]
	if not _contains_text(SequenceSchemaScript.validate_definition(unknown_receipt, OperationRegistryScript), "unknown authored receipt"):
		failures.append("Sequence schema accepted an unknown receipt reference.")
	var unknown_outcome := _fixture_definition()
	unknown_outcome["sequence"]["phase_graph"]["phases"][0]["entry_conditions"] = [{"type": "outcome", "outcome": "invented"}]
	if not _contains_text(SequenceSchemaScript.validate_definition(unknown_outcome, OperationRegistryScript), "unknown outcome"):
		failures.append("Sequence schema accepted an unknown outcome reference.")
	var oversized := _fixture_definition()
	for index in range(SequenceSchemaScript.MAX_OPERATIONS_PER_FAMILY + 1):
		oversized["sequence"]["phase_graph"]["phases"][0]["scene_ops"].append(_operation_fixture("scene_ops", "set_state", 1000 + index))
	if not _contains_text(SequenceSchemaScript.validate_definition(oversized, OperationRegistryScript), "exceeds 32 operations"):
		failures.append("Sequence schema accepted an oversized operation family.")
	var deeply_nested := _fixture_definition()
	var nested: Dictionary = {"leaf": true}
	for _index in range(SequenceSchemaScript.MAX_DATA_DEPTH + 2):
		nested = {"nested": nested}
	deeply_nested["sequence"]["owner_exceptions"] = [nested]
	if not _contains_text(SequenceSchemaScript.validate_definition(deeply_nested, OperationRegistryScript), "nesting depth"):
		failures.append("Sequence schema accepted data beyond its nesting-depth bound.")
	var bad_stage := _operation_fixture("transition_ops", "stage", 99)
	bad_stage["duration_boundaries"] = 9
	bad_stage.erase("reduced_motion_message")
	if OperationRegistryScript.validate_operation("transition_ops", bad_stage).is_empty():
		failures.append("Scenario transition stage accepted an unbounded inaccessible payload.")
	var cyclic: Dictionary = {}
	cyclic["cycle"] = cyclic
	if not _contains_text(OperationRegistryScript.validate_bounded_variant("hostile cycle", cyclic), "cycle"):
		failures.append("Scenario Variant validation did not reject a recursive container cycle.")
	var blocked_initial := _runtime_definition()
	blocked_initial["sequence"]["phase_graph"]["phases"][0]["entry_conditions"] = [{"type": "local_min", "key": "pressure", "value": 1}]
	blocked_initial["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(blocked_initial)
	var blocked_state := SequenceRuntimeScript.initial_state(blocked_initial, "bar_node", "blocked_seed")
	if str(blocked_state.get("status", "")) != SequenceRuntimeScript.STATUS_CLEANED or not _contains_text(_array(blocked_state.get("errors", [])), "entry conditions"):
		failures.append("Failed initial entry conditions silently produced an active partial sequence.")


static func _check_lifecycle_commands(failures: Array) -> void:
	var definition := _runtime_definition()
	var errors := SequenceSchemaScript.validate_definition(definition, OperationRegistryScript)
	if not errors.is_empty():
		failures.append("Runtime sequence fixture failed schema validation: %s" % JSON.stringify(errors))
		return
	var initial := SequenceRuntimeScript.initial_state(definition, "bar_node", "fixture_seed")
	if str(initial.get("phase_id", "")) != "arrival" or int(_dict(initial.get("performance_counters", {})).get("transitions_prepared", 0)) != 1:
		failures.append("Sequence initial phase was not prepared exactly once.")
	var initial_round_trip := SequenceRuntimeScript.normalize_state(initial, definition)
	if JSON.stringify(initial_round_trip) != JSON.stringify(initial):
		failures.append("Sequence normalization changed a valid initial snapshot.")

	var prepare := SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "command:prepare:1", {"handler": "request_cleanup", "cost": 999}, "scenario", "command_console")
	var applied := SequenceRuntimeScript.apply_command(initial, definition, prepare, {"available_funds": 2})
	if not bool(applied.get("ok", false)) or int(_dict(_dict(applied.get("state", {})).get("local_state", {})).get("pressure", 0)) != 1:
		failures.append("Authoritative sequence command did not apply its authored handler/cost: %s" % JSON.stringify(applied.get("errors", [])))
		return
	var applied_state := _dict(applied.get("state", {}))
	if str(applied_state.get("status", "")) != SequenceRuntimeScript.STATUS_ACTIVE:
		failures.append("Caller-supplied command handler was trusted over the authored action handler.")
	var replay := SequenceRuntimeScript.apply_command(applied_state, definition, prepare, {"available_funds": 0})
	if not bool(replay.get("ok", false)) or not bool(replay.get("replayed", false)) or JSON.stringify(replay.get("state", {})) != JSON.stringify(applied_state) or int(_dict(applied_state.get("performance_counters", {})).get("commands_applied", 0)) != 1:
		failures.append("Sequence command replay was not exactly idempotent.")
	var key_collision := prepare.duplicate(true)
	key_collision["command_id"] = "finish"
	if not _contains_text(_array(SequenceRuntimeScript.apply_command(applied_state, definition, key_collision, {"available_funds": 9}).get("errors", [])), "reused"):
		failures.append("Sequence command accepted one idempotency key for a different command.")

	var hostile_commands := [
		["wrong node", SequenceRuntimeScript.command("prepare", "other_node", "arrival", "bad:node", {}, "scenario", "command_console")],
		["stale", SequenceRuntimeScript.command("prepare", "bar_node", "later", "bad:phase", {}, "scenario", "command_console")],
		["identity", SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "bad:owner", {}, "intruder", "command_console")],
		["absent interaction", SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "bad:absent", {}, "scenario", "absent_console")],
		["unavailable", SequenceRuntimeScript.command("invented", "bar_node", "arrival", "bad:action", {}, "scenario", "command_console")],
	]
	var missing_key := SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "", {}, "scenario", "command_console")
	hostile_commands.append(["idempotency_key", missing_key])
	for fixture_value in hostile_commands:
		var fixture := fixture_value as Array
		var rejected := SequenceRuntimeScript.apply_command(initial, definition, fixture[1] as Dictionary, {"available_funds": 10})
		if bool(rejected.get("ok", true)) or not _contains_text(_array(rejected.get("errors", [])), str(fixture[0])):
			failures.append("Sequence command hostile case was not rejected for %s." % str(fixture[0]))
	var unaffordable := SequenceRuntimeScript.apply_command(initial, definition, prepare, {"available_funds": 1})
	if bool(unaffordable.get("ok", true)) or not _contains_text(_array(unaffordable.get("errors", [])), "not payable"):
		failures.append("Sequence command trusted caller cost or skipped authored affordability.")
	var finish_too_soon := SequenceRuntimeScript.command("finish", "bar_node", "arrival", "command:finish:early", {}, "scenario", "command_console")
	if bool(SequenceRuntimeScript.apply_command(initial, definition, finish_too_soon, {"available_funds": 10}).get("ok", true)):
		failures.append("Sequence command skipped an authored objective precondition.")
	var finish := SequenceRuntimeScript.command("finish", "bar_node", "arrival", "command:finish:1", {}, "scenario", "command_console")
	var finished := SequenceRuntimeScript.apply_command(applied_state, definition, finish, {"available_funds": 10})
	if not bool(finished.get("ok", false)) or str(_dict(finished.get("state", {})).get("phase_id", "")) != "aftermath":
		failures.append("Explicit command branch did not enter the authored next phase.")


static func _check_serialized_fact_ingress(failures: Array) -> void:
	var definition := _runtime_definition()
	var initial := SequenceRuntimeScript.initial_state(definition, "bar_node", "fixture_seed")
	var event_fact := SequenceRuntimeScript.fact("event_result", "event", "bar_node", "event:1", 7, 2, _fact_payload("event_result"))
	var event_queued := SequenceRuntimeScript.enqueue_fact(initial, definition, event_fact)
	if not bool(event_queued.get("ok", false)):
		failures.append("Valid event fact was rejected: %s" % JSON.stringify(event_queued.get("errors", [])))
		return
	var queued_state := _dict(event_queued.get("state", {}))
	for stable_key in ["phase_id", "status", "local_state", "objective_progress", "semantic_state", "resolved_branches", "resolved_outcomes"]:
		if JSON.stringify(queued_state.get(stable_key)) != JSON.stringify(initial.get(stable_key)):
			failures.append("Fact ingress mutated sequence state before a safe flush (%s)." % stable_key)
	var duplicate := SequenceRuntimeScript.enqueue_fact(queued_state, definition, event_fact)
	if not bool(duplicate.get("ok", false)) or not bool(duplicate.get("duplicate", false)) or JSON.stringify(duplicate.get("state", {})) != JSON.stringify(queued_state):
		failures.append("Queued fact replay was not idempotent.")
	var conflicting_fact := event_fact.duplicate(true)
	conflicting_fact["payload"]["resolved"] = true
	if not _contains_text(_array(SequenceRuntimeScript.enqueue_fact(queued_state, definition, conflicting_fact).get("errors", [])), "reused"):
		failures.append("Fact ingress accepted one fact_id for different payloads.")
	var event_flushed := SequenceRuntimeScript.flush_facts(queued_state, definition, 2)
	if not bool(event_flushed.get("ok", false)) or str(_dict(event_flushed.get("state", {})).get("phase_id", "")) != "arrival":
		failures.append("An ordinary event resolution incorrectly resolved the scenario graph.")

	var facts := [
		["sweep_changed", "sweep", "sweep:1"],
		["world_boundary", "scenario", "scenario:1"],
		["town_transition", "town", "town:1"],
		["heat_changed", "heat", "heat:1"],
		["crew_changed", "crew", "crew:1"],
		["travel_arrived", "travel", "travel:1"],
		["service_result", "service", "service:1"],
		["event_result", "event", "event:2"],
		["game_result", "game", "game:1"],
	]
	var ordered_state := initial
	for fact_fixture_value in facts:
		var fact_fixture := fact_fixture_value as Array
		var typed_fact := SequenceRuntimeScript.fact(str(fact_fixture[0]), str(fact_fixture[1]), "bar_node", str(fact_fixture[2]), 1, 3, _fact_payload(str(fact_fixture[0])))
		var enqueued := SequenceRuntimeScript.enqueue_fact(ordered_state, definition, typed_fact)
		if not bool(enqueued.get("ok", false)):
			failures.append("Valid %s fact was rejected: %s" % [str(fact_fixture[0]), JSON.stringify(enqueued.get("errors", []))])
			return
		ordered_state = _dict(enqueued.get("state", {}))
	var deterministic_copy := ordered_state.duplicate(true)
	var ordered := SequenceRuntimeScript.flush_facts(ordered_state, definition, 3)
	var ordered_copy := SequenceRuntimeScript.flush_facts(deterministic_copy, definition, 3)
	var expected_order := ["game:1", "event:2", "service:1", "travel:1", "crew:1", "heat:1", "town:1", "sweep:1", "scenario:1"]
	if _array(ordered.get("processed", [])) != expected_order or JSON.stringify(ordered.get("state", {})) != JSON.stringify(ordered_copy.get("state", {})):
		failures.append("Fact flush order/state is not canonical and deterministic: %s" % JSON.stringify(ordered.get("processed", [])))

	var future := SequenceRuntimeScript.fact("game_result", "game", "bar_node", "game:future", 9, 9, _fact_payload("game_result"))
	var future_state := _dict(SequenceRuntimeScript.enqueue_fact(initial, definition, future).get("state", {}))
	var early_flush := SequenceRuntimeScript.flush_facts(future_state, definition, 8)
	if not _array(early_flush.get("processed", [])).is_empty() or _array(_dict(early_flush.get("state", {})).get("fact_queue", [])).size() != 1:
		failures.append("A future-boundary scenario fact flushed early.")

	var malformed := [
		SequenceRuntimeScript.fact("game_result", "event", "bar_node", "bad:producer", 1, 1, _fact_payload("game_result")),
		SequenceRuntimeScript.fact("invented", "event", "bar_node", "bad:type", 1, 1, {}),
		SequenceRuntimeScript.fact("event_result", "event", "wrong_node", "bad:node", 1, 1, _fact_payload("event_result")),
		SequenceRuntimeScript.fact("event_result", "event", "bar_node", "bad:payload", 1, 1, {}),
	]
	malformed[1]["schema_version"] = 99
	for invalid_value in malformed:
		if bool(SequenceRuntimeScript.enqueue_fact(initial, definition, invalid_value as Dictionary).get("ok", true)):
			failures.append("Malformed scenario fact was accepted: %s" % JSON.stringify(invalid_value))

	var prepared := SequenceRuntimeScript.apply_command(initial, definition, SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "terminal:prepare", {}, "scenario", "command_console"), {"available_funds": 2})
	var terminal := SequenceRuntimeScript.apply_command(_dict(prepared.get("state", {})), definition, SequenceRuntimeScript.command("finish", "bar_node", "arrival", "terminal:finish", {}, "scenario", "command_console"), {"available_funds": 4})
	var terminal_fact := SequenceRuntimeScript.fact("world_boundary", "scenario", "bar_node", "terminal:boundary", 1, 4, _fact_payload("world_boundary"))
	var terminal_queued := SequenceRuntimeScript.enqueue_fact(_dict(terminal.get("state", {})), definition, terminal_fact)
	var aftermath := SequenceRuntimeScript.flush_facts(_dict(terminal_queued.get("state", {})), definition, 4)
	if str(_dict(aftermath.get("state", {})).get("status", "")) != SequenceRuntimeScript.STATUS_AFTERMATH:
		failures.append("Terminal branch did not produce persistent aftermath status.")
	elif bool(SequenceRuntimeScript.enqueue_fact(_dict(aftermath.get("state", {})), definition, SequenceRuntimeScript.fact("world_boundary", "scenario", "bar_node", "post:cleanup", 2, 5, _fact_payload("world_boundary"))).get("ok", true)):
		failures.append("Scenario fact ingress remained open after terminal cleanup/aftermath.")


static func _check_handler_reducer_contracts(failures: Array) -> void:
	var definition := _runtime_definition()
	var fixtures := {
		"set_local": {"key": "pressure", "value": 2},
		"increment_local": {"key": "pressure", "amount": 1},
		"complete_objective_step": {"objective_id": "clear_exit", "step_id": "move_chair"},
		"record_outcome": {"outcome": "repaired"},
		"publish_feedback": {"message": "Readable feedback."},
		"request_cleanup": {"reason": "handler"},
		"event_bridge": {"event_id": "fixture_event", "resolution_id": "leave"},
	}
	var contracts := OperationRegistryScript.registered_handlers()
	for handler_id_value in fixtures.keys():
		var handler_id := str(handler_id_value)
		var before := SequenceRuntimeScript.initial_state(definition, "bar_node", "handler_seed")
		var response := SequenceRuntimeScript._run_handler(before, definition, handler_id, _dict(fixtures.get(handler_id, {})), {})
		if not bool(response.get("ok", false)):
			failures.append("Registered handler %s failed its golden reducer fixture." % handler_id)
			continue
		var after := _dict(response.get("state", {}))
		var changed_keys: Array = []
		for key_value in after.keys():
			var key := str(key_value)
			if JSON.stringify(after.get(key)) != JSON.stringify(before.get(key)):
				changed_keys.append(key)
		changed_keys.sort()
		var declared_outputs := _array(_dict(contracts.get(handler_id, {})).get("outputs", []))
		declared_outputs.sort()
		if changed_keys != declared_outputs:
			failures.append("Registered handler %s changed %s but declares outputs %s." % [handler_id, JSON.stringify(changed_keys), JSON.stringify(declared_outputs)])


static func _check_sequence_persistence_seam(failures: Array) -> void:
	var definition := _runtime_definition()
	var sequence_state := SequenceRuntimeScript.initial_state(definition, "bar_node", "fixture_seed")
	var source := {"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node", "scenario_sequence_state": sequence_state, "scenario_sequence_projection": SequenceRuntimeScript.public_projection(sequence_state, definition)}
	var restored := EnvironmentInstanceScript.from_dict(source).to_dict()
	if JSON.stringify(restored.get("scenario_sequence_state", {})) != JSON.stringify(sequence_state) or JSON.stringify(restored.get("scenario_sequence_projection", {})) != JSON.stringify(source.get("scenario_sequence_projection", {})):
		failures.append("Environment snapshot round-trip dropped dynamic sequence state/projection.")
	var plain := EnvironmentInstanceScript.from_dict({"id": "plain", "archetype_id": "bar", "world_node_id": "bar_node"}).to_dict()
	if plain.has("scenario_sequence_state") or plain.has("scenario_sequence_projection"):
		failures.append("No-sequence environment gained dynamic sequence persistence fields.")


static func _check_atomic_runtime_failures(failures: Array) -> void:
	var definition := _runtime_definition()
	var initial := SequenceRuntimeScript.initial_state(definition, "bar_node", "atomic_seed")
	var prepared := SequenceRuntimeScript.apply_command(initial, definition, SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "atomic:prepare", {}, "scenario", "command_console"), {"available_funds": 2})
	var prepared_state := _dict(prepared.get("state", {}))
	var bad_phase := definition.duplicate(true)
	bad_phase["sequence"]["phase_graph"]["phases"][1]["scene_ops"] = [_operation_fixture("scene_ops", "set_state", 9999)]
	var before_phase := JSON.stringify(prepared_state)
	var failed_phase := SequenceRuntimeScript.apply_command(prepared_state, bad_phase, SequenceRuntimeScript.command("finish", "bar_node", "arrival", "atomic:finish", {}, "scenario", "command_console"), {"available_funds": 4})
	if bool(failed_phase.get("ok", true)) or JSON.stringify(failed_phase.get("state", {})) != before_phase:
		failures.append("Failed phase entry committed command, objective, receipt, or semantic state.")
	var blocked_entry := definition.duplicate(true)
	blocked_entry["sequence"]["phase_graph"]["phases"][1]["entry_conditions"] = [{"type": "local_min", "key": "pressure", "value": 5}]
	var failed_entry := SequenceRuntimeScript.apply_command(prepared_state, blocked_entry, SequenceRuntimeScript.command("finish", "bar_node", "arrival", "atomic:entry", {}, "scenario", "command_console"), {"available_funds": 4})
	if bool(failed_entry.get("ok", true)) or JSON.stringify(failed_entry.get("state", {})) != before_phase:
		failures.append("Phase entry conditions were not executed atomically.")
	var receipt_entry := definition.duplicate(true)
	receipt_entry["sequence"]["phase_graph"]["phases"][1]["entry_conditions"] = [{"type": "receipt", "receipt_kind": "operation", "family": "scene_ops", "boundary_id": "sequence_fixture:bar_node:phase:arrival:initial", "receipt_id": "scene_spawn_100"}]
	receipt_entry["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(receipt_entry)
	var receipt_initial := SequenceRuntimeScript.initial_state(receipt_entry, "bar_node", "receipt_entry_seed")
	var receipt_prepared := SequenceRuntimeScript.apply_command(receipt_initial, receipt_entry, SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "receipt:prepare", {}, "scenario", "command_console"), {"available_funds": 2})
	var receipt_finished := SequenceRuntimeScript.apply_command(_dict(receipt_prepared.get("state", {})), receipt_entry, SequenceRuntimeScript.command("finish", "bar_node", "arrival", "receipt:finish", {}, "scenario", "command_console"), {"available_funds": 4})
	if not bool(receipt_finished.get("ok", false)) or str(_dict(receipt_finished.get("state", {})).get("phase_id", "")) != "aftermath":
		failures.append("Typed operation receipt condition did not match its exact family/boundary/authored id record.")
	var bad_cleanup := definition.duplicate(true)
	bad_cleanup["sequence"]["expiry"]["policy"] = "cleanup"
	bad_cleanup["sequence"]["cleanup"]["operations"].append(_operation_fixture("scene_ops", "set_state", 9999))
	var failed_expiry := SequenceRuntimeScript.apply_expiry_boundary(initial, bad_cleanup, "night_end")
	if bool(failed_expiry.get("ok", true)) or JSON.stringify(failed_expiry.get("state", {})) != JSON.stringify(initial):
		failures.append("Failed expiry cleanup committed partial state or a cleanup receipt.")
	var bad_fact := bad_cleanup.duplicate(true)
	bad_fact["sequence"]["fact_subscriptions"] = [{"fact_type": "event_result", "handler": "request_cleanup", "inputs": {"reason": "fact"}}]
	var queued := SequenceRuntimeScript.enqueue_fact(initial, bad_fact, SequenceRuntimeScript.fact("event_result", "event", "bar_node", "atomic:fact", 1, 1, _fact_payload("event_result")))
	var queued_state := _dict(queued.get("state", {}))
	var failed_flush := SequenceRuntimeScript.flush_facts(queued_state, bad_fact, 1)
	if bool(failed_flush.get("ok", true)) or JSON.stringify(failed_flush.get("state", {})) != JSON.stringify(queued_state) or not _array(failed_flush.get("processed", [])).is_empty():
		failures.append("Failed fact batch dropped a fact or committed a partial receipt/state change.")
	var visit := SequenceRuntimeScript.record_visit(initial, definition, "visit_1")
	var visit_replay := SequenceRuntimeScript.record_visit(_dict(visit.get("state", {})), definition, "visit_1")
	if not bool(visit.get("ok", false)) or not bool(visit_replay.get("replayed", false)):
		failures.append("Scenario visit receipt is not stable and replay-safe.")
	var reentered := SequenceRuntimeScript.apply_reentry(initial, definition, "visit_2")
	if not bool(reentered.get("ok", false)) or str(reentered.get("policy", "")) != "resume" or _array(_dict(reentered.get("state", {})).get("visit_receipts", [])).size() != 1:
		failures.append("Scenario partial reentry policy did not execute with a durable visit receipt.")
	var expired := SequenceRuntimeScript.apply_expiry_boundary(initial, definition, "night_end")
	if not bool(expired.get("ok", false)) or not bool(_dict(expired.get("state", {})).get("expired", false)) or str(_dict(_dict(_dict(expired.get("state", {})).get("objective_progress", {})).get("clear_exit", {})).get("outcome", "")) != "ignore":
		failures.append("Scenario expiry policy did not persist its objective outcome.")


static func _check_authoritative_receipt_capacity(failures: Array) -> void:
	var definition := _runtime_definition()
	var state := SequenceRuntimeScript.initial_state(definition, "bar_node", "receipt_seed")
	var first_command := SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "capacity:command:0", {}, "scenario", "command_console")
	for index in range(SequenceRuntimeScript.MAX_RECEIPTS):
		var command := first_command if index == 0 else SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "capacity:command:%d" % index, {}, "scenario", "command_console")
		var applied := SequenceRuntimeScript.apply_command(state, definition, command, {"available_funds": 2})
		if not bool(applied.get("ok", false)):
			failures.append("Authoritative command receipt capacity failed before its declared limit at %d." % index)
			return
		state = _dict(applied.get("state", {}))
	var overflow := SequenceRuntimeScript.apply_command(state, definition, SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "capacity:command:overflow", {}, "scenario", "command_console"), {"available_funds": 2})
	if bool(overflow.get("ok", true)) or not _contains_text(_array(overflow.get("errors", [])), "lifetime receipt limit"):
		failures.append("Sequence command lifetime did not fail closed at receipt capacity.")
	var old_replay := SequenceRuntimeScript.apply_command(state, definition, first_command, {"available_funds": 0})
	if not bool(old_replay.get("ok", false)) or not bool(old_replay.get("replayed", false)):
		failures.append("Old command receipt became replayable after reaching capacity.")

	var fact_state := SequenceRuntimeScript.initial_state(definition, "bar_node", "fact_receipt_seed")
	var first_fact := SequenceRuntimeScript.fact("event_result", "event", "bar_node", "capacity:fact:0", 0, 1, _fact_payload("event_result"))
	for index in range(SequenceRuntimeScript.MAX_RECEIPTS):
		var typed_fact := first_fact if index == 0 else SequenceRuntimeScript.fact("event_result", "event", "bar_node", "capacity:fact:%d" % index, index, 1, _fact_payload("event_result"))
		var queued := SequenceRuntimeScript.enqueue_fact(fact_state, definition, typed_fact)
		if not bool(queued.get("ok", false)):
			failures.append("Authoritative fact receipt capacity failed before its declared limit at %d." % index)
			return
		var flushed := SequenceRuntimeScript.flush_facts(_dict(queued.get("state", {})), definition, 1)
		fact_state = _dict(flushed.get("state", {}))
	var fact_overflow := SequenceRuntimeScript.enqueue_fact(fact_state, definition, SequenceRuntimeScript.fact("event_result", "event", "bar_node", "capacity:fact:overflow", 999, 1, _fact_payload("event_result")))
	if bool(fact_overflow.get("ok", true)) or not _contains_text(_array(fact_overflow.get("errors", [])), "lifetime receipt limit"):
		failures.append("Sequence fact lifetime did not fail closed at receipt capacity.")
	var old_fact_replay := SequenceRuntimeScript.enqueue_fact(fact_state, definition, first_fact)
	if not bool(old_fact_replay.get("ok", false)) or not bool(old_fact_replay.get("duplicate", false)):
		failures.append("Old fact receipt became replayable after reaching capacity.")

	var semantic: Dictionary = {"declared_targets": {"scene_objects": ["scenario::fixture_700"]}}
	var first_operation := _operation_fixture("scene_ops", "set_state", 700)
	for index in range(SequenceRuntimeScript.MAX_RECEIPTS + 16):
		var operation := first_operation.duplicate(true)
		if index > 0:
			operation["receipt_id"] = "capacity_operation_%d" % index
		var applied_ops := OperationRegistryScript.apply_operations(semantic, "scene_ops", [operation], "capacity:node:phase:%d" % index)
		semantic = _dict(applied_ops.get("state", {}))
	var operation_replay := OperationRegistryScript.apply_operations(semantic, "scene_ops", [first_operation], "capacity:node:phase:0")
	if not bool(operation_replay.get("ok", false)) or not _array(operation_replay.get("applied", [])).is_empty() or JSON.stringify(operation_replay.get("state", {})) != JSON.stringify(semantic):
		failures.append("Old transition/operation receipt was evicted after presentation capacity.")
	var full_receipts: Array = []
	for index in range(OperationRegistryScript.MAX_OPERATION_RECEIPTS):
		full_receipts.append("op_capacity_%d" % index)
	var full_state := {"declared_targets": {"scene_objects": ["scenario::fixture_700"]}, "operation_receipts": full_receipts}
	var receipt_overflow := OperationRegistryScript.apply_operations(full_state, "scene_ops", [first_operation], "capacity:node:phase:new")
	if bool(receipt_overflow.get("ok", true)) or not _contains_text(_array(receipt_overflow.get("errors", [])), "receipt limit"):
		failures.append("Operation lifetime receipt capacity did not fail closed.")
	var full_queue: Array = []
	for index in range(OperationRegistryScript.MAX_TRANSITION_QUEUE):
		full_queue.append({"receipt_id": "queued_%d" % index})
	var queue_state := {"transition_queue": full_queue}
	var queue_overflow := OperationRegistryScript.apply_operations(queue_state, "transition_ops", [_operation_fixture("transition_ops", "feedback", 999)], "capacity:node:phase:queue")
	if bool(queue_overflow.get("ok", true)) or not _contains_text(_array(queue_overflow.get("errors", [])), "queue capacity") or JSON.stringify(queue_overflow.get("state", {})) != JSON.stringify(OperationRegistryScript.apply_operations(queue_state, "transition_ops", [], "capacity:node:phase:noop").get("state", {})):
		failures.append("Transition queue capacity did not preserve the unchanged semantic state.")


static func _check_host_transaction_seam(failures: Array) -> void:
	var context := HostTransactionScript.public_context("bar_node", "bar_visit_7", "night_3", "table_context_11")
	var injected := HostTransactionScript.inject_public_context({"id": "bar_001", "archetype_id": "bar"}, context)
	var restored_environment := EnvironmentInstanceScript.from_dict(_dict(injected.get("environment", {}))).to_dict()
	for key in ["world_node_id", "environment_visit_id", "night_instance_id", "context_instance_id"]:
		var context_key := "node_id" if key == "world_node_id" else key
		if str(restored_environment.get(key, "")) != str(context.get(context_key, "")):
			failures.append("Public game context did not persist %s before normalization." % key)
	var leases := {
		"scenario_main": {"owner_id": "scenario", "stream_id": "scenario", "current_state": 10, "receipts": []},
		"craps_throw_main": {"owner_id": "craps_throw", "stream_id": "craps_throw", "current_state": 20, "receipts": []},
		"craps_recovery_main": {"owner_id": "craps_recovery", "stream_id": "craps_recovery", "current_state": 30, "receipts": []},
		"poker_cards_main": {"owner_id": "poker_cards", "stream_id": "poker_cards", "current_state": 40, "receipts": []},
		"poker_policy_crew_rook": {"owner_id": "poker_policy_crew_rook", "stream_id": "poker_policy_crew_rook", "current_state": 50, "receipts": []},
		"poker_policy_crew_velvet": {"owner_id": "poker_policy_crew_velvet", "stream_id": "poker_policy_crew_velvet", "current_state": 51, "receipts": []},
		"poker_policy_crew_knuckles": {"owner_id": "poker_policy_crew_knuckles", "stream_id": "poker_policy_crew_knuckles", "current_state": 52, "receipts": []},
		"poker_policy_crew_switch": {"owner_id": "poker_policy_crew_switch", "stream_id": "poker_policy_crew_switch", "current_state": 53, "receipts": []},
		"poker_policy_crew_mags": {"owner_id": "poker_policy_crew_mags", "stream_id": "poker_policy_crew_mags", "current_state": 54, "receipts": []},
		"poker_policy_crew_bishop": {"owner_id": "poker_policy_crew_bishop", "stream_id": "poker_policy_crew_bishop", "current_state": 55, "receipts": []},
		"poker_policy_crew_lucky": {"owner_id": "poker_policy_crew_lucky", "stream_id": "poker_policy_crew_lucky", "current_state": 56, "receipts": []},
		"poker_policy_intruder": {"owner_id": "poker_policy_intruder", "stream_id": "poker_policy_intruder", "current_state": 57, "receipts": []},
	}
	var state := HostTransactionScript.initial_state({"player_bankroll": {"fund_domain": "bankroll", "balance": 100}, "grand_casino_chips": {"fund_domain": "chips", "balance": 50}}, {
		"craps_table": {"producer_id": "craps", "game_id": "craps", "active": true, "round": 0},
		"casino_craps_table": {"producer_id": "craps", "game_id": "craps", "active": true, "round": 0, "prepared_account_id": "grand_casino_chips"},
		"poker_table": {"producer_id": "poker", "game_id": "poker", "active": true, "round": 0},
	}, leases)
	var allowed := HostTransactionScript.prepared_game_context(state, context, "craps_table", "craps")
	if not bool(allowed.get("ok", false)) or _dict(allowed.get("context", {})).has("prepared_requests"):
		failures.append("Prepared game context did not use the public allowlist.")
	var allowed_leases := _array(_dict(allowed.get("context", {})).get("rng_leases", []))
	if allowed_leases.size() != 2 or str(_dict(allowed_leases[0]).get("owner_id", "")).begins_with("poker"):
		failures.append("Prepared game context exposed another producer's RNG leases.")
	var street_accounts := _dict(_dict(allowed.get("context", {})).get("accounts", {}))
	var street_prepared := _dict(_dict(allowed.get("context", {})).get("prepared_account", {}))
	if street_accounts.keys() != ["player_bankroll"] or str(street_prepared.get("account_id", "")) != "player_bankroll" or str(street_prepared.get("fund_domain", "")) != "bankroll":
		failures.append("Street Craps context did not expose exactly its prepared bankroll account.")
	var casino_allowed := HostTransactionScript.prepared_game_context(state, context, "casino_craps_table", "craps")
	var casino_accounts := _dict(_dict(casino_allowed.get("context", {})).get("accounts", {}))
	var casino_prepared := _dict(_dict(casino_allowed.get("context", {})).get("prepared_account", {}))
	if not bool(casino_allowed.get("ok", false)) or casino_accounts.keys() != ["grand_casino_chips"] or str(casino_prepared.get("fund_domain", "")) != "chips":
		failures.append("Casino Craps context did not expose exactly its prepared chip account.")
	var poker_allowed := HostTransactionScript.prepared_game_context(state, context, "poker_table", "poker")
	var poker_leases := _array(_dict(poker_allowed.get("context", {})).get("rng_leases", []))
	var poker_states: Dictionary = {}
	for lease_value in poker_leases:
		var lease := _dict(lease_value)
		poker_states[str(lease.get("current_state", ""))] = true
		if str(lease.get("owner_id", "")).begins_with("craps") or str(lease.get("owner_id", "")) == "scenario": failures.append("Poker context exposed a foreign RNG lease.")
	if not bool(poker_allowed.get("ok", false)) or poker_leases.size() != 8 or poker_states.size() != 8:
		failures.append("Poker context did not expose cards plus seven unique member-scoped policy leases.")
	var forbidden_context := HostTransactionScript.prepared_game_context(state, context, "craps_table", "craps", ["node_id", "prepared_requests"])
	if bool(forbidden_context.get("ok", true)):
		failures.append("Prepared game context exposed runtime-owned request records.")
	var replacement := {"producer_id": "craps", "game_id": "craps", "active": true, "round": 1, "point": 6}
	var command_receipt := "craps:bar_visit_7:table_context_11:roll_1"
	var fact := HostTransactionScript.game_fact("game_result", "craps", "craps", "craps_table", context, "craps:bar_visit_7:roll:1", "scenario:bar_visit_7:fact:1", 1, {"won": true, "amount": 5})
	var request := HostTransactionScript.prepared_request("sweep_interrupt_1", "interruption", "craps_table", context, HostTransactionScript.state_digest(replacement), 1, 1, 3, {"reason_id": "police_sweep"})
	var command := HostTransactionScript.game_command("craps", "craps", "craps_table", command_receipt, context, HostTransactionScript.state_digest({"producer_id": "craps", "game_id": "craps", "active": true, "round": 0}), replacement, {
		"account_ops": [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": 100, "account_after": 95, "delta": -5, "reason": "stake"}],
		"facts": [fact],
		"prepared_acknowledgements": [{"ack_id": "roll_prepared", "kind": "game_command", "message": "Roll prepared."}],
		"external_warnings": ["The table is being watched."],
		"rng_updates": [{"lease_id": "craps_throw_main", "owner_id": "craps_throw", "before_state": 20, "after_state": 21, "receipt_id": command_receipt}],
		"prepared_request": request,
	})
	var transaction := HostTransactionScript.reduce_game_command(state, command)
	if not bool(transaction.get("ok", false)):
		failures.append("Pure game-command reducer rejected a valid typed delta: %s" % JSON.stringify(transaction.get("errors", [])))
		return
	var stale_state := state.duplicate(true)
	stale_state["revision"] = 1
	var stale := HostTransactionScript.commit_game_command(stale_state, transaction)
	if bool(stale.get("ok", true)) or JSON.stringify(stale.get("state", {})) != JSON.stringify(HostTransactionScript.normalize_state(stale_state)):
		failures.append("CAS game transaction did not reject a stale revision/digest without partial state.")
	var committed := HostTransactionScript.commit_game_command(state, transaction)
	if not bool(committed.get("ok", false)):
		failures.append("Atomic game transaction failed: %s" % JSON.stringify(committed.get("errors", [])))
		return
	state = _dict(committed.get("state", {}))
	if int(_dict(_dict(state.get("accounts", {})).get("player_bankroll", {})).get("balance", 0)) != 95 or int(_dict(_dict(state.get("table_states", {})).get("craps_table", {})).get("round", 0)) != 1:
		failures.append("Atomic Craps transaction did not commit its table and prepared account together.")
	if int(_dict(_dict(state.get("rng_leases", {})).get("craps_throw_main", {})).get("current_state", 0)) != 21 or _array(state.get("fact_queue", [])).size() != 1 or str(_dict(_dict(state.get("prepared_requests", {})).get("sweep_interrupt_1", {})).get("status", "")) != "prepared":
		failures.append("Atomic game transaction dropped RNG, GameFact, or prepared-request state.")
	if _array(state.get("external_warnings", [])).size() != 1 or _array(state.get("acknowledgements", [])).size() < 2:
		failures.append("External warnings and runtime acknowledgements were not kept distinct.")
	var replay := HostTransactionScript.commit_game_command(state, transaction)
	if not bool(replay.get("ok", false)) or not bool(replay.get("replayed", false)) or JSON.stringify(replay.get("state", {})) != JSON.stringify(state):
		failures.append("Authoritative game-command receipt was not idempotent and non-evicting.")
	var divergent := state.duplicate(true)
	divergent["accounts"]["player_bankroll"]["balance"] = 999
	var divergence_command := HostTransactionScript.game_command("craps", "craps", "craps_table", "craps:bar_visit_7:table_context_11:divergence", context, HostTransactionScript.state_digest(replacement), replacement)
	if bool(HostTransactionScript.reduce_game_command(divergent, divergence_command).get("ok", true)):
		failures.append("Host transaction accepted a canonical RunState snapshot that diverged from its CAS digest.")
	var conflicting := transaction.duplicate(true)
	conflicting["fingerprint"] = "conflicting"
	if bool(HostTransactionScript.commit_game_command(state, conflicting).get("ok", true)):
		failures.append("Authoritative game-command receipt accepted conflicting content.")
	var poker_replacement := {"producer_id": "poker", "game_id": "poker", "active": true, "round": 1}
	var poker_command := HostTransactionScript.game_command("poker", "poker", "poker_table", "poker:bar_visit_7:table_context_11:hand_1", context, HostTransactionScript.state_digest({"producer_id": "poker", "game_id": "poker", "active": true, "round": 0}), poker_replacement, {
		"account_ops": [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": 95, "account_after": 98, "delta": 3, "reason": "winnings"}],
		"trust_ops": [{"subject_id": "crew_rook", "before": 0, "after": 1, "delta": 1, "reason": "clean_play"}],
		"tell_ops": [{"pattern_id": "crew_rook:dealer_nervous", "before": 0, "after": 1, "delta": 1, "reason": "observed"}],
	})
	var poker_transaction := HostTransactionScript.reduce_game_command(state, poker_command)
	var poker_committed := HostTransactionScript.commit_game_command(state, poker_transaction)
	if not bool(poker_committed.get("ok", false)):
		failures.append("Poker producer could not atomically commit its bankroll and Crew effects: %s" % JSON.stringify(poker_committed.get("errors", [])))
		return
	state = _dict(poker_committed.get("state", {}))
	if int(_dict(_dict(state.get("accounts", {})).get("player_bankroll", {})).get("balance", 0)) != 98 or int(_dict(state.get("trust", {})).get("crew_rook", 0)) != 1 or int(_dict(state.get("tells", {})).get("crew_rook:dealer_nervous", 0)) != 1 or int(_dict(_dict(state.get("table_states", {})).get("poker_table", {})).get("round", 0)) != 1:
		failures.append("Poker transaction did not atomically commit table/bankroll/trust/tell effects.")
	var craps_trust := HostTransactionScript.game_command("craps", "craps", "craps_table", "craps:bar_visit_7:table_context_11:trust", context, HostTransactionScript.state_digest(replacement), replacement, {"trust_ops": [{"subject_id": "crew_rook", "before": 1, "after": 2, "delta": 1, "reason": "hostile"}]})
	if bool(HostTransactionScript.reduce_game_command(state, craps_trust).get("ok", true)):
		failures.append("Craps producer was allowed to author Crew trust effects.")
	var poker_chips := HostTransactionScript.game_command("poker", "poker", "poker_table", "poker:bar_visit_7:table_context_11:chips", context, HostTransactionScript.state_digest(poker_replacement), poker_replacement, {"account_ops": [{"account_id": "grand_casino_chips", "fund_domain": "chips", "account_before": 50, "account_after": 51, "delta": 1, "reason": "hostile"}]})
	if bool(HostTransactionScript.reduce_game_command(state, poker_chips).get("ok", true)):
		failures.append("Poker producer was allowed to mutate casino chips with a matching before value.")
	var foreign_table := HostTransactionScript.game_command("poker", "poker", "craps_table", "poker:bar_visit_7:table_context_11:foreign_table", context, HostTransactionScript.state_digest(replacement), {"producer_id": "poker", "game_id": "poker", "active": true, "round": 2})
	if bool(HostTransactionScript.reduce_game_command(state, foreign_table).get("ok", true)):
		failures.append("Poker producer was allowed to replace a Craps-owned table.")
	var casino_replacement := {"producer_id": "craps", "game_id": "craps", "active": true, "round": 1, "prepared_account_id": "grand_casino_chips"}
	var casino_valid := HostTransactionScript.game_command("craps", "craps", "casino_craps_table", "craps:bar_visit_7:table_context_11:casino_valid", context, HostTransactionScript.state_digest({"producer_id": "craps", "game_id": "craps", "active": true, "round": 0, "prepared_account_id": "grand_casino_chips"}), casino_replacement, {"account_ops": [{"account_id": "grand_casino_chips", "fund_domain": "chips", "account_before": 50, "account_after": 49, "delta": -1, "reason": "casino_stake"}]})
	if not bool(HostTransactionScript.reduce_game_command(state, casino_valid).get("ok", false)):
		failures.append("Casino Craps could not use its prepared chip account.")
	var no_op_switch := HostTransactionScript.game_command("craps", "craps", "casino_craps_table", "craps:bar_visit_7:table_context_11:no_op_switch", context, HostTransactionScript.state_digest({"producer_id": "craps", "game_id": "craps", "active": true, "round": 0, "prepared_account_id": "grand_casino_chips"}), {"producer_id": "craps", "game_id": "craps", "active": true, "round": 1, "prepared_account_id": "player_bankroll"})
	if bool(HostTransactionScript.reduce_game_command(state, no_op_switch).get("ok", true)):
		failures.append("A no-op Craps replacement switched its future prepared account authority.")
	var after_switch_charge := HostTransactionScript.game_command("craps", "craps", "casino_craps_table", "craps:bar_visit_7:table_context_11:after_switch_charge", context, HostTransactionScript.state_digest({"producer_id": "craps", "game_id": "craps", "active": true, "round": 0, "prepared_account_id": "grand_casino_chips"}), casino_replacement, {"account_ops": [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": 98, "account_after": 97, "delta": -1, "reason": "hostile_followup"}]})
	if bool(HostTransactionScript.reduce_game_command(state, after_switch_charge).get("ok", true)):
		failures.append("Craps gained bankroll authority after a rejected no-op account switch.")
	var switched_account := HostTransactionScript.game_command("craps", "craps", "casino_craps_table", "craps:bar_visit_7:table_context_11:switch_account", context, HostTransactionScript.state_digest({"producer_id": "craps", "game_id": "craps", "active": true, "round": 0, "prepared_account_id": "grand_casino_chips"}), {"producer_id": "craps", "game_id": "craps", "active": true, "round": 1, "prepared_account_id": "player_bankroll"}, {"account_ops": [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": 98, "account_after": 97, "delta": -1, "reason": "hostile_switch"}]})
	if bool(HostTransactionScript.reduce_game_command(state, switched_account).get("ok", true)):
		failures.append("Craps replacement switched its prepared account before authorization.")
	var transaction_bypass := HostTransactionScript.reduce_game_command(state, HostTransactionScript.game_command("craps", "craps", "craps_table", "craps:bar_visit_7:table_context_11:transaction_bypass", context, HostTransactionScript.state_digest(replacement), {"producer_id": "craps", "game_id": "craps", "active": true, "round": 2}))
	if not bool(transaction_bypass.get("ok", false)):
		failures.append("Valid reducer baseline failed before transaction-path producer validation.")
		return
	transaction_bypass["trust_ops"] = [{"subject_id": "crew_rook", "before": 1, "after": 2, "delta": 1, "reason": "post_reduce_injection"}]
	transaction_bypass["fingerprint"] = HostTransactionScript._transaction_fingerprint(transaction_bypass)
	var before_bypass := JSON.stringify(state)
	var bypass_result := HostTransactionScript.commit_game_command(state, transaction_bypass)
	if bool(bypass_result.get("ok", true)) or JSON.stringify(bypass_result.get("state", {})) != before_bypass:
		failures.append("Transaction-path producer validation accepted injected Craps trust effects.")
	var partial := HostTransactionScript.reduce_game_command(state, HostTransactionScript.game_command("craps", "craps", "craps_table", "craps:bar_visit_7:table_context_11:partial", context, HostTransactionScript.state_digest(replacement), {"producer_id": "craps", "game_id": "craps", "active": true, "round": 2}, {"account_ops": [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": 98, "account_after": 97, "delta": -1, "reason": "stake"}]}))
	if not bool(partial.get("ok", false)):
		failures.append("Valid reducer baseline failed before post-reduction fingerprint tampering test.")
		return
	partial["account_ops"] = [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": 98, "account_after": -901, "delta": -999, "reason": "hostile"}]
	var before_partial := JSON.stringify(state)
	var partial_result := HostTransactionScript.commit_game_command(state, partial)
	if bool(partial_result.get("ok", true)) or JSON.stringify(partial_result.get("state", {})) != before_partial:
		failures.append("Hostile post-reduction transaction tampering changed canonical state.")
	var mixed := HostTransactionScript.game_command("craps", "craps", "craps_table", "craps:bar_visit_7:table_context_11:mixed", context, HostTransactionScript.state_digest(replacement), replacement, {"account_ops": [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": 98, "account_after": 97, "delta": -1, "reason": "bankroll"}, {"account_id": "grand_casino_chips", "fund_domain": "chips", "account_before": 50, "account_after": 51, "delta": 1, "reason": "chips"}]})
	if bool(HostTransactionScript.reduce_game_command(state, mixed).get("ok", true)):
		failures.append("Game command reducer accepted mixed account domains.")
	var wrong_lease := HostTransactionScript.game_command("poker", "poker", "poker_table", "poker:bar_visit_7:table_context_11:wrong_lease", context, HostTransactionScript.state_digest(poker_replacement), poker_replacement, {"rng_updates": [{"lease_id": "craps_throw_main", "owner_id": "craps_throw", "before_state": 21, "after_state": 22, "receipt_id": "poker:bar_visit_7:table_context_11:wrong_lease"}]})
	if bool(HostTransactionScript.reduce_game_command(state, wrong_lease).get("ok", true)):
		failures.append("Game command reducer accepted another consumer's RNG lease.")
	var missing_context := command.duplicate(true)
	missing_context["receipt_id"] = "craps:bar_visit_7:table_context_11:missing_context"
	missing_context["context"].erase("environment_visit_id")
	if bool(HostTransactionScript.reduce_game_command(state, missing_context).get("ok", true)):
		failures.append("Game command normalized before public persisted context IDs were injected.")
	var room_mutation := command.duplicate(true)
	room_mutation["receipt_id"] = "craps:bar_visit_7:table_context_11:room_mutation"
	room_mutation["room_ops"] = [{"remove": "craps_table"}]
	if bool(HostTransactionScript.reduce_game_command(state, room_mutation).get("ok", true)):
		failures.append("Game command was allowed to mutate runtime-owned room records.")
	var bad_serial_request := HostTransactionScript.prepared_request("bad_serial", "travel", "craps_table", context, HostTransactionScript.state_digest(replacement), 1, 3, 3, {"target_node_id": "motel_node"})
	var travel_command := HostTransactionScript.game_command("craps", "craps", "craps_table", "craps:bar_visit_7:table_context_11:travel", context, HostTransactionScript.state_digest(replacement), replacement)
	var hooked := HostTransactionScript.pre_travel_hook(travel_command, bad_serial_request)
	if not bool(hooked.get("ok", false)) or bool(HostTransactionScript.reduce_game_command(state, _dict(hooked.get("command", {}))).get("ok", true)):
		failures.append("Pre-travel hook bypassed the prepared-request delivery protocol.")
	var corrupt_order := state.duplicate(true)
	corrupt_order["fact_queue"][0]["commit_order"] = 0
	if bool(HostTransactionScript.flush_game_facts(corrupt_order, 1).get("ok", true)):
		failures.append("Safe-boundary GameFact flush accepted out-of-order host commit state.")
	var flushed := HostTransactionScript.flush_game_facts(state, 1)
	if not bool(flushed.get("ok", false)) or _array(flushed.get("processed", [])).size() != 1:
		failures.append("Typed GameFact did not flush once at its safe boundary.")
		return
	state = _dict(flushed.get("state", {}))
	var deferred := HostTransactionScript.respond_to_prepared_request(state, "sweep_interrupt_1", "defer", "game:bar_visit_7:sweep_interrupt_1:defer", int(state.get("revision", 0)), HostTransactionScript.state_digest(state))
	if not bool(deferred.get("ok", false)):
		failures.append("Prepared interruption could not be deferred without removing its live table.")
		return
	state = _dict(deferred.get("state", {}))
	var accepted := HostTransactionScript.respond_to_prepared_request(state, "sweep_interrupt_1", "accept", "game:bar_visit_7:sweep_interrupt_1:accept", int(state.get("revision", 0)), HostTransactionScript.state_digest(state))
	if not bool(accepted.get("ok", false)):
		failures.append("Deferred interruption could not later be accepted.")
		return
	state = _dict(accepted.get("state", {}))
	var early_runtime := HostTransactionScript.apply_prepared_request_runtime(state, "sweep_interrupt_1", "runtime:bar_visit_7:sweep_interrupt_1:early", int(state.get("revision", 0)), HostTransactionScript.state_digest(state))
	if bool(early_runtime.get("ok", true)) or not bool(_dict(_dict(state.get("table_states", {})).get("craps_table", {})).get("active", false)):
		failures.append("Interruption applied runtime state before economics/game unwind or hid the live table first.")
	var wrong_economy := HostTransactionScript.complete_prepared_request_economy(state, "sweep_interrupt_1", [{"account_id": "grand_casino_chips", "fund_domain": "chips", "account_before": 50, "account_after": 49, "delta": -1, "reason": "hostile_fee"}], "economy:bar_visit_7:sweep_interrupt_1:wrong_account", int(state.get("revision", 0)), HostTransactionScript.state_digest(state))
	if bool(wrong_economy.get("ok", true)):
		failures.append("Prepared interruption economics mutated an account outside the stored request binding.")
	var economic := HostTransactionScript.complete_prepared_request_economy(state, "sweep_interrupt_1", [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": 98, "account_after": 96, "delta": -2, "reason": "sweep_fee"}], "economy:bar_visit_7:sweep_interrupt_1:complete", int(state.get("revision", 0)), HostTransactionScript.state_digest(state))
	if not bool(economic.get("ok", false)):
		failures.append("Accepted interruption could not complete its economic receipt.")
		return
	state = _dict(economic.get("state", {}))
	var before_unwind := HostTransactionScript.apply_prepared_request_runtime(state, "sweep_interrupt_1", "runtime:bar_visit_7:sweep_interrupt_1:before_unwind", int(state.get("revision", 0)), HostTransactionScript.state_digest(state))
	if bool(before_unwind.get("ok", true)):
		failures.append("Interruption applied before the game published its unwind acknowledgement.")
	var unwound := HostTransactionScript.acknowledge_prepared_request_unwound(state, "sweep_interrupt_1", {"producer_id": "craps", "game_id": "craps", "active": false, "round": 1, "unwound": true}, "game:bar_visit_7:sweep_interrupt_1:unwound", int(state.get("revision", 0)), HostTransactionScript.state_digest(state))
	if not bool(unwound.get("ok", false)):
		failures.append("Game could not acknowledge unwind after economic completion.")
		return
	state = _dict(unwound.get("state", {}))
	var runtime_applied := HostTransactionScript.apply_prepared_request_runtime(state, "sweep_interrupt_1", "runtime:bar_visit_7:sweep_interrupt_1:applied", int(state.get("revision", 0)), HostTransactionScript.state_digest(state))
	if not bool(runtime_applied.get("ok", false)) or str(_dict(_dict(_dict(runtime_applied.get("state", {})).get("prepared_requests", {})).get("sweep_interrupt_1", {})).get("status", "")) != "applied":
		failures.append("Prepared interruption did not reach runtime-applied acknowledgement after unwind.")
	_check_run_state_host_transaction_facade(failures)


static func _check_run_state_host_transaction_facade(failures: Array) -> void:
	var run_state := RunState.new()
	run_state.start_new("HOST-FACADE-SEED")
	run_state.set_environment({"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node", "game_states": {
		"craps_table": {"producer_id": "craps", "game_id": "craps", "active": true, "round": 0},
		"poker_table": {"producer_id": "poker", "game_id": "poker", "active": true, "round": 0},
	}})
	var prepared_context := run_state.prepare_game_command_context("craps_table", "craps")
	if not bool(prepared_context.get("ok", false)):
		failures.append("Production RunState facade could not prepare public game context.")
		return
	var context := _dict(prepared_context.get("context", {}))
	for key in ["node_id", "environment_visit_id", "night_instance_id", "context_instance_id"]:
		if str(context.get(key, "")).is_empty():
			failures.append("Production RunState facade omitted persisted context key %s." % key)
	if bool(run_state.prepare_game_command_context("craps_table", "poker").get("ok", true)):
		failures.append("Production RunState facade prepared a Poker context for a Craps-owned table.")
	var owned_leases := _array(context.get("rng_leases", []))
	if owned_leases.size() != 2 or int(_dict(owned_leases[0]).get("current_state", 0)) == int(_dict(owned_leases[1]).get("current_state", 0)):
		failures.append("Production RunState facade did not derive distinct deterministic consumer RNG streams.")
		return
	var same_seed := RunState.new()
	same_seed.start_new("HOST-FACADE-SEED")
	same_seed.set_environment({"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node", "game_states": {
		"craps_table": {"producer_id": "craps", "game_id": "craps", "active": true, "round": 0},
		"poker_table": {"producer_id": "poker", "game_id": "poker", "active": true, "round": 0},
	}})
	var same_context := same_seed.prepare_game_command_context("craps_table", "craps")
	if JSON.stringify(_array(_dict(same_context.get("context", {})).get("rng_leases", []))) != JSON.stringify(owned_leases):
		failures.append("Same-seed RunState facades derived different consumer RNG leases.")
	var poker_prepared := run_state.prepare_game_command_context("poker_table", "poker")
	var poker_owned_leases := _array(_dict(poker_prepared.get("context", {})).get("rng_leases", []))
	var poker_streams: Dictionary = {}
	var poker_states: Dictionary = {}
	for lease_value in poker_owned_leases:
		var lease := _dict(lease_value)
		poker_streams[str(lease.get("stream_id", ""))] = true
		poker_states[str(lease.get("current_state", ""))] = true
		if str(lease.get("owner_id", "")).begins_with("craps") or str(lease.get("owner_id", "")) == "scenario": failures.append("Production Poker context exposed a foreign lease.")
	if not bool(poker_prepared.get("ok", false)) or poker_owned_leases.size() != 8 or poker_streams.size() != 8 or poker_states.size() != 8:
		failures.append("Production RunState did not derive cards plus seven unique member-scoped Poker leases.")
		return
	var same_poker := same_seed.prepare_game_command_context("poker_table", "poker")
	if JSON.stringify(_array(_dict(same_poker.get("context", {})).get("rng_leases", []))) != JSON.stringify(poker_owned_leases):
		failures.append("Same-seed RunState facades derived different Poker policy leases.")
	var throw_lease: Dictionary = {}
	for lease_value in owned_leases:
		if str(_dict(lease_value).get("owner_id", "")) == "craps_throw": throw_lease = _dict(lease_value)
	var recovery_before := int(_dict(_dict(run_state.scenario_host_transaction_ledger.get("rng_leases", {})).get("craps_recovery_main", {})).get("current_state", 0))
	var replacement := {"producer_id": "craps", "game_id": "craps", "active": true, "round": 1}
	var request := HostTransactionScript.prepared_request("facade_interrupt", "interruption", "craps_table", context, HostTransactionScript.state_digest(replacement), 1, 1, 3, {"reason_id": "fixture_interrupt"})
	var fact := HostTransactionScript.game_fact("game_result", "craps", "craps", "craps_table", context, "craps:facade:roll:1", "scenario:facade:fact:1", 1, {"won": false})
	var command := HostTransactionScript.game_command("craps", "craps", "craps_table", "craps:facade:command:1", context, str(context.get("table_state_digest", "")), replacement, {
		"account_ops": [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": run_state.bankroll, "account_after": run_state.bankroll - 2, "delta": -2, "reason": "facade_stake"}],
		"facts": [fact],
		"rng_updates": [{"lease_id": str(throw_lease.get("lease_id", "")), "owner_id": "craps_throw", "before_state": throw_lease.get("current_state"), "after_state": int(throw_lease.get("current_state", 0)) + 1, "receipt_id": "craps:facade:command:1"}],
		"prepared_request": request,
	})
	var transaction := run_state.reduce_game_command_transaction(command)
	var tampered_transaction := transaction.duplicate(true)
	tampered_transaction["replacement_table_state"] = {"producer_id": "craps", "game_id": "craps", "active": true, "round": 99}
	var bankroll_before_tamper := run_state.bankroll
	if bool(run_state.commit_game_command(tampered_transaction).get("ok", true)) or run_state.bankroll != bankroll_before_tamper or int(_dict(_dict(run_state.current_environment.get("game_states", {})).get("craps_table", {})).get("round", 0)) != 0:
		failures.append("Production RunState accepted a post-reduction transaction mutation.")
	var committed := run_state.commit_game_command(transaction)
	if not bool(committed.get("ok", false)) or run_state.bankroll != RunState.DEFAULT_BANKROLL - 2 or int(_dict(_dict(run_state.current_environment.get("game_states", {})).get("craps_table", {})).get("round", 0)) != 1:
		failures.append("Production RunState facade did not atomically apply canonical game effects.")
		return
	if int(_dict(_dict(run_state.scenario_host_transaction_ledger.get("rng_leases", {})).get("craps_recovery_main", {})).get("current_state", 0)) != recovery_before:
		failures.append("Craps throw commit advanced an unrelated recovery RNG lease.")
	if not bool(run_state.commit_game_command(transaction).get("replayed", false)) or run_state.bankroll != RunState.DEFAULT_BANKROLL - 2:
		failures.append("Production RunState facade replay reapplied canonical effects.")
	var flushed := run_state.flush_game_facts_at_safe_boundary(1)
	if not bool(flushed.get("ok", false)) or _array(flushed.get("processed", [])).size() != 1:
		failures.append("Production RunState facade did not flush GameFacts at a safe boundary.")
		return
	var cas := run_state.game_command_cas_snapshot()
	var accepted := run_state.respond_to_prepared_game_request("facade_interrupt", "accept", "game:facade:interrupt:accept", int(cas.get("revision", -1)), str(cas.get("state_digest", "")))
	if not bool(accepted.get("ok", false)):
		failures.append("Production RunState facade could not accept a prepared interruption.")
		return
	cas = run_state.game_command_cas_snapshot()
	var chips_before_hostile_economy := run_state.grand_casino_chips
	var hostile_economy := run_state.complete_prepared_game_request_economy("facade_interrupt", [{"account_id": "grand_casino_chips", "fund_domain": "chips", "account_before": run_state.grand_casino_chips, "account_after": run_state.grand_casino_chips + 1, "delta": 1, "reason": "hostile"}], "economy:facade:interrupt:wrong_account", int(cas.get("revision", -1)), str(cas.get("state_digest", "")))
	if bool(hostile_economy.get("ok", true)) or run_state.grand_casino_chips != chips_before_hostile_economy:
		failures.append("Production prepared request mutated an account outside its stored binding.")
	cas = run_state.game_command_cas_snapshot()
	var economic := run_state.complete_prepared_game_request_economy("facade_interrupt", [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": run_state.bankroll, "account_after": run_state.bankroll - 1, "delta": -1, "reason": "facade_fee"}], "economy:facade:interrupt:complete", int(cas.get("revision", -1)), str(cas.get("state_digest", "")))
	if not bool(economic.get("ok", false)):
		failures.append("Production RunState facade could not complete prepared economics.")
		return
	cas = run_state.game_command_cas_snapshot()
	var unwound := run_state.acknowledge_prepared_game_unwound("facade_interrupt", {"producer_id": "craps", "game_id": "craps", "active": false, "round": 1}, "game:facade:interrupt:unwound", int(cas.get("revision", -1)), str(cas.get("state_digest", "")))
	if not bool(unwound.get("ok", false)):
		failures.append("Production RunState facade could not acknowledge game unwind.")
		return
	cas = run_state.game_command_cas_snapshot()
	if not bool(run_state.apply_prepared_game_request_runtime("facade_interrupt", "runtime:facade:interrupt:applied", int(cas.get("revision", -1)), str(cas.get("state_digest", ""))).get("ok", false)):
		failures.append("Production RunState facade did not complete the runtime-applied phase.")
	var save := run_state.to_dict()
	var restored := RunState.new()
	restored.from_dict(save)
	if restored.bankroll != run_state.bankroll or JSON.stringify(restored.scenario_host_transaction_ledger) != JSON.stringify(run_state.scenario_host_transaction_ledger) or save.has("accounts") or save.has("table_states"):
		failures.append("Production RunState facade did not persist only its receipt/fact/RNG/request ledger.")
	var restored_poker := restored.prepare_game_command_context("poker_table", "poker")
	if JSON.stringify(_array(_dict(restored_poker.get("context", {})).get("rng_leases", []))) != JSON.stringify(poker_owned_leases):
		failures.append("Save/reload changed the producer-owned Poker RNG lease projection.")


static func _runtime_definition() -> Dictionary:
	var definition := _fixture_definition()
	var sequence := _dict(definition.get("sequence", {}))
	var graph := _dict(sequence.get("phase_graph", {}))
	var phases := _array(graph.get("phases", []))
	var arrival := _dict(phases[0])
	var interaction_op := _operation_fixture("interaction_ops", "add", 200)
	interaction_op["stable_object_id"] = "command_console"
	interaction_op["interaction"] = _interaction_record("scenario", "command_console", "Keep the exit clear", true)
	interaction_op["interaction"]["safe_exit"] = true
	interaction_op["interaction"]["available_actions"] = [
		{"id": "prepare", "label": "Brace the exit", "input_action": "confirm", "non_color_state": "ready", "cost": 2, "handler": "increment_local", "inputs": {"key": "pressure", "amount": 1}},
		{"id": "finish", "label": "Open the lane", "input_action": "confirm", "non_color_state": "ready", "cost": 4, "requires_objective_steps": [{"objective_id": "clear_exit", "step_id": "move_chair"}]},
	]
	arrival["interaction_ops"] = [interaction_op]
	arrival["branches"] = [{"id": "continue", "condition": {"type": "command", "command_id": "finish"}, "next_phase": "aftermath"}]
	arrival["advance_after_actions"] = 0
	phases[0] = arrival
	graph["phases"] = phases
	sequence["phase_graph"] = graph
	sequence["objectives"] = [{"id": "clear_exit", "label": "Keep the exit clear", "progress_label": "Exit lane", "steps": [{"id": "move_chair", "label": "Move the chair", "kind": "command", "command_id": "prepare"}], "outcomes": ["success", "failure", "ignore", "cancel"]}]
	sequence["fact_subscriptions"] = [{"fact_type": "heat_changed", "handler": "set_local", "inputs": {"key": "pressure", "value_from_payload": "current"}}]
	definition["sequence"] = sequence
	definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(definition)
	return definition


static func _fact_payload(fact_type: String) -> Dictionary:
	match fact_type:
		"game_result": return {"game_id": "blackjack", "action_id": "hit", "won": true, "ended": false, "bankroll_delta": 2, "chips_delta": 0, "applied_heat_delta": 0}
		"event_result": return {"event_id": "fixture_event", "choice_id": "leave", "resolved": false, "ok": true}
		"service_result": return {"kind": "service", "service_id": "fixture_service", "ok": true, "action_id": "use"}
		"travel_departed", "travel_arrived": return {"source_id": "bar_node", "target_id": "motel_node", "travel_kind": "world"}
		"crew_changed": return {"member_id": "crew_switch", "change": "trust", "value": 2}
		"crew_job_changed": return {"job_id": "job_1", "status": "active"}
		"heat_changed": return {"previous": 10, "current": 12, "applied_delta": 2, "source": "fixture"}
		"heat_band_changed": return {"previous_band": "quiet", "current_band": "caution", "current": 25, "source": "fixture"}
		"town_transition": return {"action_index": 3, "weather": "rain", "day_type": "weeknight", "happening_ids": ["roadwork"]}
		"sweep_changed": return {"action_index": 3, "node_id": "motel_node", "segment_index": 1, "active": true}
		"world_boundary": return {"amount": 1, "action_index": 3}
		"scenario_command": return {"command_id": "prepare", "receipt_id": "command:prepare:1"}
	return {}


static func _fixture_definition() -> Dictionary:
	var definition := {
		"id": "sequence_fixture",
		"archetype_id": "bar",
		"display_name": "Sequence Fixture",
		"sequence": {
			"schema_version": 2,
			"local_state_schema": {
				"pressure": {"type": "int", "default": 0, "min": 0, "max": 5},
				"protected_exit": {"type": "bool", "default": false},
				"side": {"type": "enum", "default": "none", "values": ["none", "left", "right"]},
			},
			"phase_graph": {
				"initial_phase": "arrival",
				"phases": [
					{
						"id": "arrival", "label": "Warning", "arrival_feedback": "Chairs scrape away from a forming ring.", "exit_prompt": "The front door remains readable.",
						"entry_conditions": [{"type": "always"}], "objective_ids": ["clear_exit"], "advance_after_actions": 2,
						"scene_ops": [_operation_fixture("scene_ops", "spawn", 100)],
						"interaction_ops": [_operation_fixture("interaction_ops", "add", 100)],
						"actor_ops": [_operation_fixture("actor_ops", "spawn", 100)],
						"transition_ops": [_operation_fixture("transition_ops", "feedback", 100)],
						"branches": [{"id": "continue", "condition": {"type": "command", "command_id": "protect_exit"}, "next_phase": "aftermath"}],
					},
					{
						"id": "aftermath", "label": "Cleanup", "arrival_feedback": "The lane opens again.", "exit_prompt": "Leave through the clear front door.", "terminal": true,
						"entry_conditions": [], "objective_ids": [], "advance_after_actions": 0, "scene_ops": [], "interaction_ops": [_operation_fixture("interaction_ops", "add", 201)], "actor_ops": [], "transition_ops": [],
						"branches": [
							{"id": "finish", "condition": {"type": "always"}, "outcome": "repaired"},
							{"id": "break", "condition": {"type": "fact", "fact_type": "heat_changed"}, "outcome": "broken"},
							{"id": "refuse", "condition": {"type": "command", "command_id": "refuse"}, "outcome": "refused"},
						],
					},
				],
			},
			"objectives": [{"id": "clear_exit", "label": "Keep the exit clear", "progress_label": "Exit lane", "steps": [{"id": "move_chair", "label": "Move the chair", "kind": "command", "command_id": "protect_exit"}], "outcomes": ["success", "failure", "ignore", "cancel"]}],
			"reentry_policy": {"partial": "resume", "terminal": "aftermath", "expired": "expired"},
			"expiry": {"boundary": "night_end", "after": 1, "policy": "ignore"},
			"cleanup": {"operations": [{"family": "scene_ops", "op": "remove", "receipt_id": "cleanup_fixture", "owner_namespace": "scenario", "stable_object_id": "fixture_100"}]},
			"aftermath": {
				"repaired": {"label": "Repaired", "revisit_feedback": "The chair is back in place.", "scene_ops": [_operation_fixture("scene_ops", "set_state", 101)], "route_ops": [_operation_fixture("route_ops", "open", 101)]},
				"broken": {"label": "Broken", "revisit_feedback": "A broken chair marks the fight.", "scene_ops": [_operation_fixture("scene_ops", "set_appearance", 102)], "route_ops": [_operation_fixture("route_ops", "close", 102)]},
				"refused": {"label": "Refused", "revisit_feedback": "The staff keep their distance.", "actor_ops": [_operation_fixture("actor_ops", "set_pose", 103)], "service_ops": [_operation_fixture("service_ops", "gate", 103)]},
			},
			"declared_targets": {
				"scene_objects": ["scenario::fixture_101", "scenario::fixture_102"],
				"interactions": [],
				"actors": ["scenario::fixture_103"],
				"services": ["scenario::fixture_103"],
				"games": [],
				"routes": ["scenario::fixture_101", "scenario::fixture_102"],
			},
			"mechanic_tags": ["room_route", "multi_step"],
			"sequence_signature": "",
			"owner_exceptions": [],
			"fact_subscriptions": ["event_result", "travel_departed", "heat_changed"],
		},
	}
	definition["sequence"]["phase_graph"]["phases"][0]["interaction_ops"][0]["interaction"]["safe_exit"] = true
	definition["sequence"]["phase_graph"]["phases"][1]["interaction_ops"][0]["interaction"]["safe_exit"] = true
	definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(definition)
	return definition


static func _operation_semantic_seed() -> Dictionary:
	var declared := {"scene_objects": [], "interactions": [], "actors": [], "services": [], "games": [], "routes": []}
	for index in range(10):
		declared["scene_objects"].append("scenario::fixture_%d" % index)
	for index in range(6):
		declared["actors"].append("scenario::fixture_%d" % index)
	for index in range(4):
		declared["services"].append("scenario::fixture_%d" % index)
		declared["games"].append("scenario::fixture_%d" % index)
		declared["routes"].append("scenario::fixture_%d" % index)
	for index in range(2, 6):
		declared["interactions"].append("base::fixture_target_%d" % index)
	return {
		"scene_objects": {"scenario::fixture_1": {"owner_namespace": "scenario", "stable_object_id": "fixture_1"}},
		"interactions": {"scenario::fixture_1": _interaction_record("scenario", "fixture_1", "Existing", true)},
		"actors": {"scenario::fixture_1": {"owner_namespace": "scenario", "stable_object_id": "fixture_1"}},
		"services": {"scenario::fixture_1": {"owner_namespace": "scenario", "stable_object_id": "fixture_1"}},
		"games": {"scenario::fixture_1": {"owner_namespace": "scenario", "stable_object_id": "fixture_1"}},
		"declared_targets": declared,
	}


static func _operation_fixture(family: String, op_id: String, index: int) -> Dictionary:
	var stable_id := "fixture_%d" % index
	var operation := {"family": family, "op": op_id, "receipt_id": "%s_%s_%d" % [family.trim_suffix("_ops"), op_id, index], "owner_namespace": "scenario", "stable_object_id": stable_id}
	match family:
		"scene_ops":
			if op_id in ["spawn", "replace"]:
				operation["object"] = {"label": "Fixture prop", "role": "obstacle", "anchor_id": "bar_floor_%d" % index, "bounds": {"w": 48, "h": 48}, "visible": true, "enabled": true}
			elif op_id == "move": operation["anchor_id"] = "bar_floor_%d" % (index + 1)
			elif op_id == "disable": operation["disabled_reason"] = "Blocked by the fixture."
			elif op_id == "set_state": operation["state"] = "ready"
			elif op_id == "set_appearance": operation["appearance"] = "scuffed"
		"interaction_ops":
			if op_id in ["add", "replace"]:
				operation["interaction"] = _interaction_record("scenario", stable_id, "Fixture interaction", true)
			if not ["add", "remove"].has(op_id):
				operation["mode"] = op_id
				operation["target_owner_namespace"] = "base"
				operation["target_stable_object_id"] = "fixture_target_%d" % index
			if op_id == "gate":
				operation["enabled"] = false
				operation["disabled_reason"] = "Blocked by the fixture."
			elif op_id == "retarget": operation["source_id"] = "fixture_source"
			elif op_id == "augment": operation["available_actions"] = [{"id": "fixture_action", "label": "Act", "input_action": "confirm", "non_color_state": "ready"}]
		"actor_ops":
			if op_id == "spawn":
				operation["actor"] = {"label": "Fixture actor", "actor_id": "actor_fixture", "anchor_id": "bar_actor", "behavior": "idle"}
			elif op_id == "set_position": operation["anchor_id"] = "bar_actor_%d" % index
			elif op_id == "set_route": operation["route_id"] = "bar_route"
			elif op_id == "set_pose": operation["pose"] = "brace"
			elif op_id == "set_behavior": operation["behavior"] = "watch"
		"transition_ops":
			operation["channel"] = "room"
			if op_id in ["sound", "music"]: operation["cue_id"] = "fixture_cue"
			elif op_id == "stage":
				operation["message"] = "The room changes."
				operation["stage_id"] = "fixture_stage"
				operation["duration_boundaries"] = 1
				operation["reduced_motion_message"] = "The room changes without motion."
			elif op_id == "scene_change":
				operation["message"] = "The room changes."
				operation["change_id"] = "fixture_change"
			elif op_id == "feedback": operation["message"] = "The room changes."
		"service_ops", "game_ops":
			if op_id in ["add", "replace"]:
				operation["object"] = {"id": stable_id, "label": "Fixture"}
			elif op_id == "gate":
				operation["enabled"] = false
				operation["disabled_reason"] = "Closed by the fixture."
			elif family == "game_ops" and op_id == "set_modifier": operation["modifier"] = {"tone": "tense"}
		"route_ops":
			if op_id == "close": operation["disabled_reason"] = "The fixture closes this route."
			elif op_id == "gate":
				operation["enabled"] = false
				operation["disabled_reason"] = "The fixture gates this route."
			elif op_id == "retarget": operation["source_id"] = "alternate_exit"
	return operation


static func _interaction_record(owner: String, stable_id: String, label: String, enabled: bool) -> Dictionary:
	return {
		"owner_namespace": owner,
		"stable_object_id": stable_id,
		"label": label,
		"state_label": "Available" if enabled else "Blocked",
		"prompt": "Choose an action.",
		"enabled": enabled,
		"disabled_reason": "Blocked." if not enabled else "",
		"available_actions": [{"id": "use", "label": "Use", "input_action": "confirm", "non_color_state": "ready"}] if enabled else [],
		"input_actions": ["confirm"],
		"non_color_state": "open" if enabled else "closed",
		"focus_order": 0,
		"hit_bounds": {"w": 48, "h": 48},
		"min_target_size": 44,
		"safe_exit": stable_id.contains("exit"),
	}


static func _contains_text(values: Array, needle: String) -> bool:
	for value in values:
		if str(value).contains(needle):
			return true
	return false


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
