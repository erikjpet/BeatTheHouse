class_name VideoPokerGame
extends GameModule

# Full-simulation multi-variant video poker cabinet, modeled on real casino
# machines. The shared UI canvas only hosts the surface; this module owns the deck,
# the bet/deal/hold/draw loop, the per-variant paytables, hand evaluation (including
# wild cards and quad-with-kicker bonuses), the holdout cheat, the double-up gamble,
# the screen rendering, animation, and result deltas.
#
# REAL-MACHINE QUALITIES MODELED:
#   - Coin betting 1-5 with the max-coin Royal Flush bonus (250-for-1 at 1-4 coins,
#     800-for-1 / 4000 credits at 5 coins) -- the defining video poker mechanic.
#   - Four generated game variants, each with its authentic paytable and strategy:
#       * Jacks or Better (8/5)        * Bonus Poker (enhanced quads)
#       * Double Double Bonus (quads with kickers; two pair pays 1)
#       * Deuces Wild (2s wild: Natural Royal / Four Deuces / Wild Royal / Five OAK)
#   - A focused current-bet paytable, CREDITS / BET / WIN meters, large active
#     hand presentation, multi-hand result lanes, and BET / DEAL / DRAW /
#     DOUBLE-UP button states.
#   - Fixed bet ladder of 2 / 5 / 10 / 15 / 20 credits, with the top-bet Royal jackpot
#     (250-for-1 below the max bet, 800-for-1 at the max bet).
#   - Double-Up (double-or-nothing) gamble after any win.
#
# CHEAT (holdout / mark): palm in one ideal card on the draw, lifting the hand once
# at a suspicion cost scaled by security strictness and the pit-boss watch.
#
# Randomness flows through the injected RngStream. The deal is built from a stable
# hash of the run seed/state (no stream consumption) so the preview matches resolve;
# the draw and the double-up shuffle/draw consume the injected stream. Result deltas
# are applied through the shared host apply_result helper; this module never mutates
# RunState directly.

const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const CardShoeScript := preload("res://scripts/core/card_shoe.gd")
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

const HAND_SIZE := 5
const STATE_SCHEMA := "video_poker_machine_state"
const STATE_VERSION := 3
const FLIP_CHANNEL := "video_poker_flip"
const FLIP_DURATION_MSEC := 760
const RANK_JACK := 11
# Real video-poker betting is 1-5 coins at the generated cabinet denomination.
const COIN_LEVELS := [1, 2, 3, 4, 5]
const BET_LADDER := COIN_LEVELS
const MAX_BET_LEVEL := 4
const MAX_COIN_LEVEL := 4
const ROYAL_MAX_MULT := 800
const DOUBLE_UP_CAP := 5
const PROGRESSIVE_BASE := 240
const SEQUENTIAL_ROYAL_BONUS := 400
const DRAW_CASCADE_CHANNEL := "video_poker_cascade"

const COIN_DENOMINATION_SETS := [
	[
		{"label": "5c", "credits": 1},
		{"label": "25c", "credits": 2},
		{"label": "50c", "credits": 4},
	],
	[
		{"label": "25c", "credits": 2},
		{"label": "$1", "credits": 5},
		{"label": "$5", "credits": 20},
	],
	[
		{"label": "50c", "credits": 3},
		{"label": "$1", "credits": 6},
		{"label": "$2", "credits": 12},
	],
]

const MULTI_HAND_OPTIONS := [1, 3, 5, 10]

const PAYTABLE_TIERS := {
	"full_pay": {
		"label": "Full-Pay",
		"weight": 2,
		"overrides": {
			"jacks_or_better": {"full_house": 9, "flush": 6},
			"bonus_poker": {"full_house": 8, "flush": 5},
			"double_double_bonus": {"full_house": 9, "flush": 6},
			"deuces_wild": {"wild_royal": 23, "five_kind": 17, "straight_flush": 12, "four_kind": 5, "full_house": 4, "flush": 4},
			"joker_poker": {"full_house": 8, "flush": 6},
		},
	},
	"standard": {
		"label": "Standard",
		"weight": 5,
		"overrides": {
			"jacks_or_better": {"full_house": 8, "flush": 5},
			"bonus_poker": {"full_house": 7, "flush": 5},
			"double_double_bonus": {"full_house": 8, "flush": 5},
			"deuces_wild": {"wild_royal": 20, "five_kind": 12, "straight_flush": 9, "four_kind": 4, "full_house": 4, "flush": 3},
			"joker_poker": {"full_house": 7, "flush": 5},
		},
	},
	"short_pay": {
		"label": "Short-Pay",
		"weight": 3,
		"overrides": {
			"jacks_or_better": {"full_house": 7, "flush": 5, "straight": 3},
			"bonus_poker": {"full_house": 6, "flush": 5, "two_pair": 1},
			"double_double_bonus": {"full_house": 7, "flush": 5, "straight": 3},
			"deuces_wild": {"wild_royal": 15, "five_kind": 8, "straight_flush": 7, "four_kind": 3, "full_house": 3, "flush": 2, "straight": 1},
			"joker_poker": {"full_house": 6, "flush": 5, "straight": 3},
		},
	},
}

# Per-variant paytables. Multipliers are gross "for 1" on the bet; the top royal row
# also carries the max-bet rate (max_mult, an 800-for-1 jackpot at the top bet). Rows
# are listed top to bottom for the grid.
const VARIANTS := {
	"jacks_or_better": {
		"label": "Jacks or Better",
		"wild_ranks": [],
		"min_label": "Jacks or Better",
		"rows": [
			{"key": "royal_flush", "label": "Royal Flush", "mult": 250, "max_mult": 800},
			{"key": "straight_flush", "label": "Straight Flush", "mult": 50},
			{"key": "four_kind", "label": "Four of a Kind", "mult": 25},
			{"key": "full_house", "label": "Full House", "mult": 8},
			{"key": "flush", "label": "Flush", "mult": 5},
			{"key": "straight", "label": "Straight", "mult": 4},
			{"key": "three_kind", "label": "Three of a Kind", "mult": 3},
			{"key": "two_pair", "label": "Two Pair", "mult": 2},
			{"key": "jacks_or_better", "label": "Jacks or Better", "mult": 1},
		],
	},
	"bonus_poker": {
		"label": "Bonus Poker",
		"wild_ranks": [],
		"min_label": "Jacks or Better",
		"rows": [
			{"key": "royal_flush", "label": "Royal Flush", "mult": 250, "max_mult": 800},
			{"key": "straight_flush", "label": "Straight Flush", "mult": 50},
			{"key": "four_aces", "label": "Four Aces", "mult": 80},
			{"key": "four_2_4", "label": "Four 2s-4s", "mult": 40},
			{"key": "four_5_k", "label": "Four 5s-Ks", "mult": 25},
			{"key": "full_house", "label": "Full House", "mult": 8},
			{"key": "flush", "label": "Flush", "mult": 5},
			{"key": "straight", "label": "Straight", "mult": 4},
			{"key": "three_kind", "label": "Three of a Kind", "mult": 3},
			{"key": "two_pair", "label": "Two Pair", "mult": 2},
			{"key": "jacks_or_better", "label": "Jacks or Better", "mult": 1},
		],
	},
	"double_double_bonus": {
		"label": "Double Double Bonus",
		"wild_ranks": [],
		"min_label": "Jacks or Better",
		"rows": [
			{"key": "royal_flush", "label": "Royal Flush", "mult": 250, "max_mult": 800},
			{"key": "straight_flush", "label": "Straight Flush", "mult": 50},
			{"key": "four_aces_kicker", "label": "Four Aces + 2/3/4", "mult": 400},
			{"key": "four_2_4_kicker", "label": "Four 2-4 + A-4", "mult": 160},
			{"key": "four_aces", "label": "Four Aces", "mult": 160},
			{"key": "four_2_4", "label": "Four 2s-4s", "mult": 80},
			{"key": "four_5_k", "label": "Four 5s-Ks", "mult": 50},
			{"key": "full_house", "label": "Full House", "mult": 8},
			{"key": "flush", "label": "Flush", "mult": 5},
			{"key": "straight", "label": "Straight", "mult": 4},
			{"key": "three_kind", "label": "Three of a Kind", "mult": 3},
			{"key": "two_pair", "label": "Two Pair", "mult": 1},
			{"key": "jacks_or_better", "label": "Jacks or Better", "mult": 1},
		],
	},
	"deuces_wild": {
		"label": "Deuces Wild",
		"wild_ranks": [2],
		"min_label": "Three of a Kind",
		"rows": [
			{"key": "natural_royal", "label": "Natural Royal", "mult": 250, "max_mult": 800},
			{"key": "four_deuces", "label": "Four Deuces", "mult": 200},
			{"key": "wild_royal", "label": "Wild Royal", "mult": 20},
			{"key": "five_kind", "label": "Five of a Kind", "mult": 12},
			{"key": "straight_flush", "label": "Straight Flush", "mult": 9},
			{"key": "four_kind", "label": "Four of a Kind", "mult": 4},
			{"key": "full_house", "label": "Full House", "mult": 4},
			{"key": "flush", "label": "Flush", "mult": 3},
			{"key": "straight", "label": "Straight", "mult": 2},
			{"key": "three_kind", "label": "Three of a Kind", "mult": 1},
		],
	},
	"joker_poker": {
		"label": "Joker Poker",
		"wild_ranks": [0],
		"include_joker": true,
		"min_label": "Kings or Better",
		"rows": [
			{"key": "natural_royal", "label": "Natural Royal", "mult": 250, "max_mult": 800},
			{"key": "five_kind", "label": "Five of a Kind", "mult": 200},
			{"key": "wild_royal", "label": "Joker Royal", "mult": 100},
			{"key": "straight_flush", "label": "Straight Flush", "mult": 50},
			{"key": "four_kind", "label": "Four of a Kind", "mult": 20},
			{"key": "full_house", "label": "Full House", "mult": 7},
			{"key": "flush", "label": "Flush", "mult": 5},
			{"key": "straight", "label": "Straight", "mult": 3},
			{"key": "three_kind", "label": "Three of a Kind", "mult": 2},
			{"key": "kings_or_better", "label": "Kings or Better", "mult": 1},
		],
	},
}
const VARIANT_WEIGHTS := ["jacks_or_better", "bonus_poker", "double_double_bonus", "deuces_wild", "joker_poker"]

const RANK_WORD := {
	2: "Twos", 3: "Threes", 4: "Fours", 5: "Fives", 6: "Sixes", 7: "Sevens",
	8: "Eights", 9: "Nines", 10: "Tens", 11: "Jacks", 12: "Queens", 13: "Kings", 14: "Aces",
}
const SUIT_WORD := {0: "Spades", 1: "Hearts", 2: "Clubs", 3: "Diamonds"}

# The surface is the shared 900x430 game board. Keep the cabinet inside those
# bounds: paytable glass on top, cards centered, real-machine buttons below.
const MACHINE_HEADER_RECT := Rect2(0, 0, 900, 36)
const PAYTABLE_RECT := Rect2(22, 44, 856, 126)
const PRIMARY_HAND_RECT := Rect2(22, 184, 596, 172)
const STATUS_PANEL_RECT := Rect2(640, 184, 238, 172)
const CARD_ROW_ORIGIN := Vector2(48, 214)
const CARD_SIZE := Vector2(92, 110)
const CARD_SPACING := 112.0
const HOLD_BUTTON_SIZE := Vector2(92, 24)
const CONTROL_DECK_RECT := Rect2(18, 366, 864, 52)


# Creates the entry message for the cabinet.
func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
	var result: Dictionary = super.enter(run_state, environment)
	var state: Dictionary = _machine_state(run_state, environment)
	result["message"] = "%s: %s %s, %d Play. Bet 1-5 coins, hold, draw, double up." % [
		str(state.get("machine_name", "Video Poker")),
		str(_variant(state).get("label", "Jacks or Better")),
		str(_paytable_tier(state).get("label", "Standard")),
		_hand_count(state),
	]
	return result


