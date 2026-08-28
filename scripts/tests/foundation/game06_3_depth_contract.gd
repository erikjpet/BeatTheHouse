extends SceneTree

const RouletteGameScript := preload("res://scripts/games/roulette.gd")
const BaccaratGameScript := preload("res://scripts/games/baccarat.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

var failures: Array[String] = []


func _init() -> void:
	_check_roulette()
	_check_baccarat()
	if failures.is_empty():
		print("GAME06_3_DEPTH_CONTRACT PASS roulette=true baccarat=true")
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


func _check_baccarat() -> void:
	var game = BaccaratGameScript.new()
	var games_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/games/games.json"))
	for definition_value in games_value if typeof(games_value) == TYPE_ARRAY else []:
		if typeof(definition_value) == TYPE_DICTIONARY and str((definition_value as Dictionary).get("id", "")) == "baccarat":
			game.setup(definition_value as Dictionary)
			break
	if game.get_id() != "baccarat":
		failures.append("Executable proof could not load the shipped baccarat definition.")
		return
	var phase_cases := [
		{"elapsed": -1, "expected": "betting"},
		{"elapsed": 0, "expected": "shoe"},
		{"elapsed": 500, "expected": "deal"},
		{"elapsed": 1900, "expected": "squeeze_reveal"},
		{"elapsed": 2500, "expected": "third_card_rule"},
		{"elapsed": 3700, "expected": "settlement"},
		{"elapsed": 5800, "expected": "betting"},
	]
	for case_value in phase_cases:
		var case: Dictionary = case_value
		var phase := str(game._baccarat_ritual_phase({"hand_id": "fixture"}, int(case.get("elapsed", -1))))
		if phase != str(case.get("expected", "")):
			failures.append("Baccarat phase projection returned %s instead of %s." % [phase, str(case.get("expected", ""))])
	var hand := {
		"natural": false, "player_initial_total": 5, "banker_initial_total": 3,
		"player_drew": true, "banker_drew": false, "player_third_value": 8,
	}
	var procedure: Dictionary = game._baccarat_third_card_procedure(hand)
	var steps: Array = procedure.get("steps", [])
	if steps.size() != 2 or str((steps[0] as Dictionary).get("decision", "")) != "draw" or str((steps[1] as Dictionary).get("decision", "")) != "stand":
		failures.append("Baccarat third-card procedure does not expose the observed player-then-banker decisions.")
	var bets := {"banker": 20, "player_pair": 5}
	var last_result := {
		"bets": bets,
		"commission": 1,
		"bet_results": [{"id": "banker", "stake": 20, "won": true, "commission": 1, "bankroll_delta": 19}],
	}
	var table := {"shoe_remaining": 311, "reshuffle_pending": false, "hand_history": [{"winner": "banker"}], "discard": [{}, {}, {}, {}], "commission_owed": 7}
	var projection: Dictionary = game._baccarat_ritual_projection("settlement", {}, last_result, table, [{"cosmetic_bet": 25}, {"cosmetic_bet": 50}, {"cosmetic_bet": 75}], [{"state": "present", "cost": 6, "window": "settlement"}], 1019, 64)
	if int(projection.get("at_risk_stake", 0)) != 25 or (projection.get("per_bet_resolutions", []) as Array).size() != 1:
		failures.append("Baccarat settlement projection lost exact wager resolution accounting.")
	var commission: Dictionary = projection.get("commission", {})
	if int(commission.get("this_hand", 0)) != 1 or int(commission.get("running_total", 0)) != 7:
		failures.append("Baccarat commission is not explicit at hand and running-total levels.")
	if (projection.get("actors", []) as Array).size() < 7 or (projection.get("scene_objects", []) as Array).size() != 4:
		failures.append("Baccarat ritual projection lacks dealer/caller/neighbours/crew/security or shoe/roads/discard/felt state.")
	if bool(((projection.get("scene_objects", []) as Array)[1] as Dictionary).get("predictive_authority", true)):
		failures.append("Baccarat road boards incorrectly claim predictive authority.")
	var quiet: Dictionary = game._baccarat_ritual_projection("betting", bets, {}, table, [], [], 1000, 0)
	var busy: Dictionary = game._baccarat_ritual_projection("betting", bets, {}, table, [{}, {}], [], 1000, 0)
	var packed: Dictionary = game._baccarat_ritual_projection("betting", bets, {}, table, [{}, {}, {}], [], 1000, 0)
	if str((quiet.get("energy", {}) as Dictionary).get("tier", "")) != "quiet" or str((busy.get("energy", {}) as Dictionary).get("tier", "")) != "busy" or str((packed.get("energy", {}) as Dictionary).get("tier", "")) != "packed":
		failures.append("Baccarat energy tiers are not deterministic from material crowd state.")
	var run_state = RunStateScript.new()
	run_state.start_new("GAME06-3-BACCARAT-SQUEEZE")
	run_state.simulation_msec = 10000
	var squeeze_result := {"hand_id": "squeeze", "resolved_at_msec": 8200, "animation_events": [{"type": "squeeze", "target_zone": "player", "card_slot": 1, "delay_msec": 1800, "duration_msec": 600}]}
	var squeeze_table := {"last_result": squeeze_result}
	var before := JSON.stringify(squeeze_table)
	var squeezed: Dictionary = game._squeeze_command({"surface_time_msec": 10000}, squeeze_table, run_state, false)
	if bool(squeezed.get("resolve", false)) or bool(squeezed.get("direct_resolve", false)) or float((squeezed.get("ui_state", {}) as Dictionary).get("baccarat_squeeze_progress", 0.0)) <= 0.0 or JSON.stringify(squeeze_table) != before:
		failures.append("Baccarat squeeze changed authority, resolved an action, or failed to advance presentation only.")
	var reduced: Dictionary = game._squeeze_command({"surface_time_msec": 10000, "reduce_motion": true}, squeeze_table, run_state, false)
	if float((reduced.get("ui_state", {}) as Dictionary).get("baccarat_squeeze_progress", 0.0)) != 1.0:
		failures.append("Reduced-motion Baccarat squeeze does not reveal the identical fixed card immediately.")
	if FileAccess.get_file_as_string("res://scripts/games/baccarat.gd").find("Time.get_ticks_msec") >= 0:
		failures.append("Baccarat module still depends on uptime instead of the deterministic simulation clock.")
	var environment := {"id": "game06_3_baccarat_restore", "archetype_id": "grand_casino", "kind": "boss", "game_ids": ["baccarat"], "economic_profile": {"stake_floor": 5, "stake_ceiling": 1000}, "security_profile": {"strictness": "high"}}
	var generated: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("game06_3_baccarat_table"))
	var restored_hand := hand.duplicate(true)
	restored_hand["player_cards"] = [{"rank": 2, "suit": "clubs"}, {"rank": 3, "suit": "hearts"}, {"rank": 8, "suit": "spades"}]
	restored_hand["banker_cards"] = [{"rank": 1, "suit": "diamonds"}, {"rank": 2, "suit": "clubs"}]
	restored_hand["animation_events"] = squeeze_result.get("animation_events", [])
	generated["last_hand"] = restored_hand
	generated["last_result"] = {"hand_id": "restore", "resolved_at_msec": 8200, "deal_animation_id": "restore_deal", "payout_animation_id": "restore_pay", "hand": restored_hand, "animation_events": restored_hand.get("animation_events", []), "bets": {"banker": 20}, "bet_results": [], "commission": 1}
	environment["game_states"] = {"baccarat": generated}
	run_state.current_environment = environment
	var restored_state = RunStateScript.new()
	restored_state.from_dict(run_state.to_dict())
	var active_ui := {"surface_time_msec": 10000, "surface_presentation_time_msec": 12000}
	var first_surface: Dictionary = game.surface_state(run_state, run_state.current_environment, active_ui)
	var restored_surface: Dictionary = game.surface_state(restored_state, restored_state.current_environment, active_ui)
	if JSON.stringify(first_surface) != JSON.stringify(restored_surface) or str(first_surface.get("phase", "")) != "dealing" or str(first_surface.get("ritual_phase", "")) != "squeeze_reveal":
		failures.append("Baccarat save/revisit did not restore the deterministic squeeze boundary exactly.")
