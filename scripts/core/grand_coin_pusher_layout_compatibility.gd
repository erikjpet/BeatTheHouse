extends RefCounted

# Existing rooms keep their selected machines and immutable scenario inventory.
# Resolve the authored pre-pusher map for those rooms rather than replacing a
# paid ticket machine or rewriting a saved manifest/semantic proof.
const MAIN := "grand_main_before_coin_pusher"
const HIGH_LIMIT := "grand_high_limit_before_coin_pusher"


static func profile_id(environment: Dictionary) -> String:
	var flags := _dict(environment.get("local_narrative_flags", {}))
	if bool(flags.get("practice_session", false)) or bool(flags.get("environment_test_session", false)):
		return ""
	var games: Array = []
	for field in ["game_ids", "scenario_sequence_base_game_ids"]:
		var value: Variant = environment.get(field, [])
		if typeof(value) == TYPE_ARRAY:
			for game_id in value:
				if not games.has(str(game_id)):
					games.append(str(game_id))
	if games.has("coin_pusher"):
		return ""
	var archetype_id := str(environment.get("archetype_id", ""))
	if archetype_id == "grand_casino":
		return MAIN if games.has("pull_tabs") else ""
	if archetype_id != "grand_casino_high_limit":
		return ""
	if int(flags.get("coin_pusher_drop_cost", 0)) == 5 or int(flags.get("coin_pusher_coin_value", 0)) == 5:
		return ""
	for field in ["scenario_game_modifiers", "scenario_sequence_base_game_modifiers"]:
		var modifiers := _dict(environment.get(field, {}))
		var pusher := _dict(modifiers.get("coin_pusher", {}))
		if int(pusher.get("drop_cost", 0)) == 5 or int(pusher.get("coin_value", 0)) == 5:
			return ""
	for game_id in ["blackjack", "baccarat", "roulette", "craps"]:
		if not games.has(game_id):
			return ""
	return HIGH_LIMIT


static func surface_map(current: Dictionary, profile: String) -> Dictionary:
	if profile not in [MAIN, HIGH_LIMIT]:
		return current
	var result := current.duplicate(true)
	if profile == MAIN:
		# This is the exact inverse of the 0.6.1 Main cabinet replacement.
		# Preserve authored mapping order as well as values.
		for field in ["class_overrides", "fixed_object_slot_ids", "object_family_ids"]:
			result[field] = _renamed_key(result.get(field, {}), "game:coin_pusher", "game:pull_tabs")
		for slot in result.get("fixed_slots", []):
			if str(slot.get("id", "")) == "fixed.game_machine_5":
				slot["physical_role"] = "Pull Tabs machine"
				slot["occupant_ids"] = ["game:pull_tabs"]
	else:
		# High Limit formerly had only its four tables. The new cabinet and its
		# four policy entries are the complete map delta for that room.
		for field in ["class_overrides", "fixed_object_slot_ids", "object_family_ids"]:
			var mapping: Dictionary = result.get(field, {})
			mapping.erase("game:coin_pusher")
		var categories: Dictionary = result.get("fixed_category_slot_ids", {})
		categories.erase("game_spots:4")
		var slots: Array = []
		for slot in result.get("fixed_slots", []):
			if str(slot.get("id", "")) != "fixed.game_coin_pusher":
				slots.append(slot)
		result["fixed_slots"] = slots
	return result


static func _renamed_key(source: Dictionary, from: String, to: String) -> Dictionary:
	var result: Dictionary = {}
	for key in source:
		result[to if str(key) == from else key] = source[key]
	return result


static func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}
