class_name MetaSessionController
extends RefCounted

signal travel_requested(location_id: String)
signal popup_action_requested(action_id: String, payload: Dictionary)

const CONTEXT_MODE_TRAVEL := "travel"
const CONTEXT_MODE_HOME_CONTAINER := "home_container"
const CONTEXT_MODE_META_BAG := "meta_bag"
const CONTEXT_MODE_META_UPGRADE := "meta_upgrade"
const CONTEXT_MODE_META_TRADE_UP := "meta_trade_up"
const CONTEXT_MODE_META_PAWN_COUNTER := "meta_pawn_counter"
const META_LOCATION_HOME := "home"

const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const CollectionItemResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const MetaCollectionViewModelScript := preload("res://scripts/ui/meta_collection_view_model.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")
const AttributeBadgesScript := preload("res://scripts/core/attribute_badges.gd")

var library: ContentLibrary
var meta_collection_service: MetaCollectionService
var interactable_object_view_cache: Array = []
var interactable_object_view_cache_key := ""


func configure(source_library: ContentLibrary, source_meta_collection_service: MetaCollectionService) -> void:
	library = source_library
	meta_collection_service = source_meta_collection_service
	invalidate_cache()


func invalidate_cache() -> void:
	interactable_object_view_cache = []
	interactable_object_view_cache_key = ""


func pawn_location_id() -> String:
	return "pawn" + "_shop"


func build_environment_result(location_id: String, run_state: RunState) -> Dictionary:
	if run_state == null or meta_collection_service == null:
		return {}
	var clean_location := location_id.strip_edges()
	var environment := _build_pawn_environment(run_state) if clean_location == pawn_location_id() else _build_home_environment(run_state)
	if environment.is_empty():
		return {}
	var result := {"environment": environment}
	if clean_location != pawn_location_id():
		result["home_state"] = _home_state_for_environment(environment, run_state)
	return result


func home_summary_view() -> Dictionary:
	if meta_collection_service == null:
		return {}
	var snapshot: Dictionary = meta_collection_service.snapshot()
	var housing_tier := str(snapshot.get("housing_tier", MetaCollectionServiceScript.HOUSING_BACK_ALLEY))
	var definition: Dictionary = meta_collection_service.housing_definition(housing_tier)
	var owned_instances := _copy_array(snapshot.get("owned_instances", []))
	var loadout := _copy_array(snapshot.get("loadout", []))
	var carried_ids: Array = _snapshot_carried_instance_ids(owned_instances, loadout, housing_tier)
	var carry_capacity := _snapshot_container_capacity(_copy_array(snapshot.get("owned_containers", [])))
	var storage_slots := maxi(0, int(definition.get("storage_slots", 0)))
	return {
		"housing_tier": housing_tier,
		"display_name": str(definition.get("display_name", housing_tier.capitalize())),
		"gold_balance": int(snapshot.get("gold_balance", 0)),
		"storage_slots": storage_slots,
		"carry_capacity": carry_capacity,
		"total_capacity": storage_slots + carry_capacity,
		"trade_up_unlocked": meta_collection_service.trade_up_unlocked(),
		"carried_count": carried_ids.size(),
		"upgrade": meta_collection_service.next_housing_upgrade(),
	}


func interactable_object_view_list(location_id: String, run_state: RunState, hover_target_id: String, focus_target_id: String, selected_object_id: String) -> Array:
	var cache_key := _interactable_object_view_cache_key(location_id)
	if cache_key == interactable_object_view_cache_key and not interactable_object_view_cache.is_empty():
		return _copy_array(interactable_object_view_cache)
	var objects := _pawn_interactable_objects(run_state, hover_target_id, focus_target_id, selected_object_id) if location_id == pawn_location_id() else _home_interactable_objects(run_state, hover_target_id, focus_target_id, selected_object_id)
	interactable_object_view_cache_key = cache_key
	interactable_object_view_cache = _copy_array(objects)
	return objects


func unopened_bag_rows() -> Array:
	var rows: Array = []
	if meta_collection_service == null:
		return rows
	var resolver: Variant = CollectionItemResolverScript.new()
	for bag_value in meta_collection_service.unopened_bags():
		if typeof(bag_value) != TYPE_DICTIONARY:
			continue
		var bag: Dictionary = bag_value
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
			"tier_badges": [{
				"glyph_id": "collection_tier",
				"value_text": tier.capitalize(),
				"polarity": "positive",
				"tooltip": "%s collection tier" % tier.capitalize(),
			}],
		})
	return rows


