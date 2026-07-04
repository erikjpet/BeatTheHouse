class_name BarDiceGame
extends GameModule

# Release bar dice table. The canonical ruleset is Ship, Captain, Crew:
# five dice, up to three shakes, lock 6-5-4, then compare cargo.

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

const DICE_COUNT := 5
const DIE_FACES := 6
const MAX_SHAKES := 3
const STATE_SCHEMA := "bar_dice_table_state"
const STATE_VERSION := 3
const TUMBLE_CHANNEL := "bar_dice_tumble"
const TUMBLE_DURATION_MSEC := 900
const PRESS_CAP := 3
const CONTROLLED_ROLL_PERFECT_WINDOW_MSEC := 90
const CONTROLLED_ROLL_GOOD_WINDOW_MSEC := 230
const CONTROLLED_ROLL_CLOSE_WINDOW_MSEC := 380
const CONTROLLED_ROLL_METER_PERIOD_MSEC := 1300
const CONTROLLED_ROLL_BASE_HEAT := 10
const CONTROLLED_ROLL_PERFECT_HEAT_REDUCTION := 3
const CONTROLLED_ROLL_PARTIAL_HEAT_BONUS := 3
const CONTROLLED_ROLL_MISS_HEAT_BONUS := 5
const CONTROLLED_ROLL_BLOWN_HEAT_BONUS := 12
const CONTROLLED_ROLL_ITEM_EFFECT_KEYS := [
	"bar_dice_controlled_roll_perfect_msec",
	"bar_dice_controlled_roll_good_msec",
	"bar_dice_controlled_roll_close_msec",
	"bar_dice_controlled_roll_meter_period_msec",
	"bar_dice_controlled_roll_base_heat",
	"skill_cheat_drunk_window_offset_msec",
]
const CONSOLE_Y := 344.0
const RULES_PANEL_RECT := Rect2(556, 218, 300, 58)
const PAYTABLE_PANEL_RECT := Rect2(556, 282, 190, 50)
const ROUND_TIMER_RECT := Rect2(752, 282, 116, 50)
const RULES_PANEL_LINE_LIMIT := 47

const PLAYER_DICE_ORIGIN := Vector2(262, 214)
const DIE_SIZE := Vector2(38, 38)
const DIE_SPACING := 46.0
const OPPONENT_DIE_SIZE := Vector2(22, 22)
const OPPONENT_DIE_SPACING := 29.0
const MAX_VISIBLE_OPPONENT_ROWS := 3
const OPPONENT_DICE_ORIGINS := [
	Vector2(76, 150),
	Vector2(76, 188),
	Vector2(76, 226),
]
const BAR_PATRON_POSITIONS := [
	Vector2(94, 84),
	Vector2(236, 70),
	Vector2(660, 70),
	Vector2(808, 84),
]

const RULESET_ORDER := ["ship_captain_crew"]
const RULESET_LABEL := {
	"ship_captain_crew": "Ship, Captain, Crew",
}
const VARIATION_LIBRARY := [
	{
		"id": "ship_captain_crew",
		"label": "Ship, Captain, Crew",
		"status": "active",
		"summary": "Lock 6-5-4, score cargo, high cargo wins the pot.",
	},
	{
		"id": "midnight_cargo",
		"label": "Midnight Cargo",
		"status": "future",
		"summary": "Cargo 12 side-pot variation reserved for later content.",
	},
	{
		"id": "last_call_lowball",
		"label": "Last Call Lowball",
		"status": "future",
		"summary": "Low cargo variation reserved for later content.",
	},
]
const EDGE_TIER_ORDER := ["friendly", "standard", "sharp"]
const EDGE_TIER_LABEL := {
	"friendly": "Loose Bar Rake",
	"standard": "House Bar Rake",
	"sharp": "Sharp Bar Rake",
}
const EDGE_RAKE_PERCENT := {
	"friendly": 4,
	"standard": 7,
	"sharp": 10,
}
const EDGE_PAYOUT_PERCENT := {
	"friendly": 68,
	"standard": 66,
	"sharp": 70,
}
const CATEGORY_RANK := {
	"not_qualified": 0,
	"ship_only": 10,
	"ship_captain": 20,
	"ship_captain_crew": 50,
	"perfect_cargo": 70,
}
const CATEGORY_LABEL := {
	"not_qualified": "No Ship",
	"ship_only": "Ship Only",
	"ship_captain": "Ship + Captain",
	"ship_captain_crew": "Ship Captain Crew",
	"perfect_cargo": "Midnight Cargo",
}
const DIE_WORD := {1: "One", 2: "Two", 3: "Three", 4: "Four", 5: "Five", 6: "Six"}
const DIE_WORD_PLURAL := {1: "Ones", 2: "Twos", 3: "Threes", 4: "Fours", 5: "Fives", 6: "Sixes"}
const MEMORABLE_REGULAR := {
	"id": "knucklebones_nell",
	"name": "Knucklebones Nell",
	"seat": 0,
	"mood": "wry",
	"personality": "Rail regular who names every die before it lands.",
	"preferred_bet": "cargo",
	"cosmetic_bet": 20,
	"rapport": 58,
	"snitch_risk": 28,
	"chip_stack": 96,
	"chip_color": "yellow",
	"watching": true,
	"silhouette": "rings",
	"tell": "names every die",
	"temper": "sharp",
	"seat_style": "rings",
	"animation_offset": 420,
	"snitch_threshold": 34,
	"last_reaction": "neutral",
	"banter_lines": [
		"Ship first, sweetheart.",
		"Captain before cargo.",
		"Pot rides if cargo ties.",
	],
	"accent": {"name": "yellow"},
}


func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
	var result: Dictionary = super.enter(run_state, environment)
	var state := _dice_state(run_state, environment)
	result["message"] = "%s sets the dice cup on the %s. Lock 6-5-4, then high cargo wins the pot." % [
		str(state.get("dealer_name", "The bartender")),
		str(state.get("bar_name", "bar top")),
	]
	return result


