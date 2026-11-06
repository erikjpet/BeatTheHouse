class_name CollectionDropService
extends RefCounted

const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")

# Run-boundary bridge: run code records pending markers, this service turns
# terminal run outcomes into meta collection grants.

const CollectionItemResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const GrandCasinoDuelModelScript := preload("res://scripts/core/grand_casino_duel_model.gd")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")

const EVALUATED_FLAG := "_meta_bag_drops_evaluated"
const FLUSHED_FLAG := "_meta_bag_grants_flushed"
const GRANTS_FLAG := "_meta_bag_grants"
const SELECTED_FLAG := "_meta_bag_selected"
const SPECIAL_OUTCOME_PROCESSED_FLAG := "_meta_special_outcome_processed"
const SPECIAL_OUTCOME_RECORD_FLAG := "_meta_special_outcome_record"
const SPECIAL_OUTCOME_ACK_FLAG := "_meta_special_outcome_ack_saved"
const PLAYERS_CARD_REWARD_FLAG := "_meta_players_card_reward"
const TUTORIAL_BRONZE_ROUTE := "tutorial_bronze_card"
const PLAYERS_CARD_DESTROYED_FLAG := "_meta_players_card_destroyed"
const GRAND_CASINO_CHIPS_REWARD_FLAG := "_meta_grand_casino_chips_reward"
const PRESTIGE_RESULT_FLAG := "_meta_prestige_result"
const SAL_STOCK_RECEIPT_FLAG := "_sal_resale_stock_receipt"
const SAL_STOCK_PROCESSED_FLAG := "_sal_resale_stock_processed"
const SAL_STOCK_SUMMARY_FLAG := "_sal_resale_stock_summary"
const HIGH_HEAT_CLEAN_ESCAPE_THRESHOLD := 65
const HIGH_HEAT_CLEAN_ESCAPE_CHANCE_PERCENT := 35

var _collection_item_resolver: Variant = CollectionItemResolverScript.new()


func stock_sal_after_success(run_state: RunState, meta_collection_service: Variant) -> Dictionary:
	if run_state == null or meta_collection_service == null:
		return {"ok": false, "stocked": false}
	if run_state.run_status != RunState.RUN_STATUS_ENDED or not run_state.is_terminal():
		return {"ok": true, "stocked": false}
	if bool(run_state.challenge_config.get("preview", false)) or bool(run_state.challenge_config.get("dry_run", false)) or bool(run_state.narrative_flags.get("preview", false)) or bool(run_state.narrative_flags.get("dry_run", false)):
		return {"ok": true, "stocked": false}
	if bool(run_state.narrative_flags.get(SAL_STOCK_PROCESSED_FLAG, false)):
		return {
			"ok": true,
			"stocked": false,
			"receipt": str(run_state.narrative_flags.get(SAL_STOCK_RECEIPT_FLAG, "")),
			"summary_line": str(run_state.narrative_flags.get(SAL_STOCK_SUMMARY_FLAG, "")),
		}
	var receipt := str(run_state.narrative_flags.get(SAL_STOCK_RECEIPT_FLAG, "")).strip_edges()
	if receipt.is_empty():
		receipt = meta_collection_service.allocate_sal_run_receipt(run_state.seed_text)
		run_state.narrative_flags[SAL_STOCK_RECEIPT_FLAG] = receipt
	if meta_collection_service.sal_run_receipt_processed(receipt):
		run_state.narrative_flags[SAL_STOCK_PROCESSED_FLAG] = true
		run_state.narrative_flags[SAL_STOCK_SUMMARY_FLAG] = "Sal stocked something new."
		return {"ok": true, "stocked": false, "recovered": true, "receipt": receipt, "summary_line": "Sal stocked something new."}
	var result: Dictionary = meta_collection_service.generate_and_insert_sal_stock(receipt)
	if not bool(result.get("stocked", false)):
		return result
	var save_error: Error = meta_collection_service.save()
	if save_error != OK:
		meta_collection_service.load()
		run_state.narrative_flags.erase(SAL_STOCK_RECEIPT_FLAG)
		return {"ok": false, "stocked": false, "save_error": save_error, "message": "Sal stock could not be saved."}
	var summary_line := str(result.get("summary_line", "Sal stocked something new."))
	run_state.narrative_flags[SAL_STOCK_PROCESSED_FLAG] = true
	run_state.narrative_flags[SAL_STOCK_SUMMARY_FLAG] = summary_line
	run_state.log_story({
		"type": "sal_resale_stocked",
		"receipt": receipt,
		"slot_index": int(result.get("slot_index", -1)),
		"message": summary_line,
	})
	return result


