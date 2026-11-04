extends "res://scripts/tests/slot_bonus_family_recovery_check.gd"

# Synthetic direct family producers, not a captured save or player interaction.
# The maintained launcher runs write/read in separate owned OS processes. This
# script never launches a process and never clears the retained save artifacts.
const COLD_SCHEMA := "slot_bonus_family_cold_v1"
const COLD_MANIFEST := "slot_bonus_family_cold_manifest.json"
const COLD_PATH_KEYS := ["APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH"]
const COLD_SOURCE_PATHS := [
	"res://scripts/tests/slot_bonus_family_cold_check.gd",
	"res://scripts/tests/slot_bonus_family_recovery_check.gd",
	"res://scripts/games/slot.gd",
	"res://scripts/games/slots/slot_bonus_recovery.gd",
	"res://scripts/games/slots/slot_machine_state.gd",
	"res://scripts/games/slots/slot_presentation.gd",
	"res://scripts/games/slots/slot_renderer.gd",
	"res://scripts/games/slots/slot_resolver.gd",
	"res://scripts/games/slots/pinball/pinball_feature.gd",
	"res://scripts/games/slots/pinball/pinball_sim.gd",
	"res://scripts/core/save_service.gd",
	"res://scripts/core/run_save_codec.gd",
]

var cold_stage := ""
var writer_pid := -1
var initial_runtime_cache := -1
var cold_cases := 0
var manifest_digest := ""
var companion_files: Array = []


func _run() -> void:
	cold_stage = OS.get_environment("BTH_SLOT_FAMILY_COLD_STAGE")
	if not _private_roots():
		_finish()
		return
	if not _check(cold_stage == "write" or cold_stage == "read", "explicit cold stage is write or read"):
		_finish()
		return
	# Observe before any fixture creation or deliberate cache clearing. A read
	# stage must prove a fresh process, rather than simulate one with a reset.
	initial_runtime_cache = Feature.runtime_session_cache_size()
	if not _check(initial_runtime_cache == 0, cold_stage + " process begins with no Pinball runtime sessions"):
		_finish()
		return
	library = Library.new()
	library.load()
	definition = library.game("slot")
	if not _check(not definition.is_empty(), "authored Slot definition loads"):
		_finish()
		return
	if cold_stage == "write":
		_write_cold_saves()
	else:
		_read_cold_saves()
	_finish()


