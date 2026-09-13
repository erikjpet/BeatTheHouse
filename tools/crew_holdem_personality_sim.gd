extends SceneTree

# Deterministic statistical audit for the production Crew Hold'em module. Player
# bots use only their hole cards, the public board, and the module's legal actions.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const GameModuleScript := preload("res://scripts/core/game_module.gd")
const CrewPokerGameScript := preload("res://scripts/games/crew_draw_poker.gd")
const CrewPokerModelScript := preload("res://scripts/core/crew_poker_model.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")

const OUTPUT_ROOT := "res://.tmp/backroom_poker_tweaks/personality_sim"
const PLAYER_BOTS: Array[String] = ["passive_caller", "tight_folder", "aggro_raiser", "random_legal", "balanced"]
const TARGET_BANDS := {
	"crew_rook": {"vpip": [30.0, 47.0], "pfr": [2.0, 12.0], "af": [0.50, 1.50], "wtsd": [75.0, 100.0], "bluff_share": [0.0, 6.0], "bet_size": [0.25, 0.55]},
	"crew_velvet": {"vpip": [38.0, 56.0], "pfr": [16.0, 34.0], "af": [2.00, 4.50], "wtsd": [80.0, 100.0], "bluff_share": [6.0, 20.0], "bet_size": [0.45, 0.85]},
	"crew_knuckles": {"vpip": [72.0, 92.0], "pfr": [45.0, 72.0], "af": [3.00, 7.00], "wtsd": [85.0, 100.0], "bluff_share": [18.0, 38.0], "bet_size": [0.90, 1.80]},
	"crew_switch": {"vpip": [45.0, 65.0], "pfr": [20.0, 42.0], "af": [2.00, 4.50], "wtsd": [75.0, 100.0], "bluff_share": [5.0, 20.0], "bet_size": [0.30, 0.75]},
	"crew_mags": {"vpip": [28.0, 45.0], "pfr": [10.0, 26.0], "af": [1.00, 2.70], "wtsd": [80.0, 100.0], "bluff_share": [0.0, 7.0], "bet_size": [0.45, 0.85]},
	"crew_bishop": {"vpip": [35.0, 55.0], "pfr": [12.0, 30.0], "af": [1.80, 4.00], "wtsd": [75.0, 100.0], "bluff_share": [1.0, 12.0], "bet_size": [0.50, 1.00]},
	"crew_lucky": {"vpip": [82.0, 98.0], "pfr": [5.0, 22.0], "af": [0.40, 1.40], "wtsd": [90.0, 100.0], "bluff_share": [0.0, 12.0], "bet_size": [0.35, 0.90]},
}

var _hands_per_bot := 3000
var _label := "final"
var _selected_bots: Array[String] = PLAYER_BOTS.duplicate()
var _fail_on_targets := true
var _verbose := false
var _compile_only := false


func _init() -> void:
	_parse_args()
	var library := ContentLibraryScript.new()
	library.load(true)
	if not library.validation_errors.is_empty():
		push_error("Content failed validation before the personality simulation: %s" % JSON.stringify(library.validation_errors))
		quit(1)
		return
	var game: GameModule = CrewPokerGameScript.new()
	game.setup(library.game("crew_draw_poker"), library)
	if _compile_only:
		print("CREW_HOLDEM_PERSONALITY_SIM_COMPILE_PASS")
		quit(0)
		return
	var started_usec := Time.get_ticks_usec()
	var report := _run_simulation(game)
	report["elapsed_msec"] = float(Time.get_ticks_usec() - started_usec) / 1000.0
	var paths := _write_report(report)
	print("CREW_HOLDEM_PERSONALITY_SIM_%s %s" % ["PASS" if bool(report.get("passed", false)) else "FAIL", JSON.stringify({"json": paths.get("json", ""), "markdown": paths.get("markdown", ""), "hands": report.get("total_hands", 0), "failures": report.get("failures", [])})])
	quit(0 if bool(report.get("passed", false)) else 1)


func _parse_args() -> void:
	for argument in OS.get_cmdline_user_args():
		var value := str(argument)
		if value.begins_with("--hands="):
			_hands_per_bot = maxi(1, int(value.trim_prefix("--hands=")))
		elif value.begins_with("--label="):
			_label = value.trim_prefix("--label=").validate_filename()
		elif value.begins_with("--bots="):
			_selected_bots.clear()
			for bot in value.trim_prefix("--bots=").split(",", false):
				if PLAYER_BOTS.has(bot):
					_selected_bots.append(bot)
		elif value == "--report-only":
			_fail_on_targets = false
		elif value == "--verbose-sim":
			_verbose = true
		elif value == "--compile-only":
			_compile_only = true
	if _selected_bots.is_empty():
		_selected_bots = ["balanced"]


