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


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rolls_per_bet := MINIMUM_ROLLS_PER_BET
	var requested := OS.get_environment("BTH_CRAPS_RTP_ROLLS").strip_edges()
	if not requested.is_empty():
		rolls_per_bet = maxi(MINIMUM_ROLLS_PER_BET, int(requested))
	var library := ContentLibraryScript.new()
	library.load()
	for error_value in library.validation_errors:
		failures.append("Content validation error: %s" % str(error_value))
	var definition := library.game("craps")
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
	rows.append(_audit_line("pass_line", "pass_line", false, rolls_per_bet, run_state.create_rng("rtp:pass_line")))
	rows.append(_audit_line("dont_pass", "dont_pass", true, rolls_per_bet, run_state.create_rng("rtp:dont_pass")))
	rows.append(_audit_line("come", "come", false, rolls_per_bet, run_state.create_rng("rtp:come")))
	rows.append(_audit_line("dont_come", "dont_come", true, rolls_per_bet, run_state.create_rng("rtp:dont_come")))
	rows.append(_audit_odds(rolls_per_bet, run_state.create_rng("rtp:odds")))
	rows.append(_audit_place("place_4_10", 4, rolls_per_bet, run_state.create_rng("rtp:place_4_10")))
	rows.append(_audit_place("place_5_9", 5, rolls_per_bet, run_state.create_rng("rtp:place_5_9")))
	rows.append(_audit_place("place_6_8", 6, rolls_per_bet, run_state.create_rng("rtp:place_6_8")))
	rows.append(_audit_field(rolls_per_bet, run_state.create_rng("rtp:field")))
	var street_parity := _audit_street_pass_parity(rolls_per_bet, run_state)
	var setting_row := _audit_setting_bias(rolls_per_bet, audit, run_state)

	var report := {
		"tool": "craps_rtp_audit",
		"seed": "CRAPS-RTP-AUDIT",
		"minimum_rolls_per_bet": MINIMUM_ROLLS_PER_BET,
		"requested_rolls_per_bet": rolls_per_bet,
		"tolerance": tolerance,
		"rows": rows,
		"street_pass_parity": street_parity,
		"setting_bias": setting_row,
		"failures": failures,
		"passed": failures.is_empty(),
	}
	_write_json(REPORT_PATH, report)
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


func _audit_line(bet_id: String, documentation_key: String, lay_side: bool, minimum_rolls: int, rng: RngStream) -> Dictionary:
	var point := 0
	var staked := 10
	var returned := 0
	var decisions := 0
	for _roll_index in range(minimum_rolls):
		var total := _roll_total(rng)
		if point == 0:
			if come_out_naturals.has(total):
				returned += 0 if lay_side else 20
				decisions += 1
				staked += 10
			elif come_out_craps.has(total):
				if lay_side and total == int(rules.get("dont_pass_bar", 12)):
					returned += 10
				elif lay_side:
					returned += 20
				decisions += 1
				staked += 10
			elif point_numbers.has(total):
				point = total
		elif total == point:
			returned += 0 if lay_side else 20
			decisions += 1
			staked += 10
			point = 0
		elif total == int(rules.get("seven_total", 7)):
			returned += 20 if lay_side else 0
			decisions += 1
			staked += 10
			point = 0
	return _rtp_row(bet_id, documentation_key, minimum_rolls, decisions, staked, returned)


func _audit_odds(samples: int, rng: RngStream) -> Dictionary:
	var stake := 30
	var returned := 0
	var rolls := 0
	for sample_index in range(samples):
		var point := int(point_numbers[sample_index % point_numbers.size()])
		while true:
			rolls += 1
			var total := _roll_total(rng)
			if total == point:
				returned += stake + CrapsRulesScript.true_odds_profit(stake, point, rules)
				break
			if total == int(rules.get("seven_total", 7)):
				break
	return _rtp_row("odds", "odds", rolls, samples, stake * samples, returned)


func _audit_place(documentation_key: String, point: int, samples: int, rng: RngStream) -> Dictionary:
	var stake := 30
	var returned := 0
	var rolls := 0
	for _sample_index in range(samples):
		while true:
			rolls += 1
			var total := _roll_total(rng)
			if total == point:
				returned += stake + _ratio_profit(stake, _dict(_dict(rules.get("place_payouts", {})).get(str(point), {})))
				break
			if total == int(rules.get("seven_total", 7)):
				break
	return _rtp_row(documentation_key, documentation_key, rolls, samples, stake * samples, returned)


func _audit_field(rolls: int, rng: RngStream) -> Dictionary:
	var stake := 10
	var returned := 0
	var payouts := _dict(rules.get("field_payouts", {}))
	for _roll_index in range(rolls):
		var payout := _dict(payouts.get(str(_roll_total(rng)), {}))
		if not payout.is_empty():
			returned += stake + _ratio_profit(stake, payout)
	return _rtp_row("field", "field", rolls, rolls, stake * rolls, returned)


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
	var structural_match := str(street.get("scenario_hook_value", "")) == "street_craps" and allowed == ["pass_line", "dont_pass"]
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


func _rtp_row(bet_id: String, documentation_key: String, rolls: int, decisions: int, staked: int, returned: int) -> Dictionary:
	var documented := float(_dict(documentation.get(documentation_key, {})).get("rtp_percent", 0.0)) / 100.0
	var rtp := float(returned) / float(maxi(1, staked))
	var passed := rolls >= MINIMUM_ROLLS_PER_BET and absf(rtp - documented) <= tolerance
	if not passed:
		failures.append("%s RTP %.6f missed documented %.6f +/- %.6f after %d rolls." % [bet_id, rtp, documented, tolerance, rolls])
	return {
		"bet_id": bet_id,
		"rolls": rolls,
		"decisions": decisions,
		"total_staked": staked,
		"total_returned": returned,
		"rtp": rtp,
		"documented_rtp": documented,
		"tolerance": tolerance,
		"passed": passed,
	}


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
