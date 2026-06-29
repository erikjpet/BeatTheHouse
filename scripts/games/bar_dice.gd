class_name BarDiceGame
extends GameModule

# Full-simulation venue bar dice. The environment owns a generated table identity
# and the surface owns only UI-local selections; resolution returns deltas through
# the shared GameModule result path.

const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const C_DARK := VisualStyleScript.DARK
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
const STATE_SCHEMA := "bar_dice_table_state"
const STATE_VERSION := 2
const TUMBLE_CHANNEL := "bar_dice_tumble"
const TUMBLE_DURATION_MSEC := 900
const MATCH_LEGS := 3
const PRESS_CAP := 3

const RULESET_ORDER := ["poker_dice", "ship_captain_crew", "over_under_7", "bluff_call"]
const RULESET_LABEL := {
	"poker_dice": "Poker Dice",
	"ship_captain_crew": "Ship Captain Crew",
	"over_under_7": "Over Under Seven",
	"bluff_call": "Liar Call",
}
const EDGE_TIER_ORDER := ["friendly", "standard", "sharp"]
const EDGE_TIER_LABEL := {
	"friendly": "Loose Rail",
	"standard": "House Rack",
	"sharp": "Sharp Cup",
}
const EDGE_TIER_SCALE := {
	"friendly": 1.10,
	"standard": 1.08,
	"sharp": 1.05,
}
const POKER_TIER_SCALE := {
	"friendly": 0.98,
	"standard": 0.96,
	"sharp": 0.94,
}
const SHIP_TIER_SCALE := {
	"friendly": 1.10,
	"standard": 1.12,
	"sharp": 1.05,
}
const BONUS_MODE_ORDER := ["hot_hand", "progressive", "press"]
const BONUS_MODE_LABEL := {
	"hot_hand": "Hot Hand Side Bet",
	"progressive": "Five-Kind Progressive",
	"press": "Clean-Win Press",
}

const CATEGORY_RANK := {
	"high_card": 10,
	"one_pair": 20,
	"two_pair": 30,
	"three_kind": 40,
	"straight": 50,
	"full_house": 60,
	"four_kind": 70,
	"five_kind": 90,
	"crew_missing": 10,
	"ship_captain_crew": 55,
	"perfect_cargo": 72,
	"under_seven": 25,
	"over_seven": 35,
	"bar_seven": 65,
	"called_high": 10,
	"called_pair": 25,
	"called_trips": 45,
	"made_four": 72,
	"made_five": 92,
}
const CATEGORY_LABEL := {
	"high_card": "High Card",
	"one_pair": "One Pair",
	"two_pair": "Two Pair",
	"three_kind": "Three of a Kind",
	"straight": "Straight",
	"full_house": "Full House",
	"four_kind": "Four of a Kind",
	"five_kind": "Five of a Kind",
	"crew_missing": "Missing Crew",
	"ship_captain_crew": "Ship Captain Crew",
	"perfect_cargo": "Heavy Cargo",
	"under_seven": "Under Seven",
	"over_seven": "Over Seven",
	"bar_seven": "Bar Seven",
	"called_high": "High Call",
	"called_pair": "Pair Call",
	"called_trips": "Trips Call",
	"made_four": "Four Call",
	"made_five": "Five Call",
}
const PAYTABLES := {
	"poker_dice": {
		"one_pair": 1.45,
		"two_pair": 1.75,
		"three_kind": 2.20,
		"straight": 2.40,
		"full_house": 2.80,
		"four_kind": 3.70,
		"five_kind": 9.00,
	},
	"ship_captain_crew": {
		"ship_captain_crew": 2.10,
		"perfect_cargo": 3.60,
	},
	"over_under_7": {
		"under_seven": 1.30,
		"over_seven": 1.43,
		"bar_seven": 2.80,
	},
	"bluff_call": {
		"called_pair": 1.45,
		"called_trips": 2.10,
		"made_four": 3.60,
		"made_five": 9.00,
	},
}
const PAYTABLE_DISPLAY_ORDER := {
	"poker_dice": ["five_kind", "four_kind", "full_house", "straight", "three_kind", "two_pair", "one_pair"],
	"ship_captain_crew": ["perfect_cargo", "ship_captain_crew"],
	"over_under_7": ["bar_seven", "over_seven", "under_seven"],
	"bluff_call": ["made_five", "made_four", "called_trips", "called_pair"],
}
const SIDE_BONUS_MULT := {
	"hot_hand": 3,
	"progressive": 8,
	"press": 3,
}
const DIE_WORD := {1: "One", 2: "Two", 3: "Three", 4: "Four", 5: "Five", 6: "Six"}
const DIE_WORD_PLURAL := {1: "Ones", 2: "Twos", 3: "Threes", 4: "Fours", 5: "Fives", 6: "Sixes"}

const PLAYER_ROW_ORIGIN := Vector2(56, 132)
const HOUSE_ROW_ORIGIN := Vector2(56, 248)
const DIE_SIZE := Vector2(58, 58)
const DIE_SPACING := 78.0


func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
	var result: Dictionary = super.enter(run_state, environment)
	var state: Dictionary = _dice_state(run_state, environment)
	result["message"] = "%s runs %s at the %s. Best of three, chip ladder locked." % [
		str(state.get("house_name", "The house")),
		str(state.get("ruleset_label", "Bar Dice")),
		str(state.get("bar_name", "bar")),
	]
	return result


