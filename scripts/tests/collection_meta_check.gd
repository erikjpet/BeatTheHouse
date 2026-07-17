extends SceneTree

const CollectionItemResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const CollectionDropServiceScript := preload("res://scripts/core/collection_drop_service.gd")
const MetaCollectionViewModelScript := preload("res://scripts/ui/meta_collection_view_model.gd")
const RunReportViewModelScript := preload("res://scripts/ui/run_report_view_model.gd")
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
	_test_players_card_schema_and_fragility(resolver)
	_test_float_determinism(resolver)
	_test_usage_decay(resolver)
	_test_resolve_run_item(resolver)
	_test_store_round_trip(resolver)
	_test_meta_home_rules(resolver)
	_test_pawn_sale_and_trade_up(resolver)
	_test_failure_decay_and_run_modifiers(resolver)
	_test_players_card_mint_and_profile_lifecycle()
	_test_uncashed_grand_casino_chips_pawn_flow()
	_test_prestige_run_modifiers_and_drop_depth()
	_test_terminal_drop_determinism()
	_test_victory_selection_grants_one_bag()
	_test_failed_run_discards_pending_bags()
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


func _test_players_card_schema_and_fragility(resolver: Variant) -> void:
	var special_items: Array = resolver.special_item_definitions()
	_check(special_items.size() == 2, "Collection schema must define Players Card and chip-stack special items.")
	var definition: Dictionary = resolver.item_definition(MetaCollectionServiceScript.PLAYERS_CARD_ITEMDEF_ID)
	_check(str(definition.get("item_class", "")) == CollectionItemResolverScript.ITEM_CLASS_PLAYERS_CARD, "Players Card is not a first-class players_card item.")
	var normalized: Dictionary = resolver.normalize_instance_for_definition({
		"itemdef_id": MetaCollectionServiceScript.PLAYERS_CARD_ITEMDEF_ID,
		"potency": 0.4,
		"condition": 1.0,
		"resonance": 0.6,
		"usage": 0.2,
	})
	_check(float(normalized.get("condition", 1.0)) <= 0.10 and bool(normalized.get("durability_pinned", false)), "Players Card condition was not pinned to the critical band.")
	var decayed: Dictionary = resolver.apply_usage_decay(normalized, "players-card-no-decay")
	_check(is_equal_approx(float(decayed.get("condition", 0.0)), float(normalized.get("condition", 1.0))) and is_equal_approx(float(decayed.get("usage", 0.0)), 1.0), "Players Card was not exempt from normal usage decay.")
	var rolled: Dictionary = resolver.roll_instance(MetaCollectionServiceScript.PLAYERS_CARD_ITEMDEF_ID, "players-card-roll")
	_check(is_equal_approx(float(rolled.get("condition", 1.0)), float(normalized.get("condition", 0.0))), "Players Card roll boundary did not keep durability pinned.")
	var run_item: Dictionary = resolver.resolve_run_item(normalized)
	_check(str(_copy_dict(run_item.get("meta_collection", {})).get("condition_band", "")) == "critical", "Players Card did not resolve in the critical durability band.")
	var chip_definition: Dictionary = resolver.item_definition(MetaCollectionServiceScript.GRAND_CASINO_CHIPS_ITEMDEF_ID)
	_check(str(chip_definition.get("item_class", "")) == CollectionItemResolverScript.ITEM_CLASS_CHIP_STACK and not bool(chip_definition.get("loadout_eligible", true)), "Grand Casino Chips are not a first-class meta-only chip stack.")
	var chip_policy := _copy_dict(chip_definition.get("sale_policy", {}))
	_check(str(chip_policy.get("kind", "")) == "face_value_rate" and is_equal_approx(float(chip_policy.get("gold_rate", 0.0)), 0.6), "Grand Casino Chips do not carry Sal's tuned 60% fenced rate.")


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
	var before_condition := float(granted.get("condition", 0.0))
	var decayed: Array = service.apply_failure_decay([int(granted.get("instance_id", 0))], "failure-decay-seed")
	var after := _copy_dict(decayed[0]) if not decayed.is_empty() else {}
	_check(is_equal_approx(float(after.get("condition", 1.0)), maxf(0.0, before_condition - MetaCollectionServiceScript.FAILURE_DURABILITY_LOSS)), "Failure decay did not reduce carried item condition by 10%.")
	var fragile := after.duplicate(true)
	fragile["condition"] = 0.05
	var fragile_grant: Dictionary = service.grant_instance(fragile)
	var fragile_id := int(fragile_grant.get("instance_id", 0))
	service.apply_failure_decay([fragile_id], "failure-delete-seed")
	_check(not _instance_ids(service.owned_instances()).has(fragile_id), "Failure decay did not delete a zero-condition carried item.")
	_remove_user_file(TEST_STORE_PATH)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, "")


