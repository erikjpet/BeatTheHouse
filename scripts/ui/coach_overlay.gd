class_name CoachOverlay
extends Control

signal lesson_seen(lesson_id: String)
signal lesson_completed(lesson_id: String)
signal dialogue_requested(lesson_id: String, dialogue_id: String, dialogue_node: String)

const CoachViewModelScript := preload("res://scripts/ui/coach_view_model.gd")


class FocusLayer:
	extends Control

	const CoachFocusViewModelScript := preload("res://scripts/ui/coach_view_model.gd")

	var snapshot: Dictionary = {}
	var live_anchor_rect := Rect2()
	var live_anchor_rect_valid := false

	func set_snapshot(next_snapshot: Dictionary) -> void:
		snapshot = next_snapshot.duplicate(true)
		live_anchor_rect = Rect2()
		live_anchor_rect_valid = false
		queue_redraw()

	func set_live_anchor_rect(anchor_rect: Rect2) -> void:
		if live_anchor_rect_valid and live_anchor_rect.is_equal_approx(anchor_rect):
			return
		live_anchor_rect = anchor_rect
		live_anchor_rect_valid = true
		queue_redraw()

	func _draw() -> void:
		if snapshot.is_empty() or not bool(snapshot.get("visible", false)):
			return
		var anchor: Rect2 = live_anchor_rect if live_anchor_rect_valid else CoachFocusViewModelScript._rect(snapshot.get("anchor_rect", {}))
		if str(snapshot.get("anchor_kind", "none")) != "none" and not anchor.has_area():
			return
		if anchor.has_area():
			_draw_positive_focus(anchor)
		for rect_value in snapshot.get("additional_anchor_rects", []):
			var additional := CoachFocusViewModelScript._rect(rect_value)
			if additional.has_area():
				_draw_positive_focus(additional)

	func _draw_positive_focus(anchor: Rect2) -> void:
		draw_rect(anchor.grow(10.0), Color(VisualStyle.YELLOW, 0.16), false, 6.0)
		draw_rect(anchor.grow(5.0), Color(VisualStyle.YELLOW, 0.46), false, 3.0)
		draw_rect(anchor.grow(2.0), VisualStyle.YELLOW, false, 2.0)


var lessons: Array = []
var seen: Dictionary = {}
var queued_lessons: Array = []
var queued_ids: Dictionary = {}
var active_lesson: Dictionary = {}
var active_context: Dictionary = {}
var latest_context: Dictionary = {}
var prepared_snapshot: Dictionary = {}
var active_layout_key := 0
var live_anchor_rect := Rect2()
var live_anchor_rect_valid := false
var live_anchor_change_count := 0
var active_anchor_kind_value := ""
var active_anchor_id_value := ""
var active_dialogue_requested := false
var active_dialogue_was_requested := false
var active_dialogue_acknowledged := false
var tips_enabled := true
var reduce_motion := false
var small_screen := false
var focus_visual_enabled := true

var focus_layer: FocusLayer
var panel: Panel
var eyebrow_label: Label
var copy_label: Label
var ok_button: Button
var attention_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 90
	visible = false
	if panel == null:
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
	live_anchor_rect = Rect2()
	live_anchor_rect_valid = false
	live_anchor_change_count = 0
	active_anchor_kind_value = ""
	active_anchor_id_value = ""
	active_dialogue_requested = false
	active_dialogue_was_requested = false
	active_dialogue_acknowledged = false
	visible = false


func reset_seen() -> void:
	restore_seen({})


func set_tips_enabled(enabled: bool) -> void:
	tips_enabled = enabled
	if enabled:
		return
	suspend()


func begin_tutorial_run(completed_lessons: Dictionary = {}) -> void:
	for lesson_value in lessons:
		var lesson := _dict(lesson_value)
		if str(lesson.get("scope", "")).strip_edges() == "tutorial_run":
			var lesson_id := str(lesson.get("id", "")).strip_edges()
			if bool(completed_lessons.get(lesson_id, false)):
				seen[lesson_id] = true
			else:
				seen.erase(lesson_id)
	suspend()


