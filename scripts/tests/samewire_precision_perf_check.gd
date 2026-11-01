extends SceneTree

const Codec := preload("res://scripts/core/run_save_codec.gd")
const Numeric := preload("res://scripts/core/storage_numeric_json.gd")
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var pattern := ["c6f396eaa7770140", "b184385a440f0a40", "0100000000000000", "ffffffffffff0f00", "0000000000001000", "ffffffffffffef7f", "0000000000000080", "9c99999999990943"]
	var values: Array = []
	for index in range(40000):
		values.append(str(pattern[index % pattern.size()]).hex_decode().decode_double(0))
	var source := {"seed_text": "synthetic", "rng_state": "12", "current_environment": {}, "values": values, "opaque": "quoted \\\"2.1834257438008278\\\" ~bth-json-number:0~ ".repeat(1000)}
	var before := var_to_bytes(source)
	var began := Time.get_ticks_msec()
	var packed := Codec.pack_for_storage(source)
	var packed_at := Time.get_ticks_msec()
	if _check(bool(packed.get("ok", false)), "40k mixed finite values pack"):
		var loaded := Codec.unpack_from_storage(packed.packed)
		var finished := Time.get_ticks_msec()
		var exact: bool = loaded.get("values", []).size() == values.size()
		if exact:
			for index in range(values.size()):
				if _bits(loaded["values"][index]) != pattern[index % pattern.size()]:
					exact = false
					break
		_check(exact, "40k numeric leaves retain every exact bit pattern")
		_check(loaded.get("opaque") == source.opaque, "large opaque quoted text remains unchanged")
		_check(var_to_bytes(source) == before, "large pack leaves caller-owned arrays unchanged")
		_check(finished - began < 20000, "40k pack/load completes in bounded 20s native budget")
		facts["pack_ms"] = packed_at - began
		facts["load_ms"] = finished - packed_at
		facts["uncompressed_bytes"] = packed.packed[Codec.STORAGE_SIZE_KEY]
		facts["compressed_bytes"] = packed.packed[Codec.STORAGE_COMPRESSED_SIZE_KEY]
	var negative_zero: float = "0000000000000080".hex_decode().decode_double(0)
	var boundary := {"seed_text": "synthetic", "rng_state": "12", "current_environment": {}, "value": negative_zero}
	Codec.debug_storage_byte_limit_override = JSON.stringify(boundary, "", true, true).to_utf8_buffer().size()
	var failed := Codec.pack_for_storage(boundary)
	_check(not failed.get("ok", true) and failed.get("error_code") == Codec.PACK_ERROR_TOO_LARGE, "final negative-zero sign byte obeys source-byte limit")
	Codec.debug_storage_byte_limit_override = 0
	var huge := {"seed_text": "synthetic", "rng_state": "12", "current_environment": {}, "opaque": "x".repeat(Codec.MAX_STORAGE_BYTES)}
	var size_started := Time.get_ticks_msec()
	var oversized := Codec.pack_for_storage(huge)
	_check(not oversized.get("ok", true) and oversized.get("error_code") == Codec.PACK_ERROR_TOO_LARGE and oversized.get("storage_limit_bytes") == 33554432, "unchanged real 32MiB source limit rejects oversized image")
	facts["limit_rejection_ms"] = Time.get_ticks_msec() - size_started
	facts["engine_static_peak_bytes"] = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	_check(facts.limit_rejection_ms < 15000, "real-limit rejection completes without parsing or compression")
	print("SAMEWIRE_PRECISION_PERF " + JSON.stringify({"checks": checks, "failures": failures, "facts": facts}))
	quit(0 if failures.is_empty() else 1)

func _bits(value: Variant) -> String:
	if typeof(value) != TYPE_FLOAT:
		return "not-float"
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.hex_encode()

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok
