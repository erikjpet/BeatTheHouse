class_name BlackjackGame
extends GameModule

# Full-simulation blackjack module. The shared UI canvas only hosts the surface;
# this module owns shoe state, table rules, side bets, player decisions, and
# cheat detection.

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

const RANK_ACE := 14
const DEAL_ANIMATION_CHANNEL := "blackjack_deal"
const ATTENTION_ANIMATION_CHANNEL := "blackjack_attention"
const COUNT_ANIMATION_CHANNEL := "blackjack_count_rhythm"
const PAYOUT_ANIMATION_CHANNEL := "blackjack_payout"
const DEAL_CARD_DURATION_MSEC := 380
const DEAL_CARD_STAGGER_MSEC := 185
const DEAL_CARD_SHOE_POS := Vector2(736, 126)
const PAYOUT_ANIMATION_DURATION_MSEC := 1800
const COUNT_ICON_DURATION_MSEC := 3000
const COUNT_ICON_STAGGER_MSEC := 520
const COUNT_ICON_FADE_MSEC := 420
const PATRON_DECISION_START_DELAY_MSEC := 260
const PATRON_DECISION_STEP_DELAY_MSEC := 220
const PATRON_HIT_CARD_DELAY_MSEC := 110
const PATRON_DECISION_HIGHLIGHT_MSEC := 840
const BLACKJACK_MAX_SIDE_BETS := 2
const BLACKJACK_PAYOUT_LABEL := "3:2"
const STRATEGY_DEVIATION_MAX_HEAT := 24
const STRATEGY_DEVIATION_MAX_WATCH := 45
const COOLERS_CUFFLINKS_ITEM_ID := "coolers_cufflinks"
const BROKEN_CUFFLINKS_ITEM_ID := "broken_cufflinks"
const PLAYER_CARD_SCALE := 0.70
const DEALER_CARD_SCALE := 0.78
const PATRON_CARD_SCALE := 0.43
const BJ_CONSOLE_Y := 342.0
const BJ_CONSOLE_H := 84.0
const BJ_TABLE_BOTTOM := 334.0
const DRAW_DEAL_EVENTS_CACHE_KEY := "_blackjack_draw_deal_events"


func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
	var result: Dictionary = super.enter(run_state, environment)
	var table: Dictionary = _table_state(run_state, environment)
	if bool(table.get("barred", false)):
		result["message"] = str(table.get("barred_reason", "The dealer refuses to let you play this table after the cheating confrontation."))
		return result
	var side_bets: Array = _side_bet_labels(_available_side_bets(table))
	var rules: Dictionary = _table_rules(table)
	result["message"] = "%s watches the shoe. Side bets: %s. Blackjack pays %s; dealer %s soft 17; insurance opens on an ace." % [
		str(table.get("dealer_name", "The dealer")),
		", ".join(side_bets) if not side_bets.is_empty() else "none",
		BLACKJACK_PAYOUT_LABEL,
		"hits" if bool(rules.get("dealer_hits_soft_17", false)) else "stands on",
	]
	return result


func legal_actions(run_state: RunState, environment: Dictionary) -> Array:
	if bool(_table_state(run_state, environment).get("barred", false)):
		return []
	return super.legal_actions(run_state, environment)


func cheat_actions(run_state: RunState, environment: Dictionary) -> Array:
	if bool(_table_state(run_state, environment).get("barred", false)):
		return []
	return super.cheat_actions(run_state, environment)


func actions(run_state: RunState, environment: Dictionary) -> Dictionary:
	var result: Dictionary = super.actions(run_state, environment)
	result["stake_floor"] = _surface_stake_floor(run_state, environment)
	result["stake_ceiling"] = _surface_stake_ceiling(run_state, environment)
	result["base_stake_ceiling"] = _blackjack_base_stake_ceiling(run_state, environment)
	result["economy_stake_ceiling"] = _surface_stake_ceiling(run_state, environment)
	result["economy_pressure_applied"] = false
	return result


func generate_environment_state(_run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var deck_count_options: Array = [2, 3, 4, 6]
	var deck_count: int = int(rng.pick(deck_count_options, 6))
	var shoe: Array = _build_shoe(deck_count, rng)
	var cut_remaining := CardShoeScript.cut_card_remaining(deck_count)
	# Act 1 tables intentionally model common shoe variants: S17/H17, DAS/no
	# DAS, split to 3-4 hands, one-card split aces, and late surrender.
	var rule_variants: Array = [
		{"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true},
		{"dealer_hits_soft_17": true, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 3, "late_surrender": false},
		{"dealer_hits_soft_17": false, "double_after_split": false, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true},
	]
	var rules: Dictionary = (rng.pick(rule_variants, rule_variants[0]) as Dictionary).duplicate(true)
	var side_bet_min: int = 2
	var side_bet_max: int = BLACKJACK_MAX_SIDE_BETS
	var side_bet_count: int = rng.randi_range(side_bet_min, side_bet_max)
	var side_bets: Array = rng.pick_many(_side_bet_catalog(), side_bet_count)
	var security: Dictionary = environment.get("security_profile", {}) if typeof(environment.get("security_profile", {})) == TYPE_DICTIONARY else {}
	var strictness := str(security.get("strictness", "low"))
	var catch_base := 10
	match strictness:
		"high":
			catch_base = 18
		"boss":
			catch_base = 22
		"private", "uneven":
			catch_base = 14
		_:
			catch_base = 9
	var dealer_profile: Dictionary = _generate_dealer_profile(rng, catch_base)
	var patrons: Array = _generate_table_patrons(rng, int(environment.get("depth", 0)))
	var distractions: Array = _generate_table_distractions(rng)
	return {
		"schema": "blackjack_table_state",
		"version": 2,
		"table_name": str(rng.pick(["Neon Felt", "Back Room 21", "Hot Shoe", "Midnight Double"], "Neon Felt")),
		"dealer_name": str(rng.pick(["Mara", "Lee", "Rook", "Vega", "June"], "Mara")),
		"deck_count": deck_count,
		"shoe": shoe,
		"shoe_cursor": 0,
		"cut_card_at": deck_count * CardShoeScript.CARDS_PER_DECK - cut_remaining,
		"cut_card_remaining": cut_remaining,
		"shoe_remaining": shoe.size(),
		"shoe_composition": CardShoeScript.remaining_composition(shoe),
		"shoe_label": CardShoeScript.shoe_label(deck_count),
		"count_efficiency": CardShoeScript.count_efficiency_label(deck_count),
		"hands_played": 0,
		"running_count": 0,
		"recorded_running_count": 0,
		"count_accuracy_streak": 0,
		"rules": rules,
		"side_bets": side_bets,
		"dealer_profile": dealer_profile,
		"patrons": patrons,
		"distractions": distractions,
		"chip_denominations": [1, 5, 10, 25],
		"table_layout": "immersive_blackjack",
		"dealer_catch_base": catch_base,
		"catch_heat": catch_base + 8,
		"strategy_deviation_strikes": 0,
		"strategy_watch_pressure": 0,
		"last_result": {},
		"table_round_timer_started_msec": 0,
	}


func surface_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var table: Dictionary = _table_state(run_state, environment)
	var session: Dictionary = _normalized_session(run_state, environment, ui_state, table)
	var now_msec := int(ui_state.get("surface_time_msec", Time.get_ticks_msec()))
	var hands: Array = _hand_array(session.get("player_hands", []))
	var active_index: int = clampi(int(session.get("active_hand_index", 0)), 0, maxi(0, hands.size() - 1))
	var active_hand: Dictionary = hands[active_index] if active_index >= 0 and active_index < hands.size() else {}
	var active_cards: Array = _card_array(active_hand.get("cards", []))
	var dealer_cards: Array = _card_array(session.get("dealer_cards", []))
	var last_result: Dictionary = _local_copy_dict(table.get("last_result", {}))
	var dealt := _has_dealt_hand(session)
	var barred := bool(table.get("barred", false))
	if not dealt and not last_result.is_empty():
		var result_patron_hands: Array = _hand_array(last_result.get("patron_hands", []))
		if not result_patron_hands.is_empty():
			session["patron_hands"] = result_patron_hands
	var patron_hands: Array = _hand_array(session.get("patron_hands", []))
	var showdown_dealer_cards: Array = _card_array(last_result.get("dealer_cards", []))
	var display_dealer_cards: Array = dealer_cards
	if display_dealer_cards.is_empty() and not showdown_dealer_cards.is_empty():
		display_dealer_cards = showdown_dealer_cards
	var dealer_view: Array = _dealer_view(display_dealer_cards, bool(session.get("dealer_hole_visible", false)) or dealer_cards.is_empty())
	var total_info: Dictionary = _hand_total_info(active_cards)
	var selected_stake: int = _effective_table_stake(_session_stake(int(ui_state.get("selected_stake", session.get("selected_stake", 1))), session), session, run_state, environment)
	var available_side_bets: Array = _available_side_bets_for_session(table, session)
	for i in range(available_side_bets.size()):
		var available_bet: Dictionary = available_side_bets[i]
		available_bet = _item_adjusted_side_bet_for_surface(available_bet, run_state)
		available_bet["surface_enabled"] = _side_bet_can_toggle_now(available_bet, session) and not barred
		available_side_bets[i] = available_bet
	var active_side_bets: Array = _valid_side_bet_ids_for_session(_string_array(session.get("blackjack_side_bets", [])), table, session)
	session["blackjack_side_bets"] = active_side_bets
	var side_bet_stakes: Dictionary = {}
	for side_bet in available_side_bets:
		var side_bet_id := str(side_bet.get("id", ""))
		side_bet_stakes[side_bet_id] = _side_bet_stake(selected_stake, side_bet, run_state)
	var patrons: Array = _patrons_for_surface(table, session)
	var snitch_pressure := _patron_snitch_risk_from_patrons(patrons)
	var dealer_focus: Dictionary = _dealer_focus_state(table, session, run_state, snitch_pressure)
	var distraction_active: bool = bool(dealer_focus.get("peek_window_open", bool(dealer_focus.get("lookaway_active", false))))
	var ambient_event: Dictionary = _ambient_table_event(table, session)
	var deal_active_id := str(session.get("deal_animation_id", table.get("last_deal_animation_id", "")))
	var deal_started_msec := int(session.get("deal_started_msec", table.get("last_deal_started_msec", 0)))
	var deal_events: Array = _deal_animation_event_array(session.get("deal_animation_events", table.get("last_deal_animation_events", [])))
	var patron_action_source: Variant = session.get("patron_action_events", []) if dealt else table.get("last_patron_action_events", [])
	var patron_action_events: Array = _patron_action_event_array(patron_action_source)
	if not dealt and not last_result.is_empty() and patron_action_events.is_empty():
		patron_action_events = _patron_action_event_array(last_result.get("patron_action_events", []))
	var deal_duration_msec := maxi(_deal_animation_duration_msec(deal_events), _patron_action_animation_duration_msec(patron_action_events))
	if deal_events.is_empty() and patron_action_events.is_empty():
		deal_active_id = ""
		deal_started_msec = 0
	var attention_active_id := str(session.get("dealer_lookaway_id", ""))
	var attention_started_msec := int(session.get("dealer_lookaway_started_msec", 0))
	var attention_duration_msec := int(session.get("dealer_lookaway_duration_msec", 0))
	var count_challenge: Dictionary = _local_copy_dict(session.get("count_challenge", {}))
	var count_active := not count_challenge.is_empty() and not bool(session.get("count_answered", false))
	var round_complete := dealt and _all_hands_complete(session)
	var dealer_blackjack_pending := dealt and _dealer_has_blackjack(dealer_cards)
	var live_table_motion := not barred
	var dealer_focus_runtime: Dictionary = {
		"dealer_lookaway_started_msec": attention_started_msec,
		"dealer_lookaway_duration_msec": attention_duration_msec,
		"dealer_distraction_noise": int(session.get("dealer_distraction_noise", 0)),
		"dealer_distraction_cover": int(session.get("dealer_distraction_cover", 0)),
		"count_active": count_active,
		"count_attention_risk": int(count_challenge.get("dealer_attention_risk", 0)),
		"strategy_attention_boost": int(session.get("strategy_attention_boost", 0)),
	}
	var table_notice := _table_notice_for_session(session, table)
	var payout_active_id := str(last_result.get("payout_animation_id", ""))
	var payout_started_msec := int(last_result.get("resolved_at_msec", last_result.get("timestamp_msec", 0)))
	var deal_animation_active := not deal_active_id.is_empty() and deal_started_msec > 0 and now_msec - deal_started_msec >= 0 and now_msec - deal_started_msec < deal_duration_msec
	var payout_animation_active := not payout_active_id.is_empty() and payout_started_msec > 0 and now_msec - payout_started_msec >= 0 and now_msec - payout_started_msec < PAYOUT_ANIMATION_DURATION_MSEC
	var timer_active := not dealt and not barred and not deal_animation_active and not payout_animation_active
	var round_timer := GameModule.table_round_timer_status(table, now_msec, "Next hand") if timer_active else {}
	if timer_active:
		_update_environment_table(environment, table)
		if table_notice == "Slide chips, choose side bets, then press DEAL.":
			var timer_seconds := int(round_timer.get("remaining_seconds", 0))
			if timer_seconds > 0:
				table_notice = "Place chips or watch; next hand in %ds." % timer_seconds
			else:
				table_notice = "Place chips or watch the next hand."
	var chip_denominations: Array = _chip_denominations(table)
	if table_notice.is_empty():
		table_notice = _table_notice_for_session(session, table)
	if barred:
		table_notice = str(table.get("barred_reason", "The dealer has barred you from this blackjack table."))
	if not dealt and not last_result.is_empty():
		table_notice = str(last_result.get("summary", ""))
	elif table_notice.is_empty() and not last_result.is_empty():
		table_notice = str(last_result.get("summary", ""))
	var persisted_recorded_count := int(table.get("recorded_running_count", 0))
	var hand_count_delta := int(session.get("count_delta", 0))
	var live_recorded_count := _recorded_count_for_surface(table, session)
	var live_true_count := _true_count_for_surface(table, session)
	return GameModule.surface_spec({
		"surface_renderer": "blackjack",
		"surface_life": "immersive_table",
		"surface_cast": "dealer_table",
		"surface_controls_native": true,
		"surface_stake_controls_required": true,
		"surface_embeds_outcomes": true,
		"surface_animates_idle": live_table_motion,
		"surface_realtime_state_refresh": true,
		"surface_ui_protected_regions": _blackjack_ui_protected_regions(count_challenge),
		"surface_hover_ui_protected_regions": [
			_blackjack_ui_rect(236, 202, 428, 108, "blackjack_side_bet"),
		],
		"surface_state_labels": _surface_state_labels(table, session),
		"surface_animation_channels": [
			GameModule.surface_animation_channel(
				DEAL_ANIMATION_CHANNEL,
				deal_active_id,
				deal_duration_msec,
				deal_started_msec,
				{"metadata": {"event_count": deal_events.size()}}
			),
			GameModule.surface_animation_channel(
				ATTENTION_ANIMATION_CHANNEL,
				attention_active_id,
				attention_duration_msec,
				attention_started_msec
			),
			GameModule.surface_animation_channel(
				COUNT_ANIMATION_CHANNEL,
				str(count_challenge.get("challenge_id", "")),
				0 if count_active else 2600,
				int(count_challenge.get("started_msec", 0))
			),
			GameModule.surface_animation_channel(
				PAYOUT_ANIMATION_CHANNEL,
				payout_active_id,
				PAYOUT_ANIMATION_DURATION_MSEC if not payout_active_id.is_empty() else 0,
				payout_started_msec
			),
		],
		"phase": "barred" if barred else "settling" if round_complete else "decision" if dealt else "betting",
		"table_barred": barred,
		"barred_reason": str(table.get("barred_reason", "")),
		"table_name": str(table.get("table_name", "Blackjack")),
		"dealer_name": str(table.get("dealer_name", "Dealer")),
		"dealer_profile": _local_copy_dict(table.get("dealer_profile", {})),
		"dealer_focus": dealer_focus,
		"dealer_focus_runtime": dealer_focus_runtime,
		"ambient_table_event": ambient_event,
		"hands_played": int(table.get("hands_played", 0)),
		"patrons": patrons,
		"patron_wager_action": "blackjack_patron_bet",
		"patron_hands": patron_hands,
		"patron_action_events": patron_action_events,
		"deal_animation_events": deal_events,
		"deal_animation_duration_msec": deal_duration_msec,
		"last_result": last_result,
		"showdown_active": not last_result.is_empty() and not dealt,
		"showdown_player_hands": _hand_array(last_result.get("player_hands", [])),
		"showdown_dealer_cards": showdown_dealer_cards,
		"result_message": str(last_result.get("summary", "")),
		"table_notice": table_notice,
		"table_round_timer": round_timer,
		"active_hand_status": _active_hand_status_text(session),
		"round_complete": round_complete,
		"settle_available": round_complete or dealer_blackjack_pending,
		"dealer_blackjack_pending": dealer_blackjack_pending,
		"distractions": _dictionary_array(table.get("distractions", [])),
		"chip_denominations": chip_denominations,
		"selected_stake": selected_stake,
		"chip_stack": _chip_stack_for_stake(selected_stake, chip_denominations),
		"rules": _table_rules(table),
		"player_hands": hands,
		"dealer": dealer_view,
		"dealer_cards": display_dealer_cards,
		"dealer_hole_visible": bool(session.get("dealer_hole_visible", false)),
		"active_hand_index": active_index,
		"blackjack_total": int(total_info.get("total", 0)),
		"blackjack_soft": bool(total_info.get("soft", false)),
		"basic_strategy_advice": _basic_strategy_advice(session, table, run_state),
		"count_hint": _count_hint(run_state, table, session),
		"counting_enabled": bool(table.get("counting_enabled", false)),
		"table_modifier": _table_summary(table),
		"side_bets_available": available_side_bets,
		"side_bets_active": active_side_bets,
		"side_bet_stakes": side_bet_stakes,
		"main_wager_cost": _main_wager_cost(selected_stake, session),
		"total_wager_cost": _wager_cost_from_session(selected_stake, session, table, run_state),
		"can_deal": not dealt and not barred,
		"can_hit": _can_hit(session) and not barred,
		"can_stand": _can_stand(session) and not barred,
		"can_double": _can_double(session, table, selected_stake, run_state) and not barred,
		"can_split": _can_split(session, table, selected_stake, run_state) and not barred,
		"can_surrender": _can_surrender(session, table) and not barred,
		"can_change_side_bets": _can_change_side_bets(session) and not barred,
		"peek_window_open": distraction_active,
		"peek_available": dealt and not bool(session.get("dealer_hole_visible", false)) and not barred,
		"peek_dangerous": dealt and not distraction_active and not bool(session.get("dealer_hole_visible", false)) and not barred,
		"snitch_pressure": snitch_pressure,
		"strategy_watch_pressure": int(table.get("strategy_watch_pressure", 0)),
		"strategy_deviation_score": int(session.get("strategy_deviation_score", 0)),
		"strategy_confronted": bool(session.get("strategy_confronted", false)),
		"count_challenge": count_challenge,
		"count_answered": bool(session.get("count_answered", false)),
		"count_correct": bool(session.get("count_correct", false)),
		"count_delta": int(session.get("count_delta", 0)),
		"count_hand_delta": hand_count_delta,
		"count_declared_delta": int(session.get("count_declared_delta", 0)),
		"count_perfect": bool(session.get("count_perfect", false)),
		"persisted_recorded_running_count": persisted_recorded_count,
		"recorded_running_count": live_recorded_count,
		"persisted_running_count": int(table.get("running_count", 0)),
		"running_count": live_true_count,
		"shoe_remaining": _shoe_remaining(table),
		"shoe_label": str(table.get("shoe_label", CardShoeScript.shoe_label(int(table.get("deck_count", 6))))),
		"deck_count": int(table.get("deck_count", 6)),
		"cut_card_remaining": int(table.get("cut_card_remaining", CardShoeScript.cut_card_remaining(int(table.get("deck_count", 6))))),
		"count_efficiency": str(table.get("count_efficiency", CardShoeScript.count_efficiency_label(int(table.get("deck_count", 6))))),
		"shoe_composition": _local_copy_dict(table.get("shoe_composition", CardShoeScript.remaining_composition(table.get("shoe", [])))),
		"native_selected_surface_actions": _selected_surface_actions(ui_state, session),
		"surface_action_bindings": {
			"legal": {"action": "blackjack_deal", "index": 0},
			"cheat": {"action": "blackjack_count_toggle", "index": 0},
			"surface_stake_down": {"action": "blackjack_clear_bet", "index": 0},
			"surface_stake_up": {"action": "blackjack_chip", "index": 0},
			"surface_stake_max": {"action": "blackjack_max_bet", "index": 0},
		},
		"surface_audio": GameModule.surface_audio_spec({
			"profile_id": "blackjack_table",
			"action_cues": {
				"blackjack_chip": "blackjack_chip",
				"blackjack_patron_bet": "blackjack_chip",
				"blackjack_clear_bet": "blackjack_chip",
				"blackjack_max_bet": "blackjack_chip",
				"surface_stake_up": "blackjack_chip",
				"surface_stake_down": "blackjack_chip",
				"surface_stake_max": "blackjack_chip",
				"blackjack_deal": "blackjack_deal",
				"blackjack_hit": "blackjack_hit",
				"blackjack_stand": "blackjack_stand",
				"blackjack_double": "blackjack_double",
				"blackjack_split": "blackjack_split",
				"blackjack_surrender": "blackjack_surrender",
				"blackjack_side_bet": "blackjack_side_bet",
				"blackjack_distraction": "blackjack_distraction",
				"blackjack_patron_cover": "blackjack_distraction",
				"blackjack_peek": "blackjack_peek",
				"blackjack_count": "blackjack_count",
				"blackjack_count_toggle": "blackjack_count_toggle",
				"blackjack_count_icon": "blackjack_count_icon",
			},
			"state_sync": {
				"method": "blackjack_table_state",
				"deal_animation_channel": DEAL_ANIMATION_CHANNEL,
				"payout_animation_channel": PAYOUT_ANIMATION_CHANNEL,
			},
		}),
	})


func _blackjack_ui_protected_regions(count_challenge: Dictionary) -> Array:
	var regions := [
		_blackjack_ui_rect(24, 14, 286, 58),
		_blackjack_ui_rect(332, 18, 236, 48),
		_blackjack_ui_rect(646, 12, 232, 74),
		_blackjack_ui_rect(18, BJ_CONSOLE_Y + 8.0, 242, BJ_CONSOLE_H - 16.0),
		_blackjack_ui_rect(272, BJ_CONSOLE_Y + 8.0, 302, BJ_CONSOLE_H - 16.0),
		_blackjack_ui_rect(586, BJ_CONSOLE_Y + 8.0, 292, BJ_CONSOLE_H - 16.0),
		_blackjack_ui_rect(692, 294, 168, 34),
	]
	if not count_challenge.is_empty():
		regions.append(_blackjack_ui_rect(620, 74, 150, 30))
	return regions


func _blackjack_ui_rect(x: float, y: float, width: float, height: float, hover_action: String = "", hover_index: int = -1) -> Dictionary:
	var rect := {
		"x": x,
		"y": y,
		"w": width,
		"h": height,
	}
	if not hover_action.is_empty():
		rect["action"] = hover_action
		if hover_index >= 0:
			rect["index"] = hover_index
	return rect


func draw_surface(surface, surface_state: Dictionary, _render_context: Dictionary = {}) -> bool:
	if str(surface_state.get("surface_renderer", "")) != "blackjack":
		return false
	var draw_state := surface_state
	if surface.surface_animation_active(DEAL_ANIMATION_CHANNEL):
		draw_state = surface_state.duplicate(false)
		draw_state[DRAW_DEAL_EVENTS_CACHE_KEY] = _deal_animation_event_array(surface_state.get("deal_animation_events", []))
	surface.surface_begin_design_space(surface.surface_board_size())
	_draw_blackjack_room(surface, draw_state)
	_draw_blackjack_table(surface, draw_state)
	_draw_table_patrons(surface, draw_state)
	_draw_dealer_station(surface, draw_state)
	_draw_player_station(surface, draw_state)
	_draw_blackjack_table_notice(surface, draw_state)
	_draw_blackjack_round_timer(surface, draw_state)
	_draw_blackjack_ambient_event(surface, draw_state)
	_draw_chip_rack(surface, draw_state)
	_draw_table_actions(surface, draw_state)
	_draw_basic_strategy_advice(surface, draw_state)
	_draw_blackjack_result_board(surface, draw_state)
	_draw_side_bet_rule_overlay(surface, draw_state)
	_draw_deal_animation(surface, draw_state)
	_draw_chip_payout_animation(surface, draw_state)
	_draw_count_challenge(surface, draw_state)
	return true


func surface_needs_auto_tick(ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> bool:
	# Per-frame check: operate on the live stored table (zero-copy) and only
	# build the full normalized session when a count challenge is actually
	# pending. Stored table state is already normalized by every mutation path;
	# the timer auto-start field persists directly on the stored dictionary.
	var table: Dictionary = _peek_table_state(environment)
	if table.is_empty():
		return false
	var raw_challenge: Variant = ui_state.get("count_challenge", {})
	if typeof(raw_challenge) == TYPE_DICTIONARY and not (raw_challenge as Dictionary).is_empty() and not bool(ui_state.get("count_answered", false)):
		var session: Dictionary = _normalized_session(run_state, environment, ui_state, table)
		_sync_count_challenge_icons(session, run_state)
		var challenge: Dictionary = _local_copy_dict(session.get("count_challenge", {}))
		if _count_has_new_misses(challenge, Time.get_ticks_msec()):
			return true
	if _has_dealt_hand(ui_state) or bool(table.get("barred", false)):
		return false
	var now_msec := int(ui_state.get("surface_time_msec", Time.get_ticks_msec()))
	if _blackjack_table_motion_active(table, now_msec):
		return false
	var timer := GameModule.table_round_timer_status(table, now_msec, "Next hand")
	return bool(timer.get("due", false))


func _peek_table_state(environment: Dictionary) -> Dictionary:
	# Zero-copy view of the stored table for read-mostly per-frame checks.
	# Callers must not restructure it; timer auto-start writes are intended.
	var states: Variant = environment.get("game_states", {})
	if typeof(states) != TYPE_DICTIONARY:
		return {}
	var table: Variant = (states as Dictionary).get(get_id(), {})
	if typeof(table) != TYPE_DICTIONARY or (table as Dictionary).is_empty():
		return {}
	return table as Dictionary


func surface_auto_action_command(ui_state: Dictionary, run_state: RunState, environment: Dictionary, _surface_status: Dictionary = {}) -> Dictionary:
	var table: Dictionary = _table_state(run_state, environment)
	var next_state: Dictionary = _normalized_session(run_state, environment, ui_state, table)
	var notice: String = _update_live_count_state(next_state, table, run_state, true)
	if not notice.is_empty():
		return _message_command(next_state, notice)
	if _has_dealt_hand(next_state) or bool(table.get("barred", false)):
		return {"handled": false}
	var now_msec := int(ui_state.get("surface_time_msec", Time.get_ticks_msec()))
	if _blackjack_table_motion_active(table, now_msec):
		return {"handled": false}
	var timer := GameModule.table_round_timer_status(table, now_msec, "Next hand")
	if not bool(timer.get("due", false)):
		_update_environment_table(environment, table)
		return {"handled": false}
	next_state["blackjack_sit_out"] = true
	next_state["blackjack_side_bets"] = []
	next_state["selected_stake"] = 1
	GameModule.reset_table_round_timer(table)
	_update_environment_table(environment, table)
	return GameModule.surface_command({
		"handled": true,
		"ui_state": _compact_session_for_ui(next_state),
		"action_id": "play_basic",
		"action_kind": "legal",
		"direct_resolve": true,
		"skip_stake_validation": true,
		"preserve_surface_ui_state": false,
		"message": "The dealer deals the next hand; you watch without wagering.",
	})


func _blackjack_table_motion_active(table: Dictionary, now_msec: int) -> bool:
	var last_result: Dictionary = _local_copy_dict(table.get("last_result", {}))
	var payout_started := int(last_result.get("resolved_at_msec", last_result.get("timestamp_msec", 0)))
	if not last_result.is_empty() and payout_started > 0:
		var payout_elapsed := now_msec - payout_started
		if payout_elapsed >= 0 and payout_elapsed < PAYOUT_ANIMATION_DURATION_MSEC:
			return true
	var deal_started := int(table.get("last_deal_started_msec", 0))
	var deal_events: Array = _deal_animation_event_array(table.get("last_deal_animation_events", []))
	var patron_action_events: Array = _patron_action_event_array(table.get("last_patron_action_events", []))
	var deal_duration := maxi(_deal_animation_duration_msec(deal_events), _patron_action_animation_duration_msec(patron_action_events))
	if deal_started > 0:
		var deal_elapsed := now_msec - deal_started
		if deal_elapsed >= 0 and deal_elapsed < deal_duration:
			return true
	return false


func surface_action_command(surface_action: String, index: int, confirm_requested: bool, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var table: Dictionary = _table_state(run_state, environment)
	var next_state: Dictionary = _normalized_session(run_state, environment, ui_state, table)
	var selected_stake: int = _effective_table_stake(_session_stake(int(ui_state.get("selected_stake", next_state.get("selected_stake", 1))), next_state), next_state, run_state, environment)
	_update_live_count_state(next_state, table, run_state, true)
	if bool(table.get("barred", false)):
		return _message_command(next_state, str(table.get("barred_reason", "The dealer refuses to let you play this blackjack table.")))
	match surface_action:
		"blackjack_chip":
			return _chip_bet_command(index, next_state, table, run_state, environment, selected_stake)
		"blackjack_patron_bet":
			return _patron_bet_command(index, next_state, table, run_state, environment)
		"blackjack_clear_bet":
			if _has_dealt_hand(next_state):
				return _message_command(next_state, "Main bets are locked until the hand settles.")
			var min_bet := _surface_stake_floor(run_state, environment)
			next_state["selected_stake"] = min_bet
			next_state.erase("table_social_alignment")
			return GameModule.surface_command({
				"handled": true,
				"ui_state": next_state,
				"set_stake": min_bet,
				"selected_index": index,
				"message": "Bet cleared to the table minimum.",
			})
		"blackjack_max_bet":
			if _has_dealt_hand(next_state):
				return _message_command(next_state, "Main bets are locked until the hand settles.")
			var max_bet := _max_table_stake_for_blackjack(next_state, table, run_state, environment)
			next_state["selected_stake"] = max_bet
			next_state.erase("table_social_alignment")
			return GameModule.surface_command({
				"handled": true,
				"ui_state": next_state,
				"set_stake": max_bet,
				"selected_index": index,
				"message": "Chips pushed to the edge of your bankroll.",
			})
		"blackjack_deal":
			if _has_dealt_hand(next_state):
				if not _all_hands_complete(next_state) and not _dealer_has_blackjack(_card_array(next_state.get("dealer_cards", []))):
					if str(next_state.get("selected_action_id", "")) == "play_basic" and str(next_state.get("selected_action_kind", "")) == "legal":
						_stand_all_hands(next_state)
						return _settle_completed_round_command(next_state, index, "You wave off the hand. Dealer reveals and settles.", table, run_state)
					return _action_command("play_basic", "legal", false, next_state, index, "Basic play selected. Click again to stand and settle, or use the live hand buttons.", true)
				return _settle_completed_round_command(next_state, index, _terminal_round_message(next_state), table, run_state)
			var dealt_state := next_state.duplicate(true)
			_start_initial_hand(dealt_state, table, selected_stake, run_state)
			var projected_cost: int = _wager_cost_from_session(selected_stake, dealt_state, table, run_state)
			if projected_cost > maxi(0, run_state.bankroll if run_state != null else projected_cost):
				return _message_command(next_state, "You do not have enough bankroll for those chips and side bets.")
			if confirm_requested:
				_stand_all_hands(dealt_state)
				return _settle_completed_round_command(dealt_state, index, "Quick hand dealt and settled from the shoe.", table, run_state)
			return _action_command("play_basic", "legal", false, dealt_state, index, _opening_deal_notice(dealt_state, table), true)
		"blackjack_distraction":
			return _start_distraction_command(index, next_state, table)
		"blackjack_patron_cover":
			return _cover_patron_command(index, next_state, table)
		"blackjack_count_toggle":
			return _toggle_counting_command(index, next_state, table, environment, run_state)
		"blackjack_hit":
			if _dealer_has_blackjack(_card_array(next_state.get("dealer_cards", []))):
				return _settle_completed_round_command(next_state, index, "Dealer reveals blackjack before another card can leave the shoe.", table, run_state)
			if not _can_hit(next_state):
				return _message_command(next_state, "That hand cannot take another card.")
			var hit_hand_index := int(next_state.get("active_hand_index", 0))
			var hit_strategy_notice := _record_strategy_deviation(next_state, table, run_state, "hit")
			_deal_to_active_hand(next_state, table)
			_autoadvance_finished_hands(next_state, table)
			_sync_count_challenge_icons(next_state, run_state)
			if _all_hands_complete(next_state):
				var terminal_hit_message := _terminal_round_message(next_state)
				if not hit_strategy_notice.is_empty():
					terminal_hit_message = "%s %s" % [terminal_hit_message, hit_strategy_notice]
				return _settle_completed_round_command(next_state, index, terminal_hit_message, table, run_state)
			return _message_command(next_state, _append_strategy_notice(_post_hand_action_message(next_state, hit_hand_index, "Hit"), hit_strategy_notice))
		"blackjack_stand":
			if not _has_dealt_hand(next_state):
				return _message_command(next_state, "Place your chips and press Deal first.")
			if _dealer_has_blackjack(_card_array(next_state.get("dealer_cards", []))):
				return _settle_completed_round_command(next_state, index, "Dealer reveals blackjack before play continues.", table, run_state)
			if _all_hands_complete(next_state):
				return _settle_completed_round_command(next_state, index, _terminal_round_message(next_state), table, run_state)
			var stood_hand_index := int(next_state.get("active_hand_index", 0))
			var stand_strategy_notice := _record_strategy_deviation(next_state, table, run_state, "stand")
			if _can_stand(next_state):
				_stand_active_hand(next_state)
			if _all_hands_complete(next_state):
				var terminal_stand_message := _terminal_round_message(next_state)
				if not stand_strategy_notice.is_empty():
					terminal_stand_message = "%s %s" % [terminal_stand_message, stand_strategy_notice]
				return _settle_completed_round_command(next_state, index, terminal_stand_message, table, run_state)
			return _message_command(next_state, _append_strategy_notice(_post_hand_action_message(next_state, stood_hand_index, "Stand"), stand_strategy_notice))
		"blackjack_double":
			if _dealer_has_blackjack(_card_array(next_state.get("dealer_cards", []))):
				return _settle_completed_round_command(next_state, index, "Dealer reveals blackjack before the double can play.", table, run_state)
			if not _can_double(next_state, table, selected_stake, run_state):
				return _message_command(next_state, "Double is not available on this hand.")
			var doubled_hand_index := int(next_state.get("active_hand_index", 0))
			var double_strategy_notice := _record_strategy_deviation(next_state, table, run_state, "double")
			_double_active_hand(next_state, table)
			_autoadvance_finished_hands(next_state, table)
			_sync_count_challenge_icons(next_state, run_state)
			if _all_hands_complete(next_state):
				var terminal_double_message := _terminal_round_message(next_state)
				if not double_strategy_notice.is_empty():
					terminal_double_message = "%s %s" % [terminal_double_message, double_strategy_notice]
				return _settle_completed_round_command(next_state, index, terminal_double_message, table, run_state)
			return _message_command(next_state, _append_strategy_notice(_post_hand_action_message(next_state, doubled_hand_index, "Double"), double_strategy_notice))
		"blackjack_split":
			if _dealer_has_blackjack(_card_array(next_state.get("dealer_cards", []))):
				return _settle_completed_round_command(next_state, index, "Dealer reveals blackjack before the split can play.", table, run_state)
			if not _can_split(next_state, table, selected_stake, run_state):
				return _message_command(next_state, "Split is not available on this hand.")
			var split_strategy_notice := _record_strategy_deviation(next_state, table, run_state, "split")
			_split_active_hand(next_state, table)
			_sync_count_challenge_icons(next_state, run_state)
			if _all_hands_complete(next_state):
				var terminal_split_message := _terminal_round_message(next_state)
				if not split_strategy_notice.is_empty():
					terminal_split_message = "%s %s" % [terminal_split_message, split_strategy_notice]
				return _settle_completed_round_command(next_state, index, terminal_split_message, table, run_state)
			return _message_command(next_state, _append_strategy_notice("Pair split. Each hand gets its own decision.", split_strategy_notice))
		"blackjack_surrender":
			if _dealer_has_blackjack(_card_array(next_state.get("dealer_cards", []))):
				return _settle_completed_round_command(next_state, index, "Dealer has blackjack; surrender is not available.", table, run_state)
			if not _can_surrender(next_state, table):
				return _message_command(next_state, "Late surrender is not available on this hand.")
			var surrendered_hand_index := int(next_state.get("active_hand_index", 0))
			var surrender_strategy_notice := _record_strategy_deviation(next_state, table, run_state, "surrender")
			_surrender_active_hand(next_state)
			return _settle_completed_round_command(next_state, index, _append_strategy_notice(_post_hand_action_message(next_state, surrendered_hand_index, "Surrender"), surrender_strategy_notice), table, run_state)
		"blackjack_side_bet":
			return _toggle_side_bet_command(index, next_state, table, run_state, ui_state)
		"blackjack_peek":
			if not _has_dealt_hand(next_state):
				return _message_command(next_state, "Place your chips and deal before trying to read the hole card.")
			if bool(next_state.get("dealer_hole_visible", false)):
				return _message_command(next_state, "Hole card already exposed.")
			var peek_window_open := _dealer_peek_window_open(table, next_state, run_state)
			var cheats: Dictionary = _local_copy_dict(next_state.get("cheats_used", {}))
			next_state["peek_had_window"] = peek_window_open
			next_state["peek_snitch_risk"] = _patron_snitch_risk(table, next_state)
			cheats["peek_hole_card"] = true
			next_state["cheats_used"] = cheats
			if not peek_window_open:
				next_state["peek_caught_watching"] = true
				next_state["dealer_hole_visible"] = false
				return _action_command("peek_hole_card", "cheat", true, next_state, index, "The dealer catches your eyes on the hole card.", true, false, true)
			next_state["dealer_hole_visible"] = true
			_sync_count_challenge_icons(next_state, run_state)
			return _action_command("peek_hole_card", "cheat", confirm_requested, next_state, index, "You catch a glimpse of the down card. The dealer may notice.", false)
		"blackjack_count":
			return _toggle_counting_command(index, next_state, table, environment, run_state)
		"blackjack_count_icon":
			return _hit_count_icon(index, next_state, table, run_state)
	return {"handled": false}


func resolve(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return resolve_with_context(action_id, stake, run_state, environment, rng, {})


func resolve_with_context(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary = {}) -> Dictionary:
	if action_id == "peek_hole_card" or action_id == "count_cards":
		return _resolve_cheat_only(action_id, run_state, environment, rng, ui_state)
	if action_id != "play_basic":
		return _empty_blackjack_result(action_id, stake, environment, "That blackjack action is not available.")
	var table: Dictionary = _table_state(run_state, environment)
	if bool(table.get("barred", false)):
		return _empty_blackjack_result(action_id, stake, environment, str(table.get("barred_reason", "The dealer refuses to let you play this blackjack table.")))
	var session: Dictionary = _normalized_session(run_state, environment, ui_state, table)
	var sit_out := bool(session.get("blackjack_sit_out", false))
	if sit_out:
		session["blackjack_side_bets"] = []
	if not _has_dealt_hand(session):
		_start_initial_hand(session, table, maxi(1, stake), run_state)
	if not _all_hands_complete(session):
		_stand_all_hands(session)
	var table_stake := 0 if sit_out else _session_stake(stake, session)
	var total_wager: int = 0 if sit_out else _wager_cost_from_session(table_stake, session, table, run_state)
	if total_wager > maxi(0, run_state.bankroll):
		return _empty_blackjack_result(action_id, stake, environment, "You do not have enough bankroll for that table action.")

	session["dealer_hole_visible"] = true
	var dealer_cards: Array = _dealer_final_cards(session, table)
	var patron_hands: Array = _hand_array(session.get("patron_hands", []))
	var hands: Array = _hand_array(session.get("player_hands", []))
	var hand_results: Array = []
	var main_delta := 0
	for hand_value in hands:
		var hand: Dictionary = hand_value
		var settled: Dictionary = _settle_hand(hand, dealer_cards, maxi(1, table_stake))
		if sit_out:
			settled["bankroll_delta"] = 0
			settled["wager"] = 0
			settled["sat_out"] = true
		hand_results.append(settled)
		main_delta += int(settled.get("bankroll_delta", 0))

	var side_results: Array = [] if sit_out else _settle_side_bets(session, table, dealer_cards, table_stake, run_state)
	var side_delta := 0
	for side_result_value in side_results:
		if typeof(side_result_value) == TYPE_DICTIONARY:
			side_delta += int((side_result_value as Dictionary).get("bankroll_delta", 0))

	if not bool(session.get("count_answered", false)) and not _local_copy_dict(session.get("count_challenge", {})).is_empty():
		_sync_count_challenge_icons(session, run_state)
		_finalize_count_challenge(session, run_state)
	var cheat: Dictionary = {} if sit_out else _cheat_detection_for_hand(session, table, run_state, environment, rng, table_stake)
	var cufflinks_broke := _coolers_cufflinks_absorbed_failed_peek(action_id, cheat, run_state)
	var raw_suspicion_delta: int = int(cheat.get("suspicion_delta", 0))
	if cufflinks_broke:
		raw_suspicion_delta = 0
	var suspicion_delta: int = run_state.alcohol_adjusted_suspicion_delta(raw_suspicion_delta) if raw_suspicion_delta > 0 else raw_suspicion_delta
	var security_pressure: Dictionary = run_state.security_action_pressure("cheat", stake, run_state.suspicion_level() + suspicion_delta) if suspicion_delta > 0 else {}
	var security_bankroll_delta: int = int(security_pressure.get("bankroll_delta", 0))
	var security_message := str(security_pressure.get("message", ""))

	var item_adjustment: Dictionary = {} if sit_out else _blackjack_item_adjustment(main_delta, side_delta, session, run_state, table_stake)
	main_delta += int(item_adjustment.get("main_delta", 0))
	side_delta += int(item_adjustment.get("side_delta", 0))
	var bankroll_delta: int = main_delta + side_delta + security_bankroll_delta

	var used_cards: Array = _cards_used_for_counting(hands, dealer_cards, patron_hands)
	var patron_action_events: Array = _patron_action_event_array(session.get("patron_action_events", []))
	var actual_count_delta: int = _count_cards_delta(used_cards)
	var count_record_delta: int = int(session.get("count_delta", 0)) if bool(session.get("count_answered", false)) else 0
	var message := _blackjack_result_message(hand_results, side_results, main_delta, side_delta, cheat, item_adjustment, security_message)
	if cufflinks_broke:
		message = "%s Cooler's Cufflinks absorb the peek heat and break." % message
	if sit_out:
		message = "You watch the blackjack hand without wagering. %s" % message
	var result_action_kind := "legal"
	if bool(cheat.get("used_peek", false)) or bool(cheat.get("used_count", false)):
		result_action_kind = "cheat"
	elif suspicion_delta > 0 or bool(cheat.get("used_strategy_deviation", false)):
		result_action_kind = "risky"
	_update_table_after_hand(table, session, dealer_cards, actual_count_delta, count_record_delta, rng)
	if not sit_out:
		_apply_patron_rapport_after_blackjack(table, session, table_stake, bankroll_delta)
	table["last_result"] = _blackjack_last_result_payload(message, hand_results, side_results, main_delta, side_delta, bankroll_delta, suspicion_delta, dealer_cards, hands, patron_hands, patron_action_events, cheat)
	_update_environment_table(environment, table)

	var story_entry := {
		"type": "game_action",
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": result_action_kind,
		"stake": table_stake,
		"total_wager": total_wager,
		"sat_out": sit_out,
		"bankroll_delta": bankroll_delta,
		"main_delta": main_delta,
		"side_delta": side_delta,
		"suspicion_delta": suspicion_delta,
		"dealer_caught_cheat": bool(cheat.get("caught", false)),
		"coolers_cufflinks_broke": cufflinks_broke,
		"dealer_strategy_confronted": bool(cheat.get("strategy_confronted", false)),
		"strategy_deviation_count": (_dictionary_array(cheat.get("strategy_deviation_events", []))).size(),
		"dealer_total": int(_hand_total_info(dealer_cards).get("total", 0)),
		"hand_results": hand_results,
		"side_bet_results": side_results,
		"environment_id": environment.get("id", ""),
		"pit_boss_watched": bool(cheat.get("pit_boss_watched", false)),
		"pit_boss_heat_bonus": int(cheat.get("pit_boss_heat_bonus", 0)),
		"security_message": security_message,
	}
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["suspicion_delta"] = suspicion_delta
	if cufflinks_broke:
		deltas["inventory_remove"] = [COOLERS_CUFFLINKS_ITEM_ID]
		deltas["inventory_add"] = [BROKEN_CUFFLINKS_ITEM_ID]
	deltas["story_log"] = [story_entry]
	deltas["messages"] = [message]
	deltas["ended"] = bool(security_pressure.get("ended", false))
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": result_action_kind,
		"stake": table_stake,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"deltas": deltas,
		"won": bankroll_delta > 0,
		"environment_id": environment.get("id", ""),
		"environment_archetype_id": environment.get("archetype_id", ""),
		"message": message,
	})
	result["blackjack_player_hands"] = hands
	result["blackjack_dealer"] = dealer_cards
	result["blackjack_patron_hands"] = patron_hands
	result["blackjack_patron_action_events"] = patron_action_events
	result["blackjack_hand_results"] = hand_results
	result["blackjack_side_bet_results"] = side_results
	result["blackjack_main_delta"] = main_delta
	result["blackjack_side_bet_delta"] = side_delta
	result["blackjack_sat_out"] = sit_out
	result["blackjack_cheat_caught"] = bool(cheat.get("caught", false))
	result["blackjack_coolers_cufflinks_broke"] = cufflinks_broke
	result["blackjack_strategy_deviation_events"] = _dictionary_array(cheat.get("strategy_deviation_events", []))
	result["blackjack_strategy_confronted"] = bool(cheat.get("strategy_confronted", false))
	result["blackjack_pit_boss_watched"] = bool(cheat.get("pit_boss_watched", false))
	result["blackjack_pit_boss_heat_bonus"] = int(cheat.get("pit_boss_heat_bonus", 0))
	result["blackjack_running_count"] = int(table.get("running_count", 0))
	result["blackjack_recorded_count"] = int(table.get("recorded_running_count", 0))
	GameModule.apply_result(run_state, result, rng)
	return result


func wager_cost_for_context(action_id: String, stake: int, run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> int:
	if action_id != "play_basic":
		return 0
	var table: Dictionary = _table_state(run_state, environment)
	if bool(table.get("barred", false)):
		return 0
	var session: Dictionary = _normalized_session(run_state, environment, ui_state, table)
	if bool(session.get("blackjack_sit_out", false)):
		return 0
	return _wager_cost_from_session(_session_stake(stake, session), session, table, run_state)


func environment_object_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var table: Dictionary = _table_state(run_state, environment)
	if table.is_empty():
		return {}
	var shoe_remaining: int = _shoe_remaining(table)
	var side_bets: Array = _side_bet_labels(_available_side_bets(table))
	var patrons: Array = _dictionary_array(table.get("patrons", []))
	var barred := bool(table.get("barred", false))
	var heat_text := "barred" if barred else "watched" if run_state != null and run_state.suspicion_level() >= 50 else "open"
	var shoe_label := str(table.get("shoe_label", CardShoeScript.shoe_label(int(table.get("deck_count", 6)))))
	var efficiency := str(table.get("count_efficiency", CardShoeScript.count_efficiency_label(int(table.get("deck_count", 6)))))
	var status_summary := str(table.get("barred_reason", "Blackjack table barred for cheating.")) if barred else "%s: %d cards; %d patrons; count %+d." % [shoe_label.capitalize(), shoe_remaining, patrons.size(), int(table.get("recorded_running_count", 0))]
	var effect_summary := "Blackjack barred. Other games in the room remain available, but staff suspicion is near max." if barred else "Dealer %s. Count efficiency %s. Side bets: %s." % [str(table.get("dealer_name", "Dealer")), efficiency, ", ".join(side_bets) if not side_bets.is_empty() else "none"]
	var badge := "BARRED" if barred else "COUNT %+d" % int(table.get("recorded_running_count", 0))
	return {
		"runtime_state": {
			"hands_played": int(table.get("hands_played", 0)),
			"shoe_remaining": shoe_remaining,
			"deck_count": int(table.get("deck_count", 6)),
			"cut_card_remaining": int(table.get("cut_card_remaining", CardShoeScript.cut_card_remaining(int(table.get("deck_count", 6))))),
			"recorded_running_count": int(table.get("recorded_running_count", 0)),
			"patron_count": patrons.size(),
		},
		"visual_state": {
			"status": heat_text,
			"side_bets": side_bets,
			"shoe_remaining": shoe_remaining,
			"shoe_label": shoe_label,
			"count_efficiency": efficiency,
			"patrons": patrons.size(),
			"dealer": str(table.get("dealer_name", "Dealer")),
		},
		"status_summary": status_summary,
		"effect_summary": effect_summary,
		"state_badge": badge,
	}


func _resolve_cheat_only(action_id: String, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary) -> Dictionary:
	var table: Dictionary = _table_state(run_state, environment)
	if bool(table.get("barred", false)):
		return _empty_blackjack_result(action_id, 0, environment, str(table.get("barred_reason", "The dealer refuses to let you play this blackjack table.")))
	var session: Dictionary = _normalized_session(run_state, environment, ui_state, table)
	if action_id == "peek_hole_card":
		var cheats: Dictionary = _local_copy_dict(session.get("cheats_used", {}))
		cheats["peek_hole_card"] = true
		session["peek_had_window"] = bool(session.get("peek_had_window", false)) or _dealer_peek_window_open(table, session, run_state)
		session["peek_snitch_risk"] = _patron_snitch_risk(table, session)
		session["cheats_used"] = cheats
		if bool(session.get("peek_caught_watching", false)) or not bool(session.get("peek_had_window", false)):
			return _resolve_watched_peek_confrontation(table, session, run_state, environment, rng)
	elif action_id == "count_cards":
		if _local_copy_dict(session.get("count_challenge", {})).is_empty():
			_start_count_challenge(session, table, run_state)
		if not bool(session.get("count_answered", false)):
			_finalize_count_challenge(session, run_state)
	var cheat: Dictionary = _cheat_detection_for_hand(session, table, run_state, environment, rng, _session_stake(maxi(1, int(ui_state.get("selected_stake", 1))), session))
	var cufflinks_broke := _coolers_cufflinks_absorbed_failed_peek(action_id, cheat, run_state)
	var raw_suspicion_delta: int = maxi(1, int(cheat.get("suspicion_delta", 0))) if action_id == "peek_hole_card" else maxi(0, int(cheat.get("suspicion_delta", 0)))
	if cufflinks_broke:
		raw_suspicion_delta = 0
	var pit_boss_status := run_state.pit_boss_watch_status(environment) if run_state != null else {}
	var pit_boss_watched := bool(cheat.get("pit_boss_watched", pit_boss_status.get("watched", false)))
	var pit_boss_heat_bonus := int(cheat.get("pit_boss_heat_bonus", pit_boss_status.get("cheat_heat_bonus", 0)))
	var suspicion_delta: int = run_state.alcohol_adjusted_suspicion_delta(raw_suspicion_delta) if raw_suspicion_delta > 0 else raw_suspicion_delta
	var security_pressure: Dictionary = run_state.security_action_pressure("cheat", maxi(1, int(ui_state.get("selected_stake", 1))), run_state.suspicion_level() + suspicion_delta) if suspicion_delta > 0 else {}
	var bankroll_delta := int(security_pressure.get("bankroll_delta", 0))
	var security_message := str(security_pressure.get("message", ""))
	var message := str(cheat.get("message", "The dealer narrows their eyes."))
	if cufflinks_broke:
		message = "%s Cooler's Cufflinks take the heat, then snap." % message
	if not security_message.is_empty():
		message = "%s %s" % [message, security_message]
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["suspicion_delta"] = suspicion_delta
	if cufflinks_broke:
		deltas["inventory_remove"] = [COOLERS_CUFFLINKS_ITEM_ID]
		deltas["inventory_add"] = [BROKEN_CUFFLINKS_ITEM_ID]
	deltas["messages"] = [message]
	deltas["story_log"] = [{
		"type": "game_action",
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": "cheat",
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"base_suspicion_delta": raw_suspicion_delta,
		"dealer_caught_cheat": bool(cheat.get("caught", false)),
		"environment_id": environment.get("id", ""),
		"pit_boss_watched": pit_boss_watched,
		"pit_boss_heat_bonus": pit_boss_heat_bonus,
		"coolers_cufflinks_broke": cufflinks_broke,
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
		"pit_boss_watched": pit_boss_watched,
		"pit_boss_heat_bonus": pit_boss_heat_bonus,
		"base_suspicion_delta": raw_suspicion_delta,
	})
	if action_id == "count_cards":
		result["blackjack_count_answered"] = bool(session.get("count_answered", false))
		result["blackjack_count_delta"] = int(session.get("count_delta", 0))
		result["preserve_surface_ui_state"] = true
		result["blackjack_surface_ui_state"] = session.duplicate(true)
	result["blackjack_pit_boss_watched"] = pit_boss_watched
	result["blackjack_pit_boss_heat_bonus"] = pit_boss_heat_bonus
	result["blackjack_coolers_cufflinks_broke"] = cufflinks_broke
	GameModule.apply_result(run_state, result, rng)
	return result


func _resolve_watched_peek_confrontation(table: Dictionary, session: Dictionary, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var table_stake := _session_stake(maxi(1, int(session.get("selected_stake", session.get("locked_stake", 1)))), session)
	var confiscated_bet := maxi(1, _wager_cost_from_session(table_stake, session, table, run_state))
	var current_heat := run_state.suspicion_level_for_environment_id(str(environment.get("id", ""))) if run_state != null else 0
	var raw_heat := rng.randi_range(60, 80) if rng != null else 70
	var desired_applied_heat := maxi(0, mini(raw_heat, 95 - current_heat))
	var heat_delta := _base_suspicion_for_applied_cap(desired_applied_heat, run_state)
	var applied_heat_preview := run_state.alcohol_adjusted_suspicion_delta(heat_delta) if run_state != null else heat_delta
	var pit_boss_status := run_state.pit_boss_watch_status(environment) if run_state != null else {}
	var pit_boss_watched := bool(pit_boss_status.get("watched", false))
	var pit_boss_heat_bonus := int(pit_boss_status.get("cheat_heat_bonus", 0)) if bool(pit_boss_status.get("active", false)) else 0
	var dealer_name := str(table.get("dealer_name", "The dealer"))
	var message := "%s catches the peek cold, sweeps your bet, and tells you the blackjack table is closed to you for cheating." % dealer_name
	var pit_boss_summary := str(pit_boss_status.get("summary", "")) if bool(pit_boss_status.get("active", false)) else ""
	if not pit_boss_summary.is_empty():
		message = "%s %s" % [message, pit_boss_summary]
	var cufflinks_broke := run_state != null and run_state.inventory.has(COOLERS_CUFFLINKS_ITEM_ID)
	if cufflinks_broke:
		heat_delta = 0
		applied_heat_preview = 0
		message = "%s Cooler's Cufflinks catch the heat, then snap into useless metal." % message
	table["barred"] = true
	table["barred_reason"] = "%s will not deal to you again after the caught hole-card peek." % dealer_name
	table["barred_at_hand"] = int(table.get("hands_played", 0))
	table["barred_confiscated_bet"] = confiscated_bet
	table["barred_scope"] = "blackjack_table"
	table["barred_heat_delta"] = applied_heat_preview
	table["last_patron_action_events"] = []
	table["last_result"] = {
		"headline": "BARRED",
		"summary": message,
		"bankroll_delta": -confiscated_bet,
		"suspicion_delta": applied_heat_preview,
		"dealer_cards": _card_array(session.get("dealer_cards", [])),
		"player_hands": _hand_array(session.get("player_hands", [])),
		"hand_results": [],
		"side_bet_results": [],
		"caught": true,
		"watched_peek": true,
		"confiscated_bet": confiscated_bet,
		"resolved_at_msec": Time.get_ticks_msec(),
	}
	_update_environment_table(environment, table)
	var story_entry := {
		"type": "game_action",
		"game_id": get_id(),
		"action_id": "peek_hole_card",
		"stake": table_stake,
		"total_wager": confiscated_bet,
		"bankroll_delta": -confiscated_bet,
		"suspicion_delta": applied_heat_preview,
		"base_suspicion_delta": heat_delta,
		"dealer_caught_cheat": true,
		"blackjack_table_barred": true,
		"coolers_cufflinks_broke": cufflinks_broke,
		"pit_boss_watched": pit_boss_watched,
		"pit_boss_heat_bonus": pit_boss_heat_bonus,
		"environment_id": environment.get("id", ""),
		"environment_archetype_id": environment.get("archetype_id", ""),
	}
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = -confiscated_bet
	deltas["suspicion_delta"] = heat_delta
	if cufflinks_broke:
		deltas["inventory_remove"] = [COOLERS_CUFFLINKS_ITEM_ID]
		deltas["inventory_add"] = [BROKEN_CUFFLINKS_ITEM_ID]
	deltas["story_log"] = [story_entry]
	deltas["messages"] = [message]
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": "peek_hole_card",
		"action_kind": "cheat",
		"stake": table_stake,
		"bankroll_delta": -confiscated_bet,
		"suspicion_delta": heat_delta,
		"deltas": deltas,
		"won": false,
		"environment_id": environment.get("id", ""),
		"environment_archetype_id": environment.get("archetype_id", ""),
		"message": message,
		"pit_boss_watched": pit_boss_watched,
		"pit_boss_heat_bonus": pit_boss_heat_bonus,
		"base_suspicion_delta": heat_delta,
	})
	result["blackjack_table_barred"] = true
	result["blackjack_watched_peek"] = true
	result["blackjack_confiscated_bet"] = confiscated_bet
	result["blackjack_coolers_cufflinks_broke"] = cufflinks_broke
	result["blackjack_pit_boss_watched"] = pit_boss_watched
	result["blackjack_pit_boss_heat_bonus"] = pit_boss_heat_bonus
	result["dealer_caught_cheat"] = true
	result["defer_bankroll_zero_failure"] = true
	GameModule.apply_result(run_state, result, rng)
	return result


func _base_suspicion_for_applied_cap(desired_applied_heat: int, run_state: RunState) -> int:
	desired_applied_heat = maxi(0, desired_applied_heat)
	if run_state == null or desired_applied_heat <= 0:
		return desired_applied_heat
	for candidate in range(desired_applied_heat, -1, -1):
		if run_state.alcohol_adjusted_suspicion_delta(candidate) <= desired_applied_heat:
			return candidate
	return 0


func _draw_blackjack_room(surface, surface_state: Dictionary) -> void:
	var clock := _surface_clock(surface)
	var board_size: Vector2 = surface.surface_board_size()
	surface.draw_rect(Rect2(Vector2.ZERO, board_size), Color("#05060a"))
	surface.draw_rect(Rect2(0, 0, board_size.x, 82), Color("#101427"))
	surface.draw_rect(Rect2(0, 82, board_size.x, BJ_CONSOLE_Y - 82.0), Color("#070810"))
	surface.draw_rect(Rect2(0, BJ_CONSOLE_Y, board_size.x, maxf(0.0, board_size.y - BJ_CONSOLE_Y)), Color("#07070d"))
	surface.draw_rect(Rect2(0, 78, board_size.x, 3), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.62))
	surface.draw_rect(Rect2(0, BJ_CONSOLE_Y - 3.0, board_size.x, 3), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.42))
	_draw_surface_light_cone(surface, Vector2(176, 78), Vector2(190, 238), C_CYAN, 0.065)
	_draw_surface_light_cone(surface, Vector2(724, 78), Vector2(188, 238), C_PINK, 0.070)
	_draw_surface_scan_bands(surface, 0, int(board_size.x), 0, 146, C_CYAN, 0.040, 1.6)
	_draw_neon_panel(surface, Rect2(24, 14, 286, 58), C_CYAN, 0.16 + absf(sin(clock * 2.1)) * 0.04)
	_draw_neon_panel(surface, Rect2(332, 18, 236, 48), C_PINK, 0.12 + absf(sin(clock * 1.7)) * 0.04)
	_draw_security_mirror(surface, Rect2(606, 16, 68, 50), C_PINK)
	_draw_watch_camera_surface(surface, Vector2(584, 42), C_PINK)
	surface.surface_title(str(surface_state.get("table_name", "Blackjack")).to_upper().left(18), Vector2(36, 42), C_CYAN)
	surface.surface_label(_table_rules_text(surface_state).left(42), Vector2(42, 62), 10, C_SOFT)
	surface.surface_label("shoe %d   count %+d" % [
		int(surface_state.get("shoe_remaining", 0)),
		int(surface_state.get("recorded_running_count", 0)),
	], Vector2(344, 48), 12, C_SOFT)


func _draw_blackjack_table(surface, surface_state: Dictionary) -> void:
	var clock := _surface_clock(surface)
	var rail_points := [
		Vector2(46, 142), Vector2(156, 92), Vector2(334, 76), Vector2(566, 76),
		Vector2(744, 92), Vector2(854, 142), Vector2(822, BJ_TABLE_BOTTOM), Vector2(78, BJ_TABLE_BOTTOM),
	]
	surface.draw_polygon(rail_points, [Color("#170d17")])
	surface.draw_polygon([
		Vector2(58, 148), Vector2(170, 102), Vector2(342, 86), Vector2(558, 86),
		Vector2(730, 102), Vector2(842, 148), Vector2(808, BJ_TABLE_BOTTOM - 12.0), Vector2(92, BJ_TABLE_BOTTOM - 12.0),
	], [Color("#3a1830")])
	var felt_points := [
		Vector2(84, 154), Vector2(190, 116), Vector2(358, 102), Vector2(542, 102),
		Vector2(710, 116), Vector2(816, 154), Vector2(766, 314), Vector2(134, 314),
	]
	surface.draw_polygon(felt_points, [Color("#0a5a48")])
	surface.draw_polygon([
		Vector2(126, 166), Vector2(226, 136), Vector2(372, 120), Vector2(528, 120),
		Vector2(674, 136), Vector2(774, 166), Vector2(736, 292), Vector2(164, 292),
	], [Color("#063f35")])
	for i in range(7):
		var y := 134 + i * 20
		surface.draw_line(Vector2(144 + i * 5, y), Vector2(756 - i * 5, y + 3), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.035), 1)
	surface.draw_rect(Rect2(116, 316, 672, 5), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.30))
	surface.draw_rect(Rect2(140, 308, 620, 2), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.16 + absf(sin(clock * 2.4)) * 0.08))
	_draw_betting_arc(surface, Vector2(450, 306), 374, C_YELLOW)
	_draw_seat_marker(surface, _player_hand_base_position(0), "H1", bool(surface_state.get("active_hand_index", 0) == 0))
	_draw_seat_marker(surface, _player_hand_base_position(1), "H2", bool(surface_state.get("active_hand_index", 0) == 1))
	_draw_seat_marker(surface, _player_hand_base_position(2), "H3", bool(surface_state.get("active_hand_index", 0) == 2))
	_draw_seat_marker(surface, _player_hand_base_position(3), "H4", bool(surface_state.get("active_hand_index", 0) == 3))
	surface.surface_label_centered("BLACKJACK PAYS 3 TO 2", Rect2(332, 148, 236, 18), 13, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.72))
	surface.surface_label_centered("INSURANCE PAYS 2:1", Rect2(348, 172, 204, 16), 10, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.52))
	surface.surface_label_centered("NO MID-HAND MERCY", Rect2(356, 196, 190, 14), 9, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.42))


