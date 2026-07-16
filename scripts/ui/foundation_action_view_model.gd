extends RefCounted


static func game_view_snapshot(host: Variant) -> Dictionary:
	var display_name = "Choose a game"
	var game_id = ""
	var family = ""
	var surface_renderer = "result"
	var surface_life = "result"
	var surface_cast = "none"
	var legal_actions = host._game_action_view_list("legal")
	var cheat_actions = host._game_action_view_list("cheat")
	var module_surface_state = {}
	if host.current_game != null:
		display_name = host.current_game.get_display_name()
		game_id = host.current_game.get_id()
		family = host.current_game.get_family()
		surface_renderer = host._surface_renderer_for_game_definition(host.current_game.definition)
		surface_life = host._surface_life_for_renderer(surface_renderer)
		surface_cast = host._surface_cast_for_renderer(surface_renderer)
		module_surface_state = host.current_game.surface_state(host.run_state, host.run_state.current_environment, host._current_game_surface_ui_state())
		if typeof(module_surface_state) != TYPE_DICTIONARY:
			module_surface_state = {}
		else:
			module_surface_state = module_surface_state.duplicate(true)
		host._sync_surface_feature_music_state(module_surface_state)
		if module_surface_state.has("surface_renderer"):
			surface_renderer = str(module_surface_state.get("surface_renderer", surface_renderer))
			surface_life = host._surface_life_for_renderer(surface_renderer)
			surface_cast = host._surface_cast_for_renderer(surface_renderer)
		if module_surface_state.has("surface_life"):
			surface_life = str(module_surface_state.get("surface_life", surface_life))
		if module_surface_state.has("surface_cast"):
			surface_cast = str(module_surface_state.get("surface_cast", surface_cast))
	var result = host._current_game_result_snapshot()
	if host.current_game == null and not result.is_empty():
		display_name = str(result.get("display_name", "Saved game summary"))
		game_id = str(result.get("game_id", ""))
		family = str(result.get("family", ""))
	var deltas: Dictionary = result.get("deltas", {})
	var result_message = host._player_facing_text(str(result.get("message", "")))
	var result_bankroll_delta = host._visible_recent_bankroll_delta(int(result.get("bankroll_delta", deltas.get("bankroll_delta", 0))))
	if host.presented_bankroll_hold_active:
		result_message = ""
	if result_message.is_empty():
		if host.current_game == null and result.is_empty():
			result_message = "Pick a game from the choices to start playing."
		elif host.message_label != null:
			result_message = host._player_facing_text(host.message_label.text)
	var drunk_time_scale = host.run_state.drunk_time_scale()
	var drunk_world_speed_percent = host.run_state.drunk_time_scale_percent()
	var stake_range = host._stake_range()
	var snapshot_selected_stake = host._selected_stake_for_range(stake_range)
	var snapshot = {
		"game_id": game_id,
		"display_name": display_name,
		"description": host._current_game_description(),
		"family": family,
		"legal_actions": legal_actions,
		"cheat_actions": cheat_actions,
		"legal_action_count": legal_actions.size(),
		"cheat_action_count": cheat_actions.size(),
		"stake_min": int(stake_range.get("min", 1)),
		"stake_max": int(stake_range.get("max", 1)),
		"selected_stake": snapshot_selected_stake,
		"has_valid_stake": bool(stake_range.get("has_valid", false)),
		"selected_action_id": host.selected_action_id,
		"selected_action_kind": host.selected_action_kind,
		"selected_action_label": host.selected_action_label,
		"selected_action_summary": host._selected_action_summary() if not host.selected_action_id.is_empty() else "",
		"risk_cue": host._cheat_action_risk_cue(cheat_actions) if host.current_game != null else "",
		"surface_renderer": surface_renderer,
		"surface_life": surface_life,
		"surface_cast": surface_cast,
		"has_recent_outcome": not result.is_empty(),
		"outcome_message": result_message,
		"outcome_bankroll_delta": result_bankroll_delta,
		"outcome_suspicion_delta": int(result.get("suspicion_delta", deltas.get("suspicion_delta", 0))),
		"result_message": result_message,
		"bankroll": host._presented_bankroll(),
		"suspicion_level": host.run_state.suspicion_level(),
		"drunk_level": host.run_state.drunk_level,
		"drunk_time_scale": drunk_time_scale,
		"drunk_time_scale_percent": drunk_world_speed_percent,
		"drunk_world_speed_percent": drunk_world_speed_percent,
		"pending_drunk_absorption": host.run_state.pending_drunk_absorption_amount(),
		"drunk_distortion_suppression_turns": host.run_state.drunk_distortion_suppression_turns,
		"drunk_effect_mode": host._drunk_effect_mode(),
		"reduce_motion": host._reduce_motion_enabled(),
		"high_contrast": host._high_contrast_enabled(),
		"accessibility": host.current_accessibility_snapshot(),
		"alcoholic_level": host.run_state.alcoholic_level,
		"baseline_luck": host.run_state.baseline_luck,
		"luck_modifier": host.run_state.effective_luck(),
		"alcohol_condition": host.run_state.alcohol_condition_label(),
		"bankroll_delta": result_bankroll_delta,
		"suspicion_delta": int(result.get("suspicion_delta", deltas.get("suspicion_delta", 0))),
		"result_stake": int(result.get("stake", 0)),
		"ticket_symbols": host._copy_array(result.get("ticket_symbols", [])),
		"won": bool(result.get("won", false)),
		"state": str(result.get("state", GameModule.RESULT_CONTINUE)),
		"summary_source": str(result.get("summary_source", "active_game" if host.current_game != null else "")),
	}
	for key in module_surface_state.keys():
		snapshot[key] = host._snapshot_copy_value(module_surface_state[key])
	snapshot["bankroll"] = host._presented_bankroll()
	snapshot["stake_min"] = int(stake_range.get("min", 1))
	snapshot["stake_max"] = int(stake_range.get("max", 1))
	snapshot["selected_stake"] = snapshot_selected_stake
	snapshot["has_valid_stake"] = bool(stake_range.get("has_valid", false))
	for key in result.keys():
		var result_key = str(key)
		if not snapshot.has(result_key):
			snapshot[result_key] = host._snapshot_copy_value(result[key])
	return snapshot


