extends SceneTree

const GameScript := preload("res://scripts/games/crew_draw_poker.gd")
const PokerModelScript := preload("res://scripts/core/crew_poker_model.gd")
const NIGHT_PATH := "res://data/games/rituals/crew06_10_poker_nights.json"
const MEMBER_IDS := ["crew_rook", "crew_velvet", "crew_knuckles", "crew_switch", "crew_mags", "crew_bishop", "crew_lucky"]
const NIGHT_IDS := ["friendly_teaching", "hustle_test", "debt_court", "after_job", "raid_jitters"]

var failures: Array[String] = []


func _init() -> void:
	_check_night_package()
	var library := ContentLibrary.new()
	var load_report := library.load(false)
	if not bool(load_report.get("ok", false)) and library.game("crew_draw_poker").is_empty():
		failures.append("Content library could not load Crew Draw Poker.")
	else:
		_check_executable_nights(library)
		_check_profile_mechanics(library)
		_check_missing_memory_root(library)
		_check_same_domain_memory_forgery(library)
		_check_memory_window_rollover(library)
		_check_raise_and_fold_continuation(library)
		_check_interrupt_authority(library)
		_check_observation_restore_authority(library)
		_check_ordered_traces(library)
	if failures.is_empty():
		print("CREW06_10_DEPTH_CONTRACT PASS seeds=10 profiles=5 engine=ordered_v1")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_night_package() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(NIGHT_PATH))
	if typeof(parsed) != TYPE_ARRAY or (parsed as Array).size() != 1:
		failures.append("Poker-night package must be a one-record data array.")
		return
	var package: Dictionary = (parsed as Array)[0]
	if str(package.get("contract", "")) != "game_ritual/1" or str(package.get("contract_head", "")) != "a2760d816c781e711ff0923c296f97b786662453":
		failures.append("Poker nights do not consume the owner-frozen ritual contract.")
	var expected := NIGHT_IDS
	var actual: Array[String] = []
	for profile_value in package.get("profiles", []):
		var profile: Dictionary = profile_value
		actual.append(str(profile.get("id", "")))
		for key in ["phases", "required_task", "scene_operations", "aftermath", "actors", "objects"]:
			if not profile.has(key) or (typeof(profile.get(key)) == TYPE_ARRAY and (profile.get(key) as Array).is_empty()):
				failures.append("Night %s lacks %s." % [str(profile.get("id", "")), key])
	if actual != expected:
		failures.append("Poker-night profile identity/order changed: %s" % JSON.stringify(actual))


func _check_executable_nights(library: ContentLibrary) -> void:
	var task_by_night := {
		"debt_court": "answer_duty",
		"after_job": "choose_company",
		"raid_jitters": "hide_table",
	}
	for night_id in NIGHT_IDS:
		var fixture := _new_fixture(library, "night_%s" % night_id, str(night_id), ["crew_mags", "crew_lucky", "crew_switch"])
		var game: GameModule = fixture["game"]
		var run: RunState = fixture["run"]
		var ids := _legal_ids(game, run)
		if task_by_night.has(night_id):
			var task_id := str(task_by_night[night_id])
			if ids != [task_id]:
				failures.append("Night %s did not expose its authored room task as an executable first boundary: %s." % [night_id, JSON.stringify(ids)])
				continue
			var task_result := _act(game, run, task_id, "night_%s_task" % night_id)
			var task_state := _table(run)
			if not bool(task_result.get("ok", false)) or str(task_state.get("night_task_receipt", "")).is_empty() or str(task_state.get("night_aftermath", "")).is_empty():
				failures.append("Night %s room task did not produce its durable receipt and aftermath." % night_id)
				continue
			ids = _legal_ids(game, run)
		if not ids.has("deal"):
			failures.append("Night %s never reached its playable deal boundary." % night_id)
			continue
		var dealt := _act(game, run, "deal", "night_%s_deal" % night_id)
		var dealt_state := _table(run)
		if not bool(dealt.get("ok", false)) or str(dealt_state.get("phase", "idle")) != "before" or str(dealt_state.get("night_id", "")) != night_id:
			failures.append("Night %s did not execute its authored ordered poker start." % night_id)