func _draw_dealer_station(surface, surface_state: Dictionary) -> void:
	var focus: Dictionary = _dealer_focus_for_surface_state(surface_state)
	var profile: Dictionary = _local_copy_dict(surface_state.get("dealer_profile", {}))
	var looking_away := bool(focus.get("lookaway_active", false))
	var peek_window := bool(focus.get("peek_window_open", looking_away))
	var blink := bool(focus.get("blink", false))
	var eye_offset := float(focus.get("eye_offset", 0.0))
	var idle := _surface_clock(surface) + float(int(profile.get("blink_offset", 0))) / 1000.0
	var attention_color := C_PINK if int(focus.get("peek_danger", 0)) >= 70 else C_YELLOW if int(focus.get("peek_danger", 0)) >= 42 else C_TEAL
	surface.draw_rect(Rect2(352, 54, 196, 104), Color("#0b0d16"))
	surface.draw_rect(Rect2(352, 54, 196, 104), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.18), false, 1)
	_draw_dealer_gaze(surface, focus, Vector2(450, 91))
	_draw_table_character(surface, {
		"name": str(surface_state.get("dealer_name", "Dealer")),
		"skin": Color("#d8b18a"),
		"hair": Color("#2a1a25"),
		"jacket": Color("#1b2230"),
		"accent": attention_color,
		"role": "dealer",
		"pose": "lookaway" if peek_window else "watching",
		"eye_offset": eye_offset,
		"blink": blink,
		"holding_card": surface.surface_animation_active(DEAL_ANIMATION_CHANNEL),
		"uniform_accent": str(profile.get("uniform_accent", "")),
	}, Vector2(450, 156), 1.06, idle)
	var meter := clampi(int(focus.get("attention_meter", 0)), 0, 100)
	_draw_status_meter(surface, Rect2(566, 92, 118, 9), meter, "dealer %s" % str(focus.get("status", "watching")), C_PINK if meter >= 70 else C_YELLOW if meter >= 42 else C_TEAL)
	_draw_status_meter(surface, Rect2(566, 116, 118, 6), int(focus.get("peek_danger", 0)), str(focus.get("gaze_phase", "read")).left(20), attention_color)
	if peek_window:
		_draw_neon_panel(surface, Rect2(566, 130, 122, 22), C_TEAL, 0.28)
		var peek_label: String = "PEEK %.1fs" % (float(int(focus.get("lookaway_remaining_msec", 0))) / 1000.0) if looking_away else "PEEK WINDOW"
		surface.surface_label_centered(peek_label, Rect2(570, 134, 114, 14), 11, C_TEAL)
	else:
		surface.surface_label(str(focus.get("body_language", focus.get("tell", ""))).left(26), Vector2(566, 142), 9, C_SOFT)
	_draw_card_row_for_table(surface, surface_state, _card_array(surface_state.get("dealer", [])), Vector2(386, 158), "dealer", 0, DEALER_CARD_SCALE)
	_draw_shoe(surface, Vector2(706, 112), int(surface_state.get("shoe_remaining", 0)))
	_draw_discard_tray(surface, Vector2(244, 118), surface_state)


func _draw_table_patrons(surface, surface_state: Dictionary) -> void:
	var patrons: Array = _dictionary_array(surface_state.get("patrons", []))
	for i in range(patrons.size()):
		var patron: Dictionary = patrons[i]
		var base_pos := _patron_seat_position(i)
		var phase := fmod((_surface_clock(surface) + float(int(patron.get("animation_offset", 0))) / 1000.0) / 2.2, 1.0)
		var bob := sin(phase * PI * 2.0) * (2.0 if bool(patron.get("watching_player", false)) else 1.0)
		var lean := float(patron.get("lean", 0.0))
		var pos := base_pos + Vector2(lean, bob)
		var watching := bool(patron.get("watching_player", false))
		var covered := bool(patron.get("covered", false))
		var risk := int(patron.get("active_snitch_risk", 0))
		var threshold := int(patron.get("snitch_threshold", 30))
		var tell_active := watching and (risk >= threshold or (phase > 0.58 and phase < 0.82))
		var accent := C_PINK if watching else C_TEAL if covered else C_SOFT
		var character_clock := _surface_clock(surface) + float(int(patron.get("animation_offset", 0))) / 1000.0
		_draw_table_character(surface, {
			"name": str(patron.get("name", "Seat")),
			"skin": Color("#c49371"),
			"hair": _patron_hair_color(patron),
			"jacket": _patron_jacket_color(patron),
			"accent": accent,
			"role": "patron",
			"pose": "covered" if covered else "snitch" if watching else "idle",
			"eye_offset": -2.0 if covered else 2.0 if watching else 0.0,
			"blink": phase > 0.92,
			"holding_card": false,
			"silhouette": str(patron.get("silhouette", "coat")),
		}, pos + Vector2(0, 52), 0.86, character_clock)
		if tell_active:
			_draw_neon_panel(surface, Rect2(pos.x - 36, pos.y - 46, 72, 20), accent, 0.22)
			surface.surface_label(str(patron.get("tell", "watching")).left(11), pos + Vector2(-30, -32), 8, accent)
			surface.draw_line(pos + Vector2(0, -24), Vector2(450, 284), Color(accent.r, accent.g, accent.b, 0.18), 1.0)
		var risk_width := clampf(float(risk) / 60.0, 0.0, 1.0) * 46.0
		surface.draw_rect(Rect2(pos.x - 28, pos.y + 61, 56, 5), Color("#070810"))
		surface.draw_rect(Rect2(pos.x - 28, pos.y + 61, risk_width, 5), accent)
		surface.surface_label(str(patron.get("behavior", ("%d" % risk) if watching else "busy" if covered else str(patron.get("mood", "")).left(7))).left(12), pos + Vector2(-30, 78), 9, accent)
		_draw_chip_stack(surface, pos + Vector2(30, 42), [{"value": 5, "count": clampi(int(patron.get("chip_stack", 0)) / 20, 1, 4)}], 0.42)
		TableVisualsScript.draw_patron_wager_badge(surface, surface_state, patron, pos, i)
		var patron_cards: Array = _card_array(patron.get("cards", []))
		if not patron_cards.is_empty():
			var action_event := _patron_active_action_event(surface, surface_state, i)
			var card_start := _patron_hand_base_position(i)
			var pad := Rect2(card_start.x - 5, card_start.y - 5, 86, 36)
			surface.draw_rect(pad, Color(0, 0, 0, 0.24))
			surface.draw_rect(pad, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.20), false, 1)
			_draw_card_row_for_table(surface, surface_state, patron_cards, card_start, "patron", i, PATRON_CARD_SCALE)
			var total := _hand_total(patron_cards)
			var total_color := C_ORANGE if total > 21 else C_YELLOW if total == 21 else C_SOFT
			surface.surface_label("%d" % total, card_start + Vector2(62, 29), 8, total_color)
			_draw_patron_move_badge(surface, card_start + Vector2(-3, -23), patron, action_event)
		surface.surface_label("cover", pos + Vector2(-18, 92), 8, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.62))
		surface.surface_add_invisible_hit(Rect2(pos.x - 34, pos.y - 24, 68, 94), "blackjack_patron_cover", i)


func _patron_active_action_event(surface, surface_state: Dictionary, patron_index: int) -> Dictionary:
	if not surface.surface_animation_active(DEAL_ANIMATION_CHANNEL):
		return {}
	var elapsed_msec := float(surface.surface_elapsed(DEAL_ANIMATION_CHANNEL)) * 1000.0
	for event_value in _patron_action_event_array(surface_state.get("patron_action_events", [])):
		var event: Dictionary = event_value
		if int(event.get("patron_index", -1)) != patron_index:
			continue
		var start := float(event.get("delay_msec", 0))
		var duration := float(event.get("duration_msec", PATRON_DECISION_HIGHLIGHT_MSEC))
		if elapsed_msec >= start and elapsed_msec <= start + duration:
			var progress := clampf((elapsed_msec - start) / maxf(1.0, duration), 0.0, 1.0)
			event["progress"] = progress
			return event
	return {}


func _draw_patron_move_badge(surface, pos: Vector2, patron: Dictionary, active_event: Dictionary) -> void:
	var label := str(active_event.get("label", patron.get("hand_action_label", "")))
	if label.is_empty():
		return
	var reason := str(active_event.get("reason", patron.get("hand_action_reason", "")))
	var action := str(active_event.get("action", patron.get("hand_action", "")))
	var peek_informed := bool(active_event.get("peek_informed", patron.get("hand_peek_informed", false)))
	var active := not active_event.is_empty()
	var accent := C_YELLOW if peek_informed else C_TEAL if action == "hit" else C_CYAN
	var pulse := 0.26 + absf(sin(_surface_clock(surface) * 5.2)) * 0.12 if active else 0.10
	var rect_width := 76.0 if peek_informed else 58.0
	var rect := Rect2(pos, Vector2(rect_width, 18))
	_draw_neon_panel(surface, rect, accent, pulse)
	surface.surface_label(label.left(10), rect.position + Vector2(6, 12), 8, accent)
	if active and not reason.is_empty():
		surface.surface_label(reason.left(17), rect.position + Vector2(4, -4), 7, C_SOFT)


