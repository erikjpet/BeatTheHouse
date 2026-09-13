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
		for error_value in library.validation_errors:
			failures.append("Content validation error: %s" % str(error_value))
	var game: GameModule = CrewPokerGameScript.new()
	game.setup(library.game("crew_draw_poker"), library)
	var seed_audit := CrewPokerVisualSeedAuditScript.audit_pinned_seed(library)
	if not bool(seed_audit.get("passed", false)):
		failures.append("The production back-room seed route no longer reaches Hold'em cleanly.")
	_check_best_of_seven(failures)
	_check_hand_categories(failures)
	_check_side_pot(game, failures)
	_check_no_limit_raise_rules(game, failures)
	_check_table_talk(game, library, failures)
	_check_six_hand_rotation_and_shoe(game, failures)
	_check_raise_round_closure(game, failures)
	_check_multiway_split(failures)
	_check_night_rituals(game, library, failures)
	_check_three_member_save(game, failures)
	_check_dealer_migration_and_roles(game, failures)
	var end_to_end := _check_two_hand_session_reload(game, failures)
	var performance := _check_performance(game, failures)
	var distributions := {
		"three_opponents": _distribution_metrics(game, library, 3, 8000),
		"five_opponents": _distribution_metrics(game, library, 5, 9000),
	}
	for distribution_value in distributions.values():
		var distribution: Dictionary = distribution_value
		if int(distribution.get("completed_hands", 0)) == 0 or not bool(distribution.get("chip_conservation_passed", false)):
			failures.append("The %d-opponent distribution audit produced no conserving completed hands." % int(distribution.get("opponents", 0)))
	var accepted := _play_hand(game, library, 7001)
	var four_street_seed_count := 0
	for seed in range(7001, 7065):
		var attempt := _play_hand(game, library, seed)
		if bool(attempt.get("complete", false)) and (attempt.get("streets", []) as Array).size() == 4:
			four_street_seed_count += 1
	if not bool(accepted.get("complete", false)) or (accepted.get("streets", []) as Array).size() != 4:
		failures.append("The first audited seed did not complete all four Hold'em streets.")
	else:
		if int(accepted.get("member_count", 0)) != CrewPokerGameScript.MAX_OPPONENT_SEATS:
			failures.append("The live table did not seat five opponents.")
		if not bool(accepted.get("fake_tell_kept_turn", false)):
			failures.append("Fake Tell consumed or displaced the player's betting turn.")
		if not bool(accepted.get("hidden_hole_cards", false)):
			failures.append("An opponent hole-card projection leaked before showdown.")
		if not bool(accepted.get("animation_hidden_information", false)):
			failures.append("A card-flight event leaked an opponent hole card or burn card.")
		for animation_kind in ["deal", "place", "sweep", "burn", "board", "showdown_flip", "payout"]:
			if not (accepted.get("animation_event_kinds", []) as Array).has(animation_kind):
				failures.append("The complete Hold'em hand did not emit %s presentation evidence." % animation_kind)
		if int(accepted.get("max_board_cards", 0)) != 5:
			failures.append("The shared board did not reach five visible cards.")
		if int(accepted.get("burn_card_count", 0)) != 3:
			failures.append("The completed hand did not burn exactly one card per board street.")
		if int(accepted.get("history_count", 0)) > 40:
			failures.append("The bounded public action history exceeded 40 records.")
		if not bool(accepted.get("chip_conservation", false)):
			failures.append("Six-handed play did not conserve stacks plus pot after every action.")
		if int(accepted.get("steps", 999)) > 160:
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
	if not bool(raised_hand.get("custom_raise_exact", false)):
		failures.append("The public raise route did not commit the exact custom whole-dollar total.")
	var report := {
		"passed": failures.is_empty(),
		"failures": failures,
		"accepted_hand": accepted,
		"all_in_hand": all_in_hand,
		"raised_hand": raised_hand,
		"end_to_end": end_to_end,
		"performance": performance,
		"distributions": distributions,
		"four_street_seed_count": four_street_seed_count,
		"four_street_seed_total": 64,
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


func _check_hand_categories(failures: Array[String]) -> void:
	var fixtures := [
		{"label": "High Card", "cards": [_card(14, 0), _card(13, 1), _card(9, 2), _card(6, 3), _card(3, 0)]},
		{"label": "One Pair", "cards": [_card(14, 0), _card(14, 1), _card(13, 2), _card(9, 3), _card(3, 0)]},
		{"label": "Two Pair", "cards": [_card(14, 0), _card(14, 1), _card(13, 2), _card(13, 3), _card(3, 0)]},
		{"label": "Three of a Kind", "cards": [_card(14, 0), _card(14, 1), _card(14, 2), _card(13, 3), _card(3, 0)]},
		{"label": "Straight", "cards": [_card(14, 0), _card(2, 1), _card(3, 2), _card(4, 3), _card(5, 0)]},
		{"label": "Flush", "cards": [_card(14, 2), _card(11, 2), _card(8, 2), _card(5, 2), _card(2, 2)]},
		{"label": "Full House", "cards": [_card(14, 0), _card(14, 1), _card(14, 2), _card(13, 3), _card(13, 0)]},
		{"label": "Four of a Kind", "cards": [_card(14, 0), _card(14, 1), _card(14, 2), _card(14, 3), _card(13, 0)]},
		{"label": "Straight Flush", "cards": [_card(5, 2), _card(6, 2), _card(7, 2), _card(8, 2), _card(9, 2)]},
	]
	for fixture_value in fixtures:
		var fixture: Dictionary = fixture_value
		var actual := str(CrewPokerModelScript.evaluate_best_hand(fixture.get("cards", [])).get("label", ""))
		if actual != str(fixture.get("label", "")):
			failures.append("Hold'em evaluator expected %s but reported %s." % [str(fixture.get("label", "")), actual])
	var ace_pair_king := [_card(14, 0), _card(14, 1), _card(13, 2), _card(9, 3), _card(3, 0)]
	var ace_pair_queen := [_card(14, 2), _card(14, 3), _card(12, 2), _card(9, 1), _card(3, 2)]
	if CrewPokerModelScript.compare_holdem(ace_pair_king, ace_pair_queen) <= 0:
		failures.append("Hold'em pair comparison ignored the deciding kicker.")


func _check_table_talk(game: GameModule, library, failures: Array[String]) -> void:
	var line_keys := ["poker_heads_up", "poker_raise", "poker_river", "poker_big_pot"]
	for member_value in CrewStateModelScript.MEMBER_IDS:
		var member_id := str(member_value)
		var character: Dictionary = library.character(member_id)
		var voice: Dictionary = character.get("voice", {}) if typeof(character.get("voice", {})) == TYPE_DICTIONARY else {}
		var lines: Dictionary = voice.get("lines", {}) if typeof(voice.get("lines", {})) == TYPE_DICTIONARY else {}
		for line_key in line_keys:
			if typeof(lines.get(line_key, [])) != TYPE_ARRAY or (lines.get(line_key, []) as Array).size() < 2:
				failures.append("%s has no authored %s pressure lines." % [member_id, line_key])
		var companions: Array = []
		for candidate_value in CrewStateModelScript.MEMBER_IDS:
			var candidate := str(candidate_value)
			if candidate != member_id and companions.size() < 4:
				companions.append(candidate)
		var state_members: Array = [member_id]
		state_members.append_array(companions)
		var state_seats: Array = [{"member_id": member_id, "active": true, "all_in": false}]
		for companion in companions:
			state_seats.append({"member_id": companion, "active": false, "all_in": false})
		var state := {
			"members": state_members,
			"seats": [
				state_seats[0], state_seats[1], state_seats[2], state_seats[3], state_seats[4],
			],
			"player_active": true,
			"player_all_in": false,
			"phase": "turn",
			"pot": 10,
			"action_ordinal": 12,
			"session_index": 1,
			"hand_number": 1,
			"table_talk_hand_count": 0,
			"table_talk_last_ordinal": -999,
			"table_talk_members_this_hand": [],
			"table_talk_history": [],
		}
		var request: Dictionary = game.call("_maybe_table_talk_request", state, member_id, "call")
		if str(request.get("member_id", "")) != member_id or str(request.get("line_key", "")) != "poker_heads_up":
			failures.append("%s did not produce the expected heads-up conversation request." % member_id)
		if int(request.get("seat_count", 0)) != CrewPokerGameScript.MAX_OPPONENT_SEATS:
			failures.append("%s table talk did not retain the five-seat anchor context." % member_id)
		if not (game.call("_maybe_table_talk_request", state, member_id, "call") as Dictionary).is_empty():
			failures.append("%s could spam a second conversation inside the cooldown." % member_id)
	var queue_state := {"action_ordinal": 20, "observation_queue": []}
	for index in range(CrewPokerGameScript.MAX_OPPONENT_SEATS):
		(queue_state["observation_queue"] as Array).append({"id": "visible-%d" % index, "m": str(CrewStateModelScript.MEMBER_IDS[index]), "source_action": "raise", "start_ordinal": 20, "duration_actions": 3, "channel": "portrait"})
	var public_queue: Array = game.call("_public_observation_queue", queue_state)
	if public_queue.size() != CrewPokerGameScript.MAX_OPPONENT_SEATS:
		failures.append("Five simultaneous Crew observations did not remain distinct in the visible queue.")
	var cap_members: Array = CrewStateModelScript.MEMBER_IDS.slice(0, CrewPokerGameScript.MAX_OPPONENT_SEATS)
	var cap_seats: Array = []
	for cap_member in cap_members:
		cap_seats.append({"member_id": cap_member, "active": true, "all_in": false})
	var cap_state := {"members": cap_members, "seats": cap_seats, "player_active": true, "player_all_in": false, "phase": "turn", "pot": 40, "action_ordinal": 30, "session_index": 2, "hand_number": 1, "table_talk_hand_count": 0, "table_talk_last_ordinal": -999, "table_talk_members_this_hand": [], "table_talk_history": []}
	for index in range(3):
		cap_state["action_ordinal"] = 30 + index * int(CrewPokerModelScript.config().get("table_talk_cooldown_actions", 3))
		game.call("_maybe_table_talk_request", cap_state, str(cap_members[index]), "raise")
	if int(cap_state.get("table_talk_hand_count", 0)) != int(CrewPokerModelScript.config().get("table_talk_max_per_hand", 2)) or (cap_state.get("table_talk_history", []) as Array).size() != 2:
		failures.append("Five-speaker table talk did not enforce its per-hand cap and cooldown.")


func _check_performance(game: GameModule, failures: Array[String]) -> Dictionary:
	var started := Time.get_ticks_usec()
	for seed in range(9000, 10000):
		game.call("scripted_session", seed, "crew_switch", true)
	var elapsed_usec := Time.get_ticks_usec() - started
	if elapsed_usec > 2000000:
		failures.append("One thousand deterministic Hold'em evaluations exceeded the two-second audit budget.")
	return {"sessions": 1000, "elapsed_usec": elapsed_usec, "budget_usec": 2000000}


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


func _check_no_limit_raise_rules(game: GameModule, failures: Array[String]) -> void:
	var state := {
		"phase": "turn",
		"turn_owner": "player",
		"current_bet": 12,
		"last_raise_size": 5,
		"round_contributions": {"player": 7},
		"player_stack": 53,
		"player_fake_tell_used_street": "",
		"raise_count": 99,
	}
	var action_ids: Array = []
	for action_value in game.call("_ordered_legal_actions", state):
		action_ids.append(str((action_value as Dictionary).get("id", "")))
	if not action_ids.has("raise"):
		failures.append("A no-limit street incorrectly stopped offering raises after earlier action.")
	if int(game.call("_minimum_raise_to", state)) != 17:
		failures.append("The minimum raise did not preserve the previous full raise size.")
	if int(game.call("_maximum_raise_to", state)) != 60:
		failures.append("The maximum raise did not include every remaining player chip.")


func _check_six_hand_rotation_and_shoe(game: GameModule, failures: Array[String]) -> void:
	var members: Array = CrewStateModelScript.MEMBER_IDS.slice(0, CrewPokerGameScript.MAX_OPPONENT_SEATS)
	var expected_actors: Array = ["player"]
	expected_actors.append_array(members)
	var signatures: Array = []
	for button_index in range(expected_actors.size()):
		var run_state := RunStateScript.new()
		run_state.start_new("CREW-HOLDEM-ROTATION-%d" % button_index)
		run_state.bankroll = 500
		var state := {
			"members": members.duplicate(), "seats": [], "phase": "idle", "session_settled": false,
			"button_index": button_index, "player_stack": 60, "npc_stacks": {}, "session_swing": 0,
			"hand_number": 0, "action_ordinal": 0, "observation_queue": [], "verified_observation_receipts": [],
			"turn_engine": "ordered_v1", "action_history": [], "session_memory": {}, "player_signal_history": [],
		}
		var rng := RngStreamScript.new()
		rng.configure(12000 + button_index)
		var deal: Dictionary = game.call("_deal_hand_ordered", run_state, state, rng)
		if not bool(deal.get("ok", false)):
			failures.append("Six-hand rotation fixture could not deal button position %d." % button_index)
			continue
		if str(state.get("dealer_actor", "")) != str(expected_actors[button_index]) \
				or str(state.get("small_blind_actor", "")) != str(expected_actors[(button_index + 1) % expected_actors.size()]) \
				or str(state.get("big_blind_actor", "")) != str(expected_actors[(button_index + 2) % expected_actors.size()]) \
				or str(state.get("turn_owner", "")) != str(expected_actors[(button_index + 3) % expected_actors.size()]):
			failures.append("Button/blind/pre-flop rotation was wrong at six-hand button position %d." % button_index)
		game.call("_start_holdem_round", state, "flop")
		if str(state.get("turn_owner", "")) != str(expected_actors[(button_index + 1) % expected_actors.size()]):
			failures.append("Post-flop first action did not start left of the button at position %d." % button_index)
		if (state.get("shoe", []) as Array).size() != 40:
			failures.append("Six-handed hole cards did not leave exactly 40 cards in the shoe.")
		game.call("_burn_and_deal_board", state, 3)
		game.call("_burn_and_deal_board", state, 1)
		game.call("_burn_and_deal_board", state, 1)
		if (state.get("community_cards", []) as Array).size() != 5 or (state.get("burn_cards", []) as Array).size() != 3 or (state.get("shoe", []) as Array).size() != 32:
			failures.append("Six-handed board dealing over-drew or miscounted the 52-card shoe.")
		signatures.append({"button": button_index, "player": state.get("player_cards", []), "board": state.get("community_cards", []), "shoe": state.get("shoe", [])})
	var repeat_signatures: Array = []
	for button_index in range(expected_actors.size()):
		var repeat_run := RunStateScript.new()
		repeat_run.start_new("CREW-HOLDEM-ROTATION-%d" % button_index)
		repeat_run.bankroll = 500
		var repeat_state := {"members": members.duplicate(), "seats": [], "phase": "idle", "session_settled": false, "button_index": button_index, "player_stack": 60, "npc_stacks": {}, "session_swing": 0, "hand_number": 0, "action_ordinal": 0, "observation_queue": [], "verified_observation_receipts": [], "turn_engine": "ordered_v1", "action_history": [], "session_memory": {}, "player_signal_history": []}
		var repeat_rng := RngStreamScript.new()
		repeat_rng.configure(12000 + button_index)
		game.call("_deal_hand_ordered", repeat_run, repeat_state, repeat_rng)
		game.call("_burn_and_deal_board", repeat_state, 3)
		game.call("_burn_and_deal_board", repeat_state, 1)
		game.call("_burn_and_deal_board", repeat_state, 1)
		repeat_signatures.append({"button": button_index, "player": repeat_state.get("player_cards", []), "board": repeat_state.get("community_cards", []), "shoe": repeat_state.get("shoe", [])})
	if JSON.stringify(signatures) != JSON.stringify(repeat_signatures):
		failures.append("Six-handed hole/board/shoe order was not deterministic per seed.")


func _check_raise_round_closure(game: GameModule, failures: Array[String]) -> void:
	var members: Array = CrewStateModelScript.MEMBER_IDS.slice(0, CrewPokerGameScript.MAX_OPPONENT_SEATS)
	var seats: Array = []
	for member_id in members:
		seats.append({"member_id": member_id, "active": true, "all_in": false, "stack": 50, "round_contribution": 14})
	var actors: Array = ["player"]
	actors.append_array(members)
	var state := {"members": members, "seats": seats, "player_active": true, "player_all_in": false, "player_stack": 50, "current_bet": 14, "round_contributions": {"player": 14}, "acted_since_raise": [str(members[0])], "turn_order": actors, "turn_cursor": 1, "phase": "turn"}
	var missing_one := actors.slice(0, actors.size() - 1)
	state["acted_since_raise"] = missing_one
	if bool(game.call("_ordered_round_closed", state)):
		failures.append("A six-handed round closed before every active seat answered the raise.")
	state["acted_since_raise"] = actors.duplicate()
	if not bool(game.call("_ordered_round_closed", state)):
		failures.append("A six-handed round did not close after every active seat matched and acted.")


func _check_multiway_split(failures: Array[String]) -> void:
	var winners := ["player", "crew_rook", "crew_mags", "crew_lucky"]
	var awards: Dictionary = CrewPokerModelScript.split_pot(17, winners)
	if int(awards.get("player", 0)) != 5 or int(awards.get("crew_rook", 0)) != 4 or int(awards.get("crew_mags", 0)) != 4 or int(awards.get("crew_lucky", 0)) != 4:
		failures.append("A four-way odd-pot tie did not award deterministic seat-order remainder chips: %s." % JSON.stringify(awards))


func _check_night_rituals(game: GameModule, library, failures: Array[String]) -> void:
	var members: Array = CrewStateModelScript.MEMBER_IDS.slice(0, CrewPokerGameScript.MAX_OPPONENT_SEATS)
	var seats: Array = []
	for member_id in members:
		seats.append({"member_id": member_id, "active": true, "last_action": "waiting"})
	for night_index in range(CrewPokerGameScript.NIGHT_IDS.size()):
		var night_id := str(CrewPokerGameScript.NIGHT_IDS[night_index])
		var state := {"night_id": night_id, "members": members, "seats": seats, "turn_owner": "player", "phase": "idle", "pot": 0, "community_cards": []}
		var actors: Array = game.call("_ordered_ritual_actors", state)
		var actor_ids: Array = []
		for actor_value in actors:
			actor_ids.append(str((actor_value as Dictionary).get("id", "")))
		var scene: Dictionary = game.call("_night_scene_state", state)
		if actors.size() != CrewPokerGameScript.MAX_OPPONENT_SEATS + 1 or str(scene.get("task", "")).is_empty():
			failures.append("Authored poker night %s did not resolve a player plus five occupied chairs." % night_id)
		for member_id in members:
			if not actor_ids.has(str(member_id)):
				failures.append("Authored poker night %s lost seated actor %s." % [night_id, str(member_id)])
		var completed := _play_hand(game, library, 7601 + night_index * 19, false, false, CrewPokerGameScript.MAX_OPPONENT_SEATS, night_id)
		if not bool(completed.get("complete", false)):
			failures.append("Authored poker night %s did not run a full hand to completion." % night_id)


func _check_three_member_save(game: GameModule, failures: Array[String]) -> void:
	var run_state := RunStateScript.new()
	run_state.start_new("CREW-HOLDEM-LEGACY-THREE-SAVE")
	run_state.bankroll = 500
	for member_id in CrewStateModelScript.MEMBER_IDS:
		run_state.crew_add_trust(str(member_id), CrewStateModelScript.rank_threshold("made"), "legacy_three_save")
	var environment := {"id": "crew_holdem_legacy_three", "archetype_id": "small_underground_casino", "kind": "crew", "layer_id": "back_room", "crew_poker_turn_engine": "ordered_v1", "resident_member_ids": CrewStateModelScript.MEMBER_IDS.slice(0, 3), "game_ids": ["crew_draw_poker"], "game_states": {}}
	var setup_rng := RngStreamScript.new()
	setup_rng.configure(13131)
	var generated: Dictionary = game.generate_environment_state(run_state, environment, setup_rng)
	generated["members"] = (generated.get("members", []) as Array).slice(0, 3)
	environment["game_states"] = {"crew_draw_poker": generated}
	run_state.current_environment = environment
	_apply(game, run_state, "deal", {}, 13132)
	var before_save: Dictionary = run_state.current_environment.get("game_states", {}).get("crew_draw_poker", {}).duplicate(true)
	var restored := RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var restored_table: Dictionary = restored.current_environment.get("game_states", {}).get("crew_draw_poker", {})
	for key in ["members", "seats", "shoe", "player_cards", "pot", "turn_owner", "turn_order", "button_index"]:
		if JSON.stringify(before_save.get(key)) != JSON.stringify(restored_table.get(key)):
			failures.append("Three-member mid-hand save changed %s during reload." % key)
	var steps := 0
	while str(restored_table.get("phase", "idle")) != "idle" and steps < 120:
		if (restored_table.get("members", []) as Array).size() != 3 or (restored_table.get("seats", []) as Array).size() != 3:
			failures.append("Reloaded three-member table re-seated opponents mid-hand.")
			break
		var legal_ids: Array = []
		for action_value in game.legal_actions(restored, restored.current_environment):
			legal_ids.append(str((action_value as Dictionary).get("id", "")))
		var action_id := "observe" if legal_ids.has("observe") else "call" if legal_ids.has("call") else "check" if legal_ids.has("check") else "fold" if legal_ids.has("fold") else ""
		if action_id.is_empty() or not bool(_apply(game, restored, action_id, {}, 13200 + steps).get("ok", false)):
			failures.append("Reloaded three-member table could not play its saved hand to completion.")
			break
		restored_table = restored.current_environment.get("game_states", {}).get("crew_draw_poker", {})
		steps += 1
	if str(restored_table.get("phase", "")) != "idle" or (restored_table.get("members", []) as Array).size() != 3:
		failures.append("Reloaded three-member table did not finish with its original roster intact.")


func _check_dealer_migration_and_roles(game: GameModule, failures: Array[String]) -> void:
	for opponent_count in [5, 3]:
		var members: Array = CrewStateModelScript.MEMBER_IDS.slice(0, opponent_count)
		var old_state := {"schema": CrewPokerGameScript.STATE_SCHEMA, "version": CrewPokerGameScript.STATE_VERSION, "members": members, "phase": "preflop", "session_index": 3, "hand_number": 1, "pot": 19, "turn_owner": str(members[0]), "seats": [], "player_cards": [_card(14, 0), _card(13, 1)], "shoe": []}
		var environment := {"id": "crew_poker_dealer_migration_%d" % opponent_count, "crew_poker_turn_engine": "ordered_v1", "game_states": {"crew_draw_poker": old_state}}
		var migrated := game.call("_table_state", environment) as Dictionary
		var dealer_id := str(migrated.get("dealer_member_id", ""))
		if dealer_id.is_empty() or members.has(dealer_id) or dealer_id != str((game.call("_table_state", environment) as Dictionary).get("dealer_member_id", "")):
			failures.append("The %d-opponent pre-dealer save did not migrate to one stable unseated dealer." % opponent_count)
		if int(migrated.get("pot", 0)) != 19 or str(migrated.get("turn_owner", "")) != str(members[0]) or JSON.stringify(migrated.get("player_cards", [])) != JSON.stringify(old_state.get("player_cards", [])):
			failures.append("Dealer migration changed authoritative live-hand state for %d opponents." % opponent_count)
		var seats: Array = []
		for member_id in members:
			seats.append({"member_id": member_id, "active": true, "last_action": "waiting"})
		migrated["seats"] = seats
		var ritual_ids: Array = []
		for actor_value in game.call("_ordered_ritual_actors", migrated):
			ritual_ids.append(str((actor_value as Dictionary).get("id", "")))
		if ritual_ids.has(dealer_id):
			failures.append("The house dealer entered an opponent ritual group in the %d-seat migration." % opponent_count)


func _check_two_hand_session_reload(game: GameModule, failures: Array[String]) -> Dictionary:
	for seed in range(15000, 15064):
		var attempt := _two_hand_session_attempt(game, seed)
		if bool(attempt.get("passed", false)):
			return attempt
	failures.append("No five-opponent production session completed three showdowns with a stable mid-animation reload.")
	return {"passed": false}


func _two_hand_session_attempt(game: GameModule, seed: int) -> Dictionary:
	var run_state := RunStateScript.new()
	run_state.start_new("CREW-HOLDEM-TWO-HAND-%d" % seed)
	run_state.bankroll = 500
	for member_id in CrewStateModelScript.MEMBER_IDS:
		run_state.crew_add_trust(str(member_id), CrewStateModelScript.rank_threshold("made"), "two_hand_reload")
	var environment := {
		"id": "crew_holdem_two_hand",
		"archetype_id": "small_underground_casino",
		"kind": "crew",
		"layer_id": "back_room",
		"crew_poker_turn_engine": "ordered_v1",
		"resident_member_ids": CrewStateModelScript.MEMBER_IDS.slice(0, CrewPokerGameScript.MAX_OPPONENT_SEATS),
		"game_ids": ["crew_draw_poker"],
		"game_states": {},
	}
	var setup_rng := RngStreamScript.new()
	setup_rng.configure(seed)
	var generated: Dictionary = game.generate_environment_state(run_state, environment, setup_rng)
	environment["game_states"] = {"crew_draw_poker": generated}
	run_state.current_environment = environment
	var current_run: RunState = run_state
	var showdown_count := 0
	var reload_preserved := false
	var mid_animation_no_replay := false
	var hand_signatures: Array = []
	for hand_index in range(3):
		var deal_result := _apply(game, current_run, "deal", {"surface_time_msec": 1000, "surface_presentation_time_msec": 1000}, seed + hand_index * 1000)
		if not bool(deal_result.get("ok", false)):
			return {"passed": false, "seed": seed, "failure": "deal_%d" % hand_index}
		if hand_index == 1:
			var before: Dictionary = current_run.current_environment.get("game_states", {}).get("crew_draw_poker", {}).duplicate(true)
			var serialized := JSON.stringify(current_run.to_dict())
			var restored := RunStateScript.new()
			restored.from_dict(current_run.to_dict())
			var after: Dictionary = restored.current_environment.get("game_states", {}).get("crew_draw_poker", {})
			reload_preserved = true
			for key in ["members", "seats", "shoe", "player_cards", "pot", "turn_owner", "turn_order", "button_index"]:
				reload_preserved = reload_preserved and JSON.stringify(before.get(key)) == JSON.stringify(after.get(key))
			var restored_surface := game.surface_state(restored, restored.current_environment, {})
			mid_animation_no_replay = not serialized.contains("poker_animation") and (restored_surface.get("surface_animation_channels", []) as Array).is_empty()
			current_run = restored
		var steps := 0
		while steps < 160:
			var table: Dictionary = current_run.current_environment.get("game_states", {}).get("crew_draw_poker", {})
			if str(table.get("phase", "idle")) == "idle":
				break
			var legal_ids: Array = []
			for action_value in game.legal_actions(current_run, current_run.current_environment):
				legal_ids.append(str((action_value as Dictionary).get("id", "")))
			var action_id := "observe" if legal_ids.has("observe") else "call" if legal_ids.has("call") else "check" if legal_ids.has("check") else "all_in" if legal_ids.has("all_in") else ""
			if action_id.is_empty() or not bool(_apply(game, current_run, action_id, {}, seed + hand_index * 1000 + steps + 1).get("ok", false)):
				return {"passed": false, "seed": seed, "failure": "progress_%d" % hand_index}
			steps += 1
		var final_table: Dictionary = current_run.current_environment.get("game_states", {}).get("crew_draw_poker", {})
		if str(final_table.get("phase", "")) != "idle":
			return {"passed": false, "seed": seed, "failure": "step_limit_%d" % hand_index}
		var reached_showdown := (final_table.get("community_cards", []) as Array).size() == 5 and (final_table.get("burn_cards", []) as Array).size() == 3
		showdown_count += 1 if reached_showdown else 0
		hand_signatures.append({"hand_number": final_table.get("hand_number", 0), "showdown": reached_showdown, "result": final_table.get("last_result", {})})
	return {
		"passed": showdown_count == 3 and reload_preserved and mid_animation_no_replay and (generated.get("members", []) as Array).size() == CrewPokerGameScript.MAX_OPPONENT_SEATS,
		"seed": seed,
		"showdown_count": showdown_count,
		"reload_preserved": reload_preserved,
		"mid_animation_no_replay": mid_animation_no_replay,
		"member_count": (generated.get("members", []) as Array).size(),
		"hands": hand_signatures,
	}


func _play_hand(game: GameModule, library, seed: int, force_all_in: bool = false, force_raise: bool = false, opponent_count: int = CrewPokerGameScript.MAX_OPPONENT_SEATS, night_id: String = "") -> Dictionary:
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
		"resident_member_ids": CrewStateModelScript.MEMBER_IDS.slice(0, CrewPokerGameScript.MAX_OPPONENT_SEATS),
		"game_ids": ["crew_draw_poker"],
		"game_states": {},
	}
	if not night_id.is_empty():
		environment["crew_poker_night_id"] = night_id
	var setup_rng := RngStreamScript.new()
	setup_rng.configure(seed)
	var generated := game.generate_environment_state(run_state, environment, setup_rng)
	generated["members"] = (generated.get("members", []) as Array).slice(0, clampi(opponent_count, 2, CrewPokerGameScript.MAX_OPPONENT_SEATS))
	environment["game_states"] = {"crew_draw_poker": generated}
	run_state.current_environment = environment
	for task_step in range(4):
		var predeal_legal: Array[String] = []
		for action_value in game.legal_actions(run_state, run_state.current_environment):
			predeal_legal.append(str((action_value as Dictionary).get("id", "")))
		if predeal_legal.has("deal"):
			break
		var task_action := ""
		for candidate in ["answer_duty", "choose_company", "hide_table", "resume_table"]:
			if predeal_legal.has(candidate):
				task_action = candidate
				break
		if task_action.is_empty() or not bool(_apply(game, run_state, task_action, {}, seed - 10 + task_step).get("ok", false)):
			return {"seed": seed, "complete": false, "failure": "night_task"}
	var first := _apply(game, run_state, "deal", {"surface_time_msec": 1000, "surface_presentation_time_msec": 1000}, seed)
	if not bool(first.get("ok", false)):
		return {"seed": seed, "complete": false, "failure": "deal"}
	var streets: Array = []
	var hidden_ok := true
	var animation_hidden_ok := _animation_result_is_public(game, run_state, first)
	var animation_event_kinds: Array = []
	_collect_animation_event_kinds(first, animation_event_kinds)
	var max_board := 0
	var fake_tell_done := false
	var fake_tell_kept_turn := false
	var all_in_committed := false
	var raise_committed := false
	var custom_raise_exact := false
	var player_action_set: Array = []
	var steps := 1
	var dealt_table: Dictionary = run_state.current_environment.get("game_states", {}).get("crew_draw_poker", {})
	var expected_chip_total := _table_chip_total(dealt_table)
	var chip_conservation := expected_chip_total > 0
	var max_pot := int(dealt_table.get("pot", 0))
	while steps < 160:
		var table: Dictionary = run_state.current_environment.get("game_states", {}).get("crew_draw_poker", {})
		max_pot = maxi(max_pot, int(table.get("pot", 0)))
		chip_conservation = chip_conservation and _table_chip_total(table) == expected_chip_total
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
		var ui := {"surface_time_msec": 1000 + steps * 2500, "surface_presentation_time_msec": 1000 + steps * 2500}
		if legal_ids.has("fake_tell") and not fake_tell_done:
			var owner_before := str(table.get("turn_owner", ""))
			var fake_ui := ui.duplicate()
			fake_ui["poker_tell_style"] = "strong"
			var fake := _apply(game, run_state, "fake_tell", fake_ui, seed + steps)
			animation_hidden_ok = animation_hidden_ok and _animation_result_is_public(game, run_state, fake)
			_collect_animation_event_kinds(fake, animation_event_kinds)
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
		var pot_before_action := int(table.get("pot", 0))
		var expected_raise_cost := 0
		if action_id == "raise":
			var selected_raise_to := int(surface.get("minimum_raise_to", 0)) + 1
			ui["poker_raise_to"] = selected_raise_to
			expected_raise_cost = selected_raise_to - int((surface.get("round_contributions", {}) as Dictionary).get("player", 0))
		var result := _apply(game, run_state, action_id, ui, seed + steps)
		if not bool(result.get("ok", false)):
			return {"seed": seed, "complete": false, "failure": action_id, "streets": streets}
		animation_hidden_ok = animation_hidden_ok and _animation_result_is_public(game, run_state, result)
		_collect_animation_event_kinds(result, animation_event_kinds)
		if action_id == "all_in":
			all_in_committed = true
		elif action_id == "raise":
			raise_committed = true
			var after_raise: Dictionary = run_state.current_environment.get("game_states", {}).get("crew_draw_poker", {})
			custom_raise_exact = int(after_raise.get("pot", 0)) == pot_before_action + expected_raise_cost
		steps += 1
	var final_table: Dictionary = run_state.current_environment.get("game_states", {}).get("crew_draw_poker", {})
	max_pot = maxi(max_pot, int(final_table.get("pot", 0)))
	max_board = maxi(max_board, (final_table.get("community_cards", []) as Array).size())
	if max_board >= 3 and not streets.has("flop"):
		streets.append("flop")
	if max_board >= 4 and not streets.has("turn"):
		streets.append("turn")
	if max_board >= 5 and not streets.has("river"):
		streets.append("river")
	chip_conservation = chip_conservation and _table_chip_total(final_table) == expected_chip_total
	return {
		"seed": seed,
		"complete": str(final_table.get("phase", "")) == "idle",
		"member_count": (generated.get("members", []) as Array).size(),
		"streets": streets,
		"max_board_cards": max_board,
		"hidden_hole_cards": hidden_ok,
		"animation_hidden_information": animation_hidden_ok and not JSON.stringify(run_state.to_dict()).contains("crew_poker_cards:"),
		"animation_event_kinds": animation_event_kinds,
		"fake_tell_kept_turn": fake_tell_kept_turn,
		"all_in_committed": all_in_committed,
		"raise_committed": raise_committed,
		"custom_raise_exact": custom_raise_exact,
		"player_action_set": player_action_set,
		"steps": steps,
		"burn_card_count": (final_table.get("burn_cards", []) as Array).size(),
		"history_count": (final_table.get("action_history", []) as Array).size(),
		"chip_conservation": chip_conservation,
		"max_pot": max_pot,
		"session_swing": int(final_table.get("session_swing", 0)),
		"signature": {"last_result": final_table.get("last_result", {}), "history": final_table.get("action_history", []), "board": final_table.get("community_cards", []), "bankroll": run_state.bankroll},
	}


