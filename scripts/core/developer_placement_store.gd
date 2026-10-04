class_name DeveloperPlacementStore
extends RefCounted

# Durable, non-simulation authoring overrides for environment slot placement.
#
# Schema v3 separates coordinates that belong to the room from coordinates that
# belong to one exact scenario layout:
#
# rooms[room_key].slot_positions
#     Shared fixed/event/exit slots and shared runtime-reserve scenario slots.
# rooms[room_key].scenario_layouts[scenario_id].slot_positions
#     Exact scenario-instance slots for that scenario only.
#
# A completed manual placement pass is explicit. `base_saved` records a saved
# no-scenario room and `scenario_layouts[scenario_id].saved` records a saved
# scenario context, including valid layouts that happen to contain zero slots.
const SCHEMA_VERSION := 3
const PROJECT_PATH := "res://data/environments/developer_placement_overrides.json"
const USER_PATH := "user://developer_environment_placements.json"
const REPORT_PATH := "user://BeatTheHouse_environment_slot_placement_changes.json"
const USER_PATH_ENV := "BTH_DEVELOPER_PLACEMENT_PATH"
const PROJECT_PATH_ENV := "BTH_PROJECT_PLACEMENT_PATH"
const REPORT_PATH_ENV := "BTH_DEVELOPER_PLACEMENT_REPORT_PATH"
const PLACEMENT_SURFACES_PATH := "res://data/environments/placement_surfaces.json"
const SCENARIO_LAYOUTS_PATH := "res://data/environments/scenario_slot_layouts.json"
const BASE_LAYOUT_ID := "__base"
const PersistencePathsScript := preload("res://scripts/core/persistence_paths.gd")
const DurableStoreScript := preload("res://scripts/core/durable_store.gd")
const BuildIdentityScript := preload("res://scripts/core/build_identity.gd")
const POSITION_FIELDS := ["slot_positions"]
const SHARED_SLOT_FAMILIES := ["fixed", "event", "exit"]

static var _loaded := false
static var _project_rooms: Dictionary = {}
static var _user_rooms: Dictionary = {}
static var _catalog_loaded := false
static var _surface_map_ids: Dictionary = {}
static var _shared_slot_ids_by_room: Dictionary = {}
static var _runtime_reserve_ids_by_room: Dictionary = {}
static var _catalog_scenario_ids_by_room: Dictionary = {}
static var _scenario_slot_ids_by_layout: Dictionary = {}
static var _expected_base_layout_ids: Array = []
static var _expected_scenario_layout_ids: Array = []
static var last_project_load_outcome: Dictionary = {}
static var last_user_load_outcome: Dictionary = {}


static func room_key(environment: Dictionary) -> String:
	var archetype_id := str(environment.get("archetype_id", environment.get("id", ""))).strip_edges()
	var layer_id := str(environment.get("current_layer_id", environment.get("layer_id", ""))).strip_edges()
	return archetype_id if layer_id.is_empty() else "%s:%s" % [archetype_id, layer_id]


static func active_scenario_id(environment: Dictionary) -> String:
	var scenario_state := _dict(environment.get("scenario_state", {}))
	var scenario_id := str(scenario_state.get("id", "")).strip_edges()
	var target_layer := str(scenario_state.get("layer_id", "")).strip_edges()
	var current_layer := str(environment.get("current_layer_id", environment.get("layer_id", ""))).strip_edges()
	if not target_layer.is_empty() and current_layer != target_layer:
		return ""
	if scenario_id.is_empty():
		scenario_id = str(environment.get("scenario_id", "")).strip_edges()
	if scenario_id.is_empty():
		scenario_id = str(_dict(environment.get("scenario_sequence_state", {})).get("scenario_id", "")).strip_edges()
	return "" if scenario_id in [BASE_LAYOUT_ID, "__default", "__none", "base"] else scenario_id


static func layout_id(environment: Dictionary) -> String:
	var key := room_key(environment)
	var scenario_id := active_scenario_id(environment)
	return "%s::%s" % [key, BASE_LAYOUT_ID if scenario_id.is_empty() else scenario_id]


# Effective placement authority for the active context. Only the shared room
# coordinates and the active scenario's exact coordinates are merged.
static func slot_overrides(environment: Dictionary, field: String = "slot_positions") -> Dictionary:
	if field not in POSITION_FIELDS:
		return {}
	_ensure_loaded()
	var result := _room_slot_overrides(_project_rooms, environment, field)
	result.merge(_room_slot_overrides(_user_rooms, environment, field), true)
	return result


static func project_slot_overrides(environment: Dictionary, field: String = "slot_positions") -> Dictionary:
	if field not in POSITION_FIELDS:
		return {}
	_ensure_loaded()
	return _room_slot_overrides(_project_rooms, environment, field)


static func user_slot_overrides(environment: Dictionary, field: String = "slot_positions") -> Dictionary:
	if field not in POSITION_FIELDS:
		return {}
	_ensure_loaded()
	return _room_slot_overrides(_user_rooms, environment, field)


static func shared_slot_overrides(environment: Dictionary, field: String = "slot_positions") -> Dictionary:
	if field not in POSITION_FIELDS:
		return {}
	_ensure_loaded()
	var key := room_key(environment)
	var result := _positions(_dict(_project_rooms.get(key, {})).get(field, {})).duplicate(true)
	result.merge(_positions(_dict(_user_rooms.get(key, {})).get(field, {})), true)
	return result


static func scenario_slot_overrides(
	environment: Dictionary,
	scenario_id: String = "",
	field: String = "slot_positions"
) -> Dictionary:
	if field not in POSITION_FIELDS:
		return {}
	_ensure_loaded()
	var clean_scenario_id := scenario_id.strip_edges()
	if clean_scenario_id.is_empty():
		clean_scenario_id = active_scenario_id(environment)
	if clean_scenario_id.is_empty():
		return {}
	var key := room_key(environment)
	var result := _scenario_positions(_project_rooms, key, clean_scenario_id, field)
	result.merge(_scenario_positions(_user_rooms, key, clean_scenario_id, field), true)
	return result


