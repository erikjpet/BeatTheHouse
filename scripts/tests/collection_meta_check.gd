extends SceneTree

const CollectionItemResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")

const TEST_STORE_PATH := "user://collection_meta_check_store.json"
const EXPECTED_TIER_COUNTS := {
	"blue": 4,
	"purple": 4,
	"pink": 3,
	"red": 2,
	"gold": 1,
}
const TIERS := ["blue", "purple", "pink", "red", "gold"]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var resolver: Variant = CollectionItemResolverScript.new()
	_test_collection_schema(resolver)
	_test_float_determinism(resolver)
	_test_usage_decay(resolver)
	_test_resolve_run_item(resolver)
	_test_store_round_trip(resolver)
	_finish()


func _test_collection_schema(resolver: Variant) -> void:
	var errors: Array = resolver.validate_definitions()
	for error in errors:
		failures.append(error)
	var collections: Array = resolver.collections()
	_check(collections.size() == 2, "Expected exactly 2 launch collections.")
	var used_itemdef_ids := {}
	var total_items := 0
	for collection_value in collections:
		var collection := _copy_dict(collection_value)
		var collection_id := str(collection.get("id", ""))
		var tier_counts := {}
		for tier in TIERS:
			tier_counts[tier] = 0
		var bag_tiers := {}
		for bag_value in _copy_array(collection.get("bag_defs", [])):
			var bag := _copy_dict(bag_value)
			var bag_tier := str(bag.get("tier", ""))
			var bag_itemdef_id := int(bag.get("itemdef_id", -1))
			bag_tiers[bag_tier] = true
			_check(bag_itemdef_id >= 9000, "Bag %s itemdef_id must be in the 9000s." % str(bag.get("id", "")))
			_check(not used_itemdef_ids.has(bag_itemdef_id), "Duplicate itemdef_id %d." % bag_itemdef_id)
			used_itemdef_ids[bag_itemdef_id] = true
		for tier in TIERS:
			_check(bag_tiers.has(tier), "Collection %s missing %s bag definition." % [collection_id, tier])
		for item_value in _copy_array(collection.get("items", [])):
			var item := _copy_dict(item_value)
			var itemdef_id := int(item.get("itemdef_id", -1))
			var tier := str(item.get("tier", ""))
			_check(not used_itemdef_ids.has(itemdef_id), "Duplicate itemdef_id %d." % itemdef_id)
			used_itemdef_ids[itemdef_id] = true
			if tier_counts.has(tier):
				tier_counts[tier] = int(tier_counts.get(tier, 0)) + 1
			total_items += 1
			_check(_item_float_bindings_are_known(item), "Item %s has an unknown float binding effect key." % str(item.get("id", "")))
		for tier in TIERS:
			_check(int(tier_counts.get(tier, 0)) == int(EXPECTED_TIER_COUNTS.get(tier, 0)), "Collection %s tier %s count mismatch." % [collection_id, tier])
	_check(total_items == 28, "Expected exactly 28 draft collection items.")


func _test_float_determinism(resolver: Variant) -> void:
	var first: Dictionary = resolver.roll_instance(1000, "determinism-seed")
	var second: Dictionary = resolver.roll_instance(1000, "determinism-seed")
	var different: Dictionary = resolver.roll_instance(1000, "determinism-seed-b")
	_check(JSON.stringify(first) == JSON.stringify(second), "Same seed did not produce identical collection item instance.")
	var variance_found := false
	for float_key in ["potency", "condition", "resonance", "usage"]:
		if absf(float(first.get(float_key, 0.0)) - float(different.get(float_key, 0.0))) > 0.000001:
			variance_found = true
		_check(float(first.get(float_key, -1.0)) >= 0.0 and float(first.get(float_key, -1.0)) <= 1.0, "Rolled float %s was outside [0,1]." % str(float_key))
	_check(variance_found, "Different seeds did not vary any rolled floats.")