func _table_chip_total(state: Dictionary) -> int:
	var total := int(state.get("pot", 0)) + int(state.get("player_stack", 0))
	for seat_value in state.get("seats", []):
		total += int((seat_value as Dictionary).get("stack", 0))
	return total


func _collect_animation_event_kinds(result: Dictionary, kinds: Array) -> void:
	var ui_state: Dictionary = result.get("ui_state", {}) if typeof(result.get("ui_state", {})) == TYPE_DICTIONARY else {}
	var animation: Dictionary = ui_state.get("poker_animation", {}) if typeof(ui_state.get("poker_animation", {})) == TYPE_DICTIONARY else {}
	for event_key in ["card_events", "chip_events", "payout_events"]:
		for event_value in animation.get(event_key, []):
			var kind := str((event_value as Dictionary).get("kind", ""))
			if not kind.is_empty() and not kinds.has(kind):
				kinds.append(kind)


func _animation_result_is_public(game: GameModule, run_state: RunState, result: Dictionary) -> bool:
	var ui_state: Dictionary = result.get("ui_state", {}) if typeof(result.get("ui_state", {})) == TYPE_DICTIONARY else {}
	var animation: Dictionary = ui_state.get("poker_animation", {}) if typeof(ui_state.get("poker_animation", {})) == TYPE_DICTIONARY else {}
	if animation.is_empty():
		return true
	var table: Dictionary = run_state.current_environment.get("game_states", {}).get("crew_draw_poker", {})
	var dealer_id := str(table.get("dealer_member_id", ""))
	if dealer_id.is_empty() or (table.get("members", []) as Array).has(dealer_id):
		return false
	for event_value in animation.get("card_events", []):
		var event: Dictionary = event_value
		var kind := str(event.get("kind", ""))
		var actor_id := str(event.get("actor", ""))
		var card: Dictionary = event.get("card", {}) if typeof(event.get("card", {})) == TYPE_DICTIONARY else {}
		if kind == "burn" or kind in ["deal", "fold"] and actor_id != "player":
			if not bool(card.get("hidden", false)) or card.has("rank") or card.has("suit"):
				return false
		if kind == "showdown_flip" and not bool(animation.get("showdown", false)):
			return false
	return true


