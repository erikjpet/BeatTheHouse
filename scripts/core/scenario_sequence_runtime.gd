class_name ScenarioSequenceRuntime
extends RefCounted

const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const SequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")

const STATE_SCHEMA_VERSION := 4
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
const FACT_FIELD_TYPES := {
	"game_result": {"game_id": TYPE_STRING, "action_id": TYPE_STRING, "won": TYPE_BOOL, "ended": TYPE_BOOL, "bankroll_delta": TYPE_INT, "chips_delta": TYPE_INT, "applied_heat_delta": TYPE_INT},
	"event_result": {"event_id": TYPE_STRING, "choice_id": TYPE_STRING, "resolution_id": TYPE_STRING, "resolved": TYPE_BOOL, "ok": TYPE_BOOL},
	"service_result": {"kind": TYPE_STRING, "service_id": TYPE_STRING, "ok": TYPE_BOOL, "action_id": TYPE_STRING},
	"travel_departed": {"source_id": TYPE_STRING, "target_id": TYPE_STRING, "travel_kind": TYPE_STRING},
	"travel_arrived": {"source_id": TYPE_STRING, "target_id": TYPE_STRING, "travel_kind": TYPE_STRING},
	"crew_changed": {"member_id": TYPE_STRING, "change": TYPE_STRING, "value": -1},
	"crew_job_changed": {"job_id": TYPE_STRING, "definition_id": TYPE_STRING, "member_id": TYPE_STRING, "status": TYPE_STRING, "outcome": TYPE_STRING},
	"heat_changed": {"previous": TYPE_INT, "current": TYPE_INT, "applied_delta": TYPE_INT, "source": TYPE_STRING},
	"heat_band_changed": {"previous_band": TYPE_STRING, "current_band": TYPE_STRING, "current": TYPE_INT, "source": TYPE_STRING},
	"town_transition": {"action_index": TYPE_INT, "weather": TYPE_STRING, "day_type": TYPE_STRING, "happening_ids": TYPE_ARRAY},
	"sweep_changed": {"action_index": TYPE_INT, "node_id": TYPE_STRING, "segment_index": TYPE_INT, "active": TYPE_BOOL},
	"world_boundary": {"amount": TYPE_INT, "action_index": TYPE_INT},
	"scenario_command": {"command_id": TYPE_STRING, "receipt_id": TYPE_STRING},
}
const FACT_PAYLOAD_TYPES := {
	"game_result": {"game_id": "string", "action_id": "string", "won": "bool", "ended": "bool", "bankroll_delta": "int", "chips_delta": "int", "applied_heat_delta": "int"},
	"event_result": {"event_id": "string", "choice_id": "string", "resolution_id": "string", "resolved": "bool", "ok": "bool"},
	"service_result": {"kind": "string", "service_id": "string", "ok": "bool", "action_id": "string"},
	"travel_departed": {"source_id": "string", "target_id": "string", "travel_kind": "string"},
	"travel_arrived": {"source_id": "string", "target_id": "string", "travel_kind": "string"},
	"crew_changed": {"member_id": "string", "change": "string", "value": "dynamic"},
	"crew_job_changed": {"job_id": "string", "status": "string", "definition_id": "string", "member_id": "string", "outcome": "string"},
	"heat_changed": {"previous": "int", "current": "int", "applied_delta": "int", "source": "string"},
	"heat_band_changed": {"previous_band": "string", "current_band": "string", "current": "int", "source": "string"},
	"town_transition": {"action_index": "int", "weather": "string", "day_type": "string", "happening_ids": "string_array"},
	"sweep_changed": {"action_index": "int", "node_id": "string", "segment_index": "int", "active": "bool"},
	"world_boundary": {"amount": "int", "action_index": "int"},
	"scenario_command": {"command_id": "string", "receipt_id": "string"},
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
const COMMAND_RESULT_KEYS := ["ok", "replayed", "receipt_id", "command_id", "phase_id", "status", "boundary_serial", "outcomes", "changed", "cost", "state"]


static func initial_state(definition: Dictionary, node_id: String, seed_token: String = "", host_semantics: Dictionary = {}) -> Dictionary:
	if not SequenceSchemaScript.is_sequence(definition):
		return {}
	var target_inventory := _dict(host_semantics.get("target_inventory", {}))
	target_inventory["event_choices"] = _dict(host_semantics.get("event_choices", target_inventory.get("event_choices", {})))
	var validation := SequenceSchemaScript.validate_definition(definition, OperationRegistryScript, target_inventory)
	validation.append_array(_array(host_semantics.get("inventory_errors", [])))
	if not validation.is_empty():
		return {"schema_version": STATE_SCHEMA_VERSION, "status": STATUS_CLEANED, "errors": validation}
	var scenario_id := str(definition.get("id", "")).strip_edges()
	var clean_node_id := node_id.strip_edges()
	if not _valid_persisted_text(scenario_id) or not _valid_persisted_text(clean_node_id) or seed_token.length() > OperationRegistryScript.MAX_VARIANT_TEXT:
		return {"schema_version": STATE_SCHEMA_VERSION, "status": STATUS_CLEANED, "errors": ["scenario runtime identity/seed exceeds the persisted text boundary"]}
	var state := {
		"schema_version": STATE_SCHEMA_VERSION,
		"scenario_id": scenario_id,
		"node_id": clean_node_id,
		"definition_version": int(SequenceSchemaScript.sequence(definition).get("schema_version", STATE_SCHEMA_VERSION)),
		"seed_token": seed_token,
		"status": STATUS_ACTIVE,
		"phase_id": SequenceSchemaScript.initial_phase_id(definition),
		"phase_action_counter": 0,
		"phase_boundary_grace": 0,
		"boundary_serial": 0,
		"fact_serial_next": 1,
		"last_flushed_fact_serial": 0,
		"local_state": SequenceSchemaScript.default_local_state(definition),
		"objective_progress": _initial_objectives(definition),
		"resolved_branches": [],
		"resolved_outcomes": [],
		"semantic_state": {
			"creation_owner_namespaces": _string_array(host_semantics.get("creation_owner_namespaces", ["scenario"])),
			"declared_targets": SequenceSchemaScript.verified_declared_targets(definition, target_inventory),
			"target_inventory": target_inventory.duplicate(true),
			"base_interactions": _array(host_semantics.get("base_interactions", [])),
			"inventory_schema_version": int(host_semantics.get("inventory_schema_version", 0)),
			"inventory_digest": str(host_semantics.get("inventory_digest", "")),
			"event_choices": _dict(host_semantics.get("event_choices", {})),
		},
		"fact_queue": [],
		"fact_receipts": [],
		"fact_receipt_records": [],
		"fact_flush_batch_records": [],
		"command_receipts": [],
		"command_receipt_records": [],
		"command_results": {},
		"command_fingerprints": {},
		"branch_resolution_records": [],
		"transition_receipts": [],
		"transition_delivery_receipts": [],
		"active_stages": [],
		"event_request_queue": [],
		"event_request_history": [],
		"event_request_delivery_receipts": [],
		"transition_receipt_records": [],
		"cleanup_receipts": [],
		"cleanup_receipt_records": [],
		"cleanup_fingerprints": {},
		"cleanup_content_fingerprint": "",
		"event_correlations": [],
		"visit_receipts": [],
		"visit_receipt_records": [],
		"expiry_receipts": [],
		"expiry_counts": {},
		"expiry_boundary_records": [],
		"expiry_progress": 0,
		"expired": false,
		"event_choice_receipts": [],
		"migration_receipts": [],
		"fact_fingerprints": {},
		"last_feedback": "",
		"runtime_errors": [],
		"performance_counters": {"transitions_prepared": 0, "facts_flushed": 0, "commands_applied": 0},
	}
	var entered := _enter_phase(state, definition, str(state.get("phase_id", "")), "initial", {"kind": "initial"})
	if not bool(entered.get("ok", false)):
		state["status"] = STATUS_CLEANED
		state["errors"] = _array(entered.get("errors", []))
		state["last_feedback"] = "This room sequence could not start safely."
		return state
	return _dict(entered.get("state", state))


static func normalize_state(value: Variant, definition: Dictionary = {}, trusted_host_semantics: Dictionary = {}) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	if not OperationRegistryScript.validate_bounded_variant("scenario runtime state", value).is_empty():
		return {}
	var source := value as Dictionary
	var source_version := int(source.get("schema_version", 0))
	if source_version <= 0 or source_version > STATE_SCHEMA_VERSION or str(source.get("scenario_id", "")).strip_edges().is_empty():
		return {}
	# Persisted causal authority must never become valid by normalization dropping
	# its oldest entries. Reject every bounded receipt/journal/queue collection in
	# its raw saved shape before any filtering, migration, or compatibility trim.
	if not _persisted_collections_within_limits(source):
		return {}
	var semantic_source := _dict(source.get("semantic_state", {})).duplicate(true)
	if not trusted_host_semantics.is_empty():
		semantic_source["event_choices"] = _dict(trusted_host_semantics.get("event_choices", {}))
		semantic_source["creation_owner_namespaces"] = _string_array(trusted_host_semantics.get("creation_owner_namespaces", ["scenario"]))
	var state := {
		"schema_version": STATE_SCHEMA_VERSION,
		"scenario_id": str(source.get("scenario_id", "")).strip_edges(),
		"node_id": str(source.get("node_id", "")).strip_edges(),
		"definition_version": maxi(1, int(source.get("definition_version", STATE_SCHEMA_VERSION))),
		"seed_token": str(source.get("seed_token", "")),
		"status": str(source.get("status", STATUS_ACTIVE)),
		"phase_id": str(source.get("phase_id", "")).strip_edges(),
		"phase_action_counter": maxi(0, int(source.get("phase_action_counter", 0))),
		"phase_boundary_grace": clampi(int(source.get("phase_boundary_grace", 0)), 0, 1),
		"boundary_serial": maxi(0, int(source.get("boundary_serial", 0))),
		"fact_serial_next": maxi(1, int(source.get("fact_serial_next", 1))),
		"last_flushed_fact_serial": maxi(0, int(source.get("last_flushed_fact_serial", 0))),
		"local_state": SequenceSchemaScript.normalize_local_state(definition, source.get("local_state", {})) if not definition.is_empty() else _dict(source.get("local_state", {})),
		"objective_progress": _normalize_objective_progress(source.get("objective_progress", {})),
		"resolved_branches": _bounded_strings(source.get("resolved_branches", []), MAX_RECEIPTS),
		"resolved_outcomes": _bounded_strings(source.get("resolved_outcomes", []), MAX_RECEIPTS),
		"semantic_state": OperationRegistryScript.normalize_semantic_state(semantic_source),
		"fact_queue": [],
		"fact_receipts": _bounded_strings(source.get("fact_receipts", []), MAX_RECEIPTS),
		"fact_receipt_records": _normalized_fact_receipt_records(source.get("fact_receipt_records", [])),
		"fact_flush_batch_records": _normalized_integer_record_fields(source.get("fact_flush_batch_records", []), ["batch_ordinal", "requested_boundary_serial", "effective_boundary_serial", "first_cause_ordinal"]),
		"command_receipts": _bounded_strings(source.get("command_receipts", []), MAX_RECEIPTS),
		"command_receipt_records": _normalized_command_receipt_records(source.get("command_receipt_records", [])),
		"command_results": {},
		"command_fingerprints": _normalized_receipt_fingerprints(source.get("command_fingerprints", {}), source.get("command_receipts", [])),
		"branch_resolution_records": _normalized_integer_record_fields(source.get("branch_resolution_records", []), ["boundary_ordinal"]),
		"transition_receipts": _bounded_strings(source.get("transition_receipts", []), MAX_RECEIPTS),
		"transition_delivery_receipts": _bounded_strings(source.get("transition_delivery_receipts", []), MAX_RECEIPTS),
		"active_stages": _bounded_records(source.get("active_stages", []), MAX_RECEIPTS),
		"event_request_queue": _bounded_records(source.get("event_request_queue", []), MAX_RECEIPTS),
		"event_request_history": _bounded_records(source.get("event_request_history", []), MAX_RECEIPTS),
		"event_request_delivery_receipts": _bounded_strings(source.get("event_request_delivery_receipts", []), MAX_RECEIPTS),
		"transition_receipt_records": _bounded_records(source.get("transition_receipt_records", []), MAX_RECEIPTS),
		"cleanup_receipts": _bounded_strings(source.get("cleanup_receipts", []), MAX_RECEIPTS),
		"cleanup_receipt_records": _bounded_records(source.get("cleanup_receipt_records", []), MAX_RECEIPTS),
		"cleanup_fingerprints": _normalized_cleanup_fingerprints(source.get("cleanup_fingerprints", {}), source.get("cleanup_receipts", [])),
		"cleanup_content_fingerprint": str(source.get("cleanup_content_fingerprint", "")),
		"event_correlations": [],
		"visit_receipts": _bounded_strings(source.get("visit_receipts", []), MAX_RECEIPTS),
		"visit_receipt_records": _normalized_integer_record_fields(source.get("visit_receipt_records", []), ["cause_ordinal"]),
		"expiry_receipts": _bounded_strings(source.get("expiry_receipts", []), MAX_RECEIPTS),
		"expiry_counts": _normalize_expiry_counts(source.get("expiry_counts", {})),
		"event_choice_receipts": _bounded_strings(source.get("event_choice_receipts", []), MAX_RECEIPTS),
		"migration_receipts": _bounded_strings(source.get("migration_receipts", []), MAX_RECEIPTS),
		"expiry_boundary_records": _bounded_records(source.get("expiry_boundary_records", []), MAX_RECEIPTS),
		"expiry_progress": maxi(0, int(source.get("expiry_progress", 0))),
		"expired": bool(source.get("expired", false)),
		"fact_fingerprints": _normalized_receipt_fingerprints(source.get("fact_fingerprints", {}), source.get("fact_receipts", [])),
		"last_feedback": str(source.get("last_feedback", "")),
		"runtime_errors": _bounded_strings(source.get("runtime_errors", []), 32),
		"performance_counters": _normalize_counters(source.get("performance_counters", {})),
	}
	state["command_results"] = _normalized_command_results(source.get("command_results", {}), state.get("command_receipts", []), state.get("command_receipt_records", []), state.get("command_fingerprints", {}))
	if not definition.is_empty():
		state["command_receipt_records"] = _migrate_command_receipt_records(state, definition)
	if not [STATUS_ACTIVE, STATUS_AFTERMATH, STATUS_CLEANED].has(str(state.get("status", ""))):
		state["status"] = STATUS_CLEANED
	if not str(state.get("cleanup_content_fingerprint", "")).is_empty() and not _valid_sha256(str(state.get("cleanup_content_fingerprint", ""))):
		return {}
	if not definition.is_empty():
		var expected_scenario_id := str(definition.get("id", ""))
		var expected_definition_version := int(SequenceSchemaScript.sequence(definition).get("schema_version", STATE_SCHEMA_VERSION))
		if str(state.get("scenario_id", "")) != expected_scenario_id or int(state.get("definition_version", 0)) != expected_definition_version:
			state["status"] = STATUS_CLEANED
			state["errors"] = ["saved scenario sequence identity/version does not match the current definition"]
	state["fact_queue"] = _normalized_fact_queue(source.get("fact_queue", []), state)
	if _array(state.get("fact_queue", [])).size() > MAX_FACT_QUEUE or _next_cause_ordinal(state) + _array(state.get("fact_queue", [])).size() > MAX_RECEIPTS:
		return {}
	state["event_correlations"] = _normalized_event_correlations(source.get("event_correlations", []), _dict(_dict(state.get("semantic_state", {})).get("event_choices", {})))
	var semantic := _dict(state.get("semantic_state", {}))
	semantic["operation_receipt_records"] = _normalized_integer_record_fields(semantic.get("operation_receipt_records", []), ["boundary_ordinal", "operation_index"])
	state["semantic_state"] = semantic
	if _array(semantic.get("transition_queue", [])).size() > OperationRegistryScript.MAX_TRANSITION_QUEUE or _string_array(semantic.get("operation_receipts", [])).size() > OperationRegistryScript.MAX_OPERATION_RECEIPTS:
		state["status"] = STATUS_CLEANED
	if not definition.is_empty() and not SequenceSchemaScript.phase_ids(definition).has(str(state.get("phase_id", ""))) and str(state.get("status", "")) == STATUS_ACTIVE:
		state["status"] = STATUS_CLEANED
	if source_version < STATE_SCHEMA_VERSION:
		_append_unique(state["migration_receipts"], "state_v%d_to_v%d" % [source_version, STATE_SCHEMA_VERSION])
	return state


static func _persisted_collections_within_limits(source: Dictionary) -> bool:
	var receipt_arrays := [
		"resolved_branches", "resolved_outcomes",
		"fact_receipts", "fact_receipt_records", "fact_flush_batch_records",
		"command_receipts", "command_receipt_records", "branch_resolution_records",
		"transition_receipts", "transition_receipt_records",
		"cleanup_receipts", "cleanup_receipt_records", "event_correlations",
		"visit_receipts", "visit_receipt_records", "expiry_boundary_records",
	]
	for key_value in receipt_arrays:
		var receipt_key := str(key_value)
		var receipt_value: Variant = source.get(receipt_key, [])
		if typeof(receipt_value) == TYPE_ARRAY and (receipt_value as Array).size() > MAX_RECEIPTS:
			return false
	var queue_value: Variant = source.get("fact_queue", [])
	if typeof(queue_value) == TYPE_ARRAY and (queue_value as Array).size() > MAX_FACT_QUEUE:
		return false
	for key_value in ["command_results", "command_fingerprints", "cleanup_fingerprints", "fact_fingerprints"]:
		var dictionary_key := str(key_value)
		var dictionary_value: Variant = source.get(dictionary_key, {})
		if typeof(dictionary_value) == TYPE_DICTIONARY and (dictionary_value as Dictionary).size() > MAX_RECEIPTS:
			return false
	var semantic := _dict(source.get("semantic_state", {}))
	var transition_queue_value: Variant = semantic.get("transition_queue", [])
	if typeof(transition_queue_value) == TYPE_ARRAY and (transition_queue_value as Array).size() > OperationRegistryScript.MAX_TRANSITION_QUEUE:
		return false
	for key_value in ["operation_receipts", "operation_receipt_records"]:
		var operation_key := str(key_value)
		var operation_value: Variant = semantic.get(operation_key, [])
		if typeof(operation_value) == TYPE_ARRAY and (operation_value as Array).size() > OperationRegistryScript.MAX_OPERATION_RECEIPTS:
			return false
	var operation_fingerprints_value: Variant = semantic.get("operation_fingerprints", {})
	if typeof(operation_fingerprints_value) == TYPE_DICTIONARY and (operation_fingerprints_value as Dictionary).size() > OperationRegistryScript.MAX_OPERATION_RECEIPTS:
		return false
	return true


static func command(command_id: String, node_id: String, phase_id: String, idempotency_key: String, payload: Dictionary = {}, owner_namespace: String = "scenario", stable_object_id: String = "sequence", action_origin_owner_namespace: String = "", action_origin_stable_object_id: String = "", action_origin_receipt_key: String = "", action_origin_boundary_id: String = "", action_origin_fingerprint: String = "") -> Dictionary:
	return {
		"schema_version": COMMAND_SCHEMA_VERSION,
		"command_id": command_id.strip_edges(),
		"node_id": node_id.strip_edges(),
		"expected_phase": phase_id.strip_edges(),
		"idempotency_key": idempotency_key.strip_edges(),
		"owner_namespace": owner_namespace.strip_edges(),
		"stable_object_id": stable_object_id.strip_edges(),
		"action_origin_owner_namespace": owner_namespace.strip_edges() if action_origin_owner_namespace.is_empty() else action_origin_owner_namespace.strip_edges(),
		"action_origin_stable_object_id": stable_object_id.strip_edges() if action_origin_stable_object_id.is_empty() else action_origin_stable_object_id.strip_edges(),
		"action_origin_receipt_key": action_origin_receipt_key,
		"action_origin_boundary_id": action_origin_boundary_id,
		"action_origin_fingerprint": action_origin_fingerprint,
		"payload": payload.duplicate(false),
	}


static func apply_command(state_value: Dictionary, definition: Dictionary, command_value: Dictionary, context: Dictionary = {}, prevalidated_state: bool = false) -> Dictionary:
	var original := state_value if prevalidated_state else normalize_state(state_value, definition)
	var state := original
	var bounded_errors := OperationRegistryScript.validate_bounded_variant("scenario command", command_value)
	if not bounded_errors.is_empty():
		return {"ok": false, "errors": bounded_errors, "state": original, "replayed": false}
	var receipt_id := str(command_value.get("idempotency_key", "")).strip_edges()
	var command_fingerprint := _fingerprint(command_value)
	if not receipt_id.is_empty() and _string_array(state.get("command_receipts", [])).has(receipt_id):
		if str(_dict(state.get("command_fingerprints", {})).get(receipt_id, "")) != command_fingerprint:
			return {"ok": false, "errors": ["scenario command idempotency_key was reused for a different command"], "state": state, "replayed": false}
		var cached := _dict(_dict(state.get("command_results", {})).get(receipt_id, {}))
		if not _valid_cached_command_result(cached, receipt_id, command_value):
			return {"ok": false, "errors": ["scenario command replay result is missing, malformed, or conflicts with its exact command"], "state": state, "replayed": false}
		cached["replayed"] = true
		cached["state"] = state
		return cached
	var effective_context := context.duplicate(false)
	var causal_descriptor := _dict(effective_context.get("causal_action_descriptor", {}))
	if causal_descriptor.is_empty():
		causal_descriptor = causal_action_descriptor(state, definition, command_value)
		if not causal_descriptor.is_empty():
			effective_context["causal_action_descriptor"] = causal_descriptor
	var validation := _validate_command(state, definition, command_value, effective_context)
	if _string_array(state.get("command_receipts", [])).size() >= MAX_RECEIPTS:
		validation.append("scenario command lifetime receipt limit reached")
	if _next_cause_ordinal(state) + _fact_array(state.get("fact_queue", [])).size() >= MAX_RECEIPTS:
		validation.append("scenario causal journal lifetime limit reached")
	if not validation.is_empty():
		return {"ok": false, "errors": validation, "state": state, "replayed": false}
	var command_id := str(command_value.get("command_id", "")).strip_edges()
	var payload := _dict(command_value.get("payload", {}))
	var descriptor := {"action": _dict(causal_descriptor.get("action", {}))} if not causal_descriptor.is_empty() else _command_descriptor(state, definition, str(command_value.get("owner_namespace", "")), str(command_value.get("stable_object_id", "")), command_id, effective_context)
	var cost := maxi(0, int(_dict(descriptor.get("action", {})).get("cost", 0)))
	var original_state := state if prevalidated_state else state.duplicate(true)
	var state_before := "" if prevalidated_state else JSON.stringify(_canonical_variant(state))
	var handler_result := _apply_registered_handler(state, definition, command_value, effective_context, causal_descriptor)
	state = _dict(handler_result.get("state", state))
	if not bool(handler_result.get("ok", false)):
		return {"ok": false, "errors": _array(handler_result.get("errors", [])), "state": original, "replayed": false}
	state = _complete_command_objective_steps(state, definition, command_id)
	var receipts := _string_array(state.get("command_receipts", []))
	receipts.append(receipt_id)
	state["command_receipts"] = receipts
	var fingerprints := _dict(state.get("command_fingerprints", {}))
	fingerprints[receipt_id] = command_fingerprint
	_trim_dictionary_to_receipts(fingerprints, receipts)
	state["command_fingerprints"] = fingerprints
	var receipt_records := _array(state.get("command_receipt_records", []))
	receipt_records.append({"receipt_key": receipt_id, "fingerprint": command_fingerprint, "cause_ordinal": _next_cause_ordinal(state), "envelope": command_value.duplicate(true), "causal_action_descriptor": causal_descriptor.duplicate(true), "causal_action_descriptor_fingerprint": _fingerprint(causal_descriptor)})
	state["command_receipt_records"] = receipt_records
	var trigger := {"kind": "command", "command_id": command_id, "receipt_id": receipt_id, "payload": payload, "cause_fingerprint": command_fingerprint}
	var branch_result := _evaluate_branches(state, definition, trigger)
	if not bool(branch_result.get("ok", false)):
		return {"ok": false, "errors": _array(branch_result.get("errors", [])), "state": original_state, "replayed": false, "cost": 0}
	state = _dict(branch_result.get("state", state))
	var counters := _normalize_counters(state.get("performance_counters", {}))
	counters["commands_applied"] = _saturating_nonnegative_add(int(counters.get("commands_applied", 0)), 1)
	state["performance_counters"] = counters
	var result := {
		"ok": true,
		"replayed": false,
		"receipt_id": receipt_id,
		"command_id": command_id,
		"phase_id": str(state.get("phase_id", "")),
		"status": str(state.get("status", "")),
		"boundary_serial": int(state.get("boundary_serial", 0)),
		"cost": cost,
		"outcomes": _string_array(state.get("resolved_outcomes", [])),
		"changed": true if prevalidated_state else state_before != JSON.stringify(_canonical_variant(state)),
		"state": {},
	}
	var results := _dict(state.get("command_results", {}))
	results[receipt_id] = result.duplicate(true)
	_trim_dictionary_to_receipts(results, receipts)
	state["command_results"] = results
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
		"payload": payload.duplicate(false),
	}


