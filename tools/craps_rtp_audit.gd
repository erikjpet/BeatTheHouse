extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const CrapsRulesScript := preload("res://scripts/games/craps/craps_rules.gd")

const MINIMUM_ROLLS_PER_BET := 1000000
const REPORT_PATH := "res://.tmp/craps/rtp_audit.json"

var failures: Array = []
var config: Dictionary = {}
var rules: Dictionary = {}
var documentation: Dictionary = {}
var point_numbers: Array = []
var come_out_naturals: Array = []
var come_out_craps: Array = []
var tolerance := 0.0035
var minimum_rolls_required := MINIMUM_ROLLS_PER_BET


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture_path := OS.get_environment("BTH_CRAPS_RTP_FIXTURE_PATH").strip_edges()
	var fixture_rolls := OS.get_environment("BTH_CRAPS_RTP_FIXTURE_ROLLS").strip_edges()
	if fixture_path.is_empty() and not fixture_rolls.is_empty():
		failures.append("Reduced Craps RTP rolls are allowed only with an explicit hostile fixture.")
	if not fixture_path.is_empty():
		minimum_rolls_required = maxi(10000, int(fixture_rolls))
	var rolls_per_bet := minimum_rolls_required
	var requested := OS.get_environment("BTH_CRAPS_RTP_ROLLS").strip_edges()
	if not requested.is_empty():
		rolls_per_bet = maxi(minimum_rolls_required, int(requested))
	var library := ContentLibraryScript.new()
	library.load()
	for error_value in library.validation_errors:
		failures.append("Content validation error: %s" % str(error_value))
	var definition := library.game("craps")
	if not fixture_path.is_empty():
		definition = _load_fixture_definition(fixture_path)
	config = definition.get("craps_config", {}) if typeof(definition.get("craps_config", {})) == TYPE_DICTIONARY else {}
	rules = config.get("rules", {}) if typeof(config.get("rules", {})) == TYPE_DICTIONARY else {}
	documentation = config.get("house_edge_documentation", {}) if typeof(config.get("house_edge_documentation", {})) == TYPE_DICTIONARY else {}
	point_numbers = _int_array(rules.get("point_numbers", []))
	come_out_naturals = _int_array(rules.get("come_out_naturals", []))
	come_out_craps = _int_array(rules.get("come_out_craps", []))
	var audit: Dictionary = config.get("rtp_audit", {}) if typeof(config.get("rtp_audit", {})) == TYPE_DICTIONARY else {}
	tolerance = float(audit.get("tolerance_percent", 0.35)) / 100.0
	if definition.is_empty() or rules.is_empty() or documentation.is_empty():
		failures.append("Craps RTP audit could not load authored rules and house-edge documentation.")

	var run_state: RunState = RunStateScript.new()
	run_state.start_new("CRAPS-RTP-AUDIT")
	var rows: Array = []
	var variant_coverage := _audit_variant_bets(rolls_per_bet, run_state, rows)
	var street_parity := _audit_street_pass_parity(rolls_per_bet, run_state)
	var setting_row := _audit_setting_bias(rolls_per_bet, audit, run_state)
	var report_path := OS.get_environment("BTH_CRAPS_RTP_REPORT_PATH").strip_edges()
	if report_path.is_empty():
		report_path = REPORT_PATH

	var report := {
		"tool": "craps_rtp_audit",
		"seed": "CRAPS-RTP-AUDIT",
		"minimum_rolls_per_bet": MINIMUM_ROLLS_PER_BET,
		"minimum_rolls_required": minimum_rolls_required,
		"requested_rolls_per_bet": rolls_per_bet,
		"fixture_mode": not fixture_path.is_empty(),
		"tolerance": tolerance,
		"rows": rows,
		"variant_coverage": variant_coverage,
		"street_pass_parity": street_parity,
		"setting_bias": setting_row,
		"failures": failures,
		"passed": failures.is_empty(),
	}
	_write_json(report_path, report)
	for row_value in rows:
		var row: Dictionary = row_value
		print("CRAPS_RTP bet=%s rolls=%d decisions=%d rtp=%.6f target=%.6f passed=%s" % [
			str(row.get("bet_id", "")),
			int(row.get("rolls", 0)),
			int(row.get("decisions", 0)),
			float(row.get("rtp", 0.0)),
			float(row.get("documented_rtp", 0.0)),
			str(bool(row.get("passed", false))),
		])
	print("CRAPS_SETTING_FAIRNESS fair_seven=%.6f biased_seven=%.6f reduction=%.6f passed=%s" % [
		float(setting_row.get("fair_seven_probability", 0.0)),
		float(setting_row.get("biased_seven_probability", 0.0)),
		float(setting_row.get("seven_probability_reduction", 0.0)),
		str(bool(setting_row.get("passed", false))),
	])
	print("STREET_CRAPS_RTP_PARITY core=%.6f street=%.6f exact=%s" % [
		float(street_parity.get("core_rtp", 0.0)),
		float(street_parity.get("street_rtp", 0.0)),
		str(bool(street_parity.get("passed", false))),
	])
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _audit_variant_bets(rolls_per_bet: int, run_state: RunState, rows: Array) -> Dictionary:
	var variants := _dict(config.get("variants", {}))
	var covered: Dictionary = {}
	for variant_key in variants.keys():
		var variant_id := str(variant_key)
		var variant := _dict(variants.get(variant_key, {}))
		var allowed: Array = variant.get("allowed_bets", []) if typeof(variant.get("allowed_bets", [])) == TYPE_ARRAY else []
		var measured: Array[String] = []
		for bet_value in allowed:
			var bet_id := str(bet_value)
			if covered.has(bet_id):
				measured.append(bet_id)
				continue
			if not documentation.has(bet_id):
				failures.append("Player-reachable %s bet %s has no house-edge documentation." % [variant_id, bet_id])
				continue
			var row := _audit_bet(bet_id, rolls_per_bet, run_state.create_rng("rtp:%s" % bet_id))
			if row.is_empty():
				failures.append("Player-reachable %s bet %s has no measured RTP implementation." % [variant_id, bet_id])
				continue
			rows.append(row)
			covered[bet_id] = true
			measured.append(bet_id)
		covered["variant:%s" % variant_id] = measured
	for documentation_key in documentation.keys():
		if not covered.has(str(documentation_key)):
			failures.append("House-edge documentation %s is not reachable in any variant." % str(documentation_key))
	return covered


