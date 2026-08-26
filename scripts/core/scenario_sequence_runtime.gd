class_name ScenarioSequenceRuntime
extends RefCounted

const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const SequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")

const STATE_SCHEMA_VERSION := 2
const COMMAND_SCHEMA_VERSION := 1
const FACT_SCHEMA_VERSION := 1
const FACT_PRODUCERS := ["game", "event", "service", "travel", "crew", "heat", "town", "sweep", "scenario"]
const FACT_TYPES := [
	"game_result", "event_result", "service_result", "travel_departed", "travel_arrived",
	"crew_changed", "crew_job_changed", "heat_changed", "heat_band_changed",
	"town_transition", "sweep_changed", "world_boundary", "scenario_command",
]
const FACT_TYPES_BY_PRODUCER := {
	"game": ["game_result"],
	"event": ["event_result"],
	"service": ["service_result"],
	"travel": ["travel_departed", "travel_arrived"],
	"crew": ["crew_changed", "crew_job_changed"],
	"heat": ["heat_changed", "heat_band_changed"],
	"town": ["town_transition"],
	"sweep": ["sweep_changed"],
	"scenario": ["world_boundary", "scenario_command"],
}
const FACT_REQUIRED_FIELDS := {
	"game_result": ["game_id", "action_id"],
	"event_result": ["event_id", "choice_id"],
	"service_result": ["kind", "service_id"],
	"travel_departed": ["source_id", "target_id", "travel_kind"],
	"travel_arrived": ["source_id", "target_id", "travel_kind"],
	"crew_changed": ["member_id", "change", "value"],
	"crew_job_changed": ["job_id", "status"],
	"heat_changed": ["previous", "current", "applied_delta", "source"],
	"heat_band_changed": ["previous_band", "current_band", "current", "source"],
	"town_transition": ["action_index", "weather", "day_type", "happening_ids"],
	"sweep_changed": ["action_index", "node_id", "segment_index", "active"],
	"world_boundary": ["amount", "action_index"],
	"scenario_command": ["command_id", "receipt_id"],
}
const PRODUCER_ORDER := {
	"game": 10, "event": 20, "service": 30, "travel": 40,
	"crew": 50, "heat": 60, "town": 70, "sweep": 80, "scenario": 90,
}
const STATUS_ACTIVE := "active"
const STATUS_AFTERMATH := "aftermath"
const STATUS_CLEANED := "cleaned"
const MAX_FACT_QUEUE := 128
const MAX_RECEIPTS := 256


static func initial_state(definition: Dictionary, node_id: String, seed_token: String = "") -> Dictionary:
	if not SequenceSchemaScript.is_sequence(definition):
		return {}
	var validation := SequenceSchemaScript.validate_definition(definition, OperationRegistryScript)
	if not validation.is_empty():
		return {"schema_version": STATE_SCHEMA_VERSION, "status": STATUS_CLEANED, "errors": validation}
	var scenario_id := str(definition.get("id", "")).strip_edges()
	var state := {
		"schema_version": STATE_SCHEMA_VERSION,
		"scenario_id": scenario_id,
		"node_id": node_id.strip_edges(),
		"definition_version": int(SequenceSchemaScript.sequence(definition).get("schema_version", STATE_SCHEMA_VERSION)),
		"seed_token": seed_token,
		"status": STATUS_ACTIVE,
		"phase_id": SequenceSchemaScript.initial_phase_id(definition),
		"phase_action_counter": 0,
		"boundary_serial": 0,
		"fact_serial_next": 1,
		"last_flushed_fact_serial": 0,
		"local_state": SequenceSchemaScript.default_local_state(definition),
		"objective_progress": _initial_objectives(definition),
		"resolved_branches": [],
		"resolved_outcomes": [],
		"semantic_state": {},
		"fact_queue": [],
		"fact_receipts": [],
		"command_receipts": [],
		"command_results": {},
		"command_fingerprints": {},
		"transition_receipts": [],
		"cleanup_receipts": [],
		"visit_receipts": [],
		"fact_fingerprints": {},
		"last_feedback": "",
		"performance_counters": {"transitions_prepared": 0, "facts_flushed": 0, "commands_applied": 0},
	}
	return _enter_phase(state, definition, str(state.get("phase_id", "")), "initial")


