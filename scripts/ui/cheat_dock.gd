class_name CheatDock
extends Control

# Compatibility adapter for legacy snapshot consumers. Risky actions are now
# drawn and activated by each GameModule's physical surface controls.
signal action_selected(action_id: String, action_kind: String)

var rendered_actions: Array[Dictionary] = []
var risk_text := ""


func _ready() -> void:
	custom_minimum_size = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func render(game_model: Dictionary) -> void:
	rendered_actions.clear()
	risk_text = str(game_model.get("risk_cue", "Risk changes with heat and room attention."))
	for action_value in _array(game_model.get("cheat_actions", [])):
		if typeof(action_value) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_value
		var action_id := str(action.get("id", ""))
		if action_id.is_empty():
			continue
		rendered_actions.append({
			"id": action_id,
			"selected": bool(action.get("selected", false)),
			"risk": int(action.get("suspicion_delta", 0)),
			"available": true,
		})
	visible = false


func current_snapshot() -> Dictionary:
	return {
		"visible": false,
		"presentation": "integrated_game_surface_actions",
		"action_count": rendered_actions.size(),
		"actions": rendered_actions.duplicate(true),
		"risk_text": risk_text,
		"rect": get_global_rect(),
		"selection_requires_confirmation": true,
		"actions_on_game_surface": true,
		"resizes_environment": false,
	}


func _select(action_id: String) -> void:
	action_selected.emit(action_id, "cheat")


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
