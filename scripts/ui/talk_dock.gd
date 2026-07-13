class_name TalkDock
extends Control

signal choice_requested(event_id: String, choice_id: String)

const COLLAPSED_SIZE := Vector2(420, 58)
const EXPANDED_SIZE := Vector2(520, 292)
const VIEWPORT_MARGIN := Vector2(18, 18)
const MAX_CHOICES := 4
const IGNORE_PENALTY_HEAT := 5
const AttributeBadgeRowScript := preload("res://scripts/ui/attribute_badge_row.gd")


class PortraitModel:
	extends Control

	const PortraitTableGameVisualsScript := preload("res://scripts/games/table_game_visuals.gd")

	var speaker: Dictionary = {}
	var speaker_key := ""

	func set_speaker(next_speaker: Dictionary) -> void:
		var key := JSON.stringify(next_speaker)
		if key == speaker_key:
			return
		speaker_key = key
		speaker = next_speaker.duplicate(true)
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color("#070714"))
		draw_rect(rect.grow(-3), Color("#151323"))
		draw_line(Vector2(0.0, rect.size.y - 3.0), Vector2(rect.size.x, rect.size.y - 3.0), VisualStyle.PINK_2, 3.0)
		var hair := _speaker_color("hair_color", Color("#171022"))
		var jacket := _speaker_color("jacket_color", Color("#1d2030"))
		var style := {
			"name": "",
			"skin": Color("#c49371"),
			"hair": hair,
			"jacket": jacket,
			"accent": VisualStyle.CYAN_2,
			"role": str(speaker.get("role", "staff")),
			"pose": "speaking",
			"eye_offset": 0.08,
			"blink": false,
			"holding_card": false,
			"silhouette": str(speaker.get("silhouette", "coat")),
		}
		PortraitTableGameVisualsScript._draw_table_character(self, style, Vector2(size.x * 0.5, size.y + 18.0), 0.92, 0.0)

	func surface_label(_text: String, _pos: Vector2, _font_size: int, _color: Color) -> void:
		pass

	func _speaker_color(field: String, fallback: Color) -> Color:
		var text := str(speaker.get(field, "")).strip_edges()
		if text.is_empty():
			return fallback
		return Color(text)

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
var portrait_model: PortraitModel
var speaker_label: Label
var summary_label: Label
var body_label: Label
var choice_scroll: ScrollContainer
var choice_list: VBoxContainer
var urgency_bar: ProgressBar
var badge_label: Label
var urgency_label: Label


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
	expanded = true
	armed_choice_id = ""
	visible = true
	_render()
	_play_attention_animation()


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
		"ignore_penalty_heat": IGNORE_PENALTY_HEAT,
		"anchored_bottom_left": true,
		"timing": timing.duplicate(true),
		"panel_rect": panel.get_global_rect() if panel != null else Rect2(),
		"screen_rect": get_global_rect(),
	}


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_position_panel()


