class_name EnvironmentSlotBinder
extends RefCounted

const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")

const BOARD_SIZE := Vector2(900.0, 430.0)
const SMALL_SCREEN_TARGET := Vector2(44.0, 44.0)
const SLOT_SCHEMA_VERSION := 1
const PRESENTATION_ROOM := "room"
const PRESENTATION_OVERFLOW := "overflow"


# Binds the complete generated base inventory to immutable authored slots.
# No coordinate search, displacement, repack, fallback grid, or RNG is used.
static func bind_base_layout(environment: Dictionary, active_entries: Array) -> Dictionary:
	var surface_map := EnvironmentPlacementScript.surface_map(environment)
	var slots := _ordered_slots(_array(surface_map.get("base_slots", [])))
	var object_preferences := _dict(surface_map.get("object_slot_ids", {}))
	var category_preferences := _dict(surface_map.get("category_slot_ids", {}))
	var occupied: Dictionary = {}
	var object_rects: Dictionary = {}
	var bindings: Dictionary = {}
	var overflow_ids: Array = []
	var entries := active_entries.duplicate(true)
	entries.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left := _dict(left_value)
		var right := _dict(right_value)
		return str(left.get("object_id", "")) < str(right.get("object_id", ""))
	)
	for entry_value in entries:
		var entry := _dict(entry_value)
		var object_id := str(entry.get("object_id", "")).strip_edges()
		if object_id.is_empty() or bindings.has(object_id):
			continue
		var placement_class := EnvironmentPlacementScript.classify(
			entry,
			str(entry.get("object_type", "")),
			object_id,
			str(entry.get("visual_prop", entry.get("prop", "")))
		)
		var preference := str(object_preferences.get(object_id, "")).strip_edges()
		if preference.is_empty():
			var category_key := "%s:%d" % [str(entry.get("spot_field", "")), int(entry.get("index", 0))]
			preference = str(category_preferences.get(category_key, "")).strip_edges()
		var slot := _select_slot(slots, occupied, placement_class, preference)
		if slot.is_empty():
			bindings[object_id] = _overflow_binding(object_id, placement_class, "base")
			overflow_ids.append(object_id)
			continue
		var slot_id := str(slot.get("id", ""))
		occupied[slot_id] = object_id
		var binding := _room_binding(object_id, placement_class, "base", slot)
		bindings[object_id] = binding
		object_rects[object_id] = _normalized_rect(_slot_rect(slot))
	return {
		"ok": true,
		"slot_schema_version": SLOT_SCHEMA_VERSION,
		"slot_map_digest": slot_map_digest(surface_map),
		"binding_digest": binding_digest(bindings),
		"slot_bindings": bindings,
		"object_rects": object_rects,
		"overflow_ids": overflow_ids,
		"occupied_slot_ids": occupied.keys(),
		"errors": [],
	}


