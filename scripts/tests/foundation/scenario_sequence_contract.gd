extends RefCounted

const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const SequenceCatalogScript := preload("res://scripts/core/scenario_sequence_catalog.gd")
const SequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const SequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const ScenarioExtensionDispatchScript := preload("res://scripts/core/scenario_extension_dispatch.gd")
const ScenarioPresentationContractScript := preload("res://scripts/tests/foundation/scenario_presentation_contract.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const SaveServiceScript := preload("res://scripts/core/save_service.gd")
const DELIVERY_SCENARIO_ID := "corner_store_delivery_day"
const DELIVERY_NODE_ID := "corner_store_delivery_day_node"
const DELIVERY_EVENT_ID := "scenario_delivery_day_stock"
const DELIVERY_RESOLUTION_ID := "delivery_day_stock_resolution"


static func check(library: ContentLibrary, failures: Array) -> void:
	_check_schema(failures)
	_check_registered_operations(failures)
	_check_interaction_identity(failures)
	_check_negative_fixtures(failures)
	_check_lifecycle_commands(failures)
	_check_augment_availability(failures)
	_check_boundary_provenance(failures)
	_check_mutually_exclusive_branch_cleanup(failures)
	_check_serialized_fact_ingress(failures)
	_check_sequence_persistence_seam(failures)
	_check_lifecycle_policy_matrix(failures)
	_check_save_service_phase_matrix(failures)
	_check_authoritative_receipt_capacity(failures)
	_check_completion_evidence(failures)
	_check_extension_dispatch(failures)
	_check_definition_validation_receipt(failures)
	_check_suppressed_sequence_compatibility(failures)
	_check_transition_and_event_delivery(failures)
	_check_delivery_day_production_package(library, failures)
	_check_material_projection(failures)
	ScenarioPresentationContractScript.check(failures)


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
	if SequenceSchemaScript.initial_phase_id(definition) != "arrival" or SequenceSchemaScript.phase_ids(definition) != ["arrival", "complication", "aftermath"]:
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
	var state: Dictionary = {}
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
		if handler.is_empty() or str(handler.get("rng", "")) != "none" or not handler.has("persistent"):
			failures.append("Scenario handler %s lacks explicit input/output/persistence/RNG contract." % handler_id)


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
	var unscoped_event_fact := _fixture_definition()
	unscoped_event_fact["sequence"]["fact_subscriptions"][0] = "event_result"
	if not _contains_text(SequenceSchemaScript.validate_definition(unscoped_event_fact, OperationRegistryScript), "payload_equals.event_id"):
		failures.append("Sequence schema accepted an event-result subscription without an event-id payload predicate.")
	var unknown_event_field := _fixture_definition()
	unknown_event_field["sequence"]["fact_subscriptions"][0]["payload_equals"] = {"event_id": "fixture_event", "invented": "collision"}
	if not _contains_text(SequenceSchemaScript.validate_definition(unknown_event_field, OperationRegistryScript), "unknown event_result field"):
		failures.append("Sequence schema accepted an unregistered event-result predicate field.")
	var wrong_event_type := _fixture_definition()
	wrong_event_type["sequence"]["fact_subscriptions"][0]["payload_equals"] = {"event_id": "fixture_event", "resolved": "yes"}
	if not _contains_text(SequenceSchemaScript.validate_definition(wrong_event_type, OperationRegistryScript), "wrong type"):
		failures.append("Sequence schema accepted a wrong-type event-result predicate.")
	var invalid_happening_predicate := _fixture_definition()
	invalid_happening_predicate["sequence"]["fact_subscriptions"].append({"fact_type": "town_transition", "payload_equals": {"happening_ids": ["roadwork", "roadwork"]}})
	if not _contains_text(SequenceSchemaScript.validate_definition(invalid_happening_predicate, OperationRegistryScript), "unique stable strings"):
		failures.append("Sequence schema accepted an unreachable town-happening payload predicate.")
	var unscoped_event_branch := _fixture_definition()
	unscoped_event_branch["sequence"]["phase_graph"]["phases"][0]["branches"][0]["condition"] = {"type": "fact", "fact_type": "event_result"}
	if not _contains_text(SequenceSchemaScript.validate_definition(unscoped_event_branch, OperationRegistryScript), "payload_equals.event_id"):
		failures.append("Sequence schema accepted an event-result branch without an event-id payload predicate.")
	var empty_event_bridge := _runtime_definition()
	empty_event_bridge["sequence"]["phase_graph"]["phases"][0]["interaction_ops"][1]["interaction"]["available_actions"][0]["handler"] = "event_bridge"
	empty_event_bridge["sequence"]["phase_graph"]["phases"][0]["interaction_ops"][1]["interaction"]["available_actions"][0]["inputs"] = {"event_id": "fixture_event", "resolution_id": ""}
	if not _contains_text(SequenceSchemaScript.validate_definition(empty_event_bridge, OperationRegistryScript), "non-empty stable event_id and resolution_id"):
		failures.append("Sequence schema accepted an event bridge without a durable resolution id.")
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
	unknown_receipt["sequence"]["phase_graph"]["phases"][0]["entry_conditions"] = [{"type": "receipt", "receipt_id": "scenario:node:phase:unknown_receipt"}]
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
	var finish := SequenceRuntimeScript.command("finish", "bar_node", "complication", "command:finish:1", {}, "scenario", "command_console")
	var finished := SequenceRuntimeScript.apply_command(applied_state, definition, finish, {"available_funds": 10})
	if not bool(finished.get("ok", false)) or str(_dict(finished.get("state", {})).get("phase_id", "")) != "aftermath":
		failures.append("Explicit command branch did not enter the authored next phase.")
	else:
		_check_clean_branch_state(_dict(finished.get("state", {})), definition, "repaired", "scenario::fixture_101", failures)


static func _check_mutually_exclusive_branch_cleanup(failures: Array) -> void:
	var definition := _runtime_definition()
	var broken_state := _prepared_fixture_state(definition, "broken_seed", failures)
	var broken_fact := SequenceRuntimeScript.fact("heat_changed", "heat", "bar_node", "branch:broken", 1, 1, _fact_payload("heat_changed"))
	var broken_queued := SequenceRuntimeScript.enqueue_fact(broken_state, definition, broken_fact)
	var broken_result := SequenceRuntimeScript.flush_facts(_dict(broken_queued.get("state", {})), definition, 1)
	_check_clean_branch_state(_dict(broken_result.get("state", {})), definition, "broken", "scenario::fixture_102", failures)

	var refused_state := _prepared_fixture_state(definition, "refused_seed", failures)
	var refused_command := SequenceRuntimeScript.command("refuse", "bar_node", "complication", "branch:refused", {}, "scenario", "command_console")
	var refused_result := SequenceRuntimeScript.apply_command(refused_state, definition, refused_command, {"available_funds": 0})
	if not bool(refused_result.get("ok", false)):
		failures.append("Refused terminal branch could not be exercised: %s" % JSON.stringify(refused_result.get("errors", [])))
	else:
		_check_clean_branch_state(_dict(refused_result.get("state", {})), definition, "refused", "scenario::fixture_103", failures)


static func _check_boundary_provenance(failures: Array) -> void:
	var definition := _runtime_definition()
	var command_state := _prepared_fixture_state(definition, "command_boundary_seed", failures)
	var first_boundary := SequenceRuntimeScript.fact("world_boundary", "scenario", "bar_node", "command:boundary:1", 1, 1, {"amount": 1, "action_index": 1})
	var first_queued := SequenceRuntimeScript.enqueue_fact(command_state, definition, first_boundary)
	var first_result := SequenceRuntimeScript.flush_facts(_dict(first_queued.get("state", {})), definition, 1)
	var first_state := _dict(first_result.get("state", {}))
	if not bool(first_result.get("ok", false)) or str(first_state.get("phase_id", "")) != "complication" or int(first_state.get("phase_action_counter", -1)) != 0 or int(first_state.get("phase_boundary_grace", -1)) != 0:
		failures.append("Command-entered phase did not consume exactly its immediate turn-boundary grace.")
	var second_boundary := SequenceRuntimeScript.fact("world_boundary", "scenario", "bar_node", "command:boundary:2", 2, 2, {"amount": 1, "action_index": 2})
	var second_queued := SequenceRuntimeScript.enqueue_fact(first_state, definition, second_boundary)
	var second_result := SequenceRuntimeScript.flush_facts(_dict(second_queued.get("state", {})), definition, 2)
	if not bool(second_result.get("ok", false)) or str(_dict(second_result.get("state", {})).get("phase_id", "")) != "aftermath":
		failures.append("Command-entered phase skipped the next legitimate world boundary after grace.")

	var fact_definition := definition.duplicate(true)
	var sequence := _dict(fact_definition.get("sequence", {}))
	var graph := _dict(sequence.get("phase_graph", {}))
	var phases := _array(graph.get("phases", []))
	var arrival := _dict(phases[0])
	arrival["branches"] = [{"id": "travel_into_complication", "condition": {"type": "fact", "fact_type": "travel_arrived"}, "next_phase": "complication"}]
	phases[0] = arrival
	var complication := _dict(phases[1])
	complication["branches"] = []
	complication["advance_after_actions"] = 1
	phases[1] = complication
	graph["phases"] = phases
	sequence["phase_graph"] = graph
	fact_definition["sequence"] = sequence
	var fact_state := SequenceRuntimeScript.initial_state(fact_definition, "bar_node", "fact_boundary_seed")
	var travel_fact := SequenceRuntimeScript.fact("travel_arrived", "travel", "bar_node", "fact:travel:1", 1, 1, {"source_id": "street", "target_id": "bar_node", "travel_kind": "walk"})
	var travel_queued := SequenceRuntimeScript.enqueue_fact(fact_state, fact_definition, travel_fact)
	var travel_result := SequenceRuntimeScript.flush_facts(_dict(travel_queued.get("state", {})), fact_definition, 1)
	var arrived_state := _dict(travel_result.get("state", {}))
	if not bool(travel_result.get("ok", false)) or str(arrived_state.get("phase_id", "")) != "complication" or int(arrived_state.get("phase_boundary_grace", -1)) != 0:
		failures.append("Fact-entered phase incorrectly inherited command turn-boundary grace.")
	var fact_boundary := SequenceRuntimeScript.fact("world_boundary", "scenario", "bar_node", "fact:boundary:2", 2, 2, {"amount": 1, "action_index": 2})
	var fact_boundary_queued := SequenceRuntimeScript.enqueue_fact(arrived_state, fact_definition, fact_boundary)
	var fact_boundary_result := SequenceRuntimeScript.flush_facts(_dict(fact_boundary_queued.get("state", {})), fact_definition, 2)
	if not bool(fact_boundary_result.get("ok", false)) or str(_dict(fact_boundary_result.get("state", {})).get("phase_id", "")) != "aftermath":
		failures.append("Fact-entered phase lost its next legitimate world boundary.")


static func _check_augment_availability(failures: Array) -> void:
	var definition := _runtime_definition()
	var sequence := _dict(definition.get("sequence", {}))
	var graph := _dict(sequence.get("phase_graph", {}))
	var phases := _array(graph.get("phases", []))
	var arrival := _dict(phases[0])
	arrival["interaction_ops"] = _array(arrival.get("interaction_ops", [])) + [_operation_fixture("interaction_ops", "augment", 5)]
	phases[0] = arrival
	graph["phases"] = phases
	sequence["phase_graph"] = graph
	definition["sequence"] = sequence
	var state := SequenceRuntimeScript.initial_state(definition, "bar_node", "augment_seed")
	var command := SequenceRuntimeScript.command("fixture_action", "bar_node", "arrival", "augment:fixture:1", {}, "scenario", "fixture_5")
	var target_identity := "base::fixture_target_5"
	var disabled_availability: Dictionary = {}
	disabled_availability[target_identity] = false
	var disabled := SequenceRuntimeScript.apply_command(state, definition, command, {"available_funds": 0, "host_interaction_availability": disabled_availability})
	if bool(disabled.get("ok", true)) or not _contains_text(_array(disabled.get("errors", [])), "disabled"):
		failures.append("Scenario augment command bypassed an unavailable authoritative host target.")
	var enabled_availability := disabled_availability.duplicate(true)
	enabled_availability[target_identity] = true
	var enabled := SequenceRuntimeScript.apply_command(state, definition, command, {"available_funds": 0, "host_interaction_availability": enabled_availability})
	if not bool(enabled.get("ok", false)):
		failures.append("Scenario augment command could not execute against an available authoritative host target.")


static func _prepared_fixture_state(definition: Dictionary, seed_token: String, failures: Array) -> Dictionary:
	var state := SequenceRuntimeScript.initial_state(definition, "bar_node", seed_token)
	var prepare := SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "branch:prepare:%s" % seed_token, {}, "scenario", "command_console")
	var result := SequenceRuntimeScript.apply_command(state, definition, prepare, {"available_funds": 2})
	var prepared := _dict(result.get("state", {}))
	if not bool(result.get("ok", false)) or str(prepared.get("phase_id", "")) != "complication" or str(prepared.get("status", "")) != SequenceRuntimeScript.STATUS_ACTIVE:
		failures.append("Terminal branch fixture did not reach complication through the public command API: %s" % JSON.stringify(result.get("errors", [])))
	return prepared


