class_name RunStateSchema
extends RefCounted

# One canonical list owns every persisted RunState key. The transform labels
# document the deliberately non-generic persistence boundaries; RunState
# supplies their values because those transforms depend on private authority.
const FIELDS := [
	{"key": "seed_text"},
	{"key": "seed_value", "transform": "exact_integer"},
	{"key": "rng_seed", "transform": "exact_integer"},
	{"key": "rng_state", "transform": "exact_integer"},
	{"key": "challenge_config"},
	{"key": "bankroll", "transform": "exact_integer"},
	{"key": "grand_casino_chips", "transform": "exact_integer"},
	{"key": "grand_casino_atm_debt", "transform": "exact_integer"},
	{"key": "economic_state"},
	{"key": "inventory"},
	{"key": "portable_ticket_piles"},
	{"key": "active_item_id"},
	{"key": "debt"},
	{"key": "sals_forfeited_item_ids"},
	{"key": "suspicion"},
	{"key": "baseline_luck", "transform": "exact_integer"},
	{"key": "drunk_level", "transform": "exact_integer"},
	{"key": "alcoholic_level", "transform": "exact_integer"},
	{"key": "pending_drunk_absorption"},
	{"key": "drunk_distortion_suppression_turns", "transform": "exact_integer"},
	{"key": "current_environment", "transform": "environment_persistent_compaction"},
	{"key": "world_map", "transform": "world_map_persistent_compaction"},
	{"key": "scenario_state_schema_version", "transform": "exact_integer"},
	{"key": "scenario_recent_by_archetype"},
	{"key": "environment_situation_cycles_by_node"},
	{"key": "grand_casino_room_states"},
	{"key": "grand_casino_staffing"},
	{"key": "rourke_current_room"},
	{"key": "rourke_current_spot"},
	{"key": "rourke_facing"},
	{"key": "rourke_actions_until_move", "transform": "exact_integer"},
	{"key": "rourke_off_floor_actions", "transform": "exact_integer"},
	{"key": "rourke_floor_action_index", "transform": "exact_integer"},
	{"key": "linda_cage_state"},
	{"key": "grand_casino_room_heat_accumulators"},
	{"key": "rival_cheaters"},
	{"key": "rival_cheater_day", "transform": "exact_integer"},
	{"key": "rourke_escort_state"},
	{"key": "pending_triggered_events"},
	{"key": "pending_bags"},
	{"key": "active_triggered_event"},
	{"key": "event_cadence"},
	{"key": "music_arrangement_state"},
	{"key": "music_tempo_state"},
	{"key": "music_choreography_state"},
	{"key": "environment_history"},
	{"key": "environment_history_archive_count", "transform": "exact_integer"},
	{"key": "unlocked_travel"},
	{"key": "narrative_flags"},
	{"key": "story_flags"},
	{"key": "story_log"},
	{"key": "story_log_archive_count", "transform": "exact_integer"},
	{"key": "crew_state"},
	{"key": "scenario_host_transaction_ledger"},
	{"key": "world_sequence_registrations"},
	{"key": "active_delivery_run"},
	{"key": "numbers_state"},
	{"key": "heat_history"},
	{"key": "town_state"},
	{"key": "simulation_msec", "transform": "exact_integer"},
	{"key": "game_clock_minutes", "transform": "exact_integer"},
	{"key": "grand_casino_atm_interest_boundary_index", "transform": "exact_integer"},
	{"key": "grand_casino_atm_interest_notifications"},
	{"key": "closing_time_state"},
	{"key": "act", "transform": "exact_integer"},
	{"key": "act_index", "transform": "exact_integer"},
	{"key": "home_state"},
	{"key": "run_status"},
	{"key": "run_failure_reason"},
	{"key": "run_failure_message"},
	{"key": "run_spending_score", "transform": "exact_integer"},
]

# Historical inputs remain readable without pretending they are current fields.
const LEGACY_INPUT_KEYS := ["active_streets_run", "pending_bag"]


static func serialize(run_state: Object) -> Dictionary:
	var source: Dictionary = run_state.call("_run_state_schema_values")
	var result: Dictionary = {}
	for field in FIELDS:
		var key := str(field.get("key", ""))
		var value: Variant = source.get(key)
		if str(field.get("transform", "")) == "exact_integer":
			value = int(value)
		result[key] = value
	return result


static func restore(run_state: Object, payload: Dictionary) -> void:
	var canonical: Dictionary = {}
	for field in FIELDS:
		var key := str(field.get("key", ""))
		if payload.has(key):
			var value: Variant = payload[key]
			if str(field.get("transform", "")) == "exact_integer":
				value = int(value)
			canonical[key] = value
	for legacy_key in LEGACY_INPUT_KEYS:
		if payload.has(legacy_key):
			canonical[legacy_key] = payload[legacy_key]
	run_state.call("_run_state_schema_restore", canonical)


static func serialized_keys() -> Array:
	var result: Array = []
	for field in FIELDS:
		result.append(str(field.get("key", "")))
	result.sort()
	return result


static func consumed_keys() -> Array:
	return serialized_keys()
