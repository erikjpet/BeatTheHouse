class_name CoachViewModel
extends RefCounted

const ANCHOR_KINDS := ["interactable_object", "hud_element", "surface_action", "none"]
const COMPLETION_TYPES := ["anchored_action", "any_action", "explicit_ok"]
const VIEWPORT_MARGIN := 12.0


static func trigger_matches(lesson: Dictionary, context: Dictionary, seen: Dictionary, tips_enabled: bool = true) -> bool:
	var lesson_id := str(lesson.get("id", "")).strip_edges()
	if lesson_id.is_empty() or bool(seen.get(lesson_id, false)):
		return false
	if not tips_enabled:
		return false
	var tutorial_context: bool = _path_value(context, "run.tutorial") == true
	var tutorial_lesson := str(lesson.get("scope", "")).strip_edges() == "tutorial_run"
	if tutorial_context != tutorial_lesson:
		return false
	var trigger := _dict(lesson.get("trigger", {}))
	if trigger.is_empty():
		return false
	for dependency_id in _string_array(trigger.get("depends_on", [])):
		if not bool(seen.get(dependency_id, false)):
			return false
	for field in ["screen", "environment_kind", "environment_archetype", "game_id"]:
		var expected := str(trigger.get(field, "")).strip_edges()
		if not expected.is_empty() and str(_path_value(context, field)).strip_edges() != expected:
			return false
	var predicates: Variant = trigger.get("state_predicates", [])
	if typeof(predicates) != TYPE_ARRAY:
		return false
	for predicate_value in predicates:
		if typeof(predicate_value) != TYPE_DICTIONARY or not _predicate_matches(predicate_value, context):
			return false
	return true


static func build(lesson: Dictionary, context: Dictionary) -> Dictionary:
	if lesson.is_empty():
		return {}
	var viewport_rect := _rect(context.get("viewport_rect", Rect2(Vector2.ZERO, Vector2(1280, 720))))
	if viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
		viewport_rect = Rect2(Vector2.ZERO, Vector2(1280, 720))
	var anchor := _dict(lesson.get("anchor", {}))
	var anchor_kind := str(anchor.get("kind", "none"))
	if not ANCHOR_KINDS.has(anchor_kind):
		anchor_kind = "none"
	var anchor_id := str(anchor.get("id", "")).strip_edges()
	var anchor_rect := _anchor_rect(anchor_kind, anchor_id, context)
	var small_screen := bool(context.get("small_screen", false))
	var completion := _dict(lesson.get("completion", {}))
	var completion_type := str(completion.get("type", "any_action"))
	if not COMPLETION_TYPES.has(completion_type):
		completion_type = "any_action"
	var bubble_width := minf(viewport_rect.size.x - VIEWPORT_MARGIN * 2.0, 420.0 if small_screen else 360.0)
	var bubble_height := 148.0 if completion_type == "explicit_ok" else 112.0
	if small_screen:
		bubble_height += 14.0
	var bubble_size := Vector2(maxf(240.0, bubble_width), minf(bubble_height, viewport_rect.size.y - VIEWPORT_MARGIN * 2.0))
	var bubble_rect := _bubble_rect(viewport_rect, anchor_rect, bubble_size)
	var gating := _dict(lesson.get("gating", {}))
	return {
		"visible": true,
		"lesson_id": str(lesson.get("id", "")),
		"voice": "dealer_advice",
		"eyebrow": "DEALER'S ADVICE",
		"copy": str(lesson.get("copy", "")),
		"anchor_kind": anchor_kind,
		"anchor_id": anchor_id,
		"anchor_found": anchor_kind == "none" or anchor_rect.has_area(),
		"anchor_rect": _rect_dict(anchor_rect),
		"bubble_rect": _rect_dict(bubble_rect),
		"viewport_rect": _rect_dict(viewport_rect),
		"completion_type": completion_type,
		"gating": not gating.is_empty(),
		"allowed_action_ids": _string_array(gating.get("allowed_action_ids", [])),
		"reduce_motion": bool(context.get("reduce_motion", false)),
		"small_screen": small_screen,
		"minimum_control_height": 52.0 if small_screen else 40.0,
	}