static func normalize_state(value: Variant, definition: Dictionary = {}) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source := value as Dictionary
	if int(source.get("schema_version", 0)) != STATE_SCHEMA_VERSION or str(source.get("scenario_id", "")).strip_edges().is_empty():
		return {}
	var state := {
		"schema_version": STATE_SCHEMA_VERSION,
		"scenario_id": str(source.get("scenario_id", "")).strip_edges(),
		"node_id": str(source.get("node_id", "")).strip_edges(),
		"definition_version": maxi(1, int(source.get("definition_version", STATE_SCHEMA_VERSION))),
		"seed_token": str(source.get("seed_token", "")),
		"status": str(source.get("status", STATUS_ACTIVE)),
		"phase_id": str(source.get("phase_id", "")).strip_edges(),
		"phase_action_counter": maxi(0, int(source.get("phase_action_counter", 0))),
		"boundary_serial": maxi(0, int(source.get("boundary_serial", 0))),
		"fact_serial_next": maxi(1, int(source.get("fact_serial_next", 1))),
		"last_flushed_fact_serial": maxi(0, int(source.get("last_flushed_fact_serial", 0))),
		"local_state": SequenceSchemaScript.normalize_local_state(definition, source.get("local_state", {})) if not definition.is_empty() else _dict(source.get("local_state", {})),
		"objective_progress": _normalize_objective_progress(source.get("objective_progress", {})),
		"resolved_branches": _bounded_strings(source.get("resolved_branches", []), MAX_RECEIPTS),
		"resolved_outcomes": _string_array(source.get("resolved_outcomes", [])),
		"semantic_state": _dict(source.get("semantic_state", {})),
		"fact_queue": _fact_array(source.get("fact_queue", [])),
		"fact_receipts": _string_array(source.get("fact_receipts", [])),
		"command_receipts": _string_array(source.get("command_receipts", [])),
		"command_results": _dict(source.get("command_results", {})),
		"command_fingerprints": _dict(source.get("command_fingerprints", {})),
		"transition_receipts": _string_array(source.get("transition_receipts", [])),
		"cleanup_receipts": _string_array(source.get("cleanup_receipts", [])),
		"visit_receipts": _string_array(source.get("visit_receipts", [])),
		"fact_fingerprints": _dict(source.get("fact_fingerprints", {})),
		"last_feedback": str(source.get("last_feedback", "")),
		"performance_counters": _normalize_counters(source.get("performance_counters", {})),
	}
	if not [STATUS_ACTIVE, STATUS_AFTERMATH, STATUS_CLEANED].has(str(state.get("status", ""))):
		state["status"] = STATUS_CLEANED
	if not definition.is_empty() and not SequenceSchemaScript.phase_ids(definition).has(str(state.get("phase_id", ""))) and str(state.get("status", "")) == STATUS_ACTIVE:
		state["status"] = STATUS_CLEANED
	return state


static func command(command_id: String, node_id: String, phase_id: String, idempotency_key: String, payload: Dictionary = {}, owner_namespace: String = "scenario", stable_object_id: String = "sequence") -> Dictionary:
	return {
		"schema_version": COMMAND_SCHEMA_VERSION,
		"command_id": command_id.strip_edges(),
		"node_id": node_id.strip_edges(),
		"expected_phase": phase_id.strip_edges(),
		"idempotency_key": idempotency_key.strip_edges(),
		"owner_namespace": owner_namespace.strip_edges(),
		"stable_object_id": stable_object_id.strip_edges(),
		"payload": payload.duplicate(true),
	}


static func apply_command(state_value: Dictionary, definition: Dictionary, command_value: Dictionary, context: Dictionary = {}) -> Dictionary:
	var state := normalize_state(state_value, definition)
	var receipt_id := str(command_value.get("idempotency_key", "")).strip_edges()
	var command_fingerprint := _fingerprint(command_value)
	if not receipt_id.is_empty() and _string_array(state.get("command_receipts", [])).has(receipt_id):
		if str(_dict(state.get("command_fingerprints", {})).get(receipt_id, "")) != command_fingerprint:
			return {"ok": false, "errors": ["scenario command idempotency_key was reused for a different command"], "state": state, "replayed": false}
		var cached := _dict(_dict(state.get("command_results", {})).get(receipt_id, {}))
		cached["replayed"] = true
		cached["state"] = state
		return cached
	var validation := _validate_command(state, definition, command_value, context)
	if _string_array(state.get("command_receipts", [])).size() >= MAX_RECEIPTS:
		validation.append("scenario command lifetime receipt limit reached")
	if not validation.is_empty():
		return {"ok": false, "errors": validation, "state": state, "replayed": false}
	var command_id := str(command_value.get("command_id", "")).strip_edges()
	var payload := _dict(command_value.get("payload", {}))
	var state_before := JSON.stringify(_canonical_variant(state))
	var handler_result := _apply_registered_handler(state, definition, command_value)
	state = _dict(handler_result.get("state", state))
	if not bool(handler_result.get("ok", false)):
		return {"ok": false, "errors": _array(handler_result.get("errors", [])), "state": state, "replayed": false}
	state = _complete_command_objective_steps(state, definition, command_id)
	var trigger := {"kind": "command", "command_id": command_id, "receipt_id": receipt_id, "payload": payload}
	state = _evaluate_branches(state, definition, trigger)
	var receipts := _string_array(state.get("command_receipts", []))
	receipts.append(receipt_id)
	state["command_receipts"] = receipts
	var counters := _normalize_counters(state.get("performance_counters", {}))
	counters["commands_applied"] = int(counters.get("commands_applied", 0)) + 1
	state["performance_counters"] = counters
	var result := {
		"ok": true,
		"replayed": false,
		"receipt_id": receipt_id,
		"command_id": command_id,
		"phase_id": str(state.get("phase_id", "")),
		"status": str(state.get("status", "")),
		"outcomes": _string_array(state.get("resolved_outcomes", [])),
		"changed": state_before != JSON.stringify(_canonical_variant(state)),
	}
	var results := _dict(state.get("command_results", {}))
	results[receipt_id] = result.duplicate(true)
	_trim_dictionary_to_receipts(results, receipts)
	state["command_results"] = results
	var fingerprints := _dict(state.get("command_fingerprints", {}))
	fingerprints[receipt_id] = command_fingerprint
	_trim_dictionary_to_receipts(fingerprints, receipts)
	state["command_fingerprints"] = fingerprints
	result["state"] = state
	return result


