class_name DeveloperPlacementStore
extends RefCounted

# Durable, non-simulation authoring overrides for environment object placement.
# Project overrides ship with builds; user overrides let an owner author from an
# exported developer build and remain reproducible on that machine.

const SCHEMA_VERSION := 1
const PROJECT_PATH := "res://data/environments/developer_placement_overrides.json"
const USER_PATH := "user://developer_environment_placements.json"
const USER_PATH_ENV := "BTH_DEVELOPER_PLACEMENT_PATH"
const PROJECT_PATH_ENV := "BTH_PROJECT_PLACEMENT_PATH"
const PersistencePathsScript := preload("res://scripts/core/persistence_paths.gd")
const POSITION_FIELDS := [
	"object_slot_positions",
	"scenario_object_slot_positions",
	"category_slot_positions",
]

static var _loaded := false
static var _project_rooms: Dictionary = {}
static var _user_rooms: Dictionary = {}


static func room_key(environment: Dictionary) -> String:
	var archetype_id := str(environment.get("archetype_id", environment.get("id", ""))).strip_edges()
	var layer_id := str(environment.get("current_layer_id", environment.get("layer_id", ""))).strip_edges()
	return archetype_id if layer_id.is_empty() else "%s:%s" % [archetype_id, layer_id]


static func slot_overrides(environment: Dictionary, field: String) -> Dictionary:
	_ensure_loaded()
	var key := room_key(environment)
	var result := _dict(_dict(_project_rooms.get(key, {})).get(field, {})).duplicate(true)
	result.merge(_dict(_dict(_user_rooms.get(key, {})).get(field, {})), true)
	return result


static func save_position(environment: Dictionary, field: String, object_id: String, position: Vector2) -> Dictionary:
	if field not in POSITION_FIELDS:
		return {"ok": false, "error": "Unsupported placement collection."}
	var key := room_key(environment)
	var clean_id := object_id.strip_edges()
	if key.is_empty() or clean_id.is_empty() or not is_finite(position.x) or not is_finite(position.y):
		return {"ok": false, "error": "Placement identity and position must be valid."}
	_ensure_loaded()
	var room := _dict(_user_rooms.get(key, {})).duplicate(true)
	var slots := _dict(room.get(field, {})).duplicate(true)
	slots[clean_id] = [snappedf(position.x, 1.0), snappedf(position.y, 1.0)]
	room[field] = slots
	_user_rooms[key] = room
	var save_error := _write_payload(user_path(), _user_rooms)
	return {
		"ok": save_error == OK,
		"error": "" if save_error == OK else "Could not save developer placement overrides.",
		"path": user_path(),
		"room_key": key,
		"field": field,
		"object_id": clean_id,
		"position": slots[clean_id],
	}


static func clear_position(environment: Dictionary, field: String, object_id: String) -> Dictionary:
	var key := room_key(environment)
	_ensure_loaded()
	var room := _dict(_user_rooms.get(key, {})).duplicate(true)
	var slots := _dict(room.get(field, {})).duplicate(true)
	slots.erase(object_id.strip_edges())
	if slots.is_empty():
		room.erase(field)
	else:
		room[field] = slots
	if room.is_empty():
		_user_rooms.erase(key)
	else:
		_user_rooms[key] = room
	var save_error := _write_payload(user_path(), _user_rooms)
	return {"ok": save_error == OK, "error": "" if save_error == OK else "Could not reset the developer placement.", "path": user_path()}


static func promote_user_overrides() -> Dictionary:
	_ensure_loaded()
	var merged := _project_rooms.duplicate(true)
	for key_value in _user_rooms.keys():
		var key := str(key_value)
		var room := _dict(merged.get(key, {})).duplicate(true)
		var authored_room := _dict(_user_rooms.get(key, {}))
		for field in POSITION_FIELDS:
			var slots := _dict(room.get(field, {})).duplicate(true)
			slots.merge(_dict(authored_room.get(field, {})), true)
			if not slots.is_empty():
				room[field] = slots
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


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_project_rooms = _read_rooms(project_path())
	_user_rooms = _read_rooms(user_path())


static func _read_rooms(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var payload := parsed as Dictionary
	if int(payload.get("schema_version", 0)) != SCHEMA_VERSION:
		return {}
	return _dict(payload.get("rooms", {})).duplicate(true)


static func _write_payload(path: String, rooms: Dictionary) -> Error:
	var global_path := ProjectSettings.globalize_path(path)
	var directory := global_path.get_base_dir()
	if not directory.is_empty():
		var directory_error := DirAccess.make_dir_recursive_absolute(directory)
		if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
			return directory_error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"schema_version": SCHEMA_VERSION, "rooms": rooms}, "  ", true) + "\n")
	file.close()
	return OK


static func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}
