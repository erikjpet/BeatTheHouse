class_name ItemCardViewModel
extends RefCounted

const AttributeBadgesScript := preload("res://scripts/core/attribute_badges.gd")


static func build(item: Dictionary, compact_badge_limit: int = 4) -> Dictionary:
	var badges := detail_badges(item)
	var compact_badges: Array = []
	for badge_value in badges:
		if compact_badges.size() >= maxi(0, compact_badge_limit):
			break
		compact_badges.append((badge_value as Dictionary).duplicate(true))
	var count := stack_count(item)
	var flavor := _one_line(str(item.get("description", item.get("flavor", ""))))
	var effect_text := _one_line(str(item.get("effect_summary", "")))
	var usage_text := _one_line(str(item.get("use_instructions", item.get("behavior_summary", ""))))
	var description := effect_text if not effect_text.is_empty() else flavor
	var item_class := str(item.get("item_class", item.get("class", item.get("item_type", "item")))).strip_edges()
	var affinity := AttributeBadgesScript.item_game_affinity_label(item)
	return {
		"display_name": str(item.get("display_name", item.get("id", "Item"))).strip_edges(),
		"description": description,
		"effect_text": effect_text,
		"usage_text": usage_text,
		"flavor_text": flavor,
		"class_label": item_class.replace("_", " ").capitalize(),
		"affinity_label": affinity,
		"stack_count": count,
		"stack_text": "+%d" % count,
		"badges": badges,
		"compact_badges": compact_badges,
		"tooltip": _tooltip(item, effect_text, usage_text, flavor, affinity, count, badges),
	}


static func detail_badges(item: Dictionary) -> Array:
	var source: Array = item.get("attribute_badges", []) if typeof(item.get("attribute_badges", [])) == TYPE_ARRAY else []
	if source.is_empty():
		source = AttributeBadgesScript.for_item(item)
	return AttributeBadgesScript.for_object_overlay(source)


static func stack_count(item: Dictionary) -> int:
	if bool(item.get("ticket_pile_item", false)):
		return maxi(1, int(item.get("ticket_count", item.get("count", 1))))
	return maxi(1, int(item.get("count", 1)))


static func _one_line(value: String) -> String:
	return " ".join(value.replace("\r", " ").replace("\n", " ").split(" ", false)).strip_edges()


static func _tooltip(item: Dictionary, effect_text: String, usage_text: String, flavor: String, affinity: String, count: int, badges: Array) -> String:
	var lines: Array[String] = [str(item.get("display_name", item.get("id", "Item"))).strip_edges()]
	if not effect_text.is_empty():
		lines.append("Effect: %s" % effect_text)
	if not usage_text.is_empty():
		lines.append("Use: %s" % usage_text)
	if not flavor.is_empty() and effect_text.is_empty():
		lines.append(flavor)
	lines.append("Stack +%d" % count)
	if not affinity.is_empty():
		lines.append("Affinity: %s" % affinity)
	var badge_lines: Array[String] = []
	for badge_value in badges:
		var badge: Dictionary = badge_value
		var tooltip := str(badge.get("tooltip", "")).strip_edges()
		var value_text := str(badge.get("value_text", "")).strip_edges()
		var line := tooltip
		if not value_text.is_empty() and line.find(value_text) < 0:
			line = "%s: %s" % [line, value_text] if not line.is_empty() else value_text
		if not line.is_empty() and not badge_lines.has(line):
			badge_lines.append(line)
	if not badge_lines.is_empty():
		lines.append(" · ".join(badge_lines))
	return "\n".join(lines)
