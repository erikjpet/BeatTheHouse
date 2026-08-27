class_name CareerStatsViewModel
extends RefCounted

const REQUIRED_GAME_DEFINITIONS := [
	{"id": "craps", "label": "Craps"},
	{"id": "coin_pusher", "label": "Quarter Falls"},
	{"id": "crew_draw_poker", "label": "Back-Room Poker"},
]


static func build(profile_inventory: ProfileInventory) -> Dictionary:
	var daily := _copy_dict(profile_inventory.daily_runs if profile_inventory != null else {})
	var lifetime := _copy_dict(profile_inventory.lifetime_stats if profile_inventory != null else {})
	var challenges := profile_inventory.completed_challenge_rows() if profile_inventory != null else []
	var history := _copy_array(profile_inventory.run_history if profile_inventory != null else [])
	var victories := _copy_dict(lifetime.get("victories_per_route", {}))
	var total_runs := int(lifetime.get("total_runs", 0))
	var total_victories := 0
	for count_value in victories.values():
		total_victories += maxi(0, int(count_value))
	var losses := maxi(0, total_runs - total_victories)
	var routes := _route_rows(victories)
	return {
		"empty": total_runs <= 0 and history.is_empty(),
		"headline": [
			{"id": "runs", "label": "Runs", "value": str(total_runs), "detail": "%d finished climb%s" % [total_runs, "" if total_runs == 1 else "s"]},
			{"id": "victories", "label": "Wins", "value": str(total_victories), "detail": "%d routes recorded" % _completed_route_count(routes)},
			{"id": "losses", "label": "Losses", "value": str(losses), "detail": "%d failed run%s recorded" % [losses, "" if losses == 1 else "s"]},
			{"id": "biggest", "label": "Biggest Win", "value": "$%d" % int(lifetime.get("biggest_single_win", 0)), "detail": "Largest single result stored in profile"},
		],
		"money": [
			{"label": "Bankroll won", "value": "$%d" % int(lifetime.get("total_bankroll_won", 0))},
			{"label": "Bankroll lost", "value": "$%d" % int(lifetime.get("total_bankroll_lost", 0))},
		],
		"routes": routes,
		"release_0_6": _release_ledger(lifetime),
		"daily": {
			"current_streak": int(daily.get("current_streak", 0)),
			"best_streak": int(daily.get("best_streak", 0)),
			"last_completed_date": str(daily.get("last_completed_date", "")),
		},
		"challenges": _challenge_rows(challenges),
		"history": _history_rows(history),
		"missing_stats": [
			"Older profiles begin the 0.6 rows, including the exact Crew roster, at zero. Earlier runs did not retain enough detail to rebuild them.",
			"Scenario aftermath counts recorded scenario choices. Unchosen room branches stay out of the book.",
		],
	}


static func route_definition_ids() -> Array:
	var result: Array = []
	for definition in RunState.terminal_victory_route_definitions():
		result.append(str(definition.get("profile_id", "")))
	return result


static func _route_rows(victories: Dictionary) -> Array:
	var rows: Array = []
	var known := {}
	for definition_value in RunState.terminal_victory_route_definitions():
		var definition: Dictionary = definition_value
		var route_id := str(definition.get("profile_id", ""))
		known[route_id] = true
		var count := maxi(0, int(victories.get(route_id, 0)))
		rows.append({"id": route_id, "label": str(definition.get("career_label", route_id.replace("_", " ").capitalize())), "value": str(count), "complete": count > 0})
	var historical_ids: Array[String] = []
	for route_value in victories.keys():
		var route_id := str(route_value).strip_edges()
		if not route_id.is_empty() and not known.has(route_id):
			historical_ids.append(route_id)
	historical_ids.sort()
	for route_id in historical_ids:
		var count := maxi(0, int(victories.get(route_id, 0)))
		rows.append({"id": route_id, "label": route_id.replace("_", " ").capitalize(), "value": str(count), "complete": count > 0, "historical": true})
	return rows


static func _completed_route_count(routes: Array) -> int:
	var count := 0
	for route in routes:
		if typeof(route) == TYPE_DICTIONARY and bool((route as Dictionary).get("complete", false)):
			count += 1
	return count


