class_name MetaItemInteractionViewModel
extends RefCounted

const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")

const CollectionItemResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const AttributeBadgesScript := preload("res://scripts/core/attribute_badges.gd")
const BADGE_CACHE_LIMIT := 256
const ASSET_PATH_CACHE_LIMIT := 256

const MODE_CONTAINER := "meta_container"
const MODE_BAGS := "meta_bags"
const MODE_SALE := "meta_sale"
const MODE_TRADE := "meta_trade"

static var _badge_cache: Dictionary = {}
static var _asset_path_cache: Dictionary = {}


static func build(meta_service: Variant, mode: String, selected_key: String = "", trade_selected_ids: Array = []) -> Dictionary:
	var resolver: Variant = CollectionItemResolverScript.new()
	var snapshot: Dictionary = {}
	if meta_service != null:
		if meta_service.has_method("presentation_snapshot"):
			snapshot = meta_service.presentation_snapshot()
		elif meta_service.has_method("snapshot"):
			snapshot = meta_service.snapshot()
	var owned := JsonCoerceScript._dictionary_array(snapshot.get("owned_instances", []))
	var valid_trade_selected_ids := _valid_trade_selection(resolver, owned, trade_selected_ids)
	var carried_ids: Array = meta_service.carried_instance_ids() if meta_service != null and meta_service.has_method("carried_instance_ids") else []
	var item_models := _owned_item_models(meta_service, resolver, owned, carried_ids, mode, valid_trade_selected_ids)
	var bag_models := _bag_models(meta_service, resolver, JsonCoerceScript._dictionary_array(snapshot.get("unopened_bags", [])), mode)
	var container_key := "meta_collection_storage"
	var container_label := "Home Storage"
	var visible_items: Array = []
	match mode:
		MODE_BAGS:
			container_key = "meta_bags"
			container_label = "Unopened Bags"
			visible_items = _sorted_meta_items(bag_models)
		MODE_SALE:
			var sale_items: Array = []
			for item in item_models:
				if bool((item as Dictionary).get("sale_eligible", false)):
					sale_items.append(item)
			sale_items.append_array(bag_models)
			container_key = "meta_sale"
			container_label = "Sale Items and Bags"
			visible_items = _sorted_meta_items(sale_items)
		MODE_TRADE:
			var trade_items: Array = []
			for item in item_models:
				if bool((item as Dictionary).get("trade_visible", false)):
					trade_items.append(item)
			container_key = "meta_trade"
			container_label = "Trade-Up Items"
			visible_items = _sorted_meta_items(trade_items)
		_:
			visible_items = _sorted_meta_items(item_models)
	# Every mode exposes one container. Reusing the sorted projection as the flat
	# item list avoids walking thousands of slots three more times merely to
	# rediscover selection and the already-known container key.
	var containers: Array = [_dynamic_container(container_key, "home_storage", container_label, visible_items)]
	var selection_found := false
	for item_value in visible_items:
		if typeof(item_value) == TYPE_DICTIONARY and str((item_value as Dictionary).get("selection_key", "")) == selected_key:
			selection_found = true
			break
	var resolved_key := selected_key if selection_found else str((visible_items[0] as Dictionary).get("selection_key", "")) if not visible_items.is_empty() else ""
	var global_actions: Array = []
	if mode == MODE_TRADE and valid_trade_selected_ids.size() == 5:
		global_actions.append({
			"id": "arm_trade",
			"label": "Arm Trade-Up",
			"payload": {"instance_ids": JsonCoerceScript._int_array(valid_trade_selected_ids)},
			"permanent": true,
		})
	return {
		"mode": mode,
		"title": _title(mode),
		"summary": _summary(mode, visible_items.size(), valid_trade_selected_ids, int(snapshot.get("gold_balance", 0))),
		"containers": containers,
		"items": visible_items,
		"selected_key": resolved_key,
		"active_container_key": container_key,
		"multi_selected_keys": _trade_selection_keys(valid_trade_selected_ids),
		"global_actions": global_actions,
		"trade_selected_ids": JsonCoerceScript._int_array(valid_trade_selected_ids),
		"trade_summary": _trade_summary(visible_items, valid_trade_selected_ids),
		"gold_balance": int(snapshot.get("gold_balance", 0)),
		"empty_text": _empty_text(mode),
		"layout": {"presentation": "grouped_card_grid", "stable_view": true, "grouping": "collection_tier_storage"},
	}


