class_name CrewPokerModel
extends RefCounted

# Pure rules/content model for the Crew's honest Texas Hold'em table. Runtime
# presentation never receives an opponent's hole cards or hidden observation counters.

const POKER_PATH := "res://data/crew/poker.json"
const PATTERNS_PATH := "res://data/crew/tells.json"
const SCHEMA_VERSION := 2
const PROFILE_VERSION := 1
const DECISION_RNG_DRAWS := 5
const PATTERN_CACHE_MAX_ENTRIES := 64
const PROFILE_ATTRIBUTES: Array[String] = [
	"looseness", "preflop_raise", "reraise", "limp", "position_awareness",
	"aggression", "continuation_bet", "bluff", "semi_bluff", "stickiness",
	"fold_to_pressure", "draw_chasing", "trap", "check_raise", "river_bluff",
	"bet_size", "size_variance", "overbet_shove", "tilt", "momentum",
	"short_stack_gamble", "adapt_to_player", "signal_belief", "multiway_caution",
	"tell_leak", "draw_caution",
]
# Personality schema (all values are integer 0..100).
# looseness: width of the starting-hand range that voluntarily enters a pot.
# preflop_raise: preference for opening with a raise instead of a call.
# reraise: willingness to three-bet after another player has raised.
# limp: preference for calling the blind with speculative starting hands.
# position_awareness: how strongly late position widens and early position tightens.
# aggression: preference for betting or raising over checking or calling postflop.
# continuation_bet: likelihood of betting the flop after raising preflop.
# bluff: frequency of betting without made-hand or draw equity.
# semi_bluff: frequency of betting or raising a live draw.
# stickiness: willingness to call with marginal showdown value.
# fold_to_pressure: sensitivity to bets large relative to the pot or stack.
# draw_chasing: willingness to continue with draws beyond direct pot odds.
# trap: likelihood of slow-playing a very strong hand before striking later.
# check_raise: likelihood of raising after checking earlier on the same street.
# river_bluff: bluff frequency on the river, independent of earlier streets.
# bet_size: typical bet or raise increment as a share of the pot.
# size_variance: deterministic per-decision variation around the typical size.
# overbet_shove: willingness to overbet or commit the whole remaining stack.
# tilt: strength of the temporary looseness/aggression response to a large loss.
# momentum: strength of the aggression response to a current win streak.
# short_stack_gamble: willingness to widen and shove as stack depth falls.
# adapt_to_player: weight given to observed player folds, raises, and shown bluffs.
# signal_belief: weight given to player fake tells and their public credibility.
# multiway_caution: tightening applied for each additional live opponent.
# tell_leak: tell frequency and the strategic cost assigned to bluffing while leaky.
# draw_caution: legacy five-card-draw preference for retaining a high card.
const PREFLOP_STRENGTH := [
	[100, 86, 84, 82, 80, 78, 76, 74, 72, 70, 68, 66, 64],
	[82, 98, 82, 80, 78, 75, 72, 69, 66, 63, 60, 57, 54],
	[80, 77, 95, 78, 76, 73, 70, 67, 64, 61, 58, 55, 52],
	[77, 74, 72, 92, 74, 71, 68, 65, 62, 59, 56, 53, 50],
	[74, 70, 68, 66, 88, 69, 66, 63, 60, 57, 54, 51, 48],
	[70, 66, 64, 62, 60, 82, 64, 61, 58, 55, 52, 49, 46],
	[66, 62, 60, 58, 56, 54, 76, 59, 56, 53, 50, 47, 44],
	[62, 58, 56, 54, 52, 50, 48, 70, 54, 51, 48, 45, 42],
	[58, 54, 52, 50, 48, 46, 44, 42, 64, 49, 46, 43, 40],
	[54, 50, 48, 46, 44, 42, 40, 38, 36, 58, 44, 41, 38],
	[50, 46, 44, 42, 40, 38, 36, 34, 32, 30, 52, 39, 36],
	[46, 42, 40, 38, 36, 34, 32, 30, 28, 26, 24, 46, 34],
	[42, 38, 36, 34, 32, 30, 28, 26, 24, 22, 20, 18, 40],
]
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
	if _config_cache.is_empty():
		config()
	var policies: Dictionary = _config_cache.get("policies", {}) if typeof(_config_cache.get("policies", {})) == TYPE_DICTIONARY else {}
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
	# An empty projection is meaningful for saves that have not observed poker
	# yet. Do not expand it into authored neutral member keys during a round-trip.
	if value.is_empty():
		return {}
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
	# start_new() owns initialization of full neutral memory. Loads preserve an
	# explicitly empty legacy/minimal projection until gameplay records a pattern.
	if source.is_empty():
		return {}
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