func _test_players_card_mint_and_profile_lifecycle() -> void:
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, TEST_STORE_PATH)
	_remove_user_file(TEST_STORE_PATH)
	var service: Variant = MetaCollectionServiceScript.new()
	service.load()
	var drop_service: Variant = CollectionDropServiceScript.new()
	var clean_run: Variant = _terminal_run("players-card-clean")
	clean_run.narrative_flags["demo_victory_route"] = RunStateScript.GRAND_CASINO_HIGH_ROLLER_EVENT_ID
	clean_run.narrative_flags["grand_casino_players_card_tier"] = RunStateScript.GRAND_CASINO_PLAYERS_CARD_TIER_GOLD
	clean_run.narrative_flags["grand_casino_players_card_highest_tier"] = RunStateScript.GRAND_CASINO_PLAYERS_CARD_TIER_GOLD
	clean_run.run_spending_score = 37
	clean_run.game_clock_minutes = 1440 + 900
	clean_run.log_story({"type": "grand_casino_players_card_tier", "tier": "bronze", "games_played": 1, "net_winnings": 5})
	clean_run.log_story({"type": "grand_casino_players_card_tier", "tier": "silver", "games_played": 3, "net_winnings": 15})
	clean_run.log_story({"type": "grand_casino_players_card_tier", "tier": "gold", "games_played": 5, "net_winnings": 30})
	var mint_result: Dictionary = drop_service.apply_terminal_special_outcome(clean_run, service)
	var mint_repeat: Dictionary = drop_service.apply_terminal_special_outcome(clean_run, service)
	_check(bool(mint_result.get("mutated", false)) and not bool(mint_repeat.get("mutated", true)), "Clean win did not mint exactly one Players Card.")
	var owned: Array = service.owned_instances()
	_check(owned.size() == 1, "Clean win did not add one Players Card instance to the profile.")
	var card := _copy_dict(owned[0]) if not owned.is_empty() else {}
	var stamp := _copy_dict(card.get("instance_data", {}))
	_check(
		str(stamp.get("seed", "")) == "players-card-clean" and int(stamp.get("final_score", 0)) == int(clean_run.terminal_score_summary().get("score", 0)) and int(stamp.get("days_survived", 0)) == 2,
		"Players Card stamp did not preserve seed, score, and days: %s" % JSON.stringify(stamp)
	)
	_check(_copy_array(stamp.get("tier_timeline", [])).size() == 3 and str(stamp.get("route", "")) == RunStateScript.GRAND_CASINO_HIGH_ROLLER_EVENT_ID, "Players Card stamp did not preserve tier timeline and route.")
	var report_reward := _copy_dict(RunReportViewModelScript.build(clean_run.to_dict()).get("meta_reward", {}))
	_check(bool(report_reward.get("visible", false)) and str(report_reward.get("kind", "")) == "players_card_minted", "Run report did not surface the minted Players Card in RESULT.")
	var showdown_run: Variant = _terminal_run("players-card-showdown")
	drop_service.apply_terminal_special_outcome(showdown_run, service)
	var failed_run: Variant = _terminal_run("players-card-failed")
	failed_run.run_status = RunStateScript.RUN_STATUS_FAILED
	drop_service.apply_terminal_special_outcome(failed_run, service)
	_check(service.owned_instances().size() == 1, "Showdown or failed route incorrectly minted a Players Card.")
	var save_error: Error = service.save()
	_check(save_error == OK, "Players Card profile save failed.")
	var restored_service: Variant = MetaCollectionServiceScript.new()
	restored_service.load()
	_check(restored_service.owned_instances().size() == 1, "Players Card did not survive profile restart.")
	var prestige_modifiers: Dictionary = restored_service.normal_run_start_modifiers()
	var prestige_win: Variant = _terminal_run_with_modifiers("players-card-survival", prestige_modifiers, RunStateScript.RUN_STATUS_ENDED, RunStateScript.GRAND_CASINO_SHOWDOWN_ROUTE)
	drop_service.apply_terminal_special_outcome(prestige_win, restored_service)
	_check(restored_service.owned_instances().size() == 1 and str(_copy_dict(prestige_win.narrative_flags.get(CollectionDropServiceScript.PRESTIGE_RESULT_FLAG, {})).get("status", "")) == "retained", "Carried Players Card was not retained after a successful prestige run.")
	var prestige_run: Variant = _terminal_run_with_modifiers("players-card-loss", prestige_modifiers, RunStateScript.RUN_STATUS_FAILED, "")
	var loss_result: Dictionary = drop_service.apply_terminal_special_outcome(prestige_run, restored_service)
	_check(_copy_array(loss_result.get("destroyed_cards", [])).size() == 1 and restored_service.owned_instances().is_empty(), "Carried Players Card was not destroyed forever on run loss.")
	_check(restored_service.save() == OK, "Destroyed Players Card profile save failed.")
	var post_loss_service: Variant = MetaCollectionServiceScript.new()
	post_loss_service.load()
	_check(post_loss_service.owned_instances().is_empty(), "Destroyed Players Card returned after profile restart.")
	var hidden_service: Variant = MetaCollectionServiceScript.new()
	_remove_user_file(TEST_STORE_PATH)
	hidden_service.load()
	var hidden_run: Variant = _terminal_run("owner-secret-seed")
	hidden_run.challenge_config["hidden_seed"] = true
	hidden_run.narrative_flags["demo_victory_route"] = RunStateScript.GRAND_CASINO_HIGH_ROLLER_EVENT_ID
	drop_service.apply_terminal_special_outcome(hidden_run, hidden_service)
	var hidden_card := _copy_dict(hidden_service.owned_instances()[0]) if not hidden_service.owned_instances().is_empty() else {}
	var hidden_stamp := _copy_dict(hidden_card.get("instance_data", {}))
	_check(bool(hidden_stamp.get("seed_hidden", false)) and str(hidden_stamp.get("seed", "")).find("owner-secret-seed") < 0, "Hidden challenge seed leaked into the Players Card stamp.")
	_remove_user_file(TEST_STORE_PATH)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, "")


