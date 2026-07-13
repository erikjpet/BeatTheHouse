class_name RunJournalViewModel
extends RefCounted

const VisualStyle := preload("res://scripts/ui/visual_style.gd")


static func entry_view_list(run_state: RunState, callbacks: Dictionary) -> Array:
	var result: Array = []
	if run_state == null:
		return result
	var entry_index := 1
	for entry_value in run_state.story_log:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry_data := entry_value as Dictionary
		var view := _entry_view(entry_data, entry_index, callbacks)
		if view.is_empty():
			continue
		result.append(view)
		entry_index += 1
	if run_state.is_terminal() and not _has_terminal_entry(result):
		var terminal_entry := _terminal_entry(run_state, entry_index, callbacks)
		if not terminal_entry.is_empty():
			result.append(terminal_entry)
	return result


static func summary_text(entries: Array) -> String:
	if entries.is_empty():
		return "Read-only record. Story beats appear here as the run develops."
	return "Read-only record: %d beat%s, oldest first." % [entries.size(), "" if entries.size() == 1 else "s"]


static func category_color(category: String) -> Color:
	match category:
		"travel":
			return VisualStyle.TEAL
		"item":
			return VisualStyle.AMBER
		"debt", "heat":
			return VisualStyle.PINK_2
		"boss", "showdown", "terminal":
			return VisualStyle.YELLOW
		"objective":
			return VisualStyle.CYAN
		"event":
			return VisualStyle.ORANGE
		"game":
			return VisualStyle.CYAN_2
		_:
			return VisualStyle.SOFT


static func _entry_view(entry: Dictionary, entry_index: int, callbacks: Dictionary) -> Dictionary:
	var category := _category_for_entry(entry)
	var title := _title_for_entry(entry, category, callbacks)
	var body := _call_string(callbacks, "story_entry_label", [entry])
	if body.strip_edges().is_empty():
		body = title
	var detail_lines := _detail_lines(entry, callbacks)
	return {
		"index": entry_index,
		"type": str(entry.get("type", "story")),
		"category": category,
		"title": title,
		"body": _call_string(callbacks, "player_facing_text", [body]),
		"detail_lines": detail_lines,
		"terminal": _story_entry_is_terminal(entry),
	}


static func _category_for_entry(entry: Dictionary) -> String:
	var entry_type := str(entry.get("type", "story"))
	var heat_delta := int(entry.get("suspicion_delta", entry.get("heat_delta", 0)))
	if entry_type == "grand_casino_high_roller_ready":
		return "objective"
	if entry_type == "grand_casino_heat_reroute" or entry_type == "demo_finale_triggered":
		return "boss"
	if entry_type == "grand_casino_showdown_arrival":
		return "showdown"
	if entry_type == "demo_victory" or entry_type == "demo_finale_result" or entry_type == "run_abandoned":
		return "terminal"
	if heat_delta > 0 or entry_type.find("heat") != -1:
		return "heat"
	if entry_type == "travel":
		return "travel"
	if entry_type.begins_with("item_") or not _copy_array(entry.get("inventory_add", [])).is_empty() or not _copy_array(entry.get("inventory_remove", [])).is_empty():
		return "item"
	if entry_type.find("debt") != -1 or entry_type.find("lender") != -1 or not _copy_array(entry.get("debt_changes", [])).is_empty():
		return "debt"
	if entry_type == "event" or not str(entry.get("event_id", "")).is_empty():
		return "event"
	if entry_type == "game_action" or not str(entry.get("game_id", "")).is_empty():
		return "game"
	return "story"


static func _title_for_entry(entry: Dictionary, category: String, callbacks: Dictionary) -> String:
	var entry_type := str(entry.get("type", "story"))
	if category == "heat":
		return "Heat Spike"
	match entry_type:
		"grand_casino_high_roller_ready":
			return "High-Roller Review"
		"grand_casino_heat_reroute":
			return "Rourke's Attention"
		"grand_casino_showdown_arrival":
			return "Back Room"
		"demo_finale_triggered":
			return "The House Calls"
		"demo_finale_result":
			return "Showdown Outcome" if str(entry.get("event_id", "")) == RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID else "Terminal Result"
		"demo_victory":
			return "Demo Victory"
		"run_abandoned":
			return "Run Abandoned"
		"travel":
			return "Travel"
		"item_purchase":
			return "Item Bought"
		"item_sale":
			return "Item Sold"
		"item_use", "active_item":
			return "Item Used"
		"event":
			return "Event"
		"game_action":
			var bankroll_delta := int(entry.get("bankroll_delta", 0))
			if bankroll_delta > 0:
				return "Notable Win"
			if bankroll_delta < 0:
				return "Notable Loss"
			return "Game Result"
		_:
			if category == "debt":
				return "Debt"
			if category == "boss":
				return "Boss Floor Attention"
			return _call_string(callbacks, "label_from_id", [entry_type])


