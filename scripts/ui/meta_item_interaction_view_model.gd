class_name MetaItemInteractionViewModel
extends RefCounted

const CollectionItemResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const AttributeBadgesScript := preload("res://scripts/core/attribute_badges.gd")
const BADGE_CACHE_LIMIT := 256

const MODE_CONTAINER := "meta_container"
const MODE_BAGS := "meta_bags"
const MODE_SALE := "meta_sale"
const MODE_TRADE := "meta_trade"

static var _badge_cache: Dictionary = {}


static func build(meta_service: Variant, mode: String, selected_key: String = "", trade_selected_ids: Array = []) -> Dictionary:
	var resolver: Variant = CollectionItemResolverScript.new()
	var snapshot: Dictionary = meta_service.snapshot() if meta_service != null and meta_service.has_method("snapshot") else {}
	var owned := _dictionary_array(snapshot.get("owned_instances", []))
	var valid_trade_selected_ids := _valid_trade_selection(resolver, owned, trade_selected_ids)
	var carried_ids: Array = meta_service.carried_instance_ids() if meta_service != null and meta_service.has_method("carried_instance_ids") else []
	var item_models := _owned_item_models(meta_service, resolver, owned, carried_ids, mode, valid_trade_selected_ids)
	var bag_models := _bag_models(meta_service, resolver, _dictionary_array(snapshot.get("unopened_bags", [])), mode)
	var containers: Array = []
	match mode:
		MODE_BAGS:
			containers = [_dynamic_container("meta_bags", "home_storage", "Unopened Bags", _sorted_meta_items(bag_models))]
		MODE_SALE:
			var sale_items: Array = []
			for item in item_models:
				if bool((item as Dictionary).get("sale_eligible", false)):
					sale_items.append(item)
			sale_items.append_array(bag_models)
			containers = [_dynamic_container("meta_sale", "home_storage", "Sale Items and Bags", _sorted_meta_items(sale_items))]
		MODE_TRADE:
			var trade_items: Array = []
			for item in item_models:
				if bool((item as Dictionary).get("trade_visible", false)):
					trade_items.append(item)
			containers = [_dynamic_container("meta_trade", "home_storage", "Trade-Up Items", _sorted_meta_items(trade_items))]
		_:
			containers = [_dynamic_container("meta_collection_storage", "home_storage", "Home Storage", _sorted_meta_items(item_models))]
	var all_items := _flatten_container_items(containers)
	var resolved_key := selected_key if _contains_selection(containers, selected_key) else _first_selection(containers)
	var global_actions: Array = []
	if mode == MODE_TRADE and valid_trade_selected_ids.size() == 5:
		global_actions.append({
			"id": "arm_trade",
			"label": "Arm Trade-Up",
			"payload": {"instance_ids": _int_array(valid_trade_selected_ids)},
			"permanent": true,
		})
	return {
		"mode": mode,
		"title": _title(mode),
		"summary": _summary(meta_service, mode, all_items.size(), valid_trade_selected_ids),
		"containers": containers,
		"items": all_items,
		"selected_key": resolved_key,
		"active_container_key": _container_key_for_selection(containers, resolved_key),
		"multi_selected_keys": _trade_selection_keys(valid_trade_selected_ids),
		"global_actions": global_actions,
		"trade_selected_ids": _int_array(valid_trade_selected_ids),
		"trade_summary": _trade_summary(all_items, valid_trade_selected_ids),
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
	for id_value in _int_array(requested_ids):
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
	var carried_lookup := {}
	for carried_id in carried_ids:
		carried_lookup[int(carried_id)] = true
	var first_trade_definition: Dictionary = {}
	if not trade_selected_ids.is_empty():
		for instance_value in owned:
			var candidate: Dictionary = instance_value
			if int(candidate.get("instance_id", 0)) == int(trade_selected_ids[0]):
				first_trade_definition = resolver.item_definition(int(candidate.get("itemdef_id", -1)))
				break
	for instance_value in owned:
		var instance: Dictionary = instance_value
		var instance_id := int(instance.get("instance_id", 0))
		var definition: Dictionary = resolver.item_definition(int(instance.get("itemdef_id", -1)))
		if definition.is_empty():
			continue
		var collection: Dictionary = resolver.collection_definition(str(definition.get("collection_id", "")))
		var item_class := str(definition.get("item_class", CollectionItemResolverScript.ITEM_CLASS_COLLECTION))
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
			var selected_index := _int_array(trade_selected_ids).find(instance_id)
			actions.append({
				"id": "toggle_trade",
				"label": "Remove from Trade" if selected_index >= 0 else "Select for Trade",
				"payload": {"instance_id": instance_id},
				"enabled": selected_index >= 0 or (trade_compatible and trade_selected_ids.size() < 5),
				"disabled_reason": trade_reason if not trade_compatible else "Five items are already selected." if trade_selected_ids.size() >= 5 and selected_index < 0 else "",
			})
		var band: Dictionary = resolver.condition_band(definition, instance)
		var badge_context := definition.duplicate(true)
		badge_context["item_class"] = item_class
		badge_context["domain"] = "meta"
		badge_context["sale_price"] = int(quote.get("price", 0))
		var item_disabled_reason := trade_reason
		if mode == MODE_CONTAINER and not packable:
			item_disabled_reason = "This meta-only item stays in home storage."
		result.append({
			"id": str(definition.get("id", "meta_item")),
			"instance_id": instance_id,
			"itemdef_id": int(instance.get("itemdef_id", -1)),
			"selection_key": selection_key,
			"display_name": str(definition.get("display_name", "Collection Item")),
			"description": str(definition.get("flavor", "")),
			"collection_display_name": str(collection.get("display_name", "Grand Casino Rewards" if item_class != CollectionItemResolverScript.ITEM_CLASS_COLLECTION else "Collection")),
			"collection_id": str(definition.get("collection_id", "")),
			"tier": str(definition.get("tier", "")),
			"group_label": "%s · %s · %s" % [
				str(collection.get("display_name", "Collection")),
				str(definition.get("tier", "")).capitalize(),
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
			"attribute_badges": _cached_attribute_badges(badge_context, mode, int(instance.get("itemdef_id", -1))),
			"sale_eligible": bool(quote.get("ok", false)),
			"sale_price": int(quote.get("price", 0)),
			"sale_breakdown": quote.duplicate(true),
			"trade_visible": trade_visible,
			"trade_compatible": trade_compatible,
			"disabled_reason": item_disabled_reason,
			"actions": actions,
			"state_marker": str(_int_array(trade_selected_ids).find(instance_id) + 1) if _int_array(trade_selected_ids).has(instance_id) else "",
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
		var bag_badge_context := definition.duplicate(true)
		bag_badge_context["item_class"] = "unopened_bag"
		bag_badge_context["domain"] = "meta"
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
			"attribute_badges": _cached_attribute_badges(bag_badge_context, mode, -int(bag.get("bagdef_id", -1)) - 1),
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
			"actionable": not _dictionary_array(item.get("actions", [])).is_empty(),
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


static func _flatten_container_items(containers: Array) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for container_value in containers:
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		for slot_value in _dictionary_array((container_value as Dictionary).get("slots", [])):
			var key := str(slot_value.get("selection_key", ""))
			if key.is_empty() or seen.has(key):
				continue
			seen[key] = true
			if typeof(slot_value.get("item", {})) == TYPE_DICTIONARY:
				result.append(slot_value.get("item"))
	return result


static func _summary(meta_service: Variant, mode: String, item_count: int, trade_selected_ids: Array) -> String:
	match mode:
		MODE_BAGS:
			if item_count <= 0:
				return "No unopened bags. Win a standard run to bring one home."
			return "%d unopened bag%s. Select one to inspect before opening." % [item_count, "" if item_count == 1 else "s"]
		MODE_SALE:
			var gold := int(meta_service.snapshot().get("gold_balance", 0)) if meta_service != null and meta_service.has_method("snapshot") else 0
			if item_count <= 0:
				return "Nothing to sell yet. Sal's counter wakes up after your first haul."
			return "%d sale option%s. Sal pays in gold; you have %d." % [item_count, "" if item_count == 1 else "s", gold]
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
	var path := "res://assets/art/items/%s.png" % clean_key
	return path if ResourceLoader.exists(path) else ""


static func _cached_attribute_badges(context: Dictionary, mode: String, definition_key: int) -> Array:
	# Sale badges include an instance-specific quote. Other modes share authored
	# definition badges, so building them once prevents a large stack of the same
	# item from repeating identical formatting work thousands of times.
	if mode == MODE_SALE:
		return AttributeBadgesScript.for_item(context)
	var cache_key := "%s|%d" % [mode, definition_key]
	if _badge_cache.has(cache_key):
		return _badge_cache.get(cache_key, [])
	var badges := AttributeBadgesScript.for_item(context)
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
	var wanted := _int_array(ids)
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


static func _contains_selection(containers: Array, selection_key: String) -> bool:
	if selection_key.is_empty():
		return false
	for container_value in containers:
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		for slot_value in _dictionary_array((container_value as Dictionary).get("slots", [])):
			if str(slot_value.get("selection_key", "")) == selection_key:
				return true
	return false


static func _first_selection(containers: Array) -> String:
	for container_value in containers:
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		for slot_value in _dictionary_array((container_value as Dictionary).get("slots", [])):
			var key := str(slot_value.get("selection_key", ""))
			if not key.is_empty():
				return key
	return ""


static func _container_key_for_selection(containers: Array, selection_key: String) -> String:
	for container_value in containers:
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		var container: Dictionary = container_value
		for slot_value in _dictionary_array(container.get("slots", [])):
			if str(slot_value.get("selection_key", "")) == selection_key:
				return str(container.get("key", ""))
	return str((containers[0] as Dictionary).get("key", "")) if not containers.is_empty() else ""


static func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


static func _int_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		result.append(int(entry))
	return result
