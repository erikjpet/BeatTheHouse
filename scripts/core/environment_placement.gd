class_name EnvironmentPlacement
extends RefCounted

const SURFACE_MAP_PATH := "res://data/environments/placement_surfaces.json"
const CLASSES := [
	"standing_person", "behind_counter_person", "seated_person", "group",
	"floor_fixture", "ground_marker", "surface_item", "wall_mounted",
	"hanging", "doorway",
]
const PERSON_CLASSES := ["standing_person", "behind_counter_person", "seated_person", "group"]
const GROUNDED_CLASSES := ["standing_person", "group", "floor_fixture", "ground_marker"]
const COUNTER_PERSON_TOKENS := ["bartender", "cashier", "clerk", "dealer", "shopkeeper", "teller", "vendor"]
const PERSON_TOKENS := ["actor", "bouncer", "captain", "crew", "driver", "guard", "host", "landlord", "mate", "observer", "patron", "person", "regular", "runner"]
const SEATED_TOKENS := ["audience", "booth", "chair", "seated", "stool"]
const GROUP_TOKENS := ["crowd", "drivers", "group", "sheltering", "the crew"]
const WALL_TOKENS := ["calendar", "camera", "clock", "menu", "notice", "poster", "scoreboard", "screen", "sign"]
const HANGING_TOKENS := ["banner", "hanging", "speaker rig", "string light"]
const DOOR_TOKENS := ["door", "exit", "gangway", "leave", "route"]
const GROUND_TOKENS := ["chalk", "lane", "mark", "spill", "tape"]
const SURFACE_TOKENS := ["card", "drink", "glass", "ledger", "note", "ticket", "tray", "watch"]
const PERSON_EVENT_PROPS := ["bar_patron", "casino_host", "clerk_counter", "clerk_talk", "host_station", "patron", "pit_boss", "rowdy_patron", "staff"]
const WALL_EVENT_PROPS := ["security_camera"]
const DOOR_EVENT_PROPS := ["motel_door", "side_door"]
const SURFACE_EVENT_PROPS := ["card_table", "paper_note", "table"]

static var _surface_maps: Dictionary = {}
static var _surface_maps_loaded := false


static func classify(object_data: Dictionary, object_type: String = "", object_id: String = "", visual_prop: String = "") -> String:
	var explicit := str(object_data.get("placement_class", "")).strip_edges()
	if explicit in CLASSES:
		return explicit
	var clean_type := object_type.strip_edges().to_lower()
	var clean_prop := visual_prop.strip_edges().to_lower()
	var text := "%s %s %s %s %s %s %s" % [
		object_id, clean_type, clean_prop, str(object_data.get("label", "")),
		str(object_data.get("role", "")), str(object_data.get("description", "")),
		str(object_data.get("icon_key", object_data.get("appearance", ""))),
	]
	text = text.to_lower()
	if clean_type in ["scenario_actor", "actor"] or clean_prop in PERSON_EVENT_PROPS or _has_token(text, COUNTER_PERSON_TOKENS + PERSON_TOKENS):
		if _has_token(text, COUNTER_PERSON_TOKENS) or clean_prop in ["clerk_counter", "host_station"]:
			return "behind_counter_person"
		if _has_token(text, SEATED_TOKENS):
			return "seated_person"
		if _has_token(text, GROUP_TOKENS):
			return "group"
		return "standing_person"
	if clean_type in ["lender", "numbers_silas"]:
		return "standing_person"
	if clean_type == "shopkeeper":
		return "behind_counter_person"
	if clean_type in ["travel", "layer", "casino_door"] or clean_prop in DOOR_EVENT_PROPS or _has_token(text, DOOR_TOKENS):
		return "doorway"
	if clean_prop in WALL_EVENT_PROPS or _has_token(text, WALL_TOKENS):
		return "wall_mounted"
	if _has_token(text, HANGING_TOKENS):
		return "hanging"
	if _has_token(text, GROUND_TOKENS):
		return "ground_marker"
	if clean_type in ["item", "drink", "numbers"] or clean_prop in SURFACE_EVENT_PROPS or _has_token(text, SURFACE_TOKENS):
		return "surface_item"
	return "floor_fixture"


static func surface_map(environment: Dictionary) -> Dictionary:
	_ensure_surface_maps()
	var archetype_id := str(environment.get("archetype_id", environment.get("id", ""))).strip_edges()
	var layer_id := str(environment.get("current_layer_id", environment.get("layer_id", ""))).strip_edges()
	var layered_key := "%s:%s" % [archetype_id, layer_id]
	if not layer_id.is_empty() and _surface_maps.has(layered_key):
		return _dict(_surface_maps.get(layered_key, {}))
	return _dict(_surface_maps.get(archetype_id, {}))