static func evaluate_best_hand(cards_value: Variant) -> Dictionary:
	var cards := _card_array(cards_value)
	if cards.size() < 5 or cards.size() > 7:
		return {"category": -1, "label": "Invalid", "signature": [-1], "cards": []}
	var best := {"category": -1, "label": "Invalid", "signature": [-1], "cards": []}
	for a in range(cards.size() - 4):
		for b in range(a + 1, cards.size() - 3):
			for c in range(b + 1, cards.size() - 2):
				for d in range(c + 1, cards.size() - 1):
					for e in range(d + 1, cards.size()):
						var candidate := [cards[a], cards[b], cards[c], cards[d], cards[e]]
						var score := evaluate_hand(candidate)
						if _compare_signatures(score.get("signature", [-1]), best.get("signature", [-1])) > 0:
							best = score.duplicate(true)
							best["cards"] = candidate.duplicate(true)
	return best


static func compare_holdem(a: Variant, b: Variant) -> int:
	return _compare_signatures(evaluate_best_hand(a).get("signature", [-1]), evaluate_best_hand(b).get("signature", [-1]))


static func holdem_strength(hole_value: Variant, board_value: Variant) -> int:
	var hole := _card_array(hole_value)
	var board := _card_array(board_value)
	if hole.size() != 2:
		return 0
	if board.is_empty():
		return _preflop_strength(hole)
	return clampi(int(round(float(_postflop_hand_profile(hole, board).get("equity", 0.0)) * 100.0)), 1, 100)


static func holdem_action(member_id: String, hole: Array, board: Array, street: String, amount_to_call: int, pot: int, can_raise: bool, player_signal: Dictionary, signal_credibility: int, rng: RngStream) -> String:
	return str(holdem_decision(member_id, hole, board, {"street": street, "amount_to_call": amount_to_call, "pot": pot, "can_raise": can_raise, "player_signal": player_signal, "signal_credibility": signal_credibility}, rng).get("action", "call"))