static func enqueue_fact(state_value: Dictionary, definition: Dictionary, fact_value: Dictionary, prevalidated_state: bool = false) -> Dictionary:
	var state := state_value.duplicate(true) if prevalidated_state else normalize_state(state_value, definition)
	var bounded_errors := OperationRegistryScript.validate_bounded_variant("scenario fact", fact_value)
	if not bounded_errors.is_empty():
		return {"ok": false, "duplicate": false, "state": state, "errors": bounded_errors}
	var fact_id := str(fact_value.get("fact_id", "")) if typeof(fact_value.get("fact_id")) == TYPE_STRING else ""
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
	var errors := validate_fact(state, fact_value)
	if not errors.is_empty():
		return {"ok": false, "duplicate": false, "state": state, "errors": errors}
	if _next_cause_ordinal(state) + _fact_array(state.get("fact_queue", [])).size() >= MAX_RECEIPTS:
		return {"ok": false, "duplicate": false, "state": state, "errors": ["scenario fact lifetime receipt limit reached"]}
	var queue := _fact_array(state.get("fact_queue", []))
	if queue.size() >= MAX_FACT_QUEUE:
		return {"ok": false, "duplicate": false, "state": state, "errors": ["scenario fact queue is full"]}
	var queued := fact_value.duplicate(true)
	queued["ingress_serial"] = int(state.get("fact_serial_next", 1))
	state["fact_serial_next"] = _saturating_nonnegative_add(int(queued.get("ingress_serial", 0)), 1)
	queue.append(queued)
	state["fact_queue"] = queue
	return {"ok": true, "duplicate": false, "state": state, "errors": []}


static func validate_fact(state: Dictionary, fact_value: Dictionary) -> Array:
	var errors: Array = []
	for key_value in fact_value.keys():
		if not ["schema_version", "fact_type", "producer", "node_id", "fact_id", "producer_serial", "boundary_serial", "payload"].has(str(key_value)):
			errors.append("scenario fact contains unknown envelope key %s" % str(key_value))
	if typeof(fact_value.get("schema_version")) != TYPE_INT or int(fact_value.get("schema_version", 0)) != FACT_SCHEMA_VERSION:
		errors.append("scenario fact schema_version is invalid")
	var producer := str(fact_value.get("producer", "")) if typeof(fact_value.get("producer")) == TYPE_STRING else ""
	var fact_type := str(fact_value.get("fact_type", "")) if typeof(fact_value.get("fact_type")) == TYPE_STRING else ""
	if not FACT_PRODUCERS.has(producer):
		errors.append("scenario fact producer is unregistered: %s" % producer)
	if not FACT_TYPES.has(fact_type):
		errors.append("scenario fact type is unregistered: %s" % fact_type)
	elif FACT_TYPES_BY_PRODUCER.has(producer) and not _array(FACT_TYPES_BY_PRODUCER.get(producer, [])).has(fact_type):
		errors.append("scenario fact type %s is not owned by producer %s" % [fact_type, producer])
	if typeof(fact_value.get("fact_id")) != TYPE_STRING or not _valid_id(str(fact_value.get("fact_id", ""))) or str(fact_value.get("fact_id", "")) != str(fact_value.get("fact_id", "")).strip_edges():
		errors.append("scenario fact requires an exact canonical fact_id")
	if typeof(fact_value.get("node_id")) != TYPE_STRING or str(fact_value.get("node_id", "")) != str(state.get("node_id", "")):
		errors.append("scenario fact targets the wrong node")
	if str(state.get("status", "")) != STATUS_ACTIVE:
		errors.append("scenario fact requires an active sequence")
	if typeof(fact_value.get("producer_serial")) != TYPE_INT or typeof(fact_value.get("boundary_serial")) != TYPE_INT or int(fact_value.get("producer_serial", -1)) < 0 or int(fact_value.get("boundary_serial", -1)) < 0:
		errors.append("scenario fact serials must be non-negative")
	if typeof(fact_value.get("payload", {})) != TYPE_DICTIONARY:
		errors.append("scenario fact payload must be a dictionary")
	else:
		var payload := fact_value.get("payload", {}) as Dictionary
		var payload_types := _dict(FACT_PAYLOAD_TYPES.get(fact_type, {}))
		for key_value in payload.keys():
			if not payload_types.has(str(key_value)): errors.append("scenario %s fact payload contains unknown key %s" % [fact_type, str(key_value)])
		for required_field_value in _array(FACT_REQUIRED_FIELDS.get(fact_type, [])):
			var required_field := str(required_field_value)
			if not payload.has(required_field):
				errors.append("scenario %s fact requires payload.%s" % [fact_type, required_field])
			elif not _fact_payload_value_matches(payload.get(required_field), str(payload_types.get(required_field, ""))):
				errors.append("scenario %s fact payload.%s has the wrong exact type" % [fact_type, required_field])
		for field_value in payload.keys():
			var field := str(field_value)
			if not payload_types.has(field):
				errors.append("scenario %s fact payload contains unknown field %s" % [fact_type, field])
				continue
			if not _fact_payload_value_matches(payload.get(field_value), str(payload_types.get(field, ""))):
				errors.append("scenario %s fact payload.%s has the wrong exact type" % [fact_type, field])
		if fact_type == "town_transition" and _string_array(payload.get("happening_ids", [])).size() != _array(payload.get("happening_ids", [])).size():
			errors.append("scenario town_transition fact payload.happening_ids must contain unique stable strings")
		if fact_type == "heat_band_changed" and (str(payload.get("previous_band", "")) not in ["quiet", "caution", "hot", "critical"] or str(payload.get("current_band", "")) not in ["quiet", "caution", "hot", "critical"]): errors.append("scenario heat_band_changed fact requires registered heat bands")
		# Event-result authority is definition- and delivery-bound in
		# _event_fact_is_authorized().  A broad legacy observer is intentionally
		# allowed to see an uncorrelated authored result even when its choice is not
		# part of the room's event-launch catalog; correlated results still require
		# the exact delivered resolution and authored closed payload predicate.
		if fact_type == "town_transition" and int(payload.get("action_index", -1)) < 0: errors.append("scenario town_transition fact action_index must be non-negative")
		if fact_type == "sweep_changed" and (int(payload.get("action_index", -1)) < 0 or int(payload.get("segment_index", -1)) < 0 or str(payload.get("node_id", "")).is_empty()): errors.append("scenario sweep_changed fact indexes/node must be valid")
		if fact_type == "world_boundary" and (int(payload.get("amount", 0)) < 1 or int(payload.get("action_index", -1)) < 0): errors.append("scenario world_boundary fact amount/action_index must be positive/non-negative")
		if fact_type == "scenario_command" and (not _canonical_id(str(payload.get("command_id", ""))) or str(payload.get("receipt_id", "")).strip_edges().is_empty()): errors.append("scenario scenario_command fact requires canonical command and stable receipt ids")
	return errors


static func flush_facts(state_value: Dictionary, definition: Dictionary, boundary_serial: int, prevalidated_state: bool = false) -> Dictionary:
	var original := state_value if prevalidated_state else normalize_state(state_value, definition)
	if original.is_empty():
		return {"ok": false, "state": original, "processed": [], "errors": ["scenario causal journal and pending fact capacity is invalid"]}
	var state := original.duplicate(false)
	if str(state.get("status", "")) == STATUS_CLEANED:
		return {"ok": false, "state": state, "processed": [], "errors": ["scenario is cleaned"]}
	var requested_boundary := maxi(0, boundary_serial)
	var target_boundary := maxi(int(state.get("boundary_serial", 0)), requested_boundary)
	var ready: Array = []
	var pending: Array = []
	for fact_value in _fact_array(state.get("fact_queue", [])):
		if int((fact_value as Dictionary).get("boundary_serial", 0)) <= target_boundary:
			ready.append(fact_value)
		else:
			pending.append(fact_value)
	ready.sort_custom(Callable(ScenarioSequenceRuntime, "_sort_fact"))
	var flush_batch_ordinal := _next_fact_batch_ordinal(state)
	if _next_cause_ordinal(state) + _fact_array(state.get("fact_queue", [])).size() > MAX_RECEIPTS:
		return {"ok": false, "state": original, "processed": [], "errors": ["scenario causal journal and pending facts exceed the lifetime receipt limit"]}
	var processed: Array = []
	var errors: Array = []
	var batch_receipt_keys: Array = []
	var batch_fingerprints: Array = []
	for fact_value in ready:
		var preflight := validate_fact(original, _without_ingress(fact_value as Dictionary))
		if not preflight.is_empty(): return {"ok": false, "state": original, "processed": [], "errors": preflight}
		var preflight_envelope := _without_ingress(fact_value as Dictionary)
		batch_receipt_keys.append(str(preflight_envelope.get("fact_id", "")))
		batch_fingerprints.append(_fingerprint(preflight_envelope))
	var first_cause_ordinal := _next_cause_ordinal(state)
	for fact_value in ready:
		var typed_fact := fact_value as Dictionary
		var fact_id := str(typed_fact.get("fact_id", ""))
		if _string_array(state.get("fact_receipts", [])).has(fact_id):
			continue
		var envelope := _without_ingress(typed_fact)
		var fingerprint := _fingerprint(envelope)
		var receipts := _string_array(state.get("fact_receipts", []))
		receipts.append(fact_id)
		state["fact_receipts"] = receipts
		var fingerprints := _dict(state.get("fact_fingerprints", {}))
		fingerprints[fact_id] = fingerprint
		_trim_dictionary_to_receipts(fingerprints, receipts)
		state["fact_fingerprints"] = fingerprints
		var receipt_records := _array(state.get("fact_receipt_records", []))
		receipt_records.append({"receipt_key": fact_id, "fingerprint": fingerprint, "cause_ordinal": _next_cause_ordinal(state), "flush_batch_ordinal": flush_batch_ordinal, "flush_boundary_serial": target_boundary, "envelope": envelope})
		state["fact_receipt_records"] = receipt_records
		if str(state.get("status", "")) == STATUS_ACTIVE:
			var response := _apply_fact(state, definition, typed_fact, fingerprint)
			if not bool(response.get("ok", false)):
				errors.append_array(_array(response.get("errors", [])))
				# A failed batch is fully retryable: keep the durable ingress envelope,
				# its order, and every pre-batch receipt byte-exact. Quarantine or discard
				# requires a separate explicit authority boundary.
				return {"ok": false, "state": original, "processed": [], "errors": errors}
			state = _dict(response.get("state", state))
		state["last_flushed_fact_serial"] = maxi(int(state.get("last_flushed_fact_serial", 0)), int(typed_fact.get("ingress_serial", 0)))
		processed.append(fact_id)
	if not ready.is_empty():
		state["boundary_serial"] = target_boundary
		var prior_batch_records := _array(state.get("fact_flush_batch_records", []))
		var prior_batch_fingerprint := "0".repeat(64) if prior_batch_records.is_empty() else str(_dict(prior_batch_records.back()).get("batch_fingerprint", ""))
		var batch_record := {
			"batch_ordinal": flush_batch_ordinal,
			"requested_boundary_serial": requested_boundary,
			"effective_boundary_serial": target_boundary,
			"first_cause_ordinal": first_cause_ordinal,
			"fact_receipt_keys": batch_receipt_keys,
			"fact_fingerprints": batch_fingerprints,
			"prior_batch_fingerprint": prior_batch_fingerprint,
		}
		batch_record["batch_fingerprint"] = _fingerprint(batch_record)
		var batch_records := prior_batch_records
		batch_records.append(batch_record)
		state["fact_flush_batch_records"] = batch_records
	state["fact_queue"] = pending
	var counters := _normalize_counters(state.get("performance_counters", {}))
	counters["facts_flushed"] = _saturating_nonnegative_add(int(counters.get("facts_flushed", 0)), processed.size())
	state["performance_counters"] = counters
	return {"ok": errors.is_empty(), "state": state, "processed": processed, "errors": errors}


