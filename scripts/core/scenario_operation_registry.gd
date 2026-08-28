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
	"set_local": {"inputs": ["key", "value"], "input_specs": {"key": "CanonicalId/local_field", "value": "LocalValue(key)"}, "fact_projection": {"input": "value", "selector": "value_from_payload"}, "allowed_sources": ["command", "fact"], "outputs": ["local_state"], "output_paths": ["local_state.<key>"], "write_algebra": "validated_replace", "persistent": true, "rng": "none", "fallible": true, "atomic": true, "idempotence": "same-value state-idempotent; dispatch receipt exactly-once", "may_trigger_branch_resolution": ["local_equals", "local_min"], "external_effects": []},
	"increment_local": {"inputs": ["key", "amount"], "input_specs": {"key": "CanonicalId/int_local_field", "amount": "int"}, "fact_projection": "none", "allowed_sources": ["command", "fact"], "outputs": ["local_state"], "output_paths": ["local_state.<key>"], "write_algebra": "integer_add_then_saturating_clamp", "persistent": true, "rng": "none", "fallible": true, "atomic": true, "idempotence": "receipt-dependent", "may_trigger_branch_resolution": ["local_equals", "local_min"], "external_effects": []},
	"complete_objective_step": {"inputs": ["objective_id", "step_id"], "input_specs": {"objective_id": "ObjectiveRef.objective_id", "step_id": "ObjectiveRef.step_id"}, "fact_projection": "none", "allowed_sources": ["command", "fact"], "outputs": ["objective_progress"], "output_paths": ["objective_progress.<objective_id>.completed_steps"], "write_algebra": "ordered_set_union_append", "persistent": true, "rng": "none", "fallible": true, "atomic": true, "idempotence": "state-idempotent", "may_trigger_branch_resolution": ["objective"], "external_effects": []},
	"resolve_objective": {"inputs": ["objective_id", "outcome"], "input_specs": {"objective_id": "ObjectiveRef.objective_id", "outcome": "ObjectiveOutcome"}, "fact_projection": "none", "allowed_sources": ["command", "fact"], "outputs": ["objective_progress"], "output_paths": ["objective_progress.<objective_id>.outcome"], "write_algebra": "validated_replace", "persistent": true, "rng": "none", "fallible": true, "atomic": true, "idempotence": "same-value state-idempotent", "may_trigger_branch_resolution": ["objective"], "external_effects": []},
	"record_outcome": {"inputs": ["outcome"], "input_specs": {"outcome": "OutcomeRef"}, "fact_projection": "none", "allowed_sources": ["command", "fact"], "outputs": ["resolved_outcomes"], "output_paths": ["resolved_outcomes"], "write_algebra": "ordered_set_union_append", "persistent": true, "rng": "none", "fallible": true, "atomic": true, "idempotence": "state-idempotent", "may_trigger_branch_resolution": ["outcome"], "external_effects": []},
	"publish_feedback": {"inputs": ["message"], "input_specs": {"message": "bounded_nonblank_path_safe_string"}, "fact_projection": "none", "allowed_sources": ["command", "fact"], "outputs": ["last_feedback", "semantic_state"], "output_paths": ["last_feedback", "semantic_state.transition_queue"], "write_algebra": "replace_plus_queue_append", "persistent": true, "rng": "none", "fallible": true, "atomic": true, "idempotence": "dispatch receipt exactly-once", "may_trigger_branch_resolution": [], "external_effects": []},
	"request_cleanup": {"inputs": ["reason"], "input_specs": {"reason": "CanonicalId"}, "fact_projection": "none", "allowed_sources": ["command", "fact"], "outputs": ["semantic_state", "cleanup_receipts", "cleanup_receipt_records", "cleanup_fingerprints", "cleanup_content_fingerprint", "status"], "output_paths": ["semantic_state", "cleanup_receipts", "cleanup_receipt_records", "cleanup_fingerprints", "cleanup_content_fingerprint", "status"], "write_algebra": "transactional_cleanup_batch", "persistent": true, "rng": "none", "fallible": true, "atomic": true, "idempotence": "fingerprint-verified replay", "may_trigger_branch_resolution": [], "external_effects": []},
	"event_bridge": {"inputs": ["event_id", "resolution_id"], "input_specs": {"event_id": "EventChoiceRef.event_id", "resolution_id": "EventChoiceRef.choice_id"}, "fact_projection": "none", "allowed_sources": ["command", "fact"], "outputs": ["event_request_queue", "last_feedback", "event_correlations"], "output_paths": ["event_request_queue", "last_feedback", "event_correlations"], "write_algebra": "replace_plus_ordered_set_union", "persistent": true, "rng": "none", "fallible": true, "atomic": true, "idempotence": "correlation-key state-idempotent", "may_trigger_branch_resolution": [], "external_effects": [{"type": "event_correlation", "owner": "EventModule"}]},
}
const MAX_OPERATIONS_PER_BATCH := 32
const MAX_ACTIONS_PER_INTERACTION := 8
const MAX_OPERATION_RECEIPTS := 512
const MAX_TRANSITION_QUEUE := 128
const MAX_VARIANT_DEPTH := 12
# The closed runtime can retain 256 authenticated command/fact causes. Their
# exact envelopes, replay results, fingerprints, and receipt records exceed the
# old 4096-node aggregate traversal budget before the declared lifetime limit.
# Depth, per-container, per-string, and authoritative receipt bounds remain the
# controlling limits; this is only the aggregate traversal ceiling.
const MAX_VARIANT_VALUES := 16384
const MAX_VARIANT_TEXT := 512
const MAX_VARIANT_COLLECTION := 512
const MIN_TARGET_SIZE := 44.0
const COMMON_OPERATION_KEYS := ["family", "op", "receipt_id", "owner_namespace", "stable_object_id"]
const PUBLIC_SEMANTIC_KEYS := ["actors", "games", "interactions", "routes", "scene_objects", "services"]


static func identity(owner_namespace: String, stable_object_id: String) -> String:
	return "%s::%s" % [owner_namespace, stable_object_id]