# Generates the cabinet identity (game variant) before entry.
func generate_environment_state(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var variant_id := str(rng.pick(VARIANT_WEIGHTS, "jacks_or_better"))
	var tier_id := _pick_paytable_tier(rng)
	var denomination_set: Array = (rng.pick(COIN_DENOMINATION_SETS, COIN_DENOMINATION_SETS[0]) as Array).duplicate(true)
	var hand_count := int(rng.pick(MULTI_HAND_OPTIONS, 1))
	var base_ceiling := int(_copy_dict(environment.get("economic_profile", {})).get("stake_ceiling", 20))
	var wager_ceiling := run_state.wager_stake_ceiling(base_ceiling) if run_state != null else base_ceiling
	while hand_count > 1 and _minimum_denomination_credits(denomination_set) * hand_count > wager_ceiling:
		hand_count = _next_lower_hand_count(hand_count)
	var playable_indices: Array = _playable_denomination_indices(denomination_set, hand_count, wager_ceiling)
	var denomination_index := int(rng.pick(playable_indices, 0))
	var machine_name := str(rng.pick(["Candy Draw", "Neon Jacks", "Pink Deuces", "Hot Hold", "Lucky Glass", "Royal Static"], "Video Poker"))
	var tell := str(rng.pick([
		"the screen flickers when you palm",
		"the draw stutters a half second",
		"the hold lights blink out of time",
	], "the screen flickers when you palm"))
	var cabinet_key := "%s:%s:%s:%dplay:%s" % [
		variant_id,
		tier_id,
		str((denomination_set[denomination_index] as Dictionary).get("label", "1c")),
		hand_count,
		machine_name.to_snake_case(),
	]
	return {
		"schema": STATE_SCHEMA,
		"version": STATE_VERSION,
		"machine_name": machine_name,
		"cabinet_key": cabinet_key,
		"variant_id": variant_id,
		"paytable_tier_id": tier_id,
		"coin_denominations": denomination_set,
		"denomination_index": denomination_index,
		"multi_hand_count": hand_count,
		"progressive_meter": PROGRESSIVE_BASE + rng.randi_range(0, 180),
		"holdout_tell": tell,
		"hands_played": 0,
		"last_result": {},
	}


# Provides display/input state for the screen without mutating RunState.
func surface_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var state: Dictionary = _machine_state(run_state, environment)
	var variant: Dictionary = _variant(state)
	var ui: Dictionary = _normalized_ui_state(ui_state)
	ui["denomination_index"] = _next_playable_denomination_index(state, _denomination_index(ui, state) - 1, run_state, environment)
	ui["bet_level"] = _affordable_bet_level(state, ui, run_state, environment)
	var last_result: Dictionary = _copy_dict(state.get("last_result", {}))
	var hand_active := bool(ui.get("hand_active", false))
	var result_collected := bool(ui.get("collected", false))
	var double_phase := not result_collected and bool(ui.get("double_active", false)) and _pending_double_credits(last_result) > 0
	var showing_result := not result_collected and not hand_active and not last_result.is_empty()
	var idle_phase := not hand_active and last_result.is_empty() and not double_phase
	if result_collected and not hand_active:
		idle_phase = true
	var phase := "double_up" if double_phase else ("idle" if idle_phase else ("settled" if showing_result else "hold"))
	var bet_level := _bet_level(ui)
	var coin_count := _coin_count_for_level(bet_level)
	var denomination_index := _denomination_index(ui, state)
	var coin_value := _coin_value(state, denomination_index)
	var hand_count := _hand_count(state)
	var total_bet := _wager_for(state, ui)

	var hand: Array = []
	var final_hands: Array = []
	var hand_results: Array = []
	var holds: Array = []
	var scoring_indices: Array = []
	var drawn_indices: Array = []
	var category := ""
	var pay_label := ""
	var pay_mult := 0
	if phase == "idle":
		hand = _presentation_cards(HAND_SIZE)
	elif phase == "settled" or phase == "double_up":
		hand = CardShoeScript.card_array(last_result.get("hand", []))
		final_hands = _hands_array(last_result.get("hands", []))
		hand_results = _copy_array(last_result.get("hand_results", []))
		scoring_indices = _index_array(last_result.get("scoring_indices", []))
		drawn_indices = _index_array(last_result.get("drawn_indices", []))
		category = str(last_result.get("pay_key", ""))
		pay_label = str(last_result.get("pay_label", ""))
		pay_mult = int(last_result.get("pay_mult", 0))
	else:
		hand = _opening_hand(run_state, state)
		holds = _index_array(ui.get("holds", []))
	if hand.size() != HAND_SIZE:
		hand = _presentation_cards(HAND_SIZE) if phase == "idle" else _opening_hand(run_state, state)

	var suggested: Array = _suggested_holds(hand, variant) if phase == "hold" else []
	var marked := bool(ui.get("marked", false)) and phase == "hold"
	var win_credits := int(last_result.get("win_credits", 0)) if (phase == "settled" or phase == "double_up") else 0
	var pending_double := 0 if result_collected else _pending_double_credits(last_result)
	var double_view: Dictionary = _double_up_view(run_state, state, ui, last_result) if phase == "double_up" else {}
	var flip: Dictionary = _active_flip(ui, last_result, hand_active)
	var pit_boss: Dictionary = run_state.pit_boss_watch_status(environment)

	var spec: Dictionary = GameModule.surface_spec({
		"surface_renderer": "card_machine",
		"surface_life": "screen",
		"surface_cast": "machine",
		"surface_controls_native": true,
		"surface_fixed_price_actions": true,
		"surface_stake_controls_required": false,
		"surface_embeds_outcomes": true,
		"surface_animates_idle": false,
		"surface_realtime_state_refresh": false,
		"phase": phase,
		"machine_name": str(state.get("machine_name", "Video Poker")),
		"cabinet_key": str(state.get("cabinet_key", "")),
		"variant_id": str(state.get("variant_id", "jacks_or_better")),
		"variant_label": str(variant.get("label", "Jacks or Better")),
		"paytable_tier_id": str(state.get("paytable_tier_id", "standard")),
		"paytable_tier_label": str(_paytable_tier(state).get("label", "Standard")),
		"bet_level": bet_level,
		"bet_options": COIN_LEVELS,
		"coin_count": coin_count,
		"coin_value": coin_value,
		"coin_label": _coin_label(state, denomination_index),
		"coin_denominations": _coin_denominations(state),
		"denomination_index": denomination_index,
		"hand_count": hand_count,
		"multi_hand_mode": "%d Play" % hand_count,
		"bet_credits": total_bet,
		"win_credits": win_credits,
		"credits": maxi(0, run_state.bankroll),
		"progressive_meter": int(state.get("progressive_meter", PROGRESSIVE_BASE)),
		"holdout_tell": str(state.get("holdout_tell", "")),
		"hand": hand,
		"hands": final_hands,
		"hand_results": hand_results,
		"holds": holds,
		"suggested_holds": suggested,
		"scoring_indices": scoring_indices,
		"drawn_indices": drawn_indices,
		"marked": marked,
		"paytable_rows": _paytable_rows(variant),
		"paytable_columns": BET_LADDER.size(),
		"result_pay_key": category,
		"result_pay_label": pay_label,
		"payout_mult": pay_mult,
		"info_text": _info_text(phase, hand, holds, last_result, marked, variant),
		"result_message": str(last_result.get("summary", "")) if showing_result or double_phase else "",
		"result_bankroll_delta": int(last_result.get("bankroll_delta", 0)) if phase == "settled" else 0,
		"result_suspicion_delta": int(last_result.get("suspicion_delta", 0)) if phase == "settled" else 0,
		"double_up_available": pending_double > 0 and phase == "settled",
		"double_up_view": double_view,
		"pending_double_credits": pending_double,
		"pit_boss_watched": bool(pit_boss.get("watched", false)) if bool(pit_boss.get("active", false)) else false,
		"pit_boss_summary": str(pit_boss.get("summary", "")) if bool(pit_boss.get("active", false)) else "",
		"hands_played": int(state.get("hands_played", 0)),
		"native_selected_surface_actions": [],
		"surface_animation_channels": [
			GameModule.surface_animation_channel(
				FLIP_CHANNEL,
				str(flip.get("id", "")),
				FLIP_DURATION_MSEC if not str(flip.get("id", "")).is_empty() else 0,
				int(flip.get("started", 0))
			),
			GameModule.surface_animation_channel(
				DRAW_CASCADE_CHANNEL,
				str(flip.get("id", "")),
				FLIP_DURATION_MSEC if not str(flip.get("id", "")).is_empty() else 0,
				int(flip.get("started", 0))
			),
		],
		"surface_action_bindings": {},
		"surface_audio": GameModule.surface_audio_spec({
			"profile_id": "video_poker_machine",
			"action_cues": {
				"video_poker_hold": "machine_button",
				"video_poker_draw": "machine_button",
				"video_poker_mark": "machine_button",
				"video_poker_deal": "machine_button",
				"video_poker_bet_one": "machine_button",
				"video_poker_bet_max": "machine_button",
				"video_poker_double": "machine_button",
				"video_poker_collect": "machine_button",
				"video_poker_double_pick": "machine_button",
			},
		}),
	})
	return spec


# The bet is the module-owned ladder wager (2/5/10/15/20 credits), not a host stake.
func wager_cost_for_context(action_id: String, _stake: int, _run_state: RunState, _environment: Dictionary, ui_state: Dictionary = {}) -> int:
	if action_id == "double_up":
		return 0
	if action_id != "draw" and action_id != "mark_holds":
		return 0
	var state: Dictionary = _machine_state(_run_state, _environment)
	return _wager_for(state, _normalized_ui_state(ui_state))


# Draws the cabinet screen and registers visible/invisible hit regions.
func draw_surface(surface, surface_state: Dictionary, _render_context: Dictionary = {}) -> bool:
	if str(surface_state.get("surface_renderer", "")) != "card_machine":
		return false
	var phase := str(surface_state.get("phase", "hold"))
	_draw_machine(surface, surface_state)
	_draw_paytable_grid(surface, surface_state)
	_draw_meters(surface, surface_state)
	if phase == "double_up":
		_draw_double_up(surface, surface_state)
	else:
		_draw_card_row(surface, surface_state, phase)
	_draw_info_line(surface, surface_state)
	_draw_controls(surface, surface_state, phase)
	return true


# Converts screen clicks into UI-local bet/hold/deal/double state or shared actions.
func surface_action_command(surface_action: String, index: int, confirm_requested: bool, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var state: Dictionary = _machine_state(run_state, environment)
	var variant: Dictionary = _variant(state)
	var next: Dictionary = _normalized_ui_state(ui_state)
	next["denomination_index"] = _next_playable_denomination_index(state, _denomination_index(next, state) - 1, run_state, environment)
	next["bet_level"] = _affordable_bet_level(state, next, run_state, environment)
	match surface_action:
		"video_poker_bet_one":
			var level := (_bet_level(next) + 1) % BET_LADDER.size()
			next["bet_level"] = level
			next["bet_level"] = _affordable_bet_level(state, next, run_state, environment)
			var shown_coins := _coin_count_for_level(_bet_level(next))
			return _bet_command(next, _wager_for(state, next), "Bet %d coin%s." % [shown_coins, "" if shown_coins == 1 else "s"])
		"video_poker_bet_max":
			next["bet_level"] = MAX_BET_LEVEL
			next["bet_level"] = _affordable_bet_level(state, next, run_state, environment)
			return _bet_command(next, _wager_for(state, next), "Max bet: %d coins." % _coin_count_for_level(MAX_BET_LEVEL))
		"video_poker_denom":
			next["denomination_index"] = _next_playable_denomination_index(state, _denomination_index(next, state), run_state, environment)
			next["bet_level"] = _affordable_bet_level(state, next, run_state, environment)
			return _bet_command(next, _wager_for(state, next), "Denomination: %s." % _coin_label(state, _denomination_index(next, state)))
		"video_poker_deal":
			var level2 := _bet_level(next)
			var denom2 := _denomination_index(next, state)
			next = {"hand_active": true, "holds": [], "marked": false, "bet_level": level2, "denomination_index": denom2}
			next["deal_id"] = "deal_%d" % Time.get_ticks_msec()
			next["deal_started_msec"] = Time.get_ticks_msec()
			return GameModule.surface_command({
				"handled": true,
				"ui_state": next,
				"selected_index": index,
				"preserve_surface_ui_state": true,
				"set_stake": _wager_for(state, next),
				"message": "Dealt. Hold what pays, then draw.",
			})
		"video_poker_hold":
			if not bool(next.get("hand_active", false)):
				return _message_command(next, "Deal a hand first.")
			next["hand_active"] = true
			var holds: Array = _index_array(next.get("holds", []))
			if holds.has(index):
				holds.erase(index)
			elif index >= 0 and index < HAND_SIZE:
				holds.append(index)
			holds.sort()
			next["holds"] = holds
			next["marked"] = false
			return GameModule.surface_command({
				"handled": true,
				"ui_state": next,
				"selected_index": index,
				"preserve_surface_ui_state": true,
				"message": "Held: %s." % _hold_summary(holds),
			})
		"video_poker_draw":
			if not bool(next.get("hand_active", false)):
				return _message_command(next, "Deal a hand first.")
			next["hand_active"] = true
			next["marked"] = false
			return _action_command("draw", "legal", confirm_requested, next, index, _wager_for(state, next), "Draw ready. Click again to replace the un-held cards.")
		"video_poker_mark":
			if not bool(next.get("hand_active", false)):
				return _message_command(next, "Deal a hand first.")
			next["hand_active"] = true
			next["holds"] = _suggested_holds(_opening_hand(run_state, state), variant)
			next["marked"] = true
			return _action_command("mark_holds", "cheat", confirm_requested, next, index, _wager_for(state, next), "Holdout armed. Click again to palm in a card and draw.")
		"video_poker_collect":
			next = {
				"hand_active": false,
				"collected": true,
				"bet_level": _bet_level(next),
				"denomination_index": _denomination_index(next, state),
			}
			return GameModule.surface_command({
				"handled": true,
				"ui_state": next,
				"selected_index": index,
				"message": "Win collected. Deal again to play on.",
			})
		"video_poker_double":
			next["double_active"] = true
			next.erase("double_pick")
			next["deal_id"] = "double_%d" % Time.get_ticks_msec()
			next["deal_started_msec"] = Time.get_ticks_msec()
			return GameModule.surface_command({
				"handled": true,
				"ui_state": next,
				"selected_index": index,
				"preserve_surface_ui_state": true,
				"message": "Double or nothing: beat the dealer card.",
			})
		"video_poker_double_pick":
			if not bool(next.get("double_active", false)):
				return _message_command(next, "Press DOUBLE UP first.")
			next["double_pick"] = clampi(index, 0, 3)
			return _action_command("double_up", "legal", confirm_requested, next, index, 0, "Card chosen. Click again to flip it.")
	return {"handled": false}


# Default resolve path delegates to the context-aware resolver.
func resolve(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return resolve_with_context(action_id, stake, run_state, environment, rng, {})


# Resolves one draw (optionally with the holdout) or one double-up gamble.
func resolve_with_context(action_id: String, _stake: int, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary = {}) -> Dictionary:
	if action_id == "double_up":
		return _resolve_double_up(run_state, environment, rng, _normalized_ui_state(ui_state))
	if action_id != "draw" and action_id != "mark_holds":
		return _empty_result(action_id, 0, environment, "That video poker action is not available.")
	return _resolve_draw(action_id, run_state, environment, rng, _normalized_ui_state(ui_state))


func _resolve_draw(action_id: String, run_state: RunState, environment: Dictionary, rng: RngStream, ui: Dictionary) -> Dictionary:
	var is_cheat := action_id == "mark_holds"
	var state: Dictionary = _machine_state(run_state, environment)
	var variant: Dictionary = _variant(state)
	ui["denomination_index"] = _next_playable_denomination_index(state, _denomination_index(ui, state) - 1, run_state, environment)

	# Step down the bet ladder until the wager fits the bankroll and economy ceiling.
	var stake_ceiling := run_state.wager_stake_ceiling(int(_copy_dict(environment.get("economic_profile", {})).get("stake_ceiling", run_state.bankroll)))
	var affordable := mini(stake_ceiling, maxi(0, run_state.bankroll))
	var bet_level := _bet_level(ui)
	ui["bet_level"] = bet_level
	while bet_level > 0 and _wager_for(state, ui) > affordable:
		bet_level -= 1
		ui["bet_level"] = bet_level
	var bet_credits := _wager_for(state, ui)
	var coin_count := _coin_count_for_level(bet_level)
	var denomination_index := _denomination_index(ui, state)
	var coin_value := _coin_value(state, denomination_index)
	var hand_count := _hand_count(state)
	var is_max_bet := bet_level >= MAX_BET_LEVEL
	if bet_credits <= 0 or bet_credits > affordable:
		return _empty_result(action_id, 0, environment, "You do not have enough credits to deal.")

	# The deal is the deterministic opening; the draw pool is the rest of that deck,
	# shuffled with the injected stream so replacements are random and unique.
	var deck: Array = _deal_deck(run_state, state)
	var opening: Array = _slice_cards(deck, 0, HAND_SIZE)
	var holds: Array = _index_array(ui.get("holds", []))
	var draw_base: Array = _deck_without_cards(_base_deck(variant), opening)
	var final_hands: Array = []
	var hand_results: Array = []
	var total_gross := 0
	var total_progressive_bonus := 0
	var total_bonus := 0
	var best_index := 0
	var best_value := -999999
	var luck_bonus := clampi(run_state.luck_win_chance_bonus() + _item_bonus("win_chance", run_state, is_cheat), 0, 35)
	for hand_index in range(hand_count):
		var pool: Array = CardShoeScript.shuffle_cards(draw_base, rng)
		var final_hand: Array = opening.duplicate(true)
		var drawn_indices: Array = []
		var pool_cursor := 0
		for i in range(HAND_SIZE):
			if not holds.has(i):
				if pool_cursor < pool.size():
					final_hand[i] = (pool[pool_cursor] as Dictionary).duplicate(true)
					pool_cursor += 1
					drawn_indices.append(i)
		if is_cheat and hand_index == 0:
			final_hand = _apply_holdout(final_hand, holds, variant)
		var descriptor: Dictionary = _evaluate(final_hand, _wild_ranks(variant))
		var pay_row: Dictionary = _pay_for(descriptor, variant)
		if not is_cheat and int(pay_row.get("mult", 0)) <= 0 and luck_bonus > 0 and rng.randi_range(1, 100) <= luck_bonus:
			final_hand = _apply_holdout(final_hand, holds, variant)
			descriptor = _evaluate(final_hand, _wild_ranks(variant))
			pay_row = _pay_for(descriptor, variant)
		var gross_payout := _row_pay(pay_row, coin_count, is_max_bet) * coin_value
		var bonus_layer: Dictionary = _bonus_layer(final_hand, descriptor, pay_row, state, coin_count, coin_value, is_max_bet)
		var bonus_payout := int(bonus_layer.get("bonus", 0))
		var hand_total := gross_payout + bonus_payout
		total_gross += hand_total
		total_bonus += bonus_payout
		total_progressive_bonus += int(bonus_layer.get("progressive_bonus", 0))
		var value := _descriptor_value(descriptor, variant) + bonus_payout
		if value > best_value:
			best_value = value
			best_index = hand_index
		final_hands.append(final_hand.duplicate(true))
		hand_results.append({
			"hand_index": hand_index,
			"hand": final_hand.duplicate(true),
			"pay_key": str(pay_row.get("key", "")),
			"pay_label": str(pay_row.get("label", "")),
			"pay_mult": int(pay_row.get("mult", 0)),
			"gross": gross_payout,
			"bonus": bonus_payout,
			"total": hand_total,
			"bonus_label": str(bonus_layer.get("label", "")),
			"scoring_indices": _index_array(descriptor.get("scoring_indices", [])),
			"drawn_indices": drawn_indices,
		})
	if final_hands.is_empty():
		return _empty_result(action_id, bet_credits, environment, "The machine failed to draw a hand.")
	var primary_result: Dictionary = hand_results[clampi(best_index, 0, hand_results.size() - 1)]
	var final_hand: Array = CardShoeScript.card_array(primary_result.get("hand", []))
	var primary_descriptor: Dictionary = _evaluate(final_hand, _wild_ranks(variant))
	var pay_row: Dictionary = _pay_for(primary_descriptor, variant)
	var gross_payout := total_gross
	var bankroll_delta := gross_payout - bet_credits
	var won := bankroll_delta > 0
	if won:
		bankroll_delta = maxi(1, bankroll_delta + run_state.luck_payout_bonus(bet_credits, true) + _item_bonus("win_bonus", run_state, is_cheat))
	elif bankroll_delta < 0:
		bankroll_delta = mini(0, bankroll_delta + _item_bonus("loss_reduction", run_state, is_cheat))

	var suspicion_delta := 0
	var security_message := ""
	var pit_boss_summary := ""
	var pit_boss_watched := false
	var pit_boss_heat_bonus := 0
	var ended := false
	if is_cheat:
		var cheat_def: Dictionary = _cheat_action_def()
		var base_heat := int(cheat_def.get("suspicion_delta", 14))
		var pit_boss_status: Dictionary = run_state.pit_boss_watch_status(environment)
		pit_boss_heat_bonus = int(pit_boss_status.get("cheat_heat_bonus", 0)) if bool(pit_boss_status.get("active", false)) else 0
		pit_boss_watched = bool(pit_boss_status.get("watched", false))
		var raw_heat := maxi(1, base_heat + _item_bonus("cheat_suspicion_delta", run_state, true) + run_state.security_risk_bonus("cheat") + pit_boss_heat_bonus)
		suspicion_delta = run_state.alcohol_adjusted_suspicion_delta(raw_heat)
		if bool(pit_boss_status.get("active", false)):
			pit_boss_summary = str(pit_boss_status.get("summary", ""))
		var security_pressure: Dictionary = run_state.security_action_pressure("cheat", bet_credits, run_state.suspicion_level() + suspicion_delta)
		var security_bankroll_delta := int(security_pressure.get("bankroll_delta", 0))
		if security_bankroll_delta != 0:
			bankroll_delta += security_bankroll_delta
		security_message = str(security_pressure.get("message", ""))
		ended = bool(security_pressure.get("ended", false))

	var blurb := _hand_blurb(primary_descriptor, pay_row, variant)
	if hand_count > 1:
		blurb = "%s x%d hands" % [blurb, hand_count]
	var message := _outcome_message(blurb, pay_row, gross_payout, bankroll_delta, suspicion_delta, is_cheat, pit_boss_summary, security_message)
	# Only a clean (non-cheated) paying win can be gambled on the double-up.
	var win_credits := maxi(0, bankroll_delta) if won else 0

	var resolved_at := Time.get_ticks_msec()
	state["progressive_meter"] = PROGRESSIVE_BASE if total_progressive_bonus > 0 else int(state.get("progressive_meter", PROGRESSIVE_BASE)) + maxi(1, int(bet_credits / 30))
	state["last_result"] = {
		"hand": final_hand,
		"hands": final_hands,
		"hand_results": hand_results,
		"pay_key": str(primary_result.get("pay_key", "")),
		"pay_label": str(primary_result.get("pay_label", "")),
		"pay_mult": int(primary_result.get("pay_mult", 0)),
		"scoring_indices": _index_array(primary_result.get("scoring_indices", [])),
		"drawn_indices": _index_array(primary_result.get("drawn_indices", [])),
		"blurb": blurb,
		"bet_level": bet_level,
		"coin_count": coin_count,
		"coin_value": coin_value,
		"coin_label": _coin_label(state, denomination_index),
		"denomination_index": denomination_index,
		"hand_count": hand_count,
		"bet_credits": bet_credits,
		"gross_credits": gross_payout,
		"bonus_credits": total_bonus,
		"progressive_bonus": total_progressive_bonus,
		"win_credits": win_credits,
		"double_credits": win_credits if (won and not is_cheat) else 0,
		"double_chain": 0,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"cheated": is_cheat,
		"summary": message,
		"flip_id": "draw_%d" % resolved_at,
		"resolved_at_msec": resolved_at,
	}
	state["hands_played"] = int(state.get("hands_played", 0)) + 1
	_update_environment_state(environment, state)

	var story_entry := {
		"type": "game_action",
		"game_id": get_id(),
		"action_id": action_id,
		"won": won,
		"variant": str(state.get("variant_id", "")),
		"paytable_tier": str(state.get("paytable_tier_id", "")),
		"category": str(primary_result.get("pay_key", "")),
		"payout": gross_payout,
		"stake_cost": bet_credits,
		"bet_credits": bet_credits,
		"coin_count": coin_count,
		"coin_value": coin_value,
		"hand_count": hand_count,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"cheated": is_cheat,
		"held_count": holds.size(),
		"skill_outcome": "holdout_card" if is_cheat else "",
		"pit_boss_watched": pit_boss_watched,
		"pit_boss_heat_bonus": pit_boss_heat_bonus,
		"pit_boss_summary": pit_boss_summary,
		"security_message": security_message,
		"skill_security_pressure_checked": is_cheat,
		"environment_id": environment.get("id", ""),
	}
	var result := _build_result(action_id, "cheat" if is_cheat else "legal", bet_credits, bankroll_delta, suspicion_delta, ended, message, story_entry, environment)
	result["video_poker_hand"] = final_hand
	result["video_poker_hands"] = final_hands
	result["video_poker_hand_results"] = hand_results
	result["video_poker_category"] = str(primary_result.get("pay_key", ""))
	result["video_poker_pay_label"] = str(primary_result.get("pay_label", ""))
	result["video_poker_payout_mult"] = int(primary_result.get("pay_mult", 0))
	result["video_poker_gross"] = gross_payout
	result["video_poker_bet"] = bet_credits
	result["video_poker_coin_count"] = coin_count
	result["video_poker_coin_value"] = coin_value
	result["video_poker_hand_count"] = hand_count
	result["video_poker_bonus"] = total_bonus
	result["video_poker_progressive_bonus"] = total_progressive_bonus
	result["video_poker_held_count"] = holds.size()
	result["video_poker_cheated"] = is_cheat
	result["video_poker_drawn_indices"] = _index_array(primary_result.get("drawn_indices", []))
	result["video_poker_variant"] = str(state.get("variant_id", ""))
	result["video_poker_paytable_tier"] = str(state.get("paytable_tier_id", ""))
	if is_cheat:
		result["video_poker_pit_boss_watched"] = pit_boss_watched
		result["video_poker_pit_boss_heat_bonus"] = pit_boss_heat_bonus
		result["skill_outcome"] = "holdout_card"
	GameModule.apply_result(run_state, result, rng)
	return result


# Resolves a double-or-nothing gamble against the dealer card.
func _resolve_double_up(run_state: RunState, environment: Dictionary, rng: RngStream, ui: Dictionary) -> Dictionary:
	var state: Dictionary = _machine_state(run_state, environment)
	var last_result: Dictionary = _copy_dict(state.get("last_result", {}))
	var at_risk := _pending_double_credits(last_result)
	if at_risk <= 0:
		return _empty_result("double_up", 0, environment, "There is no win to gamble.")
	var view: Dictionary = _double_up_view(run_state, state, ui, last_result)
	var dealer_rank := int(view.get("dealer_rank", 7))
	var picks: Array = view.get("pick_ranks", [])
	var pick_index := clampi(int(ui.get("double_pick", 0)), 0, picks.size() - 1) if not picks.is_empty() else 0
	var pick_rank := int(picks[pick_index]) if not picks.is_empty() else 7
	# Consume the injected stream so the gamble advances the run RNG deterministically.
	rng.randi_range(1, 100)

	var outcome := "win" if pick_rank > dealer_rank else ("push" if pick_rank == dealer_rank else "lose")
	var bankroll_delta := 0
	var next_double := 0
	var chain := int(last_result.get("double_chain", 0))
	if outcome == "win":
		bankroll_delta = at_risk
		chain += 1
		next_double = (at_risk * 2) if chain < DOUBLE_UP_CAP else 0
	elif outcome == "lose":
		bankroll_delta = -at_risk
	var message := _double_up_message(outcome, pick_rank, dealer_rank, bankroll_delta)

	last_result["double_credits"] = next_double
	last_result["double_chain"] = chain
	last_result["win_credits"] = (at_risk * 2) if outcome == "win" else (at_risk if outcome == "push" else 0)
	last_result["summary"] = message
	last_result["double_dealer_rank"] = dealer_rank
	last_result["double_pick_rank"] = pick_rank
	last_result["double_outcome"] = outcome
	last_result["resolved_at_msec"] = Time.get_ticks_msec()
	state["last_result"] = last_result
	_update_environment_state(environment, state)

	var story_entry := {
		"type": "game_action",
		"game_id": get_id(),
		"action_id": "double_up",
		"won": outcome == "win",
		"double_outcome": outcome,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": 0,
		"at_risk": at_risk,
		"environment_id": environment.get("id", ""),
	}
	var result := _build_result("double_up", "legal", at_risk, bankroll_delta, 0, false, message, story_entry, environment)
	result["video_poker_double_outcome"] = outcome
	result["video_poker_double_at_risk"] = at_risk
	result["video_poker_double_next"] = next_double
	GameModule.apply_result(run_state, result, rng)
	return result


# Provides a compact status payload for the room machine prop badge.
func environment_object_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var state: Dictionary = _machine_state(run_state, environment)
	if state.is_empty():
		return {}
	var variant: Dictionary = _variant(state)
	var last_result: Dictionary = _copy_dict(state.get("last_result", {}))
	var hands := int(state.get("hands_played", 0))
	var badge := str(variant.get("label", "DRAW")).to_upper().left(8)
	if not last_result.is_empty():
		badge = str(last_result.get("pay_label", badge)).to_upper().left(8)
	return {
		"runtime_state": {
			"hands_played": hands,
			"variant": str(state.get("variant_id", "")),
			"last_category": str(last_result.get("pay_key", "")),
			"last_bankroll_delta": int(last_result.get("bankroll_delta", 0)),
		},
		"visual_state": {
			"machine": str(state.get("machine_name", "Video Poker")),
			"variant": str(variant.get("label", "")),
			"tier": str(_paytable_tier(state).get("label", "Standard")),
			"denomination": _coin_label(state, int(state.get("denomination_index", 0))),
			"play_count": _hand_count(state),
			"hands": hands,
		},
		"status_summary": "%s (%s): %d hand%s drawn." % [str(state.get("machine_name", "Video Poker")), str(variant.get("label", "")), hands, "" if hands == 1 else "s"],
		"effect_summary": "%s %s, %s, %d Play." % [str(variant.get("label", "Jacks or Better")), str(_paytable_tier(state).get("label", "Standard")), _coin_label(state, int(state.get("denomination_index", 0))), _hand_count(state)],
		"state_badge": badge,
	}


# --- State helpers -----------------------------------------------------------

func _machine_state(run_state: RunState, environment: Dictionary) -> Dictionary:
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
	normalized["machine_name"] = str(normalized.get("machine_name", "Video Poker"))
	normalized["cabinet_key"] = str(normalized.get("cabinet_key", "%s:%s" % [normalized.get("machine_name", "Video Poker"), normalized.get("variant_id", "jacks_or_better")]))
	normalized["variant_id"] = str(normalized.get("variant_id", "jacks_or_better"))
	if not VARIANTS.has(normalized["variant_id"]):
		normalized["variant_id"] = "jacks_or_better"
	normalized["paytable_tier_id"] = str(normalized.get("paytable_tier_id", "standard"))
	if not PAYTABLE_TIERS.has(normalized["paytable_tier_id"]):
		normalized["paytable_tier_id"] = "standard"
	normalized["coin_denominations"] = _normalize_denominations(normalized.get("coin_denominations", []))
	normalized["denomination_index"] = clampi(int(normalized.get("denomination_index", 0)), 0, maxi(0, (normalized["coin_denominations"] as Array).size() - 1))
	normalized["multi_hand_count"] = _normalize_hand_count(int(normalized.get("multi_hand_count", 1)))
	normalized["progressive_meter"] = maxi(PROGRESSIVE_BASE, int(normalized.get("progressive_meter", PROGRESSIVE_BASE)))
	normalized["holdout_tell"] = str(normalized.get("holdout_tell", ""))
	normalized["hands_played"] = int(normalized.get("hands_played", 0))
	normalized["last_result"] = _copy_dict(normalized.get("last_result", {}))
	return normalized


func _update_environment_state(environment: Dictionary, state: Dictionary) -> void:
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	game_states[get_id()] = state.duplicate(true)
	environment["game_states"] = game_states


func _normalized_ui_state(ui_state: Dictionary) -> Dictionary:
	var next: Dictionary = ui_state.duplicate(true)
	next["holds"] = _index_array(next.get("holds", []))
	next["hand_active"] = bool(next.get("hand_active", false))
	next["marked"] = bool(next.get("marked", false))
	next["bet_level"] = clampi(int(next.get("bet_level", MAX_BET_LEVEL)), 0, MAX_BET_LEVEL)
	next["denomination_index"] = maxi(0, int(next.get("denomination_index", 0)))
	return next


func _variant(state: Dictionary) -> Dictionary:
	var variant_id := str(state.get("variant_id", "jacks_or_better"))
	if not VARIANTS.has(variant_id):
		variant_id = "jacks_or_better"
	var variant: Dictionary = (VARIANTS[variant_id] as Dictionary).duplicate(true)
	variant["id"] = variant_id
	var tier_id := str(state.get("paytable_tier_id", "standard"))
	var tier: Dictionary = _paytable_tier({"paytable_tier_id": tier_id})
	var all_overrides: Dictionary = _copy_dict(tier.get("overrides", {}))
	var variant_overrides: Dictionary = _copy_dict(all_overrides.get(variant_id, {}))
	var rows: Array = []
	for row_value in variant.get("rows", []):
		var row: Dictionary = row_value if typeof(row_value) == TYPE_DICTIONARY else {}
		var next_row: Dictionary = row.duplicate(true)
		var row_key := str(next_row.get("key", ""))
		if variant_overrides.has(row_key):
			next_row["mult"] = int(variant_overrides.get(row_key, int(next_row.get("mult", 0))))
		rows.append(next_row)
	variant["rows"] = rows
	variant["paytable_tier_id"] = tier_id
	variant["paytable_tier_label"] = str(tier.get("label", "Standard"))
	return variant


func _paytable_tier(state: Dictionary) -> Dictionary:
	var tier_id := str(state.get("paytable_tier_id", "standard"))
	if not PAYTABLE_TIERS.has(tier_id):
		tier_id = "standard"
	var tier: Dictionary = (PAYTABLE_TIERS[tier_id] as Dictionary).duplicate(true)
	tier["id"] = tier_id
	return tier


func _pick_paytable_tier(rng: RngStream) -> String:
	var total_weight := 0
	for tier_id in PAYTABLE_TIERS.keys():
		var tier: Dictionary = PAYTABLE_TIERS[tier_id]
		total_weight += maxi(1, int(tier.get("weight", 1)))
	var roll := rng.randi_range(1, maxi(1, total_weight))
	var cursor := 0
	for tier_id in PAYTABLE_TIERS.keys():
		var tier: Dictionary = PAYTABLE_TIERS[tier_id]
		cursor += maxi(1, int(tier.get("weight", 1)))
		if roll <= cursor:
			return str(tier_id)
	return "standard"


func _normalize_denominations(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry_value in value:
			if typeof(entry_value) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_value
			var credits := maxi(1, int(entry.get("credits", 1)))
			var label := str(entry.get("label", "$%d" % credits))
			result.append({"label": label, "credits": credits})
	if result.is_empty():
		for entry_value in COIN_DENOMINATION_SETS[0]:
			var entry: Dictionary = entry_value
			result.append(entry.duplicate(true))
	return result


func _coin_denominations(state: Dictionary) -> Array:
	return _normalize_denominations(state.get("coin_denominations", []))


func _denomination_index(ui: Dictionary, state: Dictionary) -> int:
	var denominations: Array = _coin_denominations(state)
	return clampi(int(ui.get("denomination_index", state.get("denomination_index", 0))), 0, maxi(0, denominations.size() - 1))


func _coin_value(state: Dictionary, index: int) -> int:
	var denominations: Array = _coin_denominations(state)
	if denominations.is_empty():
		return 1
	var entry: Dictionary = denominations[clampi(index, 0, denominations.size() - 1)]
	return maxi(1, int(entry.get("credits", 1)))


func _coin_label(state: Dictionary, index: int) -> String:
	var denominations: Array = _coin_denominations(state)
	if denominations.is_empty():
		return "1c"
	var entry: Dictionary = denominations[clampi(index, 0, denominations.size() - 1)]
	return str(entry.get("label", "1c"))


func _normalize_hand_count(count: int) -> int:
	var best := 1
	var best_distance := 999
	for option in MULTI_HAND_OPTIONS:
		var distance := absi(int(option) - count)
		if distance < best_distance:
			best_distance = distance
			best = int(option)
	return best


func _hand_count(state: Dictionary) -> int:
	return _normalize_hand_count(int(state.get("multi_hand_count", 1)))


func _next_lower_hand_count(count: int) -> int:
	var lowered := 1
	for option in MULTI_HAND_OPTIONS:
		var option_count := int(option)
		if option_count < count:
			lowered = option_count
	return lowered


func _minimum_denomination_credits(denominations: Array) -> int:
	var lowest := 999999
	for entry_value in denominations:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		lowest = mini(lowest, maxi(1, int(entry.get("credits", 1))))
	return 1 if lowest == 999999 else lowest


func _playable_denomination_indices(denominations: Array, hand_count: int, wager_ceiling: int) -> Array:
	var result: Array = []
	for i in range(denominations.size()):
		var entry: Dictionary = denominations[i] if typeof(denominations[i]) == TYPE_DICTIONARY else {}
		var min_wager := maxi(1, int(entry.get("credits", 1))) * maxi(1, hand_count)
		if min_wager <= wager_ceiling:
			result.append(i)
	if result.is_empty():
		result.append(0)
	return result


func _affordable_bet_level(state: Dictionary, ui: Dictionary, run_state: RunState, environment: Dictionary) -> int:
	var level := _bet_level(ui)
	var economic_profile: Dictionary = _copy_dict(environment.get("economic_profile", {}))
	var base_ceiling := int(economic_profile.get("stake_ceiling", run_state.bankroll if run_state != null else 20))
	var wager_ceiling := run_state.wager_stake_ceiling(base_ceiling) if run_state != null else base_ceiling
	var affordable := mini(wager_ceiling, maxi(0, run_state.bankroll if run_state != null else wager_ceiling))
	var next: Dictionary = ui.duplicate(true)
	while level > 0:
		next["bet_level"] = level
		if _wager_for(state, next) <= affordable:
			return level
		level -= 1
	next["bet_level"] = 0
	return 0


func _next_playable_denomination_index(state: Dictionary, current_index: int, run_state: RunState, environment: Dictionary) -> int:
	var denominations: Array = _coin_denominations(state)
	var economic_profile: Dictionary = _copy_dict(environment.get("economic_profile", {}))
	var base_ceiling := int(economic_profile.get("stake_ceiling", run_state.bankroll if run_state != null else 20))
	var wager_ceiling := run_state.wager_stake_ceiling(base_ceiling) if run_state != null else base_ceiling
	var playable: Array = _playable_denomination_indices(denominations, _hand_count(state), wager_ceiling)
	if playable.is_empty():
		return 0
	for offset in range(1, denominations.size() + 1):
		var candidate := (current_index + offset) % denominations.size()
		if playable.has(candidate):
			return candidate
	return int(playable[0])


func _wild_ranks(variant: Dictionary) -> Array:
	return _index_array_raw(variant.get("wild_ranks", []))


func _bet_level(ui: Dictionary) -> int:
	return clampi(int(ui.get("bet_level", MAX_BET_LEVEL)), 0, MAX_BET_LEVEL)


func _bet_for_level(level: int) -> int:
	return _coin_count_for_level(level)


func _coin_count_for_level(level: int) -> int:
	return int(COIN_LEVELS[clampi(level, 0, MAX_COIN_LEVEL)])


func _wager_for(state: Dictionary, ui: Dictionary) -> int:
	var level := _bet_level(ui)
	var coin_count := _coin_count_for_level(level)
	var coin_value := _coin_value(state, _denomination_index(ui, state))
	return maxi(1, coin_count * coin_value * _hand_count(state))


# --- Deck and deal -----------------------------------------------------------

func _deal_deck(run_state: RunState, state: Dictionary) -> Array:
	var hands := int(state.get("hands_played", 0))
	var rng_state := int(run_state.rng_state) if run_state != null else 0
	var seed_text := str(run_state.seed_text) if run_state != null else "video_poker"
	var local_rng := RngStream.new()
	local_rng.configure(_stable_hash("%s:%s:%s:%d:%d:deal" % [get_id(), str(state.get("cabinet_key", "")), seed_text, rng_state, hands]))
	return CardShoeScript.shuffle_cards(_base_deck(_variant(state)), local_rng)


func _opening_hand(run_state: RunState, state: Dictionary) -> Array:
	return _slice_cards(_deal_deck(run_state, state), 0, HAND_SIZE)


func _slice_cards(deck: Array, from_index: int, to_index: int) -> Array:
	var result: Array = []
	for i in range(maxi(0, from_index), mini(to_index, deck.size())):
		if typeof(deck[i]) == TYPE_DICTIONARY:
			result.append((deck[i] as Dictionary).duplicate(true))
	return result


func _base_deck(variant: Dictionary) -> Array:
	var deck: Array = CardShoeScript.build_deck()
	if bool(variant.get("include_joker", false)):
		deck.append({"rank": 0, "suit": 4, "deck": 0, "joker": true})
	return deck


func _deck_without_cards(deck: Array, cards: Array) -> Array:
	var result: Array = CardShoeScript.card_array(deck)
	for remove_value in cards:
		if typeof(remove_value) != TYPE_DICTIONARY:
			continue
		var remove_card: Dictionary = remove_value
		for i in range(result.size()):
			var candidate: Dictionary = result[i] if typeof(result[i]) == TYPE_DICTIONARY else {}
			if _same_card(candidate, remove_card):
				result.remove_at(i)
				break
	return result


func _same_card(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("rank", -99)) == int(b.get("rank", -98)) and int(a.get("suit", -99)) == int(b.get("suit", -98)) and int(a.get("deck", 0)) == int(b.get("deck", 0))


# Replaces a single drawn card with the best-improving legal card not in the hand.
func _apply_holdout(hand: Array, holds: Array, variant: Dictionary) -> Array:
	var wild_ranks: Array = _wild_ranks(variant)
	var best_hand: Array = hand.duplicate(true)
	var best_value := _descriptor_value(_evaluate(hand, wild_ranks), variant)
	for i in range(HAND_SIZE):
		if holds.has(i):
			continue
		for suit in range(CardShoeScript.SUIT_COUNT):
			for rank in range(CardShoeScript.RANK_MIN, CardShoeScript.RANK_MAX + 1):
				if _hand_contains(hand, rank, suit, i):
					continue
				var trial: Array = hand.duplicate(true)
				trial[i] = {"rank": rank, "suit": suit, "deck": 0}
				var value := _descriptor_value(_evaluate(trial, wild_ranks), variant)
				if value > best_value:
					best_value = value
					best_hand = trial.duplicate(true)
	return best_hand


func _descriptor_value(descriptor: Dictionary, variant: Dictionary) -> int:
	var pay_row: Dictionary = _pay_for(descriptor, variant)
	return int(pay_row.get("mult", 0)) * 100 + 50 - _row_index(variant, str(pay_row.get("key", "")))


func _hand_contains(hand: Array, rank: int, suit: int, except_index: int) -> bool:
	for i in range(hand.size()):
		if i == except_index:
			continue
		var card: Dictionary = hand[i] if typeof(hand[i]) == TYPE_DICTIONARY else {}
		if int(card.get("rank", 0)) == rank and int(card.get("suit", -1)) == suit:
			return true
	return false


# --- Evaluation --------------------------------------------------------------

# Evaluates five cards into a base hand descriptor. Non-wild variants use the
# natural evaluator (includes pairs); wild variants use the wild evaluator.
func _evaluate(hand: Array, wild_ranks: Array) -> Dictionary:
	if wild_ranks.is_empty():
		return _evaluate_natural(hand)
	return _evaluate_wild(hand, wild_ranks)


func _evaluate_natural(hand: Array) -> Dictionary:
	var ranks: Array = []
	var suits: Array = []
	for card_value in hand:
		var card: Dictionary = card_value if typeof(card_value) == TYPE_DICTIONARY else {}
		ranks.append(int(card.get("rank", 0)))
		suits.append(int(card.get("suit", -1)))
	var rank_counts: Dictionary = _rank_counts(ranks)
	var is_flush := _suits_uniform(suits)
	var straight_high := _natural_straight_high(rank_counts)
	var is_straight := straight_high > 0

	var base := "nothing"
	var quad_rank := 0
	var kicker := 0
	var pair_high := false
	if is_straight and is_flush:
		base = "royal_flush" if straight_high == 14 and _natural_top_keys(rank_counts) == [10, 11, 12, 13, 14] else "straight_flush"
	elif _max_count(rank_counts) == 4:
		base = "four_kind"
		quad_rank = _rank_with_count(rank_counts, 4)
		kicker = _other_rank(rank_counts, quad_rank)
	elif _max_count(rank_counts) == 3 and _has_count(rank_counts, 2):
		base = "full_house"
	elif is_flush:
		base = "flush"
	elif is_straight:
		base = "straight"
	elif _max_count(rank_counts) == 3:
		base = "three_kind"
	elif _pair_count(rank_counts) == 2:
		base = "two_pair"
	elif _max_count(rank_counts) == 2:
		base = "one_pair"
		pair_high = _high_pair_rank(rank_counts) >= RANK_JACK

	return {
		"base": base,
		"quad_rank": quad_rank,
		"kicker": kicker,
		"pair_high": pair_high,
		"straight_high": straight_high,
		"suit": int(suits[0]) if is_flush and not suits.is_empty() else -1,
		"rank_counts": rank_counts,
		"scoring_indices": _natural_scoring_indices(ranks, base, rank_counts),
	}


# Analytical wild-card evaluator. Picks the highest-paying achievable category.
func _evaluate_wild(hand: Array, wild_ranks: Array) -> Dictionary:
	var naturals: Array = []
	var wilds := 0
	for card_value in hand:
		var card: Dictionary = card_value if typeof(card_value) == TYPE_DICTIONARY else {}
		if wild_ranks.has(int(card.get("rank", 0))):
			wilds += 1
		else:
			naturals.append(card)
	var nat_ranks: Array = []
	var nat_suits: Array = []
	for card_value in naturals:
		var card: Dictionary = card_value
		nat_ranks.append(int(card.get("rank", 0)))
		nat_suits.append(int(card.get("suit", -1)))
	var nat_counts: Dictionary = _rank_counts(nat_ranks)
	var top := _max_count(nat_counts)
	var suits_uniform := _suits_uniform(nat_suits)

	var achievable := {}
	achievable["natural_royal"] = wilds == 0 and suits_uniform and _natural_top_keys(nat_counts) == [10, 11, 12, 13, 14]
	achievable["four_deuces"] = wilds == 4
	achievable["wild_royal"] = wilds > 0 and _can_wild_royal(nat_ranks, nat_suits, wilds)
	achievable["five_kind"] = top + wilds >= 5
	achievable["straight_flush"] = suits_uniform and _wild_straight_possible(nat_ranks, wilds)
	achievable["four_kind"] = top + wilds >= 4
	achievable["full_house"] = _wild_full_house(nat_counts, wilds)
	achievable["flush"] = suits_uniform
	achievable["straight"] = _wild_straight_possible(nat_ranks, wilds)
	achievable["three_kind"] = top + wilds >= 3
	achievable["kings_or_better"] = _wild_kings_or_better(nat_counts, nat_ranks, wilds)

	return {
		"base": "wild",
		"wild_achievable": achievable,
		"wild_count": wilds,
		"scoring_indices": [0, 1, 2, 3, 4],
	}


func _can_wild_royal(nat_ranks: Array, nat_suits: Array, wilds: int) -> bool:
	if wilds == 0:
		return false
	if not _suits_uniform(nat_suits):
		return false
	var seen := {}
	for rank in nat_ranks:
		if int(rank) < 10:
			return false
		if seen.has(int(rank)):
			return false
		seen[int(rank)] = true
	return true


func _wild_straight_possible(nat_ranks: Array, _wilds: int) -> bool:
	var counts := _rank_counts(nat_ranks)
	for rank in counts.keys():
		if int(counts[rank]) >= 2:
			return false
	var distinct: Array = counts.keys()
	if distinct.is_empty():
		return true
	var ace_high: Array = distinct.duplicate()
	ace_high.sort()
	if int(ace_high[ace_high.size() - 1]) - int(ace_high[0]) <= 4:
		return true
	var ace_low: Array = []
	for rank in distinct:
		ace_low.append(1 if int(rank) == 14 else int(rank))
	ace_low.sort()
	return int(ace_low[ace_low.size() - 1]) - int(ace_low[0]) <= 4


func _wild_full_house(nat_counts: Dictionary, wilds: int) -> bool:
	var values: Array = nat_counts.values()
	values.sort()
	values.reverse()
	var a := int(values[0]) if values.size() > 0 else 0
	var b := int(values[1]) if values.size() > 1 else 0
	if nat_counts.size() < 2:
		return false
	return maxi(0, 3 - a) + maxi(0, 2 - b) <= wilds


func _wild_kings_or_better(nat_counts: Dictionary, nat_ranks: Array, wilds: int) -> bool:
	for rank in nat_counts.keys():
		if int(rank) >= 13 and int(nat_counts[rank]) >= 2:
			return true
	if wilds > 0:
		for rank_value in nat_ranks:
			if int(rank_value) >= 13:
				return true
	return false


# --- Paytable mapping --------------------------------------------------------

# Maps a hand descriptor to the paying row of the active variant (or a no-pay row).
func _pay_for(descriptor: Dictionary, variant: Dictionary) -> Dictionary:
	var key := _pay_key(descriptor, variant)
	if key.is_empty():
		return {"key": "", "label": "No Pay", "mult": 0}
	for row_value in variant.get("rows", []):
		var row: Dictionary = row_value
		if str(row.get("key", "")) == key:
			return row.duplicate(true)
	return {"key": "", "label": "No Pay", "mult": 0}


func _pay_key(descriptor: Dictionary, variant: Dictionary) -> String:
	if str(descriptor.get("base", "")) == "wild":
		return _wild_pay_key(descriptor, variant)
	var base := str(descriptor.get("base", "nothing"))
	var variant_id := _variant_id_of(variant)
	match base:
		"royal_flush":
			return "royal_flush"
		"straight_flush":
			return "straight_flush"
		"full_house":
			return "full_house"
		"flush":
			return "flush"
		"straight":
			return "straight"
		"three_kind":
			return "three_kind"
		"two_pair":
			return "two_pair"
		"one_pair":
			return "jacks_or_better" if bool(descriptor.get("pair_high", false)) else ""
		"four_kind":
			return _four_kind_key(int(descriptor.get("quad_rank", 0)), int(descriptor.get("kicker", 0)), variant_id)
	return ""


func _four_kind_key(quad_rank: int, kicker: int, variant_id: String) -> String:
	if variant_id == "jacks_or_better":
		return "four_kind"
	if variant_id == "bonus_poker":
		if quad_rank == 14:
			return "four_aces"
		if quad_rank >= 2 and quad_rank <= 4:
			return "four_2_4"
		return "four_5_k"
	if variant_id == "double_double_bonus":
		if quad_rank == 14:
			return "four_aces_kicker" if (kicker >= 2 and kicker <= 4) else "four_aces"
		if quad_rank >= 2 and quad_rank <= 4:
			return "four_2_4_kicker" if (kicker == 14 or (kicker >= 2 and kicker <= 4)) else "four_2_4"
		return "four_5_k"
	return "four_kind"


# Picks the highest-paying achievable wild category for the variant.
func _wild_pay_key(descriptor: Dictionary, variant: Dictionary) -> String:
	var achievable: Dictionary = _copy_dict(descriptor.get("wild_achievable", {}))
	var best_key := ""
	var best_mult := -1
	for row_value in variant.get("rows", []):
		var row: Dictionary = row_value
		var key := str(row.get("key", ""))
		if bool(achievable.get(key, false)) and int(row.get("mult", 0)) > best_mult:
			best_mult = int(row.get("mult", 0))
			best_key = key
	return best_key


# Gross payout for a paying row at the given bet. The royal row pays the enhanced
# max-bet rate (800-for-1) at the top bet and the base rate (250-for-1) below it.
func _row_pay(pay_row: Dictionary, bet: int, is_max_bet: bool) -> int:
	if is_max_bet and pay_row.has("max_mult"):
		return int(pay_row.get("max_mult", 0)) * bet
	return int(pay_row.get("mult", 0)) * bet


func _bonus_layer(hand: Array, _descriptor: Dictionary, pay_row: Dictionary, state: Dictionary, coin_count: int, coin_value: int, is_max_bet: bool) -> Dictionary:
	var key := str(pay_row.get("key", ""))
	var bonus := 0
	var progressive_bonus := 0
	var labels: Array = []
	var natural_royal := key == "royal_flush" or key == "natural_royal"
	if is_max_bet and natural_royal:
		progressive_bonus = int(state.get("progressive_meter", PROGRESSIVE_BASE))
		bonus += progressive_bonus
		labels.append("progressive")
	if is_max_bet and natural_royal and _is_sequential_royal(hand):
		var sequential_bonus := SEQUENTIAL_ROYAL_BONUS * coin_value * coin_count
		bonus += sequential_bonus
		labels.append("sequential royal")
	return {
		"bonus": bonus,
		"progressive_bonus": progressive_bonus,
		"label": ", ".join(labels),
	}


func _is_sequential_royal(hand: Array) -> bool:
	if hand.size() != HAND_SIZE:
		return false
	var suit := -1
	var expected := [10, 11, 12, 13, 14]
	for i in range(HAND_SIZE):
		var card: Dictionary = hand[i] if typeof(hand[i]) == TYPE_DICTIONARY else {}
		if bool(card.get("joker", false)):
			return false
		if int(card.get("rank", 0)) != int(expected[i]):
			return false
		if i == 0:
			suit = int(card.get("suit", -1))
		elif int(card.get("suit", -2)) != suit:
			return false
	return true


func _row_index(variant: Dictionary, key: String) -> int:
	var rows: Array = variant.get("rows", [])
	for i in range(rows.size()):
		if str((rows[i] as Dictionary).get("key", "")) == key:
			return i
	return rows.size()


func _variant_id_of(variant: Dictionary) -> String:
	var variant_id := str(variant.get("id", "jacks_or_better"))
	return variant_id if VARIANTS.has(variant_id) else "jacks_or_better"


# --- Rank / count helpers ----------------------------------------------------

func _rank_counts(ranks: Array) -> Dictionary:
	var counts: Dictionary = {}
	for rank in ranks:
		var value := int(rank)
		if value > 0:
			counts[value] = int(counts.get(value, 0)) + 1
	return counts


func _suits_uniform(suits: Array) -> bool:
	if suits.is_empty():
		return true
	var first := int(suits[0])
	if first < 0:
		return false
	for suit in suits:
		if int(suit) != first:
			return false
	return true


func _natural_top_keys(rank_counts: Dictionary) -> Array:
	var keys: Array = rank_counts.keys()
	keys.sort()
	return keys


func _natural_straight_high(rank_counts: Dictionary) -> int:
	if rank_counts.size() != HAND_SIZE:
		return 0
	var keys: Array = rank_counts.keys()
	keys.sort()
	if int(keys[HAND_SIZE - 1]) - int(keys[0]) == 4:
		return int(keys[HAND_SIZE - 1])
	if keys == [2, 3, 4, 5, 14]:
		return 5
	return 0


func _max_count(rank_counts: Dictionary) -> int:
	var best := 0
	for rank in rank_counts.keys():
		best = maxi(best, int(rank_counts[rank]))
	return best


func _has_count(rank_counts: Dictionary, count: int) -> bool:
	for rank in rank_counts.keys():
		if int(rank_counts[rank]) == count:
			return true
	return false


func _pair_count(rank_counts: Dictionary) -> int:
	var pairs := 0
	for rank in rank_counts.keys():
		if int(rank_counts[rank]) == 2:
			pairs += 1
	return pairs


func _high_pair_rank(rank_counts: Dictionary) -> int:
	for rank in rank_counts.keys():
		if int(rank_counts[rank]) == 2:
			return int(rank)
	return 0


func _rank_with_count(rank_counts: Dictionary, count: int) -> int:
	var best := 0
	for rank in rank_counts.keys():
		if int(rank_counts[rank]) == count and int(rank) > best:
			best = int(rank)
	return best


func _other_rank(rank_counts: Dictionary, exclude_rank: int) -> int:
	for rank in rank_counts.keys():
		if int(rank) != exclude_rank:
			return int(rank)
	return 0


func _natural_scoring_indices(ranks: Array, base: String, rank_counts: Dictionary) -> Array:
	var indices: Array = []
	match base:
		"royal_flush", "straight_flush", "flush", "straight", "full_house":
			for i in range(ranks.size()):
				indices.append(i)
		"four_kind", "three_kind", "one_pair":
			var target := _rank_with_count(rank_counts, _max_count(rank_counts))
			for i in range(ranks.size()):
				if int(ranks[i]) == target:
					indices.append(i)
		"two_pair":
			for i in range(ranks.size()):
				if int(rank_counts.get(int(ranks[i]), 0)) == 2:
					indices.append(i)
		_:
			indices = []
	return indices


# --- Strategy / holds --------------------------------------------------------

# Variant-aware suggested holds for the hint, the cheat mark, and the RTP check.
func _suggested_holds(hand: Array, variant: Dictionary) -> Array:
	var wild_ranks: Array = _wild_ranks(variant)
	if not wild_ranks.is_empty():
		return _suggested_holds_wild(hand, wild_ranks, variant)
	var descriptor: Dictionary = _evaluate_natural(hand)
	var pay_row: Dictionary = _pay_for(descriptor, variant)
	if int(pay_row.get("mult", 0)) > 0:
		return _index_array(descriptor.get("scoring_indices", []))
	var flush_draw: Array = _flush_draw_indices(hand, 4)
	if not flush_draw.is_empty():
		return flush_draw
	var pair: Array = _pair_indices(hand)
	if not pair.is_empty():
		return pair
	var straight_draw: Array = _open_straight_draw_indices(hand)
	if not straight_draw.is_empty():
		return straight_draw
	var highs: Array = _high_card_indices(hand)
	if not highs.is_empty():
		return highs
	return []


# Deuces strategy: always hold every wild, hold a made paying hand, otherwise hold
# the strongest non-wild draw (a pair toward quads, a suited flush draw, an open
# straight draw). Lone high cards are NOT held -- in deuces a high pair does not pay.
func _suggested_holds_wild(hand: Array, wild_ranks: Array, variant: Dictionary) -> Array:
	var wild_indices: Array = []
	var natural_indices: Array = []
	for i in range(hand.size()):
		var rank := int((hand[i] as Dictionary).get("rank", 0)) if typeof(hand[i]) == TYPE_DICTIONARY else 0
		if wild_ranks.has(rank):
			wild_indices.append(i)
		else:
			natural_indices.append(i)
	var descriptor: Dictionary = _evaluate_wild(hand, wild_ranks)
	var pay_row: Dictionary = _pay_for(descriptor, variant)
	if int(pay_row.get("mult", 0)) > 0:
		return _wild_made_holds(hand, wild_indices, natural_indices, str(pay_row.get("key", "")))
	var holds: Array = wild_indices.duplicate()
	var wilds := wild_indices.size()
	var natural_hand: Array = []
	for i in natural_indices:
		natural_hand.append(hand[i])
	var pair: Array = _pair_indices(natural_hand)
	# A deuce completes a flush, so a suited draw needs one fewer natural per wild.
	var flush_draw: Array = _flush_draw_indices(natural_hand, maxi(3, 4 - mini(wilds, 1)))
	var straight_draw: Array = _open_straight_draw_indices(natural_hand)
	var chosen: Array = []
	if not pair.is_empty():
		chosen = pair
	elif not flush_draw.is_empty():
		chosen = flush_draw
	elif wilds == 0 and not straight_draw.is_empty():
		chosen = straight_draw
	for local_index in chosen:
		holds.append(int(natural_indices[int(local_index)]))
	holds.sort()
	return _index_array(holds)


func hand_all_indices(hand: Array) -> Array:
	var indices: Array = []
	for i in range(hand.size()):
		indices.append(i)
	return indices


# For a made wild hand, three/four/five of a kind hold only the matching cards (and
# draw the rest toward a stronger hand); flushes, straights and full houses are pat.
func _wild_made_holds(hand: Array, wild_indices: Array, natural_indices: Array, key: String) -> Array:
	if key == "three_kind" or key == "four_kind" or key == "five_kind":
		var nat_counts: Dictionary = {}
		for i in natural_indices:
			var rank := int((hand[int(i)] as Dictionary).get("rank", 0))
			nat_counts[rank] = int(nat_counts.get(rank, 0)) + 1
		var target := _rank_with_count(nat_counts, _max_count(nat_counts))
		var holds: Array = wild_indices.duplicate()
		for i in natural_indices:
			if int((hand[int(i)] as Dictionary).get("rank", 0)) == target:
				holds.append(int(i))
		return _index_array(holds)
	return _index_array(hand_all_indices(hand))


func _pair_indices(hand: Array) -> Array:
	var rank_first: Dictionary = {}
	var pair_rank := -1
	for i in range(hand.size()):
		var rank := int((hand[i] as Dictionary).get("rank", 0)) if typeof(hand[i]) == TYPE_DICTIONARY else 0
		if rank_first.has(rank):
			pair_rank = rank
		else:
			rank_first[rank] = i
	if pair_rank < 0:
		return []
	var indices: Array = []
	for i in range(hand.size()):
		if int((hand[i] as Dictionary).get("rank", 0)) == pair_rank:
			indices.append(i)
	return indices


func _flush_draw_indices(hand: Array, threshold: int) -> Array:
	var by_suit: Dictionary = {}
	for i in range(hand.size()):
		var suit := int((hand[i] as Dictionary).get("suit", -1)) if typeof(hand[i]) == TYPE_DICTIONARY else -1
		var bucket: Array = by_suit.get(suit, [])
		bucket.append(i)
		by_suit[suit] = bucket
	for suit in by_suit.keys():
		var indices: Array = by_suit[suit]
		if indices.size() >= threshold:
			return _index_array(indices)
	return []


func _open_straight_draw_indices(hand: Array) -> Array:
	var rank_first: Dictionary = {}
	for i in range(hand.size()):
		var rank := int((hand[i] as Dictionary).get("rank", 0)) if typeof(hand[i]) == TYPE_DICTIONARY else 0
		if not rank_first.has(rank):
			rank_first[rank] = i
	var unique: Array = rank_first.keys()
	unique.sort()
	for start in range(unique.size() - 3):
		if int(unique[start + 3]) - int(unique[start]) == 3:
			var indices: Array = []
			for offset in range(4):
				indices.append(int(rank_first[unique[start + offset]]))
			return _index_array(indices)
	return []


func _high_card_indices(hand: Array) -> Array:
	var indices: Array = []
	for i in range(hand.size()):
		if int((hand[i] as Dictionary).get("rank", 0)) >= RANK_JACK:
			indices.append(i)
	return indices


func _hold_summary(holds: Array) -> String:
	if holds.is_empty():
		return "none"
	var labels: Array = []
	for hold_index in holds:
		labels.append(str(int(hold_index) + 1))
	return ", ".join(labels)


# --- Double-up ---------------------------------------------------------------

func _pending_double_credits(last_result: Dictionary) -> int:
	return maxi(0, int(last_result.get("double_credits", 0)))


# Builds the deterministic dealer card and four face-down picks for the gamble.
func _double_up_view(run_state: RunState, state: Dictionary, ui: Dictionary, last_result: Dictionary) -> Dictionary:
	var hands := int(state.get("hands_played", 0))
	var chain := int(last_result.get("double_chain", 0))
	var rng_state := int(run_state.rng_state) if run_state != null else 0
	var seed_text := str(run_state.seed_text) if run_state != null else "video_poker"
	var local_rng := RngStream.new()
	local_rng.configure(_stable_hash("%s:%s:%d:%d:double" % [get_id(), seed_text, rng_state, hands + chain]))
	var deck: Array = CardShoeScript.shuffle_cards(CardShoeScript.build_deck(), local_rng)
	var dealer: Dictionary = deck[0]
	var picks: Array = []
	var pick_ranks: Array = []
	for i in range(4):
		var card: Dictionary = deck[1 + i]
		picks.append(card)
		pick_ranks.append(int(card.get("rank", 0)))
	return {
		"dealer": dealer,
		"dealer_rank": int(dealer.get("rank", 7)),
		"picks": picks,
		"pick_ranks": pick_ranks,
		"selected_pick": clampi(int(ui.get("double_pick", -1)), -1, 3),
		"at_risk": _pending_double_credits(last_result),
	}


func _double_up_message(outcome: String, pick_rank: int, dealer_rank: int, bankroll_delta: int) -> String:
	var pick_word := _rank_word_single(pick_rank)
	var dealer_word := _rank_word_single(dealer_rank)
	match outcome:
		"win":
			return "Double up: your %s beats the %s. Bankroll %+d." % [pick_word, dealer_word, bankroll_delta]
		"push":
			return "Double up: your %s ties the %s. Win held." % [pick_word, dealer_word]
		_:
			return "Double up: your %s loses to the %s. Bankroll %+d." % [pick_word, dealer_word, bankroll_delta]


# --- Copy / message helpers --------------------------------------------------

func _hand_blurb(descriptor: Dictionary, pay_row: Dictionary, variant: Dictionary) -> String:
	var key := str(pay_row.get("key", ""))
	if key.is_empty():
		return "No Pay"
	var label := str(pay_row.get("label", ""))
	if str(descriptor.get("base", "")) == "wild":
		return label
	match str(descriptor.get("base", "")):
		"royal_flush", "straight_flush", "flush":
			return "%s — %s" % [label, _suit_word(int(descriptor.get("suit", 0)))]
		"full_house":
			var counts: Dictionary = _copy_dict(descriptor.get("rank_counts", {}))
			return "%s — %s over %s" % [label, _rank_word(_rank_with_count(counts, 3)), _rank_word(_rank_with_count(counts, 2))]
		"four_kind", "three_kind", "one_pair":
			return "%s — %s" % [label, _rank_word(_rank_with_count(_copy_dict(descriptor.get("rank_counts", {})), _max_count(_copy_dict(descriptor.get("rank_counts", {})))))]
		"two_pair":
			var pair_counts: Dictionary = _copy_dict(descriptor.get("rank_counts", {}))
			return "%s — %s and %s" % [label, _rank_word(_high_two_pair(pair_counts, true)), _rank_word(_high_two_pair(pair_counts, false))]
		"straight":
			return "%s — %s high" % [label, _rank_word(int(descriptor.get("straight_high", 0)))]
		_:
			return label


func _high_two_pair(rank_counts: Dictionary, high: bool) -> int:
	var pairs: Array = []
	for rank in rank_counts.keys():
		if int(rank_counts[rank]) == 2:
			pairs.append(int(rank))
	pairs.sort()
	if pairs.is_empty():
		return 0
	return int(pairs[pairs.size() - 1]) if high else int(pairs[0])


func _outcome_message(blurb: String, pay_row: Dictionary, coin_pay: int, bankroll_delta: int, suspicion_delta: int, is_cheat: bool, pit_boss_summary: String, security_message: String) -> String:
	var lead := "You draw %s." % blurb
	if is_cheat:
		lead = "Holdout palms in %s." % blurb
	var pay_text := "No pay"
	if coin_pay > 0:
		pay_text = "Pays %d credits" % coin_pay if int(pay_row.get("mult", 0)) >= 1 else "No pay"
	if bankroll_delta == 0 and coin_pay > 0:
		pay_text = "Pushes (bet returned)"
	var message := "%s %s. Bankroll %+d." % [lead, pay_text, bankroll_delta]
	if suspicion_delta > 0:
		message += " Suspicion pressure rises."
	if not pit_boss_summary.is_empty():
		message += " %s" % pit_boss_summary
	if not security_message.is_empty():
		message += " %s" % security_message
	return message


func _info_text(phase: String, hand: Array, holds: Array, last_result: Dictionary, marked: bool, variant: Dictionary) -> String:
	if phase == "idle":
		return "Deal ready."
	if phase == "double_up":
		return "Double or nothing: pick a card to beat the dealer."
	if phase == "settled" and not last_result.is_empty():
		var bet := int(last_result.get("bet_credits", 0))
		var mult := int(last_result.get("pay_mult", 0))
		var blurb := str(last_result.get("blurb", ""))
		if mult > 0:
			return "%s — pays %dx (bet %d)" % [blurb, mult, bet]
		return "%s — no pay" % blurb
	if marked:
		return "Holdout armed. Draw to palm in the missing card."
	var descriptor: Dictionary = _evaluate(hand, _wild_ranks(variant))
	var pay_row: Dictionary = _pay_for(descriptor, variant)
	var holding := str(pay_row.get("label", "No Pay")) if int(pay_row.get("mult", 0)) > 0 else "no pay yet"
	return "Holding %d. Best so far: %s." % [holds.size(), holding]


func _paytable_rows(variant: Dictionary) -> Array:
	var rows: Array = []
	for row_value in variant.get("rows", []):
		var row: Dictionary = row_value
		var grid_row := {
			"key": str(row.get("key", "")),
			"label": str(row.get("label", "")),
			"mult": int(row.get("mult", 0)),
		}
		if row.has("max_mult"):
			grid_row["max_mult"] = int(row.get("max_mult", 0))
		rows.append(grid_row)
	return rows


func _rank_word(rank: int) -> String:
	if rank == 0:
		return "Jokers"
	return str(RANK_WORD.get(rank, str(rank)))


func _rank_word_single(rank: int) -> String:
	match rank:
		0:
			return "Joker"
		11:
			return "Jack"
		12:
			return "Queen"
		13:
			return "King"
		14:
			return "Ace"
		_:
			return str(rank)


func _suit_word(suit: int) -> String:
	return str(SUIT_WORD.get(suit, str(suit)))


func _cheat_action_def() -> Dictionary:
	for action_value in definition.get("cheat_actions", []):
		if typeof(action_value) == TYPE_DICTIONARY and str((action_value as Dictionary).get("id", "")) == "mark_holds":
			return (action_value as Dictionary).duplicate(true)
	return {}


# --- Surface command helpers -------------------------------------------------

func _bet_command(ui_state: Dictionary, set_stake: int, message: String) -> Dictionary:
	return GameModule.surface_command({
		"handled": true,
		"ui_state": ui_state,
		"preserve_surface_ui_state": true,
		"set_stake": set_stake,
		"message": message,
	})


func _action_command(action_id: String, action_kind: String, confirm_requested: bool, ui_state: Dictionary, index: int, set_stake: int, message: String) -> Dictionary:
	# Preserve UI-local state only while selecting; release it on the resolving click
	# so the host clears the active hand and the next surface_state shows the result.
	var already_selected := str(ui_state.get("selected_action_id", "")) == action_id and str(ui_state.get("selected_action_kind", "")) == action_kind
	var resolving := confirm_requested or already_selected
	return GameModule.surface_command({
		"handled": true,
		"ui_state": ui_state,
		"action_id": action_id,
		"action_kind": action_kind,
		"resolve": resolving,
		"preserve_surface_ui_state": not resolving,
		"set_stake": set_stake,
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
	if action_id == "draw" and action_kind == "legal":
		return ["video_poker_draw"]
	if action_id == "mark_holds" and action_kind == "cheat":
		return ["video_poker_mark"]
	if action_id == "double_up" and action_kind == "legal":
		return ["video_poker_double_pick"]
	return []


func _active_flip(ui_state: Dictionary, last_result: Dictionary, hand_active: bool) -> Dictionary:
	if hand_active and ui_state.has("deal_id"):
		return {"id": str(ui_state.get("deal_id", "")), "started": int(ui_state.get("deal_started_msec", 0))}
	if not hand_active and not last_result.is_empty():
		return {"id": str(last_result.get("flip_id", "")), "started": int(last_result.get("resolved_at_msec", 0))}
	return {"id": "", "started": 0}


func _build_result(action_id: String, action_kind: String, stake: int, bankroll_delta: int, suspicion_delta: int, ended: bool, message: String, story_entry: Dictionary, environment: Dictionary) -> Dictionary:
	var deltas: Dictionary = GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["suspicion_delta"] = suspicion_delta
	deltas["story_log"] = [story_entry]
	deltas["messages"] = [message]
	deltas["ended"] = ended
	return GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": action_kind,
		"stake": stake,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"deltas": deltas,
		"won": bankroll_delta > 0,
		"environment_id": environment.get("id", ""),
		"environment_archetype_id": environment.get("archetype_id", ""),
		"message": message,
	})


# --- Drawing -----------------------------------------------------------------

func _draw_machine(surface, surface_state: Dictionary) -> void:
	var board_size: Vector2 = surface.surface_board_size()
	surface.draw_rect(Rect2(Vector2.ZERO, board_size), Color("#070a12"))
	surface.draw_rect(MACHINE_HEADER_RECT, Color("#16111f"))
	surface.draw_rect(Rect2(0, MACHINE_HEADER_RECT.end.y - 2, board_size.x, 2), C_PINK)
	surface.surface_label(str(surface_state.get("machine_name", "VIDEO POKER")).to_upper().left(24), Vector2(24, 25), 21, C_CYAN)
	surface.surface_label("%s  %s  %s" % [
		str(surface_state.get("variant_label", "Jacks or Better")).left(22),
		str(surface_state.get("paytable_tier_label", "Standard")).left(14),
		str(surface_state.get("multi_hand_mode", "1 Play")),
	], Vector2(402, 24), 12, C_PINK_2)
	surface.draw_rect(PRIMARY_HAND_RECT, Color("#09111d"))
	surface.draw_rect(PRIMARY_HAND_RECT, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.28), false, 2)
	surface.draw_rect(STATUS_PANEL_RECT, Color("#0a0d18"))
	surface.draw_rect(STATUS_PANEL_RECT, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.24), false, 2)
	surface.draw_rect(CONTROL_DECK_RECT, Color("#100d16"))
	surface.draw_rect(CONTROL_DECK_RECT, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.20), false, 1)


func _draw_paytable_grid(surface, surface_state: Dictionary) -> void:
	var rows: Array = surface_state.get("paytable_rows", [])
	var level := int(surface_state.get("bet_level", MAX_BET_LEVEL))
	var coin_count := maxi(1, int(surface_state.get("coin_count", 1)))
	var coin_value := maxi(1, int(surface_state.get("coin_value", 1)))
	var win_key := str(surface_state.get("result_pay_key", ""))
	var grid := PAYTABLE_RECT
	surface.draw_rect(grid, Color("#0b1020"))
	surface.draw_rect(grid, Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.32), false, 2)
	surface.surface_label_centered("PAY TABLE - %s - %d COIN %s" % [
		str(surface_state.get("variant_label", "Video Poker")).to_upper().left(24),
		coin_count,
		str(surface_state.get("coin_label", "1c")).to_upper(),
	], Rect2(grid.position + Vector2(12, 6), Vector2(grid.size.x - 24, 18)), 13, C_YELLOW)
	var column_count := 2 if rows.size() > 6 else 1
	var rows_per_column := int(ceil(float(maxi(1, rows.size())) / float(column_count)))
	var column_gap := 16.0
	var column_width := (grid.size.x - 28.0 - column_gap * float(column_count - 1)) / float(column_count)
	var row_h := (grid.size.y - 36.0) / float(maxi(1, rows_per_column))
	for i in range(rows.size()):
		var row: Dictionary = rows[i] if typeof(rows[i]) == TYPE_DICTIONARY else {}
		var column := i / rows_per_column
		var row_index := i % rows_per_column
		var x := grid.position.x + 14.0 + float(column) * (column_width + column_gap)
		var y := grid.position.y + 32.0 + float(row_index) * row_h
		var row_rect := Rect2(x, y, column_width, row_h - 1.0)
		var is_win := win_key != "" and str(row.get("key", "")) == win_key
		if is_win:
			surface.draw_rect(row_rect, Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.18))
			surface.draw_rect(row_rect, Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.54), false, 1)
		var pay := _row_pay(row, coin_count, level >= MAX_BET_LEVEL) * coin_value
		surface.surface_label(str(row.get("label", "")).left(24), Vector2(row_rect.position.x + 6, row_rect.position.y + row_h * 0.66), 9, C_TEAL if is_win else C_SOFT)
		surface.surface_label(str(pay), Vector2(row_rect.end.x - 44, row_rect.position.y + row_h * 0.66), 9, C_YELLOW if is_win else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.80))