static func _detail_lines(entry: Dictionary, callbacks: Dictionary) -> Array:
	var lines: Array = []
	var venue := _environment_label(entry, callbacks)
	if not venue.is_empty():
		lines.append("Venue: %s" % venue)
	var bankroll_delta := int(entry.get("bankroll_delta", 0))
	if bankroll_delta != 0:
		lines.append("Bankroll %+d" % bankroll_delta)
	var heat_delta := int(entry.get("suspicion_delta", entry.get("heat_delta", 0)))
	if heat_delta != 0:
		lines.append("Heat %+d" % heat_delta)
	elif entry.has("heat"):
		lines.append("Heat %d" % int(entry.get("heat", 0)))
	var branch := str(entry.get("branch", entry.get("finale_branch", ""))).strip_edges()
	if not branch.is_empty():
		lines.append("Branch: %s" % _call_string(callbacks, "label_from_id", [branch]))
	var event_id := str(entry.get("event_id", "")).strip_edges()
	if not event_id.is_empty():
		lines.append("Event: %s" % _call_string(callbacks, "label_from_id", [event_id]))
	var item_id := str(entry.get("item_name", entry.get("item_id", ""))).strip_edges()
	if not item_id.is_empty():
		lines.append("Item: %s" % _call_string(callbacks, "label_from_id", [item_id]))
	var game_id := str(entry.get("game_id", "")).strip_edges()
	if not game_id.is_empty():
		lines.append("Game: %s" % _call_string(callbacks, "game_display_name", [game_id]))
	var attention_sources := _copy_array(entry.get("attention_sources", []))
	if not attention_sources.is_empty():
		lines.append("Attention: %s" % _label_list(attention_sources, callbacks))
	var debt_changes := _copy_array(entry.get("debt_changes", []))
	if not debt_changes.is_empty():
		lines.append("Debt changed")
	var inventory_add := _copy_array(entry.get("inventory_add", []))
	if not inventory_add.is_empty():
		lines.append("Gained: %s" % _label_list(inventory_add, callbacks))
	var inventory_remove := _copy_array(entry.get("inventory_remove", []))
	if not inventory_remove.is_empty():
		lines.append("Used: %s" % _label_list(inventory_remove, callbacks))
	return lines


static func _environment_label(entry: Dictionary, callbacks: Dictionary) -> String:
	var display_name := str(entry.get("environment_name", entry.get("to_environment_name", ""))).strip_edges()
	if not display_name.is_empty():
		return display_name
	var environment_id := str(entry.get("environment_id", entry.get("to_environment_id", ""))).strip_edges()
	if not environment_id.is_empty():
		return _call_string(callbacks, "label_from_id", [environment_id])
	var archetype_id := str(entry.get("environment_archetype_id", entry.get("to_archetype_id", ""))).strip_edges()
	if not archetype_id.is_empty():
		return _call_string(callbacks, "label_from_id", [archetype_id])
	return ""


static func _label_list(values: Array, callbacks: Dictionary) -> String:
	var labels: Array = []
	for value in values:
		labels.append(_call_string(callbacks, "label_from_id", [str(value)]))
	return ", ".join(labels)


static func _has_terminal_entry(entries: Array) -> bool:
	for entry_value in entries:
		if typeof(entry_value) == TYPE_DICTIONARY and bool((entry_value as Dictionary).get("terminal", false)):
			return true
	return false


static func _story_entry_is_terminal(entry: Dictionary) -> bool:
	var entry_type := str(entry.get("type", ""))
	return bool(entry.get("ended", false)) or entry_type == "demo_victory" or entry_type == "demo_finale_result" or entry_type == "run_abandoned"


static func _terminal_entry(run_state: RunState, entry_index: int, callbacks: Dictionary) -> Dictionary:
	if run_state == null or not run_state.is_terminal():
		return {}
	var title := "Run Ended"
	var body := "This run is over."
	if run_state.run_status == RunState.RUN_STATUS_ENDED:
		title = "Demo Victory" if bool(run_state.narrative_flags.get("demo_victory", false)) else "Run Ended"
		body = run_state.current_demo_victory_message() if bool(run_state.narrative_flags.get("demo_victory", false)) else "This run is over."
	elif run_state.run_status == RunState.RUN_STATUS_FAILED:
		var failure := _call_dict(callbacks, "failure_summary_snapshot", [])
		title = str(failure.get("title", "Run Failed"))
		body = str(failure.get("message", run_state.run_failure_message))
	return {
		"index": entry_index,
		"type": "terminal_result",
		"category": "terminal",
		"title": title,
		"body": _call_string(callbacks, "player_facing_text", [body]),
		"detail_lines": [
			"Final bankroll %d" % run_state.bankroll,
			"Heat %d" % run_state.suspicion_level(),
		],
		"terminal": true,
	}


static func _call_string(callbacks: Dictionary, key: String, args: Array) -> String:
	var callback: Callable = callbacks.get(key, Callable())
	if callback.is_null():
		return ""
	return str(callback.callv(args))


static func _call_dict(callbacks: Dictionary, key: String, args: Array) -> Dictionary:
	var callback: Callable = callbacks.get(key, Callable())
	if callback.is_null():
		return {}
	var value: Variant = callback.callv(args)
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _copy_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
