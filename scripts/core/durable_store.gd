class_name DurableStore
extends RefCounted

const IoResultScript := preload("res://scripts/core/io_result.gd")
const KeysScript := preload("res://scripts/core/keys.gd")

# Shared JSON persistence boundary. A primary is never displaced until its
# replacement has been written and validated, and a failed install restores
# the prior primary from the rotated backup.

const OUTCOME_PRIMARY := "loaded-primary"
const OUTCOME_BACKUP := "loaded-backup"
const OUTCOME_NONE := "nothing-loadable"
const OUTCOME_SAVED := "saved-primary"

static var debug_force_write_failure := false
static var debug_force_rename_failure := false
static var debug_fail_transition := ""

const TRANSITION_STAGE_BACKUP := "stage_backup"
const TRANSITION_ROTATE_PRIMARY := "rotate_primary"
const TRANSITION_INSTALL_PRIMARY := "install_primary"
const TRANSITION_VALIDATE_PRIMARY := "validate_primary"


static func write_json(path: String, payload: Dictionary, validator: Callable = Callable()) -> Dictionary:
	var clean_path := path.strip_edges()
	if clean_path.is_empty():
		return _result(false, ERR_INVALID_PARAMETER, "empty_path", OUTCOME_NONE)
	var absolute_path := ProjectSettings.globalize_path(clean_path)
	var directory := absolute_path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return _result(false, directory_error, "directory_create_failed", OUTCOME_NONE)

	var temp_absolute := "%s.tmp" % absolute_path
	_remove_if_exists(temp_absolute)
	if debug_force_write_failure:
		return _result(false, ERR_CANT_CREATE, "debug_forced_write_failure", OUTCOME_NONE)
	var file := FileAccess.open(temp_absolute, FileAccess.WRITE)
	if file == null:
		return _result(false, FileAccess.get_open_error(), "temporary_open_failed", OUTCOME_NONE)
	file.store_string(JSON.stringify(payload, "\t"))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_remove_if_exists(temp_absolute)
		return _result(false, write_error, "temporary_write_failed", OUTCOME_NONE)

	var temporary := _read_generation(temp_absolute, validator)
	if not bool(temporary.get("loadable", false)):
		_remove_if_exists(temp_absolute)
		return _result(false, ERR_FILE_CORRUPT, "temporary_generation_invalid", OUTCOME_NONE)

	var primary := _read_generation(clean_path, validator)
	var backup_absolute := ProjectSettings.globalize_path(backup_path(clean_path))
	var backup_rollback_absolute := "%s.rollback" % backup_absolute
	var invalid_primary_rollback_absolute := "%s.rollback" % absolute_path
	# Rollback names are private to one synchronous install. A prior completed
	# transaction must not leave either name behind, and an interrupted one is
	# surfaced instead of silently overwriting a recoverable generation.
	for rollback_path in [backup_rollback_absolute, invalid_primary_rollback_absolute]:
		if FileAccess.file_exists(rollback_path):
			_remove_if_exists(temp_absolute)
			return _result(false, ERR_ALREADY_IN_USE, "stale_transaction_rollback", OUTCOME_NONE)
	var staged_backup := false
	var rotated_primary := false
	var staged_invalid_primary := false
	if bool(primary.get("loadable", false)):
		if FileAccess.file_exists(backup_absolute):
			if _debug_transition_fails(TRANSITION_STAGE_BACKUP):
				_remove_if_exists(temp_absolute)
				return _result(false, ERR_CANT_CREATE, "debug_forced_backup_stage_failure", OUTCOME_NONE)
			var stage_backup_error := DirAccess.rename_absolute(backup_absolute, backup_rollback_absolute)
			if stage_backup_error != OK:
				_remove_if_exists(temp_absolute)
				return _result(false, stage_backup_error, "backup_stage_failed", OUTCOME_NONE)
			staged_backup = true
		if _debug_transition_fails(TRANSITION_ROTATE_PRIMARY):
			_remove_if_exists(temp_absolute)
			var restore_staged_error := _restore_install_generations(
				absolute_path, backup_absolute, backup_rollback_absolute,
				invalid_primary_rollback_absolute, false, staged_backup, false, false
			)
			return _result(false, ERR_CANT_CREATE if restore_staged_error == OK else restore_staged_error, "debug_forced_primary_rotation_failure", OUTCOME_NONE)
		var rotate_error := DirAccess.rename_absolute(absolute_path, backup_absolute)
		if rotate_error != OK:
			_remove_if_exists(temp_absolute)
			var restore_staged_error := _restore_install_generations(
				absolute_path, backup_absolute, backup_rollback_absolute,
				invalid_primary_rollback_absolute, false, staged_backup, false, false
			)
			return _result(false, rotate_error if restore_staged_error == OK else restore_staged_error, "backup_rotation_failed", OUTCOME_NONE)
		rotated_primary = true
	elif bool(primary.get("exists", false)):
		if _debug_transition_fails(TRANSITION_ROTATE_PRIMARY):
			_remove_if_exists(temp_absolute)
			return _result(false, ERR_CANT_CREATE, "debug_forced_invalid_primary_stage_failure", OUTCOME_NONE)
		var stage_invalid_error := DirAccess.rename_absolute(absolute_path, invalid_primary_rollback_absolute)
		if stage_invalid_error != OK:
			_remove_if_exists(temp_absolute)
			return _result(false, stage_invalid_error, "invalid_primary_stage_failed", OUTCOME_NONE)
		staged_invalid_primary = true

	if debug_force_rename_failure or _debug_transition_fails(TRANSITION_INSTALL_PRIMARY):
		_remove_if_exists(temp_absolute)
		var restore_error := _restore_install_generations(
			absolute_path, backup_absolute, backup_rollback_absolute,
			invalid_primary_rollback_absolute, rotated_primary, staged_backup,
			staged_invalid_primary, false
		)
		return _result(false, ERR_CANT_CREATE if restore_error == OK else restore_error, "debug_forced_rename_failure", OUTCOME_NONE)

	var install_error := DirAccess.rename_absolute(temp_absolute, absolute_path)
	if install_error != OK:
		_remove_if_exists(temp_absolute)
		var restore_error := _restore_install_generations(
			absolute_path, backup_absolute, backup_rollback_absolute,
			invalid_primary_rollback_absolute, rotated_primary, staged_backup,
			staged_invalid_primary, false
		)
		if restore_error != OK:
			return _result(false, restore_error, "primary_restore_failed", OUTCOME_NONE)
		return _result(false, install_error, "primary_install_failed", OUTCOME_NONE)

	var installed := _read_generation(clean_path, validator)
	if _debug_transition_fails(TRANSITION_VALIDATE_PRIMARY) or not bool(installed.get("loadable", false)):
		var restore_error := _restore_install_generations(
			absolute_path, backup_absolute, backup_rollback_absolute,
			invalid_primary_rollback_absolute, rotated_primary, staged_backup,
			staged_invalid_primary, true
		)
		if restore_error != OK:
			return _result(false, restore_error, "installed_invalid_restore_failed", OUTCOME_NONE)
		return _result(false, ERR_FILE_CORRUPT, "installed_generation_invalid", OUTCOME_NONE)
	# The new primary has been validated and the old primary is now the normal
	# backup. Only now may the pre-transaction backup be discarded.
	_remove_if_exists(backup_rollback_absolute)
	_remove_if_exists(invalid_primary_rollback_absolute)
	return _result(true, OK, "", OUTCOME_SAVED, installed.get("data", {}))


