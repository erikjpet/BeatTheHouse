class_name SaveService
extends RefCounted

# Saves and loads foundation RunState data by slot.

const SAVE_DIR := "user://saves"
const PersistencePathsScript := preload("res://scripts/core/persistence_paths.gd")
const SAVE_SCHEMA := "beat_the_house.foundation_run"
const SAVE_VERSION := 2
const RunSaveCodecScript := preload("res://scripts/core/run_save_codec.gd")
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
var trusted_primary_fingerprints: Dictionary = {}
var async_task_id: int = -1
var async_result_box: Dictionary = {}
var async_slot_id: String = ""
var io_mutex := Mutex.new()


# Checks whether a run save exists.
func has_run(slot_id: String = "autosave") -> bool:
	var clean_slot := _slot_id(slot_id)
	io_mutex.lock()
	var result := _primary_fingerprint_is_trusted(clean_slot, run_save_path(clean_slot))
	if not result:
		result = bool(_slot_status_unlocked(clean_slot).get("has_loadable", false))
	io_mutex.unlock()
	return result


# Writes run state to a save slot.
func save_run(run_state: RunState, slot_id: String = "autosave") -> Error:
	if run_state == null:
		return ERR_INVALID_PARAMETER
	if async_task_id >= 0:
		var async_error := wait_for_async_save()
		if async_error != OK:
			return async_error
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
	var primary_loadable := false
	if FileAccess.file_exists(path):
		if _primary_fingerprint_is_trusted(clean_slot, path):
			primary_loadable = true
		else:
			var primary_read := _read_run_state_from_path(path)
			primary_loadable = bool(primary_read.get("loadable", false))
			if primary_loadable:
				_remember_primary_fingerprint(clean_slot, path)
	if primary_loadable:
		var backup_error := _rotate_primary_to_backup(path, backup_save_path(clean_slot))
		if backup_error != OK:
			_remove_absolute_if_exists(temp_path)
			return backup_error
	if FileAccess.file_exists(absolute_path):
		var remove_error := DirAccess.remove_absolute(absolute_path)
		if remove_error != OK:
			_remove_absolute_if_exists(temp_path)
			return remove_error
	var install_error := DirAccess.rename_absolute(temp_path, absolute_path)
	if install_error == OK:
		_remember_primary_fingerprint(clean_slot, path)
	else:
		trusted_primary_fingerprints.erase(clean_slot)
	return install_error


# Captures one detached RunState generation on the main thread, then performs
# save projection, JSON encoding, validation, and atomic file rotation on a
# worker. Only one generation writes at a time; FoundationMain coalesces newer
# dirty generations while this job is in flight.
func begin_save_run(run_state: RunState, slot_id: String = "autosave") -> Error:
	if run_state == null:
		return ERR_INVALID_PARAMETER
	if async_task_id >= 0:
		return ERR_BUSY
	var clean_slot := _slot_id(slot_id)
	var runtime_snapshot := run_state.to_save_snapshot()
	var path := run_save_path(clean_slot)
	var backup_path := backup_save_path(clean_slot)
	# Loaded and successfully written primaries are fingerprinted. Passing that
	# trust into the worker avoids reparsing the entire previous save merely to
	# decide whether it is safe to rotate into the backup generation.
	var primary_trusted := _primary_fingerprint_is_trusted(clean_slot, path)
	async_result_box = {"error": ERR_BUSY, "slot_id": clean_slot}
	async_slot_id = clean_slot
	async_task_id = WorkerThreadPool.add_task(
		Callable(self, "_async_save_worker").bind(runtime_snapshot, clean_slot, path, backup_path, primary_trusted, async_result_box),
		false,
		"Beat the House autosave"
	)
	return OK


func async_save_in_flight() -> bool:
	return async_task_id >= 0


func poll_async_save() -> Dictionary:
	if async_task_id < 0:
		return {"completed": false, "in_flight": false}
	if not WorkerThreadPool.is_task_completed(async_task_id):
		return {"completed": false, "in_flight": true, "slot_id": async_slot_id}
	WorkerThreadPool.wait_for_task_completion(async_task_id)
	return _finish_async_save_result()


