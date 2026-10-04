class_name EnvironmentPlacement
extends RefCounted

const SURFACE_MAP_PATH := "res://data/environments/placement_surfaces.json"
const SCENARIO_LAYOUT_PATH := "res://data/environments/scenario_slot_layouts.json"
const DeveloperPlacementStoreScript := preload("res://scripts/core/developer_placement_store.gd")
const SLOT_SCHEMA_VERSION := 2
const SLOT_FAMILIES := ["fixed", "event", "scenario", "exit"]
const SLOT_COLLECTIONS := {
	"fixed": "fixed_slots",
	"event": "event_slots",
	"scenario": "scenario_slots",
	"exit": "exit_slots",
}
const CLASSES := [
	"standing_person", "behind_counter_person", "seated_person", "group",
	"floor_fixture", "ground_marker", "surface_item", "shop_item", "wall_mounted",
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
const PERSON_EVENT_PROPS := ["bar_patron", "casino_host", "clerk_counter", "clerk_talk", "host_station", "patron", "patron_talk", "pit_boss", "rowdy_patron", "staff"]
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
static var _scenario_layouts: Dictionary = {}
static var _maps_with_catalog_scenarios: Dictionary = {}
static var _surface_maps_loaded := false


static func classify(object_data: Dictionary, object_type: String = "", object_id: String = "", visual_prop: String = "") -> String:
	var clean_type := object_type.strip_edges().to_lower()
	# Merchandise owns a closed placement class so props and scenario visuals can
	# never consume its authored shelf row. Cage stock uses the same base item
	# record contract under a stable, index-addressed presentation identity.
	if clean_type == "item" or object_id.begins_with("cage_gift_item:"):
		return "shop_item"
	var explicit := str(object_data.get("placement_class", "")).strip_edges()
	if explicit in CLASSES:
		return explicit
	var clean_prop := visual_prop.strip_edges().to_lower()
	if clean_prop.is_empty():
		clean_prop = str(object_data.get("visual_prop", object_data.get("environment_prop", ""))).strip_edges().to_lower()
	# Event speakers describe who narrates or owns an interaction, not always the
	# physical object that receives it.  Concrete table props remain furniture
	# even when a staff/crew speaker supplies the dialogue (The Live Table is the
	# canonical case); otherwise the speaker role incorrectly wins below and
	# consumes behind-counter person capacity.
	if clean_type == "event" and clean_prop in ["card_table", "table"]:
		return "floor_fixture"
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
	return _with_runtime_slot_geometry(environment, _shipping_surface_map(environment))


static func _shipping_surface_map(environment: Dictionary) -> Dictionary:
	_ensure_surface_maps()
	var archetype_id := str(environment.get("archetype_id", environment.get("id", ""))).strip_edges()
	var layer_id := str(environment.get("current_layer_id", environment.get("layer_id", ""))).strip_edges()
	var layered_key := "%s:%s" % [archetype_id, layer_id]
	var map_key := layered_key if not layer_id.is_empty() and _surface_maps.has(layered_key) else archetype_id
	var base_map := _dict(_surface_maps.get(map_key, {}))
	var scenario_id := active_scenario_id(environment)
	var scenario_overrides := _dict(base_map.get("scenario_overrides", {}))
	var has_instance_layout := _scenario_layouts.has("%s::%s" % [map_key, scenario_id])
	if scenario_id.is_empty():
		var base_key := "%s::base" % map_key
		if _effective_surface_maps.has(base_key):
			return _dict(_effective_surface_maps.get(base_key, {}))
		var unreserved_map := base_map.duplicate(false)
		for field_value in SCENARIO_RESERVATION_FIELDS:
			unreserved_map.erase(str(field_value))
		var base_result := _with_scenario_instance_layout(map_key, scenario_id, unreserved_map)
		_effective_surface_maps[base_key] = base_result
		return base_result
	var effective_key := "%s::%s" % [map_key, scenario_id]
	if _effective_surface_maps.has(effective_key):
		return _dict(_effective_surface_maps.get(effective_key, {}))
	if not scenario_overrides.has(scenario_id) and not has_instance_layout:
		_effective_surface_maps[effective_key] = base_map
		return base_map
	var result := base_map.duplicate(false)
	var scenario_override := _dict(scenario_overrides.get(scenario_id, {}))
	var base_class_overrides := _dict(base_map.get("class_overrides", {})).duplicate(true)
	result.merge(scenario_override, true)
	if scenario_override.has("class_overrides"):
		base_class_overrides.merge(_dict(scenario_override.get("class_overrides", {})), true)
		result["class_overrides"] = base_class_overrides
	result = _with_scenario_instance_layout(map_key, scenario_id, result)
	_effective_surface_maps[effective_key] = result
	return result


static func active_scenario_id(environment: Dictionary) -> String:
	var scenario_state := _dict(environment.get("scenario_state", {}))
	var target_layer_id := str(scenario_state.get("layer_id", "")).strip_edges()
	var current_layer_id := str(environment.get("current_layer_id", environment.get("layer_id", ""))).strip_edges()
	# Layered venues retain one scenario cursor while the player visits another
	# floor. The retained cursor is progression state, not placement authority for
	# the non-target room.
	if not target_layer_id.is_empty() and target_layer_id != current_layer_id:
		return ""
	var scenario_id := str(scenario_state.get("id", environment.get("scenario_id", ""))).strip_edges()
	if scenario_id.is_empty():
		scenario_id = str(_dict(environment.get("scenario_sequence_state", {})).get("scenario_id", "")).strip_edges()
	return scenario_id


# Catalog scenario objects own exact, scenario-scoped slot instances. Shared
# runtime reserves remain available for injected delivery/chain records, while
# ordinary map-wide generic scenario pools are retired from catalog and clean
# no-scenario layouts.
static func _with_scenario_instance_layout(map_key: String, scenario_id: String, surface_data: Dictionary) -> Dictionary:
	var layout_key := "%s::%s" % [map_key, scenario_id]
	var layout := _dict(_scenario_layouts.get(layout_key, {}))
	var has_catalog_layouts := bool(_maps_with_catalog_scenarios.get(map_key, false))
	if layout.is_empty() and (not scenario_id.is_empty() or not has_catalog_layouts):
		return surface_data
	var result := surface_data.duplicate(true)
	var runtime_slots: Array = []
	for slot_value in _array(result.get("scenario_slots", [])):
		var slot := _dict(slot_value)
		if bool(slot.get("runtime_reserve", false)):
			runtime_slots.append(slot.duplicate(true))
	if layout.is_empty():
		result["scenario_slots"] = runtime_slots
		result["scenario_slot_ids"] = {}
		result["scenario_object_slot_ids"] = _filtered_slot_mapping(
			_dict(result.get("scenario_object_slot_ids", {})), runtime_slots
		)
		result["scenario_category_slot_ids"] = _filtered_slot_mapping(
			_dict(result.get("scenario_category_slot_ids", {})), runtime_slots
		)
		result["actor_routes"] = _filtered_actor_routes(_array(result.get("actor_routes", [])), runtime_slots)
		result["scenario_position_route_ids"] = _filtered_route_mapping(
			_dict(result.get("scenario_position_route_ids", {})), _array(result.get("actor_routes", []))
		)
		result["scenario_layout_id"] = "%s::base" % map_key
		result["scenario_layout_scoped"] = true
		return result
	var authored_slots := _array(layout.get("scenario_slots", [])).duplicate(true)
	authored_slots.append_array(runtime_slots)
	result["scenario_slots"] = authored_slots
	result["scenario_instance_slot_ids"] = _dict(layout.get("scenario_instance_slot_ids", {})).duplicate(true)
	result["scenario_instance_object_slot_ids"] = _dict(layout.get("scenario_instance_object_slot_ids", {})).duplicate(true)
	var scenario_family_ids := _dict(layout.get("scenario_instance_object_family_ids", {}))
	var object_family_ids := _dict(result.get("object_family_ids", {})).duplicate(true)
	object_family_ids.merge(scenario_family_ids, true)
	result["object_family_ids"] = object_family_ids
	for family in ["fixed", "event", "exit"]:
		var field := "%s_object_slot_ids" % family
		result[field] = _without_mapping_keys(_dict(result.get(field, {})), scenario_family_ids)
	result["fixed_objects"] = _without_fixed_declarations(
		_array(result.get("fixed_objects", [])), scenario_family_ids
	)
	# The older preference fields remain complete views for diagnostics and
	# callers that do not yet distinguish exact scenario instances.
	result["scenario_slot_ids"] = _dict(layout.get("scenario_instance_slot_ids", {})).duplicate(true)
	result["scenario_object_slot_ids"] = _dict(layout.get("scenario_instance_object_slot_ids", {})).duplicate(true)
	result["scenario_category_slot_ids"] = {}
	result["actor_routes"] = _array(layout.get("actor_routes", [])).duplicate(true)
	result["scenario_position_route_ids"] = _filtered_route_mapping(
		_dict(result.get("scenario_position_route_ids", {})), _array(result.get("actor_routes", []))
	)
	result["scenario_layout_id"] = str(layout.get("layout_id", layout_key))
	result["scenario_layout_scenario_id"] = scenario_id
	result["scenario_layout_display_name"] = str(layout.get("display_name", scenario_id))
	result["scenario_layout_scoped"] = true
	result["scenario_layout_audit"] = _dict(layout.get("audit", {})).duplicate(true)
	return result


static func _filtered_slot_mapping(source: Dictionary, slots: Array) -> Dictionary:
	var valid: Dictionary = {}
	for slot_value in slots:
		var slot_id := str(_dict(slot_value).get("id", "")).strip_edges()
		if not slot_id.is_empty():
			valid[slot_id] = true
	var result: Dictionary = {}
	for key_value in source.keys():
		var slot_id := str(source.get(key_value, "")).strip_edges()
		if valid.has(slot_id):
			result[str(key_value)] = slot_id
	return result


static func _without_mapping_keys(source: Dictionary, removed: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	for key_value in removed.keys():
		result.erase(str(key_value))
	return result


static func _without_fixed_declarations(source: Array, removed: Dictionary) -> Array:
	var result: Array = []
	for declaration_value in source:
		var declaration := _dict(declaration_value)
		if removed.has(str(declaration.get("object_id", ""))):
			continue
		result.append(declaration.duplicate(true))
	return result


static func _filtered_actor_routes(routes: Array, slots: Array) -> Array:
	var valid: Dictionary = {}
	for slot_value in slots:
		valid[str(_dict(slot_value).get("id", ""))] = true
	var result: Array = []
	for route_value in routes:
		var route := _dict(route_value)
		if valid.has(str(route.get("start_slot_id", ""))) and valid.has(str(route.get("end_slot_id", ""))):
			result.append(route.duplicate(true))
	return result


static func _filtered_route_mapping(source: Dictionary, routes: Array) -> Dictionary:
	var valid: Dictionary = {}
	for route_value in routes:
		var route_id := str(_dict(route_value).get("id", "")).strip_edges()
		if not route_id.is_empty():
			valid[route_id] = true
	var result: Dictionary = {}
	for key_value in source.keys():
		var route_id := str(source.get(key_value, "")).strip_edges()
		if valid.has(route_id):
			result[str(key_value)] = route_id
	return result


static func surface_map_by_id(archetype_id: String, layer_id: String = "") -> Dictionary:
	return surface_map({"archetype_id": archetype_id, "current_layer_id": layer_id})


static func slots_for_family(surface_data: Dictionary, family: String) -> Array:
	var collection := str(SLOT_COLLECTIONS.get(family, ""))
	return _array(surface_data.get(collection, [])).duplicate(true) if not collection.is_empty() else []


static func all_slots(surface_data: Dictionary) -> Array:
	var result: Array = []
	for family in SLOT_FAMILIES:
		result.append_array(slots_for_family(surface_data, str(family)))
	return result


static func slot_family(slot: Dictionary) -> String:
	var family := str(slot.get("kind", "")).strip_edges()
	var slot_id := str(slot.get("id", "")).strip_edges()
	return family if family in SLOT_FAMILIES and slot_id.begins_with("%s." % family) else ""


# Reusable slot geometry is already live through surface_map(), so locked slot
# moves persist when the overlay is disabled and in newly generated rooms.
static func authoring_surface_map(environment: Dictionary) -> Dictionary:
	return _with_developer_slots(environment, surface_map(environment))


# Applies developer-authored positions as the final authored slot layer. This
# changes placement inputs only; it never touches run state, visibility, or RNG.
static func _with_developer_slots(environment: Dictionary, surface_data: Dictionary) -> Dictionary:
	var slot_overrides := DeveloperPlacementStoreScript.slot_overrides(environment, "slot_positions")
	if slot_overrides.is_empty():
		return surface_data
	# Never modify the cached authored surface map. A local override must remain
	# scoped to its room and must disappear immediately when Reset clears it.
	var result := _with_slot_geometry(surface_data.duplicate(true), slot_overrides)
	result["developer_slot_positions"] = slot_overrides.duplicate(true)
	return result


# A locked reusable-slot edit is runtime authority on this machine immediately.
# Save to Project controls whether that same authority ships in future builds;
# it is not an activation step for the local authoring session.
static func _with_runtime_slot_geometry(environment: Dictionary, surface_data: Dictionary) -> Dictionary:
	var overrides := DeveloperPlacementStoreScript.slot_overrides(environment, "slot_positions")
	if overrides.is_empty():
		return surface_data
	var result := _with_slot_geometry(surface_data, overrides)
	result["developer_slot_positions"] = overrides.duplicate(true)
	return result


# A slot move is a rigid translation. Its stable id, class, size, support and
# priority remain authored authority while its contact point, hit rectangle and
# label anchor move together.
static func _with_slot_geometry(surface_data: Dictionary, overrides: Dictionary) -> Dictionary:
	if overrides.is_empty():
		return surface_data
	var result := surface_data.duplicate(true)
	for field in SLOT_COLLECTIONS.values():
		var translated: Array = []
		for slot_value in _array(result.get(field, [])):
			var slot := _dict(slot_value).duplicate(true)
			var slot_id := str(slot.get("id", "")).strip_edges()
			if slot_id.is_empty() or not overrides.has(slot_id):
				translated.append(slot)
				continue
			var original := _number_pair(slot.get("pos", []))
			var target := _vector(overrides.get(slot_id, []))
			if not is_finite(target.x) or not is_finite(target.y):
				translated.append(slot)
				continue
			var delta := target - original
			slot["pos"] = [target.x, target.y]
			var hit_values := _array(slot.get("hit_rect", [])).duplicate()
			if hit_values.size() >= 4:
				hit_values[0] = float(hit_values[0]) + delta.x
				hit_values[1] = float(hit_values[1]) + delta.y
				slot["hit_rect"] = hit_values
			var label_values := _array(slot.get("label_anchor", [])).duplicate()
			if label_values.size() >= 2:
				label_values[0] = float(label_values[0]) + delta.x
				label_values[1] = float(label_values[1]) + delta.y
				slot["label_anchor"] = label_values
			translated.append(slot)
		result[field] = translated
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
				if not _rect_has_point_inclusive(band, contact):
					continue
				# Raised and recessed stage bands are explicit grounded supports and
				# intentionally sit outside the main floor's contact range. The range
				# only constrains the broad floor bands. Accept authored feet on a
				# band's lower edge as well; Rect2.has_point excludes that edge.
				if str(band_key) == "stage_bands":
					return {"surface_id": "stage"}
				if contact.y >= contact_range.x - 0.5 and contact.y <= contact_range.y + 0.5:
					return {"surface_id": "floor"}
	elif placement_class in ["behind_counter_person", "surface_item", "shop_item"]:
		for counter_value in _array(surfaces.get("counters", [])):
			var counter := _dict(counter_value)
			var allowed_classes := _array(counter.get("classes", []))
			var support_class := "surface_item" if placement_class == "shop_item" else placement_class
			if not allowed_classes.is_empty() and support_class not in allowed_classes:
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
	if placement_class in ["surface_item", "shop_item"]:
		return "contact"
	return "feet" if placement_class in PERSON_CLASSES else "base"


static func _ensure_surface_maps() -> void:
	if _surface_maps_loaded:
		return
	_surface_maps_loaded = true
	_effective_surface_maps.clear()
	_scenario_layouts.clear()
	_maps_with_catalog_scenarios.clear()
	var file := FileAccess.open(SURFACE_MAP_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var root := _dict(parsed)
	if int(root.get("schema_version", 0)) != 3 or int(root.get("slot_schema_version", 0)) != SLOT_SCHEMA_VERSION:
		return
	for map_value in _array(root.get("maps", [])):
		var map_data := _dict(map_value)
		var map_id := str(map_data.get("id", ""))
		if not map_id.is_empty() and _surface_map_v2_valid(map_data):
			_surface_maps[map_id] = map_data
	var layout_file := FileAccess.open(SCENARIO_LAYOUT_PATH, FileAccess.READ)
	if layout_file == null:
		return
	var layout_parsed: Variant = JSON.parse_string(layout_file.get_as_text())
	layout_file.close()
	if typeof(layout_parsed) != TYPE_DICTIONARY:
		return
	var layout_root := _dict(layout_parsed)
	if int(layout_root.get("schema_version", 0)) != 1 \
			or int(layout_root.get("slot_schema_version", 0)) != SLOT_SCHEMA_VERSION:
		return
	for map_id_value in _array(layout_root.get("maps_with_catalog_scenarios", [])):
		_maps_with_catalog_scenarios[str(map_id_value)] = true
	for layout_value in _array(layout_root.get("layouts", [])):
		var layout := _dict(layout_value)
		var map_id := str(layout.get("map_id", "")).strip_edges()
		var scenario_id := str(layout.get("scenario_id", "")).strip_edges()
		if map_id.is_empty() or scenario_id.is_empty():
			continue
		_scenario_layouts["%s::%s" % [map_id, scenario_id]] = layout


static func _surface_map_v2_valid(map_data: Dictionary) -> bool:
	if int(map_data.get("slot_schema_version", 0)) != SLOT_SCHEMA_VERSION:
		return false
	var seen: Dictionary = {}
	var fixed_slot_ids: Dictionary = {}
	for family in SLOT_FAMILIES:
		var collection := str(SLOT_COLLECTIONS.get(family, ""))
		if typeof(map_data.get(collection)) != TYPE_ARRAY:
			return false
		for slot_value in _array(map_data.get(collection, [])):
			var slot := _dict(slot_value)
			var slot_id := str(slot.get("id", "")).strip_edges()
			if slot_id.is_empty() or seen.has(slot_id) or not slot_id.begins_with("%s." % family) \
					or str(slot.get("kind", "")) != family or str(slot.get("footprint_class", "")) not in CLASSES:
				return false
			seen[slot_id] = family
			if family == "fixed":
				fixed_slot_ids[slot_id] = true
	for family in SLOT_FAMILIES:
		for suffix in ["object_slot_ids", "category_slot_ids"]:
			var field := "%s_%s" % [family, suffix]
			if typeof(map_data.get(field)) != TYPE_DICTIONARY:
				return false
			for slot_id_value in _dict(map_data.get(field, {})).values():
				if str(seen.get(str(slot_id_value), "")) != family:
					return false
	if typeof(map_data.get("object_family_ids")) != TYPE_DICTIONARY or typeof(map_data.get("fixed_objects")) != TYPE_ARRAY:
		return false
	for family_value in _dict(map_data.get("object_family_ids", {})).values():
		if str(family_value) not in SLOT_FAMILIES:
			return false
	var fixed_object_ids: Dictionary = {}
	for declaration_value in _array(map_data.get("fixed_objects", [])):
		var declaration := _dict(declaration_value)
		var object_id := str(declaration.get("object_id", declaration.get("instance_object_id", ""))).strip_edges()
		var exact_slot_id := str(declaration.get("exact_slot_id", "")).strip_edges()
		if object_id.is_empty() or fixed_object_ids.has(object_id) or not fixed_slot_ids.has(exact_slot_id) \
				or typeof(declaration.get("required")) != TYPE_BOOL or typeof(declaration.get("action_ids")) != TYPE_ARRAY:
			return false
		fixed_object_ids[object_id] = true
	return true


static func _contact_point(rect: Rect2, placement_class: String) -> Vector2:
	if placement_class in ["wall_mounted", "hanging", "doorway"]:
		return rect.get_center()
	return Vector2(rect.get_center().x, rect.end.y)


static func _rect_has_point_inclusive(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x - 0.5 and point.x <= rect.end.x + 0.5 \
		and point.y >= rect.position.y - 0.5 and point.y <= rect.end.y + 0.5


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