func _test_uncashed_grand_casino_chips_pawn_flow() -> void:
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, TEST_STORE_PATH)
	_remove_user_file(TEST_STORE_PATH)
	var service: Variant = MetaCollectionServiceScript.new()
	service.load()
	var drop_service: Variant = CollectionDropServiceScript.new()
	var shown_run: Variant = _terminal_run("shown-door-chip-stack")
	shown_run.bankroll = 123
	shown_run.grand_casino_chips = 37
	shown_run.narrative_flags["grand_casino_walked_with_chips"] = true
	shown_run.narrative_flags["grand_casino_duel_outcome"] = "shown_the_door"
	shown_run.narrative_flags["grand_casino_uncashed_chip_amount"] = 37
	var grant_result: Dictionary = drop_service.apply_terminal_special_outcome(shown_run, service)
	var repeated_result: Dictionary = drop_service.apply_terminal_special_outcome(shown_run, service)
	_check(bool(grant_result.get("mutated", false)) and not bool(repeated_result.get("mutated", true)), "Shown-door ending did not grant exactly one chip stack.")
	var owned: Array = service.owned_instances()
	_check(owned.size() == 1, "Shown-door ending did not add one Grand Casino Chips stack to meta storage.")
	var chip_stack := _copy_dict(owned[0]) if not owned.is_empty() else {}
	_check(str(chip_stack.get("item_class", "")) == CollectionItemResolverScript.ITEM_CLASS_CHIP_STACK and int(chip_stack.get("stack_amount", 0)) == 37 and int(chip_stack.get("face_value", 0)) == 37, "Grand Casino Chips stack did not preserve the exact uncashed amount as face value.")
	var run_modifiers: Dictionary = service.normal_run_start_modifiers()
	_check(not _copy_array(run_modifiers.get("meta_collection_carried_instance_ids", [])).has(int(chip_stack.get("instance_id", 0))) and _copy_array(run_modifiers.get("meta_collection_loadout", [])).is_empty(), "Grand Casino Chips leaked from meta storage into a run loadout.")
	var markers: Array = drop_service.ensure_run_end_pending_bags(shown_run, null)
	_check(not markers.is_empty(), "Shown-door chip stack was not granted alongside the existing run-end drop flow.")
	var report_reward := _copy_dict(RunReportViewModelScript.build(shown_run.to_dict()).get("meta_reward", {}))
	_check(str(report_reward.get("kind", "")) == "grand_casino_chips" and str(report_reward.get("title", "")).contains("×37"), "Run report did not surface the uncashed Grand Casino Chips stack.")
	_check(service.save() == OK, "Grand Casino Chips profile save failed.")
	var restored: Variant = MetaCollectionServiceScript.new()
	restored.load()
	var restored_owned: Array = restored.owned_instances()
	_check(restored_owned.size() == 1 and int(_copy_dict(restored_owned[0]).get("face_value", 0)) == 37, "Grand Casino Chips did not survive profile restart with exact face value.")
	var instance_id := int(_copy_dict(restored_owned[0]).get("instance_id", 0)) if not restored_owned.is_empty() else 0
	var quote: Dictionary = restored.sale_quote(MetaCollectionServiceScript.SALE_KIND_ITEM, instance_id)
	_check(bool(quote.get("ok", false)) and int(quote.get("price", 0)) == 22 and is_equal_approx(float(quote.get("gold_rate", 0.0)), 0.6), "Sal did not price the 37-chip stack at the tuned 60% fenced rate.")
	var run_cash_before: int = shown_run.bankroll
	var run_chips_before: int = shown_run.grand_casino_chips
	var armed: Dictionary = restored.arm_sale(MetaCollectionServiceScript.SALE_KIND_ITEM, instance_id)
	var sold: Dictionary = restored.confirm_sale(str(armed.get("token", "")))
	_check(bool(sold.get("ok", false)) and int(sold.get("gold_balance", 0)) == 22 and restored.owned_instances().is_empty(), "Sal's existing sale flow did not consume the chip stack and grant fenced gold.")
	_check(shown_run.bankroll == run_cash_before and shown_run.grand_casino_chips == run_chips_before, "Selling the meta chip stack mutated run cash or run chips.")
	var clean_showdown: Variant = _terminal_run("clean-showdown-no-chip-stack")
	drop_service.apply_terminal_special_outcome(clean_showdown, restored)
	var failed_showdown: Variant = _terminal_run("failed-showdown-no-chip-stack")
	failed_showdown.run_status = RunStateScript.RUN_STATUS_FAILED
	failed_showdown.narrative_flags["grand_casino_walked_with_chips"] = true
	failed_showdown.narrative_flags["grand_casino_duel_outcome"] = "taken_out_back"
	failed_showdown.narrative_flags["grand_casino_uncashed_chip_amount"] = 99
	drop_service.apply_terminal_special_outcome(failed_showdown, restored)
	_check(restored.owned_instances().is_empty(), "Clean or failed showdown route incorrectly granted a Grand Casino Chips stack.")
	_remove_user_file(TEST_STORE_PATH)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, "")