static func current_game_surface_ui_state(host: Variant) -> Dictionary:
	var ui_state = host.game_surface_ui_state.duplicate(true)
	ui_state["selected_action_id"] = host.selected_action_id
	ui_state["selected_action_kind"] = host.selected_action_kind
	ui_state["selected_stake"] = host._current_selected_stake()
	ui_state["surface_runtime_status"] = host._current_game_surface_status()
	ui_state["focused_talk_speaker"] = host._focused_talk_speaker_snapshot()
	return host._apply_game_surface_time_fields(ui_state)


static func focused_talk_speaker_snapshot(host: Variant) -> Dictionary:
	if host.run_state == null:
		return {}
	var entry = host.run_state.next_pending_talk_event()
	if entry.is_empty():
		return {}
	var speaker: Dictionary = entry.get("speaker", {}) if typeof(entry.get("speaker", {})) == TYPE_DICTIONARY else {}
	if str(speaker.get("role", "")) != "patron":
		return {}
	return speaker.duplicate(true)


static func current_game_result_snapshot(host: Variant) -> Dictionary:
	if host.last_game_result.is_empty():
		return {}
	if host.current_game == null:
		return host.last_game_result.duplicate(true)
	var result_game_id = str(host.last_game_result.get("game_id", host.last_game_result.get("source_id", "")))
	if result_game_id.is_empty() or result_game_id == host.current_game.get_id():
		return host.last_game_result.duplicate(true)
	return {}


static func current_game_embeds_result_feedback(host: Variant) -> bool:
	if host.current_game == null or host.run_state == null:
		return false
	var surface_state = host.current_game.surface_state(host.run_state, host.run_state.current_environment, host._current_game_surface_ui_state())
	if typeof(surface_state) != TYPE_DICTIONARY:
		return false
	return bool(surface_state.get("surface_embeds_outcomes", false))