func terminal_special_outcome_eligible(run_state: RunState) -> bool:
	if run_state == null or not run_state.is_terminal():
		return false
	return run_state.meta_collection_enabled_for_run() or (run_state.is_tutorial_run() \
		and run_state.run_status == RunState.RUN_STATUS_ENDED \
		and [RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID, TUTORIAL_BRONZE_ROUTE].has(str(run_state.narrative_flags.get("demo_victory_route", ""))))


func terminal_special_outcome_pending(run_state: RunState) -> bool:
	if not terminal_special_outcome_eligible(run_state):
		return false
	if run_state.narrative_flags.has(SPECIAL_OUTCOME_RECORD_FLAG):
		var record := JsonCoerceScript._copy_dict(run_state.narrative_flags[SPECIAL_OUTCOME_RECORD_FLAG])
		return not _terminal_special_record_valid(record) or not bool(run_state.narrative_flags.get(SPECIAL_OUTCOME_PROCESSED_FLAG, false)) or not bool(run_state.narrative_flags.get(SPECIAL_OUTCOME_ACK_FLAG, false))
	# Old processed outcomes have no verifiable receipt. Reapplying would also
	# repeat correctly saved rewards or durability loss, so preserve that state.
	return not bool(run_state.narrative_flags.get(SPECIAL_OUTCOME_PROCESSED_FLAG, false))


func _terminal_special_record_valid(record: Dictionary) -> bool:
	if int(record.get("schema_version", 0)) != 1 or typeof(record.get("receipt")) != TYPE_STRING or typeof(record.get("intent_json")) != TYPE_STRING:
		return false
	var receipt := str(record["receipt"])
	var suffix := receipt.trim_prefix("terminal-outcome:")
	if not receipt.begins_with("terminal-outcome:") or not suffix.is_valid_int() or int(suffix) < 1 or str(int(suffix)) != suffix:
		return false
	var plan: Variant = JSON.parse_string(str(record["intent_json"]))
	return typeof(plan) == TYPE_DICTIONARY and int(plan.get("schema_version", 0)) == 1


func prepare_terminal_special_outcome(run_state: RunState, meta_collection_service: Variant) -> Dictionary:
	if not terminal_special_outcome_eligible(run_state) or meta_collection_service == null:
		return {"ok": false, "message": "No terminal collection outcome is available."}
	if run_state.narrative_flags.has(SPECIAL_OUTCOME_RECORD_FLAG):
		var record := JsonCoerceScript._copy_dict(run_state.narrative_flags[SPECIAL_OUTCOME_RECORD_FLAG])
		if not _terminal_special_record_valid(record):
			return {"ok": false, "message": "The pending collection outcome could not be verified."}
		return {"ok": true, "record": record}
	if bool(run_state.narrative_flags.get(SPECIAL_OUTCOME_PROCESSED_FLAG, false)):
		return {"ok": true, "legacy_processed": true}
	var record := {
		"schema_version": 1,
		"receipt": meta_collection_service.allocate_terminal_special_receipt(),
		"intent_json": JSON.stringify(_terminal_special_plan(run_state)),
	}
	run_state.narrative_flags[SPECIAL_OUTCOME_RECORD_FLAG] = record
	run_state.narrative_flags[SPECIAL_OUTCOME_ACK_FLAG] = false
	return {"ok": true, "record": record}


func commit_terminal_special_outcome(run_state: RunState, meta_collection_service: Variant) -> Dictionary:
	var prepared := prepare_terminal_special_outcome(run_state, meta_collection_service)
	if not bool(prepared.get("ok", false)) or bool(prepared.get("legacy_processed", false)):
		return prepared
	var record := JsonCoerceScript._copy_dict(prepared.get("record", {}))
	var result: Dictionary = meta_collection_service.commit_terminal_special_outcome(str(record.get("receipt", "")), str(record.get("intent_json", "")))
	if bool(result.get("ok", false)) and not bool(run_state.narrative_flags.get(SPECIAL_OUTCOME_PROCESSED_FLAG, false)):
		_acknowledge_terminal_special_outcome(run_state, result)
	return result


