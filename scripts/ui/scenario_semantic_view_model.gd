class_name ScenarioSemanticViewModel
extends RefCounted

const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")
const BOARD_SIZE := Vector2(900.0, 430.0)


static func prepare_projection(base_records: Array, projection: Dictionary, environment: Dictionary = {}) -> Dictionary:
	return ScenarioLayoutResolverScript.resolve(base_records, projection, environment)


static func failure_authority(base_records: Array = []) -> Dictionary:
	return ScenarioLayoutResolverScript.failure_authority(base_records)


static func actor_character_model(actor: Dictionary) -> Dictionary:
	var behavior := str(actor.get("behavior", "idle"))
	var pose := str(actor.get("pose", "")).strip_edges()
	if pose.is_empty():
		pose = {
			"watch": "watching",
			"guard": "watching",
			"fight": "ready",
			"work": "working",
			"flee": "moving",
			"depart": "moving",
		}.get(behavior, "idle")
	return {
		"presentation": str(actor.get("presentation", "")),
		"role": behavior,
		"pose": pose,
		"behavior": behavior,
		"route_id": str(actor.get("route_id", "")),
		"route_points": _array(actor.get("route_points", [])),
		"route_stage": _dict(actor.get("route_stage", {})),
		"portrait_count": 1,
		"members": [{
			"role": behavior,
			"pose": pose,
			"model": _dict(actor.get("model", {})),
		}],
	}


static func compose(base_records: Array, prepared: Dictionary, selection: Dictionary) -> Dictionary:
	if prepared.is_empty():
		return {"ok": true, "records": base_records.duplicate(true), "errors": []}
	var errors := _array(prepared.get("errors", []))
	if not bool(prepared.get("ok", false)):
		var failed_records := base_records.duplicate(true)
		failed_records.append(_presentation_error_record(errors))
		return {"ok": false, "records": failed_records, "errors": errors}
	var boundary_serial := maxi(0, int(prepared.get("boundary_serial", 0)))
	var base_semantic: Array = []
	var presentations: Dictionary = {}
	var base_order: Array[String] = []
	for value in base_records:
		var presentation := _dict(value)
		if presentation.is_empty() or str(presentation.get("object_id", "")).is_empty():
			continue
		var semantic := _base_semantic_record(presentation)
		var identity := OperationRegistryScript.identity_from(semantic)
		base_semantic.append(semantic)
		base_order.append(identity)
		presentation["owner_namespace"] = str(semantic.get("owner_namespace", ""))
		presentation["stable_object_id"] = str(semantic.get("stable_object_id", ""))
		presentations[identity] = presentation

	var resolution := OperationRegistryScript.resolve_interactions(base_semantic, _array(prepared.get("interaction_overlays", [])))
	errors.append_array(_array(resolution.get("errors", [])))
	var visuals := _visual_lookup(_array(prepared.get("visual_objects", [])))
	var resolved_by_identity: Dictionary = {}
	for resolved_value in _array(resolution.get("records", [])):
		var resolved := _dict(resolved_value)
		resolved_by_identity[OperationRegistryScript.identity_from(resolved)] = resolved
	var augment_lookup := _augment_lookup(
		_array(prepared.get("interaction_overlays", [])),
		_array(resolution.get("accepted_overlay_source_identities", [])),
	)
	var result: Array = []
	for identity in base_order:
		if not resolved_by_identity.has(identity):
			continue
		var base_record := _apply_resolved_base(_dict(presentations.get(identity, {})), _dict(resolved_by_identity.get(identity, {})))
		if augment_lookup.has(identity):
			base_record = _append_augmented_actions(base_record, _array(augment_lookup.get(identity, [])), boundary_serial)
		result.append(base_record)
	var scenario_records: Array = []
	for value in _array(resolution.get("records", [])):
		var semantic := _dict(value)
		var identity := OperationRegistryScript.identity_from(semantic)
		if str(semantic.get("owner_namespace", "")) == "scenario":
			var record := _scenario_record(semantic, _dict(visuals.get(identity, {})), selection, boundary_serial)
			if not record.is_empty(): scenario_records.append(record)
	scenario_records.sort_custom(Callable(ScenarioSemanticViewModel, "_sort_records"))
	result.append_array(scenario_records)

	result = _apply_service_game_route_state(result, prepared)
	return {"ok": bool(resolution.get("ok", false)) and errors.is_empty(), "records": result, "errors": errors}


