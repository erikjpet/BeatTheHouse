class_name CardShoe
extends RefCounted

# Shared standard-card shoe utilities for full-simulation card games.

const RANK_MIN := 2
const RANK_MAX := 14
const SUIT_COUNT := 4
const CARDS_PER_DECK := 52


static func build_deck(deck_index: int = 0) -> Array:
	var cards: Array = []
	for suit in range(SUIT_COUNT):
		for rank in range(RANK_MIN, RANK_MAX + 1):
			cards.append({"rank": rank, "suit": suit, "deck": deck_index})
	return cards


static func build_shoe(deck_count: int, rng: RngStream) -> Array:
	var cards: Array = []
	for deck_index in range(maxi(1, deck_count)):
		cards.append_array(build_deck(deck_index))
	return shuffle_cards(cards, rng)


static func shuffle_cards(cards_value: Variant, rng: RngStream) -> Array:
	var cards: Array = card_array(cards_value)
	var shuffle_rng: RngStream = rng
	if shuffle_rng == null:
		shuffle_rng = RngStream.new()
		shuffle_rng.configure(1)
	for i in range(cards.size() - 1, 0, -1):
		var j := shuffle_rng.randi_range(0, i)
		var tmp: Variant = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
	return cards


static func draw_cards(shoe_value: Variant, count: int) -> Dictionary:
	var shoe: Array = card_array(shoe_value)
	var drawn: Array = []
	var draw_count := mini(maxi(0, count), shoe.size())
	for _i in range(draw_count):
		var card: Variant = shoe.pop_front()
		if typeof(card) == TYPE_DICTIONARY:
			drawn.append((card as Dictionary).duplicate(true))
	return {
		"cards": drawn,
		"shoe": shoe,
		"remaining": shoe.size(),
	}


static func card_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for card_value in value:
		if typeof(card_value) == TYPE_DICTIONARY:
			result.append((card_value as Dictionary).duplicate(true))
	return result


static func remaining_count(shoe_value: Variant) -> int:
	return card_array(shoe_value).size()


static func cut_card_remaining(deck_count: int, penetration: float = 0.72) -> int:
	var total_cards := maxi(1, deck_count) * CARDS_PER_DECK
	var cards_before_cut := int(floor(float(total_cards) * clampf(penetration, 0.25, 0.95)))
	return clampi(total_cards - cards_before_cut, 8, total_cards)


static func remaining_composition(shoe_value: Variant) -> Dictionary:
	var cards: Array = card_array(shoe_value)
	var by_rank: Dictionary = {}
	var by_suit: Dictionary = {}
	var by_deck: Dictionary = {}
	var high_cards := 0
	var low_cards := 0
	var neutral_cards := 0
	for card_value in cards:
		var card: Dictionary = card_value
		var rank := int(card.get("rank", RANK_MIN))
		var suit := int(card.get("suit", 0))
		var deck := int(card.get("deck", 0))
		var rank_key := rank_label(rank)
		var suit_key := suit_label(suit)
		var deck_key := str(deck)
		by_rank[rank_key] = int(by_rank.get(rank_key, 0)) + 1
		by_suit[suit_key] = int(by_suit.get(suit_key, 0)) + 1
		by_deck[deck_key] = int(by_deck.get(deck_key, 0)) + 1
		if rank >= 2 and rank <= 6:
			low_cards += 1
		elif rank >= 10 or rank == RANK_MAX:
			high_cards += 1
		else:
			neutral_cards += 1
	return {
		"total": cards.size(),
		"by_rank": by_rank,
		"by_suit": by_suit,
		"by_deck": by_deck,
		"high_cards": high_cards,
		"low_cards": low_cards,
		"neutral_cards": neutral_cards,
		"hi_lo_remaining_bias": low_cards - high_cards,
	}


static func shoe_label(deck_count: int) -> String:
	var count := maxi(1, deck_count)
	return "single-deck shoe" if count == 1 else "%d-deck shoe" % count


static func count_efficiency_label(deck_count: int) -> String:
	var count := maxi(1, deck_count)
	if count <= 2:
		return "sharp"
	if count <= 4:
		return "workable"
	if count <= 6:
		return "diluted"
	return "deep"


static func rank_label(rank: int) -> String:
	match rank:
		11:
			return "J"
		12:
			return "Q"
		13:
			return "K"
		14:
			return "A"
		_:
			return str(rank)


static func suit_label(suit: int) -> String:
	match suit:
		0:
			return "spades"
		1:
			return "hearts"
		2:
			return "clubs"
		3:
			return "diamonds"
		_:
			return str(suit)