# Exactly five RNG draws are consumed per decision, independent of the chosen path.
static func holdem_decision(member_id: String, hole_value: Variant, board_value: Variant, context: Dictionary, rng: RngStream, profile_override: Dictionary = {}) -> Dictionary:
	var profile := policy(member_id)
	profile.merge(profile_override, true)
	var hole := _card_array(hole_value)
	var board := _card_array(board_value)
	var continue_roll := rng.randi_range(1, 100)
	var attack_roll := rng.randi_range(1, 100)
	var bluff_roll := rng.randi_range(1, 100)
	var size_roll := rng.randi_range(1, 100)
	var shove_roll := rng.randi_range(1, 100)
	var street := str(context.get("street", "preflop"))
	var due := maxi(0, int(context.get("amount_to_call", 0)))
	var pot := maxi(0, int(context.get("pot", 0)))
	var can_raise := bool(context.get("can_raise", false))
	var position := clampi(int(context.get("position", 50)), 0, 100)
	var active_opponents := maxi(1, int(context.get("active_opponents", 1)))
	var raise_count := maxi(0, int(context.get("raise_count", 0)))
	var tilt_level := clampi(int(context.get("tilt_level", 0)), 0, 100)
	var win_streak := clampi(int(context.get("win_streak", 0)), 0, 5)
	var stack_bb := maxf(0.0, float(context.get("stack_big_blinds", 30.0)))
	var tilt_bonus := float(tilt_level * int(profile.get("tilt", 50))) / 100.0
	var momentum_bonus := float(win_streak * int(profile.get("momentum", 50))) / 5.0
	var short_pressure := clampf((12.0 - stack_bb) / 12.0, 0.0, 1.0)
	var short_bonus := short_pressure * float(int(profile.get("short_stack_gamble", 50)))
	var reads: Dictionary = context.get("player_reads", {}) if typeof(context.get("player_reads", {})) == TYPE_DICTIONARY else {}
	var player_fold_rate := float(reads.get("fold_rate", 0.35))
	var player_raise_rate := float(reads.get("raise_rate", 0.20))
	var shown_bluff_rate := float(reads.get("shown_bluff_rate", 0.0))
	var adaptation := float(int(profile.get("adapt_to_player", 50))) / 100.0
	var fold_equity := clampf(float(context.get("observed_fold_rate", 0.30)) * 0.55 + player_fold_rate * 0.45, 0.05, 0.85)
	var signal_shift := _signal_threshold_shift(profile, street, context)
	var multiway_shift := float(maxi(0, active_opponents - 1) * int(profile.get("multiway_caution", 50))) * 0.035
	var result := {"action": "check" if due == 0 else "call", "target": int(context.get("current_bet", 0)), "intent": "check" if due == 0 else "showdown", "equity": 0.0, "draw_outs": 0, "rng_draws": DECISION_RNG_DRAWS}
	if street == "preflop":
		var strength := _preflop_strength(hole)
		result["equity"] = float(strength) / 100.0
		var threshold := 62.5 - float(int(profile.get("looseness", 50))) * 0.48
		threshold += (50.0 - float(position)) * float(int(profile.get("position_awareness", 50))) / 400.0
		threshold += multiway_shift + signal_shift * 100.0
		threshold -= tilt_bonus * 0.11 + momentum_bonus * 0.08 + short_bonus * 0.10
		var continue_score := float(strength) + float(continue_roll - 50) * 0.16
		if due > 0 and continue_score < threshold:
			result["action"] = "fold"
			result["intent"] = "range_fold"
			return result
		var raise_attr := int(profile.get("reraise", 50)) if raise_count > 0 else int(profile.get("preflop_raise", 50))
		var raise_chance := float(raise_attr) * 0.50 + float(int(profile.get("aggression", 50))) * 0.11
		raise_chance += maxf(0.0, float(strength) - threshold) * 0.55 + tilt_bonus * 0.16 + momentum_bonus * 0.12 + short_bonus * 0.22
		raise_chance += (fold_equity - 0.35) * 40.0 * adaptation - player_raise_rate * 12.0 * adaptation
		if strength < 62:
			raise_chance -= float(int(profile.get("limp", 50))) * 0.28
		if can_raise and float(attack_roll) <= clampf(raise_chance, 1.0, 96.0):
			result["intent"] = "value" if strength >= 64 else "preflop_pressure"
			return _sized_decision(result, "raise", profile, context, size_roll, shove_roll, strength >= 78, short_pressure)
		result["action"] = "check" if due == 0 else "call"
		result["intent"] = "limp" if due > 0 else "check"
		return result
	var hand_profile := _postflop_hand_profile(hole, board)
	var equity := float(hand_profile.get("equity", 0.0))
	var draw_outs := int(hand_profile.get("draw_outs", 0))
	result["equity"] = equity
	result["draw_outs"] = draw_outs
	var pot_odds := float(due) / float(maxi(1, pot + due))
	var pot_pressure := float(due) / float(maxi(1, pot))
	var stack_pressure := float(due) / float(maxi(1, int(context.get("stack", due))))
	var required := pot_odds
	required += float(int(profile.get("fold_to_pressure", 50))) * (pot_pressure * 0.08 + stack_pressure * 0.05) / 100.0
	required -= float(int(profile.get("stickiness", 50))) * 0.0018
	required -= float(int(profile.get("draw_chasing", 50)) * draw_outs) * 0.00016
	required += multiway_shift / 100.0 + signal_shift
	required += player_raise_rate * adaptation * 0.035
	required -= shown_bluff_rate * adaptation * 0.05
	required -= tilt_bonus * 0.0007 + short_bonus * 0.0008
	if due > 0 and equity + float(continue_roll - 50) * 0.0018 < required:
		result["action"] = "fold"
		result["intent"] = "pot_odds_fold"
		return result
	var has_draw := draw_outs >= 4 and board.size() < 5
	var strong := equity >= 0.72
	var pure_bluff := equity < 0.38 and not has_draw
	var checked_before := bool(context.get("checked_this_street", false))
	var was_preflop_aggressor := bool(context.get("was_preflop_aggressor", false))
	var trap_chance := float(int(profile.get("trap", 50))) + (12.0 if checked_before else 0.0)
	if strong and float(bluff_roll) <= trap_chance and not checked_before:
		result["action"] = "check" if due == 0 else "call"
		result["intent"] = "trap"
		return result
	var bluff_attr := int(profile.get("river_bluff", 50)) if street == "river" else int(profile.get("bluff", 50))
	var tell_cost := float(int(profile.get("tell_leak", 50))) * 0.10
	var bluff_chance := float(bluff_attr) * (0.45 + fold_equity * 0.65) + (player_fold_rate - 0.35) * 45.0 * adaptation - tell_cost
	var semi_chance := float(int(profile.get("semi_bluff", 50))) * (0.55 + fold_equity * 0.45)
	var bluffing := pure_bluff and float(bluff_roll) <= clampf(bluff_chance, 0.0, 92.0)
	var semi_bluffing := has_draw and float(bluff_roll) <= clampf(semi_chance, 0.0, 96.0)
	var attack_chance := float(int(profile.get("aggression", 50))) * 0.38
	attack_chance += maxf(0.0, equity - 0.45) * 45.0 + tilt_bonus * 0.18 + momentum_bonus * 0.16 + short_bonus * 0.18
	attack_chance += (fold_equity - 0.30) * 35.0 * adaptation
	if was_preflop_aggressor and street == "flop":
		attack_chance += float(int(profile.get("continuation_bet", 50))) * 0.38
	if checked_before and due > 0:
		attack_chance += float(int(profile.get("check_raise", 50))) * 0.48
	if bluffing or semi_bluffing:
		attack_chance += 32.0
	if can_raise and float(attack_roll) <= clampf(attack_chance, 1.0, 97.0):
		result["intent"] = "semi_bluff" if semi_bluffing else "bluff" if bluffing else "value"
		return _sized_decision(result, "bet" if int(context.get("current_bet", 0)) == 0 else "raise", profile, context, size_roll, shove_roll, strong, short_pressure)
	result["action"] = "check" if due == 0 else "call"
	result["intent"] = "draw" if has_draw else "showdown"
	return result