static func preserved_game_surface_preference_state(host: Variant, ui_state: Dictionary) -> Dictionary:
	var preserved: Dictionary = {}
	var preference_keys = host.GAME_SURFACE_UI_PREFERENCE_KEYS.duplicate()
	if host.current_game != null and host.run_state != null and not host.run_state.current_environment.is_empty():
		var surface = host.current_game.surface_state(host.run_state, host.run_state.current_environment, ui_state)
		var module_keys: Array = surface.get("surface_ui_preference_keys", []) if typeof(surface.get("surface_ui_preference_keys", [])) == TYPE_ARRAY else []
		for module_key_value in module_keys:
			var module_key = str(module_key_value).strip_edges()
			if not module_key.is_empty() and not preference_keys.has(module_key):
				preference_keys.append(module_key)
	for key_value in preference_keys:
		var key = str(key_value)
		if not ui_state.has(key):
			continue
		var value: Variant = ui_state.get(key)
		match typeof(value):
			TYPE_DICTIONARY:
				preserved[key] = (value as Dictionary).duplicate(true)
			TYPE_ARRAY:
				preserved[key] = (value as Array).duplicate(true)
			_:
				preserved[key] = value
	return preserved


static func surface_renderer_for_game_definition(host: Variant, definition: Dictionary) -> String:
	var renderer = str(definition.get("surface_renderer", definition.get("presentation_mode", ""))).strip_edges()
	return renderer if not renderer.is_empty() else "result"


static func surface_life_for_renderer(host: Variant, renderer: String) -> String:
	match renderer:
		"reel_machine":
			return "machine"
		"card_machine":
			return "screen"
		"ticket_reveal":
			return "ticket_table"
		"card_table":
			return "cards"
		"dice_table":
			return "dice_bar"
		_:
			return "result"


static func surface_cast_for_renderer(host: Variant, renderer: String) -> String:
	match renderer:
		"reel_machine", "card_machine":
			return "machine"
		"card_table":
			return "dealer"
		_:
			return "none"


static func game_test_environment(host: Variant, game_id: String, game: GameModule) -> Dictionary:
	var definition = host.library.game(game_id)
	var archetype = host._game_test_archetype()
	var visual_context = host._copy_dict(archetype.get("visual_context", {}))
	if visual_context.is_empty():
		visual_context = {"art_key": str(archetype.get("id", "test_lab"))}
	var archetype_id = str(archetype.get("id", "test_lab"))
	var security_profile = host._copy_dict(archetype.get("security_profile", {}))
	security_profile["strictness"] = host._game_test_security_strictness()
	var economic_profile = host._copy_dict(archetype.get("economic_profile", {}))
	economic_profile["stake_floor"] = host._game_test_stake_floor()
	economic_profile["stake_ceiling"] = host._game_test_stake_ceiling()
	var environment = {
		"id": "practice_%s" % game_id,
		"archetype_id": archetype_id,
		"kind": str(archetype.get("kind", "casino")),
		"display_name": "Practice: %s" % str(definition.get("display_name", game_id.capitalize())),
		"tier": 4,
		"depth": 4,
		"art_key": str(visual_context.get("art_key", archetype_id)),
		"visual_context": visual_context,
		"layout": host._copy_dict(archetype.get("layout", {})),
		"security_profile": security_profile,
		"music_profile": host._copy_dict(archetype.get("music_profile", {})),
		"economic_profile": economic_profile,
		"objective_hint": "Practice the table.",
		"demo_objective": {},
		"game_ids": [game_id],
		"game_states": {},
		"event_ids": [],
		"item_offers": [],
		"service_ids": [],
		"lender_hooks": [],
		"suspicion_cues": host._copy_array(archetype.get("suspicion_cues", [])),
		"travel_hooks": [],
		"next_archetypes": [],
		"local_narrative_flags": {"practice_session": true},
		"moods": host._copy_array(archetype.get("moods", ["boss"])),
		"mood": "boss",
		"turns": 0,
		"resolved_event_ids": [],
	}
	var overrides = host._game_test_generation_overrides()
	var environment_overrides = host._copy_dict(overrides.get("environment", {}))
	if not environment_overrides.is_empty():
		host._deep_merge_dict(environment, environment_overrides)
	var rng = host.run_state.create_rng("game_test_environment:%s" % game_id) if host.run_state != null else RngStream.new()
	if rng.seed_value == 0:
		rng.configure(1)
	var generated = game.generate_environment_state(host.run_state, environment, rng.fork("game_state:%s" % game_id))
	if not generated.is_empty():
		var state_overrides = host._copy_dict(overrides.get("game_state", {}))
		if state_overrides.is_empty() and not overrides.has("environment"):
			state_overrides = overrides
		if not state_overrides.is_empty():
			host._deep_merge_dict(generated, state_overrides)
		var states: Dictionary = environment.get("game_states", {})
		states[game_id] = generated.duplicate(true)
		environment["game_states"] = states
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)
	return environment


static func game_entry_preview(host: Variant, game_id: String) -> Dictionary:
	if host.run_state == null or host.library == null or game_id.is_empty():
		return {}
	var definition = host.library.game(game_id)
	if definition.is_empty():
		return {}
	var game = host._create_game_module(definition)
	if game == null:
		return {"ok": false}
	var action_view = game.actions(host.run_state, host.run_state.current_environment)
	var range = host._stake_range_from_action_view(action_view)
	var legal_actions: Array = action_view.get("legal_actions", [])
	var cheat_actions: Array = action_view.get("cheat_actions", [])
	return {
		"ok": true,
		"display_name": game.get_display_name(),
		"stake_min": int(range.get("min", 1)),
		"stake_max": int(range.get("max", 1)),
		"has_valid_stake": bool(range.get("has_valid", false)),
		"legal_count": legal_actions.size(),
		"cheat_count": cheat_actions.size(),
		"risk_cue": host._cheat_action_risk_cue(cheat_actions),
	}


static func current_game_description(host: Variant) -> String:
	if host.current_game == null:
		return ""
	var definition: Dictionary = host.current_game.definition
	var description = str(definition.get("description", ""))
	if description.is_empty():
		description = str(definition.get("intro", "Choose a stake on the surface, then click an action."))
	return description


static func cheat_action_risk_cue(host: Variant, actions: Variant) -> String:
	if typeof(actions) != TYPE_ARRAY or (actions as Array).is_empty():
		return "No risky action is available here."
	var largest_risk = 0
	var pressure_summary = ""
	for action in actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var action_data = action as Dictionary
		largest_risk = maxi(largest_risk, int(action_data.get("suspicion_delta", 0)))
		if int(action_data.get("security_pressure_bonus", 0)) > 0:
			pressure_summary = str(action_data.get("security_pressure_summary", "The room is watching."))
	if largest_risk <= 0:
		return "Risk cue: this option may draw attention."
	if not pressure_summary.is_empty():
		return "Risk cue: %s Risky actions can draw up to %d heat." % [pressure_summary, largest_risk]
	return "Risk cue: risky actions can draw up to %d heat." % largest_risk


static func selected_action_summary(host: Variant) -> String:
	if host.selected_action_id.is_empty():
		return "No action selected."
	var kind = "risky" if host.selected_action_kind == "cheat" else "legal"
	var action = host._available_game_action(host.selected_action_id, host.selected_action_kind)
	var detail = host._game_action_choice_summary(action, host.selected_action_kind)
	if detail.is_empty():
		detail = "Click the highlighted surface action again to resolve."
	else:
		detail = "%s Click the highlighted surface action again to resolve." % detail
	return "%s action: %s at stake %d. %s" % [
		kind.capitalize(),
		host.selected_action_label,
		host._current_selected_stake(),
		detail,
	]


static func game_recent_outcome_text(host: Variant) -> String:
	var result = host._current_game_result_snapshot()
	if result.is_empty():
		return "No game outcome yet."
	var message = host._player_facing_text(str(result.get("message", "")))
	var deltas: Dictionary = result.get("deltas", {})
	var bankroll_delta = int(result.get("bankroll_delta", deltas.get("bankroll_delta", 0)))
	var suspicion_delta = int(result.get("suspicion_delta", deltas.get("suspicion_delta", 0)))
	return "%s Bankroll %+d, heat %+d." % [
		message if not message.is_empty() else "Recent play resolved.",
		bankroll_delta,
		suspicion_delta,
	]


