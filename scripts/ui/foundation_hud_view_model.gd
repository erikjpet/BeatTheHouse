class_name FoundationHudViewModel
extends RefCounted


static func run_status_model(run_state: RunState, data: Dictionary) -> Dictionary:
	if run_state == null:
		return {}
	var pressure: Dictionary = data.get("pressure", {})
	var objective: Dictionary = data.get("demo_objective", {})
	var pit_boss: Dictionary = data.get("pit_boss_watch", {})
	var guidance := objective_guidance_view(pressure, objective, data.get("next_for_state", {}))
	var recent_result: Dictionary = data.get("recent_result", {})
	var deltas: Dictionary = recent_result.get("deltas", {})
	var bankroll_delta := int(data.get("bankroll_delta", recent_result.get("bankroll_delta", deltas.get("bankroll_delta", 0))))
	var heat_delta := int(recent_result.get("suspicion_delta", deltas.get("suspicion_delta", 0)))
	var debt_items: Array = data.get("debt_items", [])
	var inventory_items: Array = data.get("inventory_items", [])
	var environment := run_state.current_environment
	var bankroll := int(data.get("presented_bankroll", run_state.bankroll))
	var bankroll_text := "[$] Bankroll %d" % bankroll
	if bankroll_delta != 0:
		bankroll_text += " (%+d)" % bankroll_delta
	var heat_meter := hud_meter(run_state.suspicion_level(), 100, 10)
	var heat_text := "[HEAT] Risk: %s %s" % [heat_meter, run_state.security_pressure_label().capitalize()]
	if heat_delta != 0:
		heat_text += " (%+d)" % heat_delta
	var drunk_meter := hud_meter(run_state.drunk_level, 100, 8)
	var speed_percent := run_state.drunk_time_scale_percent()
	var alcohol_text := "[DRINK] %s %s Luck %+d" % [run_state.alcohol_condition_label().capitalize(), drunk_meter, run_state.effective_luck()]
	if run_state.drunk_level > 0:
		alcohol_text += " Time %d%%" % speed_percent
	var pending_drink := run_state.pending_drunk_absorption_amount()
	if pending_drink > 0:
		alcohol_text += " (+%d pending)" % pending_drink
	var player_text: Callable = data.get("player_facing_text", Callable())
	var debt_text := "[DEBT] %s" % hud_debt_text(debt_items, player_text)
	var run_text := "[RUN] %s" % hud_run_status_text(run_state, pressure)
	var clock_text := "[TIME] %s" % run_state.clock_display_text()
	var save_text := hud_save_text(bool(data.get("has_save", false)), str(data.get("save_status_message", "")), player_text)
	var goal_text := hud_goal_text(run_state, pressure, objective, player_text)
	var label_from_id: Callable = data.get("label_from_id", Callable())
	var environment_text := "[ENV] %s / %s" % [
		hud_short(str(environment.get("display_name", "Environment")), 28, player_text),
		_call_string(label_from_id, str(environment.get("kind", environment.get("archetype_id", "room")))),
	]
	var inventory_text := "[GEAR] %s" % hud_inventory_text(inventory_items, player_text)
	var economy_text := "Cash: %s" % str(data.get("economy_text", ""))
	var heat_summary_text := "Heat: %s" % run_state.security_pressure_label().capitalize()
	var pit_boss_text := pit_boss_hud_text(pit_boss)
	var alcohol_summary_text := "Alcohol: %s" % run_state.alcohol_pressure_summary()
	var next_objective: Dictionary = data.get("next_objective", {})
	var next_hint := str(next_objective.get("hint", ""))
	var next_text := "Next: %s" % next_hint if not next_hint.is_empty() else "Next: inspect the room"
	var pressure_text := objective_pressure_text(pressure)
	var objective_parts := ["[GOAL] Goal: %s" % goal_text, economy_text, heat_summary_text, alcohol_summary_text, environment_text, inventory_text, next_text]
	if not pressure_text.is_empty():
		objective_parts.insert(3, "Status: %s" % hud_short(pressure_text, 38, player_text))
	if not pit_boss_text.is_empty():
		objective_parts.insert(4, pit_boss_text)
	var home_text := hud_home_text(run_state, player_text)
	if not home_text.is_empty():
		objective_parts.insert(5, home_text)
	return {
		"status_text": "%s  %s  %s  %s  %s  %s" % [clock_text, bankroll_text, heat_text, alcohol_text, debt_text, run_text],
		"objective_text": " | ".join(objective_parts),
		"save_text": save_text,
		"clock_text": clock_text,
		"home_text": home_text,
		"bankroll_text": bankroll_text,
		"bankroll": bankroll,
		"bankroll_delta": bankroll_delta,
		"heat_text": heat_text,
		"heat_meter": heat_meter,
		"heat_level": run_state.suspicion_level(),
		"heat_delta": heat_delta,
		"alcohol_text": alcohol_text,
		"alcohol_summary_text": alcohol_summary_text,
		"drunk_level": run_state.drunk_level,
		"drunk_time_scale": run_state.drunk_time_scale(),
		"drunk_time_scale_percent": speed_percent,
		"drunk_world_speed_percent": speed_percent,
		"pending_drunk_absorption": pending_drink,
		"alcoholic_level": run_state.alcoholic_level,
		"baseline_luck": run_state.baseline_luck,
		"luck_modifier": run_state.effective_luck(),
		"debt_text": debt_text,
		"environment_text": environment_text,
		"inventory_text": inventory_text,
		"run_text": run_text,
		"goal_text": goal_text,
		"objective_state": str(guidance.get("state", "")),
		"objective_guidance": guidance,
		"demo_objective": objective,
		"pit_boss_watch": pit_boss,
		"next_text": next_text,
		"next_objective": next_objective,
		"pressure": pressure,
		"run_status": run_state.run_status,
	}


