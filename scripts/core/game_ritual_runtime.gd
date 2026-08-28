class_name GameRitualRuntime
extends RefCounted

# Neutral action-boundary executor for validated game_ritual/1 definitions.
# Rules/outcomes remain in allowlisted host handlers; this class owns phase,
# request identity, receipts, staged edits, projection, and replay safety.

const SchemaScript := preload("res://scripts/core/game_ritual_schema.gd")
const RECEIPT_LIMIT := 256
const REQUEST_LIMIT := 128

var definition: Dictionary = {}
var state: Dictionary = {}
var _actions: Dictionary = {}
var _phases: Dictionary = {}
var _handlers: Dictionary = {}
var _host_handlers: Dictionary = {}
var _operations: Dictionary = {}


func configure(ritual_definition: Dictionary, host_handlers: Dictionary = {}) -> Dictionary:
	var errors := SchemaScript.validate_definition(ritual_definition)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	definition = ritual_definition.duplicate(true)
	_host_handlers = host_handlers.duplicate()
	_index_definition()
	state = _fresh_state()
	_apply_phase_entry(str(state.get("phase_id", "")))
	return {"ok": true, "state": state.duplicate(true), "projection": prepared_projection()}


func process_action(action_id: String, parameters: Dictionary, request_key: String, context: Dictionary = {}) -> Dictionary:
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
	var facts: Variant = _seal_facts(handler_result.get("facts", []), sequence, action_id)
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
	var cache: Dictionary = candidate.get("request_cache", {}) if typeof(candidate.get("request_cache", {})) == TYPE_DICTIONARY else {}
	cache[request_key] = {"command_fingerprint": command_fingerprint, "response": response.duplicate(true)}
	_trim_dictionary(cache, REQUEST_LIMIT)
	candidate["request_cache"] = cache
	state = candidate
	response["projection"] = prepared_projection()
	# Cache the final projection-bearing response only after the candidate commits.
	(state["request_cache"] as Dictionary)[request_key]["response"] = response.duplicate(true)
	return response


func restore(serialized_state: Dictionary) -> Dictionary:
	if definition.is_empty():
		return {"ok": false, "errors": ["runtime is not configured"]}
	var required := ["contract", "ritual_id", "phase_id", "action_sequence", "transition_sequence", "pending_items", "working_items", "item_resolutions", "actor_states", "object_states", "energy_tier", "handler_state", "receipts", "request_cache"]
	var errors: Array[String] = []
	for key in required:
		if not serialized_state.has(key):
			errors.append("restore state is missing %s" % key)
	if str(serialized_state.get("contract", "")) != SchemaScript.CONTRACT or str(serialized_state.get("ritual_id", "")) != str(definition.get("ritual_id", "")):
		errors.append("restore identity does not match configured ritual")
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
	return {"contract": SchemaScript.CONTRACT, "ritual_id": str(definition.get("ritual_id", "")), "phase_id": str(definition.get("initial_phase", "")), "action_sequence": 0, "transition_sequence": 0, "last_transition_id": "", "pending_items": {}, "pending_history": [], "working_items": {}, "last_commitment": {}, "eligible_resolutions": {}, "item_resolutions": [], "authoritative_result_refs": [], "actor_states": actor_states, "object_states": object_states, "energy_tier": str((definition.get("energy", {}) as Dictionary).get("initial_tier", "")), "handler_state": {}, "readable_totals": {"available_funds": 0, "pending_total": 0, "at_risk_total": 0, "returned_stake": 0, "payout": 0, "net_change": 0}, "receipts": [], "request_cache": {}}


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


func _seal_facts(value: Variant, sequence: int, action_id: String) -> Variant:
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
		seen[type] = true
		var record := {"fact_id": "ritual:fact:%d:%s" % [sequence, type], "fact_type": type, "fact_version": int((declared[type] as Dictionary).get("fact_version", 1)), "visibility": "public", "boundary": "action", "cause": action_id, "payload": (fact.get("payload", {}) as Dictionary).duplicate(true), "receipt_key": "ritual:fact:%d:%s" % [sequence, type]}
		record["content_fingerprint"] = canonical_fingerprint(record)
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
		elif not _value_matches(parameters[key], str(schema[key])): errors.append("parameter %s has wrong type" % key)
	return errors


func _value_matches(value: Variant, type: String) -> bool:
	match type:
		"bool": return typeof(value) == TYPE_BOOL
		"int": return typeof(value) == TYPE_INT
		"float": return typeof(value) == TYPE_FLOAT
		"string": return typeof(value) == TYPE_STRING
		"qualified_id": return typeof(value) == TYPE_STRING and str(value).contains(".")
		"string_array": return typeof(value) == TYPE_ARRAY and (value as Array).all(func(item): return typeof(item) == TYPE_STRING)
		"int_array": return typeof(value) == TYPE_ARRAY and (value as Array).all(func(item): return typeof(item) == TYPE_INT)
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


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for item in value:
			if typeof(item) == TYPE_DICTIONARY: result.append((item as Dictionary).duplicate(true))
	return result