static func _check_clean_branch_state(state: Dictionary, definition: Dictionary, outcome: String, aftermath_identity: String, failures: Array) -> void:
	if str(state.get("status", "")) != SequenceRuntimeScript.STATUS_AFTERMATH or _array(state.get("resolved_outcomes", [])) != [outcome]:
		failures.append("Mutually exclusive %s branch did not resolve to persistent aftermath." % outcome)
		return
	var semantic := _dict(state.get("semantic_state", {}))
	for collection_name in ["scene_objects", "interactions", "actors"]:
		var collection := _dict(semantic.get(collection_name, {}))
		for temporary_identity in ["scenario::fixture_100", "scenario::fixture_104", "scenario::fixture_105", "scenario::command_console"]:
			if collection.has(temporary_identity):
				failures.append("Mutually exclusive %s branch left temporary %s in %s." % [outcome, temporary_identity, collection_name])
	var material_collections := ["scene_objects", "actors", "routes", "services", "games", "interactions"]
	var expected_present := false
	for collection_name in material_collections:
		if _dict(semantic.get(collection_name, {})).has(aftermath_identity): expected_present = true
	if not expected_present:
		failures.append("Mutually exclusive %s branch lost its material aftermath identity." % outcome)
	var outcome_identities := {
		"repaired": "scenario::fixture_101",
		"broken": "scenario::fixture_102",
		"refused": "scenario::fixture_103",
	}
	for other_outcome_value in outcome_identities.keys():
		var other_outcome := str(other_outcome_value)
		if other_outcome == outcome: continue
		var other_identity := str(outcome_identities.get(other_outcome, ""))
		for collection_name in material_collections:
			if _dict(semantic.get(collection_name, {})).has(other_identity):
				failures.append("Mutually exclusive %s branch leaked %s identity into %s." % [outcome, other_outcome, collection_name])
	if _array(state.get("cleanup_receipts", [])).is_empty():
		failures.append("Mutually exclusive %s branch did not persist cleanup receipts." % outcome)
	var reentered := SequenceRuntimeScript.apply_reentry(state, definition, "terminal_%s_return" % outcome)
	var reentered_state := _dict(reentered.get("state", {}))
	if not bool(reentered.get("ok", false)) or str(reentered.get("policy", "")) != "aftermath" or str(reentered_state.get("status", "")) != SequenceRuntimeScript.STATUS_AFTERMATH:
		failures.append("Mutually exclusive %s aftermath did not survive terminal reentry." % outcome)
	elif JSON.stringify(reentered_state.get("semantic_state", {})) != JSON.stringify(state.get("semantic_state", {})) or _array(reentered_state.get("resolved_outcomes", [])) != _array(state.get("resolved_outcomes", [])):
		failures.append("Mutually exclusive %s reentry changed its exact semantic aftermath/outcome." % outcome)


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

	var expired := SequenceRuntimeScript.apply_expiry(sequence_state, definition, "night_end", 9)
	var expired_state := _dict(expired.get("state", {}))
	if not bool(expired.get("ok", false)) or not bool(expired.get("expired", false)) or str(expired_state.get("status", "")) != SequenceRuntimeScript.STATUS_CLEANED:
		failures.append("Source-room expiry did not clean the active sequence before persistence.")
		return
	var expired_snapshot := EnvironmentInstanceScript.from_dict({
		"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node",
		"scenario_sequence_state": expired_state,
		"scenario_sequence_projection": SequenceRuntimeScript.public_projection(expired_state, definition),
	}).to_dict()
	var restored_expired := _dict(expired_snapshot.get("scenario_sequence_state", {}))
	if not _array(restored_expired.get("expiry_receipts", [])).has("expiry:night_end:9") or _array(restored_expired.get("cleanup_receipts", [])).is_empty():
		failures.append("Source-room expiry/cleanup receipts were not persisted with the room snapshot.")
	var reentered := SequenceRuntimeScript.apply_reentry(restored_expired, definition, "expired_return")
	var reentered_state := _dict(reentered.get("state", {}))
	if not bool(reentered.get("ok", false)) or str(reentered.get("policy", "")) != "expired" or not _array(reentered_state.get("visit_receipts", [])).has("visit:expired_return"):
		failures.append("Expired source-room state did not apply and receipt deterministic reentry.")
	var reentry_snapshot := EnvironmentInstanceScript.from_dict({
		"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node",
		"scenario_sequence_state": reentered_state,
		"scenario_sequence_projection": SequenceRuntimeScript.public_projection(reentered_state, definition),
	}).to_dict()
	if JSON.stringify(reentry_snapshot.get("scenario_sequence_state", {})) != JSON.stringify(reentered_state):
		failures.append("Expired source-room reentry state/receipts did not survive a second persistence round-trip.")


static func _check_lifecycle_policy_matrix(failures: Array) -> void:
	var base_definition := _runtime_definition()
	var partial := _prepared_fixture_state(base_definition, "reentry_matrix_seed", failures)
	for policy_value in SequenceSchemaScript.REENTRY_POLICIES:
		var policy := str(policy_value)
		var definition := base_definition.duplicate(true)
		definition["sequence"]["reentry_policy"]["partial"] = policy
		var result := SequenceRuntimeScript.apply_reentry(partial, definition, "partial_%s" % policy)
		var next := _dict(result.get("state", {}))
		if not bool(result.get("ok", false)) or str(result.get("policy", "")) != policy or not _array(next.get("visit_receipts", [])).has("visit:partial_%s" % policy):
			failures.append("Partial reentry policy %s did not apply and receipt exactly once." % policy)
			continue
		match policy:
			"resume", "aftermath":
				var expected_feedback := str(SequenceSchemaScript.phase(definition, str(partial.get("phase_id", ""))).get("arrival_feedback", ""))
				if str(next.get("status", "")) != SequenceRuntimeScript.STATUS_ACTIVE or JSON.stringify(next.get("semantic_state", {})) != JSON.stringify(partial.get("semantic_state", {})) or str(next.get("last_feedback", "")) != expected_feedback:
					failures.append("Partial reentry policy %s changed resumable semantic state." % policy)
			"restart":
				if str(next.get("phase_id", "")) != "arrival" or not _array(next.get("command_receipts", [])).is_empty():
					failures.append("Partial restart reentry did not reset phase/command authority.")
			"expired":
				if str(next.get("status", "")) != SequenceRuntimeScript.STATUS_CLEANED or _array(next.get("cleanup_receipts", [])).is_empty():
					failures.append("Partial expired reentry did not clean temporary state.")
		var replay := SequenceRuntimeScript.apply_reentry(next, definition, "partial_%s" % policy)
		if not bool(replay.get("ok", false)) or not bool(replay.get("replayed", false)) or JSON.stringify(replay.get("state", {})) != JSON.stringify(next):
			failures.append("Reentry policy %s was not idempotent." % policy)

	for policy_value in SequenceSchemaScript.EXPIRY_POLICIES:
		var policy := str(policy_value)
		var definition := base_definition.duplicate(true)
		var lifecycle_outcomes := {"fail": "failure", "ignore": "ignore", "cancel": "cancel"}
		var lifecycle_outcome := str(lifecycle_outcomes.get(policy, ""))
		if not lifecycle_outcome.is_empty():
			definition = _definition_with_lifecycle_outcome(definition, lifecycle_outcome)
		definition["sequence"]["expiry"] = {"boundary": "town_action", "after": 2, "policy": policy}
		var definition_errors := SequenceSchemaScript.validate_definition(definition, OperationRegistryScript)
		if not definition_errors.is_empty():
			failures.append("Expiry policy %s fixture failed schema validation: %s" % [policy, JSON.stringify(definition_errors)])
			continue
		var state := SequenceRuntimeScript.initial_state(definition, "bar_node", "expiry_%s" % policy)
		var wrong_boundary := SequenceRuntimeScript.apply_expiry(state, definition, "leave", 1)
		if not bool(wrong_boundary.get("ok", false)) or bool(wrong_boundary.get("applied", true)) or JSON.stringify(wrong_boundary.get("state", {})) != JSON.stringify(state):
			failures.append("Expiry policy %s mutated state at the wrong boundary." % policy)
		var first := SequenceRuntimeScript.apply_expiry(state, definition, "town_action", 1)
		var first_state := _dict(first.get("state", {}))
		if not bool(first.get("ok", false)) or not bool(first.get("applied", false)) or bool(first.get("expired", true)) or int(_dict(first_state.get("expiry_counts", {})).get("town_action", 0)) != 1:
			failures.append("Expiry policy %s did not respect its authored threshold." % policy)
		var duplicate := SequenceRuntimeScript.apply_expiry(first_state, definition, "town_action", 1)
		if not bool(duplicate.get("replayed", false)) or JSON.stringify(duplicate.get("state", {})) != JSON.stringify(first_state):
			failures.append("Expiry policy %s duplicate boundary was not idempotent." % policy)
		var second := SequenceRuntimeScript.apply_expiry(first_state, definition, "town_action", 2)
		var second_state := _dict(second.get("state", {}))
		if not bool(second.get("ok", false)) or int(_dict(second_state.get("expiry_counts", {})).get("town_action", 0)) != 2:
			failures.append("Expiry policy %s did not apply at its threshold boundary." % policy)
		elif policy == "resume":
			if str(second_state.get("status", "")) != SequenceRuntimeScript.STATUS_ACTIVE or bool(second.get("expired", true)) or not str(_dict(_dict(second_state.get("objective_progress", {})).get("clear_exit", {})).get("outcome", "")).is_empty():
				failures.append("Resume expiry policy incorrectly terminated active state.")
		elif policy == "cleanup":
			if str(second_state.get("status", "")) != SequenceRuntimeScript.STATUS_CLEANED or not bool(second.get("expired", false)) or _array(second_state.get("cleanup_receipts", [])).is_empty() or not str(_dict(_dict(second_state.get("objective_progress", {})).get("clear_exit", {})).get("outcome", "")).is_empty():
				failures.append("Cleanup expiry policy did not clean state without inventing an objective outcome.")
		elif str(second_state.get("status", "")) != SequenceRuntimeScript.STATUS_AFTERMATH \
			or _array(second_state.get("resolved_outcomes", [])) != [lifecycle_outcome] \
			or str(_dict(_dict(second_state.get("objective_progress", {})).get("clear_exit", {})).get("outcome", "")) != lifecycle_outcome \
			or not _dict(_dict(second_state.get("semantic_state", {})).get("scene_objects", {})).has("scenario::fixture_101"):
			failures.append("Expiry policy %s did not materialize its distinct %s objective/aftermath outcome." % [policy, lifecycle_outcome])


