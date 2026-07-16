class_name TerminalConsequenceViewModel
extends RefCounted


static func consequence_snapshot(run_state: RunState, data: Dictionary) -> Dictionary:
	if run_state == null:
		return {}
	var recent_result: Dictionary = data.get("recent_result", {})
	var deltas: Dictionary = recent_result.get("deltas", {})
	var bankroll_delta := int(data.get("recent_bankroll_delta", 0))
	var suspicion_delta := int(recent_result.get("suspicion_delta", deltas.get("suspicion_delta", 0)))
	var recent_message := str(data.get("recent_message", ""))
	var suspicion_cues: Array = data.get("suspicion_cues", [])
	var security_cues: Array = data.get("security_cues", [])
	var story_messages: Array = data.get("story_messages", [])
	var inventory_items: Array = data.get("inventory_items", [])
	var debt_items: Array = data.get("debt_items", [])
	var flag_labels: Array = data.get("flag_labels", [])
	var travel_choices: Array = data.get("travel_choices", [])
	var pressure: Dictionary = data.get("pressure", {})
	var presented_bankroll := int(data.get("presented_bankroll", run_state.bankroll))
	var has_recent := result_is_visible_consequence(recent_result, recent_message)
	var current_state_text := "Bankroll %d | %s | Status %s | %s | Debt %s | Gear %s | Routes %s" % [
		presented_bankroll, str(data.get("economy", "")), str(pressure.get("title", "")), run_state.alcohol_pressure_summary(),
		debt_summary(debt_items), inventory_summary(inventory_items), travel_summary(travel_choices),
	]
	var suspicion_text := "Heat: %s" % run_state.security_pressure_label().capitalize()
	if not suspicion_cues.is_empty():
		suspicion_text += " | %s" % str(suspicion_cues[0])
	elif not security_cues.is_empty():
		suspicion_text += " | %s" % str(security_cues[0])
	var context := data.duplicate(false)
	context["has_recent_consequence"] = has_recent
	context["recent_suspicion_delta"] = suspicion_delta
	return {
		"bankroll": presented_bankroll,
		"economy": run_state.economy(),
		"recent_bankroll_delta": bankroll_delta,
		"recent_suspicion_delta": suspicion_delta,
		"recent_result_message": recent_message,
		"suspicion_level": run_state.suspicion_level(),
		"drunk_level": run_state.drunk_level,
		"alcoholic_level": run_state.alcoholic_level,
		"baseline_luck": run_state.baseline_luck,
		"luck_modifier": run_state.effective_luck(),
		"alcohol_text": run_state.alcohol_pressure_summary(),
		"suspicion_cues": suspicion_cues,
		"security_cues": security_cues,
		"debt_items": debt_items,
		"debt_summary": debt_summary(debt_items),
		"inventory_items": inventory_items,
		"inventory_summary": inventory_summary(inventory_items),
		"flag_labels": flag_labels,
		"flag_summary": flag_summary(flag_labels),
		"story_messages": story_messages,
		"travel_available": not travel_choices.is_empty(),
		"travel_count": travel_choices.size(),
		"travel_summary": travel_summary(travel_choices),
		"run_status": run_state.run_status,
		"pressure": pressure,
		"pressure_text": pressure_status_text(pressure),
		"has_recent_consequence": has_recent,
		"current_state_text": current_state_text,
		"suspicion_text": suspicion_text,
		"recent_result_text": "Recent result: %s | Bankroll %+d | Heat %+d" % [recent_message if not recent_message.is_empty() else "No result yet.", bankroll_delta, suspicion_delta],
		"story_text": "Story: %s | Clues %s" % [" / ".join(story_messages) if not story_messages.is_empty() else "No story yet.", flag_summary(flag_labels)],
		"cards": consequence_cards(run_state, context),
	}


