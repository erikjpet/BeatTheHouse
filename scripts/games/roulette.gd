class_name RouletteGame
extends GameModule

# Full-simulation roulette module. The outcome is produced by a deterministic
# wheel/ball physics model, then settled against visible table bets.

const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
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

const ROULETTE_SPIN_CHANNEL := "roulette_spin"
const ROULETTE_PAYOUT_CHANNEL := "roulette_payout"
const SPIN_ANIMATION_DURATION_MSEC := 5600
const PAYOUT_ANIMATION_DURATION_MSEC := 1800
const ROULETTE_RESULT_REVEAL_MSEC := 1600
const WHEEL_CENTER := Vector2(150, 182)
const WHEEL_RADIUS := 108.0
const GRID_RECT := Rect2(332, 156, 360, 108)
const CELL_W := 30.0
const CELL_H := 36.0
const ZERO_RECT := Rect2(280, 156, 52, 54)
const DOUBLE_ZERO_RECT := Rect2(280, 210, 52, 54)
const LINE_BET_Y := 264.0
const LINE_BET_H := 8.0
const OUTSIDE_Y := 272.0
const CONSOLE_Y := 344.0
const CONSOLE_H := 76.0
const HISTORY_LIMIT := 12
const TRAJECTORY_KEYFRAMES := 96
const MAX_VISIBLE_PATRONS := 3
const PAST_POST_ACTION_ID := "past_post"
const PAST_POST_PERFECT_MSEC := 120
const PAST_POST_GOOD_MSEC := 260
const PAST_POST_WINDOW_MSEC := 700
const PAST_POST_BASE_HEAT := 18
const PAST_POST_BLOWN_HEAT_BONUS := 16
const PAST_POST_PARTIAL_HEAT_BONUS := 4
const PAST_POST_MISS_HEAT_BONUS := 8
const PAST_POST_PERFECT_HEAT_REDUCTION := 4
const PAST_POST_ITEM_EFFECT_KEYS := [
	"roulette_past_post_perfect_msec",
	"roulette_past_post_good_msec",
	"roulette_past_post_window_msec",
	"roulette_past_post_base_heat",
	"skill_cheat_drunk_window_offset_msec",
]

const AMERICAN_SEQUENCE := [
	"0", "28", "9", "26", "30", "11", "7", "20", "32", "17", "5", "22", "34", "15", "3", "24", "36", "13", "1", "00", "27", "10", "25", "29", "12", "8", "19", "31", "18", "6", "21", "33", "16", "4", "23", "35", "14", "2"
]
const EUROPEAN_SEQUENCE := [
	"0", "32", "15", "19", "4", "21", "2", "25", "17", "34", "6", "27", "13", "36", "11", "30", "8", "23", "10", "5", "24", "16", "33", "1", "20", "14", "31", "9", "22", "18", "29", "7", "28", "12", "35", "3", "26"
]
const RED_NUMBERS := ["1", "3", "5", "7", "9", "12", "14", "16", "18", "19", "21", "23", "25", "27", "30", "32", "34", "36"]
const BLACK_NUMBERS := ["2", "4", "6", "8", "10", "11", "13", "15", "17", "20", "22", "24", "26", "28", "29", "31", "33", "35"]


func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
	var result: Dictionary = super.enter(run_state, environment)
	var table := _table_state(run_state, environment)
	if bool(table.get("table_barred", false)):
		result["message"] = str(table.get("barred_reason", "The croupier refuses more roulette action at this wheel."))
		return result
	var rules: Dictionary = _table_rules(table)
	result["message"] = "%s palms the dolly beside the %s wheel. Inside minimum $%d; outside minimum $%d." % [
		str(table.get("dealer_name", "The croupier")),
		"double-zero" if int(rules.get("zero_count", 2)) == 2 else "single-zero",
		int(rules.get("inside_min_total", 1)),
		int(rules.get("outside_min_each", 1)),
	]
	return result


func generate_environment_state(_run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var security: Dictionary = environment.get("security_profile", {}) if typeof(environment.get("security_profile", {})) == TYPE_DICTIONARY else {}
	var strictness := str(security.get("strictness", "low"))
	var catch_base := 12
	match strictness:
		"boss":
			catch_base = 28
		"high":
			catch_base = 22
		"private", "uneven":
			catch_base = 17
		_:
			catch_base = 11
	var variant := "american_double_zero"
	var names := ["Neon Wheel", "Velvet Zero", "Copper Rotor", "Midnight 00", "Cyan Dolly"]
	return {
		"schema": "roulette_table_state",
		"version": 1,
		"table_name": str(rng.pick(names, names[0])),
		"dealer_name": str(rng.pick(["Vega", "Mara", "Rook", "June", "Sal"], "Vega")),
		"variant": variant,
		"wheel_sequence": AMERICAN_SEQUENCE.duplicate(true),
		"red_numbers": RED_NUMBERS.duplicate(true),
		"black_numbers": BLACK_NUMBERS.duplicate(true),
		"rules": {
			"zero_count": 2,
			"la_partage": false,
			"en_prison": false,
			"call_bets_enabled": false,
			"late_bets_allowed": false,
			"inside_min_total": 1,
			"outside_min_each": maxi(1, int(environment.get("economic_profile", {}).get("stake_floor", 1)) if typeof(environment.get("economic_profile", {})) == TYPE_DICTIONARY else 1),
			"table_max": maxi(50, int(environment.get("economic_profile", {}).get("stake_ceiling", 100)) if typeof(environment.get("economic_profile", {})) == TYPE_DICTIONARY else 100),
		},
		"physics_profile": _standard_physics_profile(rng),
		"dealer_profile": _generate_dealer_profile(rng, catch_base),
		"patrons": _generate_table_patrons(rng, int(environment.get("depth", 0))),
		"chip_denominations": [1, 5, 10, 25],
		"table_layout": "immersive_roulette",
		"spin_count": 0,
		"last_results": [],
		"last_result": {},
		"bias_read": {},
		"dealer_catch_base": catch_base,
		"table_barred": false,
		"barred_reason": "",
		"table_round_timer_started_msec": 0,
	}


func surface_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var table := _table_state(run_state, environment)
	var session := _normalized_session(run_state, environment, ui_state, table)
	var bets: Array = _bet_array(session.get("roulette_bets", []))
	var bet_targets := _roulette_bet_targets(table)
	var selected_chip := int(session.get("selected_chip", _chip_denominations(table)[0]))
	var chip_denoms := _chip_denominations(table)
	var total_wager := _total_wager(bets)
	var inside_total := _wager_total_for_family(bets, "inside")
	var outside_total := _wager_total_for_family(bets, "outside")
	var last_result := _copy_dict(table.get("last_result", {}))
	var now_msec := int(ui_state.get("surface_time_msec", Time.get_ticks_msec()))
	var spin_elapsed_msec := now_msec - int(last_result.get("resolved_at_msec", 0))
	var spin_active := not last_result.is_empty() and spin_elapsed_msec >= 0 and spin_elapsed_msec < SPIN_ANIMATION_DURATION_MSEC
	var payout_active := not last_result.is_empty() and spin_elapsed_msec >= SPIN_ANIMATION_DURATION_MSEC and spin_elapsed_msec < SPIN_ANIMATION_DURATION_MSEC + PAYOUT_ANIMATION_DURATION_MSEC
	var result_reveal_active := _roulette_result_reveal_active(last_result, spin_elapsed_msec)
	var past_post_window := _past_post_window_status(table, session, last_result, now_msec, run_state)
	var past_post_challenge := _normalized_past_post_challenge(session.get("past_post_challenge", {}))
	var past_post_available := bool(past_post_window.get("available", false))
	var roulette_motion_active := spin_active or payout_active or result_reveal_active or past_post_available
	var rules := _table_rules(table)
	var barred := bool(table.get("table_barred", false))
	var recent_numbers := _roulette_recent_numbers(table)
	var timer_active := not barred and not spin_active and not payout_active
	var round_timer := GameModule.table_round_timer_status(table, now_msec, "Next spin") if timer_active else {}
	if timer_active:
		_update_environment_table(environment, table)
	var table_notice := _table_notice(table, session, last_result, spin_active, payout_active, round_timer)
	if past_post_available:
		table_notice = "The payout lock is open. A late chip could still slide."
	if barred:
		table_notice = str(table.get("barred_reason", "The roulette wheel is closed to you."))
	var surface_patrons := _patrons_for_surface(table, last_result)
	var patron_layout := _roulette_patron_layout(surface_patrons)
	var cheat_binding_action := "roulette_past_post" if past_post_available else "roulette_nudge"
	var past_post_item_modifiers := skill_item_modifier_badges(run_state, PAST_POST_ITEM_EFFECT_KEYS)
	return GameModule.surface_spec({
		"surface_renderer": "roulette",
		"surface_life": "immersive_table",
		"surface_cast": "dealer_table",
		"surface_controls_native": true,
		"surface_stake_controls_required": true,
		"surface_embeds_outcomes": true,
		"surface_suppresses_game_result_burst": true,
		"surface_animates_idle": roulette_motion_active,
		"surface_realtime_state_refresh": roulette_motion_active,
		"surface_state_labels": [
			{"label": "Wager", "value": "$%d" % total_wager},
			{"label": "Wheel", "value": "00" if int(rules.get("zero_count", 2)) == 2 else "0"},
		],
		"surface_animation_channels": [
			GameModule.surface_animation_channel(
				ROULETTE_SPIN_CHANNEL,
				str(last_result.get("spin_id", "")) if spin_active else "",
				SPIN_ANIMATION_DURATION_MSEC if spin_active else 0,
				int(last_result.get("resolved_at_msec", 0)),
				{"metadata": {"winning_number": str(last_result.get("winning_number", ""))}}
			),
			GameModule.surface_animation_channel(
				ROULETTE_PAYOUT_CHANNEL,
				str(last_result.get("payout_animation_id", "")) if payout_active else "",
				PAYOUT_ANIMATION_DURATION_MSEC if payout_active else 0,
				int(last_result.get("resolved_at_msec", 0)) + SPIN_ANIMATION_DURATION_MSEC
			),
		],
		"surface_action_blocks": _surface_action_blocks(spin_active or payout_active),
		"phase": "barred" if barred else "spinning" if spin_active else "payout" if payout_active else "betting",
		"table_barred": barred,
		"barred_reason": str(table.get("barred_reason", "")),
		"table_name": str(table.get("table_name", "Roulette")),
		"dealer_name": str(table.get("dealer_name", "Croupier")),
		"dealer_profile": _copy_dict(table.get("dealer_profile", {})),
		"patrons": surface_patrons,
		"patron_layout": patron_layout,
		"focused_patron_index": _focused_patron_index(session, surface_patrons),
		"patron_wager_action": "roulette_patron_bet",
		"snitch_pressure": _patron_snitch_pressure(surface_patrons),
		"suspicion_level": run_state.suspicion_level() if run_state != null else 0,
		"dealer_attention_pressure": 12 if spin_active else 8 if payout_active else 0,
		"rules": rules,
		"variant": str(table.get("variant", "american_double_zero")),
		"wheel_sequence": _string_array(table.get("wheel_sequence", [])),
		"red_numbers": _string_array(table.get("red_numbers", RED_NUMBERS)),
		"black_numbers": _string_array(table.get("black_numbers", BLACK_NUMBERS)),
		"physics_profile": _copy_dict(table.get("physics_profile", {})),
		"physics_profile_summary": _physics_summary(table),
		"bet_targets": bet_targets,
		"roulette_bets": bets,
		"roulette_rebet": _bet_array(session.get("roulette_rebet", table.get("last_bets", []))),
		"selected_chip": selected_chip,
		"selected_stake": selected_chip,
		"chip_denominations": chip_denoms,
		"chip_stack": _chip_stack_for_stake(total_wager, chip_denoms),
		"total_wager_cost": total_wager,
		"inside_wager_total": inside_total,
		"outside_wager_total": outside_total,
		"can_spin": not barred and not spin_active and not payout_active,
		"can_undo": not barred and not (_array(session.get("roulette_undo_stack", [])).is_empty()),
		"can_clear": not barred and not bets.is_empty(),
		"can_rebet": not barred and not _bet_array(session.get("roulette_rebet", table.get("last_bets", []))).is_empty(),
		"last_result": last_result,
		"last_results": _dictionary_array(table.get("last_results", [])),
		"recent_numbers": recent_numbers,
		"roulette_recent_numbers": recent_numbers,
		"past_post_available": past_post_available,
		"past_post_window": past_post_window,
		"past_post_challenge": past_post_challenge,
		"past_post_item_modifiers": past_post_item_modifiers,
		"result_reveal_active": result_reveal_active,
		"roulette_motion_active": roulette_motion_active,
		"result_message": str(last_result.get("summary", "")) if not spin_active else "",
		"table_notice": table_notice,
		"table_round_timer": round_timer,
		"spin_trajectory": _dictionary_array(last_result.get("trajectory", [])),
		"spin_elapsed_msec": spin_elapsed_msec,
		"native_selected_surface_actions": _selected_surface_actions(session),
		"surface_action_bindings": {
			"legal": {"action": "roulette_spin", "index": 0},
			"cheat": {"action": cheat_binding_action, "index": 0},
			"surface_stake_down": {"action": "roulette_clear", "index": 0},
			"surface_stake_up": {"action": "roulette_chip", "index": 0},
			"surface_stake_max": {"action": "roulette_max_bet", "index": 0},
		},
		"surface_audio": GameModule.surface_audio_spec({
			"profile_id": "roulette_table",
			"action_cues": {
				"roulette_chip": "roulette_chip_select",
				"roulette_bet": "roulette_chip_place",
				"roulette_patron_focus": "roulette_chip_select",
				"roulette_patron_bet": "roulette_chip_place",
				"roulette_clear": "roulette_chip_sweep",
				"roulette_undo": "roulette_chip_lift",
				"roulette_rebet": "roulette_chip_stack",
				"roulette_double": "roulette_chip_stack",
				"roulette_spin": "roulette_spin",
				"roulette_read_wheel": "roulette_read_wheel",
				"roulette_nudge": "roulette_read_wheel",
				"roulette_past_post": "roulette_chip_place",
				"surface_stake_up": "roulette_chip_select",
				"surface_stake_down": "roulette_chip_lift",
				"surface_stake_max": "roulette_chip_stack",
			},
			"state_sync": {
				"method": "roulette_table_state",
				"spin_animation_channel": ROULETTE_SPIN_CHANNEL,
				"payout_animation_channel": ROULETTE_PAYOUT_CHANNEL,
			},
		}),
	})


func draw_surface(surface, surface_state: Dictionary, _render_context: Dictionary = {}) -> bool:
	if str(surface_state.get("surface_renderer", "")) != "roulette":
		return false
	var static_betting := _roulette_static_betting_view(surface, surface_state)
	surface.surface_begin_design_space(surface.surface_board_size())
	_draw_roulette_room(surface, surface_state)
	_draw_roulette_table(surface, surface_state)
	_draw_roulette_wheel(surface, surface_state)
	if static_betting:
		_draw_static_table_patrons(surface, surface_state)
		_draw_static_croupier_station(surface, surface_state)
	else:
		_draw_table_patrons(surface, surface_state)
		_draw_croupier_station(surface, surface_state)
	_draw_recent_numbers(surface, surface_state)
	_draw_betting_layout(surface, surface_state)
	_draw_bet_chips(surface, surface_state)
	_draw_table_notice(surface, surface_state)
	_draw_round_timer(surface, surface_state)
	_draw_chip_rack(surface, surface_state)
	_draw_table_actions(surface, surface_state)
	_draw_spin_result(surface, surface_state)
	_draw_rule_hover_overlay(surface, surface_state)
	_draw_payout_animation(surface, surface_state)
	return true


func _roulette_static_betting_view(surface, surface_state: Dictionary) -> bool:
	if str(surface_state.get("phase", "betting")) != "betting":
		return false
	if bool(surface_state.get("result_reveal_active", false)):
		return false
	return not bool(surface.surface_animation_active(ROULETTE_SPIN_CHANNEL)) and not bool(surface.surface_animation_active(ROULETTE_PAYOUT_CHANNEL))


func surface_needs_auto_tick(ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> bool:
	# Per-frame check: operate on the live stored table (zero-copy) instead of
	# normalize -> deep copy -> write-back every frame. Stored state is already
	# normalized by every mutation path.
	var table := _peek_table_state(environment)
	if table.is_empty() or bool(table.get("table_barred", false)):
		return false
	var now_msec := int(ui_state.get("surface_time_msec", Time.get_ticks_msec()))
	var timer := GameModule.table_round_timer_status_peek(table, now_msec, "Next spin")
	if _roulette_motion_active(table, now_msec) and not bool(timer.get("due", false)):
		return false
	return bool(timer.get("due", false))


func _peek_table_state(environment: Dictionary) -> Dictionary:
	# Zero-copy view of the stored table for read-mostly per-frame checks.
	# Callers must not mutate it or hold it across writes.
	var states: Variant = environment.get("game_states", {})
	if typeof(states) != TYPE_DICTIONARY:
		return {}
	var table: Variant = (states as Dictionary).get(get_id(), {})
	if typeof(table) != TYPE_DICTIONARY or (table as Dictionary).is_empty():
		return {}
	return table as Dictionary


func surface_auto_action_command(ui_state: Dictionary, run_state: RunState, environment: Dictionary, _surface_status: Dictionary = {}) -> Dictionary:
	var table := _table_state(run_state, environment)
	var session := _normalized_session(run_state, environment, ui_state, table)
	var now_msec := int(ui_state.get("surface_time_msec", Time.get_ticks_msec()))
	var timer := GameModule.table_round_timer_status(table, now_msec, "Next spin")
	if _roulette_motion_active(table, now_msec) and not bool(timer.get("due", false)):
		return {"handled": false}
	if bool(table.get("table_barred", false)) or not bool(timer.get("due", false)):
		_update_environment_table(environment, table)
		return {"handled": false}
	session["roulette_sit_out"] = _bet_array(session.get("roulette_bets", [])).is_empty()
	GameModule.reset_table_round_timer(table)
	_update_environment_table(environment, table)
	return GameModule.surface_command({
		"handled": true,
		"ui_state": session,
		"action_id": "spin_roulette",
		"action_kind": "legal",
		"direct_resolve": true,
		"skip_stake_validation": true,
		"preserve_surface_ui_state": false,
		"message": "The croupier spins; you sit this one out." if bool(session.get("roulette_sit_out", false)) else "The croupier spins the working layout.",
	})


func surface_action_command(surface_action: String, index: int, confirm_requested: bool, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var table := _table_state(run_state, environment)
	var next_state := _normalized_session(run_state, environment, ui_state, table)
	if bool(table.get("table_barred", false)):
		return _message_command(next_state, str(table.get("barred_reason", "The croupier closes the roulette table to you.")))
	if surface_action == "roulette_past_post":
		return _past_post_command(index, next_state, table, run_state, environment, confirm_requested)
	if _surface_locked(next_state):
		return _message_command(next_state, "No more bets while the wheel is moving.")
	match surface_action:
		"roulette_chip":
			return _select_chip_command(index, next_state, table)
		"roulette_bet":
			return _place_bet_command(index, next_state, table, run_state, environment)
		"roulette_patron_focus":
			return _patron_focus_command(index, next_state, table)
		"roulette_patron_bet":
			return _patron_bet_command(index, next_state, table, run_state, environment)
		"roulette_clear":
			return _clear_bets_command(next_state)
		"roulette_undo":
			return _undo_bets_command(next_state)
		"roulette_rebet":
			return _rebet_command(next_state, table, run_state, environment)
		"roulette_double":
			return _double_bets_command(next_state, table, run_state, environment)
		"roulette_max_bet":
			return _max_bet_command(next_state, table, run_state, environment)
		"roulette_spin":
			return _spin_command(next_state, table, run_state, environment, confirm_requested)
		"roulette_nudge":
			return _nudge_wheel_command(index, next_state, table, run_state, environment)
		"roulette_read_wheel":
			return _read_wheel_command(index, next_state, table, run_state)
	return {"handled": false}


func resolve(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return resolve_with_context(action_id, stake, run_state, environment, rng, {})


func resolve_with_context(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary = {}) -> Dictionary:
	if action_id == "read_wheel_bias":
		return _resolve_read_wheel(action_id, run_state, environment, rng, ui_state)
	if action_id == PAST_POST_ACTION_ID:
		return _resolve_past_post(action_id, run_state, environment, rng, ui_state)
	if action_id != "spin_roulette":
		return _empty_roulette_result(action_id, stake, environment, "That roulette action is not available.")
	var table := _table_state(run_state, environment)
	if bool(table.get("table_barred", false)):
		return _empty_roulette_result(action_id, stake, environment, str(table.get("barred_reason", "The croupier refuses more roulette action at this wheel.")))
	var session := _normalized_session(run_state, environment, ui_state, table)
	var bets := _bet_array(session.get("roulette_bets", []))
	var sit_out := bool(session.get("roulette_sit_out", false)) and bets.is_empty()
	if bets.is_empty() and not sit_out:
		bets = [_default_smoke_bet(maxi(1, stake))]
	if not sit_out:
		var validation := _validate_roulette_bets(bets, table, run_state, environment)
		if not bool(validation.get("ok", false)):
			return _empty_roulette_result(action_id, stake, environment, str(validation.get("message", "Those roulette bets cannot be placed.")))
	var effective_profile := _effective_physics_profile(table, run_state, environment, session, rng)
	var spin := _simulate_spin(table, effective_profile, rng)
	var cheat_context: Dictionary = _copy_dict(session.get("cheats_used", {}))
	var used_nudge := bool(cheat_context.get("wheel_nudge", false))
	if used_nudge:
		spin = _apply_nudged_spin(spin, table, bets)
	var winning_number := str(spin.get("winning_number", "0"))
	var bet_results := _settle_roulette_bets(winning_number, bets, table)
	var bankroll_delta := 0
	for result_value in bet_results:
		if typeof(result_value) == TYPE_DICTIONARY:
			bankroll_delta += int((result_value as Dictionary).get("bankroll_delta", 0))
	var suspicion_delta := 0
	var used_cheat := bool(cheat_context.get("read_wheel_bias", false)) or used_nudge
	var pit_boss_status := run_state.pit_boss_watch_status(environment) if run_state != null and used_cheat else {}
	var pit_boss_bonus := int(pit_boss_status.get("cheat_heat_bonus", 0)) if bool(pit_boss_status.get("active", false)) else 0
	if bool(cheat_context.get("read_wheel_bias", false)):
		var raw_heat := int(cheat_context.get("read_wheel_heat", 0))
		suspicion_delta = run_state.alcohol_adjusted_suspicion_delta(raw_heat) if run_state != null and raw_heat > 0 else raw_heat
	if used_nudge:
		var nudge_heat := int(cheat_context.get("wheel_nudge_heat", _nudge_wheel_heat(table, run_state, environment)))
		var adjusted_nudge_heat := run_state.alcohol_adjusted_suspicion_delta(nudge_heat) if run_state != null and nudge_heat > 0 else nudge_heat
		suspicion_delta += adjusted_nudge_heat
	var security_pressure: Dictionary = run_state.security_action_pressure("cheat", _total_wager(bets), run_state.suspicion_level() + suspicion_delta) if run_state != null and suspicion_delta > 0 else {}
	var security_bankroll_delta := int(security_pressure.get("bankroll_delta", 0))
	bankroll_delta += security_bankroll_delta
	var security_message := str(security_pressure.get("message", ""))
	var message := _roulette_result_message(winning_number, spin, bet_results, bankroll_delta, security_message)
	if sit_out:
		message = "You sit out the spin. %s" % message
	elif used_nudge:
		message = "%s You nudge the wheel's rhythm before the ball drops." % message
	var table_pressure := _roulette_pressure_message(table, pit_boss_status) if used_cheat else ""
	if not table_pressure.is_empty():
		message = "%s %s" % [message, table_pressure]
	var result_action_kind := "cheat" if used_cheat or suspicion_delta > 0 else "legal"
	_update_table_after_spin(table, bets, bet_results, spin, bankroll_delta, suspicion_delta, rng)
	_apply_patron_rapport_after_roulette(table, session, bets, winning_number)
	_update_environment_table(environment, table)
	var story_entry := {
		"type": "game_action",
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": result_action_kind,
		"stake": _total_wager(bets),
		"total_wager": _total_wager(bets),
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"cheated": used_cheat,
		"sat_out": sit_out,
		"wheel_nudge": used_nudge,
		"wheel_nudge_watched": bool(cheat_context.get("wheel_nudge_watched", false)),
		"winning_number": winning_number,
		"winning_color": str(spin.get("winning_color", "")),
		"bet_results": bet_results,
		"physics": _copy_dict(spin.get("physics", {})),
		"environment_id": environment.get("id", ""),
		"pit_boss_watched": bool(pit_boss_status.get("watched", false)),
		"pit_boss_heat_bonus": pit_boss_bonus,
		"table_pressure": table_pressure,
		"security_message": security_message,
	}
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["suspicion_delta"] = suspicion_delta
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
		"stake": _total_wager(bets),
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"deltas": deltas,
		"won": bankroll_delta > 0,
		"environment_id": environment.get("id", ""),
		"environment_archetype_id": environment.get("archetype_id", ""),
		"message": message,
	})
	result["roulette_winning_number"] = winning_number
	result["roulette_winning_color"] = str(spin.get("winning_color", ""))
	result["roulette_bets"] = bets
	result["roulette_bet_results"] = bet_results
	result["roulette_spin_physics"] = _copy_dict(spin.get("physics", {}))
	result["roulette_spin_trajectory"] = _dictionary_array(spin.get("trajectory", []))
	result["roulette_spin_id"] = str(spin.get("spin_id", ""))
	result["roulette_total_wager"] = _total_wager(bets)
	result["roulette_cheated"] = used_cheat
	result["roulette_sat_out"] = sit_out
	result["roulette_wheel_nudge"] = used_nudge
	result["roulette_wheel_nudge_watched"] = bool(cheat_context.get("wheel_nudge_watched", false))
	result["roulette_pit_boss_watched"] = bool(pit_boss_status.get("watched", false))
	result["roulette_pit_boss_heat_bonus"] = pit_boss_bonus
	result["roulette_table_pressure"] = table_pressure
	GameModule.apply_result(run_state, result, rng)
	return result


func _past_post_command(index: int, state: Dictionary, table: Dictionary, run_state: RunState, environment: Dictionary, confirm_requested: bool) -> Dictionary:
	var last_result := _copy_dict(table.get("last_result", {}))
	var now_msec := _surface_time_msec(state)
	var window := _past_post_window_status(table, state, last_result, now_msec, run_state)
	if not bool(window.get("available", false)):
		return _message_command(state, str(window.get("message", "The croupier has locked this payout.")))
	var challenge := _normalized_past_post_challenge(state.get("past_post_challenge", {}))
	if challenge.is_empty() or str(challenge.get("spin_id", "")) != str(last_result.get("spin_id", "")):
		challenge = _start_past_post_challenge(state, run_state, table, environment, last_result)
	var already_armed := bool(state.get("past_post_armed", false)) or (str(state.get("selected_action_id", "")) == PAST_POST_ACTION_ID and str(state.get("selected_action_kind", "")) == "cheat")
	var resolving := confirm_requested or already_armed
	if resolving:
		challenge["input_msec"] = maxi(0, int(state.get("past_post_input_msec", now_msec)))
		challenge["input_target"] = _past_post_target_from_input(state, table, str(challenge.get("winning_number", "0")), index)
		challenge = _grade_past_post_challenge(challenge)
		state.erase("past_post_input_msec")
		state.erase("past_post_input_target")
		state.erase("past_post_input_target_index")
	state["past_post_challenge"] = challenge
	state["past_post_armed"] = not resolving
	return GameModule.surface_command({
		"handled": true,
		"ui_state": state,
		"action_id": PAST_POST_ACTION_ID,
		"action_kind": "cheat",
		"resolve": resolving,
		"selected_index": index,
		"preserve_surface_ui_state": not resolving,
		"message": "Late chip selected. Click again before the payout lock." if not resolving else "Late-chip timing locked: %s." % str(challenge.get("skill_grade", "miss")).replace("_", " "),
	})


func _resolve_past_post(action_id: String, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary) -> Dictionary:
	var table := _table_state(run_state, environment)
	var last_result := _copy_dict(table.get("last_result", {}))
	if last_result.is_empty():
		return _empty_roulette_result(action_id, 0, environment, "There is no settled roulette number to past-post.")
	if bool(last_result.get("past_post_resolved", false)):
		return _empty_roulette_result(action_id, 0, environment, "The croupier has already locked that payout.")
	var challenge := _finalize_past_post_challenge(ui_state, run_state, table, environment, last_result)
	if challenge.is_empty() or str(challenge.get("spin_id", "")) != str(last_result.get("spin_id", "")):
		return _empty_roulette_result(action_id, 0, environment, "The late-chip window is gone.")
	var grade := str(challenge.get("skill_grade", "miss"))
	var applied := _past_post_grade_applies(grade)
	var chip_value := maxi(1, int(challenge.get("chip_value", ui_state.get("selected_chip", 1))))
	var target := _past_post_target_for_grade(challenge, table)
	var payout_mult := _past_post_payout_mult_for_grade(grade, target)
	var bankroll_delta := chip_value * payout_mult if applied else 0
	if grade == "blown":
		bankroll_delta = -chip_value
	var watch := _roulette_table_watch_status(table, run_state, environment)
	var pit_boss_status := run_state.pit_boss_watch_status(environment) if run_state != null else {}
	var pit_boss_active := bool(pit_boss_status.get("active", false))
	var pit_boss_watched := (pit_boss_active and bool(pit_boss_status.get("watched", false))) or bool(watch.get("watched", false)) or bool(challenge.get("watched_start", false))
	var pit_boss_bonus := int(pit_boss_status.get("cheat_heat_bonus", 0)) if pit_boss_active else 0
	var base_suspicion_delta := maxi(1, int(challenge.get("base_heat", _past_post_base_heat(run_state))) + _item_effect_total("cheat_suspicion_delta", run_state) + _past_post_grade_heat_modifier(grade))
	var raw_heat := base_suspicion_delta
	if run_state != null:
		raw_heat += run_state.security_risk_bonus("cheat") + pit_boss_bonus
	var suspicion_delta := run_state.alcohol_adjusted_suspicion_delta(raw_heat) if run_state != null else raw_heat
	var security_pressure: Dictionary = run_state.security_action_pressure("cheat", chip_value, run_state.suspicion_level() + suspicion_delta) if run_state != null else {}
	var security_bankroll_delta := int(security_pressure.get("bankroll_delta", 0))
	if security_bankroll_delta != 0:
		bankroll_delta += security_bankroll_delta
	var security_message := str(security_pressure.get("message", ""))
	var skill_outcome := _past_post_skill_outcome(grade)
	var table_pressure := _roulette_pressure_message(table, pit_boss_status)
	var message := _past_post_message(grade, chip_value, target, bankroll_delta, suspicion_delta, table_pressure, security_message)
	_record_past_post_table_result(table, last_result, challenge, target, bankroll_delta, suspicion_delta, message)
	_update_environment_table(environment, table)
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
		"pit_boss_heat_bonus": pit_boss_bonus,
		"security_pressure_checked": true,
		"winning_number": str(challenge.get("winning_number", "")),
		"chip_value": chip_value,
		"input_target": target.duplicate(true),
	}
	var story_entry := {
		"type": "game_action",
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": "cheat",
		"stake": chip_value,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"cheated": true,
		"winning_number": str(challenge.get("winning_number", "")),
		"skill_outcome": skill_outcome,
		"skill_grade": grade,
		"skill_accuracy": clampi(int(challenge.get("skill_accuracy", 0)), 0, 100),
		"skill_margin_msec": int(challenge.get("skill_margin_msec", 0)),
		"base_suspicion_delta": base_suspicion_delta,
		"pit_boss_watched": pit_boss_watched,
		"pit_boss_heat_bonus": pit_boss_bonus,
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
		"stake": chip_value,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"deltas": deltas,
		"won": bankroll_delta > 0,
		"environment_id": environment.get("id", ""),
		"environment_archetype_id": environment.get("archetype_id", ""),
		"message": message,
		"pit_boss_watched": pit_boss_watched,
		"pit_boss_heat_bonus": pit_boss_bonus,
		"skill_outcome": skill_outcome,
		"skill_security_pressure_checked": true,
		"security_message": security_message,
		"skill_story_context": skill_context,
	})
	result["roulette_past_post"] = true
	result["roulette_past_post_applied"] = applied
	result["roulette_past_post_challenge"] = challenge
	result["roulette_past_post_grade"] = grade
	result["roulette_past_post_accuracy"] = clampi(int(challenge.get("skill_accuracy", 0)), 0, 100)
	result["roulette_past_post_margin_msec"] = int(challenge.get("skill_margin_msec", 0))
	result["roulette_past_post_bet"] = target
	result["roulette_past_post_payout_mult"] = payout_mult
	result["roulette_past_post_chip_value"] = chip_value
	result["roulette_winning_number"] = str(challenge.get("winning_number", ""))
	result["roulette_pit_boss_watched"] = pit_boss_watched
	result["roulette_pit_boss_heat_bonus"] = pit_boss_bonus
	result["roulette_table_pressure"] = table_pressure
	result["skill_grade"] = grade
	result["skill_accuracy"] = clampi(int(challenge.get("skill_accuracy", 0)), 0, 100)
	result["skill_margin_msec"] = int(challenge.get("skill_margin_msec", 0))
	result["base_suspicion_delta"] = base_suspicion_delta
	GameModule.normalize_skill_cheat_contract(result, result)
	GameModule.apply_result(run_state, result, rng)
	return result