static func parse_owned_identity(value: String) -> Dictionary:
	if value != value.strip_edges() or value.count("::") != 1:
		return {}
	var separator := value.find("::")
	var owner := value.substr(0, separator)
	var stable_object_id := value.substr(separator + 2)
	if not OWNER_NAMESPACES.has(owner) or not _valid_semantic_object_id(stable_object_id):
		return {}
	return {"owner_namespace": owner, "stable_object_id": stable_object_id, "owned_identity": value}


static func validate_owned_identity(value: String) -> Array:
	return [] if not parse_owned_identity(value).is_empty() else ["owned identity must contain exactly one canonical owner::stable:id value."]


static func target_key(collection: String, owner_namespace: String, stable_object_id: String) -> String:
	return _length_prefixed(collection) + _length_prefixed(owner_namespace) + _length_prefixed(stable_object_id)


static func identity_from(value: Dictionary, prefix: String = "") -> String:
	var owner_key := "%sowner_namespace" % prefix
	var id_key := "%sstable_object_id" % prefix
	return identity(str(value.get(owner_key, "")), str(value.get(id_key, "")))


static func registered_operations() -> Dictionary:
	return OP_FAMILIES.duplicate(true)


static func registered_handlers() -> Dictionary:
	return REGISTERED_HANDLERS.duplicate(true)


static func normalize_semantic_state(value: Dictionary) -> Dictionary:
	return _normalize_semantic_state(value)


static func validate_handler_inputs(handler_id: String, inputs: Dictionary, local_schema: Dictionary = {}, reachable_outcomes: Array = [], context: Dictionary = {}) -> Array:
	var errors: Array = []
	errors.append_array(validate_bounded_variant("scenario handler inputs", inputs))
	var contract := _dict(REGISTERED_HANDLERS.get(handler_id, {}))
	if contract.is_empty(): return ["scenario handler is unregistered: %s." % handler_id]
	var source := str(context.get("source", "command"))
	if not _array(contract.get("allowed_sources", [])).has(source): errors.append("scenario handler %s is not allowed from %s." % [handler_id, source])
	var projection := inputs.has("value_from_payload")
	var allowed_inputs := _array(contract.get("inputs", []))
	if projection: allowed_inputs.append("value_from_payload")
	_append_unknown_keys("scenario handler %s inputs" % handler_id, inputs, allowed_inputs, errors)
	if projection and handler_id != "set_local": errors.append("value_from_payload is allowed only for set_local.")
	if handler_id == "set_local":
		if inputs.has("value") == projection: errors.append("set_local requires exactly one of value or value_from_payload.")
		if not inputs.has("key"): errors.append("scenario handler set_local requires input key.")
	else:
		for input_value in _array(contract.get("inputs", [])):
			if not inputs.has(str(input_value)): errors.append("scenario handler %s requires input %s." % [handler_id, str(input_value)])
	if not errors.is_empty(): return errors
	match handler_id:
		"set_local":
			if typeof(inputs.get("key")) != TYPE_STRING or not _canonical_id(str(inputs.get("key", ""))): return ["set_local key must be a canonical local field id."]
			var field_id := str(inputs.get("key", ""))
			var field := _dict(local_schema.get(field_id, {}))
			if field.is_empty(): errors.append("set_local references an unknown local field.")
			elif projection:
				if typeof(inputs.get("value_from_payload")) != TYPE_STRING or not _canonical_id(str(inputs.get("value_from_payload", ""))): errors.append("set_local value_from_payload must be a canonical top-level payload key.")
				else:
					var selector := str(inputs.get("value_from_payload", ""))
					var payload_types := _dict(context.get("fact_payload_types", {}))
					if not payload_types.has(selector): errors.append("set_local value_from_payload is not registered for the selected fact type.")
					elif not _payload_type_can_target_local(str(payload_types.get(selector, "")), str(field.get("type", ""))): errors.append("set_local fact selector type does not match the target local type.")
			elif not _value_matches_local_type(inputs.get("value"), str(field.get("type", "")), field): errors.append("set_local value does not match the declared local field type/domain.")
		"increment_local":
			if typeof(inputs.get("key")) != TYPE_STRING or not _canonical_id(str(inputs.get("key", ""))): errors.append("increment_local key must be a canonical local field id.")
			var field_id := str(inputs.get("key", ""))
			var field_type := str(_dict(local_schema.get(field_id, {})).get("type", ""))
			if field_type != "int": errors.append("increment_local requires a declared integer local field.")
			elif typeof(inputs.get("amount")) != TYPE_INT: errors.append("increment_local requires an exact integer amount.")
		"complete_objective_step":
			if typeof(inputs.get("objective_id")) != TYPE_STRING or typeof(inputs.get("step_id")) != TYPE_STRING or not _canonical_id(str(inputs.get("objective_id", ""))) or not _canonical_id(str(inputs.get("step_id", ""))): errors.append("complete_objective_step requires canonical string ids.")
			else:
				var objective_id := str(inputs.get("objective_id", ""))
				var objective_steps := _dict(context.get("objective_steps", {}))
				if not objective_steps.is_empty() and (not objective_steps.has(objective_id) or not _dict(objective_steps.get(objective_id, {})).has(str(inputs.get("step_id", "")))): errors.append("complete_objective_step requires an exact authored objective step.")
				if source == "command" and context.has("phase_objective_ids") and not _array(context.get("phase_objective_ids", [])).has(objective_id): errors.append("complete_objective_step objective is not owned by the containing phase.")
		"resolve_objective":
			if typeof(inputs.get("objective_id")) != TYPE_STRING or not _canonical_id(str(inputs.get("objective_id", ""))) or typeof(inputs.get("outcome")) != TYPE_STRING or str(inputs.get("outcome", "")) not in ["success", "failure", "ignore", "cancel"]: errors.append("resolve_objective requires an authored objective and valid outcome.")
			elif not _dict(context.get("objective_steps", {})).has(str(inputs.get("objective_id", ""))): errors.append("resolve_objective references an unknown objective.")
		"record_outcome":
			if typeof(inputs.get("outcome")) != TYPE_STRING or not _canonical_id(str(inputs.get("outcome", ""))) or not reachable_outcomes.has(str(inputs.get("outcome", ""))): errors.append("record_outcome requires an authored reachable outcome with matching aftermath.")
		"publish_feedback":
			if typeof(inputs.get("message")) != TYPE_STRING or str(inputs.get("message", "")).strip_edges().is_empty() or str(inputs.get("message", "")).length() > MAX_VARIANT_TEXT or _contains_forbidden_path(inputs.get("message")): errors.append("publish_feedback requires bounded nonempty path-safe text.")
		"request_cleanup":
			if typeof(inputs.get("reason")) != TYPE_STRING or not _canonical_id(str(inputs.get("reason", ""))): errors.append("request_cleanup requires a canonical lowercase cleanup reason id.")
		"event_bridge":
			if typeof(inputs.get("event_id")) != TYPE_STRING or typeof(inputs.get("resolution_id")) != TYPE_STRING or not _canonical_id(str(inputs.get("event_id", ""))) or not _canonical_id(str(inputs.get("resolution_id", ""))): errors.append("event_bridge requires canonical event and resolution ids.")
			var event_choices := _dict(context.get("event_choices", {}))
			if event_choices.is_empty() or not _array(event_choices.get(str(inputs.get("event_id", "")), [])).has(str(inputs.get("resolution_id", ""))): errors.append("event_bridge requires a catalog-proven choice belonging to the exact event.")
	return errors


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
	if not OWNER_NAMESPACES.has(owner) or not _valid_semantic_object_id(stable_id):
		errors.append("%s %s requires registered owner_namespace and stable_object_id." % [family, op_id])
	if not _valid_id(str(operation.get("receipt_id", ""))):
		errors.append("%s %s requires a stable authored receipt_id." % [family, op_id])
	var mode := str(operation.get("mode", "")).strip_edges()
	if family == "interaction_ops" and not ["add", "remove"].has(op_id):
		if mode != op_id:
			errors.append("interaction %s requires matching explicit mode." % op_id)
		var target_owner := str(operation.get("target_owner_namespace", "")).strip_edges()
		var target_id := str(operation.get("target_stable_object_id", "")).strip_edges()
		if not OWNER_NAMESPACES.has(target_owner) or not _valid_semantic_object_id(target_id):
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
			var expected_presentation_id := identity(owner, stable_id)
			if payload.has("presentation_object_id") and str(payload.get("presentation_object_id", "")) != expected_presentation_id:
				errors.append("scenario interaction presentation_object_id must equal its full owned identity %s." % expected_presentation_id)
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


