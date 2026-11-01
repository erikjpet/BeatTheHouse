extends SceneTree

# Approved same-wire correction regression. Separate from frozen e747 sources.
# All fixtures are public synthetic values, assembled in memory. No files,
# profiles, keys, SaveService, RunState, browser, RNG or gameplay are accessed.
# Desired-rounding assertions intentionally expose the current reader defect.
const Codec := preload("res://scripts/core/run_save_codec.gd")
const Ritual := preload("res://scripts/core/game_ritual_runtime.gd")
const CrewTurn := preload("res://scripts/core/crew_turn_model.gd")
const Numeric := preload("res://scripts/core/storage_numeric_json.gd")
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_literal_rounding()
	_exact_midpoints()
	_grammar_and_strings()
	_integer_and_integrity_contracts()
	_generated_fixtures()
	_independent_vectors()
	print("STORAGE_NUMERIC_JSON_CHECK " + JSON.stringify({"checks": checks, "failures": failures, "runtime_scope": "public synthetic codec only"}))
	quit(0 if failures.is_empty() else 1)

func _literal_rounding() -> void:
	# Expected binary64 encodings are explicit little-endian IEEE bits, not
	# numbers parsed by the reader under test or a tolerance-based comparison.
	var vectors: Array = [
		["0", "0000000000000000", "integer zero remains a JSON float"],
		["0.0", "0000000000000000", "positive zero"],
		["-0", "0000000000000080", "negative integer-spelled zero"],
		["-0.0", "0000000000000080", "negative fractional zero"],
		["0.1", "9a9999999999b93f", "ordinary fraction"],
		["1.0", "000000000000f03f", "one"],
		["1.0000000000000002", "010000000000f03f", "successor of one"],
		["0.9999999999999999", "ffffffffffffef3f", "predecessor of one"],
		["2.1834257438008278", "c6f396eaa7770140", "retained phase witness"],
		["3.2574545906541847", "b184385a440f0a40", "retained tilt witness"],
		["9007199254740993", "0000000000004043", "integer token ties to even binary64"],
		["9007199254740994", "0100000000004043", "next representable integer"],
		["4.9406564584124654e-324", "0100000000000000", "least positive subnormal"],
		["-4.9406564584124654e-324", "0100000000000080", "least negative subnormal"],
		["2.225073858507201e-308", "ffffffffffff0f00", "greatest subnormal"],
		["2.2250738585072014e-308", "0000000000001000", "least positive normal"],
		["1.7976931348623157e308", "ffffffffffffef7f", "greatest finite double"],
		["1.7976931348623159e308", "000000000000f07f", "positive overflow"],
		["-1.7976931348623159e308", "000000000000f0ff", "negative overflow"],
		["1e-9999", "0000000000000000", "positive underflow"],
		["-1e-9999", "0000000000000080", "negative underflow"]
	]
	for vector in vectors:
		_expect_number(str(vector[0]), str(vector[1]), str(vector[2]))

func _exact_midpoints() -> void:
	# Decimal witnesses are constructed only with integer/string arithmetic.
	# No decimal-to-float implementation supplies its own expected answer.
	var one_half_ulp := "1.00000000000000011102230246251565404236316680908203125"
	_expect_number(one_half_ulp, "000000000000f03f", "normal halfway chooses even lower significand")
	_expect_number(one_half_ulp.substr(0, one_half_ulp.length() - 1) + "4", "000000000000f03f", "just below normal halfway")
	_expect_number(one_half_ulp.substr(0, one_half_ulp.length() - 1) + "6", "010000000000f03f", "just above normal halfway")
	_expect_number("1.00000000000000033306690738754696212708950042724609375", "020000000000f03f", "normal halfway chooses even upper significand")
	var half_minimum := _dyadic_decimal(1, -1075)
	_expect_number(half_minimum, "0000000000000000", "half minimum subnormal ties to positive zero")
	_expect_number("-" + half_minimum, "0000000000000080", "half minimum negative subnormal ties to negative zero")
	_expect_number(half_minimum + "1", "0100000000000000", "nonzero tail above subnormal halfway is retained")
	_expect_number(_dyadic_decimal(3, -1075), "0200000000000000", "subnormal halfway chooses even upper significand")
	_expect_number(_dyadic_decimal(9007199254740991, -1075), "0000000000001000", "subnormal-normal halfway chooses even normal")
	var overflow_midpoint := _dyadic_decimal(18014398509481983, 970)
	_expect_number(overflow_midpoint, "000000000000f07f", "finite-overflow halfway rounds to infinity")
	_expect_number(_decrement_integer(overflow_midpoint), "ffffffffffffef7f", "one integer below overflow halfway stays finite")