func _grid_cell_pay(row: Dictionary, col_index: int, bet_options: Array) -> int:
	var bet := int(bet_options[clampi(col_index, 0, bet_options.size() - 1)])
	return _row_pay(row, bet, col_index >= bet_options.size() - 1)


func _draw_meters(surface, surface_state: Dictionary) -> void:
	var panel := STATUS_PANEL_RECT
	surface.surface_label_centered("MACHINE METERS", Rect2(panel.position + Vector2(10, 8), Vector2(panel.size.x - 20, 16)), 11, C_YELLOW)
	_draw_meter(surface, panel.position + Vector2(14, 30), Vector2(98, 30), "CREDITS", int(surface_state.get("credits", 0)), C_YELLOW)
	_draw_meter(surface, panel.position + Vector2(126, 30), Vector2(98, 30), "BET", int(surface_state.get("bet_credits", 0)), C_CYAN)
	_draw_meter(surface, panel.position + Vector2(14, 66), Vector2(98, 30), "WIN", int(surface_state.get("win_credits", 0)), C_TEAL)
	_draw_meter(surface, panel.position + Vector2(126, 66), Vector2(98, 30), "PROG", int(surface_state.get("progressive_meter", 0)), C_AMBER)
	surface.surface_label_centered("%d COIN  %s  %d PLAY" % [
		int(surface_state.get("coin_count", 1)),
		str(surface_state.get("coin_label", "1c")).to_upper(),
		int(surface_state.get("hand_count", 1)),
	], Rect2(panel.position + Vector2(14, 104), Vector2(panel.size.x - 28, 18)), 10, C_SOFT)


