class_name EventModule
extends RefCounted

# Data-backed event contract for conditional run consequences.

var definition: Dictionary = {}
var content_library: ContentLibrary = null


# Stores the event definition used by this module.
func setup(p_definition: Dictionary, p_library: ContentLibrary = null) -> void:
	definition = p_definition.duplicate(true)
	content_library = p_library


# Returns this event id.
func get_id() -> String:
	return str(definition.get("id", ""))


# Returns the player-facing event name.
func get_display_name() -> String:
	return str(definition.get("display_name", get_id()))


# Returns the event type.
func get_event_type() -> String:
	return str(definition.get("type", ""))


# Returns the event interaction mode.
func get_interaction_mode() -> String:
	return str(definition.get("interaction_mode", "interactable"))


# Returns available event choices.
func choices(run_state: RunState = null, environment: Dictionary = {}) -> Array:
	var payload := _copy_dict(definition.get("payload", {}))
	if str(payload.get("kind", "")) == "grand_casino_showdown":
		return _grand_casino_showdown_choices(payload, run_state, environment)
	if str(payload.get("kind", "")) == "grand_casino_high_roller_cashout":
		return _grand_casino_high_roller_choices(payload, run_state, environment)
	var result: Array = []
	for choice_value in _copy_array(payload.get("choices", [])):
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice_data: Dictionary = (choice_value as Dictionary).duplicate(true)
		if _choice_conditions_allow(choice_data, run_state, environment):
			result.append(choice_data)
	return result


# Finds one event choice by id.
func choice(choice_id: String, run_state: RunState = null, environment: Dictionary = {}) -> Dictionary:
	for option in choices(run_state, environment):
		if option.get("id", "") == choice_id:
			return option.duplicate(true)
	return {}


# Checks whether this event can fire in the current run context.
func can_trigger(run_state: RunState, environment: Dictionary, context: Dictionary = {}) -> bool:
	var min_suspicion := int(definition.get("min_suspicion", 0))
	var tier_min := int(definition.get("tier_min", 1))
	if int(run_state.suspicion.get("level", 0)) < min_suspicion:
		return false
	if int(environment.get("tier", 1)) < tier_min:
		return false
	var event_ids := _copy_array(environment.get("event_ids", []))
	if get_interaction_mode() != "triggered" and not event_ids.is_empty() and not event_ids.has(get_id()):
		return false
	var resolved := _copy_array(environment.get("resolved_event_ids", []))
	if resolved.has(get_id()):
		return false
	var scopes := _copy_array(definition.get("scopes", []))
	if not scopes.is_empty() and not scopes.has("any") and not scopes.has(str(environment.get("kind", ""))):
		return false
	if not _conditions_allow(run_state, environment, context):
		return false
	return _trigger_allows(environment, context)


# Applies simple event consequences to the run.
func resolve(run_state: RunState, environment: Dictionary, choice_id: String = "") -> Dictionary:
	var payload := _copy_dict(definition.get("payload", {}))
	if str(payload.get("kind", "")) == "grand_casino_showdown":
		return _resolve_grand_casino_showdown(run_state, environment, payload, choice_id)
	if str(payload.get("kind", "")) == "grand_casino_high_roller_cashout":
		return _resolve_grand_casino_high_roller_cashout(run_state, environment, payload, choice_id)
	var selected_choice := choice(choice_id, run_state, environment)
	if not choice_id.is_empty() and selected_choice.is_empty():
		return _empty_result(choice_id, environment, "Event choice is not available.")
	var consequences := _consequences(selected_choice)
	consequences = _resolved_checked_consequences(run_state, environment, selected_choice, consequences)
	consequences = _resolved_lender_hook_consequences(run_state, consequences)
	var bankroll_delta := int(consequences.get("bankroll_delta", 0))
	var suspicion_delta := int(consequences.get("suspicion_delta", 0))
	var alcohol_intake := int(consequences.get("alcohol_intake", 0))
	var drunk_delta := int(consequences.get("drunk_delta", 0))
	var pending_drunk_absorption_delta := int(consequences.get("pending_drunk_absorption_delta", 0))
	var drunk_distortion_suppression_turns := int(consequences.get("drunk_distortion_suppression_turns", 0))
	var alcoholic_delta := int(consequences.get("alcoholic_delta", 0))
	var baseline_luck_delta := int(consequences.get("baseline_luck_delta", 0))
	var choice_key := str(selected_choice.get("id", choice_id))
	var message := _message(selected_choice)
	var story_entry := {
		"type": "event",
		"event_id": get_id(),
		"choice_id": choice_key,
		"environment_id": environment.get("id", ""),
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"alcohol_intake": alcohol_intake,
		"drunk_delta": drunk_delta,
		"pending_drunk_absorption_delta": pending_drunk_absorption_delta,
		"drunk_distortion_suppression_turns": drunk_distortion_suppression_turns,
		"alcoholic_delta": alcoholic_delta,
		"baseline_luck_delta": baseline_luck_delta,
	}
	var deltas := _consequence_deltas(consequences, story_entry, message)
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "event",
		"source_id": get_id(),
		"action_id": choice_key,
		"action_kind": "event",
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"deltas": deltas,
		"environment_id": environment.get("id", ""),
		"message": message,
	})
	result["event_id"] = get_id()
	result["choice_id"] = choice_key
	result["interaction_mode"] = get_interaction_mode()
	result["conclusion_animation"] = str(selected_choice.get("conclusion_animation", consequences.get("conclusion_animation", "")))
	apply_event_result(run_state, result)
	return result


# Applies a shared event result and records event-specific outcomes.
static func apply_event_result(run_state: RunState, result: Dictionary) -> void:
	if run_state == null or not bool(result.get("ok", false)):
		return
	GameModule.apply_result(run_state, result)
	var deltas: Dictionary = result.get("deltas", {})
	for hook in deltas.get("event_hooks", []):
		if typeof(hook) != TYPE_DICTIONARY:
			continue
		var hook_data := _copy_dict(hook)
		match str(hook_data.get("type", "")):
			"resolve_event":
				run_state.resolve_event(str(hook_data.get("event_id", "")))
			"trigger_event":
				_apply_trigger_event_hook(run_state, result, hook_data)


# Returns a no-op event result for invalid choices.
func _empty_result(choice_id: String, environment: Dictionary, text: String) -> Dictionary:
	var result := GameModule.build_action_result({
		"ok": false,
		"type": "event",
		"source_id": get_id(),
		"action_id": choice_id,
		"action_kind": "event",
		"environment_id": environment.get("id", ""),
		"message": text,
	})
	result["event_id"] = get_id()
	result["choice_id"] = choice_id
	return result


# Converts event consequences into the shared result-delta shape.
func _consequence_deltas(consequences: Dictionary, story_entry: Dictionary, message: String) -> Dictionary:
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = int(consequences.get("bankroll_delta", 0))
	deltas["suspicion_delta"] = int(consequences.get("suspicion_delta", 0))
	deltas["alcohol_intake"] = int(consequences.get("alcohol_intake", 0))
	deltas["drunk_delta"] = int(consequences.get("drunk_delta", 0))
	deltas["pending_drunk_absorption_delta"] = int(consequences.get("pending_drunk_absorption_delta", 0))
	deltas["drunk_distortion_suppression_turns"] = int(consequences.get("drunk_distortion_suppression_turns", 0))
	deltas["alcoholic_delta"] = int(consequences.get("alcoholic_delta", 0))
	deltas["baseline_luck_delta"] = int(consequences.get("baseline_luck_delta", 0))
	if consequences.has("debt"):
		deltas["debt_changes"] = [_copy_dict(consequences.get("debt", {}))]
	else:
		deltas["debt_changes"] = _copy_array(consequences.get("debt_changes", []))
	deltas["inventory_add"] = _copy_array(consequences.get("inventory_add", []))
	deltas["inventory_remove"] = _copy_array(consequences.get("inventory_remove", []))
	deltas["flags_set"] = _copy_dict(consequences.get("flags", consequences.get("flags_set", {})))
	deltas["travel_hooks_add"] = _copy_array(consequences.get("travel_hooks_add", []))
	var travel_changes := _copy_dict(consequences.get("travel_changes", {}))
	if consequences.has("set_next_archetypes"):
		travel_changes["set_next_archetypes"] = _copy_array(consequences.get("set_next_archetypes", []))
	if consequences.has("add_next_archetypes"):
		travel_changes["add_next_archetypes"] = _copy_array(consequences.get("add_next_archetypes", []))
	deltas["travel_changes"] = travel_changes
	var story_entries := [story_entry]
	story_entries.append_array(_copy_array(consequences.get("story_log", [])))
	deltas["story_log"] = story_entries
	var messages := _copy_array(consequences.get("messages", []))
	if not message.is_empty():
		messages.push_front(message)
	deltas["messages"] = messages
	deltas["event_hooks"] = _copy_array(consequences.get("event_hooks", []))
	deltas["demo_finale"] = _copy_dict(consequences.get("demo_finale", {}))
	if bool(consequences.get("resolve_event", false)):
		deltas["event_hooks"].append({
			"type": "resolve_event",
			"event_id": get_id(),
		})
	var trigger_event := _copy_dict(consequences.get("trigger_event", {}))
	if not trigger_event.is_empty():
		trigger_event["type"] = "trigger_event"
		trigger_event["source_event_id"] = get_id()
		trigger_event["source_choice_id"] = str(story_entry.get("choice_id", ""))
		deltas["event_hooks"].append(trigger_event)
	return deltas


func _resolved_lender_hook_consequences(run_state: RunState, consequences: Dictionary) -> Dictionary:
	var lender_id := str(consequences.get("lender_hook", "")).strip_edges()
	if lender_id.is_empty() or run_state == null or content_library == null:
		return consequences
	var resolver := RunActionService.new()
	resolver.setup(content_library, run_state)
	var lender_result := resolver.hook_result("lender", lender_id)
	if lender_result.is_empty() or not bool(lender_result.get("ok", false)):
		return consequences
	var lender_deltas := _copy_dict(lender_result.get("deltas", {}))
	var resolved := consequences.duplicate(true)
	for key in ["bankroll_delta", "suspicion_delta", "alcohol_intake", "drunk_delta", "pending_drunk_absorption_delta", "drunk_distortion_suppression_turns", "alcoholic_delta", "baseline_luck_delta"]:
		resolved[key] = int(resolved.get(key, 0)) + int(lender_deltas.get(key, 0))
	var debt_changes := _copy_array(resolved.get("debt_changes", []))
	debt_changes.append_array(_copy_array(lender_deltas.get("debt_changes", [])))
	resolved["debt_changes"] = debt_changes
	var flags := _copy_dict(resolved.get("flags_set", resolved.get("flags", {})))
	var lender_flags := _copy_dict(lender_deltas.get("flags_set", {}))
	for flag_key in lender_flags.keys():
		flags[str(flag_key)] = lender_flags[flag_key]
	resolved["flags_set"] = flags
	var story_log := _copy_array(resolved.get("story_log", []))
	story_log.append_array(_copy_array(lender_deltas.get("story_log", [])))
	resolved["story_log"] = story_log
	var messages := _copy_array(resolved.get("messages", []))
	messages.append_array(_copy_array(lender_deltas.get("messages", [])))
	resolved["messages"] = messages
	return resolved