func _surface_time_msec(ui_state: Dictionary) -> int:
	if ui_state.has("surface_time_msec"):
		return maxi(0, int(ui_state.get("surface_time_msec", 0)))
	return Time.get_ticks_msec()


func _past_post_windows(run_state: RunState) -> Dictionary:
	var perfect := PAST_POST_PERFECT_MSEC + _item_effect_total("roulette_past_post_perfect_msec", run_state)
	var good := PAST_POST_GOOD_MSEC + _item_effect_total("roulette_past_post_good_msec", run_state)
	var window := PAST_POST_WINDOW_MSEC + _item_effect_total("roulette_past_post_window_msec", run_state)
	var impairment := clampi(int(run_state.drunk_level / 4), 0, 40) if run_state != null else 0
	impairment = maxi(0, impairment - _item_effect_total("skill_cheat_drunk_window_offset_msec", run_state))
	perfect = maxi(36, perfect - impairment)
	good = maxi(perfect + 48, good - impairment * 2)
	window = maxi(good + 120, window - impairment * 4)
	return {"perfect": perfect, "good": good, "window": window}


func _past_post_base_heat(run_state: RunState) -> int:
	var base_heat := PAST_POST_BASE_HEAT + _item_effect_total("roulette_past_post_base_heat", run_state)
	return maxi(1, base_heat)


func _past_post_window_status(_table: Dictionary, _session: Dictionary, last_result: Dictionary, now_msec: int, run_state: RunState) -> Dictionary:
	if last_result.is_empty():
		return {"available": false, "message": "No settled number is on the layout."}
	if bool(last_result.get("past_post_resolved", false)):
		return {"available": false, "message": "The croupier has already locked that payout."}
	var resolved_at := int(last_result.get("resolved_at_msec", 0))
	var windows := _past_post_windows(run_state)
	var window_start := resolved_at + SPIN_ANIMATION_DURATION_MSEC
	var window_end := mini(window_start + int(windows.get("window", PAST_POST_WINDOW_MSEC)), resolved_at + SPIN_ANIMATION_DURATION_MSEC + PAYOUT_ANIMATION_DURATION_MSEC)
	var payout_end := resolved_at + SPIN_ANIMATION_DURATION_MSEC + PAYOUT_ANIMATION_DURATION_MSEC
	var available := now_msec >= window_start and now_msec <= window_end
	var message := ""
	if now_msec < window_start:
		message = "The ball has not settled enough for a late chip."
	elif now_msec > payout_end:
		message = "The payout is locked."
	elif now_msec > window_end:
		message = "The dealer's dolly is already over the number."
	return {
		"available": available,
		"message": message,
		"spin_id": str(last_result.get("spin_id", "")),
		"winning_number": str(last_result.get("winning_number", "0")),
		"window_start_msec": window_start,
		"window_end_msec": window_end,
		"payout_end_msec": payout_end,
		"remaining_msec": maxi(0, window_end - now_msec),
		"item_modifiers": skill_item_modifier_badges(run_state, PAST_POST_ITEM_EFFECT_KEYS),
	}


func _start_past_post_challenge(ui_state: Dictionary, run_state: RunState, table: Dictionary, environment: Dictionary, last_result: Dictionary) -> Dictionary:
	var winning_number := str(last_result.get("winning_number", "0"))
	var now_msec := _surface_time_msec(ui_state)
	var resolved_at := int(last_result.get("resolved_at_msec", now_msec))
	var windows := _past_post_windows(run_state)
	var window_start := resolved_at + SPIN_ANIMATION_DURATION_MSEC
	var window_end := window_start + int(windows.get("window", PAST_POST_WINDOW_MSEC))
	var spin_id := str(last_result.get("spin_id", "roulette"))
	var seed := "%s:%s:%s:%d" % [get_id(), spin_id, str(run_state.seed_text if run_state != null else ""), now_msec]
	var watch := _roulette_table_watch_status(table, run_state, environment)
	var target := _past_post_target_from_input(ui_state, table, winning_number, -1)
	return {
		"challenge_id": "roulette_past_%d" % _stable_hash(seed),
		"spin_id": spin_id,
		"winning_number": winning_number,
		"allowed_targets": _past_post_allowed_targets(table, winning_number),
		"no_more_bets_msec": resolved_at,
		"window_start_msec": window_start,
		"window_end_msec": window_end,
		"perfect_window_msec": int(windows.get("perfect", PAST_POST_PERFECT_MSEC)),
		"good_window_msec": int(windows.get("good", PAST_POST_GOOD_MSEC)),
		"window_msec": int(windows.get("window", PAST_POST_WINDOW_MSEC)),
		"input_target": target,
		"chip_value": maxi(1, int(ui_state.get("selected_chip", _chip_denominations(table)[0]))),
		"base_heat": _past_post_base_heat(run_state),
		"watched_start": bool(watch.get("watched", false)),
		"dealer_attention": int(watch.get("dealer_attention", 0)),
		"patron_pressure": int(watch.get("patron_pressure", 0)),
		"item_modifiers": skill_item_modifier_badges(run_state, PAST_POST_ITEM_EFFECT_KEYS),
	}


