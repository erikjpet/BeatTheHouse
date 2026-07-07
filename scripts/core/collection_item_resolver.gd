class_name CollectionItemResolver
extends RefCounted

const COLLECTIONS_PATH := "res://data/collections/collections.json"
const SCHEMA_VERSION := 1
const HASH_MODULUS := 4294967296
const INSTANCE_ID_BASE := 1000000
const INSTANCE_ID_SPAN := 900000000
const FLOAT_KEYS := ["potency", "condition", "resonance", "usage"]
const TIERS := ["blue", "purple", "pink", "red", "gold"]
const TIER_COUNTS := {
	"blue": 4,
	"purple": 4,
	"pink": 3,
	"red": 2,
	"gold": 1,
}
const KNOWN_EFFECT_KEYS := [
	"baseline_luck_delta",
	"win_chance",
	"win_bonus",
	"legal_win_chance",
	"loss_reduction",
	"cheat_suspicion_delta",
	"travel_scouting_level",
	"debt_grace_turns",
	"debt_default_heat_delta",
	"blackjack_peek_heat_delta",
	"blackjack_peek_loss_reduction",
	"baccarat_edge_sort_memory_tolerance",
	"slot_nudge_perfect_msec_bonus",
	"slot_cold_quarter_heat_reduction",
	"video_poker_holdout_heat_delta",
	"video_poker_holdout_perfect_msec",
	"slot_split_reel_note_perfect_msec_bonus",
	"roulette_past_post_base_heat",
	"blackjack_failed_peek_heat_absorb",
]

var _loaded := false
var _root: Dictionary = {}
var _collections: Array = []
var _items_by_itemdef_id: Dictionary = {}
var _bags_by_itemdef_id: Dictionary = {}
var _validation_errors: Array[String] = []


func load_definitions() -> void:
	_loaded = true
	_root = {}
	_collections = []
	_items_by_itemdef_id = {}
	_bags_by_itemdef_id = {}
	_validation_errors = []
	if not FileAccess.file_exists(COLLECTIONS_PATH):
		_validation_errors.append("Missing collection schema: %s" % COLLECTIONS_PATH)
		return
	var text := FileAccess.get_file_as_string(COLLECTIONS_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_ARRAY:
		var entries: Array = parsed
		if entries.is_empty():
			_validation_errors.append("Collection schema bundle is empty.")
			return
		_root = _copy_dict(entries[0])
	elif typeof(parsed) == TYPE_DICTIONARY:
		_root = _copy_dict(parsed)
	else:
		_validation_errors.append("Collection schema root must be an object or single-object array.")
		return
	_index_definitions()


func validate_definitions() -> Array[String]:
	_ensure_loaded()
	var errors: Array[String] = []
	for error in _validation_errors:
		errors.append(error)
	return errors


func collections() -> Array:
	_ensure_loaded()
	return _collections.duplicate(true)


func item_definitions() -> Array:
	_ensure_loaded()
	var items: Array = []
	for itemdef_id in _items_by_itemdef_id.keys():
		items.append(_copy_dict(_items_by_itemdef_id[itemdef_id]))
	return items


func item_definition(itemdef_id: int) -> Dictionary:
	_ensure_loaded()
	return _copy_dict(_items_by_itemdef_id.get(itemdef_id, {}))


func bag_definition(itemdef_id: int) -> Dictionary:
	_ensure_loaded()
	return _copy_dict(_bags_by_itemdef_id.get(itemdef_id, {}))


func roll_instance(itemdef_id: int, rng_seed: String) -> Dictionary:
	_ensure_loaded()
	var definition := item_definition(itemdef_id)
	if definition.is_empty():
		return {}
	var seed := "%s|%d" % [rng_seed, itemdef_id]
	var instance_id := INSTANCE_ID_BASE + (_hash_u32("%s|instance" % seed) % INSTANCE_ID_SPAN)
	return {
		"schema_version": SCHEMA_VERSION,
		"instance_id": instance_id,
		"itemdef_id": itemdef_id,
		"potency": _unit_float(seed, "potency"),
		"condition": _unit_float(seed, "condition"),
		"resonance": _unit_float(seed, "resonance"),
		"usage": clampf(0.82 + (_unit_float(seed, "usage") * 0.18), 0.0, 1.0),
	}


func apply_usage_decay(instance: Dictionary, rng_seed: String) -> Dictionary:
	_ensure_loaded()
	var next := normalize_instance(instance)
	var itemdef_id := int(next.get("itemdef_id", -1))
	var definition := item_definition(itemdef_id)
	if definition.is_empty():
		return next
	var usage_binding := _copy_dict(_copy_dict(definition.get("float_bindings", {})).get("usage", {}))
	var decay_min := maxf(0.0, float(usage_binding.get("decay_min", 0.02)))
	var decay_max := maxf(decay_min, float(usage_binding.get("decay_max", decay_min)))
	var decay := lerpf(decay_min, decay_max, _unit_float("%s|%d" % [rng_seed, itemdef_id], "usage_decay"))
	var current_usage := clampf(float(next.get("usage", 0.0)), 0.0, 1.0)
	next["usage"] = 0.0 if current_usage <= decay else clampf(current_usage - decay, 0.0, 1.0)
	return next


func resolve_run_item(instance: Dictionary) -> Dictionary:
	_ensure_loaded()
	var normalized := normalize_instance(instance)
	var itemdef_id := int(normalized.get("itemdef_id", -1))
	var definition := item_definition(itemdef_id)
	if definition.is_empty():
		return {}
	var band := condition_band(definition, normalized)
	var effect := _scaled_effect(definition, normalized)
	var instance_id := int(normalized.get("instance_id", 0))
	var item_id := str(definition.get("id", "collection_item"))
	var display_name := "%s (%s)" % [
		str(definition.get("display_name", "Collection Item")),
		str(band.get("display_name", "Unknown")),
	]
	return {
		"id": "meta_%s_%d" % [item_id, instance_id],
		"display_name": display_name,
		"class": "permanent",
		"domain": "global",
		"content_groups": ["meta_collection"],
		"sellable": false,
		"sale_price": 0,
		"price_min": 0,
		"price_max": 0,
		"icon_key": str(definition.get("icon_key", "")),
		"description": str(definition.get("flavor", "")),
		"effect": effect,
		"meta_collection": {
			"schema_version": SCHEMA_VERSION,
			"collection_id": str(definition.get("collection_id", "")),
			"itemdef_id": itemdef_id,
			"instance_id": instance_id,
			"tier": str(definition.get("tier", "")),
			"condition_band": str(band.get("id", "")),
		},
		"meta_value_multiplier": value_multiplier(definition, normalized),
	}


func condition_band(definition: Dictionary, instance: Dictionary) -> Dictionary:
	var condition := clampf(float(instance.get("condition", 0.0)), 0.0, 1.0)
	var condition_binding := _copy_dict(_copy_dict(definition.get("float_bindings", {})).get("condition", {}))
	var bands := _copy_array(condition_binding.get("bands", []))
	var fallback: Dictionary = {"id": "unknown", "display_name": "Unknown", "value_multiplier": 1.0}
	for band_value in bands:
		var band := _copy_dict(band_value)
		if band.is_empty():
			continue
		fallback = band
		var max_value := clampf(float(band.get("max", 1.0)), 0.0, 1.0)
		if condition <= max_value:
			return band
	return fallback


func value_multiplier(definition: Dictionary, instance: Dictionary) -> float:
	var condition_binding := _copy_dict(_copy_dict(definition.get("float_bindings", {})).get("condition", {}))
	var spent_value_multiplier := maxf(0.0, float(condition_binding.get("spent_value_multiplier", 0.08)))
	var usage := clampf(float(instance.get("usage", 0.0)), 0.0, 1.0)
	if usage <= 0.0:
		return spent_value_multiplier
	var band := condition_band(definition, instance)
	var condition_multiplier := maxf(0.0, float(band.get("value_multiplier", 1.0)))
	return snappedf(condition_multiplier * lerpf(spent_value_multiplier, 1.0, usage), 0.001)


static func normalize_instance(instance: Dictionary) -> Dictionary:
	var normalized := instance.duplicate(true)
	normalized["schema_version"] = int(normalized.get("schema_version", SCHEMA_VERSION))
	normalized["instance_id"] = maxi(0, int(normalized.get("instance_id", 0)))
	normalized["itemdef_id"] = int(normalized.get("itemdef_id", -1))
	for float_key in FLOAT_KEYS:
		normalized[float_key] = clampf(float(normalized.get(float_key, 0.0)), 0.0, 1.0)
	return normalized


func _ensure_loaded() -> void:
	if not _loaded:
		load_definitions()


func _index_definitions() -> void:
	if int(_root.get("schema_version", 0)) != SCHEMA_VERSION:
		_validation_errors.append("Collection schema_version must be %d." % SCHEMA_VERSION)
	if not bool(_root.get("draft", false)):
		_validation_errors.append("Collection schema must carry draft=true for P0 owner review.")
	var bundle_collections := _copy_array(_root.get("collections", []))
	if bundle_collections.size() != 2:
		_validation_errors.append("Collection schema must define exactly 2 launch collections.")
	var used_itemdef_ids := {}
	for collection_value in bundle_collections:
		var collection := _copy_dict(collection_value)
		var collection_id := str(collection.get("id", "")).strip_edges()
		if collection_id.is_empty():
			_validation_errors.append("Collection is missing id.")
			continue
		_index_collection(collection, collection_id, used_itemdef_ids)


func _index_collection(collection: Dictionary, collection_id: String, used_itemdef_ids: Dictionary) -> void:
	var items := _copy_array(collection.get("items", []))
	var bag_defs := _copy_array(collection.get("bag_defs", []))
	var tier_counts := {}
	var bag_tiers := {}
	for tier in TIERS:
		tier_counts[tier] = 0
	for bag_value in bag_defs:
		var bag := _copy_dict(bag_value)
		var bag_tier := str(bag.get("tier", "")).strip_edges()
		var bag_itemdef_id := int(bag.get("itemdef_id", -1))
		if not TIERS.has(bag_tier):
			_validation_errors.append("Bag %s has invalid tier '%s'." % [str(bag.get("id", "")), bag_tier])
		if bag_itemdef_id <= 0:
			_validation_errors.append("Bag %s is missing a positive itemdef_id." % str(bag.get("id", "")))
		elif used_itemdef_ids.has(bag_itemdef_id):
			_validation_errors.append("Duplicate itemdef_id %d." % bag_itemdef_id)
		else:
			used_itemdef_ids[bag_itemdef_id] = true
			bag["collection_id"] = collection_id
			_bags_by_itemdef_id[bag_itemdef_id] = bag
		bag_tiers[bag_tier] = true
	for tier in TIERS:
		if not bag_tiers.has(tier):
			_validation_errors.append("Collection %s is missing a %s bag definition." % [collection_id, tier])
	for item_value in items:
		var item := _copy_dict(item_value)
		var item_tier := str(item.get("tier", "")).strip_edges()
		var itemdef_id := int(item.get("itemdef_id", -1))
		if not TIERS.has(item_tier):
			_validation_errors.append("Item %s has invalid tier '%s'." % [str(item.get("id", "")), item_tier])
			continue
		tier_counts[item_tier] = int(tier_counts.get(item_tier, 0)) + 1
		if itemdef_id <= 0:
			_validation_errors.append("Item %s is missing a positive itemdef_id." % str(item.get("id", "")))
		elif used_itemdef_ids.has(itemdef_id):
			_validation_errors.append("Duplicate itemdef_id %d." % itemdef_id)
		else:
			used_itemdef_ids[itemdef_id] = true
			item["collection_id"] = collection_id
			_items_by_itemdef_id[itemdef_id] = item
		_validate_item_bindings(collection_id, item)
	for tier in TIERS:
		var expected := int(TIER_COUNTS.get(tier, 0))
		var actual := int(tier_counts.get(tier, 0))
		if actual != expected:
			_validation_errors.append("Collection %s tier %s count was %d, expected %d." % [collection_id, tier, actual, expected])
	_collections.append(collection)


func _validate_item_bindings(collection_id: String, item: Dictionary) -> void:
	var item_id := str(item.get("id", ""))
	var effect := _copy_dict(item.get("base_effect", {}))
	for effect_key in effect.keys():
		if not KNOWN_EFFECT_KEYS.has(str(effect_key)):
			_validation_errors.append("Collection %s item %s has unknown base effect key %s." % [collection_id, item_id, str(effect_key)])
	var bindings := _copy_dict(item.get("float_bindings", {}))
	for float_key in FLOAT_KEYS:
		if not bindings.has(float_key):
			_validation_errors.append("Collection %s item %s is missing %s binding." % [collection_id, item_id, str(float_key)])
	var potency := _copy_dict(bindings.get("potency", {}))
	var potency_key := str(potency.get("effect_key", ""))
	if potency_key.is_empty() or not KNOWN_EFFECT_KEYS.has(potency_key):
		_validation_errors.append("Collection %s item %s has unknown potency effect key %s." % [collection_id, item_id, potency_key])
	var resonance := _copy_dict(bindings.get("resonance", {}))
	var resonance_key := str(resonance.get("effect_key", ""))
	if resonance_key.is_empty() or not KNOWN_EFFECT_KEYS.has(resonance_key):
		_validation_errors.append("Collection %s item %s has unknown resonance effect key %s." % [collection_id, item_id, resonance_key])
	var usage := _copy_dict(bindings.get("usage", {}))
	var decay_min := float(usage.get("decay_min", -1.0))
	var decay_max := float(usage.get("decay_max", -1.0))
	if decay_min < 0.0 or decay_max < decay_min:
		_validation_errors.append("Collection %s item %s has invalid usage decay range." % [collection_id, item_id])


func _scaled_effect(definition: Dictionary, instance: Dictionary) -> Dictionary:
	var effect := _copy_dict(definition.get("base_effect", {}))
	var bindings := _copy_dict(definition.get("float_bindings", {}))
	var potency := _copy_dict(bindings.get("potency", {}))
	var effect_key := str(potency.get("effect_key", ""))
	if not effect_key.is_empty():
		var raw_value := lerpf(float(potency.get("min", 0)), float(potency.get("max", 0)), clampf(float(instance.get("potency", 0.0)), 0.0, 1.0))
		if float(instance.get("usage", 0.0)) <= 0.0:
			var condition_binding := _copy_dict(bindings.get("condition", {}))
			raw_value *= clampf(float(condition_binding.get("spent_potency_factor", 0.35)), 0.0, 1.0)
		effect[effect_key] = int(round(raw_value))
	var resonance := _copy_dict(bindings.get("resonance", {}))
	var resonance_key := str(resonance.get("effect_key", ""))
	if not resonance_key.is_empty() and clampf(float(instance.get("resonance", 0.0)), 0.0, 1.0) >= clampf(float(resonance.get("threshold", 1.0)), 0.0, 1.0):
		effect[resonance_key] = int(effect.get(resonance_key, 0)) + int(resonance.get("value", 0))
	return effect


static func _unit_float(seed: String, channel: String) -> float:
	return clampf(float(_hash_u32("%s|%s" % [seed, channel])) / float(HASH_MODULUS - 1), 0.0, 1.0)


static func _hash_u32(text: String) -> int:
	var hash := 2166136261
	for index in range(text.length()):
		var code := text.unicode_at(index)
		hash = int(((hash ^ code) * 16777619) % HASH_MODULUS)
		if hash < 0:
			hash += HASH_MODULUS
	return hash


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