func owned_item_rows() -> Array:
	var rows: Array = []
	if meta_collection_service == null:
		return rows
	var resolver: Variant = CollectionItemResolverScript.new()
	var packed_ids := meta_collection_service.carried_instance_ids()
	for instance_value in meta_collection_service.owned_instances():
		if typeof(instance_value) != TYPE_DICTIONARY:
			continue
		var instance: Dictionary = instance_value
		var itemdef_id := int(instance.get("itemdef_id", -1))
		var definition: Dictionary = resolver.item_definition(itemdef_id)
		var collection: Dictionary = resolver.collection_definition(str(definition.get("collection_id", "")))
		var run_item: Dictionary = resolver.resolve_run_item(instance)
		var meta: Dictionary = _copy_dict(run_item.get("meta_collection", {}))
		var item_class := str(definition.get("item_class", CollectionItemResolverScript.ITEM_CLASS_COLLECTION))
		var collection_name := str(collection.get("display_name", "Collection"))
		var float_summary := MetaCollectionViewModelScript._float_summary(instance)
		if item_class == CollectionItemResolverScript.ITEM_CLASS_PLAYERS_CARD:
			var stamp := _copy_dict(instance.get("instance_data", {}))
			collection_name = "Grand Casino Rewards"
			float_summary = "Critical · Score %d · Day %d · %s" % [int(stamp.get("final_score", 0)), int(stamp.get("days_survived", 1)), str(stamp.get("seed", ""))]
		rows.append({
			"instance_id": int(instance.get("instance_id", 0)),
			"itemdef_id": itemdef_id,
			"display_name": str(definition.get("display_name", "Collection Item")),
			"collection_display_name": collection_name,
			"tier": str(definition.get("tier", "")),
			"condition_band": str(meta.get("condition_band", "")),
			"float_summary": float_summary,
			"packed": packed_ids.has(int(instance.get("instance_id", 0))),
		})
	return rows


func sale_rows() -> Array:
	var rows: Array = []
	if meta_collection_service == null:
		return rows
	for item_row_value in owned_item_rows():
		var item_row := _copy_dict(item_row_value)
		var instance_id := int(item_row.get("instance_id", 0))
		var quote: Dictionary = meta_collection_service.sale_quote(MetaCollectionServiceScript.SALE_KIND_ITEM, instance_id)
		if not bool(quote.get("ok", false)):
			continue
		rows.append({
			"kind": MetaCollectionServiceScript.SALE_KIND_ITEM,
			"instance_id": instance_id,
			"display_name": str(item_row.get("display_name", "Collection Item")),
			"detail": "%s. %s" % [str(item_row.get("collection_display_name", "Collection")), str(item_row.get("float_summary", ""))],
			"price": int(quote.get("price", 0)),
		})
	var resolver: Variant = CollectionItemResolverScript.new()
	for bag_value in meta_collection_service.unopened_bags():
		if typeof(bag_value) != TYPE_DICTIONARY:
			continue
		var bag: Dictionary = bag_value
		var bagdef_id := int(bag.get("bagdef_id", -1))
		var definition: Dictionary = resolver.bag_definition(bagdef_id)
		var collection: Dictionary = resolver.collection_definition(str(definition.get("collection_id", "")))
		var instance_id := int(bag.get("instance_id", 0))
		var quote: Dictionary = meta_collection_service.sale_quote(MetaCollectionServiceScript.SALE_KIND_BAG, instance_id)
		if not bool(quote.get("ok", false)):
			continue
		rows.append({
			"kind": MetaCollectionServiceScript.SALE_KIND_BAG,
			"instance_id": instance_id,
			"display_name": str(definition.get("display_name", "Collection Bag")),
			"detail": "%s unopened bag." % str(collection.get("display_name", "Collection")),
			"price": int(quote.get("price", 0)),
		})
	return rows


func trade_up_candidates() -> Array:
	var grouped: Dictionary = {}
	if meta_collection_service == null:
		return []
	var resolver: Variant = CollectionItemResolverScript.new()
	for instance_value in meta_collection_service.owned_instances():
		if typeof(instance_value) != TYPE_DICTIONARY:
			continue
		var instance: Dictionary = instance_value
		var definition: Dictionary = resolver.item_definition(int(instance.get("itemdef_id", -1)))
		var collection_id := str(definition.get("collection_id", ""))
		var tier := str(definition.get("tier", ""))
		var next_tier := next_tier(tier)
		if collection_id.is_empty() or tier.is_empty() or next_tier.is_empty():
			continue
		var key := "%s|%s" % [collection_id, tier]
		var ids := _copy_array(grouped.get(key, []))
		ids.append(int(instance.get("instance_id", 0)))
		grouped[key] = ids
	var candidates: Array = []
	for key_value in grouped.keys():
		var ids := _copy_array(grouped.get(key_value, []))
		if ids.size() < 5:
			continue
		var key := str(key_value)
		var parts := key.split("|", false)
		if parts.size() < 2:
			continue
		var collection: Dictionary = resolver.collection_definition(str(parts[0]))
		var tier := str(parts[1])
		candidates.append({
			"label": "%s %s" % [str(collection.get("display_name", "Collection")), tier.capitalize()],
			"summary": "Creates one %s item." % next_tier(tier).capitalize(),
			"instance_ids": ids.slice(0, 5),
		})
	return candidates


