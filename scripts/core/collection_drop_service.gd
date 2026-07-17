class_name CollectionDropService
extends RefCounted

# Run-boundary bridge: run code records pending markers, this service turns
# terminal run outcomes into meta collection grants.

const CollectionItemResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")

const EVALUATED_FLAG := "_meta_bag_drops_evaluated"
const FLUSHED_FLAG := "_meta_bag_grants_flushed"
const GRANTS_FLAG := "_meta_bag_grants"
const SELECTED_FLAG := "_meta_bag_selected"
const SPECIAL_OUTCOME_PROCESSED_FLAG := "_meta_special_outcome_processed"
const PLAYERS_CARD_REWARD_FLAG := "_meta_players_card_reward"
const PLAYERS_CARD_DESTROYED_FLAG := "_meta_players_card_destroyed"
const PRESTIGE_RESULT_FLAG := "_meta_prestige_result"
const HIGH_HEAT_CLEAN_ESCAPE_THRESHOLD := 65
const HIGH_HEAT_CLEAN_ESCAPE_CHANCE_PERCENT := 35


func apply_terminal_special_outcome(run_state: RunState, meta_collection_service: Variant) -> Dictionary:
	if run_state == null or meta_collection_service == null or not run_state.is_terminal():
		return {"ok": false, "mutated": false}
	if not run_state.meta_collection_enabled_for_run():
		return {"ok": true, "mutated": false}
	if bool(run_state.narrative_flags.get(SPECIAL_OUTCOME_PROCESSED_FLAG, false)):
		return {
			"ok": true,
			"mutated": false,
			"card_reward": _copy_dict(run_state.narrative_flags.get(PLAYERS_CARD_REWARD_FLAG, {})),
			"destroyed_cards": _copy_array(run_state.narrative_flags.get(PLAYERS_CARD_DESTROYED_FLAG, [])),
		}
	var result := {"ok": true, "mutated": false, "card_reward": {}, "destroyed_cards": []}
	var modifiers := run_state.challenge_modifiers()
	var prestige := bool(modifiers.get("grand_casino_prestige", false))
	if run_state.run_status == RunState.RUN_STATUS_FAILED:
		if bool(run_state.narrative_flags.get(MetaCollectionServiceScript.FAILURE_DECAY_FLAG, false)):
			run_state.narrative_flags[SPECIAL_OUTCOME_PROCESSED_FLAG] = true
			return result
		var carried_ids := _copy_array(modifiers.get("meta_collection_carried_instance_ids", []))
		var consequences: Array = meta_collection_service.apply_failure_decay(carried_ids, "%s|failure" % run_state.seed_text)
		var destroyed_cards: Array = []
		for consequence_value in consequences:
			var consequence := _copy_dict(consequence_value)
			if str(consequence.get("item_class", "")) != CollectionItemResolverScript.ITEM_CLASS_PLAYERS_CARD or not bool(consequence.get("destroyed_forever", false)):
				continue
			var stamp := _copy_dict(consequence.get("instance_data", {}))
			destroyed_cards.append({
				"instance_id": int(consequence.get("instance_id", 0)),
				"display_name": "Grand Casino Players Card",
				"earned_route": str(stamp.get("route", "")),
			})
		if not destroyed_cards.is_empty():
			run_state.narrative_flags[PLAYERS_CARD_DESTROYED_FLAG] = destroyed_cards
			run_state.log_story({
				"type": "meta_players_card_destroyed",
				"count": destroyed_cards.size(),
				"message": "The Grand Casino Players Card carried into this run is gone forever.",
			})
		result["destroyed_cards"] = destroyed_cards
		result["mutated"] = not consequences.is_empty()
		run_state.narrative_flags[MetaCollectionServiceScript.FAILURE_DECAY_FLAG] = true
		run_state.clear_pending_bag_markers()
	elif run_state.run_status == RunState.RUN_STATUS_ENDED:
		if str(run_state.narrative_flags.get("demo_victory_route", "")) == RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID:
			var stamp := _players_card_stamp(run_state)
			var card: Dictionary = meta_collection_service.mint_players_card(stamp)
			if not card.is_empty():
				var reward := {
					"instance_id": int(card.get("instance_id", 0)),
					"itemdef_id": int(card.get("itemdef_id", -1)),
					"item_class": str(card.get("item_class", "")),
					"display_name": "Grand Casino Players Card",
					"condition": float(card.get("condition", 0.0)),
					"instance_data": stamp,
				}
				run_state.narrative_flags[PLAYERS_CARD_REWARD_FLAG] = reward
				run_state.log_story({
					"type": "meta_players_card_minted",
					"instance_id": int(card.get("instance_id", 0)),
					"route": RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID,
					"message": "Linda's Gold Players Card was added to the collection.",
				})
				result["card_reward"] = reward
				result["mutated"] = true
		if prestige:
			var card_ids := _copy_array(modifiers.get("grand_casino_prestige_card_instance_ids", []))
			var prestige_result := {
				"active": true,
				"status": "retained",
				"card_count": card_ids.size(),
				"drop_tier_bonus_steps": maxi(0, int(modifiers.get("meta_collection_drop_tier_bonus_steps", 0))),
			}
			run_state.narrative_flags[PRESTIGE_RESULT_FLAG] = prestige_result
	result["prestige"] = prestige
	run_state.narrative_flags[SPECIAL_OUTCOME_PROCESSED_FLAG] = true
	return result


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
	if run_state.run_status != RunState.RUN_STATUS_ENDED:
		run_state.clear_pending_bag_markers()
		run_state.narrative_flags[GRANTS_FLAG] = []
		run_state.narrative_flags[FLUSHED_FLAG] = true
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
	var existing_lines := _copy_array(run_state.narrative_flags.get(GRANTS_FLAG, []))
	if bool(run_state.narrative_flags.get(FLUSHED_FLAG, false)):
		return {"ok": true, "granted": [], "summary_lines": existing_lines, "message": "A bag was already brought home."}
	var selected_id := marker_id.strip_edges()
	if selected_id.is_empty():
		return {"ok": false, "granted": [], "summary_lines": [], "message": "Choose a bag to bring home."}
	var selected_marker := {}
	for marker_value in run_state.pending_bag_markers():
		var marker := _enriched_marker(_copy_dict(marker_value))
		if str(marker.get("marker_id", "")) == selected_id:
			selected_marker = marker
			break
	if selected_marker.is_empty():
		return {"ok": false, "granted": [], "summary_lines": [], "message": "That bag is no longer available."}
	var bagdef_id := int(selected_marker.get("bagdef_id", -1))
	if bagdef_id < 0:
		return {"ok": false, "granted": [], "summary_lines": [], "message": "That bag cannot be extracted."}
	var grant: Dictionary = meta_collection_service.grant_bag(bagdef_id, str(selected_marker.get("rng_seed", "")), selected_marker)
	var granted: Array = []
	if not grant.is_empty():
		granted.append(grant)
	var summary_lines := summary_lines_for_markers(granted)
	run_state.narrative_flags[GRANTS_FLAG] = summary_lines
	run_state.narrative_flags[SELECTED_FLAG] = selected_id
	run_state.narrative_flags[FLUSHED_FLAG] = true
	run_state.clear_pending_bag_markers()
	return {
		"ok": true,
		"granted": granted,
		"summary_lines": summary_lines,
		"message": "Collection bag stored." if not granted.is_empty() else "No collection bag was stored.",
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
	tier = _promote_tier(tier, maxi(0, int(run_state.challenge_modifiers().get("meta_collection_drop_tier_bonus_steps", 0))))
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


func _promote_tier(tier: String, bonus_steps: int) -> String:
	var index := CollectionItemResolverScript.TIERS.find(tier)
	if index < 0:
		index = 0
	return str(CollectionItemResolverScript.TIERS[mini(CollectionItemResolverScript.TIERS.size() - 1, index + maxi(0, bonus_steps))])


func _players_card_stamp(run_state: RunState) -> Dictionary:
	var timeline: Array = []
	for entry_value in run_state.story_log:
		var entry := _copy_dict(entry_value)
		if str(entry.get("type", "")) != "grand_casino_players_card_tier":
			continue
		timeline.append({
			"tier": str(entry.get("tier", "")),
			"games_played": maxi(0, int(entry.get("games_played", 0))),
			"net_winnings": int(entry.get("net_winnings", 0)),
		})
	var seed_hidden := run_state.seed_is_hidden()
	return {
		"seed": "Hidden challenge" if seed_hidden else run_state.seed_text,
		"seed_hidden": seed_hidden,
		"final_score": int(run_state.terminal_score_summary().get("score", 0)),
		"days_survived": run_state.game_day(),
		"tier_reached": str(run_state.narrative_flags.get("grand_casino_players_card_highest_tier", run_state.narrative_flags.get("grand_casino_players_card_tier", RunState.GRAND_CASINO_PLAYERS_CARD_TIER_GOLD))),
		"tier_timeline": timeline,
		"route": RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID,
	}


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