func generate_environment_state(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var ruleset := str(rng.pick(RULESET_ORDER, "poker_dice"))
	var tier := str(rng.pick(EDGE_TIER_ORDER, "standard"))
	var bonus_mode := str(rng.pick(BONUS_MODE_ORDER, "hot_hand"))
	var house_name := str(rng.pick(["Big Sal", "The Rail", "Mac", "Odette", "The Cooler", "Whistle"], "The House"))
	var bar_name := str(rng.pick(["back bar", "rail counter", "corner stool", "house cup", "long bar"], "bar"))
	var loaded_tell := str(rng.pick([
		"the cup hangs a beat too long",
		"one die always lands proud",
		"your thumb rides the rim",
		"the toss reads a touch flat",
	], "the cup hangs a beat too long"))
	var ladder: Array = _generated_stake_ladder(environment, rng)
	var default_index := clampi(ladder.size() / 2, 0, maxi(0, ladder.size() - 1))
	var table_key := "%s:%s:%s:%s:%s" % [str(run_state.seed_text if run_state != null else "bar"), str(environment.get("id", "")), ruleset, tier, bonus_mode]
	var base_progressive := maxi(40, int(ladder[ladder.size() - 1]) * rng.randi_range(18, 30))
	return _normalize_state({
		"schema": STATE_SCHEMA,
		"version": STATE_VERSION,
		"table_key": table_key,
		"house_name": house_name,
		"bar_name": bar_name,
		"ruleset_family": ruleset,
		"ruleset_label": str(RULESET_LABEL.get(ruleset, "Bar Dice")),
		"edge_tier": tier,
		"edge_label": str(EDGE_TIER_LABEL.get(tier, "House Rack")),
		"bonus_mode": bonus_mode,
		"bonus_label": str(BONUS_MODE_LABEL.get(bonus_mode, "Hot Hand Side Bet")),
		"stake_ladder": ladder,
		"selected_stake_index": default_index,
		"rail_bettors": _generate_rail_bettors(rng, ladder),
		"progressive_base": base_progressive,
		"progressive_pot": base_progressive,
		"loaded_die": {
			"label": "Loaded Die",
			"tell": loaded_tell,
		},
		"rounds_played": 0,
		"last_result": {},
	})


func wager_cost_for_context(_action_id: String, stake: int, run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> int:
	var state: Dictionary = _dice_state(run_state, environment)
	var active_stake := _active_stake_from_context(stake, state, ui_state, run_state, environment)
	return active_stake + _side_bet_for(active_stake, state)


func surface_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var state: Dictionary = _dice_state(run_state, environment)
	var ui: Dictionary = _normalized_ui_state(run_state, environment, ui_state, state)
	var last_result: Dictionary = _copy_dict(state.get("last_result", {}))
	var rolled := bool(ui.get("rolled", false))
	var showing_result := not rolled and not last_result.is_empty()
	var phase := "select" if rolled else ("settled" if showing_result else "bet")
	var ruleset := str(state.get("ruleset_family", "poker_dice"))
	var active_stake := _active_stake_from_context(0, state, ui, run_state, environment)
	var side_bet := _side_bet_for(active_stake, state)

	var player_dice: Array = []
	var house_dice: Array = [0, 0, 0, 0, 0]
	var scoring_indices: Array = []
	var house_scoring_indices: Array = []
	var house_revealed := false
	var blurb := ""
	var house_blurb := ""
	var outcome := ""
	var payout_mult := 0.0
	if phase == "select":
		player_dice = _int_dice(ui.get("dice", []))
	elif phase == "settled":
		player_dice = _int_dice(last_result.get("player_dice", []))
		house_dice = _int_dice(last_result.get("house_dice", []))
		scoring_indices = _index_array(last_result.get("player_scoring_indices", []))
		house_scoring_indices = _index_array(last_result.get("house_scoring_indices", []))
		house_revealed = true
		blurb = str(last_result.get("player_blurb", ""))
		house_blurb = str(last_result.get("house_blurb", ""))
		outcome = str(last_result.get("outcome", ""))
		payout_mult = float(last_result.get("payout_mult", 0.0))
	else:
		player_dice = _generate_opening(run_state, state)
	if player_dice.size() != DICE_COUNT:
		player_dice = _generate_opening(run_state, state)

	var reroll: Array = _index_array(ui.get("reroll", [])) if phase == "select" else []
	var suggested: Array = _suggested_reroll_for_ruleset(player_dice, ruleset) if phase != "settled" else []
	var kept_dice: Array = _kept_dice(player_dice, reroll)
	var loaded_armed := bool(ui.get("loaded_armed", false)) and phase == "select"
	var palm_armed := bool(ui.get("palm_armed", false)) and phase == "select"
	var loaded_value := int(ui.get("loaded_value", 0))
	if loaded_armed and loaded_value <= 0:
		loaded_value = _loaded_value_for_ruleset(kept_dice if not kept_dice.is_empty() else player_dice, ruleset)

	var tumble: Dictionary = _active_tumble(ui, last_result, rolled)
	var pit_boss: Dictionary = run_state.pit_boss_watch_status(environment)
	var press_offer: Dictionary = _copy_dict(last_result.get("press_offer", {}))
	var press_available := phase == "settled" and bool(press_offer.get("available", false))
	var rail_bettors := _rail_bettors_for_surface(state, active_stake, side_bet)

	return GameModule.surface_spec({
		"surface_renderer": "dice_table",
		"surface_life": "dice_bar",
		"surface_cast": "none",
		"surface_controls_native": true,
		"surface_stake_controls_required": false,
		"surface_embeds_outcomes": true,
		"surface_animates_idle": false,
		"surface_realtime_state_refresh": false,
		"phase": phase,
		"house_name": str(state.get("house_name", "The house")),
		"bar_name": str(state.get("bar_name", "bar")),
		"table_key": str(state.get("table_key", "")),
		"ruleset_family": ruleset,
		"ruleset_label": str(state.get("ruleset_label", RULESET_LABEL.get(ruleset, "Bar Dice"))),
		"edge_tier": str(state.get("edge_tier", "standard")),
		"edge_label": str(state.get("edge_label", "House Rack")),
		"bonus_mode": str(state.get("bonus_mode", "hot_hand")),
		"bonus_label": str(state.get("bonus_label", "Hot Hand Side Bet")),
		"rail_bettors": rail_bettors,
		"stake_ladder": _int_array(state.get("stake_ladder", [])),
		"selected_stake_index": _selected_stake_index(state, ui),
		"active_stake": active_stake,
		"side_bet": side_bet,
		"bet_meter": active_stake + side_bet,
		"chips_meter": maxi(0, run_state.bankroll),
		"win_meter": int(last_result.get("gross_payout", 0)) if showing_result else 0,
		"progressive_pot": int(state.get("progressive_pot", 0)),
		"loaded_label": str(_copy_dict(state.get("loaded_die", {})).get("label", "Loaded Die")),
		"loaded_tell": str(_copy_dict(state.get("loaded_die", {})).get("tell", "")),
		"player": player_dice,
		"house": house_dice,
		"house_revealed": house_revealed,
		"reroll": reroll,
		"suggested_reroll": suggested,
		"scoring_indices": scoring_indices,
		"house_scoring_indices": house_scoring_indices,
		"loaded_armed": loaded_armed,
		"palm_armed": palm_armed,
		"loaded_value": loaded_value,
		"player_blurb": blurb,
		"house_blurb": house_blurb,
		"outcome": outcome,
		"payout_mult": payout_mult,
		"paytable_rows": _paytable_rows(state, active_stake),
		"match_legs": _copy_array(last_result.get("match_legs", [])),
		"match_summary": str(last_result.get("match_summary", "")),
		"info_text": _info_text(phase, player_dice, reroll, last_result, loaded_armed, palm_armed, loaded_value, state),
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
		"surface_action_bindings": {
			"legal": {"action": "bar_dice_resolve", "index": 0},
			"cheat": {"action": "bar_dice_load", "index": 0},
			"bar_dice_palm": {"action": "bar_dice_palm", "index": 0},
			"bar_dice_press": {"action": "bar_dice_press", "index": 0},
			"bar_dice_stake": {"action": "bar_dice_stake", "index": 0},
		},
		"surface_audio": GameModule.surface_audio_spec({
			"profile_id": "bar_dice_table",
			"action_cues": {
				"bar_dice_roll": "machine_button",
				"bar_dice_resolve": "machine_button",
				"bar_dice_load": "machine_button",
				"bar_dice_palm": "machine_button",
				"bar_dice_press": "machine_button",
				"bar_dice_select": "machine_button",
				"bar_dice_stake": "machine_button",
				"bar_dice_rail_bet": "machine_button",
			},
		}),
	})


func draw_surface(surface, surface_state: Dictionary, _render_context: Dictionary = {}) -> bool:
	if str(surface_state.get("surface_renderer", "")) != "dice_table":
		return false
	var phase := str(surface_state.get("phase", "bet"))
	_draw_dice_room(surface)
	surface.surface_title("BAR DICE", Vector2(34, 24), C_YELLOW)
	surface.surface_label("%s - %s" % [str(surface_state.get("house_name", "House")), str(surface_state.get("ruleset_label", "Dice"))], Vector2(210, 30), 15, C_PINK_2)
	surface.surface_label("%s / %s" % [str(surface_state.get("edge_label", "")), str(surface_state.get("bonus_label", ""))], Vector2(560, 32), 13, C_CYAN)

	_draw_meter_strip(surface, surface_state)
	_draw_chip_ladder(surface, surface_state, phase)

	surface.surface_label("YOUR CUP", Vector2(56, 114), 15, C_TEAL)
	var player: Array = _int_dice(surface_state.get("player", []))
	if player.size() != DICE_COUNT:
		player = [0, 0, 0, 0, 0]
	var reroll: Array = _index_array(surface_state.get("reroll", []))
	var suggested: Array = _index_array(surface_state.get("suggested_reroll", []))
	var scoring: Array = _index_array(surface_state.get("scoring_indices", []))
	_draw_dice_row(surface, player, PLAYER_ROW_ORIGIN, reroll, suggested, scoring, false)
	if phase == "select":
		_add_dice_row_hits(surface, player, PLAYER_ROW_ORIGIN, "bar_dice_select")
		surface.surface_label("REROLL marked dice; teal dice count toward the current pack.", Vector2(56, 200), 12, C_YELLOW)

	surface.surface_label("HOUSE CUP", Vector2(56, 230), 15, C_PINK_2)
	var house: Array = _int_dice(surface_state.get("house", []))
	if house.size() != DICE_COUNT:
		house = [0, 0, 0, 0, 0]
	var house_revealed := bool(surface_state.get("house_revealed", false))
	var house_scoring: Array = _index_array(surface_state.get("house_scoring_indices", []))
	_draw_dice_row(surface, house if house_revealed else [0, 0, 0, 0, 0], HOUSE_ROW_ORIGIN, [], [], house_scoring if house_revealed else [], not house_revealed)

	_draw_info_panel(surface, surface_state)
	_draw_rail_bettors(surface, surface_state, phase)
	_draw_controls(surface, surface_state, phase)
	return true


func surface_action_command(surface_action: String, index: int, confirm_requested: bool, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var state: Dictionary = _dice_state(run_state, environment)
	var next: Dictionary = _normalized_ui_state(run_state, environment, ui_state, state)
	match surface_action:
		"bar_dice_rail_bet":
			if bool(next.get("rolled", false)):
				return _message_command(next, "Rail bets are locked once the cup is out.")
			return _rail_bettor_command(index, next, state, run_state, environment)
		"bar_dice_stake":
			if bool(next.get("rolled", false)):
				return _message_command(next, "Settle this cup before changing chips.")
			var ladder: Array = _int_array(state.get("stake_ladder", []))
			if index >= 0 and index < ladder.size():
				next["selected_stake_index"] = index
				next.erase("table_social_alignment")
				return GameModule.surface_command({
					"handled": true,
					"ui_state": next,
					"selected_index": index,
					"preserve_surface_ui_state": true,
					"message": "Chip set to $%d." % int(ladder[index]),
				})
			return _message_command(next, "That chip is off the rack.")
		"bar_dice_roll":
			next["rolled"] = true
			next["dice"] = _generate_opening(run_state, state)
			next["reroll"] = []
			next["loaded_armed"] = false
			next["palm_armed"] = false
			next.erase("loaded_value")
			var now := Time.get_ticks_msec()
			next["tumble_id"] = "open_%d" % now
			next["tumble_started_msec"] = now
			return GameModule.surface_command({
				"handled": true,
				"ui_state": next,
				"selected_index": index,
				"preserve_surface_ui_state": true,
				"message": "The dice spill across the bar. Keep or reroll, then resolve the leg.",
			})
		"bar_dice_select":
			if not bool(next.get("rolled", false)):
				return _message_command(next, "Toss the cup first.")
			var marks: Array = _index_array(next.get("reroll", []))
			if marks.has(index):
				marks.erase(index)
			elif index >= 0 and index < DICE_COUNT:
				marks.append(index)
			marks.sort()
			next["reroll"] = marks
			next["loaded_armed"] = false
			next["palm_armed"] = false
			next.erase("loaded_value")
			return GameModule.surface_command({
				"handled": true,
				"ui_state": next,
				"selected_index": index,
				"preserve_surface_ui_state": true,
				"message": "Reroll marks: %s." % _reroll_summary(marks),
			})
		"bar_dice_resolve":
			next["loaded_armed"] = false
			next["palm_armed"] = false
			next.erase("loaded_value")
			return _action_command("roll", "legal", confirm_requested, next, index, _resolve_prompt(next, "roll"))
		"bar_dice_load":
			var dice: Array = _int_dice(next.get("dice", []))
			var kept: Array = _kept_dice(dice, _index_array(next.get("reroll", [])))
			var loaded_value := _loaded_value_for_ruleset(kept if not kept.is_empty() else dice, str(state.get("ruleset_family", "poker_dice")))
			next["loaded_armed"] = true
			next["palm_armed"] = false
			next["loaded_value"] = loaded_value
			return _action_command("loaded_toss", "cheat", confirm_requested, next, index, _resolve_prompt(next, "loaded_toss"))
		"bar_dice_palm":
			next["loaded_armed"] = false
			next["palm_armed"] = true
			next.erase("loaded_value")
			return _action_command("palmed_swap", "cheat", confirm_requested, next, index, _resolve_prompt(next, "palmed_swap"))
		"bar_dice_press":
			return _action_command("press", "legal", confirm_requested, next, index, "Press the clean win. Click again to double or lose the risk.")
	return {"handled": false}


func resolve(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return resolve_with_context(action_id, stake, run_state, environment, rng, {})


func resolve_with_context(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary = {}) -> Dictionary:
	if action_id == "press":
		return _resolve_press(stake, run_state, environment, rng)
	if action_id != "roll" and action_id != "loaded_toss" and action_id != "palmed_swap":
		return _empty_result(action_id, stake, environment, "That bar dice action is not available.")
	var is_cheat := action_id == "loaded_toss" or action_id == "palmed_swap"
	var state: Dictionary = _dice_state(run_state, environment)
	var ruleset := str(state.get("ruleset_family", "poker_dice"))
	var adjusted_stake := _active_stake_from_context(stake, state, ui_state, run_state, environment)
	var side_bet := _side_bet_for(adjusted_stake, state)
	var total_cost := adjusted_stake + side_bet
	if total_cost > run_state.bankroll:
		side_bet = maxi(0, run_state.bankroll - adjusted_stake)
		total_cost = adjusted_stake + side_bet
	if adjusted_stake <= 0 or total_cost <= 0 or total_cost > run_state.bankroll:
		return _empty_result(action_id, stake, environment, "You do not have enough bankroll for this chip rack.")

	var match_data: Dictionary = _resolve_match(action_id, run_state, state, rng, ui_state)
	var player_wins := int(match_data.get("player_wins", 0))
	var house_wins := int(match_data.get("house_wins", 0))
	var outcome := "win" if player_wins > house_wins else ("push" if player_wins == house_wins else "lose")
	var luck_bonus := clampi(run_state.luck_win_chance_bonus() + _item_bonus("win_chance", run_state, is_cheat), 0, 45)
	if outcome == "lose" and luck_bonus > 0 and rng.randi_range(1, 100) <= luck_bonus:
		match_data = _luck_flip_match(match_data)
		player_wins = int(match_data.get("player_wins", 0))
		house_wins = int(match_data.get("house_wins", 0))
		outcome = "win" if player_wins > house_wins else ("push" if player_wins == house_wins else "lose")

	var best_score: Dictionary = _copy_dict(match_data.get("best_player_score", {}))
	if best_score.is_empty():
		best_score = _score_for_ruleset(_int_dice(match_data.get("player_dice", [])), ruleset)
	var player_category := str(best_score.get("category", "high_card"))
	var payout_mult := _payout_multiplier(player_category, state)
	var gross_payout := 0
	if outcome == "win":
		gross_payout = maxi(adjusted_stake + 1, int(round(float(adjusted_stake) * payout_mult)))
	elif outcome == "push":
		gross_payout = adjusted_stake

	var side_result: Dictionary = _resolve_side_bet(match_data, state, side_bet)
	var side_award := int(side_result.get("award", 0))
	var progressive_award := int(side_result.get("progressive_award", 0))
	var progressive_hit := bool(side_result.get("progressive_hit", false))
	var bankroll_delta := gross_payout + side_award + progressive_award - total_cost
	var won := outcome == "win"
	if won:
		bankroll_delta = maxi(1, bankroll_delta + run_state.luck_payout_bonus(adjusted_stake, true) + _item_bonus("win_bonus", run_state, is_cheat))
	elif bankroll_delta < 0:
		bankroll_delta = mini(0, bankroll_delta + _item_bonus("loss_reduction", run_state, is_cheat))

	var suspicion_delta := 0
	var security_message := ""
	var pit_boss_summary := ""
	var pit_boss_watched := false
	var pit_boss_heat_bonus := 0
	var skill_outcome := ""
	var ended := false
	if is_cheat:
		var heat: Dictionary = _cheat_heat(action_id, adjusted_stake, run_state, environment)
		suspicion_delta = int(heat.get("suspicion_delta", 0))
		security_message = str(heat.get("security_message", ""))
		pit_boss_summary = str(heat.get("pit_boss_summary", ""))
		pit_boss_watched = bool(heat.get("pit_boss_watched", false))
		pit_boss_heat_bonus = int(heat.get("pit_boss_heat_bonus", 0))
		skill_outcome = "loaded_die" if action_id == "loaded_toss" else "palmed_swap"
		ended = bool(heat.get("ended", false))
		bankroll_delta += int(heat.get("bankroll_delta", 0))

	var new_pot := int(state.get("progressive_pot", 0))
	if progressive_hit:
		new_pot = int(state.get("progressive_base", 80))
	else:
		new_pot += maxi(1, int(ceil(float(side_bet) * 0.50))) if side_bet > 0 else 0
	state["progressive_pot"] = new_pot

	var press_offer: Dictionary = {}
	if won and not is_cheat and bankroll_delta > 0:
		press_offer = {
			"available": true,
			"risk": mini(maxi(1, bankroll_delta), adjusted_stake * 12),
			"level": 0,
			"cap": PRESS_CAP,
		}
	var resolved_at := Time.get_ticks_msec()
	var player_score: Dictionary = _copy_dict(match_data.get("player_score", {}))
	var house_score: Dictionary = _copy_dict(match_data.get("house_score", {}))
	var player_dice: Array = _int_dice(match_data.get("player_dice", []))
	var house_dice: Array = _int_dice(match_data.get("house_dice", []))
	var summary := _outcome_message(match_data, outcome, bankroll_delta, suspicion_delta, action_id, pit_boss_summary, security_message, side_result, state)
	_apply_rail_rapport_after_bar_dice(state, ui_state, adjusted_stake, side_bet, outcome)
	state["last_result"] = {
		"player_dice": player_dice,
		"house_dice": house_dice,
		"player_category": player_category,
		"house_category": str(house_score.get("category", "high_card")),
		"player_scoring_indices": _index_array(player_score.get("scoring_indices", [])),
		"house_scoring_indices": _index_array(house_score.get("scoring_indices", [])),
		"player_blurb": _hand_blurb(best_score),
		"house_blurb": _hand_blurb(house_score),
		"outcome": outcome,
		"payout_mult": payout_mult,
		"stake": adjusted_stake,
		"side_bet": side_bet,
		"gross_payout": gross_payout + side_award + progressive_award,
		"side_award": side_award,
		"progressive_award": progressive_award,
		"progressive_hit": progressive_hit,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"loaded": action_id == "loaded_toss",
		"palmed": action_id == "palmed_swap",
		"loaded_value": int(match_data.get("loaded_value", 0)),
		"match_legs": _copy_array(match_data.get("legs", [])),
		"match_summary": "%d-%d in best of %d" % [player_wins, house_wins, MATCH_LEGS],
		"summary": summary,
		"press_offer": press_offer,
		"tumble_id": "settle_%d" % resolved_at,
		"resolved_at_msec": resolved_at,
	}
	state["rounds_played"] = int(state.get("rounds_played", 0)) + 1
	_update_environment_state(environment, state)

	var story_entry := {
		"type": "game_action",
		"game_id": get_id(),
		"action_id": action_id,
		"won": won,
		"outcome": outcome,
		"ruleset": ruleset,
		"edge_tier": str(state.get("edge_tier", "standard")),
		"bonus_mode": str(state.get("bonus_mode", "hot_hand")),
		"player_category": player_category,
		"house_category": str(house_score.get("category", "high_card")),
		"match_score": "%d-%d" % [player_wins, house_wins],
		"payout": gross_payout + side_award + progressive_award,
		"stake_cost": total_cost,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"loaded": action_id == "loaded_toss",
		"palmed": action_id == "palmed_swap",
		"skill_outcome": skill_outcome,
		"pit_boss_watched": pit_boss_watched,
		"pit_boss_heat_bonus": pit_boss_heat_bonus,
		"pit_boss_summary": pit_boss_summary,
		"security_message": security_message,
		"skill_security_pressure_checked": is_cheat,
		"environment_id": environment.get("id", ""),
	}
	var deltas: Dictionary = GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["suspicion_delta"] = suspicion_delta
	deltas["story_log"] = [story_entry]
	deltas["messages"] = [summary]
	deltas["ended"] = ended
	var result: Dictionary = GameModule.build_action_result({
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
	})
	result["bar_dice_player_dice"] = player_dice
	result["bar_dice_house_dice"] = house_dice
	result["bar_dice_player_category"] = player_category
	result["bar_dice_house_category"] = str(house_score.get("category", "high_card"))
	result["bar_dice_outcome"] = outcome
	result["bar_dice_payout_mult"] = payout_mult
	result["bar_dice_loaded"] = action_id == "loaded_toss"
	result["bar_dice_palmed"] = action_id == "palmed_swap"
	result["bar_dice_loaded_value"] = int(match_data.get("loaded_value", 0))
	result["bar_dice_match_legs"] = _copy_array(match_data.get("legs", []))
	result["bar_dice_player_legs"] = player_wins
	result["bar_dice_house_legs"] = house_wins
	result["bar_dice_stake"] = adjusted_stake
	result["bar_dice_side_bet"] = side_bet
	result["bar_dice_side_award"] = side_award
	result["bar_dice_progressive_award"] = progressive_award
	result["bar_dice_progressive_hit"] = progressive_hit
	result["bar_dice_ruleset"] = ruleset
	result["bar_dice_edge_tier"] = str(state.get("edge_tier", "standard"))
	result["bar_dice_bonus_mode"] = str(state.get("bonus_mode", "hot_hand"))
	result["bar_dice_luck_bonus"] = luck_bonus
	if is_cheat:
		result["bar_dice_pit_boss_watched"] = pit_boss_watched
		result["bar_dice_pit_boss_heat_bonus"] = pit_boss_heat_bonus
		result["skill_outcome"] = skill_outcome
	GameModule.apply_result(run_state, result, rng)
	return result


func environment_object_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var state: Dictionary = _dice_state(run_state, environment)
	if state.is_empty():
		return {}
	var last_result: Dictionary = _copy_dict(state.get("last_result", {}))
	var rounds := int(state.get("rounds_played", 0))
	var badge := str(state.get("ruleset_label", "DICE")).left(5).to_upper()
	if not last_result.is_empty():
		badge = str(last_result.get("outcome", "dice")).to_upper()
	return {
		"runtime_state": {
			"rounds_played": rounds,
			"last_outcome": str(last_result.get("outcome", "")),
			"last_bankroll_delta": int(last_result.get("bankroll_delta", 0)),
		},
		"visual_state": {
			"house": str(state.get("house_name", "the house")),
			"ruleset": str(state.get("ruleset_label", "Bar Dice")),
			"bonus": str(state.get("bonus_label", "")),
		},
		"status_summary": "%s runs %s. %d match%s tossed." % [
			str(state.get("house_name", "The house")),
			str(state.get("ruleset_label", "bar dice")),
			rounds,
			"" if rounds == 1 else "es",
		],
		"effect_summary": "%s with %s chips." % [str(state.get("bonus_label", "Side bet")), str(state.get("edge_label", "House Rack"))],
		"state_badge": badge,
	}


# --- Resolution helpers ------------------------------------------------------

func _resolve_match(action_id: String, run_state: RunState, state: Dictionary, rng: RngStream, ui_state: Dictionary) -> Dictionary:
	var ruleset := str(state.get("ruleset_family", "poker_dice"))
	var legs: Array = []
	var player_wins := 0
	var house_wins := 0
	var loaded_value := 0
	var final_player: Array = []
	var final_house: Array = []
	var final_player_score: Dictionary = {}
	var final_house_score: Dictionary = {}
	var best_player_score: Dictionary = {}
	for leg_index in range(MATCH_LEGS):
		var player_open: Array = _opening_dice(run_state, state, ui_state) if leg_index == 0 else _roll_dice(rng, DICE_COUNT)
		var player_dice: Array = _play_player_leg(player_open, rng, ruleset, ui_state if leg_index == 0 else {})
		if leg_index == 0 and action_id == "loaded_toss":
			loaded_value = _loaded_value_for_ruleset(player_dice, ruleset)
			player_dice = _apply_loaded_die(player_dice, loaded_value)
		elif leg_index == 0 and action_id == "palmed_swap":
			player_dice = _apply_palmed_swap(player_dice, ruleset)
		var house_open: Array = _roll_dice(rng, DICE_COUNT)
		var house_dice: Array = _house_strategy_play(house_open, rng, ruleset)
		var player_score: Dictionary = _score_for_ruleset(player_dice, ruleset)
		var house_score: Dictionary = _score_for_ruleset(house_dice, ruleset)
		var comparison := _compare_signatures(player_score.get("signature", []), house_score.get("signature", []))
		var leg_outcome := "win" if comparison > 0 else ("push" if comparison == 0 else "lose")
		if comparison > 0:
			player_wins += 1
			if best_player_score.is_empty() or _compare_signatures(player_score.get("signature", []), best_player_score.get("signature", [])) > 0:
				best_player_score = player_score.duplicate(true)
		elif comparison < 0:
			house_wins += 1
		final_player = player_dice
		final_house = house_dice
		final_player_score = player_score
		final_house_score = house_score
		legs.append({
			"index": leg_index + 1,
			"player_dice": player_dice,
			"house_dice": house_dice,
			"player_score": player_score,
			"house_score": house_score,
			"outcome": leg_outcome,
		})
		if player_wins >= 2 or house_wins >= 2:
			break
	if best_player_score.is_empty():
		best_player_score = final_player_score.duplicate(true)
	return {
		"legs": legs,
		"player_wins": player_wins,
		"house_wins": house_wins,
		"player_dice": final_player,
		"house_dice": final_house,
		"player_score": final_player_score,
		"house_score": final_house_score,
		"best_player_score": best_player_score,
		"loaded_value": loaded_value,
	}


func _play_player_leg(open_dice: Array, rng: RngStream, ruleset: String, ui_state: Dictionary) -> Array:
	if bool(ui_state.get("rolled", false)):
		var dice: Array = _int_dice(ui_state.get("dice", []))
		if dice.size() != DICE_COUNT:
			dice = open_dice.duplicate()
		var reroll: Array = _index_array(ui_state.get("reroll", []))
		for index_value in reroll:
			var die_index := int(index_value)
			if die_index >= 0 and die_index < dice.size():
				dice[die_index] = rng.randi_range(1, DIE_FACES)
		return dice
	var marks: Array = _suggested_reroll_for_ruleset(open_dice, ruleset)
	var result: Array = open_dice.duplicate()
	for index_value in marks:
		var die_index := int(index_value)
		if die_index >= 0 and die_index < result.size():
			result[die_index] = rng.randi_range(1, DIE_FACES)
	return result


func _house_strategy_play(open_dice: Array, rng: RngStream, ruleset: String = "poker_dice") -> Array:
	var hand: Array = _house_shake(open_dice, rng, ruleset)
	hand = _house_shake(hand, rng, ruleset)
	return hand


func _house_shake(dice: Array, rng: RngStream, ruleset: String) -> Array:
	var marks: Array = _suggested_reroll_for_ruleset(dice, ruleset)
	var shaken: Array = dice.duplicate()
	for index_value in marks:
		var die_index := int(index_value)
		if die_index >= 0 and die_index < shaken.size():
			shaken[die_index] = rng.randi_range(1, DIE_FACES)
	return shaken


func _luck_flip_match(match_data: Dictionary) -> Dictionary:
	var updated: Dictionary = match_data.duplicate(true)
	var legs: Array = _copy_array(updated.get("legs", []))
	for i in range(legs.size() - 1, -1, -1):
		if typeof(legs[i]) != TYPE_DICTIONARY:
			continue
		var leg: Dictionary = legs[i]
		if str(leg.get("outcome", "")) == "lose":
			leg["outcome"] = "win"
			leg["luck_flip"] = true
			legs[i] = leg
			updated["player_wins"] = int(updated.get("player_wins", 0)) + 1
			updated["house_wins"] = maxi(0, int(updated.get("house_wins", 0)) - 1)
			updated["legs"] = legs
			var player_score: Dictionary = _copy_dict(leg.get("player_score", {}))
			updated["best_player_score"] = player_score
			return updated
	return updated


func _resolve_side_bet(match_data: Dictionary, state: Dictionary, side_bet: int) -> Dictionary:
	if side_bet <= 0:
		return {"award": 0, "progressive_award": 0, "progressive_hit": false, "reason": ""}
	var legs: Array = _copy_array(match_data.get("legs", []))
	var bonus_mode := str(state.get("bonus_mode", "hot_hand"))
	var best_category := ""
	var hit_five_kind := false
	var clean_sweep := int(match_data.get("player_wins", 0)) >= 2 and int(match_data.get("house_wins", 0)) == 0
	for leg_value in legs:
		if typeof(leg_value) != TYPE_DICTIONARY:
			continue
		var leg: Dictionary = leg_value
		var score: Dictionary = _copy_dict(leg.get("player_score", {}))
		var category := str(score.get("category", ""))
		if category == "five_kind" or category == "made_five":
			hit_five_kind = true
		if best_category.is_empty() or _category_power(category) > _category_power(best_category):
			best_category = category
	if bonus_mode == "progressive" and hit_five_kind:
		return {
			"award": side_bet * int(SIDE_BONUS_MULT.get(bonus_mode, 8)),
			"progressive_award": int(state.get("progressive_pot", 0)),
			"progressive_hit": true,
			"reason": "five-kind progressive",
		}
	if bonus_mode == "hot_hand" and _category_power(best_category) >= _category_power("four_kind"):
		return {"award": side_bet * int(SIDE_BONUS_MULT.get(bonus_mode, 7)), "progressive_award": 0, "progressive_hit": false, "reason": "hot hand"}
	if bonus_mode == "press" and clean_sweep:
		return {"award": side_bet * int(SIDE_BONUS_MULT.get(bonus_mode, 5)), "progressive_award": 0, "progressive_hit": false, "reason": "clean sweep"}
	return {"award": 0, "progressive_award": 0, "progressive_hit": false, "reason": ""}


func _resolve_press(stake: int, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var state: Dictionary = _dice_state(run_state, environment)
	var last_result: Dictionary = _copy_dict(state.get("last_result", {}))
	var offer: Dictionary = _copy_dict(last_result.get("press_offer", {}))
	if not bool(offer.get("available", false)):
		return _empty_result("press", stake, environment, "No clean win is available to press.")
	var risk := mini(maxi(1, int(offer.get("risk", 0))), maxi(0, run_state.bankroll))
	if risk <= 0:
		return _empty_result("press", stake, environment, "You do not have enough chips to press.")
	var level := int(offer.get("level", 0))
	var chance := clampi(47 + run_state.luck_win_chance_bonus() + _item_bonus("win_chance", run_state, false), 5, 85)
	var press_won := rng.randi_range(1, 100) <= chance
	var bankroll_delta := risk if press_won else -risk
	var next_offer: Dictionary = {}
	if press_won and level + 1 < int(offer.get("cap", PRESS_CAP)):
		next_offer = {
			"available": true,
			"risk": mini(risk * 2, maxi(1, int(last_result.get("stake", risk)) * 16)),
			"level": level + 1,
			"cap": int(offer.get("cap", PRESS_CAP)),
		}
	last_result["press_offer"] = next_offer
	last_result["press_result"] = "win" if press_won else "lose"
	last_result["bankroll_delta"] = int(last_result.get("bankroll_delta", 0)) + bankroll_delta
	last_result["summary"] = "Press %s for %+d. %s" % ["hits" if press_won else "misses", bankroll_delta, str(last_result.get("summary", ""))]
	state["last_result"] = last_result
	_update_environment_state(environment, state)
	var deltas: Dictionary = GameModule.empty_result_deltas()
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
	var result: Dictionary = GameModule.build_action_result({
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


func _cheat_heat(action_id: String, adjusted_stake: int, run_state: RunState, environment: Dictionary) -> Dictionary:
	var cheat_def: Dictionary = _action_def(action_id)
	var base_heat := int(cheat_def.get("suspicion_delta", 10))
	var pit_boss_status: Dictionary = run_state.pit_boss_watch_status(environment)
	var pit_boss_bonus := int(pit_boss_status.get("cheat_heat_bonus", 0)) if bool(pit_boss_status.get("active", false)) else 0
	var raw_heat := maxi(1, base_heat + _item_bonus("cheat_suspicion_delta", run_state, true) + run_state.security_risk_bonus("cheat") + pit_boss_bonus)
	var suspicion_delta := run_state.alcohol_adjusted_suspicion_delta(raw_heat)
	var security_pressure: Dictionary = run_state.security_action_pressure("cheat", adjusted_stake, run_state.suspicion_level() + suspicion_delta)
	return {
		"suspicion_delta": suspicion_delta,
		"bankroll_delta": int(security_pressure.get("bankroll_delta", 0)),
		"security_message": str(security_pressure.get("message", "")),
		"pit_boss_summary": str(pit_boss_status.get("summary", "")) if bool(pit_boss_status.get("active", false)) else "",
		"pit_boss_watched": bool(pit_boss_status.get("watched", false)),
		"pit_boss_heat_bonus": pit_boss_bonus,
		"skill_security_pressure_checked": true,
		"ended": bool(security_pressure.get("ended", false)),
		"alcohol_multiplier": run_state.alcohol_heat_multiplier(),
	}


# --- State helpers -----------------------------------------------------------

func _dice_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var state: Dictionary = game_states.get(get_id(), {}) if typeof(game_states.get(get_id(), {})) == TYPE_DICTIONARY else {}
	if state.is_empty():
		state = _fallback_state(run_state, environment)
	return _normalize_state(state)


func _fallback_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var rng := RngStream.new()
	rng.configure(_stable_hash("%s:%s:%s" % [get_id(), str(run_state.seed_text if run_state != null else "fallback"), str(environment.get("id", ""))]))
	return generate_environment_state(run_state, environment, rng)


func _normalize_state(state: Dictionary) -> Dictionary:
	var normalized: Dictionary = state.duplicate(true)
	normalized["schema"] = STATE_SCHEMA
	normalized["version"] = STATE_VERSION
	var ruleset := str(normalized.get("ruleset_family", "poker_dice"))
	if not RULESET_ORDER.has(ruleset):
		ruleset = "poker_dice"
	var tier := str(normalized.get("edge_tier", "standard"))
	if not EDGE_TIER_ORDER.has(tier):
		tier = "standard"
	var bonus := str(normalized.get("bonus_mode", "hot_hand"))
	if not BONUS_MODE_ORDER.has(bonus):
		bonus = "hot_hand"
	normalized["ruleset_family"] = ruleset
	normalized["ruleset_label"] = str(normalized.get("ruleset_label", RULESET_LABEL.get(ruleset, "Bar Dice")))
	normalized["edge_tier"] = tier
	normalized["edge_label"] = str(normalized.get("edge_label", EDGE_TIER_LABEL.get(tier, "House Rack")))
	normalized["bonus_mode"] = bonus
	normalized["bonus_label"] = str(normalized.get("bonus_label", BONUS_MODE_LABEL.get(bonus, "Hot Hand Side Bet")))
	normalized["house_name"] = str(normalized.get("house_name", "The house"))
	normalized["bar_name"] = str(normalized.get("bar_name", "bar"))
	normalized["table_key"] = str(normalized.get("table_key", "%s:%s:%s" % [normalized["house_name"], ruleset, bonus]))
	var ladder: Array = _int_array(normalized.get("stake_ladder", []))
	if ladder.is_empty():
		ladder = [1, 2, 5, 10, 20]
	normalized["stake_ladder"] = ladder
	normalized["selected_stake_index"] = clampi(int(normalized.get("selected_stake_index", 0)), 0, maxi(0, ladder.size() - 1))
	normalized["rail_bettors"] = _normalize_rail_bettors(normalized.get("rail_bettors", []), ladder)
	normalized["progressive_base"] = maxi(20, int(normalized.get("progressive_base", int(ladder[ladder.size() - 1]) * 20)))
	normalized["progressive_pot"] = maxi(int(normalized.get("progressive_base", 20)), int(normalized.get("progressive_pot", normalized.get("progressive_base", 20))))
	normalized["loaded_die"] = _copy_dict(normalized.get("loaded_die", {}))
	normalized["rounds_played"] = int(normalized.get("rounds_played", 0))
	normalized["last_result"] = _copy_dict(normalized.get("last_result", {}))
	return normalized


func _update_environment_state(environment: Dictionary, state: Dictionary) -> void:
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	game_states[get_id()] = _normalize_state(state)
	environment["game_states"] = game_states


func _normalized_ui_state(run_state: RunState, _environment: Dictionary, ui_state: Dictionary, state: Dictionary) -> Dictionary:
	var next: Dictionary = ui_state.duplicate(true)
	next["rolled"] = bool(next.get("rolled", false))
	var selected := int(next.get("selected_stake_index", state.get("selected_stake_index", 0)))
	var ladder: Array = _int_array(state.get("stake_ladder", []))
	next["selected_stake_index"] = clampi(selected, 0, maxi(0, ladder.size() - 1))
	if bool(next["rolled"]):
		var dice: Array = _int_dice(next.get("dice", []))
		if dice.size() != DICE_COUNT:
			dice = _generate_opening(run_state, state)
		next["dice"] = dice
		next["reroll"] = _index_array(next.get("reroll", []))
	else:
		next["reroll"] = []
	next["loaded_armed"] = bool(next.get("loaded_armed", false))
	next["palm_armed"] = bool(next.get("palm_armed", false))
	return next


func _generated_stake_ladder(environment: Dictionary, rng: RngStream) -> Array:
	var economic_profile: Dictionary = environment.get("economic_profile", {}) if typeof(environment.get("economic_profile", {})) == TYPE_DICTIONARY else {}
	var floor := maxi(1, int(economic_profile.get("stake_floor", 1)))
	var ceiling := maxi(floor, int(economic_profile.get("stake_ceiling", 80)))
	var templates := [
		[1, 2, 5, 10, 20],
		[2, 5, 10, 25, 50],
		[5, 10, 20, 40, 80],
		[1, 3, 6, 12, 24],
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


func _generate_rail_bettors(rng: RngStream, ladder: Array) -> Array:
	var names := ["Tess", "Milo", "June", "Vale", "Rin", "Cole"]
	var styles := ["main", "side", "press"]
	var colors := ["cyan", "teal", "yellow", "pink", "orange"]
	var result: Array = []
	var clean_ladder := _int_array(ladder)
	if clean_ladder.is_empty():
		clean_ladder = [1, 2, 5, 10, 20]
	for i in range(3):
		var style := str(styles[i % styles.size()])
		var stake := int(clean_ladder[clampi(i + 1, 0, clean_ladder.size() - 1)])
		if style == "side":
			stake = int(clean_ladder[clean_ladder.size() - 1])
		result.append({
			"id": "rail_%d" % i,
			"name": str(rng.pick(names, names[0])),
			"style": style,
			"stake": stake,
			"rapport": rng.randi_range(42, 62),
			"chip_color": str(colors[i % colors.size()]),
		})
	return result


func _normalize_rail_bettors(value: Variant, ladder: Array) -> Array:
	var source: Array = value if typeof(value) == TYPE_ARRAY else []
	if source.is_empty():
		var rng := RngStream.new()
		rng.configure(_stable_hash("bar_dice:rail:fallback"))
		source = _generate_rail_bettors(rng, ladder)
	var result: Array = []
	var clean_ladder := _int_array(ladder)
	for i in range(source.size()):
		if typeof(source[i]) != TYPE_DICTIONARY:
			continue
		var bettor: Dictionary = source[i]
		var style := str(bettor.get("style", "main"))
		if not ["main", "side", "press"].has(style):
			style = "main"
		result.append({
			"id": str(bettor.get("id", "rail_%d" % i)),
			"name": str(bettor.get("name", "Rail %d" % (i + 1))),
			"style": style,
			"stake": maxi(1, int(bettor.get("stake", clean_ladder[0] if not clean_ladder.is_empty() else 1))),
			"rapport": clampi(int(bettor.get("rapport", 50)), 0, 100),
			"chip_color": str(bettor.get("chip_color", "cyan")),
			"last_social_delta": int(bettor.get("last_social_delta", 0)),
		})
	return result


func _rail_bettors_for_surface(state: Dictionary, active_stake: int, side_bet: int) -> Array:
	var bettors := _normalize_rail_bettors(state.get("rail_bettors", []), _int_array(state.get("stake_ladder", [])))
	for i in range(bettors.size()):
		var bettor: Dictionary = bettors[i]
		bettor["visible_bet"] = _rail_wager_label(bettor)
		bettor["with_player"] = _rail_bettor_matches(bettor, active_stake, side_bet)
		bettors[i] = bettor
	return bettors


func _rail_wager_label(bettor: Dictionary) -> Dictionary:
	var style := str(bettor.get("style", "main"))
	var label := "MAIN"
	if style == "side":
		label = "SIDE"
	elif style == "press":
		label = "PRESS"
	return {"id": style, "label": label, "stake": maxi(1, int(bettor.get("stake", 1)))}


func _rail_bettor_command(index: int, ui_state: Dictionary, state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var fade := index >= 100
	var bettor_index := index % 100
	var bettors := _normalize_rail_bettors(state.get("rail_bettors", []), _int_array(state.get("stake_ladder", [])))
	if bettor_index < 0 or bettor_index >= bettors.size():
		return _message_command(ui_state, "That rail bettor stepped away.")
	var bettor: Dictionary = bettors[bettor_index]
	var ladder := _int_array(state.get("stake_ladder", []))
	if ladder.is_empty():
		return _message_command(ui_state, "The chip ladder is empty.")
	var target_stake := int(bettor.get("stake", ladder[0]))
	if fade:
		if str(bettor.get("style", "main")) == "side":
			target_stake = ladder[0]
		else:
			target_stake = int(ladder[ladder.size() - 1])
	else:
		if str(bettor.get("style", "main")) == "side":
			target_stake = int(ladder[ladder.size() - 1])
	var index_choice := _nearest_chip_index(ladder, target_stake)
	ui_state["selected_stake_index"] = index_choice
	ui_state["table_social_alignment"] = {
		"game": "bar_dice",
		"bettor_id": str(bettor.get("id", "rail_%d" % bettor_index)),
		"bettor_name": str(bettor.get("name", "Rail")),
		"stance": "against" if fade else "with",
		"style": str(bettor.get("style", "main")),
		"stake": int(ladder[index_choice]),
	}
	return GameModule.surface_command({
		"handled": true,
		"ui_state": ui_state,
		"selected_index": bettor_index,
		"preserve_surface_ui_state": true,
		"message": "%s %s's rail action at $%d." % ["Fading" if fade else "Following", str(bettor.get("name", "Rail")), int(ladder[index_choice])],
	})


func _rail_bettor_matches(bettor: Dictionary, active_stake: int, side_bet: int) -> bool:
	match str(bettor.get("style", "main")):
		"side":
			return side_bet > 0
		"press":
			return active_stake >= int(bettor.get("stake", active_stake))
		_:
			return abs(active_stake - int(bettor.get("stake", active_stake))) <= maxi(1, int(ceil(float(maxi(1, int(bettor.get("stake", 1)))) * 0.25)))


func _apply_rail_rapport_after_bar_dice(state: Dictionary, ui_state: Dictionary, active_stake: int, side_bet: int, outcome: String) -> void:
	var bettors := _normalize_rail_bettors(state.get("rail_bettors", []), _int_array(state.get("stake_ladder", [])))
	var alignment := _copy_dict(ui_state.get("table_social_alignment", {}))
	for i in range(bettors.size()):
		var bettor: Dictionary = bettors[i]
		var same := _rail_bettor_matches(bettor, active_stake, side_bet)
		var explicitly_aligned := str(alignment.get("bettor_id", "")) == str(bettor.get("id", "rail_%d" % i))
		var against := explicitly_aligned and str(alignment.get("stance", "")) == "against"
		var delta := 2 if same else 0
		if explicitly_aligned:
			delta += 4 if str(alignment.get("stance", "")) == "with" else -4
		if outcome == "win" and same:
			delta += 1
		elif outcome == "win" and against:
			delta -= 1
		bettor["rapport"] = clampi(int(bettor.get("rapport", 50)) + delta, 0, 100)
		bettor["last_social_delta"] = delta
		bettors[i] = bettor
	state["rail_bettors"] = bettors


func _selected_stake_index(state: Dictionary, ui_state: Dictionary) -> int:
	var ladder: Array = _int_array(state.get("stake_ladder", []))
	return clampi(int(ui_state.get("selected_stake_index", state.get("selected_stake_index", 0))), 0, maxi(0, ladder.size() - 1))


func _active_stake_from_context(stake: int, state: Dictionary, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> int:
	var ladder: Array = _int_array(state.get("stake_ladder", []))
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


func _side_bet_for(stake: int, _state: Dictionary) -> int:
	if stake <= 4:
		return 0
	return maxi(1, int(floor(float(stake) * 0.10)))


# --- Dice generation and play ------------------------------------------------

func _generate_opening(run_state: RunState, state: Dictionary) -> Array:
	var rounds := int(state.get("rounds_played", 0))
	var rng_state := int(run_state.rng_state) if run_state != null else 0
	var seed_text := str(run_state.seed_text) if run_state != null else "bar_dice"
	var table_key := str(state.get("table_key", "table"))
	var dice: Array = []
	for i in range(DICE_COUNT):
		var hashed := _stable_hash("%s:%s:%s:%d:%d:%d:open" % [get_id(), table_key, seed_text, rng_state, rounds, i])
		dice.append(1 + int(hashed % DIE_FACES))
	return dice


func _opening_dice(run_state: RunState, state: Dictionary, ui_state: Dictionary) -> Array:
	if bool(ui_state.get("rolled", false)):
		var dice: Array = _int_dice(ui_state.get("dice", []))
		if dice.size() == DICE_COUNT:
			return dice
	return _generate_opening(run_state, state)


func _roll_dice(rng: RngStream, count: int) -> Array:
	var dice: Array = []
	for _i in range(count):
		dice.append(rng.randi_range(1, DIE_FACES))
	return dice


func _suggested_reroll(dice: Array) -> Array:
	return _suggested_reroll_for_ruleset(dice, "poker_dice")


func _suggested_reroll_for_ruleset(dice: Array, ruleset: String) -> Array:
	match ruleset:
		"ship_captain_crew":
			return _ship_reroll_marks(dice)
		"over_under_7":
			return _over_under_reroll_marks(dice)
		_:
			var keep_value := _best_keep_value(dice)
			var marks: Array = []
			for i in range(dice.size()):
				if int(dice[i]) != keep_value:
					marks.append(i)
			return marks


func _ship_reroll_marks(dice: Array) -> Array:
	var needed := [6, 5, 4]
	var marks: Array = []
	var kept_special: Array = []
	for i in range(dice.size()):
		var value := int(dice[i])
		if needed.has(value) and not kept_special.has(value):
			kept_special.append(value)
		else:
			marks.append(i)
	for i in range(dice.size()):
		var value := int(dice[i])
		if not kept_special.has(6) and value != 6 and not marks.has(i):
			marks.append(i)
		elif not kept_special.has(5) and value != 5 and not marks.has(i):
			marks.append(i)
		elif not kept_special.has(4) and value != 4 and not marks.has(i):
			marks.append(i)
	marks.sort()
	return marks


func _over_under_reroll_marks(dice: Array) -> Array:
	var pair: Array = _best_seven_pair_indices(dice)
	var marks: Array = []
	for i in range(dice.size()):
		if not pair.has(i):
			marks.append(i)
	return marks


func _best_keep_value(dice: Array) -> int:
	return _loaded_value_for(dice)


func _loaded_value_for(dice: Array) -> int:
	if dice.is_empty():
		return DIE_FACES
	var counts: Dictionary = _counts(dice)
	var best_value := DIE_FACES
	var best_key := -1
	for value in counts.keys():
		var key := int(counts[value]) * 10 + int(value)
		if key > best_key:
			best_key = key
			best_value = int(value)
	return best_value


func _loaded_value_for_ruleset(dice: Array, ruleset: String) -> int:
	if ruleset == "ship_captain_crew":
		for needed in [6, 5, 4]:
			if not dice.has(needed):
				return int(needed)
	if ruleset == "over_under_7":
		var pair: Array = _best_seven_pair_indices(dice)
		if pair.size() >= 1:
			var value := int(dice[int(pair[0])])
			return clampi(7 - value, 1, DIE_FACES)
	return _loaded_value_for(dice)


func _apply_loaded_die(dice: Array, loaded_value: int) -> Array:
	if loaded_value < 1 or loaded_value > DIE_FACES:
		return dice
	var result: Array = dice.duplicate()
	var counts: Dictionary = _counts(result)
	var target_index := -1
	var best_rank := 999
	for i in range(result.size()):
		var value := int(result[i])
		if value == loaded_value:
			continue
		var rank := int(counts.get(value, 0)) * 10 + value
		if rank < best_rank:
			best_rank = rank
			target_index = i
	if target_index >= 0:
		result[target_index] = loaded_value
	return result


func _apply_palmed_swap(dice: Array, ruleset: String) -> Array:
	var best: Array = dice.duplicate()
	var best_score: Dictionary = _score_for_ruleset(best, ruleset)
	for i in range(dice.size()):
		for face in range(1, DIE_FACES + 1):
			var candidate: Array = dice.duplicate()
			candidate[i] = face
			var score: Dictionary = _score_for_ruleset(candidate, ruleset)
			if _compare_signatures(score.get("signature", []), best_score.get("signature", [])) > 0:
				best = candidate
				best_score = score
	return best


func _kept_dice(dice: Array, reroll: Array) -> Array:
	var kept: Array = []
	for i in range(dice.size()):
		if not reroll.has(i):
			kept.append(int(dice[i]))
	return kept


# --- Scoring -----------------------------------------------------------------

func _score(dice: Array) -> Dictionary:
	return _score_poker(dice)


func _score_for_ruleset(dice: Array, ruleset: String) -> Dictionary:
	match ruleset:
		"ship_captain_crew":
			return _score_ship(dice)
		"over_under_7":
			return _score_over_under(dice)
		"bluff_call":
			return _score_bluff(dice)
		_:
			return _score_poker(dice)


func _score_poker(dice: Array) -> Dictionary:
	var counts: Dictionary = _counts(dice)
	var unique_sorted: Array = counts.keys()
	unique_sorted.sort()
	var group_keys: Array = []
	for value in counts.keys():
		group_keys.append(int(counts[value]) * 10 + int(value))
	group_keys.sort()
	group_keys.reverse()
	var group_counts: Array = []
	var group_values: Array = []
	for key in group_keys:
		group_counts.append(int(key) / 10)
		group_values.append(int(key) % 10)
	var top_count := int(group_counts[0]) if not group_counts.is_empty() else 0
	var second_count := int(group_counts[1]) if group_counts.size() > 1 else 0
	var is_straight := unique_sorted.size() == DICE_COUNT and (unique_sorted == [1, 2, 3, 4, 5] or unique_sorted == [2, 3, 4, 5, 6])
	var category := "high_card"
	if top_count == 5:
		category = "five_kind"
	elif top_count == 4:
		category = "four_kind"
	elif top_count == 3 and second_count == 2:
		category = "full_house"
	elif is_straight:
		category = "straight"
	elif top_count == 3:
		category = "three_kind"
	elif top_count == 2 and second_count == 2:
		category = "two_pair"
	elif top_count == 2:
		category = "one_pair"
	var signature: Array = [int(CATEGORY_RANK.get(category, 1))]
	if category == "straight":
		signature.append(int(unique_sorted[unique_sorted.size() - 1]))
	else:
		for value in group_values:
			signature.append(int(value))
	return {
		"category": category,
		"signature": signature,
		"scoring_indices": _scoring_indices(dice, category, group_values),
	}


func _score_ship(dice: Array) -> Dictionary:
	var used_indices: Array = []
	var has_ship := false
	var has_captain := false
	var has_crew := false
	for i in range(dice.size()):
		var value := int(dice[i])
		if value == 6 and not has_ship:
			has_ship = true
			used_indices.append(i)
		elif value == 5 and not has_captain:
			has_captain = true
			used_indices.append(i)
		elif value == 4 and not has_crew:
			has_crew = true
			used_indices.append(i)
	var cargo_values: Array = []
	for i in range(dice.size()):
		if not used_indices.has(i):
			cargo_values.append(int(dice[i]))
	cargo_values.sort()
	cargo_values.reverse()
	var cargo := 0
	for value in cargo_values:
		cargo += int(value)
	var complete := has_ship and has_captain and has_crew
	var category := "perfect_cargo" if complete and cargo >= 10 else ("ship_captain_crew" if complete else "crew_missing")
	var component_count := int(has_ship) + int(has_captain) + int(has_crew)
	var signature: Array = [int(CATEGORY_RANK.get(category, 1)), cargo if complete else component_count]
	for value in cargo_values:
		signature.append(int(value))
	return {
		"category": category,
		"signature": signature,
		"cargo": cargo,
		"scoring_indices": used_indices if complete else _highest_indices(dice, 2),
	}


func _score_over_under(dice: Array) -> Dictionary:
	var pair: Array = _best_seven_pair_indices(dice)
	var total := 0
	for index_value in pair:
		total += int(dice[int(index_value)])
	var category := "bar_seven" if total == 7 else ("over_seven" if total > 7 else "under_seven")
	var distance := absi(total - 7)
	return {
		"category": category,
		"signature": [int(CATEGORY_RANK.get(category, 1)), -distance, total],
		"pair_total": total,
		"scoring_indices": pair,
	}


func _score_bluff(dice: Array) -> Dictionary:
	var poker: Dictionary = _score_poker(dice)
	var category := str(poker.get("category", "high_card"))
	match category:
		"five_kind":
			category = "made_five"
		"four_kind":
			category = "made_four"
		"three_kind", "full_house":
			category = "called_trips"
		"one_pair", "two_pair":
			category = "called_pair"
		_:
			category = "called_high"
	var signature: Array = _index_array_raw(poker.get("signature", []))
	signature[0] = int(CATEGORY_RANK.get(category, 1))
	return {
		"category": category,
		"signature": signature,
		"scoring_indices": _index_array(poker.get("scoring_indices", [])),
	}


func _scoring_indices(dice: Array, category: String, group_values: Array) -> Array:
	var indices: Array = []
	if category == "straight":
		for i in range(dice.size()):
			indices.append(i)
		return indices
	if category == "high_card":
		return _highest_indices(dice, 1)
	var primary := int(group_values[0]) if not group_values.is_empty() else 0
	var secondary := -1
	if (category == "full_house" or category == "two_pair") and group_values.size() > 1:
		secondary = int(group_values[1])
	for i in range(dice.size()):
		var value := int(dice[i])
		if value == primary or (secondary >= 0 and value == secondary):
			indices.append(i)
	return indices


func _best_seven_pair_indices(dice: Array) -> Array:
	var best_pair: Array = [0, 1]
	var best_key := 999
	for i in range(dice.size()):
		for j in range(i + 1, dice.size()):
			var total := int(dice[i]) + int(dice[j])
			var key := absi(total - 7) * 100 - total
			if key < best_key:
				best_key = key
				best_pair = [i, j]
	return best_pair


func _highest_indices(dice: Array, count: int) -> Array:
	var keyed: Array = []
	for i in range(dice.size()):
		keyed.append(int(dice[i]) * 10 + i)
	keyed.sort()
	keyed.reverse()
	var result: Array = []
	for i in range(mini(count, keyed.size())):
		result.append(int(keyed[i]) % 10)
	result.sort()
	return result


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


func _counts(dice: Array) -> Dictionary:
	var counts: Dictionary = {}
	for value in dice:
		var face := int(value)
		if face < 1 or face > DIE_FACES:
			continue
		counts[face] = int(counts.get(face, 0)) + 1
	return counts


func _category_power(category: String) -> int:
	return int(CATEGORY_RANK.get(category, 0))


func _payout_multiplier(category: String, state: Dictionary) -> float:
	var ruleset := str(state.get("ruleset_family", "poker_dice"))
	var paytable: Dictionary = _copy_dict(PAYTABLES.get(ruleset, {}))
	var base := float(paytable.get(category, 0.0))
	if base <= 0.0:
		return 0.0
	var tier := str(state.get("edge_tier", "standard"))
	var scale := float(EDGE_TIER_SCALE.get(tier, 1.0))
	if ruleset == "poker_dice":
		scale = float(POKER_TIER_SCALE.get(tier, scale))
	elif ruleset == "ship_captain_crew":
		scale = float(SHIP_TIER_SCALE.get(tier, scale))
	return maxf(1.05, base * scale)


# --- Text helpers ------------------------------------------------------------

func _hand_blurb(score: Dictionary) -> String:
	var category := str(score.get("category", "high_card"))
	var signature: Array = _index_array_raw(score.get("signature", []))
	var label := str(CATEGORY_LABEL.get(category, "High Card"))
	match category:
		"five_kind", "four_kind", "three_kind", "one_pair", "made_five", "made_four", "called_trips", "called_pair":
			return "%s - %s" % [label, _word_plural(_sig_value(signature, 1))]
		"full_house":
			return "%s - %s over %s" % [label, _word_plural(_sig_value(signature, 1)), _word_plural(_sig_value(signature, 2))]
		"two_pair":
			return "%s - %s and %s" % [label, _word_plural(_sig_value(signature, 1)), _word_plural(_sig_value(signature, 2))]
		"straight":
			return "%s - %s high" % [label, _word_single(_sig_value(signature, 1))]
		"ship_captain_crew", "perfect_cargo":
			return "%s - cargo %d" % [label, int(score.get("cargo", _sig_value(signature, 1)))]
		"under_seven", "over_seven", "bar_seven":
			return "%s - pair totals %d" % [label, int(score.get("pair_total", _sig_value(signature, 2)))]
		_:
			return "%s - %s" % [label, _word_single(_sig_value(signature, 1))]


func _outcome_message(match_data: Dictionary, outcome: String, bankroll_delta: int, suspicion_delta: int, action_id: String, pit_boss_summary: String, security_message: String, side_result: Dictionary, state: Dictionary) -> String:
	var player_score: Dictionary = _copy_dict(match_data.get("best_player_score", match_data.get("player_score", {})))
	var house_score: Dictionary = _copy_dict(match_data.get("house_score", {}))
	var verdict := "wins the match"
	if outcome == "push":
		verdict = "pushes the match"
	elif outcome == "lose":
		verdict = "loses to the house"
	var cheat_text := ""
	if action_id == "loaded_toss":
		cheat_text = " Loaded die shows the tell."
	elif action_id == "palmed_swap":
		cheat_text = " Palmed swap cleans up one die."
	var side_text := ""
	var side_reason := str(side_result.get("reason", ""))
	if int(side_result.get("award", 0)) > 0 or int(side_result.get("progressive_award", 0)) > 0:
		side_text = " Bonus %s pays %+d." % [side_reason, int(side_result.get("award", 0)) + int(side_result.get("progressive_award", 0))]
	var message := "%s - %s, pays %.1fx. House shows %s. You %s for %+d.%s%s" % [
		_hand_blurb(player_score),
		str(state.get("ruleset_label", "Bar Dice")),
		_payout_multiplier(str(player_score.get("category", "high_card")), state),
		_hand_blurb(house_score),
		verdict,
		bankroll_delta,
		cheat_text,
		side_text,
	]
	if suspicion_delta > 0:
		message += " Suspicion pressure rises."
	if not pit_boss_summary.is_empty():
		message += " %s" % pit_boss_summary
	if not security_message.is_empty():
		message += " %s" % security_message
	return message


func _info_text(phase: String, player_dice: Array, reroll: Array, last_result: Dictionary, loaded_armed: bool, palm_armed: bool, loaded_value: int, state: Dictionary) -> String:
	if phase == "settled" and not last_result.is_empty():
		var blurb := str(last_result.get("player_blurb", ""))
		var mult := float(last_result.get("payout_mult", 0.0))
		return "%s, pays %.1fx (%s)" % [blurb, mult, str(last_result.get("match_summary", "match"))]
	if phase == "select":
		if loaded_armed:
			return "Loaded die set to %s; heat scales with watch." % _word_single(loaded_value)
		if palm_armed:
			return "Palmed swap armed; one die will be improved."
		var keep: Array = _kept_dice(player_dice, reroll)
		var score: Dictionary = _score_for_ruleset(player_dice, str(state.get("ruleset_family", "poker_dice")))
		return "Holding %d, rerolling %d. Pack reads %s." % [keep.size(), reroll.size(), str(CATEGORY_LABEL.get(str(score.get("category", "high_card")), "High Card"))]
	return "Choose a chip, toss the cup, play best of three."


func _resolve_prompt(ui_state: Dictionary, action_id: String) -> String:
	match action_id:
		"loaded_toss":
			return "Loaded toss armed. Click again to rig the first leg and resolve."
		"palmed_swap":
			return "Palmed swap armed. Click again to lift the first leg and resolve."
		_:
			if bool(ui_state.get("rolled", false)):
				return "Honest match ready. Click again to reroll marked dice and settle."
			return "Quick match ready. Click again to toss and settle."


func _paytable_rows(state: Dictionary, active_stake: int) -> Array:
	var rows: Array = []
	var ruleset := str(state.get("ruleset_family", "poker_dice"))
	var order: Array = PAYTABLE_DISPLAY_ORDER.get(ruleset, [])
	for category in order:
		var mult := _payout_multiplier(str(category), state)
		rows.append({
			"label": str(CATEGORY_LABEL.get(str(category), str(category))),
			"mult": mult,
			"payout": int(round(float(active_stake) * mult)),
		})
	rows.append({
		"label": str(state.get("bonus_label", "Side Bet")),
		"mult": float(SIDE_BONUS_MULT.get(str(state.get("bonus_mode", "hot_hand")), 5)),
		"payout": _side_bet_for(active_stake, state) * int(SIDE_BONUS_MULT.get(str(state.get("bonus_mode", "hot_hand")), 5)),
	})
	return rows


func _reroll_summary(marks: Array) -> String:
	if marks.is_empty():
		return "keep all"
	var labels: Array = []
	for mark in marks:
		labels.append(str(int(mark) + 1))
	return ", ".join(labels)


func _word_single(value: int) -> String:
	return str(DIE_WORD.get(value, str(value)))


func _word_plural(value: int) -> String:
	return str(DIE_WORD_PLURAL.get(value, "%ss" % value))


func _sig_value(signature: Array, index: int) -> int:
	if index >= 0 and index < signature.size():
		return int(signature[index])
	return 0


func _action_def(action_id: String) -> Dictionary:
	for action_value in definition.get("legal_actions", []):
		if typeof(action_value) == TYPE_DICTIONARY and str((action_value as Dictionary).get("id", "")) == action_id:
			return (action_value as Dictionary).duplicate(true)
	for action_value in definition.get("cheat_actions", []):
		if typeof(action_value) == TYPE_DICTIONARY and str((action_value as Dictionary).get("id", "")) == action_id:
			return (action_value as Dictionary).duplicate(true)
	return {}


# --- Surface command helpers -------------------------------------------------

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
		return ["bar_dice_load"]
	if action_id == "palmed_swap" and action_kind == "cheat":
		return ["bar_dice_palm"]
	if action_id == "press" and action_kind == "legal":
		return ["bar_dice_press"]
	return []


func _active_tumble(ui_state: Dictionary, last_result: Dictionary, rolled: bool) -> Dictionary:
	if rolled and ui_state.has("tumble_id"):
		return {"id": str(ui_state.get("tumble_id", "")), "started": int(ui_state.get("tumble_started_msec", 0))}
	if not rolled and not last_result.is_empty():
		return {"id": str(last_result.get("tumble_id", "")), "started": int(last_result.get("resolved_at_msec", 0))}
	return {"id": "", "started": 0}


# --- Drawing -----------------------------------------------------------------

func _draw_dice_room(surface) -> void:
	var board_size: Vector2 = surface.surface_board_size()
	surface.draw_rect(Rect2(Vector2.ZERO, board_size), Color("#0a0712"))
	surface.draw_rect(Rect2(0, 0, board_size.x, 70), Color("#150a1d"))
	surface.draw_rect(Rect2(40, 102, 470, 226), Color("#101a14"))
	surface.draw_rect(Rect2(40, 102, 470, 226), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.28), false, 2)
	surface.draw_rect(Rect2(40, 218, 470, 2), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.30))
	surface.draw_rect(Rect2(532, 86, 350, 260), Color("#0c0c1c"))
	surface.draw_rect(Rect2(532, 86, 350, 260), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.24), false, 2)


func _draw_meter_strip(surface, surface_state: Dictionary) -> void:
	surface.draw_rect(Rect2(40, 76, 842, 20), Color("#191124"))
	surface.surface_label("CHIPS $%d" % int(surface_state.get("chips_meter", 0)), Vector2(54, 91), 12, C_SOFT)
	surface.surface_label("BET $%d" % int(surface_state.get("bet_meter", 0)), Vector2(188, 91), 12, C_YELLOW)
	surface.surface_label("WIN $%d" % int(surface_state.get("win_meter", 0)), Vector2(306, 91), 12, C_TEAL)
	surface.surface_label("PROG $%d" % int(surface_state.get("progressive_pot", 0)), Vector2(420, 91), 12, C_AMBER)


func _draw_chip_ladder(surface, surface_state: Dictionary, phase: String) -> void:
	var ladder: Array = _int_array(surface_state.get("stake_ladder", []))
	var selected := int(surface_state.get("selected_stake_index", 0))
	for i in range(ladder.size()):
		var rect := Rect2(52 + i * 62, 354, 52, 34)
		var enabled := phase != "select"
		var fill := C_YELLOW if i == selected else Color("#271735")
		surface.draw_rect(rect, fill)
		surface.draw_rect(rect, C_SOFT, false, 2)
		surface.surface_label_centered("$%d" % int(ladder[i]), rect, 13, C_DARK if i == selected else C_SOFT)
		if enabled:
			surface.surface_add_hit(rect, "bar_dice_stake", i)


func _draw_dice_row(surface, values: Array, start: Vector2, reroll: Array, suggested: Array, scoring: Array, hidden: bool) -> void:
	var tumble_active := bool(surface.surface_animation_active(TUMBLE_CHANNEL))
	var tumble_progress := float(surface.surface_animation_progress(TUMBLE_CHANNEL))
	var flicker := float(surface.surface_flicker())
	for i in range(values.size()):
		var rect := Rect2(start + Vector2(i * DIE_SPACING, 0.0), DIE_SIZE)
		var settle_point := float(i + 1) / float(DICE_COUNT + 1)
		var rolling := tumble_active and tumble_progress < settle_point and not hidden
		var marked := reroll.has(i)
		var is_suggested := suggested.has(i) and not marked
		var is_scoring := scoring.has(i)
		if hidden:
			_draw_die_cup(surface, rect)
			continue
		var draw_rect := rect
		if rolling:
			var bounce := sin((flicker * 18.0) + float(i)) * 6.0
			draw_rect = Rect2(rect.position + Vector2(0.0, bounce), rect.size)
		var face := int(values[i])
		if rolling:
			face = 1 + int(flicker * 21.0 + i * 3) % DIE_FACES
		_draw_die(surface, draw_rect, face, marked, is_suggested, is_scoring and not rolling)


func _add_dice_row_hits(surface, values: Array, start: Vector2, action: String) -> void:
	for i in range(values.size()):
		surface.surface_add_exact_hit(Rect2(start + Vector2(i * DIE_SPACING, 0.0), DIE_SIZE), action, i)


func _draw_die(surface, rect: Rect2, value: int, marked: bool, suggested: bool, scoring: bool) -> void:
	if scoring:
		surface.draw_rect(Rect2(rect.position - Vector2(5, 5), rect.size + Vector2(10, 10)), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.30))
	surface.draw_rect(rect, C_SOFT)
	var face_color := Color("#f7f1e0") if not marked else Color("#e7c9d8")
	surface.draw_rect(Rect2(rect.position + Vector2(4, 4), rect.size - Vector2(8, 8)), face_color)
	if marked:
		surface.draw_rect(Rect2(rect.position - Vector2(4, 4), rect.size + Vector2(8, 8)), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.55), false, 3)
		surface.surface_label("RR", rect.position + Vector2(rect.size.x - 22, 16), 12, C_PINK)
	elif suggested:
		surface.draw_rect(Rect2(rect.position - Vector2(3, 3), rect.size + Vector2(6, 6)), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.45), false, 2)
	elif scoring:
		surface.draw_rect(Rect2(rect.position - Vector2(4, 4), rect.size + Vector2(8, 8)), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.70), false, 3)
	if value <= 0:
		surface.surface_label("?", rect.position + rect.size * 0.5 + Vector2(-7, 8), 26, C_DARK)
		return
	_draw_pips(surface, rect, value)


func _draw_die_cup(surface, rect: Rect2) -> void:
	surface.draw_rect(rect, Color("#1c1326"))
	surface.draw_rect(Rect2(rect.position + Vector2(4, 4), rect.size - Vector2(8, 8)), Color("#2a1c36"))
	surface.draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.30), false, 2)
	surface.surface_label("?", rect.position + rect.size * 0.5 + Vector2(-7, 8), 26, C_PINK_2)


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
	var pip_radius := maxf(4.0, minf(w, h) * 0.075)
	var indices := {
		1: [1],
		2: [0, 2],
		3: [0, 1, 2],
		4: [0, 2, 3, 4],
		5: [0, 1, 2, 3, 4],
		6: [0, 2, 3, 4, 5, 6],
	}
	for idx in indices.get(value, []):
		surface.draw_circle(points[int(idx)], pip_radius, C_DARK)


func _draw_info_panel(surface, surface_state: Dictionary) -> void:
	surface.surface_label("PAYTABLE", Vector2(548, 108), 16, C_YELLOW)
	var rows: Array = surface_state.get("paytable_rows", [])
	var info_blurb := str(surface_state.get("player_blurb", ""))
	for i in range(mini(rows.size(), 7)):
		var row: Dictionary = rows[i] if typeof(rows[i]) == TYPE_DICTIONARY else {}
		var y := 130 + i * 22
		var label := str(row.get("label", ""))
		var mult := float(row.get("mult", 0.0))
		var highlight := not info_blurb.is_empty() and info_blurb.begins_with(label)
		var row_color := C_TEAL if highlight else C_SOFT
		surface.surface_label(label.left(22), Vector2(548, y), 13, row_color)
		surface.surface_label("%.1fx" % mult, Vector2(780, y), 13, C_YELLOW if highlight else C_SOFT)
		surface.surface_label("$%d" % int(row.get("payout", 0)), Vector2(832, y), 13, C_AMBER if highlight else C_SOFT)

	var info_text := str(surface_state.get("info_text", ""))
	surface.surface_label(info_text.left(48), Vector2(548, 306), 13, C_CYAN)
	if not str(surface_state.get("match_summary", "")).is_empty():
		surface.surface_label(str(surface_state.get("match_summary", "")).left(40), Vector2(548, 326), 12, C_TEAL)
	if bool(surface_state.get("loaded_armed", false)):
		surface.surface_label("Loaded die: %s" % _word_single(int(surface_state.get("loaded_value", 0))), Vector2(56, 212), 13, C_PINK_2)
	if bool(surface_state.get("palm_armed", false)):
		surface.surface_label("Palmed swap ready", Vector2(56, 212), 13, C_PINK_2)
	if bool(surface_state.get("pit_boss_watched", false)):
		surface.surface_label(str(surface_state.get("pit_boss_summary", "")).left(42), Vector2(548, 92), 12, C_PINK)


func _draw_rail_bettors(surface, surface_state: Dictionary, phase: String) -> void:
	var bettors: Array = surface_state.get("rail_bettors", []) if typeof(surface_state.get("rail_bettors", [])) == TYPE_ARRAY else []
	if bettors.is_empty():
		return
	for i in range(mini(bettors.size(), 3)):
		if typeof(bettors[i]) != TYPE_DICTIONARY:
			continue
		var bettor: Dictionary = bettors[i]
		var rect := Rect2(56 + i * 98, 310, 92, 34)
		var color := _rail_chip_color(str(bettor.get("chip_color", "cyan")))
		var rapport := clampi(int(bettor.get("rapport", 50)), 0, 100)
		var rapport_color := C_TEAL if rapport >= 58 else C_PINK if rapport <= 42 else C_YELLOW
		surface.draw_rect(rect, Color(0.02, 0.02, 0.06, 0.78))
		surface.draw_rect(rect, Color(rapport_color.r, rapport_color.g, rapport_color.b, 0.34), false, 1)
		var wager := _copy_dict(bettor.get("visible_bet", _rail_wager_label(bettor)))
		surface.draw_circle(rect.position + Vector2(10, 11), 6.0, color)
		surface.draw_circle(rect.position + Vector2(10, 11), 2.5, Color("#f8f4dc"))
		surface.surface_label(str(bettor.get("name", "Rail")).left(7), rect.position + Vector2(20, 10), 7, C_WHITE)
		surface.surface_label("%s $%d" % [str(wager.get("label", "BET")).to_upper().left(5), int(wager.get("stake", 0))], rect.position + Vector2(6, 21), 7, C_YELLOW)
		var meter := Rect2(rect.position + Vector2(58, 22), Vector2(28, 3))
		surface.draw_rect(meter, Color("#070810"))
		surface.draw_rect(Rect2(meter.position, Vector2(meter.size.x * float(rapport) / 100.0, meter.size.y)), rapport_color)
		if phase != "select":
			var with_rect := Rect2(rect.position + Vector2(6, 25), Vector2(38, 8))
			var fade_rect := Rect2(rect.position + Vector2(48, 25), Vector2(38, 8))
			surface.draw_rect(with_rect, Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.18))
			surface.draw_rect(fade_rect, Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.18))
			surface.surface_label_centered("WITH", with_rect, 6, C_TEAL)
			surface.surface_label_centered("FADE", fade_rect, 6, C_PINK)
			surface.surface_add_exact_hit(with_rect, "bar_dice_rail_bet", i)
			surface.surface_add_exact_hit(fade_rect, "bar_dice_rail_bet", i + 100)


