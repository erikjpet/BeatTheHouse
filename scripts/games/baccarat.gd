class_name BaccaratGame
extends GameModule

# Full-simulation mini-baccarat / Punto Banco. Outcomes are produced by a
# finite shuffled shoe and mandatory casino draw rules, then settled against
# visible table bets.

const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const CardShoeScript := preload("res://scripts/core/card_shoe.gd")
const TableVisualsScript := preload("res://scripts/games/table_game_visuals.gd")

const C_DARK := VisualStyleScript.DARK
const C_DARK_2 := VisualStyleScript.DARK_2
const C_PINK := VisualStyleScript.PINK
const C_PINK_2 := VisualStyleScript.PINK_2
const C_CYAN := VisualStyleScript.CYAN
const C_TEAL := VisualStyleScript.TEAL
const C_YELLOW := VisualStyleScript.YELLOW
const C_AMBER := VisualStyleScript.AMBER
const C_ORANGE := VisualStyleScript.ORANGE
const C_WHITE := VisualStyleScript.WHITE
const C_SOFT := VisualStyleScript.SOFT

const BACCARAT_DEAL_CHANNEL := "baccarat_deal"
const BACCARAT_PAYOUT_CHANNEL := "baccarat_payout"
const DEAL_ANIMATION_DURATION_MSEC := 4200
const PAYOUT_ANIMATION_DURATION_MSEC := 1600
const HISTORY_LIMIT := 72
const BACCARAT_ROAD_ROWS := 6
const BACCARAT_ROAD_COLUMNS := 12
const CARD_SHOE_POS := Vector2(748, 104)
const PLAYER_CARD_BASE := Vector2(304, 230)
const BANKER_CARD_BASE := Vector2(526, 166)
const CARD_SIZE := Vector2(42, 60)
const CONSOLE_Y := 344.0

const BET_TARGETS := [
	{"id": "player_pair", "label": "PLAYER PAIR", "short": "P PAIR", "type": "pair", "family": "side", "payout_key": "player_pair_payout", "rect": Rect2(262, 168, 126, 48)},
	{"id": "banker_pair", "label": "BANKER PAIR", "short": "B PAIR", "type": "pair", "family": "side", "payout_key": "banker_pair_payout", "rect": Rect2(512, 168, 126, 48)},
	{"id": "player", "label": "PLAYER", "short": "PLAYER", "type": "main", "family": "main", "payout_key": "player_payout", "rect": Rect2(226, 248, 178, 76)},
	{"id": "tie", "label": "TIE", "short": "TIE", "type": "main", "family": "main", "payout_key": "tie_payout", "rect": Rect2(418, 236, 64, 88)},
	{"id": "banker", "label": "BANKER", "short": "BANKER", "type": "main", "family": "main", "payout_key": "banker_payout", "rect": Rect2(496, 248, 178, 76)},
]

const EDGE_SORT_ACTION_ID := "edge_sort"
const EDGE_SORT_CUE_COUNT := 4
const EDGE_SORT_MIN_HANDS := 2
const EDGE_SORT_EDGE_HANDS := 3
const EDGE_SORT_BASE_HEAT := 8
const EDGE_SORT_PERFECT_HEAT_REDUCTION := 3
const EDGE_SORT_PARTIAL_HEAT_BONUS := 4
const EDGE_SORT_MISS_HEAT_BONUS := 6
const EDGE_SORT_BLOWN_HEAT_BONUS := 10
const EDGE_SORT_ITEM_EFFECT_KEYS := [
	"baccarat_edge_sort_cue_count",
	"baccarat_edge_sort_memory_tolerance",
	"baccarat_edge_sort_heat_delta",
	"skill_cheat_drunk_memory_offset",
]


func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
	var result: Dictionary = super.enter(run_state, environment)
	var table := _table_state_preview(run_state, environment)
	var rules := _table_rules(table)
	result["message"] = "%s steadies the shoe at %s. Table minimum $%d; Banker commission %.0f%%." % [
		str(table.get("dealer_name", "The croupier")),
		str(table.get("table_name", "Baccarat")),
		int(table.get("table_minimum", 20)),
		float(rules.get("banker_commission_rate", 0.05)) * 100.0,
	]
	return result


func generate_environment_state(_run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var security: Dictionary = environment.get("security_profile", {}) if typeof(environment.get("security_profile", {})) == TYPE_DICTIONARY else {}
	var strictness := str(security.get("strictness", "boss"))
	var catch_base := 16
	match strictness:
		"boss":
			catch_base = 30
		"high":
			catch_base = 24
		"private", "uneven":
			catch_base = 20
		_:
			catch_base = 14
	var economic: Dictionary = environment.get("economic_profile", {}) if typeof(environment.get("economic_profile", {})) == TYPE_DICTIONARY else {}
	var table_min := maxi(20, int(economic.get("stake_floor", 10)))
	var table_max := maxi(table_min * 8, int(economic.get("stake_ceiling", table_min * 10)) * 10)
	var deck_count := 8
	var rules := _default_rules(deck_count)
	var shoe_state := _fresh_shoe_state(deck_count, rules, rng)
	var names := ["Salon Punto", "Velvet Shoe", "Golden Banker", "Lotus Table", "Midnight Baccarat"]
	var table := {
		"schema": "baccarat_table_state",
		"version": 1,
		"table_name": str(rng.pick(names, names[0])),
		"dealer_name": str(rng.pick(["Marisol", "Anika", "Vega", "June", "Sato"], "Marisol")),
		"variant": "mini_baccarat",
		"deck_count": deck_count,
		"rules": rules,
		"side_bets": [
			{"id": "player_pair", "label": "Player Pair", "payout": int(rules.get("player_pair_payout", 11))},
			{"id": "banker_pair", "label": "Banker Pair", "payout": int(rules.get("banker_pair_payout", 11))},
		],
		"dealer_profile": _generate_dealer_profile(rng, catch_base),
		"patrons": _generate_table_patrons(rng, int(environment.get("depth", 3))),
		"chip_denominations": [5, 10, 20, 25, 50, 100],
		"table_minimum": table_min,
		"table_maximum": table_max,
		"table_layout": "immersive_baccarat",
		"shoe_profile": _standard_shoe_profile(),
		"deal_profile": _standard_deal_profile(),
		"hands_played": 0,
		"reshuffle_count": 0,
		"commission_owed": 0,
		"last_bets": {},
		"last_result": {},
		"last_hand": {},
		"hand_history": [],
		"shoe_history": [],
		"dealer_catch_base": catch_base,
		"table_round_timer_started_msec": 0,
		"normalized_version": 1,
	}
	table.merge(shoe_state, true)
	return table


func surface_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var table := _table_state_preview(run_state, environment)
	var session := _normalized_session(run_state, environment, ui_state, table)
	var bets := _bet_dict(session.get("baccarat_bets", {}))
	var selected_chip := int(session.get("selected_chip", _chip_denominations(table)[0]))
	var total_wager := _total_wager(bets)
	var last_result := _copy_dict(table.get("last_result", {}))
	var now_msec := int(ui_state.get("surface_time_msec", Time.get_ticks_msec()))
	var elapsed_msec := now_msec - int(last_result.get("resolved_at_msec", 0))
	var deal_active := not last_result.is_empty() and elapsed_msec >= 0 and elapsed_msec < DEAL_ANIMATION_DURATION_MSEC
	var payout_active := not last_result.is_empty() and elapsed_msec >= DEAL_ANIMATION_DURATION_MSEC and elapsed_msec < DEAL_ANIMATION_DURATION_MSEC + PAYOUT_ANIMATION_DURATION_MSEC
	var surface_motion_active := deal_active or payout_active
	var min_ready := total_wager >= int(table.get("table_minimum", 20))
	var timer_active := not deal_active and not payout_active
	var round_timer := GameModule.table_round_timer_status_peek(table, now_msec, "Next hand") if timer_active else {}
	var table_notice := _table_notice(table, session, last_result, deal_active, payout_active, round_timer)
	var rules := _table_rules(table)
	var targets := _baccarat_bet_targets(table)
	var surface_patrons := _patrons_for_surface(table, last_result)
	var hand_explainer := _baccarat_hand_explainer(session, last_result, deal_active, payout_active, round_timer)
	var edge_challenge := _normalized_edge_sort_challenge(table.get("edge_sort_challenge", {}))
	var edge := _normalized_edge_sort_edge(table.get("edge_sort_edge", {}), table)
	var edge_status := _edge_sort_surface_status(table, edge_challenge, edge, session)
	var edge_sort_item_modifiers := skill_item_modifier_badges(run_state, EDGE_SORT_ITEM_EFFECT_KEYS)
	var road_state := _baccarat_road_state(table.get("hand_history", []))
	var shoe_penetration := _baccarat_shoe_penetration(table)
	var squeeze_state := _baccarat_squeeze_state(last_result)
	return GameModule.surface_spec({
		"surface_renderer": "baccarat",
		"surface_life": "immersive_table",
		"surface_cast": "dealer_table",
		"surface_controls_native": true,
		"surface_stake_controls_required": true,
		"surface_embeds_outcomes": true,
		"surface_suppresses_game_result_burst": true,
		"surface_animates_idle": surface_motion_active,
		"surface_realtime_state_refresh": surface_motion_active,
		"surface_state_labels": [
			{"label": "Wager", "value": "$%d" % total_wager},
			{"label": "Shoe", "value": str(table.get("shoe_label", "8-deck shoe"))},
		],
		"surface_animation_channels": [
			GameModule.surface_animation_channel(
				BACCARAT_DEAL_CHANNEL,
				str(last_result.get("deal_animation_id", "")) if deal_active else "",
				DEAL_ANIMATION_DURATION_MSEC if deal_active else 0,
				int(last_result.get("resolved_at_msec", 0)),
				{"metadata": {"winner": str(last_result.get("winner", ""))}}
			),
			GameModule.surface_animation_channel(
				BACCARAT_PAYOUT_CHANNEL,
				str(last_result.get("payout_animation_id", "")) if payout_active else "",
				PAYOUT_ANIMATION_DURATION_MSEC if payout_active else 0,
				int(last_result.get("resolved_at_msec", 0)) + DEAL_ANIMATION_DURATION_MSEC
			),
		],
		"surface_action_blocks": _surface_action_blocks(),
		"phase": "dealing" if deal_active else "payout" if payout_active else "betting",
		"table_name": str(table.get("table_name", "Baccarat")),
		"dealer_name": str(table.get("dealer_name", "Croupier")),
		"dealer_profile": _copy_dict(table.get("dealer_profile", {})),
		"patrons": surface_patrons,
		"patron_wager_action": "baccarat_patron_bet",
		"snitch_pressure": _patron_snitch_pressure(surface_patrons),
		"suspicion_level": run_state.suspicion_level() if run_state != null else 0,
		"dealer_attention_pressure": 10 if deal_active else 6 if payout_active else 0,
		"rules": rules,
		"bet_targets": targets,
		"baccarat_bets": bets,
		"baccarat_rebet": _bet_dict(session.get("baccarat_rebet", table.get("last_bets", {}))),
		"selected_chip": selected_chip,
		"selected_stake": selected_chip,
		"chip_denominations": _chip_denominations(table),
		"chip_stack": _chip_stack_for_stake(total_wager, _chip_denominations(table)),
		"total_wager_cost": total_wager,
		"table_minimum": int(table.get("table_minimum", 20)),
		"table_maximum": int(table.get("table_maximum", 500)),
		"can_deal": (total_wager <= 0 or min_ready) and not deal_active and not payout_active,
		"can_clear": not bets.is_empty() and not deal_active and not payout_active,
		"can_undo": not (_array(session.get("baccarat_undo_stack", [])).is_empty()) and not deal_active and not payout_active,
		"can_rebet": not _bet_dict(session.get("baccarat_rebet", table.get("last_bets", {}))).is_empty() and not deal_active and not payout_active,
		"commission_owed": int(table.get("commission_owed", 0)),
		"shoe_remaining": int(table.get("shoe_remaining", 0)),
		"shoe_label": str(table.get("shoe_label", "")),
		"cut_card_remaining": int(table.get("cut_card_remaining", 0)),
		"shoe_penetration": shoe_penetration,
		"reshuffle_pending": bool(table.get("reshuffle_pending", false)),
		"last_result": last_result,
		"last_hand": _copy_dict(table.get("last_hand", {})),
		"hand_history": _dictionary_array(table.get("hand_history", [])),
		"baccarat_road": road_state,
		"baccarat_scoreboard": road_state,
		"baccarat_squeeze_reveal": squeeze_state,
		"deal_animation_events": _dictionary_array(last_result.get("animation_events", [])),
		"baccarat_explainer": hand_explainer,
		"baccarat_edge_sort_challenge": edge_challenge.duplicate(true),
		"baccarat_edge_sort_edge": edge.duplicate(true),
		"baccarat_edge_sort_status": edge_status.duplicate(true),
		"baccarat_edge_sort_item_modifiers": edge_sort_item_modifiers,
		"edge_sort_challenge": edge_challenge.duplicate(true),
		"edge_sort_edge": edge.duplicate(true),
		"edge_sort_status": edge_status.duplicate(true),
		"edge_sort_ready": bool(edge_status.get("ready", false)),
		"edge_sort_active": bool(edge_status.get("active", false)),
		"edge_sort_item_modifiers": edge_sort_item_modifiers,
		"result_message": str(last_result.get("summary", "")) if not deal_active else "",
		"table_notice": table_notice,
		"table_round_timer": round_timer,
		"native_selected_surface_actions": _selected_surface_actions(bets),
		"surface_action_bindings": {
			"legal": {"action": "baccarat_deal", "index": 0},
			"cheat": {"action": "baccarat_edge_sort", "index": 0},
			"surface_stake_down": {"action": "baccarat_clear", "index": 0},
			"surface_stake_up": {"action": "baccarat_chip", "index": 0},
			"surface_stake_max": {"action": "baccarat_max_bet", "index": 0},
		},
		"surface_audio": GameModule.surface_audio_spec({
			"profile_id": "baccarat_table",
			"action_cues": {
				"baccarat_chip": "baccarat_chip",
				"baccarat_bet": "baccarat_chip",
				"baccarat_patron_bet": "baccarat_chip",
				"baccarat_clear": "baccarat_chip",
				"baccarat_undo": "baccarat_chip",
				"baccarat_rebet": "baccarat_chip",
				"baccarat_deal": "baccarat_deal",
				"baccarat_read_shoe": "baccarat_read_shoe",
				"baccarat_edge_sort": "baccarat_edge_sort",
				"baccarat_edge_sort_answer": "baccarat_chip",
				"surface_stake_up": "baccarat_chip",
				"surface_stake_down": "baccarat_chip",
				"surface_stake_max": "baccarat_chip",
			},
			"state_sync": {
				"method": "baccarat_table_state",
				"deal_animation_channel": BACCARAT_DEAL_CHANNEL,
				"payout_animation_channel": BACCARAT_PAYOUT_CHANNEL,
			},
		}),
	})


func draw_surface(surface, surface_state: Dictionary, _render_context: Dictionary = {}) -> bool:
	if str(surface_state.get("surface_renderer", "")) != "baccarat":
		return false
	surface.surface_begin_design_space(surface.surface_board_size())
	_draw_baccarat_room(surface, surface_state)
	_draw_hand_explainer(surface, surface_state)
	_draw_baccarat_table(surface, surface_state)
	_draw_table_patrons(surface, surface_state)
	_draw_croupier_station(surface, surface_state)
	_draw_bet_zones(surface, surface_state)
	_draw_card_areas(surface, surface_state)
	_draw_bet_chips(surface, surface_state)
	_draw_shoe_and_discard(surface, surface_state)
	_draw_baccarat_road(surface, surface_state)
	_draw_edge_sort_panel(surface, surface_state)
	_draw_table_notice(surface, surface_state)
	_draw_round_timer(surface, surface_state)
	_draw_chip_rack(surface, surface_state)
	_draw_action_console(surface, surface_state)
	surface.surface_end_design_space()
	return true


func surface_needs_auto_tick(ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> bool:
	# Per-frame check: operate on the live stored table (zero-copy) instead of
	# normalize -> deep copy -> write-back every frame. Stored state is already
	# normalized by every mutation path.
	var table := _peek_table_state(environment)
	if table.is_empty():
		return false
	var now_msec := int(ui_state.get("surface_time_msec", Time.get_ticks_msec()))
	var last_result: Variant = table.get("last_result", {})
	if typeof(last_result) == TYPE_DICTIONARY and not (last_result as Dictionary).is_empty():
		var elapsed_msec := now_msec - int((last_result as Dictionary).get("resolved_at_msec", 0))
		if elapsed_msec >= 0 and elapsed_msec < DEAL_ANIMATION_DURATION_MSEC + PAYOUT_ANIMATION_DURATION_MSEC:
			return false
	var timer := GameModule.table_round_timer_status_peek(table, now_msec, "Next hand")
	return not bool(timer.get("active", false)) or bool(timer.get("due", false))


func _peek_table_state(environment: Dictionary) -> Dictionary:
	# Zero-copy view of the stored table for read-mostly per-frame checks.
	# Callers must not mutate it or hold it across writes.
	var states: Variant = environment.get("game_states", {})
	if typeof(states) != TYPE_DICTIONARY:
		return {}
	var table: Variant = (states as Dictionary).get(get_id(), (states as Dictionary).get("baccarat", {}))
	if typeof(table) != TYPE_DICTIONARY or str((table as Dictionary).get("schema", "")) != "baccarat_table_state":
		return {}
	return table as Dictionary


func surface_auto_action_command(ui_state: Dictionary, run_state: RunState, environment: Dictionary, _surface_status: Dictionary = {}) -> Dictionary:
	var table := _table_state(run_state, environment)
	var session := _normalized_session(run_state, environment, ui_state, table)
	if _surface_locked(table, session):
		return {"handled": false}
	var now_msec := int(ui_state.get("surface_time_msec", Time.get_ticks_msec()))
	var timer := GameModule.table_round_timer_status(table, now_msec, "Next hand")
	if not bool(timer.get("due", false)):
		_update_environment_table(environment, table)
		return {"handled": false}
	session["baccarat_sit_out"] = _bet_dict(session.get("baccarat_bets", {})).is_empty()
	GameModule.reset_table_round_timer(table)
	_update_environment_table(environment, table)
	return GameModule.surface_command({
		"handled": true,
		"ui_state": session,
		"action_id": "deal_baccarat",
		"action_kind": "legal",
		"direct_resolve": true,
		"skip_stake_validation": true,
		"preserve_surface_ui_state": false,
		"message": "The croupier deals; you sit this hand out." if bool(session.get("baccarat_sit_out", false)) else "The croupier deals the working baccarat bets.",
	})


func surface_action_command(surface_action: String, index: int, _confirm_requested: bool, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var table := _table_state(run_state, environment)
	var session := _normalized_session(run_state, environment, ui_state, table)
	if _surface_locked(table, session):
		return _message_command(session, "No more bets while the hand is being dealt.")
	match surface_action:
		"baccarat_chip":
			return _chip_command(index, session, table)
		"baccarat_bet":
			return _place_bet_command(index, session, run_state, table)
		"baccarat_patron_bet":
			return _patron_bet_command(index, session, run_state, table)
		"baccarat_clear":
			session["baccarat_undo_stack"] = _array(session.get("baccarat_undo_stack", [])) + [_bet_dict(session.get("baccarat_bets", {}))]
			session["baccarat_bets"] = {}
			session.erase("table_social_alignment")
			session["table_notice"] = "Bets cleared."
			return GameModule.surface_command({"handled": true, "ui_state": session})
		"baccarat_undo":
			return _undo_command(session)
		"baccarat_rebet":
			return _rebet_command(session, run_state, table)
		"baccarat_max_bet":
			return _max_bet_command(session, run_state, table)
		"baccarat_deal":
			var total := _total_wager(_bet_dict(session.get("baccarat_bets", {})))
			if total <= 0:
				session["baccarat_sit_out"] = true
			elif total < int(table.get("table_minimum", 20)):
				return _message_command(session, "Baccarat table minimum is $%d." % int(table.get("table_minimum", 20)))
			return GameModule.surface_command({
				"handled": true,
				"ui_state": session,
				"action_id": "deal_baccarat",
				"action_kind": "legal",
				"resolve": true,
				"skip_stake_validation": true,
				"preserve_surface_ui_state": false,
			})
		"baccarat_read_shoe":
			session["shoe_read"] = _shoe_read_context(table)
			return GameModule.surface_command({
				"handled": true,
				"ui_state": session,
				"action_id": "read_baccarat_shoe",
				"action_kind": "cheat",
				"resolve": false,
				"skip_stake_validation": true,
				"message": str((session["shoe_read"] as Dictionary).get("message", "You study the shoe.")),
			})
		"baccarat_edge_sort":
			return _edge_sort_command(session, run_state, environment, table)
		"baccarat_edge_sort_answer":
			return _edge_sort_answer_command(index, session, table)
		_:
			return {"handled": false}


func wager_cost_for_context(action_id: String, stake: int, _run_state: RunState, _environment: Dictionary, ui_state: Dictionary = {}) -> int:
	if action_id == "deal_baccarat":
		return _total_wager(_bet_dict(ui_state.get("baccarat_bets", {})))
	return maxi(0, stake)


func resolve_with_context(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary = {}) -> Dictionary:
	if action_id == "read_baccarat_shoe":
		return _resolve_read_shoe(action_id, stake, run_state, environment, rng, ui_state)
	if action_id == EDGE_SORT_ACTION_ID:
		return _resolve_edge_sort(action_id, run_state, environment, rng, ui_state)
	if action_id != "deal_baccarat":
		return super.resolve_with_context(action_id, stake, run_state, environment, rng, ui_state)
	var result_msec := GameModule.deterministic_time_msec(run_state, ui_state)
	var table := _table_state(run_state, environment)
	var session := _normalized_session(run_state, environment, ui_state, table)
	var bets := _bet_dict(session.get("baccarat_bets", {}))
	var sit_out := bool(session.get("baccarat_sit_out", false)) and bets.is_empty()
	if bets.is_empty() and not sit_out:
		bets = _default_smoke_bets(maxi(stake, int(table.get("table_minimum", 20))))
	var total_wager := _total_wager(bets)
	if total_wager <= 0 and not sit_out:
		return _empty_baccarat_result(action_id, stake, environment, "Place a baccarat bet first.")
	if run_state != null and total_wager > run_state.bankroll:
		return _empty_baccarat_result(action_id, total_wager, environment, "You do not have enough bankroll for those baccarat chips.")
	var min_total := int(table.get("table_minimum", 20))
	if total_wager > 0 and total_wager < min_total:
		return _empty_baccarat_result(action_id, total_wager, environment, "Baccarat table minimum is $%d." % min_total)

	var edge_before := _normalized_edge_sort_edge(table.get("edge_sort_edge", {}), table)
	var edge_used := _edge_sort_edge_used(edge_before, bets)
	var hand := _resolve_baccarat_hand(table, rng, result_msec)
	var settlement := _settle_baccarat_bets(bets, hand, _table_rules(table))
	var bankroll_delta := int(settlement.get("bankroll_delta", 0))
	var message := _baccarat_result_message(hand, settlement, bankroll_delta)
	if edge_used:
		message = "%s Edge-sort lean called %s." % [message, _winner_display(str(edge_before.get("predicted_bet", "")))]
	if sit_out:
		message = "You sit out the baccarat hand. %s" % message
	_update_table_after_hand(table, bets, hand, settlement, bankroll_delta, rng, result_msec)
	_consume_edge_sort_edge(table, edge_before)
	_apply_patron_rapport_after_baccarat(table, session, bets, str(hand.get("winner", "")))
	_update_environment_table(environment, table)
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["messages"] = [message]
	deltas["story_log"] = [{
		"type": "game_action",
		"game_id": get_id(),
		"action_id": action_id,
		"won": bankroll_delta > 0,
		"stake_cost": total_wager,
		"sat_out": sit_out,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": 0,
		"environment_id": environment.get("id", ""),
		"baccarat_winner": str(hand.get("winner", "")),
	}]
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": "legal",
		"stake": total_wager,
		"bankroll_delta": bankroll_delta,
		"deltas": deltas,
		"won": bankroll_delta > 0,
		"environment_id": environment.get("id", ""),
		"message": message,
	})
	result["baccarat_winner"] = str(hand.get("winner", ""))
	result["baccarat_hand"] = hand.duplicate(true)
	result["baccarat_bets"] = bets.duplicate(true)
	result["baccarat_bet_results"] = _dictionary_array(settlement.get("bet_results", []))
	result["baccarat_total_wager"] = total_wager
	result["baccarat_sat_out"] = sit_out
	result["baccarat_commission"] = int(settlement.get("commission", 0))
	result["baccarat_animation_events"] = _dictionary_array(hand.get("animation_events", []))
	result["baccarat_edge_sort_edge_used"] = edge_used
	result["baccarat_edge_sort_prediction"] = edge_before.duplicate(true)
	result["baccarat_edge_sort_edge_remaining"] = int(_copy_dict(table.get("edge_sort_edge", {})).get("hands_remaining", 0))
	result["baccarat_road"] = _baccarat_road_state(table.get("hand_history", []))
	result["baccarat_shoe_penetration"] = _baccarat_shoe_penetration(table)
	GameModule.apply_result(run_state, result, rng)
	return result


func environment_object_state(_run_state: RunState, environment: Dictionary) -> Dictionary:
	var table := _table_state_preview(null, environment)
	var last_result := _copy_dict(table.get("last_result", {}))
	var winner := str(last_result.get("winner", "")).capitalize()
	return {
		"runtime_state": {
			"active": true,
			"status_label": "BAC %s" % (winner.left(6) if not winner.is_empty() else "OPEN"),
			"hands_played": int(table.get("hands_played", 0)),
			"shoe_remaining": int(table.get("shoe_remaining", 0)),
			"patron_count": _dictionary_array(table.get("patrons", [])).size(),
		},
		"visual_state": {
			"prop": "baccarat_table",
			"badge": "BAC",
			"summary": "Croupier, shoe, patrons, Player/Banker/Tie felt.",
		},
	}


func _resolve_read_shoe(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary) -> Dictionary:
	var action := _action(action_id)
	var pit_boss_status := run_state.pit_boss_watch_status(environment) if run_state != null else {}
	var pit_bonus := int(pit_boss_status.get("cheat_heat_bonus", 0)) if bool(pit_boss_status.get("active", false)) else 0
	var raw_heat := maxi(0, int(action.get("suspicion_delta", 8)) + (run_state.security_risk_bonus("cheat") if run_state != null else 0) + pit_bonus)
	var suspicion_delta := run_state.alcohol_adjusted_suspicion_delta(raw_heat) if run_state != null and raw_heat > 0 else raw_heat
	var security_pressure: Dictionary = run_state.security_action_pressure("cheat", maxi(1, stake), run_state.suspicion_level() + suspicion_delta) if run_state != null and suspicion_delta > 0 else {}
	var bankroll_delta := int(security_pressure.get("bankroll_delta", 0))
	var security_message := str(security_pressure.get("message", ""))
	var pit_boss_summary := str(pit_boss_status.get("summary", "")) if bool(pit_boss_status.get("active", false)) else ""
	var read := _copy_dict(ui_state.get("shoe_read", {}))
	if read.is_empty():
		read = _shoe_read_context(_table_state(run_state, environment))
	var message := "%s Heat %+d." % [str(read.get("message", "You read the shoe tempo.")), suspicion_delta]
	if not pit_boss_summary.is_empty():
		message = "%s %s" % [message, pit_boss_summary]
	var table_pressure := _baccarat_pressure_message(_table_state(run_state, environment), pit_boss_status)
	if not table_pressure.is_empty():
		message = "%s %s" % [message, table_pressure]
	if not security_message.is_empty():
		message = "%s %s" % [message, security_message]
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["suspicion_delta"] = suspicion_delta
	deltas["messages"] = [message]
	deltas["story_log"] = [{
		"type": "game_action",
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": "cheat",
		"won": false,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"environment_id": environment.get("id", ""),
		"pit_boss_watched": bool(pit_boss_status.get("watched", false)),
		"pit_boss_heat_bonus": pit_bonus,
		"table_pressure": table_pressure,
		"security_message": security_message,
	}]
	deltas["ended"] = bool(security_pressure.get("ended", false))
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": "cheat",
		"stake": 0,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"deltas": deltas,
		"won": false,
		"environment_id": environment.get("id", ""),
		"environment_archetype_id": environment.get("archetype_id", ""),
		"message": message,
	})
	result["baccarat_shoe_read"] = read
	result["baccarat_pit_boss_watched"] = bool(pit_boss_status.get("watched", false))
	result["baccarat_pit_boss_heat_bonus"] = pit_bonus
	result["baccarat_table_pressure"] = table_pressure
	GameModule.apply_result(run_state, result, rng)
	return result