func _draw_player_station(surface, surface_state: Dictionary) -> void:
	var hands: Array = _hand_array(surface_state.get("player_hands", []))
	var result: Dictionary = _local_copy_dict(surface_state.get("last_result", {}))
	var showdown_hands: Array = _hand_array(result.get("player_hands", []))
	var display_hands: Array = hands if not hands.is_empty() else showdown_hands
	var showing_showdown := hands.is_empty() and not showdown_hands.is_empty()
	var active_index: int = int(surface_state.get("active_hand_index", 0))
	_draw_player_forearms(surface, surface_state)
	var result_hands: Array = _dictionary_array(result.get("hand_results", []))
	var clock := _surface_clock(surface)
	for i in range(display_hands.size()):
		var hand: Dictionary = display_hands[i]
		var pos: Vector2 = _player_hand_base_position(i)
		var active := i == active_index and not showing_showdown
		var cards: Array = _card_array(hand.get("cards", []))
		var pad := Rect2(pos.x - 12, pos.y - 28, 120, 82)
		var pulse := 0.08 + absf(sin(clock * 3.2 + float(i))) * 0.08 if active else 0.04
		surface.draw_rect(pad.grow(3 if active else 0), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, pulse))
		surface.draw_rect(pad, C_YELLOW if showing_showdown else C_TEAL if active else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.22), false, 1)
		_draw_card_row_for_table(surface, surface_state, cards, pos, "player", i, PLAYER_CARD_SCALE)
		surface.surface_label("H%d %s" % [i + 1, _hand_label(hand)], pos + Vector2(-4, -8), 10, C_TEAL if active else C_SOFT)
		_draw_hand_state_badge(surface, pos + Vector2(6, -30), hand, active)
		if i < result_hands.size():
			_draw_hand_result_badge(surface, pos + Vector2(6, 54), result_hands[i])
	if showing_showdown:
		surface.surface_label_centered("SHOWDOWN HELD ON FELT", Rect2(342, 226, 216, 16), 10, C_YELLOW)
	if display_hands.is_empty():
		_draw_neon_panel(surface, Rect2(346, 236, 208, 36), C_CYAN, 0.12)
		surface.surface_label_centered("slide chips, then deal", Rect2(358, 246, 184, 16), 13, C_SOFT)
	_draw_player_wager_chips(surface, surface_state)
	_draw_side_bet_felt(surface, surface_state)


func _draw_player_wager_chips(surface, surface_state: Dictionary) -> void:
	var center := Vector2(452, 310)
	var stack: Array = surface_state.get("chip_stack", []) if typeof(surface_state.get("chip_stack", [])) == TYPE_ARRAY else []
	_draw_chip_stack(surface, center, stack, 0.58)
	surface.draw_rect(Rect2(center - Vector2(24, 20), Vector2(48, 46)), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.72), false, 1)
	surface.surface_label_centered("YOU", Rect2(center + Vector2(-18, 22), Vector2(36, 10)), 7, C_CYAN)


func _draw_hand_state_badge(surface, pos: Vector2, hand: Dictionary, active: bool) -> void:
	var cards: Array = _card_array(hand.get("cards", []))
	if cards.is_empty():
		return
	var total := _hand_total(cards)
	var text := ""
	var accent := C_SOFT
	if bool(hand.get("surrendered", false)):
		text = "SURRENDER"
		accent = C_ORANGE
	elif total > 21:
		text = "BUST"
		accent = C_ORANGE
	elif total == 21:
		text = "21 LOCKED"
		accent = C_YELLOW
	elif bool(hand.get("stood", false)):
		text = "STAND"
		accent = C_CYAN
	elif active:
		text = "LIVE"
		accent = C_TEAL
	if text.is_empty():
		return
	var rect := Rect2(pos, Vector2(66, 16))
	_draw_neon_panel(surface, rect, accent, 0.14)
	surface.surface_label(text, rect.position + Vector2(6, 11), 8, accent)


func _draw_blackjack_table_notice(surface, surface_state: Dictionary) -> void:
	var notice := str(surface_state.get("table_notice", ""))
	if notice.is_empty():
		notice = str(surface_state.get("active_hand_status", ""))
	if notice.is_empty():
		return
	var rect := Rect2(238, 314, 424, 26)
	var accent := C_ORANGE if notice.to_lower().find("bust") >= 0 else C_YELLOW if notice.to_lower().find("blackjack") >= 0 else C_TEAL
	_draw_neon_panel(surface, rect, accent, 0.18)
	surface.surface_label_centered(notice.left(78), Rect2(rect.position + Vector2(8, 5), rect.size - Vector2(16, 8)), 11, accent)


func _draw_blackjack_round_timer(surface, surface_state: Dictionary) -> void:
	TableVisualsScript.draw_round_timer_panel(surface, _local_copy_dict(surface_state.get("table_round_timer", {})), Rect2(668, 294, 112, 30), C_CYAN)


func _draw_blackjack_ambient_event(surface, surface_state: Dictionary) -> void:
	var event: Dictionary = _ambient_table_event_for_surface(surface, surface_state)
	if event.is_empty():
		return
	var accent := C_CYAN
	match str(event.get("accent", "cyan")):
		"pink":
			accent = C_PINK
		"yellow":
			accent = C_YELLOW
		"teal":
			accent = C_TEAL
		"orange":
			accent = C_ORANGE
	var rect := Rect2(28, 88, 190, 26)
	_draw_neon_panel(surface, rect, accent, 0.12 + float(event.get("intensity", 0.0)) * 0.10)
	surface.surface_label(str(event.get("label", "table motion")).to_upper().left(18), rect.position + Vector2(8, 12), 8, accent)
	surface.surface_label(str(event.get("detail", "")).left(24), rect.position + Vector2(8, 23), 7, C_SOFT)


func _draw_player_forearms(surface, surface_state: Dictionary) -> void:
	var clock := _surface_clock(surface)
	var active_index := int(surface_state.get("active_hand_index", 0))
	var left_hand := _player_hand_base_position(active_index) + Vector2(-32, 48)
	var right_hand := _player_hand_base_position(active_index) + Vector2(96, 50)
	var sleeve_y: float = surface.surface_board_size().y - 4.0
	var sleeve := Color("#171022")
	var skin := Color("#c49371")
	var tremor := sin(clock * 4.0) * 2.0
	surface.draw_line(Vector2(270, sleeve_y), left_hand + Vector2(tremor, 0), sleeve, 14.0)
	surface.draw_line(Vector2(630, sleeve_y), right_hand + Vector2(-tremor, 0), sleeve, 14.0)
	surface.draw_line(Vector2(270, sleeve_y), left_hand + Vector2(tremor, 0), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.32), 3.0)
	surface.draw_line(Vector2(630, sleeve_y), right_hand + Vector2(-tremor, 0), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.28), 3.0)
	surface.draw_rect(Rect2(left_hand + Vector2(-7 + tremor, -4), Vector2(14, 10)), skin)
	surface.draw_rect(Rect2(right_hand + Vector2(-7 - tremor, -4), Vector2(14, 10)), skin)


func _draw_hand_result_badge(surface, pos: Vector2, result: Dictionary) -> void:
	var outcome := str(result.get("outcome", "push")).replace("_", " ")
	var delta := int(result.get("bankroll_delta", 0))
	var accent := C_TEAL if delta > 0 else C_ORANGE if delta < 0 else C_YELLOW
	var rect := Rect2(pos, Vector2(72, 20))
	_draw_neon_panel(surface, rect, accent, 0.16)
	surface.surface_label(outcome.left(10), rect.position + Vector2(6, 12), 8, accent)
	surface.surface_label("%+d" % delta, rect.position + Vector2(44, 12), 8, accent)


func _draw_side_bet_felt(surface, surface_state: Dictionary) -> void:
	var side_bets: Array = _dictionary_array(surface_state.get("side_bets_available", []))
	var active: Array = _string_array(surface_state.get("side_bets_active", []))
	var stakes: Dictionary = _local_copy_dict(surface_state.get("side_bet_stakes", {}))
	var panel := Rect2(272, BJ_CONSOLE_Y + 8.0, 302, BJ_CONSOLE_H - 16.0)
	_draw_neon_panel(surface, panel, C_PINK_2, 0.08)
	surface.surface_label("SIDE BETS", panel.position + Vector2(10, 15), 10, C_SOFT)
	if side_bets.is_empty():
		surface.surface_label_centered("none on this table", Rect2(panel.position + Vector2(12, 32), Vector2(panel.size.x - 24, 18)), 11, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.58))
		return
	for i in range(mini(side_bets.size(), BLACKJACK_MAX_SIDE_BETS)):
		var bet: Dictionary = side_bets[i]
		var col := i % 2
		var row := int(i / 2)
		var rect := Rect2(panel.position.x + 12.0 + float(col) * 146.0, panel.position.y + 24.0 + float(row) * 30.0, 134, 24)
		var bet_id := str(bet.get("id", ""))
		var selected := active.has(bet_id)
		var enabled := bool(bet.get("surface_enabled", bool(surface_state.get("can_change_side_bets", false))))
		var accent := C_YELLOW if selected else C_SOFT
		surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.15 if selected else 0.06))
		surface.draw_rect(rect, accent if enabled else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.24), false, 1)
		surface.surface_label(str(bet.get("label", bet_id)).left(14), rect.position + Vector2(6, 15), 9, accent)
		surface.surface_label("$%d" % int(stakes.get(bet_id, 1)), rect.position + Vector2(104, 15), 9, accent)
		if enabled:
			surface.surface_add_hit(rect, "blackjack_side_bet", i)


func _draw_side_bet_rule_overlay(surface, surface_state: Dictionary) -> void:
	var side_bets: Array = _dictionary_array(surface_state.get("side_bets_available", []))
	if side_bets.is_empty():
		return
	var target_index := -1
	for i in range(mini(side_bets.size(), BLACKJACK_MAX_SIDE_BETS)):
		if bool(surface.surface_region_hovered("blackjack_side_bet", i)):
			target_index = i
			break
	if target_index < 0 or target_index >= side_bets.size():
		return
	var target: Dictionary = side_bets[target_index]
	var bet_id := str(target.get("id", ""))
	var active: Array = _string_array(surface_state.get("side_bets_active", []))
	var selected := active.has(bet_id)
	var accent := C_YELLOW if selected else C_PINK_2
	var rect := Rect2(236, 202, 428, 108)
	_draw_neon_panel(surface, rect, accent, 0.24)
	surface.draw_rect(rect.grow(1), Color(0.0, 0.0, 0.0, 0.22), false, 1)
	surface.surface_label("SIDE BET RULES", rect.position + Vector2(12, 15), 9, C_SOFT)
	surface.surface_label(str(target.get("label", bet_id)).to_upper().left(28), rect.position + Vector2(12, 31), 14, accent)
	surface.surface_label(str(target.get("summary", "")).left(54), rect.position + Vector2(12, 47), 8, C_SOFT)
	var rules: Array = _string_array(target.get("rules", _side_bet_definition(bet_id).get("rules", [])))
	var payouts: Array = _string_array(target.get("payouts", _side_bet_definition(bet_id).get("payouts", [])))
	var y := rect.position.y + 64.0
	for i in range(mini(rules.size(), 2)):
		surface.surface_label("- %s" % str(rules[i]).left(58), Vector2(rect.position.x + 14.0, y), 8, C_WHITE)
		y += 12.0
	var payout_text := ", ".join(payouts).left(72)
	if not payout_text.is_empty():
		surface.surface_label("PAYS: %s" % payout_text, Vector2(rect.position.x + 14.0, rect.position.y + rect.size.y - 10.0), 8, C_YELLOW)


func _draw_chip_rack(surface, surface_state: Dictionary) -> void:
	var rack := Rect2(18, BJ_CONSOLE_Y + 8.0, 242, BJ_CONSOLE_H - 16.0)
	surface.draw_rect(rack, Color("#120b14"))
	surface.draw_rect(rack, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.28), false, 1)
	surface.surface_label("CHIP RAIL", rack.position + Vector2(12, 15), 10, C_SOFT)
	surface.surface_label("BET $%d" % int(surface_state.get("selected_stake", 1)), rack.position + Vector2(112, 15), 12, C_YELLOW)
	var chips: Array = surface_state.get("chip_denominations", []) if typeof(surface_state.get("chip_denominations", [])) == TYPE_ARRAY else []
	var chip_y := rack.position.y + 46.0
	for i in range(chips.size()):
		if i == 0:
			surface.surface_add_invisible_hit(Rect2(Vector2(rack.position.x + 34.0 + float(i) * 40.0, chip_y) - Vector2(18, 18), Vector2(36, 36)), "surface_stake_up")
		_draw_chip_button(surface, Vector2(rack.position.x + 34.0 + float(i) * 40.0, chip_y), int(chips[i]), "blackjack_chip", i)
	_draw_chip_stack(surface, rack.position + Vector2(184, 50), surface_state.get("chip_stack", []), 0.46)
	_draw_table_button(surface, Rect2(rack.position.x + 174, rack.position.y + 22, 50, 22), "CLEAR", "blackjack_clear_bet", 0, C_SOFT, true)
	_draw_table_button(surface, Rect2(rack.position.x + 174, rack.position.y + 48, 50, 22), "MAX", "blackjack_max_bet", 0, C_YELLOW, true)


func _draw_table_actions(surface, surface_state: Dictionary) -> void:
	var panel := Rect2(586, BJ_CONSOLE_Y + 8.0, 292, BJ_CONSOLE_H - 16.0)
	_draw_neon_panel(surface, panel, C_CYAN, 0.10)
	surface.surface_label("HAND ACTIONS", panel.position + Vector2(10, 15), 10, C_SOFT)
	if bool(surface_state.get("table_barred", false)):
		surface.surface_label("TABLE CLOSED", panel.position + Vector2(14, 42), 16, C_PINK)
		surface.surface_label(str(surface_state.get("barred_reason", "Dealer refuses action.")).left(38), panel.position + Vector2(14, 62), 8, C_SOFT)
		return
	var snitch := int(surface_state.get("snitch_pressure", 0))
	surface.surface_label("Snitch %d" % snitch, panel.position + Vector2(210, 15), 9, C_PINK if snitch > 0 else C_SOFT)
	var counting_enabled := bool(surface_state.get("counting_enabled", false))
	_draw_table_button(surface, Rect2(panel.position.x + 112, panel.position.y + 7, 88, 16), "COUNT ON" if counting_enabled else "COUNT OFF", "blackjack_count_toggle", 0, C_PINK_2 if counting_enabled else C_SOFT, true, counting_enabled)
	if bool(surface_state.get("can_deal", false)):
		_draw_table_button(surface, Rect2(panel.position.x + 14, panel.position.y + 28, 132, 38), "DEAL", "blackjack_deal", 0, C_YELLOW, true, surface.surface_native_action_selected("blackjack_deal"))
	else:
		surface.surface_add_invisible_hit(Rect2(panel.position.x + 14, panel.position.y + 7, 84, 16), "blackjack_deal", 0)
		_draw_table_button(surface, Rect2(panel.position.x + 12, panel.position.y + 24, 84, 26), "HIT", "blackjack_hit", 0, C_TEAL, bool(surface_state.get("can_hit", false)))
		var stand_rect := Rect2(panel.position.x + 104, panel.position.y + 24, 84, 26)
		if surface.surface_native_action_selected("blackjack_deal"):
			surface.surface_add_invisible_hit(stand_rect, "blackjack_deal", 0)
		_draw_table_button(surface, stand_rect, "STAND", "blackjack_stand", 0, C_CYAN, bool(surface_state.get("can_stand", false)), surface.surface_native_action_selected("blackjack_stand"))
		_draw_table_button(surface, Rect2(panel.position.x + 196, panel.position.y + 24, 72, 26), "DOUBLE", "blackjack_double", 0, C_YELLOW, bool(surface_state.get("can_double", false)))
		_draw_table_button(surface, Rect2(panel.position.x + 12, panel.position.y + 54, 84, 22), "SPLIT", "blackjack_split", 0, C_AMBER, bool(surface_state.get("can_split", false)))
		var focus := _dealer_focus_for_surface_state(surface_state)
		var peek_available := bool(surface_state.get("peek_available", false))
		var peek_dangerous := peek_available and not bool(focus.get("peek_window_open", false)) and not bool(surface_state.get("dealer_hole_visible", false))
		_draw_table_button(surface, Rect2(panel.position.x + 104, panel.position.y + 54, 84, 22), "PEEK", "blackjack_peek", 0, C_PINK if peek_dangerous else C_TEAL, peek_available, surface.surface_native_action_selected("blackjack_peek"))
		if bool(surface_state.get("settle_available", false)):
			_draw_table_button(surface, Rect2(panel.position.x + 196, panel.position.y + 54, 72, 22), "SETTLE", "blackjack_deal", 0, C_YELLOW, true, surface.surface_native_action_selected("blackjack_deal"))
		elif bool(surface_state.get("can_surrender", false)):
			_draw_table_button(surface, Rect2(panel.position.x + 196, panel.position.y + 54, 72, 22), "SURRENDER", "blackjack_surrender", 0, C_ORANGE, bool(surface_state.get("can_surrender", false)))
	var distractions: Array = _dictionary_array(surface_state.get("distractions", []))
	var strip := Rect2(692, 294, 168, 34)
	_draw_neon_panel(surface, strip, C_TEAL, 0.08)
	surface.surface_label("LOOKAWAY", strip.position + Vector2(8, 14), 8, C_SOFT)
	for i in range(mini(distractions.size(), 3)):
		var distraction: Dictionary = distractions[i]
		var label := str(distraction.get("label", "Distract")).replace(" ", "").to_upper().left(5)
		_draw_table_button(surface, Rect2(strip.position.x + 64 + i * 34, strip.position.y + 8, 30, 18), label, "blackjack_distraction", i, C_TEAL, true)


func _draw_basic_strategy_advice(surface, surface_state: Dictionary) -> void:
	var advice: Dictionary = _local_copy_dict(surface_state.get("basic_strategy_advice", {}))
	if not bool(advice.get("visible", false)):
		return
	var rect := Rect2(662, 88, 198, 44)
	var accent := C_YELLOW
	_draw_neon_panel(surface, rect, accent, 0.18)
	surface.draw_rect(rect.grow(1.0), Color(accent.r, accent.g, accent.b, 0.34), false, 1)
	surface.draw_circle(rect.position + Vector2(24, 22), 14, Color(accent.r, accent.g, accent.b, 0.24))
	surface.draw_circle(rect.position + Vector2(24, 22), 14, accent, false, 2)
	surface.surface_label_centered("BOOK", Rect2(rect.position + Vector2(7, 16), Vector2(34, 12)), 8, C_WHITE)
	surface.surface_label("BASIC STRATEGY", rect.position + Vector2(48, 14), 8, C_SOFT)
	surface.surface_label(str(advice.get("label", "")).to_upper().left(18), rect.position + Vector2(48, 30), 14, accent)
	var reason := str(advice.get("summary", ""))
	if not reason.is_empty():
		surface.surface_label(reason.left(28), rect.position + Vector2(122, 30), 8, C_SOFT)


func _draw_deal_animation(surface, surface_state: Dictionary) -> void:
	if not surface.surface_animation_active(DEAL_ANIMATION_CHANNEL):
		return
	var events: Array = _surface_deal_animation_events(surface_state)
	if events.is_empty():
		events.append(_deal_animation_event({"rank": 2, "suit": 0, "hidden": true}, "player", 0, 0, DEAL_CARD_SHOE_POS, _player_hand_card_target(0, 0), 0, PLAYER_CARD_SCALE, "card"))
	var elapsed_msec := float(surface.surface_elapsed(DEAL_ANIMATION_CHANNEL)) * 1000.0
	for event_value in events:
		var event: Dictionary = event_value
		var delay := float(event.get("delay_msec", 0))
		var duration := maxf(1.0, float(event.get("duration_msec", DEAL_CARD_DURATION_MSEC)))
		if elapsed_msec < delay or elapsed_msec > delay + duration:
			continue
		var t := clampf((elapsed_msec - delay) / duration, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - t, 3.0)
		var start := _event_vector(event.get("from", []), DEAL_CARD_SHOE_POS)
		var target := _event_vector(event.get("to", []), Vector2(454, 224))
		var lift := -18.0 * sin(t * PI)
		var wiggle := sin((t * PI * 2.0) + float(event.get("delay_msec", 0)) * 0.01) * 2.0
		var pos := start.lerp(target, eased) + Vector2(wiggle, lift)
		var scale := float(event.get("scale", 0.62))
		surface.draw_rect(Rect2(pos + Vector2(4, 5) * scale, Vector2(42, 60) * scale), Color(0, 0, 0, 0.22))
		_draw_card(surface, _local_copy_dict(event.get("card", {})), pos, scale)


func _draw_chip_payout_animation(surface, surface_state: Dictionary) -> void:
	var result: Dictionary = _local_copy_dict(surface_state.get("last_result", {}))
	if result.is_empty():
		return
	if not surface.surface_animation_active(PAYOUT_ANIMATION_CHANNEL):
		return
	var elapsed_msec := float(surface.surface_elapsed(PAYOUT_ANIMATION_CHANNEL)) * 1000.0
	var t := clampf(elapsed_msec / float(PAYOUT_ANIMATION_DURATION_MSEC), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0)
	var delta := int(result.get("bankroll_delta", 0))
	var main_delta := int(result.get("main_delta", delta))
	var side_delta := int(result.get("side_delta", 0))
	var source := Vector2(622, 116)
	var target := Vector2(206, BJ_CONSOLE_Y + 58.0)
	if delta < 0:
		source = Vector2(450, 306)
		target = Vector2(622, 116)
	elif delta == 0:
		source = Vector2(450, 306)
		target = Vector2(450, 306)
	var chip_values: Array = _chip_denominations({})
	var stack: Array = _chip_stack_for_stake(maxi(1, abs(delta)), chip_values)
	var draw_count := 0
	for entry_value in stack:
		var entry: Dictionary = entry_value
		var value := int(entry.get("value", 1))
		var count := clampi(int(entry.get("count", 1)), 1, 6)
		for i in range(count):
			if draw_count >= 7:
				break
			var delay := float(draw_count) * 110.0
			var local_t := clampf((elapsed_msec - delay) / 820.0, 0.0, 1.0)
			var local_eased := 1.0 - pow(1.0 - local_t, 3.0)
			var arc := -34.0 * sin(local_t * PI)
			var jitter := Vector2(float((draw_count % 3) - 1) * 8.0, float(draw_count % 2) * 5.0)
			var pos := source.lerp(target + jitter, local_eased) + Vector2(0, arc)
			_draw_casino_chip(surface, pos, value, 13.0, clampf(0.18 + local_t, 0.18, 1.0), false)
			draw_count += 1
		if draw_count >= 7:
			break
	var label_rect := Rect2(312, 290, 276, 34)
	var accent := C_TEAL if delta > 0 else C_ORANGE if delta < 0 else C_YELLOW
	_draw_neon_panel(surface, label_rect, accent, 0.18 * (1.0 - clampf(t - 0.68, 0.0, 1.0)))
	var label := "PUSH: CHIPS RETURN"
	if delta > 0:
		label = "DEALER PAYS $%+d" % delta
	elif delta < 0:
		label = "DEALER COLLECTS $%d" % abs(delta)
	if side_delta != 0:
		label += " / SIDE %+d" % side_delta
	elif main_delta != delta:
		label += " / MAIN %+d" % main_delta
	surface.surface_label_centered(label.left(42), label_rect.grow(-5), 12, accent)


func _draw_card_row_for_table(surface, surface_state: Dictionary, cards: Array, start: Vector2, zone: String, hand_index: int = 0, scale: float = 1.0) -> void:
	var spacing := 54.0 * scale
	if cards.size() > 1:
		if zone == "player":
			spacing = minf(spacing, 86.0 / float(cards.size() - 1))
		elif zone == "dealer":
			spacing = minf(spacing, 176.0 / float(cards.size() - 1))
	for i in range(cards.size()):
		if _card_waiting_for_deal_animation(surface, surface_state, zone, hand_index, i):
			continue
		_draw_card(surface, cards[i], start + Vector2(float(i) * spacing, 0), scale)


func _card_waiting_for_deal_animation(surface, surface_state: Dictionary, zone: String, hand_index: int, card_index: int) -> bool:
	if not surface.surface_animation_active(DEAL_ANIMATION_CHANNEL):
		return false
	var elapsed_msec := float(surface.surface_elapsed(DEAL_ANIMATION_CHANNEL)) * 1000.0
	for event_value in _surface_deal_animation_events(surface_state):
		var event: Dictionary = event_value
		if str(event.get("zone", "")) != zone:
			continue
		if int(event.get("hand_index", -1)) != hand_index:
			continue
		if int(event.get("card_index", -1)) != card_index:
			continue
		var reveal_at := float(event.get("delay_msec", 0)) + float(event.get("duration_msec", DEAL_CARD_DURATION_MSEC)) * 0.92
		return elapsed_msec < reveal_at
	return false


func _draw_dealer_gaze(surface, focus: Dictionary, eye_origin: Vector2) -> void:
	if bool(focus.get("peek_window_open", bool(focus.get("lookaway_active", false)))):
		surface.draw_line(eye_origin + Vector2(-6, 0), eye_origin + Vector2(-70, 22), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.34), 2.0)
		return
	var danger := clampi(int(focus.get("peek_danger", 0)), 0, 100)
	var alpha := 0.06 + float(danger) / 100.0 * 0.14
	var target := Vector2(450 + float(focus.get("eye_offset", 0.0)) * 9.0, 292)
	var color := C_PINK if danger >= 70 else C_YELLOW if danger >= 42 else C_TEAL
	surface.draw_polygon([
		eye_origin + Vector2(-12, 3),
		eye_origin + Vector2(12, 3),
		target + Vector2(88, 0),
		target + Vector2(-88, 0),
	], [Color(color.r, color.g, color.b, alpha)])


func _surface_clock(surface) -> float:
	return float(surface.surface_flicker()) if surface != null and surface.has_method("surface_flicker") else float(Time.get_ticks_msec()) / 1000.0


func _dealer_focus_for_surface_state(surface_state: Dictionary) -> Dictionary:
	var runtime: Dictionary = _local_copy_dict(surface_state.get("dealer_focus_runtime", {}))
	if runtime.is_empty():
		return _local_copy_dict(surface_state.get("dealer_focus", {}))
	var profile: Dictionary = _local_copy_dict(surface_state.get("dealer_profile", {}))
	var base_attention: int = int(profile.get("attention_base", 24))
	var heat: int = int(surface_state.get("suspicion_level", 0))
	var started := int(runtime.get("dealer_lookaway_started_msec", 0))
	var duration := int(runtime.get("dealer_lookaway_duration_msec", 0))
	var now := Time.get_ticks_msec()
	var active := started > 0 and duration > 0 and now <= started + duration
	var remaining := maxi(0, started + duration - now) if active else 0
	var cycle_msec := maxi(900, int(320000 / maxi(45, int(profile.get("gaze_speed", 95)))))
	var phase := float((now + int(profile.get("blink_offset", 0))) % cycle_msec) / float(cycle_msec)
	var sweep := sin(phase * PI * 2.0)
	var scan_attention := int((0.5 + 0.5 * sweep) * 18.0)
	var count_pressure := 0 if not bool(runtime.get("count_active", false)) else int(float(int(runtime.get("count_attention_risk", 0))) / 4.0)
	var strategy_pressure := clampi(int(surface_state.get("strategy_watch_pressure", 0)) + int(runtime.get("strategy_attention_boost", 0)), 0, STRATEGY_DEVIATION_MAX_WATCH)
	var attention := clampi(base_attention + int(float(heat) * 0.35) + scan_attention + count_pressure + strategy_pressure + int(runtime.get("dealer_distraction_noise", 0)), 0, 100)
	if active:
		attention = clampi(attention - 44 - int(runtime.get("dealer_distraction_cover", 0)), 0, 100)
	var blink := phase > 0.94 and phase < 0.985
	var watching_player := not active and phase >= 0.18 and phase <= 0.46
	var focus_snapshot: Dictionary = _local_copy_dict(surface_state.get("dealer_focus", {}))
	var peek_window_percent := clampi(int(focus_snapshot.get("peek_window_percent", 100)), 10, 100)
	var window_half_width := 0.08 * (float(peek_window_percent) / 100.0)
	var read_start := 0.62 - window_half_width
	var read_end := 0.62 + window_half_width
	var read_window := active or (attention < 58 and phase > read_start and phase < read_end)
	var peek_danger := clampi(attention + (0 if active else int(abs(sweep) * 16.0)) + int(int(surface_state.get("snitch_pressure", 0)) / 4.0), 0, 100)
	var peek_window_open := active or (read_window and not watching_player and peek_danger <= 62)
	var gaze_phase := "looking away" if active else "blink" if blink else "watching you" if watching_player else "hole card loose" if peek_window_open else "open read" if read_window else str(profile.get("read_style", "slow sweep"))
	var body_language := "shoulder turned" if active else "eyes on your chips" if watching_player else "checks payout tray" if peek_window_open or phase > 0.70 else "tracks the felt"
	return {
		"lookaway_active": active,
		"lookaway_remaining_msec": remaining,
		"attention_meter": attention,
		"status": "looking away" if active else "locked on" if attention >= 70 else "watching",
		"tell": str(profile.get("tell", "watches hands more than faces")),
		"gaze_phase": gaze_phase,
		"body_language": body_language,
		"read_window": read_window,
		"watching_player": watching_player,
		"peek_window_open": peek_window_open,
		"scan_phase": phase,
		"count_pressure": count_pressure,
		"strategy_pressure": strategy_pressure,
		"peek_danger": peek_danger,
		"peek_window_percent": peek_window_percent,
		"eye_offset": -0.65 if active else sweep,
		"blink": blink,
	}


func _ambient_table_event_for_surface(surface, surface_state: Dictionary) -> Dictionary:
	if str(surface_state.get("phase", "")) == "betting":
		return {}
	var now_msec := int(_surface_clock(surface) * 1000.0)
	var cycle_msec := 4200
	var phase := float(now_msec % cycle_msec) / float(cycle_msec)
	if phase > 0.42:
		return {}
	var catalog: Array = [
		{"label": "chip shuffle", "detail": "seat stack clicks", "accent": "yellow"},
		{"label": "pit glance", "detail": "security looks over", "accent": "pink"},
		{"label": "shoe tap", "detail": "dealer checks tray", "accent": "teal"},
		{"label": "patron tell", "detail": "someone leans in", "accent": "orange"},
		{"label": "felt chatter", "detail": "table noise rises", "accent": "cyan"},
	]
	var table_key: String = "%s:%d:%d" % [str(surface_state.get("table_name", "blackjack")), int(surface_state.get("hands_played", 0)), int(now_msec / cycle_msec)]
	var event_seed: int = abs(_stable_hash(table_key))
	var index: int = event_seed % catalog.size()
	var event: Dictionary = (catalog[index] as Dictionary).duplicate(true)
	event["phase"] = phase
	event["intensity"] = sin(clampf(phase / 0.42, 0.0, 1.0) * PI)
	return event


func _draw_neon_panel(surface, rect: Rect2, accent: Color, alpha: float = 0.18) -> void:
	surface.draw_rect(rect.grow(4), Color(accent.r, accent.g, accent.b, alpha * 0.22))
	surface.draw_rect(rect, Color(0.01, 0.02, 0.05, 0.72))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, alpha), false, 1)
	surface.draw_rect(Rect2(rect.position + Vector2(4, rect.size.y - 5), Vector2(maxf(0.0, rect.size.x - 8), 2)), Color(accent.r, accent.g, accent.b, alpha * 1.6))


func _draw_surface_scan_bands(surface, x0: int, x1: int, y0: int, y1: int, color: Color, alpha: float, speed: float) -> void:
	var height := maxi(1, y1 - y0)
	var band_y := y0 + int(fmod(_surface_clock(surface) * speed * 20.0, float(height)))
	surface.draw_rect(Rect2(x0, band_y, x1 - x0, 2), Color(color.r, color.g, color.b, alpha))
	surface.draw_rect(Rect2(x0, y0 + int(fmod(float(band_y - y0 + 19), float(height))), x1 - x0, 1), Color(color.r, color.g, color.b, alpha * 0.55))


func _draw_surface_light_cone(surface, origin: Vector2, fall: Vector2, color: Color, alpha: float) -> void:
	surface.draw_polygon([
		origin + Vector2(-36, 0),
		origin + Vector2(36, 0),
		origin + Vector2(fall.x, fall.y),
		origin + Vector2(-fall.x, fall.y),
	], [Color(color.r, color.g, color.b, alpha)])


func _draw_security_mirror(surface, rect: Rect2, accent: Color) -> void:
	surface.draw_rect(rect, Color("#05060a"))
	surface.draw_rect(Rect2(rect.position + Vector2(8, 8), rect.size - Vector2(16, 16)), Color("#111421"))
	surface.draw_rect(Rect2(rect.position + Vector2(16, 15), Vector2(rect.size.x - 32, 3)), Color(accent.r, accent.g, accent.b, 0.42))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.28), false, 1)


func _draw_watch_camera_surface(surface, pos: Vector2, accent: Color) -> void:
	surface.draw_rect(Rect2(pos + Vector2(-20, -10), Vector2(40, 20)), Color("#05060a"))
	surface.draw_rect(Rect2(pos + Vector2(-8, -5), Vector2(16, 10)), C_DARK_2)
	surface.draw_rect(Rect2(pos + Vector2(-3, -3), Vector2(6, 6)), accent)
	surface.draw_line(pos + Vector2(0, 8), Vector2(492, 190), Color(accent.r, accent.g, accent.b, 0.12), 1)


func _draw_betting_arc(surface, center: Vector2, width: float, accent: Color) -> void:
	for i in range(9):
		var x := center.x - width * 0.5 + float(i) * width / 8.0
		var y := center.y - absf(float(i) - 4.0) * 3.5
		surface.draw_rect(Rect2(x - 1, y - 1, 2, 2), Color(accent.r, accent.g, accent.b, 0.30))


func _draw_seat_marker(surface, pos: Vector2, label: String, active: bool) -> void:
	var color := C_TEAL if active else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.32)
	surface.draw_rect(Rect2(pos + Vector2(-16, -18), Vector2(40, 5)), Color(color.r, color.g, color.b, 0.20))
	surface.draw_rect(Rect2(pos + Vector2(-12, -28), Vector2(32, 20)), Color(color.r, color.g, color.b, 0.06), false, 1)
	surface.surface_label_centered(label, Rect2(pos + Vector2(-11, -25), Vector2(30, 12)), 8, color)


func _draw_status_meter(surface, rect: Rect2, value: int, label: String, accent: Color) -> void:
	var clamped := clampi(value, 0, 100)
	surface.draw_rect(rect, Color("#080a12"))
	surface.draw_rect(Rect2(rect.position, Vector2(rect.size.x * float(clamped) / 100.0, rect.size.y)), accent)
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.22), false, 1)
	surface.surface_label(label.left(26), rect.position + Vector2(0, -4), 9, accent)


func _draw_discard_tray(surface, pos: Vector2, surface_state: Dictionary) -> void:
	surface.draw_rect(Rect2(pos, Vector2(62, 36)), Color("#080a12"))
	surface.draw_rect(Rect2(pos + Vector2(6, 5), Vector2(50, 26)), Color("#171022"))
	surface.draw_rect(Rect2(pos, Vector2(62, 36)), Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.22), false, 1)
	var result: Dictionary = _local_copy_dict(surface_state.get("last_result", {}))
	var cards: Array = _card_array(result.get("dealer_cards", []))
	for i in range(mini(cards.size(), 4)):
		_draw_card(surface, cards[i], pos + Vector2(8 + i * 8, 7 + i * 2), 0.24)