static func operation_fingerprint(operation: Dictionary) -> String:
	return JSON.stringify(_canonical_variant(operation)).sha256_text()


static func validate_bounded_variant(label: String, value: Variant) -> Array:
	var errors: Array = []
	_validate_bounded_variant(label, value, 0, {"count": 0}, [], errors)
	return errors


static func apply_operations(state_value: Dictionary, family: String, operations: Array, boundary_id: String, cleanup_restore: bool = false) -> Dictionary:
	var state_validation := validate_bounded_variant("scenario semantic state", state_value)
	if not state_validation.is_empty():
		return {"ok": false, "state": state_value, "applied": [], "errors": state_validation}
	var original := _normalize_semantic_state(state_value)
	if not OP_FAMILIES.has(family):
		return {"ok": false, "state": original, "applied": [], "errors": ["operation family is unregistered: %s." % family]}
	if boundary_id.length() > MAX_VARIANT_TEXT or not _valid_boundary_scope(boundary_id):
		return {"ok": false, "state": original, "applied": [], "errors": ["operation batch requires an instance/content/phase/boundary scope."]}
	if operations.size() > MAX_OPERATIONS_PER_BATCH:
		return {"ok": false, "state": original, "applied": [], "errors": ["operation batch exceeds %d entries." % MAX_OPERATIONS_PER_BATCH]}
	var applied: Array = []
	var errors: Array = []
	var authored_receipts: Dictionary = {}
	var pending: Array = []
	var fingerprints := _dict(original.get("operation_fingerprints", {}))
	var collection_key := _collection_key(family)
	var known_targets := _dict(original.get(collection_key, {}))
	# Sealed host targets are live even before a scenario materializes its overlay.
	# Per-operation declared-target checks below still gate mutation, while create
	# operations continue to reject every identity already present in inventory.
	for target_value in _string_array(_dict(original.get("target_inventory", {})).get(collection_key, [])):
		known_targets[str(target_value)] = true
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
			var fingerprint := operation_fingerprint(candidate)
			if fingerprints.has(authoritative_receipt) and str(fingerprints.get(authoritative_receipt, "")) != fingerprint:
				errors.append("operation receipt %s was reused for conflicting content." % authoritative_receipt)
			pending.append({"operation": candidate.duplicate(true), "receipt_id": authoritative_receipt, "authored_receipt_id": authored_receipt, "fingerprint": fingerprint, "operation_index": index})
			# An exact structural receipt plus content fingerprint authenticates a
			# replay against the state that already contains its result. Do not run
			# create/live-target validation a second time; conflicting fingerprints
			# remain errors above and every new receipt is validated below.
			if existing_receipts.has(authoritative_receipt) and str(fingerprints.get(authoritative_receipt, "")) == fingerprint:
				continue
		_validate_and_track_target(family, candidate, known_targets, errors)
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
		var target_errors := _validate_operation_target(state, family, _dict(item.get("operation", {})), cleanup_restore)
		if not target_errors.is_empty(): errors.append_array(target_errors)
		else: _apply_operation(state, family, _dict(item.get("operation", {})), receipt_id, boundary_id, str(item.get("fingerprint", "")), cleanup_restore)
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
		records.append({
			"receipt_key": receipt_id,
			"boundary_id": boundary_id.strip_edges(),
			"boundary_kind": _boundary_kind(boundary_id),
			"boundary_ordinal": _boundary_ordinal(records, boundary_id),
			"family": family,
			"authored_receipt_id": str(item.get("authored_receipt_id", "")),
			"operation_index": int(item.get("operation_index", -1)),
			"fingerprint": str(item.get("fingerprint", "")),
			"source_ref": _boundary_source_ref(boundary_id),
		})
		state["operation_receipt_records"] = records
		applied.append(receipt_id)
	var result_validation := validate_bounded_variant("scenario semantic state after operation batch", state)
	if not result_validation.is_empty():
		return {"ok": false, "state": original, "applied": [], "errors": result_validation}
	return {"ok": true, "state": state, "applied": applied, "errors": []}


