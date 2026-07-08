class_name ProfileInventory
extends RefCounted

# Profile-level inventory lives outside RunState and survives between runs.

const INVENTORY_PATH := "user://profile_inventory.json"
const INVENTORY_PATH_ENV := "BTH_PROFILE_INVENTORY_PATH"
const SCHEMA_VERSION := 2
const RUN_HISTORY_LIMIT := 20
const REFERENCE_CHIP_ID := "profile_poker_chip"
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
var _unknown_fields: Dictionary = {}


func load() -> void:
	from_dict({})
	var path := store_path()
	if not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		from_dict(parsed)


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
		"items": items.duplicate(true),
		"challenge_completions": challenge_completions.duplicate(true),
		"run_history": run_history.duplicate(true),
		"daily_runs": daily_runs.duplicate(true),
		"lifetime_stats": lifetime_stats.duplicate(true),
	}, true)
	return data


func from_dict(data: Dictionary) -> void:
	_unknown_fields = data.duplicate(true)
	for key in ["schema_version", "items", "challenge_completions", "completed_challenge_flags", "run_history", "daily_runs", "lifetime_stats"]:
		_unknown_fields.erase(key)
	items = []
	challenge_completions = _normalize_challenge_completions(data.get("challenge_completions", data.get("completed_challenge_flags", {})))
	run_history = _normalize_run_history(data.get("run_history", []))
	daily_runs = _normalize_daily_runs(data.get("daily_runs", {}))
	lifetime_stats = _normalize_lifetime_stats(data.get("lifetime_stats", {}))
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


static func store_path() -> String:
	var override := OS.get_environment(INVENTORY_PATH_ENV).strip_edges()
	if not override.is_empty():
		return override
	return INVENTORY_PATH


func reference_chip() -> Dictionary:
	return REFERENCE_CHIP.duplicate(true)


func add_reference_chip(quantity: int = 1) -> void:
	var chip: Dictionary = reference_chip()
	add_item(chip, quantity)


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
	return {
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
	}


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
	return {
		"total_runs": maxi(0, int(source.get("total_runs", 0))),
		"victories_per_route": _normalize_int_dictionary(source.get("victories_per_route", {})),
		"biggest_single_win": maxi(0, int(source.get("biggest_single_win", 0))),
		"total_bankroll_won": maxi(0, int(source.get("total_bankroll_won", 0))),
		"total_bankroll_lost": maxi(0, int(source.get("total_bankroll_lost", 0))),
		"games_played": _normalize_int_dictionary(source.get("games_played", {})),
	}


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
