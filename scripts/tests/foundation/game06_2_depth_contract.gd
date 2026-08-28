extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

var failures: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	var definition := library.game("blackjack")
	var module_script: Script = load(str(definition.get("module_path", "")))
	var game: GameModule = module_script.new()
	game.setup(definition, library)
	_check_contract(game)
	_check_phase_projection(game)
	_check_itemized_accounting(game)
	_check_gesture_rejections_and_equivalence(game)
	_check_ten_seed_projection_isolation(game)
	if failures.is_empty():
		print("game06_2_depth_contract: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(str(failure))
	print("game06_2_depth_contract: FAIL (%d)" % failures.size())
	quit(1)


func _check_contract(game: GameModule) -> void:
	var contract: Dictionary = game.call("blackjack_ritual_contract")
	_check(str(contract.get("contract", "")) == "game_ritual/1", "Blackjack did not declare the accepted ritual contract version.")
	_check(str(contract.get("ritual_id", "")) == "blackjack.standard_table", "Blackjack ritual id changed.")
	_check(contract.get("phases", []) == ["wagering", "initial_deal", "player_turn", "dealer_procedure", "settlement"], "Blackjack phase vocabulary is incomplete or reordered.")
	for action in ["place", "correct", "remove_one", "undo", "clear", "repeat", "rebet", "confirm"]:
		_check((contract.get("commitment_actions", []) as Array).has(action), "Missing staged commitment action: %s." % action)
	for total in ["available_funds", "pending_total", "at_risk_total", "returned_stake", "payout", "net_change"]:
		_check((contract.get("readable_totals", []) as Array).has(total), "Missing readable total: %s." % total)
	var gestures: Array = contract.get("gestures", []) if typeof(contract.get("gestures", [])) == TYPE_ARRAY else []
	_check(gestures.size() == 4, "Blackjack must declare place, cut, wave, and tap gesture packages.")
	for gesture_value in gestures:
		var gesture: Dictionary = gesture_value if typeof(gesture_value) == TYPE_DICTIONARY else {}
		_check((gesture.get("rejection_effects", []) as Array).is_empty(), "Gesture rejection gained an authoritative effect: %s." % str(gesture.get("id", "unknown")))
		var equivalents: Dictionary = gesture.get("equivalents", {}) if typeof(gesture.get("equivalents", {})) == TYPE_DICTIONARY else {}
		for input_kind in ["keyboard", "controller", "reduced_motion"]:
			_check(typeof(equivalents.get(input_kind, null)) == TYPE_DICTIONARY, "Gesture %s lost its %s equivalent." % [str(gesture.get("id", "unknown")), input_kind])
	var persistence: Dictionary = contract.get("persistence", {}) if typeof(contract.get("persistence", {})) == TYPE_DICTIONARY else {}
	_check(persistence.get("save_boundaries", []) == ["wagering", "initial_deal", "player_turn", "dealer_procedure", "settlement"], "Not every Blackjack action phase is a declared save boundary.")


func _check_phase_projection(game: GameModule) -> void:
	var table := {"deck_count": 2, "cut_card_remaining": 28, "last_result": {}}
	var spec := {"selected_stake": 5, "shoe_remaining": 104, "patrons": [], "side_bets_active": [], "side_bet_stakes": {}, "can_deal": true}
	_check(_phase(game, table, {}, spec, false, false) == "wagering", "Empty Blackjack session did not project wagering.")
	_check(_phase(game, table, {}, spec, true, false) == "initial_deal", "Opening card staging did not project initial_deal.")
	var live := {"selected_stake": 5, "player_hands": [{"cards": [{"rank": 9, "suit": 0}, {"rank": 7, "suit": 1}], "stood": false, "wager_multiplier": 1}], "dealer_cards": [{"rank": 8, "suit": 2}, {"rank": 6, "suit": 3}], "active_hand_index": 0, "wager_debited": 5}
	_check(_phase(game, table, live, spec, false, false) == "player_turn", "Live hand did not project player_turn.")
	var complete := live.duplicate(true)
	(complete.get("player_hands", []) as Array)[0]["stood"] = true
	_check(_phase(game, table, complete, spec, false, false) == "dealer_procedure", "Finished player decisions did not project dealer_procedure.")
	_check(_phase(game, table, {}, spec, false, true) == "settlement", "Payout staging did not project settlement.")


func _phase(game: GameModule, table: Dictionary, session: Dictionary, spec: Dictionary, deal_active: bool, payout_active: bool) -> String:
	var projection: Dictionary = game.call("_blackjack_ritual_projection", null, {}, table.duplicate(true), session.duplicate(true), spec.duplicate(true), deal_active, payout_active)
	return str(projection.get("phase_id", ""))


func _check_itemized_accounting(game: GameModule) -> void:
	var last_result := {
		"bankroll_delta": 18,
		"hand_results": [
			{"outcome": "blackjack", "wager": 10, "bankroll_delta": 15},
			{"outcome": "push", "wager": 10, "bankroll_delta": 0},
			{"outcome": "surrender", "wager": 10, "bankroll_delta": -5},
			{"outcome": "bust", "wager": 10, "bankroll_delta": -10},
		],
		"side_bet_results": [{"id": "perfect_pairs", "stake": 2, "bankroll_delta": 18, "won": true, "detail": "perfect pair"}],
	}
	var resolutions: Array = game.call("_blackjack_item_resolutions", last_result)
	_check(resolutions.size() == 5, "Settlement projection was not itemized per hand and side wager.")
	var totals: Dictionary = game.call("_blackjack_settlement_totals", resolutions, last_result)
	_check(int(totals.get("returned_stake", -1)) == 27, "Returned-stake accounting did not distinguish blackjack, push, surrender, bust, and side win.")
	_check(int(totals.get("payout", -1)) == 33, "Profit/payout accounting did not remain separate from returned stake.")
	for resolution_value in resolutions:
		var resolution: Dictionary = resolution_value if typeof(resolution_value) == TYPE_DICTIONARY else {}
		_check(not str(resolution.get("reason", "")).is_empty(), "An itemized wager resolution has no public reason.")


func _check_gesture_rejections_and_equivalence(game: GameModule) -> void:
	var fixture := _fixture(game, "GAME06-2-GESTURES", 0)
	var run: RunState = fixture.run
	var environment: Dictionary = fixture.environment
	var bankroll_before := run.wager_balance_for_game("blackjack", environment)
	var ui := {"selected_stake": 5, "surface_time_msec": 10000}
	var begin: Dictionary = game.surface_pointer_command("blackjack_cut_gesture", 0, "begin", Vector2(720, 120), ui, run, environment)
	var rejected: Dictionary = game.surface_pointer_command("blackjack_cut_gesture", 0, "end", Vector2(620, 220), begin.get("ui_state", {}), run, environment)
	_check(str(rejected.get("action_id", "")).is_empty(), "Incomplete cut gesture produced an authoritative action.")
	_check(run.wager_balance_for_game("blackjack", environment) == bankroll_before, "Incomplete cut gesture charged bankroll.")
	var drag_begin: Dictionary = game.surface_pointer_command("blackjack_wager_place_gesture", 1, "begin", Vector2(75, 398), ui, run, environment)
	var placed: Dictionary = game.surface_pointer_command("blackjack_wager_place_gesture", 1, "end", Vector2(452, 304), drag_begin.get("ui_state", {}), run, environment)
	_check(int(placed.get("set_stake", 0)) > 5, "Chip drag did not reach the same staged-wager handler as the button path.")
	_check(run.wager_balance_for_game("blackjack", environment) == bankroll_before, "Staging a dragged chip charged before confirmation.")
	var cut_begin: Dictionary = game.surface_pointer_command("blackjack_cut_gesture", 0, "begin", Vector2(720, 120), placed.get("ui_state", {}), run, environment)
	var cut: Dictionary = game.surface_pointer_command("blackjack_cut_gesture", 0, "end", Vector2(720, 120), cut_begin.get("ui_state", {}), run, environment)
	_check(str(cut.get("action_id", "")) == "blackjack_place_bet" and bool(cut.get("direct_resolve", false)), "Cut gesture did not reach the same confirm/deal authority as keyboard/controller action.")
	_check(run.wager_balance_for_game("blackjack", environment) == bankroll_before, "Cut gesture mutated bankroll before the authoritative resolve boundary.")


func _check_ten_seed_projection_isolation(game: GameModule) -> void:
	for seed_index in range(10):
		var fixture := _fixture(game, "GAME06-2-SEED-%02d" % seed_index, seed_index)
		var run: RunState = fixture.run
		var environment: Dictionary = fixture.environment
		var table_before: Dictionary = (environment.get("game_states", {}) as Dictionary).get("blackjack", {}).duplicate(true)
		var state := game.surface_state(run, environment, {"selected_stake": 5, "surface_time_msec": 12000 + seed_index})
		var projection: Dictionary = state.get("ritual_projection", {}) if typeof(state.get("ritual_projection", {})) == TYPE_DICTIONARY else {}
		for actor_value in projection.get("actors", []):
			if typeof(actor_value) == TYPE_DICTIONARY and str((actor_value as Dictionary).get("role", "")) == "neighbour":
				_check(str((actor_value as Dictionary).get("authority", "")) == "none", "Seed %d projected a neighbour with outcome authority." % seed_index)
		var table_after: Dictionary = (environment.get("game_states", {}) as Dictionary).get("blackjack", {})
		_check(table_before == table_after, "Seed %d ritual projection mutated authoritative table state." % seed_index)


func _fixture(game: GameModule, seed_text: String, seed_index: int) -> Dictionary:
	var run: RunState = RunStateScript.new()
	run.start_new(seed_text)
	run.change_bankroll(1000)
	var environment := {
		"id": "game06_2_room_%02d" % seed_index,
		"display_name": "Blackjack Contract Room",
		"depth": seed_index % 3,
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 100},
		"security_profile": {"strictness": "low"},
	}
	var table := game.generate_environment_state(run, environment, run.create_rng("table:%02d" % seed_index))
	environment["game_states"] = {"blackjack": table}
	run.current_environment = environment
	return {"run": run, "environment": environment}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
