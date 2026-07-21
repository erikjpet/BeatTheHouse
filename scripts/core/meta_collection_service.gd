class_name MetaCollectionService
extends RefCounted

const CollectionItemResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")

const STORE_PATH := "user://meta_collection.json"
const STORE_PATH_ENV := "BTH_META_COLLECTION_PATH"
const ITEMS_PATH := "res://data/items/items.json"
const SCHEMA_VERSION := 3
const FIRST_INSTANCE_ID := 1
const SAL_RESALE_SCHEMA_VERSION := 1
const SAL_SHELF_SLOT_COUNT := 6
const SAL_HISTORY_LIMIT := 64
const SAL_RECEIPT_LIMIT := 256
const SAL_STARTER_CONDITION := 0.18
const SAL_STARTER_RARE_VALUE := 0.01
const REVEAL_BAG_KEY := "bag"
const HOUSING_BACK_ALLEY := "back_alley"
const HOUSING_MOTEL_ROOM := "motel_room"
const HOUSING_APARTMENT := "apartment"
const HOUSING_HOUSE := "house"
const SALE_KIND_ITEM := "item"
const SALE_KIND_BAG := "bag"
const LISTING_MODE_PAWN := "pawn"
const LISTING_MODE_NORMAL := "normal"
const LISTING_MODE_STARTER_DISCOUNT := "starter_discount"
const LISTING_MODE_STARTER_BUYBACK := "starter_buyback"
const LISTING_MODE_MOCKING_RELIST := "mocking_relist"
const FAILURE_DECAY_FLAG := "_meta_collection_failure_decay_applied"
const FIXTURE_POLLUTION_MIGRATION_FLAG := "_fixture_pollution_quarantined_v1"
const FAILURE_DURABILITY_LOSS := 0.10
const PLAYERS_CARD_ITEMDEF_ID := 9500
const GRAND_CASINO_CHIPS_ITEMDEF_ID := 9501
const PRESTIGE_RECOGNITION_HEAT_DELTA := -10
const PRESTIGE_CLEAN_HEAT_CEILING_DELTA := -5
const PRESTIGE_DROP_TIER_BONUS_STEPS := 1

const FIXTURE_PROVENANCE_TOKENS := [
	"ui-",
	"fixture",
	"test",
	"dry-run",
	"meta-home-review",
	"screenshot",
	"post-release",
	"foundation-",
	"layout-",
	"v04-",
]

var _store: Dictionary = {}
var _item_definitions_by_id: Dictionary = {}
var _items_loaded := false
var _shared_collection_resolver: CollectionItemResolver


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
	var migration := _migrate_fixture_pollution(_normalize_store(data))
	_store = _copy_dict(migration.get("store", {}))
	if bool(migration.get("migrated", false)):
		save()
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
	var resolver: Variant = CollectionItemResolverScript.new()
	var normalized: Dictionary = resolver.normalize_instance_for_definition(instance)
	var instance_id := _take_next_instance_id()
	normalized["schema_version"] = SCHEMA_VERSION
	normalized["instance_id"] = instance_id
	var instances := _copy_array(_store.get("owned_instances", []))
	instances.append(normalized)
	_store["owned_instances"] = instances
	return normalized.duplicate(true)


func mint_players_card(instance_data: Dictionary) -> Dictionary:
	var instance := {
		"itemdef_id": PLAYERS_CARD_ITEMDEF_ID,
		"potency": 1.0,
		"condition": 0.08,
		"resonance": 1.0,
		"usage": 1.0,
		"source": "grand_casino_players_card",
		"source_id": str(instance_data.get("route", "high_roller_cashout")),
		"instance_data": instance_data.duplicate(true),
	}
	return grant_instance(instance)


func mint_grand_casino_chip_stack(chip_amount: int, instance_data: Dictionary = {}) -> Dictionary:
	var amount := maxi(0, chip_amount)
	if amount <= 0:
		return {}
	var stamp := instance_data.duplicate(true)
	stamp["chip_amount"] = amount
	stamp["face_value"] = amount
	var instance := {
		"itemdef_id": GRAND_CASINO_CHIPS_ITEMDEF_ID,
		"potency": 1.0,
		"condition": 1.0,
		"resonance": 1.0,
		"usage": 1.0,
		"stack_amount": amount,
		"face_value": amount,
		"source": "grand_casino_shown_the_door",
		"source_id": str(stamp.get("route", "pit_boss_showdown")),
		"instance_data": stamp,
	}
	return grant_instance(instance)


func grant_bag(bagdef_id: int, rng_seed: String = "", metadata: Dictionary = {}) -> Dictionary:
	_store = _normalize_store(_store)
	var bag := metadata.duplicate(true)
	bag["schema_version"] = SCHEMA_VERSION
	bag["instance_id"] = _take_next_instance_id()
	bag["bagdef_id"] = bagdef_id
	bag["rng_seed"] = rng_seed
	if not bag.has("source"):
		bag["source"] = "grant"
	if not bag.has("source_id"):
		bag["source_id"] = ""
	var bags := _copy_array(_store.get("unopened_bags", []))
	bags.append(bag)
	_store["unopened_bags"] = bags
	return bag.duplicate(true)


func open_bag(instance_id: int) -> Dictionary:
	_store = _normalize_store(_store)
	if not can_accept_owned_instance():
		return {"ok": false, "message": "No room for another collection item."}
	var bags := _copy_array(_store.get("unopened_bags", []))
	var bag_index := -1
	var bag: Dictionary = {}
	for index in range(bags.size()):
		var candidate := _copy_dict(bags[index])
		if int(candidate.get("instance_id", -1)) == instance_id:
			bag_index = index
			bag = candidate
			break
	if bag_index < 0:
		return {"ok": false, "message": "That bag is no longer unopened."}
	var resolver: Variant = CollectionItemResolverScript.new()
	var options: Array = resolver.bag_item_options_for_bag(int(bag.get("bagdef_id", -1)))
	if options.is_empty():
		return {"ok": false, "message": "That bag definition has no item options."}
	var rng := _meta_rng()
	var option_index := rng.randi_range(0, options.size() - 1)
	var definition := _copy_dict(options[option_index])
	var reveal_seed := "%s|bag:%d|itemdef:%d|state:%d" % [
		str(bag.get("rng_seed", "meta")),
		instance_id,
		int(definition.get("itemdef_id", 0)),
		rng.state_value,
	]
	bags.remove_at(bag_index)
	_store["unopened_bags"] = bags
	_store["meta_rng"] = rng.snapshot()
	var rolled: Dictionary = resolver.roll_instance(int(definition.get("itemdef_id", -1)), reveal_seed)
	rolled["source"] = str(bag.get("source", "bag"))
	rolled["source_id"] = str(bag.get("source_id", ""))
	rolled["source_bag_instance_id"] = instance_id
	rolled["source_rng_seed"] = str(bag.get("rng_seed", ""))
	var granted := grant_instance(rolled)
	var run_item: Dictionary = resolver.resolve_run_item(granted)
	var reveal := {
		"bag": bag.duplicate(true),
		"item": granted.duplicate(true),
		"definition": definition,
		"run_item": run_item,
		"condition_band": _copy_dict(run_item.get("meta_collection", {})).get("condition_band", ""),
	}
	return {
		"ok": true,
		"message": "Opened %s." % str(bag.get("display_name", "bag")),
		"bag": bag.duplicate(true),
		"item": granted.duplicate(true),
		"run_item": run_item,
		"reveal": reveal,
	}


func housing_tier() -> String:
	_store = _normalize_store(_store)
	return str(_store.get("housing_tier", HOUSING_BACK_ALLEY))


func housing_definition(tier: String = "") -> Dictionary:
	var config := _meta_home_config()
	var housing := _copy_dict(config.get("housing", {}))
	var clean_tier := tier.strip_edges()
	if clean_tier.is_empty():
		clean_tier = housing_tier()
	return _copy_dict(housing.get(clean_tier, {}))


func next_housing_upgrade() -> Dictionary:
	_store = _normalize_store(_store)
	var order := _housing_order()
	var current := housing_tier()
	var current_index := order.find(current)
	if current_index < 0 or current_index >= order.size() - 1:
		return {}
	var next_tier := str(order[current_index + 1])
	var definition := housing_definition(next_tier)
	definition["tier"] = next_tier
	definition["price"] = maxi(0, int(definition.get("upgrade_price", 0)))
	definition["affordable"] = int(_store.get("gold_balance", 0)) >= int(definition.get("price", 0))
	return definition


func purchase_housing_upgrade() -> Dictionary:
	_store = _normalize_store(_store)
	var upgrade := next_housing_upgrade()
	if upgrade.is_empty():
		return {"ok": false, "message": "No further home upgrade is available."}
	var price := maxi(0, int(upgrade.get("price", 0)))
	var gold := int(_store.get("gold_balance", 0))
	if gold < price:
		return {"ok": false, "message": "Not enough gold for that home upgrade."}
	var tier := str(upgrade.get("tier", ""))
	_store["gold_balance"] = gold - price
	_store["housing_tier"] = tier
	var home := _copy_dict(_store.get("meta_home", {}))
	home["current_location"] = "home"
	home["housing_tier"] = tier
	_store["meta_home"] = home
	_store["loadout"] = _filtered_packed_ids(_copy_array(_store.get("loadout", [])))
	return {
		"ok": true,
		"message": "Home upgraded to %s." % str(upgrade.get("display_name", tier.capitalize())),
		"housing_tier": tier,
		"gold_balance": int(_store.get("gold_balance", 0)),
	}


