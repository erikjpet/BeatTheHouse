class_name ScenarioOperationRegistry
extends RefCounted

# Small allowlisted semantic operations. Definitions never name callables or
# node/resource paths; each operation has a fixed data contract here.

const OWNER_NAMESPACES := ["base", "traveler", "service", "game", "event", "crew", "scenario", "sweep"]
const OWNER_PRIORITY := {
	"base": 10,
	"traveler": 20,
	"service": 30,
	"game": 40,
	"event": 50,
	"crew": 55,
	"scenario": 60,
	"sweep": 70,
}
const SCENE_OPS := ["spawn", "remove", "move", "replace", "reveal", "hide", "enable", "disable", "set_state", "set_appearance"]
const INTERACTION_OPS := ["add", "remove", "replace", "gate", "retarget", "augment"]
const ACTOR_OPS := ["spawn", "despawn", "set_position", "set_route", "set_pose", "set_behavior"]
const TRANSITION_OPS := ["stage", "sound", "music", "scene_change", "feedback"]
const SERVICE_OPS := ["add", "remove", "gate", "replace"]
const GAME_OPS := ["add", "remove", "gate", "set_modifier"]
const ROUTE_OPS := ["open", "close", "gate", "retarget"]
const OP_FAMILIES := {
	"scene_ops": SCENE_OPS,
	"interaction_ops": INTERACTION_OPS,
	"actor_ops": ACTOR_OPS,
	"transition_ops": TRANSITION_OPS,
	"service_ops": SERVICE_OPS,
	"game_ops": GAME_OPS,
	"route_ops": ROUTE_OPS,
}
const REGISTERED_HANDLERS := {
	"set_local": {"inputs": ["key", "value"], "output": "local_state", "persistent": true, "rng": "none"},
	"increment_local": {"inputs": ["key", "amount"], "output": "local_state", "persistent": true, "rng": "none"},
	"complete_objective_step": {"inputs": ["objective_id", "step_id"], "output": "objective_progress", "persistent": true, "rng": "none"},
	"record_outcome": {"inputs": ["outcome"], "output": "resolved_outcomes", "persistent": true, "rng": "none"},
	"publish_feedback": {"inputs": ["message"], "output": "transition_queue", "persistent": false, "rng": "none"},
	"request_cleanup": {"inputs": ["reason"], "output": "cleanup_receipts", "persistent": true, "rng": "none"},
	"event_bridge": {"inputs": ["event_id", "resolution_id"], "output": "fact_queue", "persistent": true, "rng": "none"},
}


static func identity(owner_namespace: String, stable_object_id: String) -> String:
	return "%s::%s" % [owner_namespace.strip_edges(), stable_object_id.strip_edges()]


static func identity_from(value: Dictionary, prefix: String = "") -> String:
	var owner_key := "%sowner_namespace" % prefix
	var id_key := "%sstable_object_id" % prefix
	return identity(str(value.get(owner_key, "")), str(value.get(id_key, "")))


static func registered_operations() -> Dictionary:
	return OP_FAMILIES.duplicate(true)


static func registered_handlers() -> Dictionary:
	return REGISTERED_HANDLERS.duplicate(true)


static func validate_any_operation(operation: Dictionary) -> Array:
	var family := str(operation.get("family", "")).strip_edges()
	if not OP_FAMILIES.has(family):
		return ["operation family is missing or unregistered: %s." % family]
	return validate_operation(family, operation)


