class_name TalkDock
extends Control

signal choice_requested(event_id: String, choice_id: String)

const COLLAPSED_SIZE := Vector2(420, 58)
const EXPANDED_PANEL_SIZE := Vector2(540, 168)
const EXPANDED_PORTRAIT_SIZE := Vector2(280, 390)
const VIEWPORT_MARGIN := Vector2(18, 18)
const MAX_CHOICES := 4
const IGNORE_PENALTY_HEAT := 5


class PortraitModel:
	extends Control

	const PortraitTableGameVisualsScript := preload("res://scripts/games/table_game_visuals.gd")
	const ANIMATION_REDRAW_INTERVAL := 1.0 / 12.0

	var speaker: Dictionary = {}
	var speaker_key := ""
	var animation_clock := 0.0
	var animation_redraw_elapsed := 0.0
	var animation_redraw_count := 0
	var animation_active := false
	var reduce_motion := false

	func _ready() -> void:
		set_process(false)

	func set_speaker(next_speaker: Dictionary) -> void:
		var key := JSON.stringify(next_speaker)
		if key == speaker_key:
			return
		speaker_key = key
		speaker = next_speaker.duplicate(true)
		queue_redraw()

	func set_animation_active(active: bool) -> void:
		animation_active = active and not reduce_motion
		set_process(animation_active)
		if animation_active:
			queue_redraw()

	func set_reduce_motion(enabled: bool) -> void:
		reduce_motion = enabled
		set_animation_active(animation_active and not reduce_motion)
		queue_redraw()

	func _process(delta: float) -> void:
		if not animation_active:
			return
		animation_clock = fposmod(animation_clock + delta, 120.0)
		animation_redraw_elapsed += delta
		if animation_redraw_elapsed < ANIMATION_REDRAW_INTERVAL:
			return
		animation_redraw_elapsed = fposmod(animation_redraw_elapsed, ANIMATION_REDRAW_INTERVAL)
		animation_redraw_count += 1
		queue_redraw()

	func _draw() -> void:
		var hair := _speaker_color("hair_color", Color("#171022"))
		var jacket := _speaker_color("jacket_color", Color("#1d2030"))
		var cycle := fposmod(animation_clock, 4.2) / 4.2
		var speaking_gesture := fposmod(animation_clock, 2.8) > 1.9
		var style := {
			"name": "",
			"skin": Color("#c49371"),
			"hair": hair,
			"jacket": jacket,
			"accent": VisualStyle.CYAN_2,
			"role": str(speaker.get("role", "staff")),
			"pose": "watching" if speaking_gesture else "speaking",
			"eye_offset": sin(animation_clock * 0.72) * 0.55,
			"blink": cycle > 0.92 and cycle < 0.975,
			"holding_card": false,
			"silhouette": str(speaker.get("silhouette", "coat")),
		}
		var character_scale := clampf(minf(size.x / 98.0, size.y / 150.0) * 0.92, 0.92, 2.6)
		var speech_bob := sin(animation_clock * 3.1) * 1.15 * character_scale
		PortraitTableGameVisualsScript._draw_table_character(self, style, Vector2(size.x * 0.5, size.y + 18.0 + speech_bob), character_scale, animation_clock)

	func surface_label(_text: String, _pos: Vector2, _font_size: int, _color: Color) -> void:
		pass

	func _speaker_color(field: String, fallback: Color) -> Color:
		var text := str(speaker.get(field, "")).strip_edges()
		if text.is_empty():
			return fallback
		return Color(text)