func _resolve_baccarat_hand(table: Dictionary, rng: RngStream, result_msec: int = 0) -> Dictionary:
	var rules := _table_rules(table)
	if _needs_new_shoe(table):
		var fresh := _fresh_shoe_state(int(table.get("deck_count", 8)), rules, rng)
		for key in fresh.keys():
			table[key] = fresh[key]
		table["reshuffle_count"] = int(table.get("reshuffle_count", 0)) + 1
	var shoe: Array = table.get("shoe", []) if typeof(table.get("shoe", [])) == TYPE_ARRAY else []
	var player: Array = []
	var banker: Array = []
	player.append(_draw_one(shoe))
	banker.append(_draw_one(shoe))
	player.append(_draw_one(shoe))
	banker.append(_draw_one(shoe))
	var player_initial := _hand_total(player)
	var banker_initial := _hand_total(banker)
	var natural := player_initial >= 8 or banker_initial >= 8
	var player_third_card := {}
	var banker_third_card := {}
	var player_third_value := -1
	var player_drew := false
	var banker_drew := false
	if not natural:
		if _player_should_draw(player_initial):
			player_third_card = _draw_one(shoe)
			player.append(player_third_card)
			player_third_value = _baccarat_card_value(player_third_card)
			player_drew = true
		var banker_total_after_player := _hand_total(banker)
		if _banker_should_draw(banker_total_after_player, player_third_value, not player_drew):
			banker_third_card = _draw_one(shoe)
			banker.append(banker_third_card)
			banker_drew = true
	var player_total := _hand_total(player)
	var banker_total := _hand_total(banker)
	var winner := "tie"
	if player_total > banker_total:
		winner = "player"
	elif banker_total > player_total:
		winner = "banker"
	var used_cards: Array = []
	used_cards.append_array(_card_array(player))
	used_cards.append_array(_card_array(banker))
	var discard: Array = table.get("discard", []) if typeof(table.get("discard", [])) == TYPE_ARRAY else []
	discard.append_array(used_cards)
	table["shoe"] = shoe
	table["discard"] = discard
	table["shoe_remaining"] = shoe.size()
	table["shoe_composition_count"] = -1
	table["reshuffle_pending"] = shoe.size() <= int(table.get("cut_card_remaining", 84))
	return {
		"hand_id": "baccarat_%d_%d" % [int(table.get("hands_played", 0)) + 1, maxi(0, result_msec)],
		"player_cards": _card_array(player),
		"banker_cards": _card_array(banker),
		"player_initial_total": player_initial,
		"banker_initial_total": banker_initial,
		"player_total": player_total,
		"banker_total": banker_total,
		"winner": winner,
		"natural": natural,
		"player_drew": player_drew,
		"banker_drew": banker_drew,
		"player_third_value": player_third_value,
		"player_pair": _same_rank(player.slice(0, 2)),
		"banker_pair": _same_rank(banker.slice(0, 2)),
		"cards_used": used_cards.size(),
		"shoe_remaining_after": shoe.size(),
		"reshuffle_pending": bool(table.get("reshuffle_pending", false)),
		"animation_events": _baccarat_deal_events(player, banker, natural, player_drew, banker_drew, winner),
	}


func _settle_baccarat_bets(bets_value: Variant, hand: Dictionary, rules: Dictionary = {}) -> Dictionary:
	var bets := _bet_dict(bets_value)
	var bet_results: Array = []
	var bankroll_delta := 0
	var commission_total := 0
	for bet_id in bets.keys():
		var stake := maxi(0, int(bets.get(bet_id, 0)))
		if stake <= 0:
			continue
		var won := false
		var push := false
		var payout := 0
		var commission := 0
		match str(bet_id):
			"player":
				if str(hand.get("winner", "")) == "player":
					won = true
					payout = stake * int(rules.get("player_payout", 1))
				elif str(hand.get("winner", "")) == "tie":
					push = true
			"banker":
				if str(hand.get("winner", "")) == "banker":
					won = true
					payout = stake * int(rules.get("banker_payout", 1))
					commission = _banker_commission(stake, rules)
					payout = maxi(0, payout - commission)
				elif str(hand.get("winner", "")) == "tie":
					push = true
			"tie":
				if str(hand.get("winner", "")) == "tie":
					won = true
					payout = stake * int(rules.get("tie_payout", 8))
			"player_pair":
				if bool(hand.get("player_pair", false)):
					won = true
					payout = stake * int(rules.get("player_pair_payout", 11))
			"banker_pair":
				if bool(hand.get("banker_pair", false)):
					won = true
					payout = stake * int(rules.get("banker_pair_payout", 11))
			_:
				pass
		var net := 0 if push else payout if won else -stake
		bankroll_delta += net
		commission_total += commission
		bet_results.append({
			"id": str(bet_id),
			"stake": stake,
			"won": won,
			"push": push,
			"payout": payout,
			"commission": commission,
			"net": net,
			"label": _target_label(str(bet_id)),
		})
	return {
		"bankroll_delta": bankroll_delta,
		"commission": commission_total,
		"bet_results": bet_results,
	}


func _update_table_after_hand(table: Dictionary, bets: Dictionary, hand: Dictionary, settlement: Dictionary, bankroll_delta: int, rng: RngStream, result_msec: int = 0) -> void:
	table["hands_played"] = int(table.get("hands_played", 0)) + 1
	GameModule.reset_table_round_timer(table)
	table["last_bets"] = bets.duplicate(true)
	table["last_hand"] = hand.duplicate(true)
	table["commission_owed"] = int(table.get("commission_owed", 0)) + int(settlement.get("commission", 0))
	var summary := _baccarat_result_message(hand, settlement, bankroll_delta)
	var result := {
		"hand_id": str(hand.get("hand_id", "")),
		"deal_animation_id": "baccarat_deal_%s" % str(hand.get("hand_id", "")),
		"payout_animation_id": "baccarat_payout_%s" % str(hand.get("hand_id", "")),
		"winner": str(hand.get("winner", "")),
		"player_total": int(hand.get("player_total", 0)),
		"banker_total": int(hand.get("banker_total", 0)),
		"natural": bool(hand.get("natural", false)),
		"bankroll_delta": bankroll_delta,
		"commission": int(settlement.get("commission", 0)),
		"summary": summary,
		"bets": bets.duplicate(true),
		"bet_results": _dictionary_array(settlement.get("bet_results", [])),
		"hand": hand.duplicate(true),
		"animation_events": _dictionary_array(hand.get("animation_events", [])),
		"resolved_at_msec": maxi(0, result_msec),
		"rng_state": rng.snapshot() if rng != null else {},
	}
	table["last_result"] = result
	var history := _dictionary_array(table.get("hand_history", []))
	history.push_front({
		"hand_id": str(hand.get("hand_id", "")),
		"winner": str(hand.get("winner", "")),
		"player_total": int(hand.get("player_total", 0)),
		"banker_total": int(hand.get("banker_total", 0)),
		"natural": bool(hand.get("natural", false)),
		"bankroll_delta": bankroll_delta,
	})
	while history.size() > HISTORY_LIMIT:
		history.pop_back()
	table["hand_history"] = history
	var shoe_history := _dictionary_array(table.get("shoe_history", []))
	shoe_history.push_front({
		"hand_id": str(hand.get("hand_id", "")),
		"shoe_remaining": int(hand.get("shoe_remaining_after", 0)),
		"reshuffle_pending": bool(hand.get("reshuffle_pending", false)),
	})
	while shoe_history.size() > HISTORY_LIMIT:
		shoe_history.pop_back()
	table["shoe_history"] = shoe_history
	_update_edge_sort_after_hand(table, hand)


