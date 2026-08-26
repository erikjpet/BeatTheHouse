class_name ScenarioLayoutResolver
extends RefCounted

const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")

const BOARD_SIZE := Vector2(900.0, 430.0)
const SMALL_SCREEN_TARGET := Vector2(104.0, 76.0)
const MAX_LABEL_LENGTH := 48
const ZONE_CENTERS := {
	"left": Vector2(180.0, 232.0),
	"right": Vector2(720.0, 232.0),
	"center": Vector2(450.0, 220.0),
	"foreground": Vector2(450.0, 342.0),
	"background": Vector2(450.0, 112.0),
	"exit_lane": Vector2(820.0, 342.0),
	"service_lane": Vector2(132.0, 250.0),
}
const ANCHOR_FIELDS := {
	"game": "game_spots",
	"event": "event_spots",
	"item": "item_spots",
	"service": "service_spots",
	"lender": "lender_spots",
	"travel": "travel_spots",
	"shopkeeper": "shopkeeper_spots",
	"game_hook": "game_hook_spots",
}


static func prepare(environment: Dictionary, projection: Dictionary) -> Dictionary:
	if projection.is_empty():
		return {}
	var semantic := _dict(projection.get("semantic_state", {}))
	var errors: Array = []
	var warnings: Array = []
	var visuals: Array = []
	var interaction_overlays: Array = []
	var visual_identities: Dictionary = {}
	var occupied: Array = []
	var exit_lane := Rect2(Vector2(764.0, 286.0), Vector2(136.0, 144.0))

	for value in _ordered_values(_dict(semantic.get("scene_objects", {}))):
		var scene := _dict(value)
		var identity := OperationRegistryScript.identity_from(scene)
		var visual := _prepare_visual(environment, scene, false, errors)
		if visual.is_empty():
			continue
		visual_identities[identity] = visual.duplicate(true)
		visuals.append(visual)
		_validate_placement(identity, visual, occupied, exit_lane, errors, warnings)

	for value in _ordered_values(_dict(semantic.get("actors", {}))):
		var actor := _dict(value)
		var identity := OperationRegistryScript.identity_from(actor)
		var visual := _prepare_visual(environment, actor, true, errors)
		if visual.is_empty():
			continue
		visual_identities[identity] = visual.duplicate(true)
		visuals.append(visual)
		_validate_placement(identity, visual, occupied, exit_lane, errors, warnings)

	var has_safe_exit := false
	for value in _ordered_values(_dict(semantic.get("interactions", {}))):
		var interaction := _dict(value)
		interaction_overlays.append(interaction)
		var identity := OperationRegistryScript.identity_from(interaction)
		var mode := str(interaction.get("mode", "add"))
		if mode in ["add", "replace"]:
			var minimum := maxf(OperationRegistryScript.MIN_TARGET_SIZE, float(interaction.get("min_target_size", 0.0)))
			var bounds := _dict(interaction.get("hit_bounds", {}))
			if float(bounds.get("w", 0.0)) < minimum or float(bounds.get("h", 0.0)) < minimum:
				errors.append("scenario interaction %s has a hit target below %.0f pixels." % [identity, minimum])
			if not visual_identities.has(identity):
				errors.append("scenario interaction %s has no rendered scene object or actor." % identity)
		if bool(interaction.get("enabled", false)) and bool(interaction.get("safe_exit", false)):
			has_safe_exit = true

	for visual_value in visuals:
		var visual := _dict(visual_value)
		if str(visual.get("role", "")) == "obstacle" and bool(visual.get("visible", true)) and bool(visual.get("enabled", true)):
			var pixels := _pixel_rect(_dict(visual.get("normalized_rect", {})))
			if pixels.intersects(exit_lane) and not has_safe_exit:
				errors.append("scenario obstacle %s blocks the exit lane without an enabled safe-exit interaction." % str(visual.get("semantic_identity", "")))

	visuals.sort_custom(Callable(ScenarioLayoutResolver, "_sort_visuals"))
	return {
		"schema_version": 1,
		"scenario_id": str(projection.get("scenario_id", "")),
		"phase_id": str(projection.get("phase_id", "")),
		"status": str(projection.get("status", "")),
		"ok": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"visual_objects": visuals,
		"interaction_overlays": interaction_overlays,
		"services": _ordered_values(_dict(semantic.get("services", {}))),
		"games": _ordered_values(_dict(semantic.get("games", {}))),
		"routes": _ordered_values(_dict(semantic.get("routes", {}))),
		"layout_audit": {
			"board_size": {"x": BOARD_SIZE.x, "y": BOARD_SIZE.y},
			"minimum_target_size": OperationRegistryScript.MIN_TARGET_SIZE,
			"small_screen_target": {"x": SMALL_SCREEN_TARGET.x, "y": SMALL_SCREEN_TARGET.y},
			"visual_count": visuals.size(),
			"interaction_count": interaction_overlays.size(),
			"safe_exit_present": has_safe_exit,
		},
	}