func _test_usage_decay(resolver: Variant) -> void:
	var instance: Dictionary = resolver.roll_instance(1000, "decay-seed")
	instance["usage"] = 0.03
	var decayed: Dictionary = resolver.apply_usage_decay(instance, "failure-seed")
	_check(decayed.has("itemdef_id"), "Usage decay removed item identity.")
	_check(float(decayed.get("usage", 1.0)) <= float(instance.get("usage", 0.0)), "Usage decay was not monotonic.")
	_check(float(decayed.get("usage", -1.0)) >= 0.0, "Usage decay fell below zero.")
	var fresh: Dictionary = instance.duplicate(true)
	fresh["usage"] = 1.0
	var spent: Dictionary = instance.duplicate(true)
	spent["usage"] = 0.0
	var fresh_item: Dictionary = resolver.resolve_run_item(fresh)
	var spent_item: Dictionary = resolver.resolve_run_item(spent)
	var fresh_effect := _copy_dict(fresh_item.get("effect", {}))
	var spent_effect := _copy_dict(spent_item.get("effect", {}))
	_check(int(spent_effect.get("win_chance", 999)) < int(fresh_effect.get("win_chance", 0)), "Spent item potency was not dampened.")
	_check(float(spent_item.get("meta_value_multiplier", 1.0)) < float(fresh_item.get("meta_value_multiplier", 0.0)), "Spent item value multiplier did not bottom out.")


func _test_resolve_run_item(resolver: Variant) -> void:
	var instance: Dictionary = resolver.roll_instance(1013, "resolve-seed")
	var before_json := JSON.stringify(instance)
	var run_item: Dictionary = resolver.resolve_run_item(instance)
	_check(JSON.stringify(instance) == before_json, "resolve_run_item mutated the source instance.")
	for key in ["id", "display_name", "class", "domain", "content_groups", "sellable", "price_min", "price_max", "icon_key", "description", "effect"]:
		_check(run_item.has(key), "Resolved run item missing key %s." % str(key))
	_check(typeof(run_item.get("effect", {})) == TYPE_DICTIONARY, "Resolved run item effect must be a Dictionary.")
	var meta := _copy_dict(run_item.get("meta_collection", {}))
	_check(int(meta.get("itemdef_id", -1)) == 1013, "Resolved run item missing meta itemdef_id.")


func _test_store_round_trip(resolver: Variant) -> void:
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, TEST_STORE_PATH)
	_remove_user_file(TEST_STORE_PATH)
	var service: Variant = MetaCollectionServiceScript.new()
	var empty_store: Dictionary = service.load()
	_check(int(empty_store.get("schema_version", 0)) == MetaCollectionServiceScript.SCHEMA_VERSION, "Default store missing schema_version.")
	_check(int(empty_store.get("gold_balance", -1)) == 0, "Default gold balance must start at 0.")
	var granted: Dictionary = service.grant_instance(resolver.roll_instance(1000, "store-seed"))
	service.grant_bag(9000, "bag-seed")
	service.add_gold(17)
	var before_save: Dictionary = service.snapshot()
	var save_error: Error = service.save()
	_check(save_error == OK, "Meta collection store save failed with error %d." % int(save_error))
	var loaded_service: Variant = MetaCollectionServiceScript.new()
	var loaded: Dictionary = loaded_service.load()
	_check(JSON.stringify(before_save) == JSON.stringify(loaded), "Meta collection store did not round-trip identically.")
	_check(int(granted.get("instance_id", 0)) == 1, "First granted item did not receive monotonic instance id 1.")
	var removed: bool = loaded_service.remove_instance(1)
	_check(removed, "remove_instance did not remove the granted owned instance.")
	_check(loaded_service.owned_instances().is_empty(), "owned_instances still returned removed instance.")
	var corrupt_file := FileAccess.open(TEST_STORE_PATH, FileAccess.WRITE)
	if corrupt_file != null:
		corrupt_file.store_string("{corrupt")
		corrupt_file.close()
	var corrupt_service: Variant = MetaCollectionServiceScript.new()
	var corrupt_loaded: Dictionary = corrupt_service.load()
	_check(int(corrupt_loaded.get("schema_version", 0)) == MetaCollectionServiceScript.SCHEMA_VERSION, "Corrupt store did not normalize schema_version.")
	_check(_copy_array(corrupt_loaded.get("owned_instances", [])).is_empty(), "Corrupt store did not reset owned instances.")
	_check(int(corrupt_loaded.get("gold_balance", -1)) == 0, "Corrupt store did not reset gold balance.")
	_remove_user_file(TEST_STORE_PATH)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, "")


func _item_float_bindings_are_known(item: Dictionary) -> bool:
	var bindings := _copy_dict(item.get("float_bindings", {}))
	for binding_key in ["potency", "resonance"]:
		var binding := _copy_dict(bindings.get(binding_key, {}))
		var effect_key := str(binding.get("effect_key", ""))
		if not CollectionItemResolverScript.KNOWN_EFFECT_KEYS.has(effect_key):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("collection_meta_check: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("collection_meta_check: FAIL (%d failure(s))" % failures.size())
	quit(1)


func _remove_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var dictionary: Dictionary = value
	return dictionary.duplicate(true)


static func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var array: Array = value
	return array.duplicate(true)
