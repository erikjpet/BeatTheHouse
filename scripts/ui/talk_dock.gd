class_name TalkDock
extends Control

signal choice_requested(event_id: String, choice_id: String)
signal occupied_rect_changed(rect: Rect2)

const COLLAPSED_SIZE := Vector2(420, 58)
const EXPANDED_PANEL_WIDTH := 460.0
const SINGLE_CHOICE_PANEL_WIDTH := 420.0
const EXPANDED_PANEL_BASE_HEIGHT := 160.0
const EXPANDED_PANEL_EXTRA_ROW_HEIGHT := 40.0
const EXPANDED_PANEL_EXTRA_BODY_LINE_HEIGHT := 23.0
const SMALL_SCREEN_CHOICE_ROW_EXTRA := 12.0
const EXPANDED_PORTRAIT_SIZE := Vector2(210, 290)
const VIEWPORT_MARGIN := Vector2(18, 18)
const MAX_CHOICES := 4
const IGNORE_PENALTY_HEAT := 5
const PRESENTATION_Z_INDEX := 100
const SmallScreenPolicyScript := preload("res://scripts/ui/small_screen_policy.gd")


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
		var portrait_count := clampi(int(speaker.get("portrait_count", 1)), 1, 3)
		if portrait_count > 1:
			_draw_speaker_group(portrait_count)
		elif str(speaker.get("presentation", "")) == "faceless_silhouette":
			_draw_faceless_silhouette()
		else:
			_draw_visible_speaker()

	func _draw_visible_speaker() -> void:
		var members: Array = speaker.get("members", []) if typeof(speaker.get("members", [])) == TYPE_ARRAY else []
		var member: Dictionary = members[0] if not members.is_empty() and typeof(members[0]) == TYPE_DICTIONARY else {}
		var style := _visible_style(animation_clock, member)
		var character_scale := clampf(minf(size.x / 98.0, size.y / 150.0) * 0.92, 0.92, 2.6)
		character_scale *= _member_scale(member)
		var speech_bob := sin(animation_clock * 3.1) * 1.15 * character_scale
		PortraitTableGameVisualsScript._draw_table_character(self, style, Vector2(size.x * 0.5, size.y + 18.0 + speech_bob), character_scale, animation_clock)

	func _draw_speaker_group(portrait_count: int) -> void:
		var faceless := str(speaker.get("presentation", "")) == "faceless_silhouette"
		var members: Array = speaker.get("members", []) if typeof(speaker.get("members", [])) == TYPE_ARRAY else []
		var base_scale := clampf(minf(size.x / 98.0, size.y / 150.0) * 0.68, 0.82, 1.9)
		var back_scale := base_scale * 0.82
		if portrait_count >= 2:
			var left_member: Dictionary = members[1] if members.size() > 1 and typeof(members[1]) == TYPE_DICTIONARY else {}
			_draw_group_member(Vector2(size.x * 0.31, size.y + 8.0), back_scale * _member_scale(left_member), animation_clock + 0.7, faceless, left_member)
		if portrait_count >= 3:
			var right_member: Dictionary = members[2] if members.size() > 2 and typeof(members[2]) == TYPE_DICTIONARY else {}
			_draw_group_member(Vector2(size.x * 0.69, size.y + 8.0), back_scale * _member_scale(right_member), animation_clock + 1.4, faceless, right_member)
		var lead_member: Dictionary = members[0] if not members.is_empty() and typeof(members[0]) == TYPE_DICTIONARY else {}
		_draw_group_member(Vector2(size.x * 0.5, size.y + 20.0), base_scale * _member_scale(lead_member), animation_clock, faceless, lead_member)

	func _draw_group_member(anchor: Vector2, character_scale: float, phase: float, faceless: bool, member: Dictionary = {}) -> void:
		var idle_bob := 0.0 if reduce_motion else sin(phase * 2.1) * 1.2 * character_scale
		var style := _faceless_style(phase) if faceless else _visible_style(phase, member)
		PortraitTableGameVisualsScript._draw_table_character(
			self,
			style,
			anchor + Vector2(0.0, idle_bob),
			character_scale,
			phase
		)

	func _draw_faceless_silhouette() -> void:
		var character_scale := clampf(minf(size.x / 98.0, size.y / 150.0) * 0.92, 0.92, 2.6)
		var idle_bob := 0.0 if reduce_motion else sin(animation_clock * 2.1) * 1.2 * character_scale
		PortraitTableGameVisualsScript._draw_table_character(self, _faceless_style(animation_clock), Vector2(size.x * 0.5, size.y + 18.0 + idle_bob), character_scale, animation_clock)

	func _faceless_style(phase: float) -> Dictionary:
		# "shadow" is a palette color, not a semantic role. Passing it through
		# role() fell back to white and rendered anonymous callers as a blank white
		# paper-doll instead of a readable faceless silhouette.
		var shadow := VisualStyle.color("shadow")
		return {
			"name": "",
			"skin": shadow,
			"hair": shadow,
			"jacket": shadow,
			"accent": VisualStyle.role("disabled"),
			"role": str(speaker.get("role", "stranger")),
			"pose": "watching" if fposmod(phase, 2.8) > 1.9 else "speaking",
			"eye_offset": 0.0,
			"blink": false,
			"holding_card": false,
			"silhouette": str(speaker.get("silhouette", "featureless")),
			"faceless": true,
		}

	func _visible_style(phase: float, member: Dictionary = {}) -> Dictionary:
		var cycle := fposmod(phase, 4.2) / 4.2
		var model: Dictionary = member.get("model", {}) if typeof(member.get("model", {})) == TYPE_DICTIONARY else {}
		return {
			"name": "",
			"skin": _model_color(model, "skin_color", VisualStyle.PORTRAIT_SKIN),
			"hair": _model_color(model, "hair_color", _speaker_color("hair_color", VisualStyle.SHADOW)),
			"jacket": _model_color(model, "jacket_color", _speaker_color("jacket_color", VisualStyle.BLUE)),
			"accent": _model_color(model, "accent_color", VisualStyle.CYAN_2),
			"role": str(member.get("role", speaker.get("role", "staff"))),
			"pose": "watching" if fposmod(phase, 2.8) > 1.9 else "speaking",
			"eye_offset": sin(phase * 0.72) * 0.55,
			"blink": cycle > 0.92 and cycle < 0.975,
			"holding_card": false,
			"silhouette": str(model.get("silhouette", speaker.get("silhouette", "coat"))),
		}

	func surface_label(_text: String, _pos: Vector2, _font_size: int, _color: Color) -> void:
		pass

	func _speaker_color(field: String, fallback: Color) -> Color:
		var text := str(speaker.get(field, "")).strip_edges()
		if text.is_empty():
			return fallback
		return Color(text)

	func _model_color(model: Dictionary, field: String, fallback: Color) -> Color:
		var text := str(model.get(field, "")).strip_edges()
		return Color(text) if not text.is_empty() else fallback

	func _member_scale(member: Dictionary) -> float:
		var model: Dictionary = member.get("model", {}) if typeof(member.get("model", {})) == TYPE_DICTIONARY else {}
		return clampf(float(model.get("scale", 1.0)), 0.75, 1.25)


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


