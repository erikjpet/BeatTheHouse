class_name VideoPokerGame
extends GameModule

# Full-simulation three-cabinet video poker, modeled on real casino machines.
# The shared UI canvas only hosts the surface; this module owns the deck, the
# bet/deal/hold/draw loop, cabinet paytables, hand evaluation (including wild cards
# and quad-with-kicker bonuses), the timed holdout cheat, the double-up gamble, the
# screen rendering, animation, and result deltas.
#
# REAL-MACHINE QUALITIES MODELED:
#   - Coin betting 1-5 with the max-coin Royal Flush bonus (250-for-1 at 1-4 coins,
#     800-for-1 / 4000 credits at 5 coins) -- the defining video poker mechanic.
#   - Three owner-locked cabinets, each with its authentic paytable and hand count:
#       * Jacks or Better (9/6), 1 hand
#       * Double Deuces (Deuces Wild), 2 hands
#       * Triple Double Bonus (Double Double Bonus), 3 hands
#   - A focused current-bet paytable, CREDITS / BET / WIN meters, large active
#     hand presentation, multi-hand result lanes, and BET / DEAL / DRAW /
#     DOUBLE-UP button states.
#   - Fixed bet ladder of 2 / 5 / 10 / 15 / 20 credits, with the top-bet Royal jackpot
#     (250-for-1 below the max bet, 800-for-1 at the max bet).
#   - Double-Up (double-or-nothing) gamble after any win.
#
# CHEAT (timed holdout): one shared timing skill core, dressed differently by
# cabinet. It palms one seeded ideal card on the draw, preserves the existing
# quality->heat/evidence economy, and reports blunt feedback naming the exact
# swapped card and resulting hand.
#
# Randomness flows through the injected RngStream. The deal is built from a stable
# hash of the run seed/state (no stream consumption) so the preview matches resolve;
# the draw and the double-up shuffle/draw consume the injected stream. Result deltas
# are applied through the shared host apply_result helper; this module never mutates
# RunState directly.

const CardShoeScript := preload("res://scripts/core/card_shoe.gd")
const VideoPokerRendererScript := preload("res://scripts/games/video_poker_renderer.gd")
const RuntimeScript := preload("res://scripts/core/game_ritual_runtime.gd")
const ActionAuthorityScript := preload("res://scripts/core/blackjack_action_authority.gd")

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
const DOUBLE_UP_CAP := 5
const DOUBLE_UP_RESULT_HOLD_MSEC := 1500
const PROGRESSIVE_BASE := 240
const SEQUENTIAL_ROYAL_BONUS := 400
const DRAW_CASCADE_CHANNEL := "video_poker_cascade"
const HOLDOUT_PROMPT_BASE_MSEC := 520
const HOLDOUT_PERFECT_WINDOW_MSEC := 80
const HOLDOUT_GOOD_WINDOW_MSEC := 210
const HOLDOUT_CLOSE_WINDOW_MSEC := 340
const HOLDOUT_CHAIN_VERSION := 3
const HOLDOUT_BEAT_TARGETS := [0.58, 0.58]
const HOLDOUT_BEAT_DURATIONS_MSEC := [880, 760]
const HOLDOUT_BEAT_IDS := ["line_up", "commit"]
const HOLDOUT_BEAT_LABELS := ["LINE UP", "COMMIT"]
const HOLDOUT_BEAT_KINDS := ["timing", "target"]
const HOLDOUT_REDUCED_DURATION_MSEC := 1120
const HOLDOUT_BASE_HEAT := 14
const HOLDOUT_PERFECT_HEAT_REDUCTION := 4
const HOLDOUT_PARTIAL_HEAT_BONUS := 3
const HOLDOUT_MISS_HEAT_BONUS := 6
const HOLDOUT_BLOWN_HEAT_BONUS := 10
const HOLDOUT_ITEM_EFFECT_KEYS := [
	"video_poker_holdout_perfect_msec",
	"video_poker_holdout_good_msec",
	"video_poker_holdout_close_msec",
	"video_poker_holdout_heat_delta",
	"skill_cheat_drunk_window_offset_msec",
]
const STRATEGY_SAMPLE_CAP := 1024
const STRATEGY_CACHE_LIMIT := 128
const VIDEO_POKER_RITUAL_CONTRACT := "game_ritual/1"
const VIDEO_POKER_RITUAL_ID := "video_poker.machine_session"

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

const CABINET_ORDER := ["jacks_or_better", "double_deuces", "triple_double_bonus"]
const CABINETS := {
	"jacks_or_better": {
		"label": "Jacks or Better",
		"machine_name": "Neon Jacks",
		"variant_id": "jacks_or_better",
		"paytable_tier_id": "full_pay",
		"hand_count": 1,
		"identity": "Retro-neon diner cabinet",
		"theme": "retro",
		"primary": "#19d6ff",
		"secondary": "#ff4fd8",
		"body": "#111a2b",
		"glass": "#071323",
		"button": "#1ac8ff",
		"trim": "#f7ef75",
		"cheat_name": "Neon Slip",
		"cheat_verb": "slipped in",
		"cheat_prompt": "Stop the neon sweep, then tap the highlighted card slot.",
		"cheat_commit_label": "SLIP CARD",
		"sfx_family": "jacks",
	},
	"double_deuces": {
		"label": "Double Deuces",
		"machine_name": "Double Deuces",
		"variant_id": "deuces_wild",
		"paytable_tier_id": "full_pay",
		"hand_count": 2,
		"identity": "Electric wild-card cabinet",
		"theme": "deuces",
		"primary": "#62ff8a",
		"secondary": "#27a9ff",
		"body": "#071d18",
		"glass": "#06231f",
		"button": "#65ff9c",
		"trim": "#9dfcff",
		"cheat_name": "Wild Deuce Flash",
		"cheat_verb": "flashed in",
		"cheat_prompt": "Catch the wild pulse, then tap the card slot to receive the deuce-powered swap.",
		"cheat_commit_label": "FLASH WILD",
		"sfx_family": "deuces",
	},
	"triple_double_bonus": {
		"label": "Triple Double Bonus",
		"machine_name": "Triple Double Bonus",
		"variant_id": "double_double_bonus",
		"paytable_tier_id": "full_pay",
		"hand_count": 3,
		"identity": "Premium gold high-roller cabinet",
		"theme": "gold",
		"primary": "#ffc84d",
		"secondary": "#ff5a3d",
		"body": "#241406",
		"glass": "#140a04",
		"button": "#ffbf35",
		"trim": "#fff0a4",
		"cheat_name": "High-Roller Hold",
		"cheat_verb": "locked in",
		"cheat_prompt": "Hit the gold timing lane, then tap the bonus-card slot.",
		"cheat_commit_label": "LOCK BONUS",
		"sfx_family": "triple",
	},
}

const MULTI_HAND_OPTIONS := [1, 2, 3]