static func surface_map_by_id(archetype_id: String, layer_id: String = "") -> Dictionary:
	return surface_map({"archetype_id": archetype_id, "current_layer_id": layer_id})


static func grounded_rect(environment: Dictionary, placement_class: String, authored: Rect2, constraint: Rect2 = Rect2()) -> Dictionary:
	var surfaces := surface_map(environment)
	if surfaces.is_empty() or placement_class not in CLASSES:
		return {"ok": false, "rect": authored, "surface_id": "", "error": "missing placement surface map or class"}
	var candidates := candidate_rects(environment, placement_class, authored, constraint)
	if candidates.is_empty():
		return {"ok": false, "rect": authored, "surface_id": "", "error": "no valid surface candidate"}
	var selected := _dict(candidates[0])
	return {"ok": true, "rect": selected.get("rect", authored), "surface_id": str(selected.get("surface_id", "")), "error": ""}


static func candidate_rects(environment: Dictionary, placement_class: String, authored: Rect2, constraint: Rect2 = Rect2()) -> Array:
	var surfaces := surface_map(environment)
	var result: Array = []
	if placement_class in GROUNDED_CLASSES:
		var floor_data := _dict(surfaces.get("floor", {}))
		var contact_range := _number_pair(floor_data.get("contact_y", []))
		for band_value in _array(floor_data.get("bands", [])):
			var band := _rect_array(band_value)
			if band.size.x <= 0.0 or band.size.y <= 0.0:
				continue
			var min_contact := maxf(band.position.y, contact_range.x)
			var max_contact := minf(band.end.y, contact_range.y)
			for contact_y in _ordered_values(clampf(authored.end.y, min_contact, max_contact), min_contact, max_contact, 26.0):
				for center_x in _ordered_values(clampf(authored.get_center().x, band.position.x + authored.size.x * 0.5, band.end.x - authored.size.x * 0.5), band.position.x + authored.size.x * 0.5, band.end.x - authored.size.x * 0.5, maxf(24.0, authored.size.x + 8.0)):
					_append_candidate(result, Rect2(Vector2(center_x - authored.size.x * 0.5, contact_y - authored.size.y), authored.size), "floor", placement_class, constraint)
	elif placement_class in ["behind_counter_person", "surface_item"]:
		for counter_value in _array(surfaces.get("counters", [])):
			var counter := _dict(counter_value)
			var x0 := float(counter.get("x0", 0.0))
			var x1 := float(counter.get("x1", 0.0))
			var contact_y := float(counter.get("top_y", 0.0))
			var min_x := x0 + authored.size.x * 0.5
			var max_x := x1 - authored.size.x * 0.5
			if max_x < min_x:
				continue
			for center_x in _ordered_values(clampf(authored.get_center().x, min_x, max_x), min_x, max_x, maxf(20.0, authored.size.x + 6.0)):
				_append_candidate(result, Rect2(Vector2(center_x - authored.size.x * 0.5, contact_y - authored.size.y), authored.size), str(counter.get("id", "counter")), placement_class, constraint)
	elif placement_class == "seated_person":
		for seat_value in _array(surfaces.get("seats", [])):
			var seat := _dict(seat_value)
			var point := _vector(seat.get("point", []))
			_append_candidate(result, Rect2(Vector2(point.x - authored.size.x * 0.5, point.y - authored.size.y), authored.size), str(seat.get("id", "seat")), placement_class, constraint)
	elif placement_class == "wall_mounted":
		var wall := _rect_array(_dict(surfaces.get("wall", {})).get("bounds", []))
		var min_x := wall.position.x + authored.size.x * 0.5
		var max_x := wall.end.x - authored.size.x * 0.5
		var min_y := wall.position.y + authored.size.y * 0.5
		var max_y := wall.end.y - authored.size.y * 0.5
		for center_y in _ordered_values(clampf(authored.get_center().y, min_y, max_y), min_y, max_y, maxf(20.0, authored.size.y + 6.0)):
			for center_x in _ordered_values(clampf(authored.get_center().x, min_x, max_x), min_x, max_x, maxf(20.0, authored.size.x + 6.0)):
				var candidate := Rect2(Vector2(center_x, center_y) - authored.size * 0.5, authored.size)
				if not _intersects_named_rects(candidate, _array(_dict(surfaces.get("wall", {})).get("exclusions", []))):
					_append_candidate(result, candidate, "wall", placement_class, constraint)
	elif placement_class == "hanging":
		var ceiling := _rect_array(_dict(surfaces.get("ceiling", {})).get("bounds", []))
		var center := Vector2(clampf(authored.get_center().x, ceiling.position.x + authored.size.x * 0.5, ceiling.end.x - authored.size.x * 0.5), clampf(authored.get_center().y, ceiling.position.y + authored.size.y * 0.5, ceiling.end.y - authored.size.y * 0.5))
		_append_candidate(result, Rect2(center - authored.size * 0.5, authored.size), "ceiling", placement_class, constraint)
	elif placement_class == "doorway":
		for doorway_value in _array(surfaces.get("doorways", [])):
			var doorway := _dict(doorway_value)
			var doorway_rect := _rect_array(doorway.get("bounds", []))
			var center := Vector2(clampf(authored.get_center().x, doorway_rect.position.x + authored.size.x * 0.5, doorway_rect.end.x - authored.size.x * 0.5), clampf(authored.get_center().y, doorway_rect.position.y + authored.size.y * 0.5, doorway_rect.end.y - authored.size.y * 0.5))
			_append_candidate(result, Rect2(center - authored.size * 0.5, authored.size), str(doorway.get("id", "doorway")), placement_class, constraint)
	result.sort_custom(func(a: Variant, b: Variant) -> bool: return _dict(a).get("rect", authored).get_center().distance_squared_to(authored.get_center()) < _dict(b).get("rect", authored).get_center().distance_squared_to(authored.get_center()))
	return result


