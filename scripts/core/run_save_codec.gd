class_name RunSaveCodec
extends RefCounted

const ScenarioSequenceCatalogScript := preload("res://scripts/core/scenario_sequence_catalog.gd")
const PersistentEnvironmentProjectionScript := preload("res://scripts/core/persistent_environment_projection.gd")

# Save-only projection. Runtime dictionaries keep their full authored state;
# persisted data deduplicates identical environments and omits slot definition
# arrays that are reconstructed from stable machine IDs by SlotGame.

const CODEC_VERSION := 2
const ENVIRONMENT_REF_KEY := "__bth_environment_ref"
const REGISTRY_KEY := "environment_registry"
const CODEC_KEY := "run_save_codec_version"
const EXACT_INT_KEY := "__bth_exact_int64"
const EXACT_INTEGER_ROOT_KEYS := ["active_delivery_run", "world_sequence_registrations"]
const BLACKJACK_LEDGER_KEY := "_blackjack_action_authority"
const SLOT_DEFINITION_KEYS := ["reel_strips", "bonus_reel_strips"]
const SLOT_DUPLICATE_PRESENTATION_KEYS := ["slot_reel_timeline", "slot_reel_stop_times"]
const STORAGE_MARKER_KEY := "__bth_packed_run_state"
const STORAGE_DATA_KEY := "data"
const STORAGE_HASH_KEY := "sha256"
const STORAGE_SIZE_KEY := "uncompressed_bytes"
const STORAGE_FORMAT := "json-zstd-z85-v1"
const MAX_STORAGE_BYTES := 32 * 1024 * 1024
const PACK_ERROR_EMPTY := "empty_input"
const PACK_ERROR_TOO_LARGE := "storage_limit_exceeded"
const PACK_ERROR_COMPRESSION := "compression_failed"
const STORAGE_COMPRESSED_SIZE_KEY := "compressed_bytes"
const Z85_ALPHABET := "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-:+=^!/*?&<>()[]{}@%$#"
# The nothreads Web template executes WorkerThreadPool tasks on the calling
# thread. Keep the exact storage format, but run its byte loops in the browser's
# JavaScript engine instead of interpreting them once per byte in GDScript/Wasm.
# Arguments are JSON string literals; no save text is executable source. These
# functions are local expressions with no global state or persistence access.
const WEB_Z85_ENCODE := """(function(base64, alphabet) {
    const source = atob(base64), groups = Math.ceil(source.length / 4);
    const result = new Array(groups);
    for (let group = 0; group < groups; group++) {
        let value = 0;
        for (let offset = 0; offset < 4; offset++) {
            const index = group * 4 + offset;
            value = value * 256 + (index < source.length ? source.charCodeAt(index) : 0);
        }
        const digits = new Array(5);
        for (let digit = 4; digit >= 0; digit--) {
            digits[digit] = alphabet[value % 85];
            value = Math.floor(value / 85);
        }
        result[group] = digits.join('');
    }
    return result.join('');
})"""
const WEB_Z85_DECODE := """(function(source, expectedSize, alphabet) {
    if (!source.length || source.length % 5 || expectedSize <= 0 || expectedSize > source.length / 5 * 4) return null;
    const digits = new Int16Array(256); digits.fill(-1);
    for (let i = 0; i < alphabet.length; i++) digits[alphabet.charCodeAt(i)] = i;
    const result = new Uint8Array(expectedSize);
    for (let group = 0; group < source.length / 5; group++) {
        let value = 0;
        for (let digit = 0; digit < 5; digit++) {
            const code = source.charCodeAt(group * 5 + digit);
            if (code > 255 || digits[code] < 0) return null;
            value = value * 85 + digits[code];
        }
        for (let offset = 0; offset < 4; offset++) result[group * 4 + offset] = (value >>> ((3 - offset) * 8)) & 255;
    }
    return result;
})"""
const SEEDED_SCENARIO_DEFINITIONS_KEY := "seeded_scenario_definitions_by_node"
const SCENARIO_DEFINITION_REF_KEY := "__bth_scenario_definition_ref"
const SCENARIO_DEFINITION_PATCH_KEY := "p"
const PATCH_VALUE_KEY := "v"
const PATCH_DICTIONARY_KEY := "d"
const PATCH_ERASE_KEY := "e"
const ENVIRONMENT_BASE_REF_KEY := "__bth_environment_base_ref"

