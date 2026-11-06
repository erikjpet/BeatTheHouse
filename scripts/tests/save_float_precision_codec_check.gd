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
	_check_codec022_comparison_matrix()
	_check_codec023_compiled_numeric_identity()
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


# Registered finite synthetic DTO controls; all oracles consume public codec output.
func _codec022_room(phase: float) -> Dictionary:
	return {"id": "codec022_matrix_room", "archetype_id": "delta_queen", "game_states": {"roulette": {"physics_profile": {"diamond_phase": phase, "tilt_angle": 0.4}}}, "layer_states": {"fixture_layer": {"probe": {"label": "public synthetic storage comparison", "values": [0.1, 0.2, 0.3, 0.4]}}}}


func _codec022_value_at(value: Variant, path: Array) -> Variant:
	for step in path:
		if typeof(value) == TYPE_DICTIONARY:
			value = value.get(step)
		elif typeof(value) in [TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY] and typeof(step) == TYPE_INT and step >= 0 and step < value.size():
			value = value[step]
		else:
			return null
	return value


func _codec022_roundtrip(source: Dictionary) -> Dictionary:
	var before: PackedByteArray = var_to_bytes(source)
	var current_before: Variant = source.get("current_environment")
	var current_readonly_before: bool = typeof(current_before) == TYPE_DICTIONARY and current_before.is_read_only()
	var probe_before: Variant = _codec022_value_at(source, ["current_environment", "layer_states", "fixture_layer", "probe"])
	var probe_typed_before: bool = typeof(probe_before) == TYPE_ARRAY and probe_before.is_typed()
	var probe_readonly_before: bool = typeof(probe_before) == TYPE_ARRAY and probe_before.is_read_only()
	var engine_static_before: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var engine_static_max_before: int = int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX))
	var started_usec: int = Time.get_ticks_usec()
	var encoded: Dictionary = Codec.encode(source)
	var packed: Dictionary = Codec.pack_for_storage(encoded)
	var envelope: Dictionary = packed.get("packed", {})
	var unpacked: Dictionary = Codec.unpack_from_storage(envelope)
	var decoded: Dictionary = Codec.decode(unpacked)
	var public_pipeline_usec: int = Time.get_ticks_usec() - started_usec
	var engine_static_after: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var engine_static_max_after: int = int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX))
	var envelope_valid: bool = Codec.storage_envelope_valid(envelope)
	var contents_valid: bool = Codec.storage_contents_valid(envelope)
	var admitted: bool = bool(packed.get("ok", false)) and envelope_valid and contents_valid
	var current_after: Variant = source.get("current_environment")
	var current_readonly_after: bool = typeof(current_after) == TYPE_DICTIONARY and current_after.is_read_only()
	var probe_after: Variant = _codec022_value_at(source, ["current_environment", "layer_states", "fixture_layer", "probe"])
	var probe_typed_after: bool = typeof(probe_after) == TYPE_ARRAY and probe_after.is_typed()
	var probe_readonly_after: bool = typeof(probe_after) == TYPE_ARRAY and probe_after.is_read_only()
	return {"encoded": encoded, "decoded": decoded, "envelope": envelope, "admitted": admitted, "pack_ok": packed.get("ok", false), "envelope_valid": envelope_valid, "contents_valid": contents_valid, "input_unchanged": before == var_to_bytes(source), "input_flags_unchanged": current_readonly_before == current_readonly_after and probe_typed_before == probe_typed_after and probe_readonly_before == probe_readonly_after, "current_readonly_before": current_readonly_before, "current_readonly_after": current_readonly_after, "probe_typed_before": probe_typed_before, "probe_typed_after": probe_typed_after, "probe_readonly_before": probe_readonly_before, "probe_readonly_after": probe_readonly_after, "public_pipeline_usec": public_pipeline_usec, "engine_tracked_allocation_bytes": {"static_before": engine_static_before, "static_after": engine_static_after, "static_max_before": engine_static_max_before, "static_max_after": engine_static_max_after}, "source_variant_sha256": before.hex_encode().sha256_text(), "decoded_variant_sha256": var_to_bytes(decoded).hex_encode().sha256_text(), "storage_source_sha256": envelope.get(Codec.STORAGE_HASH_KEY, ""), "uncompressed_bytes": envelope.get(Codec.STORAGE_SIZE_KEY, 0), "compressed_bytes": envelope.get(Codec.STORAGE_COMPRESSED_SIZE_KEY, 0)}