static func action_descriptor_for_token(records: Array, token: String) -> Dictionary:
	var wanted := token.strip_edges()
	if wanted.is_empty() or not wanted.begins_with("scenario_action:"):
		return {}
	for record_value in records:
		var record := _dict(record_value)
		if not bool(record.get("enabled", true)) or not bool(record.get("interactive", true)):
			continue
		for action_value in _array(record.get("inline_actions", [])):
			var action := _dict(action_value)
			if str(action.get("emit_object_id", "")) != wanted or not bool(action.get("enabled", true)):
				continue
			return {
				"owner_namespace": str(action.get("scenario_owner_namespace", record.get("scenario_owner_namespace", "scenario"))),
				"stable_object_id": str(action.get("scenario_stable_object_id", record.get("scenario_stable_object_id", ""))),
				"command_id": str(action.get("scenario_command_id", action.get("id", ""))),
				"idempotency_key": str(action.get("scenario_idempotency_key", "")),
				"action_origin_owner_namespace": str(action.get("action_origin_owner_namespace", "")),
				"action_origin_stable_object_id": str(action.get("action_origin_stable_object_id", "")),
				"action_origin_receipt_key": str(action.get("action_origin_receipt_key", "")),
				"action_origin_boundary_id": str(action.get("action_origin_boundary_id", "")),
				"action_origin_fingerprint": str(action.get("action_origin_fingerprint", "")),
			}
	return {}


static func _base_semantic_record(record: Dictionary) -> Dictionary:
	var owner := _owner_for_type(str(record.get("object_type", "")))
	var stable_id := str(record.get("object_id", "")).strip_edges().to_lower().replace(" ", "_")
	var enabled := bool(record.get("enabled", true))
	var rect := _dict(record.get("normalized_rect", record.get("focus_rect", {})))
	var hit_w := maxf(OperationRegistryScript.MIN_TARGET_SIZE, float(rect.get("w", 0.0)) * BOARD_SIZE.x)
	var hit_h := maxf(OperationRegistryScript.MIN_TARGET_SIZE, float(rect.get("h", 0.0)) * BOARD_SIZE.y)
	return {
		"owner_namespace": owner,
		"stable_object_id": stable_id,
		"mode": "add",
		"label": str(record.get("label", stable_id)),
		"state_label": "Available" if enabled else "Unavailable",
		"prompt": _fallback_text(str(record.get("action_summary", "")), "Choose an action."),
		"enabled": enabled,
		"disabled_reason": str(record.get("disabled_reason", "Unavailable.")) if not enabled else "",
		"available_actions": [{"id": "activate", "label": "Use", "input_action": "confirm", "non_color_state": "ready"}] if enabled else [],
		"input_actions": ["confirm"],
		"non_color_state": "available" if enabled else "unavailable",
		"focus_order": maxi(0, int(record.get("focus_order", 0))),
		"hit_bounds": {"w": hit_w, "h": hit_h},
		"min_target_size": OperationRegistryScript.MIN_TARGET_SIZE,
		"safe_exit": str(record.get("object_type", "")) == "travel",
		"alternate_exit": bool(record.get("alternate_exit", false)),
		"source_id": str(record.get("source_id", "")),
	}


static func _apply_resolved_base(record: Dictionary, semantic: Dictionary) -> Dictionary:
	var result := record.duplicate(true)
	result["enabled"] = bool(semantic.get("enabled", result.get("enabled", true)))
	result["disabled_reason"] = str(semantic.get("disabled_reason", "")) if not bool(result.get("enabled", true)) else ""
	result["action_summary"] = str(semantic.get("prompt", result.get("action_summary", "")))
	result["non_color_state"] = str(semantic.get("non_color_state", ""))
	result["scenario_augmented_actions"] = _array(semantic.get("available_actions", [])).slice(1)
	result["owner_namespace"] = str(semantic.get("owner_namespace", ""))
	result["stable_object_id"] = str(semantic.get("stable_object_id", ""))
	return result