func set_reduce_motion(enabled: bool) -> void:
	reduce_motion = enabled
	if enabled:
		_stop_attention_motion()
	if not prepared_snapshot.is_empty():
		active_context["reduce_motion"] = enabled
		_render_active(false)


func set_small_screen_mode(enabled: bool) -> void:
	small_screen = enabled
	if not prepared_snapshot.is_empty():
		active_context["small_screen"] = enabled
		_render_active(false)


# Modal surfaces may cover the world-space target while the tutorial dialogue
# deliberately remains readable. Hide only the visual focus layer in that case;
# lesson state and input behavior stay untouched.
func set_focus_visual_enabled(enabled: bool) -> void:
	focus_visual_enabled = enabled
	if focus_layer != null:
		focus_layer.visible = enabled


func evaluate_at_boundary(context: Dictionary) -> void:
	if panel == null:
		_build()
	var observed_context := context.duplicate(true)
	observed_context["reduce_motion"] = reduce_motion
	observed_context["small_screen"] = small_screen
	latest_context = observed_context
	if not active_lesson.is_empty():
		if CoachViewModelScript.state_completion_matches(active_lesson, observed_context):
			_finish_active()
		var next_layout_key := _layout_key(active_lesson, observed_context)
		if not active_lesson.is_empty() and next_layout_key != active_layout_key:
			active_context = observed_context.duplicate(true)
			_render_active(false)
	# A player can perform a state-based lesson before its dialogue becomes the
	# active queue head (or save/reload on the same boundary). Reconcile durable
	# outcomes before selecting the next lesson so already-achieved work never
	# leaves the dependency graph waiting for a transient trigger that has passed.
	_complete_satisfied_frontier_lessons(observed_context)
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
	# Exact predicates describe the ideal authored beat, but the tutorial must
	# survive an extra click, an early hand, a closed map, or a reload. If the
	# player is already on the lesson's surface, keep the real lesson active and
	# let its completion contract observe the eventual outcome. If they are on a
	# different surface, show a non-modal recovery step that guides them back.
	if active_lesson.is_empty() and queued_lessons.is_empty():
		_queue_frontier_guardrail(observed_context)
	if active_lesson.is_empty():
		_show_next()


func notify_action(action_id: String) -> bool:
	if active_lesson.is_empty() or not CoachViewModelScript.completion_matches(active_lesson, action_id):
		return false
	_finish_active()
	return true


func notify_dialogue_completed(lesson_id: String) -> bool:
	if active_lesson.is_empty() or str(active_lesson.get("id", "")) != lesson_id.strip_edges():
		return false
	active_dialogue_acknowledged = true
	var completion := _dict(active_lesson.get("completion", {}))
	if str(completion.get("type", "")) != "explicit_ok":
		return true
	_finish_active()
	return true


# Dialogue delivery is represented by a separate TalkDock queue entry. Travel,
# old-save cleanup, or malformed queue data can remove that entry without
# completing the coach lesson. Retry only an unacknowledged line; a player who
# already pressed Continue must not hear the same instruction again.
func reconcile_active_dialogue(pending: bool) -> bool:
	if active_lesson.is_empty() \
			or bool(active_lesson.get("runtime_recovery", false)) \
			or str(prepared_snapshot.get("delivery", "coach")) != "dialogue" \
			or not active_dialogue_was_requested \
			or active_dialogue_acknowledged \
			or pending:
		return false
	active_dialogue_requested = false
	_request_active_dialogue_once(false)
	return active_dialogue_requested