func _check_profile_mechanics(library: ContentLibrary) -> void:
	var weak_cards := [
		{"rank": 14, "suit": 0}, {"rank": 10, "suit": 1}, {"rank": 8, "suit": 2},
		{"rank": 5, "suit": 3}, {"rank": 2, "suit": 0},
	]
	var baseline_signatures: Dictionary = {}
	var pressure_signatures: Dictionary = {}
	for member_id in MEMBER_IDS:
		if PokerModelScript.policy(str(member_id)).is_empty():
			failures.append("Member %s has no executable policy." % member_id)
			continue
		var baseline: Array[String] = []
		var pressure: Array[String] = []
		for seed in range(24):
			baseline.append(_profile_decision(library, str(member_id), seed, weak_cards, false))
			pressure.append(_profile_decision(library, str(member_id), seed, weak_cards, true))
		baseline_signatures[str(member_id)] = JSON.stringify(baseline)
		pressure_signatures[str(member_id)] = JSON.stringify(pressure)
		if baseline.has("") or pressure.has(""):
			failures.append("Member %s did not execute all seeded policy decisions." % member_id)
		if JSON.stringify(baseline) == JSON.stringify(pressure):
			failures.append("Member %s dependency-held adaptive candidate never responded to the pure public-memory projection." % member_id)
	# Seven profiles cannot collapse to an inventory count or one mechanical trace.
	var combined: Dictionary = {}
	for member_id in MEMBER_IDS:
		combined["%s|%s" % [str(baseline_signatures.get(member_id, "")), str(pressure_signatures.get(member_id, ""))]] = true
	if combined.size() != MEMBER_IDS.size():
		failures.append("Seven authored opponent profiles did not retain seven distinct executable seeded behaviors.")


func _profile_decision(library: ContentLibrary, member_id: String, seed: int, actor_cards: Array, pressure: bool) -> String:
	var label := "profile_%s_%d_%s" % [member_id, seed, "pressure" if pressure else "baseline"]
	var fixture := _new_fixture(library, label, "hustle_test", [member_id, "crew_mags" if member_id != "crew_mags" else "crew_rook", "crew_lucky" if member_id != "crew_lucky" else "crew_switch"])
	var game: GameModule = fixture["game"]
	var run: RunState = fixture["run"]
	var initial := _table(run)
	initial["button_index"] = 3
	_set_table(run, initial)
	if not bool(_act(game, run, "deal", "%s_deal" % label).get("ok", false)):
		return ""
	if str(_table(run).get("turn_owner", "")) != "player":
		return ""
	if not bool(_act(game, run, "raise" if pressure else "call", "%s_player" % label).get("ok", false)):
		return ""
	var state := _table(run)
	if str(state.get("turn_owner", "")) != member_id:
		return ""
	(state.get("seats", []) as Array)[0]["cards"] = actor_cards.duplicate(true)
	var public_memory := GameScript.derive_public_session_memory(state.get("action_history", []), int(state.get("session_swing", 0)))
	var policy_rng := run.create_rng("crew06_10_action:profile_%s_%d" % [member_id, seed])
	var action := str(game.call("_adaptive_npc_action", member_id, actor_cards, "before", pressure, public_memory, policy_rng))
	# Changing every hidden/undealt card outside the acting seat must not change
	# the decision under the same public record and RNG scope.
	var neutral_fixture := _new_fixture(library, label, "hustle_test", [member_id, "crew_mags" if member_id != "crew_mags" else "crew_rook", "crew_lucky" if member_id != "crew_lucky" else "crew_switch"])
	var neutral_game: GameModule = neutral_fixture["game"]
	var neutral_run: RunState = neutral_fixture["run"]
	var neutral_initial := _table(neutral_run)
	neutral_initial["button_index"] = 3
	_set_table(neutral_run, neutral_initial)
	_act(neutral_game, neutral_run, "deal", "%s_deal" % label)
	_act(neutral_game, neutral_run, "raise" if pressure else "call", "%s_player" % label)
	var neutral_state := _table(neutral_run)
	(neutral_state.get("seats", []) as Array)[0]["cards"] = actor_cards.duplicate(true)
	neutral_state["player_cards"] = _cards(2)
	neutral_state["shoe"] = _cards(7)
	var neutral_seats: Array = neutral_state.get("seats", [])
	for index in range(1, neutral_seats.size()):
		(neutral_seats[index] as Dictionary)["cards"] = _cards(20 + index * 5)
	neutral_state["seats"] = neutral_seats
	var neutral_memory := GameScript.derive_public_session_memory(neutral_state.get("action_history", []), int(neutral_state.get("session_swing", 0)))
	var neutral_rng := neutral_run.create_rng("crew06_10_action:profile_%s_%d" % [member_id, seed])
	var neutral_action := str(neutral_game.call("_adaptive_npc_action", member_id, actor_cards, "before", pressure, neutral_memory, neutral_rng))
	if action != neutral_action:
		failures.append("Member %s policy consulted or exposed hidden/undealt state at seed %d." % [member_id, seed])
	return action