# Applies the same authority to the complete interaction inventory. Some live
# records (deliveries, transient contacts, and meta controls) are assembled
# after EnvironmentInstance generated its serialized layout. They consume only
# still-free authored base slots; excess records remain fully actionable in the
# room action list.
static func bind_base_records(environment: Dictionary, records: Array, existing_bindings: Dictionary = {}) -> Dictionary:
	var surface_map := EnvironmentPlacementScript.surface_map(environment)
	var slots := _ordered_slots(_array(surface_map.get("base_slots", [])))
	var object_preferences := _dict(surface_map.get("object_slot_ids", {}))
	var category_preferences := _dict(surface_map.get("category_slot_ids", {}))
	var bindings := existing_bindings.duplicate(true)
	var occupied: Dictionary = {}
	for existing_value in bindings.values():
		var existing := _dict(existing_value)
		if str(existing.get("presentation_mode", "")) != PRESENTATION_ROOM:
			continue
		var existing_slot_id := str(existing.get("slot_id", "")).strip_edges()
		if not existing_slot_id.is_empty():
			occupied[existing_slot_id] = str(existing.get("identity", ""))
	var ordered: Array = []
	for record_value in records:
		var record := _dict(record_value)
		var object_id := str(record.get("object_id", "")).strip_edges()
		if not object_id.is_empty():
			ordered.append(record)
	ordered.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		return str(_dict(left_value).get("object_id", "")) < str(_dict(right_value).get("object_id", ""))
	)
	for record_value in ordered:
		var record := _dict(record_value)
		var object_id := str(record.get("object_id", "")).strip_edges()
		if bindings.has(object_id):
			continue
		var placement_class := EnvironmentPlacementScript.classify(
			record,
			str(record.get("object_type", "")),
			object_id,
			str(record.get("visual_prop", record.get("prop", record.get("icon_key", ""))))
		)
		# A late interaction can be the actionable representation of an object
		# already present in the generated base inventory. Reuse that immutable
		# binding instead of consuming a second slot for the same physical prop.
		var binding_source_id := str(record.get("slot_binding_source_id", "")).strip_edges()
		var shared_binding := _dict(bindings.get(binding_source_id, {}))
		if not binding_source_id.is_empty() \
				and binding_source_id != object_id \
				and not shared_binding.is_empty() \
				and str(shared_binding.get("placement_class", "")) == placement_class:
			shared_binding["identity"] = object_id
			bindings[object_id] = shared_binding
			continue
		var preference := str(object_preferences.get(object_id, "")).strip_edges()
		if preference.is_empty():
			var spot_field := str(record.get("layout_spot_field", "")).strip_edges()
			var category_key := "%s:%d" % [spot_field, int(record.get("layout_index", 0))]
			preference = str(category_preferences.get(category_key, "")).strip_edges()
		var slot := _select_slot(slots, occupied, placement_class, preference)
		if slot.is_empty():
			bindings[object_id] = _overflow_binding(object_id, placement_class, "base")
			continue
		var slot_id := str(slot.get("id", ""))
		occupied[slot_id] = object_id
		bindings[object_id] = _room_binding(object_id, placement_class, "base", slot)
	var result_records: Array = []
	var overflow_ids: Array = []
	for original_value in records:
		var record := _dict(original_value)
		var object_id := str(record.get("object_id", "")).strip_edges()
		var binding := _dict(bindings.get(object_id, {}))
		if binding.is_empty():
			result_records.append(record)
			continue
		var mode := str(binding.get("presentation_mode", PRESENTATION_OVERFLOW))
		record["presentation_mode"] = mode
		record["slot_id"] = str(binding.get("slot_id", ""))
		record["placement_class"] = str(binding.get("placement_class", ""))
		if mode == PRESENTATION_ROOM:
			var normalized := _normalized_rect(_slot_rect(_dict(binding.get("slot", {}))))
			record["normalized_rect"] = normalized.duplicate(true)
			record["focus_rect"] = normalized.duplicate(true)
			record["small_screen_rect"] = _normalized_rect(expanded_rect(_slot_rect(_dict(binding.get("slot", {})))))
			var rect := _rect_from_dict(normalized)
			record["focus_point"] = {"x": rect.get_center().x, "y": rect.get_center().y}
		else:
			record["normalized_rect"] = {}
			record["focus_rect"] = {}
			record["small_screen_rect"] = {}
			record["focus_point"] = {}
			overflow_ids.append(object_id)
		result_records.append(record)
	return {
		"ok": true,
		"records": result_records,
		"slot_bindings": bindings,
		"overflow_ids": overflow_ids,
		"slot_map_digest": slot_map_digest(surface_map),
		"binding_digest": binding_digest(bindings),
		"errors": [],
	}