func _grammar_and_strings() -> void:
	# Keep the engine's existing lexical acceptance as a separate requirement.
	# In particular Godot accepts some nonstandard spellings and trailing commas.
	# A new numeric helper must not silently replace that grammar contract.
	for token in ["+1", "1e", "1e+", "1e++2", "1..2", "--1", "NaN", "Infinity", "1 2"]:
		var text := _number_object(token)
		var native := JSON.new()
		var native_ok := native.parse(text) == OK
		var loaded := _load_text(text)
		_check(not native_ok and loaded.is_empty(), "malformed numeric rejection: " + token)
	for token in ["01", "1.", "-.5"]:
		var text := _number_object(token)
		var native := JSON.new()
		var native_ok := native.parse(text) == OK
		var loaded := _load_text(text)
		_check(native_ok == (not loaded.is_empty()), "existing extended numeric grammar: " + token)
		if native_ok and not loaded.is_empty():
			_check(_same(native.data, loaded), "extended spelling retains legacy result: " + token)
	# Correct stored-decimal interpretation is approved, including old parser
	# errors. Existing Infinity/NaN serialization itself is not expanded.
	_expect_number("0e99999", "0000000000000000", "zero with huge exponent is mathematically zero")
	_expect_number("-0e99999", "0000000000000080", "negative zero with huge exponent retains sign")
	_expect_number("1e99999", "000000000000f07f", "existing positive overflow remains infinity")
	_expect_number("-1e99999", "000000000000f0ff", "existing negative overflow remains infinity")
	_check(Numeric.stringify(NAN) == "null" and Numeric.stringify(INF) == "1e99999", "existing nonfinite writer contract is unchanged")
	var strings := '{"seed_text":"synthetic","rng_state":"12","current_environment":{},"text":"2.1834257438008278 -0 1e99999","escaped":"\\u0032.1834257438008278","quote":"\\\"1.2\\\"","marker_like":"~bth-numeric:0~","1.25":"key","nested":["4.9406564584124654e-324",true,null]}'
	_check(_same(_load_text(strings), JSON.parse_string(strings)), "strings, escapes, numeric keys and marker-like text are opaque")
	var duplicate := _load_text('{"seed_text":"synthetic","rng_state":"12","current_environment":{},"number":2.1834257438008278,"number":1.0}')
	_check(_bits(duplicate.get("number")) == "000000000000f03f", "duplicate keys preserve last-value behavior")
	var comma := '{"seed_text":"synthetic","rng_state":"12","current_environment":{},"number":[1.0,],}'
	_check(_same(_load_text(comma), JSON.parse_string(comma)), "existing trailing-comma behavior remains unchanged")

