class_name ProfileInventory
extends RefCounted

# Profile-level inventory lives outside RunState and survives between runs.

const INVENTORY_PATH := "user://profile_inventory.json"
const INVENTORY_PATH_ENV := "BTH_PROFILE_INVENTORY_PATH"
const PersistencePathsScript := preload("res://scripts/core/persistence_paths.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const SCHEMA_VERSION := 6
const RUN_HISTORY_LIMIT := 20
const RELEASE_REPORTING_KEY := "release_0_6"
const CREW_STANDING_IDS := ["stranger", "marker", "associate", "made", "inner_circle"]
const REFERENCE_CHIP_ID := "profile_poker_chip"
const ACTIVE_SCRATCH_TICKET_IDS := ["two_fer", "lucky_7s", "tic_tac_gold", "crossword_corner", "bonus_bingo", "high_roller_holdem", "golden_vault"]
const REFERENCE_CHIP := {
	"id": REFERENCE_CHIP_ID,
	"display_name": "Rain City Poker Chip",
	"description": "A neon casino chip kept in your profile stash.",
	"icon_key": "poker_chip",
	"quantity": 1,
}

var items: Array = []
var challenge_completions: Dictionary = {}
var run_history: Array = []
var daily_runs: Dictionary = {}
var lifetime_stats: Dictionary = {}
var act_seam: Dictionary = {}
var scratch_ticket_types_discovered: Array = []
var scratch_ticket_collection_acknowledged := false
var tips_seen: Dictionary = {}
var tutorial_completed := false
var loaded_from_disk := false
var loaded_schema_version := 0
var tutorial_field_present := false
var _unknown_fields: Dictionary = {}


func load() -> void:
	loaded_from_disk = false
	loaded_schema_version = 0
	tutorial_field_present = false
	from_dict({})
	var path := store_path()
	if not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var parsed: Variant = json.data
	if typeof(parsed) == TYPE_DICTIONARY:
		from_dict(parsed)
		loaded_from_disk = true


func save() -> Error:
	var path := store_path()
	var absolute_path := ProjectSettings.globalize_path(path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK:
		return directory_error
	var temp_path := "%s.tmp" % absolute_path
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	if FileAccess.file_exists(absolute_path):
		var remove_error := DirAccess.remove_absolute(absolute_path)
		if remove_error != OK:
			return remove_error
	return DirAccess.rename_absolute(temp_path, absolute_path)


func to_dict() -> Dictionary:
	var data := _unknown_fields.duplicate(true)
	data.merge({
		"schema_version": SCHEMA_VERSION,
		"act": 1,
		"items": items.duplicate(true),
		"challenge_completions": challenge_completions.duplicate(true),
		"run_history": run_history.duplicate(true),
		"daily_runs": daily_runs.duplicate(true),
		"lifetime_stats": lifetime_stats.duplicate(true),
		"act_seam": act_seam.duplicate(true),
		"scratch_ticket_types_discovered": scratch_ticket_types_discovered.duplicate(),
		"scratch_ticket_collection_acknowledged": scratch_ticket_collection_acknowledged,
		"tips_seen": tips_seen.duplicate(true),
		"tutorial_completed": tutorial_completed,
	}, true)
	return data


func from_dict(data: Dictionary) -> void:
	loaded_schema_version = int(data.get("schema_version", 0))
	tutorial_field_present = data.has("tutorial_completed")
	_unknown_fields = data.duplicate(true)
	for key in ["schema_version", "act", "items", "challenge_completions", "completed_challenge_flags", "run_history", "daily_runs", "lifetime_stats", "act_seam", "scratch_ticket_types_discovered", "scratch_ticket_collection_acknowledged", "tips_seen", "tutorial_completed"]:
		_unknown_fields.erase(key)
	items = []
	challenge_completions = _normalize_challenge_completions(data.get("challenge_completions", data.get("completed_challenge_flags", {})))
	run_history = _normalize_run_history(data.get("run_history", []))
	daily_runs = _normalize_daily_runs(data.get("daily_runs", {}))
	lifetime_stats = _normalize_lifetime_stats(data.get("lifetime_stats", {}))
	act_seam = _normalize_act_seam(data.get("act_seam", {}))
	scratch_ticket_types_discovered = []
	for type_id_value in _normalize_string_set(data.get("scratch_ticket_types_discovered", [])):
		var type_id := str(type_id_value)
		if ACTIVE_SCRATCH_TICKET_IDS.has(type_id):
			scratch_ticket_types_discovered.append(type_id)
	scratch_ticket_collection_acknowledged = bool(data.get("scratch_ticket_collection_acknowledged", false)) and scratch_ticket_collection_complete()
	tips_seen = _normalize_seen_map(data.get("tips_seen", {}))
	tutorial_completed = bool(data.get("tutorial_completed", false))
	var loaded: Variant = data.get("items", [])
	if typeof(loaded) != TYPE_ARRAY:
		return
	for item in loaded:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_data := item as Dictionary
		var item_id := str(item_data.get("id", "")).strip_edges()
		if item_id.is_empty():
			continue
		items.append({
			"id": item_id,
			"display_name": str(item_data.get("display_name", item_id.capitalize())),
			"description": str(item_data.get("description", "")),
			"icon_key": str(item_data.get("icon_key", "")),
			"quantity": max(1, int(item_data.get("quantity", 1))),
		})


func legacy_without_tutorial_state() -> bool:
	return loaded_from_disk and not tutorial_field_present


static func store_path() -> String:
	var override := OS.get_environment(INVENTORY_PATH_ENV).strip_edges()
	if not override.is_empty():
		return override
	return PersistencePathsScript.file_path(INVENTORY_PATH, "profile_inventory.json")


func reference_chip() -> Dictionary:
	return REFERENCE_CHIP.duplicate(true)


func add_reference_chip(quantity: int = 1) -> void:
	var chip: Dictionary = reference_chip()
	add_item(chip, quantity)


func has_seen_tip(lesson_id: String) -> bool:
	return bool(tips_seen.get(lesson_id.strip_edges(), false))


func mark_tip_seen(lesson_id: String) -> bool:
	var normalized := lesson_id.strip_edges()
	if normalized.is_empty() or has_seen_tip(normalized):
		return false
	tips_seen[normalized] = true
	return true


func reset_tips() -> void:
	tips_seen.clear()


func add_item(item: Dictionary, quantity: int = 1) -> void:
	var item_id: String = str(item.get("id", "")).strip_edges()
	if item_id.is_empty():
		return
	var add_quantity: int = max(1, quantity)
	for entry in items:
		if typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("id", "")) == item_id:
			entry["quantity"] = int((entry as Dictionary).get("quantity", 1)) + add_quantity
			return
	var copy: Dictionary = item.duplicate(true)
	copy["quantity"] = add_quantity
	items.append(copy)


func has_item(item_id: String) -> bool:
	return item_quantity(item_id) > 0


func item_quantity(item_id: String) -> int:
	for entry in items:
		if typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("id", "")) == item_id:
			return int((entry as Dictionary).get("quantity", 0))
	return 0