func generate_environment_state(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var tier := str(rng.pick(EDGE_TIER_ORDER, "standard"))
	var bar_name := str(rng.pick(["brass rail", "maple bar", "corner rail", "back bar", "long bar"], "bar top"))
	var dealer_name := str(rng.pick(["Nora", "Cal", "Marta", "Dev", "Lou"], "Nora"))
	var ladder := _generated_stake_ladder(environment, rng)
	var default_index := clampi(ladder.size() / 2, 0, maxi(0, ladder.size() - 1))
	var table_key := "%s:%s:%s" % [str(run_state.seed_text if run_state != null else "bar"), str(environment.get("id", "")), bar_name]
	var state := {
		"schema": STATE_SCHEMA,
		"version": STATE_VERSION,
		"table_key": table_key,
		"ruleset_family": "ship_captain_crew",
		"ruleset_label": str(RULESET_LABEL.get("ship_captain_crew", "Ship, Captain, Crew")),
		"available_variants": VARIATION_LIBRARY.duplicate(true),
		"bonus_mode": "pot_rake",
		"bonus_label": "Carryover Pot",
		"edge_tier": tier,
		"edge_label": str(EDGE_TIER_LABEL.get(tier, "House Bar Rake")),
		"rake_percent": int(EDGE_RAKE_PERCENT.get(tier, 7)),
		"hosted_payout_percent": int(EDGE_PAYOUT_PERCENT.get(tier, 66)),
		"bar_name": bar_name,
		"dealer_name": dealer_name,
		"dealer_profile": _generate_dealer_profile(rng, dealer_name, tier),
		"patrons": _generate_patrons(rng, int(environment.get("depth", 2))),
		"stake_ladder": ladder,
		"selected_stake_index": default_index,
		"carryover_pot": 0,
		"loaded_die": 0,
		"rounds_played": 0,
		"last_result": {},
		"table_round_timer_started_msec": 0,
	}
	return _normalize_state(state)


func wager_cost_for_context(action_id: String, stake: int, run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> int:
	if action_id == "press":
		return maxi(0, stake)
	var state := _dice_state(run_state, environment)
	return _active_stake_from_context(stake, state, ui_state, run_state, environment)


func surface_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var state := _dice_state(run_state, environment)
	var ui := _normalized_ui_state(run_state, environment, ui_state, state)
	var last_result := _copy_dict(state.get("last_result", {}))
	var rolled := bool(ui.get("rolled", false))
	var showing_result := not rolled and not last_result.is_empty()
	var phase := "select" if rolled else ("settled" if showing_result else "bet")
	var active_stake := _active_stake_from_context(0, state, ui, run_state, environment)
	var patrons := _patrons_for_surface(state, last_result, active_stake)
	var participants := _participant_count(state)
	var working_pot := _working_pot(active_stake, state)
	var rake := _rake_for_pot(working_pot, state)
	var now_msec := int(ui_state.get("surface_time_msec", Time.get_ticks_msec()))
	var timer_active := phase == "bet"
	var timer_state := state.duplicate(true)
	var round_timer := GameModule.table_round_timer_status(timer_state, now_msec, "Next shake", GameModule.TABLE_ROUND_START_DELAY_MSEC, false) if timer_active else {}

	var player_dice: Array = []
	var opponent_dice: Array = []
	var player_score: Dictionary = {}
	var opponent_score: Dictionary = {}
	if phase == "select":
		player_dice = _int_dice(ui.get("dice", []))
		player_score = _score_ship(player_dice)
	elif phase == "settled":
		player_dice = _int_dice(last_result.get("player_dice", []))
		opponent_dice = _int_dice(last_result.get("winning_opponent_dice", last_result.get("house_dice", [])))
		player_score = _copy_dict(last_result.get("player_score", {}))
		opponent_score = _copy_dict(last_result.get("winning_opponent_score", last_result.get("house_score", {})))
	else:
		player_dice = _generate_opening(run_state, state)
		player_score = _score_ship(player_dice)
	if player_dice.size() != DICE_COUNT:
		player_dice = [0, 0, 0, 0, 0]
	var reroll := _index_array(ui.get("reroll", [])) if phase == "select" else []
	var suggested := _suggested_reroll_for_ruleset(player_dice, "ship_captain_crew") if phase == "select" else []
	var locked := _index_array(player_score.get("scoring_indices", [])) if not player_score.is_empty() else []
	var remaining_shakes := _remaining_shakes(ui) if phase == "select" else 0
	var loaded_armed := bool(ui.get("loaded_armed", false)) and phase == "select"
	var palm_armed := bool(ui.get("palm_armed", false)) and phase == "select"
	var controlled_roll: Dictionary = _normalized_controlled_roll(ui.get("controlled_roll", {})) if loaded_armed else {}
	var controlled_roll_meter: Dictionary = _controlled_roll_meter(controlled_roll, ui) if not controlled_roll.is_empty() else {}
	var controlled_roll_meter_active := not controlled_roll_meter.is_empty() and str(controlled_roll.get("skill_grade", "")).is_empty()
	var loaded_value := int(ui.get("loaded_value", 0))
	if loaded_armed and loaded_value <= 0:
		loaded_value = _loaded_value_for_ruleset(player_dice, "ship_captain_crew")
	var tumble := _active_tumble(ui, last_result, rolled)
	var animated_dice_indices := _index_array(tumble.get("indices", []))
	if rolled and not str(tumble.get("id", "")).is_empty() and animated_dice_indices.is_empty():
		animated_dice_indices = _all_die_indices()
	var tumble_active := not str(tumble.get("id", "")).is_empty()
	var surface_motion_active := tumble_active or controlled_roll_meter_active
	var pit_boss := run_state.pit_boss_watch_status(environment) if run_state != null else {}
	var press_offer := _copy_dict(last_result.get("press_offer", {}))
	var press_available := phase == "settled" and bool(press_offer.get("available", false))
	var controlled_roll_item_modifiers := skill_item_modifier_badges(run_state, CONTROLLED_ROLL_ITEM_EFFECT_KEYS)
	var explainer := _bar_dice_explainer(phase, player_score, last_result, active_stake, working_pot, rake, participants, round_timer)
	var turn_guide := _bar_dice_turn_guide(phase, player_score, reroll, suggested, remaining_shakes, active_stake, working_pot, round_timer, last_result)
	var rules_lines := _bar_dice_rules_panel_lines(phase, turn_guide, explainer)
	var action_buttons := _bar_dice_action_buttons(
		phase,
		remaining_shakes,
		reroll,
		suggested,
		phase == "select" and remaining_shakes > 0 and not suggested.is_empty(),
		press_available,
		int(press_offer.get("risk", 0)),
		loaded_armed,
		controlled_roll
	)
	var opponent_rows := _surface_opponent_rows(state, last_result, phase)

	return GameModule.surface_spec({
		"surface_renderer": "dice_table",
		"surface_life": "bar_dice_table",
		"surface_cast": "dealer_table",
		"surface_controls_native": true,
		"surface_stake_controls_required": false,
		"surface_embeds_outcomes": true,
		"surface_suppresses_game_result_burst": true,
		"surface_animates_idle": surface_motion_active,
		"surface_realtime_state_refresh": surface_motion_active,
		"phase": phase,
		"table_key": str(state.get("table_key", "")),
		"ruleset_family": "ship_captain_crew",
		"ruleset_label": str(state.get("ruleset_label", "Ship, Captain, Crew")),
		"available_variants": _copy_array(state.get("available_variants", [])),
		"bonus_mode": str(state.get("bonus_mode", "pot_rake")),
		"bonus_label": str(state.get("bonus_label", "Carryover Pot")),
		"edge_tier": str(state.get("edge_tier", "standard")),
		"edge_label": str(state.get("edge_label", "House Bar Rake")),
		"rake_percent": int(state.get("rake_percent", 7)),
		"hosted_payout_percent": int(state.get("hosted_payout_percent", 66)),
		"bar_name": str(state.get("bar_name", "bar top")),
		"dealer_name": str(state.get("dealer_name", "Bartender")),
		"dealer_profile": _copy_dict(state.get("dealer_profile", {})),
		"dealer_attention_pressure": 8 if phase == "select" else 4,
		"patrons": patrons,
		"rail_bettors": patrons,
		"patron_wager_action": "bar_dice_rail_bet",
		"snitch_pressure": _patron_snitch_pressure(patrons),
		"suspicion_level": run_state.suspicion_level() if run_state != null else 0,
		"stake_ladder": _int_array(state.get("stake_ladder", [])),
		"selected_stake_index": _selected_stake_index(state, ui),
		"selected_stake": active_stake,
		"active_stake": active_stake,
		"side_bet": 0,
		"bet_meter": active_stake,
		"chips_meter": maxi(0, run_state.bankroll) if run_state != null else 0,
		"pot_meter": working_pot,
		"rake_meter": rake,
		"win_meter": int(last_result.get("gross_payout", 0)) if showing_result else _gross_payout_for_pot(working_pot, rake, state),
		"carryover_pot": int(state.get("carryover_pot", 0)),
		"participant_count": participants,
		"player": player_dice,
		"house": opponent_dice,
		"house_revealed": phase == "settled" and not opponent_dice.is_empty(),
		"opponent_name": str(last_result.get("winning_opponent_name", "the table")),
		"opponent_rows": opponent_rows,
		"reroll": reroll,
		"suggested_reroll": suggested,
		"last_rerolled": _index_array(ui.get("last_rerolled", [])),
		"animated_dice_indices": animated_dice_indices,
		"reroll_summary": _reroll_summary(reroll if not reroll.is_empty() else suggested),
		"scoring_indices": locked,
		"house_scoring_indices": _index_array(opponent_score.get("scoring_indices", [])),
		"shake_number": int(ui.get("shake_number", 0)) if phase == "select" else 0,
		"remaining_shakes": remaining_shakes,
		"can_shake_again": phase == "select" and _remaining_shakes(ui) > 0 and not _suggested_reroll_for_ruleset(player_dice, "ship_captain_crew").is_empty(),
		"loaded_armed": loaded_armed,
		"palm_armed": palm_armed,
		"loaded_value": loaded_value,
		"controlled_roll": controlled_roll,
		"controlled_roll_meter": controlled_roll_meter,
		"controlled_roll_grade": str(controlled_roll.get("skill_grade", "")),
		"controlled_roll_ready": loaded_armed and not controlled_roll.is_empty(),
		"controlled_roll_item_modifiers": controlled_roll_item_modifiers,
		"player_score": player_score,
		"player_blurb": _hand_blurb(player_score),
		"house_blurb": _hand_blurb(opponent_score),
		"outcome": str(last_result.get("outcome", "")),
		"payout_mult": float(last_result.get("payout_mult", 0.0)),
		"paytable_rows": _paytable_rows(state, active_stake),
		"table_round_timer": round_timer,
		"bar_dice_explainer": explainer,
		"bar_dice_turn_guide": turn_guide,
		"bar_dice_rules_lines": rules_lines,
		"bar_dice_layout": _bar_dice_layout_snapshot(),
		"surface_ui_protected_regions": _bar_dice_text_panel_regions(),
		"bar_dice_action_buttons": action_buttons,
		"dice_legend": _bar_dice_legend(),
		"table_regular_id": str(MEMORABLE_REGULAR.get("id", "knucklebones_nell")),
		"bar_dice_pacing": {
			"patron_turn_model": "simultaneous_cups",
			"patron_dead_wait_msec": 0,
			"opponent_rows_visible": opponent_rows.size(),
		},
		"info_text": str(explainer.get("summary", "")),
		"result_message": str(last_result.get("summary", "")) if showing_result else "",
		"result_bankroll_delta": int(last_result.get("bankroll_delta", 0)) if showing_result else 0,
		"result_suspicion_delta": int(last_result.get("suspicion_delta", 0)) if showing_result else 0,
		"press_available": press_available,
		"press_risk": int(press_offer.get("risk", 0)) if press_available else 0,
		"pit_boss_watched": bool(pit_boss.get("watched", false)) if bool(pit_boss.get("active", false)) else false,
		"pit_boss_summary": str(pit_boss.get("summary", "")) if bool(pit_boss.get("active", false)) else "",
		"rounds_played": int(state.get("rounds_played", 0)),
		"native_selected_surface_actions": _selected_surface_actions(ui),
		"surface_animation_channels": [
			GameModule.surface_animation_channel(
				TUMBLE_CHANNEL,
				str(tumble.get("id", "")),
				TUMBLE_DURATION_MSEC if not str(tumble.get("id", "")).is_empty() else 0,
				int(tumble.get("started", 0))
			),
		],
		"surface_action_blocks": _tumble_action_blocks(),
		"surface_action_bindings": {
			"legal": {"action": "bar_dice_resolve", "index": 0},
			"cheat": {"action": "bar_dice_load", "index": 0},
			"bar_dice_release": {"action": "bar_dice_release", "index": 0},
			"bar_dice_palm": {"action": "bar_dice_palm", "index": 0},
			"bar_dice_press": {"action": "bar_dice_press", "index": 0},
			"bar_dice_stake": {"action": "bar_dice_stake", "index": 0},
			"surface_stake_up": {"action": "bar_dice_stake", "index": 0},
		},
		"surface_audio": GameModule.surface_audio_spec({
			"profile_id": "bar_dice_table",
			"action_cues": {
				"bar_dice_roll": "machine_button",
				"bar_dice_shake": "machine_button",
				"bar_dice_resolve": "machine_button",
				"bar_dice_load": "machine_button",
				"bar_dice_release": "machine_button",
				"bar_dice_palm": "machine_button",
				"bar_dice_press": "machine_button",
				"bar_dice_select": "machine_button",
				"bar_dice_stake": "machine_button",
				"bar_dice_rail_bet": "machine_button",
			},
			"state_sync": {"method": "bar_dice_table_state", "tumble_channel": TUMBLE_CHANNEL},
		}),
	})


func draw_surface(surface, surface_state: Dictionary, _render_context: Dictionary = {}) -> bool:
	if str(surface_state.get("surface_renderer", "")) != "dice_table":
		return false
	surface.surface_begin_design_space(surface.surface_board_size())
	_draw_bar_room(surface, surface_state)
	_draw_bar_top(surface, surface_state)
	TableVisualsScript.draw_table_patrons(surface, surface_state, BAR_PATRON_POSITIONS)
	TableVisualsScript.draw_dealer_station(surface, surface_state, "calls cargo")
	_draw_dice_rows(surface, surface_state)
	_draw_explainer(surface, surface_state)
	_draw_paytable(surface, surface_state)
	_draw_round_timer(surface, surface_state)
	_draw_console(surface, surface_state)
	surface.surface_end_design_space()
	return true


func surface_action_command(surface_action: String, index: int, confirm_requested: bool, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var state := _dice_state(run_state, environment)
	var next := _normalized_ui_state(run_state, environment, ui_state, state)
	match surface_action:
		"bar_dice_rail_bet":
			return _patron_bet_command(index, next, state, run_state, environment)
		"bar_dice_stake":
			if bool(next.get("rolled", false)):
				return _message_command(next, "Settle this cup before changing your ante.")
			var ladder := _int_array(state.get("stake_ladder", []))
			if index >= 0 and index < ladder.size():
				next["selected_stake_index"] = index
				next.erase("table_social_alignment")
				return GameModule.surface_command({
					"handled": true,
					"ui_state": next,
					"selected_index": index,
					"preserve_surface_ui_state": true,
					"message": "Ante set to $%d." % int(ladder[index]),
				})
			return _message_command(next, "That chip is off the bar.")
		"bar_dice_roll":
			if bool(next.get("rolled", false)):
				return _message_command(next, "The cup is already open.")
			next["rolled"] = true
			next["shake_number"] = 1
			next["dice"] = _generate_opening(run_state, state)
			next["reroll"] = []
			next["loaded_armed"] = false
			next["palm_armed"] = false
			next.erase("controlled_roll")
			next.erase("loaded_value")
			next["last_rerolled"] = _all_die_indices()
			_set_tumble(next, "open", _all_die_indices())
			return GameModule.surface_command({
				"handled": true,
				"ui_state": next,
				"selected_index": index,
				"preserve_surface_ui_state": true,
				"message": "First shake down. Teal dice lock 6, then 5, then 4. Click amber dice to mark rerolls, then SHAKE or SETTLE.",
			})
		"bar_dice_shake":
			if not bool(next.get("rolled", false)):
				return _message_command(next, "Ante first, then roll the cup.")
			if _remaining_shakes(next) <= 0:
				return _message_command(next, "Three shakes are spent. Settle the cargo.")
			var marked_before := _index_array(next.get("reroll", []))
			var dice_before := _int_dice(next.get("dice", []))
			var auto_marks := _suggested_reroll_for_ruleset(dice_before, "ship_captain_crew") if marked_before.is_empty() else []
			var marks_for_shake := marked_before if not marked_before.is_empty() else auto_marks
			next = _shake_again(next, run_state, state, marks_for_shake)
			var rerolled_count := marks_for_shake.size()
			var shake_message := "No legal reroll dice remain; settle the cup."
			if rerolled_count > 0:
				shake_message = "Shake rerolled dice %s. Unmarked dice stayed still; %d shake%s remain." % [
					_reroll_summary(marks_for_shake),
					_remaining_shakes(next),
					"" if _remaining_shakes(next) == 1 else "s",
				]
			return GameModule.surface_command({
				"handled": true,
				"ui_state": next,
				"selected_index": index,
				"preserve_surface_ui_state": true,
				"message": shake_message,
			})
		"bar_dice_select":
			if not bool(next.get("rolled", false)):
				return _message_command(next, "Roll the cup before marking cargo dice.")
			var dice := _int_dice(next.get("dice", []))
			var locks := _ship_lock_indices(dice)
			if locks.has(index):
				return _message_command(next, "Ship, Captain, and Crew stay locked once they show.")
			var marks := _index_array(next.get("reroll", []))
			if marks.has(index):
				marks.erase(index)
			elif index >= 0 and index < DICE_COUNT:
				marks.append(index)
			marks.sort()
			next["reroll"] = marks
			next["loaded_armed"] = false
			next["palm_armed"] = false
			next.erase("controlled_roll")
			next["last_rerolled"] = []
			next.erase("loaded_value")
			var select_message := "No dice marked. SHAKE AMBER rerolls suggested dice; SETTLE keeps the cup as shown." if marks.is_empty() else "Pink dice %s will reroll on SHAKE. Plain dice stay exactly where they are." % _reroll_summary(marks)
			return GameModule.surface_command({
				"handled": true,
				"ui_state": next,
				"selected_index": index,
				"preserve_surface_ui_state": true,
				"message": select_message,
			})
		"bar_dice_resolve":
			if bool(next.get("loaded_armed", false)) and not _normalized_controlled_roll(next.get("controlled_roll", {})).is_empty():
				return _action_command("loaded_toss", "cheat", confirm_requested, next, index, _resolve_prompt(next, "loaded_toss"))
			next["loaded_armed"] = false
			next["palm_armed"] = false
			next.erase("controlled_roll")
			next.erase("loaded_value")
			return _action_command("roll", "legal", confirm_requested, next, index, _resolve_prompt(next, "roll"))
		"bar_dice_load":
			if not bool(next.get("rolled", false)):
				next["rolled"] = true
				next["shake_number"] = 1
				next["dice"] = _generate_opening(run_state, state)
				next["last_rerolled"] = _all_die_indices()
				_set_tumble(next, "open", _all_die_indices())
			next["loaded_armed"] = true
			next["palm_armed"] = false
			next["loaded_value"] = _loaded_value_for_ruleset(_int_dice(next.get("dice", [])), "ship_captain_crew")
			next["controlled_roll"] = _start_controlled_roll(next, run_state, state)
			return _action_command("loaded_toss", "cheat", false, next, index, _resolve_prompt(next, "loaded_toss"))
		"bar_dice_release":
			if not bool(next.get("rolled", false)):
				return _message_command(next, "Roll the cup before timing a loaded toss.")
			var controlled: Dictionary = _normalized_controlled_roll(next.get("controlled_roll", {}))
			if controlled.is_empty():
				controlled = _start_controlled_roll(next, run_state, state)
			controlled["input_msec"] = int(next.get("controlled_roll_input_msec", _surface_time_msec(next)))
			controlled = _grade_controlled_roll(controlled)
			next["loaded_armed"] = true
			next["palm_armed"] = false
			next["loaded_value"] = int(controlled.get("desired_face", _loaded_value_for_ruleset(_int_dice(next.get("dice", [])), "ship_captain_crew")))
			next["controlled_roll"] = controlled
			next.erase("controlled_roll_input_msec")
			return _action_command("loaded_toss", "cheat", confirm_requested, next, index, _resolve_prompt(next, "loaded_toss"))
		"bar_dice_palm":
			if not bool(next.get("rolled", false)):
				next["rolled"] = true
				next["shake_number"] = 1
				next["dice"] = _generate_opening(run_state, state)
				next["last_rerolled"] = _all_die_indices()
				_set_tumble(next, "open", _all_die_indices())
			next["loaded_armed"] = false
			next["palm_armed"] = true
			next.erase("controlled_roll")
			next.erase("loaded_value")
			return _action_command("palmed_swap", "cheat", confirm_requested, next, index, _resolve_prompt(next, "palmed_swap"))
		"bar_dice_press":
			return _action_command("press", "legal", confirm_requested, next, index, "Press the last clean win. Click again to risk it.")
	return {"handled": false}


func resolve(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return resolve_with_context(action_id, stake, run_state, environment, rng, {})


func resolve_with_context(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary = {}) -> Dictionary:
	if action_id == "press":
		return _resolve_press(stake, run_state, environment, rng)
	if action_id != "roll" and action_id != "loaded_toss" and action_id != "palmed_swap":
		return _empty_result(action_id, stake, environment, "That bar dice action is not available.")
	if run_state == null:
		return _empty_result(action_id, stake, environment, "No run is active for bar dice.")
	var is_cheat := action_id == "loaded_toss" or action_id == "palmed_swap"
	var state := _dice_state(run_state, environment)
	var ui := _normalized_ui_state(run_state, environment, ui_state, state)
	var adjusted_stake := _active_stake_from_context(stake, state, ui, run_state, environment)
	if adjusted_stake <= 0 or adjusted_stake > run_state.bankroll:
		return _empty_result(action_id, stake, environment, "You do not have enough bankroll for this ante.")
	var table_result := _resolve_table_round(action_id, adjusted_stake, run_state, state, rng, ui)
	var outcome := str(table_result.get("outcome", "lose"))
	var player_score := _copy_dict(table_result.get("player_score", {}))
	var player_category := str(player_score.get("category", "not_qualified"))
	var participants := int(table_result.get("participant_count", _participant_count(state)))
	var pot := int(table_result.get("pot", _working_pot(adjusted_stake, state)))
	var rake := int(table_result.get("rake", _rake_for_pot(pot, state)))
	var gross_payout := int(table_result.get("gross_payout", 0))
	var bankroll_delta := gross_payout - adjusted_stake
	if outcome == "carry":
		bankroll_delta = -adjusted_stake
	elif outcome == "lose":
		bankroll_delta = -adjusted_stake
	var won := outcome == "win"
	var luck_bonus := clampi(run_state.luck_win_chance_bonus() + _item_effect_total("win_chance", run_state), 0, 45)
	if not won and outcome == "lose" and luck_bonus > 0 and rng.randi_range(1, 100) <= luck_bonus:
		table_result = _luck_lift_to_win(table_result, adjusted_stake, state)
		outcome = "win"
		won = true
		player_score = _copy_dict(table_result.get("player_score", {}))
		player_category = str(player_score.get("category", "ship_captain_crew"))
		pot = int(table_result.get("pot", pot))
		rake = int(table_result.get("rake", rake))
		gross_payout = int(table_result.get("gross_payout", 0))
		bankroll_delta = gross_payout - adjusted_stake
	if won:
		bankroll_delta = maxi(1, bankroll_delta + run_state.luck_payout_bonus(adjusted_stake, true) + _item_effect_total("win_bonus", run_state))
	elif bankroll_delta < 0:
		bankroll_delta = mini(0, bankroll_delta + _item_effect_total("loss_reduction", run_state))

	var suspicion_delta := 0
	var security_message := ""
	var pit_boss_summary := ""
	var pit_boss_watched := false
	var pit_boss_heat_bonus := 0
	var base_suspicion_delta := 0
	var ended := false
	var skill_outcome := ""
	var skill_grade := ""
	var skill_accuracy := 0
	var skill_margin_msec := 0
	var controlled_roll: Dictionary = _copy_dict(table_result.get("controlled_roll", {}))
	var patron_snitch_pressure := 0
	var patron_snitch_heat_bonus := 0
	if is_cheat:
		if action_id == "loaded_toss":
			skill_grade = str(controlled_roll.get("skill_grade", "miss"))
			skill_accuracy = clampi(int(controlled_roll.get("skill_accuracy", 0)), 0, 100)
			skill_margin_msec = int(controlled_roll.get("skill_margin_msec", 0))
			skill_outcome = _controlled_roll_skill_outcome(skill_grade)
			patron_snitch_pressure = int(controlled_roll.get("patron_snitch_pressure", 0))
		else:
			skill_grade = "swap"
			skill_accuracy = 100
			skill_margin_msec = 0
			skill_outcome = "palmed_swap"
		var heat := _cheat_heat(action_id, adjusted_stake, run_state, environment, controlled_roll)
		suspicion_delta = int(heat.get("suspicion_delta", 0))
		base_suspicion_delta = int(heat.get("base_suspicion_delta", 0))
		security_message = str(heat.get("security_message", ""))
		pit_boss_summary = str(heat.get("pit_boss_summary", ""))
		pit_boss_watched = bool(heat.get("pit_boss_watched", false))
		pit_boss_heat_bonus = int(heat.get("pit_boss_heat_bonus", 0))
		patron_snitch_pressure = int(heat.get("patron_snitch_pressure", patron_snitch_pressure))
		patron_snitch_heat_bonus = int(heat.get("patron_snitch_heat_bonus", 0))
		ended = bool(heat.get("ended", false))
		bankroll_delta += int(heat.get("bankroll_delta", 0))

	var carryover_pot := int(table_result.get("carryover_pot", 0))
	state["carryover_pot"] = carryover_pot
	state["rounds_played"] = int(state.get("rounds_played", 0)) + 1
	GameModule.reset_table_round_timer(state)
	var resolved_at := Time.get_ticks_msec()
	var summary := _outcome_message(table_result, outcome, bankroll_delta, suspicion_delta, action_id, pit_boss_summary, security_message, state)
	_apply_patron_rapport_after_round(state, ui, outcome)
	var press_offer := {}
	if won and not is_cheat and bankroll_delta > 0:
		press_offer = {
			"available": true,
			"risk": mini(maxi(1, bankroll_delta), adjusted_stake * 8),
			"level": 0,
			"cap": PRESS_CAP,
		}
	var winning_opponent := _copy_dict(table_result.get("winning_opponent", {}))
	state["last_result"] = {
		"player_dice": _int_dice(table_result.get("player_dice", [])),
		"house_dice": _int_dice(winning_opponent.get("dice", [])),
		"winning_opponent_dice": _int_dice(winning_opponent.get("dice", [])),
		"winning_opponent_name": str(winning_opponent.get("name", "the table")),
		"player_category": player_category,
		"house_category": str(_copy_dict(winning_opponent.get("score", {})).get("category", "not_qualified")),
		"player_score": player_score,
		"house_score": _copy_dict(winning_opponent.get("score", {})),
		"winning_opponent_score": _copy_dict(winning_opponent.get("score", {})),
		"player_scoring_indices": _index_array(player_score.get("scoring_indices", [])),
		"house_scoring_indices": _index_array(_copy_dict(winning_opponent.get("score", {})).get("scoring_indices", [])),
		"player_blurb": _hand_blurb(player_score),
		"house_blurb": _hand_blurb(_copy_dict(winning_opponent.get("score", {}))),
		"outcome": outcome,
		"payout_mult": _payout_multiplier(player_category, state),
		"stake": adjusted_stake,
		"side_bet": 0,
		"participant_count": participants,
		"pot": pot,
		"rake": rake,
		"gross_payout": gross_payout,
		"carryover_pot": carryover_pot,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"loaded": action_id == "loaded_toss",
		"palmed": action_id == "palmed_swap",
		"loaded_value": int(table_result.get("loaded_value", 0)),
		"controlled_roll": controlled_roll if action_id == "loaded_toss" else {},
		"controlled_roll_grade": skill_grade if action_id == "loaded_toss" else "",
		"controlled_roll_margin_msec": skill_margin_msec if action_id == "loaded_toss" else 0,
		"patron_snitch_pressure": patron_snitch_pressure,
		"patron_snitch_heat_bonus": patron_snitch_heat_bonus,
		"match_legs": _copy_array(table_result.get("opponent_results", [])),
		"match_summary": _match_summary(table_result),
		"summary": summary,
		"press_offer": press_offer,
		"tumble_id": "settle_%d" % resolved_at,
		"resolved_at_msec": resolved_at,
		"tumble_indices": _all_die_indices(),
	}
	_update_environment_state(environment, state)

	var story_entry := {
		"type": "game_action",
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": "cheat" if is_cheat else "legal",
		"won": won,
		"outcome": outcome,
		"ruleset": "ship_captain_crew",
		"edge_tier": str(state.get("edge_tier", "standard")),
		"player_category": player_category,
		"player_cargo": int(player_score.get("cargo", 0)),
		"pot": pot,
		"rake": rake,
		"payout": gross_payout,
		"stake_cost": adjusted_stake,
		"bar_dice_stake": adjusted_stake,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"loaded": action_id == "loaded_toss",
		"palmed": action_id == "palmed_swap",
		"skill_outcome": skill_outcome,
		"skill_grade": skill_grade,
		"skill_accuracy": skill_accuracy,
		"skill_margin_msec": skill_margin_msec,
		"base_suspicion_delta": base_suspicion_delta,
		"controlled_roll": controlled_roll if action_id == "loaded_toss" else {},
		"patron_snitch_pressure": patron_snitch_pressure,
		"patron_snitch_heat_bonus": patron_snitch_heat_bonus,
		"pit_boss_watched": pit_boss_watched,
		"pit_boss_heat_bonus": pit_boss_heat_bonus,
		"pit_boss_summary": pit_boss_summary,
		"security_message": security_message,
		"skill_security_pressure_checked": is_cheat,
		"environment_id": environment.get("id", ""),
	}
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["suspicion_delta"] = suspicion_delta
	deltas["story_log"] = [story_entry]
	deltas["messages"] = [summary]
	deltas["ended"] = ended
	var payload := {
		"ok": true,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": "cheat" if is_cheat else "legal",
		"stake": adjusted_stake,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"deltas": deltas,
		"won": won,
		"environment_id": environment.get("id", ""),
		"environment_archetype_id": environment.get("archetype_id", ""),
		"message": summary,
		"pit_boss_watched": pit_boss_watched,
		"pit_boss_heat_bonus": pit_boss_heat_bonus,
		"skill_outcome": skill_outcome,
		"skill_security_pressure_checked": is_cheat,
		"security_message": security_message,
		"skill_story_context": {
			"game_id": get_id(),
			"action_id": action_id,
			"action_kind": "cheat" if is_cheat else "legal",
			"ruleset": "ship_captain_crew",
			"player_cargo": int(player_score.get("cargo", 0)),
			"skill_outcome": skill_outcome,
			"skill_grade": skill_grade,
			"skill_accuracy": skill_accuracy,
			"skill_margin_msec": skill_margin_msec,
			"suspicion_delta": suspicion_delta,
			"base_suspicion_delta": base_suspicion_delta,
			"bankroll_delta": bankroll_delta,
			"watched": pit_boss_watched,
			"pit_boss_heat_bonus": pit_boss_heat_bonus,
			"security_pressure_checked": is_cheat,
			"desired_face": int(controlled_roll.get("desired_face", 0)),
			"desired_die_index": int(controlled_roll.get("desired_die_index", -1)),
			"patron_snitch_pressure": patron_snitch_pressure,
			"patron_snitch_heat_bonus": patron_snitch_heat_bonus,
		},
	}
	var result := GameModule.build_action_result(payload)
	result["bar_dice_player_dice"] = _int_dice(table_result.get("player_dice", []))
	result["bar_dice_house_dice"] = _int_dice(winning_opponent.get("dice", []))
	result["bar_dice_player_category"] = player_category
	result["bar_dice_house_category"] = str(_copy_dict(winning_opponent.get("score", {})).get("category", "not_qualified"))
	result["bar_dice_outcome"] = outcome
	result["bar_dice_payout_mult"] = _payout_multiplier(player_category, state)
	result["bar_dice_loaded"] = action_id == "loaded_toss"
	result["bar_dice_palmed"] = action_id == "palmed_swap"
	result["bar_dice_loaded_value"] = int(table_result.get("loaded_value", 0))
	result["bar_dice_controlled_roll"] = controlled_roll if action_id == "loaded_toss" else {}
	result["bar_dice_controlled_roll_grade"] = skill_grade if action_id == "loaded_toss" else ""
	result["bar_dice_controlled_roll_accuracy"] = skill_accuracy if action_id == "loaded_toss" else 0
	result["bar_dice_controlled_roll_margin_msec"] = skill_margin_msec if action_id == "loaded_toss" else 0
	result["bar_dice_controlled_roll_applied"] = action_id == "loaded_toss" and _controlled_roll_applies(skill_grade)
	result["bar_dice_patron_snitch_pressure"] = patron_snitch_pressure
	result["bar_dice_patron_snitch_heat_bonus"] = patron_snitch_heat_bonus
	result["bar_dice_match_legs"] = _copy_array(table_result.get("opponent_results", []))
	result["bar_dice_player_legs"] = 1 if won else 0
	result["bar_dice_house_legs"] = 0 if won else 1
	result["bar_dice_stake"] = adjusted_stake
	result["bar_dice_side_bet"] = 0
	result["bar_dice_side_award"] = 0
	result["bar_dice_progressive_award"] = 0
	result["bar_dice_progressive_hit"] = false
	result["bar_dice_ruleset"] = "ship_captain_crew"
	result["bar_dice_edge_tier"] = str(state.get("edge_tier", "standard"))
	result["bar_dice_bonus_mode"] = "pot_rake"
	result["bar_dice_luck_bonus"] = luck_bonus
	result["bar_dice_pot"] = pot
	result["bar_dice_rake"] = rake
	result["bar_dice_carryover_pot"] = carryover_pot
	if is_cheat:
		result["bar_dice_pit_boss_watched"] = pit_boss_watched
		result["bar_dice_pit_boss_heat_bonus"] = pit_boss_heat_bonus
		result["skill_outcome"] = skill_outcome
		result["skill_grade"] = skill_grade
		result["skill_accuracy"] = skill_accuracy
		result["skill_margin_msec"] = skill_margin_msec
		result["base_suspicion_delta"] = base_suspicion_delta
		result["pit_boss_watched"] = pit_boss_watched
		result["pit_boss_heat_bonus"] = pit_boss_heat_bonus
		result["skill_security_pressure_checked"] = true
		result["skill_story_context"] = _copy_dict(payload.get("skill_story_context", {}))
		if not security_message.is_empty():
			result["security_message"] = security_message
		GameModule.normalize_skill_cheat_contract(result, result)
	GameModule.apply_result(run_state, result, rng)
	return result


func environment_object_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var state := _dice_state(run_state, environment)
	var last_result := _copy_dict(state.get("last_result", {}))
	var badge := "DICE"
	if not last_result.is_empty():
		badge = str(last_result.get("outcome", "dice")).to_upper().left(5)
	return {
		"runtime_state": {
			"rounds_played": int(state.get("rounds_played", 0)),
			"last_outcome": str(last_result.get("outcome", "")),
			"last_bankroll_delta": int(last_result.get("bankroll_delta", 0)),
			"carryover_pot": int(state.get("carryover_pot", 0)),
		},
		"visual_state": {
			"house": str(state.get("dealer_name", "Bartender")),
			"ruleset": str(state.get("ruleset_label", "Ship, Captain, Crew")),
			"bonus": "Pot carries on tied cargo.",
		},
		"status_summary": "%s runs Ship, Captain, Crew at the %s." % [str(state.get("dealer_name", "The bartender")), str(state.get("bar_name", "bar"))],
		"effect_summary": "High cargo wins the pot; ties carry forward.",
		"state_badge": badge,
	}


func _resolve_table_round(action_id: String, stake: int, run_state: RunState, state: Dictionary, rng: RngStream, ui_state: Dictionary) -> Dictionary:
	var player_dice := _player_final_dice(action_id, run_state, state, rng, ui_state)
	var loaded_value := int(_loaded_value_for_ruleset(player_dice, "ship_captain_crew")) if action_id == "loaded_toss" else 0
	var controlled_roll: Dictionary = {}
	if action_id == "loaded_toss":
		controlled_roll = _finalize_controlled_roll(ui_state, run_state, state)
		loaded_value = int(controlled_roll.get("desired_face", loaded_value))
		player_dice = _apply_controlled_roll(player_dice, controlled_roll)
	elif action_id == "palmed_swap":
		player_dice = _apply_palmed_swap(player_dice, "ship_captain_crew")
	var player_score := _score_ship(player_dice)
	var opponent_results := _opponent_results(state, rng)
	var seats: Array = [{
		"id": "player",
		"name": "You",
		"dice": player_dice,
		"score": player_score,
	}]
	seats.append_array(opponent_results)
	var winners := _winning_seats(seats)
	var player_is_winner := winners.size() == 1 and str(_copy_dict(winners[0]).get("id", "")) == "player"
	var player_top_tie := false
	for winner_value in winners:
		var winner: Dictionary = winner_value
		if str(winner.get("id", "")) == "player":
			player_top_tie = winners.size() > 1
	var pot := _working_pot(stake, state)
	var rake := _rake_for_pot(pot, state)
	var outcome := "lose"
	var gross_payout := 0
	var carryover := 0
	if winners.is_empty():
		outcome = "carry"
		carryover = pot
	elif player_is_winner:
		outcome = "win"
		gross_payout = _gross_payout_for_pot(pot, rake, state)
	elif player_top_tie:
		outcome = "carry"
		carryover = pot
	elif winners.size() > 1:
		outcome = "carry"
		carryover = pot
	var winning_opponent := _best_non_player_seat(winners, opponent_results)
	return {
		"outcome": outcome,
		"player_dice": player_dice,
		"player_score": player_score,
		"opponent_results": opponent_results,
		"winning_opponent": winning_opponent,
		"winners": winners,
		"participant_count": _participant_count(state),
		"stake": stake,
		"pot": pot,
		"rake": rake,
		"gross_payout": gross_payout,
		"carryover_pot": carryover,
		"loaded_value": loaded_value,
		"controlled_roll": controlled_roll,
	}


func _player_final_dice(_action_id: String, run_state: RunState, state: Dictionary, rng: RngStream, ui_state: Dictionary) -> Array:
	if bool(ui_state.get("rolled", false)):
		var dice := _int_dice(ui_state.get("dice", []))
		if dice.size() == DICE_COUNT:
			return dice
	var hand := _roll_dice(rng, DICE_COUNT)
	for _shake in range(MAX_SHAKES - 1):
		var marks := _suggested_reroll_for_ruleset(hand, "ship_captain_crew")
		if marks.is_empty():
			break
		for index_value in marks:
			hand[int(index_value)] = rng.randi_range(1, DIE_FACES)
	return hand


func _opponent_results(state: Dictionary, rng: RngStream) -> Array:
	var result: Array = []
	var patrons: Array = state.get("patrons", []) if typeof(state.get("patrons", [])) == TYPE_ARRAY else []
	for i in range(patrons.size()):
		if typeof(patrons[i]) != TYPE_DICTIONARY:
			continue
		var patron: Dictionary = patrons[i]
		var dice := _auto_play_ship_hand(rng)
		result.append({
			"id": str(patron.get("id", "patron_%d" % i)),
			"name": str(patron.get("name", "Patron")),
			"personality": str(patron.get("personality", "")),
			"banter": _patron_banter_line(patron, i + int(state.get("rounds_played", 0)), "roll"),
			"dice": dice,
			"score": _score_ship(dice),
			"seat": i,
			"turn_order": i,
			"turn_wait_msec": 0,
		})
	var house_dice := _auto_play_ship_hand(rng)
	result.append({
		"id": "house",
		"name": str(state.get("dealer_name", "House")),
		"personality": "House caller",
		"banter": "Dealer calls the cargo.",
		"dice": house_dice,
		"score": _score_ship(house_dice),
		"seat": patrons.size(),
		"turn_order": patrons.size(),
		"turn_wait_msec": 0,
	})
	return result


func _auto_play_ship_hand(rng: RngStream) -> Array:
	var hand := _roll_dice(rng, DICE_COUNT)
	for _shake in range(MAX_SHAKES - 1):
		var marks := _suggested_reroll_for_ruleset(hand, "ship_captain_crew")
		if marks.is_empty():
			break
		for index_value in marks:
			hand[int(index_value)] = rng.randi_range(1, DIE_FACES)
	return hand


func _winning_seats(seats: Array) -> Array:
	var best_signature: Array = []
	var winners: Array = []
	for seat_value in seats:
		var seat: Dictionary = seat_value
		var score := _copy_dict(seat.get("score", {}))
		if not bool(score.get("qualified", false)):
			continue
		var signature := _index_array_raw(score.get("signature", []))
		if best_signature.is_empty() or _compare_signatures(signature, best_signature) > 0:
			best_signature = signature
			winners = [seat]
		elif _compare_signatures(signature, best_signature) == 0:
			winners.append(seat)
	return winners


func _best_non_player_seat(winners: Array, opponents: Array) -> Dictionary:
	for winner_value in winners:
		var winner: Dictionary = winner_value
		if str(winner.get("id", "")) != "player":
			return winner
	var best: Dictionary = {}
	for opponent_value in opponents:
		var opponent: Dictionary = opponent_value
		if best.is_empty() or _compare_signatures(_copy_dict(opponent.get("score", {})).get("signature", []), _copy_dict(best.get("score", {})).get("signature", [])) > 0:
			best = opponent
	return best


func _luck_lift_to_win(table_result: Dictionary, stake: int, state: Dictionary) -> Dictionary:
	var updated := table_result.duplicate(true)
	var player_dice := [6, 5, 4, 6, 6]
	var player_score := _score_ship(player_dice)
	var pot := int(updated.get("pot", _working_pot(stake, state)))
	var rake := _rake_for_pot(pot, state)
	updated["outcome"] = "win"
	updated["player_dice"] = player_dice
	updated["player_score"] = player_score
	updated["gross_payout"] = _gross_payout_for_pot(pot, rake, state)
	updated["carryover_pot"] = 0
	updated["luck_lift"] = true
	return updated


func _resolve_press(stake: int, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var state := _dice_state(run_state, environment)
	var last_result := _copy_dict(state.get("last_result", {}))
	var offer := _copy_dict(last_result.get("press_offer", {}))
	if not bool(offer.get("available", false)):
		return _empty_result("press", stake, environment, "No clean bar dice win is available to press.")
	var risk := mini(maxi(1, int(offer.get("risk", 0))), maxi(0, run_state.bankroll))
	if risk <= 0:
		return _empty_result("press", stake, environment, "You do not have enough chips to press.")
	var level := int(offer.get("level", 0))
	var chance := clampi(46 + run_state.luck_win_chance_bonus() + _item_effect_total("win_chance", run_state), 5, 85)
	var press_won := rng.randi_range(1, 100) <= chance
	var bankroll_delta := risk if press_won else -risk
	var next_offer := {}
	if press_won and level + 1 < int(offer.get("cap", PRESS_CAP)):
		next_offer = {
			"available": true,
			"risk": mini(risk * 2, maxi(1, int(last_result.get("stake", risk)) * 12)),
			"level": level + 1,
			"cap": int(offer.get("cap", PRESS_CAP)),
		}
	last_result["press_offer"] = next_offer
	last_result["press_result"] = "win" if press_won else "lose"
	last_result["bankroll_delta"] = int(last_result.get("bankroll_delta", 0)) + bankroll_delta
	last_result["summary"] = "Pressed the cargo win: %s %+d." % ["hit" if press_won else "miss", bankroll_delta]
	state["last_result"] = last_result
	_update_environment_state(environment, state)
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["messages"] = [str(last_result.get("summary", ""))]
	deltas["story_log"] = [{
		"type": "game_action",
		"game_id": get_id(),
		"action_id": "press",
		"won": press_won,
		"risk": risk,
		"bankroll_delta": bankroll_delta,
		"environment_id": environment.get("id", ""),
	}]
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": "press",
		"action_kind": "legal",
		"stake": risk,
		"bankroll_delta": bankroll_delta,
		"deltas": deltas,
		"won": press_won,
		"environment_id": environment.get("id", ""),
		"environment_archetype_id": environment.get("archetype_id", ""),
		"message": str(last_result.get("summary", "")),
	})
	result["bar_dice_press"] = true
	result["bar_dice_press_won"] = press_won
	result["bar_dice_press_risk"] = risk
	GameModule.apply_result(run_state, result, rng)
	return result


func _cheat_heat(action_id: String, adjusted_stake: int, run_state: RunState, environment: Dictionary, controlled_roll: Dictionary = {}) -> Dictionary:
	var cheat_def := _action_def(action_id)
	var base_heat := int(cheat_def.get("suspicion_delta", 10))
	var grade := ""
	var patron_pressure := 0
	var patron_heat_bonus := 0
	if action_id == "loaded_toss":
		base_heat = int(controlled_roll.get("base_heat", _controlled_roll_base_heat(run_state)))
		grade = str(controlled_roll.get("skill_grade", "miss"))
		patron_pressure = int(controlled_roll.get("patron_snitch_pressure", 0))
		patron_heat_bonus = _patron_snitch_heat_bonus(patron_pressure, grade)
	var pit_boss_status := run_state.pit_boss_watch_status(environment)
	var pit_boss_bonus := int(pit_boss_status.get("cheat_heat_bonus", 0)) if bool(pit_boss_status.get("active", false)) else 0
	var base_suspicion_delta := maxi(1, base_heat + _item_effect_total("cheat_suspicion_delta", run_state) + _controlled_roll_grade_heat_modifier(grade) + patron_heat_bonus)
	var raw_heat := maxi(1, base_suspicion_delta + run_state.security_risk_bonus("cheat") + pit_boss_bonus)
	var suspicion_delta := run_state.alcohol_adjusted_suspicion_delta(raw_heat)
	var security_pressure := run_state.security_action_pressure("cheat", adjusted_stake, run_state.suspicion_level() + suspicion_delta)
	return {
		"suspicion_delta": suspicion_delta,
		"base_suspicion_delta": base_suspicion_delta,
		"bankroll_delta": int(security_pressure.get("bankroll_delta", 0)),
		"security_message": str(security_pressure.get("message", "")),
		"pit_boss_summary": str(pit_boss_status.get("summary", "")) if bool(pit_boss_status.get("active", false)) else "",
		"pit_boss_watched": bool(pit_boss_status.get("watched", false)),
		"pit_boss_heat_bonus": pit_boss_bonus,
		"patron_snitch_pressure": patron_pressure,
		"patron_snitch_heat_bonus": patron_heat_bonus,
		"ended": bool(security_pressure.get("ended", false)),
	}


func _dice_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var state: Dictionary = game_states.get(get_id(), {}) if typeof(game_states.get(get_id(), {})) == TYPE_DICTIONARY else {}
	if state.is_empty():
		state = _fallback_state(run_state, environment)
		game_states[get_id()] = state
		environment["game_states"] = game_states
		return state
	if _state_is_current(state):
		return state
	var normalized := _normalize_state(state)
	game_states[get_id()] = normalized
	environment["game_states"] = game_states
	return normalized


func _fallback_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var rng := RngStream.new()
	rng.configure(_stable_hash("%s:%s:%s" % [get_id(), str(run_state.seed_text if run_state != null else "fallback"), str(environment.get("id", ""))]))
	return generate_environment_state(run_state, environment, rng)


func _normalize_state(state: Dictionary) -> Dictionary:
	var normalized := state.duplicate(true)
	normalized["schema"] = STATE_SCHEMA
	normalized["version"] = STATE_VERSION
	normalized["ruleset_family"] = "ship_captain_crew"
	normalized["ruleset_label"] = str(normalized.get("ruleset_label", RULESET_LABEL.get("ship_captain_crew", "Ship, Captain, Crew")))
	normalized["available_variants"] = _copy_array(normalized.get("available_variants", VARIATION_LIBRARY.duplicate(true)))
	normalized["bonus_mode"] = "pot_rake"
	normalized["bonus_label"] = str(normalized.get("bonus_label", "Carryover Pot"))
	var tier := str(normalized.get("edge_tier", "standard"))
	if not EDGE_TIER_ORDER.has(tier):
		tier = "standard"
	normalized["edge_tier"] = tier
	normalized["edge_label"] = str(normalized.get("edge_label", EDGE_TIER_LABEL.get(tier, "House Bar Rake")))
	normalized["rake_percent"] = clampi(int(normalized.get("rake_percent", EDGE_RAKE_PERCENT.get(tier, 7))), 0, 25)
	normalized["hosted_payout_percent"] = clampi(int(normalized.get("hosted_payout_percent", EDGE_PAYOUT_PERCENT.get(tier, 66))), 30, 100)
	normalized["dealer_name"] = str(normalized.get("dealer_name", "Bartender"))
	normalized["bar_name"] = str(normalized.get("bar_name", "bar top"))
	normalized["table_key"] = str(normalized.get("table_key", "%s:%s" % [normalized["dealer_name"], normalized["bar_name"]]))
	normalized["dealer_profile"] = _normalize_dealer_profile(normalized.get("dealer_profile", {}), normalized)
	var ladder := _int_array(normalized.get("stake_ladder", []))
	if ladder.is_empty():
		ladder = [2, 5, 10, 20, 40]
	ladder.sort()
	normalized["stake_ladder"] = ladder
	normalized["selected_stake_index"] = clampi(int(normalized.get("selected_stake_index", 0)), 0, maxi(0, ladder.size() - 1))
	normalized["patrons"] = _normalize_patrons(normalized.get("patrons", []))
	normalized["rail_bettors"] = normalized["patrons"]
	normalized["carryover_pot"] = maxi(0, int(normalized.get("carryover_pot", 0)))
	normalized["loaded_die"] = clampi(int(normalized.get("loaded_die", 0)), 0, DIE_FACES)
	normalized["rounds_played"] = maxi(0, int(normalized.get("rounds_played", 0)))
	normalized["last_result"] = _copy_dict(normalized.get("last_result", {}))
	normalized["table_round_timer_started_msec"] = int(normalized.get("table_round_timer_started_msec", 0))
	normalized["normalized_version"] = STATE_VERSION
	return normalized


func _state_is_current(state: Dictionary) -> bool:
	return str(state.get("schema", "")) == STATE_SCHEMA and int(state.get("version", 0)) == STATE_VERSION and int(state.get("normalized_version", 0)) == STATE_VERSION


func _update_environment_state(environment: Dictionary, state: Dictionary) -> void:
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	state["normalized_version"] = STATE_VERSION
	game_states[get_id()] = state if _state_is_current(state) else _normalize_state(state)
	environment["game_states"] = game_states


func _normalized_ui_state(run_state: RunState, _environment: Dictionary, ui_state: Dictionary, state: Dictionary) -> Dictionary:
	var next := ui_state.duplicate(true)
	next["rolled"] = bool(next.get("rolled", false))
	var ladder := _int_array(state.get("stake_ladder", []))
	next["selected_stake_index"] = clampi(int(next.get("selected_stake_index", state.get("selected_stake_index", 0))), 0, maxi(0, ladder.size() - 1))
	if bool(next["rolled"]):
		var dice := _int_dice(next.get("dice", []))
		if dice.size() != DICE_COUNT:
			dice = _generate_opening(run_state, state)
		next["dice"] = dice
		next["shake_number"] = clampi(int(next.get("shake_number", 1)), 1, MAX_SHAKES)
		next["reroll"] = _index_array(next.get("reroll", []))
		next["last_rerolled"] = _index_array(next.get("last_rerolled", []))
		next["tumble_indices"] = _index_array(next.get("tumble_indices", []))
	else:
		next["reroll"] = []
		next["shake_number"] = 0
		next["last_rerolled"] = []
		next["tumble_indices"] = []
	next["loaded_armed"] = bool(next.get("loaded_armed", false))
	next["palm_armed"] = bool(next.get("palm_armed", false))
	var controlled_roll: Dictionary = _normalized_controlled_roll(next.get("controlled_roll", {}))
	if controlled_roll.is_empty() or not bool(next.get("rolled", false)) or not bool(next.get("loaded_armed", false)):
		next.erase("controlled_roll")
	elif bool(next.get("loaded_armed", false)):
		next["controlled_roll"] = controlled_roll
	return next


func _normalized_controlled_roll(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = (value as Dictionary).duplicate(true)
	var challenge_id := str(source.get("challenge_id", "")).strip_edges()
	if challenge_id.is_empty():
		return {}
	var started := maxi(0, int(source.get("meter_started_msec", 0)))
	var period := maxi(300, int(source.get("meter_period_msec", CONTROLLED_ROLL_METER_PERIOD_MSEC)))
	var windows := GameModule.normalize_skill_timing_windows(
		int(source.get("perfect_window_msec", CONTROLLED_ROLL_PERFECT_WINDOW_MSEC)),
		int(source.get("good_window_msec", CONTROLLED_ROLL_GOOD_WINDOW_MSEC)),
		int(source.get("close_window_msec", CONTROLLED_ROLL_CLOSE_WINDOW_MSEC)),
		20
	)
	var normalized := {
		"challenge_id": challenge_id,
		"desired_face": clampi(int(source.get("desired_face", 6)), 1, DIE_FACES),
		"desired_die_index": clampi(int(source.get("desired_die_index", -1)), -1, DICE_COUNT - 1),
		"dice_before": _int_dice(source.get("dice_before", [])),
		"meter_started_msec": started,
		"meter_period_msec": period,
		"target_msec": maxi(started, int(source.get("target_msec", started))),
		"perfect_window_msec": int(windows.get("perfect_window_msec", CONTROLLED_ROLL_PERFECT_WINDOW_MSEC)),
		"good_window_msec": int(windows.get("good_window_msec", CONTROLLED_ROLL_GOOD_WINDOW_MSEC)),
		"close_window_msec": int(windows.get("close_window_msec", CONTROLLED_ROLL_CLOSE_WINDOW_MSEC)),
		"base_heat": maxi(1, int(source.get("base_heat", CONTROLLED_ROLL_BASE_HEAT))),
		"patron_snitch_pressure": maxi(0, int(source.get("patron_snitch_pressure", 0))),
		"patron_watch_count": maxi(0, int(source.get("patron_watch_count", 0))),
		"item_modifiers": _copy_array(source.get("item_modifiers", [])),
	}
	if source.has("input_msec"):
		normalized["input_msec"] = maxi(0, int(source.get("input_msec", 0)))
	normalized["skill_margin_msec"] = int(source.get("skill_margin_msec", 0))
	normalized["face_result"] = clampi(int(source.get("face_result", 0)), 0, DIE_FACES)
	var grade := str(source.get("skill_grade", ""))
	if ["perfect", "good", "partial", "miss", "blown"].has(grade):
		normalized["skill_grade"] = grade
	if source.has("skill_accuracy"):
		normalized["skill_accuracy"] = clampi(int(source.get("skill_accuracy", 0)), 0, 100)
	return normalized


func _surface_time_msec(ui_state: Dictionary) -> int:
	if ui_state.has("surface_time_msec"):
		return maxi(0, int(ui_state.get("surface_time_msec", 0)))
	return Time.get_ticks_msec()


func _controlled_roll_windows(run_state: RunState) -> Dictionary:
	var perfect := CONTROLLED_ROLL_PERFECT_WINDOW_MSEC + _item_effect_total("bar_dice_controlled_roll_perfect_msec", run_state)
	var good := CONTROLLED_ROLL_GOOD_WINDOW_MSEC + _item_effect_total("bar_dice_controlled_roll_good_msec", run_state)
	var close := CONTROLLED_ROLL_CLOSE_WINDOW_MSEC + _item_effect_total("bar_dice_controlled_roll_close_msec", run_state)
	var period := CONTROLLED_ROLL_METER_PERIOD_MSEC + _item_effect_total("bar_dice_controlled_roll_meter_period_msec", run_state)
	var impairment := clampi(int(run_state.drunk_level / 4), 0, 30) if run_state != null else 0
	impairment = maxi(0, impairment - _item_effect_total("skill_cheat_drunk_window_offset_msec", run_state))
	perfect = maxi(36, perfect - impairment)
	good = maxi(perfect + 48, good - impairment * 2)
	close = maxi(good + 48, close - impairment * 3)
	return {
		"perfect": perfect,
		"good": good,
		"close": close,
		"period": maxi(600, period),
	}


func _controlled_roll_base_heat(run_state: RunState) -> int:
	var action := _action_def("loaded_toss")
	var base := int(action.get("suspicion_delta", CONTROLLED_ROLL_BASE_HEAT))
	base += _item_effect_total("bar_dice_controlled_roll_base_heat", run_state)
	return maxi(1, base)


func _start_controlled_roll(ui_state: Dictionary, run_state: RunState, state: Dictionary) -> Dictionary:
	var dice := _int_dice(ui_state.get("dice", []))
	if dice.size() != DICE_COUNT:
		dice = _generate_opening(run_state, state)
	var target := _controlled_roll_target(dice)
	var desired_face := int(target.get("face", _loaded_value_for_ruleset(dice, "ship_captain_crew")))
	var desired_index := int(target.get("index", -1))
	var now_msec := _surface_time_msec(ui_state)
	var windows := _controlled_roll_windows(run_state)
	var period := int(windows.get("period", CONTROLLED_ROLL_METER_PERIOD_MSEC))
	var target_phase := int(round((float(desired_face) - 0.5) * float(period) / float(DIE_FACES)))
	var seed := "%s:%s:%d:%s:%d" % [
		str(state.get("table_key", "")),
		str(run_state.seed_text if run_state != null else ""),
		int(state.get("rounds_played", 0)),
		JSON.stringify(dice),
		int(ui_state.get("shake_number", 1)),
	]
	var started := now_msec - int(_stable_hash(seed) % period)
	var watch_info := _patron_watch_info(state)
	return {
		"challenge_id": "bar_control_%d" % _stable_hash(seed),
		"desired_face": desired_face,
		"desired_die_index": desired_index,
		"dice_before": dice.duplicate(),
		"meter_started_msec": started,
		"meter_period_msec": period,
		"target_msec": started + target_phase,
		"perfect_window_msec": int(windows.get("perfect", CONTROLLED_ROLL_PERFECT_WINDOW_MSEC)),
		"good_window_msec": int(windows.get("good", CONTROLLED_ROLL_GOOD_WINDOW_MSEC)),
		"close_window_msec": int(windows.get("close", CONTROLLED_ROLL_CLOSE_WINDOW_MSEC)),
		"base_heat": _controlled_roll_base_heat(run_state),
		"patron_snitch_pressure": int(watch_info.get("pressure", 0)),
		"patron_watch_count": int(watch_info.get("watch_count", 0)),
		"item_modifiers": skill_item_modifier_badges(run_state, CONTROLLED_ROLL_ITEM_EFFECT_KEYS),
	}


func _controlled_roll_target(dice: Array) -> Dictionary:
	var locks := _ship_lock_indices(dice)
	var face := _loaded_value_for_ruleset(dice, "ship_captain_crew")
	for i in range(dice.size()):
		if not locks.has(i):
			return {"index": i, "face": face}
	return {"index": 0, "face": face}


func _grade_controlled_roll(challenge: Dictionary) -> Dictionary:
	var graded := _normalized_controlled_roll(challenge)
	if graded.is_empty():
		return {}
	if not graded.has("input_msec") or int(graded.get("input_msec", 0)) <= 0:
		graded["skill_grade"] = "miss"
		graded["skill_margin_msec"] = 0
		graded["skill_accuracy"] = 0
		graded["face_result"] = 0
		return graded
	var period := maxi(1, int(graded.get("meter_period_msec", CONTROLLED_ROLL_METER_PERIOD_MSEC)))
	var input_phase := (int(graded.get("input_msec", 0)) - int(graded.get("meter_started_msec", 0))) % period
	if input_phase < 0:
		input_phase += period
	var target_phase := (int(graded.get("target_msec", 0)) - int(graded.get("meter_started_msec", 0))) % period
	if target_phase < 0:
		target_phase += period
	var margin := _circular_meter_margin(input_phase, target_phase, period)
	var distance := absi(margin)
	var timing := GameModule.skill_timing_grade_from_distance(
		distance,
		int(graded.get("perfect_window_msec", CONTROLLED_ROLL_PERFECT_WINDOW_MSEC)),
		int(graded.get("good_window_msec", CONTROLLED_ROLL_GOOD_WINDOW_MSEC)),
		int(graded.get("close_window_msec", CONTROLLED_ROLL_CLOSE_WINDOW_MSEC)),
		20
	)
	var grade := str(timing.get("skill_grade", "blown"))
	graded["skill_grade"] = grade
	graded["skill_margin_msec"] = margin
	graded["skill_accuracy"] = clampi(int(timing.get("skill_accuracy", 0)), 0, 100)
	graded["face_result"] = int(graded.get("desired_face", 6)) if grade != "blown" else 0
	return graded


func _circular_meter_margin(input_phase: int, target_phase: int, period: int) -> int:
	var margin := input_phase - target_phase
	var half_period := int(period / 2)
	if margin > half_period:
		margin -= period
	elif margin < -half_period:
		margin += period
	return margin


func _finalize_controlled_roll(ui_state: Dictionary, run_state: RunState, state: Dictionary) -> Dictionary:
	var challenge := _normalized_controlled_roll(ui_state.get("controlled_roll", {}))
	if challenge.is_empty():
		challenge = _start_controlled_roll(ui_state, run_state, state)
	if ui_state.has("controlled_roll_input_msec") and not challenge.has("input_msec"):
		challenge["input_msec"] = maxi(0, int(ui_state.get("controlled_roll_input_msec", 0)))
	return _grade_controlled_roll(challenge)


func _controlled_roll_applies(grade: String) -> bool:
	return GameModule.skill_grade_applies(grade)


func _controlled_roll_grade_heat_modifier(grade: String) -> int:
	match grade:
		"perfect":
			return -CONTROLLED_ROLL_PERFECT_HEAT_REDUCTION
		"partial":
			return CONTROLLED_ROLL_PARTIAL_HEAT_BONUS
		"miss":
			return CONTROLLED_ROLL_MISS_HEAT_BONUS
		"blown":
			return CONTROLLED_ROLL_BLOWN_HEAT_BONUS
	return 0


func _controlled_roll_skill_outcome(grade: String) -> String:
	return GameModule.skill_outcome_for_grade("controlled_roll", grade)


func _controlled_roll_meter(challenge: Dictionary, ui_state: Dictionary) -> Dictionary:
	var now_msec := _surface_time_msec(ui_state)
	var started := int(challenge.get("meter_started_msec", now_msec))
	var period := maxi(1, int(challenge.get("meter_period_msec", CONTROLLED_ROLL_METER_PERIOD_MSEC)))
	var phase := (now_msec - started) % period
	if phase < 0:
		phase += period
	var target := (int(challenge.get("target_msec", started)) - started) % period
	if target < 0:
		target += period
	var input_progress := -1.0
	if challenge.has("input_msec"):
		var input_phase := (int(challenge.get("input_msec", 0)) - started) % period
		if input_phase < 0:
			input_phase += period
		input_progress = float(input_phase) / float(period)
	return {
		"active": true,
		"progress": float(phase) / float(period),
		"target": float(target) / float(period),
		"input": input_progress,
		"desired_face": int(challenge.get("desired_face", 0)),
		"skill_grade": str(challenge.get("skill_grade", "")),
	}


func _patron_watch_info(state: Dictionary) -> Dictionary:
	var pressure := 0
	var watch_count := 0
	var patrons: Array = state.get("patrons", []) if typeof(state.get("patrons", [])) == TYPE_ARRAY else []
	for patron_value in patrons:
		if typeof(patron_value) != TYPE_DICTIONARY:
			continue
		var patron: Dictionary = patron_value
		if bool(patron.get("watching", true)):
			watch_count += 1
			pressure += int(patron.get("snitch_risk", 0)) + 8
	return {
		"pressure": pressure,
		"watch_count": watch_count,
	}


func _patron_snitch_heat_bonus(pressure: int, grade: String) -> int:
	var bonus := int(ceil(float(maxi(0, pressure)) / 34.0))
	if grade == "blown":
		bonus += 4
	elif grade == "miss":
		bonus += 2
	return bonus


func _generated_stake_ladder(environment: Dictionary, rng: RngStream) -> Array:
	var economic_profile: Dictionary = environment.get("economic_profile", {}) if typeof(environment.get("economic_profile", {})) == TYPE_DICTIONARY else {}
	var floor := maxi(1, int(economic_profile.get("stake_floor", 2)))
	var ceiling := maxi(floor, int(economic_profile.get("stake_ceiling", 80)))
	var templates := [
		[2, 5, 10, 20, 40],
		[5, 10, 20, 40, 80],
		[1, 2, 5, 10, 25],
	]
	var source: Array = rng.pick(templates, templates[0])
	var ladder: Array = []
	for chip_value in source:
		var chip := clampi(int(chip_value), floor, ceiling)
		if not ladder.has(chip):
			ladder.append(chip)
	if ladder.is_empty():
		ladder = [floor]
	ladder.sort()
	return ladder


func _generate_dealer_profile(rng: RngStream, dealer_name: String, tier: String) -> Dictionary:
	return {
		"name": dealer_name,
		"role": "bar_dice_caller",
		"style": "bar",
		"attention_base": 16 if tier == "friendly" else 24 if tier == "standard" else 32,
		"tell": str(rng.pick(["watches the cup lip", "counts locked dice", "checks hands after shakes"], "watches the cup lip")),
		"read_style": "bar sweep",
		"uniform_accent": "bar towel",
		"gaze_speed": rng.randi_range(80, 130),
		"blink_offset": rng.randi_range(0, 1800),
		"accent": _color_name(str(rng.pick(["cyan", "teal", "yellow", "pink"], "teal"))),
	}


func _normalize_dealer_profile(value: Variant, state: Dictionary) -> Dictionary:
	var dealer := _copy_dict(value)
	if dealer.is_empty():
		var rng := RngStream.new()
		rng.configure(_stable_hash("%s:dealer" % str(state.get("table_key", "bar"))))
		dealer = _generate_dealer_profile(rng, str(state.get("dealer_name", "Bartender")), str(state.get("edge_tier", "standard")))
	dealer["name"] = str(dealer.get("name", state.get("dealer_name", "Bartender")))
	dealer["role"] = str(dealer.get("role", "bar_dice_caller"))
	dealer["attention_base"] = clampi(int(dealer.get("attention_base", 24)), 6, 70)
	dealer["tell"] = str(dealer.get("tell", "tracks the cup"))
	dealer["read_style"] = str(dealer.get("read_style", "bar sweep"))
	dealer["uniform_accent"] = str(dealer.get("uniform_accent", "bar towel"))
	dealer["gaze_speed"] = clampi(int(dealer.get("gaze_speed", 95)), 45, 180)
	dealer["blink_offset"] = maxi(0, int(dealer.get("blink_offset", 0)))
	if not dealer.has("accent"):
		dealer["accent"] = _color_name("teal")
	return dealer


func _generate_patrons(rng: RngStream, depth: int) -> Array:
	var names := ["Tess", "Milo", "June", "Vale", "Rin", "Cole", "Iris", "Sol"]
	var tells := ["calls cargo", "leans on rail", "guards chips", "watches cup", "taps glass"]
	var result: Array = []
	var count := clampi(2 + depth % 3, 2, 4)
	result.append(MEMORABLE_REGULAR.duplicate(true))
	for i in range(maxi(0, count - 1)):
		var mood := str(rng.pick(["loose", "watchful", "loud", "quiet"], "loose"))
		var tell := str(rng.pick(tells, tells[0]))
		var temper := str(rng.pick(["nosy", "careless", "loyal", "sharp"], "careless"))
		result.append({
			"id": "bar_patron_%d" % (i + 1),
			"name": str(rng.pick(names, names[0])),
			"seat": i + 1,
			"mood": mood,
			"personality": _generated_patron_personality(mood, tell, temper),
			"preferred_bet": "cargo",
			"cosmetic_bet": int(rng.pick([5, 10, 20, 25, 40], 10)),
			"rapport": rng.randi_range(42, 62),
			"snitch_risk": rng.randi_range(6, 34),
			"chip_stack": rng.randi_range(20, 120),
			"chip_color": str(rng.pick(["cyan", "teal", "yellow", "pink", "orange"], "cyan")),
			"watching": rng.randi_range(0, 100) >= 42,
			"silhouette": str(rng.pick(["cap", "glasses", "coat", "rings"], "cap")),
			"tell": tell,
			"temper": temper,
			"seat_style": str(rng.pick(["vest", "jacket", "open"], "open")),
			"animation_offset": rng.randi_range(0, 3600),
			"snitch_threshold": rng.randi_range(18, 52),
			"last_reaction": "neutral",
			"banter_lines": _generated_patron_banter(mood, tell, temper),
			"accent": _color_name(str(rng.pick(["cyan", "teal", "yellow", "pink", "orange"], "cyan"))),
		})
	return result


func _generated_patron_personality(mood: String, tell: String, temper: String) -> String:
	return "%s rail player; %s, %s when the pot grows." % [mood.capitalize(), tell, temper]


func _generated_patron_banter(mood: String, tell: String, temper: String) -> Array:
	return [
		"%s says ride the cargo." % mood.capitalize(),
		"%s, then count cargo." % tell.capitalize(),
		"%s eyes on the cup." % temper.capitalize(),
	]


func _normalize_patrons(value: Variant) -> Array:
	var patrons := _dictionary_array(value)
	if patrons.is_empty():
		var rng := RngStream.new()
		rng.configure(_stable_hash("bar_dice:patrons:fallback"))
		return _generate_patrons(rng, 2)
	for i in range(patrons.size()):
		var patron: Dictionary = patrons[i]
		patron["id"] = str(patron.get("id", "bar_patron_%d" % i))
		patron["name"] = str(patron.get("name", "Rail %d" % (i + 1)))
		patron["seat"] = int(patron.get("seat", i))
		patron["mood"] = str(patron.get("mood", "loose"))
		patron["personality"] = str(patron.get("personality", _generated_patron_personality(str(patron.get("mood", "loose")), str(patron.get("tell", "calls cargo")), str(patron.get("temper", "careless")))))
		patron["preferred_bet"] = str(patron.get("preferred_bet", "cargo"))
		patron["cosmetic_bet"] = maxi(1, int(patron.get("cosmetic_bet", 10)))
		patron["rapport"] = clampi(int(patron.get("rapport", 50)), 0, 100)
		patron["snitch_risk"] = clampi(int(patron.get("snitch_risk", 18)), 0, 60)
		patron["chip_stack"] = maxi(0, int(patron.get("chip_stack", int(patron.get("cosmetic_bet", 10)))))
		patron["chip_color"] = str(patron.get("chip_color", "cyan"))
		patron["watching"] = bool(patron.get("watching", true))
		patron["silhouette"] = str(patron.get("silhouette", "cap"))
		patron["tell"] = str(patron.get("tell", "calls cargo"))
		patron["temper"] = str(patron.get("temper", "careless"))
		patron["seat_style"] = str(patron.get("seat_style", "open"))
		patron["animation_offset"] = maxi(0, int(patron.get("animation_offset", i * 620)))
		patron["snitch_threshold"] = clampi(int(patron.get("snitch_threshold", 30)), 4, 70)
		var banter_lines := _string_array(patron.get("banter_lines", []))
		if banter_lines.size() < 2:
			banter_lines = _generated_patron_banter(str(patron.get("mood", "loose")), str(patron.get("tell", "calls cargo")), str(patron.get("temper", "careless")))
		patron["banter_lines"] = banter_lines
		if not patron.has("accent"):
			patron["accent"] = _color_name("cyan")
		patrons[i] = patron
	return patrons


func _patrons_for_surface(state: Dictionary, last_result: Dictionary, active_stake: int) -> Array:
	var patrons := _normalize_patrons(state.get("patrons", []))
	var winner_name := str(last_result.get("winning_opponent_name", ""))
	var outcome := str(last_result.get("outcome", ""))
	for i in range(patrons.size()):
		var patron: Dictionary = patrons[i]
		var watching := bool(patron.get("watching", true))
		patron["watching_player"] = watching
		patron["active_snitch_risk"] = int(patron.get("snitch_risk", 0)) + (8 if watching else 0)
		patron["visible_bet"] = {
			"id": "cargo",
			"label": "CARGO",
			"stake": active_stake,
		}
		patron["wager"] = patron["visible_bet"]
		if winner_name == str(patron.get("name", "")):
			patron["last_reaction"] = "won"
			patron["behavior"] = "took pot"
			patron["banter"] = _patron_banter_line(patron, i + active_stake, "win")
		elif outcome == "win":
			patron["last_reaction"] = "lost"
			patron["behavior"] = "pays up"
			patron["banter"] = _patron_banter_line(patron, i + active_stake, "lose")
		elif outcome == "carry":
			patron["last_reaction"] = "push"
			patron["behavior"] = "pot rides"
			patron["banter"] = _patron_banter_line(patron, i + active_stake, "carry")
		else:
			patron["banter"] = _patron_banter_line(patron, i + active_stake, "")
			patron["behavior"] = str(patron.get("banter", patron.get("mood", "loose"))).left(12)
		patrons[i] = patron
	return patrons


func _patron_bet_command(index: int, ui_state: Dictionary, state: Dictionary, _run_state: RunState, _environment: Dictionary) -> Dictionary:
	var fade := index >= 100
	var patron_index := index % 100
	var patrons := _normalize_patrons(state.get("patrons", []))
	if patron_index < 0 or patron_index >= patrons.size():
		return _message_command(ui_state, "That rail player stepped away.")
	var patron: Dictionary = patrons[patron_index]
	ui_state["table_social_alignment"] = {
		"game": "bar_dice",
		"patron_id": str(patron.get("id", "bar_patron_%d" % patron_index)),
		"patron_name": str(patron.get("name", "Rail")),
		"stance": "against" if fade else "with",
		"style": "cargo",
	}
	var delta := -2 if fade else 3
	patron["rapport"] = clampi(int(patron.get("rapport", 50)) + delta, 0, 100)
	patrons[patron_index] = patron
	state["patrons"] = patrons
	return GameModule.surface_command({
		"handled": true,
		"ui_state": ui_state,
		"selected_index": patron_index,
		"preserve_surface_ui_state": true,
		"message": "%s %s's cargo read." % ["Fading" if fade else "Following", str(patron.get("name", "Rail"))],
	})


func _apply_patron_rapport_after_round(state: Dictionary, ui_state: Dictionary, outcome: String) -> void:
	var patrons := _normalize_patrons(state.get("patrons", []))
	var alignment := _copy_dict(ui_state.get("table_social_alignment", {}))
	for i in range(patrons.size()):
		var patron: Dictionary = patrons[i]
		var aligned := str(alignment.get("patron_id", "")) == str(patron.get("id", "bar_patron_%d" % i))
		var delta := 1 if outcome == "win" else -1 if outcome == "lose" else 0
		if aligned:
			delta += 3 if str(alignment.get("stance", "")) == "with" else -3
		patron["rapport"] = clampi(int(patron.get("rapport", 50)) + delta, 0, 100)
		patron["last_social_delta"] = delta
		patrons[i] = patron
	state["patrons"] = patrons
	state["rail_bettors"] = patrons


func _participant_count(state: Dictionary) -> int:
	return 1 + _patron_count(state) + 1


func _patron_count(state: Dictionary) -> int:
	var patrons: Array = state.get("patrons", []) if typeof(state.get("patrons", [])) == TYPE_ARRAY else []
	var count := 0
	for patron_value in patrons:
		if typeof(patron_value) == TYPE_DICTIONARY:
			count += 1
	return count


func _working_pot(stake: int, state: Dictionary) -> int:
	return maxi(0, stake) * _participant_count(state) + maxi(0, int(state.get("carryover_pot", 0)))


func _rake_for_pot(pot: int, state: Dictionary) -> int:
	if pot <= 0:
		return 0
	return maxi(0, int(round(float(pot) * float(int(state.get("rake_percent", 7))) / 100.0)))


func _gross_payout_for_pot(pot: int, rake: int, state: Dictionary) -> int:
	var after_rake := maxi(0, pot - rake)
	var hosted_percent := clampi(int(state.get("hosted_payout_percent", 66)), 30, 100)
	return maxi(0, int(round(float(after_rake) * float(hosted_percent) / 100.0)))


func _selected_stake_index(state: Dictionary, ui_state: Dictionary) -> int:
	var ladder := _int_array(state.get("stake_ladder", []))
	return clampi(int(ui_state.get("selected_stake_index", state.get("selected_stake_index", 0))), 0, maxi(0, ladder.size() - 1))


func _active_stake_from_context(stake: int, state: Dictionary, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> int:
	var ladder := _int_array(state.get("stake_ladder", []))
	if ladder.is_empty():
		return 0
	var selected := _selected_stake_index(state, ui_state)
	if not ui_state.has("selected_stake_index") and stake > 0:
		selected = _nearest_chip_index(ladder, stake)
	var economic_profile: Dictionary = environment.get("economic_profile", {}) if typeof(environment.get("economic_profile", {})) == TYPE_DICTIONARY else {}
	var bankroll_limit := int(ladder[selected])
	var stake_ceiling := int(ladder[selected])
	if run_state != null:
		bankroll_limit = maxi(0, run_state.bankroll)
		stake_ceiling = run_state.wager_stake_ceiling(int(economic_profile.get("stake_ceiling", run_state.bankroll)))
	return mini(mini(int(ladder[selected]), maxi(0, stake_ceiling)), bankroll_limit)


func _nearest_chip_index(ladder: Array, stake: int) -> int:
	var best_index := 0
	var best_dist := 999999
	for i in range(ladder.size()):
		var dist := absi(int(ladder[i]) - stake)
		if dist < best_dist:
			best_dist = dist
			best_index = i
	return best_index


func _remaining_shakes(ui_state: Dictionary) -> int:
	return maxi(0, MAX_SHAKES - int(ui_state.get("shake_number", 0)))


func _shake_again(ui_state: Dictionary, run_state: RunState, state: Dictionary, reroll_marks: Array = []) -> Dictionary:
	var next := ui_state.duplicate(true)
	var dice := _int_dice(next.get("dice", []))
	if dice.size() != DICE_COUNT:
		dice = _generate_opening(run_state, state)
	var marks := _index_array(reroll_marks)
	if marks.is_empty():
		marks = _index_array(next.get("reroll", []))
	if marks.is_empty():
		marks = _suggested_reroll_for_ruleset(dice, "ship_captain_crew")
	var shake_number := clampi(int(next.get("shake_number", 1)) + 1, 1, MAX_SHAKES)
	for index_value in marks:
		var die_index := int(index_value)
		if die_index >= 0 and die_index < dice.size():
			dice[die_index] = _deterministic_die(run_state, state, shake_number, die_index)
	next["dice"] = dice
	next["shake_number"] = shake_number
	next["reroll"] = []
	next["loaded_armed"] = false
	next["palm_armed"] = false
	next["last_rerolled"] = marks
	next.erase("controlled_roll")
	next.erase("loaded_value")
	_set_tumble(next, "shake_%d" % shake_number, marks)
	return next


func _generate_opening(run_state: RunState, state: Dictionary) -> Array:
	var dice: Array = []
	for i in range(DICE_COUNT):
		dice.append(_deterministic_die(run_state, state, 1, i))
	return dice


func _deterministic_die(run_state: RunState, state: Dictionary, shake_number: int, index: int) -> int:
	var seed_text := str(run_state.seed_text) if run_state != null else "bar_dice"
	var rng_state := int(run_state.rng_state) if run_state != null else 0
	var table_key := str(state.get("table_key", "table"))
	var rounds := int(state.get("rounds_played", 0))
	var hashed := _stable_hash("%s:%s:%s:%d:%d:%d:%d" % [get_id(), table_key, seed_text, rng_state, rounds, shake_number, index])
	return 1 + int(hashed % DIE_FACES)


func _roll_dice(rng: RngStream, count: int) -> Array:
	var dice: Array = []
	for _i in range(count):
		dice.append(rng.randi_range(1, DIE_FACES))
	return dice


func _suggested_reroll(dice: Array) -> Array:
	return _suggested_reroll_for_ruleset(dice, "ship_captain_crew")


func _suggested_reroll_for_ruleset(dice: Array, _ruleset: String) -> Array:
	return _ship_reroll_marks(dice)


func _ship_reroll_marks(dice_value: Variant) -> Array:
	var dice := _int_dice(dice_value)
	var locks := _ship_lock_indices(dice)
	var marks: Array = []
	for i in range(dice.size()):
		if not locks.has(i):
			marks.append(i)
	if locks.size() >= 3:
		var score := _score_ship(dice)
		if int(score.get("cargo", 0)) >= 12:
			return []
	return marks


func _ship_lock_indices(dice: Array) -> Array:
	var locks: Array = []
	var used: Array = []
	for needed in [6, 5, 4]:
		var found := false
		for i in range(dice.size()):
			if used.has(i):
				continue
			if int(dice[i]) == int(needed):
				locks.append(i)
				used.append(i)
				found = true
				break
		if not found:
			break
	return locks


func _loaded_value_for(dice: Array) -> int:
	return _loaded_value_for_ruleset(dice, "ship_captain_crew")


func _loaded_value_for_ruleset(dice_value: Variant, _ruleset: String) -> int:
	var dice := _int_dice(dice_value)
	var locks := _ship_lock_indices(dice)
	if locks.size() < 1:
		return 6
	if locks.size() < 2:
		return 5
	if locks.size() < 3:
		return 4
	return 6


func _apply_loaded_die(dice_value: Variant, loaded_value: int) -> Array:
	var dice := _int_dice(dice_value)
	if dice.size() != DICE_COUNT or loaded_value < 1 or loaded_value > DIE_FACES:
		return dice
	var locks := _ship_lock_indices(dice)
	var target_index := -1
	for i in range(dice.size()):
		if not locks.has(i):
			target_index = i
			break
	if target_index >= 0:
		dice[target_index] = loaded_value
	return dice


func _apply_controlled_roll(dice_value: Variant, controlled_roll: Dictionary) -> Array:
	var dice := _int_dice(dice_value)
	if dice.size() != DICE_COUNT:
		return dice
	var grade := str(controlled_roll.get("skill_grade", "miss"))
	if not _controlled_roll_applies(grade):
		return dice
	var desired_face := clampi(int(controlled_roll.get("desired_face", 0)), 1, DIE_FACES)
	var desired_index := clampi(int(controlled_roll.get("desired_die_index", -1)), -1, DICE_COUNT - 1)
	if desired_index < 0:
		desired_index = int(_controlled_roll_target(dice).get("index", -1))
	if desired_index < 0 or desired_index >= dice.size():
		return dice
	if grade == "partial":
		var hash_text := "%s:%s:%s" % [str(controlled_roll.get("challenge_id", "")), JSON.stringify(dice), str(desired_face)]
		if int(_stable_hash(hash_text) % 100) >= 70:
			return dice
	dice[desired_index] = desired_face
	return dice


func _apply_palmed_swap(dice_value: Variant, ruleset: String) -> Array:
	var dice := _int_dice(dice_value)
	if dice.size() != DICE_COUNT:
		return dice
	var best := dice.duplicate()
	var best_score := _score_for_ruleset(best, ruleset)
	for i in range(dice.size()):
		for face in range(1, DIE_FACES + 1):
			var candidate := dice.duplicate()
			candidate[i] = face
			var score := _score_for_ruleset(candidate, ruleset)
			if _compare_signatures(score.get("signature", []), best_score.get("signature", [])) > 0:
				best = candidate
				best_score = score
	return best


func _score(dice: Array) -> Dictionary:
	return _score_ship(dice)


func _score_for_ruleset(dice: Array, _ruleset: String) -> Dictionary:
	return _score_ship(dice)


func _score_ship(dice_value: Variant) -> Dictionary:
	var dice := _int_dice(dice_value)
	var locks := _ship_lock_indices(dice)
	var stage := locks.size()
	var cargo := 0
	var category := "not_qualified"
	var qualified := false
	if stage == 1:
		category = "ship_only"
	elif stage == 2:
		category = "ship_captain"
	elif stage >= 3:
		qualified = true
		category = "ship_captain_crew"
		var cargo_indices: Array = []
		for i in range(dice.size()):
			if not locks.has(i):
				cargo_indices.append(i)
				cargo += int(dice[i])
		if cargo >= 12:
			category = "perfect_cargo"
		locks.append_array(cargo_indices)
	var signature := [1 if qualified else 0, cargo, stage]
	return {
		"category": category,
		"signature": signature,
		"qualified": qualified,
		"cargo": cargo,
		"stage": stage,
		"scoring_indices": _index_array(locks),
	}


func _compare_signatures(a: Array, b: Array) -> int:
	var limit := mini(a.size(), b.size())
	for i in range(limit):
		var left := int(a[i])
		var right := int(b[i])
		if left > right:
			return 1
		if left < right:
			return -1
	if a.size() > b.size():
		return 1
	if a.size() < b.size():
		return -1
	return 0


func _category_power(category: String) -> int:
	return int(CATEGORY_RANK.get(category, 0))


func _payout_multiplier(_category: String, state: Dictionary) -> float:
	var participants := float(_participant_count(state))
	var rake_scale := 1.0 - float(int(state.get("rake_percent", 7))) / 100.0
	var hosted_scale := float(int(state.get("hosted_payout_percent", 66))) / 100.0
	return maxf(1.0, participants * rake_scale * hosted_scale)


func _paytable_rows(state: Dictionary, active_stake: int) -> Array:
	var participants := _participant_count(state)
	var pot := _working_pot(active_stake, state)
	var rake := _rake_for_pot(pot, state)
	return [
		{"label": "Hosted pot win", "mult": _payout_multiplier("ship_captain_crew", state), "payout": _gross_payout_for_pot(pot, rake, state)},
		{"label": "Tie cargo", "mult": 0.0, "payout": int(state.get("carryover_pot", 0)) + active_stake * participants},
		{"label": "No 6-5-4", "mult": 0.0, "payout": 0},
	]


func _hand_blurb(score: Dictionary) -> String:
	var category := str(score.get("category", "not_qualified"))
	if bool(score.get("qualified", false)):
		return "%s, cargo %d" % [str(CATEGORY_LABEL.get(category, "Ship Captain Crew")), int(score.get("cargo", 0))]
	match int(score.get("stage", 0)):
		2:
			return "Ship and Captain, no Crew"
		1:
			return "Ship only"
		_:
			return "No Ship"


func _bar_dice_explainer(phase: String, player_score: Dictionary, last_result: Dictionary, active_stake: int, pot: int, rake: int, participants: int, round_timer: Dictionary) -> Dictionary:
	if phase == "settled" and not last_result.is_empty():
		return {
			"title": _result_title(str(last_result.get("outcome", ""))),
			"summary": str(last_result.get("summary", "")),
			"rule": "6-5-4 locks first; the last two dice are cargo.",
			"pot": int(last_result.get("pot", pot)),
			"rake": int(last_result.get("rake", rake)),
			"cargo": int(_copy_dict(last_result.get("player_score", {})).get("cargo", 0)),
		}
	if phase == "select":
		return {
			"title": "BUILD 6-5-4",
			"summary": "%s. Pink dice reroll; plain dice stay still." % _hand_blurb(player_score),
			"rule": "Ship is 6, Captain is 5, Crew is 4. Cargo wins only after all three lock.",
			"pot": pot,
			"rake": rake,
			"cargo": int(player_score.get("cargo", 0)),
		}
	var seconds := int(round_timer.get("remaining_seconds", 0))
	return {
		"title": "SHIP, CAPTAIN, CREW",
		"summary": "$%d ante builds a $%d pot with %d seats." % [active_stake, pot, participants],
		"rule": "High cargo wins after 6-5-4. Tied cargo carries the pot.",
		"pot": pot,
		"rake": rake,
		"cargo": 0,
		"timer": seconds,
	}


func _bar_dice_turn_guide(phase: String, player_score: Dictionary, reroll: Array, suggested: Array, remaining_shakes: int, active_stake: int, pot: int, round_timer: Dictionary, last_result: Dictionary) -> Dictionary:
	var guide := {
		"title": "How to play",
		"goal": "Make 6, then 5, then 4. When all three lock, the last two dice are cargo.",
		"next_step": "",
		"selection": "",
		"shake_hint": "",
		"result_hint": "",
		"steps": [
			"1. Roll the cup.",
			"2. Teal dice are locked.",
			"3. Click dice: pink rerolls, plain stays.",
			"4. Shake selected dice or settle shown cup.",
		],
	}
	if phase == "settled" and not last_result.is_empty():
		guide["title"] = "Round result"
		guide["next_step"] = "Roll starts the next hand. If a clean win offers PRESS, that risks the last profit for more."
		guide["selection"] = str(last_result.get("match_summary", "The table compares cargo."))
		guide["shake_hint"] = "Wins pay from the hosted pot after rake; tied cargo carries the pot forward."
		guide["result_hint"] = str(last_result.get("summary", ""))
		return guide
	if phase == "select":
		var target := _next_ship_target(player_score)
		var marked_count := reroll.size()
		guide["title"] = "Your cup is open"
		var target_text := "Need %s." % target if not target.is_empty() else "Cargo is live."
		guide["next_step"] = "%s Click dice to toggle pink reroll marks; teal locks cannot move." % target_text
		if marked_count > 0:
			guide["selection"] = "%d pink die%s will reroll; every plain die stays frozen on SHAKE." % [marked_count, "" if marked_count == 1 else "s"]
		elif suggested.size() > 0:
			guide["selection"] = "Amber dice are suggested rerolls. Click them if you want manual control."
		else:
			guide["selection"] = "No reroll needed; this cup is ready to settle."
		guide["shake_hint"] = "%d shake%s left. SHAKE moves only pink or amber dice; SETTLE compares what you see." % [remaining_shakes, "" if remaining_shakes == 1 else "s"]
		guide["result_hint"] = _hand_blurb(player_score)
		return guide
	var seconds := int(round_timer.get("remaining_seconds", 0))
	guide["title"] = "Before the roll"
	guide["next_step"] = "Choose an ante, then ROLL to play the hand step by step."
	guide["selection"] = "$%d ante feeds a $%d table pot." % [active_stake, pot]
	guide["shake_hint"] = "AUTO-PLAY HAND skips choices; ROLL CUP lets you choose every reroll."
	guide["result_hint"] = "Next automatic shake in %ds if you sit at the table." % seconds if seconds > 0 else "The table is waiting for your ante."
	return guide


func _bar_dice_rules_panel_lines(phase: String, guide: Dictionary, explainer: Dictionary) -> Array:
	var lines: Array = []
	if phase == "select":
		lines.append("Goal: make 6 Ship, 5 Captain, 4 Crew.")
		lines.append("Then cargo dice decide the pot.")
		lines.append("Pink rerolls; teal locks; plain stays.")
		lines.append("SHAKE marked dice only; SETTLE compares.")
	elif phase == "settled":
		lines.append("6-5-4 locks first; last two dice are cargo.")
		lines.append("High cargo wins; tied cargo carries the pot.")
		lines.append(str(guide.get("selection", explainer.get("summary", ""))))
		lines.append("Roll again or press a clean win.")
	else:
		lines.append("Goal: make 6 Ship, 5 Captain, 4 Crew.")
		lines.append("High cargo wins after all three lock.")
		lines.append("Pick ante, then ROLL CUP for choices.")
		lines.append("AUTO-PLAY skips choices; ties carry the pot.")
	return _compact_text_lines(lines, RULES_PANEL_LINE_LIMIT)


func _bar_dice_legend() -> Array:
	return [
		{"label": "TEAL", "text": "locked 6/5/4 or cargo score"},
		{"label": "AMBER", "text": "suggested reroll"},
		{"label": "PINK", "text": "selected reroll"},
		{"label": "PLAIN", "text": "kept this shake"},
	]


func _bar_dice_action_buttons(phase: String, remaining_shakes: int, reroll: Array, suggested: Array, can_shake: bool, press_available: bool, press_risk: int, loaded_armed: bool = false, controlled_roll: Dictionary = {}) -> Array:
	var buttons: Array = []
	if phase == "select":
		var suggested_count := suggested.size()
		var shake_label := "SHAKE PINK DICE" if not reroll.is_empty() else "SHAKE AMBER DICE"
		var shake_detail := "Reroll selected only" if not reroll.is_empty() else "Reroll suggestions"
		var shake_button_detail := "%s; %d left" % [shake_detail, remaining_shakes]
		if reroll.is_empty():
			shake_button_detail = "Reroll %d suggested; %d left" % [suggested_count, remaining_shakes]
		buttons.append({
			"action": "bar_dice_shake",
			"index": 0,
			"label": shake_label,
			"detail": shake_button_detail,
			"accent": "teal",
			"enabled": can_shake,
		})
		buttons.append({
			"action": "bar_dice_resolve",
			"index": 0,
			"label": "SETTLE CURRENT",
			"detail": "Compare shown dice",
			"accent": "yellow",
			"enabled": true,
		})
		var load_action := "bar_dice_release" if loaded_armed else "bar_dice_load"
		var load_label := "RELEASE THROW" if loaded_armed else "CHEAT LOAD DIE"
		var load_detail := "Hit %s band" % _word_single(int(controlled_roll.get("desired_face", 6))) if loaded_armed else "Time controlled roll"
		var grade := str(controlled_roll.get("skill_grade", ""))
		if loaded_armed and not grade.is_empty():
			load_label = "ROLL LOCKED"
			load_detail = grade.replace("_", " ").capitalize()
		buttons.append({
			"action": load_action,
			"index": 0,
			"label": load_label,
			"detail": load_detail,
			"accent": "pink",
			"enabled": true,
		})
		buttons.append({
			"action": "bar_dice_palm",
			"index": 0,
			"label": "CHEAT PALM SWAP",
			"detail": "Improve one die",
			"accent": "orange",
			"enabled": true,
		})
		return buttons
	buttons.append({
		"action": "bar_dice_roll",
		"index": 0,
		"label": "ROLL CUP",
		"detail": "Start step play",
		"accent": "teal",
		"enabled": true,
	})
	buttons.append({
		"action": "bar_dice_resolve",
		"index": 0,
		"label": "AUTO-PLAY HAND",
		"detail": "Skip to result",
		"accent": "yellow",
		"enabled": true,
	})
	if press_available:
		buttons.append({
			"action": "bar_dice_press",
			"index": 0,
			"label": "PRESS LAST WIN",
			"detail": "Risk $%d" % press_risk,
			"accent": "amber",
			"enabled": true,
		})
	return buttons


func _surface_opponent_rows(state: Dictionary, last_result: Dictionary, phase: String) -> Array:
	var rows: Array = []
	if phase == "settled" and not last_result.is_empty():
		var legs := _dictionary_array(last_result.get("match_legs", []))
		var winning_name := str(last_result.get("winning_opponent_name", ""))
		if not winning_name.is_empty():
			for leg_value in legs:
				var leg: Dictionary = leg_value
				if str(leg.get("name", "")) == winning_name:
					rows.append(_surface_opponent_row_from_leg(leg, true))
					break
		for leg_value in legs:
			var leg: Dictionary = leg_value
			if _opponent_rows_has_id(rows, str(leg.get("id", ""))):
				continue
			rows.append(_surface_opponent_row_from_leg(leg, false))
			if rows.size() >= MAX_VISIBLE_OPPONENT_ROWS:
				return rows
		return rows
	var patrons := _normalize_patrons(state.get("patrons", []))
	for i in range(mini(patrons.size(), MAX_VISIBLE_OPPONENT_ROWS)):
		var patron: Dictionary = patrons[i]
		var dice := _opponent_preview_dice(state, i)
		var score := _score_ship(dice)
		rows.append({
			"id": str(patron.get("id", "bar_patron_%d" % i)),
			"name": str(patron.get("name", "Rail %d" % (i + 1))),
			"personality": str(patron.get("personality", "")),
			"banter": _patron_banter_line(patron, i + int(state.get("rounds_played", 0)), ""),
			"dice": dice,
			"score": score,
			"scoring_indices": _index_array(score.get("scoring_indices", [])),
			"blurb": _hand_blurb(score),
			"winning": false,
			"preview": true,
			"roll_visible": true,
			"turn_order": i,
			"turn_wait_msec": 0,
		})
	return rows


func _surface_opponent_row_from_leg(leg: Dictionary, winning: bool) -> Dictionary:
	var dice := _int_dice(leg.get("dice", []))
	var score := _copy_dict(leg.get("score", {}))
	if score.is_empty():
		score = _score_ship(dice)
	return {
		"id": str(leg.get("id", "")),
		"name": str(leg.get("name", "Rail")),
		"personality": str(leg.get("personality", "")),
		"banter": str(leg.get("banter", "")),
		"dice": dice,
		"score": score,
		"scoring_indices": _index_array(score.get("scoring_indices", [])),
		"blurb": _hand_blurb(score),
		"winning": winning,
		"preview": false,
		"roll_visible": true,
		"turn_order": int(leg.get("turn_order", leg.get("seat", 0))),
		"turn_wait_msec": int(leg.get("turn_wait_msec", 0)),
	}


func _opponent_rows_has_id(rows: Array, id: String) -> bool:
	if id.is_empty():
		return false
	for row_value in rows:
		if typeof(row_value) == TYPE_DICTIONARY and str((row_value as Dictionary).get("id", "")) == id:
			return true
	return false


func _opponent_preview_dice(state: Dictionary, patron_index: int) -> Array:
	var dice: Array = []
	var table_key := str(state.get("table_key", "bar"))
	var rounds := int(state.get("rounds_played", 0))
	for die_index in range(DICE_COUNT):
		var hashed := _stable_hash("%s:preview:%d:%d:%d" % [table_key, rounds, patron_index, die_index])
		dice.append(1 + int(hashed % DIE_FACES))
	return dice


func _tumble_action_blocks() -> Array:
	return [
		{"actions": ["bar_dice_roll", "bar_dice_shake", "bar_dice_select", "bar_dice_resolve", "bar_dice_load", "bar_dice_release", "bar_dice_palm", "bar_dice_press", "bar_dice_stake", "bar_dice_rail_bet"], "while_animation": TUMBLE_CHANNEL},
	]


func _next_ship_target(score: Dictionary) -> String:
	match int(score.get("stage", 0)):
		0:
			return "Ship: a 6"
		1:
			return "Captain: a 5"
		2:
			return "Crew: a 4"
		_:
			return ""


func _remaining_from_score(score: Dictionary) -> int:
	return maxi(0, MAX_SHAKES - int(score.get("stage", 0)))


func _result_title(outcome: String) -> String:
	match outcome:
		"win":
			return "YOU WIN THE POT"
		"carry":
			return "POT CARRIES"
		_:
			return "TABLE WINS"


func _outcome_message(table_result: Dictionary, outcome: String, bankroll_delta: int, suspicion_delta: int, action_id: String, pit_boss_summary: String, security_message: String, state: Dictionary) -> String:
	var player_score := _copy_dict(table_result.get("player_score", {}))
	var pot := int(table_result.get("pot", 0))
	var rake := int(table_result.get("rake", 0))
	var winner_name := str(_copy_dict(table_result.get("winning_opponent", {})).get("name", "the table"))
	var text := ""
	if outcome == "win":
		text = "Bar dice: you lock 6-5-4 with cargo %d and win the $%d pot after $%d rake. Bankroll %+d." % [int(player_score.get("cargo", 0)), pot, rake, bankroll_delta]
	elif outcome == "carry":
		text = "Bar dice: cargo ties or nobody completes 6-5-4. Your $%d ante rides into the next $%d carryover pot. Bankroll %+d." % [int(table_result.get("stake", 0)), int(table_result.get("carryover_pot", 0)), bankroll_delta]
	else:
		text = "Bar dice: %s beats your %s and takes the $%d pot. Bankroll %+d." % [winner_name, _hand_blurb(player_score), pot, bankroll_delta]
	if action_id == "loaded_toss":
		var controlled := _copy_dict(table_result.get("controlled_roll", {}))
		var grade := str(controlled.get("skill_grade", "miss")).replace("_", " ").capitalize()
		text += " Controlled roll %s; loaded die risk is visible." % grade
	elif action_id == "palmed_swap":
		text += " Palmed swap risk is visible."
	if suspicion_delta > 0:
		text += " Heat %+d." % suspicion_delta
	if not pit_boss_summary.is_empty():
		text += " %s" % pit_boss_summary
	if not security_message.is_empty():
		text += " %s" % security_message
	if not str(state.get("edge_label", "")).is_empty():
		text += " %s." % str(state.get("edge_label", ""))
	return text


func _match_summary(table_result: Dictionary) -> String:
	var outcome := str(table_result.get("outcome", ""))
	if outcome == "win":
		return "You beat the bar."
	if outcome == "carry":
		return "Pot carries forward."
	var winner := _copy_dict(table_result.get("winning_opponent", {}))
	return "%s wins cargo." % str(winner.get("name", "The table"))


func _resolve_prompt(ui_state: Dictionary, action_id: String) -> String:
	match action_id:
		"loaded_toss":
			var controlled := _normalized_controlled_roll(ui_state.get("controlled_roll", {}))
			if controlled.is_empty():
				return "Controlled roll armed. Release on the target face, then settle the cup."
			var grade := str(controlled.get("skill_grade", ""))
			if grade.is_empty():
				return "Controlled roll armed for %s. Hit RELEASE in the target band." % _word_single(int(controlled.get("desired_face", 6)))
			return "Controlled roll %s locked. Settle the cup to risk the throw." % grade.replace("_", " ").capitalize()
		"palmed_swap":
			return "Palmed swap armed. Click again to improve one die and take heat."
		_:
			if bool(ui_state.get("rolled", false)):
				return "Settle this cup: your 6-5-4 cargo is compared against every seat. Click again to confirm."
			return "Quick play rolls all three shakes automatically, then compares cargo against the table. Click again to confirm."


func _action_command(action_id: String, action_kind: String, confirm_requested: bool, ui_state: Dictionary, index: int, message: String) -> Dictionary:
	var already_selected := str(ui_state.get("selected_action_id", "")) == action_id and str(ui_state.get("selected_action_kind", "")) == action_kind
	var resolving := confirm_requested or already_selected
	return GameModule.surface_command({
		"handled": true,
		"ui_state": ui_state,
		"action_id": action_id,
		"action_kind": action_kind,
		"resolve": resolving,
		"preserve_surface_ui_state": not resolving,
		"selected_index": index,
		"message": message,
	})


func _message_command(ui_state: Dictionary, message: String) -> Dictionary:
	return GameModule.surface_command({
		"handled": true,
		"ui_state": ui_state,
		"preserve_surface_ui_state": true,
		"message": message,
	})


func _selected_surface_actions(ui_state: Dictionary) -> Array:
	var action_id := str(ui_state.get("selected_action_id", ""))
	var action_kind := str(ui_state.get("selected_action_kind", ""))
	if action_id == "roll" and action_kind == "legal":
		return ["bar_dice_resolve"]
	if action_id == "loaded_toss" and action_kind == "cheat":
		return ["bar_dice_load", "bar_dice_release", "bar_dice_resolve"]
	if action_id == "palmed_swap" and action_kind == "cheat":
		return ["bar_dice_palm"]
	if action_id == "press" and action_kind == "legal":
		return ["bar_dice_press"]
	return []


func _active_tumble(ui_state: Dictionary, last_result: Dictionary, rolled: bool) -> Dictionary:
	if rolled and ui_state.has("tumble_id"):
		return {"id": str(ui_state.get("tumble_id", "")), "started": int(ui_state.get("tumble_started_msec", 0)), "indices": _index_array(ui_state.get("tumble_indices", []))}
	if not rolled and not last_result.is_empty():
		return {"id": str(last_result.get("tumble_id", "")), "started": int(last_result.get("resolved_at_msec", 0)), "indices": _index_array(last_result.get("tumble_indices", []))}
	return {"id": "", "started": 0, "indices": []}


func _set_tumble(ui_state: Dictionary, prefix: String, indices: Array = []) -> void:
	var now := Time.get_ticks_msec()
	ui_state["tumble_id"] = "%s_%d" % [prefix, now]
	ui_state["tumble_started_msec"] = now
	ui_state["tumble_indices"] = _index_array(indices)


func _draw_bar_room(surface, state: Dictionary) -> void:
	TableVisualsScript.draw_room(surface, state, "BAR DICE", "%s / %s" % [str(state.get("bar_name", "bar top")), str(state.get("edge_label", "Bar Rake"))])


func _draw_bar_top(surface, _state: Dictionary) -> void:
	var rail := Rect2(46, 134, 808, 194)
	surface.draw_rect(rail, Color("#2a1420"))
	surface.draw_rect(Rect2(rail.position + Vector2(12, 10), rail.size - Vector2(24, 20)), Color("#2f2118"))
	surface.draw_rect(Rect2(rail.position + Vector2(24, 24), rail.size - Vector2(48, 48)), Color("#3a2619"))
	for i in range(7):
		var y := 156 + i * 21
		surface.draw_line(Vector2(84, y), Vector2(814, y + 6), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.08), 1)
	surface.draw_rect(rail, Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.32), false, 2)
	surface.draw_rect(Rect2(132, 300, 636, 5), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.22))


func _draw_dice_rows(surface, state: Dictionary) -> void:
	var phase := str(state.get("phase", "bet"))
	var player := _int_dice(state.get("player", []))
	var reroll := _index_array(state.get("reroll", []))
	var suggested := _index_array(state.get("suggested_reroll", []))
	var scoring := _index_array(state.get("scoring_indices", []))
	var animated := _index_array(state.get("animated_dice_indices", []))
	var guide := _copy_dict(state.get("bar_dice_turn_guide", {}))
	_draw_opponent_dice_rows(surface, state)
	surface.surface_label("YOUR CUP", Vector2(262, 204), 12, C_TEAL)
	if phase == "select":
		surface.surface_label(str(guide.get("selection", "Pink rerolls; plain dice stay.")).left(64), Vector2(262, 194), 8, C_SOFT)
	_draw_dice_row(surface, player, PLAYER_DICE_ORIGIN, reroll, suggested, scoring, false, DIE_SIZE, DIE_SPACING, animated, phase == "select", false)
	if phase == "select":
		_add_dice_row_hits(surface, player, PLAYER_DICE_ORIGIN, "bar_dice_select", DIE_SIZE, DIE_SPACING)
		_draw_dice_goal_strip(surface, state, Vector2(262, 266))
	_draw_legend_row(surface, state, Vector2(262, 306))
	if bool(state.get("loaded_armed", false)):
		_draw_controlled_roll_meter(surface, state, Vector2(262, 282))
	if bool(state.get("palm_armed", false)):
		surface.surface_label("Palmed swap ready", Vector2(262, 286), 12, C_PINK_2)


func _draw_controlled_roll_meter(surface, state: Dictionary, pos: Vector2) -> void:
	var challenge: Dictionary = state.get("controlled_roll", {}) if typeof(state.get("controlled_roll", {})) == TYPE_DICTIONARY else {}
	var meter: Dictionary = state.get("controlled_roll_meter", {}) if typeof(state.get("controlled_roll_meter", {})) == TYPE_DICTIONARY else {}
	if challenge.is_empty():
		surface.surface_label("Loaded face: %s" % _word_single(int(state.get("loaded_value", 0))), pos + Vector2(0, 4), 12, C_PINK_2)
		return
	var bar := Rect2(pos + Vector2(0, 12), Vector2(276, 10))
	surface.surface_label("CONTROL THROW: %s" % _word_single(int(challenge.get("desired_face", state.get("loaded_value", 6)))).to_upper(), pos, 8, C_PINK_2)
	surface.draw_rect(bar, Color("#070812"))
	surface.draw_rect(bar, Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.38), false, 1)
	for face in range(1, DIE_FACES + 1):
		var x := bar.position.x + (float(face) - 0.5) * bar.size.x / float(DIE_FACES)
		var color := C_YELLOW if face == int(challenge.get("desired_face", 0)) else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.32)
		surface.draw_rect(Rect2(x - 1.0, bar.position.y - 3.0, 2.0, bar.size.y + 6.0), color)
	var progress_x := bar.position.x + bar.size.x * clampf(float(meter.get("progress", 0.0)), 0.0, 1.0)
	surface.draw_rect(Rect2(bar.position.x, bar.position.y, maxf(0.0, progress_x - bar.position.x), bar.size.y), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.24))
	surface.draw_rect(Rect2(progress_x - 2.0, bar.position.y - 5.0, 4.0, bar.size.y + 10.0), C_CYAN)
	var input := float(meter.get("input", -1.0))
	if input >= 0.0:
		var input_x := bar.position.x + bar.size.x * clampf(input, 0.0, 1.0)
		surface.draw_rect(Rect2(input_x - 1.0, bar.position.y - 6.0, 2.0, bar.size.y + 12.0), C_WHITE)
		var grade := str(meter.get("skill_grade", "")).replace("_", " ").to_upper()
		surface.surface_label(grade.left(18), pos + Vector2(154, 0), 8, C_CYAN)