func storage_slots() -> int:
	var definition := housing_definition()
	return maxi(0, int(definition.get("storage_slots", 0)))


func carry_capacity() -> int:
	_store = _normalize_store(_store)
	var total := 0
	for container_value in _copy_array(_store.get("owned_containers", [])):
		var container := _copy_dict(container_value)
		total += _container_capacity(str(container.get("item_id", "")))
	return maxi(0, total)


func total_owned_capacity() -> int:
	return storage_slots() + carry_capacity()


func can_accept_owned_instance() -> bool:
	_store = _normalize_store(_store)
	var capacity := total_owned_capacity()
	return capacity <= 0 or owned_instances().size() < capacity


func trade_up_unlocked() -> bool:
	var definition := housing_definition()
	return bool(definition.get("trade_up", false))


func grant_container(item_id: String) -> Dictionary:
	_store = _normalize_store(_store)
	var clean_id := item_id.strip_edges()
	if clean_id.is_empty() or _container_capacity(clean_id) <= 0:
		return {}
	var container := {
		"item_id": clean_id,
		"instance_id": _take_next_instance_id(),
		"capacity": _container_capacity(clean_id),
	}
	var containers := _copy_array(_store.get("owned_containers", []))
	containers.append(container)
	_store["owned_containers"] = containers
	return container.duplicate(true)


func pack_instance(instance_id: int) -> Dictionary:
	_store = _normalize_store(_store)
	if housing_tier() == HOUSING_BACK_ALLEY:
		return {"ok": true, "message": "Homeless runs carry every loadout-eligible item.", "packed_instance_ids": carried_instance_ids()}
	if instance_id <= 0 or not _owned_instance_ids().has(instance_id):
		return {"ok": false, "message": "That item is not owned."}
	var resolver: Variant = CollectionItemResolverScript.new()
	if not resolver.is_loadout_eligible(_owned_instance(instance_id)):
		return {"ok": false, "message": "Grand Casino Chips stay in meta storage until Sal fences them."}
	var loadout := _filtered_packed_ids(_copy_array(_store.get("loadout", [])))
	if loadout.has(instance_id):
		return {"ok": true, "message": "Item is already packed.", "packed_instance_ids": loadout}
	if loadout.size() >= carry_capacity():
		return {"ok": false, "message": "No carry space remains."}
	loadout.append(instance_id)
	_store["loadout"] = loadout
	return {"ok": true, "message": "Item packed.", "packed_instance_ids": loadout}


func unpack_instance(instance_id: int) -> Dictionary:
	_store = _normalize_store(_store)
	if housing_tier() == HOUSING_BACK_ALLEY:
		return {"ok": false, "message": "Back alley starts carry every owned item."}
	var loadout := _filtered_packed_ids(_copy_array(_store.get("loadout", [])))
	loadout.erase(instance_id)
	_store["loadout"] = loadout
	return {"ok": true, "message": "Item unpacked.", "packed_instance_ids": loadout}


func carried_instance_ids() -> Array:
	_store = _normalize_store(_store)
	if housing_tier() == HOUSING_BACK_ALLEY:
		return _loadout_eligible_owned_instance_ids()
	return _filtered_packed_ids(_copy_array(_store.get("loadout", [])))


func normal_run_start_modifiers() -> Dictionary:
	var carried_ids := carried_instance_ids()
	var resolver: Variant = CollectionItemResolverScript.new()
	var run_items: Array = []
	var prestige_card_ids: Array = []
	for instance_value in owned_instances():
		var instance := _copy_dict(instance_value)
		if not carried_ids.has(int(instance.get("instance_id", 0))):
			continue
		if resolver.is_players_card_instance(instance):
			prestige_card_ids.append(int(instance.get("instance_id", 0)))
		var run_item: Dictionary = resolver.resolve_run_item(instance)
		if not run_item.is_empty():
			run_items.append(run_item)
	var result := {
		"home_archetype_id": str(housing_definition().get("archetype_id", HOUSING_BACK_ALLEY)),
		"meta_collection_enabled": true,
		"meta_collection_carried_instance_ids": carried_ids,
		"meta_collection_loadout": run_items,
		"meta_collection_containers": carried_container_rows(),
	}
	if not prestige_card_ids.is_empty():
		var prestige: Dictionary = resolver.prestige_config()
		result["grand_casino_prestige"] = true
		result["grand_casino_prestige_card_instance_ids"] = prestige_card_ids
		result["grand_casino_prestige_recognition_heat_delta"] = mini(0, int(prestige.get("recognition_heat_delta", PRESTIGE_RECOGNITION_HEAT_DELTA)))
		result["grand_casino_prestige_clean_heat_ceiling_delta"] = mini(0, int(prestige.get("clean_heat_ceiling_delta", PRESTIGE_CLEAN_HEAT_CEILING_DELTA)))
		result["meta_collection_drop_tier_bonus_steps"] = maxi(0, int(prestige.get("drop_tier_bonus_steps", PRESTIGE_DROP_TIER_BONUS_STEPS)))
	return result


func players_card_carried_instance_ids() -> Array:
	var resolver: Variant = CollectionItemResolverScript.new()
	var carried_ids := carried_instance_ids()
	var result: Array = []
	for instance_value in owned_instances():
		var instance := _copy_dict(instance_value)
		var instance_id := int(instance.get("instance_id", 0))
		if carried_ids.has(instance_id) and resolver.is_players_card_instance(instance):
			result.append(instance_id)
	return result


# Builds the one authoritative packed-container manifest used by both the
# meta-home room and the generated run home.
func carried_container_rows() -> Array:
	_store = _normalize_store(_store)
	var carried_ids := carried_instance_ids()
	var resolver: Variant = CollectionItemResolverScript.new()
	var packed_items: Array = []
	for instance_value in owned_instances():
		var instance := _copy_dict(instance_value)
		if not carried_ids.has(int(instance.get("instance_id", 0))):
			continue
		var run_item: Dictionary = resolver.resolve_run_item(instance)
		if not run_item.is_empty():
			packed_items.append(run_item)
	var rows: Array = []
	var packed_index := 0
	var container_index := 0
	for container_value in _copy_array(_store.get("owned_containers", [])):
		var container := _copy_dict(container_value)
		var item_id := str(container.get("item_id", "bag")).strip_edges()
		var capacity := maxi(0, int(container.get("capacity", _container_capacity(item_id))))
		if item_id.is_empty() or capacity <= 0:
			continue
		container_index += 1
		var item_ids: Array = []
		var item_definitions := {}
		while packed_index < packed_items.size() and item_ids.size() < capacity:
			var packed_item: Dictionary = _copy_dict(packed_items[packed_index])
			packed_index += 1
			var packed_item_id := str(packed_item.get("id", "")).strip_edges()
			if packed_item_id.is_empty():
				continue
			item_ids.append(packed_item_id)
			item_definitions[packed_item_id] = packed_item
		rows.append({
			"id": "meta_%s_%02d" % [item_id, container_index],
			"item_id": item_id,
			"capacity": capacity,
			"items": item_ids,
			"item_definitions": item_definitions,
			"meta_loadout": true,
			"meta_container_instance_id": maxi(0, int(container.get("instance_id", 0))),
		})
	return rows


func apply_failure_decay(carried_ids: Array, rng_seed: String) -> Array:
	_store = _normalize_store(_store)
	var wanted_ids := {}
	for id_value in carried_ids:
		var instance_id := int(id_value)
		if instance_id > 0:
			wanted_ids[instance_id] = true
	if wanted_ids.is_empty():
		return []
	var next_instances: Array = []
	var decayed: Array = []
	var deleted_ids: Array = []
	var resolver: Variant = CollectionItemResolverScript.new()
	for instance_value in _copy_array(_store.get("owned_instances", [])):
		var instance := _copy_dict(instance_value)
		var instance_id := int(instance.get("instance_id", 0))
		if wanted_ids.has(instance_id):
			var after: Dictionary = resolver.normalize_instance_for_definition(instance)
			if resolver.is_players_card_instance(after):
				after["deleted"] = true
				after["destroyed_forever"] = true
				after["failure_rng_seed"] = "%s|%d" % [rng_seed, instance_id]
				deleted_ids.append(instance_id)
				decayed.append(after.duplicate(true))
				continue
			var before_condition := clampf(float(after.get("condition", 0.0)), 0.0, 1.0)
			after["condition"] = 0.0 if before_condition <= FAILURE_DURABILITY_LOSS else clampf(before_condition - FAILURE_DURABILITY_LOSS, 0.0, 1.0)
			after["failure_durability_loss"] = FAILURE_DURABILITY_LOSS
			after["failure_rng_seed"] = "%s|%d" % [rng_seed, instance_id]
			if float(after.get("condition", 0.0)) <= 0.0:
				after["deleted"] = true
				deleted_ids.append(instance_id)
			else:
				next_instances.append(after)
			decayed.append(after.duplicate(true))
		else:
			next_instances.append(instance)
	_store["owned_instances"] = next_instances
	if not deleted_ids.is_empty():
		var loadout := _filtered_packed_ids(_copy_array(_store.get("loadout", [])))
		for deleted_id in deleted_ids:
			loadout.erase(int(deleted_id))
		_store["loadout"] = loadout
	return decayed


