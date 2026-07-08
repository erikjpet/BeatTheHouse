extends SceneTree

const CollectionItemResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const CollectionDropServiceScript := preload("res://scripts/core/collection_drop_service.gd")
const MetaCollectionViewModelScript := preload("res://scripts/ui/meta_collection_view_model.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

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
	_test_meta_home_rules(resolver)
	_test_pawn_sale_and_trade_up(resolver)
	_test_failure_decay_and_run_modifiers(resolver)
	_test_terminal_drop_determinism()
	_test_run_end_grant_persists()
	_test_daily_and_challenge_runs_are_meta_isolated()
	_test_open_bag_consumes_once()
	_test_collection_browser_view_model_read_only(resolver)
	_test_end_summary_lists_bags()
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
	_check(str(empty_store.get("housing_tier", "")) == MetaCollectionServiceScript.HOUSING_BACK_ALLEY, "Default housing tier must be back alley.")
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


func _test_meta_home_rules(resolver: Variant) -> void:
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, TEST_STORE_PATH)
	_remove_user_file(TEST_STORE_PATH)
	var service: Variant = MetaCollectionServiceScript.new()
	service.load()
	_check(service.housing_tier() == MetaCollectionServiceScript.HOUSING_BACK_ALLEY, "Meta home must default to back alley.")
	_check(service.storage_slots() == 0, "Back alley must not provide owned storage slots.")
	_check(service.carry_capacity() == 3, "Starter bag capacity must come from container data.")
	_check(not service.trade_up_unlocked(), "Back alley must not unlock trade-ups.")
	for index in range(3):
		service.grant_instance(resolver.roll_instance(1000, "home-cap-%d" % index))
	var bag: Dictionary = service.grant_bag(9000, "home-full-bag")
	var blocked: Dictionary = service.open_bag(int(bag.get("instance_id", 0)))
	_check(not bool(blocked.get("ok", true)), "Homeless owned-cap must block opening bags when full.")
	_check(service.unopened_bags().size() == 1, "Blocked bag open must not consume the bag.")
	service.add_gold(60)
	var motel: Dictionary = service.purchase_housing_upgrade()
	_check(bool(motel.get("ok", false)) and service.housing_tier() == MetaCollectionServiceScript.HOUSING_MOTEL_ROOM, "Gold purchase did not upgrade to motel room.")
	_check(service.storage_slots() == 8, "Motel room must provide eight storage slots.")
	_check(not service.trade_up_unlocked(), "Motel room must not unlock trade-ups.")
	var owned_ids: Array = _instance_ids(service.owned_instances())
	var packed: Dictionary = service.pack_instance(int(owned_ids[0]))
	var duplicate_pack: Dictionary = service.pack_instance(int(owned_ids[0]))
	_check(bool(packed.get("ok", false)) and _copy_array(packed.get("packed_instance_ids", [])).size() == 1, "Housed packing did not select one item.")
	_check(_copy_array(duplicate_pack.get("packed_instance_ids", [])).size() == 1, "Packing the same item twice duplicated it.")
	service.add_gold(250)
	var apartment: Dictionary = service.purchase_housing_upgrade()
	_check(bool(apartment.get("ok", false)) and service.housing_tier() == MetaCollectionServiceScript.HOUSING_APARTMENT, "Gold purchase did not upgrade to apartment.")
	_check(service.trade_up_unlocked(), "Apartment must unlock trade-ups.")
	_remove_user_file(TEST_STORE_PATH)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, "")


func _test_pawn_sale_and_trade_up(resolver: Variant) -> void:
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, TEST_STORE_PATH)
	_remove_user_file(TEST_STORE_PATH)
	var service: Variant = MetaCollectionServiceScript.new()
	service.load()
	service.add_gold(310)
	service.purchase_housing_upgrade()
	service.purchase_housing_upgrade()
	var ids: Array = []
	for index in range(5):
		var granted: Dictionary = service.grant_instance(resolver.roll_instance(1000, "trade-%d" % index))
		ids.append(int(granted.get("instance_id", 0)))
	var trade: Dictionary = service.arm_trade_up(ids)
	_check(bool(trade.get("ok", false)), "Apartment trade-up did not arm for five matching items.")
	var trade_result: Dictionary = service.confirm_trade_up(str(trade.get("token", "")))
	_check(bool(trade_result.get("ok", false)), "Apartment trade-up did not confirm.")
	_check(service.owned_instances().size() == 1, "Trade-up did not consume five items and grant one output.")
	var output := _copy_dict(service.owned_instances()[0])
	var output_def: Dictionary = resolver.item_definition(int(output.get("itemdef_id", -1)))
	_check(str(output_def.get("tier", "")) == "purple", "Trade-up output did not move to the next tier.")
	var sale: Dictionary = service.arm_sale(MetaCollectionServiceScript.SALE_KIND_ITEM, int(output.get("instance_id", 0)))
	_check(bool(sale.get("ok", false)) and int(sale.get("price", 0)) > 0, "Pawn sale did not produce a deterministic item quote.")
	var sale_result: Dictionary = service.confirm_sale(str(sale.get("token", "")))
	_check(bool(sale_result.get("ok", false)) and int(sale_result.get("gold_balance", 0)) > 0, "Pawn sale did not mint gold on confirmation.")
	_check(service.owned_instances().is_empty(), "Pawn sale did not remove the sold item.")
	_remove_user_file(TEST_STORE_PATH)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, "")