static func meta_status_model(home: Dictionary) -> Dictionary:
	var gold := int(home.get("gold_balance", 0))
	var upgrade := _copy_dict(home.get("upgrade", {}))
	var next_price := maxi(0, int(upgrade.get("price", 0))) if not upgrade.is_empty() else 0
	var next_label := str(upgrade.get("display_name", "Next home")) if not upgrade.is_empty() else ""
	var fields: Array = [{"id": "gold", "label": "Gold", "value": gold}]
	if not upgrade.is_empty():
		fields.append({"id": "next_home_price", "label": next_label, "value": next_price})
	return {
		"mode": "meta",
		"status_text": "[GOLD] Gold %d" % gold,
		"objective_text": "[HOME] %s - %d gold" % [next_label, next_price] if not upgrade.is_empty() else "",
		"save_text": "",
		"fields": fields,
		"gold": gold,
		"next_home_label": next_label,
		"next_home_price": next_price,
		"housing_tier": str(home.get("housing_tier", "")),
	}


static func next_objective_option(run_state: RunState, data: Dictionary) -> Dictionary:
	if run_state == null:
		return {}
	var pressure: Dictionary = data.get("pressure", {})
	var pressure_state := str(pressure.get("state", ""))
	if pressure_state == "victory":
		return objective_for_object("menu", "main_menu", "return to the menu or start fresh", true, data.get("player_facing_text", Callable()))
	if pressure_state == "failed":
		return objective_for_object("menu", "main_menu", "return to the menu to continue or start over", true, data.get("player_facing_text", Callable()))
	var objective: Dictionary = data.get("demo_objective", {})
	var state := objective_presentation_state(pressure, objective)
	var state_option := next_objective_option_for_state(state, objective, data.get("player_facing_text", Callable()))
	if not state_option.is_empty():
		return state_option
	if bool(data.get("current_game_active", false)):
		return {"hint": "choose stake and press for the objective" if bool(data.get("objective_needs_play", false)) else "choose stake and click a game-surface action", "object_type": "game_surface", "object_id": "", "enabled": true}
	if bool(data.get("objective_needs_play", false)) and bool(data.get("has_enabled_game", false)):
		return objective_for_object("game", "", "play for the boss-floor target", true, data.get("player_facing_text", Callable()))
	for candidate in [
		_candidate(data.get("event_option", {}), "event", "event:", "answer the local event"),
		_candidate(data.get("item_offer", {}), "item", "item:", "inspect useful gear"),
		_candidate(data.get("service_option", {}), "service", "service:", "use a local service"),
		_candidate(data.get("lender_option", {}), "lender", "lender:", "consider lender help"),
		_candidate(data.get("travel_choice", {}), "travel", "travel:", "choose where to go next"),
	]:
		if not candidate.is_empty():
			return objective_for_object(str(candidate.get("object_type", "")), str(candidate.get("object_id", "")), str(candidate.get("hint", "")), true, data.get("player_facing_text", Callable()))
	if bool(data.get("has_enabled_game", false)):
		return objective_for_object("game", "", "play a visible game", true, data.get("player_facing_text", Callable()))
	var locked: Dictionary = data.get("locked_travel", {})
	if not locked.is_empty():
		return objective_for_object("travel", "travel:%s" % str(locked.get("id", "")), str(locked.get("disabled_reason", "routes are locked for now")), false, data.get("player_facing_text", Callable()))
	return objective_for_object("menu", "main_menu", "return to the menu or inspect the room", true, data.get("player_facing_text", Callable()))