static func _release_ledger(lifetime: Dictionary) -> Array:
	var release := _copy_dict(lifetime.get(ProfileInventory.RELEASE_REPORTING_KEY, {}))
	return [
		{
			"id": "crew",
			"title": "Crew",
			"rows": _crew_lifetime_rows(release),
		},
		{
			"id": "world",
			"title": "World",
			"rows": [
				{"label": "Nights survived", "value": str(int(release.get("nights_survived", 0)))},
				{"label": "Scenarios experienced", "value": str(int(release.get("scenarios_experienced", 0)))},
				{"label": "Aftermath outcomes", "value": str(int(release.get("notable_aftermath_outcomes", 0)))},
				{"label": "Sweeps encountered", "value": str(int(release.get("sweeps_encountered", 0)))},
				{"label": "Rumors proved true", "value": str(int(release.get("rumors_proved_true", 0)))},
			],
		},
		{
			"id": "numbers",
			"title": "Numbers",
			"rows": [
				{"label": "Slips placed", "value": str(int(release.get("numbers_slips_placed", 0)))},
				{"label": "Hits", "value": str(int(release.get("numbers_hits", 0)))},
				{"label": "Rig routes used", "value": str(int(release.get("numbers_rig_runs", 0)))},
			],
		},
		{"id": "games", "title": "Games", "rows": _game_rows(_copy_dict(lifetime.get("games_played", {})))},
		{
			"id": "deliveries",
			"title": "Deliveries",
			"rows": [
				{"label": "Runs completed", "value": str(int(release.get("delivery_runs_completed", 0)))},
				{"label": "Packages lost", "value": str(int(release.get("delivery_packages_lost", 0)))},
			],
		},
	]


static func _crew_lifetime_rows(release: Dictionary) -> Array:
	var rows: Array = [
		{"label": "Runs on the path", "value": str(int(release.get("crew_path_runs", 0)))},
		{"label": "Highest standing", "value": str(release.get("highest_crew_standing", "stranger")).replace("_", " ").capitalize()},
		{"label": "Members met", "value": str(int(release.get("crew_members_met_unique", 0)))},
		{"label": "Jobs", "value": "%d completed / %d abandoned" % [int(release.get("crew_jobs_completed", 0)), int(release.get("crew_jobs_abandoned", 0))]},
	]
	var turn_resolutions := maxi(0, int(release.get("crew_turn_resolutions", 0)))
	if turn_resolutions > 0:
		rows.append({"label": "Turn endings", "value": str(turn_resolutions)})
	return rows


static func _game_rows(tallies: Dictionary) -> Array:
	var rows: Array = []
	var known := {}
	for definition in REQUIRED_GAME_DEFINITIONS:
		var game_id := str(definition.get("id", ""))
		known[game_id] = true
		rows.append({"id": game_id, "label": str(definition.get("label", game_id.replace("_", " ").capitalize())), "value": str(maxi(0, int(tallies.get(game_id, 0))))})
	var extra_ids: Array[String] = []
	for game_value in tallies.keys():
		var game_id := str(game_value).strip_edges()
		if not game_id.is_empty() and not known.has(game_id):
			extra_ids.append(game_id)
	extra_ids.sort()
	for game_id in extra_ids:
		rows.append({"id": game_id, "label": game_id.replace("_", " ").capitalize(), "value": str(maxi(0, int(tallies.get(game_id, 0))))})
	return rows


static func _history_rows(history: Array, limit: int = 8) -> Array:
	var rows: Array = []
	var count := mini(history.size(), limit)
	for index in range(count):
		var entry := _copy_dict(history[index])
		rows.append({
			"date": str(entry.get("completed_date", "")),
			"outcome": _outcome_text(entry),
			"bankroll": "$%d" % int(entry.get("final_bankroll", 0)),
			"day": "Day %d" % int(entry.get("day_count", 1)),
			"actions": "%d actions" % int(entry.get("duration_actions", 0)),
			"score": int(entry.get("score", 0)),
			"won": str(entry.get("outcome", "")) == "victory",
		})
	return rows


static func _challenge_rows(challenges: Array) -> Array:
	var rows: Array = []
	for challenge_value in challenges:
		var challenge := _copy_dict(challenge_value)
		var title := str(challenge.get("title", challenge.get("flag", "Challenge"))).strip_edges()
		if title.is_empty():
			title = "Challenge"
		rows.append({
			"title": title,
			"id": str(challenge.get("challenge_id", challenge.get("flag", ""))),
		})
	return rows


static func _outcome_text(entry: Dictionary) -> String:
	var outcome := str(entry.get("outcome", "")).capitalize()
	var route := str(entry.get("route", "")).replace("_", " ").capitalize()
	if route.is_empty() or route == outcome:
		return outcome
	return "%s - %s" % [outcome, route]


static func _copy_dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _copy_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
