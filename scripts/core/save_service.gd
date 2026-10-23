class_name SaveService
extends RefCounted

# Saves and loads foundation RunState data by slot.

const SAVE_DIR := "user://saves"
const PersistencePathsScript := preload("res://scripts/core/persistence_paths.gd")
const SAVE_SCHEMA := "beat_the_house.foundation_run"
const SAVE_VERSION := 2
const RunSaveCodecScript := preload("res://scripts/core/run_save_codec.gd")
const DurableStoreScript := preload("res://scripts/core/durable_store.gd")
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
# In-memory proof for exact primary bytes validated on load or install.
# Entries bind the exact file bytes to the absolute path, never just mtime/size.
var trusted_primary_fingerprints: Dictionary = {}
var async_task_id: int = -1
var async_result_box: Dictionary = {}
var async_slot_id: String = ""
var _web_save_job: Dictionary = {}
var _web_save_step_frame: int = -1
var io_mutex := Mutex.new()
var last_save_outcome: Dictionary = {"ok": true, "error": OK, "error_code": ""}


# Checks whether a run save exists.
func has_run(slot_id: String = "autosave") -> bool:
	var clean_slot := _slot_id(slot_id)
	io_mutex.lock()
	var result := _primary_digest_is_trusted(clean_slot, run_save_path(clean_slot))
	if not result:
		result = bool(_slot_status_unlocked(clean_slot).get("has_loadable", false))
	io_mutex.unlock()
	return result


# Writes run state to a save slot.
func save_run(run_state: RunState, slot_id: String = "autosave") -> Error:
	if run_state == null:
		last_save_outcome = {"ok": false, "error": ERR_INVALID_PARAMETER, "error_code": "invalid_run_state"}
		return ERR_INVALID_PARAMETER
	if async_save_in_flight():
		var async_error := wait_for_async_save()
		if async_error != OK:
			return async_error
	var clean_slot := _slot_id(slot_id)
	# Use the same immutable environment compilations as begin_save_run. The
	# codec owns its encoded output; synchronous durability still completes here.
	var payload_result := _save_payload_result(run_state.to_save_snapshot_for_encoding(), clean_slot)
	if not bool(payload_result.get("ok", false)):
		trusted_primary_fingerprints.erase(clean_slot)
		last_save_outcome = payload_result.duplicate(true)
		return int(payload_result.get("error", FAILED))
	var payload: Dictionary = payload_result.get("payload", {})
	var path := run_save_path(clean_slot)
	var result := DurableStoreScript.write_json(
		path, payload, Callable(self, "_payload_dictionary_loadable"), true,
		_trusted_primary_digest(clean_slot, path)
	)
	var install_error := int(result.get("error", FAILED))
	if bool(result.get("ok", false)):
		_remember_primary_digest(clean_slot, path, str(result.get("validated_sha256", "")))
		last_save_outcome = {"ok": true, "error": OK, "error_code": "", "slot_id": clean_slot}
	else:
		trusted_primary_fingerprints.erase(clean_slot)
		last_save_outcome = result.duplicate(true)
		last_save_outcome["slot_id"] = clean_slot
	return install_error


# Captures one RunState generation. Threaded builds project and install on a
# worker. No-thread Web builds own the encoded generation before yielding, then
# pack, validate bytes/JSON and atomically install on separate frames. FoundationMain coalesces newer
# dirty generations while this one bounded job is in flight.
func begin_save_run(run_state: RunState, slot_id: String = "autosave") -> Error:
	if run_state == null:
		return ERR_INVALID_PARAMETER
	if async_save_in_flight():
		return ERR_BUSY
	var clean_slot := _slot_id(slot_id)
	# Seeded scenario definitions are immutable content. The worker may share those
	# records while encoding; recursively copying them on the input thread made an
	# otherwise asynchronous late-run save pause every active cabinet frame.
	var runtime_snapshot := run_state.to_save_snapshot_for_encoding()
	var path := run_save_path(clean_slot)
	var backup_path := backup_save_path(clean_slot)
	# A prior installed generation can be reused only if the worker finds those
	# exact validated bytes again. A changed or unknown primary is fully checked.
	var primary_digest := _trusted_primary_digest(clean_slot, path)
	if OS.has_feature("web") and OS.has_feature("nothreads"):
		return _begin_web_save(runtime_snapshot, clean_slot, path, primary_digest)
	async_result_box = {"error": ERR_BUSY, "slot_id": clean_slot}
	async_slot_id = clean_slot
	async_task_id = WorkerThreadPool.add_task(
		Callable(self, "_async_save_worker").bind(runtime_snapshot, clean_slot, path, backup_path, primary_digest, async_result_box),
		false,
		"Beat the House autosave"
	)
	return OK