func _draw_table_character(surface, style: Dictionary, foot: Vector2, scale_value: float, clock: float) -> void:
	var accent: Color = style.get("accent", C_CYAN) if typeof(style.get("accent", C_CYAN)) == TYPE_COLOR else C_CYAN
	var skin: Color = style.get("skin", Color("#c49371")) if typeof(style.get("skin", Color("#c49371"))) == TYPE_COLOR else Color("#c49371")
	var hair: Color = style.get("hair", Color("#171022")) if typeof(style.get("hair", Color("#171022"))) == TYPE_COLOR else Color("#171022")
	var jacket: Color = style.get("jacket", Color("#1d2030")) if typeof(style.get("jacket", Color("#1d2030"))) == TYPE_COLOR else Color("#1d2030")
	var pose := str(style.get("pose", "idle"))
	var sway := sin(clock * 1.8) * 2.0 * scale_value
	var lean := 4.0 * scale_value if pose == "snitch" else -4.0 * scale_value if pose == "covered" or pose == "lookaway" else 0.0
	var pos := foot + Vector2(sway + lean, 0)
	var head := Rect2(pos + Vector2(-12, -78) * scale_value, Vector2(24, 24) * scale_value)
	var body := Rect2(pos + Vector2(-23, -54) * scale_value, Vector2(46, 52) * scale_value)
	surface.draw_rect(Rect2(pos.x - 25 * scale_value, pos.y - 6 * scale_value, 50 * scale_value, 5 * scale_value), Color(0, 0, 0, 0.34))
	surface.draw_rect(body, Color("#05060a"))
	surface.draw_rect(Rect2(body.position + Vector2(4, 5) * scale_value, body.size - Vector2(8, 9) * scale_value), jacket)
	surface.draw_rect(Rect2(pos + Vector2(-18, -56) * scale_value, Vector2(36, 6) * scale_value), accent)
	_draw_character_arm(surface, pos, scale_value, accent, pose, true)
	_draw_character_arm(surface, pos, scale_value, accent, pose, false)
	surface.draw_rect(head, skin)
	surface.draw_rect(Rect2(head.position, Vector2(head.size.x, 8 * scale_value)), hair)
	_draw_character_face(surface, head, scale_value, float(style.get("eye_offset", 0.0)), bool(style.get("blink", false)), pose)
	if str(style.get("silhouette", "")) == "cap":
		surface.draw_rect(Rect2(head.position + Vector2(-3, -3) * scale_value, Vector2(head.size.x + 8 * scale_value, 5 * scale_value)), hair)
	elif str(style.get("silhouette", "")) == "glasses":
		surface.draw_rect(Rect2(head.position + Vector2(4, 10) * scale_value, Vector2(6, 4) * scale_value), Color("#05060a"), false, 1)
		surface.draw_rect(Rect2(head.position + Vector2(14, 10) * scale_value, Vector2(6, 4) * scale_value), Color("#05060a"), false, 1)
	elif str(style.get("silhouette", "")) == "rings":
		surface.draw_rect(Rect2(pos + Vector2(-30, -22) * scale_value, Vector2(6, 4) * scale_value), C_YELLOW)
	if bool(style.get("holding_card", false)):
		_draw_card(surface, {"rank": 2, "suit": 0, "hidden": true}, pos + Vector2(-34, -35) * scale_value, 0.28 * scale_value)
	var name := str(style.get("name", ""))
	if not name.is_empty():
		surface.surface_label(name.left(10), pos + Vector2(-26, 10) * scale_value, int(10 * scale_value), accent)


func _draw_character_arm(surface, pos: Vector2, scale_value: float, accent: Color, pose: String, left: bool) -> void:
	var side := -1.0 if left else 1.0
	var shoulder := pos + Vector2(side * 24, -45) * scale_value
	var hand := pos + Vector2(side * 42, -22) * scale_value
	if pose == "snitch":
		hand = pos + Vector2(side * 34, -58) * scale_value
	elif pose == "covered":
		hand = pos + Vector2(side * 22, -28) * scale_value
	elif pose == "lookaway":
		hand = pos + Vector2(side * 36, -30) * scale_value
	elif pose == "watching" and left:
		hand = pos + Vector2(side * 30, -18) * scale_value
	surface.draw_line(shoulder, hand, Color("#05060a"), maxf(2.0, 6.0 * scale_value))
	surface.draw_line(shoulder, hand, Color(accent.r, accent.g, accent.b, 0.42), maxf(1.0, 2.0 * scale_value))
	surface.draw_rect(Rect2(hand + Vector2(-3, -2) * scale_value, Vector2(6, 6) * scale_value), Color("#c49371"))


func _draw_character_face(surface, head: Rect2, scale_value: float, eye_offset: float, blink: bool, pose: String) -> void:
	var eye_y := head.position.y + 12 * scale_value
	var left_eye := head.position + Vector2(6 + eye_offset, 12) * scale_value
	var right_eye := head.position + Vector2(16 + eye_offset, 12) * scale_value
	if blink:
		surface.draw_rect(Rect2(left_eye, Vector2(5, 1) * scale_value), Color("#05060a"))
		surface.draw_rect(Rect2(right_eye, Vector2(5, 1) * scale_value), Color("#05060a"))
	else:
		surface.draw_rect(Rect2(left_eye, Vector2(4, 3) * scale_value), Color("#05060a"))
		surface.draw_rect(Rect2(right_eye, Vector2(4, 3) * scale_value), Color("#05060a"))
	var mouth_color := C_PINK if pose == "snitch" else Color("#3a1830")
	surface.draw_rect(Rect2(head.position.x + 8 * scale_value, eye_y + 8 * scale_value, 8 * scale_value, 2 * scale_value), mouth_color)


func _patron_hair_color(patron: Dictionary) -> Color:
	match str(patron.get("silhouette", "coat")):
		"cap":
			return Color("#2d1a28")
		"rings":
			return Color("#513315")
		"glasses":
			return Color("#08090e")
		_:
			return Color("#2b1630")


func _patron_jacket_color(patron: Dictionary) -> Color:
	match str(patron.get("seat_style", "open")):
		"vest":
			return Color("#262033")
		"jacket":
			return Color("#27333b")
		_:
			return Color("#1d2030")


func _draw_blackjack_result_board(surface, surface_state: Dictionary) -> void:
	var result: Dictionary = _local_copy_dict(surface_state.get("last_result", {}))
	var rect := Rect2(646, 12, 232, 74)
	if result.is_empty():
		_draw_neon_panel(surface, rect, C_CYAN, 0.10)
		surface.surface_label("TABLE READ", rect.position + Vector2(10, 18), 12, C_CYAN)
		surface.surface_label("eyes + snitches", rect.position + Vector2(10, 36), 9, C_SOFT)
		return
	var delta := int(result.get("bankroll_delta", 0))
	var heat := int(result.get("suspicion_delta", 0))
	var accent := C_TEAL if delta > 0 else C_ORANGE if delta < 0 else C_YELLOW
	if bool(result.get("caught", false)):
		accent = C_PINK
	_draw_neon_panel(surface, rect, accent, 0.22)
	surface.surface_label(str(result.get("headline", "RESULT")).left(18), rect.position + Vector2(10, 18), 12, accent)
	surface.surface_label("$%+d" % delta, rect.position + Vector2(10, 38), 12, C_TEAL if delta >= 0 else C_ORANGE)
	surface.surface_label("heat %+d" % heat, rect.position + Vector2(128, 38), 9, C_PINK if heat > 0 else C_SOFT)
	var dealer_total := int(result.get("dealer_total", 0))
	var hand_results: Array = _dictionary_array(result.get("hand_results", []))
	var hand_bits: Array = []
	for i in range(mini(hand_results.size(), 4)):
		var hand_result: Dictionary = hand_results[i]
		hand_bits.append("H%d %d %s" % [i + 1, int(hand_result.get("player_total", 0)), str(hand_result.get("outcome", "push")).replace("_", " ").left(8)])
	var compare := "Dealer %d" % dealer_total
	if not hand_bits.is_empty():
		compare += " vs %s" % " / ".join(hand_bits)
	var side_line := _side_bet_result_line(_dictionary_array(result.get("side_bet_results", [])))
	if not side_line.is_empty():
		compare = side_line
	surface.surface_label(compare.left(38), rect.position + Vector2(10, 58), 8, C_SOFT)


func _side_bet_result_line(side_results: Array) -> String:
	if side_results.is_empty():
		return ""
	var parts: Array = []
	var net_delta := 0
	for side_value in side_results:
		if typeof(side_value) != TYPE_DICTIONARY:
			continue
		var side: Dictionary = side_value
		var label := str(side.get("label", side.get("id", "Side"))).left(12)
		var delta := int(side.get("bankroll_delta", 0))
		net_delta += delta
		var detail := str(side.get("detail", "miss")).replace("_", " ").left(12)
		parts.append("%s %s %+d" % [label, detail, delta])
	if parts.is_empty():
		return ""
	return "Side %+d: %s" % [net_delta, " / ".join(parts).left(25)]


func _draw_shoe(surface, pos: Vector2, remaining: int) -> void:
	surface.draw_rect(Rect2(pos, Vector2(78, 46)), Color("#1b1d28"))
	surface.draw_rect(Rect2(pos + Vector2(8, 6), Vector2(62, 34)), Color("#0a0c14"))
	for i in range(4):
		surface.draw_rect(Rect2(pos + Vector2(12 + i * 4, 10 + i * 2), Vector2(42, 24)), Color("#f4ead5"))
	surface.draw_rect(Rect2(pos, Vector2(78, 46)), C_CYAN, false, 1)
	surface.surface_label("SHOE %d" % remaining, pos + Vector2(6, 60), 10, C_SOFT)


func _draw_table_button(surface, rect: Rect2, label: String, action: String, index: int, accent: Color, enabled: bool = true, selected: bool = false) -> void:
	var hovered: bool = bool(surface.surface_region_hovered(action, index))
	var fill := Color(accent.r, accent.g, accent.b, 0.26 if selected else 0.18 if hovered else 0.10)
	if not enabled:
		fill = Color(0.03, 0.03, 0.06, 0.72)
	surface.draw_rect(rect, fill)
	surface.draw_rect(rect, C_WHITE if hovered and enabled else accent if enabled else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.30), false, 2 if hovered or selected else 1)
	surface.surface_label_centered(label.left(16), rect.grow(-3), 11, accent if enabled else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.46))
	if selected:
		surface.surface_draw_ready_badge(rect, "READY")
	if enabled:
		surface.surface_add_exact_hit(rect, action, index)


func _draw_chip_button(surface, center: Vector2, value: int, action: String, index: int) -> void:
	var hovered := bool(surface.surface_region_hovered(action, index))
	_draw_casino_chip(surface, center, value, 17.0, 1.0, hovered)
	surface.surface_add_hit(Rect2(center - Vector2(18, 18), Vector2(36, 36)), action, index)


func _draw_chip_stack(surface, pos: Vector2, stack_value: Variant, scale: float = 1.0) -> void:
	var stack: Array = _dictionary_array(stack_value)
	var y := 0.0
	for entry_value in stack:
		var entry: Dictionary = entry_value
		var value := int(entry.get("value", 1))
		var count := clampi(int(entry.get("count", 1)), 1, 8)
		for i in range(count):
			var chip_pos := pos + Vector2(0, y - float(i) * 3.0 * scale)
			_draw_casino_chip(surface, chip_pos, value, 11.0 * scale, 0.92, false)
		y -= float(count + 1) * 3.0 * scale


func _draw_casino_chip(surface, center: Vector2, value: int, radius: float, alpha: float = 1.0, selected: bool = false) -> void:
	var color := _chip_color(value)
	var rim := C_WHITE if selected else Color("#f7f1d0")
	surface.draw_circle(center + Vector2(2, 3), radius, Color(0, 0, 0, 0.28 * alpha))
	surface.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.95 * alpha))
	surface.draw_circle(center, radius * 0.78, Color(rim.r, rim.g, rim.b, 0.86 * alpha), false, maxf(1.0, radius * 0.12))
	for i in range(12):
		var angle := (float(i) / 12.0) * PI * 2.0
		var dir := Vector2(cos(angle), sin(angle))
		var p0 := center + dir * radius * 0.70
		var p1 := center + dir * radius * 0.98
		surface.draw_line(p0, p1, Color(rim.r, rim.g, rim.b, 0.88 * alpha), maxf(1.0, radius * 0.10))
	surface.draw_circle(center, radius * 0.50, Color("#101018"))
	surface.draw_circle(center, radius * 0.50, Color(color.r, color.g, color.b, 0.42 * alpha), false, maxf(1.0, radius * 0.08))
	if radius >= 8.0:
		var label_size := clampi(int(radius * 0.58), 6, 11)
		surface.surface_label_centered("$%d" % value, Rect2(center - Vector2(radius * 0.62, radius * 0.34), Vector2(radius * 1.24, radius * 0.68)), label_size, C_WHITE)


func _chip_color(value: int) -> Color:
	if value >= 25:
		return C_PINK_2
	if value >= 10:
		return C_TEAL
	if value >= 5:
		return C_YELLOW
	return C_WHITE


func _patron_seat_position(index: int) -> Vector2:
	var positions: Array = [Vector2(128, 176), Vector2(272, 130), Vector2(628, 130), Vector2(772, 176)]
	return positions[clampi(index, 0, positions.size() - 1)]


func _draw_count_challenge(surface, surface_state: Dictionary) -> void:
	var challenge: Dictionary = _local_copy_dict(surface_state.get("count_challenge", {}))
	if challenge.is_empty():
		return
	var now_msec := Time.get_ticks_msec()
	var icons: Array = _dictionary_array(challenge.get("icons", []))
	var clicked: Array = _string_array(challenge.get("clicked_icons", []))
	var missed: Array = _count_missed_icon_ids(challenge, now_msec)
	var current_delta := int(surface_state.get("count_delta", int(challenge.get("recorded_delta", 0))))
	var badge := Rect2(620, 74, 150, 30)
	surface.draw_rect(badge, Color(0.02, 0.025, 0.045, 0.72))
	surface.draw_rect(badge, Color(C_PINK_2.r, C_PINK_2.g, C_PINK_2.b, 0.34), false, 1)
	surface.surface_label("COUNT %+d" % current_delta, badge.position + Vector2(12, 20), 14, C_YELLOW)
	if not missed.is_empty() or int(challenge.get("bad_hits", 0)) > 0:
		surface.surface_label("MISS %d / BAD %d" % [missed.size(), int(challenge.get("bad_hits", 0))], badge.position + Vector2(90, 19), 8, C_ORANGE)
	var resolved_times: Dictionary = _local_copy_dict(challenge.get("resolved_icon_msec", {}))
	for i in range(icons.size()):
		var icon: Dictionary = icons[i]
		var icon_id := str(icon.get("id", "icon_%d" % i))
		var spawn := int(icon.get("spawn_msec", int(challenge.get("started_msec", now_msec))))
		var duration := int(icon.get("duration_msec", COUNT_ICON_DURATION_MSEC))
		var age := now_msec - spawn
		var clicked_icon := clicked.has(icon_id)
		var missed_icon := missed.has(icon_id)
		var active := age >= 0 and age <= duration and not clicked_icon and not missed_icon and not bool(surface_state.get("count_answered", false))
		var preview := age < 0 and age >= -360
		var fade_elapsed := -1
		if clicked_icon or missed_icon:
			fade_elapsed = now_msec - int(resolved_times.get(icon_id, spawn + duration))
		var fading := (clicked_icon or missed_icon) and fade_elapsed >= 0 and fade_elapsed <= COUNT_ICON_FADE_MSEC
		if not active and not fading and not preview:
			continue
		var phase := clampf(float(age) / float(maxi(1, duration)), 0.0, 1.0)
		var pos := Vector2(float(icon.get("x", 320.0)), float(icon.get("y", 164.0)))
		pos += Vector2(0, sin((float(now_msec - spawn) / 360.0) + float(i)) * 4.0)
		var value := int(icon.get("count_value", 0))
		var accent := C_TEAL if value > 0 else C_PINK_2 if value < 0 else C_SOFT
		var alpha := 0.28 if preview else 0.95 - phase * 0.42
		if clicked_icon:
			accent = C_YELLOW
			alpha = 0.86 * (1.0 - float(fade_elapsed) / float(COUNT_ICON_FADE_MSEC))
		elif missed_icon:
			accent = C_ORANGE
			alpha = 0.62 * (1.0 - float(fade_elapsed) / float(COUNT_ICON_FADE_MSEC))
		_draw_count_pulse_icon(surface, pos, value, accent, alpha, clicked_icon, missed_icon)
		if active:
			surface.surface_add_exact_hit(Rect2(pos - Vector2(22, 22), Vector2(44, 44)), "blackjack_count_icon", i)


func _draw_count_pulse_icon(surface, center: Vector2, value: int, accent: Color, alpha: float, clicked: bool, missed: bool) -> void:
	var radius := 18.0
	surface.draw_circle(center + Vector2(2, 3), radius + 2.0, Color(0, 0, 0, 0.28 * alpha))
	surface.draw_circle(center, radius, Color(accent.r, accent.g, accent.b, 0.26 * alpha))
	surface.draw_circle(center, radius, Color(accent.r, accent.g, accent.b, 0.88 * alpha), false, 2)
	var label := "+1" if value > 0 else "-1" if value < 0 else "0"
	surface.surface_label_centered(label, Rect2(center - Vector2(17, 9), Vector2(34, 18)), 13, C_WHITE)
	if clicked:
		surface.surface_label_centered("HIT", Rect2(center - Vector2(18, 22), Vector2(36, 10)), 7, C_YELLOW)
	elif missed:
		surface.surface_label_centered("MISS", Rect2(center - Vector2(20, 22), Vector2(40, 10)), 7, C_ORANGE)


func _table_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var table: Dictionary = game_states.get(get_id(), {}) if typeof(game_states.get(get_id(), {})) == TYPE_DICTIONARY else {}
	if table.is_empty():
		table = _fallback_table_state(run_state, environment)
	return _normalize_table_state(table)


func _fallback_table_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var rng := RngStream.new()
	rng.configure(_stable_hash("%s:%s:%s" % [get_id(), str(run_state.seed_text if run_state != null else "fallback"), str(environment.get("id", ""))]))
	return generate_environment_state(run_state, environment, rng)


func _generate_dealer_profile(rng: RngStream, catch_base: int) -> Dictionary:
	var tells: Array = [
		"checks the discard tray",
		"watches hands more than faces",
		"glances at the pit boss",
		"protects the hole card with one thumb",
	]
	var read_styles: Array = ["slow sweep", "sharp eye flick", "tray check", "chip count", "pit glance"]
	return {
		"posture": str(rng.pick(["upright", "leaning", "quiet", "sharp"], "upright")),
		"tell": str(rng.pick(tells, tells[0])),
		"attention_base": clampi(catch_base + rng.randi_range(4, 18), 10, 60),
		"patience": rng.randi_range(2, 5),
		"uniform_accent": str(rng.pick(["cyan tie", "pink cuffs", "gold pin", "black vest"], "cyan tie")),
		"read_style": str(rng.pick(read_styles, read_styles[0])),
		"gaze_speed": rng.randi_range(70, 135),
		"blink_offset": rng.randi_range(0, 2600),
		"strategy_scrutiny": rng.randi_range(8, 16),
		"strategy_threshold": rng.randi_range(3, 5),
		"strategy_response": str(rng.pick(["watch", "heat", "both"], "watch")),
	}


func _generate_table_patrons(rng: RngStream, depth: int) -> Array:
	var names: Array = ["Nix", "Sal", "Dove", "Milo", "Anika", "Trent", "June", "Vale"]
	var moods: Array = ["chatty", "quiet", "suspicious", "tilted", "friendly"]
	var styles: Array = ["flat_main", "side_action", "big_stack", "minimum"]
	var chip_colors: Array = ["cyan", "teal", "yellow", "pink", "orange"]
	var tells: Array = ["leans in", "side eye", "chip stare", "phone glance", "drink sip", "soft nod"]
	var count: int = rng.randi_range(1, clampi(2 + depth, 2, 4))
	var picked_names: Array = rng.pick_many(names, count)
	var patrons: Array = []
	for i in range(count):
		var mood := str(rng.pick(moods, "quiet"))
		var snitch_risk := rng.randi_range(8, 28)
		if mood == "suspicious":
			snitch_risk += 14
		elif mood == "friendly" or mood == "chatty":
			snitch_risk -= 5
		patrons.append({
			"id": "patron_%d" % i,
			"name": str(picked_names[i] if i < picked_names.size() else "Patron"),
			"seat": i,
			"mood": mood,
			"bet_style": str(rng.pick(styles, styles[0])),
			"cosmetic_bet": int(rng.pick([5, 10, 15, 25, 40], 10)),
			"rapport": rng.randi_range(42, 62),
			"chip_color": str(chip_colors[i % chip_colors.size()]),
			"snitch_risk": clampi(snitch_risk, 4, 46),
			"chip_stack": rng.randi_range(12, 90),
			"watching": rng.randi_range(0, 100) >= 32,
			"silhouette": str(rng.pick(["cap", "glasses", "coat", "rings"], "coat")),
			"tell": str(rng.pick(tells, tells[0])),
			"temper": str(rng.pick(["nosy", "careless", "loyal", "sharp"], "careless")),
			"seat_style": str(rng.pick(["vest", "jacket", "open"], "open")),
			"animation_offset": rng.randi_range(0, 3600),
			"snitch_threshold": rng.randi_range(18, 52),
		})
	return patrons


func _generate_table_distractions(rng: RngStream) -> Array:
	var catalog: Array = [
		{"id": "chip_spill", "label": "Chip Spill", "summary": "short window; patrons look down", "duration_msec": 2600, "cover": 10, "noise": 7},
		{"id": "payout_question", "label": "Payout Ask", "summary": "medium window; dealer checks felt", "duration_msec": 3400, "cover": 6, "noise": 4},
		{"id": "pit_glance", "label": "Pit Glance", "summary": "long window; higher table heat", "duration_msec": 4200, "cover": 4, "noise": 10},
		{"id": "drink_pass", "label": "Drink Pass", "summary": "covers patrons; brief dealer gap", "duration_msec": 3000, "cover": 16, "noise": 6},
	]
	return rng.pick_many(catalog, rng.randi_range(2, 3))


func _default_table_rng(table: Dictionary, suffix: String) -> RngStream:
	var rng := RngStream.new()
	rng.configure(_stable_hash("%s:%s:%s" % [get_id(), str(table.get("table_name", "blackjack")), suffix]))
	return rng


func _normalize_dealer_profile(value: Variant, table: Dictionary) -> Dictionary:
	var profile: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	if profile.is_empty():
		profile = _generate_dealer_profile(_default_table_rng(table, "dealer"), int(table.get("dealer_catch_base", 10)))
	profile["posture"] = str(profile.get("posture", "upright"))
	profile["tell"] = str(profile.get("tell", "watches hands more than faces"))
	profile["attention_base"] = clampi(int(profile.get("attention_base", int(table.get("dealer_catch_base", 10)) + 12)), 8, 70)
	profile["patience"] = clampi(int(profile.get("patience", 3)), 1, 6)
	profile["uniform_accent"] = str(profile.get("uniform_accent", "cyan tie"))
	profile["read_style"] = str(profile.get("read_style", "slow sweep"))
	profile["gaze_speed"] = clampi(int(profile.get("gaze_speed", 95)), 45, 180)
	profile["blink_offset"] = maxi(0, int(profile.get("blink_offset", 0)))
	profile["strategy_scrutiny"] = clampi(int(profile.get("strategy_scrutiny", 10)), 0, 30)
	profile["strategy_threshold"] = clampi(int(profile.get("strategy_threshold", 4)), 1, 8)
	var strategy_response := str(profile.get("strategy_response", "watch"))
	if not ["watch", "heat", "both"].has(strategy_response):
		strategy_response = "watch"
	profile["strategy_response"] = strategy_response
	return profile


func _normalize_distractions(value: Variant, table: Dictionary) -> Array:
	var distractions: Array = _dictionary_array(value)
	if distractions.is_empty():
		distractions = _generate_table_distractions(_default_table_rng(table, "distractions"))
	var result: Array = []
	for distraction_value in distractions:
		var distraction: Dictionary = distraction_value
		var id := str(distraction.get("id", "distraction_%d" % result.size()))
		result.append({
			"id": id,
			"label": str(distraction.get("label", id.replace("_", " ").capitalize())),
			"summary": str(distraction.get("summary", "opens a peek window")),
			"duration_msec": clampi(int(distraction.get("duration_msec", 3000)), 1200, 6000),
			"cover": clampi(int(distraction.get("cover", 8)), 0, 30),
			"noise": clampi(int(distraction.get("noise", 5)), 0, 30),
		})
	return result


func _normalize_patrons(value: Variant, table: Dictionary) -> Array:
	var patrons: Array = _dictionary_array(value)
	if patrons.is_empty() and not table.has("patrons"):
		patrons = _generate_table_patrons(_default_table_rng(table, "patrons"), 0)
	var result: Array = []
	for i in range(patrons.size()):
		var patron: Dictionary = patrons[i]
		var id := str(patron.get("id", "patron_%d" % i))
		result.append({
			"id": id,
			"name": str(patron.get("name", "Patron")),
			"seat": int(patron.get("seat", i)),
			"mood": str(patron.get("mood", "quiet")),
			"bet_style": str(patron.get("bet_style", "flat_main")),
			"cosmetic_bet": maxi(1, int(patron.get("cosmetic_bet", maxi(1, int(patron.get("chip_stack", 20)) / 3)))),
			"rapport": clampi(int(patron.get("rapport", 50)), 0, 100),
			"chip_color": str(patron.get("chip_color", "cyan")),
			"snitch_risk": clampi(int(patron.get("snitch_risk", 18)), 0, 60),
			"chip_stack": maxi(0, int(patron.get("chip_stack", 20))),
			"watching": bool(patron.get("watching", true)),
			"silhouette": str(patron.get("silhouette", "coat")),
			"tell": str(patron.get("tell", "leans in")),
			"temper": str(patron.get("temper", "careless")),
			"seat_style": str(patron.get("seat_style", "open")),
			"animation_offset": maxi(0, int(patron.get("animation_offset", i * 620))),
			"snitch_threshold": clampi(int(patron.get("snitch_threshold", 30)), 4, 70),
		})
	return result


func _chip_denominations(table: Dictionary) -> Array:
	var values: Array = []
	var source: Array = table.get("chip_denominations", []) if typeof(table.get("chip_denominations", [])) == TYPE_ARRAY else []
	for value in source:
		var chip_value := maxi(1, int(value))
		if not values.has(chip_value):
			values.append(chip_value)
	if values.is_empty():
		values = [1, 5, 10, 25]
	values.sort()
	return values


func _normalize_table_state(table: Dictionary) -> Dictionary:
	var normalized := table.duplicate(false)
	normalized["schema"] = str(normalized.get("schema", "blackjack_table_state"))
	normalized["version"] = maxi(2, int(normalized.get("version", 2)))
	normalized["deck_count"] = clampi(int(normalized.get("deck_count", 6)), 1, 8)
	var deck_count := int(normalized.get("deck_count", 6))
	var shoe: Array = []
	var shoe_value: Variant = normalized.get("shoe", [])
	if typeof(shoe_value) == TYPE_ARRAY:
		shoe = shoe_value as Array
	if shoe.is_empty():
		var rng := RngStream.new()
		rng.configure(_stable_hash(str(normalized.get("table_name", "blackjack"))))
		shoe = _build_shoe(deck_count, rng)
	normalized["shoe"] = shoe
	normalized["shoe_cursor"] = 0
	var total_cards := deck_count * CardShoeScript.CARDS_PER_DECK
	var default_cut_remaining := CardShoeScript.cut_card_remaining(deck_count)
	if not normalized.has("cut_card_remaining"):
		var cut_card_at := int(normalized.get("cut_card_at", total_cards - default_cut_remaining))
		normalized["cut_card_remaining"] = clampi(total_cards - cut_card_at, 1, total_cards)
	else:
		normalized["cut_card_remaining"] = clampi(int(normalized.get("cut_card_remaining", default_cut_remaining)), 1, total_cards)
	normalized["cut_card_at"] = total_cards - int(normalized.get("cut_card_remaining", default_cut_remaining))
	normalized["shoe_remaining"] = shoe.size()
	var composition: Dictionary = normalized.get("shoe_composition", {}) if typeof(normalized.get("shoe_composition", {})) == TYPE_DICTIONARY else {}
	if composition.is_empty() or int(composition.get("total", -1)) != shoe.size():
		composition = CardShoeScript.remaining_composition(shoe)
	normalized["shoe_composition"] = composition
	normalized["shoe_label"] = CardShoeScript.shoe_label(deck_count)
	normalized["count_efficiency"] = CardShoeScript.count_efficiency_label(deck_count)
	if typeof(normalized.get("rules", {})) != TYPE_DICTIONARY:
		normalized["rules"] = {}
	normalized["side_bets"] = _normalize_side_bets(normalized.get("side_bets", []))
	normalized["dealer_profile"] = _normalize_dealer_profile(normalized.get("dealer_profile", {}), normalized)
	normalized["patrons"] = _normalize_patrons(normalized.get("patrons", []), normalized)
	normalized["distractions"] = _normalize_distractions(normalized.get("distractions", []), normalized)
	normalized["chip_denominations"] = _chip_denominations(normalized)
	normalized["table_layout"] = str(normalized.get("table_layout", "immersive_blackjack"))
	normalized["running_count"] = int(normalized.get("running_count", 0))
	normalized["recorded_running_count"] = int(normalized.get("recorded_running_count", 0))
	normalized["counting_enabled"] = bool(normalized.get("counting_enabled", false))
	normalized["barred"] = bool(normalized.get("barred", false))
	normalized["barred_reason"] = str(normalized.get("barred_reason", ""))
	normalized["strategy_deviation_strikes"] = maxi(0, int(normalized.get("strategy_deviation_strikes", 0)))
	normalized["strategy_watch_pressure"] = clampi(int(normalized.get("strategy_watch_pressure", 0)), 0, STRATEGY_DEVIATION_MAX_WATCH)
	normalized["strategy_last_notice"] = str(normalized.get("strategy_last_notice", ""))
	normalized["table_round_timer_started_msec"] = int(normalized.get("table_round_timer_started_msec", 0))
	return normalized


func _normalized_session(run_state: RunState, environment: Dictionary, ui_state: Dictionary, table: Dictionary) -> Dictionary:
	var session: Dictionary = {}
	for key in ui_state.keys():
		session[str(key)] = ui_state[key]
	var hands: Array = _hand_array(session.get("player_hands", session.get("blackjack_hands", [])))
	var dealer_cards: Array = _card_array(session.get("dealer_cards", session.get("dealer", [])))
	var patron_hands: Array = _hand_array(session.get("patron_hands", []))
	var cards_consumed: int = int(session.get("cards_consumed", 0))
	var session_shoe: Array = []
	if typeof(session.get("shoe", [])) == TYPE_ARRAY:
		session_shoe = _card_array(session.get("shoe", []))
	session["player_hands"] = hands
	session["dealer_cards"] = dealer_cards
	session["patron_hands"] = patron_hands
	session["cards_consumed"] = cards_consumed
	if session_shoe.is_empty() and not bool(session.get("shoe_refilled_during_hand", false)):
		session.erase("shoe")
		session["shoe_remaining"] = _shoe_remaining_for_cursor(table, cards_consumed)
	else:
		session["shoe"] = session_shoe
		session["shoe_remaining"] = session_shoe.size()
	session["active_hand_index"] = clampi(int(session.get("active_hand_index", 0)), 0, maxi(0, hands.size() - 1))
	session["dealer_hole_visible"] = bool(session.get("dealer_hole_visible", false))
	var initial_player_cards: Array = _card_array(session.get("initial_player_cards", []))
	if initial_player_cards.is_empty() and not hands.is_empty():
		var opening_hand: Dictionary = hands[0]
		initial_player_cards = _first_cards(_card_array(opening_hand.get("cards", [])), 2)
	var initial_dealer_cards: Array = _card_array(session.get("initial_dealer_cards", []))
	if initial_dealer_cards.is_empty():
		initial_dealer_cards = _first_cards(dealer_cards, 2)
	session["initial_player_cards"] = initial_player_cards
	session["initial_dealer_cards"] = initial_dealer_cards
	session["blackjack_side_bets"] = _valid_side_bet_ids_for_session(_string_array(session.get("blackjack_side_bets", session.get("side_bets", []))), table, session)
	if typeof(session.get("cheats_used", {})) != TYPE_DICTIONARY:
		session["cheats_used"] = {}
	if typeof(session.get("count_challenge", {})) != TYPE_DICTIONARY:
		session["count_challenge"] = {}
	if typeof(session.get("strategy_deviation_events", [])) != TYPE_ARRAY:
		session["strategy_deviation_events"] = []
	session["strategy_deviation_score"] = maxi(0, int(session.get("strategy_deviation_score", 0)))
	session["strategy_attention_boost"] = clampi(int(session.get("strategy_attention_boost", 0)), 0, STRATEGY_DEVIATION_MAX_WATCH)
	session["strategy_confronted"] = bool(session.get("strategy_confronted", false))
	session["strategy_confrontation_heat"] = maxi(0, int(session.get("strategy_confrontation_heat", 0)))
	session["counting_enabled"] = bool(session.get("counting_enabled", table.get("counting_enabled", false)))
	if typeof(session.get("patron_cover", {})) != TYPE_DICTIONARY:
		session["patron_cover"] = {}
	session["dealer_lookaway_started_msec"] = int(session.get("dealer_lookaway_started_msec", 0))
	session["dealer_lookaway_duration_msec"] = int(session.get("dealer_lookaway_duration_msec", 0))
	session["dealer_lookaway_id"] = str(session.get("dealer_lookaway_id", ""))
	session["dealer_distraction_id"] = str(session.get("dealer_distraction_id", ""))
	session["dealer_distraction_noise"] = int(session.get("dealer_distraction_noise", 0))
	session["blackjack_sit_out"] = bool(session.get("blackjack_sit_out", false))
	if session.has("locked_stake"):
		session["locked_stake"] = maxi(1, int(session.get("locked_stake", 1)))
	if session.has("selected_stake"):
		session["selected_stake"] = maxi(1, int(session.get("selected_stake", 1)))
	if not session.has("session_id"):
		session["session_id"] = "%s:%s:%d" % [get_id(), str(environment.get("id", "")), int(table.get("hands_played", 0))]
	return session


func _initial_deal(session: Dictionary, table: Dictionary) -> Dictionary:
	var opening_cards: Array = _draw_cards_from_session(session, table, 4)
	while opening_cards.size() < 4:
		opening_cards.append({"rank": 2, "suit": opening_cards.size() % 4, "deck": 0})
	var player_cards: Array = [opening_cards[0], opening_cards[2]]
	var dealer_cards: Array = [opening_cards[1], opening_cards[3]]
	var patron_hands: Array = []
	var patrons: Array = _dictionary_array(table.get("patrons", []))
	for i in range(patrons.size()):
		var patron: Dictionary = patrons[i]
		var cards: Array = _draw_cards_from_session(session, table, 2)
		patron_hands.append({
			"patron_id": str(patron.get("id", "patron_%d" % i)),
			"name": str(patron.get("name", "Patron")),
			"seat": int(patron.get("seat", i)),
			"temper": str(patron.get("temper", "careless")),
			"cards": cards,
			"wager_multiplier": 1,
			"stood": false,
			"doubled": false,
			"split": false,
			"blackjack_eligible": false,
			"terminal_reason": "",
		})
	return {
		"player_hands": [{
			"cards": player_cards,
			"wager_multiplier": 1,
			"stood": false,
			"doubled": false,
			"split": false,
			"blackjack_eligible": true,
		}],
		"dealer_cards": dealer_cards,
		"patron_hands": patron_hands,
		"cards_consumed": int(session.get("cards_consumed", 0)),
	}


func _has_dealt_hand(session: Dictionary) -> bool:
	return not _hand_array(session.get("player_hands", [])).is_empty() and not _card_array(session.get("dealer_cards", [])).is_empty()


func _start_initial_hand(session: Dictionary, table: Dictionary, stake: int = 1, run_state: RunState = null) -> void:
	if _has_dealt_hand(session):
		return
	session.erase("shoe")
	session["cards_consumed"] = 0
	session["shoe_emergency_shuffle_count"] = 0
	session["shoe_refilled_during_hand"] = false
	var initial: Dictionary = _initial_deal(session, table)
	var hands: Array = _hand_array(initial.get("player_hands", []))
	var dealer_cards: Array = _card_array(initial.get("dealer_cards", []))
	var patron_hands: Array = _hand_array(initial.get("patron_hands", []))
	session["player_hands"] = hands
	session["dealer_cards"] = dealer_cards
	session["patron_hands"] = patron_hands
	session["patron_action_events"] = []
	session["settlement_deal_animation_events"] = []
	session["cards_consumed"] = int(initial.get("cards_consumed", 4))
	session.erase("shoe")
	session["shoe_remaining"] = _shoe_remaining_for_cursor(table, int(session.get("cards_consumed", 0)))
	session["active_hand_index"] = 0
	session["moves_made"] = false
	session["locked_stake"] = maxi(1, stake)
	session["selected_stake"] = maxi(1, stake)
	if not hands.is_empty():
		var opening_hand: Dictionary = hands[0]
		session["initial_player_cards"] = _first_cards(_card_array(opening_hand.get("cards", [])), 2)
	session["initial_dealer_cards"] = _first_cards(dealer_cards, 2)
	_mark_deal_animation(session, "initial", _initial_deal_animation_events(hands, dealer_cards, patron_hands))
	if bool(table.get("counting_enabled", false)):
		_start_count_challenge(session, table, run_state)