func _normalized_past_post_challenge(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = value
	if str(source.get("challenge_id", "")).strip_edges().is_empty():
		return {}
	var result := source.duplicate(true)
	result["challenge_id"] = str(result.get("challenge_id", ""))
	result["spin_id"] = str(result.get("spin_id", ""))
	result["winning_number"] = str(result.get("winning_number", "0"))
	result["allowed_targets"] = _string_array(result.get("allowed_targets", []))
	result["no_more_bets_msec"] = maxi(0, int(result.get("no_more_bets_msec", 0)))
	result["window_start_msec"] = maxi(0, int(result.get("window_start_msec", 0)))
	result["window_end_msec"] = maxi(int(result.get("window_start_msec", 0)), int(result.get("window_end_msec", 0)))
	var timing_windows := GameModule.normalize_skill_timing_windows(
		int(result.get("perfect_window_msec", PAST_POST_PERFECT_MSEC)),
		int(result.get("good_window_msec", PAST_POST_GOOD_MSEC)),
		int(result.get("window_msec", PAST_POST_WINDOW_MSEC))
	)
	result["perfect_window_msec"] = int(timing_windows.get("perfect_window_msec", PAST_POST_PERFECT_MSEC))
	result["good_window_msec"] = int(timing_windows.get("good_window_msec", PAST_POST_GOOD_MSEC))
	result["window_msec"] = int(timing_windows.get("close_window_msec", PAST_POST_WINDOW_MSEC))
	result["chip_value"] = maxi(1, int(result.get("chip_value", 1)))
	result["base_heat"] = maxi(1, int(result.get("base_heat", PAST_POST_BASE_HEAT)))
	if typeof(result.get("input_target", {})) == TYPE_DICTIONARY:
		result["input_target"] = _copy_dict(result.get("input_target", {}))
	else:
		result["input_target"] = {}
	if result.has("input_msec"):
		result["input_msec"] = maxi(0, int(result.get("input_msec", 0)))
	if result.has("skill_grade"):
		result["skill_grade"] = str(result.get("skill_grade", ""))
	if result.has("skill_accuracy"):
		result["skill_accuracy"] = clampi(int(result.get("skill_accuracy", 0)), 0, 100)
	if result.has("skill_margin_msec"):
		result["skill_margin_msec"] = int(result.get("skill_margin_msec", 0))
	return result


func _finalize_past_post_challenge(ui_state: Dictionary, run_state: RunState, table: Dictionary, environment: Dictionary, last_result: Dictionary) -> Dictionary:
	var challenge := _normalized_past_post_challenge(ui_state.get("past_post_challenge", {}))
	if challenge.is_empty():
		challenge = _start_past_post_challenge(ui_state, run_state, table, environment, last_result)
	if ui_state.has("past_post_input_msec") and not challenge.has("input_msec"):
		challenge["input_msec"] = maxi(0, int(ui_state.get("past_post_input_msec", 0)))
	if not challenge.has("input_msec"):
		challenge["input_msec"] = _surface_time_msec(ui_state)
	challenge["input_target"] = _past_post_target_from_input(ui_state, table, str(challenge.get("winning_number", "0")), -1)
	return _grade_past_post_challenge(challenge)


func _grade_past_post_challenge(challenge: Dictionary) -> Dictionary:
	var graded := _normalized_past_post_challenge(challenge)
	if graded.is_empty():
		return {}
	if not graded.has("input_msec") or int(graded.get("input_msec", 0)) <= 0:
		graded["skill_grade"] = "miss"
		graded["skill_margin_msec"] = 0
		graded["reaction_msec"] = 0
		graded["skill_accuracy"] = 0
		return graded
	var window_start := int(graded.get("window_start_msec", 0))
	var reaction := int(graded.get("input_msec", 0)) - window_start
	var grade := "blown"
	var accuracy := 0
	if reaction >= 0:
		var timing := GameModule.skill_timing_grade_from_distance(
			reaction,
			int(graded.get("perfect_window_msec", PAST_POST_PERFECT_MSEC)),
			int(graded.get("good_window_msec", PAST_POST_GOOD_MSEC)),
			int(graded.get("window_msec", PAST_POST_WINDOW_MSEC))
		)
		grade = str(timing.get("skill_grade", "blown"))
		accuracy = clampi(int(timing.get("skill_accuracy", 0)), 0, 100)
	graded["skill_grade"] = grade
	graded["reaction_msec"] = reaction
	graded["skill_margin_msec"] = reaction
	graded["skill_accuracy"] = accuracy
	return graded


func _past_post_grade_applies(grade: String) -> bool:
	return GameModule.skill_grade_applies(grade)


func _past_post_grade_heat_modifier(grade: String) -> int:
	match grade:
		"perfect":
			return -PAST_POST_PERFECT_HEAT_REDUCTION
		"partial":
			return PAST_POST_PARTIAL_HEAT_BONUS
		"miss":
			return PAST_POST_MISS_HEAT_BONUS
		"blown":
			return PAST_POST_BLOWN_HEAT_BONUS
	return 0


func _past_post_skill_outcome(grade: String) -> String:
	return GameModule.skill_outcome_for_grade("past_post", grade)


func _past_post_payout_mult_for_grade(grade: String, target: Dictionary) -> int:
	if grade == "perfect":
		return int(target.get("payout", 35))
	if grade == "good":
		return mini(int(target.get("payout", 17)), 17)
	if grade == "partial":
		return 1
	return 0


func _past_post_target_from_input(ui_state: Dictionary, table: Dictionary, winning_number: String, index: int = -1) -> Dictionary:
	if typeof(ui_state.get("past_post_input_target", {})) == TYPE_DICTIONARY:
		var explicit_target := _copy_dict(ui_state.get("past_post_input_target", {}))
		if not explicit_target.is_empty():
			return _normalize_past_post_target(explicit_target)
	var target_index := index
	if target_index < 0 and ui_state.has("past_post_input_target_index"):
		target_index = int(ui_state.get("past_post_input_target_index", -1))
	var targets := _roulette_bet_targets(table)
	if target_index >= 0 and target_index < targets.size():
		return _normalize_past_post_target(targets[target_index])
	var exact := _roulette_target_for_type_numbers(targets, "straight", [winning_number])
	if not exact.is_empty():
		return _normalize_past_post_target(exact)
	return _normalize_past_post_target(_default_smoke_bet(1))


func _past_post_target_for_grade(challenge: Dictionary, table: Dictionary) -> Dictionary:
	var winning_number := str(challenge.get("winning_number", "0"))
	var target := _copy_dict(challenge.get("input_target", {}))
	if str(challenge.get("skill_grade", "")) == "partial":
		var outside := _past_post_outside_target(table, winning_number)
		if not outside.is_empty():
			return outside
	if target.is_empty():
		return _past_post_target_from_input({}, table, winning_number, -1)
	return _normalize_past_post_target(target)


func _past_post_outside_target(table: Dictionary, winning_number: String) -> Dictionary:
	var targets := _roulette_bet_targets(table)
	var color := _roulette_color(winning_number)
	if color == "red":
		return _normalize_past_post_target(_roulette_target_for_type_numbers(targets, "red", RED_NUMBERS))
	if color == "black":
		return _normalize_past_post_target(_roulette_target_for_type_numbers(targets, "black", BLACK_NUMBERS))
	var low := _roulette_target_for_type_numbers(targets, "low", _range_strings(1, 18))
	return _normalize_past_post_target(low)


func _normalize_past_post_target(value: Variant) -> Dictionary:
	var target := _copy_dict(value)
	if target.is_empty():
		return {}
	target["type"] = str(target.get("type", "straight"))
	target["numbers"] = _string_array(target.get("numbers", []))
	target["payout"] = maxi(0, int(target.get("payout", 0)))
	target["label"] = str(target.get("label", ",".join(_string_array(target.get("numbers", [])))))
	target["family"] = str(target.get("family", "inside"))
	if not target.has("id"):
		target["id"] = _canonical_bet_id(str(target.get("type", "straight")), _string_array(target.get("numbers", [])))
	target["stake"] = maxi(1, int(target.get("stake", 1)))
	if not target.has("placement"):
		target["placement"] = _vector_to_dict(Vector2(490, 190))
	return target


func _past_post_allowed_targets(table: Dictionary, winning_number: String) -> Array:
	var targets := _roulette_bet_targets(table)
	var allowed: Array = []
	var exact := _roulette_target_for_type_numbers(targets, "straight", [winning_number])
	if not exact.is_empty():
		allowed.append(str(exact.get("id", "")))
	var sequence := _wheel_sequence(table)
	var index := sequence.find(winning_number)
	if index >= 0:
		for offset in [-1, 1]:
			var neighbor := str(sequence[posmod(index + int(offset), sequence.size())])
			var neighbor_target := _roulette_target_for_type_numbers(targets, "straight", [neighbor])
			if not neighbor_target.is_empty():
				allowed.append(str(neighbor_target.get("id", "")))
	var outside := _past_post_outside_target(table, winning_number)
	if not outside.is_empty():
		allowed.append(str(outside.get("id", "")))
	return allowed


func _past_post_message(grade: String, chip_value: int, target: Dictionary, bankroll_delta: int, suspicion_delta: int, table_pressure: String, security_message: String) -> String:
	var label := str(target.get("label", "the layout"))
	var message := ""
	match grade:
		"perfect":
			message = "Perfect late chip: $%d lands on %s before the dolly. Bankroll %+d; heat %+d." % [chip_value, label, bankroll_delta, suspicion_delta]
		"good":
			message = "Good late chip: the slide catches %s with a capped payoff. Bankroll %+d; heat %+d." % [label, bankroll_delta, suspicion_delta]
		"partial":
			message = "Partial late chip: you only reach an outside cover bet. Bankroll %+d; heat %+d." % [bankroll_delta, suspicion_delta]
		"blown":
			message = "Blown late chip: the croupier catches the move and voids the chip. Bankroll %+d; heat %+d." % [bankroll_delta, suspicion_delta]
		_:
			message = "Missed late chip: your hand hangs over the felt. Bankroll %+d; heat %+d." % [bankroll_delta, suspicion_delta]
	if not table_pressure.is_empty():
		message = "%s %s" % [message, table_pressure]
	if not security_message.is_empty():
		message = "%s %s" % [message, security_message]
	return message


func _record_past_post_table_result(table: Dictionary, last_result: Dictionary, challenge: Dictionary, target: Dictionary, bankroll_delta: int, suspicion_delta: int, message: String) -> void:
	last_result["past_post_resolved"] = true
	last_result["past_post_challenge_id"] = str(challenge.get("challenge_id", ""))
	last_result["past_post_grade"] = str(challenge.get("skill_grade", "miss"))
	last_result["past_post_bankroll_delta"] = bankroll_delta
	last_result["past_post_suspicion_delta"] = suspicion_delta
	last_result["past_post_bet"] = target.duplicate(true)
	last_result["past_post_summary"] = message
	last_result["summary"] = message
	table["last_result"] = last_result


func wager_cost_for_context(action_id: String, stake: int, run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> int:
	if action_id != "spin_roulette":
		return 0
	var table := _table_state(run_state, environment)
	if bool(table.get("table_barred", false)):
		return 0
	var session := _normalized_session(run_state, environment, ui_state, table)
	var bets := _bet_array(session.get("roulette_bets", []))
	if bool(session.get("roulette_sit_out", false)) and bets.is_empty():
		return 0
	return _total_wager(bets) if not bets.is_empty() else 0


func environment_object_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var table := _table_state(run_state, environment)
	if table.is_empty():
		return {}
	var last_results := _dictionary_array(table.get("last_results", []))
	var last_label := "fresh wheel"
	if not last_results.is_empty():
		last_label = "last %s" % str((last_results[0] as Dictionary).get("winning_number", "?"))
	var barred := bool(table.get("table_barred", false))
	return {
		"runtime_state": {
			"spin_count": int(table.get("spin_count", 0)),
			"variant": str(table.get("variant", "american_double_zero")),
			"last_result": last_label,
			"patron_count": _dictionary_array(table.get("patrons", [])).size(),
		},
		"visual_state": {
			"prop": "roulette_table",
			"status": "barred" if barred else "open",
			"badge": "BARRED" if barred else "00 WHEEL",
			"summary": str(table.get("barred_reason", "")) if barred else "%s, %d spins, %s." % [str(table.get("dealer_name", "Croupier")), int(table.get("spin_count", 0)), last_label],
			"accent": "pink" if barred else "yellow",
		},
	}


func _standard_physics_profile(rng: RngStream) -> Dictionary:
	return {
		"preset": "standard_casino_wheel",
		"wheel_radius_m": 0.36,
		"rim_radius_m": 0.42,
		"ball_radius_m": 0.0095,
		"ball_mass_kg": 0.006,
		"rotor_initial_omega_min": -3.2,
		"rotor_initial_omega_max": -2.2,
		"rotor_angular_decel": 0.018,
		"ball_initial_omega_min": 18.0,
		"ball_initial_omega_max": 22.0,
		"ball_angular_decel_min": 0.86,
		"ball_angular_decel_max": 1.16,
		"drop_omega_threshold": 6.8,
		"diamond_count": 8,
		"diamond_phase": _rng_float(rng, 0.0, TAU),
		"diamond_restitution": 0.42,
		"diamond_scatter_degrees": 24.0,
		"pocket_depth": 0.62,
		"pocket_rebound": 0.18,
		"tilt_degrees": 0.0,
		"tilt_angle": _rng_float(rng, 0.0, TAU),
		"level_bias_strength": 0.0,
		"micro_scatter": 0.035,
	}


func _effective_physics_profile(table: Dictionary, run_state: RunState, environment: Dictionary, _ui_state: Dictionary, _rng: RngStream) -> Dictionary:
	var profile := _normalize_physics_profile(table.get("physics_profile", {}))
	for modifier in _physics_modifiers(run_state, environment, table):
		if typeof(modifier) == TYPE_DICTIONARY:
			profile = _apply_physics_modifier(profile, modifier as Dictionary)
	return profile


func _physics_modifiers(_run_state: RunState, _environment: Dictionary, _table: Dictionary) -> Array:
	return []


func _apply_physics_modifier(profile: Dictionary, modifier: Dictionary) -> Dictionary:
	var result := profile.duplicate(true)
	for key in ["ball_angular_decel", "diamond_scatter_degrees", "tilt_degrees", "level_bias_strength", "micro_scatter", "drop_omega_threshold"]:
		var delta_key := "%s_delta" % key
		if modifier.has(delta_key):
			result[key] = float(result.get(key, 0.0)) + float(modifier.get(delta_key, 0.0))
	if modifier.has("ball_angular_decel_delta"):
		result["ball_angular_decel_min"] = float(result.get("ball_angular_decel_min", 0.86)) + float(modifier.get("ball_angular_decel_delta", 0.0))
		result["ball_angular_decel_max"] = float(result.get("ball_angular_decel_max", 1.16)) + float(modifier.get("ball_angular_decel_delta", 0.0))
	return _normalize_physics_profile(result)


func _simulate_spin(table: Dictionary, profile: Dictionary, rng: RngStream) -> Dictionary:
	var launch := _sample_launch_conditions(profile, rng)
	var drop_time := _solve_drop_time(launch, profile)
	var drop := _state_at_time(launch, profile, drop_time)
	var deflect := _resolve_deflector_hit(drop, profile, rng)
	var capture := _resolve_pocket_capture(deflect, profile, table, rng)
	var spin_id := "roulette_%d_%d_%d" % [int(table.get("spin_count", 0)) + 1, int(launch.get("launch_nonce", 0)), int(capture.get("index", 0))]
	return {
		"spin_id": spin_id,
		"winning_number": str(capture.get("number", "0")),
		"winning_index": int(capture.get("index", 0)),
		"winning_color": _roulette_color(str(capture.get("number", "0"))),
		"drop_time": drop_time,
		"drop_angle": float(drop.get("ball_angle", 0.0)),
		"deflector_index": int(deflect.get("deflector_index", 0)),
		"physics": {
			"launch": launch,
			"drop": drop,
			"deflect": deflect,
			"capture": capture,
			"profile": profile.duplicate(true),
			"drop_time": drop_time,
			"deflector_index": int(deflect.get("deflector_index", 0)),
			"settle_time": float(capture.get("settle_time", 0.0)),
			"relative_angle": float(capture.get("relative_angle", 0.0)),
			"capture_energy": float(capture.get("capture_energy", 0.0)),
			"winning_index": int(capture.get("index", 0)),
		},
		"trajectory": _build_spin_trajectory(launch, drop, deflect, capture, profile, table),
	}


func _sample_launch_conditions(profile: Dictionary, rng: RngStream) -> Dictionary:
	return {
		"launch_nonce": rng.randi_range(100000, 999999),
		"ball_angle0": _rng_float(rng, 0.0, TAU),
		"rotor_angle0": _rng_float(rng, 0.0, TAU),
		"ball_omega0": _rng_float(rng, float(profile.get("ball_initial_omega_min", 18.0)), float(profile.get("ball_initial_omega_max", 22.0))),
		"rotor_omega0": _rng_float(rng, float(profile.get("rotor_initial_omega_min", -3.2)), float(profile.get("rotor_initial_omega_max", -2.2))),
		"ball_decel": _rng_float(rng, float(profile.get("ball_angular_decel_min", 0.86)), float(profile.get("ball_angular_decel_max", 1.16))),
		"rotor_decel": float(profile.get("rotor_angular_decel", 0.018)),
	}


func _solve_drop_time(launch: Dictionary, profile: Dictionary) -> float:
	var omega0 := float(launch.get("ball_omega0", 20.0))
	var decel := maxf(0.05, float(launch.get("ball_decel", 1.0)))
	var threshold := maxf(1.0, float(profile.get("drop_omega_threshold", 6.8)) - float(profile.get("tilt_degrees", 0.0)) * 0.04)
	return clampf((omega0 - threshold) / decel, 3.0, 22.0)


func _state_at_time(launch: Dictionary, _profile: Dictionary, t: float) -> Dictionary:
	var ball_angle0 := float(launch.get("ball_angle0", 0.0))
	var rotor_angle0 := float(launch.get("rotor_angle0", 0.0))
	var ball_omega0 := float(launch.get("ball_omega0", 20.0))
	var rotor_omega0 := float(launch.get("rotor_omega0", -2.6))
	var ball_decel := float(launch.get("ball_decel", 1.0))
	var rotor_decel := float(launch.get("rotor_decel", 0.018))
	var rotor_sign := -1.0 if rotor_omega0 < 0.0 else 1.0
	return {
		"time": t,
		"ball_angle": fposmod(ball_angle0 + ball_omega0 * t - 0.5 * ball_decel * t * t, TAU),
		"rotor_angle": fposmod(rotor_angle0 + rotor_omega0 * t - 0.5 * rotor_sign * rotor_decel * t * t, TAU),
		"ball_omega": maxf(0.0, ball_omega0 - ball_decel * t),
		"rotor_omega": rotor_omega0 - rotor_sign * rotor_decel * t,
	}


func _resolve_deflector_hit(drop: Dictionary, profile: Dictionary, rng: RngStream) -> Dictionary:
	var diamonds := clampi(int(profile.get("diamond_count", 8)), 4, 16)
	var diamond_width := TAU / float(diamonds)
	var phase := float(profile.get("diamond_phase", 0.0))
	var angle := fposmod(float(drop.get("ball_angle", 0.0)) - phase, TAU)
	var deflector_index := int(floor(angle / diamond_width)) % diamonds
	var scatter_degrees := maxf(0.0, float(profile.get("diamond_scatter_degrees", 24.0)))
	var scatter := deg_to_rad(_rng_float(rng, -scatter_degrees, scatter_degrees))
	var tilt_strength := float(profile.get("level_bias_strength", 0.0)) + absf(float(profile.get("tilt_degrees", 0.0))) * 0.022
	var tilt_angle := float(profile.get("tilt_angle", 0.0))
	var tilt_bias := sin(tilt_angle - float(drop.get("ball_angle", 0.0))) * tilt_strength
	return {
		"deflector_index": deflector_index,
		"scatter_angle": scatter + tilt_bias,
		"restitution": clampf(float(profile.get("diamond_restitution", 0.42)), 0.05, 0.95),
		"entry_time": float(drop.get("time", 0.0)),
		"ball_angle": float(drop.get("ball_angle", 0.0)),
		"rotor_angle": float(drop.get("rotor_angle", 0.0)),
		"ball_omega": float(drop.get("ball_omega", 0.0)),
		"rotor_omega": float(drop.get("rotor_omega", 0.0)),
	}


func _resolve_pocket_capture(deflected_state: Dictionary, profile: Dictionary, table: Dictionary, rng: RngStream) -> Dictionary:
	var sequence := _wheel_sequence(table)
	var count := maxi(1, sequence.size())
	var pocket_width := TAU / float(count)
	var scatter := float(deflected_state.get("scatter_angle", 0.0))
	var settle_time := 0.62 + clampf(float(profile.get("diamond_restitution", 0.42)), 0.05, 0.95) * 0.44
	var rotor_angle := fposmod(float(deflected_state.get("rotor_angle", 0.0)) + float(deflected_state.get("rotor_omega", -2.0)) * settle_time, TAU)
	var ball_angle := fposmod(float(deflected_state.get("ball_angle", 0.0)) + scatter + float(deflected_state.get("ball_omega", 6.0)) * settle_time * 0.28, TAU)
	var relative := fposmod(ball_angle - rotor_angle, TAU)
	var raw_index := int(floor(relative / pocket_width)) % count
	var relative_velocity := absf(float(deflected_state.get("ball_omega", 6.0)) - float(deflected_state.get("rotor_omega", -2.0)))
	var energy := relative_velocity * float(profile.get("pocket_depth", 0.62)) * clampf(float(profile.get("diamond_restitution", 0.42)), 0.05, 0.95)
	var micro := _rng_float(rng, -1.0, 1.0) * float(profile.get("micro_scatter", 0.035)) * float(count)
	var overshoot := int(round(energy + micro))
	if scatter < 0.0:
		overshoot = -overshoot
	var final_index := posmod(raw_index + overshoot, count)
	var final_ball_angle := fposmod(rotor_angle + (float(final_index) + 0.5) * pocket_width, TAU)
	return {
		"relative_angle": relative,
		"raw_index": raw_index,
		"overshoot": overshoot,
		"index": final_index,
		"number": str(sequence[final_index]),
		"pre_capture_ball_angle": ball_angle,
		"final_ball_angle": final_ball_angle,
		"final_rotor_angle": rotor_angle,
		"settle_time": settle_time,
		"capture_energy": energy,
	}


func _build_spin_trajectory(launch: Dictionary, drop: Dictionary, deflect: Dictionary, capture: Dictionary, profile: Dictionary, _table: Dictionary) -> Array:
	var result: Array = []
	var drop_time := maxf(0.1, float(drop.get("time", 8.0)))
	var settle_time := drop_time + 1.2 + float(capture.get("settle_time", 0.8))
	var ball_angle0 := float(launch.get("ball_angle0", 0.0))
	var rotor_angle0 := float(launch.get("rotor_angle0", 0.0))
	var ball_omega0 := float(launch.get("ball_omega0", 20.0))
	var rotor_omega0 := float(launch.get("rotor_omega0", -2.6))
	var ball_decel := float(launch.get("ball_decel", 1.0))
	var rotor_decel := float(launch.get("rotor_decel", 0.018))
	var rotor_sign := -1.0 if rotor_omega0 < 0.0 else 1.0
	var drop_ball_angle := float(drop.get("ball_angle", 0.0))
	var drop_rotor_angle := float(drop.get("rotor_angle", 0.0))
	var final_ball_angle := float(capture.get("final_ball_angle", drop_ball_angle))
	var final_rotor_angle := float(capture.get("final_rotor_angle", drop_rotor_angle))
	var scatter_angle := float(deflect.get("scatter_angle", 0.0))
	for i in range(TRAJECTORY_KEYFRAMES):
		var p := float(i) / float(maxi(1, TRAJECTORY_KEYFRAMES - 1))
		var t := p * settle_time
		var sim_t := minf(t, drop_time)
		var phase := "rim"
		var radius := WHEEL_RADIUS - 8.0
		var bounce := 0.0
		var ball_angle := fposmod(ball_angle0 + ball_omega0 * sim_t - 0.5 * ball_decel * sim_t * sim_t, TAU)
		var wheel_angle := fposmod(rotor_angle0 + rotor_omega0 * sim_t - 0.5 * rotor_sign * rotor_decel * sim_t * sim_t, TAU)
		if t > drop_time:
			var local := clampf((t - drop_time) / maxf(0.1, settle_time - drop_time), 0.0, 1.0)
			phase = "capture" if local > 0.76 else "scatter" if local > 0.38 else "deflect"
			radius = lerpf(WHEEL_RADIUS - 8.0, WHEEL_RADIUS * 0.58, local)
			ball_angle = fposmod(lerp_angle(drop_ball_angle + scatter_angle, final_ball_angle, local), TAU)
			wheel_angle = fposmod(lerp_angle(drop_rotor_angle, final_rotor_angle, local), TAU)
			bounce = sin(local * PI * 9.0) * (1.0 - local) * 8.0
		result.append({
			"t": p,
			"ball_angle": ball_angle,
			"wheel_angle": wheel_angle,
			"ball_radius": radius,
			"bounce": bounce,
			"phase": phase,
		})
	return result


func _roulette_bet_targets(table: Dictionary) -> Array:
	var targets: Array = []
	var american := int(_table_rules(table).get("zero_count", 2)) == 2
	targets.append(_bet_target("straight", ["0"], 35, "0", ZERO_RECT.grow(-5), "inside"))
	if american:
		targets.append(_bet_target("straight", ["00"], 35, "00", DOUBLE_ZERO_RECT.grow(-5), "inside"))
	for number in range(1, 37):
		targets.append(_bet_target("straight", [str(number)], 35, str(number), _number_cell(number).grow(-4), "inside"))
	for row in range(12):
		var base := row * 3 + 1
		targets.append(_bet_target("street", [str(base), str(base + 1), str(base + 2)], 11, "%d-%d-%d" % [base, base + 1, base + 2], Rect2(GRID_RECT.position.x + float(row) * CELL_W + 4, LINE_BET_Y, CELL_W - 8, LINE_BET_H), "inside"))
	for row in range(11):
		var base := row * 3 + 1
		var nums: Array = []
		for n in range(base, base + 6):
			nums.append(str(n))
		targets.append(_bet_target("six_line", nums, 5, "%d-%d" % [base, base + 5], Rect2(GRID_RECT.position.x + float(row + 1) * CELL_W - 6, LINE_BET_Y, 12, LINE_BET_H), "inside"))
	for row in range(12):
		var base := row * 3 + 1
		targets.append(_bet_target("split", [str(base), str(base + 1)], 17, "%d/%d" % [base, base + 1], _split_rect(base, base + 1), "inside"))
		targets.append(_bet_target("split", [str(base + 1), str(base + 2)], 17, "%d/%d" % [base + 1, base + 2], _split_rect(base + 1, base + 2), "inside"))
	for row in range(11):
		for col in range(3):
			var n := row * 3 + col + 1
			targets.append(_bet_target("split", [str(n), str(n + 3)], 17, "%d/%d" % [n, n + 3], _split_rect(n, n + 3), "inside"))
	for row in range(11):
		for col in range(2):
			var n := row * 3 + col + 1
			targets.append(_bet_target("corner", [str(n), str(n + 1), str(n + 3), str(n + 4)], 8, "%d/%d/%d/%d" % [n, n + 1, n + 3, n + 4], _corner_rect(n), "inside"))
	targets.append(_bet_target("trio", ["0", "1", "2"], 11, "0/1/2", Rect2(318, 220, 18, 14), "inside"))
	if american:
		targets.append(_bet_target("split", ["0", "00"], 17, "0/00", Rect2(288, 205, 28, 10), "inside"))
		targets.append(_bet_target("trio", ["0", "00", "2"], 11, "0/00/2", Rect2(318, 203, 18, 14), "inside"))
		targets.append(_bet_target("trio", ["00", "2", "3"], 11, "00/2/3", Rect2(318, 186, 18, 14), "inside"))
		targets.append(_bet_target("top_line", ["0", "00", "1", "2", "3"], 6, "0/00/1/2/3", Rect2(286, LINE_BET_Y, 44, LINE_BET_H), "inside"))
	else:
		targets.append(_bet_target("first_four", ["0", "1", "2", "3"], 8, "0/1/2/3", Rect2(286, LINE_BET_Y, 44, LINE_BET_H), "inside"))
	_add_outside_targets(targets)
	return targets


func _add_outside_targets(targets: Array) -> void:
	targets.append(_bet_target("dozen", _range_strings(1, 12), 2, "1st 12", Rect2(332, OUTSIDE_Y, 120, 28), "outside"))
	targets.append(_bet_target("dozen", _range_strings(13, 24), 2, "2nd 12", Rect2(452, OUTSIDE_Y, 120, 28), "outside"))
	targets.append(_bet_target("dozen", _range_strings(25, 36), 2, "3rd 12", Rect2(572, OUTSIDE_Y, 120, 28), "outside"))
	targets.append(_bet_target("low", _range_strings(1, 18), 1, "1-18", Rect2(332, OUTSIDE_Y + 32, 60, 28), "outside"))
	targets.append(_bet_target("even", _even_numbers(), 1, "EVEN", Rect2(392, OUTSIDE_Y + 32, 60, 28), "outside"))
	targets.append(_bet_target("red", RED_NUMBERS.duplicate(true), 1, "RED", Rect2(452, OUTSIDE_Y + 32, 60, 28), "outside"))
	targets.append(_bet_target("black", BLACK_NUMBERS.duplicate(true), 1, "BLACK", Rect2(512, OUTSIDE_Y + 32, 60, 28), "outside"))
	targets.append(_bet_target("odd", _odd_numbers(), 1, "ODD", Rect2(572, OUTSIDE_Y + 32, 60, 28), "outside"))
	targets.append(_bet_target("high", _range_strings(19, 36), 1, "19-36", Rect2(632, OUTSIDE_Y + 32, 60, 28), "outside"))
	targets.append(_bet_target("column", _column_numbers(0), 2, "2 TO 1", Rect2(692, GRID_RECT.position.y, 46, CELL_H), "outside"))
	targets.append(_bet_target("column", _column_numbers(1), 2, "2 TO 1", Rect2(692, GRID_RECT.position.y + CELL_H, 46, CELL_H), "outside"))
	targets.append(_bet_target("column", _column_numbers(2), 2, "2 TO 1", Rect2(692, GRID_RECT.position.y + CELL_H * 2.0, 46, CELL_H), "outside"))


func _bet_target(type: String, numbers: Array, payout: int, label: String, rect: Rect2, family: String) -> Dictionary:
	var normalized_numbers := _string_array(numbers)
	return {
		"id": _canonical_bet_id(type, normalized_numbers),
		"type": type,
		"numbers": normalized_numbers,
		"stake": 0,
		"payout": payout,
		"label": label,
		"family": family,
		"origin": "layout",
		"rect": _rect_to_dict(rect),
		"placement": _vector_to_dict(rect.get_center()),
	}


func _validate_roulette_bets(bets: Array, table: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	if bets.is_empty():
		return {"ok": false, "message": "Place chips on the layout before the spin."}
	var rules := _table_rules(table)
	var total := _total_wager(bets)
	if total <= 0:
		return {"ok": false, "message": "No roulette chips are at risk."}
	var max_table := int(rules.get("table_max", 100))
	if total > max_table:
		return {"ok": false, "message": "That exceeds the table maximum."}
	var bankroll := maxi(0, run_state.bankroll if run_state != null else total)
	if total > bankroll:
		return {"ok": false, "message": "You do not have enough bankroll for those roulette chips."}
	var outside_min := int(rules.get("outside_min_each", 1))
	var inside_total := 0
	for bet_value in bets:
		if typeof(bet_value) != TYPE_DICTIONARY:
			continue
		var bet: Dictionary = bet_value
		var stake := int(bet.get("stake", 0))
		if stake <= 0:
			return {"ok": false, "message": "Roulette bets must have positive chips."}
		if str(bet.get("family", "inside")) == "inside":
			inside_total += stake
		elif stake < outside_min:
			return {"ok": false, "message": "Outside bets must meet the outside minimum."}
	var inside_min := int(rules.get("inside_min_total", 1))
	if inside_total > 0 and inside_total < inside_min:
		return {"ok": false, "message": "Inside bets must meet the inside minimum."}
	if typeof(environment.get("economic_profile", {})) == TYPE_DICTIONARY:
		var ceiling := int((environment.get("economic_profile", {}) as Dictionary).get("stake_ceiling", max_table))
		if ceiling > 0 and total > ceiling:
			return {"ok": false, "message": "This room's stake ceiling will not cover those chips."}
	return {"ok": true}


func _settle_roulette_bets(winning_number: String, bets: Array, table: Dictionary) -> Array:
	var results: Array = []
	var color := _roulette_color(winning_number)
	for bet_value in bets:
		if typeof(bet_value) != TYPE_DICTIONARY:
			continue
		var bet: Dictionary = (bet_value as Dictionary).duplicate(true)
		var numbers := _string_array(bet.get("numbers", []))
		var stake := maxi(0, int(bet.get("stake", 0)))
		var payout := maxi(0, int(bet.get("payout", 0)))
		var won := numbers.has(winning_number)
		var bankroll_delta := stake * payout if won else -stake
		if not won and _is_zero(winning_number) and _la_partage_applies(bet, table):
			bankroll_delta = -int(ceil(float(stake) * 0.5))
		var celebration_score := _roulette_celebration_score(bet, won)
		results.append({
			"id": str(bet.get("id", "")),
			"type": str(bet.get("type", "")),
			"label": str(bet.get("label", "")),
			"numbers": numbers,
			"stake": stake,
			"payout": payout,
			"won": won,
			"winning_number": winning_number,
			"winning_color": color,
			"bankroll_delta": bankroll_delta,
			"celebration_score": celebration_score,
			"detail": "wins %d to 1" % payout if won else "zero half-loss" if bankroll_delta > -stake else "loses",
		})
	return results


func _la_partage_applies(bet: Dictionary, table: Dictionary) -> bool:
	if not bool(_table_rules(table).get("la_partage", false)):
		return false
	if str(bet.get("family", "")) != "outside":
		return false
	return int(bet.get("payout", 0)) == 1


func _roulette_celebration_score(bet: Dictionary, won: bool) -> int:
	if not won:
		return 0
	var payout := maxi(0, int(bet.get("payout", 0)))
	var stake := maxi(1, int(bet.get("stake", 1)))
	return clampi(payout * 2 + int(round(log(float(stake) + 1.0) / log(2.0))), 1, 100)


func _select_chip_command(index: int, state: Dictionary, table: Dictionary) -> Dictionary:
	var denoms := _chip_denominations(table)
	var chip: int = int(denoms[clampi(index, 0, denoms.size() - 1)])
	state["selected_chip"] = chip
	state["selected_stake"] = chip
	return GameModule.surface_command({
		"handled": true,
		"ui_state": state,
		"set_stake": chip,
		"selected_index": index,
		"message": "$%d roulette chip selected." % chip,
	})


func _place_bet_command(index: int, state: Dictionary, table: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var targets := _roulette_bet_targets(table)
	if index < 0 or index >= targets.size():
		return _message_command(state, "That roulette space is not available.")
	var target: Dictionary = targets[index]
	_push_undo_state(state)
	var bets := _bet_array(state.get("roulette_bets", []))
	var chip := maxi(1, int(state.get("selected_chip", _chip_denominations(table)[0])))
	var placed := false
	for i in range(bets.size()):
		var bet: Dictionary = bets[i]
		if str(bet.get("id", "")) == str(target.get("id", "")):
			bet["stake"] = int(bet.get("stake", 0)) + chip
			bets[i] = bet
			placed = true
			break
	if not placed:
		var next_bet := target.duplicate(true)
		next_bet["stake"] = chip
		bets.append(next_bet)
	state["roulette_bets"] = bets
	state.erase("table_social_alignment")
	var validation := _validate_roulette_bets(bets, table, run_state, environment)
	if not bool(validation.get("ok", false)):
		state["roulette_bets"] = _pop_undo_state(state)
		return _message_command(state, str(validation.get("message", "Those chips cannot stay on the layout.")))
	return GameModule.surface_command({
		"handled": true,
		"ui_state": state,
		"set_stake": chip,
		"selected_index": index,
		"message": "$%d on %s." % [chip, str(target.get("label", "roulette"))],
	})


func _patron_focus_command(index: int, state: Dictionary, table: Dictionary) -> Dictionary:
	var patrons := _dictionary_array(table.get("patrons", []))
	var visible_count := mini(patrons.size(), MAX_VISIBLE_PATRONS)
	if index < 0 or index >= visible_count:
		return _message_command(state, "That roulette player is no longer seated.")
	var patron: Dictionary = patrons[index]
	var wager := _patron_roulette_wager(patron, table, index)
	state["focused_patron_index"] = index
	state["selected_patron_index"] = index
	state["selected_surface_action"] = "roulette_patron_focus"
	var wager_label := str(wager.get("label", "the layout")) if not wager.is_empty() else "the rail"
	return GameModule.surface_command({
		"handled": true,
		"ui_state": state,
		"selected_index": index,
		"preserve_surface_ui_state": true,
		"message": "%s is watching %s. Choose WITH to follow their bet or FADE to oppose it." % [str(patron.get("name", "Patron")), wager_label],
	})


func _patron_bet_command(index: int, state: Dictionary, table: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var fade := index >= 100
	var patron_index := index % 100
	var patrons := _dictionary_array(table.get("patrons", []))
	if patron_index < 0 or patron_index >= patrons.size():
		return _message_command(state, "That roulette player is no longer seated.")
	var patron: Dictionary = patrons[patron_index]
	var source_target := _patron_roulette_wager(patron, table, patron_index)
	if source_target.is_empty():
		return _message_command(state, "That player's roulette action is not on the layout.")
	var target := _roulette_fade_target(source_target, table, patron_index) if fade else source_target
	if target.is_empty():
		return _message_command(state, "There is no legal opposing bet for that wager.")
	var bets := _bet_array(state.get("roulette_bets", []))
	var rules := _table_rules(table)
	var wager := maxi(1, int(source_target.get("patron_stake", source_target.get("stake", 1))))
	var bankroll_room := maxi(0, (run_state.bankroll if run_state != null else wager) - _total_wager(bets))
	var table_room := maxi(0, int(rules.get("table_max", 100)) - _total_wager(bets))
	var chip := mini(wager, mini(bankroll_room, table_room))
	if chip <= 0:
		return _message_command(state, "No bankroll left to take that social roulette action.")
	if str(target.get("family", "")) == "outside":
		var outside_min := int(rules.get("outside_min_each", 1))
		if chip < outside_min:
			if mini(bankroll_room, table_room) >= outside_min:
				chip = outside_min
			else:
				return _message_command(state, "That outside bet cannot meet the table minimum.")
	_push_undo_state(state)
	var placed := false
	for i in range(bets.size()):
		var bet: Dictionary = bets[i]
		if str(bet.get("id", "")) == str(target.get("id", "")):
			bet["stake"] = int(bet.get("stake", 0)) + chip
			bets[i] = bet
			placed = true
			break
	if not placed:
		var next_bet := target.duplicate(true)
		next_bet["stake"] = chip
		bets.append(next_bet)
	state["roulette_bets"] = bets
	var validation := _validate_roulette_bets(bets, table, run_state, environment)
	if not bool(validation.get("ok", false)):
		state["roulette_bets"] = _pop_undo_state(state)
		return _message_command(state, str(validation.get("message", "Those social roulette chips cannot stay on the layout.")))
	state["table_social_alignment"] = {
		"game": "roulette",
		"patron_id": str(patron.get("id", "patron_%d" % patron_index)),
		"patron_name": str(patron.get("name", "Patron")),
		"stance": "against" if fade else "with",
		"source_bet": str(source_target.get("id", "")),
		"bet_id": str(target.get("id", "")),
		"stake": chip,
	}
	return GameModule.surface_command({
		"handled": true,
		"ui_state": state,
		"set_stake": chip,
		"selected_index": patron_index,
		"message": "%s %s: $%d on %s." % ["Fading" if fade else "Following", str(patron.get("name", "Patron")), chip, str(target.get("label", "roulette"))],
	})


func _patron_roulette_wager(patron: Dictionary, table: Dictionary, seat_index: int = 0) -> Dictionary:
	var targets := _roulette_bet_targets(table)
	var style := str(patron.get("bet_style", "outside_red"))
	var target := {}
	match style:
		"outside_red":
			target = _roulette_target_for_type_numbers(targets, "red", RED_NUMBERS)
		"columns":
			target = _roulette_target_for_type_numbers(targets, "column", _column_numbers(seat_index % 3))
		"favorite_17":
			target = _roulette_target_for_type_numbers(targets, "straight", ["17"])
		"dozens":
			var dozen_start := 1 + (seat_index % 3) * 12
			target = _roulette_target_for_type_numbers(targets, "dozen", _range_strings(dozen_start, dozen_start + 11))
		"chaotic_spread":
			target = _roulette_target_for_type_numbers(targets, "odd", _odd_numbers()) if seat_index % 2 == 0 else _roulette_target_for_type_numbers(targets, "black", BLACK_NUMBERS)
		_:
			target = _roulette_target_for_type_numbers(targets, "red", RED_NUMBERS)
	if target.is_empty():
		return {}
	target = target.duplicate(true)
	target["patron_stake"] = maxi(1, int(patron.get("cosmetic_bet", maxi(1, int(patron.get("chip_stack", 25)) / 4))))
	return target


func _roulette_fade_target(source_target: Dictionary, table: Dictionary, seat_index: int = 0) -> Dictionary:
	var targets := _roulette_bet_targets(table)
	var source_type := str(source_target.get("type", ""))
	match source_type:
		"red":
			return _roulette_target_for_type_numbers(targets, "black", BLACK_NUMBERS)
		"black":
			return _roulette_target_for_type_numbers(targets, "red", RED_NUMBERS)
		"odd":
			return _roulette_target_for_type_numbers(targets, "even", _even_numbers())
		"even":
			return _roulette_target_for_type_numbers(targets, "odd", _odd_numbers())
		"low":
			return _roulette_target_for_type_numbers(targets, "high", _range_strings(19, 36))
		"high":
			return _roulette_target_for_type_numbers(targets, "low", _range_strings(1, 18))
		"dozen":
			var nums: Array = _string_array(source_target.get("numbers", []))
			var next_start: int = 25 if nums.has("1") else 1 if nums.has("25") else 1
			return _roulette_target_for_type_numbers(targets, "dozen", _range_strings(next_start, next_start + 11))
		"column":
			return _roulette_target_for_type_numbers(targets, "column", _column_numbers((seat_index + 1) % 3))
		"straight":
			var nums: Array = _string_array(source_target.get("numbers", []))
			var number: String = str(nums[0]) if not nums.is_empty() else "17"
			var color := _roulette_color(number)
			if color == "red":
				return _roulette_target_for_type_numbers(targets, "black", BLACK_NUMBERS)
			if color == "black":
				return _roulette_target_for_type_numbers(targets, "red", RED_NUMBERS)
			return _roulette_target_for_type_numbers(targets, "high", _range_strings(19, 36))
		_:
			return _roulette_target_for_type_numbers(targets, "black", BLACK_NUMBERS)


func _roulette_target_for_type_numbers(targets: Array, type: String, numbers: Array) -> Dictionary:
	var target_id := _canonical_bet_id(type, _string_array(numbers))
	for target_value in targets:
		var target: Dictionary = target_value
		if str(target.get("id", "")) == target_id:
			return target
	return {}


func _roulette_bets_include_id(bets: Array, id: String) -> bool:
	for bet_value in bets:
		if typeof(bet_value) == TYPE_DICTIONARY and str((bet_value as Dictionary).get("id", "")) == id:
			return int((bet_value as Dictionary).get("stake", 0)) > 0
	return false


func _apply_patron_rapport_after_roulette(table: Dictionary, session: Dictionary, bets: Array, winning_number: String) -> void:
	var patrons := _dictionary_array(table.get("patrons", []))
	if patrons.is_empty():
		return
	var alignment := _copy_dict(session.get("table_social_alignment", {}))
	for i in range(patrons.size()):
		var patron: Dictionary = patrons[i]
		var source_target := _patron_roulette_wager(patron, table, i)
		var fade_target := _roulette_fade_target(source_target, table, i)
		var same := not source_target.is_empty() and _roulette_bets_include_id(bets, str(source_target.get("id", "")))
		var against := not fade_target.is_empty() and _roulette_bets_include_id(bets, str(fade_target.get("id", "")))
		var delta := 0
		if same:
			delta += 2
		if against:
			delta -= 2
		if str(alignment.get("patron_id", "")) == str(patron.get("id", "patron_%d" % i)):
			delta += 4 if str(alignment.get("stance", "")) == "with" else -4
		if delta != 0:
			var patron_won := _string_array(source_target.get("numbers", [])).has(winning_number)
			if patron_won and same:
				delta += 1
			if patron_won and against:
				delta -= 1
			patron["rapport"] = clampi(int(patron.get("rapport", 50)) + delta, 0, 100)
			patron["last_social_delta"] = delta
			patron["last_social_stance"] = "with" if delta > 0 else "against"
		else:
			patron["last_social_delta"] = 0
			patron["last_social_stance"] = "neutral"
		patrons[i] = patron
	table["patrons"] = patrons


func _clear_bets_command(state: Dictionary) -> Dictionary:
	var bets := _bet_array(state.get("roulette_bets", []))
	if bets.is_empty():
		return _message_command(state, "The layout is already clear.")
	_push_undo_state(state)
	state["roulette_bets"] = []
	state.erase("table_social_alignment")
	return GameModule.surface_command({"handled": true, "ui_state": state, "message": "The croupier clears your unspun chips."})


func _undo_bets_command(state: Dictionary) -> Dictionary:
	var undo_stack := _array(state.get("roulette_undo_stack", []))
	if undo_stack.is_empty():
		return _message_command(state, "No roulette bet to undo.")
	state["roulette_bets"] = _pop_undo_state(state)
	state.erase("table_social_alignment")
	return GameModule.surface_command({"handled": true, "ui_state": state, "message": "Last roulette chip move undone."})


func _rebet_command(state: Dictionary, table: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var rebet := _bet_array(state.get("roulette_rebet", table.get("last_bets", [])))
	if rebet.is_empty():
		return _message_command(state, "No previous roulette bet to repeat.")
	var validation := _validate_roulette_bets(rebet, table, run_state, environment)
	if not bool(validation.get("ok", false)):
		return _message_command(state, str(validation.get("message", "The previous roulette bet will not fit this table.")))
	_push_undo_state(state)
	state["roulette_bets"] = rebet.duplicate(true)
	state.erase("table_social_alignment")
	return GameModule.surface_command({"handled": true, "ui_state": state, "message": "Previous roulette layout repeated."})


func _double_bets_command(state: Dictionary, table: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var bets := _bet_array(state.get("roulette_bets", []))
	if bets.is_empty():
		return _message_command(state, "Place roulette chips before doubling.")
	var doubled: Array = []
	for bet_value in bets:
		var bet: Dictionary = (bet_value as Dictionary).duplicate(true)
		bet["stake"] = int(bet.get("stake", 0)) * 2
		doubled.append(bet)
	var validation := _validate_roulette_bets(doubled, table, run_state, environment)
	if not bool(validation.get("ok", false)):
		return _message_command(state, str(validation.get("message", "Doubling would exceed the table or bankroll.")))
	_push_undo_state(state)
	state["roulette_bets"] = doubled
	return GameModule.surface_command({"handled": true, "ui_state": state, "message": "All roulette bets doubled."})


func _max_bet_command(state: Dictionary, table: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var denoms := _chip_denominations(table)
	var max_chip := int(denoms[denoms.size() - 1])
	if typeof(environment.get("economic_profile", {})) == TYPE_DICTIONARY:
		max_chip = mini(max_chip, maxi(1, int((environment.get("economic_profile", {}) as Dictionary).get("stake_ceiling", max_chip))))
	if run_state != null:
		max_chip = mini(max_chip, maxi(1, run_state.bankroll))
	state["selected_chip"] = max_chip
	state["selected_stake"] = max_chip
	return GameModule.surface_command({"handled": true, "ui_state": state, "set_stake": max_chip, "message": "$%d roulette chip selected." % max_chip})


func _spin_command(state: Dictionary, table: Dictionary, run_state: RunState, environment: Dictionary, confirm_requested: bool) -> Dictionary:
	var bets := _bet_array(state.get("roulette_bets", []))
	var sit_out := bets.is_empty()
	if not sit_out:
		var validation := _validate_roulette_bets(bets, table, run_state, environment)
		if not bool(validation.get("ok", false)):
			return _message_command(state, str(validation.get("message", "Those roulette bets cannot be placed.")))
	state["locked_bets"] = bets.duplicate(true)
	state["roulette_sit_out"] = sit_out
	var resolving := confirm_requested or bool(state.get("roulette_spin_armed", false))
	state["roulette_spin_armed"] = not resolving
	return GameModule.surface_command({
		"handled": true,
		"ui_state": state,
		"action_id": "spin_roulette",
		"action_kind": "legal",
		"resolve": resolving,
		"skip_stake_validation": sit_out,
		"preserve_surface_ui_state": not resolving,
		"message": "No wager down. Click again to sit out this spin." if sit_out and not resolving else "Spin selected. Click again to confirm the wheel." if not resolving else "No more bets. The ball is away.",
	})


func _nudge_wheel_command(index: int, state: Dictionary, table: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var cheats := _copy_dict(state.get("cheats_used", {}))
	var watch := _roulette_table_watch_status(table, run_state, environment)
	cheats["wheel_nudge"] = true
	cheats["wheel_nudge_heat"] = _nudge_wheel_heat(table, run_state, environment)
	cheats["wheel_nudge_watched"] = bool(watch.get("watched", false))
	state["cheats_used"] = cheats
	state["roulette_nudge_ready"] = true
	var message := "You palm the wheel rhythm. The next spin can be nudged."
	if bool(watch.get("watched", false)):
		message = "%s %s" % [message, str(watch.get("summary", "The table is watching your hands."))]
	return GameModule.surface_command({
		"handled": true,
		"ui_state": state,
		"selected_index": index,
		"message": message,
	})


func _read_wheel_command(index: int, state: Dictionary, table: Dictionary, run_state: RunState) -> Dictionary:
	var cheats := _copy_dict(state.get("cheats_used", {}))
	var heat := _read_wheel_heat(table, run_state)
	cheats["read_wheel_bias"] = true
	cheats["read_wheel_heat"] = heat
	state["cheats_used"] = cheats
	var profile := _normalize_physics_profile(table.get("physics_profile", {}))
	state["bias_read"] = {
		"tilt_degrees": float(profile.get("tilt_degrees", 0.0)),
		"scatter": float(profile.get("diamond_scatter_degrees", 0.0)),
		"message": "The ball favors late scatter near the low side." if absf(float(profile.get("tilt_degrees", 0.0))) > 0.05 else "The wheel looks level, but the diamonds are lively.",
	}
	return GameModule.surface_command({
		"handled": true,
		"ui_state": state,
		"action_id": "read_wheel_bias",
		"action_kind": "cheat",
		"resolve": false,
		"selected_index": index,
		"message": "You clock the rotor and the diamond pattern. Heat risk rises if you keep staring.",
	})


func _resolve_read_wheel(action_id: String, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary) -> Dictionary:
	var table := _table_state(run_state, environment)
	var heat := _read_wheel_heat(table, run_state)
	var suspicion_delta := run_state.alcohol_adjusted_suspicion_delta(heat) if run_state != null else heat
	var pit_boss_status := run_state.pit_boss_watch_status(environment) if run_state != null else {}
	var pit_boss_bonus := int(pit_boss_status.get("cheat_heat_bonus", 0)) if bool(pit_boss_status.get("active", false)) else 0
	var security_pressure: Dictionary = run_state.security_action_pressure("cheat", 0, run_state.suspicion_level() + suspicion_delta) if run_state != null else {}
	var bankroll_delta := int(security_pressure.get("bankroll_delta", 0))
	var message := "You read the roulette wheel's rhythm."
	var pit_boss_summary := str(pit_boss_status.get("summary", "")) if bool(pit_boss_status.get("active", false)) else ""
	if not pit_boss_summary.is_empty():
		message = "%s %s" % [message, pit_boss_summary]
	var table_pressure := _roulette_pressure_message(table, pit_boss_status)
	if not table_pressure.is_empty():
		message = "%s %s" % [message, table_pressure]
	if not str(security_pressure.get("message", "")).is_empty():
		message = "%s %s" % [message, str(security_pressure.get("message", ""))]
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["suspicion_delta"] = suspicion_delta
	deltas["messages"] = [message]
	deltas["story_log"] = [{
		"type": "game_action",
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": "cheat",
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"environment_id": environment.get("id", ""),
		"pit_boss_watched": bool(pit_boss_status.get("watched", false)),
		"pit_boss_heat_bonus": pit_boss_bonus,
		"table_pressure": table_pressure,
		"security_message": str(security_pressure.get("message", "")),
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
	result["roulette_bias_read"] = _copy_dict(ui_state.get("bias_read", {}))
	result["roulette_pit_boss_watched"] = bool(pit_boss_status.get("watched", false))
	result["roulette_pit_boss_heat_bonus"] = pit_boss_bonus
	result["roulette_table_pressure"] = table_pressure
	GameModule.apply_result(run_state, result, rng)
	return result


func _draw_roulette_room(surface, surface_state: Dictionary) -> void:
	TableVisualsScript.draw_room(surface, surface_state, str(surface_state.get("table_name", "Roulette")), _roulette_room_info(surface_state))


func _draw_roulette_table(surface, _surface_state: Dictionary) -> void:
	TableVisualsScript.draw_table(surface)


func _draw_roulette_wheel(surface, surface_state: Dictionary) -> void:
	var sequence := _string_array(surface_state.get("wheel_sequence", AMERICAN_SEQUENCE))
	var trajectory := _dictionary_array(surface_state.get("spin_trajectory", []))
	var spin_active: bool = bool(surface.surface_animation_active(ROULETTE_SPIN_CHANNEL))
	var progress: float = surface.surface_animation_progress(ROULETTE_SPIN_CHANNEL) if spin_active else 1.0
	var keyframe := _trajectory_keyframe(trajectory, progress)
	var wheel_default_angle := _surface_clock(surface) * -0.5 if spin_active else 0.0
	var wheel_angle := float(keyframe.get("wheel_angle", wheel_default_angle))
	var last_result := _copy_dict(surface_state.get("last_result", {}))
	var winning_index := int(last_result.get("winning_index", -1))
	var settled_spin := not spin_active and not last_result.is_empty()
	var reveal_result := settled_spin and bool(surface_state.get("result_reveal_active", false))
	var settled_elapsed := maxf(0.0, float(int(surface_state.get("surface_time_msec", Time.get_ticks_msec())) - int(last_result.get("resolved_at_msec", 0)) - SPIN_ANIMATION_DURATION_MSEC) / 1000.0) if reveal_result else 0.0
	var settled_drift := fposmod(settled_elapsed * -0.18, TAU) if reveal_result else 0.0
	if reveal_result:
		wheel_angle = fposmod(wheel_angle + settled_drift, TAU)
	var detailed_wheel := spin_active or reveal_result
	var draw_pocket_labels := detailed_wheel
	surface.draw_circle(WHEEL_CENTER, WHEEL_RADIUS + 10, Color("#1b0d16"))
	surface.draw_circle(WHEEL_CENTER, WHEEL_RADIUS + 4, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.28), false, 2)
	surface.draw_circle(WHEEL_CENTER, WHEEL_RADIUS, Color("#0b1118"))
	var count := maxi(1, sequence.size())
	if detailed_wheel:
		for i in range(count):
			var a0 := wheel_angle + float(i) / float(count) * TAU
			var a1 := wheel_angle + float(i + 1) / float(count) * TAU
			var mid := (a0 + a1) * 0.5
			var number := str(sequence[i])
			var color := _pocket_color(number)
			var p0 := WHEEL_CENTER + Vector2(cos(a0), sin(a0)) * (WHEEL_RADIUS - 2.0)
			var p1 := WHEEL_CENTER + Vector2(cos(a1), sin(a1)) * (WHEEL_RADIUS - 2.0)
			var inner := WHEEL_CENTER + Vector2(cos(mid), sin(mid)) * 48.0
			surface.draw_polygon([WHEEL_CENTER, p0, p1, inner], [color])
			var spoke_start := WHEEL_CENTER + Vector2(cos(a0), sin(a0)) * 52.0
			var spoke_end := WHEEL_CENTER + Vector2(cos(a0), sin(a0)) * (WHEEL_RADIUS - 3.0)
			surface.draw_line(spoke_start, spoke_end, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.16), 1)
	else:
		for i in range(12):
			var angle := wheel_angle + float(i) / 12.0 * TAU
			var color := Color("#8e1026") if i % 2 == 0 else Color("#111922")
			var spoke_start := WHEEL_CENTER + Vector2(cos(angle), sin(angle)) * 50.0
			var spoke_end := WHEEL_CENTER + Vector2(cos(angle), sin(angle)) * (WHEEL_RADIUS - 4.0)
			surface.draw_line(spoke_start, spoke_end, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.14), 1)
			surface.draw_circle(WHEEL_CENTER + Vector2(cos(angle + 0.12), sin(angle + 0.12)) * 76.0, 4.0, Color(color.r, color.g, color.b, 0.78))
	if draw_pocket_labels:
		for i in range(count):
			var a0 := wheel_angle + float(i) / float(count) * TAU
			var a1 := wheel_angle + float(i + 1) / float(count) * TAU
			var mid := (a0 + a1) * 0.5
			var number := str(sequence[i])
			var pocket_color := _pocket_color(number)
			var label_size := Vector2(19, 10) if number.length() > 1 else Vector2(15, 10)
			var label_pos := WHEEL_CENTER + Vector2(cos(mid), sin(mid)) * (WHEEL_RADIUS + 17.0)
			var label_rect := Rect2(label_pos - label_size * 0.5, label_size)
			surface.draw_rect(label_rect.grow(1.0), Color(0.01, 0.02, 0.04, 0.86))
			surface.draw_rect(label_rect.grow(1.0), Color(pocket_color.r, pocket_color.g, pocket_color.b, 0.92), false, 1)
			surface.surface_label_centered(number, label_rect, 6 if number.length() > 1 else 7, _wheel_label_color(number))
	if reveal_result and winning_index >= 0 and winning_index < count:
		var win_a0 := wheel_angle + float(winning_index) / float(count) * TAU
		var win_a1 := wheel_angle + float(winning_index + 1) / float(count) * TAU
		var win_mid := (win_a0 + win_a1) * 0.5
		var win_dir := Vector2(cos(win_mid), sin(win_mid))
		var marker_start := WHEEL_CENTER + win_dir * 48.0
		var result_label := str(last_result.get("winning_number", sequence[winning_index]))
		var result_pos := WHEEL_CENTER + win_dir * (WHEEL_RADIUS + 17.0)
		var result_rect := Rect2(result_pos - Vector2(14, 8), Vector2(28, 16))
		var label_edge_radius := absf(win_dir.x) * result_rect.size.x * 0.5 + absf(win_dir.y) * result_rect.size.y * 0.5
		var marker_end := result_pos - win_dir * (label_edge_radius + 3.0)
		surface.draw_line(marker_start, marker_end, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.92), 3)
		surface.draw_rect(result_rect.grow(2.0), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.22))
		surface.draw_rect(result_rect.grow(2.0), C_YELLOW, false, 2)
		surface.surface_label_centered(result_label, result_rect, 8, C_YELLOW)
	surface.draw_circle(WHEEL_CENTER, 44, Color("#241427"))
	surface.draw_circle(WHEEL_CENTER, 24, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.32))
	var ball_default_angle := _surface_clock(surface) * 2.0 if spin_active or reveal_result else -0.72
	var ball_angle := float(keyframe.get("ball_angle", ball_default_angle))
	if reveal_result:
		ball_angle = fposmod(ball_angle + settled_drift, TAU)
	var ball_radius := float(keyframe.get("ball_radius", WHEEL_RADIUS - 9.0))
	var bounce := float(keyframe.get("bounce", 0.0))
	var ball_pos := WHEEL_CENTER + Vector2(cos(ball_angle), sin(ball_angle)) * (ball_radius + bounce)
	surface.draw_circle(ball_pos, 6.0, Color("#e9f2f2"))
	surface.draw_circle(ball_pos + Vector2(-2, -2), 2.0, C_WHITE)


func _draw_static_croupier_station(surface, surface_state: Dictionary) -> void:
	var focus: Dictionary = TableVisualsScript.dealer_focus_for_state(surface_state)
	var rect := Rect2(352, 54, 196, 104)
	var danger := clampi(int(focus.get("peek_danger", 0)), 0, 100)
	var attention := clampi(int(focus.get("attention_meter", 0)), 0, 100)
	var accent := C_PINK if danger >= 70 else C_YELLOW if danger >= 42 else C_TEAL
	surface.draw_rect(rect, Color("#0b0d16"))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.18), false, 1)
	surface.draw_rect(Rect2(rect.position + Vector2(26, 26), Vector2(44, 54)), Color("#111827"))
	surface.draw_rect(Rect2(rect.position + Vector2(34, 12), Vector2(28, 26)), Color("#c49371"))
	surface.draw_rect(Rect2(rect.position + Vector2(34, 12), Vector2(28, 8)), Color("#2a1a25"))
	surface.draw_rect(Rect2(rect.position + Vector2(40, 25), Vector2(5, 3)), C_DARK)
	surface.draw_rect(Rect2(rect.position + Vector2(52, 25), Vector2(5, 3)), C_DARK)
	surface.surface_label(str(surface_state.get("dealer_name", "Croupier")).to_upper().left(14), rect.position + Vector2(84, 26), 10, C_WHITE)
	surface.surface_label(str(focus.get("status", "watching")).left(18), rect.position + Vector2(84, 43), 8, accent)
	var meter := Rect2(rect.position + Vector2(84, 54), Vector2(86, 6))
	surface.draw_rect(meter, Color("#070810"))
	surface.draw_rect(Rect2(meter.position, Vector2(meter.size.x * float(attention) / 100.0, meter.size.y)), accent)
	surface.surface_label(str(focus.get("body_language", "tracks the felt")).left(23), rect.position + Vector2(84, 75), 8, C_SOFT)


func _draw_static_table_patrons(surface, surface_state: Dictionary) -> void:
	var patrons := _dictionary_array(surface_state.get("patrons", []))
	var layout := _dictionary_array(surface_state.get("patron_layout", []))
	if layout.size() < patrons.size():
		layout = _roulette_patron_layout(patrons)
	var focused_index := _focused_patron_index(surface_state, patrons)
	for i in range(patrons.size()):
		if i >= layout.size():
			break
		var patron: Dictionary = patrons[i]
		var slot: Dictionary = layout[i]
		var rect := _rect_from_dict(slot.get("rect", {}))
		var foot := _vector_from_dict(slot.get("foot", {}), _patron_seat_position(i))
		var watching := bool(patron.get("watching_player", false))
		var covered := bool(patron.get("covered", false))
		var risk := int(patron.get("active_snitch_risk", patron.get("snitch_risk", 0)))
		var accent := C_PINK if watching else C_TEAL if covered else C_SOFT
		var selected := focused_index == i
		if selected or bool(surface.surface_region_hovered("roulette_patron_focus", i)):
			_draw_neon_panel(surface, rect.grow(3), accent, 0.14 if selected else 0.08)
		surface.draw_rect(Rect2(foot.x - 22, foot.y - 58, 44, 54), Color("#05060a"))
		surface.draw_rect(Rect2(foot.x - 16, foot.y - 48, 32, 42), Color("#172633" if covered else "#251930"))
		surface.draw_rect(Rect2(foot.x - 12, foot.y - 66, 24, 22), Color("#c49371"))
		surface.draw_rect(Rect2(foot.x - 12, foot.y - 66, 24, 7), _patron_hair_color(patron))
		surface.draw_rect(Rect2(foot.x - 6, foot.y - 57, 4, 3), C_DARK)
		surface.draw_rect(Rect2(foot.x + 6, foot.y - 57, 4, 3), C_DARK)
		surface.draw_rect(Rect2(foot.x - 22, foot.y - 2, 44, 4), Color(0, 0, 0, 0.28))
		surface.draw_rect(Rect2(rect.position.x + 8, rect.end.y - 22, 54, 4), Color("#040509"))
		surface.draw_rect(Rect2(rect.position.x + 8, rect.end.y - 22, clampf(float(risk) / 60.0, 0.0, 1.0) * 54.0, 4), accent)
		surface.surface_label(str(patron.get("behavior", str(patron.get("mood", "watching")))).left(13), rect.position + Vector2(8, rect.size.y - 8), 8, accent)
		surface.draw_circle(foot + Vector2(30, -8), 6.0, _chip_color_name(str(patron.get("chip_color", "cyan"))))
		surface.surface_add_exact_hit(rect, "roulette_patron_focus", i)
	_draw_focused_patron_panel(surface, surface_state, patrons, focused_index)


func _draw_table_patrons(surface, surface_state: Dictionary) -> void:
	var patrons := _dictionary_array(surface_state.get("patrons", []))
	var layout := _dictionary_array(surface_state.get("patron_layout", []))
	if layout.size() < patrons.size():
		layout = _roulette_patron_layout(patrons)
	var focused_index := _focused_patron_index(surface_state, patrons)
	for i in range(patrons.size()):
		if i >= layout.size():
			break
		var patron: Dictionary = patrons[i]
		var slot: Dictionary = layout[i]
		var rect := _rect_from_dict(slot.get("rect", {}))
		var foot := _vector_from_dict(slot.get("foot", {}), _patron_seat_position(i))
		var watching := bool(patron.get("watching_player", false))
		var covered := bool(patron.get("covered", false))
		var risk := int(patron.get("active_snitch_risk", patron.get("snitch_risk", 0)))
		var accent := C_PINK if watching else C_TEAL if covered else C_SOFT
		var selected := focused_index == i
		var phase := float(patron.get("behavior_phase", 0.0))
		var bob := sin(phase * PI * 2.0) * (2.0 if watching else 1.0)
		var lean := float(patron.get("lean", 0.0))
		var model_foot := foot + Vector2(lean, bob)
		if selected or bool(surface.surface_region_hovered("roulette_patron_focus", i)):
			_draw_neon_panel(surface, rect.grow(3), accent, 0.18 if selected else 0.10)
		_draw_table_character(surface, {
			"name": str(patron.get("name", "Seat")),
			"accent": accent,
			"hair": _patron_hair_color(patron),
			"jacket": _patron_jacket_color(patron),
			"pose": "covered" if covered else "snitch" if watching else "idle",
			"silhouette": str(patron.get("silhouette", "coat")),
			"blink": phase > 0.92,
			"eye_offset": -1.4 if covered else 1.4 if watching else 0.0,
		}, model_foot, 0.86)
		var label_pos := Vector2(rect.position.x + 8.0, rect.position.y + rect.size.y - 24.0)
		surface.surface_label(str(patron.get("behavior", str(patron.get("mood", "watching")))).left(13), label_pos, 8, accent)
		var risk_rect := Rect2(label_pos + Vector2(0, 13), Vector2(54, 4))
		surface.draw_rect(risk_rect, Color("#040509"))
		surface.draw_rect(Rect2(risk_rect.position, Vector2(clampf(float(risk) / 60.0, 0.0, 1.0) * risk_rect.size.x, risk_rect.size.y)), accent)
		_draw_small_color_chip(surface, foot + Vector2(30, -8), _chip_color_name(str(patron.get("chip_color", "cyan"))), maxi(1, int(patron.get("chip_stack", 0)) / 4))
		surface.surface_add_exact_hit(rect, "roulette_patron_focus", i)
		if selected:
			surface.draw_rect(rect.grow(5), Color(accent.r, accent.g, accent.b, 0.40), false, 2)
	_draw_focused_patron_panel(surface, surface_state, patrons, focused_index)


func _roulette_patron_layout(patrons: Array) -> Array:
	var count := clampi(patrons.size(), 0, MAX_VISIBLE_PATRONS)
	var result: Array = []
	if count <= 0:
		return result
	for i in range(count):
		var foot := _patron_seat_position(i)
		var rect := Rect2(784.0, foot.y - 64.0, 96.0, 84.0)
		result.append({
			"index": i,
			"foot": _vector_to_dict(foot),
			"rect": _rect_to_dict(rect),
		})
	return result


func _draw_focused_patron_panel(surface, surface_state: Dictionary, patrons: Array, focused_index: int) -> void:
	if focused_index < 0 or focused_index >= patrons.size():
		return
	var patron: Dictionary = patrons[focused_index]
	var action := str(surface_state.get("patron_wager_action", ""))
	if action.is_empty():
		return
	var rect := Rect2(710, 18, 176, 58)
	var accent := C_PINK if bool(patron.get("watching_player", false)) else C_TEAL
	_draw_neon_panel(surface, rect, accent, 0.15)
	surface.surface_label(str(patron.get("name", "Patron")).to_upper().left(16), rect.position + Vector2(10, 14), 10, C_WHITE)
	surface.surface_label(str(patron.get("behavior", str(patron.get("mood", "watching")))).left(22), rect.position + Vector2(10, 29), 8, accent)
	_draw_table_button(surface, Rect2(rect.position.x + 84, rect.position.y + 10, 38, 20), "WITH", action, focused_index, C_TEAL, true)
	_draw_table_button(surface, Rect2(rect.position.x + 128, rect.position.y + 10, 38, 20), "FADE", action, focused_index + 100, C_PINK, true)
	var wager := _copy_dict(patron.get("visible_bet", {}))
	var wager_text := "$%d %s" % [int(wager.get("stake", 0)), str(wager.get("label", "bet"))]
	surface.surface_label(wager_text.left(22), rect.position + Vector2(84, 45), 8, C_YELLOW)


func _draw_small_color_chip(surface, center: Vector2, color: Color, value: int) -> void:
	surface.draw_circle(center, 8.0, Color(C_DARK.r, C_DARK.g, C_DARK.b, 0.92))
	surface.draw_circle(center, 6.4, color)
	surface.draw_circle(center, 2.6, Color("#f8f4dc"))
	surface.surface_label_centered_plain("%d" % value, Rect2(center + Vector2(-8, 7), Vector2(16, 8)), 6, color)


func _draw_croupier_station(surface, surface_state: Dictionary) -> void:
	TableVisualsScript.draw_dealer_station(surface, surface_state)


func _draw_recent_numbers(surface, surface_state: Dictionary) -> void:
	var recent := _dictionary_array(surface_state.get("recent_numbers", surface_state.get("roulette_recent_numbers", [])))
	var rect := Rect2(246, 84, 492, 28)
	_draw_neon_panel(surface, rect, C_CYAN, 0.08)
	surface.surface_label("RECENT", rect.position + Vector2(8, 18), 8, C_SOFT)
	if recent.is_empty():
		surface.surface_label_centered_plain("NO SPINS YET", Rect2(rect.position + Vector2(78, 8), Vector2(120, 12)), 8, C_SOFT)
		return
	var max_slots := mini(10, recent.size())
	for i in range(max_slots):
		var entry: Dictionary = recent[i]
		var number := str(entry.get("number", ""))
		var center := rect.position + Vector2(82 + float(i) * 38.0, 14)
		var accent := _pocket_color(number)
		var radius := 10.0 + minf(4.0, float(int(entry.get("celebration_score", 0))) / 20.0)
		surface.draw_circle(center, radius, Color(accent.r, accent.g, accent.b, 0.94))
		surface.draw_circle(center, radius + 1.5, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.22), false, 1)
		surface.surface_label_centered_plain(number.left(2), Rect2(center - Vector2(12, 5), Vector2(24, 10)), 7, _wheel_label_color(number))


func _draw_betting_layout(surface, surface_state: Dictionary) -> void:
	var red_numbers := _string_array(surface_state.get("red_numbers", RED_NUMBERS))
	surface.draw_rect(ZERO_RECT, Color("#0b7b4e"))
	surface.draw_rect(ZERO_RECT, C_YELLOW, false, 1)
	surface.surface_label_centered_plain("0", ZERO_RECT, 18, C_WHITE)
	if int(_copy_dict(surface_state.get("rules", {})).get("zero_count", 2)) == 2:
		surface.draw_rect(DOUBLE_ZERO_RECT, Color("#0b7b4e"))
		surface.draw_rect(DOUBLE_ZERO_RECT, C_YELLOW, false, 1)
		surface.surface_label_centered_plain("00", DOUBLE_ZERO_RECT, 16, C_WHITE)
	for n in range(1, 37):
		var rect := _number_cell(n)
		var number_text := str(n)
		var color := Color("#8e1026") if red_numbers.has(number_text) else Color("#111922")
		surface.draw_rect(rect, color)
		surface.draw_rect(rect, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.28), false, 1)
		surface.surface_label_centered_plain(number_text, rect, 12, C_WHITE)
	_draw_outside_labels(surface)
	var targets := _dictionary_array(surface_state.get("bet_targets", []))
	var hovered_index: int = surface.surface_hovered_index("roulette_bet") if surface.has_method("surface_hovered_index") else -1
	if hovered_index >= 0 and hovered_index < targets.size():
		var hovered_target: Dictionary = targets[hovered_index]
		var hovered_rect := _rect_from_dict(hovered_target.get("rect", {}))
		surface.draw_rect(hovered_rect.grow(2), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.22))
		surface.draw_rect(hovered_rect.grow(2), C_YELLOW, false, 1)
	if surface.has_method("surface_add_cached_exact_hits"):
		surface.surface_add_cached_exact_hits(_roulette_bet_hit_cache_key(surface_state, targets), targets, "roulette_bet")
	else:
		for i in range(targets.size()):
			var target: Dictionary = targets[i]
			surface.surface_add_exact_hit(_rect_from_dict(target.get("rect", {})), "roulette_bet", i)