func async_save_in_flight() -> bool:
	return async_task_id >= 0 or not _web_save_job.is_empty()


# No-thread Web exports run WorkerThreadPool.add_task synchronously. Capture
# and encode before yielding: the codec owns all output containers, so later
# frame/input mutations cannot change this generation. Keep one job, with two
# remaining bounded phases (pack, bytes/hash, JSON roots, atomic install), one
# per frame. Each proof binds the exact owned compressed envelope.
# Foundation retains its existing single coalesced newer dirty generation.
func _begin_web_save(runtime_snapshot: Dictionary, slot_id: String, path: String, primary_digest: String) -> Error:
	if async_save_in_flight():
		return ERR_BUSY
	var encoded := RunSaveCodecScript.encode(runtime_snapshot)
	async_result_box = {"error": ERR_BUSY, "slot_id": slot_id}
	async_slot_id = slot_id
	_web_save_job = {
		"phase": "pack",
		"encoded": encoded,
		"act": maxi(1, int(runtime_snapshot.get("act", 1))),
		"path": path,
		"primary_digest": primary_digest,
	}
	_web_save_step_frame = Engine.get_process_frames()
	return OK


func _advance_web_save_step() -> void:
	var phase := str(_web_save_job.get("phase", ""))
	if phase == "pack":
		var packed := RunSaveCodecScript.pack_for_storage(_web_save_job.get("encoded", {}))
		var payload_result := _payload_from_storage_pack(packed, int(_web_save_job.get("act", 1)), async_slot_id)
		_web_save_job.erase("encoded")
		if not bool(payload_result.get("ok", false)):
			async_result_box = payload_result
			_web_save_job["phase"] = "done"
			return
		_web_save_job["payload"] = payload_result.get("payload", {})
		_web_save_job["phase"] = "validate_bytes"
		return
	if phase == "validate_bytes":
		var payload: Dictionary = _web_save_job.get("payload", {})
		var storage: Dictionary = (payload.get("run_state", {}) as Dictionary).duplicate(true)
		var source := RunSaveCodecScript._validated_storage_source(storage)
		if source.is_empty():
			_fail_web_content_validation()
			return
		# Capture the envelope now, with its verified bytes. A later mutation of
		# the pending payload must never acquire a proof for different content.
		_web_save_job["verified_storage"] = storage
		_web_save_job["source"] = source
		_web_save_job["phase"] = "validate_json"
		return
	if phase == "validate_json":
		var source: PackedByteArray = _web_save_job.get("source", PackedByteArray())
		var valid := RunSaveCodecScript._json_content_roots_valid(source.get_string_from_utf8())
		_web_save_job.erase("source")
		if not valid:
			_fail_web_content_validation()
			return
		_web_save_job["phase"] = "install"
		return
	if phase == "install":
		io_mutex.lock()
		async_result_box["error"] = _write_payload_atomic(
			_web_save_job.get("payload", {}), str(_web_save_job.get("path", "")), "",
			str(_web_save_job.get("primary_digest", "")), async_result_box,
			_web_save_job.get("verified_storage", {})
		)
		io_mutex.unlock()
		_web_save_job.erase("payload")
		_web_save_job["phase"] = "done"


func _fail_web_content_validation() -> void:
	async_result_box = {"error": ERR_FILE_CORRUPT, "error_code": "temporary_generation_invalid", "slot_id": async_slot_id}
	_web_save_job.erase("source")
	_web_save_job.erase("verified_storage")
	_web_save_job["phase"] = "done"