func suspend() -> void:
	queued_lessons.clear()
	queued_ids.clear()
	active_lesson = {}
	active_context = {}
	latest_context = {}
	prepared_snapshot = {}
	active_layout_key = 0
	live_anchor_rect = Rect2()
	live_anchor_rect_valid = false
	active_anchor_kind_value = ""
	active_anchor_id_value = ""
	active_dialogue_requested = false
	active_dialogue_was_requested = false
	active_dialogue_acknowledged = false
	visible = false
	if panel != null:
		panel.visible = false
	if focus_layer != null:
		focus_layer.set_snapshot({})
	_stop_attention_motion()


func input_allowed(action_id: String) -> bool:
	return CoachViewModelScript.input_allowed(prepared_snapshot, action_id)


func current_snapshot() -> Dictionary:
	var snapshot := prepared_snapshot.duplicate(true)
	if live_anchor_rect_valid:
		snapshot["anchor_rect"] = CoachViewModelScript._rect_dict(live_anchor_rect)
		snapshot["anchor_found"] = live_anchor_rect.has_area()
	snapshot["visible"] = visible and not active_lesson.is_empty()
	snapshot["queued_count"] = queued_lessons.size()
	snapshot["live_anchor_change_count"] = live_anchor_change_count
	return snapshot


func _build() -> void:
	focus_layer = FocusLayer.new()
	focus_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(focus_layer)
	panel = FoundationWidgets.panel(Color(VisualStyle.role("surface_overlay"), 0.98), VisualStyle.YELLOW)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.clip_contents = true
	add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", VisualStyle.SPACE_5)
	margin.add_theme_constant_override("margin_right", VisualStyle.SPACE_5)
	margin.add_theme_constant_override("margin_top", VisualStyle.SPACE_3)
	margin.add_theme_constant_override("margin_bottom", VisualStyle.SPACE_3)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", VisualStyle.SPACE_3)
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(stack)
	eyebrow_label = FoundationWidgets.label("DEALER'S ADVICE", VisualStyle.TYPE_SMALL)
	FoundationWidgets.set_control_font_color(eyebrow_label, VisualStyle.YELLOW)
	stack.add_child(eyebrow_label)
	copy_label = FoundationWidgets.label("", VisualStyle.TYPE_BODY_LARGE + VisualStyle.BORDER_HAIRLINE)
	copy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy_label.max_lines_visible = 4
	stack.add_child(copy_label)
	var action_spacer := Control.new()
	action_spacer.custom_minimum_size.y = float(VisualStyle.SPACE_4)
	action_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(action_spacer)
	ok_button = FoundationWidgets.button("Got it", Callable(self, "_on_ok_pressed"))
	ok_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	stack.add_child(ok_button)


func _show_next() -> void:
	if queued_lessons.is_empty():
		active_lesson = {}
		active_context = {}
		prepared_snapshot = {}
		visible = false
		if focus_layer != null:
			focus_layer.set_snapshot({})
		return
	var entry: Dictionary = queued_lessons.pop_front()
	active_lesson = _dict(entry.get("lesson", {})).duplicate(true)
	active_context = latest_context.duplicate(true) if not latest_context.is_empty() else _dict(entry.get("context", {})).duplicate(true)
	queued_ids.erase(str(active_lesson.get("id", "")))
	var lesson_id := str(active_lesson.get("id", ""))
	if str(active_lesson.get("scope", "")).strip_edges() != "tutorial_run":
		seen[lesson_id] = true
	lesson_seen.emit(lesson_id)
	active_dialogue_requested = false
	active_dialogue_was_requested = false
	active_dialogue_acknowledged = false
	_render_active(true)


