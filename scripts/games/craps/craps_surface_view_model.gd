class_name CrapsSurfaceViewModel
extends RefCounted


static func bet_targets(table: Dictionary, rules: Dictionary) -> Array:
	var point := int(table.get("point", 0))
	var working: Dictionary = table.get("working_bets", {}) if typeof(table.get("working_bets", {})) == TYPE_DICTIONARY else {}
	var targets: Array = [
		_target("field", "FIELD", "Single roll", Rect2(78, 84, 530, 42), true),
		_target("come", "COME", "Point-on wager", Rect2(152, 140, 382, 50), point != 0),
		_target("dont_come", "DON'T COME", "Bar %d" % int(rules.get("dont_pass_bar", 0)), Rect2(152, 198, 382, 36), point != 0),
		_target("pass_line", "PASS LINE", "Even money", Rect2(78, 292, 530, 42), point == 0 and int(working.get("pass_line", 0)) <= 0),
		_target("dont_pass", "DON'T PASS", "Bar %d" % int(rules.get("dont_pass_bar", 0)), Rect2(78, 340, 530, 34), point == 0 and int(working.get("dont_pass", 0)) <= 0),
	]
	var number_x := 92.0
	for number_value in rules.get("point_numbers", []):
		var number := int(number_value)
		targets.append(_target("place_%d" % number, "PLACE %d" % number, _ratio_label(_dict(_dict(rules.get("place_payouts", {})).get(str(number), {}))), Rect2(number_x, 242, 76, 44), true))
		number_x += 86.0
	if point != 0 and int(working.get("pass_line", 0)) > 0:
		targets.append(_target("pass_odds", "PASS ODDS", "%dx max" % int(rules.get("max_odds_multiple", 0)), Rect2(618, 292, 118, 42), true))
	var come: Dictionary = working.get("come", {}) if typeof(working.get("come", {})) == TYPE_DICTIONARY else {}
	var odds_y := 84.0
	for number_key in come.keys():
		if int(come.get(number_key, 0)) <= 0:
			continue
		var number := int(number_key)
		targets.append(_target("come_odds_%d" % number, "ODDS %d" % number, _ratio_label(_dict(_dict(rules.get("odds_payouts", {})).get(str(number), {}))), Rect2(618, odds_y, 118, 34), true))
		odds_y += 40.0
	return targets


static func working_rows(table: Dictionary) -> Array:
	var working: Dictionary = table.get("working_bets", {}) if typeof(table.get("working_bets", {})) == TYPE_DICTIONARY else {}
	var rows: Array = []
	for key in ["pass_line", "dont_pass", "pass_odds"]:
		var stake := int(working.get(key, 0))
		if stake > 0:
			rows.append({"label": str(key).replace("_", " ").capitalize(), "stake": stake})
	for group_key in ["come", "dont_come", "come_odds", "place"]:
		var group: Dictionary = working.get(group_key, {}) if typeof(working.get(group_key, {})) == TYPE_DICTIONARY else {}
		for number_key in group.keys():
			var stake := int(group.get(number_key, 0))
			if stake > 0:
				rows.append({"label": "%s %s" % [str(group_key).replace("_", " ").capitalize(), str(number_key)], "stake": stake})
	return rows


static func roll_history_rows(history_value: Variant, limit: int) -> Array:
	var result: Array = []
	if typeof(history_value) != TYPE_ARRAY:
		return result
	var history: Array = history_value
	var start := maxi(0, history.size() - maxi(1, limit))
	for index in range(history.size() - 1, start - 1, -1):
		if typeof(history[index]) == TYPE_DICTIONARY:
			result.append((history[index] as Dictionary).duplicate(true))
	return result


static func _target(id: String, label: String, payout: String, rect: Rect2, enabled: bool) -> Dictionary:
	return {"id": id, "label": label, "payout": payout, "rect": rect, "enabled": enabled}


static func _ratio_label(ratio: Dictionary) -> String:
	return "%d:%d" % [int(ratio.get("numerator", 0)), maxi(1, int(ratio.get("denominator", 1)))]


static func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}