func _draw_meter(surface, pos: Vector2, size: Vector2, label: String, value: int, color: Color) -> void:
	var rect := Rect2(pos, size)
	surface.draw_rect(rect, Color("#05070d"))
	surface.draw_rect(rect, Color(color.r, color.g, color.b, 0.35), false, 1)
	surface.surface_label(label, pos + Vector2(6, 11), 8, Color(color.r, color.g, color.b, 0.70))
	surface.surface_label(str(value).left(8), pos + Vector2(6, 25), 13, color)


func _draw_card_row(surface, surface_state: Dictionary, phase: String) -> void:
	var hand: Array = CardShoeScript.card_array(surface_state.get("hand", []))
	if hand.size() != HAND_SIZE:
		hand = _presentation_cards(HAND_SIZE)
	var holds: Array = _index_array(surface_state.get("holds", []))
	var suggested: Array = _index_array(surface_state.get("suggested_holds", []))
	var scoring: Array = _index_array(surface_state.get("scoring_indices", []))
	var drawn: Array = _index_array(surface_state.get("drawn_indices", []))
	var flip_active := bool(surface.surface_animation_active(FLIP_CHANNEL))
	var flip_progress := float(surface.surface_animation_progress(FLIP_CHANNEL))
	var phase_label := "INSERT BET - PRESS DEAL"
	if phase == "hold":
		phase_label = "SELECT HOLDS - PRESS DRAW"
	elif phase == "settled":
		phase_label = str(surface_state.get("result_pay_label", "NO PAY")).to_upper()
	surface.surface_label_centered(phase_label, Rect2(PRIMARY_HAND_RECT.position + Vector2(10, 8), Vector2(PRIMARY_HAND_RECT.size.x - 20, 18)), 13, C_YELLOW if phase == "idle" else C_CYAN)
	for i in range(hand.size()):
		var pos := CARD_ROW_ORIGIN + Vector2(i * CARD_SPACING, 0.0)
		var held := holds.has(i)
		var is_suggested := suggested.has(i) and not held
		var is_scoring := scoring.has(i)
		var flipping := flip_active and drawn.has(i) and flip_progress < 0.5
		if held and phase == "hold":
			surface.draw_rect(Rect2(pos + Vector2(0, -18), Vector2(CARD_SIZE.x, 16)), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.22))
			surface.surface_label_centered("HELD", Rect2(pos + Vector2(0, -17), Vector2(CARD_SIZE.x, 14)), 11, C_TEAL)
		if flipping:
			_draw_card_back(surface, Rect2(pos, CARD_SIZE))
		else:
			_draw_card(surface, hand[i], pos, held, is_suggested, is_scoring and phase != "hold")
		var hold_rect := Rect2(pos + Vector2(0, CARD_SIZE.y + 7), HOLD_BUTTON_SIZE)
		_draw_cabinet_button(surface, hold_rect, "HELD" if held else "HOLD %d" % (i + 1), "video_poker_hold", i, C_TEAL if held else C_CYAN, phase == "hold")
	_draw_multi_hand_stack(surface, surface_state, phase)
	if phase == "hold":
		for i in range(hand.size()):
			surface.surface_add_exact_hit(Rect2(CARD_ROW_ORIGIN + Vector2(i * CARD_SPACING, 0.0), CARD_SIZE), "video_poker_hold", i)
	elif phase == "idle":
		surface.surface_label_centered("DEAL A HAND", Rect2(PRIMARY_HAND_RECT.position + Vector2(10, 140), Vector2(PRIMARY_HAND_RECT.size.x - 20, 18)), 11, C_SOFT)


