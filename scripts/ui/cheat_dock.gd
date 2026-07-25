class_name CheatDock
extends PanelContainer

signal action_selected(action_id: String, action_kind: String)

const UIArtScript := preload("res://scripts/ui/ui_art.gd")

var action_row: HBoxContainer
var risk_label: Label
var rendered_actions: Array[Dictionary] = []


func _ready() -> void:
	add_theme_stylebox_override("panel", VisualStyle.state_box("normal", "danger"))
	custom_minimum_size.y = VisualStyle.CHEAT_DOCK_HEIGHT
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_END
	_build()
	visible = false


func render(game_model: Dictionary) -> void:
	if action_row == null:
		return
	rendered_actions.clear()
	FoundationWidgets.clear(action_row)
	var actions: Array = _array(game_model.get("cheat_actions", []))
	visible = not actions.is_empty()
	risk_label.text = str(game_model.get("risk_cue", "Risk changes with heat and room attention."))
	for action_value in actions:
		if typeof(action_value) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_value
		var action_id := str(action.get("id", ""))
		if action_id.is_empty():
			continue
		var selected := bool(action.get("selected", false))
		var risk := int(action.get("suspicion_delta", 0))
		var label := "%s · %s" % [
			str(action.get("label", action_id.replace("_", " ").capitalize())),
			"Heat %+d" % risk if risk != 0 else "Heat risk",
		]
		var button := FoundationWidgets.variant_button(label, _select.bind(action_id), "danger")
		button.icon = UIArtScript.icon("cheat")
		button.expand_icon = true
		button.tooltip_text = str(action.get("summary", risk_label.text))
		FoundationWidgets.style_focusable(button, selected, selected)
		action_row.add_child(button)
		rendered_actions.append({
			"id": action_id,
			"selected": selected,
			"risk": risk,
			"available": true,
		})


func current_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"presentation": "dedicated_cheat_and_distraction_dock",
		"action_count": rendered_actions.size(),
		"actions": rendered_actions.duplicate(true),
		"risk_text": risk_label.text if risk_label != null else "",
		"rect": get_global_rect(),
		"selection_requires_confirmation": true,
	}


func _build() -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", VisualStyle.SPACE_2)
	add_child(stack)
	var heading := FoundationWidgets.icon_label_row(UIArtScript.icon("danger"), "Cheats & distractions", false)
	stack.add_child(heading)
	risk_label = FoundationWidgets.muted_label("", VisualStyle.TYPE_CAPTION)
	risk_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	risk_label.clip_text = true
	heading.add_child(risk_label)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", VisualStyle.SPACE_3)
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(action_row)


func _select(action_id: String) -> void:
	action_selected.emit(action_id, "cheat")


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
