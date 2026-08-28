class_name GameRitualRuntime
extends RefCounted

# Neutral action-boundary executor for validated game_ritual/1 definitions.
# Rules/outcomes remain in allowlisted host handlers; this class owns phase,
# request identity, receipts, staged edits, projection, and replay safety.

const SchemaScript := preload("res://scripts/core/game_ritual_schema.gd")
const RECEIPT_LIMIT := 256
const REQUEST_LIMIT := 128
const ENVELOPE_VERSION := 1
const COMMAND_KEYS := ["envelope_version", "ritual_id", "session_id", "command_id", "request_key", "action_id", "expected_phase", "source_id", "target_id", "parameters", "authenticated_action", "boundary", "receipt_key", "content_fingerprint"]
const AUTHENTICATED_ACTION_KEYS := ["action_id", "origin_owner_id", "origin_stable_id", "operation_receipt_key", "boundary_id", "content_fingerprint"]
const BOUNDARY_KEYS := ["boundary_id", "kind", "ritual_id", "session_id", "phase_id", "ordinal", "cause_receipt_key"]
const ERROR_CODES := ["invalid_envelope", "unsupported_version", "invalid_id", "unknown_reference", "stale_phase", "action_not_permitted", "disabled_action", "blocked_action", "unavailable_source", "unavailable_target", "unsealed_authority", "authority_mismatch", "ambiguous_target", "invalid_parameters", "incomplete_gesture", "out_of_bounds", "inaccessible_target", "precondition_failed", "insufficient_funds", "receipt_content_conflict", "handler_rejected", "invalid_restore", "ambiguous_transition", "internal_fail_closed"]
const STATE_KEYS := ["state_version", "contract", "ritual_id", "session_id", "phase_id", "action_sequence", "transition_sequence", "boundary_ordinal", "last_transition_id", "pending_items", "pending_history", "working_items", "last_commitment", "eligible_resolutions", "item_resolutions", "authoritative_result_refs", "actor_states", "object_states", "energy_tier", "handler_state", "readable_totals", "receipts", "envelope_receipts", "fact_envelopes", "operation_envelopes", "request_cache", "envelope_request_cache"]

var definition: Dictionary = {}
var state: Dictionary = {}
var _actions: Dictionary = {}
var _phases: Dictionary = {}
var _handlers: Dictionary = {}
var _host_handlers: Dictionary = {}
var _operations: Dictionary = {}
var _session_id := "session.default_01"
var _authenticated_actions: Dictionary = {}
var _runtime_capability := RefCounted.new()


func configure(ritual_definition: Dictionary, host_handlers: Dictionary = {}, session_id: String = "session.default_01", authenticated_actions: Dictionary = {}) -> Dictionary:
	if not definition.is_empty():
		return {"ok": false, "errors": ["ritual runtime is already configured"]}
	var errors := SchemaScript.validate_definition(ritual_definition)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	definition = ritual_definition.duplicate(true)
	_host_handlers = host_handlers.duplicate()
	_session_id = session_id
	_authenticated_actions = authenticated_actions.duplicate(true)
	_index_definition()
	state = _fresh_state()
	_apply_phase_entry(str(state.get("phase_id", "")))
	return {"ok": true, "state": state.duplicate(true), "projection": prepared_projection()}


func set_authenticated_actions(authenticated_actions: Dictionary) -> void:
	if definition.is_empty():
		_authenticated_actions = authenticated_actions.duplicate(true)


# Strict frozen-contract entry point. Caller origin data never establishes
# authority: the complete authenticated descriptor must equal the live trusted
# descriptor supplied by the host for this action.
func process_command(command: Dictionary, context: Dictionary = {}) -> Dictionary:
	var request_key := str(command.get("request_key", ""))
	var envelope_cache: Dictionary = state.get("envelope_request_cache", {})
	if envelope_cache.has(request_key):
		var cached: Dictionary = envelope_cache[request_key]
		var authenticated: Dictionary = command.get("authenticated_action", {}) if typeof(command.get("authenticated_action")) == TYPE_DICTIONARY else {}
		var trusted: Dictionary = _authenticated_actions.get(str(command.get("action_id", "")), {})
		if not _closed_shape(command, COMMAND_KEYS) or not _fingerprint(str(command.get("content_fingerprint", ""))) or canonical_fingerprint(_without_fingerprint(command)) != str(command.get("content_fingerprint", "")):
			return _envelope_rejection(command, "invalid_envelope", "Replay command envelope is invalid.", false, "none")
		if trusted.is_empty() or canonical_json(authenticated) != canonical_json(trusted):
			return _envelope_rejection(command, "authority_mismatch", "Replay action origin is not live and authenticated.", false, "none")
		if str(cached.get("command_content_fingerprint", "")) != str(command.get("content_fingerprint", "")):
			return _envelope_rejection(command, "receipt_content_conflict", "Request key is already bound to different command content.", false, "none")
		var cached_responses: Dictionary = (state.get("handler_state", {}) as Dictionary).get("_ritual_cached_responses", {})
		var cached_response: Dictionary = cached_responses.get(request_key, {})
		if cached_response.is_empty() or str(cached_response.get("content_fingerprint", "")) != str(cached.get("response_content_fingerprint", "")):
			return _envelope_rejection(command, "internal_fail_closed", "Cached response receipt is unavailable or mismatched.", false, "none")
		return cached_response.duplicate(true)
	var validation := _validate_command_envelope(command)
	if not validation.is_empty():
		return _envelope_rejection(command, str(validation.get("error_code", "invalid_envelope")), str(validation.get("message", "Invalid ritual command.")), false, "none")
	var execution_context := context.duplicate(true)
	execution_context["_ritual_command_boundary"] = (command.get("boundary", {}) as Dictionary).duplicate(true)
	execution_context["_ritual_command_receipt"] = str(command.get("receipt_key", ""))
	var before := state.duplicate(true)
	var legacy: Dictionary = _reduce_action(str(command.get("action_id", "")), command.get("parameters", {}) as Dictionary, request_key, execution_context, _runtime_capability)
	var response := _result_envelope(command, legacy) if bool(legacy.get("ok", false)) else _envelope_rejection(command, _taxonomy_code(str(legacy.get("error_code", "handler_rejected"))), str(legacy.get("message", "Action rejected.")), false, "none")
	if not bool(response.get("ok", false)):
		state = before
		return response
	envelope_cache = state.get("envelope_request_cache", {})
	envelope_cache[request_key] = {
		"request_key": request_key,
		"command_receipt_key": str(command.get("receipt_key", "")),
		"command_content_fingerprint": str(command.get("content_fingerprint", "")),
		"response_receipt_key": str(response.get("receipt_key", "")),
		"response_content_fingerprint": str(response.get("content_fingerprint", "")),
		"status": "resolved" if bool(response.get("ok", false)) else "rejected",
	}
	_trim_dictionary(envelope_cache, REQUEST_LIMIT)
	state["envelope_request_cache"] = envelope_cache
	var handler_state: Dictionary = state.get("handler_state", {})
	var cached_responses: Dictionary = handler_state.get("_ritual_cached_responses", {})
	cached_responses[request_key] = response.duplicate(true)
	handler_state["_ritual_cached_responses"] = cached_responses
	state["handler_state"] = handler_state
	if bool(response.get("ok", false)):
		state["boundary_ordinal"] = int((command.get("boundary", {}) as Dictionary).get("ordinal", state.get("boundary_ordinal", 0)))
	_append_envelope_receipt(_receipt_record(str(command.get("receipt_key", "")), str(command.get("content_fingerprint", "")), str((command.get("boundary", {}) as Dictionary).get("boundary_id", "")), "command", "accepted"))
	_append_envelope_receipt(_receipt_record(str(response.get("receipt_key", "")), str(response.get("content_fingerprint", "")), str((response.get("boundary", {}) as Dictionary).get("boundary_id", "")), "result" if bool(response.get("ok", false)) else "rejection", "accepted" if bool(response.get("ok", false)) else "rejected"))
	for fact in state.get("fact_envelopes", []):
		_append_envelope_receipt(_receipt_record(str((fact as Dictionary).get("receipt_key", "")), str((fact as Dictionary).get("content_fingerprint", "")), str(((fact as Dictionary).get("boundary", {}) as Dictionary).get("boundary_id", "")), "fact", "accepted"))
	for operation in state.get("operation_envelopes", []):
		_append_envelope_receipt(_receipt_record(str((operation as Dictionary).get("receipt_key", "")), str((operation as Dictionary).get("content_fingerprint", "")), str(((operation as Dictionary).get("boundary", {}) as Dictionary).get("boundary_id", "")), "operation", "accepted"))
	return response


