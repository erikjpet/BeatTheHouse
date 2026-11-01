extends SceneTree

const Codec := preload("res://scripts/core/run_save_codec.gd")
const Numeric := preload("res://scripts/core/storage_numeric_json.gd")
const Saves := preload("res://scripts/core/save_service.gd")
const Store := preload("res://scripts/core/durable_store.gd")
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_BUILD") == "1" and OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-save-float-samewire-atomic-"), "own fresh synthetic resident-key root required"):
		_finish(); return
	var library := ContentLibrary.new()
	library.load(false)
	var run := RunState.new()
	var seed := "ENVIRONMENT-PRACTICE-v1:SYNTHETIC-SAMEWIRE-ATOMIC"
	run.start_new(seed, RunState.custom_challenge("environment_practice", seed, {"environment_practice": true}))
	var generated := RunGenerator.new(library).environment_test_result(run, {"archetype_id": "delta_queen", "scenario_id": "__none", "generation_key": "samewire-atomic", "depth": 0})
	if not _check(generated.get("ok", false), "ordinary generator creates pristine synthetic River room"):
		_finish(); return
	var profile: Dictionary = run.current_environment.game_states.roulette.physics_profile
	profile.diamond_phase = "c6f396eaa7770140".hex_decode().decode_double(0)
	profile.tilt_angle = "b184385a440f0a40".hex_decode().decode_double(0)
	run.challenge_config.modifiers["precision_probe"] = "9c99999999990943".hex_decode().decode_double(0)
	run.challenge_config.modifiers["negative_zero"] = "0000000000000080".hex_decode().decode_double(0)
	_legacy_fixtures(run)
	_atomic_failures(run)
	_raw_fixtures()
	_finish()

func _legacy_fixtures(run: RunState) -> void:
	var snapshot := run.to_save_snapshot()
	var encoded := Codec.encode(snapshot)
	var legacy_text := JSON.stringify(encoded)
	var old_pack := _old_pack(legacy_text)
	var service := Saves.new()
	for shape in ["packed_v1", "unpacked_codec2", "unpacked_codec1"]:
		var slot: String = "samewire_legacy_" + shape
		if not _check(not service.has_run(slot), "new legacy fixture slot " + shape): return
		var body: Dictionary = old_pack if shape == "packed_v1" else encoded.duplicate(true)
		if shape == "unpacked_codec1":
			body[Codec.CODEC_KEY] = 1
			body[Codec.REGISTRY_KEY] = Codec._expand_environment_registry_deltas(body[Codec.REGISTRY_KEY])
		var payload := {"schema": Saves.SAVE_SCHEMA, "version": 2, "act": 1, "slot_id": slot, "run_state": body}
		var installed := Store.write_json(service.run_save_path(slot), payload)
		if not _check(installed.get("ok", false), "generated old-spelling fixture installs " + shape): return
		var loaded: Variant = Saves.new().load_run(slot)
		if not _check(loaded is RunState, "official SaveService reads legacy shape " + shape): return
		var profile: Dictionary = loaded.current_environment.game_states.roulette.physics_profile
		_check(_bits(profile.diamond_phase) == "cbf396eaa7770140" and _bits(profile.tilt_angle) == "a684385a440f0a40", "legacy physics matches recorded decimals, not discarded original digits " + shape)
		_check(_bits(loaded.challenge_config.modifiers.precision_probe) == "9c99999999990943", "approved correction of shared old decimal token " + shape)
		_check(_bits(loaded.challenge_config.modifiers.negative_zero) == "0000000000000000", "old writer erased zero sign; reader does not invent it " + shape)
		_check(not loaded.narrative_flags.has("crew_private_authority_error"), "generated signed legacy public binding validates with resident key " + shape)
		_check(loaded.bankroll == run.bankroll and loaded.rng_state == run.rng_state and loaded.game_clock_minutes == run.game_clock_minutes, "legacy finance/RNG/clock retain exact source values " + shape)
		var tampered: Dictionary = loaded.to_save_snapshot()
		tampered.crew_state.trust.crew_rook += 1
		var rejected := RunState.new()
		rejected.from_dict(tampered)
		_check(rejected.narrative_flags.has("crew_private_authority_error"), "edited legacy bound context remains rejected " + shape)
	facts["legacy_shapes"] = ["packed-v1", "unpacked-codec2", "unpacked-codec1-flat"]
	facts["legacy_fidelity"] = "Current unchanged signer/encoder plus actual old native writer spelling; synthetic, not genuine old-build receipt evidence."

func _atomic_failures(run: RunState) -> void:
	var service := Saves.new()
	var slot := "samewire_atomic"
	if not _check(not service.has_run(slot), "atomic slot begins absent"): return
	if not _check(service.save_run(run, slot) == OK and service.save_run(run, slot) == OK, "two ordinary generations establish primary and backup"): return
	var primary_path := service.run_save_path(slot)
	var backup_path := service.backup_save_path(slot)
	# Save bytes stay in this native process/root. They are never printed, hashed
	# to evidence, copied to another root, or inspected for key material.
	var primary := FileAccess.get_file_as_bytes(primary_path)
	var backup := FileAccess.get_file_as_bytes(backup_path)
	for mode in range(3):
		Codec.debug_storage_byte_limit_override = 64
		var error := OK
		if mode == 0:
			error = service.save_run(run, slot)
		elif mode == 1:
			error = service.begin_save_run(run, slot)
			if error == OK: error = service.wait_for_async_save()
		else:
			error = service._begin_web_save(run.to_save_snapshot_for_encoding(), slot, primary_path, "")
			if error == OK: error = service.wait_for_async_save()
		Codec.debug_storage_byte_limit_override = 0
		_check(error != OK, "size limit rejects save mode " + str(mode))
		_check(FileAccess.get_file_as_bytes(primary_path) == primary and FileAccess.get_file_as_bytes(backup_path) == backup, "failed precise save preserves both generations " + str(mode))
		_check(not FileAccess.file_exists(primary_path + ".tmp") and not service.async_save_in_flight(), "failed pipeline cleans temporary/pending state " + str(mode))
	_check(service.save_run(run, slot) == OK, "retry after size failure succeeds normally")
	primary = FileAccess.get_file_as_bytes(primary_path)
	backup = FileAccess.get_file_as_bytes(backup_path)
	Store.debug_force_rename_failure = true
	var rename_error := service.save_run(run, slot)
	Store.debug_force_rename_failure = false
	_check(rename_error != OK and FileAccess.get_file_as_bytes(primary_path) == primary and FileAccess.get_file_as_bytes(backup_path) == backup, "atomic install failure restores exact prior generations")
	_check(not FileAccess.file_exists(primary_path + ".tmp") and not FileAccess.file_exists(primary_path + ".rollback") and not FileAccess.file_exists(backup_path + ".rollback"), "failed install closes rollback and temporary files")
	FileAccess.open(primary_path, FileAccess.WRITE).store_string("{")
	var fallback := Saves.new()
	var recovered: Variant = fallback.load_run(slot)
	_check(recovered is RunState and fallback.last_load_outcome.get("outcome") == Saves.LOAD_OUTCOME_BACKUP, "truncated primary loads actual compatible backup")
	_check(FileAccess.get_file_as_string(primary_path) == "{" and FileAccess.get_file_as_bytes(backup_path) == backup, "load alone does not rewrite either generation")
	_check(service.save_run(run, slot) == OK, "ordinary save recovers after truncated-primary fallback")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(primary_path))
	payload.run_state[Codec.STORAGE_HASH_KEY] = "0".repeat(64)
	FileAccess.open(primary_path, FileAccess.WRITE).store_string(JSON.stringify(payload))
	fallback = Saves.new()
	recovered = fallback.load_run(slot)
	_check(recovered is RunState and fallback.last_load_outcome.get("outcome") == Saves.LOAD_OUTCOME_BACKUP, "tampered packed source hash cannot mint primary trust")
	_check(not recovered.narrative_flags.has("crew_private_authority_error"), "untouched backup retains resident authenticated binding")
	facts["atomic_scope"] = "sync/threaded/native no-thread pipeline size failure, retry, atomic rename rollback, truncated/tampered primary fallback"

func _raw_fixtures() -> void:
	# Public minimal legacy reader fixtures, not claimed signed/full old runs.
	for envelope in [false, true]:
		var service := Saves.new()
		var slot := "samewire_raw_envelope" if envelope else "samewire_raw_root"
		var raw := {"seed_text": "SYNTHETIC-RAW-DECIMAL", "rng_state": "12", "current_environment": {"id": "raw_numeric_room", "archetype_id": "delta_queen", "game_states": {"roulette": {"physics_profile": {"diamond_phase": "9c99999999990943".hex_decode().decode_double(0)}}}}}
		raw["challenge_config"] = {"mode": "custom", "id": "synthetic", "seed_text": raw.seed_text, "modifiers": {}}
		raw["bankroll"] = 23
		var payload: Dictionary = {"schema": Saves.SAVE_SCHEMA, "version": 1, "act": 1, "run_state": raw} if envelope else raw
		if not _check(not service.has_run(slot) and Store.write_json(service.run_save_path(slot), payload).get("ok", false), "fresh minimal raw legacy fixture installs"):
			return
		var loaded: Variant = service.load_run(slot)
		if not _check(loaded is RunState and _bits(loaded.current_environment.game_states.roulette.physics_profile.diamond_phase) == "9c99999999990943", "outer raw/schema1 reader correctly rounds stored decimal"):
			return
		_check(loaded.rng_state == 12, "raw reader retains exact RNG decimal string")
	facts["raw_scope"] = "Minimal supported raw/schema1 reader shapes only; no genuine historical authority qualification."

func _old_pack(text: String) -> Dictionary:
	var bytes := text.to_utf8_buffer()
	var compressed := bytes.compress(FileAccess.COMPRESSION_ZSTD)
	return {Codec.STORAGE_MARKER_KEY: Codec.STORAGE_FORMAT, Codec.STORAGE_DATA_KEY: Codec._z85_encode(compressed), Codec.STORAGE_HASH_KEY: text.sha256_text(), Codec.STORAGE_SIZE_KEY: bytes.size(), Codec.STORAGE_COMPRESSED_SIZE_KEY: compressed.size()}

func _bits(value: Variant) -> String:
	if typeof(value) != TYPE_FLOAT: return "not-float"
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.hex_encode()

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

func _finish() -> void:
	print("SAMEWIRE_PRECISION_ATOMIC " + JSON.stringify({"checks": checks, "failures": failures, "facts": facts}))
	quit(0 if failures.is_empty() else 1)