static func validate_operation(family: String, operation: Dictionary) -> Array:
	var errors: Array = []
	var allowed_ops: Array = OP_FAMILIES.get(family, [])
	var op_id := str(operation.get("op", "")).strip_edges()
	if not allowed_ops.has(op_id):
		errors.append("%s operation is unregistered: %s." % [family, op_id])
	var owner := str(operation.get("owner_namespace", "")).strip_edges()
	var stable_id := str(operation.get("stable_object_id", "")).strip_edges()
	if not OWNER_NAMESPACES.has(owner) or not _valid_id(stable_id):
		errors.append("%s %s requires registered owner_namespace and stable_object_id." % [family, op_id])
	var mode := str(operation.get("mode", "")).strip_edges()
	if family == "interaction_ops" and not ["add", "remove"].has(op_id):
		if not ["replace", "gate", "augment", "retarget"].has(mode):
			errors.append("interaction %s requires explicit replace/gate/augment/retarget mode." % op_id)
		var target_owner := str(operation.get("target_owner_namespace", "")).strip_edges()
		var target_id := str(operation.get("target_stable_object_id", "")).strip_edges()
		if not OWNER_NAMESPACES.has(target_owner) or not _valid_id(target_id):
			errors.append("interaction %s requires a valid target identity." % op_id)
	if ["spawn", "add", "replace"].has(op_id):
		var payload := _dict(operation.get("object", operation.get("actor", operation.get("interaction", {}))))
		if payload.is_empty():
			errors.append("%s %s requires a semantic payload." % [family, op_id])
		elif family == "scene_ops":
			_validate_scene_payload(payload, errors)
		elif family == "interaction_ops":
			_validate_interaction_payload(payload, errors)
		elif family == "actor_ops":
			_validate_actor_payload(payload, errors)
	if family == "actor_ops" and op_id == "set_behavior" and not ["idle", "watch", "patrol", "guard", "flee", "fight", "work", "depart"].has(str(operation.get("behavior", ""))):
		errors.append("actor behavior is not in the bounded registry.")
	if family == "transition_ops" and op_id in ["sound", "music"] and not _valid_id(str(operation.get("cue_id", ""))):
		errors.append("transition %s requires an allowlisted cue_id, not a resource path." % op_id)
	if _contains_forbidden_path(operation):
		errors.append("operation contains a forbidden resource/node/reflection path.")
	return errors


static func apply_operations(state_value: Dictionary, family: String, operations: Array, boundary_id: String) -> Dictionary:
	var state := _normalize_semantic_state(state_value)
	var applied: Array = []
	var errors: Array = []
	for index in range(operations.size()):
		if typeof(operations[index]) != TYPE_DICTIONARY:
			errors.append("%s[%d] is not a dictionary." % [family, index])
			continue
		var operation := (operations[index] as Dictionary).duplicate(true)
		var validation := validate_operation(family, operation)
		if not validation.is_empty():
			errors.append_array(validation)
			continue
		var receipt_id := str(operation.get("receipt_id", "%s:%s:%d" % [boundary_id, family, index])).strip_edges()
		if _string_array(state.get("operation_receipts", [])).has(receipt_id):
			continue
		_apply_operation(state, family, operation, receipt_id)
		var receipts := _string_array(state.get("operation_receipts", []))
		receipts.append(receipt_id)
		state["operation_receipts"] = receipts
		applied.append(receipt_id)
	return {"ok": errors.is_empty(), "state": state, "applied": applied, "errors": errors}


static func resolve_interactions(base_records: Array, overlay_records: Array) -> Dictionary:
	var records: Dictionary = {}
	var errors: Array = []
	for source_value in base_records + overlay_records:
		if typeof(source_value) != TYPE_DICTIONARY:
			continue
		var source := (source_value as Dictionary).duplicate(true)
		var key := identity_from(source)
		if key == "::":
			errors.append("interaction record has no stable owner identity.")
			continue
		if records.has(key):
			# Same-owner duplicates are hostile and fail closed rather than letting
			# iteration order silently pick a winner.
			records.erase(key)
			errors.append("illegal duplicate interaction identity %s." % key)
			continue
		records[key] = source
	var ordered_overlays := overlay_records.duplicate(true)
	ordered_overlays.sort_custom(Callable(ScenarioOperationRegistry, "_sort_interaction_overlay"))
	for overlay_value in ordered_overlays:
		if typeof(overlay_value) != TYPE_DICTIONARY:
			continue
		var overlay := overlay_value as Dictionary
		var mode := str(overlay.get("mode", "add"))
		if mode == "add":
			continue
		var target_key := identity(str(overlay.get("target_owner_namespace", "")), str(overlay.get("target_stable_object_id", "")))
		if not records.has(target_key):
			errors.append("interaction %s targets missing identity %s." % [identity_from(overlay), target_key])
			continue
		var source_key := identity_from(overlay)
		var priority := int(OWNER_PRIORITY.get(str(overlay.get("owner_namespace", "")), -1))
		var target_priority := int(OWNER_PRIORITY.get(str((records.get(target_key, {}) as Dictionary).get("owner_namespace", "")), -1))
		if priority < target_priority:
			errors.append("interaction %s cannot override higher-priority %s." % [source_key, target_key])
			records.erase(source_key)
			continue
		match mode:
			"replace":
				records.erase(target_key)
			"gate":
				var target := (records.get(target_key, {}) as Dictionary).duplicate(true)
				target["enabled"] = bool(overlay.get("enabled", false))
				target["disabled_reason"] = str(overlay.get("disabled_reason", "Unavailable during this room sequence.")) if not bool(target.get("enabled", false)) else ""
				records[target_key] = target
				records.erase(source_key)
			"augment":
				var target := (records.get(target_key, {}) as Dictionary).duplicate(true)
				var actions := _array(target.get("available_actions", []))
				for action_value in _array(overlay.get("available_actions", [])):
					if typeof(action_value) == TYPE_DICTIONARY and not _action_ids(actions).has(str((action_value as Dictionary).get("id", ""))):
						actions.append((action_value as Dictionary).duplicate(true))
				target["available_actions"] = actions
				records[target_key] = target
				records.erase(source_key)
			"retarget":
				var target := (records.get(target_key, {}) as Dictionary).duplicate(true)
				target["source_id"] = str(overlay.get("source_id", target.get("source_id", "")))
				records[target_key] = target
				records.erase(source_key)
	var result: Array = []
	var keys := records.keys()
	keys.sort()
	for key_value in keys:
		result.append((records.get(key_value, {}) as Dictionary).duplicate(true))
	return {"ok": errors.is_empty(), "records": result, "errors": errors}