func _draw_opponent_dice_rows(surface, state: Dictionary) -> void:
	var rows := _dictionary_array(state.get("opponent_rows", []))
	if rows.is_empty():
		return
	surface.surface_label("RAIL CUPS", Vector2(76, 134), 9, C_PINK_2)
	for i in range(mini(rows.size(), MAX_VISIBLE_OPPONENT_ROWS)):
		var row: Dictionary = rows[i]
		var origin: Vector2 = OPPONENT_DICE_ORIGINS[i]
		var accent := C_YELLOW if bool(row.get("winning", false)) else C_PINK_2
		var panel := Rect2(origin + Vector2(-8, -16), Vector2(204, 34))
		surface.draw_rect(panel, Color("#130c18"))
		surface.draw_rect(panel, Color(accent.r, accent.g, accent.b, 0.18), false, 1)
		surface.surface_label(str(row.get("name", "Rail")).to_upper().left(10), origin + Vector2(0, -5), 7, accent)
		surface.surface_label(str(row.get("blurb", "Cup ready")).left(18), origin + Vector2(88, -5), 7, C_SOFT)
		if not str(row.get("banter", "")).is_empty():
			surface.surface_label(str(row.get("banter", "")).left(28), origin + Vector2(0, 34), 6, C_AMBER)
		_draw_dice_row(surface, _int_dice(row.get("dice", [])), origin + Vector2(0, 7), [], [], _index_array(row.get("scoring_indices", [])), false, OPPONENT_DIE_SIZE, OPPONENT_DIE_SPACING, [], false, true)