class ResponseIcon:
	extends Control

	const ICON_SIZE := Vector2(26, 26)

	var kind := "talk"

	func _init(icon_kind: String = "talk") -> void:
		kind = icon_kind
		custom_minimum_size = ICON_SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center := size * 0.5
		var color := _icon_color()
		draw_circle(center, 11.0, Color(color, 0.15))
		draw_arc(center, 10.0, 0.0, TAU, 20, color, 1.5, true)
		match kind:
			"leave":
				draw_line(center + Vector2(-5, 0), center + Vector2(5, 0), color, 2.0)
				draw_line(center + Vector2(2, -4), center + Vector2(6, 0), color, 2.0)
				draw_line(center + Vector2(2, 4), center + Vector2(6, 0), color, 2.0)
			"route":
				draw_line(center + Vector2(-6, 5), center + Vector2(-2, -4), color, 2.0)
				draw_line(center + Vector2(-2, -4), center + Vector2(5, 3), color, 2.0)
				draw_circle(center + Vector2(-6, 5), 2.0, color)
				draw_circle(center + Vector2(5, 3), 2.0, color)
			"cash_gain", "cash_cost":
				draw_line(center + Vector2(-4, -5), center + Vector2(3, -5), color, 1.5)
				draw_line(center + Vector2(-4, -5), center + Vector2(-4, 0), color, 1.5)
				draw_line(center + Vector2(-4, 0), center + Vector2(3, 0), color, 1.5)
				draw_line(center + Vector2(3, 0), center + Vector2(3, 5), color, 1.5)
				draw_line(center + Vector2(3, 5), center + Vector2(-4, 5), color, 1.5)
				draw_line(center + Vector2(-1, -7), center + Vector2(-1, 7), color, 1.0)
				draw_line(center + Vector2(4, -5), center + Vector2(4, 4), color, 1.5)
				draw_line(center + Vector2(1, -2 if kind == "cash_gain" else 4), center + Vector2(7, -2 if kind == "cash_gain" else 4), color, 1.5)
			"heat_up", "heat_down":
				var direction := -1.0 if kind == "heat_up" else 1.0
				draw_line(center + Vector2(0, 6 * direction), center + Vector2(0, -5 * direction), color, 2.0)
				draw_line(center + Vector2(-4, -1 * direction), center + Vector2(0, -5 * direction), color, 2.0)
				draw_line(center + Vector2(4, -1 * direction), center + Vector2(0, -5 * direction), color, 2.0)
			"uncertain":
				draw_arc(center + Vector2(0, -2), 5.0, PI, TAU, 10, color, 1.8, true)
				draw_line(center + Vector2(5, -2), center + Vector2(0, 3), color, 1.8)
				draw_line(center + Vector2(0, 3), center + Vector2(0, 5), color, 1.8)
				draw_circle(center + Vector2(0, 8), 1.2, color)
			"luck":
				draw_line(center + Vector2(-7, 0), center + Vector2(7, 0), color, 2.0)
				draw_line(center + Vector2(0, -7), center + Vector2(0, 7), color, 2.0)
				draw_line(center + Vector2(-4, -4), center + Vector2(4, 4), color, 1.0)
				draw_line(center + Vector2(4, -4), center + Vector2(-4, 4), color, 1.0)
			"item":
				draw_rect(Rect2(center + Vector2(-6, -4), Vector2(12, 9)), Color(color, 0.35), true)
				draw_rect(Rect2(center + Vector2(-6, -4), Vector2(12, 9)), color, false, 1.5)
				draw_line(center + Vector2(-2, -4), center + Vector2(-2, -7), color, 1.5)
				draw_line(center + Vector2(-2, -7), center + Vector2(3, -7), color, 1.5)
				draw_line(center + Vector2(3, -7), center + Vector2(3, -4), color, 1.5)
			_:
				draw_circle(center + Vector2(-4, -1), 1.5, color)
				draw_circle(center + Vector2(0, -1), 1.5, color)
				draw_circle(center + Vector2(4, -1), 1.5, color)

	func _icon_color() -> Color:
		match kind:
			"cash_gain", "heat_down", "luck":
				return VisualStyle.CYAN
			"cash_cost", "heat_up":
				return VisualStyle.PINK_2
			"uncertain":
				return VisualStyle.YELLOW
			_:
				return VisualStyle.SOFT

var entry: Dictionary = {}
var option: Dictionary = {}
var queue_count: int = 0
var expanded := false
var armed_choice_id := ""
var reduce_motion := false