static func _valid_trade_selection(resolver: Variant, owned: Array, requested_ids: Array) -> Array:
	var instances_by_id: Dictionary = {}
	for value in owned:
		var instance: Dictionary = value
		instances_by_id[int(instance.get("instance_id", 0))] = instance
	var result: Array = []
	var collection_id := ""
	var tier := ""
	for id_value in JsonCoerceScript._int_array(requested_ids):
		var instance_id := int(id_value)
		if result.has(instance_id) or not instances_by_id.has(instance_id):
			continue
		var definition: Dictionary = resolver.item_definition(int((instances_by_id[instance_id] as Dictionary).get("itemdef_id", -1)))
		if definition.is_empty() or str(definition.get("item_class", CollectionItemResolverScript.ITEM_CLASS_COLLECTION)) != CollectionItemResolverScript.ITEM_CLASS_COLLECTION:
			continue
		if result.is_empty():
			collection_id = str(definition.get("collection_id", ""))
			tier = str(definition.get("tier", ""))
		elif str(definition.get("collection_id", "")) != collection_id or str(definition.get("tier", "")) != tier:
			continue
		result.append(instance_id)
		if result.size() >= 5:
			break
	return result


static func _owned_item_models(meta_service: Variant, resolver: Variant, owned: Array, carried_ids: Array, mode: String, trade_selected_ids: Array) -> Array:
	var result: Array = []
	# Large collections contain many instances of the same small definition set.
	# Resolver access returns an owned deep copy, so cache one copy per definition
	# and collection for this immutable projection instead of cloning it per item.
	var definitions_by_id: Dictionary = {}
	var collections_by_id: Dictionary = {}
	var trade_position_by_id: Dictionary = {}
	for trade_index in range(trade_selected_ids.size()):
		trade_position_by_id[int(trade_selected_ids[trade_index])] = trade_index + 1
	var carried_lookup := {}
	for carried_id in carried_ids:
		carried_lookup[int(carried_id)] = true
	var first_trade_definition: Dictionary = {}
	if not trade_selected_ids.is_empty():
		for instance_value in owned:
			var candidate: Dictionary = instance_value
			if int(candidate.get("instance_id", 0)) == int(trade_selected_ids[0]):
				first_trade_definition = _cached_item_definition(resolver, definitions_by_id, int(candidate.get("itemdef_id", -1)))
				break
	for instance_value in owned:
		var instance: Dictionary = instance_value
		var instance_id := int(instance.get("instance_id", 0))
		var definition: Dictionary = _cached_item_definition(resolver, definitions_by_id, int(instance.get("itemdef_id", -1)))
		if definition.is_empty():
			continue
		var collection: Dictionary = _cached_collection_definition(resolver, collections_by_id, str(definition.get("collection_id", "")))
		var item_class := str(definition.get("item_class", CollectionItemResolverScript.ITEM_CLASS_COLLECTION))
		var presentation_definition := definition
		var presentation_tier := str(definition.get("tier", ""))
		var presentation_description := str(definition.get("flavor", ""))
		if item_class == CollectionItemResolverScript.ITEM_CLASS_PLAYERS_CARD:
			var instance_data: Dictionary = instance.get("instance_data", {}) if typeof(instance.get("instance_data", {})) == TYPE_DICTIONARY else {}
			var earned_tier := str(instance_data.get("tier_reached", "")).strip_edges().to_lower()
			if earned_tier in ["bronze", "silver", "gold"]:
				presentation_tier = earned_tier
				presentation_description = "Linda's %s card, stamped with the run that paid for it." % earned_tier.capitalize()
				presentation_definition = definition.duplicate(false)
				presentation_definition["tier"] = earned_tier
		var quote: Dictionary = meta_service.sale_quote(MetaCollectionServiceScript.SALE_KIND_ITEM, instance_id) if mode == MODE_SALE and meta_service != null and meta_service.has_method("sale_quote") else {}
		var packed := carried_lookup.has(instance_id)
		var packable := bool(definition.get("loadout_eligible", true))
		var trade_visible := item_class == CollectionItemResolverScript.ITEM_CLASS_COLLECTION
		var trade_compatible := trade_visible
		var trade_reason := ""
		if mode == MODE_TRADE and trade_visible and not first_trade_definition.is_empty():
			trade_compatible = (
				str(definition.get("collection_id", "")) == str(first_trade_definition.get("collection_id", ""))
				and str(definition.get("tier", "")) == str(first_trade_definition.get("tier", ""))
			)
			if not trade_compatible:
				trade_reason = "Choose the same collection and tier as the first trade item."
		var selection_key := "meta:item:%d" % instance_id
		var actions: Array = []
		if mode == MODE_CONTAINER and packable:
			actions.append({"id": "unpack" if packed else "pack", "label": "Unpack" if packed else "Pack", "payload": {"instance_id": instance_id}})
		elif mode == MODE_SALE and bool(quote.get("ok", false)):
			actions.append({"id": "arm_sale", "label": "Sell for %d gold" % int(quote.get("price", 0)), "payload": {"kind": MetaCollectionServiceScript.SALE_KIND_ITEM, "instance_id": instance_id}, "permanent": true})
		elif mode == MODE_TRADE and trade_visible:
			var selected_index := JsonCoerceScript._int_array(trade_selected_ids).find(instance_id)
			actions.append({
				"id": "toggle_trade",
				"label": "Remove from Trade" if selected_index >= 0 else "Select for Trade",
				"payload": {"instance_id": instance_id},
				"enabled": selected_index >= 0 or (trade_compatible and trade_selected_ids.size() < 5),
				"disabled_reason": trade_reason if not trade_compatible else "Five items are already selected." if trade_selected_ids.size() >= 5 and selected_index < 0 else "",
			})
		var band: Dictionary = resolver.condition_band(definition, instance)
		var item_disabled_reason := trade_reason
		if mode == MODE_CONTAINER and not packable:
			item_disabled_reason = "This meta-only item stays in home storage."
		result.append({
			"id": str(definition.get("id", "meta_item")),
			"instance_id": instance_id,
			"itemdef_id": int(instance.get("itemdef_id", -1)),
			"selection_key": selection_key,
			"display_name": str(definition.get("display_name", "Collection Item")),
			"description": presentation_description,
			"collection_display_name": str(collection.get("display_name", "Grand Casino Rewards" if item_class != CollectionItemResolverScript.ITEM_CLASS_COLLECTION else "Collection")),
			"collection_id": str(definition.get("collection_id", "")),
			"tier": presentation_tier,
			"group_label": "%s · %s · %s" % [
				str(collection.get("display_name", "Collection")),
				presentation_tier.capitalize(),
				"Carried" if packed else "Stored",
			],
			"count": 1,
			"item_class": item_class,
			"domain": "meta",
			"icon_key": str(definition.get("icon_key", "")),
			"asset_path": _asset_path_for_icon(str(definition.get("icon_key", ""))),
			"storage_source": "carried" if packed else "stored",
			"packed": packed,
			"packable": packable,
			"condition_band": str(band.get("display_name", band.get("id", "Unknown"))),
			"floats": {
				"potency": clampf(float(instance.get("potency", 0.0)), 0.0, 1.0),
				"condition": clampf(float(instance.get("condition", 0.0)), 0.0, 1.0),
				"resonance": clampf(float(instance.get("resonance", 0.0)), 0.0, 1.0),
				"usage": clampf(float(instance.get("usage", 0.0)), 0.0, 1.0),
			},
			"attribute_badges": _cached_attribute_badges(presentation_definition, mode, int(instance.get("itemdef_id", -1)), item_class, int(quote.get("price", 0))),
			"sale_eligible": bool(quote.get("ok", false)),
			"sale_price": int(quote.get("price", 0)),
			"sale_breakdown": quote.duplicate(true),
			"trade_visible": trade_visible,
			"trade_compatible": trade_compatible,
			"disabled_reason": item_disabled_reason,
			"actions": actions,
			"state_marker": str(trade_position_by_id.get(instance_id, "")),
		})
	return result


