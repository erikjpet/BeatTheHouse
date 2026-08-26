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
	"set_local": {"inputs": ["key", "value"], "outputs": ["local_state"], "persistent": true, "rng": "none"},
	"increment_local": {"inputs": ["key", "amount"], "outputs": ["local_state"], "persistent": true, "rng": "none"},
	"complete_objective_step": {"inputs": ["objective_id", "step_id"], "outputs": ["objective_progress"], "persistent": true, "rng": "none"},
	"record_outcome": {"inputs": ["outcome"], "outputs": ["resolved_outcomes"], "persistent": true, "rng": "none"},
	"publish_feedback": {"inputs": ["message"], "outputs": ["last_feedback"], "persistent": true, "rng": "none"},
	"request_cleanup": {"inputs": ["reason"], "outputs": ["semantic_state", "cleanup_receipts", "cleanup_receipt_records", "status"], "persistent": true, "rng": "none"},
	"event_bridge": {"inputs": ["event_id", "resolution_id"], "outputs": ["last_feedback"], "persistent": true, "rng": "none"},
}
const MAX_OPERATIONS_PER_BATCH := 32
const MAX_ACTIONS_PER_INTERACTION := 8
const MAX_OPERATION_RECEIPTS := 512
const MAX_TRANSITION_QUEUE := 128
const MAX_VARIANT_DEPTH := 12
const MAX_VARIANT_VALUES := 4096
const MAX_VARIANT_TEXT := 512
const MAX_VARIANT_COLLECTION := 512
const MIN_TARGET_SIZE := 44.0
const COMMON_OPERATION_KEYS := ["family", "op", "receipt_id", "owner_namespace", "stable_object_id"]


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
	errors.append_array(validate_bounded_variant("scenario operation", operation))
	if not OP_FAMILIES.has(family):
		return ["operation family is unregistered: %s." % family]
	var allowed_ops: Array = OP_FAMILIES.get(family, [])
	var op_id := str(operation.get("op", "")).strip_edges()
	_append_unknown_keys(family, operation, _allowed_operation_keys(family, op_id), errors)
	if str(operation.get("family", "")).strip_edges() != family:
		errors.append("%s operation requires an exact matching family field." % family)
	if not allowed_ops.has(op_id):
		errors.append("%s operation is unregistered: %s." % [family, op_id])
	var owner := str(operation.get("owner_namespace", "")).strip_edges()
	var stable_id := str(operation.get("stable_object_id", "")).strip_edges()
	if not OWNER_NAMESPACES.has(owner) or not _valid_id(stable_id):
		errors.append("%s %s requires registered owner_namespace and stable_object_id." % [family, op_id])
	if not _valid_id(str(operation.get("receipt_id", ""))):
		errors.append("%s %s requires a stable authored receipt_id." % [family, op_id])
	var mode := str(operation.get("mode", "")).strip_edges()
	if family == "interaction_ops" and not ["add", "remove"].has(op_id):
		if mode != op_id:
			errors.append("interaction %s requires matching explicit mode." % op_id)
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
			if str(payload.get("owner_namespace", "")).strip_edges() != owner or str(payload.get("stable_object_id", "")).strip_edges() != stable_id:
				errors.append("interaction payload identity must exactly match its operation identity.")
		elif family == "actor_ops":
			_validate_actor_payload(payload, errors)
		elif family in ["service_ops", "game_ops"]:
			_validate_service_game_payload(payload, errors)
	_validate_operation_fields(family, op_id, operation, errors)
	if family == "actor_ops" and op_id == "set_behavior" and not ["idle", "watch", "patrol", "guard", "flee", "fight", "work", "depart"].has(str(operation.get("behavior", ""))):
		errors.append("actor behavior is not in the bounded registry.")
	if family == "transition_ops" and op_id in ["sound", "music"] and not _valid_id(str(operation.get("cue_id", ""))):
		errors.append("transition %s requires an allowlisted cue_id, not a resource path." % op_id)
	if _contains_forbidden_path(operation):
		errors.append("operation contains a forbidden resource/node/reflection path.")
	return errors


static func structural_receipt_key(boundary_id: String, family: String, authored_receipt_id: String) -> String:
	var tuple := _length_prefixed(boundary_id.strip_edges()) + _length_prefixed(family.strip_edges()) + _length_prefixed(authored_receipt_id.strip_edges())
	return "op_%s" % tuple.sha256_text()


static func validate_bounded_variant(label: String, value: Variant) -> Array:
	var errors: Array = []
	_validate_bounded_variant(label, value, 0, {"count": 0}, [], errors)
	return errors