func validate_command_envelope(command: Dictionary) -> Dictionary:
	return _validate_command_envelope(command)


func process_action(action_id: String, parameters: Dictionary, request_key: String, context: Dictionary = {}) -> Dictionary:
	# Compatibility guard only. All authoritative actions must enter through the
	# complete authenticated RitualCommand boundary above.
	return _rejection("unsealed_authority", action_id, request_key, "Direct ritual action authority is sealed.")


func _reduce_action(action_id: String, parameters: Dictionary, request_key: String, context: Dictionary, runtime_capability: RefCounted) -> Dictionary:
	if runtime_capability != _runtime_capability:
		return _rejection("unsealed_authority", action_id, request_key, "Ritual reducer capability is not authentic.")
	if definition.is_empty():
		return _rejection("runtime_not_configured", action_id, request_key, "Ritual runtime is not configured.")
	if not _request_key(request_key):
		return _rejection("invalid_request", action_id, request_key, "Request key is not canonical.")
	var command := {"ritual_id": str(definition.get("ritual_id", "")), "phase_id": str(state.get("phase_id", "")), "action_id": action_id, "parameters": parameters.duplicate(true), "request_key": request_key}
	# Phase is observed execution state, not caller-owned request content. Keeping it
	# out of the binding lets a successful phase-changing request replay exactly.
	var command_fingerprint := canonical_fingerprint({"ritual_id": command["ritual_id"], "action_id": action_id, "parameters": parameters, "request_key": request_key})
	var cached: Dictionary = state.get("request_cache", {}).get(request_key, {}) if typeof(state.get("request_cache", {})) == TYPE_DICTIONARY else {}
	if not cached.is_empty():
		if str(cached.get("command_fingerprint", "")) != command_fingerprint:
			return _rejection("request_conflict", action_id, request_key, "Request key was already bound to different canonical content.")
		return (cached.get("response", {}) as Dictionary).duplicate(true)
	if not _actions.has(action_id):
		return _cache_rejection(command_fingerprint, request_key, _rejection("unknown_action", action_id, request_key, "Action is not declared."))
	var declaration: Dictionary = _actions[action_id]
	var parameter_errors := _validate_parameters(parameters, declaration.get("parameters", {}))
	if not parameter_errors.is_empty():
		return _cache_rejection(command_fingerprint, request_key, _rejection("invalid_parameters", action_id, request_key, "; ".join(parameter_errors)))
	var phase: Dictionary = _phases.get(str(state.get("phase_id", "")), {})
	if not (phase.get("permitted_actions", []) as Array).has(action_id):
		return _cache_rejection(command_fingerprint, request_key, _rejection("action_out_of_phase", action_id, request_key, "Action is not permitted in the current phase."))

	var candidate := state.duplicate(true)
	var handler_id := str(declaration.get("handler_id", ""))
	var handler_result := _invoke_handler(handler_id, action_id, parameters, candidate, context)
	if not bool(handler_result.get("ok", false)):
		return _cache_rejection(command_fingerprint, request_key, _rejection(str(handler_result.get("error_code", "handler_rejected")), action_id, request_key, str(handler_result.get("message", "Handler rejected the action."))))
	var emission_error := _validate_handler_emissions(handler_id, handler_result)
	if not emission_error.is_empty():
		return _cache_rejection(command_fingerprint, request_key, _rejection("handler_contract_violation", action_id, request_key, emission_error))
	var mutation_error := _apply_handler_mutation(candidate, handler_id, handler_result)
	if not mutation_error.is_empty():
		return _cache_rejection(command_fingerprint, request_key, _rejection("handler_contract_violation", action_id, request_key, mutation_error))

	var transition := _transition_for_action(phase, action_id)
	if transition.size() > 1:
		return _cache_rejection(command_fingerprint, request_key, _rejection("ambiguous_transition", action_id, request_key, "More than one transition accepts this action."))
	var operations: Array = []
	if transition.size() == 1:
		var transition_record: Dictionary = transition[0]
		var next_phase := str(transition_record.get("next_phase", ""))
		operations.append_array(_dictionary_array(transition_record.get("operations", [])))
		candidate["phase_id"] = next_phase
		candidate["transition_sequence"] = int(candidate.get("transition_sequence", 0)) + 1
		candidate["last_transition_id"] = str(transition_record.get("id", ""))
		operations.append_array(_dictionary_array((_phases.get(next_phase, {}) as Dictionary).get("entry_operations", [])))
	operations.append_array(_dictionary_array(handler_result.get("operations", [])))
	var operation_error := _apply_operations(candidate, operations)
	if not operation_error.is_empty():
		return _cache_rejection(command_fingerprint, request_key, _rejection("operation_rejected", action_id, request_key, operation_error))

	candidate["action_sequence"] = int(candidate.get("action_sequence", 0)) + 1
	var sequence := int(candidate.get("action_sequence", 0))
	var command_receipt := _receipt("command", "ritual:command:%d" % sequence, command)
	var facts: Variant = _seal_facts(handler_result.get("facts", []), sequence, action_id, context)
	if typeof(facts) != TYPE_ARRAY:
		return _cache_rejection(command_fingerprint, request_key, _rejection("fact_rejected", action_id, request_key, "Handler emitted an invalid fact batch."))
	var result_payload: Dictionary = handler_result.get("result", {}) if typeof(handler_result.get("result", {})) == TYPE_DICTIONARY else {}
	var result_body := {"ritual_id": str(definition.get("ritual_id", "")), "action_id": action_id, "phase_id": str(candidate.get("phase_id", "")), "sequence": sequence, "payload": result_payload.duplicate(true)}
	var result_receipt := _receipt("result", "ritual:result:%d" % sequence, result_body)
	var response := {"ok": true, "action_id": action_id, "phase_id": str(candidate.get("phase_id", "")), "sequence": sequence, "request_key": request_key, "command_receipt": command_receipt, "result_receipt": result_receipt, "facts": facts, "operations": operations.duplicate(true), "result": result_payload.duplicate(true), "projection": {}}
	_append_receipt(candidate, command_receipt)
	_append_receipt(candidate, result_receipt)
	for fact in facts:
		_append_receipt(candidate, _receipt("fact", str((fact as Dictionary).get("receipt_key", "")), fact as Dictionary))
	var fact_envelopes: Array = candidate.get("fact_envelopes", [])
	fact_envelopes.append_array((facts as Array).duplicate(true))
	candidate["fact_envelopes"] = fact_envelopes
	var operation_envelopes: Array = candidate.get("operation_envelopes", [])
	for operation in operations:
		operation_envelopes.append(_operation_result_envelope(operation as Dictionary, context))
	candidate["operation_envelopes"] = operation_envelopes
	var cache: Dictionary = candidate.get("request_cache", {}) if typeof(candidate.get("request_cache", {})) == TYPE_DICTIONARY else {}
	cache[request_key] = {"command_fingerprint": command_fingerprint, "response": response.duplicate(true)}
	_trim_dictionary(cache, REQUEST_LIMIT)
	candidate["request_cache"] = cache
	state = candidate
	response["projection"] = prepared_projection()
	# Cache the final projection-bearing response only after the candidate commits.
	(state["request_cache"] as Dictionary)[request_key]["response"] = response.duplicate(true)
	return response