func next_tier(tier: String) -> String:
	var order := ["blue", "purple", "pink", "red", "gold"]
	var index := order.find(tier.strip_edges().to_lower())
	if index < 0 or index >= order.size() - 1:
		return ""
	return str(order[index + 1])


func collection_reveal_text(result: Dictionary) -> String:
	if not bool(result.get("ok", false)):
		return str(result.get("message", "Bag could not be opened."))
	var reveal := _copy_dict(result.get("reveal", {}))
	var definition := _copy_dict(reveal.get("definition", {}))
	var item := _copy_dict(reveal.get("item", {}))
	var bag := _copy_dict(reveal.get(MetaCollectionServiceScript.REVEAL_BAG_KEY, {}))
	var tier := str(definition.get("tier", "")).capitalize()
	var condition := str(reveal.get("condition_band", "unknown")).capitalize()
	var floats := "P %d%% / C %d%% / R %d%% / U %d%%" % [
		int(round(clampf(float(item.get("potency", 0.0)), 0.0, 1.0) * 100.0)),
		int(round(clampf(float(item.get("condition", 0.0)), 0.0, 1.0) * 100.0)),
		int(round(clampf(float(item.get("resonance", 0.0)), 0.0, 1.0) * 100.0)),
		int(round(clampf(float(item.get("usage", 0.0)), 0.0, 1.0) * 100.0)),
	]
	return "Opened %s: %s, %s, %s. %s" % [
		str(bag.get("display_name", "Collection Bag")),
		str(definition.get("display_name", "Collection Item")),
		tier,
		condition,
		floats,
	]


func map_node_ids() -> Array:
	return [META_LOCATION_HOME, pawn_location_id()]


func travel_target_ids(location_id: String) -> Array:
	if location_id == pawn_location_id():
		return [META_LOCATION_HOME]
	return [pawn_location_id()]


func travel_choice(target_id: String, location_id: String) -> Dictionary:
	var clean_id := target_id.strip_edges()
	if not map_node_ids().has(clean_id):
		return {}
	var label := "Home"
	if clean_id == pawn_location_id():
		label = "Sal's Pawn Shop"
	return {
		"id": clean_id,
		"label": label,
		"kind": "meta",
		"tier": 0,
		"description": "Free out-of-run travel.",
		"route": {
			"id": clean_id,
			"cost": 0,
			"distance": "near",
			"distance_blocks": 0,
			"travel_method": "Walk",
		},
		"cost": 0,
		"distance": "near",
		"distance_blocks": 0,
		"travel_minutes": 0,
		"enabled": clean_id != location_id,
		"disabled_reason": "You are here." if clean_id == location_id else "",
		"open_now": true,
		"open_status_text": "Always open",
		"attribute_badges": [],
	}


func world_map_snapshot(location_id: String, selected_node_id: String) -> Dictionary:
	var selected_id := selected_node_id
	if selected_id.is_empty():
		selected_id = location_id
	var nodes: Array = [
		_world_map_node(META_LOCATION_HOME, Vector2(0.36, 0.50), selected_id, location_id),
		_world_map_node(pawn_location_id(), Vector2(0.64, 0.50), selected_id, location_id),
	]
	var targets := travel_target_ids(location_id)
	return {
		"schema_version": 1,
		"current_node_id": location_id,
		"selected_node_id": selected_id,
		"nodes": nodes,
		"edges": [{"id": "home-pawn", "a": META_LOCATION_HOME, "b": pawn_location_id(), "distance": "near"}],
		"visited_path": [location_id],
		"travel_target_ids": targets,
		"travel_enabled_node_ids": targets,
		"travel_disabled_node_ids": [],
		"travel_paths": [{"target_id": targets[0], "path": [location_id, targets[0]], "enabled": true}] if not targets.is_empty() else [],
		"map_focus_node_ids": map_node_ids(),
		"background_path": WorldMapScript.MAP_BACKGROUND_PATH,
	}


func archetype_id_for_location(node_id: String) -> String:
	if node_id == pawn_location_id():
		return pawn_location_id()
	if meta_collection_service == null:
		return MetaCollectionServiceScript.HOUSING_BACK_ALLEY
	return str(meta_collection_service.housing_definition().get("archetype_id", MetaCollectionServiceScript.HOUSING_BACK_ALLEY))


