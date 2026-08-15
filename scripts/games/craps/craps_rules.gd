class_name CrapsRules
extends RefCounted


static func roll_dice(rng: RngStream, rules: Dictionary, setting_bias_permille: int = 0) -> Dictionary:
	var die_sides := maxi(2, int(rules.get("die_sides", 6)))
	var first := rng.randi_range(1, die_sides)
	var second := rng.randi_range(1, die_sides)
	var initial_total := first + second
	var bias_applied := false
	if initial_total == int(rules.get("seven_total", 7)) and setting_bias_permille > 0 and rng.randi_range(1, 1000) <= setting_bias_permille:
		if rng.randi_range(0, 1) == 0:
			first = rng.randi_range(1, die_sides)
		else:
			second = rng.randi_range(1, die_sides)
		bias_applied = true
	return {
		"dice": [first, second],
		"total": first + second,
		"initial_total": initial_total,
		"setting_bias_applied": bias_applied,
	}


static func pending_wager_total(pending_value: Variant) -> int:
	var total := 0
	if typeof(pending_value) != TYPE_DICTIONARY:
		return total
	for value in (pending_value as Dictionary).values():
		total += maxi(0, int(value))
	return total


static func can_place_bet(bet_id: String, amount: int, table: Dictionary, pending: Dictionary, rules: Dictionary) -> Dictionary:
	if amount <= 0:
		return {"ok": false, "message": "Select a chip before placing that wager."}
	var point := int(table.get("point", 0))
	var working := _working(table)
	var combined := _combined_stake(bet_id, working, pending)
	var table_minimum := maxi(1, int(table.get("table_minimum", 1)))
	var table_maximum := maxi(table_minimum, int(table.get("table_maximum", table_minimum)))
	if combined == 0 and amount < table_minimum:
		return {"ok": false, "message": "That wager is below the posted table minimum."}
	if combined + amount > table_maximum:
		return {"ok": false, "message": "That wager exceeds the posted table maximum."}
	match bet_id:
		"pass_line", "dont_pass":
			if point != 0:
				return {"ok": false, "message": "Line wagers wait for the next come-out roll."}
			if combined > 0:
				return {"ok": false, "message": "That line wager is already working."}
		"come", "dont_come":
			if point == 0:
				return {"ok": false, "message": "Come wagers open after the point is established."}
		"pass_odds":
			var pass_stake := int(working.get("pass_line", 0)) + int(pending.get("pass_line", 0))
			if point == 0 or pass_stake <= 0:
				return {"ok": false, "message": "Pass odds require a working Pass Line wager."}
			if combined + amount > pass_stake * int(rules.get("max_odds_multiple", 0)):
				return {"ok": false, "message": "The table has reached its posted odds limit."}
		_:
			if bet_id.begins_with("come_odds_"):
				var number := int(bet_id.trim_prefix("come_odds_"))
				var come_bets := _dict(working.get("come", {}))
				var base_stake := int(come_bets.get(str(number), 0))
				if base_stake <= 0:
					return {"ok": false, "message": "Come odds require a working Come number."}
				if combined + amount > base_stake * int(rules.get("max_odds_multiple", 0)):
					return {"ok": false, "message": "The table has reached its posted odds limit."}
			elif not bet_id.begins_with("place_") and bet_id != "field":
				return {"ok": false, "message": "That wager is not offered at this table."}
	return {"ok": true}