static func resolve_interactions(base_records: Array, overlay_records: Array) -> Dictionary:
	var records: Dictionary = {}
	var tainted: Dictionary = {}
	var errors: Array = []
	# Reject cycles/oversize graphs before any recursive duplicate. This direct
	# resolver is a public ingress, not merely a helper behind operation validation.
	var input_errors := validate_bounded_variant("base interaction records", base_records)
	input_errors.append_array(validate_bounded_variant("overlay interaction records", overlay_records))
	if not input_errors.is_empty(): return {"ok": false, "records": [], "errors": input_errors}
	for source_value in base_records:
		_ingest_interaction_record(records, tainted, errors, source_value, false)
	for source_value in overlay_records:
		_ingest_interaction_record(records, tainted, errors, source_value, true)
	# Effective overlay ownership is reducer-private. Mutating a base-owned record
	# must not rewrite its public identity, but later overlays still compare against
	# the strongest owner that already won that target.
	var effective_winners: Dictionary = {}
	for record_key_value in records.keys():
		var record_key := str(record_key_value)
		var record := _dict(records.get(record_key_value, {}))
		if str(record.get("mode", "add")) == "add":
			effective_winners[record_key] = {
				"priority": int(OWNER_PRIORITY.get(str(record.get("owner_namespace", "")), -1)),
				"owner_namespace": str(record.get("owner_namespace", "")),
				"source_key": record_key,
			}
	var ordered_overlays := overlay_records.duplicate(true)
	ordered_overlays.sort_custom(Callable(ScenarioOperationRegistry, "_sort_interaction_overlay"))
	var accepted_overlay_source_identities: Array = []
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
		var competing_claims := _string_array(target_claims.get(target_key, []))
		if competing_claims.size() > 1 and source_key != str(competing_claims[0]):
			var winner_source := str(competing_claims[0])
			errors.append("interaction target claim loser %s cannot override %s; canonical winner is %s." % [source_key, target_key, winner_source])
			records.erase(source_key)
			continue
		var priority := int(OWNER_PRIORITY.get(str(overlay.get("owner_namespace", "")), -1))
		var effective_winner := _dict(effective_winners.get(target_key, {}))
		var effective_priority := int(effective_winner.get("priority", -1))
		if not effective_winner.is_empty() and priority < effective_priority:
			errors.append("interaction %s cannot override higher-priority %s owned by %s." % [source_key, target_key, str(effective_winner.get("owner_namespace", ""))])
			records.erase(source_key)
			continue
		if not records.has(target_key):
			errors.append("interaction %s targets missing identity %s." % [identity_from(overlay), target_key])
			records.erase(source_key)
			continue
		var target_priority := effective_priority if not effective_winner.is_empty() else int(OWNER_PRIORITY.get(str((records.get(target_key, {}) as Dictionary).get("owner_namespace", "")), -1))
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
				if not bool(target.get("enabled", false)):
					target["available_actions"] = []
					target["input_actions"] = []
				records[target_key] = target
				records.erase(source_key)
			"augment":
				var target := (records.get(target_key, {}) as Dictionary).duplicate(true)
				var actions := _array(target.get("available_actions", []))
				var existing_action_ids := _action_ids(actions)
				var collision_id := ""
				for action_value in _array(overlay.get("available_actions", [])):
					var action_id := str(_dict(action_value).get("id", ""))
					if existing_action_ids.has(action_id):
						collision_id = action_id
						break
				if not collision_id.is_empty():
					errors.append("interaction %s augment action id %s collides with target %s." % [source_key, collision_id, target_key])
					records.erase(source_key)
					continue
				for action_value in _array(overlay.get("available_actions", [])):
					if typeof(action_value) == TYPE_DICTIONARY:
						var augmented_action := (action_value as Dictionary).duplicate(true)
						augmented_action["action_origin_owner_namespace"] = str(overlay.get("owner_namespace", ""))
						augmented_action["action_origin_stable_object_id"] = str(overlay.get("stable_object_id", ""))
						augmented_action["action_origin_receipt_key"] = str(overlay.get("operation_receipt_key", ""))
						augmented_action["action_origin_boundary_id"] = str(overlay.get("operation_boundary_id", ""))
						augmented_action["action_origin_fingerprint"] = str(overlay.get("operation_fingerprint", ""))
						actions.append(augmented_action)
				target["available_actions"] = actions
				records[target_key] = target
				records.erase(source_key)
			"retarget":
				var target := (records.get(target_key, {}) as Dictionary).duplicate(true)
				target["source_id"] = str(overlay.get("source_id", target.get("source_id", "")))
				records[target_key] = target
				records.erase(source_key)
		var effective_key := target_key
		if mode == "replace":
			effective_winners.erase(target_key)
			effective_key = source_key
		effective_winners[effective_key] = {
			"priority": priority,
			"owner_namespace": str(overlay.get("owner_namespace", "")),
			"source_key": source_key,
		}
		accepted_overlay_source_identities.append(source_key)
	var result: Array = []
	var keys := records.keys()
	keys.sort()
	for key_value in keys:
		if not tainted.has(str(key_value)):
			result.append((records.get(key_value, {}) as Dictionary).duplicate(true))
	return {
		"ok": errors.is_empty(),
		"records": result,
		"errors": errors,
		"accepted_overlay_source_identities": accepted_overlay_source_identities,
	}