static var _scenario_definition_cache: Dictionary = {}
static var debug_storage_byte_limit_override: int = 0
static var debug_force_compression_failure: bool = false



static func encode(runtime_state: Dictionary) -> Dictionary:
	var registry: Dictionary = {}
	var fingerprints: Dictionary = {}
	var encoded_value: Variant = _encode_value(runtime_state, registry, fingerprints, false)
	var encoded: Dictionary = encoded_value as Dictionary if typeof(encoded_value) == TYPE_DICTIONARY else {}
	_compact_environment_registry_deltas(registry)
	encoded[CODEC_KEY] = CODEC_VERSION
	encoded[REGISTRY_KEY] = registry
	return encoded


static func decode(saved_state: Dictionary) -> Dictionary:
	if int(saved_state.get(CODEC_KEY, 0)) <= 0:
		var legacy: Variant = _restore_exact_integer_markers(saved_state)
		return legacy as Dictionary if typeof(legacy) == TYPE_DICTIONARY else {}
	var registry_value: Variant = saved_state.get(REGISTRY_KEY, {})
	var registry: Dictionary = _expand_environment_registry_deltas(registry_value as Dictionary) if typeof(registry_value) == TYPE_DICTIONARY else {}
	var root: Dictionary = saved_state.duplicate(false)
	root.erase(CODEC_KEY)
	root.erase(REGISTRY_KEY)
	var decoded: Variant = _decode_value(root, registry)
	return decoded as Dictionary if typeof(decoded) == TYPE_DICTIONARY else {}


static func _compact_environment_registry_deltas(registry: Dictionary) -> void:
	var previous_by_identity: Dictionary = {}
	for ref_value in registry.keys():
		var ref := str(ref_value)
		var environment_value: Variant = registry.get(ref_value)
		if typeof(environment_value) != TYPE_DICTIONARY:
			continue
		var environment: Dictionary = environment_value
		var identity := str(environment.get("id", "")).strip_edges()
		if identity.is_empty() or not previous_by_identity.has(identity):
			previous_by_identity[identity] = ref
			continue
		var base_ref := str(previous_by_identity.get(identity, ""))
		var base_value: Variant = registry.get(base_ref)
		if typeof(base_value) != TYPE_DICTIONARY:
			continue
		var patch: Variant = _dictionary_patch(environment, base_value)
		if patch == null:
			registry[ref_value] = {ENVIRONMENT_BASE_REF_KEY: base_ref}
			continue
		var delta := {ENVIRONMENT_BASE_REF_KEY: base_ref, SCENARIO_DEFINITION_PATCH_KEY: patch}
		if JSON.stringify(delta).length() < JSON.stringify(environment).length():
			registry[ref_value] = delta