func _run_simulation(game: GameModule) -> Dictionary:
	var lineups := _five_member_lineups()
	lineups.append(CrewStateModelScript.MEMBER_IDS.slice(0, 3))
	var aggregate := _empty_aggregate()
	var by_bot := {}
	var by_bot_lineup := {}
	var decision_times: Array[float] = []
	for bot_index in range(_selected_bots.size()):
		var bot := _selected_bots[bot_index]
		var bot_aggregate := _empty_aggregate()
		var lineup_aggregates := {}
		for hand_index in range(_hands_per_bot):
			var lineup: Array = lineups[hand_index % lineups.size()]
			var lineup_key := JSON.stringify(lineup)
			var seed := 310000 + bot_index * 1000000 + hand_index * 97
			var hand := _play_hand(game, lineup, bot, seed, decision_times)
			_accumulate_hand(bot_aggregate, hand)
			_accumulate_hand(aggregate, hand)
			var lineup_aggregate: Dictionary = lineup_aggregates.get(lineup_key, _empty_aggregate())
			_accumulate_hand(lineup_aggregate, hand)
			lineup_aggregates[lineup_key] = lineup_aggregate
		by_bot[bot] = _finish_aggregate(bot_aggregate)
		var finished_lineups := {}
		for lineup_key in lineup_aggregates.keys():
			finished_lineups[lineup_key] = _finish_aggregate(lineup_aggregates[lineup_key])
		by_bot_lineup[bot] = finished_lineups
	var final_aggregate := _finish_aggregate(aggregate)
	var failures: Array[String] = []
	var distinctness := _distinctness_report((by_bot.get("balanced", {}) as Dictionary).get("members", {})) if _selected_bots.has("balanced") else {}
	var character := _character_report(by_bot)
	var exploit_health := _exploit_report(by_bot, by_bot_lineup)
	var tilt_probe := _tilt_probe()
	var swing_cap_study := _session_cap_study(game) if _hands_per_bot >= 3000 else {"skipped": "Runs with 3,000 or more hands."}
	if _fail_on_targets and _selected_bots.has("balanced") and _hands_per_bot >= 3000:
		var balanced: Dictionary = by_bot.get("balanced", {})
		if float((balanced.get("flow", {}) as Dictionary).get("preflop_uncontested_pct", 100.0)) > 15.0:
			failures.append("Balanced hands won uncontested preflop exceeded 15%.")
		if float((balanced.get("flow", {}) as Dictionary).get("flop_multiway_pct", 0.0)) < 75.0:
			failures.append("Balanced hands seeing a multiway flop fell below 75%.")
		if float((balanced.get("flow", {}) as Dictionary).get("showdown_multiway_pct", 0.0)) < 50.0:
			failures.append("Balanced multiway showdowns fell below 50%.")
		if float((balanced.get("flow", {}) as Dictionary).get("folds_only_pct", 100.0)) > 5.0:
			failures.append("Balanced folds-only hands exceeded 5%.")
		if float((balanced.get("flow", {}) as Dictionary).get("average_actions", 0.0)) <= 12.569:
			failures.append("Balanced actions per hand did not improve over the 12.569 baseline.")
		_check_member_bands(balanced.get("members", {}), failures)
		failures.append_array(distinctness.get("failures", []))
		failures.append_array(character.get("failures", []))
		failures.append_array(exploit_health.get("failures", []))
	if _fail_on_targets:
		failures.append_array(tilt_probe.get("failures", []))
	if _fail_on_targets and int(swing_cap_study.get("incomplete_sessions", 0)) > 0:
		failures.append("The swing-cap study had incomplete sessions.")
	if _fail_on_targets:
		for bot_value in by_bot.values():
			var bot_result: Dictionary = bot_value
			if int(bot_result.get("incomplete", 0)) > 0:
				failures.append("A player-bot run had incomplete hands.")
			if int(bot_result.get("chip_conservation_failures", 0)) > 0:
				failures.append("A player-bot run violated chip conservation.")
	var timing := _timing_summary(decision_times)
	if _fail_on_targets and not decision_times.is_empty():
		if float(timing.get("average_msec", 999.0)) >= 0.5:
			failures.append("Average NPC decision time reached 0.5 ms.")
		if float(timing.get("worst_msec", 999.0)) >= 2.0:
			failures.append("Worst NPC decision time reached 2 ms.")
	return {
		"schema_version": 2,
		"label": _label,
		"hands_per_bot": _hands_per_bot,
		"total_hands": int(final_aggregate.get("hands", 0)),
		"lineup_count": lineups.size(),
		"five_member_lineup_count": lineups.size() - 1,
		"player_bots": _selected_bots,
		"target_bands": TARGET_BANDS,
		"overall": final_aggregate,
		"by_player_bot": by_bot,
		"by_player_bot_lineup": by_bot_lineup,
		"distinctness": distinctness,
		"character_across_bots": character,
		"exploit_health": exploit_health,
		"tilt_probe": tilt_probe,
		"swing_cap_study": swing_cap_study,
		"decision_performance": timing,
		"passed": failures.is_empty(),
		"failures": failures,
	}