static func _ingest_interaction_record(records: Dictionary, tainted: Dictionary, errors: Array, source_value: Variant, overlay: bool) -> void:
	if typeof(source_value) != TYPE_DICTIONARY:
		errors.append("interaction record must be a dictionary.")
		return
	var bounded_errors := validate_bounded_variant("interaction record", source_value)
	if not bounded_errors.is_empty():
		errors.append_array(bounded_errors)
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
	var actions: Array = []
	for action_value in _array(source.get("available_actions", [])):
		var action := _dict(action_value)
		action["action_origin_owner_namespace"] = str(source.get("owner_namespace", ""))
		action["action_origin_stable_object_id"] = str(source.get("stable_object_id", ""))
		if not str(source.get("operation_receipt_key", "")).is_empty():
			action["action_origin_receipt_key"] = str(source.get("operation_receipt_key", ""))
			action["action_origin_boundary_id"] = str(source.get("operation_boundary_id", ""))
			action["action_origin_fingerprint"] = str(source.get("operation_fingerprint", ""))
		actions.append(action)
	source["available_actions"] = actions
	records[key] = source


static func _apply_operation(state: Dictionary, family: String, operation: Dictionary, receipt_id: String, boundary_id: String, fingerprint: String, cleanup_restore: bool = false) -> void:
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
	if cleanup_restore and family == "interaction_ops" and not ["add", "remove"].has(op_id) and collection.has(key):
		collection.erase(key)
		state[collection_key] = collection
		return
	if cleanup_restore and _inventory_has(state, collection_key, key) and not (family == "scene_ops" and op_id == "spawn" or family == "interaction_ops" and op_id == "add" or family == "actor_ops" and op_id == "spawn" or family in ["service_ops", "game_ops"] and op_id == "add") and not ["remove", "despawn"].has(op_id):
		collection.erase(key)
		state[collection_key] = collection
		return
	if family == "interaction_ops" and not ["add", "remove"].has(op_id):
		var overlay := payload
		overlay["owner_namespace"] = str(operation.get("owner_namespace", ""))
		overlay["stable_object_id"] = str(operation.get("stable_object_id", ""))
		for overlay_key in ["mode", "target_owner_namespace", "target_stable_object_id", "enabled", "disabled_reason", "source_id", "available_actions"]:
			if operation.has(overlay_key):
				overlay[overlay_key] = operation.get(overlay_key)
		overlay["operation_receipt_key"] = receipt_id
		overlay["operation_boundary_id"] = boundary_id
		overlay["operation_fingerprint"] = fingerprint
		collection[key] = overlay
		state[collection_key] = collection
		return
	if ["remove", "despawn"].has(op_id):
		collection.erase(key)
		if _inventory_has(state, collection_key, key):
			var tombstones := _dict(state.get("tombstones", {}))
			var collection_tombstones := _dict(tombstones.get(collection_key, {}))
			if cleanup_restore: collection_tombstones.erase(key)
			else: collection_tombstones[key] = true
			tombstones[collection_key] = collection_tombstones
			state["tombstones"] = tombstones
	elif ["spawn", "add", "replace"].has(op_id):
		payload["owner_namespace"] = str(operation.get("owner_namespace", ""))
		payload["stable_object_id"] = str(operation.get("stable_object_id", ""))
		if family == "interaction_ops":
			payload["presentation_object_id"] = key
			payload["operation_receipt_key"] = receipt_id
			payload["operation_boundary_id"] = boundary_id
			payload["operation_fingerprint"] = fingerprint
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
				if family == "interaction_ops" and not bool(current.get("enabled", false)):
					current["available_actions"] = []
					current["input_actions"] = []
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


static func _validate_operation_target(state: Dictionary, family: String, operation: Dictionary, cleanup_restore: bool = false) -> Array:
	if family == "transition_ops":
		return []
	var errors: Array = []
	var collection_key := _collection_key(family)
	var collection := _dict(state.get(collection_key, {}))
	var key := identity_from(operation)
	var op_id := str(operation.get("op", "")).strip_edges()
	if family in ["scene_ops", "actor_ops"]:
		var spatial_source := _dict(operation.get("object", operation.get("actor", {}))) if op_id in ["spawn", "replace"] else operation
		for spatial_kind in ["anchor", "zone"]:
			var spatial_id := str(spatial_source.get("%s_id" % spatial_kind, "")).strip_edges()
			if not spatial_id.is_empty():
				var spatial_identity := identity("base", "%s:%s" % [spatial_kind, spatial_id])
				var collection_name := "%ss" % spatial_kind
				if not _target_declared(state, collection_name, spatial_identity):
					errors.append("%s %s references undeclared or unavailable %s %s." % [family, op_id, spatial_kind, spatial_id])
	if family == "actor_ops" and op_id == "set_route":
		var route_id := str(operation.get("route_id", ""))
		var route_authorized := not parse_owned_identity(route_id).is_empty() and _string_array(_dict(state.get("declared_targets", {})).get("routes", [])).has(route_id) and _inventory_has(state, "routes", route_id)
		if not route_authorized:
			errors.append("actor set_route requires an exact owned route identity, got %s." % route_id)
	var create_operation := family == "scene_ops" and op_id == "spawn" or family == "interaction_ops" and op_id == "add" or family == "actor_ops" and op_id == "spawn" or family in ["service_ops", "game_ops"] and op_id == "add"
	if create_operation:
		if str(operation.get("owner_namespace", "")) != "scenario":
			errors.append("%s %s requires scenario ownership." % [family, op_id])
		elif collection.has(key) or _inventory_has(state, collection_key, key):
			errors.append("%s %s cannot create existing identity %s." % [family, op_id, key])
		return errors
	if family == "interaction_ops" and not ["add", "remove"].has(op_id):
		if cleanup_restore:
			if not collection.has(key):
				var cleanup_target_key := identity(str(operation.get("target_owner_namespace", "")), str(operation.get("target_stable_object_id", "")))
				if not collection.has(cleanup_target_key) and not _target_declared(state, collection_key, cleanup_target_key):
					errors.append("interaction cleanup overlay target is not live: %s." % cleanup_target_key)
			return errors
		if collection.has(key):
			var existing_overlay := _dict(collection.get(key, {}))
			var existing_target := identity(str(existing_overlay.get("target_owner_namespace", "")), str(existing_overlay.get("target_stable_object_id", "")))
			var requested_target := identity(str(operation.get("target_owner_namespace", "")), str(operation.get("target_stable_object_id", "")))
			if existing_target != requested_target or str(existing_overlay.get("mode", "")) != op_id:
				errors.append("interaction overlay identity already exists with different authority: %s." % key)
			return errors
		var target_key := identity(str(operation.get("target_owner_namespace", "")), str(operation.get("target_stable_object_id", "")))
		if not collection.has(target_key) and not _target_declared(state, collection_key, target_key):
			errors.append("interaction %s targets undeclared missing identity %s." % [key, target_key])
		return errors
	if ["remove", "despawn"].has(op_id):
		if not collection.has(key) and not _target_declared(state, collection_key, key) and not (cleanup_restore and _target_authorized(state, collection_key, key)):
			errors.append("%s %s targets missing identity %s." % [family, op_id, key])
		return errors
	if not collection.has(key) and not _target_declared(state, collection_key, key):
		errors.append("%s %s targets undeclared missing identity %s." % [family, op_id, key])
	return errors