static func input_allowed(snapshot: Dictionary, action_id: String) -> bool:
	if snapshot.is_empty() or not bool(snapshot.get("gating", false)):
		return true
	var normalized := action_id.strip_edges()
	var allowed := _string_array(snapshot.get("allowed_action_ids", []))
	return allowed.has("*") or (not normalized.is_empty() and allowed.has(normalized))


static func completion_matches(lesson: Dictionary, action_id: String) -> bool:
	var completion := _dict(lesson.get("completion", {}))
	match str(completion.get("type", "any_action")):
		"any_action":
			return not action_id.strip_edges().is_empty()
		"anchored_action":
			var expected := str(completion.get("action_id", "")).strip_edges()
			if expected.is_empty():
				expected = str(_dict(lesson.get("anchor", {})).get("id", "")).strip_edges()
			return not expected.is_empty() and expected == action_id.strip_edges()
		"explicit_ok":
			return action_id == "coach:ok"
	return false


static func _predicate_matches(predicate: Dictionary, context: Dictionary) -> bool:
	var actual: Variant = _path_value(context, str(predicate.get("path", "")))
	var expected: Variant = predicate.get("value")
	match str(predicate.get("op", "equals")).to_lower():
		"not_equals":
			return actual != expected
		"gt":
			return _number(actual) > _number(expected)
		"gte":
			return _number(actual) >= _number(expected)
		"lt":
			return _number(actual) < _number(expected)
		"lte":
			return _number(actual) <= _number(expected)
		"truthy":
			return bool(actual)
		"one_of":
			return typeof(expected) == TYPE_ARRAY and (expected as Array).has(actual)
		_:
			return actual == expected


static func _path_value(source: Dictionary, path: String) -> Variant:
	var current: Variant = source
	for segment in path.split(".", false):
		if typeof(current) != TYPE_DICTIONARY:
			return null
		current = (current as Dictionary).get(segment)
	return current


static func _anchor_rect(kind: String, anchor_id: String, context: Dictionary) -> Rect2:
	if kind == "none":
		return Rect2()
	var anchor_rects := _dict(context.get("anchor_rects", {}))
	var group_name: String = str({
		"interactable_object": "interactable_objects",
		"hud_element": "hud_elements",
		"surface_action": "surface_actions",
	}.get(kind, ""))
	var group := _dict(anchor_rects.get(group_name, {}))
	return _rect(group.get(anchor_id, Rect2()))


static func _bubble_rect(viewport_rect: Rect2, anchor_rect: Rect2, bubble_size: Vector2) -> Rect2:
	var position := viewport_rect.get_center() - bubble_size * 0.5
	if anchor_rect.has_area():
		var below_y := anchor_rect.end.y + 10.0
		var above_y := anchor_rect.position.y - bubble_size.y - 10.0
		if below_y + bubble_size.y <= viewport_rect.end.y - VIEWPORT_MARGIN:
			position = Vector2(anchor_rect.get_center().x - bubble_size.x * 0.5, below_y)
		elif above_y >= viewport_rect.position.y + VIEWPORT_MARGIN:
			position = Vector2(anchor_rect.get_center().x - bubble_size.x * 0.5, above_y)
		else:
			position = Vector2(anchor_rect.end.x + 10.0, anchor_rect.get_center().y - bubble_size.y * 0.5)
	position.x = clampf(position.x, viewport_rect.position.x + VIEWPORT_MARGIN, viewport_rect.end.x - bubble_size.x - VIEWPORT_MARGIN)
	position.y = clampf(position.y, viewport_rect.position.y + VIEWPORT_MARGIN, viewport_rect.end.y - bubble_size.y - VIEWPORT_MARGIN)
	return Rect2(position, bubble_size)


static func _rect(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = value
	return Rect2(
		Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))),
		Vector2(float(data.get("w", data.get("width", 0.0))), float(data.get("h", data.get("height", 0.0))))
	)


static func _rect_dict(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y}


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary) if typeof(value) == TYPE_DICTIONARY else {}


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value:
		var entry := str(entry_value).strip_edges()
		if not entry.is_empty() and not result.has(entry):
			result.append(entry)
	return result


static func _number(value: Variant) -> float:
	return float(value) if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT else 0.0