func restore(_serialized_state: Dictionary) -> Dictionary:
	return {"ok": false, "error_code": "invalid_restore", "errors": ["Raw ritual restore authority is sealed"]}


func _restore_state(serialized_state: Dictionary, runtime_capability: RefCounted) -> Dictionary:
	if runtime_capability != _runtime_capability:
		return {"ok": false, "error_code": "invalid_restore", "errors": ["Ritual restore capability is not authentic"]}
	if definition.is_empty():
		return {"ok": false, "errors": ["runtime is not configured"]}
	var errors := _validate_restore_state(serialized_state)
	for key in STATE_KEYS:
		if not serialized_state.has(key): errors.append("restore state is missing %s" % key)
	for key in serialized_state.keys():
		if not STATE_KEYS.has(str(key)): errors.append("restore state has unknown field %s" % key)
	if int(serialized_state.get("state_version", 0)) != 1:
		errors.append("restore state has unsupported version")
	if str(serialized_state.get("contract", "")) != SchemaScript.CONTRACT or str(serialized_state.get("ritual_id", "")) != str(definition.get("ritual_id", "")):
		errors.append("restore identity does not match configured ritual")
	if str(serialized_state.get("session_id", "")) != _session_id:
		errors.append("restore session identity does not match configured runtime")
	if not _phases.has(str(serialized_state.get("phase_id", ""))):
		errors.append("restore phase is not legal")
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	state = serialized_state.duplicate(true)
	state.erase("pointer_path")
	state.erase("hover")
	state.erase("animation_progress")
	return {"ok": true, "state": state.duplicate(true), "projection": prepared_projection(), "replayed_effects": []}


func serialized_state() -> Dictionary:
	return state.duplicate(true)


func authenticated_snapshot() -> Dictionary:
	var snapshot := {"envelope_version": 1, "ritual_id": str(definition.get("ritual_id", "")), "session_id": _session_id, "state": state.duplicate(true), "content_fingerprint": ""}
	snapshot["content_fingerprint"] = canonical_fingerprint(_without_fingerprint(snapshot))
	return snapshot


func restore_snapshot(snapshot: Dictionary) -> Dictionary:
	var keys := ["envelope_version", "ritual_id", "session_id", "state", "content_fingerprint"]
	if not _closed_shape(snapshot, keys): return {"ok": false, "error_code": "invalid_restore", "errors": ["restore snapshot has invalid closed shape"]}
	if int(snapshot.get("envelope_version", 0)) != 1: return {"ok": false, "error_code": "invalid_restore", "errors": ["restore snapshot version requires an explicit unavailable migration"]}
	if str(snapshot.get("ritual_id", "")) != str(definition.get("ritual_id", "")) or str(snapshot.get("session_id", "")) != _session_id: return {"ok": false, "error_code": "invalid_restore", "errors": ["restore snapshot identity mismatch"]}
	if typeof(snapshot.get("state")) != TYPE_DICTIONARY or not _fingerprint(str(snapshot.get("content_fingerprint", ""))) or canonical_fingerprint(_without_fingerprint(snapshot)) != str(snapshot.get("content_fingerprint", "")):
		return {"ok": false, "error_code": "invalid_restore", "errors": ["restore snapshot fingerprint mismatch"]}
	var before := state.duplicate(true)
	var result := _restore_state(snapshot.get("state", {}) as Dictionary, _runtime_capability)
	if not bool(result.get("ok", false)):
		state = before
		result["error_code"] = "invalid_restore"
	return result


func prepared_projection() -> Dictionary:
	return {
		"contract": SchemaScript.CONTRACT,
		"ritual_id": str(definition.get("ritual_id", "")),
		"phase_id": str(state.get("phase_id", "")),
		"pending_items": (state.get("pending_items", {}) as Dictionary).duplicate(true),
		"working_items": (state.get("working_items", {}) as Dictionary).duplicate(true),
		"item_resolutions": _dictionary_array(state.get("item_resolutions", [])),
		"readable_totals": (state.get("readable_totals", {}) as Dictionary).duplicate(true),
		"actors": _actor_projection(),
		"scene_objects": _object_projection(),
		"energy_tier": str(state.get("energy_tier", "")),
		"pointer_verbs": _pointer_projection(),
		"action_sequence": int(state.get("action_sequence", 0)),
	}


func set_energy_tier(tier_id: String, request_key: String) -> Dictionary:
	return {"ok": false, "error_code": "unsealed_authority", "energy_tier": tier_id, "request_key": request_key}


func _apply_energy_tier(tier_id: String, request_key: String, runtime_capability: RefCounted) -> Dictionary:
	if runtime_capability != _runtime_capability:
		return {"ok": false, "error_code": "unsealed_authority"}
	var energy: Dictionary = definition.get("energy", {}) if typeof(definition.get("energy", {})) == TYPE_DICTIONARY else {}
	for tier in _dictionary_array(energy.get("tiers", [])):
		if str(tier.get("id", "")) != tier_id:
			continue
		var fingerprint := canonical_fingerprint({"tier_id": tier_id, "request_key": request_key})
		var key := "energy:%s" % request_key
		var cache: Dictionary = state.get("request_cache", {})
		if cache.has(key):
			return (cache[key].get("response", {}) as Dictionary).duplicate(true) if str(cache[key].get("command_fingerprint", "")) == fingerprint else {"ok": false, "error_code": "request_conflict"}
		var candidate := state.duplicate(true)
		var operations: Array = []
		for operation_key in ["actor_operations", "object_operations", "interaction_operations"]:
			operations.append_array(_dictionary_array(tier.get(operation_key, [])))
		var error := _apply_operations(candidate, operations)
		if not error.is_empty():
			return {"ok": false, "error_code": "operation_rejected", "message": error}
		candidate["energy_tier"] = tier_id
		var response := {"ok": true, "energy_tier": tier_id, "operations": operations, "projection": {}}
		cache = candidate.get("request_cache", {})
		cache[key] = {"command_fingerprint": fingerprint, "response": response.duplicate(true)}
		candidate["request_cache"] = cache
		state = candidate
		response["projection"] = prepared_projection()
		(state["request_cache"] as Dictionary)[key]["response"] = response.duplicate(true)
		return response
	return {"ok": false, "error_code": "unknown_energy_tier"}