func map_icon_archetype_id(node_id: String) -> String:
	if node_id == pawn_location_id():
		return pawn_location_id()
	return archetype_id_for_location(node_id)


func world_map_detail_view(location_id: String, selected_node_id: String) -> Dictionary:
	var lines: Array = []
	if selected_node_id.is_empty():
		lines.append("Select a revealed stop.")
		return {"text": "\n".join(lines), "confirm_enabled": false, "badges": []}
	var label := "Home" if selected_node_id == META_LOCATION_HOME else "Sal's Pawn Shop"
	var destination_kind := "shop" if selected_node_id == pawn_location_id() else "home"
	var route := travel_choice(selected_node_id, location_id)
	lines.append("Stop: %s" % label)
	lines.append("Travel: Walk · Cost: $0")
	lines.append("Distance: Near / 1 block")
	lines.append("Clock: no time passes")
	if selected_node_id == location_id:
		lines.append("Status: You are here.")
		return {"text": "\n".join(lines), "confirm_enabled": false, "badges": AttributeBadgesScript.for_world_map_detail(destination_kind)}
	lines.append("Status: Route open.")
	return {"text": "\n".join(lines), "confirm_enabled": true, "badges": AttributeBadgesScript.for_world_map_detail(destination_kind, route)}


func _build_home_environment(run_state: RunState) -> Dictionary:
	var definition: Dictionary = meta_collection_service.housing_definition()
	var archetype_id := str(definition.get("archetype_id", MetaCollectionServiceScript.HOUSING_BACK_ALLEY)).strip_edges()
	if archetype_id.is_empty():
		archetype_id = MetaCollectionServiceScript.HOUSING_BACK_ALLEY
	var archetype := _environment_archetype(archetype_id)
	if archetype.is_empty():
		return {}
	var rng := run_state.create_rng("meta_home:%s" % archetype_id)
	var instance := EnvironmentInstance.from_archetype(archetype, 1, rng, library, {})
	var data: Dictionary = instance.to_dict()
	data["id"] = "meta_home_%s" % archetype_id
	data["archetype_id"] = archetype_id
	data["world_node_id"] = META_LOCATION_HOME
	data["world_map_travel"] = true
	data["kind"] = "home"
	data["display_name"] = str(definition.get("display_name", data.get("display_name", "Home")))
	data["objective_hint"] = "Use room props to manage storage, bags, upgrades, and travel."
	data["game_ids"] = []
	data["game_states"] = {}
	data["event_ids"] = []
	data["item_offers"] = []
	data["service_ids"] = []
	data["lender_hooks"] = []
	data["object_fixtures"] = []
	data["travel_hooks"] = [pawn_location_id()]
	data["next_archetypes"] = [pawn_location_id()]
	data["home_profile"] = _copy_dict(archetype.get("home_profile", {}))
	data["home_containers"] = _container_rows()
	data["home_container_index"] = _copy_array(data.get("home_containers", [])).size()
	data["home_lost"] = false
	data["meta_session"] = true
	data["meta_location"] = META_LOCATION_HOME
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data)
	return data


func _build_pawn_environment(run_state: RunState) -> Dictionary:
	var pawn_location := pawn_location_id()
	var archetype := _environment_archetype(pawn_location)
	if archetype.is_empty():
		return {}
	var rng := run_state.create_rng("meta_pawn_shop")
	var instance := EnvironmentInstance.from_archetype(archetype, 1, rng, library, {})
	var data: Dictionary = instance.to_dict()
	data["id"] = "meta_pawn_shop"
	data["world_node_id"] = pawn_location
	data["world_map_travel"] = true
	data["kind"] = "pawn" + "_shop"
	data["display_name"] = "Sal's Pawn Shop"
	data["objective_hint"] = "Sell collection items or unopened bags for gold."
	data["game_ids"] = []
	data["game_states"] = {}
	data["event_ids"] = []
	data["item_offers"] = []
	data["service_ids"] = []
	data["lender_hooks"] = []
	data["object_fixtures"] = []
	data["travel_hooks"] = [META_LOCATION_HOME]
	data["next_archetypes"] = [META_LOCATION_HOME]
	data["home_containers"] = []
	data["meta_session"] = true
	data["meta_location"] = pawn_location
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data)
	return data


func _home_state_for_environment(environment: Dictionary, run_state: RunState) -> Dictionary:
	return {
		"active": true,
		"lost": false,
		"act_index": maxi(1, run_state.act_marker()),
		"home_archetype_id": str(environment.get("archetype_id", MetaCollectionServiceScript.HOUSING_BACK_ALLEY)),
		"home_node_id": META_LOCATION_HOME,
		"display_name": str(environment.get("display_name", "Home")),
		"started_day": run_state.game_day(),
		"lost_day": 0,
		"lost_reason": "",
		"tenure": {},
	}


