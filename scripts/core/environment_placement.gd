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
const COUNTER_PERSON_TOKENS := ["bartender", "cashier", "clerk", "dealer", "shopkeeper", "staff", "teller", "vendor"]
const PERSON_TOKENS := ["actor", "bouncer", "captain", "crew", "driver", "guard", "host", "landlord", "mate", "observer", "patron", "person", "regular", "runner", "staff"]
const SEATED_TOKENS := ["audience", "booth", "chair", "seated", "stool"]
const GROUP_TOKENS := ["crowd", "drivers", "group", "sheltering", "the crew"]
const WALL_TOKENS := ["board", "bracket", "calendar", "camera", "clock", "easel", "gauge", "lamp", "menu", "notice", "panel", "poster", "scoreboard", "screen", "seal", "sign", "signal"]
const HANGING_TOKENS := ["banner", "hanging", "speaker rig", "string light"]
const DOOR_TOKENS := ["door", "exit", "gangway", "leave"]
const GROUND_TOKENS := ["chalk", "lane", "mark", "spill", "tape"]
const SURFACE_TOKENS := ["basket", "card", "case", "desk", "drink", "glass", "item", "ledger", "manifest", "note", "provenance", "table", "ticket", "tray", "watch"]
const PERSON_EVENT_PROPS := ["bar_patron", "casino_host", "clerk_counter", "clerk_talk", "host_station", "patron", "pit_boss", "rowdy_patron", "staff"]
const WALL_EVENT_PROPS := ["security_camera"]
const DOOR_EVENT_PROPS := ["motel_door", "side_door"]
const SURFACE_EVENT_PROPS := ["card_table", "paper_note", "room_refreshment", "table"]
const GROUND_EVENT_PROPS := ["room_barrier", "room_fixture", "room_hazard", "room_route", "room_seating", "room_storage", "room_trace", "room_vehicle", "street_sign"]
const WALL_PRESENTATION_PROPS := ["room_display", "room_signal"]

static var _surface_maps: Dictionary = {}
static var _surface_maps_loaded := false


