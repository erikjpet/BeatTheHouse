class_name CrewPokerModel
extends RefCounted

# Pure rules/content model for the Crew's honest five-card draw table. Runtime
# presentation never receives the hidden observation counters.

const POKER_PATH := "res://data/crew/poker.json"
const PATTERNS_PATH := "res://data/crew/tells.json"
const SCHEMA_VERSION := 1
const CATEGORY_LABELS := [
	"High Card", "One Pair", "Two Pair", "Three of a Kind", "Straight",
	"Flush", "Full House", "Four of a Kind", "Straight Flush",
]

static var _config_cache: Dictionary = {}
static var _pattern_cache: Dictionary = {}


static func config() -> Dictionary:
	if _config_cache.is_empty():
		var rows := _load_array(POKER_PATH)
		if not rows.is_empty() and typeof(rows[0]) == TYPE_DICTIONARY:
			_config_cache = (rows[0] as Dictionary).duplicate(true)
	return _config_cache.duplicate(true)


static func policy(member_id: String) -> Dictionary:
	var policies: Dictionary = config().get("policies", {}) if typeof(config().get("policies", {})) == TYPE_DICTIONARY else {}
	var value: Variant = policies.get(member_id, {})
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func patterns(member_id: String) -> Array:
	_ensure_patterns()
	var value: Variant = _pattern_cache.get(member_id, [])
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func pattern(member_id: String, state_key: String) -> Dictionary:
	for value in patterns(member_id):
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("state_key", "")) == state_key:
			return (value as Dictionary).duplicate(true)
	return {}


static func default_observations() -> Dictionary:
	var result := {}
	_ensure_patterns()
	for member_id in _pattern_cache.keys():
		var counters := {}
		for value in patterns(str(member_id)):
			if typeof(value) == TYPE_DICTIONARY:
				counters[str((value as Dictionary).get("state_key", ""))] = 0
		result[str(member_id)] = counters
	return result


static func normalize_observations(value: Variant) -> Dictionary:
	var source: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var result := default_observations()
	for member_id in result.keys():
		var source_member: Dictionary = source.get(member_id, {}) if typeof(source.get(member_id, {})) == TYPE_DICTIONARY else {}
		var counters: Dictionary = result[member_id]
		for state_key in counters.keys():
			counters[state_key] = maxi(0, int(source_member.get(state_key, 0)))
		result[member_id] = counters
	return result


# Save projection packs both neutral counters into one masked integer per member;
# raw saves contain neither authored ids nor a readable progress counter.
static func pack_observations(value: Dictionary) -> Dictionary:
	var source := normalize_observations(value)
	var result := {}
	var member_index := 0
	for member_id in source.keys():
		var packed := 0
		var shift := 0
		var counters: Dictionary = source.get(member_id, {})
		for authored_value in patterns(str(member_id)):
			var state_key := str((authored_value as Dictionary).get("state_key", ""))
			packed = packed | (clampi(int(counters.get(state_key, 0)), 0, 255) << shift)
			shift += 8
		result[member_id] = packed ^ (0x5A31 + member_index * 0x113)
		member_index += 1
	return result


static func unpack_observations(value: Variant) -> Dictionary:
	var source: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var result := default_observations()
	var member_index := 0
	for member_id in result.keys():
		if not source.has(member_id):
			member_index += 1
			continue
		var packed := int(source.get(member_id, 0)) ^ (0x5A31 + member_index * 0x113)
		var counters: Dictionary = result.get(member_id, {})
		var shift := 0
		for authored_value in patterns(str(member_id)):
			var state_key := str((authored_value as Dictionary).get("state_key", ""))
			counters[state_key] = maxi(0, (packed >> shift) & 0xFF)
			shift += 8
		result[member_id] = counters
		member_index += 1
	return result


static func learned(observations: Dictionary, member_id: String) -> bool:
	var threshold := maxi(1, int(config().get("learned_exposures", 3)))
	var counters: Dictionary = observations.get(member_id, {}) if typeof(observations.get(member_id, {})) == TYPE_DICTIONARY else {}
	for value in patterns(member_id):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		if int(counters.get(str((value as Dictionary).get("state_key", "")), 0)) >= threshold:
			return true
	return false


static func record_verified(observations: Dictionary, member_id: String, state_key: String) -> Dictionary:
	var result := normalize_observations(observations)
	if pattern(member_id, state_key).is_empty():
		return result
	var counters: Dictionary = result.get(member_id, {})
	counters[state_key] = int(counters.get(state_key, 0)) + 1
	result[member_id] = counters
	return result