static func record_visit(state_value: Dictionary, definition: Dictionary, visit_id: String, prevalidated_state: bool = false) -> Dictionary:
	var state := state_value if prevalidated_state else normalize_state(state_value, definition)
	if state.is_empty(): return {"ok": false, "state": state, "errors": ["scenario causal journal and pending fact capacity is invalid"]}
	var clean_visit_id := visit_id.strip_edges()
	if not _valid_id(clean_visit_id) or not _valid_persisted_text(clean_visit_id):
		return {"ok": false, "state": state, "errors": ["scenario visit requires a stable visit_id"]}
	var receipt_key := "visit:%s" % clean_visit_id
	var receipts := _string_array(state.get("visit_receipts", []))
	if receipts.has(receipt_key):
		return {"ok": true, "state": state, "errors": [], "replayed": true}
	if receipts.size() >= MAX_RECEIPTS or _next_cause_ordinal(state) + _fact_array(state.get("fact_queue", [])).size() >= MAX_RECEIPTS:
		return {"ok": false, "state": state, "errors": ["scenario causal journal lifetime limit reached"]}
	var next := state.duplicate(false)
	receipts.append(receipt_key)
	next["visit_receipts"] = receipts
	var records := _array(next.get("visit_receipt_records", []))
	records.append({"receipt_key": receipt_key, "visit_id": clean_visit_id, "cause_ordinal": _next_cause_ordinal(state)})
	next["visit_receipt_records"] = records
	return {"ok": true, "state": next, "errors": [], "replayed": false}


static func apply_reentry(state_value: Dictionary, definition: Dictionary, visit_id: String, host_semantics: Dictionary = {}, prevalidated_state: bool = false) -> Dictionary:
	var original := state_value if prevalidated_state else normalize_state(state_value, definition)
	var visit_result := record_visit(original, definition, visit_id, true)
	if not bool(visit_result.get("ok", false)) or bool(visit_result.get("replayed", false)):
		return visit_result
	var state := _dict(visit_result.get("state", original))
	var authored := SequenceSchemaScript.sequence(definition)
	var policies := _dict(authored.get("reentry_policy", {}))
	var status := str(state.get("status", STATUS_ACTIVE))
	var policy_key := "partial" if status == STATUS_ACTIVE else "terminal" if status == STATUS_AFTERMATH else "expired"
	var policy := str(policies.get(policy_key, "resume"))
	var next := state.duplicate(false)
	match policy:
		"restart":
			var cleaned := _apply_cleanup(next, definition, "reentry:%s" % visit_id)
			if not bool(cleaned.get("ok", false)):
				return {"ok": false, "state": original, "errors": _array(cleaned.get("errors", []))}
			var prior_semantic := _dict(state.get("semantic_state", {}))
			var restart_semantics := host_semantics.duplicate(true)
			if restart_semantics.is_empty():
				restart_semantics = {"target_inventory": _dict(prior_semantic.get("target_inventory", {})), "base_interactions": _array(prior_semantic.get("base_interactions", [])), "inventory_schema_version": int(prior_semantic.get("inventory_schema_version", 0)), "inventory_digest": str(prior_semantic.get("inventory_digest", "")), "event_choices": _dict(prior_semantic.get("event_choices", {}))}
			var restarted := initial_state(definition, str(state.get("node_id", "")), str(state.get("seed_token", "")), restart_semantics)
			if restarted.is_empty() or str(restarted.get("status", "")) == STATUS_CLEANED:
				var restart_errors := ["scenario restart reentry failed"]
				restart_errors.append_array(_array(restarted.get("errors", [])))
				return {"ok": false, "state": original, "errors": restart_errors}
			restarted["visit_receipts"] = _array(state.get("visit_receipts", []))
			restarted["visit_receipt_records"] = _reordinal_visit_records(state.get("visit_receipt_records", []))
			next = restarted
		"expired":
			var expired_cleanup := _apply_cleanup(next, definition, "reentry_expired:%s" % visit_id)
			if not bool(expired_cleanup.get("ok", false)):
				return {"ok": false, "state": original, "errors": _array(expired_cleanup.get("errors", []))}
			next = _dict(expired_cleanup.get("state", next))
			next["expired"] = true
			next["status"] = STATUS_CLEANED
			next["last_feedback"] = "This room sequence has expired. The exit remains clear."
		"aftermath":
			# Terminal aftermath is already materialized in semantic_state. Partial
			# sequences cannot invent an outcome at reentry and therefore resume
			# their current phase's readable arrival state.
			if status == STATUS_AFTERMATH:
				next["last_feedback"] = _aftermath_feedback(next, definition)
			elif status == STATUS_ACTIVE:
				next["last_feedback"] = str(SequenceSchemaScript.phase(definition, str(next.get("phase_id", ""))).get("arrival_feedback", next.get("last_feedback", "")))
		"resume":
			if status == STATUS_AFTERMATH:
				next["last_feedback"] = _aftermath_feedback(next, definition)
			elif status == STATUS_ACTIVE:
				next["last_feedback"] = str(SequenceSchemaScript.phase(definition, str(next.get("phase_id", ""))).get("arrival_feedback", next.get("last_feedback", "")))
		_:
			return {"ok": false, "state": original, "errors": ["scenario reentry policy is invalid: %s" % policy]}
	return {"ok": true, "state": next, "replayed": false, "policy": policy}


static func apply_expiry(state_value: Dictionary, definition: Dictionary, boundary: String, boundary_serial: int, prevalidated_state: bool = false) -> Dictionary:
	var state := state_value if prevalidated_state else normalize_state(state_value, definition)
	var expiry := _dict(SequenceSchemaScript.sequence(definition).get("expiry", {}))
	var clean_boundary := boundary.strip_edges()
	if state.is_empty() or clean_boundary.is_empty():
		return {"ok": false, "state": state, "errors": ["scenario expiry requires state and boundary"]}
	if str(state.get("status", "")) != STATUS_ACTIVE:
		return {"ok": true, "state": state, "applied": false, "expired": true, "errors": []}
	if str(expiry.get("boundary", "none")) == "none" or str(expiry.get("boundary", "none")) != clean_boundary:
		return {"ok": true, "state": state, "applied": false, "expired": false, "errors": []}
	var receipt_id := "expiry:%s:%d" % [clean_boundary, maxi(0, boundary_serial)]
	var receipts := _string_array(state.get("expiry_receipts", []))
	if receipts.has(receipt_id):
		return {"ok": true, "state": state, "applied": false, "expired": str(state.get("status", "")) != STATUS_ACTIVE, "replayed": true, "errors": []}
	var next := state.duplicate(false)
	var counts := _normalize_expiry_counts(next.get("expiry_counts", {}))
	counts[clean_boundary] = int(counts.get(clean_boundary, 0)) + 1
	next["expiry_counts"] = counts
	receipts.append(receipt_id)
	next["expiry_receipts"] = _bounded_strings(receipts, MAX_RECEIPTS)
	var threshold := maxi(0, int(expiry.get("after", 0)))
	if threshold > 0 and int(counts.get(clean_boundary, 0)) < threshold:
		return {"ok": true, "state": next, "applied": true, "expired": false, "errors": []}
	var policy := str(expiry.get("policy", "resume"))
	if policy == "resume":
		return {"ok": true, "state": next, "applied": true, "expired": false, "policy": policy, "errors": []}
	if policy in ["fail", "ignore", "cancel"]:
		var objective_outcome := "failure" if policy == "fail" else policy
		for objective_id_value in _string_array(SequenceSchemaScript.phase(definition, str(next.get("phase_id", ""))).get("objective_ids", [])):
			next = _resolve_objective(next, definition, str(objective_id_value), objective_outcome)
		var outcome := _lifecycle_outcome(definition, policy)
		if not outcome.is_empty():
			var outcome_result := _resolve_outcome(next, definition, outcome, receipt_id)
			if not bool(outcome_result.get("ok", false)):
				return {"ok": false, "state": state, "applied": false, "expired": false, "policy": policy, "errors": _array(outcome_result.get("errors", []))}
			next = _dict(outcome_result.get("state", next))
		else:
			var cleanup_result := _apply_cleanup(next, definition, receipt_id)
			if not bool(cleanup_result.get("ok", false)):
				return {"ok": false, "state": state, "applied": false, "expired": false, "policy": policy, "errors": _array(cleanup_result.get("errors", []))}
			next = _dict(cleanup_result.get("state", next))
			next["status"] = STATUS_CLEANED
	elif policy == "cleanup":
		var cleanup_result := _apply_cleanup(next, definition, receipt_id)
		if not bool(cleanup_result.get("ok", false)):
			return {"ok": false, "state": state, "applied": false, "expired": false, "policy": policy, "errors": _array(cleanup_result.get("errors", []))}
		next = _dict(cleanup_result.get("state", next))
		next["status"] = STATUS_CLEANED
	else:
		return {"ok": false, "state": state, "errors": ["scenario expiry policy is invalid: %s" % policy]}
	return {"ok": true, "state": next, "applied": true, "expired": true, "policy": policy, "errors": []}


static func drain_transitions(state_value: Dictionary, definition: Dictionary, reduced_motion: bool = false, prevalidated_state: bool = false) -> Dictionary:
	var state := state_value.duplicate(true) if prevalidated_state else normalize_state(state_value, definition)
	if state.is_empty():
		return {"ok": false, "state": state, "transitions": [], "errors": ["scenario transition drain requires state"]}
	var semantic := OperationRegistryScript.normalize_semantic_state(_dict(state.get("semantic_state", {})))
	var delivered := _string_array(state.get("transition_delivery_receipts", []))
	var emitted: Array = []
	var remaining: Array = []
	var active_stages := _bounded_records(state.get("active_stages", []), MAX_RECEIPTS)
	for transition_value in _array(semantic.get("transition_queue", [])):
		var transition := _dict(transition_value)
		var receipt_id := str(transition.get("receipt_id", "")).strip_edges()
		if receipt_id.is_empty() or delivered.has(receipt_id):
			continue
		var presentation := transition.duplicate(true)
		if reduced_motion and str(presentation.get("op", "")) == "stage":
			presentation["message"] = str(presentation.get("reduced_motion_message", presentation.get("message", "")))
			presentation["duration_boundaries"] = 0
		emitted.append(_public_transition_dto(presentation))
		delivered.append(receipt_id)
		if str(presentation.get("op", "")) == "stage" and int(presentation.get("duration_boundaries", 0)) > 0:
			var stage := presentation.duplicate(true)
			stage["started_boundary"] = int(state.get("boundary_serial", 0))
			stage["expires_boundary"] = int(state.get("boundary_serial", 0)) + int(presentation.get("duration_boundaries", 0))
			active_stages.append(stage)
	semantic["transition_queue"] = remaining
	state["semantic_state"] = semantic
	state["transition_delivery_receipts"] = _bounded_strings(delivered, MAX_RECEIPTS)
	state["active_stages"] = _bounded_records(active_stages, MAX_RECEIPTS)
	return {"ok": true, "state": state, "transitions": emitted, "errors": []}


static func _public_transition_dto(value: Dictionary) -> Dictionary:
	var result := {
		"op": str(value.get("op", "feedback")),
		"message": str(value.get("message", "")),
		"duration_boundaries": maxi(0, int(value.get("duration_boundaries", 0))),
	}
	if not str(value.get("stage_id", "")).strip_edges().is_empty():
		result["stage_id"] = str(value.get("stage_id", ""))
	if not str(value.get("cue_id", "")).strip_edges().is_empty():
		result["cue_id"] = str(value.get("cue_id", ""))
	return result


static func _public_active_stage_dtos(value: Variant) -> Array:
	var result: Array = []
	for stage_value in _bounded_records(value, MAX_RECEIPTS):
		var stage := _dict(stage_value)
		result.append({
			"stage_id": str(stage.get("stage_id", "")),
			"message": str(stage.get("message", "")),
			"started_boundary": maxi(0, int(stage.get("started_boundary", 0))),
			"expires_boundary": maxi(0, int(stage.get("expires_boundary", 0))),
		})
	return result


static func drain_event_requests(state_value: Dictionary, definition: Dictionary, prevalidated_state: bool = false) -> Dictionary:
	var state := state_value.duplicate(true) if prevalidated_state else normalize_state(state_value, definition)
	if state.is_empty():
		return {"ok": false, "state": state, "requests": [], "errors": ["scenario event-request drain requires state"]}
	var delivered := _string_array(state.get("event_request_delivery_receipts", []))
	var history := _bounded_records(state.get("event_request_history", []), MAX_RECEIPTS)
	var emitted: Array = []
	for request_value in _bounded_records(state.get("event_request_queue", []), MAX_RECEIPTS):
		var request := _dict(request_value)
		var request_id := str(request.get("request_id", "")).strip_edges()
		if request_id.is_empty() or delivered.has(request_id): continue
		var public_request := {"kind": str(request.get("kind", "event"))}
		match str(public_request.get("kind", "event")):
			"item":
				public_request["item_id"] = str(request.get("item_id", ""))
				public_request["message"] = str(request.get("message", ""))
			"cash":
				public_request["amount"] = int(request.get("amount", 0))
				public_request["message"] = str(request.get("message", ""))
			_:
				public_request["event_id"] = str(request.get("event_id", ""))
				public_request["resolution_id"] = str(request.get("resolution_id", ""))
		emitted.append(public_request)
		history.append(request)
		delivered.append(request_id)
	state["event_request_queue"] = []
	state["event_request_history"] = _bounded_records(history, MAX_RECEIPTS)
	state["event_request_delivery_receipts"] = _bounded_strings(delivered, MAX_RECEIPTS)
	return {"ok": true, "state": state, "requests": emitted, "errors": []}


static func apply_expiry_boundary(state_value: Dictionary, definition: Dictionary, boundary: String, amount: int = 1, prevalidated_state: bool = false) -> Dictionary:
	var original := state_value if prevalidated_state else normalize_state(state_value, definition)
	if original.is_empty(): return {"ok": false, "state": original, "errors": ["scenario causal journal and pending fact capacity is invalid"], "expired": false}
	var expiry := _dict(SequenceSchemaScript.sequence(definition).get("expiry", {}))
	if str(expiry.get("boundary", "none")) == "none" or str(expiry.get("boundary", "")) != boundary:
		return {"ok": true, "state": original, "errors": [], "expired": bool(original.get("expired", false))}
	if bool(original.get("expired", false)):
		return {"ok": true, "state": original, "errors": [], "expired": true, "replayed": true}
	var next := original.duplicate(false)
	var applied_amount := maxi(1, amount)
	var expiry_records := _array(next.get("expiry_boundary_records", []))
	if expiry_records.size() >= MAX_RECEIPTS or _next_cause_ordinal(next) + _fact_array(next.get("fact_queue", [])).size() >= MAX_RECEIPTS:
		return {"ok": false, "state": original, "errors": ["scenario causal journal lifetime limit reached"], "expired": false}
	expiry_records.append({"cause_ordinal": _next_cause_ordinal(next), "boundary": boundary, "amount": applied_amount})
	next["expiry_boundary_records"] = expiry_records
	next["expiry_progress"] = _saturating_nonnegative_add(int(next.get("expiry_progress", 0)), applied_amount)
	if int(next.get("expiry_progress", 0)) < maxi(1, int(expiry.get("after", 0))):
		return {"ok": true, "state": next, "errors": [], "expired": false}
	var policy := str(expiry.get("policy", "fail"))
	next["expired"] = true
	if policy == "resume":
		return {"ok": true, "state": next, "errors": [], "expired": true, "policy": policy}
	if policy == "ignore":
		next = _set_objective_outcomes(next, definition, "ignore")
		return {"ok": true, "state": next, "errors": [], "expired": true, "policy": policy}
	var cleanup_result := _apply_cleanup(next, definition, "expiry:%s" % boundary)
	if not bool(cleanup_result.get("ok", false)):
		return {"ok": false, "state": original, "errors": _array(cleanup_result.get("errors", [])), "expired": false}
	next = _dict(cleanup_result.get("state", next))
	next["status"] = STATUS_CLEANED
	next = _set_objective_outcomes(next, definition, "failure" if policy == "fail" else "cancel")
	return {"ok": true, "state": next, "errors": [], "expired": true, "policy": policy}