func _draw_card_from_session(session: Dictionary, table: Dictionary) -> Dictionary:
	var cards: Array = _draw_cards_from_session(session, table, 1)
	if cards.is_empty():
		return {"rank": 2, "suit": 0, "deck": 0}
	return (cards[0] as Dictionary).duplicate(true)


func _draw_cards_from_session(session: Dictionary, table: Dictionary, count: int) -> Array:
	var drawn: Array = []
	var target_count := maxi(0, count)
	if _draw_cards_from_table_cursor(session, table, target_count, drawn):
		return drawn
	while drawn.size() < target_count:
		var shoe: Array = _card_array(session.get("shoe", []))
		if shoe.is_empty():
			_refill_session_shoe(session, table)
			shoe = _card_array(session.get("shoe", []))
			if shoe.is_empty():
				break
		var draw_result: Dictionary = CardShoeScript.draw_cards(shoe, target_count - drawn.size())
		var draw_cards: Array = _card_array(draw_result.get("cards", []))
		drawn.append_array(draw_cards)
		session["shoe"] = _card_array(draw_result.get("shoe", []))
		session["cards_consumed"] = int(session.get("cards_consumed", 0)) + draw_cards.size()
		session["shoe_remaining"] = CardShoeScript.remaining_count(session.get("shoe", []))
		if draw_cards.is_empty():
			break
	return drawn


func _draw_cards_from_table_cursor(session: Dictionary, table: Dictionary, target_count: int, drawn: Array) -> bool:
	if bool(session.get("shoe_refilled_during_hand", false)):
		return false
	if typeof(session.get("shoe", [])) == TYPE_ARRAY and not (session.get("shoe", []) as Array).is_empty():
		return false
	var table_shoe_value: Variant = table.get("shoe", [])
	if typeof(table_shoe_value) != TYPE_ARRAY:
		return false
	var table_shoe: Array = table_shoe_value as Array
	var cursor: int = clampi(int(session.get("cards_consumed", 0)), 0, table_shoe.size())
	while drawn.size() < target_count and cursor < table_shoe.size():
		var card_value: Variant = table_shoe[cursor]
		cursor += 1
		if typeof(card_value) == TYPE_DICTIONARY:
			drawn.append((card_value as Dictionary).duplicate(true))
	session["cards_consumed"] = cursor
	session["shoe_remaining"] = maxi(0, table_shoe.size() - cursor)
	return drawn.size() >= target_count


func _refill_session_shoe(session: Dictionary, table: Dictionary) -> void:
	var refill_index := int(session.get("shoe_emergency_shuffle_count", 0)) + 1
	var rng := RngStream.new()
	rng.configure(_stable_hash("%s:%s:%d:%d" % [
		str(table.get("table_name", "blackjack")),
		str(session.get("session_id", "")),
		int(table.get("hands_played", 0)),
		refill_index,
	]))
	session["shoe"] = _build_shoe(int(table.get("deck_count", 6)), rng)
	session["shoe_remaining"] = CardShoeScript.remaining_count(session.get("shoe", []))
	session["shoe_emergency_shuffle_count"] = refill_index
	session["shoe_refilled_during_hand"] = true


func _shoe_remaining_for_cursor(table: Dictionary, cards_consumed: int) -> int:
	var table_shoe_value: Variant = table.get("shoe", [])
	if typeof(table_shoe_value) != TYPE_ARRAY:
		return 0
	var table_shoe: Array = table_shoe_value as Array
	return maxi(0, table_shoe.size() - clampi(cards_consumed, 0, table_shoe.size()))


func _remaining_shoe_after_session(table: Dictionary, session: Dictionary) -> Array:
	var session_shoe: Array = _card_array(session.get("shoe", []))
	if not session_shoe.is_empty() or bool(session.get("shoe_refilled_during_hand", false)):
		return session_shoe
	var table_shoe_value: Variant = table.get("shoe", [])
	var remaining: Array = []
	if typeof(table_shoe_value) != TYPE_ARRAY:
		return remaining
	var table_shoe: Array = table_shoe_value as Array
	var cursor: int = clampi(int(session.get("cards_consumed", 0)), 0, table_shoe.size())
	for i in range(cursor, table_shoe.size()):
		var card_value: Variant = table_shoe[i]
		if typeof(card_value) == TYPE_DICTIONARY:
			remaining.append((card_value as Dictionary).duplicate(true))
	return remaining


func _compact_session_for_ui(ui_state: Dictionary) -> Dictionary:
	if not bool(ui_state.get("shoe_refilled_during_hand", false)):
		ui_state.erase("shoe")
		if ui_state.has("cards_consumed"):
			ui_state["shoe_remaining"] = maxi(0, int(ui_state.get("shoe_remaining", 0)))
	return ui_state


func _first_cards(cards: Array, count: int) -> Array:
	var result: Array = []
	var limit: int = mini(maxi(0, count), cards.size())
	for i in range(limit):
		if typeof(cards[i]) == TYPE_DICTIONARY:
			result.append((cards[i] as Dictionary).duplicate(true))
	return result


func _build_shoe(deck_count: int, rng: RngStream) -> Array:
	return CardShoeScript.build_shoe(deck_count, rng)


func _deal_animation_event_array(value: Variant) -> Array:
	var events: Array = []
	for event_value in _dictionary_array(value):
		var event: Dictionary = event_value
		event["zone"] = str(event.get("zone", "player"))
		event["hand_index"] = int(event.get("hand_index", 0))
		event["card_index"] = int(event.get("card_index", 0))
		event["delay_msec"] = maxi(0, int(event.get("delay_msec", 0)))
		event["duration_msec"] = maxi(80, int(event.get("duration_msec", DEAL_CARD_DURATION_MSEC)))
		event["scale"] = maxf(0.35, float(event.get("scale", 0.62)))
		event["card"] = _local_copy_dict(event.get("card", {}))
		event["from"] = _event_point(_event_vector(event.get("from", []), DEAL_CARD_SHOE_POS))
		event["to"] = _event_point(_event_vector(event.get("to", []), Vector2(454, 224)))
		event["label"] = str(event.get("label", "card"))
		events.append(event)
	return events


func _surface_deal_animation_events(surface_state: Dictionary) -> Array:
	var cached_value: Variant = surface_state.get(DRAW_DEAL_EVENTS_CACHE_KEY, [])
	if typeof(cached_value) == TYPE_ARRAY:
		var cached_events: Array = cached_value as Array
		return cached_events
	return _deal_animation_event_array(surface_state.get("deal_animation_events", []))


func _deal_animation_duration_msec(events: Array) -> int:
	var duration := 0
	for event_value in events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		duration = maxi(duration, int(event.get("delay_msec", 0)) + int(event.get("duration_msec", DEAL_CARD_DURATION_MSEC)) + 120)
	return duration


func _patron_action_event_array(value: Variant) -> Array:
	var events: Array = []
	for event_value in _dictionary_array(value):
		var event: Dictionary = event_value
		var action := str(event.get("action", "stand"))
		if not ["hit", "stand"].has(action):
			action = "stand"
		events.append({
			"patron_index": maxi(0, int(event.get("patron_index", 0))),
			"patron_id": str(event.get("patron_id", "")),
			"name": str(event.get("name", "Patron")),
			"action": action,
			"label": str(event.get("label", action.to_upper())),
			"reason": str(event.get("reason", "")),
			"total_before": maxi(0, int(event.get("total_before", 0))),
			"total_after": maxi(0, int(event.get("total_after", event.get("total_before", 0)))),
			"dealer_known_total": maxi(0, int(event.get("dealer_known_total", 0))),
			"peek_informed": bool(event.get("peek_informed", false)),
			"delay_msec": maxi(0, int(event.get("delay_msec", 0))),
			"duration_msec": maxi(120, int(event.get("duration_msec", PATRON_DECISION_HIGHLIGHT_MSEC))),
		})
	return events


func _patron_action_animation_duration_msec(events: Array) -> int:
	var duration := 0
	for event_value in events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		duration = maxi(duration, int(event.get("delay_msec", 0)) + int(event.get("duration_msec", PATRON_DECISION_HIGHLIGHT_MSEC)) + 120)
	return duration


func _settlement_next_deal_delay_msec(session: Dictionary, deal_events: Array) -> int:
	var delay := 0
	for event_value in deal_events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		delay = maxi(delay, int(event.get("delay_msec", 0)) + int(event.get("duration_msec", DEAL_CARD_DURATION_MSEC)))
	for event_value in _patron_action_event_array(session.get("patron_action_events", [])):
		var action_event: Dictionary = event_value
		delay = maxi(delay, int(action_event.get("delay_msec", 0)) + int(action_event.get("duration_msec", PATRON_DECISION_HIGHLIGHT_MSEC)))
	return delay + (PATRON_DECISION_STEP_DELAY_MSEC if delay > 0 else 0)


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


func _deal_animation_event(card_value: Variant, zone: String, hand_index: int, card_index: int, from_pos: Vector2, to_pos: Vector2, delay_msec: int, scale: float, label: String, duration_msec: int = DEAL_CARD_DURATION_MSEC) -> Dictionary:
	var card: Dictionary = _local_copy_dict(card_value)
	if card.is_empty():
		card = {"rank": 2, "suit": 0, "hidden": true}
	return {
		"zone": zone,
		"hand_index": hand_index,
		"card_index": card_index,
		"card": card,
		"from": _event_point(from_pos),
		"to": _event_point(to_pos),
		"delay_msec": maxi(0, delay_msec),
		"duration_msec": maxi(80, duration_msec),
		"scale": scale,
		"label": label,
	}


func _player_hand_base_position(hand_index: int) -> Vector2:
	var base_positions: Array = [Vector2(338, 248), Vector2(458, 248), Vector2(248, 282), Vector2(568, 282)]
	return base_positions[clampi(hand_index, 0, base_positions.size() - 1)]


func _player_hand_card_target(hand_index: int, card_index: int) -> Vector2:
	return _player_hand_base_position(hand_index) + Vector2(float(card_index) * 54.0 * PLAYER_CARD_SCALE, 0)


func _dealer_card_target(card_index: int) -> Vector2:
	return Vector2(386, 158) + Vector2(float(card_index) * 54.0 * DEALER_CARD_SCALE, 0)


func _patron_hand_card_target(patron_index: int, card_index: int) -> Vector2:
	return _patron_hand_base_position(patron_index) + Vector2(float(card_index) * 54.0 * PATRON_CARD_SCALE, 0)


func _patron_hand_base_position(patron_index: int) -> Vector2:
	var base := _patron_seat_position(patron_index)
	return base + Vector2(-28, 26)


func _initial_deal_animation_events(hands: Array, dealer_cards: Array, patron_hands: Array = []) -> Array:
	var events: Array = []
	if hands.is_empty():
		return events
	var first_hand: Dictionary = hands[0]
	var cards: Array = _card_array(first_hand.get("cards", []))
	if cards.size() > 0:
		events.append(_deal_animation_event(cards[0], "player", 0, 0, DEAL_CARD_SHOE_POS, _player_hand_card_target(0, 0), 0, PLAYER_CARD_SCALE, "player first"))
	if dealer_cards.size() > 0:
		events.append(_deal_animation_event(dealer_cards[0], "dealer", 0, 0, DEAL_CARD_SHOE_POS, _dealer_card_target(0), DEAL_CARD_STAGGER_MSEC, DEALER_CARD_SCALE, "dealer upcard"))
	if cards.size() > 1:
		events.append(_deal_animation_event(cards[1], "player", 0, 1, DEAL_CARD_SHOE_POS, _player_hand_card_target(0, 1), DEAL_CARD_STAGGER_MSEC * 2, PLAYER_CARD_SCALE, "player second"))
	if dealer_cards.size() > 1:
		var hole: Dictionary = (dealer_cards[1] as Dictionary).duplicate(true)
		hole["hidden"] = true
		events.append(_deal_animation_event(hole, "dealer", 0, 1, DEAL_CARD_SHOE_POS, _dealer_card_target(1), DEAL_CARD_STAGGER_MSEC * 3, DEALER_CARD_SCALE, "hole card"))
	var delay := DEAL_CARD_STAGGER_MSEC * 4
	for patron_index in range(patron_hands.size()):
		var patron_hand: Dictionary = patron_hands[patron_index]
		var patron_cards: Array = _card_array(patron_hand.get("cards", []))
		for card_index in range(mini(patron_cards.size(), 2)):
			events.append(_deal_animation_event(patron_cards[card_index], "patron", patron_index, card_index, DEAL_CARD_SHOE_POS, _patron_hand_card_target(patron_index, card_index), delay, PATRON_CARD_SCALE, "patron card"))
			delay += int(float(DEAL_CARD_STAGGER_MSEC) * 0.72)
	return events


func _mark_deal_animation(session: Dictionary, suffix: String, events: Array = []) -> void:
	session["deal_animation_id"] = "%s:%s:%d" % [get_id(), suffix, Time.get_ticks_msec()]
	session["deal_started_msec"] = Time.get_ticks_msec()
	session["deal_animation_events"] = _deal_animation_event_array(events)


func _deal_to_active_hand(session: Dictionary, table: Dictionary) -> void:
	var hands: Array = _hand_array(session.get("player_hands", []))
	var active_index: int = clampi(int(session.get("active_hand_index", 0)), 0, maxi(0, hands.size() - 1))
	if active_index < 0 or active_index >= hands.size():
		return
	var hand: Dictionary = hands[active_index]
	var cards: Array = _card_array(hand.get("cards", []))
	cards.append(_draw_card_from_session(session, table))
	var new_card_index := cards.size() - 1
	var new_card: Dictionary = (cards[new_card_index] as Dictionary).duplicate(true)
	hand["cards"] = cards
	hand["blackjack_eligible"] = false
	_mark_deal_animation(session, "hand_%d_card_%d" % [active_index, cards.size()], [
		_deal_animation_event(new_card, "player", active_index, new_card_index, DEAL_CARD_SHOE_POS, _player_hand_card_target(active_index, new_card_index), 0, PLAYER_CARD_SCALE, "hit card")
	])
	var total := _hand_total(cards)
	if _is_bust(cards):
		hand["stood"] = true
		hand["terminal_reason"] = "bust"
	elif total == 21:
		hand["stood"] = true
		hand["terminal_reason"] = "21"
	hands[active_index] = hand
	session["player_hands"] = hands
	session["moves_made"] = true


func _stand_active_hand(session: Dictionary) -> void:
	var hands: Array = _hand_array(session.get("player_hands", []))
	var active_index: int = clampi(int(session.get("active_hand_index", 0)), 0, maxi(0, hands.size() - 1))
	if active_index >= 0 and active_index < hands.size():
		var hand: Dictionary = hands[active_index]
		hand["stood"] = true
		if str(hand.get("terminal_reason", "")).is_empty():
			hand["terminal_reason"] = "stand"
		hands[active_index] = hand
	session["player_hands"] = hands
	session["moves_made"] = true
	_advance_active_hand(session)


func _surrender_active_hand(session: Dictionary) -> void:
	var hands: Array = _hand_array(session.get("player_hands", []))
	var active_index: int = clampi(int(session.get("active_hand_index", 0)), 0, maxi(0, hands.size() - 1))
	if active_index >= 0 and active_index < hands.size():
		var hand: Dictionary = hands[active_index]
		hand["stood"] = true
		hand["surrendered"] = true
		hand["terminal_reason"] = "surrender"
		hands[active_index] = hand
	session["player_hands"] = hands
	session["moves_made"] = true
	_advance_active_hand(session)


func _double_active_hand(session: Dictionary, table: Dictionary) -> void:
	var hands: Array = _hand_array(session.get("player_hands", []))
	var active_index: int = clampi(int(session.get("active_hand_index", 0)), 0, maxi(0, hands.size() - 1))
	if active_index < 0 or active_index >= hands.size():
		return
	var hand: Dictionary = hands[active_index]
	hand["wager_multiplier"] = 2
	hand["doubled"] = true
	hands[active_index] = hand
	session["player_hands"] = hands
	_deal_to_active_hand(session, table)
	hands = _hand_array(session.get("player_hands", []))
	if active_index >= 0 and active_index < hands.size():
		hand = hands[active_index]
		hand["stood"] = true
		if str(hand.get("terminal_reason", "")).is_empty():
			hand["terminal_reason"] = "double"
		hands[active_index] = hand
	session["player_hands"] = hands
	session["moves_made"] = true
	_advance_active_hand(session)


func _split_active_hand(session: Dictionary, table: Dictionary) -> void:
	var hands: Array = _hand_array(session.get("player_hands", []))
	var active_index: int = clampi(int(session.get("active_hand_index", 0)), 0, maxi(0, hands.size() - 1))
	if active_index < 0 or active_index >= hands.size():
		return
	var hand: Dictionary = hands[active_index]
	var cards: Array = _card_array(hand.get("cards", []))
	if cards.size() != 2:
		return
	var first_draw: Dictionary = _draw_card_from_session(session, table)
	var second_draw: Dictionary = _draw_card_from_session(session, table)
	var first_hand := {
		"cards": [cards[0], first_draw],
		"wager_multiplier": 1,
		"stood": false,
		"doubled": false,
		"split": true,
		"blackjack_eligible": false,
	}
	var second_hand := {
		"cards": [cards[1], second_draw],
		"wager_multiplier": 1,
		"stood": false,
		"doubled": false,
		"split": true,
		"blackjack_eligible": false,
	}
	hands.remove_at(active_index)
	hands.insert(active_index, second_hand)
	hands.insert(active_index, first_hand)
	session["player_hands"] = hands
	session["active_hand_index"] = active_index
	session["split_count"] = int(session.get("split_count", 0)) + 1
	var first_cards: Array = _card_array(first_hand.get("cards", []))
	var second_cards: Array = _card_array(second_hand.get("cards", []))
	var split_events: Array = [
		_deal_animation_event(cards[1], "player", active_index + 1, 0, _player_hand_card_target(active_index, 1), _player_hand_card_target(active_index + 1, 0), 0, PLAYER_CARD_SCALE, "split slide", 300),
	]
	if first_cards.size() > 1:
		split_events.append(_deal_animation_event(first_cards[1], "player", active_index, 1, DEAL_CARD_SHOE_POS, _player_hand_card_target(active_index, 1), 130, PLAYER_CARD_SCALE, "split first draw"))
	if second_cards.size() > 1:
		split_events.append(_deal_animation_event(second_cards[1], "player", active_index + 1, 1, DEAL_CARD_SHOE_POS, _player_hand_card_target(active_index + 1, 1), 315, PLAYER_CARD_SCALE, "split second draw"))
	_mark_deal_animation(session, "split_%d_%d" % [active_index, int(session.get("split_count", 0))], split_events)
	session["moves_made"] = true
	_autostand_split_aces(session, table)


func _autostand_split_aces(session: Dictionary, table: Dictionary) -> void:
	var rules: Dictionary = _table_rules(table)
	if not bool(rules.get("split_aces_one_card", true)):
		return
	# Split aces are deliberately one-card hands and cannot be re-split or hit.
	var hands: Array = _hand_array(session.get("player_hands", []))
	for i in range(hands.size()):
		var hand: Dictionary = hands[i]
		if not bool(hand.get("split", false)):
			continue
		var cards: Array = _card_array(hand.get("cards", []))
		if cards.size() >= 2 and _card_rank_value(cards[0]) == RANK_ACE:
			hand["stood"] = true
			hand["terminal_reason"] = "split ace"
			hands[i] = hand
	session["player_hands"] = hands
	_advance_active_hand(session)


func _autoadvance_finished_hands(session: Dictionary, table: Dictionary) -> void:
	var _rules: Dictionary = _table_rules(table)
	var hands: Array = _hand_array(session.get("player_hands", []))
	var active_index: int = int(session.get("active_hand_index", 0))
	if active_index >= 0 and active_index < hands.size():
		var active: Dictionary = hands[active_index]
		var total := _hand_total(_card_array(active.get("cards", [])))
		if bool(active.get("stood", false)) or total >= 21:
			active["stood"] = true
			if str(active.get("terminal_reason", "")).is_empty():
				active["terminal_reason"] = "bust" if total > 21 else "21" if total == 21 else "stand"
			hands[active_index] = active
			session["player_hands"] = hands
			_advance_active_hand(session)


func _advance_active_hand(session: Dictionary) -> void:
	var hands: Array = _hand_array(session.get("player_hands", []))
	for i in range(hands.size()):
		var hand: Dictionary = hands[i]
		if not bool(hand.get("stood", false)) and not _is_bust(_card_array(hand.get("cards", []))):
			session["active_hand_index"] = i
			return
	session["active_hand_index"] = maxi(0, hands.size() - 1)


func _stand_all_hands(session: Dictionary) -> void:
	var hands: Array = _hand_array(session.get("player_hands", []))
	for i in range(hands.size()):
		var hand: Dictionary = hands[i]
		hand["stood"] = true
		if str(hand.get("terminal_reason", "")).is_empty():
			hand["terminal_reason"] = "stand"
		hands[i] = hand
	session["player_hands"] = hands
	session["active_hand_index"] = maxi(0, hands.size() - 1)


func _dealer_final_cards(session: Dictionary, table: Dictionary) -> Array:
	var dealer_cards: Array = _card_array(session.get("dealer_cards", []))
	var rules: Dictionary = _table_rules(table)
	if _dealer_has_blackjack(dealer_cards):
		session["settlement_deal_animation_events"] = []
		session["dealer_cards"] = dealer_cards
		return dealer_cards
	var settlement_events: Array = _play_patron_hands_for_settlement(session, table)
	var dealer_draw_needed := false
	for hand_value in _hand_array(session.get("player_hands", [])):
		var hand: Dictionary = hand_value
		if not _hand_resolves_without_dealer_draw(hand):
			dealer_draw_needed = true
			break
	if not dealer_draw_needed:
		for patron_hand_value in _hand_array(session.get("patron_hands", [])):
			var patron_hand: Dictionary = patron_hand_value
			if not _hand_resolves_without_dealer_draw(patron_hand):
				dealer_draw_needed = true
				break
	if not dealer_draw_needed:
		session["settlement_deal_animation_events"] = settlement_events
		session["dealer_cards"] = dealer_cards
		return dealer_cards
	var dealer_draw_base_delay := _settlement_next_deal_delay_msec(session, settlement_events)
	var dealer_draw_index := 0
	while true:
		var info: Dictionary = _hand_total_info(dealer_cards)
		var total: int = int(info.get("total", 0))
		var soft: bool = bool(info.get("soft", false))
		# Dealer line is table-driven: S17 stops here, H17 takes one more card.
		var should_hit := total < 17 or (total == 17 and soft and bool(rules.get("dealer_hits_soft_17", false)))
		if not should_hit:
			break
		dealer_cards.append(_draw_card_from_session(session, table))
		var new_card_index := dealer_cards.size() - 1
		var new_card: Dictionary = (dealer_cards[new_card_index] as Dictionary).duplicate(true)
		settlement_events.append(_deal_animation_event(new_card, "dealer", 0, new_card_index, DEAL_CARD_SHOE_POS, _dealer_card_target(new_card_index), dealer_draw_base_delay + dealer_draw_index * 145, DEALER_CARD_SCALE, "dealer draw"))
		dealer_draw_index += 1
	session["settlement_deal_animation_events"] = settlement_events
	session["dealer_cards"] = dealer_cards
	return dealer_cards


func _play_patron_hands_for_settlement(session: Dictionary, table: Dictionary) -> Array:
	var events: Array = []
	var action_events: Array = []
	var patron_hands: Array = _hand_array(session.get("patron_hands", []))
	session["patron_action_events"] = []
	if patron_hands.is_empty():
		return events
	var decision_delay := PATRON_DECISION_START_DELAY_MSEC
	for patron_index in range(patron_hands.size()):
		var hand: Dictionary = patron_hands[patron_index]
		var cards: Array = _card_array(hand.get("cards", []))
		while not cards.is_empty() and not _is_bust(cards):
			var decision: Dictionary = _patron_decision_for_hand(cards, hand, patron_index, session)
			var action := str(decision.get("action", "stand"))
			var total_before := _hand_total(cards)
			action_events.append(_patron_action_event(hand, patron_index, action, total_before, total_before, decision, decision_delay))
			decision_delay += PATRON_DECISION_STEP_DELAY_MSEC
			if action != "hit":
				break
			cards.append(_draw_card_from_session(session, table))
			var new_card_index := cards.size() - 1
			var new_card: Dictionary = (cards[new_card_index] as Dictionary).duplicate(true)
			var total_after := _hand_total(cards)
			var hit_event: Dictionary = action_events[action_events.size() - 1]
			hit_event["total_after"] = total_after
			action_events[action_events.size() - 1] = hit_event
			var card_delay := maxi(0, decision_delay - PATRON_DECISION_STEP_DELAY_MSEC + PATRON_HIT_CARD_DELAY_MSEC)
			events.append(_deal_animation_event(new_card, "patron", patron_index, new_card_index, DEAL_CARD_SHOE_POS, _patron_hand_card_target(patron_index, new_card_index), card_delay, PATRON_CARD_SCALE, "patron hit"))
			decision_delay = maxi(decision_delay, card_delay + DEAL_CARD_DURATION_MSEC + 120)
			if total_after >= 21:
				break
		hand["cards"] = cards
		hand["stood"] = true
		var total := _hand_total(cards)
		if total > 21:
			hand["terminal_reason"] = "bust"
		elif total == 21:
			hand["terminal_reason"] = "21"
		elif str(hand.get("terminal_reason", "")).is_empty():
			hand["terminal_reason"] = "stand"
		hand["last_action"] = "hit" if _patron_hand_hit_count(action_events, patron_index) > 0 else "stand"
		hand["last_action_label"] = str(_latest_patron_action_event(action_events, patron_index).get("label", str(hand.get("last_action", "stand")).to_upper()))
		hand["last_decision_reason"] = str(_latest_patron_action_event(action_events, patron_index).get("reason", ""))
		hand["peek_informed"] = bool(_latest_patron_action_event(action_events, patron_index).get("peek_informed", false))
		patron_hands[patron_index] = hand
	session["patron_hands"] = patron_hands
	session["patron_action_events"] = _patron_action_event_array(action_events)
	return events


func _patron_decision_for_hand(cards: Array, hand: Dictionary, patron_index: int, session: Dictionary) -> Dictionary:
	var baseline_hit := _patron_should_hit(cards, hand, patron_index)
	var total := _hand_total(cards)
	if cards.is_empty() or total > 21:
		return {"action": "stand", "reason": "locked", "peek_informed": false}
	if not _strategy_info_advantage_active(session):
		return {
			"action": "hit" if baseline_hit else "stand",
			"reason": _patron_baseline_reason(hand, patron_index),
			"peek_informed": false,
		}
	var dealer_cards: Array = _card_array(session.get("dealer_cards", []))
	if dealer_cards.size() < 2:
		return {
			"action": "hit" if baseline_hit else "stand",
			"reason": _patron_baseline_reason(hand, patron_index),
			"peek_informed": false,
		}
	var dealer_total := _hand_total(_first_cards(dealer_cards, 2))
	if dealer_total >= 17 and dealer_total <= 21 and total < dealer_total:
		if total <= _patron_peek_chase_limit(hand, patron_index):
			return {
				"action": "hit",
				"reason": "known dealer %d beats %d" % [dealer_total, total],
				"peek_informed": true,
				"dealer_known_total": dealer_total,
			}
		return {
			"action": "stand",
			"reason": "won't chase dealer %d" % dealer_total,
			"peek_informed": true,
			"dealer_known_total": dealer_total,
		}
	if dealer_total >= 12 and dealer_total <= 16 and total >= 12:
		return {
			"action": "stand",
			"reason": "dealer stiff %d" % dealer_total,
			"peek_informed": true,
			"dealer_known_total": dealer_total,
		}
	return {
		"action": "hit" if baseline_hit else "stand",
		"reason": _patron_baseline_reason(hand, patron_index),
		"peek_informed": false,
		"dealer_known_total": dealer_total,
	}


func _patron_action_event(hand: Dictionary, patron_index: int, action: String, total_before: int, total_after: int, decision: Dictionary, delay_msec: int) -> Dictionary:
	var label := "HIT" if action == "hit" else "STAND"
	if bool(decision.get("peek_informed", false)):
		label = "PEEK %s" % label
	return {
		"patron_index": patron_index,
		"patron_id": str(hand.get("patron_id", "patron_%d" % patron_index)),
		"name": str(hand.get("name", "Patron")),
		"action": action,
		"label": label,
		"reason": str(decision.get("reason", "")),
		"total_before": total_before,
		"total_after": total_after,
		"dealer_known_total": int(decision.get("dealer_known_total", 0)),
		"peek_informed": bool(decision.get("peek_informed", false)),
		"delay_msec": delay_msec,
		"duration_msec": PATRON_DECISION_HIGHLIGHT_MSEC,
	}


func _latest_patron_action_event(events: Array, patron_index: int) -> Dictionary:
	for i in range(events.size() - 1, -1, -1):
		if typeof(events[i]) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = events[i]
		if int(event.get("patron_index", -1)) == patron_index:
			return event
	return {}


func _patron_hand_hit_count(events: Array, patron_index: int) -> int:
	var hits := 0
	for event_value in events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		if int(event.get("patron_index", -1)) == patron_index and str(event.get("action", "")) == "hit":
			hits += 1
	return hits


func _patron_baseline_reason(hand: Dictionary, patron_index: int) -> String:
	var temper := str(hand.get("temper", "careless"))
	if temper == "sharp" or patron_index % 3 == 1:
		return "sharp table read"
	if temper == "nosy":
		return "nosy table read"
	return "table habit"


func _patron_peek_chase_limit(hand: Dictionary, patron_index: int) -> int:
	var temper := str(hand.get("temper", "careless"))
	if temper == "sharp" or patron_index % 3 == 1:
		return 18
	if temper == "nosy":
		return 17
	return 16


func _patron_should_hit(cards: Array, hand: Dictionary, patron_index: int) -> bool:
	if cards.is_empty() or _is_bust(cards):
		return false
	var total := _hand_total(cards)
	if total <= 11:
		return true
	if total >= 17:
		return false
	var temper := str(hand.get("temper", "careless"))
	var stand_total := 16
	if temper == "sharp" or patron_index % 3 == 1:
		stand_total = 17
	elif temper == "nosy":
		stand_total = 15
	return total < stand_total


func _settle_hand(hand: Dictionary, dealer_cards: Array, base_stake: int) -> Dictionary:
	var cards: Array = _card_array(hand.get("cards", []))
	var wager: int = maxi(1, base_stake) * maxi(1, int(hand.get("wager_multiplier", 1)))
	var player_total: int = _hand_total(cards)
	var dealer_total: int = _hand_total(dealer_cards)
	var player_blackjack: bool = _is_natural_blackjack(hand)
	var dealer_blackjack: bool = _dealer_has_blackjack(dealer_cards)
	var dealer_bust: bool = dealer_total > 21
	var outcome := "push"
	var delta := 0
	if bool(hand.get("surrendered", false)):
		outcome = "surrender"
		delta = -int(ceil(float(wager) * 0.5))
	elif player_blackjack and dealer_blackjack:
		outcome = "push"
	elif player_blackjack:
		outcome = "blackjack"
		# Naturals pay 3:2 in this sim. Bankroll is whole-dollar, so odd chip
		# wagers floor the half-dollar instead of switching to a 6:5 table.
		delta = maxi(1, int(floor(float(wager) * 1.5)))
	elif dealer_blackjack:
		outcome = "dealer_blackjack"
		delta = -wager
	elif player_total > 21:
		outcome = "bust"
		delta = -wager
	elif dealer_bust:
		outcome = "dealer_bust"
		delta = wager
	elif player_total > dealer_total:
		outcome = "win"
		delta = wager
	elif player_total < dealer_total:
		outcome = "lose"
		delta = -wager
	return {
		"outcome": outcome,
		"bankroll_delta": delta,
		"wager": wager,
		"player_total": player_total,
		"dealer_total": dealer_total,
		"doubled": bool(hand.get("doubled", false)),
		"split": bool(hand.get("split", false)),
		"surrendered": bool(hand.get("surrendered", false)),
		"blackjack": player_blackjack,
	}


func _settle_side_bets(session: Dictionary, table: Dictionary, dealer_cards: Array, stake: int, run_state: RunState) -> Array:
	var results: Array = []
	var active_ids: Array = _string_array(session.get("blackjack_side_bets", []))
	if active_ids.is_empty():
		return results
	var hands: Array = _hand_array(session.get("player_hands", []))
	if hands.is_empty():
		return results
	var first_hand: Dictionary = hands[0]
	var initial_player_cards: Array = _card_array(session.get("initial_player_cards", []))
	if initial_player_cards.is_empty():
		initial_player_cards = _first_cards(_card_array(first_hand.get("cards", [])), 2)
	var initial_dealer_cards: Array = _card_array(session.get("initial_dealer_cards", []))
	if initial_dealer_cards.is_empty():
		initial_dealer_cards = _first_cards(dealer_cards, 2)
	var available: Array = _available_side_bets_for_session(table, session)
	for bet in available:
		var bet_id := str(bet.get("id", ""))
		if not active_ids.has(bet_id):
			continue
		var bet_stake: int = _side_bet_stake(stake, bet, run_state)
		var dealer_cards_for_bet: Array = dealer_cards if bet_id == "buster" else initial_dealer_cards
		var settled: Dictionary = _side_bet_result(bet, initial_player_cards, dealer_cards_for_bet, bet_stake, run_state)
		results.append(settled)
	return results


func _side_bet_result(bet: Dictionary, player_cards: Array, dealer_cards: Array, bet_stake: int, run_state: RunState) -> Dictionary:
	var bet_id := str(bet.get("id", ""))
	var payout_mult := 0
	var detail := "miss"
	match bet_id:
		"perfect_pairs":
			var pair: Dictionary = _perfect_pairs_payout(player_cards)
			payout_mult = int(pair.get("payout", 0))
			detail = str(pair.get("detail", "miss"))
		"twenty_one_three":
			var combo: Dictionary = _twenty_one_three_payout(player_cards, dealer_cards)
			payout_mult = int(combo.get("payout", 0))
			detail = str(combo.get("detail", "miss"))
		"lucky_ladies":
			var ladies: Dictionary = _lucky_ladies_payout(player_cards, dealer_cards)
			payout_mult = int(ladies.get("payout", 0))
			detail = str(ladies.get("detail", "miss"))
		"royal_match":
			var royal: Dictionary = _royal_match_payout(player_cards)
			payout_mult = int(royal.get("payout", 0))
			detail = str(royal.get("detail", "miss"))
		"insurance":
			var insurance: Dictionary = _insurance_payout(dealer_cards)
			payout_mult = int(insurance.get("payout", 0))
			detail = str(insurance.get("detail", "miss"))
		"buster":
			var buster: Dictionary = _buster_payout(dealer_cards)
			payout_mult = int(buster.get("payout", 0))
			detail = str(buster.get("detail", "miss"))
	var payout_multiplier := 1
	if bet_id == "lucky_ladies":
		payout_multiplier = maxi(1, _item_effect_total("blackjack_lucky_ladies_payout_multiplier", run_state))
		if payout_mult > 0 and payout_multiplier > 1:
			payout_mult *= payout_multiplier
			detail = "%s, compact doubled" % detail
	var bonus_mult: int = _item_effect_total("blackjack_side_bet_bonus", run_state)
	if payout_mult > 0:
		payout_mult += bonus_mult
	var loss_reduction: int = _item_effect_total("blackjack_side_bet_loss_reduction", run_state)
	var delta := (bet_stake * payout_mult) if payout_mult > 0 else -maxi(0, bet_stake - loss_reduction)
	return {
		"id": bet_id,
		"label": str(bet.get("label", bet_id)),
		"stake": bet_stake,
		"payout_mult": payout_mult,
		"item_payout_multiplier": payout_multiplier,
		"bankroll_delta": delta,
		"won": payout_mult > 0,
		"detail": detail,
	}