func _draw_dice_row(surface, values: Array, start: Vector2, reroll: Array, suggested: Array, scoring: Array, hidden: bool, die_size: Vector2, die_spacing: float, rolling_indices: Array, show_keep_labels: bool, compact: bool) -> void:
	var tumble_active := bool(surface.surface_animation_active(TUMBLE_CHANNEL))
	var tumble_progress := float(surface.surface_animation_progress(TUMBLE_CHANNEL))
	var flicker := float(surface.surface_flicker())
	var rolling := _index_array(rolling_indices)
	for i in range(values.size()):
		var rect := Rect2(start + Vector2(float(i) * die_spacing, 0.0), die_size)
		var die_rolling := tumble_active and tumble_progress < 0.98 and rolling.has(i) and not hidden
		var draw_rect := rect
		if die_rolling:
			draw_rect = Rect2(rect.position + Vector2(0, sin((flicker * 18.0) + float(i)) * 5.0), rect.size)
			_draw_die_motion_trail(surface, rect, i, flicker)
		if hidden:
			_draw_die_cup(surface, draw_rect)
		else:
			var face := int(values[i])
			if die_rolling:
				face = 1 + int(flicker * 19.0 + i * 3) % DIE_FACES
			_draw_die(surface, draw_rect, face, reroll.has(i), suggested.has(i), scoring.has(i) and not die_rolling, show_keep_labels, compact)