func apply_terminal_special_outcome(run_state: RunState, meta_collection_service: Variant) -> Dictionary:
	if run_state == null or meta_collection_service == null or not run_state.is_terminal():
		return {"ok": false, "mutated": false}
	if not terminal_special_outcome_eligible(run_state):
		return {"ok": true, "mutated": false}
	if bool(run_state.narrative_flags.get(SPECIAL_OUTCOME_PROCESSED_FLAG, false)):
		return {
			"ok": true, "mutated": false,
			"card_reward": JsonCoerceScript._copy_dict(run_state.narrative_flags.get(PLAYERS_CARD_REWARD_FLAG, {})),
			"chips_reward": JsonCoerceScript._copy_dict(run_state.narrative_flags.get(GRAND_CASINO_CHIPS_REWARD_FLAG, {})),
			"destroyed_cards": JsonCoerceScript._copy_array(run_state.narrative_flags.get(PLAYERS_CARD_DESTROYED_FLAG, [])),
		}
	var result: Dictionary = meta_collection_service.stage_terminal_special_outcome(_terminal_special_plan(run_state))
	if bool(result.get("ok", false)):
		_acknowledge_terminal_special_outcome(run_state, result)
	return result


func _terminal_special_plan(run_state: RunState) -> Dictionary:
	var modifiers := run_state.challenge_modifiers()
	var failed := run_state.run_status == RunState.RUN_STATUS_FAILED
	var route := str(run_state.narrative_flags.get("demo_victory_route", ""))
	var card_victory := not failed and (route == RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID or (run_state.is_tutorial_run() and route == TUTORIAL_BRONZE_ROUTE))
	var plan := {
		"schema_version": 1, "failed": failed,
		"skip_failure_decay": bool(run_state.narrative_flags.get(MetaCollectionServiceScript.FAILURE_DECAY_FLAG, false)),
		"carried_ids": JsonCoerceScript._copy_array(modifiers.get("meta_collection_carried_instance_ids", [])),
		"failure_seed": "%s|failure" % run_state.seed_text if failed else "",
		"card_stamp": _players_card_stamp(run_state) if card_victory else {},
		"chip_amount": maxi(0, int(run_state.narrative_flags.get("grand_casino_uncashed_chip_amount", 0))) if not failed and _shown_door_has_uncashed_chips(run_state) else 0,
		"chip_stamp": {}, "prestige": bool(modifiers.get("grand_casino_prestige", false)), "prestige_result": {},
	}
	if int(plan["chip_amount"]) > 0:
		plan["chip_stamp"] = {
			"seed": "Hidden challenge" if run_state.seed_is_hidden() else run_state.seed_text,
			"seed_hidden": run_state.seed_is_hidden(), "route": RunState.GRAND_CASINO_SHOWDOWN_ROUTE,
			"ending": GrandCasinoDuelModelScript.OUTCOME_SHOWN_THE_DOOR, "chip_amount": plan["chip_amount"],
		}
	if not failed and bool(plan["prestige"]):
		plan["prestige_result"] = {
			"active": true, "status": "retained",
			"card_count": JsonCoerceScript._copy_array(modifiers.get("grand_casino_prestige_card_instance_ids", [])).size(),
			"drop_tier_bonus_steps": maxi(0, int(modifiers.get("meta_collection_drop_tier_bonus_steps", 0))),
		}
	return plan


