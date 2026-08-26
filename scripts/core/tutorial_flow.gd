class_name TutorialFlow
extends RefCounted

const CHALLENGE_ID := "tutorial_first_card"
const LESSON_SCOPE := "tutorial_run"
const INVITATION_FLAG := "grand_casino_invite"
const APARTMENT_ID := "apartment"
const CORNER_STORE_ID := "corner_store"
const GAS_CASINO_ID := "gas_station_casino"
const UNDERGROUND_CASINO_ID := "small_underground_casino"
const GRAND_CASINO_ID := "grand_casino"


static func environment_open_status(run_state: RunState, archetype: Dictionary, minute_of_day: int) -> Dictionary:
	if run_state == null or not run_state.is_tutorial_run():
		return EnvironmentHours.status_at(archetype, minute_of_day)
	return {
		"open": true,
		"always_open": true,
		"closing_soon": false,
		"label": "Open for lessons",
		"disabled_reason": "",
		"opens_at": "",
		"closes_at": "",
		"minutes_until_open": 0,
		"minutes_until_close": EnvironmentHours.MINUTES_PER_DAY,
		"tutorial_override": true,
	}


static func environment_open_at(run_state: RunState, archetype: Dictionary, minute_of_day: int) -> bool:
	return bool(environment_open_status(run_state, archetype, minute_of_day).get("open", true))


static func environment_status_text(run_state: RunState, archetype: Dictionary, minute_of_day: int) -> String:
	var status := environment_open_status(run_state, archetype, minute_of_day)
	if bool(status.get("tutorial_override", false)):
		return "Open for lessons"
	return EnvironmentHours.travel_status_text(archetype, minute_of_day)


static func apply_caught_transition(run_state: RunState, result: Dictionary) -> Dictionary:
	if run_state == null or not run_state.is_tutorial_run():
		return {}
	# Being caught is a gameplay result, never permission to administratively
	# complete an unplayed lesson. Blackjack owns the protected practice-hand
	# behavior; the tutorial dependency chain must always reach a real count.
	return {}


static func repair_legacy_frontier(run_state: RunState) -> bool:
	return repair_legacy_blackjack_count_skip(run_state)


static func repair_legacy_blackjack_count_skip(run_state: RunState) -> bool:
	if run_state == null or not run_state.is_tutorial_run():
		return false
	if not bool(run_state.narrative_flags.get("tutorial_caught_continue", false)):
		return false
	var environment: Dictionary = run_state.current_environment
	if str(environment.get("archetype_id", "")) != UNDERGROUND_CASINO_ID:
		return false
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var table: Dictionary = game_states.get("blackjack", {}) if typeof(game_states.get("blackjack", {})) == TYPE_DICTIONARY else {}
	if bool(table.get("tutorial_count_completed", false)):
		run_state.narrative_flags.erase("tutorial_caught_continue")
		return false

	# Older builds barred the table, discarded the live Peek hand, marked Count
	# complete, and sent the player to Leave. The lost hand cannot be reconstructed
	# safely, so resume at the next honest boundary and require hand three's real
	# count challenge before Leave can ever become eligible.
	table["barred"] = false
	for barred_key in ["barred_reason", "barred_at_hand", "barred_confiscated_bet", "barred_scope", "barred_heat_delta"]:
		table.erase(barred_key)
	table["hands_played"] = maxi(2, int(table.get("hands_played", 0)))
	if typeof(table.get("last_result", {})) != TYPE_DICTIONARY or (table.get("last_result", {}) as Dictionary).is_empty():
		table["last_result"] = {"headline": "LESSON RESUMED", "summary": "The practice Peek hand is settled. Counting is still required."}
	game_states["blackjack"] = table
	environment["game_states"] = game_states
	run_state.current_environment = environment

	var completed: Dictionary = run_state.narrative_flags.get("tutorial_lessons_completed", {}) if typeof(run_state.narrative_flags.get("tutorial_lessons_completed", {})) == TYPE_DICTIONARY else {}
	completed["tutorial_blackjack_peek"] = true
	completed["tutorial_blackjack_peek_finish"] = true
	for lesson_id in ["tutorial_blackjack_count_start", "tutorial_blackjack_count_all", "tutorial_blackjack_count_finish", "tutorial_heat_warning", "tutorial_leave_blackjack"]:
		completed.erase(lesson_id)
	run_state.narrative_flags["tutorial_lessons_completed"] = completed
	run_state.narrative_flags.erase("tutorial_caught_continue")
	return true


static func is_tutorial_challenge(config: Dictionary) -> bool:
	return str(config.get("id", "")).strip_edges() == CHALLENGE_ID or bool(config.get("tutorial", false))


static func challenge_config(library: ContentLibrary) -> Dictionary:
	if library == null:
		return {}
	var config := library.challenge_config_for(CHALLENGE_ID, "")
	if config.is_empty():
		return {}
	# The guided run owns its opening room. Enforce the authored identity at the
	# boundary so profile home/loadout modifiers can never leak into either New
	# Run or Replay Lessons.
	var modifiers: Dictionary = config.get("modifiers", {}) if typeof(config.get("modifiers", {})) == TYPE_DICTIONARY else {}
	modifiers = modifiers.duplicate(true)
	modifiers["home_archetype_id"] = APARTMENT_ID
	config["modifiers"] = modifiers
	return config


