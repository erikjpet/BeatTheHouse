class_name CoachViewModel
extends RefCounted

const ANCHOR_KINDS := ["interactable_object", "hud_element", "surface_action", "none"]
const COMPLETION_TYPES := ["anchored_action", "one_of_actions", "any_action", "explicit_ok", "state_predicate"]
const VIEWPORT_MARGIN := 12.0


static func trigger_matches(lesson: Dictionary, context: Dictionary, seen: Dictionary, tips_enabled: bool = true) -> bool:
	var lesson_id := str(lesson.get("id", "")).strip_edges()
	if lesson_id.is_empty() or bool(seen.get(lesson_id, false)):
		return false
	var tutorial_context: bool = _path_value(context, "run.tutorial") == true
	var tutorial_lesson := str(lesson.get("scope", "")).strip_edges() == "tutorial_run"
	if tutorial_context != tutorial_lesson:
		return false
	# The guided run is binding even when the profile's ambient-tip preference is
	# off. That preference only controls normal-run Dealer's Advice lessons.
	if not tutorial_lesson and not tips_enabled:
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
	# Guided highlights must be evaluated on the surface that can actually draw
	# their target. This is a runtime backstop for authored data and prevents a
	# room object lesson from opening over a table, map, or other covered view.
	if tutorial_lesson and not _tutorial_anchor_screen_matches(lesson, context):
		return false
	var predicates: Variant = trigger.get("state_predicates", [])
	if typeof(predicates) != TYPE_ARRAY:
		return false
	for predicate_value in predicates:
		if typeof(predicate_value) != TYPE_DICTIONARY or not _predicate_matches(predicate_value, context):
			return false
	return true


static func _tutorial_anchor_screen_matches(lesson: Dictionary, context: Dictionary) -> bool:
	var trigger := _dict(lesson.get("trigger", {}))
	var anchor := _dict(lesson.get("anchor", {}))
	var anchor_kind := str(anchor.get("kind", "")).strip_edges()
	var anchor_id := str(anchor.get("id", "")).strip_edges()
	var expected_screen := ""
	match anchor_kind:
		"interactable_object":
			expected_screen = "ENVIRONMENT"
		"surface_action":
			expected_screen = "GAME"
		"hud_element":
			if anchor_id.begins_with("travel:"):
				expected_screen = "TRAVEL"
			elif not str(trigger.get("game_id", "")).strip_edges().is_empty():
				expected_screen = "GAME"
			else:
				expected_screen = "ENVIRONMENT"
		"none":
			return true
		_:
			return false
	return str(context.get("screen", "")).strip_edges() == expected_screen