static func _definition_with_lifecycle_outcome(definition: Dictionary, lifecycle_outcome: String) -> Dictionary:
	var result := definition.duplicate(true)
	var sequence := _dict(result.get("sequence", {}))
	var graph := _dict(sequence.get("phase_graph", {}))
	var phases := _array(graph.get("phases", []))
	var terminal := _dict(phases[phases.size() - 1])
	var branches := _array(terminal.get("branches", []))
	for index in range(branches.size()):
		var branch := _dict(branches[index])
		if str(branch.get("id", "")) == "finish":
			branch["outcome"] = lifecycle_outcome
			branches[index] = branch
	terminal["branches"] = branches
	phases[phases.size() - 1] = terminal
	graph["phases"] = phases
	sequence["phase_graph"] = graph
	var aftermath := _dict(sequence.get("aftermath", {}))
	var renamed := _dict(aftermath.get("repaired", {}))
	renamed["label"] = lifecycle_outcome.capitalize()
	renamed["revisit_feedback"] = "The %s lifecycle aftermath remains visible." % lifecycle_outcome
	aftermath.erase("repaired")
	aftermath[lifecycle_outcome] = renamed
	sequence["aftermath"] = aftermath
	result["sequence"] = sequence
	return result


static func _check_save_service_phase_matrix(failures: Array) -> void:
	var definition := _runtime_definition()
	var arrival := SequenceRuntimeScript.initial_state(definition, "bar_node", "save_arrival")
	var before_branch := _prepared_fixture_state(definition, "save_before_branch", failures)
	var repaired_command := SequenceRuntimeScript.command("finish", "bar_node", "complication", "save:branch:repaired", {}, "scenario", "command_console")
	var repaired := _dict(SequenceRuntimeScript.apply_command(before_branch, definition, repaired_command, {"available_funds": 10}).get("state", {}))
	var broken_fact := SequenceRuntimeScript.fact("heat_changed", "heat", "bar_node", "save:branch:broken", 1, 1, _fact_payload("heat_changed"))
	var broken_queued := SequenceRuntimeScript.enqueue_fact(before_branch, definition, broken_fact)
	var broken := _dict(SequenceRuntimeScript.flush_facts(_dict(broken_queued.get("state", {})), definition, 1).get("state", {}))
	var refused_command := SequenceRuntimeScript.command("refuse", "bar_node", "complication", "save:branch:refused", {}, "scenario", "command_console")
	var refused := _dict(SequenceRuntimeScript.apply_command(before_branch, definition, refused_command, {"available_funds": 0}).get("state", {}))
	var checkpoints := {
		"arrival": arrival,
		"before_branch": before_branch,
		"after_repaired": repaired,
		"after_broken": broken,
		"after_refused": refused,
	}
	for label_value in checkpoints.keys():
		var label := str(label_value)
		var expected := _dict(checkpoints.get(label_value, {}))
		var restored := _save_service_round_trip_state(expected, definition, label, failures)
		if restored.is_empty(): continue
		if JSON.stringify(restored) != JSON.stringify(expected):
			failures.append("SaveService changed exact scenario sequence state at %s." % label)
		match label:
			"after_repaired":
				var replay := SequenceRuntimeScript.apply_command(restored, definition, repaired_command, {"available_funds": 10})
				if not bool(replay.get("replayed", false)) or JSON.stringify(replay.get("state", {})) != JSON.stringify(restored): failures.append("Save/load duplicated repaired branch consequences.")
			"after_broken":
				var duplicate := SequenceRuntimeScript.enqueue_fact(restored, definition, broken_fact)
				if not bool(duplicate.get("duplicate", false)) or JSON.stringify(duplicate.get("state", {})) != JSON.stringify(restored): failures.append("Save/load duplicated broken branch consequences.")
			"after_refused":
				var replay := SequenceRuntimeScript.apply_command(restored, definition, refused_command, {"available_funds": 0})
				if not bool(replay.get("replayed", false)) or JSON.stringify(replay.get("state", {})) != JSON.stringify(restored): failures.append("Save/load duplicated refused branch consequences.")


static func _save_service_round_trip_state(state: Dictionary, definition: Dictionary, label: String, failures: Array, archetype_id: String = "bar", node_id: String = "bar_node") -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("ENV06-6-SAVE-%s" % label, RunState.custom_challenge("env06_6_%s" % label, "ENV06-6-SAVE-%s" % label, {"fixture": true}))
	run_state.current_environment = {
		"id": "%s_001" % archetype_id, "archetype_id": archetype_id, "world_node_id": node_id,
		"scenario_state": ScenarioEngineScript.initial_state(definition),
		"scenario_sequence_definition": definition.duplicate(true),
		"scenario_sequence_state": state.duplicate(true),
		"scenario_sequence_projection": {"hostile": true},
		"scenario_render_snapshot": {"hostile": true},
		"layout": {"object_rects": {}},
	}
	var save_service: SaveService = SaveServiceScript.new()
	var slot_id := "env06_6_sequence_%s" % label
	var clear_before := save_service.clear_run(slot_id)
	if clear_before != OK:
		failures.append("SaveService could not clear scenario fixture slot %s before use: %s." % [label, clear_before])
		return {}
	var save_error := save_service.save_run(run_state, slot_id)
	if save_error != OK:
		failures.append("SaveService scenario checkpoint %s failed to save: %s." % [label, save_error])
		save_service.clear_run(slot_id)
		return {}
	var loaded = save_service.load_run(slot_id)
	var clear_after := save_service.clear_run(slot_id)
	if clear_after != OK:
		failures.append("SaveService could not clear scenario fixture slot %s after use: %s." % [label, clear_after])
	if loaded == null:
		failures.append("SaveService scenario checkpoint %s failed to load." % label)
		return {}
	var environment := _dict((loaded as RunState).current_environment)
	if environment.has("scenario_sequence_projection") and bool(_dict(environment.get("scenario_sequence_projection", {})).get("hostile", false)) or environment.has("scenario_render_snapshot") and bool(_dict(environment.get("scenario_render_snapshot", {})).get("hostile", false)):
		failures.append("SaveService trusted stale derived scenario presentation at %s." % label)
	return _dict(environment.get("scenario_sequence_state", {}))


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

	var semantic: Dictionary = {}
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


static func _check_completion_evidence(failures: Array) -> void:
	var definition := _fixture_definition()
	var calculated := SequenceSchemaScript.calculated_completion_contract(definition)
	for row in SequenceSchemaScript.ALLOWED_EXCEPTION_ROWS:
		if not bool(calculated.get(row, false)):
			failures.append("Calculated hard-10 completion row is not evidenced: %s." % row)
	var excepted := definition.duplicate(true)
	excepted["sequence"]["completion_contract"]["semantic_changes"] = false
	excepted["sequence"]["owner_exceptions"] = [{"row": "semantic_changes", "reason": "Fixture proves signed waiver routing.", "owner": "owner", "approved_on": "2026-08-25"}]
	if not SequenceSchemaScript.validate_definition(excepted, OperationRegistryScript).is_empty():
		failures.append("Signed owner exception did not waive its named completion row only.")
	var unsigned := excepted.duplicate(true)
	unsigned["sequence"]["owner_exceptions"][0].erase("approved_on")
	if not _contains_text(SequenceSchemaScript.validate_definition(unsigned, OperationRegistryScript), "owner exception"):
		failures.append("Unsigned hard-10 owner exception was accepted.")


static func _check_extension_dispatch(failures: Array) -> void:
	var command := SequenceRuntimeScript.command("use", "bar_node", "arrival", "extension:1", {}, "scenario", "fixture")
	var handled := ScenarioExtensionDispatchScript.prepare_command({}, command, {"available_funds": 10})
	if not bool(handled.get("ok", false)) or JSON.stringify(handled.get("command", {})) != JSON.stringify(command):
		failures.append("Base scenario handler extension changed the authoritative command envelope.")
	var rendered := ScenarioExtensionDispatchScript.prepare_render({}, {"layout": {"object_rects": {}}}, {"scenario_id": "fixture", "phase_id": "arrival", "status": "active", "boundary_serial": 0, "semantic_state": {}})
	if not bool(rendered.get("ok", false)) or str(rendered.get("renderer_id", "")) != "semantic_v1":
		failures.append("Base scenario renderer extension did not produce its fixed semantic snapshot contract.")
	if ScenarioExtensionDispatchScript.validate_package_extensions("invented_package", "invented", "invented").is_empty():
		failures.append("Scenario extension dispatch accepted a package outside the fixed four-package interface.")
	var escaped_handler := ScenarioExtensionDispatchScript.prepare_command({"sequence_handler_pack": "../run_state"}, command, {"available_funds": 10})
	if bool(escaped_handler.get("ok", true)) or not _contains_text(_array(escaped_handler.get("errors", [])), "allowlist"):
		failures.append("Scenario extension dispatch accepted a handler path outside its fixed allowlist.")


static func _check_definition_validation_receipt(failures: Array) -> void:
	var definition := _runtime_definition()
	var environment := {"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node", "scenario_state": {"id": definition.get("id", "")}}
	var resolved := ScenarioEngineScript.sequence_definition_for_environment(environment, definition)
	if not bool(resolved.get("__scenario_sequence_runtime_validated", false)):
		failures.append("Scenario definition resolution did not issue its immutable validation receipt.")
	var cached := ScenarioEngineScript.sequence_definition_for_environment(environment, resolved)
	if JSON.stringify(cached) != JSON.stringify(resolved):
		failures.append("Scenario definition validation receipt was not stable across runtime reads.")