static func _normalize_semantic_state(value: Dictionary) -> Dictionary:
	return {
		"base_interactions": _array(value.get("base_interactions", [])),
		"event_choices": _dict(value.get("event_choices", {})),
		"inventory_schema_version": maxi(0, int(value.get("inventory_schema_version", 0))),
		"inventory_digest": str(value.get("inventory_digest", "")),
		"scene_objects": _dict(value.get("scene_objects", {})),
		"interactions": _dict(value.get("interactions", {})),
		"actors": _dict(value.get("actors", {})),
		"services": _dict(value.get("services", {})),
		"games": _dict(value.get("games", {})),
		"routes": _dict(value.get("routes", {})),
		"transition_queue": _array(value.get("transition_queue", [])),
		"operation_receipts": _string_array(value.get("operation_receipts", [])),
		"operation_receipt_records": _array(value.get("operation_receipt_records", [])),
		"operation_fingerprints": _normalized_operation_fingerprints(value.get("operation_fingerprints", {}), value.get("operation_receipts", [])),
		"tombstones": _dict(value.get("tombstones", {})),
		"declared_targets": _normalize_declared_targets(value.get("declared_targets", {})),
		"target_inventory": _normalize_declared_targets(value.get("target_inventory", {})),
	}


static func resolved_semantic_state(state_value: Dictionary) -> Dictionary:
	var state := _normalize_semantic_state(state_value)
	var overlays: Array = []
	for value in _dict(state.get("interactions", {})).values(): overlays.append(value)
	var base_records: Array = []
	var interaction_tombstones := _dict(_dict(state.get("tombstones", {})).get("interactions", {}))
	for value in _array(state.get("base_interactions", [])):
		if typeof(value) == TYPE_DICTIONARY and not interaction_tombstones.has(identity_from(value as Dictionary)): base_records.append(value)
	var resolved := resolve_interactions(base_records, overlays)
	var interactions: Dictionary = {}
	for record_value in _array(resolved.get("records", [])):
		var record := _dict(record_value)
		interactions[identity_from(record)] = record
	state["interactions"] = interactions
	if not bool(resolved.get("ok", false)):
		state["interaction_resolution_errors"] = _array(resolved.get("errors", []))
	for collection_key in ["actors", "games", "interactions", "routes", "scene_objects", "services"]:
		state[collection_key] = _records_with_presence(_dict(state.get(collection_key, {})))
	return state


# Closed player-facing projection. Authorization catalogs, provenance digests,
# tombstones, and replay journals remain runtime-owned even though resolving the
# visible collections needs them internally.
static func public_semantic_state(state_value: Dictionary) -> Dictionary:
	var resolved := resolved_semantic_state(state_value)
	return {
		"actors": _public_collection_with_tombstones(resolved, "actors"),
		"games": _public_collection_with_tombstones(resolved, "games"),
		"interactions": _public_collection_with_tombstones(resolved, "interactions"),
		"routes": _public_collection_with_tombstones(resolved, "routes"),
		"scene_objects": _public_collection_with_tombstones(resolved, "scene_objects"),
		"services": _public_collection_with_tombstones(resolved, "services"),
	}