static func build(lesson: Dictionary, context: Dictionary) -> Dictionary:
	if lesson.is_empty():
		return {}
	var viewport_rect := _rect(context.get("viewport_rect", Rect2(Vector2.ZERO, Vector2(1280, 720))))
	if viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
		viewport_rect = Rect2(Vector2.ZERO, Vector2(1280, 720))
	var anchor := resolved_anchor(lesson, context)
	var anchor_kind := str(anchor.get("kind", "none"))
	if not ANCHOR_KINDS.has(anchor_kind):
		anchor_kind = "none"
	var anchor_id := str(anchor.get("id", "")).strip_edges()
	var anchor_rect := _anchor_rect(anchor_kind, anchor_id, context)
	var tutorial_lesson := str(lesson.get("scope", "")).strip_edges() == "tutorial_run"
	if anchor_rect.has_area():
		anchor_rect = anchor_rect.intersection(viewport_rect)
	var additional_anchor_rects: Array = []
	for additional_id in _string_array(lesson.get("additional_anchor_ids", [])):
		var additional_rect := _anchor_rect(anchor_kind, additional_id, context)
		if additional_rect.has_area():
			additional_anchor_rects.append(_rect_dict(additional_rect.intersection(viewport_rect)))
	var small_screen := bool(context.get("small_screen", false))
	var completion := _dict(lesson.get("completion", {}))
	var completion_type := str(completion.get("type", "any_action"))
	if not COMPLETION_TYPES.has(completion_type):
		completion_type = "any_action"
	var available_width := maxf(1.0, viewport_rect.size.x - VIEWPORT_MARGIN * 2.0)
	var preferred_width := 420.0 if small_screen else 384.0
	var bubble_width := minf(available_width, preferred_width)
	var bubble_height := 172.0 if completion_type == "explicit_ok" else 144.0
	if small_screen:
		bubble_height += 14.0
	var bubble_size := Vector2(
		maxf(1.0, bubble_width),
		minf(bubble_height, maxf(1.0, viewport_rect.size.y - VIEWPORT_MARGIN * 2.0))
	)
	var bubble_rect := _bubble_rect(viewport_rect, anchor_rect, bubble_size)
	if not tutorial_lesson:
		bubble_rect = _bubble_rect_avoiding_context(viewport_rect, bubble_rect, bubble_size, context)
	var guidance := _dict(lesson.get("gating", {}))
	var suggested_action_ids := _string_array(guidance.get("allowed_action_ids", []))
	var delivery := str(lesson.get("delivery", "coach")).strip_edges().to_lower()
	if not ["coach", "dialogue"].has(delivery):
		delivery = "coach"
	return {
		"visible": true,
		"lesson_id": str(lesson.get("id", "")),
		"voice": "pal" if tutorial_lesson else "dealer_advice",
		"eyebrow": "PAL'S POINTER" if tutorial_lesson else "DEALER'S ADVICE",
		"copy": str(lesson.get("copy", "")),
		"anchor_kind": anchor_kind,
		"anchor_id": anchor_id,
		"anchor_found": anchor_kind == "none" or anchor_rect.has_area(),
		"anchor_rect": _rect_dict(anchor_rect),
		"additional_anchor_rects": additional_anchor_rects,
		"bubble_rect": _rect_dict(bubble_rect),
		"viewport_rect": _rect_dict(viewport_rect),
		"completion_type": completion_type,
		"delivery": delivery,
		"dialogue_id": str(lesson.get("dialogue_id", "")).strip_edges(),
		"dialogue_node": str(lesson.get("dialogue_node", "")).strip_edges(),
		"dismissible": true,
		"dismiss_action_id": "coach:ok" if completion_type == "explicit_ok" else "coach:skip",
		"dismiss_label": "Got it" if completion_type == "explicit_ok" else "Skip tip",
		"gating": false,
		"highlight_emphasis": not guidance.is_empty(),
		"allowed_action_ids": suggested_action_ids,
		"suggested_action_ids": suggested_action_ids,
		"reduce_motion": bool(context.get("reduce_motion", false)),
		"small_screen": small_screen,
		"minimum_control_height": 52.0 if small_screen else 40.0,
	}


# A lesson may follow a short interaction loop without becoming a chain of
# repetitive popups. The first matching variant owns the highlight; the base
# anchor remains the fallback. Variants are presentation-only and are evaluated
# at the same explicit UI boundaries as the rest of the coach model.
static func resolved_anchor(lesson: Dictionary, context: Dictionary) -> Dictionary:
	var fallback := _dict(lesson.get("anchor", {}))
	var variants: Variant = lesson.get("anchor_variants", [])
	if typeof(variants) != TYPE_ARRAY:
		return fallback
	for variant_value in variants:
		if typeof(variant_value) != TYPE_DICTIONARY:
			continue
		var variant: Dictionary = variant_value
		var predicates: Variant = variant.get("state_predicates", [])
		if typeof(predicates) != TYPE_ARRAY or (predicates as Array).is_empty():
			continue
		var matches := true
		for predicate_value in predicates:
			if typeof(predicate_value) != TYPE_DICTIONARY or not _predicate_matches(predicate_value, context):
				matches = false
				break
		if matches:
			var candidate := _dict(variant.get("anchor", {}))
			if not candidate.is_empty():
				return candidate
	return fallback


static func input_allowed(_snapshot: Dictionary, _action_id: String) -> bool:
	# Tutorial guidance is advisory. Retain this compatibility method for callers
	# and tests, but never turn a highlight into an input permission boundary.
	return true


static func completion_matches(lesson: Dictionary, action_id: String) -> bool:
	if action_id == "coach:skip":
		return true
	var completion := _dict(lesson.get("completion", {}))
	match str(completion.get("type", "any_action")):
		"any_action":
			return not action_id.strip_edges().is_empty()
		"one_of_actions":
			return _string_array(completion.get("action_ids", [])).has(action_id.strip_edges())
		"anchored_action":
			var expected := str(completion.get("action_id", "")).strip_edges()
			if expected.is_empty():
				expected = str(_dict(lesson.get("anchor", {})).get("id", "")).strip_edges()
			return not expected.is_empty() and expected == action_id.strip_edges()
		"explicit_ok":
			return action_id == "coach:ok"
		"state_predicate":
			return false
	return false