func discover_scratch_ticket_type(type_id: String) -> bool:
	var normalized := type_id.strip_edges()
	if not ACTIVE_SCRATCH_TICKET_IDS.has(normalized) or scratch_ticket_types_discovered.has(normalized):
		return false
	scratch_ticket_types_discovered.append(normalized)
	scratch_ticket_types_discovered.sort()
	return true


func has_discovered_scratch_ticket_type(type_id: String) -> bool:
	return scratch_ticket_types_discovered.has(type_id.strip_edges())


func scratch_ticket_discovery_count() -> int:
	return scratch_ticket_types_discovered.size()


func scratch_ticket_collection_complete() -> bool:
	return scratch_ticket_types_discovered.size() >= ACTIVE_SCRATCH_TICKET_IDS.size()


func mark_scratch_ticket_collection_acknowledged() -> bool:
	if scratch_ticket_collection_acknowledged or not scratch_ticket_collection_complete():
		return false
	scratch_ticket_collection_acknowledged = true
	return true


func mark_challenge_completed(completion_flag: String, challenge_id: String = "", title: String = "") -> void:
	var flag := completion_flag.strip_edges()
	if flag.is_empty():
		return
	var entry := {
		"completed": true,
		"challenge_id": challenge_id.strip_edges(),
		"title": title.strip_edges(),
		"completed_unix": int(Time.get_unix_time_from_system()),
	}
	challenge_completions[flag] = entry