func _finish_async_save_result() -> Dictionary:
	var result := async_result_box.duplicate(true)
	result["completed"] = true
	result["in_flight"] = false
	if int(result.get("error", FAILED)) == OK:
		_remember_primary_fingerprint(async_slot_id, run_save_path(async_slot_id))
	else:
		trusted_primary_fingerprints.erase(async_slot_id)
	async_task_id = -1
	async_result_box = {}
	async_slot_id = ""
	return result


func wait_for_async_save() -> Error:
	if async_task_id < 0:
		return OK
	WorkerThreadPool.wait_for_task_completion(async_task_id)
	var result := _finish_async_save_result()
	return int(result.get("error", FAILED))


func _async_save_worker(runtime_snapshot: Dictionary, slot_id: String, path: String, backup_path: String, primary_trusted: bool, result_box: Dictionary) -> void:
	var payload := {
		"schema": SAVE_SCHEMA,
		"version": SAVE_VERSION,
		"act": maxi(1, int(runtime_snapshot.get("act", 1))),
		"slot_id": slot_id,
		"run_state": RunSaveCodecScript.encode(runtime_snapshot),
	}
	io_mutex.lock()
	result_box["error"] = _write_payload_atomic(payload, path, backup_path, primary_trusted)
	io_mutex.unlock()


static func _write_payload_atomic(payload: Dictionary, path: String, backup_path: String, primary_trusted: bool = false) -> Error:
	var absolute_path := ProjectSettings.globalize_path(path)
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK:
		return directory_error
	var temp_path := "%s.tmp" % absolute_path
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_remove_worker_file(temp_path)
		return write_error
	if FileAccess.file_exists(absolute_path) and (primary_trusted or _worker_payload_loadable(absolute_path)):
		if FileAccess.file_exists(backup_absolute):
			var remove_backup_error := DirAccess.remove_absolute(backup_absolute)
			if remove_backup_error != OK:
				_remove_worker_file(temp_path)
				return remove_backup_error
		var backup_error := DirAccess.rename_absolute(absolute_path, backup_absolute)
		if backup_error != OK:
			_remove_worker_file(temp_path)
			return backup_error
	elif FileAccess.file_exists(absolute_path):
		var remove_primary_error := DirAccess.remove_absolute(absolute_path)
		if remove_primary_error != OK:
			_remove_worker_file(temp_path)
			return remove_primary_error
	return DirAccess.rename_absolute(temp_path, absolute_path)


static func _worker_payload_loadable(absolute_path: String) -> bool:
	var text := FileAccess.get_file_as_string(absolute_path)
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = json.data
	if payload.get("schema", "") == SAVE_SCHEMA:
		return typeof(payload.get("run_state", {})) == TYPE_DICTIONARY
	return payload.has("seed_text") and payload.has("rng_state") and payload.has("current_environment")


static func _remove_worker_file(absolute_path: String) -> void:
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


# Loads run state from a save slot.
func load_run(slot_id: String = "autosave") -> Variant:
	if async_task_id >= 0:
		wait_for_async_save()
	var clean_slot := _slot_id(slot_id)
	var primary := _read_run_state_from_path(run_save_path(clean_slot))
	if bool(primary.get("loadable", false)):
		# A valid primary is authoritative. Parsing and normalizing the complete
		# backup as well doubled Continue time for accumulated late-run saves.
		var backup := {
			"exists": FileAccess.file_exists(backup_save_path(clean_slot)),
			"loadable": false,
		}
		_remember_primary_fingerprint(clean_slot, run_save_path(clean_slot))
		last_load_outcome = _load_outcome(clean_slot, LOAD_OUTCOME_PRIMARY, primary, backup)
		return primary.get("run_state")
	var backup := _read_run_state_from_path(backup_save_path(clean_slot))
	if bool(backup.get("loadable", false)):
		last_load_outcome = _load_outcome(clean_slot, LOAD_OUTCOME_BACKUP, primary, backup)
		return backup.get("run_state")
	last_load_outcome = _load_outcome(clean_slot, LOAD_OUTCOME_NONE, primary, backup)
	return null