func _render_active(play_motion: bool) -> void:
	if active_lesson.is_empty():
		return
	active_context["reduce_motion"] = reduce_motion
	active_context["small_screen"] = small_screen
	prepared_snapshot = CoachViewModelScript.build(active_lesson, active_context)
	live_anchor_rect = CoachViewModelScript._rect(prepared_snapshot.get("anchor_rect", {}))
	live_anchor_rect_valid = true
	active_anchor_kind_value = str(prepared_snapshot.get("anchor_kind", ""))
	active_anchor_id_value = str(prepared_snapshot.get("anchor_id", "")).strip_edges()
	active_layout_key = _layout_key(active_lesson, active_context)
	eyebrow_label.text = str(prepared_snapshot.get("eyebrow", "DEALER'S ADVICE"))
	copy_label.text = str(prepared_snapshot.get("copy", ""))
	ok_button.text = str(prepared_snapshot.get("dismiss_label", "Got it"))
	ok_button.visible = bool(prepared_snapshot.get("dismissible", true))
	ok_button.custom_minimum_size.y = float(prepared_snapshot.get("minimum_control_height", 40.0))
	var bubble_rect := CoachViewModelScript._rect(prepared_snapshot.get("bubble_rect", {}))
	panel.position = bubble_rect.position
	panel.custom_minimum_size = bubble_rect.size
	panel.size = bubble_rect.size
	focus_layer.set_snapshot(prepared_snapshot)
	focus_layer.visible = focus_visual_enabled
	var dialogue_delivery := str(prepared_snapshot.get("delivery", "coach")) == "dialogue"
	panel.visible = not dialogue_delivery
	visible = true
	move_to_front()
	_request_active_dialogue_once()
	if play_motion:
		_play_attention_motion()


func _finish_active() -> void:
	var completed_id := str(active_lesson.get("id", ""))
	var runtime_recovery := bool(active_lesson.get("runtime_recovery", false))
	if not completed_id.is_empty() and not runtime_recovery:
		seen[completed_id] = true
	active_lesson = {}
	active_context = {}
	prepared_snapshot = {}
	active_layout_key = 0
	live_anchor_rect = Rect2()
	live_anchor_rect_valid = false
	active_anchor_kind_value = ""
	active_anchor_id_value = ""
	active_dialogue_requested = false
	active_dialogue_was_requested = false
	active_dialogue_acknowledged = false
	visible = false
	if panel != null:
		panel.visible = false
	focus_layer.set_snapshot({})
	_stop_attention_motion()
	if not completed_id.is_empty() and not runtime_recovery:
		lesson_completed.emit(completed_id)


func active_anchor_kind() -> String:
	return active_anchor_kind_value


func active_lesson_id() -> String:
	return str(active_lesson.get("id", "")).strip_edges()


func active_anchor_id() -> String:
	return active_anchor_id_value


func active_anchor_rect() -> Rect2:
	if live_anchor_rect_valid:
		return live_anchor_rect
	return CoachViewModelScript._rect(prepared_snapshot.get("anchor_rect", {}))


# Moves only the active focus rectangle. Tutorial state, trigger evaluation,
# and the prepared guidance model remain unchanged during camera motion.
func update_active_anchor_rect(anchor_kind: String, anchor_id: String, next_rect: Rect2) -> bool:
	if active_lesson.is_empty() or anchor_kind != active_anchor_kind() or anchor_id != active_anchor_id():
		return false
	var clipped_rect := next_rect.intersection(Rect2(Vector2.ZERO, size)) if next_rect.has_area() else Rect2()
	if live_anchor_rect_valid and live_anchor_rect.is_equal_approx(clipped_rect):
		return false
	live_anchor_rect = clipped_rect
	live_anchor_rect_valid = true
	live_anchor_change_count += 1
	if focus_layer != null:
		focus_layer.set_live_anchor_rect(clipped_rect)
	_request_active_dialogue_once()
	return true


func _request_active_dialogue_once(require_anchor: bool = true) -> void:
	if active_dialogue_requested or active_lesson.is_empty():
		return
	if str(prepared_snapshot.get("delivery", "coach")) != "dialogue":
		return
	var anchor_kind := str(prepared_snapshot.get("anchor_kind", "none"))
	var anchor_found := live_anchor_rect.has_area() if live_anchor_rect_valid else bool(prepared_snapshot.get("anchor_found", false))
	if require_anchor and anchor_kind != "none" and not anchor_found:
		return
	active_dialogue_requested = true
	active_dialogue_was_requested = true
	dialogue_requested.emit(
		str(active_lesson.get("id", "")),
		str(active_lesson.get("dialogue_id", "")).strip_edges(),
		str(active_lesson.get("dialogue_node", "")).strip_edges()
	)