static func _prepare_visual(environment: Dictionary, semantic: Dictionary, actor: bool, errors: Array) -> Dictionary:
	var identity := OperationRegistryScript.identity_from(semantic)
	var label := str(semantic.get("label", "")).strip_edges()
	if identity == "::":
		errors.append("scenario visual is missing its stable owner identity.")
		return {}
	if label.is_empty():
		errors.append("scenario visual %s is missing its accessible label." % identity)
		return {}
	if label.length() > MAX_LABEL_LENGTH:
		errors.append("scenario visual %s label exceeds %d characters." % [identity, MAX_LABEL_LENGTH])
	var center := _resolve_center(environment, str(semantic.get("anchor_id", "")), str(semantic.get("zone_id", "")))
	if center.x < 0.0:
		errors.append("scenario visual %s references an unresolved anchor or zone." % identity)
		return {}
	var bounds := _dict(semantic.get("bounds", {}))
	var size := Vector2(float(bounds.get("w", 72.0 if actor else 48.0)), float(bounds.get("h", 80.0 if actor else 48.0)))
	size.x = maxf(size.x, 16.0)
	size.y = maxf(size.y, 16.0)
	var pixels := Rect2(center - size * 0.5, size)
	var owner := str(semantic.get("owner_namespace", ""))
	var stable_id := str(semantic.get("stable_object_id", ""))
	return {
		"object_id": "scenario:%s:%s" % [owner, stable_id],
		"object_type": "scenario_actor" if actor else "scenario_object",
		"visual_type": "scenario_actor" if actor else "scenario_object",
		"source_id": str(semantic.get("actor_id", stable_id)),
		"label": label,
		"short_description": _visual_description(semantic, actor),
		"presence": "scenario",
		"interactive": false,
		"decorative": true,
		"enabled": bool(semantic.get("enabled", true)),
		"visible": bool(semantic.get("visible", true)),
		"disabled_reason": str(semantic.get("disabled_reason", "")),
		"normalized_rect": _normalized_rect(pixels),
		"focus_rect": _normalized_rect(pixels),
		"owner_namespace": owner,
		"stable_object_id": stable_id,
		"semantic_identity": identity,
		"role": str(semantic.get("role", "actor" if actor else "prop")),
		"state": str(semantic.get("state", "")),
		"appearance": str(semantic.get("appearance", "")),
		"pose": str(semantic.get("pose", "idle")),
		"behavior": str(semantic.get("behavior", "idle")),
		"route_id": str(semantic.get("route_id", "")),
		"non_color_state": _non_color_state(semantic, actor),
		"z_order": int(round(center.y)) + (20 if actor else 0),
	}