static func _bag_models(meta_service: Variant, resolver: Variant, bags: Array, mode: String) -> Array:
	var result: Array = []
	for bag_value in bags:
		var bag: Dictionary = bag_value
		var instance_id := int(bag.get("instance_id", 0))
		var definition: Dictionary = resolver.bag_definition(int(bag.get("bagdef_id", -1)))
		var collection: Dictionary = resolver.collection_definition(str(definition.get("collection_id", bag.get("collection_id", ""))))
		var quote: Dictionary = meta_service.sale_quote(MetaCollectionServiceScript.SALE_KIND_BAG, instance_id) if mode == MODE_SALE and meta_service != null and meta_service.has_method("sale_quote") else {}
		var actions: Array = []
		if mode == MODE_BAGS:
			actions.append({"id": "open_bag", "label": "Open", "payload": {"instance_id": instance_id}})
		elif mode == MODE_SALE and bool(quote.get("ok", false)):
			actions.append({"id": "arm_sale", "label": "Sell for %d gold" % int(quote.get("price", 0)), "payload": {"kind": MetaCollectionServiceScript.SALE_KIND_BAG, "instance_id": instance_id}, "permanent": true})
		result.append({
			"id": str(definition.get("id", "collection_bag")),
			"instance_id": instance_id,
			"bagdef_id": int(bag.get("bagdef_id", -1)),
			"selection_key": "meta:bag:%d" % instance_id,
			"display_name": str(definition.get("display_name", bag.get("display_name", "Collection Bag"))),
			"description": str(definition.get("flavor", "An unopened collection bag.")),
			"collection_display_name": str(collection.get("display_name", "Collection")),
			"collection_id": str(definition.get("collection_id", bag.get("collection_id", ""))),
			"tier": str(definition.get("tier", bag.get("tier", ""))),
			"group_label": "Unopened Bags · %s · %s" % [str(collection.get("display_name", "Collection")), str(definition.get("tier", bag.get("tier", ""))).capitalize()],
			"count": 1,
			"item_class": "unopened_bag",
			"domain": "meta",
			"icon_key": str(definition.get("icon_key", "")),
			"asset_path": _asset_path_for_icon(str(definition.get("icon_key", ""))),
			"storage_source": "unopened",
			"source": str(bag.get("source", "bag")),
			"source_id": str(bag.get("source_id", "")),
			"sale_eligible": bool(quote.get("ok", false)),
			"sale_price": int(quote.get("price", 0)),
			"sale_breakdown": quote.duplicate(true),
			"attribute_badges": _cached_attribute_badges(definition, mode, -int(bag.get("bagdef_id", -1)) - 1, "unopened_bag", int(quote.get("price", 0))),
			"actions": actions,
		})
	return result