static func create_portrait_model() -> Control:
	return PortraitModel.new()

var entry: Dictionary = {}
var option: Dictionary = {}
var queue_count: int = 0
var expanded := false
var armed_choice_id := ""
var reduce_motion := false
var small_screen_mode := false
var full_body_text := ""
var reveal_elapsed := 0.0
var typewriter_active := false
var rendered_entry_key := ""
var last_occupied_rect := Rect2()
var avoid_global_rect := Rect2()
var reserved_body_line_count := 1

var panel: PanelContainer
var stack: VBoxContainer
var collapsed_button: Button
var collapse_button: Button
var header_row: HBoxContainer
var portrait_panel: Control
var portrait_model: PortraitModel
var speaker_name_plate: PanelContainer
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
	z_index = PRESENTATION_Z_INDEX
	visible = false
	_build()
	_position_panel()
	set_process(false)


func _process(delta: float) -> void:
	if not typewriter_active or body_label == null:
		set_process(false)
		return
	reveal_elapsed += delta * VisualStyle.TYPEWRITER_CHARACTERS_PER_SECOND
	body_label.visible_characters = mini(full_body_text.length(), maxi(1, int(floor(reveal_elapsed))))
	if body_label.visible_characters >= full_body_text.length():
		_complete_body_reveal()


