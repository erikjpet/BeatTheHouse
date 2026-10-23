extends SceneTree

const Codec := preload("res://scripts/core/run_save_codec.gd")
const Store := preload("res://scripts/core/durable_store.gd")
const Saves := preload("res://scripts/core/save_service.gd")
var failures: Array[String] = []
var checks := 0


func _init() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)


func _run() -> void:
	for size in [0, 1, 2, 3, 4, 5, 7, 8, 31, 255, 1025]:
		var bytes := PackedByteArray()
		bytes.resize(size)
		for index in range(size):
			bytes[index] = (index * 73 + 255) % 256
		var text := Codec._z85_encode(bytes)
		_check(text == Codec._z85_encode_gdscript(bytes), "encode fallback %d" % size)
		_check(Codec._z85_decode(text, size) == bytes, "decode exact bytes %d" % size)
	_check(Codec._z85_decode("invalid", 4).is_empty(), "invalid group length rejected")
	_check(Codec._z85_decode("~~~~~", 4).is_empty(), "invalid alphabet rejected")
	_check(Codec._z85_decode("00000", 5).is_empty(), "invalid expected length rejected")
	var payload := {"schema": Saves.SAVE_SCHEMA, "version": Saves.SAVE_VERSION, "act": 1, "slot_id": "codec_check", "run_state": {}}
	var fixture := OS.get_environment("BTH_SAVE_CODEC_FIXTURE")
	if fixture.is_empty():
		payload["run_state"] = Codec.pack_for_storage({"seed_text": "save-codec-contract", "rng_state": "9223372036854775806", "current_environment": {}, "act": 1}).get("packed", {})
	else:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(fixture))
		_check(typeof(parsed) == TYPE_DICTIONARY, "private fixture parsed")
		if typeof(parsed) != TYPE_DICTIONARY:
			_finish()
			return
		payload = parsed as Dictionary
	var packed: Dictionary = payload.get("run_state", {})
	var started := Time.get_ticks_usec()
	var raw := Codec._z85_decode_gdscript(str(packed.get("data", "")), int(packed.get("compressed_bytes", 0)))
	var decode_usec := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var text := Codec._z85_encode_gdscript(raw)
	var encode_usec := Time.get_ticks_usec() - started
	_check(not raw.is_empty() and text == packed.get("data", ""), "real save exact encoded bytes")
	_check(Codec._z85_decode(text, raw.size()) == raw, "real save exact decoded bytes")
	var unpacked := Codec.unpack_from_storage(packed)
	_check(not unpacked.is_empty(), "original compressed content/hash validated")
	var detached := Codec.unpack_from_storage(packed)
	detached.get("current_environment", {}).clear()
	detached["owned_parse_probe"] = [1, 2, 3]
	_check(Codec.unpack_from_storage(packed) == unpacked and not unpacked.has("owned_parse_probe"), "each fresh JSON parse owns its graph independently of returned mutations")
	var roundtrip := Codec.unpack_from_storage(Codec.pack_for_storage(unpacked).get("packed", {}))
	_check(roundtrip == unpacked, "complete storage state/RNG roundtrip")
	var legacy := {"seed_text":"legacy-int-probe", "rng_state":"9223372036854775806", "current_environment":{Codec.BLACKJACK_LEDGER_KEY:{"counter":9223372036854775806}}}
	var legacy_packed: Dictionary = Codec.pack_for_storage(legacy).get("packed", {})
	var restored := Codec.decode(Codec.unpack_from_storage(legacy_packed))
	_check(restored["current_environment"][Codec.BLACKJACK_LEDGER_KEY]["counter"] == 9223372036854775806, "real legacy load retains exact authority integer repair")
	var validation_payload := {"schema":Saves.SAVE_SCHEMA, "run_state":legacy_packed}
	_check(Saves._payload_dictionary_loadable(validation_payload), "validation accepts intact legacy content without restoring integer types")
	var invalid_legacy := legacy_packed.duplicate(true)
	invalid_legacy[Codec.STORAGE_HASH_KEY] = "0".repeat(64)
	validation_payload["run_state"] = invalid_legacy
	_check(not Saves._payload_dictionary_loadable(validation_payload), "validation still rejects legacy content hash damage")
	validation_payload["run_state"] = Codec.pack_for_storage({"current_environment":{}}).get("packed", {})
	_check(not Saves._payload_dictionary_loadable(validation_payload), "validation still requires complete root fields")
	var damaged := packed.duplicate(true)
	damaged["sha256"] = "0".repeat(64)
	_check(Codec.unpack_from_storage(damaged).is_empty(), "content hash mismatch rejected")
	damaged = packed.duplicate(true)
	damaged["data"] = "~" + str(damaged.get("data", "")).substr(1)
	_check(Codec.unpack_from_storage(damaged).is_empty(), "compressed data damage rejected")
	var path := "user://save_byte_codec_check/run.json"
	var validator := Callable(Saves, "_payload_dictionary_loadable")
	var initial := Store.write_json(path, payload, validator, true)
	_check(bool(initial.get("ok", false)), "validated primary installed")
	var original_bytes := FileAccess.get_file_as_bytes(path)
	var next := payload.duplicate(true)
	next["slot_id"] = "codec_next"
	Store.set_debug_fail_transition(Store.TRANSITION_INSTALL_PRIMARY)
	var failed := Store.write_json(path, next, validator, true, str(initial.get("validated_sha256", "")))
	Store.reset_debug_faults()
	_check(not bool(failed.get("ok", true)) and FileAccess.get_file_as_bytes(path) == original_bytes, "failed install preserves exact prior generation")
	var installed := Store.write_json(path, next, validator, true, str(initial.get("validated_sha256", "")))
	_check(bool(installed.get("ok", false)), "retry installs once")
	_check(FileAccess.get_file_as_bytes(Store.backup_path(path)) == original_bytes, "backup is exact prior generation")
	print(JSON.stringify({"legacy_z85_encode_usec": encode_usec, "legacy_z85_decode_usec": decode_usec, "compressed_bytes": raw.size(), "native_timing_only": true}))
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("SAVE_STORAGE_BYTE_CODEC PASS checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