# Applies a chain hook after the source event result has already mutated the run.
static func _apply_trigger_event_hook(run_state: RunState, source_result: Dictionary, hook_data: Dictionary) -> void:
	var target_id := str(hook_data.get("event_id", "")).strip_edges()
	if run_state == null or target_id.is_empty():
		return
	var chance := clampf(float(hook_data.get("chance", 1.0)), 0.0, 1.0)
	var threshold := clampi(int(round(chance * 10000.0)), 0, 10000)
	var rng := run_state.create_rng()
	var roll := rng.randi_range(0, 9999)
	run_state.save_rng(rng)
	var success := roll < threshold
	_apply_trigger_hook_flags(run_state, _copy_dict(hook_data.get("success_flags" if success else "failure_flags", {})))
	_apply_trigger_hook_story(run_state, _copy_array(hook_data.get("success_story_log" if success else "failure_story_log", [])))
	if success:
		var context := _copy_dict(hook_data.get("context", {}))
		context["trigger"] = "chain"
		context["type"] = "chain"
		context["source_event_id"] = str(hook_data.get("source_event_id", source_result.get("event_id", "")))
		context["source_choice_id"] = str(hook_data.get("source_choice_id", source_result.get("choice_id", "")))
		context["chance"] = chance
		context["roll"] = roll
		run_state.enqueue_triggered_event(target_id, "event_chain", context)
	else:
		run_state.log_story({
			"type": "event_chain_miss",
			"event_id": str(hook_data.get("source_event_id", source_result.get("event_id", ""))),
			"choice_id": str(hook_data.get("source_choice_id", source_result.get("choice_id", ""))),
			"target_event_id": target_id,
			"chance": chance,
			"roll": roll,
			"message": str(hook_data.get("failure_message", "The follow-up does not land.")),
		})


static func _apply_trigger_hook_flags(run_state: RunState, flags: Dictionary) -> void:
	if run_state == null:
		return
	for flag_key in flags.keys():
		run_state.narrative_flags[str(flag_key)] = flags[flag_key]


static func _apply_trigger_hook_story(run_state: RunState, entries: Array) -> void:
	if run_state == null:
		return
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		run_state.log_story(entry_value as Dictionary)


# Checks the event trigger payload.
func _trigger_allows(environment: Dictionary, context: Dictionary = {}) -> bool:
	var trigger := _copy_dict(definition.get("trigger", {"type": "manual"}))
	var trigger_type := str(trigger.get("type", "manual"))
	match trigger_type:
		"manual":
			return true
		"timed":
			var turns := int(context.get("turns", environment.get("turns", 0)))
			return turns >= int(trigger.get("turns", 0))
		"travel":
			return str(context.get("trigger", context.get("type", ""))) == "travel"
		"random":
			if str(context.get("trigger", context.get("type", ""))) != "action":
				return false
			var turns := int(context.get("turns", environment.get("turns", 0)))
			return turns >= int(trigger.get("turns", trigger.get("min_turns", 0)))
		_:
			return false


# Checks optional run-state/system conditions without mutating the run.
func _conditions_allow(run_state: RunState, environment: Dictionary, context: Dictionary = {}) -> bool:
	var conditions := _copy_dict(context.get("conditions_override", definition.get("conditions", {})))
	if conditions.is_empty():
		return true
	if run_state == null:
		return false
	if conditions.has("min_bankroll") and run_state.bankroll < int(conditions.get("min_bankroll", 0)):
		return false
	if conditions.has("max_bankroll") and run_state.bankroll > int(conditions.get("max_bankroll", 0)):
		return false
	if conditions.has("min_suspicion") and run_state.suspicion_level() < int(conditions.get("min_suspicion", 0)):
		return false
	if conditions.has("max_suspicion") and run_state.suspicion_level() > int(conditions.get("max_suspicion", 0)):
		return false
	if conditions.has("min_drunk") and run_state.drunk_level < int(conditions.get("min_drunk", 0)):
		return false
	if conditions.has("max_drunk") and run_state.drunk_level > int(conditions.get("max_drunk", 0)):
		return false
	if conditions.has("min_alcoholic") and run_state.alcoholic_level < int(conditions.get("min_alcoholic", 0)):
		return false
	if conditions.has("max_alcoholic") and run_state.alcoholic_level > int(conditions.get("max_alcoholic", 0)):
		return false
	if conditions.has("min_tier") and int(environment.get("tier", 1)) < int(conditions.get("min_tier", 1)):
		return false
	if conditions.has("max_tier") and int(environment.get("tier", 1)) > int(conditions.get("max_tier", 99)):
		return false
	if conditions.has("min_luck") and run_state.effective_luck() < int(conditions.get("min_luck", 0)):
		return false
	if conditions.has("max_luck") and run_state.effective_luck() > int(conditions.get("max_luck", 0)):
		return false
	var economy_states := _string_array(conditions.get("economy_states", []))
	if not economy_states.is_empty() and not economy_states.has(run_state.economy()):
		return false
	var requires_flags := _copy_dict(conditions.get("requires_flags", {}))
	for key in requires_flags.keys():
		if run_state.narrative_flags.get(str(key), null) != requires_flags[key]:
			return false
	for flag_id in _string_array(conditions.get("blocked_by_flags", [])):
		if bool(run_state.narrative_flags.get(flag_id, false)):
			return false
	for flag_id in _string_array(conditions.get("missing_flags", [])):
		if bool(run_state.narrative_flags.get(flag_id, false)):
			return false
	for item_id in _string_array(conditions.get("requires_items", [])):
		if not run_state.inventory.has(item_id):
			return false
	for item_id in _string_array(conditions.get("blocked_by_items", [])):
		if run_state.inventory.has(item_id):
			return false
	var archetype_ids := _string_array(conditions.get("archetype_ids", []))
	if not archetype_ids.is_empty() and not archetype_ids.has(str(environment.get("archetype_id", ""))):
		return false
	for archetype_id in _string_array(conditions.get("blocked_archetype_ids", [])):
		if str(environment.get("archetype_id", "")) == archetype_id:
			return false
	var requires_games := _string_array(conditions.get("requires_games", []))
	if not requires_games.is_empty():
		var environment_games := _string_array(environment.get("game_ids", []))
		for game_id in requires_games:
			if not environment_games.has(game_id):
				return false
	if conditions.has("requires_debt"):
		var requires_debt := bool(conditions.get("requires_debt", false))
		if requires_debt != (run_state.debt.size() > 0):
			return false
	if conditions.has("requires_overdue_debt") and bool(conditions.get("requires_overdue_debt", false)) != _has_debt_with_status(run_state, ["overdue", "favor_due"]):
		return false
	var lender_ids := _string_array(conditions.get("requires_lender_debt", []))
	if not lender_ids.is_empty() and not _has_lender_debt(run_state, lender_ids):
		return false
	var travel_ids := _string_array(conditions.get("requires_travel_targets", []))
	if not travel_ids.is_empty():
		var available_travel := _event_travel_targets(run_state, environment)
		for travel_id in travel_ids:
			if not available_travel.has(travel_id):
				return false
	var context_flags := _copy_dict(conditions.get("requires_context", {}))
	for key in context_flags.keys():
		if context.get(str(key), null) != context_flags[key]:
			return false
	return true


func _event_travel_targets(run_state: RunState, environment: Dictionary) -> Array:
	var result: Array = []
	for source in [
		environment.get("next_archetypes", []),
		environment.get("travel_hooks", []),
		run_state.unlocked_travel,
	]:
		for target_id in _string_array(source):
			if not result.has(target_id):
				result.append(target_id)
	return result


func _has_lender_debt(run_state: RunState, lender_ids: Array) -> bool:
	for debt_entry in run_state.debt:
		if typeof(debt_entry) != TYPE_DICTIONARY:
			continue
		var debt_data := debt_entry as Dictionary
		if lender_ids.has(str(debt_data.get("lender_id", ""))):
			return true
	return false


func _has_debt_with_status(run_state: RunState, statuses: Array) -> bool:
	for debt_entry in run_state.debt:
		if typeof(debt_entry) != TYPE_DICTIONARY:
			continue
		var debt_data := debt_entry as Dictionary
		if statuses.has(str(debt_data.get("status", "active"))):
			return true
	return false


func _choice_conditions_allow(choice_data: Dictionary, run_state: RunState, environment: Dictionary) -> bool:
	var choice_conditions := _copy_dict(choice_data.get("conditions", {}))
	if choice_conditions.is_empty():
		return true
	return _conditions_allow(run_state, environment, {"choice_conditions": true, "conditions_override": choice_conditions})


# Returns consequences from a selected choice or legacy top-level event data.
func _consequences(selected_choice: Dictionary) -> Dictionary:
	if not selected_choice.is_empty():
		return _copy_dict(selected_choice.get("consequences", {}))
	return _copy_dict(definition.get("consequences", {}))


func _resolved_checked_consequences(run_state: RunState, environment: Dictionary, selected_choice: Dictionary, consequences: Dictionary) -> Dictionary:
	var check := _copy_dict(consequences.get("check", {}))
	if check.is_empty() or run_state == null:
		return consequences
	var chance := clampi(int(check.get("chance_percent", 50)), 0, 100)
	var item_bonus := _copy_dict(check.get("item_success_bonus", {}))
	for item_id_value in item_bonus.keys():
		if run_state.inventory.has(str(item_id_value)):
			chance += int(item_bonus[item_id_value])
	chance = clampi(chance, int(check.get("min_chance", 0)), int(check.get("max_chance", 100)))
	var rng := run_state.create_rng()
	var roll := rng.randi_range(1, 100)
	run_state.save_rng(rng)
	var outcome_key := "success_consequences" if roll <= chance else "failure_consequences"
	var resolved := consequences.duplicate(true)
	resolved.erase("check")
	var outcome := _copy_dict(check.get(outcome_key, {}))
	for key in outcome.keys():
		resolved[key] = outcome[key]
	var story := _copy_array(resolved.get("story_log", []))
	story.append({
		"type": "event_check",
		"event_id": get_id(),
		"choice_id": str(selected_choice.get("id", "")),
		"environment_id": str(environment.get("id", "")),
		"chance_percent": chance,
		"roll": roll,
		"success": roll <= chance,
	})
	resolved["story_log"] = story
	return resolved


# Returns the player-facing event resolution text.
func _message(selected_choice: Dictionary) -> String:
	if not selected_choice.is_empty():
		return str(selected_choice.get("text", selected_choice.get("label", get_display_name())))
	var payload := _copy_dict(definition.get("payload", {}))
	return str(definition.get("text", payload.get("summary", "")))


func _grand_casino_showdown_choices(payload: Dictionary, run_state: RunState, environment: Dictionary) -> Array:
	var all_choices := _copy_array(payload.get("choices", []))
	if run_state == null:
		return all_choices
	var active := bool(run_state.narrative_flags.get("grand_casino_showdown_active", false))
	var pending := bool(run_state.narrative_flags.get("grand_casino_showdown_pending", false)) or bool(run_state.narrative_flags.get("the_house_calls_pending", false))
	var result: Array = []
	for choice_value in all_choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice_data := (choice_value as Dictionary).duplicate(true)
		var choice_id := str(choice_data.get("id", ""))
		if active and ["hold_steady", "talk_down", "take_the_edge"].has(choice_id):
			result.append(choice_data)
		elif not active and pending and choice_id == "enter_back_room":
			result.append(choice_data)
	return result


func _resolve_grand_casino_showdown(run_state: RunState, environment: Dictionary, payload: Dictionary, choice_id: String) -> Dictionary:
	var selected_choice := choice(choice_id, run_state, environment)
	if selected_choice.is_empty():
		return _empty_result(choice_id, environment, "Showdown choice is not available.")
	var config := _copy_dict(payload.get("showdown_tuning", {}))
	config["success_message"] = str(payload.get("success_message", ""))
	config["failure_message"] = str(payload.get("failure_message", ""))
	var choice_key := str(selected_choice.get("id", choice_id))
	var outcome := {}
	if choice_key == "enter_back_room":
		outcome = run_state.start_grand_casino_showdown(config)
	else:
		outcome = run_state.resolve_grand_casino_showdown_pressure(choice_key, config)
	var ok := bool(outcome.get("ok", false))
	var message := str(outcome.get("message", selected_choice.get("text", get_display_name())))
	var deltas := GameModule.empty_result_deltas()
	deltas["messages"] = [] if message.is_empty() else [message]
	deltas["ended"] = run_state.is_terminal()
	var result := GameModule.build_action_result({
		"ok": ok,
		"type": "event",
		"source_id": get_id(),
		"action_id": choice_key,
		"action_kind": "event",
		"deltas": deltas,
		"environment_id": environment.get("id", ""),
		"message": message,
		"ended": run_state.is_terminal(),
	})
	result["event_id"] = get_id()
	result["choice_id"] = choice_key
	result["showdown"] = _copy_dict(outcome.get("status", {}))
	result["showdown_check"] = _copy_dict(outcome.get("check", {}))
	if run_state.is_terminal():
		result["state"] = GameModule.RESULT_ENDED
	return result


func _grand_casino_high_roller_choices(payload: Dictionary, run_state: RunState, _environment: Dictionary) -> Array:
	var all_choices := _copy_array(payload.get("choices", []))
	if run_state == null:
		return all_choices
	if not bool(run_state.narrative_flags.get("high_roller_cashout_pending", false)):
		return []
	if bool(run_state.narrative_flags.get("grand_casino_showdown_pending", false)) or bool(run_state.narrative_flags.get("grand_casino_showdown_active", false)):
		return []
	var result: Array = []
	for choice_value in all_choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice_data := (choice_value as Dictionary).duplicate(true)
		if str(choice_data.get("id", "")) == RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID:
			result.append(choice_data)
	return result


func _resolve_grand_casino_high_roller_cashout(run_state: RunState, environment: Dictionary, payload: Dictionary, choice_id: String) -> Dictionary:
	var selected_choice := choice(choice_id, run_state, environment)
	if selected_choice.is_empty():
		return _empty_result(choice_id, environment, "The Players Card desk is not available.")
	var config := {
		"success_message": str(payload.get("success_message", "")),
	}
	var outcome := run_state.complete_grand_casino_high_roller_cashout(config)
	var ok := bool(outcome.get("ok", false))
	var message := str(outcome.get("message", selected_choice.get("text", get_display_name())))
	var deltas := GameModule.empty_result_deltas()
	deltas["messages"] = [] if message.is_empty() else [message]
	deltas["ended"] = run_state.is_terminal()
	var choice_key := str(selected_choice.get("id", choice_id))
	var result := GameModule.build_action_result({
		"ok": ok,
		"type": "event",
		"source_id": get_id(),
		"action_id": choice_key,
		"action_kind": "event",
		"deltas": deltas,
		"environment_id": environment.get("id", ""),
		"message": message,
		"ended": run_state.is_terminal(),
	})
	result["event_id"] = get_id()
	result["choice_id"] = choice_key
	result["high_roller_cashout"] = _copy_dict(outcome.get("status", {}))
	if run_state.is_terminal():
		result["state"] = GameModule.RESULT_ENDED
	return result


# Safely duplicates array content.
static func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


# Normalizes a variant array into string ids.
static func _string_array(value: Variant) -> Array:
	var result: Array = []
	for entry in _copy_array(value):
		var id := str(entry)
		if not id.is_empty():
			result.append(id)
	return result


# Safely duplicates dictionary content.
static func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
