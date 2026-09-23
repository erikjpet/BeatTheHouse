class_name RoomActionList
extends VBoxContainer

signal action_selected(record: Dictionary, action: Dictionary)

const MIN_TARGET := Vector2(44.0, 44.0)
const SOURCE_INLINE := "inline_actions"
const SOURCE_SEQUENCE := "scenario_sequence_actions"
const SOURCE_AVAILABLE := "available_actions"

var _modal_focus_scope: RefCounted
var _launcher: Button
var _panel: PanelContainer
var _list: VBoxContainer
var _close: Button
var _records: Array = []
var _render_signature := ""
var _last_focus_key := ""


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
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
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
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
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
		if not is_visible_overflow_record(record):
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
	var scope_was_top := true
	if _modal_focus_scope != null and _modal_focus_scope.has_method("active_root"):
		scope_was_top = _modal_focus_scope.call("active_root") == _panel
	if _modal_focus_scope != null and _modal_focus_scope.has_method("pop_scope"):
		_modal_focus_scope.call("pop_scope", _panel)
	_panel.visible = false
	_last_focus_key = ""
	if (_modal_focus_scope == null or not _modal_focus_scope.has_method("pop_scope")) \
			and scope_was_top and is_instance_valid(_launcher) and _launcher.visible:
		_launcher.grab_focus()


static func is_visible_overflow_record(record: Dictionary) -> bool:
	return str(record.get("presentation_mode", "room")) == "overflow" \
		and bool(record.get("visible", true)) \
		and bool(record.get("presentation_required", true)) \
		and not str(record.get("object_id", "")).strip_edges().is_empty()


static func action_entries_for_record(record: Dictionary) -> Array:
	var entries: Array = []
	for candidate_source in [SOURCE_INLINE, SOURCE_SEQUENCE, SOURCE_AVAILABLE]:
		var source := str(candidate_source)
		var actions_value: Variant = record.get(source, [])
		if typeof(actions_value) != TYPE_ARRAY:
			continue
		var source_actions := actions_value as Array
		for index in range(source_actions.size()):
			if typeof(source_actions[index]) != TYPE_DICTIONARY:
				continue
			var action := source_actions[index] as Dictionary
			if not _action_is_visible(action):
				continue
			var entry := action.duplicate(true)
			entry["_overflow_source"] = source
			entry["_overflow_index"] = index
			entry["_overflow_action_key"] = _action_key(str(record.get("object_id", "")), source, index, entry)
			entries.append(entry)
	return entries


static func action_is_enabled(record: Dictionary, action: Dictionary) -> bool:
	var record_enabled := bool(record.get("enabled", true))
	var record_interactive := bool(record.get("interactive", record_enabled))
	return record_enabled and record_interactive and bool(action.get("enabled", true))


static func _action_is_visible(action: Dictionary) -> bool:
	if not bool(action.get("visible", true)) \
			or not bool(action.get("presentation_visible", true)) \
			or bool(action.get("hidden", false)) \
			or bool(action.get("hidden_only", false)):
		return false
	var action_id := str(action.get("emit_object_id", action.get("id", ""))).strip_edges()
	return not action_id.is_empty()


static func _action_key(object_id: String, source: String, index: int, action: Dictionary) -> String:
	var identity := str(action.get("emit_object_id", action.get("id", ""))).strip_edges()
	return "%s:%s:%d:%s" % [object_id, source, index, identity]


func _rebuild_rows() -> void:
	if _list == null:
		return
	var focus_key := _focused_action_key()
	if not focus_key.is_empty():
		_last_focus_key = focus_key
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var preferred: Control = null
	for record_value in _records:
		var record := record_value as Dictionary
		var actions := action_entries_for_record(record)
		if actions.is_empty():
			_add_unavailable_record_row(record)
			continue
		for action_value in actions:
			var action := action_value as Dictionary
			var button := _add_action_row(record, action)
			if str(action.get("_overflow_action_key", "")) == _last_focus_key and not button.disabled:
				preferred = button
	if _panel != null and _panel.visible:
		var controls := _focus_controls()
		if preferred == null:
			preferred = controls[0] as Control if not controls.is_empty() else _close
		if _modal_focus_scope != null and _modal_focus_scope.has_method("refresh_scope"):
			_modal_focus_scope.call("refresh_scope", _panel, preferred, controls)
		if preferred != null:
			preferred.grab_focus()


