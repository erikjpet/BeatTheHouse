extends RefCounted

# Storage-local numeric conversion. JSON still owns structure, escapes, duplicate
# keys and its historical extended grammar. No persisted markers or global hooks.
const LIMB_BITS := 26
const LIMB_BASE := 1 << LIMB_BITS
const LIMB_MASK := LIMB_BASE - 1
const INF_BITS := 0x7ff0000000000000
const FRACTION_MASK := 0x000fffffffffffff
const HIDDEN_BIT := 0x0010000000000000
const EXACT_INTEGER_LIMIT := 9007199254740992
const DIGIT_LIMIT := 768
const CACHE_LIMIT := 4096
const NUMBER_PREFIX := "~bth-json-number:"
const ZERO_PREFIX := "~bth-json-negative-zero:"


static func parse(text: String) -> Dictionary:
	var native := JSON.new()
	var error := native.parse(text)
	if error != OK:
		return {"error": error, "data": null}
	var context := {"powers": [PackedInt64Array([1])], "cache": {}}
	var replacements: Dictionary = {}
	var occupied: Dictionary = {}
	var pieces := PackedStringArray()
	var copy_from := 0
	var index := 0
	var next_id := 0
	while index < text.length():
		var code := text.unicode_at(index)
		if code == 0:
			break # Preserve the native parser's terminator behavior.
		if code == 34:
			index += 1
			while index < text.length():
				var quoted := text.unicode_at(index)
				index += 1
				if quoted == 92:
					index += 1
				elif quoted == 34:
					break
			continue
		if code != 45 and not _digit(code):
			index += 1
			continue
		var end := index + 1
		while end < text.length() and text[end] in "0123456789+-.eE":
			end += 1
		var token := text.substr(index, end - index)
		var approximate := token.to_float()
		var corrected: float
		if context.cache.has(token):
			corrected = context.cache[token]
		else:
			corrected = _number(token, approximate, context)
			if context.cache.size() < CACHE_LIMIT:
				context.cache[token] = corrected
		if _bits(corrected) != _bits(approximate):
			if replacements.is_empty():
				occupied = _occupied_number_strings(native.data)
			var marker := NUMBER_PREFIX + str(next_id) + "~"
			while occupied.has(marker):
				next_id += 1
				marker = NUMBER_PREFIX + str(next_id) + "~"
			next_id += 1
			replacements[marker] = corrected
			pieces.append(text.substr(copy_from, index - copy_from))
			pieces.append(JSON.stringify(marker))
			copy_from = end
		index = end
	if replacements.is_empty():
		return {"error": OK, "data": native.data}
	pieces.append(text.substr(copy_from))
	# Only corrected number tokens change, after the original grammar passed.
	# Occupancy is checked against decoded live strings, including escaped text.
	# The second native parse preserves duplicate-key and string behavior.
	native.data = null
	var rewritten := JSON.new()
	error = rewritten.parse("".join(pieces))
	if error != OK:
		return {"error": error, "data": null}
	var result: Variant = rewritten.data
	if typeof(result) == TYPE_STRING and replacements.has(result):
		result = replacements[result]
	else:
		_restore_numbers(result, replacements)
	return {"error": OK, "data": result}


static func stringify(value: Variant, byte_limit: int = 33554432) -> String:
	var original := JSON.stringify(value, "", true, true)
	# Return oversized native text to the codec's unchanged limit/error path.
	if original.to_utf8_buffer().size() > byte_limit:
		return original
	if not _has_negative_zero(value, original.length()):
		return original
	var occupied: Dictionary = {}
	var offset := 0
	while offset < original.length():
		var found := original.find(ZERO_PREFIX, offset)
		if found < 0:
			break
		var start := found + ZERO_PREFIX.length()
		var end := start
		while end < original.length() and _digit(original.unicode_at(end)):
			end += 1
		if end > start and end - start <= 8 and end < original.length() and original[end] == "~":
			occupied[original.substr(start, end - start)] = true
		offset = maxi(end, start)
	var marker_id := 0
	while occupied.has(str(marker_id)):
		marker_id += 1
	var marker := ZERO_PREFIX + str(marker_id) + "~"
	var pending: Array = []
	var count := [0]
	var projected: Variant = _zero_shell(value, marker, count, pending)
	var visited := 0
	while not pending.is_empty():
		visited += 1
		if visited > original.length():
			return "" # Cyclic/non-DTO input cannot cause an unbounded walk.
		var frame: Array = pending.pop_back()
		var source: Variant = frame[0]
		var target: Variant = frame[1]
		if typeof(source) == TYPE_DICTIONARY:
			for key in source:
				target[key] = _zero_shell(source[key], marker, count, pending)
		else:
			target.resize(source.size())
			for item in range(source.size()):
				target[item] = _zero_shell(source[item], marker, count, pending)
	var encoded := JSON.stringify(projected, "", true, true)
	var quoted := JSON.stringify(marker)
	# A changing unsupported object's stringification must not overwrite data.
	if original.contains(quoted) or encoded.count(quoted) != count[0]:
		return ""
	return encoded.replace(quoted, "-0.0")