func _add_dice_row_hits(surface, values: Array, start: Vector2, action: String, die_size: Vector2, die_spacing: float) -> void:
	for i in range(values.size()):
		surface.surface_add_exact_hit(Rect2(start + Vector2(float(i) * die_spacing, 0.0), die_size), action, i)


func _draw_die(surface, rect: Rect2, value: int, marked: bool, suggested: bool, scoring: bool, show_keep_label: bool, compact: bool) -> void:
	var flicker := float(surface.surface_flicker())
	if scoring:
		var grow := (3.0 if compact else 4.0) + absf(sin(flicker * 4.0)) * 1.5
		surface.draw_rect(Rect2(rect.position - Vector2(grow, grow), rect.size + Vector2(grow * 2.0, grow * 2.0)), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.30))
	surface.draw_rect(rect, C_SOFT)
	var inset := 3.0 if compact else 4.0
	surface.draw_rect(Rect2(rect.position + Vector2(inset, inset), rect.size - Vector2(inset * 2.0, inset * 2.0)), Color("#f7f1e0") if not marked else Color("#e8c8d8"))
	if marked:
		var pulse := (3.0 if compact else 4.0) + absf(sin(flicker * 5.5)) * 2.0
		surface.draw_rect(Rect2(rect.position - Vector2(pulse, pulse), rect.size + Vector2(pulse * 2.0, pulse * 2.0)), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.64), false, 3)
	elif suggested:
		var suggest_grow := (2.0 if compact else 3.0) + absf(sin(flicker * 3.0)) * 1.0
		surface.draw_rect(Rect2(rect.position - Vector2(suggest_grow, suggest_grow), rect.size + Vector2(suggest_grow * 2.0, suggest_grow * 2.0)), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.48), false, 2)
	elif scoring:
		var score_grow := 3.0 if compact else 4.0
		surface.draw_rect(Rect2(rect.position - Vector2(score_grow, score_grow), rect.size + Vector2(score_grow * 2.0, score_grow * 2.0)), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.70), false, 3)
	if value <= 0:
		surface.surface_label_centered("?", rect, 18 if compact else 24, C_DARK)
		return
	_draw_pips(surface, rect, value)
	var status := ""
	var status_color := C_SOFT
	if marked:
		status = "REROLL"
		status_color = C_PINK
	elif suggested:
		status = "TRY"
		status_color = C_AMBER
	elif scoring:
		status = "LOCK"
		status_color = C_TEAL
	elif show_keep_label:
		status = "KEEP"
		status_color = C_SOFT
	if not status.is_empty():
		surface.surface_label_centered(status, Rect2(rect.position + Vector2(-2, rect.size.y + 2), Vector2(rect.size.x + 4, 10)), 6 if compact else 7, status_color)