func _baccarat_deal_events(player_cards: Array, banker_cards: Array, natural: bool, player_drew: bool, banker_drew: bool, winner: String) -> Array:
	var events: Array = []
	var order: Array = [
		{"zone": "player", "card": player_cards[0], "to": _player_card_target(0), "delay": 0, "label": "Player first"},
		{"zone": "banker", "card": banker_cards[0], "to": _banker_card_target(0), "delay": 520, "label": "Banker first"},
		{"zone": "player", "card": player_cards[1], "to": _player_card_target(1), "delay": 1040, "label": "Player second"},
		{"zone": "banker", "card": banker_cards[1], "to": _banker_card_target(1), "delay": 1560, "label": "Banker second"},
	]
	if player_cards.size() >= 3:
		order.append({"zone": "player", "card": player_cards[2], "to": _player_card_target(2), "delay": 2460, "label": "Player draw"})
	if banker_cards.size() >= 3:
		order.append({"zone": "banker", "card": banker_cards[2], "to": _banker_card_target(2), "delay": 3020, "label": "Banker draw"})
	for i in range(order.size()):
		var entry: Dictionary = order[i]
		events.append({
			"type": "card",
			"zone": str(entry.get("zone", "")),
			"card_index": i,
			"card": _copy_dict(entry.get("card", {})),
			"from": _event_point(CARD_SHOE_POS),
			"to": _event_point(entry.get("to", Vector2.ZERO)),
			"delay_msec": int(entry.get("delay", 0)),
			"duration_msec": 520,
			"label": str(entry.get("label", "")),
		})
	var player_total := _hand_total(player_cards)
	var banker_total := _hand_total(banker_cards)
	var marker_delay := 3600
	if _hand_needs_squeeze(natural, player_total, banker_total):
		events.append({
			"type": "squeeze",
			"label": "Squeeze reveal",
			"winner": winner,
			"player_total": player_total,
			"banker_total": banker_total,
			"player_drew": player_drew,
			"banker_drew": banker_drew,
			"delay_msec": 3380,
			"duration_msec": 520,
		})
		marker_delay = 3880
	events.append({
		"type": "marker",
		"marker": "natural" if natural else "third-card" if player_drew or banker_drew else "stand",
		"winner": winner,
		"delay_msec": marker_delay,
		"duration_msec": 500,
	})
	return events


func _hand_needs_squeeze(natural: bool, player_total: int, banker_total: int) -> bool:
	return not natural and abs(player_total - banker_total) <= 1


func _baccarat_squeeze_state(last_result: Dictionary) -> Dictionary:
	for event_value in _dictionary_array(last_result.get("animation_events", [])):
		var event: Dictionary = event_value
		if str(event.get("type", "")) == "squeeze":
			return {
				"active": true,
				"label": str(event.get("label", "Squeeze reveal")),
				"winner": str(event.get("winner", "")),
				"player_total": int(event.get("player_total", 0)),
				"banker_total": int(event.get("banker_total", 0)),
				"delay_msec": int(event.get("delay_msec", 0)),
				"duration_msec": int(event.get("duration_msec", 0)),
			}
	return {}


func _baccarat_road_state(history_value: Variant) -> Dictionary:
	var history := _dictionary_array(history_value)
	var ordered: Array = []
	for i in range(history.size() - 1, -1, -1):
		ordered.append(history[i])
	var max_beads := BACCARAT_ROAD_ROWS * BACCARAT_ROAD_COLUMNS
	var start := maxi(0, ordered.size() - max_beads)
	var beads: Array = []
	var counts := {"player": 0, "banker": 0, "tie": 0}
	for i in range(start, ordered.size()):
		var hand: Dictionary = ordered[i]
		var winner := str(hand.get("winner", ""))
		if not counts.has(winner):
			continue
		counts[winner] = int(counts.get(winner, 0)) + 1
		var bead_index := beads.size()
		beads.append({
			"row": bead_index % BACCARAT_ROAD_ROWS,
			"column": int(bead_index / BACCARAT_ROAD_ROWS),
			"winner": winner,
			"player_total": int(hand.get("player_total", 0)),
			"banker_total": int(hand.get("banker_total", 0)),
			"natural": bool(hand.get("natural", false)),
			"hand_id": str(hand.get("hand_id", "")),
		})
	return {
		"type": "bead_plate",
		"rows": BACCARAT_ROAD_ROWS,
		"columns": BACCARAT_ROAD_COLUMNS,
		"beads": beads,
		"history_count": history.size(),
		"visible_count": beads.size(),
		"player_count": int(counts.get("player", 0)),
		"banker_count": int(counts.get("banker", 0)),
		"tie_count": int(counts.get("tie", 0)),
		"summary": "P%d B%d T%d" % [int(counts.get("player", 0)), int(counts.get("banker", 0)), int(counts.get("tie", 0))],
	}


func _baccarat_shoe_penetration(table: Dictionary) -> Dictionary:
	var deck_count := maxi(1, int(table.get("deck_count", 8)))
	var total_cards := deck_count * CardShoeScript.CARDS_PER_DECK
	var remaining := clampi(int(table.get("shoe_remaining", CardShoeScript.remaining_count(table.get("shoe", [])))), 0, total_cards)
	var used := clampi(total_cards - remaining, 0, total_cards)
	var cut_card_remaining := clampi(int(table.get("cut_card_remaining", CardShoeScript.cut_card_remaining(deck_count, float(_table_rules(table).get("cut_card_penetration", 0.72))))), 0, total_cards)
	var penetration_percent := int(round((float(used) / float(total_cards)) * 100.0))
	return {
		"total_cards": total_cards,
		"remaining": remaining,
		"used": used,
		"discard_count": _card_array(table.get("discard", [])).size(),
		"burn_count": _card_array(table.get("burn_cards", [])).size(),
		"cut_card_remaining": cut_card_remaining,
		"penetration_percent": penetration_percent,
		"reshuffle_pending": bool(table.get("reshuffle_pending", false)),
	}


func _player_card_target(index: int) -> Vector2:
	return PLAYER_CARD_BASE + Vector2(float(index) * 50.0, 0)


func _banker_card_target(index: int) -> Vector2:
	return BANKER_CARD_BASE + Vector2(float(index) * 50.0, 0)


func _fresh_shoe_state(deck_count: int, rules: Dictionary, rng: RngStream) -> Dictionary:
	var shoe := CardShoeScript.build_shoe(deck_count, rng)
	var burn_cards: Array = []
	if bool(rules.get("burn_card_on_new_shoe", true)) and not shoe.is_empty():
		var first := _draw_one(shoe)
		burn_cards.append(first)
		var burn_count := _baccarat_burn_value(first)
		for _i in range(maxi(0, burn_count - 1)):
			if shoe.is_empty():
				break
			burn_cards.append(_draw_one(shoe))
	var shoe_id := _shoe_state_id(deck_count, shoe, burn_cards)
	return {
		"shoe_id": shoe_id,
		"shoe": shoe,
		"discard": [],
		"burn_cards": burn_cards,
		"cut_card_remaining": CardShoeScript.cut_card_remaining(deck_count, float(rules.get("cut_card_penetration", 0.72))),
		"cut_card_at": maxi(0, deck_count * CardShoeScript.CARDS_PER_DECK - CardShoeScript.cut_card_remaining(deck_count, float(rules.get("cut_card_penetration", 0.72)))),
		"shoe_remaining": shoe.size(),
		"shoe_composition": CardShoeScript.remaining_composition(shoe),
		"shoe_composition_count": shoe.size(),
		"shoe_label": CardShoeScript.shoe_label(deck_count),
		"reshuffle_pending": false,
		"edge_sort_challenge": {},
		"edge_sort_edge": {},
	}


func _needs_new_shoe(table: Dictionary) -> bool:
	var shoe: Array = table.get("shoe", []) if typeof(table.get("shoe", [])) == TYPE_ARRAY else []
	var shoe_size := shoe.size()
	if shoe_size < 12:
		return true
	return bool(table.get("reshuffle_pending", false)) and int(table.get("hands_played", 0)) > 0


func _draw_one(shoe: Array) -> Dictionary:
	if shoe.is_empty():
		return {"rank": 2, "suit": 0, "deck": -1}
	var card_value: Variant = shoe.pop_front()
	return _copy_dict(card_value)


func _baccarat_card_value(card_value: Variant) -> int:
	if typeof(card_value) != TYPE_DICTIONARY:
		return 0
	var card: Dictionary = card_value
	var rank := int(card.get("rank", 2))
	if rank == 14:
		return 1
	if rank >= 2 and rank <= 9:
		return rank
	return 0


func _baccarat_burn_value(card_value: Variant) -> int:
	if typeof(card_value) != TYPE_DICTIONARY:
		return 0
	var card: Dictionary = card_value
	var rank := int(card.get("rank", 2))
	if rank == 14:
		return 1
	if rank >= 2 and rank <= 9:
		return rank
	return 10


func _hand_total(cards: Array) -> int:
	var total := 0
	for card in cards:
		total += _baccarat_card_value(card)
	return total % 10


func _is_natural(player_total: int, banker_total: int) -> bool:
	return player_total >= 8 or banker_total >= 8


func _player_should_draw(player_total: int) -> bool:
	return player_total <= 5


func _banker_should_draw(banker_total: int, player_third_value: int, player_stood: bool) -> bool:
	if player_stood:
		return banker_total <= 5
	match banker_total:
		0, 1, 2:
			return true
		3:
			return player_third_value != 8
		4:
			return player_third_value >= 2 and player_third_value <= 7
		5:
			return player_third_value >= 4 and player_third_value <= 7
		6:
			return player_third_value == 6 or player_third_value == 7
		_:
			return false


func _banker_commission(stake: int, rules: Dictionary) -> int:
	var rate := float(rules.get("banker_commission_rate", 0.05))
	if rate <= 0.0:
		return 0
	return maxi(1, int(ceil(float(stake) * rate)))


func _same_rank(cards: Array) -> bool:
	if cards.size() < 2:
		return false
	if typeof(cards[0]) != TYPE_DICTIONARY or typeof(cards[1]) != TYPE_DICTIONARY:
		return false
	var first: Dictionary = cards[0]
	var second: Dictionary = cards[1]
	return int(first.get("rank", -1)) == int(second.get("rank", -2))


func _default_rules(deck_count: int) -> Dictionary:
	return {
		"variant": "mini_baccarat",
		"deck_count": deck_count,
		"player_payout": 1,
		"banker_payout": 1,
		"banker_commission_rate": 0.05,
		"banker_commission_rounding": "ceil_whole_unit",
		"tie_payout": 8,
		"player_pair_payout": 11,
		"banker_pair_payout": 11,
		"pair_payout_mode": "to_one",
		"allow_opposing_main_bets": false,
		"allow_tie_with_main_bet": true,
		"allow_pair_without_main_bet": true,
		"burn_card_on_new_shoe": true,
		"burn_card_count_mode": "first_card_value",
		"cut_card_penetration": 0.72,
		"reshuffle_after_cut_card": true,
		"optional_side_bet_hooks": ["either_pair", "perfect_pair", "big", "small", "tiger_pair", "small_tiger", "big_tiger", "tiger_tie"],
	}


func _standard_shoe_profile() -> Dictionary:
	return {
		"shoe_speed": 1.0,
		"card_slide_friction": 0.78,
		"squeeze_reveal_bias": 0.18,
		"shuffle_chunk_size": 32,
		"cut_card_penetration": 0.72,
	}


func _standard_deal_profile() -> Dictionary:
	return {
		"deal_stagger_msec": 520,
		"card_slide_duration_msec": 520,
		"natural_pause_msec": 420,
		"third_card_pause_msec": 520,
		"payout_duration_msec": PAYOUT_ANIMATION_DURATION_MSEC,
	}


func _baccarat_bet_targets(table: Dictionary) -> Array:
	var rules := _table_rules(table)
	var result: Array = []
	for target_value in BET_TARGETS:
		var target: Dictionary = (target_value as Dictionary).duplicate(true)
		var payout_key := str(target.get("payout_key", ""))
		target["payout"] = int(rules.get(payout_key, 1))
		var rect: Rect2 = target.get("rect", Rect2())
		target["center"] = _vector_to_dict(rect.get_center())
		result.append(target)
	return result


func _chip_command(index: int, session: Dictionary, table: Dictionary) -> Dictionary:
	var denoms := _chip_denominations(table)
	var current := int(session.get("selected_chip", denoms[0]))
	var next_index := denoms.find(current)
	if index >= 0 and index < denoms.size():
		next_index = index
	else:
		next_index = (next_index + 1) % denoms.size()
	session["selected_chip"] = int(denoms[next_index])
	session["selected_stake"] = int(denoms[next_index])
	session["table_notice"] = "$%d chip selected." % int(denoms[next_index])
	return GameModule.surface_command({"handled": true, "ui_state": session})


func _place_bet_command(index: int, session: Dictionary, run_state: RunState, table: Dictionary) -> Dictionary:
	var targets := _baccarat_bet_targets(table)
	if index < 0 or index >= targets.size():
		return _message_command(session, "That baccarat betting space is not available.")
	var target: Dictionary = targets[index]
	var bet_id := str(target.get("id", ""))
	var bets := _bet_dict(session.get("baccarat_bets", {}))
	var chip := int(session.get("selected_chip", _chip_denominations(table)[0]))
	var bankroll := run_state.bankroll if run_state != null else 0
	if _total_wager(bets) + chip > bankroll:
		return _message_command(session, "Those chips exceed your bankroll.")
	if int(bets.get(bet_id, 0)) + chip > int(table.get("table_maximum", 500)):
		return _message_command(session, "That bet is above the table maximum.")
	if not bool(_table_rules(table).get("allow_opposing_main_bets", false)):
		if bet_id == "player" and int(bets.get("banker", 0)) > 0:
			return _message_command(session, "You cannot bet Player and Banker together at this table.")
		if bet_id == "banker" and int(bets.get("player", 0)) > 0:
			return _message_command(session, "You cannot bet Banker and Player together at this table.")
	session["baccarat_undo_stack"] = _array(session.get("baccarat_undo_stack", [])) + [bets.duplicate(true)]
	bets[bet_id] = int(bets.get(bet_id, 0)) + chip
	session["baccarat_bets"] = bets
	session.erase("table_social_alignment")
	session["table_notice"] = "$%d on %s." % [chip, str(target.get("label", bet_id))]
	return GameModule.surface_command({"handled": true, "ui_state": session})


func _patron_bet_command(index: int, session: Dictionary, run_state: RunState, table: Dictionary) -> Dictionary:
	var fade := index >= 100
	var patron_index := index % 100
	var patrons := _dictionary_array(table.get("patrons", []))
	if patron_index < 0 or patron_index >= patrons.size():
		return _message_command(session, "That player is not at the table anymore.")
	var patron: Dictionary = patrons[patron_index]
	var source_bet := str(patron.get("preferred_bet", "banker"))
	var bet_id := _opposing_baccarat_bet(source_bet) if fade else source_bet
	var wager := maxi(1, int(patron.get("cosmetic_bet", patron.get("chip_stack", int(table.get("table_minimum", 20))))))
	var bets := _bet_dict(session.get("baccarat_bets", {}))
	var bankroll := run_state.bankroll if run_state != null else wager
	var available := maxi(0, bankroll - _total_wager(bets))
	var table_room := maxi(0, int(table.get("table_maximum", 500)) - int(bets.get(bet_id, 0)))
	var chip := mini(wager, mini(available, table_room))
	if chip <= 0:
		return _message_command(session, "No bankroll left to mirror that baccarat action.")
	if not bool(_table_rules(table).get("allow_opposing_main_bets", false)):
		if bet_id == "player" and int(bets.get("banker", 0)) > 0:
			bets.erase("banker")
		elif bet_id == "banker" and int(bets.get("player", 0)) > 0:
			bets.erase("player")
	session["baccarat_undo_stack"] = _array(session.get("baccarat_undo_stack", [])) + [_bet_dict(session.get("baccarat_bets", {}))]
	bets[bet_id] = int(bets.get(bet_id, 0)) + chip
	session["baccarat_bets"] = bets
	session["table_social_alignment"] = {
		"game": "baccarat",
		"patron_id": str(patron.get("id", "patron_%d" % patron_index)),
		"patron_name": str(patron.get("name", "Guest")),
		"stance": "against" if fade else "with",
		"source_bet": source_bet,
		"bet_id": bet_id,
		"stake": chip,
	}
	session["table_notice"] = "%s %s %s: $%d on %s." % [
		"Fading" if fade else "Following",
		str(patron.get("name", "Guest")),
		"against" if fade else "with",
		chip,
		_target_label(bet_id),
	]
	return GameModule.surface_command({"handled": true, "ui_state": session})


func _baccarat_patron_wager(patron: Dictionary) -> Dictionary:
	var bet_id := str(patron.get("preferred_bet", "banker"))
	return {
		"id": bet_id,
		"label": _target_label(bet_id),
		"stake": maxi(1, int(patron.get("cosmetic_bet", patron.get("chip_stack", 25)))),
	}


func _opposing_baccarat_bet(bet_id: String) -> String:
	match bet_id:
		"player":
			return "banker"
		"banker":
			return "player"
		"player_pair":
			return "banker_pair"
		"banker_pair":
			return "player_pair"
		"tie":
			return "banker"
		_:
			return "banker"