static func _dynamic_container(key: String, container_type: String, display_name: String, items: Array) -> Dictionary:
	return {"key": key, "container_type": container_type, "display_name": display_name, "capacity": 0, "read_only": false, "slots": _slots(items)}


static func _slots(items: Array) -> Array:
	var result: Array = []
	for item_value in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		result.append({
			"slot_index": result.size(),
			"occupied": true,
			"selection_key": str(item.get("selection_key", "")),
			"item": item,
			"actionable": not JsonCoerceScript._dictionary_array(item.get("actions", [])).is_empty(),
			"disabled_reason": str(item.get("disabled_reason", "")),
			"state_marker": str(item.get("state_marker", "")),
		})
	return result


static func _sorted_meta_items(items: Array) -> Array:
	var result: Array = []
	for item_value in items:
		if typeof(item_value) == TYPE_DICTIONARY:
			result.append(item_value)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_group := str(a.get("group_label", a.get("collection_display_name", "")))
		var b_group := str(b.get("group_label", b.get("collection_display_name", "")))
		if a_group != b_group:
			return a_group < b_group
		var a_tier := _tier_rank(str(a.get("tier", "")))
		var b_tier := _tier_rank(str(b.get("tier", "")))
		if a_tier != b_tier:
			return a_tier < b_tier
		var a_name := str(a.get("display_name", ""))
		var b_name := str(b.get("display_name", ""))
		if a_name != b_name:
			return a_name < b_name
		return int(a.get("instance_id", 0)) < int(b.get("instance_id", 0))
	)
	return result


static func _tier_rank(tier: String) -> int:
	match tier.strip_edges().to_lower():
		"blue": return 10
		"purple": return 20
		"pink": return 30
		"red": return 40
		"gold": return 50
	return 0