static func stake_range(host: Variant, action_view: Dictionary = {}) -> Dictionary:
	if host.run_state == null:
		return {"min": 1, "max": 1, "default": 1, "has_valid": false}
	if host.current_game != null:
		var view = action_view
		if view.is_empty():
			view = host.current_game.actions(host.run_state, host.run_state.current_environment)
		return host._stake_range_from_action_view(view)
	return host._stake_range_from_action_view(action_view)


static func stake_range_from_action_view(host: Variant, action_view: Dictionary = {}) -> Dictionary:
	if host.run_state == null:
		return {"min": 1, "max": 1, "default": 1, "has_valid": false}
	var floor = 1
	var display_bankroll = host._presented_bankroll()
	var ceiling = display_bankroll
	var economic_profile: Dictionary = host.run_state.current_environment.get("economic_profile", {})
	floor = int(economic_profile.get("stake_floor", floor))
	ceiling = int(economic_profile.get("stake_ceiling", ceiling))
	if not action_view.is_empty():
		floor = int(action_view.get("stake_floor", floor))
		ceiling = int(action_view.get("stake_ceiling", ceiling))
	var min_stake = maxi(1, floor)
	var max_stake = mini(ceiling, display_bankroll)
	var has_valid = max_stake >= min_stake
	return {
		"min": min_stake,
		"max": max_stake,
		"base_max": int(action_view.get("base_stake_ceiling", ceiling)) if not action_view.is_empty() else ceiling,
		"recommended_max": int(action_view.get("economy_stake_ceiling", max_stake)) if not action_view.is_empty() else host.run_state.economy_stake_ceiling(ceiling),
		"default": min_stake if has_valid else 0,
		"has_valid": has_valid,
		"economy_state": host.run_state.economy(),
		"economy_pressure_applied": bool(action_view.get("economy_pressure_applied", false)) if not action_view.is_empty() else max_stake < mini(ceiling, display_bankroll),
	}


static func game_action_view_list(host: Variant, action_kind: String) -> Array:
	if host.current_game == null or host.run_state == null:
		return []
	var source = host.current_game.legal_actions(host.run_state, host.run_state.current_environment)
	if action_kind == "cheat":
		source = host.current_game.cheat_actions(host.run_state, host.run_state.current_environment)
	var actions: Array = []
	for action in source:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var action_data = action as Dictionary
		var action_id = str(action_data.get("id", ""))
		if action_id.is_empty():
			continue
		actions.append({
			"id": action_id,
			"kind": action_kind,
			"label": host._action_label(action_data),
			"summary": host._game_action_choice_summary(action_data, action_kind),
			"win_chance": int(action_data.get("win_chance", 0)),
			"payout_mult": int(action_data.get("payout_mult", 0)),
			"suspicion_delta": int(action_data.get("suspicion_delta", 0)),
			"selected": action_id == host.selected_action_id and action_kind == host.selected_action_kind,
		})
	return actions


static func available_game_action(host: Variant, action_id: String, action_kind: String) -> Dictionary:
	var source = host.current_game.legal_actions(host.run_state, host.run_state.current_environment)
	if action_kind == "cheat":
		source = host.current_game.cheat_actions(host.run_state, host.run_state.current_environment)
	for action in source:
		if typeof(action) == TYPE_DICTIONARY and str((action as Dictionary).get("id", "")) == action_id:
			return (action as Dictionary).duplicate(true)
	return {}


static func action_label(host: Variant, action: Dictionary) -> String:
	var label = str(action.get("label", ""))
	if not label.is_empty():
		return label
	var action_id = str(action.get("id", ""))
	if action_id.is_empty():
		return "Action"
	return action_id.replace("_", " ").capitalize()