func _apply_patron_rapport_after_baccarat(table: Dictionary, session: Dictionary, bets: Dictionary, winner: String) -> void:
	var patrons := _dictionary_array(table.get("patrons", []))
	if patrons.is_empty():
		return
	var alignment := _copy_dict(session.get("table_social_alignment", {}))
	for i in range(patrons.size()):
		var patron: Dictionary = patrons[i]
		var preferred := str(patron.get("preferred_bet", "banker"))
		var opposite := _opposing_baccarat_bet(preferred)
		var same := int(bets.get(preferred, 0)) > 0
		var fade := int(bets.get(opposite, 0)) > 0
		var delta := 0
		if same:
			delta += 2
		if fade:
			delta -= 2
		if str(alignment.get("patron_id", "")) == str(patron.get("id", "patron_%d" % i)):
			delta += 4 if str(alignment.get("stance", "")) == "with" else -4
		if delta != 0:
			if preferred == winner and same:
				delta += 1
			if preferred == winner and fade:
				delta -= 1
			patron["rapport"] = clampi(int(patron.get("rapport", 50)) + delta, 0, 100)
			patron["last_social_delta"] = delta
			patron["last_social_stance"] = "with" if delta > 0 else "against"
		else:
			patron["last_social_delta"] = 0
			patron["last_social_stance"] = "neutral"
		patrons[i] = patron
	table["patrons"] = patrons


func _undo_command(session: Dictionary) -> Dictionary:
	var stack := _array(session.get("baccarat_undo_stack", []))
	if stack.is_empty():
		return _message_command(session, "No baccarat bet to undo.")
	var previous := _bet_dict(stack.pop_back())
	session["baccarat_undo_stack"] = stack
	session["baccarat_bets"] = previous
	session.erase("table_social_alignment")
	session["table_notice"] = "Last chip placement undone."
	return GameModule.surface_command({"handled": true, "ui_state": session})


func _rebet_command(session: Dictionary, run_state: RunState, table: Dictionary) -> Dictionary:
	var rebet := _bet_dict(session.get("baccarat_rebet", table.get("last_bets", {})))
	if rebet.is_empty():
		return _message_command(session, "No previous baccarat bet to repeat.")
	if run_state != null and _total_wager(rebet) > run_state.bankroll:
		return _message_command(session, "You do not have enough bankroll to repeat that bet.")
	session["baccarat_undo_stack"] = _array(session.get("baccarat_undo_stack", [])) + [_bet_dict(session.get("baccarat_bets", {}))]
	session["baccarat_bets"] = rebet
	session.erase("table_social_alignment")
	session["table_notice"] = "Previous baccarat layout repeated."
	return GameModule.surface_command({"handled": true, "ui_state": session})


func _max_bet_command(session: Dictionary, run_state: RunState, table: Dictionary) -> Dictionary:
	var bets := _bet_dict(session.get("baccarat_bets", {}))
	var chip := maxi(int(table.get("table_minimum", 20)), int(session.get("selected_chip", 20)))
	var bankroll := run_state.bankroll if run_state != null else chip
	var allowed := mini(chip, maxi(0, bankroll - _total_wager(bets)))
	if allowed <= 0:
		return _message_command(session, "No bankroll left for another baccarat chip.")
	session["selected_chip"] = allowed
	session["selected_stake"] = allowed
	return GameModule.surface_command({"handled": true, "ui_state": session, "message": "$%d chip selected." % allowed})


func _shoe_read_context(table: Dictionary) -> Dictionary:
	_refresh_shoe_cached_metadata(table)
	var composition := _copy_dict(table.get("shoe_composition", {}))
	var bias := int(composition.get("hi_lo_remaining_bias", 0))
	var remaining := int(table.get("shoe_remaining", 0))
	var lean := "neutral"
	if bias > 20:
		lean = "low cards heavy"
	elif bias < -20:
		lean = "zero-value cards heavy"
	return {
		"remaining": remaining,
		"bias": bias,
		"lean": lean,
		"message": "You clock %d cards left; the shoe feels %s." % [remaining, lean],
	}


func _edge_sort_command(session: Dictionary, run_state: RunState, environment: Dictionary, table: Dictionary) -> Dictionary:
	var challenge := _normalized_edge_sort_challenge(table.get("edge_sort_challenge", {}))
	if challenge.is_empty() or bool(challenge.get("resolved", false)):
		challenge = _start_edge_sort_challenge(table, run_state, environment)
		table["edge_sort_challenge"] = challenge.duplicate(true)
		_update_environment_table(environment, table)
		session["edge_sort_challenge"] = challenge.duplicate(true)
		session["edge_sort_answers"] = []
		session["table_notice"] = "Edge-sort read started; watch the next two hands."
		return GameModule.surface_command({
			"handled": true,
			"ui_state": session,
			"preserve_surface_ui_state": true,
			"message": "You start tracking tiny card-back tells from the shoe.",
		})
	session["edge_sort_challenge"] = challenge.duplicate(true)
	if not _edge_sort_challenge_ready(challenge):
		var observed := _dictionary_array(challenge.get("observed_cues", [])).size()
		var required := int(challenge.get("required_cue_count", EDGE_SORT_CUE_COUNT))
		session["table_notice"] = "Edge-sort read: %d/%d backs logged." % [observed, required]
		return GameModule.surface_command({
			"handled": true,
			"ui_state": session,
			"preserve_surface_ui_state": true,
			"message": "Keep watching the shoe; the pattern is not settled yet.",
		})
	var answers := _string_array(session.get("edge_sort_answers", []))
	var expected := _string_array(challenge.get("hidden_answer", []))
	if answers.size() < expected.size() and not session.has("edge_sort_answer_mode"):
		session["table_notice"] = "Set the edge-sort memory sequence before committing."
		return GameModule.surface_command({
			"handled": true,
			"ui_state": session,
			"preserve_surface_ui_state": true,
			"message": "You still need to lock in the remembered back sequence.",
		})
	return GameModule.surface_command({
		"handled": true,
		"ui_state": session,
		"action_id": EDGE_SORT_ACTION_ID,
		"action_kind": "cheat",
		"resolve": true,
		"skip_stake_validation": true,
		"preserve_surface_ui_state": true,
		"message": "You commit the edge-sort read.",
	})


func _edge_sort_answer_command(index: int, session: Dictionary, table: Dictionary) -> Dictionary:
	var challenge := _normalized_edge_sort_challenge(table.get("edge_sort_challenge", session.get("edge_sort_challenge", {})))
	if challenge.is_empty() or not _edge_sort_challenge_ready(challenge):
		return _message_command(session, "No edge-sort memory prompt is ready.")
	var answer_options := ["high", "low", "neutral"]
	var cue_index := clampi(index, 0, answer_options.size() - 1)
	var answers := _string_array(session.get("edge_sort_answers", []))
	var expected := _string_array(challenge.get("hidden_answer", []))
	if answers.size() >= expected.size():
		answers.clear()
	answers.append(str(answer_options[cue_index]))
	session["edge_sort_answers"] = answers
	session["edge_sort_challenge"] = challenge.duplicate(true)
	var label := _edge_sort_cue_icon(str(answer_options[cue_index]))
	return GameModule.surface_command({
		"handled": true,
		"ui_state": session,
		"preserve_surface_ui_state": true,
		"message": "Edge-sort cue %s logged (%d/%d)." % [label, answers.size(), expected.size()],
	})


func _resolve_edge_sort(action_id: String, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary) -> Dictionary:
	var table := _table_state(run_state, environment)
	var challenge := _finalize_edge_sort_challenge(ui_state, run_state, table, environment)
	if challenge.is_empty():
		return _empty_baccarat_result(action_id, 0, environment, "There is no edge-sort read to resolve.")
	var grade := str(challenge.get("skill_grade", "miss"))
	var applied := _edge_sort_grade_applies(grade)
	var edge := _copy_dict(challenge.get("edge_prediction", {}))
	if applied and not edge.is_empty():
		table["edge_sort_edge"] = edge.duplicate(true)
	else:
		table["edge_sort_edge"] = {}
	table["edge_sort_challenge"] = {}
	_update_environment_table(environment, table)

	var pit_boss_status := run_state.pit_boss_watch_status(environment) if run_state != null else {}
	var pit_boss_active := bool(pit_boss_status.get("active", false))
	var pit_boss_watched := (pit_boss_active and bool(pit_boss_status.get("watched", false))) or bool(challenge.get("pit_boss_watched_start", false)) or _edge_sort_table_watched(table)
	var pit_bonus := int(pit_boss_status.get("cheat_heat_bonus", 0)) if pit_boss_active else 0
	var action := _action(action_id)
	var action_heat := int(action.get("suspicion_delta", EDGE_SORT_BASE_HEAT))
	var base_suspicion_delta := maxi(1, action_heat + _item_effect_total("cheat_suspicion_delta", run_state) + _edge_sort_grade_heat_modifier(grade))
	var raw_heat := base_suspicion_delta
	if run_state != null:
		raw_heat += run_state.security_risk_bonus("cheat") + pit_bonus
	var suspicion_delta := run_state.alcohol_adjusted_suspicion_delta(raw_heat) if run_state != null and raw_heat > 0 else raw_heat
	var security_pressure: Dictionary = run_state.security_action_pressure("cheat", int(table.get("table_minimum", 20)), run_state.suspicion_level() + suspicion_delta) if run_state != null and suspicion_delta > 0 else {}
	var bankroll_delta := int(security_pressure.get("bankroll_delta", 0))
	var security_message := str(security_pressure.get("message", ""))
	var table_pressure := _edge_sort_pressure_message(table, pit_boss_status)
	var skill_outcome := _edge_sort_skill_outcome(grade)
	var message := _edge_sort_message(grade, edge, suspicion_delta, table_pressure, security_message)
	var skill_context := {
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": "cheat",
		"skill_outcome": skill_outcome,
		"skill_grade": grade,
		"skill_accuracy": clampi(int(challenge.get("skill_accuracy", 0)), 0, 100),
		"skill_margin_msec": int(challenge.get("skill_margin_msec", 0)),
		"suspicion_delta": suspicion_delta,
		"base_suspicion_delta": base_suspicion_delta,
		"bankroll_delta": bankroll_delta,
		"watched": pit_boss_watched,
		"pit_boss_heat_bonus": pit_bonus,
		"security_pressure_checked": true,
		"shoe_id": str(challenge.get("shoe_id", "")),
		"correct_count": int(challenge.get("correct_count", 0)),
		"miss_count": int(challenge.get("miss_count", 0)),
		"edge_prediction": edge.duplicate(true),
	}
	var story_entry := {
		"type": "game_action",
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": "cheat",
		"stake": 0,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"cheated": true,
		"skill_outcome": skill_outcome,
		"skill_grade": grade,
		"skill_accuracy": clampi(int(challenge.get("skill_accuracy", 0)), 0, 100),
		"skill_margin_msec": int(challenge.get("skill_margin_msec", 0)),
		"base_suspicion_delta": base_suspicion_delta,
		"pit_boss_watched": pit_boss_watched,
		"pit_boss_heat_bonus": pit_bonus,
		"table_pressure": table_pressure,
		"security_message": security_message,
		"skill_security_pressure_checked": true,
		"environment_id": environment.get("id", ""),
		"skill_story_context": skill_context.duplicate(true),
	}
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["suspicion_delta"] = suspicion_delta
	deltas["messages"] = [message]
	deltas["story_log"] = [story_entry]
	deltas["ended"] = bool(security_pressure.get("ended", false))
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": "cheat",
		"stake": 0,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"deltas": deltas,
		"won": applied,
		"environment_id": environment.get("id", ""),
		"environment_archetype_id": environment.get("archetype_id", ""),
		"message": message,
		"pit_boss_watched": pit_boss_watched,
		"pit_boss_heat_bonus": pit_bonus,
		"skill_outcome": skill_outcome,
		"skill_security_pressure_checked": true,
		"security_message": security_message,
		"skill_story_context": skill_context,
	})
	result["baccarat_edge_sort"] = true
	result["baccarat_edge_sort_applied"] = applied
	result["baccarat_edge_sort_challenge"] = challenge.duplicate(true)
	result["baccarat_edge_sort_edge"] = edge.duplicate(true)
	result["baccarat_edge_sort_grade"] = grade
	result["baccarat_edge_sort_accuracy"] = clampi(int(challenge.get("skill_accuracy", 0)), 0, 100)
	result["baccarat_edge_sort_correct_count"] = int(challenge.get("correct_count", 0))
	result["baccarat_edge_sort_miss_count"] = int(challenge.get("miss_count", 0))
	result["baccarat_pit_boss_watched"] = pit_boss_watched
	result["baccarat_pit_boss_heat_bonus"] = pit_bonus
	result["baccarat_table_pressure"] = table_pressure
	result["skill_grade"] = grade
	result["skill_accuracy"] = clampi(int(challenge.get("skill_accuracy", 0)), 0, 100)
	result["skill_margin_msec"] = int(challenge.get("skill_margin_msec", 0))
	result["base_suspicion_delta"] = base_suspicion_delta
	GameModule.normalize_skill_cheat_contract(result, result)
	GameModule.apply_result(run_state, result, rng)
	return result


