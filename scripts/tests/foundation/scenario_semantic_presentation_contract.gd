class_name ScenarioSemanticPresentationContract
extends RefCounted

const EnvironmentInteractionControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")


static func check(_library: Variant, failures: Array) -> void:
	_check_ordinary_interaction_coexistence(failures)
	_check_public_removal_tombstones(failures)


static func _check_ordinary_interaction_coexistence(failures: Array) -> void:
	var untouched := _base_record("game:cards", "game", "Deal cards")
	var targeted := _base_record("travel:leave", "base", "Leave")
	var removed := _base_record("event:closed", "event", "Closed event")
	var projection := {
		"semantic_state": {
			"scene_objects": {},
			"interactions": {
				"base::travel:leave": {
					"owner_namespace": "base",
					"stable_object_id": "travel:leave",
					"present": true,
					"label": "Marked exit",
					"prompt": "Take the marked exit.",
					"state_label": "Open",
					"enabled": true,
					"available_actions": [{
						"id": "scenario_leave",
						"label": "Use marked exit",
						"action_origin_receipt_key": "phase:exit",
					}],
				},
				"event::event:closed": {
					"owner_namespace": "event",
					"stable_object_id": "event:closed",
					"present": false,
				},
			},
		},
	}
	var records := EnvironmentInteractionControllerScript.project_sequence_interactions(
		[untouched, targeted, removed],
		projection
	)
	var untouched_result := _record(records, "game:cards")
	var targeted_result := _record(records, "travel:leave")
	if untouched_result.is_empty() or str(untouched_result.get("confirm_action_id", "")) != "activate":
		failures.append("An active sequence removed or rewrote an unrelated ordinary interaction.")
	if not _array(untouched_result.get("scenario_sequence_actions", [])).is_empty():
		failures.append("An unrelated ordinary interaction gained scenario command authority.")
	if targeted_result.is_empty() or str(targeted_result.get("confirm_action_id", "")) != "scenario_leave" or _array(targeted_result.get("scenario_sequence_actions", [])).size() != 1:
		failures.append("A declared scenario target did not exclusively receive its authored scenario action.")
	if not _record(records, "event:closed").is_empty():
		failures.append("A declared public removal tombstone did not suppress its exact base interaction.")


static func _check_public_removal_tombstones(failures: Array) -> void:
	var identity := "base::door"
	var semantic := {
		"declared_targets": {"interactions": [identity]},
		"target_inventory": {"interactions": [identity]},
		"base_interactions": [{
			"owner_namespace": "base",
			"stable_object_id": "door",
			"enabled": true,
			"available_actions": [],
		}],
	}
	var removed := OperationRegistryScript.apply_operations(semantic, "interaction_ops", [{
		"family": "interaction_ops",
		"op": "remove",
		"receipt_id": "remove_door",
		"owner_namespace": "base",
		"stable_object_id": "door",
	}], "presentation:phase:remove")
	var public_state := OperationRegistryScript.public_semantic_state(_dict(removed.get("state", {})))
	var tombstone := _dict(_dict(public_state.get("interactions", {})).get(identity, {}))
	if not bool(removed.get("ok", false)) or tombstone != {
		"owner_namespace": "base",
		"stable_object_id": "door",
		"present": false,
	}:
		failures.append("A declared base removal did not expose the exact closed public presence tombstone.")
	if JSON.stringify(public_state).contains("receipt_id") or JSON.stringify(public_state).contains("tombstones"):
		failures.append("The public removal marker leaked operation receipt or tombstone journal internals.")


static func _base_record(object_id: String, owner: String, label: String) -> Dictionary:
	return {
		"object_id": object_id,
		"object_type": "travel" if object_id.begins_with("travel:") else "game" if object_id.begins_with("game:") else "event",
		"visual_type": "fixture",
		"source_id": object_id.get_slice(":", 1),
		"owner_namespace": owner,
		"stable_object_id": object_id,
		"label": label,
		"interactive": true,
		"enabled": true,
		"available_actions": [{"id": "activate", "label": "Activate"}],
		"confirm_action_id": "activate",
		"scenario_sequence_actions": [],
		"focus_rect": Rect2(0.2, 0.2, 0.12, 0.16),
	}


static func _record(records: Array, object_id: String) -> Dictionary:
	for value in records:
		var record := _dict(value)
		if str(record.get("object_id", "")) == object_id:
			return record
	return {}


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