static func _check_suppressed_sequence_compatibility(failures: Array) -> void:
	var definition := _runtime_definition()
	var ordinary_environment := {
		"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node",
		"layout": {"object_rects": {}}, "game_ids": ["slots"],
		"service_ids": ["fixture_service"], "travel_hooks": ["old_exit"],
		"scenario_game_modifiers": {},
	}
	ScenarioEngineScript.attach_to_environment(ordinary_environment, ScenarioEngineScript.initial_state(definition), definition)
	var ordinary_resolved := ScenarioEngineScript.sequence_definition_for_environment(ordinary_environment, definition)
	if not SequenceSchemaScript.is_sequence(ordinary_resolved) or _dict(ordinary_environment.get("scenario_sequence_state", {})).is_empty() or _dict(ordinary_environment.get("scenario_sequence_projection", {})).is_empty():
		failures.append("An ordinary scenario definition lost its full dynamic sequence during compatibility setup.")

	var suppressed_definition := ScenarioEngineScript.suppress_sequence_definition(definition)
	if str(suppressed_definition.get("id", "")) != str(definition.get("id", "")) or SequenceSchemaScript.is_sequence(suppressed_definition) or not bool(suppressed_definition.get(ScenarioEngineScript.SEQUENCE_SUPPRESSION_KEY, false)):
		failures.append("Sequence suppression did not preserve identity while removing the dynamic overlay.")
	var suppressed_environment := {
		"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node",
		"layout": {"object_rects": {}}, "game_ids": ["slots"],
		"service_ids": ["fixture_service"], "travel_hooks": ["old_exit"],
		"scenario_game_modifiers": {},
	}
	ScenarioEngineScript.attach_to_environment(suppressed_environment, ScenarioEngineScript.initial_state(suppressed_definition), definition)
	if str(_dict(suppressed_environment.get("scenario_state", {})).get("id", "")) != str(definition.get("id", "")) or not bool(_dict(suppressed_environment.get("scenario_state", {})).get(ScenarioEngineScript.SEQUENCE_SUPPRESSION_KEY, false)):
		failures.append("Suppressed sequence setup lost its retained scenario identity marker.")
	var hostile_state := SequenceRuntimeScript.initial_state(definition, "bar_node", "suppressed_hostile")
	hostile_state["event_request_queue"] = [{"request_id": "hostile", "event_id": "fixture_event", "resolution_id": "fixture_resolution"}]
	suppressed_environment["scenario_sequence_state"] = hostile_state
	suppressed_environment["scenario_sequence_projection"] = {"hostile": true}
	suppressed_environment["scenario_render_snapshot"] = {"hostile": true}
	suppressed_environment["scenario_sequence_migration"] = {"hostile": true}
	suppressed_environment["scenario_sequence_definition"] = definition.duplicate(true)
	suppressed_environment["scenario_sequence_base_game_ids"] = ["slots"]
	suppressed_environment["scenario_sequence_base_service_ids"] = ["fixture_service"]
	suppressed_environment["scenario_sequence_base_travel_hooks"] = ["old_exit"]
	suppressed_environment["scenario_sequence_base_game_modifiers"] = {}
	suppressed_environment["game_ids"] = ["leaked_game"]
	suppressed_environment["service_ids"] = ["leaked_service"]
	suppressed_environment["travel_hooks"] = ["leaked_route"]
	suppressed_environment["scenario_game_modifiers"] = {"leaked_game": {"tone": "hostile"}}
	var suppressed_state := ScenarioEngineScript.ensure_sequence_state(suppressed_environment, definition)
	var suppressed_resolved := ScenarioEngineScript.sequence_definition_for_environment(suppressed_environment, definition)
	if not suppressed_state.is_empty() or SequenceSchemaScript.is_sequence(suppressed_resolved) or not ScenarioEngineScript.sequence_projection(suppressed_environment, definition).is_empty():
		failures.append("A mutation-suppressed scenario reacquired a dynamic sequence by preferred definition or scenario id.")
	for forbidden_key in ["scenario_sequence_state", "scenario_sequence_projection", "scenario_render_snapshot", "scenario_sequence_migration", "scenario_sequence_definition", "scenario_sequence_base_game_ids", "scenario_sequence_base_service_ids", "scenario_sequence_base_travel_hooks", "scenario_sequence_base_game_modifiers"]:
		if suppressed_environment.has(forbidden_key):
			failures.append("Suppressed scenario retained sequence runtime artifact %s." % forbidden_key)
	if _array(suppressed_environment.get("game_ids", [])) != ["slots"] or _array(suppressed_environment.get("service_ids", [])) != ["fixture_service"] or _array(suppressed_environment.get("travel_hooks", [])) != ["old_exit"] or not _dict(suppressed_environment.get("scenario_game_modifiers", {})).is_empty():
		failures.append("Suppressed scenario did not restore its pre-sequence material baseline.")
	var inactive_command := ScenarioEngineScript.sequence_command(suppressed_environment, definition, SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "suppressed:command", {}, "scenario", "command_console"), {"available_funds": 10})
	var inactive_requests := ScenarioEngineScript.drain_sequence_event_requests(suppressed_environment, definition)
	if bool(inactive_command.get("ok", true)) or not bool(inactive_requests.get("inactive", false)) or not _array(inactive_requests.get("requests", [])).is_empty():
		failures.append("Suppressed scenario exposed command authority or an event-bridge request drain.")

	# Pre-marker saves restore through RunState.from_dict before RunGenerator can
	# revisit a room. Cover every persisted environment graph so the content
	# catalog cannot activate a newly installed overlay during that early seam.
	var old_run := RunStateScript.new()
	var old_challenge := RunStateScript.custom_challenge("suppressed_restore", "SUPPRESSED-RESTORE", {
		"scenario_pins": {"bar": str(definition.get("id", "")), "grand_casino": str(definition.get("id", ""))},
		"scenario_pins_apply_mutations": false,
	})
	old_run.start_new("SUPPRESSED-RESTORE", old_challenge)
	var hostile_snapshot := {
		"id": "bar_legacy", "archetype_id": "bar", "world_node_id": "bar_legacy_node",
		"layout": {"object_rects": {}}, "game_ids": ["leaked_game"],
		"service_ids": ["leaked_service"], "travel_hooks": ["leaked_route"],
		"scenario_game_modifiers": {"leaked_game": {"tone": "hostile"}},
		"scenario_sequence_base_game_ids": ["slots"],
		"scenario_sequence_base_service_ids": ["fixture_service"],
		"scenario_sequence_base_travel_hooks": ["old_exit"],
		"scenario_sequence_base_game_modifiers": {},
		"scenario_sequence_definition": definition.duplicate(true),
		"scenario_sequence_migration": {"hostile": true},
	}
	ScenarioEngineScript.attach_to_environment(hostile_snapshot, ScenarioEngineScript.initial_state(definition), definition)
	var hostile_runtime_state := SequenceRuntimeScript.initial_state(definition, "bar_legacy_node", "pre_marker")
	hostile_runtime_state["event_request_queue"] = [{"request_id": "hostile", "event_id": "fixture_event", "resolution_id": "fixture_resolution"}]
	hostile_snapshot["scenario_sequence_state"] = hostile_runtime_state
	hostile_snapshot["scenario_sequence_projection"] = {"hostile": true}
	hostile_snapshot["scenario_render_snapshot"] = {"hostile": true}
	var hostile_layer := hostile_snapshot.duplicate(true)
	hostile_layer["id"] = "bar_legacy_layer"
	hostile_layer["world_node_id"] = "bar_legacy_layer_node"
	hostile_layer.erase("archetype_id")
	var hostile_layer_scenario := _dict(hostile_layer.get("scenario_state", {}))
	hostile_layer_scenario["archetype_id"] = ""
	hostile_layer["scenario_state"] = hostile_layer_scenario
	hostile_snapshot["environment_layer_schema_version"] = 1
	hostile_snapshot["current_layer_id"] = "main"
	hostile_snapshot["default_layer_id"] = "main"
	hostile_snapshot["layer_ids"] = ["main", "side"]
	hostile_snapshot["layer_states"] = {"side": hostile_layer}
	old_run.current_environment = hostile_snapshot.duplicate(true)
	old_run.world_map = {
		"version": 1, "seed_text": "SUPPRESSED-RESTORE", "start_node_id": "stored_bar", "current_node_id": "stored_bar",
		"nodes": [{"id": "stored_bar", "archetype_id": "bar", "state": "visited", "environment": hostile_layer.duplicate(true)}],
		"edges": [], "visited_path": ["stored_bar"],
	}
	var hostile_grand_room := hostile_layer.duplicate(true)
	hostile_grand_room["id"] = "grand_casino_legacy"
	hostile_grand_room["archetype_id"] = "grand_casino"
	hostile_grand_room["world_node_id"] = "grand_casino"
	old_run.grand_casino_room_states = {"grand_casino": hostile_grand_room}
	var old_save := old_run.to_dict()
	var restored_run := RunStateScript.new()
	restored_run.from_dict(old_save)
	var restored_nodes := _array(_dict(restored_run.world_map).get("nodes", []))
	var restored_stored_environment := _dict(_dict(restored_nodes[0] if not restored_nodes.is_empty() else {}).get("environment", {}))
	var restored_snapshots := [
		{"path": "current", "environment": restored_run.current_environment},
		{"path": "layer", "environment": _dict(_dict(restored_run.current_environment.get("layer_states", {})).get("side", {}))},
		{"path": "world", "environment": restored_stored_environment},
		{"path": "grand", "environment": _dict(restored_run.grand_casino_room_states.get("grand_casino", {}))},
	]
	for restored_entry_value in restored_snapshots:
		var restored_entry := _dict(restored_entry_value)
		var restored_environment := _dict(restored_entry.get("environment", {}))
		var restored_scenario := _dict(restored_environment.get("scenario_state", {}))
		if str(restored_scenario.get("id", "")) != str(definition.get("id", "")) or not bool(restored_scenario.get(ScenarioEngineScript.SEQUENCE_SUPPRESSION_KEY, false)):
			failures.append("Suppressed old-save %s snapshot lost identity or its durable suppression marker." % str(restored_entry.get("path", "")))
		for forbidden_key in ["scenario_sequence_state", "scenario_sequence_projection", "scenario_render_snapshot", "scenario_sequence_migration", "scenario_sequence_definition", "scenario_sequence_base_game_ids", "scenario_sequence_base_service_ids", "scenario_sequence_base_travel_hooks", "scenario_sequence_base_game_modifiers"]:
			if restored_environment.has(forbidden_key):
				failures.append("Suppressed old-save %s snapshot retained sequence runtime artifact %s." % [str(restored_entry.get("path", "")), forbidden_key])
		if _array(restored_environment.get("game_ids", [])) != ["slots"] or _array(restored_environment.get("service_ids", [])) != ["fixture_service"] or _array(restored_environment.get("travel_hooks", [])) != ["old_exit"] or not _dict(restored_environment.get("scenario_game_modifiers", {})).is_empty():
			failures.append("Suppressed old-save %s snapshot did not restore its pre-sequence material baseline." % str(restored_entry.get("path", "")))
	var restored_definition := restored_run.scenario_sequence_definition()
	var restored_requests := restored_run.scenario_drain_event_requests()
	if SequenceSchemaScript.is_sequence(restored_definition) or restored_run.scenario_sequence_active() or not bool(restored_requests.get("inactive", false)) or not _array(restored_requests.get("requests", [])).is_empty():
		failures.append("Suppressed old-save restore reacquired a sequence or event authority after migration.")