# Binds scenario-owned visuals. Required safe exits use exit slots; all other
# visuals use stage slots. Route actors reserve both authored endpoints.
static func bind_scenario_visuals(environment: Dictionary, visual_entries: Array) -> Dictionary:
	var surface_map := EnvironmentPlacementScript.surface_map(environment)
	var stage_slots := _ordered_slots(_array(surface_map.get("stage_slots", [])))
	var exit_slots := _ordered_slots(_array(surface_map.get("exit_slots", [])))
	var all_slots := stage_slots + exit_slots
	var slots_by_id := _slots_by_id(all_slots)
	var preferences := _dict(surface_map.get("scenario_slot_ids", {}))
	var routes_by_id := _routes_by_id(_array(surface_map.get("actor_routes", [])))
	var occupied: Dictionary = {}
	var bindings: Dictionary = {}
	var overflow_ids: Array = []
	var entries := visual_entries.duplicate(true)
	entries.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		return str(_dict(left_value).get("identity", "")) < str(_dict(right_value).get("identity", ""))
	)
	# Required exits are hard spatial authority and moving routes reserve both
	# endpoints before ordinary stage visuals consume capacity.
	entries.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left := _dict(left_value)
		var right := _dict(right_value)
		var left_rank := 0 if bool(left.get("safe_exit", false)) else 1 if not str(_dict(left.get("semantic", {})).get("route_id", "")).is_empty() else 2
		var right_rank := 0 if bool(right.get("safe_exit", false)) else 1 if not str(_dict(right.get("semantic", {})).get("route_id", "")).is_empty() else 2
		return str(left.get("identity", "")) < str(right.get("identity", "")) if left_rank == right_rank else left_rank < right_rank
	)
	for entry_value in entries:
		var entry := _dict(entry_value)
		var identity := str(entry.get("identity", "")).strip_edges()
		var semantic := _dict(entry.get("semantic", {}))
		if identity.is_empty() or bindings.has(identity) or not bool(semantic.get("present", true)):
			continue
		var placement_class := str(entry.get("placement_class", ""))
		if placement_class not in EnvironmentPlacementScript.CLASSES:
			placement_class = EnvironmentPlacementScript.classify(
				semantic,
				"actor" if bool(entry.get("actor", false)) else "scene_object",
				identity,
				str(semantic.get("prop", semantic.get("icon_key", "")))
			)
		var stable_id := identity.trim_prefix("scenario::")
		var route_id := str(semantic.get("route_id", "")).strip_edges()
		var route := _dict(routes_by_id.get(route_id, {}))
		var slot: Dictionary = {}
		if not route_id.is_empty() and not route.is_empty():
			var start_id := str(route.get("start_slot_id", ""))
			var end_id := str(route.get("end_slot_id", ""))
			var start_slot := _dict(slots_by_id.get(start_id, {}))
			var end_slot := _dict(slots_by_id.get(end_id, {}))
			if not start_slot.is_empty() and not end_slot.is_empty() \
					and str(start_slot.get("footprint_class", "")) == placement_class \
					and not occupied.has(start_id) and not occupied.has(end_id):
				slot = start_slot
				occupied[start_id] = identity
				occupied[end_id] = "route_endpoint::%s" % identity
		elif bool(entry.get("safe_exit", false)):
			var preference := str(preferences.get(stable_id, preferences.get(identity, ""))).strip_edges()
			slot = _select_slot(exit_slots, occupied, placement_class, preference)
		else:
			var preference := str(preferences.get(stable_id, preferences.get(identity, ""))).strip_edges()
			slot = _select_slot(stage_slots, occupied, placement_class, preference)
		if slot.is_empty():
			bindings[identity] = _overflow_binding(identity, placement_class, "exit" if bool(entry.get("safe_exit", false)) else "stage")
			overflow_ids.append(identity)
			continue
		var slot_id := str(slot.get("id", ""))
		if not occupied.has(slot_id):
			occupied[slot_id] = identity
		var binding := _room_binding(identity, placement_class, "exit" if bool(entry.get("safe_exit", false)) else "stage", slot)
		if not route.is_empty():
			binding["route"] = route.duplicate(true)
		bindings[identity] = binding
	return {
		"ok": true,
		"slot_schema_version": SLOT_SCHEMA_VERSION,
		"slot_map_digest": slot_map_digest(surface_map),
		"binding_digest": binding_digest(bindings),
		"slot_bindings": bindings,
		"overflow_ids": overflow_ids,
		"occupied_slot_ids": occupied.keys(),
		"errors": [],
	}