static func _sized_decision(result: Dictionary, action: String, profile: Dictionary, context: Dictionary, size_roll: int, shove_roll: int, strong: bool, short_pressure: float) -> Dictionary:
	var current_bet := maxi(0, int(context.get("current_bet", 0)))
	var minimum := maxi(current_bet, int(context.get("minimum_raise_to", current_bet)))
	var maximum := maxi(minimum, int(context.get("maximum_raise_to", minimum)))
	var pot := maxi(1, int(context.get("pot", 1)))
	var preflop := str(context.get("street", "")) == "preflop"
	var base_fraction := (0.18 + float(int(profile.get("bet_size", 50))) * 0.0055) if preflop else (0.22 + float(int(profile.get("bet_size", 50))) * 0.0105)
	var variance := float(size_roll - 50) / 50.0 * float(int(profile.get("size_variance", 50))) * 0.006
	var desired := current_bet + maxi(1, int(round(float(pot) * maxf(0.15, base_fraction + variance))))
	var shove_chance := float(int(profile.get("overbet_shove", 50))) * (0.20 + short_pressure * 0.55 + (0.20 if strong else 0.0)) + float(int(profile.get("short_stack_gamble", 50))) * short_pressure * 0.25
	if float(shove_roll) <= clampf(shove_chance, 0.0, 95.0):
		result["action"] = "all_in"
		result["target"] = maximum
	else:
		result["action"] = action
		result["target"] = clampi(desired, minimum, maximum)
	return result


static func _signal_threshold_shift(profile: Dictionary, street: String, context: Dictionary) -> float:
	var player_signal: Dictionary = context.get("player_signal", {}) if typeof(context.get("player_signal", {})) == TYPE_DICTIONARY else {}
	if str(player_signal.get("street", "")) != street:
		return 0.0
	var credibility := clampi(int(context.get("signal_credibility", 50)), 10, 90)
	var belief := float(int(profile.get("signal_belief", 50))) / 100.0
	var weight := (0.035 + float(credibility - 50) * 0.00045) * belief
	return weight if str(player_signal.get("style", "")) == "strong" else -weight


static func _preflop_strength(hole: Array) -> int:
	if hole.size() != 2:
		return 0
	var first_index := 14 - clampi(int((hole[0] as Dictionary).get("rank", 2)), 2, 14)
	var second_index := 14 - clampi(int((hole[1] as Dictionary).get("rank", 2)), 2, 14)
	if first_index == second_index:
		return int((PREFLOP_STRENGTH[first_index] as Array)[second_index])
	var high_index := mini(first_index, second_index)
	var low_index := maxi(first_index, second_index)
	var suited := int((hole[0] as Dictionary).get("suit", -1)) == int((hole[1] as Dictionary).get("suit", -2))
	return int((PREFLOP_STRENGTH[high_index] as Array)[low_index]) if suited else int((PREFLOP_STRENGTH[low_index] as Array)[high_index])