# Single-slot edits remain available for drag locking. They mark the affected
# context as needing an explicit Save Layout press.
static func save_position(
	environment: Dictionary,
	field: String,
	object_id: String,
	position: Vector2
) -> Dictionary:
	if field not in POSITION_FIELDS:
		return {"ok": false, "error": "Unsupported placement collection."}
	var key := room_key(environment)
	var clean_id := object_id.strip_edges()
	if key.is_empty() or clean_id.is_empty() or not is_finite(position.x) or not is_finite(position.y):
		return {"ok": false, "error": "Placement identity and position must be valid."}
	var scenario_id := active_scenario_id(environment)
	var scope := _slot_scope(key, scenario_id, clean_id)
	if scope == "scenario_missing":
		return {"ok": false, "error": "Scenario-specific placement requires an active scenario."}
	if scope == "unsupported":
		return {"ok": false, "error": "Unsupported placement slot family."}
	_ensure_loaded()
	var previous_user_rooms := _user_rooms.duplicate(true)
	var room := _dict(_user_rooms.get(key, {})).duplicate(true)
	var normalized := [snappedf(position.x, 1.0), snappedf(position.y, 1.0)]
	if scope == "shared":
		var previous_effective := _effective_shared_positions(key, room, field)
		var slots := _positions(room.get(field, {})).duplicate(true)
		slots[clean_id] = normalized
		room[field] = slots
		if previous_effective != _effective_shared_positions(key, room, field):
			room = _invalidate_shared_layout_completion(key, room)
		room = _reconcile_project_completion_shadows(key, room, field)
	else:
		var layouts := _dict(room.get("scenario_layouts", {})).duplicate(true)
		var scenario_layout := _dict(layouts.get(scenario_id, {})).duplicate(true)
		var slots := _positions(scenario_layout.get(field, {})).duplicate(true)
		var previous_effective := _effective_scenario_positions(
			key, scenario_id, slots, field
		)
		slots[clean_id] = normalized
		scenario_layout[field] = slots
		if previous_effective != _effective_scenario_positions(key, scenario_id, slots, field):
			var geometry_differs := _shared_geometry_differs_from_project(key, room, field) \
					or _scenario_geometry_differs_from_project(key, scenario_id, slots, field)
			if geometry_differs:
				scenario_layout["saved"] = false
			else:
				scenario_layout.erase("saved")
		layouts[scenario_id] = scenario_layout
		room["scenario_layouts"] = layouts
	_user_rooms[key] = room
	var save_error := _write_payload(user_path(), _user_rooms)
	if save_error != OK:
		_user_rooms = previous_user_rooms
	return {
		"ok": save_error == OK,
		"error": "" if save_error == OK else "Could not save developer placement overrides.",
		"path": user_path(),
		"room_key": key,
		"layout_id": "%s::%s" % [key, BASE_LAYOUT_ID if scope == "shared" else scenario_id],
		"scenario_id": scenario_id if scope == "scenario" else "",
		"scope": scope,
		"field": field,
		"object_id": clean_id,
		"position": normalized,
	}


static func clear_position(environment: Dictionary, field: String, object_id: String) -> Dictionary:
	if field not in POSITION_FIELDS:
		return {"ok": false, "error": "Unsupported placement collection."}
	var key := room_key(environment)
	var clean_id := object_id.strip_edges()
	if key.is_empty() or clean_id.is_empty():
		return {"ok": false, "error": "Placement identity must be valid."}
	var scenario_id := active_scenario_id(environment)
	var scope := _slot_scope(key, scenario_id, clean_id)
	if scope == "scenario_missing":
		return {"ok": false, "error": "Scenario-specific placement requires an active scenario."}
	if scope == "unsupported":
		return {"ok": false, "error": "Unsupported placement slot family."}
	_ensure_loaded()
	var previous_user_rooms := _user_rooms.duplicate(true)
	var room := _dict(_user_rooms.get(key, {})).duplicate(true)
	if scope == "shared":
		var previous_effective := _effective_shared_positions(key, room, field)
		var slots := _positions(room.get(field, {})).duplicate(true)
		slots.erase(clean_id)
		if slots.is_empty():
			room.erase(field)
		else:
			room[field] = slots
		if previous_effective != _effective_shared_positions(key, room, field):
			room = _invalidate_shared_layout_completion(key, room)
		room = _reconcile_project_completion_shadows(key, room, field)
	else:
		var layouts := _dict(room.get("scenario_layouts", {})).duplicate(true)
		var scenario_layout := _dict(layouts.get(scenario_id, {})).duplicate(true)
		var had_completion_shadow := scenario_layout.has("saved")
		var slots := _positions(scenario_layout.get(field, {})).duplicate(true)
		slots.erase(clean_id)
		if slots.is_empty():
			scenario_layout.erase(field)
		else:
			scenario_layout[field] = slots
		var project_layout := _dict(
			_dict(_dict(_project_rooms.get(key, {})).get("scenario_layouts", {})).get(scenario_id, {})
		)
		var geometry_differs := _shared_geometry_differs_from_project(key, room, field) \
				or _scenario_geometry_differs_from_project(key, scenario_id, slots, field)
		if geometry_differs and (
			had_completion_shadow
			or bool(project_layout.get("saved", false))
			or not slots.is_empty()
		):
			scenario_layout["saved"] = false
		else:
			scenario_layout.erase("saved")
		if scenario_layout.is_empty():
			layouts.erase(scenario_id)
		else:
			layouts[scenario_id] = scenario_layout
		if layouts.is_empty():
			room.erase("scenario_layouts")
		else:
			room["scenario_layouts"] = layouts
		room = _reconcile_project_completion_shadows(key, room, field)
	if room.is_empty():
		_user_rooms.erase(key)
	else:
		_user_rooms[key] = room
	var save_error := _write_payload(user_path(), _user_rooms)
	if save_error != OK:
		_user_rooms = previous_user_rooms
	return {
		"ok": save_error == OK,
		"error": "" if save_error == OK else "Could not reset the developer placement.",
		"path": user_path(),
		"room_key": key,
		"layout_id": "%s::%s" % [key, BASE_LAYOUT_ID if scope == "shared" else scenario_id],
		"scenario_id": scenario_id if scope == "scenario" else "",
		"scope": scope,
		"field": field,
		"object_id": clean_id,
	}