static func valid_rect(environment: Dictionary, placement_class: String, rect: Rect2, constraint: Rect2 = Rect2()) -> bool:
	for candidate_value in candidate_rects(environment, placement_class, rect, constraint):
		var candidate := _dict(candidate_value).get("rect", Rect2()) as Rect2
		if candidate.position.distance_squared_to(rect.position) <= 0.25:
			return true
	return false


static func is_person_class(placement_class: String) -> bool:
	return placement_class in PERSON_CLASSES


static func shadow_kind(placement_class: String) -> String:
	if placement_class in ["wall_mounted", "hanging", "doorway"]:
		return "none"
	if placement_class == "surface_item":
		return "contact"
	return "feet" if placement_class in PERSON_CLASSES else "base"


static func _ensure_surface_maps() -> void:
	if _surface_maps_loaded:
		return
	_surface_maps_loaded = true
	var file := FileAccess.open(SURFACE_MAP_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for map_value in _array(_dict(parsed).get("maps", [])):
		var map_data := _dict(map_value)
		var map_id := str(map_data.get("id", ""))
		if not map_id.is_empty():
			_surface_maps[map_id] = map_data


static func _append_candidate(output: Array, rect: Rect2, surface_id: String, placement_class: String, constraint: Rect2) -> void:
	var board := Rect2(0.0, 0.0, 900.0, 430.0)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not board.encloses(rect):
		return
	if constraint.has_area() and not constraint.has_point(_contact_point(rect, placement_class)):
		return
	output.append({"rect": rect, "surface_id": surface_id})


static func _contact_point(rect: Rect2, placement_class: String) -> Vector2:
	if placement_class in ["wall_mounted", "hanging", "doorway"]:
		return rect.get_center()
	return Vector2(rect.get_center().x, rect.end.y)


static func _ordered_values(preferred: float, minimum: float, maximum: float, step: float) -> Array:
	var values: Array = []
	if maximum < minimum:
		return values
	values.append(clampf(preferred, minimum, maximum))
	var distance := step
	while preferred - distance >= minimum or preferred + distance <= maximum:
		if preferred - distance >= minimum:
			values.append(preferred - distance)
		if preferred + distance <= maximum:
			values.append(preferred + distance)
		distance += step
	if not values.has(minimum):
		values.append(minimum)
	if not values.has(maximum):
		values.append(maximum)
	return values


static func _intersects_named_rects(rect: Rect2, entries: Array) -> bool:
	for entry_value in entries:
		if rect.intersects(_rect_array(_dict(entry_value).get("bounds", []))):
			return true
	return false


static func _has_token(text: String, tokens: Array) -> bool:
	for token_value in tokens:
		if text.contains(str(token_value)):
			return true
	return false


static func _number_pair(value: Variant) -> Vector2:
	var values := _array(value)
	if values.size() < 2:
		return Vector2(0.0, 430.0)
	return Vector2(float(values[0]), float(values[1]))


static func _rect_array(value: Variant) -> Rect2:
	var values := _array(value)
	if values.size() < 4:
		return Rect2()
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


static func _vector(value: Variant) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value
	var values := _array(value)
	if values.size() >= 2:
		return Vector2(float(values[0]), float(values[1]))
	return Vector2.ZERO


static func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []
