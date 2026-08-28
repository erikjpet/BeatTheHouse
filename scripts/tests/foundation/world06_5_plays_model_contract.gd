extends SceneTree

const PlayModel := preload("res://scripts/core/crew_play_model.gd")
const CrewState := preload("res://scripts/core/crew_state_model.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const MEMBERS := ["crew_rook", "crew_switch", "crew_mags", "crew_knuckles", "crew_velvet", "crew_bishop", "crew_lucky"]
const GAMES := ["blackjack", "baccarat", "roulette", "craps", "video_poker"]


func _initialize() -> void:
	var failures: Array = []
	_check_unchanged_contract(failures)
	_check_exact_game_matrix_and_lifecycle(failures)
	_check_cap_and_pairing_exception(failures)
	_check_chip_dump_and_detection(failures)
	_check_save_revisit_and_hidden_safety(failures)
	if failures.is_empty():
		print("world06_5 plays model contract passed proposal_only=true authority_gap=adapter_host_root_unavailable seeds=10")
		quit(0)
		return
	for failure in failures:
		push_error(str(failure))
	quit(1)


func _check_unchanged_contract(failures: Array) -> void:
	var expected := {
		"spotter": ["made", ["blackjack"], 2, 8, 6, 4, 16, 14, {"blackjack_count_tolerance": 1, "blackjack_count_confidence": "Switch taps once when your count is within one.", "suspicion_multiplier_percent": 65}],
		"distraction": ["made", GAMES, 1, 10, 8, 0, 0, 0, {"suspicion_dump": 18}],
		"big_player": ["made", ["blackjack"], 1, 14, 8, 1, 0, 0, {"minimum_warm_count": 3, "maximum_warm_count": 5}],
		"chip_dump": ["made", ["baccarat"], 2, 0, 5, 0, 20, 12, {"transfer_amount": 40, "transfer_fee": 6, "direction": "cash_to_chips"}],
		"table_flood": ["made", GAMES, 2, 16, 6, 3, 10, 10, {"cheat_detection_multiplier_percent": 60}],
	}
	var cfg := PlayModel.config()
	if int(cfg.get("active_window_cap", -1)) != 1 or cfg.get("pairing_exceptions", []) != ["spotter:big_player"]:
		failures.append("Active-window cap or the sole spotter:big_player exception changed.")
	for play_id in PlayModel.PLAY_IDS:
		var play := PlayModel.definition(play_id)
		var row: Array = expected.get(play_id, [])
		var actual := [play.get("minimum_rank"), play.get("game_ids"), int(play.get("uses_per_run")), int(play.get("cash_cost")), int(play.get("cooldown_boundaries")), int(play.get("window_boundaries")), int(play.get("detection_chance_percent")), int(play.get("detection_heat"))]
		if actual != row.slice(0, 8):
			failures.append("Landed values changed for %s: %s" % [play_id, JSON.stringify(actual)])
		var effect := _dict(play.get("effect", {}))
		var expected_effect := _dict(row[8])
		if effect.keys().size() != expected_effect.keys().size():
			failures.append("Landed effect shape changed for %s." % play_id)
		for key in expected_effect:
			var matches := str(effect.get(key, "")) == str(expected_effect[key]) if typeof(expected_effect[key]) == TYPE_STRING else int(effect.get(key, -99999)) == int(expected_effect[key])
			if not matches: failures.append("Landed effect %s changed for %s." % [key, play_id])
	if not PlayModel.validate_content(MEMBERS).is_empty():
		failures.append("Unchanged coordinated-play data no longer validates.")


func _check_exact_game_matrix_and_lifecycle(failures: Array) -> void:
	for play_id in PlayModel.PLAY_IDS:
		var play := PlayModel.definition(play_id)
		for game_value in play.get("game_ids", []):
			var game_id := str(game_value)
			var run: Variant = _run("WORLD65-MATRIX-%s-%s" % [play_id, game_id], game_id)
			if play_id == "big_player":
				PlayModel.activate(run, run.current_environment, "blackjack", "spotter")
			var before := JSON.stringify(run.to_dict())
			var proposal := PlayModel.table_presence_proposal(run, run.current_environment, game_id, play_id)
			if not bool(proposal.get("eligible", false)) or bool(proposal.get("authoritative", true)) or not bool(proposal.get("proposal_only", false)) \
					or bool(proposal.get("can_mutate", true)) or str(proposal.get("authority_gap", "")) != "adapter_host_root_unavailable":
				failures.append("%s did not produce a safe proposal at exact game %s." % [play_id, game_id])
			if proposal.get("lifecycle_phases", []) != ["arrive", "work", "detected_or_clean", "leave"]:
				failures.append("%s/%s lost arrive-work-outcome-leave lifecycle." % [play_id, game_id])
			var actor_states: Array = []
			for op_value in proposal.get("actor_ops", []):
				actor_states.append(str((op_value as Dictionary).get("state", "")))
			for state in ["arriving", "working", "detected", "leaving"]:
				if not actor_states.has(state): failures.append("%s/%s omitted actor state %s." % [play_id, game_id, state])
			if JSON.stringify(run.to_dict()) != before:
				failures.append("Reading %s/%s proposal mutated authoritative run state." % [play_id, game_id])
		for wrong_game in GAMES:
			if not (play.get("game_ids", []) as Array).has(wrong_game):
				var wrong: Variant = _run("WORLD65-WRONG-%s-%s" % [play_id, wrong_game], wrong_game)
				var rejected := PlayModel.table_presence_proposal(wrong, wrong.current_environment, wrong_game, play_id)
				if bool(rejected.get("eligible", true)) or str(rejected.get("reason", "")) != "wrong_context":
					failures.append("%s escaped exact game_ids at %s." % [play_id, wrong_game])
		var substitution: Variant = _run("WORLD65-SUB-%s" % play_id, str((play.get("game_ids", []) as Array)[0]))
		var forged: Dictionary = substitution.current_environment.duplicate(true)
		forged["id"] = "substituted_table"
		var rejected_sub := PlayModel.table_presence_proposal(substitution, forged, str((play.get("game_ids", []) as Array)[0]), play_id)
		if str(rejected_sub.get("reason", "")) != "untrusted_table_context":
			failures.append("%s accepted a substituted environment." % play_id)


func _check_cap_and_pairing_exception(failures: Array) -> void:
	var capped: Variant = _run("WORLD65-CAP", "blackjack")
	PlayModel.activate(capped, capped.current_environment, "blackjack", "table_flood")
	var denied := PlayModel.table_presence_proposal(capped, capped.current_environment, "blackjack", "spotter")
	if str(denied.get("reason", "")) != "active_window_cap":
		failures.append("The exact one-window cap did not reject Spotter beside Table Flood.")
	var paired: Variant = _run("WORLD65-PAIR", "blackjack")
	PlayModel.activate(paired, paired.current_environment, "blackjack", "spotter")
	var allowed := PlayModel.table_presence_proposal(paired, paired.current_environment, "blackjack", "big_player")
	if not bool(allowed.get("eligible", false)):
		failures.append("The sole spotter:big_player pairing exception was not honored.")


func _check_chip_dump_and_detection(failures: Array) -> void:
	var observed: Array = []
	for index in range(10):
		var seed := "WORLD65-DETECTION-%d" % index
		var first: Variant = _run(seed, "baccarat")
		first.grand_casino_chips = 10
		var proposal := PlayModel.table_presence_proposal(first, first.current_environment, "baccarat", "chip_dump")
		var funding := _dict(proposal.get("funding", {}))
		if funding != {"model": "A_player_funded", "direction": "cash_to_chips", "cash_debit": 46, "chip_credit": 40, "fee_sink": 6}:
			failures.append("Chip Dump proposal changed conservation model A.")
		var before_total: int = first.bankroll + first.grand_casino_chips
		var result := PlayModel.activate(first, first.current_environment, "baccarat", "chip_dump")
		if not bool(result.get("ok", false)) or first.bankroll + first.grand_casino_chips != before_total - 6 \
				or int(result.get("bankroll_delta", 0)) != -46 or int(result.get("chips_delta", 0)) != 40:
			failures.append("Chip Dump failed player-funded conservation for seed %s." % seed)
		var second: Variant = _run(seed, "baccarat")
		second.grand_casino_chips = 10
		var replay := PlayModel.activate(second, second.current_environment, "baccarat", "chip_dump")
		if bool(result.get("crew_play_detected", false)) != bool(replay.get("crew_play_detected", false)) or first.suspicion_level() != second.suspicion_level():
			failures.append("Detection projection diverged for repeated seed %s." % seed)
		observed.append(bool(result.get("crew_play_detected", false)))
	if not observed.has(true) or not observed.has(false):
		failures.append("The fixed 10-seed projection did not exercise both detected and clean Chip Dump beats: %s" % JSON.stringify(observed))


func _check_save_revisit_and_hidden_safety(failures: Array) -> void:
	var run: Variant = _run("WORLD65-SAVE", "blackjack")
	PlayModel.activate(run, run.current_environment, "blackjack", "table_flood")
	var before_status := PlayModel.active_status(run.crew_play_state, run.crew_action_index(), run.current_environment, "blackjack")
	var before_proposal := PlayModel.table_presence_proposal(run, run.current_environment, "blackjack", "spotter")
	var restored := RunStateScript.new()
	restored.from_dict(run.to_dict())
	var after_status := PlayModel.active_status(restored.crew_play_state, restored.crew_action_index(), restored.current_environment, "blackjack")
	var after_proposal := PlayModel.table_presence_proposal(restored, restored.current_environment, "blackjack", "spotter")
	if JSON.stringify(before_status) != JSON.stringify(after_status) or JSON.stringify(before_proposal) != JSON.stringify(after_proposal):
		failures.append("Mid-window save/revisit changed active or proposal state.")
	var hidden_run: Variant = _run("WORLD65-HIDDEN", "blackjack")
	var public_text := JSON.stringify(PlayModel.table_presence_proposal(hidden_run, hidden_run.current_environment, "blackjack", "spotter")).to_lower()
	for forbidden in ["rng_state", "seed_value", "traitor", "betrayal", "heist_hidden", "free_heist_use", "selection_weight", "grievance_weight"]:
		if public_text.contains(forbidden): failures.append("Play proposal leaked hidden state: %s." % forbidden)


func _run(seed: String, game_id: String):
	var run := RunStateScript.new()
	run.start_new(seed)
	run.bankroll = 500
	var presence: Array = []
	for member_id in MEMBERS:
		run.crew_add_trust(member_id, CrewState.rank_threshold("made"), "fixture")
		presence.append({"member_id": member_id, "rank": "made", "line": "fixture"})
	run.set_environment({
		"id": "grand_casino_fixture", "archetype_id": "grand_casino", "world_node_id": "grand_casino", "kind": "casino",
		"active_game_id": game_id, "crew_presence": presence, "game_states": {game_id: {"running_count": 0, "recorded_running_count": 0}},
		"economic_profile": {"stake_floor": 5, "stake_ceiling": 100}, "security_profile": {"strictness": "high"}, "turns": 0,
	})
	return run


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