static func apply_operations(state_value: Dictionary, family: String, operations: Array, boundary_id: String) -> Dictionary:
	var state_validation := validate_bounded_variant("scenario semantic state", state_value)
	if not state_validation.is_empty():
		return {"ok": false, "state": state_value, "applied": [], "errors": state_validation}
	var original := _normalize_semantic_state(state_value)
	if not OP_FAMILIES.has(family):
		return {"ok": false, "state": original, "applied": [], "errors": ["operation family is unregistered: %s." % family]}
	if not _valid_boundary_scope(boundary_id):
		return {"ok": false, "state": original, "applied": [], "errors": ["operation batch requires an instance/content/phase/boundary scope."]}
	if operations.size() > MAX_OPERATIONS_PER_BATCH:
		return {"ok": false, "state": original, "applied": [], "errors": ["operation batch exceeds %d entries." % MAX_OPERATIONS_PER_BATCH]}
	var applied: Array = []
	var errors: Array = []
	var authored_receipts: Dictionary = {}
	var pending: Array = []
	var fingerprints := _dict(original.get("operation_fingerprints", {}))
	var existing_receipts := _string_array(original.get("operation_receipts", []))
	for index in range(operations.size()):
		if typeof(operations[index]) != TYPE_DICTIONARY:
			errors.append("%s[%d] is not a dictionary." % [family, index])
			continue
		var candidate := operations[index] as Dictionary
		var validation := validate_operation(family, candidate)
		if not validation.is_empty():
			errors.append_array(validation)
		var authored_receipt := str(candidate.get("receipt_id", "")).strip_edges()
		if authored_receipts.has(authored_receipt):
			errors.append("operation batch contains duplicate authored receipt_id %s." % authored_receipt)
		elif not authored_receipt.is_empty():
			authored_receipts[authored_receipt] = true
		if not authored_receipt.is_empty() and validation.is_empty():
			var authoritative_receipt := structural_receipt_key(boundary_id, family, authored_receipt)
			var fingerprint := JSON.stringify(_canonical_variant(candidate))
			if fingerprints.has(authoritative_receipt) and str(fingerprints.get(authoritative_receipt, "")) != fingerprint:
				errors.append("operation receipt %s was reused for conflicting content." % authoritative_receipt)
			pending.append({"operation": candidate.duplicate(true), "receipt_id": authoritative_receipt, "authored_receipt_id": authored_receipt, "fingerprint": fingerprint})
	var new_receipt_count := 0
	for pending_value in pending:
		if not existing_receipts.has(str(_dict(pending_value).get("receipt_id", ""))): new_receipt_count += 1
	if existing_receipts.size() + new_receipt_count > MAX_OPERATION_RECEIPTS:
		errors.append("operation lifetime receipt limit reached.")
	if _array(original.get("transition_queue", [])).size() > MAX_TRANSITION_QUEUE:
		errors.append("transition queue exceeds its persisted capacity.")
	if family == "transition_ops" and _array(original.get("transition_queue", [])).size() + new_receipt_count > MAX_TRANSITION_QUEUE:
		errors.append("transition queue capacity reached.")
	if not errors.is_empty():
		return {"ok": false, "state": original, "applied": [], "errors": errors}
	var state := original.duplicate(true)
	for pending_value in pending:
		var item := pending_value as Dictionary
		var receipt_id := str(item.get("receipt_id", ""))
		if existing_receipts.has(receipt_id): continue
		var target_errors := _validate_operation_target(state, family, _dict(item.get("operation", {})))
		if not target_errors.is_empty(): errors.append_array(target_errors)
		else: _apply_operation(state, family, _dict(item.get("operation", {})), receipt_id)
	if not errors.is_empty():
		return {"ok": false, "state": original, "applied": [], "errors": errors}
	for pending_value in pending:
		var item := pending_value as Dictionary
		var operation := _dict(item.get("operation", {}))
		var receipt_id := str(item.get("receipt_id", ""))
		if existing_receipts.has(receipt_id):
			continue
		var receipts := _string_array(state.get("operation_receipts", []))
		receipts.append(receipt_id)
		state["operation_receipts"] = receipts
		fingerprints[receipt_id] = str(item.get("fingerprint", ""))
		state["operation_fingerprints"] = fingerprints.duplicate(true)
		var records := _array(state.get("operation_receipt_records", []))
		records.append({"receipt_key": receipt_id, "boundary_id": boundary_id.strip_edges(), "family": family, "authored_receipt_id": str(item.get("authored_receipt_id", "")), "fingerprint": str(item.get("fingerprint", ""))})
		state["operation_receipt_records"] = records
		applied.append(receipt_id)
	return {"ok": true, "state": state, "applied": applied, "errors": []}