func _check_codec022_comparison_matrix() -> void:
	var positive_zero: float = 0.0
	var negative_zero: float = "0000000000000080".hex_decode().decode_double(0)
	var adjacent_one: float = "010000000000f03f".hex_decode().decode_double(0)
	var rows: Array = [
		{"id": "different_identity_control", "left": positive_zero, "right": negative_zero, "different_id": true},
		{"id": "forward_zero", "left": positive_zero, "right": negative_zero},
		{"id": "reverse_zero", "left": negative_zero, "right": positive_zero},
		{"id": "visited_registered_first", "left": positive_zero, "right": negative_zero, "visited_first": true},
		{"id": "identical_positive_zero_reuse", "left": positive_zero, "right": positive_zero, "reuse": true},
		{"id": "identical_negative_zero_reuse", "left": negative_zero, "right": negative_zero, "reuse": true},
		{"id": "identical_nonzero_reuse", "left": 1.25, "right": 1.25, "reuse": true},
		{"id": "unequal_nonzero", "left": 1.25, "right": 2.5},
		{"id": "adjacent_nonzero", "left": 1.0, "right": adjacent_one},
		{"id": "dictionary_insertion_order", "left": 1.25, "right": 1.25, "reorder": true},
		{"id": "mixed_delta_forward", "left": positive_zero, "right": negative_zero, "delta": true},
		{"id": "mixed_delta_reverse", "left": negative_zero, "right": positive_zero, "delta": true},
		{"id": "nested_dictionary_array", "left": positive_zero, "right": negative_zero, "nested": true},
		{"id": "typed_readonly_array", "left": positive_zero, "right": negative_zero, "typed_readonly": true},
		{"id": "packed_float32", "left": positive_zero, "right": negative_zero, "packed": 32},
		{"id": "packed_float64", "left": positive_zero, "right": negative_zero, "packed": 64},
		{"id": "last_native_float_depth", "left": positive_zero, "right": negative_zero, "boundary": true},
		{"id": "last_native_packed64_depth", "left": positive_zero, "right": negative_zero, "boundary": true, "packed": 64}
	]
	var observations: Array = []
	for row_value in rows:
		var row: Dictionary = row_value
		var row_id: String = str(row.id)
		var left: Dictionary = _codec022_room(float(row.left))
		var right: Dictionary = _codec022_room(float(row.right))
		# Isolate non-scalar probes: no shallower differing zero may mask a missed walk.
		if bool(row.get("nested", false)) or bool(row.get("typed_readonly", false)) or int(row.get("packed", 0)) > 0 or bool(row.get("boundary", false)):
			left["game_states"]["roulette"]["physics_profile"]["diamond_phase"] = 1.25
			right["game_states"]["roulette"]["physics_profile"]["diamond_phase"] = 1.25
		var leaf_path: Array = ["game_states", "roulette", "physics_profile", "diamond_phase"]
		if bool(row.get("different_id", false)):
			right["id"] = "codec022_other_room"
		if bool(row.get("delta", false)):
			right["game_states"]["roulette"]["physics_profile"]["tilt_angle"] = 0.5
		if bool(row.get("nested", false)):
			left["layer_states"]["fixture_layer"]["probe"] = {"deep": {"values": [float(row.left), 1.25]}}
			right["layer_states"]["fixture_layer"]["probe"] = {"deep": {"values": [float(row.right), 1.25]}}
			leaf_path = ["layer_states", "fixture_layer", "probe", "deep", "values", 0]
		if bool(row.get("typed_readonly", false)):
			var left_typed: Array[float] = [float(row.left), 1.25]
			var right_typed: Array[float] = [float(row.right), 1.25]
			left_typed.make_read_only()
			right_typed.make_read_only()
			left["layer_states"]["fixture_layer"]["probe"] = left_typed
			right["layer_states"]["fixture_layer"]["probe"] = right_typed
			left.make_read_only()
			right.make_read_only()
			leaf_path = ["layer_states", "fixture_layer", "probe", 0]
		if int(row.get("packed", 0)) > 0 and not bool(row.get("boundary", false)):
			left["layer_states"]["fixture_layer"]["probe"] = PackedFloat32Array([float(row.left), 1.25]) if int(row.packed) == 32 else PackedFloat64Array([float(row.left), 1.25])
			right["layer_states"]["fixture_layer"]["probe"] = PackedFloat32Array([float(row.right), 1.25]) if int(row.packed) == 32 else PackedFloat64Array([float(row.right), 1.25])
			leaf_path = ["layer_states", "fixture_layer", "probe", 0]
		if bool(row.get("boundary", false)):
			var left_deep: Variant = float(row.left) if int(row.get("packed", 0)) == 0 else PackedFloat64Array([float(row.left), 1.25])
			var right_deep: Variant = float(row.right) if int(row.get("packed", 0)) == 0 else PackedFloat64Array([float(row.right), 1.25])
			# Env/game_states/roulette/profile counts0/2/4/6.47nested dictionaries
			# put their last parent at100; scalar/Packed leaves are still compared.
			for _depth in range(47):
				left_deep = {"next": left_deep}
				right_deep = {"next": right_deep}
			left["game_states"]["roulette"]["physics_profile"]["codec022_deep"] = left_deep
			right["game_states"]["roulette"]["physics_profile"]["codec022_deep"] = right_deep
			leaf_path = ["game_states", "roulette", "physics_profile", "codec022_deep"]
			for _depth in range(47):
				leaf_path.append("next")
			if int(row.get("packed", 0)) > 0:
				leaf_path.append(0)
		if bool(row.get("reorder", false)):
			var reordered: Dictionary = {}
			for key in ["layer_states", "game_states", "archetype_id", "id"]:
				reordered[key] = right[key]
			right = reordered
		var source: Dictionary = {"seed_text": "CODEC022-MATRIX", "rng_state": "12"}
		if bool(row.get("visited_first", false)):
			source["visited_probe"] = [right]
			source["current_environment"] = left
		else:
			source["current_environment"] = left
			source["visited_probe"] = [right]
		var result: Dictionary = _codec022_roundtrip(source)
		_check(bool(result.admitted), "Codec022 matrix " + row_id + " public packed source admitted")
		_check(bool(result.input_unchanged) and bool(result.input_flags_unchanged), "Codec022 matrix " + row_id + " source bytes/flags unchanged")
		var current_path: Array = ["current_environment"] + leaf_path
		var visited_path: Array = ["visited_probe", 0] + leaf_path
		var current_leaf: Variant = _codec022_value_at(result.decoded, current_path)
		var visited_leaf: Variant = _codec022_value_at(result.decoded, visited_path)
		var current_bits: String = _bits(float(current_leaf)) if typeof(current_leaf) == TYPE_FLOAT else ""
		var visited_bits: String = _bits(float(visited_leaf)) if typeof(visited_leaf) == TYPE_FLOAT else ""
		_check(typeof(current_leaf) == TYPE_FLOAT and current_bits == _bits(float(row.left)), "Codec022 matrix " + row_id + " current float bits retained")
		_check(typeof(visited_leaf) == TYPE_FLOAT and visited_bits == _bits(float(row.right)), "Codec022 matrix " + row_id + " visited float bits retained")
		var registry: Dictionary = result.encoded.get(Codec.REGISTRY_KEY, {})
		if bool(row.get("reuse", false)):
			_check(registry.size() == 1, "Codec022 matrix " + row_id + " identical rooms still reuse one entry")
		var delta_ref: Variant = _codec022_value_at(result.encoded, ["visited_probe", 0, Codec.ENVIRONMENT_REF_KEY])
		var entry: Variant = registry.get(delta_ref)
		var delta_selected: bool = typeof(entry) == TYPE_DICTIONARY and entry.has(Codec.ENVIRONMENT_BASE_REF_KEY) and entry.has(Codec.SCENARIO_DEFINITION_PATCH_KEY)
		if bool(row.get("delta", false)):
			_check(delta_selected, "Codec022 matrix " + row_id + " exercises actual smaller base delta")
		observations.append({"case": row_id, "admitted": result.admitted, "input_unchanged": result.input_unchanged, "input_flags_unchanged": result.input_flags_unchanged, "expected_bits": [_bits(float(row.left)), _bits(float(row.right))], "restored_bits": [current_bits, visited_bits], "restored_types": [type_string(typeof(current_leaf)), type_string(typeof(visited_leaf))], "registry_size": registry.size(), "delta_selected": delta_selected, "leaf_path": leaf_path, "source_key_order": source.keys(), "current_readonly_before": result.current_readonly_before, "current_readonly_after": result.current_readonly_after, "probe_typed_before": result.probe_typed_before, "probe_typed_after": result.probe_typed_after, "probe_readonly_before": result.probe_readonly_before, "probe_readonly_after": result.probe_readonly_after, "decoded_variant_sha256": result.decoded_variant_sha256, "storage_source_sha256": result.storage_source_sha256, "uncompressed_bytes": result.uncompressed_bytes, "compressed_bytes": result.compressed_bytes})
	var catalog: Script = load("res://scripts/core/scenario_sequence_catalog.gd")
	var catalog_definition: Dictionary = catalog.legacy_definition("pawn_shop_estate_lot_day")
	var catalog_path: Array = ["mutations", "economic_profile_overrides", "shop_price_multiplier"]
	var catalog_leaf: Variant = _codec022_value_at(catalog_definition, catalog_path)
	var catalog_admitted: bool = not catalog_definition.is_empty() and typeof(catalog_leaf) == TYPE_FLOAT and catalog_leaf == 1.0
	_check(catalog_admitted, "Codec022 matrix actual catalog Float1.0 source admitted")
	var seeded_observations: Array = []
	if catalog_admitted:
		for kind in ["catalog_float_unchanged", "supplied_int1", "unequal_float", "unknown_catalog_int"]:
			var definition: Dictionary = catalog_definition.duplicate(true)
			if kind in ["supplied_int1", "unknown_catalog_int"]:
				definition["mutations"]["economic_profile_overrides"]["shop_price_multiplier"] = 1
			elif kind == "unequal_float":
				definition["mutations"]["economic_profile_overrides"]["shop_price_multiplier"] = 1.25
			if kind == "unknown_catalog_int":
				definition["id"] = "codec022_unknown_catalog_synthetic"
			var seeded_source: Dictionary = {"seed_text": "CODEC022-SEEDED", "rng_state": "12", "current_environment": {}, "seeded_scenario_definitions_by_node": {"codec022_node": definition}}
			var seeded_result: Dictionary = _codec022_roundtrip(seeded_source)
			var seeded_leaf: Variant = _codec022_value_at(seeded_result.decoded, ["seeded_scenario_definitions_by_node", "codec022_node"] + catalog_path)
			var expected_type: int = TYPE_INT if kind in ["supplied_int1", "unknown_catalog_int"] else TYPE_FLOAT
			var expected_value: float = 1.25 if kind == "unequal_float" else 1.0
			_check(bool(seeded_result.admitted), "Codec022 seeded " + kind + " public packed source admitted")
			_check(bool(seeded_result.input_unchanged) and bool(seeded_result.input_flags_unchanged), "Codec022 seeded " + kind + " source bytes/flags unchanged")
			_check(typeof(seeded_leaf) == expected_type and seeded_leaf == expected_value, "Codec022 seeded " + kind + " numeric kind/value retained")
			var seeded_entry: Variant = _codec022_value_at(seeded_result.encoded, ["seeded_scenario_definitions_by_node", "codec022_node"])
			if kind == "catalog_float_unchanged":
				_check(typeof(seeded_entry) == TYPE_DICTIONARY and seeded_entry.size() == 1 and seeded_entry.has(Codec.SCENARIO_DEFINITION_REF_KEY), "Codec022 seeded unchanged catalog still uses compact reference")
			seeded_observations.append({"case": kind, "admitted": seeded_result.admitted, "input_unchanged": seeded_result.input_unchanged, "expected_type": type_string(expected_type), "restored_type": type_string(typeof(seeded_leaf)), "restored_value": seeded_leaf, "encoded_seeded_entry": seeded_entry, "storage_source_sha256": seeded_result.storage_source_sha256})
	var cost_observations: Array = []
	for population in ["identical_positive_rooms", "identical_negative_rooms", "changed_rooms"]:
		var phase: float = negative_zero if population == "identical_negative_rooms" else positive_zero
		var first_room: Dictionary = _codec022_room(phase)
		var values: Array = []
		for index in range(128):
			values.append(0.0 if index % 4 == 0 else float(index) / 17.0)
		first_room["layer_states"]["fixture_layer"]["probe"] = {"values": values, "label": "bounded synthetic ordinary comparison workload"}
		var repeated_rooms: Array = []
		for index in range(11):
			var room: Dictionary = first_room.duplicate(true)
			if population == "changed_rooms":
				room["game_states"]["roulette"]["physics_profile"]["tilt_angle"] = 0.5 + float(index) / 100.0
			repeated_rooms.append(room)
		var cost_source: Dictionary = {"seed_text": "CODEC022-COST", "rng_state": "12", "current_environment": first_room, "visited_probe": repeated_rooms}
		var samples_usec: Array = []
		var source_hashes: Array = []
		var decoded_hashes: Array = []
		var sizes: Array = []
		var allocation_observations: Array = []
		for _sample in range(5):
			var cost_result: Dictionary = _codec022_roundtrip(cost_source)
			_check(bool(cost_result.admitted) and bool(cost_result.input_unchanged) and bool(cost_result.input_flags_unchanged), "Codec022 cost " + population + " admitted/unchanged")
			var cost_leaf: Variant = _codec022_value_at(cost_result.decoded, ["current_environment", "game_states", "roulette", "physics_profile", "diamond_phase"])
			_check(typeof(cost_leaf) == TYPE_FLOAT and _bits(float(cost_leaf)) == _bits(phase), "Codec022 cost " + population + " probe bits retained")
			samples_usec.append(cost_result.public_pipeline_usec)
			source_hashes.append(cost_result.storage_source_sha256)
			decoded_hashes.append(cost_result.decoded_variant_sha256)
			sizes.append([cost_result.uncompressed_bytes, cost_result.compressed_bytes])
			allocation_observations.append(cost_result.engine_tracked_allocation_bytes)
		cost_observations.append({"population": population, "room_count": 12, "shared_array_leaves": 128, "iterations": 5, "whole_public_pipeline_usec": samples_usec, "storage_source_sha256": source_hashes, "decoded_variant_sha256": decoded_hashes, "source_compressed_byte_counts": sizes, "engine_tracked_allocation_bytes": allocation_observations, "cache_scope": "same process after all fixed functional cases; no cold-cache or internal comparator timing claim"})
	print("CODEC022_COMPARISON_OBSERVATIONS " + JSON.stringify({"matrix": observations, "catalog_admitted": catalog_admitted, "seeded": seeded_observations, "cost": cost_observations, "admission_authority": "Canonical public codec pack/envelope/content-root proof only", "normalization_authority": "Public encode/unpack/decode; packed arrays restore as ordinary Arrays; no RunState/schema/mounted-authority acceptance", "clock_scope": "Whole actual canonical encode/pack/unpack/decode calls only, excludes source snapshot/hash/admission/oracle work; root guarded job wall/CPU separate", "memory_scope": "Performance.MEMORY_STATIC and MEMORY_STATIC_MAX observations before/after the public pipeline, outside its clock; engine-tracked allocation counters, debug-dependent and possibly zero; not OS RSS/peak or comparator-only allocation", "unsupported_domain": "No opaque Object/callback, nonfinite or cyclic experiment; existing native error-boundary behavior is source-reviewed only", "player_or_historical_alias_claim": false}))