func _add_action_row(record: Dictionary, action: Dictionary) -> Button:
	var button := Button.new()
	var record_label := str(record.get("label", record.get("object_id", "Room action"))).strip_edges()
	var action_label := str(action.get("label", "")).strip_edges()
	if action_label.is_empty():
		action_label = str(action.get("id", action.get("emit_object_id", "Use"))).replace("_", " ").capitalize()
	var enabled := action_is_enabled(record, action)
	var reason := _disabled_reason(record, action) if not enabled else ""
	button.text = "%s: %s%s" % [record_label, action_label, " - %s" % reason if not reason.is_empty() else ""]
	var description := str(action.get("text", action.get("short_description", record.get("short_description", "")))).strip_edges()
	button.tooltip_text = reason if not reason.is_empty() else description
	button.custom_minimum_size = MIN_TARGET
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.disabled = not enabled
	var object_id := str(record.get("object_id", ""))
	var action_key := str(action.get("_overflow_action_key", ""))
	button.set_meta("object_id", object_id)
	button.set_meta("action_id", str(action.get("emit_object_id", action.get("id", ""))))
	button.set_meta("action_source", str(action.get("_overflow_source", "")))
	button.set_meta("action_key", action_key)
	button.focus_entered.connect(_remember_focus.bind(action_key))
	button.pressed.connect(_select_action.bind(object_id, action_key))
	_list.add_child(button)
	return button


func _add_unavailable_record_row(record: Dictionary) -> void:
	var button := Button.new()
	var label := str(record.get("label", record.get("object_id", "Room action"))).strip_edges()
	var reason := _disabled_reason(record, {})
	if bool(record.get("enabled", true)) and bool(record.get("interactive", true)):
		reason = "No actions are available."
	button.text = "%s - %s" % [label, reason]
	button.tooltip_text = reason
	button.custom_minimum_size = MIN_TARGET
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.disabled = true
	button.set_meta("object_id", str(record.get("object_id", "")))
	button.set_meta("action_id", "")
	button.set_meta("action_source", "")
	button.set_meta("action_key", "")
	_list.add_child(button)


func _focus_controls() -> Array:
	var controls: Array = []
	if _list != null:
		for child in _list.get_children():
			if child is Button and (child as Button).visible and not (child as Button).disabled:
				controls.append(child)
	if is_instance_valid(_close):
		controls.append(_close)
	return controls


func _select_action(object_id: String, action_key: String) -> void:
	for record_value in _records:
		var record := record_value as Dictionary
		if str(record.get("object_id", "")) != object_id:
			continue
		for action_value in action_entries_for_record(record):
			var action := action_value as Dictionary
			if str(action.get("_overflow_action_key", "")) != action_key:
				continue
			if not action_is_enabled(record, action):
				return
			action_selected.emit(record.duplicate(true), action.duplicate(true))
			close()
			return


func _remember_focus(action_key: String) -> void:
	_last_focus_key = action_key


func _focused_action_key() -> String:
	if _panel == null or not _panel.visible or get_viewport() == null:
		return ""
	var owner := get_viewport().gui_get_focus_owner()
	if owner == null or not _panel.is_ancestor_of(owner):
		return ""
	return str(owner.get_meta("action_key", ""))


func _disabled_reason(record: Dictionary, action: Dictionary) -> String:
	var reason := str(action.get("disabled_reason", record.get("disabled_reason", ""))).strip_edges()
	return reason if not reason.is_empty() else "Unavailable."


func _records_signature(records: Array) -> String:
	var rows: Array = []
	for record_value in records:
		var record := record_value as Dictionary
		rows.append({
			"object_id": str(record.get("object_id", "")),
			"label": str(record.get("label", "")),
			"enabled": bool(record.get("enabled", true)),
			"interactive": bool(record.get("interactive", true)),
			"disabled_reason": str(record.get("disabled_reason", "")),
			"short_description": str(record.get("short_description", "")),
			"focus_order": int(record.get("focus_order", 0)),
			"actions": action_entries_for_record(record),
		})
	return JSON.stringify(rows)


func _unhandled_input(event: InputEvent) -> void:
	if _panel != null and _panel.visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
