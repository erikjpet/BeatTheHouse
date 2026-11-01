extends SceneTree

# Public synthetic values only. No profile, key, captured save or paid action.
# These bit patterns come from the retained River diagnostic, not a reconstructed
# user run. Legacy expectations are the OLD stored/loaded values.
const Codec := preload("res://scripts/core/run_save_codec.gd")
const Saves := preload("res://scripts/core/save_service.gd")
const Ritual := preload("res://scripts/core/game_ritual_runtime.gd")
const CrewTurn := preload("res://scripts/core/crew_turn_model.gd")
const Roulette := preload("res://scripts/games/roulette.gd")
const PHASE_BITS := "c6f396eaa7770140"
const TILT_BITS := "b184385a440f0a40"
const OLD_PHASE_BITS := "cbf396eaa7770140"
const OLD_TILT_BITS := "a684385a440f0a40"
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var profile := {"diamond_phase": PHASE_BITS.hex_decode().decode_double(0), "tilt_angle": TILT_BITS.hex_decode().decode_double(0)}
	_check(_bits(profile.diamond_phase) != OLD_PHASE_BITS and _bits(profile.tilt_angle) != OLD_TILT_BITS, "exact comparator detects both retained ULP changes")
	var environment := {"id": "synthetic_float_room", "archetype_id": "delta_queen", "game_states": {"roulette": {"physics_profile": profile}}, "layer_states": {"fixture_layer": {"probe": profile.duplicate(true)}}}
	var source := {"seed_text": "SYNTHETIC-SAVE-FLOAT", "rng_state": "9223372036854775806", "current_environment": environment,
		"visited_probe": [environment.duplicate(true)], "float_vector": [profile.diamond_phase, profile.tilt_angle, PI, TAU, 1.0 / 3.0, -1.0 / 7.0, 1.0e-20, 1.0e20],
		"scenario_public_probe": {"counter": 9223372036854775806, "fraction": profile.diamond_phase},
		"active_delivery_run": {"counter": 9223372036854775806}, "world_sequence_registrations": {"counter": 9223372036854775806}}
	var encoded := Codec.encode(source)
	var packed_result := Codec.pack_for_storage(encoded)
	if not _check(bool(packed_result.get("ok", false)), "new storage pack succeeds"):
		_finish(); return
	var packed: Dictionary = packed_result.packed
	_check(Codec.storage_envelope_valid(packed) and Codec.storage_contents_valid(packed), "new envelope and content validate")
	var decoded := Codec.decode(Codec.unpack_from_storage(packed))
	_check(_equal(source, decoded), "new scalar/vector/registry/layer values round trip exactly")
	var restored_profile: Dictionary = decoded.current_environment.game_states.roulette.physics_profile
	_check(_bits(restored_profile.diamond_phase) == PHASE_BITS and _bits(restored_profile.tilt_angle) == TILT_BITS, "both observed runtime double bit patterns survive")
	for key in ["scenario_public_probe", "active_delivery_run", "world_sequence_registrations"]:
		_check(typeof(decoded[key].counter) == TYPE_INT and decoded[key].counter == 9223372036854775806, "existing exact int64 marker rule " + key)
	_check(typeof(decoded.rng_state) == TYPE_STRING and decoded.rng_state == source.rng_state, "RNG decimal text unchanged")
	# Public-data golden checks only. These do not replace genuine legacy receipt
	# qualification, and never serialize a real authority envelope to evidence.
	_check(Ritual.canonical_json(source.scenario_public_probe) == Ritual.canonical_json(decoded.scenario_public_probe), "ritual canonical bytes unchanged by storage round trip")
	_check(CrewTurn.canonical_json(source.scenario_public_probe) == CrewTurn.canonical_json(decoded.scenario_public_probe), "Crew public-context canonical bytes unchanged")
	var changed: Dictionary = decoded.scenario_public_probe.duplicate(true)
	changed.counter -= 1
	_check(Ritual.canonical_fingerprint(changed) != Ritual.canonical_fingerprint(source.scenario_public_probe), "integer edits remain detectable by canonical fingerprint")
	var legacy_source := {"seed_text": "SYNTHETIC-OLD-FLOAT-TEXT", "rng_state": source.rng_state, "current_environment": environment}
	var legacy_text := JSON.stringify(legacy_source)
	var legacy_packed := _old_pack(legacy_text.to_utf8_buffer())
	var old_loaded := Codec.decode(Codec.unpack_from_storage(legacy_packed))
	var old_profile: Dictionary = old_loaded.current_environment.game_states.roulette.physics_profile
	_check(_bits(old_profile.diamond_phase) == OLD_PHASE_BITS and _bits(old_profile.tilt_angle) == OLD_TILT_BITS, "old rounded stored values remain authoritative, without inferred precision")
	_check(Codec._validated_storage_source(legacy_packed).get_string_from_utf8() == legacy_text, "legacy read preserves original storage text")
	_check(_equal(old_loaded, Codec.decode(Codec.unpack_from_storage(Codec.pack_for_storage(Codec.encode(old_loaded)).packed))), "new writer retains the already-loaded legacy values")
	var raw_legacy: Dictionary = JSON.parse_string(legacy_text)
	_check(_equal(Codec.decode(Codec.unpack_from_storage(raw_legacy)), old_loaded), "unpacked/no-codec legacy dispatch retained")
	var old_ledger_text := '{"seed_text":"synthetic-legacy-integer","rng_state":"9223372036854775806","current_environment":{"_blackjack_action_authority":{"counter":9223372036854775806,"fraction":3.0}}}'
	var old_ledger := Codec.decode(Codec.unpack_from_storage(_old_pack(old_ledger_text.to_utf8_buffer())))
	_check(typeof(old_ledger.current_environment._blackjack_action_authority.counter) == TYPE_INT and old_ledger.current_environment._blackjack_action_authority.counter == 9223372036854775806 and typeof(old_ledger.current_environment._blackjack_action_authority.fraction) == TYPE_FLOAT, "legacy token repair still preserves integer and float literal distinction")
	var damaged := packed.duplicate(true)
	damaged[Codec.STORAGE_HASH_KEY] = "0".repeat(64)
	_check(not Codec.storage_contents_valid(damaged) and Codec.unpack_from_storage(damaged).is_empty(), "content hash damage rejected")
	damaged = packed.duplicate(true)
	damaged[Codec.STORAGE_DATA_KEY] = "~" + str(damaged[Codec.STORAGE_DATA_KEY]).substr(1)
	_check(not Codec.storage_contents_valid(damaged) and Codec.unpack_from_storage(damaged).is_empty(), "encoded byte damage rejected")
	_check(not Saves._payload_dictionary_loadable({"schema": Saves.SAVE_SCHEMA, "run_state": Codec.pack_for_storage({"current_environment": {}}).packed}), "missing required roots remain rejected")
	_physics_parity(profile, restored_profile)
	_finish()