# Saves the complete visible slot snapshot for one manual-placement context.
# Shared slot coordinates replace the room snapshot. Scenario coordinates replace
# only the active scenario snapshot. Unknown legacy/non-slot identities are
# rejected so they cannot leak into placement authority or make an incomplete
# manual pass look complete.
static func save_layout(
	environment: Dictionary,
	full_positions: Dictionary,
	field: String = "slot_positions"
) -> Dictionary:
	if field not in POSITION_FIELDS:
		return _save_layout_error("Unsupported placement collection.")
	var key := room_key(environment)
	if key.is_empty():
		return _save_layout_error("Environment placement identity must be valid.")
	var scenario_id := active_scenario_id(environment)
	_ensure_catalog()
	if not _surface_map_ids.has(key):
		return _save_layout_error("The current environment has no authored placement layout.")
	if not scenario_id.is_empty() \
			and not _dict(_catalog_scenario_ids_by_room.get(key, {})).has(scenario_id):
		return _save_layout_error("The current scenario has no authored placement layout.")
	if scenario_id.is_empty() and not _expected_base_layout_ids.has("%s::%s" % [key, BASE_LAYOUT_ID]):
		return _save_layout_error("The current environment is a source template, not a playable placement layout.")
	var shared_positions: Dictionary = {}
	var scenario_positions: Dictionary = {}
	var ignored_slot_ids: Array = []
	var slot_ids := full_positions.keys()
	slot_ids.sort()
	for slot_value in slot_ids:
		var slot_id := str(slot_value).strip_edges()
		var normalized := _normalized_position(full_positions.get(slot_value))
		if slot_id.is_empty() or normalized.is_empty():
			return _save_layout_error("Every saved slot requires a valid identity and finite position.", [slot_id])
		var scope := _slot_scope(key, scenario_id, slot_id)
		if scope == "shared":
			shared_positions[slot_id] = normalized
		elif scope == "scenario":
			scenario_positions[slot_id] = normalized
		else:
			ignored_slot_ids.append(slot_id)
	if not ignored_slot_ids.is_empty():
		return _save_layout_error("The layout contains slot identities outside its authored placement authority.", ignored_slot_ids)
	var missing_slot_ids: Array = []
	for slot_id_value in _dict(_shared_slot_ids_by_room.get(key, {})).keys():
		if not shared_positions.has(slot_id_value):
			missing_slot_ids.append(str(slot_id_value))
	if not scenario_id.is_empty():
		var exact_layout_id := "%s::%s" % [key, scenario_id]
		for slot_id_value in _dict(_scenario_slot_ids_by_layout.get(exact_layout_id, {})).keys():
			if not scenario_positions.has(slot_id_value):
				missing_slot_ids.append(str(slot_id_value))
	if not missing_slot_ids.is_empty():
		missing_slot_ids.sort()
		return _save_layout_error("The layout snapshot is missing authored slots.", missing_slot_ids)
	_ensure_loaded()
	var previous_user_rooms := _user_rooms.duplicate(true)
	var room := _dict(_user_rooms.get(key, {})).duplicate(true)
	var previous_shared_positions := _positions(
		_dict(_project_rooms.get(key, {})).get(field, {})
	).duplicate(true)
	previous_shared_positions.merge(_positions(room.get(field, {})), true)
	var shared_positions_changed := previous_shared_positions != shared_positions
	if shared_positions.is_empty():
		room.erase(field)
	else:
		room[field] = shared_positions
	if shared_positions_changed:
		room = _invalidate_shared_layout_completion(key, room)
	var scope := "base"
	if scenario_id.is_empty():
		room["base_saved"] = true
	else:
		scope = "scenario"
		var layouts := _dict(room.get("scenario_layouts", {})).duplicate(true)
		var scenario_layout := _dict(layouts.get(scenario_id, {})).duplicate(true)
		if scenario_positions.is_empty():
			scenario_layout.erase(field)
		else:
			scenario_layout[field] = scenario_positions
		scenario_layout["saved"] = true
		layouts[scenario_id] = scenario_layout
		room["scenario_layouts"] = layouts
	room = _reconcile_project_completion_shadows(key, room, field)
	_user_rooms[key] = room
	var save_error := _write_payload(user_path(), _user_rooms)
	if save_error != OK:
		_user_rooms = previous_user_rooms
	return {
		"ok": save_error == OK,
		"error": "" if save_error == OK else "Could not save the complete environment layout.",
		"path": user_path(),
		"room_key": key,
		"layout_id": "%s::%s" % [key, BASE_LAYOUT_ID if scenario_id.is_empty() else scenario_id],
		"scenario_id": scenario_id,
		"scope": scope,
		"saved": save_error == OK,
		"shared_slot_count": shared_positions.size(),
		"scenario_slot_count": scenario_positions.size(),
		"slot_count": shared_positions.size() + scenario_positions.size(),
		"ignored_slot_ids": ignored_slot_ids,
	}


static func layout_saved(environment: Dictionary, scenario_id: String = "") -> bool:
	_ensure_loaded()
	var clean_scenario_id := scenario_id.strip_edges()
	if clean_scenario_id.is_empty():
		clean_scenario_id = active_scenario_id(environment)
	var key := room_key(environment)
	var user_room := _dict(_user_rooms.get(key, {}))
	var project_room := _dict(_project_rooms.get(key, {}))
	if clean_scenario_id.is_empty():
		if user_room.has("base_saved"):
			return bool(user_room.get("base_saved", false))
		return bool(project_room.get("base_saved", false))
	var user_layout := _dict(_dict(user_room.get("scenario_layouts", {})).get(clean_scenario_id, {}))
	if user_layout.has("saved"):
		return bool(user_layout.get("saved", false))
	var project_layout := _dict(_dict(project_room.get("scenario_layouts", {})).get(clean_scenario_id, {}))
	return bool(project_layout.get("saved", false))


# Shared fixed/event/exit/reserve geometry participates in every layout for a
# room. Moving or resetting any shared slot therefore invalidates every
# previously reviewed context whose composition may have changed, not only the
# base marker. Unsaved contexts remain absent instead of creating noisy rows.
static func _invalidate_shared_layout_completion(key: String, room: Dictionary) -> Dictionary:
	var result := room.duplicate(true)
	result["base_saved"] = false
	var layouts := _dict(result.get("scenario_layouts", {})).duplicate(true)
	var project_layouts := _dict(_dict(_project_rooms.get(key, {})).get("scenario_layouts", {}))
	var scenario_ids: Dictionary = {}
	for scenario_value in _dict(_catalog_scenario_ids_by_room.get(key, {})).keys():
		scenario_ids[str(scenario_value)] = true
	for scenario_value in layouts.keys():
		scenario_ids[str(scenario_value)] = true
	for scenario_value in project_layouts.keys():
		scenario_ids[str(scenario_value)] = true
	for scenario_value in scenario_ids.keys():
		var scenario_id := str(scenario_value).strip_edges()
		if scenario_id.is_empty():
			continue
		var scenario_layout := _dict(layouts.get(scenario_id, {})).duplicate(true)
		var project_layout := _dict(project_layouts.get(scenario_id, {}))
		var was_saved := bool(scenario_layout.get("saved", false)) \
				if scenario_layout.has("saved") else bool(project_layout.get("saved", false))
		if not was_saved:
			continue
		scenario_layout["saved"] = false
		layouts[scenario_id] = scenario_layout
	if layouts.is_empty():
		result.erase("scenario_layouts")
	else:
		result["scenario_layouts"] = layouts
	return result