static func classify(object_data: Dictionary, object_type: String = "", object_id: String = "", visual_prop: String = "") -> String:
	var explicit := str(object_data.get("placement_class", "")).strip_edges()
	if explicit in CLASSES:
		return explicit
	var clean_type := object_type.strip_edges().to_lower()
	var clean_prop := visual_prop.strip_edges().to_lower()
	if clean_prop.is_empty():
		clean_prop = str(object_data.get("visual_prop", object_data.get("environment_prop", ""))).strip_edges().to_lower()
	var person_semantics := "%s %s %s %s %s %s" % [
		object_id, clean_type, clean_prop, str(object_data.get("role", "")),
		str(object_data.get("pose", "")), str(object_data.get("appearance", "")),
	]
	person_semantics = person_semantics.to_lower()
	var role := str(object_data.get("role", "")).strip_edges().to_lower()
	var text := "%s %s %s %s %s %s" % [
		object_id, clean_type, clean_prop, str(object_data.get("label", "")),
		str(object_data.get("role", "")),
		str(object_data.get("icon_key", object_data.get("appearance", ""))),
	]
	text = text.to_lower()
	if clean_type in ["scenario_actor", "actor"]:
		if _has_token(person_semantics, COUNTER_PERSON_TOKENS) or clean_prop in ["clerk_counter", "host_station"]:
			return "behind_counter_person"
		if _has_token(person_semantics, SEATED_TOKENS):
			return "seated_person"
		if _has_token(person_semantics, GROUP_TOKENS):
			return "group"
		return "standing_person"
	if role == "exit" and _has_token(text, ["marked_lane", "clear exit", "public aisle"]):
		return "ground_marker"
	if role in ["exit", "doorway"]:
		return "doorway"
	if role == "task_zone":
		return "ground_marker"
	if role == "decision_route":
		return "surface_item"
	if role in ["task_station", "display", "notice", "sign", "wall"] or clean_prop in WALL_PRESENTATION_PROPS:
		return "wall_mounted"
	if role in ["route_marker", "ground_marker"] or clean_prop == "room_route" and role != "task_station":
		return "ground_marker"
	if role == "barrier" and text.contains("bulkhead"):
		return "wall_mounted"
	# The tutorial's dirty parking-lot note is discovered on the pavement, not
	# stocked as merchandise on an indoor shelf.
	if object_id == "event:parking_lot_tip":
		return "ground_marker"
	if role in ["vehicle", "obstacle", "barrier", "blockade", "utility", "furniture", "game_station"] or role == "door" and _has_token(text, ["gate"]):
		return "floor_fixture"
	if clean_prop in ["card_table", "table"]:
		return "floor_fixture"
	if clean_type in ["travel", "layer", "casino_door"] or clean_prop in DOOR_EVENT_PROPS or _has_token(text, DOOR_TOKENS):
		return "doorway"
	if _has_token(text, HANGING_TOKENS):
		return "hanging"
	if _has_token(text, GROUND_TOKENS):
		return "ground_marker"
	if clean_prop in WALL_EVENT_PROPS or clean_prop in WALL_PRESENTATION_PROPS or _has_token(text, WALL_TOKENS):
		return "wall_mounted"
	if clean_type == "event" and _has_token(text, ["discount_sticker"]):
		return "wall_mounted"
	if clean_prop in SURFACE_EVENT_PROPS or _has_token(text, SURFACE_TOKENS):
		return "surface_item"
	if role == "arrangement" and object_id.to_lower().contains("floor_prop"):
		return "ground_marker"
	if role in ["arrangement", "evidence", "refreshment"] or clean_prop in ["room_refreshment", "paper_note"]:
		return "surface_item"
	if clean_prop in GROUND_EVENT_PROPS:
		return "floor_fixture"
	if clean_prop in PERSON_EVENT_PROPS or clean_type == "event" and _has_token(text, COUNTER_PERSON_TOKENS + PERSON_TOKENS):
		if clean_prop in ["clerk_talk", "staff"]:
			return "standing_person"
		if _has_token(person_semantics, COUNTER_PERSON_TOKENS) or clean_prop in ["clerk_counter", "host_station"]:
			return "behind_counter_person"
		if _has_token(person_semantics, SEATED_TOKENS):
			return "seated_person"
		if _has_token(person_semantics, GROUP_TOKENS):
			return "group"
		return "standing_person"
	if clean_type in ["lender", "numbers_silas"]:
		if object_id.to_lower().contains("pawn_counter"):
			return "behind_counter_person"
		return "standing_person"
	if clean_type == "shopkeeper":
		return "behind_counter_person"
	if clean_type in ["game", "game_hook"]:
		return "floor_fixture" if _has_token(text, ["coin pusher", "pull tab", "pull tabs", "scratch ticket", "scratch tickets", "slot", "video poker"]) else "surface_item"
	if clean_type == "service" and _has_token(text, ["deck walk", "relax", "ride", "sand pile", "shuttle", "walk"]):
		return "floor_fixture"
	if clean_type == "service" and _has_token(text, ["burlesque show", "floor show", "stage show"]):
		return "floor_fixture"
	if clean_type in ["item", "drink", "numbers", "service"]:
		return "surface_item"
	return "floor_fixture"


