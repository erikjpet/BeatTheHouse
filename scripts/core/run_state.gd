class_name RunState
extends RefCounted

# Source of truth for one active run in the foundation path.
# Crew API (hidden, within-run state): crew_trust(member) reads trust;
# crew_rank(member) derives rank; crew_add_trust(member, amount, reason) mutates it;
# crew_standing() derives shared gates; grievance_add(entry) writes The Turn ledger;
# crew_grievances(member) is the private crew06_9 reader. Crew job lifecycle is
# host-only: player surfaces request work through crew_job_accept_definition(),
# while only this RunState's non-serialized capability can advance or settle it.

signal heat_changed(applied_amount: int, level: int, cue_id: String, context: Dictionary)

const GrandCasinoShowdownModelScript := preload("res://scripts/core/grand_casino_showdown_model.gd")
const GrandCasinoDuelModelScript := preload("res://scripts/core/grand_casino_duel_model.gd")
const CageEconomyModelScript := preload("res://scripts/core/cage_economy_model.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const ScenarioOperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const ScenarioSequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const ScenarioSequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const CrewWorldSequenceAdapterScript := preload("res://scripts/core/crew_world_sequence_adapter.gd")
const WorldSequencePackageCatalogScript := preload("res://scripts/core/world_sequence_package_catalog.gd")
const EnvironmentBaseSemanticRecordsScript := preload("res://scripts/core/environment_base_semantic_records.gd")
const EnvironmentSemanticInventoryScript := preload("res://scripts/core/environment_semantic_inventory.gd")
const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")
const ArtContractsScript := preload("res://scripts/core/art_contracts.gd")
const ScenarioHostTransactionScript := preload("res://scripts/core/scenario_host_transaction.gd")
const TownStateScript := preload("res://scripts/core/town_state.gd")
const PoliceSweepModelScript := preload("res://scripts/core/police_sweep_model.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const CrewRecruitmentModelScript := preload("res://scripts/core/crew_recruitment_model.gd")
const CrewPlayModelScript := preload("res://scripts/core/crew_play_model.gd")
const CrewHeistModelScript := preload("res://scripts/core/crew_heist_model.gd")
const CrewTurnModelScript := preload("res://scripts/core/crew_turn_model.gd")
const DeliveryRunModelScript := preload("res://scripts/core/delivery_run_model.gd")
const CrewPokerModelScript := preload("res://scripts/core/crew_poker_model.gd")
const NumbersModelScript := preload("res://scripts/core/numbers_model.gd")
const CharacterChainModelScript := preload("res://scripts/core/character_chain_model.gd")
const BlackjackActionAuthorityScript := preload("res://scripts/core/blackjack_action_authority.gd")
const GameRitualRuntimeScript := preload("res://scripts/core/game_ritual_runtime.gd")

const ENV06_6B_SEMANTIC_RESTORE_EQUIVALENCE_V1 := "ENV06_6B_SEMANTIC_RESTORE_EQUIVALENCE_V1"
const SCENARIO_DERIVED_NONCAUSAL_ENVIRONMENT_FIELDS := [
	"scenario_sequence_projection",
	"scenario_sequence_lifecycle_errors",
	"scenario_layout_context",
	"scenario_layout_audit",
	"scenario_render_snapshot",
	"scenario_restore_pending_trusted_rebuild",
]

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
const TUTORIAL_HEAT_CEILING := 99
const TUTORIAL_HEAT_INTERVENTION_LEVEL := 75
const TUTORIAL_DRUNK_COFFEE_THRESHOLD := 33
const TUTORIAL_DRUNK_COFFEE_ITEM_ID := "thermos_black_coffee"
const TUTORIAL_DRUNK_COFFEE_PENDING_FLAG := "tutorial_drunk_coffee_interventions_pending"
const FAILURE_NONE := ""
const FAILURE_BANKROLL_ZERO := "bankroll_zero"
const FAILURE_STRANDED := "stranded"
const FAILURE_POLICE_CAPTURE := "police_capture"
const FAILURE_CASINO_TAKEN_OUT_BACK := "casino_taken_out_back"
const FAILURE_ABANDONED := "abandoned"
const BANKROLL_ZERO_FAILURE_MESSAGE := "You are out of money. The room stops pretending it knows you."
const STRANDED_FAILURE_MESSAGE := "No stake, ride, sale, lender, or miracle remains. The night folds."
const POLICE_CAPTURE_FAILURE_MESSAGE := "Blue lights flood the room; cuffs find you first."
const CASINO_TAKEN_OUT_BACK_FAILURE_MESSAGE := "The casino walks you out back. The neon stays inside."
const ABANDONED_FAILURE_MESSAGE := "You leave the table before the table leaves you."
const GRAND_CASINO_ARCHETYPE_ID := "grand_casino"
const GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID := "grand_casino_high_limit"
const GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID := "grand_casino_back_room"
const GRAND_CASINO_CAGE_ARCHETYPE_ID := "grand_casino_cage"
const GRAND_CASINO_ARCHETYPE_IDS := [
	GRAND_CASINO_ARCHETYPE_ID,
	GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID,
	GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID,
	GRAND_CASINO_CAGE_ARCHETYPE_ID,
]
const GRAND_CASINO_TABLE_GAME_IDS := ["blackjack", "baccarat", "roulette", "craps"]
const GRAND_CASINO_CHIP_GAME_IDS := ["blackjack", "baccarat", "roulette", "craps", "video_poker", "pull_tabs", "bar_dice"]
const GRAND_CASINO_INVITATION_EVENT_ID := "grand_casino_invite"
const TIER_TWO_LOCATION_SPAWN_FLAG := "tier_two_casino_spawns_enabled"
const TIER_TWO_LOCATION_SPAWN_REASON_FLAG := "tier_two_casino_spawn_reason"
const TIER_TWO_LOCATION_SPAWN_VISITS_FLAG := "tier_two_casino_spawn_visit_ids"
const TIER_TWO_UNDERGROUND_SOURCE_ID := "small_underground_casino"
const TIER_TWO_REQUIRED_TIER_ONE_CASINO_VISITS := 2
const GRAND_CASINO_INVITATION_TABLE_WIN_THRESHOLD := 300
const GRAND_CASINO_INVITATION_TABLE_WIN_FLAG := "grand_casino_invite_table_win_spawned"
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
const CREW_HEIST_ROUTE := "crew_heist"
const TERMINAL_VICTORY_ROUTE_DEFINITIONS := [
	{"runtime_id": GRAND_CASINO_HIGH_ROLLER_EVENT_ID, "profile_id": "players_card_cashout", "career_label": "Players Card Cashout", "report_outcome_key": "players_card"},
	{"runtime_id": GRAND_CASINO_SHOWDOWN_ROUTE, "profile_id": "showdown", "career_label": "Rourke Showdown", "report_outcome_key": "showdown_survived"},
	{"runtime_id": CREW_HEIST_ROUTE, "profile_id": CREW_HEIST_ROUTE, "career_label": "Crew Heist", "report_outcome_prefix": "heist_"},
]
const TERMINAL_REPORT_ROUTE_ALIASES := {"tutorial_bronze_card": "players_card"}
const TERMINAL_FAILURE_REASONS := [
	FAILURE_BANKROLL_ZERO,
	FAILURE_STRANDED,
	FAILURE_POLICE_CAPTURE,
	FAILURE_CASINO_TAKEN_OUT_BACK,
	FAILURE_ABANDONED,
]
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
const GRAND_CASINO_SHOWDOWN_DEFAULT_SUCCESS_MESSAGE := "Rourke cannot prove enough to keep you. The elevator closes; the house keeps your face."
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
# Visit rows are deliberately tiny (identity plus entry/departure clocks). Keep
# enough exact visits for long multi-day report timelines without retaining any
# environment machine/runtime payloads.
const MAX_ENVIRONMENT_HISTORY_ENTRIES := 256
const MAX_STORY_LOG_ENTRIES := 240
const MAX_HEAT_HISTORY_ENTRIES := 480
const MAX_PENDING_TRIGGERED_EVENTS := 64
const MAX_PENDING_BAG_MARKERS := 32
const MAX_ATM_INTEREST_NOTIFICATIONS := 32
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
const BLACKJACK_BACKOFF_HEAT := 90
const BLACKJACK_BACKOFF_SCOPE := "blackjack_location"
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
	"pull_tabs": ["tray_stack", "ticket_stack", "winner_pile", "loser_pile", "loser_archive_count"],
	"scratch_tickets": ["active_ticket", "pending_queue", "winner_pile", "loser_pile", "loser_archive_count", "pending_penalty", "penalty_shields_remaining", "last_settled_ticket", "last_settled_pile", "last_file_id", "file_started_msec", "last_sweep_id", "last_sweep_section", "sweep_started_msec"],
}
const PORTABLE_PULL_TAB_LOSER_RECEIPT_LIMIT := 10
const PORTABLE_SCRATCH_TICKET_LOSER_RECEIPT_LIMIT := 5
const PORTABLE_PULL_TAB_RECEIPT_FIELDS := [
	"id", "deal_id", "deal_index", "ticket_number", "ticket_number_value", "serial", "form", "display_name",
	"palette", "price", "payout", "tainted", "fake", "tab_detector_heat",
	"xray_target_consumed", "burned_payout", "pile_depth_index", "origin_key", "origin_name",
	"origin_environment_id", "origin_world_node_id", "origin_archetype_id",
]
const PORTABLE_SCRATCH_RECEIPT_FIELDS := [
	"id", "type_id", "size_id", "display_name", "price", "payout", "outcome_id",
	"fortune_tier", "face", "palette", "result_ready", "settled",
	"discarded_unfinished", "mask_compacted", "origin_key", "origin_name",
	"origin_environment_id", "origin_world_node_id", "origin_archetype_id",
]

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
var scenario_recent_by_archetype: Dictionary = {}
var grand_casino_room_states: Dictionary = {}
var grand_casino_staffing: Dictionary = {}
var rourke_current_room: String = ""
var rourke_current_spot: String = ""
var rourke_facing: String = "right"
var rourke_actions_until_move: int = ROURKE_MOVE_EVALUATION_ACTIONS
var rourke_off_floor_actions: int = 0
var rourke_floor_action_index: int = 0
var linda_cage_state: Dictionary = {}
var grand_casino_room_heat_accumulators: Dictionary = {}
var rival_cheaters: Array = []
var rival_cheater_day: int = 0
var rourke_escort_state: Dictionary = {}
var pending_triggered_events: Array = []
var pending_bags: Array = []
var active_triggered_event: Dictionary = {}
var event_cadence: Dictionary = {}
var event_cadence_rng_create_call_count := 0
var event_cadence_rng_save_call_count := 0
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
var crew_trust_by_member: Dictionary = {}
var crew_grievance_ledger: Array = []
var crew_jobs: Dictionary = {}
var crew_grievance_sequence: int = 0
var crew_job_sequence: int = 0
var _crew_job_host_capability: RefCounted
var _crew_recruitment_host_capability: RefCounted
var _world1_host_capability: RefCounted
var _crew_heist_host_capability: RefCounted
var _crew_heist_private_capsule := ""
var _crew_heist_private_fingerprint := ""
# A RunState can be populated by small host/test fixtures before start_new().
# Give every instance a valid authority; start_new() remints it for each run and
# from_dict() replaces it with the authenticated saved or migrated authority.
var _crew_private_authority_id := CrewTurnModelScript.new_authority_id()
var active_delivery_run: Dictionary = {}
var crew_pattern_memory: Dictionary = {}
var scenario_host_transaction_ledger: Dictionary = {}
var crew_match_marks: Dictionary = {}
var crew_contraband_stash: Array = []
var crew_recruitment_encounters: Dictionary = {}
var crew_play_state: Dictionary = {}
var crew_heist_state: Dictionary = {}
var numbers_state: NumbersModel
var _numbers_host_capability: RefCounted
var heat_history: Array = []
var town_state: TownState
var simulation_msec: int = 0
var game_clock_minutes: int = GAME_CLOCK_START_MINUTE
var grand_casino_atm_interest_boundary_index: int = -1
var grand_casino_atm_interest_notifications: Array = []
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
var _item_effect_total_cache: Dictionary = {}
var _owned_item_lookup_cache: Dictionary = {}
var _owned_item_lookup_cache_valid := false
var _scenario_sequence_definition_cache: Dictionary = {}
# Fail-closed forced-rejection probe used by the retained-alias transaction contract.
# It can only reject a turn; it cannot grant authority or alter a consequence.
var _turn_transaction_test_failure_stage: String = ""

const TURN_TRANSACTION_SCALAR_FIELDS := [
	"seed_text", "seed_value", "rng_seed", "rng_state", "bankroll",
	"grand_casino_chips", "economic_state", "active_item_id", "baseline_luck",
	"drunk_level", "alcoholic_level", "drunk_distortion_suppression_turns",
	"rourke_current_room", "rourke_current_spot", "rourke_facing",
	"rourke_actions_until_move", "rourke_off_floor_actions",
	"rourke_floor_action_index", "rival_cheater_day",
	"event_cadence_rng_create_call_count", "event_cadence_rng_save_call_count",
	"environment_history_archive_count", "story_log_archive_count",
	"crew_grievance_sequence", "crew_job_sequence", "simulation_msec",
	"game_clock_minutes", "grand_casino_atm_interest_boundary_index", "act_index",
	"run_status", "run_failure_reason", "run_failure_message",
	"run_spending_score", "defer_next_bankroll_zero_failure",
	"_crew_private_authority_id",
	"_item_effects_loaded", "_item_definitions_loaded",
	"_owned_item_lookup_cache_valid", "_turn_transaction_test_failure_stage",
]
const TURN_TRANSACTION_COLLECTION_FIELDS := [
	"challenge_config", "inventory", "portable_ticket_piles", "debt",
	"sals_forfeited_item_ids", "suspicion", "pending_drunk_absorption",
	"current_environment", "world_map", "scenario_recent_by_archetype",
	"grand_casino_room_states", "grand_casino_staffing", "linda_cage_state",
	"grand_casino_room_heat_accumulators", "rival_cheaters",
	"rourke_escort_state", "pending_triggered_events", "pending_bags",
	"active_triggered_event", "event_cadence", "music_arrangement_state",
	"music_tempo_state", "music_choreography_state", "environment_history",
	"unlocked_travel", "narrative_flags", "story_flags", "story_log",
	"crew_trust_by_member", "crew_grievance_ledger", "crew_jobs",
	"active_delivery_run", "crew_pattern_memory",
	"scenario_host_transaction_ledger", "crew_match_marks",
	"crew_contraband_stash", "crew_recruitment_encounters", "crew_play_state", "crew_heist_state",
	"heat_history", "grand_casino_atm_interest_notifications",
	"closing_time_state", "home_state", "_item_effects_by_id",
	"_item_definitions_by_id", "_item_effect_total_cache",
	"_owned_item_lookup_cache", "_scenario_sequence_definition_cache",
]
const TURN_TRANSACTION_SHALLOW_CACHE_FIELDS := [
	"_item_effects_by_id", "_item_definitions_by_id", "_item_effect_total_cache",
	"_owned_item_lookup_cache", "_scenario_sequence_definition_cache",
]
var world_sequence_registrations: Dictionary = {}
var _world_sequence_definition_cache: Dictionary = {}

const WORLD_SEQUENCE_OUTCOME_CHANNELS := ["delivery_handoff", "heist_scene"]


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
	scenario_recent_by_archetype = {}
	_scenario_sequence_definition_cache = {}
	world_sequence_registrations = {}
	_world_sequence_definition_cache = {}
	grand_casino_room_states = {}
	grand_casino_staffing = {}
	rourke_current_room = ""
	rourke_current_spot = ""
	rourke_facing = "right"
	rourke_actions_until_move = ROURKE_MOVE_EVALUATION_ACTIONS
	rourke_off_floor_actions = 0
	rourke_floor_action_index = 0
	linda_cage_state = _default_linda_cage_state()
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
	crew_trust_by_member = CrewStateModelScript.default_trust()
	crew_grievance_ledger = []
	crew_jobs = {}
	crew_grievance_sequence = 0
	crew_job_sequence = 0
	_crew_job_host_capability = RefCounted.new()
	_crew_recruitment_host_capability = RefCounted.new()
	_world1_host_capability = RefCounted.new()
	_crew_heist_host_capability = RefCounted.new()
	_crew_heist_private_capsule = ""
	_crew_heist_private_fingerprint = ""
	# Mint the opaque save authority as part of run construction. Save projection
	# must be observational: lazily creating this id inside to_dict() made the
	# first read mutate a live run and invalidated transaction fingerprints.
	_crew_private_authority_id = CrewTurnModelScript.new_authority_id()
	active_delivery_run = {}
	crew_pattern_memory = CrewPokerModelScript.default_observations()
	scenario_host_transaction_ledger = {}
	crew_match_marks = {}
	crew_contraband_stash = []
	crew_recruitment_encounters = CrewRecruitmentModelScript.new_encounter_state()
	crew_play_state = CrewPlayModelScript.default_state()
	crew_heist_state = CrewHeistModelScript.empty_state()
	_numbers_host_capability = RefCounted.new()
	numbers_state = _new_numbers_model()
	numbers_state.reset(seed_value)
	heat_history = []
	town_state = TownStateScript.new()
	town_state.generate(seed_value)
	town_state.bind_host_capability(_world1_host_capability)
	simulation_msec = 0
	game_clock_minutes = GAME_CLOCK_START_MINUTE
	grand_casino_atm_interest_boundary_index = CageEconomyModelScript.boundary_index_at_or_before(game_clock_minutes)
	grand_casino_atm_interest_notifications = []
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
	var seam_route := profile_victory_route_for_runtime(demo_route)
	if seam_route.is_empty():
		return {}
	var payload := {
		"schema_version": 2 if seam_route == CREW_HEIST_ROUTE else 1,
		"source_act": act_marker(),
		"target_act": 2,
		"victory_route": seam_route,
		"demo_victory_route": demo_route,
		"final_bankroll_band": act_seam_bankroll_band(bankroll),
		"story_flags": story_flags.duplicate(true),
		"route_payload": _act_seam_route_payload(seam_route),
	}
	return payload


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


static func terminal_victory_route_definitions() -> Array:
	return TERMINAL_VICTORY_ROUTE_DEFINITIONS.duplicate(true)


static func terminal_failure_reasons() -> Array:
	return TERMINAL_FAILURE_REASONS.duplicate()


static func terminal_report_route_aliases() -> Dictionary:
	return TERMINAL_REPORT_ROUTE_ALIASES.duplicate(true)


static func terminal_crew_heist_outcomes() -> Array:
	var result: Array = []
	for outcome_value in CrewHeistModelScript.config().get("outcomes", []):
		if typeof(outcome_value) == TYPE_DICTIONARY:
			var outcome_id := str((outcome_value as Dictionary).get("id", "")).strip_edges()
			if not outcome_id.is_empty():
				result.append(outcome_id)
	return result


static func profile_victory_route_for_runtime(runtime_route: String) -> String:
	var clean_route := runtime_route.strip_edges()
	for definition_value in TERMINAL_VICTORY_ROUTE_DEFINITIONS:
		var definition: Dictionary = definition_value
		if str(definition.get("runtime_id", "")) == clean_route:
			return str(definition.get("profile_id", ""))
	return ""


static func report_outcome_key_for_runtime(runtime_route: String, heist_outcome: String = "") -> String:
	var clean_route := runtime_route.strip_edges()
	if TERMINAL_REPORT_ROUTE_ALIASES.has(clean_route):
		return str(TERMINAL_REPORT_ROUTE_ALIASES.get(clean_route, ""))
	for definition_value in TERMINAL_VICTORY_ROUTE_DEFINITIONS:
		var definition: Dictionary = definition_value
		if str(definition.get("runtime_id", "")) != clean_route:
			continue
		var direct_key := str(definition.get("report_outcome_key", "")).strip_edges()
		if not direct_key.is_empty():
			return direct_key
		var prefix := str(definition.get("report_outcome_prefix", ""))
		var branch := heist_outcome.strip_edges()
		var outcomes := terminal_crew_heist_outcomes()
		if not outcomes.has(branch):
			branch = "somebody_got_pinched"
		return "%s%s" % [prefix, branch]
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
		CREW_HEIST_ROUTE:
			var heist_payload := {
				"hook": "town_remembers",
				"outcome_band": str(crew_heist_state.get("outcome", "somebody_got_pinched")),
				"plan_id": str(crew_heist_state.get("plan_id", "")),
				"tone": "crew_exit",
			}
			var scar_id := str(_copy_dict(crew_heist_state.get("getaway", {})).get("scar", ""))
			if not scar_id.is_empty():
				heist_payload["story_scar"] = scar_id
			return heist_payload
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


func advance_game_clock_minutes(amount: int) -> Dictionary:
	if amount <= 0 or is_terminal():
		return {"ok": true, "applied": false, "errors": []}
	var previous_minutes := game_clock_minutes
	var previous_day := game_day()
	var next_minutes := maxi(0, game_clock_minutes + amount)
	var next_day := maxi(1, int(floor(float(next_minutes) / 1440.0)) + 1)
	if next_day > previous_day and _scenario_sequence_uses_expiry_boundary("night_end"):
		var rollback_environment := current_environment.duplicate(true)
		var expiry_result := scenario_sequence_apply_expiry_boundary("night_end", next_day - previous_day)
		if not bool(expiry_result.get("ok", false)):
			current_environment = rollback_environment
			return {"ok": false, "applied": false, "errors": _copy_array(expiry_result.get("errors", []))}
	game_clock_minutes = next_minutes
	_process_grand_casino_atm_interest_boundaries(previous_minutes, game_clock_minutes)
	if next_day > previous_day:
		for ended_day in range(previous_day, next_day):
			scenario_apply_expiry("night_end", ended_day)
		_advance_grand_casino_staff_day_rollovers(previous_day, next_day)
		_advance_home_day_rollovers(previous_day, next_day)
	return {"ok": true, "applied": true, "errors": []}


func advance_action_clock(amount: int = 1) -> Dictionary:
	var actions := maxi(0, amount)
	if actions <= 0:
		return {"ok": true, "applied": false, "errors": []}
	return advance_game_clock_minutes(actions * ACTION_CLOCK_MINUTES)


# True only during the discovered solo race between a published handle and the
# last authored late-book close. This is an opt-in travel consumer; normal travel
# never advances action boundaries.
func _numbers_past_post_race_active() -> bool:
	if numbers_state == null or not bool(numbers_state.knowledge.get("assembled", false)):
		return false
	var status := numbers_state.status()
	if not bool(status.get("posted", false)) or str(status.get("published_number", "")).is_empty():
		return false
	var post := int(status.get("post_action", 0))
	for venue_value in _copy_array(status.get("venue_status", [])):
		if typeof(venue_value) != TYPE_DICTIONARY:
			continue
		var venue: Dictionary = venue_value
		if bool(venue.get("open", false)) and int(venue.get("close_action", 0)) > post:
			return true
	return false


# Converts route duration into global boundary ticks only for the live Numbers
# race. It deliberately leaves both origin and generated destination local state
# untouched; local casino-room moves are never a physical street race.
func advance_numbers_past_post_travel_actions(travel_minutes: int, local_casino_room_move: bool = false) -> int:
	if travel_minutes <= 0 or local_casino_room_move or is_terminal() or not _numbers_past_post_race_active():
		return 0
	var actions := maxi(1, int(ceil(float(travel_minutes) / float(ACTION_CLOCK_MINUTES))))
	_advance_global_boundary_start(actions)
	_advance_global_boundary_after_encounter(actions)
	_advance_global_boundary_before_local_cooldown(actions)
	_advance_global_boundary_finish(actions)
	return actions


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
	var rollback_run := to_dict()
	var rollback_environment := current_environment.duplicate(true)
	var rollback_world_map := world_map.duplicate(true)
	var rollback_room_states := grand_casino_room_states.duplicate(true)
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
	var clock_result := advance_game_clock_minutes(minutes)
	if not bool(clock_result.get("ok", false)):
		from_dict(rollback_run)
		current_environment = rollback_environment
		world_map = rollback_world_map
		grand_casino_room_states = rollback_room_states
		return {"ok": false, "message": "Sleep could not cross the night boundary safely.", "errors": _copy_array(clock_result.get("errors", []))}
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


func transfer_item_between_home_containers(from_container_id: String, to_container_id: String, item_id: String) -> Dictionary:
	var clean_from_container_id := from_container_id.strip_edges()
	var clean_to_container_id := to_container_id.strip_edges()
	var clean_item_id := item_id.strip_edges()
	if clean_from_container_id.is_empty() or clean_to_container_id.is_empty() or clean_item_id.is_empty():
		return {"ok": false, "message": "Storage transfer is not configured."}
	if clean_from_container_id == clean_to_container_id:
		return {"ok": false, "message": "Choose another container."}
	if not is_current_home_environment():
		return {"ok": false, "message": "Home storage is not available here."}
	var containers := current_home_containers()
	var from_index := _home_container_index(containers, clean_from_container_id)
	var to_index := _home_container_index(containers, clean_to_container_id)
	if from_index < 0 or to_index < 0:
		return {"ok": false, "message": "Container is no longer available."}
	var from_container: Dictionary = containers[from_index]
	var to_container: Dictionary = containers[to_index]
	if bool(from_container.get("meta_loadout", false)):
		return {"ok": false, "message": "These items are already carried from the meta-home loadout."}
	if bool(to_container.get("meta_loadout", false)):
		return {"ok": false, "message": "Meta-home loadout bags are read-only during this run."}
	var from_items := _copy_array(from_container.get("items", []))
	var to_items := _copy_array(to_container.get("items", []))
	if not from_items.has(clean_item_id):
		return {"ok": false, "message": "That item is not stored here."}
	var to_capacity := maxi(0, int(to_container.get("capacity", 0)))
	if to_capacity > 0 and to_items.size() >= to_capacity:
		return {"ok": false, "message": "%s is full." % str(to_container.get("display_name", "Container"))}
	from_items.erase(clean_item_id)
	to_items.append(clean_item_id)
	from_container["items"] = from_items
	to_container["items"] = to_items
	containers[from_index] = from_container
	containers[to_index] = to_container
	_set_current_home_containers(containers)
	var message := "Moved %s from %s to %s." % [
		clean_item_id.replace("_", " ").capitalize(),
		str(from_container.get("display_name", "Container")),
		str(to_container.get("display_name", "Container")),
	]
	return {
		"ok": true,
		"message": message,
		"from_container_id": clean_from_container_id,
		"to_container_id": clean_to_container_id,
		"item_id": clean_item_id,
	}


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
	event_cadence_rng_create_call_count += 1
	_ensure_event_cadence()
	var rng := RngStream.new()
	rng.configure(int(event_cadence.get("rng_seed", seed_value)), int(event_cadence.get("rng_state", seed_value)))
	return rng


# Saves the cadence stream without advancing the general run RNG.
func save_event_cadence_rng(rng: RngStream) -> void:
	event_cadence_rng_save_call_count += 1
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
	var cadence_value: Variant = event_definition.get("cadence", {})
	var cadence: Dictionary = cadence_value if typeof(cadence_value) == TYPE_DICTIONARY else {}
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
	var visit_event_ids_value: Variant = event_cadence.get("visit_event_ids", [])
	var visit_event_ids: Array = visit_event_ids_value if typeof(visit_event_ids_value) == TYPE_ARRAY else []
	if visit_event_ids.has(event_id):
		return false
	return true


# Debt collectors, showdown calls, and explicit chains can jump the quiet-visit budget.
func event_cadence_event_bypasses_budget(event_id: String, trigger_type: String, source: String, event_definition: Dictionary = {}) -> bool:
	var normalized_id := event_id.strip_edges()
	var cadence_value: Variant = event_definition.get("cadence", {})
	var cadence: Dictionary = cadence_value if typeof(cadence_value) == TYPE_DICTIONARY else {}
	if bool(cadence.get("bypass_budget", false)):
		return true
	if [GRAND_CASINO_SHOWDOWN_EVENT_ID, GRAND_CASINO_HIGH_ROLLER_EVENT_ID, "the_collector", "family_loan"].has(normalized_id):
		return true
	if ["event_chain", "debt", "lender", "showdown"].has(source):
		return true
	var conditions_value: Variant = event_definition.get("conditions", {})
	var conditions: Dictionary = conditions_value if typeof(conditions_value) == TYPE_DICTIONARY else {}
	if bool(conditions.get("requires_overdue_debt", false)):
		return true
	return trigger_type == "manual" and source == "event"


# Returns lower weights for events already seen this run without forbidding them.
func event_cadence_weight_for_event(event_id: String) -> int:
	_ensure_event_cadence()
	var seen_counts_value: Variant = event_cadence.get("seen_event_counts", {})
	var seen_counts: Dictionary = seen_counts_value if typeof(seen_counts_value) == TYPE_DICTIONARY else {}
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
	# Cadence is normalized at new-run/reset and deserialization boundaries, and
	# every canonical mutator below preserves that shape. Re-normalizing here made
	# each read recursively duplicate arrays/dictionaries; an action with several
	# eligible event candidates paid that save-compatibility work dozens of times.
	# Serialization still emits a normalized copy, so older-save compatibility and
	# external snapshots retain the same defensive boundary.


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


# Read-only departure check used before callers publish facts, consume RNG, or
# move a world-map cursor. The real boundary is committed by set_environment.
func scenario_preflight_environment_change(source_id: String = "", target_id: String = "", travel_kind: String = "") -> Dictionary:
	if current_environment.is_empty(): return {"ok": true, "inactive": true, "errors": []}
	var candidate := current_environment.duplicate(true)
	var definition := _scenario_sequence_definition_readonly()
	var boundary := _scenario_environment_change_expiry_boundary()
	if not travel_kind.is_empty() and ScenarioSequenceSchemaScript.is_sequence(definition):
		if not _scenario_semantic_ready(): return {"ok": false, "errors": ["Dynamic room sequence semantic records are not finalized for departure."]}
		var state := ScenarioEngineScript.ensure_sequence_state(candidate, definition)
		if state.is_empty(): return {"ok": false, "errors": ["Dynamic room sequence departure could not initialize its causal state."]}
		var state_errors := _copy_array(state.get("errors", []))
		if str(state.get("status", "")) == ScenarioSequenceRuntimeScript.STATUS_CLEANED and not state_errors.is_empty():
			return {"ok": false, "errors": state_errors}
		var required_causes := _scenario_environment_change_required_causes(state, boundary)
		if ScenarioSequenceRuntimeScript._next_cause_ordinal(state) + _copy_array(state.get("fact_queue", [])).size() + required_causes > ScenarioSequenceRuntimeScript.MAX_RECEIPTS:
			return {"ok": false, "errors": ["scenario causal journal lifetime limit reached"]}
		if str(state.get("status", "")) == ScenarioSequenceRuntimeScript.STATUS_ACTIVE:
			var serial := maxi(1, int(state.get("fact_serial_next", 1)))
			var departure_fact := ScenarioSequenceRuntimeScript.fact(
				"travel_departed",
				"travel",
				current_world_node_id(),
				"travel:travel_departed:%d" % serial,
				serial,
				maxi(int(state.get("boundary_serial", 0)), _crew_action_index()),
				{"source_id": source_id, "target_id": target_id, "travel_kind": travel_kind}
			)
			var enqueued := ScenarioEngineScript.enqueue_sequence_fact(candidate, definition, departure_fact)
			if not bool(enqueued.get("ok", false)):
				return {"ok": false, "errors": _copy_array(enqueued.get("errors", []))}
			var flushed := ScenarioEngineScript.flush_sequence_facts(candidate, definition, _crew_action_index())
			if not bool(flushed.get("ok", false)):
				return {"ok": false, "errors": _copy_array(flushed.get("errors", []))}
	if boundary.is_empty(): return {"ok": true, "inactive": true, "errors": []}
	if not _scenario_semantic_ready(): return {"ok": false, "errors": ["Dynamic room sequence semantic records are not finalized for departure."]}
	var result := ScenarioEngineScript.sequence_apply_expiry_boundary(candidate, definition, boundary)
	return {"ok": bool(result.get("ok", false)), "inactive": false, "errors": _copy_array(result.get("errors", []))}


func _scenario_environment_change_required_causes(state: Dictionary, boundary: String) -> int:
	var required := 1 if str(state.get("status", "")) == ScenarioSequenceRuntimeScript.STATUS_ACTIVE else 0
	if not boundary.is_empty() and not bool(state.get("expired", false)):
		required += 1
	return required


func _scenario_environment_change_expiry_boundary() -> String:
	for boundary in ["leave", "visit_end"]:
		if _scenario_sequence_uses_expiry_boundary(boundary): return boundary
	return ""


# Sets the current environment and records the previous one.
func set_environment(environment_data: Dictionary, debug_timing: Dictionary = {}) -> Dictionary:
	var perf_timing_enabled := not debug_timing.is_empty()
	var perf_stage_started_usec := Time.get_ticks_usec() if perf_timing_enabled else 0
	var previous_was_grand_casino := _is_grand_casino_environment(current_environment)
	var destination_sequence_state := ScenarioSequenceRuntimeScript.normalize_state(environment_data.get("scenario_sequence_state", {}))
	var destination_is_revisit := environment_data.has("departed_game_clock_minutes") or not destination_sequence_state.is_empty() and (
		int(destination_sequence_state.get("boundary_serial", 0)) > 0
		or str(destination_sequence_state.get("status", ScenarioSequenceRuntimeScript.STATUS_ACTIVE)) != ScenarioSequenceRuntimeScript.STATUS_ACTIVE
		or not _copy_array(destination_sequence_state.get("command_receipts", [])).is_empty()
		or not _copy_array(destination_sequence_state.get("fact_receipts", [])).is_empty()
		or not _copy_array(destination_sequence_state.get("visit_receipts", [])).is_empty()
	)
	var departure_check := scenario_preflight_environment_change()
	if perf_timing_enabled:
		debug_timing["initial_preflight"] = Time.get_ticks_usec() - perf_stage_started_usec
		perf_stage_started_usec = Time.get_ticks_usec()
	if not bool(departure_check.get("ok", false)):
		return {"ok": false, "applied": false, "errors": _copy_array(departure_check.get("errors", []))}
	var departure_boundary := _scenario_environment_change_expiry_boundary()
	if not departure_boundary.is_empty():
		var expiry_result := scenario_sequence_apply_expiry_boundary(departure_boundary)
		if not bool(expiry_result.get("ok", false)):
			return {"ok": false, "applied": false, "errors": _copy_array(expiry_result.get("errors", []))}
	if not current_environment.is_empty():
		scenario_apply_expiry("leave", _crew_action_index())
		scenario_apply_expiry("visit_end", _crew_action_index())
		# Lifecycle cleanup and its receipts are authoritative source-room state.
		# Persist them before any caller can observe the destination as current.
		if is_layered_environment():
			store_current_environment_layer_state()
		if _is_grand_casino_environment(current_environment):
			store_grand_casino_room_environment(current_environment)
		store_current_world_node_environment()
		# Travel advances the clock before installing the destination, but stamps
		# the actual departure first. Preserve that boundary so the report can
		# animate the journey instead of collapsing it to a zero-length teleport.
		# Direct environment changes still close at the current clock.
		var entered_minutes := maxi(0, int(current_environment.get("entered_game_clock_minutes", game_clock_minutes)))
		var stamped_departure := int(current_environment.get("departed_game_clock_minutes", -1))
		var departed_minutes := game_clock_minutes
		if stamped_departure >= entered_minutes and stamped_departure <= game_clock_minutes:
			departed_minutes = stamped_departure
		current_environment["departed_game_clock_minutes"] = maxi(entered_minutes, departed_minutes)
		# The portable registry is canonical once an action has written it. Travel
		# may migrate a missing legacy machine pile, but must not overwrite a newer
		# portable pile with stale environment state left by a read-only preview.
		capture_portable_ticket_piles_from_environment(current_environment, true)
		_store_current_local_suspicion()
		environment_history.append(_environment_history_entry(current_environment))
		_compact_environment_history()
	if perf_timing_enabled:
		debug_timing["source_persist"] = Time.get_ticks_usec() - perf_stage_started_usec
		perf_stage_started_usec = Time.get_ticks_usec()
	current_environment = _normalize_environment(environment_data)
	if perf_timing_enabled:
		debug_timing["destination_normalize"] = Time.get_ticks_usec() - perf_stage_started_usec
		perf_stage_started_usec = Time.get_ticks_usec()
	# Fresh generated rooms have no trusted semantic inventory yet; finalization
	# initializes their sequence atomically below. Running legacy migration here
	# only reloaded and revalidated the same package before returning `pending`.
	if bool(current_environment.get("scenario_semantic_ready", false)) or current_environment.has("scenario_sequence_state") or current_environment.has("scenario_sequence_migration"):
		ScenarioEngineScript.migrate_environment_sequence(
			current_environment,
			{},
			"%d:set_environment:%s" % [seed_value, str(current_environment.get("world_node_id", current_environment.get("archetype_id", "")))]
		)
	if perf_timing_enabled:
		debug_timing["sequence_migration"] = Time.get_ticks_usec() - perf_stage_started_usec
		perf_stage_started_usec = Time.get_ticks_usec()
	# The world-map cursor advances only after this installation succeeds. Resolve
	# the destination's seed from its explicit node id, not the still-current
	# source cursor, so first entry reuses the accepted package receipt.
	var destination_node_id := str(current_environment.get("world_node_id", current_environment.get("archetype_id", ""))).strip_edges()
	var destination_definition := _seeded_scenario_definition_for_node_readonly(destination_node_id)
	if perf_timing_enabled:
		debug_timing["sequence_definition_lookup"] = Time.get_ticks_usec() - perf_stage_started_usec
		perf_stage_started_usec = Time.get_ticks_usec()
	if destination_definition.is_empty():
		destination_definition = _scenario_sequence_definition_readonly()
	var destination_sequence_value: Variant = destination_definition.get("sequence", {})
	if typeof(destination_sequence_value) == TYPE_DICTIONARY and not (destination_sequence_value as Dictionary).is_empty():
		if perf_timing_enabled:
			debug_timing["sequence_definition_presence"] = Time.get_ticks_usec() - perf_stage_started_usec
			perf_stage_started_usec = Time.get_ticks_usec()
		# V2 initialization/reentry is intentionally deferred until the controller's
		# final pre-overlay interaction record set and ContentLibrary are sealed.
		current_environment.erase("scenario_semantic_ready")
		current_environment.erase("scenario_semantic_inventory")
		current_environment.erase("scenario_base_interactions")
		current_environment.erase("scenario_base_actors")
		current_environment.erase("scenario_base_producer_context")
		current_environment.erase("scenario_semantic_action_digest")
		# Finalization creates the public visit identity and falls back to it when
		# this optional persisted migration hint is absent.
		current_environment.erase("scenario_sequence_pending_visit_id")
	if perf_timing_enabled:
		debug_timing["sequence_definition_prepare"] = Time.get_ticks_usec() - perf_stage_started_usec
		perf_stage_started_usec = Time.get_ticks_usec()
	CharacterChainModelScript.apply_to_environment(self, current_environment)
	if perf_timing_enabled:
		debug_timing["character_chain"] = Time.get_ticks_usec() - perf_stage_started_usec
		perf_stage_started_usec = Time.get_ticks_usec()
	# The Punchline's posted board is a physical source. Arriving after the post
	# reveals only the current published handle; it does not grant solo-route lore.
	if numbers_state != null and str(current_environment.get("archetype_id", "")) == "small_underground_casino":
		var posted_status := numbers_state.status()
		if bool(posted_status.get("posted", false)):
			numbers_state.reveal_number(int(posted_status.get("day", 0)), "punchline_post")
	# Stored/revisited environments may contain the boundary from their prior
	# visit. The destination is active now and must begin with an open visit.
	current_environment.erase("departed_game_clock_minutes")
	_reconcile_grand_casino_invitation_uniqueness()
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
	if destination_is_revisit:
		scenario_reenter_current(_event_cadence_visit_key(current_environment))
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
	if perf_timing_enabled:
		debug_timing["destination_models"] = Time.get_ticks_usec() - perf_stage_started_usec
	return {"ok": true, "applied": true, "errors": []}


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
		var node_id := str(current_environment.get("world_node_id", "")).strip_edges()
		return node_id if not node_id.is_empty() else str(current_environment.get("archetype_id", "")).strip_edges()
	return WorldMap.current_node_id(world_map)


# Returns compact scenario identity for a node without selecting or regenerating.
func scenario_for_node(node_id: String) -> Dictionary:
	var wanted := node_id.strip_edges()
	if wanted.is_empty():
		return {}
	var current_node := str(current_environment.get("world_node_id", "")).strip_edges()
	if current_node.is_empty():
		current_node = str(current_environment.get("archetype_id", "")).strip_edges()
	if wanted == current_node or wanted == str(current_environment.get("id", "")):
		var current_scenario := ScenarioEngineScript.public_snapshot(current_environment.get("scenario_state", {}))
		return current_scenario if not current_scenario.is_empty() else seeded_scenario_for_node(wanted)
	var nodes_value: Variant = world_map.get("nodes", [])
	if typeof(nodes_value) != TYPE_ARRAY:
		return {}
	for node_value in nodes_value as Array:
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		if str(node.get("id", "")) != wanted:
			continue
		var environment_value: Variant = node.get("environment", {})
		if typeof(environment_value) != TYPE_DICTIONARY:
			break
		var stored_scenario := ScenarioEngineScript.public_snapshot((environment_value as Dictionary).get("scenario_state", {}))
		if not stored_scenario.is_empty():
			return stored_scenario
		break
	return seeded_scenario_for_node(wanted)


# Immutable authored definition for the current node. TownState owns seeded
# identity/definition; the environment fallback exists for headless fixtures.
func scenario_sequence_definition() -> Dictionary:
	return _scenario_sequence_definition_readonly().duplicate(true)


# Trusted RunState paths consume the immutable definition without cloning the
# full authored sequence on every projection, fact, phase, and travel boundary.
func _scenario_sequence_definition_readonly() -> Dictionary:
	var node_id := current_world_node_id()
	var scenario_state_value: Variant = current_environment.get("scenario_state", {})
	var scenario_state: Dictionary = scenario_state_value as Dictionary if typeof(scenario_state_value) == TYPE_DICTIONARY else {}
	var scenario_id := str(scenario_state.get("id", current_environment.get("scenario_id", ""))).strip_edges()
	var embedded_value: Variant = current_environment.get("scenario_sequence_definition", {})
	var embedded_definition: Dictionary = embedded_value as Dictionary if typeof(embedded_value) == TYPE_DICTIONARY else {}
	if scenario_id.is_empty() and ScenarioSequenceSchemaScript.is_sequence(embedded_definition):
		scenario_id = str(embedded_definition.get("id", embedded_definition.get("scenario_id", ""))).strip_edges()
	var definition := _seeded_scenario_definition_for_node_readonly(node_id)
	if definition.is_empty():
		definition = embedded_definition
	if scenario_sequence_is_suppressed(scenario_id, str(current_environment.get("archetype_id", node_id))):
		definition = ScenarioEngineScript.suppress_sequence_definition(definition if not definition.is_empty() else {"id": scenario_id, "archetype_id": str(current_environment.get("archetype_id", node_id))})
	if not scenario_id.is_empty() and _scenario_sequence_definition_cache.has(scenario_id):
		var cached_definition := _scenario_sequence_definition_cache.get(scenario_id, {}) as Dictionary
		if definition.is_empty() or _scenario_cached_definition_matches_source(cached_definition, definition):
			return cached_definition
	var resolution_environment := current_environment
	if str(scenario_state.get("id", resolution_environment.get("scenario_id", ""))).strip_edges().is_empty() and not scenario_id.is_empty():
		resolution_environment = current_environment.duplicate(true)
		resolution_environment["scenario_id"] = scenario_id
	var resolved := ScenarioEngineScript.sequence_definition_for_environment(resolution_environment, definition)
	# Embedded/headless definitions cannot prove declared targets until the
	# environment-owned semantic inventory has been produced. They remain a
	# provisional, ingress-blocked candidate until finalization validates them
	# against that exact inventory and stamps the runtime marker below.
	if not ScenarioSequenceSchemaScript.is_sequence(resolved) and ScenarioSequenceSchemaScript.is_sequence(embedded_definition) and not bool(current_environment.get("scenario_semantic_ready", false)):
		resolved = embedded_definition
	if not scenario_id.is_empty() and bool(resolved.get(ScenarioEngineScript.VALIDATED_SEQUENCE_MARKER, false)):
		_scenario_sequence_definition_cache[scenario_id] = resolved.duplicate(true)
	return resolved


func _scenario_cached_definition_matches_source(cached: Dictionary, source: Dictionary) -> bool:
	if str(cached.get("id", cached.get("scenario_id", ""))).strip_edges() != str(source.get("id", source.get("scenario_id", ""))).strip_edges():
		return false
	if bool(cached.get(ScenarioEngineScript.SEQUENCE_SUPPRESSION_KEY, false)) != bool(source.get(ScenarioEngineScript.SEQUENCE_SUPPRESSION_KEY, false)):
		return false
	for key in ["sequence_package_id", "sequence_handler_pack", "sequence_renderer_id"]:
		if str(cached.get(key, "")) != str(source.get(key, "")):
			return false
	var cached_sequence_value: Variant = cached.get("sequence", {})
	var source_sequence_value: Variant = source.get("sequence", {})
	var cached_signature := str((cached_sequence_value as Dictionary).get("sequence_signature", "")) if typeof(cached_sequence_value) == TYPE_DICTIONARY else ""
	var source_signature := str((source_sequence_value as Dictionary).get("sequence_signature", "")) if typeof(source_sequence_value) == TYPE_DICTIONARY else ""
	return not cached_signature.is_empty() and cached_signature == source_signature


func scenario_definition_cache_snapshot() -> Dictionary:
	return _scenario_sequence_definition_cache.duplicate(true)


func restore_scenario_definition_cache(snapshot: Dictionary) -> void:
	_scenario_sequence_definition_cache = snapshot.duplicate(true)


# Registers an owner request for a future public node. This is boundary-driven:
# the definition is not mounted and no environment registration marker exists
# until the exact target room has a sealed semantic inventory.

# The caller names only a trusted package and compares the public delivery
# instance/target it just received. Source, definition, channels, claims, mount
# zone and seed authority are all resolved again from trusted live state here.
func world_sequence_schedule_mount(package_id: String, public_instance_token: String, node_id_value: String) -> Dictionary:
	var entry := WorldSequencePackageCatalogScript.entry(package_id)
	if entry.is_empty():
		return {"ok": false, "owner_token": "", "errors": ["registered world sequence package is unavailable"]}
	var delivery := DeliveryRunModelScript.snapshot(active_delivery_run)
	var trusted_instance := str(delivery.get("job_id", "")).strip_edges()
	if trusted_instance.is_empty(): trusted_instance = str(delivery.get("run_id", "")).strip_edges()
	var targets := _copy_array(delivery.get("targets", []))
	var trusted_node := str(_copy_dict(targets[0]).get("node_id", "")).strip_edges() if targets.size() == 1 else ""
	if trusted_instance.is_empty() or trusted_instance != public_instance_token or trusted_node.is_empty() or trusted_node != node_id_value:
		return {"ok": false, "owner_token": "", "errors": ["world sequence schedule does not match the live delivery registration"]}
	return _world_sequence_register_trusted_entry(entry, trusted_instance, trusted_node)


# Heist presentation packages are selected only from the live private host
# state. Callers cannot name a package, plan, phase, node or public instance.
func world_sequence_schedule_heist_mount(action: String, host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability:
		return {"ok": false, "errors": ["heist sequence host capability rejected"]}
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	var plan_id := str(state.get("plan_id", ""))
	var status := str(state.get("status", ""))
	var package_id := ""
	if action == "observe_table": package_id = "world06_6_quiet_clue"
	elif action in ["confront", "hedge"]: package_id = "world06_6_closed_door"
	elif plan_id == CrewHeistModelScript.PLAN_COUNT:
		package_id = {CrewHeistModelScript.STATUS_SETUP: "world06_6_count_setup", CrewHeistModelScript.STATUS_PLAY: "world06_6_count_play", CrewHeistModelScript.STATUS_GETAWAY: "world06_6_count_getaway"}.get(status, "")
	elif plan_id == CrewHeistModelScript.PLAN_WHALE:
		package_id = {CrewHeistModelScript.STATUS_SETUP: "world06_6_whale_setup", CrewHeistModelScript.STATUS_PLAY: "world06_6_whale_play", CrewHeistModelScript.STATUS_INTERVIEW: "world06_6_whale_interview", CrewHeistModelScript.STATUS_GETAWAY: "world06_6_whale_getaway"}.get(status, "")
	var active_heist_tokens: Array = []
	var heist_registration_count := 0
	for token_value in world_sequence_registrations.keys():
		var registration := _copy_dict(world_sequence_registrations.get(token_value, {}))
		if not str(_copy_dict(registration.get("source", {})).get("definition_id", "")).begins_with("heist_"): continue
		heist_registration_count += 1
		if str(registration.get("lifecycle", "")) in ["eligible", "mounted"]: active_heist_tokens.append(str(token_value))
	for token in active_heist_tokens:
		var cleanup := world_sequence_unmount(token, "owner_phase_changed")
		if not bool(cleanup.get("ok", false)): return cleanup
	if package_id.is_empty(): return {"ok": true, "inactive": true, "errors": []}
	var entry := WorldSequencePackageCatalogScript.entry(package_id)
	var node_id := current_world_node_id().strip_edges()
	var public_instance := "heist_scene:%d:%d:%s" % [int(state.get("locked_action", 0)), _crew_action_index(), package_id]
	var token := CrewWorldSequenceAdapterScript.owner_token(_copy_dict(entry.get("source", {})), public_instance)
	if entry.is_empty() or node_id.is_empty(): return {"ok": false, "errors": ["live heist sequence package or node is unavailable"]}
	if not world_sequence_registrations.has(token) and heist_registration_count >= CrewHeistModelScript.TOMBSTONE_LIMIT:
		return {"ok": false, "errors": ["heist sequence registration bound reached"]}
	return _world_sequence_register_trusted_entry(entry, public_instance, node_id)


func _world_sequence_register_trusted_entry(entry: Dictionary, public_instance_token: String, node_id: String) -> Dictionary:
	var source := _copy_dict(entry.get("source", {}))
	var definition := _copy_dict(entry.get("definition", {}))
	var outcome_channels := _copy_dict(entry.get("outcome_channels", {}))
	var ownership_claims := _copy_array(entry.get("ownership_claims", []))
	var authored_mount := _copy_dict(entry.get("mount", {}))
	var mount_selector := {"node_id": node_id, "zone_id": str(authored_mount.get("zone_id", "")).strip_edges()}
	var seed_token := "world_sequence:%s" % public_instance_token
	var token := CrewWorldSequenceAdapterScript.owner_token(source, public_instance_token)
	var errors: Array = []
	if token.is_empty(): errors.append("world sequence registration source or public instance token is invalid")
	if node_id.is_empty() or node_id != node_id.strip_edges(): errors.append("world sequence registration requires an exact public target node")
	if not ScenarioSequenceSchemaScript.is_sequence(definition): errors.append("world sequence registration requires an env06_6 sequence definition")
	if str(source.get("definition_id", "")) != str(definition.get("id", "")): errors.append("world sequence registration source does not match definition id")
	if seed_token.length() > ScenarioOperationRegistryScript.MAX_VARIANT_TEXT: errors.append("world sequence registration seed token exceeds its bound")
	if not errors.is_empty(): return {"ok": false, "owner_token": token, "errors": errors}
	var fingerprint := ScenarioSequenceRuntimeScript.content_fingerprint(definition)
	if world_sequence_registrations.has(token):
		var existing := _copy_dict(world_sequence_registrations.get(token, {}))
		if str(existing.get("definition_fingerprint", "")) != fingerprint or str(existing.get("node_id", "")) != node_id:
			return {"ok": false, "owner_token": token, "errors": ["world sequence registration token was reused for different content or node"]}
		_world_sequence_definition_cache[token] = definition.duplicate(true)
		return {"ok": true, "replayed": true, "owner_token": token, "lifecycle": str(existing.get("lifecycle", "eligible")), "errors": []}
	world_sequence_registrations[token] = {
		"schema_version": CrewWorldSequenceAdapterScript.REGISTRATION_SCHEMA_VERSION,
		"owner_token": token,
		"source": source.duplicate(true),
		"public_instance_token": public_instance_token,
		"node_id": node_id,
		"mount_selector": mount_selector.duplicate(true),
		"definition": definition.duplicate(true),
		"definition_fingerprint": fingerprint,
		"outcome_channels": outcome_channels.duplicate(true),
		"ownership_claims": ownership_claims.duplicate(true),
		"seed_token": seed_token,
		"lifecycle": "eligible",
		"pending_outcomes": [],
		"owner_outcome_results": {},
		"outcome_acknowledgements": {},
	}
	_world_sequence_definition_cache[token] = definition.duplicate(true)
	return {"ok": true, "replayed": false, "owner_token": token, "lifecycle": "eligible", "errors": []}


# Called after semantic finalization/arrival. Empty registration state returns
# immediately, preserving the crew-ignoring no-scan contract.
func world_sequence_activate_current_mounts() -> Dictionary:
	if world_sequence_registrations.is_empty(): return {"ok": true, "inactive": true, "mounted": [], "errors": []}
	if not bool(current_environment.get("scenario_semantic_ready", false)):
		return {"ok": true, "pending": true, "mounted": [], "errors": []}
	var node_id := current_world_node_id()
	var mounted: Array = []
	var errors: Array = []
	var tokens := world_sequence_registrations.keys()
	tokens.sort()
	for token_value in tokens:
		var token := str(token_value)
		var registration := _copy_dict(world_sequence_registrations.get(token, {}))
		if str(registration.get("node_id", "")) != node_id or not ["eligible", "mounted"].has(str(registration.get("lifecycle", ""))): continue
		var definition := _copy_dict(_world_sequence_definition_cache.get(token, registration.get("definition", {})))
		var result := CrewWorldSequenceAdapterScript.mount(
			current_environment,
			_copy_dict(registration.get("source", {})),
			str(registration.get("public_instance_token", "")),
			_copy_dict(registration.get("mount_selector", {})),
			definition,
			_copy_dict(registration.get("outcome_channels", {})),
			_copy_array(registration.get("ownership_claims", [])),
			WORLD_SEQUENCE_OUTCOME_CHANNELS,
			str(registration.get("seed_token", ""))
		)
		if not bool(result.get("ok", false)):
			errors.append_array(_copy_array(result.get("errors", [])))
			continue
		registration["lifecycle"] = "mounted"
		registration["registration_marker"] = str(result.get("registration_marker", ""))
		world_sequence_registrations[token] = registration
		_refresh_world_sequence_registration(token)
		_world_sequence_definition_cache[token] = definition.duplicate(true)
		mounted.append(token)
	return {"ok": errors.is_empty(), "mounted": mounted, "errors": errors}


func world_sequence_snapshot(token: String) -> Dictionary:
	if token == CrewWorldSequenceAdapterScript.RESERVED_ENVIRONMENT_OWNER_TOKEN:
		return {
			"owner_token": token,
			"source": {"domain": "environment", "owner_id": "environment", "definition_id": str(scenario_sequence_definition().get("id", ""))},
			"lifecycle": "active" if scenario_sequence_present() else "inactive",
			"projection": scenario_sequence_projection(),
		}
	return CrewWorldSequenceAdapterScript.snapshot(current_environment, token, _world_sequence_definition(token))


func world_sequence_projection(token: String) -> Dictionary:
	if token == CrewWorldSequenceAdapterScript.RESERVED_ENVIRONMENT_OWNER_TOKEN: return scenario_sequence_projection()
	return CrewWorldSequenceAdapterScript.projection(current_environment, token, _world_sequence_definition(token))


func world_sequence_mounted_owner_for_channel(channel_id: String, node_id: String = "") -> String:
	if world_sequence_registrations.is_empty(): return ""
	var exact_node := node_id.strip_edges()
	if exact_node.is_empty(): exact_node = current_world_node_id()
	var tokens := world_sequence_registrations.keys()
	tokens.sort()
	for token_value in tokens:
		var token := str(token_value)
		var registration := _copy_dict(world_sequence_registrations.get(token, {}))
		if str(registration.get("node_id", "")) != exact_node or str(registration.get("lifecycle", "")) not in ["mounted", "cleanup_pending"]: continue
		if not _copy_dict(registration.get("outcome_channels", {})).values().has(channel_id): continue
		if _copy_dict(_copy_dict(current_environment.get(CrewWorldSequenceAdapterScript.CONTAINER_KEY, {})).get(token, {})).is_empty(): continue
		return token
	return ""


func world_sequence_owner_for_public_instance(channel_id: String, public_instance_token: String) -> String:
	if world_sequence_registrations.is_empty(): return ""
	var exact_instance := public_instance_token.strip_edges()
	if exact_instance.is_empty(): return ""
	var tokens := world_sequence_registrations.keys()
	tokens.sort()
	for token_value in tokens:
		var token := str(token_value)
		var registration := _copy_dict(world_sequence_registrations.get(token, {}))
		if str(registration.get("public_instance_token", "")) != exact_instance: continue
		if str(registration.get("lifecycle", "")) not in ["eligible", "mounted", "cleanup_pending"]: continue
		if not _copy_dict(registration.get("outcome_channels", {})).values().has(channel_id): continue
		return token
	return ""


func world_sequence_composed_projection() -> Dictionary:
	return CrewWorldSequenceAdapterScript.composed_projection(current_environment, _world_sequence_definition_cache, scenario_sequence_projection())


func world_sequence_execute(token: String, command: Dictionary, public_context: Dictionary = {}) -> Dictionary:
	var result := CrewWorldSequenceAdapterScript.execute(current_environment, token, _world_sequence_definition(token), command, public_context)
	if bool(result.get("ok", false)): _refresh_world_sequence_registration(token)
	return result


func world_sequence_command(token: String, command_id: String, idempotency_key: String, payload: Dictionary = {}, owner_namespace: String = "crew", stable_object_id: String = "sequence", host_interaction_availability: Dictionary = {}, action_origin_owner_namespace: String = "", action_origin_stable_object_id: String = "", action_origin_receipt_key: String = "", action_origin_boundary_id: String = "", action_origin_fingerprint: String = "") -> Dictionary:
	var definition := _world_sequence_definition(token)
	var projection := world_sequence_projection(token)
	if definition.is_empty() or projection.is_empty(): return {"ok": false, "errors": ["World sequence is not mounted and finalized."]}
	var state := _copy_dict(_copy_dict(_copy_dict(current_environment.get(CrewWorldSequenceAdapterScript.CONTAINER_KEY, {})).get(token, {})).get("state", {}))
	var expected_phase := str(projection.get("phase_id", ""))
	for record_value in _copy_array(state.get("command_receipt_records", [])):
		var record := _copy_dict(record_value)
		if str(record.get("receipt_key", "")) == idempotency_key:
			expected_phase = str(_copy_dict(record.get("envelope", {})).get("expected_phase", expected_phase))
			break
	var command := ScenarioSequenceRuntimeScript.command(command_id, current_world_node_id(), expected_phase, idempotency_key, payload, owner_namespace, stable_object_id, action_origin_owner_namespace, action_origin_stable_object_id, action_origin_receipt_key, action_origin_boundary_id, action_origin_fingerprint)
	var candidate := current_environment.duplicate(true)
	var result := CrewWorldSequenceAdapterScript.execute(candidate, token, definition, command, {"available_funds": bankroll, "host_interaction_availability": host_interaction_availability})
	if not bool(result.get("ok", false)): return result
	var cost := 0 if bool(result.get("replayed", false)) else maxi(0, int(result.get("cost", 0)))
	if cost > bankroll: return {"ok": false, "errors": ["world sequence command cost is not payable"], "cost": 0}
	bankroll -= cost
	current_environment = candidate
	_refresh_world_sequence_registration(token)
	result["cost"] = cost
	result["bankroll_delta"] = -cost
	result["bankroll_after"] = bankroll
	return result


func world_sequence_enqueue_fact(token: String, fact: Dictionary) -> Dictionary:
	var result := CrewWorldSequenceAdapterScript.enqueue_fact(current_environment, token, _world_sequence_definition(token), fact)
	if bool(result.get("ok", false)): _refresh_world_sequence_registration(token)
	return result


func world_sequence_flush_facts(token: String, boundary_serial: int) -> Dictionary:
	var result := CrewWorldSequenceAdapterScript.flush_facts(current_environment, token, _world_sequence_definition(token), boundary_serial)
	if bool(result.get("ok", false)): _refresh_world_sequence_registration(token)
	return result


func world_sequence_record_visit(token: String, visit_id: String = "") -> Dictionary:
	var exact_visit := visit_id.strip_edges()
	if exact_visit.is_empty(): exact_visit = str(current_environment.get("environment_visit_id", ""))
	var result := CrewWorldSequenceAdapterScript.record_visit(current_environment, token, _world_sequence_definition(token), exact_visit)
	if bool(result.get("ok", false)): _refresh_world_sequence_registration(token)
	return result


func world_sequence_apply_reentry(token: String, visit_id: String = "") -> Dictionary:
	var exact_visit := visit_id.strip_edges()
	if exact_visit.is_empty(): exact_visit = str(current_environment.get("environment_visit_id", ""))
	var result := CrewWorldSequenceAdapterScript.apply_reentry(current_environment, token, _world_sequence_definition(token), exact_visit)
	if bool(result.get("ok", false)): _refresh_world_sequence_registration(token)
	return result


func world_sequence_apply_expiry(token: String, boundary: String, amount: int = 1) -> Dictionary:
	var result := CrewWorldSequenceAdapterScript.apply_expiry_boundary(current_environment, token, _world_sequence_definition(token), boundary, amount)
	if bool(result.get("ok", false)): _refresh_world_sequence_registration(token)
	return result


func world_sequence_sync_owner(token: String, owner_active: bool, reason: String = "owner_ended") -> Dictionary:
	var registration := _copy_dict(world_sequence_registrations.get(token, {}))
	if registration.is_empty(): return {"ok": true, "inactive": true, "errors": []}
	if not owner_active and str(registration.get("lifecycle", "")) == "cleaned": return {"ok": true, "replayed": true, "errors": []}
	if not owner_active and str(registration.get("lifecycle", "")) == "eligible":
		registration["lifecycle"] = "cleaned"
		world_sequence_registrations[token] = registration
		return {"ok": true, "cancelled_pending": true, "errors": []}
	var result := CrewWorldSequenceAdapterScript.sync_owner(current_environment, token, _world_sequence_definition(token), owner_active, reason)
	if bool(result.get("ok", false)) and not owner_active:
		_refresh_world_sequence_registration(token)
		registration = _copy_dict(world_sequence_registrations.get(token, registration))
		if str(registration.get("lifecycle", "")) == "cleaned":
			registration["pending_outcomes"] = []
			registration["owner_outcome_results"] = {}
			world_sequence_registrations[token] = registration
	return result


func world_sequence_unmount(token: String, reason: String = "abandoned") -> Dictionary:
	return world_sequence_sync_owner(token, false, reason)


func world_sequence_pending_outcomes(token: String) -> Array:
	_refresh_world_sequence_registration(token)
	return _copy_array(_copy_dict(world_sequence_registrations.get(token, {})).get("pending_outcomes", []))


func world_sequence_pending_owner_tokens() -> Array:
	var result: Array = []
	var tokens := world_sequence_registrations.keys()
	tokens.sort()
	for token_value in tokens:
		var token := str(token_value)
		var registration := _copy_dict(world_sequence_registrations.get(token, {}))
		if not _copy_array(registration.get("pending_outcomes", [])).is_empty() or not _copy_dict(registration.get("owner_outcome_results", {})).is_empty():
			result.append(token)
	return result


func world_sequence_ack_outcome(token: String, receipt_id: String, public_result: Dictionary) -> Dictionary:
	var result := CrewWorldSequenceAdapterScript.acknowledge_outcome(current_environment, token, receipt_id, public_result)
	if bool(result.get("ok", false)) and world_sequence_registrations.has(token):
		# The durable work item remains pending until cleanup succeeds, even though
		# the room-local adapter now reports the receipt as acknowledged.
		_refresh_world_sequence_registration(token)
	return result


# Completes one neutral delivery outcome as a persisted three-stage transaction:
# owner consequence, acknowledgement, then cleanup. Once the consequence has
# produced its public result, retries reuse that result and never reissue either
# the sequence command or the delivery mutation.
func world_sequence_consume_delivery_outcome(token: String, receipt_id: String, node_id: String = "") -> Dictionary:
	var registration := _copy_dict(world_sequence_registrations.get(token, {}))
	if registration.is_empty(): return {"ok": false, "errors": ["world sequence outcome registration is missing"]}
	var receipt: Dictionary = {}
	for receipt_value in _copy_array(registration.get("pending_outcomes", [])):
		var candidate := _copy_dict(receipt_value)
		if str(candidate.get("receipt_id", "")) == receipt_id:
			receipt = candidate
			break
	if receipt.is_empty(): return {"ok": false, "errors": ["world sequence pending outcome receipt is missing"]}
	if str(receipt.get("channel_id", "")) != "delivery_handoff":
		return {"ok": false, "errors": ["world sequence outcome is not routed to delivery_handoff"]}
	var checkpoint_errors := DeliveryRunModelScript.closed_checkpoint_errors(active_delivery_run, _world_sequence_delivery_binding(receipt))
	if not checkpoint_errors.is_empty(): return {"ok": false, "errors": checkpoint_errors}
	var checkpoint := DeliveryRunModelScript.closed_checkpoint(active_delivery_run)
	var public_result := _copy_dict(checkpoint.get("public_result", {}))
	var owner_results := _copy_dict(registration.get("owner_outcome_results", {}))
	if owner_results.has(receipt_id) and _copy_dict(owner_results.get(receipt_id, {})) != public_result:
		return {"ok": false, "errors": ["world sequence delivery result checkpoint conflicts with registration"]}
	owner_results[receipt_id] = public_result.duplicate(true)
	registration["owner_outcome_results"] = owner_results
	world_sequence_registrations[token] = registration
	var acknowledgement := world_sequence_ack_outcome(token, receipt_id, public_result)
	if not bool(acknowledgement.get("ok", false)):
		return {"ok": false, "errors": _copy_array(acknowledgement.get("errors", ["World sequence outcome acknowledgement failed."]))}
	var cleanup := world_sequence_sync_owner(token, false, "owner_ended")
	if not bool(cleanup.get("ok", false)):
		return {"ok": false, "errors": _copy_array(cleanup.get("errors", ["World sequence cleanup failed."]))}
	return {"ok": true, "message": str(public_result.get("message", "")), "public_result": public_result, "errors": []}


func _world_sequence_delivery_binding(receipt: Dictionary) -> Dictionary:
	return {
		"owner_token": str(receipt.get("owner_token", "")),
		"public_instance_token": str(receipt.get("public_instance_token", "")),
		"outcome_receipt_id": str(receipt.get("receipt_id", "")),
		"outcome_receipt_fingerprint": str(receipt.get("receipt_fingerprint", "")),
		"outcome_cause_fingerprint": str(receipt.get("cause_fingerprint", "")),
	}


func _world_sequence_delivery_owner_cause(token: String, outcome: String) -> Dictionary:
	if outcome not in ["expired", "abandoned"]: return {}
	return {
		"schema_version": 1,
		"owner_token": token,
		"public_instance_token": str(_copy_dict(world_sequence_registrations.get(token, {})).get("public_instance_token", "")),
		"outcome": outcome,
		"delivery_resolution_fingerprint": ScenarioSequenceRuntimeScript.content_fingerprint(_copy_dict(active_delivery_run.get("resolution", {}))),
	}


func _delivery_checkpoint_outcome() -> String:
	var resolution := _copy_dict(active_delivery_run.get("resolution", {}))
	if str(resolution.get("outcome", "")) == "success": return "delivered"
	return "abandoned" if str(resolution.get("reason", "")) == "abandoned" else "expired"


func _refresh_world_sequence_registration(token: String, preserve_pending: bool = true) -> void:
	if not world_sequence_registrations.has(token): return
	var snapshot := CrewWorldSequenceAdapterScript.snapshot(current_environment, token, _world_sequence_definition(token))
	if snapshot.is_empty(): return
	var registration := _copy_dict(world_sequence_registrations.get(token, {}))
	var adapter_lifecycle := str(snapshot.get("lifecycle", ""))
	# The adapter's live `active` state corresponds to the registration's public
	# `mounted` state; terminal lifecycle names are shared verbatim.
	registration["lifecycle"] = "mounted" if adapter_lifecycle == "active" else adapter_lifecycle if not adapter_lifecycle.is_empty() else str(registration.get("lifecycle", "mounted"))
	registration["outcome_acknowledgements"] = _copy_dict(snapshot.get("outcome_acknowledgements", {}))
	var live_pending := CrewWorldSequenceAdapterScript.pending_outcomes(current_environment, token)
	if not live_pending.is_empty() or not preserve_pending:
		registration["pending_outcomes"] = live_pending.duplicate(true)
	world_sequence_registrations[token] = registration


func _world_sequence_definition(token: String) -> Dictionary:
	if _world_sequence_definition_cache.has(token): return _copy_dict(_world_sequence_definition_cache.get(token, {}))
	var registration := _copy_dict(world_sequence_registrations.get(token, {}))
	var definition := _copy_dict(registration.get("definition", {}))
	if not definition.is_empty(): _world_sequence_definition_cache[token] = definition.duplicate(true)
	return definition


static func _normalize_world_sequence_registrations(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY or not ScenarioOperationRegistryScript.validate_bounded_variant("persisted world sequence registrations", value).is_empty(): return result
	for token_value in (value as Dictionary).keys():
		var token := str(token_value)
		var registration := _copy_dict((value as Dictionary).get(token_value, {}))
		var source := _copy_dict(registration.get("source", {}))
		var definition := _copy_dict(registration.get("definition", {}))
		var public_instance_token := str(registration.get("public_instance_token", ""))
		if CrewWorldSequenceAdapterScript.owner_token(source, public_instance_token) != token: continue
		if not ScenarioSequenceSchemaScript.is_sequence(definition): continue
		if str(registration.get("definition_fingerprint", "")) != ScenarioSequenceRuntimeScript.content_fingerprint(definition): continue
		if str(registration.get("lifecycle", "")) not in ["eligible", "mounted", "cleanup_pending", "cleaned"]: continue
		if str(registration.get("node_id", "")).strip_edges().is_empty(): continue
		registration["pending_outcomes"] = _copy_array(registration.get("pending_outcomes", []))
		registration["owner_outcome_results"] = _copy_dict(registration.get("owner_outcome_results", {}))
		registration["outcome_acknowledgements"] = _copy_dict(registration.get("outcome_acknowledgements", {}))
		result[token] = registration
	return result


func scenario_sequence_is_suppressed(scenario_id: String, archetype_id: String = "") -> bool:
	var modifiers := _copy_dict(challenge_config.get("modifiers", {}))
	if bool(modifiers.get("scenario_pins_apply_mutations", true)):
		return false
	var clean_archetype := archetype_id.strip_edges()
	if clean_archetype.is_empty():
		clean_archetype = str(current_environment.get("archetype_id", current_world_node_id())).strip_edges()
	return not clean_archetype.is_empty() and str(_copy_dict(modifiers.get("scenario_pins", {})).get(clean_archetype, "")).strip_edges() == scenario_id.strip_edges()


func scenario_prepare_semantic_finalization() -> Dictionary:
	_ensure_scenario_host_public_context()
	var definition := _scenario_sequence_definition_readonly()
	if not ScenarioSequenceSchemaScript.is_sequence(definition): return {"ok": true, "inactive": true, "errors": []}
	return {"ok": true, "errors": []}


func world_sequence_prepare_semantic_finalization() -> Dictionary:
	if world_sequence_registrations.is_empty(): return {"ok": true, "inactive": true, "errors": []}
	var node_id := current_world_node_id()
	for registration_value in world_sequence_registrations.values():
		var registration := _copy_dict(registration_value)
		if str(registration.get("node_id", "")) == node_id and str(registration.get("lifecycle", "")) in ["eligible", "mounted"]:
			_ensure_scenario_host_public_context()
			return {"ok": true, "active": true, "errors": []}
	return {"ok": true, "inactive": true, "errors": []}


# Produces the same sealed host inventory for a crew/world-only room. This is
# used only at the normal interaction-list boundary when a persisted matching
# registration exists; an ignored run remains a constant-time empty check.
func world_sequence_finalize_base_semantics(interactable_records: Array, library: ContentLibrary, layout_context: Dictionary = {}) -> Dictionary:
	var preparation := world_sequence_prepare_semantic_finalization()
	if bool(preparation.get("inactive", false)): return preparation
	if library == null: return {"ok": false, "errors": ["World sequence semantic finalization requires ContentLibrary."]}
	var producer_context := _scenario_base_producer_context()
	var stamped := EnvironmentBaseSemanticRecordsScript.stamp_interactable_records(interactable_records, current_environment, library, producer_context)
	if not bool(stamped.get("ok", false)): return {"ok": false, "errors": _copy_array(stamped.get("errors", []))}
	var stamped_records := _copy_array(stamped.get("records", []))
	var produced := EnvironmentBaseSemanticRecordsScript.from_interactable_records(stamped_records)
	if not bool(produced.get("ok", false)): return {"ok": false, "errors": _copy_array(produced.get("errors", []))}
	var interactions := _copy_array(produced.get("interactions", []))
	var dynamic_actors := EnvironmentBaseSemanticRecordsScript.authorized_dynamic_actor_records(current_environment, library)
	if not bool(dynamic_actors.get("ok", false)): return {"ok": false, "errors": _copy_array(dynamic_actors.get("errors", []))}
	var actors := _copy_array(produced.get("actors", []))
	actors.append_array(_copy_array(dynamic_actors.get("records", [])))
	var semantic_environment := current_environment.duplicate(true)
	semantic_environment["scenario_base_producer_context"] = producer_context.duplicate(true)
	var sealed := EnvironmentSemanticInventoryScript.for_instance(semantic_environment, library, interactions, actors)
	var inventory_errors := EnvironmentSemanticInventoryScript.validate(sealed)
	if not inventory_errors.is_empty(): return {"ok": false, "errors": inventory_errors}
	var candidate := current_environment.duplicate(true)
	candidate["scenario_base_interactions"] = interactions
	candidate["scenario_base_actors"] = actors
	candidate["scenario_base_producer_context"] = producer_context.duplicate(true)
	candidate["scenario_semantic_action_digest"] = ScenarioSequenceRuntimeScript.base_interaction_action_authority_digest(interactions)
	candidate["scenario_semantic_inventory"] = sealed
	candidate["scenario_semantic_inventory_version"] = int(sealed.get("schema_version", 0))
	candidate["scenario_semantic_digest"] = str(sealed.get("digest", ""))
	candidate["scenario_semantic_ready"] = true
	candidate["scenario_event_choices"] = EnvironmentSemanticInventoryScript.event_choice_index(_copy_array(candidate.get("event_ids", [])), library)
	candidate["scenario_layout_base_records"] = stamped_records.duplicate(true)
	candidate["scenario_layout_context"] = layout_context.duplicate(true)
	current_environment = candidate
	var activation := world_sequence_activate_current_mounts()
	if not bool(activation.get("ok", false)): return {"ok": false, "errors": _copy_array(activation.get("errors", []))}
	var composed := _resolve_world_sequence_composed_layout(stamped_records, layout_context)
	if not bool(composed.get("ok", false)): return composed
	composed["world_sequences"] = activation
	composed["records"] = stamped_records
	composed["state"] = {}
	return composed


func scenario_finalize_installed_environment(library: ContentLibrary, layout_context: Dictionary = {}) -> Dictionary:
	var definition := _scenario_sequence_definition_readonly()
	if not ScenarioSequenceSchemaScript.is_sequence(definition):
		return {"ok": true, "inactive": true, "errors": []}
	var authoritative_environment := _scenario_terminal_authoritative_environment(definition)
	var authoritative := EnvironmentBaseSemanticRecordsScript.authoritative_interactable_records(authoritative_environment, library)
	if not bool(authoritative.get("ok", false)):
		return _scenario_semantic_finalization_failure(_copy_array(authoritative.get("errors", [])), bool(current_environment.get("scenario_semantic_ready", false)))
	return _scenario_finalize_trusted_base_semantics(_copy_array(authoritative.get("records", [])), library, layout_context)


func _scenario_terminal_authoritative_environment(definition: Dictionary) -> Dictionary:
	if not _scenario_terminal_semantic_refresh(definition):
		return current_environment
	var result := current_environment.duplicate(true)
	var layout := _copy_dict(result.get("layout", {}))
	var object_rects := _copy_dict(layout.get("object_rects", {}))
	var semantic := _copy_dict(_copy_dict(result.get("scenario_sequence_state", {})).get("semantic_state", {}))
	for service_value in _copy_dict(semantic.get("services", {})).values():
		var service := _copy_dict(service_value)
		if str(service.get("owner_namespace", "")) != "scenario" or bool(service.get("enabled", true)):
			continue
		var service_id := str(service.get("id", service.get("stable_object_id", ""))).strip_edges()
		if not service_id.is_empty():
			object_rects.erase("service:%s" % service_id)
	layout["object_rects"] = object_rects
	result["layout"] = layout
	return result


func scenario_finalize_base_semantics(interactable_records: Array, library: ContentLibrary, layout_context: Dictionary = {}) -> Dictionary:
	# Explicit host/test seam. Production generation and refresh call
	# scenario_finalize_installed_environment(), whose records come only from the
	# installed environment plus trusted ContentLibrary. Presentation callers do
	# not route through this seam.
	return _scenario_finalize_trusted_base_semantics(interactable_records, library, layout_context)


func _scenario_finalize_trusted_base_semantics(trusted_records: Array, library: ContentLibrary, layout_context: Dictionary = {}) -> Dictionary:
	_ensure_scenario_host_public_context()
	var definition := _scenario_sequence_definition_readonly()
	if not ScenarioSequenceSchemaScript.is_sequence(definition): return {"ok": true, "inactive": true, "errors": []}
	var refresh_attempt := bool(current_environment.get("scenario_semantic_ready", false))
	if library == null: return _scenario_semantic_finalization_failure(["Scenario semantic finalization requires ContentLibrary."], refresh_attempt)
	var producer_context := _scenario_base_producer_context()
	var stamped := EnvironmentBaseSemanticRecordsScript.stamp_interactable_records(trusted_records, current_environment, library, producer_context)
	if not bool(stamped.get("ok", false)): return _scenario_semantic_finalization_failure(_copy_array(stamped.get("errors", [])), refresh_attempt)
	var stamped_records := _copy_array(stamped.get("records", []))
	var produced := EnvironmentBaseSemanticRecordsScript.from_interactable_records(stamped_records)
	if not bool(produced.get("ok", false)): return _scenario_semantic_finalization_failure(_copy_array(produced.get("errors", [])), refresh_attempt)
	var interactions := _scenario_declared_base_records(_copy_array(produced.get("interactions", [])), definition, ["interactions", "scene_objects"])
	interactions = _scenario_terminal_semantic_interactions(interactions, definition)
	stamped_records = _scenario_terminal_layout_base_records(stamped_records, interactions, definition)
	var dynamic_actors := EnvironmentBaseSemanticRecordsScript.authorized_dynamic_actor_records(current_environment, library)
	if not bool(dynamic_actors.get("ok", false)): return _scenario_semantic_finalization_failure(_copy_array(dynamic_actors.get("errors", [])), refresh_attempt)
	var actors := _copy_array(produced.get("actors", []))
	actors.append_array(_copy_array(dynamic_actors.get("records", [])))
	actors = _scenario_declared_base_records(actors, definition, ["actors"])
	var action_digest := ScenarioSequenceRuntimeScript.base_interaction_action_authority_digest(interactions)
	var semantic_environment := current_environment.duplicate(true)
	semantic_environment["scenario_base_producer_context"] = producer_context.duplicate(true)
	if current_environment.has("scenario_sequence_base_game_ids"):
		semantic_environment["game_ids"] = _copy_array(current_environment.get("scenario_sequence_base_game_ids", []))
	if current_environment.has("scenario_sequence_base_service_ids"):
		semantic_environment["service_ids"] = _copy_array(current_environment.get("scenario_sequence_base_service_ids", []))
	if current_environment.has("scenario_sequence_base_travel_hooks"):
		semantic_environment["travel_hooks"] = _copy_array(current_environment.get("scenario_sequence_base_travel_hooks", []))
	if current_environment.has("scenario_sequence_base_layout_object_rects"):
		var semantic_layout := _copy_dict(semantic_environment.get("layout", {}))
		semantic_layout["object_rects"] = _copy_dict(current_environment.get("scenario_sequence_base_layout_object_rects", {}))
		semantic_environment["layout"] = semantic_layout
	var terminal_refresh := refresh_attempt and _scenario_terminal_semantic_refresh(definition)
	var sealed := _copy_dict(current_environment.get("scenario_semantic_inventory", {})) if terminal_refresh else EnvironmentSemanticInventoryScript.for_instance(semantic_environment, library, interactions, actors)
	var inventory_errors := EnvironmentSemanticInventoryScript.validate(sealed)
	if not inventory_errors.is_empty(): return _scenario_semantic_finalization_failure(inventory_errors, refresh_attempt)
	if not bool(definition.get(ScenarioEngineScript.VALIDATED_SEQUENCE_MARKER, false)):
		var validation_inventory := EnvironmentSemanticInventoryScript.exact_collections(sealed)
		validation_inventory["event_choices"] = EnvironmentSemanticInventoryScript.event_choice_index(_copy_array(current_environment.get("event_ids", [])), library)
		var definition_errors := ScenarioSequenceSchemaScript.validate_definition(definition, ScenarioOperationRegistryScript, validation_inventory)
		if not definition_errors.is_empty(): return _scenario_semantic_finalization_failure(definition_errors, refresh_attempt)
		definition[ScenarioEngineScript.VALIDATED_SEQUENCE_MARKER] = true
	var definition_id := str(definition.get("id", definition.get("scenario_id", ""))).strip_edges()
	var next_version := int(sealed.get("schema_version", 0))
	var next_digest := str(sealed.get("digest", ""))
	var has_expected_version := current_environment.has("scenario_semantic_inventory_version")
	var has_expected_digest := current_environment.has("scenario_semantic_digest")
	var proof_ready := bool(current_environment.get("scenario_semantic_ready", false))
	if has_expected_version != has_expected_digest or proof_ready and not has_expected_version:
		return _invalidate_scenario_semantic_proof("scenario semantic inventory proof reference is incomplete; explicit migration is required")
	var expected_version_value: Variant = current_environment.get("scenario_semantic_inventory_version", 0)
	var expected_digest_value: Variant = current_environment.get("scenario_semantic_digest", "")
	var expected_version := int(expected_version_value) if typeof(expected_version_value) == TYPE_INT else 0
	var expected_digest := str(expected_digest_value) if typeof(expected_digest_value) == TYPE_STRING else ""
	if has_expected_version and (typeof(current_environment.get("scenario_semantic_inventory_version")) != TYPE_INT or typeof(current_environment.get("scenario_semantic_digest")) != TYPE_STRING or expected_version <= 0 or expected_digest != expected_digest.strip_edges() or expected_digest.is_empty()):
		return _invalidate_scenario_semantic_proof("scenario semantic inventory proof reference is malformed; explicit migration is required")
	if has_expected_version and (expected_version != next_version or expected_digest != next_digest):
		return _invalidate_scenario_semantic_proof("scenario semantic inventory version or digest changed; explicit migration is required")
	if proof_ready:
		# Identity/origin digest stability deliberately permits current presentation
		# availability and action descriptors to change. Refresh all authorization
		# inputs and the projection on a detached copy without replaying reentry.
		if _copy_dict(current_environment.get("scenario_sequence_state", {})).is_empty():
			return _invalidate_scenario_semantic_proof("Scenario semantic refresh requires an initialized sequence state.")
		var refresh_candidate := current_environment.duplicate(true)
		if str(refresh_candidate.get("scenario_id", "")).strip_edges().is_empty(): refresh_candidate["scenario_id"] = definition_id
		refresh_candidate["scenario_base_interactions"] = interactions
		refresh_candidate["scenario_base_actors"] = actors
		refresh_candidate["scenario_base_producer_context"] = producer_context.duplicate(true)
		refresh_candidate["scenario_semantic_action_digest"] = action_digest
		refresh_candidate["scenario_semantic_inventory"] = sealed
		refresh_candidate["scenario_semantic_inventory_version"] = next_version
		refresh_candidate["scenario_semantic_digest"] = next_digest
		refresh_candidate["scenario_semantic_ready"] = true
		refresh_candidate["scenario_restore_contract"] = ENV06_6B_SEMANTIC_RESTORE_EQUIVALENCE_V1
		refresh_candidate["scenario_event_choices"] = EnvironmentSemanticInventoryScript.event_choice_index(_copy_array(refresh_candidate.get("event_ids", [])), library)
		refresh_candidate["scenario_layout_base_records"] = stamped_records.duplicate(true)
		refresh_candidate["scenario_layout_context"] = layout_context.duplicate(true)
		var refreshed_state := ScenarioEngineScript.ensure_sequence_state(refresh_candidate, definition)
		if refreshed_state.is_empty() or str(refreshed_state.get("status", "")) == ScenarioSequenceRuntimeScript.STATUS_CLEANED and str(_copy_dict(current_environment.get("scenario_sequence_state", {})).get("status", "")) != ScenarioSequenceRuntimeScript.STATUS_CLEANED:
			return _scenario_semantic_finalization_failure(_copy_array(refreshed_state.get("errors", ["Scenario semantic refresh failed closed."])), refresh_attempt)
		var refresh_layout := _resolve_scenario_layout_candidate(refresh_candidate, stamped_records, definition, layout_context)
		if not bool(refresh_layout.get("ok", false)):
			return refresh_layout
		for key in ["scenario_id", "scenario_base_interactions", "scenario_base_actors", "scenario_base_producer_context", "scenario_semantic_action_digest", "scenario_semantic_inventory", "scenario_semantic_inventory_version", "scenario_semantic_digest", "scenario_semantic_ready", "scenario_restore_contract", "scenario_event_choices", "scenario_sequence_state", ScenarioEngineScript.TRUSTED_STATE_REFERENCE_KEY, ScenarioEngineScript.TRUSTED_LAYOUT_INPUT_DIGEST_KEY, "scenario_sequence_projection", "scenario_layout_base_records", "scenario_layout_context", "scenario_layout_authority", "scenario_layout_audit", "scenario_layout_authority_digest", "scenario_render_snapshot", "game_ids", "service_ids", "travel_hooks", "scenario_game_modifiers", "scenario_sequence_base_game_ids", "scenario_sequence_base_service_ids", "scenario_sequence_base_travel_hooks", "scenario_sequence_base_game_modifiers", "scenario_sequence_base_layout_object_rects"]:
			current_environment[key] = refresh_candidate.get(key).duplicate(true) if typeof(refresh_candidate.get(key)) in [TYPE_DICTIONARY, TYPE_ARRAY] else refresh_candidate.get(key)
		current_environment.erase("scenario_sequence_lifecycle_errors")
		current_environment.erase("scenario_restore_pending_trusted_rebuild")
		if not definition_id.is_empty(): _scenario_sequence_definition_cache[definition_id] = definition.duplicate(true)
		return _finalized_scenario_layout_result(true, next_digest, refreshed_state, stamped_records, refresh_layout)
	# Build the proof and perform initialization/reentry against a detached
	# environment. Readiness, authorization and runtime state become visible
	# together only after the entire transition succeeds.
	var candidate := current_environment.duplicate(true)
	if str(candidate.get("scenario_id", "")).strip_edges().is_empty(): candidate["scenario_id"] = definition_id
	candidate["scenario_base_interactions"] = interactions
	candidate["scenario_base_actors"] = actors
	candidate["scenario_base_producer_context"] = producer_context.duplicate(true)
	candidate["scenario_semantic_action_digest"] = action_digest
	candidate["scenario_semantic_inventory"] = sealed
	candidate["scenario_semantic_inventory_version"] = next_version
	candidate["scenario_semantic_digest"] = next_digest
	candidate["scenario_semantic_ready"] = true
	candidate["scenario_restore_contract"] = ENV06_6B_SEMANTIC_RESTORE_EQUIVALENCE_V1
	candidate["scenario_event_choices"] = EnvironmentSemanticInventoryScript.event_choice_index(_copy_array(candidate.get("event_ids", [])), library)
	candidate["scenario_layout_base_records"] = stamped_records.duplicate(true)
	candidate["scenario_layout_context"] = layout_context.duplicate(true)
	if _copy_dict(candidate.get("scenario_state", {})).is_empty():
		candidate["scenario_state"] = ScenarioEngineScript.initial_state(definition)
	var migration := ScenarioEngineScript.migrate_environment_sequence(candidate, definition, str(candidate.get("id", candidate.get("environment_visit_id", ""))))
	if not bool(migration.get("ok", false)) or not bool(migration.get("active", false)):
		return _scenario_semantic_finalization_failure(_copy_array(migration.get("errors", ["Scenario sequence migration did not activate after semantic finalization."])), refresh_attempt)
	var initialized_state := _copy_dict(candidate.get("scenario_sequence_state", {}))
	if str(initialized_state.get("status", "")) == ScenarioSequenceRuntimeScript.STATUS_CLEANED:
		var initialization_errors := _copy_array(initialized_state.get("errors", []))
		if initialization_errors.is_empty():
			initialization_errors = ["Scenario sequence could not initialize its sealed semantic state."]
		return _scenario_semantic_finalization_failure(initialization_errors, refresh_attempt)
	var visit_id := str(candidate.get("scenario_sequence_pending_visit_id", candidate.get("environment_visit_id", "")))
	var reentry := ScenarioEngineScript.sequence_apply_reentry(candidate, definition, visit_id)
	if not bool(reentry.get("ok", false)):
		return {"ok": false, "errors": _copy_array(reentry.get("errors", []))}
	var candidate_layout := {
		"ok": true,
		"projection": _copy_dict(reentry.get("projection", candidate.get("scenario_sequence_projection", {}))),
		"layout_authority": _copy_dict(reentry.get("layout_authority", candidate.get("scenario_layout_authority", {}))),
		"layout_authority_digest": str(reentry.get("layout_authority_digest", candidate.get("scenario_layout_authority_digest", ""))),
		"layout_audit": _copy_dict(reentry.get("layout_audit", candidate.get("scenario_layout_audit", {}))),
		"warnings": _copy_array(reentry.get("warnings", [])),
		"errors": [],
	}
	for key in ["scenario_id", "scenario_base_interactions", "scenario_base_actors", "scenario_base_producer_context", "scenario_semantic_action_digest", "scenario_semantic_inventory", "scenario_semantic_inventory_version", "scenario_semantic_digest", "scenario_semantic_ready", "scenario_restore_contract", "scenario_event_choices", "scenario_sequence_migration", "scenario_sequence_state", ScenarioEngineScript.TRUSTED_STATE_REFERENCE_KEY, ScenarioEngineScript.TRUSTED_LAYOUT_INPUT_DIGEST_KEY, "scenario_sequence_projection", "scenario_layout_base_records", "scenario_layout_context", "scenario_layout_authority", "scenario_layout_audit", "scenario_layout_authority_digest", "scenario_render_snapshot", "game_ids", "service_ids", "travel_hooks", "scenario_game_modifiers", "scenario_sequence_base_game_ids", "scenario_sequence_base_service_ids", "scenario_sequence_base_travel_hooks", "scenario_sequence_base_game_modifiers", "scenario_sequence_base_layout_object_rects"]:
		current_environment[key] = candidate.get(key).duplicate(true) if typeof(candidate.get(key)) in [TYPE_DICTIONARY, TYPE_ARRAY] else candidate.get(key)
	current_environment.erase("scenario_sequence_pending_visit_id")
	current_environment.erase("scenario_sequence_lifecycle_errors")
	current_environment.erase("scenario_restore_pending_trusted_rebuild")
	if not definition_id.is_empty(): _scenario_sequence_definition_cache[definition_id] = definition.duplicate(true)
	return _finalized_scenario_layout_result(false, next_digest, _copy_dict(reentry.get("state", {})), stamped_records, candidate_layout)


func _resolve_scenario_layout_candidate(candidate: Dictionary, stamped_records: Array, definition: Dictionary, layout_context: Dictionary) -> Dictionary:
	var projection := ScenarioEngineScript.sequence_projection(candidate, definition)
	var layout_environment := candidate.duplicate(true)
	if not layout_context.is_empty():
		layout_environment["_scenario_layout_context"] = layout_context.duplicate(true)
	var layout_result := ScenarioLayoutResolverScript.resolve(stamped_records, projection, layout_environment)
	if not bool(layout_result.get("ok", false)):
		return {
			"ok": false,
			"errors": _copy_array(layout_result.get("errors", ["Scenario production layout resolution failed closed."])),
			"layout_audit": _copy_dict(layout_result.get("layout_audit", {})),
		}
	candidate["scenario_sequence_projection"] = _copy_dict(layout_result.get("projection", projection))
	candidate["scenario_layout_authority"] = _copy_dict(layout_result.get("layout_authority", {}))
	candidate["scenario_layout_audit"] = _copy_dict(layout_result.get("layout_audit", {}))
	candidate["scenario_layout_authority_digest"] = str(layout_result.get("layout_authority_digest", ""))
	var renderer_snapshot := ScenarioLayoutResolverScript.sealed_renderer_snapshot(layout_result)
	if not bool(renderer_snapshot.get("ok", false)):
		return {"ok": false, "errors": _copy_array(renderer_snapshot.get("errors", ["Scenario sealed renderer snapshot failed closed."])), "layout_audit": _copy_dict(layout_result.get("layout_audit", {}))}
	candidate["scenario_render_snapshot"] = renderer_snapshot.duplicate(true)
	return layout_result


func _resolve_world_sequence_composed_layout(stamped_records: Array, layout_context: Dictionary) -> Dictionary:
	var projection := world_sequence_composed_projection()
	if not bool(projection.get("ok", true)):
		return {"ok": false, "errors": _copy_array(projection.get("errors", ["World sequence projection composition failed closed."]))}
	var layout_environment := current_environment.duplicate(true)
	if not layout_context.is_empty(): layout_environment["_scenario_layout_context"] = layout_context.duplicate(true)
	var layout_result := ScenarioLayoutResolverScript.resolve(stamped_records, projection, layout_environment)
	if not bool(layout_result.get("ok", false)): return {"ok": false, "errors": _copy_array(layout_result.get("errors", ["World sequence layout resolution failed closed."])), "layout_audit": _copy_dict(layout_result.get("layout_audit", {}))}
	var renderer_snapshot := ScenarioLayoutResolverScript.sealed_renderer_snapshot(layout_result)
	if not bool(renderer_snapshot.get("ok", false)): return {"ok": false, "errors": _copy_array(renderer_snapshot.get("errors", ["World sequence renderer resolution failed closed."]))}
	current_environment["scenario_sequence_projection"] = _copy_dict(layout_result.get("projection", projection))
	current_environment["scenario_layout_authority"] = _copy_dict(layout_result.get("layout_authority", {}))
	current_environment["scenario_layout_audit"] = _copy_dict(layout_result.get("layout_audit", {}))
	current_environment["scenario_layout_authority_digest"] = str(layout_result.get("layout_authority_digest", ""))
	current_environment["scenario_render_snapshot"] = renderer_snapshot.duplicate(true)
	return {
		"ok": true,
		"projection": _copy_dict(layout_result.get("projection", projection)),
		"layout_authority": _copy_dict(layout_result.get("layout_authority", {})),
		"layout_authority_digest": str(layout_result.get("layout_authority_digest", "")),
		"layout_audit": _copy_dict(layout_result.get("layout_audit", {})),
		"renderer_snapshot": renderer_snapshot,
		"warnings": _copy_array(layout_result.get("warnings", [])),
		"errors": [],
	}


func _finalized_scenario_layout_result(replayed: bool, digest: String, state: Dictionary, records: Array, layout_result: Dictionary) -> Dictionary:
	var result := {
		"ok": true,
		"replayed": replayed,
		"digest": digest,
		"state": state.duplicate(true),
		"records": records.duplicate(true),
		"projection": _copy_dict(layout_result.get("projection", {})),
		"layout_authority": _copy_dict(layout_result.get("layout_authority", {})),
		"layout_authority_digest": str(layout_result.get("layout_authority_digest", "")),
		"layout_audit": _copy_dict(layout_result.get("layout_audit", {})),
		"warnings": _copy_array(layout_result.get("warnings", [])),
		"errors": [],
	}
	var world_activation := world_sequence_activate_current_mounts()
	result["world_sequences"] = world_activation
	if not bool(world_activation.get("ok", false)):
		result["ok"] = false
		result["errors"] = _copy_array(world_activation.get("errors", []))
	elif not _copy_array(world_activation.get("mounted", [])).is_empty():
		var composed := _resolve_world_sequence_composed_layout(records, _copy_dict(current_environment.get("scenario_layout_context", {})))
		if not bool(composed.get("ok", false)):
			result["ok"] = false
			result["errors"] = _copy_array(composed.get("errors", []))
		else:
			for key in ["projection", "layout_authority", "layout_authority_digest", "layout_audit", "renderer_snapshot", "warnings"]:
				result[key] = composed.get(key).duplicate(true) if typeof(composed.get(key)) in [TYPE_DICTIONARY, TYPE_ARRAY] else composed.get(key)
	return result


func _scenario_declared_base_records(records: Array, definition: Dictionary, collection_keys: Array) -> Array:
	var declared := _copy_dict(_copy_dict(ScenarioSequenceSchemaScript.sequence(definition)).get("declared_targets", {}))
	var allowed: Dictionary = {}
	for collection_value in collection_keys:
		for identity_value in _copy_array(declared.get(str(collection_value), [])):
			allowed[str(identity_value)] = true
	var result: Array = []
	for record_value in records:
		if typeof(record_value) != TYPE_DICTIONARY: continue
		var record := record_value as Dictionary
		var owned_identity := ScenarioOperationRegistryScript.identity(str(record.get("owner_namespace", "")), str(record.get("stable_object_id", "")))
		if allowed.has(owned_identity): result.append(record.duplicate(true))
	return result


# A resolved base event legitimately leaves the live UI after it drives a
# terminal sequence branch. Retain its already sealed producer identity as a
# disabled semantic record so aftermath reconstruction keeps the immutable
# inventory proof without resurrecting the interaction in the live record set.
func _scenario_terminal_semantic_interactions(live_records: Array, definition: Dictionary) -> Array:
	var state := _copy_dict(current_environment.get("scenario_sequence_state", {}))
	if not _scenario_terminal_semantic_refresh(definition):
		return live_records
	var declared := _copy_dict(_copy_dict(ScenarioSequenceSchemaScript.sequence(definition)).get("declared_targets", {}))
	var declared_interactions: Dictionary = {}
	for identity_value in _copy_array(declared.get("interactions", [])):
		declared_interactions[str(identity_value)] = true
	var sealed_inventory := _copy_dict(current_environment.get("scenario_semantic_inventory", {}))
	var sealed_inventory_valid := EnvironmentSemanticInventoryScript.validate(sealed_inventory).is_empty() \
		and str(sealed_inventory.get("environment_id", "")) == str(current_environment.get("id", "")) \
		and str(sealed_inventory.get("layer_id", "")) == str(current_environment.get("current_layer_id", ""))
	var result := live_records.duplicate(true)
	for record_index in range(result.size()):
		var live_record := _copy_dict(result[record_index])
		var live_identity := ScenarioOperationRegistryScript.identity(str(live_record.get("owner_namespace", "")), str(live_record.get("stable_object_id", "")))
		if not declared_interactions.has(live_identity) or not live_identity.begins_with("event::event:"):
			continue
		live_record["enabled"] = false
		live_record["interactive"] = false
		live_record["disabled_reason"] = "The scenario has already resolved this event."
		live_record["state_label"] = "Resolved"
		live_record["available_actions"] = []
		live_record["inline_actions"] = []
		live_record["scenario_sequence_actions"] = []
		result[record_index] = live_record
	var present: Dictionary = {}
	for record_value in result:
		var record := _copy_dict(record_value)
		present[ScenarioOperationRegistryScript.identity(str(record.get("owner_namespace", "")), str(record.get("stable_object_id", "")))] = true
	for record_value in _copy_array(current_environment.get("scenario_base_interactions", [])) if sealed_inventory_valid else []:
		var record := _copy_dict(record_value)
		var identity := ScenarioOperationRegistryScript.identity(str(record.get("owner_namespace", "")), str(record.get("stable_object_id", "")))
		if identity.is_empty() or present.has(identity):
			continue
		record["enabled"] = false
		record["interactive"] = false
		record["available_actions"] = []
		record["inline_actions"] = []
		record["scenario_sequence_actions"] = []
		result.append(record)
		present[identity] = true
	# Render-time proof data is intentionally absent after save/load. Rebuild a
	# resolved base-event tombstone from its durable producer and exact final
	# layout so terminal reentry recreates the same immutable identity seal
	# without persisting hidden semantic inventory state.
	var layout_rects := _copy_dict(current_environment.get("scenario_sequence_base_layout_object_rects", _copy_dict(current_environment.get("layout", {})).get("object_rects", {})))
	var board := Vector2(ArtContractsScript.ENVIRONMENT_BOARD_SIZE)
	for identity_value in _copy_array(declared.get("interactions", [])):
		var identity := str(identity_value)
		if present.has(identity) or not identity.begins_with("event::event:"):
			continue
		var event_id := identity.trim_prefix("event::event:")
		var presentation_id := "event:%s" % event_id
		var normalized_rect := _copy_dict(layout_rects.get(presentation_id, {}))
		if not _copy_array(current_environment.get("event_ids", [])).has(event_id) or normalized_rect.is_empty():
			continue
		result.append({
			"owner_namespace": "event",
			"stable_object_id": presentation_id,
			"presentation_object_id": presentation_id,
			"source_kind": "environment_instance_ui",
			"source_field": "event_ids",
			"source_record_id": event_id,
			"label": event_id,
			"state_label": "Resolved",
			"prompt": "No action is currently available.",
			"enabled": false,
			"disabled_reason": "No action is currently available.",
			"available_actions": [],
			"input_actions": [],
			"non_color_state": "closed",
			"focus_order": result.size(),
			"hit_bounds": {
				"w": float(normalized_rect.get("w", 0.0)) * board.x,
				"h": float(normalized_rect.get("h", 0.0)) * board.y,
			},
			"normalized_hit_rect": normalized_rect,
			"min_target_size": ScenarioOperationRegistryScript.MIN_TARGET_SIZE,
			"safe_exit": false,
			"alternate_exit": false,
			"source_id": event_id,
		})
		present[identity] = true
	return result


func _scenario_terminal_layout_base_records(live_records: Array, interactions: Array, definition: Dictionary) -> Array:
	if not _scenario_terminal_semantic_refresh(definition):
		return live_records
	var result := live_records.duplicate(true)
	var interactions_by_presentation: Dictionary = {}
	for interaction_value in interactions:
		var terminal_interaction := _copy_dict(interaction_value)
		var terminal_presentation_id := str(terminal_interaction.get("presentation_object_id", ""))
		if not terminal_presentation_id.is_empty():
			interactions_by_presentation[terminal_presentation_id] = terminal_interaction
	var presentation_ids: Dictionary = {}
	for record_index in range(result.size()):
		var record := _copy_dict(result[record_index])
		var record_presentation_id := str(record.get("object_id", ""))
		presentation_ids[record_presentation_id] = true
		var terminal_interaction := _copy_dict(interactions_by_presentation.get(record_presentation_id, {}))
		if terminal_interaction.is_empty() or bool(terminal_interaction.get("enabled", true)):
			continue
		record["enabled"] = false
		record["interactive"] = false
		record["visible"] = true
		record["disabled_reason"] = str(terminal_interaction.get("disabled_reason", "The scenario has already resolved this event."))
		record["state_label"] = "Resolved"
		record["action_summary"] = "No action is currently available."
		record["available_actions"] = []
		record["inline_actions"] = []
		result[record_index] = record
	for interaction_value in interactions:
		var interaction := _copy_dict(interaction_value)
		var presentation_id := str(interaction.get("presentation_object_id", ""))
		if presentation_id.is_empty() or presentation_ids.has(presentation_id):
			continue
		result.append({
			"object_id": presentation_id,
			"object_type": "event",
			"visual_type": "event",
			"source_id": str(interaction.get("source_id", "")),
			"owner_namespace": str(interaction.get("owner_namespace", "")),
			"stable_object_id": str(interaction.get("stable_object_id", "")),
			"source_kind": str(interaction.get("source_kind", "")),
			"source_field": str(interaction.get("source_field", "")),
			"source_record_id": str(interaction.get("source_record_id", "")),
			"normalized_hit_rect": _copy_dict(interaction.get("normalized_hit_rect", {})),
			"normalized_rect": _copy_dict(interaction.get("normalized_hit_rect", {})),
			"pixel_hit_bounds": _copy_dict(interaction.get("hit_bounds", {})),
			"label": str(interaction.get("label", presentation_id)),
			"state_label": "Resolved",
			"non_color_state": "closed",
			"action_summary": "No action is currently available.",
			"enabled": false,
			"interactive": false,
			"visible": true,
			"available_actions": [],
			"inline_actions": [],
		})
		presentation_ids[presentation_id] = true
	return result


func _scenario_terminal_semantic_refresh(definition: Dictionary) -> bool:
	var state := _copy_dict(current_environment.get("scenario_sequence_state", {}))
	if str(state.get("status", "")) in [ScenarioSequenceRuntimeScript.STATUS_AFTERMATH, ScenarioSequenceRuntimeScript.STATUS_CLEANED]:
		return true
	return bool(_copy_dict(ScenarioSequenceSchemaScript.phase(definition, str(state.get("phase_id", "")))).get("terminal", false))


func _scenario_base_producer_context() -> Dictionary:
	var venue_ids: Array = []
	for venue_value in _copy_array(numbers_status().get("venue_status", [])):
		if typeof(venue_value) != TYPE_DICTIONARY: continue
		var venue_id := str((venue_value as Dictionary).get("id", ""))
		if venue_id == venue_id.strip_edges() and not venue_id.is_empty() and not venue_ids.has(venue_id): venue_ids.append(venue_id)
	venue_ids.sort()
	var handoff := delivery_arrival_interaction()
	return {
		"numbers_venue_ids": venue_ids,
		"numbers_silas_present": numbers_silas_is_here(),
		"delivery_handoff_node_id": str(handoff.get("node_id", "")),
	}


func _invalidate_scenario_semantic_proof(message: String) -> Dictionary:
	for key in ["scenario_semantic_ready", "scenario_semantic_inventory", "scenario_base_interactions", "scenario_base_actors", "scenario_base_producer_context", "scenario_semantic_action_digest", "scenario_layout_base_records", "scenario_layout_context", "scenario_layout_authority", "scenario_layout_audit", "scenario_layout_authority_digest", "scenario_render_snapshot"]:
		current_environment.erase(key)
	# Proof invalidation is not a causal gameplay boundary. Preserve the durable
	# journal exactly and block live ingress; cleanup may only be written by the
	# runtime through an authenticated command/fact/expiry receipt.
	current_environment["scenario_sequence_lifecycle_errors"] = [message]
	current_environment["scenario_sequence_projection"] = {}
	return {"ok": false, "errors": [message]}


func _scenario_semantic_finalization_failure(errors: Array, invalidate_if_ready: bool) -> Dictionary:
	var failure_errors := errors.duplicate(true)
	if failure_errors.is_empty(): failure_errors = ["Scenario semantic finalization failed closed."]
	# A malformed trusted refresh means the live proof can no longer establish a
	# unique authority record. Invalidate only ephemeral proof state while the
	# durable causal journal remains byte-for-byte unchanged.
	if invalidate_if_ready:
		_invalidate_scenario_semantic_proof(str(failure_errors[0]))
	return {"ok": false, "errors": failure_errors}


func scenario_reject_layout_projection(errors_value: Array, layout_audit: Dictionary = {}) -> Dictionary:
	var errors: Array = []
	for value in errors_value:
		var message := str(value).strip_edges()
		if not message.is_empty() and not errors.has(message): errors.append(message)
	if errors.is_empty(): errors.append("Scenario production layout projection failed closed.")
	_invalidate_scenario_semantic_proof(str(errors[0]))
	current_environment["scenario_sequence_lifecycle_errors"] = errors.duplicate(true)
	current_environment["scenario_layout_audit"] = layout_audit.duplicate(true)
	current_environment["scenario_layout_authority_digest"] = ""
	return {"ok": false, "errors": errors}


func _scenario_semantic_ready() -> bool:
	if bool(current_environment.get("scenario_restore_pending_trusted_rebuild", false)): return false
	if str(current_environment.get("scenario_restore_contract", "")) != ENV06_6B_SEMANTIC_RESTORE_EQUIVALENCE_V1: return false
	if not bool(current_environment.get("scenario_semantic_ready", false)): return false
	var inventory := _copy_dict(current_environment.get("scenario_semantic_inventory", {}))
	var layout_audit := _copy_dict(current_environment.get("scenario_layout_audit", {}))
	var layout_digest := str(current_environment.get("scenario_layout_authority_digest", ""))
	var layout_authority := _copy_dict(current_environment.get("scenario_layout_authority", {}))
	var renderer_snapshot := _copy_dict(current_environment.get("scenario_render_snapshot", {}))
	var projection_semantic := _copy_dict(_copy_dict(current_environment.get("scenario_sequence_projection", {})).get("semantic_state", {}))
	var passive_layout := not bool(layout_audit.get("active", true))
	if typeof(current_environment.get("scenario_semantic_inventory_version")) != TYPE_INT \
		or typeof(current_environment.get("scenario_semantic_digest")) != TYPE_STRING \
		or typeof(current_environment.get("scenario_semantic_action_digest")) != TYPE_STRING \
		or not bool(layout_audit.get("valid", false)) \
		or not ScenarioSequenceRuntimeScript._valid_sha256(layout_digest) \
		or (layout_authority.is_empty() and not passive_layout) \
		or (passive_layout and (not layout_authority.is_empty() or not bool(layout_audit.get("sealed_passive", false)) or not bool(renderer_snapshot.get("sealed_passive", false)) or str(renderer_snapshot.get("presentation_mode", "")) != "passive")) \
		or (not passive_layout and bool(renderer_snapshot.get("sealed_passive", false))) \
		or not bool(renderer_snapshot.get("ok", false)) \
		or str(layout_audit.get("authority_digest", "")) != layout_digest \
		or str(renderer_snapshot.get("layout_authority_digest", "")) != layout_digest \
		or str(projection_semantic.get("layout_authority_digest", "")) != layout_digest:
		return false
	var action_digest := str(current_environment.get("scenario_semantic_action_digest", ""))
	if not ScenarioSequenceRuntimeScript._valid_sha256(action_digest) or action_digest != ScenarioSequenceRuntimeScript.base_interaction_action_authority_digest(_copy_array(current_environment.get("scenario_base_interactions", []))): return false
	return not inventory.is_empty() \
		and int(inventory.get("schema_version", 0)) == int(current_environment.get("scenario_semantic_inventory_version", 0)) \
		and str(inventory.get("digest", "")) == str(current_environment.get("scenario_semantic_digest", ""))


func scenario_sequence_active() -> bool:
	return _scenario_semantic_ready() and not ScenarioEngineScript.sequence_projection(current_environment, _scenario_sequence_definition_readonly()).is_empty()


func scenario_sequence_present() -> bool:
	if not current_environment.has("scenario_sequence_state") and not current_environment.has("scenario_sequence_pending_visit_id"):
		return false
	var definition := _scenario_sequence_definition_readonly()
	return ScenarioSequenceSchemaScript.is_sequence(definition)


func _scenario_sequence_uses_expiry_boundary(boundary: String) -> bool:
	if not scenario_sequence_present(): return false
	var sequence := ScenarioSequenceSchemaScript.sequence(_scenario_sequence_definition_readonly())
	var expiry_value: Variant = sequence.get("expiry", {})
	return typeof(expiry_value) == TYPE_DICTIONARY and str((expiry_value as Dictionary).get("boundary", "none")) == boundary


func scenario_sequence_projection() -> Dictionary:
	if not _scenario_semantic_ready(): return {}
	return ScenarioEngineScript.sequence_projection(current_environment, _scenario_sequence_definition_readonly())


func scenario_sequence_record_visit(visit_id: String = "") -> Dictionary:
	var definition := _scenario_sequence_definition_readonly()
	if definition.is_empty(): return {"ok": false, "errors": ["No dynamic room sequence is active."]}
	if not _scenario_semantic_ready(): return {"ok": false, "errors": ["Dynamic room sequence semantic records are not finalized."]}
	var environment_before := current_environment.duplicate(true)
	_ensure_scenario_host_public_context()
	var stable_visit_id := visit_id.strip_edges()
	if stable_visit_id.is_empty(): stable_visit_id = str(current_environment.get("environment_visit_id", ""))
	var result := ScenarioEngineScript.sequence_record_visit(current_environment, definition, stable_visit_id)
	if not bool(result.get("ok", false)):
		current_environment = environment_before
	return result


func scenario_sequence_apply_reentry(visit_id: String = "") -> Dictionary:
	var definition := _scenario_sequence_definition_readonly()
	if definition.is_empty(): return {"ok": false, "errors": ["No dynamic room sequence is active."]}
	if not _scenario_semantic_ready(): return {"ok": false, "errors": ["Dynamic room sequence semantic records are not finalized."]}
	var environment_before := current_environment.duplicate(true)
	_ensure_scenario_host_public_context()
	var stable_visit_id := visit_id.strip_edges()
	if stable_visit_id.is_empty(): stable_visit_id = str(current_environment.get("environment_visit_id", ""))
	var result := ScenarioEngineScript.sequence_apply_reentry(current_environment, definition, stable_visit_id)
	if not bool(result.get("ok", false)):
		current_environment = environment_before
	return result


func scenario_sequence_apply_expiry_boundary(boundary: String, amount: int = 1) -> Dictionary:
	var definition := _scenario_sequence_definition_readonly()
	if definition.is_empty(): return {"ok": true, "inactive": true, "errors": []}
	var sequence := ScenarioSequenceSchemaScript.sequence(definition)
	var expiry_value: Variant = sequence.get("expiry", {})
	var authored_boundary := str((expiry_value as Dictionary).get("boundary", "none")) if typeof(expiry_value) == TYPE_DICTIONARY else "none"
	if authored_boundary == "none" or authored_boundary != boundary:
		return {"ok": true, "inactive": true, "errors": []}
	if not _scenario_semantic_ready(): return {"ok": false, "errors": ["Dynamic room sequence semantic records are not finalized."]}
	var environment_before := current_environment.duplicate(true)
	var result := ScenarioEngineScript.sequence_apply_expiry_boundary(current_environment, definition, boundary, amount)
	if not bool(result.get("ok", false)):
		current_environment = environment_before
	return result


# Public cross-consumer table-game transaction context. The returned state is an
# ephemeral CAS snapshot bound to canonical RunState fields; only the ledger is
# persisted.
func prepare_game_command_context(table_id: String, producer_id: String, requested_keys: Array = []) -> Dictionary:
	_ensure_scenario_host_public_context()
	return ScenarioHostTransactionScript.prepared_game_context(_scenario_host_bound_state(), _scenario_host_public_context(), table_id, producer_id, requested_keys)


func reduce_game_command_transaction(command: Dictionary) -> Dictionary:
	_ensure_scenario_host_public_context()
	return ScenarioHostTransactionScript.reduce_game_command(_scenario_host_bound_state(), command)


func commit_game_command(transaction: Dictionary) -> Dictionary:
	var result := ScenarioHostTransactionScript.commit_game_command(_scenario_host_bound_state(), transaction)
	return _apply_scenario_host_result(result)


func game_command_cas_snapshot() -> Dictionary:
	var state := _scenario_host_bound_state()
	return {"revision": int(state.get("revision", 0)), "state_digest": ScenarioHostTransactionScript.state_digest(state)}


func flush_game_facts_at_safe_boundary(boundary: int) -> Dictionary:
	var result := ScenarioHostTransactionScript.flush_game_facts(_scenario_host_bound_state(), boundary)
	return _apply_scenario_host_result(result)


func respond_to_prepared_game_request(request_id: String, response: String, receipt_id: String, expected_revision: int, expected_digest: String) -> Dictionary:
	return _apply_scenario_host_result(ScenarioHostTransactionScript.respond_to_prepared_request(_scenario_host_bound_state(), request_id, response, receipt_id, expected_revision, expected_digest))


func complete_prepared_game_request_economy(request_id: String, account_ops: Array, receipt_id: String, expected_revision: int, expected_digest: String) -> Dictionary:
	return _apply_scenario_host_result(ScenarioHostTransactionScript.complete_prepared_request_economy(_scenario_host_bound_state(), request_id, account_ops, receipt_id, expected_revision, expected_digest))


func acknowledge_prepared_game_unwound(request_id: String, replacement_table_state: Dictionary, receipt_id: String, expected_revision: int, expected_digest: String) -> Dictionary:
	return _apply_scenario_host_result(ScenarioHostTransactionScript.acknowledge_prepared_request_unwound(_scenario_host_bound_state(), request_id, replacement_table_state, receipt_id, expected_revision, expected_digest))


func apply_prepared_game_request_runtime(request_id: String, receipt_id: String, expected_revision: int, expected_digest: String) -> Dictionary:
	return _apply_scenario_host_result(ScenarioHostTransactionScript.apply_prepared_request_runtime(_scenario_host_bound_state(), request_id, receipt_id, expected_revision, expected_digest))


func pre_travel_game_gate(command: Dictionary, request: Dictionary) -> Dictionary:
	return ScenarioHostTransactionScript.pre_travel_hook(command, request)


func _scenario_host_bound_state() -> Dictionary:
	_ensure_scenario_host_ledger()
	return ScenarioHostTransactionScript.bind_canonical_snapshot(scenario_host_transaction_ledger, {
		"accounts": {
			"player_bankroll": {"fund_domain": "bankroll", "balance": bankroll},
			"grand_casino_chips": {"fund_domain": "chips", "balance": grand_casino_chips},
		},
		"table_states": _copy_dict(current_environment.get("game_states", {})),
		"trust": crew_trust_by_member.duplicate(true),
		"tells": _scenario_host_tell_snapshot(),
	})


func _apply_scenario_host_result(result_value: Dictionary) -> Dictionary:
	var result := result_value.duplicate(true)
	if not bool(result.get("ok", false)):
		return result
	var state := _copy_dict(result.get("state", {}))
	if state.is_empty():
		return result
	if not bool(result.get("replayed", false)):
		var accounts := _copy_dict(state.get("accounts", {}))
		bankroll = int(_copy_dict(accounts.get("player_bankroll", {})).get("balance", bankroll))
		grand_casino_chips = maxi(0, int(_copy_dict(accounts.get("grand_casino_chips", {})).get("balance", grand_casino_chips)))
		current_environment["game_states"] = _copy_dict(state.get("table_states", {}))
		crew_trust_by_member = _copy_dict(state.get("trust", {}))
		_apply_scenario_host_tell_snapshot(_copy_dict(state.get("tells", {})))
	scenario_host_transaction_ledger = ScenarioHostTransactionScript.persisted_ledger(state)
	return result


func _ensure_scenario_host_ledger() -> void:
	if not scenario_host_transaction_ledger.is_empty():
		return
	var scenario_state := text_to_seed("%s|%d|scenario" % [seed_text, rng_state])
	var craps_throw_state := text_to_seed("%s|%d|craps_throw" % [seed_text, rng_state])
	var craps_recovery_state := text_to_seed("%s|%d|craps_recovery" % [seed_text, rng_state])
	var poker_cards_state := text_to_seed("%s|%d|poker_cards" % [seed_text, rng_state])
	var rng_leases := {
		"scenario_main": {"owner_id": "scenario", "stream_id": "scenario", "current_state": scenario_state, "receipts": []},
		"craps_throw_main": {"owner_id": "craps_throw", "stream_id": "craps_throw", "current_state": craps_throw_state, "receipts": []},
		"craps_recovery_main": {"owner_id": "craps_recovery", "stream_id": "craps_recovery", "current_state": craps_recovery_state, "receipts": []},
		"poker_cards_main": {"owner_id": "poker_cards", "stream_id": "poker_cards", "current_state": poker_cards_state, "receipts": []},
	}
	for member_id in ["crew_rook", "crew_velvet", "crew_knuckles", "crew_switch", "crew_mags", "crew_bishop", "crew_lucky"]:
		var owner_id := "poker_policy_%s" % member_id
		rng_leases[owner_id] = {
			"owner_id": owner_id,
			"stream_id": owner_id,
			"current_state": text_to_seed("%s|%d|%s" % [seed_text, rng_state, owner_id]),
			"receipts": [],
		}
	var state := ScenarioHostTransactionScript.initial_state({}, {}, rng_leases)
	scenario_host_transaction_ledger = ScenarioHostTransactionScript.persisted_ledger(state)


func _ensure_scenario_host_public_context() -> void:
	if current_environment.is_empty():
		return
	var node_id := _scenario_host_safe_id(str(current_environment.get("world_node_id", current_environment.get("archetype_id", "node"))))
	if node_id.is_empty(): node_id = "node"
	current_environment["world_node_id"] = node_id
	var environment_visit_id := _scenario_host_safe_id(str(current_environment.get("environment_visit_id", "")))
	if environment_visit_id.is_empty():
		environment_visit_id = "visit_%s_%d" % [_scenario_host_safe_id(str(current_environment.get("id", node_id))), maxi(1, environment_travel_count() + 1)]
	current_environment["environment_visit_id"] = environment_visit_id
	var night_instance_id := _scenario_host_safe_id(str(current_environment.get("night_instance_id", "")))
	if night_instance_id.is_empty(): night_instance_id = "night_%d" % act_marker()
	current_environment["night_instance_id"] = night_instance_id
	var context_instance_id := _scenario_host_safe_id(str(current_environment.get("context_instance_id", "")))
	if context_instance_id.is_empty(): context_instance_id = "context_%s" % environment_visit_id
	current_environment["context_instance_id"] = context_instance_id


func _scenario_host_public_context() -> Dictionary:
	return ScenarioHostTransactionScript.public_context(
		str(current_environment.get("world_node_id", "")),
		str(current_environment.get("environment_visit_id", "")),
		str(current_environment.get("night_instance_id", "")),
		str(current_environment.get("context_instance_id", ""))
	)


func _scenario_host_tell_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for member_id_value in crew_pattern_memory.keys():
		var member_id := str(member_id_value)
		for pattern_id_value in _copy_dict(crew_pattern_memory.get(member_id_value, {})).keys():
			var pattern_id := str(pattern_id_value)
			result["%s:%s" % [member_id, pattern_id]] = int(_copy_dict(crew_pattern_memory.get(member_id_value, {})).get(pattern_id_value, 0))
	return result


func _apply_scenario_host_tell_snapshot(snapshot: Dictionary) -> void:
	var next := crew_pattern_memory.duplicate(true)
	for key_value in snapshot.keys():
		var parts := str(key_value).split(":", false, 1)
		if parts.size() != 2: continue
		var member := _copy_dict(next.get(str(parts[0]), {}))
		member[str(parts[1])] = maxi(0, int(snapshot.get(key_value, 0)))
		next[str(parts[0])] = member
	crew_pattern_memory = next


func _scenario_host_safe_id(value: String) -> String:
	var result := ""
	var normalized := value.strip_edges().to_lower()
	for index in range(normalized.length()):
		var code := normalized.unicode_at(index)
		result += normalized[index] if (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code in [95, 45] else "_"
	return result


func scenario_sequence_command(command_id: String, idempotency_key: String, payload: Dictionary = {}, owner_namespace: String = "scenario", stable_object_id: String = "sequence", host_interaction_availability: Dictionary = {}, action_origin_owner_namespace: String = "", action_origin_stable_object_id: String = "", action_origin_receipt_key: String = "", action_origin_boundary_id: String = "", action_origin_fingerprint: String = "") -> Dictionary:
	var definition := _scenario_sequence_definition_readonly()
	if definition.is_empty():
		return {"ok": false, "errors": ["No dynamic room sequence is active."]}
	if not _scenario_semantic_ready():
		return {"ok": false, "errors": ["Dynamic room sequence semantic records are not finalized."]}
	var sequence_state := _copy_dict(current_environment.get("scenario_sequence_state", {}))
	var replay_record: Dictionary = {}
	if _copy_array(sequence_state.get("command_receipts", [])).has(idempotency_key):
		for record_value in _copy_array(sequence_state.get("command_receipt_records", [])):
			var record := _copy_dict(record_value)
			if str(record.get("receipt_key", "")) != idempotency_key:
				continue
			if not replay_record.is_empty():
				return {"ok": false, "errors": ["scenario command replay receipt is duplicated or malformed"]}
			replay_record = record
		if replay_record.is_empty():
			return {"ok": false, "errors": ["scenario command replay receipt is missing or malformed"]}
	# The ingress receipt above proves this prepared projection belongs to the
	# finalized environment; ScenarioEngine authenticates the exact state digest
	# before mutation. Re-projecting the complete semantic state merely to read
	# its phase repeated the same normalization on every click.
	var expected_phase := str(_copy_dict(current_environment.get("scenario_sequence_projection", {})).get("phase_id", ""))
	if not replay_record.is_empty():
		var stored_envelope := _copy_dict(replay_record.get("envelope", {}))
		var stored_fingerprint := str(replay_record.get("fingerprint", ""))
		if stored_envelope.is_empty() or stored_fingerprint.is_empty() or stored_fingerprint != str(_copy_dict(sequence_state.get("command_fingerprints", {})).get(idempotency_key, "")) or stored_fingerprint != ScenarioSequenceRuntimeScript.content_fingerprint(stored_envelope):
			return {"ok": false, "errors": ["scenario command replay receipt is missing, malformed, or conflicts with its exact command"]}
		expected_phase = str(stored_envelope.get("expected_phase", ""))
	var authored_command := ScenarioSequenceRuntimeScript.command(
		command_id,
		current_world_node_id(),
		expected_phase,
		idempotency_key,
		payload,
		owner_namespace,
		stable_object_id,
		action_origin_owner_namespace,
		action_origin_stable_object_id,
		action_origin_receipt_key,
		action_origin_boundary_id,
		action_origin_fingerprint
	)
	if not replay_record.is_empty():
		if ScenarioSequenceRuntimeScript.content_fingerprint(authored_command) != str(replay_record.get("fingerprint", "")):
			return {"ok": false, "errors": ["scenario command idempotency_key was reused for a different command"]}
		var stored_descriptor := _copy_dict(replay_record.get("causal_action_descriptor", {}))
		var stored_descriptor_fingerprint := str(replay_record.get("causal_action_descriptor_fingerprint", ""))
		if stored_descriptor.is_empty() or stored_descriptor_fingerprint != ScenarioSequenceRuntimeScript.content_fingerprint(stored_descriptor):
			return {"ok": false, "errors": ["scenario command replay action origin, handler, inputs, or cost changed"]}
		var cached_result := _copy_dict(_copy_dict(sequence_state.get("command_results", {})).get(idempotency_key, {}))
		if not ScenarioSequenceRuntimeScript._valid_cached_command_result(cached_result, idempotency_key, authored_command):
			return {"ok": false, "errors": ["scenario command replay result is missing, malformed, or conflicts with its exact command"]}
		# An authenticated exact replay is a read. In particular, do not enter
		# ensure_sequence_state(), whose trusted causal rebuild deliberately omits
		# one-shot presentation effects and would consume a still-pending transition.
		cached_result["replayed"] = true
		cached_result["state"] = sequence_state.duplicate(true)
		cached_result["cost"] = 0
		cached_result["bankroll_delta"] = 0
		cached_result["bankroll_after"] = bankroll
		cached_result["result_receipt"] = {
			"receipt_id": str(cached_result.get("receipt_id", "")),
			"command_id": command_id,
			"scenario_id": str(definition.get("id", "")),
			"node_id": current_world_node_id(),
			"cost": 0,
			"replayed": true,
		}
		return cached_result
	# ScenarioEngine replaces only independently allocated top-level fields and
	# commits atomically. Keep a shallow transaction envelope so command latency
	# does not scale with every immutable room/content record.
	var candidate_environment := current_environment.duplicate(false)
	# This map is an internal presentation-to-state boundary: FoundationMain
	# derives it synchronously from the current composed interaction model. The
	# default is empty/fail-closed, and extension handlers cannot rewrite it.
	var result := ScenarioEngineScript.sequence_command(candidate_environment, definition, authored_command, {
		"available_funds": bankroll,
		"host_interaction_availability": host_interaction_availability.duplicate(true),
	})
	if not bool(result.get("ok", false)):
		var quarantine_state := _scenario_node_binding_quarantine_state(candidate_environment, definition)
		if not quarantine_state.is_empty():
			# Persist only the independently reproduced quarantine journal. Command
			# payload, presentation, funds, and every other host field remain the
			# exact pre-ingress values.
			current_environment["scenario_sequence_state"] = quarantine_state
			result["state"] = quarantine_state.duplicate(true)
		return result
	var cost := 0 if bool(result.get("replayed", false)) else maxi(0, int(result.get("cost", 0)))
	if cost > bankroll:
		return {"ok": false, "errors": ["scenario command cost is not payable"], "state": _copy_dict(current_environment.get("scenario_sequence_state", {})), "cost": 0}
	bankroll -= cost
	current_environment = candidate_environment
	result["cost"] = cost
	result["bankroll_delta"] = -cost
	result["bankroll_after"] = bankroll
	result["result_receipt"] = {
		"receipt_id": str(result.get("receipt_id", "")),
		"command_id": command_id,
		"scenario_id": str(definition.get("id", "")),
		"node_id": current_world_node_id(),
		"cost": cost,
		"replayed": bool(result.get("replayed", false)),
	}
	return result


func _scenario_node_binding_quarantine_state(candidate_environment: Dictionary, definition: Dictionary) -> Dictionary:
	var stored := _copy_dict(current_environment.get("scenario_sequence_state", {}))
	var stored_node := str(stored.get("node_id", "")).strip_edges()
	var physical_node := current_world_node_id()
	if stored.is_empty() or str(stored.get("status", "")) == ScenarioSequenceRuntimeScript.STATUS_CLEANED or stored_node.is_empty() or physical_node.is_empty() or stored_node == physical_node:
		return {}
	var expected_environment := current_environment.duplicate(true)
	var expected := ScenarioEngineScript.ensure_sequence_state(expected_environment, definition)
	var candidate := _copy_dict(candidate_environment.get("scenario_sequence_state", {}))
	var binding_error := "scenario progressed sequence state is bound to another world node; explicit migration is required"
	if str(expected.get("status", "")) != ScenarioSequenceRuntimeScript.STATUS_CLEANED \
		or not _copy_array(expected.get("errors", [])).has(binding_error) \
		or ScenarioSequenceRuntimeScript.content_fingerprint(candidate) != ScenarioSequenceRuntimeScript.content_fingerprint(expected):
		return {}
	return expected.duplicate(true)


func scenario_reenter_current(visit_id: String = "") -> Dictionary:
	var definition := _scenario_sequence_definition_readonly()
	if definition.is_empty():
		return {"ok": false, "inactive": true, "errors": []}
	var stable_visit := visit_id.strip_edges()
	if stable_visit.is_empty():
		stable_visit = "%s:%d" % [current_world_node_id(), _crew_action_index()]
	return ScenarioEngineScript.sequence_reentry(current_environment, definition, stable_visit)


func scenario_apply_expiry(boundary: String, boundary_serial: int = -1) -> Dictionary:
	var definition := _scenario_sequence_definition_readonly()
	if definition.is_empty():
		return {"ok": false, "inactive": true, "errors": []}
	var serial := _crew_action_index() if boundary_serial < 0 else boundary_serial
	return ScenarioEngineScript.sequence_expiry(current_environment, definition, boundary, serial)


func scenario_drain_transitions(reduced_motion: bool = false) -> Dictionary:
	var definition := _scenario_sequence_definition_readonly()
	if definition.is_empty():
		return {"ok": false, "inactive": true, "transitions": [], "errors": []}
	return ScenarioEngineScript.drain_sequence_transitions(current_environment, definition, reduced_motion)


func scenario_drain_event_requests() -> Dictionary:
	var definition := _scenario_sequence_definition_readonly()
	if definition.is_empty():
		return {"ok": false, "inactive": true, "requests": [], "errors": []}
	return ScenarioEngineScript.drain_sequence_event_requests(current_environment, definition)


# Migrates every persisted environment graph without changing scenario identity
# or touching snapshots that do not have a sequence overlay. SaveService restores
# through from_dict(), so this is the single migration seam for old slots.
func migrate_legacy_scenario_sequences() -> Dictionary:
	var report := {
		"schema_version": ScenarioSequenceRuntimeScript.STATE_SCHEMA_VERSION,
		"snapshots_checked": 0,
		"legacy_scenarios_checked": 0,
		"active_sequences": 0,
		"changed_snapshots": 0,
		"no_sequence_unchanged": 0,
		"scenario_ids": [],
		"changed_paths": [],
	}
	var current_result := _migrate_scenario_environment_graph(current_environment, "current_environment", report, str(current_environment.get("archetype_id", "")))
	if bool(current_result.get("changed", false)):
		current_environment = _copy_dict(current_result.get("environment", current_environment))
	var nodes := _copy_array(world_map.get("nodes", []))
	var map_changed := false
	for index in range(nodes.size()):
		if typeof(nodes[index]) != TYPE_DICTIONARY:
			continue
		var node := _copy_dict(nodes[index])
		var environment := _copy_dict(node.get("environment", {}))
		if environment.is_empty():
			continue
		var node_id := str(node.get("id", index)).strip_edges()
		var stored_result := _migrate_scenario_environment_graph(environment, "world_map.nodes.%s.environment" % node_id, report, str(node.get("archetype_id", "")))
		if bool(stored_result.get("changed", false)):
			node["environment"] = _copy_dict(stored_result.get("environment", environment))
			nodes[index] = node
			map_changed = true
	if map_changed:
		var next_map := world_map.duplicate(true)
		next_map["nodes"] = nodes
		world_map = next_map
	var rooms := grand_casino_room_states.duplicate(true)
	var rooms_changed := false
	for room_id_value in rooms.keys():
		var room_id := str(room_id_value)
		var room := _copy_dict(rooms.get(room_id_value, {}))
		var room_result := _migrate_scenario_environment_graph(room, "grand_casino_room_states.%s" % room_id, report, room_id)
		if bool(room_result.get("changed", false)):
			rooms[room_id_value] = _copy_dict(room_result.get("environment", room))
			rooms_changed = true
	if rooms_changed:
		grand_casino_room_states = rooms
	(report["scenario_ids"] as Array).sort()
	(report["changed_paths"] as Array).sort()
	return report


func _migrate_scenario_environment_graph(environment: Dictionary, path: String, report: Dictionary, fallback_archetype_id: String = "") -> Dictionary:
	if environment.is_empty():
		return {"changed": false, "environment": environment}
	var before := JSON.stringify(environment)
	var candidate := environment.duplicate(true)
	var graph_archetype_id := str(candidate.get("archetype_id", "")).strip_edges()
	if graph_archetype_id.is_empty():
		graph_archetype_id = str(_copy_dict(candidate.get("scenario_state", {})).get("archetype_id", "")).strip_edges()
	if graph_archetype_id.is_empty():
		graph_archetype_id = fallback_archetype_id.strip_edges()
	_migrate_scenario_snapshot_in_place(candidate, path, report, graph_archetype_id)
	var states := _copy_dict(candidate.get("layer_states", {}))
	for layer_id_value in states.keys():
		var layer_id := str(layer_id_value)
		var layer := _copy_dict(states.get(layer_id_value, {}))
		if layer.is_empty():
			continue
		_migrate_scenario_snapshot_in_place(layer, "%s.layer_states.%s" % [path, layer_id], report, graph_archetype_id)
		states[layer_id_value] = layer
	if not states.is_empty():
		candidate["layer_states"] = states
	var changed := before != JSON.stringify(candidate)
	if changed:
		report["changed_snapshots"] = int(report.get("changed_snapshots", 0)) + 1
		var changed_paths := _copy_array(report.get("changed_paths", []))
		if not changed_paths.has(path):
			changed_paths.append(path)
		report["changed_paths"] = changed_paths
	return {"changed": changed, "environment": candidate if changed else environment}


func _migrate_scenario_snapshot_in_place(environment: Dictionary, path: String, report: Dictionary, fallback_archetype_id: String = "") -> void:
	report["snapshots_checked"] = int(report.get("snapshots_checked", 0)) + 1
	var scenario_id := str(_copy_dict(environment.get("scenario_state", {})).get("id", environment.get("scenario_id", ""))).strip_edges()
	if scenario_id.is_empty():
		report["no_sequence_unchanged"] = int(report.get("no_sequence_unchanged", 0)) + 1
		return
	report["legacy_scenarios_checked"] = int(report.get("legacy_scenarios_checked", 0)) + 1
	var scenario_ids := _copy_array(report.get("scenario_ids", []))
	if not scenario_ids.has(scenario_id):
		scenario_ids.append(scenario_id)
	report["scenario_ids"] = scenario_ids
	var preferred := _scenario_sequence_migration_definition(environment, fallback_archetype_id)
	var result := ScenarioEngineScript.migrate_environment_sequence(environment, preferred, "%d:%s" % [seed_value, path])
	if bool(result.get("active", false)):
		report["active_sequences"] = int(report.get("active_sequences", 0)) + 1


# Old saves predate the durable suppression marker, so every independently
# persisted snapshot must re-derive it from the restored challenge before the
# content catalog is allowed to resolve a newly installed sequence overlay.
func _scenario_sequence_migration_definition(environment: Dictionary, fallback_archetype_id: String = "") -> Dictionary:
	var scenario_state := ScenarioEngineScript.normalize_state(environment.get("scenario_state", {}))
	var scenario_id := str(scenario_state.get("id", environment.get("scenario_id", ""))).strip_edges()
	var archetype_id := str(environment.get("archetype_id", "")).strip_edges()
	if archetype_id.is_empty():
		archetype_id = str(scenario_state.get("archetype_id", "")).strip_edges()
	if archetype_id.is_empty():
		archetype_id = fallback_archetype_id.strip_edges()
	if scenario_id.is_empty() or not scenario_sequence_is_suppressed(scenario_id, archetype_id):
		return {}
	scenario_state[ScenarioEngineScript.SEQUENCE_SUPPRESSION_KEY] = true
	environment["scenario_state"] = ScenarioEngineScript.normalize_state(scenario_state)
	var preferred := _copy_dict(environment.get("scenario_sequence_definition", {}))
	if str(preferred.get("id", preferred.get("scenario_id", ""))).strip_edges() != scenario_id:
		preferred = {}
	if preferred.is_empty():
		preferred = {"id": scenario_id, "archetype_id": archetype_id}
	return ScenarioEngineScript.suppress_sequence_definition(preferred)


func scenario_enqueue_fact(fact_type: String, producer: String, payload: Dictionary = {}, fact_id: String = "", node_id: String = "") -> Dictionary:
	if not current_environment.has("scenario_sequence_state") and not current_environment.has("scenario_sequence_pending_visit_id"):
		return {"ok": false, "inactive": true, "errors": []}
	var definition := _scenario_sequence_definition_readonly()
	if not ScenarioSequenceSchemaScript.is_sequence(definition):
		return {"ok": false, "inactive": true, "errors": []}
	if not _scenario_semantic_ready():
		return {"ok": false, "errors": ["Dynamic room sequence semantic records are not finalized."]}
	var state_value: Variant = current_environment.get("scenario_sequence_state", {})
	var state: Dictionary = state_value as Dictionary if typeof(state_value) == TYPE_DICTIONARY else {}
	if state.is_empty():
		return {"ok": false, "errors": ["Dynamic room sequence fact ingress requires initialized causal state."]}
	var target_node := current_world_node_id() if node_id.strip_edges().is_empty() else node_id.strip_edges()
	var serial := maxi(1, int(state.get("fact_serial_next", 1)))
	var stable_fact_id := fact_id.strip_edges()
	if stable_fact_id.is_empty():
		stable_fact_id = "%s:%s:%d" % [producer, fact_type, serial]
	var boundary_serial := maxi(int(state.get("boundary_serial", 0)), _crew_action_index())
	if not fact_id.strip_edges().is_empty():
		var prior_envelope: Dictionary = {}
		for queued_value in _copy_array(state.get("fact_queue", [])):
			var queued := _copy_dict(queued_value)
			if str(queued.get("fact_id", "")) == stable_fact_id:
				prior_envelope = queued
				break
		if prior_envelope.is_empty():
			for record_value in _copy_array(state.get("fact_receipt_records", [])):
				var record := _copy_dict(record_value)
				if str(record.get("receipt_key", "")) == stable_fact_id:
					prior_envelope = _copy_dict(record.get("envelope", {}))
					break
		if not prior_envelope.is_empty():
			serial = int(prior_envelope.get("producer_serial", serial))
			boundary_serial = int(prior_envelope.get("boundary_serial", boundary_serial))
	var typed_fact := ScenarioSequenceRuntimeScript.fact(
		fact_type,
		producer,
		target_node,
		stable_fact_id,
		serial,
		boundary_serial,
		payload
	)
	return ScenarioEngineScript.enqueue_sequence_fact(current_environment, definition, typed_fact)


func scenario_flush_facts(boundary_serial: int = -1) -> Dictionary:
	if not current_environment.has("scenario_sequence_state") and not current_environment.has("scenario_sequence_pending_visit_id"):
		return {"ok": false, "inactive": true, "processed": [], "errors": []}
	var definition := _scenario_sequence_definition_readonly()
	if definition.is_empty():
		return {"ok": false, "inactive": true, "processed": [], "errors": []}
	if not _scenario_semantic_ready():
		return {"ok": false, "processed": [], "errors": ["Dynamic room sequence semantic records are not finalized."]}
	var target := _crew_action_index() if boundary_serial < 0 else boundary_serial
	return ScenarioEngineScript.flush_sequence_facts(current_environment, definition, target)


func scenario_publish_game_result(result: Dictionary, deltas: Dictionary) -> void:
	var game_id := str(result.get("game_id", "")).strip_edges()
	if game_id.is_empty():
		return
	scenario_enqueue_fact("game_result", "game", {
		"game_id": game_id,
		"action_id": str(result.get("action_id", "")),
		"won": bool(result.get("won", false)),
		"ended": bool(deltas.get("ended", result.get("ended", false))),
		"bankroll_delta": int(deltas.get("bankroll_delta", 0)),
		"chips_delta": int(deltas.get("chips_delta", 0)),
		"applied_heat_delta": int(deltas.get("suspicion_delta", 0)),
	})


func scenario_publish_event_result(result: Dictionary) -> void:
	var resolved := bool(result.get("resolved", false))
	var deltas := _copy_dict(result.get("deltas", {}))
	for hook_value in _copy_array(deltas.get("event_hooks", [])):
		if typeof(hook_value) == TYPE_DICTIONARY and str((hook_value as Dictionary).get("type", "")) == "resolve_event":
			resolved = true
			break
	var event_id := str(result.get("event_id", result.get("source_id", "")))
	var resolution_id := str(result.get("resolution_id", "")).strip_edges()
	if resolution_id.is_empty():
		resolution_id = _scenario_pending_resolution_for_event(event_id)
	var choice_id := str(result.get("choice_id", result.get("action_id", ""))).strip_edges()
	# event_bridge resolution ids are catalog-proven event choice ids. Hosts that
	# report the authenticated pending resolution need not redundantly echo it as
	# action_id/choice_id.
	if choice_id.is_empty() and not resolution_id.is_empty():
		choice_id = resolution_id
	var payload := {
		"event_id": event_id,
		"choice_id": choice_id,
		"resolution_id": resolution_id,
		"resolved": resolved,
		"ok": bool(result.get("ok", false)),
	}
	# Public event results are broadcast by EventModule. Only route a result into
	# this room sequence when an authored event-result subscription observes that
	# event id (or intentionally declares a broad legacy observer). Direct runtime
	# ingress remains fail-closed for mismatched/correlation-forged facts.
	if not _scenario_observes_event_result(event_id):
		return
	scenario_enqueue_fact("event_result", "event", payload)


func _scenario_observes_event_result(event_id: String) -> bool:
	var definition := _scenario_sequence_definition_readonly()
	if not ScenarioSequenceSchemaScript.is_sequence(definition):
		return false
	for subscription_value in _copy_array(ScenarioSequenceSchemaScript.sequence(definition).get("fact_subscriptions", [])):
		var subscription := _copy_dict(subscription_value)
		if str(subscription.get("fact_type", "")) != "event_result":
			continue
		var predicate := _copy_dict(subscription.get("payload_equals", {}))
		if not predicate.has("event_id") or str(predicate.get("event_id", "")) == event_id:
			return true
	return false


func _scenario_pending_resolution_for_event(event_id: String) -> String:
	var state := ScenarioSequenceRuntimeScript.normalize_state(current_environment.get("scenario_sequence_state", {}))
	var history := _copy_array(state.get("event_request_history", []))
	var receipts := _string_array(_copy_array(state.get("event_choice_receipts", [])))
	for index in range(history.size() - 1, -1, -1):
		var request := _copy_dict(history[index])
		if str(request.get("event_id", "")) != event_id:
			continue
		var resolution_id := str(request.get("resolution_id", "")).strip_edges()
		if resolution_id.is_empty():
			continue
		var already_resolved := false
		for receipt_value in receipts:
			if str(receipt_value).begins_with("%s:" % resolution_id):
				already_resolved = true
				break
		if not already_resolved:
			return resolution_id
	return ""


func scenario_publish_service_result(kind: String, hook_id: String, result: Dictionary) -> void:
	scenario_enqueue_fact("service_result", "service", {
		"kind": kind,
		"service_id": hook_id,
		"ok": bool(result.get("ok", false)),
		"action_id": str(result.get("action_id", "")),
	})


func scenario_publish_travel(fact_type: String, source_id: String, target_id: String, travel_kind: String = "world") -> Dictionary:
	if not ["travel_departed", "travel_arrived"].has(fact_type):
		return {"ok": false, "errors": ["Scenario travel fact type is unregistered."]}
	var definition := _scenario_sequence_definition_readonly()
	if ScenarioSequenceSchemaScript.is_sequence(definition):
		var state := ScenarioEngineScript.ensure_sequence_state(current_environment.duplicate(true), definition)
		if not state.is_empty() and str(state.get("status", "")) != ScenarioSequenceRuntimeScript.STATUS_ACTIVE:
			return {"ok": true, "inactive": true, "errors": []}
	var result := scenario_enqueue_fact(fact_type, "travel", {"source_id": source_id, "target_id": target_id, "travel_kind": travel_kind})
	if bool(result.get("inactive", false)):
		return {"ok": true, "inactive": true, "errors": []}
	return result


func _scenario_publish_crew_change(member_id: String, change: String, value: Variant) -> void:
	scenario_enqueue_fact("crew_changed", "crew", {"member_id": member_id, "change": change, "value": value})


func _scenario_publish_crew_job(job: Dictionary) -> void:
	if job.is_empty():
		return
	scenario_enqueue_fact("crew_job_changed", "crew", {"job_id": str(job.get("id", "")), "definition_id": str(job.get("definition_id", "")), "member_id": str(job.get("member_id", "")), "status": str(job.get("status", "")), "outcome": str(job.get("outcome", ""))})


func _scenario_publish_heat_change(previous_level: int, applied_delta: int, source: String) -> void:
	if applied_delta == 0:
		return
	var next_level := suspicion_level()
	scenario_enqueue_fact("heat_changed", "heat", {"previous": previous_level, "current": next_level, "applied_delta": applied_delta, "source": source})
	var previous_band := _scenario_heat_band(previous_level)
	var next_band := _scenario_heat_band(next_level)
	if previous_band != next_band:
		scenario_enqueue_fact("heat_band_changed", "heat", {"previous_band": previous_band, "current_band": next_band, "current": next_level, "source": source})


static func _scenario_heat_band(value: int) -> String:
	if value >= 75: return "critical"
	if value >= 50: return "hot"
	if value >= 25: return "caution"
	return "quiet"


func recent_scenario_ids(archetype_id: String) -> Array:
	var value: Variant = scenario_recent_by_archetype.get(archetype_id, [])
	return (value as Array).duplicate(false) if typeof(value) == TYPE_ARRAY else []


func remember_scenario_selection(archetype_id: String, scenario_id: String) -> void:
	var clean_archetype := archetype_id.strip_edges()
	var clean_scenario := scenario_id.strip_edges()
	if clean_archetype.is_empty() or clean_scenario.is_empty():
		return
	var recent := recent_scenario_ids(clean_archetype)
	recent.push_front(clean_scenario)
	while recent.size() > 3:
		recent.pop_back()
	scenario_recent_by_archetype[clean_archetype] = recent


func is_layered_environment(environment: Dictionary = {}) -> bool:
	var source := current_environment if environment.is_empty() else environment
	return int(source.get("environment_layer_schema_version", 0)) > 0 \
		and not str(source.get("current_layer_id", "")).strip_edges().is_empty()


func environment_layer_access_status(target_layer_id: String) -> Dictionary:
	var target_id := target_layer_id.strip_edges()
	if not is_layered_environment() or not _string_array(_copy_array(current_environment.get("layer_ids", []))).has(target_id):
		return {"available": false, "hidden": true, "reason": "That room is not part of this venue."}
	if target_id == str(current_environment.get("current_layer_id", "")):
		return {"available": false, "hidden": true, "reason": "You are already here."}
	var transition: Dictionary = {}
	for transition_value in _copy_array(current_environment.get("layer_transitions", [])):
		if typeof(transition_value) == TYPE_DICTIONARY and str((transition_value as Dictionary).get("target_layer_id", "")) == target_id:
			transition = (transition_value as Dictionary).duplicate(true)
			break
	if transition.is_empty():
		return {"available": false, "hidden": true, "reason": "There is no door that way."}
	var discovery := _copy_dict(current_environment.get("layer_discovery", {}))
	var already_discovered := bool(discovery.get(target_id, false))
	if already_discovered or not bool(transition.get("requires_discovered", false)) and _copy_array(transition.get("access_paths", [])).is_empty():
		return {"available": true, "hidden": false, "access_method": "discovered" if already_discovered else "open", "discover_on_enter": false}
	for path_value in _copy_array(transition.get("access_paths", [])):
		if typeof(path_value) != TYPE_DICTIONARY:
			continue
		var path: Dictionary = path_value
		if not _environment_layer_access_path_allows(path, discovery, target_id):
			continue
		return {
			"available": true,
			"hidden": false,
			"access_method": str(path.get("method", "access")),
			"discover_on_enter": not already_discovered,
		}
	var hidden := bool(transition.get("hidden_until_available", false))
	return {
		"available": false,
		"hidden": hidden,
		"locked": not hidden,
		"reason": str(transition.get("locked_reason", "The door stays shut.")),
	}


func discover_environment_layer(layer_id: String, method: String = "discovery") -> bool:
	var clean_id := layer_id.strip_edges()
	if not is_layered_environment() or not _string_array(_copy_array(current_environment.get("layer_ids", []))).has(clean_id):
		return false
	var discovery := _copy_dict(current_environment.get("layer_discovery", {}))
	var was_discovered := bool(discovery.get(clean_id, false))
	discovery[clean_id] = true
	current_environment["layer_discovery"] = discovery
	var states := _copy_dict(current_environment.get("layer_states", {}))
	for state_id_value in states.keys():
		var state := _copy_dict(states.get(state_id_value, {}))
		state["layer_discovery"] = discovery.duplicate(true)
		states[state_id_value] = state
	current_environment["layer_states"] = states
	if not was_discovered:
		log_story({
			"type": "environment_layer_discovered",
			"environment_id": str(current_environment.get("id", "")),
			"environment_archetype_id": str(current_environment.get("archetype_id", "")),
			"layer": clean_id,
			"method": method.strip_edges(),
			"message": "A room inside the venue opens.",
		})
	return true


func store_current_environment_layer_state() -> void:
	if not is_layered_environment():
		return
	var current_id := str(current_environment.get("current_layer_id", "")).strip_edges()
	var states := _copy_dict(current_environment.get("layer_states", {}))
	var body := current_environment.duplicate(true)
	body.erase("layer_states")
	body.erase("active_game_id")
	_strip_scenario_semantic_ephemera(body)
	states[current_id] = body
	current_environment["layer_states"] = states


func environment_layer_state(layer_id: String) -> Dictionary:
	if not is_layered_environment():
		return {}
	store_current_environment_layer_state()
	return _copy_dict(_copy_dict(current_environment.get("layer_states", {})).get(layer_id.strip_edges(), {}))


func install_environment_layer_state(layer_id: String, layer_state: Dictionary) -> bool:
	var target_id := layer_id.strip_edges()
	if not is_layered_environment() or layer_state.is_empty():
		return false
	store_current_environment_layer_state()
	var source := current_environment
	var states := _copy_dict(source.get("layer_states", {}))
	var target := layer_state.duplicate(true)
	for key in ["environment_layer_schema_version", "default_layer_id", "layer_ids", "layer_discovery"]:
		target[key] = source.get(key)
	target["current_layer_id"] = target_id
	target["layer_states"] = states
	target["world_node_id"] = str(source.get("world_node_id", source.get("archetype_id", "")))
	target["world_map_travel"] = bool(source.get("world_map_travel", false))
	target["display_name"] = str(source.get("display_name", target.get("display_name", "")))
	target["turns"] = int(source.get("turns", target.get("turns", 0)))
	for clock_key in ["entered_game_clock_minutes", "departed_game_clock_minutes", "environment_visit_id", "night_instance_id", "context_instance_id"]:
		if source.has(clock_key):
			target[clock_key] = source.get(clock_key)
	var scenario_state := ScenarioEngineScript.normalize_state(source.get("scenario_state", {}))
	if not scenario_state.is_empty():
		ScenarioEngineScript.reconcile_environment(target, scenario_state)
	current_environment = _normalize_environment(target)
	ScenarioEngineScript.migrate_environment_sequence(
		current_environment,
		{},
		"%d:layer:%s:%s" % [seed_value, str(current_environment.get("world_node_id", current_environment.get("archetype_id", ""))), target_id]
	)
	if ScenarioSequenceSchemaScript.is_sequence(_scenario_sequence_definition_readonly()):
		current_environment["scenario_sequence_pending_visit_id"] = str(current_environment.get("environment_visit_id", ""))
	CharacterChainModelScript.apply_to_environment(self, current_environment)
	return true


func _environment_layer_access_path_allows(path: Dictionary, discovery: Dictionary, target_id: String) -> bool:
	if bool(path.get("requires_discovered", false)) and not bool(discovery.get(target_id, false)):
		return false
	var minimum_rank := str(path.get("min_crew_rank", "")).strip_edges()
	if not minimum_rank.is_empty():
		var rank_ids := CrewStateModelScript.RANK_IDS
		if not rank_ids.has(minimum_rank) or rank_ids.find(str(crew_standing().get("rank", "stranger"))) < rank_ids.find(minimum_rank):
			return false
	for flag_id in _string_array(_copy_array(path.get("flags_all", []))):
		if not _environment_layer_flag_truthy(flag_id):
			return false
	var flags_any := _string_array(_copy_array(path.get("flags_any", [])))
	if not flags_any.is_empty():
		var found := false
		for flag_id in flags_any:
			if _environment_layer_flag_truthy(flag_id):
				found = true
				break
		if not found:
			return false
	return true


func _environment_layer_flag_truthy(flag_id: String) -> bool:
	var value: Variant = story_flags.get(flag_id, narrative_flags.get(flag_id, false))
	return bool(value) if typeof(value) == TYPE_BOOL else int(value) != 0 if typeof(value) == TYPE_INT else not str(value).strip_edges().is_empty()


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
	world_map = WorldMap.store_environment(world_map, node_id, _environment_for_persistent_storage(stored_environment))


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


# Internal runtime view for schedulers that only inspect or deliberately update
# the stored room. Player-facing restoration continues to use the owned copy
# above, while this avoids deep-copying every cabinet on every foreground frame.
func peek_grand_casino_room_environment(archetype_id: String) -> Dictionary:
	var room: Variant = grand_casino_room_states.get(archetype_id.strip_edges(), {})
	return room as Dictionary if typeof(room) == TYPE_DICTIONARY else {}


func grand_casino_room_access_status(target_archetype_id: String, high_limit_buy_in: int = 60) -> Dictionary:
	var target_id := target_archetype_id.strip_edges()
	if not is_grand_casino_environment():
		return {"available": false, "reason": "The casino interior is not available here."}
	if tutorial_main_floor_only():
		if target_id == GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID:
			return {"available": false, "locked": true, "reason": "Locked for this lesson. The Main Floor has everything you need; a Players Card can open High-Limit on later runs."}
		if target_id == GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID:
			return {"available": false, "locked": true, "reason": "Lesson lock: Rourke's Back Room can wait its turn."}
		if target_id == GRAND_CASINO_ARCHETYPE_ID or target_id == GRAND_CASINO_CAGE_ARCHETYPE_ID:
			return {"available": true, "access_method": "tutorial_main_floor", "cost": 0}
	if bool(narrative_flags.get("grand_casino_showdown_active", false)):
		if target_id == GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID and str(narrative_flags.get("grand_casino_showdown_step", "")) == GRAND_CASINO_SHOWDOWN_STEP_DUEL:
			return {"available": true, "access_method": "showdown", "cost": 0}
		return {"available": false, "locked": true, "reason": "Rourke keeps that door shut until the duel is done."}
	if target_id == GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID:
		return {"available": false, "locked": true, "reason": "Locked. Rourke opens it only when the house calls."}
	if target_id == GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID:
		if bool(narrative_flags.get("grand_casino_high_limit_access", false)):
			return {"available": true, "access_method": str(narrative_flags.get("grand_casino_high_limit_access_method", "card")), "cost": 0}
		var buy_in := maxi(0, high_limit_buy_in)
		if bankroll < buy_in:
			return {"available": false, "locked": true, "cash_buy_in_required": true, "cost": buy_in, "reason": "High-Limit requires Silver card access or a $%d cash buy-in." % buy_in}
		return {"available": true, "cash_buy_in_required": true, "access_method": "cash_buy_in", "cost": buy_in}
	if target_id == GRAND_CASINO_ARCHETYPE_ID or target_id == GRAND_CASINO_CAGE_ARCHETYPE_ID:
		return {"available": true, "access_method": "interior", "cost": 0}
	return {"available": false, "reason": "That room is not part of the Grand Casino."}


func enter_world_node(node_id: String, environment_data: Dictionary) -> void:
	if world_map.is_empty() or node_id.strip_edges().is_empty():
		return
	world_map = WorldMap.enter_node(world_map, node_id, _environment_for_persistent_storage(environment_data))
	_reconcile_tier_two_casino_spawn_eligibility()
	_apply_town_sweep_generation_context(current_environment)
	_check_police_sweep_boundary()


# Tier-2 casino routes are intentionally hidden at spawn. Open their spawn gates
# once the player has either found the Underground or visited two distinct
# Tier-1 casinos. The nodes remain hidden until normal neighbor discovery finds
# each one; this milestone must not reveal both venues immediately.
func _reconcile_tier_two_casino_spawn_eligibility() -> void:
	if world_map.is_empty():
		return
	var nodes_value: Variant = world_map.get("nodes", [])
	if typeof(nodes_value) != TYPE_ARRAY:
		return
	var visited_tier_one_casino_ids: Array = []
	var tier_two_casino_ids: Array = []
	var underground_visited := false
	var every_tier_two_casino_spawn_enabled := true
	for node_value in nodes_value as Array:
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", "")).strip_edges()
		var node_kind := str(node.get("kind", "")).strip_edges().to_lower()
		var node_tier := maxi(1, int(node.get("tier", 1)))
		var visited := str(node.get("state", WorldMap.STATE_HIDDEN)) == WorldMap.STATE_VISITED
		if visited and node_tier == 1 and node_kind == "casino" and not visited_tier_one_casino_ids.has(node_id):
			visited_tier_one_casino_ids.append(node_id)
		if visited and node_id == TIER_TWO_UNDERGROUND_SOURCE_ID:
			underground_visited = true
		if node_tier == 2 and node_kind == "casino":
			tier_two_casino_ids.append(node_id)
			if not bool(node.get("route_spawn_open", false)):
				every_tier_two_casino_spawn_enabled = false
	if tier_two_casino_ids.is_empty():
		return
	var threshold_met := underground_visited or visited_tier_one_casino_ids.size() >= TIER_TWO_REQUIRED_TIER_ONE_CASINO_VISITS
	if not threshold_met:
		return
	if not every_tier_two_casino_spawn_enabled:
		world_map = WorldMap.enable_node_spawns(world_map, tier_two_casino_ids)
	narrative_flags[TIER_TWO_LOCATION_SPAWN_FLAG] = true
	narrative_flags[TIER_TWO_LOCATION_SPAWN_REASON_FLAG] = "underground_visit" if underground_visited else "two_tier_one_casinos"
	narrative_flags[TIER_TWO_LOCATION_SPAWN_VISITS_FLAG] = visited_tier_one_casino_ids.duplicate()


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


func preview_grand_casino_wager_funding(game_id: String, wager_amount: int, environment: Dictionary = {}) -> Dictionary:
	# Pure funding lease preview used by the Blackjack transaction authority.
	# In particular, cash does not equal one chip when the venue exchange rate is
	# greater than one, so wager_capacity_for_game() is not a sufficient check.
	var amount := maxi(0, wager_amount)
	if amount <= 0:
		return {"ok": true, "wager": amount, "existing_chips_used": 0, "chips_bought": 0, "cash_used": 0}
	if not grand_casino_game_uses_chips(game_id, environment):
		return {
			"ok": amount <= maxi(0, bankroll),
			"wager": amount,
			"existing_chips_used": 0,
			"chips_bought": 0,
			"cash_used": amount,
			"message": "You do not have enough bankroll for that wager." if amount > maxi(0, bankroll) else "",
		}
	var existing_chips_used := mini(maxi(0, grand_casino_chips), amount)
	var required_chips := maxi(0, amount - existing_chips_used)
	var rate := grand_casino_chip_exchange_rate()
	var cash_cost := required_chips * rate
	return {
		"ok": cash_cost <= maxi(0, bankroll),
		"wager": amount,
		"existing_chips_used": existing_chips_used,
		"chips_bought": required_chips if cash_cost <= maxi(0, bankroll) else 0,
		"cash_used": cash_cost if cash_cost <= maxi(0, bankroll) else 0,
		"message": "That wager needs %d chips plus $%d cash, but you only have $%d cash available." % [existing_chips_used, cash_cost, bankroll] if cash_cost > maxi(0, bankroll) else "",
	}


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
		return {"ok": false, "message": "The Cage goes quiet while Rourke deals."}
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
	if str(current_environment.get("archetype_id", "")) != GRAND_CASINO_CAGE_ARCHETYPE_ID:
		return {"ok": false, "message": "Chip redemption is available at Linda's Cage counter."}
	if bool(narrative_flags.get("grand_casino_walked_with_chips", false)):
		return {"ok": false, "message": "Rourke closed the Cage account after the door found you."}
	if bool(narrative_flags.get("grand_casino_showdown_active", false)) and str(narrative_flags.get("grand_casino_duel_outcome", "")) != GrandCasinoDuelModelScript.OUTCOME_WALK_OUT_CLEAN:
		return {"ok": false, "message": "The Cage goes quiet while Rourke deals."}
	var amount := grand_casino_chips if chip_amount < 0 else chip_amount
	var rate := maxi(1, cash_rate)
	var preview := CageEconomyModelScript.cashout_preview(
		grand_casino_chips,
		amount,
		rate,
		grand_casino_atm_debt(),
		bankroll
	)
	if not bool(preview.get("ok", false)):
		return {"ok": false, "message": str(preview.get("reason", "You do not have that many chips to redeem.")), "preview": preview}
	var debt_paid := int(preview.get("debt_paid", 0))
	grand_casino_chips = int(preview.get("chips_after", grand_casino_chips))
	bankroll = int(preview.get("cash_after", bankroll))
	_set_grand_casino_atm_debt(int(preview.get("debt_after", grand_casino_atm_debt())))
	if debt_paid > 0 and narrative_flags.has("grand_casino_entry_bankroll"):
		narrative_flags["grand_casino_entry_bankroll"] = int(narrative_flags.get("grand_casino_entry_bankroll", 0)) - debt_paid
	_refresh_economy(true)
	log_story({
		"type": "grand_casino_chip_cashout",
		"chips_redeemed": amount,
		"exchange_rate": rate,
		"gross_value": int(preview.get("gross_value", 0)),
		"debt_paid": debt_paid,
		"debt_remaining": grand_casino_atm_debt(),
		"cash_paid": int(preview.get("cash_paid", 0)),
		"bankroll_delta": int(preview.get("cash_paid", 0)),
		"chips_delta": -amount,
		"message": "Linda redeems %d chips: $%d to the marker, $%d cash, $%d marker remaining." % [amount, debt_paid, int(preview.get("cash_paid", 0)), grand_casino_atm_debt()],
	})
	evaluate_environment_objective_state()
	return preview.merged({
		"ok": true,
		"cash_delta": int(preview.get("cash_paid", 0)),
		"chips_delta": -amount,
		"message": "Redeemed %d chips. Marker paid $%d; cash paid $%d; marker remaining $%d." % [amount, debt_paid, int(preview.get("cash_paid", 0)), grand_casino_atm_debt()],
	}, true)


func grand_casino_atm_debt() -> int:
	var index := _debt_index(CageEconomyModelScript.ATM_DEBT_ID)
	if index < 0 or typeof(debt[index]) != TYPE_DICTIONARY:
		return 0
	return maxi(0, int((debt[index] as Dictionary).get("balance", 0)))


func grand_casino_atm_debt_entry() -> Dictionary:
	var index := _debt_index(CageEconomyModelScript.ATM_DEBT_ID)
	return (debt[index] as Dictionary).duplicate(true) if index >= 0 and typeof(debt[index]) == TYPE_DICTIONARY else {}


func grand_casino_atm_status() -> Dictionary:
	var balance := grand_casino_atm_debt()
	var next_boundary := CageEconomyModelScript.next_interest_boundary(game_clock_minutes)
	return {
		"debt": balance,
		"cash": bankroll,
		"loan_increment": CageEconomyModelScript.LOAN_INCREMENT,
		"loan_cap": CageEconomyModelScript.LOAN_CAP,
		"origination_fee": CageEconomyModelScript.ORIGINATION_FEE,
		"daily_interest_rate": CageEconomyModelScript.DAILY_INTEREST_RATE,
		"interest_minute_of_day": CageEconomyModelScript.INTEREST_MINUTE_OF_DAY,
		"next_interest_absolute_minute": next_boundary,
		"projected_next_balance": CageEconomyModelScript.interest_balance(balance),
		"available_credit": maxi(0, CageEconomyModelScript.LOAN_CAP - balance),
		"interest_boundary_index": grand_casino_atm_interest_boundary_index,
	}


func borrow_from_grand_casino_atm(amount: int) -> Dictionary:
	if str(current_environment.get("archetype_id", "")) != GRAND_CASINO_CAGE_ARCHETYPE_ID:
		return {"ok": false, "message": "The Grand Casino ATM is inside the Cage."}
	var preview := CageEconomyModelScript.borrow_preview(grand_casino_atm_debt(), amount)
	if not bool(preview.get("ok", false)):
		return {"ok": false, "message": str(preview.get("reason", "The ATM declines that draw.")), "preview": preview}
	var cash_received := int(preview.get("cash_received", 0))
	_set_grand_casino_atm_debt(int(preview.get("debt_after", 0)))
	bankroll += cash_received
	if narrative_flags.has("grand_casino_entry_bankroll"):
		narrative_flags["grand_casino_entry_bankroll"] = int(narrative_flags.get("grand_casino_entry_bankroll", 0)) + cash_received
	_refresh_economy(true)
	log_story({
		"type": "lender_hook",
		"id": "grand_casino_atm",
		"label": "Grand Casino ATM",
		"debt_id": CageEconomyModelScript.ATM_DEBT_ID,
		"lender_id": "grand_casino_atm",
		"debt_changes": [grand_casino_atm_debt_entry()],
		"amount": cash_received,
		"bankroll_delta": cash_received,
		"balance": grand_casino_atm_debt(),
		"message": "The Grand Casino ATM advances $%d cash. House marker: $%d." % [cash_received, grand_casino_atm_debt()],
	})
	return preview.merged({
		"ok": true,
		"cash_delta": cash_received,
		"message": "Borrowed $%d cash. Grand Casino marker: $%d." % [cash_received, grand_casino_atm_debt()],
	}, true)


func repay_grand_casino_atm_debt(amount: int = -1) -> Dictionary:
	if str(current_environment.get("archetype_id", "")) != GRAND_CASINO_CAGE_ARCHETYPE_ID:
		return {"ok": false, "message": "Cash marker payments are accepted at the Cage ATM."}
	var balance := grand_casino_atm_debt()
	var requested := mini(balance, bankroll) if amount < 0 else amount
	var preview := CageEconomyModelScript.repayment_preview(balance, bankroll, requested)
	if not bool(preview.get("ok", false)):
		return {"ok": false, "message": str(preview.get("reason", "The ATM cannot accept that payment.")), "preview": preview}
	var payment := int(preview.get("amount", 0))
	bankroll -= payment
	_set_grand_casino_atm_debt(int(preview.get("debt_after", 0)))
	if narrative_flags.has("grand_casino_entry_bankroll"):
		narrative_flags["grand_casino_entry_bankroll"] = int(narrative_flags.get("grand_casino_entry_bankroll", 0)) - payment
	_refresh_economy(true)
	log_story({
		"type": "debt_paid" if grand_casino_atm_debt() <= 0 else "debt_payment",
		"debt_id": CageEconomyModelScript.ATM_DEBT_ID,
		"lender_id": "grand_casino_atm",
		"payment": payment,
		"bankroll_delta": -payment,
		"balance": grand_casino_atm_debt(),
		"message": "Paid $%d cash toward the Grand Casino marker. Balance: $%d." % [payment, grand_casino_atm_debt()],
	})
	evaluate_environment_objective_state()
	return preview.merged({
		"ok": true,
		"cash_delta": -payment,
		"payment": payment,
		"paid_off": grand_casino_atm_debt() <= 0,
		"message": "Paid $%d. Grand Casino marker: $%d." % [payment, grand_casino_atm_debt()],
	}, true)


func grand_casino_atm_pending_interest_notifications() -> Array:
	return grand_casino_atm_interest_notifications.duplicate(true)


func consume_grand_casino_atm_interest_notifications() -> Array:
	var result := grand_casino_atm_interest_notifications.duplicate(true)
	grand_casino_atm_interest_notifications.clear()
	return result


func _set_grand_casino_atm_debt(balance: int) -> void:
	var normalized_balance := maxi(0, balance)
	var index := _debt_index(CageEconomyModelScript.ATM_DEBT_ID)
	if normalized_balance <= 0:
		if index >= 0:
			debt.remove_at(index)
		return
	var entry := {
		"id": CageEconomyModelScript.ATM_DEBT_ID,
		"lender_id": "grand_casino_atm",
		"lender_name": "Grand Casino ATM",
		"status": "active",
		"debt_kind": "casino_marker",
		"balance": normalized_balance,
		"principal": normalized_balance,
		"deadline_turns": 0,
		"turns_remaining": 0,
		"no_default": true,
		"no_collector": true,
		"stackable": false,
	}
	if index >= 0:
		var existing := (debt[index] as Dictionary).duplicate(true)
		entry["principal"] = maxi(int(existing.get("principal", 0)), normalized_balance)
		debt[index] = entry
	else:
		debt.append(entry)


func _process_grand_casino_atm_interest_boundaries(previous_minutes: int, current_minutes: int) -> void:
	var crossings := CageEconomyModelScript.crossed_interest_boundary_indices(
		previous_minutes,
		current_minutes,
		grand_casino_atm_interest_boundary_index
	)
	for boundary_value in crossings:
		var boundary_index := int(boundary_value)
		grand_casino_atm_interest_boundary_index = maxi(grand_casino_atm_interest_boundary_index, boundary_index)
		var old_balance := grand_casino_atm_debt()
		if old_balance <= 0:
			continue
		var new_balance := CageEconomyModelScript.interest_balance(old_balance)
		var interest_added := new_balance - old_balance
		_set_grand_casino_atm_debt(new_balance)
		var notification := {
			"boundary_index": boundary_index,
			"absolute_minute": CageEconomyModelScript.INTEREST_MINUTE_OF_DAY + boundary_index * CageEconomyModelScript.MINUTES_PER_DAY,
			"old_balance": old_balance,
			"rate": CageEconomyModelScript.DAILY_INTEREST_RATE,
			"interest_added": interest_added,
			"new_balance": new_balance,
			"message": "3:00 AM marker interest added $%d. Grand Casino ATM balance: $%d." % [interest_added, new_balance],
		}
		grand_casino_atm_interest_notifications.append(notification)
		if grand_casino_atm_interest_notifications.size() > MAX_ATM_INTEREST_NOTIFICATIONS:
			grand_casino_atm_interest_notifications.pop_front()
		log_story({
			"type": "debt_interest",
			"debt_id": CageEconomyModelScript.ATM_DEBT_ID,
			"old_balance": old_balance,
			"rate": CageEconomyModelScript.DAILY_INTEREST_RATE,
			"interest_added": interest_added,
			"new_balance": new_balance,
			"boundary_index": boundary_index,
			"message": str(notification.get("message", "")),
		})


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
	var result_environment := {
		"id": str(result.get("environment_id", "")),
		"archetype_id": str(result.get("environment_archetype_id", "")),
	}
	if not grand_casino_game_uses_chips(game_id, result_environment):
		return routed
	var chips_delta := int(routed.get("bankroll_delta", result.get("bankroll_delta", 0)))
	var funding_amount := _grand_casino_result_wager_funding_amount(result, chips_delta)
	if funding_amount > grand_casino_chips:
		var funding := fund_grand_casino_wager(game_id, funding_amount, result_environment)
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


func consume_blackjack_authority_result_receipt(result: Dictionary) -> bool:
	var game_id := str(result.get("game_id", result.get("source_id", "")))
	if game_id.is_empty():
		return false
	if typeof(result.get("blackjack_host_apply_receipt", null)) != TYPE_DICTIONARY:
		return false
	var receipt: Dictionary = result.get("blackjack_host_apply_receipt", {})
	var game_states: Dictionary = current_environment.get("game_states", {}) if typeof(current_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	if typeof(game_states.get(game_id, null)) != TYPE_DICTIONARY:
		return false
	var table: Dictionary = game_states.get(game_id, {})
	var pending: Variant = table.get("_blackjack_pending_apply_receipt", null)
	var binding := "%s:%s:%s" % [game_id, str(current_environment.get("id", "unknown")), str(current_environment.get("archetype_id", "unknown"))]
	if not BlackjackActionAuthorityScript.valid_receipt(receipt, pending, result, binding):
		return false
	# Consume before applying any deltas. Foundation applies only to a detached
	# candidate, so a later failure discards both this consumption and all effects.
	table.erase("_blackjack_pending_apply_receipt")
	game_states[game_id] = table
	current_environment["game_states"] = game_states
	return true


func blackjack_authority_checkpoint_fingerprint() -> String:
	# The durable authority ledger is reconciled against the canonical balances
	# and RNG cursor on restore. Neither caller-authored UI nor ledger content is
	# allowed to supply these values.
	return GameRitualRuntimeScript.canonical_fingerprint({
		"bankroll": bankroll,
		"grand_casino_chips": grand_casino_chips,
		"rng_seed": rng_seed,
		"rng_state": rng_state,
	})


func action_authority_checkpoint_fingerprint() -> String:
	return blackjack_authority_checkpoint_fingerprint()


func _reconcile_blackjack_authority_restore() -> void:
	# A not-yet-started room is represented by an empty dictionary. Preserve that
	# byte-exact save state instead of materializing a synthetic game_states key.
	if current_environment.is_empty():
		return
	var game_states: Dictionary = current_environment.get("game_states", {}) if typeof(current_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	for game_id_value in game_states.keys():
		var game_id := str(game_id_value)
		if typeof(game_states.get(game_id, null)) != TYPE_DICTIONARY:
			continue
		var table: Dictionary = (game_states.get(game_id, {}) as Dictionary).duplicate(true)
		if not table.has(BlackjackActionAuthorityScript.LEDGER_KEY):
			continue
		var binding := "%s:%s:%s" % [game_id, str(current_environment.get("id", "unknown")), str(current_environment.get("archetype_id", "unknown"))]
		var ledger := BlackjackActionAuthorityScript.validate_persisted_ledger(
			table.get(BlackjackActionAuthorityScript.LEDGER_KEY),
			binding,
			blackjack_authority_checkpoint_fingerprint()
		)
		if ledger.is_empty():
			table.erase(BlackjackActionAuthorityScript.LEDGER_KEY)
		else:
			table[BlackjackActionAuthorityScript.LEDGER_KEY] = ledger
		game_states[game_id] = table
	current_environment["game_states"] = game_states


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
	elif game_id == "craps":
		wager = maxi(wager, int(result.get("craps_total_wager", 0)))
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
	var active_location := location_id.is_empty() or location_id == current_location_id or current_location_id.is_empty()
	var tutorial_heat_intervention := is_tutorial_run() \
		and active_location \
		and adjusted_amount > 0 \
		and base_level < TUTORIAL_HEAT_CEILING \
		and base_level + adjusted_amount >= TUTORIAL_HEAT_CEILING
	var ceiling := TUTORIAL_HEAT_CEILING if is_tutorial_run() else 100
	if str(context.get("source_id", "")) == "blackjack":
		ceiling = mini(ceiling, BLACKJACK_BACKOFF_HEAT)
	var level := clampi(base_level + adjusted_amount, 0, ceiling)
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
		var distraction_liability := CrewPlayModelScript.distraction_grievance_candidate(
			crew_play_state, _crew_action_index(), base_level, level
		)
		if not distraction_liability.is_empty():
			grievance_add({
				"member_id": str(distraction_liability.get("member_id", "")),
				"kind": "distraction_heat_dumped",
				"weight": 2,
				"source_ref": _crew_distraction_grievance_source(distraction_liability),
			})
			crew_play_state = CrewPlayModelScript.mark_distraction_grievance_recorded(crew_play_state)
	if tutorial_heat_intervention:
		_apply_tutorial_heat_intervention(location_id, cue_id)
	if applied_amount != 0 and active_location:
		heat_changed.emit(applied_amount, suspicion_level(), cue_id, context.duplicate(true))
		_scenario_publish_heat_change(base_level, applied_amount, cue_id)
	_evaluate_immediate_terminal_state(defer_bankroll_zero)
	return applied_amount


func _apply_tutorial_heat_intervention(location_id: String, cue_id: String) -> void:
	var current_location_id := current_suspicion_location_id()
	if location_id.is_empty():
		suspicion["level"] = TUTORIAL_HEAT_INTERVENTION_LEVEL
	elif location_id == current_location_id or current_location_id.is_empty():
		var levels := _local_suspicion_levels()
		levels[location_id] = TUTORIAL_HEAT_INTERVENTION_LEVEL
		suspicion["local_levels"] = levels
		suspicion["level"] = TUTORIAL_HEAT_INTERVENTION_LEVEL
	else:
		return
	var serial := int(narrative_flags.get("tutorial_heat_intervention_serial", 0)) + 1
	narrative_flags["tutorial_heat_intervention_serial"] = serial
	narrative_flags["tutorial_heat_intervention_pending"] = {
		"serial": serial,
		"cue_id": cue_id,
		"location_id": location_id,
		"threshold": TUTORIAL_HEAT_CEILING,
		"reduced_to": TUTORIAL_HEAT_INTERVENTION_LEVEL,
	}
	_record_heat_history(false)
	log_story({
		"type": "tutorial_heat_intervention",
		"cue_id": cue_id,
		"heat_threshold": TUTORIAL_HEAT_CEILING,
		"heat_after": TUTORIAL_HEAT_INTERVENTION_LEVEL,
		"message": "Pal pulls you back before the heat can end the lesson.",
	})


func consume_tutorial_heat_intervention() -> Dictionary:
	var pending: Dictionary = narrative_flags.get("tutorial_heat_intervention_pending", {}) if typeof(narrative_flags.get("tutorial_heat_intervention_pending", {})) == TYPE_DICTIONARY else {}
	if pending.is_empty():
		return {}
	narrative_flags.erase("tutorial_heat_intervention_pending")
	return pending.duplicate(true)


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
	return clampi(int(suspicion.get("level", 0)), 0, TUTORIAL_HEAT_CEILING if is_tutorial_run() else 100)


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
		return clampi(int(levels.get(location_id, 0)), 0, TUTORIAL_HEAT_CEILING if is_tutorial_run() else 100)
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
	_set_drunk_level(drunk_level + delta)


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
			_set_drunk_level(drunk_level + step)
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
		_set_drunk_level(drunk_level + immediate)
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


# Applies every live Drunk change through one threshold seam. Save restoration
# assigns the persisted value directly, so loading above the threshold never
# fabricates a new tutorial warning.
func _set_drunk_level(next_level: int) -> void:
	var previous_level := drunk_level
	drunk_level = clampi(next_level, 0, ALCOHOL_MAX)
	if is_tutorial_run() \
			and previous_level <= TUTORIAL_DRUNK_COFFEE_THRESHOLD \
			and drunk_level > TUTORIAL_DRUNK_COFFEE_THRESHOLD:
		_publish_tutorial_drunk_coffee_intervention(previous_level, drunk_level)


func _publish_tutorial_drunk_coffee_intervention(previous_level: int, current_level: int) -> void:
	var already_owned := inventory.has(TUTORIAL_DRUNK_COFFEE_ITEM_ID)
	add_item(TUTORIAL_DRUNK_COFFEE_ITEM_ID)
	var serial := int(narrative_flags.get("tutorial_drunk_coffee_intervention_serial", 0)) + 1
	narrative_flags["tutorial_drunk_coffee_intervention_serial"] = serial
	var pending: Array = _copy_array(narrative_flags.get(TUTORIAL_DRUNK_COFFEE_PENDING_FLAG, []))
	pending.append({
		"serial": serial,
		"previous_level": previous_level,
		"current_level": current_level,
		"threshold": TUTORIAL_DRUNK_COFFEE_THRESHOLD,
		"item_id": TUTORIAL_DRUNK_COFFEE_ITEM_ID,
		"item_granted": not already_owned,
	})
	narrative_flags[TUTORIAL_DRUNK_COFFEE_PENDING_FLAG] = pending
	log_story({
		"type": "tutorial_drunk_coffee_intervention",
		"drunk_before": previous_level,
		"drunk_after": current_level,
		"item_id": TUTORIAL_DRUNK_COFFEE_ITEM_ID,
		"item_granted": not already_owned,
		"message": "Pal steps in with coffee after Drunk crosses 33%.",
	})


func consume_tutorial_drunk_coffee_intervention() -> Dictionary:
	var pending: Array = _copy_array(narrative_flags.get(TUTORIAL_DRUNK_COFFEE_PENDING_FLAG, []))
	while not pending.is_empty():
		var entry_value: Variant = pending.pop_front()
		if pending.is_empty():
			narrative_flags.erase(TUTORIAL_DRUNK_COFFEE_PENDING_FLAG)
		else:
			narrative_flags[TUTORIAL_DRUNK_COFFEE_PENDING_FLAG] = pending
		if typeof(entry_value) == TYPE_DICTIONARY:
			return (entry_value as Dictionary).duplicate(true)
	narrative_flags.erase(TUTORIAL_DRUNK_COFFEE_PENDING_FLAG)
	return {}


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
	var chain_security := _copy_dict(current_environment.get("security_profile", {}))
	bonus += maxi(0, int(chain_security.get("cass_chain_attention_delta", 0)))
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
				"message": "Rourke's crew tightens the room. The back door waits.",
			}
		var shutdown_cost := -mini(maxi(10, safe_stake), maxi(bankroll, 0))
		return {
			"bankroll_delta": shutdown_cost,
			"ended": true,
			"message": "Police lights slap the room blue; cuffs arrive before the door.",
		}
	if level >= 85:
		var crackdown_cost := -mini(maxi(8, safe_stake), maxi(bankroll, 0))
		return {
			"bankroll_delta": crackdown_cost,
			"ended": false,
			"message": "Security leans close and bills you for leaving.",
		}
	if level >= 65:
		var half_stake := maxi(1, int(ceil(float(safe_stake) / 2.0)))
		var shakedown_cost := -mini(maxi(3, half_stake), maxi(bankroll, 0))
		return {
			"bankroll_delta": shakedown_cost,
			"ended": false,
			"message": "Security pressure turns into a small, ugly shakedown.",
		}
	return {
		"bankroll_delta": 0,
		"ended": false,
		"message": "",
	}


# Caps blackjack's projected heat at the backoff threshold for security copy.
# add_suspicion owns the authoritative post-alcohol clamp, so even a scaled
# one-point award at 89 Heat lands exactly on the guardrail.
func blackjack_suspicion_delta_before_backoff(amount: int) -> int:
	if amount <= 0 or suspicion_level() >= BLACKJACK_BACKOFF_HEAT:
		return 0
	return mini(amount, BLACKJACK_BACKOFF_HEAT - suspicion_level())


# Returns whether the live run, venue, table, and canonical resolved action still
# qualify for Pal's protected tutorial Peek. Both Blackjack result emission and
# generic Heat backoff enforcement use this predicate so the policy cannot drift.
func blackjack_tutorial_peek_reprieve_eligible(action_id: String, environment: Dictionary = {}) -> bool:
	if action_id != "peek_hole_card" or not is_tutorial_run():
		return false
	var source := current_environment if environment.is_empty() else environment
	if str(source.get("archetype_id", "")) != TIER_TWO_UNDERGROUND_SOURCE_ID:
		return false
	var game_states := _copy_dict(source.get("game_states", {}))
	var table_value: Variant = game_states.get("blackjack", null)
	if typeof(table_value) != TYPE_DICTIONARY or (table_value as Dictionary).is_empty():
		return false
	return not bool((table_value as Dictionary).get("tutorial_count_completed", false))


# Converts the first blackjack result at 90 Heat into a persistent location
# backoff. The result seam calls this only after the canonical heat delta lands.
func apply_blackjack_heat_backoff(result: Dictionary) -> Dictionary:
	var game_id := str(result.get("game_id", result.get("source_id", "")))
	if game_id != "blackjack" \
			or suspicion_level() < BLACKJACK_BACKOFF_HEAT \
			or current_environment.is_empty():
		return {}
	if bool(result.get("blackjack_tutorial_peek_reprieve", false)) \
			and blackjack_tutorial_peek_reprieve_eligible(str(result.get("action_id", ""))):
		return {}
	var game_states := _copy_dict(current_environment.get("game_states", {}))
	var table := _copy_dict(game_states.get("blackjack", {}))
	if bool(table.get("heat_backoff", false)):
		return {}
	var dealer_name := str(table.get("dealer_name", result.get("blackjack_dealer_name", "The dealer"))).strip_edges()
	if dealer_name.is_empty():
		dealer_name = "The dealer"
	var environment_name := str(current_environment.get("display_name", "this casino"))
	var message := "%s calls the pit boss over. You're done playing blackjack at %s for the rest of the run. Other games remain open." % [dealer_name, environment_name]
	table["barred"] = true
	table["heat_backoff"] = true
	table["barred_reason"] = message
	table["barred_scope"] = BLACKJACK_BACKOFF_SCOPE
	table["barred_at_heat"] = suspicion_level()
	table["barred_at_hand"] = int(table.get("hands_played", 0))
	table["barred_action_id"] = str(result.get("action_id", ""))
	game_states["blackjack"] = table
	current_environment["game_states"] = game_states
	current_environment["blackjack_backoff"] = true
	current_environment["blackjack_backoff_heat"] = suspicion_level()

	var location_id := str(current_environment.get("world_node_id", current_environment.get("id", current_environment.get("archetype_id", ""))))
	var consequence_ids: Array = []
	var crew_payback := str(current_environment.get("archetype_id", "")) == "small_underground_casino" or location_id == "small_underground_casino"
	if crew_payback:
		for member_id in CrewStateModelScript.MEMBER_IDS:
			crew_trust_by_member[member_id] = 0
		narrative_flags.erase("rook_escort_punchline_back_room")
		_reconcile_crew_recruitment_perks()
		add_debt({
			"id": "crew_blackjack_backoff:%s" % location_id,
			"lender_id": CREW_LENDER_ID,
			"lender_name": "The Crew",
			"balance": 1,
			"debt_kind": "favor",
			"status": "active",
			"deadline_turns": 2,
			"turns_remaining": 2,
			"default_consequence": "crew_favor_due",
			"cash_conversion_balance_per_favor": 45,
			"cash_conversion_interest_rate": 0.35,
			"source_location_id": location_id,
			"source": "blackjack_backoff",
		})
		narrative_flags["crew_blackjack_backoff_payback"] = true
		message += " The Crew strips your standing and adds one favor to your marker: payback for taking from the operation."
		consequence_ids.append("crew_payback")

	var hook_ids := _string_array(_copy_array(current_environment.get("blackjack_backoff_event_ids", [])))
	var hook_flags := _copy_dict(current_environment.get("scenario_hook_flags", {}))
	var single_hook := str(hook_flags.get("blackjack_backoff_event_id", "")).strip_edges()
	if not single_hook.is_empty() and not hook_ids.has(single_hook):
		hook_ids.append(single_hook)
	for event_id in hook_ids:
		if enqueue_triggered_event(event_id, "blackjack_backoff", {"heat": suspicion_level(), "location_id": location_id}, {"presentation": "talk"}):
			consequence_ids.append(event_id)

	narrative_flags["blackjack_backoff:%s" % location_id] = true
	store_current_world_node_environment()
	return {
		"triggered": true,
		"message": message,
		"heat": suspicion_level(),
		"location_id": location_id,
		"crew_payback": crew_payback,
		"consequence_ids": consequence_ids,
		"story_entry": {
			"type": "blackjack_backoff",
			"game_id": "blackjack",
			"environment_id": str(current_environment.get("id", "")),
			"environment_archetype_id": str(current_environment.get("archetype_id", "")),
			"heat": suspicion_level(),
			"crew_payback": crew_payback,
			"message": message,
		},
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
	if _crew_heist_whale_attention_active():
		return true
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
	if _crew_heist_whale_attention_active():
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
	_try_spawn_grand_casino_invitation_from_table_win(game_id, bankroll_delta, result)


# Background game runtime is committed by the host, but its durable metrics
# belong to RunState rather than the UI shell. Keep one bounded per-game tally
# and reuse the same profile/objective recorders as foreground results.
func record_background_game_result(result: Dictionary) -> void:
	if result.is_empty() or not bool(result.get("ok", false)):
		return
	var game_id := str(result.get("game_id", result.get("source_id", ""))).strip_edges()
	if game_id.is_empty():
		return
	var all_stats := _copy_dict(narrative_flags.get("background_game_runtime_stats", {}))
	var stats := _copy_dict(all_stats.get(game_id, {}))
	if stats.is_empty() and game_id == "slot":
		stats = _copy_dict(narrative_flags.get("offscreen_slot_autoplay_stats", {}))
	stats["actions"] = maxi(0, int(stats.get("actions", stats.get("spins", 0)))) + 1
	stats["net"] = int(stats.get("net", 0)) + int(result.get("cash_equivalent_delta", result.get("bankroll_delta", result.get("chips_delta", 0))))
	stats["wins"] = maxi(0, int(stats.get("wins", 0))) + (1 if bool(result.get("won", false)) else 0)
	stats.erase("spins")
	all_stats[game_id] = stats
	narrative_flags["background_game_runtime_stats"] = all_stats
	narrative_flags.erase("offscreen_slot_autoplay_stats")
	record_profile_game_result(result)
	if str(result.get("environment_archetype_id", "")) == GRAND_CASINO_ARCHETYPE_ID:
		record_grand_casino_game_result(result)


func _try_spawn_grand_casino_invitation_from_table_win(game_id: String, bankroll_delta: int, result: Dictionary) -> bool:
	if not GRAND_CASINO_TABLE_GAME_IDS.has(game_id):
		return false
	if bankroll_delta <= GRAND_CASINO_INVITATION_TABLE_WIN_THRESHOLD:
		return false
	if bool(narrative_flags.get("grand_casino_invite", false)) or bool(narrative_flags.get(GRAND_CASINO_INVITATION_TABLE_WIN_FLAG, false)):
		return false
	if current_environment.is_empty():
		return false
	var environment_id := str(current_environment.get("id", "")).strip_edges()
	var world_node_id := str(current_environment.get("world_node_id", current_world_node_id())).strip_edges()
	var invitation_message := "A host notices the $%d table win and leaves a High Roller Invitation nearby." % bankroll_delta
	narrative_flags[GRAND_CASINO_INVITATION_TABLE_WIN_FLAG] = true
	narrative_flags["grand_casino_invite_table_win_game_id"] = game_id
	narrative_flags["grand_casino_invite_table_win_amount"] = bankroll_delta
	narrative_flags["grand_casino_invite_table_win_environment_id"] = environment_id
	narrative_flags["grand_casino_invite_table_win_world_node_id"] = world_node_id
	_reconcile_grand_casino_invitation_uniqueness()
	store_current_world_node_environment()
	log_story({
		"type": "grand_casino_invitation_table_win",
		"event_id": GRAND_CASINO_INVITATION_EVENT_ID,
		"game_id": game_id,
		"bankroll_delta": bankroll_delta,
		"environment_id": environment_id,
		"world_node_id": world_node_id,
		"message": invitation_message,
	})
	var result_deltas := _copy_dict(result.get("deltas", {}))
	var messages := _copy_array(result.get("messages", result_deltas.get("messages", [])))
	if not messages.has(invitation_message):
		messages.append(invitation_message)
	result["messages"] = messages
	var delta_messages := _copy_array(result_deltas.get("messages", []))
	if not delta_messages.has(invitation_message):
		delta_messages.append(invitation_message)
	result_deltas["messages"] = delta_messages
	result["deltas"] = result_deltas
	result["grand_casino_invitation_spawned"] = true
	result["grand_casino_invitation_event_id"] = GRAND_CASINO_INVITATION_EVENT_ID
	return true


# Keeps the table-win invitation at its earned location and strips generated
# Tier-2 copies. Once accepted, no environment retains a second invitation.
func reconcile_grand_casino_invitation_uniqueness() -> void:
	_reconcile_grand_casino_invitation_uniqueness()


func _reconcile_grand_casino_invitation_uniqueness() -> void:
	var invitation_received := bool(narrative_flags.get("grand_casino_invite", false))
	var table_win_spawned := bool(narrative_flags.get(GRAND_CASINO_INVITATION_TABLE_WIN_FLAG, false))
	if not invitation_received and not table_win_spawned:
		return
	if not current_environment.is_empty():
		var keep_current := not invitation_received and _is_grand_casino_invitation_table_win_environment(current_environment)
		_set_environment_event_presence(current_environment, GRAND_CASINO_INVITATION_EVENT_ID, keep_current)
	var nodes := _copy_array(world_map.get("nodes", []))
	var nodes_changed := false
	for index in range(nodes.size()):
		if typeof(nodes[index]) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = nodes[index]
		var stored_value: Variant = node.get("environment", {})
		if typeof(stored_value) != TYPE_DICTIONARY or (stored_value as Dictionary).is_empty():
			continue
		var stored: Dictionary = stored_value
		var keep_stored := not invitation_received and _is_grand_casino_invitation_table_win_environment(stored)
		if _set_environment_event_presence(stored, GRAND_CASINO_INVITATION_EVENT_ID, keep_stored):
			node["environment"] = stored
			nodes[index] = node
			nodes_changed = true
	if nodes_changed:
		world_map["nodes"] = nodes


func _is_grand_casino_invitation_table_win_environment(environment: Dictionary) -> bool:
	var source_node_id := str(narrative_flags.get("grand_casino_invite_table_win_world_node_id", "")).strip_edges()
	var environment_node_id := str(environment.get("world_node_id", "")).strip_edges()
	if not source_node_id.is_empty() and environment_node_id == source_node_id:
		return true
	var source_environment_id := str(narrative_flags.get("grand_casino_invite_table_win_environment_id", "")).strip_edges()
	return not source_environment_id.is_empty() and str(environment.get("id", "")).strip_edges() == source_environment_id


func _set_environment_event_presence(environment: Dictionary, event_id: String, present: bool) -> bool:
	var event_ids := _copy_array(environment.get("event_ids", []))
	var changed := false
	if present:
		if not event_ids.has(event_id):
			event_ids.append(event_id)
			changed = true
		var resolved_ids := _copy_array(environment.get("resolved_event_ids", []))
		if resolved_ids.has(event_id):
			resolved_ids.erase(event_id)
			environment["resolved_event_ids"] = resolved_ids
			changed = true
	elif event_ids.has(event_id):
		event_ids.erase(event_id)
		changed = true
	if changed:
		environment["event_ids"] = event_ids
		environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)
	return changed


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
	var card_tier := _grand_casino_players_card_awarded_tier()
	var card_tier_label := card_tier.capitalize() if card_tier != GRAND_CASINO_PLAYERS_CARD_TIER_NONE else "Unranked"
	if not card_eligible:
		card_tier_label = "%s (program closed)" % card_tier_label
	var next_tier := _grand_casino_players_card_next_definition(config, card_tier) if card_eligible else {}
	var next_tier_id := str(next_tier.get("id", ""))
	var next_tier_label := str(next_tier.get("label", ""))
	var next_tier_min_games := int(next_tier.get("min_games", min_games))
	var next_tier_net := int(next_tier.get("net_winnings", required_net))
	var next_tier_max_heat := int(next_tier.get("max_heat", max_heat))
	var segment_games := maxi(0, int(narrative_flags.get("grand_casino_players_card_segment_games", 0)))
	var segment_net := int(narrative_flags.get("grand_casino_players_card_segment_net_winnings", 0))
	var segment_max_heat := clampi(int(narrative_flags.get("grand_casino_players_card_segment_max_heat", current_heat)), 0, 100)
	var ready_to_claim := bool(narrative_flags.get("grand_casino_players_card_ready_to_claim", false)) and not next_tier_id.is_empty() and card_eligible
	var card_debt := grand_casino_atm_debt() if has_method("grand_casino_atm_debt") else 0
	var claim_block_reason := ""
	if not card_eligible:
		claim_block_reason = "Cheat evidence permanently closes the Players Card program for this run."
	elif bool(narrative_flags.get("grand_casino_showdown_pending", false)) or bool(narrative_flags.get("grand_casino_showdown_active", false)):
		claim_block_reason = "Rourke's showdown has priority over the Players Card program."
	elif card_debt > 0:
		claim_block_reason = "Settle the $%d Grand Casino ATM marker before Linda can issue %s." % [card_debt, next_tier_label]
	elif not ready_to_claim:
		claim_block_reason = "%s requirements are still in progress." % next_tier_label if not next_tier_label.is_empty() else "No later Players Card tier remains."
	var card_benefits := _grand_casino_players_card_benefits(config, card_tier)
	var money_target_met := net_winnings >= required_net
	if required_net <= 0 and target_bankroll > 0:
		money_target_met = total_money >= target_bankroll
	var game_target_met := games_played >= min_games
	var heat_clean := max_visit_heat <= max_heat
	var high_roller_ready := next_tier_id == GRAND_CASINO_PLAYERS_CARD_TIER_GOLD and ready_to_claim and card_debt <= 0 and claim_block_reason.is_empty()
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
		"players_card_awarded_tier": card_tier,
		"players_card_tier_label": card_tier_label,
		"players_card_eligible": card_eligible,
		"players_card_ineligible_reason": "Cheat evidence permanently closes the Players Card program for this run." if not card_eligible else "",
		"players_card_next_tier": next_tier_id,
		"players_card_next_tier_label": next_tier_label,
		"players_card_next_min_games": next_tier_min_games,
		"players_card_next_net_winnings": next_tier_net,
		"players_card_next_max_heat": next_tier_max_heat,
		"players_card_segment_games": segment_games,
		"players_card_segment_net_winnings": segment_net,
		"players_card_segment_max_heat": segment_max_heat,
		"players_card_next_remaining_games": maxi(0, next_tier_min_games - segment_games),
		"players_card_next_remaining_net_winnings": maxi(0, next_tier_net - segment_net),
		"players_card_ready_to_claim": ready_to_claim,
		"players_card_can_claim": ready_to_claim and claim_block_reason.is_empty(),
		"players_card_claim_block_reason": claim_block_reason,
		"grand_casino_atm_debt": card_debt,
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
	# Segment readiness is an action-boundary mutation. Rebuild the read-only
	# objective snapshot before deciding whether Gold or the showdown is ready.
	status = demo_objective_status()
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
		narrative_flags["grand_casino_linda_look_away_available"] = false
		if str(narrative_flags.get("grand_casino_high_limit_access_method", "")) == "silver_card":
			narrative_flags["grand_casino_high_limit_access"] = false
			narrative_flags["grand_casino_high_limit_access_method"] = ""
		return
	narrative_flags["grand_casino_players_card_ineligible"] = false
	if bool(narrative_flags.get("grand_casino_players_card_ready_to_claim", false)):
		return
	var card_tier := _grand_casino_players_card_awarded_tier()
	var config := _grand_casino_objective_config(_copy_dict(current_environment.get("demo_objective", {})))
	var next_definition := _grand_casino_players_card_next_definition(config, card_tier)
	if next_definition.is_empty():
		return
	var total_games := maxi(0, int(narrative_flags.get("grand_casino_games_played", 0)))
	var total_net := int(narrative_flags.get("grand_casino_net_winnings", 0))
	var baseline_games := maxi(0, int(narrative_flags.get("grand_casino_players_card_segment_start_games", total_games)))
	var baseline_net := int(narrative_flags.get("grand_casino_players_card_segment_start_net_winnings", total_net))
	var segment_games := maxi(0, total_games - baseline_games)
	var segment_net := total_net - baseline_net
	var segment_max_heat := maxi(
		clampi(int(narrative_flags.get("grand_casino_players_card_segment_max_heat", suspicion_level())), 0, 100),
		suspicion_level()
	)
	narrative_flags["grand_casino_players_card_segment_games"] = segment_games
	narrative_flags["grand_casino_players_card_segment_net_winnings"] = segment_net
	narrative_flags["grand_casino_players_card_segment_max_heat"] = segment_max_heat
	var ready := (
		segment_games >= int(next_definition.get("min_games", 0))
		and segment_net >= int(next_definition.get("net_winnings", 0))
		and segment_max_heat <= int(next_definition.get("max_heat", 100))
	)
	if ready:
		narrative_flags["grand_casino_players_card_ready_to_claim"] = true
		narrative_flags["grand_casino_players_card_ready_tier"] = str(next_definition.get("id", ""))
		log_story({
			"type": "grand_casino_players_card_ready",
			"tier": str(next_definition.get("id", "")),
			"segment_games": segment_games,
			"segment_net_winnings": segment_net,
			"segment_max_heat": segment_max_heat,
			"message": "%s Players Card qualification is ready for Linda." % str(next_definition.get("label", "Next")),
		})


func _grant_grand_casino_players_card_tier(target_tier: String, queue_dialogue: bool) -> bool:
	var current_tier := _grand_casino_players_card_awarded_tier()
	var current_index := _grand_casino_players_card_tier_index(current_tier)
	var target_index := _grand_casino_players_card_tier_index(target_tier)
	if target_index != current_index + 1:
		return false
	var config := _grand_casino_objective_config(_copy_dict(current_environment.get("demo_objective", {})))
	var tier_id := str(GRAND_CASINO_PLAYERS_CARD_TIERS[target_index])
	var definition := _grand_casino_players_card_tier_definition(config, tier_id)
	_apply_grand_casino_players_card_tier_benefits(definition)
	narrative_flags["grand_casino_players_card_awarded_tier"] = tier_id
	narrative_flags["grand_casino_players_card_tier"] = tier_id
	narrative_flags["grand_casino_players_card_highest_tier"] = tier_id
	narrative_flags["grand_casino_players_card_ready_to_claim"] = false
	narrative_flags.erase("grand_casino_players_card_ready_tier")
	narrative_flags["grand_casino_players_card_segment_start_games"] = maxi(0, int(narrative_flags.get("grand_casino_games_played", 0)))
	narrative_flags["grand_casino_players_card_segment_start_net_winnings"] = int(narrative_flags.get("grand_casino_net_winnings", 0))
	narrative_flags["grand_casino_players_card_segment_games"] = 0
	narrative_flags["grand_casino_players_card_segment_net_winnings"] = 0
	narrative_flags["grand_casino_players_card_segment_max_heat"] = suspicion_level()
	log_story({
		"type": "grand_casino_players_card_tier",
		"tier": tier_id,
		"games_played": maxi(0, int(narrative_flags.get("grand_casino_games_played", 0))),
		"net_winnings": int(narrative_flags.get("grand_casino_net_winnings", 0)),
		"environment_id": str(current_environment.get("id", "")),
		"environment_archetype_id": str(current_environment.get("archetype_id", "")),
		"message": "Linda awards the %s Players Card tier." % tier_id.capitalize(),
	})
	if queue_dialogue and not is_tutorial_run() and GRAND_CASINO_LINDA_TIER_DIALOGUES.has(tier_id):
		var dialogue_id := str(GRAND_CASINO_LINDA_TIER_DIALOGUES[tier_id])
		enqueue_dialogue(dialogue_id, "dialogue:%s" % dialogue_id, GRAND_CASINO_LINDA_SPEAKER, "recognition", "players_card_tier", {
			"tier": tier_id,
			"environment_snapshot": environment_context_snapshot(current_environment),
		})
	return true


func claim_grand_casino_players_card_tier() -> Dictionary:
	if str(current_environment.get("archetype_id", "")) != GRAND_CASINO_CAGE_ARCHETYPE_ID:
		return {"ok": false, "message": "Linda awards Players Card tiers only at the Cage counter."}
	var status := demo_objective_status()
	if not bool(status.get("players_card_eligible", false)):
		return {"ok": false, "message": str(status.get("players_card_claim_block_reason", "Cheat evidence closed the Players Card program."))}
	if not bool(status.get("players_card_ready_to_claim", false)):
		return {"ok": false, "message": str(status.get("players_card_claim_block_reason", "The next tier is not ready."))}
	if not bool(status.get("players_card_can_claim", false)):
		return {"ok": false, "message": str(status.get("players_card_claim_block_reason", "Linda cannot issue the tier yet."))}
	var next_tier := str(status.get("players_card_next_tier", ""))
	if next_tier == GRAND_CASINO_PLAYERS_CARD_TIER_GOLD:
		return {"ok": true, "review_required": true, "tier": next_tier, "message": "Linda is ready to complete the Gold review."}
	if not _grant_grand_casino_players_card_tier(next_tier, true):
		return {"ok": false, "message": "The Players Card tier sequence is invalid."}
	return {"ok": true, "tier": next_tier, "message": "Linda awards the %s Players Card tier." % next_tier.capitalize(), "status": demo_objective_status()}


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
	if str(current_environment.get("archetype_id", "")) != GRAND_CASINO_CAGE_ARCHETYPE_ID:
		return {"ok": false, "message": "Linda completes the Gold review only at the Cage counter."}
	var status := demo_objective_status()
	if not bool(status.get("grand_casino_objective", false)):
		return {"ok": false, "message": "The Players Card is not available here."}
	if bool(status.get("showdown_pending", false)) or bool(status.get("showdown_active", false)):
		return {"ok": false, "message": "Rourke's call has priority now."}
	if grand_casino_atm_debt() > 0:
		return {"ok": false, "message": "Settle the $%d Grand Casino ATM marker before Linda can complete Gold." % grand_casino_atm_debt()}
	if not bool(status.get("high_roller_ready", false)) and not bool(narrative_flags.get("high_roller_cashout_pending", false)):
		evaluate_environment_objective_state()
		status = demo_objective_status()
	if not bool(status.get("high_roller_ready", false)) and not bool(narrative_flags.get("high_roller_cashout_pending", false)):
		return {"ok": false, "message": "The host is not ready to issue the Players Card yet."}
	if str(status.get("players_card_next_tier", "")) != GRAND_CASINO_PLAYERS_CARD_TIER_GOLD or not bool(status.get("players_card_ready_to_claim", false)):
		return {"ok": false, "message": "Gold has not completed its sequential qualification segment."}
	if not _grant_grand_casino_players_card_tier(GRAND_CASINO_PLAYERS_CARD_TIER_GOLD, false):
		return {"ok": false, "message": "Linda could not issue Gold without the prior Players Card tiers."}
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
	objective["finale_trigger_message"] = "Rourke calls you where the carpet ends."
	_trigger_demo_finale(status, objective)


func _log_grand_casino_heat_reroute(showdown_event_id: String, trigger_reason: String, sources: Array) -> void:
	if _story_log_has_type("grand_casino_heat_reroute", showdown_event_id):
		return
	var message := "Rourke calls you where the carpet ends."
	if trigger_reason == "forced_heat":
		message = "A heat spike puts Rourke's crew in your shadow."
	elif trigger_reason == "heat_attention":
		message = "Staff attention hands your heat to Rourke."
	elif trigger_reason == "dirty_money":
		message = "The Players Card review sends your win across Rourke's desk."
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
		"message": "Rourke walks you past the last friendly light.",
	})
	return {
		"ok": true,
		"message": "Rourke walks you past the floor. One pocket gets one last lie.",
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
	var message := "You keep every pocket steady while Rourke walks."
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
		"message": "Rourke records the answer like it was always evidence.",
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
			_complete_grand_casino_showdown_success("You take Rourke's stack. Linda kisses the rack goodbye. The elevator opens.")
		GrandCasinoDuelModelScript.OUTCOME_SHOWN_THE_DOOR:
			_complete_grand_casino_showdown_shown_door()
		_:
			_complete_grand_casino_showdown_failure("Rourke takes the last hand. The casino takes you where neon does not follow.")


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
	var message := "Rourke opens the service door and closes the Cage. %d house chips leave cold in your pocket." % chip_amount
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
		message = str(pat_down_config.get("blatant_failure_message", "Rourke finds a loaded cheating kit. The back door gets impatient."))
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
				"demo_victory_route": str(finale_data.get("route", event_id)).strip_edges(),
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
	retire_pending_talk_events()
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
	return _grand_casino_staffing_projection(source)


func grand_casino_staff_member_for_game(game_id: String, environment: Dictionary = {}) -> Dictionary:
	var source := current_environment if environment.is_empty() else environment
	if not _is_grand_casino_environment(source):
		return {}
	_initialize_grand_casino_staffing(source)
	var role_id := "bartender" if game_id == "bar_dice" else game_id.strip_edges()
	var assignments: Dictionary = grand_casino_staffing.get("assignments", {}) if typeof(grand_casino_staffing.get("assignments", {})) == TYPE_DICTIONARY else {}
	var assignment: Variant = assignments.get(role_id, {})
	return assignment if typeof(assignment) == TYPE_DICTIONARY else {}


func grand_casino_staff_member_for_game_preview(game_id: String, environment: Dictionary = {}) -> Dictionary:
	var source := current_environment if environment.is_empty() else environment
	if not _is_grand_casino_environment(source):
		return {}
	var staffing := _grand_casino_staffing_projection(source)
	var role_id := "bartender" if game_id == "bar_dice" else game_id.strip_edges()
	var assignments: Dictionary = staffing.get("assignments", {}) if typeof(staffing.get("assignments", {})) == TYPE_DICTIONARY else {}
	var assignment: Variant = assignments.get(role_id, {})
	return (assignment as Dictionary).duplicate(true) if typeof(assignment) == TYPE_DICTIONARY else {}


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


func _initialize_grand_casino_staffing(environment: Dictionary = {}) -> void:
	var source := current_environment if environment.is_empty() else environment
	if not _is_grand_casino_environment(source):
		return
	var current_day := game_day()
	if int(grand_casino_staffing.get("day", 0)) == current_day and not _grand_casino_staff_assignments(grand_casino_staffing).is_empty():
		return
	var prior_cue: Dictionary = grand_casino_staffing.get("entry_cue", {}) if typeof(grand_casino_staffing.get("entry_cue", {})) == TYPE_DICTIONARY else {}
	var shown_day := maxi(0, int(grand_casino_staffing.get("rotation_cue_shown_day", 0)))
	grand_casino_staffing = _grand_casino_staffing_for_day(current_day, _grand_casino_staff_config(source))
	grand_casino_staffing["entry_cue"] = prior_cue
	grand_casino_staffing["rotation_cue_shown_day"] = shown_day


func _grand_casino_staffing_projection(environment: Dictionary) -> Dictionary:
	var current_day := game_day()
	if int(grand_casino_staffing.get("day", 0)) == current_day and not _grand_casino_staff_assignments(grand_casino_staffing).is_empty():
		return grand_casino_staffing.duplicate(true)
	var projected := _grand_casino_staffing_for_day(current_day, _grand_casino_staff_config(environment))
	projected["entry_cue"] = _copy_dict(grand_casino_staffing.get("entry_cue", {}))
	projected["rotation_cue_shown_day"] = maxi(0, int(grand_casino_staffing.get("rotation_cue_shown_day", 0)))
	return projected


func _advance_grand_casino_staff_day_rollovers(previous_day: int, next_day: int) -> void:
	if previous_day >= next_day:
		return
	for day_index in range(previous_day + 1, next_day + 1):
		grand_casino_staffing = _grand_casino_staffing_for_day(day_index)
		_seed_rival_cheater_cast(day_index)


func _grand_casino_staffing_for_day(day_index: int, config_override: Dictionary = {}) -> Dictionary:
	var target_day := maxi(1, day_index)
	var config := config_override.duplicate(true) if not config_override.is_empty() else _grand_casino_staff_config()
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


func _grand_casino_staff_config(environment: Dictionary = {}) -> Dictionary:
	var candidates: Array = []
	if not environment.is_empty():
		candidates.append(environment)
	candidates.append(current_environment)
	candidates.append(grand_casino_room_states.get(GRAND_CASINO_ARCHETYPE_ID, {}))
	for environment_value in candidates:
		if typeof(environment_value) != TYPE_DICTIONARY:
			continue
		var candidate_environment := environment_value as Dictionary
		var flags: Dictionary = candidate_environment.get("local_narrative_flags", {}) if typeof(candidate_environment.get("local_narrative_flags", {})) == TYPE_DICTIONARY else {}
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
		_advance_linda_cage_simulation()
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


func linda_cage_snapshot() -> Dictionary:
	if linda_cage_state.is_empty():
		linda_cage_state = _default_linda_cage_state()
	return linda_cage_state.duplicate(true)


func _advance_linda_cage_simulation() -> void:
	if linda_cage_state.is_empty():
		linda_cage_state = _default_linda_cage_state()
	var action_index := maxi(0, int(linda_cage_state.get("action_index", 0))) + 1
	var remaining := maxi(0, int(linda_cage_state.get("actions_until_move", 1)) - 1)
	linda_cage_state["action_index"] = action_index
	if remaining > 0:
		linda_cage_state["actions_until_move"] = remaining
		return
	var pose_rng := create_rng("linda_cage").fork("pose:%d" % action_index)
	var previous_pose := clampi(int(linda_cage_state.get("pose_index", 1)), 0, 3)
	var step := 1 if pose_rng.randi_range(0, 1) == 1 else -1
	var next_pose := clampi(previous_pose + step, 0, 3)
	if next_pose == previous_pose:
		next_pose = clampi(previous_pose - step, 0, 3)
	linda_cage_state["pose_index"] = next_pose
	linda_cage_state["facing"] = "right" if next_pose > previous_pose else "left"
	linda_cage_state["actions_until_move"] = pose_rng.randi_range(2, 4)
	linda_cage_state["fork_state"] = pose_rng.snapshot()


static func _default_linda_cage_state() -> Dictionary:
	return {
		"pose_index": 1,
		"facing": "left",
		"actions_until_move": 2,
		"action_index": 0,
		"fork_state": {},
		"presentation": "faceless_silhouette",
	}


static func _normalize_linda_cage_state(value: Dictionary) -> Dictionary:
	var normalized := _default_linda_cage_state()
	normalized["pose_index"] = clampi(int(value.get("pose_index", normalized["pose_index"])), 0, 3)
	normalized["facing"] = "right" if str(value.get("facing", normalized["facing"])) == "right" else "left"
	normalized["actions_until_move"] = clampi(int(value.get("actions_until_move", normalized["actions_until_move"])), 0, 4)
	normalized["action_index"] = maxi(0, int(value.get("action_index", 0)))
	normalized["fork_state"] = _copy_dict(value.get("fork_state", {}))
	return normalized


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
	var had_sequential_card_state := narrative_flags.has("grand_casino_players_card_awarded_tier")
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
	var total_games := maxi(0, int(narrative_flags.get("grand_casino_games_played", 0)))
	var total_net := int(narrative_flags.get("grand_casino_net_winnings", 0))
	if not had_sequential_card_state:
		var legacy_tier := str(narrative_flags.get("grand_casino_players_card_tier", GRAND_CASINO_PLAYERS_CARD_TIER_NONE)).strip_edges().to_lower()
		if not GRAND_CASINO_PLAYERS_CARD_TIERS.has(legacy_tier):
			legacy_tier = GRAND_CASINO_PLAYERS_CARD_TIER_NONE
		# The old cumulative system marked Gold before Linda's review. Preserve an
		# open review as Silver + a frozen Gold claim; otherwise retain a genuinely
		# awarded legacy tier without deriving anything from excess totals.
		if bool(narrative_flags.get("high_roller_cashout_pending", false)) and legacy_tier == GRAND_CASINO_PLAYERS_CARD_TIER_GOLD:
			narrative_flags["grand_casino_players_card_awarded_tier"] = GRAND_CASINO_PLAYERS_CARD_TIER_SILVER
			narrative_flags["grand_casino_players_card_ready_to_claim"] = true
			narrative_flags["grand_casino_players_card_ready_tier"] = GRAND_CASINO_PLAYERS_CARD_TIER_GOLD
		else:
			narrative_flags["grand_casino_players_card_awarded_tier"] = legacy_tier
			narrative_flags["grand_casino_players_card_ready_to_claim"] = false
	# A carried meta Gold card keeps its prestige recognition modifiers, but a
	# new run's card program begins Unranked. This is deliberate: prestige makes
	# the standards tighter/safer; it never skips a run-local Linda award.
	var awarded_tier := _grand_casino_players_card_awarded_tier()
	narrative_flags["grand_casino_players_card_tier"] = awarded_tier
	if not narrative_flags.has("grand_casino_players_card_highest_tier"):
		narrative_flags["grand_casino_players_card_highest_tier"] = awarded_tier
	if not narrative_flags.has("grand_casino_players_card_segment_start_games"):
		narrative_flags["grand_casino_players_card_segment_start_games"] = total_games
	if not narrative_flags.has("grand_casino_players_card_segment_start_net_winnings"):
		narrative_flags["grand_casino_players_card_segment_start_net_winnings"] = total_net
	if not narrative_flags.has("grand_casino_players_card_segment_games"):
		narrative_flags["grand_casino_players_card_segment_games"] = 0
	if not narrative_flags.has("grand_casino_players_card_segment_net_winnings"):
		narrative_flags["grand_casino_players_card_segment_net_winnings"] = 0
	if not narrative_flags.has("grand_casino_players_card_segment_max_heat"):
		narrative_flags["grand_casino_players_card_segment_max_heat"] = suspicion_level()
	if not narrative_flags.has("grand_casino_players_card_ready_to_claim"):
		narrative_flags["grand_casino_players_card_ready_to_claim"] = false
	if bool(narrative_flags.get("grand_casino_players_card_ready_to_claim", false)) and not narrative_flags.has("grand_casino_players_card_ready_tier"):
		var config := _grand_casino_objective_config(objective)
		var next_definition := _grand_casino_players_card_next_definition(config, awarded_tier)
		narrative_flags["grand_casino_players_card_ready_tier"] = str(next_definition.get("id", ""))
	if bool(narrative_flags.get("grand_casino_cheat_evidence", false)) or bool(narrative_flags.get("grand_casino_watched_cheat_evidence", false)):
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
		var configured_value := int(objective.get(key, card_defaults[key]))
		if is_tutorial_run() and key == "players_card_bronze_net_winnings":
			config[key] = clampi(configured_value, -10000, 10000)
		else:
			config[key] = maxi(0, configured_value)
	for heat_key in ["players_card_bronze_max_heat", "players_card_silver_max_heat", "players_card_gold_max_heat"]:
		config[heat_key] = clampi(int(objective.get(heat_key, card_defaults[heat_key])) + prestige_heat_delta, 0, 100)
	config["players_card_gold_min_games"] = maxi(int(config.get("players_card_gold_min_games", 0)), int(config.get("high_roller_min_grand_casino_games", 0)))
	config["players_card_gold_net_winnings"] = maxi(int(config.get("players_card_gold_net_winnings", 0)), high_roller_net)
	config["players_card_gold_max_heat"] = clampi(int(config.get("players_card_gold_max_heat", high_roller_max_heat)), 0, 100)
	return config


func _grand_casino_players_card_awarded_tier() -> String:
	var tier_id := str(narrative_flags.get(
		"grand_casino_players_card_awarded_tier",
		narrative_flags.get("grand_casino_players_card_tier", GRAND_CASINO_PLAYERS_CARD_TIER_NONE)
	)).strip_edges().to_lower()
	return tier_id if GRAND_CASINO_PLAYERS_CARD_TIERS.has(tier_id) else GRAND_CASINO_PLAYERS_CARD_TIER_NONE


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
		return "Rourke wants you past the friendly lights."
	if high_roller_ready:
		return "Gold Players Card review is ready at the Cage."
	if dirty_money_showdown_ready:
		return "The Players Card review put your win on Rourke's desk."
	if heat_route_ready:
		return "Your heat has Rourke walking toward the table."
	if not money_target_met:
		return "Win $%d clean on the Grand Casino floor toward Gold." % required_net
	if not game_target_met:
		return "Play %d more Grand Casino game%s before Linda can open Gold review." % [remaining_games, "" if remaining_games == 1 else "s"]
	return "Keep heat low so Linda can open Gold review."


func _grand_casino_result_has_wager(result: Dictionary) -> bool:
	# Blackjack debits the wager on Deal, then returns the settled outcome as a
	# separate result. The wager-placement receipt is not a completed hand and
	# must never advance Players Card progress.
	if str(result.get("game_id", "")) == "blackjack":
		return str(result.get("action_id", "")) == "play_basic" and int(result.get("stake", 0)) > 0
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
	var stored := _portable_ticket_state_for_live_storage(clean_kind, state)
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


func capture_portable_ticket_piles_from_environment(environment: Dictionary, only_missing: bool = false) -> void:
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
		var existing := portable_ticket_state(kind, environment)
		if only_missing and not existing.is_empty():
			continue
		var player_state := _portable_ticket_player_state(kind, machine_value as Dictionary)
		if _portable_ticket_state_count(kind, player_state) > 0 or not existing.is_empty():
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
				unplayed_count += _portable_ticket_array_size(state.get("pending_queue", []))
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
		invalidate_inventory_effect_cache()


# Removes a run item and clears the active slot if that item was equipped.
func remove_item(item_id: String) -> void:
	if item_id.is_empty():
		return
	if is_portable_ticket_pile_item(item_id) and int(portable_ticket_pile_summary(item_id).get("ticket_count", 0)) > 0:
		return
	inventory.erase(item_id)
	invalidate_inventory_effect_cache()
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
	var cache_key := "%s|%s|%s" % [effect_key, family_key, action_key]
	if _item_effect_total_cache.has(cache_key):
		return int(_item_effect_total_cache.get(cache_key, 0))
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
	_item_effect_total_cache[cache_key] = total
	return total


func _inventory_entry_effect(entry: Variant) -> Dictionary:
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = entry
	return _copy_dict(data.get("effect", {}))


func _owned_item_lookup() -> Dictionary:
	if _owned_item_lookup_cache_valid:
		return _owned_item_lookup_cache
	var result := {}
	for inventory_entry in inventory:
		var item_id := _inventory_item_id(inventory_entry)
		if not item_id.is_empty():
			result[item_id] = true
	_owned_item_lookup_cache = result
	_owned_item_lookup_cache_valid = true
	return _owned_item_lookup_cache


func invalidate_inventory_effect_cache() -> void:
	_item_effect_total_cache.clear()
	_owned_item_lookup_cache.clear()
	_owned_item_lookup_cache_valid = false


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


# Returns the first Collector-eligible cash marker and its discounted payoff.
# The ledger order is authoritative so the same save always receives the same offer.
func discounted_debt_settlement_preview(discount_percent: int) -> Dictionary:
	var discount := clampi(discount_percent, 0, 90)
	for debt_value in debt:
		if typeof(debt_value) != TYPE_DICTIONARY:
			continue
		var debt_data := debt_value as Dictionary
		if bool(debt_data.get("no_collector", false)):
			continue
		if not ["active", "overdue"].has(str(debt_data.get("status", "active"))):
			continue
		if str(debt_data.get("debt_kind", "cash")) == "favor":
			continue
		var balance := maxi(0, int(debt_data.get("balance", 0)))
		if balance <= 0:
			continue
		var payment := maxi(1, int(ceil(float(balance) * float(100 - discount) / 100.0)))
		return {
			"ok": bankroll >= payment,
			"debt_id": str(debt_data.get("id", "")),
			"lender_id": str(debt_data.get("lender_id", "")),
			"balance": balance,
			"payment": payment,
			"discount_percent": discount,
			"reason": "" if bankroll >= payment else "The Collector's discount still needs $%d." % payment,
		}
	return {"ok": false, "reason": "No active marker reaches the Collector."}


# Clears a previously previewed marker before the event action advances clocks.
# The event's shared bankroll delta applies the quoted payment immediately after.
func apply_discounted_debt_settlement(preview: Dictionary) -> Dictionary:
	var debt_id := str(preview.get("debt_id", "")).strip_edges()
	var index := _debt_index(debt_id)
	if index < 0 or typeof(debt[index]) != TYPE_DICTIONARY:
		return {"ok": false, "message": "That marker changed before settlement."}
	var debt_data := (debt[index] as Dictionary).duplicate(true)
	var balance := maxi(0, int(debt_data.get("balance", 0)))
	var payment := maxi(0, int(preview.get("payment", 0)))
	if balance != int(preview.get("balance", -1)) or payment <= 0 or bankroll < payment:
		return {"ok": false, "message": "That marker no longer matches the quoted settlement."}
	var message := _settle_paid_debt(index, debt_data, payment)
	narrative_flags["debt_court_last_debt_id"] = debt_id
	narrative_flags["debt_court_last_discount_percent"] = clampi(int(preview.get("discount_percent", 0)), 0, 90)
	_refresh_economy(true)
	return {
		"ok": true,
		"message": message,
		"debt_id": debt_id,
		"balance": balance,
		"payment": payment,
		"discount_percent": int(narrative_flags.get("debt_court_last_discount_percent", 0)),
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
	grievance_add({
		"member_id": _crew_debt_lead_member(debt_data),
		"kind": "favor_converted_unpaid",
		"weight": maxi(1, favor_balance),
		"source_ref": str(debt_data.get("id", debt_id)),
	})
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


# Returns one member's hidden within-run trust value.
func crew_trust(member_id: String) -> int:
	return maxi(0, int(crew_trust_by_member.get(member_id, 0))) if CrewStateModelScript.MEMBER_IDS.has(member_id) else 0


# Returns one member's data-tuned trust rank.
func crew_rank(member_id: String) -> String:
	return CrewStateModelScript.rank_for_trust(crew_trust(member_id))


# Changes hidden trust without emitting story, UI, or log copy.
func crew_add_trust(member_id: String, amount: int, _reason: String = "") -> int:
	if not CrewStateModelScript.MEMBER_IDS.has(member_id) or amount == 0:
		return crew_trust(member_id)
	var previous := crew_trust(member_id)
	crew_trust_by_member[member_id] = maxi(0, crew_trust(member_id) + amount)
	_reconcile_crew_recruitment_perks()
	if crew_trust(member_id) != previous:
		_scenario_publish_crew_change(member_id, "trust", crew_trust(member_id))
	return crew_trust(member_id)


# Legacy lifecycle names remain fail-closed for compatibility with callers that
# only inspect their result. Production recruitment commits through the exact
# resolved EventModule result in crew_record_recruitment_event_result().
func crew_recruit_member(member_id: String, host_capability: RefCounted = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_recruitment_host_capability:
		return {"ok": false, "member_id": member_id}
	if not CrewStateModelScript.MEMBER_IDS.has(member_id) or member_id == "crew_rook":
		return {"ok": false, "member_id": member_id}
	var target := CrewStateModelScript.rank_threshold("associate")
	if crew_trust(member_id) < target:
		crew_add_trust(member_id, target - crew_trust(member_id), "recruitment_intro")
	return {"ok": crew_rank(member_id) == "associate" or CrewStateModelScript.RANK_IDS.find(crew_rank(member_id)) > CrewStateModelScript.RANK_IDS.find("associate"), "member_id": member_id, "rank": crew_rank(member_id)}


func crew_meet_member(member_id: String, host_capability: RefCounted = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_recruitment_host_capability:
		return {"ok": false, "member_id": member_id}
	if not CrewStateModelScript.MEMBER_IDS.has(member_id) or member_id == "crew_rook":
		return {"ok": false, "member_id": member_id}
	var target := CrewStateModelScript.rank_threshold("marker")
	if crew_trust(member_id) < target:
		crew_add_trust(member_id, target - crew_trust(member_id), "recruitment_contact")
	return {"ok": CrewStateModelScript.RANK_IDS.find(crew_rank(member_id)) >= CrewStateModelScript.RANK_IDS.find("marker"), "member_id": member_id, "rank": crew_rank(member_id)}


# Commits only a choice already resolved by the production event host. The
# event id must still be mounted at the exact live placement; caller-authored
# member, path, outcome, trust, or aftermath fields are never accepted.
func crew_record_recruitment_event_result(result: Dictionary) -> Dictionary:
	if not bool(result.get("ok", false)) or str(result.get("type", "")) != "event":
		return {"ok": false, "reason": "not_resolved_event"}
	var event_id := str(result.get("event_id", result.get("source_id", ""))).strip_edges()
	var choice_id := str(result.get("choice_id", result.get("action_id", ""))).strip_edges()
	if event_id.is_empty() or choice_id.is_empty() or not _copy_array(current_environment.get("event_ids", [])).has(event_id) \
			or _copy_array(current_environment.get("resolved_event_ids", [])).has(event_id):
		return {"ok": false, "reason": "event_not_live"}
	var member_id := ""
	var definition: Dictionary = {}
	for candidate_id in CrewStateModelScript.MEMBER_IDS:
		var candidate := CrewRecruitmentModelScript.member_definition(str(candidate_id))
		if str(candidate.get("event_id", "")) == event_id:
			member_id = str(candidate_id)
			definition = candidate
			break
	if member_id.is_empty() or member_id == "crew_rook":
		return {"ok": false, "reason": "not_first_meeting"}
	var path_kind := CrewRecruitmentModelScript.placement_kind(self, current_environment, definition)
	if path_kind.is_empty():
		return {"ok": false, "reason": "placement_changed"}
	var outcome := "refused" if choice_id.begins_with("leave_") else "deferred"
	var hooks := _copy_array(_copy_dict(result.get("deltas", {})).get("event_hooks", []))
	var recruit_hook := false
	var meet_hook := false
	for hook_value in hooks:
		var hook := _copy_dict(hook_value)
		if str(hook.get("member_id", "")) != member_id:
			continue
		recruit_hook = recruit_hook or str(hook.get("type", "")) == "crew_recruit"
		meet_hook = meet_hook or str(hook.get("type", "")) == "crew_meet"
	if recruit_hook:
		outcome = "accepted"
	elif not meet_hook and not choice_id.begins_with("leave_"):
		return {"ok": false, "reason": "choice_has_no_recruitment_outcome"}
	var proposal := CrewRecruitmentModelScript.first_meeting_proposal(self, current_environment, member_id, path_kind, outcome)
	if str(proposal.get("reason", "")) != "adapter_host_root_unavailable" or str(proposal.get("event_id", "")) != event_id:
		return {"ok": false, "reason": "proposal_mismatch"}
	var state := CrewRecruitmentModelScript.normalize_encounter_state(crew_recruitment_encounters)
	if state.is_empty():
		state = CrewRecruitmentModelScript.new_encounter_state()
	var meetings := _copy_dict(state.get("meetings", {}))
	var previous := _copy_dict(meetings.get(member_id, {}))
	if str(previous.get("outcome", "")) == "accepted":
		return {"ok": true, "replayed": true, "public_state": CrewRecruitmentModelScript.encounter_public_state(state, member_id)}
	var action_index := _crew_action_index()
	var fact := {"path_kind": path_kind, "outcome": outcome, "action_index": action_index}
	var history := _copy_array(previous.get("history", []))
	if history.is_empty() or history.back() != fact:
		history.append(fact)
	meetings[member_id] = {
		"member_id": member_id,
		"first_path_kind": str(previous.get("first_path_kind", path_kind)),
		"first_outcome": str(previous.get("first_outcome", outcome)),
		"path_kind": path_kind,
		"outcome": outcome,
		"action_index": action_index,
		"aftermath_id": "%s_%s" % [member_id, outcome],
		"history": history,
	}
	state["meetings"] = meetings
	crew_recruitment_encounters = state
	if outcome == "accepted":
		crew_recruit_member(member_id, _crew_recruitment_host_capability)
	elif outcome == "deferred":
		crew_meet_member(member_id, _crew_recruitment_host_capability)
	return {"ok": true, "replayed": false, "public_state": CrewRecruitmentModelScript.encounter_public_state(state, member_id)}


func crew_recruitment_public_state(member_id: String) -> Dictionary:
	var result := CrewRecruitmentModelScript.encounter_public_state(crew_recruitment_encounters, member_id)
	if str(result.get("meeting_state", "")) != "accepted":
		return result
	var job_out := false
	for job_value in crew_jobs.values():
		var job := _copy_dict(job_value)
		if str(job.get("member_id", "")) == member_id and str(job.get("status", "")) in ["offered", "accepted", "active"]:
			job_out = true
			break
	var standing := crew_rank(member_id)
	result["standing"] = standing
	result["contact_state"] = "job_out" if job_out else ("trusted" if standing in ["made", "inner_circle"] else "familiar")
	return result


func crew_rank_perks(member_id: String) -> Array:
	var result: Array = []
	var rank_index := CrewStateModelScript.RANK_IDS.find(crew_rank(member_id))
	for rank_id_value in CrewRecruitmentModelScript.rank_perks(member_id).keys():
		var rank_id := str(rank_id_value)
		if CrewStateModelScript.RANK_IDS.has(rank_id) and rank_index >= CrewStateModelScript.RANK_IDS.find(rank_id):
			for perk_value in _copy_array(CrewRecruitmentModelScript.rank_perks(member_id).get(rank_id_value, [])):
				var perk_id := str(perk_value)
				if not perk_id.is_empty() and not result.has(perk_id):
					result.append(perk_id)
	return result


func crew_member_job_available(member_id: String) -> bool:
	return crew_rank_perks(member_id).has("member_jobs")


# Read-only physical-presence seam shared by Layer 3 jobs and coordinated plays.
func crew_present_member_ids(environment: Dictionary = {}) -> Array:
	var source := current_environment if environment.is_empty() else environment
	var result: Array = []
	for entry_value in _copy_array(source.get("crew_presence", [])):
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var member_id := str((entry_value as Dictionary).get("member_id", "")).strip_edges()
		if CrewStateModelScript.MEMBER_IDS.has(member_id) and not result.has(member_id):
			result.append(member_id)
	result.sort()
	return result


func crew_member_present(member_id: String, environment: Dictionary = {}) -> bool:
	return crew_present_member_ids(environment).has(member_id.strip_edges())


# Shared progress grant used by both Street Craps lessons and Mags' Practice
# Rig. Callers may request a delta-only projection when GameModule will apply
# the returned flags at the canonical action boundary.
func grant_shared_training_progress(progress_flag: String, trained_flag: String, required: int, amount: int = 1, apply_now: bool = true) -> Dictionary:
	var clean_progress := progress_flag.strip_edges()
	var clean_trained := trained_flag.strip_edges()
	if clean_progress.is_empty() or clean_trained.is_empty() or required <= 0 or amount <= 0:
		return {}
	if bool(narrative_flags.get(clean_trained, false)):
		return {"flags_set": {}, "progress": required, "required": required, "trained": true}
	var progress := mini(required, maxi(0, int(narrative_flags.get(clean_progress, 0))) + amount)
	var flags := {clean_progress: progress}
	if progress >= required:
		flags[clean_trained] = true
	if apply_now:
		for key in flags.keys():
			narrative_flags[str(key)] = flags[key]
	return {"flags_set": flags, "progress": progress, "required": required, "trained": progress >= required}


func crew_practice_rig_readout() -> Dictionary:
	var services := _copy_dict(CrewStateModelScript.config().get("member_services", {}))
	var required := maxi(1, int(services.get("practice_rig_successes_required", 2)))
	var windows := ["early", "center", "late"]
	var index := posmod(seed_value * 31 + _crew_action_index() * 17, windows.size())
	return {
		"target_window": windows[index],
		"progress": mini(required, maxi(0, int(narrative_flags.get("craps_setting_street_progress", 0)))),
		"required": required,
		"trained": bool(narrative_flags.get("craps_setting_trained", false)),
	}


func crew_practice_rig_choices() -> Array:
	var readout := crew_practice_rig_readout()
	if bool(readout.get("trained", false)):
		return [{"id": "leave", "label": "Rig trained", "text": "The target distribution holds steady. The setting technique is learned.", "consequences": {}}]
	var result: Array = []
	for window in ["early", "center", "late"]:
		result.append({
			"id": window,
			"label": "Release %s" % str(window).capitalize(),
			"text": "Readout target: %s. Progress %d/%d." % [str(readout.get("target_window", "center")).capitalize(), int(readout.get("progress", 0)), int(readout.get("required", 2))],
			"consequences": {"event_hooks": [{"type": "crew_practice_rig", "window": window}]},
		})
	result.append({"id": "leave", "label": "Step away", "text": "No stakes. No heat. The rig waits.", "consequences": {}})
	return result


func crew_practice_rig_session(window: String) -> Dictionary:
	var readout := crew_practice_rig_readout()
	var hit := window.strip_edges() == str(readout.get("target_window", ""))
	var grant := {}
	if hit:
		grant = grant_shared_training_progress("craps_setting_street_progress", "craps_setting_trained", int(readout.get("required", 2)), 1, true)
	return {"ok": ["early", "center", "late"].has(window), "hit": hit, "window": window, "target_window": str(readout.get("target_window", "")), "grant": grant, "message": "The dice settle inside the band." if hit else "The dice land outside the target band."}


func crew_rook_ride_status() -> Dictionary:
	var services := _copy_dict(CrewStateModelScript.config().get("member_services", {}))
	var rank := crew_rank("crew_rook")
	var caps := _copy_dict(services.get("rook_ride_uses_by_rank", {}))
	var discounts := _copy_dict(services.get("rook_ride_discount_percent_by_rank", {}))
	var cap := maxi(0, int(caps.get(rank, 0)))
	var day := int(floor(float(_crew_action_index()) / 48.0))
	var stored_day := int(narrative_flags.get("crew_rook_ride_day", -1))
	var used := maxi(0, int(narrative_flags.get("crew_rook_ride_uses", 0))) if stored_day == day else 0
	var active := bool(narrative_flags.get("crew_rook_ride_active", false))
	return {"available": cap > used and not active and current_travel_lock_remaining() <= 0, "rank": rank, "cap": cap, "used": used, "uses_remaining": maxi(0, cap - used), "discount_percent": clampi(int(discounts.get(rank, 0)), 0, 100), "active": active, "travel_locked": current_travel_lock_remaining() > 0, "day": day}


func crew_rook_begin_ride() -> Dictionary:
	var status := crew_rook_ride_status()
	if not bool(status.get("available", false)):
		return {"ok": false, "message": "Rook cannot move the car through this lock." if bool(status.get("travel_locked", false)) else "Rook's rides are used for this stretch."}
	narrative_flags["crew_rook_ride_day"] = int(status.get("day", 0))
	narrative_flags["crew_rook_ride_uses"] = int(status.get("used", 0))
	narrative_flags["crew_rook_ride_active"] = true
	narrative_flags["crew_rook_ride_discount_percent"] = int(status.get("discount_percent", 0))
	return {"ok": true, "status": crew_rook_ride_status(), "message": "Rook starts the car. Choose any normally open route."}


func crew_rook_finish_ride() -> Dictionary:
	if not bool(narrative_flags.get("crew_rook_ride_active", false)):
		return {}
	narrative_flags["crew_rook_ride_active"] = false
	narrative_flags["crew_rook_ride_discount_percent"] = 0
	narrative_flags["crew_rook_ride_day"] = int(floor(float(_crew_action_index()) / 48.0))
	narrative_flags["crew_rook_ride_uses"] = maxi(0, int(narrative_flags.get("crew_rook_ride_uses", 0))) + 1
	return crew_rook_ride_status()


func crew_mags_bench_status() -> Dictionary:
	var available := CrewStateModelScript.RANK_IDS.find(crew_rank("crew_mags")) >= CrewStateModelScript.RANK_IDS.find("associate")
	return {"available": available, "catalog_ready": true, "catalog_owner": "content06_1", "message": "Mags opens the labeled cases." if available else "Mags does not open the cases for strangers."}


func crew_action_index() -> int:
	return _crew_action_index()


func crew_play_actions(game_id: String, environment: Dictionary = current_environment) -> Array:
	if JSON.stringify(environment) != JSON.stringify(current_environment) or str(current_environment.get("active_game_id", "")) != game_id:
		return []
	return CrewPlayModelScript.available_actions(self, current_environment, game_id)


func crew_play_activate(play_id: String, game_id: String, environment: Dictionary = current_environment) -> Dictionary:
	if not crew_play_host_authorizes(_world1_host_capability, environment, game_id):
		return GameModule.build_action_result({"ok": false, "type": "game_action", "source_id": "crew_plays", "game_id": game_id, "action_id": "crew_play:%s" % play_id, "action_kind": "unknown", "message": "That crew play is not bound to the live table."})
	var rollback: Dictionary = _environment_turn_snapshot()
	var before_state := CrewPlayModelScript.normalize_state(crew_play_state)
	var before_bankroll := bankroll
	var before_chips := grand_casino_chips
	var result := CrewPlayModelScript.activate(self, current_environment, game_id, play_id, _world1_host_capability)
	var after_state := CrewPlayModelScript.normalize_state(crew_play_state)
	var valid := bool(result.get("ok", false)) \
		and str(result.get("source_id", "")) == "crew_plays" and str(result.get("game_id", "")) == game_id \
		and int(after_state.get("sequence", -1)) == int(before_state.get("sequence", 0)) + 1 \
		and bankroll == before_bankroll + int(result.get("bankroll_delta", 0)) \
		and grand_casino_chips == before_chips + int(result.get("chips_delta", 0))
	if not valid:
		_apply_environment_turn_snapshot(rollback, false)
		return GameModule.build_action_result({"ok": false, "type": "game_action", "source_id": "crew_plays", "game_id": game_id, "action_id": "crew_play:%s" % play_id, "action_kind": "unknown", "message": "The table host rejected an incomplete play transaction."})
	return result


func crew_play_host_authorizes(host_capability: Variant, environment: Dictionary, game_id: String, require_active_game: bool = true) -> bool:
	if host_capability == null or host_capability != _world1_host_capability or JSON.stringify(environment) != JSON.stringify(current_environment):
		return false
	return not require_active_game or not game_id.is_empty() and str(current_environment.get("active_game_id", "")) == game_id


func crew_play_active(play_id: String, environment: Dictionary = current_environment) -> bool:
	return CrewPlayModelScript.is_active(crew_play_state, play_id, _crew_action_index(), environment)


func crew_play_active_status(game_id: String = "", environment: Dictionary = current_environment) -> Array:
	return CrewPlayModelScript.active_status(crew_play_state, _crew_action_index(), environment, game_id)


func crew_heist_free_play_available() -> bool:
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	return str(state.get("status", "")) == CrewHeistModelScript.STATUS_PLAY and int(_copy_dict(state.get("play", {})).get("free_play", 0)) > 0


func crew_heist_consume_free_play() -> bool:
	if not crew_heist_free_play_available():
		return false
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	var play := _copy_dict(state.get("play", {}))
	play["free_play"] = maxi(0, int(play.get("free_play", 0)) - 1)
	state["play"] = play
	crew_heist_state = state
	return true


func crew_play_effect_int(play_id: String, effect_key: String, fallback: int, environment: Dictionary = current_environment) -> int:
	return CrewPlayModelScript.effect_int(crew_play_state, play_id, effect_key, _crew_action_index(), environment, fallback)


func crew_play_adjust_suspicion(amount: int, game_id: String, environment: Dictionary = current_environment) -> int:
	if amount <= 0 or game_id != "blackjack":
		return amount
	var multiplier := crew_play_effect_int("spotter", "suspicion_multiplier_percent", 100, environment)
	return maxi(0, int(ceil(float(amount) * float(multiplier) / 100.0)))


func crew_play_adjust_detection_chance(chance: int, environment: Dictionary = current_environment) -> int:
	var multiplier := crew_play_effect_int("table_flood", "cheat_detection_multiplier_percent", 100, environment)
	return clampi(int(ceil(float(maxi(0, chance)) * float(multiplier) / 100.0)), 0, 100)


func crew_job_definition_pending(definition_id: String) -> bool:
	var clean_id := definition_id.strip_edges()
	for job_value in crew_jobs.values():
		if typeof(job_value) != TYPE_DICTIONARY:
			continue
		var job: Dictionary = job_value
		if str(job.get("definition_id", "")) == clean_id and str(job.get("status", "")) != "resolved":
			return true
	return false


func crew_close_rook_leads_event() -> void:
	var event_ids := _copy_array(current_environment.get("event_ids", []))
	event_ids.erase("recruitment_rook_leads")
	current_environment["event_ids"] = event_ids
	store_current_world_node_environment()


func crew_switch_intel_status() -> Dictionary:
	var available := crew_rank_perks("crew_switch").has("remote_scenario_reveal")
	var services := _copy_dict(CrewStateModelScript.config().get("member_services", {}))
	var cap := maxi(1, int(services.get("switch_intel_uses_per_visit", 2)))
	var visit_id := _event_cadence_visit_key(current_environment)
	var stored_visit_id := str(current_environment.get("crew_switch_intel_visit_id", ""))
	var used := maxi(0, int(current_environment.get("crew_switch_intel_uses", 0))) if not visit_id.is_empty() and stored_visit_id == visit_id else 0
	return {"available": available and used < cap, "rank_gated": not available, "uses": used, "uses_remaining": maxi(0, cap - used), "cap": cap, "visit_id": visit_id}


func crew_switch_reveal_candidates() -> Array:
	if not bool(crew_switch_intel_status().get("available", false)):
		return []
	var result: Array = []
	for node_value in _copy_array(world_map.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", "")).strip_edges()
		if node_id.is_empty() or node_id == current_world_node_id() or bool(node.get("scouted", false)):
			continue
		var scenario := seeded_scenario_for_node(node_id)
		if scenario.is_empty():
			continue
		result.append({
			"node_id": node_id,
			"display_name": str(node.get("display_name", node.get("name", node_id.replace("_", " ").capitalize()))),
			"scenario_id": str(scenario.get("id", "")),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("node_id", "")) < str(b.get("node_id", "")))
	return result


# Switch upgrades a true seeded scenario fact through the existing heard/scouted
# pipeline. The use counter lives in the node snapshot and resets on a new room.
func crew_switch_reveal_node(node_id: String) -> Dictionary:
	var status := crew_switch_intel_status()
	var target := node_id.strip_edges()
	if not bool(status.get("available", false)) or target.is_empty() or seeded_scenario_for_node(target).is_empty():
		return {"ok": false, "node_id": target, "status": status}
	var heard := hear_rumor("scenario:%s" % target)
	if heard.is_empty():
		return {"ok": false, "node_id": target, "status": status}
	world_map = WorldMap.mark_scouted(world_map, target)
	current_environment["crew_switch_intel_visit_id"] = str(status.get("visit_id", ""))
	current_environment["crew_switch_intel_uses"] = int(status.get("uses", 0)) + 1
	store_current_world_node_environment()
	return {"ok": true, "node_id": target, "heard": heard, "status": crew_switch_intel_status()}


func crew_rook_escort_available() -> bool:
	return crew_rank_perks("crew_rook").has("rook_l3_escort")


func crew_knuckles_stash_status() -> Dictionary:
	var cap := CrewRecruitmentModelScript.stash_cap()
	var available := crew_rank_perks("crew_knuckles").has("contraband_stash")
	return {"available": available and crew_contraband_stash.size() < cap, "rank_gated": not available, "count": crew_contraband_stash.size(), "cap": cap, "item_ids": crew_contraband_stash.duplicate(true)}


func crew_knuckles_stash_candidates() -> Array:
	var result: Array = []
	var definitions := _item_definition_index()
	for inventory_index in range(inventory.size()):
		var item_id := _inventory_item_id(inventory[inventory_index])
		var definition := _copy_dict(definitions.get(item_id, {}))
		var risk_flags := _string_array(_copy_array(definition.get("risk_flags", [])))
		if str(definition.get("class", "")).strip_edges().to_lower() == "contraband" or risk_flags.has("contraband"):
			result.append({"candidate_id": "inventory:%d" % inventory_index, "inventory_index": inventory_index, "item_id": item_id})
	return result


func crew_knuckles_retrieve_candidates() -> Array:
	var result: Array = []
	for stash_index in range(crew_contraband_stash.size()):
		result.append({"candidate_id": "stash:%d" % stash_index, "stash_index": stash_index, "item_id": _inventory_item_id(crew_contraband_stash[stash_index])})
	return result


# Moves carried contraband out of sweep-visible inventory. Stashed entries keep
# their exact inventory shape and therefore survive confiscation encounters.
func crew_knuckles_stash_item(item_id: String) -> Dictionary:
	var clean_id := item_id.strip_edges()
	for candidate_value in crew_knuckles_stash_candidates():
		if typeof(candidate_value) == TYPE_DICTIONARY and str((candidate_value as Dictionary).get("item_id", "")) == clean_id:
			return crew_knuckles_stash_inventory_entry(int((candidate_value as Dictionary).get("inventory_index", -1)), clean_id)
	return {"ok": false, "item_id": clean_id, "status": crew_knuckles_stash_status()}


func crew_knuckles_stash_inventory_entry(inventory_index: int, expected_item_id: String) -> Dictionary:
	var status := crew_knuckles_stash_status()
	var clean_id := expected_item_id.strip_edges()
	if not bool(status.get("available", false)) or inventory_index < 0 or inventory_index >= inventory.size() \
		or _inventory_item_id(inventory[inventory_index]) != clean_id:
		return {"ok": false, "item_id": clean_id, "status": status}
	var valid_candidate := false
	for candidate_value in crew_knuckles_stash_candidates():
		if typeof(candidate_value) == TYPE_DICTIONARY and int((candidate_value as Dictionary).get("inventory_index", -1)) == inventory_index:
			valid_candidate = true
			break
	if not valid_candidate:
		return {"ok": false, "item_id": clean_id, "status": status}
	crew_contraband_stash.append(_persistent_copy_value(inventory[inventory_index]))
	inventory.remove_at(inventory_index)
	invalidate_inventory_effect_cache()
	if active_item_id == clean_id:
		active_item_id = ""
	return {"ok": true, "item_id": clean_id, "status": crew_knuckles_stash_status()}


func crew_knuckles_retrieve_item(item_id: String) -> Dictionary:
	var clean_id := item_id.strip_edges()
	for candidate_value in crew_knuckles_retrieve_candidates():
		if typeof(candidate_value) == TYPE_DICTIONARY and str((candidate_value as Dictionary).get("item_id", "")) == clean_id:
			return crew_knuckles_retrieve_stash_entry(int((candidate_value as Dictionary).get("stash_index", -1)), clean_id)
	return {"ok": false, "item_id": clean_id}


func crew_knuckles_retrieve_stash_entry(stash_index: int, expected_item_id: String) -> Dictionary:
	var clean_id := expected_item_id.strip_edges()
	if not crew_rank_perks("crew_knuckles").has("contraband_stash") or stash_index < 0 or stash_index >= crew_contraband_stash.size() \
		or _inventory_item_id(crew_contraband_stash[stash_index]) != clean_id:
		return {"ok": false, "item_id": clean_id}
	inventory.append(_persistent_copy_value(crew_contraband_stash[stash_index]))
	crew_contraband_stash.remove_at(stash_index)
	invalidate_inventory_effect_cache()
	return {"ok": true, "item_id": clean_id, "status": crew_knuckles_stash_status()}


func triggered_event_pending(event_id: String) -> bool:
	var clean_id := event_id.strip_edges()
	if clean_id.is_empty():
		return false
	if str(active_triggered_event.get("event_id", "")) == clean_id:
		return true
	for entry_value in pending_triggered_events:
		if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("event_id", "")) == clean_id:
			return true
	return false


func _reconcile_crew_recruitment_perks() -> void:
	if crew_rook_escort_available():
		narrative_flags["rook_escort_punchline_back_room"] = true


# Derives crew-wide standing and the registered shared/heist gates.
func crew_standing() -> Dictionary:
	var total_trust := 0
	var highest_rank_index := 0
	var ranks := {}
	var made_members: Array = []
	var inner_circle_members: Array = []
	for member_id in CrewStateModelScript.MEMBER_IDS:
		var trust := crew_trust(member_id)
		var rank_id := crew_rank(member_id)
		total_trust += trust
		ranks[member_id] = rank_id
		highest_rank_index = maxi(highest_rank_index, CrewStateModelScript.RANK_IDS.find(rank_id))
		if CrewStateModelScript.RANK_IDS.find(rank_id) >= CrewStateModelScript.RANK_IDS.find("made"):
			made_members.append(member_id)
		if rank_id == "inner_circle":
			inner_circle_members.append(member_id)
	var heist_eligibility := {}
	var requirements: Dictionary = CrewStateModelScript.config().get("heist_requirements", {})
	for plan_id_value in requirements.keys():
		var plan_id := str(plan_id_value)
		var eligible := true
		for member_value in _copy_array(requirements.get(plan_id_value, [])):
			if crew_rank(str(member_value)) != "inner_circle":
				eligible = false
				break
		heist_eligibility[plan_id] = eligible
	return {
		"rank": CrewStateModelScript.RANK_IDS[highest_rank_index],
		"total_trust": total_trust,
		"average_trust": int(floor(float(total_trust) / float(CrewStateModelScript.MEMBER_IDS.size()))),
		"member_ranks": ranks,
		"made_members": made_members,
		"inner_circle_members": inner_circle_members,
		"layer_3_access": not made_members.is_empty(),
		"heist_eligibility": heist_eligibility,
	}


# Public planning-table projection. It reports truthful missing stars without
# exposing hidden seed mechanics or The Turn's private state.
func crew_heist_planning_status() -> Dictionary:
	var rows: Array = []
	var any_inner_circle := not _copy_array(crew_standing().get("inner_circle_members", [])).is_empty()
	for plan_id in CrewHeistModelScript.PLAN_IDS:
		var definition := CrewHeistModelScript.plan(plan_id)
		var missing: Array = []
		for criterion_value in _copy_array(definition.get("crew_criteria", [])):
			var criterion := _copy_dict(criterion_value)
			var required_rank := str(criterion.get("rank", "inner_circle"))
			if CrewStateModelScript.RANK_IDS.find(crew_rank(str(criterion.get("member_id", "")))) < CrewStateModelScript.RANK_IDS.find(required_rank):
				missing.append(str(criterion.get("label", "The crew is not ready.")))
		for criterion_value in _copy_array(definition.get("world_criteria", [])):
			var criterion := _copy_dict(criterion_value)
			var found := false
			if str(criterion.get("kind", "")) == "scenario_hook":
				found = _crew_heist_world_has_hook(str(criterion.get("key", "")))
			else:
				for key_value in _copy_array(criterion.get("keys", [])):
					if _crew_heist_world_has_hook(str(key_value)):
						found = true
						break
			if not found:
				missing.append(str(criterion.get("label", "The night does not carry this score.")))
		rows.append({
			"id": plan_id,
			"label": str(definition.get("label", plan_id)),
			"live": any_inner_circle and missing.is_empty() and crew_heist_state.is_empty(),
			"missing_stars": missing,
		})
	return {
		"visible": any_inner_circle,
		"locked_plan_id": str(crew_heist_state.get("plan_id", "")),
		"phase": str(crew_heist_state.get("status", "")),
		"plans": rows if any_inner_circle else [],
	}


func crew_heist_table_choices() -> Array:
	var status := crew_heist_planning_status()
	if not crew_heist_state.is_empty():
		var active_choices: Array = []
		var phase := str(crew_heist_state.get("status", "setup"))
		var plan_id := str(crew_heist_state.get("plan_id", ""))
		var setup := _copy_dict(crew_heist_state.get("setup", {}))
		var play := _copy_dict(crew_heist_state.get("play", {}))
		active_choices.append({"id": "inspect", "label": "Read the live score", "text": "The locked plan is in %s." % phase.replace("_", " "), "consequences": {}})
		if phase == CrewHeistModelScript.STATUS_SETUP:
			active_choices.append({"id": "table_talk", "label": "Let the room talk", "text": "Nobody has stood up yet.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "observe_table"}]}})
			active_choices.append_array(_crew_heist_private_choices())
			if plan_id == CrewHeistModelScript.PLAN_COUNT:
				if not bool(setup.get("schedule", false)):
					active_choices.append({"id": "count_schedule", "label": "Watch the schedule", "text": "Hold the cage through shift change.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "count_schedule"}]}})
				if not bool(setup.get("swap_cart", false)):
					active_choices.append({"id": "count_cart", "label": "Move the swap cart", "text": "Take the hard package route to the service perimeter.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "count_cart"}]}})
			else:
				_crew_heist_sync_whale_setup()
				setup = _copy_dict(crew_heist_state.get("setup", {}))
			active_choices.append({"id": "begin_play", "label": "Begin the Play", "text": "All chairs are filled." if CrewHeistModelScript.setup_complete(crew_heist_state) else "The setup still has an empty chair.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "begin_play"}]}})
			active_choices.append({"id": "abort", "label": "Fold the score", "text": "Pay for the preparation already burned. The run continues.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "abort"}]}})
		elif phase == CrewHeistModelScript.STATUS_PLAY:
			active_choices.append({"id": "live_table_direction", "label": "Return to the live table", "text": "The decisions happen inside the session, not over the planning map.", "disabled": true, "consequences": {}})
		active_choices.append({"id": "leave", "label": "Leave the table", "text": "The map stays where it is.", "consequences": {}})
		return active_choices
	if not bool(status.get("visible", false)):
		return [{"id": "leave", "label": "Leave the table clear", "text": "The center waits for somebody inside the circle.", "consequences": {}}]
	var choices: Array = []
	for row_value in _copy_array(status.get("plans", [])):
		var row := _copy_dict(row_value)
		var missing := _copy_array(row.get("missing_stars", []))
		choices.append({
			"id": "lock_%s" % str(row.get("id", "")),
			"label": "Lock %s" % str(row.get("label", "the plan")),
			"text": "The stars line up." if bool(row.get("live", false)) else " ".join(missing),
			"disabled": not bool(row.get("live", false)),
			"consequences": {"event_hooks": [{"type": "crew_heist", "action": "lock", "plan_id": str(row.get("id", ""))}]},
		})
	choices.append({"id": "leave", "label": "Leave the table clear", "text": "No score is forced tonight.", "consequences": {}})
	return choices


func crew_heist_live_table_choices() -> Array:
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	var phase := str(state.get("status", ""))
	if phase == CrewHeistModelScript.STATUS_INTERVIEW and str(state.get("plan_id", "")) == CrewHeistModelScript.PLAN_WHALE:
		var interview := _copy_dict(state.get("interview", {}))
		return [
			{"id": "interview_show_receipt", "label": "Show the receipt", "text": "Let the borrowed name survive the cage questions.", "disabled": bool(interview.get("cracked", false)), "consequences": {"event_hooks": [{"type": "crew_heist", "action": "resolve_interview", "choice": "show_receipt"}]}},
			{"id": "interview_cut_short", "label": "Cut it short", "text": "Call Rook before the borrowed name cracks in the light.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "resolve_interview", "choice": "cut_short"}]}},
		]
	if phase != CrewHeistModelScript.STATUS_PLAY or not _crew_heist_at_designated_table(state):
		return [{"id": "leave", "label": "Leave the quiet table", "text": "No crew beat is live here.", "consequences": {}}]
	var play := _copy_dict(state.get("play", {}))
	var plan_id := str(state.get("plan_id", ""))
	var result: Array = [{"id": "inspect", "label": "Read the live session", "text": "Round %d is settled." % int(play.get("round", 0)), "consequences": {}}]
	if plan_id == CrewHeistModelScript.PLAN_COUNT:
		var decision_id := _crew_heist_count_decision_due(state)
		if decision_id == "go":
			result.append_array(_crew_heist_decision_choices("go", ["early", "hold"]))
		elif decision_id == "distraction":
			result.append_array(_crew_heist_decision_choices("distraction", ["sit", "dump"]))
		elif decision_id == "exit":
			var exits := ["dock"]
			if bool(_copy_dict(state.get("setup", {})).get("guard_marker", false)):
				exits.append("corridor")
			result.append_array(_crew_heist_decision_choices("exit", exits))
	if int(play.get("round", 0)) >= int(_copy_dict(CrewHeistModelScript.plan(plan_id).get("play", {})).get("required_rounds", 1)) and (plan_id != CrewHeistModelScript.PLAN_COUNT or _copy_dict(play.get("decisions", {})).size() == 3):
		if plan_id == CrewHeistModelScript.PLAN_WHALE:
			result.append({"id": "begin_interview", "label": "Take the pot to the cage", "text": "The borrowed name still has to survive the interview.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "begin_interview"}]}})
		else:
			result.append({"id": "begin_getaway", "label": "Take the exit", "text": "Leave the live table for the marked route.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "begin_getaway"}]}})
	result.append({"id": "leave", "label": "Stay in the session", "text": "The table keeps moving only when you play.", "consequences": {}})
	return result


func _crew_heist_decision_choices(decision_id: String, values: Array) -> Array:
	var result: Array = []
	for value in values:
		var choice := str(value)
		result.append({"id": "%s_%s" % [decision_id, choice], "label": choice.replace("_", " ").capitalize(), "text": "Bishop records the choice, not an excuse.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "decide", "decision": decision_id, "choice": choice}]}})
	return result


func crew_record_heist_event_result(result: Dictionary) -> Dictionary:
	if not bool(result.get("ok", false)) or str(result.get("type", "")) != "event":
		return {"ok": false, "reason": "not_resolved_event"}
	var event_id := str(result.get("event_id", result.get("source_id", ""))).strip_edges()
	var choice_id := str(result.get("choice_id", result.get("action_id", ""))).strip_edges()
	if event_id not in ["crew_planning_table", "heist_live_table"] or choice_id.is_empty() \
			or not _copy_array(current_environment.get("event_ids", [])).has(event_id) \
			or _copy_array(current_environment.get("resolved_event_ids", [])).has(event_id):
		return {"ok": false, "reason": "event_not_live"}
	var live_choices := crew_heist_table_choices() if event_id == "crew_planning_table" else crew_heist_live_table_choices()
	var expected_hook: Dictionary = {}
	for choice_value in live_choices:
		var choice := _copy_dict(choice_value)
		if str(choice.get("id", "")) != choice_id or bool(choice.get("disabled", false)): continue
		var candidate_hooks: Array = []
		for hook_value in _copy_array(_copy_dict(choice.get("consequences", {})).get("event_hooks", [])):
			var candidate := _copy_dict(hook_value)
			if str(candidate.get("type", "")) == "crew_heist": candidate_hooks.append(candidate)
		if candidate_hooks.size() == 1: expected_hook = _copy_dict(candidate_hooks[0])
		break
	if expected_hook.is_empty(): return {"ok": false, "reason": "choice_not_live"}
	var supplied_hooks: Array = []
	for hook_value in _copy_array(_copy_dict(result.get("deltas", {})).get("event_hooks", [])):
		var supplied := _copy_dict(hook_value)
		if str(supplied.get("type", "")) == "crew_heist": supplied_hooks.append(supplied)
	if supplied_hooks.size() != 1 or JSON.stringify(supplied_hooks[0]) != JSON.stringify(expected_hook):
		return {"ok": false, "reason": "hook_mismatch"}
	return crew_heist_event_action(expected_hook, _crew_heist_host_capability)


func crew_heist_event_action(hook: Dictionary, host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability:
		return {"ok": false, "message": "The heist host rejected that action."}
	var rollback := _environment_turn_snapshot()
	var action := str(hook.get("action", ""))
	var result: Dictionary = {}
	match str(hook.get("action", "")):
		"lock": result = crew_heist_lock(str(hook.get("plan_id", "")), host_capability)
		"observe_table": result = crew_heist_observe_table(host_capability)
		"confront": result = crew_heist_confront(str(hook.get("member_id", "")), host_capability)
		"hedge": result = crew_heist_hedge(host_capability)
		"abort": result = crew_heist_abort("planning_table", host_capability)
		"count_schedule": result = crew_heist_begin_count_schedule(host_capability)
		"count_cart": result = crew_heist_begin_count_swap_cart(host_capability)
		"begin_play": result = crew_heist_begin_play(host_capability)
		"decide": result = crew_heist_decide(str(hook.get("decision", "")), str(hook.get("choice", "")), host_capability)
		"begin_interview": result = crew_heist_begin_interview(host_capability)
		"resolve_interview": result = crew_heist_resolve_interview(str(hook.get("choice", "")), host_capability)
		"begin_getaway": result = crew_heist_begin_getaway(host_capability)
		_: result = {"ok": false, "message": "That part of the plan is not live."}
	if not bool(result.get("ok", false)):
		_apply_environment_turn_snapshot(rollback, false)
		return result
	var action_codes := {"lock": 1, "observe_table": 2, "confront": 3, "hedge": 4, "abort": 5, "count_schedule": 6, "count_cart": 7, "begin_play": 8, "decide": 9, "begin_interview": 10, "resolve_interview": 11, "begin_getaway": 12}
	var phase_codes := {CrewHeistModelScript.STATUS_SETUP: 1, CrewHeistModelScript.STATUS_PLAY: 2, CrewHeistModelScript.STATUS_INTERVIEW: 3, CrewHeistModelScript.STATUS_GETAWAY: 4, CrewHeistModelScript.STATUS_COMPLETED: 5, CrewHeistModelScript.STATUS_ABORTED: 6}
	var state := CrewHeistModelScript.record_tombstone(crew_heist_state, _crew_action_index(), int(action_codes.get(action, 99)), int(phase_codes.get(str(crew_heist_state.get("status", "")), 9)))
	if state.is_empty():
		_apply_environment_turn_snapshot(rollback, false)
		return {"ok": false, "message": "The heist receipt could not be committed."}
	if action in ["observe_table", "confront", "hedge"]:
		var private_codes := {"observe_table": 1, "confront": 2, "hedge": 3}
		state["x"] = CrewTurnModelScript.record_tombstone(state.get("x", {}), _crew_action_index(), int(private_codes.get(action, 99)), CrewStateModelScript.MEMBER_IDS)
	crew_heist_state = state
	var sequence_result := world_sequence_schedule_heist_mount(action, host_capability)
	if not bool(sequence_result.get("ok", false)):
		_apply_environment_turn_snapshot(rollback, false)
		return {"ok": false, "message": "The heist scene could not be staged atomically.", "errors": _copy_array(sequence_result.get("errors", []))}
	result["world_sequence_scheduled"] = not bool(sequence_result.get("inactive", false))
	# Quiet-table actions schedule their scene internally, but the package/owner
	# token names the private observation channel. It is never needed as a player
	# command receipt, so do not echo it through the public action result.
	if action not in ["observe_table", "confront", "hedge"]:
		result["world_sequence_owner_token"] = str(sequence_result.get("owner_token", ""))
	return result


func crew_heist_lock(plan_id: String, host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	if not crew_heist_state.is_empty():
		return {"ok": false, "message": "One score is already the run's score."}
	for row_value in _copy_array(crew_heist_planning_status().get("plans", [])):
		var row := _copy_dict(row_value)
		if str(row.get("id", "")) == plan_id and bool(row.get("live", false)):
			crew_heist_state = CrewHeistModelScript.begin(plan_id, _crew_action_index())
			var met_members: Array = []
			for member_id in CrewStateModelScript.MEMBER_IDS:
				if crew_rank(member_id) != "stranger":
					met_members.append(member_id)
			var resolution_rng := create_rng("crew_heist_hidden").fork("lock:%s:%d" % [plan_id, _crew_action_index()])
			crew_heist_state["x"] = CrewTurnModelScript.resolve(
				CrewHeistModelScript.plan(plan_id), met_members, crew_grievances(), CrewStateModelScript.MEMBER_IDS,
				_copy_dict(CrewHeistModelScript.config().get("hidden_resolution", {})), resolution_rng
			)
			return {"ok": not crew_heist_state.is_empty(), "plan_id": plan_id, "message": "The plan is locked. The map stays on the table."}
	return {"ok": false, "message": "The plan's stars do not line up tonight."}


# Only diegetic options leave this method. Hidden member ids and progress never do.
func _crew_heist_private_choices() -> Array:
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	var hidden := _copy_dict(state.get("x", {}))
	var witnessed := CrewTurnModelScript.witnessed_count(hidden, CrewStateModelScript.MEMBER_IDS)
	var result: Array = []
	if witnessed == 1 and not bool(hidden.get("h", false)):
		result.append({"id": "change_seat", "label": "Change your place at the table", "text": "Move your part without explaining why.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "hedge"}]}})
	elif witnessed >= 2 and not bool(hidden.get("c", false)):
		var eligible := CrewTurnModelScript.eligible_members(CrewHeistModelScript.plan(str(state.get("plan_id", ""))), _crew_heist_met_members(), CrewStateModelScript.MEMBER_IDS)
		for member_id in eligible:
			result.append({"id": "close_door_%s" % member_id.trim_prefix("crew_"), "label": "Close the door on %s" % member_id.trim_prefix("crew_").capitalize(), "text": "Say the name once and accept what follows.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "confront", "member_id": member_id}]}})
	return result


func crew_heist_observe_table(host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("status", "")) != CrewHeistModelScript.STATUS_SETUP:
		return {"ok": false, "message": "The room has moved past talk."}
	var hidden := CrewTurnModelScript.normalize_state(state.get("x", {}), CrewStateModelScript.MEMBER_IDS)
	var member_id := CrewTurnModelScript.active_member(hidden, CrewStateModelScript.MEMBER_IDS)
	if member_id.is_empty():
		return {"ok": true, "message": "The room talks through the route one more time."}
	var emitted := _copy_array(hidden.get("e", []))
	if not emitted.has(CrewTurnModelScript.SIGNAL_PATTERN):
		var learned := tell_learned(member_id)
		hidden = CrewTurnModelScript.mark_emitted(hidden, CrewTurnModelScript.SIGNAL_PATTERN, learned, CrewStateModelScript.MEMBER_IDS)
		state["x"] = hidden
		crew_heist_state = state
		if learned:
			return {"ok": true, "message": "A familiar table tell surfaces in the quiet room. No cards are on the table."}
		# An unlearned tell must be observationally identical to a clean table.
		return {"ok": true, "message": "The room talks through the route one more time."}
	if not emitted.has(CrewTurnModelScript.SIGNAL_ROUTE):
		var contradiction := _crew_heist_route_contradiction(member_id)
		if not contradiction.is_empty():
			hidden = CrewTurnModelScript.mark_emitted(hidden, CrewTurnModelScript.SIGNAL_ROUTE, true, CrewStateModelScript.MEMBER_IDS)
			state["x"] = hidden
			crew_heist_state = state
			assert(bool(contradiction.get("checkable", false)), "Planning route line lacked a visited world record.")
			return {"ok": true, "message": "A neutral Crew voice gives a route claim that contradicts a visit you personally witnessed during the same window."}
	return {"ok": true, "message": "The route gets read without another word."}


func crew_heist_confront(member_id: String, host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	var hidden := CrewTurnModelScript.normalize_state(state.get("x", {}), CrewStateModelScript.MEMBER_IDS)
	if str(state.get("status", "")) != CrewHeistModelScript.STATUS_SETUP or CrewTurnModelScript.witnessed_count(hidden, CrewStateModelScript.MEMBER_IDS) < 2:
		return {"ok": false, "message": "The room does not follow you there."}
	var eligible := CrewTurnModelScript.eligible_members(CrewHeistModelScript.plan(str(state.get("plan_id", ""))), _crew_heist_met_members(), CrewStateModelScript.MEMBER_IDS)
	if not eligible.has(member_id):
		return {"ok": false, "message": "That chair is not yours to close."}
	if member_id == str(hidden.get("m", "")) and not member_id.is_empty():
		hidden["c"] = true
		hidden["m"] = ""
		var play := _copy_dict(state.get("play", {}))
		play["free_play"] = 1
		state["play"] = play
		state["x"] = hidden
		crew_heist_state = state
		return {"ok": true, "message": "%s stays after the others leave. The old debt comes out plain. One chair moves closer." % member_id.trim_prefix("crew_").capitalize()}
	grievance_add({"member_id": member_id, "kind": "wrong_accusation", "weight": 2, "source_ref": "heist_table"})
	var tuning := _copy_dict(CrewHeistModelScript.config().get("hidden_resolution", {}))
	var trust_cost := maxi(1, int(tuning.get("crew_trust_cost", 5)))
	for crew_member_id in CrewStateModelScript.MEMBER_IDS:
		crew_add_trust(crew_member_id, -trust_cost, "closed_door")
	# Re-run only the already-real member against the increased curve. The wrong
	# chair's new debt cannot become a candidate here, and a miss cannot fabricate
	# evidence. Existing evidence remains valid only if that same member fires.
	var real_member := CrewTurnModelScript.active_member(hidden, CrewStateModelScript.MEMBER_IDS)
	var escalation := int(hidden.get("f", 0)) + 1
	var reroll_rng := create_rng("crew_heist_hidden").fork("reroute:%s:%d:%d:%s" % [str(state.get("plan_id", "")), _crew_action_index(), escalation, real_member])
	var rerolled := CrewTurnModelScript.resolve(CrewHeistModelScript.plan(str(state.get("plan_id", ""))), [real_member], crew_grievances(real_member), CrewStateModelScript.MEMBER_IDS, tuning, reroll_rng, escalation)
	if str(rerolled.get("m", "")) == real_member:
		rerolled["e"] = _copy_array(hidden.get("e", []))
		rerolled["w"] = _copy_array(hidden.get("w", []))
	state["x"] = rerolled
	crew_heist_state = state
	return {"ok": true, "message": "%s leaves first. Nobody brightens the lamp for the next name." % member_id.trim_prefix("crew_").capitalize()}


func crew_heist_hedge(host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	var hidden := CrewTurnModelScript.normalize_state(state.get("x", {}), CrewStateModelScript.MEMBER_IDS)
	if str(state.get("status", "")) != CrewHeistModelScript.STATUS_SETUP or CrewTurnModelScript.witnessed_count(hidden, CrewStateModelScript.MEMBER_IDS) != 1 or bool(hidden.get("h", false)):
		return {"ok": false, "message": "The seats stay where they are."}
	hidden["h"] = true
	if CrewTurnModelScript.active_member(hidden, CrewStateModelScript.MEMBER_IDS).is_empty():
		var cost := maxi(1, int(_copy_dict(CrewHeistModelScript.config().get("hidden_resolution", {})).get("hedge_trust_cost", 2)))
		for member_id in CrewStateModelScript.MEMBER_IDS:
			crew_add_trust(member_id, -cost, "cold_feet")
	state["x"] = hidden
	crew_heist_state = state
	return {"ok": true, "message": "You move your own chair. The room notices and lets you keep the explanation."}


func _crew_heist_met_members() -> Array:
	var result: Array = []
	for member_id in CrewStateModelScript.MEMBER_IDS:
		if crew_rank(member_id) != "stranger":
			result.append(member_id)
	return result


func _crew_heist_route_contradiction(member_id: String) -> Dictionary:
	var actual := {}
	for node_value in _copy_array(world_map.get("nodes", [])):
		var node := _copy_dict(node_value)
		if str(node.get("state", "")) != "visited":
			continue
		var environment := _copy_dict(node.get("environment", {}))
		var period_start := int(environment.get("entered_game_clock_minutes", -1))
		var period_end := int(environment.get("departed_game_clock_minutes", -1))
		if period_start < 0 or period_end <= period_start:
			continue
		for presence_value in _copy_array(environment.get("crew_presence", [])):
			if str(_copy_dict(presence_value).get("member_id", "")) == member_id:
				actual = {"id": str(node.get("id", "")), "name": str(node.get("label", node.get("id", "the room"))), "period_start": period_start, "period_end": period_end}
				break
		if not actual.is_empty():
			break
	if actual.is_empty():
		return {}
	var claimed := {}
	for node_value in _copy_array(world_map.get("nodes", [])):
		var node := _copy_dict(node_value)
		if str(node.get("id", "")) != str(actual.get("id", "")):
			claimed = {"id": str(node.get("id", "")), "name": str(node.get("label", node.get("id", "the other room")))}
			break
	if claimed.is_empty():
		return {}
	return {"checkable": true, "actual_node_id": str(actual.get("id", "")), "actual_name": str(actual.get("name", "")), "claimed_node_id": str(claimed.get("id", "")), "claimed_name": str(claimed.get("name", "")), "period_start": int(actual.get("period_start", 0)), "period_end": int(actual.get("period_end", 0))}


static func _crew_clock_label(total_minutes: int) -> String:
	var minute_of_day := maxi(0, total_minutes) % 1440
	var hour_24 := int(floor(float(minute_of_day) / 60.0)) % 24
	var hour_12 := hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	return "%d:%02d %s" % [hour_12, minute_of_day % 60, "AM" if hour_24 < 12 else "PM"]


func crew_heist_abort(reason: String = "retreated", host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	if state.is_empty() or [CrewHeistModelScript.STATUS_PLAY, CrewHeistModelScript.STATUS_GETAWAY, CrewHeistModelScript.STATUS_COMPLETED, CrewHeistModelScript.STATUS_ABORTED].has(str(state.get("status", ""))):
		return {"ok": false, "message": "That retreat is no longer available."}
	var setup_count := _copy_dict(state.get("setup", {})).size()
	var requested_cost := 15 + setup_count * 10
	var paid := mini(requested_cost, maxi(0, bankroll - 1))
	bankroll -= paid
	state["status"] = CrewHeistModelScript.STATUS_ABORTED
	state["abort"] = {"reason": reason.strip_edges(), "cost": paid, "action": _crew_action_index()}
	crew_heist_state = state
	return {"ok": true, "cost": paid, "run_ended": false, "message": "The crew folds the map. Preparation costs $%d; the run stays yours." % paid}


func crew_heist_record_count_session(bet: int, heat_start: int, heat_peak: int, settled: bool = true, session_id: String = "", host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("plan_id", "")) != CrewHeistModelScript.PLAN_COUNT or str(state.get("status", "")) != CrewHeistModelScript.STATUS_SETUP:
		return {"ok": false}
	var tuning := _copy_dict(_copy_dict(CrewHeistModelScript.plan(CrewHeistModelScript.PLAN_COUNT).get("setup", {})).get("identity", {}))
	var qualifies := settled and bet >= int(tuning.get("bet_min", 0)) and bet <= int(tuning.get("bet_max", 0)) and heat_peak <= int(tuning.get("heat_ceiling", 100)) and heat_peak - heat_start < int(tuning.get("heat_ceiling", 100))
	var setup := _copy_dict(state.get("setup", {}))
	var session_ids := _copy_array(setup.get("identity_session_ids", []))
	var clean_session_id := session_id.strip_edges()
	if clean_session_id.is_empty():
		clean_session_id = "%s:%d" % [_event_cadence_visit_key(current_environment), int(current_environment.get("turns", 0))]
	if session_ids.has(clean_session_id):
		qualifies = false
	elif qualifies:
		session_ids.append(clean_session_id)
	setup["identity_session_ids"] = session_ids
	var count := session_ids.size()
	setup["identity_sessions"] = count
	setup["identity"] = count >= int(tuning.get("required_sessions", 1))
	state["setup"] = setup
	crew_heist_state = state
	return {"ok": true, "qualified": qualifies, "sessions": count, "complete": bool(setup.get("identity", false)), "message": "Bishop keeps the sessions that look like furniture."}


func crew_heist_begin_count_schedule(host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	return _crew_heist_begin_setup_delivery("schedule", true)


func crew_heist_begin_count_swap_cart(host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	return _crew_heist_begin_setup_delivery("swap_cart", false)


func crew_heist_record_whale_vouch(session_loss: int, entourage_beat: bool = true, host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("plan_id", "")) != CrewHeistModelScript.PLAN_WHALE or str(state.get("status", "")) != CrewHeistModelScript.STATUS_SETUP:
		return {"ok": false}
	var tuning := _copy_dict(_copy_dict(CrewHeistModelScript.plan(CrewHeistModelScript.PLAN_WHALE).get("setup", {})).get("vouch", {}))
	var setup := _copy_dict(state.get("setup", {}))
	var rounds := int(setup.get("vouch_rounds", 0)) + (1 if entourage_beat and session_loss < 0 else 0)
	var loss := int(setup.get("vouch_loss", 0)) + maxi(0, -session_loss)
	setup["vouch_rounds"] = rounds
	setup["vouch_loss"] = loss
	setup["vouch"] = rounds >= int(tuning.get("rounds", 1)) and loss >= int(tuning.get("loss_target", 1))
	state["setup"] = setup
	crew_heist_state = state
	return {"ok": true, "rounds": rounds, "loss": loss, "complete": bool(setup.get("vouch", false))}


func crew_heist_record_whale_rig(_component_sourced: bool = false, _training_source: String = "", host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("plan_id", "")) != CrewHeistModelScript.PLAN_WHALE or str(state.get("status", "")) != CrewHeistModelScript.STATUS_SETUP:
		return {"ok": false}
	var trained := bool(narrative_flags.get("craps_setting_trained", false))
	var sourced := inventory.has("false_bottom_cup")
	var setup := _copy_dict(state.get("setup", {}))
	setup["rig"] = sourced and trained
	setup["rig_source"] = "craps_setting_trained" if trained else ""
	state["setup"] = setup
	crew_heist_state = state
	return {"ok": true, "component": sourced, "trained": trained, "complete": bool(setup.get("rig", false))}


func crew_heist_record_whale_name(spend: int, seen_beat: bool, host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("plan_id", "")) != CrewHeistModelScript.PLAN_WHALE or str(state.get("status", "")) != CrewHeistModelScript.STATUS_SETUP:
		return {"ok": false}
	var tuning := _copy_dict(_copy_dict(CrewHeistModelScript.plan(CrewHeistModelScript.PLAN_WHALE).get("setup", {})).get("name", {}))
	var setup := _copy_dict(state.get("setup", {}))
	setup["name_spend"] = int(setup.get("name_spend", 0)) + maxi(0, spend)
	setup["name_seen"] = int(setup.get("name_seen", 0)) + (1 if seen_beat else 0)
	setup["name"] = int(setup.get("name_spend", 0)) >= int(tuning.get("spend_required", 0)) and int(setup.get("name_seen", 0)) >= int(tuning.get("seen_required", 0))
	state["setup"] = setup
	crew_heist_state = state
	return {"ok": true, "complete": bool(setup.get("name", false)), "spend": int(setup.get("name_spend", 0)), "seen": int(setup.get("name_seen", 0))}


func _crew_heist_sync_whale_setup() -> void:
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("plan_id", "")) != CrewHeistModelScript.PLAN_WHALE or str(state.get("status", "")) != CrewHeistModelScript.STATUS_SETUP:
		return
	var setup := _copy_dict(state.get("setup", {}))
	if bool(narrative_flags.get("heist_plan_b_whale_vouch", false)) and not bool(setup.get("vouch_event_seeded", false)):
		setup["vouch_event_seeded"] = true
		setup["vouch_rounds"] = maxi(1, int(setup.get("vouch_rounds", 0)))
		setup["vouch_loss"] = maxi(18, int(setup.get("vouch_loss", 0)))
	var vouch_tuning := _copy_dict(_copy_dict(CrewHeistModelScript.plan(CrewHeistModelScript.PLAN_WHALE).get("setup", {})).get("vouch", {}))
	setup["vouch"] = int(setup.get("vouch_rounds", 0)) >= int(vouch_tuning.get("rounds", 1)) and int(setup.get("vouch_loss", 0)) >= int(vouch_tuning.get("loss_target", 1))
	var has_component: bool = inventory.has("false_bottom_cup")
	var trained := bool(narrative_flags.get("craps_setting_trained", false))
	setup["rig"] = bool(setup.get("rig", false)) or (has_component and trained)
	var name_tuning := _copy_dict(_copy_dict(CrewHeistModelScript.plan(CrewHeistModelScript.PLAN_WHALE).get("setup", {})).get("name", {}))
	setup["name_spend"] = maxi(int(setup.get("name_spend", 0)), run_spending_score)
	setup["name_seen"] = _copy_array(setup.get("name_seen_ids", [])).size()
	setup["name"] = int(setup.get("name_spend", 0)) >= int(name_tuning.get("spend_required", 0)) and int(setup.get("name_seen", 0)) >= int(name_tuning.get("seen_required", 0))
	state["setup"] = setup
	crew_heist_state = state


func _crew_heist_boundary_sync() -> void:
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	state = _crew_heist_sync_count_window(state)
	_crew_heist_sync_live_table_event(state)
	if str(state.get("plan_id", "")) != CrewHeistModelScript.PLAN_WHALE or str(state.get("status", "")) != CrewHeistModelScript.STATUS_SETUP:
		return
	var hooks := _copy_dict(current_environment.get("scenario_hook_flags", {}))
	if bool(hooks.get("heist_plan_b_criteria", false)) or bool(hooks.get("gala_night", false)):
		var setup := _copy_dict(state.get("setup", {}))
		var seen_ids := _copy_array(setup.get("name_seen_ids", []))
		var visit_id := _event_cadence_visit_key(current_environment)
		if not visit_id.is_empty() and not seen_ids.has(visit_id):
			seen_ids.append(visit_id)
			setup["name_seen_ids"] = seen_ids
			state["setup"] = setup
			crew_heist_state = state
	_crew_heist_sync_whale_setup()


func crew_heist_begin_play(host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	if state.is_empty() or str(state.get("status", "")) != CrewHeistModelScript.STATUS_SETUP:
		return {"ok": false, "message": "There is no prepared play."}
	var setup := _copy_dict(state.get("setup", {}))
	if str(state.get("plan_id", "")) == CrewHeistModelScript.PLAN_COUNT:
		setup["guard_marker"] = bool(narrative_flags.get("debt_court_settlement", false)) and CrewStateModelScript.RANK_IDS.find(crew_rank("crew_knuckles")) >= CrewStateModelScript.RANK_IDS.find("associate")
	else:
		setup["drunk"] = bool(setup.get("vouch", false)) and bool(setup.get("rig", false)) and bool(setup.get("name", false))
	state["setup"] = setup
	if str(state.get("plan_id", "")) == CrewHeistModelScript.PLAN_COUNT and not bool(setup.get("identity", false)):
		crew_heist_state = state
		var forced_abort := crew_heist_abort("identity_shortfall", host_capability)
		forced_abort["forced"] = bool(forced_abort.get("ok", false))
		forced_abort["message"] = "The identity never held. Bishop folds the score and the preparation cost stays spent."
		return forced_abort
	if not CrewHeistModelScript.setup_complete(state):
		crew_heist_state = state
		return {"ok": false, "message": "The setup still has an empty chair."}
	state["status"] = CrewHeistModelScript.STATUS_PLAY
	narrative_flags["heist_live_table_active"] = true
	var play := _copy_dict(state.get("play", {}))
	if str(state.get("plan_id", "")) == CrewHeistModelScript.PLAN_WHALE:
		change_grand_casino_chips(int(_copy_dict(CrewHeistModelScript.plan(CrewHeistModelScript.PLAN_WHALE).get("play", {})).get("starting_pot", 0)), true)
		play["pot"] = grand_casino_chips
	state["play"] = play
	crew_heist_state = state
	state = _crew_heist_sync_count_window(state)
	_crew_heist_sync_live_table_event(state)
	return {"ok": true, "message": "The Play begins at the real table."}


func crew_heist_decide(decision_id: String, choice: String, host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("status", "")) != CrewHeistModelScript.STATUS_PLAY:
		return {"ok": false}
	var plan_id := str(state.get("plan_id", ""))
	var allowed := {"go": ["early", "hold"], "distraction": ["sit", "dump"], "exit": ["dock", "corridor"]}
	if plan_id != CrewHeistModelScript.PLAN_COUNT or not allowed.has(decision_id) or not _copy_array(allowed.get(decision_id, [])).has(choice):
		return {"ok": false}
	var setup := _copy_dict(state.get("setup", {}))
	if decision_id == "exit" and choice == "corridor" and not bool(setup.get("guard_marker", false)):
		return {"ok": false, "message": "The corridor has no marker."}
	var play := _copy_dict(state.get("play", {}))
	if decision_id == "exit" and choice == "corridor" and bool(play.get("corridor_blown", false)):
		return {"ok": false, "message": "The heat spike has already blown the corridor."}
	if _crew_heist_count_decision_due(state) != decision_id:
		return {"ok": false, "message": "That crew beat is not live in this round."}
	var decisions := _copy_dict(play.get("decisions", {}))
	decisions[decision_id] = choice
	play["decisions"] = decisions
	if choice in ["early", "dump"]:
		play["score"] = int(play.get("score", 100)) - 12
	if decision_id == "distraction":
		play["deliberate_heat"] = 6
		add_suspicion("heist_count_distraction", 6, "crew_heist", true)
	state["play"] = play
	crew_heist_state = state
	return {"ok": true, "decision": decision_id, "choice": choice}


func crew_heist_play_round(round_data: Dictionary, host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("status", "")) != CrewHeistModelScript.STATUS_PLAY:
		return {"ok": false}
	var plan_id := str(state.get("plan_id", ""))
	var tuning := _copy_dict(CrewHeistModelScript.plan(plan_id).get("play", {}))
	var play := _copy_dict(state.get("play", {}))
	var next_round := int(play.get("round", 0)) + 1
	var score := int(play.get("score", 100))
	if plan_id == CrewHeistModelScript.PLAN_COUNT:
		state = _crew_heist_sync_count_window(state)
		play = _copy_dict(state.get("play", {}))
		score = int(play.get("score", 100))
		if not _crew_heist_at_designated_table(state):
			return {"ok": false, "message": "The Count only moves at its designated table."}
		if _crew_heist_count_decision_due(state) != "":
			return {"ok": false, "message": "Bishop's live-table beat is still waiting."}
		if str(round_data.get("game_id", "")) != str(tuning.get("table_game", "blackjack")):
			return {"ok": false, "message": "That is not the designated boring table."}
		var bet := int(round_data.get("bet", 0))
		if bet < int(tuning.get("boring_bet_min", 0)) or bet > int(tuning.get("boring_bet_max", 0)):
			score -= 12
		if int(round_data.get("heat_delta", 0)) >= int(tuning.get("heat_spike", 1)):
			score -= 20
			play["heat_degraded"] = true
			play["corridor_blown"] = true
	else:
		if not _crew_heist_at_designated_table(state):
			return {"ok": false, "message": "The invitational is not running in this room."}
		var sequence := _copy_array(tuning.get("game_sequence", []))
		var expected_game_id := str(sequence[next_round - 1]) if next_round - 1 < sequence.size() else ""
		if expected_game_id.is_empty() or str(round_data.get("game_id", "")) != expected_game_id:
			return {"ok": false, "expected_game_id": expected_game_id, "message": "The invitational calls a different game this round."}
		var hazard := false
		for hazard_round_value in _copy_array(tuning.get("hazard_rounds", [])):
			if int(hazard_round_value) == next_round:
				hazard = true
				break
		var hidden := CrewTurnModelScript.normalize_state(state.get("x", {}), CrewStateModelScript.MEMBER_IDS)
		if hazard and not CrewTurnModelScript.active_member(hidden, CrewStateModelScript.MEMBER_IDS).is_empty():
			return _crew_heist_finish_whale_exposure(state, next_round, hidden)
		var honest := bool(round_data.get("honest", false))
		if hazard:
			var hazards := _copy_array(play.get("hazards", []))
			hazards.append({"round": next_round, "honest": honest})
			play["hazards"] = hazards
			score += 5 if honest else -30
		if bool(round_data.get("made", false)):
			score -= 25
			play["made"] = true
		play["pot"] = grand_casino_chips
		if int(play.get("pot", 0)) <= 0:
			play["bust"] = true
		var lifeline_sequence := _crew_heist_live_lifeline_sequence(str(round_data.get("game_id", "")), play)
		if lifeline_sequence > 0:
			var lifelines: Array = play.get("lifelines_used", [])
			if lifelines.size() < int(tuning.get("lifelines", 0)):
				lifelines.append(lifeline_sequence)
				play["lifelines_used"] = lifelines
				score += 8
	play["round"] = next_round
	play["score"] = clampi(score, 0, 100)
	state["play"] = play
	crew_heist_state = state
	return {"ok": true, "round": next_round, "score": int(play.get("score", 0)), "ready": next_round >= int(tuning.get("required_rounds", 1))}


# Plan B breaks at the felt, before interview/getaway. The exposed rig costs the
# live pot and raises concrete house attention; a changed seat saves only a
# deterministic partial haul and closes Out Hot at the same mid-game boundary.
func _crew_heist_finish_whale_exposure(state_value: Dictionary, round_index: int, hidden: Dictionary) -> Dictionary:
	var state := CrewHeistModelScript.normalize_state(state_value)
	var play := _copy_dict(state.get("play", {}))
	play["round"] = round_index
	play["interrupted"] = "house_points_at_rig"
	state["play"] = play
	var hedged := bool(hidden.get("h", false))
	var outcome := "out_hot" if hedged else "closed"
	var payout := 0
	var scar_id := ""
	if hedged:
		payout = _crew_heist_hidden_partial_payout(state)
		add_suspicion("heist_whale_exit", 10, "crew_heist", true, {}, true)
	else:
		scar_id = "rig_exposure"
		add_suspicion("heist_whale_rig_exposed", 25, "contraband", true, {}, true)
	grand_casino_chips = 0
	bankroll += payout
	state["status"] = CrewHeistModelScript.STATUS_COMPLETED
	state["outcome"] = outcome
	state["payout"] = payout
	if not scar_id.is_empty():
		play["scar"] = scar_id
		state["play"] = play
		story_flags["heist_scar_%s" % scar_id] = true
	crew_heist_state = state
	narrative_flags["heist_live_table_active"] = false
	_crew_heist_sync_live_table_event(state)
	var message := CrewHeistModelScript.ending_line(CrewHeistModelScript.PLAN_WHALE, outcome)
	narrative_flags["crew_heist_outcome"] = outcome
	narrative_flags["crew_heist_plan_id"] = CrewHeistModelScript.PLAN_WHALE
	_complete_demo_objective({"id": CREW_HEIST_ROUTE, "target_bankroll": bankroll, "victory_message": message}, message, {"finale_event_id": "heist_finale", "finale_branch": outcome, "demo_victory_route": CREW_HEIST_ROUTE})
	narrative_flags["act_two_seam_ready"] = true
	return {"ok": true, "resolved": true, "outcome": outcome, "payout": payout, "message": message}


func _crew_heist_hidden_partial_payout(state: Dictionary) -> int:
	var band := _copy_array(_copy_dict(CrewHeistModelScript.config().get("hidden_resolution", {})).get("partial_haul_percent_band", [35, 55]))
	var low := int(band[0]) if band.size() > 0 else 35
	var high := int(band[1]) if band.size() > 1 else low
	var partial_rng := create_rng("crew_heist_hidden").fork("partial:%s:%d" % [str(state.get("plan_id", "")), int(state.get("locked_action", 0))])
	return int(floor(float(CrewHeistModelScript.payout_for(state, "clean_sweep")) * float(partial_rng.randi_range(low, high)) / 100.0))


func crew_heist_begin_interview(host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("plan_id", "")) != CrewHeistModelScript.PLAN_WHALE or str(state.get("status", "")) != CrewHeistModelScript.STATUS_PLAY:
		return {"ok": false, "message": "No invitational pot is ready for the cage."}
	var play := _copy_dict(state.get("play", {}))
	var required_rounds := int(_copy_dict(CrewHeistModelScript.plan(CrewHeistModelScript.PLAN_WHALE).get("play", {})).get("required_rounds", 1))
	if int(play.get("round", 0)) < required_rounds:
		return {"ok": false, "message": "The invitational is not finished."}
	var cracked := int(play.get("score", 100)) < int(_copy_dict(CrewHeistModelScript.plan(CrewHeistModelScript.PLAN_WHALE).get("interview", {})).get("clean_score_min", 80)) or bool(play.get("made", false)) or bool(play.get("bust", false))
	state["status"] = CrewHeistModelScript.STATUS_INTERVIEW
	state["interview"] = {"started_action": _crew_action_index(), "cracked": cracked, "resolved": false}
	crew_heist_state = state
	return {"ok": true, "cracked": cracked, "message": "The cage counts the chips. Rourke lets the borrowed name answer for them."}


func crew_heist_resolve_interview(choice: String, host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("plan_id", "")) != CrewHeistModelScript.PLAN_WHALE or str(state.get("status", "")) != CrewHeistModelScript.STATUS_INTERVIEW:
		return {"ok": false}
	var interview := _copy_dict(state.get("interview", {}))
	if bool(interview.get("resolved", false)) or not ["show_receipt", "cut_short"].has(choice):
		return {"ok": false}
	if bool(interview.get("cracked", false)) and choice == "show_receipt":
		return {"ok": false, "message": "The borrowed name has already cracked."}
	interview["resolved"] = true
	interview["choice"] = choice
	if choice == "cut_short":
		interview["cracked"] = true
	state["interview"] = interview
	crew_heist_state = state
	return crew_heist_begin_getaway(host_capability)


func crew_heist_begin_getaway(host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	var plan_id := str(state.get("plan_id", ""))
	var phase := str(state.get("status", ""))
	if (plan_id == CrewHeistModelScript.PLAN_COUNT and phase != CrewHeistModelScript.STATUS_PLAY) or (plan_id == CrewHeistModelScript.PLAN_WHALE and (phase != CrewHeistModelScript.STATUS_INTERVIEW or not bool(_copy_dict(state.get("interview", {})).get("resolved", false)))):
		return {"ok": false, "message": "The Play is not ready to leave."}
	var definition := CrewHeistModelScript.plan(plan_id)
	var play := _copy_dict(state.get("play", {}))
	var play_tuning := _copy_dict(definition.get("play", {}))
	if int(play.get("round", 0)) < int(play_tuning.get("required_rounds", 1)):
		return {"ok": false, "message": "The table sequence is not finished."}
	if str(state.get("plan_id", "")) == CrewHeistModelScript.PLAN_COUNT and _copy_dict(play.get("decisions", {})).size() < 3:
		return {"ok": false, "message": "The Count still has a decision open."}
	var exit_choice := str(_copy_dict(play.get("decisions", {})).get("exit", "dock")) if plan_id == CrewHeistModelScript.PLAN_COUNT else "front_door"
	if plan_id == CrewHeistModelScript.PLAN_COUNT and bool(play.get("corridor_blown", false)):
		exit_choice = "dock"
	var target_id := _crew_heist_getaway_target(plan_id, exit_choice)
	if target_id.is_empty():
		return {"ok": false, "message": "The real town has no valid exit route."}
	var getaway_tuning := _copy_dict(definition.get("getaway", {}))
	var tuning := _copy_dict(_copy_dict(getaway_tuning.get("routes", {})).get(exit_choice, {})) if plan_id == CrewHeistModelScript.PLAN_COUNT else getaway_tuning
	var hot_whale_exit := plan_id == CrewHeistModelScript.PLAN_WHALE and (bool(_copy_dict(state.get("interview", {})).get("cracked", false)) or int(play.get("score", 100)) < 80 or bool(play.get("made", false)) or bool(play.get("bust", false)))
	var pursuit_pressure := 0
	if plan_id == CrewHeistModelScript.PLAN_COUNT:
		pursuit_pressure = int(tuning.get("pursuit_pressure", 0)) + (10 if bool(play.get("heat_degraded", false)) else 0)
	elif hot_whale_exit:
		pursuit_pressure = int(tuning.get("hot_pursuit_pressure", 0)) + (10 if bool(play.get("made", false)) or bool(play.get("bust", false)) else 0)
	var started := delivery_begin_getaway({
		"enabled": true,
		"run_id": "heist:%s:getaway" % str(state.get("plan_id", "")),
		"targets": [{"node_id": target_id}],
		"deadline_actions": int(tuning.get("deadline_actions", 10)),
		"pursuit_pressure": pursuit_pressure,
		"pursuit_per_boundary": 0 if plan_id == CrewHeistModelScript.PLAN_WHALE and not hot_whale_exit else 2,
		"pursuit_limit": int(tuning.get("pursuit_limit", 10)),
		"assists": ["rook_cutoff", "switch_route"],
		"assist_relief": 4,
		"cargo_id": "heist_take",
		"cargo_label": "The take",
		"cargo_heat_per_travel": 0,
		"consumer_payload": {"start_boundary_grace": 1},
	})
	if not bool(started.get("ok", false)):
		return started
	state["status"] = CrewHeistModelScript.STATUS_GETAWAY
	state["getaway"] = {"target_node_id": target_id, "exit": exit_choice, "status": "active", "chase": plan_id == CrewHeistModelScript.PLAN_COUNT or hot_whale_exit}
	crew_heist_state = state
	narrative_flags["heist_live_table_active"] = false
	_crew_heist_sync_live_table_event(state)
	return started


func crew_heist_snapshot() -> Dictionary:
	var public_state := CrewHeistModelScript.normalize_state(crew_heist_state)
	public_state.erase("x")
	return public_state


func _crew_heist_whale_attention_active() -> bool:
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	return str(state.get("plan_id", "")) == CrewHeistModelScript.PLAN_WHALE and str(state.get("status", "")) in [CrewHeistModelScript.STATUS_PLAY, CrewHeistModelScript.STATUS_INTERVIEW, CrewHeistModelScript.STATUS_GETAWAY] and _is_grand_casino_environment(current_environment)


func _crew_heist_capture_whale_attention() -> bool:
	if not _crew_heist_whale_attention_active() or suspicion_level() < 100:
		return false
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	var play := _copy_dict(state.get("play", {}))
	if not bool(play.get("made", false)):
		play["made"] = true
		play["score"] = maxi(0, int(play.get("score", 100)) - 25)
	play["rourke_attention_capped"] = true
	state["play"] = play
	crew_heist_state = state
	add_suspicion("heist_rourke_attention", -1, "crew_heist", true)
	return true


func _crew_heist_count_decision_due(state: Dictionary) -> String:
	if str(state.get("plan_id", "")) != CrewHeistModelScript.PLAN_COUNT or str(state.get("status", "")) != CrewHeistModelScript.STATUS_PLAY:
		return ""
	var play := _copy_dict(state.get("play", {}))
	var decisions := _copy_dict(play.get("decisions", {}))
	var round_index := int(play.get("round", 0))
	var decision_rounds := _copy_dict(_copy_dict(CrewHeistModelScript.plan(CrewHeistModelScript.PLAN_COUNT).get("play", {})).get("decision_rounds", {}))
	for decision_id in ["go", "distraction", "exit"]:
		if not decisions.has(decision_id) and round_index == int(decision_rounds.get(decision_id, -1)):
			return decision_id
	return ""


func _crew_heist_live_lifeline_sequence(game_id: String, play: Dictionary) -> int:
	var crew_state := CrewPlayModelScript.normalize_state(crew_play_state)
	var sequence := int(crew_state.get("sequence", 0))
	if sequence <= 0 or _copy_array(play.get("lifelines_used", [])).has(sequence):
		return 0
	var beat := _copy_dict(crew_state.get("last_beat", {}))
	if str(beat.get("play_id", "")).is_empty():
		return 0
	var beat_is_current := int(beat.get("action_index", -1000)) >= _crew_action_index() - 1
	var active_match := false
	for active_value in _copy_array(crew_state.get("active", [])):
		var active := _copy_dict(active_value)
		if int(active.get("sequence", 0)) == sequence and (str(active.get("game_id", "")).is_empty() or str(active.get("game_id", "")) == game_id):
			active_match = CrewPlayModelScript.is_active(crew_state, str(active.get("play_id", "")), _crew_action_index(), current_environment)
			break
	return sequence if beat_is_current or active_match else 0


func _crew_heist_sync_count_window(state: Dictionary) -> Dictionary:
	if str(state.get("plan_id", "")) != CrewHeistModelScript.PLAN_COUNT or str(state.get("status", "")) != CrewHeistModelScript.STATUS_PLAY:
		return state
	var play := _copy_dict(state.get("play", {}))
	var tuning := _copy_dict(CrewHeistModelScript.plan(CrewHeistModelScript.PLAN_COUNT).get("play", {}))
	if int(play.get("round", 0)) >= int(tuning.get("required_rounds", 1)):
		return state
	var action_index := _crew_action_index()
	if not play.has("window_started_action"):
		if not _crew_heist_at_designated_table(state):
			return state
		play["window_started_action"] = action_index
		play["window_deadline_action"] = action_index + maxi(1, int(tuning.get("window_actions", 1)))
		play["table_visit_id"] = _event_cadence_visit_key(current_environment)
	elif not _crew_heist_at_designated_table(state) and not bool(play.get("left_table", false)):
		play["left_table"] = true
		play["corridor_blown"] = true
		play["score"] = maxi(0, int(play.get("score", 100)) - 15)
	if action_index >= int(play.get("window_deadline_action", action_index + 1)) and not bool(play.get("late", false)):
		play["late"] = true
		play["heat_degraded"] = true
		play["corridor_blown"] = true
		play["score"] = maxi(0, int(play.get("score", 100)) - 20)
	state["play"] = play
	crew_heist_state = state
	return state


func _crew_heist_at_designated_table(state: Dictionary) -> bool:
	var archetype_id := str(current_environment.get("archetype_id", ""))
	if str(state.get("plan_id", "")) == CrewHeistModelScript.PLAN_COUNT:
		return archetype_id in GRAND_CASINO_ARCHETYPE_IDS
	return archetype_id == str(_copy_dict(CrewHeistModelScript.plan(CrewHeistModelScript.PLAN_WHALE).get("play", {})).get("venue_archetype", GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID))


func _crew_heist_sync_live_table_event(state: Dictionary) -> void:
	var phase := str(state.get("status", ""))
	var should_register := phase in [CrewHeistModelScript.STATUS_PLAY, CrewHeistModelScript.STATUS_INTERVIEW] and _crew_heist_at_designated_table(state)
	var was_registered := bool(narrative_flags.get("heist_live_table_registered", false))
	# Crew-ignoring runs must remain byte-identical at every boundary.  The
	# expensive world scan is cleanup for an event we actually registered, not
	# a speculative repair pass for every run in the game.
	if not was_registered and not should_register:
		return
	if was_registered:
		_remove_heist_live_table_event(current_environment)
		var nodes := _copy_array(world_map.get("nodes", []))
		for index in range(nodes.size()):
			if typeof(nodes[index]) == TYPE_DICTIONARY:
				var node := _copy_dict(nodes[index])
				var environment := _copy_dict(node.get("environment", {}))
				_remove_heist_live_table_event(environment)
				node["environment"] = environment
				nodes[index] = node
		world_map["nodes"] = nodes
		for room_id_value in grand_casino_room_states.keys():
			var room: Variant = grand_casino_room_states.get(room_id_value, {})
			if typeof(room) == TYPE_DICTIONARY:
				var clean_room := _copy_dict(room)
				_remove_heist_live_table_event(clean_room)
				grand_casino_room_states[room_id_value] = clean_room
		narrative_flags.erase("heist_live_table_registered")
	if not should_register:
		return
	var event_ids := _copy_array(current_environment.get("event_ids", []))
	if not event_ids.has("heist_live_table"):
		event_ids.append("heist_live_table")
		current_environment["event_ids"] = event_ids
	narrative_flags["heist_live_table_registered"] = true


func _remove_heist_live_table_event(environment: Dictionary) -> void:
	if environment.is_empty():
		return
	var event_ids := _copy_array(environment.get("event_ids", []))
	event_ids.erase("heist_live_table")
	environment["event_ids"] = event_ids
	var resolved := _copy_array(environment.get("resolved_event_ids", []))
	resolved.erase("heist_live_table")
	environment["resolved_event_ids"] = resolved


func _crew_heist_world_has_hook(hook_id: String) -> bool:
	if hook_id.is_empty():
		return false
	if bool(_copy_dict(current_environment.get("scenario_hook_flags", {})).get(hook_id, false)):
		return true
	for node_value in _copy_array(world_map.get("nodes", [])):
		var node := _copy_dict(node_value)
		var environment := _copy_dict(node.get("environment", {}))
		if bool(_copy_dict(environment.get("scenario_hook_flags", {})).get(hook_id, false)):
			return true
		var definition := _seeded_scenario_definition_for_node_readonly(str(node.get("id", "")))
		if bool(_copy_dict(_copy_dict(definition.get("mutations", {})).get("hook_flags", {})).get(hook_id, false)):
			return true
	return false


func _crew_heist_begin_setup_delivery(step: String, hold: bool) -> Dictionary:
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("plan_id", "")) != CrewHeistModelScript.PLAN_COUNT or str(state.get("status", "")) != CrewHeistModelScript.STATUS_SETUP:
		return {"ok": false}
	var setup := _copy_dict(state.get("setup", {}))
	if bool(setup.get(step, false)):
		return {"ok": false, "message": "That setup is already complete."}
	var target_id := _crew_heist_node_for_archetype(GRAND_CASINO_CAGE_ARCHETYPE_ID if hold else GRAND_CASINO_ARCHETYPE_ID)
	if target_id.is_empty():
		return {"ok": false, "message": "The setup has no real venue tonight."}
	var tuning := _copy_dict(_copy_dict(CrewHeistModelScript.plan(CrewHeistModelScript.PLAN_COUNT).get("setup", {})).get(step, {}))
	var spec := {
		"run_id": "heist:%s:%s" % [CrewHeistModelScript.PLAN_COUNT, step],
		"targets": [{"node_id": target_id}],
		"deadline_actions": int(tuning.get("deadline_actions", 12)),
		"cargo_id": "heist_swap_cart" if not hold else "heist_schedule_watch",
		"cargo_label": "Swap cart" if not hold else "Shift schedule",
		"cargo_heat_per_travel": 0,
	}
	if hold:
		spec["hold_required_actions"] = int(tuning.get("hold_required_actions", 2))
		spec["hold_attention_limit"] = int(tuning.get("attention_limit", 40))
	return delivery_begin_hold(spec) if hold else delivery_begin_package(spec)


func _crew_heist_node_for_archetype(archetype_id: String) -> String:
	for node_value in _copy_array(world_map.get("nodes", [])):
		var node := _copy_dict(node_value)
		if str(node.get("archetype_id", "")) == archetype_id:
			return str(node.get("id", ""))
	return ""


func _crew_heist_getaway_target(plan_id: String, exit_choice: String = "") -> String:
	var preferred_archetype := "small_underground_casino"
	if plan_id == CrewHeistModelScript.PLAN_COUNT:
		preferred_archetype = GRAND_CASINO_CAGE_ARCHETYPE_ID if exit_choice == "corridor" else "delta_queen"
	var preferred := _crew_heist_node_for_archetype(preferred_archetype)
	if not preferred.is_empty() and preferred != current_world_node_id():
		return preferred
	for node_value in _copy_array(world_map.get("nodes", [])):
		var node := _copy_dict(node_value)
		var node_id := str(node.get("id", ""))
		if not node_id.is_empty() and node_id != current_world_node_id():
			return node_id
	return ""


func _crew_heist_apply_delivery_resolution(run_id: String, succeeded: bool, resolution: Dictionary) -> void:
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	if state.is_empty() or not run_id.begins_with("heist:%s:" % str(state.get("plan_id", ""))):
		return
	var part := run_id.get_slice(":", 2)
	if part in ["schedule", "swap_cart"]:
		if succeeded:
			var setup := _copy_dict(state.get("setup", {}))
			setup[part] = true
			state["setup"] = setup
		crew_heist_state = state
		return
	if part != "getaway" or str(state.get("status", "")) != CrewHeistModelScript.STATUS_GETAWAY:
		return
	var play := _copy_dict(state.get("play", {}))
	var hidden := CrewTurnModelScript.normalize_state(state.get("x", {}), CrewStateModelScript.MEMBER_IDS)
	var active_member := CrewTurnModelScript.active_member(hidden, CrewStateModelScript.MEMBER_IDS)
	var outcome := CrewHeistModelScript.ladder(int(play.get("score", 0)), succeeded, bool(play.get("made", false)), bool(play.get("bust", false)))
	var payout := CrewHeistModelScript.payout_for(state, outcome)
	var scar_id := ""
	if not active_member.is_empty():
		if bool(hidden.get("h", false)):
			outcome = "out_hot"
			payout = _crew_heist_hidden_partial_payout(state)
		else:
			outcome = "closed"
			payout = 0
			scar_id = "corridor_breach" if str(state.get("plan_id", "")) == CrewHeistModelScript.PLAN_COUNT else "rig_exposure"
	if str(state.get("plan_id", "")) == CrewHeistModelScript.PLAN_WHALE:
		grand_casino_chips = 0
	bankroll += payout
	state["status"] = CrewHeistModelScript.STATUS_COMPLETED
	state["outcome"] = outcome
	state["payout"] = payout
	var getaway := _copy_dict(state.get("getaway", {}))
	getaway["status"] = "success" if succeeded else "failed"
	getaway["resolution"] = resolution.duplicate(true)
	if not scar_id.is_empty():
		getaway["scar"] = scar_id
		if scar_id == "corridor_breach":
			getaway["corridor_failed"] = true
			add_suspicion("heist_count_corridor_breach", 15, "crew_heist", true, {}, true)
		story_flags["heist_scar_%s" % scar_id] = true
	state["getaway"] = getaway
	crew_heist_state = state
	narrative_flags["heist_live_table_active"] = false
	_crew_heist_sync_live_table_event(state)
	var message := CrewHeistModelScript.ending_line(str(state.get("plan_id", "")), outcome)
	narrative_flags["crew_heist_outcome"] = outcome
	narrative_flags["crew_heist_plan_id"] = str(state.get("plan_id", ""))
	_complete_demo_objective({"id": CREW_HEIST_ROUTE, "target_bankroll": bankroll, "victory_message": message}, message, {"finale_event_id": "heist_finale", "finale_branch": outcome, "demo_victory_route": CREW_HEIST_ROUTE})
	narrative_flags["act_two_seam_ready"] = true


# Adds one typed hidden grievance and returns its normalized stored shape.
func grievance_add(entry: Dictionary) -> Dictionary:
	var member_id := str(entry.get("member_id", "")).strip_edges()
	var kind := str(entry.get("kind", "")).strip_edges()
	if not CrewStateModelScript.MEMBER_IDS.has(member_id) or not CrewStateModelScript.GRIEVANCE_KINDS.has(kind):
		return {}
	if crew_grievance_ledger.size() >= CrewTurnModelScript.PRIVATE_GRIEVANCE_LIMIT or crew_grievance_sequence >= CrewTurnModelScript.PRIVATE_SEQUENCE_LIMIT:
		narrative_flags["crew_private_authority_error"] = "private_authority_capacity_exceeded"
		return {"ok": false, "reason": "private_authority_capacity_exceeded"}
	var grievance_id := str(entry.get("id", "")).strip_edges()
	if grievance_id.is_empty():
		grievance_id = "crew_grievance_%04d" % (crew_grievance_sequence + 1)
	var source_ref := str(entry.get("source_ref", "")).strip_edges()
	var weight := int(entry.get("weight", 1))
	var turn_recorded := int(entry.get("turn_recorded", _crew_action_index()))
	if grievance_id.to_utf8_buffer().size() > CrewTurnModelScript.PRIVATE_TEXT_BYTE_LIMIT or source_ref.to_utf8_buffer().size() > CrewTurnModelScript.PRIVATE_TEXT_BYTE_LIMIT \
			or weight < 1 or weight > CrewTurnModelScript.PRIVATE_SEQUENCE_LIMIT \
			or turn_recorded < 0 or turn_recorded > CrewTurnModelScript.PRIVATE_SEQUENCE_LIMIT:
		narrative_flags["crew_private_authority_error"] = "private_authority_capacity_exceeded"
		return {"ok": false, "reason": "private_authority_capacity_exceeded"}
	crew_grievance_sequence += 1
	var normalized := {
		"id": grievance_id,
		"member_id": member_id,
		"kind": kind,
		"weight": weight,
		"turn_recorded": turn_recorded,
		"source_ref": source_ref,
	}
	crew_grievance_ledger.append(normalized)
	return normalized.duplicate(true)


# Returns a private ledger projection for crew06_9; presentation must not call it.
func crew_grievances(member_id: String = "") -> Array:
	var result: Array = []
	for entry_value in crew_grievance_ledger:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if member_id.is_empty() or str(entry.get("member_id", "")) == member_id:
			result.append(entry.duplicate(true))
	return result


# Private reader used by The Turn. Presentation and journal code must not call it.
func tell_learned(member_id: String) -> bool:
	return CrewPokerModelScript.learned(crew_pattern_memory, member_id)


# Records one condition-verified showdown exposure under neutral persisted ids.
func crew_record_pattern(member_id: String, state_key: String) -> bool:
	var before := tell_learned(member_id)
	crew_pattern_memory = CrewPokerModelScript.record_verified(crew_pattern_memory, member_id, state_key)
	return not before and tell_learned(member_id)


# Settles one friendly poker session. This is deliberately trust-only: poker
# has no path to the grievance ledger, regardless of win/loss or hustle streak.
func crew_record_poker_session(member_ids: Array, session_swing: int) -> Dictionary:
	var tuning := CrewPokerModelScript.config()
	var base_trust := maxi(0, int(tuning.get("session_trust", 2)))
	var threshold := maxi(1, int(tuning.get("hustle_threshold", 12)))
	var repeats := maxi(1, int(tuning.get("hustle_sessions_required", 2)))
	var bonus := maxi(0, int(tuning.get("hustle_respect_bonus", 1)))
	var applied := {}
	for member_value in member_ids:
		var member_id := str(member_value)
		if not CrewStateModelScript.MEMBER_IDS.has(member_id):
			continue
		var mark := int(crew_match_marks.get(member_id, 0))
		mark = mark + 1 if session_swing >= threshold else 0
		crew_match_marks[member_id] = mark
		var amount := base_trust + (bonus if mark >= repeats else 0)
		crew_add_trust(member_id, amount, "crew_poker_session")
		applied[member_id] = amount
	return applied


# Host-only lifecycle seam. The capability is an in-memory object identity owned
# by this RunState; it is never serialized, projected, or accepted from content.
func job_offer(job_definition: Dictionary, host_capability: RefCounted = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_job_host_capability:
		return {}
	var definition := CrewStateModelScript.normalize_job_definition(job_definition)
	if definition.is_empty():
		return {}
	crew_job_sequence += 1
	var action_index := _crew_action_index()
	var instance_id := "%s:%04d" % [str(definition.get("id", "crew_job")), crew_job_sequence]
	var job := definition.duplicate(true)
	job["id"] = instance_id
	job["definition_id"] = str(definition.get("id", ""))
	job["status"] = "offered"
	job["outcome"] = ""
	job["offered_action"] = action_index
	job["expires_at_action"] = action_index + maxi(1, int(definition.get("expiry_in_actions", 1)))
	crew_jobs[instance_id] = job
	return _crew_job_public_projection(job)


# Accepts one offered job without consuming an action boundary.
func job_accept(job_id: String, host_capability: RefCounted = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_job_host_capability:
		return {}
	var job := _crew_job(job_id)
	if str(job.get("status", "")) != "offered":
		return {}
	job["status"] = "accepted"
	job["accepted_action"] = _crew_action_index()
	crew_jobs[job_id] = job
	_scenario_publish_crew_job(job)
	return _crew_job_public_projection(job)


# Activates one accepted job; later gameplay slices own their active surface.
func job_activate(job_id: String, host_capability: RefCounted = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_job_host_capability:
		return {}
	var job := _crew_job(job_id)
	if str(job.get("status", "")) != "accepted":
		return {}
	job["status"] = "active"
	job["active_action"] = _crew_action_index()
	crew_jobs[job_id] = job
	_scenario_publish_crew_job(job)
	return _crew_job_public_projection(job)


# Resolves one accepted/active job and applies configured success or failure effects.
func job_resolve(job_id: String, outcome: String, host_capability: RefCounted = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_job_host_capability:
		return {}
	var job := _crew_job(job_id)
	if job.is_empty() or not CrewStateModelScript.JOB_OUTCOMES.has(outcome):
		return {}
	if not ["accepted", "active"].has(str(job.get("status", ""))):
		return {}
	var member_id := str(job.get("member_id", ""))
	if outcome == "success":
		var rewards: Dictionary = job.get("rewards", {}) if typeof(job.get("rewards", {})) == TYPE_DICTIONARY else {}
		var posted_cash := maxi(0, int(rewards.get("cash", 0)))
		var payment := _crew_heist_job_payment(member_id, posted_cash, job_id)
		var cash_reward := maxi(0, int(payment.get("paid", posted_cash)))
		if cash_reward > 0:
			change_bankroll(cash_reward, true)
		crew_add_trust(member_id, int(rewards.get("trust", 0)), "job:%s" % str(job.get("definition_id", "")))
		if cash_reward != posted_cash:
			job["posted_cash"] = posted_cash
			job["paid_cash"] = cash_reward
			job["payment_note"] = "The board says $%d. The envelope holds $%d." % [posted_cash, cash_reward]
	else:
		var failure: Dictionary = job.get("failure", {}) if typeof(job.get("failure", {})) == TYPE_DICTIONARY else {}
		crew_add_trust(member_id, int(failure.get("trust", 0)), "job:%s:%s" % [str(job.get("definition_id", "")), outcome])
		var grievance_kind := str(failure.get("grievance_kind", "")).strip_edges()
		if not grievance_kind.is_empty():
			grievance_add({
				"member_id": member_id,
				"kind": grievance_kind,
				"weight": maxi(1, int(failure.get("grievance_weight", 1))),
				"source_ref": job_id,
			})
	job["status"] = "resolved"
	job["outcome"] = outcome
	job["resolved_action"] = _crew_action_index()
	crew_jobs[job_id] = job
	_scenario_publish_crew_job(job)
	return _crew_job_public_projection(job)


func _crew_heist_job_payment(member_id: String, posted_cash: int, job_id: String) -> Dictionary:
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("status", "")) != CrewHeistModelScript.STATUS_SETUP or posted_cash <= 0:
		return {"paid": posted_cash}
	var hidden := CrewTurnModelScript.normalize_state(state.get("x", {}), CrewStateModelScript.MEMBER_IDS)
	if CrewTurnModelScript.active_member(hidden, CrewStateModelScript.MEMBER_IDS) != member_id or _copy_array(hidden.get("e", [])).has(CrewTurnModelScript.SIGNAL_PAYMENT):
		return {"paid": posted_cash}
	var percent := clampi(int(_copy_dict(CrewHeistModelScript.config().get("hidden_resolution", {})).get("payment_shortfall_percent", 25)), 1, 90)
	var shortfall := maxi(1, int(ceil(float(posted_cash) * float(percent) / 100.0)))
	var paid := maxi(0, posted_cash - shortfall)
	hidden = CrewTurnModelScript.mark_emitted(hidden, CrewTurnModelScript.SIGNAL_PAYMENT, true, CrewStateModelScript.MEMBER_IDS)
	state["x"] = hidden
	crew_heist_state = state
	assert(posted_cash - paid == shortfall and shortfall > 0, "Job payment did not retain a checkable board figure.")
	return {"paid": paid, "posted": posted_cash, "source": job_id}


# Player-safe Layer 3 board projection. Only jobs owned by crew physically in
# the room appear; the authored catalog remains broader than any one residency.
func crew_job_board_offers() -> Array:
	var result: Array = []
	for definition_value in CrewStateModelScript.job_definitions():
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = definition_value
		var definition_id := str(definition.get("id", ""))
		if definition_id == "crew_favor_delivery" or crew_job_definition_pending(definition_id):
			continue
		var member_id := str(definition.get("member_id", ""))
		var min_rank := str(definition.get("min_rank", "associate"))
		if not crew_member_present(member_id) \
			or CrewStateModelScript.RANK_IDS.find(crew_rank(member_id)) < CrewStateModelScript.RANK_IDS.find(min_rank):
			continue
		result.append({
			"definition_id": definition_id,
			"label": str(definition.get("label", definition_id.replace("_", " ").capitalize())),
			"member_id": member_id,
			"kind": str(definition.get("kind", "")),
			"expiry_in_actions": int(definition.get("expiry_in_actions", 1)),
			"cash": int(_copy_dict(definition.get("rewards", {})).get("cash", 0)),
			"trust": int(_copy_dict(definition.get("rewards", {})).get("trust", 0)),
			"member_present": true,
		})
	return result


func crew_job_board_choices(payload: Dictionary = {}) -> Array:
	var result: Array = []
	var flavor_lines := _string_array(payload.get("flavor_lines", []))
	var flavor_line := ""
	if not flavor_lines.is_empty():
		flavor_line = str(flavor_lines[posmod(seed_value + _crew_action_index(), flavor_lines.size())])
	for offer_value in crew_job_board_offers():
		var offer: Dictionary = offer_value
		var member_name := str(offer.get("member_id", "crew")).trim_prefix("crew_").capitalize()
		var detail := "%s%s · %d actions · $%d / trust %+d." % [
			str(offer.get("kind", "job")).replace("_", " ").capitalize(),
			" · here tonight",
			int(offer.get("expiry_in_actions", 1)), int(offer.get("cash", 0)), int(offer.get("trust", 0))]
		# The event surface has no board-level subtitle, so project the rotating
		# board note once on the first row instead of repeating it for every job.
		if not flavor_line.is_empty() and result.is_empty():
			detail = "%s\n%s" % [flavor_line, detail]
		result.append({
			"id": "accept_%s" % str(offer.get("definition_id", "")),
			"label": "%s · %s" % [str(offer.get("label", "Work")), member_name],
			"text": detail,
			"consequences": {"event_hooks": [{"type": "crew_job_accept", "definition_id": str(offer.get("definition_id", ""))}]},
		})
	result.append({"id": "leave", "label": "Leave the board", "text": "No promise made. The chalk stays clean.", "consequences": {}})
	return result


func crew_job_accept_definition(definition_id: String) -> Dictionary:
	var definition := CrewStateModelScript.job_definition(definition_id)
	if definition.is_empty() or crew_job_definition_pending(definition_id):
		return {"ok": false, "message": "That note is no longer open."}
	var member_id := str(definition.get("member_id", ""))
	var min_rank := str(definition.get("min_rank", "associate"))
	if not crew_member_present(member_id):
		return {"ok": false, "message": "That crew member is not in the room."}
	if CrewStateModelScript.RANK_IDS.find(crew_rank(member_id)) < CrewStateModelScript.RANK_IDS.find(min_rank):
		return {"ok": false, "message": "That work is above your standing."}
	var offered := job_offer(definition, _crew_job_host_capability)
	var job_id := str(offered.get("id", ""))
	if job_id.is_empty() or job_accept(job_id, _crew_job_host_capability).is_empty() or job_activate(job_id, _crew_job_host_capability).is_empty():
		return {"ok": false, "message": "The note will not come off the wall."}
	var payload := _copy_dict(definition.get("payload", {}))
	var kind := str(definition.get("kind", ""))
	if kind in ["package_run", "package_delivery", "numbers_route", "lookout_hold", "collection"]:
		var spec := payload.duplicate(true)
		spec["run_id"] = "crew_job:%s" % job_id
		spec["job_id"] = "" if kind == "collection" else job_id
		spec["deadline_actions"] = int(definition.get("expiry_in_actions", 1))
		spec["consumer_payload"] = {"success": {"cash": 0, "heat": 0}, "failure": {"cash": 0, "heat": 0}}
		var started := delivery_begin_multi_stop(spec) if kind == "numbers_route" else delivery_begin_hold(spec) if kind == "lookout_hold" else delivery_begin_package(spec)
		if not bool(started.get("ok", false)):
			job_resolve(job_id, "failed", _crew_job_host_capability)
			return started
		if kind == "collection":
			active_delivery_run["run_id"] = "crew_collection:%s" % job_id
		return {"ok": true, "job_id": job_id, "kind": kind, "delivery": started, "message": "The real-map route is marked."}
	if kind == "stake_horse":
		var stake := maxi(1, int(payload.get("crew_stake", 1)))
		payload["session_net"] = 0
		payload["loss_choice_pending"] = false
		var job := _crew_job(job_id)
		job["payload"] = payload
		crew_jobs[job_id] = job
		change_bankroll(stake, true)
		return {"ok": true, "job_id": job_id, "kind": kind, "crew_stake": stake, "message": "Crew money is in your pocket. Play the named game."}
	job_resolve(job_id, "failed", _crew_job_host_capability)
	return {"ok": false, "message": "That job kind has no live surface."}


# Central game-result seam: a stake horse advances only at its authored venue
# and game, using the canonical applied bankroll delta.
func crew_record_game_result(result: Dictionary, deltas: Dictionary) -> Dictionary:
	var game_id := str(result.get("game_id", result.get("source_id", "")))
	var venue_id := str(result.get("environment_archetype_id", current_environment.get("archetype_id", "")))
	_crew_heist_record_settled_game(game_id, venue_id, result, deltas)
	for job_id_value in crew_jobs.keys():
		var job_id := str(job_id_value)
		var job := _crew_job(job_id)
		if str(job.get("status", "")) != "active" or str(job.get("kind", "")) != "stake_horse":
			continue
		var payload := _copy_dict(job.get("payload", {}))
		if str(payload.get("game_id", "")) != game_id or str(payload.get("venue_id", "")) != venue_id:
			continue
		payload["session_net"] = int(payload.get("session_net", 0)) + int(deltas.get("bankroll_delta", 0))
		job["payload"] = payload
		crew_jobs[job_id] = job
		if int(payload.get("session_net", 0)) >= int(payload.get("profit_target", 1)):
			return job_resolve(job_id, "success", _crew_job_host_capability)
		if int(payload.get("session_net", 0)) <= -int(payload.get("crew_stake", 1)):
			payload["loss_choice_pending"] = true
			job["payload"] = payload
			crew_jobs[job_id] = job
			_crew_add_room_event("crew_stake_horse_loss")
		return _crew_job_public_projection(job)
	return {}


func _crew_heist_record_settled_game(game_id: String, venue_id: String, result: Dictionary, deltas: Dictionary) -> void:
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	if state.is_empty():
		return
	var phase := str(state.get("status", ""))
	var plan_id := str(state.get("plan_id", ""))
	var settled := _crew_heist_game_result_is_settled(game_id, result)
	if plan_id == CrewHeistModelScript.PLAN_WHALE and phase == CrewHeistModelScript.STATUS_PLAY and venue_id == str(_copy_dict(CrewHeistModelScript.plan(CrewHeistModelScript.PLAN_WHALE).get("play", {})).get("venue_archetype", GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID)):
		if not settled:
			_crew_heist_record_whale_pending_fact(game_id, _crew_heist_whale_result_facts(game_id, result))
			return
	if not settled:
		return
	var net := int(deltas.get("chips_delta", 0)) if str(result.get("currency", "")) == "chips" else int(deltas.get("bankroll_delta", 0))
	if phase == CrewHeistModelScript.STATUS_SETUP:
		if plan_id == CrewHeistModelScript.PLAN_COUNT and venue_id in GRAND_CASINO_ARCHETYPE_IDS:
			var session_id := str(result.get("session_id", "%s:%s" % [_event_cadence_visit_key(current_environment), game_id]))
			crew_heist_record_count_session(int(result.get("bet", result.get("wager", result.get("stake", 0)))), int(result.get("heat_start", suspicion_level())), int(result.get("heat_peak", suspicion_level())), bool(result.get("ok", true)), session_id, _crew_heist_host_capability)
		elif plan_id == CrewHeistModelScript.PLAN_WHALE and bool(narrative_flags.get("heist_plan_b_whale_vouch", false)) and net < 0 and _crew_heist_whale_vouch_table_active(venue_id):
			_crew_heist_sync_whale_setup()
			crew_heist_record_whale_vouch(net, true, _crew_heist_host_capability)
		return
	if phase != CrewHeistModelScript.STATUS_PLAY:
		return
	if plan_id == CrewHeistModelScript.PLAN_COUNT and venue_id in GRAND_CASINO_ARCHETYPE_IDS:
		crew_heist_play_round({"game_id": game_id, "bet": int(result.get("bet", result.get("wager", result.get("stake", 0)))), "heat_delta": int(result.get("heat_delta", deltas.get("suspicion_delta", 0)))}, _crew_heist_host_capability)
	elif plan_id == CrewHeistModelScript.PLAN_WHALE and venue_id == str(_copy_dict(CrewHeistModelScript.plan(CrewHeistModelScript.PLAN_WHALE).get("play", {})).get("venue_archetype", GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID)) and game_id in ["craps", "blackjack", "baccarat", "poker", "video_poker"]:
		var whale_facts := _crew_heist_whale_result_facts(game_id, result)
		state = CrewHeistModelScript.normalize_state(crew_heist_state)
		var play := _copy_dict(state.get("play", {}))
		var pending_by_game := _copy_dict(play.get("pending_game_facts", {}))
		var pending := _copy_dict(pending_by_game.get(game_id, {}))
		var expected_game_id := _crew_heist_whale_expected_game(state)
		if game_id == expected_game_id:
			pending_by_game.erase(game_id)
			play["pending_game_facts"] = pending_by_game
			state["play"] = play
			crew_heist_state = state
		var honest := bool(whale_facts.get("honest", true)) and not bool(pending.get("dishonest", false))
		var made_now := bool(whale_facts.get("made", false)) and not bool(play.get("made", false))
		crew_heist_play_round({"game_id": game_id, "honest": honest, "made": made_now, "pot_delta": net}, _crew_heist_host_capability)


func _crew_heist_whale_vouch_table_active(venue_id: String) -> bool:
	if venue_id.is_empty() or venue_id != str(current_environment.get("archetype_id", "")):
		return false
	var hooks := _copy_dict(current_environment.get("scenario_hook_flags", {}))
	var event_ids := _copy_array(current_environment.get("event_ids", []))
	return bool(hooks.get("whale_vouch_anchor", false)) or (bool(hooks.get("heist_plan_b_criteria", false)) and event_ids.has("scenario_whale_aboard_vouch"))


func _crew_heist_whale_expected_game(state: Dictionary) -> String:
	var sequence := _copy_array(_copy_dict(CrewHeistModelScript.plan(CrewHeistModelScript.PLAN_WHALE).get("play", {})).get("game_sequence", []))
	var round_index := int(_copy_dict(state.get("play", {})).get("round", 0))
	return str(sequence[round_index]) if round_index >= 0 and round_index < sequence.size() else ""


func _crew_heist_record_whale_pending_fact(game_id: String, facts: Dictionary) -> void:
	if bool(facts.get("honest", true)) and not bool(facts.get("made", false)):
		return
	var state := CrewHeistModelScript.normalize_state(crew_heist_state)
	var play := _copy_dict(state.get("play", {}))
	var pending_by_game := _copy_dict(play.get("pending_game_facts", {}))
	var pending := _copy_dict(pending_by_game.get(game_id, {}))
	pending["dishonest"] = bool(pending.get("dishonest", false)) or not bool(facts.get("honest", true))
	pending["made"] = bool(pending.get("made", false)) or bool(facts.get("made", false))
	if bool(facts.get("made", false)) and not bool(play.get("made", false)):
		play["made"] = true
		play["score"] = maxi(0, int(play.get("score", 100)) - 25)
		pending["made_penalty_applied"] = true
	pending_by_game[game_id] = pending
	play["pending_game_facts"] = pending_by_game
	state["play"] = play
	crew_heist_state = state


func _crew_heist_whale_result_facts(game_id: String, result: Dictionary) -> Dictionary:
	var action_kind := str(result.get("action_kind", "")).to_lower()
	var cheat_used := action_kind in ["cheat", "risky", "advantage"]
	var made := false
	match game_id:
		"blackjack":
			cheat_used = cheat_used or bool(result.get("player_cheat_used", false))
			made = bool(result.get("blackjack_cheat_caught", false)) or bool(result.get("dealer_caught_cheat", false))
		"baccarat":
			cheat_used = cheat_used or bool(result.get("baccarat_edge_sort_edge_used", false)) or bool(result.get("baccarat_edge_sort", false))
	var skill_outcome := str(result.get("skill_outcome", "")).to_lower()
	var skill_grade := str(result.get("skill_grade", "")).to_lower()
	made = made or skill_outcome.find("caught") >= 0 or skill_outcome.find("blown") >= 0 or skill_grade == "blown"
	return {"honest": not cheat_used, "made": made}


# GameModule's shared ActionResult deliberately carries no generic "settled"
# bit.  Completion is owned by each shipped game and exposed by the payload it
# adds after build_action_result.  Heist progress therefore consumes those
# production facts instead of treating an arbitrary legal input as a session.
func _crew_heist_game_result_is_settled(game_id: String, result: Dictionary) -> bool:
	if not bool(result.get("ok", false)):
		return false
	if result.has("settled"):
		return bool(result.get("settled", false))
	match game_id:
		"blackjack":
			return not _copy_array(result.get("blackjack_hand_results", [])).is_empty()
		"roulette":
			return not str(result.get("roulette_spin_id", "")).is_empty()
		"baccarat":
			return not str(result.get("baccarat_winner", "")).is_empty() and not _copy_dict(result.get("baccarat_hand", {})).is_empty()
		"craps":
			return not _copy_dict(result.get("craps_roll", {})).is_empty() and not _copy_array(result.get("craps_bet_results", [])).is_empty()
		"video_poker":
			return str(result.get("action_id", "")) == "draw" and not _copy_array(result.get("video_poker_hand_results", [])).is_empty()
	return false


func crew_stake_horse_loss_choices() -> Array:
	var pending := _pending_crew_job("stake_horse", "loss_choice_pending")
	if pending.is_empty():
		return []
	return [
		{"id": "repay", "label": "Repay the stake", "text": "Make the crew whole. The loss still costs trust.", "consequences": {"event_hooks": [{"type": "crew_stake_loss_choice", "choice": "repay"}], "resolve_event": true}},
		{"id": "shrug", "label": "Shrug it off", "text": "Call it the cost of doing business.", "consequences": {"event_hooks": [{"type": "crew_stake_loss_choice", "choice": "shrug"}], "resolve_event": true}},
	]


func crew_resolve_stake_horse_loss(choice_id: String) -> Dictionary:
	var pending := _pending_crew_job("stake_horse", "loss_choice_pending")
	if pending.is_empty() or not ["repay", "shrug"].has(choice_id):
		return {"ok": false}
	var job_id := str(pending.get("id", ""))
	var payload := _copy_dict(pending.get("payload", {}))
	if choice_id == "repay":
		change_bankroll(-mini(bankroll, maxi(1, int(payload.get("crew_stake", 1)))), true)
	var resolved := job_resolve(job_id, "failed", _crew_job_host_capability)
	if choice_id == "shrug":
		grievance_add({"member_id": str(pending.get("member_id", "")), "kind": "stake_horse_loss_shrugged", "weight": 1, "source_ref": job_id})
	return {"ok": not resolved.is_empty(), "choice": choice_id, "job": resolved}


func crew_collection_choices() -> Array:
	var pending := _pending_crew_job("collection", "press_choice_pending")
	if pending.is_empty():
		return []
	return [
		{"id": "friendly", "label": "Keep the friendly face", "text": "Take the smaller envelope and leave the room intact.", "consequences": {"event_hooks": [{"type": "crew_collection_choice", "choice": "friendly"}], "resolve_event": true}},
		{"id": "press", "label": "Press harder", "text": "Take more cash and let the town remember the pressure.", "consequences": {"event_hooks": [{"type": "crew_collection_choice", "choice": "press"}], "resolve_event": true}},
	]


func crew_resolve_collection(choice_id: String) -> Dictionary:
	var pending := _pending_crew_job("collection", "press_choice_pending")
	if pending.is_empty() or not ["friendly", "press"].has(choice_id):
		return {"ok": false}
	var payload := _copy_dict(pending.get("payload", {}))
	var cash := int(payload.get("friendly_cash", 0)) if choice_id == "friendly" else int(payload.get("press_cash", 0))
	var heat := int(payload.get("friendly_heat", 0)) if choice_id == "friendly" else int(payload.get("press_heat", 0))
	if cash > 0:
		change_bankroll(cash, true)
	if heat > 0:
		add_suspicion("crew_collection_press", heat, "behavior", false, {}, true)
	var resolved := job_resolve(str(pending.get("id", "")), "success", _crew_job_host_capability)
	return {"ok": not resolved.is_empty(), "choice": choice_id, "cash": cash, "heat": heat, "job": resolved}


func _pending_crew_job(kind: String, payload_flag: String) -> Dictionary:
	for job_value in crew_jobs.values():
		if typeof(job_value) != TYPE_DICTIONARY:
			continue
		var job: Dictionary = job_value
		if str(job.get("status", "")) == "active" and str(job.get("kind", "")) == kind and bool(_copy_dict(job.get("payload", {})).get(payload_flag, false)):
			return job.duplicate(true)
	return {}


func _crew_add_room_event(event_id: String) -> void:
	var ids := _copy_array(current_environment.get("event_ids", []))
	if not ids.has(event_id):
		ids.append(event_id)
	current_environment["event_ids"] = ids
	store_current_world_node_environment()


# Starts or declines the Crew favor without changing ordinary travel. The
# shipped event rewards are applied only after the real in-venue handoff.
func resolve_crew_favor_delivery_job(choice_id: String, authored_consequences: Dictionary = {}) -> Dictionary:
	var offered := job_offer(CrewStateModelScript.job_definition("crew_favor_delivery"), _crew_job_host_capability)
	var job_id := str(offered.get("id", ""))
	if job_id.is_empty() or job_accept(job_id, _crew_job_host_capability).is_empty() or job_activate(job_id, _crew_job_host_capability).is_empty():
		return {}
	if choice_id != "run_package":
		return job_resolve(job_id, "failed", _crew_job_host_capability)
	var started := delivery_begin_package({
		"run_id": "crew_favor_delivery",
		"job_id": job_id,
		"source_event_id": "crew_favor_delivery",
		"attempt": int(offered.get("offered_action", 0)),
		"deadline_actions": 18,
		"cargo_id": "crew_package",
		"cargo_label": "Crew package",
		"cargo_heat_per_travel": 0,
		"consumer_payload": _delivery_event_consumer_payload(authored_consequences),
	})
	if not bool(started.get("ok", false)):
		job_resolve(job_id, "failed", _crew_job_host_capability)
	return started


func _delivery_event_consumer_payload(consequences: Dictionary) -> Dictionary:
	var succeeded := _copy_dict(consequences.get("success", {}))
	var failed := _copy_dict(consequences.get("failure", {}))
	return {
		"success": {
			"cash": maxi(0, int(succeeded.get("bankroll_delta", 0))),
			"clean_speed_bonus_cash": maxi(0, int(succeeded.get("clean_speed_bonus_cash", 0))),
			"heat": maxi(0, int(succeeded.get("suspicion_delta", 0))),
			"flags": _copy_dict(succeeded.get("flags", {})),
		},
		"failure": {
			"heat": maxi(0, int(failed.get("suspicion_delta", 0))),
			"flags": _copy_dict(failed.get("flags", {})),
		},
	}


# Creates the sole live Numbers owner binding. The object identity never enters
# a proposal, snapshot, serialized key, or caller-supplied context.
func _new_numbers_model() -> NumbersModel:
	if _numbers_host_capability == null:
		_numbers_host_capability = RefCounted.new()
	var model: NumbersModel = NumbersModelScript.new()
	model.bind_host_capability(_numbers_host_capability)
	return model


# Returns the player-safe Numbers projection used by venue surfaces.
func numbers_status() -> Dictionary:
	if numbers_state == null:
		return {}
	return numbers_state.status()


# Player-safe crew desk projection. Hidden solo knowledge, future handles, raw
# leak state, and detection rolls never cross this presentation seam.
func numbers_desk_status() -> Dictionary:
	if numbers_state == null:
		return {}
	var fix_stage := str(numbers_state.fix_state.get("status", "locked"))
	var current_day := numbers_state.day_at(numbers_state.action_index)
	var retry_ready := current_day >= int(numbers_state.fix_state.get("retry_day", 0))
	var public_stage := fix_stage if ["bribe_running", "camouflage", "payday"].has(fix_stage) else "ready" if _numbers_fix_eligible() and retry_ready else "locked"
	var venues: Array = []
	for venue_value in _copy_array(numbers_status().get("venue_status", [])):
		if typeof(venue_value) != TYPE_DICTIONARY:
			continue
		var venue: Dictionary = venue_value
		venues.append({
			"id": str(venue.get("id", "")),
			"label": str(venue.get("label", "Book")),
			"open": bool(venue.get("open", false)),
		})
	var lucky_rank := crew_rank("crew_lucky")
	var mags_rank := crew_rank("crew_mags")
	return {
		"runner_available": CrewStateModelScript.RANK_IDS.find(lucky_rank) >= CrewStateModelScript.RANK_IDS.find("associate")
			and numbers_state.action_index < numbers_state.post_action(current_day)
			and str(numbers_state.collection_state.get("status", "")) != "active"
			and not delivery_has_active_run(),
		"runner_active": str(numbers_state.collection_state.get("status", "")) == "active",
		"lucky_rank": lucky_rank,
		"mags_rank": mags_rank,
		"fix_eligible": _numbers_fix_eligible(),
		"fix_available": public_stage == "ready" and not delivery_has_active_run(),
		"fix_stage": public_stage,
		"allocation_available": public_stage == "camouflage",
		"venues": venues,
	}


# Narrow Silas presentation seam. The surface learns only whether the optional
# handle exchange belongs in the current encounter; it never receives the
# discovery counters, assembled flag, or unpublished number.
func numbers_silas_status() -> Dictionary:
	if numbers_state == null:
		return {"handle_available": false}
	var public_status := numbers_status()
	var late_book_open := false
	for venue_value in _copy_array(public_status.get("venue_status", [])):
		if typeof(venue_value) != TYPE_DICTIONARY:
			continue
		var venue: Dictionary = venue_value
		if bool(venue.get("open", false)) and int(venue.get("close_action", 0)) > int(public_status.get("post_action", 0)):
			late_book_open = true
			break
	return {
		"handle_available": bool(numbers_state.knowledge.get("assembled", false))
			and bool(public_status.get("posted", false))
			and late_book_open
			and numbers_state.known_number().is_empty(),
	}


# Silas is physically present in the rendered room. The environment is the
# authority during room restore/installation; the map cursor is its fallback.
func numbers_silas_is_here() -> bool:
	if town_state == null:
		return false
	var physical_node_id: String = str(current_environment.get("world_node_id", "")).strip_edges()
	if physical_node_id.is_empty():
		physical_node_id = current_world_node_id()
	return town_state.traveler_node("silas_snitch") == physical_node_id


# Buys one physical slip at the current Numbers venue. The model owns the slip;
# inventory carries one contraband stack marker so sweep handling stays canonical.
func numbers_buy_slip(digits: String, stake: int, play_type: String) -> Dictionary:
	if numbers_state == null:
		return {"ok": false, "message": "The book is not running."}
	var venue_id := str(current_environment.get("archetype_id", current_world_node_id())).strip_edges()
	if numbers_state.venue_definition(venue_id).is_empty():
		return {"ok": false, "message": "There is no Numbers book here."}
	if bankroll < stake:
		return {"ok": false, "message": "That stake is not in your pocket."}
	var result := numbers_state.buy_slip(venue_id, digits, stake, play_type, numbers_state.known_number())
	if not bool(result.get("ok", false)):
		return result
	change_bankroll(-stake)
	_sync_numbers_inventory_marker()
	return result


# Silas is an encounter, not a menu. This call succeeds only at his current node.
func numbers_buy_silas_tip(today_number: bool = false) -> Dictionary:
	if numbers_state == null or town_state == null:
		return {"ok": false, "message": "Silas is not here."}
	if not numbers_silas_is_here():
		return {"ok": false, "message": "Silas is drinking somewhere else."}
	if today_number and not bool(numbers_silas_status().get("handle_available", false)):
		return {"ok": false, "message": "Silas has no handle for you."}
	var tuning := _copy_dict(NumbersModelScript.tuning().get("past_posting", {}))
	var price := int(tuning.get("silas_today_number_price", 24)) if today_number else int(tuning.get("silas_tip_price", 12))
	if bankroll < price:
		return {"ok": false, "message": "Silas does not extend credit."}
	change_bankroll(-price)
	var result := numbers_state.buy_silas_tip(today_number)
	result["price"] = price
	result["message"] = "Silas sells a time and a place, not an apology."
	return result


# Lucky's associate route consumes the real-map delivery multi-stop entry point.
func numbers_begin_collection_route() -> Dictionary:
	if numbers_state == null or CrewStateModelScript.RANK_IDS.find(crew_rank("crew_lucky")) < CrewStateModelScript.RANK_IDS.find("associate"):
		return {"ok": false, "message": "Lucky does not hand that bag to strangers."}
	var tuning := _copy_dict(NumbersModelScript.tuning().get("runner", {}))
	var remaining := numbers_state.post_action(numbers_state.day_at(_crew_action_index())) - _crew_action_index()
	if remaining <= 0:
		return {"ok": false, "message": "Today's collection clock is already gone."}
	var venue_ids: Array = []
	for venue_value in NumbersModelScript.tuning().get("venues", []):
		if typeof(venue_value) != TYPE_DICTIONARY:
			continue
		var venue_id := str((venue_value as Dictionary).get("id", ""))
		if venue_id != "small_underground_casino" and venue_id != current_world_node_id():
			venue_ids.append(venue_id)
	venue_ids.sort()
	var stop_count_range := _copy_array(tuning.get("stop_count", [3, 4]))
	var stop_count := clampi(3 + posmod(seed_value + numbers_state.day_at(_crew_action_index()), 2), 3, mini(4, venue_ids.size()))
	if stop_count_range.size() >= 2:
		stop_count = clampi(stop_count, int(stop_count_range[0]), int(stop_count_range[1]))
	var rotation := posmod(seed_value + numbers_state.day_at(_crew_action_index()), maxi(1, venue_ids.size()))
	var stops: Array = []
	var bag_value := 0
	var bag_range := _copy_array(tuning.get("bag_value_per_venue", [35, 70]))
	var bag_min := int(bag_range[0]) if not bag_range.is_empty() else 35
	var bag_max := int(bag_range[1]) if bag_range.size() > 1 else bag_min
	for index in range(stop_count):
		var venue_id := str(venue_ids[(rotation + index) % venue_ids.size()])
		stops.append({"id": "numbers_book_%s" % venue_id, "node_id": venue_id, "label": str(numbers_state.venue_definition(venue_id).get("label", venue_id.replace("_", " ").capitalize()))})
		bag_value += bag_min + posmod(seed_value + numbers_state.day_at(_crew_action_index()) * 31 + index * 17, maxi(1, bag_max - bag_min + 1))
	var pay := int(floor(float(bag_value) * float(int(tuning.get("pay_percent", 18))) / 100.0))
	var offered := job_offer({
		"id": "numbers_collection",
		"member_id": "crew_lucky",
		"kind": "numbers_collection",
		"payload": {"bag_value": bag_value, "stops": stops.duplicate(true)},
		"expiry_in_actions": remaining,
		"rewards": {"cash": 0, "trust": int(tuning.get("trust_on_time", 5))},
		"failure": {"trust": int(tuning.get("trust_late", -6)), "grievance_kind": "", "grievance_weight": 1},
	}, _crew_job_host_capability)
	var job_id := str(offered.get("id", ""))
	if job_id.is_empty() or job_accept(job_id, _crew_job_host_capability).is_empty() or job_activate(job_id, _crew_job_host_capability).is_empty():
		return {"ok": false, "message": "Lucky keeps the bag."}
	var delivery_targets := stops.duplicate(true)
	delivery_targets.append({"id": "numbers_return", "node_id": "small_underground_casino", "label": "The Punchline"})
	var started := delivery_begin_multi_stop({
		"run_id": "numbers_collection:%d" % numbers_state.day_at(_crew_action_index()),
		"job_id": job_id,
		"attempt": numbers_state.day_at(_crew_action_index()),
		"targets": delivery_targets,
		"target_count": delivery_targets.size(),
		"deadline_actions": remaining,
		"fast_threshold_actions": maxi(1, remaining - 4),
		"cargo_id": "numbers_slips",
		"cargo_label": "Numbers bag",
		"cargo_heat_per_travel": 3,
		"consumer_payload": {
			"success": {"cash": pay, "heat": 0, "flags": {"numbers_route_paid": true}},
			"failure": {"cash": 0, "heat": 7, "flags": {"numbers_route_failed": true}},
		},
	})
	if not bool(started.get("ok", false)):
		job_resolve(job_id, "failed", _crew_job_host_capability)
		return started
	numbers_state.begin_collection(stops, bag_value, job_id)
	started["job_id"] = job_id
	started["bag_value"] = bag_value
	started["pay"] = pay
	return started


# Starts the high-trust fix through a real-map package run.
func numbers_begin_fix_bribe() -> Dictionary:
	if numbers_state == null:
		return {"ok": false, "message": "The desk is dark."}
	numbers_state.fix_unlock(_numbers_fix_eligible())
	var begun := numbers_state.fix_begin_bribe()
	if not bool(begun.get("ok", false)):
		return begun
	var bribe := _copy_dict(_copy_dict(NumbersModelScript.tuning().get("fix", {})).get("bribe_run", {}))
	var started := delivery_begin_package({
		"run_id": "numbers_fix_bribe:%d" % int(_copy_dict(begun.get("fix", {})).get("target_day", 0)),
		"deadline_actions": int(bribe.get("deadline_actions", 22)),
		"cargo_heat_per_travel": int(bribe.get("spot_heat_per_new_spot", 6)),
		"cargo_id": "numbers_bribe_envelope",
		"cargo_label": "Bribe envelope",
		"consumer_payload": {"success": {"cash": 0, "heat": 0}, "failure": {"cash": 0, "heat": 12}},
	})
	if not bool(started.get("ok", false)):
		numbers_state.fix_record_bribe(false)
	return started


# Desk allocation surface: venue ids map to integer stakes.
func numbers_fix_allocate(allocations: Dictionary) -> Dictionary:
	if numbers_state == null:
		return {"ok": false, "message": "The desk is dark."}
	var quote := numbers_state.fix_allocation_quote(allocations)
	if not bool(quote.get("ok", false)):
		# Preserve the model's authored late-abort transition.
		return numbers_state.fix_allocate(allocations) if bool(quote.get("late", false)) else quote
	var total := maxi(0, int(quote.get("total", 0)))
	if bankroll < total:
		return {"ok": false, "message": "The desk needs $%d in real bankroll for that spread." % total}
	var result := numbers_state.fix_allocate(allocations)
	if not bool(result.get("ok", false)):
		return result
	change_bankroll(-total)
	_sync_numbers_inventory_marker()
	var operation_heat := maxi(0, int(result.get("operation_heat", 0)))
	if operation_heat > 0:
		add_suspicion("numbers_fix_concentration", operation_heat, "contraband", true, {}, true)
	return {
		"ok": true,
		"message": str(result.get("message", "The crew paper is placed.")),
		"total": total,
		"slip_count": int(result.get("slip_count", 0)),
		"operation_heat": operation_heat,
	}


func _numbers_fix_eligible() -> bool:
	var ranks := _copy_dict(_copy_dict(NumbersModelScript.tuning().get("fix", {})).get("member_ranks", {}))
	for member_value in ranks.keys():
		var required := str(ranks.get(member_value, "made"))
		if CrewStateModelScript.RANK_IDS.find(crew_rank(str(member_value))) < CrewStateModelScript.RANK_IDS.find(required):
			return false
	return not ranks.is_empty()


func _apply_numbers_events(events: Array) -> void:
	if numbers_state == null:
		return
	for event_value in events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		match str(event.get("type", "")):
			"numbers_post":
				if str(current_environment.get("archetype_id", "")) == "small_underground_casino":
					numbers_state.reveal_number(int(event.get("day", 0)), "punchline_post")
				register_rumor_fact("numbers_whisper", "numbers_post:%d" % int(event.get("day", 0)), {
					"target_node_id": "small_underground_casino",
					"source_id": "numbers_handle",
					"fact_detail": "the handle posted %s" % str(event.get("number", "000")),
					"number": str(event.get("number", "000")),
				})
			"numbers_day_rumors":
				var day := int(event.get("day", 0))
				var yesterday := str(event.get("yesterday_number", ""))
				if not yesterday.is_empty():
					register_rumor_fact("numbers_whisper", "numbers_yesterday:%d" % day, {
						"target_node_id": "bar", "source_id": "numbers_yesterday", "fact_detail": "yesterday's handle was %s" % yesterday, "number": yesterday,
					})
				register_rumor_fact("numbers_superstition", "numbers_hot_talk:%d" % day, {
					"target_node_id": "corner_store", "source_id": "numbers_hot_talk", "fact_detail": str(event.get("hot_number", "000")), "non_factual_prediction": true,
				})
			"numbers_settlement":
				var payout := maxi(0, int(event.get("payout", 0)))
				if payout > 0:
					change_bankroll(payout, true)
			"numbers_past_post_success":
				var past_payout := maxi(0, int(event.get("payout", 0)))
				if past_payout > 0:
					change_bankroll(past_payout, true)
			"numbers_past_post_detected":
				var slip := _copy_dict(event.get("slip", {}))
				var penalty := maxi(1, int(event.get("penalty", 1)))
				var debt_id := "numbers_past_post_%s" % str(slip.get("id", numbers_state.action_index))
				add_debt({
					"id": debt_id,
					"lender_id": "crew_knuckles",
					"debt_kind": "street_debt",
					"principal": penalty,
					"balance": penalty,
					"status": "active",
					"source_location_id": str(slip.get("venue_id", current_world_node_id())),
				})
				enqueue_triggered_event("numbers_knuckles_collection", "numbers", {"debt_id": debt_id, "penalty": penalty, "slip_id": str(slip.get("id", ""))}, {"presentation": "talk"})
				if _numbers_on_crew_path():
					grievance_add({"member_id": "crew_knuckles", "kind": "numbers_past_posting_in_colors", "weight": 2, "source_ref": str(slip.get("id", ""))})
			"numbers_fix_payday":
				var cut := maxi(0, int(event.get("player_cut", 0)))
				if cut > 0:
					change_bankroll(cut, true)
				crew_add_trust("crew_lucky", 4, "numbers_fix_payday")
				crew_add_trust("crew_mags", 4, "numbers_fix_payday")
			"numbers_leak_active":
				_apply_numbers_leak(_copy_dict(event.get("leak", {})))
	_sync_numbers_inventory_marker()


func _apply_numbers_leak(leak: Dictionary) -> void:
	var number := str(leak.get("number", "000"))
	for venue_value in NumbersModelScript.tuning().get("venues", []):
		if typeof(venue_value) != TYPE_DICTIONARY:
			continue
		var venue_id := str((venue_value as Dictionary).get("id", ""))
		register_rumor_fact("numbers_whisper", "numbers_leak:%d:%s" % [int(leak.get("active_day", 0)), venue_id], {
			"target_node_id": venue_id,
			"source_id": "numbers_fix_leak",
			"fact_detail": "everybody is piling onto %s" % number,
			"number": number,
			"pattern": number,
			"declared_pool_multiplier_percent": int(leak.get("declared_pool_multiplier_percent", 100)),
			"strictness_delta": int(leak.get("strictness_delta", 0)),
		})
	if bool(leak.get("sweep_reroute_requested", false)) and town_state != null:
		var target_ids: Array = []
		for venue_value in NumbersModelScript.tuning().get("venues", []):
			if typeof(venue_value) == TYPE_DICTIONARY:
				target_ids.append(str((venue_value as Dictionary).get("id", "")))
		town_state.request_sweep_reroute(target_ids, "numbers_leak:%d" % int(leak.get("successes", 0)))


func _numbers_on_crew_path() -> bool:
	for member_id in CrewStateModelScript.MEMBER_IDS:
		if crew_trust(member_id) > 0:
			return true
	return false


func _sync_numbers_inventory_marker() -> void:
	if numbers_state != null and numbers_state.open_slip_count() > 0:
		add_item("numbers_slips")
	else:
		remove_item("numbers_slips")


# Delivery jobs carry state across the real map. They never own movement.
func delivery_begin_package(spec: Dictionary) -> Dictionary:
	var normalized := spec.duplicate(true)
	normalized["mode"] = DeliveryRunModelScript.MODE_PACKAGE
	normalized["target_count"] = 1
	return _delivery_begin(normalized)


func delivery_begin_multi_stop(spec: Dictionary) -> Dictionary:
	var normalized := spec.duplicate(true)
	normalized["mode"] = DeliveryRunModelScript.MODE_MULTI_STOP
	return _delivery_begin(normalized)


func delivery_begin_hold(spec: Dictionary) -> Dictionary:
	var normalized := spec.duplicate(true)
	normalized["mode"] = DeliveryRunModelScript.MODE_HOLD
	normalized["target_count"] = 1
	return _delivery_begin(normalized)


func delivery_begin_getaway(spec: Dictionary) -> Dictionary:
	if not bool(spec.get("enabled", false)) and not bool(narrative_flags.get("delivery_getaway_enabled", false)):
		return {"ok": false, "message": "The getaway route is not live."}
	var normalized := spec.duplicate(true)
	normalized["mode"] = DeliveryRunModelScript.MODE_GETAWAY
	normalized["target_count"] = 1
	return _delivery_begin(normalized)


func _delivery_begin(spec: Dictionary) -> Dictionary:
	if delivery_has_active_run():
		return {"ok": false, "message": "Finish the route already under your coat."}
	if not has_world_map():
		return {"ok": false, "message": "There is no real town route for that job."}
	var resolved_targets := _delivery_resolve_targets(spec)
	if not bool(resolved_targets.get("ok", false)):
		return {"ok": false, "message": str(resolved_targets.get("message", "That route cannot be offered tonight."))}
	var normalized := spec.duplicate(true)
	normalized["targets"] = _copy_array(resolved_targets.get("targets", []))
	normalized["start_node_id"] = current_world_node_id()
	normalized["current_node_id"] = current_world_node_id()
	var state := DeliveryRunModelScript.begin(normalized, _crew_action_index())
	if state.is_empty():
		return {"ok": false, "message": "That route cannot be carried on this town map."}
	world_map = _copy_dict(resolved_targets.get("world_map", world_map))
	active_delivery_run = state
	return {"ok": true, "snapshot": delivery_snapshot(), "message": "The route is marked. The room at the far end is real."}


func delivery_has_active_run() -> bool:
	return not active_delivery_run.is_empty() and str(active_delivery_run.get("status", "")) == "active"


func delivery_snapshot() -> Dictionary:
	return DeliveryRunModelScript.snapshot(active_delivery_run)


func delivery_physical_interactions() -> Array:
	if not delivery_has_active_run():
		return []
	var physical := _copy_dict(delivery_snapshot().get("physical", {}))
	var node_id := current_world_node_id()
	if node_id.is_empty() or node_id != str(physical.get("position_node_id", "")):
		return []
	var result: Array = []
	for verb_value in _copy_array(physical.get("available_verbs", [])):
		var verb := str(verb_value)
		if verb == "move" or verb == "handoff":
			continue
		var label := str({
			"pickup": "Take the package", "wait": "Hold your sightline", "duck": "Duck into cover",
			"stash": "Stash the package", "retrieve": "Retrieve the package", "ditch": "Ditch the package",
			"signal": "Send the signal", "break_hold": "Break the hold",
		}.get(verb, verb.replace("_", " ").capitalize()))
		result.append({
			"object_id": "delivery:%s:%s" % [verb, node_id],
			"node_id": node_id,
			"verb": verb,
			"label": label,
			"cargo_label": str(active_delivery_run.get("cargo_label", "Crew package")),
			"message": "This acts on the route here, at %s." % node_id.replace("_", " ").capitalize(),
		})
	return result


func delivery_apply_physical_action(verb: String, idempotency_key: String) -> Dictionary:
	if not delivery_has_active_run():
		return {"ok": false, "message": "No delivery sequence is active."}
	var action := verb.strip_edges()
	var receipt_key := idempotency_key.strip_edges()
	if action not in DeliveryRunModelScript.STREET_VERBS or action in ["move", "handoff"] or receipt_key.is_empty() or receipt_key != idempotency_key:
		return {"ok": false, "message": "That street action is not available."}
	var snapshot := delivery_snapshot()
	var physical := _copy_dict(snapshot.get("physical", {}))
	if not _copy_array(physical.get("available_verbs", [])).has(action):
		return {"ok": false, "message": "That street action is not available now."}
	var node_id := current_world_node_id()
	if node_id.is_empty() or node_id != str(physical.get("position_node_id", "")):
		return {"ok": false, "message": "That street action is not at your present position."}
	var target_id := ""
	var place_id := ""
	var cover_id := ""
	var signal_id := ""
	match action:
		"pickup": target_id = str(physical.get("cargo_place_id", ""))
		"stash": place_id = "%s::delivery_stash" % node_id
		"retrieve": place_id = str(physical.get("cargo_place_id", ""))
		"ditch": place_id = str(physical.get("cargo_place_id", "")) if str(physical.get("cargo_state", "")) == DeliveryRunModelScript.CARGO_STASHED else "%s::delivery_ditch" % node_id
		"duck": cover_id = "%s::delivery_cover" % node_id
		"signal": signal_id = "%s::delivery_signal" % node_id
	var host_context := _delivery_host_context(node_id, "", target_id, place_id, cover_id, signal_id, action)
	var before := JSON.stringify(active_delivery_run)
	var rollback_run := to_dict()
	var candidate := DeliveryRunModelScript.apply_host_action(active_delivery_run, action, receipt_key, host_context)
	if JSON.stringify(candidate) == before:
		return {"ok": false, "message": "The route no longer accepts that action."}
	active_delivery_run = candidate
	var applied := _apply_delivery_resolution()
	if not bool(applied.get("ok", false)):
		from_dict(rollback_run)
		return {"ok": false, "message": "The street consequence could not be committed.", "errors": _copy_array(applied.get("errors", []))}
	return {"ok": true, "resolved": not delivery_has_active_run(), "snapshot": delivery_snapshot(), "message": str(_delivery_physical_action_message(action))}


func _delivery_host_context(node_id: String, destination_node_id: String, target_id: String, place_id: String, cover_id: String, signal_id: String, reason: String) -> Dictionary:
	return {
		"schema_version": 1,
		"node_id": node_id.strip_edges(),
		"destination_node_id": destination_node_id.strip_edges(),
		"target_id": target_id.strip_edges(),
		"place_id": place_id.strip_edges(),
		"cover_id": cover_id.strip_edges(),
		"signal_id": signal_id.strip_edges(),
		"reason": reason.strip_edges(),
		"attention": clampi(suspicion_level(), 0, 100),
		"action_index": maxi(0, _crew_action_index()),
	}


func _delivery_physical_action_message(verb: String) -> String:
	return str({
		"pickup": "The package has weight now.", "wait": "You hold the sightline.", "duck": "The street loses you for a beat.",
		"stash": "The package stays here until you return.", "retrieve": "The package is back under your coat.",
		"ditch": "The package is gone.", "signal": "The signal crosses the street.", "break_hold": "You leave the sightline early.",
	}.get(verb, "The route changes here."))


func delivery_arrival_interaction() -> Dictionary:
	if not delivery_has_active_run():
		return {}
	if not bool(delivery_snapshot().get("carrying_contraband", false)):
		return {}
	var node_id := current_world_node_id()
	if node_id.is_empty() or node_id != str(active_delivery_run.get("handoff_pending_node_id", "")):
		return {}
	return {
		"object_id": "delivery:handoff:%s" % node_id,
		"node_id": node_id,
		"label": "Make the handoff",
		"cargo_label": str(active_delivery_run.get("cargo_label", "Crew package")),
		"message": "A quiet hand waits inside the room. Pass it over.",
	}


func delivery_complete_handoff(node_id: String = "") -> Dictionary:
	if not delivery_has_active_run():
		return {"ok": false, "message": "There is no package to hand over."}
	var target_id := node_id.strip_edges()
	var host_node_id := current_world_node_id()
	if target_id.is_empty(): target_id = host_node_id
	if host_node_id.is_empty() or target_id != host_node_id:
		return {"ok": false, "message": "This is not the marked handoff."}
	var target := _delivery_pending_target_at(target_id)
	if target.is_empty():
		return {"ok": false, "message": "This is not the marked handoff."}
	var before := JSON.stringify(delivery_snapshot())
	var rollback_run := to_dict()
	var receipt_key := "handoff:%s:%s:%d" % [str(active_delivery_run.get("run_id", "delivery")), str(target.get("id", "target")), maxi(0, _crew_action_index())]
	active_delivery_run = DeliveryRunModelScript.apply_host_action(active_delivery_run, "handoff", receipt_key, _delivery_host_context(target_id, "", str(target.get("id", "")), "", "", "", "handoff"))
	if JSON.stringify(delivery_snapshot()) == before:
		return {"ok": false, "message": "This is not the marked handoff."}
	var applied := _apply_delivery_resolution()
	if not bool(applied.get("ok", false)):
		from_dict(rollback_run)
		var apply_errors := _copy_array(applied.get("errors", []))
		return {"ok": false, "message": str(apply_errors[0]) if not apply_errors.is_empty() else "The delivery consequence could not be committed.", "errors": apply_errors}
	var receipt := _copy_dict(active_delivery_run.get("receipt", {}))
	var handoff_message := str(receipt.get("payment_note", "The package changes hands. Nothing else does."))
	return {"ok": true, "resolved": not delivery_has_active_run(), "snapshot": delivery_snapshot(), "message": handoff_message}


func _delivery_pending_target_at(node_id: String) -> Dictionary:
	for target_value in _copy_array(delivery_snapshot().get("targets", [])):
		var target := _copy_dict(target_value)
		if str(target.get("status", "pending")) == "pending":
			return target if str(target.get("node_id", "")) == node_id else {}
	return {}


func delivery_use_getaway_assist(assist_id: String) -> Dictionary:
	if not delivery_has_active_run():
		return {"ok": false, "message": "No getaway is active."}
	var before := JSON.stringify(delivery_snapshot())
	active_delivery_run = DeliveryRunModelScript.use_assist(active_delivery_run, assist_id)
	if JSON.stringify(delivery_snapshot()) == before:
		return {"ok": false, "message": "That assist is not available."}
	return {"ok": true, "snapshot": delivery_snapshot(), "message": "One favor burns. The pressure drops."}


func delivery_abandon(_reason: String = "abandoned") -> Dictionary:
	if not delivery_has_active_run():
		return {"ok": false, "message": "No delivery is active."}
	var rollback_run := to_dict()
	var receipt_key := "abandon:%s:%d" % [str(active_delivery_run.get("run_id", "delivery")), maxi(0, _crew_action_index())]
	var before := JSON.stringify(active_delivery_run)
	active_delivery_run = DeliveryRunModelScript.apply_host_action(
		active_delivery_run,
		"abandon",
		receipt_key,
		_delivery_host_context(current_world_node_id(), "", "", "", "", "", "abandoned")
	)
	if JSON.stringify(active_delivery_run) == before:
		return {"ok": false, "message": "The route could not be closed safely."}
	var applied := _apply_delivery_resolution()
	if not bool(applied.get("ok", false)):
		from_dict(rollback_run)
		return {"ok": false, "message": "The route could not be closed safely.", "errors": _copy_array(applied.get("errors", []))}
	return {"ok": true, "resolved": true, "snapshot": delivery_snapshot(), "message": "The route closes without you."}


# Called by the canonical travel pipeline after the destination room exists.
func delivery_resolve_travel_arrival(route: Dictionary = {}, route_risk: Dictionary = {}) -> Dictionary:
	if not delivery_has_active_run():
		return {}
	var rollback_run := to_dict()
	var rollback_environment := current_environment.duplicate(true)
	var rollback_world_map := world_map.duplicate(true)
	var rollback_room_states := grand_casino_room_states.duplicate(true)
	var node_id := current_world_node_id()
	var physical_before := _copy_dict(delivery_snapshot().get("physical", {}))
	var source_node_id := str(physical_before.get("position_node_id", ""))
	var route_query := WorldMap.prepare_path_query(world_map, source_node_id, true)
	var authoritative_path := WorldMap.prepared_path(route_query, node_id)
	if source_node_id.is_empty() or source_node_id == node_id or authoritative_path.is_empty() or not WorldMap.prepared_path_uses_real_edges(route_query, authoritative_path):
		return {"ok": false, "resolved": false, "snapshot": delivery_snapshot(), "errors": ["delivery travel did not cross an authoritative real-map route"]}
	var security_heat := _delivery_arrival_security_heat()
	if security_heat > 0:
		add_suspicion("delivery_arrival", security_heat, "contraband", true, {
			"node_id": node_id,
			"cargo_id": str(active_delivery_run.get("cargo_id", "")),
			"route_risk_triggered": bool(route_risk.get("triggered", false)),
		}, true)
		active_delivery_run = DeliveryRunModelScript.add_heat(active_delivery_run, security_heat)
	# Travel is one delivery action boundary. Ordinary travel never enters here.
	var advance_result := advance_environment_turns(1)
	if not bool(advance_result.get("ok", false)):
		from_dict(rollback_run)
		current_environment = rollback_environment
		world_map = rollback_world_map
		grand_casino_room_states = rollback_room_states
		return {"ok": false, "resolved": false, "snapshot": delivery_snapshot(), "errors": _copy_array(advance_result.get("errors", []))}
	if not delivery_has_active_run():
		return {"ok": false, "resolved": true, "snapshot": delivery_snapshot()}
	var move_receipt := "travel:%s:%s:%d" % [source_node_id, node_id, maxi(0, _crew_action_index())]
	var move_context := _delivery_host_context(source_node_id, node_id, "", "", "", "", str(route.get("id", route.get("target_node_id", node_id))))
	var before_move := JSON.stringify(active_delivery_run)
	active_delivery_run = DeliveryRunModelScript.apply_host_action(active_delivery_run, "move", move_receipt, move_context)
	if JSON.stringify(active_delivery_run) == before_move:
		from_dict(rollback_run)
		current_environment = rollback_environment
		world_map = rollback_world_map
		grand_casino_room_states = rollback_room_states
		return {"ok": false, "resolved": false, "snapshot": delivery_snapshot(), "errors": ["delivery model rejected the authoritative travel arrival"]}
	_apply_delivery_resolution()
	return {
		"ok": true,
		"resolved": not delivery_has_active_run(),
		"handoff_ready": str(active_delivery_run.get("handoff_pending_node_id", "")) == node_id,
		"route_id": str(route.get("id", route.get("target_node_id", node_id))),
		"snapshot": delivery_snapshot(),
	}


func delivery_map_layer() -> Dictionary:
	if not delivery_has_active_run():
		return {}
	var delivery_view := delivery_snapshot()
	var physical := _copy_dict(delivery_view.get("physical", {}))
	var public_sweep := sweep_status()
	var edge_reads: Array = []
	for edge_value in _copy_array(world_map.get("edges", [])):
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		var a := str(edge.get("a", "")).strip_edges()
		var b := str(edge.get("b", "")).strip_edges()
		if not WorldMap.is_node_visible(world_map, a) or not WorldMap.is_node_visible(world_map, b):
			continue
		var score := 0
		var reasons: Array = []
		var weather := weather_now()
		if weather in ["rain", "storm", "fog"]:
			score += 1
			reasons.append("weather cover" if weather == "fog" else "bad weather")
		var attention := 0.0
		if town_state != null:
			attention = maxf(float(town_state.local_reputation(a).get("attention", 0.0)), float(town_state.local_reputation(b).get("attention", 0.0)))
		if attention >= 0.5:
			score += 1
			reasons.append("local attention")
		var law_pressure := _delivery_scenario_law_pressure([a, b])
		if law_pressure > 0:
			score += law_pressure
			reasons.append("venue pressure")
		if not public_sweep.is_empty() and bool(public_sweep.get("active", false)):
			var sweep_nodes := [str(public_sweep.get("current_node_id", "")), str(public_sweep.get("heading_node_id", ""))]
			if a in sweep_nodes or b in sweep_nodes:
				score += 2
				reasons.append("reported sweep")
		elif public_sweep.is_empty():
			reasons.append("sweep unknown")
		var band := "low" if score <= 1 else "guarded" if score <= 3 else "hot"
		edge_reads.append({
			"edge_id": str(edge.get("id", "%s--%s" % [a, b])),
			"a": a,
			"b": b,
			"band": band,
			"reasons": reasons,
		})
	return {
		"active": true,
		"mode": str(active_delivery_run.get("mode", "package")),
		"targets": _copy_array(delivery_view.get("targets", [])),
		"deadline_remaining": int(active_delivery_run.get("deadline_remaining", 0)),
		"cargo": {
			"id": str(active_delivery_run.get("cargo_id", "")),
			"label": str(active_delivery_run.get("cargo_label", "Crew package")),
			"contraband": bool(delivery_view.get("carrying_contraband", false)),
			"status": str(physical.get("cargo_state", "none")),
			"node_id": str(physical.get("cargo_node_id", "")),
			"place_id": str(physical.get("cargo_place_id", "")),
		},
		"edge_reads": edge_reads,
	}


func _delivery_resolve_targets(spec: Dictionary) -> Dictionary:
	var requested: Array = []
	for source_value in [spec.get("targets", []), spec.get("stops", []), spec.get("target_node_ids", [])]:
		if typeof(source_value) != TYPE_ARRAY or (source_value as Array).is_empty():
			continue
		for entry_value in source_value as Array:
			var node_id := str((entry_value as Dictionary).get("node_id", (entry_value as Dictionary).get("id", ""))).strip_edges() if typeof(entry_value) == TYPE_DICTIONARY else str(entry_value).strip_edges()
			if not node_id.is_empty() and not requested.has(node_id):
				requested.append(node_id)
		break
	var count := maxi(1, int(spec.get("target_count", requested.size() if not requested.is_empty() else 1)))
	var origin_id := current_world_node_id()
	var offer_path_query := WorldMap.prepare_path_query(world_map, origin_id, false)
	var buckets := [[], [], []]
	var nodes_value: Variant = world_map.get("nodes", [])
	if typeof(nodes_value) == TYPE_ARRAY:
		for node_value in nodes_value as Array:
			if typeof(node_value) != TYPE_DICTIONARY:
				continue
			var node: Dictionary = node_value
			var node_id := str(node.get("id", "")).strip_edges()
			if node_id.is_empty() or (node_id == origin_id and str(spec.get("mode", "")) != DeliveryRunModelScript.MODE_HOLD):
				continue
			if str(node.get("archetype_id", "")).strip_edges().is_empty() or str(node.get("kind", "")).strip_edges().is_empty():
				continue
			if not WorldMap.prepared_has_path(offer_path_query, node_id) and node_id != origin_id:
				continue
			# Familiar places are the default: first rooms the player has entered,
			# then the rest of the discovered map. Hidden real nodes remain the last
			# bucket so courier work can still pull the player into unseen town.
			var bucket_index := 0 if str(node.get("state", "hidden")) == WorldMap.STATE_VISITED else 1 if WorldMap.prepared_is_node_visible(offer_path_query, node_id) else 2
			(buckets[bucket_index] as Array).append(node_id)
	var candidates: Array = []
	var target_rng := create_rng("delivery_targets:%s:%d" % [str(spec.get("run_id", spec.get("route_id", "delivery"))), _crew_action_index()])
	for bucket_value in buckets:
		var bucket: Array = bucket_value
		bucket.sort()
		for chosen_value in target_rng.pick_many(bucket, bucket.size()):
			candidates.append(str(chosen_value))
	var chosen_ids := requested if not requested.is_empty() else candidates.slice(0, mini(count, candidates.size()))
	if chosen_ids.size() != count:
		return {"ok": false, "message": "The job has no complete real route tonight."}
	var allows_origin_return := str(spec.get("mode", "")) == DeliveryRunModelScript.MODE_MULTI_STOP \
		and chosen_ids.size() > 1 and str(chosen_ids[chosen_ids.size() - 1]) == origin_id
	var reveal_ids: Array = []
	var targets: Array = []
	for node_id_value in chosen_ids:
		var node_id := str(node_id_value)
		if not candidates.has(node_id) and not (allows_origin_return and node_id == origin_id):
			return {"ok": false, "message": "%s is not a reachable venue tonight." % node_id.replace("_", " ").capitalize()}
		var path := WorldMap.prepared_path(offer_path_query, node_id) if node_id != origin_id else [origin_id]
		if path.is_empty() or not WorldMap.prepared_path_uses_real_edges(offer_path_query, path):
			return {"ok": false, "message": "The route to %s is not a real map path." % node_id.replace("_", " ").capitalize()}
		for path_id_value in path:
			var path_id := str(path_id_value)
			if not WorldMap.prepared_is_node_visible(offer_path_query, path_id) and not reveal_ids.has(path_id):
				reveal_ids.append(path_id)
		var node := WorldMap.node_metadata_by_id(world_map, node_id)
		var was_visible := WorldMap.prepared_is_node_visible(offer_path_query, node_id)
		targets.append({
			"id": "delivery_target_%s" % node_id,
			"node_id": node_id,
			"label": str(node.get("label", node_id.replace("_", " ").capitalize())),
			"was_visited_at_offer": str(node.get("state", "hidden")) == WorldMap.STATE_VISITED,
			"was_visible_at_offer": was_visible,
			"revealed_by_job": not was_visible,
		})
	var offered_map := WorldMap.unlock_nodes(world_map, reveal_ids, WorldMap.DISCOVERY_SOURCE_EVENT)
	var offered_path_query := WorldMap.prepare_path_query(offered_map, origin_id, true)
	for target_value in targets:
		var node_id := str((target_value as Dictionary).get("node_id", ""))
		var visible_path := WorldMap.prepared_path(offered_path_query, node_id) if node_id != origin_id else [origin_id]
		if visible_path.is_empty() or not WorldMap.prepared_path_uses_real_edges(offered_path_query, visible_path):
			return {"ok": false, "message": "The revealed courier route is incomplete."}
	return {"ok": true, "targets": targets, "world_map": offered_map}


func _delivery_path_uses_real_edges(path: Array, map_value: Dictionary = {}) -> bool:
	var source_map := world_map if map_value.is_empty() else map_value
	if path.size() == 1:
		return true
	for index in range(path.size() - 1):
		if WorldMap.edge_between(source_map, str(path[index]), str(path[index + 1])).is_empty():
			return false
	return path.size() >= 2


func _delivery_scenario_law_pressure(node_ids: Array) -> int:
	var total := 0
	var seen := {}
	for node_id_value in node_ids:
		var node_id := str(node_id_value).strip_edges()
		if node_id.is_empty() or seen.has(node_id):
			continue
		seen[node_id] = true
		var definition := _seeded_scenario_definition_for_node_readonly(node_id)
		var mutations: Dictionary = definition.get("mutations", {}) if typeof(definition.get("mutations", {})) == TYPE_DICTIONARY else {}
		var security: Dictionary = mutations.get("security_overrides", {}) if typeof(mutations.get("security_overrides", {})) == TYPE_DICTIONARY else {}
		match str(security.get("strictness_band", "")).to_lower():
			"high", "strict", "maximum":
				total += 2
			"medium", "uneven":
				total += 1
	return clampi(total, 0, 4)


func _delivery_arrival_security_heat() -> int:
	if not delivery_has_active_run() or not bool(delivery_snapshot().get("carrying_contraband", false)):
		return 0
	var heat := maxi(0, int(active_delivery_run.get("cargo_heat_per_travel", 2)))
	var security := _copy_dict(current_environment.get("security_profile", {}))
	match str(security.get("strictness_band", security.get("strictness", "low"))).to_lower():
		"medium":
			heat += 1
		"high", "strict", "maximum":
			heat += 2
	heat += _delivery_scenario_law_pressure([current_world_node_id()])
	return heat


func _apply_delivery_resolution(expected_receipt: Dictionary = {}, materialize_adapter: bool = true) -> Dictionary:
	if active_delivery_run.is_empty() or str(active_delivery_run.get("status", "")) != "resolved":
		return {"ok": true, "inactive": true, "errors": []}
	if bool(active_delivery_run.get("world_applied", false)):
		var checkpoint := DeliveryRunModelScript.closed_checkpoint(active_delivery_run)
		var applied_instance := str(active_delivery_run.get("job_id", "")).strip_edges()
		if applied_instance.is_empty(): applied_instance = str(active_delivery_run.get("run_id", "")).strip_edges()
		var applied_owner := world_sequence_owner_for_public_instance("delivery_handoff", applied_instance)
		var applied_entry := _copy_dict(_copy_dict(current_environment.get(CrewWorldSequenceAdapterScript.CONTAINER_KEY, {})).get(applied_owner, {}))
		if checkpoint.is_empty() and not applied_owner.is_empty() and not applied_entry.is_empty():
			return {"ok": false, "errors": ["mounted applied delivery is missing its closed checkpoint"]}
		if not checkpoint.is_empty():
			var checkpoint_token := str(checkpoint.get("owner_token", ""))
			var materialized := world_sequence_materialize_delivery_checkpoint(checkpoint_token)
			if not bool(materialized.get("ok", false)): return materialized
		var retried := _retry_delivery_world_sequence_lifecycle()
		if not bool(retried.get("ok", false)): return retried
		return {"ok": true, "replayed": true, "public_result": _copy_dict(checkpoint.get("public_result", {})), "errors": []}
	var resolution := _copy_dict(active_delivery_run.get("resolution", {}))
	var succeeded := str(resolution.get("outcome", "")) == "success"
	var reason := str(resolution.get("reason", "failed"))
	var job_id := str(active_delivery_run.get("job_id", ""))
	var run_id := str(active_delivery_run.get("run_id", ""))
	var public_instance_token := job_id if not job_id.is_empty() else run_id
	var owner_token := world_sequence_owner_for_public_instance("delivery_handoff", public_instance_token)
	var live_entry := _copy_dict(_copy_dict(current_environment.get(CrewWorldSequenceAdapterScript.CONTAINER_KEY, {})).get(owner_token, {}))
	var mounted := not owner_token.is_empty() and not live_entry.is_empty()
	var outcome_id := "delivered" if succeeded else ("abandoned" if reason == "abandoned" else "expired")
	var owner_cause := _world_sequence_delivery_owner_cause(owner_token, outcome_id) if mounted else {}
	var receipt := expected_receipt.duplicate(true)
	if mounted:
		var preview := CrewWorldSequenceAdapterScript.preview_outcome(current_environment, owner_token, _world_sequence_definition(owner_token), outcome_id, owner_cause)
		if not bool(preview.get("ok", false)): return preview
		var trusted_receipt := _copy_dict(preview.get("receipt", {}))
		if not receipt.is_empty() and receipt != trusted_receipt:
			return {"ok": false, "errors": ["delivery consequence preview changed before commit"]}
		receipt = trusted_receipt
	var rollback_run := to_dict()
	var rollback_environment := current_environment.duplicate(true)
	var rollback_world_map := world_map.duplicate(true)
	var rollback_room_states := grand_casino_room_states.duplicate(true)
	var payload := _copy_dict(active_delivery_run.get("consumer_payload", {}))
	var effects := _copy_dict(payload.get("success" if succeeded else "failure", {}))
	var cash := maxi(0, int(effects.get("cash", 0)))
	if succeeded and bool(resolution.get("clean", false)) and bool(resolution.get("fast", false)):
		cash += maxi(0, int(effects.get("clean_speed_bonus_cash", 0)))
	if cash > 0:
		change_bankroll(cash, true)
	var heat := maxi(0, int(effects.get("heat", 0)))
	if reason == "abandoned":
		heat = 0
	if heat > 0:
		add_suspicion("delivery:%s" % reason, heat, "contraband", true, {"run_id": str(active_delivery_run.get("run_id", ""))}, true)
	for flag_value in _copy_dict(effects.get("flags", {})).keys():
		narrative_flags[str(flag_value)] = _copy_dict(effects.get("flags", {})).get(flag_value)
	if not job_id.is_empty():
		var job_result := job_resolve(job_id, "success" if succeeded else "failed", _crew_job_host_capability)
		var payment_note := str(job_result.get("payment_note", "")).strip_edges()
		if not payment_note.is_empty():
			active_delivery_run["receipt"] = {
				"posted_cash": int(job_result.get("posted_cash", 0)),
				"paid_cash": int(job_result.get("paid_cash", 0)),
				"payment_note": payment_note,
			}
	if run_id.begins_with("heist:"):
		_crew_heist_apply_delivery_resolution(run_id, succeeded, resolution)
	if run_id.begins_with("crew_collection:"):
		var collection_job_id := run_id.trim_prefix("crew_collection:")
		var collection_job := _crew_job(collection_job_id)
		if not collection_job.is_empty() and str(collection_job.get("status", "")) == "active":
			if succeeded:
				var collection_payload := _copy_dict(collection_job.get("payload", {}))
				collection_payload["press_choice_pending"] = true
				collection_job["payload"] = collection_payload
				crew_jobs[collection_job_id] = collection_job
				_crew_add_room_event("crew_collection_press")
			else:
				job_resolve(collection_job_id, "failed", _crew_job_host_capability)
	if numbers_state != null:
		if run_id.begins_with("numbers_collection:"):
			numbers_state.resolve_collection(succeeded, reason, resolution)
			if not succeeded and reason == "abandoned":
				grievance_add({"member_id": "crew_lucky", "kind": "job_abandoned", "weight": 1, "source_ref": str(active_delivery_run.get("job_id", run_id))})
		elif run_id.begins_with("numbers_fix_bribe:"):
			numbers_state.fix_record_bribe(succeeded, resolution)
	# Reporting-only counters share this existing, idempotent resolution boundary.
	# Lookout holds and heist getaways are not package-delivery ledger entries.
	var reporting_mode := str(active_delivery_run.get("mode", ""))
	if reporting_mode in [DeliveryRunModelScript.MODE_PACKAGE, DeliveryRunModelScript.MODE_MULTI_STOP]:
		var reporting_key := "profile_delivery_runs_completed" if succeeded else "profile_delivery_packages_lost"
		narrative_flags[reporting_key] = maxi(0, int(narrative_flags.get(reporting_key, 0))) + 1
	var delivery_receipt := _copy_dict(active_delivery_run.get("receipt", {}))
	var public_result := {"ok": true, "resolved": true, "message": str(delivery_receipt.get("payment_note", "The package changes hands. Nothing else does.")) if succeeded else ""}
	if not succeeded: public_result["outcome"] = outcome_id
	if mounted:
		var checkpointed := DeliveryRunModelScript.commit_closed_checkpoint(active_delivery_run, _world_sequence_delivery_binding(receipt), public_result)
		if not bool(checkpointed.get("ok", false)):
			from_dict(rollback_run)
			current_environment = rollback_environment
			world_map = rollback_world_map
			grand_casino_room_states = rollback_room_states
			return checkpointed
		active_delivery_run = _copy_dict(checkpointed.get("state", {}))
		if materialize_adapter:
			var confirmed := CrewWorldSequenceAdapterScript.confirm_outcome(current_environment, owner_token, _world_sequence_definition(owner_token), receipt, owner_cause)
			if not bool(confirmed.get("ok", false)):
				# The owner checkpoint is already the durable authority. Adapter
				# materialization is a separate retryable step and may never roll back or
				# reissue the committed economy/model consequence.
				return confirmed
			_refresh_world_sequence_registration(owner_token, false)
	else:
		# Separate legacy/unmounted delivery path: it retains its established
		# exactly-once world bit and never manufactures an adapter checkpoint.
		active_delivery_run["world_applied"] = true
	var lifecycle_reason := "expired" if reason == "deadline" else ("abandoned" if reason == "abandoned" else "")
	if not lifecycle_reason.is_empty() and mounted:
		active_delivery_run["world_sequence_lifecycle_retry"] = {"owner_token": owner_token, "outcome": lifecycle_reason}
		var lifecycle := _retry_delivery_world_sequence_lifecycle()
		if not bool(lifecycle.get("ok", false)): return lifecycle
	return {"ok": true, "public_result": public_result, "errors": []}


func _retry_delivery_world_sequence_lifecycle() -> Dictionary:
	var retry := _copy_dict(active_delivery_run.get("world_sequence_lifecycle_retry", {}))
	if retry.is_empty(): return {"ok": true, "inactive": true, "errors": []}
	var owner_token := str(retry.get("owner_token", ""))
	var outcome_id := str(retry.get("outcome", ""))
	if owner_token.is_empty() or outcome_id not in ["expired", "abandoned"]:
		return {"ok": false, "errors": ["delivery world-sequence lifecycle retry authority is invalid"]}
	var matching_receipt: Dictionary = {}
	for outcome_value in world_sequence_pending_outcomes(owner_token):
		var outcome := _copy_dict(outcome_value)
		if str(outcome.get("channel_id", "")) == "delivery_handoff" and str(outcome.get("outcome", "")) == outcome_id:
			matching_receipt = outcome
			break
	if matching_receipt.is_empty():
		var sync_result := world_sequence_sync_owner(owner_token, false, outcome_id)
		if not bool(sync_result.get("ok", false)): return sync_result
		for outcome_value in world_sequence_pending_outcomes(owner_token):
			var outcome := _copy_dict(outcome_value)
			if str(outcome.get("channel_id", "")) == "delivery_handoff" and str(outcome.get("outcome", "")) == outcome_id:
				matching_receipt = outcome
				break
	if matching_receipt.is_empty():
		return {"ok": false, "errors": ["delivery world-sequence lifecycle outcome receipt was not emitted"]}
	var consumed := world_sequence_consume_delivery_outcome(owner_token, str(matching_receipt.get("receipt_id", "")), current_world_node_id())
	if bool(consumed.get("ok", false)):
		active_delivery_run.erase("world_sequence_lifecycle_retry")
	return consumed


func _migrate_legacy_streets_run(legacy_state: Dictionary) -> void:
	var legacy_status := str(legacy_state.get("status", "")).strip_edges()
	if legacy_status.is_empty():
		return
	var job_id := str(legacy_state.get("job_id", "")).strip_edges()
	if not job_id.is_empty():
		var job := _crew_job(job_id)
		if not job.is_empty() and str(job.get("status", "")) != "resolved":
			job["status"] = "resolved"
			job["outcome"] = "migration_closed"
			job["resolved_action"] = _crew_action_index()
			crew_jobs[job_id] = job
	var route_id := str(legacy_state.get("route_id", ""))
	if numbers_state != null and route_id.begins_with("numbers_collection:") and str(numbers_state.collection_state.get("status", "")) == "active":
		numbers_state.resolve_collection(false, "migration_closed", {})
	elif numbers_state != null and route_id.begins_with("numbers_fix_bribe:"):
		numbers_state.fix_record_bribe(false, {"reason": "migration_closed"})
	narrative_flags["delivery_legacy_board_migrated"] = true
	log_story({
		"type": "delivery_migration",
		"message": "An old street-board route was closed cleanly during save migration.",
		"legacy_route_id": route_id,
		"job_id": job_id,
	})
	print("RUN_SAVE_MIGRATION active_streets_run closed; synthetic geography is no longer supported.")


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
	var cost := _travel_route_cost(route_data)
	var status := {
		"available": true,
		"disabled_reason": "",
		"cost": cost,
		"risk": _town_adjusted_travel_risk_band(str(route_data.get("risk", ""))),
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


func _travel_route_cost(route_data: Dictionary) -> int:
	var tutorial_override := _tutorial_travel_route_cost_override(route_data)
	if tutorial_override >= 0:
		return tutorial_override
	var base_cost := maxi(0, int(route_data.get("cost", 0)))
	if _travel_route_is_walk(route_data):
		return 0
	var current_archetype_id := str(current_environment.get("archetype_id", current_environment.get("id", ""))).strip_edges()
	if current_archetype_id.is_empty():
		return base_cost
	var free_from_archetypes := _string_array(_copy_array(route_data.get("free_from_archetypes", [])))
	if free_from_archetypes.has(current_archetype_id):
		return 0
	var multiplier := 1.0
	if town_state != null:
		multiplier = maxf(0.0, float(town_state.travel_modifier_profile().get("cost_multiplier", 1.0)))
	var adjusted := maxi(0, int(round(float(base_cost) * multiplier)))
	if bool(narrative_flags.get("crew_rook_ride_active", false)):
		var discount := clampi(int(narrative_flags.get("crew_rook_ride_discount_percent", 0)), 0, 100)
		adjusted = maxi(0, int(ceil(float(adjusted) * float(100 - discount) / 100.0)))
	return adjusted


func _tutorial_travel_route_cost_override(route_data: Dictionary) -> int:
	if not is_tutorial_run():
		return -1
	var modifiers := challenge_modifiers()
	var overrides_value: Variant = modifiers.get("tutorial_travel_cost_overrides", {})
	if typeof(overrides_value) != TYPE_DICTIONARY:
		return -1
	var overrides: Dictionary = overrides_value
	var target_id := str(route_data.get(
		"destination_archetype",
		route_data.get("target_node_id", route_data.get("id", ""))
	)).strip_edges()
	if target_id.is_empty() or not overrides.has(target_id):
		return -1
	return maxi(0, int(overrides.get(target_id, 0)))


func _travel_route_is_walk(route_data: Dictionary) -> bool:
	var explicit_kind := str(route_data.get("travel_method_kind", "")).strip_edges().to_lower()
	if not explicit_kind.is_empty():
		return explicit_kind == "walk"
	var method := str(route_data.get("travel_method", route_data.get("method", ""))).strip_edges().to_lower()
	if not method.is_empty():
		return method == "walk" or method.contains("walk")
	return str(route_data.get("distance", "")).strip_edges().to_lower() == "near"


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
	var heard := heard_rumor_for_node(archetype_id)
	if not full_preview and not heard.is_empty():
		preview["level"] = "heard"
		preview["heard_rumor"] = heard.duplicate(true)
		lines.append("Heard: %s" % str(heard.get("line", "")))
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
	var chance_multiplier := 1.0
	if town_state != null:
		chance_multiplier = maxf(0.0, float(town_state.travel_modifier_profile().get("risk_multiplier", 1.0)))
	var chance := clampi(int(round(float(risk_event.get("chance_percent", 0)) * chance_multiplier)), 0, 100)
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


func sweep_wait_action_status() -> Dictionary:
	var remaining := current_travel_lock_remaining()
	var visible := remaining > 0 and str(current_environment.get("travel_lock_source", "")) == "police_sweep" and not is_terminal()
	return {
		"id": "wait_out_police_sweep",
		"label": "Wait out the sweep",
		"visible": visible,
		"enabled": visible,
		"remaining_actions": remaining if visible else 0,
		"action_cost": 1 if visible else 0,
	}


func perform_sweep_wait_action() -> Dictionary:
	var status := sweep_wait_action_status()
	if not bool(status.get("enabled", false)):
		return {"ok": false, "message": "There is no sweep to wait out."}
	var before := int(status.get("remaining_actions", 0))
	var advance_result := advance_environment_turns(1)
	if not bool(advance_result.get("ok", false)):
		return {"ok": false, "message": "The sweep boundary could not advance safely.", "errors": _copy_array(advance_result.get("errors", []))}
	var after := current_travel_lock_remaining()
	return {
		"ok": true,
		"action_id": "wait_out_police_sweep",
		"actions_advanced": 1,
		"remaining_actions": after,
		"travel_reopened": after <= 0,
		"message": "The cruisers move on. Travel is open." if after <= 0 else "Keep your head down. %d more action%s." % [after, "" if after == 1 else "s"],
		"previous_remaining_actions": before,
	}


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
	if town_state != null:
		finalized["weather"] = town_state.weather_now()
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


func _town_adjusted_travel_risk_band(base_band: String) -> String:
	if town_state == null:
		return base_band
	var normalized := base_band.strip_edges().to_lower()
	var index := TownStateScript.RISK_BANDS.find(normalized)
	if index < 0:
		return base_band
	var delta := int(town_state.travel_modifier_profile().get("risk_band_delta", 0))
	return str(TownStateScript.RISK_BANDS[clampi(index + delta, 0, TownStateScript.RISK_BANDS.size() - 1)])


func weather_now() -> String:
	return town_state.weather_now() if town_state != null else "clear"


func day_type() -> String:
	return town_state.day_type() if town_state != null else "midweek"


func active_happenings() -> Array:
	return town_state.active_happenings() if town_state != null else []


func happening_active(id: String) -> bool:
	return town_state != null and town_state.happening_active(id)


func town_flag_active(id: String) -> bool:
	return town_state != null and town_state.town_flag_active(id)


func town_snapshot() -> Dictionary:
	return town_state.snapshot() if town_state != null else {}


func town_public_snapshot() -> Dictionary:
	return town_state.public_snapshot() if town_state != null else {}


func set_crew_capability(capability_id: String, enabled: bool = true) -> void:
	var clean_id := capability_id.strip_edges().to_lower()
	if clean_id.is_empty():
		return
	var key := "crew_capability:%s" % clean_id
	if enabled:
		narrative_flags[key] = true
	else:
		narrative_flags.erase(key)


func crew_capability_active(capability_id: String) -> bool:
	var clean_id := capability_id.strip_edges().to_lower()
	if clean_id == "sweep_intel" and crew_rank_perks("crew_switch").has("sweep_intel"):
		return true
	return not clean_id.is_empty() and bool(narrative_flags.get("crew_capability:%s" % clean_id, false))


func sweep_status() -> Dictionary:
	if town_state == null:
		return {}
	return town_state.sweep_status(_world1_host_capability, crew_capability_active("sweep_intel"))


func sweep_map_marker() -> Dictionary:
	if town_state == null:
		return {}
	return town_state.sweep_map_marker(_world1_host_capability, crew_capability_active("sweep_intel"))


func report_sweep_intel_at_boundary() -> Dictionary:
	if town_state == null:
		return {}
	return town_state.report_sweep_intel_at_boundary(_world1_host_capability, crew_capability_active("sweep_intel"))


func swept_window(node_id: String = "") -> Dictionary:
	if town_state == null:
		return {}
	var target := node_id.strip_edges()
	if target.is_empty():
		target = current_world_node_id()
	return town_state.swept_window(target)


func sweep_interplay_seams(node_id: String = "") -> Dictionary:
	var target := node_id.strip_edges()
	if target.is_empty():
		target = current_world_node_id()
	return {
		"node_id": target,
		"knuckles_stash_registered": true,
		"knuckles_stash_active": crew_rank_perks("crew_knuckles").has("contraband_stash"),
		"knuckles_stash_count": crew_contraband_stash.size(),
		"numbers_pause_registered": true,
		"numbers_pause_active": false,
		"delivery_carrier_risk_registered": true,
		"delivery_law_pressure_delta": _delivery_scenario_law_pressure([target]),
		"swept_window": swept_window(target),
	}


func town_status_line() -> String:
	return town_state.status_line() if town_state != null else "Clear outside · Midweek"


func configure_town_world(map_data: Dictionary, initialize_discovery_facts: bool = true) -> void:
	if town_state != null:
		town_state.configure_world(map_data, initialize_discovery_facts)
		if initialize_discovery_facts:
			_register_numbers_discovery_rumors()


func _register_numbers_discovery_rumors() -> void:
	if rumor_fact("numbers_stagger:gas_late").is_empty():
		register_rumor_fact("numbers_whisper", "numbers_stagger:gas_late", {
			"target_node_id": "gas_station_casino", "source_id": "numbers_staggered_close", "fact_detail": "the gas book writes two ticks after the Punchline posts", "numbers_knowledge_fragment": true,
		})
	if rumor_fact("numbers_stagger:corner_late").is_empty():
		register_rumor_fact("numbers_whisper", "numbers_stagger:corner_late", {
			"target_node_id": "corner_store", "source_id": "numbers_staggered_close", "fact_detail": "the corner jar stays open four ticks past the first post", "numbers_knowledge_fragment": true,
		})


func seed_scenario_for_node(node_id: String, scenario: Dictionary) -> bool:
	return town_state != null and town_state.seed_scenario_for_node(node_id, scenario)


func seeded_scenario_for_node(node_id: String) -> Dictionary:
	return town_state.seeded_scenario_for_node(node_id) if town_state != null else {}


func seeded_scenario_definition_for_node(node_id: String) -> Dictionary:
	return town_state.seeded_scenario_definition_for_node(node_id) if town_state != null else {}


func _seeded_scenario_definition_for_node_readonly(node_id: String) -> Dictionary:
	return town_state._seeded_scenario_definition_for_node_readonly(node_id) if town_state != null else {}


func register_rumor_fact(fact_class: String, fact_id: String, payload: Dictionary) -> bool:
	return town_state != null and town_state.register_rumor_fact(fact_class, fact_id, payload)


func register_progressive_meter(meter_id: String, payload: Dictionary) -> Dictionary:
	return town_state.register_progressive_meter(meter_id, payload) if town_state != null else {}


func progressive_meter(meter_id: String) -> Dictionary:
	return town_state.progressive_meter(meter_id) if town_state != null else {}


func set_progressive_meter_value(meter_id: String, value: int) -> Dictionary:
	return town_state.set_progressive_meter_value(meter_id, value) if town_state != null else {}


func rumor_fact(fact_id: String) -> Dictionary:
	return town_state.rumor_fact(fact_id) if town_state != null else {}


func rumor_facts(fact_class: String = "") -> Array:
	return town_state.rumor_facts(fact_class) if town_state != null else []


func rumors_for_venue(node_id: String, speaker_side: String, count: int = 1, rng: RngStream = null) -> Array:
	return town_state.rumors_for_venue(node_id, speaker_side, count, rng) if town_state != null else []


func hear_rumor(rumor_id: String) -> Dictionary:
	if town_state == null:
		return {}
	var heard: Dictionary = {}
	for rumor_value in _copy_array(current_environment.get("town_rumors", [])):
		if typeof(rumor_value) != TYPE_DICTIONARY:
			continue
		var rumor: Dictionary = rumor_value
		if str(rumor.get("id", "")) == rumor_id or str(rumor.get("fact_id", "")) == rumor_id:
			heard = town_state.hear_rendered_rumor(rumor)
			break
	if heard.is_empty():
		heard = town_state.hear_rumor(rumor_id)
	if heard.is_empty():
		return {}
	var target_node_id := str(heard.get("target_node_id", "")).strip_edges()
	if not world_map.is_empty() and not target_node_id.is_empty():
		world_map = WorldMap.mark_heard(world_map, target_node_id, heard)
	var remaining: Array = []
	for rumor_value in _copy_array(current_environment.get("town_rumors", [])):
		if typeof(rumor_value) == TYPE_DICTIONARY and str((rumor_value as Dictionary).get("id", "")) == str(heard.get("id", "")):
			continue
		remaining.append(rumor_value)
	current_environment["town_rumors"] = remaining
	var fact := rumor_fact(str(heard.get("fact_id", "")))
	var payload := _copy_dict(fact.get("payload", {}))
	if numbers_state != null and bool(payload.get("numbers_knowledge_fragment", false)):
		numbers_state.hear_staggered_close_rumor(str(heard.get("fact_id", "")))
	return heard


func heard_rumor_for_node(node_id: String) -> Dictionary:
	return town_state.heard_rumor_for_node(node_id) if town_state != null else {}


func traveler_node(character_id: String) -> String:
	return town_state.traveler_node(character_id) if town_state != null else ""


func travelers_at(node_id: String) -> Array:
	return town_state.travelers_at(node_id) if town_state != null else []


func traveler_state(character_id: String) -> Dictionary:
	return town_state.traveler_state(character_id) if town_state != null else {}


func register_reputation_incident_type(incident_type: String, definition: Dictionary) -> bool:
	return town_state != null and town_state.register_reputation_incident_type(incident_type, definition)


func record_reputation_incident(incident_type: String, node_id: String = "", magnitude: float = 1.0, context: Dictionary = {}) -> Dictionary:
	if town_state == null:
		return {}
	var source_node_id := node_id.strip_edges()
	if source_node_id.is_empty():
		source_node_id = current_world_node_id()
	return town_state.record_reputation_incident(incident_type, source_node_id, magnitude, context)


func local_reputation(node_id: String) -> Dictionary:
	return town_state.local_reputation(node_id) if town_state != null else {}


func reputation_value(node_id: String, incident_type: String = "") -> float:
	return town_state.reputation_value(node_id, incident_type) if town_state != null else 0.0


func record_reputation_from_result(result: Dictionary, deltas: Dictionary) -> void:
	if town_state == null or result.is_empty():
		return
	var node_id := current_world_node_id()
	if node_id.is_empty():
		return
	var source_id := str(result.get("source_id", "")).strip_edges().to_lower()
	var action_id := str(result.get("action_id", "")).strip_edges().to_lower()
	var action_kind := str(result.get("action_kind", "")).strip_edges().to_lower()
	var bankroll_delta := int(deltas.get("bankroll_delta", result.get("bankroll_delta", 0)))
	var suspicion_delta := int(deltas.get("suspicion_delta", result.get("suspicion_delta", 0)))
	var stake := maxi(0, int(result.get("stake", result.get("wager", 0))))
	if bankroll_delta >= maxi(40, stake * 3):
		record_reputation_incident("big_public_win", node_id, 1.0, {"source_id": source_id, "bankroll_delta": bankroll_delta})
	if action_id.begins_with("tip_") or action_id == "tip_dealer":
		record_reputation_incident("generous_tipper", node_id, 1.0, {"source_id": source_id, "bankroll_delta": bankroll_delta})
	var alarm_named := source_id.contains("alarm") or source_id.contains("security") or action_id.contains("alarm")
	if alarm_named or (action_kind in ["cheat", "risky"] and suspicion_delta >= 8):
		record_reputation_incident("alarm_tripped", node_id, 1.0, {"source_id": source_id, "suspicion_delta": suspicion_delta})


func scenario_weight_multiplier(archetype_id: String, scenario_id: String, tags: Array) -> float:
	if town_state == null:
		return CharacterChainModelScript.scenario_weight_multiplier(self, archetype_id, scenario_id)
	return town_state.scenario_weight_multiplier(archetype_id, scenario_id, tags) * CharacterChainModelScript.scenario_weight_multiplier(self, archetype_id, scenario_id)


func apply_town_generation_modifiers(environment_data: Dictionary, rng: RngStream = null) -> void:
	if town_state == null or environment_data.is_empty():
		return
	var economic := _copy_dict(environment_data.get("economic_profile", {}))
	var economic_modifiers := town_state.economic_modifier_profile()
	_apply_town_stake_multiplier(economic, "stake_floor", float(economic_modifiers.get("stake_floor_multiplier", 1.0)))
	_apply_town_stake_multiplier(economic, "stake_ceiling", float(economic_modifiers.get("stake_ceiling_multiplier", 1.0)))
	_apply_town_stake_override_multipliers(economic, "game_stake_floor_overrides", float(economic_modifiers.get("stake_floor_multiplier", 1.0)))
	_apply_town_stake_override_multipliers(economic, "game_stake_ceiling_overrides", float(economic_modifiers.get("stake_ceiling_multiplier", 1.0)))
	environment_data["economic_profile"] = economic
	var visual := _copy_dict(environment_data.get("visual_context", {}))
	visual["crowd_density_multiplier"] = maxf(0.0, float(economic_modifiers.get("crowd_density_multiplier", 1.0)))
	environment_data["visual_context"] = visual
	var music := _copy_dict(environment_data.get("music_profile", {}))
	var music_modifiers := town_state.music_modifier_profile()
	music["ambience"] = clampf(float(music.get("ambience", 0.7)) + float(music_modifiers.get("ambience_delta", 0.0)), 0.0, 1.0)
	music["volume"] = maxf(0.0, float(music.get("volume", 0.26)) * float(music_modifiers.get("volume_multiplier", 1.0)))
	var texture_override := str(music_modifiers.get("texture_override", "")).strip_edges()
	if not texture_override.is_empty():
		music["texture"] = texture_override
	music["town_modifiers"] = music_modifiers.duplicate(true)
	environment_data["music_profile"] = music
	environment_data["town_conditions"] = town_state.public_snapshot()
	apply_town_living_world_context(environment_data, rng)


func apply_town_living_world_context(environment_data: Dictionary, rng: RngStream = null) -> void:
	if town_state == null or environment_data.is_empty():
		return
	_apply_town_traveler_generation_context(environment_data)
	_apply_town_reputation_generation_context(environment_data)
	_apply_town_sweep_generation_context(environment_data)
	_apply_town_rumor_generation_context(environment_data, rng)
	CharacterChainModelScript.apply_to_environment(self, environment_data)


func _apply_town_sweep_generation_context(environment_data: Dictionary) -> void:
	if town_state == null or environment_data.is_empty():
		return
	var node_id := str(environment_data.get("world_node_id", environment_data.get("archetype_id", environment_data.get("id", "")))).strip_edges()
	if node_id.is_empty():
		return
	var security := _copy_dict(environment_data.get("security_profile", {}))
	var channels := _copy_dict(security.get("security_override_channels", {}))
	var existing := _copy_dict(channels.get("police_sweep", {}))
	var window := town_state.swept_window(node_id)
	if window.is_empty():
		if not existing.is_empty():
			_restore_sweep_security_value(security, existing, "strictness_band")
			_restore_sweep_security_value(security, existing, "cheat_risk_window")
			_restore_sweep_security_value(security, existing, "machine_alarm_tolerance_band")
			security.erase("swept_window_remaining_actions")
			security.erase("cheat_windows_open")
			security.erase("pusher_alarm_tolerance_band_delta")
			channels.erase("police_sweep")
			security["security_override_channels"] = channels
			environment_data["security_profile"] = security
		return
	if existing.is_empty():
		existing = {
			"source": "police_sweep",
			"base_strictness_band": str(security.get("strictness_band", security.get("strictness", "low"))),
			"base_cheat_risk_window": str(security.get("cheat_risk_window", "normal")),
			"base_machine_alarm_tolerance_band": str(security.get("machine_alarm_tolerance_band", "normal")),
		}
	existing["strictness_band_delta"] = -1
	existing["cheat_window_open"] = true
	existing["pusher_alarm_tolerance_band_delta"] = 1
	existing["remaining_actions"] = int(window.get("remaining_actions", 0))
	channels["police_sweep"] = existing
	security["strictness_band"] = _sweep_looser_strictness(str(existing.get("base_strictness_band", "low")))
	security["cheat_risk_window"] = "open"
	security["machine_alarm_tolerance_band"] = _sweep_looser_alarm_band(str(existing.get("base_machine_alarm_tolerance_band", "normal")))
	security["swept_window_remaining_actions"] = int(window.get("remaining_actions", 0))
	security["cheat_windows_open"] = true
	security["pusher_alarm_tolerance_band_delta"] = 1
	security["security_override_channels"] = channels
	environment_data["security_profile"] = security


func _restore_sweep_security_value(security: Dictionary, channel: Dictionary, key: String) -> void:
	var base_key := "base_%s" % key
	if channel.has(base_key):
		security[key] = channel.get(base_key)
	else:
		security.erase(key)


func _sweep_looser_strictness(value: String) -> String:
	match value.strip_edges().to_lower():
		"boss":
			return "high"
		"high":
			return "tight"
		"tight", "velvet":
			return "moderate"
		"moderate", "uneven", "private", "licensed-gray":
			return "low"
		"low", "distracted":
			return "relaxed"
		_:
			return "relaxed"


func _sweep_looser_alarm_band(value: String) -> String:
	match value.strip_edges().to_lower():
		"twitchy", "strict":
			return "normal"
		"normal":
			return "lax"
		"lax":
			return "open"
		_:
			return "lax"


func _apply_town_traveler_generation_context(environment_data: Dictionary) -> void:
	var node_id := str(environment_data.get("world_node_id", environment_data.get("archetype_id", environment_data.get("id", "")))).strip_edges()
	if node_id.is_empty():
		return
	var presence := travelers_at(node_id)
	environment_data["traveler_presence_ids"] = presence.duplicate()
	var patrons := _string_array(_copy_array(environment_data.get("scenario_patron_ids", [])))
	for character_id in presence:
		if not patrons.has(character_id):
			patrons.append(character_id)
	environment_data["scenario_patron_ids"] = patrons
	var flags := _copy_dict(environment_data.get("local_narrative_flags", {}))
	flags.erase("rival_worked_here")
	flags.erase("rival_worked_here_remaining_actions")
	var security := _copy_dict(environment_data.get("security_profile", {}))
	security.erase("rival_table_attention_delta")
	var cass_modifier := {} if bool(story_flags.get("chain06_cass_ending_truce", false)) else town_state.departed_traveler_modifier(node_id, "cass_rival_counter")
	if not cass_modifier.is_empty():
		flags["rival_worked_here"] = true
		flags["rival_worked_here_remaining_actions"] = int(cass_modifier.get("remaining_actions", 0))
		security["rival_table_attention_delta"] = int(cass_modifier.get("table_attention_delta", 1))
	environment_data["local_narrative_flags"] = flags
	environment_data["security_profile"] = security


func _apply_town_reputation_generation_context(environment_data: Dictionary) -> void:
	var node_id := str(environment_data.get("world_node_id", environment_data.get("archetype_id", environment_data.get("id", "")))).strip_edges()
	if node_id.is_empty():
		return
	var reputation := local_reputation(node_id)
	environment_data["town_reputation"] = reputation.duplicate(true)
	var security := _copy_dict(environment_data.get("security_profile", {}))
	var base_strictness := str(security.get("town_base_strictness", security.get("strictness", "low"))).strip_edges().to_lower()
	security["town_base_strictness"] = base_strictness
	var strictness_bands := ["low", "moderate", "high", "boss"]
	var band_index := 0
	if ["uneven", "licensed-gray", "private", "moderate"].has(base_strictness):
		band_index = 1
	elif ["high", "velvet"].has(base_strictness):
		band_index = 2
	elif base_strictness == "boss":
		band_index = 3
	var effective_index := clampi(band_index + int(reputation.get("door_strictness_delta", 0)), 0, strictness_bands.size() - 1)
	security["door_strictness_band"] = str(strictness_bands[effective_index])
	security["town_door_strictness_delta"] = int(reputation.get("door_strictness_delta", 0))
	security["town_reputation_attention"] = float(reputation.get("attention", 0.0))
	environment_data["security_profile"] = security
	var rare_reaction := _copy_dict(reputation.get("rare_reaction", {}))
	if not rare_reaction.is_empty():
		var event_ids := _string_array(_copy_array(environment_data.get("event_ids", [])))
		if not event_ids.has("town_reputation_reaction"):
			event_ids.append("town_reputation_reaction")
		environment_data["event_ids"] = event_ids


func _apply_town_rumor_generation_context(environment_data: Dictionary, rng: RngStream) -> void:
	var node_id := str(environment_data.get("world_node_id", environment_data.get("archetype_id", environment_data.get("id", "")))).strip_edges()
	if node_id.is_empty():
		return
	var rumors := _copy_array(environment_data.get("town_rumors", []))
	if rumors.is_empty():
		rumors = rumors_for_venue(node_id, _town_speaker_side(str(environment_data.get("archetype_id", node_id))), 1, rng)
	environment_data["town_rumors"] = rumors
	if rumors.is_empty():
		return
	var archetype_id := str(environment_data.get("archetype_id", node_id)).strip_edges()
	if not _town_has_rumor_staff(archetype_id):
		return
	var event_ids := _string_array(_copy_array(environment_data.get("event_ids", [])))
	var resolved := _string_array(_copy_array(environment_data.get("resolved_event_ids", [])))
	if not event_ids.has("town_rumor_staff") and not resolved.has("town_rumor_staff"):
		event_ids.append("town_rumor_staff")
	environment_data["event_ids"] = event_ids


func _town_has_rumor_staff(archetype_id: String) -> bool:
	return [
		"bar",
		"corner_store",
		"delta_queen",
		"gas_station_casino",
		"grand_casino",
		"jazz_club",
		"kitty_cat_lounge",
		"motel",
		"pawn_shop",
		"small_underground_casino",
	].has(archetype_id)


func _town_speaker_side(archetype_id: String) -> String:
	if ["corner_store", "back_alley", "motel", "bar", "gas_station_casino", "pawn_shop"].has(archetype_id):
		return "street"
	if ["grand_casino", "grand_casino_high_limit", "grand_casino_back_room", "grand_casino_cage", "delta_queen", "kitty_cat_lounge"].has(archetype_id):
		return "house"
	if ["small_underground_casino", "jazz_club", "beach"].has(archetype_id):
		return "seam"
	return "neutral"


func _apply_town_stake_multiplier(profile: Dictionary, key: String, multiplier: float) -> void:
	if not profile.has(key):
		return
	var value := maxi(0, int(profile.get(key, 0)))
	if value <= 0:
		return
	profile[key] = maxi(1, int(round(float(value) * maxf(0.0, multiplier))))


func _apply_town_stake_override_multipliers(profile: Dictionary, key: String, multiplier: float) -> void:
	var overrides := _copy_dict(profile.get(key, {}))
	if overrides.is_empty():
		return
	for game_id_value in overrides.keys():
		var value := maxi(0, int(overrides.get(game_id_value, 0)))
		if value > 0:
			overrides[game_id_value] = maxi(1, int(round(float(value) * maxf(0.0, multiplier))))
	profile[key] = overrides


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


# Resolves a narrative favor attached to one lender without inventing a second
# debt system. Honoring clears the soft note; refusing converts it into a short,
# ordinary repayment clock so no favor_owed state can dangle forever.
func resolve_lender_favor(lender_id: String, resolution: String) -> Dictionary:
	var clean_lender := lender_id.strip_edges()
	var clean_resolution := resolution.strip_edges().to_lower()
	if clean_lender.is_empty() or not ["honored", "refused"].has(clean_resolution):
		return {"ok": false, "message": "That favor cannot be resolved."}
	for index in range(debt.size() - 1, -1, -1):
		if typeof(debt[index]) != TYPE_DICTIONARY:
			continue
		var debt_data := (debt[index] as Dictionary).duplicate(true)
		if str(debt_data.get("lender_id", "")) != clean_lender:
			continue
		if not ["active", "overdue", "favor_due"].has(str(debt_data.get("status", "active"))):
			continue
		if clean_resolution == "honored":
			debt.remove_at(index)
			_mark_lender_repaid(clean_lender)
			narrative_flags["debt_favor_owed"] = false
			_refresh_economy(true)
			return {"ok": true, "resolution": clean_resolution, "debt_id": str(debt_data.get("id", "")), "message": "The favor closes the soft note."}
		debt_data["status"] = "active"
		debt_data["default_consequence"] = "forced_repayment"
		debt_data["turns_remaining"] = 2
		debt_data["deadline_turns"] = 2
		debt[index] = debt_data
		narrative_flags["debt_favor_owed"] = false
		_refresh_economy(true)
		return {"ok": true, "resolution": clean_resolution, "debt_id": str(debt_data.get("id", "")), "message": "The favor becomes an ordinary note. Two ticks."}
	return {"ok": false, "message": "No favor from that lender is waiting."}


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


# Read-only production turn preflight. It executes the authored expiry and
# world-boundary fact against a detached environment so deterministic capacity
# or handler rejection is reported before any clock, RNG, town, or room state
# can move.
func _scenario_preflight_environment_turn(amount: int) -> Dictionary:
	var present := scenario_sequence_present()
	if amount <= 0 or not present:
		return {"ok": true, "inactive": true, "errors": []}
	if not _scenario_semantic_ready():
		return {"ok": false, "inactive": false, "errors": ["Dynamic room sequence semantic records are not finalized."]}
	var definition := _scenario_sequence_definition_readonly()
	var state_value: Variant = current_environment.get("scenario_sequence_state", {})
	var state: Dictionary = state_value as Dictionary if typeof(state_value) == TYPE_DICTIONARY else {}
	if state.is_empty():
		return {"ok": false, "inactive": false, "errors": ["Dynamic room sequence turn preflight requires initialized causal state."]}
	var required_causes := 1
	var uses_expiry := _scenario_sequence_uses_expiry_boundary("town_action")
	if uses_expiry and not bool(state.get("expired", false)):
		required_causes += 1
	if ScenarioSequenceRuntimeScript._next_cause_ordinal(state) + _copy_array(state.get("fact_queue", [])).size() + required_causes > ScenarioSequenceRuntimeScript.MAX_RECEIPTS:
		return {"ok": false, "inactive": false, "errors": ["scenario causal journal lifetime limit reached"]}
	# The complete turn already executes on a detached RunState. Runtime state,
	# handler, and layout validation still occur during the real operations and
	# discard that candidate on rejection; preflight only reserves capacity.
	return {"ok": true, "inactive": false, "errors": []}


# Advances the current environment clock.
func advance_environment_turns(amount: int = 1, profile_stages: bool = false) -> Dictionary:
	if current_environment.is_empty() or is_terminal():
		return {"ok": true, "applied": false, "errors": []}
	var profile_started_usec := Time.get_ticks_usec() if profile_stages else 0
	# A room without a scenario sequence has no rejecting operation after the
	# read-only preflight: every fact ingress below returns the documented
	# inactive result. Advance that common path in place, preserving every live
	# alias and avoiding a full RunState transaction for ordinary game inputs.
	# The forced-rejection seam deliberately keeps the detached path so the exact
	# rollback contract remains exercised in debug qualification.
	if _turn_transaction_test_failure_stage.is_empty() and not scenario_sequence_present():
		var direct_result := _advance_environment_turns_candidate(amount)
		if profile_stages:
			direct_result["debug_turn_transaction_usec"] = {"candidate_create": 0, "candidate_advance": Time.get_ticks_usec() - profile_started_usec, "publish": 0, "total": Time.get_ticks_usec() - profile_started_usec}
		return direct_result
	var profile_stage_started_usec := profile_started_usec
	var candidate := _detached_environment_turn_candidate()
	var candidate_create_usec := Time.get_ticks_usec() - profile_stage_started_usec if profile_stages else 0
	profile_stage_started_usec = Time.get_ticks_usec() if profile_stages else 0
	var result := candidate._advance_environment_turns_candidate(amount)
	var candidate_advance_usec := Time.get_ticks_usec() - profile_stage_started_usec if profile_stages else 0
	if not bool(result.get("ok", false)):
		if profile_stages:
			result["debug_turn_transaction_usec"] = {"candidate_create": candidate_create_usec, "candidate_advance": candidate_advance_usec, "publish": 0, "total": Time.get_ticks_usec() - profile_started_usec}
		return result
	profile_stage_started_usec = Time.get_ticks_usec() if profile_stages else 0
	_publish_environment_turn_candidate(candidate)
	if profile_stages:
		result["debug_turn_transaction_usec"] = {"candidate_create": candidate_create_usec, "candidate_advance": candidate_advance_usec, "publish": Time.get_ticks_usec() - profile_stage_started_usec, "total": Time.get_ticks_usec() - profile_started_usec}
	return result


# Executes the complete turn against a graph that shares no mutable roots with
# the live RunState. The caller either discards this object or publishes it as a
# single graph-consistent tuple through _publish_environment_turn_candidate().
func _advance_environment_turns_candidate(amount: int) -> Dictionary:
	var safe_amount := maxi(0, amount)
	var scenario_facts_active := scenario_sequence_present()
	var uses_v2_expiry := safe_amount > 0 and _scenario_sequence_uses_expiry_boundary("town_action")
	var turn_preflight := _scenario_preflight_environment_turn(safe_amount)
	if not bool(turn_preflight.get("ok", false)):
		return {"ok": false, "applied": false, "errors": _copy_array(turn_preflight.get("errors", []))}
	var forced_failure := _environment_turn_test_failure("preflight")
	if not forced_failure.is_empty(): return forced_failure
	if uses_v2_expiry:
		var expiry_result := scenario_sequence_apply_expiry_boundary("town_action", safe_amount)
		if not bool(expiry_result.get("ok", false)):
			return {"ok": false, "applied": false, "errors": _copy_array(expiry_result.get("errors", []))}
		# Cleanup expiry is a valid terminal transition. Do not enqueue the later
		# town/world facts into a sequence that this same boundary just cleaned.
		# The pre-expiry value is retained only when the sequence remains active.
		var post_expiry_state := _copy_dict(current_environment.get("scenario_sequence_state", {}))
		scenario_facts_active = str(post_expiry_state.get("status", "")) == ScenarioSequenceRuntimeScript.STATUS_ACTIVE
	forced_failure = _environment_turn_test_failure("expiry")
	if not forced_failure.is_empty(): return forced_failure
	# Town/sweep snapshots exist only to author scenario facts. Ordinary rooms have
	# no sequence consumer, so avoid constructing and comparing both nested public
	# views on every game action while retaining every transaction failure seam.
	var town_before := town_state.public_snapshot() if town_state != null and scenario_facts_active else {}
	var sweep_before := town_state.sweep_internal_status() if town_state != null and scenario_facts_active else {}
	_advance_global_boundary_start(safe_amount)
	forced_failure = _environment_turn_test_failure("global_start")
	if not forced_failure.is_empty(): return forced_failure
	var previous_turns := int(current_environment.get("turns", 0))
	var next_turns := previous_turns + safe_amount
	current_environment["turns"] = next_turns
	_advance_environment_layer_ambient(next_turns)
	if ScenarioEngineScript.advance_environment(current_environment, safe_amount):
		current_environment["layout"] = EnvironmentInstance.ensure_generated_layout(current_environment)
	_advance_travel_lock(safe_amount)
	forced_failure = _environment_turn_test_failure("environment")
	if not forced_failure.is_empty(): return forced_failure
	_apply_town_sweep_generation_context(current_environment)
	_check_police_sweep_boundary()
	forced_failure = _environment_turn_test_failure("town_sweep")
	if not forced_failure.is_empty(): return forced_failure
	_advance_global_boundary_after_encounter(safe_amount)
	_advance_grand_casino_living_floor(safe_amount)
	forced_failure = _environment_turn_test_failure("encounter_and_rooms")
	if not forced_failure.is_empty(): return forced_failure
	_advance_global_boundary_before_local_cooldown(safe_amount)
	var decay_interval := maxi(1, LOCAL_RISK_TURN_DECAY_INTERVAL + int(challenge_modifiers().get("local_heat_turn_decay_interval_delta", 0)))
	var previous_decay_step := int(floor(float(previous_turns) / float(decay_interval)))
	var next_decay_step := int(floor(float(next_turns) / float(decay_interval)))
	_decrease_current_suspicion(next_decay_step - previous_decay_step)
	_advance_heat_cooldown(safe_amount)
	_advance_global_boundary_finish(safe_amount)
	forced_failure = _environment_turn_test_failure("crew_and_world_models")
	if not forced_failure.is_empty(): return forced_failure
	if town_state != null:
		if scenario_facts_active:
			var town_after := town_state.public_snapshot()
			if town_after != town_before:
				var happening_ids: Array = []
				for happening_value in _copy_array(town_after.get("active_happenings", [])):
					if typeof(happening_value) != TYPE_DICTIONARY:
						continue
					var happening_id := str((happening_value as Dictionary).get("id", "")).strip_edges()
					if not happening_id.is_empty() and not happening_ids.has(happening_id):
						happening_ids.append(happening_id)
				happening_ids.sort()
				var town_fact := scenario_enqueue_fact("town_transition", "town", {"action_index": _crew_action_index(), "weather": str(town_after.get("weather", "")), "day_type": str(town_after.get("day_type", "")), "happening_ids": happening_ids})
				if not bool(town_fact.get("ok", false)) and not bool(town_fact.get("inactive", false)):
					return {"ok": false, "applied": false, "errors": _copy_array(town_fact.get("errors", []))}
		forced_failure = _environment_turn_test_failure("town_fact")
		if not forced_failure.is_empty(): return forced_failure
		if scenario_facts_active:
			var sweep_after := town_state.sweep_internal_status()
			if sweep_after != sweep_before:
				var sweep_fact := scenario_enqueue_fact("sweep_changed", "sweep", {"action_index": _crew_action_index(), "node_id": str(sweep_after.get("current_node_id", "")), "segment_index": int(sweep_after.get("segment_index", -1)), "active": bool(sweep_after.get("active", false))})
				if not bool(sweep_fact.get("ok", false)) and not bool(sweep_fact.get("inactive", false)):
					return {"ok": false, "applied": false, "errors": _copy_array(sweep_fact.get("errors", []))}
		forced_failure = _environment_turn_test_failure("sweep_fact")
		if not forced_failure.is_empty(): return forced_failure
	if safe_amount > 0:
		var world_fact := {}
		if scenario_facts_active:
			world_fact = scenario_enqueue_fact("world_boundary", "scenario", {"amount": safe_amount, "action_index": _crew_action_index()})
			if not bool(world_fact.get("ok", false)) and not bool(world_fact.get("inactive", false)):
				return {"ok": false, "applied": false, "errors": _copy_array(world_fact.get("errors", []))}
		forced_failure = _environment_turn_test_failure("world_fact")
		if not forced_failure.is_empty(): return forced_failure
		if scenario_facts_active and not bool(world_fact.get("inactive", false)):
			var flushed := scenario_flush_facts(_crew_action_index())
			if not bool(flushed.get("ok", false)):
				return {"ok": false, "applied": false, "errors": _copy_array(flushed.get("errors", []))}
		forced_failure = _environment_turn_test_failure("fact_flush")
		if not forced_failure.is_empty(): return forced_failure
	# A v2 town_action expiry was applied above. When it is absent, the authored
	# sequence explicitly names another boundary (or none), so invoking the legacy
	# expiry facade here can only perform an expensive no-op reconstruction.
	forced_failure = _environment_turn_test_failure("legacy_expiry")
	if not forced_failure.is_empty(): return forced_failure
	return {"ok": true, "applied": safe_amount > 0, "errors": []}


func _environment_turn_test_failure(stage: String) -> Dictionary:
	if OS.is_debug_build() and _turn_transaction_test_failure_stage == stage:
		return {
			"ok": false,
			"applied": false,
			"failure_stage": stage,
			"errors": ["Forced environment-turn transaction rejection after %s." % stage],
		}
	return {}


func _detached_environment_turn_candidate() -> RunState:
	var candidate := get_script().new() as RunState
	candidate._apply_environment_turn_snapshot(_environment_turn_snapshot(), false)
	return candidate


func _publish_environment_turn_candidate(candidate: RunState) -> void:
	# Build the complete publish tuple before touching a live root. This method is
	# synchronous and contains the only accepted-turn rebind boundary. The
	# candidate already owns a completely detached collection graph, so publishing
	# its exact roots does not require deep-copying that graph a second time.
	var publish_snapshot := candidate._environment_turn_publish_snapshot()
	_apply_environment_turn_snapshot(publish_snapshot, true)


func _environment_turn_publish_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for field_name in TURN_TRANSACTION_SCALAR_FIELDS:
		snapshot[field_name] = get(field_name)
	for field_name in TURN_TRANSACTION_COLLECTION_FIELDS:
		snapshot[field_name] = get(field_name)
	snapshot["town_state_object"] = {
		"present": town_state != null,
		"source": town_state,
	}
	snapshot["numbers_state_object"] = {
		"present": numbers_state != null,
		"source": numbers_state,
	}
	return snapshot


func _environment_turn_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for field_name in TURN_TRANSACTION_SCALAR_FIELDS:
		snapshot[field_name] = get(field_name)
	# Duplicate the mutable transaction roots as one graph. Grand Casino room
	# storage can intentionally alias the live current environment; duplicating
	# each field independently loses that relationship and lets a stale room copy
	# overwrite the newly advanced environment while the candidate is published.
	var active_room_alias_ids: Array = []
	for room_id_value in grand_casino_room_states.keys():
		var room_value: Variant = grand_casino_room_states.get(room_id_value)
		if typeof(room_value) == TYPE_DICTIONARY and is_same(room_value, current_environment):
			active_room_alias_ids.append(room_id_value)
	# Game modules own game_states; an environment turn neither reads nor mutates
	# those opaque machine records. Detach the mutable environment shell while
	# retaining that exact immutable subtree. This prevents a 300-piece pusher
	# checkpoint from being copied into the candidate and then walked again during
	# publication for every quarter, without relaxing transaction atomicity.
	var transaction_environment: Dictionary = {}
	for environment_key in current_environment.keys():
		if str(environment_key) != "game_states":
			transaction_environment[environment_key] = current_environment[environment_key]
	var transaction_rooms := grand_casino_room_states.duplicate(false)
	for room_id_value in active_room_alias_ids:
		transaction_rooms[room_id_value] = transaction_environment
	var collection_graph: Dictionary = {}
	var detached_shallow_caches: Dictionary = {}
	for field_name in TURN_TRANSACTION_COLLECTION_FIELDS:
		if field_name in TURN_TRANSACTION_SHALLOW_CACHE_FIELDS:
			var cache_value: Variant = get(field_name)
			detached_shallow_caches[field_name] = cache_value.duplicate(false) if typeof(cache_value) in [TYPE_DICTIONARY, TYPE_ARRAY] else cache_value
		elif field_name == "current_environment":
			collection_graph[field_name] = transaction_environment
		elif field_name == "grand_casino_room_states":
			collection_graph[field_name] = transaction_rooms
		else:
			collection_graph[field_name] = get(field_name)
	var detached_collection_graph := collection_graph.duplicate(true)
	var detached_rooms: Dictionary = detached_collection_graph.get("grand_casino_room_states", {})
	var detached_environment: Dictionary = detached_collection_graph.get("current_environment", {})
	var game_states_value: Variant = current_environment.get("game_states", null)
	if typeof(game_states_value) == TYPE_DICTIONARY:
		detached_environment["game_states"] = game_states_value
	for room_id_value in active_room_alias_ids:
		detached_rooms[room_id_value] = detached_environment
	for field_name in TURN_TRANSACTION_COLLECTION_FIELDS:
		snapshot[field_name] = detached_shallow_caches.get(field_name) if field_name in TURN_TRANSACTION_SHALLOW_CACHE_FIELDS else detached_collection_graph.get(field_name)
	snapshot["town_state_object"] = {
		"present": town_state != null,
		"state": town_state.snapshot() if town_state != null else {},
		"conditions": town_state._conditions.duplicate(true) if town_state != null else {},
	}
	snapshot["numbers_state_object"] = {
		"present": numbers_state != null,
		"state": numbers_state.snapshot() if numbers_state != null else {},
		"config": numbers_state.config.duplicate(true) if numbers_state != null else {},
	}
	return snapshot


func _apply_environment_turn_snapshot(snapshot: Dictionary, preserve_live_aliases: bool) -> void:
	for field_name in TURN_TRANSACTION_SCALAR_FIELDS:
		set(field_name, snapshot.get(field_name))
	for field_name in TURN_TRANSACTION_COLLECTION_FIELDS:
		var incoming: Variant = snapshot.get(field_name)
		if not preserve_live_aliases:
			# The snapshot already owns a detached graph. Installing its roots
			# directly retains cross-field aliases inside the transaction candidate.
			set(field_name, incoming)
			continue
		if field_name in TURN_TRANSACTION_SHALLOW_CACHE_FIELDS:
			# These private caches own detached outer containers but immutable
			# definition/scalar values. An accepted candidate can transfer that
			# outer cache directly; no external gameplay identity retains it.
			set(field_name, incoming)
			continue
		var current: Variant = get(field_name)
		if field_name == "current_environment" and typeof(current) == TYPE_DICTIONARY and typeof(incoming) == TYPE_DICTIONARY:
			_publish_environment_dictionary_in_place(current as Dictionary, incoming as Dictionary)
			continue
		if preserve_live_aliases and _publish_mutable_variant_in_place(current, incoming):
			continue
		set(field_name, incoming.duplicate(true) if typeof(incoming) in [TYPE_DICTIONARY, TYPE_ARRAY] else incoming)
	var town_record := _copy_dict(snapshot.get("town_state_object", {}))
	if bool(town_record.get("present", false)):
		if town_state == null:
			town_state = TownStateScript.new()
			town_state.bind_host_capability(_world1_host_capability)
		var town_source: Variant = town_record.get("source", null)
		if preserve_live_aliases and typeof(town_source) == TYPE_OBJECT and is_instance_valid(town_source):
			_publish_refcounted_script_state(town_state, town_source as Object)
		else:
			town_state.restore(_copy_dict(town_record.get("state", {})), seed_value, _copy_dict(town_record.get("conditions", {})))
	else:
		town_state = null
	var numbers_record := _copy_dict(snapshot.get("numbers_state_object", {}))
	if bool(numbers_record.get("present", false)):
		if numbers_state == null:
			numbers_state = _new_numbers_model()
		var numbers_source: Variant = numbers_record.get("source", null)
		if preserve_live_aliases and typeof(numbers_source) == TYPE_OBJECT and is_instance_valid(numbers_source):
			_publish_refcounted_script_state(numbers_state, numbers_source as Object)
		else:
			numbers_state.restore(_copy_dict(numbers_record.get("state", {})), seed_value, _copy_dict(numbers_record.get("config", {})))
	else:
		numbers_state = null


static func _publish_refcounted_script_state(live_object: Object, candidate_object: Object) -> void:
	# The accepted candidate is already detached and will not execute again. Move
	# its complete stored model fields into the retained authoritative object rather
	# than serializing and reconstructing both models during the synchronous input
	# boundary. This retains the externally held TownState/NumbersModel identities.
	for property_record in candidate_object.get_property_list():
		if typeof(property_record) != TYPE_DICTIONARY:
			continue
		var property: Dictionary = property_record
		var usage := int(property.get("usage", 0))
		if (usage & PROPERTY_USAGE_STORAGE) == 0 and (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var property_name := str(property.get("name", ""))
		if property_name.is_empty() or property_name == "script":
			continue
		live_object.set(property_name, candidate_object.get(property_name))


static func _publish_environment_dictionary_in_place(live_environment: Dictionary, candidate_environment: Dictionary) -> void:
	# External systems retain the environment root (and, when unchanged, its
	# nested authored roots). Changed environment fields are already detached and
	# complete in the accepted candidate, so publish them field-wise instead of
	# recursively interpreting every generated layout/presentation dictionary in
	# GDScript. Equality retains exact unchanged nested identities.
	for key in live_environment.keys():
		if not candidate_environment.has(key):
			live_environment.erase(key)
	for key in candidate_environment.keys():
		var incoming: Variant = candidate_environment[key]
		if live_environment.has(key):
			var current: Variant = live_environment[key]
			if (typeof(current) in [TYPE_DICTIONARY, TYPE_ARRAY] and is_same(current, incoming)) or current == incoming:
				continue
		live_environment[key] = incoming.duplicate(true) if typeof(incoming) in [TYPE_DICTIONARY, TYPE_ARRAY] else incoming


static func _publish_mutable_variant_in_place(live_value: Variant, candidate_value: Variant) -> bool:
	if typeof(live_value) == TYPE_DICTIONARY and typeof(candidate_value) == TYPE_DICTIONARY:
		if is_same(live_value, candidate_value):
			return true
		# Variant equality is implemented natively and proves an unchanged detached
		# subtree exactly. Avoid walking that subtree key-by-key in GDScript merely
		# to reassign the same values during an accepted transaction publish.
		if live_value == candidate_value:
			return true
		var live_dictionary := live_value as Dictionary
		var candidate_dictionary := candidate_value as Dictionary
		for key in live_dictionary.keys():
			if not candidate_dictionary.has(key): live_dictionary.erase(key)
		for key in candidate_dictionary.keys():
			var incoming: Variant = candidate_dictionary[key]
			if live_dictionary.has(key) and _publish_mutable_variant_in_place(live_dictionary[key], incoming):
				continue
			live_dictionary[key] = incoming.duplicate(true) if typeof(incoming) in [TYPE_DICTIONARY, TYPE_ARRAY] else incoming
		return true
	if typeof(live_value) == TYPE_ARRAY and typeof(candidate_value) == TYPE_ARRAY:
		if is_same(live_value, candidate_value):
			return true
		if live_value == candidate_value:
			return true
		var live_array := live_value as Array
		var candidate_array := candidate_value as Array
		while live_array.size() > candidate_array.size(): live_array.pop_back()
		for index in range(candidate_array.size()):
			var incoming: Variant = candidate_array[index]
			if index < live_array.size():
				if _publish_mutable_variant_in_place(live_array[index], incoming): continue
				live_array[index] = incoming.duplicate(true) if typeof(incoming) in [TYPE_DICTIONARY, TYPE_ARRAY] else incoming
			else:
				live_array.append(incoming.duplicate(true) if typeof(incoming) in [TYPE_DICTIONARY, TYPE_ARRAY] else incoming)
		return true
	return false


func _advance_global_boundary_start(safe_amount: int) -> void:
	if town_state != null:
		town_state.advance_actions(safe_amount)
	if delivery_has_active_run() and safe_amount > 0:
		active_delivery_run = DeliveryRunModelScript.advance_boundaries(
			active_delivery_run,
			safe_amount,
			current_world_node_id(),
			suspicion_level(),
			_crew_action_index()
		)
		_apply_delivery_resolution()
	simulation_msec = maxi(0, simulation_msec + safe_amount * SIMULATION_ACTION_MSEC)
	event_cadence_advance_actions(safe_amount)
	if numbers_state != null:
		if current_world_node_id() == "small_underground_casino":
			_ensure_scenario_host_public_context()
			numbers_state.host_mark_draw_presence(
				_numbers_host_capability,
				_crew_action_index(),
				current_world_node_id(),
				_scenario_host_public_context(),
			)
		_apply_numbers_events(numbers_state.advance_to(_crew_action_index()))
	var alcohol_decay := safe_amount * DRUNK_TURN_DECAY
	if alcohol_decay > 0:
		change_drunk(-alcohol_decay)


func _advance_global_boundary_after_encounter(safe_amount: int) -> void:
	_advance_narrative_action_timers(safe_amount)


func _advance_global_boundary_before_local_cooldown(safe_amount: int) -> void:
	drunk_distortion_suppression_turns = maxi(0, drunk_distortion_suppression_turns - safe_amount)


func _advance_global_boundary_finish(safe_amount: int) -> void:
	_advance_debt_clocks(safe_amount)
	_advance_crew_jobs()
	if safe_amount > 0:
		CrewPlayModelScript.advance_boundary(self, current_environment, _world1_host_capability)
		_crew_heist_boundary_sync()
	CharacterChainModelScript.advance(self, safe_amount)


func _advance_environment_layer_ambient(total_turns: int) -> void:
	var lines := _string_array(_copy_array(current_environment.get("layer_ambient_lines", [])))
	if lines.is_empty():
		return
	var interval := maxi(1, int(current_environment.get("layer_ambient_rotate_actions", 1)))
	var index := posmod(int(floor(float(maxi(0, total_turns)) / float(interval))), lines.size())
	current_environment["layer_ambient_index"] = index
	current_environment["layer_ambient_line"] = str(lines[index])


func _advance_crew_jobs() -> void:
	var action_index := _crew_action_index()
	var expiring_ids: Array = []
	for job_id_value in crew_jobs.keys():
		var job := _crew_job(str(job_id_value))
		if str(job.get("status", "")) == "resolved":
			continue
		var linked_delivery_job_pending := (
			not active_delivery_run.is_empty()
			and str(active_delivery_run.get("job_id", "")) == str(job_id_value)
			and (
				str(active_delivery_run.get("status", "")) == "active"
				or not bool(active_delivery_run.get("world_applied", false))
			)
		)
		if linked_delivery_job_pending:
			continue
		if action_index >= int(job.get("expires_at_action", action_index + 1)):
			expiring_ids.append(str(job_id_value))
	for job_id in expiring_ids:
		var job := _crew_job(str(job_id))
		if str(job.get("status", "")) == "offered":
			job["status"] = "accepted"
			job["accepted_action"] = action_index
			crew_jobs[str(job_id)] = job
		job = _crew_job(str(job_id))
		if str(job.get("status", "")) == "accepted":
			job["status"] = "active"
			job["active_action"] = action_index
			crew_jobs[str(job_id)] = job
		job_resolve(str(job_id), "abandoned", _crew_job_host_capability)


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
	var next_remaining := maxi(0, remaining - amount)
	current_environment["travel_lock_remaining"] = next_remaining
	if next_remaining <= 0:
		current_environment.erase("travel_lock_source")


func _check_police_sweep_boundary() -> Dictionary:
	if town_state == null or current_environment.is_empty() or is_terminal():
		return {}
	var node_id := current_world_node_id()
	if node_id.is_empty() or node_id.begins_with("grand_casino"):
		return {}
	if town_state.sweep_is_at(node_id):
		var rollback: Dictionary = _environment_turn_snapshot()
		town_state.record_sweep_sighting("direct", _world1_host_capability)
		if crew_capability_active("sweep_intel"):
			report_sweep_intel_at_boundary()
		var claim := town_state.claim_sweep_encounter(node_id, _world1_host_capability)
		if claim.is_empty(): return {}
		var proposal := town_state.police_sweep.encounter_proposal(claim, _sweep_cargo_context(), _sweep_exit_node_ids(node_id), _world1_host_capability, crew_capability_active("sweep_intel"))
		var result := _resolve_police_sweep_encounter(claim, _world1_host_capability, proposal)
		if result.is_empty():
			_apply_environment_turn_snapshot(rollback, false)
		return result
	if town_state.sweep_adjacent_sighting_due(node_id):
		var marker := town_state.record_sweep_sighting("adjacent", _world1_host_capability)
		enqueue_triggered_event("police_sweep_adjacent_sighting", "police_sweep", {
			"sweep_marker": marker,
			"node_id": node_id,
		}, {"presentation": "talk"})
		return {"outcome": "adjacent_sighting", "marker": marker}
	return {}


func resolve_police_sweep_encounter_for_test(claim: Dictionary) -> Dictionary:
	var _ignored_claim := claim
	return {}


func resolve_current_police_sweep_encounter() -> Dictionary:
	return _check_police_sweep_boundary()


func _resolve_police_sweep_encounter(claim: Dictionary, host_capability: Variant = null, proposal: Dictionary = {}) -> Dictionary:
	if claim.is_empty() or town_state == null or host_capability == null or host_capability != _world1_host_capability \
			or PoliceSweepModelScript.normalize_encounter_proposal(proposal).is_empty():
		return {}
	var tuning := town_state.sweep_encounter_config()
	var heat := suspicion_level()
	var contraband_ids := _carried_contraband_ids()
	var street_debt_count := _active_street_debt_count()
	var score := _sweep_heat_points(heat, _copy_array(tuning.get("heat_bands", [])))
	score += contraband_ids.size() * maxi(0, int(tuning.get("contraband_points_each", 2)))
	score += street_debt_count * maxi(0, int(tuning.get("street_debt_points_each", 1)))
	var node_id := str(claim.get("node_id", current_world_node_id()))
	var archetype_id := str(current_environment.get("archetype_id", node_id))
	var punchline := node_id == "small_underground_casino" or archetype_id == "small_underground_casino"
	var punchline_threshold := clampi(int(tuning.get("punchline_l2_heat_threshold", 75)), 0, 100)
	var outcome := "pass_over"
	if not punchline:
		if score <= int(tuning.get("pass_over_max_score", 1)):
			outcome = "pass_over"
		elif score <= int(tuning.get("shakedown_max_score", 4)):
			outcome = "shakedown"
		elif score <= int(tuning.get("confiscation_max_score", 7)):
			outcome = "confiscation"
		else:
			outcome = "travel_lock"
	elif heat >= punchline_threshold:
		outcome = "punchline_l2_near_miss"
	var result := {
		"type": "police_sweep_encounter",
		"outcome": outcome,
		"score": score,
		"heat": heat,
		"contraband_count": contraband_ids.size(),
		"street_debt_count": street_debt_count,
		"node_id": node_id,
		"segment_index": int(claim.get("segment_index", -1)),
		"run_continues": true,
		"punchline_layer": 2 if outcome == "punchline_l2_near_miss" else 1 if punchline else 0,
		"encounter_public_state": PoliceSweepModelScript.encounter_public_state(proposal),
	}
	var encounter_rng := RngStream.new()
	var encounter_seed := maxi(1, int(claim.get("encounter_seed", seed_value)))
	encounter_rng.configure(encounter_seed, encounter_seed)
	match outcome:
		"pass_over":
			_apply_sweep_fee_or_delay(
				result,
				tuning.get("pass_over_fee", [2, 6]),
				maxi(1, int(tuning.get("pass_over_fallback_lock_actions", 1))),
				claim,
				encounter_rng
			)
		"shakedown":
			_apply_sweep_fee_or_delay(
				result,
				tuning.get("shakedown_fee", [10, 28]),
				maxi(1, int(tuning.get("shakedown_fallback_lock_actions", 1))),
				claim,
				encounter_rng
			)
		"confiscation":
			if not contraband_ids.is_empty():
				contraband_ids.sort()
				var confiscated_id := str(contraband_ids[encounter_rng.randi_range(0, contraband_ids.size() - 1)])
				if confiscated_id.begins_with("delivery:"):
					active_delivery_run = DeliveryRunModelScript.confiscate(active_delivery_run, "swept")
					_apply_delivery_resolution()
				else:
					remove_item(confiscated_id)
				result["confiscated_item_id"] = confiscated_id
				result["cost_kind"] = "contraband"
				result["cost_amount"] = 1
			else:
				_apply_sweep_fee_or_delay(
					result,
					tuning.get("empty_confiscation_fee", [8, 16]),
					maxi(1, int(tuning.get("empty_confiscation_fallback_lock_actions", 2))),
					claim,
					encounter_rng
				)
		"travel_lock":
			if _sweep_foreign_travel_lock_active():
				_apply_sweep_foreign_lock_cost(result, tuning, encounter_rng, claim)
			else:
				var lock_range := _sweep_int_range(tuning.get("travel_lock_actions", [2, 4]), 2, 4)
				var rolled_lock := encounter_rng.randi_range(int(lock_range[0]), int(lock_range[1]))
				var lock_actions := _apply_sweep_delay(rolled_lock, claim)
				result["travel_lock_actions"] = lock_actions
				result["escape_after_actions"] = lock_actions
				result["cost_kind"] = "travel_delay"
				result["cost_amount"] = lock_actions
		"punchline_l2_near_miss":
			if _sweep_foreign_travel_lock_active():
				_apply_sweep_foreign_lock_cost(result, tuning, encounter_rng, claim)
			else:
				var near_miss_lock := _apply_sweep_delay(maxi(1, int(tuning.get("punchline_near_miss_lock_actions", 2))), claim)
				result["travel_lock_actions"] = near_miss_lock
				result["escape_after_actions"] = near_miss_lock
				result["cost_kind"] = "travel_delay"
				result["cost_amount"] = near_miss_lock
		_:
			pass
	if numbers_state != null and str(result.get("confiscated_item_id", "")).begins_with("delivery:numbers_slips"):
		var swept_bag_value := maxi(0, int(numbers_state.collection_state.get("bag_value", 0)))
		var swept_collection := numbers_state.confiscate_open_slips("collection_sweep")
		var collection_job_id := str(active_delivery_run.get("job_id", ""))
		var swept_heat := maxi(0, int(_copy_dict(NumbersModelScript.tuning().get("runner", {})).get("swept_heat", 14)))
		if swept_heat > 0:
			add_suspicion("numbers_collection_swept", swept_heat, "contraband", true, {"node_id": node_id}, true)
		register_rumor_fact("numbers_whisper", "numbers_collection_swept:%d" % _crew_action_index(), {
			"target_node_id": node_id, "source_id": "numbers_collection_swept", "fact_detail": "the collector lost the whole bag under blue lights",
		})
		result["numbers_collection_confiscated"] = swept_collection
		result["numbers_collection_bag_value_confiscated"] = swept_bag_value
		enqueue_triggered_event("numbers_lucky_swept_collection", "numbers", {
			"bag_value": swept_bag_value,
			"node_id": node_id,
			"job_id": collection_job_id,
		}, {"presentation": "talk"})
	if str(result.get("confiscated_item_id", "")) == "numbers_slips" and numbers_state != null:
		result["numbers_slips_confiscated"] = numbers_state.confiscate_open_slips("police_sweep")
	_sync_numbers_inventory_marker()
	var tombstone := town_state.police_sweep.record_encounter_resolution(_world1_host_capability, claim, outcome, str(result.get("cost_kind", "")), int(result.get("cost_amount", -1)))
	if tombstone.is_empty():
		return {}
	result["encounter_tombstone"] = tombstone
	var event_id := "police_sweep_%s" % outcome
	enqueue_triggered_event(event_id, "police_sweep", result, {"presentation": "talk"})
	log_story(result)
	return result


func _sweep_cargo_context() -> Dictionary:
	if delivery_has_active_run():
		var snapshot := delivery_snapshot()
		var physical := _copy_dict(snapshot.get("physical", {}))
		if str(physical.get("cargo_state", "")) == "carried":
			return {"cargo_id": "delivery:%s" % str(active_delivery_run.get("cargo_id", "cargo")), "cargo_label": str(active_delivery_run.get("cargo_label", "Delivery cargo")), "contraband": bool(snapshot.get("carrying_contraband", false))}
	var contraband := _carried_contraband_ids()
	if not contraband.is_empty():
		contraband.sort()
		return {"cargo_id": str(contraband[0]), "cargo_label": str(contraband[0]).replace("_", " ").capitalize(), "contraband": true}
	return {}


func _sweep_exit_node_ids(node_id: String) -> Array:
	var result: Array = []
	for edge_value in _copy_array(world_map.get("edges", [])):
		var edge := _copy_dict(edge_value)
		var a := str(edge.get("a", "")); var b := str(edge.get("b", ""))
		var exit_id := b if a == node_id else a if b == node_id else ""
		if not exit_id.is_empty() and not result.has(exit_id): result.append(exit_id)
	result.sort()
	return result


func _sweep_heat_points(heat: int, bands: Array) -> int:
	for band_value in bands:
		if typeof(band_value) != TYPE_DICTIONARY:
			continue
		var band: Dictionary = band_value
		if heat <= int(band.get("max", 100)):
			return maxi(0, int(band.get("points", 0)))
	return 0


func _apply_sweep_fee_or_delay(result: Dictionary, fee_value: Variant, fallback_lock_actions: int, claim: Dictionary, rng: RngStream) -> void:
	var fee_range := _sweep_int_range(fee_value, 1, 1)
	var quoted_fee := rng.randi_range(int(fee_range[0]), int(fee_range[1]))
	var paid := mini(quoted_fee, maxi(0, bankroll - 1))
	if paid > 0:
		change_bankroll(-paid)
		result["fee"] = paid
		result["cost_kind"] = "cash"
		result["cost_amount"] = paid
		return
	if _sweep_foreign_travel_lock_active():
		_apply_sweep_foreign_lock_cost(result, town_state.sweep_encounter_config(), rng, claim)
		return
	var lock_actions := _apply_sweep_delay(maxi(1, fallback_lock_actions), claim)
	result["fee"] = 0
	result["travel_lock_actions"] = lock_actions
	result["escape_after_actions"] = lock_actions
	result["cost_kind"] = "travel_delay"
	result["cost_amount"] = lock_actions


func _sweep_foreign_travel_lock_active() -> bool:
	return maxi(0, int(current_environment.get("travel_lock_remaining", 0))) > 0 \
		and str(current_environment.get("travel_lock_source", "")) != "police_sweep"


func _apply_sweep_foreign_lock_cost(result: Dictionary, tuning: Dictionary, rng: RngStream, claim: Dictionary) -> void:
	var fine_range := _sweep_int_range(tuning.get("occupied_lock_fine", [6, 12]), 6, 12)
	var fine := rng.randi_range(int(fine_range[0]), int(fine_range[1]))
	var paid := mini(fine, maxi(0, bankroll - 1))
	result["foreign_lock_preserved"] = true
	if paid > 0:
		change_bankroll(-paid)
		result["fee"] = paid
		result["cost_kind"] = "cash"
		result["cost_amount"] = paid
		return
	var debt_id := "police_sweep_fine_%d_%d" % [int(claim.get("segment_index", 0)), int(claim.get("action_index", town_state.action_index))]
	add_debt({
		"id": debt_id,
		"lender_id": "police_sweep",
		"debt_kind": "cash",
		"principal": fine,
		"balance": fine,
		"status": "active",
		"source_location_id": current_world_node_id(),
	})
	result["debt_id"] = debt_id
	result["cost_kind"] = "street_debt"
	result["cost_amount"] = fine


func _apply_sweep_delay(requested_actions: int, claim: Dictionary) -> int:
	var until_departure := maxi(1, int(claim.get("sweep_departure_action", town_state.action_index + 1)) - int(town_state.action_index))
	var lock_actions := mini(maxi(1, requested_actions), until_departure)
	current_environment["travel_locked_actions"] = maxi(int(current_environment.get("travel_locked_actions", 0)), lock_actions)
	current_environment["travel_lock_remaining"] = maxi(int(current_environment.get("travel_lock_remaining", 0)), lock_actions)
	current_environment["travel_lock_source"] = "police_sweep"
	return lock_actions


func _sweep_int_range(value: Variant, fallback_min: int, fallback_max: int) -> Array:
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
		var first := int((value as Array)[0])
		var second := int((value as Array)[1])
		return [mini(first, second), maxi(first, second)]
	return [mini(fallback_min, fallback_max), maxi(fallback_min, fallback_max)]


func _carried_contraband_ids() -> Array:
	var definitions := _item_definition_index()
	var result: Array = []
	for inventory_entry in inventory:
		var item_id := _inventory_item_id(inventory_entry)
		var definition := _copy_dict(definitions.get(item_id, {}))
		var risk_flags := _string_array(_copy_array(definition.get("risk_flags", [])))
		if str(definition.get("class", "")).strip_edges().to_lower() == "contraband" or risk_flags.has("contraband"):
			result.append(item_id)
	if delivery_has_active_run() and bool(delivery_snapshot().get("carrying_contraband", false)):
		result.append("delivery:%s" % str(active_delivery_run.get("cargo_id", "cargo")))
	return result


func _active_street_debt_count() -> int:
	var count := 0
	for debt_value in debt:
		if typeof(debt_value) != TYPE_DICTIONARY:
			continue
		var debt_data: Dictionary = debt_value
		if str(debt_data.get("debt_kind", "")) == "casino_marker":
			continue
		if ["active", "overdue", "favor_due"].has(str(debt_data.get("status", "active"))):
			count += 1
	return count


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
		if str(debt_data.get("debt_kind", "")) == "casino_marker" or bool(debt_data.get("no_default", false)):
			continue
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
	if str(debt_data.get("debt_kind", "")) == "casino_marker":
		return
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


func _crew_debt_lead_member(debt_data: Dictionary) -> String:
	for member_value in _copy_array(debt_data.get("crew_member_ids", [])):
		var member_id := str(member_value)
		if CrewStateModelScript.MEMBER_IDS.has(member_id):
			return member_id
	return "crew_rook"


func _crew_job(job_id: String) -> Dictionary:
	var value: Variant = crew_jobs.get(job_id, {})
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func _crew_action_index() -> int:
	return maxi(0, int(event_cadence.get("action_index", 0)))


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
	# Conversations belong to the live run. Event producers can finish their
	# action after a terminal result has already been committed, so reject a late
	# talk enqueue at the source instead of letting it leak onto the run report.
	if is_terminal() and str(entry_overrides.get("presentation", "modal")) == "talk":
		return false
	if str(active_triggered_event.get("event_id", "")) == normalized_id:
		return false
	for entry_value in pending_triggered_events:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("event_id", "")) == normalized_id:
			return false
	if pending_triggered_events.size() >= MAX_PENDING_TRIGGERED_EVENTS:
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
	# During the guided run, Pal's currently active instruction must resume ahead
	# of unrelated ambient conversations that happened to enqueue on the same
	# action boundary. The queue itself is left intact: once the guide beat is
	# resolved, the natural conversation is still available and proceeds next.
	# Normal runs retain strict insertion order.
	if is_tutorial_run():
		for entry_value in pending_triggered_events:
			var intervention_entry := _normalize_triggered_event_entry(entry_value)
			var intervention_context: Dictionary = intervention_entry.get("context", {}) if typeof(intervention_entry.get("context", {})) == TYPE_DICTIONARY else {}
			var intervention_source := str(intervention_entry.get("source", intervention_context.get("source", "")))
			if str(intervention_entry.get("presentation", "modal")) == "talk" and intervention_source == "tutorial_intervention":
				return intervention_entry
		# Applying the family loan creates debt before the shared dialogue queue is
		# refreshed. If an older save already queued Pal's debt explanation at that
		# boundary, keep the actual phone offer in front of the explanation.
		var family_loan_entry: Dictionary = {}
		var family_debt_guide_pending := false
		for entry_value in pending_triggered_events:
			var ordered_entry := _normalize_triggered_event_entry(entry_value)
			if str(ordered_entry.get("presentation", "modal")) != "talk":
				continue
			var ordered_event_id := str(ordered_entry.get("event_id", ""))
			if ordered_event_id == "family_loan":
				family_loan_entry = ordered_entry
			elif ordered_event_id == "tutorial_guide:tutorial_family_debt":
				family_debt_guide_pending = true
		if not family_loan_entry.is_empty() and family_debt_guide_pending:
			return family_loan_entry
		for entry_value in pending_triggered_events:
			var tutorial_entry := _normalize_triggered_event_entry(entry_value)
			var tutorial_context: Dictionary = tutorial_entry.get("context", {}) if typeof(tutorial_entry.get("context", {})) == TYPE_DICTIONARY else {}
			var is_guide_entry := str(tutorial_entry.get("source", "")) == "tutorial_guide" \
				or str(tutorial_context.get("source", "")) == "tutorial_guide" \
				or not str(tutorial_context.get("tutorial_lesson_id", "")).strip_edges().is_empty()
			if str(tutorial_entry.get("presentation", "modal")) == "talk" and is_guide_entry:
				return tutorial_entry
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


# Retires every unresolved conversation without applying its choices. Terminal
# runs no longer have a gameplay context in which those choices can be made;
# non-talk triggered events remain intact for save/report history compatibility.
func retire_pending_talk_events() -> int:
	var retired_count := 0
	for index in range(pending_triggered_events.size() - 1, -1, -1):
		var entry := _normalize_triggered_event_entry(pending_triggered_events[index])
		if str(entry.get("presentation", "modal")) != "talk":
			continue
		pending_triggered_events.remove_at(index)
		retired_count += 1
	return retired_count


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
	if pending_bags.size() >= MAX_PENDING_BAG_MARKERS:
		return {}
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
	if run_failure_reason == FAILURE_CASINO_TAKEN_OUT_BACK:
		record_reputation_incident("thrown_out", current_world_node_id(), 1.0, {"reason": run_failure_reason})
	retire_pending_talk_events()
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
		_scenario_publish_heat_change(previous_level, next_level - previous_level, "cooldown")
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
	if _crew_heist_capture_whale_attention():
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
	var result := {
		"seed_text": seed_text,
		"seed_value": seed_value,
		"rng_seed": rng_seed,
		"rng_state": rng_state,
		"challenge_config": challenge_config.duplicate(true),
		"bankroll": bankroll,
		"grand_casino_chips": grand_casino_chips,
		"grand_casino_atm_debt": grand_casino_atm_debt(),
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
		# Player-owned ticket state is serialized once in portable_ticket_piles.
		# The current/world-node machine copies retain only location-owned stock.
		"current_environment": _environment_for_persistent_storage(current_environment),
		"world_map": _compact_world_map_ticket_storage(WorldMap.normalize(world_map)),
		"scenario_state_schema_version": ScenarioEngineScript.STATE_SCHEMA_VERSION,
		"scenario_recent_by_archetype": scenario_recent_by_archetype.duplicate(true),
		"grand_casino_room_states": _grand_casino_room_states_for_save(),
		"grand_casino_staffing": grand_casino_staffing.duplicate(true),
		"rourke_current_room": rourke_current_room,
		"rourke_current_spot": rourke_current_spot,
		"rourke_facing": rourke_facing,
		"rourke_actions_until_move": rourke_actions_until_move,
		"rourke_off_floor_actions": rourke_off_floor_actions,
		"rourke_floor_action_index": rourke_floor_action_index,
		"linda_cage_state": linda_cage_snapshot(),
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
		# Every serialized projection is observer-safe. Hidden Turn authority and
		# grievances live only in the authenticated fixed-size private capsule.
		"crew_state": _crew_state_for_save(true, false),
		"scenario_host_transaction_ledger": scenario_host_transaction_ledger.duplicate(true),
		"active_delivery_run": active_delivery_run.duplicate(true),
		"numbers_state": numbers_state.snapshot() if numbers_state != null else {},
		"heat_history": normalize_heat_history(heat_history),
		"town_state": town_state.snapshot() if town_state != null else {},
		"simulation_msec": simulation_msec,
		"game_clock_minutes": game_clock_minutes,
		"grand_casino_atm_interest_boundary_index": grand_casino_atm_interest_boundary_index,
		"grand_casino_atm_interest_notifications": grand_casino_atm_interest_notifications.duplicate(true),
		"closing_time_state": _normalize_closing_time_state(closing_time_state),
		"act": act_marker(),
		"act_index": act_marker(),
		"home_state": _normalize_home_state(home_state),
		"run_status": run_status,
		"run_failure_reason": run_failure_reason,
		"run_failure_message": run_failure_message,
		"run_spending_score": run_spending_score,
	}
	if scenario_host_transaction_ledger.is_empty():
		result.erase("scenario_host_transaction_ledger")
	if not world_sequence_registrations.is_empty(): result["world_sequence_registrations"] = world_sequence_registrations.duplicate(true)
	return result


func world_sequence_preview_delivery_outcome(token: String, outcome: String = "delivered") -> Dictionary:
	var registration := _copy_dict(world_sequence_registrations.get(token, {}))
	if registration.is_empty(): return {"ok": false, "errors": ["world sequence delivery registration is missing"]}
	return CrewWorldSequenceAdapterScript.preview_outcome(current_environment, token, _world_sequence_definition(token), outcome, _world_sequence_delivery_owner_cause(token, outcome))


func world_sequence_commit_delivery_outcome(token: String, node_id: String = "") -> Dictionary:
	var checkpointed := world_sequence_checkpoint_delivery_outcome(token, node_id)
	if not bool(checkpointed.get("ok", false)): return checkpointed
	var materialized := world_sequence_materialize_delivery_checkpoint(token)
	if not bool(materialized.get("ok", false)): return materialized
	return checkpointed


func world_sequence_checkpoint_delivery_outcome(token: String, node_id: String = "") -> Dictionary:
	var preview := world_sequence_preview_delivery_outcome(token, "delivered")
	if not bool(preview.get("ok", false)): return preview
	var target_id := node_id.strip_edges()
	if target_id.is_empty(): target_id = current_world_node_id()
	if not delivery_has_active_run(): return {"ok": false, "errors": ["delivery owner is not active at the terminal handoff"]}
	var before := JSON.stringify(delivery_snapshot())
	active_delivery_run = DeliveryRunModelScript.complete_handoff(active_delivery_run, target_id)
	if JSON.stringify(delivery_snapshot()) == before or str(active_delivery_run.get("status", "")) != "resolved":
		return {"ok": false, "errors": ["delivery owner rejected the terminal handoff"]}
	var applied := _apply_delivery_resolution(_copy_dict(preview.get("receipt", {})), false)
	if not bool(applied.get("ok", false)): return applied
	return {"ok": true, "resolved": true, "message": str(_copy_dict(applied.get("public_result", {})).get("message", "")), "public_result": _copy_dict(applied.get("public_result", {})), "errors": []}


func world_sequence_materialize_delivery_checkpoint(token: String) -> Dictionary:
	var checkpoint := DeliveryRunModelScript.closed_checkpoint(active_delivery_run)
	if checkpoint.is_empty() or str(checkpoint.get("owner_token", "")) != token:
		return {"ok": true, "inactive": true, "errors": []}
	var expected_receipt := {
		"receipt_id": str(checkpoint.get("outcome_receipt_id", "")),
		"owner_token": str(checkpoint.get("owner_token", "")),
		"public_instance_token": str(checkpoint.get("public_instance_token", "")),
		"channel_id": "delivery_handoff",
		"outcome": _delivery_checkpoint_outcome(),
		"cause_fingerprint": str(checkpoint.get("outcome_cause_fingerprint", "")),
		"receipt_fingerprint": str(checkpoint.get("outcome_receipt_fingerprint", "")),
	}
	var checkpoint_errors := DeliveryRunModelScript.closed_checkpoint_errors(active_delivery_run, _world_sequence_delivery_binding(expected_receipt))
	if not checkpoint_errors.is_empty(): return {"ok": false, "errors": checkpoint_errors}
	var confirmed := CrewWorldSequenceAdapterScript.confirm_outcome(current_environment, token, _world_sequence_definition(token), expected_receipt, _world_sequence_delivery_owner_cause(token, str(expected_receipt.get("outcome", ""))))
	if bool(confirmed.get("ok", false)): _refresh_world_sequence_registration(token, false)
	return confirmed


func world_sequence_resume_delivery_checkpoint() -> Dictionary:
	var checkpoint := DeliveryRunModelScript.closed_checkpoint(active_delivery_run)
	if checkpoint.is_empty(): return {"ok": true, "inactive": true, "errors": []}
	var token := str(checkpoint.get("owner_token", ""))
	var registration := _copy_dict(world_sequence_registrations.get(token, {}))
	if str(registration.get("lifecycle", "")) == "cleaned" and _copy_dict(registration.get("outcome_acknowledgements", {})).has(str(checkpoint.get("outcome_receipt_id", ""))):
		return {"ok": true, "inactive": true, "errors": []}
	return world_sequence_materialize_delivery_checkpoint(token)


# Captures a worker-safe save generation without first deep-copying duplicated
# current/map/room environment graphs. Slot/environment writers replace their
# top-level maps, while this snapshot owns each mutable root container. The v2
# codec is non-mutating and performs the final compact deep projection on the
# worker.
func to_save_snapshot(deep_copy_seeded_scenario_definitions: bool = true) -> Dictionary:
	var result := {
		"seed_text": seed_text,
		"seed_value": seed_value,
		"rng_seed": rng_seed,
		"rng_state": rng_state,
		"challenge_config": challenge_config.duplicate(false),
		"bankroll": bankroll,
		"grand_casino_chips": grand_casino_chips,
		"grand_casino_atm_debt": grand_casino_atm_debt(),
		"economic_state": economic_state,
		"inventory": inventory.duplicate(false),
		"portable_ticket_piles": portable_ticket_piles.duplicate(false),
		"active_item_id": active_item_id,
		"debt": debt.duplicate(false),
		"sals_forfeited_item_ids": sals_forfeited_item_ids.duplicate(false),
		"suspicion": suspicion.duplicate(false),
		"baseline_luck": baseline_luck,
		"drunk_level": drunk_level,
		"alcoholic_level": alcoholic_level,
		"pending_drunk_absorption": pending_drunk_absorption.duplicate(false),
		"drunk_distortion_suppression_turns": drunk_distortion_suppression_turns,
		"current_environment": _environment_for_persistent_storage(current_environment, false),
		"world_map": _world_map_for_save_snapshot(world_map),
		"scenario_state_schema_version": ScenarioEngineScript.STATE_SCHEMA_VERSION,
		"scenario_recent_by_archetype": scenario_recent_by_archetype.duplicate(false),
		"grand_casino_room_states": _grand_casino_room_states_for_save(false),
		"grand_casino_staffing": grand_casino_staffing.duplicate(false),
		"rourke_current_room": rourke_current_room,
		"rourke_current_spot": rourke_current_spot,
		"rourke_facing": rourke_facing,
		"rourke_actions_until_move": rourke_actions_until_move,
		"rourke_off_floor_actions": rourke_off_floor_actions,
		"rourke_floor_action_index": rourke_floor_action_index,
		"linda_cage_state": linda_cage_state.duplicate(false),
		"grand_casino_room_heat_accumulators": grand_casino_room_heat_accumulators.duplicate(false),
		"rival_cheaters": rival_cheaters.duplicate(false),
		"rival_cheater_day": rival_cheater_day,
		"rourke_escort_state": rourke_escort_state.duplicate(false),
		"pending_triggered_events": pending_triggered_events.duplicate(true),
		"pending_bags": pending_bags.duplicate(true),
		"active_triggered_event": active_triggered_event.duplicate(true),
		"event_cadence": event_cadence.duplicate(false),
		"music_arrangement_state": music_arrangement_state.duplicate(false),
		"music_tempo_state": music_tempo_state.duplicate(false),
		"music_choreography_state": music_choreography_state.duplicate(false),
		"environment_history": environment_history.duplicate(false),
		"environment_history_archive_count": environment_history_archive_count,
		"unlocked_travel": unlocked_travel.duplicate(false),
		"narrative_flags": narrative_flags.duplicate(false),
		"story_flags": story_flags.duplicate(false),
		"story_log": story_log.duplicate(false),
		"story_log_archive_count": story_log_archive_count,
		"crew_state": _crew_state_for_save(false, true),
		"scenario_host_transaction_ledger": scenario_host_transaction_ledger.duplicate(true),
		"active_delivery_run": active_delivery_run.duplicate(false),
		"numbers_state": numbers_state.snapshot() if numbers_state != null else {},
		"heat_history": heat_history.duplicate(false),
		"town_state": town_state.snapshot(deep_copy_seeded_scenario_definitions) if town_state != null else {},
		"simulation_msec": simulation_msec,
		"game_clock_minutes": game_clock_minutes,
		"grand_casino_atm_interest_boundary_index": grand_casino_atm_interest_boundary_index,
		"grand_casino_atm_interest_notifications": grand_casino_atm_interest_notifications.duplicate(false),
		"closing_time_state": closing_time_state.duplicate(false),
		"act": act_marker(),
		"act_index": act_marker(),
		"home_state": home_state.duplicate(false),
		"run_status": run_status,
		"run_failure_reason": run_failure_reason,
		"run_failure_message": run_failure_message,
		"run_spending_score": run_spending_score,
	}
	if scenario_host_transaction_ledger.is_empty():
		result.erase("scenario_host_transaction_ledger")
	if not world_sequence_registrations.is_empty(): result["world_sequence_registrations"] = world_sequence_registrations.duplicate(false)
	return result


# Restores the run from saved data.
func from_dict(data: Dictionary) -> void:
	_scenario_sequence_definition_cache = {}
	_world_sequence_definition_cache = {}
	world_sequence_registrations = _normalize_world_sequence_registrations(data.get("world_sequence_registrations", {}))
	var saved_crew_state: Dictionary = data.get("crew_state", {}) if typeof(data.get("crew_state", {})) == TYPE_DICTIONARY else {}
	var legacy_streets_migration := _copy_dict(data.get("active_streets_run", {}))
	seed_text = str(data.get("seed_text", "FOUNDATION-SEED"))
	seed_value = int(data.get("seed_value", text_to_seed(seed_text)))
	rng_seed = int(data.get("rng_seed", seed_value))
	rng_state = int(data.get("rng_state", rng_seed))
	challenge_config = normalize_challenge(seed_text, _copy_dict(data.get("challenge_config", standard_challenge(seed_text))))
	_world1_host_capability = RefCounted.new()
	_crew_heist_host_capability = RefCounted.new()
	town_state = TownStateScript.new()
	town_state.bind_host_capability(_world1_host_capability)
	var saved_town_value: Variant = data.get("town_state", {})
	if typeof(saved_town_value) != TYPE_DICTIONARY or (saved_town_value as Dictionary).is_empty():
		town_state.generate(seed_value)
		town_state.disable_police_sweep_for_legacy_save()
		print("RUN_SAVE_MIGRATION town_state regenerated from seed for a pre-0.6 save.")
	else:
		town_state.restore(saved_town_value as Dictionary, seed_value)
	bankroll = int(data.get("bankroll", DEFAULT_BANKROLL))
	grand_casino_chips = maxi(0, int(data.get("grand_casino_chips", 0)))
	economic_state = str(data.get("economic_state", "stable"))
	inventory = _normalize_inventory_entries(data.get("inventory", []))
	invalidate_inventory_effect_cache()
	portable_ticket_piles = _normalize_portable_ticket_piles(_copy_dict(data.get("portable_ticket_piles", {})))
	active_item_id = str(data.get("active_item_id", ""))
	if not inventory.has(active_item_id):
		active_item_id = ""
	debt = _normalize_debt_entries(_copy_array(data.get("debt", [])))
	if _debt_index(CageEconomyModelScript.ATM_DEBT_ID) < 0 and int(data.get("grand_casino_atm_debt", 0)) > 0:
		_set_grand_casino_atm_debt(int(data.get("grand_casino_atm_debt", 0)))
	sals_forfeited_item_ids = _string_array(_copy_array(data.get("sals_forfeited_item_ids", [])))
	suspicion = _normalize_suspicion(_copy_dict(data.get("suspicion", {"level": 0, "cues": []})))
	baseline_luck = clampi(int(data.get("baseline_luck", 0)), BASELINE_LUCK_MIN, BASELINE_LUCK_MAX)
	drunk_level = clampi(int(data.get("drunk_level", 0)), 0, ALCOHOL_MAX)
	alcoholic_level = clampi(int(data.get("alcoholic_level", 0)), 0, ALCOHOL_MAX)
	pending_drunk_absorption = _normalize_pending_drunk_absorption(_copy_array(data.get("pending_drunk_absorption", [])))
	drunk_distortion_suppression_turns = maxi(0, int(data.get("drunk_distortion_suppression_turns", 0)))
	current_environment = _normalize_environment(_copy_dict(data.get("current_environment", {})))
	_reconcile_blackjack_authority_restore()
	_mark_scenario_restore_pending_trusted_rebuild(current_environment)
	scenario_host_transaction_ledger = _copy_dict(data.get("scenario_host_transaction_ledger", {}))
	# Import current-room machine ownership from pre-portable saves, then make
	# the portable record authoritative for the restored surface.
	capture_portable_ticket_piles_from_environment(current_environment, true)
	restore_portable_ticket_piles_to_environment(current_environment)
	_sync_portable_ticket_inventory_markers()
	_apply_sals_forfeited_shelf_to_current_environment()
	world_map = _normalize_world_map_environment_snapshots(
		_compact_world_map_ticket_storage(WorldMap.normalize(_copy_dict(data.get("world_map", {}))))
	)
	# Restored town state is authoritative. Discovery facts are registered on
	# fresh world generation, never injected during a byte-identical restore.
	configure_town_world(world_map, false)
	scenario_recent_by_archetype = _normalize_scenario_recent(_copy_dict(data.get("scenario_recent_by_archetype", {})))
	grand_casino_room_states = _normalize_grand_casino_room_states(_copy_dict(data.get("grand_casino_room_states", {})))
	migrate_legacy_scenario_sequences()
	grand_casino_staffing = _normalize_grand_casino_staffing(_copy_dict(data.get("grand_casino_staffing", {})))
	rourke_current_room = _normalize_grand_casino_room_id(str(data.get("rourke_current_room", "")))
	rourke_current_spot = str(data.get("rourke_current_spot", "")).strip_edges()
	rourke_facing = "left" if str(data.get("rourke_facing", "right")) == "left" else "right"
	rourke_actions_until_move = clampi(int(data.get("rourke_actions_until_move", ROURKE_MOVE_EVALUATION_ACTIONS)), 0, ROURKE_MOVE_EVALUATION_ACTIONS)
	rourke_off_floor_actions = clampi(int(data.get("rourke_off_floor_actions", 0)), 0, ROURKE_OFF_FLOOR_ACTIONS)
	rourke_floor_action_index = maxi(0, int(data.get("rourke_floor_action_index", 0)))
	linda_cage_state = _normalize_linda_cage_state(_copy_dict(data.get("linda_cage_state", {})))
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
	_restore_crew_state(saved_crew_state, not data.has("crew_state"))
	active_delivery_run = DeliveryRunModelScript.bind_legacy_position(
		DeliveryRunModelScript.normalize_state(data.get("active_delivery_run", {})),
		current_world_node_id()
	)
	_numbers_host_capability = RefCounted.new()
	numbers_state = _new_numbers_model()
	var saved_numbers_value: Variant = data.get("numbers_state", {})
	if typeof(saved_numbers_value) == TYPE_DICTIONARY and not (saved_numbers_value as Dictionary).is_empty():
		numbers_state.restore(saved_numbers_value as Dictionary, seed_value)
	else:
		numbers_state.reset(seed_value)
		numbers_state.advance_to(_crew_action_index())
	_sync_numbers_inventory_marker()
	for story_flag_key in story_flags.keys():
		narrative_flags[str(story_flag_key)] = story_flags[story_flag_key]
	# Repair saves made before Tier-2 casino spawning had an explicit progression
	# milestone. The visited-node state is already authoritative.
	_reconcile_tier_two_casino_spawn_eligibility()
	_reconcile_grand_casino_invitation_uniqueness()
	story_log_archive_count = maxi(0, int(data.get("story_log_archive_count", 0)))
	story_log = _normalize_story_log(_copy_array(data.get("story_log", [])))
	for story_entry_value in story_log:
		if typeof(story_entry_value) == TYPE_DICTIONARY:
			_remember_story_seen_flags(story_entry_value as Dictionary)
	_compact_story_log()
	if active_delivery_run.is_empty() and not legacy_streets_migration.is_empty():
		_migrate_legacy_streets_run(legacy_streets_migration)
	# Restore the authoritative clock before synthesizing any missing timeline
	# sample. Older saves without heat history must not receive a fake Day-1 row.
	game_clock_minutes = maxi(0, int(data.get("game_clock_minutes", GAME_CLOCK_START_MINUTE)))
	heat_history = normalize_heat_history(_copy_array(data.get("heat_history", [])))
	if heat_history.is_empty():
		_record_heat_history(not current_environment.is_empty())
	_compact_heat_history()
	simulation_msec = maxi(0, int(data.get("simulation_msec", int(_copy_dict(data.get("event_cadence", {})).get("action_index", 0)) * SIMULATION_ACTION_MSEC)))
	if bool(narrative_flags.get("grand_casino_showdown_active", false)) and str(narrative_flags.get("grand_casino_showdown_step", "")) == GRAND_CASINO_SHOWDOWN_STEP_LEGACY_CHECK and not _copy_dict(narrative_flags.get("grand_casino_duel_terms", {})).is_empty():
		_begin_grand_casino_duel(_copy_dict(narrative_flags.get("grand_casino_duel_terms", {})))
	grand_casino_atm_interest_boundary_index = int(data.get(
		"grand_casino_atm_interest_boundary_index",
		CageEconomyModelScript.boundary_index_at_or_before(game_clock_minutes)
	))
	grand_casino_atm_interest_notifications = _copy_array(data.get("grand_casino_atm_interest_notifications", []))
	if grand_casino_atm_interest_notifications.size() > MAX_ATM_INTEREST_NOTIFICATIONS:
		grand_casino_atm_interest_notifications = grand_casino_atm_interest_notifications.slice(
			grand_casino_atm_interest_notifications.size() - MAX_ATM_INTEREST_NOTIFICATIONS,
			grand_casino_atm_interest_notifications.size()
		)
	closing_time_state = _normalize_closing_time_state(_copy_dict(data.get("closing_time_state", {})))
	act_index = maxi(1, int(data.get("act", data.get("act_index", 1))))
	home_state = _normalize_home_state(_copy_dict(data.get("home_state", {})))
	var saved_run_status := str(data.get("run_status", RUN_STATUS_ACTIVE))
	run_status = saved_run_status
	run_failure_reason = str(data.get("run_failure_reason", FAILURE_NONE))
	run_failure_message = str(data.get("run_failure_message", ""))
	run_spending_score = maxi(0, int(data.get("run_spending_score", 0)))
	var blackjack_unsettled_wager := _blackjack_authority_has_unsettled_wager()
	_refresh_economy(blackjack_unsettled_wager)
	_activate_current_local_suspicion(true)
	_initialize_grand_casino_objective_runtime()
	_initialize_grand_casino_staffing()
	_initialize_grand_casino_living_floor()
	if saved_run_status != RUN_STATUS_ENDED and saved_run_status != RUN_STATUS_FAILED:
		_evaluate_immediate_terminal_state(blackjack_unsettled_wager)
	if saved_run_status == RUN_STATUS_ENDED:
		run_status = saved_run_status
	elif saved_run_status == RUN_STATUS_FAILED:
		run_status = saved_run_status
		if run_failure_reason.strip_edges().is_empty():
			run_failure_reason = FAILURE_BANKROLL_ZERO if bankroll <= 0 else FAILURE_STRANDED
		if run_failure_message.strip_edges().is_empty():
			run_failure_message = _failure_message_for_reason(run_failure_reason)
	if run_status == RUN_STATUS_ENDED or run_status == RUN_STATUS_FAILED:
		retire_pending_talk_events()


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


static func _environment_for_persistent_storage(environment: Dictionary, deep_copy: bool = true) -> Dictionary:
	if environment.is_empty():
		return {}
	var stored: Dictionary = {}
	for key_value in environment.keys():
		var key := str(key_value)
		if key == "game_states" or key == "active_game_id" or key == ScenarioEngineScript.TRUSTED_STATE_REFERENCE_KEY or key == ScenarioEngineScript.TRUSTED_LAYOUT_INPUT_DIGEST_KEY:
			continue
		stored[key] = _persistent_copy_value(environment.get(key_value)) if deep_copy else environment.get(key_value)
	var states_value: Variant = environment.get("game_states", {})
	if typeof(states_value) != TYPE_DICTIONARY:
		_strip_scenario_semantic_ephemera(stored)
		_strip_persistent_active_game_bindings(stored)
		return stored
	var stored_states: Dictionary = {}
	for game_key_value in (states_value as Dictionary).keys():
		var game_key := str(game_key_value)
		var state_value: Variant = (states_value as Dictionary).get(game_key_value)
		if PORTABLE_TICKET_KINDS.has(game_key) and typeof(state_value) == TYPE_DICTIONARY:
			var machine: Dictionary = state_value as Dictionary
			var stored_machine: Dictionary = {}
			var player_fields: Array = PORTABLE_TICKET_PLAYER_FIELDS.get(game_key, [])
			for field_value in machine.keys():
				var field := str(field_value)
				if player_fields.has(field):
					continue
				stored_machine[field] = _persistent_copy_value(machine.get(field_value)) if deep_copy else machine.get(field_value)
			stored_states[game_key] = stored_machine
		else:
			stored_states[game_key] = _persistent_copy_value(state_value) if deep_copy else state_value
	stored["game_states"] = stored_states
	_strip_scenario_semantic_ephemera(stored)
	_strip_persistent_active_game_bindings(stored)
	return stored


static func _strip_persistent_active_game_bindings(environment: Dictionary) -> void:
	# This Foundation-to-game capability exists only while its surface is live.
	# Scrub nested venue-layer snapshots as well as the current room projection.
	environment.erase("active_game_id")
	var layer_states := _copy_dict(environment.get("layer_states", {}))
	for layer_id_value in layer_states.keys():
		var layer_body := _copy_dict(layer_states.get(layer_id_value, {}))
		layer_body.erase("layer_states")
		_strip_persistent_active_game_bindings(layer_body)
		layer_states[layer_id_value] = layer_body
	if not layer_states.is_empty():
		environment["layer_states"] = layer_states


static func _strip_scenario_semantic_ephemera(environment: Dictionary) -> void:
	# ENV06_6B_SEMANTIC_RESTORE_EQUIVALENCE_V1 persists every causal and
	# authority-bearing field exactly. Only named presentation projections and
	# caches are rebuilt from those trusted bytes after restore.
	for key in SCENARIO_DERIVED_NONCAUSAL_ENVIRONMENT_FIELDS:
		environment.erase(key)
	environment.erase(ScenarioEngineScript.TRUSTED_STATE_REFERENCE_KEY)
	environment.erase(ScenarioEngineScript.TRUSTED_LAYOUT_INPUT_DIGEST_KEY)
	var state := _copy_dict(environment.get("scenario_sequence_state", {}))
	if not state.is_empty():
		environment["scenario_sequence_state"] = state
		environment["scenario_restore_contract"] = ENV06_6B_SEMANTIC_RESTORE_EQUIVALENCE_V1
	if environment.has("scenario_sequence_state"):
		environment["scenario_sequence_pending_visit_id"] = str(environment.get("environment_visit_id", environment.get("scenario_sequence_pending_visit_id", "")))
	else:
		environment.erase("scenario_sequence_pending_visit_id")
		environment.erase("scenario_restore_contract")
	if environment.has(CrewWorldSequenceAdapterScript.CONTAINER_KEY):
		var world_instances := CrewWorldSequenceAdapterScript.durable_container(environment.get(CrewWorldSequenceAdapterScript.CONTAINER_KEY, {}))
		if world_instances.is_empty(): environment.erase(CrewWorldSequenceAdapterScript.CONTAINER_KEY)
		else: environment[CrewWorldSequenceAdapterScript.CONTAINER_KEY] = world_instances
	var layer_states := _copy_dict(environment.get("layer_states", {}))
	if not layer_states.is_empty():
		for layer_id_value in layer_states.keys():
			var layer_body := _copy_dict(layer_states.get(layer_id_value, {}))
			layer_body.erase("layer_states")
			_strip_scenario_semantic_ephemera(layer_body)
			layer_states[layer_id_value] = layer_body
		environment["layer_states"] = layer_states


static func _mark_scenario_restore_pending_trusted_rebuild(environment: Dictionary) -> void:
	if not _copy_dict(environment.get("scenario_sequence_state", {})).is_empty():
		environment["scenario_restore_pending_trusted_rebuild"] = true
	var layer_states := _copy_dict(environment.get("layer_states", {}))
	for layer_id_value in layer_states.keys():
		var layer_body := _copy_dict(layer_states.get(layer_id_value, {}))
		_mark_scenario_restore_pending_trusted_rebuild(layer_body)
		layer_states[layer_id_value] = layer_body
	if not layer_states.is_empty():
		environment["layer_states"] = layer_states


static func scenario_restore_equivalence_snapshot(environment: Dictionary) -> Dictionary:
	var snapshot := environment.duplicate(true)
	_strip_scenario_semantic_ephemera(snapshot)
	var causal_environment: Dictionary = {}
	for key in [
		"id", "archetype_id", "world_node_id", "environment_visit_id", "current_layer_id",
		"scenario_id", "scenario_sequence_definition", "scenario_sequence_migration",
		"scenario_sequence_state", "scenario_sequence_pending_visit_id",
		"scenario_restore_contract", "scenario_semantic_ready", "scenario_semantic_inventory",
		"scenario_semantic_inventory_version", "scenario_semantic_digest",
		"scenario_base_interactions", "scenario_base_actors", "scenario_base_producer_context",
		"scenario_semantic_action_digest", "scenario_event_choices",
		"scenario_layout_base_records", "scenario_layout_authority", "scenario_layout_authority_digest",
		"scenario_sequence_base_game_ids", "scenario_sequence_base_service_ids",
		"scenario_sequence_base_travel_hooks", "scenario_sequence_base_game_modifiers",
		"scenario_sequence_base_layout_object_rects",
	]:
		if snapshot.has(key):
			var value: Variant = snapshot.get(key)
			causal_environment[key] = value.duplicate(true) if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY] else value
	return {
		"contract": ENV06_6B_SEMANTIC_RESTORE_EQUIVALENCE_V1,
		"causal_environment": causal_environment,
		"derived_noncausal_fields": SCENARIO_DERIVED_NONCAUSAL_ENVIRONMENT_FIELDS.duplicate(),
	}


static func scenario_restore_equivalent(before: Dictionary, after: Dictionary) -> bool:
	return JSON.stringify(scenario_restore_equivalence_snapshot(before)) == JSON.stringify(scenario_restore_equivalence_snapshot(after))


# Same-process host transactions may carry a trusted, already-verified
# non-causal scenario projection across a save-shaped detached snapshot. The
# causal equivalence check prevents the projection from being attached to a
# different room, phase, visit, or authority state; persistent save/load still
# performs the ordinary trusted rebuild.
func restore_trusted_scenario_semantics(trusted_environment: Dictionary) -> bool:
	if trusted_environment.is_empty() or not bool(trusted_environment.get("scenario_semantic_ready", false)):
		return false
	if not scenario_restore_equivalent(trusted_environment, current_environment):
		return false
	for field_value in SCENARIO_DERIVED_NONCAUSAL_ENVIRONMENT_FIELDS:
		var field := str(field_value)
		if trusted_environment.has(field):
			var value: Variant = trusted_environment.get(field)
			current_environment[field] = value.duplicate(true) if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY] else value
		else:
			current_environment.erase(field)
	current_environment.erase("scenario_restore_pending_trusted_rebuild")
	return _scenario_semantic_ready()


static func _world_map_for_save_snapshot(map_data: Dictionary) -> Dictionary:
	if map_data.is_empty():
		return {}
	var snapshot := map_data.duplicate(false)
	var nodes_value: Variant = map_data.get("nodes", [])
	if typeof(nodes_value) != TYPE_ARRAY:
		return snapshot
	var nodes: Array = []
	for node_value in nodes_value as Array:
		if typeof(node_value) != TYPE_DICTIONARY:
			nodes.append(node_value)
			continue
		var node := (node_value as Dictionary).duplicate(false)
		var environment_value: Variant = node.get("environment", {})
		if typeof(environment_value) == TYPE_DICTIONARY and not (environment_value as Dictionary).is_empty():
			node["environment"] = _environment_for_persistent_storage(environment_value as Dictionary, false)
		nodes.append(node)
	snapshot["nodes"] = nodes
	return snapshot


func _crew_pack_ledger() -> Array:
	if crew_grievance_ledger.size() > CrewTurnModelScript.PRIVATE_GRIEVANCE_LIMIT:
		return []
	var result: Array = []
	for entry_value in crew_grievance_ledger:
		var entry := _copy_dict(entry_value)
		var member_index := CrewStateModelScript.MEMBER_IDS.find(str(entry.get("member_id", "")))
		var kind_index := CrewStateModelScript.GRIEVANCE_KINDS.find(str(entry.get("kind", "")))
		var entry_id := str(entry.get("id", ""))
		var source_ref := str(entry.get("source_ref", ""))
		var weight := int(entry.get("weight", 1))
		var turn_recorded := int(entry.get("turn_recorded", 0))
		if member_index < 0 or kind_index < 0 or entry_id.is_empty() \
				or entry_id.to_utf8_buffer().size() > CrewTurnModelScript.PRIVATE_TEXT_BYTE_LIMIT \
				or source_ref.to_utf8_buffer().size() > CrewTurnModelScript.PRIVATE_TEXT_BYTE_LIMIT \
				or weight < 1 or weight > CrewTurnModelScript.PRIVATE_SEQUENCE_LIMIT \
				or turn_recorded < 0 or turn_recorded > CrewTurnModelScript.PRIVATE_SEQUENCE_LIMIT:
			return []
		result.append([member_index, kind_index, weight, turn_recorded, entry_id.to_utf8_buffer().hex_encode(), source_ref.to_utf8_buffer().hex_encode()])
	return result


func _crew_unpack_ledger(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var source: Array = value
	# Backward-compatible reader for pre-crew06_9 saves.
	if not source.is_empty() and typeof(source[0]) == TYPE_DICTIONARY:
		return CrewStateModelScript.normalize_grievances(source)
	var decoded: Array = []
	for index in range(source.size()):
		if typeof(source[index]) != TYPE_ARRAY:
			continue
		var row: Array = source[index]
		if row.size() < 4:
			continue
		var member_index := int(row[0])
		var kind_index := int(row[1])
		if member_index < 0 or member_index >= CrewStateModelScript.MEMBER_IDS.size() or kind_index < 0 or kind_index >= CrewStateModelScript.GRIEVANCE_KINDS.size():
			continue
		var entry_id := str(row[4]).hex_decode().get_string_from_utf8() if row.size() > 4 else "g%04d" % (index + 1)
		var source_ref := str(row[5]).hex_decode().get_string_from_utf8() if row.size() > 5 else ""
		decoded.append({"id": entry_id, "member_id": CrewStateModelScript.MEMBER_IDS[member_index], "kind": CrewStateModelScript.GRIEVANCE_KINDS[kind_index], "weight": maxi(1, int(row[2])), "turn_recorded": maxi(0, int(row[3])), "source_ref": source_ref})
	return decoded


func _crew_jobs_for_save(deep_copy: bool) -> Dictionary:
	var result := crew_jobs.duplicate(deep_copy)
	for job_id in result.keys():
		result[job_id] = _crew_job_public_projection(_copy_dict(result.get(job_id, {})))
	return result


func _crew_jobs_from_save(value: Variant) -> Dictionary:
	var result: Dictionary = (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
	for job_id in result.keys():
		var job := _copy_dict(result.get(job_id, {}))
		var failure := _copy_dict(job.get("failure", {}))
		# Legacy packed failure readers remain supported, but new public saves do
		# not duplicate grievance authority outside the private capsule.
		var packed := _copy_array(failure.get("g", []))
		if packed.size() >= 2:
			var kind_index := int(packed[0])
			failure["grievance_kind"] = CrewStateModelScript.GRIEVANCE_KINDS[kind_index] if kind_index >= 0 and kind_index < CrewStateModelScript.GRIEVANCE_KINDS.size() else ""
			failure["grievance_weight"] = maxi(1, int(packed[1]))
			failure.erase("g")
		else:
			var definition := CrewStateModelScript.job_definition(str(job.get("definition_id", "")))
			var authored_failure := _copy_dict(definition.get("failure", {}))
			failure["grievance_kind"] = str(authored_failure.get("grievance_kind", ""))
			failure["grievance_weight"] = maxi(1, int(authored_failure.get("grievance_weight", 1)))
		job["failure"] = failure
		result[job_id] = job
	return result


func _crew_job_public_projection(job_value: Dictionary) -> Dictionary:
	var job := job_value.duplicate(true)
	var failure := _copy_dict(job.get("failure", {}))
	failure.erase("grievance_kind")
	failure.erase("grievance_weight")
	failure.erase("g")
	job["failure"] = failure
	return job


func _crew_state_for_save(deep_copy: bool, _opaque_hidden: bool = true) -> Dictionary:
	var result := {
		"schema_version": CrewStateModelScript.STATE_SCHEMA_VERSION,
		"trust": crew_trust_by_member.duplicate(deep_copy),
		"jobs": _crew_jobs_for_save(deep_copy),
		"job_sequence": crew_job_sequence,
		# Neutral keys keep the hidden learning model opaque in raw saves.
		"p": CrewPokerModelScript.pack_observations(crew_pattern_memory),
		"m": crew_match_marks.duplicate(deep_copy),
	}
	# Keep a crew-ignoring save byte-identical to the crew06_1 projection. The
	# optional field carries its own addition version only after the stash is used.
	if not crew_contraband_stash.is_empty():
		result["recruitment_schema_version"] = CrewRecruitmentModelScript.SCHEMA_VERSION
		result["stash"] = crew_contraband_stash.duplicate(deep_copy)
	var recruitment_encounters := _crew_recruitment_encounters_for_save()
	if not recruitment_encounters.is_empty() and (not _copy_dict(recruitment_encounters.get("meetings", {})).is_empty() or not _copy_dict(recruitment_encounters.get("contacts", {})).is_empty()):
		result["recruitment_schema_version"] = CrewRecruitmentModelScript.SCHEMA_VERSION
		result["encounters"] = recruitment_encounters.duplicate(deep_copy)
	var normalized_plays := CrewPlayModelScript.normalize_state(crew_play_state)
	if not (normalized_plays.get("uses", {}) as Dictionary).is_empty() \
			or not (normalized_plays.get("active", []) as Array).is_empty() \
			or not (normalized_plays.get("member_cooldowns", {}) as Dictionary).is_empty() \
			or not (normalized_plays.get("tombstones", []) as Array).is_empty():
		result["plays"] = _crew_plays_for_save(normalized_plays, deep_copy)
	var normalized_heist := CrewHeistModelScript.normalize_state(crew_heist_state)
	var private_heist := CrewTurnModelScript.empty_state()
	if not normalized_heist.is_empty():
		private_heist = _copy_dict(normalized_heist.get("x", CrewTurnModelScript.empty_state()))
		normalized_heist.erase("x")
		result["crew_heist_schema_version"] = CrewHeistModelScript.SCHEMA_VERSION
		result["crew_heist"] = normalized_heist.duplicate(deep_copy)
	# Every save carries the same fixed-size private authority envelope, including
	# a pristine zero-grievance run. Omitting it (or writing public empty
	# sentinels) made zero versus one grievance distinguishable by keys and size.
	# `_opaque_hidden` remains in the signature for old callers only.
	var _legacy_projection_ignored := _opaque_hidden
	var packed_ledger := _crew_pack_ledger()
	if packed_ledger.size() != crew_grievance_ledger.size() or crew_grievance_sequence < packed_ledger.size() \
			or crew_grievance_sequence > CrewTurnModelScript.PRIVATE_SEQUENCE_LIMIT:
		result["private_authority_error"] = "private_authority_capacity_exceeded"
		return result
	if not CrewTurnModelScript.valid_authority_id(_crew_private_authority_id):
		result["private_authority_error"] = "private_authority_unavailable"
		return result
	var payload := {"x": private_heist, "g": packed_ledger, "q": crew_grievance_sequence}
	var binding := _crew_private_save_binding(_crew_private_authority_id, normalized_heist)
	var fingerprint := CrewTurnModelScript.private_save_fingerprint(payload, CrewStateModelScript.MEMBER_IDS, CrewStateModelScript.GRIEVANCE_KINDS, binding)
	if binding.is_empty() or fingerprint.is_empty():
		result["private_authority_error"] = "private_authority_capacity_exceeded"
		return result
	if _crew_heist_private_capsule.is_empty() or _crew_heist_private_fingerprint != fingerprint:
		_crew_heist_private_capsule = CrewTurnModelScript.pack_private_save(payload, CrewStateModelScript.MEMBER_IDS, CrewStateModelScript.GRIEVANCE_KINDS, binding)
		_crew_heist_private_fingerprint = fingerprint if not _crew_heist_private_capsule.is_empty() else ""
	if _crew_heist_private_capsule.is_empty():
		result["private_authority_error"] = "private_authority_unavailable"
		return result
	result["a"] = _crew_private_authority_id
	result["z"] = _crew_heist_private_capsule
	return result


func _crew_private_save_binding(authority_id: String, public_heist: Dictionary) -> String:
	return CrewTurnModelScript.private_save_binding(authority_id, seed_text, {
		"challenge_config": challenge_config.duplicate(true),
		"member_ids": CrewStateModelScript.MEMBER_IDS.duplicate(),
		"trust": CrewStateModelScript.normalize_trust(crew_trust_by_member),
		"jobs": _crew_jobs_for_save(true),
		"heist": public_heist.duplicate(true),
	})


func _crew_plays_for_save(normalized_plays: Dictionary, deep_copy: bool) -> Dictionary:
	var result := normalized_plays.duplicate(deep_copy)
	var liability := _copy_dict(result.get("distraction_liability", {}))
	if not liability.is_empty():
		# The source is a hidden-ledger join key. It is reconstructed from the
		# already-public play sequence after authentication, never serialized.
		liability["source_ref"] = ""
		result["distraction_liability"] = liability
	return result


func _crew_recruitment_encounters_for_save() -> Dictionary:
	var result := CrewRecruitmentModelScript.normalize_encounter_state(crew_recruitment_encounters)
	var contacts := _copy_dict(result.get("contacts", {}))
	for member_id in contacts.keys():
		var contact := _copy_dict(contacts.get(member_id, {}))
		# `aggrieved` was a legacy public classifier derived from the private
		# ledger. Preserve the durable meeting/contact receipt but project a
		# neutral state based only on public standing and active-job facts.
		if str(contact.get("contact_state", "")) == "aggrieved":
			var standing := str(contact.get("standing", ""))
			var job_out := false
			for job_value in crew_jobs.values():
				var job := _copy_dict(job_value)
				if str(job.get("member_id", "")) == str(member_id) and str(job.get("status", "")) in ["offered", "accepted", "active"]:
					job_out = true
					break
			contact["contact_state"] = "job_out" if job_out else ("trusted" if standing in ["made", "inner_circle"] else "familiar")
		contacts[member_id] = contact
	result["contacts"] = contacts
	return result


func _crew_plays_from_save(value: Variant) -> Dictionary:
	var result := CrewPlayModelScript.restore_state(value)
	return result


func _crew_distraction_grievance_source(liability: Dictionary) -> String:
	return CrewTurnModelScript.private_reference("crew_play", CrewTurnModelScript.canonical_json({
		"seed": seed_text,
		"member_id": str(liability.get("member_id", "")),
		"until_action": maxi(0, int(liability.get("until_action", 0))),
	}))


func _crew_private_restore_failed(saved_heist: Dictionary) -> Dictionary:
	crew_grievance_ledger = []
	crew_grievance_sequence = 0
	_crew_private_authority_id = ""
	_crew_heist_private_capsule = ""
	_crew_heist_private_fingerprint = ""
	narrative_flags["crew_private_authority_error"] = "private_authority_unavailable"
	# Preserve an active heist as an explicit terminal result. A missing capsule
	# must never become a fresh attempt with erased hidden consequences.
	if not saved_heist.is_empty():
		saved_heist["x"] = CrewTurnModelScript.empty_state()
		saved_heist["status"] = CrewHeistModelScript.STATUS_ABORTED
		saved_heist["abort"] = {"reason": "private_authority_unavailable", "cost": 0, "action": _crew_action_index()}
		narrative_flags["crew_heist_private_restore_error"] = "private_authority_unavailable"
	return saved_heist


func _restore_crew_state(saved: Dictionary, legacy: bool) -> void:
	crew_trust_by_member = CrewStateModelScript.normalize_trust(saved.get("trust", {}))
	crew_jobs = CrewStateModelScript.normalize_jobs(_crew_jobs_from_save(saved.get("jobs", {})))
	crew_grievance_ledger = []
	crew_grievance_sequence = 0
	crew_job_sequence = maxi(int(saved.get("job_sequence", crew_jobs.size())), crew_jobs.size())
	crew_pattern_memory = CrewPokerModelScript.unpack_observations(saved.get("p", {}))
	crew_match_marks = {}
	crew_contraband_stash = _normalize_inventory_entries(saved.get("stash", []))
	crew_recruitment_encounters = CrewRecruitmentModelScript.normalize_encounter_state(saved.get("encounters", CrewRecruitmentModelScript.new_encounter_state()))
	if crew_recruitment_encounters.is_empty():
		crew_recruitment_encounters = CrewRecruitmentModelScript.new_encounter_state()
	else:
		# Migrate legacy persisted `aggrieved` contact classifiers immediately so
		# they cannot reappear through encounter_public_state before the next save.
		crew_recruitment_encounters = _crew_recruitment_encounters_for_save()
	if _crew_job_host_capability == null:
		_crew_job_host_capability = RefCounted.new()
	if _crew_recruitment_host_capability == null:
		_crew_recruitment_host_capability = RefCounted.new()
	if _world1_host_capability == null:
		_world1_host_capability = RefCounted.new()
	if _crew_heist_host_capability == null:
		_crew_heist_host_capability = RefCounted.new()
	crew_play_state = _crew_plays_from_save(saved.get("plays", {}))
	var saved_heist := _copy_dict(saved.get("crew_heist", {}))
	_crew_heist_private_capsule = ""
	_crew_heist_private_fingerprint = ""
	_crew_private_authority_id = ""
	var partial_private_authority := saved.has("a") != saved.has("z") \
			or (not saved_heist.is_empty() and not saved.has("z") and not saved_heist.has("z") and not saved_heist.has("x"))
	if not saved.has("z") and not saved.has("private_authority_error") and not partial_private_authority:
		crew_grievance_ledger = _crew_unpack_ledger(saved.get("g", saved.get("grievances", [])))
		crew_grievance_sequence = maxi(int(saved.get("q", saved.get("grievance_sequence", crew_grievance_ledger.size()))), crew_grievance_ledger.size())
		# Historical saves predate the opaque envelope. Give the migrated run a
		# fresh authority during restore so subsequent save reads remain pure.
		_crew_private_authority_id = CrewTurnModelScript.new_authority_id()
	if saved.has("private_authority_error") or partial_private_authority:
		saved_heist = _crew_private_restore_failed(saved_heist)
	elif saved.has("z"):
		var capsule := str(saved.get("z", ""))
		var authority_id := str(saved.get("a", ""))
		var public_heist := saved_heist.duplicate(true)
		public_heist.erase("x")
		public_heist.erase("z")
		var binding := _crew_private_save_binding(authority_id, public_heist)
		var restored_payload := CrewTurnModelScript.unpack_private_save(capsule, CrewStateModelScript.MEMBER_IDS, CrewStateModelScript.GRIEVANCE_KINDS, binding)
		var restored_ledger := _crew_unpack_ledger(restored_payload.get("g", [])) if not restored_payload.is_empty() else []
		if restored_payload.is_empty() or restored_ledger.size() != _copy_array(restored_payload.get("g", [])).size():
			saved_heist = _crew_private_restore_failed(saved_heist)
		else:
			crew_grievance_ledger = restored_ledger
			crew_grievance_sequence = int(restored_payload.get("q", restored_ledger.size()))
			if not saved_heist.is_empty(): saved_heist["x"] = _copy_dict(restored_payload.get("x", CrewTurnModelScript.empty_state()))
			_crew_private_authority_id = authority_id
			_crew_heist_private_capsule = capsule
			_crew_heist_private_fingerprint = CrewTurnModelScript.private_save_fingerprint(restored_payload, CrewStateModelScript.MEMBER_IDS, CrewStateModelScript.GRIEVANCE_KINDS, binding)
	elif saved_heist.has("z") and not saved_heist.has("x"):
		# Migration reader for the shipped 512-byte heist-local x-only capsule.
		var capsule := str(saved_heist.get("z", ""))
		saved_heist.erase("z")
		var binding := CrewTurnModelScript.legacy_private_save_binding(
			seed_text, str(saved_heist.get("plan_id", "")), int(saved_heist.get("locked_action", 0))
		)
		var restored_private := CrewTurnModelScript.unpack_legacy_private_save(capsule, CrewStateModelScript.MEMBER_IDS, binding)
		if restored_private.is_empty():
			saved_heist = _crew_private_restore_failed(saved_heist)
		else:
			saved_heist["x"] = restored_private
	crew_heist_state = CrewHeistModelScript.restore_state(saved_heist)
	var saved_marks: Dictionary = saved.get("m", {}) if typeof(saved.get("m", {})) == TYPE_DICTIONARY else {}
	for member_id in CrewStateModelScript.MEMBER_IDS:
		# Keep an empty/sparse save projection sparse. Session recording already
		# treats a missing mark as zero, so materializing neutral keys only breaks
		# byte-identical save/load without improving runtime behavior.
		if saved_marks.has(member_id):
			crew_match_marks[member_id] = maxi(0, int(saved_marks.get(member_id, 0)))
	_reconcile_crew_recruitment_perks()
	if not legacy:
		return
	var has_legacy_marker := (
		bool(narrative_flags.get("crew_favor_pending", false))
		or bool(narrative_flags.get("crew_marker_converted_to_cash", false))
		or (bool(narrative_flags.get("crew_marker_open", false)) and not bool(narrative_flags.get("crew_marker_clear", false)))
	)
	var legacy_members: Array = ["crew_rook"]
	for debt_value in debt:
		if typeof(debt_value) != TYPE_DICTIONARY:
			continue
		var debt_data: Dictionary = debt_value
		if str(debt_data.get("lender_id", "")) != CREW_LENDER_ID:
			continue
		if ["active", "overdue", "favor_due"].has(str(debt_data.get("status", "active"))):
			has_legacy_marker = true
			legacy_members.append_array(_copy_array(debt_data.get("crew_member_ids", [])))
	if not has_legacy_marker:
		return
	var marker_threshold := CrewStateModelScript.rank_threshold("marker")
	for member_value in legacy_members:
		var member_id := str(member_value)
		if CrewStateModelScript.MEMBER_IDS.has(member_id):
			crew_trust_by_member[member_id] = maxi(crew_trust(member_id), marker_threshold)


static func environment_context_snapshot(environment: Dictionary) -> Dictionary:
	# Dialogue/event predicates consume the room identity, offers, hooks, layout,
	# and routing fields—not live machine internals. Keeping game_states here
	# made every focus/refresh copy high-resolution ticket masks and other game
	# runtime buffers into presentation and queued-event records.
	var snapshot: Dictionary = {}
	for key_value in environment.keys():
		if str(key_value) == "game_states":
			continue
		snapshot[key_value] = _persistent_copy_value(environment.get(key_value))
	_strip_scenario_semantic_ephemera(snapshot)
	return snapshot


static func _compact_world_map_ticket_storage(map_data: Dictionary) -> Dictionary:
	if map_data.is_empty():
		return {}
	var nodes_value: Variant = map_data.get("nodes", [])
	if typeof(nodes_value) != TYPE_ARRAY:
		return map_data
	var nodes: Array = nodes_value
	for index in range(nodes.size()):
		if typeof(nodes[index]) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = nodes[index]
		var environment_value: Variant = node.get("environment", {})
		if typeof(environment_value) == TYPE_DICTIONARY and not (environment_value as Dictionary).is_empty():
			node["environment"] = _environment_for_persistent_storage(environment_value as Dictionary)
			nodes[index] = node
	map_data["nodes"] = nodes
	return map_data


static func _normalize_world_map_environment_snapshots(map_data: Dictionary) -> Dictionary:
	if map_data.is_empty():
		return {}
	var nodes := _copy_array(map_data.get("nodes", []))
	for index in range(nodes.size()):
		if typeof(nodes[index]) != TYPE_DICTIONARY:
			continue
		var node := _copy_dict(nodes[index])
		var environment := _copy_dict(node.get("environment", {}))
		if not environment.is_empty():
			node["environment"] = _normalize_environment(environment)
		nodes[index] = node
	map_data["nodes"] = nodes
	return map_data


static func _persistent_copy_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return value


static func _compact_ticket_receipt(ticket: Dictionary, fields: Array, deep_copy: bool) -> Dictionary:
	var receipt: Dictionary = {}
	for key_value in fields:
		var key := str(key_value)
		if not ticket.has(key):
			continue
		var value: Variant = ticket.get(key)
		receipt[key] = _persistent_copy_value(value) if deep_copy else value
	return receipt


static func _compact_pull_tab_receipt(ticket: Dictionary, deep_copy: bool) -> Dictionary:
	return _compact_ticket_receipt(ticket, PORTABLE_PULL_TAB_RECEIPT_FIELDS, deep_copy)


static func _compact_scratch_ticket_receipt(ticket: Dictionary, deep_copy: bool) -> Dictionary:
	var receipt := _compact_ticket_receipt(ticket, PORTABLE_SCRATCH_RECEIPT_FIELDS, deep_copy)
	receipt["mask_compacted"] = true
	return receipt


static func _compact_scratch_ticket_receipt_array(value: Variant, deep_copy: bool) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for ticket_value in value as Array:
		if typeof(ticket_value) == TYPE_DICTIONARY:
			result.append(_compact_scratch_ticket_receipt(ticket_value as Dictionary, deep_copy))
	return result


static func _compact_pull_tab_receipt_array(value: Variant, deep_copy: bool) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for ticket_value in value as Array:
		if typeof(ticket_value) == TYPE_DICTIONARY:
			result.append(_compact_pull_tab_receipt(ticket_value as Dictionary, deep_copy))
	return result


static func _bounded_loser_receipts(receipts: Array, existing_archive_count: int, limit: int) -> Dictionary:
	var archive_count := maxi(0, existing_archive_count)
	var retained := receipts
	if retained.size() > limit:
		var overflow := retained.size() - limit
		archive_count += overflow
		retained = retained.slice(overflow, retained.size())
	for index in range(retained.size()):
		var value: Variant = retained[index]
		if typeof(value) == TYPE_DICTIONARY:
			(value as Dictionary)["pile_depth_index"] = archive_count + index
	return {"receipts": retained, "archive_count": archive_count}


# Produces the bounded player-owned ticket state used by both game machines and
# persistence. Settled losers have no remaining gameplay value, so only the
# visible tail is retained; the exact historical count remains available for
# pile labels, inventory, and pull-tab cashout scrutiny.
static func compact_portable_ticket_state(kind: String, state: Dictionary, deep_copy: bool = false) -> Dictionary:
	var stored := state.duplicate(true) if deep_copy else state.duplicate(false)
	if kind == "pull_tabs":
		stored["winner_pile"] = _compact_pull_tab_receipt_array(state.get("winner_pile", []), deep_copy)
		var pull_losers := _compact_pull_tab_receipt_array(state.get("loser_pile", []), deep_copy)
		var bounded_pull := _bounded_loser_receipts(pull_losers, int(state.get("loser_archive_count", 0)), PORTABLE_PULL_TAB_LOSER_RECEIPT_LIMIT)
		stored["loser_pile"] = bounded_pull.get("receipts", [])
		stored["loser_archive_count"] = int(bounded_pull.get("archive_count", 0))
		return stored
	if kind != "scratch_tickets":
		return stored
	stored["winner_pile"] = _compact_scratch_ticket_receipt_array(state.get("winner_pile", []), deep_copy)
	var scratch_losers := _compact_scratch_ticket_receipt_array(state.get("loser_pile", []), deep_copy)
	var bounded_scratch := _bounded_loser_receipts(scratch_losers, int(state.get("loser_archive_count", 0)), PORTABLE_SCRATCH_TICKET_LOSER_RECEIPT_LIMIT)
	stored["loser_pile"] = bounded_scratch.get("receipts", [])
	stored["loser_archive_count"] = int(bounded_scratch.get("archive_count", 0))
	var last_value: Variant = state.get("last_settled_ticket", {})
	stored["last_settled_ticket"] = _compact_scratch_ticket_receipt(last_value as Dictionary, deep_copy) if typeof(last_value) == TYPE_DICTIONARY and not (last_value as Dictionary).is_empty() else {}
	return stored


static func _portable_ticket_state_for_live_storage(kind: String, state: Dictionary) -> Dictionary:
	return compact_portable_ticket_state(kind, state, false)


static func _portable_ticket_player_state(kind: String, machine: Dictionary) -> Dictionary:
	var result := {}
	for field_value in _copy_array(PORTABLE_TICKET_PLAYER_FIELDS.get(kind, [])):
		var field := str(field_value)
		var fallback: Variant = 0 if field.ends_with("_count") else [] if field.ends_with("pile") or field.ends_with("stack") or field.ends_with("queue") else {}
		var value: Variant = machine.get(field, fallback)
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
	var count := _portable_ticket_array_size(state.get("winner_pile", [])) + _portable_ticket_array_size(state.get("loser_pile", [])) + maxi(0, int(state.get("loser_archive_count", 0)))
	if kind == "pull_tabs":
		return count + _portable_ticket_array_size(state.get("tray_stack", [])) + _portable_ticket_array_size(state.get("ticket_stack", []))
	if kind == "scratch_tickets" and not _copy_dict(state.get("active_ticket", {})).is_empty():
		count += 1
	if kind == "scratch_tickets":
		count += _portable_ticket_array_size(state.get("pending_queue", []))
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
				var state := compact_portable_ticket_state(kind, state_value as Dictionary, true)
				state["origin_key"] = origin_key
				origins[origin_key] = state
		if not origins.is_empty() or value.has(kind):
			result[kind] = origins
	return result


static func _inventory_item_id(entry: Variant) -> String:
	if typeof(entry) == TYPE_DICTIONARY:
		return str((entry as Dictionary).get("id", "")).strip_edges()
	return str(entry).strip_edges()


# Runtime item grants are unique by id, while meta-collection instances are
# unique by their permanent instance id. Normalize impossible duplicate string
# entries from legacy or edited saves without collapsing legitimate instances.
static func _normalize_inventory_entries(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var result: Array = []
	var seen_string_ids := {}
	var seen_instance_ids := {}
	for entry_value in value as Array:
		if typeof(entry_value) == TYPE_DICTIONARY:
			var entry: Dictionary = (entry_value as Dictionary).duplicate(true)
			var dictionary_item_id := _inventory_item_id(entry)
			if dictionary_item_id.is_empty():
				continue
			var meta: Dictionary = entry.get("meta_collection", {}) if typeof(entry.get("meta_collection", {})) == TYPE_DICTIONARY else {}
			var instance_id := int(meta.get("instance_id", entry.get("instance_id", 0)))
			if instance_id > 0:
				if seen_instance_ids.has(instance_id):
					continue
				seen_instance_ids[instance_id] = true
			result.append(entry)
			continue
		var item_id := str(entry_value).strip_edges()
		if item_id.is_empty() or seen_string_ids.has(item_id):
			continue
		seen_string_ids[item_id] = true
		result.append(item_id)
	return result


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
	for key in ["id", "archetype_id", "world_node_id", "display_name", "kind", "current_layer_id", "entered_game_clock_minutes", "departed_game_clock_minutes"]:
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
		GRAND_CASINO_CAGE_ARCHETYPE_ID: 0,
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


func _grand_casino_room_states_for_save(deep_copy: bool = true) -> Dictionary:
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
			result[room_id] = _environment_for_persistent_storage(room as Dictionary, deep_copy)
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
			if result.size() >= MAX_PENDING_TRIGGERED_EVENTS:
				break
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
	var presentation := str(source.get("presentation", "")).strip_edges().to_lower()
	if presentation != "faceless_silhouette":
		presentation = ""
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
		"presentation": presentation,
		"environment_actor": bool(source.get("environment_actor", true)),
		"face_layers": _copy_array(source.get("face_layers", [])),
		"portrait_count": clampi(int(source.get("portrait_count", 1)), 1, 3),
		"character_id": str(source.get("character_id", "")).strip_edges(),
		"character_pool_id": str(source.get("character_pool_id", "")).strip_edges(),
		"character_identity_key": str(source.get("character_identity_key", "")).strip_edges(),
		"voice_line_key": str(source.get("voice_line_key", "")).strip_edges(),
		"voice_line": str(source.get("voice_line", "")).strip_edges(),
		"speaking_character_id": str(source.get("speaking_character_id", "")).strip_edges(),
		"speaking_character_name": str(source.get("speaking_character_name", "")).strip_edges(),
		"speaking_character_title": str(source.get("speaking_character_title", "")).strip_edges(),
		"members": _copy_array(source.get("members", [])),
		"encounter": _copy_dict(source.get("encounter", {})),
		"lender_terms": _copy_dict(source.get("lender_terms", {})),
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
			if result.size() >= MAX_PENDING_BAG_MARKERS:
				break
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
	if environment.has("scenario_semantic_inventory_version"):
		var inventory_version_value: Variant = environment.get("scenario_semantic_inventory_version")
		if typeof(inventory_version_value) == TYPE_FLOAT and is_finite(float(inventory_version_value)) and is_equal_approx(float(inventory_version_value), floor(float(inventory_version_value))):
			environment["scenario_semantic_inventory_version"] = int(inventory_version_value)
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
	if environment.has("semantic_anchors"): environment["semantic_anchors"] = _copy_dict(environment.get("semantic_anchors", {}))
	if environment.has("semantic_zones"): environment["semantic_zones"] = _copy_dict(environment.get("semantic_zones", {}))
	if environment.has("semantic_actors"): environment["semantic_actors"] = _copy_array(environment.get("semantic_actors", []))
	environment["local_narrative_flags"] = _copy_dict(environment.get("local_narrative_flags", {}))
	if environment.has("crew_presence"):
		environment["crew_presence"] = _copy_array(environment.get("crew_presence", []))
	if environment.has("crew_switch_intel_uses"):
		environment["crew_switch_intel_uses"] = maxi(0, int(environment.get("crew_switch_intel_uses", 0)))
	if environment.has("crew_switch_intel_visit_id"):
		environment["crew_switch_intel_visit_id"] = str(environment.get("crew_switch_intel_visit_id", ""))
	environment["game_states"] = _normalize_game_states(_copy_dict(environment.get("game_states", {})))
	var blackjack_states: Dictionary = environment.get("game_states", {})
	for authority_game_id_value in blackjack_states.keys():
		var authority_game_id := str(authority_game_id_value)
		if typeof(blackjack_states.get(authority_game_id, null)) != TYPE_DICTIONARY:
			continue
		var blackjack_table: Dictionary = (blackjack_states.get(authority_game_id, {}) as Dictionary).duplicate(true)
		# Apply receipts are transaction-local and can never survive a save boundary.
		blackjack_table.erase("_blackjack_pending_apply_receipt")
		if blackjack_table.has(BlackjackActionAuthorityScript.LEDGER_KEY):
			var binding := "%s:%s:%s" % [authority_game_id, str(environment.get("id", "unknown")), str(environment.get("archetype_id", "unknown"))]
			var ledger := BlackjackActionAuthorityScript.validate_persisted_ledger(blackjack_table.get(BlackjackActionAuthorityScript.LEDGER_KEY), binding)
			if ledger.is_empty():
				blackjack_table.erase(BlackjackActionAuthorityScript.LEDGER_KEY)
			else:
				blackjack_table[BlackjackActionAuthorityScript.LEDGER_KEY] = ledger
		blackjack_states[authority_game_id] = blackjack_table
	environment["game_states"] = blackjack_states
	environment["visual_context"] = _copy_dict(environment.get("visual_context", {}))
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)
	environment["security_profile"] = _copy_dict(environment.get("security_profile", {}))
	environment["economic_profile"] = _normalize_economic_profile(_copy_dict(environment.get("economic_profile", {})))
	environment["objective_hint"] = str(environment.get("objective_hint", ""))
	environment["demo_objective"] = _copy_dict(environment.get("demo_objective", {}))
	var scenario_state := ScenarioEngineScript.normalize_state(environment.get("scenario_state", {}))
	if scenario_state.is_empty():
		for legacy_key in ["scenario_state", "scenario_id", "scenario_phase_index", "scenario_phase_action_counter"]:
			environment.erase(legacy_key)
	else:
		environment["scenario_state"] = scenario_state
		environment["scenario_id"] = str(scenario_state.get("id", ""))
		environment["scenario_phase_index"] = int(scenario_state.get("phase_index", 0))
		environment["scenario_phase_action_counter"] = int(scenario_state.get("phase_action_counter", 0))
		for scenario_array_key in ["scenario_patron_ids", "scenario_staff_ids"]:
			environment[scenario_array_key] = _copy_array(environment.get(scenario_array_key, []))
		for scenario_dict_key in ["scenario_game_modifiers", "scenario_presentation", "scenario_exclusive_opportunity", "scenario_hook_flags"]:
			environment[scenario_dict_key] = _copy_dict(environment.get(scenario_dict_key, {}))
	var has_persisted_sequence := environment.has("scenario_sequence_state")
	var raw_sequence_state: Variant = environment.get("scenario_sequence_state", {})
	var sequence_state := _copy_dict(raw_sequence_state)
	if typeof(sequence_state.get("schema_version")) == TYPE_FLOAT and is_finite(float(sequence_state.get("schema_version"))) and is_equal_approx(float(sequence_state.get("schema_version")), floor(float(sequence_state.get("schema_version")))):
		sequence_state["schema_version"] = int(sequence_state.get("schema_version"))
	var sequence_state_errors := ScenarioOperationRegistryScript.validate_bounded_variant("persisted scenario sequence state", raw_sequence_state) if has_persisted_sequence else []
	var sequence_identity_valid := typeof(raw_sequence_state) == TYPE_DICTIONARY and not sequence_state.is_empty() and typeof(sequence_state.get("schema_version")) == TYPE_INT and int(sequence_state.get("schema_version", 0)) == ScenarioSequenceRuntimeScript.STATE_SCHEMA_VERSION and typeof(sequence_state.get("scenario_id")) == TYPE_STRING and not str(sequence_state.get("scenario_id", "")).strip_edges().is_empty() and ScenarioSequenceRuntimeScript._persisted_collections_within_limits(sequence_state)
	if has_persisted_sequence and (not sequence_state_errors.is_empty() or not sequence_identity_valid):
		environment.erase("scenario_sequence_state")
		environment.erase("scenario_sequence_projection")
		environment.erase("scenario_render_snapshot")
		environment.erase("scenario_sequence_pending_visit_id")
		environment["scenario_sequence_migration_error"] = "Persisted dynamic room sequence state is malformed, unsupported, or overbound; explicit migration is required."
	elif has_persisted_sequence:
		var sequence_definition := _copy_dict(environment.get("scenario_sequence_definition", {}))
		var normalized_sequence_state := ScenarioSequenceRuntimeScript.normalize_state(sequence_state, sequence_definition)
		if normalized_sequence_state.is_empty():
			environment.erase("scenario_sequence_state")
			environment.erase("scenario_sequence_projection")
			environment.erase("scenario_render_snapshot")
			environment.erase("scenario_sequence_pending_visit_id")
			environment["scenario_sequence_migration_error"] = "Persisted dynamic room sequence state is malformed, unsupported, or overbound; explicit migration is required."
		else:
			environment["scenario_sequence_state"] = normalized_sequence_state
			# Projection and render data are derived from authoritative sequence state.
			# Never trust a stale or tampered saved copy across schema/content versions.
			environment.erase("scenario_sequence_projection")
			environment.erase("scenario_render_snapshot")
			var baseline_sources := {
				"scenario_sequence_base_game_ids": "game_ids",
				"scenario_sequence_base_service_ids": "service_ids",
				"scenario_sequence_base_travel_hooks": "travel_hooks",
			}
			for baseline_array_key in baseline_sources.keys():
				var source_key := str(baseline_sources.get(baseline_array_key, ""))
				environment[baseline_array_key] = _copy_array(environment.get(baseline_array_key, environment.get(source_key, [])))
			environment["scenario_sequence_base_game_modifiers"] = _copy_dict(environment.get("scenario_sequence_base_game_modifiers", environment.get("scenario_game_modifiers", {})))
	if environment.has("scenario_sequence_migration"):
		environment["scenario_sequence_migration"] = _copy_dict(environment.get("scenario_sequence_migration", {}))
	if environment.has(CrewWorldSequenceAdapterScript.CONTAINER_KEY):
		var world_instances := CrewWorldSequenceAdapterScript.durable_container(environment.get(CrewWorldSequenceAdapterScript.CONTAINER_KEY, {}))
		if world_instances.is_empty(): environment.erase(CrewWorldSequenceAdapterScript.CONTAINER_KEY)
		else: environment[CrewWorldSequenceAdapterScript.CONTAINER_KEY] = world_instances
	_normalize_environment_layers(environment)
	# Semantic authorization is a render-time proof. Saved or layer-stored copies
	# can retain only the expected schema/digest and must be rebuilt before ingress.
	_strip_scenario_semantic_ephemera(environment)
	return environment


static func _normalize_environment_layers(environment: Dictionary) -> void:
	var archetype_id := str(environment.get("archetype_id", "")).strip_edges()
	var has_schema := int(environment.get("environment_layer_schema_version", 0)) > 0
	if not has_schema and archetype_id == TIER_TWO_UNDERGROUND_SOURCE_ID:
		environment["display_name"] = "The Punchline"
		environment["environment_layer_schema_version"] = EnvironmentInstance.ENVIRONMENT_LAYER_SCHEMA_VERSION
		environment["current_layer_id"] = "casino"
		environment["default_layer_id"] = "club"
		environment["layer_ids"] = ["club", "casino", "back_room"]
		environment["layer_display_name"] = "Hidden Casino"
		environment["layer_discovery"] = {"club": true, "casino": true, "back_room": false}
		environment["layer_transitions"] = [
			{"target_layer_id": "club", "label": "Comedy Club", "description": "Take the stairs back to the public room."},
			{"target_layer_id": "back_room", "label": "Crew Back Room", "description": "A private door behind the tables.", "requires_discovered": true, "access_paths": [{"method": "crew_rank", "min_crew_rank": "made"}, {"method": "rook_escort", "flags_any": ["rook_escort_punchline_back_room"]}], "locked_reason": "Rook keeps this door for made company."},
		]
		environment["layer_ambient_lines"] = []
		environment["layer_ambient_label"] = ""
		environment["layer_ambient_prop"] = ""
		environment["layer_ambient_rotate_actions"] = 1
		environment["layer_ambient_index"] = 0
		environment["layer_ambient_line"] = ""
		var legacy_body := environment.duplicate(true)
		legacy_body.erase("layer_states")
		environment["layer_states"] = {"casino": legacy_body}
		has_schema = true
	if not has_schema:
		return
	environment["environment_layer_schema_version"] = EnvironmentInstance.ENVIRONMENT_LAYER_SCHEMA_VERSION
	environment["current_layer_id"] = str(environment.get("current_layer_id", environment.get("default_layer_id", ""))).strip_edges()
	environment["default_layer_id"] = str(environment.get("default_layer_id", environment.get("current_layer_id", ""))).strip_edges()
	environment["layer_ids"] = _string_array(_copy_array(environment.get("layer_ids", [])))
	environment["layer_display_name"] = str(environment.get("layer_display_name", "")).strip_edges()
	environment["layer_transitions"] = _copy_array(environment.get("layer_transitions", []))
	environment["layer_discovery"] = _copy_dict(environment.get("layer_discovery", {}))
	var states := _copy_dict(environment.get("layer_states", {}))
	for state_id_value in states.keys():
		var body := _copy_dict(states.get(state_id_value, {}))
		body.erase("layer_states")
		if body.has("scenario_sequence_state"):
			var raw_layer_sequence_state: Variant = body.get("scenario_sequence_state", {})
			var layer_sequence_state := _copy_dict(raw_layer_sequence_state)
			if typeof(layer_sequence_state.get("schema_version")) == TYPE_FLOAT and is_finite(float(layer_sequence_state.get("schema_version"))) and is_equal_approx(float(layer_sequence_state.get("schema_version")), floor(float(layer_sequence_state.get("schema_version")))):
				layer_sequence_state["schema_version"] = int(layer_sequence_state.get("schema_version"))
			var layer_sequence_valid := typeof(raw_layer_sequence_state) == TYPE_DICTIONARY \
				and not layer_sequence_state.is_empty() \
				and ScenarioOperationRegistryScript.validate_bounded_variant("persisted layer scenario sequence state", raw_layer_sequence_state).is_empty() \
				and typeof(layer_sequence_state.get("schema_version")) == TYPE_INT \
				and int(layer_sequence_state.get("schema_version", 0)) == ScenarioSequenceRuntimeScript.STATE_SCHEMA_VERSION \
				and typeof(layer_sequence_state.get("scenario_id")) == TYPE_STRING \
				and not str(layer_sequence_state.get("scenario_id", "")).strip_edges().is_empty() \
				and ScenarioSequenceRuntimeScript._persisted_collections_within_limits(layer_sequence_state)
			if not layer_sequence_valid:
				body.erase("scenario_sequence_state")
				body["scenario_sequence_migration_error"] = "Persisted dynamic room sequence state is malformed, unsupported, or overbound; explicit migration is required."
		states[str(state_id_value)] = body
	environment["layer_states"] = states
	environment["layer_ambient_lines"] = _string_array(_copy_array(environment.get("layer_ambient_lines", [])))
	environment["layer_ambient_label"] = str(environment.get("layer_ambient_label", "")).strip_edges()
	environment["layer_ambient_prop"] = str(environment.get("layer_ambient_prop", "")).strip_edges()
	environment["layer_ambient_rotate_actions"] = maxi(1, int(environment.get("layer_ambient_rotate_actions", 1)))
	environment["layer_ambient_index"] = maxi(0, int(environment.get("layer_ambient_index", 0)))
	environment["layer_ambient_line"] = str(environment.get("layer_ambient_line", "")).strip_edges()


static func _normalize_scenario_recent(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for archetype_value in value.keys():
		var archetype_id := str(archetype_value).strip_edges()
		if archetype_id.is_empty():
			continue
		var recent := _string_array(_copy_array(value.get(archetype_value, [])))
		if recent.size() > 3:
			recent = recent.slice(0, 3)
		if not recent.is_empty():
			result[archetype_id] = recent
	return result


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
	if typeof(result.get("game_stake_floor_overrides", {})) == TYPE_DICTIONARY:
		var normalized_floor_overrides: Dictionary = {}
		var floor_overrides: Dictionary = result.get("game_stake_floor_overrides", {})
		for game_id in floor_overrides.keys():
			var normalized_id := str(game_id).strip_edges()
			if normalized_id.is_empty():
				continue
			normalized_floor_overrides[normalized_id] = maxi(0, int(floor_overrides.get(game_id, 0)))
		result["game_stake_floor_overrides"] = normalized_floor_overrides
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
		if defer_bankroll_zero or closing_time_forced_travel_required():
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


func _blackjack_authority_has_unsettled_wager() -> bool:
	var game_states: Dictionary = current_environment.get("game_states", {}) if typeof(current_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var table: Dictionary = game_states.get("blackjack", {}) if typeof(game_states.get("blackjack", {})) == TYPE_DICTIONARY else {}
	var ledger: Dictionary = table.get("_blackjack_action_authority", {}) if typeof(table.get("_blackjack_action_authority", {})) == TYPE_DICTIONARY else {}
	var session: Dictionary = ledger.get("session", {}) if typeof(ledger.get("session", {})) == TYPE_DICTIONARY else {}
	var hands: Array = session.get("player_hands", session.get("blackjack_hands", [])) if typeof(session.get("player_hands", session.get("blackjack_hands", []))) == TYPE_ARRAY else []
	return bool(session.get("bankroll_wager_debited", false)) \
		and int(session.get("wager_debited", 0)) > 0 \
		and not hands.is_empty()