static func hud_goal_text(run_state: RunState, pressure: Dictionary, objective: Dictionary, player_facing_text: Callable) -> String:
	return hud_short(objective_goal_text(run_state, pressure, objective), 54, player_facing_text).replace("Double-click it to win.", "double-click to win.")


static func objective_goal_text(run_state: RunState, pressure: Dictionary, objective: Dictionary) -> String:
	match str(pressure.get("state", "")):
		"victory": return "Victory claimed. Return to the menu or start fresh."
		"failed": return "Run failed. Return to the menu to continue or start over."
		"recovery": return "Recover with available help before playing."
	if bool(objective.get("active", false)):
		if is_boss_floor_objective(objective):
			return boss_floor_objective_goal_text(objective)
		var title := str(objective.get("title", "Beat the house"))
		var target := int(objective.get("target_bankroll", 0))
		var remaining := int(objective.get("remaining_bankroll", 0))
		return "%s complete. Cash out to move on." % title if bool(objective.get("complete", false)) else "%s: reach $%d. Need $%d." % [title, target, remaining]
	return "Build cash, find Grand Casino routes, keep heat low."


static func boss_floor_objective_goal_text(objective: Dictionary) -> String:
	var state := str(objective.get("objective_state", "grand-incomplete"))
	if state == "showdown-active": return "Rourke has you in back. Keep your story straight."
	if state == "showdown-pending" or bool(objective.get("showdown_pending", false)): return "Rourke is calling. Answer the back-room event."
	if state == "high-roller-ready" or bool(objective.get("high_roller_ready", false)): return "Players Card is ready. Claim it before heat rises."
	if bool(objective.get("dirty_money_showdown_ready", false)): return "The card review is checking your win. Expect Rourke."
	if boss_floor_heat_pressure_close(objective): return "Heat is loud. More pressure means Rourke's back room."
	if boss_floor_progress_close(objective): return "Close to Players Card: keep play clean and finish the set."
	return "Win $200 here for a Players Card, or survive Rourke."


static func objective_presentation_state(pressure: Dictionary, objective: Dictionary) -> String:
	var state := str(pressure.get("state", ""))
	if state == "victory": return "victory"
	if state == "failed": return "failure"
	if bool(objective.get("active", false)) and is_boss_floor_objective(objective):
		return str(objective.get("objective_state", "grand-incomplete")) if not str(objective.get("objective_state", "")).strip_edges().is_empty() else "grand-incomplete"
	return "pre-grand"