func _roulette_bet_hit_cache_key(surface_state: Dictionary, targets: Array) -> String:
	var rules: Dictionary = surface_state.get("rules", {}) if typeof(surface_state.get("rules", {})) == TYPE_DICTIONARY else {}
	return "roulette_bets:%s:%d:%d" % [
		str(surface_state.get("variant", surface_state.get("table_layout", "roulette"))),
		int(rules.get("zero_count", 2)),
		targets.size(),
	]


func _draw_outside_labels(surface) -> void:
	for label_data in [
		{"label": "1ST 12", "rect": Rect2(332, OUTSIDE_Y, 120, 28)},
		{"label": "2ND 12", "rect": Rect2(452, OUTSIDE_Y, 120, 28)},
		{"label": "3RD 12", "rect": Rect2(572, OUTSIDE_Y, 120, 28)},
		{"label": "1-18", "rect": Rect2(332, OUTSIDE_Y + 32, 60, 28)},
		{"label": "EVEN", "rect": Rect2(392, OUTSIDE_Y + 32, 60, 28)},
		{"label": "RED", "rect": Rect2(452, OUTSIDE_Y + 32, 60, 28), "fill": Color("#8e1026")},
		{"label": "BLACK", "rect": Rect2(512, OUTSIDE_Y + 32, 60, 28), "fill": Color("#111922")},
		{"label": "ODD", "rect": Rect2(572, OUTSIDE_Y + 32, 60, 28)},
		{"label": "19-36", "rect": Rect2(632, OUTSIDE_Y + 32, 60, 28)},
		{"label": "2:1", "rect": Rect2(692, GRID_RECT.position.y, 46, CELL_H)},
		{"label": "2:1", "rect": Rect2(692, GRID_RECT.position.y + CELL_H, 46, CELL_H)},
		{"label": "2:1", "rect": Rect2(692, GRID_RECT.position.y + CELL_H * 2.0, 46, CELL_H)},
	]:
		var rect: Rect2 = label_data.get("rect", Rect2())
		surface.draw_rect(rect, label_data.get("fill", Color("#063f35")))
		surface.draw_rect(rect, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.26), false, 1)
		surface.surface_label_centered_plain(str(label_data.get("label", "")), rect, 10, C_WHITE)