static func state_completion_matches(lesson: Dictionary, context: Dictionary) -> bool:
	var completion := _dict(lesson.get("completion", {}))
	if str(completion.get("type", "")) != "state_predicate":
		return false
	var predicates: Variant = completion.get("state_predicates", [])
	if typeof(predicates) != TYPE_ARRAY or (predicates as Array).is_empty():
		return false
	for predicate_value in predicates:
		if typeof(predicate_value) != TYPE_DICTIONARY or not _predicate_matches(predicate_value, context):
			return false
	return true


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
	const ANCHOR_GAP := 24.0
	var position := viewport_rect.get_center() - bubble_size * 0.5
	if anchor_rect.has_area():
		var below_y := anchor_rect.end.y + ANCHOR_GAP
		var above_y := anchor_rect.position.y - bubble_size.y - ANCHOR_GAP
		if below_y + bubble_size.y <= viewport_rect.end.y - VIEWPORT_MARGIN:
			position = Vector2(anchor_rect.get_center().x - bubble_size.x * 0.5, below_y)
		elif above_y >= viewport_rect.position.y + VIEWPORT_MARGIN:
			position = Vector2(anchor_rect.get_center().x - bubble_size.x * 0.5, above_y)
		else:
			position = Vector2(anchor_rect.end.x + ANCHOR_GAP, anchor_rect.get_center().y - bubble_size.y * 0.5)
	position.x = clampf(position.x, viewport_rect.position.x + VIEWPORT_MARGIN, viewport_rect.end.x - bubble_size.x - VIEWPORT_MARGIN)
	position.y = clampf(position.y, viewport_rect.position.y + VIEWPORT_MARGIN, viewport_rect.end.y - bubble_size.y - VIEWPORT_MARGIN)
	return Rect2(position, bubble_size)


# Ambient advice keeps its one intentional pointer receiver (Skip tip) while
# choosing the least-contended standard placement from public UI geometry. The
# choice is pure and deterministic; guided tutorial placement remains authored.
static func _bubble_rect_avoiding_context(viewport_rect: Rect2, preferred: Rect2, bubble_size: Vector2, context: Dictionary) -> Rect2:
	var targets: Array[Rect2] = []
	var anchor_rects := _dict(context.get("anchor_rects", {}))
	for group_name in ["interactable_objects", "hud_elements", "surface_actions"]:
		for rect_value in _dict(anchor_rects.get(group_name, {})).values():
			var target := _rect(rect_value)
			if target.has_area():
				targets.append(target)
	if targets.is_empty():
		return preferred
	var left := viewport_rect.position.x + VIEWPORT_MARGIN
	var top := viewport_rect.position.y + VIEWPORT_MARGIN
	var right := viewport_rect.end.x - bubble_size.x - VIEWPORT_MARGIN
	var bottom := viewport_rect.end.y - bubble_size.y - VIEWPORT_MARGIN
	var center := viewport_rect.get_center() - bubble_size * 0.5
	var candidates: Array[Rect2] = [
		preferred,
		Rect2(Vector2(left, top), bubble_size),
		Rect2(Vector2(right, top), bubble_size),
		Rect2(Vector2(left, bottom), bubble_size),
		Rect2(Vector2(right, bottom), bubble_size),
		Rect2(Vector2(center.x, top), bubble_size),
		Rect2(Vector2(center.x, bottom), bubble_size),
		Rect2(Vector2(left, center.y), bubble_size),
		Rect2(Vector2(right, center.y), bubble_size),
	]
	var best := preferred
	var best_overlap := _bubble_target_overlap(preferred, targets)
	for candidate in candidates:
		var overlap := _bubble_target_overlap(candidate, targets)
		if overlap < best_overlap:
			best = candidate
			best_overlap = overlap
	return best


static func _bubble_target_overlap(bubble: Rect2, targets: Array[Rect2]) -> float:
	var overlap := 0.0
	for target in targets:
		if bubble.intersects(target):
			overlap += bubble.intersection(target).get_area()
	return overlap


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