func _test_prestige_run_modifiers_and_drop_depth() -> void:
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, TEST_STORE_PATH)
	_remove_user_file(TEST_STORE_PATH)
	var ordinary: Variant = MetaCollectionServiceScript.new()
	ordinary.load()
	var ordinary_modifiers: Dictionary = ordinary.normal_run_start_modifiers()
	_check(not bool(ordinary_modifiers.get("grand_casino_prestige", false)), "Non-prestige profile received prestige run modifiers.")
	ordinary.mint_players_card({"seed": "prestige-origin", "final_score": 80, "days_survived": 2, "tier_timeline": [], "route": RunStateScript.GRAND_CASINO_HIGH_ROLLER_EVENT_ID})
	var prestige_modifiers: Dictionary = ordinary.normal_run_start_modifiers()
	_check(bool(prestige_modifiers.get("grand_casino_prestige", false)), "Carried Players Card did not mark the run as prestige.")
	_check(int(prestige_modifiers.get("grand_casino_prestige_recognition_heat_delta", 0)) < 0 and int(prestige_modifiers.get("grand_casino_prestige_clean_heat_ceiling_delta", 0)) < 0 and int(prestige_modifiers.get("meta_collection_drop_tier_bonus_steps", 0)) > 0, "Prestige tunables were not injected into run modifiers.")
	var prestige_run: Variant = RunStateScript.new()
	prestige_run.start_new("prestige-entry", {
		"mode": "standard",
		"id": "standard",
		"seed_text": "prestige-entry",
		"modifiers": prestige_modifiers,
	})
	prestige_run.suspicion["local_levels"] = {RunStateScript.GRAND_CASINO_ARCHETYPE_ID: 20}
	prestige_run.set_environment(_grand_casino_environment_fixture())
	var prestige_status: Dictionary = prestige_run.grand_casino_prestige_status()
	var objective: Dictionary = prestige_run.demo_objective_status()
	_check(bool(prestige_status.get("recognition_applied", false)) and prestige_run.suspicion_level() == 10, "Prestige recognition did not reduce initial Grand Casino attention by the tuned amount.")
	_check(int(objective.get("high_roller_max_heat", 30)) == 25 and int(objective.get("players_card_next_max_heat", 30)) == 25, "Prestige expectations did not tighten the clean-route heat ceiling.")
	var drop_service: Variant = CollectionDropServiceScript.new()
	var regular_drop_run: Variant = _terminal_run("prestige-drop-depth")
	var prestige_drop_run: Variant = _terminal_run_with_modifiers("prestige-drop-depth", prestige_modifiers, RunStateScript.RUN_STATUS_ENDED, RunStateScript.GRAND_CASINO_SHOWDOWN_ROUTE)
	var regular_markers: Array = drop_service.ensure_run_end_pending_bags(regular_drop_run, null)
	var prestige_markers: Array = drop_service.ensure_run_end_pending_bags(prestige_drop_run, null)
	_check(regular_markers.size() == prestige_markers.size() and not regular_markers.is_empty(), "Prestige drop comparison did not produce matching deterministic marker counts.")
	for index in range(mini(regular_markers.size(), prestige_markers.size())):
		var regular_marker := _copy_dict(regular_markers[index])
		var regular_rolled_tier := str(regular_marker.get("rolled_tier", ""))
		var regular_tier := str(regular_marker.get("tier", ""))
		_check(regular_tier == regular_rolled_tier and int(regular_marker.get("tier_bonus_steps", -1)) == 0, "Non-prestige drop changed its existing deterministic tier roll.")
		var prestige_marker := _copy_dict(prestige_markers[index])
		var prestige_rolled_tier := str(prestige_marker.get("rolled_tier", ""))
		var prestige_tier := str(prestige_marker.get("tier", ""))
		var bonus_steps := int(prestige_modifiers.get("meta_collection_drop_tier_bonus_steps", 0))
		var expected_index := mini(CollectionItemResolverScript.TIERS.size() - 1, CollectionItemResolverScript.TIERS.find(prestige_rolled_tier) + bonus_steps)
		_check(int(prestige_marker.get("tier_bonus_steps", -1)) == bonus_steps and CollectionItemResolverScript.TIERS.find(prestige_tier) == expected_index, "Prestige drop did not promote its existing deterministic tier roll.")
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