func _draw_multi_hand_stack(surface, surface_state: Dictionary, phase: String) -> void:
	var hands: Array = _hands_array(surface_state.get("hands", []))
	var results: Array = _copy_array(surface_state.get("hand_results", []))
	var hand_count := maxi(1, int(surface_state.get("hand_count", 1)))
	var panel := STATUS_PANEL_RECT
	var list_top := panel.position.y + 126.0
	surface.draw_rect(Rect2(panel.position.x + 12, list_top - 2.0, panel.size.x - 24, 1), Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.22))
	surface.surface_label(str(surface_state.get("multi_hand_mode", "1 Play")).to_upper(), Vector2(panel.position.x + 16, list_top + 12), 10, C_CYAN)
	if hand_count <= 1 and hands.size() <= 1:
		var result_label := str(surface_state.get("result_pay_label", "READY")) if phase == "settled" else ("READY" if phase == "idle" else "IN PLAY")
		surface.surface_label(result_label.left(20).to_upper(), Vector2(panel.position.x + 16, list_top + 30), 10, C_SOFT if phase == "idle" else C_TEAL)
		return
	if hands.is_empty():
		var pending_count := mini(maxi(0, hand_count - 1), 2)
		for pending_index in range(pending_count):
			var y := list_top + 30.0 + float(pending_index) * 14.0
			surface.surface_label("HAND %d PENDING" % (pending_index + 2), Vector2(panel.position.x + 16, y), 9, C_SOFT)
		return
	var progress := float(surface.surface_animation_progress(DRAW_CASCADE_CHANNEL))
	var visible_count := clampi(int(floor(progress * float(hands.size() + 1))) + 1, 1, mini(hands.size(), 2))
	for hand_index in range(visible_count):
		var y := list_top + 28.0 + float(hand_index) * 18.0
		var result: Dictionary = results[hand_index] if hand_index < results.size() and typeof(results[hand_index]) == TYPE_DICTIONARY else {}
		var label := str(result.get("pay_label", "No Pay"))
		var total := int(result.get("total", 0))
		surface.surface_label("#%d %s  %d" % [hand_index + 1, label.left(14), total], Vector2(panel.position.x + 16, y), 9, C_TEAL if total > 0 else C_SOFT)
	if hands.size() > visible_count:
		surface.surface_label("+%d MORE" % (hands.size() - visible_count), Vector2(panel.position.x + 162, list_top + 48), 9, C_AMBER)