static func _occupied_number_strings(value: Variant) -> Dictionary:
	var occupied: Dictionary = {}
	var pending: Array = [value]
	while not pending.is_empty():
		var item: Variant = pending.pop_back()
		if typeof(item) == TYPE_STRING:
			if item.begins_with(NUMBER_PREFIX):
				occupied[item] = true
		elif typeof(item) == TYPE_DICTIONARY:
			for key in item:
				pending.append(item[key])
		elif typeof(item) == TYPE_ARRAY:
			pending.append_array(item)
	return occupied


static func _restore_numbers(value: Variant, replacements: Dictionary) -> void:
	var pending: Array = [value]
	while not pending.is_empty():
		var item: Variant = pending.pop_back()
		if typeof(item) == TYPE_DICTIONARY:
			for key in item:
				var child: Variant = item[key]
				if typeof(child) == TYPE_STRING and replacements.has(child):
					item[key] = replacements[child]
				elif typeof(child) in [TYPE_DICTIONARY, TYPE_ARRAY]:
					pending.append(child)
		elif typeof(item) == TYPE_ARRAY:
			for index in range(item.size()):
				var child: Variant = item[index]
				if typeof(child) == TYPE_STRING and replacements.has(child):
					item[index] = replacements[child]
				elif typeof(child) in [TYPE_DICTIONARY, TYPE_ARRAY]:
					pending.append(child)


static func _has_negative_zero(value: Variant, max_nodes: int) -> bool:
	var pending: Array = [value]
	var visited := 0
	while not pending.is_empty() and visited <= max_nodes:
		var item: Variant = pending.pop_back()
		visited += 1
		if typeof(item) == TYPE_FLOAT:
			if item == 0.0 and _bits(item) < 0:
				return true
		elif typeof(item) == TYPE_DICTIONARY:
			for key in item:
				pending.append(item[key])
		elif typeof(item) in [TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY]:
			for child in item:
				pending.append(child)
	return false


static func _zero_shell(value: Variant, marker: String, count: Array, pending: Array) -> Variant:
	if typeof(value) == TYPE_FLOAT and value == 0.0 and _bits(value) < 0:
		count[0] += 1
		return marker
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		pending.append([value, result])
		return result
	if typeof(value) in [TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY]:
		var result: Array = []
		pending.append([value, result])
		return result
	return value


static func _number(token: String, approximate: float, context: Dictionary) -> float:
	var length := token.length()
	var negative := token.begins_with("-")
	var start := 1 if negative else 0
	var index := start
	if index >= length or not _digit(token.unicode_at(index)):
		return approximate # Native extended spellings retain their old semantics.
	if token[index] == "0":
		index += 1
		if index < length and _digit(token.unicode_at(index)):
			return approximate
	else:
		while index < length and _digit(token.unicode_at(index)):
			index += 1
	var integer_end := index
	var fraction_start := index
	if index < length and token[index] == ".":
		index += 1
		fraction_start = index
		while index < length and _digit(token.unicode_at(index)):
			index += 1
		if index == fraction_start:
			return approximate
	var mantissa_end := index
	var fractional_digits := index - fraction_start if fraction_start > integer_end else 0
	var decimal_exponent := 0
	if index < length and token[index] in "eE":
		index += 1
		var exponent_negative := index < length and token[index] == "-"
		if index < length and token[index] in "+-":
			index += 1
		var exponent_start := index
		while index < length and _digit(token.unicode_at(index)):
			decimal_exponent = mini(decimal_exponent * 10 + token.unicode_at(index) - 48, length + 4096)
			index += 1
		if index == exponent_start:
			return approximate
		if exponent_negative:
			decimal_exponent = -decimal_exponent
	if index != length:
		return approximate
	var raw_digits := token.substr(start, integer_end - start)
	if fraction_start > integer_end:
		raw_digits += token.substr(fraction_start, mantissa_end - fraction_start)
	var raw_exponent := decimal_exponent - fractional_digits
	# An exact coefficient and exact power of ten perform one rounding in the
	# native converter. Leading/trailing digits must not trigger its 18-digit cut.
	if raw_digits.length() <= 18 and absi(raw_exponent) <= 22:
		var coefficient := raw_digits.to_int()
		var reduced := coefficient
		var shift := 0
		while reduced > EXACT_INTEGER_LIMIT:
			reduced >>= 1
			shift += 1
		if (coefficient & ((1 << shift) - 1)) == 0:
			return approximate
	var first := 0
	while first < raw_digits.length() and raw_digits[first] == "0":
		first += 1
	if first == raw_digits.length():
		return _float_bits(0, negative)
	var last := raw_digits.length()
	while raw_digits[last - 1] == "0":
		last -= 1
	var exponent := raw_exponent + raw_digits.length() - last
	var digits := raw_digits.substr(first, last - first)
	var order := digits.length() - 1 + exponent
	if order > 308:
		return _float_bits(INF_BITS, negative)
	if order < -324:
		return _float_bits(0, negative)
	var sticky := digits.length() > DIGIT_LIMIT
	if sticky:
		exponent += digits.length() - DIGIT_LIMIT
		digits = digits.substr(0, DIGIT_LIMIT)
	var numerator := _from_digits(digits)
	var denominator := PackedInt64Array([1])
	if exponent >= 0:
		numerator = _multiply(numerator, _power5(exponent, context))
	else:
		denominator = _power5(-exponent, context)
	var ratio := {"n": numerator, "d": denominator, "e": exponent, "sticky": sticky}
	var candidate := 0 if is_nan(approximate) else (_bits(absf(approximate)) & 0x7fffffffffffffff)
	candidate = mini(candidate, INF_BITS)
	for _attempt in range(4):
		if candidate > 0:
			var lower := _compare_upper(ratio, candidate - 1)
			if lower < 0 or (lower == 0 and (candidate & 1) != 0):
				candidate -= 1
				continue
		if candidate < INF_BITS:
			var upper := _compare_upper(ratio, candidate)
			if upper > 0 or (upper == 0 and (candidate & 1) != 0):
				candidate += 1
				continue
		return _float_bits(candidate, negative)
	# No assumption about the old parser's error bound, including underflow.
	var low := 0
	var high := INF_BITS
	while low < high:
		@warning_ignore("integer_division")
		var middle := low + (high - low) / 2
		var compared := _compare_upper(ratio, middle)
		if compared > 0 or (compared == 0 and (middle & 1) != 0):
			low = middle + 1
		else:
			high = middle
	return _float_bits(low, negative)