func set_entry(next_entry: Dictionary, next_option: Dictionary, next_queue_count: int) -> void:
	var next_key := JSON.stringify({
		"entry": next_entry,
		"option": next_option,
		"queue_count": maxi(0, next_queue_count),
	})
	if visible and next_key == rendered_entry_key:
		return
	entry = next_entry.duplicate(true)
	option = next_option.duplicate(true)
	queue_count = maxi(0, next_queue_count)
	if entry.is_empty() or option.is_empty():
		clear_entry()
		return
	expanded = true
	armed_choice_id = ""
	rendered_entry_key = next_key
	visible = true
	_render()
	_play_attention_animation()


func clear_entry() -> void:
	entry = {}
	option = {}
	queue_count = 0
	expanded = false
	armed_choice_id = ""
	rendered_entry_key = ""
	visible = false
	if portrait_model != null:
		portrait_model.set_animation_active(false)
	if choice_list != null:
		FoundationWidgets.clear(choice_list)
	full_body_text = ""
	typewriter_active = false
	set_process(false)
	_notify_occupied_rect_changed()


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
	var portrait_speaker: Dictionary = portrait_model.speaker if portrait_model != null else {}
	var portrait_members: Array = portrait_speaker.get("members", []) if typeof(portrait_speaker.get("members", [])) == TYPE_ARRAY else []
	var character_ids: Array = []
	var character_names: Array = []
	var choice_ids: Array = []
	for choice_value in _choices():
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice_id := str((choice_value as Dictionary).get("id", "")).strip_edges()
		if not choice_id.is_empty():
			choice_ids.append(choice_id)
	for member_value in portrait_members:
		if typeof(member_value) != TYPE_DICTIONARY:
			continue
		var member: Dictionary = member_value
		character_ids.append(str(member.get("character_id", "")))
		character_names.append(str(member.get("display_name", "")))
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
		"choice_ids": choice_ids,
		"choice_button_height": _rendered_choice_button_height(),
		"ignore_penalty_heat": IGNORE_PENALTY_HEAT,
		"anchored_bottom_left": true,
		"presentation": "environment_overlay",
		"z_index": z_index,
		"choice_effects_visible": false,
		"response_icon_kinds": rendered_response_icon_kinds.duplicate(),
		"portrait_animation_active": portrait_model.animation_active if portrait_model != null else false,
		"portrait_animation_redraw_count": portrait_model.animation_redraw_count if portrait_model != null else 0,
		"portrait_renderer": "animated_character_model",
		"portrait_presentation": str(portrait_model.speaker.get("presentation", "")) if portrait_model != null else "",
		"portrait_count": clampi(int(portrait_model.speaker.get("portrait_count", 1)), 1, 3) if portrait_model != null else 0,
		"character_pool_id": str(portrait_speaker.get("character_pool_id", "")),
		"character_ids": character_ids,
		"character_names": character_names,
		"speaking_character_id": str(portrait_speaker.get("speaking_character_id", "")),
		"speaking_character_name": str(portrait_speaker.get("speaking_character_name", "")),
		"speaking_character_title": str(portrait_speaker.get("speaking_character_title", "")),
		"voice_line_key": str(portrait_speaker.get("voice_line_key", "")),
		"voice_line": str(portrait_speaker.get("voice_line", "")),
		"character_encounter": (portrait_speaker.get("encounter", {}) as Dictionary).duplicate(true) if typeof(portrait_speaker.get("encounter", {})) == TYPE_DICTIONARY else {},
		"name_plate": speaker_name_plate != null,
		"topic": summary_label.text if summary_label != null else "",
		"topic_visible": summary_label != null and summary_label.is_visible_in_tree(),
		"typewriter_active": typewriter_active,
		"visible_characters": body_label.visible_characters if body_label != null else -1,
		"body_character_count": full_body_text.length(),
		"body_line_count": body_label.get_line_count() if body_label != null else 0,
		"body_visible_line_count": body_label.get_visible_line_count() if body_label != null else 0,
		"body_text_clipped": body_label != null and body_label.get_line_count() > body_label.get_visible_line_count(),
		"urgency_bar_visible": urgency_bar != null and urgency_bar.is_visible_in_tree(),
		"click_to_skip": true,
		"reduce_motion": reduce_motion,
		"timing": timing.duplicate(true),
		"panel_rect": panel.get_global_rect() if panel != null else Rect2(),
		"portrait_rect": portrait_panel.get_global_rect() if portrait_panel != null and portrait_panel.visible else Rect2(),
		"occupied_rect": occupied_global_rect(),
		"environment_reserved_rect": environment_reserved_global_rect(),
		"avoid_rect": avoid_global_rect,
		"layout_side": str(_expanded_layout_rects(false).get("side", "left")),
		"screen_rect": get_global_rect(),
	}