static func should_auto_start(profile: Variant, meta_snapshot: Dictionary) -> bool:
	if profile == null or bool(profile.get("tutorial_completed")):
		return false
	if profile.has_method("legacy_without_tutorial_state") and bool(profile.call("legacy_without_tutorial_state")):
		return false
	for field_name in ["items", "run_history", "scratch_ticket_types_discovered"]:
		var value: Variant = profile.get(field_name)
		if typeof(value) == TYPE_ARRAY and not (value as Array).is_empty():
			return false
	for field_name in ["challenge_completions", "daily_runs", "lifetime_stats", "act_seam"]:
		var value: Variant = profile.get(field_name)
		if typeof(value) == TYPE_DICTIONARY and (
				_lifetime_stats_has_progress(value) if field_name == "lifetime_stats" else _dictionary_has_progress(value)
		):
			return false
	for field_name in ["owned_instances", "unopened_bags", "loadout"]:
		var value: Variant = meta_snapshot.get(field_name, [])
		if typeof(value) == TYPE_ARRAY and not (value as Array).is_empty():
			return false
	if int(meta_snapshot.get("gold_balance", 0)) > 0:
		return false
	if str(meta_snapshot.get("housing_tier", "back_alley")) != "back_alley":
		return false
	return true


static func _lifetime_stats_has_progress(value: Dictionary) -> bool:
	var remaining := value.duplicate(true)
	var release_value: Variant = remaining.get("release_0_6", {})
	remaining.erase("release_0_6")
	if _dictionary_has_progress(remaining):
		return true
	if typeof(release_value) != TYPE_DICTIONARY:
		return false
	var release := (release_value as Dictionary).duplicate(true)
	# ProfileInventory materializes this canonical schema-5 reporting value even
	# before the player has acted. It is an enum default, not career progress.
	if str(release.get("highest_crew_standing", "")).strip_edges() in ["", "stranger"]:
		release.erase("highest_crew_standing")
	return _dictionary_has_progress(release)


static func _dictionary_has_progress(value: Dictionary) -> bool:
	for nested_value in value.values():
		match typeof(nested_value):
			TYPE_BOOL:
				if bool(nested_value):
					return true
			TYPE_INT, TYPE_FLOAT:
				if float(nested_value) != 0.0:
					return true
			TYPE_STRING:
				if not str(nested_value).strip_edges().is_empty():
					return true
			TYPE_ARRAY:
				if not (nested_value as Array).is_empty():
					return true
			TYPE_DICTIONARY:
				if _dictionary_has_progress(nested_value):
					return true
	return false


static func lesson_is_tutorial(lesson_id: String, lessons: Array) -> bool:
	var normalized := lesson_id.strip_edges()
	for lesson_value in lessons:
		if typeof(lesson_value) != TYPE_DICTIONARY:
			continue
		var lesson: Dictionary = lesson_value
		if str(lesson.get("id", "")).strip_edges() == normalized:
			return str(lesson.get("scope", "")).strip_edges() == LESSON_SCOPE
	return false


static func lesson_allowed_action_ids(lesson_id: String, lessons: Array) -> Array:
	var normalized := lesson_id.strip_edges()
	for lesson_value in lessons:
		if typeof(lesson_value) != TYPE_DICTIONARY:
			continue
		var lesson: Dictionary = lesson_value
		if str(lesson.get("id", "")).strip_edges() != normalized:
			continue
		var gating: Dictionary = lesson.get("gating", {}) if typeof(lesson.get("gating", {})) == TYPE_DICTIONARY else {}
		var result: Array = []
		for action_value in gating.get("allowed_action_ids", []):
			var action_id := str(action_value).strip_edges()
			if not action_id.is_empty() and not result.has(action_id):
				result.append(action_id)
		return result
	return []


static func invitation_received(run_state: RunState) -> bool:
	return run_state != null and bool(run_state.narrative_flags.get(INVITATION_FLAG, false))


# Tutorial travel is an authored sequence, not a sample from the normal-run
# world-map candidate pool. Keep this presentation policy tutorial-scoped so
# normal route discovery and selection remain byte-identical.
static func travel_target_ids(run_state: RunState, candidate_ids: Array) -> Array:
	if run_state == null or not run_state.is_tutorial_run():
		return candidate_ids.duplicate()
	var environment_id := str(run_state.current_environment.get("archetype_id", run_state.current_world_node_id())).strip_edges()
	var authored_ids: Array = []
	match environment_id:
		APARTMENT_ID:
			authored_ids = [CORNER_STORE_ID]
		CORNER_STORE_ID:
			authored_ids = [GAS_CASINO_ID]
			if bool(run_state.narrative_flags.get("underground_tip", false)):
				authored_ids.append(UNDERGROUND_CASINO_ID)
		GAS_CASINO_ID:
			authored_ids = [UNDERGROUND_CASINO_ID]
		UNDERGROUND_CASINO_ID:
			if invitation_received(run_state):
				authored_ids = [GRAND_CASINO_ID]
		_:
			return candidate_ids.duplicate()
	var result: Array = []
	for target_id_value in authored_ids:
		var target_id := str(target_id_value)
		if candidate_ids.has(target_id) or (run_state.has_world_map() and WorldMap.is_node_visible(run_state.world_map, target_id)):
			result.append(target_id)
	for target_id_value in candidate_ids:
		var target_id := str(target_id_value)
		if target_id == environment_id or result.has(target_id) or not run_state.has_world_map():
			continue
		if WorldMap.node_state(run_state.world_map, target_id) == WorldMap.STATE_VISITED:
			result.append(target_id)
	return result