func _build() -> void:
	panel = FoundationWidgets.panel_container(Color("#090717", 0.98), VisualStyle.PINK_2)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(stack)

	collapsed_button = FoundationWidgets.button("", Callable(self, "_toggle_expanded"))
	collapsed_button.custom_minimum_size = Vector2(0, FoundationWidgets.MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	stack.add_child(collapsed_button)

	header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(header_row)

	portrait_panel = FoundationWidgets.panel(Color("#14111f"), VisualStyle.PINK_2)
	portrait_panel.custom_minimum_size = Vector2(98, 112)
	header_row.add_child(portrait_panel)
	portrait_model = PortraitModel.new()
	portrait_model.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_model.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_panel.add_child(portrait_model)

	var header_text := VBoxContainer.new()
	header_text.add_theme_constant_override("separation", 2)
	header_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_text)

	speaker_label = FoundationWidgets.label("", 20)
	speaker_label.max_lines_visible = 1
	speaker_label.clip_text = true
	FoundationWidgets.set_control_font_color(speaker_label, VisualStyle.YELLOW)
	header_text.add_child(speaker_label)

	summary_label = FoundationWidgets.muted_label("", 13)
	summary_label.max_lines_visible = 2
	summary_label.clip_text = true
	header_text.add_child(summary_label)

	urgency_label = FoundationWidgets.label("", 12)
	urgency_label.max_lines_visible = 2
	urgency_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	FoundationWidgets.set_control_font_color(urgency_label, VisualStyle.PINK_2)
	header_text.add_child(urgency_label)

	badge_label = FoundationWidgets.muted_label("", 12)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge_label.custom_minimum_size = Vector2(54, 0)
	header_row.add_child(badge_label)

	body_label = FoundationWidgets.label("", 14)
	body_label.max_lines_visible = 3
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	choice_scroll.custom_minimum_size = Vector2(0, 112)
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
	collapsed_button.text = "Talk now: %s - %s%s" % [
		speaker_name if not speaker_name.is_empty() else "Someone",
		summary.left(52) if not summary.is_empty() else str(option.get("display_name", "Talk")),
		"  +%d" % maxi(0, queue_count - 1) if queue_count > 1 else "",
	]
	speaker_label.text = speaker_name if not speaker_name.is_empty() else str(option.get("display_name", "Talk"))
	summary_label.text = str(option.get("display_name", "Talk"))
	body_label.text = summary
	var timing: Dictionary = entry.get("timing", {}) if typeof(entry.get("timing", {})) == TYPE_DICTIONARY else {}
	urgency_label.text = _urgency_text(timing)
	badge_label.text = "+%d" % maxi(0, queue_count - 1) if queue_count > 1 else ""
	if portrait_model != null:
		var speaker: Dictionary = entry.get("speaker", {}) if typeof(entry.get("speaker", {})) == TYPE_DICTIONARY else {}
		portrait_model.set_speaker(speaker)
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
		if _choice_is_ignore(choice_data):
			label = "%s (heat +%d)" % [label, IGNORE_PENALTY_HEAT]
		if _choice_requires_confirm(choice_data) and armed_choice_id == choice_id:
			label = "Confirm: %s" % label
		var button := FoundationWidgets.button(label, Callable(self, "_on_choice_pressed").bind(choice_id))
		var enabled := bool(choice_data.get("enabled", true))
		var disabled_reason := str(choice_data.get("disabled_reason", "")).strip_edges()
		button.disabled = not enabled
		button.tooltip_text = disabled_reason if not enabled and not disabled_reason.is_empty() else str(choice_data.get("text", choice_data.get("consequence_summary", "")))
		choice_list.add_child(button)
		var badges := _copy_array(choice_data.get("attribute_badges", []))
		if not badges.is_empty():
			AttributeBadgeRowScript.warm_cache(badges, 16)
			choice_list.add_child(AttributeBadgeRowScript.control_row(badges, 16))


func _choices() -> Array:
	var source: Variant = option.get("choices", [])
	if typeof(source) != TYPE_ARRAY:
		return []
	return (source as Array).slice(0, MAX_CHOICES)


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


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
	if not bool(choice.get("enabled", true)):
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


func _choice_is_ignore(choice: Dictionary) -> bool:
	var choice_id := str(choice.get("id", "")).strip_edges().to_lower()
	if choice_id.begins_with("ignore"):
		return true
	var label := str(choice.get("label", "")).strip_edges().to_lower()
	return label == "ignore" or label.begins_with("ignore ")


func _urgency_text(timing: Dictionary) -> String:
	if bool(timing.get("expires", false)):
		var remaining := maxi(0, int(timing.get("remaining_actions", timing.get("duration_actions", 0))))
		return "Answer before this passes. Ignoring adds heat +%d. Actions left: %d." % [IGNORE_PENALTY_HEAT, remaining]
	return "They are waiting on you. Ignoring adds heat +%d." % IGNORE_PENALTY_HEAT


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
	var available_size := Vector2(
		maxf(280.0, size.x - VIEWPORT_MARGIN.x * 2.0),
		maxf(44.0, size.y - VIEWPORT_MARGIN.y * 2.0)
	)
	var minimum_size := panel.get_combined_minimum_size()
	panel_size.x = minf(maxf(panel_size.x, minimum_size.x), available_size.x)
	panel_size.y = minf(maxf(panel_size.y, minimum_size.y), available_size.y)
	panel.size = panel_size
	panel.position = Vector2(VIEWPORT_MARGIN.x, maxf(VIEWPORT_MARGIN.y, size.y - panel_size.y - VIEWPORT_MARGIN.y))


func _play_attention_animation() -> void:
	if panel == null:
		return
	panel.modulate = Color(1.0, 1.0, 1.0, 0.88)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate", Color.WHITE, 0.12)
	if portrait_model != null:
		portrait_model.pivot_offset = portrait_model.size * 0.5
		portrait_model.scale = Vector2(1.04, 1.04)
		tween.parallel().tween_property(portrait_model, "scale", Vector2.ONE, 0.18)