static func canonical_json(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if bool(value) else "false"
		TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return JSON.stringify(value)
		TYPE_ARRAY:
			var items: Array[String] = []
			for item in value:
				items.append(canonical_json(item))
			return "[%s]" % ",".join(items)
		TYPE_DICTIONARY:
			var source: Dictionary = value
			var keys: Array[String] = []
			for key in source.keys():
				keys.append(str(key))
			keys.sort()
			var members: Array[String] = []
			for key in keys:
				members.append("%s:%s" % [JSON.stringify(key), canonical_json(source.get(key))])
			return "{%s}" % ",".join(members)
	return ""


static func canonical_fingerprint(value: Variant) -> String:
	return canonical_json(value).sha256_text()


func _fresh_state() -> Dictionary:
	var actor_states := {}
	for actor in _dictionary_array(definition.get("actors", [])):
		actor_states[str(actor.get("id", ""))] = {"pose": str(actor.get("initial_pose", "")), "behavior": str(actor.get("initial_behavior", "")), "anchor": str(actor.get("anchor", "")), "attention": "neutral"}
	var object_states := {}
	for object in _dictionary_array(definition.get("scene_objects", [])):
		object_states[str(object.get("id", ""))] = {"visual": str(object.get("initial_visual_state", "")), "functional": str(object.get("initial_functional_state", "")), "visible": true, "enabled": true}
	return {"state_version": 1, "contract": SchemaScript.CONTRACT, "ritual_id": str(definition.get("ritual_id", "")), "session_id": _session_id, "phase_id": str(definition.get("initial_phase", "")), "action_sequence": 0, "transition_sequence": 0, "boundary_ordinal": 0, "last_transition_id": "", "pending_items": {}, "pending_history": [], "working_items": {}, "last_commitment": {}, "eligible_resolutions": {}, "item_resolutions": [], "authoritative_result_refs": [], "actor_states": actor_states, "object_states": object_states, "energy_tier": str((definition.get("energy", {}) as Dictionary).get("initial_tier", "")), "handler_state": {}, "readable_totals": {"available_funds": 0, "pending_total": 0, "at_risk_total": 0, "returned_stake": 0, "payout": 0, "net_change": 0}, "receipts": [], "envelope_receipts": [], "fact_envelopes": [], "operation_envelopes": [], "request_cache": {}, "envelope_request_cache": {}}


func _index_definition() -> void:
	_actions.clear()
	_phases.clear()
	_handlers.clear()
	_operations.clear()
	for action in _dictionary_array(definition.get("action_declarations", [])):
		_actions[str(action.get("action_id", ""))] = action
	for phase in _dictionary_array(definition.get("ritual_phases", [])):
		_phases[str(phase.get("id", ""))] = phase
		for operation in _dictionary_array(phase.get("entry_operations", [])):
			_operations[str(operation.get("operation_id", ""))] = operation
		for transition in _dictionary_array(phase.get("transitions", [])):
			for operation in _dictionary_array(transition.get("operations", [])):
				_operations[str(operation.get("operation_id", ""))] = operation
	for handler in _dictionary_array(definition.get("handler_registry", [])):
		_handlers[str(handler.get("handler_id", ""))] = handler
	for tier in _dictionary_array((definition.get("energy", {}) as Dictionary).get("tiers", [])):
		for key in ["actor_operations", "object_operations", "interaction_operations"]:
			for operation in _dictionary_array(tier.get(key, [])):
				_operations[str(operation.get("operation_id", ""))] = operation


func _invoke_handler(handler_id: String, action_id: String, parameters: Dictionary, candidate: Dictionary, context: Dictionary) -> Dictionary:
	if handler_id == "commitment.edit":
		return _builtin_commitment(action_id, parameters, candidate, context)
	if handler_id == "resolution.ack":
		return {"ok": true, "result": {}, "operations": [], "facts": []}
	var callback: Variant = _host_handlers.get(handler_id)
	if typeof(callback) != TYPE_CALLABLE or not (callback as Callable).is_valid():
		return {"ok": false, "error_code": "handler_unavailable", "message": "No allowlisted host handler is bound."}
	var response: Variant = (callback as Callable).call(action_id, parameters.duplicate(true), candidate.duplicate(true), context.duplicate(true))
	return (response as Dictionary).duplicate(true) if typeof(response) == TYPE_DICTIONARY else {"ok": false, "error_code": "handler_contract_violation", "message": "Handler did not return a record."}


func _validate_handler_emissions(handler_id: String, handler_result: Dictionary) -> String:
	var declaration: Dictionary = _handlers.get(handler_id, {})
	var accepted_operations: Array = declaration.get("accepted_operations", [])
	for operation in _dictionary_array(handler_result.get("operations", [])):
		if not accepted_operations.has(str(operation.get("operation_id", ""))):
			return "Handler %s emitted operation outside its allowlist." % handler_id
	var emitted_facts: Array = declaration.get("emitted_facts", [])
	for fact in _dictionary_array(handler_result.get("facts", [])):
		if not emitted_facts.has(str(fact.get("fact_type", ""))):
			return "Handler %s emitted fact outside its allowlist." % handler_id
	return ""


func _builtin_commitment(action_id: String, parameters: Dictionary, candidate: Dictionary, context: Dictionary) -> Dictionary:
	var pending: Dictionary = candidate.get("pending_items", {}).duplicate(true)
	var history: Array = candidate.get("pending_history", []).duplicate(true)
	var item_id := str(parameters.get("item_id", ""))
	var amount := maxi(0, int(parameters.get("amount", 0)))
	var available := maxi(0, int(context.get("available_funds", (candidate.get("readable_totals", {}) as Dictionary).get("available_funds", 0))))
	match action_id:
		"commit.place":
			history.append(pending.duplicate(true)); pending[item_id] = int(pending.get(item_id, 0)) + amount
		"commit.correct":
			history.append(pending.duplicate(true)); pending[item_id] = amount
		"commit.remove":
			if not pending.has(item_id): return {"ok": false, "error_code": "missing_item", "message": "Pending item is absent."}
			history.append(pending.duplicate(true)); pending.erase(item_id)
		"commit.undo":
			if history.is_empty(): return {"ok": false, "error_code": "nothing_to_undo", "message": "No pending edit can be undone."}
			pending = history.pop_back()
		"commit.clear":
			history.append(pending.duplicate(true)); pending = {}
		"commit.repeat":
			pending = (candidate.get("last_commitment", {}) as Dictionary).duplicate(true)
		"commit.rebet":
			pending = (candidate.get("eligible_resolutions", {}) as Dictionary).duplicate(true)
		"commit.confirm":
			if pending.is_empty(): return {"ok": false, "error_code": "empty_commitment", "message": "No pending commitment exists."}
	var total := _sum_positive(pending)
	if total > available:
		return {"ok": false, "error_code": "insufficient_funds", "message": "Pending commitment exceeds available funds."}
	var persisted := {"pending_items": pending, "pending_history": history}
	if action_id == "commit.confirm":
		persisted["working_items"] = pending.duplicate(true)
		persisted["last_commitment"] = pending.duplicate(true)
		persisted["pending_items"] = {}
		persisted["pending_history"] = []
	return {"ok": true, "persisted_state": persisted, "result": {"pending_total": 0 if action_id == "commit.confirm" else total, "at_risk_total": total if action_id == "commit.confirm" else _sum_positive(candidate.get("working_items", {}))}, "facts": [], "operations": []}


func _apply_handler_mutation(candidate: Dictionary, handler_id: String, handler_result: Dictionary) -> String:
	var mutation: Dictionary = handler_result.get("persisted_state", {}) if typeof(handler_result.get("persisted_state", {})) == TYPE_DICTIONARY else {}
	var allowed: Array = (_handlers.get(handler_id, {}) as Dictionary).get("persisted_state", [])
	# Built-in commitment owns the vocabulary collections named by the contract.
	if handler_id == "commitment.edit":
		allowed = ["pending_items", "pending_history", "working_items", "last_commitment", "eligible_resolutions", "item_resolutions", "readable_totals"]
	for key in mutation.keys():
		if not allowed.has(str(key)):
			return "Handler attempted undeclared persisted field %s." % key
		candidate[key] = mutation[key].duplicate(true) if typeof(mutation[key]) in [TYPE_ARRAY, TYPE_DICTIONARY] else mutation[key]
	var result: Dictionary = handler_result.get("result", {}) if typeof(handler_result.get("result", {})) == TYPE_DICTIONARY else {}
	var totals: Dictionary = candidate.get("readable_totals", {}).duplicate(true)
	for key in ["available_funds", "pending_total", "at_risk_total", "returned_stake", "payout", "net_change"]:
		if result.has(key): totals[key] = int(result.get(key, 0))
	totals["pending_total"] = _sum_positive(candidate.get("pending_items", {}))
	totals["at_risk_total"] = _sum_positive(candidate.get("working_items", {}))
	candidate["readable_totals"] = totals
	return ""


func _apply_operations(candidate: Dictionary, operations: Array) -> String:
	for operation in operations:
		var family := str(operation.get("family", ""))
		var verb := str(operation.get("verb", ""))
		var target := str(operation.get("target_id", ""))
		var arguments: Dictionary = operation.get("arguments", {}) if typeof(operation.get("arguments", {})) == TYPE_DICTIONARY else {}
		if family == "actor_ops":
			var actors: Dictionary = candidate.get("actor_states", {})
			if not actors.has(target): return "Actor operation target is absent."
			var actor: Dictionary = actors[target]
			if verb == "set_pose": actor["pose"] = str(arguments.get("pose", ""))
			elif verb == "set_behavior": actor["behavior"] = str(arguments.get("behavior", ""))
			elif verb == "set_position": actor["anchor"] = str(arguments.get("anchor", actor.get("anchor", "")))
			elif verb in ["despawn"]: actor["visible"] = false
			elif verb in ["spawn"]: actor["visible"] = true
			else: return "Actor operation verb is not projectable."
			actors[target] = actor; candidate["actor_states"] = actors
		elif family == "scene_ops":
			var objects: Dictionary = candidate.get("object_states", {})
			if not objects.has(target): return "Scene operation target is absent."
			var object: Dictionary = objects[target]
			if verb == "set_state": object[str(arguments.get("state_slot", "visual"))] = str(arguments.get("state", ""))
			elif verb == "set_visibility": object["visible"] = bool(arguments.get("visible", true))
			elif verb == "set_enabled": object["enabled"] = bool(arguments.get("enabled", true))
			elif verb == "move" or verb == "set_position": object["anchor"] = str(arguments.get("anchor", object.get("anchor", "")))
			elif verb == "remove": object["visible"] = false
			elif verb == "spawn": object["visible"] = true
			else: return "Scene operation verb is not projectable."
			objects[target] = object; candidate["object_states"] = objects
		elif family == "interaction_ops":
			var objects: Dictionary = candidate.get("object_states", {})
			if objects.has(target):
				var object: Dictionary = objects[target]; object["enabled"] = verb not in ["remove", "gate"] or bool(arguments.get("enabled", false)); objects[target] = object; candidate["object_states"] = objects
		elif family == "transition_ops":
			var cues: Array = candidate.get("one_shot_cues", []); cues.append({"operation_id": str(operation.get("operation_id", "")), "sequence": int(candidate.get("action_sequence", 0)) + 1}); candidate["one_shot_cues"] = cues
	return ""


func _apply_phase_entry(phase_id: String) -> void:
	if not _phases.has(phase_id): return
	_apply_operations(state, _dictionary_array((_phases[phase_id] as Dictionary).get("entry_operations", [])))


func _transition_for_action(phase: Dictionary, action_id: String) -> Array:
	var result: Array = []
	for transition in _dictionary_array(phase.get("transitions", [])):
		var condition: Dictionary = transition.get("condition", {})
		if str(condition.get("kind", "")) == "accepted_action" and str(condition.get("action_id", "")) == action_id: result.append(transition)
	return result


func _seal_facts(value: Variant, sequence: int, action_id: String, context: Dictionary = {}) -> Variant:
	if typeof(value) != TYPE_ARRAY: return null
	var declared := {}
	for fact in _dictionary_array(definition.get("game_facts", [])): declared[str(fact.get("fact_type", ""))] = fact
	var result: Array = []
	var seen := {}
	for raw in value:
		if typeof(raw) != TYPE_DICTIONARY: return null
		var fact: Dictionary = raw
		var type := str(fact.get("fact_type", ""))
		if not declared.has(type) or seen.has(type): return null
		var payload: Dictionary = fact.get("payload", {}) if typeof(fact.get("payload", {})) == TYPE_DICTIONARY else {}
		if not _validate_parameters(payload, (declared[type] as Dictionary).get("payload", {})).is_empty(): return null
		seen[type] = true
		var boundary: Dictionary = context.get("_ritual_command_boundary", {}) if typeof(context.get("_ritual_command_boundary", {})) == TYPE_DICTIONARY else {}
		if boundary.is_empty(): boundary = {"boundary_id": "boundary.command.%d" % sequence, "kind": "command", "ritual_id": str(definition.get("ritual_id", "")), "session_id": _session_id, "phase_id": str(state.get("phase_id", "")), "ordinal": int(state.get("boundary_ordinal", 0)) + 1, "cause_receipt_key": "receipt:command:%d" % sequence}
		var record := {"envelope_version": 1, "fact_id": "fact.%s_%d" % [type.replace(".", "_"), sequence], "fact_type": type, "fact_version": int((declared[type] as Dictionary).get("fact_version", 1)), "payload": payload.duplicate(true), "visibility": "public", "boundary": boundary.duplicate(true), "receipt_key": "receipt:fact:%s_%d" % [type.replace(".", "_"), sequence], "content_fingerprint": ""}
		record["content_fingerprint"] = canonical_fingerprint(_without_fingerprint(record))
		result.append(record)
	return result


func _receipt(kind: String, key: String, content: Dictionary) -> Dictionary:
	var receipt := {"receipt_kind": kind, "receipt_key": key, "content_fingerprint": canonical_fingerprint(content)}
	return receipt


func _append_receipt(candidate: Dictionary, receipt: Dictionary) -> void:
	var receipts: Array = candidate.get("receipts", [])
	receipts.append(receipt.duplicate(true))
	while receipts.size() > RECEIPT_LIMIT: receipts.pop_front()
	candidate["receipts"] = receipts


func _rejection(error_code: String, action_id: String, request_key: String, message: String) -> Dictionary:
	var body := {"ok": false, "action_id": action_id, "phase_id": str(state.get("phase_id", "")), "request_key": request_key, "error_code": error_code, "message": message}
	body["rejection_receipt"] = _receipt("rejection", "ritual:rejection:%s" % request_key, body)
	return body


func _cache_rejection(command_fingerprint: String, request_key: String, response: Dictionary) -> Dictionary:
	var cache: Dictionary = state.get("request_cache", {})
	cache[request_key] = {"command_fingerprint": command_fingerprint, "response": response.duplicate(true)}
	_trim_dictionary(cache, REQUEST_LIMIT)
	state["request_cache"] = cache
	return response


func _validate_parameters(parameters: Dictionary, schema_value: Variant) -> Array[String]:
	var schema: Dictionary = schema_value if typeof(schema_value) == TYPE_DICTIONARY else {}
	var errors: Array[String] = []
	for key in parameters.keys():
		if not schema.has(key): errors.append("unknown parameter %s" % key)
	for key in schema.keys():
		if not parameters.has(key): errors.append("missing parameter %s" % key)
		elif not _value_matches(parameters[key], schema[key]): errors.append("parameter %s violates its declared type or bounds" % key)
	return errors


func _value_matches(value: Variant, descriptor_value: Variant) -> bool:
	if typeof(descriptor_value) != TYPE_DICTIONARY:
		return false
	var descriptor: Dictionary = descriptor_value
	match str(descriptor.get("type", "")):
		"bool": return typeof(value) == TYPE_BOOL
		"int": return typeof(value) == TYPE_INT and int(value) >= int(descriptor.get("min", 0)) and int(value) <= int(descriptor.get("max", 0))
		"float": return typeof(value) == TYPE_FLOAT and is_finite(float(value)) and float(value) >= float(descriptor.get("min", 0.0)) and float(value) <= float(descriptor.get("max", 0.0))
		"string":
			if typeof(value) != TYPE_STRING: return false
			var byte_length := str(value).to_utf8_buffer().size()
			return byte_length >= int(descriptor.get("min_length", 0)) and byte_length <= int(descriptor.get("max_length", 0))
		"qualified_id": return typeof(value) == TYPE_STRING and str(value).length() <= int(descriptor.get("max_length", 0)) and _qualified_id(str(value))
		"string_array":
			if typeof(value) != TYPE_ARRAY or (value as Array).size() < int(descriptor.get("min_items", 0)) or (value as Array).size() > int(descriptor.get("max_items", 0)): return false
			return (value as Array).all(func(item): return typeof(item) == TYPE_STRING and str(item).to_utf8_buffer().size() <= int(descriptor.get("item_max_length", 0)))
		"int_array":
			if typeof(value) != TYPE_ARRAY or (value as Array).size() < int(descriptor.get("min_items", 0)) or (value as Array).size() > int(descriptor.get("max_items", 0)): return false
			return (value as Array).all(func(item): return typeof(item) == TYPE_INT and int(item) >= int(descriptor.get("item_min", 0)) and int(item) <= int(descriptor.get("item_max", 0)))
	return false


func _actor_projection() -> Array:
	var result: Array = []
	for actor in _dictionary_array(definition.get("actors", [])):
		var record: Dictionary = actor.duplicate(true)
		var actor_state: Dictionary = (state.get("actor_states", {}) as Dictionary).get(str(actor.get("id", "")), {})
		record["state"] = actor_state.duplicate(true)
		result.append(record)
	return result


func _object_projection() -> Array:
	var result: Array = []
	for object in _dictionary_array(definition.get("scene_objects", [])):
		var record: Dictionary = object.duplicate(true)
		var object_state: Dictionary = (state.get("object_states", {}) as Dictionary).get(str(object.get("id", "")), {})
		record["state"] = object_state.duplicate(true)
		result.append(record)
	return result


func _pointer_projection() -> Array:
	var phase := str(state.get("phase_id", "")); var result: Array = []
	for pointer in _dictionary_array(definition.get("pointer_verbs", [])):
		if (pointer.get("phases", []) as Array).has(phase): result.append(pointer.duplicate(true))
	return result


func _sum_positive(value: Variant) -> int:
	var total := 0
	if typeof(value) == TYPE_DICTIONARY:
		for amount in (value as Dictionary).values(): total += maxi(0, int(amount))
	return total


func _trim_dictionary(value: Dictionary, limit: int) -> void:
	while value.size() > limit: value.erase(value.keys()[0])


func _request_key(value: String) -> bool:
	if value.is_empty() or value.length() > 192: return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and not [58, 45, 46, 95].has(code): return false
	return true


func _qualified_id(value: String) -> bool:
	var atoms := value.split(".", false)
	if atoms.size() < 2 or value.length() > 192: return false
	for atom in atoms:
		if atom.is_empty() or atom.length() > 64: return false
		for index in range(atom.length()):
			var code := atom.unicode_at(index)
			if index == 0:
				if code < 97 or code > 122: return false
			elif not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and code != 95:
				return false
	return true


func _fingerprint(value: String) -> bool:
	if value.length() != 64: return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102): return false
	return true


