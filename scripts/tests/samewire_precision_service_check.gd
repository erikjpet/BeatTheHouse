extends SceneTree

# NEW synthetic engineering roots only. Engine Save/restore may use its own
# naturally resident key; this harness never names, reads, hashes or copies it.
# No captured save, paid hand, fixture transplant or claimed Web coverage.
const Saves := preload("res://scripts/core/save_service.gd")
const PHASE_BITS := "c6f396eaa7770140"
const TILT_BITS := "b184385a440f0a40"
const SEED := "ENVIRONMENT-PRACTICE-v1:SYNTHETIC-SAVE-FLOAT-PRECISION"
const SLOTS := ["save_float_precision_sync", "save_float_precision_async", "save_float_precision_phased"]
const WARM_RECEIPT := "save_float_precision_warm_receipt.json"
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_BUILD") == "1" and OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-save-float-"), "dedicated new key-local engineering root required"):
		_finish(); return
	if not _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty() and OS.get_environment("BTH_SAVE_CODEC_FIXTURE").is_empty(), "captured saves, Web storage and external fixtures excluded"):
		_finish(); return
	var mode := OS.get_environment("BTH_FLOAT_ROUNDTRIP_MODE")
	if not _check(mode in ["warm", "cold"], "explicit warm/cold mode required"):
		_finish(); return
	facts["mode"] = mode
	if mode == "warm":
		_warm()
	else:
		_cold()
	_finish()

func _warm() -> void:
	var admission := Saves.new()
	if not _check(not FileAccess.file_exists(_receipt_path()), "warm public receipt must not overwrite an earlier attempt"): return
	for slot in SLOTS:
		if not _check(not admission.has_run(slot), "fresh root has no previous slot " + slot): return
	var library := ContentLibrary.new()
	library.load(false)
	var run := RunState.new()
	run.start_new(SEED, RunState.custom_challenge("environment_practice", SEED, {"environment_practice": true}))
	var generated := RunGenerator.new(library).environment_test_result(run, {"archetype_id": "delta_queen", "scenario_id": "__none", "generation_key": "save-float-precision", "depth": 0})
	facts["generation"] = {"ok": generated.get("ok", false), "errors": generated.get("errors", [])}
	if not _check(bool(generated.get("ok", false)) and bool(run.validate_room_action_authority().get("ok", false)), "production generator admits pristine synthetic River room"):
		return
	var table: Dictionary = run.current_environment.get("game_states", {}).get("roulette", {})
	if not _check(not table.is_empty() and typeof(table.get("physics_profile")) == TYPE_DICTIONARY, "generated River room owns a Roulette physics profile"):
		return
	# Public synthetic precision sentinels only. Do not change a paid outcome,
	# receipt, RNG, job, finance, room inventory or scenario owner.
	table.physics_profile.diamond_phase = PHASE_BITS.hex_decode().decode_double(0)
	table.physics_profile.tilt_angle = TILT_BITS.hex_decode().decode_double(0)
	table.physics_profile["samewire_probes"] = []
	for bit_text in ["0000000000000080", "0100000000000000", "ffffffffffff0f00", "0000000000001000", "ffffffffffffef7f", "9c99999999990943"]:
		table.physics_profile.samewire_probes.append(str(bit_text).hex_decode().decode_double(0))
	var expected := _witness(run)
	for index in range(SLOTS.size()):
		var slot: String = SLOTS[index]
		var service := Saves.new()
		var error := OK
		if index == 0:
			error = service.save_run(run, slot)
		elif index == 1:
			error = service.begin_save_run(run, slot)
			if error == OK: error = service.wait_for_async_save()
		else:
			# Native execution of the same no-thread Web phases, not browser proof.
			error = service._begin_web_save(run.to_save_snapshot_for_encoding(), slot, service.run_save_path(slot), "")
			if error == OK: error = service.wait_for_async_save()
		if not _check(error == OK, "normal save pipeline completes " + slot): return
		_check(_witness(run) == expected, "Save leaves live physics/custody unchanged " + slot)
		var restored: Variant = Saves.new().load_run(slot)
		if not _check(restored is RunState, "fresh SaveService restores " + slot): return
		_check(_witness(restored) == expected, "fresh load retains exact physics/core witness " + slot)
		_check(not restored.narrative_flags.has("crew_private_authority_error"), "resident private capsule remains valid " + slot)
	facts["expected"] = expected
	# Keep real authenticated payloads in memory only. Editing their public bound
	# context must still fail existing authentication; no re-signing or bypass.
	var tampered := run.to_save_snapshot()
	var crew: Dictionary = tampered.get("crew_state", {})
	if not _check(not str(crew.get("a", "")).is_empty() and not str(crew.get("z", "")).is_empty(), "ordinary snapshot contains its normal opaque authority capsule"):
		return
	var trust: Dictionary = crew.get("trust", {})
	trust["crew_rook"] = int(trust.get("crew_rook", 0)) + 1
	var rejected := RunState.new()
	rejected.from_dict(tampered)
	_check(rejected.narrative_flags.has("crew_private_authority_error"), "edited bound context remains rejected with resident authority")