# Reconcile completion markers after coordinates are saved or reset. This is
# geometry-based rather than presence-based: complete local snapshots may
# legitimately retain many project-identical rows. A true local marker remains
# valid only while its complete snapshot is still present; otherwise committed
# project authority is restored, or the locally changed layout becomes false.
static func _reconcile_project_completion_shadows(
	key: String,
	room: Dictionary,
	field: String = "slot_positions"
) -> Dictionary:
	var result := room.duplicate(true)
	var shared_differs := _shared_geometry_differs_from_project(key, result, field)
	var local_shared_complete := _position_ids_match(
		result.get(field, {}),
		_dict(_shared_slot_ids_by_room.get(key, {}))
	)
	if result.has("base_saved"):
		if bool(result.get("base_saved", false)) and not local_shared_complete:
			if shared_differs:
				result["base_saved"] = false
			else:
				result.erase("base_saved")
		elif not bool(result.get("base_saved", false)) and not shared_differs:
			result.erase("base_saved")
	var layouts := _dict(result.get("scenario_layouts", {})).duplicate(true)
	for scenario_value in layouts.keys():
		var scenario_id := str(scenario_value)
		var scenario_layout := _dict(layouts.get(scenario_id, {})).duplicate(true)
		var scenario_differs := _scenario_geometry_differs_from_project(
			key,
			scenario_id,
			_positions(scenario_layout.get(field, {})),
			field
		)
		var exact_layout_id := "%s::%s" % [key, scenario_id]
		var local_scenario_complete := _position_ids_match(
			scenario_layout.get(field, {}),
			_dict(_scenario_slot_ids_by_layout.get(exact_layout_id, {}))
		)
		if scenario_layout.has("saved"):
			if bool(scenario_layout.get("saved", false)) \
					and (not local_shared_complete or not local_scenario_complete):
				if shared_differs or scenario_differs:
					scenario_layout["saved"] = false
				else:
					scenario_layout.erase("saved")
			elif not bool(scenario_layout.get("saved", false)) \
					and not shared_differs \
					and not scenario_differs:
				scenario_layout.erase("saved")
		if scenario_layout.is_empty():
			layouts.erase(scenario_id)
		else:
			layouts[scenario_id] = scenario_layout
	if layouts.is_empty():
		result.erase("scenario_layouts")
	else:
		result["scenario_layouts"] = layouts
	return result


static func _shared_geometry_differs_from_project(
	key: String,
	room: Dictionary,
	field: String = "slot_positions"
) -> bool:
	var project_positions := _positions(
		_dict(_project_rooms.get(key, {})).get(field, {})
	)
	return _effective_shared_positions(key, room, field) != project_positions


static func _effective_shared_positions(
	key: String,
	room: Dictionary,
	field: String = "slot_positions"
) -> Dictionary:
	var result := _positions(
		_dict(_project_rooms.get(key, {})).get(field, {})
	).duplicate(true)
	result.merge(_positions(room.get(field, {})), true)
	return result


static func _scenario_geometry_differs_from_project(
	key: String,
	scenario_id: String,
	local_positions: Dictionary,
	field: String = "slot_positions"
) -> bool:
	var project_positions := _scenario_positions(
		_project_rooms, key, scenario_id, field
	)
	return _effective_scenario_positions(key, scenario_id, local_positions, field) != project_positions


static func _effective_scenario_positions(
	key: String,
	scenario_id: String,
	local_positions: Dictionary,
	field: String = "slot_positions"
) -> Dictionary:
	var result := _scenario_positions(
		_project_rooms, key, scenario_id, field
	).duplicate(true)
	result.merge(local_positions, true)
	return result


static func promote_user_overrides() -> Dictionary:
	_ensure_loaded()
	var merged := _project_rooms.duplicate(true)
	var authored_keys := _user_rooms.keys()
	authored_keys.sort()
	for key_value in authored_keys:
		var key := str(key_value)
		var room := _dict(merged.get(key, {})).duplicate(true)
		var authored_room := _dict(_user_rooms.get(key, {}))
		var slots := _positions(room.get("slot_positions", {})).duplicate(true)
		slots.merge(_positions(authored_room.get("slot_positions", {})), true)
		if not slots.is_empty():
			room["slot_positions"] = slots
		if authored_room.has("base_saved"):
			room["base_saved"] = bool(authored_room.get("base_saved", false))
		var layouts := _dict(room.get("scenario_layouts", {})).duplicate(true)
		var authored_layouts := _dict(authored_room.get("scenario_layouts", {}))
		var scenario_ids := authored_layouts.keys()
		scenario_ids.sort()
		for scenario_value in scenario_ids:
			var scenario_id := str(scenario_value)
			var scenario_layout := _dict(layouts.get(scenario_id, {})).duplicate(true)
			var authored_layout := _dict(authored_layouts.get(scenario_id, {}))
			var scenario_slots := _positions(scenario_layout.get("slot_positions", {})).duplicate(true)
			scenario_slots.merge(_positions(authored_layout.get("slot_positions", {})), true)
			if not scenario_slots.is_empty():
				scenario_layout["slot_positions"] = scenario_slots
			if authored_layout.has("saved"):
				scenario_layout["saved"] = bool(authored_layout.get("saved", false))
			layouts[scenario_id] = scenario_layout
		if not layouts.is_empty():
			room["scenario_layouts"] = layouts
		merged[key] = room
	var output_path := project_path()
	var save_error := _write_payload(output_path, merged)
	if save_error == OK:
		_project_rooms = merged
	return {
		"ok": save_error == OK,
		"error": "" if save_error == OK else "The project placement file is not writable in this build. The local locked placement is still saved.",
		"path": output_path,
		"room_count": merged.size(),
		"slot_count": _slot_count(merged),
	}