func _draw_bet_chips(surface, surface_state: Dictionary) -> void:
	_draw_patron_roulette_chips(surface, surface_state)
	var bets := _bet_array(surface_state.get("roulette_bets", []))
	for bet_value in bets:
		var bet: Dictionary = bet_value
		var placement := _vector_from_dict(bet.get("placement", {}), Vector2(490, 190))
		_draw_casino_chip(surface, placement, int(bet.get("stake", 0)), 12, 1.0, false)
		surface.draw_rect(Rect2(placement - Vector2(16, 16), Vector2(32, 36)), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.72), false, 1)
		surface.surface_label_centered_plain("YOU", Rect2(placement + Vector2(-15, 13), Vector2(30, 9)), 6, C_CYAN)
	var last_result := _copy_dict(surface_state.get("last_result", {}))
	var spin_done: bool = not bool(surface.surface_animation_active(ROULETTE_SPIN_CHANNEL))
	if not last_result.is_empty() and spin_done:
		for result_value in _dictionary_array(last_result.get("bet_results", [])):
			var result: Dictionary = result_value
			if not bool(result.get("won", false)):
				continue
			var placement := _vector_from_dict(result.get("placement", {}), Vector2(490, 190))
			_draw_casino_chip(surface, placement + Vector2(6, -8), int(result.get("stake", 0)), 10, 0.92, true)