func _draw_mini_card(surface, card_value: Variant, pos: Vector2, paid: bool) -> void:
	var card: Dictionary = card_value if typeof(card_value) == TYPE_DICTIONARY else {}
	var rect := Rect2(pos, Vector2(28, 24))
	surface.draw_rect(rect, Color("#fbf8e6"))
	surface.draw_rect(rect, Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.55) if paid else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.4), false, 1)
	var rank := int(card.get("rank", 2))
	var label := "J*" if bool(card.get("joker", false)) or rank == 0 else CardShoeScript.rank_label(rank)
	var suit := int(card.get("suit", 0))
	var color := C_PINK if suit == 1 or suit == 3 else C_DARK
	surface.surface_label(label, pos + Vector2(4, 17), 9, color)


func _draw_double_up(surface, surface_state: Dictionary) -> void:
	var view: Dictionary = surface_state.get("double_up_view", {})
	var dealer: Dictionary = view.get("dealer", {})
	surface.draw_rect(PRIMARY_HAND_RECT, Color("#0c1422"))
	surface.draw_rect(PRIMARY_HAND_RECT, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.30), false, 2)
	surface.surface_label_centered("DOUBLE OR NOTHING - %d CREDITS AT RISK" % int(view.get("at_risk", 0)), Rect2(PRIMARY_HAND_RECT.position + Vector2(12, 8), Vector2(PRIMARY_HAND_RECT.size.x - 24, 18)), 13, C_AMBER)
	surface.surface_label_centered("DEALER", Rect2(CARD_ROW_ORIGIN + Vector2(0, -18), Vector2(CARD_SIZE.x, 14)), 10, C_SOFT)
	_draw_card(surface, dealer, CARD_ROW_ORIGIN, false, false, false)
	surface.surface_label_centered("PICK ONE CARD TO BEAT THE DEALER", Rect2(CARD_ROW_ORIGIN + Vector2(134, -18), Vector2(424, 14)), 10, C_SOFT)
	var new_selected := int(view.get("selected_pick", -1))
	for pick_index in range(4):
		var pick_pos := Vector2(CARD_ROW_ORIGIN.x + 134.0 + float(pick_index) * 106.0, CARD_ROW_ORIGIN.y)
		surface.draw_rect(Rect2(pick_pos, CARD_SIZE), C_SOFT)
		surface.draw_rect(Rect2(pick_pos + Vector2(4, 4), CARD_SIZE - Vector2(8, 8)), C_PINK if pick_index != new_selected else C_TEAL)
		surface.draw_rect(Rect2(pick_pos + Vector2(12, 12), CARD_SIZE - Vector2(24, 24)), Color("#563be0"))
		surface.surface_label("?", pick_pos + CARD_SIZE * 0.5 + Vector2(-7, 8), 26, C_WHITE)
		surface.surface_add_exact_hit(Rect2(pick_pos, CARD_SIZE), "video_poker_double_pick", pick_index)
	return
	surface.surface_label("DOUBLE OR NOTHING — %d at risk" % int(view.get("at_risk", 0)), Vector2(56, 224), 15, C_AMBER)
	surface.surface_label("Dealer", Vector2(60, 244), 12, C_SOFT)
	_draw_card(surface, dealer, CARD_ROW_ORIGIN + Vector2(0, 14), false, false, false)
	surface.surface_label("Beat it:", Vector2(192, 244), 12, C_SOFT)
	surface.draw_rect(PRIMARY_HAND_RECT, Color("#0c1422"))
	surface.draw_rect(PRIMARY_HAND_RECT, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.30), false, 2)
	surface.surface_label("DOUBLE OR NOTHING - %d at risk" % int(view.get("at_risk", 0)), PRIMARY_HAND_RECT.position + Vector2(18, 24), 15, C_AMBER)
	surface.surface_label("DEALER", CARD_ROW_ORIGIN + Vector2(8, -8), 12, C_SOFT)
	_draw_card(surface, dealer, CARD_ROW_ORIGIN + Vector2(0, 12), false, false, false)
	surface.surface_label("PICKS", Vector2(192, CARD_ROW_ORIGIN.y + 4), 12, C_SOFT)
	var selected := int(view.get("selected_pick", -1))
	for i in range(4):
		var pos := Vector2(192 + i * CARD_SPACING, CARD_ROW_ORIGIN.y + 12)
		surface.draw_rect(Rect2(pos, CARD_SIZE), C_SOFT)
		surface.draw_rect(Rect2(pos + Vector2(4, 4), CARD_SIZE - Vector2(8, 8)), C_PINK if i != selected else C_TEAL)
		surface.draw_rect(Rect2(pos + Vector2(12, 12), CARD_SIZE - Vector2(24, 24)), Color("#563be0"))
		surface.surface_label("?", pos + CARD_SIZE * 0.5 + Vector2(-7, 8), 26, C_WHITE)
		surface.surface_add_exact_hit(Rect2(pos, CARD_SIZE), "video_poker_double_pick", i)