static func action_kind_label(host: Variant, action_kind: String) -> String:
	return "cheat/advantage" if action_kind == "cheat" else "legal"


static func game_action_choice_summary(host: Variant, action: Dictionary, action_kind: String = "") -> String:
	if action.is_empty():
		return ""
	var parts: Array = []
	var win_chance = int(action.get("win_chance", 0))
	if win_chance > 0:
		parts.append("Win %d%%" % win_chance)
	var payout_mult = int(action.get("payout_mult", 0))
	if payout_mult > 0:
		parts.append("Pay %dx" % payout_mult)
	var suspicion_delta = int(action.get("suspicion_delta", 0))
	if suspicion_delta != 0:
		parts.append("Heat %s" % host._signed_int_text(suspicion_delta))
	elif action_kind == "cheat":
		parts.append("Heat risk")
	return " / ".join(parts)


static func eligible_event_option_view_list(host: Variant) -> Array:
	if host.run_state == null or host.library == null:
		return []
	var options: Array = []
	for event_id in host._string_array(host.run_state.current_environment.get("event_ids", [])):
		if event_id == RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID and host.run_state.is_grand_casino_environment():
			continue
		var option = host._eligible_event_option(event_id)
		if option.is_empty():
			continue
		if str(option.get("interaction_mode", "interactable")) != "interactable":
			continue
		options.append(option)
	return options


static func eligible_event_option(host: Variant, event_id: String) -> Dictionary:
	if host.run_state != null and event_id == RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID and host.run_state.is_grand_casino_environment():
		return {}
	return host._eligible_event_option_with_context(event_id, {})


static func eligible_event_option_with_context(host: Variant, event_id: String, context: Dictionary = {}, environment_override: Dictionary = {}) -> Dictionary:
	var event_definition = host.library.event(event_id)
	if event_definition.is_empty():
		return {}
	var event_module = EventModule.new()
	event_module.setup(event_definition, host.library)
	var event_environment = environment_override if not environment_override.is_empty() else host.run_state.current_environment
	if not event_module.can_trigger(host.run_state, event_environment, context):
		return {}
	var choices: Array = event_module.choices(host.run_state, event_environment)
	if choices.is_empty():
		return {}
	var payload: Dictionary = event_definition.get("payload", {})
	var option_choices: Array = []
	for choice in choices:
		if typeof(choice) != TYPE_DICTIONARY:
			continue
		var choice_data = (choice as Dictionary).duplicate(true)
		var choice_id = str(choice_data.get("id", ""))
		if choice_id.is_empty():
			continue
		option_choices.append({
			"id": choice_id,
			"label": str(choice_data.get("label", choice_id)),
			"text": str(choice_data.get("text", "")),
			"event_type": event_module.get_event_type(),
			"consequences": host._copy_dict(choice_data.get("consequences", {})),
			"check": host._copy_dict(choice_data.get("check", {})),
			"consequence_summary": host._event_choice_consequence_summary(choice_data),
			"requires_confirm": host._event_choice_requires_confirmation(choice_data),
			"identity_summary": "Choice ID: %s" % choice_id,
			"impact_summary": host._event_choice_consequence_summary(choice_data),
			"selected": event_id == host.selected_event_id and choice_id == host.selected_event_choice_id,
		})
		var last_index = option_choices.size() - 1
		var option_choice: Dictionary = option_choices[last_index]
		option_choice["attribute_badges"] = host.AttributeBadgesScript.for_event_choice(option_choice)
		option_choices[last_index] = option_choice
	return {
		"id": event_id,
		"display_name": event_module.get_display_name(),
		"type": event_module.get_event_type(),
		"interaction_mode": event_module.get_interaction_mode(),
		"summary": str(payload.get("summary", "")),
		"asset_path": str(event_definition.get("asset_path", "")),
		"visual_key": str(event_definition.get("visual_key", event_definition.get("type", "event"))),
		"icon_key": str(event_definition.get("icon_key", event_id)),
		"environment_prop": str(event_definition.get("environment_prop", event_definition.get("prop", ""))),
		"unique_object_class": str(event_definition.get("unique_object_class", "")).strip_edges(),
		"unique_object_priority": int(event_definition.get("unique_object_priority", 0)),
		"allow_duplicate_unique_class": bool(event_definition.get("allow_duplicate_unique_class", false)),
		"start_summary": str(event_definition.get("start_summary", "Choose a response.")),
		"choices": option_choices,
	}


