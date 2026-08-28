class_name RunSaveCodec
extends RefCounted

# Save-only projection. Runtime dictionaries keep their full authored state;
# persisted data deduplicates identical environments and omits slot definition
# arrays that are reconstructed from stable machine IDs by SlotGame.

const CODEC_VERSION := 2
const ENVIRONMENT_REF_KEY := "__bth_environment_ref"
const REGISTRY_KEY := "environment_registry"
const CODEC_KEY := "run_save_codec_version"
const EXACT_INT_KEY := "__bth_exact_int64"
const SLOT_DEFINITION_KEYS := ["reel_strips", "bonus_reel_strips"]
const SLOT_DUPLICATE_PRESENTATION_KEYS := ["slot_reel_timeline", "slot_reel_stop_times"]


static func encode(runtime_state: Dictionary) -> Dictionary:
	var registry: Dictionary = {}
	var fingerprints: Dictionary = {}
	var encoded_value: Variant = _encode_value(runtime_state, registry, fingerprints, false)
	var encoded: Dictionary = encoded_value as Dictionary if typeof(encoded_value) == TYPE_DICTIONARY else {}
	encoded[CODEC_KEY] = CODEC_VERSION
	encoded[REGISTRY_KEY] = registry
	return encoded


static func decode(saved_state: Dictionary) -> Dictionary:
	if int(saved_state.get(CODEC_KEY, 0)) <= 0:
		return saved_state.duplicate(true)
	var registry_value: Variant = saved_state.get(REGISTRY_KEY, {})
	var registry: Dictionary = registry_value as Dictionary if typeof(registry_value) == TYPE_DICTIONARY else {}
	var root: Dictionary = saved_state.duplicate(false)
	root.erase(CODEC_KEY)
	root.erase(REGISTRY_KEY)
	var decoded: Variant = _decode_value(root, registry)
	return decoded as Dictionary if typeof(decoded) == TYPE_DICTIONARY else {}


static func _encode_value(value: Variant, registry: Dictionary, fingerprints: Dictionary, inside_environment: bool) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var source: Dictionary = value
		if not inside_environment and _looks_like_environment(source):
			return _encode_environment_reference(source, registry, fingerprints)
		var encoded_dict: Dictionary = {}
		for key_value in source.keys():
			var key := str(key_value)
			var child: Variant = source.get(key_value)
			encoded_dict[key_value] = _encode_exact_integers(child) if key.begins_with("scenario_") else _encode_value(child, registry, fingerprints, inside_environment)
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


# JSON has one numeric type and otherwise changes every persisted integer into a
# float. Dynamic scenario authority hashes exact typed envelopes, so preserve
# integer identity recursively for every scenario-owned save field.
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