func _integer_and_integrity_contracts() -> void:
	var text := '{"seed_text":"synthetic","rng_state":"9223372036854775806","current_environment":{"_blackjack_action_authority":{"counter":9223372036854775806,"fraction":3.0}},"scenario_numeric_probe":{"counter":{"__bth_exact_int64":"9223372036854775806"}}}'
	var loaded := Codec.decode(_load_text(text))
	var ledger: Dictionary = loaded.get("current_environment", {}).get("_blackjack_action_authority", {})
	_check(typeof(ledger.get("counter")) == TYPE_INT and ledger.get("counter") == 9223372036854775806, "legacy ledger integer token repair remains exact")
	_check(typeof(ledger.get("fraction")) == TYPE_FLOAT and _bits(ledger.get("fraction")) == "0000000000000840", "fractional ledger literal retains float type")
	_check(typeof(loaded.get("scenario_numeric_probe", {}).get("counter")) == TYPE_INT and loaded.scenario_numeric_probe.counter == 9223372036854775806, "existing exact-int64 marker is not a decimal float")
	_check(typeof(loaded.get("rng_state")) == TYPE_STRING and loaded.rng_state == "9223372036854775806", "RNG text is unchanged")
	var packed := _pack_text(_number_object("1.0"))
	var corrupt := packed.duplicate(true)
	corrupt[Codec.STORAGE_HASH_KEY] = "0".repeat(64)
	_check(not Codec.storage_contents_valid(corrupt) and Codec.unpack_from_storage(corrupt).is_empty(), "hash rejection remains authoritative")
	corrupt = packed.duplicate(true)
	corrupt[Codec.STORAGE_MARKER_KEY] = "unrecognized-format"
	_check(not Codec.storage_envelope_valid(corrupt) and Codec.unpack_from_storage(corrupt).is_empty(), "unknown format remains rejected")
	corrupt = packed.duplicate(true)
	corrupt[Codec.STORAGE_SIZE_KEY] = Codec.MAX_STORAGE_BYTES + 1
	_check(not Codec.storage_envelope_valid(corrupt) and Codec.unpack_from_storage(corrupt).is_empty(), "existing decompression limit remains authoritative")

func _generated_fixtures() -> void:
	var phase: float = "c6f396eaa7770140".hex_decode().decode_double(0)
	var tilt: float = "b184385a440f0a40".hex_decode().decode_double(0)
	var environment := {"id": "synthetic", "archetype_id": "delta_queen", "game_states": {"roulette": {"physics_profile": {"diamond_phase": phase, "tilt_angle": tilt}}}, "scenario_layout_authority": {"base::travel:leave": {"label_rect": {"h": "77c41d7147dca13f".hex_decode().decode_double(0)}}}}
	var source := {"seed_text": "SYNTHETIC-DECIMAL-READER", "rng_state": "9223372036854775806", "current_environment": environment, "scenario_numeric_probe": {"counter": 9223372036854775806, "fraction": phase}}
	var encoded := Codec.encode(source)
	# This is the current encoder with OLD writer spelling, not a captured or
	# genuine old-build fixture. The old stored values, not pre-save values,
	# supply the compatibility expectation, including the observed old bits.
	var legacy_text := JSON.stringify(encoded)
	var native_old: Dictionary = Numeric.parse(legacy_text).data
	# Independent exact-bit expectations for the actual old emitted decimals.
	# No old native numeric parser supplies the expected values.
	var expected_old := source.duplicate(true)
	expected_old.current_environment.game_states.roulette.physics_profile.diamond_phase = "cbf396eaa7770140".hex_decode().decode_double(0)
	expected_old.current_environment.game_states.roulette.physics_profile.tilt_angle = "a684385a440f0a40".hex_decode().decode_double(0)
	expected_old.current_environment.scenario_layout_authority["base::travel:leave"].label_rect.h = "7dc41d7147dca13f".hex_decode().decode_double(0)
	expected_old.scenario_numeric_probe.fraction = "cbf396eaa7770140".hex_decode().decode_double(0)
	var loaded_old := Codec.decode(_load_text(legacy_text))
	_check(_same(expected_old, loaded_old), "generated old-writer packed-v1 result matches independently specified stored decimals")
	_check(_same(Codec.decode(Codec.unpack_from_storage(native_old)), expected_old), "already-parsed unpacked codec-2 branch remains unchanged")
	var codec_one := native_old.duplicate(true)
	codec_one[Codec.CODEC_KEY] = 1
	_check(_same(Codec.decode(codec_one), expected_old), "synthetic codec-1 flat registry remains readable")
	var old_profile: Dictionary = loaded_old.current_environment.game_states.roulette.physics_profile
	_check(_bits(old_profile.diamond_phase) == "cbf396eaa7770140" and _bits(old_profile.tilt_angle) == "a684385a440f0a40", "retained old-writer witnesses stay at their stored/loaded values")
	var current := Codec.pack_for_storage(encoded)
	if _check(bool(current.get("ok", false)), "current generated fixture packs"):
		var restored := Codec.decode(Codec.unpack_from_storage(current.packed))
		_check(_same(source, restored), "current generated physics and geometry preserve exact bits")
		_check(Ritual.canonical_json(source.scenario_numeric_probe) == Ritual.canonical_json(restored.scenario_numeric_probe), "ritual canonical bytes are unchanged")
		_check(CrewTurn.canonical_json(source.scenario_numeric_probe) == CrewTurn.canonical_json(restored.scenario_numeric_probe), "Crew public-context canonical bytes are unchanged")
		var tampered: Dictionary = restored.scenario_numeric_probe.duplicate(true)
		tampered.counter -= 1
		_check(Ritual.canonical_fingerprint(source.scenario_numeric_probe) != Ritual.canonical_fingerprint(tampered), "changed bound integer remains detectable")
	# Negative zero is included in actual pack/unpack, not only direct parsing.
	for bit_text in ["0000000000000000", "0000000000000080", "0100000000000000", "ffffffffffff0f00", "0000000000001000", "ffffffffffffef7f", "c6f396eaa7770140", "77c41d7147dca13f"]:
		var fixture := {"seed_text": "synthetic", "rng_state": "12", "current_environment": {}, "number": str(bit_text).hex_decode().decode_double(0)}
		var pack := Codec.pack_for_storage(fixture)
		if _check(bool(pack.get("ok", false)), "finite bit fixture packs: " + bit_text):
			_check(_bits(Codec.unpack_from_storage(pack.packed).get("number")) == bit_text, "finite bit fixture exact roundtrip: " + bit_text)

