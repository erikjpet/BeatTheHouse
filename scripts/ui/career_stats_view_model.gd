class_name CareerStatsViewModel
extends RefCounted


static func build(profile_inventory: ProfileInventory) -> Dictionary:
	var daily := _copy_dict(profile_inventory.daily_runs if profile_inventory != null else {})
	var lifetime := _copy_dict(profile_inventory.lifetime_stats if profile_inventory != null else {})
	var challenges := profile_inventory.completed_challenge_rows() if profile_inventory != null else []
	var history := _copy_array(profile_inventory.run_history if profile_inventory != null else [])
	var victories := _copy_dict(lifetime.get("victories_per_route", {}))
	var card_victories := int(victories.get("players_card_cashout", 0))
	var showdown_victories := int(victories.get("showdown", 0))
	var total_runs := int(lifetime.get("total_runs", 0))
	var total_victories := card_victories + showdown_victories
	var losses := maxi(0, total_runs - total_victories)
	return {
		"empty": total_runs <= 0 and history.is_empty(),
		"headline": [
			{"id": "runs", "label": "Runs", "value": str(total_runs), "detail": "%d finished climb%s" % [total_runs, "" if total_runs == 1 else "s"]},
			{"id": "victories", "label": "Wins", "value": str(total_victories), "detail": "%d card cashout / %d showdown" % [card_victories, showdown_victories]},
			{"id": "losses", "label": "Losses", "value": str(losses), "detail": "%d failed run%s recorded" % [losses, "" if losses == 1 else "s"]},
			{"id": "biggest", "label": "Biggest Win", "value": "$%d" % int(lifetime.get("biggest_single_win", 0)), "detail": "Largest single result stored in profile"},
		],
		"money": [
			{"label": "Bankroll won", "value": "$%d" % int(lifetime.get("total_bankroll_won", 0))},
			{"label": "Bankroll lost", "value": "$%d" % int(lifetime.get("total_bankroll_lost", 0))},
		],
		"routes": [
			{"id": "players_card_cashout", "label": "Players Card Cashout", "value": str(card_victories), "complete": card_victories > 0},
			{"id": "showdown", "label": "Rourke Showdown", "value": str(showdown_victories), "complete": showdown_victories > 0},
		],
		"daily": {
			"current_streak": int(daily.get("current_streak", 0)),
			"best_streak": int(daily.get("best_streak", 0)),
			"last_completed_date": str(daily.get("last_completed_date", "")),
		},
		"challenges": _challenge_rows(challenges),
		"history": _history_rows(history),
		"missing_stats": [
			"Per-game win rates are not persisted; the profile stores games played, but not per-game wins/losses.",
		],
	}


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