func _audit_bet(bet_id: String, rolls_per_bet: int, rng: RngStream) -> Dictionary:
	if bet_id in ["pass_line", "come"]:
		return _audit_line(bet_id, bet_id, false, rolls_per_bet, rng)
	if bet_id in ["dont_pass", "dont_come"]:
		return _audit_line(bet_id, bet_id, true, rolls_per_bet, rng)
	if bet_id == "pass_odds":
		return _audit_odds(bet_id, false, rolls_per_bet, rng)
	if bet_id == "dont_pass_odds":
		return _audit_odds(bet_id, true, rolls_per_bet, rng)
	if bet_id == "field":
		return _audit_field(rolls_per_bet, rng)
	if bet_id.begins_with("place_"):
		return _audit_number_bet(bet_id, "place", int(bet_id.trim_prefix("place_")), rolls_per_bet, rng)
	if bet_id.begins_with("buy_"):
		return _audit_number_bet(bet_id, "buy", int(bet_id.trim_prefix("buy_")), rolls_per_bet, rng)
	if bet_id.begins_with("lay_"):
		return _audit_number_bet(bet_id, "lay", int(bet_id.trim_prefix("lay_")), rolls_per_bet, rng)
	if bet_id.begins_with("big_"):
		return _audit_number_bet(bet_id, "big", int(bet_id.trim_prefix("big_")), rolls_per_bet, rng)
	if bet_id.begins_with("hard_"):
		return _audit_hardway(bet_id, int(bet_id.trim_prefix("hard_")), rolls_per_bet, rng)
	if bet_id in ["any_seven", "any_craps", "horn", "ce", "world", "snake_eyes", "ace_deuce", "yo", "boxcars"]:
		return _audit_proposition(bet_id, rolls_per_bet, rng)
	return {}


