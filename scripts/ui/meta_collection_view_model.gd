class_name MetaCollectionViewModel
extends RefCounted

const CollectionItemResolverScript := preload("res://scripts/core/collection_item_resolver.gd")


static func build(meta_service: Variant) -> Dictionary:
	var resolver: Variant = CollectionItemResolverScript.new()
	var snapshot := _service_snapshot(meta_service)
	var owned_instances := _copy_array(snapshot.get("owned_instances", []))
	var unopened_bags := _bag_rows(resolver, _copy_array(snapshot.get("unopened_bags", [])))
	var owned_by_itemdef := _owned_by_itemdef(owned_instances)
	var home := _home_view(meta_service, snapshot)
	var collections: Array = []
	for collection_value in resolver.collections():
		var collection := _copy_dict(collection_value)
		var item_rows: Array = []
		for item_value in _copy_array(collection.get("items", [])):
			var definition := _copy_dict(item_value)
			var itemdef_id := int(definition.get("itemdef_id", -1))
			item_rows.append(_item_row(resolver, definition, _copy_array(owned_by_itemdef.get(itemdef_id, []))))
		collections.append({
			"id": str(collection.get("id", "")),
			"display_name": str(collection.get("display_name", "Collection")),
			"theme": str(collection.get("theme", "")),
			"owned_count": _owned_count_for_collection(collection, owned_by_itemdef),
			"total_count": item_rows.size(),
			"items": item_rows,
		})
	return {
		"title": "Home",
		"summary": "%s - %d owned, %d unopened bag%s, %d gold." % [
			str(home.get("display_name", "Back Alley")),
			owned_instances.size(),
			unopened_bags.size(),
			"" if unopened_bags.size() == 1 else "s",
			int(snapshot.get("gold_balance", 0)),
		],
		"home": home,
		"owned_count": owned_instances.size(),
		"bag_count": unopened_bags.size(),
		"gold_balance": int(snapshot.get("gold_balance", 0)),
		"collections": collections,
		"unopened_bags": unopened_bags,
	}


static func _home_view(meta_service: Variant, snapshot: Dictionary) -> Dictionary:
	var housing_tier := str(snapshot.get("housing_tier", "back_alley"))
	var definition: Dictionary = meta_service.housing_definition(housing_tier) if meta_service != null and meta_service.has_method("housing_definition") else {}
	var upgrade: Dictionary = meta_service.next_housing_upgrade() if meta_service != null and meta_service.has_method("next_housing_upgrade") else {}
	var carried_ids: Array = meta_service.carried_instance_ids() if meta_service != null and meta_service.has_method("carried_instance_ids") else []
	return {
		"housing_tier": housing_tier,
		"display_name": str(definition.get("display_name", housing_tier.capitalize())),
		"storage_slots": int(meta_service.storage_slots()) if meta_service != null and meta_service.has_method("storage_slots") else 0,
		"carry_capacity": int(meta_service.carry_capacity()) if meta_service != null and meta_service.has_method("carry_capacity") else 0,
		"total_capacity": int(meta_service.total_owned_capacity()) if meta_service != null and meta_service.has_method("total_owned_capacity") else 0,
		"trade_up_unlocked": bool(meta_service.trade_up_unlocked()) if meta_service != null and meta_service.has_method("trade_up_unlocked") else false,
		"carried_count": carried_ids.size(),
		"upgrade": upgrade,
		"map_nodes": [
			{"id": "home", "label": "Home", "kind": "home", "selected": true},
			{"id": "pawn_shop", "label": "Sal's Pawn Shop", "kind": "pawn_shop", "selected": false},
		],
		"pawn_shop": {"interaction": "buy_and_sell", "shelf_slots": 6},
	}