static func consequence_cards(run_state: RunState, context: Dictionary) -> Array:
	var recent_result: Dictionary = context.get("recent_result", {})
	if not bool(context.get("has_recent_consequence", false)):
		return []
	var deltas: Dictionary = recent_result.get("deltas", {})
	var message := str(context.get("recent_message", ""))
	var bankroll_delta := int(context.get("recent_bankroll_delta", 0))
	var suspicion_delta := int(context.get("recent_suspicion_delta", 0))
	var cards: Array = [{
		"title": outcome_card_title(recent_result),
		"tone": outcome_card_tone(recent_result, bankroll_delta, suspicion_delta),
		"lines": [message if not message.is_empty() else "No result yet.", "Bankroll now %d." % int(context.get("presented_bankroll", run_state.bankroll))],
	}]
	if not recent_result.is_empty() or bankroll_delta != 0:
		cards.append({"title": "Bankroll", "tone": "positive" if bankroll_delta >= 0 else "cost", "lines": ["Change %+d." % bankroll_delta, "Current bankroll %d." % int(context.get("presented_bankroll", run_state.bankroll)), str(context.get("economy", "")) + "."]})
	var suspicion_cues: Array = context.get("suspicion_cues", [])
	var security_cues: Array = context.get("security_cues", [])
	if suspicion_delta != 0 or not suspicion_cues.is_empty() or not security_cues.is_empty():
		cards.append({"title": "Risk", "tone": "risk", "lines": risk_card_lines(run_state, suspicion_delta, suspicion_cues, security_cues)})
	var alcohol_intake := int(deltas.get("alcohol_intake", 0))
	var drunk_delta := int(deltas.get("drunk_delta", 0))
	var alcoholic_delta := int(deltas.get("alcoholic_delta", 0))
	var luck_delta := int(deltas.get("baseline_luck_delta", 0))
	if alcohol_intake != 0 or drunk_delta != 0 or alcoholic_delta != 0 or luck_delta != 0 or run_state.drunk_level > 0 or run_state.alcoholic_level > 0 or run_state.baseline_luck != 0:
		cards.append({"title": "Alcohol", "tone": "risk" if run_state.alcoholic_level > run_state.drunk_level else "positive", "lines": alcohol_card_lines(run_state, alcohol_intake, drunk_delta, alcoholic_delta, luck_delta)})
	var debt_changes := _copy_array(deltas.get("debt_changes", []))
	var debt_items: Array = context.get("debt_items", [])
	if not debt_changes.is_empty() or not debt_items.is_empty():
		cards.append({"title": "Debt", "tone": "cost", "lines": debt_card_lines(debt_changes, debt_items)})
	var inventory_add := _copy_array(deltas.get("inventory_add", []))
	var inventory_remove := _copy_array(deltas.get("inventory_remove", []))
	var inventory_items: Array = context.get("inventory_items", [])
	if not inventory_add.is_empty() or not inventory_remove.is_empty() or not inventory_items.is_empty():
		cards.append({"title": "Items", "tone": "positive", "lines": inventory_card_lines(inventory_add, inventory_remove, inventory_items, context.get("item_labeler", Callable()))})
	var travel_hooks := _copy_array(deltas.get("travel_hooks_add", []))
	var travel_changes: Dictionary = deltas.get("travel_changes", {})
	var travel_choices: Array = context.get("travel_choices", [])
	if not travel_hooks.is_empty() or not travel_changes.is_empty() or not travel_choices.is_empty():
		cards.append({"title": "Travel", "tone": "neutral", "lines": travel_card_lines(travel_hooks, travel_changes, travel_choices, context.get("travel_labeler", Callable()))})
	var pressure: Dictionary = context.get("pressure", {})
	if should_show_pressure_card(pressure):
		cards.append({"title": str(pressure.get("title", "Run pressure")), "tone": pressure_card_tone(pressure), "lines": pressure_card_lines(pressure)})
	var story_messages: Array = context.get("story_messages", [])
	if not message.is_empty() or not story_messages.is_empty():
		cards.append({"title": "Story", "tone": "story", "lines": story_card_lines(message, story_messages)})
	cards.append({"title": "Next", "tone": "next", "lines": next_action_lines(bool(context.get("current_game_active", false)), travel_choices)})
	return cards


