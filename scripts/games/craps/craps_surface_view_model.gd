class_name CrapsSurfaceViewModel
extends RefCounted


static func bet_targets(table: Dictionary, rules: Dictionary) -> Array:
	var point := int(table.get("point", 0))
	var working: Dictionary = table.get("working_bets", {}) if typeof(table.get("working_bets", {})) == TYPE_DICTIONARY else {}
	var targets: Array = [
		_target("field", "FIELD", "One roll · 2 pays 2:1 · 12 pays 3:1", Rect2(108, 136, 492, 34), true, "line"),
		_target("come", "COME", "New line bet after point", Rect2(178, 176, 352, 40), point != 0, "line"),
		_target("dont_come", "DON'T COME", "Against shooter · 12 bars", Rect2(178, 222, 352, 34), point != 0, "line"),
		_target("pass_line", "PASS LINE", "7/11 wins · 2/3/12 loses", Rect2(108, 264, 492, 34), point == 0 and int(working.get("pass_line", 0)) <= 0, "line"),
		_target("dont_pass", "DON'T PASS", "2/3 wins · 7/11 loses · 12 bars", Rect2(108, 304, 492, 30), point == 0 and int(working.get("dont_pass", 0)) <= 0, "line"),
	]
	var number_x := 62.0
	for number_value in rules.get("point_numbers", []):
		var number := int(number_value)
		targets.append(_target("place_%d" % number, "PLACE %d" % number, _ratio_label(_dict(_dict(rules.get("place_payouts", {})).get(str(number), {}))), Rect2(number_x, 132, 94, 50), true, "numbers"))
		targets.append(_target("buy_%d" % number, "BUY %d" % number, "True odds · 5% vig", Rect2(number_x, 188, 94, 50), true, "numbers"))
		targets.append(_target("lay_%d" % number, "LAY %d" % number, "7 first · 5% vig", Rect2(number_x, 244, 94, 50), true, "numbers"))
		number_x += 100.0
	targets.append(_target("big_6", "BIG 6", "6 before 7 · even", Rect2(246, 300, 104, 34), true, "numbers"))
	targets.append(_target("big_8", "BIG 8", "8 before 7 · even", Rect2(358, 300, 104, 34), true, "numbers"))
	var hard_numbers := [4, 6, 8, 10]
	for index in range(hard_numbers.size()):
		var number := int(hard_numbers[index])
		targets.append(_target("hard_%d" % number, "HARD %d" % number, "Pair before easy %d or 7" % number, Rect2(92 + index * 142, 142, 132, 52), true, "props"))
	var prop_specs := [
		["any_seven", "ANY 7", "One roll · 4:1"], ["any_craps", "ANY CRAPS", "2, 3, 12 · 7:1"],
		["horn", "HORN HIGH", "Extra chip goes to 12"], ["snake_eyes", "SNAKE EYES", "2 · 30:1"],
		["ace_deuce", "ACE-DEUCE", "3 · 15:1"], ["yo", "YO 11", "11 · 15:1"], ["boxcars", "BOXCARS", "12 · 30:1"],
		["ce", "C & E", "Craps 3:1 · 11 7:1"], ["world", "WORLD", "Horn + 7 · 7 pushes"],
	]
	for index in range(prop_specs.size()):
		var spec: Array = prop_specs[index]
		var column := index % 4
		var row := int(index / 4.0)
		targets.append(_target(str(spec[0]), str(spec[1]), str(spec[2]), Rect2(68 + column * 154, 210 + row * 58, 144, 50), true, "props"))
	if point != 0 and int(working.get("pass_line", 0)) > 0:
		targets.append(_target("pass_odds", "PASS ODDS", "%dx max · true odds" % int(rules.get("max_odds_multiple", 0)), Rect2(116, 142, 206, 42), true, "odds"))
	if point != 0 and int(working.get("dont_pass", 0)) > 0:
		targets.append(_target("dont_pass_odds", "DON'T PASS ODDS", "%dx max · lay odds" % int(rules.get("max_odds_multiple", 0)), Rect2(386, 142, 206, 42), true, "odds"))
	var come: Dictionary = working.get("come", {}) if typeof(working.get("come", {})) == TYPE_DICTIONARY else {}
	var dont_come: Dictionary = working.get("dont_come", {}) if typeof(working.get("dont_come", {})) == TYPE_DICTIONARY else {}
	var odds_y := 196.0
	for number_key in come.keys():
		if int(come.get(number_key, 0)) <= 0:
			continue
		var number := int(number_key)
		targets.append(_target("come_odds_%d" % number, "COME ODDS %d" % number, _ratio_label(_dict(_dict(rules.get("odds_payouts", {})).get(str(number), {}))), Rect2(116, odds_y, 206, 36), true, "odds"))
		odds_y += 40.0
	var dont_odds_y := 196.0
	for number_key in dont_come.keys():
		if int(dont_come.get(number_key, 0)) <= 0:
			continue
		var number := int(number_key)
		targets.append(_target("dont_come_odds_%d" % number, "DON'T ODDS %d" % number, _ratio_label(_dict(_dict(rules.get("lay_odds_payouts", {})).get(str(number), {}))), Rect2(386, dont_odds_y, 206, 36), true, "odds"))
		dont_odds_y += 40.0
	return targets


static func working_rows(table: Dictionary) -> Array:
	var working: Dictionary = table.get("working_bets", {}) if typeof(table.get("working_bets", {})) == TYPE_DICTIONARY else {}
	var rows: Array = []
	for key in ["pass_line", "dont_pass", "pass_odds", "dont_pass_odds"]:
		var stake := int(working.get(key, 0))
		if stake > 0:
			rows.append({"id": key, "label": str(key).replace("_", " ").capitalize(), "stake": stake})
	for group_key in ["come", "dont_come", "come_odds", "dont_come_odds", "place", "buy", "lay", "hardways", "big"]:
		var group: Dictionary = working.get(group_key, {}) if typeof(working.get(group_key, {})) == TYPE_DICTIONARY else {}
		for number_key in group.keys():
			var stake := int(group.get(number_key, 0))
			if stake > 0:
				var target_prefix: String = "hard" if group_key == "hardways" else str(group_key)
				rows.append({"id": "%s_%s" % [target_prefix, str(number_key)], "label": "%s %s" % [str(group_key).replace("_", " ").capitalize(), str(number_key)], "stake": stake})
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


static func _target(id: String, label: String, payout: String, rect: Rect2, enabled: bool, page: String) -> Dictionary:
	return {"id": id, "label": label, "payout": payout, "rect": rect, "enabled": enabled, "page": page}


static func _ratio_label(ratio: Dictionary) -> String:
	return "%d:%d" % [int(ratio.get("numerator", 0)), maxi(1, int(ratio.get("denominator", 1)))]


static func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}