static func slot_map_digest(surface_map: Dictionary) -> String:
	return JSON.stringify({
		"schema_version": int(surface_map.get("slot_schema_version", 0)),
		"map_id": str(surface_map.get("id", "")),
		"base_slots": _array(surface_map.get("base_slots", [])),
		"stage_slots": _array(surface_map.get("stage_slots", [])),
		"exit_slots": _array(surface_map.get("exit_slots", [])),
		"walk_lanes": _array(surface_map.get("walk_lanes", [])),
		"actor_routes": _array(surface_map.get("actor_routes", [])),
		"object_slot_ids": _dict(surface_map.get("object_slot_ids", {})),
		"category_slot_ids": _dict(surface_map.get("category_slot_ids", {})),
		"scenario_slot_ids": _dict(surface_map.get("scenario_slot_ids", {})),
	}).sha256_text()


static func binding_digest(bindings: Dictionary) -> String:
	var canonical: Array = []
	var identities := bindings.keys()
	identities.sort()
	for identity_value in identities:
		canonical.append(_dict(bindings.get(identity_value, {})))
	return JSON.stringify(canonical).sha256_text()


static func rect_from_binding(binding: Dictionary) -> Rect2:
	return _slot_rect(_dict(binding.get("slot", {})))


static func expanded_rect(rect: Rect2) -> Rect2:
	if not rect.has_area():
		return Rect2()
	var size := Vector2(maxf(rect.size.x, SMALL_SCREEN_TARGET.x), maxf(rect.size.y, SMALL_SCREEN_TARGET.y))
	return _clamp_inside_board(Rect2(rect.get_center() - size * 0.5, size))


static func normalized_rect(rect: Rect2) -> Dictionary:
	return _normalized_rect(rect)


# Returns actor-center points along only the portion of the ordered authored
# lane chain between the two slot contacts. Endpoint-to-lane connectors are
# retained (doorways commonly sit above the public lane), but no unrelated lane
# vertex is visited and no free-space search is performed.
static func authored_route_points(surface_map: Dictionary, start_slot: Dictionary, end_slot: Dictionary, lane_ids: Array) -> Array[Vector2]:
	var start_rect := _slot_rect(start_slot)
	var end_rect := _slot_rect(end_slot)
	if not start_rect.has_area() or not end_rect.has_area() or lane_ids.is_empty():
		return []
	var start_contact := _slot_contact(start_slot, start_rect.get_center())
	var end_contact := _slot_contact(end_slot, end_rect.get_center())
	var lane_points := _authored_lane_polyline(surface_map, lane_ids, start_contact)
	if lane_points.size() < 2:
		return []
	var start_projection := _nearest_polyline_projection(lane_points, start_contact)
	var end_projection := _nearest_polyline_projection(lane_points, end_contact)
	if start_projection.is_empty() or end_projection.is_empty():
		return []
	var projected_start: Vector2 = start_projection.get("point", start_contact)
	var projected_end: Vector2 = end_projection.get("point", end_contact)
	var contact_path := _polyline_slice(
		lane_points,
		projected_start,
		float(start_projection.get("distance_along", 0.0)),
		projected_end,
		float(end_projection.get("distance_along", 0.0))
	)
	if contact_path.is_empty():
		return []
	var center_offset := _moving_center_offset(start_slot, end_slot, start_rect, end_rect, start_contact, end_contact)
	var result: Array[Vector2] = []
	_append_unique_point(result, start_rect.get_center())
	for contact_point in contact_path:
		_append_unique_point(result, contact_point + center_offset)
	_append_unique_point(result, end_rect.get_center())
	return result if result.size() >= 2 else []