func _draw_die_motion_trail(surface, rect: Rect2, index: int, flicker: float) -> void:
	var phase := fmod(flicker * 4.0 + float(index) * 0.17, 1.0)
	for trail_index in range(3):
		var offset := Vector2(-8.0 - float(trail_index) * 5.0, sin((phase + float(trail_index) * 0.2) * TAU) * 4.0)
		var alpha := 0.12 - float(trail_index) * 0.03
		surface.draw_rect(Rect2(rect.position + offset, rect.size), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, alpha), false, 1)


func _draw_dice_goal_strip(surface, state: Dictionary, pos: Vector2) -> void:
	var score := _copy_dict(state.get("player_score", {}))
	var stage := int(score.get("stage", 0))
	var steps := [
		{"label": "SHIP 6", "done": stage >= 1},
		{"label": "CAPTAIN 5", "done": stage >= 2},
		{"label": "CREW 4", "done": stage >= 3},
		{"label": "CARGO", "done": bool(score.get("qualified", false))},
	]
	for i in range(steps.size()):
		var step: Dictionary = steps[i]
		var rect := Rect2(pos + Vector2(float(i) * 68.0, 0), Vector2(62, 16))
		var done := bool(step.get("done", false))
		var color := C_TEAL if done else C_AMBER if i == stage else C_SOFT
		surface.draw_rect(rect, Color(color.r, color.g, color.b, 0.16 if done or i == stage else 0.06))
		surface.draw_rect(rect, color, false, 1)
		surface.surface_label_centered(str(step.get("label", "")), rect.grow(-2), 7, color)