func _cheat_detection_for_hand(session: Dictionary, table: Dictionary, run_state: RunState, environment: Dictionary, rng: RngStream, stake: int) -> Dictionary:
	var cheats: Dictionary = _local_copy_dict(session.get("cheats_used", {}))
	var used_peek: bool = bool(cheats.get("peek_hole_card", false))
	var used_count: bool = bool(cheats.get("count_cards", false)) or bool(session.get("count_attempted", false)) or bool(session.get("count_answered", false))
	var strategy_events: Array = _dictionary_array(session.get("strategy_deviation_events", []))
	var used_strategy := not strategy_events.is_empty()
	if not used_peek and not used_count and not used_strategy:
		return {"suspicion_delta": 0, "caught": false, "message": ""}
	var base_heat := 0
	var catch_chance: int = int(table.get("dealer_catch_base", 10))
	if used_peek:
		var snitch_risk: int = _patron_snitch_risk(table, session)
		var dealer_focus: Dictionary = _dealer_focus_state(table, session, run_state, snitch_risk)
		base_heat += 5
		catch_chance += 8
		if bool(session.get("peek_had_window", false)):
			catch_chance -= 10
			base_heat = maxi(1, base_heat - 3)
		else:
			base_heat += 14
			catch_chance += 28
		catch_chance += int(float(int(dealer_focus.get("attention_meter", 0))) / 8.0)
		if snitch_risk > 0:
			base_heat += int(ceil(float(snitch_risk) / 12.0))
			catch_chance += int(ceil(float(snitch_risk) / 4.0))
	if used_count:
		var challenge: Dictionary = _local_copy_dict(session.get("count_challenge", {}))
		var missed_count := (_string_array(challenge.get("missed_icons", []))).size()
		var bad_hits := int(challenge.get("bad_hits", 0))
		var dirty_count: bool = not bool(session.get("count_correct", false)) or missed_count > 0 or bad_hits > 0
		if not dirty_count and not used_peek:
			return {
				"suspicion_delta": 0,
				"caught": false,
				"catch_chance": 0,
				"message": "The live count stays clean.",
				"used_peek": false,
				"used_count": true,
			}
		if dirty_count:
			base_heat += 3 + clampi(missed_count + bad_hits, 0, 6)
			catch_chance += 6 + missed_count * 4 + bad_hits * 5
			catch_chance += int(float(int(challenge.get("dealer_attention_risk", 0))) / 16.0)
			base_heat += _item_effect_total("blackjack_count_heat_delta", run_state)
	if used_strategy:
		var strategy_score := maxi(1, int(session.get("strategy_deviation_score", strategy_events.size())))
		var profile: Dictionary = _local_copy_dict(table.get("dealer_profile", {}))
		var response := str(profile.get("strategy_response", "watch"))
		var scrutiny := clampi(int(profile.get("strategy_scrutiny", 10)), 0, 30)
		catch_chance += strategy_score * 7 + int(float(scrutiny) / 3.0)
		if response == "watch":
			base_heat += clampi(strategy_score, 1, 6)
		elif response == "heat":
			base_heat += 4 + strategy_score * 3
		else:
			base_heat += 2 + strategy_score * 2
		if bool(session.get("strategy_confronted", false)):
			base_heat += clampi(int(session.get("strategy_confrontation_heat", 0)), 0, STRATEGY_DEVIATION_MAX_HEAT)
			catch_chance += 20
	base_heat += run_state.security_risk_bonus("cheat")
	catch_chance += run_state.security_risk_bonus("cheat") * 2
	var pit_boss: Dictionary = run_state.pit_boss_watch_status(environment)
	var pit_boss_heat_bonus := 0
	if bool(pit_boss.get("active", false)):
		pit_boss_heat_bonus = int(pit_boss.get("cheat_heat_bonus", 0))
		catch_chance += pit_boss_heat_bonus
		base_heat += pit_boss_heat_bonus
	base_heat += _item_effect_total("cheat_suspicion_delta", run_state)
	if used_peek:
		base_heat += _item_effect_total("blackjack_peek_heat_delta", run_state)
	catch_chance += _item_effect_total("blackjack_dealer_catch_chance", run_state)
	catch_chance = clampi(catch_chance, 2, 95)
	var strategy_confronted := bool(session.get("strategy_confronted", false))
	var caught := strategy_confronted or rng.randi_range(1, 100) <= catch_chance
	var heat := maxi(0, base_heat)
	if caught:
		var catch_heat_bonus := maxi(6, int(table.get("catch_heat", 18)))
		if strategy_confronted and not used_peek and not used_count:
			catch_heat_bonus = maxi(4, int(round(float(int(table.get("catch_heat", 18))) * 0.5)))
		heat += catch_heat_bonus
	var message := "The dealer confronts the off-book line." if strategy_confronted else "The dealer clocks the move." if caught else "The risky move slides by."
	if used_count and bool(session.get("count_correct", false)):
		message = "%s The count lands clean." % message
	elif used_count:
		message = "%s The count drifts." % message
	if used_strategy and not strategy_confronted:
		message = "%s The odd strategy line is noted." % message
	return {
		"suspicion_delta": heat,
		"caught": caught,
		"catch_chance": catch_chance,
		"message": message,
		"used_peek": used_peek,
		"used_count": used_count,
		"used_strategy_deviation": used_strategy,
		"strategy_confronted": strategy_confronted,
		"strategy_deviation_events": strategy_events,
		"pit_boss_watched": bool(pit_boss.get("watched", false)),
		"pit_boss_heat_bonus": pit_boss_heat_bonus,
		"stake": stake,
	}


func _blackjack_item_adjustment(main_delta: int, side_delta: int, session: Dictionary, run_state: RunState, stake: int) -> Dictionary:
	# Passive blackjack item effects are resolved here after main and side-bet
	# payouts are known. New result modifiers should add one effect key instead
	# of branching through the hand settlement flow.
	var main_adjust := 0
	var side_adjust := 0
	var cheats: Dictionary = _local_copy_dict(session.get("cheats_used", {}))
	if main_delta > 0:
		main_adjust += run_state.luck_payout_bonus(stake, true) if run_state != null else 0
		main_adjust += _item_effect_total("win_bonus", run_state)
		main_adjust += _item_effect_total("blackjack_win_bonus", run_state)
		if bool(session.get("count_correct", false)):
			main_adjust += _item_effect_total("blackjack_count_edge_bonus", run_state)
	elif main_delta < 0:
		main_adjust += mini(-main_delta, _item_effect_total("loss_reduction", run_state))
		main_adjust += mini(maxi(0, -main_delta - main_adjust), _item_effect_total("blackjack_loss_reduction", run_state))
		if bool(cheats.get("peek_hole_card", false)):
			main_adjust += mini(maxi(0, -main_delta - main_adjust), _item_effect_total("blackjack_peek_loss_reduction", run_state))
	if side_delta > 0:
		side_adjust += _item_effect_total("blackjack_side_bet_flat_bonus", run_state)
	return {
		"main_delta": main_adjust,
		"side_delta": side_adjust,
		"summary": "Blackjack gear adjusted the result." if main_adjust != 0 or side_adjust != 0 else "",
		"stake": stake,
	}


func _update_table_after_hand(table: Dictionary, session: Dictionary, dealer_cards: Array, actual_count_delta: int, count_record_delta: int, rng: RngStream) -> void:
	var deck_count := int(table.get("deck_count", 6))
	var cut_card_remaining := int(table.get("cut_card_remaining", CardShoeScript.cut_card_remaining(deck_count)))
	var remaining_shoe: Array = _remaining_shoe_after_session(table, session)
	table["hands_played"] = int(table.get("hands_played", 0)) + 1
	GameModule.reset_table_round_timer(table)
	table["running_count"] = int(table.get("running_count", 0)) + actual_count_delta
	if bool(session.get("count_answered", false)):
		table["recorded_running_count"] = int(table.get("recorded_running_count", 0)) + count_record_delta
	if bool(session.get("count_correct", false)):
		table["count_accuracy_streak"] = int(table.get("count_accuracy_streak", 0)) + 1
	elif bool(session.get("count_answered", false)):
		table["count_accuracy_streak"] = 0
	var strategy_events: Array = _dictionary_array(session.get("strategy_deviation_events", []))
	var strategy_score := maxi(0, int(session.get("strategy_deviation_score", 0)))
	var profile: Dictionary = _local_copy_dict(table.get("dealer_profile", {}))
	if strategy_score > 0:
		table["strategy_deviation_strikes"] = maxi(0, int(table.get("strategy_deviation_strikes", 0))) + strategy_score
		var response := str(profile.get("strategy_response", "watch"))
		var watch_add := clampi(int(session.get("strategy_attention_boost", 0)), 0, STRATEGY_DEVIATION_MAX_WATCH)
		if response == "heat":
			watch_add = int(ceil(float(watch_add) * 0.45))
		elif response == "both":
			watch_add = int(ceil(float(watch_add) * 0.70))
		table["strategy_watch_pressure"] = clampi(int(table.get("strategy_watch_pressure", 0)) + watch_add, 0, STRATEGY_DEVIATION_MAX_WATCH)
		table["strategy_last_notice"] = "Dealer questioned %d off-book play%s." % [strategy_events.size(), "" if strategy_events.size() == 1 else "s"]
		if bool(session.get("strategy_confronted", false)):
			profile["attention_base"] = clampi(int(profile.get("attention_base", 12)) + 3, 8, 70)
			table["dealer_profile"] = profile
	else:
		table["strategy_watch_pressure"] = clampi(int(table.get("strategy_watch_pressure", 0)) - 2, 0, STRATEGY_DEVIATION_MAX_WATCH)
	if remaining_shoe.is_empty() or remaining_shoe.size() <= cut_card_remaining:
		var shuffle_rng := rng.fork("blackjack_shuffle:%d" % int(table.get("hands_played", 0)))
		remaining_shoe = _build_shoe(deck_count, shuffle_rng)
		table["shoe_cursor"] = 0
		table["running_count"] = 0
		table["recorded_running_count"] = 0
		table["last_shuffle_hand"] = int(table.get("hands_played", 0))
		table["last_result"] = {"summary": "Shoe shuffled.", "dealer_cards": dealer_cards}
	else:
		table["shoe_cursor"] = 0
		table["last_result"] = {"summary": "Hand settled.", "dealer_cards": dealer_cards}
	table["shoe"] = remaining_shoe
	table["shoe_remaining"] = CardShoeScript.remaining_count(remaining_shoe)
	table["shoe_composition"] = CardShoeScript.remaining_composition(remaining_shoe)
	table["cut_card_remaining"] = clampi(cut_card_remaining, 1, deck_count * CardShoeScript.CARDS_PER_DECK)
	table["cut_card_at"] = deck_count * CardShoeScript.CARDS_PER_DECK - int(table.get("cut_card_remaining", cut_card_remaining))
	table["shoe_label"] = CardShoeScript.shoe_label(deck_count)
	table["count_efficiency"] = CardShoeScript.count_efficiency_label(deck_count)
	table["last_deal_animation_id"] = "%s:%d" % [get_id(), int(table.get("hands_played", 0))]
	table["last_deal_started_msec"] = Time.get_ticks_msec()
	table["last_deal_animation_events"] = _deal_animation_event_array(session.get("settlement_deal_animation_events", []))
	table["last_patron_action_events"] = _patron_action_event_array(session.get("patron_action_events", []))


func _update_environment_table(environment: Dictionary, table: Dictionary) -> void:
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	game_states[get_id()] = table.duplicate(true)
	environment["game_states"] = game_states


func _action_command(action_id: String, action_kind: String, confirm_requested: bool, ui_state: Dictionary, index: int, message: String, resolve_when_selected: bool, preserve_surface_ui_state: bool = false, force_resolve: bool = false) -> Dictionary:
	var already_selected := str(ui_state.get("selected_action_id", "")) == action_id and str(ui_state.get("selected_action_kind", "")) == action_kind
	if not message.is_empty():
		ui_state["table_notice"] = message
	var compact_state: Dictionary = _compact_session_for_ui(ui_state)
	return GameModule.surface_command({
		"handled": true,
		"ui_state": compact_state,
		"action_id": action_id,
		"action_kind": action_kind,
		"resolve": force_resolve or confirm_requested or (already_selected and resolve_when_selected),
		"preserve_surface_ui_state": preserve_surface_ui_state,
		"selected_index": index,
		"message": message,
	})


func _message_command(ui_state: Dictionary, message: String) -> Dictionary:
	if not message.is_empty():
		ui_state["table_notice"] = message
	var compact_state: Dictionary = _compact_session_for_ui(ui_state)
	return GameModule.surface_command({
		"handled": true,
		"ui_state": compact_state,
		"selected_index": int(ui_state.get("active_hand_index", 0)),
		"message": message,
	})


func _settle_completed_round_command(ui_state: Dictionary, index: int, message: String, table: Dictionary, run_state: RunState) -> Dictionary:
	if _count_settlement_preview_required(ui_state):
		_prepare_count_settlement_preview(ui_state, table, run_state)
		var preview_message := "Dealer reveals the table. Count every exposed card, then settle."
		ui_state["table_notice"] = preview_message
		return _message_command(ui_state, preview_message)
	ui_state["dealer_hole_visible"] = true
	ui_state["round_terminal"] = true
	ui_state["settlement_pending"] = true
	ui_state["table_notice"] = message
	return _action_command("play_basic", "legal", true, ui_state, index, message, true, false, true)


func _count_settlement_preview_required(ui_state: Dictionary) -> bool:
	if bool(ui_state.get("count_answered", false)) or bool(ui_state.get("settlement_count_revealed", false)):
		return false
	if _local_copy_dict(ui_state.get("count_challenge", {})).is_empty():
		return false
	return bool(ui_state.get("counting_enabled", false)) or bool(ui_state.get("count_attempted", false))


func _prepare_count_settlement_preview(ui_state: Dictionary, table: Dictionary, run_state: RunState) -> void:
	ui_state["dealer_hole_visible"] = true
	ui_state["round_terminal"] = true
	ui_state["settlement_pending"] = true
	ui_state["settlement_count_revealed"] = true
	_dealer_final_cards(ui_state, table)
	_sync_count_challenge_icons(ui_state, run_state)


func _toggle_counting_command(index: int, ui_state: Dictionary, table: Dictionary, environment: Dictionary, run_state: RunState) -> Dictionary:
	var enabled := not bool(table.get("counting_enabled", false))
	table["counting_enabled"] = enabled
	ui_state["counting_enabled"] = enabled
	if enabled:
		if _has_dealt_hand(ui_state) and _local_copy_dict(ui_state.get("count_challenge", {})).is_empty() and not bool(ui_state.get("count_answered", false)):
			_start_count_challenge(ui_state, table, run_state)
		_update_environment_table(environment, table)
		var challenge: Dictionary = _local_copy_dict(ui_state.get("count_challenge", {}))
		var message := "Counting armed for this table. Symbols appear only for +1 and -1 cards."
		if _has_dealt_hand(ui_state) and (_dictionary_array(challenge.get("icons", []))).is_empty():
			message = "Counting armed. Neutral cards are tracked; symbols appear when countable cards reveal."
		return GameModule.surface_command({
			"handled": true,
			"ui_state": _compact_session_for_ui(ui_state),
			"selected_index": index,
			"message": message,
		})
	ui_state["count_challenge"] = {}
	ui_state["count_answered"] = false
	ui_state["count_correct"] = false
	ui_state["count_perfect"] = false
	ui_state["count_delta"] = 0
	ui_state["count_declared_delta"] = 0
	_update_environment_table(environment, table)
	return GameModule.surface_command({
		"handled": true,
		"ui_state": _compact_session_for_ui(ui_state),
		"selected_index": index,
		"message": "Counting disarmed for this table.",
	})


func _session_stake(stake: int, session: Dictionary) -> int:
	return maxi(1, int(session.get("locked_stake", stake)))


func _opening_deal_notice(session: Dictionary, _table: Dictionary) -> String:
	var dealer_cards: Array = _card_array(session.get("dealer_cards", []))
	var hand: Dictionary = _active_hand(session)
	var cards: Array = _card_array(hand.get("cards", []))
	if _dealer_has_blackjack(dealer_cards):
		if not dealer_cards.is_empty() and _card_rank_value(dealer_cards[0]) == RANK_ACE:
			return "Dealer shows an ace. Insurance is open; settle before any hit."
		return "Dealer checks the hole card. Blackjack is pending; settle the hand."
	if _is_natural_blackjack(hand):
		return "BLACKJACK. Settle to reveal the dealer and pay 3:2."
	return "Cards are out. Play the live hand: hit, stand, double, or split."


func _table_notice_for_session(session: Dictionary, table: Dictionary) -> String:
	var notice := str(session.get("table_notice", ""))
	var count_notice := str(session.get("count_live_notice", ""))
	if not notice.is_empty() and not count_notice.is_empty() and notice != count_notice:
		return "%s %s" % [count_notice, notice]
	if not notice.is_empty():
		return notice
	if not count_notice.is_empty():
		return count_notice
	if not _has_dealt_hand(session):
		return "Slide chips, choose side bets, then press DEAL."
	var dealer_cards: Array = _card_array(session.get("dealer_cards", []))
	if _dealer_has_blackjack(dealer_cards):
		return _opening_deal_notice(session, table)
	if _all_hands_complete(session):
		return _terminal_round_message(session)
	return _active_hand_status_text(session)


func _active_hand_status_text(session: Dictionary) -> String:
	if not _has_dealt_hand(session):
		return "No hand in play."
	var hands: Array = _hand_array(session.get("player_hands", []))
	if hands.is_empty():
		return "No hand in play."
	var active_index: int = clampi(int(session.get("active_hand_index", 0)), 0, maxi(0, hands.size() - 1))
	if _all_hands_complete(session):
		return _terminal_round_message(session)
	var hand: Dictionary = hands[active_index]
	var cards: Array = _card_array(hand.get("cards", []))
	var total := _hand_total(cards)
	var soft := bool(_hand_total_info(cards).get("soft", false))
	if bool(hand.get("surrendered", false)):
		return "Hand %d surrendered." % (active_index + 1)
	if total > 21:
		return "BUST: Hand %d totals %d." % [active_index + 1, total]
	if total == 21:
		return "Hand %d is locked at 21." % (active_index + 1)
	if bool(hand.get("stood", false)):
		return "Hand %d stands on %d." % [active_index + 1, total]
	return "Hand %d live: %s%d." % [active_index + 1, "soft " if soft else "", total]


func _terminal_round_message(session: Dictionary) -> String:
	var dealer_cards: Array = _card_array(session.get("dealer_cards", []))
	if _dealer_has_blackjack(dealer_cards):
		return "Dealer reveals blackjack. The hand settles immediately."
	var hands: Array = _hand_array(session.get("player_hands", []))
	if hands.size() == 1:
		var hand: Dictionary = hands[0]
		var total := _hand_total(_card_array(hand.get("cards", [])))
		if bool(hand.get("surrendered", false)):
			return "SURRENDER: half the wager is returned; the hand settles now."
		if _is_natural_blackjack(hand):
			return "BLACKJACK. Dealer reveals the hole card and pays 3:2 unless they also have it."
		if total > 21:
			return "BUST: your hand totals %d. Dealer takes the wager now." % total
		if total == 21:
			return "21 locked. Dealer reveals and settles now."
	if _all_player_hands_busted(session):
		return "All player hands busted. Dealer takes the completed wagers."
	return "All player hands are complete. Dealer reveals and settles now."


func _post_hand_action_message(session: Dictionary, hand_index: int, action_label: String) -> String:
	var hands: Array = _hand_array(session.get("player_hands", []))
	var safe_index := clampi(hand_index, 0, maxi(0, hands.size() - 1))
	var hand: Dictionary = hands[safe_index] if safe_index >= 0 and safe_index < hands.size() else {}
	var total := _hand_total(_card_array(hand.get("cards", [])))
	var prefix := "%s: Hand %d" % [action_label, safe_index + 1]
	if bool(hand.get("surrendered", false)):
		prefix = "SURRENDER: Hand %d gives up half the wager." % (safe_index + 1)
	elif total > 21:
		prefix = "BUST: Hand %d totals %d." % [safe_index + 1, total]
	elif total == 21:
		prefix = "Hand %d reaches 21." % (safe_index + 1)
	elif bool(hand.get("stood", false)):
		prefix = "%s stands on %d." % [prefix, total]
	else:
		prefix = "%s totals %d." % [prefix, total]
	var active_index := int(session.get("active_hand_index", 0))
	if active_index != safe_index and active_index >= 0 and active_index < hands.size():
		prefix += " Hand %d is live." % (active_index + 1)
	return prefix


func _append_strategy_notice(message: String, strategy_notice: String) -> String:
	if strategy_notice.is_empty():
		return message
	if message.is_empty():
		return strategy_notice
	return "%s %s" % [message, strategy_notice]


func _record_strategy_deviation(session: Dictionary, table: Dictionary, run_state: RunState, chosen_action: String) -> String:
	var event: Dictionary = _strategy_deviation_for_action(session, table, run_state, chosen_action)
	if event.is_empty():
		return ""
	var events: Array = _dictionary_array(session.get("strategy_deviation_events", []))
	events.append(event)
	session["strategy_deviation_events"] = events
	var score := maxi(1, int(event.get("score", 1)))
	session["strategy_deviation_score"] = maxi(0, int(session.get("strategy_deviation_score", 0))) + score
	var profile: Dictionary = _local_copy_dict(table.get("dealer_profile", {}))
	var scrutiny := clampi(int(profile.get("strategy_scrutiny", 10)), 0, 30)
	var attention_add := clampi(score * 4 + int(ceil(float(scrutiny) / 5.0)), 4, 20)
	session["strategy_attention_boost"] = clampi(int(session.get("strategy_attention_boost", 0)) + attention_add, 0, STRATEGY_DEVIATION_MAX_WATCH)
	var threshold := clampi(int(profile.get("strategy_threshold", 4)), 1, 8)
	var cumulative_score := maxi(0, int(table.get("strategy_deviation_strikes", 0))) + int(session.get("strategy_deviation_score", 0))
	if cumulative_score >= threshold and not bool(session.get("strategy_confronted", false)):
		session["strategy_confronted"] = true
		var response := str(profile.get("strategy_response", "watch"))
		var heat := 4 + score + int(ceil(float(scrutiny) / 8.0))
		if response == "heat":
			heat += 8 + score * 2
		elif response == "both":
			heat += 5 + score
		session["strategy_confrontation_heat"] = clampi(int(session.get("strategy_confrontation_heat", 0)) + heat, 0, STRATEGY_DEVIATION_MAX_HEAT)
		return "The dealer pauses on the %s: \"That call was too cute. I'm watching you.\"" % str(event.get("chosen", chosen_action))
	return "The dealer notes the off-book %s." % str(event.get("chosen", chosen_action))


func _strategy_deviation_for_action(session: Dictionary, table: Dictionary, run_state: RunState, chosen_action: String) -> Dictionary:
	if not _strategy_info_advantage_active(session):
		return {}
	var hands: Array = _hand_array(session.get("player_hands", []))
	var active_index: int = clampi(int(session.get("active_hand_index", 0)), 0, maxi(0, hands.size() - 1))
	if active_index < 0 or active_index >= hands.size():
		return {}
	var hand: Dictionary = hands[active_index]
	var cards: Array = _card_array(hand.get("cards", []))
	if cards.is_empty() or _is_bust(cards):
		return {}
	var recommended := _basic_strategy_action(session, table, run_state)
	if recommended.is_empty() or recommended == chosen_action:
		return {}
	var dealer_cards: Array = _card_array(session.get("dealer_cards", []))
	var benefit: Dictionary = _strategy_deviation_benefit(chosen_action, recommended, cards, dealer_cards)
	if benefit.is_empty():
		return {}
	return {
		"hand_index": active_index,
		"chosen": chosen_action,
		"recommended": recommended,
		"score": int(benefit.get("score", 1)),
		"reason": str(benefit.get("reason", "")),
		"player_total": _hand_total(cards),
		"dealer_known_total": _hand_total(dealer_cards),
		"timestamp_msec": Time.get_ticks_msec(),
	}


func _strategy_info_advantage_active(session: Dictionary) -> bool:
	var cheats: Dictionary = _local_copy_dict(session.get("cheats_used", {}))
	return bool(cheats.get("peek_hole_card", false)) and bool(session.get("dealer_hole_visible", false)) and not bool(session.get("peek_caught_watching", false))


func _strategy_deviation_benefit(chosen_action: String, recommended: String, player_cards: Array, dealer_cards: Array) -> Dictionary:
	if dealer_cards.size() < 2:
		return {}
	var player_info: Dictionary = _hand_total_info(player_cards)
	var player_total := int(player_info.get("total", 0))
	var dealer_total := _hand_total(_first_cards(dealer_cards, 2))
	if player_total > 21 or dealer_total > 21:
		return {}
	var card_chase := ["hit", "double", "split"].has(chosen_action)
	var standing_loses := dealer_total >= 17 and dealer_total <= 21 and player_total < dealer_total
	var standing_pushes := dealer_total >= 17 and dealer_total <= 21 and player_total == dealer_total
	var dealer_weak_known := dealer_total >= 12 and dealer_total <= 16
	var score := 1
	var reason := ""
	if card_chase and ["stand", "surrender"].has(recommended) and standing_loses:
		score = 2 if player_total >= 17 else 1
		reason = "known dealer total beats the standing hand"
	elif chosen_action == "surrender" and recommended != "surrender" and standing_loses:
		score = 1
		reason = "known dealer total makes surrender unusually attractive"
	elif chosen_action == "stand" and ["hit", "double", "surrender"].has(recommended) and dealer_weak_known and player_total >= 12 and player_total <= 16:
		score = 1
		reason = "known dealer hole card turns a visible strong upcard into a stiff hand"
	elif chosen_action == "double" and recommended == "hit" and dealer_weak_known and player_total >= 9 and player_total <= 11:
		score = 1
		reason = "known dealer hole card exposes a weak made hand"
	elif chosen_action == "split" and recommended != "split" and dealer_weak_known:
		score = 1
		reason = "known dealer weakness makes an odd split look too precise"
	elif card_chase and recommended == "stand" and standing_pushes and player_total >= 17:
		score = 1
		reason = "known push invites an otherwise strange draw"
	if reason.is_empty():
		return {}
	return {"score": score, "reason": reason}


func _basic_strategy_action(session: Dictionary, table: Dictionary, run_state: RunState) -> String:
	var hand: Dictionary = _active_hand(session)
	var cards: Array = _card_array(hand.get("cards", []))
	if cards.is_empty():
		return ""
	var dealer_cards: Array = _card_array(session.get("dealer_cards", []))
	if dealer_cards.is_empty():
		return ""
	var dealer_value := _dealer_strategy_value(dealer_cards[0] as Dictionary)
	var selected_stake := _session_stake(maxi(1, int(session.get("selected_stake", session.get("locked_stake", 1)))), session)
	if _can_surrender(session, table) and not bool(_hand_total_info(cards).get("soft", false)):
		var hard_total := _hand_total(cards)
		if hard_total == 16 and dealer_value >= 9:
			return "surrender"
		if hard_total == 15 and dealer_value == 10:
			return "surrender"
	if _can_split(session, table, selected_stake, run_state):
		var split_action := _pair_strategy_action(cards, dealer_value, table)
		if not split_action.is_empty():
			return split_action
	var info: Dictionary = _hand_total_info(cards)
	if bool(info.get("soft", false)) and cards.size() <= 3:
		return _soft_strategy_action(int(info.get("total", 0)), dealer_value, _can_double(session, table, selected_stake, run_state))
	return _hard_strategy_action(int(info.get("total", 0)), dealer_value, _can_double(session, table, selected_stake, run_state))


func _basic_strategy_advice(session: Dictionary, table: Dictionary, run_state: RunState) -> Dictionary:
	if run_state == null or _item_effect_total("blackjack_basic_strategy_card", run_state) <= 0:
		return {"visible": false}
	var action := _basic_strategy_action(session, table, run_state)
	if action.is_empty():
		return {"visible": false}
	var hand: Dictionary = _active_hand(session)
	var cards: Array = _card_array(hand.get("cards", []))
	var dealer_cards: Array = _card_array(session.get("dealer_cards", []))
	var total_info: Dictionary = _hand_total_info(cards)
	var dealer_label := "dealer ?"
	if not dealer_cards.is_empty():
		dealer_label = "dealer %s" % _card_rank_label(_card_rank_value(dealer_cards[0]))
	var total_label := "soft %d" % int(total_info.get("total", 0)) if bool(total_info.get("soft", false)) else "%d" % int(total_info.get("total", 0))
	return {
		"visible": true,
		"action": action,
		"label": _book_action_label(action),
		"summary": "%s vs %s" % [total_label, dealer_label],
	}


func _book_action_label(action: String) -> String:
	match action:
		"hit":
			return "Hit"
		"stand":
			return "Stand"
		"double":
			return "Double"
		"split":
			return "Split"
		"surrender":
			return "Surrender"
		_:
			return action.capitalize()


func _card_rank_label(rank: int) -> String:
	match rank:
		RANK_ACE:
			return "A"
		13:
			return "K"
		12:
			return "Q"
		11:
			return "J"
		_:
			return "%d" % mini(rank, 10)


func _pair_strategy_action(cards: Array, dealer_value: int, table: Dictionary) -> String:
	if cards.size() != 2:
		return ""
	var first_rank := _card_rank_value(cards[0])
	var second_rank := _card_rank_value(cards[1])
	if first_rank != second_rank:
		return ""
	var rules: Dictionary = _table_rules(table)
	var das := bool(rules.get("double_after_split", true))
	var pair_value := 11 if first_rank == RANK_ACE else mini(first_rank, 10)
	if pair_value == 11 or pair_value == 8:
		return "split"
	if pair_value == 10:
		return "stand"
	if pair_value == 9:
		return "split" if [2, 3, 4, 5, 6, 8, 9].has(dealer_value) else "stand"
	if pair_value == 7:
		return "split" if dealer_value >= 2 and dealer_value <= 7 else "hit"
	if pair_value == 6:
		return "split" if dealer_value >= 2 and dealer_value <= 6 else "hit"
	if pair_value == 5:
		return "double" if dealer_value >= 2 and dealer_value <= 9 else "hit"
	if pair_value == 4:
		return "split" if das and dealer_value >= 5 and dealer_value <= 6 else "hit"
	if pair_value == 2 or pair_value == 3:
		return "split" if dealer_value >= 2 and dealer_value <= 7 else "hit"
	return ""


func _soft_strategy_action(total: int, dealer_value: int, double_available: bool) -> String:
	if total >= 19:
		return "stand"
	if total == 18:
		if dealer_value >= 3 and dealer_value <= 6:
			return "double" if double_available else "stand"
		if dealer_value == 2 or dealer_value == 7 or dealer_value == 8:
			return "stand"
		return "hit"
	if total == 17:
		return "double" if double_available and dealer_value >= 3 and dealer_value <= 6 else "hit"
	if total == 15 or total == 16:
		return "double" if double_available and dealer_value >= 4 and dealer_value <= 6 else "hit"
	if total == 13 or total == 14:
		return "double" if double_available and dealer_value >= 5 and dealer_value <= 6 else "hit"
	return "hit"


func _hard_strategy_action(total: int, dealer_value: int, double_available: bool) -> String:
	if total >= 17:
		return "stand"
	if total >= 13 and total <= 16:
		return "stand" if dealer_value >= 2 and dealer_value <= 6 else "hit"
	if total == 12:
		return "stand" if dealer_value >= 4 and dealer_value <= 6 else "hit"
	if total == 11:
		return "double" if double_available else "hit"
	if total == 10:
		return "double" if double_available and dealer_value >= 2 and dealer_value <= 9 else "hit"
	if total == 9:
		return "double" if double_available and dealer_value >= 3 and dealer_value <= 6 else "hit"
	return "hit"


func _dealer_strategy_value(card: Dictionary) -> int:
	var rank := _card_rank_value(card)
	if rank == RANK_ACE:
		return 11
	return mini(rank, 10)


func _all_player_hands_busted(session: Dictionary) -> bool:
	var hands: Array = _hand_array(session.get("player_hands", []))
	if hands.is_empty():
		return false
	for hand_value in hands:
		var hand: Dictionary = hand_value
		if not _is_bust(_card_array(hand.get("cards", []))):
			return false
	return true


func _hand_resolves_without_dealer_draw(hand: Dictionary) -> bool:
	if bool(hand.get("surrendered", false)):
		return true
	var cards: Array = _card_array(hand.get("cards", []))
	return _is_bust(cards) or _is_natural_blackjack(hand)


func _chip_bet_command(index: int, ui_state: Dictionary, table: Dictionary, run_state: RunState, environment: Dictionary, selected_stake: int) -> Dictionary:
	if _has_dealt_hand(ui_state):
		return _message_command(ui_state, "Main bets are locked until the hand settles.")
	var chips: Array = _chip_denominations(table)
	if index < 0 or index >= chips.size():
		return _message_command(ui_state, "That chip is not in your rack.")
	var chip_value: int = int(chips[index])
	var min_bet := _surface_stake_floor(run_state, environment)
	var max_stake: int = _max_table_stake_for_blackjack(ui_state, table, run_state, environment)
	var next_stake: int = min_bet if max_stake < min_bet else clampi(maxi(min_bet, selected_stake) + chip_value, min_bet, max_stake)
	ui_state["selected_stake"] = next_stake
	ui_state.erase("table_social_alignment")
	return GameModule.surface_command({
		"handled": true,
		"ui_state": ui_state,
		"set_stake": next_stake,
		"selected_index": index,
		"message": "You slide a $%d chip forward. Bet $%d." % [chip_value, next_stake],
	})