static func settle_roll(table: Dictionary, pending_value: Variant, roll: Dictionary, rules: Dictionary) -> Dictionary:
	var pending := _dict(pending_value)
	var working := _working(table)
	var total := int(roll.get("total", 0))
	var point_before := int(table.get("point", 0))
	var bankroll_delta := -pending_wager_total(pending)
	var results: Array = []
	var existing_come := _dict(working.get("come", {})).duplicate(true)
	var existing_dont_come := _dict(working.get("dont_come", {})).duplicate(true)
	_merge_pending_persistent(working, pending)
	# Pending odds are attached to already-established Come numbers before this
	# throw and must settle on an immediate number or seven. New Come wagers are
	# still excluded because _merge_pending_persistent never merges the apron bet.
	var existing_come_odds := _dict(working.get("come_odds", {})).duplicate(true)

	var line_result := _settle_line_bets(working, total, point_before, rules, results)
	bankroll_delta += int(line_result.get("credit", 0))
	var point_after := int(line_result.get("point", point_before))
	var point_made := bool(line_result.get("point_made", false))
	var seven_out := bool(line_result.get("seven_out", false))

	var established_result := _settle_established_come_bets(
		working,
		existing_come,
		existing_dont_come,
		existing_come_odds,
		total,
		point_before,
		rules,
		results
	)
	bankroll_delta += int(established_result.get("credit", 0))
	bankroll_delta += _settle_new_come_bets(working, pending, total, rules, results)
	bankroll_delta += _settle_place_bets(working, total, point_before, rules, results)
	bankroll_delta += _settle_field(int(pending.get("field", 0)), total, rules, results)

	table["point"] = point_after
	table["working_bets"] = working
	table["roll_count"] = int(table.get("roll_count", 0)) + 1
	table["hot_shooter_streak"] = int(table.get("hot_shooter_streak", 0)) + 1 if point_made else 0 if seven_out else int(table.get("hot_shooter_streak", 0))
	var energy_per_point := int(rules.get("table_energy_per_point", 0))
	var energy_seven_out_loss := int(rules.get("table_energy_seven_out_loss", 0))
	var energy := int(table.get("table_energy", 0))
	if point_made:
		energy += energy_per_point * maxi(1, int(table.get("hot_shooter_streak", 1)))
	elif seven_out:
		energy -= energy_seven_out_loss
	table["table_energy"] = clampi(energy, int(rules.get("table_energy_min", 0)), int(rules.get("table_energy_max", 100)))

	return {
		"bankroll_delta": bankroll_delta,
		"total_wager": pending_wager_total(pending),
		"point_before": point_before,
		"point_after": point_after,
		"point_made": point_made,
		"seven_out": seven_out,
		"bet_results": results,
		"working_bets": working.duplicate(true),
	}


static func true_odds_profit(stake: int, number: int, rules: Dictionary) -> int:
	return _profit(stake, _dict(_dict(rules.get("odds_payouts", {})).get(str(number), {})))


static func place_profit(stake: int, number: int, rules: Dictionary) -> int:
	return _profit(stake, _dict(_dict(rules.get("place_payouts", {})).get(str(number), {})))


static func _settle_line_bets(working: Dictionary, total: int, point: int, rules: Dictionary, results: Array) -> Dictionary:
	var credit := 0
	var point_after := point
	var pass_stake := int(working.get("pass_line", 0))
	var dont_stake := int(working.get("dont_pass", 0))
	var odds_stake := int(working.get("pass_odds", 0))
	var point_made := false
	var seven_out := false
	if point == 0:
		if _int_array(rules.get("come_out_naturals", [])).has(total):
			credit += _win_and_clear(working, "pass_line", pass_stake, rules, results, "Pass Line")
			_clear_loss(working, "dont_pass", dont_stake, results, "Don't Pass")
		elif _int_array(rules.get("come_out_craps", [])).has(total):
			_clear_loss(working, "pass_line", pass_stake, results, "Pass Line")
			if total == int(rules.get("dont_pass_bar", 0)):
				credit += _push_and_clear(working, "dont_pass", dont_stake, results, "Don't Pass")
			else:
				credit += _win_and_clear(working, "dont_pass", dont_stake, rules, results, "Don't Pass")
		elif _int_array(rules.get("point_numbers", [])).has(total):
			point_after = total
	else:
		if total == point:
			credit += _win_and_clear(working, "pass_line", pass_stake, rules, results, "Pass Line")
			_clear_loss(working, "dont_pass", dont_stake, results, "Don't Pass")
			if odds_stake > 0:
				var odds_profit := true_odds_profit(odds_stake, point, rules)
				credit += odds_stake + odds_profit
				results.append(_bet_result("Pass Odds", odds_stake, odds_profit, "win"))
			working["pass_odds"] = 0
			point_after = 0
			point_made = true
		elif total == int(rules.get("seven_total", 7)):
			_clear_loss(working, "pass_line", pass_stake, results, "Pass Line")
			credit += _win_and_clear(working, "dont_pass", dont_stake, rules, results, "Don't Pass")
			_clear_loss(working, "pass_odds", odds_stake, results, "Pass Odds")
			point_after = 0
			seven_out = true
	return {"credit": credit, "point": point_after, "point_made": point_made, "seven_out": seven_out}