static func environment_result_feedback(result: Dictionary, message: String, current_game_embeds_result: bool, max_chars: int, player_facing_text: Callable) -> Dictionary:
	if current_game_embeds_result:
		return {"visible": false}
	var deltas: Dictionary = result.get("deltas", {})
	var bankroll_delta := int(result.get("bankroll_delta", deltas.get("bankroll_delta", 0)))
	var suspicion_delta := int(result.get("suspicion_delta", deltas.get("suspicion_delta", 0)))
	if message.strip_edges().is_empty() and bankroll_delta == 0 and suspicion_delta == 0:
		return {"visible": false}
	return {
		"visible": true,
		"anchor": "environment_panel_top_right",
		"interaction_kind": "informational_result",
		"dismissible": true,
		"title": "Result",
		"text": environment_result_feedback_text(message, bankroll_delta, suspicion_delta, max_chars, player_facing_text),
		"message": message,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"object_id": outcome_object_id(result),
		"result": result.duplicate(true),
	}


static func environment_result_feedback_text(message: String, bankroll_delta: int, suspicion_delta: int, max_chars: int, player_facing_text: Callable) -> String:
	var base := str(player_facing_text.call(message) if not player_facing_text.is_null() else message).strip_edges()
	if base.is_empty():
		base = "Outcome recorded."
	var delta_parts: Array[String] = []
	if bankroll_delta != 0:
		delta_parts.append("$%+d" % bankroll_delta)
	if suspicion_delta != 0:
		delta_parts.append("Heat %+d" % suspicion_delta)
	if delta_parts.is_empty():
		return base.left(max_chars)
	var suffix := "  %s" % " / ".join(delta_parts)
	return ("%s%s" % [base.left(maxi(12, max_chars - suffix.length())), suffix]).left(max_chars)


static func result_is_visible_consequence(result: Dictionary, recent_message: String = "") -> bool:
	if result.is_empty() or ["game_enter", "game_actions"].has(str(result.get("type", ""))):
		return false
	var deltas: Dictionary = result.get("deltas", {})
	if int(result.get("bankroll_delta", deltas.get("bankroll_delta", 0))) != 0 or int(result.get("suspicion_delta", deltas.get("suspicion_delta", 0))) != 0:
		return true
	for key in ["alcohol_intake", "drunk_delta", "alcoholic_delta", "baseline_luck_delta"]:
		if int(deltas.get(key, 0)) != 0:
			return true
	if bool(result.get("ended", deltas.get("ended", false))):
		return true
	for key in ["debt_changes", "inventory_add", "inventory_remove", "travel_hooks_add", "story_log", "messages", "item_hooks", "event_hooks"]:
		if not _copy_array(deltas.get(key, [])).is_empty():
			return true
	for key in ["flags_set", "travel_changes"]:
		var value: Variant = deltas.get(key, {})
		if typeof(value) == TYPE_DICTIONARY and not (value as Dictionary).is_empty():
			return true
	return not recent_message.strip_edges().is_empty() or ["game_action", "game_action_summary", "item_effect", "item_sale", "event", "travel", "service_hook", "lender_hook", "game_hook", "story_summary"].has(str(result.get("type", "")))


static func outcome_card_title(result: Dictionary) -> String:
	if result.is_empty():
		return "Ready"
	match str(result.get("type", "")):
		"game_action", "game_action_summary":
			return "Risky play resolved" if str(result.get("action_kind", "")) == "cheat" else "Play resolved"
		"item_effect": return "Item gained"
		"item_sale": return "Item sold"
		"event": return "Event resolved"
		"travel": return "Travel complete"
		"service_hook": return "Service resolved"
		"lender_hook": return "Debt changed"
		"game_hook": return "Cashout resolved"
	return "Outcome"


static func outcome_card_tone(_result: Dictionary, bankroll_delta: int, suspicion_delta: int) -> String:
	if suspicion_delta > 0: return "risk"
	if bankroll_delta < 0: return "cost"
	if bankroll_delta > 0: return "positive"
	return "neutral"


static func should_show_pressure_card(pressure: Dictionary) -> bool:
	return ["failed", "recovery", "distressed", "volatile", "victory"].has(str(pressure.get("state", "")))


static func pressure_card_tone(pressure: Dictionary) -> String:
	match str(pressure.get("state", "")):
		"victory": return "positive"
		"failed": return "risk"
		"recovery", "distressed", "volatile": return "cost"
	return "neutral"