func poll_async_save() -> Dictionary:
	if not _web_save_job.is_empty():
		# Multiple polls in one frame must not collapse the phases into a hitch.
		if _web_save_step_frame == Engine.get_process_frames():
			return {"completed": false, "in_flight": true, "slot_id": async_slot_id}
		_web_save_step_frame = Engine.get_process_frames()
		_advance_web_save_step()
		if str(_web_save_job.get("phase", "")) == "done":
			return _finish_async_save_result()
		return {"completed": false, "in_flight": true, "slot_id": async_slot_id}
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
	var installed_path := ProjectSettings.globalize_path(run_save_path(async_slot_id))
	var validated_digest := str(result.get("validated_sha256", ""))
	# The writer already validated the installed generation. Reuse that proof
	# only for the same bytes; an external change still takes the full validator.
	var same_validated_bytes := not validated_digest.is_empty() \
		and FileAccess.file_exists(installed_path) \
		and FileAccess.get_sha256(installed_path) == validated_digest
	if int(result.get("error", FAILED)) == OK and (same_validated_bytes or _worker_payload_loadable(installed_path)):
		if same_validated_bytes:
			_remember_primary_digest(async_slot_id, run_save_path(async_slot_id), validated_digest)
		else:
			# An externally replaced but loadable install has no matching worker proof.
			trusted_primary_fingerprints.erase(async_slot_id)
		result["ok"] = true
	else:
		trusted_primary_fingerprints.erase(async_slot_id)
		if int(result.get("error", FAILED)) == OK:
			result["error"] = ERR_FILE_CORRUPT
			result["error_code"] = "installed_generation_invalid"
		result["ok"] = false
	result.erase("validated_sha256")
	last_save_outcome = result.duplicate(true)
	async_task_id = -1
	_web_save_job = {}
	_web_save_step_frame = -1
	async_result_box = {}
	async_slot_id = ""
	return result


func wait_for_async_save() -> Error:
	if not _web_save_job.is_empty():
		# Explicit Save/Continue/clear/navigation boundaries still drain and wait.
		# Four finite remaining phases; do not create an unbounded queue.
		for _step in range(4):
			if str(_web_save_job.get("phase", "")) == "done":
				break
			_advance_web_save_step()
		if str(_web_save_job.get("phase", "")) != "done":
			return ERR_BUSY
		var web_result := _finish_async_save_result()
		return int(web_result.get("error", FAILED))
	if async_task_id < 0:
		return OK
	WorkerThreadPool.wait_for_task_completion(async_task_id)
	var result := _finish_async_save_result()
	return int(result.get("error", FAILED))


func _async_save_worker(runtime_snapshot: Dictionary, slot_id: String, path: String, backup_path: String, primary_digest: String, result_box: Dictionary) -> void:
	var payload_result := _save_payload_result(runtime_snapshot, slot_id)
	if not bool(payload_result.get("ok", false)):
		for key in payload_result.keys():
			result_box[key] = payload_result[key]
		return
	var payload := {
		"schema": SAVE_SCHEMA,
		"version": SAVE_VERSION,
		"act": maxi(1, int(runtime_snapshot.get("act", 1))),
		"slot_id": slot_id,
		"run_state": (payload_result.get("payload", {}) as Dictionary).get("run_state", {}),
	}
	io_mutex.lock()
	result_box["error"] = _write_payload_atomic(payload, path, backup_path, primary_digest, result_box)
	io_mutex.unlock()


func _write_payload_atomic(payload: Dictionary, path: String, _backup_path: String, primary_digest: String = "", result_box: Dictionary = {}, verified_storage: Dictionary = {}) -> Error:
	var validator := Callable(self, "_payload_dictionary_loadable")
	if not verified_storage.is_empty():
		validator = Callable(self, "_payload_with_verified_storage_loadable").bind(verified_storage)
	var result := DurableStoreScript.write_json(path, payload, validator, true, primary_digest)
	if bool(result.get("ok", false)):
		result_box["validated_sha256"] = str(result.get("validated_sha256", ""))
	return int(result.get("error", FAILED))