static func _settle_established_come_bets(working: Dictionary, come: Dictionary, dont_come: Dictionary, come_odds: Dictionary, total: int, point_before: int, rules: Dictionary, results: Array) -> Dictionary:
	var credit := 0
	var current_come := _dict(working.get("come", {}))
	var current_dont := _dict(working.get("dont_come", {}))
	var current_odds := _dict(working.get("come_odds", {}))
	for number_key in come.keys():
		var number := int(number_key)
		var stake := int(come.get(number_key, 0))
		var odds_stake := int(come_odds.get(number_key, 0))
		if total == number:
			var profit := _even_money_profit(stake, rules)
			credit += stake + profit
			results.append(_bet_result("Come %d" % number, stake, profit, "win"))
			if odds_stake > 0:
				if point_before == 0 and not bool(rules.get("odds_work_on_come_out", false)):
					credit += odds_stake
					results.append(_bet_result("Come Odds %d" % number, odds_stake, 0, "off"))
				else:
					var odds_profit := true_odds_profit(odds_stake, number, rules)
					credit += odds_stake + odds_profit
					results.append(_bet_result("Come Odds %d" % number, odds_stake, odds_profit, "win"))
			current_come.erase(number_key)
			current_odds.erase(number_key)
		elif total == int(rules.get("seven_total", 7)):
			results.append(_bet_result("Come %d" % number, stake, -stake, "loss"))
			if odds_stake > 0:
				results.append(_bet_result("Come Odds %d" % number, odds_stake, -odds_stake, "loss"))
			current_come.erase(number_key)
			current_odds.erase(number_key)
	for number_key in dont_come.keys():
		var number := int(number_key)
		var stake := int(dont_come.get(number_key, 0))
		if total == number:
			results.append(_bet_result("Don't Come %d" % number, stake, -stake, "loss"))
			current_dont.erase(number_key)
		elif total == int(rules.get("seven_total", 7)):
			var profit := _even_money_profit(stake, rules)
			credit += stake + profit
			results.append(_bet_result("Don't Come %d" % number, stake, profit, "win"))
			current_dont.erase(number_key)
	working["come"] = current_come
	working["dont_come"] = current_dont
	working["come_odds"] = current_odds
	return {"credit": credit}


static func _settle_new_come_bets(working: Dictionary, pending: Dictionary, total: int, rules: Dictionary, results: Array) -> int:
	var credit := 0
	var come_stake := int(pending.get("come", 0))
	var dont_stake := int(pending.get("dont_come", 0))
	var come := _dict(working.get("come", {}))
	var dont_come := _dict(working.get("dont_come", {}))
	if come_stake > 0:
		if _int_array(rules.get("come_out_naturals", [])).has(total):
			var profit := _even_money_profit(come_stake, rules)
			credit += come_stake + profit
			results.append(_bet_result("Come", come_stake, profit, "win"))
		elif _int_array(rules.get("come_out_craps", [])).has(total):
			results.append(_bet_result("Come", come_stake, -come_stake, "loss"))
		else:
			come[str(total)] = int(come.get(str(total), 0)) + come_stake
			results.append(_bet_result("Come", come_stake, 0, "moved_%d" % total))
	if dont_stake > 0:
		if _int_array(rules.get("come_out_naturals", [])).has(total):
			results.append(_bet_result("Don't Come", dont_stake, -dont_stake, "loss"))
		elif _int_array(rules.get("come_out_craps", [])).has(total):
			if total == int(rules.get("dont_pass_bar", 0)):
				credit += dont_stake
				results.append(_bet_result("Don't Come", dont_stake, 0, "push"))
			else:
				var profit := _even_money_profit(dont_stake, rules)
				credit += dont_stake + profit
				results.append(_bet_result("Don't Come", dont_stake, profit, "win"))
		else:
			dont_come[str(total)] = int(dont_come.get(str(total), 0)) + dont_stake
			results.append(_bet_result("Don't Come", dont_stake, 0, "moved_%d" % total))
	working["come"] = come
	working["dont_come"] = dont_come
	return credit


static func _settle_place_bets(working: Dictionary, total: int, point_before: int, rules: Dictionary, results: Array) -> int:
	var credit := 0
	var place := _dict(working.get("place", {}))
	var active := point_before != 0 or bool(rules.get("place_bets_work_on_come_out", false))
	if not active:
		return credit
	if total == int(rules.get("seven_total", 7)):
		for number_key in place.keys():
			var stake := int(place.get(number_key, 0))
			if stake > 0:
				results.append(_bet_result("Place %s" % number_key, stake, -stake, "loss"))
		place.clear()
	elif place.has(str(total)):
		var stake := int(place.get(str(total), 0))
		var profit := place_profit(stake, total, rules)
		credit += profit
		results.append(_bet_result("Place %d" % total, stake, profit, "win_working"))
	working["place"] = place
	return credit