func _container_rows() -> Array:
	var rows: Array = []
	if meta_collection_service == null:
		return rows
	for container_value in meta_collection_service.carried_container_rows():
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		var container: Dictionary = _copy_dict(container_value)
		var item_id := str(container.get("item_id", "bag")).strip_edges()
		if item_id.is_empty():
			continue
		container["display_name"] = _container_label(item_id)
		rows.append(container)
	return rows


func _container_label(item_id: String) -> String:
	var clean_id := item_id.strip_edges()
	if library != null:
		var item := library.item(clean_id)
		if not item.is_empty():
			return str(item.get("display_name", clean_id.replace("_", " ").capitalize()))
	return clean_id.replace("_", " ").capitalize()


func _interactable_object_view_cache_key(location_id: String) -> String:
	var parts: Array[String] = [location_id]
	if meta_collection_service != null:
		var snapshot: Dictionary = meta_collection_service.snapshot()
		parts.append(str(snapshot.get("housing_tier", "")))
		parts.append(str(snapshot.get("gold_balance", 0)))
		parts.append(JSON.stringify(snapshot.get("owned_containers", [])))
		parts.append(JSON.stringify(snapshot.get("owned_instances", [])))
		parts.append(JSON.stringify(snapshot.get("unopened_bags", [])))
		parts.append(JSON.stringify(snapshot.get("loadout", [])))
	return "|".join(parts)