func _test_victory_selection_grants_one_bag() -> void:
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, TEST_STORE_PATH)
	_remove_user_file(TEST_STORE_PATH)
	var service: Variant = MetaCollectionServiceScript.new()
	service.load()
	var drop_service: Variant = CollectionDropServiceScript.new()
	var run_state: Variant = _terminal_run("p1-grant-seed")
	var markers: Array = drop_service.ensure_run_end_pending_bags(run_state, null)
	_check(markers.size() >= 2, "Standard meta victory plus showdown should create at least two pending bags.")
	var selected := _copy_dict(markers[0])
	var flush_result: Dictionary = drop_service.flush_selected_pending_bag(run_state, service, str(selected.get("marker_id", "")))
	_check(_copy_array(flush_result.get("granted", [])).size() == 1, "Victory extraction did not grant exactly one selected bag.")
	_check(run_state.pending_bag_markers().is_empty(), "Run-end flush did not clear pending bag markers.")
	_check(bool(run_state.narrative_flags.get(CollectionDropServiceScript.FLUSHED_FLAG, false)), "Run-end flush flag was not recorded.")
	var save_error: Error = service.save()
	_check(save_error == OK, "Meta collection store save after run-end grant failed.")
	var loaded_service: Variant = MetaCollectionServiceScript.new()
	var loaded: Dictionary = loaded_service.load()
	_check(_copy_array(loaded.get("unopened_bags", [])).size() == 1, "Selected bag did not survive meta store reload as the only grant.")
	_remove_user_file(TEST_STORE_PATH)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, "")