# Trusted owner adapters use this only when the owning model publicly ends.
# Travel, save and revisit do not call this boundary.
static func apply_owner_lifecycle_outcome(state_value: Dictionary, definition: Dictionary, outcome: String, reason: String) -> Dictionary:
	var state := normalize_state(state_value, definition)
	if state.is_empty(): return {"ok": false, "state": state, "errors": ["scenario owner lifecycle requires normalized state"]}
	if reason not in ["expired", "abandoned"] or outcome != reason:
		return {"ok": false, "state": state, "errors": ["scenario owner lifecycle reason must be exact expired or abandoned outcome"]}
	if not SequenceSchemaScript.reachable_outcome_ids(definition).has(outcome):
		return {"ok": false, "state": state, "errors": ["scenario owner lifecycle outcome is not authored: %s" % outcome]}
	var receipt_id := structural_runtime_receipt("owner_lifecycle", [str(state.get("scenario_id", "")), str(state.get("node_id", "")), reason])
	if str(state.get("status", "")) == STATUS_AFTERMATH:
		return {"ok": true, "state": state, "receipt_id": receipt_id, "replayed": true, "errors": []}
	if str(state.get("status", "")) != STATUS_ACTIVE:
		return {"ok": false, "state": state, "errors": ["scenario owner lifecycle cannot resolve from current status"]}
	var resolved := _resolve_outcome(state, definition, outcome, receipt_id)
	if not bool(resolved.get("ok", false)): return resolved
	resolved["receipt_id"] = receipt_id
	resolved["replayed"] = false
	return resolved


static func public_projection(state_value: Dictionary, definition: Dictionary = {}, prevalidated_state: bool = false) -> Dictionary:
	# Engine-owned transactions have already passed the strict normalization and
	# host-authority checks in ensure_sequence_state(). Re-normalizing the same
	# causal journal here doubled every synchronous re-entry/expiry transition.
	# Public callers retain the closed default and must still normalize.
	var state := state_value if prevalidated_state else normalize_state(state_value, definition)
	if state.is_empty():
		return {}
	var public_semantics := OperationRegistryScript.public_semantic_state(_dict(state.get("semantic_state", {})))
	# Cleanup removes scenario presentation. Authored aftermath is deliberately
	# still public: its objects are the visible, inspectable receipt for how the
	# room ended and must survive leave/revisit and save/load.
	if str(state.get("status", "")) == STATUS_CLEANED:
		for presentation_collection in ["scene_objects", "actors", "interactions"]:
			public_semantics[presentation_collection] = {}
	var public_interactions := _dict(public_semantics.get("interactions", {}))
	for identity_value in public_interactions.keys():
		var interaction := _dict(public_interactions.get(identity_value, {}))
		var available_actions: Array = []
		for action_value in _array(interaction.get("available_actions", [])):
			var action := _dict(action_value)
			if _action_preconditions_publicly_available(state, definition, action):
				available_actions.append(action)
		interaction["available_actions"] = available_actions
		public_interactions[identity_value] = interaction
	public_semantics["interactions"] = public_interactions
	var projection := {
		"scenario_id": str(state.get("scenario_id", "")),
		"node_id": str(state.get("node_id", "")),
		"phase_id": str(state.get("phase_id", "")),
		"status": str(state.get("status", "")),
		"boundary_serial": maxi(0, int(state.get("boundary_serial", 0))),
		"objectives": _public_objectives(state, definition),
		"local_state": SequenceSchemaScript.public_local_state(definition, state.get("local_state", {})),
		"resolved_outcomes": _string_array(state.get("resolved_outcomes", [])),
		"last_feedback": str(state.get("last_feedback", "")),
		"semantic_state": public_semantics,
		"pending_transition_count": _array(_dict(state.get("semantic_state", {})).get("transition_queue", [])).size(),
		"active_stages": _public_active_stage_dtos(state.get("active_stages", [])),
		"pending_event_request_count": _array(state.get("event_request_queue", [])).size(),
	}
	return _json_projection_variant(projection)


# Presentation may suppress only an action whose unmet requirement is itself
# public. Private local state remains undisclosed and is enforced only by
# authenticated command ingress.
static func _action_preconditions_publicly_available(state: Dictionary, definition: Dictionary, action: Dictionary) -> bool:
	for requirement_value in _array(action.get("requires_objective_steps", [])):
		var requirement := _dict(requirement_value)
		if not _objective_step_complete(state, str(requirement.get("objective_id", "")), str(requirement.get("step_id", ""))):
			return false
	var local_schema := _dict(SequenceSchemaScript.sequence(definition).get("local_state_schema", {}))
	var local_state := _dict(state.get("local_state", {}))
	for requirement_value in _array(action.get("requires_local", [])):
		var requirement := _dict(requirement_value)
		var key := str(requirement.get("key", ""))
		var field_schema := _dict(local_schema.get(key, {}))
		if str(field_schema.get("visibility", "private")) == "public" and local_state.get(key) != requirement.get("equals"):
			return false
	return true


static func _validate_command(state: Dictionary, definition: Dictionary, command_value: Dictionary, context: Dictionary) -> Array:
	var errors: Array = []
	for key_value in command_value.keys():
		if not ["schema_version", "command_id", "node_id", "expected_phase", "idempotency_key", "owner_namespace", "stable_object_id", "action_origin_owner_namespace", "action_origin_stable_object_id", "action_origin_receipt_key", "action_origin_boundary_id", "action_origin_fingerprint", "payload"].has(str(key_value)): errors.append("scenario command contains unknown envelope key %s" % str(key_value))
	if state.is_empty() or str(state.get("status", "")) != STATUS_ACTIVE:
		errors.append("scenario command requires an active sequence")
	if typeof(command_value.get("schema_version")) != TYPE_INT or int(command_value.get("schema_version", 0)) != COMMAND_SCHEMA_VERSION:
		errors.append("scenario command schema_version is invalid")
	for field in ["command_id", "node_id", "expected_phase", "idempotency_key", "owner_namespace", "stable_object_id", "action_origin_owner_namespace", "action_origin_stable_object_id", "action_origin_receipt_key", "action_origin_boundary_id", "action_origin_fingerprint"]:
		if typeof(command_value.get(field)) != TYPE_STRING or str(command_value.get(field, "")) != str(command_value.get(field, "")).strip_edges(): errors.append("scenario command requires exact string field %s" % field)
	if str(command_value.get("node_id", "")) != str(state.get("node_id", "")):
		errors.append("scenario command targets the wrong node")
	if str(command_value.get("expected_phase", "")) != str(state.get("phase_id", "")):
		errors.append("scenario command expected_phase is stale")
	if not _valid_id(str(command_value.get("idempotency_key", ""))) or str(command_value.get("idempotency_key", "")).length() > OperationRegistryScript.MAX_VARIANT_TEXT:
		errors.append("scenario command requires idempotency_key")
	var owner_namespace := str(command_value.get("owner_namespace", ""))
	var stable_object_id := str(command_value.get("stable_object_id", ""))
	if OperationRegistryScript.parse_owned_identity(OperationRegistryScript.identity(owner_namespace, stable_object_id)).is_empty():
		errors.append("scenario command requires interaction identity")
	var command_id := str(command_value.get("command_id", ""))
	if not _canonical_id(command_id) or not _phase_command_ids(state, definition, str(state.get("phase_id", ""))).has(command_id):
		errors.append("scenario command is unavailable in the current phase")
	if typeof(command_value.get("payload", {})) != TYPE_DICTIONARY:
		errors.append("scenario command payload must be a dictionary")
	var causal_descriptor := _dict(context.get("causal_action_descriptor", {}))
	var descriptor: Dictionary = {}
	if not causal_descriptor.is_empty():
		errors.append_array(validate_causal_action_descriptor(state, definition, command_value, causal_descriptor))
		descriptor = {
			"identity_present": true,
			"interaction_enabled": true,
			"action_present": true,
			"action": _dict(causal_descriptor.get("action", {})),
			"action_origin_owner_namespace": str(_dict(causal_descriptor.get("action", {})).get("action_origin_owner_namespace", "")),
			"action_origin_stable_object_id": str(_dict(causal_descriptor.get("action", {})).get("action_origin_stable_object_id", "")),
			"action_origin_receipt_key": str(_dict(causal_descriptor.get("action", {})).get("action_origin_receipt_key", "")),
			"action_origin_boundary_id": str(_dict(causal_descriptor.get("action", {})).get("action_origin_boundary_id", "")),
			"action_origin_fingerprint": str(_dict(causal_descriptor.get("action", {})).get("action_origin_fingerprint", "")),
		}
	else:
		descriptor = _command_descriptor(state, definition, owner_namespace, stable_object_id, command_id, context)
	var creation_owners := _array(_dict(state.get("semantic_state", {})).get("creation_owner_namespaces", ["scenario"]))
	if not creation_owners.has(owner_namespace):
		var external_action := _dict(descriptor.get("action", {}))
		var sealed_creation_owner_origin := bool(descriptor.get("action_present", false)) \
			and creation_owners.has(str(external_action.get("action_origin_owner_namespace", ""))) \
			and _authored_action_origin_matches(state, definition, owner_namespace, stable_object_id, external_action)
		if not sealed_creation_owner_origin:
			errors.append("scenario command cannot spoof another owner namespace")
		else:
			var addressed_identity := OperationRegistryScript.identity(owner_namespace, stable_object_id)
			# Presentation availability is a one-way proposal. It may suppress a
			# sealed host interaction, but caller true can never create or broaden
			# authority beyond the base records captured in this sequence state.
			descriptor["interaction_enabled"] = _sealed_host_interaction_enabled(state, owner_namespace, stable_object_id) \
				and _availability_proposal_allows(context, addressed_identity)
	if not bool(descriptor.get("identity_present", false)):
		errors.append("scenario command targets a missing interaction identity")
	else:
		if not bool(descriptor.get("interaction_enabled", false)):
			errors.append("scenario command interaction is disabled")
		elif not bool(descriptor.get("action_present", false)):
			errors.append("scenario command is unavailable on the addressed interaction")
		elif str(command_value.get("action_origin_owner_namespace", "")) != str(descriptor.get("action_origin_owner_namespace", "")) or str(command_value.get("action_origin_stable_object_id", "")) != str(descriptor.get("action_origin_stable_object_id", "")) or str(command_value.get("action_origin_receipt_key", "")) != str(descriptor.get("action_origin_receipt_key", "")) or str(command_value.get("action_origin_boundary_id", "")) != str(descriptor.get("action_origin_boundary_id", "")) or str(command_value.get("action_origin_fingerprint", "")) != str(descriptor.get("action_origin_fingerprint", "")):
			errors.append("scenario command action origin is stale or mismatched")
		else:
			errors.append_array(_command_precondition_errors(state, _dict(descriptor.get("action", {}))))
	var cost := maxi(0, int(_dict(descriptor.get("action", {})).get("cost", 0)))
	if cost > maxi(0, int(context.get("available_funds", 0))):
		errors.append("scenario command cost is not payable")
	return errors


static func _apply_registered_handler(state: Dictionary, definition: Dictionary, command_value: Dictionary, context: Dictionary = {}, causal_descriptor: Dictionary = {}) -> Dictionary:
	var next := state.duplicate(false)
	var command_id := str(command_value.get("command_id", "")).strip_edges()
	var descriptor := {"action": _dict(causal_descriptor.get("action", {}))} if not causal_descriptor.is_empty() else _command_descriptor(
		state,
		definition,
		str(command_value.get("owner_namespace", "")),
		str(command_value.get("stable_object_id", "")),
		command_id,
		context
	)
	var action := _dict(descriptor.get("action", {}))
	var handler_id := str(action.get("handler", "")).strip_edges()
	if handler_id.is_empty():
		return {"ok": true, "state": next}
	if not OperationRegistryScript.registered_handlers().has(handler_id):
		return {"ok": false, "state": state, "errors": ["scenario command handler is unregistered: %s" % handler_id]}
	return _run_handler(next, definition, handler_id, _dict(action.get("inputs", {})), {"kind": "command", "command_id": command_id, "receipt_id": str(command_value.get("idempotency_key", "")), "payload": _dict(command_value.get("payload", {}))})


static func causal_action_descriptor(state: Dictionary, definition: Dictionary, command_value: Dictionary) -> Dictionary:
	var descriptor := _command_descriptor(state, definition, str(command_value.get("owner_namespace", "")), str(command_value.get("stable_object_id", "")), str(command_value.get("command_id", "")))
	if not bool(descriptor.get("identity_present", false)) or not bool(descriptor.get("interaction_enabled", false)) or not bool(descriptor.get("action_present", false)):
		return {}
	return {
		"owner_namespace": str(command_value.get("owner_namespace", "")),
		"stable_object_id": str(command_value.get("stable_object_id", "")),
		"command_id": str(command_value.get("command_id", "")),
		"action": _dict(descriptor.get("action", {})),
	}


static func _migrate_command_receipt_records(state: Dictionary, definition: Dictionary) -> Array:
	var records: Array = []
	for record_value in _array(state.get("command_receipt_records", [])):
		var record := _dict(record_value).duplicate(true)
		if record.size() == 4:
			var descriptor := receipt_bound_causal_action_descriptor(state, definition, _dict(record.get("envelope", {})))
			if not descriptor.is_empty():
				record["causal_action_descriptor"] = descriptor
				record["causal_action_descriptor_fingerprint"] = _fingerprint(descriptor)
		records.append(record)
	return records


static func receipt_bound_causal_action_descriptor(state: Dictionary, definition: Dictionary, command_value: Dictionary) -> Dictionary:
	var receipt_key := str(command_value.get("action_origin_receipt_key", ""))
	var boundary_id := str(command_value.get("action_origin_boundary_id", ""))
	var operation_fingerprint := str(command_value.get("action_origin_fingerprint", ""))
	var receipt_record: Dictionary = {}
	for record_value in _array(_dict(state.get("semantic_state", {})).get("operation_receipt_records", [])):
		var candidate := _dict(record_value)
		if str(candidate.get("receipt_key", "")) == receipt_key:
			receipt_record = candidate
			break
	if receipt_record.is_empty() or str(receipt_record.get("family", "")) != "interaction_ops" or str(receipt_record.get("boundary_id", "")) != boundary_id or str(receipt_record.get("fingerprint", "")) != operation_fingerprint:
		return {}
	var operation := _authored_interaction_operation_for_receipt(definition, receipt_record)
	if not operation.is_empty():
		var interaction := _dict(operation.get("interaction", {}))
		for action_value in _array(interaction.get("available_actions", operation.get("available_actions", []))):
			var action := _dict(action_value).duplicate(true)
			if str(action.get("id", "")) != str(command_value.get("command_id", "")): continue
			action["action_origin_owner_namespace"] = str(operation.get("owner_namespace", interaction.get("owner_namespace", "")))
			action["action_origin_stable_object_id"] = str(operation.get("stable_object_id", interaction.get("stable_object_id", "")))
			action["action_origin_receipt_key"] = receipt_key
			action["action_origin_boundary_id"] = boundary_id
			action["action_origin_fingerprint"] = operation_fingerprint
			return {"owner_namespace": str(command_value.get("owner_namespace", "")), "stable_object_id": str(command_value.get("stable_object_id", "")), "command_id": str(command_value.get("command_id", "")), "action": action}
	return {}


static func validate_causal_action_descriptor(state: Dictionary, definition: Dictionary, command_value: Dictionary, descriptor: Dictionary) -> Array:
	var errors: Array = []
	var descriptor_closed := descriptor.size() == 4
	for key_value in descriptor.keys():
		if str(key_value) not in ["owner_namespace", "stable_object_id", "command_id", "action"]: descriptor_closed = false
	if not descriptor_closed:
		return ["scenario command causal action descriptor is not closed"]
	for key in ["owner_namespace", "stable_object_id", "command_id"]:
		if typeof(descriptor.get(key)) != TYPE_STRING or str(descriptor.get(key, "")) != str(command_value.get(key, "")):
			errors.append("scenario command causal action descriptor conflicts with %s" % key)
	var action := _dict(descriptor.get("action", {}))
	if action.is_empty() or str(action.get("id", "")) != str(command_value.get("command_id", "")):
		errors.append("scenario command causal action descriptor has no exact action")
	else:
		var authored_phase_state := state.duplicate(false)
		authored_phase_state["phase_id"] = str(command_value.get("expected_phase", ""))
		if not _authored_action_origin_matches(authored_phase_state, definition, str(descriptor.get("owner_namespace", "")), str(descriptor.get("stable_object_id", "")), action):
			errors.append("scenario command causal action descriptor is not bound to an authored operation receipt")
	for field in ["action_origin_owner_namespace", "action_origin_stable_object_id", "action_origin_receipt_key", "action_origin_boundary_id", "action_origin_fingerprint"]:
		if str(command_value.get(field, "")) != str(action.get(field, "")):
			errors.append("scenario command causal action descriptor conflicts with %s" % field)
	return errors