static func _resolve_center(environment: Dictionary, anchor_id: String, zone_id: String) -> Vector2:
	if not anchor_id.strip_edges().is_empty():
		var parts := anchor_id.split(":", false)
		if parts.size() == 3 and str(parts[0]) == "layout" and ANCHOR_FIELDS.has(str(parts[1])) and str(parts[2]).is_valid_int():
			var spots := _array(_dict(environment.get("layout", {})).get(str(ANCHOR_FIELDS.get(str(parts[1]), "")), []))
			var index := int(parts[2])
			if index >= 0 and index < spots.size():
				return _point(spots[index])
	if ZONE_CENTERS.has(zone_id):
		return ZONE_CENTERS.get(zone_id, Vector2(-1.0, -1.0))
	return Vector2(-1.0, -1.0)


static func _validate_placement(identity: String, visual: Dictionary, occupied: Array, exit_lane: Rect2, errors: Array, warnings: Array) -> void:
	var rect := _pixel_rect(_dict(visual.get("normalized_rect", {})))
	if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > BOARD_SIZE.x or rect.end.y > BOARD_SIZE.y:
		errors.append("scenario visual %s is outside the 900x430 room board." % identity)
	for occupied_value in occupied:
		var prior := _dict(occupied_value)
		var prior_rect := _pixel_rect(_dict(prior.get("rect", {})))
		if rect.intersection(prior_rect).get_area() > minf(rect.get_area(), prior_rect.get_area()) * 0.65:
			warnings.append("scenario visuals %s and %s substantially overlap; deterministic depth order is applied." % [str(prior.get("identity", "")), identity])
	occupied.append({"identity": identity, "rect": _normalized_rect(rect)})
	if str(visual.get("role", "")) == "exit" and not rect.intersects(exit_lane):
		warnings.append("scenario exit visual %s is outside the authored exit lane." % identity)


static func _visual_description(value: Dictionary, actor: bool) -> String:
	var parts: Array[String] = []
	if actor:
		parts.append(str(value.get("behavior", "idle")).replace("_", " "))
		parts.append(str(value.get("pose", "idle")).replace("_", " "))
	else:
		parts.append(str(value.get("role", "object")).replace("_", " "))
		if not str(value.get("state", "")).is_empty(): parts.append(str(value.get("state", "")).replace("_", " "))
	return ", ".join(parts).capitalize()


static func _non_color_state(value: Dictionary, actor: bool) -> String:
	if actor:
		return "%s; %s" % [str(value.get("behavior", "idle")).replace("_", " "), str(value.get("pose", "idle")).replace("_", " ")]
	var state := str(value.get("state", "present")).replace("_", " ")
	var appearance := str(value.get("appearance", "")).replace("_", " ")
	return state if appearance.is_empty() else "%s; %s" % [state, appearance]


static func _normalized_rect(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x / BOARD_SIZE.x, "y": rect.position.y / BOARD_SIZE.y, "w": rect.size.x / BOARD_SIZE.x, "h": rect.size.y / BOARD_SIZE.y}


static func _pixel_rect(value: Dictionary) -> Rect2:
	return Rect2(float(value.get("x", 0.0)) * BOARD_SIZE.x, float(value.get("y", 0.0)) * BOARD_SIZE.y, float(value.get("w", 0.0)) * BOARD_SIZE.x, float(value.get("h", 0.0)) * BOARD_SIZE.y)


static func _point(value: Variant) -> Vector2:
	if typeof(value) == TYPE_VECTOR2: return value
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2: return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	if typeof(value) == TYPE_DICTIONARY: return Vector2(float((value as Dictionary).get("x", -1.0)), float((value as Dictionary).get("y", -1.0)))
	return Vector2(-1.0, -1.0)


static func _ordered_values(value: Dictionary) -> Array:
	var result: Array = []
	var keys := value.keys()
	keys.sort()
	for key_value in keys: result.append(_dict(value.get(key_value, {})))
	return result


static func _sort_visuals(a: Dictionary, b: Dictionary) -> bool:
	var az := int(a.get("z_order", 0))
	var bz := int(b.get("z_order", 0))
	return str(a.get("semantic_identity", "")) < str(b.get("semantic_identity", "")) if az == bz else az < bz


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
