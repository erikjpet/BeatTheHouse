extends RefCounted

# Runtime-only compilation of an inactive room's durable projection. Neither
# the source receipt nor compiled output is exposed as a mutable alias.
var _source: Dictionary
var _projection: Dictionary
var _encoded_projection: Dictionary = {}
var retained_bytes := 0


static func compile(environment: Dictionary, projector: Callable, byte_budget: int) -> RefCounted:
	if _contains_opaque_value(environment):
		return null
	var source_bytes := var_to_bytes(environment).size()
	if source_bytes > byte_budget:
		return null
	var entry := new()
	entry._source = owned(environment)
	# The existing projector may reconcile its detached working envelope. Keep
	# that graph separate from both the live room and the exact source receipt.
	entry._projection = projector.call(owned(environment))
	entry.retained_bytes = source_bytes + var_to_bytes(entry._projection).size()
	if entry.retained_bytes > byte_budget:
		return null
	# Compile only plain container/scalar output. Dictionary.duplicate(true)
	# owns that graph in native code, while packed mutable leaves need the
	# original codec's explicit copying. Keep the same total cache budget.
	var codec: Script = load("res://scripts/core/run_save_codec.gd")
	var encoded: Dictionary = codec._encode_value(entry._projection, {}, {}, true)
	codec._compact_slot_game_states(encoded)
	if _plain_owned_json_graph(encoded):
		var encoded_bytes := var_to_bytes(encoded).size()
		if entry.retained_bytes + encoded_bytes <= byte_budget:
			entry._encoded_projection = encoded
			entry.retained_bytes += encoded_bytes
	return entry


static func _plain_owned_json_graph(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_DICTIONARY:
			for key in value:
				if typeof(key) != TYPE_STRING or not _plain_owned_json_graph(value[key]):
					return false
			return true
		TYPE_ARRAY:
			for child in value:
				if not _plain_owned_json_graph(child): return false
			return true
	return false


static func _contains_opaque_value(value: Variant) -> bool:
	if typeof(value) in [TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL]:
		return true
	if typeof(value) == TYPE_DICTIONARY:
		for key in value:
			if _contains_opaque_value(key) or _contains_opaque_value(value[key]):
				return true
	elif typeof(value) == TYPE_ARRAY:
		for child in value:
			if _contains_opaque_value(child):
				return true
	return false


func matches(environment: Dictionary) -> bool:
	# All fields participate, including game buffers, layers, source digests and
	# mutable aliases. A mismatch takes the original complete projection path.
	return environment == _source


func snapshot() -> Dictionary:
	return owned(_projection)


func encode_into(registry: Dictionary, fingerprints: Dictionary) -> Dictionary:
	# Only the canonical non-mutating codec sees this immutable graph. Never
	# return it or lend it to a caller-supplied callback. The codec owns every
	# resulting container/packed leaf before a generation can outlive this frame.
	var codec: Script = load("res://scripts/core/run_save_codec.gd")
	if not _encoded_projection.is_empty():
		return codec._register_encoded_environment_reference(_encoded_projection.duplicate(true), registry, fingerprints, str(_projection.get("id", "environment")))
	return codec._encode_environment_reference(_projection, registry, fingerprints)


static func owned(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for key in value:
				result[key] = owned(value[key])
			return result
		TYPE_ARRAY:
			var result: Array = []
			for child in value:
				result.append(owned(child))
			return result
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			return value.duplicate()
	return value