func _home_interactable_objects(run_state: RunState, hover_target_id: String, focus_target_id: String, selected_object_id: String) -> Array:
	var objects: Array = []
	if run_state == null:
		return objects
	var home := home_summary_view()
	var gold := int(home.get("gold_balance", 0))
	var containers := run_state.current_home_containers()
	for index in range(containers.size()):
		if typeof(containers[index]) != TYPE_DICTIONARY:
			continue
		var container: Dictionary = containers[index]
		var container_id := str(container.get("id", ""))
		objects.append(_make_interactable_object({
			"object_id": "meta_container:%s" % container_id,
			"object_type": CONTEXT_MODE_HOME_CONTAINER,
			"visual_type": CONTEXT_MODE_HOME_CONTAINER,
			"source_id": container_id,
			"label": str(container.get("display_name", "Container")),
			"short_description": "Storage you own. Click to inspect packed and stored collection items.",
			"presence": "fixture",
			"interactive": true,
			"enabled": true,
			"action_summary": "Open contents.",
			"status_summary": "%d carried / %d capacity" % [int(home.get("carried_count", 0)), int(home.get("carry_capacity", 0))],
			"effect_summary": "Gold: %d" % gold,
			"visual_key": "home_container",
			"prop": "satchel",
			"icon_key": str(container.get("item_id", "b" + "ag")),
			"available_actions": [{"id": "open_meta_container", "label": "Open"}],
			"confirm_action_id": "open_meta_container",
			"focus_rect": _interaction_rect_for_object(run_state, "meta_container:%s" % container_id, CONTEXT_MODE_HOME_CONTAINER, index),
		}, hover_target_id, focus_target_id, selected_object_id))
	var bags := unopened_bag_rows()
	for index in range(bags.size()):
		var bag := _copy_dict(bags[index])
		var bag_id := int(bag.get("instance_id", 0))
		objects.append(_make_interactable_object({
			"object_id": "meta_bag:%d" % bag_id,
			"object_type": CONTEXT_MODE_META_BAG,
			"visual_type": CONTEXT_MODE_META_BAG,
			"source_id": str(bag_id),
			"label": str(bag.get("display_name", "Collection Bag")),
			"short_description": str(bag.get("collection_display_name", "Unopened collection bag")),
			"presence": "fixture",
			"interactive": true,
			"enabled": true,
			"action_summary": "Open this bag.",
			"status_summary": str(bag.get("tier_label", "")),
			"attribute_badges": _copy_array(bag.get("tier_badges", [])),
			"visual_key": "meta_bag",
			"prop": "paper_bag",
			"icon_key": str(bag.get("icon_key", "cashout" + "_envelope")),
			"available_actions": [{"id": "open_meta_bag", "label": "Open"}],
			"confirm_action_id": "open_meta_bag",
			"focus_rect": _interaction_rect_for_object(run_state, "meta_bag:%d" % bag_id, CONTEXT_MODE_META_BAG, index),
		}, hover_target_id, focus_target_id, selected_object_id))
	var upgrade := _copy_dict(home.get("upgrade", {}))
	var upgrade_enabled := not upgrade.is_empty() and bool(upgrade.get("affordable", false))
	objects.append(_make_interactable_object({
		"object_id": "meta_upgrade:home",
		"object_type": CONTEXT_MODE_META_UPGRADE,
		"visual_type": CONTEXT_MODE_META_UPGRADE,
		"source_id": "home",
		"label": "Upgrade Sign",
		"short_description": "Buy the next housing tier with pawn-shop gold.",
		"presence": "fixture",
		"interactive": not upgrade.is_empty(),
		"enabled": upgrade_enabled,
		"disabled_reason": "No further upgrade." if upgrade.is_empty() else "Needs %d gold." % int(upgrade.get("price", 0)),
		"action_summary": "Buy %s." % str(upgrade.get("display_name", "next home")) if upgrade_enabled else "Inspect the next housing price.",
		"cost_summary": "Gold: %d / %d" % [gold, int(upgrade.get("price", 0))] if not upgrade.is_empty() else "",
		"visual_key": "meta_upgrade",
		"prop": "sign",
		"icon_key": "roadside" + "_map",
		"available_actions": [{"id": "buy_home_upgrade", "label": "Buy"}] if upgrade_enabled else [],
		"confirm_action_id": "buy_home_upgrade" if upgrade_enabled else "",
		"focus_rect": _interaction_rect_for_object(run_state, "meta_upgrade:home", CONTEXT_MODE_META_UPGRADE, 0),
	}, hover_target_id, focus_target_id, selected_object_id))
	var trade_unlocked := bool(home.get("trade_up_unlocked", false))
	if trade_unlocked or str(home.get("housing_tier", "")) != MetaCollectionServiceScript.HOUSING_BACK_ALLEY:
		objects.append(_make_interactable_object({
			"object_id": "meta_trade_up:station",
			"object_type": CONTEXT_MODE_META_TRADE_UP,
			"visual_type": CONTEXT_MODE_META_TRADE_UP,
			"source_id": "station",
			"label": "Trade-Up Station",
			"short_description": "Trade five matching collection items for one next-tier item.",
			"presence": "fixture",
			"interactive": true,
			"enabled": trade_unlocked,
			"disabled_reason": "" if trade_unlocked else "Trade-ups unlock with an apartment or house.",
			"action_summary": "Review eligible trades." if trade_unlocked else "Housing tier is too low.",
			"visual_key": "meta_trade_up",
			"prop": "workbench",
			"icon_key": "ledger" + "_pencil",
			"available_actions": [{"id": "open_trade_up", "label": "Trade"}] if trade_unlocked else [],
			"confirm_action_id": "open_trade_up" if trade_unlocked else "",
			"focus_rect": _interaction_rect_for_object(run_state, "meta_trade_up:station", CONTEXT_MODE_META_TRADE_UP, 0),
		}, hover_target_id, focus_target_id, selected_object_id))
	objects.append(_make_interactable_object({
		"object_id": "travel:leave",
		"object_type": CONTEXT_MODE_TRAVEL,
		"source_id": "leave",
		"label": "Map Door",
		"short_description": "Open the meta travel map.",
		"enabled": true,
		"action_summary": "Travel to Sal's Pawn Shop.",
		"cost_summary": "Free",
		"visual_key": "travel",
		"prop": "door",
		"icon_key": "travel",
		"available_actions": [{"id": "open_meta_map", "label": "Open Map"}],
		"confirm_action_id": "open_meta_map",
		"focus_rect": _interaction_rect_for_object(run_state, "travel:leave", CONTEXT_MODE_TRAVEL, 0),
	}, hover_target_id, focus_target_id, selected_object_id))
	return objects


func _pawn_interactable_objects(run_state: RunState, hover_target_id: String, focus_target_id: String, selected_object_id: String) -> Array:
	return [
		_make_interactable_object({
			"object_id": "meta_pawn_counter:sell",
			"object_type": CONTEXT_MODE_META_PAWN_COUNTER,
			"visual_type": CONTEXT_MODE_META_PAWN_COUNTER,
			"source_id": "sell",
			"label": "Sell Counter",
			"short_description": "Sal buys collection items and unopened bags for gold.",
			"presence": "fixture",
			"interactive": true,
			"enabled": true,
			"action_summary": "Choose something to sell.",
			"effect_summary": "Pawn shop is the only gold faucet.",
			"visual_key": "meta_pawn_counter",
			"prop": "counter",
			"icon_key": "pawn_receipt" + "_sleeve",
			"available_actions": [{"id": "open_sell_counter", "label": "Sell"}],
			"confirm_action_id": "open_sell_counter",
			"focus_rect": _interaction_rect_for_object(run_state, "meta_pawn_counter:sell", CONTEXT_MODE_META_PAWN_COUNTER, 0),
		}, hover_target_id, focus_target_id, selected_object_id),
		_make_interactable_object({
			"object_id": "travel:leave",
			"object_type": CONTEXT_MODE_TRAVEL,
			"source_id": "leave",
			"label": "Street Door",
			"short_description": "Open the meta travel map.",
			"enabled": true,
			"action_summary": "Return home.",
			"cost_summary": "Free",
			"visual_key": "travel",
			"prop": "door",
			"icon_key": "travel",
			"available_actions": [{"id": "open_meta_map", "label": "Open Map"}],
			"confirm_action_id": "open_meta_map",
			"focus_rect": _interaction_rect_for_object(run_state, "travel:leave", CONTEXT_MODE_TRAVEL, 0),
		}, hover_target_id, focus_target_id, selected_object_id),
	]