var panel: PanelContainer
var stack: VBoxContainer
var collapsed_button: Button
var collapse_button: Button
var header_row: HBoxContainer
var portrait_panel: Control
var portrait_model: PortraitModel
var speaker_label: Label
var summary_label: Label
var body_label: Label
var choice_list: GridContainer
var urgency_bar: ProgressBar
var badge_label: Label
var urgency_label: Label
var rendered_response_icon_kinds: Array[String] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	if portrait_model != null:
		portrait_model.set_animation_active(false)
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
		"speaker_text": speaker_label.text if speaker_label != null else "",
		"speaker_label_visible": speaker_label != null and speaker_label.is_visible_in_tree(),
		"summary": str(option.get("summary", "")),
		"queue_count": queue_count,
		"choice_count": _choices().size(),
		"ignore_penalty_heat": IGNORE_PENALTY_HEAT,
		"anchored_bottom_left": true,
		"presentation": "environment_overlay",
		"choice_effects_visible": false,
		"response_icon_kinds": rendered_response_icon_kinds.duplicate(),
		"portrait_animation_active": portrait_model.animation_active if portrait_model != null else false,
		"portrait_animation_redraw_count": portrait_model.animation_redraw_count if portrait_model != null else 0,
		"reduce_motion": reduce_motion,
		"timing": timing.duplicate(true),
		"panel_rect": panel.get_global_rect() if panel != null else Rect2(),
		"portrait_rect": portrait_panel.get_global_rect() if portrait_panel != null and portrait_panel.visible else Rect2(),
		"screen_rect": get_global_rect(),
	}


func set_reduce_motion(enabled: bool) -> void:
	reduce_motion = enabled
	if portrait_model != null:
		portrait_model.set_reduce_motion(enabled)
		portrait_model.set_animation_active(visible and expanded)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_position_panel()