static func resolve_interactions(base_records: Array, overlay_records: Array) -> Dictionary:
	var records: Dictionary = {}
	var tainted: Dictionary = {}
	var errors: Array = []
	for source_value in base_records:
		_ingest_interaction_record(records, tainted, errors, source_value, false)
	for source_value in overlay_records:
		_ingest_interaction_record(records, tainted, errors, source_value, true)
	var ordered_overlays := overlay_records.duplicate(true)
	ordered_overlays.sort_custom(Callable(ScenarioOperationRegistry, "_sort_interaction_overlay"))
	var target_claims: Dictionary = {}
	for overlay_value in ordered_overlays:
		if typeof(overlay_value) != TYPE_DICTIONARY:
			continue
		var overlay := overlay_value as Dictionary
		var source_key := identity_from(overlay)
		if tainted.has(source_key) or not records.has(source_key) or str(overlay.get("mode", "add")) == "add":
			continue
		var target_key := identity(str(overlay.get("target_owner_namespace", "")), str(overlay.get("target_stable_object_id", "")))
		var claims := _string_array(target_claims.get(target_key, []))
		claims.append(source_key)
		target_claims[target_key] = claims
	for target_key_value in target_claims.keys():
		var claims := _string_array(target_claims.get(target_key_value, []))
		if claims.size() <= 1:
			continue
		errors.append("interactions %s compete for target %s." % [JSON.stringify(claims), str(target_key_value)])
		for source_key_value in claims:
			records.erase(str(source_key_value))
	for overlay_value in ordered_overlays:
		if typeof(overlay_value) != TYPE_DICTIONARY:
			continue
		var overlay := overlay_value as Dictionary
		var source_key := identity_from(overlay)
		if tainted.has(source_key) or not records.has(source_key):
			continue
		var mode := str(overlay.get("mode", "add"))
		if mode == "add":
			continue
		var target_key := identity(str(overlay.get("target_owner_namespace", "")), str(overlay.get("target_stable_object_id", "")))
		if _string_array(target_claims.get(target_key, [])).size() > 1:
			continue
		if not records.has(target_key):
			errors.append("interaction %s targets missing identity %s." % [identity_from(overlay), target_key])
			records.erase(source_key)
			continue
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
		if not tainted.has(str(key_value)):
			result.append((records.get(key_value, {}) as Dictionary).duplicate(true))
	return {"ok": errors.is_empty(), "records": result, "errors": errors}


static func _ingest_interaction_record(records: Dictionary, tainted: Dictionary, errors: Array, source_value: Variant, overlay: bool) -> void:
	if typeof(source_value) != TYPE_DICTIONARY:
		errors.append("interaction record must be a dictionary.")
		return
	var source := (source_value as Dictionary).duplicate(true)
	var key := identity_from(source)
	var validation: Array = []
	_validate_interaction_record(source, validation, overlay)
	if not validation.is_empty():
		errors.append_array(validation)
		records.erase(key)
		tainted[key] = true
		return
	if tainted.has(key):
		return
	if records.has(key):
		# Same-owner duplicates are hostile and fail closed rather than letting
		# iteration order silently pick a winner.
		records.erase(key)
		tainted[key] = true
		errors.append("illegal duplicate interaction identity %s." % key)
		return
	records[key] = source


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
	if family == "interaction_ops" and not ["add", "remove"].has(op_id):
		var overlay := payload
		overlay["owner_namespace"] = str(operation.get("owner_namespace", ""))
		overlay["stable_object_id"] = str(operation.get("stable_object_id", ""))
		for overlay_key in ["mode", "target_owner_namespace", "target_stable_object_id", "enabled", "disabled_reason", "source_id", "available_actions"]:
			if operation.has(overlay_key):
				overlay[overlay_key] = operation.get(overlay_key)
		collection[key] = overlay
		state[collection_key] = collection
		return
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
			"open":
				current["enabled"] = true
				current["disabled_reason"] = ""
			"close":
				current["enabled"] = false
				current["disabled_reason"] = str(operation.get("disabled_reason", "Route closed."))
		collection[key] = current
	state[collection_key] = collection


static func _validate_operation_target(state: Dictionary, family: String, operation: Dictionary) -> Array:
	if family == "transition_ops":
		return []
	var errors: Array = []
	var collection_key := _collection_key(family)
	var collection := _dict(state.get(collection_key, {}))
	var key := identity_from(operation)
	var op_id := str(operation.get("op", "")).strip_edges()
	var create_operation := family == "scene_ops" and op_id == "spawn" or family == "interaction_ops" and op_id == "add" or family == "actor_ops" and op_id == "spawn" or family in ["service_ops", "game_ops"] and op_id == "add"
	if create_operation:
		if collection.has(key):
			errors.append("%s %s cannot create existing identity %s." % [family, op_id, key])
		return errors
	if family == "interaction_ops" and not ["add", "remove"].has(op_id):
		if collection.has(key):
			errors.append("interaction overlay identity already exists: %s." % key)
		var target_key := identity(str(operation.get("target_owner_namespace", "")), str(operation.get("target_stable_object_id", "")))
		if not collection.has(target_key) and not _target_declared(state, collection_key, target_key):
			errors.append("interaction %s targets undeclared missing identity %s." % [key, target_key])
		return errors
	if ["remove", "despawn"].has(op_id):
		if not collection.has(key):
			errors.append("%s %s targets missing identity %s." % [family, op_id, key])
		return errors
	if not collection.has(key) and not _target_declared(state, collection_key, key):
		errors.append("%s %s targets undeclared missing identity %s." % [family, op_id, key])
	return errors


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
		"operation_receipt_records": _array(value.get("operation_receipt_records", [])),
		"operation_fingerprints": _dict(value.get("operation_fingerprints", {})),
		"declared_targets": _normalize_declared_targets(value.get("declared_targets", {})),
	}