static func _check_transition_and_event_delivery(failures: Array) -> void:
	var definition := _runtime_definition()
	var initial := SequenceRuntimeScript.initial_state(definition, "bar_node", "delivery_seed")
	var first := SequenceRuntimeScript.drain_transitions(initial, definition)
	var first_state := _dict(first.get("state", {}))
	var replay := SequenceRuntimeScript.drain_transitions(first_state, definition)
	if not bool(first.get("ok", false)) or _array(first.get("transitions", [])).is_empty() or not _array(replay.get("transitions", [])).is_empty():
		failures.append("Scenario transition delivery was not durable and exactly once.")
	var staged_state := _prepared_fixture_state(definition, "stage_seed", failures)
	var staged_delivery := SequenceRuntimeScript.drain_transitions(staged_state, definition)
	var staged_delivery_state := _dict(staged_delivery.get("state", {}))
	if _array(staged_delivery_state.get("active_stages", [])).size() != 1:
		failures.append("Scenario stage transition did not become active after delivery.")
	var boundary_fact := SequenceRuntimeScript.fact("world_boundary", "scenario", "bar_node", "stage:boundary:1", 1, 1, {"amount": 1, "action_index": 1})
	var boundary_queued := SequenceRuntimeScript.enqueue_fact(staged_delivery_state, definition, boundary_fact)
	var boundary_flushed := SequenceRuntimeScript.flush_facts(_dict(boundary_queued.get("state", {})), definition, 1)
	if not bool(boundary_flushed.get("ok", false)) or not _array(_dict(boundary_flushed.get("state", {})).get("active_stages", [])).is_empty():
		failures.append("Scenario stage transition did not expire at its deterministic world boundary.")
	var reduced_state := _prepared_fixture_state(definition, "reduced_stage_seed", failures)
	var reduced_delivery := SequenceRuntimeScript.drain_transitions(reduced_state, definition, true)
	if not bool(reduced_delivery.get("ok", false)) or not _array(_dict(reduced_delivery.get("state", {})).get("active_stages", [])).is_empty():
		failures.append("Reduced-motion transition delivery retained a timed visual stage.")
	var bridged_definition := definition.duplicate(true)
	var sequence := _dict(bridged_definition.get("sequence", {}))
	var graph := _dict(sequence.get("phase_graph", {}))
	var phases := _array(graph.get("phases", []))
	var arrival := _dict(phases[0])
	var interaction_ops := _array(arrival.get("interaction_ops", []))
	var command_console_op := _dict(interaction_ops[interaction_ops.size() - 1])
	var command_console := _dict(command_console_op.get("interaction", {}))
	var actions := _array(command_console.get("available_actions", []))
	actions[0]["handler"] = "event_bridge"
	actions[0]["inputs"] = {"event_id": "fixture_event", "resolution_id": "fixture_resolution"}
	command_console["available_actions"] = actions
	command_console_op["interaction"] = command_console
	interaction_ops[interaction_ops.size() - 1] = command_console_op
	arrival["interaction_ops"] = interaction_ops
	phases[0] = arrival
	graph["phases"] = phases
	sequence["phase_graph"] = graph
	var objectives := _array(sequence.get("objectives", []))
	var event_objective := _dict(objectives[0])
	var event_steps := _array(event_objective.get("steps", []))
	event_steps.append({"id": "record_event_choice", "label": "Record the correlated event choice", "kind": "fact", "fact_type": "event_result", "payload_equals": {"event_id": "fixture_event"}})
	event_objective["steps"] = event_steps
	objectives[0] = event_objective
	sequence["objectives"] = objectives
	sequence["fact_subscriptions"][0] = {
		"fact_type": "event_result",
		"payload_equals": {"event_id": "fixture_event"},
		"handler": "increment_local",
		"inputs": {"key": "pressure", "amount": 1},
	}
	bridged_definition["sequence"] = sequence
	var applied := SequenceRuntimeScript.apply_command(SequenceRuntimeScript.initial_state(bridged_definition, "bar_node", "event_seed"), bridged_definition, SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "event_bridge:1", {}, "scenario", "command_console"), {"available_funds": 2})
	var drained := SequenceRuntimeScript.drain_event_requests(_dict(applied.get("state", {})), bridged_definition)
	var drained_again := SequenceRuntimeScript.drain_event_requests(_dict(drained.get("state", {})), bridged_definition)
	if not bool(applied.get("ok", false)) or _array(drained.get("requests", [])).size() != 1 or not _array(drained_again.get("requests", [])).is_empty():
		failures.append("Scenario event bridge did not publish one durable correlated request.")
	var delivered_state := _dict(drained.get("state", {}))
	var unrelated_fact := SequenceRuntimeScript.fact("event_result", "event", "bar_node", "event:unrelated", 1, 1, {"event_id": "unrelated_event", "choice_id": "accept", "resolved": true, "ok": true})
	var unrelated_queued := SequenceRuntimeScript.enqueue_fact(delivered_state, bridged_definition, unrelated_fact)
	var unrelated_result := SequenceRuntimeScript.flush_facts(_dict(unrelated_queued.get("state", {})), bridged_definition, 1)
	if bool(unrelated_result.get("ok", true)) or not _contains_text(_array(unrelated_result.get("errors", [])), "does not match") or int(_dict(_dict(unrelated_result.get("state", {})).get("local_state", {})).get("pressure", -1)) != 0 or not _array(_dict(unrelated_result.get("state", {})).get("event_choice_receipts", [])).is_empty():
		failures.append("An unrelated event_result with a colliding choice id reached this scenario before payload isolation.")
	var uncorrelated_fact := SequenceRuntimeScript.fact("event_result", "event", "bar_node", "event:uncorrelated", 2, 1, {"event_id": "fixture_event", "choice_id": "accept", "resolved": true, "ok": true})
	var uncorrelated_queued := SequenceRuntimeScript.enqueue_fact(delivered_state, bridged_definition, uncorrelated_fact)
	var uncorrelated_result := SequenceRuntimeScript.flush_facts(_dict(uncorrelated_queued.get("state", {})), bridged_definition, 1)
	if bool(uncorrelated_result.get("ok", true)) or not _contains_text(_array(uncorrelated_result.get("errors", [])), "does not match") or int(_dict(_dict(uncorrelated_result.get("state", {})).get("local_state", {})).get("pressure", -1)) != 0 or JSON.stringify(_dict(uncorrelated_result.get("state", {})).get("objective_progress", {})) != JSON.stringify(delivered_state.get("objective_progress", {})):
		failures.append("A delivered event-bridge request accepted an event_result without its resolution correlation.")
	var branch_definition := bridged_definition.duplicate(true)
	var branch_sequence := _dict(branch_definition.get("sequence", {}))
	var branch_graph := _dict(branch_sequence.get("phase_graph", {}))
	var branch_phases := _array(branch_graph.get("phases", []))
	var branch_complication := _dict(branch_phases[1])
	var complication_branches := _array(branch_complication.get("branches", []))
	complication_branches.append({"id": "event_collision_to_aftermath", "condition": {"type": "fact", "fact_type": "event_result", "payload_equals": {"event_id": "fixture_event"}}, "next_phase": "aftermath"})
	branch_complication["branches"] = complication_branches
	branch_phases[1] = branch_complication
	var branch_aftermath := _dict(branch_phases[2])
	var aftermath_branches := _array(branch_aftermath.get("branches", []))
	aftermath_branches.append({"id": "event_collision_repaired", "condition": {"type": "fact", "fact_type": "event_result", "payload_equals": {"event_id": "fixture_event"}}, "outcome": "repaired", "objective_outcomes": {"clear_exit": "success"}})
	branch_aftermath["branches"] = aftermath_branches
	branch_phases[2] = branch_aftermath
	branch_graph["phases"] = branch_phases
	branch_sequence["phase_graph"] = branch_graph
	branch_definition["sequence"] = branch_sequence
	var branch_uncorrelated_result := SequenceRuntimeScript.flush_facts(_dict(uncorrelated_queued.get("state", {})), branch_definition, 1)
	if bool(branch_uncorrelated_result.get("ok", true)) or not _contains_text(_array(branch_uncorrelated_result.get("errors", [])), "does not match"):
		failures.append("Uncorrelated event-result branch fixture was not rejected.")
	for stable_key in ["phase_id", "status", "local_state", "objective_progress", "resolved_branches", "resolved_outcomes", "semantic_state"]:
		if JSON.stringify(_dict(branch_uncorrelated_result.get("state", {})).get(stable_key)) != JSON.stringify(delivered_state.get(stable_key)):
			failures.append("Uncorrelated event-result isolation ran a handler, objective step, or branch before rejection (%s)." % stable_key)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("ENV06-6-EVENT-BRIDGE", RunState.custom_challenge("env06_6_event_bridge", "ENV06-6-EVENT-BRIDGE", {"fixture": true}))
	run_state.current_environment = {
		"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node",
		"scenario_state": ScenarioEngineScript.initial_state(bridged_definition),
		"scenario_sequence_definition": bridged_definition,
		"scenario_sequence_state": delivered_state,
		"layout": {"object_rects": {}},
	}
	run_state.scenario_publish_event_result({"event_id": "fixture_event", "choice_id": "accept", "resolved": true, "ok": true})
	var published_queue := _array(_dict(run_state.current_environment.get("scenario_sequence_state", {})).get("fact_queue", []))
	if published_queue.is_empty() or str(_dict(_dict(published_queue[published_queue.size() - 1]).get("payload", {})).get("resolution_id", "")) != "fixture_resolution":
		failures.append("Production event-result routing did not infer its delivered scenario resolution correlation.")
	var correlated_fact := SequenceRuntimeScript.fact("event_result", "event", "bar_node", "event:correlated", 1, 1, {"event_id": "fixture_event", "choice_id": "accept", "resolution_id": "fixture_resolution", "resolved": true, "ok": true})
	var correlated_queued := SequenceRuntimeScript.enqueue_fact(delivered_state, bridged_definition, correlated_fact)
	var correlated_result := SequenceRuntimeScript.flush_facts(_dict(correlated_queued.get("state", {})), bridged_definition, 1)
	var correlated_state := _dict(correlated_result.get("state", {}))
	if not bool(correlated_result.get("ok", false)) or not _array(correlated_state.get("event_choice_receipts", [])).has("fixture_resolution:accept") or int(_dict(correlated_state.get("local_state", {})).get("pressure", -1)) != 1 or not _array(_dict(_dict(correlated_state.get("objective_progress", {})).get("clear_exit", {})).get("completed_steps", [])).has("record_event_choice"):
		failures.append("Scenario event bridge did not accept its delivered correlated event result.")
	var consumed_fact := SequenceRuntimeScript.fact("event_result", "event", "bar_node", "event:consumed_again", 2, 1, {"event_id": "fixture_event", "choice_id": "conflicting_choice", "resolution_id": "fixture_resolution", "resolved": true, "ok": true})
	var consumed_queued := SequenceRuntimeScript.enqueue_fact(correlated_state, bridged_definition, consumed_fact)
	var consumed_result := SequenceRuntimeScript.flush_facts(_dict(consumed_queued.get("state", {})), bridged_definition, 1)
	if bool(consumed_result.get("ok", true)) or not _contains_text(_array(consumed_result.get("errors", [])), "does not match") or int(_dict(_dict(consumed_result.get("state", {})).get("local_state", {})).get("pressure", -1)) != 1 or _array(_dict(consumed_result.get("state", {})).get("event_choice_receipts", [])).size() != 1:
		failures.append("A consumed event resolution reran under a fresh fact id or conflicting choice.")
	var mismatched_fact := SequenceRuntimeScript.fact("event_result", "event", "bar_node", "event:mismatched", 2, 1, {"event_id": "fixture_event", "choice_id": "accept", "resolution_id": "wrong_resolution", "resolved": true, "ok": true})
	var mismatched_queued := SequenceRuntimeScript.enqueue_fact(delivered_state, bridged_definition, mismatched_fact)
	var mismatched_result := SequenceRuntimeScript.flush_facts(_dict(mismatched_queued.get("state", {})), bridged_definition, 1)
	if bool(mismatched_result.get("ok", true)) or not _contains_text(_array(mismatched_result.get("errors", [])), "does not match"):
		failures.append("Scenario event bridge accepted an unmatched event-result correlation.")


