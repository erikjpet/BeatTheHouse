class_name ScenarioSemanticViewModel
extends RefCounted

# Converts sealed scenario semantic records into player-safe actors, objects,
# actions, and failure projections for room presentation.



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
			# Physical sequence records retain their existing deferred command path.
			# Do not run them through the legacy scenario action's extra room turn.
			for sequence_value in _array(record.get("scenario_sequence_actions", [])):
				var sequence_action := _dict(sequence_value)
				if str(sequence_action.get("id", "")) == str(action.get("id", "")):
					return {"sequence_record": record, "sequence_action": sequence_action}
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


static func inline_actions_for_interaction(interaction: Dictionary, boundary_serial: int) -> Array:
	var owner := str(interaction.get("owner_namespace", ""))
	var stable_id := str(interaction.get("stable_object_id", ""))
	var actions := _array(interaction.get("available_actions", []))
	var inline_actions: Array = []
	for value in actions:
		var action := _dict(value)
		if not bool(action.get("visible", true)) or not bool(action.get("presentation_visible", true)) \
				or bool(action.get("hidden", false)) or bool(action.get("hidden_only", false)):
			continue
		var action_id := str(action.get("id", ""))
		var token := _cycle_scoped_action_token(boundary_serial, owner, stable_id, action_id, action)
		inline_actions.append({
			"id": action_id,
			"label": str(action.get("label", action_id.replace("_", " ").capitalize())),
			"enabled": bool(interaction.get("enabled", true)) and bool(action.get("enabled", true)) and not bool(action.get("disabled", false)),
			"emit_object_id": token,
			"scenario_idempotency_key": _action_idempotency_key(boundary_serial, owner, stable_id, action_id) + _venue_cycle_action_scope(action),
			"scenario_owner_namespace": str(action.get("attached_owner_namespace", owner)),
			"scenario_stable_object_id": str(action.get("attached_stable_object_id", stable_id)),
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
	return inline_actions


static func _action_idempotency_key(boundary_serial: int, owner: String, stable_id: String, action_id: String) -> String:
	return "ui:%d:%s:%s:%s" % [maxi(0, boundary_serial), _token_component(owner), _token_component(stable_id), _token_component(action_id)]


static func _cycle_scoped_action_token(boundary_serial: int, owner: String, stable_id: String, action_id: String, action: Dictionary) -> String:
	return _action_token(boundary_serial, owner, stable_id, action_id) + _venue_cycle_action_scope(action)


static func _venue_cycle_action_scope(action: Dictionary) -> String:
	var origin := str(action.get("action_origin_boundary_id", ""))
	# Older journals retain their established tokens. New venue instances use an
	# authenticated operation scope so an old prepared click cannot bind to an
	# identical command at boundary0 of a later instance of the same scenario.
	return ":cycle:%s" % origin.sha256_text().substr(0, 20) if origin.contains(":cycle:") else ""


static func _action_token(boundary_serial: int, owner: String, stable_id: String, action_id: String) -> String:
	return "scenario_action:%d:%s:%s:%s" % [maxi(0, boundary_serial), _token_component(owner), _token_component(stable_id), _token_component(action_id)]


static func _token_component(value: String) -> String:
	return value.replace("%", "%25").replace(":", "%3A")


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