static func _expand_environment_registry_deltas(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for ref_value in source.keys():
		var value: Variant = source.get(ref_value)
		if typeof(value) != TYPE_DICTIONARY or not (value as Dictionary).has(ENVIRONMENT_BASE_REF_KEY):
			result[ref_value] = value
			continue
		var entry: Dictionary = value
		var base_ref := str(entry.get(ENVIRONMENT_BASE_REF_KEY, ""))
		var base_value: Variant = result.get(base_ref)
		if typeof(base_value) != TYPE_DICTIONARY:
			return {}
		result[ref_value] = _apply_dictionary_patch(base_value, entry.get(SCENARIO_DEFINITION_PATCH_KEY, {})) if entry.has(SCENARIO_DEFINITION_PATCH_KEY) else (base_value as Dictionary).duplicate(true)
	return result


# The save envelope remains JSON and the codec schema remains unchanged. This
# storage layer removes the repeated authored/runtime payload cost on disk and
# is transparently accepted alongside every previously shipped unpacked save.
static func pack_for_storage(encoded_state: Dictionary) -> Dictionary:
	var source := JSON.stringify(encoded_state).to_utf8_buffer()
	var storage_limit := debug_storage_byte_limit_override if debug_storage_byte_limit_override > 0 else MAX_STORAGE_BYTES
	if source.is_empty():
		return {"ok": false, "error": ERR_INVALID_DATA, "error_code": PACK_ERROR_EMPTY, "packed": {}}
	if source.size() > storage_limit:
		return {"ok": false, "error": ERR_OUT_OF_MEMORY, "error_code": PACK_ERROR_TOO_LARGE, "packed": {}, "uncompressed_bytes": source.size(), "storage_limit_bytes": storage_limit}
	if debug_force_compression_failure:
		return {"ok": false, "error": ERR_CANT_CREATE, "error_code": PACK_ERROR_COMPRESSION, "packed": {}}
	var compressed := source.compress(FileAccess.COMPRESSION_ZSTD)
	if compressed.is_empty():
		return {"ok": false, "error": ERR_CANT_CREATE, "error_code": PACK_ERROR_COMPRESSION, "packed": {}}
	return {"ok": true, "error": OK, "error_code": "", "packed": {
		STORAGE_MARKER_KEY: STORAGE_FORMAT,
		STORAGE_DATA_KEY: _z85_encode(compressed),
		STORAGE_HASH_KEY: _sha256(source),
		STORAGE_SIZE_KEY: source.size(),
		STORAGE_COMPRESSED_SIZE_KEY: compressed.size(),
	}}


static func storage_envelope_valid(value: Dictionary) -> bool:
	if not value.has(STORAGE_MARKER_KEY):
		return true
	if value.size() != 5 or str(value.get(STORAGE_MARKER_KEY, "")) != STORAGE_FORMAT:
		return false
	var expected_size := int(value.get(STORAGE_SIZE_KEY, 0))
	var compressed_size := int(value.get(STORAGE_COMPRESSED_SIZE_KEY, 0))
	var expected_hash := str(value.get(STORAGE_HASH_KEY, ""))
	var encoded_data := str(value.get(STORAGE_DATA_KEY, ""))
	return expected_size > 0 and expected_size <= MAX_STORAGE_BYTES \
		and compressed_size > 0 and compressed_size <= MAX_STORAGE_BYTES \
		and encoded_data.length() == int(ceil(float(compressed_size) / 4.0)) * 5 \
		and expected_hash.length() == 64


# Only content/shape validation may skip the legacy token repair. Real loads
# keep the default so authority hashes receive exact historical integer values.
static func unpack_from_storage(stored_state: Dictionary, preserve_legacy_authority_integers: bool = true) -> Dictionary:
	if not stored_state.has(STORAGE_MARKER_KEY):
		return stored_state.duplicate(true)
	var source := _validated_storage_source(stored_state)
	if source.is_empty():
		return {}
	var json := JSON.new()
	var json_text := source.get_string_from_utf8()
	if preserve_legacy_authority_integers:
		json_text = preserve_blackjack_ledger_integer_tokens(json_text)
	if json.parse(json_text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	# This parser was created for this one call. Its complete JSON graph is
	# already privately owned; another deep copy cannot detach it any further.
	return json.data as Dictionary


static func storage_contents_valid(stored_state: Dictionary) -> bool:
	if not stored_state.has(STORAGE_MARKER_KEY):
		return _required_content_roots(stored_state)
	var source := _validated_storage_source(stored_state)
	return not source.is_empty() and _json_content_roots_valid(source.get_string_from_utf8())


static func _json_content_roots_valid(json_text: String) -> bool:
	var json := JSON.new()
	return json.parse(json_text) == OK and typeof(json.data) == TYPE_DICTIONARY and _required_content_roots(json.data)


static func _required_content_roots(value: Dictionary) -> bool:
	return not value.is_empty() and value.has("seed_text") and value.has("rng_state") and value.has("current_environment")


static func _validated_storage_source(stored_state: Dictionary) -> PackedByteArray:
	if not storage_envelope_valid(stored_state):
		return PackedByteArray()
	var compressed := _z85_decode(
		str(stored_state.get(STORAGE_DATA_KEY, "")),
		int(stored_state.get(STORAGE_COMPRESSED_SIZE_KEY, 0))
	)
	if compressed.is_empty():
		return PackedByteArray()
	var source := compressed.decompress(int(stored_state.get(STORAGE_SIZE_KEY, 0)), FileAccess.COMPRESSION_ZSTD)
	if source.size() != int(stored_state.get(STORAGE_SIZE_KEY, 0)) \
			or _sha256(source) != str(stored_state.get(STORAGE_HASH_KEY, "")):
		return PackedByteArray()
	return source


# Prior packed saves wrote the authority ledger as ordinary JSON. Godot parses
# every JSON number as a float, invalidating the ledger's type-sensitive hashes
# even when the saved bytes are intact. Restore only integer literals inside
# ledger objects before the existing strict authority validation runs. Float
# literals (including 3.0) and all non-ledger save fields stay unchanged.
static func preserve_blackjack_ledger_integer_tokens(json_text: String) -> String:
	var marker := '"%s"' % BLACKJACK_LEDGER_KEY
	var ranges: Array[Dictionary] = []
	var offset := 0
	while offset < json_text.length():
		var key_at := json_text.find(marker, offset)
		if key_at < 0:
			break
		var value_at := key_at + marker.length()
		while value_at < json_text.length() and json_text[value_at] in [" ", "\t", "\r", "\n"]:
			value_at += 1
		if value_at >= json_text.length() or json_text[value_at] != ":":
			offset = value_at
			continue
		value_at += 1
		while value_at < json_text.length() and json_text[value_at] in [" ", "\t", "\r", "\n"]:
			value_at += 1
		if value_at >= json_text.length() or json_text[value_at] != "{":
			offset = value_at
			continue
		var end_at := _json_object_end(json_text, value_at)
		if end_at < 0:
			return json_text
		ranges.append({"start": value_at, "end": end_at})
		offset = end_at
	for range_index in range(ranges.size() - 1, -1, -1):
		var span: Dictionary = ranges[range_index]
		var start_at := int(span.get("start", 0))
		var end_at := int(span.get("end", 0))
		json_text = json_text.substr(0, start_at) \
			+ _json_wrap_integer_literals(json_text.substr(start_at, end_at - start_at)) \
			+ json_text.substr(end_at)
	return json_text


static func _json_object_end(json_text: String, start_at: int) -> int:
	var depth := 0
	var inside_string := false
	var escaped := false
	for index in range(start_at, json_text.length()):
		var character := json_text[index]
		if inside_string:
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == '"':
				inside_string = false
		elif character == '"':
			inside_string = true
		elif character == "{":
			depth += 1
		elif character == "}":
			depth -= 1
			if depth == 0:
				return index + 1
	return -1


static func _json_wrap_integer_literals(json_text: String) -> String:
	var pieces: Array[String] = []
	var copy_from := 0
	var index := 0
	var inside_string := false
	var escaped := false
	while index < json_text.length():
		var character := json_text[index]
		if inside_string:
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == '"':
				inside_string = false
			index += 1
			continue
		if character == '"':
			inside_string = true
			index += 1
			continue
		if character != "-" and not character in "0123456789":
			index += 1
			continue
		var number_end := index + 1
		while number_end < json_text.length() and json_text[number_end] in "0123456789+-.eE":
			number_end += 1
		var token := json_text.substr(index, number_end - index)
		if token.is_valid_int():
			pieces.append(json_text.substr(copy_from, index - copy_from))
			pieces.append('{"%s":"%s"}' % [EXACT_INT_KEY, token])
			copy_from = number_end
		index = number_end
	pieces.append(json_text.substr(copy_from))
	return "".join(pieces)


static func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(bytes)
	return context.finish().hex_encode()


static func _z85_encode(source: PackedByteArray) -> String:
	if source.is_empty():
		return ""
	if OS.has_feature("web") and Thread.is_main_thread():
		var fast: Variant = JavaScriptBridge.eval(WEB_Z85_ENCODE + "(" + JSON.stringify(Marshalls.raw_to_base64(source)) + "," + JSON.stringify(Z85_ALPHABET) + ")")
		if typeof(fast) == TYPE_STRING and (fast as String).length() == int(ceil(float(source.size()) / 4.0)) * 5:
			return fast as String
	# Native builds and unavailable browser bridges retain the original codec.
	return _z85_encode_gdscript(source)


static func _z85_encode_gdscript(source: PackedByteArray) -> String:
	if source.is_empty():
		return ""
	var alphabet := Z85_ALPHABET.to_ascii_buffer()
	var group_count := int(ceil(float(source.size()) / 4.0))
	var encoded := PackedByteArray()
	encoded.resize(group_count * 5)
	for group in range(group_count):
		var value := 0
		for offset in range(4):
			var source_index := group * 4 + offset
			value = (value << 8) | (int(source[source_index]) if source_index < source.size() else 0)
		for digit_index in range(4, -1, -1):
			encoded[group * 5 + digit_index] = alphabet[value % 85]
			value /= 85
	return encoded.get_string_from_ascii()


static func _z85_decode(encoded_text: String, expected_size: int) -> PackedByteArray:
	if OS.has_feature("web") and Thread.is_main_thread():
		var fast: Variant = JavaScriptBridge.eval(WEB_Z85_DECODE + "(" + JSON.stringify(encoded_text) + "," + str(expected_size) + "," + JSON.stringify(Z85_ALPHABET) + ")")
		if typeof(fast) == TYPE_PACKED_BYTE_ARRAY and (fast as PackedByteArray).size() == expected_size:
			return fast as PackedByteArray
	# All storage envelope, decompression and content-hash checks stay at their
	# existing boundaries. A missing/failed bridge does not weaken validation.
	return _z85_decode_gdscript(encoded_text, expected_size)


static func _z85_decode_gdscript(encoded_text: String, expected_size: int) -> PackedByteArray:
	var encoded := encoded_text.to_ascii_buffer()
	if encoded.is_empty() or encoded.size() % 5 != 0 or expected_size <= 0:
		return PackedByteArray()
	var alphabet := Z85_ALPHABET.to_ascii_buffer()
	var digit_by_byte := PackedByteArray()
	digit_by_byte.resize(256)
	digit_by_byte.fill(255)
	for alphabet_index in range(alphabet.size()):
		digit_by_byte[alphabet[alphabet_index]] = alphabet_index
	var decoded := PackedByteArray()
	decoded.resize((encoded.size() / 5) * 4)
	for group in range(encoded.size() / 5):
		var value := 0
		for digit_index in range(5):
			var digit := int(digit_by_byte[encoded[group * 5 + digit_index]])
			if digit == 255:
				return PackedByteArray()
			value = value * 85 + digit
		for offset in range(4):
			decoded[group * 4 + offset] = (value >> ((3 - offset) * 8)) & 0xff
	if expected_size > decoded.size():
		return PackedByteArray()
	decoded.resize(expected_size)
	return decoded


static func _encode_value(value: Variant, registry: Dictionary, fingerprints: Dictionary, inside_environment: bool) -> Variant:
	if typeof(value) == TYPE_OBJECT and value != null and value.get_script() == PersistentEnvironmentProjectionScript:
		return value.encode_into(registry, fingerprints)
	if typeof(value) == TYPE_DICTIONARY:
		var source: Dictionary = value
		if not inside_environment and _looks_like_environment(source):
			return _encode_environment_reference(source, registry, fingerprints)
		var encoded_dict: Dictionary = {}
		for key_value in source.keys():
			var key := str(key_value)
			var child: Variant = source.get(key_value)
			if key == SEEDED_SCENARIO_DEFINITIONS_KEY and typeof(child) == TYPE_DICTIONARY:
				encoded_dict[key_value] = _encode_seeded_scenario_definitions(child as Dictionary)
			else:
				var crew_encounters := key == "encounters" and source.has("recruitment_schema_version")
				encoded_dict[key_value] = _encode_exact_integers(child) if key.begins_with("scenario_") or key in EXACT_INTEGER_ROOT_KEYS or key == BLACKJACK_LEDGER_KEY or crew_encounters else _encode_value(child, registry, fingerprints, inside_environment)
		return encoded_dict
	if typeof(value) == TYPE_ARRAY:
		var source_array: Array = value
		var encoded_array: Array = []
		for index in range(source_array.size()):
			encoded_array.append(_encode_value(source_array[index], registry, fingerprints, inside_environment))
		return encoded_array
	if typeof(value) >= TYPE_PACKED_BYTE_ARRAY:
		return value.duplicate()
	return value


static func _owned_encoded_leaf(value: Variant) -> Variant:
	# Dictionary.duplicate(true) does not detach packed-array leaves. The encoded
	# generation may outlive this frame, so own these mutable buffers as well.
	match typeof(value):
		TYPE_DICTIONARY:
			var owned: Dictionary = {}
			for key in value:
				owned[key] = _owned_encoded_leaf(value[key])
			return owned
		TYPE_ARRAY:
			var owned: Array = []
			for entry in value:
				owned.append(_owned_encoded_leaf(entry))
			return owned
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			return value.duplicate()
	return value


static func _encode_environment_reference(environment: Dictionary, registry: Dictionary, fingerprints: Dictionary) -> Dictionary:
	var encoded_value: Variant = _encode_value(environment, registry, fingerprints, true)
	var encoded: Dictionary = encoded_value as Dictionary if typeof(encoded_value) == TYPE_DICTIONARY else {}
	_compact_slot_game_states(encoded)
	return _register_encoded_environment_reference(encoded, registry, fingerprints, str(environment.get("id", "environment")))


static func _register_encoded_environment_reference(encoded: Dictionary, registry: Dictionary, fingerprints: Dictionary, environment_id: String) -> Dictionary:
	var fingerprint := str(hash(encoded))
	var candidate_refs: Array = fingerprints.get(fingerprint, []) if typeof(fingerprints.get(fingerprint, [])) == TYPE_ARRAY else []
	for candidate_ref_value in candidate_refs:
		var candidate_ref := str(candidate_ref_value)
		if registry.get(candidate_ref, {}) == encoded:
			return {ENVIRONMENT_REF_KEY: candidate_ref}
	var base_ref := environment_id.strip_edges()
	if base_ref.is_empty():
		base_ref = "environment"
	var ref := base_ref
	var suffix := 2
	while registry.has(ref):
		ref = "%s#%d" % [base_ref, suffix]
		suffix += 1
	registry[ref] = encoded
	candidate_refs.append(ref)
	fingerprints[fingerprint] = candidate_refs
	return {ENVIRONMENT_REF_KEY: ref}


static func _compact_slot_game_states(environment: Dictionary) -> void:
	var states_value: Variant = environment.get("game_states", {})
	if typeof(states_value) != TYPE_DICTIONARY:
		return
	var states: Dictionary = states_value
	var compacted := states.duplicate(false)
	for key_value in states.keys():
		var state_key := str(key_value)
		var machine_value: Variant = states.get(key_value)
		if (state_key != "slot" and not state_key.begins_with("slot:")) or typeof(machine_value) != TYPE_DICTIONARY:
			continue
		var machine: Dictionary = (machine_value as Dictionary).duplicate(true)
		if not machine.has("format_id") or not machine.has("type_id"):
			continue
		for key in SLOT_DEFINITION_KEYS:
			machine.erase(key)
		for key in SLOT_DUPLICATE_PRESENTATION_KEYS:
			machine.erase(key)
		machine["schema_version"] = maxi(2, int(machine.get("schema_version", 2)))
		compacted[key_value] = machine
	environment["game_states"] = compacted


static func _decode_value(value: Variant, registry: Dictionary) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var source: Dictionary = value
		if source.has(SCENARIO_DEFINITION_REF_KEY):
			return _decode_seeded_scenario_definition(source)
		if source.size() == 1 and typeof(source.get(EXACT_INT_KEY)) == TYPE_STRING:
			return int(str(source.get(EXACT_INT_KEY, "0")))
		if source.size() == 1 and source.has(ENVIRONMENT_REF_KEY):
			var ref := str(source.get(ENVIRONMENT_REF_KEY, ""))
			var stored: Variant = registry.get(ref, {})
			return _decode_value(stored, registry) if typeof(stored) == TYPE_DICTIONARY else {}
		var result: Dictionary = {}
		for key_value in source.keys():
			result[key_value] = _decode_value(source.get(key_value), registry)
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for entry_value in value as Array:
			result.append(_decode_value(entry_value, registry))
		return result
	return value


static func _restore_exact_integer_markers(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var source: Dictionary = value
		if source.size() == 1 and typeof(source.get(EXACT_INT_KEY)) == TYPE_STRING:
			return int(str(source.get(EXACT_INT_KEY, "0")))
		var restored: Dictionary = {}
		for key in source.keys():
			restored[key] = _restore_exact_integer_markers(source.get(key))
		return restored
	if typeof(value) == TYPE_ARRAY:
		var restored_array: Array = []
		for item in value as Array:
			restored_array.append(_restore_exact_integer_markers(item))
		return restored_array
	return value


static func _encode_seeded_scenario_definitions(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for node_id_value in source.keys():
		var node_id := str(node_id_value)
		var definition_value: Variant = source.get(node_id_value)
		if typeof(definition_value) != TYPE_DICTIONARY:
			result[node_id_value] = _owned_encoded_leaf(definition_value)
			continue
		var definition: Dictionary = definition_value
		var scenario_id := str(definition.get("id", "")).strip_edges()
		var catalog_definition := _catalog_scenario_definition(scenario_id)
		if scenario_id.is_empty() or catalog_definition.is_empty():
			result[node_id_value] = _encode_exact_integers(definition)
			continue
		var entry := {SCENARIO_DEFINITION_REF_KEY: scenario_id}
		var patch: Variant = _dictionary_patch(definition, catalog_definition)
		if patch != null:
			# Sequence signatures are type-sensitive. JSON otherwise turns integers
			# inside a compact delta into floats and invalidates the definition only
			# after a later room attempts to mount it.
			entry[SCENARIO_DEFINITION_PATCH_KEY] = _encode_exact_integers(patch)
		result[node_id_value] = entry
	return result


static func _decode_seeded_scenario_definition(entry: Dictionary) -> Dictionary:
	var scenario_id := str(entry.get(SCENARIO_DEFINITION_REF_KEY, "")).strip_edges()
	var definition := _catalog_scenario_definition(scenario_id).duplicate(true)
	if definition.is_empty():
		return {}
	if entry.has(SCENARIO_DEFINITION_PATCH_KEY):
		var decoded_patch: Variant = _decode_value(entry.get(SCENARIO_DEFINITION_PATCH_KEY), {})
		var patched: Variant = _apply_dictionary_patch(definition, decoded_patch)
		return patched as Dictionary if typeof(patched) == TYPE_DICTIONARY else {}
	return definition


static func _catalog_scenario_definition(scenario_id: String) -> Dictionary:
	if scenario_id.is_empty():
		return {}
	if not _scenario_definition_cache.has(scenario_id):
		_scenario_definition_cache[scenario_id] = ScenarioSequenceCatalogScript.legacy_definition(scenario_id)
	var value: Variant = _scenario_definition_cache.get(scenario_id, {})
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


# A selected scenario generally differs from its immutable catalog definition
# only by small trusted validation markers. Persist those deltas instead of a
# second copy of every authored sequence in the town snapshot.
static func _dictionary_patch(source: Variant, base: Variant) -> Variant:
	if source == base:
		return null
	if typeof(source) != TYPE_DICTIONARY or typeof(base) != TYPE_DICTIONARY:
		return {PATCH_VALUE_KEY: source}
	var source_dict: Dictionary = source
	var base_dict: Dictionary = base
	var changed: Dictionary = {}
	var erased: Array = []
	for key_value in source_dict.keys():
		var child_patch: Variant = _dictionary_patch(source_dict.get(key_value), base_dict.get(key_value)) if base_dict.has(key_value) else {PATCH_VALUE_KEY: source_dict.get(key_value)}
		if child_patch != null:
			changed[key_value] = child_patch
	for key_value in base_dict.keys():
		if not source_dict.has(key_value):
			erased.append(key_value)
	if changed.is_empty() and erased.is_empty():
		return null
	var result: Dictionary = {}
	if not changed.is_empty():
		result[PATCH_DICTIONARY_KEY] = changed
	if not erased.is_empty():
		result[PATCH_ERASE_KEY] = erased
	return result


static func _apply_dictionary_patch(base: Variant, patch: Variant) -> Variant:
	if typeof(patch) != TYPE_DICTIONARY:
		return base
	var patch_dict: Dictionary = patch
	if patch_dict.has(PATCH_VALUE_KEY):
		return patch_dict.get(PATCH_VALUE_KEY)
	if typeof(base) != TYPE_DICTIONARY:
		return base
	var result := (base as Dictionary).duplicate(true)
	var changed_value: Variant = patch_dict.get(PATCH_DICTIONARY_KEY, {})
	if typeof(changed_value) == TYPE_DICTIONARY:
		for key_value in (changed_value as Dictionary).keys():
			result[key_value] = _apply_dictionary_patch(result.get(key_value), (changed_value as Dictionary).get(key_value))
	var erased_value: Variant = patch_dict.get(PATCH_ERASE_KEY, [])
	if typeof(erased_value) == TYPE_ARRAY:
		for key_value in erased_value as Array:
			result.erase(key_value)
	return result


# JSON has one numeric type and otherwise changes every persisted integer into a
# float. Dynamic scenario, mounted world-sequence, delivery depth, and Blackjack
# authority validate exact typed envelopes, so preserve integer identity for
# those save fields.
static func _encode_exact_integers(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return {EXACT_INT_KEY: str(value)}
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		for key_value in (value as Dictionary).keys():
			result[key_value] = _encode_exact_integers((value as Dictionary).get(key_value))
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for entry_value in value as Array:
			result.append(_encode_exact_integers(entry_value))
		return result
	if typeof(value) >= TYPE_PACKED_BYTE_ARRAY:
		return value.duplicate()
	return value


static func _looks_like_environment(value: Dictionary) -> bool:
	return value.has("id") and value.has("game_states") and (value.has("archetype_id") or value.has("kind"))