static func evaluate_hand(cards_value: Variant) -> Dictionary:
	var cards := _card_array(cards_value)
	if cards.size() != 5:
		return {"category": -1, "label": "Invalid", "signature": [-1]}
	var ranks: Array = []
	var suits: Array = []
	var counts := {}
	for card_value in cards:
		var card: Dictionary = card_value
		var rank := int(card.get("rank", 0))
		ranks.append(rank)
		suits.append(int(card.get("suit", -1)))
		counts[rank] = int(counts.get(rank, 0)) + 1
	ranks.sort()
	ranks.reverse()
	var unique: Array = counts.keys()
	unique.sort()
	unique.reverse()
	var straight_high := 0
	if unique.size() == 5:
		straight_high = int(unique[0]) if int(unique[0]) - int(unique[4]) == 4 else 5 if unique == [14, 5, 4, 3, 2] else 0
	var flush := true
	for suit in suits:
		if int(suit) != int(suits[0]):
			flush = false
			break
	var groups: Array = []
	for rank_value in counts.keys():
		groups.append({"rank": int(rank_value), "count": int(counts.get(rank_value, 0))})
	groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("count", 0)) > int(b.get("count", 0)) or (int(a.get("count", 0)) == int(b.get("count", 0)) and int(a.get("rank", 0)) > int(b.get("rank", 0)))
	)
	var category := 0
	var kickers: Array = []
	if straight_high > 0 and flush:
		category = 8
		kickers = [straight_high]
	elif int((groups[0] as Dictionary).get("count", 0)) == 4:
		category = 7
		kickers = [int((groups[0] as Dictionary).get("rank", 0)), int((groups[1] as Dictionary).get("rank", 0))]
	elif int((groups[0] as Dictionary).get("count", 0)) == 3 and int((groups[1] as Dictionary).get("count", 0)) == 2:
		category = 6
		kickers = [int((groups[0] as Dictionary).get("rank", 0)), int((groups[1] as Dictionary).get("rank", 0))]
	elif flush:
		category = 5
		kickers = ranks.duplicate()
	elif straight_high > 0:
		category = 4
		kickers = [straight_high]
	elif int((groups[0] as Dictionary).get("count", 0)) == 3:
		category = 3
		kickers = _group_ranks(groups)
	elif int((groups[0] as Dictionary).get("count", 0)) == 2 and int((groups[1] as Dictionary).get("count", 0)) == 2:
		category = 2
		kickers = _group_ranks(groups)
	elif int((groups[0] as Dictionary).get("count", 0)) == 2:
		category = 1
		kickers = _group_ranks(groups)
	else:
		kickers = ranks.duplicate()
	var signature: Array = [category]
	signature.append_array(kickers)
	return {"category": category, "label": CATEGORY_LABELS[category], "signature": signature, "high": int(kickers[0]) if not kickers.is_empty() else 0}


static func compare_hands(a: Variant, b: Variant) -> int:
	var left: Array = evaluate_hand(a).get("signature", [-1])
	var right: Array = evaluate_hand(b).get("signature", [-1])
	for index in range(maxi(left.size(), right.size())):
		var av := int(left[index]) if index < left.size() else 0
		var bv := int(right[index]) if index < right.size() else 0
		if av != bv:
			return 1 if av > bv else -1
	return 0


static func split_pot(pot: int, winner_ids: Array) -> Dictionary:
	var result := {}
	if pot <= 0 or winner_ids.is_empty():
		return result
	var share := floori(float(pot) / float(winner_ids.size()))
	var remainder := pot % winner_ids.size()
	for index in range(winner_ids.size()):
		result[str(winner_ids[index])] = share + (1 if index < remainder else 0)
	return result


static func draw_indices(cards_value: Variant, policy_value: Dictionary = {}) -> Array:
	var cards := _card_array(cards_value)
	var score := evaluate_hand(cards)
	var category := int(score.get("category", -1))
	if category >= 4:
		return []
	var counts := {}
	for card_value in cards:
		var rank := int((card_value as Dictionary).get("rank", 0))
		counts[rank] = int(counts.get(rank, 0)) + 1
	var held_ranks: Array = []
	for rank_value in counts.keys():
		if int(counts.get(rank_value, 0)) >= 2:
			held_ranks.append(int(rank_value))
	var result: Array = []
	for index in range(cards.size()):
		var rank := int((cards[index] as Dictionary).get("rank", 0))
		if not held_ranks.has(rank):
			result.append(index)
	if held_ranks.is_empty():
		# Cautious personalities retain high cards; loose ones take the full redraw.
		var caution := int(policy_value.get("draw_caution", 50))
		var best_index := -1
		var best_rank := 0
		for index in range(cards.size()):
			var rank := int((cards[index] as Dictionary).get("rank", 0))
			if rank > best_rank:
				best_rank = rank
				best_index = index
		if caution >= 45 and best_rank >= 11:
			result.erase(best_index)
	return result