func _draw_patron_roulette_chips(surface, surface_state: Dictionary) -> void:
	var patrons := _dictionary_array(surface_state.get("patrons", []))
	var targets := _dictionary_array(surface_state.get("bet_targets", []))
	for i in range(patrons.size()):
		var patron: Dictionary = patrons[i]
		var wager := _copy_dict(patron.get("visible_bet", {}))
		var target := _roulette_surface_target_by_id(targets, str(wager.get("id", "")))
		if target.is_empty():
			continue
		var placement := _vector_from_dict(target.get("placement", {}), Vector2(490, 190))
		var offset := Vector2(-12 + float(i % 3) * 12.0, -16 - float(i / 3) * 8.0)
		var center := placement + offset
		var color := _chip_color_name(str(patron.get("chip_color", "cyan")))
		surface.draw_circle(center, 7.6, Color(C_DARK.r, C_DARK.g, C_DARK.b, 0.92))
		surface.draw_circle(center, 6.0, color)
		surface.draw_circle(center, 2.5, Color("#f8f4dc"))
		surface.surface_label_centered_plain("THEM", Rect2(center + Vector2(-15, 6), Vector2(30, 8)), 6, color)


func _roulette_surface_target_by_id(targets: Array, id: String) -> Dictionary:
	for target_value in targets:
		var target: Dictionary = target_value
		if str(target.get("id", "")) == id:
			return target
	return {}


func _draw_table_notice(surface, surface_state: Dictionary) -> void:
	var notice := str(surface_state.get("table_notice", ""))
	if notice.is_empty():
		return
	var rect := Rect2(244, 314, 420, 24)
	var accent := C_YELLOW if str(surface_state.get("phase", "")) == "spinning" else C_TEAL
	_draw_neon_panel(surface, rect, accent, 0.18)
	surface.surface_label_centered_plain(notice.left(72), rect.grow(-4), 10, accent)


func _draw_round_timer(surface, surface_state: Dictionary) -> void:
	TableVisualsScript.draw_round_timer_panel(surface, _copy_dict(surface_state.get("table_round_timer", {})), Rect2(666, 314, 112, 24), C_CYAN)


func _draw_chip_rack(surface, surface_state: Dictionary) -> void:
	var rack := Rect2(18, CONSOLE_Y + 8, 238, CONSOLE_H - 16)
	surface.draw_rect(rack, Color("#120b14"))
	surface.draw_rect(rack, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.28), false, 1)
	surface.surface_label("CHIP RAIL", rack.position + Vector2(10, 14), 10, C_SOFT)
	surface.surface_label("BET $%d" % int(surface_state.get("total_wager_cost", 0)), rack.position + Vector2(112, 14), 11, C_YELLOW)
	var chips := _array(surface_state.get("chip_denominations", []))
	for i in range(chips.size()):
		var center := Vector2(rack.position.x + 32 + float(i) * 40.0, rack.position.y + 44)
		_draw_chip_button(surface, center, int(chips[i]), "roulette_chip", i, int(surface_state.get("selected_chip", 1)) == int(chips[i]))
	_draw_chip_stack(surface, rack.position + Vector2(184, 48), surface_state.get("chip_stack", []), 0.44)


func _draw_table_actions(surface, surface_state: Dictionary) -> void:
	var panel := Rect2(274, CONSOLE_Y + 8, 352, CONSOLE_H - 16)
	_draw_neon_panel(surface, panel, C_CYAN, 0.10)
	surface.surface_label("WHEEL ACTIONS", panel.position + Vector2(10, 14), 10, C_SOFT)
	if bool(surface_state.get("table_barred", false)):
		surface.surface_label("TABLE CLOSED", panel.position + Vector2(14, 42), 15, C_PINK)
		return
	var selected_actions := _string_array(surface_state.get("native_selected_surface_actions", []))
	var phase := str(surface_state.get("phase", "betting"))
	if phase == "payout":
		var past_post_selected := selected_actions.has("roulette_past_post")
		var available := bool(surface_state.get("past_post_available", false))
		_draw_table_button(surface, Rect2(panel.position.x + 12, panel.position.y + 25, 102, 30), "SLIDE CHIP" if past_post_selected else "LATE CHIP", "roulette_past_post", 0, C_PINK, available, past_post_selected)
		var window := _copy_dict(surface_state.get("past_post_window", {}))
		var detail := "%d ms" % int(window.get("remaining_msec", 0)) if available else "LOCKED"
		surface.surface_label("Payout window %s" % detail, panel.position + Vector2(126, 45), 10, C_SOFT)
		return
	if phase == "spinning":
		surface.surface_label("NO MORE BETS", panel.position + Vector2(14, 46), 14, C_YELLOW)
		return
	var spin_selected := selected_actions.has("roulette_spin")
	var spin_label := "CONFIRM" if spin_selected else "SIT OUT" if int(surface_state.get("total_wager_cost", 0)) <= 0 else "SPIN"
	_draw_table_button(surface, Rect2(panel.position.x + 12, panel.position.y + 24, 86, 30), spin_label, "roulette_spin", 0, C_YELLOW, bool(surface_state.get("can_spin", false)), spin_selected)
	_draw_table_button(surface, Rect2(panel.position.x + 106, panel.position.y + 24, 54, 30), "UNDO", "roulette_undo", 0, C_SOFT, bool(surface_state.get("can_undo", false)))
	_draw_table_button(surface, Rect2(panel.position.x + 168, panel.position.y + 24, 58, 30), "CLEAR", "roulette_clear", 0, C_ORANGE, bool(surface_state.get("can_clear", false)))
	_draw_table_button(surface, Rect2(panel.position.x + 234, panel.position.y + 24, 54, 30), "REBET", "roulette_rebet", 0, C_TEAL, bool(surface_state.get("can_rebet", false)))
	_draw_table_button(surface, Rect2(panel.position.x + 296, panel.position.y + 24, 44, 30), "2X", "roulette_double", 0, C_AMBER, bool(surface_state.get("can_clear", false)))
	_draw_table_button(surface, Rect2(panel.position.x + 12, panel.position.y + 56, 70, 18), "NUDGE", "roulette_nudge", 0, C_PINK, true, selected_actions.has("roulette_nudge"))
	_draw_table_button(surface, Rect2(panel.position.x + 90, panel.position.y + 56, 88, 18), "READ WHEEL", "roulette_read_wheel", 0, C_PINK_2, true)
	surface.surface_label("Inside $%d  Outside $%d" % [int(surface_state.get("inside_wager_total", 0)), int(surface_state.get("outside_wager_total", 0))], panel.position + Vector2(188, 69), 8, C_SOFT)


func _draw_spin_result(surface, surface_state: Dictionary) -> void:
	var result := _copy_dict(surface_state.get("last_result", {}))
	if result.is_empty():
		return
	if surface.surface_animation_active(ROULETTE_SPIN_CHANNEL):
		return
	var number := str(result.get("winning_number", ""))
	var color := _pocket_color(number)
	var target_rect := _layout_rect_for_number(number)
	if target_rect.size.x > 0:
		surface.draw_rect(target_rect.grow(4), Color(color.r, color.g, color.b, 0.34))
		surface.draw_rect(target_rect.grow(4), C_YELLOW, false, 2)
	var board := Rect2(26, 286, 206, 42)
	_draw_neon_panel(surface, board, C_YELLOW, 0.18)
	surface.surface_label("WINNING NUMBER", board.position + Vector2(10, 14), 8, C_SOFT)
	surface.surface_label(number, board.position + Vector2(118, 30), 26, C_YELLOW)
	surface.surface_label(str(result.get("winning_color", "")).to_upper(), board.position + Vector2(10, 31), 10, color)


func _draw_rule_hover_overlay(surface, surface_state: Dictionary) -> void:
	var targets := _dictionary_array(surface_state.get("bet_targets", []))
	var target_index := -1
	for i in range(targets.size()):
		if surface.surface_region_hovered("roulette_bet", i):
			target_index = i
			break
	if target_index < 0:
		return
	var target: Dictionary = targets[target_index]
	var rect := Rect2(724, 84, 150, 92)
	_draw_neon_panel(surface, rect, C_YELLOW, 0.20)
	surface.surface_label(str(target.get("type", "bet")).replace("_", " ").to_upper().left(18), rect.position + Vector2(10, 15), 9, C_SOFT)
	surface.surface_label(str(target.get("label", "")).left(18), rect.position + Vector2(10, 35), 15, C_YELLOW)
	surface.surface_label("pays %d:1" % int(target.get("payout", 0)), rect.position + Vector2(10, 52), 10, C_TEAL)
	surface.surface_label(",".join(_string_array(target.get("numbers", []))).left(24), rect.position + Vector2(10, 69), 8, C_SOFT)


func _draw_payout_animation(surface, surface_state: Dictionary) -> void:
	if not surface.surface_animation_active(ROULETTE_PAYOUT_CHANNEL):
		return
	var progress: float = surface.surface_animation_progress(ROULETTE_PAYOUT_CHANNEL)
	var result := _copy_dict(surface_state.get("last_result", {}))
	var wins := _dictionary_array(result.get("bet_results", []))
	var start := Vector2(468, 114)
	var index := 0
	for win_value in wins:
		var win: Dictionary = win_value
		if not bool(win.get("won", false)):
			continue
		var target := _vector_from_dict(win.get("placement", {}), Vector2(490, 190)) + Vector2(18, -16 - index * 3)
		var pos := start.lerp(target, clampf(progress * 1.25 - float(index) * 0.08, 0.0, 1.0))
		var score := clampi(int(win.get("celebration_score", 0)), 1, 100)
		var radius := 8.0 + minf(8.0, float(score) / 12.0)
		surface.draw_circle(pos, radius + 6.0, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, clampf(float(score) / 140.0, 0.18, 0.72)), false, 2)
		_draw_casino_chip(surface, pos, int(win.get("bankroll_delta", 0)), radius, 0.92, true)
		index += 1


func _number_cell(number: int) -> Rect2:
	var row := int((number - 1) / 3)
	var col := int((number - 1) % 3)
	return Rect2(GRID_RECT.position.x + float(row) * CELL_W, GRID_RECT.position.y + float(2 - col) * CELL_H, CELL_W, CELL_H)


func _split_rect(a: int, b: int) -> Rect2:
	var ra := _number_cell(a)
	var rb := _number_cell(b)
	var min_x := minf(ra.position.x, rb.position.x)
	var min_y := minf(ra.position.y, rb.position.y)
	var max_x := maxf(ra.position.x + ra.size.x, rb.position.x + rb.size.x)
	var max_y := maxf(ra.position.y + ra.size.y, rb.position.y + rb.size.y)
	if abs(a - b) == 1:
		return Rect2(min_x + 3, (ra.get_center().y + rb.get_center().y) * 0.5 - 5, ra.size.x - 6, 10)
	return Rect2((ra.get_center().x + rb.get_center().x) * 0.5 - 5, min_y + 3, 10, max_y - min_y - 6)


func _corner_rect(number: int) -> Rect2:
	var r := _number_cell(number)
	return Rect2(r.position.x + r.size.x - 6, r.position.y - 6, 12, 12)


func _layout_rect_for_number(number: String) -> Rect2:
	if number == "0":
		return ZERO_RECT
	if number == "00":
		return DOUBLE_ZERO_RECT
	var n := int(number)
	if n >= 1 and n <= 36:
		return _number_cell(n)
	return Rect2()


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


