class_name RngStream
extends RefCounted

# Deterministic RNG stream for foundation simulation.

const MODULUS := 2147483647
const MULTIPLIER := 48271

var seed_value: int = 1
var state_value: int = 1


# Sets the seed and optional stream state.
func configure(p_seed: int, p_state: Variant = null) -> void:
	seed_value = _normalize(p_seed)
	if p_state == null:
		state_value = seed_value
	else:
		state_value = _normalize(int(p_state))


# Restores the stream from a snapshot dictionary.
func restore(data: Dictionary) -> void:
	var restored_seed := int(data.get("seed", seed_value))
	var restored_state := int(data.get("state", restored_seed))
	configure(restored_seed, restored_state)


# Creates an independent deterministic stream from this stream and a key.
func fork(stream_key: String) -> RngStream:
	var child := RngStream.new()
	child.configure(derive_seed(seed_value, state_value, stream_key))
	return child


# Returns a deterministic integer inside the inclusive range.
func randi_range(min_value: int, max_value: int) -> int:
	if max_value < min_value:
		var previous_min := min_value
		min_value = max_value
		max_value = previous_min
	var span := max_value - min_value + 1
	var value := _next()
	return min_value + (value % span)


# Picks one value from an array or returns a fallback.
func pick(values: Array, fallback: Variant = null) -> Variant:
	if values.is_empty():
		return fallback
	return values[self.randi_range(0, values.size() - 1)]


# Picks unique values from an array.
func pick_many(values: Array, count: int) -> Array:
	var pool: Array = values.duplicate(true)
	var picks: Array = []
	var target_count := maxi(0, count)
	while not pool.is_empty() and picks.size() < target_count:
		var index := self.randi_range(0, pool.size() - 1)
		picks.append(pool[index])
		pool.remove_at(index)
	return picks


# Returns the current seed and state.
func snapshot() -> Dictionary:
	return {
		"seed": seed_value,
		"state": state_value,
	}


# Advances the RNG stream once.
func _next() -> int:
	state_value = int((state_value * MULTIPLIER) % MODULUS)
	return state_value


# Keeps seed values inside the generator range.
static func _normalize(value: int) -> int:
	var normalized: int = abs(value) % MODULUS
	if normalized == 0:
		return 1
	return normalized


# Derives a deterministic seed for named streams without using engine globals.
static func derive_seed(base_seed: int, base_state: int, stream_key: String) -> int:
	var value := _normalize(base_seed)
	var text := "%s|%s|%s" % [base_seed, base_state, stream_key]
	for index in range(text.length()):
		value = value ^ text.unicode_at(index)
		value = int((value * MULTIPLIER) % MODULUS)
	return _normalize(value)