func _draw_card(surface, card_value: Variant, pos: Vector2, held: bool, suggested: bool, scoring: bool) -> void:
	var card: Dictionary = card_value if typeof(card_value) == TYPE_DICTIONARY else {}
	var rect := Rect2(pos, CARD_SIZE)
	if bool(card.get("hidden", false)):
		_draw_card_back(surface, rect)
		return
	if scoring:
		surface.draw_rect(Rect2(rect.position - Vector2(5, 5), rect.size + Vector2(10, 10)), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.30))
	surface.draw_rect(rect, C_SOFT)
	surface.draw_rect(Rect2(pos + Vector2(4, 4), CARD_SIZE - Vector2(8, 8)), Color("#fbf8e6"))
	if suggested:
		surface.draw_rect(Rect2(pos - Vector2(3, 3), CARD_SIZE + Vector2(6, 6)), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.45), false, 2)
	if held:
		surface.draw_rect(Rect2(pos - Vector2(4, 4), CARD_SIZE + Vector2(8, 8)), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.55), false, 3)
	elif scoring:
		surface.draw_rect(Rect2(pos - Vector2(4, 4), CARD_SIZE + Vector2(8, 8)), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.70), false, 3)
	var rank := int(card.get("rank", 2))
	var suit := int(card.get("suit", 0))
	var color := C_PINK if suit == 1 or suit == 3 else C_DARK
	if bool(card.get("joker", false)) or rank == 0:
		surface.surface_label("JOKER", pos + Vector2(8, 28), 15, C_PINK)
		surface.draw_circle(pos + Vector2(42, 58), 10, Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.55))
		return
	surface.surface_label(CardShoeScript.rank_label(rank), pos + Vector2(8, 26), 20, color)
	_draw_suit(surface, pos + Vector2(38, 62), suit, color)