func _test_failed_run_discards_pending_bags() -> void:
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, TEST_STORE_PATH)
	_remove_user_file(TEST_STORE_PATH)
	var service: Variant = MetaCollectionServiceScript.new()
	service.load()
	var drop_service: Variant = CollectionDropServiceScript.new()
	var run_state: Variant = _terminal_run("p1-failure-pending")
	run_state.run_status = RunStateScript.RUN_STATUS_FAILED
	run_state.add_pending_bag_marker(drop_service.marker_from_static_bag(9000, "legacy_event", "removed_bag_marker", "failure-bag"))
	var flush_result: Dictionary = drop_service.flush_pending_bags(run_state, service)
	_check(_copy_array(flush_result.get("granted", [])).is_empty(), "Failed run must not grant pending bag rewards.")
	_check(run_state.pending_bag_markers().is_empty(), "Failed run did not discard pending bag markers.")
	_check(service.unopened_bags().is_empty(), "Failed run leaked an unopened bag into meta storage.")
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


func _terminal_run_with_modifiers(seed: String, modifiers: Dictionary, status: String, route: String) -> Variant:
	var run_state: Variant = RunStateScript.new()
	run_state.start_new(seed, {
		"mode": "standard",
		"id": "standard",
		"title": "P1 Meta",
		"seed_text": seed,
		"modifiers": modifiers.duplicate(true),
	})
	run_state.bankroll = 500
	run_state.run_status = status
	if status == RunStateScript.RUN_STATUS_ENDED:
		run_state.narrative_flags["demo_victory"] = true
		run_state.narrative_flags["demo_victory_route"] = route
	return run_state


func _grand_casino_environment_fixture() -> Dictionary:
	return {
		"id": RunStateScript.GRAND_CASINO_ARCHETYPE_ID,
		"archetype_id": RunStateScript.GRAND_CASINO_ARCHETYPE_ID,
		"display_name": "Grand Casino",
		"demo_objective": {
			"id": RunStateScript.GRAND_CASINO_OBJECTIVE_ID,
			"type": "bankroll",
			"target_bankroll": 500,
			"high_roller_target_bankroll": 500,
			"high_roller_net_winnings": 30,
			"high_roller_min_grand_casino_games": 5,
			"high_roller_max_heat": 30,
			"players_card_bronze_max_heat": 30,
			"players_card_silver_max_heat": 30,
			"players_card_gold_max_heat": 30,
		},
	}


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