static func _run_handler(state: Dictionary, definition: Dictionary, handler_id: String, inputs: Dictionary, trigger: Dictionary) -> Dictionary:
	var trigger_kind := str(trigger.get("kind", ""))
	if trigger_kind not in ["command", "fact"]:
		return {"ok": false, "state": state, "errors": ["scenario handler trigger kind must be exactly command or fact"]}
	var handler_event_choices := _dict(_dict(state.get("semantic_state", {})).get("event_choices", {})).duplicate(true)
	if handler_id == "event_bridge" and _authored_event_resolution_pair(definition, str(inputs.get("event_id", "")), str(inputs.get("resolution_id", ""))):
		var authored_resolutions := _array(handler_event_choices.get(str(inputs.get("event_id", "")), [])).duplicate()
		_append_unique(authored_resolutions, str(inputs.get("resolution_id", "")))
		handler_event_choices[str(inputs.get("event_id", ""))] = authored_resolutions
	var handler_errors := OperationRegistryScript.validate_handler_inputs(handler_id, inputs, _dict(SequenceSchemaScript.sequence(definition).get("local_state_schema", {})), SequenceSchemaScript.reachable_outcome_ids(definition), {"source": trigger_kind, "objective_steps": _objective_step_index(definition), "phase_objective_ids": _array(SequenceSchemaScript.phase(definition, str(state.get("phase_id", ""))).get("objective_ids", [])), "event_choices": handler_event_choices})
	if not handler_errors.is_empty(): return {"ok": false, "state": state, "errors": handler_errors}
	var next := state.duplicate(false)
	var local := _dict(next.get("local_state", {}))
	var handler_replayed := false
	match handler_id:
		"set_local":
			local[str(inputs.get("key", ""))] = inputs.get("value")
			next["local_state"] = SequenceSchemaScript.normalize_local_state(definition, local)
		"increment_local":
			var key := str(inputs.get("key", ""))
			var field := _dict(_dict(SequenceSchemaScript.sequence(definition).get("local_state_schema", {})).get(key, {}))
			var current := int(local.get(key, 0))
			var amount := int(inputs.get("amount", 0))
			var sum := current
			if amount > 0 and current > 9223372036854775807 - amount:
				sum = 9223372036854775807
			elif amount < 0 and current < -9223372036854775807 - 1 - amount:
				sum = -9223372036854775807 - 1
			else:
				sum = current + amount
			if field.has("min"): sum = maxi(sum, int(field.get("min")))
			if field.has("max"): sum = mini(sum, int(field.get("max")))
			local[key] = sum
			next["local_state"] = SequenceSchemaScript.normalize_local_state(definition, local)
		"complete_objective_step":
			next = _complete_objective_step(next, definition, str(inputs.get("objective_id", "")), str(inputs.get("step_id", "")))
		"resolve_objective":
			next = _resolve_objective(next, definition, str(inputs.get("objective_id", "")), str(inputs.get("outcome", "")))
		"record_outcome":
			var outcomes := _string_array(next.get("resolved_outcomes", []))
			var outcome := str(inputs.get("outcome", "")).strip_edges()
			if not outcome.is_empty() and not outcomes.has(outcome): outcomes.append(outcome)
			next["resolved_outcomes"] = outcomes
		"publish_feedback":
			var feedback_message := str(inputs.get("message", ""))
			next["last_feedback"] = feedback_message
			next = _queue_feedback_transition(next, feedback_message, trigger)
		"request_cleanup":
			var cleanup_result := _apply_cleanup(next, definition, str(inputs.get("reason", "requested")))
			if not bool(cleanup_result.get("ok", false)):
				return cleanup_result
			handler_replayed = bool(cleanup_result.get("replayed", false))
			next = _dict(cleanup_result.get("state", next))
			next["status"] = STATUS_CLEANED
		"event_bridge":
			var event_id := str(inputs.get("event_id", ""))
			var resolution_id := str(inputs.get("resolution_id", ""))
			var trigger_id := str(trigger.get("receipt_id", trigger.get("fact_id", trigger.get("command_id", ""))))
			if event_id != event_id.strip_edges() or resolution_id != resolution_id.strip_edges() or not _valid_id(event_id) or not _valid_id(resolution_id) or not _valid_persisted_text(trigger_id):
				return {"ok": false, "state": state, "errors": ["scenario event correlation requires exact canonical event, resolution, and trigger ids"]}
			var event_choices := _dict(_dict(next.get("semantic_state", {})).get("event_choices", {}))
			if _array(event_choices.get(event_id, [])).is_empty() or not _authored_event_resolution_pair(definition, event_id, resolution_id):
				return {"ok": false, "state": state, "errors": ["scenario event correlation requires a catalog-proven event choice pair"]}
			var feedback := "Event %s resolved as %s." % [event_id, resolution_id]
			if feedback.length() > OperationRegistryScript.MAX_VARIANT_TEXT:
				return {"ok": false, "state": state, "errors": ["scenario event correlation feedback exceeds the persisted text boundary"]}
			var correlation_key := _structural_receipt("event_correlation", [event_id, resolution_id, trigger_kind, trigger_id])
			var correlations := _normalized_event_correlations(next.get("event_correlations", []), event_choices)
			var found := false
			for correlation_value in correlations:
				if str(_dict(correlation_value).get("correlation_key", "")) == correlation_key: found = true
			if not found and correlations.size() >= MAX_RECEIPTS: return {"ok": false, "state": state, "errors": ["scenario event correlation lifetime receipt limit reached"]}
			if not found: correlations.append({"correlation_key": correlation_key, "event_id": event_id, "resolution_id": resolution_id, "trigger_kind": trigger_kind, "trigger_id": trigger_id})
			next["event_correlations"] = correlations
			var request_id := "event_request:%s:%s:%s" % [event_id, resolution_id, _trigger_receipt(trigger)]
			var requests := _bounded_records(next.get("event_request_queue", []), MAX_RECEIPTS)
			var known_request := false
			for request_value in requests:
				if str(_dict(request_value).get("request_id", "")) == request_id: known_request = true
			if not known_request:
				requests.append({"request_id": request_id, "event_id": event_id, "resolution_id": resolution_id, "scenario_id": str(next.get("scenario_id", "")), "node_id": str(next.get("node_id", "")), "phase_id": str(next.get("phase_id", ""))})
			next["event_request_queue"] = _bounded_records(requests, MAX_RECEIPTS)
			next["last_feedback"] = feedback
		"grant_item", "grant_cash":
			var consequence_kind := "item" if handler_id == "grant_item" else "cash"
			var consequence_message := str(inputs.get("message", ""))
			var consequence_id := "consequence:%s:%s" % [consequence_kind, _trigger_receipt(trigger)]
			var consequence_requests := _bounded_records(next.get("event_request_queue", []), MAX_RECEIPTS)
			var consequence_known := false
			for request_value in consequence_requests:
				if str(_dict(request_value).get("request_id", "")) == consequence_id: consequence_known = true
			if not consequence_known:
				var consequence := {"request_id": consequence_id, "kind": consequence_kind, "message": consequence_message}
				if consequence_kind == "item": consequence["item_id"] = str(inputs.get("item_id", ""))
				else: consequence["amount"] = int(inputs.get("amount", 0))
				consequence_requests.append(consequence)
			next["event_request_queue"] = _bounded_records(consequence_requests, MAX_RECEIPTS)
			next["last_feedback"] = consequence_message
		"change_scene_object":
			var scene_identity := OperationRegistryScript.identity(str(inputs.get("owner_namespace", "")), str(inputs.get("stable_object_id", "")))
			var scene_semantic := _dict(next.get("semantic_state", {}))
			var scene_objects := _dict(scene_semantic.get("scene_objects", {}))
			if not scene_objects.has(scene_identity):
				return {"ok": false, "state": state, "errors": ["change_scene_object target is not currently visible"]}
			var scene_object := _dict(scene_objects.get(scene_identity, {}))
			scene_object["state"] = str(inputs.get("state", ""))
			scene_objects[scene_identity] = scene_object
			scene_semantic["scene_objects"] = scene_objects
			next["semantic_state"] = scene_semantic
			next["last_feedback"] = str(inputs.get("message", ""))
			next = _queue_feedback_transition(next, str(inputs.get("message", "")), trigger)
		"play_cue":
			var cue_semantic := _dict(next.get("semantic_state", {}))
			var cue_queue := _array(cue_semantic.get("transition_queue", []))
			var cue_receipt := _trigger_receipt(trigger)
			var cue_message := str(inputs.get("message", ""))
			cue_queue.append({"op": "sound", "cue_id": str(inputs.get("cue_id", "")), "receipt_id": "%s:sound" % cue_receipt})
			cue_queue.append({
				"op": "stage", "stage_id": "action_consequence", "duration_boundaries": 1.0,
				"message": cue_message, "reduced_motion_message": cue_message,
				"receipt_id": "%s:stage" % cue_receipt,
			})
			cue_semantic["transition_queue"] = cue_queue
			next["semantic_state"] = cue_semantic
			next["last_feedback"] = cue_message
		_:
			return {"ok": false, "state": state, "errors": ["scenario handler is unregistered: %s." % handler_id]}
	return {"ok": true, "state": next, "errors": [], "replayed": handler_replayed}


static func _apply_fact(state: Dictionary, definition: Dictionary, fact_value: Dictionary, cause_fingerprint: String) -> Dictionary:
	var next := state.duplicate(false)
	var original := state
	var fact_type := str(fact_value.get("fact_type", ""))
	var payload := _dict(fact_value.get("payload", {}))
	if fact_type == "event_result" and not _event_fact_is_authorized(next, definition, payload):
		return {"ok": false, "state": original, "errors": ["scenario event_result does not match an authored payload predicate or delivered event request"]}
	var skip_phase_boundary := fact_type == "world_boundary" and int(next.get("phase_boundary_grace", 0)) > 0
	if skip_phase_boundary:
		next["phase_boundary_grace"] = 0
	for subscription_value in _array(SequenceSchemaScript.sequence(definition).get("fact_subscriptions", [])):
		var subscription := _dict(subscription_value)
		if subscription.is_empty():
			continue
		if str(subscription.get("fact_type", "")) != fact_type:
			continue
		if not _payload_predicate_matches(_dict(subscription.get("payload_equals", {})), payload):
			continue
		var handler_id := str(subscription.get("handler", "")).strip_edges()
		if handler_id.is_empty():
			continue
		var inputs := _dict(subscription.get("inputs", {}))
		var payload_key := str(inputs.get("value_from_payload", "")).strip_edges()
		if not payload_key.is_empty():
			var projection_errors := OperationRegistryScript.validate_handler_inputs(str(subscription.get("handler", "")), inputs, _dict(SequenceSchemaScript.sequence(definition).get("local_state_schema", {})), SequenceSchemaScript.reachable_outcome_ids(definition), {"source": "fact", "fact_payload_types": _dict(FACT_PAYLOAD_TYPES.get(fact_type, {})), "objective_steps": _objective_step_index(definition), "event_choices": _dict(_dict(next.get("semantic_state", {})).get("event_choices", {}))})
			if not projection_errors.is_empty(): return {"ok": false, "state": state, "errors": projection_errors}
			if not payload.has(payload_key): return {"ok": false, "state": state, "errors": ["scenario fact projection field %s is absent" % payload_key]}
			inputs["value"] = payload.get(payload_key)
			inputs.erase("value_from_payload")
		var handler_result := _run_handler(next, definition, handler_id, inputs, {"kind": "fact", "fact_type": fact_type, "fact_id": str(fact_value.get("fact_id", "")), "payload": payload})
		if not bool(handler_result.get("ok", false)):
			return handler_result
		next = _dict(handler_result.get("state", next))
	var active_objective_ids := _string_array(SequenceSchemaScript.phase(definition, str(next.get("phase_id", ""))).get("objective_ids", []))
	for objective_value in _array(SequenceSchemaScript.sequence(definition).get("objectives", [])):
		var objective := _dict(objective_value)
		if not active_objective_ids.has(str(objective.get("id", ""))):
			continue
		for step_value in _array(objective.get("steps", [])):
			var step := _dict(step_value)
			if str(step.get("kind", "")) == "fact" and str(step.get("fact_type", "")) == fact_type and _payload_predicate_matches(_dict(step.get("payload_equals", {})), payload):
				next = _complete_objective_step(next, definition, str(objective.get("id", "")), str(step.get("id", "")))
			elif str(step.get("kind", "")) == "world_boundary" and fact_type == "world_boundary" and not skip_phase_boundary:
				next = _complete_objective_step(next, definition, str(objective.get("id", "")), str(step.get("id", "")))
	if fact_type == "event_result":
		var resolution_id := str(payload.get("resolution_id", "")).strip_edges()
		if not resolution_id.is_empty() and not _event_resolution_was_requested(next, str(payload.get("event_id", "")), resolution_id):
			return {"ok": false, "state": original, "errors": ["scenario event_result does not match a delivered event request"]}
		if bool(payload.get("resolved", false)):
			var event_receipt := "%s:%s" % [resolution_id if not resolution_id.is_empty() else str(payload.get("event_id", "")), str(payload.get("choice_id", ""))]
			var event_receipts := _string_array(next.get("event_choice_receipts", []))
			_append_unique(event_receipts, event_receipt)
			next["event_choice_receipts"] = event_receipts
	if fact_type == "world_boundary":
		# Presentation stages expire on real world boundaries even when a newly
		# entered phase consumes its one-boundary progression grace.
		var fact_boundary := maxi(int(next.get("boundary_serial", 0)), int(fact_value.get("boundary_serial", 0)))
		next["active_stages"] = _unexpired_stages(next.get("active_stages", []), fact_boundary)
		if not skip_phase_boundary:
			next["phase_action_counter"] = _saturating_nonnegative_add(int(next.get("phase_action_counter", 0)), maxi(1, int(payload.get("amount", 1))))
	var trigger := {"kind": "fact", "fact_type": "world_boundary_grace" if skip_phase_boundary else fact_type, "fact_id": str(fact_value.get("fact_id", "")), "payload": payload, "cause_fingerprint": cause_fingerprint}
	var branch_result := _evaluate_branches(next, definition, trigger)
	if not bool(branch_result.get("ok", false)):
		return branch_result
	return {"ok": true, "state": _dict(branch_result.get("state", next)), "errors": []}


static func _evaluate_branches(state: Dictionary, definition: Dictionary, trigger: Dictionary) -> Dictionary:
	var next := state.duplicate(false)
	for _hop in range(SequenceSchemaScript.MAX_PHASES + 1):
		if str(next.get("status", "")) != STATUS_ACTIVE:
			return {"ok": true, "state": next, "errors": []}
		var current := SequenceSchemaScript.phase(definition, str(next.get("phase_id", "")))
		var advanced := false
		for branch_value in _array(current.get("branches", [])):
			var branch := _dict(branch_value)
			if not _condition_matches(_dict(branch.get("condition", {})), next, trigger): continue
			var branch_id := "%s:%s" % [str(next.get("phase_id", "")), str(branch.get("id", ""))]
			if not _valid_persisted_text(branch_id):
				return {"ok": false, "state": state, "errors": ["scenario resolved branch identity exceeds the persisted text boundary"]}
			var records := _array(next.get("branch_resolution_records", []))
			var resolved := _resolved_branch_ids(records)
			for legacy_id in _string_array(next.get("resolved_branches", [])): _append_unique(resolved, str(legacy_id))
			if resolved.has(branch_id): continue
			var target := str(branch.get("next_phase", "")).strip_edges()
			if not target.is_empty() and not _entry_conditions_match(SequenceSchemaScript.phase(definition, target), next, trigger): continue
			if records.size() >= MAX_RECEIPTS:
				return {"ok": false, "state": state, "errors": ["scenario branch resolution lifetime journal limit reached"]}
			var trigger_kind := str(trigger.get("kind", ""))
			var trigger_receipt_key := str(trigger.get("receipt_id", "")) if trigger_kind == "command" else str(trigger.get("fact_id", "")) if trigger_kind == "fact" else ""
			var cause_fingerprint := str(trigger.get("cause_fingerprint", ""))
			if trigger_kind not in ["command", "fact"] or trigger_receipt_key.is_empty() or cause_fingerprint.is_empty():
				return {"ok": false, "state": state, "errors": ["scenario branch resolution requires a closed command or fact cause"]}
			var outcome := str(branch.get("outcome", "")).strip_edges()
			var record := {
				"phase_id": str(next.get("phase_id", "")),
				"branch_id": str(branch.get("id", "")),
				"trigger_kind": trigger_kind,
				"trigger_receipt_key": trigger_receipt_key,
				"boundary_ordinal": records.size(),
				"branch_fingerprint": branch_content_fingerprint(branch),
				"cause_fingerprint": cause_fingerprint,
			}
			if not target.is_empty(): record["target_phase_id"] = target
			else: record["terminal_outcome"] = outcome
			records.append(record)
			next["branch_resolution_records"] = records
			next["resolved_branches"] = _resolved_branch_ids(records)
			for objective_id_value in _dict(branch.get("objective_outcomes", {})).keys():
				next = _resolve_objective(next, definition, str(objective_id_value), str(_dict(branch.get("objective_outcomes", {})).get(objective_id_value, "")))
			if not target.is_empty():
				var entered := _enter_phase(next, definition, target, branch_id, trigger)
				if not bool(entered.get("ok", false)): return entered
				next = _dict(entered.get("state", next))
				advanced = true
				break
			return _resolve_outcome(next, definition, outcome, branch_id)
		if advanced: continue
		var threshold := maxi(0, int(current.get("advance_after_actions", 0)))
		if str(trigger.get("fact_type", "")) == "world_boundary" and threshold > 0 and int(next.get("phase_action_counter", 0)) >= threshold:
			var ids := SequenceSchemaScript.phase_ids(definition)
			var index := ids.find(str(next.get("phase_id", "")))
			if index >= 0 and index + 1 < ids.size():
				var target := str(ids[index + 1])
				if _entry_conditions_match(SequenceSchemaScript.phase(definition, target), next, trigger):
					var entered := _enter_phase(next, definition, target, "ordered_compat", trigger)
					if not bool(entered.get("ok", false)): return entered
					next = _dict(entered.get("state", next))
					continue
		return {"ok": true, "state": next, "errors": []}
	return {"ok": false, "state": state, "errors": ["scenario phase graph exceeded its bounded transition count"]}


