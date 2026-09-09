extends SceneTree

# Deterministic production-path audit for Back-Room Hold'em. It exercises the
# same legal-action, bankroll, hidden-information, and surface-state seams used
# by the game screen, without reaching into private cards to choose actions.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const GameModuleScript := preload("res://scripts/core/game_module.gd")
const CrewPokerGameScript := preload("res://scripts/games/crew_draw_poker.gd")
const CrewPokerModelScript := preload("res://scripts/core/crew_poker_model.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const CrewPokerVisualSeedAuditScript := preload("res://tools/crew_poker_visual_seed_audit.gd")


func _init() -> void:
	var failures: Array[String] = []
	var library := ContentLibraryScript.new()
	library.load(true)
	if not library.validation_errors.is_empty():
		failures.append("Content library did not load.")
	var game: GameModule = CrewPokerGameScript.new()
	game.setup(library.game("crew_draw_poker"), library)
	var seed_audit := CrewPokerVisualSeedAuditScript.audit_pinned_seed(library)
	if not bool(seed_audit.get("passed", false)):
		failures.append("The production back-room seed route no longer reaches Hold'em cleanly.")
	_check_best_of_seven(failures)
	_check_side_pot(game, failures)
	var accepted := {}
	for seed in range(7001, 7065):
		var attempt := _play_hand(game, library, seed)
		if bool(attempt.get("complete", false)) and (attempt.get("streets", []) as Array).size() == 4:
			accepted = attempt
			break
	if accepted.is_empty():
		failures.append("No audited seed completed all four Hold'em streets.")
	else:
		if int(accepted.get("member_count", 0)) != 3:
			failures.append("The live table did not seat three opponents.")
		if not bool(accepted.get("fake_tell_kept_turn", false)):
			failures.append("Fake Tell consumed or displaced the player's betting turn.")
		if not bool(accepted.get("hidden_hole_cards", false)):
			failures.append("An opponent hole-card projection leaked before showdown.")
		if int(accepted.get("max_board_cards", 0)) != 5:
			failures.append("The shared board did not reach five visible cards.")
		if int(accepted.get("steps", 999)) > 80:
			failures.append("A single hand exceeded the bounded interaction budget.")
		for action_id in ["call", "raise", "all_in", "fake_tell", "fold"]:
			if not (accepted.get("player_action_set", []) as Array).has(action_id):
				failures.append("The player turn did not expose selectable %s control." % action_id)
		var repeat := _play_hand(game, library, int(accepted.get("seed", 0)))
		if JSON.stringify(accepted.get("signature", {})) != JSON.stringify(repeat.get("signature", {})):
			failures.append("The same seed and public actions did not replay deterministically.")
	var all_in_hand := {}
	for seed in range(7101, 7140):
		var attempt := _play_hand(game, library, seed, true)
		if bool(attempt.get("complete", false)) and bool(attempt.get("all_in_committed", false)):
			all_in_hand = attempt
			break
	if all_in_hand.is_empty():
		failures.append("The public all-in route did not settle cleanly.")
	var raised_hand := _play_hand(game, library, 7201, false, true)
	if not bool(raised_hand.get("complete", false)) or not bool(raised_hand.get("raise_committed", false)):
		failures.append("The public raise route did not resolve through a complete hand.")
	var report := {
		"passed": failures.is_empty(),
		"failures": failures,
		"accepted_hand": accepted,
		"all_in_hand": all_in_hand,
		"raised_hand": raised_hand,
	}
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)


func _check_best_of_seven(failures: Array[String]) -> void:
	var royal_board := [_card(10, 2), _card(11, 2), _card(12, 2), _card(13, 2), _card(14, 2)]
	var ace_flush := [_card(2, 0), _card(3, 1)]
	var nine_flush := [_card(9, 2), _card(9, 1)]
	var left := ace_flush.duplicate(true)
	left.append_array(royal_board)
	var right := nine_flush.duplicate(true)
	right.append_array(royal_board)
	if str(CrewPokerModelScript.evaluate_best_hand(left).get("label", "")) != "Straight Flush":
		failures.append("Best-of-seven evaluation missed the board straight flush.")
	if CrewPokerModelScript.compare_holdem(left, right) != 0:
		failures.append("A board-playing tie did not split equally.")


func _check_side_pot(game: GameModule, failures: Array[String]) -> void:
	var board := [_card(2, 0), _card(3, 1), _card(7, 2), _card(8, 3), _card(9, 0)]
	var player_cards := [_card(14, 0), _card(14, 1)]
	player_cards.append_array(board)
	var rook_cards := [_card(13, 0), _card(13, 1)]
	rook_cards.append_array(board)
	var lucky_cards := [_card(12, 0), _card(12, 1)]
	lucky_cards.append_array(board)
	var state := {"player_contribution": 10, "seats": [{"member_id": "crew_rook", "contribution": 20}, {"member_id": "crew_lucky", "contribution": 20}]}
	var settlement: Dictionary = game.call("_settle_holdem_pots", state, [{"id": "player", "cards": player_cards}, {"id": "crew_rook", "cards": rook_cards}, {"id": "crew_lucky", "cards": lucky_cards}])
	var awards: Dictionary = settlement.get("awards", {})
	if int(awards.get("player", 0)) != 30 or int(awards.get("crew_rook", 0)) != 20 or int(awards.get("crew_lucky", 0)) != 0:
		failures.append("Main-pot and side-pot settlement was incorrect: %s" % JSON.stringify(awards))