func occupied_global_rect() -> Rect2:
	if not visible or panel == null:
		return Rect2()
	var occupied := panel.get_global_rect()
	if expanded and portrait_panel != null and portrait_panel.visible:
		occupied = occupied.merge(portrait_panel.get_global_rect())
	return occupied


# This footprint remains stable while dialogue is hidden, so environment
# objects are authored into a safe composition before a future talk opens.
func environment_reserved_global_rect() -> Rect2:
	if not is_inside_tree():
		return Rect2()
	var layout := _expanded_layout_rects(true)
	var local_rect: Rect2 = layout.get("portrait_rect", Rect2())
	local_rect = local_rect.merge(layout.get("panel_rect", Rect2()))
	var canvas_transform := get_global_transform()
	var top_left := canvas_transform * local_rect.position
	var top_right := canvas_transform * Vector2(local_rect.end.x, local_rect.position.y)
	var bottom_left := canvas_transform * Vector2(local_rect.position.x, local_rect.end.y)
	var bottom_right := canvas_transform * local_rect.end
	var minimum := Vector2(
		minf(minf(top_left.x, top_right.x), minf(bottom_left.x, bottom_right.x)),
		minf(minf(top_left.y, top_right.y), minf(bottom_left.y, bottom_right.y))
	)
	var maximum := Vector2(
		maxf(maxf(top_left.x, top_right.x), maxf(bottom_left.x, bottom_right.x)),
		maxf(maxf(top_left.y, top_right.y), maxf(bottom_left.y, bottom_right.y))
	)
	return Rect2(minimum, maximum - minimum)


func set_reduce_motion(enabled: bool) -> void:
	reduce_motion = enabled
	if reduce_motion:
		_complete_body_reveal()
	if portrait_model != null:
		portrait_model.set_reduce_motion(enabled)
		portrait_model.set_animation_active(visible and expanded)


# Keep an authored instruction away from its live target without taking input
# ownership from that target.
func set_avoid_global_rect(next_rect: Rect2) -> void:
	if avoid_global_rect.is_equal_approx(next_rect):
		return
	var previous_has_area := avoid_global_rect.has_area()
	var previous_side := _preferred_layout_side()
	avoid_global_rect = next_rect
	var side_changed := previous_side != _preferred_layout_side()
	var occupancy_changed := previous_has_area != avoid_global_rect.has_area()
	if side_changed or occupancy_changed or occupied_global_rect().intersects(avoid_global_rect.grow(8.0)):
		_position_panel()