func _build() -> void:
	panel = FoundationWidgets.panel_container(Color("#090717", 0.98), VisualStyle.PINK_2)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
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

	portrait_panel = Control.new()
	portrait_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait_panel)
	portrait_model = PortraitModel.new()
	portrait_model.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_panel.add_child(portrait_model)
	portrait_model.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_model.set_reduce_motion(reduce_motion)

	var header_text := VBoxContainer.new()
	header_text.add_theme_constant_override("separation", 2)
	header_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_text)

	speaker_label = FoundationWidgets.label("", 17)
	speaker_label.custom_minimum_size = Vector2(0, 22)
	speaker_label.max_lines_visible = 1
	speaker_label.clip_text = true
	FoundationWidgets.set_control_font_color(speaker_label, VisualStyle.YELLOW)
	header_text.add_child(speaker_label)

	summary_label = FoundationWidgets.muted_label("", 12)
	summary_label.max_lines_visible = 1
	summary_label.clip_text = true
	header_text.add_child(summary_label)

	urgency_label = FoundationWidgets.label("", 11)
	urgency_label.max_lines_visible = 1
	urgency_label.clip_text = true
	FoundationWidgets.set_control_font_color(urgency_label, VisualStyle.PINK_2)
	header_text.add_child(urgency_label)

	badge_label = FoundationWidgets.muted_label("", 12)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge_label.custom_minimum_size = Vector2(54, 0)
	header_row.add_child(badge_label)

	collapse_button = FoundationWidgets.button("Hide", Callable(self, "_toggle_expanded"))
	collapse_button.custom_minimum_size = Vector2(72, FoundationWidgets.MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	header_row.add_child(collapse_button)

	body_label = FoundationWidgets.label("", 14)
	body_label.max_lines_visible = 2
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(body_label)

	urgency_bar = ProgressBar.new()
	urgency_bar.min_value = 0.0
	urgency_bar.max_value = 1.0
	urgency_bar.value = 1.0
	urgency_bar.show_percentage = false
	urgency_bar.custom_minimum_size = Vector2(0, 5)
	stack.add_child(urgency_bar)

	choice_list = GridContainer.new()
	choice_list.columns = 2
	choice_list.add_theme_constant_override("h_separation", 8)
	choice_list.add_theme_constant_override("v_separation", 6)
	choice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(choice_list)


func _render() -> void:
	if panel == null:
		return
	var speaker_name := _speaker_name()
	var summary := str(option.get("summary", "")).strip_edges()
	collapsed_button.text = "Talk to %s - %s%s" % [
		speaker_name if not speaker_name.is_empty() else "Someone",
		summary.left(52) if not summary.is_empty() else str(option.get("display_name", "Talk")),
		"  +%d" % maxi(0, queue_count - 1) if queue_count > 1 else "",
	]
	speaker_label.text = "Speaking with %s" % (speaker_name if not speaker_name.is_empty() else "Someone")
	summary_label.text = str(option.get("display_name", "Talk"))
	summary_label.visible = false
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
	portrait_panel.visible = expanded
	collapsed_button.visible = not expanded
	header_row.visible = expanded
	body_label.visible = expanded
	urgency_label.visible = expanded and bool(timing.get("expires", false))
	choice_list.visible = expanded
	portrait_model.set_animation_active(expanded)
	_render_choices()
	panel.custom_minimum_size = Vector2.ZERO
	_position_panel()


func _render_choices() -> void:
	FoundationWidgets.clear(choice_list)
	rendered_response_icon_kinds.clear()
	if not expanded:
		return
	var choices := _choices()
	var compact_columns := mini(3, choices.size()) if choices.size() <= 3 else 2
	choice_list.columns = maxi(1, mini(4 if size.x >= 1040.0 else compact_columns, choices.size()))
	for choice in choices:
		if typeof(choice) != TYPE_DICTIONARY:
			continue
		var choice_data: Dictionary = choice
		var choice_id := str(choice_data.get("id", ""))
		if choice_id.is_empty():
			continue
		var label := _choice_display_label(choice_data)
		if _choice_requires_confirm(choice_data) and armed_choice_id == choice_id:
			label = "Confirm: %s" % label
		var response := HBoxContainer.new()
		response.add_theme_constant_override("separation", 3)
		response.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		response.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var icon_kinds := _response_icon_kinds(choice_data)
		for icon_kind in icon_kinds:
			var response_icon := ResponseIcon.new(icon_kind)
			response_icon.tooltip_text = _response_icon_description(icon_kind)
			response.add_child(response_icon)
			rendered_response_icon_kinds.append(icon_kind)
		var button := FoundationWidgets.button(label, Callable(self, "_on_choice_pressed").bind(choice_id))
		button.custom_minimum_size = Vector2(0, 40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		var enabled := bool(choice_data.get("enabled", true))
		var disabled_reason := str(choice_data.get("disabled_reason", "")).strip_edges()
		button.disabled = not enabled
		button.tooltip_text = disabled_reason if not enabled else _response_icon_descriptions(icon_kinds)
		response.add_child(button)
		choice_list.add_child(response)


func _response_icon_kinds(choice: Dictionary) -> Array[String]:
	var kinds: Array[String] = []
	var choice_text := "%s %s %s" % [
		str(choice.get("id", "")),
		str(choice.get("label", "")),
		str(choice.get("consequence_summary", "")),
	]
	var lowered := choice_text.to_lower()
	if lowered.contains("leave") or lowered.contains("pass") or lowered.contains("done") or lowered.contains("end conversation") or lowered.contains("event closes"):
		_append_icon_kind(kinds, "leave")
	_collect_response_effect_icons(choice.get("effects", {}), kinds)
	_collect_response_effect_icons(choice.get("consequences", {}), kinds)
	if lowered.contains("heat +") or lowered.contains("attention rises"):
		_append_icon_kind(kinds, "heat_up")
	if lowered.contains("heat -") or lowered.contains("attention falls"):
		_append_icon_kind(kinds, "heat_down")
	if lowered.contains("route") or lowered.contains("shortcut"):
		_append_icon_kind(kinds, "route")
	if lowered.contains("risk") or bool(choice.get("requires_confirm", false)):
		_append_icon_kind(kinds, "uncertain")
	if kinds.is_empty():
		kinds.append("talk")
	if kinds.size() > 2:
		kinds.resize(2)
	return kinds


func _collect_response_effect_icons(value: Variant, kinds: Array[String]) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		var effects: Dictionary = value
		for key_variant in effects.keys():
			var key := str(key_variant).to_lower()
			var effect_value: Variant = effects.get(key_variant)
			if key == "bankroll_delta" and (typeof(effect_value) == TYPE_INT or typeof(effect_value) == TYPE_FLOAT):
				_append_icon_kind(kinds, "cash_gain" if float(effect_value) > 0.0 else "cash_cost")
			elif key == "suspicion_delta" and (typeof(effect_value) == TYPE_INT or typeof(effect_value) == TYPE_FLOAT):
				_append_icon_kind(kinds, "heat_up" if float(effect_value) > 0.0 else "heat_down")
			elif key.contains("unlock_travel") or key.contains("route"):
				_append_icon_kind(kinds, "route")
			elif key.contains("chance") or key.contains("check") or key.contains("random"):
				_append_icon_kind(kinds, "uncertain")
			elif key.contains("luck"):
				_append_icon_kind(kinds, "luck")
			elif key.contains("item") or key.contains("inventory") or key.contains("gear"):
				_append_icon_kind(kinds, "item")
			if typeof(effect_value) == TYPE_DICTIONARY or typeof(effect_value) == TYPE_ARRAY:
				_collect_response_effect_icons(effect_value, kinds)
	elif typeof(value) == TYPE_ARRAY:
		for nested_value in value:
			_collect_response_effect_icons(nested_value, kinds)


func _append_icon_kind(kinds: Array[String], kind: String) -> void:
	if not kinds.has(kind):
		kinds.append(kind)


func _response_icon_descriptions(kinds: Array[String]) -> String:
	var descriptions: PackedStringArray = []
	for kind in kinds:
		descriptions.append(_response_icon_description(kind))
	return ", ".join(descriptions)


func _response_icon_description(kind: String) -> String:
	match kind:
		"leave":
			return "Leave the conversation"
		"route":
			return "May open a route"
		"cash_gain":
			return "May gain cash"
		"cash_cost":
			return "Costs cash"
		"heat_up":
			return "May draw attention"
		"heat_down":
			return "May lower attention"
		"uncertain":
			return "Uncertain outcome"
		"luck":
			return "May affect luck"
		"item":
			return "May involve gear"
		_:
			return "Conversation response"


func _choice_display_label(choice: Dictionary) -> String:
	var label := str(choice.get("label", choice.get("id", "Choose"))).strip_edges()
	match label.to_lower():
		"done":
			return "End conversation"
		"move on":
			return "Leave"
	return label


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


func _urgency_text(timing: Dictionary) -> String:
	if bool(timing.get("expires", false)):
		var remaining := maxi(0, int(timing.get("remaining_actions", timing.get("duration_actions", 0))))
		return "Respond soon - %d action%s left." % [remaining, "" if remaining == 1 else "s"]
	return "Choose what to say or do."


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
	var available_size := Vector2(
		maxf(280.0, size.x - VIEWPORT_MARGIN.x * 2.0),
		maxf(44.0, size.y - VIEWPORT_MARGIN.y * 2.0)
	)
	if not expanded:
		var collapsed_size := Vector2(
			minf(COLLAPSED_SIZE.x, available_size.x),
			minf(COLLAPSED_SIZE.y, available_size.y)
		)
		panel.size = collapsed_size
		panel.position = Vector2(VIEWPORT_MARGIN.x, maxf(VIEWPORT_MARGIN.y, size.y - collapsed_size.y - VIEWPORT_MARGIN.y))
		return
	var portrait_size := Vector2(
		minf(EXPANDED_PORTRAIT_SIZE.x, maxf(180.0, size.x * 0.24)),
		minf(EXPANDED_PORTRAIT_SIZE.y, maxf(230.0, size.y * 0.55))
	)
	portrait_panel.size = portrait_size
	portrait_panel.position = Vector2(
		VIEWPORT_MARGIN.x + 12.0,
		maxf(VIEWPORT_MARGIN.y, size.y - portrait_size.y - VIEWPORT_MARGIN.y)
	)
	var panel_left := minf(
		portrait_panel.position.x + portrait_size.x - 12.0,
		maxf(VIEWPORT_MARGIN.x, size.x - 280.0 - VIEWPORT_MARGIN.x)
	)
	var panel_available_width := maxf(280.0, size.x - panel_left - VIEWPORT_MARGIN.x)
	var panel_size := Vector2(
		minf(EXPANDED_PANEL_SIZE.x, panel_available_width),
		minf(EXPANDED_PANEL_SIZE.y, available_size.y)
	)
	var minimum_size := panel.get_combined_minimum_size()
	panel_size.x = minf(maxf(panel_size.x, minimum_size.x), panel_available_width)
	panel_size.y = minf(maxf(panel_size.y, minimum_size.y), available_size.y)
	panel.size = panel_size
	panel.position = Vector2(panel_left, maxf(VIEWPORT_MARGIN.y, size.y - panel_size.y - VIEWPORT_MARGIN.y))


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