func _draw_card_back(surface, rect: Rect2) -> void:
	surface.draw_rect(rect, C_SOFT)
	surface.draw_rect(Rect2(rect.position + Vector2(4, 4), rect.size - Vector2(8, 8)), C_PINK)
	surface.draw_rect(Rect2(rect.position + Vector2(12, 12), rect.size - Vector2(24, 24)), Color("#563be0"))


func _draw_suit(surface, pos: Vector2, suit: int, color: Color) -> void:
	match suit:
		0:
			surface.draw_polygon([pos + Vector2(0, -12), pos + Vector2(12, 4), pos + Vector2(-12, 4)], [color])
			surface.draw_rect(Rect2(pos.x - 3, pos.y + 2, 6, 10), color)
		1:
			surface.draw_circle(pos + Vector2(-6, -4), 7, color)
			surface.draw_circle(pos + Vector2(6, -4), 7, color)
			surface.draw_polygon([pos + Vector2(-14, 0), pos + Vector2(14, 0), pos + Vector2(0, 14)], [color])
		2:
			surface.draw_circle(pos + Vector2(-7, 0), 7, color)
			surface.draw_circle(pos + Vector2(7, 0), 7, color)
			surface.draw_circle(pos + Vector2(0, -8), 7, color)
			surface.draw_rect(Rect2(pos.x - 3, pos.y + 2, 6, 12), color)
		_:
			surface.draw_polygon([pos + Vector2(0, -13), pos + Vector2(11, 0), pos + Vector2(0, 13), pos + Vector2(-11, 0)], [color])


func _draw_info_line(surface, surface_state: Dictionary) -> void:
	var info_rect := Rect2(26, 173, 588, 16)
	surface.surface_label_centered(str(surface_state.get("info_text", "")).left(82), info_rect, 10, C_CYAN)
	if bool(surface_state.get("pit_boss_watched", false)):
		surface.surface_label(str(surface_state.get("pit_boss_summary", "")).left(26), STATUS_PANEL_RECT.position + Vector2(16, 158), 9, C_PINK)


func _draw_controls(surface, surface_state: Dictionary, phase: String) -> void:
	if phase == "double_up":
		_draw_cabinet_button(surface, Rect2(24, 374, 128, 36), "DOUBLE", "video_poker_double", 0, C_AMBER, false)
		_draw_cabinet_button(surface, Rect2(160, 374, 128, 36), "COLLECT", "video_poker_collect", 0, C_TEAL, false)
		surface.surface_label_centered("PICK A CARD ABOVE", Rect2(320, 378, 240, 24), 12, C_AMBER)
		return
	var win_pending := phase == "settled" and bool(surface_state.get("double_up_available", false))
	var betting_enabled := phase == "idle" or phase == "settled"
	_draw_cabinet_button(surface, Rect2(30, 374, 92, 36), "BET ONE", "video_poker_bet_one", 0, C_YELLOW, betting_enabled)
	_draw_cabinet_button(surface, Rect2(130, 374, 92, 36), "BET MAX", "video_poker_bet_max", 0, C_YELLOW, betting_enabled)
	_draw_cabinet_button(surface, Rect2(230, 374, 92, 36), str(surface_state.get("coin_label", "DENOM")).to_upper(), "video_poker_denom", 0, C_AMBER, betting_enabled)
	_draw_cabinet_button(surface, Rect2(338, 370, 116, 44), "DRAW" if phase == "hold" else "DEAL", "video_poker_draw" if phase == "hold" else "video_poker_deal", 0, C_TEAL, true)
	_draw_cabinet_button(surface, Rect2(470, 374, 104, 36), "DOUBLE", "video_poker_double", 0, C_AMBER, win_pending)
	_draw_cabinet_button(surface, Rect2(582, 374, 104, 36), "COLLECT", "video_poker_collect", 0, C_TEAL, phase == "settled")
	if phase == "settled":
		var delta := int(surface_state.get("result_bankroll_delta", 0))
		var color := C_TEAL if delta > 0 else (C_YELLOW if delta == 0 else C_ORANGE)
		surface.surface_label_centered("BANKROLL %+d  HEAT %+d" % [delta, int(surface_state.get("result_suspicion_delta", 0))], Rect2(686, 338, 188, 16), 9, color)


func _draw_cabinet_button(surface, rect: Rect2, label: String, action: String, index: int, accent: Color, enabled: bool) -> void:
	var hovered: bool = enabled and bool(surface.surface_region_hovered(action, index))
	var fill_alpha := 0.24 if hovered else (0.16 if enabled else 0.06)
	var border := C_WHITE if hovered else (accent if enabled else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.28))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, fill_alpha))
	surface.draw_rect(rect, border, false, 2 if hovered else 1)
	surface.surface_label_centered(label.left(12), rect.grow(-4), 12, accent if enabled else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.42))
	if enabled:
		surface.surface_add_hit(rect, action, index)


# --- Result builders ---------------------------------------------------------

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


# --- Value helpers -----------------------------------------------------------

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


func _hands_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for hand_value in value:
		result.append(CardShoeScript.card_array(hand_value))
	return result


func _presentation_cards(count: int) -> Array:
	var cards: Array = []
	for i in range(count):
		cards.append({"hidden": true})
	return cards


func _stable_hash(text: String) -> int:
	var hash_value := 2166136261
	for i in range(text.length()):
		hash_value = int(hash_value ^ text.unicode_at(i))
		hash_value = int((hash_value * 16777619) & 0x7fffffff)
	return maxi(hash_value, 1)