# Independent ordinary-DTO production compilation controls for registered C3.
# A single map environment per pipeline prevents Codec registry/delta collisions
# from concealing an upstream stale-compilation decision. No full helper is run.
func _check_codec023_compiled_numeric_identity() -> void:
	var projection_script: Script = load("res://scripts/core/persistent_environment_projection.gd")
	var positive_zero: float = 0.0
	var negative_zero: float = "0000000000000080".hex_decode().decode_double(0)
	var rows: Array = [
		{"id": "scalar_zero_forward", "before": positive_zero, "after": negative_zero, "changed": true},
		{"id": "scalar_zero_reverse", "before": negative_zero, "after": positive_zero, "changed": true},
		{"id": "scalar_int_to_float", "before": 1, "after": 1.0, "changed": true},
		{"id": "scalar_float_to_int", "before": 1.0, "after": 1, "changed": true},
		{"id": "scalar_unchanged_reuse", "before": 1.25, "after": 1.25, "changed": false},
		{"id": "packed64_zero_forward", "before": positive_zero, "after": negative_zero, "changed": true, "packed": true},
		{"id": "packed64_zero_reverse", "before": negative_zero, "after": positive_zero, "changed": true, "packed": true},
		{"id": "packed64_unchanged_reuse", "before": negative_zero, "after": negative_zero, "changed": false, "packed": true}
	]
	var observations: Array = []
	for row_value in rows:
		var row: Dictionary = row_value
		var row_id: String = str(row.id)
		var packed_leaf: bool = bool(row.get("packed", false))
		var owner := RunState.new()
		owner.rng_seed = 20261105
		owner.rng_state = 20261105
		var owner_witness: Array = [owner.rng_seed, owner.rng_state, owner.bankroll, owner.game_clock_minutes]
		var first_compilation: RefCounted = null
		for phase in ["fresh", "replacement"]:
			var expected_numeric: Variant = row.before if phase == "fresh" else row.after
			var room: Dictionary = _codec022_room(1.25)
			room["id"] = "codec023_compiled_room"
			room["scenario_codec023_numeric"] = PackedFloat64Array([float(expected_numeric)]) if packed_leaf else expected_numeric
			var input_map: Dictionary = {"nodes": [{"id": "codec023_compiled_node", "environment": room}]}
			owner.world_map = input_map
			var before: PackedByteArray = var_to_bytes(input_map)
			var reference_map: Dictionary = RunState._world_map_for_save_snapshot(input_map)
			var captured_map: Dictionary = owner._owned_world_map_for_save_snapshot(input_map, true)
			var compiled: Variant = _codec022_value_at(captured_map, ["nodes", 0, "environment"])
			var compiled_ok: bool = typeof(compiled) == TYPE_OBJECT and compiled != null and compiled.get_script() == projection_script
			if not _check(compiled_ok, "Codec023 compiled " + row_id + " " + phase + " actual production projection admitted"):
				observations.append({"case": row_id, "phase": phase, "compiled_admitted": false})
				continue
			var same_compilation: bool = phase == "replacement" and first_compilation != null and is_same(first_compilation, compiled)
			if phase == "fresh":
				first_compilation = compiled
			else:
				_check(first_compilation != null, "Codec023 compiled " + row_id + " replacement has admitted fresh source")
				_check(not same_compilation if bool(row.changed) else same_compilation, "Codec023 compiled " + row_id + " replacement invalidation or unchanged reuse")
			var default_map: Dictionary = owner._owned_world_map_for_save_snapshot(input_map)
			var default_leaf_path: Array = ["nodes", 0, "environment", "scenario_codec023_numeric"]
			if packed_leaf:
				default_leaf_path.append(0)
			var reference_leaf: Variant = _codec022_value_at(reference_map, default_leaf_path)
			var default_leaf: Variant = _codec022_value_at(default_map, default_leaf_path)
			var reference_exact: bool = typeof(reference_leaf) == typeof(expected_numeric) and (_bits(float(reference_leaf)) == _bits(float(expected_numeric)) if typeof(expected_numeric) == TYPE_FLOAT else reference_leaf == expected_numeric)
			var default_exact: bool = typeof(default_leaf) == typeof(expected_numeric) and (_bits(float(default_leaf)) == _bits(float(expected_numeric)) if typeof(expected_numeric) == TYPE_FLOAT else default_leaf == expected_numeric)
			_check(reference_exact, "Codec023 compiled " + row_id + " " + phase + " ordinary production projection retains numeric identity")
			_check(default_exact, "Codec023 compiled " + row_id + " " + phase + " default snapshot retains numeric identity")
			var source: Dictionary = {"seed_text": "CODEC023-COMPILED-DTOS", "rng_state": str(owner.rng_state), "current_environment": {}, "world_map": captured_map}
			var reference_source: Dictionary = {"seed_text": "CODEC023-COMPILED-DTOS", "rng_state": str(owner.rng_state), "current_environment": {}, "world_map": reference_map}
			var expected_encoded: Dictionary = Codec.encode(reference_source)
			var engine_static_before: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
			var engine_static_max_before: int = int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX))
			var encoded: Dictionary = Codec.encode(source)
			var packed: Dictionary = Codec.pack_for_storage(encoded)
			var envelope: Dictionary = packed.get("packed", {})
			var unpacked: Dictionary = Codec.unpack_from_storage(envelope)
			var decoded: Dictionary = Codec.decode(unpacked)
			var engine_static_after: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
			var engine_static_max_after: int = int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX))
			var admitted: bool = bool(packed.get("ok", false)) and Codec.storage_envelope_valid(envelope) and Codec.storage_contents_valid(envelope)
			_check(admitted, "Codec023 compiled " + row_id + " " + phase + " public packed source admitted")
			_check(JSON.stringify(encoded) == JSON.stringify(expected_encoded), "Codec023 compiled " + row_id + " " + phase + " full ordinary encoded JSON parity")
			var decoded_leaf: Variant = _codec022_value_at(decoded, ["world_map"] + default_leaf_path)
			var decoded_exact: bool = typeof(decoded_leaf) == typeof(expected_numeric) and (_bits(float(decoded_leaf)) == _bits(float(expected_numeric)) if typeof(expected_numeric) == TYPE_FLOAT else decoded_leaf == expected_numeric)
			_check(decoded_exact, "Codec023 compiled " + row_id + " " + phase + " public decoded numeric identity retained")
			var registry: Dictionary = encoded.get(Codec.REGISTRY_KEY, {})
			_check(registry.size() == 1, "Codec023 compiled " + row_id + " " + phase + " single environment isolates upstream cache")
			var encoded_fast_path: bool = not compiled._encoded_projection.is_empty()
			_check(encoded_fast_path == (not packed_leaf), "Codec023 compiled " + row_id + " " + phase + " actual encoded fast or packed fallback path")
			var retained_components: Array = [var_to_bytes(compiled._source).size(), var_to_bytes(compiled._projection).size(), var_to_bytes(compiled._encoded_projection).size() if encoded_fast_path else 0]
			var retained_total: int = int(retained_components[0]) + int(retained_components[1]) + int(retained_components[2])
			_check(compiled.retained_bytes == retained_total and owner._inactive_storage_projection_bytes == retained_total and retained_total <= RunState.INACTIVE_STORAGE_PROJECTION_BUDGET, "Codec023 compiled " + row_id + " " + phase + " retained production byte budget matches")
			_check(before == var_to_bytes(input_map) and before == var_to_bytes(owner.world_map), "Codec023 compiled " + row_id + " " + phase + " ordinary input bytes unchanged")
			_check([owner.rng_seed, owner.rng_state, owner.bankroll, owner.game_clock_minutes] == owner_witness, "Codec023 compiled " + row_id + " " + phase + " owner RNG cash and clock unchanged")
			observations.append({"case": row_id, "phase": phase, "compiled_admitted": compiled_ok, "compiled_script_resource": str(compiled.get_script().resource_path), "numeric_change": row.changed, "same_compilation_as_fresh": same_compilation, "encoded_fast_path": encoded_fast_path, "single_environment_registry_size": registry.size(), "expected_type": type_string(typeof(expected_numeric)), "reference_type": type_string(typeof(reference_leaf)), "default_type": type_string(typeof(default_leaf)), "decoded_type": type_string(typeof(decoded_leaf)), "expected_float_bits": _bits(float(expected_numeric)) if typeof(expected_numeric) == TYPE_FLOAT else "", "decoded_float_bits": _bits(float(decoded_leaf)) if typeof(decoded_leaf) == TYPE_FLOAT else "", "decoded_numeric_exact": decoded_exact, "default_numeric_exact": default_exact, "ordinary_source_sha256": before.hex_encode().sha256_text(), "ordinary_input_unchanged": before == var_to_bytes(input_map), "owner_rng_cash_clock": owner_witness, "retained_components_bytes": retained_components, "retained_bytes": compiled.retained_bytes, "aggregate_retained_bytes": owner._inactive_storage_projection_bytes, "retained_budget_bytes": RunState.INACTIVE_STORAGE_PROJECTION_BUDGET, "engine_tracked_allocation_bytes": {"static_before": engine_static_before, "static_after": engine_static_after, "static_max_before": engine_static_max_before, "static_max_after": engine_static_max_after}, "storage_source_sha256": envelope.get(Codec.STORAGE_HASH_KEY, ""), "uncompressed_bytes": envelope.get(Codec.STORAGE_SIZE_KEY, 0), "compressed_bytes": envelope.get(Codec.STORAGE_COMPRESSED_SIZE_KEY, 0)})
	print("CODEC023_COMPILED_NUMERIC_OBSERVATIONS " + JSON.stringify({"rows": rows.size(), "stages_per_row": 2, "observations": observations, "task": "BTH061-AUDIT-PROJECTION-NUMERIC-IDENTITY-023", "scope": "Ordinary finite synthetic DTOs through actual production RunState default/compiled storage and canonical public Codec; no full RunState save/restore or UI cold Continue", "isolation": "One environment in each pipeline, current_environment empty; no downstream reference/delta collision can mask upstream reuse", "source_policy": "No captured save, opaque input, injected projector/callback, alias/cyclic experiment or private capsule access; only the known production compiled object is passed to canonical Codec", "memory_scope": "Engine-tracked debug-dependent allocation monitor observations, not OS RSS/peak or comparator-only memory", "original_projection_helper_executed": false}))