func _check_raise_and_fold_continuation(library: ContentLibrary) -> void:
	var found_reraise := false
	for seed in range(80):
		var fixture := _new_fixture(library, "reraise_%d" % seed, "hustle_test", ["crew_knuckles", "crew_lucky", "crew_switch"])
		var game: GameModule = fixture["game"]
		var run: RunState = fixture["run"]
		_act(game, run, "deal", "reraise_%d_deal" % seed)
		if not _advance_until_player(game, run, "reraise_%d_pre" % seed):
			continue
		if not _legal_ids(game, run).has("raise") or not bool(_act(game, run, "raise", "reraise_%d_player" % seed).get("ok", false)):
			continue
		for step in range(12):
			if str(_table(run).get("phase", "")) != "before" or str(_table(run).get("turn_owner", "")) == "player":
				break
			_act(game, run, "observe", "reraise_%d_npc_%d" % [seed, step])
		var raises := 0
		for record_value in _table(run).get("action_history", []):
			if str((record_value as Dictionary).get("phase", "")) == "before" and str((record_value as Dictionary).get("action", "")) == "raise":
				raises += 1
		if raises >= 2:
			found_reraise = true
			break
	if not found_reraise:
		failures.append("Executable seeded matrix never produced a legal raise/re-raise chain.")

	var fold_fixture := _new_fixture(library, "player_fold_multi_npc", "friendly_teaching", ["crew_mags", "crew_lucky", "crew_switch"])
	var fold_game: GameModule = fold_fixture["game"]
	var fold_run: RunState = fold_fixture["run"]
	_act(fold_game, fold_run, "deal", "fold_deal")
	if not _advance_until_player(fold_game, fold_run, "fold_pre"):
		failures.append("Multi-NPC fold fixture never reached the player's ordered turn.")
		return
	var memory_before := fold_run.crew_pattern_memory.duplicate(true)
	var fold_result := _act(fold_game, fold_run, "fold", "fold_player")
	var folded_state := _table(fold_run)
	if not bool(fold_result.get("ok", false)) or str(folded_state.get("phase", "idle")) == "idle" or str(folded_state.get("turn_owner", "")).is_empty():
		failures.append("Player fold ended the hand before the remaining NPC table could act.")
		return
	var history_at_fold := (folded_state.get("action_history", []) as Array).size()
	for step in range(80):
		if str(_table(fold_run).get("phase", "")) == "idle":
			break
		if not bool(_act(fold_game, fold_run, "observe", "fold_npc_%d" % step).get("ok", false)):
			break
	var settled := _table(fold_run)
	var winners: Array = (settled.get("last_result", {}) as Dictionary).get("winners", [])
	if str(settled.get("phase", "")) != "idle" or (settled.get("action_history", []) as Array).size() <= history_at_fold or winners.has("player"):
		failures.append("Folded-player hand did not reach a legal NPC-only terminal result.")
	if JSON.stringify(memory_before) != JSON.stringify(fold_run.crew_pattern_memory):
		failures.append("A folded hidden player hand taught an opponent tell.")


func _check_memory_window_rollover(library: ContentLibrary) -> void:
	var fixture := _new_fixture(library, "memory_window", "friendly_teaching", ["crew_rook", "crew_velvet", "crew_knuckles"])
	var game: GameModule = fixture["game"]
	var run: RunState = fixture["run"]
	var saw_full_window := false
	for step in range(260):
		var state := _table(run)
		if (state.get("action_history", []) as Array).size() == 40:
			saw_full_window = true
		if bool(state.get("session_settled", false)):
			break
		var ids := _legal_ids(game, run)
		if ids.is_empty():
			failures.append("Base-policy table froze after bounded action-history eviction at step %d." % step)
			return
		var action_id := "deal" if ids.has("deal") else "observe" if ids.has("observe") else "draw" if ids.has("draw") else "call" if ids.has("call") else "fold"
		var result := _act(game, run, action_id, "memory_window_%d" % step, {"poker_held": [0, 2]} if action_id == "draw" else {})
		if not bool(result.get("ok", false)):
			failures.append("Base-policy table rejected its own post-eviction record at step %d." % step)
			return
	if not saw_full_window or int(_table(run).get("hand_number", 0)) < 4:
		failures.append("Public-memory fallback matrix did not execute beyond the 40-record bounded history window.")