func _validate_command_envelope(command: Dictionary) -> Dictionary:
	if not _closed_shape(command, COMMAND_KEYS): return _validation_error("invalid_envelope", "RitualCommand has unknown or missing fields.")
	if int(command.get("envelope_version", 0)) != ENVELOPE_VERSION: return _validation_error("unsupported_version", "RitualCommand envelope_version must be 1.")
	for key in ["ritual_id", "session_id", "command_id", "action_id", "source_id", "target_id"]:
		if typeof(command.get(key)) != TYPE_STRING or not _qualified_id(str(command.get(key, ""))): return _validation_error("invalid_id", "RitualCommand %s is not a canonical qualified id." % key)
	if str(command.get("ritual_id", "")) != str(definition.get("ritual_id", "")) or str(command.get("session_id", "")) != _session_id:
		return _validation_error("authority_mismatch", "RitualCommand identity does not match the live runtime.")
	if not _request_key(str(command.get("request_key", ""))) or not _request_key(str(command.get("receipt_key", ""))): return _validation_error("invalid_id", "RitualCommand request or receipt key is invalid.")
	if typeof(command.get("parameters")) != TYPE_DICTIONARY: return _validation_error("invalid_parameters", "RitualCommand parameters must be a dictionary.")
	var action_id := str(command.get("action_id", ""))
	if not _actions.has(action_id): return _validation_error("unknown_reference", "RitualCommand action is undeclared.")
	if str(command.get("expected_phase", "")) != str(state.get("phase_id", "")): return _validation_error("stale_phase", "RitualCommand expected_phase is stale.")
	var parameter_errors := _validate_parameters(command.get("parameters", {}) as Dictionary, (_actions[action_id] as Dictionary).get("parameters", {}))
	if not parameter_errors.is_empty(): return _validation_error("invalid_parameters", "; ".join(parameter_errors))
	var targets: Dictionary = definition.get("declared_targets", {})
	var allowed_references: Array = []
	for kind in ["regions", "sealed_host_targets"]: allowed_references.append_array(targets.get(kind, []) as Array)
	if not allowed_references.has(str(command.get("source_id", ""))): return _validation_error("unavailable_source", "RitualCommand source is not in the live sealed inventory.")
	if not allowed_references.has(str(command.get("target_id", ""))): return _validation_error("unavailable_target", "RitualCommand target is not in the live sealed inventory.")
	var authenticated: Dictionary = command.get("authenticated_action", {}) if typeof(command.get("authenticated_action")) == TYPE_DICTIONARY else {}
	if not _closed_shape(authenticated, AUTHENTICATED_ACTION_KEYS): return _validation_error("invalid_envelope", "Authenticated action has unknown or missing fields.")
	for key in ["action_id", "origin_owner_id", "origin_stable_id"]:
		if not _qualified_id(str(authenticated.get(key, ""))): return _validation_error("invalid_id", "Authenticated action %s is invalid." % key)
	for key in ["operation_receipt_key", "boundary_id"]:
		if not _request_key(str(authenticated.get(key, ""))): return _validation_error("invalid_id", "Authenticated action %s is invalid." % key)
	if not _fingerprint(str(authenticated.get("content_fingerprint", ""))): return _validation_error("invalid_envelope", "Authenticated action fingerprint is invalid.")
	var trusted: Dictionary = _authenticated_actions.get(action_id, {})
	if trusted.is_empty(): return _validation_error("unsealed_authority", "No live authenticated action is bound.")
	if canonical_json(authenticated) != canonical_json(trusted): return _validation_error("authority_mismatch", "Caller action origin does not match the live authenticated action.")
	var boundary: Dictionary = command.get("boundary", {}) if typeof(command.get("boundary")) == TYPE_DICTIONARY else {}
	var boundary_error := _validate_boundary(boundary, command)
	if not boundary_error.is_empty(): return boundary_error
	if not _fingerprint(str(command.get("content_fingerprint", ""))) or canonical_fingerprint(_without_fingerprint(command)) != str(command.get("content_fingerprint", "")):
		return _validation_error("receipt_content_conflict", "RitualCommand canonical fingerprint mismatch.")
	return {}