static func coverage_snapshot() -> Dictionary:
	_ensure_loaded()
	_ensure_catalog()
	var saved_base: Dictionary = {}
	var saved_scenarios: Dictionary = {}
	var room_keys: Dictionary = {}
	for room_value in _project_rooms.keys():
		room_keys[str(room_value)] = true
	for room_value in _user_rooms.keys():
		room_keys[str(room_value)] = true
	for room_value in room_keys.keys():
		var key := str(room_value).strip_edges()
		var project_room := _dict(_project_rooms.get(key, {}))
		var user_room := _dict(_user_rooms.get(key, {}))
		var base_saved := bool(user_room.get("base_saved", false)) \
				if user_room.has("base_saved") else bool(project_room.get("base_saved", false))
		if base_saved:
			saved_base["%s::%s" % [key, BASE_LAYOUT_ID]] = true
		var project_layouts := _dict(project_room.get("scenario_layouts", {}))
		var user_layouts := _dict(user_room.get("scenario_layouts", {}))
		var scenario_ids: Dictionary = {}
		for scenario_value in project_layouts.keys():
			scenario_ids[str(scenario_value)] = true
		for scenario_value in user_layouts.keys():
			scenario_ids[str(scenario_value)] = true
		for scenario_value in scenario_ids.keys():
			var scenario_id := str(scenario_value).strip_edges()
			var project_layout := _dict(project_layouts.get(scenario_id, {}))
			var user_layout := _dict(user_layouts.get(scenario_id, {}))
			var scenario_saved := bool(user_layout.get("saved", false)) \
					if user_layout.has("saved") else bool(project_layout.get("saved", false))
			if not scenario_id.is_empty() and scenario_saved:
				saved_scenarios["%s::%s" % [key, scenario_id]] = true
	var expected_base := _array_to_set(_expected_base_layout_ids)
	var expected_scenarios := _array_to_set(_expected_scenario_layout_ids)
	var missing_base := _missing_ids(_expected_base_layout_ids, saved_base)
	var missing_scenarios := _missing_ids(_expected_scenario_layout_ids, saved_scenarios)
	var unexpected: Array = []
	for saved_id_value in saved_base.keys():
		if not expected_base.has(saved_id_value):
			unexpected.append(str(saved_id_value))
	for saved_id_value in saved_scenarios.keys():
		if not expected_scenarios.has(saved_id_value):
			unexpected.append(str(saved_id_value))
	unexpected.sort()
	var missing := missing_base.duplicate()
	missing.append_array(missing_scenarios)
	missing.sort()
	var missing_set := _array_to_set(missing)
	var next_missing_layout_id := ""
	for layout_id_value in _manual_pass_layout_order():
		var ordered_layout_id := str(layout_id_value)
		if missing_set.has(ordered_layout_id):
			next_missing_layout_id = ordered_layout_id
			break
	var saved_base_count := _expected_saved_count(_expected_base_layout_ids, saved_base)
	var saved_scenario_count := _expected_saved_count(_expected_scenario_layout_ids, saved_scenarios)
	return {
		"expected_base_layout_count": _expected_base_layout_ids.size(),
		"expected_scenario_layout_count": _expected_scenario_layout_ids.size(),
		"expected_layout_count": _expected_base_layout_ids.size() + _expected_scenario_layout_ids.size(),
		"saved_base_layout_count": saved_base_count,
		"saved_scenario_layout_count": saved_scenario_count,
		"saved_layout_count": saved_base_count + saved_scenario_count,
		"missing_base_layout_ids": missing_base,
		"missing_scenario_layout_ids": missing_scenarios,
		"missing_layout_ids": missing,
		"next_missing_layout_id": next_missing_layout_id,
		"unexpected_layout_ids": unexpected,
		"complete": missing.is_empty(),
	}


# Interleave each base room with its exact scenarios. This keeps a 75-layout
# owner pass moving through one environment at a time instead of jumping from
# all base rooms to an unrelated alphabetic scenario list.
static func _manual_pass_layout_order() -> Array:
	var result: Array = []
	for base_layout_value in _expected_base_layout_ids:
		var base_layout_id := str(base_layout_value)
		result.append(base_layout_id)
		var separator := base_layout_id.rfind("::")
		var room_prefix := base_layout_id.left(separator + 2) if separator >= 0 else ""
		for scenario_layout_value in _expected_scenario_layout_ids:
			var scenario_layout_id := str(scenario_layout_value)
			if not room_prefix.is_empty() and scenario_layout_id.begins_with(room_prefix):
				result.append(scenario_layout_id)
	return result


static func export_user_overrides() -> Dictionary:
	_ensure_loaded()
	# The handoff must be self-contained. Export the effective reviewed authority,
	# not only machine-local differences whose completion flags may be inherited
	# from a committed baseline that the recipient cannot reconstruct.
	var local_rooms := _exportable_user_rooms()
	var exported_rooms := _exportable_effective_rooms()
	var coverage := coverage_snapshot()
	var output_path := report_path()
	var absolute_path := ProjectSettings.globalize_path(output_path)
	var slot_count := _slot_count(exported_rooms)
	var local_slot_count := _slot_count(local_rooms)
	var build_identity := BuildIdentityScript.telemetry_identity()
	var report_metadata := {
		"schema": "beat_the_house.environment_placement_report/v1",
		"report_scope": "effective_reviewed_authority",
		"generated_at_utc": Time.get_datetime_string_from_system(true, true),
		"build_version": BuildIdentityScript.display_version(),
		"source_commit": str(build_identity.get("source_commit", "")),
		"source_tree": str(build_identity.get("source_tree", "")),
		"platform": str(build_identity.get("platform", OS.get_name())),
		"identity_source": str(build_identity.get("identity_source", "development_source")),
		"placement_surfaces_sha256": FileAccess.get_sha256(PLACEMENT_SURFACES_PATH),
		"scenario_slot_layouts_sha256": FileAccess.get_sha256(SCENARIO_LAYOUTS_PATH),
		"effective_room_count": exported_rooms.size(),
		"effective_slot_count": slot_count,
		"local_room_count": local_rooms.size(),
		"local_slot_count": local_slot_count,
	}
	var save_error := _write_payload(output_path, exported_rooms, {
		"coverage": coverage,
		"report_metadata": report_metadata,
	})
	var warning := ""
	if save_error == OK:
		var backup_absolute := ProjectSettings.globalize_path(DurableStoreScript.backup_path(output_path))
		if FileAccess.file_exists(backup_absolute):
			var backup_error := DirAccess.remove_absolute(backup_absolute)
			if backup_error != OK:
				warning = "The current report was exported, but its older backup could not be removed."
	return {
		"ok": save_error == OK,
		"error": "" if save_error == OK else "Could not export the environment slot placement report.",
		"warning": warning,
		"path": output_path,
		"absolute_path": absolute_path,
		"room_count": exported_rooms.size(),
		"slot_count": slot_count,
		"local_room_count": local_rooms.size(),
		"local_slot_count": local_slot_count,
		"report_metadata": report_metadata,
		"coverage": coverage,
		"saved_layout_count": int(coverage.get("saved_layout_count", 0)),
		"expected_layout_count": int(coverage.get("expected_layout_count", 0)),
		"missing_layout_count": _array(coverage.get("missing_layout_ids", [])).size(),
		"complete": bool(coverage.get("complete", false)),
	}