static func pressure_card_lines(pressure: Dictionary) -> Array:
	var lines: Array = []
	var summary := str(pressure.get("summary", ""))
	if not summary.is_empty(): lines.append(summary)
	if bool(pressure.get("failed", false)): lines.append("Start over or load a saved run.")
	elif bool(pressure.get("recovery_available", false)): lines.append("Use recovery before pushing the run.")
	return lines


static func risk_card_lines(run_state: RunState, suspicion_delta: int, suspicion_cues: Array, security_cues: Array) -> Array:
	var lines: Array = []
	if suspicion_delta > 0: lines.append("Heat rises %+d: %s." % [suspicion_delta, run_state.security_pressure_label()])
	elif suspicion_delta < 0: lines.append("Heat cools %+d: %s." % [suspicion_delta, run_state.security_pressure_label()])
	else: lines.append("No new heat.")
	if not suspicion_cues.is_empty(): lines.append(str(suspicion_cues[0]) + ".")
	elif not security_cues.is_empty(): lines.append("Room cue: %s" % str(security_cues[0]))
	return lines


static func alcohol_card_lines(run_state: RunState, alcohol_intake: int, drunk_delta: int, alcoholic_delta: int, luck_delta: int) -> Array:
	var lines: Array = []
	if alcohol_intake > 0:
		lines.append("Drink +%d pending; need +%d." % [alcohol_intake, alcohol_intake])
	elif drunk_delta != 0 or alcoholic_delta != 0:
		var parts: Array = []
		if drunk_delta != 0: parts.append("drunk %+d" % drunk_delta)
		if alcoholic_delta != 0: parts.append("need %+d" % alcoholic_delta)
		lines.append(", ".join(parts).capitalize() + ".")
	if luck_delta != 0: lines.append("Baseline luck %+d." % luck_delta)
	lines.append(run_state.alcohol_pressure_summary())
	lines.append("Drunk %d, need %d, luck %+d." % [run_state.drunk_level, run_state.alcoholic_level, run_state.effective_luck()])
	return lines


static func debt_card_lines(debt_changes: Array, debt_items: Array) -> Array:
	var lines: Array = []
	if not debt_changes.is_empty(): lines.append("New pressure from %d lender%s." % [debt_changes.size(), "" if debt_changes.size() == 1 else "s"])
	if debt_items.is_empty(): lines.append("No active debt remains.")
	else:
		lines.append("Current debt: %s." % debt_summary(debt_items))
		lines.append(str(debt_items[0]))
	return lines


static func inventory_card_lines(inventory_add: Array, inventory_remove: Array, inventory_items: Array, labeler: Callable) -> Array:
	var lines: Array = []
	if not inventory_add.is_empty(): lines.append("Gained: %s." % _call_list_label(labeler, inventory_add))
	if not inventory_remove.is_empty(): lines.append("Used: %s." % _call_list_label(labeler, inventory_remove))
	lines.append("Inventory: %s." % inventory_summary(inventory_items))
	return lines


static func travel_card_lines(travel_hooks: Array, travel_changes: Dictionary, travel_choices: Array, labeler: Callable) -> Array:
	var lines: Array = []
	if not travel_hooks.is_empty(): lines.append("New routes: %s." % _call_list_label(labeler, travel_hooks))
	if not travel_changes.is_empty(): lines.append("Routes changed.")
	lines.append("No route is available right now." if travel_choices.is_empty() else "Available: %s." % travel_summary(travel_choices))
	return lines


static func story_card_lines(recent_message: String, story_messages: Array) -> Array:
	var lines: Array = []
	if not recent_message.is_empty(): lines.append(recent_message)
	for value in story_messages:
		var text := str(value)
		if not text.is_empty() and not lines.has(text): lines.append(text)
		if lines.size() >= 3: break
	return lines


static func next_action_lines(current_game_active: bool, travel_choices: Array) -> Array:
	var lines: Array = ["Keep playing, change your stake, or go back to the environment." if current_game_active else "Choose a game, check events, review items, or save the run."]
	if not travel_choices.is_empty(): lines.append("Travel is available when you are ready to move on.")
	return lines