func _audit_line(bet_id: String, documentation_key: String, lay_side: bool, minimum_rolls: int, rng: RngStream) -> Dictionary:
	var point := 0
	var stake := _documented_stake(documentation_key)
	var staked := 0
	var returned := 0
	var decisions := 0
	for _roll_index in range(minimum_rolls):
		var total := _roll_total(rng)
		if point == 0:
			if come_out_naturals.has(total):
				returned += 0 if lay_side else stake * 2
				decisions += 1
				staked += stake
			elif come_out_craps.has(total):
				if lay_side and total == int(rules.get("dont_pass_bar", 12)):
					returned += stake
				elif lay_side:
					returned += stake * 2
				decisions += 1
				staked += stake
			elif point_numbers.has(total):
				point = total
		elif total == point:
			returned += 0 if lay_side else stake * 2
			decisions += 1
			staked += stake
			point = 0
		elif total == int(rules.get("seven_total", 7)):
			returned += stake * 2 if lay_side else 0
			decisions += 1
			staked += stake
			point = 0
	return _rtp_row(bet_id, documentation_key, stake, minimum_rolls, decisions, staked, returned)


func _audit_odds(bet_id: String, lay_side: bool, minimum_rolls: int, rng: RngStream) -> Dictionary:
	var stake := _documented_stake(bet_id)
	var returned := 0
	var returned_squared_sum := 0.0
	var rolls := 0
	var decisions := 0
	while rolls < minimum_rolls:
		var point := int(point_numbers[decisions % point_numbers.size()])
		var decision_return := 0
		while true:
			rolls += 1
			var total := _roll_total(rng)
			if total == point:
				if not lay_side:
					decision_return = stake + CrapsRulesScript.true_odds_profit(stake, point, rules)
				break
			if total == int(rules.get("seven_total", 7)):
				if lay_side:
					decision_return = stake + CrapsRulesScript.lay_odds_profit(stake, point, rules)
				break
		returned += decision_return
		returned_squared_sum += float(decision_return * decision_return)
		decisions += 1
	return _rtp_row(bet_id, bet_id, stake, rolls, decisions, stake * decisions, returned, returned_squared_sum)


func _audit_number_bet(bet_id: String, kind: String, point: int, minimum_rolls: int, rng: RngStream) -> Dictionary:
	var stake := _documented_stake(bet_id)
	var returned := 0
	var returned_squared_sum := 0.0
	var rolls := 0
	var decisions := 0
	while rolls < minimum_rolls:
		var decision_return := 0
		while true:
			rolls += 1
			var total := _roll_total(rng)
			if total == point:
				if kind != "lay":
					var profit := stake if kind == "big" else CrapsRulesScript.buy_profit(stake, point, rules) if kind == "buy" else CrapsRulesScript.place_profit(stake, point, rules)
					decision_return = stake + profit
				break
			if total == int(rules.get("seven_total", 7)):
				if kind == "lay":
					decision_return = stake + CrapsRulesScript.lay_profit(stake, point, rules)
				break
		returned += decision_return
		returned_squared_sum += float(decision_return * decision_return)
		decisions += 1
	return _rtp_row(bet_id, bet_id, stake, rolls, decisions, stake * decisions, returned, returned_squared_sum)


func _audit_hardway(bet_id: String, point: int, minimum_rolls: int, rng: RngStream) -> Dictionary:
	var stake := _documented_stake(bet_id)
	var returned := 0
	var returned_squared_sum := 0.0
	var rolls := 0
	var decisions := 0
	var payout := _dict(_dict(rules.get("hardway_payouts", {})).get(str(point), {}))
	while rolls < minimum_rolls:
		var decision_return := 0
		while true:
			rolls += 1
			var die_a := rng.randi_range(1, 6)
			var die_b := rng.randi_range(1, 6)
			var total := die_a + die_b
			if total == point:
				if die_a == die_b:
					decision_return = stake + _ratio_profit(stake, payout)
				break
			if total == int(rules.get("seven_total", 7)):
				break
		returned += decision_return
		returned_squared_sum += float(decision_return * decision_return)
		decisions += 1
	return _rtp_row(bet_id, bet_id, stake, rolls, decisions, stake * decisions, returned, returned_squared_sum)