func _validate_boundary(boundary: Dictionary, command: Dictionary) -> Dictionary:
	if not _closed_shape(boundary, BOUNDARY_KEYS): return _validation_error("invalid_envelope", "RitualBoundary has unknown or missing fields.")
	if str(boundary.get("kind", "")) not in ["phase_entry", "fact_flush", "command", "cleanup", "aftermath_application"]: return _validation_error("invalid_envelope", "RitualBoundary kind is invalid.")
	if str(boundary.get("kind", "")) != "command" or str(boundary.get("ritual_id", "")) != str(definition.get("ritual_id", "")) or str(boundary.get("session_id", "")) != _session_id or str(boundary.get("phase_id", "")) != str(state.get("phase_id", "")):
		return _validation_error("authority_mismatch", "RitualBoundary does not identify the live command boundary.")
	if int(boundary.get("ordinal", -1)) != int(state.get("boundary_ordinal", 0)) + 1: return _validation_error("stale_phase", "RitualBoundary ordinal is not the next durable boundary.")
	if str(boundary.get("cause_receipt_key", "")) != str(command.get("receipt_key", "")) or not _request_key(str(boundary.get("boundary_id", ""))): return _validation_error("invalid_envelope", "RitualBoundary cause or id is invalid.")
	return {}


func _result_envelope(command: Dictionary, legacy: Dictionary) -> Dictionary:
	var phase_before := str(command.get("expected_phase", ""))
	var result_payload: Dictionary = legacy.get("result", {})
	var result_ref := str(result_payload.get("result_id", "result.command_%d" % int(legacy.get("sequence", 0))))
	if not _qualified_id(result_ref): result_ref = "result.command_%d" % int(legacy.get("sequence", 0))
	var envelope := {
		"envelope_version": ENVELOPE_VERSION, "ok": true, "ritual_id": str(command.get("ritual_id", "")), "session_id": str(command.get("session_id", "")), "command_id": str(command.get("command_id", "")), "request_key": str(command.get("request_key", "")),
		"phase_before": phase_before, "phase_after": str(legacy.get("phase_id", phase_before)), "authoritative_result_ref": result_ref,
		"state_receipts": [str((legacy.get("result_receipt", {}) as Dictionary).get("receipt_key", ""))], "operation_receipts": [], "fact_receipts": [],
		"boundary": (command.get("boundary", {}) as Dictionary).duplicate(true), "receipt_key": "receipt:result:%s" % str(command.get("command_id", "")).replace(".", "_"), "content_fingerprint": "", "public_projection": _public_projection(),
	}
	for fact in legacy.get("facts", []): envelope["fact_receipts"].append(str((fact as Dictionary).get("receipt_key", "")))
	for operation in legacy.get("operations", []): envelope["operation_receipts"].append("receipt:operation:%s" % str((operation as Dictionary).get("operation_id", "")))
	return _seal_envelope(envelope)