static func _select_slot(slots: Array, occupied: Dictionary, placement_class: String, preferred_slot_id: String) -> Dictionary:
	if not preferred_slot_id.is_empty():
		for slot_value in slots:
			var preferred := _dict(slot_value)
			if str(preferred.get("id", "")) == preferred_slot_id \
					and str(preferred.get("footprint_class", "")) == placement_class \
					and not occupied.has(preferred_slot_id):
				return preferred
	for slot_value in slots:
		var slot := _dict(slot_value)
		var slot_id := str(slot.get("id", ""))
		if str(slot.get("footprint_class", "")) == placement_class and not occupied.has(slot_id):
			return slot
	return {}


static func _ordered_slots(values: Array) -> Array:
	var result := values.duplicate(true)
	result.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left := _dict(left_value)
		var right := _dict(right_value)
		var left_priority := int(left.get("priority", 0))
		var right_priority := int(right.get("priority", 0))
		return str(left.get("id", "")) < str(right.get("id", "")) if left_priority == right_priority else left_priority < right_priority
	)
	return result


static func _slots_by_id(slots: Array) -> Dictionary:
	var result: Dictionary = {}
	for slot_value in slots:
		var slot := _dict(slot_value)
		var slot_id := str(slot.get("id", ""))
		if not slot_id.is_empty():
			result[slot_id] = slot
	return result


static func _routes_by_id(routes: Array) -> Dictionary:
	var result: Dictionary = {}
	for route_value in routes:
		var route := _dict(route_value)
		var route_id := str(route.get("id", ""))
		if not route_id.is_empty():
			result[route_id] = route
	return result


static func _room_binding(identity: String, placement_class: String, kind: String, slot: Dictionary) -> Dictionary:
	return {
		"identity": identity,
		"kind": kind,
		"presentation_mode": PRESENTATION_ROOM,
		"slot_id": str(slot.get("id", "")),
		"placement_class": placement_class,
		"slot": slot.duplicate(true),
	}


static func _overflow_binding(identity: String, placement_class: String, kind: String) -> Dictionary:
	return {
		"identity": identity,
		"kind": kind,
		"presentation_mode": PRESENTATION_OVERFLOW,
		"slot_id": "",
		"placement_class": placement_class,
		"slot": {},
	}


static func _slot_rect(slot: Dictionary) -> Rect2:
	var values := _array(slot.get("hit_rect", []))
	if values.size() < 4:
		return Rect2()
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


static func _slot_contact(slot: Dictionary, fallback: Vector2) -> Vector2:
	var values := _array(slot.get("pos", []))
	if values.size() < 2:
		return fallback
	return Vector2(float(values[0]), float(values[1]))


static func _moving_center_offset(
	start_slot: Dictionary,
	end_slot: Dictionary,
	start_rect: Rect2,
	end_rect: Rect2,
	start_contact: Vector2,
	end_contact: Vector2
) -> Vector2:
	var start_offset := start_rect.get_center() - start_contact
	var end_offset := end_rect.get_center() - end_contact
	if start_offset.is_equal_approx(end_offset):
		return start_offset
	if str(start_slot.get("footprint_class", "")) == "doorway":
		return end_offset
	if str(end_slot.get("footprint_class", "")) == "doorway":
		return start_offset
	return start_offset