func _audit_proposition(bet_id: String, rolls: int, rng: RngStream) -> Dictionary:
	var stake := _documented_stake(bet_id)
	var returned := 0
	var returned_squared_sum := 0.0
	for _roll_index in range(rolls):
		var total := _roll_total(rng)
		var roll_return := int(CrapsRulesScript._settle_proposition_bets({bet_id: stake}, total, rules, []))
		returned += roll_return
		returned_squared_sum += float(roll_return * roll_return)
	return _rtp_row(bet_id, bet_id, stake, rolls, rolls, stake * rolls, returned, returned_squared_sum)


func _audit_field(rolls: int, rng: RngStream) -> Dictionary:
	var stake := _documented_stake("field")
	var returned := 0
	var returned_squared_sum := 0.0
	var payouts := _dict(rules.get("field_payouts", {}))
	for _roll_index in range(rolls):
		var payout := _dict(payouts.get(str(_roll_total(rng)), {}))
		var roll_return := 0
		if not payout.is_empty():
			roll_return = stake + _ratio_profit(stake, payout)
		returned += roll_return
		returned_squared_sum += float(roll_return * roll_return)
	return _rtp_row("field", "field", stake, rolls, rolls, stake * rolls, returned, returned_squared_sum)


func _audit_setting_bias(rolls: int, audit: Dictionary, run_state: RunState) -> Dictionary:
	var fair_rng := run_state.create_rng("setting:fair")
	var biased_rng := run_state.create_rng("setting:biased")
	var fair_sevens := 0
	var biased_sevens := 0
	var setting := _dict(config.get("setting", {}))
	var grades := _dict(setting.get("grades", {}))
	var perfect := _dict(grades.get("perfect", {}))
	var bias := int(perfect.get("bias_permille", 0))
	for _roll_index in range(rolls):
		if int(CrapsRulesScript.roll_dice(fair_rng, rules, 0).get("total", 0)) == int(rules.get("seven_total", 7)):
			fair_sevens += 1
		if int(CrapsRulesScript.roll_dice(biased_rng, rules, bias).get("total", 0)) == int(rules.get("seven_total", 7)):
			biased_sevens += 1
	var fair_probability := float(fair_sevens) / float(rolls)
	var biased_probability := float(biased_sevens) / float(rolls)
	var reduction := fair_probability - biased_probability
	var minimum := float(audit.get("setting_min_seven_probability_reduction", 0.005))
	var maximum := float(audit.get("setting_max_seven_probability_reduction", 0.03))
	var passed := reduction >= minimum and reduction <= maximum and biased_probability > 0.0
	if not passed:
		failures.append("Dice-setting seven reduction %.6f missed authored %.6f-%.6f bound." % [reduction, minimum, maximum])
	return {
		"rolls": rolls,
		"bias_permille": bias,
		"fair_seven_probability": fair_probability,
		"biased_seven_probability": biased_probability,
		"seven_probability_reduction": reduction,
		"documented_reduction_band": [minimum, maximum],
		"passed": passed,
	}


