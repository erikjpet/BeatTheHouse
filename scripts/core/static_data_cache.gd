class_name StaticDataCache
extends RefCounted

# Process-local bounded LRU for immutable parsed/static source data.

static var _entries: Dictionary = {}
static var _order: Array[String] = []


static func get_or_load(key: String, loader: Callable, max_entries: int = 8) -> Variant:
	var clean_key := key.strip_edges()
	if clean_key.is_empty() or not loader.is_valid():
		return null
	if _entries.has(clean_key):
		_touch(clean_key)
		return _copy_value(_entries.get(clean_key))
	var loaded: Variant = loader.call(clean_key)
	_entries[clean_key] = _copy_value(loaded)
	_touch(clean_key)
	_trim(maxi(1, max_entries))
	return _copy_value(loaded)


static func erase(key: String) -> void:
	var clean_key := key.strip_edges()
	_entries.erase(clean_key)
	_order.erase(clean_key)


static func clear_all() -> void:
	_entries.clear()
	_order.clear()


static func has(key: String) -> bool:
	return _entries.has(key.strip_edges())


static func size() -> int:
	return _entries.size()


static func _touch(key: String) -> void:
	_order.erase(key)
	_order.append(key)


static func _trim(max_entries: int) -> void:
	while _order.size() > max_entries:
		_entries.erase(_order.pop_front())


static func _copy_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return value
