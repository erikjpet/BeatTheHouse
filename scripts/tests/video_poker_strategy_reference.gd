extends "res://scripts/games/video_poker.gd"

# Test-only reference from dc15b7d. Preserve the pre-optimization completion

# loop and payout oracle; this file is not loaded by shipping gameplay.

func _hold_expected_pay(hand: Array, deck: Array, holds: Array, variant: Dictionary, state: Dictionary, coin_count: int, coin_value: int, is_max_bet: bool, seed_key: String) -> float:
	var draw_slots: Array = []
	for index in range(HAND_SIZE):
		if not holds.has(index):
			draw_slots.append(index)
	var draw_count := draw_slots.size()
	if draw_count == 0:
		return float(_strategy_hand_pay(hand, variant, state, coin_count, coin_value, is_max_bet))
	var total := 0.0
	var samples := 0
	if draw_count == 1:
		for first in range(deck.size()):
			total += _strategy_completion_pay(hand, draw_slots, [deck[first]], variant, state, coin_count, coin_value, is_max_bet)
			samples += 1
	elif draw_count == 2:
		for first in range(deck.size() - 1):
			for second in range(first + 1, deck.size()):
				total += _strategy_completion_pay(hand, draw_slots, [deck[first], deck[second]], variant, state, coin_count, coin_value, is_max_bet)
				samples += 1
	else:
		var sample_rng := RngStream.new()
		sample_rng.configure(JsonCoerceScript._stable_hash("%s|%s" % [seed_key, JSON.stringify(holds)]))
		for _sample in range(STRATEGY_SAMPLE_CAP):
			var pool := deck.duplicate(false)
			var cards: Array = []
			for _draw in range(draw_count):
				var pick := sample_rng.randi_range(0, pool.size() - 1)
				cards.append(pool[pick])
				pool.remove_at(pick)
			total += _strategy_completion_pay(hand, draw_slots, cards, variant, state, coin_count, coin_value, is_max_bet)
			samples += 1
	return total / float(maxi(1, samples))

func _strategy_hand_pay(hand: Array, variant: Dictionary, state: Dictionary, coin_count: int, coin_value: int, is_max_bet: bool) -> int:
	var descriptor := _reference_evaluate(hand, _wild_ranks(variant))
	var pay_row := _pay_for(descriptor, variant)
	var base_pay := _row_pay(pay_row, coin_count, is_max_bet) * coin_value
	return base_pay + int(_bonus_layer(hand, descriptor, pay_row, state, coin_count, coin_value, is_max_bet).get("bonus", 0))

func _reference_evaluate(hand: Array, wild_ranks: Array) -> Dictionary:
	if wild_ranks.is_empty():
		return _reference_evaluate_natural(hand)
	return _reference_evaluate_wild(hand, wild_ranks)

func _reference_evaluate_natural(hand: Array) -> Dictionary:
	var ranks: Array = []
	var suits: Array = []
	for card_value in hand:
		var card: Dictionary = card_value if typeof(card_value) == TYPE_DICTIONARY else {}
		ranks.append(int(card.get("rank", 0)))
		suits.append(int(card.get("suit", -1)))
	var rank_counts: Dictionary = _rank_counts(ranks)
	var max_count := _max_count(rank_counts)
	var is_flush := _suits_uniform(suits)
	var straight_high := _natural_straight_high(rank_counts)
	var is_straight := straight_high > 0

	var base := "nothing"
	var quad_rank := 0
	var kicker := 0
	var pair_high := false
	if is_straight and is_flush:
		base = "royal_flush" if straight_high == 14 and _natural_top_keys(rank_counts) == [10, 11, 12, 13, 14] else "straight_flush"
	elif max_count == 4:
		base = "four_kind"
		quad_rank = _rank_with_count(rank_counts, 4)
		kicker = _other_rank(rank_counts, quad_rank)
	elif max_count == 3 and _has_count(rank_counts, 2):
		base = "full_house"
	elif is_flush:
		base = "flush"
	elif is_straight:
		base = "straight"
	elif max_count == 3:
		base = "three_kind"
	elif _pair_count(rank_counts) == 2:
		base = "two_pair"
	elif max_count == 2:
		base = "one_pair"
		pair_high = _high_pair_rank(rank_counts) >= RANK_JACK

	return {
		"base": base,
		"quad_rank": quad_rank,
		"kicker": kicker,
		"pair_high": pair_high,
		"straight_high": straight_high,
		"suit": int(suits[0]) if is_flush and not suits.is_empty() else -1,
		"rank_counts": rank_counts,
		"scoring_indices": _natural_scoring_indices(ranks, base, rank_counts),
	}


# Analytical wild-card evaluator. Picks the highest-paying achievable category.

func _reference_evaluate_wild(hand: Array, wild_ranks: Array) -> Dictionary:
	var naturals: Array = []
	var wilds := 0
	for card_value in hand:
		var card: Dictionary = card_value if typeof(card_value) == TYPE_DICTIONARY else {}
		if wild_ranks.has(int(card.get("rank", 0))):
			wilds += 1
		else:
			naturals.append(card)
	var nat_ranks: Array = []
	var nat_suits: Array = []
	for card_value in naturals:
		var card: Dictionary = card_value
		nat_ranks.append(int(card.get("rank", 0)))
		nat_suits.append(int(card.get("suit", -1)))
	var nat_counts: Dictionary = _rank_counts(nat_ranks)
	var top := _max_count(nat_counts)
	var suits_uniform := _suits_uniform(nat_suits)

	var achievable := {}
	achievable["natural_royal"] = wilds == 0 and suits_uniform and _natural_top_keys(nat_counts) == [10, 11, 12, 13, 14]
	achievable["four_deuces"] = wilds == 4
	achievable["wild_royal"] = wilds > 0 and _can_wild_royal(nat_ranks, nat_suits, wilds)
	achievable["five_kind"] = top + wilds >= 5
	achievable["straight_flush"] = suits_uniform and _wild_straight_possible(nat_ranks, wilds)
	achievable["four_kind"] = top + wilds >= 4
	achievable["full_house"] = _wild_full_house(nat_counts, wilds)
	achievable["flush"] = suits_uniform
	achievable["straight"] = _wild_straight_possible(nat_ranks, wilds)
	achievable["three_kind"] = top + wilds >= 3
	achievable["kings_or_better"] = _wild_kings_or_better(nat_counts, nat_ranks, wilds)

	return {
		"base": "wild",
		"wild_achievable": achievable,
		"wild_count": wilds,
		"scoring_indices": [0, 1, 2, 3, 4],
	}