static func _records_with_presence(records: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for identity_value in records.keys():
		var identity_key := str(identity_value)
		var record := _dict(records.get(identity_value, {}))
		if record.is_empty():
			continue
		record["present"] = true
		result[identity_key] = record
	return result


static func _public_collection_with_tombstones(resolved: Dictionary, collection_key: String) -> Dictionary:
	var result := _dict(resolved.get(collection_key, {}))
	var tombstones := _dict(_dict(resolved.get("tombstones", {})).get(collection_key, {}))
	for identity_value in tombstones.keys():
		var identity_key := str(identity_value)
		var parsed := parse_owned_identity(identity_key)
		# Scenario-created identities have no immutable base presentation to
		# suppress. Their removal is represented by absence; only declared,
		# inventory-backed producer identities need a closed public tombstone.
		if parsed.is_empty() or str(parsed.get("owner_namespace", "")) == "scenario" or not _target_authorized(resolved, collection_key, identity_key):
			continue
		result[identity_key] = {
			"owner_namespace": str(parsed.get("owner_namespace", "")),
			"stable_object_id": str(parsed.get("stable_object_id", "")),
			"present": false,
		}
	return result


static func _boundary_kind(boundary_id: String) -> String:
	for kind in ["phase", "aftermath", "cleanup"]:
		if boundary_id.contains(":%s:" % kind): return kind
	return ""


static func _boundary_source_ref(boundary_id: String) -> String:
	var kind := _boundary_kind(boundary_id)
	if kind.is_empty(): return ""
	var marker := ":%s:" % kind
	return boundary_id.substr(boundary_id.find(marker) + marker.length())


static func _boundary_ordinal(records: Array, boundary_id: String) -> int:
	var ordinal := 0
	for record_value in records:
		if str(_dict(record_value).get("boundary_id", "")) == boundary_id: ordinal += 1
	return ordinal


static func _normalize_declared_targets(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	var source := _dict(value)
	for collection_key in ["scene_objects", "interactions", "actors", "services", "games", "routes", "anchors", "zones"]:
		result[collection_key] = _string_array(source.get(collection_key, []))
	return result


static func _normalized_operation_fingerprints(value: Variant, receipts_value: Variant) -> Dictionary:
	var result: Dictionary = {}
	var source := _dict(value)
	for receipt_value in _string_array(receipts_value):
		var receipt_id := str(receipt_value)
		var fingerprint := str(source.get(receipt_id, ""))
		if _valid_sha256(fingerprint): result[receipt_id] = fingerprint
	return result


static func _valid_sha256(value: String) -> bool:
	if value.length() != 64 or value != value.to_lower(): return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102): return false
	return true


static func _target_declared(state: Dictionary, collection_key: String, target_key: String) -> bool:
	var declared := _dict(state.get("declared_targets", {}))
	var inventory := _dict(state.get("target_inventory", {}))
	var tombstones := _dict(_dict(state.get("tombstones", {})).get(collection_key, {}))
	return not tombstones.has(target_key) and _string_array(declared.get(collection_key, [])).has(target_key) and _string_array(inventory.get(collection_key, [])).has(target_key)


static func _inventory_has(state: Dictionary, collection_key: String, target_key: String) -> bool:
	return _string_array(_dict(state.get("target_inventory", {})).get(collection_key, [])).has(target_key)


static func _target_authorized(state: Dictionary, collection_key: String, target_key: String) -> bool:
	return _string_array(_dict(state.get("declared_targets", {})).get(collection_key, [])).has(target_key) and _inventory_has(state, collection_key, target_key)


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
	_append_unknown_keys("interaction payload", payload, ["owner_namespace", "stable_object_id", "presentation_object_id", "source_kind", "source_field", "source_record_id", "label", "state_label", "prompt", "enabled", "disabled_reason", "available_actions", "input_actions", "non_color_state", "focus_order", "hit_bounds", "normalized_hit_rect", "min_target_size", "safe_exit", "alternate_exit", "mode", "target_owner_namespace", "target_stable_object_id", "source_id", "operation_receipt_key", "operation_boundary_id", "operation_fingerprint"], errors)
	for provenance_key in ["source_kind", "source_field", "source_record_id"]:
		if payload.has(provenance_key) and str(payload.get(provenance_key, "")).strip_edges().is_empty():
			errors.append("interaction producer provenance %s cannot be blank." % provenance_key)
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
	var actions_empty := _array(payload.get("available_actions", [])).is_empty()
	if (input_actions.is_empty() and not (actions_empty and not bool(payload.get("enabled", false)))) or input_actions.size() != _array(payload.get("input_actions", [])).size() or str(payload.get("non_color_state", "")).strip_edges().is_empty():
		errors.append("interaction requires input_actions and a non-color state.")
	for action_value in _array(payload.get("available_actions", [])):
		if typeof(action_value) == TYPE_DICTIONARY and not input_actions.has(str((action_value as Dictionary).get("input_action", ""))):
			errors.append("interaction action input_action must be declared in input_actions.")
	if not _finite_number(payload.get("focus_order")) or float(payload.get("focus_order", -1.0)) != floorf(float(payload.get("focus_order", -1.0))) or int(payload.get("focus_order", -1)) < 0:
		errors.append("interaction requires non-negative focus_order.")
	var hit_bounds := _dict(payload.get("hit_bounds", {}))
	_append_unknown_keys("interaction hit_bounds", hit_bounds, ["w", "h"], errors)
	if not _finite_number(hit_bounds.get("w")) or not _finite_number(hit_bounds.get("h")) or not _finite_number(payload.get("min_target_size")) or float(hit_bounds.get("w", 0.0)) < MIN_TARGET_SIZE or float(hit_bounds.get("h", 0.0)) < MIN_TARGET_SIZE or float(payload.get("min_target_size", 0.0)) < MIN_TARGET_SIZE:
		errors.append("interaction hit bounds/min_target_size are below the accessible minimum.")
	if payload.has("normalized_hit_rect"):
		var normalized_rect := _dict(payload.get("normalized_hit_rect", {}))
		_append_unknown_keys("interaction normalized_hit_rect", normalized_rect, ["x", "y", "w", "h"], errors)
		for rect_key in ["x", "y", "w", "h"]:
			if not _finite_number(normalized_rect.get(rect_key)): errors.append("interaction normalized_hit_rect must contain finite coordinates.")
	if not payload.has("safe_exit") or typeof(payload.get("safe_exit")) != TYPE_BOOL:
		errors.append("interaction must declare safe_exit semantics.")
	if not payload.has("alternate_exit") or typeof(payload.get("alternate_exit")) != TYPE_BOOL:
		errors.append("interaction must declare alternate_exit semantics.")
	elif typeof(payload.get("safe_exit")) == TYPE_BOOL and bool(payload.get("safe_exit", false)) and bool(payload.get("alternate_exit", false)):
		errors.append("interaction cannot be both a safe exit and an alternate exit objective.")


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
					"min_target_size": MIN_TARGET_SIZE, "safe_exit": false, "alternate_exit": false,
				}, errors)
		"actor_ops":
			if op_id == "set_position" and str(operation.get("anchor_id", "")).strip_edges().is_empty() and str(operation.get("zone_id", "")).strip_edges().is_empty():
				errors.append("actor set_position requires anchor_id or zone_id.")
			elif op_id == "set_route" and parse_owned_identity(str(operation.get("route_id", ""))).is_empty():
				errors.append("actor set_route requires an exact owned route identity.")
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
	if not OWNER_NAMESPACES.has(owner) or not _valid_semantic_object_id(stable_id):
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
		if not OWNER_NAMESPACES.has(target_owner) or not _valid_semantic_object_id(target_id):
			errors.append("interaction %s has invalid target identity." % identity(owner, stable_id))
			return
	if mode in ["add", "replace"]:
		_validate_interaction_payload(record, errors)
	elif mode == "gate":
		if not record.has("enabled") or typeof(record.get("enabled")) != TYPE_BOOL or not bool(record.get("enabled", false)) and str(record.get("disabled_reason", "")).strip_edges().is_empty():
			errors.append("interaction gate is missing enabled/disabled semantics.")
	elif mode == "augment":
		var augment_actions := _array(record.get("available_actions", []))
		if augment_actions.is_empty():
			errors.append("interaction augment requires actions.")
		else:
			var augment_inputs: Array = []
			for action_value in augment_actions:
				var input_action := str(_dict(action_value).get("input_action", "")).strip_edges()
				if not input_action.is_empty() and not augment_inputs.has(input_action): augment_inputs.append(input_action)
			_validate_interaction_payload({
				"label": "Augment", "state_label": "Available", "prompt": "Choose.", "enabled": true,
				"available_actions": augment_actions, "input_actions": augment_inputs,
				"non_color_state": "available", "focus_order": 0, "hit_bounds": {"w": MIN_TARGET_SIZE, "h": MIN_TARGET_SIZE},
				"min_target_size": MIN_TARGET_SIZE, "safe_exit": false, "alternate_exit": false,
			}, errors)
	elif mode == "retarget" and str(record.get("source_id", "")).strip_edges().is_empty():
		errors.append("interaction retarget requires source_id.")