func sale_quote(kind: String, instance_id: int) -> Dictionary:
	_store = _normalize_store(_store)
	var clean_kind := kind.strip_edges().to_lower()
	if clean_kind == SALE_KIND_BAG:
		return _bag_sale_quote(instance_id)
	return _item_sale_quote(instance_id)


func ordinary_collection_price_breakdown(instance: Dictionary, listing_mode: String = LISTING_MODE_PAWN) -> Dictionary:
	var resolver: Variant = _collection_resolver()
	var normalized: Dictionary = resolver.normalize_instance_for_definition(instance)
	var definition: Dictionary = resolver.item_definition(int(normalized.get("itemdef_id", -1)))
	if definition.is_empty() or str(definition.get("item_class", CollectionItemResolverScript.ITEM_CLASS_COLLECTION)) != CollectionItemResolverScript.ITEM_CLASS_COLLECTION:
		return {"ok": false, "message": "That item does not use Sal's collection price curve."}
	var floats := {
		"potency": clampf(float(normalized.get("potency", 0.0)), 0.0, 1.0),
		"condition": clampf(float(normalized.get("condition", 0.0)), 0.0, 1.0),
		"resonance": clampf(float(normalized.get("resonance", 0.0)), 0.0, 1.0),
		"usage": clampf(float(normalized.get("usage", 0.0)), 0.0, 1.0),
	}
	var potency_score := snappedf(pow(absf(2.0 * float(floats.get("potency", 0.0)) - 1.0), 4.0), 0.000000000001)
	var resonance_score := snappedf(pow(absf(2.0 * float(floats.get("resonance", 0.0)) - 1.0), 4.0), 0.000000000001)
	var usage_score := snappedf(pow(absf(2.0 * float(floats.get("usage", 0.0)) - 1.0), 4.0), 0.000000000001)
	var condition_score := snappedf(pow(float(floats.get("condition", 0.0)), 4.0), 0.000000000001)
	var scores := {
		"potency": potency_score,
		"condition": condition_score,
		"resonance": resonance_score,
		"usage": usage_score,
	}
	var contributions := {
		"potency": snappedf(0.5 * potency_score, 0.000000000001),
		"condition": snappedf(0.5 * condition_score, 0.000000000001),
		"resonance": snappedf(0.5 * resonance_score, 0.000000000001),
		"usage": snappedf(0.5 * usage_score, 0.000000000001),
	}
	var rarity_multiplier := snappedf(clampf(
		1.0
		+ float(contributions.get("potency", 0.0))
		+ float(contributions.get("condition", 0.0))
		+ float(contributions.get("resonance", 0.0))
		+ float(contributions.get("usage", 0.0)),
		1.0,
		3.0
	), 0.000000000001)
	var tier := str(definition.get("tier", "blue"))
	var prices := _copy_dict(_copy_dict(_meta_home_config().get("sale_prices", {})).get("items", {}))
	var tier_base := maxi(1, int(prices.get(tier, 1)))
	var pawn_quote := maxi(1, int(round(float(tier_base) * rarity_multiplier)))
	var mode := listing_mode.strip_edges().to_lower()
	if not [LISTING_MODE_PAWN, LISTING_MODE_NORMAL, LISTING_MODE_STARTER_DISCOUNT, LISTING_MODE_STARTER_BUYBACK, LISTING_MODE_MOCKING_RELIST].has(mode):
		mode = LISTING_MODE_PAWN
	var listing_multiplier := 1.0
	var final_price := pawn_quote
	match mode:
		LISTING_MODE_NORMAL:
			listing_multiplier = 1.5
			final_price = maxi(pawn_quote + 1, int(ceil(float(pawn_quote) * listing_multiplier)))
		LISTING_MODE_STARTER_DISCOUNT:
			listing_multiplier = 0.75
			final_price = maxi(1, int(round(float(pawn_quote) * listing_multiplier)))
		LISTING_MODE_STARTER_BUYBACK:
			listing_multiplier = 1.25
			final_price = maxi(1, int(ceil(float(pawn_quote) * listing_multiplier)))
		LISTING_MODE_MOCKING_RELIST:
			listing_multiplier = 10.0
			final_price = maxi(1, int(ceil(float(pawn_quote) * listing_multiplier)))
	return {
		"ok": true,
		"itemdef_id": int(normalized.get("itemdef_id", -1)),
		"instance_id": int(normalized.get("instance_id", 0)),
		"display_name": str(definition.get("display_name", "Collection Item")),
		"collection_id": str(definition.get("collection_id", "")),
		"tier": tier,
		"tier_base": tier_base,
		"clamped_floats": floats,
		"rarity_scores": scores,
		"rarity_contributions": contributions,
		"rarity_multiplier": rarity_multiplier,
		"pawn_quote": pawn_quote,
		"listing_mode": mode,
		"listing_multiplier": listing_multiplier,
		"final_price": final_price,
		"price": final_price,
	}


func sal_shelf_rows() -> Array:
	var resale := _copy_dict(_store.get("sal_resale", {}))
	var result: Array = []
	for slot_value in _copy_array(resale.get("slots", [])):
		var slot := _copy_dict(slot_value)
		if bool(slot.get("occupied", false)):
			var mode := str(slot.get("listing_mode", LISTING_MODE_NORMAL))
			var breakdown := ordinary_collection_price_breakdown(_copy_dict(slot.get("item", {})), mode)
			slot["quote_basis"] = breakdown
			slot["asking_price"] = int(breakdown.get("final_price", slot.get("asking_price", 0)))
		result.append(slot)
	return result