func _start_edge_sort_challenge(table: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var shoe_id := str(table.get("shoe_id", ""))
	if shoe_id.is_empty():
		shoe_id = _shoe_state_id(int(table.get("deck_count", 8)), table.get("shoe", []), table.get("burn_cards", []))
		table["shoe_id"] = shoe_id
	var seed := "%s:%s:%s:%d:%d" % [
		get_id(),
		str(run_state.seed_text if run_state != null else ""),
		shoe_id,
		int(table.get("hands_played", 0)),
		int(table.get("reshuffle_count", 0)),
	]
	var pit_boss := run_state.pit_boss_watch_status(environment) if run_state != null else {}
	return {
		"challenge_id": "bac_edge_%d" % _stable_hash(seed),
		"shoe_id": shoe_id,
		"hand_index_start": int(table.get("hands_played", 0)) + 1,
		"observed_cues": [],
		"cue_icons": [],
		"observed_hand_indexes": [],
		"hidden_answer": [],
		"memory_prompt": "Watch two hands, then recall the card-back cues.",
		"answers": [],
		"correct_count": 0,
		"miss_count": 0,
		"edge_prediction": {},
		"confidence": 0,
		"skill_grade": "",
		"skill_accuracy": 0,
		"skill_margin_msec": 0,
		"required_cue_count": _edge_sort_required_cue_count(run_state),
		"min_hands": EDGE_SORT_MIN_HANDS,
		"memory_tolerance": _edge_sort_memory_tolerance(run_state),
		"base_heat": _edge_sort_base_heat(run_state),
		"pit_boss_watched_start": bool(pit_boss.get("watched", false)) if bool(pit_boss.get("active", false)) else false,
		"item_modifiers": skill_item_modifier_badges(run_state, EDGE_SORT_ITEM_EFFECT_KEYS),
		"ready": false,
		"resolved": false,
	}


func _update_edge_sort_after_hand(table: Dictionary, hand: Dictionary) -> void:
	var challenge := _normalized_edge_sort_challenge(table.get("edge_sort_challenge", {}))
	if challenge.is_empty() or bool(challenge.get("resolved", false)):
		return
	if str(challenge.get("shoe_id", "")) != str(table.get("shoe_id", "")):
		table["edge_sort_challenge"] = {}
		return
	var required := int(challenge.get("required_cue_count", EDGE_SORT_CUE_COUNT))
	var hidden := _string_array(challenge.get("hidden_answer", []))
	if hidden.size() >= required:
		challenge["ready"] = _edge_sort_challenge_ready(challenge)
		table["edge_sort_challenge"] = challenge
		return
	var observed_hands := _int_array(challenge.get("observed_hand_indexes", []))
	var hand_index := int(table.get("hands_played", 0))
	if observed_hands.has(hand_index):
		table["edge_sort_challenge"] = challenge
		return
	var observed := _dictionary_array(challenge.get("observed_cues", []))
	var icons := _dictionary_array(challenge.get("cue_icons", []))
	var cues := _edge_sort_cues_for_hand(hand, hand_index)
	var added := 0
	for cue_value in cues:
		if added >= 2 or hidden.size() >= required:
			break
		var cue: Dictionary = cue_value
		observed.append(cue.duplicate(true))
		hidden.append(str(cue.get("cue", "neutral")))
		icons.append({
			"hand_index": hand_index,
			"icon": _edge_sort_cue_icon(str(cue.get("cue", "neutral"))),
			"zone": str(cue.get("zone", "")),
			"slot": int(cue.get("slot", 0)),
		})
		added += 1
	if added > 0:
		observed_hands.append(hand_index)
	challenge["observed_cues"] = observed
	challenge["cue_icons"] = icons
	challenge["hidden_answer"] = hidden
	challenge["observed_hand_indexes"] = observed_hands
	challenge["memory_prompt"] = "Recall %d card-back cues from %d hands." % [required, int(challenge.get("min_hands", EDGE_SORT_MIN_HANDS))]
	challenge["ready"] = _edge_sort_challenge_ready(challenge)
	table["edge_sort_challenge"] = challenge


# Edge sort stays local by design: it grades observed cue memory and answer sets,
# not the scalar timing window shared by holdout, controlled roll, and past-post.
func _finalize_edge_sort_challenge(ui_state: Dictionary, run_state: RunState, table: Dictionary, environment: Dictionary) -> Dictionary:
	var challenge := _normalized_edge_sort_challenge(ui_state.get("edge_sort_challenge", table.get("edge_sort_challenge", {})))
	if challenge.is_empty():
		challenge = _normalized_edge_sort_challenge(table.get("edge_sort_challenge", {}))
	if challenge.is_empty() or str(challenge.get("shoe_id", "")) != str(table.get("shoe_id", "")):
		return {}
	var hidden := _string_array(challenge.get("hidden_answer", []))
	var answers := _edge_sort_answers_for_ui(ui_state, challenge)
	var correct := 0
	for i in range(hidden.size()):
		if i < answers.size() and str(answers[i]) == str(hidden[i]):
			correct += 1
	var miss_count := maxi(0, hidden.size() - correct)
	var watched_now := _edge_sort_table_watched(table)
	var mode := str(ui_state.get("edge_sort_answer_mode", "")).strip_edges()
	var tolerance := clampi(int(challenge.get("memory_tolerance", _edge_sort_memory_tolerance(run_state))), 0, hidden.size())
	var grade := "miss"
	if mode == "blown" or (watched_now and miss_count >= hidden.size() and hidden.size() > 0):
		grade = "blown"
	elif miss_count == 0 and _edge_sort_challenge_ready(challenge):
		grade = "perfect"
	elif miss_count <= tolerance and _edge_sort_challenge_ready(challenge):
		grade = "good"
	elif correct >= maxi(1, int(ceil(float(hidden.size()) * 0.5))) and _edge_sort_challenge_ready(challenge):
		grade = "partial"
	var accuracy := 0
	if hidden.size() > 0:
		accuracy = clampi(int(round(float(correct) / float(hidden.size()) * 100.0)), 0, 100)
	var prediction := _edge_sort_prediction_for_grade(table, grade)
	challenge["answers"] = answers
	challenge["correct_count"] = correct
	challenge["miss_count"] = miss_count
	challenge["skill_grade"] = grade
	challenge["skill_accuracy"] = accuracy
	challenge["skill_margin_msec"] = 0
	challenge["confidence"] = int(prediction.get("confidence", 0))
	challenge["edge_prediction"] = prediction
	challenge["resolved"] = true
	challenge["ready"] = false
	challenge["pit_boss_watched_start"] = bool(challenge.get("pit_boss_watched_start", false)) or bool((run_state.pit_boss_watch_status(environment) if run_state != null else {}).get("watched", false))
	return challenge


func _normalized_edge_sort_challenge(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = (value as Dictionary).duplicate(true)
	var challenge_id := str(source.get("challenge_id", "")).strip_edges()
	if challenge_id.is_empty():
		return {}
	var grade := str(source.get("skill_grade", ""))
	if not ["", "perfect", "good", "partial", "miss", "blown"].has(grade):
		grade = ""
	var normalized := {
		"challenge_id": challenge_id,
		"shoe_id": str(source.get("shoe_id", "")),
		"hand_index_start": maxi(0, int(source.get("hand_index_start", 0))),
		"observed_cues": _dictionary_array(source.get("observed_cues", [])),
		"cue_icons": _dictionary_array(source.get("cue_icons", [])),
		"observed_hand_indexes": _int_array(source.get("observed_hand_indexes", [])),
		"hidden_answer": _string_array(source.get("hidden_answer", [])),
		"memory_prompt": str(source.get("memory_prompt", "")),
		"answers": _string_array(source.get("answers", [])),
		"correct_count": maxi(0, int(source.get("correct_count", 0))),
		"miss_count": maxi(0, int(source.get("miss_count", 0))),
		"edge_prediction": _copy_dict(source.get("edge_prediction", {})),
		"confidence": clampi(int(source.get("confidence", 0)), 0, 100),
		"skill_grade": grade,
		"skill_accuracy": clampi(int(source.get("skill_accuracy", 0)), 0, 100),
		"skill_margin_msec": int(source.get("skill_margin_msec", 0)),
		"required_cue_count": clampi(int(source.get("required_cue_count", EDGE_SORT_CUE_COUNT)), 3, 6),
		"min_hands": clampi(int(source.get("min_hands", EDGE_SORT_MIN_HANDS)), 1, 4),
		"memory_tolerance": clampi(int(source.get("memory_tolerance", 0)), 0, 3),
		"base_heat": maxi(1, int(source.get("base_heat", EDGE_SORT_BASE_HEAT))),
		"pit_boss_watched_start": bool(source.get("pit_boss_watched_start", false)),
		"resolved": bool(source.get("resolved", false)),
		"item_modifiers": _copy_array(source.get("item_modifiers", [])),
	}
	normalized["ready"] = bool(source.get("ready", false)) or _edge_sort_challenge_ready(normalized)
	return normalized


func _normalized_edge_sort_edge(value: Variant, table: Dictionary) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var edge := (value as Dictionary).duplicate(true)
	var predicted := str(edge.get("predicted_bet", ""))
	if not ["player", "banker", "tie"].has(predicted):
		return {}
	if str(edge.get("shoe_id", "")) != str(table.get("shoe_id", "")):
		return {}
	var hands_remaining := maxi(0, int(edge.get("hands_remaining", 0)))
	if hands_remaining <= 0:
		return {}
	return {
		"active": true,
		"shoe_id": str(edge.get("shoe_id", "")),
		"predicted_bet": predicted,
		"confidence": clampi(int(edge.get("confidence", 0)), 0, 100),
		"hands_remaining": hands_remaining,
		"expires_after_hand": maxi(0, int(edge.get("expires_after_hand", int(table.get("hands_played", 0)) + hands_remaining))),
		"skill_grade": str(edge.get("skill_grade", "")),
		"side_bet_hint": str(edge.get("side_bet_hint", "")),
	}


func _edge_sort_surface_status(table: Dictionary, challenge: Dictionary, edge: Dictionary, session: Dictionary) -> Dictionary:
	var answers := _string_array(session.get("edge_sort_answers", []))
	var observed := _dictionary_array(challenge.get("observed_cues", []))
	var required := int(challenge.get("required_cue_count", EDGE_SORT_CUE_COUNT)) if not challenge.is_empty() else EDGE_SORT_CUE_COUNT
	return {
		"active": not challenge.is_empty(),
		"ready": _edge_sort_challenge_ready(challenge),
		"resolved": bool(challenge.get("resolved", false)),
		"cue_count": observed.size(),
		"required_cue_count": required,
		"observed_hands": _int_array(challenge.get("observed_hand_indexes", [])).size(),
		"required_hands": int(challenge.get("min_hands", EDGE_SORT_MIN_HANDS)) if not challenge.is_empty() else EDGE_SORT_MIN_HANDS,
		"answer_count": answers.size(),
		"memory_prompt": str(challenge.get("memory_prompt", "")),
		"edge_active": not edge.is_empty(),
		"predicted_bet": str(edge.get("predicted_bet", "")),
		"confidence": int(edge.get("confidence", 0)),
		"hands_remaining": int(edge.get("hands_remaining", 0)),
		"shoe_id": str(table.get("shoe_id", "")),
	}


func _edge_sort_challenge_ready(challenge: Dictionary) -> bool:
	if challenge.is_empty() or bool(challenge.get("resolved", false)):
		return false
	return _string_array(challenge.get("hidden_answer", [])).size() >= int(challenge.get("required_cue_count", EDGE_SORT_CUE_COUNT)) and _int_array(challenge.get("observed_hand_indexes", [])).size() >= int(challenge.get("min_hands", EDGE_SORT_MIN_HANDS))


func _edge_sort_cues_for_hand(hand: Dictionary, hand_index: int) -> Array:
	var result: Array = []
	var zones := [
		{"id": "player", "cards": _card_array(hand.get("player_cards", []))},
		{"id": "banker", "cards": _card_array(hand.get("banker_cards", []))},
	]
	for zone_value in zones:
		var zone: Dictionary = zone_value
		var cards: Array = zone.get("cards", [])
		for i in range(cards.size()):
			var card: Dictionary = cards[i]
			var cue := _edge_sort_card_cue(card)
			result.append({
				"hand_index": hand_index,
				"zone": str(zone.get("id", "")),
				"slot": i,
				"cue": cue,
				"icon": _edge_sort_cue_icon(cue),
				"rank": int(card.get("rank", 2)),
				"suit": int(card.get("suit", 0)),
			})
	return result


func _edge_sort_card_cue(card: Dictionary) -> String:
	var rank := int(card.get("rank", 2))
	if rank == 14 or rank >= 10:
		return "high"
	if rank <= 6:
		return "low"
	return "neutral"


func _edge_sort_cue_icon(cue: String) -> String:
	match cue:
		"high":
			return "H"
		"low":
			return "L"
		_:
			return "N"


func _edge_sort_answers_for_ui(ui_state: Dictionary, challenge: Dictionary) -> Array:
	var explicit := _string_array(ui_state.get("edge_sort_answers", []))
	if not explicit.is_empty():
		return explicit
	var hidden := _string_array(challenge.get("hidden_answer", []))
	var mode := str(ui_state.get("edge_sort_answer_mode", "")).strip_edges()
	if mode == "perfect":
		return hidden
	if mode == "partial":
		var partial: Array = []
		var split := int(ceil(float(hidden.size()) * 0.5))
		for i in range(hidden.size()):
			partial.append(str(hidden[i]) if i < split else _wrong_edge_sort_answer(str(hidden[i])))
		return partial
	if mode == "miss" or mode == "blown":
		var misses: Array = []
		for answer in hidden:
			misses.append(_wrong_edge_sort_answer(str(answer)))
		return misses
	return explicit


func _wrong_edge_sort_answer(answer: String) -> String:
	match answer:
		"high":
			return "low"
		"low":
			return "neutral"
		_:
			return "high"


func _edge_sort_prediction_for_grade(table: Dictionary, grade: String) -> Dictionary:
	if not _edge_sort_grade_applies(grade):
		return {}
	var preview_table := table.duplicate(true)
	var preview_rng := _default_table_rng(table, "edge_sort_preview")
	var preview_hand := _resolve_baccarat_hand(preview_table, preview_rng)
	var predicted := str(preview_hand.get("winner", "banker"))
	var confidence := 48
	match grade:
		"perfect":
			confidence = 90
		"good":
			confidence = 72
		"partial":
			confidence = 52
	var side_hint := _edge_sort_side_bet_hint(preview_hand) if grade == "perfect" else ""
	return {
		"active": true,
		"shoe_id": str(table.get("shoe_id", "")),
		"predicted_bet": predicted,
		"confidence": confidence,
		"hands_remaining": EDGE_SORT_EDGE_HANDS,
		"expires_after_hand": int(table.get("hands_played", 0)) + EDGE_SORT_EDGE_HANDS,
		"skill_grade": grade,
		"side_bet_hint": side_hint,
	}


func _edge_sort_side_bet_hint(hand: Dictionary) -> String:
	var player := _card_array(hand.get("player_cards", []))
	var banker := _card_array(hand.get("banker_cards", []))
	if player.size() >= 2 and int((player[0] as Dictionary).get("rank", 0)) == int((player[1] as Dictionary).get("rank", -1)):
		return "player_pair"
	if banker.size() >= 2 and int((banker[0] as Dictionary).get("rank", 0)) == int((banker[1] as Dictionary).get("rank", -1)):
		return "banker_pair"
	return ""


func _edge_sort_edge_used(edge: Dictionary, bets: Dictionary) -> bool:
	if edge.is_empty():
		return false
	var predicted := str(edge.get("predicted_bet", ""))
	return int(bets.get(predicted, 0)) > 0


func _consume_edge_sort_edge(table: Dictionary, edge_before: Dictionary) -> void:
	if edge_before.is_empty():
		table["edge_sort_edge"] = _normalized_edge_sort_edge(table.get("edge_sort_edge", {}), table)
		return
	if str(edge_before.get("shoe_id", "")) != str(table.get("shoe_id", "")):
		table["edge_sort_edge"] = {}
		return
	var remaining := int(edge_before.get("hands_remaining", 0)) - 1
	if remaining <= 0:
		table["edge_sort_edge"] = {}
		return
	var next_edge := _edge_sort_prediction_for_grade(table, str(edge_before.get("skill_grade", "partial")))
	if next_edge.is_empty():
		table["edge_sort_edge"] = {}
		return
	next_edge["hands_remaining"] = remaining
	next_edge["expires_after_hand"] = int(table.get("hands_played", 0)) + remaining
	table["edge_sort_edge"] = next_edge


func _edge_sort_grade_applies(grade: String) -> bool:
	return grade == "perfect" or grade == "good" or grade == "partial"


func _edge_sort_grade_heat_modifier(grade: String) -> int:
	match grade:
		"perfect":
			return -EDGE_SORT_PERFECT_HEAT_REDUCTION
		"partial":
			return EDGE_SORT_PARTIAL_HEAT_BONUS
		"miss":
			return EDGE_SORT_MISS_HEAT_BONUS
		"blown":
			return EDGE_SORT_BLOWN_HEAT_BONUS
	return 0


func _edge_sort_skill_outcome(grade: String) -> String:
	if grade.is_empty():
		return "edge_sort_miss"
	return "edge_sort_%s" % grade


func _edge_sort_required_cue_count(run_state: RunState) -> int:
	var count := EDGE_SORT_CUE_COUNT + _item_effect_total("baccarat_edge_sort_cue_count", run_state)
	var drunk_extra := 1 if run_state != null and run_state.drunk_level >= 45 else 0
	if drunk_extra > 0:
		drunk_extra = maxi(0, drunk_extra - _item_effect_total("skill_cheat_drunk_memory_offset", run_state))
	count += drunk_extra
	return clampi(count, 3, 6)


func _edge_sort_memory_tolerance(run_state: RunState) -> int:
	return clampi(_item_effect_total("baccarat_edge_sort_memory_tolerance", run_state), 0, 3)


func _edge_sort_base_heat(run_state: RunState) -> int:
	return maxi(1, EDGE_SORT_BASE_HEAT + _item_effect_total("baccarat_edge_sort_heat_delta", run_state))


func _edge_sort_table_watched(table: Dictionary) -> bool:
	for patron_value in _dictionary_array(table.get("patrons", [])):
		var patron: Dictionary = patron_value
		if bool(patron.get("watching", patron.get("watching_player", false))):
			return true
	return false


func _edge_sort_pressure_message(table: Dictionary, pit_boss_status: Dictionary) -> String:
	if bool(pit_boss_status.get("watched", false)):
		return "The pit boss watches your edge-sort read from the rail."
	for patron_value in _dictionary_array(table.get("patrons", [])):
		var patron: Dictionary = patron_value
		if bool(patron.get("watching", false)):
			return "A patron follows your eyes from the shoe to the felt."
	return ""


func _edge_sort_message(grade: String, edge: Dictionary, suspicion_delta: int, table_pressure: String, security_message: String) -> String:
	var summary := "Your edge-sort read slips."
	if grade == "perfect":
		summary = "The card backs line up cleanly: lean %s at %d%% confidence for %d hands." % [
			_winner_display(str(edge.get("predicted_bet", ""))),
			int(edge.get("confidence", 0)),
			int(edge.get("hands_remaining", 0)),
		]
	elif grade == "good":
		summary = "The edge-sort read is usable: lean %s at %d%% confidence." % [
			_winner_display(str(edge.get("predicted_bet", ""))),
			int(edge.get("confidence", 0)),
		]
	elif grade == "partial":
		summary = "The pattern is shaky, but it still points toward %s." % _winner_display(str(edge.get("predicted_bet", "")))
	elif grade == "blown":
		summary = "The croupier clocks the stare before you can use the backs."
	var message := "%s Heat %+d." % [summary, suspicion_delta]
	if not table_pressure.is_empty():
		message = "%s %s" % [message, table_pressure]
	if not security_message.is_empty():
		message = "%s %s" % [message, security_message]
	return message


func _shoe_state_id(deck_count: int, shoe_value: Variant, burn_value: Variant) -> String:
	var shoe := CardShoeScript.card_array(shoe_value)
	var burns := _card_array(burn_value)
	var sample: Array = []
	for i in range(mini(12, shoe.size())):
		sample.append(_copy_dict(shoe[i]))
	var fingerprint := JSON.stringify({"shoe": sample, "burn": burns})
	return "shoe_%d_%d_%d" % [deck_count, shoe.size(), _stable_hash(fingerprint)]


func _message_command(ui_state: Dictionary, message: String) -> Dictionary:
	return GameModule.surface_command({"handled": true, "ui_state": ui_state, "message": message})


func _surface_action_blocks() -> Array:
	var actions := ["baccarat_bet", "baccarat_patron_bet", "baccarat_chip", "baccarat_clear", "baccarat_undo", "baccarat_rebet", "baccarat_deal", "baccarat_read_shoe", "baccarat_edge_sort", "baccarat_edge_sort_answer", "baccarat_max_bet"]
	return [
		{"actions": actions, "while_animation": BACCARAT_DEAL_CHANNEL, "reason": "No more bets while the hand is being dealt."},
		{"actions": actions, "while_animation": BACCARAT_PAYOUT_CHANNEL, "reason": "The croupier is settling the hand."},
	]


func _surface_locked(table: Dictionary, session: Dictionary) -> bool:
	var last_result := _copy_dict(table.get("last_result", {}))
	if last_result.is_empty():
		return false
	var now_msec := int(session.get("surface_time_msec", Time.get_ticks_msec()))
	var elapsed_msec := now_msec - int(last_result.get("resolved_at_msec", 0))
	return elapsed_msec >= 0 and elapsed_msec < DEAL_ANIMATION_DURATION_MSEC + PAYOUT_ANIMATION_DURATION_MSEC


func _selected_surface_actions(bets: Dictionary) -> Array:
	return ["baccarat_deal"] if not bets.is_empty() else []


func _table_notice(table: Dictionary, session: Dictionary, last_result: Dictionary, deal_active: bool, payout_active: bool, round_timer: Dictionary = {}) -> String:
	if deal_active:
		return "No more bets. Cards are sliding from the shoe."
	if payout_active:
		var winner_text := _winner_display(str(last_result.get("winner", "")))
		return "%s is settling. Winning chips are marked." % winner_text if not winner_text.is_empty() else "The croupier marks winners and collects commission."
	if not str(session.get("table_notice", "")).is_empty():
		return str(session.get("table_notice", ""))
	var edge := _normalized_edge_sort_edge(table.get("edge_sort_edge", {}), table)
	if not edge.is_empty():
		return "Edge-sort lean: %s at %d%% for %d hands." % [_winner_display(str(edge.get("predicted_bet", ""))), int(edge.get("confidence", 0)), int(edge.get("hands_remaining", 0))]
	var challenge := _normalized_edge_sort_challenge(table.get("edge_sort_challenge", {}))
	if not challenge.is_empty():
		var observed := _dictionary_array(challenge.get("observed_cues", [])).size()
		var required := int(challenge.get("required_cue_count", EDGE_SORT_CUE_COUNT))
		return "Edge-sort read: %d/%d backs logged." % [observed, required] if not _edge_sort_challenge_ready(challenge) else "Edge-sort sequence ready."
	var bets := _bet_dict(session.get("baccarat_bets", {}))
	if bets.is_empty():
		if bool(table.get("reshuffle_pending", false)):
			return "The cut card is out; the croupier will shuffle before the next hand."
		var seconds := int(round_timer.get("remaining_seconds", 0))
		if seconds > 0:
			return "Place chips or sit out; next hand in %ds." % seconds
		return "Place chips or sit out the next hand."
	if _total_wager(bets) < int(table.get("table_minimum", 20)):
		return "Add chips to reach the $%d table minimum." % int(table.get("table_minimum", 20))
	if not last_result.is_empty():
		return str(last_result.get("summary", "The shoe is ready."))
	return "$%d working across %d baccarat space%s." % [_total_wager(bets), bets.size(), "" if bets.size() == 1 else "s"]


func _baccarat_hand_explainer(session: Dictionary, last_result: Dictionary, deal_active: bool, payout_active: bool, round_timer: Dictionary = {}) -> Dictionary:
	var bets := _bet_dict(session.get("baccarat_bets", {}))
	if deal_active:
		return {
			"mode": "dealing",
			"title": "HAND IN PROGRESS",
			"primary": "Cards deal Player, Banker, Player, Banker.",
			"secondary": "Closest to 9 wins; only the final digit counts.",
			"bet_summary": "Totals appear when the hand is complete.",
			"winner": "",
			"player_total": -1,
			"banker_total": -1,
			"net": 0,
		}
	if not last_result.is_empty():
		var winner := str(last_result.get("winner", "tie"))
		var player_total := int(last_result.get("player_total", 0))
		var banker_total := int(last_result.get("banker_total", 0))
		var net := int(last_result.get("bankroll_delta", 0))
		var natural := bool(last_result.get("natural", false))
		return {
			"mode": "payout" if payout_active else "last_hand",
			"title": _winner_title(winner),
			"primary": "Player %d  Banker %d" % [player_total, banker_total],
			"secondary": _baccarat_winner_reason(winner, player_total, banker_total, natural),
			"bet_summary": _baccarat_settlement_summary(_dictionary_array(last_result.get("bet_results", [])), net),
			"winner": winner,
			"player_total": player_total,
			"banker_total": banker_total,
			"net": net,
			"natural": natural,
		}
	if bets.is_empty():
		var seconds := int(round_timer.get("remaining_seconds", 0))
		return {
			"mode": "guide",
			"title": "HOW BACCARAT WORKS",
			"primary": "Bet Player, Banker, or Tie before the hand.",
			"secondary": "Closest to 9 wins. Face cards count 0; aces count 1.",
			"bet_summary": "Player and Banker bets push when the hand ties." if seconds <= 0 else "Next hand in %ds; you may sit out." % seconds,
			"winner": "",
			"player_total": -1,
			"banker_total": -1,
			"net": 0,
		}
	return {
		"mode": "betting",
		"title": "READY TO DEAL",
		"primary": "$%d placed on %s." % [_total_wager(bets), _bets_display(bets)],
		"secondary": "Player and Banker compare final totals.",
		"bet_summary": "Pair side bets need matching first two cards.",
		"winner": "",
		"player_total": -1,
		"banker_total": -1,
		"net": 0,
	}


func _baccarat_result_message(hand: Dictionary, settlement: Dictionary, bankroll_delta: int) -> String:
	var winner := str(hand.get("winner", "tie"))
	var player_total := int(hand.get("player_total", 0))
	var banker_total := int(hand.get("banker_total", 0))
	var commission := int(settlement.get("commission", 0))
	var wins := 0
	var losses := 0
	var pushes := 0
	for result_value in _dictionary_array(settlement.get("bet_results", [])):
		var bet_result: Dictionary = result_value
		if bool(bet_result.get("won", false)):
			wins += 1
		elif bool(bet_result.get("push", false)):
			pushes += 1
		else:
			losses += 1
	var natural := " Natural hand." if bool(hand.get("natural", false)) else ""
	var commission_text := " Commission $%d." % commission if commission > 0 else ""
	var bet_text := "No player chips settled." if wins + losses + pushes <= 0 else "%d won, %d lost, %d pushed." % [wins, losses, pushes]
	return "Baccarat: %s Player %d, Banker %d. %s%s Net %+d.%s" % [
		_winner_sentence(winner),
		player_total,
		banker_total,
		natural,
		bet_text,
		bankroll_delta,
		commission_text,
	]


func _winner_title(winner: String) -> String:
	if winner == "tie":
		return "TIE HAND"
	return "%s WINS" % _winner_display(winner).to_upper()


func _winner_sentence(winner: String) -> String:
	if winner == "tie":
		return "Tie hand."
	return "%s wins." % _winner_display(winner)


func _winner_display(winner: String) -> String:
	match winner:
		"player":
			return "Player"
		"banker":
			return "Banker"
		"tie":
			return "Tie"
		_:
			return ""


func _baccarat_winner_reason(winner: String, player_total: int, banker_total: int, natural: bool) -> String:
	if winner == "tie":
		return "Both sides finished at %d; Player/Banker bets push." % player_total
	var trailing_total := banker_total if winner == "player" else player_total
	var natural_text := " Natural 8/9." if natural else ""
	return "%s is closer to 9 than %d.%s" % [_winner_display(winner), trailing_total, natural_text]


func _baccarat_settlement_summary(bet_results: Array, net: int) -> String:
	if bet_results.is_empty():
		return "You sat out. Net $0."
	var won: Array = []
	var lost: Array = []
	var pushed: Array = []
	for result_value in bet_results:
		var bet_result: Dictionary = result_value
		var label := str(bet_result.get("label", bet_result.get("id", "bet")))
		if bool(bet_result.get("push", false)):
			pushed.append("%s push" % label)
		elif bool(bet_result.get("won", false)):
			won.append("%s +$%d" % [label, int(bet_result.get("payout", 0))])
		else:
			lost.append("%s -$%d" % [label, int(bet_result.get("stake", 0))])
	var parts: Array = []
	if not won.is_empty():
		parts.append("Won %s" % _join_limited(won, 2))
	if not lost.is_empty():
		parts.append("Lost %s" % _join_limited(lost, 2))
	if not pushed.is_empty():
		parts.append(_join_limited(pushed, 2))
	return "%s. Net %+d." % ["; ".join(parts), net]


func _bets_display(bets: Dictionary) -> String:
	var labels: Array = []
	for bet_id in bets.keys():
		var amount := int(bets.get(bet_id, 0))
		if amount > 0:
			labels.append("%s $%d" % [_target_label(str(bet_id)), amount])
	return _join_limited(labels, 3)


func _join_limited(values: Array, limit: int) -> String:
	var clean: Array = []
	for value in values:
		var text := str(value)
		if not text.is_empty():
			clean.append(text)
	var shown: Array = []
	for i in range(mini(clean.size(), maxi(1, limit))):
		shown.append(str(clean[i]))
	if clean.size() > shown.size():
		shown.append("+%d more" % (clean.size() - shown.size()))
	return ", ".join(shown)


func _baccarat_pressure_message(table: Dictionary, pit_boss_status: Dictionary) -> String:
	if bool(pit_boss_status.get("watched", false)):
		return "Patrons go quiet as staff clock the shoe read."
	for patron_value in _dictionary_array(table.get("patrons", [])):
		var patron: Dictionary = patron_value
		if bool(patron.get("watching", false)):
			return "A patron tracks the read and glances toward staff."
	return ""


func _default_smoke_bets(stake: int) -> Dictionary:
	return {"player": maxi(1, stake)}


func _empty_baccarat_result(action_id: String, stake: int, environment: Dictionary, text: String) -> Dictionary:
	return GameModule.build_action_result({
		"ok": false,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": "unknown",
		"stake": stake,
		"won": false,
		"environment_id": environment.get("id", ""),
		"message": text,
	})


func _table_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	if states.has(get_id()) and typeof(states.get(get_id(), {})) == TYPE_DICTIONARY:
		return _stored_table_state(states, get_id(), environment)
	if states.has("baccarat") and typeof(states.get("baccarat", {})) == TYPE_DICTIONARY:
		return _stored_table_state(states, "baccarat", environment)
	var rng := run_state.create_rng("baccarat_table_fallback") if run_state != null else _default_table_rng({}, "fallback")
	var generated := generate_environment_state(run_state, environment, rng)
	_update_environment_table(environment, generated)
	return generated


func _table_state_preview(run_state: RunState, environment: Dictionary) -> Dictionary:
	var states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	if states.has(get_id()) and typeof(states.get(get_id(), {})) == TYPE_DICTIONARY:
		return _normalize_table_state(states.get(get_id(), {}), environment)
	if states.has("baccarat") and typeof(states.get("baccarat", {})) == TYPE_DICTIONARY:
		return _normalize_table_state(states.get("baccarat", {}), environment)
	var rng := run_state.create_rng("baccarat_table_preview") if run_state != null else _default_table_rng({}, "preview")
	return generate_environment_state(run_state, environment, rng)


func _stored_table_state(states: Dictionary, key: String, environment: Dictionary) -> Dictionary:
	var table_value: Variant = states.get(key, {})
	if typeof(table_value) != TYPE_DICTIONARY:
		return {}
	var table: Dictionary = table_value
	if _table_state_is_current(table):
		if int(table.get("storage_version", 0)) >= 1:
			_refresh_shoe_remaining_metadata(table)
			return table
		var stored := table.duplicate(true)
		stored["storage_version"] = 1
		_refresh_shoe_remaining_metadata(stored)
		states[key] = stored
		environment["game_states"] = states
		return stored
	var normalized := _normalize_table_state(table, environment)
	states[key] = normalized
	environment["game_states"] = states
	return normalized


func _table_state_is_current(table: Dictionary) -> bool:
	return str(table.get("schema", "")) == "baccarat_table_state" and int(table.get("normalized_version", 0)) >= 1


func _normalize_table_state(value: Variant, environment: Dictionary) -> Dictionary:
	var table := _copy_dict(value)
	if table.is_empty() or str(table.get("schema", "")) != "baccarat_table_state":
		var rng := _default_table_rng({}, "normalize")
		table = generate_environment_state(null, environment, rng)
	table["schema"] = "baccarat_table_state"
	table["deck_count"] = maxi(1, int(table.get("deck_count", 8)))
	table["rules"] = _copy_dict(table.get("rules", _default_rules(int(table.get("deck_count", 8)))))
	table["shoe"] = CardShoeScript.card_array(table.get("shoe", []))
	table["discard"] = _card_array(table.get("discard", []))
	table["burn_cards"] = _card_array(table.get("burn_cards", []))
	_refresh_shoe_cached_metadata(table)
	table["shoe_label"] = str(table.get("shoe_label", CardShoeScript.shoe_label(int(table.get("deck_count", 8)))))
	table["shoe_id"] = str(table.get("shoe_id", ""))
	if str(table.get("shoe_id", "")).is_empty():
		table["shoe_id"] = _shoe_state_id(int(table.get("deck_count", 8)), table.get("shoe", []), table.get("burn_cards", []))
	table["cut_card_remaining"] = maxi(8, int(table.get("cut_card_remaining", CardShoeScript.cut_card_remaining(int(table.get("deck_count", 8)), float(_table_rules(table).get("cut_card_penetration", 0.72))))))
	table["dealer_profile"] = _normalize_dealer_profile(table.get("dealer_profile", {}), table)
	table["patrons"] = _normalize_patrons(table.get("patrons", []), table)
	table["chip_denominations"] = _int_array(table.get("chip_denominations", [5, 10, 20, 25, 50, 100]))
	table["table_minimum"] = maxi(1, int(table.get("table_minimum", 20)))
	table["table_maximum"] = maxi(int(table.get("table_minimum", 20)), int(table.get("table_maximum", 500)))
	table["last_bets"] = _bet_dict(table.get("last_bets", {}))
	table["last_result"] = _copy_dict(table.get("last_result", {}))
	table["last_hand"] = _copy_dict(table.get("last_hand", {}))
	table["hand_history"] = _dictionary_array(table.get("hand_history", []))
	table["shoe_history"] = _dictionary_array(table.get("shoe_history", []))
	var challenge := _normalized_edge_sort_challenge(table.get("edge_sort_challenge", {}))
	if not challenge.is_empty() and str(challenge.get("shoe_id", "")) != str(table.get("shoe_id", "")):
		challenge = {}
	table["edge_sort_challenge"] = challenge
	table["edge_sort_edge"] = _normalized_edge_sort_edge(table.get("edge_sort_edge", {}), table)
	table["table_round_timer_started_msec"] = int(table.get("table_round_timer_started_msec", 0))
	table["normalized_version"] = 1
	table["storage_version"] = 1
	return table


func _refresh_shoe_cached_metadata(table: Dictionary) -> void:
	var shoe: Array = table.get("shoe", []) if typeof(table.get("shoe", [])) == TYPE_ARRAY else []
	var remaining := shoe.size()
	table["shoe_remaining"] = remaining
	var composition_value: Variant = table.get("shoe_composition", {})
	var cached_count := int(table.get("shoe_composition_count", -1))
	if typeof(composition_value) != TYPE_DICTIONARY or cached_count != remaining:
		table["shoe_composition"] = CardShoeScript.remaining_composition(shoe)
		table["shoe_composition_count"] = remaining


func _refresh_shoe_remaining_metadata(table: Dictionary) -> void:
	var shoe: Array = table.get("shoe", []) if typeof(table.get("shoe", [])) == TYPE_ARRAY else []
	table["shoe_remaining"] = shoe.size()


func _normalized_session(_run_state: RunState, _environment: Dictionary, ui_state: Dictionary, table: Dictionary) -> Dictionary:
	var session := ui_state.duplicate(true)
	var denoms := _chip_denominations(table)
	var selected_chip := int(session.get("selected_chip", session.get("selected_stake", denoms[0])))
	if not denoms.has(selected_chip):
		selected_chip = _closest_chip(selected_chip, denoms)
	session["selected_chip"] = selected_chip
	session["selected_stake"] = selected_chip
	session["baccarat_bets"] = _bet_dict(session.get("baccarat_bets", {}))
	session["baccarat_rebet"] = _bet_dict(session.get("baccarat_rebet", table.get("last_bets", {})))
	if typeof(session.get("baccarat_undo_stack", [])) != TYPE_ARRAY:
		session["baccarat_undo_stack"] = []
	session["edge_sort_answers"] = _string_array(session.get("edge_sort_answers", []))
	session["edge_sort_challenge"] = _normalized_edge_sort_challenge(session.get("edge_sort_challenge", table.get("edge_sort_challenge", {})))
	return session


func _update_environment_table(environment: Dictionary, table: Dictionary) -> void:
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	table["normalized_version"] = 1
	table["storage_version"] = 1
	_refresh_shoe_remaining_metadata(table)
	game_states[get_id()] = table
	environment["game_states"] = game_states


func _table_rules(table: Dictionary) -> Dictionary:
	return _copy_dict(table.get("rules", _default_rules(int(table.get("deck_count", 8)))))


func _chip_denominations(table: Dictionary) -> Array:
	var denoms := _int_array(table.get("chip_denominations", [5, 10, 20, 25, 50, 100]))
	if denoms.is_empty():
		denoms = [5, 10, 20, 25, 50, 100]
	denoms.sort()
	return denoms


func _closest_chip(value: int, denoms: Array) -> int:
	var best := int(denoms[0])
	var best_delta: int = abs(best - value)
	for denom in denoms:
		var delta: int = abs(int(denom) - value)
		if delta < best_delta:
			best = int(denom)
			best_delta = delta
	return best


func _generate_dealer_profile(rng: RngStream, catch_base: int) -> Dictionary:
	return {
		"name": str(rng.pick(["Marisol", "Anika", "Vega", "June", "Sato"], "Marisol")),
		"role": "baccarat_croupier",
		"portrait_seed": rng.randi_range(1000, 9999),
		"style": "grand_casino",
		"mood": str(rng.pick(["composed", "precise", "quiet", "formal"], "composed")),
		"catch_base": catch_base,
		"accent": _color_name(rng.pick(["cyan", "teal", "yellow", "pink"], "cyan")),
		"callouts": ["No more bets.", "Player draws.", "Banker stands.", "Natural nine.", "Commission marked."],
	}


func _generate_table_patrons(rng: RngStream, depth: int) -> Array:
	var names := ["Lena", "Miles", "Theo", "Nadia", "Rin", "Cole", "Iris", "Sol"]
	var bets := ["player", "banker", "tie", "player_pair", "banker_pair"]
	var tells := ["tracks chips", "leans in", "side eye", "shoe stare", "soft nod"]
	var result: Array = []
	var count := clampi(2 + depth % 3, 2, 4)
	for i in range(count):
		var mood := str(rng.pick(["calm", "watchful", "pleased", "tense"], "calm"))
		var snitch_risk := rng.randi_range(8, 30)
		if mood == "watchful" or mood == "tense":
			snitch_risk += 8
		result.append({
			"id": "patron_%d" % i,
			"name": str(rng.pick(names, names[0])),
			"seat": i,
			"mood": mood,
			"preferred_bet": str(rng.pick(bets, "banker")),
			"cosmetic_bet": int(rng.pick([20, 25, 40, 50, 100], 25)),
			"rapport": rng.randi_range(42, 62),
			"snitch_risk": clampi(snitch_risk, 4, 50),
			"chip_stack": rng.randi_range(20, 120),
			"chip_color": str(rng.pick(["cyan", "teal", "yellow", "pink", "orange"], "cyan")),
			"watching": rng.randi_range(0, 100) >= 36,
			"silhouette": str(rng.pick(["cap", "glasses", "coat", "rings"], "coat")),
			"tell": str(rng.pick(tells, tells[0])),
			"temper": str(rng.pick(["nosy", "careless", "loyal", "sharp"], "careless")),
			"seat_style": str(rng.pick(["vest", "jacket", "open"], "open")),
			"animation_offset": rng.randi_range(0, 3600),
			"snitch_threshold": rng.randi_range(18, 52),
			"last_reaction": "neutral",
			"accent": _color_name(rng.pick(["cyan", "teal", "yellow", "pink", "orange"], "cyan")),
		})
	return result


func _normalize_dealer_profile(value: Variant, table: Dictionary) -> Dictionary:
	var dealer := _copy_dict(value)
	if dealer.is_empty():
		dealer = _generate_dealer_profile(_default_table_rng(table, "dealer"), int(table.get("dealer_catch_base", 18)))
	if str(dealer.get("name", "")).is_empty():
		dealer["name"] = str(table.get("dealer_name", "Croupier"))
	if str(dealer.get("role", "")).is_empty():
		dealer["role"] = "baccarat_croupier"
	if not dealer.has("accent"):
		dealer["accent"] = _color_name("cyan")
	dealer["attention_base"] = clampi(int(dealer.get("attention_base", int(table.get("dealer_catch_base", 18)) + 12)), 8, 70)
	dealer["tell"] = str(dealer.get("tell", "watches hands more than faces"))
	dealer["uniform_accent"] = str(dealer.get("uniform_accent", "cyan tie"))
	dealer["read_style"] = str(dealer.get("read_style", "slow sweep"))
	dealer["gaze_speed"] = clampi(int(dealer.get("gaze_speed", 95)), 45, 180)
	dealer["blink_offset"] = maxi(0, int(dealer.get("blink_offset", 0)))
	return dealer


func _normalize_patrons(value: Variant, table: Dictionary) -> Array:
	var patrons := _dictionary_array(value)
	if patrons.is_empty():
		return _generate_table_patrons(_default_table_rng(table, "patrons"), 2)
	for i in range(patrons.size()):
		var patron: Dictionary = patrons[i]
		patron["id"] = str(patron.get("id", "patron_%d" % i))
		if str(patron.get("name", "")).is_empty():
			patron["name"] = "Guest %d" % (i + 1)
		patron["seat"] = int(patron.get("seat", i))
		patron["mood"] = str(patron.get("mood", "calm"))
		if str(patron.get("preferred_bet", "")).is_empty():
			patron["preferred_bet"] = "banker"
		patron["cosmetic_bet"] = maxi(1, int(patron.get("cosmetic_bet", 25)))
		patron["rapport"] = clampi(int(patron.get("rapport", 50)), 0, 100)
		if not patron.has("accent"):
			patron["accent"] = _color_name("cyan")
		patron["chip_color"] = str(patron.get("chip_color", str(_copy_dict(patron.get("accent", {})).get("name", "cyan"))))
		patron["snitch_risk"] = clampi(int(patron.get("snitch_risk", 18)), 0, 60)
		patron["chip_stack"] = maxi(0, int(patron.get("chip_stack", int(patron.get("cosmetic_bet", 25)))))
		patron["watching"] = bool(patron.get("watching", true))
		patron["silhouette"] = str(patron.get("silhouette", "coat"))
		patron["tell"] = str(patron.get("tell", "leans in"))
		patron["temper"] = str(patron.get("temper", "careless"))
		patron["seat_style"] = str(patron.get("seat_style", "open"))
		patron["animation_offset"] = maxi(0, int(patron.get("animation_offset", i * 620)))
		patron["snitch_threshold"] = clampi(int(patron.get("snitch_threshold", 30)), 4, 70)
		patrons[i] = patron
	return patrons


func _patrons_for_surface(table: Dictionary, last_result: Dictionary) -> Array:
	var patrons := _dictionary_array(table.get("patrons", []))
	var winner := str(last_result.get("winner", ""))
	var now := Time.get_ticks_msec()
	for i in range(patrons.size()):
		var patron: Dictionary = patrons[i]
		var reaction_bonus := 0
		if winner.is_empty():
			patron["last_reaction"] = "neutral"
		elif str(patron.get("preferred_bet", "")) == winner:
			patron["last_reaction"] = "won"
			reaction_bonus = -4
		else:
			patron["last_reaction"] = "lost" if winner != "tie" else "push"
			reaction_bonus = 8 if winner != "tie" else 2
		var rapport_adjust := int((50 - clampi(int(patron.get("rapport", 50)), 0, 100)) / 5)
		var risk := clampi(int(patron.get("snitch_risk", 0)) + reaction_bonus + rapport_adjust, 0, 60)
		var phase := float((now + int(patron.get("animation_offset", 0))) % 2200) / 2200.0
		var watching := bool(patron.get("watching", true)) and risk > 0
		var threshold := int(patron.get("snitch_threshold", 30))
		var tell_active := watching and (risk >= threshold or (phase > 0.58 and phase < 0.82))
		patron["covered"] = false
		patron["watching_player"] = watching
		patron["active_snitch_risk"] = risk
		patron["behavior_phase"] = phase
		patron["tell_active"] = tell_active
		patron["lean"] = (float(risk) / 60.0) * 5.0
		patron["behavior"] = "snitch tell" if tell_active else "watching" if watching else str(patron.get("mood", "calm"))
		patron["visible_bet"] = _baccarat_patron_wager(patron)
		patrons[i] = patron
	return patrons


func _patron_snitch_pressure(patrons: Array) -> int:
	var total := 0
	for patron_value in patrons:
		if typeof(patron_value) != TYPE_DICTIONARY:
			continue
		var patron: Dictionary = patron_value
		if bool(patron.get("watching_player", false)):
			total += int(patron.get("active_snitch_risk", 0))
	return total


func _baccarat_room_info(state: Dictionary) -> String:
	return "%s | %d left | comm $%d" % [
		str(state.get("shoe_label", "8-deck shoe")),
		int(state.get("shoe_remaining", 0)),
		int(state.get("commission_owed", 0)),
	]


func _color_name(name: Variant) -> Dictionary:
	return {"name": str(name)}


func _default_table_rng(table: Dictionary, suffix: String) -> RngStream:
	var rng := RngStream.new()
	rng.configure(_stable_hash("%s:%s:%s" % [get_id(), str(table.get("table_name", "baccarat")), suffix]))
	return rng


func _item_effect_total(key: String, run_state: RunState) -> int:
	if run_state == null:
		return 0
	return run_state.item_effect_total(key, get_family()) if run_state.has_method("item_effect_total") else 0


func _stable_hash(text: String) -> int:
	var value := 216613626
	for index in range(text.length()):
		value = value ^ text.unicode_at(index)
		value = int((value * 16777619) & 0x7fffffff)
	return maxi(1, value)


func _draw_baccarat_room(surface, state: Dictionary) -> void:
	TableVisualsScript.draw_room(surface, state, str(state.get("table_name", "Baccarat")), _baccarat_room_info(state))


func _draw_baccarat_table(surface, _state: Dictionary) -> void:
	TableVisualsScript.draw_table(surface)
	surface.draw_line(Vector2(450, 154), Vector2(450, 324), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.20), 1)
	surface.draw_line(Vector2(188, 224), Vector2(712, 224), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.18), 1)


