class_name RoomActionList
extends VBoxContainer

signal record_selected(record: Dictionary)

const MIN_TARGET := Vector2(44.0, 44.0)

var _modal_focus_scope: RefCounted
var _launcher: Button
var _panel: PanelContainer
var _list: VBoxContainer
var _close: Button
var _records: Array = []
var _render_signature := ""


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_launcher = Button.new()
	_launcher.text = "More room actions"
	_launcher.tooltip_text = "Open actions that do not have a free authored room slot."
	_launcher.custom_minimum_size = MIN_TARGET
	_launcher.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_launcher.focus_mode = Control.FOCUS_ALL
	_launcher.pressed.connect(open)
	add_child(_launcher)

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.focus_mode = Control.FOCUS_NONE
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)
	var heading := Label.new()
	heading.text = "Room actions"
	heading.tooltip_text = "These objects remain available here without being drawn on the room canvas."
	stack.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 132.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_close = Button.new()
	_close.text = "Close"
	_close.custom_minimum_size = MIN_TARGET
	_close.focus_mode = Control.FOCUS_ALL
	_close.pressed.connect(close)
	stack.add_child(_close)
	set_process_unhandled_input(true)
	render([])


func configure(modal_focus_scope: RefCounted) -> void:
	_modal_focus_scope = modal_focus_scope


func render(records: Array) -> void:
	var filtered: Array = []
	for value in records:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var record := (value as Dictionary).duplicate(true)
		if str(record.get("presentation_mode", "room")) != "overflow" \
				or not bool(record.get("visible", true)) \
				or not bool(record.get("presentation_required", true)):
			continue
		var object_id := str(record.get("object_id", "")).strip_edges()
		if object_id.is_empty():
			continue
		filtered.append(record)
	filtered.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left := left_value as Dictionary
		var right := right_value as Dictionary
		var left_order := int(left.get("focus_order", 0))
		var right_order := int(right.get("focus_order", 0))
		return str(left.get("object_id", "")) < str(right.get("object_id", "")) if left_order == right_order else left_order < right_order
	)
	_records = filtered
	var next_signature := _records_signature(_records)
	if next_signature != _render_signature:
		_render_signature = next_signature
		_rebuild_rows()
	visible = not _records.is_empty()
	_launcher.visible = visible
	_launcher.text = "More room actions (%d)" % _records.size()
	if _records.is_empty():
		close()


func open() -> void:
	if _records.is_empty() or _panel.visible:
		return
	_panel.visible = true
	var controls := _focus_controls()
	var first := controls[0] as Control if not controls.is_empty() else _close
	if _modal_focus_scope != null and _modal_focus_scope.has_method("push_scope"):
		_modal_focus_scope.call("push_scope", _panel, first, _launcher, controls)
	elif first != null:
		first.grab_focus()


func close() -> void:
	if _panel == null or not _panel.visible:
		return
	if _modal_focus_scope != null and _modal_focus_scope.has_method("pop_scope"):
		_modal_focus_scope.call("pop_scope", _panel)
	_panel.visible = false
	if is_instance_valid(_launcher) and _launcher.visible:
		_launcher.grab_focus()


func _rebuild_rows() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for record_value in _records:
		var record := record_value as Dictionary
		var button := Button.new()
		var label := str(record.get("label", record.get("object_id", "Room action"))).strip_edges()
		button.text = "%s%s" % [label, " — unavailable" if not bool(record.get("enabled", true)) else ""]
		var tooltip := str(record.get("disabled_reason", "")).strip_edges()
		button.tooltip_text = str(record.get("short_description", "")) if tooltip.is_empty() else tooltip
		button.custom_minimum_size = MIN_TARGET
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.set_meta("object_id", str(record.get("object_id", "")))
		button.pressed.connect(_select_record.bind(str(record.get("object_id", ""))))
		_list.add_child(button)
	if _panel != null and _panel.visible and _modal_focus_scope != null and _modal_focus_scope.has_method("refresh_scope"):
		var controls := _focus_controls()
		_modal_focus_scope.call("refresh_scope", _panel, controls[0] if not controls.is_empty() else _close, controls)


func _focus_controls() -> Array:
	var controls: Array = []
	if _list != null:
		for child in _list.get_children():
			if child is Button and (child as Button).visible:
				controls.append(child)
	if is_instance_valid(_close):
		controls.append(_close)
	return controls


func _select_record(object_id: String) -> void:
	for record_value in _records:
		var record := record_value as Dictionary
		if str(record.get("object_id", "")) != object_id:
			continue
		close()
		record_selected.emit(record.duplicate(true))
		return


func _records_signature(records: Array) -> String:
	var rows: Array = []
	for record_value in records:
		var record := record_value as Dictionary
		rows.append({
			"object_id": str(record.get("object_id", "")),
			"label": str(record.get("label", "")),
			"enabled": bool(record.get("enabled", true)),
			"disabled_reason": str(record.get("disabled_reason", "")),
			"short_description": str(record.get("short_description", "")),
			"focus_order": int(record.get("focus_order", 0)),
		})
	return JSON.stringify(rows)


func _unhandled_input(event: InputEvent) -> void:
	if _panel != null and _panel.visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