func _write_cold_saves() -> void:
	writer_pid = OS.get_process_id()
	var records: Array = []
	var service := Saves.new()
	for format_value in FORMATS:
		var format_id := str(format_value)
		var fixture := _fixture("pinball", format_id, "pinball")
		var producer: RunState = fixture.run
		var machine: Dictionary = fixture.machine
		var game := Slot.new()
		game.setup(definition, library)
		var launch: Dictionary = Pinball.new().step_bonus(machine, "slot_bonus_launch", producer.create_rng("recorded_launch"), definition, {"surface_time_msec": 1000})
		var active: Dictionary = Feature.surface_refresh(launch.get("active_bonus", {}), 1032)
		machine["active_bonus"] = active
		if not _check(int(active.get("active_ball_count", 0)) > 0, format_id + " writer has an actual producer-launched midflight ball"):
			continue
		State.write_machine(producer.current_environment, "slot", machine)
		game.checkpoint_surface_ui_state_for_save({}, producer, producer.current_environment)
		machine = State.peek_machine(producer.current_environment, "slot").duplicate(true)
		active = machine.active_bonus
		var durable: Dictionary = active.get(Feature.DURABLE_RUNTIME_KEY, {})
		var checkpoint := Feature.runtime_transaction_checkpoint(active)
		var solver: Dictionary = checkpoint.get("sim", {})
		var expected_payload := Marshalls.variant_to_base64(solver, false)
		if not _check(bool(checkpoint.get("present", false)) and not solver.is_empty() \
				and str(durable.get("schema", "")) == Feature.DURABLE_RUNTIME_SCHEMA \
				and str(durable.get("payload", "")) == expected_payload, format_id + " writer checkpoint is the exact live solver capsule"):
			continue
		for tag_value in TAGS:
			var tag := str(tag_value)
			var label := format_id + "/" + tag
			var run := RunState.new()
			run.from_dict(producer.to_dict())
			_install_tag(run, machine, tag)
			var slot_id := "slot_bonus_family_cold_%s_%s" % [format_id, tag]
			var save_path := ProjectSettings.globalize_path(service.run_save_path(slot_id)).replace("\\", "/").simplify_path()
			if not _check(_cold_contained(save_path), label + " official save path is inside the provided private root"):
				continue
			var before := _all_guard(run)
			var account := run.action_authority_checkpoint_fingerprint()
			var guard := _persistent_fingerprint(_codec_guard_without_family(run))
			if not _check(service.save_run(run, slot_id) == OK, label + " writer installs official SaveService fixture"):
				continue
			_check(_all_guard(run) == before and run.action_authority_checkpoint_fingerprint() == account, label + " official save does not mutate the live producer or account RNG")
			_check(FileAccess.file_exists(save_path), label + " primary save exists after synchronous official install")
			var record := {
				"format": format_id, "tag": tag, "slot_id": slot_id, "save_path": save_path,
				"save_sha256": FileAccess.get_sha256(save_path),
				"solver_payload": expected_payload, "solver_payload_sha256": expected_payload.sha256_text(),
				"solver_rng_state": str(solver.get("rng_state", "")), "solver_tick": int(solver.get("tick", -1)),
				"account_fingerprint": account, "non_tag_guard_fingerprint": guard,
				"economy_fingerprint": _persistent_fingerprint(_economy_guard(run)),
				"bonus_receipts": _bonus_receipts(run),
			}
			records.append(record)
			cold_cases += 1
			facts.append({"case": label, "stage": "write", "slot_id": slot_id, "solver_tick": record.solver_tick, "payload_sha256": record.solver_payload_sha256, "account_fingerprint": account})
	Feature.clear_runtime_session_cache()
	_check(cold_cases == FORMATS.size() * TAGS.size(), "writer persists all nine format/tag fixtures")
	companion_files = _cold_companion_files()
	var manifest := {
		"schema": COLD_SCHEMA, "id": "BTH061-AUDIT-SLOT-LEGACY-FAMILY-004",
		"writer_pid": writer_pid, "writer_output": _cold_output_path(),
		"private_root": private_root, "persistence_paths": _cold_persistence_paths(),
		"source_sha256": _cold_sources(), "companion_files": companion_files,
		"cases": records, "writer_ok": failures.is_empty(),
		"fidelity": "Synthetic direct Pinball family producers; actual midflight solver and existing durable v1 capsule; official SaveService plus companions in one retained private root.",
	}
	var file := FileAccess.open(private_root.path_join(COLD_MANIFEST), FileAccess.WRITE)
	if not _check(file != null, "writer can create the private restart manifest"):
		return
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	manifest_digest = FileAccess.get_sha256(private_root.path_join(COLD_MANIFEST))
	completed = true