func _rail_chip_color(name: String) -> Color:
	match name:
		"pink":
			return C_PINK
		"yellow":
			return C_YELLOW
		"teal":
			return C_TEAL
		"orange":
			return C_ORANGE
		_:
			return C_CYAN


func _draw_controls(surface, surface_state: Dictionary, phase: String) -> void:
	if phase == "select":
		surface.surface_draw_action_button(Rect2(352, 354, 112, 38), "RESOLVE", "bar_dice_resolve", 0, C_TEAL)
		surface.surface_draw_action_button(Rect2(474, 354, 132, 38), "LOADED", "bar_dice_load", 0, C_PINK)
		surface.surface_draw_action_button(Rect2(616, 354, 132, 38), "PALM", "bar_dice_palm", 0, C_ORANGE)
	else:
		surface.surface_draw_action_button(Rect2(352, 354, 112, 38), "ROLL", "bar_dice_roll", 0, C_TEAL)
		surface.surface_draw_action_button(Rect2(474, 354, 132, 38), "QUICK", "bar_dice_resolve", 0, C_AMBER)
		if bool(surface_state.get("press_available", false)):
			surface.surface_draw_action_button(Rect2(616, 354, 132, 38), "PRESS $%d" % int(surface_state.get("press_risk", 0)), "bar_dice_press", 0, C_YELLOW)
	if phase == "settled":
		var delta := int(surface_state.get("result_bankroll_delta", 0))
		var heat := int(surface_state.get("result_suspicion_delta", 0))
		var color := C_TEAL if delta > 0 else (C_YELLOW if delta == 0 else C_ORANGE)
		surface.surface_label("Bankroll %+d   Heat %+d" % [delta, heat], Vector2(352, 414), 14, color)


# --- Result/value helpers ----------------------------------------------------

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


func _index_array_raw(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		result.append(int(entry))
	return result


func _stable_hash(text: String) -> int:
	var hash_value := 2166136261
	for i in range(text.length()):
		hash_value = int(hash_value ^ text.unicode_at(i))
		hash_value = int((hash_value * 16777619) & 0x7fffffff)
	return maxi(hash_value, 1)
