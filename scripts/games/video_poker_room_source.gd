extends GameModule

# Cabinet state and room readouts are available without loading interactive
# poker play, card evaluation or the cabinet renderer during travel.

const STATE_SCHEMA := "video_poker_machine_state"
const STATE_VERSION := 3
const PROGRESSIVE_BASE := 240

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


# Generates the cabinet identity (game variant) before entry.
# The cabinet's denomination, coin count and hands determine its actual bet.
func actions(run_state: RunState, environment: Dictionary) -> Dictionary:
	var wager_capacity := run_state.wager_capacity_for_game(get_id(), environment)
	return {
		"ok": true,
		"type": "game_actions",
		"game_id": get_id(),
		"legal_actions": legal_actions(run_state, environment),
		"cheat_actions": cheat_actions(run_state, environment),
		"stake_floor": 1,
		"stake_ceiling": maxi(1, wager_capacity),
		"base_stake_ceiling": maxi(1, wager_capacity),
		"economy_state": run_state.economy(),
		"economy_pressure_applied": false,
	}


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
