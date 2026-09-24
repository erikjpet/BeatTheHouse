class_name EnvironmentPlacement
extends RefCounted

const SURFACE_MAP_PATH := "res://data/environments/placement_surfaces.json"
const DeveloperPlacementStoreScript := preload("res://scripts/core/developer_placement_store.gd")
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
const SCENARIO_RESERVATION_FIELDS := [
	"scenario_reserved_surfaces", "scenario_reserved_behind_counter_surfaces",
	"scenario_reserved_rects", "scenario_reserved_surface_rects",
	"scenario_reserved_wall_rects", "scenario_reserved_clear_rects",
	"scenario_reserved_clear_rects_by_class",
]

static var _surface_maps: Dictionary = {}
static var _effective_surface_maps: Dictionary = {}
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
	var person_roles := ["bartender", "casino_host", "clerk", "dealer", "guard", "host", "lender", "merchant", "musician", "patron", "person", "pit_boss", "shopkeeper", "staff", "teller", "vendor"]
	var named_person := not str(object_data.get("actor_id", object_data.get("character_id", object_data.get("npc_id", object_data.get("speaker_id", ""))))).strip_edges().is_empty()
	var person_object := clean_type in ["actor", "character", "lender", "merchant", "npc", "scenario_actor", "shopkeeper", "numbers_silas"] \
		or role in person_roles \
		or clean_prop in PERSON_EVENT_PROPS \
		or named_person \
		or object_id.to_lower() == "numbers:silas"
	if person_object:
		if role in ["bartender", "clerk", "dealer", "merchant", "shopkeeper", "teller", "vendor"] \
				or clean_prop in ["clerk_counter", "host_station"] \
				or _has_token(person_semantics, COUNTER_PERSON_TOKENS):
			return "behind_counter_person"
		if _has_token(person_semantics, SEATED_TOKENS):
			return "seated_person"
		if _has_token(person_semantics, GROUP_TOKENS):
			return "group"
		return "standing_person"
	var text := "%s %s %s %s %s %s" % [
		object_id, clean_type, clean_prop, str(object_data.get("label", "")),
		str(object_data.get("role", "")),
		str(object_data.get("icon_key", object_data.get("appearance", ""))),
	]
	text = text.to_lower()
	# Scenario escape controls keep doorway authority after their live-object
	# payload is reduced to a task-zone visual during composition.
	if object_id.to_lower().ends_with("_safe_exit"):
		return "doorway"
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
	var map_key := layered_key if not layer_id.is_empty() and _surface_maps.has(layered_key) else archetype_id
	var base_map := _dict(_surface_maps.get(map_key, {}))
	var scenario_state := _dict(environment.get("scenario_state", {}))
	var scenario_id := str(scenario_state.get("id", environment.get("scenario_id", ""))).strip_edges()
	if scenario_id.is_empty():
		scenario_id = str(_dict(environment.get("scenario_sequence_state", {})).get("scenario_id", "")).strip_edges()
	var scenario_overrides := _dict(base_map.get("scenario_overrides", {}))
	if scenario_id.is_empty() or not scenario_overrides.has(scenario_id):
		var base_key := "%s::base" % map_key
		if _effective_surface_maps.has(base_key):
			return _dict(_effective_surface_maps.get(base_key, {}))
		var unreserved_map := base_map.duplicate(false)
		for field_value in SCENARIO_RESERVATION_FIELDS:
			unreserved_map.erase(str(field_value))
		_effective_surface_maps[base_key] = unreserved_map
		return unreserved_map
	var effective_key := "%s::%s" % [map_key, scenario_id]
	if _effective_surface_maps.has(effective_key):
		return _dict(_effective_surface_maps.get(effective_key, {}))
	var result := base_map.duplicate(false)
	var scenario_override := _dict(scenario_overrides.get(scenario_id, {}))
	var base_class_overrides := _dict(base_map.get("class_overrides", {})).duplicate(true)
	result.merge(scenario_override, true)
	if scenario_override.has("class_overrides"):
		base_class_overrides.merge(_dict(scenario_override.get("class_overrides", {})), true)
		result["class_overrides"] = base_class_overrides
	_effective_surface_maps[effective_key] = result
	return result


static func surface_map_by_id(archetype_id: String, layer_id: String = "") -> Dictionary:
	return surface_map({"archetype_id": archetype_id, "current_layer_id": layer_id})


# Developer placement is a preview/export concern only. Shipping placement
# always reads surface_map(), so a local authoring override cannot change a run.
static func authoring_surface_map(environment: Dictionary) -> Dictionary:
	return _with_developer_slots(environment, surface_map(environment))