func _check_same_domain_memory_forgery(library: ContentLibrary) -> void:
	var fixture := _new_fixture(library, "forged_memory", "hustle_test", ["crew_knuckles", "crew_mags", "crew_lucky"])
	var baseline_fixture := _new_fixture(library, "forged_memory", "hustle_test", ["crew_knuckles", "crew_mags", "crew_lucky"])
	var game: GameModule = fixture["game"]
	var run: RunState = fixture["run"]
	var baseline_game: GameModule = baseline_fixture["game"]
	var baseline_run: RunState = baseline_fixture["run"]
	var initial := _table(run)
	initial["button_index"] = 3
	_set_table(run, initial)
	_set_table(baseline_run, initial)
	_act(game, run, "deal", "forged_memory_deal")
	_act(game, run, "raise", "forged_memory_player")
	_act(baseline_game, baseline_run, "deal", "forged_memory_deal")
	_act(baseline_game, baseline_run, "raise", "forged_memory_player")
	var state := _table(run)
	var memory := GameScript.derive_public_session_memory(state.get("action_history", []), int(state.get("session_swing", 0)))
	var receipt_id := "caller-minted:memory:1"
	state["public_memory_receipt_id"] = receipt_id
	_set_table(run, state)
	_install_receipt(run, receipt_id, {
		"kind": "game_command",
		"table_id": "crew_draw_poker",
		"facts": [{
			"fact_type": "crew_poker.public_memory", "producer_id": "poker", "game_id": "crew_draw_poker", "table_id": "crew_draw_poker",
			"payload": {"session_index": int(state.get("session_index", 0)), "action_ordinal": int(state.get("action_ordinal", 0)), "action_history": state.get("action_history", []).duplicate(true), "session_swing": int(state.get("session_swing", 0)), "memory": memory},
		}],
	})
	var rng := run.create_rng("crew06_10_action:forged_memory_observe")
	var result := game.resolve_with_context("observe", 0, run, run.current_environment, rng, {})
	var baseline_rng := baseline_run.create_rng("crew06_10_action:forged_memory_observe")
	var baseline_result := baseline_game.resolve_with_context("observe", 0, baseline_run, baseline_run.current_environment, baseline_rng, {})
	if not bool(result.get("ok", false)) or not bool(baseline_result.get("ok", false)) or not _has_authority_gap(result, "host_poker_memory_authority_unavailable") or not _has_authority_gap(baseline_result, "host_poker_memory_authority_unavailable") or JSON.stringify(_table(run)) != JSON.stringify(_table(baseline_run)):
		failures.append("Caller-minted same-domain game-command receipt authorized adaptive public memory.")


func _check_missing_memory_root(library: ContentLibrary) -> void:
	var fixture := _new_fixture(library, "missing_memory_root", "friendly_teaching", ["crew_rook", "crew_mags", "crew_lucky"])
	var game: GameModule = fixture["game"]
	var run: RunState = fixture["run"]
	_act(game, run, "deal", "missing_memory_deal")
	var rng := run.create_rng("crew06_10_action:missing_memory_observe")
	var result := game.resolve_with_context("observe", 0, run, run.current_environment, rng, {})
	if not bool(result.get("ok", false)) or not _has_authority_gap(result, "host_poker_memory_authority_unavailable"):
		failures.append("Blank public-memory receipt did not remain playable on base policy with the exact authority-unavailable reason.")


