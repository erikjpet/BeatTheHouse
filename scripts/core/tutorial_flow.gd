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


# A caught tutorial peek is a real outcome, but it branches to the table exit
# instead of pointing at count controls on a barred table.
static func apply_caught_transition(run_state: RunState, result: Dictionary) -> Dictionary:
	if run_state == null or not run_state.is_tutorial_run():
		return {}
	var caught := bool(result.get("dealer_caught_cheat", false)) or bool(result.get("blackjack_cheat_caught", false)) or bool(result.get("blackjack_table_barred", false))
	if not caught:
		return {}
	var completed: Dictionary = run_state.narrative_flags.get("tutorial_lessons_completed", {}) if typeof(run_state.narrative_flags.get("tutorial_lessons_completed", {})) == TYPE_DICTIONARY else {}
	for lesson_id in ["tutorial_blackjack_peek", "tutorial_blackjack_count_start", "tutorial_blackjack_count_all"]:
		completed[lesson_id] = true
	run_state.narrative_flags["tutorial_lessons_completed"] = completed
	run_state.narrative_flags["tutorial_caught_continue"] = true
	return {
		"continued": true,
		"next_lesson_id": "tutorial_leave_blackjack",
		"completed_lessons": completed.duplicate(true),
		"message": "The dealer caught the move and barred the table. The lesson continues: leave the table and scan the room.",
	}


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
		if typeof(value) == TYPE_DICTIONARY and _dictionary_has_progress(value):
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