# Applies developer-authored positions as the final authored slot layer. This
# changes placement inputs only; it never touches run state, visibility, or RNG.
static func _with_developer_slots(environment: Dictionary, surface_data: Dictionary) -> Dictionary:
	var base_overrides := DeveloperPlacementStoreScript.slot_overrides(environment, "object_slot_positions")
	var scenario_overrides := DeveloperPlacementStoreScript.slot_overrides(environment, "scenario_object_slot_positions")
	var category_overrides := DeveloperPlacementStoreScript.slot_overrides(environment, "category_slot_positions")
	if base_overrides.is_empty() and scenario_overrides.is_empty() and category_overrides.is_empty():
		return surface_data
	var result := surface_data.duplicate(true)
	for field in ["object_slot_positions", "scenario_object_slot_positions"]:
		var overrides := base_overrides if field == "object_slot_positions" else scenario_overrides
		if overrides.is_empty():
			continue
		var slots := _dict(result.get(field, {})).duplicate(true)
		slots.merge(overrides, true)
		result[field] = slots
	# These parallel maps retain provenance. The generated-layout pass uses them
	# to distinguish deliberate free placement from legacy authored coordinates
	# that still need physical-surface recovery.
	result["developer_object_slot_positions"] = base_overrides.duplicate(true)
	result["developer_scenario_object_slot_positions"] = scenario_overrides.duplicate(true)
	result["developer_category_slot_positions"] = category_overrides.duplicate(true)
	return result


# Preserves authored geometry whenever its class contact already rests on a
# physical room support. Recovery is deliberately local and bounded; the
# content pass owns composition, while this is only a malformed-slot safety net.
static func support_for_rect(environment: Dictionary, placement_class: String, rect: Rect2) -> Dictionary:
	return support_for_rect_on_surfaces(surface_map(environment), placement_class, rect)


# Static slot validation already holds the immutable effective surface map.
# Reusing it avoids re-merging developer/project placement layers for each
# authored slot while checking its physical support.
static func support_for_rect_on_surfaces(surfaces: Dictionary, placement_class: String, rect: Rect2) -> Dictionary:
	var board := Rect2(0.0, 0.0, 900.0, 430.0)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not board.encloses(rect):
		return {}
	var contact := _contact_point(rect, placement_class)
	if placement_class in GROUNDED_CLASSES:
		var floor_data := _dict(surfaces.get("floor", {}))
		var contact_range := _number_pair(floor_data.get("contact_y", []))
		for band_key in ["bands", "stage_bands"]:
			for band_value in _array(floor_data.get(str(band_key), [])):
				var band := _rect_array(band_value)
				if band.has_point(contact) and contact.y >= contact_range.x - 0.5 and contact.y <= contact_range.y + 0.5:
					return {"surface_id": "stage" if str(band_key) == "stage_bands" else "floor"}
	elif placement_class in ["behind_counter_person", "surface_item"]:
		for counter_value in _array(surfaces.get("counters", [])):
			var counter := _dict(counter_value)
			var allowed_classes := _array(counter.get("classes", []))
			if not allowed_classes.is_empty() and placement_class not in allowed_classes:
				continue
			var top_y := float(counter.get("top_y", -1000.0))
			var front_y := float(counter.get("front_y", top_y))
			var vertical_contact := contact.y > top_y + 0.5 and contact.y <= front_y + 0.5 \
					if placement_class == "behind_counter_person" else absf(contact.y - top_y) <= 0.5
			if vertical_contact \
					and rect.position.x >= float(counter.get("x0", 0.0)) - 0.5 \
					and rect.end.x <= float(counter.get("x1", 0.0)) + 0.5:
				return {"surface_id": str(counter.get("id", "counter"))}
	elif placement_class == "seated_person":
		for seat_value in _array(surfaces.get("seats", [])):
			var seat := _dict(seat_value)
			if contact.distance_to(_vector(seat.get("point", []))) <= 0.75:
				return {"surface_id": str(seat.get("id", "seat"))}
	elif placement_class == "wall_mounted":
		for mount_value in _array(_dict(surfaces.get("wall", {})).get("mounts", [])):
			var mount := _dict(mount_value)
			if _rect_array(mount.get("bounds", [])).encloses(rect):
				return {"surface_id": str(mount.get("id", "wall_mount"))}
		var wall_data := _dict(surfaces.get("wall", {}))
		if _rect_array(wall_data.get("bounds", [])).encloses(rect) and not _intersects_named_rects(rect, _array(wall_data.get("exclusions", []))):
			return {"surface_id": "wall"}
	elif placement_class == "hanging":
		if _rect_array(_dict(surfaces.get("ceiling", {})).get("bounds", [])).encloses(rect):
			return {"surface_id": "ceiling"}
	elif placement_class == "doorway":
		for doorway_value in _array(surfaces.get("doorways", [])):
			var doorway := _dict(doorway_value)
			if _rect_array(doorway.get("bounds", [])).has_point(contact):
				return {"surface_id": str(doorway.get("id", "doorway"))}
	return {}


static func valid_rect(environment: Dictionary, placement_class: String, rect: Rect2, constraint: Rect2 = Rect2()) -> bool:
	if not constraint.is_equal_approx(Rect2()) and not constraint.encloses(rect):
		return false
	return not support_for_rect(environment, placement_class, rect).is_empty()


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
	_effective_surface_maps.clear()
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


static func _contact_point(rect: Rect2, placement_class: String) -> Vector2:
	if placement_class in ["wall_mounted", "hanging", "doorway"]:
		return rect.get_center()
	return Vector2(rect.get_center().x, rect.end.y)


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