func set_small_screen_mode(enabled: bool) -> void:
	if small_screen_mode == enabled:
		return
	small_screen_mode = enabled
	if collapsed_button != null:
		collapsed_button.custom_minimum_size.y = SmallScreenPolicyScript.control_height(FoundationWidgets.MIN_NATIVE_TOUCH_TARGET_HEIGHT, enabled)
	if collapse_button != null:
		collapse_button.custom_minimum_size.y = SmallScreenPolicyScript.control_height(VisualStyle.TALK_CHOICE_HEIGHT, enabled)
	_render_choices()
	_position_panel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_position_panel()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		call_deferred("_notify_occupied_rect_changed")


func _build() -> void:
	panel = FoundationWidgets.panel_container(Color(VisualStyle.role("surface_overlay"), 0.98), VisualStyle.role("danger"))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	add_child(panel)

	stack = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", VisualStyle.SPACE_2)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(stack)

	collapsed_button = FoundationWidgets.button("", Callable(self, "_toggle_expanded"))
	collapsed_button.custom_minimum_size = Vector2(VisualStyle.FLEXIBLE_SIZE, FoundationWidgets.MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	stack.add_child(collapsed_button)

	header_row = HBoxContainer.new()
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_theme_constant_override("separation", VisualStyle.SPACE_5)
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
	header_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_text.add_theme_constant_override("separation", VisualStyle.SPACE_1)
	header_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_text)

	speaker_name_plate = FoundationWidgets.panel_container(VisualStyle.role("surface_raised"), VisualStyle.role("accent_secondary"))
	speaker_name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker_name_plate.custom_minimum_size.y = VisualStyle.TALK_CHOICE_HEIGHT
	header_text.add_child(speaker_name_plate)
	speaker_label = FoundationWidgets.label("", VisualStyle.TYPE_HEADING)
	speaker_label.custom_minimum_size = Vector2(VisualStyle.FLEXIBLE_SIZE, VisualStyle.TALK_CHOICE_HEIGHT)
	speaker_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker_label.max_lines_visible = 1
	speaker_label.clip_text = false
	FoundationWidgets.set_control_font_color(speaker_label, VisualStyle.YELLOW)
	speaker_name_plate.add_child(speaker_label)

	summary_label = FoundationWidgets.muted_label("", VisualStyle.TYPE_SMALL)
	summary_label.max_lines_visible = 1
	summary_label.clip_text = true
	header_text.add_child(summary_label)

	urgency_label = FoundationWidgets.label("", VisualStyle.TYPE_CAPTION)
	urgency_label.max_lines_visible = 1
	urgency_label.clip_text = true
	FoundationWidgets.set_control_font_color(urgency_label, VisualStyle.PINK_2)
	header_text.add_child(urgency_label)

	badge_label = FoundationWidgets.muted_label("", VisualStyle.TYPE_SMALL)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge_label.custom_minimum_size = Vector2(VisualStyle.TALK_BADGE_WIDTH, VisualStyle.FLEXIBLE_SIZE)
	header_row.add_child(badge_label)

	collapse_button = FoundationWidgets.button("Hide", Callable(self, "_toggle_expanded"))
	collapse_button.custom_minimum_size = Vector2(VisualStyle.TALK_COLLAPSE_WIDTH, VisualStyle.TALK_CHOICE_HEIGHT)
	header_row.add_child(collapse_button)

	body_label = FoundationWidgets.label("", VisualStyle.TYPE_BODY_LARGE)
	body_label.max_lines_visible = 4
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.mouse_filter = Control.MOUSE_FILTER_STOP
	body_label.gui_input.connect(Callable(self, "_on_body_gui_input"))
	stack.add_child(body_label)

	urgency_bar = ProgressBar.new()
	urgency_bar.min_value = 0.0
	urgency_bar.max_value = 1.0
	urgency_bar.value = 1.0
	urgency_bar.show_percentage = false
	urgency_bar.custom_minimum_size = Vector2(VisualStyle.FLEXIBLE_SIZE, VisualStyle.TALK_URGENCY_HEIGHT)
	urgency_bar.visible = false
	stack.add_child(urgency_bar)

	choice_list = GridContainer.new()
	choice_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_list.columns = 2
	choice_list.add_theme_constant_override("h_separation", VisualStyle.SPACE_3)
	choice_list.add_theme_constant_override("v_separation", VisualStyle.SPACE_2)
	choice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_list.size_flags_vertical = Control.SIZE_SHRINK_END
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
	speaker_label.text = _speaker_display_name()
	summary_label.text = str(option.get("display_name", "Talk"))
	summary_label.visible = expanded
	_begin_body_reveal(summary)
	var timing: Dictionary = entry.get("timing", {}) if typeof(entry.get("timing", {})) == TYPE_DICTIONARY else {}
	urgency_label.text = _urgency_text(timing)
	badge_label.text = "+%d" % maxi(0, queue_count - 1) if queue_count > 1 else ""
	if portrait_model != null:
		var speaker: Dictionary = entry.get("speaker", {}) if typeof(entry.get("speaker", {})) == TYPE_DICTIONARY else {}
		portrait_model.set_speaker(speaker)
	if bool(timing.get("expires", false)):
		var duration := maxi(1, int(timing.get("duration_actions", 1)))
		urgency_bar.value = clampf(float(int(timing.get("remaining_actions", duration))) / float(duration), 0.0, 1.0)
	urgency_bar.visible = false
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
	call_deferred("_position_panel")


