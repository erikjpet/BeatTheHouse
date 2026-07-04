class_name SaveService
extends RefCounted

# Saves and loads foundation RunState data by slot.

const SAVE_DIR := "user://saves"
const SAVE_SCHEMA := "beat_the_house.foundation_run"
const SAVE_VERSION := 1


# Checks whether a run save exists.
func has_run(slot_id: String = "autosave") -> bool:
	return FileAccess.file_exists(run_save_path(slot_id))


# Writes run state to a save slot.
func save_run(run_state: RunState, slot_id: String = "autosave") -> Error:
	if run_state == null:
		return ERR_INVALID_PARAMETER
	var root := DirAccess.open("user://")
	if root == null:
		return ERR_CANT_OPEN
	var make_dir_error := root.make_dir_recursive("saves")
	if make_dir_error != OK:
		return make_dir_error
	var clean_slot := _slot_id(slot_id)
	var file := FileAccess.open(run_save_path(clean_slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(_save_payload(run_state, clean_slot)))
	file.close()
	return OK


# Loads run state from a save slot.
func load_run(slot_id: String = "autosave") -> Variant:
	var path := run_save_path(slot_id)
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var run_data := _run_data_from_payload(parsed)
	if run_data.is_empty():
		return null
	var run_state := RunState.new()
	run_state.from_dict(run_data)
	return run_state


# Builds the foundation run save path for a slot.
func run_save_path(slot_id: String = "autosave") -> String:
	return "%s/%s.json" % [SAVE_DIR, _slot_id(slot_id)]


# Builds a versioned foundation run payload.
func _save_payload(run_state: RunState, slot_id: String) -> Dictionary:
	return {
		"schema": SAVE_SCHEMA,
		"version": SAVE_VERSION,
		"slot_id": slot_id,
		"run_state": run_state.to_dict(),
	}


# Accepts current envelopes and previous raw foundation RunState dictionaries.
func _run_data_from_payload(payload: Dictionary) -> Dictionary:
	if payload.get("schema", "") == SAVE_SCHEMA:
		var run_data: Variant = payload.get("run_state", {})
		if typeof(run_data) != TYPE_DICTIONARY:
			return {}
		return (run_data as Dictionary).duplicate(true)
	if _looks_like_run_state(payload):
		return payload.duplicate(true)
	return {}


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