func completed_challenge_rows() -> Array:
	var rows: Array = []
	var flags := challenge_completions.keys()
	flags.sort()
	for flag_value in flags:
		var flag := str(flag_value)
		var entry := _copy_dict(challenge_completions.get(flag, {}))
		if not bool(entry.get("completed", false)):
			continue
		rows.append({
			"flag": flag,
			"challenge_id": str(entry.get("challenge_id", "")),
			"title": str(entry.get("title", flag.capitalize())),
			"completed_unix": maxi(0, int(entry.get("completed_unix", 0))),
		})
	return rows


func record_run_result(snapshot: Dictionary) -> Dictionary:
	var entry := _normalize_run_history_entry(snapshot)
	if entry.is_empty():
		return {"ok": false, "message": "Run result snapshot was not terminal."}
	run_history.push_front(entry)
	while run_history.size() > RUN_HISTORY_LIMIT:
		run_history.pop_back()
	_record_lifetime_stats(entry)
	_record_daily_result(entry)
	return {"ok": true, "entry": entry.duplicate(true)}


func record_act_seam(payload: Dictionary) -> Dictionary:
	var normalized := _normalize_act_seam(payload)
	if normalized.is_empty():
		return {"ok": false, "message": "Act seam payload was empty."}
	act_seam = normalized
	return {"ok": true, "act_seam": act_seam.duplicate(true)}


func has_challenge_completion(completion_flag: String) -> bool:
	var flag := completion_flag.strip_edges()
	if flag.is_empty() or not challenge_completions.has(flag):
		return false
	var value: Variant = challenge_completions.get(flag, {})
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	if typeof(value) == TYPE_DICTIONARY:
		return bool((value as Dictionary).get("completed", false))
	return false