func _play_hand(game: GameModule, library, seed: int, force_all_in: bool = false, force_raise: bool = false) -> Dictionary:
	var run_state := RunStateScript.new()
	run_state.start_new("CREW-HOLDEM-%d" % seed)
	run_state.bankroll = 500
	for member_id in CrewStateModelScript.MEMBER_IDS:
		run_state.crew_add_trust(str(member_id), CrewStateModelScript.rank_threshold("made"), "holdem_audit")
	var environment := {
		"id": "crew_holdem_audit",
		"archetype_id": "small_underground_casino",
		"kind": "crew",
		"layer_id": "back_room",
		"crew_poker_turn_engine": "ordered_v1",
		"resident_member_ids": ["crew_mags", "crew_rook", "crew_lucky"],
		"game_ids": ["crew_draw_poker"],
		"game_states": {},
	}
	var setup_rng := RngStreamScript.new()
	setup_rng.configure(seed)
	var generated := game.generate_environment_state(run_state, environment, setup_rng)
	environment["game_states"] = {"crew_draw_poker": generated}
	run_state.current_environment = environment
	var first := _apply(game, run_state, "deal", {}, seed)
	if not bool(first.get("ok", false)):
		return {"seed": seed, "complete": false, "failure": "deal"}
	var streets: Array = []
	var hidden_ok := true
	var max_board := 0
	var fake_tell_done := false
	var fake_tell_kept_turn := false
	var all_in_committed := false
	var raise_committed := false
	var player_action_set: Array = []
	var steps := 1
	while steps < 80:
		var table: Dictionary = run_state.current_environment.get("game_states", {}).get("crew_draw_poker", {})
		var phase := str(table.get("phase", "idle"))
		if phase == "idle":
			break
		if ["preflop", "flop", "turn", "river"].has(phase) and not streets.has(phase):
			streets.append(phase)
		var surface := game.surface_state(run_state, run_state.current_environment, {"poker_tell_style": "strong"})
		max_board = maxi(max_board, (surface.get("community_cards", []) as Array).size())
		for seat_value in surface.get("seats", []):
			var seat: Dictionary = seat_value
			if not bool(seat.get("revealed", false)):
				var public_cards: Array = seat.get("cards", [])
				hidden_ok = hidden_ok and public_cards.size() == 2
				for card_value in public_cards:
					hidden_ok = hidden_ok and bool((card_value as Dictionary).get("hidden", false))
		var legal_ids: Array = []
		for action_value in game.legal_actions(run_state, run_state.current_environment):
			legal_ids.append(str((action_value as Dictionary).get("id", "")))
		if legal_ids.has("fake_tell") and player_action_set.is_empty():
			player_action_set = legal_ids.duplicate()
		var action_id := "observe" if legal_ids.has("observe") else "all_in" if force_all_in and not all_in_committed and legal_ids.has("all_in") else "raise" if force_raise and not raise_committed and legal_ids.has("raise") else "call"
		var ui := {}
		if legal_ids.has("fake_tell") and not fake_tell_done:
			var owner_before := str(table.get("turn_owner", ""))
			var fake := _apply(game, run_state, "fake_tell", {"poker_tell_style": "strong"}, seed + steps)
			var after_fake: Dictionary = run_state.current_environment.get("game_states", {}).get("crew_draw_poker", {})
			fake_tell_kept_turn = bool(fake.get("ok", false)) and str(after_fake.get("turn_owner", "")) == owner_before and str(after_fake.get("player_signal", {}).get("style", "")) == "strong"
			fake_tell_done = true
			steps += 1
			continue
		if not legal_ids.has(action_id):
			if legal_ids.has("check"):
				action_id = "check"
			elif legal_ids.has("fold"):
				action_id = "fold"
			else:
				return {"seed": seed, "complete": false, "failure": "no legal progression", "streets": streets}
		var result := _apply(game, run_state, action_id, ui, seed + steps)
		if not bool(result.get("ok", false)):
			return {"seed": seed, "complete": false, "failure": action_id, "streets": streets}
		if action_id == "all_in":
			all_in_committed = true
		elif action_id == "raise":
			raise_committed = true
		steps += 1
	var final_table: Dictionary = run_state.current_environment.get("game_states", {}).get("crew_draw_poker", {})
	return {
		"seed": seed,
		"complete": str(final_table.get("phase", "")) == "idle",
		"member_count": (generated.get("members", []) as Array).size(),
		"streets": streets,
		"max_board_cards": max_board,
		"hidden_hole_cards": hidden_ok,
		"fake_tell_kept_turn": fake_tell_kept_turn,
		"all_in_committed": all_in_committed,
		"raise_committed": raise_committed,
		"player_action_set": player_action_set,
		"steps": steps,
		"signature": {"last_result": final_table.get("last_result", {}), "history": final_table.get("action_history", []), "board": final_table.get("community_cards", []), "bankroll": run_state.bankroll},
	}


func _apply(game: GameModule, run_state: RunState, action_id: String, ui: Dictionary, seed: int) -> Dictionary:
	var rng := RngStreamScript.new()
	rng.configure(seed)
	var result := game.resolve_with_context(action_id, 2, run_state, run_state.current_environment, rng, ui)
	if bool(result.get("ok", false)):
		GameModuleScript.apply_result(run_state, result, rng)
	return result


func _card(rank: int, suit: int) -> Dictionary:
	return {"rank": rank, "suit": suit, "deck": 0}
