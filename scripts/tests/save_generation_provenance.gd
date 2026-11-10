extends RefCounted

# Optional disposable-fixture evidence only. Never searches player storage.
static func fingerprints(service: SaveService, slot: String) -> Dictionary:
	var result := {}
	for pair in [["primary", service.run_save_path(slot)], ["backup", service.backup_save_path(slot)]]:
		var path := str(pair[1])
		var exists := FileAccess.file_exists(path)
		var file := FileAccess.open(path, FileAccess.READ) if exists else null
		result[str(pair[0])] = {"exists": exists, "sha256": FileAccess.get_sha256(path) if exists else "", "bytes": file.get_length() if file != null else 0}
	return result

static func record(stage: String, service: SaveService, slot: String, snapshot: Dictionary, app: Control = null) -> void:
	var row := {"stage": stage, "slot": slot, "cold": OS.get_cmdline_user_args().has("--cold"), "ticks_msec": Time.get_ticks_msec(), "fingerprints": fingerprints(service, slot), "load_result": service.last_load_result(), "snapshot_sha256": JSON.stringify(snapshot).sha256_text(), "clock_minutes": snapshot.get("clock_minutes", snapshot.get("clock", -1)), "cash": snapshot.get("cash", -1), "chips": snapshot.get("chips", -1), "rng": snapshot.get("rng", ""), "pile": snapshot.get("pile", {})}
	if app != null:
		row["host_generations"] = {"dirty": app.get("autosave_dirty_generation"), "inflight": app.get("autosave_inflight_generation"), "completed": app.get("autosave_completed_generation")}
	print("SAVE_GENERATION_PROVENANCE ", JSON.stringify(row))
	var directory := OS.get_environment("BTH_SAVE_PROVENANCE_EVIDENCE_DIR")
	if directory.is_empty():
		return
	# The launcher supplies an already-admitted dedicated evidence directory.
	var path := directory.path_join("save-generation-provenance.jsonl")
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	assert(file != null, "Provenance evidence could not be retained")
	file.seek_end()
	file.store_line(JSON.stringify(row))
	file.flush()