func _draw_die_cup(surface, rect: Rect2) -> void:
	surface.draw_rect(rect, Color("#1c1326"))
	surface.draw_rect(Rect2(rect.position + Vector2(4, 4), rect.size - Vector2(8, 8)), Color("#2a1c36"))
	surface.draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.30), false, 2)
	surface.surface_label_centered("?", rect, 24, C_PINK_2)


func _draw_pips(surface, rect: Rect2, value: int) -> void:
	var w := rect.size.x
	var h := rect.size.y
	var points := [
		rect.position + Vector2(w * 0.28, h * 0.28),
		rect.position + Vector2(w * 0.50, h * 0.50),
		rect.position + Vector2(w * 0.72, h * 0.72),
		rect.position + Vector2(w * 0.72, h * 0.28),
		rect.position + Vector2(w * 0.28, h * 0.72),
		rect.position + Vector2(w * 0.28, h * 0.50),
		rect.position + Vector2(w * 0.72, h * 0.50),
	]
	var indices := {
		1: [1],
		2: [0, 2],
		3: [0, 1, 2],
		4: [0, 2, 3, 4],
		5: [0, 1, 2, 3, 4],
		6: [0, 2, 3, 4, 5, 6],
	}
	for idx in indices.get(value, []):
		surface.draw_circle(points[int(idx)], clampf(minf(w, h) * 0.085, 1.6, 3.5), C_DARK)