static func _apply_operation(state: Dictionary, family: String, operation: Dictionary, receipt_id: String) -> void:
	var collection_key := _collection_key(family)
	if family == "transition_ops":
		var transitions := _array(state.get(collection_key, []))
		var transition := operation.duplicate(true)
		transition["receipt_id"] = receipt_id
		transitions.append(transition)
		state[collection_key] = transitions
		return
	var collection := _dict(state.get(collection_key, {}))
	var key := identity_from(operation)
	var op_id := str(operation.get("op", ""))
	var payload := _dict(operation.get("object", operation.get("actor", operation.get("interaction", {}))))
	if ["remove", "despawn"].has(op_id):
		collection.erase(key)
	elif ["spawn", "add", "replace"].has(op_id):
		payload["owner_namespace"] = str(operation.get("owner_namespace", ""))
		payload["stable_object_id"] = str(operation.get("stable_object_id", ""))
		payload["mode"] = str(operation.get("mode", "add"))
		for target_key in ["target_owner_namespace", "target_stable_object_id"]:
			if operation.has(target_key):
				payload[target_key] = operation.get(target_key)
		collection[key] = payload
	else:
		var current := _dict(collection.get(key, {}))
		if current.is_empty():
			current = {"owner_namespace": str(operation.get("owner_namespace", "")), "stable_object_id": str(operation.get("stable_object_id", ""))}
		match op_id:
			"move", "set_position":
				current["anchor_id"] = str(operation.get("anchor_id", current.get("anchor_id", "")))
				current["zone_id"] = str(operation.get("zone_id", current.get("zone_id", "")))
			"reveal": current["visible"] = true
			"hide": current["visible"] = false
			"enable": current["enabled"] = true
			"disable":
				current["enabled"] = false
				current["disabled_reason"] = str(operation.get("disabled_reason", "Unavailable."))
			"set_state": current["state"] = str(operation.get("state", ""))
			"set_appearance": current["appearance"] = str(operation.get("appearance", ""))
			"set_route": current["route_id"] = str(operation.get("route_id", ""))
			"set_pose": current["pose"] = str(operation.get("pose", ""))
			"set_behavior": current["behavior"] = str(operation.get("behavior", "idle"))
			"gate":
				current["enabled"] = bool(operation.get("enabled", false))
				current["disabled_reason"] = str(operation.get("disabled_reason", "Unavailable.")) if not bool(current.get("enabled", false)) else ""
			"retarget": current["source_id"] = str(operation.get("source_id", current.get("source_id", "")))
			"set_modifier": current["modifier"] = _dict(operation.get("modifier", {}))
		collection[key] = current
	state[collection_key] = collection