func _draw_croupier_station(surface, state: Dictionary) -> void:
	TableVisualsScript.draw_dealer_station(surface, state)


func _draw_hand_explainer(surface, state: Dictionary) -> void:
	var explainer := _copy_dict(state.get("baccarat_explainer", {}))
	if explainer.is_empty():
		return
	var rect := Rect2(684, 14, 192, 58)
	var winner := str(explainer.get("winner", ""))
	var accent := _target_color(winner) if not winner.is_empty() else C_YELLOW
	_draw_neon_panel(surface, rect, accent, 0.15)
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.52), false, 1)
	surface.surface_label_centered(str(explainer.get("title", "BACCARAT")).left(24), Rect2(rect.position + Vector2(8, 5), Vector2(rect.size.x - 16, 13)), 11, accent)
	surface.surface_label_centered(str(explainer.get("primary", "")).left(38), Rect2(rect.position + Vector2(8, 22), Vector2(rect.size.x - 16, 12)), 8, C_WHITE)
	surface.surface_label_centered(str(explainer.get("secondary", "")).left(44), Rect2(rect.position + Vector2(8, 36), Vector2(rect.size.x - 16, 10)), 7, C_SOFT)
	surface.surface_label_centered(str(explainer.get("bet_summary", "")).left(44), Rect2(rect.position + Vector2(8, 47), Vector2(rect.size.x - 16, 8)), 6, C_YELLOW)