func _normalize_table_state(table: Dictionary) -> Dictionary:
	var normalized := table.duplicate(true)
	normalized["schema"] = str(normalized.get("schema", "roulette_table_state"))
	normalized["version"] = maxi(1, int(normalized.get("version", 1)))
	var variant := str(normalized.get("variant", "american_double_zero"))
	if not ["american_double_zero", "european_single_zero"].has(variant):
		variant = "american_double_zero"
	normalized["variant"] = variant
	if _string_array(normalized.get("wheel_sequence", [])).is_empty():
		normalized["wheel_sequence"] = EUROPEAN_SEQUENCE.duplicate(true) if variant == "european_single_zero" else AMERICAN_SEQUENCE.duplicate(true)
	normalized["red_numbers"] = RED_NUMBERS.duplicate(true)
	normalized["black_numbers"] = BLACK_NUMBERS.duplicate(true)
	if typeof(normalized.get("rules", {})) != TYPE_DICTIONARY:
		normalized["rules"] = {}
	var rules: Dictionary = normalized.get("rules", {})
	rules["zero_count"] = 1 if variant == "european_single_zero" else int(rules.get("zero_count", 2))
	if variant == "american_double_zero":
		rules["zero_count"] = 2
	rules["la_partage"] = bool(rules.get("la_partage", false))
	rules["en_prison"] = bool(rules.get("en_prison", false))
	rules["call_bets_enabled"] = bool(rules.get("call_bets_enabled", false))
	rules["late_bets_allowed"] = bool(rules.get("late_bets_allowed", false))
	rules["inside_min_total"] = maxi(1, int(rules.get("inside_min_total", 1)))
	rules["outside_min_each"] = maxi(1, int(rules.get("outside_min_each", 1)))
	rules["table_max"] = maxi(rules["outside_min_each"], int(rules.get("table_max", 100)))
	normalized["rules"] = rules
	normalized["physics_profile"] = _normalize_physics_profile(normalized.get("physics_profile", {}))
	normalized["dealer_profile"] = _normalize_dealer_profile(normalized.get("dealer_profile", {}), normalized)
	normalized["patrons"] = _normalize_patrons(normalized.get("patrons", []), normalized)
	normalized["chip_denominations"] = _chip_denominations(normalized)
	normalized["spin_count"] = maxi(0, int(normalized.get("spin_count", 0)))
	normalized["last_results"] = _dictionary_array(normalized.get("last_results", []))
	normalized["last_result"] = _copy_dict(normalized.get("last_result", {}))
	normalized["last_bets"] = _bet_array(normalized.get("last_bets", []))
	normalized["bias_read"] = _copy_dict(normalized.get("bias_read", {}))
	normalized["table_barred"] = bool(normalized.get("table_barred", false))
	normalized["barred_reason"] = str(normalized.get("barred_reason", ""))
	normalized["table_round_timer_started_msec"] = int(normalized.get("table_round_timer_started_msec", 0))
	return normalized


func _normalize_physics_profile(value: Variant) -> Dictionary:
	var profile: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var result := {
		"preset": str(profile.get("preset", "standard_casino_wheel")),
		"wheel_radius_m": clampf(float(profile.get("wheel_radius_m", 0.36)), 0.2, 0.6),
		"rim_radius_m": clampf(float(profile.get("rim_radius_m", 0.42)), 0.2, 0.7),
		"ball_radius_m": clampf(float(profile.get("ball_radius_m", 0.0095)), 0.004, 0.03),
		"ball_mass_kg": clampf(float(profile.get("ball_mass_kg", 0.006)), 0.001, 0.03),
		"rotor_initial_omega_min": float(profile.get("rotor_initial_omega_min", -3.2)),
		"rotor_initial_omega_max": float(profile.get("rotor_initial_omega_max", -2.2)),
		"rotor_angular_decel": clampf(float(profile.get("rotor_angular_decel", 0.018)), 0.0, 0.2),
		"ball_initial_omega_min": clampf(float(profile.get("ball_initial_omega_min", 18.0)), 5.0, 40.0),
		"ball_initial_omega_max": clampf(float(profile.get("ball_initial_omega_max", 22.0)), 5.0, 45.0),
		"ball_angular_decel_min": clampf(float(profile.get("ball_angular_decel_min", 0.86)), 0.1, 4.0),
		"ball_angular_decel_max": clampf(float(profile.get("ball_angular_decel_max", 1.16)), 0.1, 4.0),
		"drop_omega_threshold": clampf(float(profile.get("drop_omega_threshold", 6.8)), 1.0, 16.0),
		"diamond_count": clampi(int(profile.get("diamond_count", 8)), 4, 16),
		"diamond_phase": fposmod(float(profile.get("diamond_phase", 0.0)), TAU),
		"diamond_restitution": clampf(float(profile.get("diamond_restitution", 0.42)), 0.05, 0.95),
		"diamond_scatter_degrees": clampf(float(profile.get("diamond_scatter_degrees", 24.0)), 0.0, 80.0),
		"pocket_depth": clampf(float(profile.get("pocket_depth", 0.62)), 0.1, 2.0),
		"pocket_rebound": clampf(float(profile.get("pocket_rebound", 0.18)), 0.0, 1.0),
		"tilt_degrees": clampf(float(profile.get("tilt_degrees", 0.0)), -4.0, 4.0),
		"tilt_angle": fposmod(float(profile.get("tilt_angle", 0.0)), TAU),
		"level_bias_strength": clampf(float(profile.get("level_bias_strength", 0.0)), -0.4, 0.4),
		"micro_scatter": clampf(float(profile.get("micro_scatter", 0.035)), 0.0, 0.4),
	}
	if float(result["rotor_initial_omega_min"]) > float(result["rotor_initial_omega_max"]):
		var rotor_min := float(result["rotor_initial_omega_min"])
		result["rotor_initial_omega_min"] = result["rotor_initial_omega_max"]
		result["rotor_initial_omega_max"] = rotor_min
	if float(result["ball_initial_omega_min"]) > float(result["ball_initial_omega_max"]):
		var ball_min := float(result["ball_initial_omega_min"])
		result["ball_initial_omega_min"] = result["ball_initial_omega_max"]
		result["ball_initial_omega_max"] = ball_min
	if float(result["ball_angular_decel_min"]) > float(result["ball_angular_decel_max"]):
		var decel_min := float(result["ball_angular_decel_min"])
		result["ball_angular_decel_min"] = result["ball_angular_decel_max"]
		result["ball_angular_decel_max"] = decel_min
	return result


func _normalized_session(_run_state: RunState, _environment: Dictionary, ui_state: Dictionary, table: Dictionary) -> Dictionary:
	var session := ui_state.duplicate(true)
	var denoms := _chip_denominations(table)
	var selected_chip := int(session.get("selected_chip", session.get("selected_stake", denoms[0])))
	if not denoms.has(selected_chip):
		selected_chip = _closest_chip(selected_chip, denoms)
	session["selected_chip"] = selected_chip
	session["selected_stake"] = selected_chip
	session["roulette_bets"] = _bet_array(session.get("roulette_bets", []))
	session["roulette_rebet"] = _bet_array(session.get("roulette_rebet", table.get("last_bets", [])))
	session["locked_bets"] = _bet_array(session.get("locked_bets", []))
	if typeof(session.get("roulette_undo_stack", [])) != TYPE_ARRAY:
		session["roulette_undo_stack"] = []
	if typeof(session.get("cheats_used", {})) != TYPE_DICTIONARY:
		session["cheats_used"] = {}
	var past_post_challenge := _normalized_past_post_challenge(session.get("past_post_challenge", {}))
	if past_post_challenge.is_empty():
		session.erase("past_post_challenge")
	else:
		session["past_post_challenge"] = past_post_challenge
	return session


func _update_table_after_spin(table: Dictionary, bets: Array, bet_results: Array, spin: Dictionary, bankroll_delta: int, suspicion_delta: int, rng: RngStream) -> void:
	table["spin_count"] = int(table.get("spin_count", 0)) + 1
	GameModule.reset_table_round_timer(table)
	var summary := _roulette_result_message(str(spin.get("winning_number", "0")), spin, bet_results, bankroll_delta, "")
	var result_bets: Array = []
	var celebration_score := 0
	for result_value in bet_results:
		if typeof(result_value) != TYPE_DICTIONARY:
			continue
		var result: Dictionary = (result_value as Dictionary).duplicate(true)
		var matching := _bet_for_result_id(bets, str(result.get("id", "")))
		if not matching.is_empty():
			result["placement"] = _copy_dict(matching.get("placement", {}))
		celebration_score = maxi(celebration_score, int(result.get("celebration_score", 0)))
		result_bets.append(result)
	var last_result := {
		"spin_id": str(spin.get("spin_id", "")),
		"payout_animation_id": "roulette_payout_%s" % str(spin.get("spin_id", "")),
		"winning_number": str(spin.get("winning_number", "0")),
		"winning_color": str(spin.get("winning_color", "")),
		"winning_index": int(spin.get("winning_index", 0)),
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"celebration_score": celebration_score,
		"summary": summary,
		"bets": bets.duplicate(true),
		"bet_results": result_bets,
		"physics": _copy_dict(spin.get("physics", {})),
		"trajectory": _dictionary_array(spin.get("trajectory", [])),
		"resolved_at_msec": Time.get_ticks_msec(),
		"rng_state": rng.snapshot() if rng != null else {},
	}
	table["last_result"] = last_result
	table["last_bets"] = bets.duplicate(true)
	var history := _dictionary_array(table.get("last_results", []))
	history.push_front({
		"winning_number": str(spin.get("winning_number", "0")),
		"winning_color": str(spin.get("winning_color", "")),
		"bankroll_delta": bankroll_delta,
		"celebration_score": celebration_score,
		"spin_id": str(spin.get("spin_id", "")),
	})
	while history.size() > HISTORY_LIMIT:
		history.pop_back()
	table["last_results"] = history
	_drift_physics_profile(table)


func _update_environment_table(environment: Dictionary, table: Dictionary) -> void:
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	game_states[get_id()] = table.duplicate(true)
	environment["game_states"] = game_states


func _drift_physics_profile(table: Dictionary) -> void:
	var profile := _normalize_physics_profile(table.get("physics_profile", {}))
	var spin_count := int(table.get("spin_count", 0))
	if spin_count % 17 == 0:
		profile["diamond_phase"] = fposmod(float(profile.get("diamond_phase", 0.0)) + 0.012, TAU)
	table["physics_profile"] = profile


func _roulette_result_message(winning_number: String, spin: Dictionary, bet_results: Array, bankroll_delta: int, security_message: String) -> String:
	var wins := 0
	for result_value in bet_results:
		if typeof(result_value) == TYPE_DICTIONARY and bool((result_value as Dictionary).get("won", false)):
			wins += 1
	var base := "Roulette lands %s %s. %d winning bet%s. Bankroll %+d." % [
		winning_number,
		str(spin.get("winning_color", _roulette_color(winning_number))),
		wins,
		"" if wins == 1 else "s",
		bankroll_delta,
	]
	if not security_message.is_empty():
		base = "%s %s" % [base, security_message]
	return base


func _roulette_recent_numbers(table: Dictionary) -> Array:
	var result: Array = []
	for history_value in _dictionary_array(table.get("last_results", [])):
		var history: Dictionary = history_value
		var number := str(history.get("winning_number", ""))
		if number.is_empty():
			continue
		result.append({
			"number": number,
			"color": str(history.get("winning_color", _roulette_color(number))),
			"bankroll_delta": int(history.get("bankroll_delta", 0)),
			"celebration_score": clampi(int(history.get("celebration_score", 0)), 0, 100),
			"spin_id": str(history.get("spin_id", "")),
		})
		if result.size() >= HISTORY_LIMIT:
			break
	return result


func _roulette_pressure_message(table: Dictionary, pit_boss_status: Dictionary) -> String:
	if bool(pit_boss_status.get("watched", false)):
		return "A patron at the rail turns as staff clock the wheel read."
	for patron_value in _dictionary_array(table.get("patrons", [])):
		var patron: Dictionary = patron_value
		if bool(patron.get("watching", false)):
			return "A patron follows the stare and looks toward staff."
	return ""


func _empty_roulette_result(action_id: String, stake: int, environment: Dictionary, text: String) -> Dictionary:
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


func _message_command(ui_state: Dictionary, message: String) -> Dictionary:
	return GameModule.surface_command({"handled": true, "ui_state": ui_state, "message": message})


func _surface_action_blocks(blocked: bool) -> Array:
	if not blocked:
		return []
	var actions := ["roulette_bet", "roulette_patron_focus", "roulette_patron_bet", "roulette_chip", "roulette_clear", "roulette_undo", "roulette_rebet", "roulette_double", "roulette_spin", "roulette_read_wheel", "roulette_nudge", "roulette_max_bet"]
	var result: Array = []
	for action in actions:
		result.append({"action": action, "reason": "No more bets."})
	return result


func _surface_locked(_state: Dictionary) -> bool:
	return false


func _selected_surface_actions(session: Dictionary) -> Array:
	var result: Array = []
	if bool(session.get("roulette_spin_armed", false)) or (str(session.get("selected_action_id", "")) == "spin_roulette" and str(session.get("selected_action_kind", "")) == "legal"):
		result.append("roulette_spin")
	if bool(session.get("roulette_nudge_ready", false)) or bool(_copy_dict(session.get("cheats_used", {})).get("wheel_nudge", false)):
		result.append("roulette_nudge")
	if bool(session.get("past_post_armed", false)) or (str(session.get("selected_action_id", "")) == PAST_POST_ACTION_ID and str(session.get("selected_action_kind", "")) == "cheat"):
		result.append("roulette_past_post")
	if int(session.get("focused_patron_index", -1)) >= 0:
		result.append("roulette_patron_focus")
	return result


func _focused_patron_index(state: Dictionary, patrons: Array) -> int:
	var focused_index := int(state.get("focused_patron_index", -1))
	if focused_index < 0 or focused_index >= mini(patrons.size(), MAX_VISIBLE_PATRONS):
		return -1
	return focused_index


func _table_notice(table: Dictionary, session: Dictionary, last_result: Dictionary, spin_active: bool, payout_active: bool, round_timer: Dictionary = {}) -> String:
	if spin_active:
		return "No more bets. The ball is circling the rim."
	if payout_active:
		return "The croupier marks the number and pays the layout."
	if bool(session.get("roulette_nudge_ready", false)):
		return "Nudge ready. Confirm the spin before the croupier's eyes return."
	if not _copy_dict(session.get("bias_read", {})).is_empty():
		return str(_copy_dict(session.get("bias_read", {})).get("message", "You have a read on the wheel."))
	if not last_result.is_empty():
		return str(last_result.get("summary", "The wheel is ready for the next spin."))
	var focused_index := _focused_patron_index(session, _dictionary_array(table.get("patrons", [])))
	if focused_index >= 0:
		var patrons := _dictionary_array(table.get("patrons", []))
		var patron: Dictionary = patrons[focused_index]
		return "%s is selected. Follow their wager or fade it." % str(patron.get("name", "That player"))
	var bets := _bet_array(session.get("roulette_bets", []))
	if bets.is_empty():
		var seconds := int(round_timer.get("remaining_seconds", 0))
		if seconds > 0:
			return "Place chips or sit out; next spin in %ds." % seconds
		return "Place chips or sit out the next spin."
	return "$%d on %d roulette space%s." % [_total_wager(bets), bets.size(), "" if bets.size() == 1 else "s"]


func _table_rules(table: Dictionary) -> Dictionary:
	return _copy_dict(table.get("rules", {}))


func _wheel_sequence(table: Dictionary) -> Array:
	var sequence := _string_array(table.get("wheel_sequence", []))
	if sequence.is_empty():
		sequence = AMERICAN_SEQUENCE.duplicate(true)
	return sequence


func _roulette_color(number: String) -> String:
	if number == "0" or number == "00":
		return "green"
	if RED_NUMBERS.has(number):
		return "red"
	if BLACK_NUMBERS.has(number):
		return "black"
	return "green"


func _pocket_color(number: String) -> Color:
	match _roulette_color(number):
		"red":
			return Color("#8e1026")
		"black":
			return Color("#111922")
		_:
			return Color("#0b7b4e")


func _wheel_label_color(number: String) -> Color:
	match _roulette_color(number):
		"green":
			return C_TEAL
		"red":
			return Color("#ffd7de")
		_:
			return Color("#dcecff")


func _is_zero(number: String) -> bool:
	return number == "0" or number == "00"


func _canonical_bet_id(type: String, numbers: Array) -> String:
	return "%s:%s" % [type, "-".join(_string_array(numbers))]


func _default_smoke_bet(stake: int) -> Dictionary:
	return {
		"id": "straight:17",
		"type": "straight",
		"numbers": ["17"],
		"stake": maxi(1, stake),
		"payout": 35,
		"label": "17",
		"family": "inside",
		"origin": "smoke_default",
		"placement": _vector_to_dict(_number_cell(17).get_center()),
	}


func _total_wager(bets: Array) -> int:
	var total := 0
	for bet_value in bets:
		if typeof(bet_value) == TYPE_DICTIONARY:
			total += maxi(0, int((bet_value as Dictionary).get("stake", 0)))
	return total


func _wager_total_for_family(bets: Array, family: String) -> int:
	var total := 0
	for bet_value in bets:
		if typeof(bet_value) == TYPE_DICTIONARY and str((bet_value as Dictionary).get("family", "")) == family:
			total += maxi(0, int((bet_value as Dictionary).get("stake", 0)))
	return total


func _range_strings(first: int, last: int) -> Array:
	var result: Array = []
	for n in range(first, last + 1):
		result.append(str(n))
	return result


func _even_numbers() -> Array:
	var result: Array = []
	for n in range(2, 37, 2):
		result.append(str(n))
	return result


func _odd_numbers() -> Array:
	var result: Array = []
	for n in range(1, 36, 2):
		result.append(str(n))
	return result


func _column_numbers(col: int) -> Array:
	var result: Array = []
	for row in range(12):
		result.append(str(row * 3 + col + 1))
	return result


func _bet_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for bet_value in value:
		if typeof(bet_value) != TYPE_DICTIONARY:
			continue
		var bet: Dictionary = (bet_value as Dictionary).duplicate(true)
		bet["type"] = str(bet.get("type", "straight"))
		bet["numbers"] = _string_array(bet.get("numbers", []))
		bet["stake"] = maxi(0, int(bet.get("stake", 0)))
		bet["payout"] = maxi(0, int(bet.get("payout", 0)))
		bet["label"] = str(bet.get("label", ",".join(_string_array(bet.get("numbers", [])))))
		bet["family"] = str(bet.get("family", "inside"))
		if not bet.has("id"):
			bet["id"] = _canonical_bet_id(str(bet.get("type", "straight")), _string_array(bet.get("numbers", [])))
		if not bet.has("placement"):
			bet["placement"] = _vector_to_dict(Vector2(480, 190))
		result.append(bet)
	return result


func _push_undo_state(state: Dictionary) -> void:
	var stack := _array(state.get("roulette_undo_stack", []))
	stack.append(_bet_array(state.get("roulette_bets", [])))
	while stack.size() > 8:
		stack.pop_front()
	state["roulette_undo_stack"] = stack


func _pop_undo_state(state: Dictionary) -> Array:
	var stack := _array(state.get("roulette_undo_stack", []))
	if stack.is_empty():
		return _bet_array(state.get("roulette_bets", []))
	var previous := _bet_array(stack.pop_back())
	state["roulette_undo_stack"] = stack
	return previous


func _bet_for_result_id(bets: Array, id: String) -> Dictionary:
	for bet_value in bets:
		if typeof(bet_value) == TYPE_DICTIONARY and str((bet_value as Dictionary).get("id", "")) == id:
			return (bet_value as Dictionary).duplicate(true)
	return {}


func _generate_dealer_profile(rng: RngStream, catch_base: int) -> Dictionary:
	return {
		"posture": str(rng.pick(["upright", "relaxed", "formal", "sharp"], "formal")),
		"tell": str(rng.pick(["waits before no more bets", "fingers the dolly", "checks late hands", "watches the rotor"], "watches the rotor")),
		"attention_base": clampi(catch_base + rng.randi_range(4, 18), 8, 70),
		"spin_style": str(rng.pick(["clean snap", "slow rotor", "fast ball", "quiet launch"], "clean snap")),
		"call_style": str(rng.pick(["formal", "dry", "warm", "clipped"], "formal")),
		"uniform_accent": str(rng.pick(["gold pin", "cyan tie", "pink cuffs", "black vest"], "gold pin")),
		"blink_offset": rng.randi_range(0, 2600),
		"late_bet_scrutiny": rng.randi_range(8, 18),
	}


func _generate_table_patrons(rng: RngStream, _depth: int) -> Array:
	var names := ["Nix", "Sal", "Dove", "Milo", "Anika", "Trent", "June", "Vale"]
	var styles := ["outside_red", "columns", "favorite_17", "dozens", "chaotic_spread"]
	var colors := ["blue", "pink", "yellow", "teal"]
	var tells := ["tracks chips", "leans in", "side eye", "wheel stare", "soft nod"]
	var count := rng.randi_range(2, MAX_VISIBLE_PATRONS)
	var picked_names := rng.pick_many(names, count)
	var patrons: Array = []
	for i in range(count):
		var mood := str(rng.pick(["chatty", "quiet", "tilted", "hopeful"], "quiet"))
		var snitch_risk := rng.randi_range(6, 32)
		if mood == "tilted":
			snitch_risk += 8
		elif mood == "chatty":
			snitch_risk -= 4
		patrons.append({
			"id": "patron_%d" % i,
			"name": str(picked_names[i] if i < picked_names.size() else "Patron"),
			"seat": i,
			"mood": mood,
			"bet_style": str(rng.pick(styles, styles[0])),
			"cosmetic_bet": int(rng.pick([5, 10, 15, 20, 25], 10)),
			"rapport": rng.randi_range(42, 62),
			"chip_color": str(colors[i % colors.size()]),
			"snitch_risk": clampi(snitch_risk, 4, 50),
			"chip_stack": rng.randi_range(20, 120),
			"watching": rng.randi_range(0, 100) >= 45,
			"silhouette": str(rng.pick(["cap", "glasses", "coat", "rings"], "coat")),
			"tell": str(rng.pick(tells, tells[0])),
			"temper": str(rng.pick(["nosy", "careless", "loyal", "sharp"], "careless")),
			"seat_style": str(rng.pick(["vest", "jacket", "open"], "open")),
			"animation_offset": rng.randi_range(0, 3600),
			"snitch_threshold": rng.randi_range(18, 52),
		})
	return patrons