func _operation_result_envelope(operation: Dictionary, context: Dictionary) -> Dictionary:
	var boundary: Dictionary = context.get("_ritual_command_boundary", {}) if typeof(context.get("_ritual_command_boundary", {})) == TYPE_DICTIONARY else {}
	if boundary.is_empty(): boundary = {"boundary_id": "boundary.command.internal", "kind": "command", "ritual_id": str(definition.get("ritual_id", "")), "session_id": _session_id, "phase_id": str(state.get("phase_id", "")), "ordinal": int(state.get("boundary_ordinal", 0)) + 1, "cause_receipt_key": "receipt:command:internal"}
	var envelope := {"envelope_version": 1, "operation_id": str(operation.get("operation_id", "")), "family": str(operation.get("family", "")), "verb": str(operation.get("verb", "")), "target_id": str(operation.get("target_id", "")), "boundary": boundary.duplicate(true), "receipt_key": "receipt:operation:%s" % str(operation.get("operation_id", "")), "content_fingerprint": "", "applied": true}
	return _seal_envelope(envelope)


func _receipt_record(receipt_key: String, fingerprint: String, boundary_id: String, envelope_kind: String, status: String) -> Dictionary:
	return {"receipt_key": receipt_key, "content_fingerprint": fingerprint, "boundary_id": boundary_id, "envelope_kind": envelope_kind, "status": status}


func _append_envelope_receipt(receipt: Dictionary) -> void:
	var receipts: Array = state.get("envelope_receipts", [])
	for existing in receipts:
		if str((existing as Dictionary).get("receipt_key", "")) == str(receipt.get("receipt_key", "")):
			return
	receipts.append(receipt.duplicate(true))
	while receipts.size() > RECEIPT_LIMIT: receipts.pop_front()
	state["envelope_receipts"] = receipts


func _envelope_rejection(command: Dictionary, error_code: String, message: String, retryable: bool, return_policy: String) -> Dictionary:
	var safe_command_id := str(command.get("command_id", "command.invalid_01"))
	if not _qualified_id(safe_command_id): safe_command_id = "command.invalid_01"
	var boundary: Dictionary = command.get("boundary", {}) if typeof(command.get("boundary")) == TYPE_DICTIONARY and _closed_shape(command.get("boundary", {}) as Dictionary, BOUNDARY_KEYS) else _fallback_boundary(command)
	var envelope := {
		"envelope_version": ENVELOPE_VERSION, "ok": false, "ritual_id": str(definition.get("ritual_id", "")), "session_id": _session_id, "command_id": safe_command_id, "request_key": str(command.get("request_key", "request:invalid")) if _request_key(str(command.get("request_key", ""))) else "request:invalid",
		"phase": str(state.get("phase_id", "")), "error_code": error_code if ERROR_CODES.has(error_code) else "internal_fail_closed", "public_message": message.left(256), "retryable": retryable, "return_policy": return_policy if return_policy in ["none", "return_to_source", "restore_focus"] else "none",
		"boundary": boundary, "receipt_key": "receipt:rejection:%s" % safe_command_id.replace(".", "_"), "content_fingerprint": "", "public_projection": _public_projection(),
	}
	return _seal_envelope(envelope)


func _fallback_boundary(command: Dictionary) -> Dictionary:
	return {"boundary_id": "boundary.command.invalid", "kind": "command", "ritual_id": str(definition.get("ritual_id", "")), "session_id": _session_id, "phase_id": str(state.get("phase_id", "")), "ordinal": int(state.get("boundary_ordinal", 0)), "cause_receipt_key": str(command.get("receipt_key", "receipt:command:invalid")) if _request_key(str(command.get("receipt_key", ""))) else "receipt:command:invalid"}


func _public_projection() -> Dictionary:
	var projection := prepared_projection()
	return {"phase_id": str(projection.get("phase_id", "")), "pending_total": int((projection.get("readable_totals", {}) as Dictionary).get("pending_total", 0)), "at_risk_total": int((projection.get("readable_totals", {}) as Dictionary).get("at_risk_total", 0))}


func _seal_envelope(envelope: Dictionary) -> Dictionary:
	envelope["content_fingerprint"] = canonical_fingerprint(_without_fingerprint(envelope))
	return envelope


func _without_fingerprint(envelope: Dictionary) -> Dictionary:
	var content := envelope.duplicate(true)
	content.erase("content_fingerprint")
	return content