func _record_lifetime_stats(entry: Dictionary) -> void:
	var stats := _normalize_lifetime_stats(lifetime_stats)
	stats["total_runs"] = maxi(0, int(stats.get("total_runs", 0))) + 1
	var outcome := str(entry.get("outcome", ""))
	if outcome == "victory":
		var victories := _copy_dict(stats.get("victories_per_route", {}))
		var route := str(entry.get("route", "victory"))
		victories[route] = maxi(0, int(victories.get(route, 0))) + 1
		stats["victories_per_route"] = victories
	var biggest := maxi(0, int(stats.get("biggest_single_win", 0)))
	stats["biggest_single_win"] = maxi(biggest, maxi(0, int(entry.get("biggest_single_win", 0))))
	stats["total_bankroll_won"] = maxi(0, int(stats.get("total_bankroll_won", 0))) + maxi(0, int(entry.get("bankroll_won", 0)))
	stats["total_bankroll_lost"] = maxi(0, int(stats.get("total_bankroll_lost", 0))) + maxi(0, int(entry.get("bankroll_lost", 0)))
	var tallies := _copy_dict(stats.get("games_played", {}))
	for game_id_value in _copy_dict(entry.get("games_played", {})).keys():
		var game_id := str(game_id_value).strip_edges()
		if game_id.is_empty():
			continue
		tallies[game_id] = maxi(0, int(tallies.get(game_id, 0))) + maxi(0, int(_copy_dict(entry.get("games_played", {})).get(game_id_value, 0)))
	stats["games_played"] = tallies
	var release := _normalize_release_lifetime_stats(stats.get(RELEASE_REPORTING_KEY, {}))
	var run_release := _copy_dict(entry.get(RELEASE_REPORTING_KEY, {}))
	var crew := _copy_dict(run_release.get("crew", {}))
	var world := _copy_dict(run_release.get("world", {}))
	var numbers := _copy_dict(run_release.get("numbers", {}))
	var deliveries := _copy_dict(run_release.get("deliveries", {}))
	release["crew_path_runs"] = int(release.get("crew_path_runs", 0)) + (1 if bool(crew.get("path_walked", false)) else 0)
	release["highest_crew_standing"] = _higher_crew_standing(str(release.get("highest_crew_standing", "stranger")), str(crew.get("standing", "stranger")))
	var run_members := _normalize_reporting_rows(crew.get("members_met", []))
	var member_ids_met := _normalize_crew_member_ids(release.get("crew_member_ids_met", []))
	for member in run_members:
		var member_id := str(member.get("id", ""))
		if CrewStateModelScript.MEMBER_IDS.has(member_id) and not member_ids_met.has(member_id):
			member_ids_met.append(member_id)
	member_ids_met = _normalize_crew_member_ids(member_ids_met)
	# Retain the cumulative contact counter for schema compatibility, but expose
	# the exact unique roster count as "Members met" on the career surface.
	release["crew_members_met"] = int(release.get("crew_members_met", 0)) + run_members.size()
	release["crew_member_ids_met"] = member_ids_met
	release["crew_members_met_unique"] = maxi(int(release.get("crew_members_met_unique", 0)), member_ids_met.size())
	release["crew_jobs_completed"] = int(release.get("crew_jobs_completed", 0)) + maxi(0, int(crew.get("jobs_completed", 0)))
	release["crew_jobs_abandoned"] = int(release.get("crew_jobs_abandoned", 0)) + maxi(0, int(crew.get("jobs_abandoned", 0)))
	var approved_turn_resolution := str(entry.get("outcome", "")) == "victory" \
		and str(entry.get("route", "")) == "crew_heist" \
		and crew.has("turn_resolution") \
		and not str(crew.get("turn_resolution", "")).strip_edges().is_empty()
	release["crew_turn_resolutions"] = int(release.get("crew_turn_resolutions", 0)) + (1 if approved_turn_resolution else 0)
	release["nights_survived"] = int(release.get("nights_survived", 0)) + maxi(0, int(world.get("nights_survived", 0)))
	release["scenarios_experienced"] = int(release.get("scenarios_experienced", 0)) + _copy_array(world.get("scenarios", [])).size()
	release["notable_aftermath_outcomes"] = int(release.get("notable_aftermath_outcomes", 0)) + _copy_array(world.get("notable_outcomes", [])).size()
	release["sweeps_encountered"] = int(release.get("sweeps_encountered", 0)) + maxi(0, int(world.get("sweeps_encountered", 0)))
	release["rumors_proved_true"] = int(release.get("rumors_proved_true", 0)) + maxi(0, int(world.get("rumors_proved_true", 0)))
	release["numbers_slips_placed"] = int(release.get("numbers_slips_placed", 0)) + maxi(0, int(numbers.get("slips_placed", 0)))
	release["numbers_hits"] = int(release.get("numbers_hits", 0)) + maxi(0, int(numbers.get("hits", 0)))
	release["numbers_rig_runs"] = int(release.get("numbers_rig_runs", 0)) + (1 if bool(numbers.get("rig_route_used", false)) else 0)
	release["delivery_runs_completed"] = int(release.get("delivery_runs_completed", 0)) + maxi(0, int(deliveries.get("runs_completed", 0)))
	release["delivery_packages_lost"] = int(release.get("delivery_packages_lost", 0)) + maxi(0, int(deliveries.get("packages_lost", 0)))
	stats[RELEASE_REPORTING_KEY] = release
	lifetime_stats = stats


func _record_daily_result(entry: Dictionary) -> void:
	if str(entry.get("challenge_mode", "")) != "daily" and str(entry.get("daily_id", "")).strip_edges().is_empty():
		return
	var state := _normalize_daily_runs(daily_runs)
	var completion_date := str(entry.get("completed_date", "")).strip_edges()
	if completion_date.is_empty():
		return
	var last_date := str(state.get("last_completed_date", ""))
	var current_streak := maxi(0, int(state.get("current_streak", 0)))
	# Daily streaks use the player's local system calendar date at completion;
	# same-day repeats update best result but do not add another streak day.
	if last_date == completion_date:
		pass
	elif not last_date.is_empty() and _date_ordinal(completion_date) == _date_ordinal(last_date) + 1:
		current_streak += 1
	else:
		current_streak = 1
	state["current_streak"] = current_streak
	state["best_streak"] = maxi(maxi(0, int(state.get("best_streak", 0))), current_streak)
	state["last_completed_date"] = completion_date
	state["last_daily_id"] = str(entry.get("daily_id", ""))
	var best_result := _copy_dict(state.get("best_result", {}))
	if best_result.is_empty() or _daily_entry_score(entry) > _daily_entry_score(best_result):
		state["best_result"] = entry.duplicate(true)
	daily_runs = state