func _normalize_dealer_profile(value: Variant, table: Dictionary) -> Dictionary:
	var profile: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	if profile.is_empty():
		profile = _generate_dealer_profile(_default_table_rng(table, "dealer"), int(table.get("dealer_catch_base", 12)))
	profile["posture"] = str(profile.get("posture", "formal"))
	profile["tell"] = str(profile.get("tell", "watches the rotor"))
	profile["attention_base"] = clampi(int(profile.get("attention_base", 18)), 5, 80)
	profile["spin_style"] = str(profile.get("spin_style", "clean snap"))
	profile["call_style"] = str(profile.get("call_style", "formal"))
	profile["uniform_accent"] = str(profile.get("uniform_accent", "gold pin"))
	profile["blink_offset"] = maxi(0, int(profile.get("blink_offset", 0)))
	profile["late_bet_scrutiny"] = clampi(int(profile.get("late_bet_scrutiny", 10)), 0, 40)
	profile["read_style"] = str(profile.get("read_style", "slow sweep"))
	profile["gaze_speed"] = clampi(int(profile.get("gaze_speed", 95)), 45, 180)
	return profile


func _normalize_patrons(value: Variant, table: Dictionary) -> Array:
	var patrons := _dictionary_array(value)
	if patrons.is_empty() and not table.has("patrons"):
		patrons = _generate_table_patrons(_default_table_rng(table, "patrons"), 0)
	var result: Array = []
	for i in range(mini(patrons.size(), MAX_VISIBLE_PATRONS)):
		var patron: Dictionary = patrons[i]
		result.append({
			"id": str(patron.get("id", "patron_%d" % i)),
			"name": str(patron.get("name", "Patron")),
			"seat": int(patron.get("seat", i)),
			"mood": str(patron.get("mood", "quiet")),
			"bet_style": str(patron.get("bet_style", "outside_red")),
			"cosmetic_bet": maxi(1, int(patron.get("cosmetic_bet", maxi(1, int(patron.get("chip_stack", 40)) / 4)))),
			"rapport": clampi(int(patron.get("rapport", 50)), 0, 100),
			"chip_color": str(patron.get("chip_color", "blue")),
			"snitch_risk": clampi(int(patron.get("snitch_risk", 14)), 0, 60),
			"chip_stack": maxi(0, int(patron.get("chip_stack", 40))),
			"watching": bool(patron.get("watching", true)),
			"silhouette": str(patron.get("silhouette", "coat")),
			"tell": str(patron.get("tell", "leans in")),
			"temper": str(patron.get("temper", "careless")),
			"seat_style": str(patron.get("seat_style", "open")),
			"animation_offset": maxi(0, int(patron.get("animation_offset", i * 640))),
			"snitch_threshold": clampi(int(patron.get("snitch_threshold", 30)), 4, 70),
		})
	return result


func _patrons_for_surface(table: Dictionary, last_result: Dictionary) -> Array:
	var patrons := _dictionary_array(table.get("patrons", []))
	var now := Time.get_ticks_msec()
	var visible_count := mini(patrons.size(), MAX_VISIBLE_PATRONS)
	var visible_patrons: Array = []
	for i in range(visible_count):
		var patron: Dictionary = patrons[i]
		var result_bonus := 0
		if not last_result.is_empty():
			var number := str(last_result.get("winning_number", ""))
			result_bonus = -4 if str(patron.get("bet_style", "")).find(number) >= 0 else 6
		var rapport_adjust := int((50 - clampi(int(patron.get("rapport", 50)), 0, 100)) / 5)
		var risk := clampi(int(patron.get("snitch_risk", 0)) + result_bonus + rapport_adjust, 0, 60)
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
		patron["behavior"] = "snitch tell" if tell_active else _patron_behavior_label(patron, last_result)
		var wager := _patron_roulette_wager(patron, table, i)
		if not wager.is_empty():
			patron["visible_bet"] = {
				"id": str(wager.get("id", "")),
				"label": str(wager.get("label", "roulette")),
				"stake": int(wager.get("patron_stake", wager.get("stake", 1))),
			}
		visible_patrons.append(patron)
	return visible_patrons


func _patron_behavior_label(patron: Dictionary, last_result: Dictionary) -> String:
	if last_result.is_empty():
		return str(patron.get("bet_style", "watching")).replace("_", " ")
	var number := str(last_result.get("winning_number", ""))
	if str(patron.get("bet_style", "")).find(number) >= 0:
		return "grinning"
	return str(patron.get("mood", "watching"))


func _patron_snitch_pressure(patrons: Array) -> int:
	var total := 0
	for patron_value in patrons:
		if typeof(patron_value) != TYPE_DICTIONARY:
			continue
		var patron: Dictionary = patron_value
		if bool(patron.get("watching_player", false)):
			total += int(patron.get("active_snitch_risk", 0))
	return total


func _roulette_motion_active(table: Dictionary, now_msec: int) -> bool:
	var last_result := _copy_dict(table.get("last_result", {}))
	if last_result.is_empty():
		return false
	var elapsed := now_msec - int(last_result.get("resolved_at_msec", 0))
	return elapsed >= 0 and elapsed < SPIN_ANIMATION_DURATION_MSEC + PAYOUT_ANIMATION_DURATION_MSEC + ROULETTE_RESULT_REVEAL_MSEC


func _roulette_result_reveal_active(last_result: Dictionary, elapsed_msec: int) -> bool:
	if last_result.is_empty():
		return false
	var reveal_start := SPIN_ANIMATION_DURATION_MSEC + PAYOUT_ANIMATION_DURATION_MSEC
	return elapsed_msec >= reveal_start and elapsed_msec < reveal_start + ROULETTE_RESULT_REVEAL_MSEC


func _apply_nudged_spin(spin: Dictionary, table: Dictionary, bets: Array) -> Dictionary:
	var result := spin.duplicate(true)
	var fallback_number := str(result.get("winning_number", "0"))
	var target_number := _nudge_target_number(table, bets, fallback_number)
	var sequence := _wheel_sequence(table)
	var target_index := sequence.find(target_number)
	if target_index < 0:
		return result
	result["spin_id"] = "%s_nudge_%s" % [str(result.get("spin_id", "roulette")), target_number]
	result["winning_number"] = target_number
	result["winning_index"] = target_index
	result["winning_color"] = _roulette_color(target_number)
	var physics := _copy_dict(result.get("physics", {}))
	var capture := _copy_dict(physics.get("capture", {}))
	var pocket_width := TAU / float(maxi(1, sequence.size()))
	var rotor_angle := float(capture.get("final_rotor_angle", capture.get("rotor_angle", 0.0)))
	var final_angle := fposmod(rotor_angle + (float(target_index) + 0.5) * pocket_width, TAU)
	capture["index"] = target_index
	capture["number"] = target_number
	capture["final_ball_angle"] = final_angle
	physics["capture"] = capture
	physics["winning_index"] = target_index
	result["physics"] = physics
	var trajectory := _dictionary_array(result.get("trajectory", []))
	for i in range(trajectory.size()):
		var keyframe: Dictionary = trajectory[i]
		var t := clampf(float(keyframe.get("t", 0.0)), 0.0, 1.0)
		if t >= 0.72:
			var blend := clampf((t - 0.72) / 0.28, 0.0, 1.0)
			keyframe["ball_angle"] = lerp_angle(float(keyframe.get("ball_angle", final_angle)), final_angle, blend)
			keyframe["ball_radius"] = minf(float(keyframe.get("ball_radius", WHEEL_RADIUS * 0.58)), WHEEL_RADIUS * 0.62)
			keyframe["phase"] = "capture"
			trajectory[i] = keyframe
	result["trajectory"] = trajectory
	return result


func _nudge_target_number(table: Dictionary, bets: Array, fallback_number: String) -> String:
	var best_number := ""
	var best_score := -1
	for bet_value in bets:
		if typeof(bet_value) != TYPE_DICTIONARY:
			continue
		var bet: Dictionary = bet_value
		var numbers := _string_array(bet.get("numbers", []))
		if numbers.is_empty():
			continue
		var score := maxi(1, int(bet.get("stake", 0))) * maxi(1, int(bet.get("payout", 0)))
		if score > best_score:
			best_score = score
			best_number = str(numbers[0])
	if not best_number.is_empty():
		return best_number
	var sequence := _wheel_sequence(table)
	var index := sequence.find(fallback_number)
	if index < 0:
		return str(sequence[0]) if not sequence.is_empty() else "0"
	return str(sequence[posmod(index + 1, sequence.size())])


func _roulette_table_watch_status(table: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var surface_patrons := _patrons_for_surface(table, {})
	var patron_pressure := _patron_snitch_pressure(surface_patrons)
	var profile := _copy_dict(table.get("dealer_profile", {}))
	var suspicion := run_state.suspicion_level() if run_state != null else 0
	var dealer_attention := clampi(int(table.get("dealer_catch_base", 12)) + int(profile.get("late_bet_scrutiny", 10)) + int(float(suspicion) * 0.35) + int(float(patron_pressure) * 0.25), 0, 100)
	var pit_status := run_state.pit_boss_watch_status(environment) if run_state != null else {}
	var watched := bool(pit_status.get("watched", false)) or patron_pressure >= 30 or dealer_attention >= 46
	var summary := ""
	if bool(pit_status.get("watched", false)):
		summary = str(pit_status.get("summary", "Staff attention is already on you."))
	elif patron_pressure >= 30:
		summary = "Patrons along the rail are tracking your hands."
	elif dealer_attention >= 46:
		summary = "The croupier is watching the wheel too closely."
	return {
		"watched": watched,
		"dealer_attention": dealer_attention,
		"patron_pressure": patron_pressure,
		"pit_boss_watched": bool(pit_status.get("watched", false)),
		"summary": summary,
	}


func _nudge_wheel_heat(table: Dictionary, run_state: RunState, environment: Dictionary) -> int:
	var watch := _roulette_table_watch_status(table, run_state, environment)
	var base := 12 + int(table.get("dealer_catch_base", 12)) / 2
	if bool(watch.get("watched", false)):
		base += 16 + int(int(watch.get("patron_pressure", 0)) / 8)
	if run_state != null:
		base += run_state.security_risk_bonus("cheat")
		var pit := run_state.pit_boss_watch_status(environment)
		if bool(pit.get("active", false)):
			base += int(pit.get("cheat_heat_bonus", 0))
	return clampi(base, 10, 70)


func _roulette_room_info(surface_state: Dictionary) -> String:
	return "%s | inside $%d | outside $%d" % [
		_physics_summary_for_surface(surface_state),
		int(surface_state.get("inside_wager_total", 0)),
		int(surface_state.get("outside_wager_total", 0)),
	]


func _read_wheel_heat(table: Dictionary, run_state: RunState) -> int:
	var profile := _copy_dict(table.get("dealer_profile", {}))
	var base := int(table.get("dealer_catch_base", 12)) + int(profile.get("late_bet_scrutiny", 10))
	if run_state != null:
		base += run_state.security_risk_bonus("cheat")
		var pit := run_state.pit_boss_watch_status(run_state.current_environment)
		if bool(pit.get("active", false)):
			base += int(pit.get("cheat_heat_bonus", 0))
	return clampi(base / 3, 4, 36)


func _chip_denominations(table: Dictionary) -> Array:
	var source: Array = table.get("chip_denominations", []) if typeof(table.get("chip_denominations", [])) == TYPE_ARRAY else []
	var values: Array = []
	for value in source:
		var chip := maxi(1, int(value))
		if not values.has(chip):
			values.append(chip)
	if values.is_empty():
		values = [1, 5, 10, 25]
	values.sort()
	return values


func _closest_chip(value: int, denoms: Array) -> int:
	var best := int(denoms[0])
	var best_delta: int = abs(best - value)
	for denom in denoms:
		var delta: int = abs(int(denom) - value)
		if delta < best_delta:
			best = int(denom)
			best_delta = delta
	return best


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


func _rng_float(rng: RngStream, min_value: float, max_value: float) -> float:
	if max_value < min_value:
		var old_min := min_value
		min_value = max_value
		max_value = old_min
	var raw := float(rng.randi_range(0, 1000000)) / 1000000.0
	return lerpf(min_value, max_value, raw)


func _default_table_rng(table: Dictionary, suffix: String) -> RngStream:
	var rng := RngStream.new()
	rng.configure(_stable_hash("%s:%s:%s" % [get_id(), str(table.get("table_name", "roulette")), suffix]))
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


func _trajectory_keyframe(trajectory: Array, progress: float) -> Dictionary:
	if trajectory.is_empty():
		return {}
	if trajectory.size() == 1:
		return (trajectory[0] as Dictionary).duplicate(true)
	var scaled := clampf(progress, 0.0, 1.0) * float(trajectory.size() - 1)
	var low := clampi(int(floor(scaled)), 0, trajectory.size() - 1)
	var high := clampi(low + 1, 0, trajectory.size() - 1)
	var mix := scaled - float(low)
	var a: Dictionary = trajectory[low]
	var b: Dictionary = trajectory[high]
	return {
		"t": lerpf(float(a.get("t", 0.0)), float(b.get("t", 1.0)), mix),
		"ball_angle": lerp_angle(float(a.get("ball_angle", 0.0)), float(b.get("ball_angle", 0.0)), mix),
		"wheel_angle": lerp_angle(float(a.get("wheel_angle", 0.0)), float(b.get("wheel_angle", 0.0)), mix),
		"ball_radius": lerpf(float(a.get("ball_radius", WHEEL_RADIUS)), float(b.get("ball_radius", WHEEL_RADIUS)), mix),
		"bounce": lerpf(float(a.get("bounce", 0.0)), float(b.get("bounce", 0.0)), mix),
		"phase": str(b.get("phase", a.get("phase", "rim"))),
	}


func _surface_clock(surface) -> float:
	if surface != null and surface.has_method("surface_flicker"):
		return float(surface.surface_flicker())
	return float(Time.get_ticks_msec()) / 1000.0


func _draw_neon_panel(surface, rect: Rect2, accent: Color, alpha: float = 0.16) -> void:
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, alpha))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, minf(0.95, alpha + 0.22)), false, 1)


func _draw_table_button(surface, rect: Rect2, label: String, action: String, index: int, accent: Color, enabled: bool = true, selected: bool = false) -> void:
	var hovered: bool = bool(surface.surface_region_hovered(action, index))
	var color := accent if enabled else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.30)
	surface.draw_rect(rect, Color(color.r, color.g, color.b, 0.22 if selected or hovered else 0.10))
	surface.draw_rect(rect, color, false, 1)
	if selected:
		surface.draw_rect(rect.grow(2), Color(color.r, color.g, color.b, 0.32), false, 2)
	surface.surface_label_centered_plain(label.left(13), rect.grow(-2), 8 if rect.size.y < 24 else 10, color)
	if enabled:
		surface.surface_add_exact_hit(rect, action, index)


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
	surface.surface_label_centered_plain("%d" % value, Rect2(center - Vector2(radius, 5), Vector2(radius * 2.0, 10)), 7, C_DARK)


func _chip_color(value: int) -> Color:
	if value >= 25:
		return C_PINK
	if value >= 10:
		return C_YELLOW
	if value >= 5:
		return C_CYAN
	return C_TEAL


func _chip_color_name(name: String) -> Color:
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
			return C_CYAN


func _draw_table_character(surface, style: Dictionary, foot: Vector2, scale_value: float) -> void:
	var accent: Color = style.get("accent", C_CYAN)
	var hair: Color = style.get("hair", Color("#171022")) if typeof(style.get("hair", Color("#171022"))) == TYPE_COLOR else Color("#171022")
	var jacket: Color = style.get("jacket", Color("#1d2030")) if typeof(style.get("jacket", Color("#1d2030"))) == TYPE_COLOR else Color("#1d2030")
	var pose := str(style.get("pose", "idle"))
	var eye_offset := float(style.get("eye_offset", 0.0))
	var body := Rect2(foot + Vector2(-15, -38) * scale_value, Vector2(30, 34) * scale_value)
	var head := Rect2(foot + Vector2(-11, -60) * scale_value, Vector2(22, 22) * scale_value)
	var left_hand := foot + Vector2(-30, -22) * scale_value
	var right_hand := foot + Vector2(30, -22) * scale_value
	if pose == "snitch":
		right_hand = foot + Vector2(24, -50) * scale_value
	elif pose == "covered":
		left_hand = foot + Vector2(-16, -26) * scale_value
	surface.draw_rect(Rect2(foot.x - 24.0 * scale_value, foot.y - 4.0 * scale_value, 48.0 * scale_value, 4.0 * scale_value), Color(0, 0, 0, 0.32))
	surface.draw_line(foot + Vector2(-15, -31) * scale_value, left_hand, Color("#05060a"), maxf(2.0, 5.0 * scale_value))
	surface.draw_line(foot + Vector2(15, -31) * scale_value, right_hand, Color("#05060a"), maxf(2.0, 5.0 * scale_value))
	surface.draw_line(foot + Vector2(-15, -31) * scale_value, left_hand, Color(accent.r, accent.g, accent.b, 0.42), maxf(1.0, 2.0 * scale_value))
	surface.draw_line(foot + Vector2(15, -31) * scale_value, right_hand, Color(accent.r, accent.g, accent.b, 0.42), maxf(1.0, 2.0 * scale_value))
	surface.draw_rect(Rect2(left_hand + Vector2(-3, -2) * scale_value, Vector2(6, 6) * scale_value), Color("#c49371"))
	surface.draw_rect(Rect2(right_hand + Vector2(-3, -2) * scale_value, Vector2(6, 6) * scale_value), Color("#c49371"))
	surface.draw_rect(body, Color("#05060a"))
	surface.draw_rect(Rect2(body.position + Vector2(3, 4) * scale_value, body.size - Vector2(6, 8) * scale_value), jacket)
	surface.draw_rect(body, Color(accent.r, accent.g, accent.b, 0.34), false, 1)
	surface.draw_rect(head, Color("#c49371"))
	surface.draw_rect(Rect2(head.position, Vector2(head.size.x, 7 * scale_value)), hair)
	if bool(style.get("blink", false)):
		surface.draw_rect(Rect2(head.position + Vector2(4 + eye_offset, 10) * scale_value, Vector2(5, 1) * scale_value), C_DARK)
		surface.draw_rect(Rect2(head.position + Vector2(13 + eye_offset, 10) * scale_value, Vector2(5, 1) * scale_value), C_DARK)
	else:
		surface.draw_rect(Rect2(head.position + Vector2(4 + eye_offset, 9) * scale_value, Vector2(4, 3) * scale_value), C_DARK)
		surface.draw_rect(Rect2(head.position + Vector2(14 + eye_offset, 9) * scale_value, Vector2(4, 3) * scale_value), C_DARK)
	if str(style.get("silhouette", "")) == "cap":
		surface.draw_rect(Rect2(head.position + Vector2(-3, -3) * scale_value, Vector2(head.size.x + 8 * scale_value, 5 * scale_value)), hair)
	elif str(style.get("silhouette", "")) == "glasses":
		surface.draw_rect(Rect2(head.position + Vector2(4, 11) * scale_value, Vector2(6, 4) * scale_value), C_DARK, false, 1)
		surface.draw_rect(Rect2(head.position + Vector2(14, 11) * scale_value, Vector2(6, 4) * scale_value), C_DARK, false, 1)
	elif str(style.get("silhouette", "")) == "rings":
		surface.draw_rect(Rect2(right_hand + Vector2(-3, 3) * scale_value, Vector2(6, 3) * scale_value), C_YELLOW)
	surface.surface_label_centered(str(style.get("name", "")).left(8), Rect2(foot + Vector2(-34, 2), Vector2(68, 12)), 8, accent)


func _patron_seat_position(index: int) -> Vector2:
	match index:
		0:
			return Vector2(832, 112)
		1:
			return Vector2(832, 210)
		2:
			return Vector2(832, 308)
		_:
			return Vector2(832, 308)


func _patron_hair_color(patron: Dictionary) -> Color:
	match str(patron.get("silhouette", "coat")):
		"cap":
			return Color("#1b2338")
		"glasses":
			return Color("#2d1d32")
		"rings":
			return Color("#3a2430")
		_:
			return Color("#171022")


func _patron_jacket_color(patron: Dictionary) -> Color:
	match str(patron.get("seat_style", "open")):
		"vest":
			return Color("#172633")
		"jacket":
			return Color("#251930")
		_:
			return Color("#1c2230").lerp(_chip_color_name(str(patron.get("chip_color", "cyan"))), 0.22)


func _physics_summary(table: Dictionary) -> String:
	var profile := _normalize_physics_profile(table.get("physics_profile", {}))
	return "scatter %.0f deg, tilt %.1f" % [float(profile.get("diamond_scatter_degrees", 24.0)), float(profile.get("tilt_degrees", 0.0))]


func _physics_summary_for_surface(surface_state: Dictionary) -> String:
	var profile := _copy_dict(surface_state.get("physics_profile", {}))
	return "wheel %s | scatter %.0f" % [str(surface_state.get("variant", "00")).replace("_", " "), float(profile.get("diamond_scatter_degrees", 24.0))]


func _rect_to_dict(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y}


func _rect_from_dict(value: Variant) -> Rect2:
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = value
	return Rect2(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("w", 0.0)), float(data.get("h", 0.0)))


func _vector_to_dict(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _vector_from_dict(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if typeof(value) != TYPE_DICTIONARY:
		return fallback
	var data: Dictionary = value
	return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))


func _array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


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


static func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