static func _append_augmented_actions(record: Dictionary, augment_descriptors: Array, boundary_serial: int) -> Dictionary:
	var result := record.duplicate(true)
	var inline := _array(result.get("scenario_augmented_inline_actions", []))
	for descriptor_value in augment_descriptors:
		var descriptor := _dict(descriptor_value)
		for action_value in _array(descriptor.get("available_actions", [])):
			var action := _dict(action_value)
			var action_id := str(action.get("id", ""))
			var owner := str(descriptor.get("owner_namespace", "scenario"))
			var stable_id := str(descriptor.get("stable_object_id", ""))
			var idempotency_key := _action_idempotency_key(boundary_serial, owner, stable_id, action_id)
			inline.append({
				"id": action_id,
				"label": str(action.get("label", action_id.replace("_", " ").capitalize())),
				"enabled": bool(result.get("enabled", true)),
				"emit_object_id": _action_token(boundary_serial, owner, stable_id, action_id),
				"scenario_idempotency_key": idempotency_key,
				"scenario_owner_namespace": owner,
				"scenario_stable_object_id": stable_id,
				"scenario_command_id": action_id,
				"cost": maxi(0, int(action.get("cost", 0))),
			})
	result["scenario_augmented_inline_actions"] = inline
	var existing := _array(result.get("inline_actions", []))
	existing.append_array(inline)
	result["inline_actions"] = existing
	return result