static func objective_guidance_view(pressure: Dictionary, objective: Dictionary, next_option: Dictionary = {}) -> Dictionary:
	var state := objective_presentation_state(pressure, objective)
	var route := "reach_boss_floor"
	var text := "Build cash, scout a route to the Grand Casino, and keep heat low."
	match state:
		"victory": route = "summary"; text = "Victory is claimed. Review the run summary or start fresh."
		"failure": route = "summary"; text = "The run is over. Return to the menu or start a new climb."
		"high-roller-ready": route = "players_card"; text = "The host will issue the Players Card if you take the review now."
		"showdown-pending": route = "pit_boss_showdown"; text = "Rourke is calling. Take the back-room event before more play."
		"showdown-active": route = "pit_boss_showdown"; text = "Rourke has you off the floor. Choose one answer and stand by it."
		"grand-incomplete": route = "boss_floor"; text = boss_floor_incomplete_guidance(objective)
	return {"state": state, "route": route, "text": text, "clean_progress_close": boss_floor_progress_close(objective), "heat_pressure_close": boss_floor_heat_pressure_close(objective), "staff_attention": bool(objective.get("staff_attention_active", false)), "next": next_option}


static func boss_floor_incomplete_guidance(objective: Dictionary) -> String:
	if bool(objective.get("dirty_money_showdown_ready", false)): return "The money is there, but the floor wants Rourke to review it."
	if boss_floor_heat_pressure_close(objective): return "Rourke is close enough to matter. Keep heat down or prepare for the back room."
	if boss_floor_progress_close(objective): return "The host is nearly ready to issue the card. Finish clean play and avoid loud heat."
	return "Win clean toward the Players Card, or survive Rourke if attention turns."


static func boss_floor_progress_close(objective: Dictionary) -> bool:
	if not bool(objective.get("active", false)) or not is_boss_floor_objective(objective): return false
	if bool(objective.get("showdown_pending", false)) or bool(objective.get("showdown_active", false)): return false
	if bool(objective.get("cheat_evidence", false)) or bool(objective.get("watched_cheat_evidence", false)): return false
	if int(objective.get(boss_floor_status_key("max_heat"), 0)) > int(objective.get("high_roller_max_heat", 100)): return false
	if bool(objective.get("high_roller_ready", false)): return true
	var remaining_games := int(objective.get("high_roller_remaining_games", 0))
	var remaining_bankroll := int(objective.get("remaining_bankroll", 0))
	var remaining_net := int(objective.get("high_roller_remaining_net_winnings", 0))
	var target := int(objective.get("high_roller_target_bankroll", objective.get("target_bankroll", 0)))
	return remaining_games <= 1 and ((target > 0 and remaining_bankroll <= 50) or remaining_net <= 25)


static func boss_floor_heat_pressure_close(objective: Dictionary) -> bool:
	if not bool(objective.get("active", false)) or not is_boss_floor_objective(objective): return false
	if bool(objective.get("showdown_pending", false)) or bool(objective.get("showdown_active", false)): return true
	return int(objective.get("current_heat", 0)) >= maxi(0, int(objective.get("showdown_heat_threshold", 70)) - (12 if bool(objective.get("staff_attention_active", false)) else 6))


static func is_boss_floor_objective(objective: Dictionary) -> bool:
	return bool(objective.get(boss_floor_status_key("objective"), false))


static func boss_floor_status_key(suffix: String) -> String:
	return "%s_%s" % [RunState.GRAND_CASINO_ARCHETYPE_ID, suffix]


static func objective_pressure_text(pressure: Dictionary) -> String:
	return _pressure_status_text(pressure) if ["failed", "recovery", "distressed", "victory"].has(str(pressure.get("state", ""))) else ""