func _begin_body_reveal(text_value: String) -> void:
	if text_value == full_body_text and (typewriter_active or body_label.visible_characters == -1):
		return
	full_body_text = text_value
	reserved_body_line_count = _estimated_body_line_count(EXPANDED_PANEL_WIDTH)
	reveal_elapsed = 0.0
	body_label.text = full_body_text
	body_label.mouse_filter = Control.MOUSE_FILTER_STOP
	if reduce_motion or full_body_text.is_empty():
		_complete_body_reveal()
		return
	body_label.visible_characters = mini(1, full_body_text.length())
	typewriter_active = true
	set_process(true)


func _complete_body_reveal() -> void:
	typewriter_active = false
	set_process(false)
	if body_label != null:
		body_label.visible_characters = -1
		body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_body_gui_input(event: InputEvent) -> void:
	if not typewriter_active:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_complete_body_reveal()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_complete_body_reveal()
		get_viewport().set_input_as_handled()


func _render_choices() -> void:
	FoundationWidgets.clear(choice_list)
	rendered_response_icon_kinds.clear()
	if not expanded:
		return
	var choices := _choices()
	var compact_columns := mini(3, choices.size()) if choices.size() <= 3 else 2
	var maximum_columns := 2 if small_screen_mode else (4 if size.x >= 1040.0 else compact_columns)
	choice_list.columns = maxi(1, mini(maximum_columns, choices.size()))
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
		response.add_theme_constant_override("separation", VisualStyle.SPACE_2)
		response.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		response.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var icon_kinds := _response_icon_kinds(choice_data)
		for icon_kind in icon_kinds:
			var response_icon := ResponseIcon.new(icon_kind)
			response_icon.tooltip_text = _response_icon_description(icon_kind)
			response.add_child(response_icon)
			rendered_response_icon_kinds.append(icon_kind)
		var button := FoundationWidgets.button(label, Callable(self, "_on_choice_pressed").bind(choice_id))
		button.custom_minimum_size = Vector2(VisualStyle.FLEXIBLE_SIZE, SmallScreenPolicyScript.control_height(VisualStyle.TALK_CHOICE_HEIGHT, small_screen_mode))
		FoundationWidgets.set_control_font_size(button, VisualStyle.TYPE_SMALL)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.clip_text = true
		var enabled := bool(choice_data.get("enabled", true))
		var disabled_reason := str(choice_data.get("disabled_reason", "")).strip_edges()
		button.disabled = not enabled
		button.tooltip_text = disabled_reason if not enabled else _response_icon_descriptions(icon_kinds)
		response.add_child(button)
		choice_list.add_child(response)


