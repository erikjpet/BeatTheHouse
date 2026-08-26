extends RefCounted

const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const SequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const SequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")


static func check(_library: ContentLibrary, failures: Array) -> void:
	_check_schema(failures)
	_check_registered_operations(failures)
	_check_interaction_identity(failures)
	_check_negative_fixtures(failures)
	_check_lifecycle_commands(failures)
	_check_serialized_fact_ingress(failures)
	_check_sequence_persistence_seam(failures)
	_check_authoritative_receipt_capacity(failures)


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


static func _runtime_definition() -> Dictionary:
	var definition := _fixture_definition()
	var sequence := _dict(definition.get("sequence", {}))
	var graph := _dict(sequence.get("phase_graph", {}))
	var phases := _array(graph.get("phases", []))
	var arrival := _dict(phases[0])
	var interaction_op := _operation_fixture("interaction_ops", "add", 200)
	interaction_op["stable_object_id"] = "command_console"
	interaction_op["interaction"] = _interaction_record("scenario", "command_console", "Keep the exit clear", true)
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
						"actor_ops": [_operation_fixture("actor_ops", "spawn", 100)],
						"transition_ops": [_operation_fixture("transition_ops", "feedback", 100)],
						"branches": [{"id": "continue", "condition": {"type": "command", "command_id": "protect_exit"}, "next_phase": "aftermath"}],
					},
					{
						"id": "aftermath", "label": "Cleanup", "arrival_feedback": "The lane opens again.", "exit_prompt": "Leave through the clear front door.", "terminal": true,
						"entry_conditions": [], "objective_ids": [], "advance_after_actions": 0, "scene_ops": [], "interaction_ops": [], "actor_ops": [], "transition_ops": [],
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
			"mechanic_tags": ["room_route", "multi_step"],
			"sequence_signature": "route-protection-choice-aftermath",
			"owner_exceptions": [],
			"fact_subscriptions": ["event_result", "travel_departed", "heat_changed"],
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