func _acknowledge_terminal_special_outcome(run_state: RunState, result: Dictionary) -> void:
	var destroyed_cards := JsonCoerceScript._copy_array(result.get("destroyed_cards", []))
	if not destroyed_cards.is_empty():
		run_state.narrative_flags[PLAYERS_CARD_DESTROYED_FLAG] = destroyed_cards
		run_state.log_story({"type": "meta_players_card_destroyed", "count": destroyed_cards.size(), "message": "The Grand Casino Players Card carried into this run is gone forever."})
	var reward := JsonCoerceScript._copy_dict(result.get("card_reward", {}))
	if not reward.is_empty():
		run_state.narrative_flags[PLAYERS_CARD_REWARD_FLAG] = reward
		var stamp := JsonCoerceScript._copy_dict(reward.get("instance_data", {}))
		run_state.log_story({"type": "meta_players_card_minted", "instance_id": int(reward.get("instance_id", 0)), "route": RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID, "message": "Linda's %s Players Card was added to the collection." % str(stamp.get("tier_reached", "Gold")).capitalize()})
	var chips := JsonCoerceScript._copy_dict(result.get("chips_reward", {}))
	if not chips.is_empty():
		run_state.narrative_flags[GRAND_CASINO_CHIPS_REWARD_FLAG] = chips
		run_state.log_story({"type": "meta_grand_casino_chips_granted", "instance_id": int(chips.get("instance_id", 0)), "chip_amount": int(chips.get("stack_amount", 0)), "message": "%d uncashed Grand Casino chips were stored for Sal's Pawn Shop." % int(chips.get("stack_amount", 0))})
	var prestige_result := JsonCoerceScript._copy_dict(result.get("prestige_result", {}))
	if not prestige_result.is_empty():
		run_state.narrative_flags[PRESTIGE_RESULT_FLAG] = prestige_result
	if run_state.run_status == RunState.RUN_STATUS_FAILED and not bool(run_state.narrative_flags.get(MetaCollectionServiceScript.FAILURE_DECAY_FLAG, false)):
		run_state.narrative_flags[MetaCollectionServiceScript.FAILURE_DECAY_FLAG] = true
		run_state.clear_pending_bag_markers()
	run_state.narrative_flags[SPECIAL_OUTCOME_PROCESSED_FLAG] = true


func _shown_door_has_uncashed_chips(run_state: RunState) -> bool:
	return bool(run_state.narrative_flags.get("grand_casino_walked_with_chips", false)) \
		and str(run_state.narrative_flags.get("grand_casino_duel_outcome", "")) == GrandCasinoDuelModelScript.OUTCOME_SHOWN_THE_DOOR \
		and str(run_state.narrative_flags.get("demo_victory_route", "")) == RunState.GRAND_CASINO_SHOWDOWN_ROUTE \
		and maxi(0, int(run_state.narrative_flags.get("grand_casino_uncashed_chip_amount", 0))) > 0


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
		var marker := JsonCoerceScript._copy_dict(marker_value)
		if not marker.is_empty():
			run_state.add_pending_bag_marker(marker)
	run_state.narrative_flags[EVALUATED_FLAG] = true
	return run_state.pending_bag_markers()


func flush_pending_bags(run_state: RunState, meta_collection_service: Variant) -> Dictionary:
	if run_state == null or meta_collection_service == null:
		return {"ok": false, "granted": [], "summary_lines": []}
	if not run_state.meta_collection_enabled_for_run():
		return {"ok": true, "granted": [], "summary_lines": []}
	if run_state.run_status != RunState.RUN_STATUS_ENDED:
		run_state.clear_pending_bag_markers()
		run_state.narrative_flags[GRANTS_FLAG] = []
		run_state.narrative_flags[FLUSHED_FLAG] = true
		return {"ok": true, "granted": [], "summary_lines": []}
	var existing_lines := JsonCoerceScript._copy_array(run_state.narrative_flags.get(GRANTS_FLAG, []))
	if bool(run_state.narrative_flags.get(FLUSHED_FLAG, false)):
		return {"ok": true, "granted": [], "summary_lines": existing_lines}
	var markers := run_state.pending_bag_markers()
	var granted: Array = []
	for marker_value in markers:
		var marker := _enriched_marker(JsonCoerceScript._copy_dict(marker_value))
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