static func suspicion_cue_view_list(run_state: RunState, label_from_id: Callable) -> Array:
	var result: Array = []
	var cues: Array = run_state.suspicion.get("cues", [])
	for index in range(cues.size() - 1, -1, -1):
		if typeof(cues[index]) != TYPE_DICTIONARY: continue
		var cue: Dictionary = cues[index]
		var amount := int(cue.get("amount", 0))
		var label := _call_label(label_from_id, str(cue.get("id", "cue")).replace(":", " "))
		if amount > 0: result.append("%s notices you (%+d heat)" % [label.left(36), amount])
		elif amount < 0: result.append("%s eases pressure (%+d heat)" % [label.left(36), amount])
		else: result.append(label.left(44))
		if result.size() >= 2: break
	return result


static func security_cue_view_list(run_state: RunState) -> Array:
	var result: Array = []
	for cue in _copy_array(run_state.current_environment.get("suspicion_cues", [])):
		if not str(cue).is_empty(): result.append(str(cue))
	return result


static func inventory_view_list(run_state: RunState, library: ContentLibrary, label_from_id: Callable) -> Array:
	var result: Array = []
	for item_id in _string_array(run_state.inventory):
		var definition := library.item(item_id) if library != null else {}
		result.append(str(definition.get("display_name", _call_label(label_from_id, item_id))) if not definition.is_empty() else _call_label(label_from_id, item_id))
	return result


static func debt_view_list(run_state: RunState, label_from_id: Callable) -> Array:
	var result: Array = []
	for value in _copy_array(run_state.debt):
		if typeof(value) == TYPE_DICTIONARY: result.append(debt_entry_view_line(value as Dictionary, label_from_id))
	return result


static func debt_entry_view_line(data: Dictionary, label_from_id: Callable) -> String:
	var label := _call_label(label_from_id, str(data.get("lender_id", data.get("id", "debt"))))
	var balance := int(data.get("balance", 0))
	var status := _call_label(label_from_id, str(data.get("status", "active")))
	var schedule := debt_schedule_text(data)
	match str(data.get("debt_kind", "cash")):
		"favor": return "%s wants %d favor%s, %s (%s)" % [label, balance, "" if balance == 1 else "s", schedule, status]
		"pawn": return "%s holds %s; borrowed %d, buy-back %d, %s (%s)" % [label, str(data.get("collateral_item_name", data.get("collateral_item_id", "collateral"))), maxi(0, int(data.get("principal", balance))), balance, schedule, status]
	return "%s balance %d, %s (%s)" % [label, balance, schedule, status]


static func debt_schedule_text(data: Dictionary) -> String:
	var status := str(data.get("status", "active"))
	if status == "favor_due": return "favor due now"
	if status == "overdue":
		var pressure := int(data.get("next_pressure_turns", 0))
		return "next pressure in %d turn%s" % [pressure, "" if pressure == 1 else "s"] if pressure > 0 else "overdue now"
	var turns := int(data.get("turns_remaining", data.get("deadline_turns", 0)))
	return "due now" if turns <= 0 else "due in %d turn%s" % [turns, "" if turns == 1 else "s"]


static func flag_view_list(run_state: RunState, label_from_id: Callable) -> Array:
	var result: Array = []
	for key in run_state.narrative_flags.keys():
		if flag_value_is_visible(run_state.narrative_flags[key]): result.append(_call_label(label_from_id, str(key)))
	result.sort()
	return result


