class_name CoachOverlay
extends Control

signal lesson_seen(lesson_id: String)
signal lesson_completed(lesson_id: String)

const CoachViewModelScript := preload("res://scripts/ui/coach_view_model.gd")


class FocusLayer:
	extends Control

	const CoachFocusViewModelScript := preload("res://scripts/ui/coach_view_model.gd")

	var snapshot: Dictionary = {}

	func set_snapshot(next_snapshot: Dictionary) -> void:
		snapshot = next_snapshot.duplicate(true)
		queue_redraw()

	func _draw() -> void:
		if snapshot.is_empty() or not bool(snapshot.get("visible", false)):
			return
		var anchor := CoachFocusViewModelScript._rect(snapshot.get("anchor_rect", {}))
		var alpha := 0.40 if bool(snapshot.get("gating", false)) else 0.10
		if anchor.is_empty():
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, alpha), true)
			return
		var top_height := maxf(0.0, anchor.position.y)
		var bottom_y := minf(size.y, anchor.end.y)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, top_height)), Color(0.0, 0.0, 0.0, alpha), true)
		draw_rect(Rect2(Vector2(0.0, bottom_y), Vector2(size.x, maxf(0.0, size.y - bottom_y))), Color(0.0, 0.0, 0.0, alpha), true)
		draw_rect(Rect2(Vector2(0.0, anchor.position.y), Vector2(maxf(0.0, anchor.position.x), anchor.size.y)), Color(0.0, 0.0, 0.0, alpha), true)
		draw_rect(Rect2(Vector2(anchor.end.x, anchor.position.y), Vector2(maxf(0.0, size.x - anchor.end.x), anchor.size.y)), Color(0.0, 0.0, 0.0, alpha), true)
		draw_rect(anchor.grow(4.0), VisualStyle.YELLOW, false, 2.0)


var lessons: Array = []
var seen: Dictionary = {}
var queued_lessons: Array = []
var queued_ids: Dictionary = {}
var active_lesson: Dictionary = {}
var active_context: Dictionary = {}
var latest_context: Dictionary = {}
var prepared_snapshot: Dictionary = {}
var active_layout_key := 0
var tips_enabled := true
var reduce_motion := false
var small_screen := false

var focus_layer: FocusLayer
var panel: PanelContainer
var eyebrow_label: Label
var copy_label: Label
var ok_button: Button
var attention_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 90
	visible = false
	_build()


func set_lessons(next_lessons: Array) -> void:
	lessons = next_lessons.duplicate(true)


func restore_seen(next_seen: Dictionary) -> void:
	seen = next_seen.duplicate(true)
	queued_lessons.clear()
	queued_ids.clear()
	active_lesson = {}
	active_context = {}
	latest_context = {}
	prepared_snapshot = {}
	active_layout_key = 0
	visible = false


func reset_seen() -> void:
	restore_seen({})


func set_tips_enabled(enabled: bool) -> void:
	tips_enabled = enabled
	if enabled:
		return
	var retained: Array = []
	for entry_value in queued_lessons:
		var entry := _dict(entry_value)
		var lesson := _dict(entry.get("lesson", {}))
		if not _dict(lesson.get("gating", {})).is_empty():
			retained.append(entry)
	queued_lessons = retained
	_rebuild_queued_ids()
	if not active_lesson.is_empty() and _dict(active_lesson.get("gating", {})).is_empty():
		_finish_active()


func set_reduce_motion(enabled: bool) -> void:
	reduce_motion = enabled
	if not prepared_snapshot.is_empty():
		active_context["reduce_motion"] = enabled
		_render_active(false)


func set_small_screen_mode(enabled: bool) -> void:
	small_screen = enabled
	if not prepared_snapshot.is_empty():
		active_context["small_screen"] = enabled
		_render_active(false)


func evaluate_at_boundary(context: Dictionary) -> void:
	var observed_context := context.duplicate(true)
	observed_context["reduce_motion"] = reduce_motion
	observed_context["small_screen"] = small_screen
	latest_context = observed_context
	if not active_lesson.is_empty():
		var next_layout_key := _layout_key(active_lesson, observed_context)
		if next_layout_key != active_layout_key:
			active_context = observed_context.duplicate(true)
			_render_active(false)
	for lesson_value in lessons:
		if typeof(lesson_value) != TYPE_DICTIONARY:
			continue
		var lesson: Dictionary = lesson_value
		var lesson_id := str(lesson.get("id", "")).strip_edges()
		if bool(queued_ids.get(lesson_id, false)) or (not active_lesson.is_empty() and str(active_lesson.get("id", "")) == lesson_id):
			continue
		if CoachViewModelScript.trigger_matches(lesson, observed_context, seen, tips_enabled):
			queued_lessons.append({"lesson": lesson.duplicate(true), "context": observed_context.duplicate(true)})
			queued_ids[lesson_id] = true
	if active_lesson.is_empty():
		_show_next()


func notify_action(action_id: String) -> bool:
	if active_lesson.is_empty() or not CoachViewModelScript.completion_matches(active_lesson, action_id):
		return false
	_finish_active()
	return true


