class_name ScenarioLayoutResolver
extends RefCounted

const BOARD_SIZE := Vector2(900.0, 430.0)
const SMALL_SCREEN_TARGET := Vector2(104.0, 76.0)
const MAX_VISUALS := 128
const MIN_SCENE_SIZE := Vector2(16.0, 16.0)
const DEFAULT_SCENE_SIZE := Vector2(48.0, 48.0)
const DEFAULT_ACTOR_SIZE := Vector2(72.0, 80.0)
const COLLISION_RATIO := 0.65
const COLLISION_OFFSETS := [
	Vector2.ZERO,
	Vector2(56.0, 0.0), Vector2(-56.0, 0.0),
	Vector2(0.0, 52.0), Vector2(0.0, -52.0),
	Vector2(56.0, 52.0), Vector2(-56.0, 52.0),
	Vector2(56.0, -52.0), Vector2(-56.0, -52.0),
]
const LAYOUT_SPOT_FIELDS := {
	"game": "game_spots",
	"event": "event_spots",
	"item": "item_spots",
	"service": "service_spots",
	"lender": "lender_spots",
	"travel": "travel_spots",
	"shopkeeper": "shopkeeper_spots",
	"game_hook": "game_hook_spots",
}


static func resolve(base_records: Array, projection: Dictionary, environment: Dictionary = {}) -> Dictionary:
	var semantic_state := _dict(projection.get("semantic_state", {}))
	var resolved_projection := projection.duplicate(true)
	# The optional environment argument keeps the pure composition API backward
	# compatible for callers that only inspect semantic membership. Production
	# passes the exact room snapshot and therefore always takes the bounded path.
	if semantic_state.is_empty() or environment.is_empty():
		return {
			"ok": true,
			"projection": resolved_projection,
			"errors": [],
			"warnings": [],
			"layout_audit": {"visual_count": 0, "collision_adjustment_count": 0},
		}
	var errors: Array = []
	var warnings: Array = []
	var occupied := _base_occupied_records(base_records)
	var base_by_identity := _base_records_by_identity(base_records)
	var collision_adjustments := 0
	var visual_count := 0
	var resolved_scenes: Dictionary = {}
	var resolved_actors: Dictionary = {}
	for collection_entry in [
		[semantic_state.get("scene_objects", {}), false, resolved_scenes],
		[semantic_state.get("actors", {}), true, resolved_actors],
	]:
		var collection := _dict((collection_entry as Array)[0])
		var actor := bool((collection_entry as Array)[1])
		var destination: Dictionary = (collection_entry as Array)[2]
		var identities := collection.keys()
		identities.sort()
		for identity_value in identities:
			var identity := str(identity_value)
			var semantic := _dict(collection.get(identity_value, {}))
			if semantic.is_empty():
				continue
			if not bool(semantic.get("present", true)):
				destination[identity] = semantic
				continue
			visual_count += 1
			if visual_count > MAX_VISUALS:
				errors.append("Scenario presentation exceeds the %d visual-object bound." % MAX_VISUALS)
				continue
			var resolved := _resolve_visual(
				identity,
				semantic,
				actor,
				environment,
				semantic_state,
				_dict(base_by_identity.get(identity, {})),
				occupied,
				errors,
				warnings
			)
			if resolved.is_empty():
				var rejected := semantic.duplicate(true)
				rejected["layout_valid"] = false
				destination[identity] = rejected
				continue
			resolved["layout_valid"] = true
			if bool(resolved.get("collision_adjusted", false)):
				collision_adjustments += 1
			destination[identity] = resolved
			if bool(resolved.get("visible", true)):
				occupied.append({
					"identity": identity,
					"rect": _pixel_rect(_dict(resolved.get("normalized_hit_rect", {}))),
				})
	semantic_state["scene_objects"] = resolved_scenes
	semantic_state["actors"] = resolved_actors
	resolved_projection["semantic_state"] = semantic_state
	return {
		"ok": errors.is_empty(),
		"projection": resolved_projection,
		"errors": errors,
		"warnings": warnings,
		"layout_audit": {
			"visual_count": mini(visual_count, MAX_VISUALS),
			"collision_adjustment_count": collision_adjustments,
			"board_size": {"x": BOARD_SIZE.x, "y": BOARD_SIZE.y},
			"small_screen_target": {"w": SMALL_SCREEN_TARGET.x, "h": SMALL_SCREEN_TARGET.y},
		},
	}