static func read_json(path: String, validator: Callable = Callable()) -> Dictionary:
	var primary := _read_generation(path, validator)
	if bool(primary.get("loadable", false)):
		var result := _result(true, OK, "", OUTCOME_PRIMARY, primary.get("data", {}))
		_merge_status(result, primary, _read_generation(backup_path(path), validator))
		return result
	var backup := _read_generation(backup_path(path), validator)
	if bool(backup.get("loadable", false)):
		var result := _result(true, OK, "", OUTCOME_BACKUP, backup.get("data", {}))
		_merge_status(result, primary, backup)
		return result
	var error := ERR_FILE_NOT_FOUND if not bool(primary.get("exists", false)) and not bool(backup.get("exists", false)) else ERR_FILE_CORRUPT
	var error_code := "not_found" if error == ERR_FILE_NOT_FOUND else "no_loadable_generation"
	var result := _result(false, error, error_code, OUTCOME_NONE)
	_merge_status(result, primary, backup)
	return result


static func backup_path(path: String) -> String:
	return "%s.bak" % path


static func status(path: String, validator: Callable = Callable()) -> Dictionary:
	var primary := _read_generation(path, validator)
	var backup := _read_generation(backup_path(path), validator)
	return {
		"path": path,
		"backup_path": backup_path(path),
		"has_loadable": bool(primary.get("loadable", false)) or bool(backup.get("loadable", false)),
		"primary_exists": bool(primary.get("exists", false)),
		"primary_loadable": bool(primary.get("loadable", false)),
		"backup_exists": bool(backup.get("exists", false)),
		"backup_loadable": bool(backup.get("loadable", false)),
	}