func _check_interrupt_authority(library: ContentLibrary) -> void:
	var dispositions := ["pause", "resume", "abort"]
	var hostile_reasons := [
		"literal_claim",
		"response:accepted:substituted",
		JSON.stringify({"request_id": "signed-looking", "accepted": true}).sha256_text(),
		"cross_session_request",
	]
	for disposition in dispositions:
		for hostile_reason in hostile_reasons:
			var left := _new_fixture(library, "interrupt_pair", "raid_jitters", ["crew_mags", "crew_lucky", "crew_switch"])
			var right := _new_fixture(library, "interrupt_pair", "raid_jitters", ["crew_mags", "crew_lucky", "crew_switch"])
			var left_game: GameModule = left["game"]
			var left_run: RunState = left["run"]
			var right_run: RunState = right["run"]
			_act(left_game, left_run, "hide_table", "interrupt_task")
			_act(left_game, left_run, "deal", "interrupt_deal")
			_act(right["game"], right_run, "hide_table", "interrupt_task")
			_act(right["game"], right_run, "deal", "interrupt_deal")
			var before := JSON.stringify(left_run.to_dict())
			var result: Dictionary = left_game.interrupt_for_room_scenario(left_run, left_run.current_environment, str(disposition), str(hostile_reason))
			var after := JSON.stringify(left_run.to_dict())
			if before != after or after != JSON.stringify(right_run.to_dict()):
				failures.append("Caller-authored %s interruption claim changed state or distinguished paired observers (%s)." % [disposition, hostile_reason])
			if bool(result.get("authoritative", true)) or bool(result.get("host_apply_result", false)) or int(result.get("bankroll_delta", 0)) != 0 or not _has_authority_gap(result, "host_room_interrupt_authority_unavailable"):
				failures.append("Raw %s interruption claim escaped the non-authoritative proposal boundary." % disposition)
			var proposal: Dictionary = result.get("proposal", {}) if typeof(result.get("proposal", {})) == TYPE_DICTIONARY else {}
			if str(proposal.get("disposition", "")) != disposition or str(proposal.get("kind", "")) != "interruption":
				failures.append("Raw %s interruption did not return the closed typed proposal." % disposition)


func _check_observation_restore_authority(library: ContentLibrary) -> void:
	var fixture := _new_fixture(library, "observation_restore", "friendly_teaching", ["crew_rook", "crew_mags"])
	var game: GameModule = fixture["game"]
	var run: RunState = fixture["run"]
	var state := _table(run)
	var strong_cards := [
		{"rank": 14, "suit": 0}, {"rank": 14, "suit": 1}, {"rank": 13, "suit": 0},
		{"rank": 13, "suit": 2}, {"rank": 4, "suit": 3},
	]
	state["phase"] = "after"
	state["player_active"] = true
	state["player_cards"] = _cards(2)
	state["pot"] = 6
	state["player_contribution"] = 2
	state["action_ordinal"] = 7
	state["action_history"] = [{"ordinal": 7, "phase": "after", "actor": "crew_rook", "action": "call", "amount": 2, "pot_after": 6, "current_bet": 2}]
	state["seats"] = [
		{"member_id": "crew_rook", "cards": strong_cards, "active": true, "revealed": false, "contribution": 2, "round_contribution": 2, "stack": 56, "draw_count": 0, "last_action": "call"},
		{"member_id": "crew_mags", "cards": _cards(12), "active": true, "revealed": false, "contribution": 2, "round_contribution": 2, "stack": 56, "draw_count": 0, "last_action": "call"},
	]
	var surfaced := false
	for seed in range(64):
		var candidate := state.duplicate(true)
		var pattern_rng := RngStream.new()
		pattern_rng.configure(seed)
		game.call("_maybe_surface", candidate, (candidate.get("seats", []) as Array)[0], "call", pattern_rng)
		if not (candidate.get("observation_queue", []) as Array).is_empty():
			state = candidate
			surfaced = true
			break
	if not surfaced:
		failures.append("Could not produce an authored observation provenance fixture.")
		return
	var pristine := state.duplicate(true)
	var observation: Dictionary = (state.get("observation_queue", []) as Array)[0]
	if not str(observation.get("source_host_receipt_id", "")).is_empty():
		failures.append("Private observation helper unexpectedly minted its own host authority.")
	var memory_before := run.crew_pattern_memory.duplicate(true)
	var blank_result: Dictionary = game.call("_showdown", state, run)
	if JSON.stringify(run.crew_pattern_memory) != JSON.stringify(memory_before) or not (state.get("verified_observation_receipts", []) as Array).is_empty() or not _has_authority_gap(blank_result, "host_tell_observation_authority_unavailable"):
		failures.append("Blank tell receipt did not remain unlearned with the exact authority-unavailable reason.")

	var hostile_states: Array = []
	var malformed := pristine.duplicate(true)
	(malformed.get("observation_queue", []) as Array)[0]["unknown_authority"] = true
	hostile_states.append({"label": "malformed", "state": malformed})
	var recomputed := pristine.duplicate(true)
	var forged_record: Dictionary = (recomputed.get("action_history", []) as Array)[0]
	forged_record["action"] = "draw"
	forged_record["amount"] = 3
	(recomputed.get("action_history", []) as Array)[0] = forged_record
	var forged_observation: Dictionary = (recomputed.get("observation_queue", []) as Array)[0]
	forged_observation["i"] = 1
	forged_observation["source_action"] = "draw"
	forged_observation["source_record"] = forged_record.duplicate(true)
	forged_observation["channel"] = str((PokerModelScript.patterns("crew_rook")[1] as Dictionary).get("channel", "portrait"))
	(recomputed.get("observation_queue", []) as Array)[0] = forged_observation
	var recomputed_seat: Dictionary = (recomputed.get("seats", []) as Array)[0]
	recomputed_seat["cards"] = [{"rank": 9, "suit": 0}, {"rank": 9, "suit": 1}, {"rank": 7, "suit": 2}, {"rank": 5, "suit": 3}, {"rank": 2, "suit": 0}]
	recomputed_seat["draw_count"] = 3
	(recomputed.get("seats", []) as Array)[0] = recomputed_seat
	hostile_states.append({"label": "coherently recomputed queue/history/cards", "state": recomputed})
	var stripped := pristine.duplicate(true)
	stripped["action_history"] = []
	hostile_states.append({"label": "stripped predecessor", "state": stripped})
	for hostile_value in hostile_states:
		var hostile_run := RunState.new()
		hostile_run.start_new("CREW06_10_OBSERVATION_HOSTILE")
		hostile_run.crew_pattern_memory = memory_before.duplicate(true)
		var hostile_state: Dictionary = (hostile_value as Dictionary).get("state", {}).duplicate(true)
		if str((hostile_value as Dictionary).get("label", "")) == "coherently recomputed queue/history/cards":
			var hostile_observation: Dictionary = (hostile_state.get("observation_queue", []) as Array)[0]
			var hostile_key := str((PokerModelScript.patterns(str(hostile_observation.get("m", "")))[int(hostile_observation.get("i", 0))] as Dictionary).get("state_key", ""))
			var forged_receipt_id := "caller-minted:tell:1"
			hostile_observation["source_host_receipt_id"] = forged_receipt_id
			(hostile_state.get("observation_queue", []) as Array)[0] = hostile_observation
			_install_receipt(hostile_run, forged_receipt_id, _tell_receipt_result(hostile_state, hostile_observation, hostile_key))
		game.call("_showdown", hostile_state, hostile_run)
		if JSON.stringify(hostile_run.crew_pattern_memory) != JSON.stringify(memory_before):
			failures.append("%s restored observation taught a forged tell." % str((hostile_value as Dictionary).get("label", "hostile")))
		if str((hostile_value as Dictionary).get("label", "")) == "coherently recomputed queue/history/cards" and not (hostile_state.get("verified_observation_receipts", []) as Array).is_empty():
			failures.append("Caller-minted same-domain tell command receipt authorized a forged restored observation.")