static func _postflop_hand_profile(hole: Array, board: Array) -> Dictionary:
	var combined := hole.duplicate(true)
	combined.append_array(board)
	var category := _made_hand_category(combined)
	var equity_by_category := [0.20, 0.48, 0.72, 0.80, 0.87, 0.90, 0.95, 0.985, 0.995]
	var equity := float(equity_by_category[clampi(category, 0, equity_by_category.size() - 1)])
	var board_ranks: Array[int] = []
	for card_value in board:
		board_ranks.append(int((card_value as Dictionary).get("rank", 0)))
	if category == 1 and not board_ranks.is_empty():
		var first_rank := int((hole[0] as Dictionary).get("rank", 0))
		var second_rank := int((hole[1] as Dictionary).get("rank", 0))
		var board_high := int(board_ranks.max())
		if first_rank == second_rank and first_rank > board_high:
			equity = 0.69
		elif first_rank == board_high or second_rank == board_high:
			equity = 0.61
		elif board_ranks.has(first_rank) or board_ranks.has(second_rank):
			equity = 0.50
		else:
			equity = 0.29
	var draw_outs := 0
	if board.size() < 5:
		var suits := {}
		for card_value in combined:
			var suit := int((card_value as Dictionary).get("suit", -1))
			suits[suit] = int(suits.get(suit, 0)) + 1
		for suit_value in suits.keys():
			if int(suits.get(suit_value, 0)) == 4 and (int((hole[0] as Dictionary).get("suit", -2)) == int(suit_value) or int((hole[1] as Dictionary).get("suit", -2)) == int(suit_value)):
				draw_outs += 9
		var ranks: Array[int] = []
		for card_value in combined:
			var rank := int((card_value as Dictionary).get("rank", 0))
			if not ranks.has(rank):
				ranks.append(rank)
		if ranks.has(14):
			ranks.append(1)
		var best_window := 0
		for low in range(1, 11):
			var in_window := 0
			for rank in ranks:
				if rank >= low and rank <= low + 4:
					in_window += 1
			best_window = maxi(best_window, in_window)
		if best_window == 4 and category < 4:
			draw_outs += 8
		if category == 0 and not board_ranks.is_empty():
			var board_high := int(board_ranks.max())
			for hole_card in hole:
				if int((hole_card as Dictionary).get("rank", 0)) > board_high:
					draw_outs += 3
		var out_value := 0.034 if board.size() == 3 else 0.018
		equity += float(mini(draw_outs, 15)) * out_value
	return {"equity": clampf(equity, 0.02, 0.995), "draw_outs": draw_outs, "category": category}


static func _made_hand_category(cards: Array) -> int:
	var rank_counts := {}
	var suited_cards := {}
	for card_value in cards:
		var card: Dictionary = card_value
		var rank := int(card.get("rank", 0))
		var suit := int(card.get("suit", -1))
		rank_counts[rank] = int(rank_counts.get(rank, 0)) + 1
		var suit_cards: Array = suited_cards.get(suit, [])
		suit_cards.append(card)
		suited_cards[suit] = suit_cards
	var flush := false
	for suit_cards_value in suited_cards.values():
		var suit_cards: Array = suit_cards_value
		if suit_cards.size() >= 5:
			flush = true
			if _has_five_card_straight(suit_cards):
				return 8
	var pairs := 0
	var trips := 0
	for count_value in rank_counts.values():
		var count := int(count_value)
		if count >= 4:
			return 7
		if count >= 3:
			trips += 1
		elif count >= 2:
			pairs += 1
	if trips >= 1 and (pairs >= 1 or trips >= 2):
		return 6
	if flush:
		return 5
	if _has_five_card_straight(cards):
		return 4
	if trips >= 1:
		return 3
	if pairs >= 2:
		return 2
	return 1 if pairs == 1 else 0


static func _has_five_card_straight(cards: Array) -> bool:
	var ranks := {}
	for card_value in cards:
		var rank := int((card_value as Dictionary).get("rank", 0))
		ranks[rank] = true
		if rank == 14:
			ranks[1] = true
	for high in range(14, 4, -1):
		var complete := true
		for offset in range(5):
			if not ranks.has(high - offset):
				complete = false
				break
		if complete:
			return true
	return false