func _play_hand(game: GameModule, lineup: Array, bot: String, seed: int, decision_times: Array[float]) -> Dictionary:
	if _verbose:
		print("SIM hand seed=%d bot=%s lineup=%s" % [seed, bot, JSON.stringify(lineup)])
	var run_state := RunStateScript.new()
	run_state.start_new("CREW-PERSONALITY-%d" % seed)
	run_state.bankroll = 500
	for member_id in CrewStateModelScript.MEMBER_IDS:
		run_state.crew_add_trust(str(member_id), CrewStateModelScript.rank_threshold("made"), "personality_sim")
	var environment := {
		"id": "crew_personality_sim",
		"archetype_id": "small_underground_casino",
		"kind": "crew",
		"layer_id": "back_room",
		"crew_poker_turn_engine": "ordered_v1",
		"resident_member_ids": lineup.duplicate(),
		"game_ids": ["crew_draw_poker"],
		"game_states": {},
	}
	var rng := RngStreamScript.new()
	rng.configure(seed)
	var generated: Dictionary = game.generate_environment_state(run_state, environment, rng)
	generated["members"] = lineup.duplicate()
	generated["dealer_member_id"] = _first_unseated(lineup)
	if str(generated.get("dealer_member_id", "")).is_empty() or lineup.has(str(generated.get("dealer_member_id", ""))):
		return {"complete": false, "failure": "dealer_was_seated", "members": lineup}
	environment["game_states"] = {"crew_draw_poker": generated}
	run_state.current_environment = environment
	var bankroll_before := run_state.bankroll
	var deal := _apply(game, run_state, "deal", {}, rng)
	if not bool(deal.get("ok", false)):
		return {"complete": false, "failure": "deal", "members": lineup}
	var table: Dictionary = _table(run_state)
	var expected_chips := _table_chip_total(table)
	var records: Array = []
	var flop_players := 0
	var flop_members: Array[String] = []
	var max_board := 0
	var conservation := expected_chips > 0
	var steps := 0
	while steps < 220:
		table = _table(run_state)
		if _verbose:
			print("SIM step=%d phase=%s owner=%s pot=%d bet=%d" % [steps, str(table.get("phase", "")), str(table.get("turn_owner", "")), int(table.get("pot", 0)), int(table.get("current_bet", 0))])
		conservation = conservation and _table_chip_total(table) == expected_chips
		var phase := str(table.get("phase", "idle"))
		if phase == "idle":
			break
		var board_count := (table.get("community_cards", []) as Array).size()
		max_board = maxi(max_board, board_count)
		if board_count >= 3 and flop_players == 0:
			flop_players = _active_count(table)
			for flop_seat_value in table.get("seats", []):
				if bool((flop_seat_value as Dictionary).get("active", false)):
					flop_members.append(str((flop_seat_value as Dictionary).get("member_id", "")))
		var legal := _legal_ids(game, run_state)
		var action_id := ""
		var ui := {}
		if legal.has("observe"):
			action_id = "observe"
		else:
			var choice := _player_bot_action(bot, game, run_state, seed, steps, legal)
			action_id = str(choice.get("action", ""))
			ui = choice.get("ui", {}) if typeof(choice.get("ui", {})) == TYPE_DICTIONARY else {}
		if action_id.is_empty():
			return {"complete": false, "failure": "no_legal_action", "members": lineup}
		var before_pot := int(table.get("pot", 0))
		var before_history_size := (table.get("action_history", []) as Array).size()
		var before_phase := phase
		var actor := str(table.get("turn_owner", ""))
		var result := _apply(game, run_state, action_id, ui, rng)
		if action_id == "observe":
			decision_times.append(float(int(game.get("last_npc_decision_usec"))) / 1000.0)
		if not bool(result.get("ok", false)):
			return {"complete": false, "failure": action_id, "members": lineup}
		var after := _table(run_state)
		var history: Array = after.get("action_history", []) if typeof(after.get("action_history", [])) == TYPE_ARRAY else []
		if history.size() > 0 and (history.size() != before_history_size or str((history[history.size() - 1] as Dictionary).get("actor", "")) == actor):
			var row: Dictionary = (history[history.size() - 1] as Dictionary).duplicate(true)
			row["pot_before"] = before_pot
			row["phase"] = before_phase
			if not row.has("intent") and actor != "player":
				row["intent"] = _infer_intent(table, actor, str(row.get("action", "")))
			records.append(row)
		steps += 1
	table = _table(run_state)
	conservation = conservation and _table_chip_total(table) == expected_chips
	var showdown_players := 0
	for seat_value in table.get("seats", []):
		if bool((seat_value as Dictionary).get("revealed", false)):
			showdown_players += 1
	if max_board == 5 and bool(table.get("player_active", false)):
		showdown_players += 1
	var actions: Array[String] = []
	for record_value in records:
		actions.append(str((record_value as Dictionary).get("action", "")))
	return {
		"complete": str(table.get("phase", "")) == "idle",
		"members": lineup.duplicate(),
		"records": records,
		"seats": (table.get("seats", []) as Array).duplicate(true),
		"flop_players": flop_players,
		"flop_members": flop_members,
		"showdown_players": showdown_players,
		"max_board": max_board,
		"folds_only": max_board == 0 and not actions.is_empty() and not actions.has("call") and not actions.has("raise") and not actions.has("all_in") and not actions.has("check"),
		"chip_conservation": conservation,
		"actions": records.size(),
		"player_ev": run_state.bankroll - bankroll_before,
		"session_settled_early": bool(table.get("session_settled", false)) and int(table.get("hand_number", 0)) < int(CrewPokerModelScript.config().get("session_hand_cap", 5)),
	}


