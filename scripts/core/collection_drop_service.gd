class_name CollectionDropService
extends RefCounted

# Run-boundary bridge: run code records pending markers, this service turns
# terminal run outcomes into meta collection grants.

const CollectionItemResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")

const EVALUATED_FLAG := "_meta_bag_drops_evaluated"
const FLUSHED_FLAG := "_meta_bag_grants_flushed"
const GRANTS_FLAG := "_meta_bag_grants"
const HIGH_HEAT_CLEAN_ESCAPE_THRESHOLD := 65
const HIGH_HEAT_CLEAN_ESCAPE_CHANCE_PERCENT := 35


func ensure_run_end_pending_bags(run_state: RunState, profile_inventory: Variant = null) -> Array:
	if run_state == null or not run_state.is_terminal():
		return []
	if not run_state.meta_collection_enabled_for_run():
		return []
	if bool(run_state.narrative_flags.get(EVALUATED_FLAG, false)):
		return run_state.pending_bag_markers()
	var rng := _run_drop_rng(run_state)
	var markers: Array = []
	if run_state.run_status == RunState.RUN_STATUS_ENDED:
		markers.append(_roll_bag_marker(run_state, "run_victory", "run_victory", rng))
		if str(run_state.narrative_flags.get("demo_victory_route", "")) == RunState.GRAND_CASINO_SHOWDOWN_ROUTE:
			markers.append(_roll_bag_marker(run_state, "grand_casino_showdown", RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID, rng))
		var completion_flag := run_state.challenge_completion_flag()
		if not completion_flag.is_empty() and not _profile_has_challenge_completion(profile_inventory, completion_flag):
			markers.append(_roll_bag_marker(run_state, "challenge_completion", completion_flag, rng))
		if run_state.suspicion_level() >= HIGH_HEAT_CLEAN_ESCAPE_THRESHOLD:
			var roll := rng.randi_range(1, 100)
			if roll <= HIGH_HEAT_CLEAN_ESCAPE_CHANCE_PERCENT:
				markers.append(_roll_bag_marker(run_state, "high_heat_clean_escape", "heat_%d" % run_state.suspicion_level(), rng))
	for marker_value in markers:
		var marker := _copy_dict(marker_value)
		if not marker.is_empty():
			run_state.add_pending_bag_marker(marker)
	run_state.narrative_flags[EVALUATED_FLAG] = true
	return run_state.pending_bag_markers()


func flush_pending_bags(run_state: RunState, meta_collection_service: Variant) -> Dictionary:
	if run_state == null or meta_collection_service == null:
		return {"ok": false, "granted": [], "summary_lines": []}
	if not run_state.meta_collection_enabled_for_run():
		return {"ok": true, "granted": [], "summary_lines": []}
	var existing_lines := _copy_array(run_state.narrative_flags.get(GRANTS_FLAG, []))
	if bool(run_state.narrative_flags.get(FLUSHED_FLAG, false)):
		return {"ok": true, "granted": [], "summary_lines": existing_lines}
	var markers := run_state.pending_bag_markers()
	var granted: Array = []
	for marker_value in markers:
		var marker := _enriched_marker(_copy_dict(marker_value))
		var bagdef_id := int(marker.get("bagdef_id", -1))
		if bagdef_id < 0:
			continue
		var grant: Dictionary = meta_collection_service.grant_bag(bagdef_id, str(marker.get("rng_seed", "")), marker)
		if not grant.is_empty():
			granted.append(grant)
	var summary_lines := summary_lines_for_markers(granted)
	run_state.narrative_flags[GRANTS_FLAG] = summary_lines
	run_state.narrative_flags[FLUSHED_FLAG] = true
	run_state.clear_pending_bag_markers()
	return {
		"ok": true,
		"granted": granted,
		"summary_lines": summary_lines,
	}


func summary_lines_for_markers(markers: Array) -> Array:
	var lines: Array = []
	for marker_value in markers:
		var marker := _enriched_marker(_copy_dict(marker_value))
		if marker.is_empty():
			continue
		var display_name := str(marker.get("display_name", "Collection Bag")).strip_edges()
		var collection_name := str(marker.get("collection_display_name", marker.get("collection_id", "collection"))).strip_edges()
		var tier := str(marker.get("tier", "")).strip_edges()
		var tier_label := str(marker.get("tier_label", tier.capitalize())).strip_edges()
		if tier_label.is_empty():
			tier_label = "Tiered"
		lines.append("%s: %s, %s." % [display_name, collection_name, tier_label])
	return lines


func marker_from_static_bag(bagdef_id: int, source: String, source_id: String, rng_seed: String = "") -> Dictionary:
	var marker := {
		"bagdef_id": bagdef_id,
		"source": source.strip_edges(),
		"source_id": source_id.strip_edges(),
		"rng_seed": rng_seed.strip_edges(),
	}
	if str(marker.get("rng_seed", "")).is_empty():
		marker["rng_seed"] = "%s|%s|%d" % [str(marker.get("source", "static")), str(marker.get("source_id", "")), bagdef_id]
	return _enriched_marker(marker)