static func surface_map(environment: Dictionary) -> Dictionary:
	_ensure_surface_maps()
	var archetype_id := str(environment.get("archetype_id", environment.get("id", ""))).strip_edges()
	var layer_id := str(environment.get("current_layer_id", environment.get("layer_id", ""))).strip_edges()
	var layered_key := "%s:%s" % [archetype_id, layer_id]
	var result: Dictionary
	if not layer_id.is_empty() and _surface_maps.has(layered_key):
		result = _dict(_surface_maps.get(layered_key, {})).duplicate(true)
	else:
		result = _dict(_surface_maps.get(archetype_id, {})).duplicate(true)
	var scenario_state := _dict(environment.get("scenario_state", {}))
	var scenario_id := str(scenario_state.get("id", environment.get("scenario_id", ""))).strip_edges()
	var scenario_overrides := _dict(result.get("scenario_overrides", {}))
	if not scenario_id.is_empty() and scenario_overrides.has(scenario_id):
		var scenario_override := _dict(scenario_overrides.get(scenario_id, {}))
		var base_class_overrides := _dict(result.get("class_overrides", {})).duplicate(true)
		result.merge(scenario_override, true)
		if scenario_override.has("class_overrides"):
			base_class_overrides.merge(_dict(scenario_override.get("class_overrides", {})), true)
			result["class_overrides"] = base_class_overrides
	return result


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