func _player_bot_action(bot: String, game: GameModule, run_state: RunState, seed: int, step: int, legal: Array[String]) -> Dictionary:
	var table := _table(run_state)
	var due := maxi(0, int(table.get("current_bet", 0)) - int((table.get("round_contributions", {}) as Dictionary).get("player", 0)))
	var strength := CrewPokerModelScript.holdem_strength(table.get("player_cards", []), table.get("community_cards", []))
	var can_raise := legal.has("raise")
	var action := "call" if legal.has("call") else "fold"
	match bot:
		"passive_caller":
			action = "call" if legal.has("call") else "fold"
		"tight_folder":
			action = "fold" if due > 0 and strength < 68 and legal.has("fold") else "call"
		"aggro_raiser":
			action = "raise" if can_raise else "call" if legal.has("call") else "all_in"
		"random_legal":
			var candidates: Array[String] = []
			for candidate in ["call", "raise", "fold", "all_in"]:
				if legal.has(candidate):
					candidates.append(candidate)
			action = candidates[posmod(seed + step * 17, candidates.size())] if not candidates.is_empty() else ""
		"balanced":
			if due > 0 and strength < 24 and legal.has("fold"):
				action = "fold"
			elif can_raise and strength >= 72 and posmod(seed + step, 3) == 0:
				action = "raise"
			else:
				action = "call" if legal.has("call") else "fold"
	var ui := {}
	if action == "raise":
		var minimum := int(game.call("_minimum_raise_to", table))
		var maximum := int(game.call("_maximum_raise_to", table))
		var target := minimum
		if bot == "aggro_raiser":
			target = clampi(int(table.get("current_bet", 0)) + maxi(int(CrewPokerModelScript.config().get("big_blind", 2)), int(round(float(table.get("pot", 0)) * 0.75))), minimum, maximum)
		ui["poker_raise_to"] = target
	return {"action": action, "ui": ui}


func _empty_aggregate() -> Dictionary:
	return {"hands": 0, "incomplete": 0, "preflop_uncontested": 0, "flop_multiway": 0, "showdown_multiway": 0, "folds_only": 0, "actions": 0, "conservation_failures": 0, "player_ev": 0, "early_swing_caps": 0, "members": {}}


func _accumulate_hand(total: Dictionary, hand: Dictionary) -> void:
	if not bool(hand.get("complete", false)):
		total["incomplete"] = int(total.get("incomplete", 0)) + 1
		return
	total["hands"] = int(total.get("hands", 0)) + 1
	var board := int(hand.get("max_board", 0))
	total["preflop_uncontested"] = int(total.get("preflop_uncontested", 0)) + (1 if board == 0 else 0)
	total["flop_multiway"] = int(total.get("flop_multiway", 0)) + (1 if int(hand.get("flop_players", 0)) >= 2 else 0)
	total["showdown_multiway"] = int(total.get("showdown_multiway", 0)) + (1 if int(hand.get("showdown_players", 0)) >= 2 else 0)
	total["folds_only"] = int(total.get("folds_only", 0)) + (1 if bool(hand.get("folds_only", false)) else 0)
	total["actions"] = int(total.get("actions", 0)) + int(hand.get("actions", 0))
	total["conservation_failures"] = int(total.get("conservation_failures", 0)) + (0 if bool(hand.get("chip_conservation", false)) else 1)
	total["player_ev"] = int(total.get("player_ev", 0)) + int(hand.get("player_ev", 0))
	total["early_swing_caps"] = int(total.get("early_swing_caps", 0)) + (1 if bool(hand.get("session_settled_early", false)) else 0)
	var member_totals: Dictionary = total.get("members", {})
	for member_value in hand.get("members", []):
		var member_id := str(member_value)
		var stat: Dictionary = member_totals.get(member_id, _empty_member_stat())
		stat["hands"] = int(stat.get("hands", 0)) + 1
		member_totals[member_id] = stat
	for record_value in hand.get("records", []):
		var record: Dictionary = record_value
		var actor := str(record.get("actor", ""))
		if actor == "player" or not member_totals.has(actor):
			continue
		var stat: Dictionary = member_totals[actor]
		var phase := str(record.get("phase", ""))
		var action := str(record.get("action", ""))
		var amount := int(record.get("amount", 0))
		if phase == "preflop" and amount > 0 and action in ["call", "raise", "all_in"]:
			stat["vpip_hands_map"][str(int(total.get("hands", 0)))] = true
		if phase == "preflop" and action in ["raise", "all_in"] and bool(record.get("raised", action == "raise")):
			stat["pfr_hands_map"][str(int(total.get("hands", 0)))] = true
		if action in ["bet", "raise", "all_in"]:
			var pot_before := maxi(1, int(record.get("pot_before", 1)))
			stat["bet_size_sum"] = float(stat.get("bet_size_sum", 0.0)) + float(amount) / float(pot_before)
			stat["bet_size_count"] = int(stat.get("bet_size_count", 0)) + 1
			if str(record.get("intent", "")).contains("bluff"):
				stat["bluffs"] = int(stat.get("bluffs", 0)) + 1
		if phase != "preflop":
			if action in ["bet", "raise", "all_in"]:
				stat["aggressive"] = int(stat.get("aggressive", 0)) + 1
			elif action == "call":
				stat["calls"] = int(stat.get("calls", 0)) + 1
		member_totals[actor] = stat
	for flop_member_value in hand.get("flop_members", []):
		var flop_member := str(flop_member_value)
		if member_totals.has(flop_member):
			var stat: Dictionary = member_totals[flop_member]
			stat["saw_flops"] = int(stat.get("saw_flops", 0)) + 1
			member_totals[flop_member] = stat
	for seat_value in hand.get("seats", []):
		var seat: Dictionary = seat_value
		var member_id := str(seat.get("member_id", ""))
		if member_totals.has(member_id) and bool(seat.get("revealed", false)):
			var stat: Dictionary = member_totals[member_id]
			stat["showdowns"] = int(stat.get("showdowns", 0)) + 1
			member_totals[member_id] = stat
	total["members"] = member_totals