func _normalize_challenge_completions(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	var source: Dictionary = value
	for key_value in source.keys():
		var flag := str(key_value).strip_edges()
		if flag.is_empty():
			continue
		var completion_value: Variant = source.get(key_value, {})
		if typeof(completion_value) == TYPE_BOOL:
			if bool(completion_value):
				result[flag] = {"completed": true}
		elif typeof(completion_value) == TYPE_DICTIONARY:
			var entry: Dictionary = completion_value
			if bool(entry.get("completed", false)):
				result[flag] = {
					"completed": true,
					"challenge_id": str(entry.get("challenge_id", "")).strip_edges(),
					"title": str(entry.get("title", "")).strip_edges(),
					"completed_unix": maxi(0, int(entry.get("completed_unix", 0))),
				}
	return result


func _normalize_run_history(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value as Array:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry := _normalize_run_history_entry(entry_value as Dictionary)
		if not entry.is_empty():
			result.append(entry)
		if result.size() >= RUN_HISTORY_LIMIT:
			break
	return result


func _normalize_run_history_entry(value: Dictionary) -> Dictionary:
	var outcome := str(value.get("outcome", "")).strip_edges()
	if outcome.is_empty():
		var status := str(value.get("run_status", "")).strip_edges()
		if status == "ended":
			outcome = "victory"
		elif status == "failed":
			outcome = "failure"
	if not ["victory", "failure"].has(outcome):
		return {}
	var route := str(value.get("route", value.get("failure_reason", outcome))).strip_edges()
	if route.is_empty():
		route = outcome
	var completed_date := str(value.get("completed_date", "")).strip_edges()
	if completed_date.is_empty():
		completed_date = _today_date_string()
	var result := value.duplicate(true)
	result.merge({
		"seed": str(value.get("seed", value.get("seed_text", ""))).strip_edges(),
		"route": route,
		"outcome": outcome,
		"failure_reason": str(value.get("failure_reason", "")).strip_edges(),
		"final_bankroll": maxi(0, int(value.get("final_bankroll", value.get("bankroll", 0)))),
		"day_count": maxi(1, int(value.get("day_count", 1))),
		"duration_actions": maxi(0, int(value.get("duration_actions", 0))),
		"completed_date": completed_date,
		"completed_unix": maxi(0, int(value.get("completed_unix", int(Time.get_unix_time_from_system())))),
		"challenge_mode": str(value.get("challenge_mode", "")).strip_edges(),
		"challenge_id": str(value.get("challenge_id", "")).strip_edges(),
		"daily_id": str(value.get("daily_id", "")).strip_edges(),
		"score": maxi(0, int(value.get("score", 0))),
		"bankroll_delta": int(value.get("bankroll_delta", 0)),
		"bankroll_won": maxi(0, int(value.get("bankroll_won", maxi(0, int(value.get("bankroll_delta", 0)))))),
		"bankroll_lost": maxi(0, int(value.get("bankroll_lost", maxi(0, -int(value.get("bankroll_delta", 0)))))),
		"biggest_single_win": maxi(0, int(value.get("biggest_single_win", 0))),
		"games_played": _normalize_int_dictionary(value.get("games_played", {})),
	}, true)
	if value.has(RELEASE_REPORTING_KEY):
		result[RELEASE_REPORTING_KEY] = _normalize_release_run_stats(value.get(RELEASE_REPORTING_KEY, {}))
	return result


func _normalize_daily_runs(value: Variant) -> Dictionary:
	var source := _copy_dict(value)
	return {
		"current_streak": maxi(0, int(source.get("current_streak", 0))),
		"best_streak": maxi(0, int(source.get("best_streak", 0))),
		"last_completed_date": str(source.get("last_completed_date", "")).strip_edges(),
		"last_daily_id": str(source.get("last_daily_id", "")).strip_edges(),
		"best_result": _copy_dict(source.get("best_result", {})),
	}


func _normalize_lifetime_stats(value: Variant) -> Dictionary:
	var source := _copy_dict(value)
	var result := source.duplicate(true)
	_normalize_whole_number_values(result)
	result.merge({
		"total_runs": maxi(0, int(source.get("total_runs", 0))),
		"victories_per_route": _normalize_int_dictionary(source.get("victories_per_route", {})),
		"biggest_single_win": maxi(0, int(source.get("biggest_single_win", 0))),
		"total_bankroll_won": maxi(0, int(source.get("total_bankroll_won", 0))),
		"total_bankroll_lost": maxi(0, int(source.get("total_bankroll_lost", 0))),
		"games_played": _normalize_int_dictionary(source.get("games_played", {})),
	}, true)
	if source.has(RELEASE_REPORTING_KEY):
		result[RELEASE_REPORTING_KEY] = _normalize_release_lifetime_stats(source.get(RELEASE_REPORTING_KEY, {}))
	return result


static func _normalize_release_run_stats(value: Variant) -> Dictionary:
	var source := _copy_dict(value)
	var result := source.duplicate(true)
	var crew := _copy_dict(source.get("crew", {}))
	var normalized_crew := crew.duplicate(true)
	normalized_crew.merge({
		"path_walked": bool(crew.get("path_walked", false)),
		"standing": _normalize_crew_standing(str(crew.get("standing", "stranger"))),
		"members_met": _normalize_reporting_rows(crew.get("members_met", [])),
		"jobs_completed": maxi(0, int(crew.get("jobs_completed", 0))),
		"jobs_abandoned": maxi(0, int(crew.get("jobs_abandoned", 0))),
	}, true)
	var turn_resolution := str(crew.get("turn_resolution", "")).strip_edges()
	if turn_resolution.is_empty():
		normalized_crew.erase("turn_resolution")
	else:
		normalized_crew["turn_resolution"] = turn_resolution
	var world := _copy_dict(source.get("world", {}))
	var normalized_world := world.duplicate(true)
	normalized_world.merge({
		"nights_survived": maxi(0, int(world.get("nights_survived", 0))),
		"scenarios": _normalize_reporting_rows(world.get("scenarios", [])),
		"notable_outcomes": _normalize_reporting_rows(world.get("notable_outcomes", [])),
		"sweeps_encountered": maxi(0, int(world.get("sweeps_encountered", 0))),
		"rumors_proved_true": maxi(0, int(world.get("rumors_proved_true", 0))),
	}, true)
	var numbers := _copy_dict(source.get("numbers", {}))
	var normalized_numbers := numbers.duplicate(true)
	normalized_numbers.merge({
		"slips_placed": maxi(0, int(numbers.get("slips_placed", 0))),
		"hits": maxi(0, int(numbers.get("hits", 0))),
		"rig_route_used": bool(numbers.get("rig_route_used", false)),
	}, true)
	var deliveries := _copy_dict(source.get("deliveries", {}))
	var normalized_deliveries := deliveries.duplicate(true)
	normalized_deliveries.merge({
		"runs_completed": maxi(0, int(deliveries.get("runs_completed", 0))),
		"packages_lost": maxi(0, int(deliveries.get("packages_lost", 0))),
	}, true)
	result["crew"] = normalized_crew
	result["world"] = normalized_world
	result["numbers"] = normalized_numbers
	result["deliveries"] = normalized_deliveries
	return result


static func _normalize_release_lifetime_stats(value: Variant) -> Dictionary:
	var source := _copy_dict(value)
	var result := source.duplicate(true)
	_normalize_whole_number_values(result)
	result["highest_crew_standing"] = _normalize_crew_standing(str(source.get("highest_crew_standing", "stranger")))
	var member_ids_met := _normalize_crew_member_ids(source.get("crew_member_ids_met", []))
	result["crew_member_ids_met"] = member_ids_met
	result["crew_members_met_unique"] = maxi(maxi(0, int(source.get("crew_members_met_unique", 0))), member_ids_met.size())
	for key in [
		"crew_path_runs", "crew_members_met", "crew_jobs_completed", "crew_jobs_abandoned", "crew_turn_resolutions",
		"nights_survived", "scenarios_experienced", "notable_aftermath_outcomes", "sweeps_encountered", "rumors_proved_true",
		"numbers_slips_placed", "numbers_hits", "numbers_rig_runs", "delivery_runs_completed", "delivery_packages_lost",
	]:
		result[key] = maxi(0, int(source.get(key, 0)))
	return result


static func _normalize_whole_number_values(value: Dictionary) -> void:
	# JSON restores numbers as floats. Lifetime dictionaries are forward-compatible,
	# so canonicalize unknown whole-number counters too instead of losing them or
	# allowing an otherwise identical save/load round trip to change their type.
	for key in value.keys():
		var entry: Variant = value.get(key)
		if typeof(entry) == TYPE_FLOAT and float(entry) == float(int(entry)):
			value[key] = int(entry)


static func _normalize_crew_member_ids(value: Variant) -> Array:
	var source: Array = value if typeof(value) == TYPE_ARRAY else []
	var result: Array = []
	for member_id in CrewStateModelScript.MEMBER_IDS:
		if source.has(member_id):
			result.append(member_id)
	return result


static func _normalize_reporting_rows(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for row_value in value as Array:
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row := (row_value as Dictionary).duplicate(true)
		var row_id := str(row.get("id", "")).strip_edges()
		var label := str(row.get("label", row_id.replace("_", " ").capitalize())).strip_edges()
		if row_id.is_empty() and label.is_empty():
			continue
		row["id"] = row_id
		row["label"] = label
		result.append(row)
	return result


static func _normalize_crew_standing(value: String) -> String:
	return value if CREW_STANDING_IDS.has(value) else "stranger"


static func _higher_crew_standing(a: String, b: String) -> String:
	var normalized_a := _normalize_crew_standing(a)
	var normalized_b := _normalize_crew_standing(b)
	return normalized_b if CREW_STANDING_IDS.find(normalized_b) > CREW_STANDING_IDS.find(normalized_a) else normalized_a


static func _normalize_int_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	var source: Dictionary = value
	for key_value in source.keys():
		var key := str(key_value).strip_edges()
		if key.is_empty():
			continue
		result[key] = maxi(0, int(source.get(key_value, 0)))
	return result


static func _normalize_string_set(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value as Array:
		var entry := str(entry_value).strip_edges()
		if not entry.is_empty() and not result.has(entry):
			result.append(entry)
	result.sort()
	return result


static func _normalize_seen_map(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) == TYPE_DICTIONARY:
		for key_value in (value as Dictionary).keys():
			var key := str(key_value).strip_edges()
			if not key.is_empty() and bool((value as Dictionary).get(key_value, false)):
				result[key] = true
	elif typeof(value) == TYPE_ARRAY:
		for key_value in value:
			var key := str(key_value).strip_edges()
			if not key.is_empty():
				result[key] = true
	return result


static func _normalize_act_seam(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = value
	var route := str(source.get("victory_route", source.get("route", ""))).strip_edges()
	if route.is_empty():
		return {}
	return {
		"schema_version": maxi(1, int(source.get("schema_version", 1))),
		"source_act": maxi(1, int(source.get("source_act", source.get("act", 1)))),
		"target_act": maxi(2, int(source.get("target_act", 2))),
		"victory_route": route,
		"demo_victory_route": str(source.get("demo_victory_route", "")).strip_edges(),
		"final_bankroll_band": str(source.get("final_bankroll_band", "walking_money")).strip_edges(),
		"story_flags": _copy_dict(source.get("story_flags", {})),
		"route_payload": _copy_dict(source.get("route_payload", {})),
	}


static func _today_date_string() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [int(now.get("year", 1970)), int(now.get("month", 1)), int(now.get("day", 1))]


static func _daily_entry_score(entry: Dictionary) -> int:
	var score := maxi(0, int(entry.get("score", 0)))
	if score > 0:
		return score
	return maxi(0, int(entry.get("final_bankroll", 0)))


static func _date_ordinal(date_text: String) -> int:
	var parts := date_text.split("-")
	if parts.size() != 3:
		return 0
	var year := int(parts[0])
	var month := clampi(int(parts[1]), 1, 12)
	var day := clampi(int(parts[2]), 1, 31)
	var days := day
	for previous_month in range(1, month):
		days += _days_in_month(year, previous_month)
	for previous_year in range(1970, year):
		days += 366 if _is_leap_year(previous_year) else 365
	return days


static func _days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			return 29 if _is_leap_year(year) else 28
		_:
			return 30


static func _is_leap_year(year: int) -> bool:
	return year % 400 == 0 or (year % 4 == 0 and year % 100 != 0)


static func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


static func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)