func _test_failure_decay_and_run_modifiers(resolver: Variant) -> void:
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, TEST_STORE_PATH)
	_remove_user_file(TEST_STORE_PATH)
	var service: Variant = MetaCollectionServiceScript.new()
	service.load()
	var granted: Dictionary = service.grant_instance(resolver.roll_instance(1000, "failure-decay"))
	var modifiers: Dictionary = service.normal_run_start_modifiers()
	_check(str(modifiers.get("home_archetype_id", "")) == MetaCollectionServiceScript.HOUSING_BACK_ALLEY, "Homeless normal run must start at the back alley archetype.")
	_check(_copy_array(modifiers.get("meta_collection_carried_instance_ids", [])).has(int(granted.get("instance_id", 0))), "Homeless normal run must carry every owned item.")
	_check(_copy_array(modifiers.get("meta_collection_loadout", [])).size() == 1, "Normal run modifiers did not inject resolved run items.")
	var before_usage := float(granted.get("usage", 0.0))
	var decayed: Array = service.apply_failure_decay([int(granted.get("instance_id", 0))], "failure-decay-seed")
	var after := _copy_dict(decayed[0]) if not decayed.is_empty() else {}
	_check(float(after.get("usage", 1.0)) < before_usage, "Failure decay did not reduce carried item usage.")
	_remove_user_file(TEST_STORE_PATH)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, "")


func _test_terminal_drop_determinism() -> void:
	var drop_service: Variant = CollectionDropServiceScript.new()
	var run_a: Variant = _terminal_run("p1-deterministic-seed")
	var run_b: Variant = _terminal_run("p1-deterministic-seed")
	var markers_a: Array = drop_service.ensure_run_end_pending_bags(run_a, null)
	var markers_b: Array = drop_service.ensure_run_end_pending_bags(run_b, null)
	_check(not markers_a.is_empty(), "Terminal victory did not create a pending collection bag marker.")
	_check(JSON.stringify(markers_a) == JSON.stringify(markers_b), "Same seed and outcome did not produce identical pending bag drops.")
	var restored: Variant = RunStateScript.new()
	restored.from_dict(run_a.to_dict())
	_check(JSON.stringify(restored.pending_bag_markers()) == JSON.stringify(markers_a), "Pending bag markers did not round-trip through RunState save data.")


func _test_run_end_grant_persists() -> void:
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, TEST_STORE_PATH)
	_remove_user_file(TEST_STORE_PATH)
	var service: Variant = MetaCollectionServiceScript.new()
	service.load()
	var drop_service: Variant = CollectionDropServiceScript.new()
	var run_state: Variant = _terminal_run("p1-grant-seed")
	var markers: Array = drop_service.ensure_run_end_pending_bags(run_state, null)
	var flush_result: Dictionary = drop_service.flush_pending_bags(run_state, service)
	_check(markers.size() >= 2, "Standard meta victory plus showdown should create at least two pending bags.")
	_check(_copy_array(flush_result.get("granted", [])).size() == markers.size(), "Run-end flush did not grant each pending bag.")
	_check(run_state.pending_bag_markers().is_empty(), "Run-end flush did not clear pending bag markers.")
	_check(bool(run_state.narrative_flags.get(CollectionDropServiceScript.FLUSHED_FLAG, false)), "Run-end flush flag was not recorded.")
	var save_error: Error = service.save()
	_check(save_error == OK, "Meta collection store save after run-end grant failed.")
	var loaded_service: Variant = MetaCollectionServiceScript.new()
	var loaded: Dictionary = loaded_service.load()
	_check(_copy_array(loaded.get("unopened_bags", [])).size() == markers.size(), "Granted bags did not survive meta store reload.")
	_remove_user_file(TEST_STORE_PATH)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, "")


func _test_daily_and_challenge_runs_are_meta_isolated() -> void:
	var drop_service: Variant = CollectionDropServiceScript.new()
	var service: Variant = MetaCollectionServiceScript.new()
	service.load()
	var before_json := JSON.stringify(service.snapshot())
	var daily: Variant = _terminal_run("daily-meta-isolated", "", false, "daily")
	var authored: Variant = _terminal_run("challenge-meta-isolated", "challenge_complete", false, "custom")
	_check(drop_service.ensure_run_end_pending_bags(daily, null).is_empty(), "Daily runs must not create pending meta bags.")
	_check(drop_service.ensure_run_end_pending_bags(authored, null).is_empty(), "Challenge runs must not create pending meta bags.")
	drop_service.flush_pending_bags(daily, service)
	drop_service.flush_pending_bags(authored, service)
	_check(JSON.stringify(service.snapshot()) == before_json, "Daily/challenge flush must not mutate meta collection storage.")


