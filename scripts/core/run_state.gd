class_name RunState
extends RefCounted

# Source of truth for one active run in the foundation path.

const GrandCasinoShowdownModelScript := preload("res://scripts/core/grand_casino_showdown_model.gd")
const GrandCasinoDuelModelScript := preload("res://scripts/core/grand_casino_duel_model.gd")

const DEFAULT_BANKROLL := 100
const LOCAL_RISK_DECAY_BY_DISTANCE := {
	"same": 0,
	"near": 12,
	"local": 35,
	"far": 85,
	"remote": 95,
}
const LOCAL_HEAT_RETURN_DECAY_PERCENT := 10
const LOCAL_RISK_TURN_DECAY_INTERVAL := 2
const ALCOHOL_MAX := 100
const DRUNK_TIME_SCALE_MIN := 0.33
const DRUNK_TIME_SCALE_EXPONENT := 1.63
const DRUNK_ABSORPTION_INTERVAL_MSEC := 3000
const DRUNK_ABSORPTION_INITIAL_POINTS := 4
const DRUNK_ABSORPTION_POINTS_PER_INTERVAL := 4
const DRUNK_ABSORPTION_STACK_GRACE_MSEC := 250
const SIMULATION_ACTION_MSEC := DRUNK_ABSORPTION_INTERVAL_MSEC
const BASELINE_LUCK_MIN := -20
const BASELINE_LUCK_MAX := 20
const EFFECTIVE_LUCK_MIN := -8
const EFFECTIVE_LUCK_MAX := 8
const DRUNK_TURN_DECAY := 2
const DRUNK_TRAVEL_DECAY_BY_DISTANCE := {
	"same": 0,
	"near": 6,
	"local": 11,
	"far": 23,
	"remote": 32,
}
const RUN_STATUS_ACTIVE := "active"
const RUN_STATUS_DISTRESSED := "distressed"
const RUN_STATUS_FAILED := "failed"
const RUN_STATUS_ENDED := "ended"
const FAILURE_NONE := ""
const FAILURE_BANKROLL_ZERO := "bankroll_zero"
const FAILURE_STRANDED := "stranded"
const FAILURE_POLICE_CAPTURE := "police_capture"
const FAILURE_CASINO_TAKEN_OUT_BACK := "casino_taken_out_back"
const FAILURE_ABANDONED := "abandoned"
const BANKROLL_ZERO_FAILURE_MESSAGE := "You are out of money. The run is over."
const STRANDED_FAILURE_MESSAGE := "No valid stake, route, sale, lender, or cash event remains. The run is over."
const POLICE_CAPTURE_FAILURE_MESSAGE := "Police flood the room and catch you before you can slip away. The run is over."
const CASINO_TAKEN_OUT_BACK_FAILURE_MESSAGE := "The casino takes you out back. The run is over."
const ABANDONED_FAILURE_MESSAGE := "You walk away from the table. The run is over."
const GRAND_CASINO_ARCHETYPE_ID := "grand_casino"
const GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID := "grand_casino_high_limit"
const GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID := "grand_casino_back_room"
const GRAND_CASINO_ARCHETYPE_IDS := [
	GRAND_CASINO_ARCHETYPE_ID,
	GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID,
	GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID,
]
const GRAND_CASINO_TABLE_GAME_IDS := ["blackjack", "baccarat", "roulette"]
const GRAND_CASINO_CHIP_GAME_IDS := ["blackjack", "baccarat", "roulette", "slot", "video_poker", "pull_tabs", "bar_dice"]
const GRAND_CASINO_OBJECTIVE_ID := "grand_casino_demo_bankroll"
const GRAND_CASINO_SHOWDOWN_EVENT_ID := "the_house_calls"
const GRAND_CASINO_HIGH_ROLLER_EVENT_ID := "high_roller_cashout"
const GRAND_CASINO_STATE_PRE := "pre-grand"
const GRAND_CASINO_STATE_INCOMPLETE := "grand-incomplete"
const GRAND_CASINO_STATE_HIGH_ROLLER_READY := "high-roller-ready"
const GRAND_CASINO_STATE_SHOWDOWN_PENDING := "showdown-pending"
const GRAND_CASINO_STATE_SHOWDOWN_ACTIVE := "showdown-active"
const GRAND_CASINO_STATE_VICTORY := "victory"
const GRAND_CASINO_STATE_FAILURE := "failure"
const GRAND_CASINO_SHOWDOWN_ROUTE := "pit_boss_showdown"
const GRAND_CASINO_SHOWDOWN_STEP_WALK := "walk"
const GRAND_CASINO_SHOWDOWN_STEP_PAT_DOWN := "pat_down"
const GRAND_CASINO_SHOWDOWN_STEP_INTERROGATION := "interrogation"
const GRAND_CASINO_SHOWDOWN_STEP_DUEL := "duel"
const GRAND_CASINO_SHOWDOWN_STEP_LEGACY_CHECK := "legacy_phase_4"
const GRAND_CASINO_SHOWDOWN_STEP_PRESSURE := "pressure_choice"
const GRAND_CASINO_PLAYERS_CARD_TIER_NONE := "none"
const GRAND_CASINO_PLAYERS_CARD_TIER_BRONZE := "bronze"
const GRAND_CASINO_PLAYERS_CARD_TIER_SILVER := "silver"
const GRAND_CASINO_PLAYERS_CARD_TIER_GOLD := "gold"
const GRAND_CASINO_PLAYERS_CARD_TIERS := [
	GRAND_CASINO_PLAYERS_CARD_TIER_NONE,
	GRAND_CASINO_PLAYERS_CARD_TIER_BRONZE,
	GRAND_CASINO_PLAYERS_CARD_TIER_SILVER,
	GRAND_CASINO_PLAYERS_CARD_TIER_GOLD,
]
const GRAND_CASINO_LINDA_SPEAKER := {
	"role": "staff",
	"name": "Linda",
	"mood": "warm",
	"behavior": "keeping the count",
	"silhouette": "vest",
	"hair_color": "#2a1824",
	"jacket_color": "#234052",
}
const GRAND_CASINO_LINDA_TIER_DIALOGUES := {
	GRAND_CASINO_PLAYERS_CARD_TIER_BRONZE: "linda_bronze_tier",
	GRAND_CASINO_PLAYERS_CARD_TIER_SILVER: "linda_silver_tier",
}
const GRAND_CASINO_STAFF_ROTATION_CHANCE_PERCENT := 50
const GRAND_CASINO_STAFF_ROLE_IDS := ["blackjack", "baccarat", "roulette", "bartender"]
const GRAND_CASINO_STAFF_DEFAULT_ROSTERS := {
	"blackjack": [
		{"id": "mara", "name": "Mara", "style_id": "mara"},
		{"id": "lee", "name": "Lee", "style_id": "lena"},
		{"id": "june", "name": "June", "style_id": "june"},
	],
	"baccarat": [
		{"id": "sable", "name": "Sable", "style_id": "sable"},
		{"id": "noor", "name": "Noor", "style_id": "dot"},
		{"id": "camille", "name": "Camille", "style_id": "iris"},
	],
	"roulette": [
		{"id": "vega", "name": "Vega", "style_id": "vince"},
		{"id": "rook", "name": "Rook", "style_id": "marco"},
		{"id": "sal", "name": "Sal", "style_id": "sal"},
	],
	"bartender": [
		{"id": "rafi", "name": "Rafi", "style_id": "rafi"},
		{"id": "nora", "name": "Nora", "style_id": "nell"},
		{"id": "cal", "name": "Cal", "style_id": "mara"},
	],
}
const GRAND_CASINO_MEMORY_DEFAULT_LINES := {
	"pending_review": "Linda has your prior review slip waiting at the Cage.",
	"showdown_pressure": "The floor remembers Rourke's interest in you.",
	"cheat_evidence": "The dealers remember the move that put your hands on watch.",
	"high_heat": "The staff remember how hot your last visit became.",
	"returning": "A floor attendant recognizes you before you reach the felt.",
}
const GRAND_CASINO_SHOWDOWN_DEFAULT_SUCCESS_MESSAGE := "Rourke cannot prove enough to hold you. The casino lets you walk with your winnings. Rourke lets the elevator close; the house will remember your face."
const GRAND_CASINO_SHOWDOWN_DEFAULT_FAILURE_MESSAGE := "The story falls apart in the back room. The casino takes you out back and the run ends."
const GRAND_CASINO_HIGH_ROLLER_DEFAULT_SUCCESS_MESSAGE := "Linda issues the Gold Players Card and lets you leave with your winnings."
const GRAND_CASINO_ACT_TWO_SEAM_MESSAGE := "The Gold card opens doors beyond this city."
const ROURKE_MOVE_EVALUATION_ACTIONS := 3
const ROURKE_OFF_FLOOR_ACTIONS := 4
const ROURKE_HEAT_DECAY_PERCENT := 80
const ROURKE_INERTIA_HEAT_MARGIN := 2
const ROURKE_ESCORT_CHANCE_PERCENT := 12
const RIVAL_CHEATER_MIN_COUNT := 1
const RIVAL_CHEATER_MAX_COUNT := 3
const ROURKE_ROOM_PATH := [
	GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID,
	GRAND_CASINO_ARCHETYPE_ID,
	GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID,
]
const RIVAL_CHEATER_ROOMS := [
	GRAND_CASINO_ARCHETYPE_ID,
	GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID,
]
const TERMINAL_SCORE_VICTORY_MULTIPLIER := 3
const HEAT_COOLDOWN_ACTIONS_FLAG := "heat_cooldown_actions"
const HEAT_COOLDOWN_PER_ACTION_FLAG := "heat_cooldown_per_action"
const ITEM_DEFINITIONS_PATH := "res://data/items/items.json"
const AVAILABILITY_AVAILABLE := "available"
const AVAILABILITY_TRANSIENT_BLOCKED := "transient_blocked"
const AVAILABILITY_CATEGORICAL_UNAVAILABLE := "categorically_unavailable"
const EVENT_CADENCE_GLOBAL_GAP_ACTIONS := 6
const EVENT_CADENCE_BREATHER_ACTIONS := 1
const EVENT_CADENCE_VISIT_EVENT_CHANCE_PERCENT := 45
const MAX_ENVIRONMENT_HISTORY_ENTRIES := 48
const MAX_STORY_LOG_ENTRIES := 240
const MAX_HEAT_HISTORY_ENTRIES := 480
const HEAT_HISTORY_COMPACT_TARGET := 360
const STORY_SEEN_TYPE_FLAG_PREFIX := "_story_seen:"
const STORY_SEEN_EVENT_FLAG_PREFIX := "_story_seen_event:"
const STORY_SEEN_OBJECTIVE_FLAG_PREFIX := "_story_seen_objective:"
const GAME_CLOCK_START_MINUTE := 12 * 60
const ACTION_CLOCK_MINUTES := 8
const CLOSING_TIME_DEFAULT_GRACE_ACTIONS := 1
const CLOSING_TIME_PHASE_GRACE := "grace"
const CLOSING_TIME_PHASE_FORCED_TRAVEL := "forced_travel"
const HOME_SELECTION_RANDOM := "random"
const HOME_TENURE_RENT := "rent"
const HOME_TENURE_STAY := "stay"
const HOME_SLEEP_MIN_HOURS := 4
const HOME_SLEEP_MAX_HOURS := 8
const HOME_SLEEP_HEAT_RECOVERY_PER_HOUR := 2
const HOME_SLEEP_DRUNK_RECOVERY_PER_HOUR := 10
const CREW_LENDER_ID := "the_crew"
const CREW_MAX_LOAN_LOCATIONS := 3
const LENDER_REPAY_HEAT_REDUCTION := 3
const SALS_PAWN_COUNTER_ID := "sals_pawn_counter"
const PAWN_SHOP_ARCHETYPE_ID := "pawn_shop"
const PULL_TAB_PILE_ITEM_ID := "pile_of_pull_tabs"
const SCRATCH_TICKET_PILE_ITEM_ID := "pile_of_scratch_tickets"
const PORTABLE_TICKET_KINDS := ["pull_tabs", "scratch_tickets"]
const PORTABLE_TICKET_ITEM_IDS := {
	"pull_tabs": PULL_TAB_PILE_ITEM_ID,
	"scratch_tickets": SCRATCH_TICKET_PILE_ITEM_ID,
}
const PORTABLE_TICKET_PLAYER_FIELDS := {
	"pull_tabs": ["tray_stack", "ticket_stack", "winner_pile", "loser_pile"],
	"scratch_tickets": ["active_ticket", "winner_pile", "loser_pile", "pending_penalty", "penalty_shields_remaining", "last_settled_ticket", "last_settled_pile", "last_file_id", "file_started_msec"],
}

var seed_text: String = ""
var seed_value: int = 1
var rng_seed: int = 1
var rng_state: int = 1
var challenge_config: Dictionary = {}
var bankroll: int = DEFAULT_BANKROLL
var grand_casino_chips: int = 0
var economic_state: String = "stable"
var inventory: Array = []
var portable_ticket_piles: Dictionary = {}
var active_item_id: String = ""
var debt: Array = []
var sals_forfeited_item_ids: Array = []
var suspicion: Dictionary = {}
var baseline_luck: int = 0
var drunk_level: int = 0
var alcoholic_level: int = 0
var pending_drunk_absorption: Array = []
var drunk_distortion_suppression_turns: int = 0
var current_environment: Dictionary = {}
var world_map: Dictionary = {}
var grand_casino_room_states: Dictionary = {}
var grand_casino_staffing: Dictionary = {}
var rourke_current_room: String = ""
var rourke_current_spot: String = ""
var rourke_facing: String = "right"
var rourke_actions_until_move: int = ROURKE_MOVE_EVALUATION_ACTIONS
var rourke_off_floor_actions: int = 0
var rourke_floor_action_index: int = 0
var grand_casino_room_heat_accumulators: Dictionary = {}
var rival_cheaters: Array = []
var rival_cheater_day: int = 0
var rourke_escort_state: Dictionary = {}
var pending_triggered_events: Array = []
var pending_bags: Array = []
var active_triggered_event: Dictionary = {}
var event_cadence: Dictionary = {}
var music_arrangement_state: Dictionary = {}
var music_tempo_state: Dictionary = {}
var music_choreography_state: Dictionary = {}
var environment_history: Array = []
var environment_history_archive_count: int = 0
var unlocked_travel: Array = []
var narrative_flags: Dictionary = {}
var story_flags: Dictionary = {}
var story_log: Array = []
var story_log_archive_count: int = 0
var heat_history: Array = []
var simulation_msec: int = 0
var game_clock_minutes: int = GAME_CLOCK_START_MINUTE
var closing_time_state: Dictionary = {}
var act_index: int = 0
var home_state: Dictionary = {}
var run_status: String = RUN_STATUS_ACTIVE
var run_failure_reason: String = FAILURE_NONE
var run_failure_message: String = ""
var run_spending_score: int = 0
var defer_next_bankroll_zero_failure: bool = false
var _item_effects_by_id: Dictionary = {}
var _item_effects_loaded: bool = false
var _item_definitions_by_id: Dictionary = {}
var _item_definitions_loaded: bool = false


# Resets the run from a seed and optional challenge.
func start_new(p_seed_text: String = "FOUNDATION-SEED", p_challenge_config: Dictionary = {}) -> void:
	challenge_config = normalize_challenge(p_seed_text, p_challenge_config)
	seed_text = str(challenge_config.get("seed_text", "FOUNDATION-SEED"))
	seed_value = text_to_seed(challenge_key(challenge_config))
	rng_seed = seed_value
	rng_state = seed_value
	bankroll = DEFAULT_BANKROLL
	grand_casino_chips = 0
	economic_state = "stable"
	inventory = []
	portable_ticket_piles = {}
	active_item_id = ""
	debt = []
	sals_forfeited_item_ids = []
	suspicion = {
		"level": 0,
		"cues": [],
		"local_levels": {},
	}
	baseline_luck = 0
	drunk_level = 0
	alcoholic_level = 0
	pending_drunk_absorption = []
	drunk_distortion_suppression_turns = 0
	current_environment = {}
	world_map = {}
	grand_casino_room_states = {}
	grand_casino_staffing = {}
	rourke_current_room = ""
	rourke_current_spot = ""
	rourke_facing = "right"
	rourke_actions_until_move = ROURKE_MOVE_EVALUATION_ACTIONS
	rourke_off_floor_actions = 0
	rourke_floor_action_index = 0
	grand_casino_room_heat_accumulators = _empty_grand_casino_room_heat_accumulators()
	rival_cheaters = []
	rival_cheater_day = 0
	rourke_escort_state = {}
	pending_triggered_events = []
	pending_bags = []
	active_triggered_event = {}
	_reset_event_cadence_state()
	music_arrangement_state = {}
	music_tempo_state = {}
	music_choreography_state = {}
	environment_history = []
	environment_history_archive_count = 0
	unlocked_travel = []
	narrative_flags = {}
	story_flags = {}
	story_log = []
	story_log_archive_count = 0
	heat_history = []
	simulation_msec = 0
	game_clock_minutes = GAME_CLOCK_START_MINUTE
	closing_time_state = {}
	act_index = 0
	home_state = {}
	run_status = RUN_STATUS_ACTIVE
	run_failure_reason = FAILURE_NONE
	run_failure_message = ""
	run_spending_score = 0
	defer_next_bankroll_zero_failure = false
	_apply_starting_challenge_modifiers()
	if is_tutorial_run():
		narrative_flags["tutorial_active"] = true
		narrative_flags["tutorial_beat"] = 1
	_record_heat_history(false)


# Creates an RNG stream from the saved run RNG state.
func create_rng(stream_key: String = "") -> RngStream:
	var rng := RngStream.new()
	rng.configure(rng_seed, rng_state)
	if not stream_key.is_empty():
		return rng.fork(stream_key)
	return rng


# Saves an RNG stream back into the run.
func save_rng(rng: RngStream) -> void:
	if rng == null:
		return
	rng_seed = rng.seed_value
	rng_state = rng.state_value


# Records the active act entry point. Future act transition rules should call
# this before re-homing the player; this release only starts Act 1 here.
func begin_act(p_act_index: int) -> void:
	act_index = maxi(1, p_act_index)
	if home_state.is_empty():
		home_state = {"act_index": act_index}
	else:
		home_state["act_index"] = act_index


func act_marker() -> int:
	return maxi(1, act_index)


func act_two_seam_payload() -> Dictionary:
	if run_status != RUN_STATUS_ENDED or not bool(narrative_flags.get("demo_victory", false)):
		return {}
	var demo_route := str(narrative_flags.get("demo_victory_route", "")).strip_edges()
	var seam_route := _act_seam_route(demo_route)
	if seam_route.is_empty():
		return {}
	return {
		"schema_version": 1,
		"source_act": act_marker(),
		"target_act": 2,
		"victory_route": seam_route,
		"demo_victory_route": demo_route,
		"final_bankroll_band": act_seam_bankroll_band(bankroll),
		"story_flags": story_flags.duplicate(true),
		"route_payload": _act_seam_route_payload(seam_route),
	}


static func act_seam_bankroll_band(bankroll_value: int) -> String:
	if bankroll_value < 50:
		return "empty_pockets"
	if bankroll_value < 150:
		return "walking_money"
	if bankroll_value < 400:
		return "solid_winnings"
	if bankroll_value < 800:
		return "heavy_envelope"
	return "house_money"


func _act_seam_route(demo_route: String) -> String:
	if demo_route == GRAND_CASINO_HIGH_ROLLER_EVENT_ID:
		return "players_card_cashout"
	if demo_route == GRAND_CASINO_SHOWDOWN_ROUTE:
		return "showdown"
	return ""


func _act_seam_route_payload(seam_route: String) -> Dictionary:
	match seam_route:
		"players_card_cashout":
			return {
				"hook": "players_card_open_rooms",
				"house_attention": "valued_guest",
				"tone": "invited",
			}
		"showdown":
			return {
				"hook": "rourke_remembers",
				"house_attention": "watched_exit",
				"tone": "marked",
			}
		_:
			return {}


func selected_home_archetype_id() -> String:
	var selection := str(challenge_modifiers().get("home_archetype_id", HOME_SELECTION_RANDOM)).strip_edges()
	if selection.is_empty():
		return HOME_SELECTION_RANDOM
	return selection


func initialize_home_from_profile(home_archetype: Dictionary, node_id: String, profile: Dictionary) -> void:
	var home_id := str(home_archetype.get("id", "")).strip_edges()
	var home_node_id := node_id.strip_edges()
	if home_node_id.is_empty():
		home_node_id = home_id
	if home_id.is_empty() or home_node_id.is_empty():
		return
	var current_day := game_day()
	var tenure_profile := _copy_dict(profile.get("tenure", {}))
	var tenure_type := str(tenure_profile.get("type", "")).strip_edges().to_lower()
	var tenure: Dictionary = {}
	if tenure_type == HOME_TENURE_STAY:
		tenure = {
			"type": HOME_TENURE_STAY,
			"days_remaining": maxi(0, int(tenure_profile.get("prepaid_days", tenure_profile.get("days_remaining", 3)))),
			"renewal_cost": maxi(0, int(tenure_profile.get("renewal_cost", 45))),
			"renewal_days": maxi(1, int(tenure_profile.get("renewal_days", 1))),
			"expiry_message": str(tenure_profile.get("expiry_message", "")),
		}
	else:
		var first_due_in_days := maxi(0, int(tenure_profile.get("first_due_in_days", tenure_profile.get("due_in_days", 7))))
		var payment_label := str(tenure_profile.get("payment_label", "rent")).strip_edges().to_lower()
		if payment_label.is_empty():
			payment_label = "rent"
		var action_label := str(tenure_profile.get("action_label", "Pay %s" % payment_label.capitalize())).strip_edges()
		if action_label.is_empty():
			action_label = "Pay %s" % payment_label.capitalize()
		tenure = {
			"type": HOME_TENURE_RENT,
			"rent_amount": maxi(0, int(tenure_profile.get("rent_amount", 90))),
			"due_day": current_day + first_due_in_days,
			"cycle_days": maxi(1, int(tenure_profile.get("cycle_days", 7))),
			"grace_days": maxi(0, int(tenure_profile.get("grace_days", 3))),
			"payment_label": payment_label,
			"action_label": action_label,
			"eviction_message": str(tenure_profile.get("eviction_message", "")),
		}
	var home_display_name := str(home_archetype.get("display_name", "")).strip_edges()
	if home_display_name.is_empty():
		var name_nouns := _string_array(_copy_array(home_archetype.get("name_nouns", [])))
		home_display_name = str(name_nouns[0]) if not name_nouns.is_empty() else home_id.replace("_", " ").capitalize()
	home_state = _normalize_home_state({
		"active": true,
		"lost": false,
		"act_index": maxi(1, act_index),
		"home_archetype_id": home_id,
		"home_node_id": home_node_id,
		"display_name": home_display_name,
		"started_day": current_day,
		"lost_day": 0,
		"lost_reason": "",
		"tenure": tenure,
	})


func game_day() -> int:
	return maxi(1, int(floor(float(maxi(0, game_clock_minutes)) / 1440.0)) + 1)


func game_minute_of_day() -> int:
	return maxi(0, game_clock_minutes) % 1440


func clock_display_text(include_day: bool = true) -> String:
	var minute_of_day := game_minute_of_day()
	var hour_24 := int(floor(float(minute_of_day) / 60.0)) % 24
	var hour_12 := hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	var suffix := "AM" if hour_24 < 12 else "PM"
	var time_text := "%d %s" % [hour_12, suffix]
	if include_day:
		return "Day %d %s" % [game_day(), time_text]
	return time_text


func advance_game_clock_minutes(amount: int) -> void:
	if amount <= 0 or is_terminal():
		return
	var previous_day := game_day()
	game_clock_minutes = maxi(0, game_clock_minutes + amount)
	var next_day := game_day()
	if next_day > previous_day:
		_advance_grand_casino_staff_day_rollovers(previous_day, next_day)
		_advance_home_day_rollovers(previous_day, next_day)


func advance_action_clock(amount: int = 1) -> void:
	var actions := maxi(0, amount)
	if actions <= 0:
		return
	advance_game_clock_minutes(actions * ACTION_CLOCK_MINUTES)


func closing_time_status() -> Dictionary:
	return _normalize_closing_time_state(closing_time_state)


func closing_time_active() -> bool:
	return not closing_time_state.is_empty() and not str(closing_time_state.get("phase", "")).is_empty()


func closing_time_forced_travel_required() -> bool:
	return str(closing_time_state.get("phase", "")) == CLOSING_TIME_PHASE_FORCED_TRAVEL


func closing_time_environment_id() -> String:
	return str(closing_time_state.get("environment_id", "")).strip_edges()


func begin_closing_time(environment_data: Dictionary, current_minute: int, grace_actions: int = CLOSING_TIME_DEFAULT_GRACE_ACTIONS) -> Dictionary:
	var environment_id := str(environment_data.get("id", environment_data.get("world_node_id", environment_data.get("archetype_id", "")))).strip_edges()
	var display_name := str(environment_data.get("display_name", environment_id.replace("_", " ").capitalize()))
	closing_time_state = _normalize_closing_time_state({
		"phase": CLOSING_TIME_PHASE_GRACE,
		"environment_id": environment_id,
		"world_node_id": str(environment_data.get("world_node_id", environment_data.get("archetype_id", ""))).strip_edges(),
		"archetype_id": str(environment_data.get("archetype_id", environment_id)).strip_edges(),
		"display_name": display_name,
		"started_game_clock_minutes": maxi(0, game_clock_minutes),
		"started_minute_of_day": clampi(current_minute, 0, EnvironmentHours.MINUTES_PER_DAY - 1),
		"grace_actions_remaining": maxi(0, grace_actions),
		"message": "%s is closing." % display_name,
	})
	return closing_time_state.duplicate(true)


func spend_closing_time_grace_action() -> Dictionary:
	if closing_time_state.is_empty():
		return {}
	var state := _normalize_closing_time_state(closing_time_state)
	var remaining := maxi(0, int(state.get("grace_actions_remaining", 0)))
	if remaining > 0:
		remaining -= 1
	state["grace_actions_remaining"] = remaining
	if remaining <= 0:
		state["phase"] = CLOSING_TIME_PHASE_FORCED_TRAVEL
		state["message"] = "%s is closed. Choose a route out." % str(state.get("display_name", "This venue"))
	closing_time_state = state
	return state.duplicate(true)


func force_closing_time_travel() -> Dictionary:
	if closing_time_state.is_empty():
		return {}
	var state := _normalize_closing_time_state(closing_time_state)
	state["grace_actions_remaining"] = 0
	state["phase"] = CLOSING_TIME_PHASE_FORCED_TRAVEL
	state["message"] = "%s is closed. Choose a route out." % str(state.get("display_name", "This venue"))
	closing_time_state = state
	return state.duplicate(true)


func clear_closing_time_state() -> void:
	closing_time_state = {}


func home_is_active() -> bool:
	return not home_state.is_empty() and bool(home_state.get("active", false)) and not bool(home_state.get("lost", false))


func is_current_home_environment() -> bool:
	if current_environment.is_empty() or str(current_environment.get("kind", "")) != "home":
		return false
	if not home_is_active():
		return false
	var node_id := str(current_environment.get("world_node_id", current_environment.get("archetype_id", ""))).strip_edges()
	var home_node_id := str(home_state.get("home_node_id", "")).strip_edges()
	return home_node_id.is_empty() or node_id == home_node_id


func sleep_at_home() -> Dictionary:
	if is_terminal():
		return {"ok": false, "message": "This run is already over."}
	if not is_current_home_environment():
		return {"ok": false, "message": "You need to be home to sleep."}
	var rng := create_rng()
	var hours := rng.randi_range(HOME_SLEEP_MIN_HOURS, HOME_SLEEP_MAX_HOURS)
	save_rng(rng)
	var minutes := hours * 60
	var heat_before := suspicion_level()
	var drunk_before := drunk_level
	var pending_drunk_before := pending_drunk_absorption_amount()
	if pending_drunk_before > 0:
		change_pending_drunk_absorption(-pending_drunk_before)
	var heat_recovery := mini(heat_before, hours * HOME_SLEEP_HEAT_RECOVERY_PER_HOUR)
	if heat_recovery > 0:
		add_suspicion("home_sleep", -heat_recovery, "recovery", true, {
			"environment_id": str(current_environment.get("id", "")),
			"environment_archetype_id": str(current_environment.get("archetype_id", "")),
		})
	var drunk_recovery := mini(drunk_level, hours * HOME_SLEEP_DRUNK_RECOVERY_PER_HOUR)
	if drunk_recovery > 0:
		change_drunk(-drunk_recovery)
	advance_game_clock_minutes(minutes)
	var heat_after := suspicion_level()
	var drunk_after := drunk_level
	var message := "You sleep for %d hours and wake with a clearer head." % hours
	log_story({
		"type": "home_sleep",
		"hours": hours,
		"minutes": minutes,
		"heat_delta": heat_after - heat_before,
		"drunk_delta": drunk_after - drunk_before,
		"pending_drunk_cleared": pending_drunk_before,
		"game_clock_minutes": game_clock_minutes,
		"environment_id": str(current_environment.get("id", "")),
		"message": message,
	})
	return {
		"ok": true,
		"type": "home_sleep",
		"hours": hours,
		"minutes": minutes,
		"heat_before": heat_before,
		"heat_after": heat_after,
		"heat_delta": heat_after - heat_before,
		"drunk_before": drunk_before,
		"drunk_after": drunk_after,
		"drunk_delta": drunk_after - drunk_before,
		"pending_drunk_cleared": pending_drunk_before,
		"message": message,
	}


func home_status_summary() -> String:
	if home_state.is_empty():
		return "No home clock."
	if bool(home_state.get("lost", false)):
		return "Home lost on day %d." % maxi(1, int(home_state.get("lost_day", game_day())))
	var name := str(home_state.get("display_name", "Home"))
	var tenure := _copy_dict(home_state.get("tenure", {}))
	var tenure_type := str(tenure.get("type", "")).strip_edges()
	if tenure_type == HOME_TENURE_STAY:
		var days_remaining := maxi(0, int(tenure.get("days_remaining", 0)))
		var day_word := "day" if days_remaining == 1 else "days"
		return "%s: %d prepaid %s left." % [name, days_remaining, day_word]
	if tenure_type == HOME_TENURE_RENT:
		var status := home_tenure_status()
		var rent_amount := int(status.get("amount", tenure.get("rent_amount", 0)))
		var payment_label := str(status.get("payment_label", tenure.get("payment_label", "rent"))).strip_edges().to_lower()
		if payment_label.is_empty():
			payment_label = "rent"
		if bool(status.get("due", false)):
			if bool(status.get("overdue", false)):
				return "%s: %s $%d overdue, %d grace day(s) left." % [name, payment_label, rent_amount, int(status.get("grace_remaining", 0))]
			return "%s: %s $%d due today." % [name, payment_label, rent_amount]
		return "%s: %s $%d due day %d." % [name, payment_label, rent_amount, int(status.get("due_day", game_day()))]
	return "%s: tenure active." % name


func home_tenure_status() -> Dictionary:
	if home_state.is_empty():
		return {"active": false, "summary": "No home."}
	var state := _normalize_home_state(home_state)
	var tenure := _copy_dict(state.get("tenure", {}))
	var tenure_type := str(tenure.get("type", "")).strip_edges()
	var current_day := game_day()
	if bool(state.get("lost", false)) or not bool(state.get("active", false)):
		return {
			"active": false,
			"lost": true,
			"summary": "Home access is lost.",
		}
	if tenure_type == HOME_TENURE_STAY:
		var days_remaining := maxi(0, int(tenure.get("days_remaining", 0)))
		var day_word := "day" if days_remaining == 1 else "days"
		return {
			"active": true,
			"type": HOME_TENURE_STAY,
			"days_remaining": days_remaining,
			"renewal_cost": maxi(0, int(tenure.get("renewal_cost", 0))),
			"renewal_days": maxi(1, int(tenure.get("renewal_days", 1))),
			"due": days_remaining <= 1,
			"overdue": days_remaining <= 0,
			"summary": "%s: %d prepaid %s left." % [str(state.get("display_name", "Home")), days_remaining, day_word],
		}
	var due_day := maxi(1, int(tenure.get("due_day", current_day)))
	var grace_days := maxi(0, int(tenure.get("grace_days", 0)))
	var overdue_days := maxi(0, current_day - due_day)
	var due := current_day >= due_day
	var rent_amount := maxi(0, int(tenure.get("rent_amount", 0)))
	var payment_label := str(tenure.get("payment_label", "rent")).strip_edges().to_lower()
	if payment_label.is_empty():
		payment_label = "rent"
	var action_label := str(tenure.get("action_label", "Pay %s" % payment_label.capitalize())).strip_edges()
	if action_label.is_empty():
		action_label = "Pay %s" % payment_label.capitalize()
	var summary := "%s: %s $%d due day %d." % [str(state.get("display_name", "Home")), payment_label, rent_amount, due_day]
	if due:
		summary = "%s: %s $%d due today." % [str(state.get("display_name", "Home")), payment_label, rent_amount]
	if overdue_days > 0:
		summary = "%s: %s $%d overdue, %d grace day(s) left." % [str(state.get("display_name", "Home")), payment_label, rent_amount, maxi(0, grace_days - overdue_days)]
	return {
		"active": true,
		"type": HOME_TENURE_RENT,
		"amount": rent_amount,
		"payment_label": payment_label,
		"action_label": action_label,
		"due_day": due_day,
		"cycle_days": maxi(1, int(tenure.get("cycle_days", 1))),
		"grace_days": grace_days,
		"due": due,
		"overdue": overdue_days > 0,
		"overdue_days": overdue_days,
		"grace_remaining": maxi(0, grace_days - overdue_days),
		"eviction_day": due_day + grace_days + 1,
		"summary": summary,
	}


func home_tenure_action_status() -> Dictionary:
	var status := home_tenure_status()
	if not bool(status.get("active", false)) or not is_current_home_environment():
		return {"available": false, "enabled": false, "label": "Home", "disabled_reason": "No active home tenure here."}
	var tenure_type := str(status.get("type", ""))
	if tenure_type == HOME_TENURE_STAY:
		var renewal_cost := maxi(0, int(status.get("renewal_cost", 0)))
		var enabled := bankroll >= renewal_cost
		return {
			"available": true,
			"enabled": enabled,
			"type": HOME_TENURE_STAY,
			"label": "Renew Stay",
			"cost": renewal_cost,
			"disabled_reason": "" if enabled else "Need $%d to renew the room." % renewal_cost,
		}
	if tenure_type == HOME_TENURE_RENT:
		var payment_label := str(status.get("payment_label", "rent")).strip_edges().to_lower()
		if payment_label.is_empty():
			payment_label = "rent"
		var action_label := str(status.get("action_label", "Pay %s" % payment_label.capitalize())).strip_edges()
		if action_label.is_empty():
			action_label = "Pay %s" % payment_label.capitalize()
		if not bool(status.get("due", false)):
			return {
				"available": false,
				"enabled": false,
				"type": HOME_TENURE_RENT,
				"label": action_label,
				"payment_label": payment_label,
				"cost": int(status.get("amount", 0)),
				"disabled_reason": "%s is not due until day %d." % [payment_label.capitalize(), int(status.get("due_day", game_day()))],
			}
		var amount := maxi(0, int(status.get("amount", 0)))
		var enabled := bankroll >= amount
		return {
			"available": true,
			"enabled": enabled,
			"type": HOME_TENURE_RENT,
			"label": action_label,
			"payment_label": payment_label,
			"cost": amount,
			"disabled_reason": "" if enabled else "Need $%d to pay %s." % [amount, payment_label],
		}
	return {"available": false, "enabled": false, "label": "Home", "disabled_reason": "Home tenure is not configured."}


func pay_home_tenure() -> Dictionary:
	var action := home_tenure_action_status()
	if not bool(action.get("available", false)):
		return {"ok": false, "message": str(action.get("disabled_reason", "No payment is due."))}
	if not bool(action.get("enabled", false)):
		return {"ok": false, "message": str(action.get("disabled_reason", "Not enough bankroll."))}
	var tenure := _copy_dict(home_state.get("tenure", {}))
	var action_type := str(action.get("type", ""))
	var cost := maxi(0, int(action.get("cost", 0)))
	if cost > 0:
		change_bankroll(-cost, true)
		run_spending_score = maxi(0, run_spending_score + cost)
	var message := ""
	if action_type == HOME_TENURE_STAY:
		var added_days := maxi(1, int(tenure.get("renewal_days", 1)))
		tenure["days_remaining"] = maxi(0, int(tenure.get("days_remaining", 0))) + added_days
		home_state["tenure"] = tenure
		message = "Renewed the room for %d more day(s)." % added_days
	elif action_type == HOME_TENURE_RENT:
		var cycle_days := maxi(1, int(tenure.get("cycle_days", 1)))
		tenure["due_day"] = game_day() + cycle_days
		home_state["tenure"] = tenure
		var payment_label := str(action.get("payment_label", tenure.get("payment_label", "rent"))).strip_edges().to_lower()
		if payment_label.is_empty():
			payment_label = "rent"
		message = "Paid %s. Next due day %d." % [payment_label, int(tenure.get("due_day", game_day()))]
	else:
		return {"ok": false, "message": "Home payment is not configured."}
	log_story({
		"type": "home_tenure_payment",
		"home_archetype_id": str(home_state.get("home_archetype_id", "")),
		"amount": cost,
		"day": game_day(),
		"message": message,
	})
	return {"ok": true, "message": message, "bankroll_delta": -cost}


func current_home_containers() -> Array:
	if current_environment.is_empty():
		return []
	return _normalize_home_containers(_copy_array(current_environment.get("home_containers", [])))


func place_home_container(item_id: String, display_name: String, capacity: int) -> Dictionary:
	var clean_item_id := item_id.strip_edges()
	if clean_item_id.is_empty() or capacity <= 0:
		return {"ok": false, "message": "Container item is not configured."}
	if not is_current_home_environment():
		return {"ok": false, "message": "Containers can only be placed at your home."}
	if not inventory.has(clean_item_id):
		return {"ok": false, "message": "That container is not in your inventory."}
	var containers := current_home_containers()
	var container_id := _next_home_container_id(containers, clean_item_id)
	remove_item(clean_item_id)
	containers.append({
		"id": container_id,
		"item_id": clean_item_id,
		"display_name": display_name if not display_name.strip_edges().is_empty() else clean_item_id.replace("_", " ").capitalize(),
		"capacity": maxi(1, capacity),
		"items": [],
	})
	_set_current_home_containers(containers)
	var message := "Placed %s at home." % str(display_name if not display_name.strip_edges().is_empty() else clean_item_id.replace("_", " ").capitalize())
	log_story({
		"type": "home_container_placed",
		"container_id": container_id,
		"item_id": clean_item_id,
		"day": game_day(),
		"message": message,
	})
	return {"ok": true, "message": message, "container_id": container_id}


func transfer_item_to_home_container(container_id: String, item_id: String) -> Dictionary:
	var clean_container_id := container_id.strip_edges()
	var clean_item_id := item_id.strip_edges()
	if clean_container_id.is_empty() or clean_item_id.is_empty():
		return {"ok": false, "message": "Storage transfer is not configured."}
	if not is_current_home_environment():
		return {"ok": false, "message": "Home storage is not available here."}
	if not inventory.has(clean_item_id):
		return {"ok": false, "message": "That item is not in your inventory."}
	var containers := current_home_containers()
	var index := _home_container_index(containers, clean_container_id)
	if index < 0:
		return {"ok": false, "message": "Container is no longer available."}
	var container: Dictionary = containers[index]
	if bool(container.get("meta_loadout", false)):
		return {"ok": false, "message": "Meta-home loadout bags mirror the items already packed for this run."}
	var stored_items := _copy_array(container.get("items", []))
	var capacity := maxi(0, int(container.get("capacity", 0)))
	if stored_items.size() >= capacity:
		return {"ok": false, "message": "%s is full." % str(container.get("display_name", "Container"))}
	remove_item(clean_item_id)
	stored_items.append(clean_item_id)
	container["items"] = stored_items
	containers[index] = container
	_set_current_home_containers(containers)
	var message := "Stored %s in %s." % [clean_item_id.replace("_", " ").capitalize(), str(container.get("display_name", "Container"))]
	return {"ok": true, "message": message, "container_id": clean_container_id, "item_id": clean_item_id}


func transfer_item_from_home_container(container_id: String, item_id: String) -> Dictionary:
	var clean_container_id := container_id.strip_edges()
	var clean_item_id := item_id.strip_edges()
	if clean_container_id.is_empty() or clean_item_id.is_empty():
		return {"ok": false, "message": "Storage transfer is not configured."}
	if not is_current_home_environment():
		return {"ok": false, "message": "Home storage is not available here."}
	if inventory.has(clean_item_id):
		return {"ok": false, "message": "You already carry %s." % clean_item_id.replace("_", " ").capitalize()}
	var containers := current_home_containers()
	var index := _home_container_index(containers, clean_container_id)
	if index < 0:
		return {"ok": false, "message": "Container is no longer available."}
	var container: Dictionary = containers[index]
	if bool(container.get("meta_loadout", false)):
		return {"ok": false, "message": "These items are already carried from the meta-home loadout."}
	var stored_items := _copy_array(container.get("items", []))
	if not stored_items.has(clean_item_id):
		return {"ok": false, "message": "That item is not stored here."}
	stored_items.erase(clean_item_id)
	container["items"] = stored_items
	containers[index] = container
	add_item(clean_item_id)
	_set_current_home_containers(containers)
	var message := "Took %s from %s." % [clean_item_id.replace("_", " ").capitalize(), str(container.get("display_name", "Container"))]
	return {"ok": true, "message": message, "container_id": clean_container_id, "item_id": clean_item_id}


func lose_home(reason: String = "lost") -> Dictionary:
	if home_state.is_empty() or bool(home_state.get("lost", false)):
		return {"ok": false, "message": "Home access is already gone."}
	var clean_reason := reason.strip_edges()
	if clean_reason.is_empty():
		clean_reason = "lost"
	var home_node_id := str(home_state.get("home_node_id", "")).strip_edges()
	home_state["active"] = false
	home_state["lost"] = true
	home_state["lost_reason"] = clean_reason
	home_state["lost_day"] = game_day()
	narrative_flags["home_lost"] = true
	narrative_flags["home_lost_reason"] = clean_reason
	if is_current_home_environment():
		current_environment["home_containers"] = []
		current_environment["home_lost"] = true
		current_environment["layout"] = EnvironmentInstance.ensure_generated_layout(current_environment)
	if not world_map.is_empty() and not home_node_id.is_empty():
		world_map = WorldMap.mark_home_lost(world_map, home_node_id)
	var message := "Your home access is gone. Anything stored there is lost."
	log_story({
		"type": "home_lost",
		"home_node_id": home_node_id,
		"reason": clean_reason,
		"day": game_day(),
		"message": message,
	})
	return {"ok": true, "message": message}


func _advance_home_day_rollovers(previous_day: int, next_day: int) -> void:
	if previous_day >= next_day or not home_is_active():
		return
	for day in range(previous_day + 1, next_day + 1):
		_advance_home_for_day(day)
		if not home_is_active():
			return


func _advance_home_for_day(current_day: int) -> void:
	var tenure := _copy_dict(home_state.get("tenure", {}))
	var tenure_type := str(tenure.get("type", "")).strip_edges()
	if tenure_type == HOME_TENURE_STAY:
		var days_remaining := maxi(0, int(tenure.get("days_remaining", 0)) - 1)
		tenure["days_remaining"] = days_remaining
		home_state["tenure"] = tenure
		if days_remaining <= 0:
			lose_home("stay_expired")
	elif tenure_type == HOME_TENURE_RENT:
		var due_day := maxi(1, int(tenure.get("due_day", current_day)))
		var grace_days := maxi(0, int(tenure.get("grace_days", 0)))
		if current_day > due_day + grace_days:
			lose_home("evicted")


func _set_current_home_containers(containers: Array) -> void:
	current_environment["home_containers"] = _normalize_home_containers(containers)
	current_environment["layout"] = EnvironmentInstance.ensure_generated_layout(current_environment)
	store_current_world_node_environment()


func _next_home_container_id(containers: Array, item_id: String) -> String:
	var next_index := maxi(1, int(current_environment.get("home_container_index", 0)) + 1)
	var existing: Dictionary = {}
	for container_value in containers:
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		var container: Dictionary = container_value
		var existing_id := str(container.get("id", "")).strip_edges()
		if not existing_id.is_empty():
			existing[existing_id] = true
	while true:
		var candidate := "%s_%02d" % [item_id, next_index]
		if not existing.has(candidate):
			current_environment["home_container_index"] = next_index
			return candidate
		next_index += 1
	return "%s_%02d" % [item_id, next_index]


func _home_container_index(containers: Array, container_id: String) -> int:
	for index in range(containers.size()):
		if typeof(containers[index]) != TYPE_DICTIONARY:
			continue
		var container: Dictionary = containers[index]
		if str(container.get("id", "")) == container_id:
			return index
	return -1


# Returns the deterministic simulation clock used by gameplay systems.
func simulation_time_msec() -> int:
	return maxi(0, simulation_msec)


# Creates the saved RNG stream reserved for world-event cadence decisions.
func create_event_cadence_rng() -> RngStream:
	_ensure_event_cadence()
	var rng := RngStream.new()
	rng.configure(int(event_cadence.get("rng_seed", seed_value)), int(event_cadence.get("rng_state", seed_value)))
	return rng


# Saves the cadence stream without advancing the general run RNG.
func save_event_cadence_rng(rng: RngStream) -> void:
	if rng == null:
		return
	_ensure_event_cadence()
	event_cadence["rng_seed"] = rng.seed_value
	event_cadence["rng_state"] = rng.state_value


# Starts a new visit budget and quiet/event roll for the current room.
func event_cadence_begin_visit(environment_data: Dictionary) -> void:
	_ensure_event_cadence()
	var visit_key := _event_cadence_visit_key(environment_data)
	if visit_key.is_empty() or visit_key == str(event_cadence.get("visit_key", "")):
		return
	var rng := create_event_cadence_rng()
	var fires_this_visit := rng.randi_range(1, 100) <= EVENT_CADENCE_VISIT_EVENT_CHANCE_PERCENT
	var action_index := int(event_cadence.get("action_index", 0))
	event_cadence["visit_key"] = visit_key
	event_cadence["visit_should_fire"] = fires_this_visit
	event_cadence["visit_min_action"] = action_index + rng.randi_range(1, 3)
	event_cadence["visit_event_count"] = 0
	event_cadence["visit_event_ids"] = []
	event_cadence["visit_count"] = int(event_cadence.get("visit_count", 0)) + 1
	if not fires_this_visit:
		event_cadence["quiet_visit_count"] = int(event_cadence.get("quiet_visit_count", 0)) + 1
	save_event_cadence_rng(rng)


# Advances the cadence action clock alongside player-facing room actions.
func event_cadence_advance_actions(amount: int = 1) -> void:
	_ensure_event_cadence()
	event_cadence["action_index"] = maxi(0, int(event_cadence.get("action_index", 0)) + maxi(0, amount))


# Returns whether a world-initiated event can be queued under the room budget.
func event_cadence_allows_world_event(event_id: String, trigger_type: String, source: String, event_definition: Dictionary = {}) -> bool:
	_ensure_event_cadence()
	var cadence: Dictionary = _copy_dict(event_definition.get("cadence", {}))
	if not event_cadence_can_open_modal() and not bool(cadence.get("queue_while_modal", false)):
		return false
	if event_cadence_event_bypasses_budget(event_id, trigger_type, source, event_definition):
		return true
	var action_index := int(event_cadence.get("action_index", 0))
	if not bool(event_cadence.get("visit_should_fire", false)):
		return false
	if int(event_cadence.get("visit_event_count", 0)) >= 1:
		return false
	if action_index < int(event_cadence.get("visit_min_action", 0)):
		return false
	if action_index - int(event_cadence.get("last_world_event_action", -9999)) < EVENT_CADENCE_GLOBAL_GAP_ACTIONS:
		return false
	if _copy_array(event_cadence.get("visit_event_ids", [])).has(event_id):
		return false
	return true


# Debt collectors, showdown calls, and explicit chains can jump the quiet-visit budget.
func event_cadence_event_bypasses_budget(event_id: String, trigger_type: String, source: String, event_definition: Dictionary = {}) -> bool:
	var normalized_id := event_id.strip_edges()
	var cadence: Dictionary = _copy_dict(event_definition.get("cadence", {}))
	if bool(cadence.get("bypass_budget", false)):
		return true
	if [GRAND_CASINO_SHOWDOWN_EVENT_ID, GRAND_CASINO_HIGH_ROLLER_EVENT_ID, "the_collector", "family_loan"].has(normalized_id):
		return true
	if ["event_chain", "debt", "lender", "showdown"].has(source):
		return true
	var conditions := _copy_dict(event_definition.get("conditions", {}))
	if bool(conditions.get("requires_overdue_debt", false)):
		return true
	return trigger_type == "manual" and source == "event"


# Returns lower weights for events already seen this run without forbidding them.
func event_cadence_weight_for_event(event_id: String) -> int:
	_ensure_event_cadence()
	var seen_counts := _copy_dict(event_cadence.get("seen_event_counts", {}))
	return 25 if int(seen_counts.get(event_id, 0)) > 0 else 100


# Records a queued triggered event for repeat suppression and, optionally, room budget.
func event_cadence_note_event_enqueued(event_id: String, world_budgeted: bool = true) -> void:
	var normalized_id := event_id.strip_edges()
	if normalized_id.is_empty():
		return
	_ensure_event_cadence()
	var action_index := int(event_cadence.get("action_index", 0))
	var seen_counts := _copy_dict(event_cadence.get("seen_event_counts", {}))
	seen_counts[normalized_id] = int(seen_counts.get(normalized_id, 0)) + 1
	event_cadence["seen_event_counts"] = seen_counts
	if not world_budgeted:
		return
	var visit_event_ids := _copy_array(event_cadence.get("visit_event_ids", []))
	if not visit_event_ids.has(normalized_id):
		visit_event_ids.append(normalized_id)
	event_cadence["visit_event_ids"] = visit_event_ids
	event_cadence["visit_event_count"] = int(event_cadence.get("visit_event_count", 0)) + 1
	event_cadence["last_world_event_action"] = action_index


# A closed modal must get at least one player action before another auto-popup opens.
func event_cadence_can_open_modal() -> bool:
	_ensure_event_cadence()
	var action_index := int(event_cadence.get("action_index", 0))
	var last_closed := int(event_cadence.get("last_modal_closed_action", -9999))
	return action_index - last_closed >= EVENT_CADENCE_BREATHER_ACTIONS


func event_cadence_note_modal_closed() -> void:
	_ensure_event_cadence()
	event_cadence["last_modal_closed_action"] = int(event_cadence.get("action_index", 0))


func event_cadence_summary() -> Dictionary:
	_ensure_event_cadence()
	return {
		"action_index": int(event_cadence.get("action_index", 0)),
		"visit_key": str(event_cadence.get("visit_key", "")),
		"visit_should_fire": bool(event_cadence.get("visit_should_fire", false)),
		"visit_event_count": int(event_cadence.get("visit_event_count", 0)),
		"quiet_visit_count": int(event_cadence.get("quiet_visit_count", 0)),
		"visit_count": int(event_cadence.get("visit_count", 0)),
		"last_world_event_action": int(event_cadence.get("last_world_event_action", -9999)),
	}


func _ensure_event_cadence() -> void:
	if event_cadence.is_empty():
		_reset_event_cadence_state()
		return
	event_cadence = _normalize_event_cadence(event_cadence)


func _reset_event_cadence_state() -> void:
	var base_rng := RngStream.new()
	base_rng.configure(seed_value, seed_value)
	var cadence_rng := base_rng.fork("event_cadence")
	event_cadence = {
		"rng_seed": cadence_rng.seed_value,
		"rng_state": cadence_rng.state_value,
		"action_index": 0,
		"last_world_event_action": -9999,
		"last_modal_closed_action": -9999,
		"visit_key": "",
		"visit_should_fire": false,
		"visit_min_action": 0,
		"visit_event_count": 0,
		"visit_event_ids": [],
		"seen_event_counts": {},
		"visit_count": 0,
		"quiet_visit_count": 0,
	}


func _event_cadence_visit_key(environment_data: Dictionary) -> String:
	var environment_id := str(environment_data.get("id", "")).strip_edges()
	if environment_id.is_empty():
		environment_id = str(environment_data.get("world_node_id", environment_data.get("archetype_id", ""))).strip_edges()
	if environment_id.is_empty():
		return ""
	return "%s#%d" % [environment_id, environment_travel_count()]


# Sets the current environment and records the previous one.
func set_environment(environment_data: Dictionary) -> void:
	var previous_was_grand_casino := _is_grand_casino_environment(current_environment)
	if not current_environment.is_empty():
		capture_portable_ticket_piles_from_environment(current_environment)
		_store_current_local_suspicion()
		environment_history.append(_environment_history_entry(current_environment))
		_compact_environment_history()
	current_environment = _normalize_environment(environment_data)
	restore_portable_ticket_piles_to_environment(current_environment)
	current_environment["entered_game_clock_minutes"] = maxi(0, game_clock_minutes)
	if _is_grand_casino_environment(current_environment):
		store_grand_casino_room_environment(current_environment)
	_apply_sals_forfeited_shelf_to_current_environment()
	var next_environment := current_environment
	unlocked_travel = _unique_strings(
		_copy_array(next_environment.get("travel_hooks", [])) + _copy_array(next_environment.get("next_archetypes", []))
	)
	_activate_current_local_suspicion(false)
	_record_heat_history(true)
	if previous_was_grand_casino and not _is_grand_casino_environment(current_environment):
		_clear_grand_casino_clean_cashout_ready()
	event_cadence_begin_visit(current_environment)
	music_arrangement_state = {
		"visit_id": _event_cadence_visit_key(current_environment),
		"track_id": "",
		"recipe_id": "",
		"cursor": 0,
		"harmonic_section": "A",
		"last_phrase_event_index": -1,
		"last_phrase_event_token": "",
		"phrase_slot": 0,
		"section_history": [],
		"selected_variant_ids": {},
		"role_epochs": {},
		"selected_role_epochs": {},
	}
	music_tempo_state = {}
	music_choreography_state = {}
	_initialize_grand_casino_objective_runtime()
	_initialize_grand_casino_staffing()
	_initialize_grand_casino_living_floor()
	_queue_grand_casino_entry_cue(previous_was_grand_casino)
	_evaluate_immediate_terminal_state()


func set_world_map(map_data: Dictionary) -> void:
	world_map = WorldMap.normalize(map_data)


# Returns the compact, saveable authored-music recipe cursor for this visit.
# A different track/recipe starts a fresh cursor without consuming a phrase.
func ensure_music_arrangement_state(track_id: String, recipe_id: String, first_section: String = "A") -> Dictionary:
	var visit_id := _event_cadence_visit_key(current_environment)
	if str(music_arrangement_state.get("visit_id", "")) != visit_id \
		or str(music_arrangement_state.get("track_id", "")) != track_id \
		or str(music_arrangement_state.get("recipe_id", "")) != recipe_id:
		music_arrangement_state = {
			"visit_id": visit_id,
			"track_id": track_id,
			"recipe_id": recipe_id,
			"cursor": 0,
			"harmonic_section": first_section.strip_edges().to_upper() if not first_section.strip_edges().is_empty() else "A",
			"last_phrase_event_index": -1,
			"last_phrase_event_token": "",
			"phrase_slot": 0,
			"section_history": [],
			"selected_variant_ids": {},
			"role_epochs": {},
			"selected_role_epochs": {},
		}
	return music_arrangement_state.duplicate(true)


# Consumes one ordered phrase event. Duplicate, stale, and skipped events are
# deliberately idempotent so timing callbacks cannot move the form twice.
func advance_music_arrangement_phrase(track_id: String, recipe_id: String, sections: Array, phrase_event: Dictionary, role_policies: Dictionary = {}) -> Dictionary:
	var normalized_sections: Array[String] = []
	for section_value in sections:
		var section := str(section_value).strip_edges().to_upper()
		if not section.is_empty():
			normalized_sections.append(section)
	if normalized_sections.is_empty():
		return {"event_accepted": false}
	ensure_music_arrangement_state(track_id, recipe_id, normalized_sections[0])
	var event_index := int(phrase_event.get("phrase_event_index", phrase_event.get("index", -1)))
	var event_token := str(phrase_event.get("event_token", phrase_event.get("token", ""))).strip_edges()
	var last_index := int(music_arrangement_state.get("last_phrase_event_index", -1))
	if event_index < 0 or event_index <= last_index or event_index != last_index + 1:
		var rejected := music_arrangement_state.duplicate(true)
		rejected["event_accepted"] = false
		return rejected
	if not event_token.is_empty() and event_token == str(music_arrangement_state.get("last_phrase_event_token", "")):
		var duplicate := music_arrangement_state.duplicate(true)
		duplicate["event_accepted"] = false
		return duplicate
	var cursor := int(music_arrangement_state.get("cursor", -1)) + 1
	var section := normalized_sections[posmod(cursor, normalized_sections.size())]
	var history := _string_array(_copy_array(music_arrangement_state.get("section_history", [])))
	history.append(section)
	while history.size() > 8:
		history.pop_front()
	music_arrangement_state["cursor"] = cursor
	music_arrangement_state["harmonic_section"] = section
	music_arrangement_state["last_phrase_event_index"] = event_index
	music_arrangement_state["last_phrase_event_token"] = event_token
	music_arrangement_state["phrase_slot"] = maxi(0, int(phrase_event.get("phrase_slot", music_arrangement_state.get("phrase_slot", 0))))
	music_arrangement_state["section_history"] = history
	var role_epochs := _copy_dict(music_arrangement_state.get("role_epochs", {}))
	for role_value in role_policies.keys():
		var policy := _copy_dict(role_policies.get(role_value, {}))
		var change_every := maxi(1, int(policy.get("change_every", 1)))
		role_epochs[str(role_value)] = maxi(0, cursor) / change_every
	music_arrangement_state["role_epochs"] = role_epochs
	var accepted := music_arrangement_state.duplicate(true)
	accepted["event_accepted"] = true
	return accepted


func remember_music_arrangement_selection(track_id: String, selected_variant_ids: Dictionary, selected_role_epochs: Dictionary) -> void:
	if str(music_arrangement_state.get("track_id", "")) != track_id:
		return
	music_arrangement_state["selected_variant_ids"] = selected_variant_ids.duplicate(true)
	music_arrangement_state["selected_role_epochs"] = selected_role_epochs.duplicate(true)


func remember_music_tempo_state(state: Dictionary) -> void:
	music_tempo_state = _normalize_music_tempo_state(state)


func remember_music_choreography_state(state: Dictionary) -> void:
	music_choreography_state = _normalize_music_choreography_state(state)


func has_world_map() -> bool:
	return not world_map.is_empty()


func current_world_node_id() -> String:
	if world_map.is_empty():
		return str(current_environment.get("world_node_id", current_environment.get("archetype_id", ""))).strip_edges()
	return WorldMap.current_node_id(world_map)


func store_current_world_node_environment() -> void:
	if world_map.is_empty() or current_environment.is_empty():
		return
	var node_id := str(current_environment.get("world_node_id", current_world_node_id())).strip_edges()
	if node_id.is_empty():
		node_id = str(current_environment.get("archetype_id", "")).strip_edges()
	if node_id.is_empty():
		return
	var stored_environment := current_environment
	if _is_grand_casino_environment(current_environment):
		store_grand_casino_room_environment(current_environment)
		var main_floor := grand_casino_room_environment(GRAND_CASINO_ARCHETYPE_ID)
		if not main_floor.is_empty():
			stored_environment = main_floor
	world_map = WorldMap.store_environment(world_map, node_id, stored_environment)


func store_grand_casino_room_environment(environment: Dictionary) -> void:
	if not _is_grand_casino_environment(environment):
		return
	var archetype_id := str(environment.get("archetype_id", GRAND_CASINO_ARCHETYPE_ID)).strip_edges()
	if not GRAND_CASINO_ARCHETYPE_IDS.has(archetype_id):
		return
	# The active room is already an owned, normalized runtime dictionary. Keep
	# that reference so game-state mutations remain live without a second deep
	# copy on every environment refresh; room restoration still returns a copy.
	grand_casino_room_states[archetype_id] = environment


func grand_casino_room_environment(archetype_id: String) -> Dictionary:
	var room: Variant = grand_casino_room_states.get(archetype_id.strip_edges(), {})
	return (room as Dictionary).duplicate(true) if typeof(room) == TYPE_DICTIONARY else {}


func grand_casino_room_access_status(target_archetype_id: String, high_limit_buy_in: int = 60) -> Dictionary:
	var target_id := target_archetype_id.strip_edges()
	if not is_grand_casino_environment():
		return {"available": false, "reason": "The casino interior is not available here."}
	if tutorial_main_floor_only():
		if target_id == GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID:
			return {"available": false, "locked": true, "reason": "Locked for this lesson. The Main Floor has everything you need; a Players Card can open High-Limit on later runs."}
		if target_id == GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID:
			return {"available": false, "locked": true, "reason": "Locked for this lesson. Rourke's Back Room belongs to later runs."}
		if target_id == GRAND_CASINO_ARCHETYPE_ID:
			return {"available": true, "access_method": "tutorial_main_floor", "cost": 0}
	if bool(narrative_flags.get("grand_casino_showdown_active", false)):
		if target_id == GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID and str(narrative_flags.get("grand_casino_showdown_step", "")) == GRAND_CASINO_SHOWDOWN_STEP_DUEL:
			return {"available": true, "access_method": "showdown", "cost": 0}
		return {"available": false, "locked": true, "reason": "Rourke keeps the Back Room door shut until the duel ends."}
	if target_id == GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID:
		return {"available": false, "locked": true, "reason": "Locked. Rourke opens the Back Room only for a showdown."}
	if target_id == GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID:
		if bool(narrative_flags.get("grand_casino_high_limit_access", false)):
			return {"available": true, "access_method": str(narrative_flags.get("grand_casino_high_limit_access_method", "card")), "cost": 0}
		var buy_in := maxi(0, high_limit_buy_in)
		if bankroll < buy_in:
			return {"available": false, "locked": true, "cash_buy_in_required": true, "cost": buy_in, "reason": "High-Limit requires Silver card access or a $%d cash buy-in." % buy_in}
		return {"available": true, "cash_buy_in_required": true, "access_method": "cash_buy_in", "cost": buy_in}
	if target_id == GRAND_CASINO_ARCHETYPE_ID:
		return {"available": true, "access_method": "interior", "cost": 0}
	return {"available": false, "reason": "That room is not part of the Grand Casino."}


func enter_world_node(node_id: String, environment_data: Dictionary) -> void:
	if world_map.is_empty() or node_id.strip_edges().is_empty():
		return
	world_map = WorldMap.enter_node(world_map, node_id, environment_data)


func environment_travel_count() -> int:
	return maxi(0, environment_history_archive_count) + environment_history.size()


func visited_environment_count() -> int:
	return environment_travel_count() + (0 if current_environment.is_empty() else 1)


func story_log_entry_count() -> int:
	return maxi(0, story_log_archive_count) + story_log.size()


# Changes bankroll and refreshes economy state.
func change_bankroll(delta: int, defer_bankroll_zero: bool = false) -> void:
	bankroll += delta
	_refresh_economy(defer_bankroll_zero)


func grand_casino_table_uses_chips(game_id: String, environment: Dictionary = {}) -> bool:
	return grand_casino_game_uses_chips(game_id, environment)


func grand_casino_game_uses_chips(game_id: String, environment: Dictionary = {}) -> bool:
	if not GRAND_CASINO_CHIP_GAME_IDS.has(game_id):
		return false
	var source := current_environment if environment.is_empty() else environment
	var archetype_id := str(source.get("archetype_id", ""))
	if GRAND_CASINO_ARCHETYPE_IDS.has(archetype_id):
		return true
	var environment_id := str(source.get("id", ""))
	if not environment_id.begins_with("grand_casino_"):
		return false
	return _is_grand_casino_environment(source)


func wager_balance_for_game(game_id: String, environment: Dictionary = {}) -> int:
	return bankroll + grand_casino_chips if grand_casino_game_uses_chips(game_id, environment) else bankroll


func wager_capacity_for_game(game_id: String, environment: Dictionary = {}) -> int:
	return bankroll + grand_casino_chips if grand_casino_game_uses_chips(game_id, environment) else bankroll


func fund_grand_casino_wager(game_id: String, wager_amount: int, environment: Dictionary = {}) -> Dictionary:
	var amount := maxi(0, wager_amount)
	if amount <= 0 or not grand_casino_game_uses_chips(game_id, environment):
		return {
			"ok": true,
			"wager": amount,
			"existing_chips_used": 0,
			"chips_bought": 0,
			"cash_used": 0,
		}
	var existing_chips_used := mini(grand_casino_chips, amount)
	var required_chips := maxi(0, amount - grand_casino_chips)
	if required_chips <= 0:
		return {
			"ok": true,
			"wager": amount,
			"existing_chips_used": existing_chips_used,
			"chips_bought": 0,
			"cash_used": 0,
		}
	var rate := grand_casino_chip_exchange_rate()
	var cash_cost := required_chips * rate
	if cash_cost > bankroll:
		return {
			"ok": false,
			"wager": amount,
			"existing_chips_used": existing_chips_used,
			"chips_bought": 0,
			"cash_used": 0,
			"message": "That wager needs %d chips plus $%d cash, but you only have $%d cash available." % [existing_chips_used, cash_cost, bankroll],
		}
	var buy_result := buy_grand_casino_chips(required_chips, rate)
	if not bool(buy_result.get("ok", false)):
		return buy_result
	return {
		"ok": true,
		"wager": amount,
		"existing_chips_used": existing_chips_used,
		"chips_bought": required_chips,
		"cash_used": cash_cost,
		"message": "Wagered %d chips first and covered the remaining %d with cash." % [existing_chips_used, required_chips],
	}


func fund_grand_casino_table_wager(game_id: String, wager_amount: int, environment: Dictionary = {}) -> Dictionary:
	return fund_grand_casino_wager(game_id, wager_amount, environment)


func grand_casino_total_money() -> int:
	return bankroll + grand_casino_chips


func has_liquid_run_funds() -> bool:
	return bankroll > 0 or (_is_grand_casino_environment(current_environment) and grand_casino_chips > 0)


func grand_casino_chip_exchange_rate() -> int:
	var flags: Dictionary = current_environment.get("local_narrative_flags", {}) if typeof(current_environment.get("local_narrative_flags", {})) == TYPE_DICTIONARY else {}
	return maxi(1, int(flags.get("casino_chip_cash_rate", 1)))


func buy_grand_casino_chips(chip_amount: int, cash_rate: int = 1) -> Dictionary:
	if not _is_grand_casino_environment(current_environment):
		return {"ok": false, "message": "Casino chips are only sold inside the Grand Casino."}
	if bool(narrative_flags.get("grand_casino_showdown_active", false)):
		return {"ok": false, "message": "The Cage is locked while Rourke's duel is active."}
	var amount := maxi(0, chip_amount)
	var rate := maxi(1, cash_rate)
	var cash_cost := amount * rate
	if amount <= 0:
		return {"ok": false, "message": "Choose a positive chip amount."}
	if cash_cost > bankroll:
		return {"ok": false, "message": "You need $%d cash for that buy-in." % cash_cost}
	bankroll -= cash_cost
	grand_casino_chips += amount
	_refresh_economy()
	return {"ok": true, "cash_delta": -cash_cost, "chips_delta": amount, "message": "Bought %d chips for $%d." % [amount, cash_cost]}


func cash_out_grand_casino_chips(chip_amount: int = -1, cash_rate: int = 1) -> Dictionary:
	if not _is_grand_casino_environment(current_environment):
		return {"ok": false, "message": "The Cage is only available inside the Grand Casino."}
	if bool(narrative_flags.get("grand_casino_walked_with_chips", false)):
		return {"ok": false, "message": "Rourke closed the Cage account when you were shown the door."}
	if bool(narrative_flags.get("grand_casino_showdown_active", false)) and str(narrative_flags.get("grand_casino_duel_outcome", "")) != GrandCasinoDuelModelScript.OUTCOME_WALK_OUT_CLEAN:
		return {"ok": false, "message": "The Cage is locked while Rourke's duel is active."}
	var amount := grand_casino_chips if chip_amount < 0 else mini(grand_casino_chips, maxi(0, chip_amount))
	if amount <= 0:
		return {"ok": false, "message": "You do not have any chips to cash out."}
	var rate := maxi(1, cash_rate)
	var cash_value := amount * rate
	grand_casino_chips -= amount
	bankroll += cash_value
	_refresh_economy()
	return {"ok": true, "cash_delta": cash_value, "chips_delta": -amount, "message": "Cashed out %d chips for $%d." % [amount, cash_value]}


func grand_casino_players_card_comp_result(comp_id: String) -> Dictionary:
	if not _is_grand_casino_environment(current_environment):
		return {"ok": false, "message": "Players Card comps are available only inside the Grand Casino."}
	var status := demo_objective_status()
	if not bool(status.get("players_card_eligible", false)):
		return {"ok": false, "message": "Cheat evidence closed the Players Card comp account."}
	var config := _grand_casino_objective_config(_copy_dict(current_environment.get("demo_objective", {})))
	var clean_id := comp_id.strip_edges().to_lower()
	var deltas := {
		"bankroll_delta": 0,
		"chips_delta": 0,
		"suspicion_delta": 0,
		"alcohol_intake": 0,
		"drunk_delta": 0,
		"pending_drunk_absorption_delta": 0,
		"flags_set": {},
		"story_log": [],
		"messages": [],
	}
	var message := ""
	var duration_minutes := 0
	match clean_id:
		"drink":
			var tokens := maxi(0, int(narrative_flags.get("grand_casino_comp_drink_tokens", 0)))
			if tokens <= 0:
				return {"ok": false, "message": "No drink comps remain."}
			var alcohol := maxi(0, int(config.get("players_card_comp_drink_alcohol", 0)))
			var service_status := service_hook_status({"id": "players_card_drink_comp", "cost": 0, "category": "alcohol", "effect": {"alcohol_intake": alcohol}})
			if not bool(service_status.get("available", false)):
				return {"ok": false, "message": str(service_status.get("disabled_reason", "The drink comp cannot help right now."))}
			deltas["alcohol_intake"] = alcohol
			(deltas["flags_set"] as Dictionary)["grand_casino_comp_drink_tokens"] = tokens - 1
			message = "Linda sends a quiet house drink to the bar."
		"suite_rest":
			var rests := maxi(0, int(narrative_flags.get("grand_casino_comp_suite_rests", 0)))
			if rests <= 0:
				return {"ok": false, "message": "No suite rests remain."}
			var heat_recovery := mini(suspicion_level(), maxi(0, int(config.get("players_card_suite_heat_recovery", 0))))
			var drunk_recovery := mini(drunk_level, maxi(0, int(config.get("players_card_suite_drunk_recovery", 0))))
			duration_minutes = maxi(0, int(config.get("players_card_suite_rest_minutes", 0)))
			deltas["suspicion_delta"] = -heat_recovery
			deltas["drunk_delta"] = -drunk_recovery
			deltas["pending_drunk_absorption_delta"] = -pending_drunk_absorption_amount()
			(deltas["flags_set"] as Dictionary)["grand_casino_comp_suite_rests"] = rests - 1
			message = "Linda turns the suite key. Four quiet hours clear your head."
		_:
			return {"ok": false, "message": "That Players Card comp is not available."}
	var story_entry := {
		"type": "service_hook",
		"id": "players_card_%s_comp" % clean_id,
		"label": "Players Card %s" % clean_id.replace("_", " ").capitalize(),
		"environment_id": str(current_environment.get("id", "")),
		"environment_archetype_id": str(current_environment.get("archetype_id", "")),
		"suspicion_delta": int(deltas.get("suspicion_delta", 0)),
		"drunk_delta": int(deltas.get("drunk_delta", 0)),
		"duration_minutes": duration_minutes,
		"message": message,
	}
	deltas["story_log"] = [story_entry]
	deltas["messages"] = [message]
	return {
		"ok": true,
		"type": "service_hook",
		"source_id": "players_card_%s_comp" % clean_id,
		"action_id": "use_service",
		"action_kind": "service",
		"environment_id": str(current_environment.get("id", "")),
		"environment_archetype_id": str(current_environment.get("archetype_id", "")),
		"suspicion_delta": int(deltas.get("suspicion_delta", 0)),
		"deltas": deltas,
		"duration_minutes": duration_minutes,
		"message": message,
	}


func route_grand_casino_game_currency(result: Dictionary, deltas: Dictionary) -> Dictionary:
	var routed := deltas
	var game_id := str(result.get("game_id", result.get("source_id", ""))).strip_edges()
	if not grand_casino_game_uses_chips(game_id):
		return routed
	var chips_delta := int(routed.get("bankroll_delta", result.get("bankroll_delta", 0)))
	var funding_amount := _grand_casino_result_wager_funding_amount(result, chips_delta)
	if funding_amount > grand_casino_chips:
		var funding := fund_grand_casino_wager(game_id, funding_amount, current_environment)
		if bool(funding.get("ok", false)):
			result["wager_existing_chips_used"] = int(funding.get("existing_chips_used", 0))
			result["wager_chips_bought"] = int(funding.get("chips_bought", 0))
			result["wager_cash_used"] = int(funding.get("cash_used", 0))
	routed["bankroll_delta"] = 0
	routed["chips_delta"] = chips_delta
	result["bankroll_delta"] = 0
	result["chips_delta"] = chips_delta
	result["cash_equivalent_delta"] = chips_delta
	result["currency"] = "chips"
	result["deltas"] = routed
	return routed


func _grand_casino_result_wager_funding_amount(result: Dictionary, bankroll_delta: int) -> int:
	var game_id := str(result.get("game_id", result.get("source_id", ""))).strip_edges()
	var action_id := str(result.get("action_id", "")).strip_edges()
	if game_id == "blackjack":
		if action_id != "blackjack_place_bet":
			return 0
		return maxi(0, -bankroll_delta)
	var wager := maxi(0, int(result.get("stake", 0)))
	if game_id == "roulette":
		wager = maxi(wager, int(result.get("roulette_total_wager", 0)))
	elif game_id == "baccarat":
		wager = maxi(wager, int(result.get("baccarat_total_wager", 0)))
	return maxi(wager, maxi(0, -bankroll_delta))


func change_grand_casino_chips(delta: int, defer_zero: bool = false) -> void:
	grand_casino_chips = maxi(0, grand_casino_chips + delta)
	_refresh_economy(defer_zero)


func challenge_modifiers() -> Dictionary:
	return _copy_dict(challenge_config.get("modifiers", {}))


func challenge_completion_flag() -> String:
	return str(challenge_config.get("completion_flag", "")).strip_edges()


func is_tutorial_run() -> bool:
	return bool(challenge_config.get("tutorial", false)) or bool(challenge_modifiers().get("tutorial_run", false))


func tutorial_main_floor_only() -> bool:
	return is_tutorial_run() and bool(challenge_modifiers().get("tutorial_main_floor_only", false))


func excludes_profile_stats() -> bool:
	return bool(challenge_config.get("exclude_profile_stats", false)) or is_tutorial_run()


func meta_collection_enabled_for_run() -> bool:
	var mode := str(challenge_config.get("mode", "standard")).strip_edges().to_lower()
	if mode != "standard":
		return false
	if not challenge_completion_flag().is_empty():
		return false
	return bool(challenge_modifiers().get("meta_collection_enabled", false))


func grand_casino_prestige_status() -> Dictionary:
	var modifiers := challenge_modifiers()
	var active := bool(modifiers.get("grand_casino_prestige", false))
	return {
		"active": active,
		"card_instance_ids": _copy_array(modifiers.get("grand_casino_prestige_card_instance_ids", [])) if active else [],
		"recognition_heat_delta": mini(0, int(modifiers.get("grand_casino_prestige_recognition_heat_delta", 0))) if active else 0,
		"clean_heat_ceiling_delta": mini(0, int(modifiers.get("grand_casino_prestige_clean_heat_ceiling_delta", 0))) if active else 0,
		"drop_tier_bonus_steps": maxi(0, int(modifiers.get("meta_collection_drop_tier_bonus_steps", 0))) if active else 0,
		"recognition_applied": bool(narrative_flags.get("grand_casino_prestige_recognition_applied", false)),
	}


func challenge_cheat_actions_disabled() -> bool:
	return bool(challenge_modifiers().get("disable_cheat_actions", false))


func challenge_service_category_blocked(category: String) -> bool:
	var normalized_category := category.strip_edges().to_lower()
	if normalized_category.is_empty():
		return false
	for blocked_value in _copy_array(challenge_modifiers().get("blocked_service_categories", [])):
		if str(blocked_value).strip_edges().to_lower() == normalized_category:
			return true
	return false


func challenge_service_cost_multiplier(service_data: Dictionary) -> float:
	var category := str(service_data.get("category", "")).strip_edges().to_lower()
	if category.is_empty():
		return 1.0
	var modifiers := challenge_modifiers()
	var multipliers := _copy_dict(modifiers.get("service_cost_multipliers", {}))
	if not multipliers.has(category):
		return 1.0
	return maxf(0.0, float(multipliers.get(category, 1.0)))


func _apply_starting_challenge_modifiers() -> void:
	var modifiers := challenge_modifiers()
	if modifiers.is_empty():
		return
	if bool(modifiers.get("grand_casino_prestige", false)):
		narrative_flags["grand_casino_prestige_run"] = true
		narrative_flags["grand_casino_prestige_card_instance_ids"] = _copy_array(modifiers.get("grand_casino_prestige_card_instance_ids", []))
	if modifiers.has("starting_bankroll"):
		bankroll = maxi(1, int(modifiers.get("starting_bankroll", DEFAULT_BANKROLL)))
	if modifiers.has("starting_bankroll_delta"):
		bankroll = maxi(1, bankroll + int(modifiers.get("starting_bankroll_delta", 0)))
	if modifiers.has("baseline_luck_delta"):
		baseline_luck = clampi(baseline_luck + int(modifiers.get("baseline_luck_delta", 0)), BASELINE_LUCK_MIN, BASELINE_LUCK_MAX)
	var starting_heat := clampi(int(modifiers.get("starting_heat", 0)), 0, 100)
	if starting_heat > 0:
		suspicion["level"] = starting_heat
		suspicion["cues"] = [{
			"id": "challenge_start_heat",
			"amount": starting_heat,
			"base_amount": starting_heat,
			"alcohol_heat_multiplier": 1.0,
			"visibility": "challenge",
			"revealed_meter": true,
			"context": {
				"challenge_id": str(challenge_config.get("id", "")),
			},
		}]
		_record_heat_history(false)
	for debt_value in _copy_array(modifiers.get("starting_debt", [])):
		if typeof(debt_value) == TYPE_DICTIONARY:
			add_debt(debt_value)
	_refresh_economy()


func begin_deferred_bankroll_zero_resolution() -> void:
	defer_next_bankroll_zero_failure = true


func clear_deferred_bankroll_zero_resolution() -> void:
	defer_next_bankroll_zero_failure = false


# Changes suspicion and records a behavior cue.
func add_suspicion(cue_id: String, amount: int, visibility: String = "behavior", revealed_meter: bool = false, context: Dictionary = {}, defer_bankroll_zero: bool = false) -> int:
	var location_id := _suspicion_location_id_from_context(context)
	var current_location_id := current_suspicion_location_id()
	var levels := _local_suspicion_levels()
	var base_level := suspicion_level()
	if not location_id.is_empty():
		base_level = int(levels.get(location_id, base_level if location_id == current_location_id or current_location_id.is_empty() else 0))
	var adjusted_amount := alcohol_adjusted_suspicion_delta(amount)
	if _consume_grand_casino_linda_look_away(adjusted_amount, context):
		adjusted_amount = 0
	var level := clampi(base_level + adjusted_amount, 0, 100)
	var applied_amount := level - base_level
	if location_id.is_empty():
		suspicion["level"] = level
	elif location_id == current_location_id or current_location_id.is_empty():
		levels[location_id] = level
		suspicion["local_levels"] = levels
		suspicion["level"] = level
	else:
		levels[location_id] = level
		suspicion["local_levels"] = levels
	if applied_amount != 0 and (location_id.is_empty() or location_id == current_location_id or current_location_id.is_empty()):
		_record_heat_history(false)
	var cues: Array = suspicion.get("cues", [])
	cues.append({
		"id": cue_id,
		"amount": applied_amount,
		"base_amount": amount,
		"alcohol_heat_multiplier": alcohol_heat_multiplier() if amount > 0 else 1.0,
		"visibility": visibility,
		"revealed_meter": revealed_meter,
		"context": context.duplicate(true),
	})
	suspicion["cues"] = cues
	if applied_amount > 0:
		record_grand_casino_room_heat_gain(_grand_casino_room_id_from_context(context), applied_amount)
	_evaluate_immediate_terminal_state(defer_bankroll_zero)
	return applied_amount


func _consume_grand_casino_linda_look_away(adjusted_amount: int, context: Dictionary) -> bool:
	if adjusted_amount <= 0 or not _is_grand_casino_environment(current_environment):
		return false
	if not bool(narrative_flags.get("grand_casino_linda_look_away_available", false)):
		return false
	if bool(narrative_flags.get("grand_casino_linda_look_away_consumed", false)):
		return false
	if bool(narrative_flags.get("grand_casino_cheat_evidence", false)) or bool(narrative_flags.get("grand_casino_watched_cheat_evidence", false)):
		return false
	if str(context.get("action_kind", "")).strip_edges() == "cheat":
		return false
	if _grand_casino_players_card_tier_index(str(narrative_flags.get("grand_casino_players_card_tier", GRAND_CASINO_PLAYERS_CARD_TIER_NONE))) < _grand_casino_players_card_tier_index(GRAND_CASINO_PLAYERS_CARD_TIER_SILVER):
		return false
	var objective := _copy_dict(current_environment.get("demo_objective", {}))
	var max_gain := maxi(0, int(objective.get("players_card_look_away_max_heat_gain", 0)))
	if max_gain <= 0 or adjusted_amount > max_gain:
		return false
	narrative_flags["grand_casino_linda_look_away_available"] = false
	narrative_flags["grand_casino_linda_look_away_consumed"] = true
	log_story({
		"type": "grand_casino_linda_look_away",
		"heat_forgiven": adjusted_amount,
		"environment_id": str(current_environment.get("id", "")),
		"environment_archetype_id": str(current_environment.get("archetype_id", "")),
		"message": "Linda closes the slip before the floor can mark the heat.",
	})
	return true


# Returns current suspicion as a bounded behavior pressure value.
func suspicion_level() -> int:
	return clampi(int(suspicion.get("level", 0)), 0, 100)


# Returns the local heat key for a generated or explicit environment id.
func suspicion_location_id_for_environment_id(environment_id: String) -> String:
	return _suspicion_location_id_from_context({"environment_id": environment_id})


# Returns remembered heat for a specific environment without changing focus.
func suspicion_level_for_environment_id(environment_id: String) -> int:
	var location_id := suspicion_location_id_for_environment_id(environment_id)
	if location_id.is_empty():
		return suspicion_level()
	var levels := _local_suspicion_levels()
	if levels.has(location_id):
		return clampi(int(levels.get(location_id, 0)), 0, 100)
	if location_id == current_suspicion_location_id():
		return suspicion_level()
	return 0


# Names the room's security posture without making the raw meter the primary UI.
func security_pressure_label() -> String:
	var level := suspicion_level()
	if level >= 85:
		return "security is ready to shut this down"
	if level >= 65:
		return "security is squeezing every risky move"
	if level >= 50:
		return "heat is closing in"
	if level >= 25:
		return "the room is watching"
	if level >= 10:
		return "people are noticing"
	if level > 0:
		return "a little attention is on you"
	return "quiet"


# Explains the current security posture in player-facing consequence language.
func security_pressure_summary() -> String:
	var label := security_pressure_label()
	if label == "quiet":
		return "The room feels quiet for now."
	if suspicion_level() >= 85:
		return "%s; one more risky move can end the run." % label.capitalize()
	if suspicion_level() >= 65:
		return "%s; risky moves now bring shakedown costs." % label.capitalize()
	return "%s; risky moves draw more heat." % label.capitalize()


# Raises both the temporary drunk meter and long-term alcohol need.
func drink_alcohol(amount: int) -> void:
	amount = maxi(0, amount)
	if amount <= 0:
		return
	_queue_drunk_absorption(amount)
	change_alcoholic(amount)


# Changes the temporary drunk meter.
func change_drunk(delta: int) -> void:
	if delta == 0:
		return
	if delta < 0 and has_pending_drunk_absorption():
		return
	drunk_level = clampi(drunk_level + delta, 0, ALCOHOL_MAX)


func change_pending_drunk_absorption(delta: int) -> void:
	if delta >= 0:
		if delta > 0:
			_queue_drunk_absorption(delta)
		return
	var remaining_reduction := maxi(0, -delta)
	if remaining_reduction <= 0 or pending_drunk_absorption.is_empty():
		return
	var next_queue: Array = []
	for entry_value in pending_drunk_absorption:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = (entry_value as Dictionary).duplicate(true)
		var remaining := maxi(0, int(entry.get("remaining", 0)))
		if remaining_reduction > 0:
			var removed := mini(remaining, remaining_reduction)
			remaining -= removed
			remaining_reduction -= removed
		if remaining > 0:
			entry["remaining"] = remaining
			next_queue.append(entry)
	pending_drunk_absorption = next_queue


func suppress_drunk_distortion(turns: int) -> void:
	drunk_distortion_suppression_turns = maxi(drunk_distortion_suppression_turns, maxi(0, turns))


func drunk_distortion_suppressed() -> bool:
	return drunk_distortion_suppression_turns > 0


# Applies delayed drink absorption in small chunks after the immediate first sip.
func update_drunk_absorption(now_msec: int = -1) -> Dictionary:
	if pending_drunk_absorption.is_empty():
		return {
			"applied": 0,
			"pending": 0,
			"active": false,
		}
	if now_msec < 0:
		now_msec = simulation_time_msec()
	var applied := 0
	var next_queue: Array = []
	for entry_value in pending_drunk_absorption:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = (entry_value as Dictionary).duplicate(true)
		var remaining := maxi(0, int(entry.get("remaining", 0)))
		var interval := maxi(1, int(entry.get("interval_msec", DRUNK_ABSORPTION_INTERVAL_MSEC)))
		var next_msec := int(entry.get("next_msec", now_msec + interval))
		if remaining <= 0:
			continue
		while remaining > 0 and drunk_level < ALCOHOL_MAX and now_msec >= next_msec:
			var step := mini(remaining, DRUNK_ABSORPTION_POINTS_PER_INTERVAL)
			step = mini(step, ALCOHOL_MAX - drunk_level)
			drunk_level = clampi(drunk_level + step, 0, ALCOHOL_MAX)
			remaining -= step
			applied += step
			next_msec += interval
		if remaining > 0 and drunk_level < ALCOHOL_MAX:
			entry["remaining"] = remaining
			entry["next_msec"] = next_msec
			entry["interval_msec"] = interval
			next_queue.append(entry)
	pending_drunk_absorption = next_queue
	return {
		"applied": applied,
		"pending": pending_drunk_absorption_amount(),
		"active": has_pending_drunk_absorption(),
	}


# Returns whether any drink effect is still ramping into the drunk meter.
func has_pending_drunk_absorption() -> bool:
	return pending_drunk_absorption_amount() > 0


# Returns the remaining drunk-meter value queued from drinks.
func pending_drunk_absorption_amount() -> int:
	var total := 0
	for entry_value in pending_drunk_absorption:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		total += maxi(0, int((entry_value as Dictionary).get("remaining", 0)))
	return total


func _queue_drunk_absorption(amount: int) -> void:
	var capacity := maxi(0, ALCOHOL_MAX - drunk_level - pending_drunk_absorption_amount())
	var queued := mini(maxi(0, amount), capacity)
	if queued <= 0:
		return
	var immediate := mini(queued, DRUNK_ABSORPTION_INITIAL_POINTS)
	if immediate > 0:
		drunk_level = clampi(drunk_level + immediate, 0, ALCOHOL_MAX)
		queued -= immediate
	if queued <= 0:
		return
	var now_msec := simulation_time_msec()
	var next_msec := now_msec + DRUNK_ABSORPTION_INTERVAL_MSEC
	for entry_value in pending_drunk_absorption:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value as Dictionary
		var queued_msec := int(entry.get("queued_msec", 0))
		if queued_msec > 0 and now_msec - queued_msec <= DRUNK_ABSORPTION_STACK_GRACE_MSEC:
			next_msec = int(entry.get("next_msec", next_msec))
			break
	pending_drunk_absorption.append({
		"remaining": queued,
		"interval_msec": DRUNK_ABSORPTION_INTERVAL_MSEC,
		"next_msec": next_msec,
		"queued_msec": now_msec,
	})


# Changes the persistent alcohol need meter.
func change_alcoholic(delta: int) -> void:
	if delta == 0:
		return
	alcoholic_level = clampi(alcoholic_level + delta, 0, ALCOHOL_MAX)


# Changes baseline luck before drunk/dependency modifiers are applied.
func change_baseline_luck(delta: int) -> void:
	if delta == 0:
		return
	baseline_luck = clampi(baseline_luck + delta, BASELINE_LUCK_MIN, BASELINE_LUCK_MAX)


# Returns the total luck modifier currently affecting game odds and small payouts.
func effective_luck() -> int:
	var gap := maxi(0, alcoholic_level - drunk_level)
	return clampi(
		baseline_luck + _drunk_luck_bonus() - _alcohol_dependency_penalty(gap) + _scratch_temporary_luck_bonus(),
		EFFECTIVE_LUCK_MIN,
		EFFECTIVE_LUCK_MAX
	)


func _scratch_temporary_luck_bonus() -> int:
	var bonus := int(narrative_flags.get("scratch_midnight_luck_bonus", 0))
	var expires_turn := int(narrative_flags.get("scratch_midnight_luck_expires_turn", 0))
	var current_turn := maxi(0, int(current_environment.get("turns", 0)))
	return bonus if bonus != 0 and current_turn < expires_turn else 0


# Returns the chance modifier games should apply to outcome rolls.
func luck_win_chance_bonus() -> int:
	return effective_luck()


# Returns how quickly timing windows and surface motion should move while drunk.
func drunk_time_scale() -> float:
	var normalized := clampf(float(drunk_level) / float(ALCOHOL_MAX), 0.0, 1.0)
	var scale := 1.0 - (1.0 - DRUNK_TIME_SCALE_MIN) * pow(normalized, DRUNK_TIME_SCALE_EXPONENT)
	return clampf(scale, DRUNK_TIME_SCALE_MIN, 1.0)


func drunk_time_scale_percent() -> int:
	return clampi(int(round(drunk_time_scale() * 100.0)), int(round(DRUNK_TIME_SCALE_MIN * 100.0)), 100)


# Returns a small payout adjustment from luck without letting luck dominate stakes.
func luck_payout_bonus(stake: int, won: bool = true) -> int:
	if not won or stake <= 0:
		return 0
	var luck := effective_luck()
	if luck == 0:
		return 0
	return int(round(float(stake) * float(luck) * 0.03))


# Scales positive heat while drunk or in alcohol debt.
func alcohol_adjusted_suspicion_delta(amount: int) -> int:
	if amount == 0:
		return 0
	if amount > 0:
		return maxi(1, int(ceil(float(amount) * alcohol_heat_multiplier())))
	if drunk_level >= 70:
		return -maxi(1, int(round(float(abs(amount)) * 0.80)))
	return amount


# Returns how much more noticeable risky behavior is under alcohol pressure.
func alcohol_heat_multiplier() -> float:
	var multiplier := 1.0
	if drunk_level >= 85:
		multiplier += 0.42
	elif drunk_level >= 65:
		multiplier += 0.30
	elif drunk_level >= 45:
		multiplier += 0.20
	elif drunk_level >= 30:
		multiplier += 0.14
	elif drunk_level >= 12:
		multiplier += 0.08
	var dependency_gap := maxi(0, alcoholic_level - drunk_level)
	if dependency_gap >= 60:
		multiplier += 0.15
	elif dependency_gap >= 30:
		multiplier += 0.10
	return multiplier


# Names the current alcohol condition without making the raw meter mandatory.
func alcohol_condition_label() -> String:
	if drunk_level <= 0 and alcoholic_level > 0:
		return "dry"
	if drunk_level <= 10:
		return "sober"
	if drunk_level <= 25:
		return "warm"
	if drunk_level <= 45:
		return "buzzed"
	if drunk_level <= 70:
		return "drunk"
	return "sloppy"


# Explains the current alcohol/luck tradeoff in compact player-facing language.
func alcohol_pressure_summary() -> String:
	var luck := effective_luck()
	var luck_text := "luck %+d" % luck if luck != 0 else "luck steady"
	var time_text := ""
	if drunk_level > 0:
		time_text = ", world %d%% speed" % drunk_time_scale_percent()
	var pending := pending_drunk_absorption_amount()
	if pending > 0:
		return "%s; drink still kicking in +%d, %s%s." % [alcohol_condition_label().capitalize(), pending, luck_text, time_text]
	if alcoholic_level > drunk_level:
		return "%s; need outpaces drink, %s%s." % [alcohol_condition_label().capitalize(), luck_text, time_text]
	if drunk_level > 0:
		return "%s; %s, heat rises faster%s." % [alcohol_condition_label().capitalize(), luck_text, time_text]
	return "Sober; %s." % luck_text


# Adds pressure to risky/cheat choices when suspicion is already elevated.
func security_risk_bonus(action_kind: String = "cheat") -> int:
	if action_kind != "cheat" and action_kind != "risky" and action_kind != "advantage":
		return 0
	var level := suspicion_level()
	var bonus := 0
	if level >= 85:
		bonus = 10
	elif level >= 65:
		bonus = 7
	elif level >= 50:
		bonus = 5
	elif level >= 25:
		bonus = 2
	elif level >= 10:
		bonus = 1
	if int(narrative_flags.get("shift_change_rookie_actions", 0)) > 0:
		bonus = maxi(0, bonus - 3)
	return bonus


# Returns the extra consequence applied when a risky action pushes heat high.
func security_action_pressure(action_kind: String, stake: int, projected_level: int = -1) -> Dictionary:
	if action_kind != "cheat" and action_kind != "risky" and action_kind != "advantage":
		return {
			"bankroll_delta": 0,
			"ended": false,
			"message": "",
		}
	var level := clampi(projected_level if projected_level >= 0 else suspicion_level(), 0, 100)
	var safe_stake := maxi(1, stake)
	if level >= 100:
		if _is_grand_casino_environment(current_environment):
			return {
				"bankroll_delta": 0,
				"ended": false,
				"message": "Rourke's crew closes in; the back room is coming.",
			}
		var shutdown_cost := -mini(maxi(10, safe_stake), maxi(bankroll, 0))
		return {
			"bankroll_delta": shutdown_cost,
			"ended": true,
			"message": "Police lights slam across the room; the run ends in cuffs.",
		}
	if level >= 85:
		var crackdown_cost := -mini(maxi(8, safe_stake), maxi(bankroll, 0))
		return {
			"bankroll_delta": crackdown_cost,
			"ended": false,
			"message": "Security leans in hard and forces a costly exit.",
		}
	if level >= 65:
		var half_stake := maxi(1, int(ceil(float(safe_stake) / 2.0)))
		var shakedown_cost := -mini(maxi(3, half_stake), maxi(bankroll, 0))
		return {
			"bankroll_delta": shakedown_cost,
			"ended": false,
			"message": "Security pressure adds a shakedown cost.",
		}
	return {
		"bankroll_delta": 0,
		"ended": false,
		"message": "",
	}


# Returns whether Grand Casino heat is high enough to route away from police capture.
func grand_casino_heat_reroute_available() -> bool:
	if run_status == RUN_STATUS_ENDED or run_status == RUN_STATUS_FAILED:
		return false
	if tutorial_main_floor_only():
		return false
	if not _is_grand_casino_environment(current_environment):
		return false
	var status := demo_objective_status()
	if not bool(status.get("grand_casino_objective", false)):
		return false
	if bool(status.get("showdown_pending", false)) or bool(status.get("showdown_active", false)):
		return true
	return bool(status.get("heat_route_ready", false)) or bool(status.get("dirty_money_showdown_ready", false))


# Queues the Grand Casino back-room showdown when heat has crossed its route threshold.
func handle_grand_casino_heat_reroute(trigger_context: String = "") -> bool:
	if run_status == RUN_STATUS_ENDED or run_status == RUN_STATUS_FAILED:
		return false
	if tutorial_main_floor_only():
		return false
	if not _is_grand_casino_environment(current_environment):
		return false
	var status := demo_objective_status()
	if not bool(status.get("grand_casino_objective", false)):
		return false
	if bool(status.get("showdown_pending", false)) or bool(status.get("showdown_active", false)):
		return true
	if not bool(status.get("heat_route_ready", false)) and not bool(status.get("dirty_money_showdown_ready", false)):
		return false
	_evaluate_grand_casino_objective_state(status)
	if not trigger_context.strip_edges().is_empty():
		narrative_flags["grand_casino_heat_reroute_context"] = trigger_context
	var next_status := demo_objective_status()
	return bool(next_status.get("showdown_pending", false)) or bool(next_status.get("showdown_active", false))


# Returns the staff attention state that can route Grand Casino heat to Rourke.
func grand_casino_staff_attention_status(environment: Dictionary = {}, forced_heat_threshold: int = 95) -> Dictionary:
	var source := environment if not environment.is_empty() else current_environment
	if not _is_grand_casino_environment(source):
		return {
			"active": false,
			"sources": [],
			"watch": {"active": false},
			"summary": "",
		}
	var sources: Array = []
	var watch_status := pit_boss_watch_status(source)
	if bool(watch_status.get("active", false)) and bool(watch_status.get("watched", false)):
		sources.append("rourke_watch")
	if bool(narrative_flags.get("grand_casino_watched_cheat_evidence", false)) or bool(narrative_flags.get("grand_casino_attention_watched_cheat", false)):
		_append_unique_string(sources, "watched_cheat")
	if bool(narrative_flags.get("grand_casino_attention_pit_boss_sweep", false)):
		_append_unique_string(sources, "pit_boss_sweep")
	if bool(narrative_flags.get("grand_casino_attention_eye_in_the_sky", false)):
		_append_unique_string(sources, "eye_in_the_sky")
	for event_source in _grand_casino_active_security_event_sources(source):
		_append_unique_string(sources, str(event_source))
	if bool(narrative_flags.get("grand_casino_attention_watched_risky", false)):
		_append_unique_string(sources, "watched_risky")
	if bool(narrative_flags.get("grand_casino_attention_host", false)):
		_append_unique_string(sources, "host")
	if bool(narrative_flags.get("grand_casino_attention_high_roller_review", false)):
		_append_unique_string(sources, "high_roller_review")
	if bool(narrative_flags.get("grand_casino_attention_forced_heat", false)) or suspicion_level() >= forced_heat_threshold:
		_append_unique_string(sources, "forced_heat")
	var source_labels := {
		"rourke_watch": "Rourke watching",
		"watched_cheat": "watched edge",
		"pit_boss_sweep": "pit sweep",
		"eye_in_the_sky": "camera review",
		"watched_risky": "watched risky play",
		"host": "host attention",
		"high_roller_review": "Players Card review",
		"forced_heat": "heat spike",
	}
	var label_parts: Array = []
	for source_id in sources:
		label_parts.append(str(source_labels.get(str(source_id), str(source_id).replace("_", " "))))
	var summary := "No staff attention."
	if not label_parts.is_empty():
		summary = "Staff attention: %s." % ", ".join(label_parts)
	return {
		"active": not sources.is_empty(),
		"sources": sources,
		"watch": watch_status,
		"summary": summary,
	}


# Returns the active environment objective without changing the run.
func demo_objective_status(environment: Dictionary = {}) -> Dictionary:
	var source := environment if not environment.is_empty() else current_environment
	var objective := _copy_dict(source.get("demo_objective", {}))
	if objective.is_empty():
		return {"active": false}
	if _is_grand_casino_objective(objective):
		return _grand_casino_demo_objective_status(source, objective)
	var objective_type := str(objective.get("type", "")).strip_edges()
	var target_bankroll := maxi(0, int(objective.get("target_bankroll", 0)))
	var remaining := maxi(0, target_bankroll - bankroll)
	var complete := false
	match objective_type:
		"bankroll_target":
			complete = bankroll >= target_bankroll
		_:
			complete = false
	var title := str(objective.get("title", "Beat the house"))
	var summary := str(objective.get("summary", "Reach the objective."))
	var victory_message := str(objective.get("victory_message", "Demo Victory: you beat the house for now."))
	var finale_event_id := str(objective.get("finale_event_id", "")).strip_edges()
	var finale_required := not finale_event_id.is_empty()
	var finale_pending := finale_required and bool(narrative_flags.get("demo_finale_pending", false)) and str(narrative_flags.get("demo_finale_event_id", "")) == finale_event_id
	return {
		"active": true,
		"id": str(objective.get("id", "")),
		"type": objective_type,
		"title": title,
		"summary": summary,
		"target_bankroll": target_bankroll,
		"current_bankroll": bankroll,
		"remaining_bankroll": remaining,
		"complete": complete,
		"victory_message": victory_message,
		"finale_required": finale_required,
		"finale_event_id": finale_event_id,
		"finale_pending": finale_pending,
	}


# Completes a data-authored environment objective when its condition is met.
func evaluate_environment_objective_state() -> Dictionary:
	var status := demo_objective_status()
	if not bool(status.get("active", false)):
		return status
	if run_status == RUN_STATUS_ENDED or run_status == RUN_STATUS_FAILED:
		return status
	if bool(status.get("grand_casino_objective", false)):
		_evaluate_grand_casino_objective_state(status)
		return demo_objective_status()
	if not bool(status.get("complete", false)):
		return status
	var objective := _copy_dict(current_environment.get("demo_objective", {}))
	var finale_event_id := str(objective.get("finale_event_id", "")).strip_edges()
	if not finale_event_id.is_empty():
		var required_kind := str(objective.get("finale_requires_kind", "")).strip_edges()
		if not required_kind.is_empty() and str(current_environment.get("kind", "")) != required_kind:
			return status
		if bool(objective.get("finale_requires_watched", false)):
			var watch_status := pit_boss_watch_status(current_environment)
			if not bool(watch_status.get("active", false)) or not bool(watch_status.get("watched", false)):
				narrative_flags["demo_finale_ready"] = true
				narrative_flags["demo_finale_event_id"] = finale_event_id
				return demo_objective_status()
		_trigger_demo_finale(status, objective)
		return demo_objective_status()
	_complete_demo_objective(status)
	return demo_objective_status()


# Records one settled Grand Casino game result for Players Card objective progress.
func record_grand_casino_game_result(result: Dictionary) -> void:
	if result.is_empty() or not bool(result.get("ok", false)):
		return
	if not _is_grand_casino_environment(current_environment):
		return
	if str(result.get("game_id", "")).strip_edges().is_empty():
		return
	_initialize_grand_casino_objective_runtime()
	var entry_bankroll := int(narrative_flags.get("grand_casino_entry_bankroll", grand_casino_total_money()))
	narrative_flags["grand_casino_net_winnings"] = grand_casino_total_money() - entry_bankroll
	narrative_flags["grand_casino_max_heat"] = maxi(
		int(narrative_flags.get("grand_casino_max_heat", 0)),
		suspicion_level()
	)
	var action_kind := str(result.get("action_kind", ""))
	var watch_status := pit_boss_watch_status(current_environment)
	var watched_or_bonused := (
		(bool(watch_status.get("active", false)) and bool(watch_status.get("watched", false)))
		or _grand_casino_result_pit_boss_heat_bonus(result) > 0
	)
	if (action_kind == "cheat" or action_kind == "risky" or action_kind == "advantage") and watched_or_bonused:
		narrative_flags["grand_casino_attention_watched_risky"] = true
	if action_kind == "cheat":
		narrative_flags["grand_casino_open_cheat_actions"] = maxi(0, int(narrative_flags.get("grand_casino_open_cheat_actions", 0))) + 1
		narrative_flags["grand_casino_cheat_evidence"] = true
		if watched_or_bonused:
			narrative_flags["grand_casino_watched_cheat_evidence"] = true
			narrative_flags["grand_casino_attention_watched_cheat"] = true
	if not _grand_casino_result_has_wager(result):
		return
	var games_played := maxi(0, int(narrative_flags.get("grand_casino_games_played", 0))) + 1
	narrative_flags["grand_casino_games_played"] = games_played


func record_profile_game_result(result: Dictionary) -> void:
	if result.is_empty() or not bool(result.get("ok", false)):
		return
	var game_id := str(result.get("game_id", "")).strip_edges()
	if game_id.is_empty():
		return
	var tallies := _copy_dict(narrative_flags.get("profile_games_played", {}))
	tallies[game_id] = maxi(0, int(tallies.get(game_id, 0))) + 1
	narrative_flags["profile_games_played"] = tallies
	var deltas := _copy_dict(result.get("deltas", {}))
	var bankroll_delta := int(deltas.get("bankroll_delta", result.get("bankroll_delta", 0)))
	if str(result.get("currency", "")) == "chips":
		bankroll_delta = int(deltas.get("chips_delta", result.get("chips_delta", 0)))
	if bankroll_delta > 0:
		narrative_flags["profile_bankroll_won"] = maxi(0, int(narrative_flags.get("profile_bankroll_won", 0))) + bankroll_delta
		narrative_flags["profile_biggest_single_win"] = maxi(maxi(0, int(narrative_flags.get("profile_biggest_single_win", 0))), bankroll_delta)
	elif bankroll_delta < 0:
		narrative_flags["profile_bankroll_lost"] = maxi(0, int(narrative_flags.get("profile_bankroll_lost", 0))) + absi(bankroll_delta)


func _grand_casino_demo_objective_status(source: Dictionary, objective: Dictionary) -> Dictionary:
	if not _is_grand_casino_environment(source):
		return {
			"active": false,
			"id": str(objective.get("id", "")),
			"grand_casino_objective": false,
		}
	var config := _grand_casino_objective_config(objective)
	var target_bankroll := int(config.get("high_roller_target_bankroll", 0))
	var total_money := grand_casino_total_money()
	var entry_bankroll := int(narrative_flags.get("grand_casino_entry_bankroll", total_money))
	var net_winnings := total_money - entry_bankroll
	var required_net := int(config.get("high_roller_net_winnings", 0))
	var games_played := maxi(0, int(narrative_flags.get("grand_casino_games_played", 0)))
	var min_games := int(config.get("high_roller_min_grand_casino_games", 0))
	var max_heat := int(config.get("high_roller_max_heat", 100))
	var current_heat := suspicion_level()
	var max_visit_heat := maxi(current_heat, int(narrative_flags.get("grand_casino_max_heat", current_heat)))
	var showdown_threshold := int(config.get("showdown_heat_threshold", 70))
	var forced_threshold := int(config.get("forced_showdown_heat_threshold", 95))
	var staff_attention := grand_casino_staff_attention_status(source, forced_threshold)
	var staff_sources := _copy_array(staff_attention.get("sources", []))
	var cheat_evidence := bool(narrative_flags.get("grand_casino_cheat_evidence", false))
	var watched_cheat_evidence := bool(narrative_flags.get("grand_casino_watched_cheat_evidence", false))
	var card_eligible := not bool(narrative_flags.get("grand_casino_players_card_ineligible", false)) and not cheat_evidence and not watched_cheat_evidence
	var derived_tier := _grand_casino_players_card_derived_tier(config, games_played, net_winnings, max_visit_heat, card_eligible)
	var stored_tier := str(narrative_flags.get("grand_casino_players_card_tier", GRAND_CASINO_PLAYERS_CARD_TIER_NONE)).strip_edges().to_lower()
	if not GRAND_CASINO_PLAYERS_CARD_TIERS.has(stored_tier):
		stored_tier = GRAND_CASINO_PLAYERS_CARD_TIER_NONE
	var card_tier := stored_tier
	if _grand_casino_players_card_tier_index(derived_tier) > _grand_casino_players_card_tier_index(card_tier):
		card_tier = derived_tier
	if not card_eligible:
		card_tier = GRAND_CASINO_PLAYERS_CARD_TIER_NONE
	var card_tier_label := card_tier.capitalize() if card_tier != GRAND_CASINO_PLAYERS_CARD_TIER_NONE else "Unranked"
	if not card_eligible:
		card_tier_label = "Ineligible"
	var next_tier := _grand_casino_players_card_next_definition(config, card_tier) if card_eligible else {}
	var next_tier_id := str(next_tier.get("id", ""))
	var next_tier_label := str(next_tier.get("label", ""))
	var next_tier_min_games := int(next_tier.get("min_games", min_games))
	var next_tier_net := int(next_tier.get("net_winnings", required_net))
	var next_tier_max_heat := int(next_tier.get("max_heat", max_heat))
	var card_benefits := _grand_casino_players_card_benefits(config, card_tier) if card_eligible else []
	var money_target_met := net_winnings >= required_net
	if required_net <= 0 and target_bankroll > 0:
		money_target_met = total_money >= target_bankroll
	var game_target_met := games_played >= min_games
	var heat_clean := max_visit_heat <= max_heat
	var high_roller_ready := card_tier == GRAND_CASINO_PLAYERS_CARD_TIER_GOLD and money_target_met and game_target_met and heat_clean and card_eligible
	var high_roller_pending := bool(narrative_flags.get("high_roller_cashout_pending", false))
	var showdown_event_id := str(config.get("showdown_event_id", GRAND_CASINO_SHOWDOWN_EVENT_ID))
	var high_roller_event_id := str(config.get("high_roller_event_id", GRAND_CASINO_HIGH_ROLLER_EVENT_ID))
	var showdown_disabled := tutorial_main_floor_only()
	var showdown_pending := false if showdown_disabled else bool(narrative_flags.get("grand_casino_showdown_pending", false))
	showdown_pending = showdown_pending or (
		not showdown_disabled
		and bool(narrative_flags.get("demo_finale_pending", false))
		and str(narrative_flags.get("demo_finale_event_id", "")) == showdown_event_id
	)
	var showdown_active := false if showdown_disabled else bool(narrative_flags.get("grand_casino_showdown_active", false))
	var staff_attention_active := bool(staff_attention.get("active", false))
	var heat_route_ready := not showdown_disabled and ((current_heat >= showdown_threshold and staff_attention_active) or current_heat >= forced_threshold)
	var dirty_money_showdown_ready := not showdown_disabled and money_target_met and (cheat_evidence or watched_cheat_evidence or max_visit_heat > max_heat)
	var objective_state := _grand_casino_derived_state(source, high_roller_ready or high_roller_pending, showdown_pending, showdown_active)
	var complete := bool(narrative_flags.get("demo_victory", false))
	var remaining_bankroll := maxi(0, target_bankroll - total_money)
	var remaining_net := maxi(0, required_net - net_winnings)
	var remaining_games := maxi(0, min_games - games_played)
	var summary := _grand_casino_objective_summary(
		high_roller_ready or high_roller_pending,
		showdown_pending or showdown_active,
		heat_route_ready,
		dirty_money_showdown_ready,
		money_target_met,
		game_target_met,
		target_bankroll,
		required_net,
		remaining_games
	)
	return {
		"active": true,
		"id": str(objective.get("id", "")),
		"type": str(objective.get("type", "")),
		"title": str(objective.get("title", "Beat the Grand Casino")),
		"summary": summary,
		"authored_summary": str(objective.get("summary", "")),
		"target_bankroll": target_bankroll,
		"current_bankroll": bankroll,
		"remaining_bankroll": remaining_bankroll,
		"complete": complete,
		"victory_message": str(objective.get("victory_message", "Demo Victory: you beat the Grand Casino floor.")),
		"finale_required": true,
		"finale_event_id": showdown_event_id,
		"finale_pending": showdown_pending,
		"grand_casino_objective": true,
		"objective_state": objective_state,
		"grand_casino_entry_bankroll": entry_bankroll,
		"grand_casino_net_winnings": net_winnings,
		"grand_casino_open_cheat_actions": maxi(0, int(narrative_flags.get("grand_casino_open_cheat_actions", 0))),
		"high_roller_target_bankroll": target_bankroll,
		"high_roller_net_winnings": required_net,
		"high_roller_remaining_net_winnings": remaining_net,
		"high_roller_min_grand_casino_games": min_games,
		"grand_casino_games_played": games_played,
		"high_roller_remaining_games": remaining_games,
		"high_roller_max_heat": max_heat,
		"current_heat": current_heat,
		"grand_casino_max_heat": max_visit_heat,
		"high_roller_ready": high_roller_ready or high_roller_pending,
		"high_roller_cashout_pending": high_roller_pending,
		"high_roller_event_id": high_roller_event_id,
		"players_card_ready": high_roller_ready or high_roller_pending,
		"players_card_event_id": high_roller_event_id,
		"players_card_required_net_winnings": required_net,
		"players_card_remaining_net_winnings": remaining_net,
		"players_card_tier": card_tier,
		"players_card_tier_label": card_tier_label,
		"players_card_eligible": card_eligible,
		"players_card_ineligible_reason": "Cheat evidence permanently closes the Players Card program for this run." if not card_eligible else "",
		"players_card_next_tier": next_tier_id,
		"players_card_next_tier_label": next_tier_label,
		"players_card_next_min_games": next_tier_min_games,
		"players_card_next_net_winnings": next_tier_net,
		"players_card_next_max_heat": next_tier_max_heat,
		"players_card_next_remaining_games": maxi(0, next_tier_min_games - games_played),
		"players_card_next_remaining_net_winnings": maxi(0, next_tier_net - net_winnings),
		"players_card_benefits": card_benefits,
		"players_card_next_benefits": _copy_array(next_tier.get("benefits", [])),
		"players_card_drink_comps": maxi(0, int(narrative_flags.get("grand_casino_comp_drink_tokens", 0))),
		"players_card_suite_rests": maxi(0, int(narrative_flags.get("grand_casino_comp_suite_rests", 0))),
		"players_card_look_away_available": bool(narrative_flags.get("grand_casino_linda_look_away_available", false)),
		"prestige": grand_casino_prestige_status(),
		"cheat_evidence": cheat_evidence,
		"watched_cheat_evidence": watched_cheat_evidence,
		"showdown_heat_threshold": showdown_threshold,
		"forced_showdown_heat_threshold": forced_threshold,
		"showdown_event_id": showdown_event_id,
		"showdown_pending": showdown_pending,
		"showdown_active": showdown_active,
		"showdown_ready": heat_route_ready or dirty_money_showdown_ready,
		"heat_route_ready": heat_route_ready,
		"dirty_money_showdown_ready": dirty_money_showdown_ready,
		"staff_attention": staff_attention,
		"staff_attention_active": staff_attention_active,
		"staff_attention_sources": staff_sources,
		"pit_boss_watch": _copy_dict(staff_attention.get("watch", {})),
		"goal_text": summary,
		"lanes": {
			"clean": {
				"route": GRAND_CASINO_HIGH_ROLLER_EVENT_ID,
				"label": "players_card",
				"event_id": high_roller_event_id,
				"ready": high_roller_ready or high_roller_pending,
				"pending": high_roller_pending,
				"target_bankroll": target_bankroll,
				"net_winnings": required_net,
				"players_card_required_net_winnings": required_net,
				"min_games": min_games,
				"max_heat": max_heat,
			},
			"heat": {
				"route": "pit_boss_showdown",
				"event_id": showdown_event_id,
				"ready": heat_route_ready or dirty_money_showdown_ready,
				"pending": showdown_pending,
				"heat_threshold": showdown_threshold,
				"forced_heat_threshold": forced_threshold,
				"staff_attention": staff_attention_active,
			},
		},
	}


func _evaluate_grand_casino_objective_state(status: Dictionary) -> void:
	if not _is_grand_casino_environment(current_environment):
		return
	_initialize_grand_casino_objective_runtime()
	_update_grand_casino_players_card_state(status)
	if tutorial_main_floor_only():
		if bool(status.get("high_roller_ready", false)):
			_set_grand_casino_high_roller_ready(status)
		return
	if bool(status.get("showdown_pending", false)) or bool(status.get("showdown_active", false)):
		return
	if bool(status.get("dirty_money_showdown_ready", false)):
		_trigger_grand_casino_showdown(status, "dirty_money")
		return
	if bool(status.get("heat_route_ready", false)):
		var forced_threshold := int(status.get("forced_showdown_heat_threshold", 95))
		var trigger_reason := "forced_heat" if suspicion_level() >= forced_threshold else "heat_attention"
		_trigger_grand_casino_showdown(status, trigger_reason)
		return
	if bool(status.get("high_roller_ready", false)):
		_set_grand_casino_high_roller_ready(status)


func _update_grand_casino_players_card_state(status: Dictionary) -> void:
	narrative_flags["grand_casino_net_winnings"] = int(status.get("grand_casino_net_winnings", narrative_flags.get("grand_casino_net_winnings", 0)))
	if not bool(status.get("players_card_eligible", true)):
		narrative_flags["grand_casino_players_card_ineligible"] = true
		narrative_flags["grand_casino_players_card_tier"] = GRAND_CASINO_PLAYERS_CARD_TIER_NONE
		narrative_flags["grand_casino_linda_look_away_available"] = false
		if str(narrative_flags.get("grand_casino_high_limit_access_method", "")) == "silver_card":
			narrative_flags["grand_casino_high_limit_access"] = false
			narrative_flags["grand_casino_high_limit_access_method"] = ""
		return
	narrative_flags["grand_casino_players_card_ineligible"] = false
	var target_tier := str(status.get("players_card_tier", GRAND_CASINO_PLAYERS_CARD_TIER_NONE))
	var current_tier := str(narrative_flags.get("grand_casino_players_card_tier", GRAND_CASINO_PLAYERS_CARD_TIER_NONE))
	_advance_grand_casino_players_card_tier(current_tier, target_tier, true)


func _advance_grand_casino_players_card_tier(current_tier: String, target_tier: String, queue_dialogue: bool) -> void:
	var current_index := _grand_casino_players_card_tier_index(current_tier)
	var target_index := _grand_casino_players_card_tier_index(target_tier)
	if target_index <= current_index:
		narrative_flags["grand_casino_players_card_tier"] = GRAND_CASINO_PLAYERS_CARD_TIERS[current_index]
		return
	var config := _grand_casino_objective_config(_copy_dict(current_environment.get("demo_objective", {})))
	for tier_index in range(current_index + 1, target_index + 1):
		var tier_id := str(GRAND_CASINO_PLAYERS_CARD_TIERS[tier_index])
		var definition := _grand_casino_players_card_tier_definition(config, tier_id)
		_apply_grand_casino_players_card_tier_benefits(definition)
		narrative_flags["grand_casino_players_card_tier"] = tier_id
		narrative_flags["grand_casino_players_card_highest_tier"] = tier_id
		log_story({
			"type": "grand_casino_players_card_tier",
			"tier": tier_id,
			"games_played": maxi(0, int(narrative_flags.get("grand_casino_games_played", 0))),
			"net_winnings": int(narrative_flags.get("grand_casino_net_winnings", 0)),
			"environment_id": str(current_environment.get("id", "")),
			"environment_archetype_id": str(current_environment.get("archetype_id", "")),
			"message": "Linda marks the Players Card %s." % tier_id.capitalize(),
		})
		if queue_dialogue and not is_tutorial_run() and GRAND_CASINO_LINDA_TIER_DIALOGUES.has(tier_id):
			var dialogue_id := str(GRAND_CASINO_LINDA_TIER_DIALOGUES[tier_id])
			enqueue_dialogue(dialogue_id, "dialogue:%s" % dialogue_id, GRAND_CASINO_LINDA_SPEAKER, "recognition", "players_card_tier", {
				"tier": tier_id,
				"environment_snapshot": current_environment.duplicate(true),
			})


func _apply_grand_casino_players_card_tier_benefits(definition: Dictionary) -> void:
	if definition.is_empty():
		return
	var tier_id := str(definition.get("id", ""))
	var granted_flag := "grand_casino_players_card_%s_benefits_granted" % tier_id
	if bool(narrative_flags.get(granted_flag, false)):
		return
	var chip_bonus := maxi(0, int(definition.get("chip_bonus", 0)))
	if chip_bonus > 0:
		grand_casino_chips += chip_bonus
		narrative_flags["grand_casino_entry_bankroll"] = int(narrative_flags.get("grand_casino_entry_bankroll", grand_casino_total_money() - chip_bonus)) + chip_bonus
		_refresh_economy(true)
	var drink_comps := maxi(0, int(definition.get("drink_comps", 0)))
	if drink_comps > 0:
		narrative_flags["grand_casino_comp_drink_tokens"] = maxi(0, int(narrative_flags.get("grand_casino_comp_drink_tokens", 0))) + drink_comps
	var suite_rests := maxi(0, int(definition.get("suite_rests", 0)))
	if suite_rests > 0:
		narrative_flags["grand_casino_comp_suite_rests"] = maxi(0, int(narrative_flags.get("grand_casino_comp_suite_rests", 0))) + suite_rests
	if tier_id == GRAND_CASINO_PLAYERS_CARD_TIER_SILVER:
		narrative_flags["grand_casino_high_limit_access"] = true
		narrative_flags["grand_casino_high_limit_access_method"] = "silver_card"
		if not bool(narrative_flags.get("grand_casino_linda_look_away_consumed", false)):
			narrative_flags["grand_casino_linda_look_away_available"] = true
	narrative_flags[granted_flag] = true


func _set_grand_casino_high_roller_ready(status: Dictionary) -> void:
	var high_roller_event_id := str(status.get("high_roller_event_id", GRAND_CASINO_HIGH_ROLLER_EVENT_ID)).strip_edges()
	if high_roller_event_id.is_empty():
		high_roller_event_id = GRAND_CASINO_HIGH_ROLLER_EVENT_ID
	narrative_flags["grand_casino_endgame_state"] = GRAND_CASINO_STATE_HIGH_ROLLER_READY
	narrative_flags["grand_casino_high_roller_ready"] = true
	narrative_flags["high_roller_cashout_pending"] = true
	narrative_flags["grand_casino_showdown_pending"] = false
	narrative_flags["demo_objective_id"] = str(status.get("id", GRAND_CASINO_OBJECTIVE_ID))
	narrative_flags["grand_casino_net_winnings"] = int(status.get("grand_casino_net_winnings", 0))
	if not _story_log_has_type("grand_casino_high_roller_ready", high_roller_event_id):
		log_story({
			"type": "grand_casino_high_roller_ready",
			"event_id": high_roller_event_id,
			"objective_id": str(status.get("id", GRAND_CASINO_OBJECTIVE_ID)),
			"environment_id": str(current_environment.get("id", "")),
			"environment_archetype_id": str(current_environment.get("archetype_id", "")),
			"bankroll": bankroll,
			"grand_casino_chips": grand_casino_chips,
			"target_bankroll": int(status.get("high_roller_target_bankroll", status.get("target_bankroll", 0))),
			"net_winnings": int(status.get("grand_casino_net_winnings", 0)),
			"message": "Linda is ready to complete the Gold Players Card review.",
		})


func complete_grand_casino_high_roller_cashout(config: Dictionary = {}) -> Dictionary:
	if run_status == RUN_STATUS_ENDED or run_status == RUN_STATUS_FAILED:
		return {"ok": false, "message": "The run is already over."}
	if not _is_grand_casino_environment(current_environment):
		return {"ok": false, "message": "The Players Card desk is only available in the Grand Casino."}
	var status := demo_objective_status()
	if not bool(status.get("grand_casino_objective", false)):
		return {"ok": false, "message": "The Players Card is not available here."}
	if bool(status.get("showdown_pending", false)) or bool(status.get("showdown_active", false)):
		return {"ok": false, "message": "Rourke's call has priority now."}
	if not bool(status.get("high_roller_ready", false)) and not bool(narrative_flags.get("high_roller_cashout_pending", false)):
		evaluate_environment_objective_state()
		status = demo_objective_status()
	if not bool(status.get("high_roller_ready", false)) and not bool(narrative_flags.get("high_roller_cashout_pending", false)):
		return {"ok": false, "message": "The host is not ready to issue the Players Card yet."}
	var high_roller_event_id := str(status.get("high_roller_event_id", GRAND_CASINO_HIGH_ROLLER_EVENT_ID)).strip_edges()
	if high_roller_event_id.is_empty():
		high_roller_event_id = GRAND_CASINO_HIGH_ROLLER_EVENT_ID
	var message := str(config.get("success_message", GRAND_CASINO_HIGH_ROLLER_DEFAULT_SUCCESS_MESSAGE)).strip_edges()
	if message.is_empty():
		message = GRAND_CASINO_HIGH_ROLLER_DEFAULT_SUCCESS_MESSAGE
	_clear_grand_casino_clean_cashout_ready()
	narrative_flags["grand_casino_endgame_state"] = GRAND_CASINO_STATE_VICTORY
	var victory_status := status.duplicate(true)
	victory_status["victory_message"] = message
	_complete_demo_objective(victory_status, message, {
		"finale_event_id": high_roller_event_id,
		"finale_branch": GRAND_CASINO_HIGH_ROLLER_EVENT_ID,
		"demo_victory_route": GRAND_CASINO_HIGH_ROLLER_EVENT_ID,
	})
	narrative_flags["act_two_seam_ready"] = true
	if not _story_log_has_type("act_two_seam_ready", GRAND_CASINO_HIGH_ROLLER_EVENT_ID):
		log_story({
			"type": "act_two_seam_ready",
			"event_id": GRAND_CASINO_HIGH_ROLLER_EVENT_ID,
			"route": GRAND_CASINO_HIGH_ROLLER_EVENT_ID,
			"tier": GRAND_CASINO_PLAYERS_CARD_TIER_GOLD,
			"environment_id": str(current_environment.get("id", "")),
			"message": GRAND_CASINO_ACT_TWO_SEAM_MESSAGE,
		})
	_log_demo_finale_result(high_roller_event_id, GRAND_CASINO_HIGH_ROLLER_EVENT_ID, message, true)
	return {"ok": true, "success": true, "complete": true, "message": message, "status": demo_objective_status()}


func _trigger_grand_casino_showdown(status: Dictionary, trigger_reason: String) -> void:
	var showdown_event_id := str(status.get("showdown_event_id", GRAND_CASINO_SHOWDOWN_EVENT_ID))
	if showdown_event_id.is_empty():
		showdown_event_id = GRAND_CASINO_SHOWDOWN_EVENT_ID
	if trigger_reason == "dirty_money":
		narrative_flags["grand_casino_attention_high_roller_review"] = true
	elif trigger_reason == "forced_heat":
		narrative_flags["grand_casino_attention_forced_heat"] = true
	var sources := _copy_array(status.get("staff_attention_sources", []))
	if trigger_reason == "dirty_money":
		_append_unique_string(sources, "high_roller_review")
	elif trigger_reason == "forced_heat":
		_append_unique_string(sources, "forced_heat")
	narrative_flags["grand_casino_staff_attention_sources"] = sources
	narrative_flags["grand_casino_staff_attention"] = not sources.is_empty()
	narrative_flags["grand_casino_endgame_state"] = GRAND_CASINO_STATE_SHOWDOWN_PENDING
	narrative_flags["grand_casino_showdown_pending"] = true
	narrative_flags["grand_casino_showdown_trigger_reason"] = trigger_reason
	narrative_flags["grand_casino_high_roller_ready"] = false
	narrative_flags["high_roller_cashout_pending"] = false
	_log_grand_casino_heat_reroute(showdown_event_id, trigger_reason, sources)
	var objective := _copy_dict(current_environment.get("demo_objective", {}))
	objective["finale_event_id"] = showdown_event_id
	objective["finale_trigger_message"] = "Rourke calls you to the back room."
	_trigger_demo_finale(status, objective)


func _log_grand_casino_heat_reroute(showdown_event_id: String, trigger_reason: String, sources: Array) -> void:
	if _story_log_has_type("grand_casino_heat_reroute", showdown_event_id):
		return
	var message := "Rourke calls you to the back room."
	if trigger_reason == "forced_heat":
		message = "A heat spike puts Rourke's crew on you."
	elif trigger_reason == "heat_attention":
		message = "Staff attention turns your heat into Rourke's call."
	elif trigger_reason == "dirty_money":
		message = "The Players Card review sends the win to Rourke."
	log_story({
		"type": "grand_casino_heat_reroute",
		"event_id": showdown_event_id,
		"trigger_reason": trigger_reason,
		"attention_sources": sources.duplicate(true),
		"environment_id": str(current_environment.get("id", "")),
		"environment_archetype_id": str(current_environment.get("archetype_id", "")),
		"heat": suspicion_level(),
		"message": message,
	})


# Returns the current serialized back-room phase and playable duel state.
func grand_casino_showdown_status(config: Dictionary = {}, _preview_choice_id: String = "") -> Dictionary:
	var duel_terms := _copy_dict(narrative_flags.get("grand_casino_duel_terms", {}))
	return {
		"event_id": GRAND_CASINO_SHOWDOWN_EVENT_ID,
		"pending": bool(narrative_flags.get("grand_casino_showdown_pending", false)),
		"active": bool(narrative_flags.get("grand_casino_showdown_active", false)),
		"step": str(narrative_flags.get("grand_casino_showdown_step", "")),
		"attempt": maxi(0, int(narrative_flags.get("grand_casino_showdown_attempt", 0))),
		"trigger_reason": str(narrative_flags.get("grand_casino_showdown_trigger_reason", "")),
		"pressure_choice": str(narrative_flags.get("grand_casino_showdown_pressure_choice", "")),
		"walk": grand_casino_showdown_walk_status(),
		"pat_down": _copy_dict(narrative_flags.get("grand_casino_showdown_pat_down", {})),
		"interrogation": grand_casino_showdown_interrogation_status(config),
		"duel_terms": duel_terms,
		"duel": _copy_dict(narrative_flags.get("grand_casino_duel_state", {})),
	}


func grand_casino_showdown_walk_status() -> Dictionary:
	return {
		"ditch_used": bool(narrative_flags.get("grand_casino_showdown_ditch_used", false)),
		"method": str(narrative_flags.get("grand_casino_showdown_ditch_method", "")),
		"item_id": str(narrative_flags.get("grand_casino_showdown_ditch_item_id", "")),
		"crew_available": GrandCasinoShowdownModelScript.crew_interacted(narrative_flags, debt),
		"inventory": inventory.duplicate(true),
		"trash_seen": bool(narrative_flags.get("grand_casino_showdown_trash_seen", false)),
		"trash_flavor": str(narrative_flags.get("grand_casino_showdown_trash_flavor", "")),
	}


func grand_casino_showdown_interrogation_status(config: Dictionary = {}) -> Dictionary:
	var evidence_ids := _copy_array(narrative_flags.get("grand_casino_showdown_interrogation_evidence", []))
	var beat_index := maxi(0, int(narrative_flags.get("grand_casino_showdown_interrogation_beat", 0)))
	var interrogation_config := _copy_dict(config.get("interrogation", {}))
	var definitions := _copy_array(interrogation_config.get("evidence", []))
	var evidence_definition := _showdown_evidence_definition(definitions, str(evidence_ids[beat_index]) if beat_index < evidence_ids.size() else "")
	var snapshot := _grand_casino_showdown_fact_snapshot()
	return {
		"beat_index": beat_index,
		"beat_number": mini(evidence_ids.size(), beat_index + 1) if not evidence_ids.is_empty() else 0,
		"beat_count": evidence_ids.size(),
		"evidence_ids": evidence_ids,
		"evidence_id": str(evidence_definition.get("id", "")),
		"evidence_text": GrandCasinoShowdownModelScript.evidence_text(evidence_definition, snapshot) if not evidence_definition.is_empty() else "",
		"answers": _copy_array(narrative_flags.get("grand_casino_showdown_interrogation_answers", [])),
		"stakes": _copy_dict(snapshot.get("modifiers", {})),
	}


func grand_casino_showdown_interrogation_choices(config: Dictionary = {}) -> Array:
	if str(narrative_flags.get("grand_casino_showdown_step", "")) != GRAND_CASINO_SHOWDOWN_STEP_INTERROGATION:
		return []
	var interrogation_config := _copy_dict(config.get("interrogation", {}))
	var snapshot := _grand_casino_showdown_fact_snapshot()
	var choices: Array = []
	for choice_value in _copy_array(interrogation_config.get("choices", [])):
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice := (choice_value as Dictionary).duplicate(true)
		var choice_id := str(choice.get("id", ""))
		var strength := GrandCasinoShowdownModelScript.response_strength(choice_id, snapshot)
		choice["strength"] = int(strength.get("strength", 0))
		choice["pressure_modifier"] = int(strength.get("pressure_modifier", 0))
		choice["fact_modifier"] = int(strength.get("fact_modifier", 0))
		choice["fact_label"] = str(strength.get("fact_label", "the run record"))
		choice["text"] = str(choice.get("text", "")).replace("{strength}", _signed_showdown_value(int(choice["strength"])))
		choice["consequence_summary"] = str(choice.get("consequence_summary", "")).replace("{strength}", _signed_showdown_value(int(choice["strength"])))
		choices.append(choice)
	return choices


# Starts the saveable back-room beat without resolving the final check.
func start_grand_casino_showdown(config: Dictionary = {}) -> Dictionary:
	if run_status == RUN_STATUS_ENDED or run_status == RUN_STATUS_FAILED:
		return {"ok": false, "message": "The run is already over."}
	if not _is_grand_casino_environment(current_environment):
		return {"ok": false, "message": "Rourke is not here."}
	if tutorial_main_floor_only():
		return {"ok": false, "message": "Rourke is only watching tonight. The tutorial stays on the Main Floor."}
	if not bool(narrative_flags.get("grand_casino_showdown_pending", false)) and not bool(narrative_flags.get("the_house_calls_pending", false)) and not bool(narrative_flags.get("grand_casino_showdown_active", false)):
		return {"ok": false, "message": "Rourke has not called yet."}
	_initialize_grand_casino_objective_runtime()
	if bool(narrative_flags.get("grand_casino_showdown_active", false)):
		return {"ok": true, "message": "Rourke waits in the back room.", "status": grand_casino_showdown_status(config)}
	var status := demo_objective_status()
	var attempt := maxi(0, int(narrative_flags.get("grand_casino_showdown_attempt", 0))) + 1
	var sources := _copy_array(status.get("staff_attention_sources", narrative_flags.get("grand_casino_staff_attention_sources", [])))
	var trigger_reason := str(narrative_flags.get("grand_casino_showdown_trigger_reason", "")).strip_edges()
	if trigger_reason.is_empty():
		trigger_reason = "manual_event_resume"
	narrative_flags["grand_casino_showdown_attempt"] = attempt
	narrative_flags["grand_casino_showdown_start_heat"] = suspicion_level()
	narrative_flags["grand_casino_showdown_attention_sources"] = sources
	narrative_flags["grand_casino_showdown_trigger_reason"] = trigger_reason
	narrative_flags["grand_casino_showdown_pending"] = false
	narrative_flags["grand_casino_showdown_active"] = true
	narrative_flags["grand_casino_showdown_step"] = GRAND_CASINO_SHOWDOWN_STEP_WALK
	narrative_flags["grand_casino_endgame_state"] = GRAND_CASINO_STATE_SHOWDOWN_ACTIVE
	narrative_flags["grand_casino_high_roller_ready"] = false
	narrative_flags["high_roller_cashout_pending"] = false
	narrative_flags["demo_finale_ready"] = true
	narrative_flags["demo_finale_pending"] = true
	narrative_flags["demo_finale_event_id"] = GRAND_CASINO_SHOWDOWN_EVENT_ID
	narrative_flags["the_house_calls_pending"] = true
	narrative_flags.erase("grand_casino_showdown_pressure_choice")
	narrative_flags.erase("grand_casino_showdown_roll")
	narrative_flags.erase("grand_casino_showdown_success_chance")
	narrative_flags.erase("grand_casino_showdown_margin")
	narrative_flags.erase("grand_casino_showdown_success")
	narrative_flags["grand_casino_showdown_ditch_used"] = false
	narrative_flags.erase("grand_casino_showdown_ditch_method")
	narrative_flags.erase("grand_casino_showdown_ditch_item_id")
	narrative_flags.erase("grand_casino_showdown_crew_handoff_item_id")
	narrative_flags.erase("grand_casino_showdown_trash_seen")
	narrative_flags.erase("grand_casino_showdown_trash_flavor")
	narrative_flags.erase("grand_casino_showdown_pat_down")
	narrative_flags.erase("grand_casino_showdown_interrogation_evidence")
	narrative_flags.erase("grand_casino_showdown_interrogation_beat")
	narrative_flags.erase("grand_casino_showdown_interrogation_answers")
	narrative_flags.erase("grand_casino_duel_terms")
	narrative_flags.erase("grand_casino_duel_state")
	narrative_flags.erase("grand_casino_duel_outcome")
	narrative_flags.erase("grand_casino_walked_with_chips")
	narrative_flags.erase("grand_casino_uncashed_chip_amount")
	narrative_flags.erase("grand_casino_uncashed_chip_score_percent")
	narrative_flags.erase("grand_casino_uncashed_chip_score_value")
	log_story({
		"type": "grand_casino_showdown_arrival",
		"event_id": GRAND_CASINO_SHOWDOWN_EVENT_ID,
		"attempt": attempt,
		"trigger_reason": trigger_reason,
		"attention_sources": sources.duplicate(true),
		"heat": suspicion_level(),
		"environment_id": str(current_environment.get("id", "")),
		"environment_archetype_id": str(current_environment.get("archetype_id", "")),
		"message": "Rourke takes you to the back room.",
	})
	return {
		"ok": true,
		"message": "Rourke walks you past the floor. One pocket can change before the door.",
		"status": grand_casino_showdown_status(config),
	}


func resolve_grand_casino_showdown_walk(method: String, item_id: String, config: Dictionary = {}) -> Dictionary:
	if not bool(narrative_flags.get("grand_casino_showdown_active", false)):
		return {"ok": false, "message": "The walk has not started."}
	if str(narrative_flags.get("grand_casino_showdown_step", "")) != GRAND_CASINO_SHOWDOWN_STEP_WALK:
		return {"ok": false, "message": "The walk choice is already settled."}
	if bool(narrative_flags.get("grand_casino_showdown_ditch_used", false)):
		return {"ok": false, "message": "Only one pocket changes on this walk."}
	var clean_method := method.strip_edges().to_lower()
	var clean_item_id := item_id.strip_edges()
	if not ["crew", "trash", "keep"].has(clean_method):
		return {"ok": false, "message": "That walk choice is not available."}
	if clean_method != "keep" and (clean_item_id.is_empty() or not inventory.has(clean_item_id)):
		return {"ok": false, "message": "That item is no longer in your pocket."}
	if clean_method == "crew" and not GrandCasinoShowdownModelScript.crew_interacted(narrative_flags, debt):
		return {"ok": false, "message": "The Crew has no reason to take your handoff."}
	narrative_flags["grand_casino_showdown_ditch_used"] = true
	narrative_flags["grand_casino_showdown_ditch_method"] = clean_method
	narrative_flags["grand_casino_showdown_ditch_item_id"] = clean_item_id
	var walk_config := _copy_dict(config.get("walk", {}))
	var message := "You keep every pocket as Rourke walks."
	var heat_sting := 0
	if clean_method == "crew":
		remove_item(clean_item_id)
		narrative_flags["grand_casino_showdown_crew_handoff_item_id"] = clean_item_id
		message = "The Crew takes %s before the back-room door." % _showdown_item_label(clean_item_id)
	elif clean_method == "trash":
		remove_item(clean_item_id)
		var attempt := maxi(1, int(narrative_flags.get("grand_casino_showdown_attempt", 1)))
		var trash_rng := create_rng("grand_casino_showdown_walk").fork("attempt:%d:item:%s" % [attempt, clean_item_id])
		var flavors := _copy_array(walk_config.get("trash_flavors", []))
		var flavor: Dictionary = (trash_rng.pick(flavors, {}) as Dictionary).duplicate(true) if not flavors.is_empty() else {}
		var flavor_id := str(flavor.get("id", "discard"))
		var seen_chance := clampi(int(walk_config.get("trash_seen_chance_percent", 15)), 0, 100)
		var seen := trash_rng.randi_range(1, 100) <= seen_chance
		narrative_flags["grand_casino_showdown_trash_flavor"] = flavor_id
		narrative_flags["grand_casino_showdown_trash_seen"] = seen
		message = str(flavor.get("message", "The item disappears before the search."))
		if seen:
			heat_sting = add_suspicion("grand_casino_showdown_trash_seen", maxi(0, int(walk_config.get("trash_seen_heat", 4))), "behavior", false, {
				"action_kind": "showdown",
				"room_id": _grand_casino_room_id_for_environment(current_environment),
			})
			message += " A floor attendant sees the motion."
	log_story({
		"type": "grand_casino_showdown_walk",
		"event_id": GRAND_CASINO_SHOWDOWN_EVENT_ID,
		"method": clean_method,
		"item_id": clean_item_id,
		"trash_seen": bool(narrative_flags.get("grand_casino_showdown_trash_seen", false)),
		"suspicion_delta": heat_sting,
		"message": message,
	})
	var pat_down := _apply_grand_casino_showdown_pat_down(config)
	if is_terminal():
		return {"ok": true, "success": false, "message": str(pat_down.get("message", message)), "status": grand_casino_showdown_status(config)}
	return {"ok": true, "message": "%s %s" % [message, str(pat_down.get("message", ""))], "status": grand_casino_showdown_status(config)}


func continue_grand_casino_showdown_pat_down(config: Dictionary = {}) -> Dictionary:
	if not bool(narrative_flags.get("grand_casino_showdown_active", false)) or str(narrative_flags.get("grand_casino_showdown_step", "")) != GRAND_CASINO_SHOWDOWN_STEP_PAT_DOWN:
		return {"ok": false, "message": "The search is not waiting."}
	_prepare_grand_casino_showdown_interrogation(config)
	var status := grand_casino_showdown_interrogation_status(config)
	return {
		"ok": true,
		"message": str(status.get("evidence_text", "Rourke opens the run ledger.")),
		"status": grand_casino_showdown_status(config),
	}


func resolve_grand_casino_showdown_interrogation(choice_id: String, config: Dictionary = {}) -> Dictionary:
	if not bool(narrative_flags.get("grand_casino_showdown_active", false)) or str(narrative_flags.get("grand_casino_showdown_step", "")) != GRAND_CASINO_SHOWDOWN_STEP_INTERROGATION:
		return {"ok": false, "message": "Rourke is not waiting on that answer."}
	var selected_choice: Dictionary = {}
	for choice_value in grand_casino_showdown_interrogation_choices(config):
		if typeof(choice_value) == TYPE_DICTIONARY and str((choice_value as Dictionary).get("id", "")) == choice_id:
			selected_choice = (choice_value as Dictionary).duplicate(true)
			break
	if selected_choice.is_empty():
		return {"ok": false, "message": "That answer is not available."}
	var interrogation := grand_casino_showdown_interrogation_status(config)
	var beat_index := maxi(0, int(interrogation.get("beat_index", 0)))
	var answer := {
		"beat": beat_index + 1,
		"evidence_id": str(interrogation.get("evidence_id", "")),
		"choice_id": choice_id,
		"strength": int(selected_choice.get("strength", 0)),
		"pressure_modifier": int(selected_choice.get("pressure_modifier", 0)),
		"fact_modifier": int(selected_choice.get("fact_modifier", 0)),
	}
	var answers := _copy_array(narrative_flags.get("grand_casino_showdown_interrogation_answers", []))
	answers.append(answer)
	narrative_flags["grand_casino_showdown_interrogation_answers"] = answers
	narrative_flags["grand_casino_showdown_interrogation_beat"] = beat_index + 1
	narrative_flags["grand_casino_showdown_pressure_choice"] = choice_id
	if choice_id == "take_the_edge":
		narrative_flags["grand_casino_showdown_edge_taken"] = true
		narrative_flags["grand_casino_cheat_evidence"] = true
		narrative_flags["grand_casino_watched_cheat_evidence"] = true
		narrative_flags["grand_casino_attention_watched_cheat"] = true
	log_story({
		"type": "grand_casino_showdown_interrogation",
		"event_id": GRAND_CASINO_SHOWDOWN_EVENT_ID,
		"beat": beat_index + 1,
		"evidence_id": str(answer.get("evidence_id", "")),
		"choice_id": choice_id,
		"strength": int(answer.get("strength", 0)),
		"message": "Rourke records the answer and turns the page.",
	})
	var evidence_ids := _copy_array(narrative_flags.get("grand_casino_showdown_interrogation_evidence", []))
	if beat_index + 1 < evidence_ids.size():
		var next_status := grand_casino_showdown_interrogation_status(config)
		return {
			"ok": true,
			"message": str(next_status.get("evidence_text", "Rourke turns the page.")),
			"status": grand_casino_showdown_status(config),
		}
	var terms := _build_grand_casino_duel_terms(config)
	narrative_flags["grand_casino_duel_terms"] = terms
	var duel := _begin_grand_casino_duel(terms)
	log_story({
		"type": "grand_casino_duel_terms",
		"event_id": GRAND_CASINO_SHOWDOWN_EVENT_ID,
		"player_stack": int(_copy_dict(terms.get("starting_stacks", {})).get("player", 0)),
		"rourke_stack": int(_copy_dict(terms.get("starting_stacks", {})).get("rourke", 0)),
		"rourke_aggression": int(terms.get("rourke_aggression", 0)),
		"rourke_cheat_level": int(terms.get("rourke_cheat_level", 0)),
		"message": "The questions set the chips and Rourke's edge.",
	})
	return {
		"ok": true,
		"duel_ready": true,
		"message": str(duel.get("last_bark", "Rourke cuts the cards in the Back Room.")),
		"duel": duel,
		"status": grand_casino_showdown_status(config),
	}


# Migrates a slice-6 boundary save into the playable duel without rolling an
# outcome. No current event path calls this compatibility entry point.
func resolve_grand_casino_showdown_pressure(choice_id: String, config: Dictionary = {}) -> Dictionary:
	if not bool(narrative_flags.get("grand_casino_showdown_active", false)):
		return {"ok": false, "message": "The showdown is not active."}
	if str(narrative_flags.get("grand_casino_showdown_step", "")) != GRAND_CASINO_SHOWDOWN_STEP_LEGACY_CHECK or _copy_dict(narrative_flags.get("grand_casino_duel_terms", {})).is_empty():
		return {"ok": false, "message": "Rourke still has questions before the game."}
	if not choice_id.strip_edges().is_empty():
		narrative_flags["grand_casino_showdown_pressure_choice"] = choice_id.strip_edges()
	var duel := _begin_grand_casino_duel(_copy_dict(narrative_flags.get("grand_casino_duel_terms", {})))
	return {"ok": true, "duel_ready": true, "message": str(duel.get("last_bark", "Rourke cuts the cards.")), "duel": duel}


func _begin_grand_casino_duel(terms: Dictionary) -> Dictionary:
	var existing := _copy_dict(narrative_flags.get("grand_casino_duel_state", {}))
	if not existing.is_empty() and str(existing.get("status", "")) == "active":
		narrative_flags["grand_casino_showdown_step"] = GRAND_CASINO_SHOWDOWN_STEP_DUEL
		return existing
	var attempt := maxi(1, int(narrative_flags.get("grand_casino_showdown_attempt", 1)))
	var duel_rng := create_rng("grand_casino_duel").fork("attempt:%d:setup" % attempt)
	var duel := GrandCasinoDuelModelScript.initialize(terms, duel_rng)
	duel["attempt"] = attempt
	duel["input_index"] = 0
	narrative_flags["grand_casino_duel_state"] = duel.duplicate(true)
	narrative_flags["grand_casino_showdown_step"] = GRAND_CASINO_SHOWDOWN_STEP_DUEL
	narrative_flags.erase("grand_casino_showdown_roll")
	narrative_flags.erase("grand_casino_showdown_success_chance")
	narrative_flags.erase("grand_casino_showdown_modifiers")
	return duel


func grand_casino_duel_active(environment: Dictionary = {}) -> bool:
	var source := current_environment if environment.is_empty() else environment
	return (
		_is_grand_casino_environment(source)
		and bool(narrative_flags.get("grand_casino_showdown_active", false))
		and str(narrative_flags.get("grand_casino_showdown_step", "")) == GRAND_CASINO_SHOWDOWN_STEP_DUEL
		and str(_copy_dict(narrative_flags.get("grand_casino_duel_state", {})).get("status", "")) == "active"
	)


func grand_casino_duel_status() -> Dictionary:
	var state := _copy_dict(narrative_flags.get("grand_casino_duel_state", {}))
	if state.is_empty() and bool(narrative_flags.get("grand_casino_showdown_active", false)) and not _copy_dict(narrative_flags.get("grand_casino_duel_terms", {})).is_empty():
		state = _begin_grand_casino_duel(_copy_dict(narrative_flags.get("grand_casino_duel_terms", {})))
	return state


func grand_casino_duel_terms() -> Dictionary:
	return _copy_dict(narrative_flags.get("grand_casino_duel_terms", {}))


func grand_casino_duel_session() -> Dictionary:
	return _copy_dict(grand_casino_duel_status().get("blackjack_session", {}))


func persist_grand_casino_duel_session(session: Dictionary) -> void:
	var state := grand_casino_duel_status()
	if str(state.get("status", "")) != "active":
		return
	var saved := session.duplicate(true)
	for key in ["surface_time_msec", "drunk_scaled_surface_time_msec"]:
		saved.erase(key)
	state["blackjack_session"] = saved
	narrative_flags["grand_casino_duel_state"] = state


func grand_casino_duel_action_time_msec() -> int:
	var state := grand_casino_duel_status()
	var input_index := maxi(0, int(state.get("input_index", 0))) + 1
	state["input_index"] = input_index
	narrative_flags["grand_casino_duel_state"] = state
	return simulation_time_msec() + input_index * 250


func grand_casino_duel_current_edge() -> Dictionary:
	return GrandCasinoDuelModelScript.current_edge(grand_casino_duel_status())


func grand_casino_duel_call_out(edge_id: String) -> Dictionary:
	var terms := grand_casino_duel_terms()
	var outcome := GrandCasinoDuelModelScript.call_out(grand_casino_duel_status(), edge_id, terms)
	if not bool(outcome.get("ok", false)):
		return outcome
	var state := _copy_dict(outcome.get("state", {}))
	narrative_flags["grand_casino_duel_state"] = state
	log_story({
		"type": "grand_casino_duel_callout",
		"event_id": GRAND_CASINO_SHOWDOWN_EVENT_ID,
		"hand": int(state.get("hand_index", 0)) + 1,
		"edge_id": edge_id,
		"correct": bool(outcome.get("correct", false)),
		"stack_swing": int(outcome.get("swing", 0)),
		"message": str(outcome.get("message", "Rourke marks the call.")),
	})
	_finalize_grand_casino_duel_if_complete(state)
	outcome["state"] = state
	return outcome


func apply_grand_casino_duel_hand(hand_result: Dictionary) -> Dictionary:
	var terms := grand_casino_duel_terms()
	var outcome := GrandCasinoDuelModelScript.apply_hand(grand_casino_duel_status(), hand_result, terms)
	if not bool(outcome.get("ok", false)):
		return outcome
	var state := _copy_dict(outcome.get("state", {}))
	narrative_flags["grand_casino_duel_state"] = state
	var recorded_hands := _copy_array(state.get("hands", []))
	var recorded := _copy_dict(recorded_hands.back()) if not recorded_hands.is_empty() else {}
	log_story({
		"type": "grand_casino_duel_hand",
		"event_id": GRAND_CASINO_SHOWDOWN_EVENT_ID,
		"hand": int(recorded.get("hand_index", 0)) + 1,
		"transfer": int(recorded.get("transfer", 0)),
		"player_stack": int(state.get("player_stack", 0)),
		"rourke_stack": int(state.get("rourke_stack", 0)),
		"player_cheat_caught": bool(recorded.get("player_cheat_caught", false)),
		"message": str(hand_result.get("message", "The house table settles one hand.")),
	})
	_finalize_grand_casino_duel_if_complete(state)
	outcome["state"] = state
	return outcome


func _finalize_grand_casino_duel_if_complete(state: Dictionary) -> void:
	if str(state.get("status", "")) != "complete":
		return
	var outcome := str(state.get("outcome", ""))
	var margin := int(state.get("margin", int(state.get("player_stack", 0)) - int(state.get("rourke_stack", 0))))
	narrative_flags["grand_casino_duel_outcome"] = outcome
	narrative_flags["grand_casino_showdown_margin"] = margin
	narrative_flags["grand_casino_showdown_success"] = outcome != GrandCasinoDuelModelScript.OUTCOME_TAKEN_OUT_BACK
	narrative_flags["grand_casino_duel_hands_played"] = _copy_array(state.get("hands", [])).size()
	match outcome:
		GrandCasinoDuelModelScript.OUTCOME_WALK_OUT_CLEAN:
			var cashed_chips := grand_casino_chips
			if cashed_chips > 0:
				cash_out_grand_casino_chips(cashed_chips, grand_casino_chip_exchange_rate())
			narrative_flags["grand_casino_duel_cashed_chip_amount"] = cashed_chips
			_complete_grand_casino_showdown_success("You take Rourke's stack. Linda cashes the rack, and the elevator opens.")
		GrandCasinoDuelModelScript.OUTCOME_SHOWN_THE_DOOR:
			_complete_grand_casino_showdown_shown_door()
		_:
			_complete_grand_casino_showdown_failure("Rourke takes the last hand. The casino takes you out back, and the run ends.")


func _complete_grand_casino_showdown_shown_door() -> void:
	var chip_amount := maxi(0, grand_casino_chips)
	var rules := _copy_dict(grand_casino_duel_terms().get("rules", {}))
	var score_percent := clampi(int(rules.get("uncashed_chip_score_percent", 50)), 0, 100)
	var score_value := int(floor(float(chip_amount * score_percent) / 100.0))
	narrative_flags["grand_casino_walked_with_chips"] = true
	narrative_flags["grand_casino_uncashed_chip_amount"] = chip_amount
	narrative_flags["grand_casino_uncashed_chip_score_percent"] = score_percent
	narrative_flags["grand_casino_uncashed_chip_score_value"] = score_value
	narrative_flags["demo_finale_last_branch"] = GrandCasinoDuelModelScript.OUTCOME_SHOWN_THE_DOOR
	_return_grand_casino_crew_handoff()
	_clear_grand_casino_showdown_terminal_flags()
	narrative_flags["grand_casino_endgame_state"] = GRAND_CASINO_STATE_VICTORY
	var message := "Rourke opens the service door but closes the Cage. You leave with %d uncashed house chips." % chip_amount
	var status := demo_objective_status()
	if not bool(status.get("grand_casino_objective", false)):
		status = {"id": GRAND_CASINO_OBJECTIVE_ID, "target_bankroll": bankroll, "victory_message": message}
	_complete_demo_objective(status, message, {
		"finale_event_id": GRAND_CASINO_SHOWDOWN_EVENT_ID,
		"finale_branch": GrandCasinoDuelModelScript.OUTCOME_SHOWN_THE_DOOR,
		"demo_victory_route": GRAND_CASINO_SHOWDOWN_ROUTE,
	})
	_log_demo_finale_result(GRAND_CASINO_SHOWDOWN_EVENT_ID, GrandCasinoDuelModelScript.OUTCOME_SHOWN_THE_DOOR, message, true)


func _apply_grand_casino_showdown_pat_down(config: Dictionary) -> Dictionary:
	var pat_down_config := _copy_dict(config.get("pat_down", {}))
	var pat_down := GrandCasinoShowdownModelScript.pat_down(
		inventory,
		pat_down_config,
		bool(narrative_flags.get("grand_casino_watched_cheat_evidence", false))
	)
	var confiscated := _copy_array(pat_down.get("confiscated_items", []))
	for item_value in confiscated:
		remove_item(str(item_value))
	narrative_flags["grand_casino_showdown_pat_down"] = pat_down.duplicate(true)
	narrative_flags["grand_casino_showdown_step"] = GRAND_CASINO_SHOWDOWN_STEP_PAT_DOWN
	var tier := str(pat_down.get("tier", "clean"))
	var tier_messages := _copy_dict(pat_down_config.get("tier_messages", {}))
	var message := str(tier_messages.get(tier, "Rourke's search ends."))
	log_story({
		"type": "grand_casino_showdown_pat_down",
		"event_id": GRAND_CASINO_SHOWDOWN_EVENT_ID,
		"tier": tier,
		"contraband_items": _copy_array(pat_down.get("contraband_items", [])),
		"surveillance_items": _copy_array(pat_down.get("surveillance_items", [])),
		"confiscated_items": confiscated,
		"handicap": int(pat_down.get("handicap", 0)),
		"message": message,
	})
	if tier == "blatant":
		message = str(pat_down_config.get("blatant_failure_message", "Rourke finds a loaded cheating kit. The casino takes you out back before the game begins."))
		narrative_flags["grand_casino_showdown_success"] = false
		_complete_grand_casino_showdown_failure(message)
	return {"tier": tier, "message": message, "pat_down": pat_down}


func _prepare_grand_casino_showdown_interrogation(config: Dictionary) -> void:
	var interrogation_config := _copy_dict(config.get("interrogation", {}))
	var beat_count := maxi(1, int(interrogation_config.get("beat_count", 3)))
	var attempt := maxi(1, int(narrative_flags.get("grand_casino_showdown_attempt", 1)))
	var evidence_rng := create_rng("grand_casino_showdown_interrogation").fork("attempt:%d:evidence" % attempt)
	var selected := GrandCasinoShowdownModelScript.select_evidence(
		_grand_casino_showdown_fact_snapshot(),
		_copy_array(interrogation_config.get("evidence", [])),
		beat_count,
		evidence_rng
	)
	var evidence_ids: Array = []
	for evidence_value in selected:
		if typeof(evidence_value) == TYPE_DICTIONARY:
			evidence_ids.append(str((evidence_value as Dictionary).get("id", "")))
	narrative_flags["grand_casino_showdown_interrogation_evidence"] = evidence_ids
	narrative_flags["grand_casino_showdown_interrogation_beat"] = 0
	narrative_flags["grand_casino_showdown_interrogation_answers"] = []
	narrative_flags["grand_casino_showdown_step"] = GRAND_CASINO_SHOWDOWN_STEP_INTERROGATION


func _grand_casino_showdown_fact_snapshot() -> Dictionary:
	var open_debt_count := 0
	for debt_value in debt:
		if typeof(debt_value) != TYPE_DICTIONARY:
			continue
		var debt_data: Dictionary = debt_value
		if ["active", "overdue", "favor_due"].has(str(debt_data.get("status", "active"))):
			open_debt_count += 1
	var tier := str(narrative_flags.get("grand_casino_players_card_highest_tier", narrative_flags.get("grand_casino_players_card_tier", GRAND_CASINO_PLAYERS_CARD_TIER_NONE)))
	var linda_standing := clampi(_grand_casino_players_card_tier_index(tier) * 2, 0, 6)
	for story_value in story_log:
		if typeof(story_value) != TYPE_DICTIONARY:
			continue
		var story: Dictionary = story_value
		if str(story.get("type", "")) == "service_hook" and str(story.get("id", "")).begins_with("players_card_"):
			linda_standing = mini(6, linda_standing + 1)
	var prior_cameo := _story_log_has_type("event", "rourke_scouting_cameo")
	prior_cameo = prior_cameo or bool(narrative_flags.get("grand_casino_event_pit_boss_sweep_lay_low", false)) or bool(narrative_flags.get("grand_casino_event_eye_in_the_sky_press_anyway", false))
	var used_surveillance := false
	for item_id in ["xray_glasses", "tab_detector", "tarot_card"]:
		if bool(narrative_flags.get("grand_casino_used_%s" % item_id, false)):
			used_surveillance = true
			break
	return {
		"heat": suspicion_level(),
		"watched_cheat": bool(narrative_flags.get("grand_casino_watched_cheat_evidence", false)),
		"cheat_evidence": bool(narrative_flags.get("grand_casino_cheat_evidence", false)),
		"card_ineligible": bool(narrative_flags.get("grand_casino_players_card_ineligible", false)),
		"attention_sources": _copy_array(narrative_flags.get("grand_casino_showdown_attention_sources", narrative_flags.get("grand_casino_staff_attention_sources", []))),
		"open_debt_count": open_debt_count,
		"drunk_level": drunk_level,
		"games_played": maxi(0, int(narrative_flags.get("grand_casino_games_played", 0))),
		"net_winnings": int(narrative_flags.get("grand_casino_net_winnings", 0)),
		"prior_cameo": prior_cameo,
		"linda_standing": linda_standing,
		"crew_ties": GrandCasinoShowdownModelScript.crew_interacted(narrative_flags, debt),
		"used_surveillance": used_surveillance,
		"modifiers": _grand_casino_showdown_modifier_breakdown("hold_steady"),
	}


func _build_grand_casino_duel_terms(config: Dictionary) -> Dictionary:
	return GrandCasinoShowdownModelScript.build_duel_terms(
		_grand_casino_showdown_fact_snapshot(),
		_copy_dict(narrative_flags.get("grand_casino_showdown_pat_down", {})),
		_copy_array(narrative_flags.get("grand_casino_showdown_interrogation_answers", [])),
		_copy_array(narrative_flags.get("grand_casino_showdown_interrogation_evidence", [])),
		_copy_dict(config.get("duel_terms", {}))
	)


func _showdown_evidence_definition(definitions: Array, evidence_id: String) -> Dictionary:
	for definition_value in definitions:
		if typeof(definition_value) == TYPE_DICTIONARY and str((definition_value as Dictionary).get("id", "")) == evidence_id:
			return (definition_value as Dictionary).duplicate(true)
	return {}


func _showdown_item_label(item_id: String) -> String:
	var definition := _item_definition(item_id)
	return str(definition.get("display_name", item_id.replace("_", " ").capitalize()))


func _signed_showdown_value(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


# Applies the finale branch emitted by the landmark event or future duel surface.
func apply_demo_finale_result(finale_data: Dictionary) -> Dictionary:
	if finale_data.is_empty():
		return demo_objective_status()
	var event_id := str(finale_data.get("event_id", narrative_flags.get("demo_finale_event_id", ""))).strip_edges()
	var branch := str(finale_data.get("branch", finale_data.get("outcome", ""))).strip_edges()
	var status := demo_objective_status()
	var default_message := str(status.get("victory_message", "Demo Victory: you beat the house for now."))
	var message := str(finale_data.get("message", default_message)).strip_edges()
	if message.is_empty():
		message = default_message
	if event_id == GRAND_CASINO_HIGH_ROLLER_EVENT_ID and ["win", "win_clean", "win_uncaught"].has(branch):
		return complete_grand_casino_high_roller_cashout({"success_message": message})
	match branch:
		"win", "win_clean", "win_uncaught":
			_clear_demo_finale_pending(event_id)
			_complete_demo_objective(status, message, {
				"finale_event_id": event_id,
				"finale_branch": branch,
			})
		"caught", "caught_cheating":
			_clear_demo_finale_pending(event_id)
			narrative_flags["demo_finale_caught"] = true
			narrative_flags["demo_finale_last_branch"] = branch
			fail_run(FAILURE_POLICE_CAPTURE, message if not message.is_empty() else POLICE_CAPTURE_FAILURE_MESSAGE)
			_log_demo_finale_result(event_id, branch, message, true)
		"lose", "lose_duel":
			narrative_flags["demo_finale_last_branch"] = branch
			narrative_flags["demo_finale_pending"] = has_liquid_run_funds()
			if not event_id.is_empty():
				narrative_flags["demo_finale_event_id"] = event_id
				narrative_flags["%s_pending" % event_id] = has_liquid_run_funds()
				_ensure_current_event_id(event_id)
			if not has_liquid_run_funds():
				_clear_demo_finale_pending(event_id)
				fail_run(FAILURE_BANKROLL_ZERO, BANKROLL_ZERO_FAILURE_MESSAGE)
				_log_demo_finale_result(event_id, branch, BANKROLL_ZERO_FAILURE_MESSAGE, true)
			else:
				_log_demo_finale_result(event_id, branch, message, false)
		_:
			_log_demo_finale_result(event_id, "unknown", message, false)
	return demo_objective_status()


func _complete_grand_casino_showdown_success(message: String) -> void:
	_return_grand_casino_crew_handoff()
	_clear_grand_casino_showdown_terminal_flags()
	narrative_flags["grand_casino_endgame_state"] = GRAND_CASINO_STATE_VICTORY
	var status := demo_objective_status()
	if not bool(status.get("grand_casino_objective", false)):
		status = {
			"id": GRAND_CASINO_OBJECTIVE_ID,
			"target_bankroll": bankroll,
			"victory_message": message,
		}
	_complete_demo_objective(status, message, {
		"finale_event_id": GRAND_CASINO_SHOWDOWN_EVENT_ID,
		"finale_branch": GRAND_CASINO_SHOWDOWN_ROUTE,
		"demo_victory_route": GRAND_CASINO_SHOWDOWN_ROUTE,
	})
	_log_demo_finale_result(GRAND_CASINO_SHOWDOWN_EVENT_ID, GRAND_CASINO_SHOWDOWN_ROUTE, message, true)


func _complete_grand_casino_showdown_failure(message: String) -> void:
	var handoff_item_id := str(narrative_flags.get("grand_casino_showdown_crew_handoff_item_id", ""))
	if not handoff_item_id.is_empty():
		narrative_flags["grand_casino_showdown_crew_handoff_lost_on_failure"] = handoff_item_id
		narrative_flags.erase("grand_casino_showdown_crew_handoff_item_id")
		log_story({
			"type": "grand_casino_showdown_crew_handoff_lost",
			"event_id": GRAND_CASINO_SHOWDOWN_EVENT_ID,
			"item_id": handoff_item_id,
			"message": "The Crew cannot return the handoff after Rourke's ending.",
		})
	_clear_grand_casino_showdown_terminal_flags()
	narrative_flags["grand_casino_endgame_state"] = GRAND_CASINO_STATE_FAILURE
	narrative_flags["demo_finale_last_branch"] = FAILURE_CASINO_TAKEN_OUT_BACK
	fail_run(FAILURE_CASINO_TAKEN_OUT_BACK, message)
	_log_demo_finale_result(GRAND_CASINO_SHOWDOWN_EVENT_ID, FAILURE_CASINO_TAKEN_OUT_BACK, message, true)


func _return_grand_casino_crew_handoff() -> void:
	var handoff_item_id := str(narrative_flags.get("grand_casino_showdown_crew_handoff_item_id", ""))
	if handoff_item_id.is_empty():
		return
	add_item(handoff_item_id)
	narrative_flags.erase("grand_casino_showdown_crew_handoff_item_id")
	narrative_flags["grand_casino_showdown_crew_handoff_returned"] = handoff_item_id
	log_story({
		"type": "grand_casino_showdown_crew_handoff_returned",
		"event_id": GRAND_CASINO_SHOWDOWN_EVENT_ID,
		"item_id": handoff_item_id,
		"message": "The Crew returns the handoff outside the casino.",
	})


func _clear_grand_casino_showdown_terminal_flags() -> void:
	_clear_demo_finale_pending(GRAND_CASINO_SHOWDOWN_EVENT_ID)
	narrative_flags["grand_casino_showdown_pending"] = false
	narrative_flags["grand_casino_showdown_active"] = false
	narrative_flags["grand_casino_high_roller_ready"] = false
	narrative_flags["high_roller_cashout_pending"] = false


func _clear_grand_casino_clean_cashout_ready() -> void:
	narrative_flags["grand_casino_high_roller_ready"] = false
	narrative_flags["high_roller_cashout_pending"] = false
	narrative_flags["%s_pending" % GRAND_CASINO_HIGH_ROLLER_EVENT_ID] = false
	if not bool(narrative_flags.get("grand_casino_showdown_pending", false)) and not bool(narrative_flags.get("grand_casino_showdown_active", false)):
		if run_status == RUN_STATUS_ACTIVE or run_status == RUN_STATUS_DISTRESSED:
			narrative_flags["grand_casino_endgame_state"] = GRAND_CASINO_STATE_PRE


func _grand_casino_showdown_modifier_breakdown(choice_id: String) -> Dictionary:
	var pressure_choice := choice_id.strip_edges()
	var effective_cheat_evidence := bool(narrative_flags.get("grand_casino_cheat_evidence", false))
	var effective_watched_evidence := bool(narrative_flags.get("grand_casino_watched_cheat_evidence", false))
	if pressure_choice == "take_the_edge":
		effective_cheat_evidence = true
		effective_watched_evidence = true
	var pressure_modifier := 0
	match pressure_choice:
		"hold_steady":
			pressure_modifier = -4 if effective_cheat_evidence or effective_watched_evidence else 8
		"talk_down":
			pressure_modifier = 4
		"take_the_edge":
			pressure_modifier = 16
		_:
			pressure_modifier = 0
	var max_heat := 100
	var status := demo_objective_status()
	if bool(status.get("grand_casino_objective", false)):
		max_heat = int(status.get("high_roller_max_heat", 100))
	var heat_penalty := clampi(int(floor(float(maxi(0, suspicion_level() - max_heat)) / 5.0)) * 2, 0, 28)
	var evidence_penalty := 20 if effective_watched_evidence else 10 if effective_cheat_evidence else 0
	var clean_play_modifier := 0
	if not effective_cheat_evidence and not effective_watched_evidence:
		clean_play_modifier = 10 if suspicion_level() <= max_heat else 4
	var item_modifier := _grand_casino_showdown_item_modifier(effective_cheat_evidence or effective_watched_evidence)
	var alcohol_debt_penalty := _grand_casino_showdown_alcohol_debt_penalty()
	var prior_modifier := _grand_casino_showdown_prior_boss_modifier()
	return {
		"pressure_choice_modifier": pressure_modifier,
		"clean_play_modifier": clean_play_modifier,
		"item_modifier": item_modifier,
		"prior_boss_event_modifier": prior_modifier,
		"heat_penalty": heat_penalty,
		"evidence_penalty": evidence_penalty,
		"alcohol_debt_penalty": alcohol_debt_penalty,
	}


func _grand_casino_showdown_item_modifier(has_cheat_evidence: bool) -> int:
	var raw_modifier := 0
	if inventory.has("cheap_sunglasses"):
		raw_modifier += 4
	if inventory.has("card_counters_notes") and not has_cheat_evidence:
		raw_modifier += 4
	if inventory.has("scratch_pad") and not has_cheat_evidence:
		raw_modifier += 2
	if inventory.has("creased_luck_card"):
		raw_modifier += 2
	if inventory.has("lucky_keychain"):
		raw_modifier += 2
	var contraband_count := 0
	for item_id in ["marked_cards", "foil_sleeve", "weighted_keyring"]:
		if inventory.has(item_id):
			contraband_count += 1
	raw_modifier -= mini(18, contraband_count * 6)
	var surveillance_count := 0
	for item_id in ["xray_glasses", "tab_detector", "tarot_card"]:
		if inventory.has(item_id) or bool(narrative_flags.get("grand_casino_used_%s" % item_id, false)):
			surveillance_count += 1
	raw_modifier -= mini(16, surveillance_count * 8)
	return clampi(raw_modifier, -24, 10)


func _grand_casino_showdown_alcohol_debt_penalty() -> int:
	var drunk_penalty := 0
	if drunk_level >= 71:
		drunk_penalty = 14
	elif drunk_level >= 46:
		drunk_penalty = 10
	elif drunk_level >= 26:
		drunk_penalty = 6
	elif drunk_level >= 11:
		drunk_penalty = 3
	var dependence_gap := alcoholic_level - drunk_level
	var dependence_penalty := 0
	if dependence_gap >= 60:
		dependence_penalty = 8
	elif dependence_gap >= 30:
		dependence_penalty = 4
	var open_debt_count := 0
	for debt_entry in debt:
		if typeof(debt_entry) != TYPE_DICTIONARY:
			continue
		var debt_data := debt_entry as Dictionary
		var debt_status := str(debt_data.get("status", "active"))
		if debt_status == "active" or debt_status == "overdue":
			open_debt_count += 1
	var debt_penalty := mini(9, open_debt_count * 3)
	return clampi(drunk_penalty + dependence_penalty + debt_penalty, 0, 24)


func _grand_casino_showdown_prior_boss_modifier() -> int:
	var raw_modifier := 0
	if bool(narrative_flags.get("grand_casino_event_pit_boss_sweep_lay_low", false)):
		raw_modifier += 4
	if bool(narrative_flags.get("grand_casino_event_pit_boss_sweep_act_natural", false)):
		raw_modifier -= 3
	if bool(narrative_flags.get("grand_casino_event_eye_in_the_sky_change_table", false)):
		raw_modifier += 5
	if bool(narrative_flags.get("grand_casino_event_eye_in_the_sky_press_anyway", false)):
		raw_modifier -= 8
	if bool(narrative_flags.get("grand_casino_event_comped_suite_offer_decline", false)):
		raw_modifier += 3
	if bool(narrative_flags.get("grand_casino_event_comped_suite_offer_take_comp", false)):
		raw_modifier -= 4
	return clampi(raw_modifier, -12, 10)


func _complete_demo_objective(status: Dictionary, override_message: String = "", finale_context: Dictionary = {}) -> void:
	var message := str(status.get("victory_message", "Demo Victory: you beat the house for now."))
	if not override_message.strip_edges().is_empty():
		message = override_message.strip_edges()
	narrative_flags["demo_victory"] = true
	narrative_flags["demo_objective_id"] = str(status.get("id", ""))
	narrative_flags["demo_victory_message"] = message
	if not finale_context.is_empty():
		for key in finale_context.keys():
			narrative_flags[str(key)] = finale_context[key]
		narrative_flags["demo_finale_completed"] = true
	run_status = RUN_STATUS_ENDED
	run_failure_reason = FAILURE_NONE
	run_failure_message = ""
	if not _story_log_has_demo_victory(str(status.get("id", ""))):
		var story_entry := {
			"type": "demo_victory",
			"objective_id": str(status.get("id", "")),
			"environment_id": str(current_environment.get("id", "")),
			"environment_archetype_id": str(current_environment.get("archetype_id", "")),
			"bankroll": bankroll,
			"target_bankroll": int(status.get("target_bankroll", 0)),
			"message": message,
			"ended": true,
		}
		for key in finale_context.keys():
			story_entry[str(key)] = finale_context[key]
		log_story(story_entry)


func _trigger_demo_finale(status: Dictionary, objective: Dictionary) -> void:
	var event_id := str(objective.get("finale_event_id", "")).strip_edges()
	if event_id.is_empty():
		return
	_ensure_current_event_id(event_id)
	narrative_flags["demo_finale_ready"] = true
	narrative_flags["demo_finale_pending"] = true
	narrative_flags["demo_finale_event_id"] = event_id
	narrative_flags["demo_objective_id"] = str(status.get("id", ""))
	narrative_flags["demo_finale_target_bankroll"] = int(status.get("target_bankroll", 0))
	narrative_flags["%s_pending" % event_id] = true
	if not _story_log_has_type("demo_finale_triggered", event_id):
		log_story({
			"type": "demo_finale_triggered",
			"event_id": event_id,
			"objective_id": str(status.get("id", "")),
			"environment_id": str(current_environment.get("id", "")),
			"environment_archetype_id": str(current_environment.get("archetype_id", "")),
			"bankroll": bankroll,
			"target_bankroll": int(status.get("target_bankroll", 0)),
			"message": str(objective.get("finale_trigger_message", "The House Calls.")),
		})


func _ensure_current_event_id(event_id: String) -> void:
	if current_environment.is_empty() or event_id.is_empty():
		return
	var event_ids := _copy_array(current_environment.get("event_ids", []))
	if not event_ids.has(event_id):
		event_ids.append(event_id)
	current_environment["event_ids"] = event_ids
	current_environment["layout"] = EnvironmentInstance.ensure_generated_layout(current_environment)


func _clear_demo_finale_pending(event_id: String) -> void:
	narrative_flags["demo_finale_pending"] = false
	if not event_id.is_empty():
		narrative_flags["%s_pending" % event_id] = false


func _log_demo_finale_result(event_id: String, branch: String, message: String, terminal: bool) -> void:
	log_story({
		"type": "demo_finale_result",
		"event_id": event_id,
		"branch": branch,
		"environment_id": str(current_environment.get("id", "")),
		"environment_archetype_id": str(current_environment.get("archetype_id", "")),
		"bankroll": bankroll,
		"suspicion_delta": 0,
		"message": message,
		"ended": terminal,
	})


# Returns current pit-boss surveillance state for boss-floor cheat pressure.
func pit_boss_watch_status(environment: Dictionary = {}) -> Dictionary:
	var source := environment if not environment.is_empty() else current_environment
	var security := _copy_dict(source.get("security_profile", {}))
	var boss := _copy_dict(security.get("pit_boss", {}))
	if not bool(boss.get("enabled", false)):
		return {"active": false}
	var player_room := _grand_casino_room_id_for_environment(source)
	var label := str(boss.get("label", "Pit boss"))
	var base_bonus := maxi(0, int(boss.get("cheat_heat_bonus", 25)))
	if rourke_off_floor_actions > 0 or rourke_current_room.is_empty():
		return {
			"active": false,
			"watched": false,
			"label": label,
			"cheat_heat_bonus": 0,
			"base_cheat_heat_bonus": base_bonus,
			"rourke_room": "",
			"rourke_off_floor_actions": rourke_off_floor_actions,
			"summary": "%s is off the floor escorting a rival. This is the cleanest opening." % label,
		}
	if player_room.is_empty() or rourke_current_room != player_room:
		return {
			"active": false,
			"watched": false,
			"label": label,
			"cheat_heat_bonus": 0,
			"base_cheat_heat_bonus": base_bonus,
			"rourke_room": rourke_current_room,
			"rourke_spot": rourke_current_spot,
			"summary": "%s is working the %s." % [label, _grand_casino_room_display_name(rourke_current_room)],
		}
	var cycle_length := maxi(1, int(boss.get("cycle_length", 4)))
	var watched_turns := clampi(int(boss.get("watched_turns", 2)), 0, cycle_length)
	var phase := int(source.get("turns", 0)) % cycle_length
	if phase < 0:
		phase += cycle_length
	var watched := phase < watched_turns
	if int(narrative_flags.get("lights_out_unwatched_actions", 0)) > 0:
		return {
			"active": true,
			"label": label,
			"watched": false,
			"phase": phase,
			"cycle_length": cycle_length,
			"watched_turns": watched_turns,
			"cheat_heat_bonus": 0,
			"base_cheat_heat_bonus": base_bonus,
			"summary": "The lights are out; staff cannot watch this action.",
			"temporary_modifier": "lights_out",
			"remaining_actions": int(narrative_flags.get("lights_out_unwatched_actions", 0)),
			"rourke_room": rourke_current_room,
			"rourke_spot": rourke_current_spot,
			"rourke_facing": rourke_facing,
		}
	var shift_actions := maxi(0, int(narrative_flags.get("shift_change_rookie_actions", 0)))
	var effective_base_bonus := maxi(0, base_bonus - (12 if shift_actions > 0 else 0))
	var bonus := effective_base_bonus if watched else 0
	var summary := str(boss.get("watched_text", "%s is watching." % label)) if watched else str(boss.get("clear_text", "%s is turned away." % label))
	if shift_actions > 0:
		summary = "%s A rookie is on handoff; cheat heat is softened for %d actions." % [summary, shift_actions]
	return {
		"active": true,
		"label": label,
		"watched": watched,
		"phase": phase,
		"cycle_length": cycle_length,
		"watched_turns": watched_turns,
		"cheat_heat_bonus": bonus,
		"base_cheat_heat_bonus": base_bonus,
		"effective_base_cheat_heat_bonus": effective_base_bonus,
		"summary": summary,
		"temporary_modifier": "shift_change" if shift_actions > 0 else "",
		"remaining_actions": shift_actions,
		"rourke_room": rourke_current_room,
		"rourke_spot": rourke_current_spot,
		"rourke_facing": rourke_facing,
	}


func record_grand_casino_room_heat_gain(room_id: String, amount: int) -> void:
	var normalized_room := room_id.strip_edges()
	if not GRAND_CASINO_ARCHETYPE_IDS.has(normalized_room) or amount <= 0:
		return
	grand_casino_room_heat_accumulators = _normalize_grand_casino_room_heat_accumulators(grand_casino_room_heat_accumulators)
	grand_casino_room_heat_accumulators[normalized_room] = maxi(0, int(grand_casino_room_heat_accumulators.get(normalized_room, 0)) + amount)


func grand_casino_living_floor_snapshot(environment: Dictionary = {}) -> Dictionary:
	var source := current_environment if environment.is_empty() else environment
	var player_room := _grand_casino_room_id_for_environment(source)
	if player_room.is_empty():
		return {}
	var visible_rivals: Array = []
	for rival_value in rival_cheaters:
		if typeof(rival_value) != TYPE_DICTIONARY:
			continue
		var rival := rival_value as Dictionary
		if str(rival.get("room", "")) == player_room:
			visible_rivals.append(rival.duplicate(true))
	var escort := rourke_escort_state.duplicate(true)
	var escort_visible := not escort.is_empty() and player_room == GRAND_CASINO_ARCHETYPE_ID and rourke_off_floor_actions > 0
	if escort_visible:
		escort["progress"] = clampf(1.0 - float(rourke_off_floor_actions) / float(maxi(1, ROURKE_OFF_FLOOR_ACTIONS)), 0.0, 1.0)
	else:
		escort = {}
	return {
		"player_room": player_room,
		"room_heat": grand_casino_room_heat_accumulators.duplicate(true),
		"rourke": {
			"on_floor": rourke_off_floor_actions <= 0 and not rourke_current_room.is_empty(),
			"present": rourke_off_floor_actions <= 0 and rourke_current_room == player_room,
			"room": rourke_current_room,
			"spot": rourke_current_spot,
			"facing": rourke_facing,
			"actions_until_move": rourke_actions_until_move,
			"off_floor_actions": rourke_off_floor_actions,
		},
		"rivals": visible_rivals,
		"rival_count": rival_cheaters.size(),
		"rival_day": rival_cheater_day,
		"escort": escort,
	}


func grand_casino_staffing_snapshot(environment: Dictionary = {}) -> Dictionary:
	var source := current_environment if environment.is_empty() else environment
	if not _is_grand_casino_environment(source):
		return {}
	_initialize_grand_casino_staffing()
	return grand_casino_staffing.duplicate(true)


func grand_casino_staff_member_for_game(game_id: String, environment: Dictionary = {}) -> Dictionary:
	var source := current_environment if environment.is_empty() else environment
	if not _is_grand_casino_environment(source):
		return {}
	_initialize_grand_casino_staffing()
	var role_id := "bartender" if game_id == "bar_dice" else game_id.strip_edges()
	var assignments: Dictionary = grand_casino_staffing.get("assignments", {}) if typeof(grand_casino_staffing.get("assignments", {})) == TYPE_DICTIONARY else {}
	var assignment: Variant = assignments.get(role_id, {})
	return assignment if typeof(assignment) == TYPE_DICTIONARY else {}


func grand_casino_staff_profile_rng(role_id: String, assignment_id: String, day_index: int) -> RngStream:
	return _create_seeded_run_rng("gc_staff_profile:%s:%s:%d" % [role_id.strip_edges(), assignment_id.strip_edges(), maxi(1, day_index)])


func pending_grand_casino_entry_cue() -> Dictionary:
	var cue: Variant = grand_casino_staffing.get("entry_cue", {})
	return (cue as Dictionary).duplicate(true) if typeof(cue) == TYPE_DICTIONARY else {}


func consume_grand_casino_entry_cue() -> Dictionary:
	var cue := pending_grand_casino_entry_cue()
	if cue.is_empty():
		return {}
	grand_casino_staffing["entry_cue"] = {}
	if bool(cue.get("rotation", false)):
		grand_casino_staffing["rotation_cue_shown_day"] = maxi(1, int(cue.get("day", game_day())))
	return cue


func _initialize_grand_casino_staffing() -> void:
	if not _is_grand_casino_environment(current_environment):
		return
	var current_day := game_day()
	if int(grand_casino_staffing.get("day", 0)) == current_day and not _grand_casino_staff_assignments(grand_casino_staffing).is_empty():
		return
	var prior_cue: Dictionary = grand_casino_staffing.get("entry_cue", {}) if typeof(grand_casino_staffing.get("entry_cue", {})) == TYPE_DICTIONARY else {}
	var shown_day := maxi(0, int(grand_casino_staffing.get("rotation_cue_shown_day", 0)))
	grand_casino_staffing = _grand_casino_staffing_for_day(current_day)
	grand_casino_staffing["entry_cue"] = prior_cue
	grand_casino_staffing["rotation_cue_shown_day"] = shown_day


func _advance_grand_casino_staff_day_rollovers(previous_day: int, next_day: int) -> void:
	if previous_day >= next_day:
		return
	for day_index in range(previous_day + 1, next_day + 1):
		grand_casino_staffing = _grand_casino_staffing_for_day(day_index)
		_seed_rival_cheater_cast(day_index)


func _grand_casino_staffing_for_day(day_index: int) -> Dictionary:
	var target_day := maxi(1, day_index)
	var config := _grand_casino_staff_config()
	var chance := clampi(int(config.get("rotation_chance_percent", GRAND_CASINO_STAFF_ROTATION_CHANCE_PERCENT)), 0, 100)
	var assignments: Dictionary = {}
	for timeline_day in range(1, target_day + 1):
		var day_rng := _create_seeded_run_rng("gc_staff_day:%d" % timeline_day)
		var next_assignments: Dictionary = {}
		for role_value in GRAND_CASINO_STAFF_ROLE_IDS:
			var role_id := str(role_value)
			var roster := _grand_casino_staff_roster(config, role_id)
			var previous: Dictionary = assignments.get(role_id, {}) if typeof(assignments.get(role_id, {})) == TYPE_DICTIONARY else {}
			var role_rng := day_rng.fork(role_id)
			var rotate := timeline_day == 1 or previous.is_empty() or role_rng.randi_range(1, 100) <= chance
			var selected := _grand_casino_staff_pick(roster, previous, role_rng, rotate)
			selected["role_id"] = role_id
			selected["day"] = timeline_day
			next_assignments[role_id] = selected
		assignments = next_assignments
	var prior_assignments := _grand_casino_staff_assignments(grand_casino_staffing)
	var rotated_roles: Array = []
	if target_day > 1:
		var previous_timeline := _grand_casino_staffing_for_previous_day(target_day - 1, config, chance)
		for role_value in GRAND_CASINO_STAFF_ROLE_IDS:
			var role_id := str(role_value)
			var previous_id := str(_copy_dict(previous_timeline.get(role_id, {})).get("id", ""))
			var current_id := str(_copy_dict(assignments.get(role_id, {})).get("id", ""))
			if not current_id.is_empty() and current_id != previous_id:
				rotated_roles.append(role_id)
	if not prior_assignments.is_empty() and int(grand_casino_staffing.get("day", 0)) == target_day:
		rotated_roles = _copy_array(grand_casino_staffing.get("rotated_roles", rotated_roles))
	return {
		"day": target_day,
		"rotation_chance_percent": chance,
		"assignments": assignments,
		"rotated_roles": rotated_roles,
		"rotation_occurred": not rotated_roles.is_empty(),
		"constants": {
			"rourke": {"id": "rourke", "name": "Rourke"},
			"linda": {"id": "linda", "name": "Linda"},
		},
		"entry_cue": {},
		"rotation_cue_shown_day": maxi(0, int(grand_casino_staffing.get("rotation_cue_shown_day", 0))),
	}


func _grand_casino_staffing_for_previous_day(day_index: int, config: Dictionary, chance: int) -> Dictionary:
	var assignments: Dictionary = {}
	for timeline_day in range(1, maxi(1, day_index) + 1):
		var day_rng := _create_seeded_run_rng("gc_staff_day:%d" % timeline_day)
		var next_assignments: Dictionary = {}
		for role_value in GRAND_CASINO_STAFF_ROLE_IDS:
			var role_id := str(role_value)
			var roster := _grand_casino_staff_roster(config, role_id)
			var previous: Dictionary = assignments.get(role_id, {}) if typeof(assignments.get(role_id, {})) == TYPE_DICTIONARY else {}
			var role_rng := day_rng.fork(role_id)
			var rotate := timeline_day == 1 or previous.is_empty() or role_rng.randi_range(1, 100) <= chance
			var selected := _grand_casino_staff_pick(roster, previous, role_rng, rotate)
			selected["role_id"] = role_id
			selected["day"] = timeline_day
			next_assignments[role_id] = selected
		assignments = next_assignments
	return assignments


func _grand_casino_staff_pick(roster: Array, previous: Dictionary, rng: RngStream, rotate: bool) -> Dictionary:
	if roster.is_empty():
		return {}
	if not rotate and not previous.is_empty():
		return previous.duplicate(true)
	var choices: Array = []
	var previous_id := str(previous.get("id", ""))
	for member_value in roster:
		if typeof(member_value) != TYPE_DICTIONARY:
			continue
		var member := member_value as Dictionary
		if roster.size() > 1 and str(member.get("id", "")) == previous_id:
			continue
		choices.append(member)
	if choices.is_empty():
		choices = roster
	var selected: Variant = rng.pick(choices, choices[0])
	return (selected as Dictionary).duplicate(true) if typeof(selected) == TYPE_DICTIONARY else {}


func _grand_casino_staff_config() -> Dictionary:
	for environment_value in [current_environment, grand_casino_room_states.get(GRAND_CASINO_ARCHETYPE_ID, {})]:
		if typeof(environment_value) != TYPE_DICTIONARY:
			continue
		var environment := environment_value as Dictionary
		var flags: Dictionary = environment.get("local_narrative_flags", {}) if typeof(environment.get("local_narrative_flags", {})) == TYPE_DICTIONARY else {}
		var config: Variant = flags.get("grand_casino_staff_rotation", {})
		if typeof(config) == TYPE_DICTIONARY and not (config as Dictionary).is_empty():
			return (config as Dictionary).duplicate(true)
	return {
		"rotation_chance_percent": GRAND_CASINO_STAFF_ROTATION_CHANCE_PERCENT,
		"rosters": GRAND_CASINO_STAFF_DEFAULT_ROSTERS.duplicate(true),
		"memory_lines": GRAND_CASINO_MEMORY_DEFAULT_LINES.duplicate(true),
		"rotation_cue_lines": ["New faces have taken their places at the felt."],
		"memory_high_heat_threshold": 50,
	}


func _grand_casino_staff_roster(config: Dictionary, role_id: String) -> Array:
	var rosters: Dictionary = config.get("rosters", {}) if typeof(config.get("rosters", {})) == TYPE_DICTIONARY else {}
	var roster: Variant = rosters.get(role_id, GRAND_CASINO_STAFF_DEFAULT_ROSTERS.get(role_id, []))
	return (roster as Array).duplicate(true) if typeof(roster) == TYPE_ARRAY else []


func _queue_grand_casino_entry_cue(previous_was_grand_casino: bool) -> void:
	if not _is_grand_casino_environment(current_environment):
		return
	var config := _grand_casino_staff_config()
	var parts: Array = []
	var cue := {"day": game_day(), "rotation": false, "memory_key": ""}
	if bool(grand_casino_staffing.get("rotation_occurred", false)) and int(grand_casino_staffing.get("rotation_cue_shown_day", 0)) != game_day():
		var rotation_lines: Array = config.get("rotation_cue_lines", []) if typeof(config.get("rotation_cue_lines", [])) == TYPE_ARRAY else []
		if not rotation_lines.is_empty():
			parts.append(str(rotation_lines[0]))
		cue["rotation"] = true
	if not previous_was_grand_casino and _grand_casino_has_prior_visit():
		var memory_key := _grand_casino_dominant_memory_key(config)
		var memory_lines: Dictionary = config.get("memory_lines", {}) if typeof(config.get("memory_lines", {})) == TYPE_DICTIONARY else {}
		var memory_line := str(memory_lines.get(memory_key, GRAND_CASINO_MEMORY_DEFAULT_LINES.get(memory_key, ""))).strip_edges()
		if not memory_line.is_empty():
			parts.append(memory_line)
		cue["memory_key"] = memory_key
	if parts.is_empty():
		return
	cue["message"] = " ".join(parts)
	grand_casino_staffing["entry_cue"] = cue
	log_story({
		"type": "grand_casino_entry_memory",
		"day": game_day(),
		"memory_key": str(cue.get("memory_key", "")),
		"rotation": bool(cue.get("rotation", false)),
		"message": str(cue.get("message", "")),
	})


func _grand_casino_has_prior_visit() -> bool:
	for entry_value in environment_history:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry := entry_value as Dictionary
		if GRAND_CASINO_ARCHETYPE_IDS.has(str(entry.get("archetype_id", ""))):
			return true
	return false


func _grand_casino_dominant_memory_key(config: Dictionary) -> String:
	var remembered_pressure := bool(narrative_flags.get("grand_casino_showdown_pending", false)) \
		or bool(narrative_flags.get("grand_casino_showdown_active", false)) \
		or bool(narrative_flags.get("grand_casino_staff_attention", false)) \
		or bool(narrative_flags.get("grand_casino_attention_pit_boss_sweep", false)) \
		or bool(narrative_flags.get("grand_casino_attention_eye_in_the_sky", false)) \
		or bool(narrative_flags.get("grand_casino_attention_watched_risky", false)) \
		or bool(narrative_flags.get("grand_casino_attention_host", false)) \
		or bool(narrative_flags.get("grand_casino_attention_high_roller_review", false)) \
		or bool(narrative_flags.get("grand_casino_attention_forced_heat", false))
	if remembered_pressure:
		return "showdown_pressure"
	var objective_status := demo_objective_status()
	if bool(narrative_flags.get("grand_casino_high_roller_ready", false)) \
		or bool(narrative_flags.get("high_roller_cashout_pending", false)) \
		or bool(objective_status.get("players_card_ready", false)):
		return "pending_review"
	if bool(narrative_flags.get("grand_casino_cheat_evidence", false)) or bool(narrative_flags.get("grand_casino_watched_cheat_evidence", false)):
		return "cheat_evidence"
	var high_heat_threshold := clampi(int(config.get("memory_high_heat_threshold", 50)), 0, 100)
	if maxi(suspicion_level(), int(narrative_flags.get("grand_casino_max_heat", 0))) >= high_heat_threshold:
		return "high_heat"
	return "returning"


func _create_seeded_run_rng(stream_key: String) -> RngStream:
	var rng := RngStream.new()
	rng.configure(seed_value, seed_value)
	return rng.fork(stream_key)


static func _grand_casino_staff_assignments(staffing: Dictionary) -> Dictionary:
	var assignments: Variant = staffing.get("assignments", {})
	return assignments if typeof(assignments) == TYPE_DICTIONARY else {}


func _initialize_grand_casino_living_floor() -> void:
	if not _is_grand_casino_environment(current_environment):
		return
	grand_casino_room_heat_accumulators = _normalize_grand_casino_room_heat_accumulators(grand_casino_room_heat_accumulators)
	if rourke_current_room.is_empty() and rourke_off_floor_actions <= 0:
		var initial_rng := create_rng("rourke_floor").fork("initial:day:%d" % game_day())
		rourke_current_room = GRAND_CASINO_ARCHETYPE_ID
		rourke_current_spot = _rourke_spot_for_room(rourke_current_room, initial_rng)
		rourke_facing = "left" if initial_rng.randi_range(0, 1) == 0 else "right"
		rourke_actions_until_move = ROURKE_MOVE_EVALUATION_ACTIONS
	if rival_cheater_day != game_day():
		_seed_rival_cheater_cast(game_day())


func _advance_grand_casino_living_floor(amount: int) -> void:
	if amount <= 0 or not _is_grand_casino_environment(current_environment):
		return
	_initialize_grand_casino_living_floor()
	for _action in range(amount):
		rourke_floor_action_index += 1
		_decay_grand_casino_room_heat()
		_advance_rival_cheater_heat()
		if rourke_off_floor_actions > 0:
			rourke_off_floor_actions = maxi(0, rourke_off_floor_actions - 1)
			if not rourke_escort_state.is_empty():
				rourke_escort_state["actions_remaining"] = rourke_off_floor_actions
			if rourke_off_floor_actions <= 0:
				var return_rng := create_rng("rourke_floor").fork("escort_return:%d" % rourke_floor_action_index)
				rourke_current_room = GRAND_CASINO_ARCHETYPE_ID
				rourke_current_spot = _rourke_spot_for_room(rourke_current_room, return_rng)
				rourke_facing = "left"
				rourke_actions_until_move = ROURKE_MOVE_EVALUATION_ACTIONS
				rourke_escort_state = {}
			continue
		rourke_actions_until_move = maxi(0, rourke_actions_until_move - 1)
		if rourke_actions_until_move <= 0:
			_evaluate_rourke_movement()
			rourke_actions_until_move = ROURKE_MOVE_EVALUATION_ACTIONS
		_evaluate_rourke_escort()


func _decay_grand_casino_room_heat() -> void:
	for room_id_value in GRAND_CASINO_ARCHETYPE_IDS:
		var room_id := str(room_id_value)
		var value := maxi(0, int(grand_casino_room_heat_accumulators.get(room_id, 0)))
		grand_casino_room_heat_accumulators[room_id] = int(floor(float(value * ROURKE_HEAT_DECAY_PERCENT) / 100.0))


func _advance_rival_cheater_heat() -> void:
	for index in range(rival_cheaters.size()):
		if typeof(rival_cheaters[index]) != TYPE_DICTIONARY:
			continue
		var rival := rival_cheaters[index] as Dictionary
		var rival_id := str(rival.get("id", "rival_%d" % index))
		var room_id := str(rival.get("room", ""))
		var heat_rng := create_rng("rourke_floor").fork("rival_heat:%d:%s" % [rourke_floor_action_index, rival_id])
		var heat_gain := heat_rng.randi_range(1, 2)
		record_grand_casino_room_heat_gain(room_id, heat_gain)
		rival["last_heat_gain"] = heat_gain
		rival["last_heat_action"] = rourke_floor_action_index
		rival_cheaters[index] = rival


func _evaluate_rourke_movement() -> void:
	if rourke_current_room.is_empty():
		return
	var current_heat := maxi(0, int(grand_casino_room_heat_accumulators.get(rourke_current_room, 0)))
	var hottest_room := rourke_current_room
	var hottest_heat := current_heat
	for room_id_value in ROURKE_ROOM_PATH:
		var room_id := str(room_id_value)
		var room_heat := maxi(0, int(grand_casino_room_heat_accumulators.get(room_id, 0)))
		if room_heat > hottest_heat:
			hottest_room = room_id
			hottest_heat = room_heat
	if hottest_room == rourke_current_room or hottest_heat - current_heat <= ROURKE_INERTIA_HEAT_MARGIN:
		return
	var current_index := ROURKE_ROOM_PATH.find(rourke_current_room)
	var hottest_index := ROURKE_ROOM_PATH.find(hottest_room)
	if current_index < 0 or hottest_index < 0:
		return
	var next_index := current_index + signi(hottest_index - current_index)
	var next_room := str(ROURKE_ROOM_PATH[next_index])
	var move_rng := create_rng("rourke_floor").fork("move:%d:%s" % [rourke_floor_action_index, next_room])
	rourke_facing = "right" if next_index > current_index else "left"
	rourke_current_room = next_room
	rourke_current_spot = _rourke_spot_for_room(next_room, move_rng)


func _evaluate_rourke_escort() -> void:
	if rourke_current_room.is_empty() or rival_cheaters.is_empty():
		return
	for index in range(rival_cheaters.size()):
		if typeof(rival_cheaters[index]) != TYPE_DICTIONARY:
			continue
		var rival := rival_cheaters[index] as Dictionary
		if str(rival.get("room", "")) != rourke_current_room:
			continue
		var escort_rng := create_rng("rourke_floor").fork("escort:%d:%s" % [rourke_floor_action_index, str(rival.get("id", index))])
		if escort_rng.randi_range(1, 100) > ROURKE_ESCORT_CHANCE_PERCENT:
			continue
		_begin_rourke_escort(index, rival)
		return


func _begin_rourke_escort(index: int, rival: Dictionary) -> void:
	var caught_room := rourke_current_room
	var rival_name := str(rival.get("display_name", "a rival counter"))
	rourke_escort_state = {
		"cheater_id": str(rival.get("id", "")),
		"cheater_name": rival_name,
		"tell": str(rival.get("tell", "")),
		"caught_room": caught_room,
		"actions_remaining": ROURKE_OFF_FLOOR_ACTIONS,
	}
	rival_cheaters.remove_at(index)
	rourke_current_room = ""
	rourke_current_spot = ""
	rourke_off_floor_actions = ROURKE_OFF_FLOOR_ACTIONS
	log_story({
		"type": "rourke_rival_escort",
		"event_id": "rourke_rival_escort",
		"environment_id": str(current_environment.get("id", "")),
		"environment_archetype_id": str(current_environment.get("archetype_id", "")),
		"caught_room": caught_room,
		"cheater_id": str(rival.get("id", "")),
		"message": "Rourke catches %s's tell and walks them across the Main Floor to the Back Room. He is off the floor for %d actions." % [rival_name, ROURKE_OFF_FLOOR_ACTIONS],
	})


func _seed_rival_cheater_cast(day_index: int) -> void:
	var cast_rng := _create_seeded_run_rng("rourke_floor:cast:day:%d" % maxi(1, day_index))
	var count := cast_rng.randi_range(RIVAL_CHEATER_MIN_COUNT, RIVAL_CHEATER_MAX_COUNT)
	var names := ["Marlow", "Vega", "Kite", "Nix", "Bishop", "Juneau"]
	var tells := ["chip_riffle", "sleeve_check", "heel_tap", "glance_loop", "ring_turn", "counting_lips"]
	var cast: Array = []
	for index in range(count):
		var room_id := str(cast_rng.pick(RIVAL_CHEATER_ROOMS, GRAND_CASINO_ARCHETYPE_ID))
		cast.append({
			"id": "rival_cheater_d%d_%d" % [maxi(1, day_index), index],
			"display_name": str(names[cast_rng.randi_range(0, names.size() - 1)]),
			"room": room_id,
			"spot": cast_rng.randi_range(0, 2),
			"tell": str(tells[(index + cast_rng.randi_range(0, tells.size() - 1)) % tells.size()]),
			"idle_phase": cast_rng.randi_range(0, 1000),
		})
	rival_cheaters = cast
	rival_cheater_day = maxi(1, day_index)


func _rourke_spot_for_room(room_id: String, rng: RngStream) -> String:
	var spots := {
		GRAND_CASINO_ARCHETYPE_ID: ["main_left", "main_center", "main_cage"],
		GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID: ["high_rail", "high_center", "high_door"],
		GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID: ["back_table", "back_door"],
	}
	var room_spots: Array = spots.get(room_id, ["main_center"])
	return str(rng.pick(room_spots, room_spots[0]))


func _grand_casino_room_id_from_context(context: Dictionary) -> String:
	var archetype_id := str(context.get("environment_archetype_id", "")).strip_edges()
	if GRAND_CASINO_ARCHETYPE_IDS.has(archetype_id):
		return archetype_id
	var environment_id := str(context.get("environment_id", "")).strip_edges()
	for room_id_value in [GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID, GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID, GRAND_CASINO_ARCHETYPE_ID]:
		var room_id := str(room_id_value)
		if environment_id == room_id or environment_id.begins_with("%s_" % room_id):
			return room_id
	return _grand_casino_room_id_for_environment(current_environment)


func _grand_casino_room_id_for_environment(environment: Dictionary) -> String:
	if environment.is_empty():
		return ""
	var archetype_id := str(environment.get("archetype_id", "")).strip_edges()
	if GRAND_CASINO_ARCHETYPE_IDS.has(archetype_id):
		return archetype_id
	var environment_id := str(environment.get("id", "")).strip_edges()
	for room_id_value in [GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID, GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID, GRAND_CASINO_ARCHETYPE_ID]:
		var room_id := str(room_id_value)
		if environment_id == room_id or environment_id.begins_with("%s_" % room_id):
			return room_id
	return ""


func _grand_casino_room_display_name(room_id: String) -> String:
	match room_id:
		GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID:
			return "High-Limit Room"
		GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID:
			return "Back Room"
		_:
			return "Main Floor"


func _initialize_grand_casino_objective_runtime() -> void:
	if not _is_grand_casino_environment(current_environment):
		return
	var objective := _copy_dict(current_environment.get("demo_objective", {}))
	if not _is_grand_casino_objective(objective):
		return
	var had_players_card_tier := narrative_flags.has("grand_casino_players_card_tier")
	var environment_id := GRAND_CASINO_ARCHETYPE_ID
	var previous_environment_id := str(narrative_flags.get("grand_casino_entry_environment_id", ""))
	if previous_environment_id != environment_id:
		narrative_flags["grand_casino_entry_environment_id"] = environment_id
		_apply_grand_casino_prestige_recognition()
		narrative_flags["grand_casino_entry_bankroll"] = grand_casino_total_money()
		narrative_flags["grand_casino_games_played"] = 0
		narrative_flags["grand_casino_max_heat"] = suspicion_level()
		narrative_flags["grand_casino_open_cheat_actions"] = 0
	if not narrative_flags.has("grand_casino_entry_bankroll"):
		narrative_flags["grand_casino_entry_bankroll"] = grand_casino_total_money()
	if not narrative_flags.has("grand_casino_games_played"):
		narrative_flags["grand_casino_games_played"] = 0
	var entry_bankroll := int(narrative_flags.get("grand_casino_entry_bankroll", grand_casino_total_money()))
	narrative_flags["grand_casino_net_winnings"] = grand_casino_total_money() - entry_bankroll
	if not narrative_flags.has("grand_casino_max_heat"):
		narrative_flags["grand_casino_max_heat"] = suspicion_level()
	else:
		narrative_flags["grand_casino_max_heat"] = maxi(int(narrative_flags.get("grand_casino_max_heat", 0)), suspicion_level())
	if not narrative_flags.has("grand_casino_open_cheat_actions"):
		narrative_flags["grand_casino_open_cheat_actions"] = 0
	if not narrative_flags.has("grand_casino_endgame_state"):
		narrative_flags["grand_casino_endgame_state"] = GRAND_CASINO_STATE_INCOMPLETE
	if not narrative_flags.has("grand_casino_high_roller_ready"):
		narrative_flags["grand_casino_high_roller_ready"] = false
	if not narrative_flags.has("high_roller_cashout_pending"):
		narrative_flags["high_roller_cashout_pending"] = false
	if not narrative_flags.has("grand_casino_showdown_pending"):
		narrative_flags["grand_casino_showdown_pending"] = false
	if not narrative_flags.has("grand_casino_showdown_active"):
		narrative_flags["grand_casino_showdown_active"] = false
	if bool(narrative_flags.get("grand_casino_showdown_active", false)):
		var showdown_step := str(narrative_flags.get("grand_casino_showdown_step", ""))
		if showdown_step.is_empty() or showdown_step == GRAND_CASINO_SHOWDOWN_STEP_PRESSURE:
			narrative_flags["grand_casino_showdown_step"] = GRAND_CASINO_SHOWDOWN_STEP_WALK
			narrative_flags["grand_casino_showdown_ditch_used"] = false
	if not narrative_flags.has("grand_casino_comp_drink_tokens"):
		narrative_flags["grand_casino_comp_drink_tokens"] = 0
	if not narrative_flags.has("grand_casino_comp_suite_rests"):
		narrative_flags["grand_casino_comp_suite_rests"] = 0
	if not narrative_flags.has("grand_casino_linda_look_away_consumed"):
		narrative_flags["grand_casino_linda_look_away_consumed"] = false
	if not had_players_card_tier:
		var config := _grand_casino_objective_config(objective)
		var eligible := not bool(narrative_flags.get("grand_casino_players_card_ineligible", false)) and not bool(narrative_flags.get("grand_casino_cheat_evidence", false)) and not bool(narrative_flags.get("grand_casino_watched_cheat_evidence", false))
		var legacy_tier := _grand_casino_players_card_derived_tier(
			config,
			maxi(0, int(narrative_flags.get("grand_casino_games_played", 0))),
			int(narrative_flags.get("grand_casino_net_winnings", 0)),
			maxi(suspicion_level(), int(narrative_flags.get("grand_casino_max_heat", suspicion_level()))),
			eligible
		)
		narrative_flags["grand_casino_players_card_tier"] = GRAND_CASINO_PLAYERS_CARD_TIER_NONE
		if eligible:
			_advance_grand_casino_players_card_tier(GRAND_CASINO_PLAYERS_CARD_TIER_NONE, legacy_tier, false)
		else:
			narrative_flags["grand_casino_players_card_ineligible"] = true


func _apply_grand_casino_prestige_recognition() -> void:
	var prestige := grand_casino_prestige_status()
	if not bool(prestige.get("active", false)) or bool(prestige.get("recognition_applied", false)):
		return
	var requested_delta := mini(0, int(prestige.get("recognition_heat_delta", 0)))
	var applied_delta := 0
	if requested_delta < 0:
		applied_delta = add_suspicion("grand_casino_prestige_recognition", requested_delta, "recognition", true, {
			"action_kind": "prestige_recognition",
			"environment_id": str(current_environment.get("id", "")),
			"environment_archetype_id": str(current_environment.get("archetype_id", "")),
		})
	narrative_flags["grand_casino_prestige_recognition_applied"] = true
	narrative_flags["grand_casino_prestige_recognition_heat_delta"] = applied_delta
	log_story({
		"type": "grand_casino_prestige_recognition",
		"suspicion_delta": applied_delta,
		"message": "Linda recognizes the carried Players Card; the floor starts this visit with less attention.",
	})


func sync_grand_casino_entry_bankroll_after_travel_result(result: Dictionary) -> void:
	if not _is_grand_casino_environment(current_environment):
		return
	var action_kind := str(result.get("action_kind", "")).strip_edges()
	var result_type := str(result.get("type", "")).strip_edges()
	if action_kind != "travel" and result_type != "travel":
		return
	var destination_archetype_id := str(result.get("environment_archetype_id", result.get("to_archetype_id", ""))).strip_edges()
	if destination_archetype_id != GRAND_CASINO_ARCHETYPE_ID:
		return
	var environment_id := str(current_environment.get("id", GRAND_CASINO_ARCHETYPE_ID)).strip_edges()
	if str(narrative_flags.get("grand_casino_entry_bankroll_after_travel_environment_id", "")) == environment_id:
		return
	_initialize_grand_casino_objective_runtime()
	narrative_flags["grand_casino_entry_bankroll"] = grand_casino_total_money()
	narrative_flags["grand_casino_net_winnings"] = 0
	narrative_flags["grand_casino_entry_bankroll_after_travel_environment_id"] = environment_id


func _is_grand_casino_objective(objective: Dictionary) -> bool:
	return str(objective.get("id", "")).strip_edges() == GRAND_CASINO_OBJECTIVE_ID


func is_grand_casino_environment(environment: Dictionary = {}) -> bool:
	var source := current_environment if environment.is_empty() else environment
	return _is_grand_casino_environment(source)


func _is_grand_casino_environment(environment: Dictionary) -> bool:
	if environment.is_empty():
		return false
	var archetype_id := str(environment.get("archetype_id", "")).strip_edges()
	if GRAND_CASINO_ARCHETYPE_IDS.has(archetype_id):
		return true
	var environment_id := str(environment.get("id", "")).strip_edges()
	if GRAND_CASINO_ARCHETYPE_IDS.has(environment_id):
		return true
	return GRAND_CASINO_ARCHETYPE_IDS.has(_location_id_from_generated_environment_id(environment_id))


func _grand_casino_active_security_event_sources(environment: Dictionary) -> Array:
	var sources: Array = []
	var resolved_event_ids := _copy_array(environment.get("resolved_event_ids", []))
	for event_id_value in _copy_array(environment.get("event_ids", [])):
		var event_id := str(event_id_value)
		if resolved_event_ids.has(event_id):
			continue
		if event_id == "pit_boss_sweep" or event_id == "eye_in_the_sky":
			_append_unique_string(sources, event_id)
	return sources


func _grand_casino_objective_config(objective: Dictionary) -> Dictionary:
	var target_bankroll := maxi(0, int(objective.get("target_bankroll", objective.get("high_roller_target_bankroll", 0))))
	var high_roller_target := maxi(0, int(objective.get("high_roller_target_bankroll", target_bankroll)))
	var modifiers := challenge_modifiers()
	var prestige_heat_delta := mini(0, int(modifiers.get("grand_casino_prestige_clean_heat_ceiling_delta", 0))) if bool(modifiers.get("grand_casino_prestige", false)) else 0
	var high_roller_net := maxi(0, int(objective.get("high_roller_net_winnings", 0)) + int(modifiers.get("grand_casino_high_roller_net_delta", 0)))
	var high_roller_max_heat := clampi(int(objective.get("high_roller_max_heat", 100)) + int(modifiers.get("grand_casino_high_roller_max_heat_delta", 0)) + prestige_heat_delta, 0, 100)
	var config := {
		"target_bankroll": target_bankroll,
		"high_roller_target_bankroll": high_roller_target,
		"high_roller_net_winnings": high_roller_net,
		"high_roller_min_grand_casino_games": maxi(0, int(objective.get("high_roller_min_grand_casino_games", 0))),
		"high_roller_max_heat": high_roller_max_heat,
		"showdown_heat_threshold": clampi(int(objective.get("showdown_heat_threshold", 70)), 0, 100),
		"forced_showdown_heat_threshold": clampi(int(objective.get("forced_showdown_heat_threshold", 95)), 0, 100),
		"showdown_event_id": str(objective.get("showdown_event_id", objective.get("finale_event_id", GRAND_CASINO_SHOWDOWN_EVENT_ID))).strip_edges(),
		"high_roller_event_id": str(objective.get("high_roller_event_id", GRAND_CASINO_HIGH_ROLLER_EVENT_ID)).strip_edges(),
	}
	var card_defaults := {
		"players_card_bronze_min_games": 1,
		"players_card_bronze_net_winnings": 5,
		"players_card_bronze_max_heat": 30,
		"players_card_bronze_chip_bonus": 5,
		"players_card_bronze_drink_comps": 1,
		"players_card_silver_min_games": 3,
		"players_card_silver_net_winnings": 15,
		"players_card_silver_max_heat": 30,
		"players_card_silver_chip_bonus": 10,
		"players_card_silver_drink_comps": 1,
		"players_card_silver_suite_rests": 1,
		"players_card_gold_min_games": int(config.get("high_roller_min_grand_casino_games", 5)),
		"players_card_gold_net_winnings": high_roller_net,
		"players_card_gold_max_heat": high_roller_max_heat,
		"players_card_look_away_max_heat_gain": 5,
		"players_card_comp_drink_alcohol": 8,
		"players_card_suite_rest_minutes": 240,
		"players_card_suite_heat_recovery": 12,
		"players_card_suite_drunk_recovery": 24,
	}
	for key in card_defaults:
		config[key] = maxi(0, int(objective.get(key, card_defaults[key])))
	for heat_key in ["players_card_bronze_max_heat", "players_card_silver_max_heat", "players_card_gold_max_heat"]:
		config[heat_key] = clampi(int(objective.get(heat_key, card_defaults[heat_key])) + prestige_heat_delta, 0, 100)
	config["players_card_gold_min_games"] = maxi(int(config.get("players_card_gold_min_games", 0)), int(config.get("high_roller_min_grand_casino_games", 0)))
	config["players_card_gold_net_winnings"] = maxi(int(config.get("players_card_gold_net_winnings", 0)), high_roller_net)
	config["players_card_gold_max_heat"] = clampi(int(config.get("players_card_gold_max_heat", high_roller_max_heat)), 0, 100)
	return config


func _grand_casino_players_card_tier_index(tier_id: String) -> int:
	var index := GRAND_CASINO_PLAYERS_CARD_TIERS.find(tier_id.strip_edges().to_lower())
	return maxi(0, index)


func _grand_casino_players_card_tier_definitions(config: Dictionary) -> Array:
	return [
		{
			"id": GRAND_CASINO_PLAYERS_CARD_TIER_BRONZE,
			"label": "Bronze",
			"min_games": int(config.get("players_card_bronze_min_games", 1)),
			"net_winnings": int(config.get("players_card_bronze_net_winnings", 5)),
			"max_heat": int(config.get("players_card_bronze_max_heat", 30)),
			"chip_bonus": int(config.get("players_card_bronze_chip_bonus", 0)),
			"drink_comps": int(config.get("players_card_bronze_drink_comps", 0)),
			"suite_rests": 0,
			"benefits": ["Bar drink comp", "Small chip bonus", "Linda conversations"],
		},
		{
			"id": GRAND_CASINO_PLAYERS_CARD_TIER_SILVER,
			"label": "Silver",
			"min_games": int(config.get("players_card_silver_min_games", 3)),
			"net_winnings": int(config.get("players_card_silver_net_winnings", 15)),
			"max_heat": int(config.get("players_card_silver_max_heat", 30)),
			"chip_bonus": int(config.get("players_card_silver_chip_bonus", 0)),
			"drink_comps": int(config.get("players_card_silver_drink_comps", 0)),
			"suite_rests": int(config.get("players_card_silver_suite_rests", 0)),
			"benefits": ["High-Limit Room access", "Improved comps", "One Linda look-away", "Suite rest"],
		},
		{
			"id": GRAND_CASINO_PLAYERS_CARD_TIER_GOLD,
			"label": "Gold",
			"min_games": int(config.get("players_card_gold_min_games", config.get("high_roller_min_grand_casino_games", 5))),
			"net_winnings": int(config.get("players_card_gold_net_winnings", config.get("high_roller_net_winnings", 30))),
			"max_heat": int(config.get("players_card_gold_max_heat", config.get("high_roller_max_heat", 30))),
			"chip_bonus": 0,
			"drink_comps": 0,
			"suite_rests": 0,
			"benefits": ["Gold review completes the clean route"],
		},
	]


func _grand_casino_players_card_derived_tier(config: Dictionary, games_played: int, net_winnings: int, max_visit_heat: int, eligible: bool) -> String:
	if not eligible:
		return GRAND_CASINO_PLAYERS_CARD_TIER_NONE
	var result := GRAND_CASINO_PLAYERS_CARD_TIER_NONE
	for definition_value in _grand_casino_players_card_tier_definitions(config):
		var definition: Dictionary = definition_value
		if games_played < int(definition.get("min_games", 0)):
			break
		if net_winnings < int(definition.get("net_winnings", 0)):
			break
		if max_visit_heat > int(definition.get("max_heat", 100)):
			break
		result = str(definition.get("id", GRAND_CASINO_PLAYERS_CARD_TIER_NONE))
	return result


func _grand_casino_players_card_tier_definition(config: Dictionary, tier_id: String) -> Dictionary:
	for definition_value in _grand_casino_players_card_tier_definitions(config):
		var definition: Dictionary = definition_value
		if str(definition.get("id", "")) == tier_id:
			return definition
	return {}


func _grand_casino_players_card_next_definition(config: Dictionary, tier_id: String) -> Dictionary:
	var current_index := _grand_casino_players_card_tier_index(tier_id)
	for definition_value in _grand_casino_players_card_tier_definitions(config):
		var definition: Dictionary = definition_value
		if _grand_casino_players_card_tier_index(str(definition.get("id", ""))) > current_index:
			return definition
	return {}


func _grand_casino_players_card_benefits(config: Dictionary, tier_id: String) -> Array:
	var benefits: Array = []
	var current_index := _grand_casino_players_card_tier_index(tier_id)
	for definition_value in _grand_casino_players_card_tier_definitions(config):
		var definition: Dictionary = definition_value
		if _grand_casino_players_card_tier_index(str(definition.get("id", ""))) > current_index:
			break
		for benefit_value in _copy_array(definition.get("benefits", [])):
			var benefit := str(benefit_value)
			if not benefits.has(benefit):
				benefits.append(benefit)
	return benefits


func _grand_casino_derived_state(source: Dictionary, high_roller_ready: bool, showdown_pending: bool, showdown_active: bool) -> String:
	if run_status == RUN_STATUS_ENDED and bool(narrative_flags.get("demo_victory", false)):
		return GRAND_CASINO_STATE_VICTORY
	if run_status == RUN_STATUS_FAILED:
		return GRAND_CASINO_STATE_FAILURE
	if showdown_active:
		return GRAND_CASINO_STATE_SHOWDOWN_ACTIVE
	if showdown_pending:
		return GRAND_CASINO_STATE_SHOWDOWN_PENDING
	if high_roller_ready:
		return GRAND_CASINO_STATE_HIGH_ROLLER_READY
	if _is_grand_casino_environment(source):
		return GRAND_CASINO_STATE_INCOMPLETE
	return GRAND_CASINO_STATE_PRE


func _grand_casino_objective_summary(high_roller_ready: bool, showdown_pending: bool, heat_route_ready: bool, dirty_money_showdown_ready: bool, money_target_met: bool, game_target_met: bool, _target_bankroll: int, required_net: int, remaining_games: int) -> String:
	if showdown_pending:
		return "Rourke is calling you to the back room."
	if high_roller_ready:
		return "Gold Players Card review is ready at the Cage."
	if dirty_money_showdown_ready:
		return "The Players Card review is sending the win to Rourke."
	if heat_route_ready:
		return "Heat is drawing Rourke toward the table."
	if not money_target_met:
		return "Win $%d clean on the Grand Casino floor toward Gold." % required_net
	if not game_target_met:
		return "Play %d more Grand Casino game%s before Linda can open Gold review." % [remaining_games, "" if remaining_games == 1 else "s"]
	return "Keep heat low so Linda can open Gold review."


func _grand_casino_result_has_wager(result: Dictionary) -> bool:
	if int(result.get("stake", 0)) > 0 or int(result.get("stake_cost", 0)) > 0:
		return true
	var deltas := _copy_dict(result.get("deltas", {}))
	for key in ["stake_cost", "slot_stake_cost", "bar_dice_stake", "video_poker_bet", "baccarat_total_wager", "roulette_total_wager"]:
		if int(result.get(key, deltas.get(key, 0))) > 0:
			return true
	for entry_value in _copy_array(deltas.get("story_log", [])):
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if int(entry.get("stake_cost", 0)) > 0:
			return true
	return false


func _grand_casino_result_pit_boss_heat_bonus(result: Dictionary) -> int:
	var bonus := 0
	var deltas := _copy_dict(result.get("deltas", {}))
	for key in ["pit_boss_heat_bonus", "slot_pit_boss_heat_bonus"]:
		bonus = maxi(bonus, int(result.get(key, deltas.get(key, 0))))
	for entry_value in _copy_array(deltas.get("story_log", [])):
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		bonus = maxi(bonus, int(entry.get("pit_boss_heat_bonus", 0)))
	return bonus


func _append_unique_string(values: Array, id: String) -> void:
	if id.is_empty():
		return
	if not values.has(id):
		values.append(id)


func current_demo_victory_message() -> String:
	var message := str(narrative_flags.get("demo_victory_message", ""))
	if not message.strip_edges().is_empty():
		return message
	return str(demo_objective_status().get("victory_message", "Demo Victory: you beat the house for now."))


# Returns the stable purchase-location identity used by portable tickets.
# World nodes take priority so two instances of the same archetype never share
# tickets, while fixtures and legacy saves without a map still have a fallback.
static func portable_ticket_origin_key(environment: Dictionary) -> String:
	var world_node_id := str(environment.get("world_node_id", "")).strip_edges()
	if not world_node_id.is_empty():
		return "world:%s" % world_node_id
	var environment_id := str(environment.get("id", "")).strip_edges()
	if not environment_id.is_empty():
		return "environment:%s" % environment_id
	var archetype_id := str(environment.get("archetype_id", "")).strip_edges()
	return "archetype:%s" % archetype_id if not archetype_id.is_empty() else ""


static func portable_ticket_origin_name(environment: Dictionary) -> String:
	var fallback := str(environment.get("archetype_id", environment.get("id", "location"))).replace("_", " ").capitalize()
	return str(environment.get("display_name", fallback)).strip_edges()


static func portable_ticket_kind_for_item(item_id: String) -> String:
	var clean_id := item_id.strip_edges()
	for kind_value in PORTABLE_TICKET_ITEM_IDS.keys():
		var kind := str(kind_value)
		if str(PORTABLE_TICKET_ITEM_IDS.get(kind, "")) == clean_id:
			return kind
	return ""


static func is_portable_ticket_pile_item(item_id: String) -> bool:
	return not portable_ticket_kind_for_item(item_id).is_empty()


# Returns the live per-origin ticket record. Callers must not replace fields
# without following with remember_portable_ticket_state(). Ticket cell/window
# dictionaries intentionally remain shared so pointer scratching stays O(1).
func portable_ticket_state(kind: String, environment: Dictionary) -> Dictionary:
	var clean_kind := kind.strip_edges()
	var origin_key := portable_ticket_origin_key(environment)
	if not PORTABLE_TICKET_KINDS.has(clean_kind) or origin_key.is_empty():
		return {}
	var origins_value: Variant = portable_ticket_piles.get(clean_kind, {})
	if typeof(origins_value) != TYPE_DICTIONARY:
		return {}
	var state_value: Variant = (origins_value as Dictionary).get(origin_key, {})
	return state_value as Dictionary if typeof(state_value) == TYPE_DICTIONARY else {}


# Stores the player-owned portion of a ticket machine without copying its
# location-owned stock/deals. This is called at action boundaries, never per
# frame, and adds/removes the inventory marker as appropriate.
func remember_portable_ticket_state(kind: String, environment: Dictionary, state: Dictionary) -> void:
	var clean_kind := kind.strip_edges()
	var origin_key := portable_ticket_origin_key(environment)
	if not PORTABLE_TICKET_KINDS.has(clean_kind) or origin_key.is_empty():
		return
	# Machine modules hand over their owned arrays at an action boundary. Keep
	# those live references here; save serialization is the deep-copy boundary.
	# Re-copying an accumulated ticket pile after every purchase is quadratic.
	var stored := state.duplicate(false)
	stored["origin_key"] = origin_key
	stored["origin_name"] = portable_ticket_origin_name(environment)
	stored["origin_environment_id"] = str(environment.get("id", "")).strip_edges()
	stored["origin_world_node_id"] = str(environment.get("world_node_id", "")).strip_edges()
	stored["origin_archetype_id"] = str(environment.get("archetype_id", "")).strip_edges()
	var origins_value: Variant = portable_ticket_piles.get(clean_kind, {})
	var origins: Dictionary = (origins_value as Dictionary).duplicate(false) if typeof(origins_value) == TYPE_DICTIONARY else {}
	origins[origin_key] = stored
	portable_ticket_piles[clean_kind] = origins
	_sync_portable_ticket_inventory_markers()


func capture_portable_ticket_piles_from_environment(environment: Dictionary) -> void:
	if environment.is_empty():
		return
	var game_states_value: Variant = environment.get("game_states", {})
	if typeof(game_states_value) != TYPE_DICTIONARY:
		return
	var game_states: Dictionary = game_states_value
	for kind_value in PORTABLE_TICKET_KINDS:
		var kind := str(kind_value)
		var machine_value: Variant = game_states.get(kind, {})
		if typeof(machine_value) != TYPE_DICTIONARY or (machine_value as Dictionary).is_empty():
			continue
		var player_state := _portable_ticket_player_state(kind, machine_value as Dictionary)
		if _portable_ticket_state_count(kind, player_state) > 0 or not portable_ticket_state(kind, environment).is_empty():
			remember_portable_ticket_state(kind, environment, player_state)


func restore_portable_ticket_piles_to_environment(environment: Dictionary) -> void:
	if environment.is_empty():
		return
	var game_states_value: Variant = environment.get("game_states", {})
	if typeof(game_states_value) != TYPE_DICTIONARY:
		return
	var game_states: Dictionary = (game_states_value as Dictionary).duplicate(false)
	var changed := false
	for kind_value in PORTABLE_TICKET_KINDS:
		var kind := str(kind_value)
		var portable := portable_ticket_state(kind, environment)
		if portable.is_empty():
			continue
		var machine_value: Variant = game_states.get(kind, {})
		if typeof(machine_value) != TYPE_DICTIONARY or (machine_value as Dictionary).is_empty():
			continue
		var machine: Dictionary = machine_value
		_apply_portable_ticket_state_to_machine(kind, portable, machine)
		game_states[kind] = machine
		changed = true
	if changed:
		environment["game_states"] = game_states


func portable_ticket_pile_summary(item_id: String) -> Dictionary:
	var kind := portable_ticket_kind_for_item(item_id)
	if kind.is_empty():
		return {}
	var total_count := 0
	var unplayed_count := 0
	var winner_count := 0
	var face_value := 0
	var origin_names: Array = []
	var origins_value: Variant = portable_ticket_piles.get(kind, {})
	if typeof(origins_value) == TYPE_DICTIONARY:
		for state_value in (origins_value as Dictionary).values():
			if typeof(state_value) != TYPE_DICTIONARY:
				continue
			var state: Dictionary = state_value
			var state_count := _portable_ticket_state_count(kind, state)
			if state_count <= 0:
				continue
			total_count += state_count
			var origin_name := str(state.get("origin_name", "Unknown location")).strip_edges()
			if not origin_name.is_empty() and not origin_names.has(origin_name):
				origin_names.append(origin_name)
			var winners := _portable_ticket_dictionary_array(state.get("winner_pile", []))
			winner_count += winners.size()
			for ticket in winners:
				face_value += maxi(0, int((ticket as Dictionary).get("payout", 0)))
			if kind == "pull_tabs":
				unplayed_count += _portable_ticket_array_size(state.get("tray_stack", []))
				for ticket in _portable_ticket_dictionary_array(state.get("ticket_stack", [])):
					var ticket_data: Dictionary = ticket
					var rows := _copy_array(ticket_data.get("rows", []))
					if int(ticket_data.get("revealed_count", 0)) < rows.size():
						unplayed_count += 1
			else:
				var active := _copy_dict(state.get("active_ticket", {}))
				if not active.is_empty():
					unplayed_count += 1
	return {
		"kind": kind,
		"item_id": str(PORTABLE_TICKET_ITEM_IDS.get(kind, "")),
		"ticket_count": total_count,
		"unplayed_count": unplayed_count,
		"winner_count": winner_count,
		"face_value": face_value,
		"sal_cash_value": int(face_value / 5),
		"origin_count": origin_names.size(),
		"origin_names": origin_names,
	}


# Removes only completed, verified winners. Unknown outcomes and partially
# opened tickets remain playable, preventing Sal's fallback from becoming an
# outcome-inspection exploit.
func surrender_portable_ticket_winners_to_sal(item_id: String) -> Dictionary:
	var summary := portable_ticket_pile_summary(item_id)
	var kind := str(summary.get("kind", ""))
	var face_value := maxi(0, int(summary.get("face_value", 0)))
	var cash_value := maxi(0, int(summary.get("sal_cash_value", 0)))
	if kind.is_empty() or int(summary.get("winner_count", 0)) <= 0:
		return {"ok": false, "message": "There are no revealed winning tickets for Sal to cash."}
	if cash_value <= 0:
		return {"ok": false, "message": "Those winning tickets are worth less than $5; Sal cannot pay a whole dollar for them."}
	var removed_count := 0
	var origins_value: Variant = portable_ticket_piles.get(kind, {})
	if typeof(origins_value) == TYPE_DICTIONARY:
		for origin_key_value in (origins_value as Dictionary).keys():
			var state_value: Variant = (origins_value as Dictionary).get(origin_key_value, {})
			if typeof(state_value) != TYPE_DICTIONARY:
				continue
			var state: Dictionary = state_value
			removed_count += _portable_ticket_array_size(state.get("winner_pile", []))
			state["winner_pile"] = []
	_sync_portable_ticket_inventory_markers()
	return {
		"ok": true,
		"kind": kind,
		"item_id": item_id,
		"ticket_count": removed_count,
		"face_value": face_value,
		"cash_value": cash_value,
	}


# Adds a run item if it is not already owned.
func add_item(item_id: String) -> void:
	if item_id.is_empty():
		return
	if not inventory.has(item_id):
		inventory.append(item_id)


# Removes a run item and clears the active slot if that item was equipped.
func remove_item(item_id: String) -> void:
	if item_id.is_empty():
		return
	if is_portable_ticket_pile_item(item_id) and int(portable_ticket_pile_summary(item_id).get("ticket_count", 0)) > 0:
		return
	inventory.erase(item_id)
	if active_item_id == item_id:
		active_item_id = ""


# Sets the selected active item id. Validation belongs to the action service
# because it owns item definitions.
func set_active_item(item_id: String) -> void:
	active_item_id = item_id if inventory.has(item_id) else ""


# Sums passive numeric item effects for owned run inventory.
func item_effect_total(key: String, game_family: String = "", action_kind: String = "") -> int:
	var effect_key := key.strip_edges()
	if effect_key.is_empty():
		return 0
	var family_key := game_family.strip_edges()
	var action_key := action_kind.strip_edges()
	var effects_by_id := _item_effect_index()
	var owned_lookup := _owned_item_lookup()
	var total := 0
	for inventory_entry in inventory:
		var item_id := _inventory_item_id(inventory_entry)
		if item_id.is_empty():
			continue
		var effect := _inventory_entry_effect(inventory_entry)
		if effect.is_empty():
			effect = _copy_dict(effects_by_id.get(item_id, {}))
		if effect.is_empty():
			continue
		total += _numeric_effect_value(effect, effect_key)
		if action_key == "cheat":
			total += _numeric_effect_value(effect, "cheat_%s" % effect_key)
		elif action_key == "legal":
			total += _numeric_effect_value(effect, "legal_%s" % effect_key)
		if not family_key.is_empty():
			var families := _copy_dict(effect.get("families", {}))
			total += _numeric_effect_value(_copy_dict(families.get(family_key, {})), effect_key)
		total += _synergy_effect_total(effect, effect_key, family_key, action_key, owned_lookup)
	return total


func _inventory_entry_effect(entry: Variant) -> Dictionary:
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = entry
	return _copy_dict(data.get("effect", {}))


func _owned_item_lookup() -> Dictionary:
	var result := {}
	for inventory_entry in inventory:
		var item_id := _inventory_item_id(inventory_entry)
		if not item_id.is_empty():
			result[item_id] = true
	return result


func _synergy_effect_total(effect: Dictionary, effect_key: String, family_key: String, action_key: String, owned_lookup: Dictionary) -> int:
	var total := 0
	for synergy_value in _copy_array(effect.get("synergies", [])):
		if typeof(synergy_value) != TYPE_DICTIONARY:
			continue
		var synergy: Dictionary = synergy_value
		if not _synergy_requirements_met(synergy, owned_lookup):
			continue
		var synergy_effects := _copy_dict(synergy.get("effects", {}))
		total += _numeric_effect_value(synergy_effects, effect_key)
		if action_key == "cheat":
			total += _numeric_effect_value(synergy_effects, "cheat_%s" % effect_key)
		elif action_key == "legal":
			total += _numeric_effect_value(synergy_effects, "legal_%s" % effect_key)
		if not family_key.is_empty():
			var families := _copy_dict(synergy.get("families", {}))
			var family_effect := _copy_dict(families.get(family_key, {}))
			total += _numeric_effect_value(family_effect, effect_key)
	return total


static func _synergy_requirements_met(synergy: Dictionary, owned_lookup: Dictionary) -> bool:
	for item_id in _string_array(_copy_array(synergy.get("requires_all", []))):
		if not owned_lookup.has(str(item_id)):
			return false
	var required_any := _string_array(_copy_array(synergy.get("requires_any", [])))
	if required_any.is_empty():
		return true
	for item_id in required_any:
		if owned_lookup.has(str(item_id)):
			return true
	return false


# Removes an item offer from the current environment.
func remove_item_offer(item_id: String) -> void:
	var offers: Array = current_environment.get("item_offers", [])
	var removed_forfeited := false
	for index in range(offers.size() - 1, -1, -1):
		var offer: Variant = offers[index]
		if typeof(offer) == TYPE_DICTIONARY and offer.get("id", "") == item_id:
			removed_forfeited = removed_forfeited or bool((offer as Dictionary).get("forfeited_pawn_shelf", false))
			offers.remove_at(index)
	current_environment["item_offers"] = offers
	if removed_forfeited:
		remove_sals_forfeited_item(item_id)
	if current_environment.has("layout"):
		current_environment["layout"] = EnvironmentInstance.ensure_generated_layout(current_environment)


# Adds a debt entry and refreshes economy state.
func add_debt(debt_data: Dictionary) -> void:
	var normalized := _normalize_debt_entries([debt_data])
	if normalized.is_empty():
		return
	var debt_entry: Dictionary = normalized[0]
	_apply_debt_item_modifiers_to_new_debt(debt_entry)
	if _merge_stackable_debt(debt_entry):
		_refresh_economy()
		return
	debt.append(debt_entry)
	_refresh_economy()


func repay_debt(debt_id: String, amount: int = -1) -> Dictionary:
	var index := _debt_index(debt_id)
	if index < 0:
		return {"ok": false, "message": "Debt is not active."}
	var debt_data := (debt[index] as Dictionary).duplicate(true)
	var balance := maxi(0, int(debt_data.get("balance", 0)))
	if balance <= 0:
		debt.remove_at(index)
		_refresh_economy()
		return {"ok": true, "message": "Debt already cleared.", "debt_id": debt_id}
	var payment := balance if amount < 0 else clampi(amount, 1, balance)
	if payment > bankroll:
		return {"ok": false, "message": "Not enough bankroll to repay this debt.", "debt_id": debt_id}
	change_bankroll(-payment)
	balance -= payment
	debt_data["balance"] = balance
	var paid_off := balance <= 0
	var message := "Paid %d toward %s." % [payment, _debt_lender_label(debt_data)]
	if paid_off:
		message = _settle_paid_debt(index, debt_data, payment)
	else:
		debt[index] = debt_data
		log_story({
			"type": "debt_payment",
			"debt_id": str(debt_data.get("id", debt_id)),
			"lender_id": str(debt_data.get("lender_id", "")),
			"bankroll_delta": -payment,
			"balance": balance,
			"message": message,
		})
	_refresh_economy()
	return {
		"ok": true,
		"message": message,
		"debt_id": debt_id,
		"paid_off": paid_off,
		"payment": payment,
		"balance": balance,
	}


func complete_debt_favor(debt_id: String) -> Dictionary:
	var index := _debt_index(debt_id)
	if index < 0:
		return {"ok": false, "message": "Favor debt is not active."}
	var debt_data := (debt[index] as Dictionary).duplicate(true)
	if str(debt_data.get("debt_kind", "")) != "favor":
		return {"ok": false, "message": "This debt is not favor-based.", "debt_id": debt_id}
	var favor_balance := maxi(0, int(debt_data.get("balance", 0)))
	if favor_balance <= 0:
		debt.remove_at(index)
		_refresh_economy()
		return {"ok": true, "message": "The marker is already clear.", "debt_id": debt_id}
	favor_balance -= 1
	debt_data["balance"] = favor_balance
	debt_data["status"] = "active" if favor_balance > 0 else "paid"
	debt_data["turns_remaining"] = maxi(0, int(debt_data.get("deadline_turns", 0)))
	narrative_flags["crew_favor_pending"] = false
	var message := "You do the Crew's favor and knock one marker off the slate."
	if favor_balance <= 0:
		debt.remove_at(index)
		narrative_flags["crew_marker_clear"] = true
		message = "You finish the Crew's last favor and clear the marker."
	else:
		debt[index] = debt_data
	log_story({
		"type": "debt_favor_completed",
		"debt_id": str(debt_data.get("id", debt_id)),
		"lender_id": str(debt_data.get("lender_id", "")),
		"balance": favor_balance,
		"message": message,
	})
	_refresh_economy()
	return {"ok": true, "message": message, "debt_id": debt_id, "balance": favor_balance}


func refuse_debt_favor(debt_id: String) -> Dictionary:
	var index := _debt_index(debt_id)
	if index < 0:
		return {"ok": false, "message": "Favor debt is not active."}
	var debt_data := (debt[index] as Dictionary).duplicate(true)
	if str(debt_data.get("debt_kind", "")) != "favor":
		return {"ok": false, "message": "This debt is not favor-based.", "debt_id": debt_id}
	var favor_balance := maxi(1, int(debt_data.get("balance", 1)))
	var cash_per_favor := maxi(1, int(debt_data.get("cash_conversion_balance_per_favor", 45)))
	var cash_balance := favor_balance * cash_per_favor
	debt_data["balance"] = cash_balance
	debt_data["debt_kind"] = "cash"
	debt_data["status"] = "active"
	debt_data["interest_rate"] = maxf(0.0, float(debt_data.get("cash_conversion_interest_rate", 0.35)))
	debt_data["default_consequence"] = "forced_repayment"
	debt_data["deadline_turns"] = 3
	debt_data["turns_remaining"] = 3
	narrative_flags["crew_favor_pending"] = false
	narrative_flags["crew_marker_converted_to_cash"] = true
	debt[index] = debt_data
	var message := "You refuse the Crew's favor; the marker becomes cash at brutal rates."
	log_story({
		"type": "debt_favor_refused",
		"debt_id": str(debt_data.get("id", debt_id)),
		"lender_id": str(debt_data.get("lender_id", "")),
		"balance": cash_balance,
		"message": message,
	})
	_refresh_economy()
	return {"ok": true, "message": message, "debt_id": debt_id, "balance": cash_balance}


func default_debt(debt_id: String) -> Dictionary:
	var index := _debt_index(debt_id)
	if index < 0:
		return {"ok": false, "message": "Debt is not active."}
	return _apply_debt_default(index, true)


# Returns the current economy label.
func economy() -> String:
	return economic_state


# Returns whether a route can currently be traveled without mutating state.
func travel_route_status(route_data: Dictionary) -> Dictionary:
	var cost := maxi(0, int(route_data.get("cost", 0)))
	var status := {
		"available": true,
		"disabled_reason": "",
		"cost": cost,
		"risk": str(route_data.get("risk", "")),
		"suspicion_delta": int(route_data.get("suspicion_delta", 0)),
		"distance": str(route_data.get("distance", "near")),
		"risk_decay": travel_risk_decay(route_data),
		"condition_text": str(route_data.get("condition_text", "")),
		"hidden": false,
		"requires_travel_count_min": maxi(0, int(route_data.get("requires_travel_count_min", 0))),
		"travel_count": environment_travel_count(),
	}
	if _route_locked_hint_enabled(route_data):
		status["locked"] = false
	var lock_remaining := current_travel_lock_remaining()
	if lock_remaining > 0:
		status["available"] = false
		status["disabled_reason"] = _travel_lock_disabled_reason(lock_remaining)
		status["travel_lock_remaining"] = lock_remaining
		return _finalize_travel_route_status(status, route_data)
	var required_travel_count := int(status.get("requires_travel_count_min", 0))
	if required_travel_count > environment_travel_count():
		status["available"] = false
		status["hidden"] = bool(route_data.get("hide_until_travel_count_met", false))
		status["disabled_reason"] = str(route_data.get("travel_count_condition_text", route_data.get("condition_text", "Travel farther before this route appears.")))
		if bool(status.get("hidden", false)) and _route_locked_hint_enabled(route_data):
			_apply_locked_route_hint(status)
		return _finalize_travel_route_status(status, route_data)
	var route_window := _route_availability_status(route_data)
	if not bool(route_window.get("available", true)):
		status["available"] = false
		status["disabled_reason"] = str(route_window.get("disabled_reason", "This route is closed right now."))
		status["availability_window"] = _copy_dict(route_window.get("availability_window", {}))
		status["availability_turn"] = int(route_window.get("availability_turn", 0))
		return _finalize_travel_route_status(status, route_data)
	var required_flags := _copy_dict(route_data.get("requires_flags", {}))
	for key in required_flags.keys():
		if narrative_flags.get(str(key), null) != required_flags[key]:
			status["available"] = false
			status["hidden"] = true
			status["disabled_reason"] = str(route_data.get("condition_text", "A route condition is not met."))
			if _route_locked_hint_enabled(route_data):
				_apply_locked_route_hint(status)
			return _finalize_travel_route_status(status, route_data)
	for flag_id in _copy_array(route_data.get("blocked_by_flags", [])):
		if bool(narrative_flags.get(str(flag_id), false)):
			status["available"] = false
			status["disabled_reason"] = "This route is closed for now."
			return _finalize_travel_route_status(status, route_data)
	if cost > bankroll:
		status["available"] = false
		status["disabled_reason"] = "Not enough bankroll for this route."
	return _finalize_travel_route_status(status, route_data)


func _route_locked_hint_enabled(route_data: Dictionary) -> bool:
	return bool(route_data.get("locked_hint", false))


func _apply_locked_route_hint(status: Dictionary) -> void:
	status["hidden"] = false
	status["locked"] = true


# Returns whether the run has enough scouting help to see exact route previews.
func travel_scouting_level() -> int:
	var item_level := maxi(0, item_effect_total("travel_scouting_level", "travel"))
	var service_level := 1 if bool(narrative_flags.get("route_scouting_active", false)) else 0
	return maxi(item_level, service_level)


# Builds player-facing preview metadata for a route destination.
func travel_route_preview(route_data: Dictionary, destination_archetype: Dictionary, destination_environment: Dictionary = {}, full_preview: bool = false) -> Dictionary:
	var archetype_id := str(destination_archetype.get("id", route_data.get("destination_archetype", ""))).strip_edges()
	var tier := int(destination_archetype.get("tier", destination_environment.get("tier", 1)))
	var kind := str(destination_archetype.get("kind", destination_environment.get("kind", "")))
	var preview := {
		"level": "full" if full_preview else "partial",
		"destination_archetype": archetype_id,
		"kind": kind,
		"tier": tier,
		"lines": [],
	}
	var source_environment := destination_environment if full_preview and not destination_environment.is_empty() else {}
	var game_ids := _string_array(_copy_array(source_environment.get("game_ids", [])))
	var service_ids := _string_array(_copy_array(source_environment.get("service_ids", [])))
	var lender_ids := _string_array(_copy_array(source_environment.get("lender_hooks", [])))
	var item_ids := _travel_item_offer_ids(_copy_array(source_environment.get("item_offers", [])))
	if game_ids.is_empty():
		game_ids = _unique_strings(_copy_array(destination_archetype.get("required_game_ids", [])) + _copy_array(destination_archetype.get("game_pool", [])))
	if service_ids.is_empty():
		service_ids = _string_array(_copy_array(destination_archetype.get("service_pool", [])))
	if lender_ids.is_empty():
		lender_ids = _string_array(_copy_array(destination_archetype.get("lender_hooks", [])))
	if item_ids.is_empty():
		item_ids = _string_array(_copy_array(destination_archetype.get("item_pool", [])))
	var game_range := _travel_count_range(destination_archetype.get("game_count", game_ids.size()), game_ids.size())
	var item_range := _travel_count_range(destination_archetype.get("item_count", item_ids.size()), item_ids.size())
	preview["game_count_min"] = int(game_range[0])
	preview["game_count_max"] = int(game_range[1])
	preview["item_count_min"] = int(item_range[0])
	preview["item_count_max"] = int(item_range[1])
	preview["service_count"] = service_ids.size()
	preview["lender_count"] = lender_ids.size()
	preview["travel_locked_actions"] = maxi(0, int(destination_archetype.get("travel_locked_actions", destination_environment.get("travel_locked_actions", 0))))
	var lines: Array = []
	lines.append("Preview: tier %d %s." % [tier, kind])
	if full_preview:
		preview["game_ids"] = game_ids.duplicate(true)
		preview["service_ids"] = service_ids.duplicate(true)
		preview["lender_ids"] = lender_ids.duplicate(true)
		preview["item_ids"] = item_ids.duplicate(true)
		lines.append("Scout: games %s." % _travel_id_list_text(game_ids, "none"))
		if not service_ids.is_empty() or not lender_ids.is_empty():
			lines.append("Scout: services %s; lenders %s." % [_travel_id_list_text(service_ids, "none"), _travel_id_list_text(lender_ids, "none")])
		if not item_ids.is_empty():
			lines.append("Scout: shop can show %s." % _travel_id_list_text(item_ids.slice(0, 4), "no items"))
	else:
		lines.append("Likely: %s, %s." % [_travel_count_range_label("game", game_range), _travel_count_range_label("item", item_range)])
		if service_ids.size() > 0 or lender_ids.size() > 0:
			lines.append("Known hooks: %d service(s), %d lender(s)." % [service_ids.size(), lender_ids.size()])
	var locked_actions := int(preview.get("travel_locked_actions", 0))
	if locked_actions > 0:
		lines.append("Boarding locks travel for %d action(s)." % locked_actions)
	preview["lines"] = lines
	return preview


# Returns non-mutating risk-event metadata for a route.
func travel_route_risk_preview(route_data: Dictionary) -> Dictionary:
	var risk_event := _copy_dict(route_data.get("risk_event", {}))
	if risk_event.is_empty():
		return {}
	var chance := clampi(int(risk_event.get("chance_percent", 0)), 0, 100)
	if chance <= 0:
		return {}
	var event_id := str(risk_event.get("id", "travel_risk")).strip_edges()
	return {
		"id": event_id,
		"label": str(risk_event.get("label", event_id.replace("_", " ").capitalize())),
		"chance_percent": chance,
		"bankroll_delta": int(risk_event.get("bankroll_delta", 0)),
		"suspicion_delta": int(risk_event.get("suspicion_delta", 0)),
		"message": str(risk_event.get("message", "")),
	}


# Resolves a route risk event without mutating the run.
func travel_route_risk(route_data: Dictionary, route_id: String = "") -> Dictionary:
	var risk := travel_route_risk_preview(route_data)
	if risk.is_empty():
		return {"triggered": false, "chance_percent": 0, "roll": 0}
	var resolved_route_id := route_id.strip_edges()
	if resolved_route_id.is_empty():
		resolved_route_id = str(route_data.get("id", route_data.get("destination_archetype", ""))).strip_edges()
	var source_environment_id := str(current_environment.get("id", "")).strip_edges()
	var seed_source := "%s|%d|%s|%s|%d" % [
		seed_text,
		seed_value,
		source_environment_id,
		resolved_route_id,
		environment_travel_count(),
	]
	var roll := (text_to_seed(seed_source) % 100) + 1
	var triggered := roll <= int(risk.get("chance_percent", 0))
	risk["roll"] = roll
	risk["triggered"] = triggered
	if not triggered:
		risk["bankroll_delta"] = 0
		risk["suspicion_delta"] = 0
		risk["message"] = ""
	return risk


# Returns the number of action beats before this room allows travel again.
func current_travel_lock_remaining() -> int:
	if current_environment.is_empty():
		return 0
	return maxi(0, int(current_environment.get("travel_lock_remaining", 0)))


func _travel_lock_disabled_reason(lock_remaining: int) -> String:
	var actions := maxi(0, lock_remaining)
	var noun := "action" if actions == 1 else "actions"
	var archetype_id := str(current_environment.get("archetype_id", ""))
	if archetype_id == "delta_queen":
		return "The River Queen is out on the river for %d more %s." % [actions, noun]
	return "Travel unlocks after %d more %s." % [actions, noun]


func _route_availability_status(route_data: Dictionary) -> Dictionary:
	var window := _copy_dict(route_data.get("availability_window", {}))
	if window.is_empty():
		return {"available": true}
	var period := maxi(1, int(window.get("period", 1)))
	var open_turns := _int_array(window.get("open_turns", []))
	if open_turns.is_empty():
		return {"available": true}
	var current_turn := int(current_environment.get("turns", 0)) % period
	if open_turns.has(current_turn):
		return {
			"available": true,
			"availability_window": window,
			"availability_turn": current_turn,
		}
	return {
		"available": false,
		"disabled_reason": str(window.get("closed_text", "This route is closed right now.")),
		"availability_window": window,
		"availability_turn": current_turn,
	}


func _finalize_travel_route_status(status: Dictionary, route_data: Dictionary) -> Dictionary:
	var finalized := status.duplicate(true)
	var risk_preview := travel_route_risk_preview(route_data)
	if not risk_preview.is_empty():
		finalized["risk_event"] = risk_preview
	var risk_text := str(route_data.get("risk_text", "")).strip_edges()
	if not risk_text.is_empty():
		finalized["risk_text"] = risk_text
	var unlock_conditions := _travel_unlock_conditions(route_data, finalized)
	finalized["unlock_conditions"] = unlock_conditions
	var disabled_reason := str(finalized.get("disabled_reason", "")).strip_edges()
	if not disabled_reason.is_empty():
		finalized["unlock_summary"] = disabled_reason
	elif not unlock_conditions.is_empty():
		finalized["unlock_summary"] = "; ".join(unlock_conditions)
	else:
		finalized["unlock_summary"] = ""
	return finalized


func _travel_unlock_conditions(route_data: Dictionary, status: Dictionary) -> Array:
	var conditions: Array = []
	var condition_text := str(route_data.get("condition_text", "")).strip_edges()
	if not condition_text.is_empty():
		conditions.append(condition_text)
	var required_travel_count := maxi(0, int(route_data.get("requires_travel_count_min", 0)))
	if required_travel_count > 0:
		conditions.append("Travel count %d/%d." % [environment_travel_count(), required_travel_count])
	var lock_remaining := maxi(0, int(status.get("travel_lock_remaining", 0)))
	if lock_remaining > 0:
		conditions.append(_travel_lock_disabled_reason(lock_remaining))
	var window := _copy_dict(route_data.get("availability_window", {}))
	if not window.is_empty():
		var period := maxi(1, int(window.get("period", 1)))
		var open_turns := _int_array(window.get("open_turns", []))
		if not open_turns.is_empty():
			conditions.append("Open on schedule turns %s of %d." % [", ".join(_int_text_array(open_turns)), period])
	var required_flags := _copy_dict(route_data.get("requires_flags", {}))
	if not required_flags.is_empty() and condition_text.is_empty():
		conditions.append("Needs route intel.")
	var blocked_flags := _copy_array(route_data.get("blocked_by_flags", []))
	if not blocked_flags.is_empty():
		conditions.append("Can close after story choices.")
	var cost := maxi(0, int(status.get("cost", route_data.get("cost", 0))))
	if cost > bankroll:
		conditions.append("Needs %d bankroll." % cost)
	return conditions


func _travel_item_offer_ids(item_offers: Array) -> Array:
	var ids: Array = []
	for offer_value in item_offers:
		if typeof(offer_value) == TYPE_DICTIONARY:
			var item_id := str((offer_value as Dictionary).get("id", "")).strip_edges()
			if not item_id.is_empty() and not ids.has(item_id):
				ids.append(item_id)
	return ids


func _travel_count_range(value: Variant, fallback_count: int) -> Array:
	if typeof(value) == TYPE_ARRAY:
		var values := _int_array(value)
		if values.is_empty():
			return [maxi(0, fallback_count), maxi(0, fallback_count)]
		var min_count: int = int(values[0])
		var max_count: int = int(values[0])
		for count_value in values:
			min_count = mini(min_count, int(count_value))
			max_count = maxi(max_count, int(count_value))
		return [maxi(0, min_count), maxi(0, max_count)]
	var count := maxi(0, int(value))
	if count <= 0 and fallback_count > 0:
		count = fallback_count
	return [count, count]


func _travel_count_range_label(noun: String, count_range: Array) -> String:
	var min_count := int(count_range[0]) if count_range.size() > 0 else 0
	var max_count := int(count_range[1]) if count_range.size() > 1 else min_count
	var plural := "%ss" % noun
	if min_count == max_count:
		return "%d %s" % [min_count, noun if min_count == 1 else plural]
	return "%d-%d %s" % [min_count, max_count, plural]


func _travel_id_list_text(ids: Array, empty_text: String) -> String:
	var labels: Array = []
	for id_value in _string_array(ids):
		labels.append(str(id_value).replace("_", " "))
	if labels.is_empty():
		return empty_text
	return ", ".join(labels)


func _unique_strings(values: Array) -> Array:
	var result: Array = []
	for value in _string_array(values):
		if not result.has(value):
			result.append(value)
	return result


func _int_text_array(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(str(int(value)))
	return result


# Returns how much local heat a route sheds before arrival.
func travel_risk_decay(route_data: Dictionary) -> int:
	var base_decay := 0
	if route_data.has("risk_decay"):
		base_decay = clampi(int(route_data.get("risk_decay", 0)), 0, 100)
	else:
		var distance := str(route_data.get("distance", "near")).to_lower()
		base_decay = clampi(int(LOCAL_RISK_DECAY_BY_DISTANCE.get(distance, LOCAL_RISK_DECAY_BY_DISTANCE["near"])), 0, 100)
	var modifier := int(challenge_modifiers().get("local_risk_decay_percent_delta", 0))
	return clampi(base_decay + modifier, 0, 100)


# Stores source heat and calculates carried heat before the new environment is generated.
func begin_travel_suspicion_decay(route_data: Dictionary, destination_archetype_id: String = "") -> Dictionary:
	_store_current_local_suspicion()
	var source_location_id := current_suspicion_location_id()
	var destination_location_id := str(destination_archetype_id).strip_edges()
	if destination_location_id.is_empty():
		destination_location_id = str(route_data.get("destination_archetype", "")).strip_edges()
	if GRAND_CASINO_ARCHETYPE_IDS.has(destination_location_id):
		destination_location_id = GRAND_CASINO_ARCHETYPE_ID
	var distance := str(route_data.get("distance", "near")).to_lower()
	var route_decay_percent := travel_risk_decay(route_data)
	var same_location := not destination_location_id.is_empty() and destination_location_id == source_location_id
	var effective_route_decay := 0 if same_location else route_decay_percent
	var before := suspicion_level()
	var levels := _local_suspicion_levels()
	var source_after := before
	if not source_location_id.is_empty():
		source_after = before if same_location else _decayed_suspicion_level(before, LOCAL_HEAT_RETURN_DECAY_PERCENT)
		levels[source_location_id] = source_after
	suspicion["local_levels"] = levels
	suspicion["level"] = clampi(source_after, 0, 100)
	if source_after != before:
		_record_heat_history(false)
	var carried_heat := before if same_location else _decayed_suspicion_level(before, effective_route_decay)
	return {
		"distance": distance,
		"risk_decay": effective_route_decay,
		"source_location_id": source_location_id,
		"destination_location_id": destination_location_id,
		"before": before,
		"source_after": clampi(source_after, 0, 100),
		"carried_heat": clampi(carried_heat, 0, 100),
		"return_decay": 0 if same_location else LOCAL_HEAT_RETURN_DECAY_PERCENT,
		"same_location": same_location,
	}


# Activates destination heat after RunGenerator has assigned the new environment.
func finish_travel_suspicion_decay(travel_heat: Dictionary) -> Dictionary:
	var source_location_id := str(travel_heat.get("source_location_id", "")).strip_edges()
	var destination_location_id := current_suspicion_location_id()
	var expected_destination_id := str(travel_heat.get("destination_location_id", "")).strip_edges()
	if destination_location_id.is_empty():
		destination_location_id = expected_destination_id
	var before := clampi(int(travel_heat.get("before", suspicion_level())), 0, 100)
	var carried_heat := clampi(int(travel_heat.get("carried_heat", before)), 0, 100)
	var levels := _local_suspicion_levels()
	var remembered_destination: int = clampi(int(levels.get(destination_location_id, 0)), 0, 100) if not destination_location_id.is_empty() else 0
	var same_location := bool(travel_heat.get("same_location", false)) or (not source_location_id.is_empty() and source_location_id == destination_location_id)
	var destination_after: int = carried_heat if same_location else maxi(remembered_destination, carried_heat)
	destination_after = clampi(destination_after, 0, 100)
	if not destination_location_id.is_empty():
		levels[destination_location_id] = destination_after
	suspicion["local_levels"] = levels
	suspicion["level"] = destination_after
	_record_heat_history(false)
	_evaluate_immediate_terminal_state()
	var result := travel_heat.duplicate(true)
	result["destination_location_id"] = destination_location_id
	result["destination_before"] = remembered_destination
	result["destination_after"] = destination_after
	result["after"] = destination_after
	result["cooled"] = maxi(0, before - destination_after)
	var drunk_before := drunk_level
	var distance := str(travel_heat.get("distance", "near")).to_lower()
	var drunk_decay := int(DRUNK_TRAVEL_DECAY_BY_DISTANCE.get(distance, DRUNK_TRAVEL_DECAY_BY_DISTANCE["near"]))
	if drunk_decay > 0:
		change_drunk(-drunk_decay)
	result["drunk_before"] = drunk_before
	result["drunk_after"] = drunk_level
	result["drunk_delta"] = drunk_level - drunk_before
	return result


# Returns whether a service hook can currently be used without mutating state.
func service_hook_status(service_data: Dictionary) -> Dictionary:
	var cost := maxi(0, int(round(float(service_data.get("cost", 0)) * challenge_service_cost_multiplier(service_data))))
	var status := {
		"available": true,
		"disabled_reason": "",
		"cost": cost,
		"availability_class": AVAILABILITY_AVAILABLE,
	}
	if service_data.is_empty():
		status["available"] = false
		status["disabled_reason"] = "Service is not available here."
		status["availability_class"] = AVAILABILITY_CATEGORICAL_UNAVAILABLE
		return status
	if challenge_service_category_blocked(str(service_data.get("category", ""))):
		status["available"] = false
		status["disabled_reason"] = "This challenge blocks that service."
		status["availability_class"] = AVAILABILITY_CATEGORICAL_UNAVAILABLE
		return status
	var availability := _copy_dict(service_data.get("availability", {}))
	var single_use_flag := str(availability.get("single_use_flag", "")).strip_edges()
	if not single_use_flag.is_empty() and bool(narrative_flags.get(single_use_flag, false)):
		status["available"] = false
		status["disabled_reason"] = str(availability.get("blocked_text", "This one-time service is spent."))
		status["availability_class"] = AVAILABILITY_CATEGORICAL_UNAVAILABLE
		return status
	var required_flags := _copy_dict(availability.get("requires_flags", {}))
	for key in required_flags.keys():
		if narrative_flags.get(str(key), null) != required_flags[key]:
			status["available"] = false
			status["disabled_reason"] = str(availability.get("condition_text", "A service condition is not met."))
			status["availability_class"] = AVAILABILITY_CATEGORICAL_UNAVAILABLE
			return status
	for flag_id in _copy_array(availability.get("blocked_by_flags", [])):
		if bool(narrative_flags.get(str(flag_id), false)):
			status["available"] = false
			status["disabled_reason"] = str(availability.get("blocked_text", "This service is not available now."))
			status["availability_class"] = AVAILABILITY_CATEGORICAL_UNAVAILABLE
			return status
	if cost > bankroll:
		status["available"] = false
		status["disabled_reason"] = "Not enough bankroll for this service."
		status["availability_class"] = AVAILABILITY_TRANSIENT_BLOCKED
		return status
	var effect := _copy_dict(service_data.get("effect", {}))
	if int(effect.get("alcohol_intake", 0)) > 0 and drunk_level + pending_drunk_absorption_amount() >= ALCOHOL_MAX:
		status["available"] = false
		status["disabled_reason"] = "Too drunk to make another drink help."
		status["availability_class"] = AVAILABILITY_TRANSIENT_BLOCKED
	return status


# Returns whether a lender hook can currently be used without mutating state.
func lender_hook_status(lender_data: Dictionary) -> Dictionary:
	var lender_id := str(lender_data.get("id", ""))
	var lender_type := str(lender_data.get("lender_type", ""))
	var status := {
		"available": true,
		"disabled_reason": "",
		"active_debt": false,
		"availability_class": AVAILABILITY_AVAILABLE,
	}
	if lender_data.is_empty() or lender_id.is_empty():
		status["available"] = false
		status["disabled_reason"] = "Lender is not available here."
		status["availability_class"] = AVAILABILITY_CATEGORICAL_UNAVAILABLE
		return status
	var availability := _copy_dict(lender_data.get("availability", {}))
	var single_use_flag := str(availability.get("single_use_flag", ""))
	if not single_use_flag.is_empty() and bool(narrative_flags.get(single_use_flag, false)):
		var paid_count := _lender_paid_count(lender_id)
		if paid_count <= 0:
			status["available"] = false
			status["disabled_reason"] = "That one-time lender has already helped this run."
			status["availability_class"] = AVAILABILITY_CATEGORICAL_UNAVAILABLE
			return status
	var tier_min := maxi(0, int(availability.get("tier_min", availability.get("min_tier", 0))))
	if tier_min > 0 and int(current_environment.get("tier", 1)) < tier_min:
		status["available"] = false
		status["disabled_reason"] = "This lender only works higher up the circuit."
		status["availability_class"] = AVAILABILITY_CATEGORICAL_UNAVAILABLE
		return status
	var required_flags := _copy_dict(availability.get("requires_flags", {}))
	for key in required_flags.keys():
		if narrative_flags.get(str(key), null) != required_flags[key]:
			status["available"] = false
			status["disabled_reason"] = str(availability.get("condition_text", "A condition for this lender is not met."))
			status["availability_class"] = AVAILABILITY_CATEGORICAL_UNAVAILABLE
			return status
	for flag_id in _copy_array(availability.get("blocked_by_flags", [])):
		if bool(narrative_flags.get(str(flag_id), false)):
			status["available"] = false
			status["disabled_reason"] = "This lender will not answer again."
			status["availability_class"] = AVAILABILITY_CATEGORICAL_UNAVAILABLE
			return status
	var current_location_id := _lender_location_key()
	if lender_id == CREW_LENDER_ID or lender_type == "favor_crew":
		var crew_status := _crew_lender_repeat_status(current_location_id)
		if not bool(crew_status.get("available", true)):
			return crew_status
		return status
	else:
		var paid_environment_id := str(narrative_flags.get(_lender_paid_environment_key(lender_id), ""))
		if not current_location_id.is_empty() and paid_environment_id == current_location_id:
			status["available"] = false
			status["disabled_reason"] = "They will offer more the next time you see them."
			status["availability_class"] = AVAILABILITY_TRANSIENT_BLOCKED
			return status
	for debt_entry in debt:
		if typeof(debt_entry) != TYPE_DICTIONARY:
			continue
		var debt_data := debt_entry as Dictionary
		if str(debt_data.get("lender_id", "")) != lender_id:
			continue
		if lender_type == "pawn":
			continue
		var debt_status := str(debt_data.get("status", "active"))
		if debt_status == "active" or debt_status == "overdue" or debt_status == "favor_due":
			status["available"] = false
			status["disabled_reason"] = "You already owe this lender."
			status["active_debt"] = true
			status["availability_class"] = AVAILABILITY_TRANSIENT_BLOCKED
			return status
	return status


# Returns whether a visible lender can accept a cash repayment now.
func lender_repayment_status(lender_id: String) -> Dictionary:
	var status := {
		"available": false,
		"enabled": false,
		"disabled_reason": "No active loan to repay.",
		"debt_id": "",
		"payoff_amount": 0,
	}
	for debt_entry in debt:
		if typeof(debt_entry) != TYPE_DICTIONARY:
			continue
		var debt_data := debt_entry as Dictionary
		if str(debt_data.get("lender_id", "")) != lender_id:
			continue
		var debt_status := str(debt_data.get("status", "active"))
		if debt_status != "active" and debt_status != "overdue":
			continue
		var debt_kind := str(debt_data.get("debt_kind", "cash"))
		if debt_kind == "favor":
			status["available"] = false
			status["disabled_reason"] = "The Crew wants favors, not a cash payoff."
			return status
		var balance := maxi(0, int(debt_data.get("balance", 0)))
		status["available"] = true
		status["debt_id"] = str(debt_data.get("id", ""))
		status["payoff_amount"] = balance
		if balance <= 0 or bankroll >= balance:
			status["enabled"] = true
			status["disabled_reason"] = ""
		else:
			status["disabled_reason"] = "Need $%d to settle this loan." % balance
		return status
	return status


func pawn_tickets_for_lender(lender_id: String) -> Array:
	var result: Array = []
	for debt_entry in debt:
		if typeof(debt_entry) != TYPE_DICTIONARY:
			continue
		var debt_data := debt_entry as Dictionary
		if str(debt_data.get("lender_id", "")) != lender_id:
			continue
		if str(debt_data.get("debt_kind", "cash")) != "pawn":
			continue
		var debt_status := str(debt_data.get("status", "active"))
		if debt_status != "active" and debt_status != "overdue":
			continue
		var balance := maxi(0, int(debt_data.get("balance", 0)))
		result.append({
			"debt_id": str(debt_data.get("id", "")),
			"item_id": str(debt_data.get("collateral_item_id", "")),
			"item_name": str(debt_data.get("collateral_item_name", debt_data.get("collateral_item_id", ""))),
			"principal": maxi(0, int(debt_data.get("principal", balance))),
			"redemption_fee": maxi(0, int(debt_data.get("redemption_fee", 0))),
			"payoff_amount": balance,
			"turns_remaining": maxi(0, int(debt_data.get("turns_remaining", debt_data.get("deadline_turns", 0)))),
			"status": debt_status,
			"enabled": balance <= 0 or bankroll >= balance,
			"disabled_reason": "" if balance <= 0 or bankroll >= balance else "Need $%d to buy back this ticket." % balance,
		})
	return result


func add_sals_forfeited_item(item_id: String) -> void:
	var normalized_id := item_id.strip_edges()
	if normalized_id.is_empty():
		return
	sals_forfeited_item_ids.append(normalized_id)


func remove_sals_forfeited_item(item_id: String) -> void:
	var normalized_id := item_id.strip_edges()
	if normalized_id.is_empty():
		return
	for index in range(sals_forfeited_item_ids.size() - 1, -1, -1):
		if str(sals_forfeited_item_ids[index]) == normalized_id:
			sals_forfeited_item_ids.remove_at(index)
			return


func _crew_lender_repeat_status(current_location_id: String) -> Dictionary:
	var status := {
		"available": true,
		"disabled_reason": "",
		"active_debt": false,
		"availability_class": AVAILABILITY_AVAILABLE,
	}
	var location_lookup := {}
	var open_locations := 0
	for debt_entry in debt:
		if typeof(debt_entry) != TYPE_DICTIONARY:
			continue
		var debt_data := debt_entry as Dictionary
		if str(debt_data.get("lender_id", "")) != CREW_LENDER_ID:
			continue
		var debt_status := str(debt_data.get("status", "active"))
		if debt_status != "active" and debt_status != "overdue" and debt_status != "favor_due":
			continue
		for location_value in _copy_array(debt_data.get("source_location_ids", [])):
			var location_id := str(location_value)
			if location_id.is_empty() or location_lookup.has(location_id):
				continue
			location_lookup[location_id] = true
			open_locations += 1
		var single_location_id := str(debt_data.get("source_location_id", ""))
		if not single_location_id.is_empty() and not location_lookup.has(single_location_id):
			location_lookup[single_location_id] = true
			open_locations += 1
	if not current_location_id.is_empty() and location_lookup.has(current_location_id):
		status["available"] = false
		status["disabled_reason"] = "The Crew already marked this location."
		status["active_debt"] = true
		status["availability_class"] = AVAILABILITY_TRANSIENT_BLOCKED
		return status
	if open_locations >= CREW_MAX_LOAN_LOCATIONS:
		status["available"] = false
		status["disabled_reason"] = "The Crew will not open more than three markers."
		status["active_debt"] = true
		status["availability_class"] = AVAILABILITY_TRANSIENT_BLOCKED
	return status


# Returns the max stake allowed after current economy pressure is considered.
func economy_stake_ceiling(base_ceiling: int = -1) -> int:
	var available := bankroll if base_ceiling < 0 else mini(base_ceiling, bankroll)
	available = maxi(0, available)
	match economic_state:
		"insolvent":
			return 0
		"distressed":
			return mini(available, _fractional_bankroll_limit(4))
		"volatile":
			return mini(available, _fractional_bankroll_limit(2))
		_:
			return available


# Returns the hard wager ceiling. Economy pressure may recommend smaller bets,
# but wager actions can still risk any cash the player actually has.
func wager_stake_ceiling(base_ceiling: int = -1) -> int:
	var liquid_balance := bankroll + grand_casino_chips if _is_grand_casino_environment(current_environment) else bankroll
	var available := liquid_balance if base_ceiling < 0 else mini(base_ceiling, liquid_balance)
	return maxi(0, available)


# Explains economy pressure in player-facing terms.
func economy_pressure_summary() -> String:
	match economic_state:
		"insolvent":
			return "Insolvent: no valid stake remains without help."
		"distressed":
			return "Distressed: large stakes can end the run."
		"volatile":
			return "Volatile: low cash makes big stakes dangerous."
		"growing":
			return "Growing: bankroll pressure is low."
		_:
			return "Stable: normal stake range."


# Describes run loss/recovery pressure without mutating the run.
func recovery_pressure_status(recovery_available: bool = false, bankroll_zero_deferred: bool = false) -> Dictionary:
	if run_status == RUN_STATUS_ENDED:
		if bool(narrative_flags.get("demo_victory", false)):
			return {
				"state": "victory",
				"title": "Demo victory",
				"summary": current_demo_victory_message(),
				"failed": false,
				"recovery_available": false,
				"terminal": true,
			}
		return {
			"state": "ended",
			"title": "Run ended",
			"summary": "This run is over.",
			"failed": false,
			"recovery_available": false,
			"terminal": true,
		}
	if run_status == RUN_STATUS_FAILED:
		var failure_summary := run_failure_message
		if failure_summary.strip_edges().is_empty():
			failure_summary = _failure_message_for_reason(run_failure_reason)
		return {
			"state": "failed",
			"title": _failure_title_for_reason(run_failure_reason),
			"summary": failure_summary,
			"failed": true,
			"recovery_available": false,
			"terminal": true,
			"reason": run_failure_reason,
		}
	if not has_liquid_run_funds() and bankroll_zero_deferred:
		return {
			"state": "recovery",
			"title": "All-in result pending",
			"summary": "Your last wager is still resolving.",
			"failed": false,
			"recovery_available": true,
			"terminal": false,
		}
	if not has_liquid_run_funds():
		return {
			"state": "failed",
			"title": "Run failed",
			"summary": BANKROLL_ZERO_FAILURE_MESSAGE,
			"failed": true,
			"recovery_available": false,
			"terminal": true,
			"reason": FAILURE_BANKROLL_ZERO,
		}
	if economic_state == "distressed":
		return {
			"state": "distressed",
			"title": "Debt pressure",
			"summary": "Debt and low cash are squeezing your choices.",
			"failed": false,
			"recovery_available": true,
			"terminal": false,
		}
	if economic_state == "volatile":
		return {
			"state": "volatile",
			"title": "Low bankroll",
			"summary": "Cash is thin, so stakes are tighter.",
			"failed": false,
			"recovery_available": false,
			"terminal": false,
		}
	return {
		"state": economic_state,
		"title": economy_pressure_summary(),
		"summary": economy_pressure_summary(),
		"failed": false,
		"recovery_available": false,
		"terminal": false,
	}


# Adds a story entry to the run log.
func log_story(event_data: Dictionary) -> void:
	var story_entry := event_data.duplicate(true)
	story_log.append(story_entry)
	_remember_story_seen_flags(story_entry)
	_compact_story_log()


func _compact_environment_history() -> void:
	var overflow := environment_history.size() - MAX_ENVIRONMENT_HISTORY_ENTRIES
	if overflow <= 0:
		return
	environment_history = environment_history.slice(overflow, environment_history.size())
	environment_history_archive_count = maxi(0, environment_history_archive_count) + overflow


func _compact_story_log() -> void:
	var overflow := story_log.size() - MAX_STORY_LOG_ENTRIES
	if overflow <= 0:
		return
	story_log = story_log.slice(overflow, story_log.size())
	story_log_archive_count = maxi(0, story_log_archive_count) + overflow


func _remember_story_seen_flags(story_entry: Dictionary) -> void:
	var entry_type := str(story_entry.get("type", "")).strip_edges()
	if entry_type.is_empty():
		return
	narrative_flags["%s%s" % [STORY_SEEN_TYPE_FLAG_PREFIX, entry_type]] = true
	var event_id := str(story_entry.get("event_id", "")).strip_edges()
	if not event_id.is_empty():
		narrative_flags["%s%s:%s" % [STORY_SEEN_EVENT_FLAG_PREFIX, entry_type, event_id]] = true
	var objective_id := str(story_entry.get("objective_id", "")).strip_edges()
	if not objective_id.is_empty():
		narrative_flags["%s%s:%s" % [STORY_SEEN_OBJECTIVE_FLAG_PREFIX, entry_type, objective_id]] = true


# Advances the current environment clock.
func advance_environment_turns(amount: int = 1) -> void:
	if current_environment.is_empty() or is_terminal():
		return
	var safe_amount := maxi(0, amount)
	advance_action_clock(safe_amount)
	simulation_msec = maxi(0, simulation_msec + safe_amount * SIMULATION_ACTION_MSEC)
	event_cadence_advance_actions(safe_amount)
	var alcohol_decay := safe_amount * DRUNK_TURN_DECAY
	if alcohol_decay > 0:
		change_drunk(-alcohol_decay)
	var previous_turns := int(current_environment.get("turns", 0))
	var next_turns := previous_turns + safe_amount
	current_environment["turns"] = next_turns
	_advance_travel_lock(safe_amount)
	_advance_narrative_action_timers(safe_amount)
	_advance_grand_casino_living_floor(safe_amount)
	drunk_distortion_suppression_turns = maxi(0, drunk_distortion_suppression_turns - safe_amount)
	var decay_interval := maxi(1, LOCAL_RISK_TURN_DECAY_INTERVAL + int(challenge_modifiers().get("local_heat_turn_decay_interval_delta", 0)))
	var previous_decay_step := int(floor(float(previous_turns) / float(decay_interval)))
	var next_decay_step := int(floor(float(next_turns) / float(decay_interval)))
	_decrease_current_suspicion(next_decay_step - previous_decay_step)
	_advance_heat_cooldown(safe_amount)
	_advance_debt_clocks(safe_amount)


func start_heat_cooldown(actions: int, per_action: int = 1) -> void:
	var safe_actions := maxi(0, actions)
	var safe_per_action := maxi(0, per_action)
	if safe_actions <= 0 or safe_per_action <= 0:
		return
	narrative_flags[HEAT_COOLDOWN_ACTIONS_FLAG] = maxi(active_heat_cooldown_actions(), safe_actions)
	narrative_flags[HEAT_COOLDOWN_PER_ACTION_FLAG] = maxi(active_heat_cooldown_per_action(), safe_per_action)


func active_heat_cooldown_actions() -> int:
	return maxi(0, int(narrative_flags.get(HEAT_COOLDOWN_ACTIONS_FLAG, 0)))


func active_heat_cooldown_per_action() -> int:
	return maxi(0, int(narrative_flags.get(HEAT_COOLDOWN_PER_ACTION_FLAG, 0)))


func _advance_heat_cooldown(amount: int) -> void:
	var remaining_actions := active_heat_cooldown_actions()
	var per_action := active_heat_cooldown_per_action()
	if remaining_actions <= 0 or per_action <= 0:
		narrative_flags.erase(HEAT_COOLDOWN_ACTIONS_FLAG)
		narrative_flags.erase(HEAT_COOLDOWN_PER_ACTION_FLAG)
		return
	var consumed_actions := mini(remaining_actions, maxi(0, amount))
	if consumed_actions <= 0:
		return
	_decrease_current_suspicion(consumed_actions * per_action)
	remaining_actions -= consumed_actions
	if remaining_actions > 0:
		narrative_flags[HEAT_COOLDOWN_ACTIONS_FLAG] = remaining_actions
	else:
		narrative_flags.erase(HEAT_COOLDOWN_ACTIONS_FLAG)
		narrative_flags.erase(HEAT_COOLDOWN_PER_ACTION_FLAG)


func _advance_travel_lock(amount: int) -> void:
	if amount <= 0 or current_environment.is_empty():
		return
	var remaining := maxi(0, int(current_environment.get("travel_lock_remaining", 0)))
	if remaining <= 0:
		return
	current_environment["travel_lock_remaining"] = maxi(0, remaining - amount)


func _advance_narrative_action_timers(amount: int) -> void:
	if amount <= 0:
		return
	for key in ["shift_change_rookie_actions", "lights_out_unwatched_actions"]:
		if narrative_flags.has(key):
			narrative_flags[key] = maxi(0, int(narrative_flags.get(key, 0)) - amount)


func _advance_debt_clocks(amount: int) -> void:
	if amount <= 0 or debt.is_empty():
		return
	for index in range(debt.size() - 1, -1, -1):
		if index >= debt.size() or typeof(debt[index]) != TYPE_DICTIONARY:
			continue
		var debt_data := (debt[index] as Dictionary).duplicate(true)
		var status := str(debt_data.get("status", "active"))
		if status == "active":
			var remaining := int(debt_data.get("turns_remaining", debt_data.get("deadline_turns", 0)))
			if remaining <= 0:
				_apply_debt_default(index, false)
				continue
			remaining = maxi(0, remaining - amount)
			debt_data["turns_remaining"] = remaining
			debt[index] = debt_data
			if remaining <= 0:
				_apply_debt_default(index, false)
		elif status == "overdue" or status == "favor_due":
			_tick_recurring_debt_pressure(index, debt_data, amount)


func _tick_recurring_debt_pressure(index: int, debt_data: Dictionary, amount: int) -> void:
	var next_pressure := int(debt_data.get("next_pressure_turns", debt_data.get("nag_interval_turns", 3)))
	next_pressure -= amount
	if next_pressure > 0:
		debt_data["next_pressure_turns"] = next_pressure
		debt[index] = debt_data
		return
	var consequence := str(debt_data.get("default_consequence", ""))
	var interval := maxi(1, int(debt_data.get("nag_interval_turns", 3)))
	debt_data["next_pressure_turns"] = interval
	debt[index] = debt_data
	match consequence:
		"family_nag":
			narrative_flags["brother_in_law_recurring_nag"] = int(narrative_flags.get("brother_in_law_recurring_nag", 0)) + 1
			log_story({
				"type": "debt_default_pressure",
				"debt_id": str(debt_data.get("id", "")),
				"lender_id": str(debt_data.get("lender_id", "")),
				"message": "Your brother-in-law calls again. The family version of interest compounds out loud.",
			})
		"crew_favor_due":
			narrative_flags["crew_favor_pending"] = true
			log_story({
				"type": "debt_favor_due",
				"debt_id": str(debt_data.get("id", "")),
				"lender_id": str(debt_data.get("lender_id", "")),
				"message": "The Crew's favor is still waiting on their clock.",
			})
		_:
			log_story({
				"type": "debt_default_pressure",
				"debt_id": str(debt_data.get("id", "")),
				"lender_id": str(debt_data.get("lender_id", "")),
				"message": "%s keeps pressing the debt." % _debt_lender_label(debt_data),
			})


func _apply_debt_item_modifiers_to_new_debt(debt_data: Dictionary) -> void:
	if str(debt_data.get("status", "active")) != "active":
		return
	var grace_bonus := item_effect_total("debt_grace_turns")
	if grace_bonus <= 0:
		return
	var deadline := maxi(0, int(debt_data.get("deadline_turns", 0)))
	var remaining := maxi(0, int(debt_data.get("turns_remaining", deadline)))
	if deadline <= 0 and remaining <= 0:
		return
	debt_data["deadline_turns"] = maxi(0, deadline + grace_bonus)
	debt_data["turns_remaining"] = maxi(0, remaining + grace_bonus)


func _apply_debt_default(index: int, manual: bool = false) -> Dictionary:
	if index < 0 or index >= debt.size() or typeof(debt[index]) != TYPE_DICTIONARY:
		return {"ok": false, "message": "Debt is not active."}
	var debt_data := (debt[index] as Dictionary).duplicate(true)
	var consequence := str(debt_data.get("default_consequence", "favor_owed"))
	var message := ""
	match consequence:
		"collateral_forfeit":
			var item_name := str(debt_data.get("collateral_item_name", debt_data.get("collateral_item_id", "the collateral")))
			add_sals_forfeited_item(str(debt_data.get("collateral_item_id", "")))
			narrative_flags["sals_pawn_defaulted"] = true
			debt.remove_at(index)
			message = "Sal keeps %s. The loan is over." % item_name
			log_story(_debt_story_entry("debt_default", debt_data, message))
		"crew_favor_due":
			debt_data["status"] = "favor_due"
			debt_data["turns_remaining"] = 0
			debt_data["next_pressure_turns"] = maxi(1, int(debt_data.get("nag_interval_turns", 2)))
			narrative_flags["crew_favor_pending"] = true
			debt[index] = debt_data
			message = "The Crew calls in a favor. Their clock, their terms."
			log_story(_debt_story_entry("debt_favor_due", debt_data, message))
		"family_nag":
			debt_data["status"] = "overdue"
			debt_data["turns_remaining"] = 0
			debt_data["next_pressure_turns"] = maxi(1, int(debt_data.get("nag_interval_turns", 3)))
			narrative_flags["brother_in_law_late"] = true
			var scar_flag := str(debt_data.get("late_scar_flag", "brother_in_law_story_scar"))
			if not scar_flag.is_empty():
				narrative_flags[scar_flag] = true
			debt[index] = debt_data
			message = "Your brother-in-law starts calling it family history instead of a loan."
			log_story(_debt_story_entry("debt_default", debt_data, message))
		"forced_repayment":
			var balance := maxi(0, int(debt_data.get("balance", 0)))
			var forced_payment := mini(balance, maxi(0, int(floor(float(bankroll) / 3.0))))
			if forced_payment > 0:
				change_bankroll(-forced_payment, true)
				balance -= forced_payment
			var heat_delta := maxi(0, (6 if manual else 4) + item_effect_total("debt_default_heat_delta"))
			add_suspicion("debt_default:%s" % str(debt_data.get("lender_id", "")), heat_delta, "debt", true, {"environment_id": str(current_environment.get("id", ""))}, true)
			if balance <= 0:
				debt.remove_at(index)
				message = "%s takes a forced payment and clears the note." % _debt_lender_label(debt_data)
			else:
				debt_data["balance"] = balance
				debt_data["status"] = "overdue"
				debt_data["turns_remaining"] = 0
				debt_data["next_pressure_turns"] = 2
				debt[index] = debt_data
				message = "%s forces a payment and leaves the rest hanging." % _debt_lender_label(debt_data)
			log_story(_debt_story_entry("debt_default", debt_data, message, -forced_payment, heat_delta))
		_:
			debt_data["status"] = "overdue"
			debt_data["turns_remaining"] = 0
			narrative_flags["debt_favor_owed"] = true
			debt[index] = debt_data
			message = "%s turns the late note into a favor owed." % _debt_lender_label(debt_data)
			log_story(_debt_story_entry("debt_default", debt_data, message))
	_refresh_economy(true)
	return {
		"ok": true,
		"message": message,
		"debt_id": str(debt_data.get("id", "")),
		"consequence": consequence,
	}


func _settle_paid_debt(index: int, debt_data: Dictionary, payment: int) -> String:
	var lender_id := str(debt_data.get("lender_id", ""))
	var message := "Paid off %s." % _debt_lender_label(debt_data)
	var debt_kind := str(debt_data.get("debt_kind", "cash"))
	if debt_kind == "pawn":
		var collateral_item_id := str(debt_data.get("collateral_item_id", ""))
		var collateral_item_name := str(debt_data.get("collateral_item_name", collateral_item_id))
		if not collateral_item_id.is_empty():
			add_item(collateral_item_id)
		message = "Redeemed %s from Sal's pawn envelope." % collateral_item_name
	elif lender_id == "brother_in_law" and int(debt_data.get("turns_remaining", 0)) > 0:
		var goodwill_flag := str(debt_data.get("early_repay_flag", "brother_in_law_goodwill"))
		if not goodwill_flag.is_empty():
			narrative_flags[goodwill_flag] = true
		message = "Paid your brother-in-law early enough to become a story he tells nicely."
	_mark_lender_repaid(lender_id)
	var heat_reduction := mini(LENDER_REPAY_HEAT_REDUCTION, suspicion_level())
	if heat_reduction > 0:
		_decrease_current_suspicion(heat_reduction)
	debt.remove_at(index)
	log_story({
		"type": "debt_paid",
		"debt_id": str(debt_data.get("id", "")),
		"lender_id": lender_id,
		"bankroll_delta": -payment,
		"suspicion_delta": -heat_reduction,
		"collateral_item_id": str(debt_data.get("collateral_item_id", "")),
		"message": message,
	})
	return message


func _merge_stackable_debt(debt_entry: Dictionary) -> bool:
	if str(debt_entry.get("lender_id", "")) != CREW_LENDER_ID:
		return false
	if str(debt_entry.get("debt_kind", "")) != "favor":
		return false
	for index in range(debt.size()):
		if typeof(debt[index]) != TYPE_DICTIONARY:
			continue
		var existing := (debt[index] as Dictionary).duplicate(true)
		if str(existing.get("lender_id", "")) != CREW_LENDER_ID:
			continue
		if str(existing.get("debt_kind", "")) != "favor":
			continue
		var debt_status := str(existing.get("status", "active"))
		if debt_status != "active" and debt_status != "overdue" and debt_status != "favor_due":
			continue
		existing["balance"] = maxi(0, int(existing.get("balance", 0))) + maxi(0, int(debt_entry.get("balance", 0)))
		existing["status"] = "active"
		existing["deadline_turns"] = maxi(int(existing.get("deadline_turns", 0)), int(debt_entry.get("deadline_turns", 0)))
		existing["turns_remaining"] = maxi(int(existing.get("turns_remaining", 0)), int(debt_entry.get("turns_remaining", 0)))
		existing["loan_count"] = maxi(1, int(existing.get("loan_count", 1))) + maxi(1, int(debt_entry.get("loan_count", 1)))
		existing["source_location_ids"] = _unique_lender_source_locations(existing, debt_entry)
		debt[index] = existing
		return true
	return false


func _unique_lender_source_locations(first: Dictionary, second: Dictionary) -> Array:
	var result: Array = []
	var lookup := {}
	for source in [first, second]:
		var source_dict := source as Dictionary
		for location_value in _copy_array(source_dict.get("source_location_ids", [])):
			var location_id := str(location_value)
			if location_id.is_empty() or lookup.has(location_id):
				continue
			lookup[location_id] = true
			result.append(location_id)
		var single_location_id := str(source_dict.get("source_location_id", ""))
		if not single_location_id.is_empty() and not lookup.has(single_location_id):
			lookup[single_location_id] = true
			result.append(single_location_id)
	return result


func _mark_lender_repaid(lender_id: String) -> void:
	if lender_id.is_empty():
		return
	var count_key := _lender_paid_count_key(lender_id)
	narrative_flags[count_key] = maxi(0, int(narrative_flags.get(count_key, 0))) + 1
	var location_id := _lender_location_key()
	if not location_id.is_empty():
		narrative_flags[_lender_paid_environment_key(lender_id)] = location_id


func _lender_paid_count(lender_id: String) -> int:
	if lender_id.is_empty():
		return 0
	return maxi(0, int(narrative_flags.get(_lender_paid_count_key(lender_id), 0)))


func _lender_paid_count_key(lender_id: String) -> String:
	return "lender_%s_paid_count" % lender_id


func _lender_paid_environment_key(lender_id: String) -> String:
	return "lender_%s_paid_environment_id" % lender_id


func _lender_location_key() -> String:
	var environment_id := str(current_environment.get("id", "")).strip_edges()
	if not environment_id.is_empty():
		return environment_id
	environment_id = str(current_environment.get("world_node_id", "")).strip_edges()
	if not environment_id.is_empty():
		return environment_id
	return str(current_environment.get("archetype_id", "")).strip_edges()


func _debt_index(debt_id: String) -> int:
	var target_id := debt_id.strip_edges()
	if target_id.is_empty():
		return -1
	for index in range(debt.size()):
		if typeof(debt[index]) != TYPE_DICTIONARY:
			continue
		var debt_data := debt[index] as Dictionary
		if str(debt_data.get("id", "")) == target_id:
			return index
	return -1


func _debt_lender_label(debt_data: Dictionary) -> String:
	return str(debt_data.get("lender_id", debt_data.get("id", "debt"))).replace("_", " ").capitalize()


func _debt_story_entry(entry_type: String, debt_data: Dictionary, message: String, bankroll_delta: int = 0, suspicion_delta: int = 0) -> Dictionary:
	return {
		"type": entry_type,
		"debt_id": str(debt_data.get("id", "")),
		"lender_id": str(debt_data.get("lender_id", "")),
		"debt_kind": str(debt_data.get("debt_kind", "")),
		"balance": int(debt_data.get("balance", 0)),
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"message": message,
	}


# Marks an environment event as resolved.
func resolve_event(event_id: String) -> void:
	if current_environment.is_empty() or event_id.is_empty():
		return
	var resolved: Array = current_environment.get("resolved_event_ids", [])
	if not resolved.has(event_id):
		resolved.append(event_id)
	current_environment["resolved_event_ids"] = resolved


func set_story_flag(flag_id: String, value: Variant = true) -> void:
	var clean_id := flag_id.strip_edges()
	if clean_id.is_empty():
		return
	story_flags[clean_id] = value
	narrative_flags[clean_id] = value


# Enqueues a world-acting event for modal resolution.
func enqueue_triggered_event(event_id: String, source: String = "", context: Dictionary = {}, entry_overrides: Dictionary = {}) -> bool:
	var normalized_id := event_id.strip_edges()
	if normalized_id.is_empty():
		return false
	if str(active_triggered_event.get("event_id", "")) == normalized_id:
		return false
	for entry_value in pending_triggered_events:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("event_id", "")) == normalized_id:
			return false
	var queued_context := context.duplicate(true)
	var entry := {
		"event_id": normalized_id,
		"source": source,
		"context": queued_context,
		"environment_id": str(current_environment.get("id", "")),
		"environment_turns": int(current_environment.get("turns", 0)),
	}
	for key in entry_overrides.keys():
		entry[str(key)] = entry_overrides[key]
	pending_triggered_events.append(_normalize_triggered_event_entry(entry))
	return true


func enqueue_dialogue(dialogue_id: String, event_id: String, speaker: Dictionary, current_node: String, source: String = "dialogue", context: Dictionary = {}) -> bool:
	var clean_dialogue_id := dialogue_id.strip_edges()
	var clean_event_id := event_id.strip_edges()
	if clean_dialogue_id.is_empty():
		return false
	if clean_event_id.is_empty():
		clean_event_id = "dialogue:%s" % clean_dialogue_id
	var node_id := current_node.strip_edges()
	var overrides := {
		"presentation": "talk",
		"dialogue_id": clean_dialogue_id,
		"current_node": node_id,
		"speaker": speaker.duplicate(true),
	}
	return enqueue_triggered_event(clean_event_id, source, context, overrides)


func update_pending_talk_dialogue_node(event_id: String, node_id: String) -> bool:
	var expected_id := event_id.strip_edges()
	var clean_node := node_id.strip_edges()
	if expected_id.is_empty() or clean_node.is_empty():
		return false
	for index in range(pending_triggered_events.size()):
		var entry := _normalize_triggered_event_entry(pending_triggered_events[index])
		if str(entry.get("presentation", "modal")) != "talk":
			continue
		if str(entry.get("event_id", "")) != expected_id:
			continue
		if str(entry.get("dialogue_id", "")).strip_edges().is_empty():
			return false
		entry["current_node"] = clean_node
		pending_triggered_events[index] = entry
		return true
	return false


# Returns the first queued modal triggered event without consuming it.
func next_pending_triggered_event() -> Dictionary:
	return next_pending_modal_triggered_event()


func next_pending_modal_triggered_event() -> Dictionary:
	if pending_triggered_events.is_empty():
		return {}
	for entry_value in pending_triggered_events:
		var entry := _normalize_triggered_event_entry(entry_value)
		if entry.is_empty() or str(entry.get("presentation", "modal")) == "talk":
			continue
		return entry
	return {}


func next_pending_talk_event() -> Dictionary:
	for entry_value in pending_triggered_events:
		var entry := _normalize_triggered_event_entry(entry_value)
		if str(entry.get("presentation", "modal")) == "talk":
			return entry
	return {}


func pending_talk_event_count() -> int:
	var count := 0
	for entry_value in pending_triggered_events:
		var entry := _normalize_triggered_event_entry(entry_value)
		if str(entry.get("presentation", "modal")) == "talk":
			count += 1
	return count


func pending_talk_event(event_id: String) -> Dictionary:
	var target_id := event_id.strip_edges()
	if target_id.is_empty():
		return {}
	for entry_value in pending_triggered_events:
		var entry := _normalize_triggered_event_entry(entry_value)
		if str(entry.get("presentation", "modal")) == "talk" and str(entry.get("event_id", "")) == target_id:
			return entry
	return {}


func complete_talk_event_resolution(event_id: String = "") -> void:
	var expected_id := event_id.strip_edges()
	for index in range(pending_triggered_events.size()):
		var entry := _normalize_triggered_event_entry(pending_triggered_events[index])
		if str(entry.get("presentation", "modal")) != "talk":
			continue
		if expected_id.is_empty() or str(entry.get("event_id", "")) == expected_id:
			pending_triggered_events.remove_at(index)
			return


func advance_focused_talk_event_actions(amount: int = 1) -> Dictionary:
	var step_count := maxi(0, amount)
	if step_count <= 0:
		return {}
	for index in range(pending_triggered_events.size()):
		var entry := _normalize_triggered_event_entry(pending_triggered_events[index])
		if str(entry.get("presentation", "modal")) != "talk":
			continue
		var timing: Dictionary = entry.get("timing", {})
		if not bool(timing.get("expires", false)):
			return {}
		var remaining := maxi(0, int(timing.get("remaining_actions", timing.get("duration_actions", 0))))
		if remaining <= 0:
			pending_triggered_events[index] = entry
			return entry.duplicate(true)
		remaining = maxi(0, remaining - step_count)
		timing["remaining_actions"] = remaining
		entry["timing"] = timing
		pending_triggered_events[index] = entry
		if remaining <= 0:
			return entry.duplicate(true)
		return {}
	return {}


# Moves a queued triggered event into active modal resolution.
func begin_triggered_event_resolution(entry: Dictionary) -> Dictionary:
	var normalized := _normalize_triggered_event_entry(entry)
	if normalized.is_empty():
		return {}
	if not pending_triggered_events.is_empty():
		for index in range(pending_triggered_events.size()):
			var pending := _normalize_triggered_event_entry(pending_triggered_events[index])
			if str(pending.get("event_id", "")) == str(normalized.get("event_id", "")):
				pending_triggered_events.remove_at(index)
				break
	normalized["active"] = true
	active_triggered_event = normalized
	return active_triggered_event.duplicate(true)


# Clears the active triggered event after its choice is resolved.
func complete_triggered_event_resolution(event_id: String = "") -> void:
	if active_triggered_event.is_empty():
		return
	var expected_id := event_id.strip_edges()
	if not expected_id.is_empty() and str(active_triggered_event.get("event_id", "")) != expected_id:
		return
	active_triggered_event = {}


func triggered_event_resolution_active() -> bool:
	return not active_triggered_event.is_empty()


func add_pending_bag_marker(marker: Dictionary) -> Dictionary:
	var normalized := _normalize_pending_bag_marker(marker)
	if normalized.is_empty():
		return {}
	var marker_id := str(normalized.get("marker_id", "")).strip_edges()
	if not marker_id.is_empty():
		for existing_value in pending_bags:
			var existing := _normalize_pending_bag_marker(existing_value)
			if str(existing.get("marker_id", "")) == marker_id:
				return existing
	pending_bags.append(normalized)
	return normalized.duplicate(true)


func pending_bag_markers() -> Array:
	pending_bags = _normalize_pending_bag_markers(pending_bags)
	return pending_bags.duplicate(true)


func clear_pending_bag_markers() -> void:
	pending_bags = []


# Adds travel targets to the current environment.
func add_next_archetypes(archetype_ids: Array) -> void:
	if current_environment.is_empty():
		return
	var clean_ids := _string_array(archetype_ids)
	var next_ids: Array = current_environment.get("next_archetypes", [])
	for id in clean_ids:
		if not id.is_empty() and not next_ids.has(id):
			next_ids.append(id)
	current_environment["next_archetypes"] = next_ids
	unlocked_travel = _unique_strings(unlocked_travel + clean_ids)
	if has_world_map():
		world_map = WorldMap.unlock_nodes(world_map, clean_ids, WorldMap.DISCOVERY_SOURCE_EVENT)
		world_map = WorldMap.refresh_shop_node_environments(world_map, clean_ids)
	current_environment["layout"] = EnvironmentInstance.ensure_generated_layout(current_environment)


# Replaces current environment travel targets.
func set_next_archetypes(archetype_ids: Array) -> void:
	if current_environment.is_empty():
		return
	var clean_ids := _string_array(archetype_ids)
	current_environment["next_archetypes"] = clean_ids
	unlocked_travel = _unique_strings(unlocked_travel + clean_ids)
	if has_world_map():
		world_map = WorldMap.unlock_nodes(world_map, clean_ids, WorldMap.DISCOVERY_SOURCE_EVENT)
		world_map = WorldMap.refresh_shop_node_environments(world_map, clean_ids)
	current_environment["layout"] = EnvironmentInstance.ensure_generated_layout(current_environment)


# Returns whether the current run is over.
func is_terminal() -> bool:
	return run_status == RUN_STATUS_FAILED or run_status == RUN_STATUS_ENDED


# Records player score input from money spent on travel and item purchases.
func record_score_spending(amount: int, _source_type: String = "") -> void:
	var spend := maxi(0, amount)
	if spend <= 0:
		return
	run_spending_score = maxi(0, run_spending_score + spend)


# Extracts scoreable spending from a shared result shape after it is accepted.
func record_score_spending_from_result(result: Dictionary, deltas: Dictionary) -> void:
	var result_type := str(result.get("type", ""))
	var action_id := str(result.get("action_id", ""))
	var action_kind := str(result.get("action_kind", ""))
	if result_type == "travel" or action_kind == "travel":
		var travel_spend := maxi(0, -int(deltas.get("bankroll_delta", result.get("bankroll_delta", 0))))
		record_score_spending(travel_spend, "travel")
		return
	if action_id == "buy_item" or result_type == "item_purchase" or _result_story_has_type(deltas, "item_purchase"):
		var item_spend := maxi(0, int(result.get("price", 0)))
		if item_spend <= 0:
			item_spend = _first_story_price(deltas, "item_purchase")
		if item_spend <= 0:
			item_spend = maxi(0, -int(deltas.get("bankroll_delta", result.get("bankroll_delta", 0))))
		record_score_spending(item_spend, "items")


func terminal_score_multiplier() -> int:
	return TERMINAL_SCORE_VICTORY_MULTIPLIER if run_status == RUN_STATUS_ENDED else 1


func terminal_score() -> int:
	return (run_spending_score + maxi(0, int(narrative_flags.get("grand_casino_uncashed_chip_score_value", 0)))) * terminal_score_multiplier()


func terminal_score_summary() -> Dictionary:
	var multiplier := terminal_score_multiplier()
	var uncashed_chip_value := maxi(0, int(narrative_flags.get("grand_casino_uncashed_chip_score_value", 0)))
	var base_score := run_spending_score + uncashed_chip_value
	return {
		"base_spending": base_score,
		"run_spending": run_spending_score,
		"uncashed_chip_score_value": uncashed_chip_value,
		"uncashed_chip_amount": maxi(0, int(narrative_flags.get("grand_casino_uncashed_chip_amount", 0))),
		"multiplier": multiplier,
		"score": base_score * multiplier,
	}


func seed_is_hidden() -> bool:
	if bool(challenge_config.get("hidden_seed", false)):
		return true
	var modifiers := _copy_dict(challenge_config.get("modifiers", {}))
	return bool(modifiers.get("hidden_seed", false))


func player_facing_seed_text() -> String:
	return "Hidden daily challenge" if seed_is_hidden() else seed_text


func _result_story_has_type(deltas: Dictionary, story_type: String) -> bool:
	for story_value in _copy_array(deltas.get("story_log", [])):
		if typeof(story_value) == TYPE_DICTIONARY and str((story_value as Dictionary).get("type", "")) == story_type:
			return true
	return false


func _first_story_price(deltas: Dictionary, story_type: String) -> int:
	for story_value in _copy_array(deltas.get("story_log", [])):
		if typeof(story_value) != TYPE_DICTIONARY:
			continue
		var story_entry := story_value as Dictionary
		if str(story_entry.get("type", "")) == story_type:
			return maxi(0, int(story_entry.get("price", 0)))
	return 0


# Marks the run as failed in the RunState source of truth.
func fail_run(reason: String, message: String = "") -> void:
	if run_status == RUN_STATUS_ENDED and bool(narrative_flags.get("demo_victory", false)):
		return
	run_status = RUN_STATUS_FAILED
	run_failure_reason = reason if not reason.strip_edges().is_empty() else FAILURE_BANKROLL_ZERO
	run_failure_message = message if not message.strip_edges().is_empty() else _failure_message_for_reason(run_failure_reason)
	if bankroll <= 0:
		bankroll = 0
		economic_state = "insolvent"


# Re-checks terminal failures that depend only on local RunState values.
func evaluate_immediate_terminal_state(defer_bankroll_zero: bool = false) -> Dictionary:
	_evaluate_immediate_terminal_state(defer_bankroll_zero)
	return recovery_pressure_status(false, defer_bankroll_zero)


# Returns the venue identity used for local heat memory.
func current_suspicion_location_id() -> String:
	return _suspicion_location_id_for_environment(current_environment)


func _suspicion_location_id_from_context(context: Dictionary) -> String:
	var archetype_id := str(context.get("environment_archetype_id", "")).strip_edges()
	if not archetype_id.is_empty():
		return GRAND_CASINO_ARCHETYPE_ID if GRAND_CASINO_ARCHETYPE_IDS.has(archetype_id) else archetype_id
	var environment_id := str(context.get("environment_id", "")).strip_edges()
	if environment_id.is_empty():
		return current_suspicion_location_id()
	var current_environment_id := str(current_environment.get("id", "")).strip_edges()
	if not current_environment_id.is_empty() and environment_id == current_environment_id:
		return current_suspicion_location_id()
	var current_location_id := current_suspicion_location_id()
	if not current_location_id.is_empty() and environment_id.begins_with("%s_" % current_location_id):
		return current_location_id
	var generated_location_id := _location_id_from_generated_environment_id(environment_id)
	if not generated_location_id.is_empty():
		return generated_location_id
	return environment_id


func _suspicion_location_id_for_environment(environment: Dictionary) -> String:
	if environment.is_empty():
		return ""
	if _is_grand_casino_environment(environment):
		return GRAND_CASINO_ARCHETYPE_ID
	var archetype_id := str(environment.get("archetype_id", "")).strip_edges()
	if not archetype_id.is_empty():
		return archetype_id
	var environment_id := str(environment.get("id", "")).strip_edges()
	var generated_location_id := _location_id_from_generated_environment_id(environment_id)
	if not generated_location_id.is_empty():
		return generated_location_id
	return environment_id


func _location_id_from_generated_environment_id(environment_id: String) -> String:
	var separator := environment_id.rfind("_")
	if separator <= 0 or separator >= environment_id.length() - 1:
		return ""
	var suffix := environment_id.substr(separator + 1)
	if not suffix.is_valid_int():
		return ""
	return environment_id.substr(0, separator)


func _local_suspicion_levels() -> Dictionary:
	return _copy_dict(suspicion.get("local_levels", {}))


func _store_current_local_suspicion() -> void:
	var location_id := current_suspicion_location_id()
	if location_id.is_empty():
		return
	var levels := _local_suspicion_levels()
	levels[location_id] = suspicion_level()
	suspicion["local_levels"] = levels


func _activate_current_local_suspicion(preserve_active_level: bool) -> void:
	var location_id := current_suspicion_location_id()
	if location_id.is_empty():
		suspicion["level"] = clampi(int(suspicion.get("level", 0)), 0, 100)
		return
	var levels := _local_suspicion_levels()
	if levels.has(location_id):
		suspicion["level"] = clampi(int(levels.get(location_id, 0)), 0, 100)
		return
	if preserve_active_level:
		var current_level := clampi(int(suspicion.get("level", 0)), 0, 100)
		levels[location_id] = current_level
		suspicion["local_levels"] = levels
		suspicion["level"] = current_level
		return
	suspicion["level"] = 0


func _decayed_suspicion_level(level: int, decay_percent: int) -> int:
	level = clampi(level, 0, 100)
	decay_percent = clampi(decay_percent, 0, 100)
	if level <= 0 or decay_percent <= 0:
		return level
	var cooled := int(round(float(level) * (1.0 - float(decay_percent) / 100.0)))
	if cooled >= level:
		cooled = level - 1
	return clampi(cooled, 0, 100)


func _decrease_current_suspicion(amount: int) -> void:
	amount = maxi(0, amount)
	if amount <= 0:
		return
	var location_id := current_suspicion_location_id()
	var previous_level := suspicion_level()
	var next_level := clampi(suspicion_level() - amount, 0, 100)
	suspicion["level"] = next_level
	if next_level != previous_level:
		_record_heat_history(false)
	if location_id.is_empty():
		return
	var levels := _local_suspicion_levels()
	levels[location_id] = next_level
	suspicion["local_levels"] = levels


func _record_heat_history(environment_transition: bool) -> void:
	var environment_id := str(current_environment.get("id", current_environment.get("world_node_id", current_environment.get("archetype_id", "")))).strip_edges()
	var entry := {
		"action_index": maxi(0, int(event_cadence.get("action_index", 0))),
		"game_clock_minutes": maxi(0, game_clock_minutes),
		"heat_value": suspicion_level(),
		"environment_id": environment_id,
		"world_node_id": str(current_environment.get("world_node_id", current_environment.get("archetype_id", ""))).strip_edges(),
		"environment_name": str(current_environment.get("display_name", environment_id.replace("_", " ").capitalize())),
		"transition": environment_transition,
	}
	if not heat_history.is_empty():
		var last: Dictionary = heat_history[-1] if typeof(heat_history[-1]) == TYPE_DICTIONARY else {}
		if not environment_transition and int(last.get("action_index", -1)) == int(entry["action_index"]) and int(last.get("heat_value", -1)) == int(entry["heat_value"]) and str(last.get("environment_id", "")) == environment_id:
			return
	heat_history.append(entry)
	_compact_heat_history()


func _compact_heat_history() -> void:
	if heat_history.size() <= MAX_HEAT_HISTORY_ENTRIES:
		return
	heat_history = downsample_heat_history(heat_history, HEAT_HISTORY_COMPACT_TARGET)


static func normalize_heat_history(entries: Array) -> Array:
	var result: Array = []
	for value in entries:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		result.append({
			"action_index": maxi(0, int(entry.get("action_index", 0))),
			"game_clock_minutes": int(entry.get("game_clock_minutes", -1)),
			"heat_value": clampi(int(entry.get("heat_value", entry.get("heat", 0))), 0, 100),
			"environment_id": str(entry.get("environment_id", "")),
			"world_node_id": str(entry.get("world_node_id", "")),
			"environment_name": str(entry.get("environment_name", entry.get("environment_id", ""))).strip_edges(),
			"transition": bool(entry.get("transition", false)),
		})
	return result


static func downsample_heat_history(entries: Array, target_size: int = HEAT_HISTORY_COMPACT_TARGET) -> Array:
	var normalized := normalize_heat_history(entries)
	var target := maxi(2, target_size)
	if normalized.size() <= target:
		return normalized
	var keep := {}
	keep[0] = true
	keep[normalized.size() - 1] = true
	for index in range(normalized.size()):
		var entry: Dictionary = normalized[index]
		if bool(entry.get("transition", false)):
			keep[index] = true
		if index > 0 and index + 1 < normalized.size():
			var before := int((normalized[index - 1] as Dictionary).get("heat_value", 0))
			var current := int(entry.get("heat_value", 0))
			var after := int((normalized[index + 1] as Dictionary).get("heat_value", 0))
			if (current > before and current >= after) or (current < before and current <= after):
				keep[index] = true
	var required: Array = keep.keys()
	required.sort()
	if required.size() > target:
		var reduced: Array = []
		for slot in range(target):
			var source_index := int(round(float(slot) * float(required.size() - 1) / float(target - 1)))
			reduced.append(int(required[source_index]))
		required = reduced
	else:
		var candidates: Array = []
		for index in range(normalized.size()):
			if not keep.has(index):
				candidates.append(index)
		var remaining := target - required.size()
		for slot in range(mini(remaining, candidates.size())):
			var source_index := int(floor(float(slot) * float(candidates.size()) / float(maxi(1, remaining))))
			required.append(int(candidates[source_index]))
		required.sort()
	var result: Array = []
	var seen := {}
	for index_value in required:
		var index := int(index_value)
		if index < 0 or index >= normalized.size() or seen.has(index):
			continue
		seen[index] = true
		result.append(normalized[index])
	return result


func _story_log_has_demo_victory(objective_id: String) -> bool:
	var normalized_objective := objective_id.strip_edges()
	if normalized_objective.is_empty() and bool(narrative_flags.get("%sdemo_victory" % STORY_SEEN_TYPE_FLAG_PREFIX, false)):
		return true
	if not normalized_objective.is_empty() and bool(narrative_flags.get("%sdemo_victory:%s" % [STORY_SEEN_OBJECTIVE_FLAG_PREFIX, normalized_objective], false)):
		return true
	for entry in story_log:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var story_entry := entry as Dictionary
		if str(story_entry.get("type", "")) != "demo_victory":
			continue
		if normalized_objective.is_empty() or str(story_entry.get("objective_id", "")) == normalized_objective:
			return true
	return false


func _story_log_has_type(entry_type: String, event_id: String = "") -> bool:
	var normalized_type := entry_type.strip_edges()
	var normalized_event := event_id.strip_edges()
	if normalized_type.is_empty():
		return false
	if normalized_event.is_empty() and bool(narrative_flags.get("%s%s" % [STORY_SEEN_TYPE_FLAG_PREFIX, normalized_type], false)):
		return true
	if not normalized_event.is_empty() and bool(narrative_flags.get("%s%s:%s" % [STORY_SEEN_EVENT_FLAG_PREFIX, normalized_type, normalized_event], false)):
		return true
	for entry in story_log:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var story_entry := entry as Dictionary
		if str(story_entry.get("type", "")) != normalized_type:
			continue
		if normalized_event.is_empty() or str(story_entry.get("event_id", "")) == normalized_event:
			return true
	return false


func _evaluate_immediate_terminal_state(defer_bankroll_zero: bool = false) -> void:
	if run_status == RUN_STATUS_ENDED:
		return
	if run_status == RUN_STATUS_FAILED:
		return
	var heat_rerouted := handle_grand_casino_heat_reroute("immediate_terminal")
	if suspicion_level() >= 100:
		if heat_rerouted:
			return
		fail_run(FAILURE_POLICE_CAPTURE, POLICE_CAPTURE_FAILURE_MESSAGE)
		return
	if not has_liquid_run_funds() and not defer_bankroll_zero and not closing_time_forced_travel_required():
		fail_run(FAILURE_BANKROLL_ZERO, BANKROLL_ZERO_FAILURE_MESSAGE)


func _failure_title_for_reason(reason: String) -> String:
	match reason:
		FAILURE_CASINO_TAKEN_OUT_BACK:
			return "Taken out back"
		FAILURE_ABANDONED:
			return "Run abandoned"
		FAILURE_POLICE_CAPTURE:
			return "Captured by police"
		FAILURE_STRANDED:
			return "Run stranded"
		FAILURE_BANKROLL_ZERO:
			return "Run failed"
		_:
			return "Run failed"


func _failure_message_for_reason(reason: String) -> String:
	match reason:
		FAILURE_CASINO_TAKEN_OUT_BACK:
			return CASINO_TAKEN_OUT_BACK_FAILURE_MESSAGE
		FAILURE_ABANDONED:
			return ABANDONED_FAILURE_MESSAGE
		FAILURE_POLICE_CAPTURE:
			return POLICE_CAPTURE_FAILURE_MESSAGE
		FAILURE_STRANDED:
			return STRANDED_FAILURE_MESSAGE
		FAILURE_BANKROLL_ZERO:
			return BANKROLL_ZERO_FAILURE_MESSAGE
		_:
			return "The run is over."


# Converts the run to saveable data.
func to_dict() -> Dictionary:
	return {
		"seed_text": seed_text,
		"seed_value": seed_value,
		"rng_seed": rng_seed,
		"rng_state": rng_state,
		"challenge_config": challenge_config.duplicate(true),
		"bankroll": bankroll,
		"grand_casino_chips": grand_casino_chips,
		"economic_state": economic_state,
		"inventory": inventory.duplicate(true),
		"portable_ticket_piles": portable_ticket_piles.duplicate(true),
		"active_item_id": active_item_id,
		"debt": debt.duplicate(true),
		"sals_forfeited_item_ids": sals_forfeited_item_ids.duplicate(true),
		"suspicion": suspicion.duplicate(true),
		"baseline_luck": baseline_luck,
		"drunk_level": drunk_level,
		"alcoholic_level": alcoholic_level,
		"pending_drunk_absorption": pending_drunk_absorption.duplicate(true),
		"drunk_distortion_suppression_turns": drunk_distortion_suppression_turns,
		"current_environment": current_environment.duplicate(true),
		"world_map": WorldMap.normalize(world_map),
		"grand_casino_room_states": _grand_casino_room_states_for_save(),
		"grand_casino_staffing": grand_casino_staffing.duplicate(true),
		"rourke_current_room": rourke_current_room,
		"rourke_current_spot": rourke_current_spot,
		"rourke_facing": rourke_facing,
		"rourke_actions_until_move": rourke_actions_until_move,
		"rourke_off_floor_actions": rourke_off_floor_actions,
		"rourke_floor_action_index": rourke_floor_action_index,
		"grand_casino_room_heat_accumulators": grand_casino_room_heat_accumulators.duplicate(true),
		"rival_cheaters": rival_cheaters.duplicate(true),
		"rival_cheater_day": rival_cheater_day,
		"rourke_escort_state": rourke_escort_state.duplicate(true),
		"pending_triggered_events": pending_triggered_events.duplicate(true),
		"pending_bags": pending_bags.duplicate(true),
		"active_triggered_event": active_triggered_event.duplicate(true),
		"event_cadence": _normalize_event_cadence(event_cadence),
		"music_arrangement_state": _normalize_music_arrangement_state(music_arrangement_state),
		"music_tempo_state": _normalize_music_tempo_state(music_tempo_state),
		"music_choreography_state": _normalize_music_choreography_state(music_choreography_state),
		"environment_history": environment_history.duplicate(true),
		"environment_history_archive_count": environment_history_archive_count,
		"unlocked_travel": unlocked_travel.duplicate(true),
		"narrative_flags": narrative_flags.duplicate(true),
		"story_flags": story_flags.duplicate(true),
		"story_log": _normalize_story_log(story_log),
		"story_log_archive_count": story_log_archive_count,
		"heat_history": normalize_heat_history(heat_history),
		"simulation_msec": simulation_msec,
		"game_clock_minutes": game_clock_minutes,
		"closing_time_state": _normalize_closing_time_state(closing_time_state),
		"act": act_marker(),
		"act_index": act_marker(),
		"home_state": _normalize_home_state(home_state),
		"run_status": run_status,
		"run_failure_reason": run_failure_reason,
		"run_failure_message": run_failure_message,
		"run_spending_score": run_spending_score,
	}


# Restores the run from saved data.
func from_dict(data: Dictionary) -> void:
	seed_text = str(data.get("seed_text", "FOUNDATION-SEED"))
	seed_value = int(data.get("seed_value", text_to_seed(seed_text)))
	rng_seed = int(data.get("rng_seed", seed_value))
	rng_state = int(data.get("rng_state", rng_seed))
	challenge_config = normalize_challenge(seed_text, _copy_dict(data.get("challenge_config", standard_challenge(seed_text))))
	bankroll = int(data.get("bankroll", DEFAULT_BANKROLL))
	grand_casino_chips = maxi(0, int(data.get("grand_casino_chips", 0)))
	economic_state = str(data.get("economic_state", "stable"))
	inventory = _copy_array(data.get("inventory", []))
	portable_ticket_piles = _normalize_portable_ticket_piles(_copy_dict(data.get("portable_ticket_piles", {})))
	active_item_id = str(data.get("active_item_id", ""))
	if not inventory.has(active_item_id):
		active_item_id = ""
	debt = _normalize_debt_entries(_copy_array(data.get("debt", [])))
	sals_forfeited_item_ids = _string_array(_copy_array(data.get("sals_forfeited_item_ids", [])))
	suspicion = _normalize_suspicion(_copy_dict(data.get("suspicion", {"level": 0, "cues": []})))
	baseline_luck = clampi(int(data.get("baseline_luck", 0)), BASELINE_LUCK_MIN, BASELINE_LUCK_MAX)
	drunk_level = clampi(int(data.get("drunk_level", 0)), 0, ALCOHOL_MAX)
	alcoholic_level = clampi(int(data.get("alcoholic_level", 0)), 0, ALCOHOL_MAX)
	pending_drunk_absorption = _normalize_pending_drunk_absorption(_copy_array(data.get("pending_drunk_absorption", [])))
	drunk_distortion_suppression_turns = maxi(0, int(data.get("drunk_distortion_suppression_turns", 0)))
	current_environment = _normalize_environment(_copy_dict(data.get("current_environment", {})))
	# Import current-room machine ownership from pre-portable saves, then make
	# the portable record authoritative for the restored surface.
	capture_portable_ticket_piles_from_environment(current_environment)
	restore_portable_ticket_piles_to_environment(current_environment)
	_sync_portable_ticket_inventory_markers()
	_apply_sals_forfeited_shelf_to_current_environment()
	world_map = WorldMap.normalize(_copy_dict(data.get("world_map", {})))
	grand_casino_room_states = _normalize_grand_casino_room_states(_copy_dict(data.get("grand_casino_room_states", {})))
	grand_casino_staffing = _normalize_grand_casino_staffing(_copy_dict(data.get("grand_casino_staffing", {})))
	rourke_current_room = _normalize_grand_casino_room_id(str(data.get("rourke_current_room", "")))
	rourke_current_spot = str(data.get("rourke_current_spot", "")).strip_edges()
	rourke_facing = "left" if str(data.get("rourke_facing", "right")) == "left" else "right"
	rourke_actions_until_move = clampi(int(data.get("rourke_actions_until_move", ROURKE_MOVE_EVALUATION_ACTIONS)), 0, ROURKE_MOVE_EVALUATION_ACTIONS)
	rourke_off_floor_actions = clampi(int(data.get("rourke_off_floor_actions", 0)), 0, ROURKE_OFF_FLOOR_ACTIONS)
	rourke_floor_action_index = maxi(0, int(data.get("rourke_floor_action_index", 0)))
	grand_casino_room_heat_accumulators = _normalize_grand_casino_room_heat_accumulators(_copy_dict(data.get("grand_casino_room_heat_accumulators", {})))
	rival_cheaters = _normalize_rival_cheaters(_copy_array(data.get("rival_cheaters", [])))
	rival_cheater_day = maxi(0, int(data.get("rival_cheater_day", 0)))
	rourke_escort_state = _normalize_rourke_escort_state(_copy_dict(data.get("rourke_escort_state", {})))
	if _is_grand_casino_environment(current_environment):
		store_grand_casino_room_environment(current_environment)
	pending_triggered_events = _normalize_triggered_event_queue(_copy_array(data.get("pending_triggered_events", [])))
	var saved_pending_bags: Variant = data.get("pending_bags", data.get("pending_bag", []))
	if typeof(saved_pending_bags) == TYPE_DICTIONARY:
		pending_bags = _normalize_pending_bag_markers([saved_pending_bags])
	else:
		pending_bags = _normalize_pending_bag_markers(_copy_array(saved_pending_bags))
	active_triggered_event = _normalize_triggered_event_entry(data.get("active_triggered_event", {}))
	event_cadence = _normalize_event_cadence(_copy_dict(data.get("event_cadence", {})))
	music_arrangement_state = _normalize_music_arrangement_state(_copy_dict(data.get("music_arrangement_state", {})))
	music_tempo_state = _normalize_music_tempo_state(_copy_dict(data.get("music_tempo_state", {})))
	music_choreography_state = _normalize_music_choreography_state(_copy_dict(data.get("music_choreography_state", {})))
	environment_history_archive_count = maxi(0, int(data.get("environment_history_archive_count", 0)))
	environment_history = _normalize_environment_history(_copy_array(data.get("environment_history", [])))
	_compact_environment_history()
	unlocked_travel = _copy_array(data.get("unlocked_travel", current_environment.get("travel_hooks", [])))
	narrative_flags = _copy_dict(data.get("narrative_flags", {}))
	story_flags = _copy_dict(data.get("story_flags", {}))
	for story_flag_key in story_flags.keys():
		narrative_flags[str(story_flag_key)] = story_flags[story_flag_key]
	story_log_archive_count = maxi(0, int(data.get("story_log_archive_count", 0)))
	story_log = _normalize_story_log(_copy_array(data.get("story_log", [])))
	for story_entry_value in story_log:
		if typeof(story_entry_value) == TYPE_DICTIONARY:
			_remember_story_seen_flags(story_entry_value as Dictionary)
	_compact_story_log()
	heat_history = normalize_heat_history(_copy_array(data.get("heat_history", [])))
	if heat_history.is_empty():
		_record_heat_history(not current_environment.is_empty())
	_compact_heat_history()
	simulation_msec = maxi(0, int(data.get("simulation_msec", int(_copy_dict(data.get("event_cadence", {})).get("action_index", 0)) * SIMULATION_ACTION_MSEC)))
	if bool(narrative_flags.get("grand_casino_showdown_active", false)) and str(narrative_flags.get("grand_casino_showdown_step", "")) == GRAND_CASINO_SHOWDOWN_STEP_LEGACY_CHECK and not _copy_dict(narrative_flags.get("grand_casino_duel_terms", {})).is_empty():
		_begin_grand_casino_duel(_copy_dict(narrative_flags.get("grand_casino_duel_terms", {})))
	game_clock_minutes = maxi(0, int(data.get("game_clock_minutes", GAME_CLOCK_START_MINUTE)))
	closing_time_state = _normalize_closing_time_state(_copy_dict(data.get("closing_time_state", {})))
	act_index = maxi(1, int(data.get("act", data.get("act_index", 1))))
	home_state = _normalize_home_state(_copy_dict(data.get("home_state", {})))
	var saved_run_status := str(data.get("run_status", RUN_STATUS_ACTIVE))
	run_status = saved_run_status
	run_failure_reason = str(data.get("run_failure_reason", FAILURE_NONE))
	run_failure_message = str(data.get("run_failure_message", ""))
	run_spending_score = maxi(0, int(data.get("run_spending_score", 0)))
	_refresh_economy()
	_activate_current_local_suspicion(true)
	_initialize_grand_casino_objective_runtime()
	_initialize_grand_casino_staffing()
	_initialize_grand_casino_living_floor()
	if saved_run_status != RUN_STATUS_ENDED and saved_run_status != RUN_STATUS_FAILED:
		_evaluate_immediate_terminal_state()
	if saved_run_status == RUN_STATUS_ENDED:
		run_status = saved_run_status
	elif saved_run_status == RUN_STATUS_FAILED:
		run_status = saved_run_status
		if run_failure_reason.strip_edges().is_empty():
			run_failure_reason = FAILURE_BANKROLL_ZERO if bankroll <= 0 else FAILURE_STRANDED
		if run_failure_message.strip_edges().is_empty():
			run_failure_message = _failure_message_for_reason(run_failure_reason)


# Converts text into a deterministic positive seed.
static func text_to_seed(text: String) -> int:
	var hash_value := 2166136261
	for index in range(text.length()):
		hash_value = hash_value ^ text.unicode_at(index)
		hash_value = (hash_value * 16777619) & 0x7fffffff
	return max(1, hash_value)


# Builds the default challenge config.
static func standard_challenge(p_seed_text: String = "FOUNDATION-SEED") -> Dictionary:
	var resolved_seed := p_seed_text if not p_seed_text.is_empty() else "FOUNDATION-SEED"
	return _challenge_config("standard", "standard", resolved_seed)


# Builds a daily challenge config.
static func daily_challenge(daily_id: String, p_seed_text: String = "", hidden_seed: bool = false) -> Dictionary:
	var resolved_daily_id := daily_id if not daily_id.is_empty() else "UNSET-DAILY"
	var resolved_seed := p_seed_text if not p_seed_text.is_empty() else "DAILY:%s" % resolved_daily_id
	var config := _challenge_config(
		"daily",
		"daily",
		resolved_seed,
		resolved_daily_id,
		{"leaderboard_scope": "daily"}
	)
	if hidden_seed:
		config["hidden_seed"] = true
	return config


# Builds a custom challenge config.
static func custom_challenge(challenge_id: String, p_seed_text: String, modifiers: Dictionary = {}) -> Dictionary:
	var resolved_id := challenge_id if not challenge_id.is_empty() else "custom"
	var resolved_seed := p_seed_text if not p_seed_text.is_empty() else resolved_id
	return _challenge_config("custom", resolved_id, resolved_seed, "", modifiers)


# Builds a normalized challenge dictionary without repeating the field shape.
static func _challenge_config(mode: String, challenge_id: String, p_seed_text: String, daily_id: String = "", modifiers: Dictionary = {}) -> Dictionary:
	return {
		"mode": mode,
		"id": challenge_id,
		"seed_text": p_seed_text,
		"daily_id": daily_id,
		"modifiers": modifiers.duplicate(true),
		"hidden_seed": false,
	}


# Fills missing challenge fields with safe defaults.
static func normalize_challenge(p_seed_text: String, config: Dictionary = {}) -> Dictionary:
	if config.is_empty():
		return standard_challenge(p_seed_text)

	var normalized: Dictionary = config.duplicate(true)
	normalized["mode"] = normalized.get("mode", "custom")
	normalized["id"] = normalized.get("id", normalized.get("mode", "custom"))
	normalized["seed_text"] = normalized.get("seed_text", p_seed_text if not p_seed_text.is_empty() else "FOUNDATION-SEED")
	normalized["daily_id"] = normalized.get("daily_id", "")
	normalized["modifiers"] = _copy_dict(normalized.get("modifiers", {}))
	normalized["hidden_seed"] = bool(normalized.get("hidden_seed", false))
	if normalized.has("tutorial"):
		normalized["tutorial"] = bool(normalized.get("tutorial", false))
	if normalized.has("exclude_profile_stats"):
		normalized["exclude_profile_stats"] = bool(normalized.get("exclude_profile_stats", false))
	return normalized


# Builds the text that determines the run seed.
static func challenge_key(config: Dictionary) -> String:
	return "%s|%s|%s|%s" % [
		config.get("mode", "standard"),
		config.get("id", "standard"),
		config.get("seed_text", "FOUNDATION-SEED"),
		_mods_text(config.get("modifiers", {})),
	]


# Serializes modifiers in stable key order.
static func _mods_text(modifiers: Dictionary) -> String:
	var keys: Array = modifiers.keys()
	keys.sort()
	var parts: Array = []
	for key in keys:
		parts.append("%s=%s" % [key, modifiers[key]])
	return ";".join(parts)


# Safely duplicates array content.
static func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _int_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		result.append(int(entry))
	return result


# Safely duplicates dictionary content.
static func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _item_effect_index() -> Dictionary:
	if _item_effects_loaded:
		return _item_effects_by_id
	_item_effects_loaded = true
	_item_effects_by_id = {}
	if not FileAccess.file_exists(ITEM_DEFINITIONS_PATH):
		return _item_effects_by_id
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITEM_DEFINITIONS_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		return _item_effects_by_id
	for item_value in parsed as Array:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		var item_id := str(item.get("id", "")).strip_edges()
		if item_id.is_empty():
			continue
		var effect := _copy_dict(item.get("effect", {}))
		if not effect.is_empty():
			_item_effects_by_id[item_id] = effect
	return _item_effects_by_id


func _item_definition_index() -> Dictionary:
	if _item_definitions_loaded:
		return _item_definitions_by_id
	_item_definitions_loaded = true
	_item_definitions_by_id = {}
	if not FileAccess.file_exists(ITEM_DEFINITIONS_PATH):
		return _item_definitions_by_id
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITEM_DEFINITIONS_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		return _item_definitions_by_id
	for item_value in parsed as Array:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		var item_id := str(item.get("id", "")).strip_edges()
		if item_id.is_empty():
			continue
		_item_definitions_by_id[item_id] = item.duplicate(true)
	return _item_definitions_by_id


func _item_definition(item_id: String) -> Dictionary:
	var definitions := _item_definition_index()
	var normalized_id := item_id.strip_edges()
	if normalized_id.is_empty() or not definitions.has(normalized_id):
		return {}
	var definition: Dictionary = definitions[normalized_id]
	return definition.duplicate(true)


func _apply_sals_forfeited_shelf_to_current_environment() -> void:
	if current_environment.is_empty() or sals_forfeited_item_ids.is_empty():
		return
	if bool(current_environment.get("meta_session", false)):
		return
	var archetype_id := str(current_environment.get("archetype_id", current_environment.get("id", ""))).strip_edges()
	var kind := str(current_environment.get("kind", "")).strip_edges()
	if archetype_id != PAWN_SHOP_ARCHETYPE_ID and kind != PAWN_SHOP_ARCHETYPE_ID:
		return
	var base_offers: Array = []
	for offer_value in _normalize_item_offers(_copy_array(current_environment.get("item_offers", []))):
		if typeof(offer_value) != TYPE_DICTIONARY:
			continue
		var offer := offer_value as Dictionary
		if bool(offer.get("forfeited_pawn_shelf", false)):
			continue
		base_offers.append(offer)
	var displayed := base_offers.duplicate(true)
	for item_value in sals_forfeited_item_ids:
		var item_id := str(item_value).strip_edges()
		if item_id.is_empty():
			continue
		var shelf_offer := _sals_forfeited_shelf_offer(item_id)
		if shelf_offer.is_empty():
			continue
		var existing_index := _offer_list_item_index(displayed, item_id)
		if existing_index >= 0:
			displayed[existing_index] = shelf_offer
		else:
			displayed.append(shelf_offer)
	current_environment["item_offers"] = displayed
	if current_environment.has("layout"):
		current_environment["layout"] = EnvironmentInstance.ensure_generated_layout(current_environment)


func _sals_forfeited_shelf_offer(item_id: String) -> Dictionary:
	var definition := _item_definition(item_id)
	if definition.is_empty():
		return {}
	var retail_price := maxi(1, int(definition.get("price_max", definition.get("price_min", 1))))
	return {
		"id": item_id,
		"display_name": str(definition.get("display_name", item_id)),
		"price": retail_price,
		"price_min": retail_price,
		"price_max": retail_price,
		"forfeited_pawn_shelf": true,
	}


static func _offer_list_item_index(offers: Array, item_id: String) -> int:
	for index in range(offers.size()):
		var offer_value: Variant = offers[index]
		if typeof(offer_value) == TYPE_DICTIONARY and str((offer_value as Dictionary).get("id", "")) == item_id:
			return index
	return -1


func _sync_portable_ticket_inventory_markers() -> void:
	for kind_value in PORTABLE_TICKET_KINDS:
		var kind := str(kind_value)
		var item_id := str(PORTABLE_TICKET_ITEM_IDS.get(kind, ""))
		var count := 0
		var origins_value: Variant = portable_ticket_piles.get(kind, {})
		if typeof(origins_value) == TYPE_DICTIONARY:
			for state_value in (origins_value as Dictionary).values():
				if typeof(state_value) == TYPE_DICTIONARY:
					count += _portable_ticket_state_count(kind, state_value as Dictionary)
		if count > 0:
			if not inventory.has(item_id):
				inventory.append(item_id)
		elif inventory.has(item_id):
			inventory.erase(item_id)
			if active_item_id == item_id:
				active_item_id = ""


static func _portable_ticket_player_state(kind: String, machine: Dictionary) -> Dictionary:
	var result := {}
	for field_value in _copy_array(PORTABLE_TICKET_PLAYER_FIELDS.get(kind, [])):
		var field := str(field_value)
		var value: Variant = machine.get(field, [] if field.ends_with("pile") or field.ends_with("stack") else {})
		if typeof(value) == TYPE_ARRAY:
			result[field] = (value as Array).duplicate(true)
		elif typeof(value) == TYPE_DICTIONARY:
			result[field] = (value as Dictionary).duplicate(true)
		else:
			result[field] = value
	return result


static func _apply_portable_ticket_state_to_machine(kind: String, portable: Dictionary, machine: Dictionary) -> void:
	for field_value in _copy_array(PORTABLE_TICKET_PLAYER_FIELDS.get(kind, [])):
		var field := str(field_value)
		if portable.has(field):
			# Keep live array/dictionary references. Scratch pointer moves mutate
			# only the active ticket's masks and must not copy the whole pile.
			machine[field] = portable[field]


static func _portable_ticket_state_count(kind: String, state: Dictionary) -> int:
	var count := _portable_ticket_array_size(state.get("winner_pile", [])) + _portable_ticket_array_size(state.get("loser_pile", []))
	if kind == "pull_tabs":
		return count + _portable_ticket_array_size(state.get("tray_stack", [])) + _portable_ticket_array_size(state.get("ticket_stack", []))
	if kind == "scratch_tickets" and not _copy_dict(state.get("active_ticket", {})).is_empty():
		count += 1
	return count


static func _portable_ticket_array_size(value: Variant) -> int:
	return (value as Array).size() if typeof(value) == TYPE_ARRAY else 0


static func _portable_ticket_dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append(entry)
	return result


static func _normalize_portable_ticket_piles(value: Dictionary) -> Dictionary:
	var result := {}
	for kind_value in PORTABLE_TICKET_KINDS:
		var kind := str(kind_value)
		var origins_value: Variant = value.get(kind, {})
		var origins := {}
		if typeof(origins_value) == TYPE_DICTIONARY:
			for origin_key_value in (origins_value as Dictionary).keys():
				var origin_key := str(origin_key_value).strip_edges()
				var state_value: Variant = (origins_value as Dictionary).get(origin_key_value, {})
				if origin_key.is_empty() or typeof(state_value) != TYPE_DICTIONARY:
					continue
				var state: Dictionary = (state_value as Dictionary).duplicate(true)
				state["origin_key"] = origin_key
				origins[origin_key] = state
		if not origins.is_empty() or value.has(kind):
			result[kind] = origins
	return result


static func _inventory_item_id(entry: Variant) -> String:
	if typeof(entry) == TYPE_DICTIONARY:
		return str((entry as Dictionary).get("id", "")).strip_edges()
	return str(entry).strip_edges()


static func _numeric_effect_value(effect: Dictionary, key: String) -> int:
	var value: Variant = effect.get(key, 0)
	var value_type := typeof(value)
	if value_type == TYPE_INT or value_type == TYPE_FLOAT:
		return int(value)
	return 0


# Normalizes a list of ids into strings.
static func _string_array(values: Array) -> Array:
	var result: Array = []
	for value in values:
		var id := str(value)
		if not id.is_empty():
			result.append(id)
	return result


# Keeps suspicion state in the README behavior-first shape.
static func _normalize_suspicion(data: Dictionary) -> Dictionary:
	var local_levels := {}
	var source_levels := _copy_dict(data.get("local_levels", {}))
	for key in source_levels.keys():
		var location_id := str(key)
		if not location_id.is_empty():
			local_levels[location_id] = clampi(int(source_levels.get(key, 0)), 0, 100)
	return {
		"level": clampi(int(data.get("level", 0)), 0, 100),
		"cues": _copy_array(data.get("cues", [])),
		"local_levels": local_levels,
	}


# Normalizes debt entries after JSON save/load.
static func _normalize_debt_entries(entries: Array) -> Array:
	var result: Array = []
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var debt_entry := (entry as Dictionary).duplicate(true)
		debt_entry["id"] = str(debt_entry.get("id", "debt_%d" % result.size()))
		debt_entry["lender_id"] = str(debt_entry.get("lender_id", debt_entry.get("id", "")))
		debt_entry["status"] = str(debt_entry.get("status", "active"))
		debt_entry["debt_kind"] = str(debt_entry.get("debt_kind", "cash"))
		if debt_entry.has("balance"):
			debt_entry["balance"] = int(debt_entry.get("balance", 0))
		else:
			debt_entry["balance"] = 0
		if debt_entry.has("principal"):
			debt_entry["principal"] = maxi(0, int(debt_entry.get("principal", 0)))
		elif str(debt_entry.get("debt_kind", "cash")) == "pawn":
			debt_entry["principal"] = maxi(0, int(debt_entry.get("balance", 0)))
		if debt_entry.has("redemption_fee"):
			debt_entry["redemption_fee"] = maxi(0, int(debt_entry.get("redemption_fee", 0)))
		if debt_entry.has("redemption_fee_rate"):
			debt_entry["redemption_fee_rate"] = clampf(float(debt_entry.get("redemption_fee_rate", 0.0)), 0.0, 2.0)
		if str(debt_entry.get("debt_kind", "cash")) == "pawn":
			debt_entry["collateral_item_id"] = str(debt_entry.get("collateral_item_id", ""))
			debt_entry["collateral_item_name"] = str(debt_entry.get("collateral_item_name", debt_entry.get("collateral_item_id", "")))
		if debt_entry.has("loan_count"):
			debt_entry["loan_count"] = maxi(1, int(debt_entry.get("loan_count", 1)))
		if debt_entry.has("source_location_id"):
			debt_entry["source_location_id"] = str(debt_entry.get("source_location_id", ""))
		var source_location_ids: Array = []
		var source_lookup := {}
		for source_value in _copy_array(debt_entry.get("source_location_ids", [])):
			var source_location_id := str(source_value)
			if source_location_id.is_empty() or source_lookup.has(source_location_id):
				continue
			source_lookup[source_location_id] = true
			source_location_ids.append(source_location_id)
		var single_source_location := str(debt_entry.get("source_location_id", ""))
		if not single_source_location.is_empty() and not source_lookup.has(single_source_location):
			source_lookup[single_source_location] = true
			source_location_ids.append(single_source_location)
		if not source_location_ids.is_empty():
			debt_entry["source_location_ids"] = source_location_ids
		debt_entry["deadline_turns"] = maxi(0, int(debt_entry.get("deadline_turns", 0)))
		if debt_entry.has("turns_remaining"):
			debt_entry["turns_remaining"] = maxi(0, int(debt_entry.get("turns_remaining", 0)))
		else:
			debt_entry["turns_remaining"] = int(debt_entry.get("deadline_turns", 0))
		if debt_entry.has("next_pressure_turns"):
			debt_entry["next_pressure_turns"] = maxi(0, int(debt_entry.get("next_pressure_turns", 0)))
		if debt_entry.has("nag_interval_turns"):
			debt_entry["nag_interval_turns"] = maxi(1, int(debt_entry.get("nag_interval_turns", 1)))
		if debt_entry.has("interest_rate"):
			debt_entry["interest_rate"] = maxf(0.0, float(debt_entry.get("interest_rate", 0.0)))
		if debt_entry.has("cash_conversion_interest_rate"):
			debt_entry["cash_conversion_interest_rate"] = maxf(0.0, float(debt_entry.get("cash_conversion_interest_rate", 0.0)))
		if debt_entry.has("cash_conversion_balance_per_favor"):
			debt_entry["cash_conversion_balance_per_favor"] = maxi(1, int(debt_entry.get("cash_conversion_balance_per_favor", 1)))
		debt_entry["default_consequence"] = str(debt_entry.get("default_consequence", "favor_owed"))
		result.append(debt_entry)
	return result


# Normalizes saved environment history entries.
static func _normalize_environment_history(entries: Array) -> Array:
	var result: Array = []
	for entry in entries:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append(_environment_history_entry(entry as Dictionary))
	return result


# History only feeds visited-location summaries and route progression. Keeping a
# full environment instance here duplicated every machine's runtime state on
# each trip, making autosaves grow throughout a run and eventually stall play.
static func _environment_history_entry(environment: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in ["id", "archetype_id", "world_node_id", "display_name", "kind", "entered_game_clock_minutes", "departed_game_clock_minutes"]:
		if environment.has(key):
			result[key] = environment.get(key)
	return result


static func _normalize_grand_casino_room_states(room_states: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for room_id_value in GRAND_CASINO_ARCHETYPE_IDS:
		var room_id := str(room_id_value)
		var room: Variant = room_states.get(room_id, {})
		if typeof(room) == TYPE_DICTIONARY and not (room as Dictionary).is_empty():
			result[room_id] = _normalize_environment((room as Dictionary).duplicate(true))
	return result


static func _normalize_grand_casino_staffing(staffing: Dictionary) -> Dictionary:
	if staffing.is_empty():
		return {}
	var assignments: Dictionary = {}
	var source_assignments: Dictionary = staffing.get("assignments", {}) if typeof(staffing.get("assignments", {})) == TYPE_DICTIONARY else {}
	for role_value in GRAND_CASINO_STAFF_ROLE_IDS:
		var role_id := str(role_value)
		var member_value: Variant = source_assignments.get(role_id, {})
		if typeof(member_value) != TYPE_DICTIONARY:
			continue
		var member := (member_value as Dictionary).duplicate(true)
		var member_id := str(member.get("id", "")).strip_edges()
		if member_id.is_empty() or member_id == "rourke" or member_id == "linda":
			continue
		member["id"] = member_id
		member["name"] = str(member.get("name", member_id.capitalize()))
		member["style_id"] = str(member.get("style_id", "mara"))
		member["role_id"] = role_id
		member["day"] = maxi(1, int(member.get("day", staffing.get("day", 1))))
		assignments[role_id] = member
	var entry_cue: Dictionary = staffing.get("entry_cue", {}) if typeof(staffing.get("entry_cue", {})) == TYPE_DICTIONARY else {}
	return {
		"day": maxi(0, int(staffing.get("day", 0))),
		"rotation_chance_percent": clampi(int(staffing.get("rotation_chance_percent", GRAND_CASINO_STAFF_ROTATION_CHANCE_PERCENT)), 0, 100),
		"assignments": assignments,
		"rotated_roles": _string_array(_copy_array(staffing.get("rotated_roles", []))),
		"rotation_occurred": bool(staffing.get("rotation_occurred", false)),
		"constants": {
			"rourke": {"id": "rourke", "name": "Rourke"},
			"linda": {"id": "linda", "name": "Linda"},
		},
		"entry_cue": entry_cue,
		"rotation_cue_shown_day": maxi(0, int(staffing.get("rotation_cue_shown_day", 0))),
	}


static func _empty_grand_casino_room_heat_accumulators() -> Dictionary:
	return {
		GRAND_CASINO_ARCHETYPE_ID: 0,
		GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID: 0,
		GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID: 0,
	}


static func _normalize_grand_casino_room_heat_accumulators(room_heat: Dictionary) -> Dictionary:
	var result := _empty_grand_casino_room_heat_accumulators()
	for room_id_value in GRAND_CASINO_ARCHETYPE_IDS:
		var room_id := str(room_id_value)
		result[room_id] = maxi(0, int(room_heat.get(room_id, 0)))
	return result


static func _normalize_grand_casino_room_id(room_id: String) -> String:
	var normalized := room_id.strip_edges()
	return normalized if GRAND_CASINO_ARCHETYPE_IDS.has(normalized) else ""


static func _normalize_rival_cheaters(entries: Array) -> Array:
	var result: Array = []
	var seen := {}
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry := (entry_value as Dictionary).duplicate(true)
		var rival_id := str(entry.get("id", "")).strip_edges()
		var room_id := str(entry.get("room", "")).strip_edges()
		if rival_id.is_empty() or seen.has(rival_id) or not RIVAL_CHEATER_ROOMS.has(room_id):
			continue
		seen[rival_id] = true
		entry["id"] = rival_id
		entry["display_name"] = str(entry.get("display_name", "Rival"))
		entry["room"] = room_id
		entry["spot"] = clampi(int(entry.get("spot", 0)), 0, 2)
		entry["tell"] = str(entry.get("tell", "chip_riffle"))
		entry["idle_phase"] = maxi(0, int(entry.get("idle_phase", 0)))
		entry["last_heat_gain"] = clampi(int(entry.get("last_heat_gain", 0)), 0, 2)
		entry["last_heat_action"] = maxi(0, int(entry.get("last_heat_action", 0)))
		result.append(entry)
		if result.size() >= RIVAL_CHEATER_MAX_COUNT:
			break
	return result


static func _normalize_rourke_escort_state(data: Dictionary) -> Dictionary:
	if data.is_empty() or str(data.get("cheater_id", "")).strip_edges().is_empty():
		return {}
	return {
		"cheater_id": str(data.get("cheater_id", "")),
		"cheater_name": str(data.get("cheater_name", "Rival")),
		"tell": str(data.get("tell", "")),
		"caught_room": _normalize_grand_casino_room_id(str(data.get("caught_room", ""))),
		"actions_remaining": clampi(int(data.get("actions_remaining", 0)), 0, ROURKE_OFF_FLOOR_ACTIONS),
	}


func _grand_casino_room_states_for_save() -> Dictionary:
	var result: Dictionary = {}
	var active_room_id := ""
	if _is_grand_casino_environment(current_environment):
		active_room_id = str(current_environment.get("archetype_id", GRAND_CASINO_ARCHETYPE_ID)).strip_edges()
	for room_id_value in GRAND_CASINO_ARCHETYPE_IDS:
		var room_id := str(room_id_value)
		# current_environment already serializes the active room. Re-inserting it
		# on load avoids duplicating that potentially large game/layout payload.
		if room_id == active_room_id:
			continue
		var room: Variant = grand_casino_room_states.get(room_id, {})
		if typeof(room) == TYPE_DICTIONARY and not (room as Dictionary).is_empty():
			result[room_id] = (room as Dictionary).duplicate(true)
	return result


# Normalizes story entries after JSON save/load.
static func _normalize_story_log(entries: Array) -> Array:
	var result: Array = []
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var story_entry := (entry as Dictionary).duplicate(true)
		_normalize_story_numeric_fields(story_entry)
		var skill_context := _copy_dict(story_entry.get("skill_story_context", {}))
		if not skill_context.is_empty():
			_normalize_story_numeric_fields(skill_context)
			story_entry["skill_story_context"] = skill_context
		result.append(story_entry)
	return result


static func _normalize_story_numeric_fields(story_entry: Dictionary) -> void:
	for key in ["bankroll", "target_bankroll", "bankroll_delta", "suspicion_delta", "payout", "base_payout", "match_count", "security_bankroll_delta", "cost", "stake_cost", "jackpot_current", "bumper_progress", "bonus_total", "alcohol_intake", "drunk_delta", "alcoholic_delta", "baseline_luck_delta", "luck_modifier", "luck_payout_bonus", "item_payout_bonus", "item_loss_reduction", "pit_boss_heat_bonus", "tab_detector_heat", "tab_detector_base_heat", "base_heat", "suspicious_ticket_count", "fake_ticket_count", "loser_ticket_count", "cashout_pattern_heat"]:
		if story_entry.has(key):
			story_entry[key] = int(story_entry.get(key, 0))


static func _normalize_pending_drunk_absorption(entries: Array) -> Array:
	var result: Array = []
	var now_msec := 0
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value as Dictionary
		var remaining := maxi(0, int(entry.get("remaining", 0)))
		if remaining <= 0:
			continue
		var interval := maxi(1, int(entry.get("interval_msec", DRUNK_ABSORPTION_INTERVAL_MSEC)))
		var next_msec := int(entry.get("next_msec", now_msec + interval))
		if next_msec <= 0:
			next_msec = now_msec + interval
		var queued_msec := int(entry.get("queued_msec", now_msec))
		if queued_msec <= 0:
			queued_msec = maxi(0, next_msec - interval)
		result.append({
			"remaining": remaining,
			"interval_msec": interval,
			"next_msec": next_msec,
			"queued_msec": queued_msec,
		})
	return result


static func _normalize_triggered_event_queue(entries: Array) -> Array:
	var result: Array = []
	for entry_value in entries:
		var entry := _normalize_triggered_event_entry(entry_value)
		if not entry.is_empty():
			result.append(entry)
	return result


static func _normalize_triggered_event_entry(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = value as Dictionary
	var event_id := str(source.get("event_id", source.get("id", ""))).strip_edges()
	if event_id.is_empty():
		return {}
	var context := _copy_dict(source.get("context", {}))
	var presentation := str(source.get("presentation", "modal")).strip_edges().to_lower()
	if not ["talk", "modal"].has(presentation):
		presentation = "modal"
	return {
		"event_id": event_id,
		"source": str(source.get("source", "")),
		"context": context,
		"environment_id": str(source.get("environment_id", "")),
		"environment_turns": maxi(0, int(source.get("environment_turns", source.get("queued_turn", 0)))),
		"presentation": presentation,
		"speaker": _normalize_triggered_event_speaker(source.get("speaker", {})),
		"dialogue_id": str(source.get("dialogue_id", "")).strip_edges(),
		"current_node": str(source.get("current_node", source.get("dialogue_node", ""))).strip_edges(),
		"timing": _normalize_triggered_event_timing(source.get("timing", {})),
		"active": bool(source.get("active", false)),
	}


static func _normalize_triggered_event_speaker(value: Variant) -> Dictionary:
	var source := _copy_dict(value)
	var role := str(source.get("role", "stranger")).strip_edges().to_lower()
	if not ["patron", "staff", "stranger", "lender"].has(role):
		role = "stranger"
	var bind := str(source.get("bind", "none")).strip_edges().to_lower()
	if not ["table_patron", "none"].has(bind):
		bind = "none"
	return {
		"role": role,
		"name": str(source.get("name", "")).strip_edges(),
		"mood": str(source.get("mood", "")).strip_edges(),
		"behavior": str(source.get("behavior", "")).strip_edges(),
		"silhouette": str(source.get("silhouette", "")).strip_edges(),
		"bind": bind,
		"patron_index": maxi(-1, int(source.get("patron_index", -1))),
		"hair_color": str(source.get("hair_color", "")).strip_edges(),
		"jacket_color": str(source.get("jacket_color", "")).strip_edges(),
		"tell": str(source.get("tell", "")).strip_edges(),
	}


static func _normalize_triggered_event_timing(value: Variant) -> Dictionary:
	var source := _copy_dict(value)
	var duration_actions := maxi(0, int(source.get("duration_actions", 0)))
	var remaining_actions := maxi(0, int(source.get("remaining_actions", duration_actions)))
	var timeout_choice_id := str(source.get("timeout_choice_id", "")).strip_edges()
	var expires := bool(source.get("expires", false)) and duration_actions > 0 and not timeout_choice_id.is_empty()
	if not expires:
		duration_actions = 0
		remaining_actions = 0
		timeout_choice_id = ""
	return {
		"expires": expires,
		"duration_actions": duration_actions,
		"remaining_actions": mini(remaining_actions, duration_actions) if duration_actions > 0 else 0,
		"timeout_choice_id": timeout_choice_id,
	}


static func _normalize_pending_bag_markers(entries: Array) -> Array:
	var result: Array = []
	for entry_value in entries:
		var marker := _normalize_pending_bag_marker(entry_value)
		if marker.is_empty():
			continue
		var marker_id := str(marker.get("marker_id", ""))
		var duplicate_found := false
		for existing_value in result:
			var existing := _copy_dict(existing_value)
			if not marker_id.is_empty() and str(existing.get("marker_id", "")) == marker_id:
				duplicate_found = true
				break
		if not duplicate_found:
			result.append(marker)
	return result


static func _normalize_pending_bag_marker(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source := _copy_dict(value)
	var bagdef_id := int(source.get("bagdef_id", source.get("itemdef_id", -1)))
	if bagdef_id < 0:
		return {}
	var source_id := str(source.get("source_id", source.get("event_id", ""))).strip_edges()
	var source_type := str(source.get("source", "run_end")).strip_edges()
	if source_type.is_empty():
		source_type = "run_end"
	var rng_seed := str(source.get("rng_seed", "")).strip_edges()
	if rng_seed.is_empty():
		rng_seed = "%s|%s|%d" % [source_type, source_id, bagdef_id]
	var marker_id := str(source.get("marker_id", "")).strip_edges()
	if marker_id.is_empty():
		marker_id = "%s:%s:%d:%s" % [source_type, source_id, bagdef_id, rng_seed]
	return {
		"schema_version": int(source.get("schema_version", 1)),
		"bagdef_id": bagdef_id,
		"collection_id": str(source.get("collection_id", "")).strip_edges(),
		"collection_display_name": str(source.get("collection_display_name", "")).strip_edges(),
		"tier": str(source.get("tier", "")).strip_edges(),
		"rolled_tier": str(source.get("rolled_tier", source.get("tier", ""))).strip_edges(),
		"tier_bonus_steps": maxi(0, int(source.get("tier_bonus_steps", 0))),
		"tier_label": str(source.get("tier_label", "")).strip_edges(),
		"display_name": str(source.get("display_name", "Collection Bag")).strip_edges(),
		"icon_key": str(source.get("icon_key", "")).strip_edges(),
		"source": source_type,
		"source_id": source_id,
		"rng_seed": rng_seed,
		"marker_id": marker_id,
	}


func _drunk_luck_bonus() -> int:
	if drunk_level >= 85:
		return 5
	if drunk_level >= 65:
		return 4
	if drunk_level >= 45:
		return 3
	if drunk_level >= 25:
		return 2
	if drunk_level >= 12:
		return 1
	return 0


func _alcohol_dependency_penalty(gap: int) -> int:
	if gap >= 70:
		return 6
	if gap >= 50:
		return 4
	if gap >= 30:
		return 3
	if gap >= 15:
		return 2
	if gap >= 5:
		return 1
	return 0


# Normalizes the saveable parts of the current environment owned by RunState.
static func _normalize_environment(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	var environment := data.duplicate(true)
	environment["depth"] = int(environment.get("depth", 0))
	environment["tier"] = int(environment.get("tier", 1))
	environment["turns"] = int(environment.get("turns", 0))
	environment["world_node_id"] = str(environment.get("world_node_id", environment.get("archetype_id", environment.get("id", "")))).strip_edges()
	environment["travel_locked_actions"] = maxi(0, int(environment.get("travel_locked_actions", 0)))
	environment["travel_lock_remaining"] = maxi(0, int(environment.get("travel_lock_remaining", environment["travel_locked_actions"])))
	environment["resolved_event_ids"] = _copy_array(environment.get("resolved_event_ids", []))
	environment["game_ids"] = _copy_array(environment.get("game_ids", []))
	environment["event_ids"] = _copy_array(environment.get("event_ids", []))
	environment["item_offers"] = _normalize_item_offers(_copy_array(environment.get("item_offers", [])))
	environment["home_profile"] = _copy_dict(environment.get("home_profile", {}))
	environment["home_containers"] = _normalize_home_containers(_copy_array(environment.get("home_containers", [])))
	environment["home_container_index"] = maxi(0, int(environment.get("home_container_index", 0)))
	environment["home_lost"] = bool(environment.get("home_lost", false))
	environment["parent_archetype"] = str(environment.get("parent_archetype", ""))
	environment["service_ids"] = _copy_array(environment.get("service_ids", []))
	environment["lender_hooks"] = _copy_array(environment.get("lender_hooks", []))
	if str(environment.get("archetype_id", "")) != PAWN_SHOP_ARCHETYPE_ID:
		while environment["lender_hooks"].has(SALS_PAWN_COUNTER_ID):
			environment["lender_hooks"].erase(SALS_PAWN_COUNTER_ID)
	environment["suspicion_cues"] = _copy_array(environment.get("suspicion_cues", []))
	environment["travel_hooks"] = _copy_array(environment.get("travel_hooks", []))
	environment["next_archetypes"] = _copy_array(environment.get("next_archetypes", []))
	environment["object_fixtures"] = _copy_array(environment.get("object_fixtures", []))
	environment["local_narrative_flags"] = _copy_dict(environment.get("local_narrative_flags", {}))
	environment["game_states"] = _normalize_game_states(_copy_dict(environment.get("game_states", {})))
	environment["visual_context"] = _copy_dict(environment.get("visual_context", {}))
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)
	environment["security_profile"] = _copy_dict(environment.get("security_profile", {}))
	environment["economic_profile"] = _normalize_economic_profile(_copy_dict(environment.get("economic_profile", {})))
	environment["objective_hint"] = str(environment.get("objective_hint", ""))
	environment["demo_objective"] = _copy_dict(environment.get("demo_objective", {}))
	return environment


static func _normalize_closing_time_state(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	var phase := str(data.get("phase", "")).strip_edges()
	if phase != CLOSING_TIME_PHASE_GRACE and phase != CLOSING_TIME_PHASE_FORCED_TRAVEL:
		return {}
	var environment_id := str(data.get("environment_id", "")).strip_edges()
	var display_name := str(data.get("display_name", environment_id.replace("_", " ").capitalize())).strip_edges()
	if display_name.is_empty():
		display_name = "This venue"
	return {
		"phase": phase,
		"environment_id": environment_id,
		"world_node_id": str(data.get("world_node_id", "")).strip_edges(),
		"archetype_id": str(data.get("archetype_id", environment_id)).strip_edges(),
		"display_name": display_name,
		"started_game_clock_minutes": maxi(0, int(data.get("started_game_clock_minutes", 0))),
		"started_minute_of_day": clampi(int(data.get("started_minute_of_day", 0)), 0, EnvironmentHours.MINUTES_PER_DAY - 1),
		"grace_actions_remaining": maxi(0, int(data.get("grace_actions_remaining", 0))),
		"message": str(data.get("message", "%s is closing." % display_name)),
	}


# Normalizes saved cadence state after load or older saves.
func _normalize_event_cadence(data: Dictionary) -> Dictionary:
	if data.is_empty():
		var base_rng := RngStream.new()
		base_rng.configure(seed_value, seed_value)
		var cadence_rng := base_rng.fork("event_cadence")
		return {
			"rng_seed": cadence_rng.seed_value,
			"rng_state": cadence_rng.state_value,
			"action_index": 0,
			"last_world_event_action": -9999,
			"last_modal_closed_action": -9999,
			"visit_key": "",
			"visit_should_fire": false,
			"visit_min_action": 0,
			"visit_event_count": 0,
			"visit_event_ids": [],
			"seen_event_counts": {},
			"visit_count": 0,
			"quiet_visit_count": 0,
		}
	var normalized := data.duplicate(true)
	normalized["rng_seed"] = maxi(1, int(normalized.get("rng_seed", seed_value)))
	normalized["rng_state"] = maxi(1, int(normalized.get("rng_state", normalized.get("rng_seed", seed_value))))
	normalized["action_index"] = maxi(0, int(normalized.get("action_index", 0)))
	normalized["last_world_event_action"] = int(normalized.get("last_world_event_action", -9999))
	normalized["last_modal_closed_action"] = int(normalized.get("last_modal_closed_action", -9999))
	normalized["visit_key"] = str(normalized.get("visit_key", ""))
	normalized["visit_should_fire"] = bool(normalized.get("visit_should_fire", false))
	normalized["visit_min_action"] = maxi(0, int(normalized.get("visit_min_action", 0)))
	normalized["visit_event_count"] = maxi(0, int(normalized.get("visit_event_count", 0)))
	normalized["visit_event_ids"] = _copy_array(normalized.get("visit_event_ids", []))
	normalized["seen_event_counts"] = _copy_dict(normalized.get("seen_event_counts", {}))
	normalized["visit_count"] = maxi(0, int(normalized.get("visit_count", 0)))
	normalized["quiet_visit_count"] = maxi(0, int(normalized.get("quiet_visit_count", 0)))
	return normalized


static func _normalize_music_arrangement_state(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	var history := _string_array(_copy_array(data.get("section_history", [])))
	while history.size() > 8:
		history.pop_front()
	return {
		"visit_id": str(data.get("visit_id", "")).strip_edges(),
		"track_id": str(data.get("track_id", "")).strip_edges(),
		"recipe_id": str(data.get("recipe_id", "")).strip_edges(),
		"cursor": maxi(0, int(data.get("cursor", 0))),
		"harmonic_section": str(data.get("harmonic_section", "A")).strip_edges().to_upper(),
		"last_phrase_event_index": maxi(-1, int(data.get("last_phrase_event_index", -1))),
		"last_phrase_event_token": str(data.get("last_phrase_event_token", "")).strip_edges(),
		"phrase_slot": maxi(0, int(data.get("phrase_slot", 0))),
		"section_history": history,
		"selected_variant_ids": _normalize_music_variant_ids(data.get("selected_variant_ids", {})),
		"role_epochs": _normalize_music_role_epochs(data.get("role_epochs", {})),
		"selected_role_epochs": _normalize_music_role_epochs(data.get("selected_role_epochs", {})),
	}


static func _normalize_music_tempo_state(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	return {
		"profile_id": str(data.get("profile_id", "")).strip_edges(),
		"enabled": bool(data.get("enabled", false)),
		"current_bpm": clampf(float(data.get("current_bpm", 82.0)), 40.0, 260.0),
		"target_bpm": clampf(float(data.get("target_bpm", 82.0)), 40.0, 260.0),
		"source_heat": clampf(float(data.get("source_heat", 0.0)), 0.0, 100.0),
		"transport_beats": maxf(0.0, float(data.get("transport_beats", 0.0))),
		"source_position": maxf(0.0, float(data.get("source_position", 0.0))),
	}


static func _normalize_music_choreography_state(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	return {
		"profile_id": str(data.get("profile_id", "")).strip_edges(),
		"visit_bar": maxi(0, int(data.get("visit_bar", 0))),
		"stage_id": str(data.get("stage_id", "")).strip_edges(),
		"stage_index": maxi(-1, int(data.get("stage_index", -1))),
		"next_boundary_bar": maxi(-1, int(data.get("next_boundary_bar", -1))),
		"last_fill_bar": int(data.get("last_fill_bar", -9999)),
		"scheduled_transition": _copy_dict(data.get("scheduled_transition", {})),
		"feature_release_bar": maxi(-1, int(data.get("feature_release_bar", -1))),
		"role_target": _normalize_music_role_gains(data.get("role_target", {})),
		"role_live": _normalize_music_role_gains(data.get("role_live", {})),
	}


static func _normalize_music_role_gains(value: Variant) -> Dictionary:
	var source := _copy_dict(value)
	var result := {}
	for key_value in source.keys():
		var key := str(key_value).strip_edges()
		if not key.is_empty():
			result[key] = clampf(float(source.get(key_value, 1.0)), 0.0, 1.0)
	return result


static func _normalize_music_variant_ids(value: Variant) -> Dictionary:
	var source := _copy_dict(value)
	var result := {}
	for key_value in source.keys():
		var key := str(key_value).strip_edges()
		if not key.is_empty():
			result[key] = str(source.get(key_value, "")).strip_edges()
	return result


static func _normalize_music_role_epochs(value: Variant) -> Dictionary:
	var source := _copy_dict(value)
	var result := {}
	for key_value in source.keys():
		var key := str(key_value).strip_edges()
		if not key.is_empty():
			result[key] = maxi(0, int(source.get(key_value, 0)))
	return result


# Normalizes generated item offers after JSON save/load.
static func _normalize_item_offers(offers: Array) -> Array:
	var result: Array = []
	for offer in offers:
		if typeof(offer) != TYPE_DICTIONARY:
			continue
		var item_offer := (offer as Dictionary).duplicate(true)
		if item_offer.has("price"):
			item_offer["price"] = int(item_offer.get("price", 0))
		if item_offer.has("forfeited_pawn_shelf"):
			item_offer["forfeited_pawn_shelf"] = bool(item_offer.get("forfeited_pawn_shelf", false))
		result.append(item_offer)
	return result


static func _normalize_home_containers(containers: Array) -> Array:
	var result: Array = []
	for container_value in containers:
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		var container: Dictionary = container_value
		var container_id := str(container.get("id", "")).strip_edges()
		var item_id := str(container.get("item_id", "")).strip_edges()
		if container_id.is_empty():
			container_id = item_id
		if container_id.is_empty() or item_id.is_empty():
			continue
		var normalized_items: Array = []
		for item_value in _copy_array(container.get("items", [])):
			var stored_item_id := str(item_value).strip_edges()
			if not stored_item_id.is_empty():
				normalized_items.append(stored_item_id)
		var capacity := maxi(0, int(container.get("capacity", normalized_items.size())))
		if normalized_items.size() > capacity and capacity > 0:
			normalized_items = normalized_items.slice(0, capacity)
		var normalized_container := {
			"id": container_id,
			"item_id": item_id,
			"display_name": str(container.get("display_name", item_id.replace("_", " ").capitalize())),
			"capacity": capacity,
			"items": normalized_items,
		}
		if bool(container.get("meta_loadout", false)):
			normalized_container["meta_loadout"] = true
			normalized_container["meta_container_instance_id"] = maxi(0, int(container.get("meta_container_instance_id", 0)))
			var item_definitions := _copy_dict(container.get("item_definitions", {}))
			var normalized_definitions := {}
			for stored_item_id in normalized_items:
				var stored_definition := _copy_dict(item_definitions.get(stored_item_id, {}))
				if not stored_definition.is_empty():
					normalized_definitions[stored_item_id] = stored_definition
			normalized_container["item_definitions"] = normalized_definitions
		result.append(normalized_container)
	return result


static func _normalize_home_state(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	var normalized := data.duplicate(true)
	var lost := bool(normalized.get("lost", false))
	normalized["active"] = bool(normalized.get("active", not lost)) and not lost
	normalized["lost"] = lost
	normalized["act_index"] = maxi(0, int(normalized.get("act_index", 0)))
	normalized["home_archetype_id"] = str(normalized.get("home_archetype_id", "")).strip_edges()
	normalized["home_node_id"] = str(normalized.get("home_node_id", normalized.get("home_archetype_id", ""))).strip_edges()
	normalized["display_name"] = str(normalized.get("display_name", normalized.get("home_archetype_id", "Home"))).strip_edges()
	if normalized["display_name"].is_empty():
		normalized["display_name"] = "Home"
	normalized["started_day"] = maxi(1, int(normalized.get("started_day", 1)))
	normalized["lost_day"] = maxi(0, int(normalized.get("lost_day", 0)))
	normalized["lost_reason"] = str(normalized.get("lost_reason", ""))
	var tenure := _copy_dict(normalized.get("tenure", {}))
	var tenure_type := str(tenure.get("type", "")).strip_edges().to_lower()
	if tenure_type == HOME_TENURE_STAY:
		tenure["type"] = HOME_TENURE_STAY
		tenure["days_remaining"] = maxi(0, int(tenure.get("days_remaining", tenure.get("prepaid_days", 0))))
		tenure["renewal_cost"] = maxi(0, int(tenure.get("renewal_cost", 0)))
		tenure["renewal_days"] = maxi(1, int(tenure.get("renewal_days", 1)))
		tenure["expiry_message"] = str(tenure.get("expiry_message", ""))
	elif tenure_type == HOME_TENURE_RENT:
		tenure["type"] = HOME_TENURE_RENT
		tenure["rent_amount"] = maxi(0, int(tenure.get("rent_amount", 0)))
		tenure["due_day"] = maxi(1, int(tenure.get("due_day", 1)))
		tenure["cycle_days"] = maxi(1, int(tenure.get("cycle_days", 1)))
		tenure["grace_days"] = maxi(0, int(tenure.get("grace_days", 0)))
		tenure["payment_label"] = str(tenure.get("payment_label", "rent")).strip_edges().to_lower()
		if str(tenure.get("payment_label", "")).is_empty():
			tenure["payment_label"] = "rent"
		tenure["action_label"] = str(tenure.get("action_label", "Pay %s" % str(tenure.get("payment_label", "rent")).capitalize())).strip_edges()
		if str(tenure.get("action_label", "")).is_empty():
			tenure["action_label"] = "Pay %s" % str(tenure.get("payment_label", "rent")).capitalize()
		tenure["eviction_message"] = str(tenure.get("eviction_message", ""))
	else:
		tenure = {}
	normalized["tenure"] = tenure
	return normalized


# Normalizes per-environment gameplay state owned by GameModule instances.
static func _normalize_game_states(states: Dictionary) -> Dictionary:
	var result := {}
	for key in states.keys():
		var game_id := str(key)
		if game_id.is_empty():
			continue
		var value: Variant = states[key]
		if typeof(value) == TYPE_DICTIONARY:
			result[game_id] = (value as Dictionary).duplicate(true)
	return result


# Normalizes economy fields after JSON save/load.
static func _normalize_economic_profile(profile: Dictionary) -> Dictionary:
	var result := profile.duplicate(true)
	for key in ["stake_floor", "stake_ceiling"]:
		if result.has(key):
			result[key] = int(result.get(key, 0))
	if typeof(result.get("game_stake_ceiling_overrides", {})) == TYPE_DICTIONARY:
		var normalized_overrides: Dictionary = {}
		var overrides: Dictionary = result.get("game_stake_ceiling_overrides", {})
		for game_id in overrides.keys():
			var normalized_id := str(game_id).strip_edges()
			if normalized_id.is_empty():
				continue
			normalized_overrides[normalized_id] = maxi(0, int(overrides.get(game_id, 0)))
		result["game_stake_ceiling_overrides"] = normalized_overrides
	return result


# Returns a positive fraction of the current bankroll for pressure limits.
func _fractional_bankroll_limit(divisor: int) -> int:
	if bankroll <= 0:
		return 0
	return maxi(1, bankroll / maxi(1, divisor))


# Updates economy and failure labels from bankroll and debt.
func _refresh_economy(defer_bankroll_zero: bool = false) -> void:
	if run_status == RUN_STATUS_ENDED or run_status == RUN_STATUS_FAILED:
		return
	var economy_balance := bankroll + grand_casino_chips if _is_grand_casino_environment(current_environment) else bankroll
	if economy_balance <= 0:
		if defer_bankroll_zero:
			bankroll = 0
			economic_state = "insolvent"
			return
		fail_run(FAILURE_BANKROLL_ZERO, BANKROLL_ZERO_FAILURE_MESSAGE)
	elif not debt.is_empty() and economy_balance < DEFAULT_BANKROLL:
		economic_state = "distressed"
		run_status = RUN_STATUS_ACTIVE
	elif economy_balance < DEFAULT_BANKROLL / 2:
		economic_state = "volatile"
		run_status = RUN_STATUS_ACTIVE
	elif economy_balance >= DEFAULT_BANKROLL * 2:
		economic_state = "growing"
		run_status = RUN_STATUS_ACTIVE
	else:
		economic_state = "stable"
		run_status = RUN_STATUS_ACTIVE
	if run_status == RUN_STATUS_ACTIVE:
		run_failure_reason = FAILURE_NONE
		run_failure_message = ""