func _draw_explainer(surface, state: Dictionary) -> void:
	var explainer := _copy_dict(state.get("bar_dice_explainer", {}))
	var guide := _copy_dict(state.get("bar_dice_turn_guide", {}))
	var rect := RULES_PANEL_RECT
	_draw_neon_panel(surface, rect, C_AMBER, 0.14)
	var title := str(guide.get("title", explainer.get("title", "How to play"))).to_upper()
	surface.surface_label(title.left(22), rect.position + Vector2(10, 13), 9, C_YELLOW)
	surface.surface_label("POT $%d" % int(explainer.get("pot", 0)), rect.position + Vector2(232, 13), 8, C_TEAL)
	surface.surface_label("RAKE $%d" % int(explainer.get("rake", 0)), rect.position + Vector2(232, 25), 8, C_PINK_2)
	var lines := _panel_string_lines(state.get("bar_dice_rules_lines", []))
	var y := rect.position.y + 27.0
	for i in range(mini(lines.size(), 4)):
		var color := C_SOFT if i == 0 else C_WHITE if i == 1 else C_AMBER if i == 2 else C_TEAL
		surface.surface_label(str(lines[i]), Vector2(rect.position.x + 10.0, y + float(i) * 9.0), 6, color)
	surface.surface_label("CARGO %d" % int(explainer.get("cargo", 0)), rect.position + Vector2(232, 40), 8, C_YELLOW)


func _draw_paytable(surface, state: Dictionary) -> void:
	var rect := PAYTABLE_PANEL_RECT
	_draw_neon_panel(surface, rect, C_CYAN, 0.12)
	surface.surface_label("POT RULES", rect.position + Vector2(10, 13), 9, C_CYAN)
	var rows: Array = state.get("paytable_rows", []) if typeof(state.get("paytable_rows", [])) == TYPE_ARRAY else []
	for i in range(mini(rows.size(), 3)):
		var row: Dictionary = rows[i]
		var y := rect.position.y + 26 + i * 9
		surface.surface_label(str(row.get("label", "")).left(18), Vector2(rect.position.x + 10, y), 6, C_SOFT)
		var payout_text := "$%d" % int(row.get("payout", 0)) if int(row.get("payout", 0)) > 0 else "NO PAY"
		surface.surface_label(payout_text, Vector2(rect.position.x + 138, y), 6, C_YELLOW)


func _draw_legend_row(surface, state: Dictionary, pos: Vector2) -> void:
	var legend: Array = state.get("dice_legend", []) if typeof(state.get("dice_legend", [])) == TYPE_ARRAY else []
	for i in range(mini(legend.size(), 4)):
		if typeof(legend[i]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = legend[i]
		var color := C_TEAL if i == 0 else C_AMBER if i == 1 else C_PINK if i == 2 else C_SOFT
		var x := pos.x + float(i) * 66.0
		surface.draw_rect(Rect2(x, pos.y - 7, 9, 7), color)
		surface.surface_label(str(entry.get("label", "")).left(6), Vector2(x + 12, pos.y), 7, color)


func _draw_round_timer(surface, state: Dictionary) -> void:
	TableVisualsScript.draw_round_timer_panel(surface, _copy_dict(state.get("table_round_timer", {})), ROUND_TIMER_RECT, C_TEAL)


func _draw_console(surface, state: Dictionary) -> void:
	var phase := str(state.get("phase", "bet"))
	var panel := Rect2(0, CONSOLE_Y, 900, 86)
	surface.draw_rect(panel, Color(0.02, 0.02, 0.05, 0.86))
	surface.draw_rect(panel, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.18), false, 1)
	var guide := _copy_dict(state.get("bar_dice_turn_guide", {}))
	_draw_chip_ladder(surface, state, phase)
	surface.surface_label("ANTE $%d" % int(state.get("active_stake", 0)), Vector2(330, CONSOLE_Y + 24), 12, C_YELLOW)
	surface.surface_label("POT $%d" % int(state.get("pot_meter", 0)), Vector2(330, CONSOLE_Y + 44), 12, C_TEAL)
	surface.surface_label("CARRY $%d" % int(state.get("carryover_pot", 0)), Vector2(330, CONSOLE_Y + 64), 11, C_SOFT)
	var buttons := _dictionary_array(state.get("bar_dice_action_buttons", []))
	var widths := [108.0, 108.0, 100.0, 100.0] if phase == "select" else [108.0, 124.0, 116.0]
	var x := 428.0
	for i in range(mini(buttons.size(), widths.size())):
		var button: Dictionary = buttons[i]
		var action := str(button.get("action", ""))
		var rect := Rect2(x, CONSOLE_Y + 13, float(widths[i]), 44)
		_draw_table_button(
			surface,
			rect,
			str(button.get("label", "")),
			action,
			int(button.get("index", 0)),
			_button_accent(str(button.get("accent", "teal"))),
			bool(button.get("enabled", true)),
			_selected_contains(state, action),
			str(button.get("detail", ""))
		)
		x += float(widths[i]) + 8.0
	if phase == "settled":
		var delta := int(state.get("result_bankroll_delta", 0))
		var heat := int(state.get("result_suspicion_delta", 0))
		var color := C_TEAL if delta > 0 else C_YELLOW if delta == 0 else C_ORANGE
		surface.surface_label("Bankroll %+d  Heat %+d" % [delta, heat], Vector2(452, CONSOLE_Y + 74), 11, color)
	else:
		var prompt := str(guide.get("shake_hint", "Roll, mark dice, shake, then settle."))
		surface.surface_label(prompt.left(74), Vector2(452, CONSOLE_Y + 74), 9, C_SOFT)


func _draw_chip_ladder(surface, state: Dictionary, phase: String) -> void:
	var ladder := _int_array(state.get("stake_ladder", []))
	var selected := int(state.get("selected_stake_index", 0))
	for i in range(ladder.size()):
		var rect := Rect2(28 + i * 54, CONSOLE_Y + 22, 46, 34)
		var fill := C_YELLOW if i == selected else Color("#271735")
		surface.draw_rect(rect, fill)
		surface.draw_rect(rect, C_SOFT, false, 2)
		surface.surface_label_centered("$%d" % int(ladder[i]), rect, 12, C_DARK if i == selected else C_SOFT)
		if phase != "select":
			surface.surface_add_hit(rect, "bar_dice_stake", i)


func _draw_table_button(surface, rect: Rect2, label: String, action: String, index: int, accent: Color, enabled: bool = true, selected: bool = false, detail: String = "") -> void:
	var alpha := 0.28 if enabled else 0.08
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, alpha))
	surface.draw_rect(rect, C_WHITE if selected else accent, false, 2 if selected else 1)
	var text_color := accent if enabled else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.45)
	if detail.is_empty():
		surface.surface_label_centered(label.left(18), rect.grow(-4), 9, text_color)
	else:
		surface.surface_label_centered(label.left(18), Rect2(rect.position + Vector2(4, 8), Vector2(rect.size.x - 8.0, 13)), 8, text_color)
		surface.surface_label_centered(detail.left(22), Rect2(rect.position + Vector2(4, 25), Vector2(rect.size.x - 8.0, 11)), 7, text_color)
	if enabled:
		surface.surface_add_exact_hit(rect, action, index)


func _button_accent(name: String) -> Color:
	match name:
		"yellow":
			return C_YELLOW
		"pink":
			return C_PINK
		"orange":
			return C_ORANGE
		"amber":
			return C_AMBER
		_:
			return C_TEAL


func _selected_contains(state: Dictionary, action: String) -> bool:
	return (state.get("native_selected_surface_actions", []) as Array).has(action)


func _draw_neon_panel(surface, rect: Rect2, accent: Color, alpha: float = 0.16) -> void:
	surface.draw_rect(rect.grow(4), Color(accent.r, accent.g, accent.b, alpha * 0.20))
	surface.draw_rect(rect, Color(0.01, 0.02, 0.05, 0.74))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, alpha), false, 1)


func _bar_dice_layout_snapshot() -> Dictionary:
	return {
		"rules_panel": _rect_payload(RULES_PANEL_RECT),
		"paytable_panel": _rect_payload(PAYTABLE_PANEL_RECT),
		"round_timer": _rect_payload(ROUND_TIMER_RECT),
		"text_panel_rects": _bar_dice_text_panel_regions(),
		"patron_safe_rects": _bar_dice_patron_safe_rects(),
	}


func _bar_dice_text_panel_regions() -> Array:
	return [
		_rect_payload(RULES_PANEL_RECT, "rules"),
		_rect_payload(PAYTABLE_PANEL_RECT, "paytable"),
		_rect_payload(ROUND_TIMER_RECT, "round_timer"),
	]


func _bar_dice_patron_safe_rects() -> Array:
	var rects: Array = []
	for i in range(mini(BAR_PATRON_POSITIONS.size(), 4)):
		var pos: Vector2 = BAR_PATRON_POSITIONS[i]
		rects.append(_rect_payload(Rect2(pos + Vector2(-50, -54), Vector2(142, 158)), "patron_%d" % i))
	return rects


func _rect_payload(rect: Rect2, id: String = "") -> Dictionary:
	return {
		"id": id,
		"x": rect.position.x,
		"y": rect.position.y,
		"w": rect.size.x,
		"h": rect.size.y,
	}


func _compact_text_lines(source_lines: Array, max_chars: int) -> Array:
	var result: Array = []
	for value in source_lines:
		var line := str(value).strip_edges()
		if line.is_empty():
			continue
		var wrapped := _wrap_text_line(line, max_chars)
		result.append_array(wrapped)
	return result


func _wrap_text_line(text: String, max_chars: int) -> Array:
	var limit := maxi(8, max_chars)
	var words := text.split(" ", false)
	var result: Array = []
	var current := ""
	for word_value in words:
		var word := str(word_value)
		if current.is_empty():
			current = word
		elif current.length() + 1 + word.length() <= limit:
			current = "%s %s" % [current, word]
		else:
			result.append(current)
			current = word
	if not current.is_empty():
		result.append(current)
	return result


func _panel_string_lines(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for line_value in value as Array:
		var line := str(line_value).strip_edges()
		if not line.is_empty():
			result.append(line)
	return result


func _empty_result(action_id: String, stake: int, environment: Dictionary, text: String) -> Dictionary:
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


func _action_def(action_id: String) -> Dictionary:
	for action_value in definition.get("legal_actions", []):
		if typeof(action_value) == TYPE_DICTIONARY and str((action_value as Dictionary).get("id", "")) == action_id:
			return (action_value as Dictionary).duplicate(true)
	for action_value in definition.get("cheat_actions", []):
		if typeof(action_value) == TYPE_DICTIONARY and str((action_value as Dictionary).get("id", "")) == action_id:
			return (action_value as Dictionary).duplicate(true)
	return {}


func _item_effect_total(key: String, run_state: RunState) -> int:
	if run_state == null:
		return 0
	return run_state.item_effect_total(key, get_family()) if run_state.has_method("item_effect_total") else 0


func _patron_snitch_pressure(patrons: Array) -> int:
	var total := 0
	for patron_value in patrons:
		var patron: Dictionary = patron_value
		if bool(patron.get("watching_player", false)):
			total += int(patron.get("active_snitch_risk", patron.get("snitch_risk", 0)))
	return total


func _reroll_summary(marks: Array) -> String:
	if marks.is_empty():
		return "auto locks"
	var labels: Array = []
	for mark in marks:
		labels.append(str(int(mark) + 1))
	return ", ".join(labels)


func _word_single(value: int) -> String:
	return str(DIE_WORD.get(value, str(value)))


func _word_plural(value: int) -> String:
	return str(DIE_WORD_PLURAL.get(value, "%ss" % value))


func _patron_banter_line(patron: Dictionary, selector: int, outcome: String) -> String:
	if outcome == "win":
		return "That cargo talks."
	if outcome == "lose":
		return "Pay the rail."
	if outcome == "carry":
		return "Let the pot ride."
	var lines := _string_array(patron.get("banter_lines", []))
	if lines.is_empty():
		return str(patron.get("mood", "Rail")).capitalize()
	return str(lines[absi(selector) % lines.size()])


func _int_dice(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		result.append(clampi(int(entry), 0, DIE_FACES))
	return result


func _int_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		result.append(int(entry))
	return result


func _index_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var index := int(entry)
		if index >= 0 and not result.has(index):
			result.append(index)
	result.sort()
	return result


func _all_die_indices() -> Array:
	var result: Array = []
	for i in range(DICE_COUNT):
		result.append(i)
	return result


func _index_array_raw(value: Variant) -> Array:
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


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _color_name(name: String) -> Dictionary:
	return {"name": name}


func _stable_hash(text: String) -> int:
	var hash_value := 2166136261
	for i in range(text.length()):
		hash_value = int(hash_value ^ text.unicode_at(i))
		hash_value = int((hash_value * 16777619) & 0x7fffffff)
	return maxi(hash_value, 1)