func _roll_bag_marker(run_state: RunState, source: String, source_id: String, rng: RngStream) -> Dictionary:
	var resolver: Variant = CollectionItemResolverScript.new()
	var collections: Array = resolver.collections()
	if collections.is_empty():
		return {}
	var collection_index := rng.randi_range(0, collections.size() - 1)
	var collection := _copy_dict(collections[collection_index])
	var tier := _roll_tier(collection, rng)
	var collection_id := str(collection.get("id", ""))
	var bag_defs: Array = resolver.bag_item_definitions(collection_id, tier)
	if bag_defs.is_empty():
		return {}
	var bag_index := rng.randi_range(0, bag_defs.size() - 1)
	var bag := _copy_dict(bag_defs[bag_index])
	var bagdef_id := int(bag.get("itemdef_id", -1))
	var seed_text := "%s|%s|%s|%s|%d|%d" % [
		run_state.seed_text,
		run_state.run_status,
		source,
		source_id,
		bagdef_id,
		rng.state_value,
	]
	return _enriched_marker({
		"bagdef_id": bagdef_id,
		"collection_id": collection_id,
		"tier": tier,
		"source": source,
		"source_id": source_id,
		"rng_seed": seed_text,
	})


func _roll_tier(collection: Dictionary, rng: RngStream) -> String:
	var drop_table := _copy_dict(collection.get("drop_table", {}))
	var tiers: Array = []
	var total_weight := 0
	for tier_value in CollectionItemResolverScript.TIERS:
		var tier := str(tier_value)
		var weight := maxi(0, int(drop_table.get(tier, 0)))
		if weight <= 0:
			continue
		tiers.append({"tier": tier, "weight": weight})
		total_weight += weight
	if tiers.is_empty() or total_weight <= 0:
		return "blue"
	var roll := rng.randi_range(1, total_weight)
	var running := 0
	for entry_value in tiers:
		var entry := _copy_dict(entry_value)
		running += int(entry.get("weight", 0))
		if roll <= running:
			return str(entry.get("tier", "blue"))
	return "blue"


func _run_drop_rng(run_state: RunState) -> RngStream:
	var root: RngStream = RngStreamScript.new()
	root.configure(run_state.seed_value, run_state.seed_value)
	var key := "%s|%s|%d|%s|%s" % [
		run_state.seed_text,
		run_state.run_status,
		run_state.suspicion_level(),
		run_state.challenge_completion_flag(),
		str(run_state.narrative_flags.get("demo_victory_route", "")),
	]
	return root.fork("meta_bag_drops:%s" % key)


func _enriched_marker(marker: Dictionary) -> Dictionary:
	if marker.is_empty():
		return {}
	var resolver: Variant = CollectionItemResolverScript.new()
	var bag: Dictionary = resolver.bag_definition(int(marker.get("bagdef_id", -1)))
	if bag.is_empty():
		return marker
	var collection: Dictionary = resolver.collection_definition(str(bag.get("collection_id", marker.get("collection_id", ""))))
	var enriched := marker.duplicate(true)
	enriched["schema_version"] = 1
	enriched["bagdef_id"] = int(bag.get("itemdef_id", marker.get("bagdef_id", -1)))
	enriched["collection_id"] = str(bag.get("collection_id", marker.get("collection_id", "")))
	enriched["collection_display_name"] = str(collection.get("display_name", enriched.get("collection_id", "Collection")))
	enriched["tier"] = str(bag.get("tier", marker.get("tier", "")))
	enriched["tier_label"] = str(enriched.get("tier", "")).capitalize()
	enriched["display_name"] = str(bag.get("display_name", marker.get("display_name", "Collection Bag")))
	enriched["icon_key"] = str(bag.get("icon_key", marker.get("icon_key", "")))
	enriched["source"] = str(marker.get("source", "run_end")).strip_edges()
	enriched["source_id"] = str(marker.get("source_id", "")).strip_edges()
	enriched["rng_seed"] = str(marker.get("rng_seed", "")).strip_edges()
	if str(enriched.get("rng_seed", "")).is_empty():
		enriched["rng_seed"] = "%s|%s|%d" % [str(enriched.get("source", "run_end")), str(enriched.get("source_id", "")), int(enriched.get("bagdef_id", -1))]
	enriched["marker_id"] = "%s:%s:%d:%s" % [
		str(enriched.get("source", "")),
		str(enriched.get("source_id", "")),
		int(enriched.get("bagdef_id", -1)),
		str(enriched.get("rng_seed", "")),
	]
	return enriched


func _profile_has_challenge_completion(profile_inventory: Variant, completion_flag: String) -> bool:
	if profile_inventory == null or completion_flag.strip_edges().is_empty():
		return false
	return bool(profile_inventory.has_challenge_completion(completion_flag))


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