# Removes both generations of a slot so a deliberately skipped tutorial cannot resume.
func clear_run(slot_id: String = "autosave") -> Error:
	if async_task_id >= 0:
		var async_error := wait_for_async_save()
		if async_error != OK:
			return async_error
	var clean_slot := _slot_id(slot_id)
	for path in [run_save_path(clean_slot), backup_save_path(clean_slot)]:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			var remove_error := DirAccess.remove_absolute(absolute_path)
			if remove_error != OK:
				return remove_error
	trusted_primary_fingerprints.erase(clean_slot)
	return OK


func last_load_result() -> Dictionary:
	return last_load_outcome.duplicate(true)


func slot_status(slot_id: String = "autosave") -> Dictionary:
	var clean_slot := _slot_id(slot_id)
	io_mutex.lock()
	var result := _slot_status_unlocked(clean_slot)
	io_mutex.unlock()
	return result


func _slot_status_unlocked(clean_slot: String) -> Dictionary:
	var primary := _read_run_state_from_path(run_save_path(clean_slot))
	var backup := _read_run_state_from_path(backup_save_path(clean_slot))
	var primary_loadable := bool(primary.get("loadable", false))
	var backup_loadable := bool(backup.get("loadable", false))
	if primary_loadable:
		_remember_primary_fingerprint(clean_slot, run_save_path(clean_slot))
	else:
		trusted_primary_fingerprints.erase(clean_slot)
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
	return "%s/%s.json" % [save_dir(), _slot_id(slot_id)]


func save_dir() -> String:
	return PersistencePathsScript.directory_path(SAVE_DIR, "saves")


func backup_save_path(slot_id: String = "autosave") -> String:
	return "%s.bak" % run_save_path(slot_id)


# Builds a versioned foundation run payload.
func _save_payload(run_state: RunState, slot_id: String) -> Dictionary:
	return {
		"schema": SAVE_SCHEMA,
		"version": SAVE_VERSION,
		"act": run_state.act_marker(),
		"slot_id": slot_id,
		"run_state": RunSaveCodecScript.encode(run_state.to_dict()),
	}


# Accepts current envelopes and previous raw foundation RunState dictionaries.
func _run_data_from_payload(payload: Dictionary) -> Dictionary:
	if payload.get("schema", "") == SAVE_SCHEMA:
		var run_data: Variant = payload.get("run_state", {})
		if typeof(run_data) != TYPE_DICTIONARY:
			return {}
		var copied_run_data := RunSaveCodecScript.decode(run_data as Dictionary)
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
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"exists": true, "loadable": false, "run_state": null}
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"exists": true, "loadable": false, "run_state": null}
	var run_data := _run_data_from_payload(parsed as Dictionary)
	if run_data.is_empty():
		return {"exists": true, "loadable": false, "run_state": null}
	var run_state := RunState.new()
	run_state.from_dict(run_data)
	return {"exists": true, "loadable": true, "run_state": run_state}


func _rotate_primary_to_backup(primary_path: String, backup_path: String) -> Error:
	var primary_absolute := ProjectSettings.globalize_path(primary_path)
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_absolute):
		var remove_error := DirAccess.remove_absolute(backup_absolute)
		if remove_error != OK:
			return remove_error
	return DirAccess.rename_absolute(primary_absolute, backup_absolute)


func _primary_fingerprint_is_trusted(slot_id: String, path: String) -> bool:
	if not trusted_primary_fingerprints.has(slot_id):
		return false
	return str(trusted_primary_fingerprints.get(slot_id, "")) == _file_fingerprint(path)


func _remember_primary_fingerprint(slot_id: String, path: String) -> void:
	var fingerprint := _file_fingerprint(path)
	if fingerprint.is_empty():
		trusted_primary_fingerprints.erase(slot_id)
	else:
		trusted_primary_fingerprints[slot_id] = fingerprint


func _file_fingerprint(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return "%d:%d" % [FileAccess.get_modified_time(path), FileAccess.get_size(path)]


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