func _independent_vectors() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/samewire_numeric_vectors.json"))
	var tokens := PackedStringArray()
	for row in fixture.rows:
		tokens.append(str(row.token))
	var text := "[" + ",".join(tokens) + "]"
	var started := Time.get_ticks_msec()
	var parsed := Numeric.parse(text)
	if not _check(parsed.error == OK and typeof(parsed.data) == TYPE_ARRAY and parsed.data.size() == fixture.rows.size(), "independent oracle vector array parses"):
		return
	var values: Array = parsed.data
	for index in range(values.size()):
		_check(_bits(values[index]) == fixture.rows[index].expected_le64, "independent rational/bit oracle " + str(index))
	var pack := Codec.pack_for_storage({"seed_text": "synthetic", "rng_state": "12", "current_environment": {}, "values": values})
	if _check(bool(pack.get("ok", false)), "oracle vector values pack in existing envelope"):
		var restored := Codec.unpack_from_storage(pack.packed)
		_check(_same(values, restored.get("values")), "all oracle finite bit values roundtrip through actual writer/codec")
		var old := JSON.new()
		_check(old.parse(Codec._validated_storage_source(pack.packed).get_string_from_utf8()) == OK and typeof(old.data) == TYPE_DICTIONARY, "old native JSON reader accepts current storage numeric leaves")
		_check(not str(Codec._validated_storage_source(pack.packed).get_string_from_utf8()).contains("~bth-json-"), "temporary numeric and zero tokens never persist")
	_check(Time.get_ticks_msec() - started < 30000, "bounded oracle vector parse/pack completes within 30s native budget")
	# Escaped live strings and key spellings must never become numeric markers.
	var collision := Numeric.parse('{"s":"\\u007ebth-json-number:0~","~bth-json-number:1~":"literal","v":2.1834257438008278}')
	_check(collision.error == OK and collision.data.s == "~bth-json-number:0~" and collision.data["~bth-json-number:1~"] == "literal" and _bits(collision.data.v) == "c6f396eaa7770140", "escaped marker collision is opaque")
	var zeros := {"z": "0000000000000080".hex_decode().decode_double(0), "s": "~bth-json-negative-zero:0~", "~bth-json-negative-zero:1~": "literal", "packed": PackedFloat64Array([0.0, "0000000000000080".hex_decode().decode_double(0)])}
	var before := var_to_bytes(zeros)
	var zero_text := Numeric.stringify(zeros)
	var zero_read := Numeric.parse(zero_text)
	_check(var_to_bytes(zeros) == before and zero_read.data.s == zeros.s and zero_read.data["~bth-json-negative-zero:1~"] == "literal" and _bits(zero_read.data.z) == "0000000000000080" and _bits(zero_read.data.packed[1]) == "0000000000000080", "negative zero serialization owns its projection and preserves literal collisions")