static func event_choice(host: Variant, event_option: Dictionary, choice_id: String) -> Dictionary:
	for choice in event_option.get("choices", []):
		if typeof(choice) == TYPE_DICTIONARY and str((choice as Dictionary).get("id", "")) == choice_id:
			return (choice as Dictionary).duplicate(true)
	return {}


static func event_choice_list_summary(_host: Variant, choices: Array) -> String:
	var parts: Array = []
	for choice in choices:
		if typeof(choice) != TYPE_DICTIONARY:
			continue
		var choice_data = choice as Dictionary
		var label = str(choice_data.get("label", choice_data.get("id", ""))).strip_edges()
		if label.is_empty():
			continue
		parts.append(label)
		if parts.size() >= 3:
			break
	if parts.is_empty():
		return ""
	return "Choices: %s" % "; ".join(parts)


static func event_choice_consequence_summary(host: Variant, choice_data: Dictionary) -> String:
	var consequences: Dictionary = choice_data.get("consequences", {}) if typeof(choice_data.get("consequences", {})) == TYPE_DICTIONARY else {}
	var parts: Array = []
	var bankroll_delta = int(consequences.get("bankroll_delta", 0))
	if bankroll_delta != 0:
		parts.append("Bankroll %s" % host._signed_int_text(bankroll_delta))
	var suspicion_delta = int(consequences.get("suspicion_delta", 0))
	if suspicion_delta != 0:
		parts.append("Heat %s" % host._signed_int_text(suspicion_delta))
	if consequences.has("debt") or not host._copy_array(consequences.get("debt_changes", [])).is_empty():
		parts.append("Debt changes")
	var flags_value: Variant = consequences.get("flags", consequences.get("flags_set", {}))
	if typeof(flags_value) == TYPE_DICTIONARY and not (flags_value as Dictionary).is_empty():
		parts.append("Story flag")
	if not str(consequences.get("set_story_flag", "")).strip_edges().is_empty() or not host._string_array(consequences.get("set_story_flags", [])).is_empty():
		parts.append("Story flag")
	if not host._string_array(consequences.get("set_next_archetypes", [])).is_empty() or not host._string_array(consequences.get("add_next_archetypes", [])).is_empty() or not host._copy_array(consequences.get("travel_hooks_add", [])).is_empty():
		parts.append("Routes change")
	if not str(consequences.get("unlock_travel_route", "")).strip_edges().is_empty() or not host._string_array(consequences.get("unlock_travel_routes", [])).is_empty():
		parts.append("Routes change")
	var travel_changes: Variant = consequences.get("travel_changes", {})
	if typeof(travel_changes) == TYPE_DICTIONARY and not (travel_changes as Dictionary).is_empty():
		parts.append("Routes change")
	if not host._copy_array(consequences.get("inventory_add", [])).is_empty() or not host._copy_array(consequences.get("inventory_remove", [])).is_empty():
		parts.append("Inventory changes")
	if parts.is_empty():
		parts.append("Event closes" if bool(consequences.get("resolve_event", false)) else "No immediate cost")
	return "; ".join(parts)


static func event_choice_requires_confirmation(host: Variant, choice_data: Dictionary) -> bool:
	var consequences: Dictionary = choice_data.get("consequences", {}) if typeof(choice_data.get("consequences", {})) == TYPE_DICTIONARY else {}
	if int(consequences.get("bankroll_delta", 0)) < 0 or int(consequences.get("suspicion_delta", 0)) > 0:
		return true
	if consequences.has("debt") or not host._copy_array(consequences.get("debt_changes", [])).is_empty():
		return true
	if bool(consequences.get("ended", false)):
		return true
	return false


static func signed_int_text(host: Variant, value: int) -> String:
	return "+%d" % value if value > 0 else str(value)