static func _item_row(resolver: Variant, definition: Dictionary, instances: Array) -> Dictionary:
	var owned_rows: Array = []
	for instance_value in instances:
		var instance := _copy_dict(instance_value)
		var band: Dictionary = resolver.condition_band(definition, instance)
		owned_rows.append({
			"instance_id": int(instance.get("instance_id", 0)),
			"condition_band": str(band.get("display_name", band.get("id", "Unknown"))),
			"float_summary": _float_summary(instance),
			"floats": {
				"potency": clampf(float(instance.get("potency", 0.0)), 0.0, 1.0),
				"condition": clampf(float(instance.get("condition", 0.0)), 0.0, 1.0),
				"resonance": clampf(float(instance.get("resonance", 0.0)), 0.0, 1.0),
				"usage": clampf(float(instance.get("usage", 0.0)), 0.0, 1.0),
			},
		})
	return {
		"itemdef_id": int(definition.get("itemdef_id", -1)),
		"id": str(definition.get("id", "")),
		"display_name": str(definition.get("display_name", "Collection Item")),
		"tier": str(definition.get("tier", "")),
		"tier_label": str(definition.get("tier", "")).capitalize(),
		"icon_key": str(definition.get("icon_key", "")),
		"flavor": str(definition.get("flavor", "")),
		"owned": not owned_rows.is_empty(),
		"owned_count": owned_rows.size(),
		"owned_instances": owned_rows,
		"tier_badges": [_tier_badge(str(definition.get("tier", "")))],
	}


static func _bag_rows(resolver: Variant, bags: Array) -> Array:
	var rows: Array = []
	for bag_value in bags:
		var bag := _copy_dict(bag_value)
		var definition: Dictionary = resolver.bag_definition(int(bag.get("bagdef_id", -1)))
		var collection: Dictionary = resolver.collection_definition(str(definition.get("collection_id", bag.get("collection_id", ""))))
		var tier := str(definition.get("tier", bag.get("tier", "")))
		rows.append({
			"instance_id": int(bag.get("instance_id", 0)),
			"bagdef_id": int(bag.get("bagdef_id", -1)),
			"display_name": str(definition.get("display_name", bag.get("display_name", "Collection Bag"))),
			"collection_id": str(definition.get("collection_id", bag.get("collection_id", ""))),
			"collection_display_name": str(collection.get("display_name", bag.get("collection_display_name", "Collection"))),
			"tier": tier,
			"tier_label": tier.capitalize(),
			"icon_key": str(definition.get("icon_key", bag.get("icon_key", ""))),
			"source": str(bag.get("source", "")),
			"source_id": str(bag.get("source_id", "")),
			"tier_badges": [_tier_badge(tier)],
		})
	return rows


static func _owned_by_itemdef(instances: Array) -> Dictionary:
	var grouped: Dictionary = {}
	for instance_value in instances:
		var instance := _copy_dict(instance_value)
		var itemdef_id := int(instance.get("itemdef_id", -1))
		if itemdef_id < 0:
			continue
		var entries := _copy_array(grouped.get(itemdef_id, []))
		entries.append(instance)
		grouped[itemdef_id] = entries
	return grouped


static func _owned_count_for_collection(collection: Dictionary, owned_by_itemdef: Dictionary) -> int:
	var count := 0
	for item_value in _copy_array(collection.get("items", [])):
		var item := _copy_dict(item_value)
		count += _copy_array(owned_by_itemdef.get(int(item.get("itemdef_id", -1)), [])).size()
	return count


static func _service_snapshot(meta_service: Variant) -> Dictionary:
	if meta_service == null:
		return {}
	return _copy_dict(meta_service.snapshot())


static func _float_summary(instance: Dictionary) -> String:
	return "P %d%% / C %d%% / R %d%% / U %d%%" % [
		int(round(clampf(float(instance.get("potency", 0.0)), 0.0, 1.0) * 100.0)),
		int(round(clampf(float(instance.get("condition", 0.0)), 0.0, 1.0) * 100.0)),
		int(round(clampf(float(instance.get("resonance", 0.0)), 0.0, 1.0) * 100.0)),
		int(round(clampf(float(instance.get("usage", 0.0)), 0.0, 1.0) * 100.0)),
	]


static func _tier_badge(tier: String) -> Dictionary:
	var clean_tier := tier.strip_edges().to_lower()
	return {
		"glyph_id": "collection_tier",
		"value_text": clean_tier.capitalize(),
		"polarity": "positive",
		"tooltip": "%s collection tier" % clean_tier.capitalize(),
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