func _complete_satisfied_frontier_lessons(context: Dictionary) -> void:
	for _pass in range(lessons.size()):
		var completed_one := false
		for lesson_value in lessons:
			if typeof(lesson_value) != TYPE_DICTIONARY:
				continue
			var lesson: Dictionary = lesson_value
			var lesson_id := str(lesson.get("id", "")).strip_edges()
			if lesson_id.is_empty() \
					or bool(seen.get(lesson_id, false)) \
					or not _tutorial_frontier_ready(lesson, context) \
					or not CoachViewModelScript.state_completion_matches(lesson, context):
				continue
			seen[lesson_id] = true
			lesson_completed.emit(lesson_id)
			completed_one = true
			break
		if not completed_one:
			return


func _queue_frontier_guardrail(context: Dictionary) -> void:
	var frontier: Array = []
	for lesson_value in lessons:
		if typeof(lesson_value) != TYPE_DICTIONARY:
			continue
		var lesson: Dictionary = lesson_value
		var lesson_id := str(lesson.get("id", "")).strip_edges()
		if lesson_id.is_empty() \
				or bool(seen.get(lesson_id, false)) \
				or bool(lesson.get("optional", false)) \
				or not _tutorial_frontier_ready(lesson, context):
			continue
		frontier.append(lesson)
	if frontier.is_empty():
		return
	for lesson_value in frontier:
		var lesson: Dictionary = lesson_value
		if _trigger_surface_matches(lesson, context):
			_queue_lesson(lesson, context)
			return
	var recovery := _recovery_lesson(frontier[0], context)
	if not recovery.is_empty():
		_queue_lesson(recovery, context)


func _queue_lesson(lesson: Dictionary, context: Dictionary) -> void:
	var lesson_id := str(lesson.get("id", "")).strip_edges()
	if lesson_id.is_empty() or bool(queued_ids.get(lesson_id, false)):
		return
	queued_lessons.append({"lesson": lesson.duplicate(true), "context": context.duplicate(true)})
	queued_ids[lesson_id] = true


func _tutorial_frontier_ready(lesson: Dictionary, context: Dictionary) -> bool:
	if str(lesson.get("scope", "")).strip_edges() != "tutorial_run" or _path_value(context, "run.tutorial") != true:
		return false
	var trigger := _dict(lesson.get("trigger", {}))
	for dependency_id in _string_array(trigger.get("depends_on", [])):
		if not bool(seen.get(dependency_id, false)):
			return false
	# Challenge and meta-session predicates select separate tutorial graphs. They
	# are identities, not momentary gameplay state, and must never be recovered
	# across the wrong run type.
	for predicate_value in trigger.get("state_predicates", []):
		var predicate := _dict(predicate_value)
		var path := str(predicate.get("path", ""))
		if (path == "run.challenge_id" or path.begins_with("meta.")) \
				and not CoachViewModelScript._predicate_matches(predicate, context):
			return false
	return true


func _trigger_surface_matches(lesson: Dictionary, context: Dictionary) -> bool:
	var trigger := _dict(lesson.get("trigger", {}))
	for field in ["screen", "environment_kind", "environment_archetype", "game_id"]:
		var expected := str(trigger.get(field, "")).strip_edges()
		if not expected.is_empty() and str(_path_value(context, field)).strip_edges() != expected:
			return false
	return true