func _closed_shape(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size(): return false
	for key in keys:
		if not value.has(key): return false
	return true


func _validation_error(error_code: String, message: String) -> Dictionary:
	return {"error_code": error_code, "message": message}


func _taxonomy_code(value: String) -> String:
	var aliases := {"unknown_action": "unknown_reference", "action_out_of_phase": "action_not_permitted", "request_conflict": "receipt_content_conflict", "handler_unavailable": "unsealed_authority", "handler_contract_violation": "internal_fail_closed", "operation_rejected": "handler_rejected", "fact_rejected": "handler_rejected", "empty_commitment": "precondition_failed", "missing_item": "precondition_failed", "nothing_to_undo": "precondition_failed"}
	var normalized := str(aliases.get(value, value))
	return normalized if ERROR_CODES.has(normalized) else "handler_rejected"


func _validate_restore_state(value: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["action_sequence", "transition_sequence", "boundary_ordinal"]:
		if typeof(value.get(key)) != TYPE_INT or int(value.get(key, -1)) < 0: errors.append("restore %s must be a nonnegative integer" % key)
	if int(value.get("transition_sequence", 0)) > int(value.get("action_sequence", 0)): errors.append("restore transition sequence exceeds action sequence")
	for key in ["pending_items", "working_items", "last_commitment", "eligible_resolutions", "actor_states", "object_states", "handler_state", "readable_totals", "request_cache", "envelope_request_cache"]:
		if typeof(value.get(key)) != TYPE_DICTIONARY: errors.append("restore %s must be a dictionary" % key)
	for key in ["pending_history", "item_resolutions", "authoritative_result_refs", "receipts", "envelope_receipts", "fact_envelopes", "operation_envelopes"]:
		if typeof(value.get(key)) != TYPE_ARRAY: errors.append("restore %s must be an array" % key)
	for receipt_value in value.get("receipts", []):
		if typeof(receipt_value) != TYPE_DICTIONARY: errors.append("restore receipt must be a dictionary"); continue
		var receipt: Dictionary = receipt_value
		if not _closed_shape(receipt, ["receipt_kind", "receipt_key", "content_fingerprint"]): errors.append("restore receipt has invalid shape")
		elif not _request_key(str(receipt.get("receipt_key", ""))) or not _fingerprint(str(receipt.get("content_fingerprint", ""))): errors.append("restore receipt identity is invalid")
	for receipt_value in value.get("envelope_receipts", []):
		if typeof(receipt_value) != TYPE_DICTIONARY: errors.append("restore envelope receipt must be a dictionary"); continue
		var receipt: Dictionary = receipt_value
		if not _closed_shape(receipt, ["receipt_key", "content_fingerprint", "boundary_id", "envelope_kind", "status"]): errors.append("restore envelope receipt has invalid shape")
		elif not _request_key(str(receipt.get("receipt_key", ""))) or not _request_key(str(receipt.get("boundary_id", ""))) or not _fingerprint(str(receipt.get("content_fingerprint", ""))) or str(receipt.get("envelope_kind", "")) not in ["command", "result", "rejection", "fact", "operation", "state", "transition", "phase_entry", "cleanup", "aftermath"] or str(receipt.get("status", "")) not in ["accepted", "rejected"]: errors.append("restore envelope receipt identity is invalid")
	for fact_value in value.get("fact_envelopes", []):
		if typeof(fact_value) != TYPE_DICTIONARY or not _valid_fact_envelope(fact_value as Dictionary): errors.append("restore fact envelope is invalid")
	for operation_value in value.get("operation_envelopes", []):
		if typeof(operation_value) != TYPE_DICTIONARY or not _valid_operation_result_envelope(operation_value as Dictionary): errors.append("restore operation envelope is invalid")
	for request_key in (value.get("envelope_request_cache", {}) as Dictionary).keys():
		var cache_value: Variant = (value.get("envelope_request_cache", {}) as Dictionary)[request_key]
		if typeof(cache_value) != TYPE_DICTIONARY: errors.append("restore request cache record must be a dictionary"); continue
		var cache: Dictionary = cache_value
		var cache_keys := ["request_key", "command_receipt_key", "command_content_fingerprint", "response_receipt_key", "response_content_fingerprint", "status"]
		if not _closed_shape(cache, cache_keys): errors.append("restore request cache record has invalid shape")
		elif str(cache.get("request_key", "")) != str(request_key) or not _request_key(str(request_key)) or str(cache.get("status", "")) not in ["pending", "resolved", "rejected"]: errors.append("restore request cache identity/status is invalid")
		elif not _fingerprint(str(cache.get("command_content_fingerprint", ""))) or not _fingerprint(str(cache.get("response_content_fingerprint", ""))): errors.append("restore request cache fingerprint is invalid")
	var cached_responses: Dictionary = (value.get("handler_state", {}) as Dictionary).get("_ritual_cached_responses", {}) if typeof((value.get("handler_state", {}) as Dictionary).get("_ritual_cached_responses", {})) == TYPE_DICTIONARY else {}
	for request_key in (value.get("envelope_request_cache", {}) as Dictionary).keys():
		var cache: Dictionary = (value.get("envelope_request_cache", {}) as Dictionary)[request_key]
		var response: Dictionary = cached_responses.get(request_key, {})
		if response.is_empty() or str(response.get("content_fingerprint", "")) != str(cache.get("response_content_fingerprint", "")) or not _valid_response_envelope(response): errors.append("restore cached response does not match its exact cache binding")
	for actor_id in (value.get("actor_states", {}) as Dictionary).keys():
		if not _actors_contains(str(actor_id)): errors.append("restore actor reference is unknown")
	for object_id in (value.get("object_states", {}) as Dictionary).keys():
		if not _objects_contains(str(object_id)): errors.append("restore object reference is unknown")
	return errors


func _valid_fact_envelope(fact: Dictionary) -> bool:
	var keys := ["envelope_version", "fact_id", "fact_type", "fact_version", "payload", "visibility", "boundary", "receipt_key", "content_fingerprint"]
	return _closed_shape(fact, keys) and int(fact.get("envelope_version", 0)) == 1 and int(fact.get("fact_version", 0)) > 0 and str(fact.get("visibility", "")) == "public" and _qualified_id(str(fact.get("fact_id", ""))) and _qualified_id(str(fact.get("fact_type", ""))) and _request_key(str(fact.get("receipt_key", ""))) and _fingerprint(str(fact.get("content_fingerprint", ""))) and canonical_fingerprint(_without_fingerprint(fact)) == str(fact.get("content_fingerprint", ""))


func _valid_operation_result_envelope(operation: Dictionary) -> bool:
	var keys := ["envelope_version", "operation_id", "family", "verb", "target_id", "boundary", "receipt_key", "content_fingerprint", "applied"]
	return _closed_shape(operation, keys) and int(operation.get("envelope_version", 0)) == 1 and typeof(operation.get("applied")) == TYPE_BOOL and _request_key(str(operation.get("receipt_key", ""))) and _fingerprint(str(operation.get("content_fingerprint", ""))) and canonical_fingerprint(_without_fingerprint(operation)) == str(operation.get("content_fingerprint", ""))


func _valid_response_envelope(response: Dictionary) -> bool:
	var result_keys := ["envelope_version", "ok", "ritual_id", "session_id", "command_id", "request_key", "phase_before", "phase_after", "authoritative_result_ref", "state_receipts", "operation_receipts", "fact_receipts", "boundary", "receipt_key", "content_fingerprint", "public_projection"]
	var rejection_keys := ["envelope_version", "ok", "ritual_id", "session_id", "command_id", "request_key", "phase", "error_code", "public_message", "retryable", "return_policy", "boundary", "receipt_key", "content_fingerprint", "public_projection"]
	return (_closed_shape(response, result_keys) or _closed_shape(response, rejection_keys)) and _fingerprint(str(response.get("content_fingerprint", ""))) and canonical_fingerprint(_without_fingerprint(response)) == str(response.get("content_fingerprint", ""))


func _actors_contains(actor_id: String) -> bool:
	for actor in _dictionary_array(definition.get("actors", [])):
		if str(actor.get("id", "")) == actor_id: return true
	return false


func _objects_contains(object_id: String) -> bool:
	for object in _dictionary_array(definition.get("scene_objects", [])):
		if str(object.get("id", "")) == object_id: return true
	return false


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for item in value:
			if typeof(item) == TYPE_DICTIONARY: result.append((item as Dictionary).duplicate(true))
	return result