static func reload() -> void:
	_loaded = false
	_project_rooms = {}
	_user_rooms = {}
	_ensure_loaded()


static func user_path() -> String:
	var override := OS.get_environment(USER_PATH_ENV).strip_edges()
	if not override.is_empty():
		return override
	return PersistencePathsScript.file_path(USER_PATH, "developer_environment_placements.json")


static func project_path() -> String:
	var override := OS.get_environment(PROJECT_PATH_ENV).strip_edges()
	return PROJECT_PATH if override.is_empty() else override


static func report_path() -> String:
	var override := OS.get_environment(REPORT_PATH_ENV).strip_edges()
	if not override.is_empty():
		return override
	return PersistencePathsScript.file_path(
		REPORT_PATH,
		"BeatTheHouse_environment_slot_placement_changes.json"
	)


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var project_result := _read_rooms(project_path())
	last_project_load_outcome = _dict(project_result.get("outcome", {})).duplicate(true)
	_project_rooms = _dict(project_result.get("rooms", {})).duplicate(true)
	var user_result := _read_rooms(user_path())
	last_user_load_outcome = _dict(user_result.get("outcome", {})).duplicate(true)
	_user_rooms = _dict(user_result.get("rooms", {})).duplicate(true)


static func _read_rooms(path: String) -> Dictionary:
	var result := DurableStoreScript.read_json(
		path,
		func(payload: Dictionary) -> bool: return _placement_payload_valid(payload)
	)
	if not bool(result.get("ok", false)):
		return {"rooms": {}, "outcome": result}
	return {
		"rooms": _dict(_dict(result.get("data", {})).get("rooms", {})).duplicate(true),
		"outcome": result,
	}


static func _write_payload(path: String, rooms: Dictionary, extra_fields: Dictionary = {}) -> Error:
	var payload := {"schema_version": SCHEMA_VERSION, "rooms": rooms}
	payload.merge(extra_fields, true)
	var result := DurableStoreScript.write_json(
		path,
		payload,
		func(value: Dictionary) -> bool: return _placement_payload_valid(value)
	)
	return int(result.get("error", FAILED))


static func _placement_payload_valid(payload: Dictionary) -> bool:
	_ensure_catalog()
	if int(payload.get("schema_version", 0)) != SCHEMA_VERSION:
		return false
	if typeof(payload.get("rooms", {})) != TYPE_DICTIONARY:
		return false
	if payload.has("coverage") and typeof(payload.get("coverage")) != TYPE_DICTIONARY:
		return false
	if payload.has("report_metadata") and typeof(payload.get("report_metadata")) != TYPE_DICTIONARY:
		return false
	for room_key_value in _dict(payload.get("rooms", {})).keys():
		var raw_room_key := str(room_key_value)
		var room_key_value_clean := raw_room_key.strip_edges()
		if raw_room_key != room_key_value_clean or room_key_value_clean.is_empty() or not _surface_map_ids.has(room_key_value_clean):
			return false
		if not _expected_base_layout_ids.has("%s::%s" % [room_key_value_clean, BASE_LAYOUT_ID]):
			# Source-only placement templates are not authorable runtime rooms and
			# must never enter a promoted/exported owner report.
			return false
		var room_value: Variant = _dict(payload.get("rooms", {})).get(room_key_value)
		if typeof(room_value) != TYPE_DICTIONARY or not _room_payload_valid(room_value as Dictionary, room_key_value_clean):
			return false
	return true


static func _room_payload_valid(room: Dictionary, key: String) -> bool:
	for field_value in room.keys():
		if str(field_value) not in ["slot_positions", "base_saved", "scenario_layouts"]:
			return false
	if room.has("base_saved") and typeof(room.get("base_saved")) != TYPE_BOOL:
		return false
	if room.has("slot_positions") and not _positions_valid(room.get("slot_positions"), key):
		return false
	if bool(room.get("base_saved", false)) \
			and not _position_ids_match(room.get("slot_positions", {}), _dict(_shared_slot_ids_by_room.get(key, {}))):
		return false
	if room.has("scenario_layouts") and typeof(room.get("scenario_layouts")) != TYPE_DICTIONARY:
		return false
	for scenario_value in _dict(room.get("scenario_layouts", {})).keys():
		var raw_scenario_id := str(scenario_value)
		var scenario_id := raw_scenario_id.strip_edges()
		var exact_layout_id := "%s::%s" % [key, scenario_id]
		if raw_scenario_id != scenario_id or scenario_id.is_empty() or not _scenario_slot_ids_by_layout.has(exact_layout_id):
			return false
		var layout_value: Variant = _dict(room.get("scenario_layouts", {})).get(scenario_value)
		if typeof(layout_value) != TYPE_DICTIONARY:
			return false
		var scenario_layout := layout_value as Dictionary
		for field_value in scenario_layout.keys():
			if str(field_value) not in ["slot_positions", "saved"]:
				return false
		if scenario_layout.has("saved") and typeof(scenario_layout.get("saved")) != TYPE_BOOL:
			return false
		if scenario_layout.has("slot_positions") and not _positions_valid(scenario_layout.get("slot_positions"), key, scenario_id):
			return false
		if bool(scenario_layout.get("saved", false)):
			if not _position_ids_match(room.get("slot_positions", {}), _dict(_shared_slot_ids_by_room.get(key, {}))):
				return false
			if not _position_ids_match(scenario_layout.get("slot_positions", {}), _dict(_scenario_slot_ids_by_layout.get(exact_layout_id, {}))):
				return false
	return true


static func _positions_valid(value: Variant, key: String, scenario_id: String = "") -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var expected_scope := "shared" if scenario_id.is_empty() else "scenario"
	for slot_value in (value as Dictionary).keys():
		var raw_slot_id := str(slot_value)
		var slot_id := raw_slot_id.strip_edges()
		if raw_slot_id != slot_id or slot_id.is_empty() or _slot_scope(key, scenario_id, slot_id) != expected_scope:
			return false
		if _normalized_position((value as Dictionary).get(slot_value)).is_empty():
			return false
	return true