func _recovery_lesson(target: Dictionary, context: Dictionary) -> Dictionary:
	var trigger := _dict(target.get("trigger", {}))
	var current_screen := str(context.get("screen", ""))
	var current_environment := str(context.get("environment_archetype", ""))
	var expected_screen := str(trigger.get("screen", "ENVIRONMENT")).strip_edges()
	var expected_environment := str(trigger.get("environment_archetype", "")).strip_edges()
	var expected_game := str(trigger.get("game_id", "")).strip_edges()
	var anchor := {"kind": "none", "id": ""}
	var completion_predicates: Array = []
	var copy := "Pal's next lesson is still available."
	if current_screen == "GAME":
		anchor = {"kind": "surface_action", "id": "surface_back"}
		completion_predicates = [{"path": "screen", "op": "equals", "value": "ENVIRONMENT"}]
		copy = "Leave this table to return to Pal's next tutorial step."
	elif current_screen == "TRAVEL":
		if not expected_environment.is_empty():
			anchor = {"kind": "hud_element", "id": "travel:%s" % expected_environment}
			completion_predicates = [
				{"path": "screen", "op": "equals", "value": "ENVIRONMENT"},
				{"path": "environment_archetype", "op": "equals", "value": expected_environment},
			]
			copy = "Travel to %s to resume Pal's tutorial." % _friendly_id(expected_environment)
		else:
			completion_predicates = [{"path": "screen", "op": "not_equals", "value": "TRAVEL"}]
			copy = "Close the map to return to Pal's next tutorial step."
	else:
		if expected_screen == "TRAVEL" or (not expected_environment.is_empty() and expected_environment != current_environment):
			anchor = {"kind": "interactable_object", "id": "travel:leave"}
			completion_predicates = [{"path": "screen", "op": "equals", "value": "TRAVEL"}]
			copy = "Open the map to return to Pal's next tutorial step."
		elif expected_screen == "GAME" and not expected_game.is_empty():
			anchor = {"kind": "interactable_object", "id": "game:%s" % expected_game}
			completion_predicates = [
				{"path": "screen", "op": "equals", "value": "GAME"},
				{"path": "game_id", "op": "equals", "value": expected_game},
			]
			copy = "Return to %s to resume Pal's tutorial." % _friendly_id(expected_game)
	if completion_predicates.is_empty():
		return {}
	var target_id := str(target.get("id", "")).strip_edges()
	return {
		"id": "tutorial_recovery:%s" % target_id,
		"scope": "tutorial_run",
		"runtime_recovery": true,
		"recovery_target_lesson_id": target_id,
		"delivery": "coach",
		"anchor": anchor,
		"copy": copy,
		"completion": {"type": "state_predicate", "state_predicates": completion_predicates},
		"gating": {"allowed_action_ids": []},
	}


func _friendly_id(value: String) -> String:
	return value.replace("_", " ").capitalize()


func _path_value(source: Dictionary, path: String) -> Variant:
	var current: Variant = source
	for segment in path.split(".", false):
		if typeof(current) != TYPE_DICTIONARY:
			return null
		current = (current as Dictionary).get(segment)
	return current


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value:
		var entry := str(entry_value).strip_edges()
		if not entry.is_empty() and not result.has(entry):
			result.append(entry)
	return result


func _on_ok_pressed() -> void:
	if active_lesson.is_empty():
		return
	_finish_active()
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
	var anchor := CoachViewModelScript.resolved_anchor(lesson, context)
	var kind := str(anchor.get("kind", "none"))
	var anchor_id := str(anchor.get("id", ""))
	var group_name: String = str({"interactable_object": "interactable_objects", "hud_element": "hud_elements", "surface_action": "surface_actions"}.get(kind, ""))
	var anchor_rects := _dict(context.get("anchor_rects", {}))
	var group := _dict(anchor_rects.get(group_name, {}))
	return hash([
		str(context.get("screen", "")),
		str(context.get("environment_archetype", "")),
		str(context.get("game_id", "")),
		kind,
		anchor_id,
		context.get("viewport_rect", Rect2()),
		group.get(anchor_id, Rect2()),
		bool(context.get("small_screen", false)),
		bool(context.get("reduce_motion", false)),
	])


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary) if typeof(value) == TYPE_DICTIONARY else {}