static func fact(fact_type: String, producer: String, node_id: String, fact_id: String, producer_serial: int, boundary_serial: int, payload: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": FACT_SCHEMA_VERSION,
		"fact_type": fact_type.strip_edges(),
		"producer": producer.strip_edges(),
		"node_id": node_id.strip_edges(),
		"fact_id": fact_id.strip_edges(),
		"producer_serial": maxi(0, producer_serial),
		"boundary_serial": maxi(0, boundary_serial),
		"payload": payload.duplicate(true),
	}


static func enqueue_fact(state_value: Dictionary, definition: Dictionary, fact_value: Dictionary) -> Dictionary:
	var state := normalize_state(state_value, definition)
	var errors := validate_fact(state, fact_value)
	var fact_id := str(fact_value.get("fact_id", "")).strip_edges()
	var fact_fingerprint := _fingerprint(fact_value)
	if _string_array(state.get("fact_receipts", [])).has(fact_id):
		if str(_dict(state.get("fact_fingerprints", {})).get(fact_id, "")) != fact_fingerprint:
			return {"ok": false, "duplicate": false, "state": state, "errors": ["scenario fact_id was reused for a different fact"]}
		return {"ok": true, "duplicate": true, "state": state, "errors": []}
	var queued_fact := _queued_fact(state, fact_id)
	if not queued_fact.is_empty():
		if _fingerprint(_without_ingress(queued_fact)) != fact_fingerprint:
			return {"ok": false, "duplicate": false, "state": state, "errors": ["scenario queued fact_id was reused for a different fact"]}
		return {"ok": true, "duplicate": true, "state": state, "errors": []}
	if not errors.is_empty():
		return {"ok": false, "duplicate": false, "state": state, "errors": errors}
	if _string_array(state.get("fact_receipts", [])).size() + _fact_array(state.get("fact_queue", [])).size() >= MAX_RECEIPTS:
		return {"ok": false, "duplicate": false, "state": state, "errors": ["scenario fact lifetime receipt limit reached"]}
	var queue := _fact_array(state.get("fact_queue", []))
	if queue.size() >= MAX_FACT_QUEUE:
		return {"ok": false, "duplicate": false, "state": state, "errors": ["scenario fact queue is full"]}
	var queued := fact_value.duplicate(true)
	queued["ingress_serial"] = int(state.get("fact_serial_next", 1))
	state["fact_serial_next"] = int(queued.get("ingress_serial", 0)) + 1
	queue.append(queued)
	state["fact_queue"] = queue
	return {"ok": true, "duplicate": false, "state": state, "errors": []}


static func validate_fact(state: Dictionary, fact_value: Dictionary) -> Array:
	var errors: Array = []
	if int(fact_value.get("schema_version", 0)) != FACT_SCHEMA_VERSION:
		errors.append("scenario fact schema_version is invalid")
	var producer := str(fact_value.get("producer", "")).strip_edges()
	var fact_type := str(fact_value.get("fact_type", "")).strip_edges()
	if not FACT_PRODUCERS.has(producer):
		errors.append("scenario fact producer is unregistered: %s" % producer)
	if not FACT_TYPES.has(fact_type):
		errors.append("scenario fact type is unregistered: %s" % fact_type)
	elif FACT_TYPES_BY_PRODUCER.has(producer) and not _array(FACT_TYPES_BY_PRODUCER.get(producer, [])).has(fact_type):
		errors.append("scenario fact type %s is not owned by producer %s" % [fact_type, producer])
	if str(fact_value.get("fact_id", "")).strip_edges().is_empty():
		errors.append("scenario fact requires fact_id")
	if str(fact_value.get("node_id", "")).strip_edges() != str(state.get("node_id", "")).strip_edges():
		errors.append("scenario fact targets the wrong node")
	if str(state.get("status", "")) != STATUS_ACTIVE:
		errors.append("scenario fact requires an active sequence")
	if int(fact_value.get("producer_serial", -1)) < 0 or int(fact_value.get("boundary_serial", -1)) < 0:
		errors.append("scenario fact serials must be non-negative")
	if typeof(fact_value.get("payload", {})) != TYPE_DICTIONARY:
		errors.append("scenario fact payload must be a dictionary")
	else:
		var payload := fact_value.get("payload", {}) as Dictionary
		for required_field_value in _array(FACT_REQUIRED_FIELDS.get(fact_type, [])):
			var required_field := str(required_field_value)
			if not payload.has(required_field):
				errors.append("scenario %s fact requires payload.%s" % [fact_type, required_field])
	return errors