static func _position_ids_match(value: Variant, expected_ids: Dictionary) -> bool:
	var positions := _positions(value)
	if positions.size() != expected_ids.size():
		return false
	for slot_id_value in expected_ids.keys():
		if not positions.has(slot_id_value):
			return false
	return true


static func _room_slot_overrides(rooms: Dictionary, environment: Dictionary, field: String) -> Dictionary:
	var key := room_key(environment)
	var room := _dict(rooms.get(key, {}))
	var result := _positions(room.get(field, {})).duplicate(true)
	var scenario_id := active_scenario_id(environment)
	if not scenario_id.is_empty():
		var scenario_layout := _dict(_dict(room.get("scenario_layouts", {})).get(scenario_id, {}))
		result.merge(_positions(scenario_layout.get(field, {})), true)
	return result


static func _scenario_positions(
	rooms: Dictionary,
	key: String,
	scenario_id: String,
	field: String
) -> Dictionary:
	var room := _dict(rooms.get(key, {}))
	var scenario_layout := _dict(_dict(room.get("scenario_layouts", {})).get(scenario_id, {}))
	return _positions(scenario_layout.get(field, {})).duplicate(true)


static func _slot_scope(key: String, scenario_id: String, slot_id: String) -> String:
	_ensure_catalog()
	if bool(_dict(_shared_slot_ids_by_room.get(key, {})).get(slot_id, false)):
		return "shared"
	var family := slot_id.get_slice(".", 0)
	if family not in SHARED_SLOT_FAMILIES and family != "scenario":
		return "unsupported"
	if family in SHARED_SLOT_FAMILIES:
		return "unsupported"
	if scenario_id.is_empty():
		return "scenario_missing"
	var exact_layout_id := "%s::%s" % [key, scenario_id]
	return "scenario" if bool(_dict(_scenario_slot_ids_by_layout.get(exact_layout_id, {})).get(slot_id, false)) else "unsupported"


static func _runtime_reserve_slot(key: String, slot_id: String) -> bool:
	_ensure_catalog()
	return bool(_dict(_runtime_reserve_ids_by_room.get(key, {})).get(slot_id, false))


# Maps with no catalog scenario have only one authoring context. Their legacy
# scenario-family capacity belongs to that base room, just like an explicit
# runtime reserve, so it must remain movable and exportable without inventing
# a fake scenario layout.
static func _shared_scenario_slot(key: String, slot_id: String) -> bool:
	_ensure_catalog()
	return slot_id.begins_with("scenario.") \
		and bool(_dict(_shared_slot_ids_by_room.get(key, {})).get(slot_id, false))


static func _supported_slot_id(slot_id: String) -> bool:
	return slot_id.get_slice(".", 0) in ["fixed", "event", "scenario", "exit"]


static func _ensure_catalog() -> void:
	if _catalog_loaded:
		return
	_catalog_loaded = true
	_surface_map_ids = {}
	_shared_slot_ids_by_room = {}
	_runtime_reserve_ids_by_room = {}
	_catalog_scenario_ids_by_room = {}
	_scenario_slot_ids_by_layout = {}
	_expected_base_layout_ids = []
	_expected_scenario_layout_ids = []
	var surface_scenario_slot_ids: Dictionary = {}
	var authority := _read_resource_json(SCENARIO_LAYOUTS_PATH)
	var authored_base_layout_ids := _array_to_set(_array(authority.get("base_layout_ids", [])))
	var surfaces := _read_resource_json(PLACEMENT_SURFACES_PATH)
	for map_value in _array(surfaces.get("maps", [])):
		var surface_map := _dict(map_value)
		var map_id := str(surface_map.get("id", "")).strip_edges()
		if map_id.is_empty():
			continue
		_surface_map_ids[map_id] = true
		_catalog_scenario_ids_by_room[map_id] = {}
		var base_layout_id := "%s::%s" % [map_id, BASE_LAYOUT_ID]
		if authored_base_layout_ids.has(map_id):
			_expected_base_layout_ids.append(base_layout_id)
		var shared_ids: Dictionary = {}
		for field in ["fixed_slots", "event_slots", "exit_slots"]:
			for slot_value in _array(surface_map.get(field, [])):
				var shared_slot_id := str(_dict(slot_value).get("id", "")).strip_edges()
				if not shared_slot_id.is_empty():
					shared_ids[shared_slot_id] = true
		var reserves: Dictionary = {}
		var scenario_ids: Dictionary = {}
		for slot_value in _array(surface_map.get("scenario_slots", [])):
			var slot := _dict(slot_value)
			var slot_id := str(slot.get("id", "")).strip_edges()
			if slot_id.is_empty():
				continue
			scenario_ids[slot_id] = true
			if bool(slot.get("runtime_reserve", false)):
				reserves[slot_id] = true
				shared_ids[slot_id] = true
		_shared_slot_ids_by_room[map_id] = shared_ids
		surface_scenario_slot_ids[map_id] = scenario_ids
		_runtime_reserve_ids_by_room[map_id] = reserves
	_expected_base_layout_ids.sort()
	for layout_value in _array(authority.get("layouts", [])):
		var layout := _dict(layout_value)
		var map_id := str(layout.get("map_id", "")).strip_edges()
		var scenario_id := str(layout.get("scenario_id", "")).strip_edges()
		if map_id.is_empty() or scenario_id.is_empty() or not _surface_map_ids.has(map_id):
			continue
		var exact_layout_id := "%s::%s" % [map_id, scenario_id]
		_expected_scenario_layout_ids.append(exact_layout_id)
		var room_scenarios := _dict(_catalog_scenario_ids_by_room.get(map_id, {})).duplicate(true)
		room_scenarios[scenario_id] = true
		_catalog_scenario_ids_by_room[map_id] = room_scenarios
		var exact_ids: Dictionary = {}
		for slot_value in _array(layout.get("scenario_slots", [])):
			var slot_id := str(_dict(slot_value).get("id", "")).strip_edges()
			if not slot_id.is_empty():
				exact_ids[slot_id] = true
		_scenario_slot_ids_by_layout[exact_layout_id] = exact_ids
	_expected_scenario_layout_ids.sort()
	# Maps without catalog scenarios have one base authoring context. Their
	# scenario-family capacity is shared room authority in that sole context.
	for map_id_value in _surface_map_ids.keys():
		var map_id := str(map_id_value)
		if _dict(_catalog_scenario_ids_by_room.get(map_id, {})).is_empty():
			var shared_ids := _dict(_shared_slot_ids_by_room.get(map_id, {})).duplicate(true)
			shared_ids.merge(_dict(surface_scenario_slot_ids.get(map_id, {})), true)
			_shared_slot_ids_by_room[map_id] = shared_ids