func _distribution_metrics(game: GameModule, library, opponent_count: int, seed_base: int) -> Dictionary:
	var pots: Array[int] = []
	var swings: Array[int] = []
	var conservation_passed := true
	for offset in range(24):
		var hand := _play_hand(game, library, seed_base + offset, false, false, opponent_count)
		if not bool(hand.get("complete", false)):
			continue
		pots.append(int(hand.get("max_pot", 0)))
		swings.append(int(hand.get("session_swing", 0)))
		conservation_passed = conservation_passed and bool(hand.get("chip_conservation", false))
	pots.sort()
	swings.sort()
	return {
		"opponents": opponent_count,
		"completed_hands": pots.size(),
		"pot": _distribution_summary(pots),
		"session_swing": _distribution_summary(swings),
		"chip_conservation_passed": conservation_passed and not pots.is_empty(),
	}


func _distribution_summary(values: Array[int]) -> Dictionary:
	if values.is_empty():
		return {"min": 0, "median": 0, "p95": 0, "max": 0}
	var median_index := floori(float(values.size() - 1) / 2.0)
	var p95_index := mini(values.size() - 1, ceili(float(values.size()) * 0.95) - 1)
	return {"min": values[0], "median": values[median_index], "p95": values[p95_index], "max": values[values.size() - 1]}


func _apply(game: GameModule, run_state: RunState, action_id: String, ui: Dictionary, seed: int) -> Dictionary:
	var rng := RngStreamScript.new()
	rng.configure(seed)
	var result := game.resolve_with_context(action_id, 2, run_state, run_state.current_environment, rng, ui)
	if bool(result.get("ok", false)):
		GameModuleScript.apply_result(run_state, result, rng)
	return result


func _card(rank: int, suit: int) -> Dictionary:
	return {"rank": rank, "suit": suit, "deck": 0}