func _rendered_choice_button_height() -> float:
	if choice_list == null:
		return 0.0
	var maximum_height := 0.0
	for response_value in choice_list.get_children():
		if not response_value is Control:
			continue
		for child_value in (response_value as Control).get_children():
			if child_value is Button:
				maximum_height = maxf(maximum_height, (child_value as Button).size.y)
	return maximum_height


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
	if str(speaker.get("presentation", "")) == "faceless_silhouette":
		return "Unknown"
	var role := str(speaker.get("role", "stranger")).strip_edges()
	return role.replace("_", " ").capitalize()


func _speaker_display_name() -> String:
	var speaker: Dictionary = entry.get("speaker", {}) if typeof(entry.get("speaker", {})) == TYPE_DICTIONARY else {}
	var character_name := str(speaker.get("speaking_character_name", "")).strip_edges()
	var character_title := str(speaker.get("speaking_character_title", "")).strip_edges()
	if not character_name.is_empty():
		return "%s — %s" % [character_name, character_title] if not character_title.is_empty() else character_name
	var speaker_name := _speaker_name()
	return speaker_name if not speaker_name.is_empty() else "Unknown"


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
		_notify_occupied_rect_changed()
		return
	var layout := _expanded_layout_rects(false)
	var next_portrait_rect: Rect2 = layout.get("portrait_rect", Rect2())
	var next_panel_rect: Rect2 = layout.get("panel_rect", Rect2())
	portrait_panel.position = next_portrait_rect.position
	portrait_panel.size = next_portrait_rect.size
	panel.position = next_panel_rect.position
	panel.size = next_panel_rect.size
	_notify_occupied_rect_changed()


func _expanded_layout_rects(reserve_maximum_capacity: bool) -> Dictionary:
	var available_size := Vector2(
		maxf(280.0, size.x - VIEWPORT_MARGIN.x * 2.0),
		maxf(44.0, size.y - VIEWPORT_MARGIN.y * 2.0)
	)
	var portrait_size := Vector2(
		minf(EXPANDED_PORTRAIT_SIZE.x, maxf(150.0, size.x * 0.18)),
		minf(EXPANDED_PORTRAIT_SIZE.y, maxf(190.0, size.y * 0.44))
	)
	var choice_count := MAX_CHOICES if reserve_maximum_capacity else _choices().size()
	var desired_width := EXPANDED_PANEL_WIDTH if reserve_maximum_capacity or choice_count > 1 else SINGLE_CHOICE_PANEL_WIDTH
	var choice_columns := 2 if reserve_maximum_capacity else maxi(1, choice_list.columns if choice_list != null else 1)
	var choice_rows := maxi(1, ceili(float(maxi(1, choice_count)) / float(choice_columns)))
	var desired_height := EXPANDED_PANEL_BASE_HEIGHT
	desired_height += float(maxi(0, choice_rows - 1)) * EXPANDED_PANEL_EXTRA_ROW_HEIGHT
	var body_line_count := reserved_body_line_count if reserve_maximum_capacity else _estimated_body_line_count(desired_width)
	desired_height += float(maxi(0, body_line_count - 2)) * EXPANDED_PANEL_EXTRA_BODY_LINE_HEIGHT
	if small_screen_mode:
		desired_height += float(choice_rows) * SMALL_SCREEN_CHOICE_ROW_EXTRA
	if panel != null:
		desired_height = maxf(desired_height, panel.get_combined_minimum_size().y)
	var side := _preferred_layout_side()
	var portrait_x := VIEWPORT_MARGIN.x + 12.0
	if side == "right":
		portrait_x = maxf(VIEWPORT_MARGIN.x, size.x - portrait_size.x - VIEWPORT_MARGIN.x - 12.0)
	var portrait_rect := Rect2(
		Vector2(portrait_x, maxf(VIEWPORT_MARGIN.y, size.y - portrait_size.y - VIEWPORT_MARGIN.y)),
		portrait_size
	)
	var panel_available_width := maxf(280.0, size.x - portrait_size.x - VIEWPORT_MARGIN.x * 2.0 + 12.0)
	var panel_size := Vector2(minf(desired_width, panel_available_width), minf(desired_height, available_size.y))
	var panel_left := portrait_rect.position.x + portrait_size.x - 12.0
	if side == "right":
		panel_left = portrait_rect.position.x - panel_size.x + 12.0
	panel_left = clampf(panel_left, VIEWPORT_MARGIN.x, maxf(VIEWPORT_MARGIN.x, size.x - panel_size.x - VIEWPORT_MARGIN.x))
	var panel_rect := Rect2(Vector2(panel_left, maxf(VIEWPORT_MARGIN.y, size.y - panel_size.y - VIEWPORT_MARGIN.y)), panel_size)
	var avoid_local_rect := _global_rect_to_local_rect(avoid_global_rect)
	var occupied_rect := portrait_rect.merge(panel_rect)
	if avoid_local_rect.has_area() and occupied_rect.intersects(avoid_local_rect.grow(8.0)):
		var lift := avoid_local_rect.position.y - 8.0 - occupied_rect.end.y
		if occupied_rect.position.y + lift >= VIEWPORT_MARGIN.y:
			portrait_rect.position.y += lift
			panel_rect.position.y += lift
		else:
			var drop := avoid_local_rect.end.y + 8.0 - occupied_rect.position.y
			if occupied_rect.end.y + drop <= size.y - VIEWPORT_MARGIN.y:
				portrait_rect.position.y += drop
				panel_rect.position.y += drop
	return {
		"portrait_rect": portrait_rect,
		"panel_rect": panel_rect,
		"side": side,
	}