func _empty_member_stat() -> Dictionary:
	return {"hands": 0, "vpip_hands_map": {}, "pfr_hands_map": {}, "aggressive": 0, "calls": 0, "saw_flops": 0, "showdowns": 0, "bluffs": 0, "bet_size_sum": 0.0, "bet_size_count": 0}


func _finish_aggregate(total: Dictionary) -> Dictionary:
	var hands := maxi(1, int(total.get("hands", 0)))
	var members := {}
	for member_id in (total.get("members", {}) as Dictionary).keys():
		var raw: Dictionary = (total.get("members", {}) as Dictionary).get(member_id, {})
		var member_hands := maxi(1, int(raw.get("hands", 0)))
		var aggressive := int(raw.get("aggressive", 0))
		var calls := int(raw.get("calls", 0))
		members[member_id] = {
			"hands": int(raw.get("hands", 0)),
			"vpip": _pct((raw.get("vpip_hands_map", {}) as Dictionary).size(), member_hands),
			"pfr": _pct((raw.get("pfr_hands_map", {}) as Dictionary).size(), member_hands),
			"af": _rounded(float(aggressive) / float(maxi(1, calls))),
			"wtsd": _pct(int(raw.get("showdowns", 0)), maxi(1, maxi(int(raw.get("saw_flops", 0)), int(raw.get("showdowns", 0))))),
			"bluff_share": _pct(int(raw.get("bluffs", 0)), maxi(1, aggressive)),
			"bet_size": _rounded(float(raw.get("bet_size_sum", 0.0)) / float(maxi(1, int(raw.get("bet_size_count", 0))))),
		}
	return {
		"hands": int(total.get("hands", 0)),
		"incomplete": int(total.get("incomplete", 0)),
		"flow": {
			"preflop_uncontested_pct": _pct(int(total.get("preflop_uncontested", 0)), hands),
			"flop_multiway_pct": _pct(int(total.get("flop_multiway", 0)), hands),
			"showdown_multiway_pct": _pct(int(total.get("showdown_multiway", 0)), hands),
			"folds_only_pct": _pct(int(total.get("folds_only", 0)), hands),
			"average_actions": _rounded(float(total.get("actions", 0)) / float(hands)),
		},
		"members": members,
		"chip_conservation_failures": int(total.get("conservation_failures", 0)),
		"player_ev_per_100": _rounded(float(total.get("player_ev", 0)) * 100.0 / float(hands)),
		"early_swing_cap_pct": _pct(int(total.get("early_swing_caps", 0)), hands),
	}


func _check_member_bands(members_value: Variant, failures: Array[String]) -> void:
	var members: Dictionary = members_value if typeof(members_value) == TYPE_DICTIONARY else {}
	for member_id in TARGET_BANDS.keys():
		var stat: Dictionary = members.get(member_id, {}) if typeof(members.get(member_id, {})) == TYPE_DICTIONARY else {}
		for metric in (TARGET_BANDS[member_id] as Dictionary).keys():
			var band: Array = (TARGET_BANDS[member_id] as Dictionary).get(metric, [])
			var value := float(stat.get(metric, -999.0))
			if band.size() != 2 or value < float(band[0]) or value > float(band[1]):
				failures.append("%s %s %.3f is outside %s." % [member_id, metric, value, JSON.stringify(band)])