func _read_cold_saves() -> void:
	var path := private_root.path_join(COLD_MANIFEST)
	if not _check(FileAccess.file_exists(path), "reader finds retained writer manifest"):
		return
	manifest_digest = FileAccess.get_sha256(path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not _check(typeof(parsed) == TYPE_DICTIONARY, "reader manifest is an object"):
		return
	var manifest: Dictionary = parsed as Dictionary
	writer_pid = int(manifest.get("writer_pid", -1))
	if not _check(str(manifest.get("schema", "")) == COLD_SCHEMA and bool(manifest.get("writer_ok", false)), "reader accepts only the complete successful writer protocol"):
		return
	if not _check(writer_pid > 0 and writer_pid != OS.get_process_id(), "writer and reader are distinct OS processes"):
		return
	if not _check(str(manifest.get("private_root", "")) == private_root \
			and _fingerprint(manifest.get("persistence_paths", {})) == _fingerprint(_cold_persistence_paths()), "reader retains the same private save and companion paths"):
		return
	if not _check(_fingerprint(manifest.get("source_sha256", {})) == _fingerprint(_cold_sources()), "writer and reader use the same fixture codec and production source bytes"):
		return
	var writer_output := str(manifest.get("writer_output", ""))
	if not _check(writer_output.is_empty() or _cold_output_path().is_empty() or writer_output.to_lower() != _cold_output_path().to_lower(), "writer and reader JSON report paths are distinct when provided"):
		return
	companion_files = _cold_companion_files()
	for entry in manifest.get("companion_files", []):
		if typeof(entry) == TYPE_DICTIONARY and bool(entry.get("exists", false)):
			var companion_path := str(entry.get("path", ""))
			_check(_cold_contained(companion_path) and FileAccess.file_exists(companion_path) \
				and FileAccess.get_sha256(companion_path) == str(entry.get("sha256", "")), "reader retains writer companion bytes for " + str(entry.get("key", "")))
	var records_value: Variant = manifest.get("cases", null)
	if not _check(typeof(records_value) == TYPE_ARRAY and (records_value as Array).size() == FORMATS.size() * TAGS.size(), "reader manifest contains all nine cases"):
		return
	var service := Saves.new()
	var seen: Dictionary = {}
	var canonical_projections: Dictionary = {}
	for record_value in records_value as Array:
		if not _check(typeof(record_value) == TYPE_DICTIONARY, "reader case is an object"):
			continue
		var record: Dictionary = record_value as Dictionary
		var format_id := str(record.get("format", ""))
		var tag := str(record.get("tag", ""))
		var label := format_id + "/" + tag
		if not _check(FORMATS.has(format_id) and TAGS.has(tag) and not seen.has(label), label + " is a unique supported writer case"):
			continue
		seen[label] = true
		# The initial empty-cache assertion above precedes any reset. Between cases
		# clear the preceding inspected runtime so shared tag-variant session IDs
		# cannot let a later load borrow already-restored physics.
		if cold_cases > 0:
			Feature.clear_runtime_session_cache()
		if not _check(Feature.runtime_session_cache_size() == 0, label + " begins without an existing runtime"):
			continue
		var slot_id := str(record.get("slot_id", ""))
		var save_path := ProjectSettings.globalize_path(service.run_save_path(slot_id)).replace("\\", "/").simplify_path()
		if not _check(_cold_contained(save_path) and save_path == str(record.get("save_path", "")) \
				and FileAccess.get_sha256(save_path) == str(record.get("save_sha256", "")), label + " reader consumes the exact writer primary file"):
			continue
		var loaded_value: Variant = service.load_run(slot_id)
		if not _check(loaded_value is RunState, label + " official SaveService loads across the process boundary"):
			continue
		var run: RunState = loaded_value as RunState
		_check(Feature.runtime_session_cache_size() == 0, label + " official load itself creates no live solver")
		_check(run.action_authority_checkpoint_fingerprint() == str(record.get("account_fingerprint", "")), label + " account and global RNG fingerprint survive the independent process")
		_check(_persistent_fingerprint(_economy_guard(run)) == str(record.get("economy_fingerprint", "")), label + " wallets RNG clocks town history and turns survive official load")
		_check(_persistent_fingerprint(_codec_guard_without_family(run)) == str(record.get("non_tag_guard_fingerprint", "")), label + " every codec-retained non-tag machine field survives official load")
		var stored := State.peek_machine(run.current_environment, "slot").duplicate(true)
		var durable: Dictionary = (stored.get("active_bonus", {}) as Dictionary).get(Feature.DURABLE_RUNTIME_KEY, {})
		var payload := str(record.get("solver_payload", ""))
		_check(not payload.is_empty() and payload.sha256_text() == str(record.get("solver_payload_sha256", "")) \
			and str(durable.get("payload", "")) == payload, label + " exact existing v1 solver capsule survives the disk/codec boundary")
		var game := Slot.new()
		game.setup(definition, library)
		var before := _all_guard(run)
		var surface: Dictionary = game.surface_state(run, run.current_environment, {"surface_time_msec": 10})
		var shown: Dictionary = surface.get("slot_active_bonus", {})
		var signature: Dictionary = Renderer.new().render_signature(surface, definition, 10, "feature")
		var status := Feature.live_status(shown)
		_check(not bool(surface.get("slot_bonus_recovery_required", false)) and str(shown.get("family", "")) == "pinball" \
			and bool(signature.get("pinball_takeover_active", false)), label + " first new-clock query reaches the current native Pinball projection")
		if _check(Feature.runtime_session_cache_size() == 1 and bool(status.get("runtime_active", false)), label + " first query restores exactly one saved runtime"):
			var restored: Dictionary = Feature.runtime_transaction_checkpoint(shown).get("sim", {})
			_check(Marshalls.variant_to_base64(restored, false) == payload, label + " first query restores every solver array counter and RNG bit without stepping")
			_check(str(restored.get("rng_state", "")) == str(record.get("solver_rng_state", "")) \
				and int(restored.get("tick", -1)) == int(record.get("solver_tick", -2)), label + " recorded solver RNG and tick are exact at the new monotonic origin")
		var projection := _fingerprint(_projection(surface, signature))
		if tag == "canonical":
			canonical_projections[format_id] = projection
		else:
			_check(projection == str(canonical_projections.get(format_id, "")), label + " cold tag-loss projection matches the canonical saved feature")
		var patch: Dictionary = game.surface_realtime_state_patch(run, run.current_environment, {"surface_time_msec": 42}, surface)
		var next_active: Dictionary = patch.get("slot_active_bonus", shown)
		var next_status := Feature.live_status(next_active)
		_check(int(status.get("active_ball_count", 0)) > 0 and int(next_status.get("tick", 0)) > int(status.get("tick", 0)), label + " restored midflight physics remains live at clocks 10 and 42")
		_check(not shown.has(Feature.DURABLE_RUNTIME_KEY) and not next_active.has(Feature.DURABLE_RUNTIME_KEY), label + " presentation does not duplicate the durable capsule")
		_check(_all_guard(run) == before and _without_family(State.peek_machine(run.current_environment, "slot")) == _without_family(stored), label + " cold restore and live presentation preserve all raw non-tag progress and wallet state")
		_check(run.action_authority_checkpoint_fingerprint() == str(record.get("account_fingerprint", "")) \
			and _bonus_receipts(run) == int(record.get("bonus_receipts", -1)), label + " no payout receipt or global RNG draw occurs during restore/presentation")
		_check(FileAccess.get_sha256(save_path) == str(record.get("save_sha256", "")), label + " reader leaves the retained save file unchanged")
		cold_cases += 1
		facts.append({"case": label, "stage": "read", "writer_pid": writer_pid, "reader_pid": OS.get_process_id(), "payload_sha256": payload.sha256_text(), "before_tick": status.get("tick", 0), "after_tick": next_status.get("tick", 0), "solver_rng_state": record.get("solver_rng_state", ""), "account_fingerprint": run.action_authority_checkpoint_fingerprint(), "load_outcome": service.last_load_result()})
	Feature.clear_runtime_session_cache()
	_check(cold_cases == FORMATS.size() * TAGS.size(), "reader verifies all nine independent-process format/tag cases")
	completed = true


func _cold_contained(path: String) -> bool:
	var clean := path.replace("\\", "/").simplify_path().to_lower()
	var target_root := private_root.to_lower()
	return clean.is_absolute_path() and (clean == target_root or clean.begins_with(target_root + "/"))


func _cold_persistence_paths() -> Dictionary:
	var result := {}
	for key in COLD_PATH_KEYS:
		result[key] = OS.get_environment(key).replace("\\", "/").simplify_path()
	return result


func _cold_companion_files() -> Array:
	var result: Array = []
	for key in ["BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path()
		var exists := FileAccess.file_exists(path)
		result.append({"key": key, "path": path, "exists": exists, "sha256": FileAccess.get_sha256(path) if exists else ""})
	return result


func _cold_sources() -> Dictionary:
	var result := {}
	for path in COLD_SOURCE_PATHS:
		result[path] = FileAccess.get_sha256(path)
	return result


func _cold_output_path() -> String:
	var value := OS.get_environment("BTH_TARGET_OUTPUT")
	return "" if value.is_empty() else value.replace("\\", "/").simplify_path()


func _finish() -> void:
	_check(completed, "requested cold stage reaches its final assertion")
	var report := {
		"id": "BTH061-AUDIT-SLOT-LEGACY-FAMILY-004", "stage": "independent-process-" + cold_stage,
		"checks": checks, "failures": failures, "facts": facts, "cases": cold_cases,
		"pid": OS.get_process_id(), "writer_pid": writer_pid, "initial_runtime_cache": initial_runtime_cache,
		"manifest_sha256": manifest_digest, "source_sha256": _cold_sources(), "companion_files": companion_files,
		"fidelity": "Synthetic direct family producers and official SaveService plus retained private companions. Writer/read OS processes must differ; reader proves initial cache zero, exact recorded solver/RNG at clock10 and live progress at42. Later cases explicitly evict only the preceding inspected runtime. No player save, pointer/canvas gameplay or authenticated v1 foreign-payload provenance claim.",
	}
	var output := _cold_output_path()
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
		else:
			_check(false, "cold stage JSON report path is writable")
			report["failures"] = failures
			report["checks"] = checks
	print("SLOT_BONUS_FAMILY_COLD_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