func sal_shelf_row(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= SAL_SHELF_SLOT_COUNT:
		return {}
	var rows := sal_shelf_rows()
	if slot_index >= rows.size():
		return {}
	return _copy_dict(rows[slot_index])


func sal_resale_rng_snapshot() -> Dictionary:
	return _copy_dict(_copy_dict(_store.get("sal_resale", {})).get("rng_streams", {}))


func allocate_sal_run_receipt(seed_text: String) -> String:
	_store = _normalize_store(_store)
	var resale := _copy_dict(_store.get("sal_resale", {}))
	var next_id := maxi(1, int(resale.get("next_run_receipt_id", 1)))
	resale["next_run_receipt_id"] = next_id + 1
	_store["sal_resale"] = resale
	return "sal-run:%d:%s" % [next_id, seed_text.strip_edges()]


func sal_run_receipt_processed(receipt: String) -> bool:
	var clean := receipt.strip_edges()
	return not clean.is_empty() and _copy_array(_copy_dict(_store.get("sal_resale", {})).get("processed_run_receipts", [])).has(clean)


func generate_and_insert_sal_stock(run_receipt: String) -> Dictionary:
	_store = _normalize_store(_store)
	var receipt := run_receipt.strip_edges()
	if receipt.is_empty():
		return {"ok": false, "stocked": false, "message": "Sal stock needs a run receipt."}
	if sal_run_receipt_processed(receipt):
		return {"ok": true, "stocked": false, "receipt": receipt, "message": "Sal already stocked this run."}
	var resale := _copy_dict(_store.get("sal_resale", {}))
	var streams := _copy_dict(resale.get("rng_streams", {}))
	var stock_rng := _rng_from_snapshot(_copy_dict(streams.get("sal_resale_stock", {})))
	var resolver: Variant = _collection_resolver()
	var rolled: Dictionary = resolver.roll_virtual_bag_item(stock_rng, "sal_resale_stock|%s" % receipt)
	if rolled.is_empty():
		return {"ok": false, "stocked": false, "receipt": receipt, "message": "Sal could not generate stock."}
	streams["sal_resale_stock"] = stock_rng.snapshot()
	var item: Dictionary = resolver.normalize_instance_for_definition(_copy_dict(rolled.get("item", {})))
	item["schema_version"] = SCHEMA_VERSION
	item["instance_id"] = _take_next_instance_id()
	item["source"] = "sal_run_stock"
	item["source_id"] = receipt
	item["generation_seed"] = str(rolled.get("generation_seed", ""))
	var provenance := _sal_roll_provenance(rolled, "sal_run_stock", receipt)
	var listing := _sal_listing_from_item(item, LISTING_MODE_NORMAL, provenance)
	var slots := _copy_array(resale.get("slots", []))
	var slot_index := -1
	for index in range(slots.size()):
		if not bool(_copy_dict(slots[index]).get("occupied", false)):
			slot_index = index
			break
	var replaced: Dictionary = {}
	if slot_index < 0:
		var eligible: Array = []
		for index in range(slots.size()):
			var candidate := _copy_dict(slots[index])
			if bool(candidate.get("occupied", false)) and not bool(candidate.get("protected", false)):
				eligible.append(index)
		if eligible.is_empty():
			return {"ok": false, "stocked": false, "receipt": receipt, "message": "No eligible Sal shelf slot can be replaced."}
		var replacement_rng := _rng_from_snapshot(_copy_dict(streams.get("sal_resale_replacement", {})))
		slot_index = int(eligible[replacement_rng.randi_range(0, eligible.size() - 1)])
		streams["sal_resale_replacement"] = replacement_rng.snapshot()
		replaced = _copy_dict(slots[slot_index])
	listing["slot_index"] = slot_index
	slots[slot_index] = listing
	resale["slots"] = slots
	resale["rng_streams"] = streams
	var receipts := _copy_array(resale.get("processed_run_receipts", []))
	receipts.append(receipt)
	resale["processed_run_receipts"] = _bounded_array(receipts, SAL_RECEIPT_LIMIT)
	var history := _copy_array(resale.get("stock_history", []))
	history.append({
		"receipt": receipt,
		"slot_index": slot_index,
		"instance_id": int(item.get("instance_id", 0)),
		"itemdef_id": int(item.get("itemdef_id", -1)),
		"virtual_bagdef_id": int(provenance.get("virtual_bagdef_id", -1)),
		"collection_id": str(provenance.get("collection_id", "")),
		"tier": str(provenance.get("tier", "")),
		"generation_seed": str(provenance.get("generation_seed", "")),
		"replaced_instance_id": int(_copy_dict(replaced.get("item", {})).get("instance_id", 0)),
	})
	resale["stock_history"] = _bounded_array(history, SAL_HISTORY_LIMIT)
	resale["revision"] = maxi(0, int(resale.get("revision", 0))) + 1
	_store["sal_resale"] = resale
	return {
		"ok": true,
		"stocked": true,
		"receipt": receipt,
		"slot_index": slot_index,
		"listing": listing.duplicate(true),
		"replaced": replaced,
		"summary_line": "Sal stocked something new.",
	}


func arm_sal_shelf_purchase(slot_index: int) -> Dictionary:
	_store = _normalize_store(_store)
	var quote := _authoritative_sal_slot_quote(slot_index)
	if not bool(quote.get("ok", false)):
		return quote
	if not can_accept_owned_instance():
		return {"ok": false, "message": "No room for another collection item."}
	var price := int(quote.get("asking_price", 0))
	if int(_store.get("gold_balance", 0)) < price:
		return {"ok": false, "message": "Not enough gold for that shelf item.", "asking_price": price}
	var resale := _copy_dict(_store.get("sal_resale", {}))
	var token := "sal-buy:%d:%d:%s:%d:%d" % [
		slot_index,
		int(quote.get("instance_id", 0)),
		str(quote.get("listing_mode", "")),
		price,
		int(resale.get("revision", 0)),
	]
	var pending := quote.duplicate(true)
	pending["token"] = token
	resale["pending_purchase"] = pending
	_store["sal_resale"] = resale
	return pending


func confirm_sal_shelf_purchase(token: String) -> Dictionary:
	_store = _normalize_store(_store)
	var resale := _copy_dict(_store.get("sal_resale", {}))
	var pending := _copy_dict(resale.get("pending_purchase", {}))
	if token.strip_edges().is_empty() or str(pending.get("token", "")) != token:
		return {"ok": false, "message": "Shelf purchase confirmation expired."}
	var slot_index := int(pending.get("slot_index", -1))
	var quote := _authoritative_sal_slot_quote(slot_index)
	if not bool(quote.get("ok", false)) \
		or int(quote.get("instance_id", 0)) != int(pending.get("instance_id", -1)) \
		or str(quote.get("listing_mode", "")) != str(pending.get("listing_mode", "")) \
		or int(quote.get("asking_price", 0)) != int(pending.get("asking_price", -1)):
		resale["pending_purchase"] = {}
		_store["sal_resale"] = resale
		return {"ok": false, "message": "That shelf listing changed before confirmation."}
	if not can_accept_owned_instance():
		return {"ok": false, "message": "No room for another collection item."}
	var price := int(quote.get("asking_price", 0))
	var gold := int(_store.get("gold_balance", 0))
	if gold < price:
		return {"ok": false, "message": "Not enough gold for that shelf item."}
	var slots := _copy_array(resale.get("slots", []))
	var listing := _copy_dict(slots[slot_index])
	var item := _copy_dict(listing.get("item", {}))
	_store["gold_balance"] = gold - price
	var owned := _copy_array(_store.get("owned_instances", []))
	owned.append(item.duplicate(true))
	_store["owned_instances"] = owned
	slots[slot_index] = _empty_sal_slot(slot_index)
	resale["slots"] = slots
	var history := _copy_array(resale.get("purchase_history", []))
	var purchase_record := {
		"slot_index": slot_index,
		"instance_id": int(item.get("instance_id", 0)),
		"itemdef_id": int(item.get("itemdef_id", -1)),
		"listing_mode": str(listing.get("listing_mode", "")),
		"pawn_quote": int(quote.get("pawn_quote", 0)),
		"price": price,
		"gold_balance": int(_store.get("gold_balance", 0)),
	}
	history.append(purchase_record)
	resale["purchase_history"] = _bounded_array(history, SAL_HISTORY_LIMIT)
	var starter_offer := {}
	if str(listing.get("listing_mode", "")) == LISTING_MODE_STARTER_DISCOUNT \
		and bool(listing.get("starter_tutorial_eligible", false)) \
		and not bool(resale.get("starter_first_purchased", false)) \
		and not bool(resale.get("starter_tutorial_resolved", false)):
		var offer_breakdown := ordinary_collection_price_breakdown(item, LISTING_MODE_STARTER_BUYBACK)
		starter_offer = {
			"instance_id": int(item.get("instance_id", 0)),
			"itemdef_id": int(item.get("itemdef_id", -1)),
			"item": item.duplicate(true),
			"provenance": _copy_dict(listing.get("provenance", {})),
			"original_slot_index": slot_index,
			"rare_channel": str(listing.get("starter_rare_channel", "")),
			"rare_value": float(listing.get("starter_rare_value", 0.0)),
			"pawn_quote": int(offer_breakdown.get("pawn_quote", 0)),
			"offer_price": int(offer_breakdown.get("final_price", 0)),
			"resolved": false,
		}
		resale["pending_starter_buyback"] = starter_offer
		resale["starter_first_purchased"] = true
	resale["pending_purchase"] = {}
	resale["revision"] = maxi(0, int(resale.get("revision", 0))) + 1
	_store["sal_resale"] = resale
	return {
		"ok": true,
		"message": "Bought %s for %d gold." % [str(quote.get("display_name", "collection item")), price],
		"slot_index": slot_index,
		"item": item.duplicate(true),
		"price": price,
		"gold_balance": int(_store.get("gold_balance", 0)),
		"pawn_quote": int(quote.get("pawn_quote", 0)),
		"listing_mode": str(listing.get("listing_mode", "")),
		"starter_offer": starter_offer,
	}


func pending_starter_buyback() -> Dictionary:
	return _copy_dict(_copy_dict(_store.get("sal_resale", {})).get("pending_starter_buyback", {}))


func resolve_starter_buyback(choice: String) -> Dictionary:
	_store = _normalize_store(_store)
	var resale := _copy_dict(_store.get("sal_resale", {}))
	var pending := _copy_dict(resale.get("pending_starter_buyback", {}))
	if pending.is_empty() or bool(pending.get("resolved", false)) or bool(resale.get("starter_tutorial_resolved", false)):
		return {"ok": false, "message": "Sal's special offer is already resolved."}
	var clean_choice := choice.strip_edges().to_lower()
	if clean_choice == "keep":
		resale["pending_starter_buyback"] = {}
		resale["starter_tutorial_resolved"] = true
		resale["revision"] = maxi(0, int(resale.get("revision", 0))) + 1
		_store["sal_resale"] = resale
		return {"ok": true, "choice": "keep", "message": "You kept the item."}
	if clean_choice != "sell_back":
		return {"ok": false, "message": "Choose whether to keep it or sell it back."}
	var instance_id := int(pending.get("instance_id", 0))
	var owned_item := _owned_instance(instance_id)
	if owned_item.is_empty() or not _same_sal_instance_identity(owned_item, _copy_dict(pending.get("item", {}))):
		return {"ok": false, "message": "The exact starter item is no longer available for Sal's offer."}
	var slot_index := int(pending.get("original_slot_index", -1))
	var slots := _copy_array(resale.get("slots", []))
	if slot_index < 0 or slot_index >= slots.size() or bool(_copy_dict(slots[slot_index]).get("occupied", false)):
		return {"ok": false, "message": "The original shelf slot is no longer empty."}
	var offer_breakdown := ordinary_collection_price_breakdown(owned_item, LISTING_MODE_STARTER_BUYBACK)
	var pawn_quote := int(offer_breakdown.get("pawn_quote", 0))
	var offer_price := int(offer_breakdown.get("final_price", 0))
	if pawn_quote != int(pending.get("pawn_quote", -1)) or offer_price != int(pending.get("offer_price", -1)):
		return {"ok": false, "message": "Sal's saved offer no longer matches the item."}
	if not remove_instance(instance_id):
		return {"ok": false, "message": "The starter item could not be transferred."}
	var loadout := _filtered_packed_ids(_copy_array(_store.get("loadout", [])))
	loadout.erase(instance_id)
	_store["loadout"] = loadout
	_store["gold_balance"] = maxi(0, int(_store.get("gold_balance", 0)) + offer_price)
	var provenance := _copy_dict(pending.get("provenance", {}))
	if provenance.is_empty():
		provenance = {"source": "sal_starter_buyback", "source_id": "starter"}
	var relisted := _sal_listing_from_item(owned_item, LISTING_MODE_MOCKING_RELIST, provenance)
	relisted["slot_index"] = slot_index
	relisted["starter_rare_channel"] = str(pending.get("rare_channel", ""))
	relisted["starter_rare_value"] = float(pending.get("rare_value", 0.0))
	slots[slot_index] = relisted
	resale["slots"] = slots
	resale["pending_starter_buyback"] = {}
	resale["starter_tutorial_resolved"] = true
	var history := _copy_array(resale.get("purchase_history", []))
	history.append({
		"kind": "starter_buyback",
		"instance_id": instance_id,
		"slot_index": slot_index,
		"pawn_quote": pawn_quote,
		"offer_price": offer_price,
		"relist_price": int(relisted.get("asking_price", 0)),
		"gold_balance": int(_store.get("gold_balance", 0)),
	})
	resale["purchase_history"] = _bounded_array(history, SAL_HISTORY_LIMIT)
	resale["revision"] = maxi(0, int(resale.get("revision", 0))) + 1
	_store["sal_resale"] = resale
	return {
		"ok": true,
		"choice": "sell_back",
		"message": "Sal bought it back for %d gold." % offer_price,
		"pawn_quote": pawn_quote,
		"offer_price": offer_price,
		"relist_price": int(relisted.get("asking_price", 0)),
		"gold_balance": int(_store.get("gold_balance", 0)),
		"listing": relisted,
	}


func _authoritative_sal_slot_quote(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= SAL_SHELF_SLOT_COUNT:
		return {"ok": false, "message": "That shelf slot does not exist."}
	var resale := _copy_dict(_store.get("sal_resale", {}))
	var slots := _copy_array(resale.get("slots", []))
	if slot_index >= slots.size():
		return {"ok": false, "message": "That shelf slot does not exist."}
	var listing := _copy_dict(slots[slot_index])
	if not bool(listing.get("occupied", false)):
		return {"ok": false, "message": "That shelf slot is empty."}
	var item := _copy_dict(listing.get("item", {}))
	var mode := str(listing.get("listing_mode", LISTING_MODE_NORMAL))
	var breakdown := ordinary_collection_price_breakdown(item, mode)
	if not bool(breakdown.get("ok", false)):
		return breakdown
	breakdown["slot_index"] = slot_index
	breakdown["instance_id"] = int(item.get("instance_id", 0))
	breakdown["asking_price"] = int(breakdown.get("final_price", 0))
	return breakdown


func _same_sal_instance_identity(left: Dictionary, right: Dictionary) -> bool:
	for key in ["instance_id", "itemdef_id", "potency", "condition", "resonance", "usage"]:
		if left.get(key) != right.get(key):
			return false
	return true


func arm_sale(kind: String, instance_id: int) -> Dictionary:
	var quote := sale_quote(kind, instance_id)
	if not bool(quote.get("ok", false)):
		return quote
	var token := "sale:%s:%d:%d" % [str(quote.get("kind", "")), int(quote.get("instance_id", 0)), Time.get_ticks_msec()]
	quote["token"] = token
	_store["pending_sale"] = quote.duplicate(true)
	return quote


func confirm_sale(token: String) -> Dictionary:
	_store = _normalize_store(_store)
	var pending := _copy_dict(_store.get("pending_sale", {}))
	if token.strip_edges().is_empty() or str(pending.get("token", "")) != token:
		return {"ok": false, "message": "Sale confirmation expired."}
	var kind := str(pending.get("kind", ""))
	var instance_id := int(pending.get("instance_id", 0))
	var authoritative := sale_quote(kind, instance_id)
	if not bool(authoritative.get("ok", false)) \
		or str(authoritative.get("kind", "")) != kind \
		or int(authoritative.get("instance_id", 0)) != instance_id \
		or int(authoritative.get("price", -1)) != int(pending.get("price", -2)):
		_store["pending_sale"] = {}
		return {"ok": false, "message": "That sale quote changed before confirmation."}
	var removed := false
	if kind == SALE_KIND_BAG:
		removed = _remove_bag(instance_id)
	else:
		removed = remove_instance(instance_id)
		var loadout := _filtered_packed_ids(_copy_array(_store.get("loadout", [])))
		loadout.erase(instance_id)
		_store["loadout"] = loadout
	if not removed:
		_store["pending_sale"] = {}
		return {"ok": false, "message": "That item is no longer available to sell."}
	var price := maxi(0, int(authoritative.get("price", 0)))
	_store["gold_balance"] = maxi(0, int(_store.get("gold_balance", 0)) + price)
	var history := _copy_array(_store.get("sale_history", []))
	var record := pending.duplicate(true)
	record["gold_balance"] = int(_store.get("gold_balance", 0))
	history.append(record)
	_store["sale_history"] = history
	_store["pending_sale"] = {}
	return {
		"ok": true,
		"message": "Sold for %d gold." % price,
		"kind": kind,
		"instance_id": instance_id,
		"display_name": str(authoritative.get("display_name", "Item")),
		"price": price,
		"gold_balance": int(_store.get("gold_balance", 0)),
	}


func arm_trade_up(instance_ids: Array) -> Dictionary:
	_store = _normalize_store(_store)
	if not trade_up_unlocked():
		return {"ok": false, "message": "Trade-ups unlock with an apartment or house."}
	var ids: Array = []
	for id_value in instance_ids:
		var id := int(id_value)
		if id > 0 and not ids.has(id):
			ids.append(id)
	if ids.size() != 5:
		return {"ok": false, "message": "Trade-up requires five matching items."}
	var resolver: Variant = CollectionItemResolverScript.new()
	var instances: Array = []
	var collection_id := ""
	var tier := ""
	for id in ids:
		var instance := _owned_instance(id)
		var definition: Dictionary = resolver.item_definition(int(instance.get("itemdef_id", -1)))
		if instance.is_empty() or definition.is_empty():
			return {"ok": false, "message": "Trade-up item is missing."}
		var item_collection_id := str(definition.get("collection_id", ""))
		var item_tier := str(definition.get("tier", ""))
		if collection_id.is_empty():
			collection_id = item_collection_id
			tier = item_tier
		elif collection_id != item_collection_id or tier != item_tier:
			return {"ok": false, "message": "Trade-up items must match collection and tier."}
		instances.append(instance)
	var next_tier := _next_collection_tier(tier)
	if next_tier.is_empty():
		return {"ok": false, "message": "Gold-tier items cannot trade up."}
	var token := "trade:%s:%s:%d" % [collection_id, tier, Time.get_ticks_msec()]
	var pending := {
		"ok": true,
		"token": token,
		"collection_id": collection_id,
		"tier": tier,
		"next_tier": next_tier,
		"instance_ids": ids,
		"message": "Trade five %s items for one %s item." % [tier.capitalize(), next_tier.capitalize()],
	}
	_store["pending_trade_up"] = pending.duplicate(true)
	return pending


func confirm_trade_up(token: String) -> Dictionary:
	_store = _normalize_store(_store)
	var pending := _copy_dict(_store.get("pending_trade_up", {}))
	if token.strip_edges().is_empty() or str(pending.get("token", "")) != token:
		return {"ok": false, "message": "Trade-up confirmation expired."}
	if not trade_up_unlocked():
		_store["pending_trade_up"] = {}
		return {"ok": false, "message": "Trade-ups unlock with an apartment or house."}
	var ids := _copy_array(pending.get("instance_ids", []))
	var resolver: Variant = CollectionItemResolverScript.new()
	var inputs: Array = []
	for id_value in ids:
		var instance := _owned_instance(int(id_value))
		if instance.is_empty():
			_store["pending_trade_up"] = {}
			return {"ok": false, "message": "A trade-up item is no longer owned."}
		inputs.append(instance)
	var options: Array = resolver.item_definitions_for_collection_tier(str(pending.get("collection_id", "")), str(pending.get("next_tier", "")))
	if options.is_empty():
		_store["pending_trade_up"] = {}
		return {"ok": false, "message": "No trade-up output exists."}
	var rng := _meta_rng()
	var output_def := _copy_dict(options[rng.randi_range(0, options.size() - 1)])
	var output := _mean_trade_up_instance(int(output_def.get("itemdef_id", -1)), inputs)
	for id_value in ids:
		remove_instance(int(id_value))
	var granted := grant_instance(output)
	_store["meta_rng"] = rng.snapshot()
	var history := _copy_array(_store.get("trade_up_history", []))
	var record := pending.duplicate(true)
	record["output_instance_id"] = int(granted.get("instance_id", 0))
	record["output_itemdef_id"] = int(granted.get("itemdef_id", -1))
	history.append(record)
	_store["trade_up_history"] = history
	_store["pending_trade_up"] = {}
	return {"ok": true, "message": "Trade-up complete.", "item": granted}


func unopened_bags() -> Array:
	_store = _normalize_store(_store)
	return _copy_array(_store.get("unopened_bags", []))


func meta_rng_snapshot() -> Dictionary:
	_store = _normalize_store(_store)
	return _copy_dict(_store.get("meta_rng", {}))


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
	normalized["housing_tier"] = _normalize_housing_tier(str(normalized.get("housing_tier", _copy_dict(normalized.get("meta_home", {})).get("housing_tier", HOUSING_BACK_ALLEY))))
	normalized["owned_containers"] = _normalized_containers(normalized.get("owned_containers", []))
	normalized["loadout"] = _filtered_packed_ids_for(
		_copy_array(normalized.get("loadout", [])),
		_copy_array(normalized.get("owned_instances", [])),
		str(normalized.get("housing_tier", HOUSING_BACK_ALLEY)),
		_copy_array(normalized.get("owned_containers", []))
	)
	normalized["meta_home"] = _normalize_meta_home(normalized.get("meta_home", {}), str(normalized.get("housing_tier", HOUSING_BACK_ALLEY)))
	normalized["trade_up_history"] = _copy_array(normalized.get("trade_up_history", []))
	normalized["sale_history"] = _copy_array(normalized.get("sale_history", []))
	normalized["pending_sale"] = _copy_dict(normalized.get("pending_sale", {}))
	normalized["pending_trade_up"] = _copy_dict(normalized.get("pending_trade_up", {}))
	normalized["meta_rng"] = _normalize_meta_rng(normalized.get("meta_rng", {}))
	normalized["next_instance_id"] = maxi(
		maxi(FIRST_INSTANCE_ID, int(normalized.get("next_instance_id", FIRST_INSTANCE_ID))),
		_max_recorded_instance_id(normalized) + 1
	)
	normalized["sal_resale"] = _normalize_sal_resale(normalized.get("sal_resale", {}), normalized)
	normalized["next_instance_id"] = maxi(
		maxi(FIRST_INSTANCE_ID, int(normalized.get("next_instance_id", FIRST_INSTANCE_ID))),
		_max_recorded_instance_id(normalized) + 1
	)
	return normalized


func _normalize_sal_resale(value: Variant, root: Dictionary) -> Dictionary:
	var resale := _copy_dict(value)
	var initialized := bool(resale.get("initialized", false))
	resale["schema_version"] = SAL_RESALE_SCHEMA_VERSION
	resale["initialized"] = true
	resale["rng_streams"] = _normalized_sal_rng_streams(resale.get("rng_streams", {}))
	var source_slots := _copy_array(resale.get("slots", []))
	var slots: Array = []
	for index in range(SAL_SHELF_SLOT_COUNT):
		slots.append(_empty_sal_slot(index))
	for slot_value in source_slots:
		var source := _copy_dict(slot_value)
		var index := int(source.get("slot_index", -1))
		if index < 0 or index >= SAL_SHELF_SLOT_COUNT:
			continue
		slots[index] = _normalize_sal_slot(source, index)
	resale["slots"] = slots
	resale["starter_seeded"] = bool(resale.get("starter_seeded", initialized))
	resale["starter_first_purchased"] = bool(resale.get("starter_first_purchased", false))
	resale["starter_tutorial_resolved"] = bool(resale.get("starter_tutorial_resolved", false))
	resale["pending_starter_buyback"] = _normalize_pending_starter_buyback(resale.get("pending_starter_buyback", {}))
	resale["pending_purchase"] = _normalize_pending_sal_purchase(resale.get("pending_purchase", {}))
	resale["stock_history"] = _bounded_array(_copy_array(resale.get("stock_history", [])), SAL_HISTORY_LIMIT)
	resale["purchase_history"] = _bounded_array(_copy_array(resale.get("purchase_history", [])), SAL_HISTORY_LIMIT)
	resale["processed_run_receipts"] = _bounded_unique_strings(_copy_array(resale.get("processed_run_receipts", [])), SAL_RECEIPT_LIMIT)
	resale["next_run_receipt_id"] = maxi(1, int(resale.get("next_run_receipt_id", 1)))
	resale["dialogue_counts"] = _copy_dict(resale.get("dialogue_counts", {}))
	resale["revision"] = maxi(0, int(resale.get("revision", 0)))
	if not initialized:
		var starter := _seed_sal_starter_listing(resale, root)
		if not starter.is_empty():
			starter["slot_index"] = 0
			slots[0] = starter
			resale["slots"] = slots
			resale["starter_seeded"] = true
			resale["revision"] = maxi(1, int(resale.get("revision", 0)) + 1)
	return resale


func _normalize_pending_starter_buyback(value: Variant) -> Dictionary:
	var pending := _copy_dict(value)
	if pending.is_empty():
		return {}
	var resolver: Variant = _collection_resolver()
	pending["instance_id"] = int(pending.get("instance_id", 0))
	pending["itemdef_id"] = int(pending.get("itemdef_id", -1))
	var item: Dictionary = resolver.normalize_instance_for_definition(_copy_dict(pending.get("item", {})))
	item["provenance"] = _normalize_sal_provenance(item.get("provenance", pending.get("provenance", {})))
	pending["item"] = item
	pending["original_slot_index"] = int(pending.get("original_slot_index", -1))
	pending["rare_channel"] = str(pending.get("rare_channel", ""))
	pending["rare_value"] = clampf(float(pending.get("rare_value", 0.0)), 0.0, 1.0)
	pending["pawn_quote"] = maxi(0, int(pending.get("pawn_quote", 0)))
	pending["offer_price"] = maxi(0, int(pending.get("offer_price", 0)))
	pending["provenance"] = _normalize_sal_provenance(pending.get("provenance", {}))
	pending["resolved"] = bool(pending.get("resolved", false))
	return pending


func _normalize_pending_sal_purchase(value: Variant) -> Dictionary:
	var pending := _copy_dict(value)
	if pending.is_empty():
		return {}
	for key in ["slot_index", "instance_id", "itemdef_id", "tier_base", "pawn_quote", "final_price", "price", "asking_price"]:
		if pending.has(key):
			pending[key] = int(pending.get(key, 0))
	pending["token"] = str(pending.get("token", ""))
	pending["listing_mode"] = str(pending.get("listing_mode", ""))
	return pending


func _normalize_sal_provenance(value: Variant) -> Dictionary:
	var provenance := _copy_dict(value)
	provenance["virtual_bagdef_id"] = int(provenance.get("virtual_bagdef_id", -1))
	return provenance


func _normalize_sal_slot(value: Dictionary, slot_index: int) -> Dictionary:
	var slot := value.duplicate(true)
	slot["slot_index"] = slot_index
	var item := _copy_dict(slot.get("item", {}))
	var resolver: Variant = _collection_resolver()
	item = resolver.normalize_instance_for_definition(item)
	var definition: Dictionary = resolver.item_definition(int(item.get("itemdef_id", -1)))
	if item.is_empty() or definition.is_empty() or str(definition.get("item_class", CollectionItemResolverScript.ITEM_CLASS_COLLECTION)) != CollectionItemResolverScript.ITEM_CLASS_COLLECTION:
		return _empty_sal_slot(slot_index)
	slot["occupied"] = true
	var mode := str(slot.get("listing_mode", LISTING_MODE_NORMAL)).strip_edges().to_lower()
	if not [LISTING_MODE_NORMAL, LISTING_MODE_STARTER_DISCOUNT, LISTING_MODE_MOCKING_RELIST].has(mode):
		mode = LISTING_MODE_NORMAL
	slot["listing_mode"] = mode
	var normalized_provenance := _normalize_sal_provenance(slot.get("provenance", {}))
	slot["provenance"] = normalized_provenance
	item["provenance"] = normalized_provenance.duplicate(true)
	slot["item"] = item
	slot["protected"] = bool(slot.get("protected", mode == LISTING_MODE_STARTER_DISCOUNT))
	slot["starter_tutorial_eligible"] = bool(slot.get("starter_tutorial_eligible", mode == LISTING_MODE_STARTER_DISCOUNT))
	slot["starter_rare_channel"] = str(slot.get("starter_rare_channel", ""))
	slot["starter_rare_value"] = clampf(float(slot.get("starter_rare_value", item.get(str(slot.get("starter_rare_channel", "")), 0.0))), 0.0, 1.0)
	var provenance := _copy_dict(slot.get("provenance", {}))
	slot["virtual_bagdef_id"] = int(slot.get("virtual_bagdef_id", provenance.get("virtual_bagdef_id", -1)))
	var breakdown := ordinary_collection_price_breakdown(item, mode)
	slot["quote_basis"] = breakdown
	slot["asking_price"] = int(breakdown.get("final_price", slot.get("asking_price", 0)))
	return slot


func _seed_sal_starter_listing(resale: Dictionary, root: Dictionary) -> Dictionary:
	var streams := _copy_dict(resale.get("rng_streams", {}))
	var rng := _rng_from_snapshot(_copy_dict(streams.get("sal_starter_item", {})))
	var resolver: Variant = _collection_resolver()
	var rolled: Dictionary = resolver.roll_virtual_bag_item(rng, "sal_starter_item")
	if rolled.is_empty():
		return {}
	var rare_channels := ["potency", "resonance", "usage"]
	var rare_channel := str(rare_channels[rng.randi_range(0, rare_channels.size() - 1)])
	streams["sal_starter_item"] = rng.snapshot()
	resale["rng_streams"] = streams
	var item: Dictionary = resolver.normalize_instance_for_definition(_copy_dict(rolled.get("item", {})))
	var instance_id := maxi(FIRST_INSTANCE_ID, int(root.get("next_instance_id", FIRST_INSTANCE_ID)))
	root["next_instance_id"] = instance_id + 1
	item["schema_version"] = SCHEMA_VERSION
	item["instance_id"] = instance_id
	item["condition"] = SAL_STARTER_CONDITION
	item[rare_channel] = SAL_STARTER_RARE_VALUE
	item["source"] = "sal_starter_stock"
	item["source_id"] = "starter"
	item["generation_seed"] = str(rolled.get("generation_seed", ""))
	var provenance := _sal_roll_provenance(rolled, "sal_starter_stock", "starter")
	var listing := _sal_listing_from_item(item, LISTING_MODE_STARTER_DISCOUNT, provenance)
	listing["protected"] = true
	listing["starter_tutorial_eligible"] = true
	listing["starter_rare_channel"] = rare_channel
	listing["starter_rare_value"] = SAL_STARTER_RARE_VALUE
	return listing


func _sal_listing_from_item(item: Dictionary, listing_mode: String, provenance: Dictionary) -> Dictionary:
	var stored_item := item.duplicate(true)
	stored_item["provenance"] = provenance.duplicate(true)
	var breakdown := ordinary_collection_price_breakdown(stored_item, listing_mode)
	return {
		"slot_index": -1,
		"occupied": true,
		"item": stored_item,
		"provenance": provenance.duplicate(true),
		"listing_mode": listing_mode,
		"quote_basis": breakdown,
		"asking_price": int(breakdown.get("final_price", 0)),
		"protected": false,
		"starter_tutorial_eligible": false,
		"starter_rare_channel": "",
		"starter_rare_value": 0.0,
		"virtual_bagdef_id": int(provenance.get("virtual_bagdef_id", -1)),
	}


func _sal_roll_provenance(rolled: Dictionary, source: String, source_id: String) -> Dictionary:
	var collection := _copy_dict(rolled.get("collection", {}))
	var bag := _copy_dict(rolled.get("virtual_bag", {}))
	return {
		"source": source,
		"source_id": source_id,
		"run_receipt": source_id if source == "sal_run_stock" else "",
		"virtual_bagdef_id": int(bag.get("itemdef_id", -1)),
		"virtual_bag_id": str(bag.get("id", "")),
		"collection_id": str(collection.get("id", bag.get("collection_id", ""))),
		"tier": str(rolled.get("tier", bag.get("tier", ""))),
		"generation_seed": str(rolled.get("generation_seed", "")),
	}


func _empty_sal_slot(slot_index: int) -> Dictionary:
	return {
		"slot_index": slot_index,
		"occupied": false,
		"item": {},
		"provenance": {},
		"listing_mode": "",
		"quote_basis": {},
		"asking_price": 0,
		"protected": false,
		"starter_tutorial_eligible": false,
		"starter_rare_channel": "",
		"starter_rare_value": 0.0,
		"virtual_bagdef_id": -1,
	}


func _normalized_sal_rng_streams(value: Variant) -> Dictionary:
	var streams := _copy_dict(value)
	for key in ["sal_resale_stock", "sal_resale_replacement", "sal_starter_item"]:
		var fallback_seed := RngStreamScript.derive_seed(904613, 904613, key)
		var source := _copy_dict(streams.get(key, {}))
		var rng := RngStreamScript.new()
		rng.configure(int(source.get("seed", fallback_seed)), int(source.get("state", source.get("seed", fallback_seed))))
		streams[key] = rng.snapshot()
	return streams


func _rng_from_snapshot(snapshot_value: Dictionary) -> RngStream:
	var rng: RngStream = RngStreamScript.new()
	rng.restore(snapshot_value)
	return rng


func _bounded_array(values: Array, limit: int) -> Array:
	var result := values.duplicate(true)
	while result.size() > maxi(0, limit):
		result.pop_front()
	return result


func _bounded_unique_strings(values: Array, limit: int) -> Array:
	var result: Array = []
	for value in values:
		var clean := str(value).strip_edges()
		if not clean.is_empty() and not result.has(clean):
			result.append(clean)
	return _bounded_array(result, limit)


func _migrate_fixture_pollution(data: Dictionary) -> Dictionary:
	var next := data.duplicate(true)
	var quarantined_bags: Array = []
	var kept_bags: Array = []
	for bag_value in _copy_array(next.get("unopened_bags", [])):
		var bag := _copy_dict(bag_value)
		if _record_has_fixture_provenance(bag):
			quarantined_bags.append(bag)
		else:
			kept_bags.append(bag)
	var fixture_pollution_found := not quarantined_bags.is_empty()
	var quarantined_instances: Array = []
	var kept_instances: Array = []
	for instance_value in _copy_array(next.get("owned_instances", [])):
		var instance := _copy_dict(instance_value)
		if _record_has_fixture_provenance(instance):
			quarantined_instances.append(instance)
		elif fixture_pollution_found and not _record_has_earned_provenance(instance):
			quarantined_instances.append(instance)
		else:
			kept_instances.append(instance)
	if quarantined_bags.is_empty() and quarantined_instances.is_empty():
		return {"store": next, "migrated": false}
	next["unopened_bags"] = kept_bags
	next["owned_instances"] = kept_instances
	var quarantine := _copy_dict(next.get("quarantined_records", {}))
	quarantine["fixture_bags"] = _copy_array(quarantine.get("fixture_bags", [])) + quarantined_bags
	quarantine["fixture_instances"] = _copy_array(quarantine.get("fixture_instances", [])) + quarantined_instances
	quarantine["migration"] = FIXTURE_POLLUTION_MIGRATION_FLAG
	next["quarantined_records"] = quarantine
	if kept_bags.is_empty() and kept_instances.is_empty():
		next["loadout"] = []
		next["pending_sale"] = {}
		next["pending_trade_up"] = {}
		next["sale_history"] = []
		next["gold_balance"] = 0
	next[FIXTURE_POLLUTION_MIGRATION_FLAG] = true
	next["next_instance_id"] = maxi(FIRST_INSTANCE_ID, _max_recorded_instance_id(next) + 1)
	return {"store": _normalize_store(next), "migrated": true}


func _record_has_earned_provenance(record: Dictionary) -> bool:
	var source := str(record.get("source", "")).strip_edges()
	var rng_seed := str(record.get("rng_seed", record.get("source_rng_seed", ""))).strip_edges()
	if source.is_empty() and rng_seed.is_empty():
		return false
	return not _record_has_fixture_provenance(record)


func _record_has_fixture_provenance(record: Dictionary) -> bool:
	for field in ["source", "source_id", "rng_seed", "source_rng_seed", "marker_id"]:
		var text := str(record.get(field, "")).strip_edges().to_lower()
		if text.is_empty():
			continue
		for token in FIXTURE_PROVENANCE_TOKENS:
			if text.contains(str(token)):
				return true
	return false


func _normalize_housing_tier(value: String) -> String:
	var clean := value.strip_edges()
	if _housing_order().has(clean):
		return clean
	return HOUSING_BACK_ALLEY


func _normalize_meta_home(value: Variant, tier: String) -> Dictionary:
	var home := _copy_dict(value)
	home["housing_tier"] = _normalize_housing_tier(tier)
	home["current_location"] = str(home.get("current_location", "home")).strip_edges()
	if str(home.get("current_location", "")).is_empty():
		home["current_location"] = "home"
	return home


func _normalized_containers(value: Variant) -> Array:
	var containers: Array = []
	for container_value in _copy_array(value):
		var container := _copy_dict(container_value)
		var item_id := str(container.get("item_id", "")).strip_edges()
		var capacity := _container_capacity(item_id)
		if item_id.is_empty() or capacity <= 0:
			continue
		container["item_id"] = item_id
		container["instance_id"] = maxi(0, int(container.get("instance_id", 0)))
		container["capacity"] = capacity
		containers.append(container)
	if containers.is_empty():
		var starter_id := str(_meta_home_config().get("starter_container_id", "bag"))
		containers.append({"item_id": starter_id, "instance_id": 0, "capacity": _container_capacity(starter_id)})
	return containers


func _normalized_instances(value: Variant) -> Array:
	var normalized: Array = []
	var resolver: Variant = CollectionItemResolverScript.new()
	for instance_value in _copy_array(value):
		var instance: Dictionary = resolver.normalize_instance_for_definition(_copy_dict(instance_value))
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
		if not bag.has("source"):
			bag["source"] = "grant"
		if not bag.has("source_id"):
			bag["source_id"] = ""
		normalized.append(bag)
	return normalized


func _normalize_meta_rng(value: Variant) -> Dictionary:
	var source := _copy_dict(value)
	var seed := int(source.get("seed", 904613))
	var state := int(source.get("state", seed))
	var rng := RngStreamScript.new()
	rng.configure(seed, state)
	return rng.snapshot()


func _meta_rng() -> RngStream:
	var rng: RngStream = RngStreamScript.new()
	rng.restore(_copy_dict(_store.get("meta_rng", {})))
	return rng


func _meta_home_config() -> Dictionary:
	var resolver: Variant = CollectionItemResolverScript.new()
	var config: Dictionary = resolver.meta_home_config()
	if config.is_empty():
		return {
			"housing_order": [HOUSING_BACK_ALLEY, HOUSING_MOTEL_ROOM, HOUSING_APARTMENT, HOUSING_HOUSE],
			"starter_container_id": "bag",
			"housing": {
				"back_alley": {"display_name": "Back Alley", "archetype_id": HOUSING_BACK_ALLEY, "storage_slots": 0, "upgrade_price": 0, "trade_up": false},
				"motel_room": {"display_name": "Motel Room", "archetype_id": HOUSING_MOTEL_ROOM, "storage_slots": 8, "upgrade_price": 60, "trade_up": false},
				"apartment": {"display_name": "Apartment", "archetype_id": HOUSING_APARTMENT, "storage_slots": 16, "upgrade_price": 250, "trade_up": true},
				"house": {"display_name": "House", "archetype_id": HOUSING_HOUSE, "storage_slots": 32, "upgrade_price": 600, "trade_up": true},
			},
			"sale_prices": {
				"bags": {"blue": 6, "purple": 12, "pink": 24, "red": 48, "gold": 96},
				"items": {"blue": 10, "purple": 22, "pink": 48, "red": 100, "gold": 220},
			},
		}
	return config


func _housing_order() -> Array:
	var order := _copy_array(_meta_home_config().get("housing_order", []))
	if order.is_empty():
		return [HOUSING_BACK_ALLEY, HOUSING_MOTEL_ROOM, HOUSING_APARTMENT, HOUSING_HOUSE]
	return order


func _filtered_packed_ids(values: Array) -> Array:
	return _filtered_packed_ids_for(
		values,
		_copy_array(_store.get("owned_instances", [])),
		str(_store.get("housing_tier", HOUSING_BACK_ALLEY)),
		_copy_array(_store.get("owned_containers", []))
	)


func _filtered_packed_ids_for(values: Array, owned_instances: Array, tier: String, containers: Array) -> Array:
	var owned_lookup := {}
	var resolver: Variant = CollectionItemResolverScript.new()
	for instance_value in owned_instances:
		var instance := _copy_dict(instance_value)
		var instance_id := int(instance.get("instance_id", 0))
		if instance_id > 0 and resolver.is_loadout_eligible(instance):
			owned_lookup[instance_id] = true
	var result: Array = []
	for value in values:
		var id := int(value)
		if id > 0 and owned_lookup.has(id) and not result.has(id):
			result.append(id)
	var capacity := 0
	for container_value in containers:
		var container := _copy_dict(container_value)
		capacity += maxi(0, int(container.get("capacity", _container_capacity(str(container.get("item_id", ""))))))
	if tier != HOUSING_BACK_ALLEY and result.size() > capacity:
		result.resize(capacity)
	return result


func _owned_instance_ids() -> Array:
	var ids: Array = []
	for instance_value in _copy_array(_store.get("owned_instances", [])):
		var instance := _copy_dict(instance_value)
		var id := int(instance.get("instance_id", 0))
		if id > 0 and not ids.has(id):
			ids.append(id)
	return ids


func _loadout_eligible_owned_instance_ids() -> Array:
	var resolver: Variant = CollectionItemResolverScript.new()
	var ids: Array = []
	for instance_value in _copy_array(_store.get("owned_instances", [])):
		var instance := _copy_dict(instance_value)
		var id := int(instance.get("instance_id", 0))
		if id > 0 and resolver.is_loadout_eligible(instance) and not ids.has(id):
			ids.append(id)
	return ids


func _owned_instance(instance_id: int) -> Dictionary:
	for instance_value in _copy_array(_store.get("owned_instances", [])):
		var instance := _copy_dict(instance_value)
		if int(instance.get("instance_id", 0)) == instance_id:
			return instance
	return {}


func _remove_bag(instance_id: int) -> bool:
	var bags := _copy_array(_store.get("unopened_bags", []))
	var next_bags: Array = []
	var removed := false
	for bag_value in bags:
		var bag := _copy_dict(bag_value)
		if int(bag.get("instance_id", 0)) == instance_id:
			removed = true
			continue
		next_bags.append(bag)
	_store["unopened_bags"] = next_bags
	return removed


func _item_sale_quote(instance_id: int) -> Dictionary:
	var instance := _owned_instance(instance_id)
	if instance.is_empty():
		return {"ok": false, "message": "That item is not owned."}
	var resolver: Variant = CollectionItemResolverScript.new()
	var definition: Dictionary = resolver.item_definition(int(instance.get("itemdef_id", -1)))
	if definition.is_empty():
		return {"ok": false, "message": "That item cannot be sold."}
	if resolver.is_chip_stack_instance(instance):
		var face_value := maxi(0, int(instance.get("face_value", instance.get("stack_amount", 0))))
		var policy := _copy_dict(definition.get("sale_policy", {}))
		var gold_rate := clampf(float(policy.get("gold_rate", 0.6)), 0.0, 1.0)
		var fenced_price := maxi(1, int(round(float(face_value) * gold_rate))) if face_value > 0 else 0
		return {
			"ok": fenced_price > 0,
			"kind": SALE_KIND_ITEM,
			"instance_id": instance_id,
			"price": fenced_price,
			"display_name": str(definition.get("display_name", "Grand Casino Chips")),
			"tier": str(definition.get("tier", "gold")),
			"face_value": face_value,
			"gold_rate": gold_rate,
		}
	var breakdown := ordinary_collection_price_breakdown(instance, LISTING_MODE_PAWN)
	if not bool(breakdown.get("ok", false)):
		return breakdown
	breakdown["kind"] = SALE_KIND_ITEM
	return breakdown


func _bag_sale_quote(instance_id: int) -> Dictionary:
	var bag := {}
	for bag_value in _copy_array(_store.get("unopened_bags", [])):
		var candidate := _copy_dict(bag_value)
		if int(candidate.get("instance_id", 0)) == instance_id:
			bag = candidate
			break
	if bag.is_empty():
		return {"ok": false, "message": "That bag is not unopened."}
	var resolver: Variant = CollectionItemResolverScript.new()
	var definition: Dictionary = resolver.bag_definition(int(bag.get("bagdef_id", -1)))
	var tier := str(definition.get("tier", bag.get("tier", "blue")))
	var prices := _copy_dict(_copy_dict(_meta_home_config().get("sale_prices", {})).get("bags", {}))
	return {
		"ok": true,
		"kind": SALE_KIND_BAG,
		"instance_id": instance_id,
		"price": maxi(1, int(prices.get(tier, 1))),
		"display_name": str(definition.get("display_name", bag.get("display_name", "Collection Bag"))),
		"tier": tier,
	}


func _next_collection_tier(tier: String) -> String:
	var index := CollectionItemResolverScript.TIERS.find(tier)
	if index < 0 or index >= CollectionItemResolverScript.TIERS.size() - 1:
		return ""
	return str(CollectionItemResolverScript.TIERS[index + 1])


func _mean_trade_up_instance(itemdef_id: int, instances: Array) -> Dictionary:
	var result := {
		"itemdef_id": itemdef_id,
		"potency": 0.0,
		"condition": 0.0,
		"resonance": 0.0,
		"usage": 0.0,
	}
	if instances.is_empty():
		return result
	for float_key in CollectionItemResolverScript.FLOAT_KEYS:
		var total := 0.0
		for instance_value in instances:
			var instance := _copy_dict(instance_value)
			total += clampf(float(instance.get(float_key, 0.0)), 0.0, 1.0)
		result[float_key] = clampf(total / float(instances.size()), 0.0, 1.0)
	return result


func _container_capacity(item_id: String) -> int:
	_ensure_items_loaded()
	var item := _copy_dict(_item_definitions_by_id.get(item_id.strip_edges(), {}))
	return maxi(0, int(item.get("container_capacity", 0)))


func _ensure_items_loaded() -> void:
	if _items_loaded:
		return
	_items_loaded = true
	_item_definitions_by_id = {}
	if not FileAccess.file_exists(ITEMS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		return
	for item_value in parsed as Array:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		var id := str(item.get("id", "")).strip_edges()
		if id.is_empty():
			continue
		_item_definitions_by_id[id] = item.duplicate(true)


func _max_recorded_instance_id(data: Dictionary) -> int:
	var max_id := 0
	for instance_value in _copy_array(data.get("owned_instances", [])):
		var instance := _copy_dict(instance_value)
		max_id = maxi(max_id, int(instance.get("instance_id", 0)))
	for bag_value in _copy_array(data.get("unopened_bags", [])):
		var bag := _copy_dict(bag_value)
		max_id = maxi(max_id, int(bag.get("instance_id", 0)))
	var resale := _copy_dict(data.get("sal_resale", {}))
	for slot_value in _copy_array(resale.get("slots", [])):
		var slot := _copy_dict(slot_value)
		max_id = maxi(max_id, int(_copy_dict(slot.get("item", {})).get("instance_id", 0)))
	max_id = maxi(max_id, int(_copy_dict(_copy_dict(resale.get("pending_starter_buyback", {})).get("item", {})).get("instance_id", 0)))
	return max_id


func _default_store() -> Dictionary:
	return _normalize_store({
		"schema_version": SCHEMA_VERSION,
		"owned_instances": [],
		"unopened_bags": [],
		"gold_balance": 0,
		"housing_tier": HOUSING_BACK_ALLEY,
		"owned_containers": [{"item_id": "bag", "instance_id": 0, "capacity": 3}],
		"loadout": [],
		"meta_home": {"housing_tier": HOUSING_BACK_ALLEY, "current_location": "home"},
		"trade_up_history": [],
		"sale_history": [],
		"pending_sale": {},
		"pending_trade_up": {},
		"meta_rng": {
			"seed": 904613,
			"state": 904613,
		},
		"next_instance_id": FIRST_INSTANCE_ID,
	})


static func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var dictionary: Dictionary = value
	return dictionary.duplicate(true)


func _collection_resolver() -> CollectionItemResolver:
	if _shared_collection_resolver == null:
		_shared_collection_resolver = CollectionItemResolverScript.new()
	return _shared_collection_resolver


static func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var array: Array = value
	return array.duplicate(true)