func _distinctness_report(members_value: Variant) -> Dictionary:
	var members: Dictionary = members_value if typeof(members_value) == TYPE_DICTIONARY else {}
	var metrics := ["vpip", "pfr", "af", "wtsd", "bluff_share", "bet_size"]
	var pairs: Array = []
	var failures: Array[String] = []
	for left_index in range(CrewStateModelScript.MEMBER_IDS.size() - 1):
		for right_index in range(left_index + 1, CrewStateModelScript.MEMBER_IDS.size()):
			var left_id := str(CrewStateModelScript.MEMBER_IDS[left_index])
			var right_id := str(CrewStateModelScript.MEMBER_IDS[right_index])
			var left: Dictionary = members.get(left_id, {})
			var right: Dictionary = members.get(right_id, {})
			var separated: Array[String] = []
			for metric in metrics:
				var left_band: Array = (TARGET_BANDS[left_id] as Dictionary).get(metric, [])
				var right_band: Array = (TARGET_BANDS[right_id] as Dictionary).get(metric, [])
				var reference_width := minf(float(left_band[1]) - float(left_band[0]), float(right_band[1]) - float(right_band[0]))
				if absf(float(left.get(metric, 0.0)) - float(right.get(metric, 0.0))) >= reference_width * 0.25:
					separated.append(metric)
			pairs.append({"left": left_id, "right": right_id, "separated_metrics": separated})
			if separated.size() < 2:
				failures.append("%s and %s separate beyond the authored band-width margin on only %d stats." % [left_id, right_id, separated.size()])
	return {"definition": "absolute separation >= 25% of the narrower authored band width", "pairs": pairs, "failures": failures, "passed": failures.is_empty()}


func _character_report(by_bot: Dictionary) -> Dictionary:
	var failures: Array[String] = []
	var checks := {}
	for bot in by_bot.keys():
		var members: Dictionary = (by_bot.get(bot, {}) as Dictionary).get("members", {})
		var rook: Dictionary = members.get("crew_rook", {})
		var knuckles: Dictionary = members.get("crew_knuckles", {})
		var switch: Dictionary = members.get("crew_switch", {})
		var mags: Dictionary = members.get("crew_mags", {})
		var lucky: Dictionary = members.get("crew_lucky", {})
		var bot_checks := {
			"knuckles_looser_than_rook": float(knuckles.get("vpip", 0.0)) >= float(rook.get("vpip", 0.0)) + 15.0,
			"lucky_looser_than_mags": float(lucky.get("vpip", 0.0)) >= float(mags.get("vpip", 0.0)) + 20.0,
			"knuckles_more_aggressive_than_lucky": float(knuckles.get("af", 0.0)) >= float(lucky.get("af", 0.0)) + 0.75,
			"rook_bluffs_less_than_switch": float(rook.get("bluff_share", 0.0)) + 4.0 <= float(switch.get("bluff_share", 0.0)),
			"knuckles_bets_larger_than_switch": float(knuckles.get("bet_size", 0.0)) >= float(switch.get("bet_size", 0.0)) + 0.15,
		}
		checks[bot] = bot_checks
		for check_id in bot_checks.keys():
			if not bool(bot_checks[check_id]):
				failures.append("%s lost character check %s." % [str(bot), str(check_id)])
	return {"checks": checks, "failures": failures, "passed": failures.is_empty()}


func _exploit_report(by_bot: Dictionary, by_bot_lineup: Dictionary) -> Dictionary:
	var failures: Array[String] = []
	var bots := {}
	for bot in ["passive_caller", "aggro_raiser", "tight_folder"]:
		if not by_bot.has(bot):
			continue
		var aggregate_ev := float((by_bot.get(bot, {}) as Dictionary).get("player_ev_per_100", 0.0))
		var lineup_results: Dictionary = by_bot_lineup.get(bot, {})
		var positive_lineups := 0
		for lineup_value in lineup_results.values():
			if float((lineup_value as Dictionary).get("player_ev_per_100", 0.0)) > 0.0:
				positive_lineups += 1
		var positive_pct := _pct(positive_lineups, lineup_results.size())
		var consistent_winner := aggregate_ev > 0.0 and positive_pct >= 60.0
		bots[bot] = {"ev_per_100": aggregate_ev, "positive_lineups": positive_lineups, "lineup_count": lineup_results.size(), "positive_lineup_pct": positive_pct, "consistent_winner": consistent_winner}
		if consistent_winner:
			failures.append("%s won consistently across lineups." % bot)
	return {"bots": bots, "failures": failures, "passed": failures.is_empty()}


func _tilt_probe() -> Dictionary:
	var member_id := "crew_knuckles"
	var levels := [0, 90, 56, 22, 0]
	var samples := {}
	for level in levels:
		var continues := 0
		var raises := 0
		for sample in range(300):
			var rng := RngStreamScript.new()
			rng.configure(880000 + sample * 31)
			var decision := CrewPokerModelScript.holdem_decision(member_id, [_card(3, 0), _card(2, 1)], [], {"street": "preflop", "amount_to_call": 2, "pot": 9, "can_raise": true, "current_bet": 2, "minimum_raise_to": 4, "maximum_raise_to": 60, "stack": 60, "stack_big_blinds": 30.0, "active_opponents": 5, "position": 50, "tilt_level": level, "win_streak": 0, "raise_count": 0, "observed_fold_rate": 0.30, "player_reads": {}}, rng)
			var action := str(decision.get("action", ""))
			continues += 0 if action == "fold" else 1
			raises += 1 if action in ["bet", "raise", "all_in"] else 0
		samples[str(level)] = {"continue_pct": _pct(continues, 300), "aggressive_pct": _pct(raises, 300)}
	var base: Dictionary = samples.get("0", {})
	var peak: Dictionary = samples.get("90", {})
	var failures: Array[String] = []
	if float(peak.get("continue_pct", 0.0)) <= float(base.get("continue_pct", 0.0)) or float(peak.get("aggressive_pct", 0.0)) <= float(base.get("aggressive_pct", 0.0)):
		failures.append("A big loss did not measurably raise Knuckles' looseness and aggression.")
	if samples.get("0", {}) != base:
		failures.append("Tilt did not decay back to its neutral decision rate.")
	return {"member": member_id, "levels_after_loss_and_decay": levels, "samples": samples, "failures": failures, "passed": failures.is_empty()}


