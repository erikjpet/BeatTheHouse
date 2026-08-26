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
		var applied := OperationRegistryScript.apply_operations(state, family, family_operations, "boundary_%s" % family)
		if not bool(applied.get("ok", false)):
			failures.append("Registered %s fixtures failed: %s." % [family, JSON.stringify(applied.get("errors", []))])
			continue
		state = _dict(applied.get("state", {}))
		var replay := OperationRegistryScript.apply_operations(state, family, family_operations, "boundary_%s" % family)
		if not bool(replay.get("ok", false)) or not _array(replay.get("applied", [])).is_empty() or JSON.stringify(replay.get("state", {})) != JSON.stringify(state):
			failures.append("Registered %s operations are not idempotent by boundary receipt." % family)
	if _array(state.get("operation_receipts", [])).size() != 39:
		failures.append("Registered operation fixture did not receipt every operation exactly once.")
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
		{"id": "prepare", "label": "Brace the exit", "cost": 2, "handler": "increment_local", "inputs": {"key": "pressure", "amount": 1}},
		{"id": "finish", "label": "Open the lane", "cost": 4, "requires_objective_steps": [{"objective_id": "clear_exit", "step_id": "move_chair"}]},
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
						"branches": [{"id": "finish", "condition": {"type": "always"}, "outcome": "repaired"}],
					},
				],
			},
			"objectives": [{"id": "clear_exit", "label": "Keep the exit clear", "progress_label": "Exit lane", "steps": [{"id": "move_chair", "label": "Move the chair", "kind": "command", "command_id": "protect_exit"}], "outcomes": ["success", "failure", "ignore", "cancel"]}],
			"reentry_policy": {"partial": "resume", "terminal": "aftermath", "expired": "expired"},
			"expiry": {"boundary": "night_end", "after": 1, "policy": "ignore"},
			"cleanup": {"operations": [{"family": "scene_ops", "op": "remove", "owner_namespace": "scenario", "stable_object_id": "fixture_100"}]},
			"aftermath": {
				"repaired": {"label": "Repaired", "revisit_feedback": "The chair is back in place.", "scene_ops": [_operation_fixture("scene_ops", "set_state", 101)]},
				"broken": {"label": "Broken", "revisit_feedback": "A broken chair marks the fight.", "scene_ops": [_operation_fixture("scene_ops", "set_appearance", 102)]},
			},
			"mechanic_tags": ["room_route", "multi_step"],
			"sequence_signature": "route-protection-choice-aftermath",
			"owner_exceptions": [],
			"fact_subscriptions": ["event_result", "travel_departed"],
		},
	}


static func _operation_fixture(family: String, op_id: String, index: int) -> Dictionary:
	var stable_id := "fixture_%d" % index
	var operation := {"family": family, "op": op_id, "owner_namespace": "scenario", "stable_object_id": stable_id}
	match family:
		"scene_ops":
			if op_id in ["spawn", "replace"]:
				operation["object"] = {"label": "Fixture prop", "role": "obstacle", "anchor_id": "bar_floor_%d" % index, "bounds": {"w": 48, "h": 48}, "visible": true, "enabled": true}
			operation["anchor_id"] = "bar_floor_%d" % (index + 1)
			operation["state"] = "ready"
			operation["appearance"] = "scuffed"
		"interaction_ops":
			if op_id in ["add", "replace"]:
				operation["interaction"] = _interaction_record("scenario", stable_id, "Fixture interaction", true)
			if not ["add", "remove"].has(op_id):
				operation["mode"] = op_id
				operation["target_owner_namespace"] = "base"
				operation["target_stable_object_id"] = "fixture_target_%d" % index
			operation["enabled"] = false
			operation["disabled_reason"] = "Blocked by the fixture."
			operation["source_id"] = "fixture_source"
			operation["available_actions"] = [{"id": "fixture_action", "label": "Act"}]
		"actor_ops":
			if op_id == "spawn":
				operation["actor"] = {"label": "Fixture actor", "actor_id": "actor_fixture", "anchor_id": "bar_actor", "behavior": "idle"}
			operation["anchor_id"] = "bar_actor_%d" % index
			operation["route_id"] = "bar_route"
			operation["pose"] = "brace"
			operation["behavior"] = "watch"
		"transition_ops":
			operation["channel"] = "room"
			operation["cue_id"] = "fixture_cue"
			operation["message"] = "The room changes."
		"service_ops", "game_ops":
			if op_id in ["add", "replace"]:
				operation["object"] = {"id": stable_id, "label": "Fixture"}
			operation["enabled"] = false
			operation["modifier"] = {"tone": "tense"}
		"route_ops":
			operation["enabled"] = op_id != "close"
			operation["source_id"] = "alternate_exit"
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
		"available_actions": [{"id": "use", "label": "Use"}] if enabled else [],
		"input_actions": ["confirm"],
		"non_color_state": "open" if enabled else "closed",
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