static func _check_delivery_day_production_package(library: ContentLibrary, failures: Array) -> void:
	var raw_package: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/environments/scenario_sequences/env06_7_shops_streets.json"))
	if typeof(raw_package) != TYPE_DICTIONARY or int(_dict(raw_package).get("schema_version", 0)) != 1 or _dict(raw_package).keys() != ["schema_version", "package_id", "handler_pack", "renderer_id", "scenarios"]:
		failures.append("Delivery-day JSON is not the exact schema-v1 object envelope.")
		return
	var catalog := SequenceCatalogScript.load_catalog()
	var definition := library.scenario(DELIVERY_SCENARIO_ID)
	var packages := _array(catalog.get("packages", []))
	if not bool(catalog.get("ok", false)) or _array(catalog.get("files", [])) != ["env06_7_shops_streets.json"] or packages.size() != 1:
		failures.append("Delivery-day proof did not load as one committed object package: %s" % JSON.stringify(catalog))
		return
	var package := _dict(packages[0])
	if str(package.get("package_id", "")) != "env06_7_shops_streets" or str(package.get("handler_pack", "")) != "shops_streets" or str(package.get("renderer_id", "")) != "shops_streets" or _array(package.get("scenario_ids", [])) != [DELIVERY_SCENARIO_ID]:
		failures.append("Delivery-day package envelope/extension identity changed: %s" % JSON.stringify(package))
	if definition.is_empty() or str(definition.get("sequence_package_id", "")) != "env06_7_shops_streets" or str(definition.get("sequence_handler_pack", "")) != "shops_streets" or str(definition.get("sequence_renderer_id", "")) != "shops_streets":
		failures.append("ContentLibrary did not apply the committed delivery-day package exactly.")
		return
	var definition_errors := SequenceSchemaScript.validate_definition(definition, OperationRegistryScript)
	if not definition_errors.is_empty():
		failures.append("Committed delivery-day definition failed schema/registry validation: %s" % JSON.stringify(definition_errors))
		return
	var sequence := SequenceSchemaScript.sequence(definition)
	if SequenceSchemaScript.phase_ids(definition) != ["arrival", "sorting", "verification", "awaiting_stock", "resolution"]:
		failures.append("Committed delivery-day phase graph identity/order changed.")
	var authoring := _dict(definition.get("sequence_authoring", {}))
	var references := _dict(authoring.get("references", {}))
	if _array(references.get("events", [])) != [DELIVERY_EVENT_ID] \
		or _array(references.get("services", [])) != ["cashier_tip"] \
		or _array(references.get("items", [])) != ["delivery_twine"] \
		or _array(references.get("actors", [])) != ["ada_corner_merchant", "priya_travel_merchant"] \
		or _array(references.get("objects", [])) != ["event::event:scenario_delivery_day_stock", "service::shopkeeper:merchant", "service::service:cashier_tip", "base::travel:leave"]:
		failures.append("Committed delivery-day external references changed: %s" % JSON.stringify(references))
	var receipts := _delivery_receipts(sequence)
	for receipt_id in ["arrival_gate_host_delivery_event", "awaiting_stock_keep_host_delivery_event_gated", "resolution_close_host_delivery_event", "cleanup_install_terminal_delivery_event_gate", "aftermath_repaired_remove_terminal_event_gate", "aftermath_broken_remove_terminal_event_gate"]:
		if not receipts.has(receipt_id):
			failures.append("Committed delivery-day receipt is missing: %s." % receipt_id)
	if _array(authoring.get("capture_ids", [])).is_empty() or _dict(authoring.get("seed_evidence", {})).is_empty() or not _array(_dict(authoring.get("seed_evidence", {})).get("base_event_gate_cases", [])).has("drained_request_activates_event"):
		failures.append("Committed delivery-day capture/seed evidence is incomplete or still claims pre-drain event authority.")

	var arrival := SequenceRuntimeScript.initial_state(definition, DELIVERY_NODE_ID, "delivery_day_production")
	var sorting_result := SequenceRuntimeScript.apply_command(arrival, definition, SequenceRuntimeScript.command("inspect_manifest", DELIVERY_NODE_ID, "arrival", "delivery:inspect", {}, "scenario", "delivery_event_gate"), {})
	var sorting := _dict(sorting_result.get("state", {}))
	var verification_result := SequenceRuntimeScript.apply_command(sorting, definition, SequenceRuntimeScript.command("shift_cartons", DELIVERY_NODE_ID, "sorting", "delivery:shift", {}, "scenario", "delivery_cartons"), {})
	var verification := _dict(verification_result.get("state", {}))
	if not bool(sorting_result.get("ok", false)) or str(sorting.get("phase_id", "")) != "sorting" or not bool(verification_result.get("ok", false)) or str(verification.get("phase_id", "")) != "verification":
		failures.append("Committed delivery-day inspect/shift objective path did not reach verification.")
		return
	var hostile_sorting := SequenceRuntimeScript._enter_phase(arrival, definition, "sorting", "hostile_precondition", false)
	var hostile_commands := [
		{"label": "wrong owner", "result": SequenceRuntimeScript.apply_command(arrival, definition, SequenceRuntimeScript.command("inspect_manifest", DELIVERY_NODE_ID, "arrival", "delivery:hostile:owner", {}, "event", "delivery_event_gate"), {})},
		{"label": "wrong object", "result": SequenceRuntimeScript.apply_command(arrival, definition, SequenceRuntimeScript.command("inspect_manifest", DELIVERY_NODE_ID, "arrival", "delivery:hostile:object", {}, "scenario", "wrong_manifest"), {})},
		{"label": "wrong phase", "result": SequenceRuntimeScript.apply_command(arrival, definition, SequenceRuntimeScript.command("inspect_manifest", DELIVERY_NODE_ID, "sorting", "delivery:hostile:phase", {}, "scenario", "delivery_event_gate"), {})},
		{"label": "unknown command", "result": SequenceRuntimeScript.apply_command(arrival, definition, SequenceRuntimeScript.command("invent_delivery", DELIVERY_NODE_ID, "arrival", "delivery:hostile:unknown", {}, "scenario", "delivery_event_gate"), {})},
		{"label": "missing objective precondition", "result": SequenceRuntimeScript.apply_command(hostile_sorting, definition, SequenceRuntimeScript.command("shift_cartons", DELIVERY_NODE_ID, "sorting", "delivery:hostile:precondition", {}, "scenario", "delivery_cartons"), {})},
	]
	for hostile_command_value in hostile_commands:
		var hostile_command := _dict(hostile_command_value)
		var hostile_result := _dict(hostile_command.get("result", {}))
		if bool(hostile_result.get("ok", true)) or _array(hostile_result.get("errors", [])).is_empty():
			failures.append("Committed delivery-day package accepted hostile command class: %s." % str(hostile_command.get("label", "")))
	var inspect_replay := SequenceRuntimeScript.apply_command(sorting, definition, SequenceRuntimeScript.command("inspect_manifest", DELIVERY_NODE_ID, "arrival", "delivery:inspect", {}, "scenario", "delivery_event_gate"), {})
	var inspect_conflict := SequenceRuntimeScript.apply_command(sorting, definition, SequenceRuntimeScript.command("ignore_delivery", DELIVERY_NODE_ID, "sorting", "delivery:inspect", {}, "scenario", "delivery_exit"), {})
	if not bool(inspect_replay.get("ok", false)) or not bool(inspect_replay.get("replayed", false)) or JSON.stringify(inspect_replay.get("state", {})) != JSON.stringify(sorting) or bool(inspect_conflict.get("ok", true)) or not _contains_text(_array(inspect_conflict.get("errors", [])), "reused"):
		failures.append("Committed delivery-day command idempotency/reuse contract changed.")
	for phase_state_value in [arrival, sorting, verification]:
		var phase_state := _dict(phase_state_value)
		var event_record := _delivery_event_record(phase_state)
		if event_record.is_empty() or bool(event_record.get("enabled", true)):
			failures.append("Base delivery event was not gated during %s." % str(phase_state.get("phase_id", "")))
		if not _array(phase_state.get("event_request_queue", [])).is_empty() or not _array(phase_state.get("event_request_history", [])).is_empty() or not _array(phase_state.get("fact_queue", [])).is_empty():
			failures.append("A pre-authority delivery event click/result changed request or fact queues during %s." % str(phase_state.get("phase_id", "")))

	var early_fact := SequenceRuntimeScript.fact("event_result", "event", DELIVERY_NODE_ID, "delivery:event:shared", 17, 1, {"event_id": DELIVERY_EVENT_ID, "choice_id": "clear_the_aisle", "resolution_id": DELIVERY_RESOLUTION_ID, "resolved": true, "ok": true})
	var early_queued := SequenceRuntimeScript.enqueue_fact(arrival, definition, early_fact)
	var early_rejected := SequenceRuntimeScript.flush_facts(_dict(early_queued.get("state", {})), definition, 1)
	var early_rejected_state := _dict(early_rejected.get("state", {}))
	if bool(early_rejected.get("ok", true)) or not _contains_text(_array(early_rejected.get("errors", [])), "delivered event request") or str(early_rejected_state.get("phase_id", "")) != "arrival" or not _array(early_rejected_state.get("fact_queue", [])).is_empty() or not _array(early_rejected_state.get("fact_receipts", [])).is_empty() or int(early_rejected_state.get("last_flushed_fact_serial", -1)) != int(arrival.get("last_flushed_fact_serial", -2)):
		failures.append("Pre-authority correlated event result advanced state or consumed fact/producer authority.")

	var request_result := SequenceRuntimeScript.apply_command(verification, definition, SequenceRuntimeScript.command("request_stock_check", DELIVERY_NODE_ID, "verification", "delivery:request", {}, "scenario", "sorting_shelf"), {})
	var before_drain := _dict(request_result.get("state", {}))
	if not bool(request_result.get("ok", false)) or str(before_drain.get("phase_id", "")) != "awaiting_stock" or _array(before_drain.get("event_request_queue", [])).size() != 1 or not _array(before_drain.get("event_request_history", [])).is_empty() or bool(_delivery_event_record(before_drain).get("enabled", true)):
		failures.append("Delivery request did not queue once while keeping the base event gated before drain.")
	var request_replay := SequenceRuntimeScript.apply_command(before_drain, definition, SequenceRuntimeScript.command("request_stock_check", DELIVERY_NODE_ID, "verification", "delivery:request", {}, "scenario", "sorting_shelf"), {})
	if not bool(request_replay.get("ok", false)) or not bool(request_replay.get("replayed", false)) or JSON.stringify(request_replay.get("state", {})) != JSON.stringify(before_drain) or _array(_dict(request_replay.get("state", {})).get("event_request_queue", [])).size() != 1:
		failures.append("Delivery request replay duplicated or changed the queued event request.")
	var drained := SequenceRuntimeScript.drain_event_requests(before_drain, definition)
	var delivered := _dict(drained.get("state", {}))
	var requests := _array(drained.get("requests", []))
	var delivered_request := _dict(requests[0] if requests.size() == 1 else {})
	if not bool(drained.get("ok", false)) or requests.size() != 1 or str(delivered_request.get("event_id", "")) != DELIVERY_EVENT_ID or str(delivered_request.get("resolution_id", "")) != DELIVERY_RESOLUTION_ID or _array(delivered.get("event_request_history", [])).size() != 1 or not _array(delivered.get("event_request_queue", [])).is_empty() or bool(_delivery_event_record(delivered).get("enabled", true)):
		failures.append("Delivery bridge did not emit/history the exact request while retaining the host gate.")
	var early_recovery_sorting := _dict(SequenceRuntimeScript.apply_command(early_rejected_state, definition, SequenceRuntimeScript.command("inspect_manifest", DELIVERY_NODE_ID, "arrival", "delivery:recover:inspect", {}, "scenario", "delivery_event_gate"), {}).get("state", {}))
	var early_recovery_verification := _dict(SequenceRuntimeScript.apply_command(early_recovery_sorting, definition, SequenceRuntimeScript.command("shift_cartons", DELIVERY_NODE_ID, "sorting", "delivery:recover:shift", {}, "scenario", "delivery_cartons"), {}).get("state", {}))
	var early_recovery_before_drain := _dict(SequenceRuntimeScript.apply_command(early_recovery_verification, definition, SequenceRuntimeScript.command("request_stock_check", DELIVERY_NODE_ID, "verification", "delivery:recover:request", {}, "scenario", "sorting_shelf"), {}).get("state", {}))
	var early_recovery_delivered := _dict(SequenceRuntimeScript.drain_event_requests(early_recovery_before_drain, definition).get("state", {}))
	var drain_replay := SequenceRuntimeScript.drain_event_requests(delivered, definition)
	if not _array(drain_replay.get("requests", [])).is_empty() or JSON.stringify(drain_replay.get("state", {})) != JSON.stringify(delivered):
		failures.append("Delivery bridge request drain was not exactly-once/idempotent.")
	var ui_source := FileAccess.get_file_as_string("res://scripts/ui/foundation_main.gd")
	var consume_start := ui_source.find("func _consume_scenario_event_requests()")
	var consume_end := ui_source.find("\nfunc ", consume_start + 1)
	var consumer := ui_source.substr(consume_start, consume_end - consume_start) if consume_start >= 0 and consume_end > consume_start else ""
	if consumer.find("scenario_drain_event_requests()") < 0 or consumer.find("_activate_event_object(event_id)") < consumer.find("scenario_drain_event_requests()"):
		failures.append("Production UI no longer drains the scenario request before activating its event object.")

	for hostile_value in [
		{"label": "unresolved", "payload": {"event_id": DELIVERY_EVENT_ID, "choice_id": "clear_the_aisle", "resolution_id": DELIVERY_RESOLUTION_ID, "resolved": false, "ok": true}},
		{"label": "failed", "payload": {"event_id": DELIVERY_EVENT_ID, "choice_id": "clear_the_aisle", "resolution_id": DELIVERY_RESOLUTION_ID, "resolved": true, "ok": false}},
		{"label": "wrong_event_same_choice", "payload": {"event_id": "unrelated_delivery_event", "choice_id": "clear_the_aisle", "resolution_id": DELIVERY_RESOLUTION_ID, "resolved": true, "ok": true}},
		{"label": "missing_resolution", "payload": {"event_id": DELIVERY_EVENT_ID, "choice_id": "clear_the_aisle", "resolution_id": "", "resolved": true, "ok": true}},
		{"label": "wrong_resolution", "payload": {"event_id": DELIVERY_EVENT_ID, "choice_id": "clear_the_aisle", "resolution_id": "wrong_delivery_resolution", "resolved": true, "ok": true}},
	]:
		var hostile := _dict(hostile_value)
		var hostile_fact := SequenceRuntimeScript.fact("event_result", "event", DELIVERY_NODE_ID, "delivery:event:hostile_shared", 18, 1, _dict(hostile.get("payload", {})))
		var hostile_queued := SequenceRuntimeScript.enqueue_fact(delivered, definition, hostile_fact)
		var hostile_result := SequenceRuntimeScript.flush_facts(_dict(hostile_queued.get("state", {})), definition, 1)
		var hostile_state := _dict(hostile_result.get("state", {}))
		if bool(hostile_result.get("ok", true)) or str(hostile_state.get("phase_id", "")) != "awaiting_stock" or not _array(hostile_state.get("fact_queue", [])).is_empty() or not _array(hostile_state.get("fact_receipts", [])).is_empty() or int(hostile_state.get("last_flushed_fact_serial", -1)) != int(delivered.get("last_flushed_fact_serial", -2)):
			failures.append("Delivery %s event result poisoned or advanced the authoritative state." % str(hostile.get("label", "")))
		var corrected_fact := SequenceRuntimeScript.fact("event_result", "event", DELIVERY_NODE_ID, "delivery:event:hostile_shared", 18, 1, {"event_id": DELIVERY_EVENT_ID, "choice_id": "clear_the_aisle", "resolution_id": DELIVERY_RESOLUTION_ID, "resolved": true, "ok": true})
		var corrected_queued := SequenceRuntimeScript.enqueue_fact(hostile_state, definition, corrected_fact)
		var corrected_result := SequenceRuntimeScript.flush_facts(_dict(corrected_queued.get("state", {})), definition, 1)
		if not bool(corrected_result.get("ok", false)) or _array(_dict(corrected_result.get("state", {})).get("resolved_outcomes", [])) != ["repaired"]:
			failures.append("Delivery %s rejection could not recover with corrected same-id content from its returned state." % str(hostile.get("label", "")))
	var poison_fact := SequenceRuntimeScript.fact("event_result", "event", DELIVERY_NODE_ID, "delivery:event:poison", 22, 1, {"event_id": DELIVERY_EVENT_ID, "choice_id": "clear_the_aisle", "resolution_id": "wrong_delivery_resolution", "resolved": true, "ok": true})
	var future_sweep_fact := SequenceRuntimeScript.fact("sweep_changed", "sweep", DELIVERY_NODE_ID, "delivery:sweep:future", 23, 5, {"action_index": 5, "node_id": DELIVERY_NODE_ID, "segment_index": 1, "active": true})
	var poison_queued := SequenceRuntimeScript.enqueue_fact(delivered, definition, poison_fact)
	var future_queued := SequenceRuntimeScript.enqueue_fact(_dict(poison_queued.get("state", {})), definition, future_sweep_fact)
	var poison_rejected := SequenceRuntimeScript.flush_facts(_dict(future_queued.get("state", {})), definition, 1)
	var retained_after_rejection := _array(_dict(poison_rejected.get("state", {})).get("fact_queue", []))
	if bool(poison_rejected.get("ok", true)) or retained_after_rejection.size() != 1 or str(_dict(retained_after_rejection[0] if retained_after_rejection.size() == 1 else {}).get("fact_id", "")) != "delivery:sweep:future":
		failures.append("Rejected delivery fact did not preserve the other queued future fact exactly.")
	var retained_flush := SequenceRuntimeScript.flush_facts(_dict(poison_rejected.get("state", {})), definition, 5)
	var retained_flushed_state := _dict(retained_flush.get("state", {}))
	if not bool(retained_flush.get("ok", false)) or _array(retained_flush.get("processed", [])) != ["delivery:sweep:future"] or not _array(retained_flushed_state.get("fact_queue", [])).is_empty() or _array(retained_flushed_state.get("fact_receipts", [])) != ["delivery:sweep:future"] or _dict(retained_flushed_state.get("fact_fingerprints", {})).has("delivery:event:poison"):
		failures.append("The preserved future fact did not flush once without reviving the rejected poison identity.")

	var correlated_after_rejection := SequenceRuntimeScript.enqueue_fact(early_recovery_delivered, definition, early_fact)
	var repaired_result := SequenceRuntimeScript.flush_facts(_dict(correlated_after_rejection.get("state", {})), definition, 1)
	var repaired := _dict(repaired_result.get("state", {}))
	if not bool(repaired_result.get("ok", false)) or str(repaired.get("status", "")) != SequenceRuntimeScript.STATUS_AFTERMATH or _array(repaired.get("resolved_outcomes", [])) != ["repaired"] or not _array(repaired.get("fact_receipts", [])).has("delivery:event:shared"):
		failures.append("The exact correlated fact did not succeed after the discarded pre-authority rejection transaction.")
	var repaired_replay := SequenceRuntimeScript.enqueue_fact(repaired, definition, early_fact)
	if not bool(repaired_replay.get("ok", false)) or not bool(repaired_replay.get("duplicate", false)) or JSON.stringify(repaired_replay.get("state", {})) != JSON.stringify(repaired):
		failures.append("Committed delivery-day correlated result replay duplicated a consequence.")
	var broken_fact := SequenceRuntimeScript.fact("event_result", "event", DELIVERY_NODE_ID, "delivery:event:broken", 19, 1, {"event_id": DELIVERY_EVENT_ID, "choice_id": "take_the_deal", "resolution_id": DELIVERY_RESOLUTION_ID, "resolved": true, "ok": true})
	var broken_queued := SequenceRuntimeScript.enqueue_fact(delivered, definition, broken_fact)
	var broken := _dict(SequenceRuntimeScript.flush_facts(_dict(broken_queued.get("state", {})), definition, 1).get("state", {}))
	var refused := _dict(SequenceRuntimeScript.apply_command(arrival, definition, SequenceRuntimeScript.command("refuse_sort", DELIVERY_NODE_ID, "arrival", "delivery:refuse", {}, "scenario", "delivery_exit"), {}).get("state", {}))
	var interrupted := _dict(SequenceRuntimeScript.apply_command(arrival, definition, SequenceRuntimeScript.command("ignore_delivery", DELIVERY_NODE_ID, "arrival", "delivery:ignore", {}, "scenario", "delivery_exit"), {}).get("state", {}))
	var expired_result := SequenceRuntimeScript.apply_expiry(arrival, definition, "night_end", 1)
	var expired := _dict(expired_result.get("state", {}))
	var terminals := {"repaired": repaired, "broken": broken, "refused": refused, "interrupted": interrupted}
	var material_expectations := {
		"repaired": {"scene": "stocked_rack", "actor": "delivery_clerk", "service_enabled": true, "route": "jazz_club", "route_enabled": true},
		"broken": {"scene": "torn_carton", "actor": "", "service_enabled": false, "route": "bar", "route_enabled": false},
		"refused": {"scene": "sealed_pallet", "actor": "delivery_clerk", "service_enabled": false, "route": "pawn_shop", "route_enabled": false},
		"interrupted": {"scene": "abandoned_manifest", "actor": "", "service_enabled": true, "route": "gas_station_casino", "route_enabled": false},
	}
	for outcome_value in terminals.keys():
		var outcome := str(outcome_value)
		var terminal := _dict(terminals.get(outcome_value, {}))
		if str(terminal.get("status", "")) != SequenceRuntimeScript.STATUS_AFTERMATH or _array(terminal.get("resolved_outcomes", [])) != [outcome] or not _array(terminal.get("event_request_queue", [])).is_empty():
			failures.append("Delivery-day %s outcome did not terminate without a legacy event request." % outcome)
		var terminal_fact := SequenceRuntimeScript.fact("event_result", "event", DELIVERY_NODE_ID, "delivery:event:terminal:%s" % outcome, 20, 2, {"event_id": DELIVERY_EVENT_ID, "choice_id": "clear_the_aisle", "resolution_id": DELIVERY_RESOLUTION_ID, "resolved": true, "ok": true})
		var terminal_ingress := SequenceRuntimeScript.enqueue_fact(terminal, definition, terminal_fact)
		var terminal_drain := SequenceRuntimeScript.drain_event_requests(terminal, definition)
		if bool(terminal_ingress.get("ok", true)) or not _array(terminal_drain.get("requests", [])).is_empty():
			failures.append("Delivery-day %s terminal state accepted a legacy result/request consequence." % outcome)
		var has_terminal_gate := _has_delivery_overlay(terminal, "delivery_event_terminal_gate")
		if outcome in ["repaired", "broken"] and has_terminal_gate:
			failures.append("Legitimately resolved delivery outcome %s retained the terminal event overlay." % outcome)
		elif outcome in ["refused", "interrupted"] and not has_terminal_gate:
			failures.append("Delivery outcome %s lost durable unresolved-event suppression." % outcome)
		_check_delivery_material_state(outcome, terminal, _dict(material_expectations.get(outcome, {})), failures)
		var reentry := SequenceRuntimeScript.apply_reentry(terminal, definition, "delivery_terminal_%s" % outcome)
		var reentered := _dict(reentry.get("state", {}))
		var reentry_replay := SequenceRuntimeScript.apply_reentry(reentered, definition, "delivery_terminal_%s" % outcome)
		if not bool(reentry.get("ok", false)) or not bool(reentry_replay.get("replayed", false)) or JSON.stringify(reentry_replay.get("state", {})) != JSON.stringify(reentered):
			failures.append("Delivery-day %s terminal reentry was not idempotent." % outcome)
	if not bool(expired_result.get("ok", false)) or str(expired.get("status", "")) != SequenceRuntimeScript.STATUS_CLEANED or not _has_delivery_overlay(expired, "delivery_event_terminal_gate") or not _array(expired.get("resolved_outcomes", [])).is_empty() or not _array(expired.get("event_request_queue", [])).is_empty():
		failures.append("Delivery-day ignore expiry did not clean with durable suppression and no legacy consequences.")
	var expiry_replay := SequenceRuntimeScript.apply_expiry(expired, definition, "night_end", 1)
	if not bool(expiry_replay.get("ok", false)) or JSON.stringify(expiry_replay.get("state", {})) != JSON.stringify(expired):
		failures.append("Delivery-day expiry cleanup was not idempotent.")
	var expired_ingress := SequenceRuntimeScript.enqueue_fact(expired, definition, SequenceRuntimeScript.fact("event_result", "event", DELIVERY_NODE_ID, "delivery:event:expired", 21, 2, {"event_id": DELIVERY_EVENT_ID, "choice_id": "clear_the_aisle", "resolution_id": DELIVERY_RESOLUTION_ID, "resolved": true, "ok": true}))
	if bool(expired_ingress.get("ok", true)):
		failures.append("Delivery-day expired state accepted a legacy event consequence.")

	var coexistence_base := [
		_delivery_base_event_record(),
		_interaction_record("game", "game:blackjack", "Blackjack", true),
		_interaction_record("service", "service:cashier_tip", "Cashier tip", true),
		_interaction_record("traveler", "travel:leave", "Leave", true),
		_interaction_record("sweep", "police:sweep", "Police sweep", true),
	]
	var composed := OperationRegistryScript.resolve_interactions(coexistence_base, _dict(_dict(delivered.get("semantic_state", {})).get("interactions", {})).values())
	var composed_ids: Array = []
	for record_value in _array(composed.get("records", [])):
		composed_ids.append(OperationRegistryScript.identity_from(_dict(record_value)))
	for identity in ["event::event:scenario_delivery_day_stock", "game::game:blackjack", "service::service:cashier_tip", "traveler::travel:leave", "sweep::police:sweep"]:
		if not composed_ids.has(identity):
			failures.append("Delivery-day composition overwrote coexisting interaction %s." % identity)

	# Resolution is transaction-internal in production: accepted facts enter it
	# and select an outcome in the same bounded graph evaluation. Enter it through
	# the runtime's own phase transaction to prove its exact serialization shape.
	var resolution_snapshot := SequenceRuntimeScript._enter_phase(delivered, definition, "resolution", "persistence_probe", false)
	var checkpoints := {
		"arrival": arrival, "sorting": sorting, "verification": verification,
		"awaiting_before_request_drain": before_drain, "awaiting_after_request_drain": delivered,
		"resolution_transaction": resolution_snapshot,
		"outcome_repaired": repaired, "outcome_broken": broken,
		"outcome_refused": refused, "outcome_interrupted": interrupted, "expired": expired,
	}
	for label_value in checkpoints.keys():
		var label := str(label_value)
		var expected := _dict(checkpoints.get(label_value, {}))
		var restored := _save_service_round_trip_state(expected, definition, "delivery_%s" % label, failures, "corner_store", DELIVERY_NODE_ID)
		if not restored.is_empty() and JSON.stringify(restored) != JSON.stringify(expected):
			failures.append("SaveService changed exact committed delivery-day state at %s." % label)