func _cold() -> void:
	# New process, exact SAME original warm root and resident key. No new save,
	# creation, profile copy, key transplant or normal-game outcome replay.
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(_receipt_path()))
	if not _check(typeof(receipt) == TYPE_DICTIONARY and receipt.get("schema", "") == "bth.save_float_precision.native/v1" and receipt.get("failures", ["missing"]).is_empty() and receipt.get("facts", {}).get("mode", "") == "warm", "successful own warm metadata receipt required"):
		return
	var expected: Dictionary = receipt.facts.get("expected", {})
	if not _check(not expected.is_empty(), "warm receipt contains public physics/core witness"): return
	for slot in SLOTS:
		var restored: Variant = Saves.new().load_run(slot)
		if not _check(restored is RunState, "fresh process loads original resident slot " + slot): return
		_check(_witness(restored) == expected, "cold exact physics/core witness " + slot)
		_check(not restored.narrative_flags.has("crew_private_authority_error"), "cold resident authority remains valid " + slot)
	facts["cold_read_only_slots"] = SLOTS.duplicate()

func _witness(run: RunState) -> Dictionary:
	var profile: Dictionary = run.current_environment.get("game_states", {}).get("roulette", {}).get("physics_profile", {})
	var bits: Dictionary = {}
	for key in profile:
		if typeof(profile[key]) in [TYPE_INT, TYPE_FLOAT]:
			var value := PackedByteArray()
			value.resize(8)
			value.encode_double(0, float(profile[key]))
			bits[key] = value.hex_encode()
		else:
			bits[key] = str(profile[key])
	var probes: Array = []
	for number in profile.get("samewire_probes", []):
		var encoded := PackedByteArray()
		encoded.resize(8)
		encoded.encode_double(0, number)
		probes.append(encoded.hex_encode())
	return {"seed": run.seed_text, "cash": str(run.bankroll), "chips": str(run.grand_casino_chips), "rng_seed": str(run.rng_seed), "rng_state": str(run.rng_state), "clock": str(run.game_clock_minutes), "status": run.run_status, "jobs": _typed(run.crew_jobs), "story_rows": str(run.story_log.size()), "physics_bits": bits, "probe_bits": probes}

# Exact test-metadata transport, not a save-format change. The original cold
# receipt used JSON on typed jobs, changing expected ints to floats. Preserve
# every field/type with decimal integer strings and exact float-bit strings.
func _typed(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		for key in value:
			result[key] = _typed(value[key])
		return {"kind": "dictionary", "value": result}
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for child in value:
			result.append(_typed(child))
		return {"kind": "array", "value": result}
	if typeof(value) == TYPE_INT:
		return {"kind": "int", "value": str(value)}
	if typeof(value) == TYPE_FLOAT:
		var bytes := PackedByteArray()
		bytes.resize(8)
		bytes.encode_double(0, value)
		return {"kind": "float", "value": bytes.hex_encode()}
	if typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_STRING]:
		return {"kind": str(typeof(value)), "value": value}
	_check(false, "unexpected public jobs witness type")
	return {"kind": "unsupported"}

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

func _receipt_path() -> String:
	# Fixed public test metadata in this same new engineering root. No caller
	# filename, arbitrary profile read or key path is accepted by the harness.
	return OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").path_join(WARM_RECEIPT)

func _finish() -> void:
	var result := {"schema": "bth.save_float_precision.native/v1", "checks": checks, "failures": failures, "facts": facts, "scope": "new synthetic key-local SaveService regression; not paid-outcome or browser proof"}
	if failures.is_empty() and facts.get("mode", "") == "warm":
		FileAccess.open(_receipt_path(), FileAccess.WRITE).store_string(JSON.stringify(result, "  "))
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty(): FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(result, "  "))
	print("SAMEWIRE_PRECISION_SERVICE " + JSON.stringify({"checks": checks, "failures": failures, "mode": facts.get("mode", "unadmitted")}))
	quit(0 if failures.is_empty() else 1)