static func _summary(mode: String, item_count: int, trade_selected_ids: Array, gold_balance: int) -> String:
	match mode:
		MODE_BAGS:
			if item_count <= 0:
				return "No unopened bags. Win a standard run to bring one home."
			return "%d unopened bag%s. Select one to inspect before opening." % [item_count, "" if item_count == 1 else "s"]
		MODE_SALE:
			if item_count <= 0:
				return "Nothing to sell yet. Sal's counter wakes up after your first haul."
			return "%d sale option%s. Sal pays in gold; you have %d." % [item_count, "" if item_count == 1 else "s", gold_balance]
		MODE_TRADE:
			if item_count <= 0:
				return "Trade-up needs five matching collection items. Win bags first."
			return "%d/5 selected. All five must share one collection and tier." % trade_selected_ids.size()
		_:
			if item_count <= 0:
				return "Your shelves are empty. Beat a route to bring home bags and permanent keepsakes."
			return "%d owned item%s. Switch containers to inspect, pack, or unpack." % [item_count, "" if item_count == 1 else "s"]


static func _title(mode: String) -> String:
	match mode:
		MODE_BAGS: return "Unopened Bags"
		MODE_SALE: return "Your Bag at Sal's Counter"
		MODE_TRADE: return "Trade-Up Station"
		_: return "Inventory and Storage"


static func _empty_text(mode: String) -> String:
	match mode:
		MODE_BAGS: return "No unopened bags. Win a standard run, then open the prize here."
		MODE_SALE: return "Nothing for Sal yet. Bring home bags or keepsakes first."
		MODE_TRADE: return "Trade-up needs five matching collection pieces. Keep cracking bags."
		_: return "No collection items yet. Start a run, beat a route, and bring something home."


static func _asset_path_for_icon(icon_key: String) -> String:
	var clean_key := icon_key.strip_edges()
	if clean_key.is_empty():
		return ""
	if _asset_path_cache.has(clean_key):
		return str(_asset_path_cache.get(clean_key, ""))
	var path := "res://assets/art/items/%s.png" % clean_key
	var resolved := path if ResourceLoader.exists(path) else ""
	if _asset_path_cache.size() >= ASSET_PATH_CACHE_LIMIT:
		_asset_path_cache.clear()
	_asset_path_cache[clean_key] = resolved
	return resolved


static func _cached_attribute_badges(definition: Dictionary, mode: String, definition_key: int, item_class: String, sale_price: int) -> Array:
	# Sale badges include an instance-specific quote. Other modes share authored
	# definition badges. Check that cache before creating a mutable badge context
	# so a large stack does not clone the same definition thousands of times.
	var cache_key := "%s|%d|%s" % [mode, definition_key, str(definition.get("tier", ""))]
	if mode != MODE_SALE and _badge_cache.has(cache_key):
		return _badge_cache.get(cache_key, [])
	var context := definition.duplicate(true)
	context["item_class"] = item_class
	context["domain"] = "meta"
	context["sale_price"] = sale_price
	var badges := AttributeBadgesScript.for_item(context)
	if mode == MODE_SALE:
		return badges
	if _badge_cache.size() >= BADGE_CACHE_LIMIT:
		_badge_cache.clear()
	_badge_cache[cache_key] = badges
	return badges


static func _trade_selection_keys(ids: Array) -> Array:
	var result: Array = []
	for id_value in ids:
		result.append("meta:item:%d" % int(id_value))
	return result


static func _trade_summary(items: Array, ids: Array) -> Array:
	var result: Array = []
	var wanted := JsonCoerceScript._int_array(ids)
	for index in range(wanted.size()):
		var instance_id := int(wanted[index])
		for item_value in items:
			if typeof(item_value) != TYPE_DICTIONARY or int((item_value as Dictionary).get("instance_id", 0)) != instance_id:
				continue
			result.append({
				"position": index + 1,
				"selection_key": str((item_value as Dictionary).get("selection_key", "")),
				"display_name": str((item_value as Dictionary).get("display_name", "Item")),
				"tier": str((item_value as Dictionary).get("tier", "")),
				"collection": str((item_value as Dictionary).get("collection_display_name", "Collection")),
			})
			break
	return result


static func _cached_item_definition(resolver: Variant, cache: Dictionary, itemdef_id: int) -> Dictionary:
	if not cache.has(itemdef_id):
		cache[itemdef_id] = resolver.item_definition(itemdef_id)
	return cache.get(itemdef_id, {}) as Dictionary


static func _cached_collection_definition(resolver: Variant, cache: Dictionary, collection_id: String) -> Dictionary:
	if not cache.has(collection_id):
		cache[collection_id] = resolver.collection_definition(collection_id)
	return cache.get(collection_id, {}) as Dictionary
