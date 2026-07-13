class_name SaveService
extends RefCounted

# Saves and loads foundation RunState data by slot.

const SAVE_DIR := "user://saves"
const SAVE_SCHEMA := "beat_the_house.foundation_run"
const SAVE_VERSION := 1
const LOAD_OUTCOME_PRIMARY := "loaded-primary"
const LOAD_OUTCOME_BACKUP := "loaded-backup"
const LOAD_OUTCOME_NONE := "nothing-loadable"

var last_load_outcome: Dictionary = {
	"outcome": LOAD_OUTCOME_NONE,
	"slot_id": "",
	"primary_exists": false,
	"primary_loadable": false,
	"backup_exists": false,
	"backup_loadable": false,
}


# Checks whether a run save exists.
func has_run(slot_id: String = "autosave") -> bool:
	return bool(slot_status(slot_id).get("has_loadable", false))


# Writes run state to a save slot.
func save_run(run_state: RunState, slot_id: String = "autosave") -> Error:
	if run_state == null:
		return ERR_INVALID_PARAMETER
	var clean_slot := _slot_id(slot_id)
	var path := run_save_path(clean_slot)
	var absolute_path := ProjectSettings.globalize_path(path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK:
		return directory_error
	var temp_path := "%s.tmp" % absolute_path
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(_save_payload(run_state, clean_slot)))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_remove_absolute_if_exists(temp_path)
		return write_error
	var primary_read := _read_run_state_from_path(path)
	if bool(primary_read.get("loadable", false)):
		var backup_error := _rotate_primary_to_backup(path, backup_save_path(clean_slot))
		if backup_error != OK:
			_remove_absolute_if_exists(temp_path)
			return backup_error
	if FileAccess.file_exists(absolute_path):
		var remove_error := DirAccess.remove_absolute(absolute_path)
		if remove_error != OK:
			_remove_absolute_if_exists(temp_path)
			return remove_error
	return DirAccess.rename_absolute(temp_path, absolute_path)


# Loads run state from a save slot.
func load_run(slot_id: String = "autosave") -> Variant:
	var clean_slot := _slot_id(slot_id)
	var primary := _read_run_state_from_path(run_save_path(clean_slot))
	var backup := _read_run_state_from_path(backup_save_path(clean_slot))
	if bool(primary.get("loadable", false)):
		last_load_outcome = _load_outcome(clean_slot, LOAD_OUTCOME_PRIMARY, primary, backup)
		return primary.get("run_state")
	if bool(backup.get("loadable", false)):
		last_load_outcome = _load_outcome(clean_slot, LOAD_OUTCOME_BACKUP, primary, backup)
		return backup.get("run_state")
	last_load_outcome = _load_outcome(clean_slot, LOAD_OUTCOME_NONE, primary, backup)
	return null


func last_load_result() -> Dictionary:
	return last_load_outcome.duplicate(true)


func slot_status(slot_id: String = "autosave") -> Dictionary:
	var clean_slot := _slot_id(slot_id)
	var primary := _read_run_state_from_path(run_save_path(clean_slot))
	var backup := _read_run_state_from_path(backup_save_path(clean_slot))
	var primary_loadable := bool(primary.get("loadable", false))
	var backup_loadable := bool(backup.get("loadable", false))
	return {
		"slot_id": clean_slot,
		"has_loadable": primary_loadable or backup_loadable,
		"primary_exists": bool(primary.get("exists", false)),
		"primary_loadable": primary_loadable,
		"backup_exists": bool(backup.get("exists", false)),
		"backup_loadable": backup_loadable,
		"primary_corrupt": bool(primary.get("exists", false)) and not primary_loadable,
		"backup_corrupt": bool(backup.get("exists", false)) and not backup_loadable,
	}


# Builds the foundation run save path for a slot.
func run_save_path(slot_id: String = "autosave") -> String:
	return "%s/%s.json" % [SAVE_DIR, _slot_id(slot_id)]


func backup_save_path(slot_id: String = "autosave") -> String:
	return "%s.bak" % run_save_path(slot_id)


# Builds a versioned foundation run payload.
func _save_payload(run_state: RunState, slot_id: String) -> Dictionary:
	return {
		"schema": SAVE_SCHEMA,
		"version": SAVE_VERSION,
		"act": run_state.act_marker(),
		"slot_id": slot_id,
		"run_state": run_state.to_dict(),
	}


# Accepts current envelopes and previous raw foundation RunState dictionaries.
func _run_data_from_payload(payload: Dictionary) -> Dictionary:
	if payload.get("schema", "") == SAVE_SCHEMA:
		var run_data: Variant = payload.get("run_state", {})
		if typeof(run_data) != TYPE_DICTIONARY:
			return {}
		var copied_run_data := (run_data as Dictionary).duplicate(true)
		if not copied_run_data.has("act"):
			copied_run_data["act"] = maxi(1, int(payload.get("act", 1)))
		return copied_run_data
	if _looks_like_run_state(payload):
		return payload.duplicate(true)
	return {}


func _read_run_state_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "loadable": false, "run_state": null}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"exists": true, "loadable": false, "run_state": null}
	var run_data := _run_data_from_payload(parsed as Dictionary)
	if run_data.is_empty():
		return {"exists": true, "loadable": false, "run_state": null}
	var run_state := RunState.new()
	run_state.from_dict(run_data)
	return {"exists": true, "loadable": true, "run_state": run_state}


func _rotate_primary_to_backup(primary_path: String, backup_path: String) -> Error:
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	var backup_temp := "%s.tmp" % backup_absolute
	var previous_text := FileAccess.get_file_as_string(primary_path)
	var file := FileAccess.open(backup_temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(previous_text)
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_remove_absolute_if_exists(backup_temp)
		return write_error
	if FileAccess.file_exists(backup_absolute):
		var remove_error := DirAccess.remove_absolute(backup_absolute)
		if remove_error != OK:
			_remove_absolute_if_exists(backup_temp)
			return remove_error
	return DirAccess.rename_absolute(backup_temp, backup_absolute)


func _remove_absolute_if_exists(absolute_path: String) -> Error:
	if not FileAccess.file_exists(absolute_path):
		return OK
	return DirAccess.remove_absolute(absolute_path)


func _load_outcome(slot_id: String, outcome: String, primary: Dictionary, backup: Dictionary) -> Dictionary:
	return {
		"outcome": outcome,
		"slot_id": slot_id,
		"primary_exists": bool(primary.get("exists", false)),
		"primary_loadable": bool(primary.get("loadable", false)),
		"backup_exists": bool(backup.get("exists", false)),
		"backup_loadable": bool(backup.get("loadable", false)),
	}


# Checks that data is shaped like a foundation RunState, not settings/profile/demo state.
func _looks_like_run_state(data: Dictionary) -> bool:
	return data.has("seed_text") and data.has("rng_state") and data.has("challenge_config") and data.has("bankroll") and data.has("current_environment")


# Keeps slot ids path-local and stable across platforms.
func _slot_id(slot_id: String) -> String:
	var raw := slot_id.strip_edges()
	var clean := ""
	for index in range(raw.length()):
		var code := raw.unicode_at(index)
		var is_digit := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		var is_safe_symbol := code == 45 or code == 95
		if is_digit or is_upper or is_lower or is_safe_symbol:
			clean += raw.substr(index, 1)
	if clean.is_empty():
		return "autosave"
	return clean