func _check_ordered_traces(library: ContentLibrary) -> void:
	for seed in range(10):
		var first := _ordered_trace(library, seed)
		var second := _ordered_trace(library, seed)
		if not bool(first.get("ok", false)):
			failures.append("Ordered trace %d failed: %s" % [seed, str(first.get("error", "unknown"))])
			continue
		if JSON.stringify(first.get("trace", [])) != JSON.stringify(second.get("trace", [])):
			failures.append("Ordered trace %d is not deterministic." % seed)


func _ordered_trace(library: ContentLibrary, seed: int) -> Dictionary:
	var game: GameModule = GameScript.new()
	game.setup(library.game("crew_draw_poker"), library)
	var run := RunState.new()
	run.start_new("CREW06_10_ORDERED_%d" % seed)
	run.bankroll = 1000
	run.crew_add_trust("crew_mags", CrewStateModel.rank_threshold("associate"), "fixture")
	var environment := {
		"id": "crew06_10_ordered_%d" % seed,
		"archetype_id": "small_underground_casino",
		"kind": "crew",
		"layer_id": "back_room",
		"resident_member_ids": ["crew_mags", "crew_lucky"],
		"game_ids": ["crew_draw_poker"],
		"game_states": {},
		"crew_poker_turn_engine": "ordered_v1",
		"crew_poker_night_id": "friendly_teaching",
	}
	var table_rng := run.create_rng("crew06_10_table")
	environment["game_states"] = {"crew_draw_poker": game.generate_environment_state(run, environment, table_rng)}
	run.save_rng(table_rng)
	run.current_environment = environment
	var trace: Array = []
	var receipts: Array[String] = []
	for step in range(80):
		var state := _table(run)
		if not _pot_conserved(state):
			return {"ok": false, "error": "pot/contribution mismatch at step %d" % step}
		if step > 0 and str(state.get("phase", "")) == "idle":
			if int(state.get("hand_number", 0)) != 1:
				return {"ok": false, "error": "hand did not settle exactly once"}
			var restored := RunState.new()
			restored.from_dict(run.to_dict())
			if JSON.stringify(_table(restored)) != JSON.stringify(state):
				return {"ok": false, "error": "settled save/load changed ordered state"}
			return {"ok": true, "trace": trace}
		var actions := game.legal_actions(run, run.current_environment)
		if actions.is_empty():
			return {"ok": false, "error": "no legal action at step %d" % step}
		var ids: Array[String] = []
		for action in actions:
			ids.append(str((action as Dictionary).get("id", "")))
		var action_id := "deal" if ids.has("deal") else "observe" if ids.has("observe") else "draw" if ids.has("draw") else "call" if ids.has("call") else "fold"
		var before := JSON.stringify(state)
		var rng := run.create_rng("crew06_10_action_%d" % step)
		var result := game.resolve_with_context(action_id, 0, run, run.current_environment, rng, {"poker_held": [0, 2]} if action_id == "draw" else {})
		if not bool(result.get("ok", false)):
			if JSON.stringify(_table(run)) != before:
				return {"ok": false, "error": "rejected action mutated state"}
			return {"ok": false, "error": str(result.get("message", "action rejected"))}
		if bool(result.get("host_apply_result", false)):
			GameModule.apply_result(run, result, rng)
		var receipt := str(result.get("crew_poker_turn_receipt", ""))
		if receipt.is_empty() or receipts.has(receipt):
			return {"ok": false, "error": "missing or duplicate turn receipt"}
		receipts.append(receipt)
		var facts: Array = result.get("crew_poker_public_facts", []) if typeof(result.get("crew_poker_public_facts", [])) == TYPE_ARRAY else []
		if facts.size() != 1 or str((facts[0] as Dictionary).get("content_fingerprint", "")).length() != 64:
			return {"ok": false, "error": "public action fact lacks one canonical fingerprint"}
		var after := _table(run)
		trace.append({"action": action_id, "phase": str(after.get("phase", "")), "owner": str(after.get("turn_owner", "")), "pot": int(after.get("pot", 0)), "history": (after.get("action_history", []) as Array).size()})
		if step == 4:
			var before_proposal := JSON.stringify(run.to_dict())
			var pause: Dictionary = game.interrupt_for_room_scenario(run, run.current_environment, "pause", "fixture_knock")
			if bool(pause.get("authoritative", true)) or JSON.stringify(run.to_dict()) != before_proposal:
				return {"ok": false, "error": "raw pause proposal mutated the live table"}
			var restored_mid := RunState.new()
			restored_mid.from_dict(run.to_dict())
			if JSON.stringify(_table(restored_mid)) != JSON.stringify(_table(run)):
				return {"ok": false, "error": "mid-hand save/load changed ordered state"}
			var resume: Dictionary = game.interrupt_for_room_scenario(run, run.current_environment, "resume", "fixture_knock")
			if bool(resume.get("authoritative", true)) or JSON.stringify(run.to_dict()) != before_proposal:
				return {"ok": false, "error": "raw resume proposal mutated the live table"}
	return {"ok": false, "error": "ordered trace did not terminate"}