func suspend() -> void:
	queued_lessons.clear()
	queued_ids.clear()
	active_lesson = {}
	active_context = {}
	latest_context = {}
	prepared_snapshot = {}
	active_layout_key = 0
	visible = false
	if focus_layer != null:
		focus_layer.set_snapshot({})
	_stop_attention_motion()


func input_allowed(action_id: String) -> bool:
	return CoachViewModelScript.input_allowed(prepared_snapshot, action_id)


func current_snapshot() -> Dictionary:
	var snapshot := prepared_snapshot.duplicate(true)
	snapshot["visible"] = visible and not active_lesson.is_empty()
	snapshot["queued_count"] = queued_lessons.size()
	return snapshot


func _build() -> void:
	focus_layer = FocusLayer.new()
	focus_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(focus_layer)
	panel = FoundationWidgets.panel_container(Color("#11101f", 0.98), VisualStyle.YELLOW)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)
	eyebrow_label = FoundationWidgets.label("DEALER'S ADVICE", 12)
	FoundationWidgets.set_control_font_color(eyebrow_label, VisualStyle.YELLOW)
	stack.add_child(eyebrow_label)
	copy_label = FoundationWidgets.label("", 15)
	copy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy_label.max_lines_visible = 3
	stack.add_child(copy_label)
	ok_button = FoundationWidgets.button("Got it", Callable(self, "_on_ok_pressed"))
	ok_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	stack.add_child(ok_button)


func _show_next() -> void:
	if queued_lessons.is_empty():
		active_lesson = {}
		active_context = {}
		prepared_snapshot = {}
		visible = false
		focus_layer.set_snapshot({})
		return
	var entry: Dictionary = queued_lessons.pop_front()
	active_lesson = _dict(entry.get("lesson", {})).duplicate(true)
	active_context = latest_context.duplicate(true) if not latest_context.is_empty() else _dict(entry.get("context", {})).duplicate(true)
	queued_ids.erase(str(active_lesson.get("id", "")))
	var lesson_id := str(active_lesson.get("id", ""))
	seen[lesson_id] = true
	lesson_seen.emit(lesson_id)
	_render_active(true)


func _render_active(play_motion: bool) -> void:
	if active_lesson.is_empty():
		return
	active_context["reduce_motion"] = reduce_motion
	active_context["small_screen"] = small_screen
	prepared_snapshot = CoachViewModelScript.build(active_lesson, active_context)
	active_layout_key = _layout_key(active_lesson, active_context)
	eyebrow_label.text = str(prepared_snapshot.get("eyebrow", "DEALER'S ADVICE"))
	copy_label.text = str(prepared_snapshot.get("copy", ""))
	ok_button.visible = str(prepared_snapshot.get("completion_type", "")) == "explicit_ok"
	ok_button.custom_minimum_size.y = float(prepared_snapshot.get("minimum_control_height", 40.0))
	var bubble_rect := CoachViewModelScript._rect(prepared_snapshot.get("bubble_rect", {}))
	panel.position = bubble_rect.position
	panel.size = bubble_rect.size
	panel.custom_minimum_size = bubble_rect.size
	focus_layer.set_snapshot(prepared_snapshot)
	visible = true
	move_to_front()
	if play_motion:
		_play_attention_motion()


func _finish_active() -> void:
	var completed_id := str(active_lesson.get("id", ""))
	active_lesson = {}
	active_context = {}
	prepared_snapshot = {}
	active_layout_key = 0
	visible = false
	focus_layer.set_snapshot({})
	_stop_attention_motion()
	if not completed_id.is_empty():
		lesson_completed.emit(completed_id)


func _on_ok_pressed() -> void:
	if notify_action("coach:ok"):
		_show_next()


func _play_attention_motion() -> void:
	_stop_attention_motion()
	panel.modulate = Color.WHITE
	if reduce_motion:
		return
	panel.modulate.a = 0.0
	attention_tween = create_tween()
	attention_tween.tween_property(panel, "modulate:a", 1.0, 0.12)


func _stop_attention_motion() -> void:
	if attention_tween != null and attention_tween.is_valid():
		attention_tween.kill()
	attention_tween = null
	if panel != null:
		panel.modulate = Color.WHITE


func _rebuild_queued_ids() -> void:
	queued_ids.clear()
	for entry_value in queued_lessons:
		var entry := _dict(entry_value)
		var lesson := _dict(entry.get("lesson", {}))
		queued_ids[str(lesson.get("id", ""))] = true


func _layout_key(lesson: Dictionary, context: Dictionary) -> int:
	var anchor := _dict(lesson.get("anchor", {}))
	var kind := str(anchor.get("kind", "none"))
	var anchor_id := str(anchor.get("id", ""))
	var group_name := {"interactable_object": "interactable_objects", "hud_element": "hud_elements", "surface_action": "surface_actions"}.get(kind, "")
	var anchor_rects := _dict(context.get("anchor_rects", {}))
	var group := _dict(anchor_rects.get(group_name, {}))
	return hash([
		str(context.get("screen", "")),
		str(context.get("environment_archetype", "")),
		str(context.get("game_id", "")),
		context.get("viewport_rect", Rect2()),
		group.get(anchor_id, Rect2()),
		bool(context.get("small_screen", false)),
		bool(context.get("reduce_motion", false)),
	])


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary) if typeof(value) == TYPE_DICTIONARY else {}