func _global_rect_to_local_rect(global_rect: Rect2) -> Rect2:
	if not global_rect.has_area() or not is_inside_tree():
		return Rect2()
	var inverse := get_global_transform().affine_inverse()
	var corner_a := inverse * global_rect.position
	var corner_b := inverse * Vector2(global_rect.end.x, global_rect.position.y)
	var corner_c := inverse * global_rect.end
	var corner_d := inverse * Vector2(global_rect.position.x, global_rect.end.y)
	var minimum := Vector2(minf(minf(corner_a.x, corner_b.x), minf(corner_c.x, corner_d.x)), minf(minf(corner_a.y, corner_b.y), minf(corner_c.y, corner_d.y)))
	var maximum := Vector2(maxf(maxf(corner_a.x, corner_b.x), maxf(corner_c.x, corner_d.x)), maxf(maxf(corner_a.y, corner_b.y), maxf(corner_c.y, corner_d.y)))
	return Rect2(minimum, maximum - minimum)


func _estimated_body_line_count(panel_width: float) -> int:
	if full_body_text.strip_edges().is_empty():
		return 1
	var usable_width := maxf(220.0, panel_width - 36.0)
	var average_character_width := maxf(7.0, float(VisualStyle.TYPE_BODY_LARGE) * 0.53)
	var characters_per_line := maxi(24, int(floor(usable_width / average_character_width)))
	return clampi(ceili(float(full_body_text.length()) / float(characters_per_line)), 1, 4)


func _preferred_layout_side() -> String:
	if not avoid_global_rect.has_area():
		return "left"
	return "right" if avoid_global_rect.get_center().x < global_position.x + size.x * 0.5 else "left"


func _notify_occupied_rect_changed() -> void:
	if not is_inside_tree():
		return
	var next_rect := occupied_global_rect()
	if next_rect.is_equal_approx(last_occupied_rect):
		return
	last_occupied_rect = next_rect
	occupied_rect_changed.emit(next_rect)


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