func _world_map_node(node_id: String, position: Vector2, selected_id: String, location_id: String) -> Dictionary:
	var is_current := node_id == location_id
	var label := "Home" if node_id == META_LOCATION_HOME else "Sal's Pawn Shop"
	var flavor := "Your current housing room." if node_id == META_LOCATION_HOME else "Sell collection finds at the pawn shop."
	return {
		"id": node_id,
		"archetype_id": archetype_id_for_location(node_id),
		"icon_path": "res://assets/art/map_icons/%s.png" % map_icon_archetype_id(node_id),
		"label": label,
		"kind": "meta",
		"state": "visited",
		"position": {"x": position.x, "y": position.y},
		"current": is_current,
		"selected": node_id == selected_id,
		"travel_target": node_id != location_id,
		"travel_enabled": node_id != location_id,
		"open_now": true,
		"open_status_text": "Always open",
		"flavor": flavor,
	}


func _snapshot_carried_instance_ids(owned_instances: Array, loadout: Array, housing_tier: String) -> Array:
	var owned_ids: Array = []
	for instance_value in owned_instances:
		var instance := _copy_dict(instance_value)
		var instance_id := int(instance.get("instance_id", 0))
		if instance_id > 0 and not owned_ids.has(instance_id):
			owned_ids.append(instance_id)
	if housing_tier == MetaCollectionServiceScript.HOUSING_BACK_ALLEY:
		return owned_ids
	var carried: Array = []
	for id_value in loadout:
		var instance_id := int(id_value)
		if instance_id > 0 and owned_ids.has(instance_id) and not carried.has(instance_id):
			carried.append(instance_id)
	return carried


func _snapshot_container_capacity(containers: Array) -> int:
	var total := 0
	for container_value in containers:
		var container := _copy_dict(container_value)
		total += maxi(0, int(container.get("capacity", 0)))
	return total


func _environment_archetype(archetype_id: String) -> Dictionary:
	if library == null:
		return {}
	for archetype in library.environment_archetypes:
		if typeof(archetype) == TYPE_DICTIONARY and str((archetype as Dictionary).get("id", "")) == archetype_id:
			return (archetype as Dictionary).duplicate(true)
	return {}


func _make_interactable_object(source: Dictionary, hover_target_id: String, focus_target_id: String, selected_object_id: String) -> Dictionary:
	var focus_rect := _rect_from_dict(source.get("focus_rect", {}))
	var focus_point := focus_rect.position + focus_rect.size * 0.5
	var enabled := bool(source.get("enabled", true))
	var interactive := bool(source.get("interactive", true))
	var object_id := str(source.get("object_id", ""))
	return {
		"object_id": object_id,
		"object_type": str(source.get("object_type", "info")),
		"visual_type": str(source.get("visual_type", source.get("object_type", "info"))),
		"presence": str(source.get("presence", "dynamic")),
		"interactive": interactive,
		"decorative": not interactive,
		"source_id": str(source.get("source_id", "")),
		"parent_id": str(source.get("parent_id", "")),
		"label": str(source.get("label", "")),
		"short_description": str(source.get("short_description", "")),
		"identity_summary": str(source.get("identity_summary", "")),
		"enabled": enabled,
		"disabled_reason": str(source.get("disabled_reason", "")) if not enabled else "",
		"normalized_rect": _rect_to_dict(focus_rect),
		"focus_rect": _rect_to_dict(focus_rect),
		"focus_point": _vector2_to_dict(focus_point),
		"action_summary": str(source.get("action_summary", "")),
		"status_summary": str(source.get("status_summary", "")),
		"effect_summary": str(source.get("effect_summary", "")),
		"impact_summary": str(source.get("impact_summary", "")),
		"choice_summary": str(source.get("choice_summary", "")),
		"risk_summary": str(source.get("risk_summary", "")),
		"cost_summary": str(source.get("cost_summary", "")),
		"attribute_badges": _copy_array(source.get("attribute_badges", [])),
		"runtime_state": (source.get("runtime_state", {}) as Dictionary).duplicate(true) if typeof(source.get("runtime_state", {})) == TYPE_DICTIONARY else {},
		"visual_state": (source.get("visual_state", {}) as Dictionary).duplicate(true) if typeof(source.get("visual_state", {})) == TYPE_DICTIONARY else {},
		"state_badge": str(source.get("state_badge", "")),
		"visual_key": str(source.get("visual_key", "")),
		"prop": str(source.get("prop", "")),
		"surface": str(source.get("surface", "")),
		"icon_key": str(source.get("icon_key", "")),
		"asset_path": str(source.get("asset_path", "")),
		"unique_object_class": str(source.get("unique_object_class", "")).strip_edges(),
		"unique_object_priority": int(source.get("unique_object_priority", 0)),
		"allow_duplicate_unique_class": bool(source.get("allow_duplicate_unique_class", false)),
		"available_actions": _copy_array(source.get("available_actions", [])),
		"inline_actions": _copy_array(source.get("inline_actions", [])),
		"confirm_action_id": str(source.get("confirm_action_id", "")),
		"hovered": object_id == hover_target_id,
		"focused": object_id == focus_target_id,
		"selected": object_id == selected_object_id,
	}