static func flag_value_is_visible(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL: return value
		TYPE_INT: return int(value) != 0
		TYPE_FLOAT: return not is_zero_approx(float(value))
		TYPE_STRING: return not str(value).strip_edges().is_empty()
		TYPE_ARRAY: return not (value as Array).is_empty()
		TYPE_DICTIONARY: return not (value as Dictionary).is_empty()
	return value != null


static func story_message_view_list(run_state: RunState, library: ContentLibrary, label_from_id: Callable, player_facing_text: Callable, game_display_name: Callable) -> Array:
	var result: Array = []
	for index in range(run_state.story_log.size() - 1, -1, -1):
		if typeof(run_state.story_log[index]) != TYPE_DICTIONARY: continue
		result.append(story_entry_label(run_state.story_log[index] as Dictionary, library, label_from_id, player_facing_text, game_display_name))
		if result.size() >= 3: break
	return result


static func story_entry_label(entry: Dictionary, _library: ContentLibrary, label_from_id: Callable, player_facing_text: Callable, game_display_name: Callable) -> String:
	var message := str(player_facing_text.call(str(entry.get("message", ""))) if not player_facing_text.is_null() else entry.get("message", ""))
	if not message.is_empty(): return message
	match str(entry.get("type", "story")):
		"game_action": return "%s %+d" % [str(game_display_name.call(str(entry.get("game_id", ""))) if not game_display_name.is_null() else "Game"), int(entry.get("bankroll_delta", 0))]
		"item_purchase": return "Bought %s" % str(entry.get("item_name", entry.get("item_id", "item")))
		"item_sale": return "Sold %s" % str(entry.get("item_name", entry.get("item_id", "item")))
		"travel": return "Traveled to %s" % str(entry.get("to_environment_name", entry.get("to_archetype_id", "destination")))
		"event": return "Event: %s" % str(entry.get("event_id", entry.get("id", "event")))
	return _call_label(label_from_id, str(entry.get("type", "story")))


static func result_from_story_log(entries: Array, library: ContentLibrary, label_from_id: Callable, player_facing_text: Callable, game_display_name: Callable) -> Dictionary:
	for index in range(entries.size() - 1, -1, -1):
		if typeof(entries[index]) != TYPE_DICTIONARY: continue
		var entry: Dictionary = entries[index]
		var message := str(entry.get("message", ""))
		if message.is_empty(): message = story_entry_label(entry, library, label_from_id, player_facing_text, game_display_name)
		return GameModule.build_action_result({"ok": true, "type": str(entry.get("type", "story_summary")), "source_id": str(entry.get("id", entry.get("game_id", entry.get("item_id", "")))), "action_id": str(entry.get("action_id", "")), "bankroll_delta": int(entry.get("bankroll_delta", 0)), "suspicion_delta": int(entry.get("suspicion_delta", 0)), "deltas": {"bankroll_delta": int(entry.get("bankroll_delta", 0)), "suspicion_delta": int(entry.get("suspicion_delta", 0)), "messages": [message], "ended": bool(entry.get("ended", false))}, "message": message, "environment_id": str(entry.get("environment_id", ""))})
	return {}


static func outcome_object_id(result: Dictionary) -> String:
	if result.is_empty(): return ""
	match str(result.get("type", "")):
		"game_action", "game_action_summary", "game_enter":
			var id := str(result.get("game_id", result.get("source_id", "")))
			return "game:%s" % id if not id.is_empty() else ""
		"item_effect", "item_sale":
			var id := str(result.get("item_id", result.get("source_id", "")))
			return "item:%s" % id if not id.is_empty() else ""
		"event":
			var id := str(result.get("event_id", result.get("source_id", "")))
			return "event:%s" % id if not id.is_empty() else ""
		"service_hook", "lender_hook":
			var prefix := "service" if str(result.get("type", "")) == "service_hook" else "lender"
			var id := str(result.get("source_id", ""))
			return "%s:%s" % [prefix, id] if not id.is_empty() else ""
		"game_hook":
			var source_id := str(result.get("source_id", ""))
			var parts := source_id.split(":")
			if parts.size() >= 2: return "game_hook:%s:%s" % [str(parts[0]), str(parts[1])]
			var game_id := str(result.get("game_id", ""))
			return "game:%s" % game_id if not game_id.is_empty() else ""
	return ""


static func outcome_message(result: Dictionary, player_facing_text: Callable) -> String:
	var message := str(player_facing_text.call(str(result.get("message", ""))) if not player_facing_text.is_null() else result.get("message", ""))
	if not message.is_empty(): return message
	var messages := _copy_array(result.get("messages", []))
	return str(player_facing_text.call(str(messages[0])) if not player_facing_text.is_null() else messages[0]) if not messages.is_empty() else ""


static func pressure_status_text(pressure: Dictionary) -> String:
	if pressure.is_empty(): return ""
	var title := str(pressure.get("title", ""))
	var summary := str(pressure.get("summary", ""))
	if title.is_empty(): return summary
	return title if summary.is_empty() or summary == title else "%s: %s" % [title, summary]


static func run_summary_text(state: RunState, pressure: Dictionary) -> String:
	if state == null: return "No active run."
	var environment := state.current_environment
	return "%s | Bankroll %d | %s | Heat %d | Story %d | Clues %d | Routes %d" % [str(environment.get("display_name", environment.get("id", "No environment"))), state.bankroll, pressure_status_text(pressure), state.suspicion_level(), state.story_log_entry_count(), state.narrative_flags.size(), run_travel_target_count(state)]


static func run_travel_target_count(state: RunState) -> int:
	var result: Array = []
	if state == null: return 0
	for source in [state.current_environment.get("next_archetypes", []), state.current_environment.get("travel_hooks", [])]:
		for target_id in _string_array(source):
			if not result.has(target_id): result.append(target_id)
	return result.size()


static func game_result_from_story_log(entries: Array, game_display_name: Callable, label_from_id: Callable) -> Dictionary:
	for index in range(entries.size() - 1, -1, -1):
		if typeof(entries[index]) != TYPE_DICTIONARY: continue
		var entry: Dictionary = entries[index]
		if str(entry.get("type", "")) != "game_action": continue
		var game_id := str(entry.get("game_id", ""))
		var game_name := str(game_display_name.call(game_id))
		var action_label := _call_label(label_from_id, str(entry.get("action_id", "action")))
		var bankroll_delta := int(entry.get("bankroll_delta", 0))
		var suspicion_delta := int(entry.get("suspicion_delta", 0))
		var message := "Last saved play: %s, %s. Bankroll %+d, heat %+d." % [game_name, action_label, bankroll_delta, suspicion_delta]
		var result := GameModule.build_action_result({"ok": true, "type": "game_action_summary", "source_id": game_id, "game_id": game_id, "action_id": str(entry.get("action_id", "")), "action_kind": "summary", "bankroll_delta": bankroll_delta, "suspicion_delta": suspicion_delta, "deltas": {"bankroll_delta": bankroll_delta, "suspicion_delta": suspicion_delta, "messages": [message]}, "won": bool(entry.get("won", false)), "environment_id": str(entry.get("environment_id", "")), "message": message})
		result["display_name"] = "%s Saved Result" % game_name
		result["summary_source"] = "saved_story_log"
		return result
	return {}


static func debt_summary(items: Array) -> String:
	if items.is_empty(): return "none"
	return str(items[0]) if items.size() == 1 else "%d active debts" % items.size()


static func inventory_summary(items: Array) -> String:
	if items.is_empty(): return "empty"
	return ", ".join(items) if items.size() <= 3 else "%s +%d" % [", ".join(items.slice(0, 3)), items.size() - 3]


static func flag_summary(labels: Array) -> String:
	if labels.is_empty(): return "none"
	return ", ".join(labels) if labels.size() <= 3 else "%s +%d" % [", ".join(labels.slice(0, 3)), labels.size() - 3]


static func travel_summary(choices: Array) -> String:
	if choices.is_empty(): return "none"
	var labels: Array = []
	for value in choices:
		if typeof(value) == TYPE_DICTIONARY: labels.append(str((value as Dictionary).get("label", (value as Dictionary).get("id", ""))))
	if labels.is_empty(): return "%d available" % choices.size()
	return ", ".join(labels) if labels.size() <= 2 else "%s +%d" % [", ".join(labels.slice(0, 2)), labels.size() - 2]


static func _call_label(callback: Callable, value: String) -> String:
	return str(callback.call(value)) if not callback.is_null() else value.replace("_", " ").capitalize()


static func _call_list_label(callback: Callable, values: Array) -> String:
	return str(callback.call(values)) if not callback.is_null() else ", ".join(values)


static func _copy_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY: return result
	for entry in value:
		if not str(entry).is_empty(): result.append(str(entry))
	return result
