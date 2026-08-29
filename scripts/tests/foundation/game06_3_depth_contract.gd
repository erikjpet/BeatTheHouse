extends SceneTree

const RouletteGameScript := preload("res://scripts/games/roulette.gd")
const BaccaratGameScript := preload("res://scripts/games/baccarat.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const BlackjackActionAuthorityScript := preload("res://scripts/core/blackjack_action_authority.gd")
const RuntimeScript := preload("res://scripts/core/game_ritual_runtime.gd")

var failures: Array[String] = []


class RitualDrawProbe:
	extends RefCounted
	var labels: Array[String] = []
	var hits: Array[Dictionary] = []

	func draw_rect(_rect: Rect2, _color: Color, _filled: bool = true, _width: float = -1.0) -> void:
		pass

	func surface_label_centered(text: String, _rect: Rect2, _size: int, _color: Color) -> void:
		labels.append(text)

	func surface_label_centered_plain(text: String, _rect: Rect2, _size: int, _color: Color) -> void:
		labels.append(text)

	func surface_add_hold_hit(rect: Rect2, action: String, index: int = -1) -> void:
		hits.append({"rect": rect, "action": action, "index": index, "keyboard_hold": true, "drag": true})


func _init() -> void:
	_check_roulette()
	_check_baccarat()
	_check_exact_settlement_accounting()
	_check_authoritative_host_matrix()
	if failures.is_empty():
		print("GAME06_3_DEPTH_CONTRACT PASS roulette=true baccarat=true")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_roulette() -> void:
	var game = RouletteGameScript.new()
	_setup_game_definition(game, "roulette")
	if game.get_id() != "roulette":
		failures.append("Executable proof could not load the shipped roulette definition.")
		return
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
	var focused_state := {"roulette_bets": bets.duplicate(true), "selected_chip": 5, "roulette_undo_stack": [], "roulette_focused_stack_id": "outside:red"}
	var focused_remove: Dictionary = game._remove_bet_chip_command(-1, focused_state, table)
	var focused_remaining: Array = (focused_remove.get("ui_state", {}) as Dictionary).get("roulette_bets", [])
	if focused_remaining.size() != 2 or int((focused_remaining[1] as Dictionary).get("stake", 0)) != 5 or str((focused_remaining[0] as Dictionary).get("id", "")) != "straight:17":
		failures.append("Roulette controller remove did not bind to the exact focused named stack.")
	var unfocused_state := {"roulette_bets": bets.duplicate(true), "selected_chip": 5, "roulette_undo_stack": []}
	var unfocused_before := JSON.stringify(unfocused_state)
	var unfocused_remove: Dictionary = game._remove_bet_chip_command(-1, unfocused_state, table)
	if JSON.stringify((unfocused_remove.get("ui_state", {}) as Dictionary).get("roulette_bets", [])) != JSON.stringify(bets) or unfocused_before != JSON.stringify(unfocused_state):
		failures.append("Roulette controller remove without a named focus mutated an implicit last stack.")
	var roulette_probe := RitualDrawProbe.new()
	game._draw_roulette_ritual_status(roulette_probe, {"ritual_phase": "no_more_bets", "ritual_energy": {"tier": "packed"}, "ritual_actors": [{"behavior": "waving_off_bets"}], "ritual_scene_objects": [{"id": "roulette.ball", "visual_state": "travel"}]})
	if roulette_probe.labels.is_empty() or (roulette_probe.labels[0] as String).find("WAVING OFF BETS") < 0 or (roulette_probe.labels[0] as String).find("PACKED") < 0:
		failures.append("Roulette renderer did not visibly consume actor/object/energy ritual state.")
	var phase_run = RunStateScript.new()
	phase_run.start_new("GAME06-3-ROULETTE-PHASE-RESTORE")
	var phase_environment := {"id": "game06_3_roulette_restore", "archetype_id": "grand_casino", "kind": "boss", "game_ids": ["roulette"], "economic_profile": {"stake_floor": 5, "stake_ceiling": 1000}, "security_profile": {"strictness": "high"}}
	var phase_table: Dictionary = game.generate_environment_state(phase_run, phase_environment, phase_run.create_rng("game06_3_roulette_table"))
	phase_table["last_result"] = {"spin_id": "restore_spin", "payout_animation_id": "restore_pay", "resolved_at_msec": 10000, "winning_number": "17", "winning_color": "black", "bets": bets.duplicate(true), "bet_results": settled.duplicate(true), "trajectory": []}
	phase_environment["game_states"] = {"roulette": phase_table}
	phase_run.current_environment = phase_environment
	var restored_phase_run = RunStateScript.new()
	restored_phase_run.from_dict(phase_run.to_dict())
	for phase_case_value in [{"time": 9999, "phase": "betting"}, {"time": 10000, "phase": "no_more_bets"}, {"time": 10700, "phase": "spin"}, {"time": 15000, "phase": "ball_settle"}, {"time": 15700, "phase": "croupier_settlement"}]:
		var restore_case: Dictionary = phase_case_value
		var phase_ui := {"surface_time_msec": int(restore_case.get("time", 0))}
		var live_surface: Dictionary = game.surface_state(phase_run, phase_run.current_environment, phase_ui)
		var restored_surface: Dictionary = game.surface_state(restored_phase_run, restored_phase_run.current_environment, phase_ui)
		if JSON.stringify(live_surface) != JSON.stringify(restored_surface) or str(live_surface.get("ritual_phase", "")) != str(restore_case.get("phase", "")):
			failures.append("Roulette save/revisit diverged at %s boundary." % str(restore_case.get("phase", "")))
	_check_roulette_neighbor_isolation(game)


func _check_baccarat() -> void:
	var game = BaccaratGameScript.new()
	_setup_game_definition(game, "baccarat")
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
	var squeeze_events: Array = game._baccarat_deal_events([{"rank": 2, "suit": "clubs"}, {"rank": 3, "suit": "hearts"}], [{"rank": 2, "suit": "diamonds"}, {"rank": 2, "suit": "clubs"}], false, false, false, "player")
	var authored_squeeze: Dictionary = game._authored_squeeze_event({"deal_animation_events": squeeze_events})
	var target_card_found := false
	for squeeze_event_value in squeeze_events:
		var squeeze_event_row: Dictionary = squeeze_event_value
		if str(squeeze_event_row.get("type", "")) == "card" and str(squeeze_event_row.get("zone", "")) == str(authored_squeeze.get("target_zone", "")) and int(squeeze_event_row.get("zone_card_slot", -1)) == int(authored_squeeze.get("card_slot", -2)):
			target_card_found = true
	if authored_squeeze.is_empty() or not target_card_found:
		failures.append("Baccarat authored squeeze cannot identify the exact face-down card before its reveal window.")
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
	var pointer_environment := {"game_states": {"baccarat": {"schema": "baccarat_table_state", "last_result": squeeze_result.duplicate(true)}}}
	var pointer_before := JSON.stringify(pointer_environment)
	var pointer_begin: Dictionary = game.surface_pointer_command("baccarat_squeeze", 0, "begin", Vector2(390, 200), {"surface_time_msec": 10000}, run_state, pointer_environment)
	var pointer_move: Dictionary = game.surface_pointer_command("baccarat_squeeze", 0, "move", Vector2(490, 200), pointer_begin.get("ui_state", {}), run_state, pointer_environment)
	var pointer_end: Dictionary = game.surface_pointer_command("baccarat_squeeze", 0, "end", Vector2(490, 200), pointer_move.get("ui_state", {}), run_state, pointer_environment)
	if float((pointer_end.get("ui_state", {}) as Dictionary).get("baccarat_squeeze_progress", 0.0)) != 1.0 or JSON.stringify(pointer_environment) != pointer_before:
		failures.append("Baccarat pointer squeeze did not complete a bounded reveal without changing the authored hand.")
	var late_pointer: Dictionary = game.surface_pointer_command("baccarat_squeeze", 0, "begin", Vector2(390, 200), {"surface_time_msec": 14000}, run_state, pointer_environment)
	if (late_pointer.get("ui_state", {}) as Dictionary).has("baccarat_squeeze_origin") or JSON.stringify(pointer_environment) != pointer_before:
		failures.append("Baccarat accepted late squeeze input after the reveal window or changed authority.")
	var baccarat_probe := RitualDrawProbe.new()
	game._draw_baccarat_ritual_status(baccarat_probe, {"ritual_phase": "squeeze_reveal", "ritual_energy": {"tier": "busy"}, "ritual_actors": [{"behavior": "offering_squeeze"}], "ritual_scene_objects": [{"id": "baccarat.shoe", "visual_state": "in_use"}]})
	if baccarat_probe.labels.is_empty() or (baccarat_probe.labels[0] as String).find("OFFERING SQUEEZE") < 0 or (baccarat_probe.labels[0] as String).find("BUSY") < 0:
		failures.append("Baccarat renderer did not visibly consume actor/object/energy ritual state.")
	game._draw_squeeze_badge(baccarat_probe, squeeze_result.get("animation_events", [])[0], {"baccarat_squeeze_progress": 0.5, "baccarat_squeeze_available": true})
	if baccarat_probe.hits.is_empty() or not bool((baccarat_probe.hits[0] as Dictionary).get("keyboard_hold", false)) or not bool((baccarat_probe.hits[0] as Dictionary).get("drag", false)):
		failures.append("Baccarat squeeze renderer did not register the shared pointer/keyboard/controller hold route.")
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
	for baccarat_case_value in [{"time": 8199, "phase": "betting"}, {"time": 8200, "phase": "shoe"}, {"time": 8700, "phase": "deal"}, {"time": 10100, "phase": "squeeze_reveal"}, {"time": 10700, "phase": "third_card_rule"}, {"time": 11900, "phase": "settlement"}]:
		var boundary_case: Dictionary = baccarat_case_value
		var boundary_ui := {"surface_time_msec": int(boundary_case.get("time", 0))}
		var boundary_live: Dictionary = game.surface_state(run_state, run_state.current_environment, boundary_ui)
		var boundary_restored: Dictionary = game.surface_state(restored_state, restored_state.current_environment, boundary_ui)
		if JSON.stringify(boundary_live) != JSON.stringify(boundary_restored) or str(boundary_live.get("ritual_phase", "")) != str(boundary_case.get("phase", "")):
			failures.append("Baccarat save/revisit diverged at %s boundary." % str(boundary_case.get("phase", "")))
	_check_baccarat_neighbor_isolation(game)


func _check_roulette_neighbor_isolation(game) -> void:
	for seed_index in range(10):
		var run_a = RunStateScript.new()
		run_a.start_new("GAME06-3-ROULETTE-NEIGHBOR-%d" % seed_index)
		run_a.bankroll = 1000
		run_a.grand_casino_chips = 1000
		var environment := {"id": "roulette_neighbor_%d" % seed_index, "archetype_id": "grand_casino", "kind": "boss", "game_ids": ["roulette"], "economic_profile": {"stake_floor": 5, "stake_ceiling": 1000}, "security_profile": {"strictness": "high"}}
		var table: Dictionary = game.generate_environment_state(run_a, environment, run_a.create_rng("table"))
		environment["game_states"] = {"roulette": table}
		run_a.current_environment = environment
		var run_b = RunStateScript.new()
		run_b.from_dict(run_a.to_dict())
		var isolated_table: Dictionary = ((run_b.current_environment.get("game_states", {}) as Dictionary).get("roulette", {}) as Dictionary)
		isolated_table["patrons"] = []
		var isolated_states: Dictionary = run_b.current_environment.get("game_states", {})
		isolated_states["roulette"] = isolated_table
		run_b.current_environment["game_states"] = isolated_states
		var target: Dictionary = {}
		for target_value in game._roulette_bet_targets_cached(table):
			if str((target_value as Dictionary).get("id", "")) == "straight:17":
				target = (target_value as Dictionary).duplicate(true)
				break
		target["stake"] = 5
		var result_a: Dictionary = game.resolve_with_context("spin_roulette", 5, run_a, run_a.current_environment, run_a.create_rng("spin"), {"roulette_bets": [target]})
		var result_b: Dictionary = game.resolve_with_context("spin_roulette", 5, run_b, run_b.current_environment, run_b.create_rng("spin"), {"roulette_bets": [target]})
		if str(result_a.get("winning_number", "")) != str(result_b.get("winning_number", "")) or int(result_a.get("bankroll_delta", 0)) != int(result_b.get("bankroll_delta", 0)):
			failures.append("Roulette neighbors changed player authority at seed %d." % seed_index)


func _check_baccarat_neighbor_isolation(game) -> void:
	for seed_index in range(10):
		var run_a = RunStateScript.new()
		run_a.start_new("GAME06-3-BACCARAT-NEIGHBOR-%d" % seed_index)
		run_a.bankroll = 1000
		run_a.grand_casino_chips = 1000
		var environment := {"id": "baccarat_neighbor_%d" % seed_index, "archetype_id": "grand_casino", "kind": "boss", "game_ids": ["baccarat"], "economic_profile": {"stake_floor": 5, "stake_ceiling": 1000}, "security_profile": {"strictness": "high"}}
		var table: Dictionary = game.generate_environment_state(run_a, environment, run_a.create_rng("table"))
		environment["game_states"] = {"baccarat": table}
		run_a.current_environment = environment
		var run_b = RunStateScript.new()
		run_b.from_dict(run_a.to_dict())
		var isolated_table: Dictionary = ((run_b.current_environment.get("game_states", {}) as Dictionary).get("baccarat", {}) as Dictionary)
		isolated_table["patrons"] = []
		var isolated_states: Dictionary = run_b.current_environment.get("game_states", {})
		isolated_states["baccarat"] = isolated_table
		run_b.current_environment["game_states"] = isolated_states
		var result_a: Dictionary = game.resolve_with_context("deal_baccarat", 20, run_a, run_a.current_environment, run_a.create_rng("deal"), {"baccarat_bets": {"player": 20}})
		var result_b: Dictionary = game.resolve_with_context("deal_baccarat", 20, run_b, run_b.current_environment, run_b.create_rng("deal"), {"baccarat_bets": {"player": 20}})
		if JSON.stringify(result_a.get("hand", {})) != JSON.stringify(result_b.get("hand", {})) or int(result_a.get("bankroll_delta", 0)) != int(result_b.get("bankroll_delta", 0)):
			failures.append("Baccarat neighbors changed player authority at seed %d." % seed_index)


func _check_exact_settlement_accounting() -> void:
	var baccarat = BaccaratGameScript.new()
	_setup_game_definition(baccarat, "baccarat")
	var banker_win: Dictionary = baccarat._settle_baccarat_bets(
		{"banker": 20},
		{"winner": "banker", "player_pair": false, "banker_pair": false},
		{"banker_payout": 1, "banker_commission_rate": 0.05, "banker_commission_rounding": "ceil_whole_unit"}
	)
	var banker_row: Dictionary = (banker_win.get("bet_results", []) as Array)[0]
	if int(banker_row.get("stake_return", -1)) != 20 or int(banker_row.get("gross_return", -1)) != 39 or int(banker_row.get("commission", -1)) != 1 or int(banker_row.get("net", -999)) != 19 or int(banker_win.get("bankroll_delta", -999)) != 19:
		failures.append("Baccarat banker settlement did not return one stake plus profit minus explicit commission.")
	var push: Dictionary = baccarat._settle_baccarat_bets(
		{"player": 20},
		{"winner": "tie", "player_pair": false, "banker_pair": false},
		{}
	)
	var push_row: Dictionary = (push.get("bet_results", []) as Array)[0]
	if int(push_row.get("stake_return", -1)) != 20 or int(push_row.get("gross_return", -1)) != 20 or int(push_row.get("net", -999)) != 0:
		failures.append("Baccarat push did not return the stake exactly once.")
	var loss: Dictionary = baccarat._settle_baccarat_bets(
		{"player": 20},
		{"winner": "banker", "player_pair": false, "banker_pair": false},
		{}
	)
	var loss_row: Dictionary = (loss.get("bet_results", []) as Array)[0]
	if int(loss_row.get("stake_return", -1)) != 0 or int(loss_row.get("gross_return", -1)) != 0 or int(loss_row.get("net", -999)) != -20:
		failures.append("Baccarat loss did not debit exactly one stake.")

	var roulette = RouletteGameScript.new()
	_setup_game_definition(roulette, "roulette")
	var roulette_rows: Array = roulette._settle_roulette_bets("17", [
		{"id": "straight:17", "label": "17", "family": "inside", "numbers": ["17"], "stake": 5, "payout": 35},
		{"id": "outside:red", "label": "Red", "family": "outside", "numbers": ["1"], "stake": 10, "payout": 1},
	], {"rules": {"la_partage": false}})
	var straight: Dictionary = roulette_rows[0]
	var outside_loss: Dictionary = roulette_rows[1]
	if int(straight.get("stake_return", -1)) != 5 or int(straight.get("payout_profit", -1)) != 175 or int(straight.get("gross_return", -1)) != 180 or int(straight.get("bankroll_delta", -999)) != 175:
		failures.append("Roulette win did not return one stake in addition to its to-one profit.")
	if int(outside_loss.get("gross_return", -1)) != 0 or int(outside_loss.get("bankroll_delta", -999)) != -10:
		failures.append("Roulette multi-bet loss did not debit exactly its own stake.")
	if int(straight.get("bankroll_delta", 0)) + int(outside_loss.get("bankroll_delta", 0)) != 165:
		failures.append("Roulette multi-bet settlement did not conserve the exact combined net.")
	var partage_rows: Array = roulette._settle_roulette_bets("0", [
		{"id": "outside:red", "label": "Red", "family": "outside", "numbers": ["1"], "stake": 5, "payout": 1},
	], {"rules": {"la_partage": true}})
	var partage: Dictionary = partage_rows[0]
	if int(partage.get("stake_return", -1)) != 2 or int(partage.get("gross_return", -1)) != 2 or int(partage.get("bankroll_delta", -999)) != -3:
		failures.append("Roulette la partage did not return the retained half and charge only the rounded house half.")


func _check_authoritative_host_matrix() -> void:
	_check_authoritative_game("roulette", RouletteGameScript.new(), "spin_roulette", 15, {
		"roulette_bets": [
			{"id": "straight:17", "type": "straight", "label": "17", "family": "inside", "numbers": ["17"], "stake": 5, "payout": 35},
			{"id": "outside:red", "type": "outside", "label": "Red", "family": "outside", "numbers": ["1", "3", "5", "7", "9", "12", "14", "16", "18", "19", "21", "23", "25", "27", "30", "32", "34", "36"], "stake": 10, "payout": 1},
		],
	})
	_check_authoritative_game("baccarat", BaccaratGameScript.new(), "deal_baccarat", 20, {"baccarat_bets": {"banker": 20}})


func _check_authoritative_game(game_id: String, game, action_id: String, stake: int, session: Dictionary) -> void:
	_setup_game_definition(game, game_id)
	var run = RunStateScript.new()
	run.start_new("GAME06-3-HOST-%s" % game_id.to_upper())
	run.bankroll = 1000
	run.grand_casino_chips = 100
	var environment := {
		"id": "game06_3_host_%s" % game_id,
		"archetype_id": "grand_casino",
		"kind": "boss",
		"game_ids": [game_id],
		"economic_profile": {"stake_floor": 5, "stake_ceiling": 1000},
		"security_profile": {"strictness": "high"},
	}
	run.current_environment = environment
	var table: Dictionary = game.generate_environment_state(run, environment, run.create_rng("game06_3_host_table"))
	var game_states := {}
	game_states[game_id] = table
	environment["game_states"] = game_states
	run.current_environment = environment
	_seed_host_session(game, run, session)

	var snapshot := run.to_save_snapshot()
	var zero_cost_actions := ["unknown_action", "crew_play:chip_dump"]
	if game_id == "roulette":
		zero_cost_actions.append("read_wheel_bias")
	else:
		zero_cost_actions.append("read_baccarat_shoe")
		zero_cost_actions.append("edge_sort")
	for zero_action_value in zero_cost_actions:
		var zero_action := str(zero_action_value)
		var zero_proposal: Dictionary = game.call("_table_game_wager_cost_proposal", zero_action, 999, snapshot, session)
		if int(zero_proposal.get("cost", -1)) != 0:
			failures.append("%s wager proposal charged the non-wager action %s." % [game_id.capitalize(), zero_action])
	var wager_proposal: Dictionary = game.call("_table_game_wager_cost_proposal", action_id, stake, snapshot, session)
	if int(wager_proposal.get("cost", -1)) != stake:
		failures.append("%s authoritative wager proposal did not lease the exact table stake." % game_id.capitalize())

	var total_before := run.grand_casino_total_money()
	var rng_before := run.rng_state
	var result := _host_resolve(game, run, action_id, stake)
	if not bool(result.get("ok", false)) or not bool(result.get("blackjack_host_committed", false)) or not bool(result.get("table_game_authoritative", false)):
		failures.append("%s did not commit through the authentic Foundation host." % game_id.capitalize())
		return
	var delivery_value: Variant = result.get("blackjack_host_delivery", null)
	var receipt_value: Variant = result.get("blackjack_host_apply_receipt", null)
	if typeof(delivery_value) != TYPE_DICTIONARY or typeof(receipt_value) != TYPE_DICTIONARY:
		failures.append("%s authentic host result did not carry its delivery and apply receipt." % game_id.capitalize())
		return
	var delivery: Dictionary = delivery_value
	var receipt: Dictionary = receipt_value
	var expected_binding := "%s:%s:%s" % [game_id, str(environment.get("id", "")), str(environment.get("archetype_id", ""))]
	if str(receipt.get("table_binding", "")) != expected_binding or str(receipt.get("request_key", "")) != str(delivery.get("request_key", "")):
		failures.append("%s host receipt was not bound to the exact game/table/request." % game_id.capitalize())
	var net_delta := int(result.get("chips_delta", result.get("cash_equivalent_delta", result.get("bankroll_delta", 0))))
	if run.grand_casino_total_money() != total_before + net_delta:
		failures.append("%s host settlement did not conserve money across funding and apply." % game_id.capitalize())
	if run.rng_state == rng_before:
		failures.append("%s first authentic host settlement did not advance canonical RNG." % game_id.capitalize())
	var settled_table: Dictionary = game.call("_table_state_preview", run, run.current_environment)
	var last_result: Dictionary = settled_table.get("last_result", {}) if typeof(settled_table.get("last_result", {})) == TYPE_DICTIONARY else {}
	var resolved_at_msec := int(last_result.get("resolved_at_msec", 0))
	var predicate_host = _host(game, run, stake)
	if not game.has_method("_table_game_host_needs_auto_tick") \
			or bool(predicate_host.call("_blackjack_host_needs_auto_tick", resolved_at_msec + 1)) \
			or not bool(predicate_host.call("_blackjack_host_needs_auto_tick", resolved_at_msec + 100000)):
		failures.append("%s sealed-host auto predicate did not remain quiet during ceremony and become due afterward." % game_id.capitalize())
	predicate_host.free()

	var committed_snapshot := RuntimeScript.canonical_json(run.to_save_snapshot())
	var replay := _host_resolve(game, run, action_id, stake, delivery)
	var replay_canonical := replay.duplicate(true)
	replay_canonical.erase("blackjack_host_replay")
	if not replay.has("blackjack_host_replay") or RuntimeScript.canonical_json(replay_canonical) != RuntimeScript.canonical_json(result):
		failures.append("%s replay did not return the exact cached authoritative response." % game_id.capitalize())
	if RuntimeScript.canonical_json(run.to_save_snapshot()) != committed_snapshot:
		failures.append("%s replay repeated RNG, money, story, or another one-shot effect." % game_id.capitalize())

	var hostile_delivery := delivery.duplicate(true)
	hostile_delivery["stake"] = stake + 1
	var before_hostile := RuntimeScript.canonical_json(run.to_save_snapshot())
	var hostile := _host_resolve(game, run, action_id, stake + 1, hostile_delivery)
	if bool(hostile.get("ok", true)) or str(hostile.get("error_code", "")) not in ["receipt_content_conflict", "stale_boundary"]:
		failures.append("%s host did not reject hostile or stale delivery content." % game_id.capitalize())
	if RuntimeScript.canonical_json(run.to_save_snapshot()) != before_hostile:
		failures.append("%s hostile delivery rejection changed canonical state." % game_id.capitalize())

	_check_pending_retry_cancel(game_id, game, action_id, stake, session)


func _check_pending_retry_cancel(game_id: String, game, action_id: String, stake: int, session: Dictionary) -> void:
	var run = RunStateScript.new()
	run.start_new("GAME06-3-PENDING-%s" % game_id.to_upper())
	run.bankroll = 500
	run.grand_casino_chips = 100
	var environment := {"id": "game06_3_pending_%s" % game_id, "archetype_id": "grand_casino", "kind": "boss", "game_ids": [game_id], "economic_profile": {"stake_floor": 5, "stake_ceiling": 1000}, "security_profile": {"strictness": "high"}}
	run.current_environment = environment
	var game_states := {}
	game_states[game_id] = game.generate_environment_state(run, environment, run.create_rng("pending_table"))
	environment["game_states"] = game_states
	run.current_environment = environment
	_seed_host_session(game, run, session)
	var host = _host(game, run, stake)
	var money_before := run.grand_casino_total_money()
	var rng_before := run.rng_state
	var prepared: Dictionary = host.call("_blackjack_host_prepare_delivery", action_id, stake, {})
	var delivery: Dictionary = prepared.get("delivery", {})
	var retry: Dictionary = host.call("_blackjack_host_surface_intent", "table_game_retry_pending", 0, false, run.simulation_time_msec())
	if delivery.is_empty() or not bool(retry.get("handled", false)) or RuntimeScript.canonical_json(retry.get("_blackjack_host_delivery", {})) != RuntimeScript.canonical_json(delivery):
		failures.append("%s pending retry did not preserve the exact sealed delivery." % game_id.capitalize())
	var cancelled: Dictionary = host.call("_blackjack_host_surface_intent", "table_game_cancel_pending", 0, false, run.simulation_time_msec())
	if not bool(cancelled.get("handled", false)):
		failures.append("%s pending cancellation was not accepted by the authentic host." % game_id.capitalize())
	var ledger := _host_ledger(game, run)
	if not (ledger.get("pending_delivery", {}) as Dictionary).is_empty() or run.grand_casino_total_money() != money_before or run.rng_state != rng_before:
		failures.append("%s pending retry/cancel consumed money, RNG, or left a delivery stranded." % game_id.capitalize())
	host.free()


func _host_resolve(game, run, action_id: String, stake: int, delivery: Dictionary = {}) -> Dictionary:
	var host = _host(game, run, stake)
	var result: Dictionary = host.call("_blackjack_host_resolve_intent", action_id, stake, delivery)
	host.free()
	return result


func _host(game, run, stake: int):
	var host = FoundationMainScript.new()
	host.set("current_game", game)
	var cache := {}
	cache[game.get_id()] = game
	host.set("game_module_cache", cache)
	host.set("run_state", run)
	host.set("selected_stake", stake)
	return host


func _seed_host_session(game, run, session: Dictionary) -> void:
	var table: Dictionary = game.call("_table_state", run, run.current_environment)
	var binding := "%s:%s:%s" % [game.get_id(), str(run.current_environment.get("id", "unknown")), str(run.current_environment.get("archetype_id", "unknown"))]
	var ledger := BlackjackActionAuthorityScript.validate_persisted_ledger(table.get(BlackjackActionAuthorityScript.LEDGER_KEY, {}), binding, run.blackjack_authority_checkpoint_fingerprint())
	if ledger.is_empty():
		ledger = BlackjackActionAuthorityScript.default_ledger(binding, run.blackjack_authority_checkpoint_fingerprint())
	table[BlackjackActionAuthorityScript.LEDGER_KEY] = BlackjackActionAuthorityScript.stage_session(ledger, session)
	game.call("_update_environment_table", run.current_environment, table)


func _host_ledger(game, run) -> Dictionary:
	var table: Dictionary = game.call("_table_state_preview", run, run.current_environment)
	var binding := "%s:%s:%s" % [game.get_id(), str(run.current_environment.get("id", "unknown")), str(run.current_environment.get("archetype_id", "unknown"))]
	return BlackjackActionAuthorityScript.validate_persisted_ledger(table.get(BlackjackActionAuthorityScript.LEDGER_KEY, {}), binding, run.blackjack_authority_checkpoint_fingerprint())


func _setup_game_definition(game, game_id: String) -> void:
	var games_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/games/games.json"))
	for definition_value in games_value if typeof(games_value) == TYPE_ARRAY else []:
		if typeof(definition_value) == TYPE_DICTIONARY and str((definition_value as Dictionary).get("id", "")) == game_id:
			game.setup(definition_value as Dictionary)
			return
