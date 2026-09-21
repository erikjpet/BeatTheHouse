extends SceneTree

const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")
const StaticDataCacheScript := preload("res://scripts/core/static_data_cache.gd")
const CollectionItemResolverScript := preload("res://scripts/core/collection_item_resolver.gd")

var failures: Array[String] = []
var _loader_calls := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_json_coerce()
	_check_static_data_cache()
	_check_collection_definition_cache()
	if failures.is_empty():
		print("HEALTH06_1_SHARED_PRIMITIVES PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_json_coerce() -> void:
	var source := {"nested": {"value": 7}}
	var copied := JsonCoerceScript._copy_dict(source)
	(copied.get("nested", {}) as Dictionary)["value"] = 9
	_expect(int((source.get("nested", {}) as Dictionary).get("value", 0)) == 7, "CH-29: dictionary coercion did not deep-copy.")
	_expect(JsonCoerceScript._copy_array([{"value": 1}]) == [{"value": 1}], "CH-29: array coercion changed valid content.")
	_expect(JsonCoerceScript._dictionary_array([{"id": 1}, "bad"]) == [{"id": 1}], "CH-29: dictionary-array coercion did not filter malformed entries.")
	_expect(JsonCoerceScript._string_array([" alpha ", "", "alpha", "beta"]) == ["alpha", "alpha", "beta"], "CH-29: canonical string-array normalization did not preserve authored multiplicity.")
	_expect(JsonCoerceScript._string_array([" alpha ", "", "alpha", "beta"], true) == ["alpha", "beta"], "CH-29: opt-in unique string-array normalization failed.")
	_expect(JsonCoerceScript._raw_string_array([" alpha ", "", "alpha"]) == [" alpha ", "alpha"], "CH-29: whitespace-preserving string-array policy changed authored values.")
	_expect(JsonCoerceScript._literal_string_array(["", "alpha"]) == ["", "alpha"], "CH-29: empty-preserving string-array policy changed authored values.")
	_expect(JsonCoerceScript._unique_string_array([" alpha ", "alpha", "beta"]) == ["alpha", "beta"], "CH-29: shared unique string-array policy failed.")
	_expect(JsonCoerceScript._int_array(["1", 2, 3.9]) == [1, 2, 3], "CH-29: integer-array coercion changed conversion semantics.")
	_expect(JsonCoerceScript._stable_hash("beat-the-house") == JsonCoerceScript._stable_hash("beat-the-house") and JsonCoerceScript._stable_hash("beat-the-house") > 0, "CH-29: stable hash is not deterministic and positive.")
	_expect(JsonCoerceScript._utf8_stable_hash("café") == _legacy_utf8_hash("café"), "CH-29: UTF-8 stable-hash compatibility changed.")
	_expect(JsonCoerceScript._overflow_stable_hash("beat-the-house") == _legacy_overflow_hash("beat-the-house"), "CH-29: overflow stable-hash compatibility changed.")
	_expect(JsonCoerceScript._valid_sha256("a".repeat(64)) and not JsonCoerceScript._valid_sha256("A".repeat(64)), "CH-29: SHA-256 validation did not enforce lowercase hexadecimal.")


func _check_static_data_cache() -> void:
	StaticDataCacheScript.clear_all()
	_loader_calls = 0
	var first: Dictionary = StaticDataCacheScript.get_or_load("fixture:a", Callable(self, "_load_fixture"), 2)
	var second: Dictionary = StaticDataCacheScript.get_or_load("fixture:a", Callable(self, "_load_fixture"), 2)
	_expect(_loader_calls == 1 and first == second, "CH-11: repeated cache reads invoked the loader more than once.")
	first["mutated"] = true
	var isolated: Dictionary = StaticDataCacheScript.get_or_load("fixture:a", Callable(self, "_load_fixture"), 2)
	_expect(not isolated.has("mutated"), "CH-11: cache callers can mutate the stored value.")
	StaticDataCacheScript.get_or_load("fixture:b", Callable(self, "_load_fixture"), 2)
	StaticDataCacheScript.get_or_load("fixture:c", Callable(self, "_load_fixture"), 2)
	_expect(StaticDataCacheScript.size() == 2 and not StaticDataCacheScript.has("fixture:a"), "CH-11: static data cache is not bounded by LRU eviction.")


func _check_collection_definition_cache() -> void:
	CollectionItemResolverScript.debug_clear_definition_cache()
	var first := CollectionItemResolverScript.new()
	var second := CollectionItemResolverScript.new()
	_expect(not first.collections().is_empty() and first.collections() == second.collections(), "CH-11: cached collection definitions changed across resolver instances.")
	_expect(CollectionItemResolverScript.debug_definition_parse_count() == 1, "CH-11: multiple resolver instances reparsed collections.json.")


func _load_fixture(key: String) -> Dictionary:
	_loader_calls += 1
	return {"key": key, "call": _loader_calls}


func _legacy_utf8_hash(value: String) -> int:
	var hash_value := 2166136261
	for byte in value.to_utf8_buffer():
		hash_value = int((hash_value ^ int(byte)) * 16777619) & 0x7fffffff
	return hash_value


func _legacy_overflow_hash(value: String) -> int:
	var hash_value := 2166136261
	for index in range(value.length()):
		hash_value = int((hash_value ^ value.unicode_at(index)) * 16777619)
	return abs(hash_value) if hash_value != 0 else 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