func _audit_street_pass_parity(rolls: int, run_state: RunState) -> Dictionary:
	var variants := _dict(config.get("variants", {}))
	var street := _dict(variants.get("street_craps", {}))
	var allowed: Array = street.get("allowed_bets", []) if typeof(street.get("allowed_bets", [])) == TYPE_ARRAY else []
	var required_full_table_bets := [
		"pass_line", "dont_pass", "come", "dont_come", "field", "pass_odds", "dont_pass_odds",
		"place_4", "place_5", "place_6", "place_8", "place_9", "place_10",
		"buy_4", "buy_5", "buy_6", "buy_8", "buy_9", "buy_10",
		"lay_4", "lay_5", "lay_6", "lay_8", "lay_9", "lay_10",
		"big_6", "big_8", "hard_4", "hard_6", "hard_8", "hard_10",
		"any_seven", "any_craps", "horn", "ce", "world", "snake_eyes", "ace_deuce", "yo", "boxcars",
	]
	var structural_match := str(street.get("scenario_hook_value", "")) == "street_craps"
	for bet_id in required_full_table_bets:
		if not allowed.has(bet_id):
			structural_match = false
			break
	var core_row := _audit_line("core_pass_parity", "pass_line", false, rolls, run_state.create_rng("rtp:street_pass_parity"))
	var street_row := _audit_line("street_pass_parity", "pass_line", false, rolls, run_state.create_rng("rtp:street_pass_parity"))
	var exact := structural_match \
		and int(core_row.get("total_staked", -1)) == int(street_row.get("total_staked", -2)) \
		and int(core_row.get("total_returned", -1)) == int(street_row.get("total_returned", -2)) \
		and is_equal_approx(float(core_row.get("rtp", -1.0)), float(street_row.get("rtp", -2.0)))
	if not exact:
		failures.append("Street Craps Pass Line diverged from the core Pass Line under identical deterministic rolls.")
	return {
		"rolls": rolls,
		"core_rtp": float(core_row.get("rtp", 0.0)),
		"street_rtp": float(street_row.get("rtp", 0.0)),
		"same_rules_engine": structural_match,
		"passed": exact,
	}


func _rtp_row(bet_id: String, documentation_key: String, stake: int, rolls: int, decisions: int, staked: int, returned: int, returned_squared_sum: float = -1.0) -> Dictionary:
	var documented_row := _dict(documentation.get(documentation_key, {}))
	var documented := float(documented_row.get("rtp_percent", 0.0)) / 100.0
	var rtp := float(returned) / float(maxi(1, staked))
	var standard_error := 0.0
	if returned_squared_sum >= 0.0 and decisions > 1:
		var mean_return := float(returned) / float(decisions)
		var return_variance := maxf(0.0, returned_squared_sum / float(decisions) - mean_return * mean_return)
		standard_error = sqrt(return_variance / float(decisions)) / float(stake)
	var effective_tolerance := maxf(tolerance, 4.0 * standard_error)
	var passed := rolls >= minimum_rolls_required and stake == int(documented_row.get("audit_stake", -1)) and absf(rtp - documented) <= effective_tolerance
	if not passed:
		failures.append("%s RTP %.6f missed documented %.6f +/- %.6f after %d rolls." % [bet_id, rtp, documented, effective_tolerance, rolls])
	return {
		"bet_id": bet_id,
		"audit_stake": stake,
		"rolls": rolls,
		"decisions": decisions,
		"total_staked": staked,
		"total_returned": returned,
		"rtp": rtp,
		"documented_rtp": documented,
		"base_tolerance": tolerance,
		"standard_error": standard_error,
		"effective_tolerance": effective_tolerance,
		"passed": passed,
	}


func _documented_stake(bet_id: String) -> int:
	var stake := int(_dict(documentation.get(bet_id, {})).get("audit_stake", 0))
	if stake <= 0:
		failures.append("%s house-edge documentation has no positive audit_stake." % bet_id)
	return maxi(1, stake)


func _load_fixture_definition(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		failures.append("Could not open Craps RTP hostile fixture: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("Craps RTP hostile fixture is not a dictionary: %s" % path)
		return {}
	var fixture := parsed as Dictionary
	if not fixture.has("craps_config"):
		failures.append("Craps RTP hostile fixture has no craps_config: %s" % path)
		return {}
	return fixture


func _roll_total(rng: RngStream) -> int:
	var sides := maxi(2, int(rules.get("die_sides", 6)))
	return rng.randi_range(1, sides) + rng.randi_range(1, sides)


func _ratio_profit(stake: int, ratio: Dictionary) -> int:
	return int(floor(float(stake * int(ratio.get("numerator", 0))) / float(maxi(1, int(ratio.get("denominator", 1))))))


func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _int_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for item in value:
			result.append(int(item))
	return result


func _write_json(path: String, payload: Dictionary) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write Craps RTP report: %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