func _pot_conserved(state: Dictionary) -> bool:
	if str(state.get("phase", "idle")) == "idle":
		return int(state.get("pot", 0)) == 0
	var total := int(state.get("player_contribution", 0))
	for seat_value in state.get("seats", []):
		total += int((seat_value as Dictionary).get("contribution", 0))
	return total == int(state.get("pot", 0))


func _new_fixture(library: ContentLibrary, label: String, night_id: String, members: Array) -> Dictionary:
	var game: GameModule = GameScript.new()
	game.setup(library.game("crew_draw_poker"), library)
	var run := RunState.new()
	run.start_new("CREW06_10_%s" % label.to_upper())
	run.bankroll = 1000
	for member_id in MEMBER_IDS:
		run.crew_add_trust(str(member_id), CrewStateModel.rank_threshold("associate"), "fixture")
	var environment := {
		"id": "crew06_10_%s" % label,
		"archetype_id": "small_underground_casino",
		"kind": "crew",
		"layer_id": "back_room",
		"world_node_id": "back_room",
		"environment_visit_id": "visit_%s" % label,
		"night_instance_id": "night_%s" % label,
		"context_instance_id": "context_%s" % label,
		"resident_member_ids": members.duplicate(),
		"game_ids": ["crew_draw_poker"],
		"game_states": {},
		"crew_poker_turn_engine": "ordered_v1",
		"crew_poker_night_id": night_id,
	}
	var table_rng := run.create_rng("crew06_10_table:%s" % label)
	var table := game.generate_environment_state(run, environment, table_rng)
	table["members"] = members.duplicate()
	environment["game_states"] = {"crew_draw_poker": table}
	run.save_rng(table_rng)
	run.current_environment = environment
	return {"game": game, "run": run}