func _session_cap_study(game: GameModule) -> Dictionary:
	var sessions_per_table := 80
	var result := {}
	var incomplete := 0
	for opponent_count in [3, 5]:
		var early := 0
		var completed := 0
		var hand_total := 0
		for session_index in range(sessions_per_table):
			var session := _play_session_for_cap(game, opponent_count, 990000 + opponent_count * 10000 + session_index * 101)
			if not bool(session.get("complete", false)):
				incomplete += 1
				continue
			completed += 1
			hand_total += int(session.get("hands", 0))
			early += 1 if bool(session.get("ended_early", false)) else 0
		result["%d_opponents" % opponent_count] = {"sessions": completed, "early_swing_caps": early, "early_swing_cap_pct": _pct(early, completed), "average_hands": _rounded(float(hand_total) / float(maxi(1, completed)))}
	result["incomplete_sessions"] = incomplete
	return result


func _play_session_for_cap(game: GameModule, opponent_count: int, seed: int) -> Dictionary:
	var run_state := RunStateScript.new()
	run_state.start_new("CREW-CAP-%d" % seed)
	run_state.bankroll = 500
	for member_id in CrewStateModelScript.MEMBER_IDS:
		run_state.crew_add_trust(str(member_id), CrewStateModelScript.rank_threshold("made"), "personality_cap_sim")
	var offset := posmod(seed, CrewStateModelScript.MEMBER_IDS.size())
	var lineup: Array = []
	for index in range(opponent_count):
		lineup.append(CrewStateModelScript.MEMBER_IDS[(offset + index) % CrewStateModelScript.MEMBER_IDS.size()])
	var environment := {"id": "crew_cap_sim", "archetype_id": "small_underground_casino", "kind": "crew", "layer_id": "back_room", "crew_poker_turn_engine": "ordered_v1", "resident_member_ids": lineup, "game_ids": ["crew_draw_poker"], "game_states": {}}
	var rng := RngStreamScript.new()
	rng.configure(seed)
	var generated: Dictionary = game.generate_environment_state(run_state, environment, rng)
	generated["members"] = lineup.duplicate()
	generated["dealer_member_id"] = _first_unseated(lineup)
	environment["game_states"] = {"crew_draw_poker": generated}
	run_state.current_environment = environment
	var cap := int(CrewPokerModelScript.config().get("session_hand_cap", 5))
	for hand_index in range(cap):
		if not bool(_apply(game, run_state, "deal", {}, rng).get("ok", false)):
			return {"complete": false, "failure": "deal"}
		var steps := 0
		while str(_table(run_state).get("phase", "idle")) != "idle" and steps < 220:
			var legal := _legal_ids(game, run_state)
			var choice := {"action": "observe", "ui": {}} if legal.has("observe") else _player_bot_action("balanced", game, run_state, seed, steps + hand_index * 223, legal)
			if str(choice.get("action", "")).is_empty() or not bool(_apply(game, run_state, str(choice.get("action", "")), choice.get("ui", {}), rng).get("ok", false)):
				return {"complete": false, "failure": "progress"}
			steps += 1
		if str(_table(run_state).get("phase", "")) != "idle":
			return {"complete": false, "failure": "step_limit"}
		var hands := int(_table(run_state).get("hand_number", 0))
		if bool(_table(run_state).get("session_settled", false)):
			return {"complete": true, "hands": hands, "ended_early": hands < cap}
	return {"complete": true, "hands": cap, "ended_early": false}


func _timing_summary(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"decisions": 0, "average_msec": 0.0, "p95_msec": 0.0, "worst_msec": 0.0}
	values.sort()
	var sum := 0.0
	for value in values:
		sum += value
	return {"decisions": values.size(), "average_msec": _rounded(sum / float(values.size())), "p95_msec": _rounded(values[mini(values.size() - 1, ceili(values.size() * 0.95) - 1)]), "worst_msec": _rounded(values[values.size() - 1])}


func _write_report(report: Dictionary) -> Dictionary:
	var absolute_root := ProjectSettings.globalize_path(OUTPUT_ROOT)
	DirAccess.make_dir_recursive_absolute(absolute_root)
	var json_path := "%s/%s.json" % [absolute_root, _label]
	var markdown_path := "%s/%s.md" % [absolute_root, _label]
	var json_file := FileAccess.open(json_path, FileAccess.WRITE)
	if json_file != null:
		json_file.store_string(JSON.stringify(report, "\t") + "\n")
	var markdown_file := FileAccess.open(markdown_path, FileAccess.WRITE)
	if markdown_file != null:
		markdown_file.store_string(_markdown(report))
	return {"json": json_path, "markdown": markdown_path}