static func _normalize_semantic_state(value: Dictionary) -> Dictionary:
	return {
		"scene_objects": _dict(value.get("scene_objects", {})),
		"interactions": _dict(value.get("interactions", {})),
		"actors": _dict(value.get("actors", {})),
		"services": _dict(value.get("services", {})),
		"games": _dict(value.get("games", {})),
		"routes": _dict(value.get("routes", {})),
		"transition_queue": _array(value.get("transition_queue", [])),
		"operation_receipts": _string_array(value.get("operation_receipts", [])),
	}


static func _collection_key(family: String) -> String:
	return {
		"scene_ops": "scene_objects", "interaction_ops": "interactions",
		"actor_ops": "actors", "transition_ops": "transition_queue",
		"service_ops": "services", "game_ops": "games", "route_ops": "routes",
	}.get(family, "scene_objects")


static func _validate_scene_payload(payload: Dictionary, errors: Array) -> void:
	if str(payload.get("label", "")).strip_edges().is_empty() or str(payload.get("role", "")).strip_edges().is_empty():
		errors.append("scene object requires label and semantic role.")
	if str(payload.get("anchor_id", "")).strip_edges().is_empty() and str(payload.get("zone_id", "")).strip_edges().is_empty():
		errors.append("scene object requires bounded anchor_id or zone_id.")
	var bounds := _dict(payload.get("bounds", {}))
	if bounds.is_empty() or float(bounds.get("w", 0.0)) <= 0.0 or float(bounds.get("h", 0.0)) <= 0.0:
		errors.append("scene object requires positive semantic bounds.")


static func _validate_interaction_payload(payload: Dictionary, errors: Array) -> void:
	for key in ["label", "state_label", "prompt"]:
		if str(payload.get(key, "")).strip_edges().is_empty():
			errors.append("interaction requires accessible %s." % key)
	if not payload.has("enabled"):
		errors.append("interaction requires enabled state.")
	elif not bool(payload.get("enabled", false)) and str(payload.get("disabled_reason", "")).strip_edges().is_empty():
		errors.append("disabled interaction requires disabled_reason.")
	if _array(payload.get("available_actions", [])).is_empty() and bool(payload.get("enabled", false)):
		errors.append("enabled interaction requires available_actions.")


static func _validate_actor_payload(payload: Dictionary, errors: Array) -> void:
	if str(payload.get("label", "")).strip_edges().is_empty() or str(payload.get("actor_id", "")).strip_edges().is_empty():
		errors.append("actor requires label and actor_id.")
	if str(payload.get("anchor_id", "")).strip_edges().is_empty() and str(payload.get("zone_id", "")).strip_edges().is_empty():
		errors.append("actor requires authored anchor_id or zone_id.")
	if not ["idle", "watch", "patrol", "guard", "flee", "fight", "work", "depart"].has(str(payload.get("behavior", "idle"))):
		errors.append("actor payload behavior is not bounded.")


static func _sort_interaction_overlay(a: Variant, b: Variant) -> bool:
	var left := a as Dictionary if typeof(a) == TYPE_DICTIONARY else {}
	var right := b as Dictionary if typeof(b) == TYPE_DICTIONARY else {}
	var left_priority := int(OWNER_PRIORITY.get(str(left.get("owner_namespace", "")), -1))
	var right_priority := int(OWNER_PRIORITY.get(str(right.get("owner_namespace", "")), -1))
	if left_priority != right_priority:
		return left_priority < right_priority
	return identity_from(left) < identity_from(right)


static func _contains_forbidden_path(value: Variant) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		for nested in (value as Dictionary).values():
			if _contains_forbidden_path(nested): return true
	elif typeof(value) == TYPE_ARRAY:
		for nested in value as Array:
			if _contains_forbidden_path(nested): return true
	elif typeof(value) == TYPE_STRING:
		var text := str(value)
		return text.begins_with("res://") or text.begins_with("user://") or text.contains("../") or text.contains("/root/") or text.contains("get_node(")
	return false


static func _action_ids(actions: Array) -> Array:
	var result: Array = []
	for action_value in actions:
		if typeof(action_value) == TYPE_DICTIONARY:
			result.append(str((action_value as Dictionary).get("id", "")))
	return result


static func _valid_id(value: String) -> bool:
	var text := value.strip_edges()
	if text.is_empty(): return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and code != 95 and code != 45 and code != 58:
			return false
	return true


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