static func _scenario_record(interaction: Dictionary, visual: Dictionary, selection: Dictionary, boundary_serial: int) -> Dictionary:
	if visual.is_empty(): return {}
	var owner := str(interaction.get("owner_namespace", ""))
	var stable_id := str(interaction.get("stable_object_id", ""))
	var object_id := "scenario:%s:%s" % [owner, stable_id]
	var actions := _array(interaction.get("available_actions", []))
	var inline_actions: Array = []
	for value in actions:
		var action := _dict(value)
		var action_id := str(action.get("id", ""))
		var token := _action_token(boundary_serial, owner, stable_id, action_id)
		inline_actions.append({
			"id": action_id,
			"label": str(action.get("label", action_id.replace("_", " ").capitalize())),
			"enabled": bool(interaction.get("enabled", true)),
			"emit_object_id": token,
			"scenario_idempotency_key": _action_idempotency_key(boundary_serial, owner, stable_id, action_id),
			"scenario_owner_namespace": owner,
			"scenario_stable_object_id": stable_id,
			"scenario_command_id": action_id,
			"action_origin_owner_namespace": str(action.get("action_origin_owner_namespace", owner)),
			"action_origin_stable_object_id": str(action.get("action_origin_stable_object_id", stable_id)),
			"action_origin_receipt_key": str(action.get("action_origin_receipt_key", "")),
			"action_origin_boundary_id": str(action.get("action_origin_boundary_id", "")),
			"action_origin_fingerprint": str(action.get("action_origin_fingerprint", "")),
			"cost": maxi(0, int(action.get("cost", 0))),
			"input_action": str(action.get("input_action", "confirm")),
			"non_color_state": str(action.get("non_color_state", "ready")),
		})
	var enabled := bool(interaction.get("enabled", true))
	var cost := maxi(0, int(_dict(actions[0] if not actions.is_empty() else {}).get("cost", 0)))
	return {
		"object_id": object_id,
		"object_type": "scenario",
		"visual_type": str(visual.get("visual_type", "scenario_object")),
		"source_id": str(interaction.get("source_id", stable_id)),
		"label": str(interaction.get("label", visual.get("label", stable_id))),
		"short_description": str(interaction.get("prompt", visual.get("short_description", ""))),
		"identity_summary": str(interaction.get("state_label", "")),
		"presence": "scenario",
		"interactive": true,
		"decorative": false,
		"enabled": enabled,
		"disabled_reason": str(interaction.get("disabled_reason", "")) if not enabled else "",
		"normalized_rect": _interaction_rect(visual, interaction),
		"focus_rect": _interaction_rect(visual, interaction),
		"action_summary": str(interaction.get("prompt", "Choose an action.")),
		"status_summary": str(interaction.get("state_label", "")),
		"state_badge": str(interaction.get("non_color_state", "")),
		"non_color_state": str(interaction.get("non_color_state", "")),
		"cost_summary": "$%d" % cost if cost > 0 else "",
		"price": cost,
		"currency": "cash",
		"available_actions": actions,
		"inline_actions": inline_actions,
		"confirm_action_id": str(_dict(actions[0] if not actions.is_empty() else {}).get("id", "")),
		"owner_namespace": owner,
		"stable_object_id": stable_id,
		"scenario_owner_namespace": owner,
		"scenario_stable_object_id": stable_id,
		"scenario_command_id": str(_dict(actions[0] if not actions.is_empty() else {}).get("id", "")),
		"scenario_idempotency_key": _action_idempotency_key(boundary_serial, owner, stable_id, str(_dict(actions[0] if not actions.is_empty() else {}).get("id", ""))),
		"action_origin_owner_namespace": str(_dict(actions[0] if not actions.is_empty() else {}).get("action_origin_owner_namespace", owner)),
		"action_origin_stable_object_id": str(_dict(actions[0] if not actions.is_empty() else {}).get("action_origin_stable_object_id", stable_id)),
		"action_origin_receipt_key": str(_dict(actions[0] if not actions.is_empty() else {}).get("action_origin_receipt_key", "")),
		"action_origin_boundary_id": str(_dict(actions[0] if not actions.is_empty() else {}).get("action_origin_boundary_id", "")),
		"action_origin_fingerprint": str(_dict(actions[0] if not actions.is_empty() else {}).get("action_origin_fingerprint", "")),
		"safe_exit": bool(interaction.get("safe_exit", false)),
		"focus_order": maxi(0, int(interaction.get("focus_order", 0))),
		"role": str(visual.get("role", "")),
		"state": str(visual.get("state", "")),
		"appearance": str(visual.get("appearance", "")),
		"pose": str(visual.get("pose", "")),
		"behavior": str(visual.get("behavior", "")),
		"route_id": str(visual.get("route_id", "")),
		"route_points": _array(visual.get("route_points", [])),
		"small_screen_rect": _dict(visual.get("small_screen_rect", {})),
		"z_order": int(visual.get("z_order", 0)),
		"hovered": object_id == str(selection.get("hover_target_id", "")),
		"focused": object_id == str(selection.get("focus_target_id", "")),
		"selected": object_id == str(selection.get("selected_object_id", "")),
	}


static func _action_idempotency_key(boundary_serial: int, owner: String, stable_id: String, action_id: String) -> String:
	return "ui:%d:%s:%s:%s" % [maxi(0, boundary_serial), _token_component(owner), _token_component(stable_id), _token_component(action_id)]


static func _action_token(boundary_serial: int, owner: String, stable_id: String, action_id: String) -> String:
	return "scenario_action:%d:%s:%s:%s" % [maxi(0, boundary_serial), _token_component(owner), _token_component(stable_id), _token_component(action_id)]


static func _token_component(value: String) -> String:
	return value.replace("%", "%25").replace(":", "%3A")


static func _presentation_error_record(errors: Array) -> Dictionary:
	var detail := str(errors[0]) if not errors.is_empty() else "The authored room presentation is unavailable."
	return {
		"object_id": "scenario:presentation_error",
		"object_type": "scenario",
		"visual_type": "scenario_object",
		"source_id": "presentation_error",
		"label": "Room sequence unavailable",
		"short_description": detail,
		"identity_summary": "Authoring error",
		"presence": "scenario_error",
		"interactive": false,
		"decorative": false,
		"enabled": false,
		"disabled_reason": detail,
		"normalized_rect": {"x": 0.39, "y": 0.72, "w": 0.22, "h": 0.14},
		"focus_rect": {"x": 0.39, "y": 0.72, "w": 0.22, "h": 0.14},
		"action_summary": detail,
		"status_summary": "Unavailable",
		"state_badge": "error",
		"non_color_state": "error",
		"inline_actions": [],
		"available_actions": [],
		"owner_namespace": "scenario",
		"stable_object_id": "presentation_error",
		"focus_order": 99999,
	}