static func _settle_field(stake: int, total: int, rules: Dictionary, results: Array) -> int:
	if stake <= 0:
		return 0
	var payouts := _dict(rules.get("field_payouts", {}))
	if payouts.has(str(total)):
		var profit := _profit(stake, _dict(payouts.get(str(total), {})))
		results.append(_bet_result("Field", stake, profit, "win"))
		return stake + profit
	results.append(_bet_result("Field", stake, -stake, "loss"))
	return 0


static func _merge_pending_persistent(working: Dictionary, pending: Dictionary) -> void:
	for line_key in ["pass_line", "dont_pass", "pass_odds"]:
		working[line_key] = int(working.get(line_key, 0)) + int(pending.get(line_key, 0))
	var place := _dict(working.get("place", {}))
	var odds := _dict(working.get("come_odds", {}))
	for key_value in pending.keys():
		var key := str(key_value)
		if key.begins_with("place_"):
			var number_key := key.trim_prefix("place_")
			place[number_key] = int(place.get(number_key, 0)) + int(pending.get(key, 0))
		elif key.begins_with("come_odds_"):
			var number_key := key.trim_prefix("come_odds_")
			odds[number_key] = int(odds.get(number_key, 0)) + int(pending.get(key, 0))
	working["place"] = place
	working["come_odds"] = odds


static func _working(table: Dictionary) -> Dictionary:
	var working := _dict(table.get("working_bets", {})).duplicate(true)
	working["pass_line"] = maxi(0, int(working.get("pass_line", 0)))
	working["dont_pass"] = maxi(0, int(working.get("dont_pass", 0)))
	working["pass_odds"] = maxi(0, int(working.get("pass_odds", 0)))
	working["come"] = _dict(working.get("come", {})).duplicate(true)
	working["dont_come"] = _dict(working.get("dont_come", {})).duplicate(true)
	working["come_odds"] = _dict(working.get("come_odds", {})).duplicate(true)
	working["place"] = _dict(working.get("place", {})).duplicate(true)
	return working


static func _combined_stake(bet_id: String, working: Dictionary, pending: Dictionary) -> int:
	var value := int(pending.get(bet_id, 0))
	if bet_id.begins_with("place_"):
		value += int(_dict(working.get("place", {})).get(bet_id.trim_prefix("place_"), 0))
	elif bet_id.begins_with("come_odds_"):
		value += int(_dict(working.get("come_odds", {})).get(bet_id.trim_prefix("come_odds_"), 0))
	elif bet_id != "come" and bet_id != "dont_come":
		# Come and Don't Come working state is a traveled-number map. A new
		# apron wager is scalar and must not coerce that collection to an int.
		value += int(working.get(bet_id, 0))
	return value


static func _win_and_clear(working: Dictionary, key: String, stake: int, rules: Dictionary, results: Array, label: String) -> int:
	working[key] = 0
	if stake <= 0:
		return 0
	var profit := _even_money_profit(stake, rules)
	results.append(_bet_result(label, stake, profit, "win"))
	return stake + profit


static func _push_and_clear(working: Dictionary, key: String, stake: int, results: Array, label: String) -> int:
	working[key] = 0
	if stake > 0:
		results.append(_bet_result(label, stake, 0, "push"))
	return stake


static func _clear_loss(working: Dictionary, key: String, stake: int, results: Array, label: String) -> void:
	working[key] = 0
	if stake > 0:
		results.append(_bet_result(label, stake, -stake, "loss"))


static func _even_money_profit(stake: int, rules: Dictionary) -> int:
	return _profit(stake, _dict(rules.get("even_money_payout", {})))


static func _profit(stake: int, ratio: Dictionary) -> int:
	var denominator := maxi(1, int(ratio.get("denominator", 1)))
	return int(floor(float(maxi(0, stake) * int(ratio.get("numerator", 0))) / float(denominator)))


static func _bet_result(label: String, stake: int, profit: int, outcome: String) -> Dictionary:
	return {"label": label, "stake": stake, "profit": profit, "outcome": outcome}


static func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


static func _int_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value:
			result.append(int(entry))
	return result