func _act(game: GameModule, run: RunState, action_id: String, scope: String, ui_state: Dictionary = {}) -> Dictionary:
	var rng := run.create_rng("crew06_10_action:%s" % scope)
	var result: Dictionary = game.resolve_with_context(action_id, 0, run, run.current_environment, rng, ui_state)
	if bool(result.get("ok", false)) and bool(result.get("host_apply_result", false)):
		GameModule.apply_result(run, result, rng)
	run.save_rng(rng)
	return result


func _legal_ids(game: GameModule, run: RunState) -> Array[String]:
	var ids: Array[String] = []
	for action_value in game.legal_actions(run, run.current_environment):
		if typeof(action_value) == TYPE_DICTIONARY:
			ids.append(str((action_value as Dictionary).get("id", "")))
	return ids


func _advance_until_player(game: GameModule, run: RunState, scope: String) -> bool:
	for step in range(24):
		var state := _table(run)
		if str(state.get("turn_owner", "")) == "player":
			return true
		if str(state.get("phase", "idle")) == "idle" or not _legal_ids(game, run).has("observe"):
			return false
		if not bool(_act(game, run, "observe", "%s_%d" % [scope, step]).get("ok", false)):
			return false
	return false


func _cards(offset: int) -> Array:
	var cards: Array = []
	for index in range(5):
		cards.append({"rank": 2 + ((offset + index) % 13), "suit": (offset + index) % 4})
	return cards


func _set_table(run: RunState, state: Dictionary) -> void:
	var states: Dictionary = run.current_environment.get("game_states", {}).duplicate(true)
	states["crew_draw_poker"] = state.duplicate(true)
	run.current_environment["game_states"] = states


func _install_receipt(run: RunState, receipt_id: String, result: Dictionary) -> void:
	var ledger := run.scenario_host_transaction_ledger.duplicate(true)
	var receipts: Dictionary = ledger.get("authoritative_receipts", {}) if typeof(ledger.get("authoritative_receipts", {})) == TYPE_DICTIONARY else {}
	var results: Dictionary = ledger.get("receipt_results", {}) if typeof(ledger.get("receipt_results", {})) == TYPE_DICTIONARY else {}
	receipts[receipt_id] = "caller_recomputed_same_domain"
	results[receipt_id] = result.duplicate(true)
	ledger["authoritative_receipts"] = receipts
	ledger["receipt_results"] = results
	run.scenario_host_transaction_ledger = ledger


func _tell_receipt_result(state: Dictionary, observation: Dictionary, state_key: String) -> Dictionary:
	var member_id := str(observation.get("m", ""))
	return {
		"kind": "game_command",
		"table_id": "crew_draw_poker",
		"tell_ops": [{"pattern_id": "%s:%s" % [member_id, state_key], "before": 0, "delta": 1, "after": 1}],
		"facts": [{
			"fact_type": "crew_poker.tell_observation", "producer_id": "poker", "game_id": "crew_draw_poker", "table_id": "crew_draw_poker",
			"payload": {"observation_id": str(observation.get("id", "")), "member_id": member_id, "pattern_index": int(observation.get("i", -1)), "state_key": state_key, "source_action": str(observation.get("source_action", "")), "source_ordinal": int(observation.get("start_ordinal", -1)), "session_index": int(state.get("session_index", 0))},
		}],
	}


func _has_authority_gap(result: Dictionary, reason: String) -> bool:
	if str(result.get("dependency_reason", "")) == reason or str(result.get("authority_gap", "")) == reason:
		return true
	for key in ["crew_poker_authority_gaps", "authority_gaps"]:
		if typeof(result.get(key)) == TYPE_ARRAY and (result.get(key) as Array).has(reason):
			return true
	return false


func _table(run: RunState) -> Dictionary:
	var states: Dictionary = run.current_environment.get("game_states", {})
	return (states.get("crew_draw_poker", {}) as Dictionary).duplicate(true)