func _test_open_bag_consumes_once() -> void:
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, TEST_STORE_PATH)
	_remove_user_file(TEST_STORE_PATH)
	var service: Variant = MetaCollectionServiceScript.new()
	service.load()
	var granted: Dictionary = service.grant_bag(9000, "p1-open-seed", {"display_name": "Roadside Luck Blue Bag"})
	var instance_id := int(granted.get("instance_id", 0))
	var before_rng := JSON.stringify(service.meta_rng_snapshot())
	var first: Dictionary = service.open_bag(instance_id)
	var second: Dictionary = service.open_bag(instance_id)
	var third: Dictionary = service.open_bag(instance_id)
	_check(bool(first.get("ok", false)), "First bag open did not succeed.")
	_check(not bool(second.get("ok", true)) and not bool(third.get("ok", true)), "Repeated bag opens were not rejected.")
	_check(service.unopened_bags().is_empty(), "Opened bag was not removed from unopened storage.")
	_check(service.owned_instances().size() == 1, "Opening one bag did not grant exactly one item instance.")
	_check(JSON.stringify(service.meta_rng_snapshot()) != before_rng, "Opening a bag did not advance the persisted meta RNG stream.")
	_remove_user_file(TEST_STORE_PATH)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, "")


func _test_collection_browser_view_model_read_only(resolver: Variant) -> void:
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, TEST_STORE_PATH)
	_remove_user_file(TEST_STORE_PATH)
	var service: Variant = MetaCollectionServiceScript.new()
	service.load()
	service.grant_instance(resolver.roll_instance(1000, "browser-owned-seed"))
	service.grant_bag(9010, "browser-bag-seed", {"display_name": "House Edge Blue Bag"})
	var before_json := JSON.stringify(service.snapshot())
	var view: Dictionary = MetaCollectionViewModelScript.build(service)
	var after_json := JSON.stringify(service.snapshot())
	_check(before_json == after_json, "Collection browser view-model mutated the meta store.")
	_check(_copy_array(view.get("collections", [])).size() == 2, "Collection browser did not list both launch collections.")
	_check(_copy_array(view.get("unopened_bags", [])).size() == 1, "Collection browser did not list unopened bags.")
	_check(int(view.get("owned_count", 0)) == 1, "Collection browser owned count mismatch.")
	var home := _copy_dict(view.get("home", {}))
	_check(str(home.get("housing_tier", "")) == MetaCollectionServiceScript.HOUSING_BACK_ALLEY, "Collection browser did not expose meta home state.")
	_check(str(_copy_dict(home.get("pawn_shop", {})).get("interaction", "")) == "sell_counter_only", "Collection browser did not restrict pawn shop to sell counter.")
	_remove_user_file(TEST_STORE_PATH)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, "")


func _test_end_summary_lists_bags() -> void:
	var drop_service: Variant = CollectionDropServiceScript.new()
	var marker: Dictionary = drop_service.marker_from_static_bag(9000, "test", "summary")
	var lines: Array = drop_service.summary_lines_for_markers([marker])
	_check(lines.size() == 1, "Bag summary did not produce one line.")
	var text := str(lines[0]) if not lines.is_empty() else ""
	_check(text.contains("Roadside Luck") and text.contains("Blue"), "Bag summary did not include collection and tier.")


func _terminal_run(seed: String, completion_flag: String = "", meta_enabled: bool = true, mode: String = "standard") -> Variant:
	var run_state: Variant = RunStateScript.new()
	var config := {
		"mode": mode,
		"id": mode if mode != "standard" else "standard",
		"title": "P1 Meta",
		"seed_text": seed,
		"daily_id": "",
		"modifiers": {"meta_collection_enabled": true} if meta_enabled else {},
		"hidden_seed": false,
	}
	if not completion_flag.is_empty():
		config["completion_flag"] = completion_flag
	run_state.start_new(seed, config)
	run_state.bankroll = 500
	run_state.suspicion["level"] = 72
	run_state.run_status = RunStateScript.RUN_STATUS_ENDED
	run_state.narrative_flags["demo_victory"] = true
	run_state.narrative_flags["demo_victory_route"] = RunStateScript.GRAND_CASINO_SHOWDOWN_ROUTE
	return run_state


func _instance_ids(instances: Array) -> Array:
	var ids: Array = []
	for instance_value in instances:
		var instance := _copy_dict(instance_value)
		ids.append(int(instance.get("instance_id", 0)))
	return ids


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