static func candidate_rects(environment: Dictionary, placement_class: String, authored: Rect2, constraint: Rect2 = Rect2(), fine_search: bool = false) -> Array:
	var surfaces := surface_map(environment)
	var result: Array = []
	var depth_step := 8.0 if fine_search else 26.0
	var horizontal_step := 8.0 if fine_search else maxf(24.0, authored.size.x + 8.0)
	var surface_step := 8.0 if fine_search else maxf(20.0, authored.size.x + 6.0)
	var vertical_step := 8.0 if fine_search else maxf(20.0, authored.size.y + 6.0)
	if placement_class in GROUNDED_CLASSES:
		var floor_data := _dict(surfaces.get("floor", {}))
		var contact_range := _number_pair(floor_data.get("contact_y", []))
		var grounded_bands: Array = []
		for band_value in _array(floor_data.get("bands", [])):
			grounded_bands.append({"bounds": band_value, "surface_id": "floor"})
		for band_value in _array(floor_data.get("stage_bands", [])):
			grounded_bands.append({"bounds": band_value, "surface_id": "stage"})
		for band_entry_value in grounded_bands:
			var band_entry := _dict(band_entry_value)
			var band_value: Variant = band_entry.get("bounds", [])
			var band := _rect_array(band_value)
			if band.size.x <= 0.0 or band.size.y <= 0.0:
				continue
			var stage_band := str(band_entry.get("surface_id", "floor")) == "stage"
			var min_contact := band.position.y if stage_band else maxf(band.position.y, contact_range.x)
			var max_contact := band.end.y if stage_band else minf(band.end.y, contact_range.y)
			for contact_y in _ordered_values(clampf(authored.end.y, min_contact, max_contact), min_contact, max_contact, depth_step):
				for center_x in _ordered_values(clampf(authored.get_center().x, band.position.x + authored.size.x * 0.5, band.end.x - authored.size.x * 0.5), band.position.x + authored.size.x * 0.5, band.end.x - authored.size.x * 0.5, horizontal_step):
					_append_candidate(result, Rect2(Vector2(center_x - authored.size.x * 0.5, contact_y - authored.size.y), authored.size), str(band_entry.get("surface_id", "floor")), placement_class, constraint)
	elif placement_class in ["behind_counter_person", "surface_item"]:
		for counter_value in _array(surfaces.get("counters", [])):
			var counter := _dict(counter_value)
			var allowed_classes := _array(counter.get("classes", []))
			if not allowed_classes.is_empty() and placement_class not in allowed_classes:
				continue
			var x0 := float(counter.get("x0", 0.0))
			var x1 := float(counter.get("x1", 0.0))
			var contact_y := float(counter.get("top_y", 0.0))
			var min_x := x0 + authored.size.x * 0.5
			var max_x := x1 - authored.size.x * 0.5
			if max_x < min_x:
				continue
			for center_x in _ordered_values(clampf(authored.get_center().x, min_x, max_x), min_x, max_x, surface_step):
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
		for center_y in _ordered_values(clampf(authored.get_center().y, min_y, max_y), min_y, max_y, vertical_step):
			for center_x in _ordered_values(clampf(authored.get_center().x, min_x, max_x), min_x, max_x, horizontal_step):
				var candidate := Rect2(Vector2(center_x, center_y) - authored.size * 0.5, authored.size)
				if not _intersects_named_rects(candidate, _array(_dict(surfaces.get("wall", {})).get("exclusions", []))):
					_append_candidate(result, candidate, "wall", placement_class, constraint)
		for mount_value in _array(_dict(surfaces.get("wall", {})).get("mounts", [])):
			var mount := _dict(mount_value)
			var mount_bounds := _rect_array(mount.get("bounds", []))
			var mount_min_x := mount_bounds.position.x + authored.size.x * 0.5
			var mount_max_x := mount_bounds.end.x - authored.size.x * 0.5
			var mount_min_y := mount_bounds.position.y + authored.size.y * 0.5
			var mount_max_y := mount_bounds.end.y - authored.size.y * 0.5
			if mount_max_x < mount_min_x or mount_max_y < mount_min_y:
				continue
			for center_y in _ordered_values(clampf(authored.get_center().y, mount_min_y, mount_max_y), mount_min_y, mount_max_y, vertical_step):
				for center_x in _ordered_values(clampf(authored.get_center().x, mount_min_x, mount_max_x), mount_min_x, mount_max_x, horizontal_step):
					_append_candidate(result, Rect2(Vector2(center_x, center_y) - authored.size * 0.5, authored.size), str(mount.get("id", "wall_mount")), placement_class, constraint)
	elif placement_class == "hanging":
		var ceiling := _rect_array(_dict(surfaces.get("ceiling", {})).get("bounds", []))
		var min_x := ceiling.position.x + authored.size.x * 0.5
		var max_x := ceiling.end.x - authored.size.x * 0.5
		var min_y := ceiling.position.y + authored.size.y * 0.5
		var max_y := ceiling.end.y - authored.size.y * 0.5
		if max_x >= min_x and max_y >= min_y:
			for center_y in _ordered_values(clampf(authored.get_center().y, min_y, max_y), min_y, max_y, vertical_step):
				for center_x in _ordered_values(clampf(authored.get_center().x, min_x, max_x), min_x, max_x, horizontal_step):
					_append_candidate(result, Rect2(Vector2(center_x, center_y) - authored.size * 0.5, authored.size), "ceiling", placement_class, constraint)
	elif placement_class == "doorway":
		for doorway_value in _array(surfaces.get("doorways", [])):
			var doorway := _dict(doorway_value)
			var doorway_rect := _rect_array(doorway.get("bounds", []))
			var min_x := maxf(doorway_rect.position.x, authored.size.x * 0.5)
			var max_x := minf(doorway_rect.end.x, 900.0 - authored.size.x * 0.5)
			var min_y := maxf(doorway_rect.position.y, authored.size.y * 0.5)
			var max_y := minf(doorway_rect.end.y, 430.0 - authored.size.y * 0.5)
			for center_y in _ordered_values(clampf(authored.get_center().y, min_y, max_y), min_y, max_y, vertical_step):
				for center_x in _ordered_values(clampf(authored.get_center().x, min_x, max_x), min_x, max_x, horizontal_step):
					_append_candidate(result, Rect2(Vector2(center_x, center_y) - authored.size * 0.5, authored.size), str(doorway.get("id", "doorway")), placement_class, constraint)
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
	var normalized := " %s " % text.to_lower()
	for separator in ["_", ":", "-", "/", ".", ",", ";", "(", ")", "[", "]"]:
		normalized = normalized.replace(separator, " ")
	while normalized.contains("  "):
		normalized = normalized.replace("  ", " ")
	for token_value in tokens:
		var token := str(token_value).to_lower().replace("_", " ").strip_edges()
		if not token.is_empty() and normalized.contains(" %s " % token):
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