static func _compare_upper(ratio: Dictionary, bits: int) -> int:
	var field := bits >> 52
	var mantissa := (bits & FRACTION_MASK) | (HIDDEN_BIT if field > 0 else 0)
	var binary_exponent := field - 1076 if field > 0 else -1075
	var right := _multiply(_from_int(2 * mantissa + 1), ratio.d)
	var left: PackedInt64Array = ratio.n
	var delta := binary_exponent - int(ratio.e)
	if delta >= 0:
		right = _shift(right, delta)
	else:
		left = _shift(left, -delta)
	var compared := _compare(left, right)
	return 1 if compared == 0 and bool(ratio.sticky) else compared


static func _power5(exponent: int, context: Dictionary) -> PackedInt64Array:
	var powers: Array = context.powers
	while powers.size() <= exponent:
		powers.append(_small(powers[-1], 5))
	return powers[exponent]


static func _from_int(value: int) -> PackedInt64Array:
	var result := PackedInt64Array()
	while value > 0:
		result.append(value & LIMB_MASK)
		value >>= LIMB_BITS
	if result.is_empty():
		result.append(0)
	return result


static func _from_digits(digits: String) -> PackedInt64Array:
	var result := PackedInt64Array([0])
	for index in range(digits.length()):
		result = _small(result, 10, digits.unicode_at(index) - 48)
	return result


static func _small(value: PackedInt64Array, factor: int, carry: int = 0) -> PackedInt64Array:
	var result := PackedInt64Array()
	for limb in value:
		var product := limb * factor + carry
		result.append(product & LIMB_MASK)
		carry = product >> LIMB_BITS
	if carry > 0:
		result.append(carry)
	return result


static func _multiply(left: PackedInt64Array, right: PackedInt64Array) -> PackedInt64Array:
	var result := PackedInt64Array()
	result.resize(left.size() + right.size())
	for a in range(left.size()):
		var carry := 0
		for b in range(right.size()):
			var product := result[a + b] + left[a] * right[b] + carry
			result[a + b] = product & LIMB_MASK
			carry = product >> LIMB_BITS
		result[a + right.size()] = carry
	while result.size() > 1 and result[-1] == 0:
		result.resize(result.size() - 1)
	return result


static func _shift(value: PackedInt64Array, bits: int) -> PackedInt64Array:
	@warning_ignore("integer_division")
	var whole := bits / LIMB_BITS
	var part := bits % LIMB_BITS
	var result := PackedInt64Array()
	result.resize(value.size() + whole + 1)
	var carry := 0
	for index in range(value.size()):
		var shifted := (value[index] << part) | carry
		result[index + whole] = shifted & LIMB_MASK
		carry = shifted >> LIMB_BITS
	result[value.size() + whole] = carry
	while result.size() > 1 and result[-1] == 0:
		result.resize(result.size() - 1)
	return result


static func _compare(left: PackedInt64Array, right: PackedInt64Array) -> int:
	if left.size() != right.size():
		return -1 if left.size() < right.size() else 1
	for index in range(left.size() - 1, -1, -1):
		if left[index] != right[index]:
			return -1 if left[index] < right[index] else 1
	return 0


static func _digit(code: int) -> bool:
	return code >= 48 and code <= 57


static func _bits(value: float) -> int:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.decode_s64(0)


static func _float_bits(bits: int, negative: bool) -> float:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_s64(0, bits)
	if negative:
		bytes[7] |= 128
	return bytes.decode_double(0)