const PAYTABLE_TIERS := {
	"full_pay": {
		"label": "Full-Pay",
		"weight": 2,
		"overrides": {
			"jacks_or_better": {"full_house": 9, "flush": 6},
			"bonus_poker": {"full_house": 8, "flush": 5},
			"double_double_bonus": {"full_house": 10, "flush": 6},
			"deuces_wild": {"wild_royal": 25, "five_kind": 15, "straight_flush": 9, "four_kind": 4, "full_house": 4, "flush": 3, "straight": 2},
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
const RANK_WORD := {
	2: "Twos", 3: "Threes", 4: "Fours", 5: "Fives", 6: "Sixes", 7: "Sevens",
	8: "Eights", 9: "Nines", 10: "Tens", 11: "Jacks", 12: "Queens", 13: "Kings", 14: "Aces",
}
const SUIT_WORD := {0: "Spades", 1: "Hearts", 2: "Clubs", 3: "Diamonds"}

var machine_renderer := VideoPokerRendererScript.new()
var _strategy_hold_cache: Dictionary = {}
var _strategy_hold_cache_order: Array[String] = []
var _ritual_host_run_state: RunState = null


func sealed_action_authority_script() -> Script:
	return ActionAuthorityScript


func sealed_action_authority_contract() -> Dictionary:
	return {
		"resolve_proposal_method": &"_machine_game_resolve_proposal",
		"wager_cost_proposal_method": &"_machine_game_wager_cost_proposal",
		"host_auto_tick_method": &"_machine_game_host_needs_auto_tick",
		"surface_intent_key": "",
		"surface_intent_index_key": "",
		"retry_surface_actions": ["video_poker_retry_pending", "video_poker_draw"],
		"cancel_surface_actions": ["video_poker_cancel_pending"],
		"proposal_requires_apply_key": "machine_game_proposal_requires_apply",
		"authoritative_result_marker": "sealed_action_authoritative",
		"place_bet_action": "",
		"host_pointer_intent": false,
	}


func video_poker_ritual_contract() -> Dictionary:
	# Consumer declaration only. Cards, evaluation, paytable, credits, detection,
	# and RNG stay exclusively in this game's existing authority.
	var action_ids := ["video_poker_credit_buy_in", "video_poker_credit_cash_out", "video_poker_handpay_acknowledge", "video_poker_bet_down", "video_poker_bet_one", "video_poker_bet_max", "video_poker_denom", "video_poker_deal", "video_poker_hold", "video_poker_draw", "video_poker_mark", "video_poker_palm", "video_poker_double", "video_poker_double_pick", "video_poker_collect"]
	var declarations: Array = []
	for action_id in action_ids:
		var parameters := {"index": "int"} if action_id in ["video_poker_hold", "video_poker_palm", "video_poker_double_pick"] else {}
		declarations.append({"action_id": action_id, "handler_id": "video_poker_authority", "parameters": parameters})
	return {
		"contract": VIDEO_POKER_RITUAL_CONTRACT,
		"ritual_id": VIDEO_POKER_RITUAL_ID,
		"initial_phase": "credits",
		"ritual_phases": [
			_video_poker_ritual_phase("credits", ["video_poker_credit_buy_in", "video_poker_credit_cash_out", "video_poker_bet_down", "video_poker_bet_one", "video_poker_bet_max", "video_poker_denom", "video_poker_deal"], "commitment"),
			_video_poker_ritual_phase("commitment", ["video_poker_deal"], "initial_deal"),
			_video_poker_ritual_phase("initial_deal", [], "hold_selection"),
			_video_poker_ritual_phase("hold_selection", ["video_poker_hold", "video_poker_mark", "video_poker_palm", "video_poker_draw"], "draw"),
			_video_poker_ritual_phase("draw", ["video_poker_draw"], "result_read"),
			{"id": "result_read", "entry_conditions": [], "permitted_actions": ["video_poker_double", "video_poker_collect"], "entry_operations": [], "transitions": [
				{"id": "result_to_double", "condition": {"kind": "public_state_equals", "key": "double_up_offered", "value": true}, "next_phase": "double_up", "operations": []},
				{"id": "result_to_payout", "condition": {"kind": "public_state_equals", "key": "double_up_offered", "value": false}, "next_phase": "payout_or_handpay", "operations": []},
			], "terminal": false},
			_video_poker_ritual_phase("double_up", ["video_poker_double_pick"], "payout_or_handpay"),
			_video_poker_ritual_phase("payout_or_handpay", ["video_poker_collect", "video_poker_handpay_acknowledge"], "credits"),
		],
		"action_declarations": declarations,
		"staged_commitment": {
			"pending_collection": "pending_items", "working_collection": "working_items", "resolution_collection": "item_resolutions", "funds_authority": "video_poker_game_rules",
			"actions": [{"id": "video_poker_bet_one", "effect": "add_or_increment_one"}, {"id": "video_poker_bet_down", "effect": "remove_one_pending_item"}, {"id": "video_poker_bet_max", "effect": "correct_one_pending_amount"}, {"id": "video_poker_deal", "effect": "authorize_pending_set"}],
			"readable_totals": ["available_funds", "pending_total", "at_risk_total", "returned_stake", "payout", "net_change"],
		},
		"pointer_verbs": [
			_video_poker_pointer("video_poker_deal_press", "hold", "video_poker_deal", "button_deck"),
			_video_poker_pointer("video_poker_card_hold", "place", "video_poker_hold", "card_regions"),
			_video_poker_pointer("video_poker_draw_press", "hold", "video_poker_draw", "button_deck"),
		],
		"actors": [
			{"id": "attendant_primary", "role": "attendant", "anchor": "attendant_station", "poses": ["absent", "approaching", "servicing"], "behavior_states": ["idle", "handpay", "security"], "initial_pose": "absent", "initial_behavior": "idle", "fact_reactions": []},
			{"id": "neighbour_seats", "role": "neighbours", "anchor": "seat_rail", "poses": ["seated", "turning"], "behavior_states": ["idle", "playing", "reacting"], "initial_pose": "seated", "initial_behavior": "idle", "fact_reactions": []},
		],
		"scene_objects": [
			_video_poker_ritual_object("cabinet_body", "cabinet", ["attract", "idle", "play", "lockup"], ["passive"]),
			_video_poker_ritual_object("cabinet_playfield", "playfield", ["deal", "holds", "draw", "result"], ["read_only"]),
			_video_poker_ritual_object("cabinet_paytable", "paytable", ["idle", "highlighted"], ["read_only"]),
			_video_poker_ritual_object("cabinet_credit_meter", "credit_meter", ["ready", "committed", "paying"], ["read_only"]),
			_video_poker_ritual_object("cabinet_tower_light", "tower_light", ["off", "handpay", "security"], ["passive"]),
			_video_poker_ritual_object("cabinet_money_path", "money_path", ["idle", "accepting", "paying"], ["enabled", "locked"]),
			_video_poker_ritual_object("card_0_to_4", "card_regions", ["dealt", "held", "replaced", "final"], ["selectable", "locked"]),
		],
		"energy": {"initial_tier": "quiet", "tiers": [
			{"id": "quiet", "actor_operations": [{"target": "neighbour_seats", "behavior": "idle"}], "object_operations": [{"target": "cabinet_body", "state": "idle"}], "interaction_operations": [], "audio_cues": []},
			{"id": "engaged", "actor_operations": [{"target": "neighbour_seats", "behavior": "playing"}], "object_operations": [{"target": "cabinet_playfield", "state": "holds"}], "interaction_operations": [], "audio_cues": []},
			{"id": "big_win", "actor_operations": [{"target": "neighbour_seats", "behavior": "reacting"}], "object_operations": [{"target": "cabinet_tower_light", "state": "handpay"}], "interaction_operations": [], "audio_cues": []},
			{"id": "lockup", "actor_operations": [{"target": "attendant_primary", "behavior": "handpay"}], "object_operations": [{"target": "cabinet_tower_light", "state": "handpay"}], "interaction_operations": [{"target": "button_deck", "state": "locked"}], "audio_cues": []},
		]},
		"game_facts": [
			{"fact_type": "video_poker.initial_deal_completed", "fact_version": 1, "boundary": "action", "visibility": "public", "payload": {"card_count": "int"}},
			{"fact_type": "video_poker.holds_changed", "fact_version": 1, "boundary": "action", "visibility": "public", "payload": {"held_indices": "int_array"}},
			{"fact_type": "video_poker.result_completed", "fact_version": 1, "boundary": "action", "visibility": "public", "payload": {"pay_label": "string", "credits": "int", "drawn_indices": "int_array"}},
		],
		"ritual_persistence": {
			"authoritative_serialized": ["machine_state", "wager", "holds", "result", "result_receipts"],
			"derived_projection": ["actors", "scene_objects", "energy", "hit_regions", "paytable_highlight"],
			"transient_presentation": ["pointer_path", "card_flip", "draw_cascade", "hover"],
			"one_shot_receipted": ["deal_audio", "draw_audio", "win_audio", "room_reaction", "handpay_call"],
			"save_boundaries": ["credits", "commitment", "initial_deal", "hold_selection", "draw", "result_read", "double_up", "payout_or_handpay"],
			"restore_policy": "restore_legal_phase_without_replay",
		},
		"handler_registry": [{
			"handler_id": "video_poker_authority", "version": 1, "accepted_actions": action_ids, "accepted_operations": [], "inputs": {"phase_id": "string"}, "outputs": {"public_projection": "qualified_id"},
			"authority": "sealed_host_video_poker_game_rules", "persisted_state": ["machine_state", "result_receipts"], "transient_state": ["pointer_path", "card_flip", "draw_cascade"],
			"rng": {"owner": "video_poker_game_rules", "stream": "existing_action_stream", "consumption": "accepted_authoritative_action_only"},
			"emitted_facts": ["video_poker.initial_deal_completed", "video_poker.holds_changed", "video_poker.result_completed"], "rejection": "side_effect_free",
		}],
		"declared_targets": {"anchors": ["cabinet", "attendant_station", "seat_rail", "playfield", "paytable", "credit_meter", "tower_light", "money_path"], "regions": ["button_deck", "card_regions"], "sealed_host_targets": []},
	}


func _video_poker_ritual_phase(phase_id: String, permitted_actions: Array, next_phase: String) -> Dictionary:
	return {"id": phase_id, "entry_conditions": [], "permitted_actions": permitted_actions, "entry_operations": [], "transitions": [{"id": "%s_to_%s" % [phase_id, next_phase], "condition": {"kind": "public_state_equals", "key": "phase_complete", "value": true}, "next_phase": next_phase, "operations": []}], "terminal": false}


func _video_poker_pointer(pointer_id: String, verb: String, action_id: String, region: String) -> Dictionary:
	return {"id": pointer_id, "verb": verb, "source_region": region, "target_regions": [region], "bounds": {"space": "design", "min_distance": 0, "max_distance": 220}, "phases": ["credits", "hold_selection", "draw"], "accepted_action": action_id, "rejection": "restore_focus", "rejection_effects": [], "equivalents": {"keyboard": {"action_id": action_id, "target_selection": "focus"}, "controller": {"action_id": action_id, "target_selection": "focus"}, "reduced_motion": {"action_id": action_id, "target_selection": "focus", "staging": "short"}}}


func _video_poker_ritual_object(object_id: String, anchor: String, appearances: Array, functions: Array) -> Dictionary:
	return {"id": object_id, "anchor": anchor, "bounds": {"space": "design", "x": 80, "y": 50, "w": 740, "h": 330}, "z_layer": 10, "visual_states": appearances, "functional_states": functions, "initial_visual_state": str(appearances[0]), "initial_functional_state": str(functions[0]), "hit_regions": [], "text_safety_regions": []}


# Creates the entry message for the cabinet.
func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
	_ritual_host_run_state = run_state
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
	var cabinet_id := str(rng.pick(CABINET_ORDER, "jacks_or_better"))
	var cabinet: Dictionary = _cabinet_spec(cabinet_id)
	var variant_id := str(cabinet.get("variant_id", "jacks_or_better"))
	var tier_id := str(cabinet.get("paytable_tier_id", "full_pay"))
	var denomination_set: Array = (rng.pick(COIN_DENOMINATION_SETS, COIN_DENOMINATION_SETS[0]) as Array).duplicate(true)
	var hand_count := int(cabinet.get("hand_count", 1))
	var wager_capacity := run_state.wager_capacity_for_game(get_id(), environment) if run_state != null else 20
	var playable_indices: Array = _playable_denomination_indices(denomination_set, hand_count, wager_capacity)
	if playable_indices.is_empty():
		# Keep the authored cabinet intact even when the player arrives without
		# enough cash for one coin. Affordability is re-evaluated live as funds move.
		playable_indices = [0]
	var denomination_index := int(rng.pick(playable_indices, 0))
	var machine_name := str(cabinet.get("machine_name", cabinet.get("label", "Video Poker")))
	var tell := str(cabinet.get("cheat_prompt", "Time the skill beat, then tap the highlighted card slot."))
	var cabinet_key := "%s:%s:%s:%dplay:%s" % [
		cabinet_id,
		tier_id,
		str((denomination_set[denomination_index] as Dictionary).get("label", "1c")),
		hand_count,
		machine_name.to_snake_case(),
	]
	return {
		"schema": STATE_SCHEMA,
		"version": STATE_VERSION,
		"cabinet_id": cabinet_id,
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
	var cabinet: Dictionary = _cabinet_spec(str(state.get("cabinet_id", "jacks_or_better")))
	var ui: Dictionary = _normalized_ui_state(ui_state)
	ui["denomination_index"] = _next_playable_denomination_index(state, _denomination_index(ui, state) - 1, run_state, environment)
	ui["bet_level"] = _affordable_bet_level(state, ui, run_state, environment)
	var last_result: Dictionary = _copy_dict(state.get("last_result", {}))
	var hand_active := bool(ui.get("hand_active", false))
	var double_phase := bool(ui.get("double_active", false)) and _pending_double_credits(last_result) > 0
	var double_result_phase := _double_up_result_visible(last_result, ui)
	var showing_result := not hand_active and not last_result.is_empty()
	var idle_phase := not hand_active and last_result.is_empty() and not double_phase and not double_result_phase
	var phase := "double_result" if double_result_phase else ("double_up" if double_phase else ("idle" if idle_phase else ("settled" if showing_result else "hold")))
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
	elif phase == "settled" or phase == "double_up" or phase == "double_result":
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
	var poker_hat_strategy_active := phase == "hold" and _item_bonus("video_poker_strategy_hint", run_state, false) > 0
	var recommended_holds: Array = []
	if poker_hat_strategy_active:
		recommended_holds = _best_odds_holds(hand, variant, state, coin_count, coin_value, bet_level >= MAX_BET_LEVEL)
	var marked := bool(ui.get("marked", false)) and phase == "hold"
	var holdout_challenge: Dictionary = _normalized_holdout_challenge(ui.get("holdout_challenge", {})) if marked else {}
	var holdout_meter: Dictionary = _holdout_meter(holdout_challenge, ui) if not holdout_challenge.is_empty() else {}
	var win_credits := int(last_result.get("win_credits", 0)) if (phase == "settled" or phase == "double_up" or phase == "double_result") else 0
	var pending_double := _pending_double_credits(last_result)
	var double_view: Dictionary = _double_up_result_view(last_result) if phase == "double_result" else (_double_up_view(run_state, state, ui, last_result) if phase == "double_up" else {})
	var flip: Dictionary = _active_flip(ui, last_result, hand_active)
	var pit_boss: Dictionary = run_state.pit_boss_watch_status(environment)
	var holdout_item_modifiers := skill_item_modifier_badges(run_state, HOLDOUT_ITEM_EFFECT_KEYS)
	var display_hands: Array = []
	if phase == "settled" or phase == "double_up" or phase == "double_result":
		display_hands = final_hands
	else:
		for _hand_index in range(hand_count):
			display_hands.append(hand)
	var winning_pay_keys: Array = []
	for result_value in hand_results:
		if typeof(result_value) != TYPE_DICTIONARY:
			continue
		var result_row: Dictionary = result_value
		var result_key := str(result_row.get("pay_key", ""))
		if int(result_row.get("total", 0)) > 0 and not result_key.is_empty() and not winning_pay_keys.has(result_key):
			winning_pay_keys.append(result_key)
	var rendered_hand_signatures: Array = []
	for display_hand_value in display_hands:
		rendered_hand_signatures.append(_hand_signature(display_hand_value if typeof(display_hand_value) == TYPE_ARRAY else []))
	var outcome_headline := ""
	if phase == "settled":
		if win_credits > 0:
			outcome_headline = "WIN: %s • PAID %d CREDITS" % [pay_label.to_upper(), win_credits]
		else:
			outcome_headline = "NO PAY • SET YOUR BET AND PRESS DEAL"
	elif phase == "double_result":
		var double_outcome := str(last_result.get("double_outcome", "lose"))
		var picked_rank := int(last_result.get("double_pick_rank", 0))
		var dealer_rank := int(last_result.get("double_dealer_rank", 0))
		outcome_headline = "DOUBLE UP %s: %s VS %s" % [double_outcome.to_upper(), _rank_word_single(picked_rank).to_upper(), _rank_word_single(dealer_rank).to_upper()]
	elif phase == "hold":
		outcome_headline = "TAP CARDS TO HOLD • THEN PRESS DRAW"
	else:
		outcome_headline = "SET 1-5 COINS PER HAND • PRESS DEAL"
	var result_detail := outcome_headline
	if phase == "settled" and bool(last_result.get("cheated", false)):
		var holdout_name := str(cabinet.get("cheat_name", "Holdout")).to_upper()
		var result_name := str(last_result.get("blurb", last_result.get("pay_label", "No Pay"))).strip_edges().to_upper()
		if result_name.is_empty():
			result_name = "NO PAY"
		if bool(last_result.get("holdout_applied", false)):
			var target_name := _card_name(_copy_dict(last_result.get("holdout_target_card", {}))).to_upper()
			result_detail = "%s • SWAPPED IN %s • RESULT: %s" % [holdout_name, target_name, result_name]
		else:
			result_detail = "%s • NO CARD SWAPPED • RESULT: %s" % [holdout_name, result_name]

	var spec: Dictionary = GameModule.surface_spec({
		"surface_renderer": "card_machine",
		"surface_life": "screen",
		"surface_cast": "machine",
		"surface_controls_native": true,
		"surface_fixed_price_actions": true,
		"surface_stake_controls_required": false,
		"surface_embeds_outcomes": true,
		"surface_animates_idle": true,
		"surface_realtime_state_refresh": double_result_phase or (marked and str(holdout_challenge.get("skill_grade", "")).is_empty() and not bool(ui.get("reduce_motion", false))),
		"reduce_motion": bool(ui.get("reduce_motion", false)),
		"phase": phase,
		"machine_name": str(state.get("machine_name", "Video Poker")),
		"cabinet_id": str(state.get("cabinet_id", "jacks_or_better")),
		"cabinet_identity": str(cabinet.get("identity", "")),
		"cabinet_theme": str(cabinet.get("theme", "retro")),
		"cabinet_primary": str(cabinet.get("primary", "#19d6ff")),
		"cabinet_secondary": str(cabinet.get("secondary", "#ff4fd8")),
		"cabinet_body": str(cabinet.get("body", "#111a2b")),
		"cabinet_glass": str(cabinet.get("glass", "#071323")),
		"cabinet_button": str(cabinet.get("button", "#1ac8ff")),
		"cabinet_trim": str(cabinet.get("trim", "#f7ef75")),
		"cabinet_cheat_name": str(cabinet.get("cheat_name", "Holdout")),
		"cabinet_cheat_prompt": str(cabinet.get("cheat_prompt", "")),
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
		"credits": maxi(0, run_state.wager_capacity_for_game(get_id(), environment)),
		"progressive_meter": int(state.get("progressive_meter", PROGRESSIVE_BASE)),
		"holdout_tell": str(state.get("holdout_tell", "")),
		"hand": hand,
		"hands": final_hands,
		"display_hands": display_hands,
		"rendered_hand_signatures": rendered_hand_signatures,
		"hand_results": hand_results,
		"holds": holds,
		"suggested_holds": suggested,
		"poker_hat_strategy_active": poker_hat_strategy_active,
		"recommended_holds": recommended_holds,
		"recommended_hold_text": _recommended_hold_text(recommended_holds),
		"scoring_indices": scoring_indices,
		"drawn_indices": drawn_indices,
		"marked": marked,
		"holdout_challenge": holdout_challenge,
		"holdout_meter": holdout_meter,
		"holdout_grade": str(holdout_challenge.get("skill_grade", "")),
		"holdout_ready": marked and not holdout_challenge.is_empty(),
		"holdout_item_modifiers": holdout_item_modifiers,
		"paytable_rows": _paytable_rows(variant),
		"paytable_bets": BET_LADDER,
		"paytable_columns": BET_LADDER.size(),
		"active_paytable_column": bet_level,
		"highlight_bet_column": bet_level,
		"result_pay_key": category,
		"result_pay_label": pay_label,
		"winning_pay_keys": winning_pay_keys,
		"payout_mult": pay_mult,
		"outcome_headline": outcome_headline,
		"result_detail": result_detail,
		"info_text": _info_text(phase, hand, holds, last_result, marked, variant, holdout_challenge),
		"result_message": str(last_result.get("summary", "")) if showing_result or double_phase else "",
		"result_bankroll_delta": int(last_result.get("bankroll_delta", 0)) if phase == "settled" else 0,
		"result_suspicion_delta": int(last_result.get("suspicion_delta", 0)) if phase == "settled" else 0,
		"double_up_available": pending_double > 0 and phase == "settled",
		"double_up_view": double_view,
		"pending_double_credits": pending_double,
		"pit_boss_watched": bool(pit_boss.get("watched", false)) if bool(pit_boss.get("active", false)) else false,
		"pit_boss_summary": str(pit_boss.get("summary", "")) if bool(pit_boss.get("active", false)) else "",
		"hands_played": int(state.get("hands_played", 0)),
		"native_selected_surface_actions": _selected_surface_actions(ui),
		"surface_animation_channels": [
			GameModule.surface_animation_channel(
				FLIP_CHANNEL,
				str(flip.get("id", "")),
				FLIP_DURATION_MSEC if not str(flip.get("id", "")).is_empty() else 0,
				int(flip.get("started", 0)),
				{"clock_source": "surface"}
			),
			GameModule.surface_animation_channel(
				DRAW_CASCADE_CHANNEL,
				str(flip.get("id", "")),
				FLIP_DURATION_MSEC if not str(flip.get("id", "")).is_empty() else 0,
				int(flip.get("started", 0)),
				{"clock_source": "surface"}
			),
		],
		"surface_action_bindings": _video_poker_surface_action_bindings(phase),
		"surface_audio": GameModule.surface_audio_spec({
			"profile_id": "video_poker_machine",
			"action_cues": {
				"video_poker_hold": "video_poker_hold",
				"video_poker_draw": "video_poker_draw",
				"video_poker_mark": "video_poker_cheat",
				"video_poker_palm": "video_poker_cheat_beat",
				"video_poker_deal": "video_poker_deal",
				"video_poker_bet_down": "video_poker_button",
				"video_poker_bet_one": "video_poker_button",
				"video_poker_bet_max": "video_poker_button",
				"video_poker_double": "video_poker_double",
				"video_poker_double_pick": "video_poker_hold",
			},
		}),
	})
	spec["ritual_contract"] = VIDEO_POKER_RITUAL_CONTRACT
	spec["ritual_id"] = VIDEO_POKER_RITUAL_ID
	spec["ritual_projection"] = _video_poker_live_ritual_projection(phase, spec, flip, pit_boss, hand_active, last_result)
	return spec


func _video_poker_live_ritual_projection(phase: String, spec: Dictionary, flip: Dictionary, pit_boss: Dictionary, hand_active: bool, last_result: Dictionary) -> Dictionary:
	var ritual_phase := "credits"
	if phase == "hold":
		ritual_phase = "initial_deal" if not str(flip.get("id", "")).is_empty() else "hold_selection"
	elif phase == "settled":
		ritual_phase = "result_read"
	elif phase == "double_up":
		ritual_phase = "double_up"
	elif phase == "double_result":
		ritual_phase = "payout_or_handpay"
	var watched := bool(pit_boss.get("active", false)) and bool(pit_boss.get("watched", false))
	var win_credits := int(spec.get("win_credits", 0))
	# Video Poker currently has no authoritative hand-pay/lockup boundary. Never
	# infer one from a locally invented payout threshold.
	var handpay := bool(last_result.get("handpay_required", false))
	var energy_tier := "lockup" if handpay or watched else "big_win" if win_credits >= maxi(20, int(spec.get("bet_credits", 0)) * 10) else "engaged" if hand_active else "quiet"
	var actor_states := {
		"attendant_primary": {"visible": handpay or watched, "behavior": "handpay" if handpay else "security"},
		"neighbour_seats": {"visible": true, "behavior": "reacting" if energy_tier in ["big_win", "lockup"] else "playing", "authority": "none"},
	}
	var object_states := {
		"cabinet_body": {"visual_state": "lockup" if handpay else "play" if hand_active else "idle"},
		"cabinet_playfield": {"visual_state": "draw" if phase == "hold" and not str(flip.get("id", "")).is_empty() else "holds" if phase == "hold" else "result" if phase == "settled" else "deal"},
		"cabinet_paytable": {"visual_state": "highlighted" if phase == "settled" else "idle"},
		"cabinet_credit_meter": {"visual_state": "ready", "cash_balance": int(spec.get("credits", 0)), "machine_credit_ledger": "unavailable"},
		"cabinet_tower_light": {"visual_state": "handpay" if handpay else "security" if watched else "off"},
		"cabinet_money_path": {"visual_state": "idle", "functional_state": "locked"},
		"card_0_to_4": {"visual_state": "replaced" if phase == "settled" else "held" if phase == "hold" else "dealt", "functional_state": "selectable" if phase == "hold" else "locked"},
	}
	return {
		"phase_id": ritual_phase,
		"cabinet_state": "lockup" if handpay else "play" if hand_active else "idle",
		"energy_tier": energy_tier,
		"cash_balance": int(spec.get("credits", 0)),
		"machine_credit_ledger_available": false,
		"currency_representability_gap": "No authoritative machine-credit ledger or hand-pay boundary exists in the owned Video Poker state; cash play remains the shipped authority.",
		"denomination_label": str(spec.get("coin_label", "1c")),
		"tower_state": "handpay" if handpay else "security" if watched else "service" if energy_tier == "big_win" else "off",
		"validator_state": "locked" if hand_active or handpay else "ready",
		"button_state": "locked" if handpay else "draw" if phase == "hold" else "deal",
		"result_stage": "card_replacements" if phase == "hold" and not str(flip.get("id", "")).is_empty() else "paytable_read" if phase == "settled" else "idle",
		"held_indices": spec.get("holds", []),
		"drawn_indices": spec.get("drawn_indices", []),
		"paytable_line": str(last_result.get("pay_label", "")),
		"acknowledgement_available": handpay and _ritual_host_run_state != null,
		"actors": actor_states,
		"scene_objects": object_states,
	}


func _video_poker_surface_action_bindings(phase: String) -> Dictionary:
	var primary_action := "video_poker_draw" if phase == "hold" else "video_poker_deal"
	var bindings := {
		"surface_legal": {"action": primary_action, "index": 0},
		"legal": {"action": primary_action, "index": 0},
		"surface_stake_down": {"action": "video_poker_bet_down", "index": 0},
		"surface_stake_up": {"action": "video_poker_bet_one", "index": 0},
		"surface_stake_max": {"action": "video_poker_bet_max", "index": 0},
		"video_poker_deal": {"action": "video_poker_deal", "index": 0},
		"video_poker_draw": {"action": "video_poker_draw", "index": 0},
	}
	for card_index in range(HAND_SIZE):
		bindings["video_poker_hold_%d" % card_index] = {"action": "video_poker_hold", "index": card_index}
	return bindings


func video_poker_ritual_input_command(input_kind: String, semantic_action: String, target_index: int, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	if not input_kind in ["pointer", "keyboard", "controller", "reduced_motion"]:
		return {"handled": false, "error_code": "invalid_parameters"}
	if semantic_action == "video_poker_hold" and (target_index < 0 or target_index >= HAND_SIZE):
		return {"handled": false, "error_code": "unavailable_target"}
	if not semantic_action in ["video_poker_hold", "video_poker_deal", "video_poker_draw"]:
		return {"handled": false, "error_code": "action_not_permitted"}
	var routed_ui := ui_state.duplicate(true)
	if input_kind == "reduced_motion":
		routed_ui["reduce_motion"] = true
	var command := surface_action_command(semantic_action, target_index, false, routed_ui, run_state, environment)
	command["ritual_input_kind"] = input_kind
	command["ritual_target_index"] = target_index
	return command


# The bet is the module-owned ladder wager (2/5/10/15/20 credits), not a host stake.
func wager_cost_for_context(action_id: String, _stake: int, _run_state: RunState, _environment: Dictionary, ui_state: Dictionary = {}) -> int:
	if action_id == "double_up":
		return 0
	if action_id != "draw" and action_id != "mark_holds":
		return 0
	var state: Dictionary = _machine_state(_run_state, _environment)
	return _wager_for(state, _normalized_ui_state(ui_state))


func wager_activity_incomplete(_run_state: RunState, _environment: Dictionary, ui_state: Dictionary = {}) -> bool:
	return bool(_normalized_ui_state(ui_state).get("hand_active", false))


# Draws the cabinet screen and registers visible/invisible hit regions.
func draw_surface(surface, surface_state: Dictionary, _render_context: Dictionary = {}) -> bool:
	return machine_renderer.draw(surface, surface_state, _render_context)


# Converts screen clicks into UI-local bet/hold/deal/double state or shared actions.
func surface_action_command(surface_action: String, index: int, confirm_requested: bool, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var state: Dictionary = _machine_state(run_state, environment)
	var variant: Dictionary = _variant(state)
	var next: Dictionary = _normalized_ui_state(ui_state)
	next["denomination_index"] = _next_playable_denomination_index(state, _denomination_index(next, state) - 1, run_state, environment)
	next["bet_level"] = _affordable_bet_level(state, next, run_state, environment)
	match surface_action:
		"video_poker_credit_buy_in", "video_poker_credit_cash_out":
			return GameModule.surface_command({"handled": true, "ui_state": next, "preserve_surface_ui_state": true, "message": "This cabinet has no authoritative machine-credit conversion boundary; cash remains unchanged."})
		"video_poker_handpay_acknowledge":
			return GameModule.surface_command({"handled": true, "ui_state": next, "preserve_surface_ui_state": true, "message": "Video Poker exposes no authoritative hand-pay boundary to acknowledge."})
		"video_poker_bet_down":
			next["bet_level"] = maxi(0, _bet_level(next) - 1)
			var down_coins := _coin_count_for_level(_bet_level(next))
			return _bet_command(next, _wager_for(state, next), "Bet %d coin%s per hand." % [down_coins, "" if down_coins == 1 else "s"])
		"video_poker_bet_one":
			var level := mini(MAX_BET_LEVEL, _bet_level(next) + 1)
			next["bet_level"] = level
			next["bet_level"] = _affordable_bet_level(state, next, run_state, environment)
			var shown_coins := _coin_count_for_level(_bet_level(next))
			return _bet_command(next, _wager_for(state, next), "Bet %d coin%s per hand." % [shown_coins, "" if shown_coins == 1 else "s"])
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
			var reduced2 := bool(next.get("reduce_motion", false))
			# Surface-clock animation starts must be positive. Zero is a valid
			# simulation time at the beginning of a run, but the canvas reserves a
			# zero start as "unspecified" and otherwise rebases it to engine time.
			# That clock mismatch can leave the dealt cards showing their backs.
			var deal_started_msec := GameModule.deterministic_time_msec(run_state, ui_state)
			next = {"hand_active": true, "holds": [], "marked": false, "bet_level": level2, "denomination_index": denom2}
			if reduced2:
				next["reduce_motion"] = true
			next["deal_id"] = "deal_%d" % deal_started_msec
			next["deal_started_msec"] = deal_started_msec
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
			next.erase("holdout_challenge")
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
			var draw_challenge: Dictionary = _normalized_holdout_challenge(next.get("holdout_challenge", {}))
			if bool(next.get("marked", false)) and not draw_challenge.is_empty():
				var draw_challenge_complete := bool(draw_challenge.get("chain_complete", false)) or not str(draw_challenge.get("skill_grade", "")).is_empty() or _holdout_chain_complete(draw_challenge)
				if not draw_challenge_complete:
					# DRAW must never trap an active hand behind the optional skill UI.
					# Unfinished beats become misses, so abandoning the attempt still
					# resolves immediately and applies the holdout's Heat risk.
					draw_challenge = _grade_holdout_challenge(draw_challenge)
					next["holdout_challenge"] = draw_challenge
				return _immediate_action_command("mark_holds", "cheat", next, index, _wager_for(state, next), "Drawing with the armed holdout.")
			next["marked"] = false
			next.erase("holdout_challenge")
			return _immediate_action_command("draw", "legal", next, index, _wager_for(state, next), "Drawing the un-held cards.")
		"video_poker_mark":
			if not bool(next.get("hand_active", false)):
				return _message_command(next, "Deal a hand first.")
			next["hand_active"] = true
			next["holds"] = _suggested_holds(_opening_hand(run_state, state), variant)
			next["marked"] = true
			next["holdout_challenge"] = _start_holdout_challenge(next, run_state, state, variant, environment)
			return _action_command("mark_holds", "cheat", false, next, index, _wager_for(state, next), "Holdout armed. Follow the yellow timing beat, then commit the highlighted swap.")
		"video_poker_palm":
			if not bool(next.get("hand_active", false)):
				return _message_command(next, "Deal a hand first.")
			var palm_challenge: Dictionary = _normalized_holdout_challenge(next.get("holdout_challenge", {}))
			if palm_challenge.is_empty():
				return _message_command(next, "Mark the holds before trying the holdout.")
			var input_msec := int(next.get("holdout_input_msec", _surface_time_msec(next)))
			palm_challenge = _record_holdout_chain_input(palm_challenge, input_msec, index)
			next["marked"] = true
			next["holdout_challenge"] = palm_challenge
			next.erase("holdout_input_msec")
			var grade_label := _holdout_chain_status_label(palm_challenge)
			return GameModule.surface_command({
				"handled": true,
				"ui_state": next,
				"selected_index": index,
				"preserve_surface_ui_state": true,
				"set_stake": _wager_for(state, next),
				"message": grade_label,
			})
		"video_poker_collect":
			return _message_command(next, "Video poker pays automatically. Deal again or choose DOUBLE UP when available.")
		"video_poker_double":
			var double_started_msec := _surface_time_msec(ui_state)
			next["double_active"] = true
			next.erase("double_pick")
			next["deal_id"] = "double_%d" % double_started_msec
			next["deal_started_msec"] = double_started_msec
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
			return _immediate_action_command("double_up", "legal", next, index, 0, "Card chosen. Flipping now.")
	return {"handled": false}


# Default resolve path delegates to the context-aware resolver.
func resolve(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return resolve_with_context(action_id, stake, run_state, environment, rng, {})


func _machine_game_resolve_proposal(action_id: String, stake: int, run_snapshot: Dictionary, rng_snapshot: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var proposal_input := {
		"action_id": action_id,
		"stake": stake,
		"run_snapshot": run_snapshot,
		"rng_snapshot": rng_snapshot,
		"ui_state": ui_state,
	}
	var candidate := RunState.new()
	candidate.from_dict(run_snapshot.duplicate(true))
	var proposal_rng := RngStream.new()
	proposal_rng.restore(rng_snapshot.duplicate(true))
	var proposal_ui := ui_state.duplicate(true)
	proposal_ui["_sealed_action_defer_apply"] = true
	var result := resolve_with_context(action_id, stake, candidate, candidate.current_environment, proposal_rng, proposal_ui)
	if bool(result.get("ok", false)):
		result["machine_game_proposal_requires_apply"] = true
	var proposal := {
		"ok": bool(result.get("ok", false)),
		"input_fingerprint": RuntimeScript.canonical_fingerprint(proposal_input),
		"result": result.duplicate(true),
		"run_snapshot": candidate.to_save_snapshot(),
		"rng_snapshot": proposal_rng.snapshot(),
	}
	proposal["output_fingerprint"] = RuntimeScript.canonical_fingerprint(proposal)
	return proposal


func _machine_game_wager_cost_proposal(action_id: String, stake: int, run_snapshot: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var candidate := RunState.new()
	candidate.from_dict(run_snapshot.duplicate(true))
	var cost := wager_cost_for_context(action_id, stake, candidate, candidate.current_environment, ui_state.duplicate(true))
	return {
		"cost": maxi(0, cost),
		"input_fingerprint": RuntimeScript.canonical_fingerprint({"action_id": action_id, "stake": stake, "run_snapshot": run_snapshot, "ui_state": ui_state}),
	}


func _machine_game_host_needs_auto_tick(_surface_time_msec: int, _run_state: RunState, _environment: Dictionary) -> bool:
	return false


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

	# Step down only when the wager exceeds the player's available funds. Video
	# poker cabinet denominations are not table limits: a $5 machine must allow
	# all five coin levels whenever the player can pay the resulting wager.
	var wager_capacity := run_state.wager_capacity_for_game(get_id(), environment)
	var affordable := maxi(0, wager_capacity)
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

	# The deal is the deterministic opening. One-hand play draws from the original
	# remaining deck; multi-hand play follows real Triple Play rules: every result
	# hand gets its own independent 52-card deck with only the held cards removed.
	var deck: Array = _deal_deck(run_state, state)
	var opening: Array = _slice_cards(deck, 0, HAND_SIZE)
	var holds: Array = _index_array(ui.get("holds", []))
	var holdout_challenge: Dictionary = {}
	var holdout_grade := ""
	var holdout_accuracy := 0
	var holdout_margin := 0
	var holdout_applied := false
	var holdout_outcome := ""
	if is_cheat:
		holdout_challenge = _finalize_holdout_challenge(ui, run_state, state, variant, environment)
		holdout_grade = str(holdout_challenge.get("skill_grade", "miss"))
		holdout_accuracy = clampi(int(holdout_challenge.get("skill_accuracy", 0)), 0, 100)
		holdout_margin = int(holdout_challenge.get("margin_msec", 0))
		holdout_applied = _holdout_grade_applies(holdout_grade)
		holdout_outcome = _holdout_skill_outcome(holdout_grade)
	var final_hands: Array = []
	var hand_results: Array = []
	var total_gross := 0
	var total_progressive_bonus := 0
	var total_bonus := 0
	var best_index := 0
	var best_value := -999999
	var luck_bonus := clampi(run_state.luck_win_chance_bonus() + _item_bonus("win_chance", run_state, is_cheat), 0, 35)
	var draw_removed_cards: Array = _draw_removed_cards_for_rule(opening, holds, hand_count)
	var draw_base: Array = _deck_without_cards(_base_deck(variant), draw_removed_cards)
	var draw_rule := "single_remaining_deck" if hand_count <= 1 else "independent_deck_minus_held"
	var holds_key := JSON.stringify(holds)
	var wild_ranks := _wild_ranks(variant)
	for hand_index in range(hand_count):
		var draw_stream_key := "draw:%s:%d:%d:%s" % [
			str(state.get("cabinet_key", "")),
			int(state.get("hands_played", 0)),
			hand_index,
			holds_key,
		]
		var hand_rng: RngStream = rng.fork(draw_stream_key)
		# Advance the parent action stream once per hand while keeping each hand's
		# completion deck independently seeded and replayable.
		rng.randi_range(1, RngStream.MODULUS - 1)
		var hand_draw_base := draw_base
		if is_cheat and hand_index == 0 and holdout_applied:
			var reserved_card := _copy_dict(holdout_challenge.get("target_card", {}))
			if not reserved_card.is_empty():
				hand_draw_base = _deck_without_cards(draw_base, [reserved_card])
		var pool: Array = CardShoeScript.shuffle_cards(hand_draw_base, hand_rng)
		var final_hand: Array = opening.duplicate(true)
		var drawn_indices: Array = []
		var pool_cursor := 0
		for i in range(HAND_SIZE):
			if not holds.has(i):
				if pool_cursor < pool.size():
					final_hand[i] = (pool[pool_cursor] as Dictionary).duplicate(true)
					pool_cursor += 1
					drawn_indices.append(i)
		if is_cheat and hand_index == 0 and holdout_applied:
			final_hand = _apply_committed_holdout(final_hand, holds, holdout_challenge)
		var descriptor: Dictionary = _evaluate(final_hand, wild_ranks)
		var pay_row: Dictionary = _pay_for(descriptor, variant)
		if not is_cheat and int(pay_row.get("mult", 0)) <= 0 and luck_bonus > 0 and rng.randi_range(1, 100) <= luck_bonus:
			final_hand = _apply_holdout(final_hand, holds, variant)
			descriptor = _evaluate(final_hand, wild_ranks)
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
		var stored_hand := CardShoeScript.card_array(final_hand)
		final_hands.append(stored_hand)
		hand_results.append({
			"hand_index": hand_index,
			"hand": stored_hand,
			"pay_key": str(pay_row.get("key", "")),
			"pay_label": str(pay_row.get("label", "")),
			"pay_mult": int(pay_row.get("mult", 0)),
			"gross": gross_payout,
			"bonus": bonus_payout,
			"total": hand_total,
			"bonus_label": str(bonus_layer.get("label", "")),
			"scoring_indices": _index_array(descriptor.get("scoring_indices", [])),
			"drawn_indices": drawn_indices,
			"draw_deck_rule": draw_rule,
			"draw_stream_key": draw_stream_key,
			"draw_pool_size": draw_base.size(),
			"draw_removed_cards": draw_removed_cards,
		})
	if final_hands.is_empty():
		return _empty_result(action_id, bet_credits, environment, "The machine failed to draw a hand.")
	var primary_result: Dictionary = hand_results[clampi(best_index, 0, hand_results.size() - 1)]
	var final_hand: Array = primary_result.get("hand", []) if typeof(primary_result.get("hand", [])) == TYPE_ARRAY else []
	var primary_descriptor: Dictionary = _evaluate(final_hand, wild_ranks)
	var pay_row: Dictionary = _pay_for(primary_descriptor, variant)
	var gross_payout := total_gross
	var bankroll_delta := gross_payout - bet_credits
	var profitable := bankroll_delta > 0
	if profitable:
		bankroll_delta = maxi(1, bankroll_delta + run_state.luck_payout_bonus(bet_credits, true) + _item_bonus("win_bonus", run_state, is_cheat))
	elif bankroll_delta < 0:
		bankroll_delta = mini(0, bankroll_delta + _item_bonus("loss_reduction", run_state, is_cheat))

	var suspicion_delta := 0
	var poker_hat_heat := maxi(0, _item_bonus("video_poker_win_heat", run_state, is_cheat)) if gross_payout > 0 else 0
	var security_message := ""
	var pit_boss_summary := ""
	var pit_boss_watched := false
	var pit_boss_heat_bonus := 0
	var base_suspicion_delta := 0
	var ended := false
	if is_cheat:
		var pit_boss_status: Dictionary = run_state.pit_boss_watch_status(environment)
		pit_boss_heat_bonus = int(pit_boss_status.get("cheat_heat_bonus", 0)) if bool(pit_boss_status.get("active", false)) else 0
		pit_boss_watched = bool(pit_boss_status.get("watched", false))
		var grade_heat := _holdout_grade_heat_modifier(holdout_grade)
		base_suspicion_delta = maxi(1, int(holdout_challenge.get("base_heat", _holdout_base_heat(run_state))) + _item_bonus("cheat_suspicion_delta", run_state, true) + grade_heat)
		var raw_heat := maxi(1, base_suspicion_delta + poker_hat_heat + run_state.security_risk_bonus("cheat") + pit_boss_heat_bonus)
		suspicion_delta = run_state.alcohol_adjusted_suspicion_delta(raw_heat)
		if bool(pit_boss_status.get("active", false)):
			pit_boss_summary = str(pit_boss_status.get("summary", ""))
		var security_pressure: Dictionary = run_state.security_action_pressure("cheat", bet_credits, run_state.suspicion_level() + suspicion_delta)
		var security_bankroll_delta := int(security_pressure.get("bankroll_delta", 0))
		if security_bankroll_delta != 0:
			bankroll_delta += security_bankroll_delta
		security_message = str(security_pressure.get("message", ""))
		ended = bool(security_pressure.get("ended", false))
	elif poker_hat_heat > 0:
		suspicion_delta = run_state.alcohol_adjusted_suspicion_delta(poker_hat_heat)

	var blurb := _hand_blurb(primary_descriptor, pay_row, variant)
	if hand_count > 1:
		blurb = "%s x%d hands" % [blurb, hand_count]
	var message := _outcome_message(blurb, pay_row, gross_payout, bankroll_delta, suspicion_delta, is_cheat, pit_boss_summary, security_message, holdout_grade, holdout_applied, holdout_challenge, state)
	# A real machine's WIN meter and gamble stake show the gross paid credits,
	# even when one winning multi-hand row returns less than the total wager.
	var win_credits := maxi(0, gross_payout)

	var resolved_at := GameModule.deterministic_time_msec(run_state, ui)
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
		"double_credits": win_credits if (win_credits > 0 and not is_cheat) else 0,
		"double_chain": 0,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"cheated": is_cheat,
		"holdout_challenge": holdout_challenge if is_cheat else {},
		"holdout_grade": holdout_grade,
		"holdout_applied": holdout_applied,
		"holdout_margin_msec": holdout_margin,
		"holdout_target_card": _copy_dict(holdout_challenge.get("target_card", {})),
		"holdout_target_slot": int(holdout_challenge.get("target_slot", -1)),
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
		"action_kind": "cheat" if is_cheat else "legal",
		"won": gross_payout > 0,
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
		"holdout_applied": holdout_applied,
		"skill_outcome": holdout_outcome if is_cheat else "",
		"skill_grade": holdout_grade,
		"skill_accuracy": holdout_accuracy,
		"skill_margin_msec": holdout_margin,
		"base_suspicion_delta": base_suspicion_delta,
		"pit_boss_watched": pit_boss_watched,
		"pit_boss_heat_bonus": pit_boss_heat_bonus,
		"poker_hat_heat": poker_hat_heat,
		"pit_boss_summary": pit_boss_summary,
		"security_message": security_message,
		"skill_security_pressure_checked": is_cheat,
		"environment_id": environment.get("id", ""),
	}
	if is_cheat:
		story_entry["skill_story_context"] = {
			"game_id": get_id(),
			"action_id": action_id,
			"action_kind": "cheat",
			"skill_outcome": holdout_outcome,
			"skill_grade": holdout_grade,
			"skill_accuracy": holdout_accuracy,
			"skill_margin_msec": holdout_margin,
			"suspicion_delta": suspicion_delta,
			"base_suspicion_delta": base_suspicion_delta,
			"bankroll_delta": bankroll_delta,
			"watched": pit_boss_watched,
			"pit_boss_heat_bonus": pit_boss_heat_bonus,
			"security_pressure_checked": true,
			"target_slot": int(holdout_challenge.get("target_slot", -1)),
			"target_card": _copy_dict(holdout_challenge.get("target_card", {})),
			"holdout_applied": holdout_applied,
		}
	var result := _build_result(action_id, "cheat" if is_cheat else "legal", bet_credits, bankroll_delta, suspicion_delta, ended, message, story_entry, environment)
	result["surface_audio_cue"] = "video_poker_win" if gross_payout > 0 else ("video_poker_cheat_beat" if is_cheat else "video_poker_draw")
	result["surface_audio_context"] = {"action": action_id, "cabinet_id": str(state.get("cabinet_id", "")), "won": gross_payout > 0}
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
	result["video_poker_poker_hat_heat"] = poker_hat_heat
	if is_cheat:
		result["video_poker_pit_boss_watched"] = pit_boss_watched
		result["video_poker_pit_boss_heat_bonus"] = pit_boss_heat_bonus
		result["video_poker_holdout_challenge"] = holdout_challenge
		result["video_poker_holdout_grade"] = holdout_grade
		result["video_poker_holdout_accuracy"] = holdout_accuracy
		result["video_poker_holdout_margin_msec"] = holdout_margin
		result["video_poker_holdout_applied"] = holdout_applied
		result["video_poker_holdout_target_card"] = _copy_dict(holdout_challenge.get("target_card", {}))
		result["video_poker_holdout_target_slot"] = int(holdout_challenge.get("target_slot", -1))
		result["video_poker_blunt_feedback"] = message
		result["skill_outcome"] = holdout_outcome
		result["skill_grade"] = holdout_grade
		result["skill_accuracy"] = holdout_accuracy
		result["skill_margin_msec"] = holdout_margin
		result["base_suspicion_delta"] = base_suspicion_delta
		result["pit_boss_watched"] = pit_boss_watched
		result["pit_boss_heat_bonus"] = pit_boss_heat_bonus
		result["skill_security_pressure_checked"] = true
		if not security_message.is_empty():
			result["security_message"] = security_message
		result["skill_story_context"] = _copy_dict(story_entry.get("skill_story_context", {}))
		GameModule.normalize_skill_cheat_contract(result, result)
	if not bool(ui.get("_sealed_action_defer_apply", false)):
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
	var pick_cards: Array = view.get("picks", []) if typeof(view.get("picks", [])) == TYPE_ARRAY else []
	var picked_card: Dictionary = _copy_dict(pick_cards[pick_index]) if pick_index >= 0 and pick_index < pick_cards.size() else {}
	var dealer_card: Dictionary = _copy_dict(view.get("dealer", {}))
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
	var resolved_at_msec := GameModule.deterministic_time_msec(run_state, ui)
	last_result["double_pick_index"] = pick_index
	last_result["double_picked_card"] = picked_card
	last_result["double_dealer_card"] = dealer_card
	last_result["double_at_risk"] = at_risk
	last_result["double_result_until_msec"] = resolved_at_msec + DOUBLE_UP_RESULT_HOLD_MSEC
	last_result["resolved_at_msec"] = resolved_at_msec
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
	result["video_poker_double_pick_index"] = pick_index
	result["video_poker_double_pick_rank"] = pick_rank
	result["video_poker_double_dealer_rank"] = dealer_rank
	if not bool(ui.get("_sealed_action_defer_apply", false)):
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
	if _state_is_current(state):
		# Draw replaces nested result data; double-up copies it before mutation. A
		# shallow shell preserves caller snapshots without re-normalizing the whole
		# prior multi-hand result on every click and surface read.
		return state.duplicate(false)
	return _normalize_state(state)


func _table_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	return _machine_state(run_state, environment)


func _table_state_preview(run_state: RunState, environment: Dictionary) -> Dictionary:
	return _machine_state(run_state, environment)


func _update_environment_table(environment: Dictionary, state: Dictionary) -> void:
	_update_environment_state(environment, state)


func _state_is_current(state: Dictionary) -> bool:
	return str(state.get("schema", "")) == STATE_SCHEMA \
		and int(state.get("version", 0)) >= STATE_VERSION \
		and typeof(state.get("coin_denominations", null)) == TYPE_ARRAY \
		and typeof(state.get("last_result", null)) == TYPE_DICTIONARY


func _cabinet_spec(cabinet_id: String) -> Dictionary:
	if CABINETS.has(cabinet_id):
		return (CABINETS[cabinet_id] as Dictionary).duplicate(true)
	return (CABINETS["jacks_or_better"] as Dictionary).duplicate(true)


func _cabinet_id_for_state(state: Dictionary) -> String:
	var explicit_id := str(state.get("cabinet_id", "")).strip_edges()
	if CABINETS.has(explicit_id):
		return explicit_id
	var variant_id := str(state.get("variant_id", "jacks_or_better"))
	match variant_id:
		"deuces_wild":
			return "double_deuces"
		"double_double_bonus":
			return "triple_double_bonus"
		_:
			return "jacks_or_better"


func _fallback_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var rng := RngStream.new()
	rng.configure(_stable_hash("%s:%s:%s" % [get_id(), str(run_state.seed_text if run_state != null else "fallback"), str(environment.get("id", ""))]))
	return generate_environment_state(run_state, environment, rng)


func _normalize_state(state: Dictionary) -> Dictionary:
	var normalized: Dictionary = state.duplicate(true)
	normalized["schema"] = STATE_SCHEMA
	normalized["version"] = STATE_VERSION
	normalized["cabinet_id"] = _cabinet_id_for_state(normalized)
	var cabinet: Dictionary = _cabinet_spec(str(normalized["cabinet_id"]))
	normalized["machine_name"] = str(cabinet.get("machine_name", normalized.get("machine_name", "Video Poker")))
	normalized["variant_id"] = str(cabinet.get("variant_id", normalized.get("variant_id", "jacks_or_better")))
	if not VARIANTS.has(normalized["variant_id"]):
		normalized["variant_id"] = "jacks_or_better"
	normalized["paytable_tier_id"] = str(cabinet.get("paytable_tier_id", normalized.get("paytable_tier_id", "full_pay")))
	if not PAYTABLE_TIERS.has(normalized["paytable_tier_id"]):
		normalized["paytable_tier_id"] = "full_pay"
	normalized["coin_denominations"] = _normalize_denominations(normalized.get("coin_denominations", []))
	var has_base_denomination := false
	for denomination_value in normalized["coin_denominations"]:
		if typeof(denomination_value) == TYPE_DICTIONARY and int((denomination_value as Dictionary).get("credits", 0)) == 1:
			has_base_denomination = true
			break
	if not has_base_denomination:
		(normalized["coin_denominations"] as Array).push_front({"label": "1c", "credits": 1})
		normalized["denomination_index"] = 0
	normalized["denomination_index"] = clampi(int(normalized.get("denomination_index", 0)), 0, maxi(0, (normalized["coin_denominations"] as Array).size() - 1))
	normalized["multi_hand_count"] = int(cabinet.get("hand_count", _normalize_hand_count(int(normalized.get("multi_hand_count", 1)))))
	normalized["cabinet_key"] = str(normalized.get("cabinet_key", "%s:%s:%dplay" % [normalized["cabinet_id"], normalized["paytable_tier_id"], normalized["multi_hand_count"]]))
	normalized["progressive_meter"] = maxi(PROGRESSIVE_BASE, int(normalized.get("progressive_meter", PROGRESSIVE_BASE)))
	normalized["holdout_tell"] = str(cabinet.get("cheat_prompt", normalized.get("holdout_tell", "")))
	normalized["hands_played"] = int(normalized.get("hands_played", 0))
	normalized["last_result"] = _copy_dict(normalized.get("last_result", {}))
	return normalized


func _update_environment_state(environment: Dictionary, state: Dictionary) -> void:
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var writable_states := game_states.duplicate(false)
	writable_states[get_id()] = state
	environment["game_states"] = writable_states


func _normalized_ui_state(ui_state: Dictionary) -> Dictionary:
	var next: Dictionary = ui_state.duplicate(false)
	next["holds"] = _index_array(next.get("holds", []))
	next["hand_active"] = bool(next.get("hand_active", false))
	next["marked"] = bool(next.get("marked", false))
	next["bet_level"] = clampi(int(next.get("bet_level", 0)), 0, MAX_BET_LEVEL)
	next["denomination_index"] = maxi(0, int(next.get("denomination_index", 0)))
	var holdout_challenge: Dictionary = _normalized_holdout_challenge(next.get("holdout_challenge", {}))
	if holdout_challenge.is_empty():
		next.erase("holdout_challenge")
	elif bool(next.get("hand_active", false)):
		next["holdout_challenge"] = holdout_challenge
	else:
		next.erase("holdout_challenge")
		next["marked"] = false
	return next


func _normalized_holdout_challenge(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = (value as Dictionary).duplicate(true)
	var challenge_id := str(source.get("challenge_id", "")).strip_edges()
	if challenge_id.is_empty():
		return {}
	var started := maxi(0, int(source.get("started_msec", 0)))
	var perfect_msec := maxi(started, int(source.get("perfect_msec", started + HOLDOUT_PROMPT_BASE_MSEC)))
	var windows := GameModule.normalize_skill_timing_windows(
		int(source.get("perfect_window_msec", HOLDOUT_PERFECT_WINDOW_MSEC)),
		int(source.get("good_window_msec", HOLDOUT_GOOD_WINDOW_MSEC)),
		int(source.get("close_window_msec", HOLDOUT_CLOSE_WINDOW_MSEC)),
		20
	)
	var normalized := {
		"challenge_id": challenge_id,
		"opening_hand": CardShoeScript.card_array(source.get("opening_hand", [])),
		"holds": _index_array(source.get("holds", [])),
		"target_card": _copy_dict(source.get("target_card", {})),
		"target_slot": clampi(int(source.get("target_slot", -1)), -1, HAND_SIZE - 1),
		"started_msec": started,
		"perfect_msec": perfect_msec,
		"perfect_window_msec": int(windows.get("perfect_window_msec", HOLDOUT_PERFECT_WINDOW_MSEC)),
		"good_window_msec": int(windows.get("good_window_msec", HOLDOUT_GOOD_WINDOW_MSEC)),
		"close_window_msec": int(windows.get("close_window_msec", HOLDOUT_CLOSE_WINDOW_MSEC)),
		"pit_boss_watched_start": bool(source.get("pit_boss_watched_start", false)),
		"base_heat": maxi(1, int(source.get("base_heat", HOLDOUT_BASE_HEAT))),
		"item_modifiers": _copy_array(source.get("item_modifiers", [])),
		"chain_version": maxi(1, int(source.get("chain_version", HOLDOUT_CHAIN_VERSION))),
		"reduce_motion": bool(source.get("reduce_motion", false)),
	}
	var beats: Array = _normalized_holdout_beats(source.get("beats", []), normalized)
	if not beats.is_empty():
		normalized["beats"] = beats
		normalized["current_beat"] = _holdout_current_beat_index(beats, int(source.get("current_beat", 0)))
		normalized["chain_complete"] = _holdout_beats_complete(beats)
	if source.has("input_msec"):
		normalized["input_msec"] = maxi(0, int(source.get("input_msec", 0)))
	normalized["margin_msec"] = int(source.get("margin_msec", 0))
	var grade := str(source.get("skill_grade", ""))
	if ["perfect", "good", "partial", "miss", "blown"].has(grade):
		normalized["skill_grade"] = grade
	if source.has("skill_accuracy"):
		normalized["skill_accuracy"] = clampi(int(source.get("skill_accuracy", 0)), 0, 100)
	return normalized


func _normalized_holdout_beats(value: Variant, challenge: Dictionary) -> Array:
	var source: Array = value if typeof(value) == TYPE_ARRAY else []
	var normalized: Array = []
	for i in range(source.size()):
		var raw: Dictionary = source[i] if typeof(source[i]) == TYPE_DICTIONARY else {}
		var beat_id := str(raw.get("id", ""))
		if beat_id.is_empty():
			beat_id = "beat_%d" % i
		var duration := maxi(1, int(raw.get("duration_msec", HOLDOUT_BEAT_DURATIONS_MSEC[mini(i, HOLDOUT_BEAT_DURATIONS_MSEC.size() - 1)])))
		var start := maxi(0, int(raw.get("started_msec", challenge.get("started_msec", 0))))
		var target := maxi(start, int(raw.get("target_msec", start + int(round(float(duration) * HOLDOUT_BEAT_TARGETS[mini(i, HOLDOUT_BEAT_TARGETS.size() - 1)])))))
		var beat := {
			"id": beat_id,
			"label": str(raw.get("label", beat_id.to_upper())),
			"kind": str(raw.get("kind", "timing")),
			"started_msec": start,
			"duration_msec": duration,
			"target_msec": target,
			"target_slot": clampi(int(raw.get("target_slot", challenge.get("target_slot", -1))), -1, HAND_SIZE - 1),
			"target_card": _copy_dict(raw.get("target_card", challenge.get("target_card", {}))),
		}
		if raw.has("input_msec"):
			beat["input_msec"] = maxi(0, int(raw.get("input_msec", 0)))
		if raw.has("selected_slot"):
			beat["selected_slot"] = clampi(int(raw.get("selected_slot", -1)), -1, HAND_SIZE - 1)
		var grade := str(raw.get("skill_grade", ""))
		if ["perfect", "good", "partial", "miss", "blown"].has(grade):
			beat["skill_grade"] = grade
		if raw.has("margin_msec"):
			beat["margin_msec"] = int(raw.get("margin_msec", 0))
		if raw.has("skill_accuracy"):
			beat["skill_accuracy"] = clampi(int(raw.get("skill_accuracy", 0)), 0, 100)
		normalized.append(beat)
	return normalized


func _holdout_current_beat_index(beats: Array, fallback: int = 0) -> int:
	for i in range(beats.size()):
		var beat: Dictionary = beats[i] if typeof(beats[i]) == TYPE_DICTIONARY else {}
		if str(beat.get("skill_grade", "")).is_empty():
			return i
	return clampi(fallback, 0, maxi(0, beats.size() - 1))


func _holdout_beats_complete(beats: Array) -> bool:
	if beats.is_empty():
		return false
	for beat_value in beats:
		var beat: Dictionary = beat_value if typeof(beat_value) == TYPE_DICTIONARY else {}
		if str(beat.get("skill_grade", "")).is_empty():
			return false
	return true


func _holdout_chain_complete(challenge: Dictionary) -> bool:
	var normalized := _normalized_holdout_challenge(challenge)
	if normalized.is_empty():
		return false
	if bool(challenge.get("chain_complete", false)) or bool(normalized.get("chain_complete", false)):
		return true
	return not str(challenge.get("skill_grade", normalized.get("skill_grade", ""))).is_empty() and _holdout_beats_complete(normalized.get("beats", []))


func _surface_time_msec(ui_state: Dictionary) -> int:
	if ui_state.has("surface_time_msec"):
		return maxi(0, int(ui_state.get("surface_time_msec", 0)))
	if ui_state.has("deal_started_msec"):
		return maxi(0, int(ui_state.get("deal_started_msec", 0)))
	return 0


func _holdout_windows(run_state: RunState) -> Dictionary:
	var perfect := HOLDOUT_PERFECT_WINDOW_MSEC + _item_bonus("video_poker_holdout_perfect_msec", run_state, true)
	var good := HOLDOUT_GOOD_WINDOW_MSEC + _item_bonus("video_poker_holdout_good_msec", run_state, true)
	var close := HOLDOUT_CLOSE_WINDOW_MSEC + _item_bonus("video_poker_holdout_close_msec", run_state, true)
	var impairment := clampi(int(run_state.drunk_level / 4), 0, 28) if run_state != null else 0
	impairment = maxi(0, impairment - _item_bonus("skill_cheat_drunk_window_offset_msec", run_state, true))
	perfect = maxi(36, perfect - impairment)
	good = maxi(perfect + 48, good - impairment * 2)
	close = maxi(good + 48, close - impairment * 3)
	return {
		"perfect": perfect,
		"good": good,
		"close": close,
	}


func _holdout_base_heat(run_state: RunState) -> int:
	var cheat_def: Dictionary = _cheat_action_def()
	var base_heat := int(cheat_def.get("suspicion_delta", HOLDOUT_BASE_HEAT))
	if run_state != null:
		base_heat += _item_bonus("video_poker_holdout_heat_delta", run_state, true)
	return maxi(1, base_heat)


func _start_holdout_challenge(ui_state: Dictionary, run_state: RunState, state: Dictionary, variant: Dictionary, environment: Dictionary) -> Dictionary:
	var opening: Array = _opening_hand(run_state, state)
	var holds: Array = _index_array(ui_state.get("holds", []))
	var target: Dictionary = _holdout_target(opening, holds, variant)
	var now_msec := _surface_time_msec(ui_state)
	if now_msec <= 0 and run_state != null:
		now_msec = maxi(0, int(run_state.simulation_time_msec()))
	var seed := "%s:%s:%d:%s:%d" % [
		str(state.get("cabinet_key", "")),
		str(run_state.seed_text if run_state != null else ""),
		int(state.get("hands_played", 0)),
		JSON.stringify(holds),
		int(ui_state.get("bet_level", MAX_BET_LEVEL)),
	]
	var prompt_offset := HOLDOUT_PROMPT_BASE_MSEC + (_stable_hash(seed) % 141) - 70
	var windows: Dictionary = _holdout_windows(run_state)
	var pit_boss: Dictionary = run_state.pit_boss_watch_status(environment) if run_state != null else {}
	return {
		"challenge_id": "vp_holdout_%d" % _stable_hash(seed),
		"opening_hand": opening.duplicate(true),
		"holds": holds,
		"target_card": _copy_dict(target.get("card", {})),
		"target_slot": int(target.get("slot", -1)),
		"started_msec": now_msec,
		"perfect_msec": now_msec + prompt_offset,
		"perfect_window_msec": int(windows.get("perfect", HOLDOUT_PERFECT_WINDOW_MSEC)),
		"good_window_msec": int(windows.get("good", HOLDOUT_GOOD_WINDOW_MSEC)),
		"close_window_msec": int(windows.get("close", HOLDOUT_CLOSE_WINDOW_MSEC)),
		"pit_boss_watched_start": bool(pit_boss.get("watched", false)) if bool(pit_boss.get("active", false)) else false,
		"base_heat": _holdout_base_heat(run_state),
		"item_modifiers": skill_item_modifier_badges(run_state, HOLDOUT_ITEM_EFFECT_KEYS),
		"chain_version": HOLDOUT_CHAIN_VERSION,
		"reduce_motion": bool(ui_state.get("reduce_motion", false)),
		"current_beat": 0,
		"chain_complete": false,
		"beats": _build_holdout_beats(now_msec, prompt_offset, windows, target, bool(ui_state.get("reduce_motion", false))),
	}


func _build_holdout_beats(started_msec: int, first_prompt_offset: int, windows: Dictionary, target: Dictionary, reduce_motion: bool) -> Array:
	if reduce_motion:
		return [{
			"id": "reduced",
			"label": "SAFE COMMIT",
			"kind": "simple",
			"started_msec": started_msec,
			"duration_msec": HOLDOUT_REDUCED_DURATION_MSEC,
			"target_msec": started_msec + HOLDOUT_REDUCED_DURATION_MSEC / 2,
			"target_slot": int(target.get("slot", -1)),
			"target_card": _copy_dict(target.get("card", {})),
		}]
	var beats: Array = []
	var cursor := started_msec
	for i in range(HOLDOUT_BEAT_IDS.size()):
		var duration := int(HOLDOUT_BEAT_DURATIONS_MSEC[i])
		var target_msec := cursor + int(round(float(duration) * float(HOLDOUT_BEAT_TARGETS[i])))
		if i == 0:
			duration = maxi(duration, first_prompt_offset + int(windows.get("close", HOLDOUT_CLOSE_WINDOW_MSEC)) + 60)
			target_msec = started_msec + first_prompt_offset
		beats.append({
			"id": str(HOLDOUT_BEAT_IDS[i]),
			"label": str(HOLDOUT_BEAT_LABELS[i]),
			"kind": str(HOLDOUT_BEAT_KINDS[i]),
			"started_msec": cursor,
			"duration_msec": duration,
			"target_msec": target_msec,
			"target_slot": int(target.get("slot", -1)),
			"target_card": _copy_dict(target.get("card", {})),
		})
		cursor += duration + 120
	return beats


func _holdout_target(hand: Array, holds: Array, variant: Dictionary) -> Dictionary:
	var improved: Array = _apply_holdout(hand, holds, variant)
	for i in range(HAND_SIZE):
		if holds.has(i):
			continue
		var original: Dictionary = hand[i] if i < hand.size() and typeof(hand[i]) == TYPE_DICTIONARY else {}
		var replacement: Dictionary = improved[i] if i < improved.size() and typeof(improved[i]) == TYPE_DICTIONARY else {}
		if JSON.stringify(original) != JSON.stringify(replacement):
			return {"slot": i, "card": replacement.duplicate(true)}
	for i in range(HAND_SIZE):
		if not holds.has(i):
			var card: Dictionary = hand[i] if i < hand.size() and typeof(hand[i]) == TYPE_DICTIONARY else {}
			return {"slot": i, "card": card.duplicate(true)}
	return {"slot": -1, "card": {}}


func _apply_committed_holdout(hand: Array, holds: Array, challenge: Dictionary) -> Array:
	var result := hand.duplicate(true)
	var slot := int(challenge.get("target_slot", -1))
	var card := _copy_dict(challenge.get("target_card", {}))
	if slot < 0 or slot >= HAND_SIZE or holds.has(slot) or card.is_empty():
		return result
	result[slot] = card
	return result


func _grade_holdout_challenge(challenge: Dictionary) -> Dictionary:
	var graded: Dictionary = _normalized_holdout_challenge(challenge)
	if graded.is_empty():
		return {}
	var beats: Array = graded.get("beats", []) if typeof(graded.get("beats", [])) == TYPE_ARRAY else []
	if not beats.is_empty():
		for i in range(beats.size()):
			var beat: Dictionary = beats[i] if typeof(beats[i]) == TYPE_DICTIONARY else {}
			if str(beat.get("skill_grade", "")).is_empty():
				beat["skill_grade"] = "miss"
				beat["margin_msec"] = 0
				beat["skill_accuracy"] = 0
			beats[i] = beat
		graded["beats"] = beats
		graded["chain_complete"] = true
		graded["current_beat"] = maxi(0, beats.size() - 1)
		var aggregate := _aggregate_holdout_chain_grade(beats)
		graded["skill_grade"] = str(aggregate.get("skill_grade", "miss"))
		graded["skill_accuracy"] = clampi(int(aggregate.get("skill_accuracy", 0)), 0, 100)
		graded["margin_msec"] = int(aggregate.get("margin_msec", 0))
		return graded
	if not graded.has("input_msec") or int(graded.get("input_msec", 0)) <= 0:
		graded["skill_grade"] = "miss"
		graded["margin_msec"] = 0
		graded["skill_accuracy"] = 0
		return graded
	var margin := int(graded.get("input_msec", 0)) - int(graded.get("perfect_msec", 0))
	var abs_margin := absi(margin)
	var timing := GameModule.skill_timing_grade_from_distance(
		abs_margin,
		int(graded.get("perfect_window_msec", HOLDOUT_PERFECT_WINDOW_MSEC)),
		int(graded.get("good_window_msec", HOLDOUT_GOOD_WINDOW_MSEC)),
		int(graded.get("close_window_msec", HOLDOUT_CLOSE_WINDOW_MSEC)),
		20
	)
	graded["skill_grade"] = str(timing.get("skill_grade", "blown"))
	graded["margin_msec"] = margin
	graded["skill_accuracy"] = clampi(int(timing.get("skill_accuracy", 0)), 0, 100)
	return graded


func _record_holdout_chain_input(challenge: Dictionary, input_msec: int, selected_index: int) -> Dictionary:
	var next: Dictionary = _normalized_holdout_challenge(challenge)
	if next.is_empty():
		return {}
	var beats: Array = next.get("beats", []) if typeof(next.get("beats", [])) == TYPE_ARRAY else []
	if beats.is_empty():
		next["input_msec"] = input_msec
		return _grade_holdout_challenge(next)
	var beat_index := _holdout_current_beat_index(beats, int(next.get("current_beat", 0)))
	var beat: Dictionary = beats[beat_index] if typeof(beats[beat_index]) == TYPE_DICTIONARY else {}
	beat["input_msec"] = maxi(0, input_msec)
	if str(beat.get("kind", "")) == "target":
		beat["selected_slot"] = clampi(selected_index, -1, HAND_SIZE - 1)
	beat = _grade_holdout_beat(beat, next)
	beats[beat_index] = beat
	_rebase_remaining_holdout_beats(beats, beat_index + 1, input_msec)
	next["beats"] = beats
	next["current_beat"] = _holdout_current_beat_index(beats, beat_index + 1)
	next["chain_complete"] = _holdout_beats_complete(beats)
	if bool(next.get("chain_complete", false)):
		next = _grade_holdout_challenge(next)
	return next


func _grade_holdout_beat(beat: Dictionary, challenge: Dictionary) -> Dictionary:
	var graded := beat.duplicate(true)
	var kind := str(graded.get("kind", "timing"))
	if kind == "simple":
		graded["skill_grade"] = "perfect"
		graded["margin_msec"] = 0
		graded["skill_accuracy"] = 100
		return graded
	if kind == "target" and int(graded.get("selected_slot", -99)) != int(challenge.get("target_slot", -1)):
		graded["skill_grade"] = "blown" if int(graded.get("selected_slot", -1)) >= 0 else "miss"
		graded["margin_msec"] = 0
		graded["skill_accuracy"] = 0
		return graded
	# The visible sweep loops until the player responds. Grade its current
	# position rather than time elapsed since the first pass so it can never
	# freeze into an unwinnable state.
	var margin := _holdout_sweep_margin_msec(graded, int(graded.get("input_msec", 0)))
	var abs_margin := absi(margin)
	var timing := GameModule.skill_timing_grade_from_distance(
		abs_margin,
		int(challenge.get("perfect_window_msec", HOLDOUT_PERFECT_WINDOW_MSEC)),
		int(challenge.get("good_window_msec", HOLDOUT_GOOD_WINDOW_MSEC)),
		int(challenge.get("close_window_msec", HOLDOUT_CLOSE_WINDOW_MSEC)),
		20
	)
	graded["skill_grade"] = str(timing.get("skill_grade", "blown"))
	graded["margin_msec"] = margin
	graded["skill_accuracy"] = clampi(int(timing.get("skill_accuracy", 0)), 0, 100)
	return graded


func _rebase_remaining_holdout_beats(beats: Array, first_index: int, input_msec: int) -> void:
	var cursor := maxi(0, input_msec) + 120
	for index in range(maxi(0, first_index), beats.size()):
		var beat: Dictionary = beats[index] if typeof(beats[index]) == TYPE_DICTIONARY else {}
		var duration := maxi(1, int(beat.get("duration_msec", HOLDOUT_BEAT_DURATIONS_MSEC[mini(index, HOLDOUT_BEAT_DURATIONS_MSEC.size() - 1)])))
		beat["started_msec"] = cursor
		beat["target_msec"] = cursor + int(round(float(duration) * HOLDOUT_BEAT_TARGETS[mini(index, HOLDOUT_BEAT_TARGETS.size() - 1)]))
		beats[index] = beat
		cursor += duration + 120


func _holdout_sweep_progress(beat: Dictionary, current_msec: int) -> float:
	var started := int(beat.get("started_msec", current_msec))
	var duration := maxi(1, int(beat.get("duration_msec", HOLDOUT_PROMPT_BASE_MSEC + HOLDOUT_CLOSE_WINDOW_MSEC)))
	if current_msec <= started:
		return 0.0
	var cycle_msec := posmod(current_msec - started, duration * 2)
	var phase := float(cycle_msec) / float(duration)
	return phase if phase <= 1.0 else 2.0 - phase


func _holdout_sweep_margin_msec(beat: Dictionary, current_msec: int) -> int:
	var started := int(beat.get("started_msec", current_msec))
	var duration := maxi(1, int(beat.get("duration_msec", HOLDOUT_PROMPT_BASE_MSEC + HOLDOUT_CLOSE_WINDOW_MSEC)))
	var target_msec := int(beat.get("target_msec", started + int(round(float(duration) * 0.58))))
	var target_progress := clampf(float(target_msec - started) / float(duration), 0.0, 1.0)
	return int(round((_holdout_sweep_progress(beat, current_msec) - target_progress) * float(duration)))


func _aggregate_holdout_chain_grade(beats: Array) -> Dictionary:
	var worst_rank := 0
	var accuracy_total := 0
	var margin_total := 0
	for beat_value in beats:
		var beat: Dictionary = beat_value if typeof(beat_value) == TYPE_DICTIONARY else {}
		var grade := str(beat.get("skill_grade", "miss"))
		worst_rank = maxi(worst_rank, _holdout_grade_rank(grade))
		accuracy_total += clampi(int(beat.get("skill_accuracy", 0)), 0, 100)
		margin_total += int(beat.get("margin_msec", 0))
	var averaged_accuracy := int(round(float(accuracy_total) / float(maxi(1, beats.size()))))
	var averaged_margin := int(round(float(margin_total) / float(maxi(1, beats.size()))))
	return {
		"skill_grade": _holdout_rank_grade(worst_rank),
		"skill_accuracy": averaged_accuracy,
		"margin_msec": averaged_margin,
	}


func _holdout_grade_rank(grade: String) -> int:
	match grade:
		"perfect":
			return 0
		"good":
			return 1
		"partial":
			return 2
		"miss":
			return 3
		"blown":
			return 4
	return 3


func _holdout_rank_grade(rank: int) -> String:
	match rank:
		0:
			return "perfect"
		1:
			return "good"
		2:
			return "partial"
		4:
			return "blown"
	return "miss"


func _holdout_chain_status_label(challenge: Dictionary) -> String:
	var normalized := _normalized_holdout_challenge(challenge)
	var beats: Array = normalized.get("beats", []) if typeof(normalized.get("beats", [])) == TYPE_ARRAY else []
	if bool(normalized.get("chain_complete", false)):
		return "Holdout chain locked: %s." % str(normalized.get("skill_grade", "miss")).replace("_", " ").capitalize()
	var current := _holdout_current_beat_index(beats, int(normalized.get("current_beat", 0)))
	if current < beats.size():
		var beat: Dictionary = beats[current] if typeof(beats[current]) == TYPE_DICTIONARY else {}
		return "%s locked. Next: %s." % [
			str(HOLDOUT_BEAT_LABELS[maxi(0, current - 1)] if current > 0 and current - 1 < HOLDOUT_BEAT_LABELS.size() else "Beat"),
			str(beat.get("label", "BEAT")).to_upper(),
		]
	return "Holdout chain waiting for the draw."


func _finalize_holdout_challenge(ui: Dictionary, run_state: RunState, state: Dictionary, variant: Dictionary, environment: Dictionary) -> Dictionary:
	var challenge: Dictionary = _normalized_holdout_challenge(ui.get("holdout_challenge", {}))
	if challenge.is_empty():
		challenge = _start_holdout_challenge(ui, run_state, state, variant, environment)
	if ui.has("holdout_input_msec") and not challenge.has("input_msec"):
		challenge["input_msec"] = maxi(0, int(ui.get("holdout_input_msec", 0)))
	return _grade_holdout_challenge(challenge)


func _holdout_grade_applies(grade: String) -> bool:
	return GameModule.skill_grade_applies(grade)


func _holdout_grade_heat_modifier(grade: String) -> int:
	match grade:
		"perfect":
			return -HOLDOUT_PERFECT_HEAT_REDUCTION
		"partial":
			return HOLDOUT_PARTIAL_HEAT_BONUS
		"miss":
			return HOLDOUT_MISS_HEAT_BONUS
		"blown":
			return HOLDOUT_BLOWN_HEAT_BONUS
	return 0


func _holdout_skill_outcome(grade: String) -> String:
	return GameModule.skill_outcome_for_grade("holdout", grade)


func _holdout_meter(challenge: Dictionary, ui_state: Dictionary) -> Dictionary:
	var current_msec := _surface_time_msec(ui_state)
	var beats: Array = challenge.get("beats", []) if typeof(challenge.get("beats", [])) == TYPE_ARRAY else []
	var current_beat := _holdout_current_beat_index(beats, int(challenge.get("current_beat", 0))) if not beats.is_empty() else 0
	var beat: Dictionary = beats[current_beat] if current_beat < beats.size() and typeof(beats[current_beat]) == TYPE_DICTIONARY else {}
	var started := int(beat.get("started_msec", challenge.get("started_msec", current_msec)))
	var duration := maxi(1, int(beat.get("duration_msec", HOLDOUT_PROMPT_BASE_MSEC + HOLDOUT_CLOSE_WINDOW_MSEC)))
	var perfect := int(beat.get("target_msec", challenge.get("perfect_msec", started + HOLDOUT_PROMPT_BASE_MSEC)))
	var progress := _holdout_sweep_progress(beat, current_msec)
	var target := clampf(float(perfect - started) / float(duration), 0.0, 1.0)
	var input_progress := -1.0
	if beat.has("input_msec"):
		input_progress = clampf(float(int(beat.get("input_msec", 0)) - started) / float(duration), 0.0, 1.0)
	elif challenge.has("input_msec"):
		input_progress = clampf(float(int(challenge.get("input_msec", 0)) - started) / float(duration), 0.0, 1.0)
	return {
		"active": true,
		"center_focus": true,
		"chain_version": int(challenge.get("chain_version", HOLDOUT_CHAIN_VERSION)),
		"beat_index": current_beat,
		"beat_count": maxi(1, beats.size()),
		"beat_id": str(beat.get("id", "line_up")),
		"beat_label": str(beat.get("label", "LINE UP")),
		"beat_kind": str(beat.get("kind", "timing")),
		"target_slot": int(challenge.get("target_slot", -1)),
		"target_card": _copy_dict(challenge.get("target_card", {})),
		"reduce_motion": bool(challenge.get("reduce_motion", ui_state.get("reduce_motion", false))),
		"chain_complete": bool(challenge.get("chain_complete", false)),
		"progress": progress,
		"target": target,
		"perfect_window": clampf(float(int(challenge.get("perfect_window_msec", HOLDOUT_PERFECT_WINDOW_MSEC))) / float(duration), 0.01, 0.45),
		"good_window": clampf(float(int(challenge.get("good_window_msec", HOLDOUT_GOOD_WINDOW_MSEC))) / float(duration), 0.02, 0.48),
		"input": input_progress,
		"skill_grade": str(challenge.get("skill_grade", "")),
		"beat_results": beats,
	}


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
		# A denomination is valid when its one-coin wager can be played. Requiring
		# all five coins to fit made 3-Play Triple Double Bonus skip valid 50c/$1
		# choices and could leave its denomination button stuck. Bet-level clamping
		# independently limits how many coins are affordable at the selected value.
		var minimum_wager := maxi(1, int(entry.get("credits", 1))) * maxi(1, hand_count)
		if minimum_wager <= wager_ceiling:
			result.append(i)
	return result


func _full_ladder_denomination_indices(denominations: Array, hand_count: int, wager_ceiling: int) -> Array:
	var result: Array = []
	for i in range(denominations.size()):
		var entry: Dictionary = denominations[i] if typeof(denominations[i]) == TYPE_DICTIONARY else {}
		var max_wager := maxi(1, int(entry.get("credits", 1))) * maxi(1, hand_count) * _coin_count_for_level(MAX_BET_LEVEL)
		if max_wager <= wager_ceiling:
			result.append(i)
	return result


func _affordable_bet_level(state: Dictionary, ui: Dictionary, run_state: RunState, environment: Dictionary) -> int:
	var level := _bet_level(ui)
	var wager_capacity := run_state.wager_capacity_for_game(get_id(), environment) if run_state != null else 20
	var affordable := maxi(0, wager_capacity)
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
	var wager_capacity := run_state.wager_capacity_for_game(get_id(), environment) if run_state != null else 20
	var playable: Array = _playable_denomination_indices(denominations, _hand_count(state), maxi(0, wager_capacity))
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
	return clampi(int(ui.get("bet_level", 0)), 0, MAX_BET_LEVEL)


func _coin_count_for_level(level: int) -> int:
	return int(COIN_LEVELS[clampi(level, 0, MAX_COIN_LEVEL)])


func _wager_for(state: Dictionary, ui: Dictionary) -> int:
	# Video poker wagers are deliberately denomination * coin count * hand count,
	# not the table-stake clamp used by chip games.
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


func _draw_removed_cards_for_rule(opening: Array, holds: Array, hand_count: int) -> Array:
	var removed: Array = []
	if hand_count <= 1:
		return opening
	for hold_value in holds:
		var hold_index := int(hold_value)
		if hold_index < 0 or hold_index >= opening.size():
			continue
		var card: Dictionary = opening[hold_index] if typeof(opening[hold_index]) == TYPE_DICTIONARY else {}
		if not card.is_empty():
			removed.append(card)
	return removed


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

# Fred's hat uses the active cabinet's real paytable to compare every possible
# hold. One- and two-card draws are exhaustive; larger draws use a deterministic
# capped sample. Results are cached per dealt hand, paytable, bet, and progressive
# so repeated surface redraws do no strategy work.
func _best_odds_holds(hand: Array, variant: Dictionary, state: Dictionary, coin_count: int, coin_value: int, is_max_bet: bool) -> Array:
	if hand.size() != HAND_SIZE:
		return []
	var cache_key := "%s|%s|%d|%d|%d|%d" % [
		str(variant.get("id", "")),
		str(variant.get("paytable_tier_id", "")),
		coin_count,
		coin_value,
		int(state.get("progressive_meter", PROGRESSIVE_BASE)),
		_stable_hash(_hand_signature(hand)),
	]
	if _strategy_hold_cache.has(cache_key):
		return _index_array(_strategy_hold_cache.get(cache_key, []))
	var deck := _deck_without_cards(_base_deck(variant), hand)
	var best_holds: Array = []
	var best_average := -1.0
	for mask in range(1 << HAND_SIZE):
		var holds: Array = []
		for index in range(HAND_SIZE):
			if (mask & (1 << index)) != 0:
				holds.append(index)
		var score := _hold_expected_pay(hand, deck, holds, variant, state, coin_count, coin_value, is_max_bet, cache_key)
		if score > best_average + 0.000001 or (is_equal_approx(score, best_average) and holds.size() > best_holds.size()):
			best_average = score
			best_holds = holds
	_strategy_hold_cache[cache_key] = _index_array(best_holds)
	_strategy_hold_cache_order.append(cache_key)
	while _strategy_hold_cache_order.size() > STRATEGY_CACHE_LIMIT:
		_strategy_hold_cache.erase(_strategy_hold_cache_order.pop_front())
	return _index_array(best_holds)


func _hold_expected_pay(hand: Array, deck: Array, holds: Array, variant: Dictionary, state: Dictionary, coin_count: int, coin_value: int, is_max_bet: bool, seed_key: String) -> float:
	var draw_slots: Array = []
	for index in range(HAND_SIZE):
		if not holds.has(index):
			draw_slots.append(index)
	var draw_count := draw_slots.size()
	if draw_count == 0:
		return float(_strategy_hand_pay(hand, variant, state, coin_count, coin_value, is_max_bet))
	var total := 0.0
	var samples := 0
	if draw_count == 1:
		for first in range(deck.size()):
			total += _strategy_completion_pay(hand, draw_slots, [deck[first]], variant, state, coin_count, coin_value, is_max_bet)
			samples += 1
	elif draw_count == 2:
		for first in range(deck.size() - 1):
			for second in range(first + 1, deck.size()):
				total += _strategy_completion_pay(hand, draw_slots, [deck[first], deck[second]], variant, state, coin_count, coin_value, is_max_bet)
				samples += 1
	else:
		var sample_rng := RngStream.new()
		sample_rng.configure(_stable_hash("%s|%s" % [seed_key, JSON.stringify(holds)]))
		for _sample in range(STRATEGY_SAMPLE_CAP):
			var pool := deck.duplicate(false)
			var cards: Array = []
			for _draw in range(draw_count):
				var pick := sample_rng.randi_range(0, pool.size() - 1)
				cards.append(pool[pick])
				pool.remove_at(pick)
			total += _strategy_completion_pay(hand, draw_slots, cards, variant, state, coin_count, coin_value, is_max_bet)
			samples += 1
	return total / float(maxi(1, samples))


func _strategy_completion_pay(hand: Array, draw_slots: Array, cards: Array, variant: Dictionary, state: Dictionary, coin_count: int, coin_value: int, is_max_bet: bool) -> int:
	var completed := hand.duplicate(false)
	for index in range(mini(draw_slots.size(), cards.size())):
		completed[int(draw_slots[index])] = cards[index]
	return _strategy_hand_pay(completed, variant, state, coin_count, coin_value, is_max_bet)


func _strategy_hand_pay(hand: Array, variant: Dictionary, state: Dictionary, coin_count: int, coin_value: int, is_max_bet: bool) -> int:
	var descriptor := _evaluate(hand, _wild_ranks(variant))
	var pay_row := _pay_for(descriptor, variant)
	var base_pay := _row_pay(pay_row, coin_count, is_max_bet) * coin_value
	return base_pay + int(_bonus_layer(hand, descriptor, pay_row, state, coin_count, coin_value, is_max_bet).get("bonus", 0))


func _recommended_hold_text(holds: Array) -> String:
	if holds.is_empty():
		return "DRAW ALL FIVE"
	if holds.size() >= HAND_SIZE:
		return "HOLD ALL FIVE"
	var positions: Array[String] = []
	for hold_value in holds:
		positions.append(str(int(hold_value) + 1))
	return "HOLD CARDS %s" % ", ".join(positions)

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


func _double_up_result_visible(last_result: Dictionary, ui: Dictionary) -> bool:
	if str(last_result.get("double_outcome", "")).is_empty():
		return false
	var until_msec := maxi(0, int(last_result.get("double_result_until_msec", 0)))
	var now_msec := _surface_time_msec(ui)
	return until_msec > 0 and now_msec > 0 and now_msec < until_msec


func _double_up_result_view(last_result: Dictionary) -> Dictionary:
	var selected_pick := clampi(int(last_result.get("double_pick_index", 0)), 0, 3)
	var picked_card := _copy_dict(last_result.get("double_picked_card", {}))
	var picks: Array = []
	for index in range(4):
		picks.append(picked_card if index == selected_pick else {"hidden": true})
	return {
		"dealer": _copy_dict(last_result.get("double_dealer_card", {})),
		"dealer_rank": int(last_result.get("double_dealer_rank", 0)),
		"picks": picks,
		"selected_pick": selected_pick,
		"picked_card": picked_card,
		"picked_rank": int(last_result.get("double_pick_rank", 0)),
		"outcome": str(last_result.get("double_outcome", "")),
		"at_risk": maxi(0, int(last_result.get("double_at_risk", 0))),
		"result_message": str(last_result.get("summary", "")),
		"resolved": true,
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


func _outcome_message(blurb: String, pay_row: Dictionary, coin_pay: int, bankroll_delta: int, suspicion_delta: int, is_cheat: bool, pit_boss_summary: String, security_message: String, holdout_grade: String = "", holdout_applied: bool = false, holdout_challenge: Dictionary = {}, state: Dictionary = {}) -> String:
	var lead := "You draw %s." % blurb
	if is_cheat:
		var grade_text := holdout_grade.replace("_", " ").capitalize()
		var cabinet: Dictionary = _cabinet_spec(str(state.get("cabinet_id", "jacks_or_better")))
		var card_text := _card_name(_copy_dict(holdout_challenge.get("target_card", {})))
		var slot_text := "slot %d" % (int(holdout_challenge.get("target_slot", -1)) + 1)
		var verb := str(cabinet.get("cheat_verb", "slipped in"))
		if holdout_applied:
			lead = "%s %s: you %s the %s into %s — RESULT: %s." % [
				str(cabinet.get("cheat_name", "Holdout")).to_upper(),
				grade_text.to_upper(),
				verb,
				card_text,
				slot_text,
				blurb.to_upper(),
			]
		elif holdout_grade == "miss":
			lead = "%s MISSED: no card was swapped; you draw %s." % [str(cabinet.get("cheat_name", "Holdout")).to_upper(), blurb]
		else:
			lead = "%s LATE: the %s did not land cleanly; you draw %s." % [str(cabinet.get("cheat_name", "Holdout")).to_upper(), card_text, blurb]
	var pay_text := "No pay"
	if coin_pay > 0:
		pay_text = "Pays %d credits" % coin_pay if int(pay_row.get("mult", 0)) >= 1 else "No pay"
	if bankroll_delta == 0 and coin_pay > 0:
		pay_text = "Pushes (bet returned)"
	var message := "%s %s. Bankroll %+d." % [lead, pay_text, bankroll_delta]
	if suspicion_delta > 0:
		message += " Heat rises +%d." % suspicion_delta
	if not pit_boss_summary.is_empty():
		message += " %s" % pit_boss_summary
	if not security_message.is_empty():
		message += " %s" % security_message
	return message


func _info_text(phase: String, hand: Array, holds: Array, last_result: Dictionary, marked: bool, variant: Dictionary, holdout_challenge: Dictionary = {}) -> String:
	if phase == "idle":
		return "Deal ready."
	if phase == "double_up":
		return "Double or nothing: pick a card to beat the dealer."
	if phase == "double_result":
		return str(last_result.get("summary", "Double up resolved."))
	if phase == "settled" and not last_result.is_empty():
		var bet := int(last_result.get("bet_credits", 0))
		var mult := int(last_result.get("pay_mult", 0))
		var blurb := str(last_result.get("blurb", ""))
		if mult > 0:
			return "%s — pays %dx (bet %d)" % [blurb, mult, bet]
		return "%s — no pay" % blurb
	if marked:
		var grade := str(holdout_challenge.get("skill_grade", ""))
		if not grade.is_empty():
			return "Holdout %s locked. Draw to finish the swap." % grade.replace("_", " ").capitalize()
		var beats: Array = holdout_challenge.get("beats", []) if typeof(holdout_challenge.get("beats", [])) == TYPE_ARRAY else []
		var beat_index := _holdout_current_beat_index(beats, int(holdout_challenge.get("current_beat", 0))) if not beats.is_empty() else 0
		var beat: Dictionary = beats[beat_index] if beat_index < beats.size() and typeof(beats[beat_index]) == TYPE_DICTIONARY else {}
		return "Holdout armed. Complete %s (%d/%d), then draw." % [str(beat.get("label", "LINE UP")).to_upper(), beat_index + 1, maxi(1, beats.size())]
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


func _card_name(card: Dictionary) -> String:
	if card.is_empty():
		return "card"
	if bool(card.get("joker", false)) or int(card.get("rank", -1)) == 0:
		return "Joker"
	return "%s of %s" % [_rank_word_single(int(card.get("rank", 0))), _suit_word(int(card.get("suit", 0)))]


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


func _immediate_action_command(action_id: String, action_kind: String, ui_state: Dictionary, index: int, set_stake: int, message: String) -> Dictionary:
	return GameModule.surface_command({
		"handled": true,
		"ui_state": ui_state,
		"action_id": action_id,
		"action_kind": action_kind,
		"direct_resolve": true,
		"preserve_surface_ui_state": false,
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
		return ["video_poker_mark", "video_poker_palm", "video_poker_draw"]
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


func _hand_signature(value: Variant) -> String:
	if typeof(value) != TYPE_ARRAY:
		return ""
	var parts: Array[String] = []
	for card_value in value:
		if typeof(card_value) != TYPE_DICTIONARY:
			parts.append("?")
			continue
		var card: Dictionary = card_value
		if bool(card.get("hidden", false)):
			parts.append("BACK")
		else:
			parts.append("%d:%d" % [int(card.get("rank", 0)), int(card.get("suit", -1))])
	return "|".join(parts)


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
