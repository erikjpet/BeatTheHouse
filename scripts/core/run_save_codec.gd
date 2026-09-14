class_name RunSaveCodec
extends RefCounted

const ScenarioSequenceCatalogScript := preload("res://scripts/core/scenario_sequence_catalog.gd")

# Save-only projection. Runtime dictionaries keep their full authored state;
# persisted data deduplicates identical environments and omits slot definition
# arrays that are reconstructed from stable machine IDs by SlotGame.

const CODEC_VERSION := 2
const ENVIRONMENT_REF_KEY := "__bth_environment_ref"
const REGISTRY_KEY := "environment_registry"
const CODEC_KEY := "run_save_codec_version"
const EXACT_INT_KEY := "__bth_exact_int64"
const EXACT_INTEGER_ROOT_KEYS := ["active_delivery_run", "world_sequence_registrations"]
const SLOT_DEFINITION_KEYS := ["reel_strips", "bonus_reel_strips"]
const SLOT_DUPLICATE_PRESENTATION_KEYS := ["slot_reel_timeline", "slot_reel_stop_times"]
const STORAGE_MARKER_KEY := "__bth_packed_run_state"
const STORAGE_DATA_KEY := "data"
const STORAGE_HASH_KEY := "sha256"
const STORAGE_SIZE_KEY := "uncompressed_bytes"
const STORAGE_FORMAT := "json-zstd-z85-v1"
const MAX_STORAGE_BYTES := 32 * 1024 * 1024
const STORAGE_COMPRESSED_SIZE_KEY := "compressed_bytes"
const Z85_ALPHABET := "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-:+=^!/*?&<>()[]{}@%$#"
const SEEDED_SCENARIO_DEFINITIONS_KEY := "seeded_scenario_definitions_by_node"
const SCENARIO_DEFINITION_REF_KEY := "__bth_scenario_definition_ref"
const SCENARIO_DEFINITION_PATCH_KEY := "p"
const PATCH_VALUE_KEY := "v"
const PATCH_DICTIONARY_KEY := "d"
const PATCH_ERASE_KEY := "e"
const ENVIRONMENT_BASE_REF_KEY := "__bth_environment_base_ref"

static var _scenario_definition_cache: Dictionary = {}


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
		return saved_state.duplicate(true)
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
	if source.is_empty() or source.size() > MAX_STORAGE_BYTES:
		return {}
	var compressed := source.compress(FileAccess.COMPRESSION_ZSTD)
	if compressed.is_empty():
		return {}
	return {
		STORAGE_MARKER_KEY: STORAGE_FORMAT,
		STORAGE_DATA_KEY: _z85_encode(compressed),
		STORAGE_HASH_KEY: _sha256(source),
		STORAGE_SIZE_KEY: source.size(),
		STORAGE_COMPRESSED_SIZE_KEY: compressed.size(),
	}


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


static func unpack_from_storage(stored_state: Dictionary) -> Dictionary:
	if not stored_state.has(STORAGE_MARKER_KEY):
		return stored_state.duplicate(true)
	if not storage_envelope_valid(stored_state):
		return {}
	var compressed := _z85_decode(
		str(stored_state.get(STORAGE_DATA_KEY, "")),
		int(stored_state.get(STORAGE_COMPRESSED_SIZE_KEY, 0))
	)
	if compressed.is_empty():
		return {}
	var source := compressed.decompress(int(stored_state.get(STORAGE_SIZE_KEY, 0)), FileAccess.COMPRESSION_ZSTD)
	if source.size() != int(stored_state.get(STORAGE_SIZE_KEY, 0)) \
			or _sha256(source) != str(stored_state.get(STORAGE_HASH_KEY, "")):
		return {}
	var json := JSON.new()
	if json.parse(source.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return (json.data as Dictionary).duplicate(true)


static func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(bytes)
	return context.finish().hex_encode()


static func _z85_encode(source: PackedByteArray) -> String:
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
	var encoded := encoded_text.to_ascii_buffer()
	if encoded.is_empty() or encoded.size() % 5 != 0 or expected_size <= 0:
		return PackedByteArray()
	var alphabet := Z85_ALPHABET.to_ascii_buffer()
	var decoded := PackedByteArray()
	decoded.resize((encoded.size() / 5) * 4)
	for group in range(encoded.size() / 5):
		var value := 0
		for digit_index in range(5):
			var digit := alphabet.find(encoded[group * 5 + digit_index])
			if digit < 0:
				return PackedByteArray()
			value = value * 85 + digit
		for offset in range(4):
			decoded[group * 4 + offset] = (value >> ((3 - offset) * 8)) & 0xff
	if expected_size > decoded.size():
		return PackedByteArray()
	decoded.resize(expected_size)
	return decoded


static func _encode_value(value: Variant, registry: Dictionary, fingerprints: Dictionary, inside_environment: bool) -> Variant:
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
				encoded_dict[key_value] = _encode_exact_integers(child) if key.begins_with("scenario_") or key in EXACT_INTEGER_ROOT_KEYS else _encode_value(child, registry, fingerprints, inside_environment)
		return encoded_dict
	if typeof(value) == TYPE_ARRAY:
		var source_array: Array = value
		var encoded_array: Array = []
		for index in range(source_array.size()):
			encoded_array.append(_encode_value(source_array[index], registry, fingerprints, inside_environment))
		return encoded_array
	return value


static func _encode_environment_reference(environment: Dictionary, registry: Dictionary, fingerprints: Dictionary) -> Dictionary:
	var encoded_value: Variant = _encode_value(environment, registry, fingerprints, true)
	var encoded: Dictionary = encoded_value as Dictionary if typeof(encoded_value) == TYPE_DICTIONARY else {}
	_compact_slot_game_states(encoded)
	var fingerprint := str(hash(encoded))
	var candidate_refs: Array = fingerprints.get(fingerprint, []) if typeof(fingerprints.get(fingerprint, [])) == TYPE_ARRAY else []
	for candidate_ref_value in candidate_refs:
		var candidate_ref := str(candidate_ref_value)
		if registry.get(candidate_ref, {}) == encoded:
			return {ENVIRONMENT_REF_KEY: candidate_ref}
	var base_ref := str(environment.get("id", "environment")).strip_edges()
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


static func _encode_seeded_scenario_definitions(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for node_id_value in source.keys():
		var node_id := str(node_id_value)
		var definition_value: Variant = source.get(node_id_value)
		if typeof(definition_value) != TYPE_DICTIONARY:
			result[node_id_value] = definition_value
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
# float. Dynamic scenario, mounted world-sequence, and delivery depth authority
# validate exact typed envelopes, so preserve integer identity recursively for
# those root-owned save fields.
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
	return value


static func _looks_like_environment(value: Dictionary) -> bool:
	return value.has("id") and value.has("game_states") and (value.has("archetype_id") or value.has("kind"))