static func _delivery_base_event_record() -> Dictionary:
	return _interaction_record("event", "event:scenario_delivery_day_stock", "Delivery stock", true)


static func _delivery_event_record(state: Dictionary) -> Dictionary:
	var resolved := OperationRegistryScript.resolve_interactions([_delivery_base_event_record()], _dict(_dict(state.get("semantic_state", {})).get("interactions", {})).values())
	for record_value in _array(resolved.get("records", [])):
		var record := _dict(record_value)
		if OperationRegistryScript.identity_from(record) == "event::event:scenario_delivery_day_stock":
			return record
	return {}


static func _has_delivery_overlay(state: Dictionary, stable_object_id: String) -> bool:
	for operation_value in _dict(_dict(state.get("semantic_state", {})).get("interactions", {})).values():
		if str(_dict(operation_value).get("owner_namespace", "")) == "scenario" and str(_dict(operation_value).get("stable_object_id", "")) == stable_object_id:
			return true
	return false


static func _check_delivery_material_state(outcome: String, state: Dictionary, expected: Dictionary, failures: Array) -> void:
	var semantic := _dict(state.get("semantic_state", {}))
	var scene_key := "scenario::%s" % str(expected.get("scene", ""))
	var actor_id := str(expected.get("actor", ""))
	var actor_key := "scenario::%s" % actor_id
	var service := _dict(_dict(semantic.get("services", {})).get("scenario::cashier_tip", {}))
	var route_key := "scenario::%s" % str(expected.get("route", ""))
	var route := _dict(_dict(semantic.get("routes", {})).get(route_key, {}))
	if not _dict(semantic.get("scene_objects", {})).has(scene_key) \
		or not actor_id.is_empty() and not _dict(semantic.get("actors", {})).has(actor_key) \
		or actor_id.is_empty() and _dict(semantic.get("actors", {})).has("scenario::delivery_clerk") \
		or service.is_empty() or bool(service.get("enabled", not bool(expected.get("service_enabled", false)))) != bool(expected.get("service_enabled", false)) \
		or route.is_empty() or bool(route.get("enabled", not bool(expected.get("route_enabled", false)))) != bool(expected.get("route_enabled", false)):
		failures.append("Delivery-day %s aftermath lost its exact scene/actor/service/route material state." % outcome)