static func _resolve_visual(
	identity: String,
	semantic: Dictionary,
	actor: bool,
	environment: Dictionary,
	semantic_state: Dictionary,
	base_record: Dictionary,
	occupied: Array,
	errors: Array,
	warnings: Array
) -> Dictionary:
	var result := semantic.duplicate(true)
	var base_rect := _record_pixel_rect(base_record)
	var center := _resolve_center(
		environment,
		str(semantic.get("anchor_id", base_record.get("anchor_id", ""))),
		str(semantic.get("zone_id", base_record.get("zone_id", "")))
	)
	if (not _finite_point(center) or center.x < 0.0) and base_rect.size.x > 0.0 and base_rect.size.y > 0.0:
		center = base_rect.get_center()
	if not _finite_point(center) or center.x < 0.0:
		errors.append("Scenario visual %s references an unresolved anchor or zone." % identity)
		return {}
	var default_size := DEFAULT_ACTOR_SIZE if actor else DEFAULT_SCENE_SIZE
	var bounds := _dict(semantic.get("bounds", {}))
	var size := Vector2(float(bounds.get("w", 0.0)), float(bounds.get("h", 0.0)))
	if size.x <= 0.0 or size.y <= 0.0:
		size = base_rect.size if base_rect.size.x > 0.0 and base_rect.size.y > 0.0 else default_size
	var minimum := MIN_SCENE_SIZE
	if not _finite_point(size) or size.x < minimum.x or size.y < minimum.y or size.x > BOARD_SIZE.x or size.y > BOARD_SIZE.y:
		errors.append("Scenario visual %s has out-of-bounds semantic dimensions." % identity)
		return {}
	var route_points: Array = []
	if actor:
		var route_id := str(semantic.get("route_id", "")).strip_edges()
		if not route_id.is_empty():
			var route_center := _resolve_route_center(environment, semantic_state, route_id)
			if _finite_point(route_center) and route_center.x >= 0.0:
				route_points = [_normalized_point(center), _normalized_point(route_center)]
				if str(semantic.get("behavior", "idle")) in ["patrol", "flee", "depart"]:
					center = route_center
			else:
				warnings.append("Scenario actor %s route %s has no room-space endpoint." % [identity, route_id])
	var authored_rect := _clamp_inside_board(Rect2(center - size * 0.5, size))
	var placement := _collision_safe_rect(identity, authored_rect, occupied)
	var pixel_rect: Rect2 = placement.get("rect", authored_rect)
	var adjusted := bool(placement.get("adjusted", false))
	if bool(placement.get("colliding", false)):
		warnings.append("Scenario visual %s retains an authored overlap after bounded collision resolution." % identity)
	result["present"] = true
	result["semantic_kind"] = "actor" if actor else "scene_object"
	result["normalized_hit_rect"] = _normalized_rect(pixel_rect)
	result["small_screen_rect"] = _expanded_normalized_rect(pixel_rect, SMALL_SCREEN_TARGET)
	result["resolved_bounds"] = {"w": pixel_rect.size.x, "h": pixel_rect.size.y}
	result["collision_adjusted"] = adjusted
	result["route_points"] = route_points
	if not result.has("label"):
		result["label"] = str(base_record.get("label", result.get("stable_object_id", identity)))
	if actor:
		result["enabled"] = bool(result.get("enabled", true))
		result["visible"] = bool(result.get("visible", true))
	return result


static func _resolve_center(environment: Dictionary, anchor_id: String, zone_id: String) -> Vector2:
	var anchors := _dict(environment.get("semantic_anchors", {}))
	var zones := _dict(environment.get("semantic_zones", {}))
	if not anchor_id.is_empty() and anchors.has(anchor_id):
		return _point(_dict(anchors.get(anchor_id, {})).get("position", []))
	if not zone_id.is_empty() and zones.has(zone_id):
		var zone_rect := _pixel_bounds(_dict(zones.get(zone_id, {})).get("bounds", []))
		if zone_rect.size.x > 0.0 and zone_rect.size.y > 0.0:
			return zone_rect.get_center()
	var layout := _dict(environment.get("layout", environment))
	var object_rects := _dict(layout.get("object_rects", {}))
	if not anchor_id.is_empty() and object_rects.has(anchor_id):
		var object_rect := _normalized_or_pixel_rect(object_rects.get(anchor_id, {}))
		if object_rect.size.x > 0.0 and object_rect.size.y > 0.0:
			return object_rect.get_center()
	if anchor_id.begins_with("layout:"):
		var parts := anchor_id.split(":", false)
		if parts.size() == 3 and LAYOUT_SPOT_FIELDS.has(str(parts[1])) and str(parts[2]).is_valid_int():
			var spots := _array(layout.get(str(LAYOUT_SPOT_FIELDS.get(str(parts[1]), "")), []))
			var index := int(parts[2])
			if index >= 0 and index < spots.size():
				return _point(spots[index])
	return Vector2(-1.0, -1.0)


static func _resolve_route_center(environment: Dictionary, semantic_state: Dictionary, route_id: String) -> Vector2:
	var routes := _dict(semantic_state.get("routes", {}))
	var route := _dict(routes.get(route_id, {}))
	for candidate_value in [
		str(route.get("source_id", "")),
		str(route.get("stable_object_id", "")),
		route_id.get_slice("::", 1),
	]:
		var candidate := str(candidate_value)
		var center := _resolve_center(environment, candidate, candidate)
		if center.x >= 0.0:
			return center
	return Vector2(-1.0, -1.0)