static func next_objective_option_for_state(state: String, objective: Dictionary, player_facing_text: Callable) -> Dictionary:
	if not bool(objective.get("active", false)) or not is_boss_floor_objective(objective): return {}
	if state == "showdown-pending" or state == "showdown-active":
		var id := str(objective.get("showdown_event_id", objective.get("finale_event_id", ""))).strip_edges()
		return objective_for_object("event", "event:%s" % (RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID if id.is_empty() else id), "answer Rourke's back-room call", true, player_facing_text)
	if state == "high-roller-ready":
		var id := str(objective.get("high_roller_event_id", "")).strip_edges()
		return objective_for_object("event", "event:%s" % (RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID if id.is_empty() else id), "claim the Players Card", true, player_facing_text)
	return {}


static func objective_for_object(object_type: String, object_id: String, hint: String, enabled: bool, player_facing_text: Callable) -> Dictionary:
	return {"hint": _call_string(player_facing_text, hint), "object_type": object_type, "object_id": object_id, "enabled": enabled}


static func hud_debt_text(items: Array, player_facing_text: Callable) -> String:
	if items.is_empty(): return "none"
	return hud_short(str(items[0]), 30, player_facing_text) if items.size() == 1 else "%d active debts" % items.size()


static func hud_inventory_text(items: Array, player_facing_text: Callable) -> String:
	if items.is_empty(): return "empty"
	if items.size() > 1: return "%d items" % items.size()
	var text := str(items[0])
	var separator := text.find(" - ")
	return hud_short(text.substr(0, separator) if separator != -1 else text, 24, player_facing_text)


static func hud_home_text(run_state: RunState, player_facing_text: Callable) -> String:
	if run_state == null or run_state.home_state.is_empty(): return ""
	var status := run_state.home_tenure_status()
	if bool(status.get("lost", false)) or bool(status.get("overdue", false)) or bool(status.get("due", false)) or run_state.is_current_home_environment():
		return "Home: %s" % hud_short(run_state.home_status_summary(), 44, player_facing_text)
	return ""


static func hud_run_status_text(run_state: RunState, pressure: Dictionary) -> String:
	match str(pressure.get("state", "")):
		"victory": return "Victory"
		"failed": return "Failure"
		"recovery": return "Recovery"
		"distressed": return "Pressure"
	return "Active" if run_state.run_status == "active" else run_state.run_status.capitalize()


static func hud_save_text(has_save: bool, status: String, player_facing_text: Callable) -> String:
	return "[AUTO] %s / %s" % [("on" if has_save else "pending").capitalize(), hud_short("current run" if status.is_empty() else status, 24, player_facing_text)]


static func hud_meter(value: int, maximum: int, width: int) -> String:
	var filled := clampi(roundi(float(clampi(value, 0, maximum)) / float(maximum) * float(width)), 0, width) if maximum > 0 and width > 0 else 0
	return "[%s%s]" % ["#".repeat(filled), "-".repeat(maxi(0, width - filled))]


static func hud_short(text: String, max_length: int, player_facing_text: Callable) -> String:
	var cleaned := _call_string(player_facing_text, text).strip_edges()
	if cleaned.length() <= max_length: return cleaned
	return cleaned.left(max_length) if max_length <= 3 else "%s..." % cleaned.left(max_length - 3)


static func pit_boss_hud_text(status: Dictionary) -> String:
	if not bool(status.get("active", false)): return ""
	return "Pit boss: watching" if bool(status.get("watched", false)) else "Pit boss: turned away"


static func _candidate(value: Variant, object_type: String, prefix: String, hint: String) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).is_empty(): return {}
	return {"object_type": object_type, "object_id": prefix + str((value as Dictionary).get("id", "")), "hint": hint}


static func _pressure_status_text(pressure: Dictionary) -> String:
	var title := str(pressure.get("title", ""))
	var summary := str(pressure.get("summary", ""))
	if title.is_empty(): return summary
	return title if summary.is_empty() or summary == title else "%s: %s" % [title, summary]


static func _call_string(callback: Callable, value: String) -> String:
	return str(callback.call(value)) if not callback.is_null() else value


static func _copy_dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