static func reset_debug_faults() -> void:
	debug_force_write_failure = false
	debug_force_rename_failure = false
	debug_fail_transition = ""


static func set_debug_force_write_failure(enabled: bool) -> void:
	debug_force_write_failure = enabled


static func set_debug_force_rename_failure(enabled: bool) -> void:
	debug_force_rename_failure = enabled


static func set_debug_fail_transition(transition: String) -> void:
	debug_fail_transition = transition.strip_edges()


static func _read_generation(path: String, validator: Callable) -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return {"exists": false, "loadable": false, "data": {}}
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return {"exists": true, "loadable": false, "data": {}, "error": FileAccess.get_open_error()}
	var text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		return {"exists": true, "loadable": false, "data": {}, "error": read_error}
	var parser := JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {"exists": true, "loadable": false, "data": {}, "error": ERR_FILE_CORRUPT}
	var data: Dictionary = parser.data
	if validator.is_valid() and not bool(validator.call(data)):
		return {"exists": true, "loadable": false, "data": data, "error": ERR_FILE_CORRUPT}
	return {"exists": true, "loadable": true, "data": data, "error": OK}


static func _debug_transition_fails(transition: String) -> bool:
	return not transition.is_empty() and debug_fail_transition == transition


static func _restore_install_generations(
	primary_absolute: String,
	backup_absolute: String,
	backup_rollback_absolute: String,
	invalid_primary_rollback_absolute: String,
	rotated_primary: bool,
	staged_backup: bool,
	staged_invalid_primary: bool,
	installed_primary: bool
) -> Error:
	var first_error: Error = OK
	if installed_primary and FileAccess.file_exists(primary_absolute):
		first_error = _remove_if_exists(primary_absolute)
	if rotated_primary:
		if not FileAccess.file_exists(primary_absolute):
			var restore_primary_error := DirAccess.rename_absolute(backup_absolute, primary_absolute)
			if first_error == OK and restore_primary_error != OK:
				first_error = restore_primary_error
	elif staged_invalid_primary and not FileAccess.file_exists(primary_absolute):
		var restore_invalid_error := DirAccess.rename_absolute(invalid_primary_rollback_absolute, primary_absolute)
		if first_error == OK and restore_invalid_error != OK:
			first_error = restore_invalid_error
	# Do not displace the rotated primary if restoring it failed: both prior
	# generations remain recoverable under the backup and rollback names.
	if staged_backup and FileAccess.file_exists(primary_absolute):
		if FileAccess.file_exists(backup_absolute):
			var remove_backup_error := _remove_if_exists(backup_absolute)
			if first_error == OK and remove_backup_error != OK:
				first_error = remove_backup_error
		if not FileAccess.file_exists(backup_absolute):
			var restore_backup_error := DirAccess.rename_absolute(backup_rollback_absolute, backup_absolute)
			if first_error == OK and restore_backup_error != OK:
				first_error = restore_backup_error
	return first_error


static func _remove_if_exists(absolute_path: String) -> Error:
	if not FileAccess.file_exists(absolute_path):
		return OK
	return DirAccess.remove_absolute(absolute_path)


static func _result(ok: bool, error: Error, error_code: String, outcome: String, data: Dictionary = {}) -> Dictionary:
	var extra := {
		KeysScript.OUTCOME: outcome,
		"data": data.duplicate(true),
	}
	if ok:
		return IoResultScript.ok(extra)
	var message := error_code.replace("_", " ").capitalize()
	return IoResultScript.failed(error, error_code, message, extra)


static func _merge_status(result: Dictionary, primary: Dictionary, backup: Dictionary) -> void:
	result["primary_exists"] = bool(primary.get("exists", false))
	result["primary_loadable"] = bool(primary.get("loadable", false))
	result["backup_exists"] = bool(backup.get("exists", false))
	result["backup_loadable"] = bool(backup.get("loadable", false))
