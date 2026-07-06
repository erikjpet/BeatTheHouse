class_name TalkDock
extends Control

signal choice_requested(event_id: String, choice_id: String)

const COLLAPSED_SIZE := Vector2(380, 48)
const EXPANDED_SIZE := Vector2(380, 220)
const VIEWPORT_MARGIN := Vector2(12, 14)
const MAX_CHOICES := 4

var entry: Dictionary = {}
var option: Dictionary = {}
var queue_count: int = 0
var expanded := false
var armed_choice_id := ""

var panel: PanelContainer
var stack: VBoxContainer
var collapsed_button: Button
var header_row: HBoxContainer
var portrait_panel: Panel
var speaker_label: Label
var summary_label: Label
var body_label: Label
var choice_scroll: ScrollContainer
var choice_list: VBoxContainer
var urgency_bar: ProgressBar
var badge_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	_position_panel()


func set_entry(next_entry: Dictionary, next_option: Dictionary, next_queue_count: int) -> void:
	entry = next_entry.duplicate(true)
	option = next_option.duplicate(true)
	queue_count = maxi(0, next_queue_count)
	if entry.is_empty() or option.is_empty():
		clear_entry()
		return
	var timing: Dictionary = entry.get("timing", {}) if typeof(entry.get("timing", {})) == TYPE_DICTIONARY else {}
	if bool(timing.get("expires", false)):
		expanded = true
	armed_choice_id = ""
	visible = true
	_render()


func clear_entry() -> void:
	entry = {}
	option = {}
	queue_count = 0
	expanded = false
	armed_choice_id = ""
	visible = false
	if choice_list != null:
		FoundationWidgets.clear(choice_list)


func handle_hotkey(event: InputEvent) -> bool:
	if not visible or not expanded:
		return false
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return false
	var index := -1
	match key_event.keycode:
		KEY_1:
			index = 0
		KEY_2:
			index = 1
		KEY_3:
			index = 2
		KEY_4:
			index = 3
		_:
			return false
	var choices := _choices()
	if index < 0 or index >= choices.size():
		return false
	var choice: Dictionary = choices[index]
	_choose(str(choice.get("id", "")), choice)
	return true


func current_snapshot() -> Dictionary:
	var timing: Dictionary = entry.get("timing", {}) if typeof(entry.get("timing", {})) == TYPE_DICTIONARY else {}
	return {
		"visible": visible,
		"expanded": expanded,
		"event_id": str(entry.get("event_id", "")),
		"speaker": _speaker_name(),
		"summary": str(option.get("summary", "")),
		"queue_count": queue_count,
		"choice_count": _choices().size(),
		"timing": timing.duplicate(true),
		"panel_rect": panel.get_global_rect() if panel != null else Rect2(),
		"screen_rect": get_global_rect(),
	}


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_position_panel()


func _build() -> void:
	panel = FoundationWidgets.panel_container(Color("#070810", 0.96), VisualStyle.CYAN_2)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(stack)

	collapsed_button = FoundationWidgets.button("", Callable(self, "_toggle_expanded"))
	collapsed_button.custom_minimum_size = Vector2(0, 34)
	stack.add_child(collapsed_button)

	header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(header_row)

	portrait_panel = FoundationWidgets.panel(VisualStyle.DARK_2, VisualStyle.PINK_2)
	portrait_panel.custom_minimum_size = Vector2(48, 54)
	header_row.add_child(portrait_panel)

	var header_text := VBoxContainer.new()
	header_text.add_theme_constant_override("separation", 2)
	header_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_text)

	speaker_label = FoundationWidgets.label("", 14)
	speaker_label.max_lines_visible = 1
	speaker_label.clip_text = true
	FoundationWidgets.set_control_font_color(speaker_label, VisualStyle.YELLOW)
	header_text.add_child(speaker_label)

	summary_label = FoundationWidgets.muted_label("", 11)
	summary_label.max_lines_visible = 2
	summary_label.clip_text = true
	header_text.add_child(summary_label)

	badge_label = FoundationWidgets.muted_label("", 11)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge_label.custom_minimum_size = Vector2(46, 0)
	header_row.add_child(badge_label)

	body_label = FoundationWidgets.label("", 12)
	body_label.max_lines_visible = 2
	body_label.clip_text = true
	stack.add_child(body_label)

	urgency_bar = ProgressBar.new()
	urgency_bar.min_value = 0.0
	urgency_bar.max_value = 1.0
	urgency_bar.value = 1.0
	urgency_bar.show_percentage = false
	urgency_bar.custom_minimum_size = Vector2(0, 8)
	stack.add_child(urgency_bar)

	choice_scroll = ScrollContainer.new()
	choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choice_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	choice_scroll.custom_minimum_size = Vector2(0, 68)
	choice_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(choice_scroll)

	choice_list = VBoxContainer.new()
	choice_list.add_theme_constant_override("separation", 4)
	choice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_scroll.add_child(choice_list)