static func _condition_matches(condition: Dictionary, state: Dictionary, trigger: Dictionary) -> bool:
	match str(condition.get("type", "")):
		"always": return true
		"command": return str(trigger.get("kind", "")) == "command" and str(trigger.get("command_id", "")) == str(condition.get("command_id", ""))
		"fact": return str(trigger.get("kind", "")) == "fact" and str(trigger.get("fact_type", "")) == str(condition.get("fact_type", "")) and _payload_predicate_matches(_dict(condition.get("payload_equals", {})), _dict(trigger.get("payload", {})))
		"local_equals": return _dict(state.get("local_state", {})).get(str(condition.get("key", ""))) == condition.get("value")
		"local_min":
			var local_value: Variant = _dict(state.get("local_state", {})).get(str(condition.get("key", "")))
			return typeof(local_value) == TYPE_INT and typeof(condition.get("value")) == TYPE_INT and int(local_value) >= int(condition.get("value"))
		"objective": return _objective_step_complete(state, str(condition.get("objective_id", "")), str(condition.get("step_id", "")))
		"outcome": return _string_array(state.get("resolved_outcomes", [])).has(str(condition.get("outcome", "")))
		"receipt": return _receipt_condition_matches(condition, state)
	return false


static func _entry_conditions_match(phase_data: Dictionary, state: Dictionary, trigger: Dictionary) -> bool:
	for condition_value in _array(phase_data.get("entry_conditions", [])):
		if not _condition_matches(_dict(condition_value), state, trigger):
			return false
	return true


static func _enter_phase(state: Dictionary, definition: Dictionary, phase_id: String, source_receipt: String, entry_trigger: Dictionary = {}) -> Dictionary:
	var phase_data := SequenceSchemaScript.phase(definition, phase_id)
	if phase_data.is_empty():
		return {"ok": false, "state": state, "errors": ["scenario phase is missing: %s" % phase_id]}
	var condition_trigger := entry_trigger.duplicate(true)
	condition_trigger["source_receipt"] = source_receipt
	for condition_value in _array(phase_data.get("entry_conditions", [])):
		if not _condition_matches(_dict(condition_value), state, condition_trigger):
			return {"ok": false, "state": state, "errors": ["scenario phase %s entry conditions are not satisfied" % phase_id]}
	var next := state.duplicate(false)
	var semantic := _dict(next.get("semantic_state", {}))
	var transition_receipts := _string_array(next.get("transition_receipts", []))
	var boundary_id := "%s:%s:phase:%s:%s" % [str(next.get("scenario_id", "")), str(next.get("node_id", "")), phase_id, source_receipt]
	if not _valid_persisted_text(boundary_id) or not _valid_persisted_text(source_receipt):
		return {"ok": false, "state": state, "errors": ["scenario transition boundary exceeds the persisted text boundary"]}
	var phase_receipt := _structural_receipt("transition", [str(next.get("scenario_id", "")), str(next.get("node_id", "")), phase_id, source_receipt])
	if transition_receipts.has(phase_receipt):
		return {"ok": true, "state": next, "errors": [], "replayed": true}
	if transition_receipts.size() >= MAX_RECEIPTS:
		return {"ok": false, "state": state, "errors": ["scenario transition lifetime receipt limit reached"]}
	for family in ["scene_ops", "interaction_ops", "actor_ops", "transition_ops"]:
		var applied := OperationRegistryScript.apply_operations(semantic, family, _array(phase_data.get(family, [])), boundary_id)
		if not bool(applied.get("ok", false)):
			return {"ok": false, "state": state, "errors": _array(applied.get("errors", []))}
		semantic = _dict(applied.get("state", semantic))
	next["phase_id"] = phase_id
	next["phase_action_counter"] = 0
	# A UI command is followed by its turn boundary, which must not count twice.
	# Fact/world transitions already occur at a safe boundary, so their next real
	# boundary remains eligible for objectives and ordered compatibility advance.
	next["phase_boundary_grace"] = 1 if str(entry_trigger.get("kind", "")) == "command" else 0
	next["last_feedback"] = str(phase_data.get("arrival_feedback", ""))
	transition_receipts.append(phase_receipt)
	next["transition_receipts"] = transition_receipts
	var transition_records := _array(next.get("transition_receipt_records", []))
	transition_records.append({"receipt_key": phase_receipt, "phase_id": phase_id, "source_receipt": source_receipt, "boundary_id": boundary_id})
	next["transition_receipt_records"] = transition_records
	next["semantic_state"] = semantic
	var counters := _normalize_counters(next.get("performance_counters", {}))
	counters["transitions_prepared"] = _saturating_nonnegative_add(int(counters.get("transitions_prepared", 0)), 1)
	next["performance_counters"] = counters
	return {"ok": true, "state": next, "errors": [], "replayed": false}


static func _resolve_outcome(state: Dictionary, definition: Dictionary, outcome: String, source_receipt: String) -> Dictionary:
	if outcome.is_empty():
		return {"ok": false, "state": state, "errors": ["scenario outcome is missing"]}
	var cleanup_result := _apply_cleanup(state, definition, "terminal:%s" % source_receipt)
	if not bool(cleanup_result.get("ok", false)):
		return {"ok": false, "state": state, "errors": _array(cleanup_result.get("errors", []))}
	var next := _dict(cleanup_result.get("state", state))
	var aftermath := _dict(_dict(SequenceSchemaScript.sequence(definition).get("aftermath", {})).get(outcome, {}))
	if aftermath.is_empty():
		return {"ok": false, "state": state, "errors": ["scenario aftermath is missing for outcome %s" % outcome]}
	var semantic := _dict(next.get("semantic_state", {}))
	var aftermath_scope := "%s:%s:aftermath:%s" % [str(next.get("scenario_id", "")), str(next.get("node_id", "")), outcome]
	if not _valid_persisted_text(aftermath_scope):
		return {"ok": false, "state": state, "errors": ["scenario aftermath boundary exceeds the persisted text boundary"]}
	for family in ["scene_ops", "interaction_ops", "actor_ops", "service_ops", "game_ops", "route_ops"]:
		var applied := OperationRegistryScript.apply_operations(semantic, family, _array(aftermath.get(family, [])), aftermath_scope)
		if not bool(applied.get("ok", false)):
			return {"ok": false, "state": state, "errors": _array(applied.get("errors", []))}
		semantic = _dict(applied.get("state", semantic))
	var outcomes := _string_array(next.get("resolved_outcomes", []))
	if not outcomes.has(outcome): outcomes.append(outcome)
	next["resolved_outcomes"] = outcomes
	next = _set_objective_outcomes(next, definition, "")
	next["semantic_state"] = semantic
	next["last_feedback"] = str(aftermath.get("revisit_feedback", aftermath.get("label", "")))
	next["status"] = STATUS_AFTERMATH
	return {"ok": true, "state": next, "errors": []}


static func _apply_cleanup(state: Dictionary, definition: Dictionary, reason: String) -> Dictionary:
	var original := state
	var next := state.duplicate(false)
	var boundary_id := "%s:%s:cleanup:%s" % [str(next.get("scenario_id", "")), str(next.get("node_id", "")), reason]
	if not _valid_persisted_text(boundary_id) or not _valid_persisted_text(reason):
		return {"ok": false, "state": state, "errors": ["scenario cleanup boundary exceeds the persisted text boundary"]}
	var receipt_id := _structural_receipt("cleanup", [str(next.get("scenario_id", "")), str(next.get("node_id", "")), reason])
	var cleanup_operations := _array(_dict(SequenceSchemaScript.sequence(definition).get("cleanup", {})).get("operations", []))
	var cleanup_fingerprint := cleanup_content_fingerprint(definition, reason)
	var content_fingerprint := cleanup_definition_content_fingerprint(definition)
	var stored_content_fingerprint := str(next.get("cleanup_content_fingerprint", ""))
	if not stored_content_fingerprint.is_empty() and stored_content_fingerprint != content_fingerprint:
		return {"ok": false, "state": state, "errors": ["scenario cleanup content changed after cleanup was finalized"], "replayed": false}
	var receipts := _string_array(next.get("cleanup_receipts", []))
	if receipts.has(receipt_id):
		if str(_dict(next.get("cleanup_fingerprints", {})).get(receipt_id, "")) != cleanup_fingerprint:
			return {"ok": false, "state": state, "errors": ["scenario cleanup receipt conflicts with current cleanup content"], "replayed": false}
		return {"ok": true, "state": next, "errors": [], "replayed": true}
	if receipts.size() >= MAX_RECEIPTS:
		return {"ok": false, "state": state, "errors": ["scenario cleanup lifetime receipt limit reached"]}
	if cleanup_operations.is_empty(): return {"ok": false, "state": state, "errors": ["scenario cleanup cannot receipt an empty operation batch"]}
	if stored_content_fingerprint.is_empty():
		var semantic := _dict(next.get("semantic_state", {}))
		var by_family: Dictionary = {}
		for operation_value in cleanup_operations:
			var operation := _dict(operation_value)
			var family := str(operation.get("family", ""))
			if not OperationRegistryScript.OP_FAMILIES.has(family):
				return {"ok": false, "state": state, "errors": ["scenario cleanup contains unregistered family %s" % family]}
			if _cleanup_target_absence_is_receipted(semantic, state, definition, family, operation):
				continue
			var operations := _array(by_family.get(family, []))
			operations.append(operation)
			by_family[family] = operations
		for family in ["scene_ops", "interaction_ops", "actor_ops", "transition_ops", "service_ops", "game_ops", "route_ops"]:
			if not by_family.has(family):
				continue
			var applied := OperationRegistryScript.apply_operations(semantic, family, _array(by_family.get(family, [])), boundary_id, true)
			if not bool(applied.get("ok", false)):
				return {"ok": false, "state": state, "errors": _array(applied.get("errors", []))}
			semantic = _dict(applied.get("state", semantic))
		next["semantic_state"] = semantic
		next["cleanup_content_fingerprint"] = content_fingerprint
	receipts.append(receipt_id)
	next["cleanup_receipts"] = receipts
	var records := _array(next.get("cleanup_receipt_records", []))
	records.append({"receipt_key": receipt_id, "reason": reason, "boundary_id": boundary_id})
	next["cleanup_receipt_records"] = records
	var cleanup_fingerprints := _dict(next.get("cleanup_fingerprints", {}))
	cleanup_fingerprints[receipt_id] = cleanup_fingerprint
	_trim_dictionary_to_receipts(cleanup_fingerprints, receipts)
	next["cleanup_fingerprints"] = cleanup_fingerprints
	return {"ok": true, "state": next, "errors": [], "replayed": false}


static func _cleanup_target_absence_is_receipted(semantic: Dictionary, state: Dictionary, definition: Dictionary, family: String, cleanup_operation: Dictionary) -> bool:
	var op_id := str(cleanup_operation.get("op", ""))
	if op_id not in ["remove", "despawn"]:
		return false
	var collection_key := {
		"scene_ops": "scene_objects",
		"interaction_ops": "interactions",
		"actor_ops": "actors",
		"service_ops": "services",
		"game_ops": "games",
		"route_ops": "routes",
	}.get(family, "") as String
	var identity := OperationRegistryScript.identity_from(cleanup_operation)
	if collection_key.is_empty() or identity.is_empty() or _dict(semantic.get(collection_key, {})).has(identity):
		return false
	if _dict(_dict(semantic.get("tombstones", {})).get(collection_key, {})).has(identity):
		return true
	var receipted_authored_ids: Dictionary = {}
	for record_value in _array(_dict(state.get("semantic_state", {})).get("operation_receipt_records", [])):
		var record := _dict(record_value)
		if str(record.get("family", "")) == family:
			receipted_authored_ids[str(record.get("authored_receipt_id", ""))] = true
	var authored_scenario_identity := false
	for phase_value in _array(_dict(SequenceSchemaScript.sequence(definition).get("phase_graph", {})).get("phases", [])):
		for operation_value in _array(_dict(phase_value).get(family, [])):
			var operation := _dict(operation_value)
			if str(operation.get("owner_namespace", "")) == "scenario" \
			and str(operation.get("op", "")) not in ["remove", "despawn"] \
			and OperationRegistryScript.identity_from(operation) == identity:
				authored_scenario_identity = true
			if receipted_authored_ids.has(str(operation.get("receipt_id", ""))) \
			and str(operation.get("op", "")) in ["remove", "despawn"] \
			and OperationRegistryScript.identity_from(operation) == identity:
				return true
	return authored_scenario_identity and str(cleanup_operation.get("owner_namespace", "")) == "scenario"


static func _complete_command_objective_steps(state: Dictionary, definition: Dictionary, command_id: String) -> Dictionary:
	var next := state
	var active_objective_ids := _string_array(SequenceSchemaScript.phase(definition, str(state.get("phase_id", ""))).get("objective_ids", []))
	for objective_value in _array(SequenceSchemaScript.sequence(definition).get("objectives", [])):
		var objective := _dict(objective_value)
		if not active_objective_ids.has(str(objective.get("id", ""))):
			continue
		for step_value in _array(objective.get("steps", [])):
			var step := _dict(step_value)
			if str(step.get("kind", "")) == "command" and str(step.get("command_id", "")) == command_id:
				next = _complete_objective_step(next, definition, str(objective.get("id", "")), str(step.get("id", "")))
	return next


static func _complete_objective_step(state: Dictionary, definition: Dictionary, objective_id: String, step_id: String) -> Dictionary:
	var next := state.duplicate(false)
	var active_ids := _string_array(SequenceSchemaScript.phase(definition, str(state.get("phase_id", ""))).get("objective_ids", []))
	if not active_ids.has(objective_id):
		return next
	var objective_definition := _objective_definition(definition, objective_id)
	var ordered_steps := _array(objective_definition.get("steps", []))
	var wanted_index := -1
	for index in range(ordered_steps.size()):
		if str(_dict(ordered_steps[index]).get("id", "")) == step_id:
			wanted_index = index
			break
	if wanted_index < 0:
		return next
	var progress := _normalize_objective_progress(next.get("objective_progress", {}))
	var objective := _dict(progress.get(objective_id, {}))
	var completed := _string_array(objective.get("completed_steps", []))
	for index in range(wanted_index):
		if not completed.has(str(_dict(ordered_steps[index]).get("id", ""))):
			return next
	if not step_id.is_empty() and not completed.has(step_id): completed.append(step_id)
	objective["completed_steps"] = completed
	progress[objective_id] = objective
	next["objective_progress"] = progress
	return next


static func _resolve_objective(state: Dictionary, definition: Dictionary, objective_id: String, outcome: String) -> Dictionary:
	var next := state.duplicate(false)
	var objective_definition := _objective_definition(definition, objective_id)
	if objective_definition.is_empty() or not _string_array(objective_definition.get("outcomes", [])).has(outcome):
		return next
	var progress := _normalize_objective_progress(next.get("objective_progress", {}))
	var objective := _dict(progress.get(objective_id, {}))
	objective["outcome"] = outcome
	progress[objective_id] = objective
	next["objective_progress"] = progress
	return next


static func _objective_definition(definition: Dictionary, objective_id: String) -> Dictionary:
	for objective_value in _array(SequenceSchemaScript.sequence(definition).get("objectives", [])):
		var objective := _dict(objective_value)
		if str(objective.get("id", "")) == objective_id:
			return objective
	return {}


static func _objective_step_complete(state: Dictionary, objective_id: String, step_id: String) -> bool:
	return _string_array(_dict(_dict(state.get("objective_progress", {})).get(objective_id, {})).get("completed_steps", [])).has(step_id)


static func _set_objective_outcomes(state: Dictionary, definition: Dictionary, forced_outcome: String) -> Dictionary:
	var next := state.duplicate(false)
	var progress := _normalize_objective_progress(next.get("objective_progress", {}))
	for objective_value in _array(SequenceSchemaScript.sequence(definition).get("objectives", [])):
		var objective := _dict(objective_value)
		var objective_id := str(objective.get("id", ""))
		var allowed := _string_array(objective.get("outcomes", []))
		var objective_state := _dict(progress.get(objective_id, {}))
		var completed := _string_array(objective_state.get("completed_steps", []))
		var desired := forced_outcome
		if desired.is_empty():
			# A terminal branch or lifecycle policy may already have resolved this
			# objective. Finalizing the aftermath must preserve that exact authored
			# result instead of replacing ignore/cancel with completion-derived state.
			desired = str(objective_state.get("outcome", ""))
			if desired.is_empty():
				desired = "success" if completed.size() == _array(objective.get("steps", [])).size() else "failure"
		if not allowed.has(desired):
			desired = str(allowed[0]) if not allowed.is_empty() else ""
		objective_state["outcome"] = desired
		progress[objective_id] = objective_state
	next["objective_progress"] = progress
	return next


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


static func _phase_command_ids(state: Dictionary, definition: Dictionary, phase_id: String) -> Array:
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
	var resolved := OperationRegistryScript.resolved_semantic_state(_dict(state.get("semantic_state", {})))
	for interaction_value in _dict(resolved.get("interactions", {})).values():
		for action_value in _array(_dict(interaction_value).get("available_actions", [])):
			_append_unique(result, str(_dict(action_value).get("id", "")))
	return result


static func state_semantics_for_definition(definition: Dictionary, phase_id: String) -> Dictionary:
	var semantic: Dictionary = {
		"declared_targets": _dict(SequenceSchemaScript.sequence(definition).get("declared_targets", {})),
		"creation_owner_namespaces": _definition_creation_owner_namespaces(definition),
	}
	var phase_data := SequenceSchemaScript.phase(definition, phase_id)
	for family in ["scene_ops", "interaction_ops", "actor_ops", "transition_ops"]:
		var applied := OperationRegistryScript.apply_operations(semantic, family, _array(phase_data.get(family, [])), "definition:preview:phase:%s" % phase_id)
		semantic = _dict(applied.get("state", semantic))
	return semantic


static func _definition_creation_owner_namespaces(definition: Dictionary) -> Array:
	var result: Array = []
	var authored := SequenceSchemaScript.sequence(definition)
	for phase_value in _array(_dict(authored.get("phase_graph", {})).get("phases", [])):
		var phase_data := _dict(phase_value)
		for family in ["scene_ops", "interaction_ops", "actor_ops", "service_ops", "game_ops"]:
			for operation_value in _array(phase_data.get(family, [])):
				var operation := _dict(operation_value)
				var op_id := str(operation.get("op", ""))
				var creates: bool = family == "scene_ops" and op_id == "spawn" or family == "interaction_ops" and op_id == "add" or family == "actor_ops" and op_id == "spawn" or family in ["service_ops", "game_ops"] and op_id == "add"
				var owner := str(operation.get("owner_namespace", ""))
				if creates and not owner.is_empty() and not result.has(owner): result.append(owner)
	if result.is_empty(): result.append("scenario")
	result.sort()
	return result


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