func _markdown(report: Dictionary) -> String:
	var lines: Array[String] = ["# Crew Hold'em personality simulation — %s" % _label, "", "Hands: %d across %d lineups." % [int(report.get("total_hands", 0)), int(report.get("lineup_count", 0))], ""]
	for bot in (report.get("by_player_bot", {}) as Dictionary).keys():
		var section: Dictionary = (report.get("by_player_bot", {}) as Dictionary).get(bot, {})
		var flow: Dictionary = section.get("flow", {})
		lines.append("## %s" % str(bot))
		lines.append("")
		lines.append("Preflop uncontested %.1f%%; multiway flop %.1f%%; multiway showdown %.1f%%; folds-only %.1f%%; %.2f actions/hand; player EV/100 %.2f." % [float(flow.get("preflop_uncontested_pct", 0.0)), float(flow.get("flop_multiway_pct", 0.0)), float(flow.get("showdown_multiway_pct", 0.0)), float(flow.get("folds_only_pct", 0.0)), float(flow.get("average_actions", 0.0)), float(section.get("player_ev_per_100", 0.0))])
		lines.append("")
		lines.append("| Member | VPIP | PFR | AF | WTSD | Bluff bets | Bet/pot |")
		lines.append("|---|---:|---:|---:|---:|---:|---:|")
		for member_id in CrewStateModelScript.MEMBER_IDS:
			var stat: Dictionary = (section.get("members", {}) as Dictionary).get(member_id, {})
			lines.append("| %s | %.1f%% | %.1f%% | %.2f | %.1f%% | %.1f%% | %.2f |" % [str(member_id).trim_prefix("crew_").capitalize(), float(stat.get("vpip", 0.0)), float(stat.get("pfr", 0.0)), float(stat.get("af", 0.0)), float(stat.get("wtsd", 0.0)), float(stat.get("bluff_share", 0.0)), float(stat.get("bet_size", 0.0))])
		lines.append("")
	lines.append("Decision timing: %s" % JSON.stringify(report.get("decision_performance", {})))
	lines.append("")
	lines.append("Failures: %s" % JSON.stringify(report.get("failures", [])))
	return "\n".join(lines) + "\n"


func _infer_intent(state: Dictionary, actor: String, action: String) -> String:
	if action not in ["bet", "raise", "all_in"]:
		return ""
	var seat_index := int(game_index_or_default(state, actor))
	if seat_index < 0:
		return ""
	var seat: Dictionary = (state.get("seats", []) as Array)[seat_index]
	var strength := CrewPokerModelScript.holdem_strength(seat.get("cards", []), state.get("community_cards", []))
	return "bluff" if strength < 38 else "value"


func game_index_or_default(state: Dictionary, actor: String) -> int:
	var seats: Array = state.get("seats", []) if typeof(state.get("seats", [])) == TYPE_ARRAY else []
	for index in range(seats.size()):
		if str((seats[index] as Dictionary).get("member_id", "")) == actor:
			return index
	return -1


func _five_member_lineups() -> Array:
	var result: Array = []
	var members: Array = CrewStateModelScript.MEMBER_IDS
	for a in range(members.size() - 4):
		for b in range(a + 1, members.size() - 3):
			for c in range(b + 1, members.size() - 2):
				for d in range(c + 1, members.size() - 1):
					for e in range(d + 1, members.size()):
						result.append([members[a], members[b], members[c], members[d], members[e]])
	return result


func _first_unseated(lineup: Array) -> String:
	for member_id in CrewStateModelScript.MEMBER_IDS:
		if not lineup.has(member_id):
			return str(member_id)
	return ""


func _legal_ids(game: GameModule, run_state: RunState) -> Array[String]:
	var result: Array[String] = []
	for value in game.legal_actions(run_state, run_state.current_environment):
		result.append(str((value as Dictionary).get("id", "")))
	return result


func _apply(game: GameModule, run_state: RunState, action_id: String, ui: Dictionary, rng: RngStream) -> Dictionary:
	var result := game.resolve_with_context(action_id, 2, run_state, run_state.current_environment, rng, ui)
	if bool(result.get("ok", false)):
		GameModuleScript.apply_result(run_state, result, rng)
	return result


func _table(run_state: RunState) -> Dictionary:
	return run_state.current_environment.get("game_states", {}).get("crew_draw_poker", {})


func _active_count(state: Dictionary) -> int:
	var count := 1 if bool(state.get("player_active", false)) else 0
	for seat_value in state.get("seats", []):
		count += 1 if bool((seat_value as Dictionary).get("active", false)) else 0
	return count


func _table_chip_total(state: Dictionary) -> int:
	var total := int(state.get("pot", 0)) + int(state.get("player_stack", 0))
	for seat_value in state.get("seats", []):
		total += int((seat_value as Dictionary).get("stack", 0))
	return total


func _pct(numerator: int, denominator: int) -> float:
	return _rounded(float(numerator) * 100.0 / float(maxi(1, denominator)))


func _rounded(value: float) -> float:
	return snappedf(value, 0.001)


func _card(rank: int, suit: int) -> Dictionary:
	return {"rank": rank, "suit": suit}