static func _payload_with_verified_storage_loadable(payload: Dictionary, verified: Dictionary) -> bool:
	var storage_value: Variant = payload.get("run_state", {})
	if payload.get("schema", "") == SAVE_SCHEMA and typeof(storage_value) == TYPE_DICTIONARY:
		var storage: Dictionary = storage_value
		# Match every envelope field using the same coercions as the original
		# validator. Parsed JSON numbers may be floats; all content bytes and the
		# content hash must still be exactly those checked on the prior frames.
		if storage.size() == 5 and str(storage.get(RunSaveCodecScript.STORAGE_MARKER_KEY, "")) == str(verified.get(RunSaveCodecScript.STORAGE_MARKER_KEY, "")) \
				and str(storage.get(RunSaveCodecScript.STORAGE_DATA_KEY, "")) == str(verified.get(RunSaveCodecScript.STORAGE_DATA_KEY, "")) \
				and str(storage.get(RunSaveCodecScript.STORAGE_HASH_KEY, "")) == str(verified.get(RunSaveCodecScript.STORAGE_HASH_KEY, "")) \
				and int(storage.get(RunSaveCodecScript.STORAGE_SIZE_KEY, 0)) == int(verified.get(RunSaveCodecScript.STORAGE_SIZE_KEY, 0)) \
				and int(storage.get(RunSaveCodecScript.STORAGE_COMPRESSED_SIZE_KEY, 0)) == int(verified.get(RunSaveCodecScript.STORAGE_COMPRESSED_SIZE_KEY, 0)):
			return true
	# The old primary may be a different generation, or temporary content may
	# have changed. Preserve full validation rather than trusting that image.
	return _payload_dictionary_loadable(payload)


static func _worker_payload_loadable(absolute_path: String) -> bool:
	var text := FileAccess.get_file_as_string(absolute_path)
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = json.data
	return _payload_dictionary_loadable(payload)


static func _payload_dictionary_loadable(payload: Dictionary) -> bool:
	if payload.get("schema", "") == SAVE_SCHEMA:
		var run_data: Variant = payload.get("run_state", {})
		if typeof(run_data) != TYPE_DICTIONARY or not RunSaveCodecScript.storage_envelope_valid(run_data as Dictionary):
			return false
		# Slot discovery must reject damaged compressed data, not merely an
		# envelope whose field names and lengths look plausible.  Decompression
		# and the content hash are still much cheaper than constructing RunState.
		# This is only a content/hash/JSON/root-field check, not a restore. Legacy
		# ledger integer-token repair belongs to the real load below; rewriting
		# every ledger here adds work to each temporary/installed validation.
		return RunSaveCodecScript.storage_contents_valid(run_data as Dictionary)
	return payload.has("seed_text") and payload.has("rng_state") and payload.has("current_environment")


# Loads run state from a save slot.
func load_run(slot_id: String = "autosave") -> Variant:
	if async_save_in_flight():
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
		# Reuse only the exact bytes already checked by the normal primary load.
		# The next save still hashes the actual file before trusting this proof.
		_remember_primary_digest(clean_slot, run_save_path(clean_slot), str(primary.get("validated_sha256", "")))
		last_load_outcome = _load_outcome(clean_slot, LOAD_OUTCOME_PRIMARY, primary, backup)
		return primary.get("run_state")
	var backup := _read_run_state_from_path(backup_save_path(clean_slot))
	trusted_primary_fingerprints.erase(clean_slot)
	if bool(backup.get("loadable", false)):
		last_load_outcome = _load_outcome(clean_slot, LOAD_OUTCOME_BACKUP, primary, backup)
		return backup.get("run_state")
	last_load_outcome = _load_outcome(clean_slot, LOAD_OUTCOME_NONE, primary, backup)
	return null


# Removes both generations of a slot so a deliberately skipped tutorial cannot resume.
func clear_run(slot_id: String = "autosave") -> Error:
	if async_save_in_flight():
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
	# Menu/status polling only needs to know whether each atomic generation has a
	# valid save envelope. Constructing and normalizing two complete RunStates on
	# every hidden or visible menu refresh made late-run UI checks take seconds.
	# Continue/load remains the boundary that performs the full trusted restore.
	var primary := _slot_generation_status(run_save_path(clean_slot))
	var backup := _slot_generation_status(backup_save_path(clean_slot))
	var primary_loadable := bool(primary.get("loadable", false))
	var backup_loadable := bool(backup.get("loadable", false))
	if not primary_loadable:
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