static func _append_unknown_keys(label: String, value: Dictionary, allowed: Array, errors: Array) -> void:
	for key_value in value.keys():
		if not allowed.has(str(key_value)):
			errors.append("%s contains unknown key: %s." % [label, str(key_value)])


static func _value_matches_local_type(value: Variant, type_id: String, field: Dictionary) -> bool:
	var minimum: Variant = field.get("min")
	var maximum: Variant = field.get("max")
	match type_id:
		"bool": return typeof(value) == TYPE_BOOL
		"int":
			return typeof(value) == TYPE_INT and (not field.has("min") or int(value) >= int(minimum)) and (not field.has("max") or int(value) <= int(maximum))
		"float":
			return typeof(value) in [TYPE_INT, TYPE_FLOAT] and not is_nan(float(value)) and not is_inf(float(value)) and (not field.has("min") or float(value) >= float(minimum)) and (not field.has("max") or float(value) <= float(maximum))
		"string": return typeof(value) == TYPE_STRING and str(value).length() <= MAX_VARIANT_TEXT
		"enum": return typeof(value) == TYPE_STRING and _array(field.get("values", [])).has(str(value))
		"string_array":
			if typeof(value) != TYPE_ARRAY: return false
			var seen: Dictionary = {}
			for item in value as Array:
				if typeof(item) != TYPE_STRING or str(item).is_empty() or str(item) != str(item).strip_edges() or seen.has(str(item)): return false
				seen[str(item)] = true
			return true
		"int_array":
			if typeof(value) != TYPE_ARRAY: return false
			for item in value as Array:
				if typeof(item) != TYPE_INT: return false
			return true
	return false


static func _valid_semantic_object_id(value: String) -> bool:
	if value != value.strip_edges() or value.is_empty() or value.contains("::"): return false
	var parts := value.split(":", true)
	if parts.is_empty(): return false
	for part in parts:
		if not _canonical_id(str(part)): return false
	return true


static func _canonical_id(value: String) -> bool:
	if value != value.strip_edges() or value.is_empty() or value.length() > MAX_VARIANT_TEXT: return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and code != 95 and code != 45:
			return false
	return true


static func _payload_type_can_target_local(payload_type: String, local_type: String) -> bool:
	if payload_type == "dynamic": return true
	if local_type == "float": return payload_type in ["int", "float"]
	return payload_type == local_type


static func _sort_interaction_overlay(a: Variant, b: Variant) -> bool:
	var left := a as Dictionary if typeof(a) == TYPE_DICTIONARY else {}
	var right := b as Dictionary if typeof(b) == TYPE_DICTIONARY else {}
	var left_priority := int(OWNER_PRIORITY.get(str(left.get("owner_namespace", "")), -1))
	var right_priority := int(OWNER_PRIORITY.get(str(right.get("owner_namespace", "")), -1))
	if left_priority != right_priority:
		return left_priority > right_priority
	return identity_from(left) < identity_from(right)


static func _validate_and_track_target(family: String, operation: Dictionary, known_targets: Dictionary, errors: Array) -> void:
	if family == "transition_ops":
		return
	var owner := str(operation.get("owner_namespace", ""))
	var key := identity_from(operation)
	var op_id := str(operation.get("op", ""))
	# Base objects/interactions live in the prepared host snapshot rather than the
	# scenario-owned reducer. The host resolver validates those targets later.
	if owner != "scenario":
		return
	if family == "interaction_ops" and not ["add", "remove"].has(op_id):
		return
	var creates := (family == "scene_ops" and op_id == "spawn") \
		or (family == "interaction_ops" and op_id == "add") \
		or (family == "actor_ops" and op_id == "spawn") \
		or (family in ["service_ops", "game_ops"] and op_id == "add")
	var removes := op_id in ["remove", "despawn"]
	var requires_existing := family in ["scene_ops", "actor_ops"] and not creates and not removes \
		or family in ["service_ops", "game_ops"] and not creates and not removes
	if creates:
		if known_targets.has(key):
			errors.append("%s %s cannot create duplicate scenario target %s." % [family, op_id, key])
		else:
			known_targets[key] = true
	elif removes:
		# Cleanup/removal is deliberately conditional and idempotent: a branch may
		# never have created its temporary identity, but cleanup must still succeed.
		known_targets.erase(key)
	elif requires_existing and not known_targets.has(key):
		errors.append("%s %s targets missing scenario identity %s." % [family, op_id, key])


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
				if typeof(key_value) != TYPE_STRING:
					errors.append("%s contains a non-string dictionary key." % label)
					continue
				if str(key_value).length() > MAX_VARIANT_TEXT:
					errors.append("%s contains dictionary key exceeding %d characters." % [label, MAX_VARIANT_TEXT])
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
