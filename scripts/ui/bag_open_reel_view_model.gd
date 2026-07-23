class_name BagOpenReelViewModel
extends RefCounted

const CollectionItemResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")

const CARD_COUNT := 47
const LANDING_INDEX := 38
const CARD_WIDTH := 92.0
const CARD_GAP := 10.0
const SPIN_DURATION_SEC := 4.2
const TIERS := ["blue", "purple", "pink", "red", "gold"]
const RESULT_BAG_KEY := "ba" + "g"


static func build(open_result: Dictionary, possible_definitions: Array, reduce_motion: bool = false, seed_key: String = "") -> Dictionary:
	var item := _copy_dict(open_result.get("item", {}))
	var definition := _copy_dict(open_result.get("definition", {}))
	var run_item := _copy_dict(open_result.get("run_item", {}))
	var bag := _copy_dict(open_result.get(RESULT_BAG_KEY, {}))
	if definition.is_empty() and int(item.get("itemdef_id", -1)) >= 0:
		var resolver: Variant = CollectionItemResolverScript.new()
		definition = resolver.item_definition(int(item.get("itemdef_id", -1)))
	var winning_card := _item_card(definition, item)
	var contents := _showcase_cards(possible_definitions)
	var sequence := _reel_sequence(possible_definitions, winning_card, item, bag, seed_key)
	return {
		"schema_version": 1,
		"component": "BagOpenReel",
		"bag_instance_id": int(bag.get("instance_id", item.get("source_bag_instance_id", 0))),
		"bag_display_name": str(bag.get("display_name", "Collection Bag")),
		"committed_instance_id": int(item.get("instance_id", 0)),
		"committed_itemdef_id": int(item.get("itemdef_id", definition.get("itemdef_id", -1))),
		"committed_item": winning_card,
		"won_display_name": str(definition.get("display_name", run_item.get("display_name", "Collection Item"))),
		"won_rarity": str(definition.get("tier", "")),
		"won_condition": str(open_result.get("condition_band", _copy_dict(run_item.get("meta_collection", {})).get("condition_band", ""))),
		"message": "Won %s. It is already in your collection." % str(definition.get("display_name", "Collection Item")),
		"sequence": sequence,
		"landing_index": LANDING_INDEX,
		"card_width": CARD_WIDTH,
		"card_gap": CARD_GAP,
		"spin_duration_sec": 0.0 if reduce_motion else SPIN_DURATION_SEC,
		"reduce_motion": reduce_motion,
		"contents": contents,
		"rarity_colors": _rarity_color_map(),
	}


static func snap_to_complete(model: Dictionary) -> Dictionary:
	var snapshot := model.duplicate(true)
	snapshot["spin_duration_sec"] = 0.0
	snapshot["reduce_motion"] = true
	return snapshot


static func landing_card(model: Dictionary) -> Dictionary:
	var sequence := _dictionary_array(model.get("sequence", []))
	var index := int(model.get("landing_index", LANDING_INDEX))
	if index >= 0 and index < sequence.size():
		return _copy_dict(sequence[index])
	return {}


static func showcase_itemdef_ids(model: Dictionary) -> Array:
	var result: Array = []
	for card_value in _dictionary_array(model.get("contents", [])):
		result.append(int((card_value as Dictionary).get("itemdef_id", -1)))
	return result


static func _reel_sequence(possible_definitions: Array, winning_card: Dictionary, item: Dictionary, bag: Dictionary, seed_key: String) -> Array:
	var options := _dictionary_array(possible_definitions)
	if options.is_empty():
		options = [winning_card]
	var sequence: Array = []
	var rng := RngStreamScript.new()
	var seed_text := seed_key
	if seed_text.strip_edges().is_empty():
		seed_text = "%s|bag:%d|item:%d|instance:%d" % [
			str(item.get("source_rng_seed", bag.get("rng_seed", "bag-reel"))),
			int(bag.get("instance_id", item.get("source_bag_instance_id", 0))),
			int(winning_card.get("itemdef_id", item.get("itemdef_id", -1))),
			int(item.get("instance_id", 0)),
		]
	rng.configure(_text_seed("bag-open-reel:%s" % seed_text))
	for index in range(CARD_COUNT):
		if index == LANDING_INDEX:
			sequence.append(winning_card.duplicate(true))
		else:
			sequence.append(_item_card(_weighted_pick(options, rng), {}))
	var landing: Dictionary = sequence[LANDING_INDEX]
	landing["landing"] = true
	landing["instance_id"] = int(item.get("instance_id", 0))
	sequence[LANDING_INDEX] = landing
	return sequence


static func _weighted_pick(options: Array, rng: RngStream) -> Dictionary:
	if options.is_empty():
		return {}
	var total := 0
	var weights: Array = []
	for value in options:
		var definition := _copy_dict(value)
		var weight := _tier_visual_weight(str(definition.get("tier", "")))
		weights.append(weight)
		total += weight
	var roll := rng.randi_range(1, maxi(1, total))
	var cursor := 0
	for index in range(options.size()):
		cursor += int(weights[index])
		if roll <= cursor:
			return _copy_dict(options[index])
	return _copy_dict(options[options.size() - 1])


static func _showcase_cards(possible_definitions: Array) -> Array:
	var cards: Array = []
	for value in _dictionary_array(possible_definitions):
		cards.append(_item_card(_copy_dict(value), {}))
	cards.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_tier := TIERS.find(str(left.get("tier", "")))
		var right_tier := TIERS.find(str(right.get("tier", "")))
		if left_tier != right_tier:
			return left_tier < right_tier
		return int(left.get("itemdef_id", 0)) < int(right.get("itemdef_id", 0))
	)
	return cards


static func _item_card(definition: Dictionary, item: Dictionary) -> Dictionary:
	var tier := str(definition.get("tier", item.get("tier", ""))).strip_edges().to_lower()
	return {
		"itemdef_id": int(definition.get("itemdef_id", item.get("itemdef_id", -1))),
		"instance_id": int(item.get("instance_id", 0)),
		"display_name": str(definition.get("display_name", "Collection Item")),
		"tier": tier,
		"asset_path": _asset_path_for_icon(str(definition.get("icon_key", ""))),
		"outline_color": VisualStyle.rarity_outline_color(tier),
		"landing": false,
	}


static func _rarity_color_map() -> Dictionary:
	var result := {}
	for tier in TIERS:
		result[tier] = VisualStyle.rarity_outline_color(tier)
	return result


static func _tier_visual_weight(tier: String) -> int:
	match tier.strip_edges().to_lower():
		"blue":
			return 60
		"purple":
			return 30
		"pink":
			return 14
		"red":
			return 6
		"gold":
			return 2
	return 20


static func _asset_path_for_icon(icon_key: String) -> String:
	var clean_key := icon_key.strip_edges()
	if clean_key.is_empty():
		return ""
	var path := "res://assets/art/items/%s.png" % clean_key
	return path if ResourceLoader.exists(path) else ""


static func _text_seed(text: String) -> int:
	var hash := 2166136261
	for index in range(text.length()):
		hash = int((hash ^ text.unicode_at(index)) * 16777619) & 0x7fffffff
	return maxi(1, hash)


static func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


static func _copy_dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