static func npc_action(member_id: String, cards: Array, phase: String, facing_raise: bool, rng: RngStream) -> String:
	var profile := policy(member_id)
	var score := evaluate_hand(cards)
	var category := int(score.get("category", 0))
	var strength := category * 12 + clampi(int(score.get("high", 0)) - 8, 0, 6)
	var tightness := int(profile.get("tightness", 50))
	var aggression := int(profile.get("aggression", 50))
	var bluff := int(profile.get("bluff", 20))
	var roll: int = rng.randi_range(1, 100)
	if facing_raise and category == 0 and roll <= clampi(tightness - 25, 8, 72):
		return "fold"
	var raise_chance := clampi(int(float(aggression) / 3.0) + strength + (int(float(bluff) / 2.0) if category == 0 else 0) - (10 if phase == "before" else 0), 4, 88)
	if roll <= raise_chance:
		return "raise"
	if facing_raise and roll >= clampi(118 - tightness + strength, 30, 94):
		return "fold"
	return "call"


static func condition_matches(condition: String, cards: Array, action: String, draw_count: int) -> bool:
	var category := int(evaluate_hand(cards).get("category", 0))
	match condition:
		"strong":
			return category >= 2 and action != "draw"
		"weak_aggression":
			return category == 0 and action == "raise"
		"one_pair":
			return category == 1 and action == "draw"
		"made_straight":
			return category >= 4 and action == "draw"
	return false


static func surface_pattern(member_id: String, cards: Array, action: String, draw_count: int, rng: RngStream) -> Dictionary:
	for authored_value in patterns(member_id):
		var authored: Dictionary = authored_value
		if not condition_matches(str(authored.get("condition", "")), cards, action, draw_count):
			continue
		if rng.randi_range(1, 100) <= int(authored.get("frequency_percent", 0)):
			return authored.duplicate(true)
	return {}


static func validate_content(member_ids: Array) -> Array:
	var failures: Array = []
	var source := config()
	if int(source.get("schema_version", 0)) != SCHEMA_VERSION:
		failures.append("poker.json schema_version must match CrewPokerModel.")
	for key in ["ante", "bet_unit", "raise_unit", "session_hand_cap", "session_swing_cap", "session_trust", "hustle_threshold", "hustle_sessions_required", "learned_exposures"]:
		if int(source.get(key, 0)) <= 0:
			failures.append("poker.json %s must be positive." % key)
	var seen_keys := {}
	for member_id_value in member_ids:
		var member_id := str(member_id_value)
		if policy(member_id).is_empty():
			failures.append("poker.json is missing policy profile %s." % member_id)
		var member_patterns := patterns(member_id)
		if member_patterns.size() < 1 or member_patterns.size() > 2:
			failures.append("tells.json member %s must author one or two patterns." % member_id)
		for pattern_value in member_patterns:
			var authored: Dictionary = pattern_value
			var state_key := str(authored.get("state_key", ""))
			if state_key.is_empty() or seen_keys.has(state_key):
				failures.append("tells.json pattern keys must be unique neutral ids.")
			seen_keys[state_key] = true
			if not ["strong", "weak_aggression", "one_pair", "made_straight"].has(str(authored.get("condition", ""))):
				failures.append("tells.json %s has an unsupported condition." % state_key)
			if int(authored.get("frequency_percent", 0)) <= 0 or int(authored.get("frequency_percent", 0)) > 100:
				failures.append("tells.json %s frequency must be 1..100." % state_key)
			if str(authored.get("line", "")).to_lower().contains("tell") or str(authored.get("quirk", "")).to_lower().contains("tell"):
				failures.append("tells.json %s labels the observation in presentation copy." % state_key)
	return failures


static func _ensure_patterns() -> void:
	if not _pattern_cache.is_empty():
		return
	for value in _load_array(PATTERNS_PATH):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = value
		var member_id := str(row.get("member_id", ""))
		var authored: Array = row.get("patterns", []) if typeof(row.get("patterns", [])) == TYPE_ARRAY else []
		_pattern_cache[member_id] = authored.duplicate(true)


static func _group_ranks(groups: Array) -> Array:
	var result: Array = []
	for group_value in groups:
		result.append(int((group_value as Dictionary).get("rank", 0)))
	return result


static func _card_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for card_value in value:
		if typeof(card_value) == TYPE_DICTIONARY:
			result.append((card_value as Dictionary).duplicate(true))
	return result


static func _load_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Array).duplicate(true) if typeof(parsed) == TYPE_ARRAY else []