static func _authored_lane_polyline(surface_map: Dictionary, lane_ids: Array, start_contact: Vector2) -> Array[Vector2]:
	var lanes_by_id: Dictionary = {}
	for lane_value in _array(surface_map.get("walk_lanes", [])):
		var lane := _dict(lane_value)
		var lane_id := str(lane.get("id", ""))
		if not lane_id.is_empty():
			lanes_by_id[lane_id] = lane
	var result: Array[Vector2] = []
	for lane_id_value in lane_ids:
		var lane := _dict(lanes_by_id.get(str(lane_id_value), {}))
		var lane_points: Array[Vector2] = []
		for point_value in _array(lane.get("points", [])):
			var parts := _array(point_value)
			if parts.size() >= 2:
				lane_points.append(Vector2(float(parts[0]), float(parts[1])))
		if lane_points.size() < 2:
			return []
		var direction := str(lane.get("direction", "both"))
		if direction == "reverse":
			lane_points.reverse()
		elif direction == "both":
			var approach: Vector2 = start_contact if result.is_empty() else result.back()
			if approach.distance_squared_to(lane_points.back()) < approach.distance_squared_to(lane_points.front()):
				lane_points.reverse()
		if not result.is_empty() and not result.back().is_equal_approx(lane_points.front()):
			return []
		for lane_point in lane_points:
			_append_unique_point(result, lane_point)
	return result


static func _nearest_polyline_projection(points: Array[Vector2], target: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_distance_squared := INF
	var traversed := 0.0
	for index in range(1, points.size()):
		var segment_start := points[index - 1]
		var segment_end := points[index]
		var segment := segment_end - segment_start
		var length_squared := segment.length_squared()
		if length_squared <= 0.000001:
			continue
		var segment_length := sqrt(length_squared)
		var weight := clampf((target - segment_start).dot(segment) / length_squared, 0.0, 1.0)
		var projected := segment_start + segment * weight
		var distance_squared := target.distance_squared_to(projected)
		var distance_along := traversed + segment_length * weight
		if distance_squared < best_distance_squared - 0.000001 \
				or is_equal_approx(distance_squared, best_distance_squared) and (best.is_empty() or distance_along < float(best.get("distance_along", INF))):
			best_distance_squared = distance_squared
			best = {"point": projected, "distance_along": distance_along}
		traversed += segment_length
	return best


static func _polyline_slice(
	points: Array[Vector2],
	start_point: Vector2,
	start_distance: float,
	end_point: Vector2,
	end_distance: float
) -> Array[Vector2]:
	var vertex_distances: Array[float] = [0.0]
	for index in range(1, points.size()):
		vertex_distances.append(float(vertex_distances.back()) + points[index - 1].distance_to(points[index]))
	var result: Array[Vector2] = []
	_append_unique_point(result, start_point)
	if start_distance <= end_distance:
		for index in range(1, points.size() - 1):
			var distance := vertex_distances[index]
			if distance > start_distance + 0.001 and distance < end_distance - 0.001:
				_append_unique_point(result, points[index])
	else:
		for index in range(points.size() - 2, 0, -1):
			var distance := vertex_distances[index]
			if distance < start_distance - 0.001 and distance > end_distance + 0.001:
				_append_unique_point(result, points[index])
	_append_unique_point(result, end_point)
	return result


static func _append_unique_point(points: Array[Vector2], point: Vector2) -> void:
	if points.is_empty() or not points.back().is_equal_approx(point):
		points.append(point)


static func _normalized_rect(rect: Rect2) -> Dictionary:
	if not rect.has_area():
		return {}
	return {
		"x": rect.position.x / BOARD_SIZE.x,
		"y": rect.position.y / BOARD_SIZE.y,
		"w": rect.size.x / BOARD_SIZE.x,
		"h": rect.size.y / BOARD_SIZE.y,
	}


static func _rect_from_dict(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value as Rect2
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data := value as Dictionary
	return Rect2(
		Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))),
		Vector2(float(data.get("w", 0.0)), float(data.get("h", 0.0)))
	)


static func _clamp_inside_board(rect: Rect2) -> Rect2:
	var size := Vector2(minf(rect.size.x, BOARD_SIZE.x), minf(rect.size.y, BOARD_SIZE.y))
	return Rect2(
		Vector2(clampf(rect.position.x, 0.0, BOARD_SIZE.x - size.x), clampf(rect.position.y, 0.0, BOARD_SIZE.y - size.y)),
		size
	)


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