func _slot_generation_status(path: String) -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(path)
	var exists := FileAccess.file_exists(absolute_path)
	return {
		"exists": exists,
		"loadable": exists and _worker_payload_loadable(absolute_path),
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
	var result := _save_payload_result(run_state.to_save_snapshot(), slot_id)
	return result.get("payload", {}) if bool(result.get("ok", false)) else {}


static func _save_payload_result(runtime_snapshot: Dictionary, slot_id: String) -> Dictionary:
	var packed_result := RunSaveCodecScript.pack_for_storage(RunSaveCodecScript.encode(runtime_snapshot))
	return _payload_from_storage_pack(packed_result, maxi(1, int(runtime_snapshot.get("act", 1))), slot_id)


static func _payload_from_storage_pack(packed_result: Dictionary, act: int, slot_id: String) -> Dictionary:
	if not bool(packed_result.get("ok", false)):
		return {
			"ok": false,
			"error": int(packed_result.get("error", FAILED)),
			"error_code": str(packed_result.get("error_code", "encode_failed")),
			"slot_id": slot_id,
		}
	return {"ok": true, "error": OK, "error_code": "", "slot_id": slot_id, "payload": {
		"schema": SAVE_SCHEMA,
		"version": SAVE_VERSION,
		"act": act,
		"slot_id": slot_id,
		"run_state": packed_result.get("packed", {}),
	}}


# Accepts current envelopes and previous raw foundation RunState dictionaries.
func _run_data_from_payload(payload: Dictionary, validation_proof: Dictionary = {}) -> Dictionary:
	if payload.get("schema", "") == SAVE_SCHEMA:
		var run_data: Variant = payload.get("run_state", {})
		if typeof(run_data) != TYPE_DICTIONARY:
			return {}
		var unpacked_run_data := RunSaveCodecScript.unpack_from_storage(run_data as Dictionary)
		if unpacked_run_data.is_empty():
			return {}
		# These are the same pre-decode checks as _payload_dictionary_loadable.
		# Normalized RunState defaults must never mint a durable-generation proof.
		validation_proof["loadable"] = unpacked_run_data.has("seed_text") and unpacked_run_data.has("rng_state") and unpacked_run_data.has("current_environment")
		var copied_run_data := RunSaveCodecScript.decode(unpacked_run_data)
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
	var load_text := RunSaveCodecScript.preserve_blackjack_ledger_integer_tokens(text)
	if json.parse(load_text) != OK:
		return {"exists": true, "loadable": false, "run_state": null}
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"exists": true, "loadable": false, "run_state": null}
	var validation_proof: Dictionary = {}
	var run_data := _run_data_from_payload(parsed as Dictionary, validation_proof)
	if run_data.is_empty():
		return {"exists": true, "loadable": false, "run_state": null}
	var run_state := RunState.new()
	run_state.from_dict(run_data)
	var result := {"exists": true, "loadable": true, "run_state": run_state}
	# A ledger rewrite, raw/unknown envelope, failed unpack, or absent required
	# field keeps the existing full-validation path on the following save.
	if load_text == text and bool(validation_proof.get("loadable", false)):
		result["validated_sha256"] = text.sha256_text()
	return result
func _trusted_primary_digest(slot_id: String, path: String) -> String:
	var entry_value: Variant = trusted_primary_fingerprints.get(slot_id, {})
	if typeof(entry_value) != TYPE_DICTIONARY:
		return ""
	var entry: Dictionary = entry_value
	if str(entry.get("absolute_path", "")) != ProjectSettings.globalize_path(path):
		trusted_primary_fingerprints.erase(slot_id)
		return ""
	var digest := str(entry.get("sha256", ""))
	return digest if digest.length() == 64 else ""


func _primary_digest_is_trusted(slot_id: String, path: String) -> bool:
	var digest := _trusted_primary_digest(slot_id, path)
	if digest.is_empty():
		return false
	var absolute_path := ProjectSettings.globalize_path(path)
	var matches := FileAccess.file_exists(absolute_path) and FileAccess.get_sha256(absolute_path) == digest
	if not matches:
		trusted_primary_fingerprints.erase(slot_id)
	return matches


func _remember_primary_digest(slot_id: String, path: String, digest: String) -> void:
	if digest.length() != 64:
		trusted_primary_fingerprints.erase(slot_id)
		return
	trusted_primary_fingerprints[slot_id] = {
		"absolute_path": ProjectSettings.globalize_path(path),
		"sha256": digest,
	}


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