func _patron_bet_command(index: int, ui_state: Dictionary, table: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	if _has_dealt_hand(ui_state):
		return _message_command(ui_state, "Patron chip calls are only available before the deal.")
	var fade := index >= 100
	var patron_index := index % 100
	var patrons := _dictionary_array(table.get("patrons", []))
	if patron_index < 0 or patron_index >= patrons.size():
		return _message_command(ui_state, "That blackjack seat is empty.")
	var patron: Dictionary = patrons[patron_index]
	var wager := _blackjack_patron_wager(patron, table)
	var min_bet := _surface_stake_floor(run_state, environment)
	var max_bet := _max_table_stake_for_blackjack(ui_state, table, run_state, environment)
	var target_stake := int(wager.get("stake", min_bet))
	var active_side_bets := _string_array(ui_state.get("blackjack_side_bets", []))
	var available_side_bets := _available_side_bets_for_session(table, ui_state)
	var side_id := str(wager.get("side_bet_id", ""))
	if fade:
		match str(wager.get("style", "")):
			"side_action", "big_stack":
				target_stake = min_bet
				active_side_bets = []
			"minimum":
				target_stake = maxi(min_bet, target_stake * 3)
				if not available_side_bets.is_empty():
					active_side_bets = [str((available_side_bets[0] as Dictionary).get("id", ""))]
			_:
				target_stake = maxi(min_bet, target_stake * 2)
	else:
		if str(wager.get("style", "")) == "side_action" and not side_id.is_empty():
			if not active_side_bets.has(side_id):
				active_side_bets.append(side_id)
		elif str(wager.get("style", "")) != "side_action" and not side_id.is_empty():
			if not active_side_bets.has(side_id):
				active_side_bets.append(side_id)
	target_stake = clampi(target_stake, min_bet, max_bet)
	ui_state["selected_stake"] = target_stake
	ui_state["blackjack_side_bets"] = _valid_side_bet_ids_for_session(active_side_bets, table, ui_state)
	var total_cost := _wager_cost_from_session(target_stake, ui_state, table, run_state)
	if run_state != null and total_cost > run_state.bankroll:
		ui_state["blackjack_side_bets"] = []
		target_stake = clampi(min_bet, 1, max_bet)
		ui_state["selected_stake"] = target_stake
		total_cost = _wager_cost_from_session(target_stake, ui_state, table, run_state)
		if total_cost > run_state.bankroll:
			return _message_command(ui_state, "You do not have the bankroll to take that blackjack table action.")
	ui_state["table_social_alignment"] = {
		"game": "blackjack",
		"patron_id": str(patron.get("id", "patron_%d" % patron_index)),
		"patron_name": str(patron.get("name", "Patron")),
		"stance": "against" if fade else "with",
		"style": str(wager.get("style", "")),
		"stake": target_stake,
		"side_bets": ui_state["blackjack_side_bets"],
	}
	return GameModule.surface_command({
		"handled": true,
		"ui_state": ui_state,
		"set_stake": target_stake,
		"selected_index": patron_index,
		"message": "%s %s's blackjack posture. Main $%d, total risk $%d." % ["Fading" if fade else "Following", str(patron.get("name", "Patron")), target_stake, total_cost],
	})


func _blackjack_patron_wager(patron: Dictionary, table: Dictionary) -> Dictionary:
	var style := str(patron.get("bet_style", "flat_main"))
	var base_stake := maxi(1, int(patron.get("cosmetic_bet", maxi(1, int(patron.get("chip_stack", 20)) / 3))))
	var side_bets := _available_side_bets(table)
	var side_id := ""
	if not side_bets.is_empty():
		side_id = str((side_bets[0] as Dictionary).get("id", ""))
	var label := "MAIN"
	match style:
		"side_action":
			label = "SIDE"
		"big_stack":
			label = "PRESS"
			base_stake = maxi(base_stake, int(patron.get("chip_stack", 20)))
		"minimum":
			label = "MIN"
			base_stake = maxi(1, int(ceil(float(base_stake) * 0.5)))
		_:
			label = "MAIN"
	return {
		"id": style,
		"label": label,
		"stake": base_stake,
		"style": style,
		"side_bet_id": side_id if style == "side_action" else "",
	}


func _apply_patron_rapport_after_blackjack(table: Dictionary, session: Dictionary, table_stake: int, bankroll_delta: int) -> void:
	var patrons := _dictionary_array(table.get("patrons", []))
	if patrons.is_empty():
		return
	var alignment := _local_copy_dict(session.get("table_social_alignment", {}))
	var active_side_bets := _string_array(session.get("blackjack_side_bets", []))
	for i in range(patrons.size()):
		var patron: Dictionary = patrons[i]
		var wager := _blackjack_patron_wager(patron, table)
		var style := str(wager.get("style", "flat_main"))
		var patron_stake := maxi(1, int(wager.get("stake", 1)))
		var same := false
		var against := false
		match style:
			"side_action":
				same = not active_side_bets.is_empty()
				against = active_side_bets.is_empty()
			"big_stack":
				same = table_stake >= int(ceil(float(patron_stake) * 0.75))
				against = table_stake <= maxi(1, int(floor(float(patron_stake) * 0.4)))
			"minimum":
				same = table_stake <= maxi(1, patron_stake)
				against = table_stake >= patron_stake * 2
			_:
				same = abs(table_stake - patron_stake) <= maxi(2, int(ceil(float(patron_stake) * 0.25)))
				against = abs(table_stake - patron_stake) >= maxi(5, patron_stake)
		var delta := 0
		if same:
			delta += 2
		if against:
			delta -= 2
		if str(alignment.get("patron_id", "")) == str(patron.get("id", "patron_%d" % i)):
			delta += 4 if str(alignment.get("stance", "")) == "with" else -4
		if delta != 0:
			if bankroll_delta > 0 and same:
				delta += 1
			if bankroll_delta > 0 and against:
				delta -= 1
			patron["rapport"] = clampi(int(patron.get("rapport", 50)) + delta, 0, 100)
			patron["last_social_delta"] = delta
			patron["last_social_stance"] = "with" if delta > 0 else "against"
		else:
			patron["last_social_delta"] = 0
			patron["last_social_stance"] = "neutral"
		patrons[i] = patron
	table["patrons"] = patrons


func _max_table_stake_for_blackjack(session: Dictionary, table: Dictionary, run_state: RunState, environment: Dictionary = {}) -> int:
	var bankroll: int = _surface_stake_ceiling(run_state, environment)
	var probe: Dictionary = session.duplicate(true)
	var low := 1
	var high := bankroll
	var best := 1
	# Side-bet costs can round by stake, but total wager cost remains monotonic.
	# Binary search avoids a per-dollar scan when bankrolls get large.
	while low <= high:
		var stake := int(floor(float(low + high) * 0.5))
		if _wager_cost_from_session(stake, probe, table, run_state) <= bankroll:
			best = stake
			low = stake + 1
		else:
			high = stake - 1
	return best


func _effective_table_stake(stake: int, session: Dictionary, run_state: RunState, environment: Dictionary) -> int:
	if session.has("locked_stake"):
		return _session_stake(stake, session)
	var min_bet := _surface_stake_floor(run_state, environment)
	var max_bet := _surface_stake_ceiling(run_state, environment)
	if max_bet < min_bet:
		return min_bet
	return clampi(maxi(1, stake), min_bet, max_bet)


func _blackjack_original_stake_ceiling(run_state: RunState, environment: Dictionary) -> int:
	if run_state == null:
		return 1
	var profile: Dictionary = environment.get("economic_profile", {}) if typeof(environment.get("economic_profile", {})) == TYPE_DICTIONARY else {}
	return maxi(1, int(profile.get("stake_ceiling", run_state.bankroll)))


func _blackjack_base_stake_ceiling(run_state: RunState, environment: Dictionary) -> int:
	var base_ceiling := _blackjack_original_stake_ceiling(run_state, environment)
	var multiplier := maxi(1, _item_effect_total("blackjack_table_limit_multiplier", run_state))
	return maxi(1, base_ceiling * multiplier)


func _surface_stake_ceiling(run_state: RunState, environment: Dictionary) -> int:
	if run_state == null:
		return 1
	var base_ceiling: int = _blackjack_base_stake_ceiling(run_state, environment)
	var wager_ceiling: int = run_state.wager_stake_ceiling(base_ceiling)
	return maxi(1, mini(wager_ceiling, run_state.bankroll))


func _surface_stake_floor(run_state: RunState, environment: Dictionary) -> int:
	if run_state == null:
		return 1
	var profile: Dictionary = environment.get("economic_profile", {}) if typeof(environment.get("economic_profile", {})) == TYPE_DICTIONARY else {}
	var floor := maxi(1, int(profile.get("stake_floor", 1)))
	if _item_effect_total("blackjack_table_minimum_to_previous_max", run_state) > 0:
		floor = maxi(floor, _blackjack_original_stake_ceiling(run_state, environment))
	return floor


func _start_distraction_command(index: int, ui_state: Dictionary, table: Dictionary) -> Dictionary:
	var distractions: Array = _dictionary_array(table.get("distractions", []))
	if index < 0 or index >= distractions.size():
		return _message_command(ui_state, "That distraction is not available at this table.")
	var distraction: Dictionary = distractions[index]
	var now := Time.get_ticks_msec()
	var distraction_id := str(distraction.get("id", "distraction"))
	ui_state["dealer_lookaway_started_msec"] = now
	ui_state["dealer_lookaway_duration_msec"] = int(distraction.get("duration_msec", 2800))
	ui_state["dealer_lookaway_id"] = "%s:%s:%d" % [get_id(), distraction_id, now]
	ui_state["dealer_distraction_id"] = distraction_id
	ui_state["dealer_distraction_noise"] = int(distraction.get("noise", 0))
	ui_state["dealer_distraction_cover"] = int(distraction.get("cover", 0))
	return _message_command(ui_state, "%s opens a short peek window." % str(distraction.get("label", "Distraction")))


func _cover_patron_command(index: int, ui_state: Dictionary, table: Dictionary) -> Dictionary:
	var patrons: Array = _dictionary_array(table.get("patrons", []))
	if index < 0 or index >= patrons.size():
		return _message_command(ui_state, "That seat is empty.")
	var patron: Dictionary = patrons[index]
	var patron_id := str(patron.get("id", "patron_%d" % index))
	var cover: Dictionary = _local_copy_dict(ui_state.get("patron_cover", {}))
	cover[patron_id] = {
		"started_msec": Time.get_ticks_msec(),
		"duration_msec": 5200,
		"cover": 22,
	}
	ui_state["patron_cover"] = cover
	return _message_command(ui_state, "%s is busy watching your table talk." % str(patron.get("name", "Patron")))


func _toggle_side_bet_command(index: int, ui_state: Dictionary, table: Dictionary, run_state: RunState, source_state: Dictionary) -> Dictionary:
	var available: Array = _available_side_bets_for_session(table, ui_state)
	if index < 0 or index >= available.size():
		return _message_command(ui_state, "That side bet is not on this table.")
	var bet: Dictionary = available[index]
	if not _side_bet_can_toggle_now(bet, ui_state):
		return _message_command(ui_state, "That side bet is locked for this hand.")
	var bet_id := str(bet.get("id", ""))
	var active: Array = _string_array(ui_state.get("blackjack_side_bets", []))
	if active.has(bet_id):
		active.erase(bet_id)
	else:
		active.append(bet_id)
	ui_state["blackjack_side_bets"] = active
	ui_state.erase("table_social_alignment")
	var cost: int = _wager_cost_from_session(_session_stake(int(source_state.get("selected_stake", ui_state.get("selected_stake", 1))), ui_state), ui_state, table, run_state)
	return _message_command(ui_state, "%s %s. Total risk $%d." % [str(bet.get("label", bet_id)), "removed" if not active.has(bet_id) else "added", cost])


func _start_count_challenge(ui_state: Dictionary, table: Dictionary, run_state: RunState) -> void:
	var cards: Array = _visible_count_challenge_cards(ui_state)
	var icons: Array = []
	var now := Time.get_ticks_msec()
	var icon_duration := clampi(COUNT_ICON_DURATION_MSEC + _item_effect_total("blackjack_count_window_msec", run_state), 1800, 4600)
	var challenge_id := "%s:count:%d" % [get_id(), now]
	for i in range(cards.size()):
		var card_value: Variant = cards[i]
		var card: Dictionary = card_value
		var count_value := _count_value_for_card(card)
		if count_value == 0:
			continue
		var seed: int = abs(_stable_hash("%s:%s:%d" % [challenge_id, _count_icon_card_key(card), i]))
		var icon_pos := _count_icon_position_for_card(card, seed)
		icons.append({
			"id": "%s:%d" % [challenge_id, i],
			"card": card.duplicate(true),
			"count_value": count_value,
			"spawn_msec": now + 420 + icons.size() * COUNT_ICON_STAGGER_MSEC,
			"duration_msec": icon_duration,
			"x": icon_pos.x,
			"y": icon_pos.y,
		})
	var target_delta: int = _count_cards_delta(cards)
	var tracked_keys: Array = []
	for tracked_card_value in cards:
		if typeof(tracked_card_value) == TYPE_DICTIONARY:
			tracked_keys.append(_count_icon_card_key(tracked_card_value as Dictionary))
	ui_state["count_challenge"] = {
		"challenge_id": challenge_id,
		"cards": cards,
		"icons": icons,
		"tracked_card_keys": tracked_keys,
		"icon_serial": icons.size(),
		"clicked_icons": [],
		"missed_icons": [],
		"resolved_icon_msec": {},
		"bad_hits": 0,
		"correct_hits": 0,
		"target_delta": target_delta,
		"tolerance": maxi(0, _item_effect_total("blackjack_count_tolerance", run_state)),
		"dealer_attention_risk": clampi(18 + icons.size() * 5 - _item_effect_total("blackjack_count_cover", run_state), 4, 78),
		"recorded_delta": 0,
		"recorded_running_count_start": int(table.get("recorded_running_count", 0)),
		"running_count_start": int(table.get("running_count", 0)),
		"started_msec": now,
	}
	var cheats: Dictionary = _local_copy_dict(ui_state.get("cheats_used", {}))
	cheats["count_cards"] = true
	ui_state["cheats_used"] = cheats
	ui_state["count_attempted"] = true
	ui_state["count_answered"] = false
	ui_state["count_correct"] = false
	ui_state["count_perfect"] = false
	ui_state["count_delta"] = 0
	ui_state["count_declared_delta"] = 0


func _visible_count_challenge_cards(session: Dictionary) -> Array:
	var cards: Array = []
	var dealer_cards: Array = _card_array(session.get("dealer_cards", []))
	if not dealer_cards.is_empty():
		var dealer_up: Dictionary = (dealer_cards[0] as Dictionary).duplicate(true)
		dealer_up["_count_identity_key"] = _raw_count_icon_card_key(dealer_up)
		dealer_up["_count_source_key"] = "dealer:0:%s" % _raw_count_icon_card_key(dealer_up)
		cards.append(dealer_up)
	var hands: Array = _hand_array(session.get("player_hands", []))
	for hand_index in range(hands.size()):
		var hand_value: Variant = hands[hand_index]
		var hand: Dictionary = hand_value
		var hand_cards: Array = _card_array(hand.get("cards", []))
		for card_index in range(hand_cards.size()):
			var card_value: Variant = hand_cards[card_index]
			if typeof(card_value) == TYPE_DICTIONARY:
				var player_card: Dictionary = (card_value as Dictionary).duplicate(true)
				player_card["_count_identity_key"] = _raw_count_icon_card_key(player_card)
				player_card["_count_source_key"] = "player:%d:%d:%s" % [hand_index, card_index, _raw_count_icon_card_key(player_card)]
				cards.append(player_card)
	var patron_hands: Array = _hand_array(session.get("patron_hands", []))
	for patron_index in range(patron_hands.size()):
		var patron_hand: Dictionary = patron_hands[patron_index]
		var patron_cards: Array = _card_array(patron_hand.get("cards", []))
		for card_index in range(patron_cards.size()):
			var card_value: Variant = patron_cards[card_index]
			if typeof(card_value) == TYPE_DICTIONARY:
				var patron_card: Dictionary = (card_value as Dictionary).duplicate(true)
				patron_card["_count_identity_key"] = _raw_count_icon_card_key(patron_card)
				patron_card["_count_source_key"] = "patron:%d:%d:%s" % [patron_index, card_index, _raw_count_icon_card_key(patron_card)]
				cards.append(patron_card)
	if bool(session.get("dealer_hole_visible", false)) and dealer_cards.size() > 1:
		for dealer_index in range(1, dealer_cards.size()):
			var dealer_reveal: Dictionary = (dealer_cards[dealer_index] as Dictionary).duplicate(true)
			dealer_reveal["_count_identity_key"] = _raw_count_icon_card_key(dealer_reveal)
			dealer_reveal["_count_source_key"] = "dealer:%d:%s" % [dealer_index, _raw_count_icon_card_key(dealer_reveal)]
			cards.append(dealer_reveal)
	return cards


func _hit_count_icon(index: int, ui_state: Dictionary, table: Dictionary, _run_state: RunState) -> Dictionary:
	_sync_count_challenge_icons(ui_state, _run_state)
	var challenge: Dictionary = _local_copy_dict(ui_state.get("count_challenge", {}))
	if challenge.is_empty():
		return _message_command(ui_state, "Start the count first.")
	if bool(ui_state.get("count_answered", false)):
		return _message_command(ui_state, "Count already recorded.")
	var now_msec := Time.get_ticks_msec()
	challenge = _refresh_count_challenge_misses(challenge, now_msec)
	var icons: Array = _dictionary_array(challenge.get("icons", []))
	if index < 0 or index >= icons.size():
		challenge["bad_hits"] = int(challenge.get("bad_hits", 0)) + 1
		challenge["dealer_attention_risk"] = clampi(int(challenge.get("dealer_attention_risk", 24)) + 10, 0, 100)
		ui_state["count_challenge"] = challenge
		return _message_command(ui_state, "You reach for a count marker that is not there.")
	var icon: Dictionary = icons[index]
	var icon_id := str(icon.get("id", "icon_%d" % index))
	var clicked: Array = _string_array(challenge.get("clicked_icons", []))
	var missed: Array = _string_array(challenge.get("missed_icons", []))
	var resolved_times: Dictionary = _local_copy_dict(challenge.get("resolved_icon_msec", {}))
	if clicked.has(icon_id):
		ui_state["count_challenge"] = challenge
		return _message_command(ui_state, "That count pulse is already locked.")
	if missed.has(icon_id):
		challenge["bad_hits"] = int(challenge.get("bad_hits", 0)) + 1
		challenge["dealer_attention_risk"] = clampi(int(challenge.get("dealer_attention_risk", 24)) + 8, 0, 100)
		ui_state["count_challenge"] = challenge
		return _message_command(ui_state, "Too late. That card already slipped the count.")
	var spawn := int(icon.get("spawn_msec", now_msec))
	var duration := int(icon.get("duration_msec", COUNT_ICON_DURATION_MSEC))
	if now_msec < spawn or now_msec > spawn + duration:
		challenge["bad_hits"] = int(challenge.get("bad_hits", 0)) + 1
		challenge["dealer_attention_risk"] = clampi(int(challenge.get("dealer_attention_risk", 24)) + 8, 0, 100)
		ui_state["count_challenge"] = challenge
		return _message_command(ui_state, "The timing is off. The dealer's eyes flick to your hands.")
	clicked.append(icon_id)
	var delta := int(ui_state.get("count_delta", int(challenge.get("recorded_delta", 0)))) + int(icon.get("count_value", 0))
	challenge["clicked_icons"] = clicked
	resolved_times[icon_id] = now_msec
	challenge["resolved_icon_msec"] = resolved_times
	challenge["recorded_delta"] = delta
	challenge["correct_hits"] = int(challenge.get("correct_hits", 0)) + 1
	ui_state["count_delta"] = delta
	ui_state["count_declared_delta"] = delta
	ui_state["count_challenge"] = challenge
	return _message_command(ui_state, "Count pulse %+d locked. Hand delta %+d; shoe count %+d." % [
		int(icon.get("count_value", 0)),
		delta,
		int(table.get("recorded_running_count", 0)) + delta,
	])


func _refresh_count_challenge_misses(challenge: Dictionary, now_msec: int) -> Dictionary:
	var next_challenge := challenge.duplicate(true)
	var clicked: Array = _string_array(next_challenge.get("clicked_icons", []))
	var missed: Array = _string_array(next_challenge.get("missed_icons", []))
	var resolved_times: Dictionary = _local_copy_dict(next_challenge.get("resolved_icon_msec", {}))
	var added := 0
	var added_risk := 0
	for icon_value in _dictionary_array(next_challenge.get("icons", [])):
		var icon: Dictionary = icon_value
		var icon_id := str(icon.get("id", ""))
		if icon_id.is_empty() or clicked.has(icon_id) or missed.has(icon_id):
			continue
		var spawn := int(icon.get("spawn_msec", now_msec))
		var duration := int(icon.get("duration_msec", COUNT_ICON_DURATION_MSEC))
		if now_msec > spawn + duration:
			missed.append(icon_id)
			resolved_times[icon_id] = now_msec
			added += 1
			added_risk += 8
	if added > 0:
		next_challenge["missed_icons"] = missed
		next_challenge["resolved_icon_msec"] = resolved_times
		next_challenge["misses"] = int(next_challenge.get("misses", 0)) + added
		next_challenge["dealer_attention_risk"] = clampi(int(next_challenge.get("dealer_attention_risk", 24)) + added_risk, 0, 100)
	return next_challenge


func _count_missed_icon_ids(challenge: Dictionary, now_msec: int) -> Array:
	var snapshot: Dictionary = _refresh_count_challenge_misses(challenge, now_msec)
	return _string_array(snapshot.get("missed_icons", []))


func _mark_unresolved_count_icons_missed(challenge: Dictionary, now_msec: int) -> Dictionary:
	var next_challenge := challenge.duplicate(true)
	var clicked: Array = _string_array(next_challenge.get("clicked_icons", []))
	var missed: Array = _string_array(next_challenge.get("missed_icons", []))
	var resolved_times: Dictionary = _local_copy_dict(next_challenge.get("resolved_icon_msec", {}))
	var added := 0
	var added_risk := 0
	for icon_value in _dictionary_array(next_challenge.get("icons", [])):
		var icon: Dictionary = icon_value
		var icon_id := str(icon.get("id", ""))
		if icon_id.is_empty() or clicked.has(icon_id) or missed.has(icon_id):
			continue
		missed.append(icon_id)
		resolved_times[icon_id] = now_msec
		added += 1
		added_risk += 8
	if added > 0:
		next_challenge["missed_icons"] = missed
		next_challenge["resolved_icon_msec"] = resolved_times
		next_challenge["misses"] = int(next_challenge.get("misses", 0)) + added
		next_challenge["dealer_attention_risk"] = clampi(int(next_challenge.get("dealer_attention_risk", 24)) + added_risk, 0, 100)
	return next_challenge


func _count_missed_nonzero_icons(challenge: Dictionary) -> int:
	var missed: Array = _string_array(challenge.get("missed_icons", []))
	if missed.is_empty():
		return 0
	var count := 0
	for icon_value in _dictionary_array(challenge.get("icons", [])):
		var icon: Dictionary = icon_value
		if missed.has(str(icon.get("id", ""))) and int(icon.get("count_value", 0)) != 0:
			count += 1
	return count


func _sync_count_challenge_icons(ui_state: Dictionary, run_state: RunState) -> int:
	var challenge: Dictionary = _local_copy_dict(ui_state.get("count_challenge", {}))
	if challenge.is_empty() or bool(ui_state.get("count_answered", false)):
		return 0
	var cards: Array = _dictionary_array(challenge.get("cards", []))
	var icons: Array = _dictionary_array(challenge.get("icons", []))
	var tracked_keys: Array = _string_array(challenge.get("tracked_card_keys", []))
	if tracked_keys.is_empty():
		for card_value in cards:
			if typeof(card_value) == TYPE_DICTIONARY:
				tracked_keys.append(_count_icon_card_key(card_value as Dictionary))
	var now_msec := Time.get_ticks_msec()
	var icon_duration := clampi(COUNT_ICON_DURATION_MSEC + _item_effect_total("blackjack_count_window_msec", run_state), 1800, 4600)
	var challenge_id := str(challenge.get("challenge_id", "%s:count:%d" % [get_id(), now_msec]))
	var serial := int(challenge.get("icon_serial", icons.size()))
	var added := 0
	for card_value in _visible_count_challenge_cards(ui_state):
		if typeof(card_value) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = (card_value as Dictionary).duplicate(true)
		var key := _count_icon_card_key(card)
		if tracked_keys.has(key):
			continue
		tracked_keys.append(key)
		cards.append(card.duplicate(true))
		var count_value := _count_value_for_card(card)
		if count_value == 0:
			continue
		var seed: int = abs(_stable_hash("%s:%s:%d" % [challenge_id, key, serial]))
		var icon_pos := _count_icon_position_for_card(card, seed)
		icons.append({
			"id": "%s:%d" % [challenge_id, serial],
			"card": card.duplicate(true),
			"count_value": count_value,
			"spawn_msec": now_msec + 240 + added * COUNT_ICON_STAGGER_MSEC,
			"duration_msec": icon_duration,
			"x": icon_pos.x,
			"y": icon_pos.y,
		})
		serial += 1
		added += 1
	challenge["cards"] = cards
	challenge["icons"] = icons
	challenge["tracked_card_keys"] = tracked_keys
	challenge["icon_serial"] = serial
	challenge["target_delta"] = _count_cards_delta(cards)
	ui_state["count_challenge"] = challenge
	return added


func _count_has_new_misses(challenge: Dictionary, now_msec: int) -> bool:
	if challenge.is_empty():
		return false
	var missed_before: Array = _string_array(challenge.get("missed_icons", []))
	var refreshed: Dictionary = _refresh_count_challenge_misses(challenge, now_msec)
	var missed_after: Array = _string_array(refreshed.get("missed_icons", []))
	return missed_after.size() > missed_before.size()


func _update_live_count_state(ui_state: Dictionary, _table: Dictionary, run_state: RunState, announce: bool = true) -> String:
	var challenge: Dictionary = _local_copy_dict(ui_state.get("count_challenge", {}))
	if challenge.is_empty() or bool(ui_state.get("count_answered", false)):
		ui_state.erase("count_live_notice")
		return ""
	_sync_count_challenge_icons(ui_state, run_state)
	challenge = _local_copy_dict(ui_state.get("count_challenge", {}))
	var missed_before: int = (_string_array(challenge.get("missed_icons", []))).size()
	var now_msec := Time.get_ticks_msec()
	challenge = _refresh_count_challenge_misses(challenge, now_msec)
	var missed_after: int = (_string_array(challenge.get("missed_icons", []))).size()
	ui_state["count_challenge"] = challenge
	if missed_after <= missed_before:
		ui_state.erase("count_live_notice")
		return ""
	var new_misses: int = missed_after - missed_before
	ui_state["count_miss_suspicion"] = int(ui_state.get("count_miss_suspicion", 0)) + new_misses * 2
	var notice := "A count symbol slips by. Dealer suspicion rises." if new_misses == 1 else "%d count symbols slip by. Dealer suspicion rises." % new_misses
	if announce:
		ui_state["count_live_notice"] = notice
		ui_state["table_notice"] = notice
	return notice


func _finalize_count_challenge(ui_state: Dictionary, run_state: RunState) -> void:
	_sync_count_challenge_icons(ui_state, run_state)
	var challenge: Dictionary = _local_copy_dict(ui_state.get("count_challenge", {}))
	if challenge.is_empty():
		return
	var now_msec := Time.get_ticks_msec()
	challenge = _refresh_count_challenge_misses(challenge, now_msec)
	challenge = _mark_unresolved_count_icons_missed(challenge, now_msec)
	var target := int(challenge.get("target_delta", 0))
	var declared := int(ui_state.get("count_delta", int(challenge.get("recorded_delta", 0))))
	var clicked: Array = _string_array(challenge.get("clicked_icons", []))
	var missed: Array = _string_array(challenge.get("missed_icons", []))
	var icons: Array = _dictionary_array(challenge.get("icons", []))
	var tolerance := maxi(0, int(challenge.get("tolerance", 0)))
	var bad_hits := int(challenge.get("bad_hits", 0))
	var missed_value_count := _count_missed_nonzero_icons(challenge)
	var correct: bool = abs(declared - target) <= tolerance and missed_value_count == 0 and bad_hits == 0
	var perfect: bool = correct and clicked.size() == icons.size()
	challenge["finalized_msec"] = now_msec
	challenge["final_delta"] = declared
	challenge["correct"] = correct
	challenge["perfect"] = perfect
	ui_state["count_challenge"] = challenge
	ui_state["count_answered"] = true
	ui_state["count_correct"] = correct
	ui_state["count_perfect"] = perfect
	ui_state["count_delta"] = declared
	ui_state["count_declared_delta"] = declared


func _count_icon_card_key(card: Dictionary) -> String:
	var identity_key := str(card.get("_count_identity_key", ""))
	if not identity_key.is_empty():
		return identity_key
	var source_key := str(card.get("_count_source_key", ""))
	if not source_key.is_empty():
		return source_key
	return _raw_count_icon_card_key(card)


func _count_icon_position_for_card(card: Dictionary, seed: int) -> Vector2:
	var source_key := str(card.get("_count_source_key", ""))
	var parts := source_key.split(":")
	if parts.size() >= 2:
		match str(parts[0]):
			"dealer":
				return _dealer_card_target(int(parts[1])) + Vector2(18, -20)
			"player":
				if parts.size() >= 3:
					return _player_hand_card_target(int(parts[1]), int(parts[2])) + Vector2(20, -18)
			"patron":
				if parts.size() >= 3:
					return _patron_hand_card_target(int(parts[1]), int(parts[2])) + Vector2(10, -13)
	return Vector2(190.0 + float(seed % 500), 118.0 + float((int(seed / 17) % 128)))


func _raw_count_icon_card_key(card: Dictionary) -> String:
	return "%d:%d:%d" % [int(card.get("rank", 2)), int(card.get("suit", 0)), int(card.get("deck", 0))]


func _count_value_for_card(card: Dictionary) -> int:
	var rank: int = _card_rank_value(card)
	if rank >= 2 and rank <= 6:
		return 1
	if rank == 10 or rank == 11 or rank == 12 or rank == 13 or rank == RANK_ACE:
		return -1
	return 0


func _selected_surface_actions(ui_state: Dictionary, session: Dictionary) -> Array:
	var selected: Array = []
	var action_id := str(ui_state.get("selected_action_id", ""))
	var action_kind := str(ui_state.get("selected_action_kind", ""))
	if action_id == "play_basic" and action_kind == "legal":
		selected.append("blackjack_deal")
		if _has_dealt_hand(session):
			selected.append("blackjack_stand")
	if action_id == "peek_hole_card" and action_kind == "cheat":
		selected.append("blackjack_peek")
	if bool(session.get("counting_enabled", false)):
		selected.append("blackjack_count_toggle")
	if bool(session.get("dealer_hole_visible", false)):
		selected.append("blackjack_peek")
	return selected


func _can_hit(session: Dictionary) -> bool:
	var hand: Dictionary = _active_hand(session)
	if hand.is_empty() or bool(hand.get("stood", false)) or bool(hand.get("doubled", false)):
		return false
	var cards: Array = _card_array(hand.get("cards", []))
	return _hand_total(cards) < 21


func _can_stand(session: Dictionary) -> bool:
	var hand: Dictionary = _active_hand(session)
	if hand.is_empty() or bool(hand.get("stood", false)) or bool(hand.get("doubled", false)):
		return false
	var cards: Array = _card_array(hand.get("cards", []))
	var total := _hand_total(cards)
	return total > 0 and total < 21


func _can_double(session: Dictionary, table: Dictionary, stake: int = 1, run_state: RunState = null) -> bool:
	var hand: Dictionary = _active_hand(session)
	if hand.is_empty() or bool(hand.get("stood", false)) or bool(hand.get("doubled", false)):
		return false
	var cards: Array = _card_array(hand.get("cards", []))
	if cards.size() != 2:
		return false
	if bool(hand.get("split", false)) and not bool(_table_rules(table).get("double_after_split", true)):
		return false
	if not _can_afford_extra_main_wager(session, table, run_state, stake, 1):
		return false
	return _hand_total(cards) < 21


func _can_split(session: Dictionary, table: Dictionary, stake: int = 1, run_state: RunState = null) -> bool:
	var hands: Array = _hand_array(session.get("player_hands", []))
	# Re-splitting non-ace pairs is allowed until the table's max hand count.
	if hands.size() >= int(_table_rules(table).get("max_split_hands", 4)):
		return false
	var hand: Dictionary = _active_hand(session)
	if hand.is_empty() or bool(hand.get("stood", false)):
		return false
	var cards: Array = _card_array(hand.get("cards", []))
	return cards.size() == 2 and _card_split_value(cards[0]) == _card_split_value(cards[1]) and _can_afford_extra_main_wager(session, table, run_state, stake, 1)


func _can_surrender(session: Dictionary, table: Dictionary) -> bool:
	if not bool(_table_rules(table).get("late_surrender", true)):
		return false
	# Surrender is late surrender only: the opening hand before any other move,
	# unavailable after splits/doubles/hits and after a dealer blackjack check.
	if bool(session.get("moves_made", false)) or int(session.get("split_count", 0)) > 0:
		return false
	var hands: Array = _hand_array(session.get("player_hands", []))
	if hands.size() != 1:
		return false
	var hand: Dictionary = _active_hand(session)
	if hand.is_empty() or bool(hand.get("stood", false)) or bool(hand.get("doubled", false)) or bool(hand.get("split", false)):
		return false
	if _dealer_has_blackjack(_card_array(session.get("dealer_cards", []))):
		return false
	return _card_array(hand.get("cards", [])).size() == 2


func _can_afford_extra_main_wager(session: Dictionary, table: Dictionary, run_state: RunState, stake: int, extra_units: int) -> bool:
	if run_state == null:
		return true
	var projected_cost: int = _wager_cost_from_session(stake, session, table, run_state) + maxi(1, stake) * maxi(0, extra_units)
	return projected_cost <= maxi(0, run_state.bankroll)


func _can_change_side_bets(session: Dictionary) -> bool:
	return not bool(session.get("moves_made", false)) and int(session.get("split_count", 0)) <= 0


func _side_bet_can_toggle_now(bet: Dictionary, session: Dictionary) -> bool:
	if not _can_change_side_bets(session):
		return false
	if not _has_dealt_hand(session):
		return true
	return str(bet.get("id", "")) == "insurance"


func _all_hands_complete(session: Dictionary) -> bool:
	var hands: Array = _hand_array(session.get("player_hands", []))
	if hands.is_empty():
		return false
	for hand_value in hands:
		var hand: Dictionary = hand_value
		if bool(hand.get("stood", false)):
			continue
		if _hand_total(_card_array(hand.get("cards", []))) >= 21:
			continue
		return false
	return true


func _active_hand(session: Dictionary) -> Dictionary:
	var hands: Array = _hand_array(session.get("player_hands", []))
	var active_index: int = clampi(int(session.get("active_hand_index", 0)), 0, maxi(0, hands.size() - 1))
	if active_index < 0 or active_index >= hands.size():
		return {}
	return (hands[active_index] as Dictionary).duplicate(true)


func _main_wager_cost(stake: int, session: Dictionary) -> int:
	if bool(session.get("blackjack_sit_out", false)):
		return 0
	var cost := 0
	var hands: Array = _hand_array(session.get("player_hands", []))
	if hands.is_empty():
		return maxi(1, stake)
	for hand_value in hands:
		var hand: Dictionary = hand_value
		cost += maxi(1, stake) * maxi(1, int(hand.get("wager_multiplier", 1)))
	return cost


func _wager_cost_from_session(stake: int, session: Dictionary, table: Dictionary, run_state: RunState) -> int:
	var cost: int = _main_wager_cost(stake, session)
	var active_ids: Array = _string_array(session.get("blackjack_side_bets", []))
	for bet in _available_side_bets_for_session(table, session):
		var bet_id := str((bet as Dictionary).get("id", ""))
		if active_ids.has(bet_id):
			var side_stake: int = _side_bet_stake(stake, bet, run_state)
			var reduction: int = _item_effect_total("blackjack_side_bet_loss_reduction", run_state)
			cost += maxi(0, side_stake - reduction)
	return cost


func _side_bet_stake(stake: int, bet: Dictionary, run_state: RunState) -> int:
	var bet_id := str(bet.get("id", ""))
	if bet_id == "insurance":
		return maxi(1, int(ceil(float(maxi(1, stake)) * 0.5)))
	var base_stake := maxi(1, int(ceil(float(maxi(1, stake)) * 0.25)))
	if bet_id == "lucky_ladies":
		base_stake *= maxi(1, _item_effect_total("blackjack_lucky_ladies_stake_multiplier", run_state))
	return base_stake


func _side_bet_catalog() -> Array:
	return [
		{"id": "perfect_pairs", "label": "Perfect Pairs", "summary": "Pair first two cards; suited pair pays big", "rules": ["Your first two cards must share a rank.", "Result is checked from the original deal only."], "payouts": ["mixed pair 5:1", "colored pair 10:1", "perfect pair 25:1"]},
		{"id": "twenty_one_three", "label": "21+3", "summary": "Your two plus dealer upcard as poker hand", "rules": ["Your first two cards plus dealer upcard form a 3-card poker hand.", "Only the opening upcard is used."], "payouts": ["flush 5:1", "straight 10:1", "trips 30:1", "straight flush 40:1", "suited trips 100:1"]},
		{"id": "lucky_ladies", "label": "Lucky Ladies", "summary": "First two cards total 20; queens pay more", "rules": ["Your first two cards must total 20.", "Queen bonuses use the opening two cards."], "payouts": ["twenty 4:1", "suited twenty 10:1", "suited queens 125:1", "queen hearts plus dealer blackjack 200:1"]},
		{"id": "royal_match", "label": "Royal Match", "summary": "Suited first two; suited KQ pays big", "rules": ["Your first two cards must share a suit.", "King-queen suited upgrades the win."], "payouts": ["suited match 3:1", "royal match 25:1"]},
		{"id": "insurance", "label": "Insurance", "summary": "Dealer blackjack pays 2:1", "rules": ["Only offered when dealer upcard is an ace.", "Costs half the main wager."], "payouts": ["dealer blackjack 2:1", "dealer safe loses"]},
		{"id": "buster", "label": "Buster", "summary": "Dealer busts; more dealer cards pay more", "rules": ["Wins only if the dealer busts.", "Payout improves with longer dealer bust hands."], "payouts": ["dealer bust 2:1", "5-card bust 8:1", "6-card bust 25:1", "7-card bust 100:1"]},
	]


func _normalize_side_bets(value: Variant) -> Array:
	var source: Array = _dictionary_array(value)
	if source.is_empty():
		source = _side_bet_catalog().slice(0, BLACKJACK_MAX_SIDE_BETS)
	var result: Array = []
	for bet_value in source:
		if result.size() >= BLACKJACK_MAX_SIDE_BETS:
			break
		var bet: Dictionary = bet_value
		var bet_id := str(bet.get("id", ""))
		if bet_id.is_empty() or _side_bet_index_in_list(result, bet_id) >= 0:
			continue
		var normalized: Dictionary = _side_bet_definition(bet_id)
		for key in bet.keys():
			normalized[str(key)] = bet[key]
		if _string_array(normalized.get("rules", [])).is_empty():
			normalized["rules"] = _side_bet_definition(bet_id).get("rules", [])
		if _string_array(normalized.get("payouts", [])).is_empty():
			normalized["payouts"] = _side_bet_definition(bet_id).get("payouts", [])
		result.append(normalized)
	if result.is_empty():
		result = _side_bet_catalog().slice(0, BLACKJACK_MAX_SIDE_BETS)
	return result


func _side_bet_definition(bet_id: String) -> Dictionary:
	for bet_value in _side_bet_catalog():
		if typeof(bet_value) == TYPE_DICTIONARY and str((bet_value as Dictionary).get("id", "")) == bet_id:
			return (bet_value as Dictionary).duplicate(true)
	return {"id": bet_id, "label": bet_id.replace("_", " ").capitalize(), "summary": "Opening side bet", "rules": ["Settles from blackjack table state."], "payouts": ["see table result"]}


func _side_bet_index_in_list(side_bets: Array, bet_id: String) -> int:
	for i in range(side_bets.size()):
		if typeof(side_bets[i]) == TYPE_DICTIONARY and str((side_bets[i] as Dictionary).get("id", "")) == bet_id:
			return i
	return -1


func _available_side_bets(table: Dictionary) -> Array:
	return _normalize_side_bets(table.get("side_bets", []))


func _available_side_bets_for_session(table: Dictionary, session: Dictionary) -> Array:
	var result: Array = []
	for bet_value in _available_side_bets(table):
		var bet: Dictionary = bet_value
		if _side_bet_currently_available(bet, session):
			result.append(bet)
	if _insurance_offer_available(session) and _side_bet_index_in_list(result, "insurance") < 0:
		result.append(_side_bet_definition("insurance"))
	return result


func _item_adjusted_side_bet_for_surface(bet: Dictionary, run_state: RunState) -> Dictionary:
	var adjusted := bet.duplicate(true)
	if str(adjusted.get("id", "")) != "lucky_ladies":
		return adjusted
	var stake_multiplier := maxi(1, _item_effect_total("blackjack_lucky_ladies_stake_multiplier", run_state))
	var payout_multiplier := maxi(1, _item_effect_total("blackjack_lucky_ladies_payout_multiplier", run_state))
	if stake_multiplier <= 1 and payout_multiplier <= 1:
		return adjusted
	adjusted["item_boosted"] = true
	adjusted["summary"] = "Compact active: double stake, double listed payouts"
	adjusted["rules"] = ["Costs twice the normal side bet.", "Wins pay double Lucky Ladies odds."]
	adjusted["payouts"] = ["twenty 8:1", "suited twenty 20:1", "suited queens 250:1", "queen hearts plus dealer blackjack 400:1"]
	return adjusted


func _side_bet_currently_available(bet: Dictionary, session: Dictionary) -> bool:
	var bet_id := str(bet.get("id", ""))
	if bet_id == "insurance":
		return _insurance_offer_available(session)
	return true


func _insurance_offer_available(session: Dictionary) -> bool:
	var dealer_cards: Array = _card_array(session.get("initial_dealer_cards", session.get("dealer_cards", [])))
	return not dealer_cards.is_empty() and _card_rank_value(dealer_cards[0]) == RANK_ACE


func _valid_side_bet_ids_for_session(ids: Array, table: Dictionary, session: Dictionary) -> Array:
	var valid := {}
	for bet in _available_side_bets_for_session(table, session):
		valid[str((bet as Dictionary).get("id", ""))] = true
	var result: Array = []
	for id_value in ids:
		var id := str(id_value)
		if valid.has(id) and not result.has(id):
			result.append(id)
	return result


func _perfect_pairs_payout(player_cards: Array) -> Dictionary:
	if player_cards.size() < 2 or _card_rank_value(player_cards[0]) != _card_rank_value(player_cards[1]):
		return {"payout": 0, "detail": "miss"}
	var suit_a := _card_suit_value(player_cards[0])
	var suit_b := _card_suit_value(player_cards[1])
	var suit_a_red := suit_a == 1 or suit_a == 2
	var suit_b_red := suit_b == 1 or suit_b == 2
	var same_color := suit_a_red == suit_b_red
	if suit_a == suit_b:
		return {"payout": 25, "detail": "perfect pair"}
	if same_color:
		return {"payout": 10, "detail": "colored pair"}
	return {"payout": 5, "detail": "mixed pair"}


func _twenty_one_three_payout(player_cards: Array, dealer_cards: Array) -> Dictionary:
	if player_cards.size() < 2 or dealer_cards.is_empty():
		return {"payout": 0, "detail": "miss"}
	var cards: Array = [player_cards[0], player_cards[1], dealer_cards[0]]
	var flush := _same_suit(cards)
	var trips := _same_rank(cards)
	var straight := _three_card_straight(cards)
	if trips and flush:
		return {"payout": 100, "detail": "suited trips"}
	if straight and flush:
		return {"payout": 40, "detail": "straight flush"}
	if trips:
		return {"payout": 30, "detail": "three of a kind"}
	if straight:
		return {"payout": 10, "detail": "straight"}
	if flush:
		return {"payout": 5, "detail": "flush"}
	return {"payout": 0, "detail": "miss"}


func _lucky_ladies_payout(player_cards: Array, dealer_cards: Array) -> Dictionary:
	if player_cards.size() < 2 or _card_blackjack_value(player_cards[0]) + _card_blackjack_value(player_cards[1]) != 20:
		return {"payout": 0, "detail": "miss"}
	var both_queens := _card_rank_value(player_cards[0]) == 12 and _card_rank_value(player_cards[1]) == 12
	var suited := _card_suit_value(player_cards[0]) == _card_suit_value(player_cards[1])
	if both_queens and _card_suit_value(player_cards[0]) == 1 and _card_suit_value(player_cards[1]) == 1 and _dealer_has_blackjack(dealer_cards):
		return {"payout": 200, "detail": "queen hearts with dealer blackjack"}
	if both_queens and suited:
		return {"payout": 125, "detail": "suited queens"}
	if suited:
		return {"payout": 10, "detail": "suited twenty"}
	return {"payout": 4, "detail": "twenty"}


func _royal_match_payout(player_cards: Array) -> Dictionary:
	if player_cards.size() < 2 or _card_suit_value(player_cards[0]) != _card_suit_value(player_cards[1]):
		return {"payout": 0, "detail": "miss"}
	var ranks: Array = [_card_rank_value(player_cards[0]), _card_rank_value(player_cards[1])]
	if ranks.has(13) and ranks.has(12):
		return {"payout": 25, "detail": "royal match"}
	return {"payout": 3, "detail": "suited match"}


func _insurance_payout(dealer_cards: Array) -> Dictionary:
	if dealer_cards.is_empty() or _card_rank_value(dealer_cards[0]) != RANK_ACE:
		return {"payout": 0, "detail": "dealer upcard not ace"}
	return {"payout": 2 if _dealer_has_blackjack(dealer_cards) else 0, "detail": "dealer blackjack" if _dealer_has_blackjack(dealer_cards) else "dealer safe"}


func _buster_payout(dealer_cards: Array) -> Dictionary:
	if _hand_total(dealer_cards) <= 21:
		return {"payout": 0, "detail": "dealer did not bust"}
	var count := dealer_cards.size()
	if count >= 7:
		return {"payout": 100, "detail": "seven-card dealer bust"}
	if count == 6:
		return {"payout": 25, "detail": "six-card dealer bust"}
	if count == 5:
		return {"payout": 8, "detail": "five-card dealer bust"}
	return {"payout": 2, "detail": "dealer bust"}


func _table_rules(table: Dictionary) -> Dictionary:
	var rules: Dictionary = table.get("rules", {}) if typeof(table.get("rules", {})) == TYPE_DICTIONARY else {}
	return {
		"dealer_hits_soft_17": bool(rules.get("dealer_hits_soft_17", false)),
		"double_after_split": bool(rules.get("double_after_split", true)),
		"split_aces_one_card": bool(rules.get("split_aces_one_card", true)),
		"max_split_hands": clampi(int(rules.get("max_split_hands", 4)), 2, 4),
		"late_surrender": bool(rules.get("late_surrender", true)),
		"blackjack_payout": BLACKJACK_PAYOUT_LABEL,
		"insurance_policy": "offered_on_dealer_ace",
	}


func _table_summary(table: Dictionary) -> String:
	var rules: Dictionary = _table_rules(table)
	return "%s blackjack, %s, count %s, %s, split to %d, aces one-card, dealer %s soft 17%s, insurance on ace." % [
		BLACKJACK_PAYOUT_LABEL,
		str(table.get("shoe_label", CardShoeScript.shoe_label(int(table.get("deck_count", 6))))),
		str(table.get("count_efficiency", CardShoeScript.count_efficiency_label(int(table.get("deck_count", 6))))),
		"DAS" if bool(rules.get("double_after_split", true)) else "no DAS",
		int(rules.get("max_split_hands", 4)),
		"hits" if bool(rules.get("dealer_hits_soft_17", false)) else "stands on",
		", surrender" if bool(rules.get("late_surrender", true)) else "",
	]


func _table_rules_text(surface_state: Dictionary) -> String:
	var rules: Dictionary = surface_state.get("rules", {}) if typeof(surface_state.get("rules", {})) == TYPE_DICTIONARY else {}
	return "%s %s %s split%d A1%s Ins / Risk $%d / %s %d" % [
		str(rules.get("blackjack_payout", BLACKJACK_PAYOUT_LABEL)),
		"H17" if bool(rules.get("dealer_hits_soft_17", false)) else "S17",
		"DAS" if bool(rules.get("double_after_split", true)) else "noDAS",
		int(rules.get("max_split_hands", 4)),
		" / LS" if bool(rules.get("late_surrender", true)) else "",
		int(surface_state.get("total_wager_cost", 0)),
		str(surface_state.get("shoe_label", "shoe")),
		int(surface_state.get("shoe_remaining", 0)),
	]


func _dealer_lookaway_active(session: Dictionary) -> bool:
	var started := int(session.get("dealer_lookaway_started_msec", 0))
	var duration := int(session.get("dealer_lookaway_duration_msec", 0))
	if started <= 0 or duration <= 0:
		return false
	return Time.get_ticks_msec() <= started + duration


func _dealer_peek_window_open(table: Dictionary, session: Dictionary, run_state: RunState) -> bool:
	return bool(_dealer_focus_state(table, session, run_state).get("peek_window_open", false))


func _dealer_focus_state(table: Dictionary, session: Dictionary, run_state: RunState, patron_snitch_risk: int = -1) -> Dictionary:
	var profile: Dictionary = _local_copy_dict(table.get("dealer_profile", {}))
	var base_attention: int = int(profile.get("attention_base", int(table.get("dealer_catch_base", 10)) + 12))
	var heat: int = run_state.suspicion_level() if run_state != null else 0
	var started := int(session.get("dealer_lookaway_started_msec", 0))
	var duration := int(session.get("dealer_lookaway_duration_msec", 0))
	var now := Time.get_ticks_msec()
	var active := started > 0 and duration > 0 and now <= started + duration
	var remaining := maxi(0, started + duration - now) if active else 0
	var cycle_msec := maxi(900, int(320000 / maxi(45, int(profile.get("gaze_speed", 95)))))
	var phase := float((now + int(profile.get("blink_offset", 0))) % cycle_msec) / float(cycle_msec)
	var sweep := sin(phase * PI * 2.0)
	var scan_attention := int((0.5 + 0.5 * sweep) * 18.0)
	var challenge: Dictionary = _local_copy_dict(session.get("count_challenge", {}))
	var count_pressure := 0 if challenge.is_empty() or bool(session.get("count_answered", false)) else int(float(int(challenge.get("dealer_attention_risk", 0))) / 4.0)
	var strategy_pressure := clampi(int(table.get("strategy_watch_pressure", 0)) + int(session.get("strategy_attention_boost", 0)), 0, STRATEGY_DEVIATION_MAX_WATCH)
	var attention := clampi(base_attention + int(float(heat) * 0.35) + scan_attention + count_pressure + strategy_pressure + int(session.get("dealer_distraction_noise", 0)), 0, 100)
	if active:
		attention = clampi(attention - 44 - int(session.get("dealer_distraction_cover", 0)), 0, 100)
	var blink := phase > 0.94 and phase < 0.985
	var watching_player := not active and phase >= 0.18 and phase <= 0.46
	var peek_window_percent := 100
	var peek_window_effect := _item_effect_total("blackjack_peek_window_percent", run_state)
	if peek_window_effect > 0:
		peek_window_percent = clampi(peek_window_effect, 10, 100)
	var window_half_width := 0.08 * (float(peek_window_percent) / 100.0)
	var read_start := 0.62 - window_half_width
	var read_end := 0.62 + window_half_width
	var read_window := active or (attention < 58 and phase > read_start and phase < read_end)
	var snitch_risk := patron_snitch_risk if patron_snitch_risk >= 0 else _patron_snitch_risk(table, session)
	var peek_danger := clampi(attention + (0 if active else int(abs(sweep) * 16.0)) + int(snitch_risk / 4.0), 0, 100)
	var peek_window_open := active or (read_window and not watching_player and peek_danger <= 62)
	var gaze_phase := "looking away" if active else "blink" if blink else "watching you" if watching_player else "hole card loose" if peek_window_open else "open read" if read_window else str(profile.get("read_style", "slow sweep"))
	var body_language := "shoulder turned" if active else "eyes on your chips" if watching_player else "checks payout tray" if peek_window_open or phase > 0.70 else "tracks the felt"
	return {
		"lookaway_active": active,
		"lookaway_remaining_msec": remaining,
		"attention_meter": attention,
		"status": "looking away" if active else "locked on" if attention >= 70 else "watching",
		"tell": str(profile.get("tell", "watches hands more than faces")),
		"distraction_id": str(session.get("dealer_distraction_id", "")),
		"gaze_phase": gaze_phase,
		"body_language": body_language,
		"read_window": read_window,
		"watching_player": watching_player,
		"peek_window_open": peek_window_open,
		"scan_phase": phase,
		"count_pressure": count_pressure,
		"strategy_pressure": strategy_pressure,
		"peek_danger": peek_danger,
		"peek_window_percent": peek_window_percent,
		"eye_offset": -0.65 if active else sweep,
		"blink": blink,
	}


func _ambient_table_event(table: Dictionary, session: Dictionary) -> Dictionary:
	if not _has_dealt_hand(session):
		return {}
	var now := Time.get_ticks_msec()
	var cycle_msec := 4200
	var phase := float(now % cycle_msec) / float(cycle_msec)
	if phase > 0.42:
		return {}
	var catalog: Array = [
		{"label": "chip shuffle", "detail": "seat stack clicks", "accent": "yellow"},
		{"label": "pit glance", "detail": "security looks over", "accent": "pink"},
		{"label": "shoe tap", "detail": "dealer checks tray", "accent": "teal"},
		{"label": "patron tell", "detail": "someone leans in", "accent": "orange"},
		{"label": "felt chatter", "detail": "table noise rises", "accent": "cyan"},
	]
	var table_key: String = "%s:%d:%d" % [str(table.get("table_name", "blackjack")), int(table.get("hands_played", 0)), int(now / cycle_msec)]
	var event_seed: int = abs(_stable_hash(table_key))
	var index: int = event_seed % catalog.size()
	var event: Dictionary = (catalog[index] as Dictionary).duplicate(true)
	event["phase"] = phase
	event["intensity"] = sin(clampf(phase / 0.42, 0.0, 1.0) * PI)
	return event


func _active_distraction_cover(session: Dictionary) -> int:
	if not _dealer_lookaway_active(session):
		return 0
	return maxi(0, int(session.get("dealer_distraction_cover", 0)))


func _patron_cover_active(session: Dictionary, patron_id: String) -> bool:
	var cover: Dictionary = _local_copy_dict(session.get("patron_cover", {}))
	var entry: Dictionary = _local_copy_dict(cover.get(patron_id, {}))
	if entry.is_empty():
		return false
	var started := int(entry.get("started_msec", 0))
	var duration := int(entry.get("duration_msec", 0))
	return started > 0 and duration > 0 and Time.get_ticks_msec() <= started + duration


func _patron_cover_amount(session: Dictionary, patron_id: String) -> int:
	if not _patron_cover_active(session, patron_id):
		return 0
	var cover: Dictionary = _local_copy_dict(session.get("patron_cover", {}))
	var entry: Dictionary = _local_copy_dict(cover.get(patron_id, {}))
	return maxi(0, int(entry.get("cover", 0)))


func _patrons_for_surface(table: Dictionary, session: Dictionary) -> Array:
	var patrons: Array = []
	var distraction_cover: int = _active_distraction_cover(session)
	var now := Time.get_ticks_msec()
	var patron_hands: Array = _hand_array(session.get("patron_hands", []))
	var source_patrons: Array = _dictionary_array(table.get("patrons", []))
	for patron_index in range(source_patrons.size()):
		var patron_value: Variant = source_patrons[patron_index]
		var patron: Dictionary = patron_value
		var patron_id := str(patron.get("id", ""))
		var covered := _patron_cover_active(session, patron_id)
		var rapport_adjust := int((50 - clampi(int(patron.get("rapport", 50)), 0, 100)) / 5)
		var risk := maxi(0, int(patron.get("snitch_risk", 0)) + rapport_adjust - distraction_cover - _patron_cover_amount(session, patron_id))
		var phase := float((now + int(patron.get("animation_offset", 0))) % 2200) / 2200.0
		var watching := bool(patron.get("watching", true)) and risk > 0 and not covered
		var threshold := int(patron.get("snitch_threshold", 30))
		var tell_active := watching and (risk >= threshold or (phase > 0.58 and phase < 0.82))
		var lean := (float(risk) / 60.0) * 5.0
		if covered:
			lean = -4.0
		var behavior := "covered" if covered else "snitch tell" if tell_active else "watching" if watching else str(patron.get("mood", "quiet"))
		patron["covered"] = covered
		patron["watching_player"] = watching
		patron["active_snitch_risk"] = risk
		patron["behavior_phase"] = phase
		patron["tell_active"] = tell_active
		patron["lean"] = lean
		patron["behavior"] = behavior
		patron["visible_bet"] = _blackjack_patron_wager(patron, table)
		var hand: Dictionary = _patron_hand_for_id(patron_hands, patron_id, patron_index)
		if not hand.is_empty():
			patron["cards"] = _card_array(hand.get("cards", []))
			patron["hand_total"] = _hand_total(_card_array(hand.get("cards", [])))
			patron["hand_status"] = str(hand.get("terminal_reason", ""))
			patron["hand_action"] = str(hand.get("last_action", ""))
			patron["hand_action_label"] = str(hand.get("last_action_label", ""))
			patron["hand_action_reason"] = str(hand.get("last_decision_reason", ""))
			patron["hand_peek_informed"] = bool(hand.get("peek_informed", false))
		patrons.append(patron)
	return patrons


func _patron_hand_for_id(patron_hands: Array, patron_id: String, fallback_index: int) -> Dictionary:
	for hand_value in patron_hands:
		if typeof(hand_value) != TYPE_DICTIONARY:
			continue
		var hand: Dictionary = hand_value
		if str(hand.get("patron_id", "")) == patron_id:
			return hand.duplicate(true)
	if fallback_index >= 0 and fallback_index < patron_hands.size() and typeof(patron_hands[fallback_index]) == TYPE_DICTIONARY:
		return (patron_hands[fallback_index] as Dictionary).duplicate(true)
	return {}


func _patron_snitch_risk_from_patrons(patrons: Array) -> int:
	var total := 0
	for patron_value in patrons:
		if typeof(patron_value) != TYPE_DICTIONARY:
			continue
		var patron: Dictionary = patron_value
		if bool(patron.get("watching_player", false)):
			total += int(patron.get("active_snitch_risk", 0))
	return total


func _patron_snitch_risk(table: Dictionary, session: Dictionary) -> int:
	return _patron_snitch_risk_from_patrons(_patrons_for_surface(table, session))


func _chip_stack_for_stake(stake: int, chip_values: Array) -> Array:
	var sorted_values: Array = chip_values.duplicate()
	sorted_values.sort()
	sorted_values.reverse()
	var remaining := maxi(0, stake)
	var stack: Array = []
	for value in sorted_values:
		var chip_value := maxi(1, int(value))
		var count := int(floor(float(remaining) / float(chip_value)))
		if count <= 0:
			continue
		stack.append({"value": chip_value, "count": count})
		remaining -= count * chip_value
	return stack


func _surface_state_labels(table: Dictionary, session: Dictionary) -> Array:
	return [
		{"label": "Shoe", "value": "%s %d" % [str(table.get("shoe_label", CardShoeScript.shoe_label(int(table.get("deck_count", 6))))), _shoe_remaining(table)]},
		{"label": "Count", "value": "%+d" % _recorded_count_for_surface(table, session)},
		{"label": "Side bets", "value": str((_string_array(session.get("blackjack_side_bets", []))).size())},
	]


func _count_hint(run_state: RunState, table: Dictionary, session: Dictionary) -> String:
	var recorded := _recorded_count_for_surface(table, session)
	if bool(session.get("count_correct", false)):
		return "Recorded count %+d." % recorded
	if bool(session.get("count_answered", false)):
		return "Recorded dirty count %+d; true shoe may disagree." % recorded
	if not _local_copy_dict(session.get("count_challenge", {})).is_empty():
		return "Live hand delta %+d; shoe count %+d." % [int(session.get("count_delta", 0)), recorded]
	if run_state != null and run_state.suspicion_level() >= 65:
		return "The dealer is tracking your eyes."
	if recorded >= 4:
		return "High recorded count. Big cards remain."
	if recorded <= -4:
		return "Low recorded count. Shoe runs small."
	return "Count is neutral unless you can track it."


func _recorded_count_for_surface(table: Dictionary, session: Dictionary) -> int:
	return int(table.get("recorded_running_count", 0)) + int(session.get("count_delta", 0))


func _true_count_for_surface(table: Dictionary, session: Dictionary) -> int:
	var challenge: Dictionary = _local_copy_dict(session.get("count_challenge", {}))
	var live_delta := int(challenge.get("target_delta", 0)) if not challenge.is_empty() else 0
	return int(table.get("running_count", 0)) + live_delta


func _blackjack_result_message(hand_results: Array, side_results: Array, main_delta: int, side_delta: int, cheat: Dictionary, item_adjustment: Dictionary, security_message: String) -> String:
	var hand_details: Array = []
	var dealer_total := 0
	for hand_value in hand_results:
		var hand: Dictionary = hand_value
		dealer_total = int(hand.get("dealer_total", dealer_total))
		hand_details.append(_blackjack_hand_result_detail(hand, hand_details.size()))
	var side_details: Array = []
	for side_value in side_results:
		var side: Dictionary = side_value
		side_details.append(_blackjack_side_result_detail(side))
	var message := "Dealer %d. %s. Main %+d" % [dealer_total, "; ".join(hand_details), main_delta]
	if side_delta != 0:
		message += ". Side %+d" % side_delta
	if not side_details.is_empty():
		message += " (%s)" % "; ".join(side_details).left(96)
	if bool(cheat.get("strategy_confronted", false)):
		message += ". Dealer challenges the off-book line."
	elif bool(cheat.get("caught", false)):
		message += ". Caught cheating; heat spikes."
	elif int(cheat.get("suspicion_delta", 0)) > 0:
		message += ". Risky play adds heat."
	var gear := str(item_adjustment.get("summary", ""))
	if not gear.is_empty():
		message += " %s" % gear
	if not security_message.is_empty():
		message += " %s" % security_message
	return message


func _blackjack_hand_result_detail(hand: Dictionary, hand_index: int) -> String:
	var outcome := str(hand.get("outcome", "push"))
	var player_total := int(hand.get("player_total", 0))
	var dealer_total := int(hand.get("dealer_total", 0))
	var wager := maxi(1, int(hand.get("wager", 1)))
	var delta := int(hand.get("bankroll_delta", 0))
	var prefix := "H%d" % (hand_index + 1)
	match outcome:
		"blackjack":
			return "%s blackjack pays %s on $%d (%+d)" % [prefix, BLACKJACK_PAYOUT_LABEL, wager, delta]
		"dealer_blackjack":
			return "%s dealer blackjack beats %d (%+d)" % [prefix, player_total, delta]
		"bust":
			return "%s busts at %d (%+d)" % [prefix, player_total, delta]
		"dealer_bust":
			return "%s dealer bust pays %d (%+d)" % [prefix, player_total, delta]
		"win":
			return "%s %d beats %d (%+d)" % [prefix, player_total, dealer_total, delta]
		"lose":
			return "%s %d loses to %d (%+d)" % [prefix, player_total, dealer_total, delta]
		"surrender":
			return "%s late surrender returns half of $%d (%+d)" % [prefix, wager, delta]
		_:
			return "%s push %d-%d (%+d)" % [prefix, player_total, dealer_total, delta]


func _blackjack_side_result_detail(side: Dictionary) -> String:
	var label := str(side.get("label", side.get("id", "Side bet")))
	var detail := str(side.get("detail", "settled"))
	var delta := int(side.get("bankroll_delta", 0))
	return "%s %s %+d" % [label, detail, delta]


func _blackjack_last_result_payload(message: String, hand_results: Array, side_results: Array, main_delta: int, side_delta: int, bankroll_delta: int, suspicion_delta: int, dealer_cards: Array, player_hands: Array, patron_hands: Array, patron_action_events: Array, cheat: Dictionary) -> Dictionary:
	var resolved_at := Time.get_ticks_msec()
	var headline := "PUSH"
	if bankroll_delta > 0:
		headline = "PLAYER PAID"
	elif bankroll_delta < 0:
		headline = "HOUSE TAKES"
	if bool(cheat.get("caught", false)):
		headline = "HEAT SPIKE"
	var outcome_labels: Array = []
	for hand_value in hand_results:
		if typeof(hand_value) == TYPE_DICTIONARY:
			outcome_labels.append(str((hand_value as Dictionary).get("outcome", "push")).replace("_", " "))
	var side_wins: Array = []
	for side_value in side_results:
		if typeof(side_value) == TYPE_DICTIONARY and bool((side_value as Dictionary).get("won", false)):
			side_wins.append(str((side_value as Dictionary).get("label", "")))
	return {
		"summary": message,
		"headline": headline,
		"main_delta": main_delta,
		"side_delta": side_delta,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"dealer_total": int(_hand_total_info(dealer_cards).get("total", 0)),
		"dealer_cards": _card_array(dealer_cards),
		"player_hands": _hand_array(player_hands),
		"patron_hands": _hand_array(patron_hands),
		"patron_action_events": _patron_action_event_array(patron_action_events),
		"hand_results": _dictionary_array(hand_results),
		"side_bet_results": _dictionary_array(side_results),
		"outcomes": outcome_labels,
		"side_wins": side_wins,
		"caught": bool(cheat.get("caught", false)),
		"catch_chance": int(cheat.get("catch_chance", 0)),
		"strategy_confronted": bool(cheat.get("strategy_confronted", false)),
		"strategy_deviation_events": _dictionary_array(cheat.get("strategy_deviation_events", [])),
		"resolved_at_msec": resolved_at,
		"timestamp_msec": resolved_at,
		"payout_animation_id": "%s:payout:%d:%d" % [get_id(), resolved_at, bankroll_delta],
	}


func _cards_used_for_counting(hands: Array, dealer_cards: Array, patron_hands: Array = []) -> Array:
	var used: Array = []
	for hand_value in hands:
		var hand: Dictionary = hand_value
		for card in _card_array(hand.get("cards", [])):
			used.append(card)
	for patron_hand_value in patron_hands:
		var patron_hand: Dictionary = patron_hand_value
		for card in _card_array(patron_hand.get("cards", [])):
			used.append(card)
	for card in dealer_cards:
		if typeof(card) == TYPE_DICTIONARY:
			used.append((card as Dictionary).duplicate(true))
	return used


func _count_cards_delta(cards: Array) -> int:
	var delta := 0
	for card_value in cards:
		if typeof(card_value) != TYPE_DICTIONARY:
			continue
		var rank: int = _card_rank_value(card_value)
		if rank >= 2 and rank <= 6:
			delta += 1
		elif rank == 10 or rank == 11 or rank == 12 or rank == 13 or rank == RANK_ACE:
			delta -= 1
	return delta


func _hand_total(cards: Array) -> int:
	return int(_hand_total_info(cards).get("total", 0))


func _hand_total_info(cards: Array) -> Dictionary:
	var total := 0
	var aces := 0
	for card_value in cards:
		if typeof(card_value) != TYPE_DICTIONARY:
			continue
		var rank: int = _card_rank_value(card_value)
		if rank == RANK_ACE:
			total += 11
			aces += 1
		else:
			total += mini(rank, 10)
	var soft := aces > 0
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	soft = aces > 0
	return {"total": total, "soft": soft}


func _is_bust(cards: Array) -> bool:
	return _hand_total(cards) > 21


func _is_natural_blackjack(hand: Dictionary) -> bool:
	return bool(hand.get("blackjack_eligible", false)) and _card_array(hand.get("cards", [])).size() == 2 and _hand_total(_card_array(hand.get("cards", []))) == 21


func _dealer_has_blackjack(dealer_cards: Array) -> bool:
	return dealer_cards.size() == 2 and _hand_total(dealer_cards) == 21


func _hand_label(hand: Dictionary) -> String:
	var cards: Array = _card_array(hand.get("cards", []))
	var total: int = _hand_total(cards)
	var flags: Array = []
	if bool(hand.get("doubled", false)):
		flags.append("double")
	if bool(hand.get("split", false)):
		flags.append("split")
	if bool(hand.get("surrendered", false)):
		flags.append("surrender")
	elif total > 21:
		flags.append("bust")
	elif bool(hand.get("stood", false)):
		flags.append("stood")
	return "%d%s" % [total, " / " + ", ".join(flags) if not flags.is_empty() else ""]


func _dealer_view(dealer_cards: Array, reveal_hole: bool) -> Array:
	var dealer_view: Array = []
	for i in range(dealer_cards.size()):
		var card: Dictionary = (dealer_cards[i] as Dictionary).duplicate(true)
		if i == 1 and not reveal_hole:
			card["hidden"] = true
		dealer_view.append(card)
	return dealer_view


func _draw_card_row(surface, cards: Array, start: Vector2, _hand_index: int = 0, scale: float = 1.0) -> void:
	for i in range(cards.size()):
		_draw_card(surface, cards[i], start + Vector2(i * 54 * scale, 0), scale)


func _draw_card(surface, card_value: Variant, pos: Vector2, scale: float = 1.0) -> void:
	var card: Dictionary = card_value if typeof(card_value) == TYPE_DICTIONARY else {}
	var size := Vector2(42, 60) * scale
	var rect := Rect2(pos, size)
	if bool(card.get("hidden", false)):
		surface.draw_rect(rect, C_SOFT)
		surface.draw_rect(Rect2(pos + Vector2(3, 3) * scale, size - Vector2(6, 6) * scale), C_PINK)
		surface.draw_rect(Rect2(pos + Vector2(9, 9) * scale, size - Vector2(18, 18) * scale), Color("#563be0"))
		return
	surface.draw_rect(rect, C_SOFT)
	surface.draw_rect(Rect2(pos + Vector2(3, 3) * scale, size - Vector2(6, 6) * scale), Color("#fbf8e6"))
	var rank := _rank_text(int(card.get("rank", 2)))
	var suit := int(card.get("suit", 0))
	var color := C_PINK if suit == 1 or suit == 2 else C_DARK
	surface.surface_label(rank, pos + Vector2(7, 21) * scale, int(15 * scale), color)
	_draw_suit(surface, pos + Vector2(22, 40) * scale, suit, color, scale)


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
		RANK_ACE:
			return "A"
		13:
			return "K"
		12:
			return "Q"
		11:
			return "J"
		_:
			return str(rank)


func _same_suit(cards: Array) -> bool:
	if cards.is_empty():
		return false
	var suit: int = _card_suit_value(cards[0])
	for card in cards:
		if _card_suit_value(card) != suit:
			return false
	return true


func _same_rank(cards: Array) -> bool:
	if cards.is_empty():
		return false
	var rank: int = _card_rank_value(cards[0])
	for card in cards:
		if _card_rank_value(card) != rank:
			return false
	return true


func _three_card_straight(cards: Array) -> bool:
	var ranks: Array = []
	for card in cards:
		var rank: int = _card_rank_value(card)
		ranks.append(1 if rank == RANK_ACE else rank)
		if rank == RANK_ACE:
			ranks.append(14)
	ranks.sort()
	for i in range(ranks.size() - 2):
		var a: int = int(ranks[i])
		var b: int = int(ranks[i + 1])
		var c: int = int(ranks[i + 2])
		if a + 1 == b and b + 1 == c:
			return true
	return false


func _card_rank_value(card_value: Variant) -> int:
	if typeof(card_value) != TYPE_DICTIONARY:
		return 2
	return int((card_value as Dictionary).get("rank", 2))


func _card_suit_value(card_value: Variant) -> int:
	if typeof(card_value) != TYPE_DICTIONARY:
		return 0
	return int((card_value as Dictionary).get("suit", 0))


func _card_blackjack_value(card_value: Variant) -> int:
	var rank: int = _card_rank_value(card_value)
	return 11 if rank == RANK_ACE else mini(rank, 10)


func _card_split_value(card_value: Variant) -> int:
	var rank: int = _card_rank_value(card_value)
	return RANK_ACE if rank == RANK_ACE else mini(rank, 10)


func _shoe_remaining(table: Dictionary) -> int:
	return CardShoeScript.remaining_count(table.get("shoe", []))


func _side_bet_labels(side_bets: Array) -> Array:
	var labels: Array = []
	for value in side_bets:
		if typeof(value) == TYPE_DICTIONARY:
			labels.append(str((value as Dictionary).get("label", (value as Dictionary).get("id", ""))))
	return labels


func _item_effect_total(key: String, run_state: RunState) -> int:
	# Shared item lookup for blackjack-specific effect keys. It supports both
	# direct effect entries and family-scoped entries for future table games.
	if library == null or run_state == null:
		return 0
	var total := 0
	for inventory_entry in run_state.inventory:
		var item_id := _inventory_item_id(inventory_entry)
		if item_id.is_empty():
			continue
		var item := library.item(item_id)
		if item.is_empty():
			continue
		var effect: Dictionary = item.get("effect", {}) if typeof(item.get("effect", {})) == TYPE_DICTIONARY else {}
		total += int(effect.get(key, 0))
		var families: Dictionary = effect.get("families", {}) if typeof(effect.get("families", {})) == TYPE_DICTIONARY else {}
		var family_effect: Dictionary = families.get(get_family(), {}) if typeof(families.get(get_family(), {})) == TYPE_DICTIONARY else {}
		total += int(family_effect.get(key, 0))
	return total


func _coolers_cufflinks_absorbed_failed_peek(action_id: String, cheat: Dictionary, run_state: RunState) -> bool:
	if run_state == null or not ["peek_hole_card", "play_basic"].has(action_id):
		return false
	if not run_state.inventory.has(COOLERS_CUFFLINKS_ITEM_ID):
		return false
	return bool(cheat.get("used_peek", false)) and bool(cheat.get("caught", false))


func _empty_blackjack_result(action_id: String, stake: int, environment: Dictionary, text: String) -> Dictionary:
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


func _inventory_item_id(entry: Variant) -> String:
	if typeof(entry) == TYPE_DICTIONARY:
		return str((entry as Dictionary).get("id", ""))
	return str(entry)


func _hand_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var hand: Dictionary = (entry as Dictionary).duplicate(true)
		hand["cards"] = _card_array(hand.get("cards", []))
		hand["wager_multiplier"] = maxi(1, int(hand.get("wager_multiplier", 1)))
		hand["stood"] = bool(hand.get("stood", false))
		hand["doubled"] = bool(hand.get("doubled", false))
		hand["split"] = bool(hand.get("split", false))
		hand["surrendered"] = bool(hand.get("surrendered", false))
		hand["blackjack_eligible"] = bool(hand.get("blackjack_eligible", not bool(hand.get("split", false))))
		hand["terminal_reason"] = str(hand.get("terminal_reason", ""))
		result.append(hand)
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


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var text := str(entry)
		if not text.is_empty():
			result.append(text)
	return result


func _local_copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _stable_hash(text: String) -> int:
	var hash_value := 2166136261
	for i in range(text.length()):
		hash_value = int(hash_value ^ text.unicode_at(i))
		hash_value = int((hash_value * 16777619) & 0x7fffffff)
	return maxi(hash_value, 1)