func _render() -> void:
	if panel == null:
		return
	var speaker_name := _speaker_name()
	var summary := str(option.get("summary", "")).strip_edges()
	collapsed_button.text = "%s: %s%s" % [
		speaker_name if not speaker_name.is_empty() else "Someone",
		summary.left(42) if not summary.is_empty() else str(option.get("display_name", "Talk")),
		"  +%d" % maxi(0, queue_count - 1) if queue_count > 1 else "",
	]
	speaker_label.text = speaker_name if not speaker_name.is_empty() else str(option.get("display_name", "Talk"))
	summary_label.text = str(option.get("display_name", "Talk"))
	body_label.text = summary
	badge_label.text = "+%d" % maxi(0, queue_count - 1) if queue_count > 1 else ""
	var timing: Dictionary = entry.get("timing", {}) if typeof(entry.get("timing", {})) == TYPE_DICTIONARY else {}
	urgency_bar.visible = expanded and bool(timing.get("expires", false))
	if urgency_bar.visible:
		var duration := maxi(1, int(timing.get("duration_actions", 1)))
		urgency_bar.value = clampf(float(int(timing.get("remaining_actions", duration))) / float(duration), 0.0, 1.0)
	header_row.visible = expanded
	body_label.visible = expanded
	choice_scroll.visible = expanded
	_render_choices()
	panel.custom_minimum_size = EXPANDED_SIZE if expanded else COLLAPSED_SIZE
	panel.size = panel.custom_minimum_size
	_position_panel()


func _render_choices() -> void:
	FoundationWidgets.clear(choice_list)
	if not expanded:
		return
	for choice in _choices():
		if typeof(choice) != TYPE_DICTIONARY:
			continue
		var choice_data: Dictionary = choice
		var choice_id := str(choice_data.get("id", ""))
		if choice_id.is_empty():
			continue
		var label := str(choice_data.get("label", choice_id))
		if _choice_requires_confirm(choice_data) and armed_choice_id == choice_id:
			label = "Confirm: %s" % label
		var button := FoundationWidgets.button(label, Callable(self, "_on_choice_pressed").bind(choice_id))
		button.tooltip_text = str(choice_data.get("text", choice_data.get("consequence_summary", "")))
		choice_list.add_child(button)


func _choices() -> Array:
	var source: Variant = option.get("choices", [])
	if typeof(source) != TYPE_ARRAY:
		return []
	return (source as Array).slice(0, MAX_CHOICES)


func _toggle_expanded() -> void:
	expanded = not expanded
	armed_choice_id = ""
	_render()


func _on_choice_pressed(choice_id: String) -> void:
	var choice := _choice_by_id(choice_id)
	_choose(choice_id, choice)


func _choose(choice_id: String, choice: Dictionary) -> void:
	if choice_id.is_empty():
		return
	if _choice_requires_confirm(choice) and armed_choice_id != choice_id:
		armed_choice_id = choice_id
		_render_choices()
		return
	choice_requested.emit(str(entry.get("event_id", "")), choice_id)


func _choice_by_id(choice_id: String) -> Dictionary:
	for choice in _choices():
		if typeof(choice) == TYPE_DICTIONARY and str((choice as Dictionary).get("id", "")) == choice_id:
			return (choice as Dictionary).duplicate(true)
	return {}


func _choice_requires_confirm(choice: Dictionary) -> bool:
	if bool(choice.get("requires_confirm", false)):
		return true
	var summary := str(choice.get("consequence_summary", "")).to_lower()
	return summary.find("debt") >= 0 or summary.find("heat +") >= 0 or summary.find("barred") >= 0


func _speaker_name() -> String:
	var speaker: Dictionary = entry.get("speaker", {}) if typeof(entry.get("speaker", {})) == TYPE_DICTIONARY else {}
	var name := str(speaker.get("name", "")).strip_edges()
	if not name.is_empty():
		return name
	var role := str(speaker.get("role", "stranger")).strip_edges()
	return role.replace("_", " ").capitalize()


func _position_panel() -> void:
	if panel == null:
		return
	var panel_size := EXPANDED_SIZE if expanded else COLLAPSED_SIZE
	panel_size.x = minf(panel_size.x, maxf(280.0, size.x - VIEWPORT_MARGIN.x * 2.0))
	panel_size.y = minf(panel_size.y, maxf(44.0, size.y - VIEWPORT_MARGIN.y * 2.0))
	panel.size = panel_size
	panel.position = Vector2(VIEWPORT_MARGIN.x, maxf(VIEWPORT_MARGIN.y, size.y - panel_size.y - VIEWPORT_MARGIN.y))