func flush_selected_pending_bag(run_state: RunState, meta_collection_service: Variant, marker_id: String) -> Dictionary:
	if run_state == null or meta_collection_service == null:
		return {"ok": false, "granted": [], "summary_lines": [], "message": "Collection storage is unavailable."}
	if not run_state.meta_collection_enabled_for_run():
		return {"ok": true, "granted": [], "summary_lines": [], "message": "Meta collection is disabled for this run."}
	if run_state.run_status != RunState.RUN_STATUS_ENDED:
		run_state.clear_pending_bag_markers()
		run_state.narrative_flags[GRANTS_FLAG] = []
		run_state.narrative_flags[FLUSHED_FLAG] = true
		return {"ok": true, "granted": [], "summary_lines": [], "message": "Collection bag rewards are only extracted after a victory."}
	var existing_lines := JsonCoerceScript._copy_array(run_state.narrative_flags.get(GRANTS_FLAG, []))
	if bool(run_state.narrative_flags.get(FLUSHED_FLAG, false)):
		return {"ok": true, "granted": [], "summary_lines": existing_lines, "message": "A bag was already brought home."}
	var recovery := reconcile_terminal_bag_claim(run_state, meta_collection_service)
	if not bool(recovery.get("ok", false)) or bool(recovery.get("resolved", false)):
		return recovery
	var selected_id := marker_id.strip_edges()
	if selected_id.is_empty():
		return {"ok": false, "granted": [], "summary_lines": [], "message": "Choose a bag to bring home."}
	var selected_marker := {}
	for marker_value in run_state.pending_bag_markers():
		var marker := _enriched_marker(JsonCoerceScript._copy_dict(marker_value))
		if str(marker.get("marker_id", "")) == selected_id:
			selected_marker = marker
			break
	if selected_marker.is_empty():
		return {"ok": false, "granted": [], "summary_lines": [], "message": "That bag is no longer available."}
	var bagdef_id := int(selected_marker.get("bagdef_id", -1))
	if bagdef_id < 0:
		return {"ok": false, "granted": [], "summary_lines": [], "message": "That bag cannot be extracted."}
	var committed: Dictionary = meta_collection_service.commit_terminal_bag_claim(str(run_state.narrative_flags.get(SAL_STOCK_RECEIPT_FLAG, "")), selected_marker)
	if not bool(committed.get("ok", false)):
		return committed
	return _apply_terminal_bag_claim(run_state, JsonCoerceScript._copy_dict(committed.get("bag", {})))


# Called once at Continue, or by an explicit retry. It never chooses/grants a
# new reward: only a durable per-run receipt or a proven legacy grant qualifies.
func reconcile_terminal_bag_claim(run_state: RunState, meta_collection_service: Variant) -> Dictionary:
	if run_state == null or meta_collection_service == null or run_state.run_status != RunState.RUN_STATUS_ENDED \
			or not run_state.meta_collection_enabled_for_run() or bool(run_state.narrative_flags.get(FLUSHED_FLAG, false)):
		return {"ok": true, "resolved": false}
	var receipt := str(run_state.narrative_flags.get(SAL_STOCK_RECEIPT_FLAG, "")).strip_edges()
	if receipt.is_empty():
		return {"ok": false, "message": "The completed run's reward receipt is unavailable."}
	var markers: Array = []
	for value in run_state.pending_bag_markers():
		markers.append(_enriched_marker(JsonCoerceScript._copy_dict(value)))
	var bag: Dictionary = meta_collection_service.terminal_bag_claim(receipt)
	if bag.is_empty():
		var legacy: Dictionary = meta_collection_service.legacy_terminal_bag_claim(receipt, markers)
		if not bool(legacy.get("ok", false)):
			return legacy
		bag = JsonCoerceScript._copy_dict(legacy.get("bag", {}))
		if bag.is_empty():
			return {"ok": true, "resolved": false}
		var committed: Dictionary = meta_collection_service.commit_terminal_bag_claim(receipt, bag, bag)
		if not bool(committed.get("ok", false)):
			return committed
	var selected_id := str(bag.get("marker_id", ""))
	var matches := false
	for value in markers:
		if str(value.get("marker_id", "")) == selected_id:
			matches = true
	if not matches or int(bag.get("instance_id", 0)) <= 0:
		return {"ok": false, "message": "The stored reward does not match this completed run. No additional bag was granted."}
	return _apply_terminal_bag_claim(run_state, bag)