static func flush_facts(state_value: Dictionary, definition: Dictionary, boundary_serial: int) -> Dictionary:
	var state := normalize_state(state_value, definition)
	if str(state.get("status", "")) == STATUS_CLEANED:
		return {"ok": false, "state": state, "processed": [], "errors": ["scenario is cleaned"]}
	var target_boundary := maxi(int(state.get("boundary_serial", 0)), boundary_serial)
	state["boundary_serial"] = target_boundary
	var ready: Array = []
	var pending: Array = []
	for fact_value in _fact_array(state.get("fact_queue", [])):
		if int((fact_value as Dictionary).get("boundary_serial", 0)) <= target_boundary:
			ready.append(fact_value)
		else:
			pending.append(fact_value)
	ready.sort_custom(Callable(ScenarioSequenceRuntime, "_sort_fact"))
	var processed: Array = []
	var errors: Array = []
	for fact_value in ready:
		var typed_fact := fact_value as Dictionary
		var fact_id := str(typed_fact.get("fact_id", ""))
		if _string_array(state.get("fact_receipts", [])).has(fact_id):
			continue
		var response := _apply_fact(state, definition, typed_fact)
		state = _dict(response.get("state", state))
		if not bool(response.get("ok", false)):
			errors.append_array(_array(response.get("errors", [])))
			continue
		var receipts := _string_array(state.get("fact_receipts", []))
		receipts.append(fact_id)
		state["fact_receipts"] = receipts
		var fingerprints := _dict(state.get("fact_fingerprints", {}))
		fingerprints[fact_id] = _fingerprint(_without_ingress(typed_fact))
		_trim_dictionary_to_receipts(fingerprints, receipts)
		state["fact_fingerprints"] = fingerprints
		state["last_flushed_fact_serial"] = maxi(int(state.get("last_flushed_fact_serial", 0)), int(typed_fact.get("ingress_serial", 0)))
		processed.append(fact_id)
	state["fact_queue"] = pending
	var counters := _normalize_counters(state.get("performance_counters", {}))
	counters["facts_flushed"] = int(counters.get("facts_flushed", 0)) + processed.size()
	state["performance_counters"] = counters
	return {"ok": errors.is_empty(), "state": state, "processed": processed, "errors": errors}


static func public_projection(state_value: Dictionary, definition: Dictionary = {}) -> Dictionary:
	var state := normalize_state(state_value, definition)
	if state.is_empty():
		return {}
	return {
		"scenario_id": str(state.get("scenario_id", "")),
		"node_id": str(state.get("node_id", "")),
		"phase_id": str(state.get("phase_id", "")),
		"status": str(state.get("status", "")),
		"objectives": _public_objectives(state, definition),
		"last_feedback": str(state.get("last_feedback", "")),
		"semantic_state": _dict(state.get("semantic_state", {})),
	}


static func _validate_command(state: Dictionary, definition: Dictionary, command_value: Dictionary, context: Dictionary) -> Array:
	var errors: Array = []
	if state.is_empty() or str(state.get("status", "")) != STATUS_ACTIVE:
		errors.append("scenario command requires an active sequence")
	if int(command_value.get("schema_version", 0)) != COMMAND_SCHEMA_VERSION:
		errors.append("scenario command schema_version is invalid")
	if str(command_value.get("node_id", "")).strip_edges() != str(state.get("node_id", "")).strip_edges():
		errors.append("scenario command targets the wrong node")
	if str(command_value.get("expected_phase", "")).strip_edges() != str(state.get("phase_id", "")).strip_edges():
		errors.append("scenario command expected_phase is stale")
	if str(command_value.get("idempotency_key", "")).strip_edges().is_empty():
		errors.append("scenario command requires idempotency_key")
	var owner_namespace := str(command_value.get("owner_namespace", "")).strip_edges()
	var stable_object_id := str(command_value.get("stable_object_id", "")).strip_edges()
	if not OperationRegistryScript.OWNER_NAMESPACES.has(owner_namespace) or not _valid_id(stable_object_id):
		errors.append("scenario command requires interaction identity")
	var command_id := str(command_value.get("command_id", "")).strip_edges()
	if command_id.is_empty() or not _phase_command_ids(definition, str(state.get("phase_id", ""))).has(command_id):
		errors.append("scenario command is unavailable in the current phase")
	if typeof(command_value.get("payload", {})) != TYPE_DICTIONARY:
		errors.append("scenario command payload must be a dictionary")
	var descriptor := _command_descriptor(state, definition, owner_namespace, stable_object_id, command_id)
	if bool(descriptor.get("identity_present", false)):
		if not bool(descriptor.get("interaction_enabled", false)):
			errors.append("scenario command interaction is disabled")
		elif not bool(descriptor.get("action_present", false)):
			errors.append("scenario command is unavailable on the addressed interaction")
		else:
			errors.append_array(_command_precondition_errors(state, _dict(descriptor.get("action", {}))))
	var cost := maxi(0, int(_dict(descriptor.get("action", {})).get("cost", 0)))
	if cost > maxi(0, int(context.get("available_funds", 0))):
		errors.append("scenario command cost is not payable")
	return errors