static func _normalize_declared_targets(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	var source := _dict(value)
	for collection_key in ["scene_objects", "interactions", "actors", "services", "games", "routes"]:
		result[collection_key] = _string_array(source.get(collection_key, []))
	return result


static func _target_declared(state: Dictionary, collection_key: String, target_key: String) -> bool:
	var declared := _dict(state.get("declared_targets", {}))
	return _string_array(declared.get(collection_key, [])).has(target_key)


static func _collection_key(family: String) -> String:
	return {
		"scene_ops": "scene_objects", "interaction_ops": "interactions",
		"actor_ops": "actors", "transition_ops": "transition_queue",
		"service_ops": "services", "game_ops": "games", "route_ops": "routes",
	}.get(family, "scene_objects")


static func _validate_scene_payload(payload: Dictionary, errors: Array) -> void:
	_append_unknown_keys("scene object payload", payload, ["label", "role", "anchor_id", "zone_id", "bounds", "visible", "enabled", "state", "appearance"], errors)
	if str(payload.get("label", "")).strip_edges().is_empty() or str(payload.get("role", "")).strip_edges().is_empty():
		errors.append("scene object requires label and semantic role.")
	if str(payload.get("anchor_id", "")).strip_edges().is_empty() and str(payload.get("zone_id", "")).strip_edges().is_empty():
		errors.append("scene object requires bounded anchor_id or zone_id.")
	var bounds := _dict(payload.get("bounds", {}))
	_append_unknown_keys("scene object bounds", bounds, ["w", "h"], errors)
	if bounds.is_empty() or not _finite_number(bounds.get("w")) or not _finite_number(bounds.get("h")) or float(bounds.get("w", 0.0)) <= 0.0 or float(bounds.get("h", 0.0)) <= 0.0:
		errors.append("scene object requires positive semantic bounds.")


static func _validate_interaction_payload(payload: Dictionary, errors: Array) -> void:
	_append_unknown_keys("interaction payload", payload, ["owner_namespace", "stable_object_id", "label", "state_label", "prompt", "enabled", "disabled_reason", "available_actions", "input_actions", "non_color_state", "focus_order", "hit_bounds", "min_target_size", "safe_exit", "mode", "target_owner_namespace", "target_stable_object_id", "source_id"], errors)
	for key in ["label", "state_label", "prompt"]:
		if str(payload.get(key, "")).strip_edges().is_empty():
			errors.append("interaction requires accessible %s." % key)
	if not payload.has("enabled") or typeof(payload.get("enabled")) != TYPE_BOOL:
		errors.append("interaction requires enabled state.")
	elif not bool(payload.get("enabled", false)) and str(payload.get("disabled_reason", "")).strip_edges().is_empty():
		errors.append("disabled interaction requires disabled_reason.")
	if typeof(payload.get("available_actions", [])) != TYPE_ARRAY:
		errors.append("interaction available_actions must be an array.")
	if _array(payload.get("available_actions", [])).is_empty() and bool(payload.get("enabled", false)):
		errors.append("enabled interaction requires available_actions.")
	if _array(payload.get("available_actions", [])).size() > MAX_ACTIONS_PER_INTERACTION:
		errors.append("interaction exceeds the bounded action count.")
	var action_ids: Dictionary = {}
	for action_value in _array(payload.get("available_actions", [])):
		if typeof(action_value) != TYPE_DICTIONARY:
			errors.append("interaction action must be a dictionary.")
			continue
		var action := _dict(action_value)
		_append_unknown_keys("interaction action", action, ["id", "label", "input_action", "non_color_state", "cost", "handler", "inputs", "requires_objective_steps", "requires_local"], errors)
		var action_id := str(action.get("id", "")).strip_edges()
		if not _valid_id(action_id) or action_ids.has(action_id) or str(action.get("label", "")).strip_edges().is_empty() or not _valid_id(str(action.get("input_action", ""))) or str(action.get("non_color_state", "")).strip_edges().is_empty():
			errors.append("interaction action requires unique id, label, input_action, and non_color_state.")
		action_ids[action_id] = true
		var handler_id := str(action.get("handler", "")).strip_edges()
		if action.has("cost") and (typeof(action.get("cost")) != TYPE_INT or int(action.get("cost", 0)) < 0):
			errors.append("interaction action cost must be a non-negative integer.")
		if not handler_id.is_empty() and not REGISTERED_HANDLERS.has(handler_id):
			errors.append("interaction action references unregistered handler %s." % handler_id)
		elif not handler_id.is_empty():
			if typeof(action.get("inputs", {})) != TYPE_DICTIONARY:
				errors.append("interaction action handler inputs must be a dictionary.")
			var inputs := _dict(action.get("inputs", {}))
			var expected_inputs := _array(_dict(REGISTERED_HANDLERS.get(handler_id, {})).get("inputs", []))
			_append_unknown_keys("interaction action handler inputs", inputs, expected_inputs, errors)
			for input_value in expected_inputs:
				if not inputs.has(str(input_value)):
					errors.append("interaction action handler %s requires input %s." % [handler_id, str(input_value)])
		for requirement_value in _array(action.get("requires_objective_steps", [])):
			var requirement := _dict(requirement_value)
			_append_unknown_keys("interaction objective precondition", requirement, ["objective_id", "step_id"], errors)
			if not _valid_id(str(requirement.get("objective_id", ""))) or not _valid_id(str(requirement.get("step_id", ""))):
				errors.append("interaction objective precondition requires objective_id and step_id.")
		for requirement_value in _array(action.get("requires_local", [])):
			var requirement := _dict(requirement_value)
			_append_unknown_keys("interaction local precondition", requirement, ["key", "equals"], errors)
			if not _valid_id(str(requirement.get("key", ""))) or not requirement.has("equals"):
				errors.append("interaction local precondition requires key and equals.")
		if action.has("requires_objective_steps") and typeof(action.get("requires_objective_steps")) != TYPE_ARRAY:
			errors.append("interaction objective preconditions must be an array.")
		if action.has("requires_local") and typeof(action.get("requires_local")) != TYPE_ARRAY:
			errors.append("interaction local preconditions must be an array.")
	var input_actions := _strict_id_array(payload.get("input_actions", []))
	if input_actions.is_empty() or input_actions.size() != _array(payload.get("input_actions", [])).size() or str(payload.get("non_color_state", "")).strip_edges().is_empty():
		errors.append("interaction requires input_actions and a non-color state.")
	for action_value in _array(payload.get("available_actions", [])):
		if typeof(action_value) == TYPE_DICTIONARY and not input_actions.has(str((action_value as Dictionary).get("input_action", ""))):
			errors.append("interaction action input_action must be declared in input_actions.")
	if typeof(payload.get("focus_order")) != TYPE_INT or int(payload.get("focus_order", -1)) < 0:
		errors.append("interaction requires non-negative focus_order.")
	var hit_bounds := _dict(payload.get("hit_bounds", {}))
	_append_unknown_keys("interaction hit_bounds", hit_bounds, ["w", "h"], errors)
	if not _finite_number(hit_bounds.get("w")) or not _finite_number(hit_bounds.get("h")) or not _finite_number(payload.get("min_target_size")) or float(hit_bounds.get("w", 0.0)) < MIN_TARGET_SIZE or float(hit_bounds.get("h", 0.0)) < MIN_TARGET_SIZE or float(payload.get("min_target_size", 0.0)) < MIN_TARGET_SIZE:
		errors.append("interaction hit bounds/min_target_size are below the accessible minimum.")
	if not payload.has("safe_exit") or typeof(payload.get("safe_exit")) != TYPE_BOOL:
		errors.append("interaction must declare safe_exit semantics.")


static func _validate_actor_payload(payload: Dictionary, errors: Array) -> void:
	_append_unknown_keys("actor payload", payload, ["label", "actor_id", "anchor_id", "zone_id", "behavior", "route_id", "pose"], errors)
	if str(payload.get("label", "")).strip_edges().is_empty() or str(payload.get("actor_id", "")).strip_edges().is_empty():
		errors.append("actor requires label and actor_id.")
	if str(payload.get("anchor_id", "")).strip_edges().is_empty() and str(payload.get("zone_id", "")).strip_edges().is_empty():
		errors.append("actor requires authored anchor_id or zone_id.")
	if not ["idle", "watch", "patrol", "guard", "flee", "fight", "work", "depart"].has(str(payload.get("behavior", "idle"))):
		errors.append("actor payload behavior is not bounded.")


static func _validate_service_game_payload(payload: Dictionary, errors: Array) -> void:
	_append_unknown_keys("service/game payload", payload, ["id", "label", "enabled", "disabled_reason", "modifier"], errors)
	if not _valid_id(str(payload.get("id", ""))) or str(payload.get("label", "")).strip_edges().is_empty():
		errors.append("service/game payload requires id and label.")


static func _allowed_operation_keys(family: String, op_id: String) -> Array:
	var specific: Array = []
	match family:
		"scene_ops":
			specific = {
				"spawn": ["object"], "replace": ["object"], "move": ["anchor_id", "zone_id"],
				"disable": ["disabled_reason"], "set_state": ["state"], "set_appearance": ["appearance"],
			}.get(op_id, [])
		"interaction_ops":
			specific = {
				"add": ["interaction"],
				"replace": ["interaction", "mode", "target_owner_namespace", "target_stable_object_id"],
				"gate": ["mode", "target_owner_namespace", "target_stable_object_id", "enabled", "disabled_reason"],
				"retarget": ["mode", "target_owner_namespace", "target_stable_object_id", "source_id"],
				"augment": ["mode", "target_owner_namespace", "target_stable_object_id", "available_actions"],
			}.get(op_id, [])
		"actor_ops":
			specific = {"spawn": ["actor"], "set_position": ["anchor_id", "zone_id"], "set_route": ["route_id"], "set_pose": ["pose"], "set_behavior": ["behavior"]}.get(op_id, [])
		"transition_ops":
			specific = {
				"stage": ["channel", "message", "stage_id", "duration_boundaries", "reduced_motion_message"],
				"sound": ["channel", "cue_id"], "music": ["channel", "cue_id"],
				"scene_change": ["channel", "message", "change_id"], "feedback": ["channel", "message"],
			}.get(op_id, [])
		"service_ops":
			specific = {"add": ["object"], "replace": ["object"], "gate": ["enabled", "disabled_reason"]}.get(op_id, [])
		"game_ops":
			specific = {"add": ["object"], "replace": ["object"], "gate": ["enabled", "disabled_reason"], "set_modifier": ["modifier"]}.get(op_id, [])
		"route_ops":
			specific = {"close": ["disabled_reason"], "gate": ["enabled", "disabled_reason"], "retarget": ["source_id"]}.get(op_id, [])
	return COMMON_OPERATION_KEYS + specific


static func _validate_operation_fields(family: String, op_id: String, operation: Dictionary, errors: Array) -> void:
	match family:
		"scene_ops":
			if op_id == "move" and str(operation.get("anchor_id", "")).strip_edges().is_empty() and str(operation.get("zone_id", "")).strip_edges().is_empty():
				errors.append("scene move requires anchor_id or zone_id.")
			elif op_id == "set_state" and str(operation.get("state", "")).strip_edges().is_empty():
				errors.append("scene set_state requires state.")
			elif op_id == "set_appearance" and str(operation.get("appearance", "")).strip_edges().is_empty():
				errors.append("scene set_appearance requires appearance.")
			elif op_id == "disable" and str(operation.get("disabled_reason", "")).strip_edges().is_empty():
				errors.append("scene disable requires disabled_reason.")
		"interaction_ops":
			if op_id == "gate" and not operation.has("enabled"):
				errors.append("interaction gate requires enabled.")
			elif op_id == "gate" and not bool(operation.get("enabled", false)) and str(operation.get("disabled_reason", "")).strip_edges().is_empty():
				errors.append("disabled interaction gate requires disabled_reason.")
			elif op_id == "retarget" and str(operation.get("source_id", "")).strip_edges().is_empty():
				errors.append("interaction retarget requires source_id.")
			elif op_id == "augment" and _array(operation.get("available_actions", [])).is_empty():
				errors.append("interaction augment requires available_actions.")
			elif op_id == "augment":
				_validate_interaction_payload({
					"label": "Augment", "state_label": "Available", "prompt": "Choose.", "enabled": true,
					"available_actions": _array(operation.get("available_actions", [])), "input_actions": ["confirm"],
					"non_color_state": "available", "focus_order": 0, "hit_bounds": {"w": MIN_TARGET_SIZE, "h": MIN_TARGET_SIZE},
					"min_target_size": MIN_TARGET_SIZE, "safe_exit": false,
				}, errors)
		"actor_ops":
			if op_id == "set_position" and str(operation.get("anchor_id", "")).strip_edges().is_empty() and str(operation.get("zone_id", "")).strip_edges().is_empty():
				errors.append("actor set_position requires anchor_id or zone_id.")
			elif op_id == "set_route" and not _valid_id(str(operation.get("route_id", ""))):
				errors.append("actor set_route requires route_id.")
			elif op_id == "set_pose" and not _valid_id(str(operation.get("pose", ""))):
				errors.append("actor set_pose requires pose.")
		"transition_ops":
			if str(operation.get("channel", "")).strip_edges().is_empty():
				errors.append("transition operation requires channel.")
			if op_id == "stage":
				if not _valid_id(str(operation.get("stage_id", ""))) or str(operation.get("message", "")).strip_edges().is_empty() or int(operation.get("duration_boundaries", -1)) < 0 or int(operation.get("duration_boundaries", 0)) > 8 or str(operation.get("reduced_motion_message", "")).strip_edges().is_empty():
					errors.append("transition stage requires stage_id, message, bounded duration, and reduced-motion fallback.")
			elif op_id == "scene_change":
				if not _valid_id(str(operation.get("change_id", ""))) or str(operation.get("message", "")).strip_edges().is_empty():
					errors.append("transition scene_change requires change_id and message.")
			elif op_id == "feedback" and str(operation.get("message", "")).strip_edges().is_empty():
				errors.append("transition feedback requires message.")
		"service_ops", "game_ops":
			if op_id == "gate" and not operation.has("enabled"):
				errors.append("%s gate requires enabled." % family)
			elif op_id == "gate" and not bool(operation.get("enabled", false)) and str(operation.get("disabled_reason", "")).strip_edges().is_empty():
				errors.append("disabled %s gate requires disabled_reason." % family)
			if family == "game_ops" and op_id == "set_modifier" and _dict(operation.get("modifier", {})).is_empty():
				errors.append("game set_modifier requires modifier.")
		"route_ops":
			if op_id == "close" and str(operation.get("disabled_reason", "")).strip_edges().is_empty():
				errors.append("route close requires disabled_reason.")
			elif op_id == "gate" and not operation.has("enabled"):
				errors.append("route gate requires enabled.")
			elif op_id == "gate" and not bool(operation.get("enabled", false)) and str(operation.get("disabled_reason", "")).strip_edges().is_empty():
				errors.append("disabled route gate requires disabled_reason.")
			elif op_id == "retarget" and str(operation.get("source_id", "")).strip_edges().is_empty():
				errors.append("route retarget requires source_id.")


static func _validate_interaction_record(record: Dictionary, errors: Array, overlay: bool) -> void:
	var owner := str(record.get("owner_namespace", "")).strip_edges()
	var stable_id := str(record.get("stable_object_id", "")).strip_edges()
	if not OWNER_NAMESPACES.has(owner) or not _valid_id(stable_id):
		errors.append("interaction record has invalid stable owner identity.")
		return
	var mode := str(record.get("mode", "add")).strip_edges()
	if not ["add", "replace", "gate", "augment", "retarget"].has(mode):
		errors.append("interaction %s has invalid mode %s." % [identity(owner, stable_id), mode])
		return
	if not overlay and mode != "add":
		errors.append("base interaction %s must use add mode." % identity(owner, stable_id))
		return
	if overlay and mode != "add":
		var target_owner := str(record.get("target_owner_namespace", "")).strip_edges()
		var target_id := str(record.get("target_stable_object_id", "")).strip_edges()
		if not OWNER_NAMESPACES.has(target_owner) or not _valid_id(target_id):
			errors.append("interaction %s has invalid target identity." % identity(owner, stable_id))
			return
	if mode in ["add", "replace"]:
		_validate_interaction_payload(record, errors)
	elif mode == "gate":
		if not record.has("enabled") or typeof(record.get("enabled")) != TYPE_BOOL or not bool(record.get("enabled", false)) and str(record.get("disabled_reason", "")).strip_edges().is_empty():
			errors.append("interaction gate is missing enabled/disabled semantics.")
	elif mode == "augment":
		if _array(record.get("available_actions", [])).is_empty():
			errors.append("interaction augment requires actions.")
		else:
			_validate_interaction_payload({
				"label": "Augment", "state_label": "Available", "prompt": "Choose.", "enabled": true,
				"available_actions": _array(record.get("available_actions", [])), "input_actions": ["confirm"],
				"non_color_state": "available", "focus_order": 0, "hit_bounds": {"w": MIN_TARGET_SIZE, "h": MIN_TARGET_SIZE},
				"min_target_size": MIN_TARGET_SIZE, "safe_exit": false,
			}, errors)
	elif mode == "retarget" and str(record.get("source_id", "")).strip_edges().is_empty():
		errors.append("interaction retarget requires source_id.")


static func _append_unknown_keys(label: String, value: Dictionary, allowed: Array, errors: Array) -> void:
	for key_value in value.keys():
		if not allowed.has(str(key_value)):
			errors.append("%s contains unknown key: %s." % [label, str(key_value)])


static func _sort_interaction_overlay(a: Variant, b: Variant) -> bool:
	var left := a as Dictionary if typeof(a) == TYPE_DICTIONARY else {}
	var right := b as Dictionary if typeof(b) == TYPE_DICTIONARY else {}
	var left_priority := int(OWNER_PRIORITY.get(str(left.get("owner_namespace", "")), -1))
	var right_priority := int(OWNER_PRIORITY.get(str(right.get("owner_namespace", "")), -1))
	if left_priority != right_priority:
		return left_priority < right_priority
	return identity_from(left) < identity_from(right)


static func _contains_forbidden_path(value: Variant) -> bool:
	return _contains_forbidden_path_inner(value, 0, [])


static func _contains_forbidden_path_inner(value: Variant, depth: int, ancestors: Array) -> bool:
	if depth > MAX_VARIANT_DEPTH:
		return true
	if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		for ancestor in ancestors:
			if is_same(ancestor, value):
				return true
		var next_ancestors := ancestors.duplicate(false)
		next_ancestors.append(value)
		if typeof(value) == TYPE_DICTIONARY:
			for nested in (value as Dictionary).values():
				if _contains_forbidden_path_inner(nested, depth + 1, next_ancestors): return true
		else:
			for nested in value as Array:
				if _contains_forbidden_path_inner(nested, depth + 1, next_ancestors): return true
	elif typeof(value) == TYPE_STRING:
		var source_text := str(value)
		return source_text.begins_with("res://") or source_text.begins_with("user://") or source_text.contains("../") or source_text.contains("/root/") or source_text.contains("get_node(")
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


static func _valid_boundary_scope(value: String) -> bool:
	var parts := value.strip_edges().split(":", false)
	if parts.size() < 4:
		return false
	for part_value in parts:
		if not _valid_id(str(part_value)):
			return false
	return true


static func _finite_number(value: Variant) -> bool:
	if not [TYPE_INT, TYPE_FLOAT].has(typeof(value)):
		return false
	return not is_nan(float(value)) and not is_inf(float(value))


static func _strict_id_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item_value in value as Array:
		if typeof(item_value) != TYPE_STRING:
			return []
		var item := str(item_value).strip_edges()
		if not _valid_id(item) or result.has(item):
			return []
		result.append(item)
	return result


static func _canonical_variant(value: Variant) -> Variant:
	return _canonical_variant_inner(value, 0, [])


static func _canonical_variant_inner(value: Variant, depth: int, ancestors: Array) -> Variant:
	if depth > MAX_VARIANT_DEPTH:
		return "<depth-limit>"
	if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		for ancestor in ancestors:
			if is_same(ancestor, value):
				return "<cycle>"
		var next_ancestors := ancestors.duplicate(false)
		next_ancestors.append(value)
		if typeof(value) == TYPE_DICTIONARY:
			var result: Dictionary = {}
			var keys := (value as Dictionary).keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			for key_value in keys:
				result[str(key_value)] = _canonical_variant_inner((value as Dictionary).get(key_value), depth + 1, next_ancestors)
			return result
		var result_array: Array = []
		for item_value in value as Array:
			result_array.append(_canonical_variant_inner(item_value, depth + 1, next_ancestors))
		return result_array
	return value


static func _validate_bounded_variant(label: String, value: Variant, depth: int, budget: Dictionary, ancestors: Array, errors: Array) -> void:
	if errors.size() >= 16:
		return
	budget["count"] = int(budget.get("count", 0)) + 1
	if int(budget.get("count", 0)) > MAX_VARIANT_VALUES:
		errors.append("%s exceeds the bounded value count." % label)
		return
	if depth > MAX_VARIANT_DEPTH:
		errors.append("%s exceeds the bounded nesting depth." % label)
		return
	var value_type := typeof(value)
	if value_type in [TYPE_DICTIONARY, TYPE_ARRAY]:
		for ancestor in ancestors:
			if is_same(ancestor, value):
				errors.append("%s contains a recursive container cycle." % label)
				return
		var size := (value as Dictionary).size() if value_type == TYPE_DICTIONARY else (value as Array).size()
		if size > MAX_VARIANT_COLLECTION:
			errors.append("%s contains a collection exceeding %d entries." % [label, MAX_VARIANT_COLLECTION])
			return
		var next_ancestors := ancestors.duplicate(false)
		next_ancestors.append(value)
		if value_type == TYPE_DICTIONARY:
			for key_value in (value as Dictionary).keys():
				if typeof(key_value) != TYPE_STRING or str(key_value).length() > MAX_VARIANT_TEXT:
					errors.append("%s contains an invalid or oversized dictionary key." % label)
					continue
				_validate_bounded_variant(label, (value as Dictionary).get(key_value), depth + 1, budget, next_ancestors, errors)
		else:
			for nested in value as Array:
				_validate_bounded_variant(label, nested, depth + 1, budget, next_ancestors, errors)
	elif value_type == TYPE_STRING:
		if str(value).length() > MAX_VARIANT_TEXT:
			errors.append("%s contains text exceeding %d characters." % [label, MAX_VARIANT_TEXT])
	elif value_type == TYPE_FLOAT:
		if not _finite_number(value):
			errors.append("%s contains a non-finite number." % label)
	elif not [TYPE_NIL, TYPE_BOOL, TYPE_INT].has(value_type):
		errors.append("%s contains unsupported Variant type %d." % [label, value_type])


static func _length_prefixed(value: String) -> String:
	return "%d:%s" % [value.length(), value]


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
