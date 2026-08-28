extends SceneTree

const RouletteGameScript := preload("res://scripts/games/roulette.gd")

var failures: Array[String] = []


func _init() -> void:
	_check_roulette()
	if failures.is_empty():
		print("GAME06_3_DEPTH_CONTRACT PASS roulette=true baccarat=pending")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_roulette() -> void:
	var game = RouletteGameScript.new()
	var phase_cases := [
		{"elapsed_msec": -1, "motion_active": false, "expected": "betting"},
		{"elapsed_msec": 0, "motion_active": true, "expected": "no_more_bets"},
		{"elapsed_msec": 700, "motion_active": true, "expected": "spin"},
		{"elapsed_msec": 5000, "motion_active": true, "expected": "ball_settle"},
		{"elapsed_msec": 5700, "motion_active": true, "expected": "croupier_settlement"},
	]
	for case_value in phase_cases:
		var case: Dictionary = case_value
		var phase := str(game._roulette_ritual_phase(case, false))
		if phase != str(case.get("expected", "")):
			failures.append("Roulette phase projection returned %s instead of %s." % [phase, str(case.get("expected", ""))])
	var bets := [
		{"id": "straight:17", "label": "17", "family": "inside", "stake": 5},
		{"id": "outside:red", "label": "Red", "family": "outside", "stake": 10},
	]
	var settled := [
		{"id": "straight:17", "label": "17", "stake": 5, "payout": 35, "won": true, "bankroll_delta": 175},
		{"id": "outside:red", "label": "Red", "stake": 10, "payout": 1, "won": false, "bankroll_delta": -10},
	]
	var last_result := {"bets": bets, "bet_results": settled, "winning_number": "17"}
	var projection: Dictionary = game._roulette_ritual_projection("croupier_settlement", [], last_result, {"elapsed_msec": 5750, "payout_active": true}, 1165, [{"cosmetic_bet": 25}, {"cosmetic_bet": 50}], 62)
	if int(projection.get("at_risk_stake", 0)) != 15 or int(projection.get("total_new_stake", -1)) != 0 or (projection.get("per_bet_resolutions", []) as Array).size() != 2:
		failures.append("Roulette settlement projection lost exact at-risk or per-bet accounting.")
	if str(projection.get("late_input_policy", "")) != "reject_without_charge":
		failures.append("Roulette closed gate does not declare side-effect-free late rejection.")
	var actors: Array = projection.get("actors", [])
	var objects: Array = projection.get("scene_objects", [])
	if actors.size() < 4 or objects.size() < 4:
		failures.append("Roulette ritual projection lacks croupier/neighbours/security or wheel/ball/dolly/felt state.")
	var quiet: Dictionary = game._roulette_ritual_projection("betting", bets, {}, {"elapsed_msec": -1}, 1000, [], 0)
	var busy: Dictionary = game._roulette_ritual_projection("betting", bets, {}, {"elapsed_msec": -1}, 1000, [{}, {}], 0)
	var packed: Dictionary = game._roulette_ritual_projection("betting", bets, {}, {"elapsed_msec": -1}, 1000, [{}, {}, {}], 0)
	if str((quiet.get("energy", {}) as Dictionary).get("tier", "")) != "quiet" or str((busy.get("energy", {}) as Dictionary).get("tier", "")) != "busy" or str((packed.get("energy", {}) as Dictionary).get("tier", "")) != "packed":
		failures.append("Roulette energy tiers are not deterministic from material crowd state.")
	var state := {"roulette_bets": bets, "selected_chip": 5, "roulette_undo_stack": []}
	var table := {"rules": {"outside_min_each": 5}, "chip_denominations": [5]}
	var removed: Dictionary = game._remove_bet_chip_command(0, state, table)
	var remaining: Array = (removed.get("ui_state", {}) as Dictionary).get("roulette_bets", [])
	if remaining.size() != 1 or str((remaining[0] as Dictionary).get("id", "")) != "outside:red":
		failures.append("Roulette remove-one changed a different pending stack.")