static func _apply_service_game_route_state(records: Array, prepared: Dictionary) -> Array:
	var result := records.duplicate(true)
	for family_value in [
		{"records": _array(prepared.get("services", [])), "types": ["service", "lender"]},
		{"records": _array(prepared.get("games", [])), "types": ["game"]},
		{"records": _array(prepared.get("routes", [])), "types": ["travel"]},
	]:
		var family := _dict(family_value)
		for semantic_value in _array(family.get("records", [])):
			var semantic := _dict(semantic_value)
			var target := str(semantic.get("id", semantic.get("source_id", semantic.get("stable_object_id", ""))))
			for index in range(result.size()):
				var record := _dict(result[index])
				if not _array(family.get("types", [])).has(str(record.get("object_type", ""))): continue
				if str(record.get("source_id", "")) != target and not str(record.get("object_id", "")).ends_with(":" + target): continue
				record["enabled"] = bool(semantic.get("enabled", record.get("enabled", true)))
				record["disabled_reason"] = str(semantic.get("disabled_reason", "")) if not bool(record.get("enabled", true)) else ""
				if str(record.get("object_type", "")) == "travel" and not str(semantic.get("source_id", "")).is_empty():
					record["source_id"] = str(semantic.get("source_id", ""))
				result[index] = record
	return result


static func _interaction_rect(visual: Dictionary, interaction: Dictionary) -> Dictionary:
	var rect := _dict(visual.get("normalized_rect", {}))
	var center := Vector2(float(rect.get("x", 0.0)) + float(rect.get("w", 0.0)) * 0.5, float(rect.get("y", 0.0)) + float(rect.get("h", 0.0)) * 0.5)
	var bounds := _dict(interaction.get("hit_bounds", {}))
	var size := Vector2(maxf(float(rect.get("w", 0.0)), float(bounds.get("w", 44.0)) / BOARD_SIZE.x), maxf(float(rect.get("h", 0.0)), float(bounds.get("h", 44.0)) / BOARD_SIZE.y))
	var position := Vector2(clampf(center.x - size.x * 0.5, 0.0, 1.0 - size.x), clampf(center.y - size.y * 0.5, 0.0, 1.0 - size.y))
	return {"x": position.x, "y": position.y, "w": size.x, "h": size.y}


static func _visual_lookup(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		var visual := _dict(value)
		result[str(visual.get("semantic_identity", ""))] = visual
	return result


static func _augment_lookup(values: Array, accepted_source_identities: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		var overlay := _dict(value)
		if str(overlay.get("mode", "add")) != "augment": continue
		if not accepted_source_identities.has(OperationRegistryScript.identity_from(overlay)): continue
		var target := OperationRegistryScript.identity(str(overlay.get("target_owner_namespace", "")), str(overlay.get("target_stable_object_id", "")))
		var entries := _array(result.get(target, []))
		entries.append(overlay)
		result[target] = entries
	return result


static func _fallback_text(value: String, fallback: String) -> String:
	return fallback if value.strip_edges().is_empty() else value


static func _owner_for_type(object_type: String) -> String:
	match object_type:
		"game": return "game"
		"event": return "event"
		"service", "lender", "shopkeeper": return "service"
		"dialogue", "crew": return "crew"
		"traveler", "delivery": return "traveler"
	return "base"


static func _sort_records(a: Dictionary, b: Dictionary) -> bool:
	var af := int(a.get("focus_order", 100000))
	var bf := int(b.get("focus_order", 100000))
	return str(a.get("object_id", "")) < str(b.get("object_id", "")) if af == bf else af < bf


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