static func _normalized_cleanup_fingerprints(value: Variant, receipts_value: Variant) -> Dictionary:
	return _normalized_receipt_fingerprints(value, receipts_value)


static func _normalized_command_results(value: Variant, receipts_value: Variant, records_value: Variant, fingerprints_value: Variant) -> Dictionary:
	var result: Dictionary = {}
	var source := _dict(value)
	var record_index: Dictionary = {}
	for record_value in _array(records_value):
		var record := _dict(record_value)
		var receipt_id := str(record.get("receipt_key", ""))
		var envelope := _dict(record.get("envelope", {}))
		var fingerprint := str(record.get("fingerprint", ""))
		if receipt_id.is_empty() or record_index.has(receipt_id) or not _valid_sha256(fingerprint) or fingerprint != _fingerprint(envelope):
			continue
		record_index[receipt_id] = record
	var fingerprints := _dict(fingerprints_value)
	for receipt_value in _bounded_strings(receipts_value, MAX_RECEIPTS):
		var receipt_id := str(receipt_value)
		var record := _dict(record_index.get(receipt_id, {}))
		var envelope := _dict(record.get("envelope", {}))
		if record.is_empty() or str(fingerprints.get(receipt_id, "")) != str(record.get("fingerprint", "")):
			continue
		var cached := _dict(source.get(receipt_id, {})).duplicate(true)
		for integer_field in ["boundary_serial", "cost"]:
			var raw: Variant = cached.get(integer_field)
			if typeof(raw) == TYPE_FLOAT and is_finite(float(raw)) and is_equal_approx(float(raw), floor(float(raw))):
				cached[integer_field] = int(raw)
		if _valid_cached_command_result(cached, receipt_id, envelope):
			result[receipt_id] = cached.duplicate(true)
	return result


static func _valid_cached_command_result(value: Dictionary, receipt_id: String, command_value: Dictionary) -> bool:
	if value.size() != COMMAND_RESULT_KEYS.size():
		return false
	for key_value in value.keys():
		if not COMMAND_RESULT_KEYS.has(str(key_value)):
			return false
	if typeof(value.get("ok")) != TYPE_BOOL or not bool(value.get("ok", false)): return false
	if typeof(value.get("replayed")) != TYPE_BOOL or bool(value.get("replayed", true)): return false
	if typeof(value.get("changed")) != TYPE_BOOL: return false
	if typeof(value.get("boundary_serial")) != TYPE_INT or int(value.get("boundary_serial", -1)) < 0: return false
	if typeof(value.get("cost")) != TYPE_INT or int(value.get("cost", -1)) < 0:
		return false
	for key in ["receipt_id", "command_id", "phase_id", "status"]:
		if typeof(value.get(key)) != TYPE_STRING or not _valid_persisted_text(str(value.get(key, ""))):
			return false
	if str(value.get("receipt_id", "")) != receipt_id or str(command_value.get("idempotency_key", "")) != receipt_id or str(value.get("command_id", "")) != str(command_value.get("command_id", "")): return false
	if typeof(value.get("state")) != TYPE_DICTIONARY or not _dict(value.get("state", {})).is_empty(): return false
	if str(value.get("status", "")) not in [STATUS_ACTIVE, STATUS_AFTERMATH, STATUS_CLEANED]: return false
	if typeof(value.get("outcomes")) != TYPE_ARRAY: return false
	var outcomes: Array = []
	for outcome_value in value.get("outcomes") as Array:
		if typeof(outcome_value) != TYPE_STRING or not _canonical_id(str(outcome_value)) or outcomes.has(str(outcome_value)): return false
		outcomes.append(str(outcome_value))
	return true


static func _normalized_receipt_fingerprints(value: Variant, receipts_value: Variant) -> Dictionary:
	var result: Dictionary = {}
	var source := _dict(value)
	for receipt_value in _bounded_strings(receipts_value, MAX_RECEIPTS):
		var receipt_id := str(receipt_value)
		var fingerprint := str(source.get(receipt_id, ""))
		if _valid_sha256(fingerprint): result[receipt_id] = fingerprint
	return result


static func _next_cause_ordinal(state: Dictionary) -> int:
	return _array(state.get("command_receipt_records", [])).size() + _array(state.get("fact_receipt_records", [])).size() + _array(state.get("visit_receipt_records", [])).size() + _array(state.get("expiry_boundary_records", [])).size()


static func _next_fact_batch_ordinal(state: Dictionary) -> int:
	return _array(state.get("fact_flush_batch_records", [])).size()


static func _reordinal_visit_records(value: Variant) -> Array:
	var result: Array = []
	for record_value in _array(value):
		var record := _dict(record_value).duplicate(true)
		record["cause_ordinal"] = result.size()
		result.append(record)
	return result


static func _valid_sha256(value: String) -> bool:
	if value.length() != 64 or value != value.to_lower(): return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102): return false
	return true


static func _valid_persisted_text(value: String) -> bool:
	return not value.is_empty() and value == value.strip_edges() and value.length() <= OperationRegistryScript.MAX_VARIANT_TEXT


static func _command_descriptor(state: Dictionary, definition: Dictionary, owner_namespace: String, stable_object_id: String, command_id: String, context: Dictionary = {}) -> Dictionary:
	var identity := OperationRegistryScript.identity(owner_namespace, stable_object_id)
	var interactions := _dict(OperationRegistryScript.resolved_semantic_state(_dict(state.get("semantic_state", {}))).get("interactions", {}))
	var interaction := _dict(interactions.get(identity, {}))
	if interaction.is_empty():
		return {"identity_present": false, "interaction_enabled": false, "action_present": false, "action": {}}
	for action_value in _array(interaction.get("available_actions", [])):
		var action := _dict(action_value)
		if str(action.get("id", "")) == command_id:
			if not _authored_action_origin_matches(state, definition, owner_namespace, stable_object_id, action):
				return {"identity_present": true, "interaction_enabled": _interaction_enabled_for_command(state, interaction, context), "action_present": false, "action": {}}
			return {"identity_present": true, "interaction_enabled": _interaction_enabled_for_command(state, interaction, context), "action_present": true, "action": action, "action_origin_owner_namespace": str(action.get("action_origin_owner_namespace", owner_namespace)), "action_origin_stable_object_id": str(action.get("action_origin_stable_object_id", stable_object_id)), "action_origin_receipt_key": str(action.get("action_origin_receipt_key", "")), "action_origin_boundary_id": str(action.get("action_origin_boundary_id", "")), "action_origin_fingerprint": str(action.get("action_origin_fingerprint", ""))}
	return {"identity_present": true, "interaction_enabled": _interaction_enabled_for_command(state, interaction, context), "action_present": false, "action": {}}


static func _interaction_enabled_for_command(state: Dictionary, interaction: Dictionary, context: Dictionary) -> bool:
	if str(interaction.get("mode", "add")) == "augment":
		var target_owner := str(interaction.get("target_owner_namespace", ""))
		var target_stable_id := str(interaction.get("target_stable_object_id", ""))
		var target_identity := OperationRegistryScript.identity(target_owner, target_stable_id)
		return _sealed_host_interaction_enabled(state, target_owner, target_stable_id) \
			and _availability_proposal_allows(context, target_identity)
	return bool(interaction.get("enabled", false))


static func _sealed_host_interaction_enabled(state: Dictionary, owner_namespace: String, stable_object_id: String) -> bool:
	var expected_identity := OperationRegistryScript.identity(owner_namespace, stable_object_id)
	if OperationRegistryScript.parse_owned_identity(expected_identity).is_empty():
		return false
	var matches: Array = []
	var semantic := _dict(state.get("semantic_state", {}))
	for record_value in _array(semantic.get("base_interactions", [])):
		var record := _dict(record_value)
		if OperationRegistryScript.identity_from(record) == expected_identity:
			matches.append(record)
	if matches.size() != 1:
		return false
	var authority := _dict(matches[0])
	return bool(authority.get("enabled", false)) and bool(authority.get("interactive", true))


static func _availability_proposal_allows(context: Dictionary, identity: String) -> bool:
	var proposals := _dict(context.get("host_interaction_availability", {}))
	if not proposals.has(identity):
		return true
	return typeof(proposals.get(identity)) == TYPE_BOOL and bool(proposals.get(identity, false))


static func _queue_feedback_transition(state: Dictionary, message: String, trigger: Dictionary) -> Dictionary:
	var next := state.duplicate(false)
	var semantic := OperationRegistryScript.normalize_semantic_state(_dict(next.get("semantic_state", {})))
	var queue := _array(semantic.get("transition_queue", []))
	queue.append({"family": "transition_ops", "op": "feedback", "channel": "feedback", "message": message, "receipt_id": "feedback:%s" % _trigger_receipt(trigger)})
	semantic["transition_queue"] = queue
	next["semantic_state"] = semantic
	return next


static func _trigger_receipt(trigger: Dictionary) -> String:
	var receipt := str(trigger.get("receipt_id", trigger.get("fact_id", trigger.get("command_id", "boundary")))).strip_edges()
	return receipt.replace(":", "_")


static func _event_resolution_was_requested(state: Dictionary, event_id: String, resolution_id: String) -> bool:
	for request_collection in ["event_request_history", "event_request_queue"]:
		for value in _bounded_records(state.get(request_collection, []), MAX_RECEIPTS):
			var request := _dict(value)
			if str(request.get("event_id", "")) == event_id and str(request.get("resolution_id", "")) == resolution_id:
				return true
	return false


static func _event_fact_is_authorized(state: Dictionary, definition: Dictionary, payload: Dictionary) -> bool:
	var event_id := str(payload.get("event_id", "")).strip_edges()
	var resolution_id := str(payload.get("resolution_id", "")).strip_edges()
	if event_id.is_empty() or not _matches_authored_event_result_payload(definition, payload, false):
		return false
	var correlated := _event_request_was_delivered(state, event_id) or not resolution_id.is_empty()
	if correlated and not _matches_authored_event_result_payload(definition, payload, true):
		return false
	if _event_request_was_delivered(state, event_id):
		return not resolution_id.is_empty() and not _event_resolution_was_consumed(state, resolution_id) and _event_resolution_was_requested(state, event_id, resolution_id)
	if not resolution_id.is_empty():
		return not _event_resolution_was_consumed(state, resolution_id) and _event_resolution_was_requested(state, event_id, resolution_id)
	return true


static func _matches_authored_event_result_payload(definition: Dictionary, payload: Dictionary, require_correlation_fields: bool) -> bool:
	var authored := SequenceSchemaScript.sequence(definition)
	for subscription_value in _array(authored.get("fact_subscriptions", [])):
		var subscription := _dict(subscription_value)
		if str(subscription.get("fact_type", "")) == "event_result" and _event_payload_predicate_matches(_dict(subscription.get("payload_equals", {})), payload, require_correlation_fields):
			return true
	for phase_value in _array(_dict(authored.get("phase_graph", {})).get("phases", [])):
		var phase_data := _dict(phase_value)
		for condition_value in _array(phase_data.get("entry_conditions", [])):
			var condition := _dict(condition_value)
			if str(condition.get("type", "")) == "fact" and str(condition.get("fact_type", "")) == "event_result" and _event_payload_predicate_matches(_dict(condition.get("payload_equals", {})), payload, require_correlation_fields):
				return true
		for branch_value in _array(phase_data.get("branches", [])):
			var condition := _dict(_dict(branch_value).get("condition", {}))
			if str(condition.get("type", "")) == "fact" and str(condition.get("fact_type", "")) == "event_result" and _event_payload_predicate_matches(_dict(condition.get("payload_equals", {})), payload, require_correlation_fields):
				return true
	for objective_value in _array(authored.get("objectives", [])):
		for step_value in _array(_dict(objective_value).get("steps", [])):
			var step := _dict(step_value)
			if str(step.get("kind", "")) == "fact" and str(step.get("fact_type", "")) == "event_result" and _event_payload_predicate_matches(_dict(step.get("payload_equals", {})), payload, require_correlation_fields):
				return true
	return false


static func _authored_event_resolution_pair(definition: Dictionary, event_id: String, resolution_id: String) -> bool:
	if not _valid_id(event_id) or not _valid_id(resolution_id):
		return false
	var predicates: Array = []
	var authored := SequenceSchemaScript.sequence(definition)
	for subscription_value in _array(authored.get("fact_subscriptions", [])):
		var subscription := _dict(subscription_value)
		if str(subscription.get("fact_type", "")) == "event_result":
			predicates.append(_dict(subscription.get("payload_equals", {})))
	for phase_value in _array(_dict(authored.get("phase_graph", {})).get("phases", [])):
		var phase_data := _dict(phase_value)
		for condition_value in _array(phase_data.get("entry_conditions", [])):
			var condition := _dict(condition_value)
			if str(condition.get("type", "")) == "fact" and str(condition.get("fact_type", "")) == "event_result":
				predicates.append(_dict(condition.get("payload_equals", {})))
		for branch_value in _array(phase_data.get("branches", [])):
			var condition := _dict(_dict(branch_value).get("condition", {}))
			if str(condition.get("type", "")) == "fact" and str(condition.get("fact_type", "")) == "event_result":
				predicates.append(_dict(condition.get("payload_equals", {})))
	for objective_value in _array(authored.get("objectives", [])):
		for step_value in _array(_dict(objective_value).get("steps", [])):
			var step := _dict(step_value)
			if str(step.get("kind", "")) == "fact" and str(step.get("fact_type", "")) == "event_result":
				predicates.append(_dict(step.get("payload_equals", {})))
	for predicate_value in predicates:
		var predicate := _dict(predicate_value)
		if str(predicate.get("event_id", "")) == event_id and str(predicate.get("resolution_id", "")) == resolution_id:
			return true
	return false


static func _event_payload_predicate_matches(predicate: Dictionary, payload: Dictionary, require_correlation_fields: bool) -> bool:
	# Broad predicates remain valid observers for legacy uncorrelated facts. Once
	# an event request supplies correlation authority, a separate discriminating
	# predicate must bind the exact supported choice and result semantics.
	if require_correlation_fields:
		for key in ["event_id", "choice_id", "resolution_id", "resolved", "ok"]:
			if not predicate.has(key):
				return false
	return _payload_predicate_matches(predicate, payload)


static func _event_request_was_delivered(state: Dictionary, event_id: String) -> bool:
	for value in _bounded_records(state.get("event_request_history", []), MAX_RECEIPTS):
		if str(_dict(value).get("event_id", "")) == event_id:
			return true
	return false


static func _event_resolution_was_consumed(state: Dictionary, resolution_id: String) -> bool:
	var prefix := "%s:" % resolution_id
	for receipt_value in _string_array(state.get("event_choice_receipts", [])):
		if str(receipt_value).begins_with(prefix):
			return true
	return false


static func _payload_predicate_matches(predicate: Dictionary, payload: Dictionary) -> bool:
	for key_value in predicate.keys():
		if not payload.has(key_value) or payload.get(key_value) != predicate.get(key_value):
			return false
	return true


static func _unexpired_stages(value: Variant, boundary_serial: int) -> Array:
	var result: Array = []
	for stage_value in _bounded_records(value, MAX_RECEIPTS):
		var stage := _dict(stage_value)
		if int(stage.get("expires_boundary", 0)) > boundary_serial: result.append(stage)
	return result


static func _authored_action_origin_matches(state: Dictionary, definition: Dictionary, owner_namespace: String, stable_object_id: String, action: Dictionary) -> bool:
	var receipt_key := str(action.get("action_origin_receipt_key", ""))
	var boundary_id := str(action.get("action_origin_boundary_id", ""))
	var fingerprint := str(action.get("action_origin_fingerprint", ""))
	if receipt_key.is_empty() or boundary_id.is_empty() or not _valid_sha256(fingerprint): return false
	var receipt_record: Dictionary = {}
	for record_value in _array(_dict(state.get("semantic_state", {})).get("operation_receipt_records", [])):
		var record := _dict(record_value)
		if str(record.get("receipt_key", "")) == receipt_key:
			receipt_record = record
			break
	if receipt_record.is_empty() or str(receipt_record.get("family", "")) != "interaction_ops" or str(receipt_record.get("boundary_id", "")) != boundary_id or str(receipt_record.get("fingerprint", "")) != fingerprint:
		return false
	var operation := _authored_interaction_operation_for_receipt(definition, receipt_record)
	if not operation.is_empty():
		var interaction := _dict(operation.get("interaction", {}))
		var target_owner := str(operation.get("target_owner_namespace", interaction.get("owner_namespace", operation.get("owner_namespace", "")))) if str(operation.get("op", "")) == "augment" else str(interaction.get("owner_namespace", operation.get("owner_namespace", "")))
		var target_stable := str(operation.get("target_stable_object_id", interaction.get("stable_object_id", operation.get("stable_object_id", "")))) if str(operation.get("op", "")) == "augment" else str(interaction.get("stable_object_id", operation.get("stable_object_id", "")))
		if target_owner != owner_namespace or target_stable != stable_object_id: return false
		var authored_actions := _array(interaction.get("available_actions", operation.get("available_actions", [])))
		for authored_value in authored_actions:
			var authored := _dict(authored_value)
			if str(authored.get("id", "")) != str(action.get("id", "")): continue
			var presented := action.duplicate(true)
			for key in ["action_origin_owner_namespace", "action_origin_stable_object_id", "action_origin_receipt_key", "action_origin_boundary_id", "action_origin_fingerprint"]: presented.erase(key)
			return _fingerprint(presented) == _fingerprint(authored) \
				and str(action.get("action_origin_owner_namespace", "")) == str(operation.get("owner_namespace", interaction.get("owner_namespace", ""))) \
				and str(action.get("action_origin_stable_object_id", "")) == str(operation.get("stable_object_id", interaction.get("stable_object_id", "")))
	return false