func _interaction_rect_for_object(run_state: RunState, object_id: String, object_type: String, index: int) -> Rect2:
	var object_rect := _generated_object_interaction_rect(run_state, object_id)
	if object_rect.size.x > 0.0 and object_rect.size.y > 0.0:
		return object_rect
	return _normalized_interaction_rect(object_type, index)


func _generated_object_interaction_rect(run_state: RunState, object_id: String) -> Rect2:
	if run_state == null or object_id.is_empty():
		return Rect2()
	var layout := _current_environment_layout(run_state)
	var object_rects: Variant = layout.get("object_rects", {})
	if typeof(object_rects) != TYPE_DICTIONARY or not (object_rects as Dictionary).has(object_id):
		return Rect2()
	return _rect_from_dict((object_rects as Dictionary).get(object_id, {}))


func _current_environment_layout(run_state: RunState) -> Dictionary:
	var serialized_layout: Variant = run_state.current_environment.get("layout", {})
	if typeof(serialized_layout) == TYPE_DICTIONARY and not (serialized_layout as Dictionary).is_empty():
		return serialized_layout as Dictionary
	var archetype_id := str(run_state.current_environment.get("archetype_id", ""))
	var archetype := _environment_archetype(archetype_id)
	var archetype_layout: Variant = archetype.get("layout", {})
	if typeof(archetype_layout) != TYPE_DICTIONARY:
		return {}
	return archetype_layout as Dictionary


func _normalized_interaction_rect(object_type: String, index: int) -> Rect2:
	var board_size := Vector2(VisualStyle.ENVIRONMENT_BOARD_SIZE)
	var center := Vector2(0.5, 0.5)
	var size := Vector2(0.12, 0.18)
	match object_type:
		CONTEXT_MODE_TRAVEL:
			center = Vector2(0.78, 0.64 + float(index) * 0.12)
			size = Vector2(118.0 / board_size.x, 64.0 / board_size.y)
		CONTEXT_MODE_HOME_CONTAINER:
			center = Vector2(0.22 + float(index % 4) * 0.18, 0.76 + float(index / 4) * 0.11)
			size = Vector2(104.0 / board_size.x, 58.0 / board_size.y)
		CONTEXT_MODE_META_BAG:
			center = Vector2(0.42 + float(index % 3) * 0.12, 0.66 + float(index / 3) * 0.11)
			size = Vector2(90.0 / board_size.x, 54.0 / board_size.y)
		CONTEXT_MODE_META_UPGRADE:
			center = Vector2(0.78, 0.34)
			size = Vector2(118.0 / board_size.x, 64.0 / board_size.y)
		CONTEXT_MODE_META_TRADE_UP:
			center = Vector2(0.62, 0.72)
			size = Vector2(118.0 / board_size.x, 64.0 / board_size.y)
		CONTEXT_MODE_META_PAWN_COUNTER:
			center = Vector2(0.50, 0.48)
			size = Vector2(136.0 / board_size.x, 72.0 / board_size.y)
	return Rect2(center - size * 0.5, size)


func _rect_to_dict(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"w": rect.size.x,
		"h": rect.size.y,
	}


func _rect_from_dict(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value as Rect2
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = value
	return Rect2(
		Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))),
		Vector2(float(data.get("w", 0.0)), float(data.get("h", 0.0)))
	)


func _vector2_to_dict(value: Vector2) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y,
	}


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