static func split_pot(pot: int, winner_ids: Array) -> Dictionary:
	var result := {}
	if pot <= 0 or winner_ids.is_empty():
		return result
	var share := floori(float(pot) / float(winner_ids.size()))
	var remainder := pot % winner_ids.size()
	# Contender order is stable table order; odd chips go to its earliest winners.
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
	var tightness := 100 - int(profile.get("looseness", 50))
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


static func condition_matches(condition: String, cards: Array, action: String, draw_count: int, intent: String = "") -> bool:
	var score := evaluate_best_hand(cards) if cards.size() >= 5 else evaluate_hand(cards)
	var category := int(score.get("category", 0))
	match condition:
		"strong":
			return (category >= 2 or intent in ["value", "trap"]) and action in ["call", "bet", "raise", "check", "all_in"]
		"weak_aggression":
			return (category == 0 or intent in ["bluff", "semi_bluff"]) and action in ["bet", "raise", "all_in"]
		"one_pair":
			return category == 1 and action in ["call", "check", "draw"]
		"made_straight":
			return category >= 4 and action in ["call", "raise", "check", "all_in", "draw"]
	return false


static func surface_pattern(member_id: String, cards: Array, action: String, draw_count: int, rng: RngStream, intent: String = "", tell_leak: int = 50) -> Dictionary:
	for authored_value in patterns(member_id):
		var authored: Dictionary = authored_value
		if not condition_matches(str(authored.get("condition", "")), cards, action, draw_count, intent):
			continue
		var scaled_frequency := clampi(int(round(float(authored.get("frequency_percent", 0)) * (0.5 + float(clampi(tell_leak, 0, 100)) / 100.0))), 1, 100)
		if rng.randi_range(1, 100) <= scaled_frequency:
			return authored.duplicate(true)
	return {}


static func validate_content(member_ids: Array) -> Array:
	var failures: Array = []
	var source := config()
	if int(source.get("schema_version", 0)) != SCHEMA_VERSION:
		failures.append("poker.json schema_version must match CrewPokerModel.")
	for key in ["ante", "bet_unit", "raise_unit", "session_hand_cap", "session_swing_cap", "session_trust", "hustle_threshold", "hustle_sessions_required", "learned_exposures", "table_talk_heads_up_pot", "table_talk_multiway_pot", "table_talk_cooldown_actions", "table_talk_max_per_hand"]:
		if int(source.get(key, 0)) <= 0:
			failures.append("poker.json %s must be positive." % key)
	var seen_keys := {}
	for member_id_value in member_ids:
		var member_id := str(member_id_value)
		var member_policy := policy(member_id)
		if member_policy.is_empty():
			failures.append("poker.json is missing policy profile %s." % member_id)
		elif int(member_policy.get("profile_version", 0)) != PROFILE_VERSION:
			failures.append("poker.json policy %s profile_version must match CrewPokerModel." % member_id)
		else:
			if str(member_policy.get("style_summary", "")).is_empty():
				failures.append("poker.json policy %s needs a style_summary." % member_id)
			for attribute in PROFILE_ATTRIBUTES:
				if not member_policy.has(attribute):
					failures.append("poker.json policy %s is missing %s." % [member_id, attribute])
				elif int(member_policy.get(attribute, -1)) < 0 or int(member_policy.get(attribute, -1)) > 100:
					failures.append("poker.json policy %s %s must be 0..100." % [member_id, attribute])
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
		if not _pattern_cache.has(member_id) and _pattern_cache.size() >= PATTERN_CACHE_MAX_ENTRIES:
			break
		_pattern_cache[member_id] = authored.duplicate(true)


static func _group_ranks(groups: Array) -> Array:
	var result: Array = []
	for group_value in groups:
		result.append(int((group_value as Dictionary).get("rank", 0)))
	return result


static func _compare_signatures(left_value: Variant, right_value: Variant) -> int:
	var left: Array = left_value if typeof(left_value) == TYPE_ARRAY else [-1]
	var right: Array = right_value if typeof(right_value) == TYPE_ARRAY else [-1]
	for index in range(maxi(left.size(), right.size())):
		var av := int(left[index]) if index < left.size() else 0
		var bv := int(right[index]) if index < right.size() else 0
		if av != bv:
			return 1 if av > bv else -1
	return 0


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