func _apply_terminal_bag_claim(run_state: RunState, bag: Dictionary) -> Dictionary:
	var summary_lines := summary_lines_for_markers([bag])
	run_state.narrative_flags[GRANTS_FLAG] = summary_lines
	run_state.narrative_flags[SELECTED_FLAG] = str(bag.get("marker_id", ""))
	run_state.narrative_flags[FLUSHED_FLAG] = true
	run_state.clear_pending_bag_markers()
	return {
		"ok": true,
		"resolved": true,
		"granted": [bag],
		"summary_lines": summary_lines,
		"message": "Collection bag stored.",
	}


func summary_lines_for_markers(markers: Array) -> Array:
	var lines: Array = []
	for marker_value in markers:
		var marker := _enriched_marker(JsonCoerceScript._copy_dict(marker_value))
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
	var collections: Array = _collection_item_resolver.collections()
	if collections.is_empty():
		return {}
	var collection_index := rng.randi_range(0, collections.size() - 1)
	var collection := JsonCoerceScript._copy_dict(collections[collection_index])
	var rolled_tier := _roll_tier(collection, rng)
	var tier_bonus_steps := maxi(0, int(run_state.challenge_modifiers().get("meta_collection_drop_tier_bonus_steps", 0)))
	var tier := _promote_tier(rolled_tier, tier_bonus_steps)
	var collection_id := str(collection.get("id", ""))
	var bag_defs: Array = _collection_item_resolver.bag_item_definitions(collection_id, tier)
	if bag_defs.is_empty():
		return {}
	var bag_index := rng.randi_range(0, bag_defs.size() - 1)
	var bag := JsonCoerceScript._copy_dict(bag_defs[bag_index])
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
		"rolled_tier": rolled_tier,
		"tier_bonus_steps": tier_bonus_steps,
		"source": source,
		"source_id": source_id,
		"rng_seed": seed_text,
	})


func _roll_tier(collection: Dictionary, rng: RngStream) -> String:
	var drop_table := JsonCoerceScript._copy_dict(collection.get("drop_table", {}))
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
		var entry := JsonCoerceScript._copy_dict(entry_value)
		running += int(entry.get("weight", 0))
		if roll <= running:
			return str(entry.get("tier", "blue"))
	return "blue"


func _promote_tier(tier: String, bonus_steps: int) -> String:
	var index := CollectionItemResolverScript.TIERS.find(tier)
	if index < 0:
		index = 0
	return str(CollectionItemResolverScript.TIERS[mini(CollectionItemResolverScript.TIERS.size() - 1, index + maxi(0, bonus_steps))])


func _players_card_stamp(run_state: RunState) -> Dictionary:
	var timeline: Array = []
	for entry_value in run_state.story_log:
		var entry := JsonCoerceScript._copy_dict(entry_value)
		if str(entry.get("type", "")) != "grand_casino_players_card_tier":
			continue
		timeline.append({
			"tier": str(entry.get("tier", "")),
			"games_played": maxi(0, int(entry.get("games_played", 0))),
			"net_winnings": int(entry.get("net_winnings", 0)),
		})
	var seed_hidden := run_state.seed_is_hidden()
	var stamp := {
		"seed": "Hidden challenge" if seed_hidden else run_state.seed_text,
		"seed_hidden": seed_hidden,
		"final_score": int(run_state.terminal_score_summary().get("score", 0)),
		"days_survived": run_state.game_day(),
		"tier_reached": str(run_state.narrative_flags.get("grand_casino_players_card_highest_tier", run_state.narrative_flags.get("grand_casino_players_card_tier", RunState.GRAND_CASINO_PLAYERS_CARD_TIER_GOLD))),
		"tier_timeline": timeline,
		"route": RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID,
	}
	if run_state.is_tutorial_run():
		stamp["starter_card"] = true
		stamp["tutorial"] = true
		stamp["tutorial_challenge_id"] = str(run_state.challenge_config.get("id", "tutorial_first_card"))
	return stamp


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
	var bag: Dictionary = _collection_item_resolver.bag_definition(int(marker.get("bagdef_id", -1)))
	if bag.is_empty():
		return marker
	var collection: Dictionary = _collection_item_resolver.collection_definition(str(bag.get("collection_id", marker.get("collection_id", ""))))
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