func _expect_number(token: String, expected: String, label: String) -> void:
	var loaded := _load_text(_number_object(token))
	_check(loaded.has("number") and typeof(loaded.get("number")) == TYPE_FLOAT and _bits(loaded.get("number")) == expected, label)

func _number_object(token: String) -> String:
	return '{"seed_text":"synthetic","rng_state":"12","current_environment":{},"number":' + token + '}'

func _load_text(text: String) -> Dictionary:
	return Codec.unpack_from_storage(_pack_text(text))

func _pack_text(text: String) -> Dictionary:
	var source := text.to_utf8_buffer()
	var compressed := source.compress(FileAccess.COMPRESSION_ZSTD)
	return {Codec.STORAGE_MARKER_KEY: Codec.STORAGE_FORMAT, Codec.STORAGE_DATA_KEY: Codec._z85_encode(compressed), Codec.STORAGE_HASH_KEY: text.sha256_text(), Codec.STORAGE_SIZE_KEY: source.size(), Codec.STORAGE_COMPRESSED_SIZE_KEY: compressed.size()}

func _dyadic_decimal(mantissa: int, exponent: int) -> String:
	var digits := str(mantissa)
	for _ignored in range(absi(exponent)):
		digits = _multiply_decimal(digits, 5 if exponent < 0 else 2)
	if exponent >= 0:
		return digits
	var places := -exponent
	if digits.length() <= places:
		return "0." + "0".repeat(places - digits.length()) + digits
	return digits.substr(0, digits.length() - places) + "." + digits.substr(digits.length() - places)

func _multiply_decimal(digits: String, factor: int) -> String:
	var pieces := PackedStringArray()
	var carry := 0
	for index in range(digits.length() - 1, -1, -1):
		var value := (digits.unicode_at(index) - 48) * factor + carry
		pieces.append(str(value % 10))
		@warning_ignore("integer_division")
		carry = value / 10
	if carry > 0:
		pieces.append(str(carry))
	pieces.reverse()
	return "".join(pieces)

func _decrement_integer(digits: String) -> String:
	for index in range(digits.length() - 1, -1, -1):
		if digits[index] != "0":
			return digits.substr(0, index) + str(digits.unicode_at(index) - 49) + "9".repeat(digits.length() - index - 1)
	return "0"

func _bits(value: Variant) -> String:
	if typeof(value) != TYPE_FLOAT:
		return "not-float"
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.hex_encode()

func _same(left: Variant, right: Variant) -> bool:
	# Dictionary insertion order is not JSON semantics; numeric types and bits
	# are. No integer/float coercion, field filtering or tolerance is allowed.
	if typeof(left) != typeof(right):
		return false
	if typeof(left) == TYPE_FLOAT:
		return _bits(left) == _bits(right)
	if typeof(left) == TYPE_DICTIONARY:
		if left.size() != right.size():
			return false
		for key in left:
			if not right.has(key) or not _same(left[key], right[key]):
				return false
		return true
	if typeof(left) == TYPE_ARRAY:
		if left.size() != right.size():
			return false
		for index in range(left.size()):
			if not _same(left[index], right[index]):
				return false
		return true
	return left == right

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
	return ok