func _draw_table_patrons(surface, state: Dictionary) -> void:
	TableVisualsScript.draw_table_patrons(surface, state)


func _draw_bet_zones(surface, state: Dictionary) -> void:
	var targets := _dictionary_array(state.get("bet_targets", []))
	var bets := _bet_dict(state.get("baccarat_bets", {}))
	for i in range(targets.size()):
		var target: Dictionary = targets[i]
		var rect: Rect2 = target.get("rect", Rect2())
		var bet_id := str(target.get("id", ""))
		var hovered: bool = bool(surface.surface_region_hovered("baccarat_bet", i))
		var active := int(bets.get(bet_id, 0)) > 0
		var accent := _target_color(bet_id)
		var fill_alpha := 0.24 if active else 0.18 if hovered else 0.10
		surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, fill_alpha))
		surface.draw_rect(rect, C_WHITE if hovered else accent, false, 2 if hovered else 1)
		surface.surface_label_centered(str(target.get("label", bet_id)).left(14), rect.grow(-4), 12 if rect.size.y >= 60 else 9, C_WHITE)
		var payout := int(target.get("payout", 1))
		var payout_text := "PUSH TIE" if bet_id == "player" or bet_id == "banker" else "PAYS %d:1" % payout
		if bet_id == "banker":
			payout_text = "5% COMM"
		surface.surface_label_centered(payout_text, Rect2(rect.position + Vector2(4, rect.size.y - 18), Vector2(rect.size.x - 8, 14)), 8, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.82))
		surface.surface_add_exact_hit(rect, "baccarat_bet", i)


func _draw_card_areas(surface, state: Dictionary) -> void:
	var last_hand := _copy_dict(state.get("last_hand", {}))
	var player_cards := _card_array(last_hand.get("player_cards", []))
	var banker_cards := _card_array(last_hand.get("banker_cards", []))
	var deal_active := str(state.get("phase", "")) == "dealing"
	var visible_cards := _visible_animation_cards(surface, state) if deal_active else []
	if deal_active and not visible_cards.is_empty():
		for event in visible_cards:
			var card_event: Dictionary = event
			_draw_card(surface, card_event.get("card", {}), card_event.get("position", Vector2.ZERO), 1.0)
		var squeeze_event := _active_squeeze_event(surface, state)
		if not squeeze_event.is_empty():
			_draw_squeeze_badge(surface, squeeze_event)
	else:
		for i in range(player_cards.size()):
			_draw_card(surface, player_cards[i], _player_card_target(i), 1.0)
		for i in range(banker_cards.size()):
			_draw_card(surface, banker_cards[i], _banker_card_target(i), 1.0)
	surface.surface_label("PLAYER", Vector2(220, 236), 14, C_CYAN)
	surface.surface_label("BANKER", Vector2(604, 228), 14, C_PINK_2)
	if not last_hand.is_empty() and not deal_active:
		_draw_total_badge(surface, Rect2(282, 297, 132, 22), "PLAYER TOTAL", int(last_hand.get("player_total", 0)), C_CYAN)
		var banker_total_x := _banker_card_target(banker_cards.size()).x + 8.0
		_draw_total_badge(surface, Rect2(banker_total_x, 202, 132, 22), "BANKER TOTAL", int(last_hand.get("banker_total", 0)), C_PINK_2)
		var winner := str(last_hand.get("winner", ""))
		var marker := Rect2(382, 194, 136, 30)
		surface.draw_rect(marker, Color(0.0, 0.0, 0.0, 0.64))
		surface.draw_rect(marker, _target_color(winner), false, 2)
		surface.surface_label_centered(_winner_title(winner).left(16), marker, 14, C_WHITE)
		surface.surface_label_centered(_baccarat_winner_reason(winner, int(last_hand.get("player_total", 0)), int(last_hand.get("banker_total", 0)), bool(last_hand.get("natural", false))).left(38), Rect2(314, 224, 272, 14), 9, C_YELLOW)


func _active_squeeze_event(surface, state: Dictionary) -> Dictionary:
	var progress_elapsed: float = float(surface.surface_elapsed(BACCARAT_DEAL_CHANNEL))
	for event_value in _dictionary_array(state.get("deal_animation_events", [])):
		var event: Dictionary = event_value
		if str(event.get("type", "")) != "squeeze":
			continue
		var delay := float(int(event.get("delay_msec", 0))) / 1000.0
		var duration := maxf(0.001, float(int(event.get("duration_msec", 520))) / 1000.0)
		if progress_elapsed >= delay and progress_elapsed <= delay + duration + 0.8:
			return event
	return {}


func _draw_squeeze_badge(surface, event: Dictionary) -> void:
	var rect := Rect2(382, 190, 136, 34)
	var accent := _target_color(str(event.get("winner", "")))
	_draw_neon_panel(surface, rect, accent, 0.24)
	surface.surface_label_centered("SQUEEZE", Rect2(rect.position + Vector2(6, 4), Vector2(rect.size.x - 12, 12)), 12, C_WHITE)
	surface.surface_label_centered("P%d  B%d" % [int(event.get("player_total", 0)), int(event.get("banker_total", 0))], Rect2(rect.position + Vector2(6, 18), Vector2(rect.size.x - 12, 10)), 8, C_YELLOW)


func _draw_total_badge(surface, rect: Rect2, label: String, total: int, accent: Color) -> void:
	surface.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.58))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.64), false, 1)
	surface.surface_label_centered("%s: %d" % [label, total], rect.grow(-2.0), 10, accent)


func _visible_animation_cards(surface, state: Dictionary) -> Array:
	var progress_elapsed: float = float(surface.surface_elapsed(BACCARAT_DEAL_CHANNEL))
	var events := _dictionary_array(state.get("deal_animation_events", []))
	var visible: Array = []
	for event_value in events:
		var event: Dictionary = event_value
		if str(event.get("type", "card")) != "card":
			continue
		var delay := float(int(event.get("delay_msec", 0))) / 1000.0
		if progress_elapsed < delay:
			continue
		var duration := maxf(0.001, float(int(event.get("duration_msec", 520))) / 1000.0)
		var t := clampf((progress_elapsed - delay) / duration, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - t, 3.0)
		var from_pos := _event_vector(event.get("from", []), CARD_SHOE_POS)
		var to_pos := _event_vector(event.get("to", []), CARD_SHOE_POS)
		visible.append({"card": _copy_dict(event.get("card", {})), "position": from_pos.lerp(to_pos, eased)})
	return visible


func _draw_bet_chips(surface, state: Dictionary) -> void:
	var bets := _bet_dict(state.get("baccarat_bets", {}))
	var targets := _dictionary_array(state.get("bet_targets", []))
	var denoms := _int_array(state.get("chip_denominations", [5, 10, 20, 25, 50, 100]))
	_draw_patron_bet_chips(surface, state, targets)
	for target_value in targets:
		var target: Dictionary = target_value
		var bet_id := str(target.get("id", ""))
		var stake := int(bets.get(bet_id, 0))
		if stake <= 0:
			continue
		var rect: Rect2 = target.get("rect", Rect2())
		var center := rect.get_center() + Vector2(0, 10)
		_draw_chip_stack(surface, center, _chip_stack_for_stake(stake, denoms), 0.86)
		surface.draw_rect(Rect2(center - Vector2(21, 21), Vector2(42, 44)), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.70), false, 1)
		surface.surface_label_centered("YOU", Rect2(center + Vector2(-18, 21), Vector2(36, 10)), 7, C_CYAN)


func _draw_patron_bet_chips(surface, state: Dictionary, targets: Array) -> void:
	var patrons := _dictionary_array(state.get("patrons", []))
	for i in range(patrons.size()):
		var patron: Dictionary = patrons[i]
		var wager := _copy_dict(patron.get("visible_bet", {}))
		var target := _baccarat_target_by_id(targets, str(wager.get("id", "")))
		if target.is_empty():
			continue
		var rect: Rect2 = target.get("rect", Rect2())
		var center := rect.get_center() + Vector2(-34 + float(i % 4) * 18.0, -18 - float(i / 4) * 10.0)
		var color := _patron_chip_color(str(patron.get("chip_color", "cyan")))
		surface.draw_circle(center, 8.0, Color(C_DARK.r, C_DARK.g, C_DARK.b, 0.90))
		surface.draw_circle(center, 6.4, color)
		surface.draw_circle(center, 2.7, Color("#f8f4dc"))
		surface.surface_label_centered("THEM", Rect2(center + Vector2(-16, 7), Vector2(32, 8)), 6, color)


func _baccarat_target_by_id(targets: Array, target_id: String) -> Dictionary:
	for target_value in targets:
		var target: Dictionary = target_value
		if str(target.get("id", "")) == target_id:
			return target
	return {}


func _patron_chip_color(name: String) -> Color:
	match name:
		"pink":
			return C_PINK
		"yellow":
			return C_YELLOW
		"teal":
			return C_TEAL
		"orange":
			return C_ORANGE
		"blue", "cyan":
			return C_CYAN
		_:
			return C_SOFT


func _draw_shoe_and_discard(surface, state: Dictionary) -> void:
	var shoe := Rect2(728, 82, 68, 54)
	surface.draw_rect(shoe, Color("#21111b"))
	surface.draw_rect(Rect2(shoe.position + Vector2(8, 9), Vector2(48, 34)), Color("#f3edda"))
	for i in range(5):
		surface.draw_rect(Rect2(shoe.position + Vector2(12 + i * 7, 12 - i), Vector2(30, 24)), Color(0.94, 0.90, 0.78, 0.85))
	surface.draw_rect(shoe, C_YELLOW, false, 1)
	surface.surface_label_centered("%d LEFT" % int(state.get("shoe_remaining", 0)), Rect2(716, 140, 90, 14), 8, C_YELLOW)
	var penetration := _copy_dict(state.get("shoe_penetration", {}))
	if not penetration.is_empty():
		surface.surface_label_centered("%d%% USED" % int(penetration.get("penetration_percent", 0)), Rect2(716, 154, 90, 12), 7, C_SOFT)
	var discard := Rect2(102, 86, 78, 42)
	surface.draw_rect(discard, Color("#0d111a"))
	surface.draw_rect(discard, C_CYAN, false, 1)
	for i in range(3):
		_draw_card_back(surface, discard.position + Vector2(12 + i * 13, 8 - i * 2), 0.45)
	surface.surface_label_centered("DISCARD", Rect2(100, 132, 82, 12), 8, C_SOFT)
	if bool(state.get("reshuffle_pending", false)):
		surface.surface_label_centered("CUT CARD OUT", Rect2(640, 68, 116, 14), 9, C_ORANGE)