static func _delivery_receipts(sequence: Dictionary) -> Array:
	var result: Array = []
	for phase_value in _array(_dict(sequence.get("phase_graph", {})).get("phases", [])):
		var phase := _dict(phase_value)
		for family in ["scene_ops", "interaction_ops", "actor_ops", "transition_ops"]:
			for operation_value in _array(phase.get(family, [])):
				result.append(str(_dict(operation_value).get("receipt_id", "")))
	for operation_value in _array(_dict(sequence.get("cleanup", {})).get("operations", [])):
		result.append(str(_dict(operation_value).get("receipt_id", "")))
	for aftermath_value in _dict(sequence.get("aftermath", {})).values():
		var aftermath := _dict(aftermath_value)
		for family in ["scene_ops", "interaction_ops", "actor_ops", "service_ops", "game_ops", "route_ops"]:
			for operation_value in _array(aftermath.get(family, [])):
				result.append(str(_dict(operation_value).get("receipt_id", "")))
	return result


static func _check_material_projection(failures: Array) -> void:
	var definition := _runtime_definition()
	var state := SequenceRuntimeScript.initial_state(definition, "bar_node", "material_seed")
	var semantic := _dict(state.get("semantic_state", {}))
	semantic["services"] = {"scenario::night_service": {"owner_namespace": "scenario", "stable_object_id": "night_service", "id": "night_service", "label": "Night service", "enabled": true}}
	semantic["games"] = {"scenario::blackjack": {"owner_namespace": "scenario", "stable_object_id": "blackjack", "id": "blackjack", "label": "Blackjack", "enabled": true, "modifier": {"tone": "tense"}}}
	semantic["routes"] = {"scenario::old_exit": {"owner_namespace": "scenario", "stable_object_id": "old_exit", "source_id": "alternate_exit", "enabled": true}}
	state["semantic_state"] = semantic
	var environment := {"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node", "game_ids": ["slots"], "service_ids": [], "travel_hooks": ["old_exit"], "scenario_game_modifiers": {}, "layout": {"object_rects": {}}, "scenario_state": {"id": definition.get("id", ""), "archetype_id": "bar", "phases": []}, "scenario_sequence_state": state}
	ScenarioEngineScript.refresh_sequence_snapshots(environment, definition)
	if not _array(environment.get("service_ids", [])).has("night_service") or not _array(environment.get("game_ids", [])).has("blackjack") or _array(environment.get("travel_hooks", [])) != ["alternate_exit"] or _dict(_dict(environment.get("scenario_game_modifiers", {})).get("blackjack", {})).is_empty():
		failures.append("Scenario semantic service/game/modifier/route state was not materialized into production environment fields.")


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
		{"id": "refuse", "label": "Refuse", "input_action": "ui_cancel", "non_color_state": "choice"},
	]
	interaction_op["interaction"]["input_actions"] = ["confirm", "ui_cancel"]
	arrival["interaction_ops"] = _array(arrival.get("interaction_ops", [])) + [interaction_op]
	arrival["branches"] = [{"id": "continue", "condition": {"type": "command", "command_id": "prepare"}, "next_phase": "complication"}]
	arrival["advance_after_actions"] = 0
	phases[0] = arrival
	var complication := _dict(phases[1])
	complication["branches"] = [
		{"id": "break", "condition": {"type": "fact", "fact_type": "heat_changed"}, "next_phase": "aftermath"},
		{"id": "refuse", "condition": {"type": "command", "command_id": "refuse"}, "next_phase": "aftermath"},
		{"id": "repair", "condition": {"type": "command", "command_id": "finish"}, "next_phase": "aftermath"},
	]
	phases[1] = complication
	graph["phases"] = phases
	sequence["phase_graph"] = graph
	sequence["objectives"] = [{"id": "clear_exit", "label": "Keep the exit clear", "progress_label": "Exit lane", "steps": [{"id": "move_chair", "label": "Move the chair", "kind": "command", "command_id": "prepare"}], "outcomes": ["success", "failure", "ignore", "cancel"]}]
	sequence["fact_subscriptions"] = [
		{"fact_type": "event_result", "payload_equals": {"event_id": "fixture_event"}},
		{"fact_type": "heat_changed", "handler": "set_local", "inputs": {"key": "pressure", "value_from_payload": "current"}},
	]
	var cleanup := _dict(sequence.get("cleanup", {}))
	var cleanup_operations := _array(cleanup.get("operations", []))
	cleanup_operations.append({"family": "interaction_ops", "op": "remove", "receipt_id": "cleanup_command_console", "owner_namespace": "scenario", "stable_object_id": "command_console"})
	cleanup["operations"] = cleanup_operations
	sequence["cleanup"] = cleanup
	definition["sequence"] = sequence
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
	return {
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
						"actor_ops": [_operation_fixture("actor_ops", "spawn", 105)],
						"transition_ops": [_operation_fixture("transition_ops", "feedback", 100)],
						"branches": [{"id": "continue", "condition": {"type": "command", "command_id": "protect_exit"}, "next_phase": "complication"}],
					},
					{
						"id": "complication", "label": "Blocked lane", "arrival_feedback": "A second chair skids into the route.", "exit_prompt": "Keep the marked exit lane readable.",
						"entry_conditions": [], "objective_ids": ["clear_exit"], "advance_after_actions": 1,
						"scene_ops": [_operation_fixture("scene_ops", "spawn", 104)], "interaction_ops": [], "actor_ops": [],
						"transition_ops": [_operation_fixture("transition_ops", "stage", 104)],
						"branches": [{"id": "settle", "condition": {"type": "always"}, "next_phase": "aftermath"}],
					},
					{
						"id": "aftermath", "label": "Cleanup", "arrival_feedback": "The lane opens again.", "exit_prompt": "Leave through the clear front door.", "terminal": true,
						"entry_conditions": [], "objective_ids": [], "advance_after_actions": 0, "scene_ops": [], "interaction_ops": [], "actor_ops": [], "transition_ops": [],
						"branches": [
							{"id": "break", "condition": {"type": "fact", "fact_type": "heat_changed"}, "outcome": "broken"},
							{"id": "refuse", "condition": {"type": "command", "command_id": "refuse"}, "outcome": "refused"},
							{"id": "finish", "condition": {"type": "command", "command_id": "finish"}, "outcome": "repaired"},
						],
					},
				],
			},
			"objectives": [{"id": "clear_exit", "label": "Keep the exit clear", "progress_label": "Exit lane", "steps": [{"id": "move_chair", "label": "Move the chair", "kind": "command", "command_id": "protect_exit"}], "outcomes": ["success", "failure", "ignore", "cancel"]}],
			"reentry_policy": {"partial": "resume", "terminal": "aftermath", "expired": "expired"},
			"expiry": {"boundary": "night_end", "after": 1, "policy": "ignore"},
			"cleanup": {"operations": [
				{"family": "scene_ops", "op": "remove", "receipt_id": "cleanup_scene", "owner_namespace": "scenario", "stable_object_id": "fixture_100"},
				{"family": "scene_ops", "op": "remove", "receipt_id": "cleanup_complication", "owner_namespace": "scenario", "stable_object_id": "fixture_104"},
				{"family": "interaction_ops", "op": "remove", "receipt_id": "cleanup_interaction", "owner_namespace": "scenario", "stable_object_id": "fixture_100"},
				{"family": "actor_ops", "op": "despawn", "receipt_id": "cleanup_actor", "owner_namespace": "scenario", "stable_object_id": "fixture_105"},
			]},
			"aftermath": {
				"repaired": {"label": "Repaired", "revisit_feedback": "The chair is back in place.", "scene_ops": [_operation_fixture("scene_ops", "spawn", 101)], "route_ops": [_operation_fixture("route_ops", "open", 101)]},
				"broken": {"label": "Broken", "revisit_feedback": "A broken chair marks the fight.", "scene_ops": [_operation_fixture("scene_ops", "spawn", 102)], "route_ops": [_operation_fixture("route_ops", "close", 102)]},
				"refused": {"label": "Refused", "revisit_feedback": "The staff keep their distance.", "actor_ops": [_operation_fixture("actor_ops", "spawn", 103)], "service_ops": [_operation_fixture("service_ops", "add", 103)]},
			},
			"mechanic_tags": ["room_route", "multi_step"],
			"sequence_signature": "route-protection-choice-aftermath",
			"owner_exceptions": [],
			"fact_subscriptions": [{"fact_type": "event_result", "payload_equals": {"event_id": "fixture_event"}}, "travel_departed", "heat_changed"],
			"completion_contract": {
				"arrival_readable": true, "semantic_changes": true, "scenario_interaction": true,
				"action_boundaries": true, "choice_or_failure": true, "material_outcomes": true,
				"revisit_coverage": true, "world_connection": true, "primary_verb": true,
				"feedback_and_exit": true,
			},
		},
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
				if index == 100: operation["interaction"]["safe_exit"] = true
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