static func _read_resource_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func _exportable_user_rooms() -> Dictionary:
	return _exportable_rooms(_user_rooms)


static func _exportable_effective_rooms() -> Dictionary:
	return _exportable_rooms(_merged_effective_rooms())


static func _merged_effective_rooms() -> Dictionary:
	var merged := _project_rooms.duplicate(true)
	var authored_keys := _user_rooms.keys()
	authored_keys.sort()
	for key_value in authored_keys:
		var key := str(key_value)
		var room := _dict(merged.get(key, {})).duplicate(true)
		var authored_room := _dict(_user_rooms.get(key, {}))
		var slots := _positions(room.get("slot_positions", {})).duplicate(true)
		slots.merge(_positions(authored_room.get("slot_positions", {})), true)
		if slots.is_empty():
			room.erase("slot_positions")
		else:
			room["slot_positions"] = slots
		if authored_room.has("base_saved"):
			room["base_saved"] = bool(authored_room.get("base_saved", false))
		var layouts := _dict(room.get("scenario_layouts", {})).duplicate(true)
		var authored_layouts := _dict(authored_room.get("scenario_layouts", {}))
		var scenario_ids := authored_layouts.keys()
		scenario_ids.sort()
		for scenario_value in scenario_ids:
			var scenario_id := str(scenario_value)
			var scenario_layout := _dict(layouts.get(scenario_id, {})).duplicate(true)
			var authored_layout := _dict(authored_layouts.get(scenario_id, {}))
			var scenario_slots := _positions(scenario_layout.get("slot_positions", {})).duplicate(true)
			scenario_slots.merge(_positions(authored_layout.get("slot_positions", {})), true)
			if scenario_slots.is_empty():
				scenario_layout.erase("slot_positions")
			else:
				scenario_layout["slot_positions"] = scenario_slots
			if authored_layout.has("saved"):
				scenario_layout["saved"] = bool(authored_layout.get("saved", false))
			layouts[scenario_id] = scenario_layout
		if layouts.is_empty():
			room.erase("scenario_layouts")
		else:
			room["scenario_layouts"] = layouts
		if room.is_empty():
			merged.erase(key)
		else:
			merged[key] = room
	return merged


static func _exportable_rooms(source_rooms: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var room_keys := source_rooms.keys()
	room_keys.sort()
	for key_value in room_keys:
		var key := str(key_value).strip_edges()
		if key.is_empty():
			continue
		var source_room := _dict(source_rooms.get(key_value, {}))
		var room: Dictionary = {}
		var slots := _sanitized_positions(source_room.get("slot_positions", {}))
		if not slots.is_empty():
			room["slot_positions"] = slots
		if source_room.has("base_saved"):
			room["base_saved"] = bool(source_room.get("base_saved", false))
		var source_layouts := _dict(source_room.get("scenario_layouts", {}))
		var layout_ids := source_layouts.keys()
		layout_ids.sort()
		var layouts: Dictionary = {}
		for scenario_value in layout_ids:
			var scenario_id := str(scenario_value).strip_edges()
			if scenario_id.is_empty():
				continue
			var source_layout := _dict(source_layouts.get(scenario_value, {}))
			var scenario_layout: Dictionary = {}
			var scenario_slots := _sanitized_positions(source_layout.get("slot_positions", {}), true)
			if not scenario_slots.is_empty():
				scenario_layout["slot_positions"] = scenario_slots
			if source_layout.has("saved"):
				scenario_layout["saved"] = bool(source_layout.get("saved", false))
			if not scenario_layout.is_empty():
				layouts[scenario_id] = scenario_layout
		if not layouts.is_empty():
			room["scenario_layouts"] = layouts
		if not room.is_empty():
			result[key] = room
	return result


static func _sanitized_positions(value: Variant, scenario_only: bool = false) -> Dictionary:
	var result: Dictionary = {}
	var source := _positions(value)
	var slot_ids := source.keys()
	slot_ids.sort()
	for slot_value in slot_ids:
		var slot_id := str(slot_value).strip_edges()
		if slot_id.is_empty() or not _supported_slot_id(slot_id):
			continue
		if scenario_only and not slot_id.begins_with("scenario."):
			continue
		var position := _normalized_position(source.get(slot_value))
		if not position.is_empty():
			result[slot_id] = position
	return result


static func _normalized_position(value: Variant) -> Array:
	if typeof(value) == TYPE_VECTOR2:
		var vector := value as Vector2
		return [] if not is_finite(vector.x) or not is_finite(vector.y) else [snappedf(vector.x, 1.0), snappedf(vector.y, 1.0)]
	if typeof(value) == TYPE_VECTOR2I:
		var vector := value as Vector2i
		return [float(vector.x), float(vector.y)]
	if typeof(value) != TYPE_ARRAY:
		return []
	var values := value as Array
	if values.size() != 2 or not _numeric(values[0]) or not _numeric(values[1]):
		return []
	var x := float(values[0])
	var y := float(values[1])
	return [] if not is_finite(x) or not is_finite(y) else [snappedf(x, 1.0), snappedf(y, 1.0)]


static func _save_layout_error(message: String, invalid_slot_ids: Array = []) -> Dictionary:
	return {
		"ok": false,
		"error": message,
		"path": user_path(),
		"room_key": "",
		"layout_id": "",
		"scenario_id": "",
		"scope": "",
		"saved": false,
		"shared_slot_count": 0,
		"scenario_slot_count": 0,
		"slot_count": 0,
		"ignored_slot_ids": invalid_slot_ids,
	}


static func _slot_count(rooms: Dictionary) -> int:
	var result := 0
	for room_value in rooms.values():
		var room := _dict(room_value)
		result += _positions(room.get("slot_positions", {})).size()
		for layout_value in _dict(room.get("scenario_layouts", {})).values():
			result += _positions(_dict(layout_value).get("slot_positions", {})).size()
	return result


static func _array_to_set(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		result[str(value)] = true
	return result


static func _missing_ids(expected: Array, saved: Dictionary) -> Array:
	var result: Array = []
	for value in expected:
		if not saved.has(str(value)):
			result.append(str(value))
	return result


static func _expected_saved_count(expected: Array, saved: Dictionary) -> int:
	var result := 0
	for value in expected:
		if saved.has(str(value)):
			result += 1
	return result


static func _numeric(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT]


static func _positions(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}