func _draw_baccarat_road(surface, state: Dictionary) -> void:
	var road := _copy_dict(state.get("baccarat_road", {}))
	if road.is_empty():
		return
	var rect := Rect2(18, 150, 146, 94)
	_draw_neon_panel(surface, rect, C_CYAN, 0.10)
	surface.surface_label("BEAD PLATE", rect.position + Vector2(8, 10), 9, C_CYAN)
	surface.surface_label_centered(str(road.get("summary", "")).left(18), Rect2(rect.position + Vector2(70, 5), Vector2(66, 12)), 7, C_SOFT)
	var rows := maxi(1, int(road.get("rows", BACCARAT_ROAD_ROWS)))
	var columns := maxi(1, int(road.get("columns", BACCARAT_ROAD_COLUMNS)))
	var beads := _dictionary_array(road.get("beads", []))
	var cell := 9.6
	var origin := rect.position + Vector2(10, 26)
	for column_index in range(columns):
		for row_index in range(rows):
			var dot_center := origin + Vector2(float(column_index) * cell + 4.8, float(row_index) * cell + 4.8)
			surface.draw_circle(dot_center, 3.8, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.14))
	for bead_value in beads:
		var bead: Dictionary = bead_value
		var bead_column := int(bead.get("column", 0))
		var bead_row := int(bead.get("row", 0))
		if bead_column < 0 or bead_column >= columns or bead_row < 0 or bead_row >= rows:
			continue
		var winner := str(bead.get("winner", ""))
		var center := origin + Vector2(float(bead_column) * cell + 4.8, float(bead_row) * cell + 4.8)
		var accent := _target_color(winner)
		surface.draw_circle(center, 4.1, Color(accent.r, accent.g, accent.b, 0.96))
		surface.surface_label_centered(_road_winner_mark(winner), Rect2(center - Vector2(4.0, 4.6), Vector2(8, 9)), 6, C_DARK)
	if int(road.get("visible_count", 0)) <= 0:
		surface.surface_label_centered("NO HANDS", Rect2(rect.position + Vector2(8, 62), Vector2(rect.size.x - 16, 10)), 7, C_SOFT)


func _road_winner_mark(winner: String) -> String:
	match winner:
		"player":
			return "P"
		"banker":
			return "B"
		"tie":
			return "T"
		_:
			return ""


func _draw_edge_sort_panel(surface, state: Dictionary) -> void:
	var status := _copy_dict(state.get("edge_sort_status", state.get("baccarat_edge_sort_status", {})))
	var challenge := _copy_dict(state.get("edge_sort_challenge", state.get("baccarat_edge_sort_challenge", {})))
	var edge := _copy_dict(state.get("edge_sort_edge", state.get("baccarat_edge_sort_edge", {})))
	if challenge.is_empty() and edge.is_empty():
		return
	var rect := Rect2(202, 72, 492, 28)
	var accent := C_PINK_2 if bool(status.get("ready", false)) else C_TEAL
	if not edge.is_empty():
		accent = C_YELLOW
	_draw_neon_panel(surface, rect, accent, 0.14)
	var detail := ""
	if not edge.is_empty():
		detail = "%s %d%%  %d HANDS" % [_winner_display(str(edge.get("predicted_bet", ""))).to_upper(), int(edge.get("confidence", 0)), int(edge.get("hands_remaining", 0))]
	elif bool(status.get("ready", false)):
		detail = "SEQUENCE READY"
	else:
		detail = "%d/%d CUES  %d/%d HANDS" % [
			int(status.get("cue_count", 0)),
			int(status.get("required_cue_count", EDGE_SORT_CUE_COUNT)),
			int(status.get("observed_hands", 0)),
			int(status.get("required_hands", EDGE_SORT_MIN_HANDS)),
		]
	surface.surface_label("EDGE", rect.position + Vector2(8, 8), 10, accent)
	surface.surface_label_centered(detail.left(44), Rect2(rect.position + Vector2(50, 6), Vector2(238, 14)), 9, C_WHITE)
	if bool(status.get("ready", false)):
		var labels := ["H", "L", "N"]
		for i in range(labels.size()):
			var cue_rect := Rect2(rect.position + Vector2(302 + i * 34, 5), Vector2(28, 18))
			_draw_table_button(surface, cue_rect, str(labels[i]), "baccarat_edge_sort_answer", i, accent, true)
		_draw_table_button(surface, Rect2(rect.position + Vector2(408, 5), Vector2(70, 18)), "COMMIT", "baccarat_edge_sort", 0, C_YELLOW, true)
	else:
		_draw_table_button(surface, Rect2(rect.position + Vector2(396, 5), Vector2(82, 18)), "EDGE", "baccarat_edge_sort", 0, accent, true)


func _draw_table_notice(surface, state: Dictionary) -> void:
	var notice := str(state.get("table_notice", "")).strip_edges()
	if notice.is_empty():
		return
	var rect := Rect2(238, 314, 424, 26)
	_draw_neon_panel(surface, rect, C_TEAL, 0.18)
	surface.surface_label_centered(notice.left(78), Rect2(rect.position + Vector2(8, 5), rect.size - Vector2(16, 8)), 11, C_TEAL)


func _draw_round_timer(surface, state: Dictionary) -> void:
	TableVisualsScript.draw_round_timer_panel(surface, state.get("table_round_timer", {}), Rect2(664, 314, 116, 26), C_CYAN)


func _draw_chip_rack(surface, state: Dictionary) -> void:
	var denoms := _int_array(state.get("chip_denominations", [5, 10, 20, 25, 50, 100]))
	var selected := int(state.get("selected_chip", denoms[0]))
	surface.surface_label("CHIPS", Vector2(28, CONSOLE_Y + 19), 12, C_YELLOW)
	for i in range(denoms.size()):
		var center := Vector2(92 + i * 40, CONSOLE_Y + 36)
		_draw_chip_button(surface, center, int(denoms[i]), "baccarat_chip", i, int(denoms[i]) == selected)


func _draw_action_console(surface, state: Dictionary) -> void:
	var panel := Rect2(0, CONSOLE_Y, 900, 86)
	surface.draw_rect(panel, Color(0.02, 0.02, 0.05, 0.84))
	surface.draw_rect(panel, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.18), false, 1)
	surface.surface_label("MIN $%d  MAX $%d" % [int(state.get("table_minimum", 20)), int(state.get("table_maximum", 500))], Vector2(342, CONSOLE_Y + 22), 12, C_SOFT)
	surface.surface_label("WAGER $%d" % int(state.get("total_wager_cost", 0)), Vector2(342, CONSOLE_Y + 42), 14, C_YELLOW)
	surface.surface_label("COMM $%d" % int(state.get("commission_owed", 0)), Vector2(342, CONSOLE_Y + 62), 12, C_PINK_2)
	_draw_table_button(surface, Rect2(520, CONSOLE_Y + 15, 62, 42), "CLEAR", "baccarat_clear", 0, C_ORANGE, bool(state.get("can_clear", false)))
	_draw_table_button(surface, Rect2(590, CONSOLE_Y + 15, 62, 42), "UNDO", "baccarat_undo", 0, C_CYAN, bool(state.get("can_undo", false)))
	_draw_table_button(surface, Rect2(660, CONSOLE_Y + 15, 70, 42), "REBET", "baccarat_rebet", 0, C_TEAL, bool(state.get("can_rebet", false)))
	_draw_table_button(surface, Rect2(738, CONSOLE_Y + 15, 64, 42), "DEAL", "baccarat_deal", 0, C_YELLOW, bool(state.get("can_deal", false)), bool(state.get("can_deal", false)))
	_draw_table_button(surface, Rect2(810, CONSOLE_Y + 15, 38, 42), "READ", "baccarat_read_shoe", 0, C_PINK_2, true)
	_draw_table_button(surface, Rect2(856, CONSOLE_Y + 15, 38, 42), "EDGE", "baccarat_edge_sort", 0, C_TEAL, true)


func _draw_card(surface, card_value: Variant, pos: Vector2, scale: float = 1.0) -> void:
	var card := _copy_dict(card_value)
	var size := CARD_SIZE * scale
	var rect := Rect2(pos, size)
	if bool(card.get("hidden", false)):
		_draw_card_back(surface, pos, scale)
		return
	surface.draw_rect(rect, C_SOFT)
	surface.draw_rect(Rect2(pos + Vector2(3, 3) * scale, size - Vector2(6, 6) * scale), Color("#fbf8e6"))
	var rank := _rank_text(int(card.get("rank", 2)))
	var suit := int(card.get("suit", 0))
	var color := C_PINK if suit == 1 or suit == 3 else C_DARK
	surface.surface_label(rank, pos + Vector2(7, 21) * scale, int(15 * scale), color)
	_draw_suit(surface, pos + Vector2(22, 40) * scale, suit, color, scale)


func _draw_card_back(surface, pos: Vector2, scale: float = 1.0) -> void:
	var size := CARD_SIZE * scale
	surface.draw_rect(Rect2(pos, size), C_SOFT)
	surface.draw_rect(Rect2(pos + Vector2(3, 3) * scale, size - Vector2(6, 6) * scale), C_PINK)
	surface.draw_rect(Rect2(pos + Vector2(9, 9) * scale, size - Vector2(18, 18) * scale), Color("#563be0"))


func _draw_suit(surface, pos: Vector2, suit: int, color: Color, scale: float = 1.0) -> void:
	match suit:
		0:
			surface.draw_rect(Rect2(pos.x - 4 * scale, pos.y - 10 * scale, 8 * scale, 17 * scale), color)
			surface.draw_rect(Rect2(pos.x - 9 * scale, pos.y - 2 * scale, 18 * scale, 6 * scale), color)
		1:
			surface.draw_circle(pos + Vector2(-5, -3) * scale, 5 * scale, color)
			surface.draw_circle(pos + Vector2(5, -3) * scale, 5 * scale, color)
			surface.draw_polygon([pos + Vector2(-10, 0) * scale, pos + Vector2(10, 0) * scale, pos + Vector2(0, 13) * scale], [color])
		2:
			surface.draw_polygon([pos + Vector2(0, -12) * scale, pos + Vector2(10, 0) * scale, pos + Vector2(0, 13) * scale, pos + Vector2(-10, 0) * scale], [color])
		_:
			surface.draw_circle(pos + Vector2(-5, 0) * scale, 5 * scale, color)
			surface.draw_circle(pos + Vector2(5, 0) * scale, 5 * scale, color)
			surface.draw_circle(pos + Vector2(0, -7) * scale, 5 * scale, color)


func _rank_text(rank: int) -> String:
	match rank:
		14:
			return "A"
		13:
			return "K"
		12:
			return "Q"
		11:
			return "J"
		_:
			return str(rank)


func _draw_neon_panel(surface, rect: Rect2, accent: Color, alpha: float = 0.16) -> void:
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, alpha))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, minf(0.95, alpha + 0.22)), false, 1)


func _draw_table_button(surface, rect: Rect2, label: String, action: String, index: int, accent: Color, enabled: bool = true, selected: bool = false) -> void:
	var hovered: bool = bool(surface.surface_region_hovered(action, index))
	var color := accent if enabled else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.30)
	surface.draw_rect(rect, Color(color.r, color.g, color.b, 0.22 if selected or hovered else 0.10))
	surface.draw_rect(rect, color, false, 1)
	surface.surface_label_centered(label.left(13), rect.grow(-2), 8 if rect.size.y < 24 else 10, color)
	if enabled:
		surface.surface_add_hit(rect, action, index)


func _draw_chip_button(surface, center: Vector2, value: int, action: String, index: int, selected: bool = false) -> void:
	_draw_casino_chip(surface, center, value, 15.0, 1.0, selected)
	surface.surface_add_hit(Rect2(center - Vector2(18, 18), Vector2(36, 36)), action, index)


func _draw_chip_stack(surface, pos: Vector2, stack_value: Variant, scale: float = 1.0) -> void:
	var stacks := _dictionary_array(stack_value)
	var y := 0.0
	for stack in stacks:
		var count := clampi(int(stack.get("count", 1)), 1, 8)
		for i in range(count):
			_draw_casino_chip(surface, pos + Vector2(0, y - float(i) * 3.0 * scale), int(stack.get("value", 1)), 12.0 * scale, 0.94, false)
		y -= float(count + 1) * 3.0 * scale


func _draw_casino_chip(surface, center: Vector2, value: int, radius: float, alpha: float = 1.0, selected: bool = false) -> void:
	var color := _chip_color(value)
	surface.draw_circle(center, radius + (2.0 if selected else 0.0), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.58 if selected else 0.20))
	surface.draw_circle(center, radius, Color(color.r, color.g, color.b, alpha))
	surface.draw_circle(center, radius * 0.55, Color("#f8f4dc"))
	surface.surface_label_centered("%d" % value, Rect2(center - Vector2(radius, 5), Vector2(radius * 2.0, 10)), 7, C_DARK)


func _chip_color(value: int) -> Color:
	if value >= 100:
		return C_ORANGE
	if value >= 50:
		return C_PINK_2
	if value >= 25:
		return C_PINK
	if value >= 10:
		return C_YELLOW
	if value >= 5:
		return C_CYAN
	return C_TEAL


func _draw_table_character(surface, style: Dictionary, foot: Vector2, scale_value: float) -> void:
	var accent := _style_accent(style)
	var body := Rect2(foot + Vector2(-15, -38) * scale_value, Vector2(30, 34) * scale_value)
	var head := Rect2(foot + Vector2(-11, -60) * scale_value, Vector2(22, 22) * scale_value)
	surface.draw_rect(body, Color("#171022"))
	surface.draw_rect(body, Color(accent.r, accent.g, accent.b, 0.34), false, 1)
	surface.draw_rect(head, Color("#c49371"))
	surface.draw_rect(Rect2(head.position + Vector2(4, 8) * scale_value, Vector2(4, 3) * scale_value), C_DARK)
	surface.draw_rect(Rect2(head.position + Vector2(14, 8) * scale_value, Vector2(4, 3) * scale_value), C_DARK)
	surface.surface_label_centered(str(style.get("name", "")).left(8), Rect2(foot + Vector2(-34, 2), Vector2(68, 12)), 8, accent)


func _style_accent(style: Dictionary) -> Color:
	var accent_value: Variant = style.get("accent", {})
	if typeof(accent_value) == TYPE_DICTIONARY:
		match str((accent_value as Dictionary).get("name", "cyan")):
			"pink":
				return C_PINK
			"teal":
				return C_TEAL
			"yellow":
				return C_YELLOW
			"orange":
				return C_ORANGE
			_:
				return C_CYAN
	if typeof(accent_value) == TYPE_COLOR:
		return accent_value
	return C_CYAN


func _patron_seat_position(index: int) -> Vector2:
	match index:
		0:
			return Vector2(156, 186)
		1:
			return Vector2(742, 184)
		2:
			return Vector2(224, 334)
		3:
			return Vector2(676, 334)
		_:
			return Vector2(94, 286)


func _target_color(target_id: String) -> Color:
	match target_id:
		"player":
			return C_CYAN
		"banker":
			return C_PINK_2
		"tie":
			return C_YELLOW
		"player_pair", "banker_pair":
			return C_TEAL
		_:
			return C_SOFT


func _target_label(target_id: String) -> String:
	for target_value in BET_TARGETS:
		var target: Dictionary = target_value
		if str(target.get("id", "")) == target_id:
			return str(target.get("label", target_id))
	return target_id.capitalize()


func _chip_stack_for_stake(stake: int, chip_values: Array) -> Array:
	var remaining := maxi(0, stake)
	var sorted := chip_values.duplicate(true)
	sorted.sort()
	sorted.reverse()
	var result: Array = []
	for value in sorted:
		var chip := int(value)
		if chip <= 0:
			continue
		var count := int(remaining / chip)
		if count > 0:
			result.append({"value": chip, "count": count})
			remaining -= count * chip
	if remaining > 0:
		result.append({"value": remaining, "count": 1})
	return result


func _event_point(pos: Vector2) -> Array:
	return [pos.x, pos.y]


func _event_vector(value: Variant, fallback: Vector2) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value
	if typeof(value) == TYPE_ARRAY:
		var parts: Array = value
		if parts.size() >= 2:
			return Vector2(float(parts[0]), float(parts[1]))
	if typeof(value) == TYPE_DICTIONARY:
		var dict: Dictionary = value
		return Vector2(float(dict.get("x", fallback.x)), float(dict.get("y", fallback.y)))
	return fallback


func _vector_to_dict(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _total_wager(bets: Dictionary) -> int:
	var total := 0
	for key in bets.keys():
		total += maxi(0, int(bets.get(key, 0)))
	return total


func _bet_dict(value: Variant) -> Dictionary:
	var result := {}
	if typeof(value) == TYPE_DICTIONARY:
		for key in (value as Dictionary).keys():
			var amount := maxi(0, int((value as Dictionary).get(key, 0)))
			if amount > 0:
				result[str(key)] = amount
	elif typeof(value) == TYPE_ARRAY:
		for entry in value:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var bet: Dictionary = entry
			var bet_id := str(bet.get("id", bet.get("target", "")))
			var amount := maxi(0, int(bet.get("stake", 0)))
			if not bet_id.is_empty() and amount > 0:
				result[bet_id] = int(result.get(bet_id, 0)) + amount
	return result


func _card_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _int_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		result.append(int(entry))
	return result


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var text := str(entry).strip_edges()
		if not text.is_empty():
			result.append(text)
	return result


func _array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