static func _apply_registered_handler(state: Dictionary, definition: Dictionary, command_value: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	var command_id := str(command_value.get("command_id", "")).strip_edges()
	var descriptor := _command_descriptor(
		state,
		definition,
		str(command_value.get("owner_namespace", "")),
		str(command_value.get("stable_object_id", "")),
		command_id
	)
	var action := _dict(descriptor.get("action", {}))
	var handler_id := str(action.get("handler", "")).strip_edges()
	if handler_id.is_empty():
		return {"ok": true, "state": next}
	if not OperationRegistryScript.registered_handlers().has(handler_id):
		return {"ok": false, "state": state, "errors": ["scenario command handler is unregistered: %s" % handler_id]}
	return _run_handler(next, definition, handler_id, _dict(action.get("inputs", {})), {"command_id": command_id, "payload": _dict(command_value.get("payload", {}))})


static func _run_handler(state: Dictionary, definition: Dictionary, handler_id: String, inputs: Dictionary, trigger: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	var local := _dict(next.get("local_state", {}))
	match handler_id:
		"set_local":
			local[str(inputs.get("key", ""))] = inputs.get("value")
			next["local_state"] = SequenceSchemaScript.normalize_local_state(definition, local)
		"increment_local":
			var key := str(inputs.get("key", ""))
			local[key] = int(local.get(key, 0)) + int(inputs.get("amount", 1))
			next["local_state"] = SequenceSchemaScript.normalize_local_state(definition, local)
		"complete_objective_step":
			next = _complete_objective_step(next, str(inputs.get("objective_id", "")), str(inputs.get("step_id", "")))
		"record_outcome":
			var outcomes := _string_array(next.get("resolved_outcomes", []))
			var outcome := str(inputs.get("outcome", "")).strip_edges()
			if not outcome.is_empty() and not outcomes.has(outcome): outcomes.append(outcome)
			next["resolved_outcomes"] = outcomes
		"publish_feedback":
			next["last_feedback"] = str(inputs.get("message", ""))
		"request_cleanup":
			next = _apply_cleanup(next, definition, str(inputs.get("reason", "requested")))
			next["status"] = STATUS_CLEANED
		"event_bridge":
			# The bridge records correlation only. Event consequences remain owned by
			# EventModule and arrive as a later typed event_result fact.
			next["last_feedback"] = str(inputs.get("message", trigger.get("fact_type", "Event resolved.")))
	return {"ok": true, "state": next}


static func _apply_fact(state: Dictionary, definition: Dictionary, fact_value: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	var fact_type := str(fact_value.get("fact_type", ""))
	var payload := _dict(fact_value.get("payload", {}))
	for subscription_value in _array(SequenceSchemaScript.sequence(definition).get("fact_subscriptions", [])):
		var subscription := _dict(subscription_value)
		if subscription.is_empty():
			continue
		if str(subscription.get("fact_type", "")) != fact_type:
			continue
		var inputs := _dict(subscription.get("inputs", {}))
		var payload_key := str(inputs.get("value_from_payload", "")).strip_edges()
		if not payload_key.is_empty():
			inputs["value"] = payload.get(payload_key)
		var handler_result := _run_handler(next, definition, str(subscription.get("handler", "")), inputs, fact_value)
		if not bool(handler_result.get("ok", false)):
			return handler_result
		next = _dict(handler_result.get("state", next))
	for objective_value in _array(SequenceSchemaScript.sequence(definition).get("objectives", [])):
		var objective := _dict(objective_value)
		for step_value in _array(objective.get("steps", [])):
			var step := _dict(step_value)
			if str(step.get("kind", "")) == "fact" and str(step.get("fact_type", "")) == fact_type:
				next = _complete_objective_step(next, str(objective.get("id", "")), str(step.get("id", "")))
	if fact_type == "world_boundary":
		next["phase_action_counter"] = int(next.get("phase_action_counter", 0)) + maxi(1, int(payload.get("amount", 1)))
	var trigger := {"kind": "fact", "fact_type": fact_type, "fact_id": str(fact_value.get("fact_id", "")), "payload": payload}
	next = _evaluate_branches(next, definition, trigger)
	return {"ok": true, "state": next}


static func _evaluate_branches(state: Dictionary, definition: Dictionary, trigger: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != STATUS_ACTIVE:
		return state
	var current := SequenceSchemaScript.phase(definition, str(state.get("phase_id", "")))
	for branch_value in _array(current.get("branches", [])):
		var branch := _dict(branch_value)
		if not _condition_matches(_dict(branch.get("condition", {})), state, trigger):
			continue
		var branch_id := "%s:%s" % [str(state.get("phase_id", "")), str(branch.get("id", ""))]
		var resolved := _string_array(state.get("resolved_branches", []))
		if resolved.has(branch_id):
			continue
		resolved.append(branch_id)
		state["resolved_branches"] = resolved
		var target := str(branch.get("next_phase", "")).strip_edges()
		if not target.is_empty():
			return _enter_phase(state, definition, target, branch_id)
		var outcome := str(branch.get("outcome", "")).strip_edges()
		return _resolve_outcome(state, definition, outcome, branch_id)
	# Compatibility lifecycle is deliberately secondary to graph branches.
	var threshold := maxi(0, int(current.get("advance_after_actions", 0)))
	if str(trigger.get("fact_type", "")) == "world_boundary" and threshold > 0 and int(state.get("phase_action_counter", 0)) >= threshold:
		var ids := SequenceSchemaScript.phase_ids(definition)
		var index := ids.find(str(state.get("phase_id", "")))
		if index >= 0 and index + 1 < ids.size():
			return _enter_phase(state, definition, str(ids[index + 1]), "ordered_compat")
	return state


static func _condition_matches(condition: Dictionary, state: Dictionary, trigger: Dictionary) -> bool:
	match str(condition.get("type", "")):
		"always": return true
		"command": return str(trigger.get("kind", "")) == "command" and str(trigger.get("command_id", "")) == str(condition.get("command_id", ""))
		"fact": return str(trigger.get("kind", "")) == "fact" and str(trigger.get("fact_type", "")) == str(condition.get("fact_type", ""))
		"local_equals": return _dict(state.get("local_state", {})).get(str(condition.get("key", ""))) == condition.get("value")
		"local_min": return int(_dict(state.get("local_state", {})).get(str(condition.get("key", "")), 0)) >= int(condition.get("value", 0))
		"objective": return _objective_step_complete(state, str(condition.get("objective_id", "")), str(condition.get("step_id", "")))
		"outcome": return _string_array(state.get("resolved_outcomes", [])).has(str(condition.get("outcome", "")))
		"receipt": return _string_array(state.get("command_receipts", [])).has(str(condition.get("receipt_id", ""))) or _string_array(state.get("fact_receipts", [])).has(str(condition.get("receipt_id", "")))
	return false


static func _enter_phase(state: Dictionary, definition: Dictionary, phase_id: String, source_receipt: String) -> Dictionary:
	var next := state.duplicate(true)
	var phase_data := SequenceSchemaScript.phase(definition, phase_id)
	if phase_data.is_empty():
		next["status"] = STATUS_CLEANED
		return next
	next["phase_id"] = phase_id
	next["phase_action_counter"] = 0
	next["last_feedback"] = str(phase_data.get("arrival_feedback", ""))
	var semantic := _dict(next.get("semantic_state", {}))
	var transition_receipts := _string_array(next.get("transition_receipts", []))
	var phase_receipt := "%s:%s:phase:%s:%s" % [str(next.get("scenario_id", "")), str(next.get("node_id", "")), phase_id, source_receipt]
	if transition_receipts.has(phase_receipt):
		return next
	for family in ["scene_ops", "interaction_ops", "actor_ops", "transition_ops"]:
		var applied := OperationRegistryScript.apply_operations(semantic, family, _array(phase_data.get(family, [])), phase_receipt)
		if not bool(applied.get("ok", false)):
			next["status"] = STATUS_CLEANED
			next["last_feedback"] = "This room sequence closed safely."
			return next
		semantic = _dict(applied.get("state", semantic))
	transition_receipts.append(phase_receipt)
	next["transition_receipts"] = transition_receipts
	next["semantic_state"] = semantic
	var counters := _normalize_counters(next.get("performance_counters", {}))
	counters["transitions_prepared"] = int(counters.get("transitions_prepared", 0)) + 1
	next["performance_counters"] = counters
	return next


static func _resolve_outcome(state: Dictionary, definition: Dictionary, outcome: String, source_receipt: String) -> Dictionary:
	var next := state.duplicate(true)
	if outcome.is_empty():
		return next
	var outcomes := _string_array(next.get("resolved_outcomes", []))
	if not outcomes.has(outcome): outcomes.append(outcome)
	next["resolved_outcomes"] = outcomes
	next = _apply_cleanup(next, definition, "terminal:%s" % source_receipt)
	var aftermath := _dict(_dict(SequenceSchemaScript.sequence(definition).get("aftermath", {})).get(outcome, {}))
	var semantic := _dict(next.get("semantic_state", {}))
	var aftermath_scope := "%s:%s:aftermath:%s" % [str(next.get("scenario_id", "")), str(next.get("node_id", "")), outcome]
	for family in ["scene_ops", "interaction_ops", "actor_ops", "service_ops", "game_ops", "route_ops"]:
		var applied := OperationRegistryScript.apply_operations(semantic, family, _array(aftermath.get(family, [])), aftermath_scope)
		if not bool(applied.get("ok", false)):
			next["status"] = STATUS_CLEANED
			return next
		semantic = _dict(applied.get("state", semantic))
	next["semantic_state"] = semantic
	next["last_feedback"] = str(aftermath.get("revisit_feedback", aftermath.get("label", "")))
	next["status"] = STATUS_AFTERMATH
	return next


static func _apply_cleanup(state: Dictionary, definition: Dictionary, reason: String) -> Dictionary:
	var next := state.duplicate(true)
	var receipt_id := "%s:%s:cleanup:%s" % [str(next.get("scenario_id", "")), str(next.get("node_id", "")), reason]
	var receipts := _string_array(next.get("cleanup_receipts", []))
	if receipts.has(receipt_id):
		return next
	var semantic := _dict(next.get("semantic_state", {}))
	for operation_value in _array(_dict(SequenceSchemaScript.sequence(definition).get("cleanup", {})).get("operations", [])):
		var operation := _dict(operation_value)
		var family := str(operation.get("family", ""))
		var applied := OperationRegistryScript.apply_operations(semantic, family, [operation], receipt_id)
		if bool(applied.get("ok", false)):
			semantic = _dict(applied.get("state", semantic))
	next["semantic_state"] = semantic
	receipts.append(receipt_id)
	next["cleanup_receipts"] = receipts
	return next


static func _complete_command_objective_steps(state: Dictionary, definition: Dictionary, command_id: String) -> Dictionary:
	var next := state
	for objective_value in _array(SequenceSchemaScript.sequence(definition).get("objectives", [])):
		var objective := _dict(objective_value)
		for step_value in _array(objective.get("steps", [])):
			var step := _dict(step_value)
			if str(step.get("kind", "")) == "command" and str(step.get("command_id", "")) == command_id:
				next = _complete_objective_step(next, str(objective.get("id", "")), str(step.get("id", "")))
	return next


static func _complete_objective_step(state: Dictionary, objective_id: String, step_id: String) -> Dictionary:
	var next := state.duplicate(true)
	var progress := _normalize_objective_progress(next.get("objective_progress", {}))
	var objective := _dict(progress.get(objective_id, {}))
	var completed := _string_array(objective.get("completed_steps", []))
	if not step_id.is_empty() and not completed.has(step_id): completed.append(step_id)
	objective["completed_steps"] = completed
	progress[objective_id] = objective
	next["objective_progress"] = progress
	return next


static func _objective_step_complete(state: Dictionary, objective_id: String, step_id: String) -> bool:
	return _string_array(_dict(_dict(state.get("objective_progress", {})).get(objective_id, {})).get("completed_steps", [])).has(step_id)


static func _initial_objectives(definition: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for objective_value in _array(SequenceSchemaScript.sequence(definition).get("objectives", [])):
		var objective := _dict(objective_value)
		result[str(objective.get("id", ""))] = {"completed_steps": [], "outcome": ""}
	return result


static func _normalize_objective_progress(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY: return result
	var keys := (value as Dictionary).keys()
	keys.sort()
	for key_value in keys:
		var objective := _dict((value as Dictionary).get(key_value, {}))
		result[str(key_value)] = {"completed_steps": _string_array(objective.get("completed_steps", [])), "outcome": str(objective.get("outcome", ""))}
	return result


static func _phase_command_ids(definition: Dictionary, phase_id: String) -> Array:
	var result: Array = []
	var phase_data := SequenceSchemaScript.phase(definition, phase_id)
	for branch_value in _array(phase_data.get("branches", [])):
		var condition := _dict(_dict(branch_value).get("condition", {}))
		if str(condition.get("type", "")) == "command":
			_append_unique(result, str(condition.get("command_id", "")))
	for objective_value in _array(SequenceSchemaScript.sequence(definition).get("objectives", [])):
		var objective := _dict(objective_value)
		if not _string_array(phase_data.get("objective_ids", [])).has(str(objective.get("id", ""))): continue
		for step_value in _array(objective.get("steps", [])):
			var step := _dict(step_value)
			if str(step.get("kind", "")) == "command": _append_unique(result, str(step.get("command_id", "")))
	for interaction_value in _dict(_dict(state_semantics_for_definition(definition, phase_id)).get("interactions", {})).values():
		for action_value in _array(_dict(interaction_value).get("available_actions", [])):
			_append_unique(result, str(_dict(action_value).get("id", "")))
	return result


static func state_semantics_for_definition(definition: Dictionary, phase_id: String) -> Dictionary:
	var semantic: Dictionary = {}
	var phase_data := SequenceSchemaScript.phase(definition, phase_id)
	for family in ["scene_ops", "interaction_ops", "actor_ops", "transition_ops"]:
		var applied := OperationRegistryScript.apply_operations(semantic, family, _array(phase_data.get(family, [])), "definition:preview:phase:%s" % phase_id)
		semantic = _dict(applied.get("state", semantic))
	return semantic


static func _public_objectives(state: Dictionary, definition: Dictionary) -> Array:
	var result: Array = []
	var progress := _dict(state.get("objective_progress", {}))
	for objective_value in _array(SequenceSchemaScript.sequence(definition).get("objectives", [])):
		var objective := _dict(objective_value)
		var objective_id := str(objective.get("id", ""))
		var completed := _string_array(_dict(progress.get(objective_id, {})).get("completed_steps", []))
		result.append({"id": objective_id, "label": str(objective.get("label", "")), "progress_label": str(objective.get("progress_label", "")), "completed": completed.size(), "total": _array(objective.get("steps", [])).size(), "outcome": str(_dict(progress.get(objective_id, {})).get("outcome", ""))})
	return result


static func _queued_fact(state: Dictionary, fact_id: String) -> Dictionary:
	for fact_value in _fact_array(state.get("fact_queue", [])):
		if str((fact_value as Dictionary).get("fact_id", "")) == fact_id:
			return (fact_value as Dictionary).duplicate(true)
	return {}


static func _sort_fact(a: Variant, b: Variant) -> bool:
	var left := a as Dictionary
	var right := b as Dictionary
	for key in ["boundary_serial", "producer_priority", "producer_serial", "ingress_serial"]:
		var left_value := int(PRODUCER_ORDER.get(str(left.get("producer", "")), 999)) if key == "producer_priority" else int(left.get(key, 0))
		var right_value := int(PRODUCER_ORDER.get(str(right.get("producer", "")), 999)) if key == "producer_priority" else int(right.get(key, 0))
		if left_value != right_value: return left_value < right_value
	return str(left.get("fact_id", "")) < str(right.get("fact_id", ""))


static func _trim_dictionary_to_receipts(values: Dictionary, receipts: Array) -> void:
	var keep: Dictionary = {}
	for receipt_value in receipts:
		keep[str(receipt_value)] = true
	for key_value in values.keys():
		if not keep.has(str(key_value)):
			values.erase(key_value)


static func _command_descriptor(state: Dictionary, definition: Dictionary, owner_namespace: String, stable_object_id: String, command_id: String) -> Dictionary:
	var identity := OperationRegistryScript.identity(owner_namespace, stable_object_id)
	var interactions := _dict(_dict(state.get("semantic_state", {})).get("interactions", {}))
	var interaction := _dict(interactions.get(identity, {}))
	if interaction.is_empty():
		return {"identity_present": false, "interaction_enabled": false, "action_present": false, "action": {}}
	for action_value in _array(interaction.get("available_actions", [])):
		var action := _dict(action_value)
		if str(action.get("id", "")) == command_id:
			return {"identity_present": true, "interaction_enabled": bool(interaction.get("enabled", false)), "action_present": true, "action": action}
	return {"identity_present": true, "interaction_enabled": bool(interaction.get("enabled", false)), "action_present": false, "action": {}}


static func _command_precondition_errors(state: Dictionary, action: Dictionary) -> Array:
	var errors: Array = []
	for requirement_value in _array(action.get("requires_objective_steps", [])):
		var requirement := _dict(requirement_value)
		if not _objective_step_complete(state, str(requirement.get("objective_id", "")), str(requirement.get("step_id", ""))):
			errors.append("scenario command objective precondition is not complete")
	for requirement_value in _array(action.get("requires_local", [])):
		var requirement := _dict(requirement_value)
		if _dict(state.get("local_state", {})).get(str(requirement.get("key", ""))) != requirement.get("equals"):
			errors.append("scenario command local-state precondition is not met")
	return errors


static func _without_ingress(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	result.erase("ingress_serial")
	return result


static func _fingerprint(value: Variant) -> String:
	return JSON.stringify(_canonical_variant(value))


static func _valid_id(value: String) -> bool:
	var text := value.strip_edges()
	if text.is_empty():
		return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and code != 95 and code != 45 and code != 58:
			return false
	return true


static func _normalize_counters(value: Variant) -> Dictionary:
	var source := _dict(value)
	return {"transitions_prepared": maxi(0, int(source.get("transitions_prepared", 0))), "facts_flushed": maxi(0, int(source.get("facts_flushed", 0))), "commands_applied": maxi(0, int(source.get("commands_applied", 0)))}


static func _fact_array(value: Variant) -> Array:
	var result: Array = []
	for fact_value in _array(value):
		if typeof(fact_value) == TYPE_DICTIONARY: result.append((fact_value as Dictionary).duplicate(true))
	return result


static func _bounded_strings(value: Variant, limit: int) -> Array:
	var result := _string_array(value)
	if result.size() > limit: result = result.slice(result.size() - limit, result.size())
	return result


static func _append_unique(values: Array, value: String) -> void:
	var clean := value.strip_edges()
	if not clean.is_empty() and not values.has(clean): values.append(clean)


static func _canonical_variant(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		var keys := (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key_value in keys: result[str(key_value)] = _canonical_variant((value as Dictionary).get(key_value))
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for item in value as Array: result.append(_canonical_variant(item))
		return result
	return value


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY: return result
	for item_value in value as Array:
		var item := str(item_value).strip_edges()
		if not item.is_empty() and not result.has(item): result.append(item)
	return result


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