func _physics_parity(original: Dictionary, restored: Dictionary) -> void:
	# Isolated deterministic MODEL comparisons, no wager/funding/settlement.
	# This proves only synthetic solver parity, not an observed paid outcome change.
	var game := Roulette.new()
	var profile_rng := RngStream.new()
	profile_rng.configure(20261101)
	var baseline := game._standard_physics_profile(profile_rng)
	for key in original:
		baseline[key] = original[key]
	baseline["tilt_degrees"] = 0.4
	baseline["level_bias_strength"] = 0.01
	var cold_profile := baseline.duplicate(true)
	for key in restored:
		cold_profile[key] = restored[key]
	var table := {"spin_count": 0, "wheel_sequence": Roulette.AMERICAN_SEQUENCE.duplicate()}
	for seed_value in [41, 20261101]:
		var memory_rng := RngStream.new()
		var loaded_rng := RngStream.new()
		memory_rng.configure(seed_value)
		loaded_rng.configure(seed_value)
		var table_before := var_to_bytes(table)
		var memory := game._simulate_spin(table, baseline, memory_rng)
		var loaded := game._simulate_spin(table, cold_profile, loaded_rng)
		_check(_equal(memory, loaded) and memory_rng.snapshot() == loaded_rng.snapshot(), "synthetic physics/trajectory/RNG parity for seed %d" % seed_value)
		_check(var_to_bytes(table) == table_before, "model comparison never settles or changes a table")

func _old_pack(bytes: PackedByteArray) -> Dictionary:
	# Old-format public synthetic fixture, not an actual historical writer run.
	var compressed := bytes.compress(FileAccess.COMPRESSION_ZSTD)
	return {Codec.STORAGE_MARKER_KEY: Codec.STORAGE_FORMAT, Codec.STORAGE_DATA_KEY: Codec._z85_encode(compressed), Codec.STORAGE_HASH_KEY: Codec._sha256(bytes), Codec.STORAGE_SIZE_KEY: bytes.size(), Codec.STORAGE_COMPRESSED_SIZE_KEY: compressed.size()}

func _bits(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.hex_encode()

func _equal(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_INT and typeof(b) == TYPE_INT:
		return a == b
	if typeof(a) == TYPE_FLOAT and typeof(b) == TYPE_FLOAT:
		return _bits(a) == _bits(b)
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		# Only JSON-safe exact INTEGER type coercion is allowed, never fractional
		# rounding or a numeric tolerance. Signed/int64 fields have separate checks.
		return absf(float(a)) <= 9007199254740991.0 and float(a) == floor(float(a)) and float(a) == float(b)
	if typeof(a) != typeof(b): return false
	if typeof(a) == TYPE_DICTIONARY:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _equal(a[key], b[key]): return false
		return true
	if typeof(a) == TYPE_ARRAY:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not _equal(a[i], b[i]): return false
		return true
	return a == b

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

func _finish() -> void:
	print("SAVE_FLOAT_PRECISION_CODEC " + JSON.stringify({"checks": checks, "failures": failures, "scope": "public synthetic codec/format/model parity only; no profile/key/paid receipt"}))
	quit(0 if failures.is_empty() else 1)