static func _collision_safe_rect(identity: String, authored: Rect2, occupied: Array) -> Dictionary:
	for offset_value in COLLISION_OFFSETS:
		var candidate := _clamp_inside_board(Rect2(authored.position + (offset_value as Vector2), authored.size))
		if not _substantially_overlaps(identity, candidate, occupied):
			return {"rect": candidate, "adjusted": not (offset_value as Vector2).is_zero_approx(), "colliding": false}
	return {"rect": authored, "adjusted": false, "colliding": true}


static func _substantially_overlaps(identity: String, rect: Rect2, occupied: Array) -> bool:
	for occupied_value in occupied:
		var occupied_record := _dict(occupied_value)
		if str(occupied_record.get("identity", "")) == identity:
			continue
		var other: Rect2 = occupied_record.get("rect", Rect2())
		if other.size.x <= 0.0 or other.size.y <= 0.0:
			continue
		var overlap := rect.intersection(other).get_area()
		if overlap > minf(rect.get_area(), other.get_area()) * COLLISION_RATIO:
			return true
	return false


static func _base_records_by_identity(base_records: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in base_records:
		var record := _dict(value)
		var identity := "%s::%s" % [str(record.get("owner_namespace", "")), str(record.get("stable_object_id", ""))]
		if identity != "::":
			result[identity] = record
	return result


static func _base_occupied_records(base_records: Array) -> Array:
	var result: Array = []
	for value in base_records:
		var record := _dict(value)
		var rect := _record_pixel_rect(record)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		result.append({
			"identity": "%s::%s" % [str(record.get("owner_namespace", "")), str(record.get("stable_object_id", ""))],
			"rect": rect,
		})
	return result


static func _record_pixel_rect(record: Dictionary) -> Rect2:
	if record.is_empty():
		return Rect2()
	return _normalized_or_pixel_rect(record.get("focus_rect", record.get("normalized_rect", {})))


static func _normalized_or_pixel_rect(value: Variant) -> Rect2:
	var rect := _rect(value)
	if not _finite_point(rect.position) or not _finite_point(rect.size) or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Rect2()
	if rect.position.x <= 1.0 and rect.position.y <= 1.0 and rect.size.x <= 1.0 and rect.size.y <= 1.0:
		return Rect2(rect.position * BOARD_SIZE, rect.size * BOARD_SIZE)
	return rect


static func _pixel_bounds(value: Variant) -> Rect2:
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 4:
		return Rect2(float((value as Array)[0]), float((value as Array)[1]), float((value as Array)[2]), float((value as Array)[3]))
	return _normalized_or_pixel_rect(value)


static func _clamp_inside_board(rect: Rect2) -> Rect2:
	var position := Vector2(
		clampf(rect.position.x, 0.0, BOARD_SIZE.x - rect.size.x),
		clampf(rect.position.y, 0.0, BOARD_SIZE.y - rect.size.y)
	)
	return Rect2(position, rect.size)


static func _expanded_normalized_rect(rect: Rect2, minimum: Vector2) -> Dictionary:
	var size := Vector2(maxf(rect.size.x, minimum.x), maxf(rect.size.y, minimum.y))
	size.x = minf(size.x, BOARD_SIZE.x)
	size.y = minf(size.y, BOARD_SIZE.y)
	var expanded := _clamp_inside_board(Rect2(rect.get_center() - size * 0.5, size))
	return _normalized_rect(expanded)


static func _normalized_rect(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x / BOARD_SIZE.x,
		"y": rect.position.y / BOARD_SIZE.y,
		"w": rect.size.x / BOARD_SIZE.x,
		"h": rect.size.y / BOARD_SIZE.y,
	}


static func _pixel_rect(value: Dictionary) -> Rect2:
	return Rect2(
		float(value.get("x", 0.0)) * BOARD_SIZE.x,
		float(value.get("y", 0.0)) * BOARD_SIZE.y,
		float(value.get("w", 0.0)) * BOARD_SIZE.x,
		float(value.get("h", 0.0)) * BOARD_SIZE.y
	)


static func _normalized_point(point: Vector2) -> Dictionary:
	return {"x": point.x / BOARD_SIZE.x, "y": point.y / BOARD_SIZE.y}


static func _finite_point(point: Vector2) -> bool:
	return is_finite(point.x) and is_finite(point.y)


static func _point(value: Variant) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value as Vector2
	if typeof(value) == TYPE_VECTOR2I:
		var point := value as Vector2i
		return Vector2(float(point.x), float(point.y))
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2(float((value as Dictionary).get("x", -1.0)), float((value as Dictionary).get("y", -1.0)))
	return Vector2(-1.0, -1.0)


static func _rect(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value as Rect2
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data := value as Dictionary
	return Rect2(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0)),
		float(data.get("w", 0.0)),
		float(data.get("h", 0.0))
	)


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
