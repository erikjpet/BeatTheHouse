class_name MetaCollectionService
extends RefCounted

const CollectionItemResolverScript := preload("res://scripts/core/collection_item_resolver.gd")

const STORE_PATH := "user://meta_collection.json"
const STORE_PATH_ENV := "BTH_META_COLLECTION_PATH"
const SCHEMA_VERSION := 1
const FIRST_INSTANCE_ID := 1

var _store: Dictionary = {}


func _init() -> void:
	_store = _default_store()


func load() -> Dictionary:
	var path := store_path()
	if not FileAccess.file_exists(path):
		_store = _default_store()
		return snapshot()
	var text := FileAccess.get_file_as_string(path)
	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK:
		_store = _default_store()
		return snapshot()
	var parsed: Variant = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		_store = _default_store()
		return snapshot()
	var data: Dictionary = parsed
	_store = _normalize_store(data)
	return snapshot()


func save() -> Error:
	_store = _normalize_store(_store)
	var path := store_path()
	var absolute_path := ProjectSettings.globalize_path(path)
	var directory := absolute_path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK:
		return directory_error
	var temp_path := "%s.tmp" % absolute_path
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(_store, "\t"))
	file.close()
	if FileAccess.file_exists(absolute_path):
		var remove_error := DirAccess.remove_absolute(absolute_path)
		if remove_error != OK:
			return remove_error
	return DirAccess.rename_absolute(temp_path, absolute_path)


func grant_instance(instance: Dictionary) -> Dictionary:
	_store = _normalize_store(_store)
	var normalized := CollectionItemResolverScript.normalize_instance(instance)
	var instance_id := _take_next_instance_id()
	normalized["schema_version"] = SCHEMA_VERSION
	normalized["instance_id"] = instance_id
	var instances := _copy_array(_store.get("owned_instances", []))
	instances.append(normalized)
	_store["owned_instances"] = instances
	return normalized.duplicate(true)


func grant_bag(bagdef_id: int, rng_seed: String = "") -> Dictionary:
	_store = _normalize_store(_store)
	var bag := {
		"schema_version": SCHEMA_VERSION,
		"instance_id": _take_next_instance_id(),
		"bagdef_id": bagdef_id,
		"rng_seed": rng_seed,
	}
	var bags := _copy_array(_store.get("unopened_bags", []))
	bags.append(bag)
	_store["unopened_bags"] = bags
	return bag.duplicate(true)


func owned_instances() -> Array:
	_store = _normalize_store(_store)
	return _copy_array(_store.get("owned_instances", []))


func remove_instance(instance_id: int) -> bool:
	_store = _normalize_store(_store)
	var instances := _copy_array(_store.get("owned_instances", []))
	var next_instances: Array = []
	var removed := false
	for instance_value in instances:
		var instance := _copy_dict(instance_value)
		if int(instance.get("instance_id", -1)) == instance_id:
			removed = true
			continue
		next_instances.append(instance)
	_store["owned_instances"] = next_instances
	return removed


func add_gold(amount: int) -> int:
	_store = _normalize_store(_store)
	_store["gold_balance"] = maxi(0, int(_store.get("gold_balance", 0)) + amount)
	return int(_store.get("gold_balance", 0))


func snapshot() -> Dictionary:
	_store = _normalize_store(_store)
	return _store.duplicate(true)


static func store_path() -> String:
	var override := OS.get_environment(STORE_PATH_ENV).strip_edges()
	if not override.is_empty():
		return override
	return STORE_PATH


func _take_next_instance_id() -> int:
	var next_id := maxi(FIRST_INSTANCE_ID, int(_store.get("next_instance_id", FIRST_INSTANCE_ID)))
	_store["next_instance_id"] = next_id + 1
	return next_id


func _normalize_store(data: Dictionary) -> Dictionary:
	var normalized := data.duplicate(true)
	normalized["schema_version"] = SCHEMA_VERSION
	normalized["owned_instances"] = _normalized_instances(normalized.get("owned_instances", []))
	normalized["unopened_bags"] = _normalized_bags(normalized.get("unopened_bags", []))
	normalized["gold_balance"] = maxi(0, int(normalized.get("gold_balance", 0)))
	normalized["loadout"] = _copy_array(normalized.get("loadout", []))
	normalized["meta_home"] = _copy_dict(normalized.get("meta_home", {}))
	normalized["trade_up_history"] = _copy_array(normalized.get("trade_up_history", []))
	normalized["sale_history"] = _copy_array(normalized.get("sale_history", []))
	normalized["next_instance_id"] = maxi(
		maxi(FIRST_INSTANCE_ID, int(normalized.get("next_instance_id", FIRST_INSTANCE_ID))),
		_max_recorded_instance_id(normalized) + 1
	)
	return normalized


func _normalized_instances(value: Variant) -> Array:
	var normalized: Array = []
	for instance_value in _copy_array(value):
		var instance := CollectionItemResolverScript.normalize_instance(_copy_dict(instance_value))
		if int(instance.get("itemdef_id", -1)) < 0:
			continue
		normalized.append(instance)
	return normalized


func _normalized_bags(value: Variant) -> Array:
	var normalized: Array = []
	for bag_value in _copy_array(value):
		var bag := _copy_dict(bag_value)
		var bagdef_id := int(bag.get("bagdef_id", -1))
		if bagdef_id < 0:
			continue
		bag["schema_version"] = int(bag.get("schema_version", SCHEMA_VERSION))
		bag["instance_id"] = maxi(0, int(bag.get("instance_id", 0)))
		bag["bagdef_id"] = bagdef_id
		bag["rng_seed"] = str(bag.get("rng_seed", ""))
		normalized.append(bag)
	return normalized


func _max_recorded_instance_id(data: Dictionary) -> int:
	var max_id := 0
	for instance_value in _copy_array(data.get("owned_instances", [])):
		var instance := _copy_dict(instance_value)
		max_id = maxi(max_id, int(instance.get("instance_id", 0)))
	for bag_value in _copy_array(data.get("unopened_bags", [])):
		var bag := _copy_dict(bag_value)
		max_id = maxi(max_id, int(bag.get("instance_id", 0)))
	return max_id


func _default_store() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"owned_instances": [],
		"unopened_bags": [],
		"gold_balance": 0,
		"loadout": [],
		"meta_home": {},
		"trade_up_history": [],
		"sale_history": [],
		"next_instance_id": FIRST_INSTANCE_ID,
	}


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