static func _authored_interaction_operation_for_receipt(definition: Dictionary, receipt_record: Dictionary) -> Dictionary:
	if str(receipt_record.get("family", "")) != "interaction_ops" or str(receipt_record.get("boundary_kind", "")) != "phase":
		return {}
	var operation_index := int(receipt_record.get("operation_index", -1))
	var authored_receipt_id := str(receipt_record.get("authored_receipt_id", ""))
	var fingerprint := str(receipt_record.get("fingerprint", ""))
	var boundary_id := str(receipt_record.get("boundary_id", ""))
	var source_ref := str(receipt_record.get("source_ref", ""))
	if operation_index < 0 or authored_receipt_id.is_empty() or not _valid_sha256(fingerprint):
		return {}
	var matched: Dictionary = {}
	for phase_value in _array(_dict(SequenceSchemaScript.sequence(definition).get("phase_graph", {})).get("phases", [])):
		var phase_data := _dict(phase_value)
		var phase_id := str(phase_data.get("id", ""))
		if phase_id.is_empty() or not source_ref.begins_with("%s:" % phase_id) or not boundary_id.contains(":phase:%s:" % phase_id):
			continue
		var operations := _array(phase_data.get("interaction_ops", []))
		if operation_index >= operations.size():
			continue
		var candidate := _dict(operations[operation_index])
		if str(candidate.get("receipt_id", "")) != authored_receipt_id or OperationRegistryScript.operation_fingerprint(candidate) != fingerprint:
			continue
		if not matched.is_empty():
			return {}
		matched = candidate
	return matched


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


static func _aftermath_feedback(state: Dictionary, definition: Dictionary) -> String:
	var outcomes := _string_array(state.get("resolved_outcomes", []))
	if outcomes.is_empty():
		return str(state.get("last_feedback", ""))
	var aftermath := _dict(_dict(SequenceSchemaScript.sequence(definition).get("aftermath", {})).get(outcomes[outcomes.size() - 1], {}))
	return str(aftermath.get("revisit_feedback", state.get("last_feedback", "")))


static func _lifecycle_outcome(definition: Dictionary, policy: String) -> String:
	var aftermath := _dict(SequenceSchemaScript.sequence(definition).get("aftermath", {}))
	var candidates: Array = []
	match policy:
		"fail": candidates = ["failure", "failed", "fail"]
		"ignore": candidates = ["ignore", "ignored"]
		"cancel": candidates = ["cancel", "cancelled", "canceled"]
	for candidate_value in candidates:
		if aftermath.has(str(candidate_value)):
			return str(candidate_value)
	return ""


static func _append_runtime_error(state: Dictionary, message: String) -> void:
	var errors := _bounded_strings(state.get("runtime_errors", []), 32)
	if not message.strip_edges().is_empty() and not errors.has(message):
		errors.append(message)
	state["runtime_errors"] = _bounded_strings(errors, 32)


static func _normalize_expiry_counts(value: Variant) -> Dictionary:
	var source := _dict(value)
	var result: Dictionary = {}
	for boundary_value in SequenceSchemaScript.EXPIRY_BOUNDARIES:
		var boundary := str(boundary_value)
		if boundary != "none" and source.has(boundary):
			result[boundary] = maxi(0, int(source.get(boundary, 0)))
	return result


static func _receipt_condition_matches(condition: Dictionary, state: Dictionary) -> bool:
	var receipt_kind := str(condition.get("receipt_kind", ""))
	var receipt_id := str(condition.get("receipt_id", ""))
	match receipt_kind:
		"command": return _string_array(state.get("command_receipts", [])).has(receipt_id)
		"fact": return _string_array(state.get("fact_receipts", [])).has(receipt_id)
		"operation":
			var records := _array(_dict(state.get("semantic_state", {})).get("operation_receipt_records", []))
			for record_value in records:
				var record := _dict(record_value)
				if str(record.get("authored_receipt_id", "")) == receipt_id and str(record.get("family", "")) == str(condition.get("family", "")) and str(record.get("boundary_id", "")) == str(condition.get("boundary_id", "")):
					return true
		"transition":
			for record_value in _array(state.get("transition_receipt_records", [])):
				var record := _dict(record_value)
				if str(record.get("receipt_key", "")) == receipt_id or str(record.get("source_receipt", "")) == receipt_id:
					return true
		"cleanup":
			for record_value in _array(state.get("cleanup_receipt_records", [])):
				var record := _dict(record_value)
				if str(record.get("receipt_key", "")) == receipt_id or str(record.get("reason", "")) == receipt_id:
					return true
		"visit":
			for record_value in _array(state.get("visit_receipt_records", [])):
				var record := _dict(record_value)
				if str(record.get("receipt_key", "")) == receipt_id or str(record.get("visit_id", "")) == receipt_id:
					return true
	return false


static func _without_ingress(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	result.erase("ingress_serial")
	return result


static func _fingerprint(value: Variant) -> String:
	return JSON.stringify(_canonical_variant(value)).sha256_text()


static func content_fingerprint(value: Variant) -> String:
	return _fingerprint(value)


static func base_interaction_action_authority_digest(records: Array) -> String:
	var authority: Array = []
	for record_value in records:
		var record := _dict(record_value)
		var actions: Array = []
		for action_value in _array(record.get("available_actions", [])):
			var source := _dict(action_value)
			var action: Dictionary = {}
			for key in ["id", "cost", "handler", "inputs", "requires_objective_steps", "requires_local", "action_origin_owner_namespace", "action_origin_stable_object_id", "action_origin_receipt_key", "action_origin_boundary_id", "action_origin_fingerprint"]:
				if source.has(key): action[key] = source.get(key)
			actions.append(action)
		actions.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(_canonical_variant(a)) < JSON.stringify(_canonical_variant(b)))
		authority.append({
			"owner_namespace": str(record.get("owner_namespace", "")),
			"stable_object_id": str(record.get("stable_object_id", "")),
			"enabled": bool(record.get("enabled", false)),
			"actions": actions,
		})
	authority.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(_canonical_variant(a)) < JSON.stringify(_canonical_variant(b)))
	return _fingerprint(authority)


static func branch_content_fingerprint(branch: Dictionary) -> String:
	return _fingerprint(branch)


static func fact_flush_batch_fingerprint(batch_record: Dictionary) -> String:
	var content := batch_record.duplicate(true)
	content.erase("batch_fingerprint")
	return _fingerprint(content)


static func _structural_receipt(kind: String, components: Array) -> String:
	var encoded := "%d:%s" % [kind.length(), kind]
	for component_value in components:
		var component := str(component_value)
		encoded += "%d:%s" % [component.length(), component]
	return "%s_%s" % [kind, encoded.sha256_text()]


static func _saturating_nonnegative_add(current: int, amount: int) -> int:
	var base := maxi(0, current)
	var delta := maxi(0, amount)
	return 9223372036854775807 if base > 9223372036854775807 - delta else base + delta


static func structural_runtime_receipt(kind: String, components: Array) -> String:
	return _structural_receipt(kind, components)


static func cleanup_content_fingerprint(definition: Dictionary, reason: String) -> String:
	var cleanup_operations := _array(_dict(SequenceSchemaScript.sequence(definition).get("cleanup", {})).get("operations", []))
	return _fingerprint({"reason": reason, "cleanup_operations": cleanup_operations, "definition_schema_version": int(SequenceSchemaScript.sequence(definition).get("schema_version", 0)), "sequence_signature": str(SequenceSchemaScript.sequence(definition).get("sequence_signature", ""))})


static func cleanup_definition_content_fingerprint(definition: Dictionary) -> String:
	var sequence := SequenceSchemaScript.sequence(definition)
	return _fingerprint({"cleanup_operations": _array(_dict(sequence.get("cleanup", {})).get("operations", [])), "definition_schema_version": int(sequence.get("schema_version", 0)), "sequence_signature": str(sequence.get("sequence_signature", ""))})


static func _valid_id(value: String) -> bool:
	var text := value.strip_edges()
	if text.is_empty():
		return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and code != 95 and code != 45 and code != 58:
			return false
	return true


static func _canonical_id(value: String) -> bool:
	if value != value.strip_edges() or value.is_empty() or value.length() > OperationRegistryScript.MAX_VARIANT_TEXT: return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and code != 95 and code != 45: return false
	return true


static func _fact_payload_value_matches(value: Variant, type_id: String) -> bool:
	match type_id:
		"dynamic": return OperationRegistryScript.validate_bounded_variant("scenario fact dynamic payload value", value).is_empty()
		"bool": return typeof(value) == TYPE_BOOL
		"int": return typeof(value) == TYPE_INT
		"float": return typeof(value) in [TYPE_INT, TYPE_FLOAT] and not is_nan(float(value)) and not is_inf(float(value))
		"string": return typeof(value) == TYPE_STRING and str(value).length() <= OperationRegistryScript.MAX_VARIANT_TEXT
		"string_array":
			if typeof(value) != TYPE_ARRAY: return false
			for item_value in value as Array:
				if typeof(item_value) != TYPE_STRING: return false
			return true
	return false


static func _objective_step_index(definition: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for objective_value in _array(SequenceSchemaScript.sequence(definition).get("objectives", [])):
		var objective := _dict(objective_value)
		var steps: Dictionary = {}
		for step_value in _array(objective.get("steps", [])):
			steps[str(_dict(step_value).get("id", ""))] = true
		result[str(objective.get("id", ""))] = steps
	return result


static func _normalize_counters(value: Variant) -> Dictionary:
	var source := _dict(value)
	return {"transitions_prepared": maxi(0, int(source.get("transitions_prepared", 0))), "facts_flushed": maxi(0, int(source.get("facts_flushed", 0))), "commands_applied": maxi(0, int(source.get("commands_applied", 0)))}


static func _fact_array(value: Variant) -> Array:
	var result: Array = []
	for fact_value in _array(value):
		if typeof(fact_value) == TYPE_DICTIONARY: result.append((fact_value as Dictionary).duplicate(true))
	return result


static func _bounded_records(value: Variant, _limit: int) -> Array:
	var result: Array = []
	for record_value in _array(value):
		if typeof(record_value) == TYPE_DICTIONARY:
			result.append((record_value as Dictionary).duplicate(true))
	return result


static func _normalized_integer_record_fields(value: Variant, fields: Array) -> Array:
	var result := _bounded_records(value, MAX_RECEIPTS)
	for record_value in result:
		var record := record_value as Dictionary
		for field_value in fields:
			var field := str(field_value)
			var raw: Variant = record.get(field)
			if typeof(raw) == TYPE_FLOAT and is_finite(float(raw)) and is_equal_approx(float(raw), floor(float(raw))):
				record[field] = int(raw)
	return result


static func _normalized_command_receipt_records(value: Variant) -> Array:
	var result := _normalized_integer_record_fields(value, ["cause_ordinal"])
	for record_value in result:
		var record := record_value as Dictionary
		var envelope := _dict(record.get("envelope", {})).duplicate(true)
		var schema_version_value: Variant = envelope.get("schema_version")
		if typeof(schema_version_value) == TYPE_FLOAT and is_finite(float(schema_version_value)) and is_equal_approx(float(schema_version_value), floor(float(schema_version_value))):
			envelope["schema_version"] = int(schema_version_value)
		record["envelope"] = envelope
	return result


static func _normalized_fact_receipt_records(value: Variant) -> Array:
	var result := _normalized_integer_record_fields(value, ["cause_ordinal", "flush_batch_ordinal", "flush_boundary_serial"])
	for record_value in result:
		var record := record_value as Dictionary
		var envelope := _dict(record.get("envelope", {})).duplicate(true)
		for integer_field in ["schema_version", "producer_serial", "boundary_serial"]:
			var raw: Variant = envelope.get(integer_field)
			if typeof(raw) == TYPE_FLOAT and is_finite(float(raw)) and is_equal_approx(float(raw), floor(float(raw))):
				envelope[integer_field] = int(raw)
		var payload := _dict(envelope.get("payload", {})).duplicate(true)
		var payload_types := _dict(FACT_PAYLOAD_TYPES.get(str(envelope.get("fact_type", "")), {}))
		for field_value in payload_types.keys():
			var field := str(field_value)
			var raw: Variant = payload.get(field)
			if str(payload_types.get(field, "")) == "int" and typeof(raw) == TYPE_FLOAT and is_finite(float(raw)) and is_equal_approx(float(raw), floor(float(raw))):
				payload[field] = int(raw)
		envelope["payload"] = payload
		record["envelope"] = envelope
	return result


static func _resolved_branch_ids(records: Array) -> Array:
	var result: Array = []
	for record_value in records:
		var record := _dict(record_value)
		var phase_id := str(record.get("phase_id", ""))
		var branch_id := str(record.get("branch_id", ""))
		if not phase_id.is_empty() and not branch_id.is_empty():
			_append_unique(result, "%s:%s" % [phase_id, branch_id])
	return result


static func _resolved_branch_outcomes(records: Array) -> Array:
	var result: Array = []
	for record_value in records:
		_append_unique(result, str(_dict(record_value).get("terminal_outcome", "")))
	return result


static func _normalized_event_correlations(value: Variant, event_choices: Dictionary = {}) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for record_value in _array(value):
		if result.size() >= MAX_RECEIPTS: break
		if typeof(record_value) != TYPE_DICTIONARY: continue
		var source := record_value as Dictionary
		if source.size() != 5:
			continue
		for required_key in ["correlation_key", "event_id", "resolution_id", "trigger_kind", "trigger_id"]:
			if not source.has(required_key) or typeof(source.get(required_key)) != TYPE_STRING:
				source = {}
				break
		if source.is_empty(): continue
		var event_id := str(source.get("event_id", ""))
		var resolution_id := str(source.get("resolution_id", ""))
		var trigger_kind := str(source.get("trigger_kind", ""))
		var trigger_id := str(source.get("trigger_id", ""))
		if event_id != event_id.strip_edges() or resolution_id != resolution_id.strip_edges() or not _valid_id(event_id) or not _valid_id(resolution_id) or trigger_kind not in ["command", "fact"] or not _valid_persisted_text(trigger_id):
			continue
		# event_choices proves the authored event exists. resolution_id is the
		# sequence's correlation identity, not an event choice id.
		if event_choices.is_empty() or _array(event_choices.get(event_id, [])).is_empty():
			continue
		var correlation_key := _structural_receipt("event_correlation", [event_id, resolution_id, trigger_kind, trigger_id])
		if str(source.get("correlation_key", "")) != correlation_key or seen.has(correlation_key):
			continue
		seen[correlation_key] = true
		result.append({"correlation_key": correlation_key, "event_id": event_id, "resolution_id": resolution_id, "trigger_kind": trigger_kind, "trigger_id": trigger_id})
	return result


static func _normalized_fact_queue(value: Variant, state: Dictionary) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for fact_value in _array(value):
		if typeof(fact_value) != TYPE_DICTIONARY: continue
		var queued := (fact_value as Dictionary).duplicate(true)
		if typeof(queued.get("ingress_serial")) != TYPE_INT or int(queued.get("ingress_serial", 0)) < 1: continue
		var envelope := _without_ingress(queued)
		if not OperationRegistryScript.validate_bounded_variant("persisted scenario fact", envelope).is_empty() or not validate_fact(state, envelope).is_empty(): continue
		var fact_id := str(envelope.get("fact_id", ""))
		if seen.has(fact_id) or _string_array(state.get("fact_receipts", [])).has(fact_id): continue
		seen[fact_id] = true
		result.append(queued)
	return result


static func _bounded_strings(value: Variant, _limit: int) -> Array:
	return _string_array(value)


static func _append_unique(values: Array, value: String) -> void:
	var clean := value.strip_edges()
	if not clean.is_empty() and not values.has(clean): values.append(clean)


static func _canonical_variant(value: Variant) -> Variant:
	return _canonical_variant_inner(value, 0, [])


# Public projections are wire DTOs. Godot's JSON parser materializes every JSON
# number as a float, so normalize public integer values at the producer boundary
# to keep native and Web projections byte-equivalent without weakening the
# typed canonical fingerprints used for commands, receipts, and saved state.
static func _json_projection_variant(value: Variant) -> Variant:
	return _json_projection_variant_inner(value, 0, [])


static func _json_projection_variant_inner(value: Variant, depth: int, ancestors: Array) -> Variant:
	if depth > OperationRegistryScript.MAX_VARIANT_DEPTH:
		return "<depth-limit>"
	if typeof(value) == TYPE_INT:
		return float(value)
	if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		for ancestor in ancestors:
			if is_same(ancestor, value):
				return "<cycle>"
		ancestors = ancestors.duplicate(false)
		ancestors.append(value)
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		for key_value in (value as Dictionary).keys():
			result[str(key_value)] = _json_projection_variant_inner((value as Dictionary).get(key_value), depth + 1, ancestors)
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for item in value as Array:
			result.append(_json_projection_variant_inner(item, depth + 1, ancestors))
		return result
	return value


static func _canonical_variant_inner(value: Variant, depth: int, ancestors: Array) -> Variant:
	if depth > OperationRegistryScript.MAX_VARIANT_DEPTH:
		return "<depth-limit>"
	if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		for ancestor in ancestors:
			if is_same(ancestor, value):
				return "<cycle>"
		ancestors = ancestors.duplicate(false)
		ancestors.append(value)
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		var keys := (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key_value in keys: result[str(key_value)] = _canonical_variant_inner((value as Dictionary).get(key_value), depth + 1, ancestors)
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for item in value as Array: result.append(_canonical_variant_inner(item, depth + 1, ancestors))
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
	return (value as Array).duplicate(false) if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(false) if typeof(value) == TYPE_DICTIONARY else {}
