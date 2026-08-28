class_name CrapsGame
extends GameModule

const CrapsRulesScript := preload("res://scripts/games/craps/craps_rules.gd")
const CrapsSurfaceViewModelScript := preload("res://scripts/games/craps/craps_surface_view_model.gd")

const ROLL_CHANNEL := "craps_roll"
const THROW_ACTION := "craps_throw"
const THROW_REGION := Rect2(260, 112, 330, 142)
const THROW_MIN_DISTANCE := 34.0
const THROW_MAX_DISTANCE := 360.0


func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
	var result := super.enter(run_state, environment)
	var table := _table_state_preview(run_state, environment)
	if _is_street_variant(environment):
		var variant := _street_config()
		var guidance := _dict(variant.get("guidance", {}))
		var seen_flag := str(guidance.get("seen_flag", "street_craps_guidance_seen"))
		var lines := _string_array(guidance.get("lines", []))
		if run_state != null and not bool(run_state.narrative_flags.get(seen_flag, false)) and not lines.is_empty():
			var line_index := _stable_hash("%s:%s" % [str(run_state.seed_value), seen_flag]) % lines.size()
			result["message"] = "%s palms the dice. \"%s\"" % [str(table.get("dealer_name", "The caller")), str(lines[line_index])]
		else:
			result["message"] = "%s opens the chalk ring. Cash only, %d to %d." % [
				str(table.get("dealer_name", "The caller")),
				int(table.get("table_minimum", 0)),
				int(table.get("table_maximum", 0)),
			]
		return result
	result["message"] = "%s sets the dice at %s. The minimum is %d chips." % [
		str(table.get("dealer_name", "The stickperson")),
		str(table.get("table_name", "the craps table")),
		int(table.get("table_minimum", 0)),
	]
	return result


func generate_environment_state(_run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var config := _config()
	var street := _is_street_variant(environment)
	var variant := _street_config() if street else {}
	var rules := _dict(config.get("rules", {})).duplicate(true)
	var economic: Dictionary = environment.get("economic_profile", {}) if typeof(environment.get("economic_profile", {})) == TYPE_DICTIONARY else {}
	var authored_minimum := int(variant.get("minimum_stake", config.get("minimum_stake", 1)))
	var authored_maximum := int(variant.get("maximum_stake", config.get("maximum_stake", authored_minimum)))
	var table_minimum := maxi(authored_minimum, GameModule.stake_floor_for_game(environment, get_id(), authored_minimum))
	var table_maximum := maxi(table_minimum, mini(authored_maximum, GameModule.stake_ceiling_for_game(environment, get_id(), authored_maximum)))
	var table := {
		"schema": "craps_table_state",
		"version": int(config.get("state_version", 1)),
		"table_name": str(rng.pick(_array(variant.get("circle_names", config.get("table_names", []))), "The Chalk Ring" if street else "Marble Dice")),
		"dealer_name": str(rng.pick(_array(variant.get("caller_names", config.get("dealer_names", []))), "The caller" if street else "The stickperson")),
		"table_minimum": maxi(table_minimum, int(economic.get("stake_floor", table_minimum))),
		"table_maximum": table_maximum if street else maxi(table_maximum, int(economic.get("stake_ceiling", table_maximum))),
		"chip_denominations": _int_array(variant.get("denominations", config.get("chip_denominations", []))),
		"rules": rules,
		"point": 0,
		"working_bets": _empty_working_bets(),
		"roll_count": 0,
		"roll_history": [],
		"last_roll": {},
		"last_result": {},
		"hot_shooter_streak": 0,
		"table_energy": int(rules.get("table_energy_min", 0)),
		"last_committed_bets": {},
		"last_resolved_bets": {},
		"ritual_sequence": 0,
		"normalized_version": int(config.get("state_version", 1)),
	}
	if street:
		table["variant_id"] = "street_craps"
		table["street_dispersed"] = false
		table["street_disperse_reason"] = ""
	return table


func cheat_actions(run_state: RunState, environment: Dictionary) -> Array:
	var actions := super.cheat_actions(run_state, environment)
	if not _is_street_variant(environment):
		return actions
	var street_actions: Array = []
	for action_value in actions:
		if typeof(action_value) == TYPE_DICTIONARY and str((action_value as Dictionary).get("id", "")) == "dice_setting":
			street_actions.append((action_value as Dictionary).duplicate(true))
	return street_actions


func surface_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var table := _table_state_preview(run_state, environment)
	var street := _is_street_table(table, environment)
	var dispersed := street and bool(table.get("street_dispersed", false))
	var warning_reason := _street_disperse_reason(run_state, environment, 0) if street and not dispersed else ""
	var warning := not warning_reason.is_empty()
	var rules := _dict(table.get("rules", {}))
	var pending := _pending_bets(ui_state.get("craps_pending_bets", {}))
	var selected_chip := int(ui_state.get("selected_chip", _first_chip(table)))
	var targets := _street_bet_targets(table, rules) if street else CrapsSurfaceViewModelScript.bet_targets(table, rules)
	if dispersed:
		for target_value in targets:
			if typeof(target_value) == TYPE_DICTIONARY:
				(target_value as Dictionary)["enabled"] = false
	var total_wager := CrapsRulesScript.pending_wager_total(pending)
	var last_roll := _dict(table.get("last_roll", {}))
	var roll_started := int(last_roll.get("resolved_at_msec", 0))
	var duration := int(_config().get("roll_animation_duration_msec", 0))
	var now_msec := GameModule.deterministic_time_msec(run_state, ui_state)
	var roll_active := roll_started > 0 and now_msec >= roll_started and now_msec < roll_started + duration
	var presentation_phase := _presentation_phase(last_roll, now_msec, duration, dispersed, "warning" if warning else str(ui_state.get("craps_ritual_phase", "")))
	var setting_challenge := _dict(ui_state.get("craps_setting_challenge", {}))
	var switching_challenge := _dict(ui_state.get("craps_switching_challenge", {}))
	var setting_active := not setting_challenge.is_empty() and str(setting_challenge.get("skill_grade", "")).is_empty()
	var switching_active := not switching_challenge.is_empty() and str(switching_challenge.get("skill_grade", "")).is_empty()
	var last_result := _dict(table.get("last_result", {}))
	var accounting := _last_roll_accounting(last_result)
	var available_cash := int(run_state.bankroll) if run_state != null else 0
	var available_chips := int(run_state.grand_casino_chips) if run_state != null else 0
	var spec := GameModule.surface_spec({
		"surface_renderer": "craps",
		"surface_life": "street_circle" if street else "immersive_table",
		"surface_cast": "circle_of_players" if street else "dealer_table",
		"surface_time_msec": now_msec,
		"surface_presentation_time_msec": int(ui_state.get("surface_presentation_time_msec", now_msec)),
		"reduce_motion": bool(ui_state.get("reduce_motion", false)),
		"surface_controls_native": true,
		"surface_stake_controls_required": true,
		"surface_embeds_outcomes": true,
		"surface_suppresses_game_result_burst": true,
		"surface_animates_idle": true,
		"surface_realtime_state_refresh": setting_active or switching_active,
		"surface_dynamic_overlay_channels": [ROLL_CHANNEL],
		"surface_animation_channels": [GameModule.surface_animation_channel(
			ROLL_CHANNEL,
			str(last_roll.get("animation_id", "")) if roll_active else "",
			duration if roll_active else 0,
			roll_started,
			{"clock_source": "surface", "metadata": {"dice": _int_array(last_roll.get("dice", []))}}
		)],
		"surface_action_blocks": _surface_action_blocks(),
		"surface_action_bindings": {
			"legal": {"action": "craps_roll", "index": 0},
			"cheat": {"action": "craps_setting", "index": 0},
		},
		"native_selected_surface_actions": _selected_surface_actions(setting_challenge, switching_challenge),
		"surface_state_labels": [
			{"label": "Point", "value": "OFF" if int(table.get("point", 0)) == 0 else str(table.get("point", 0))},
			{"label": "New wagers", "value": "%d cash" % total_wager if street else "%d chips" % total_wager},
			{"label": "Circle", "value": "SCATTERED" if dispersed else "LIVE"} if street else {"label": "Energy", "value": str(table.get("table_energy", 0))},
		],
		"phase": presentation_phase,
		"ritual_phase": presentation_phase,
		"ritual_sequence": int(table.get("ritual_sequence", 0)),
		"table_name": str(table.get("table_name", "Craps")),
		"dealer_name": str(table.get("dealer_name", "Stickperson")),
		"point": int(table.get("point", 0)),
		"point_puck": {"on": int(table.get("point", 0)) != 0, "number": int(table.get("point", 0))},
		"bet_targets": targets,
		"craps_pending_bets": pending,
		"working_bets": _dict(table.get("working_bets", {})).duplicate(true),
		"working_bet_rows": CrapsSurfaceViewModelScript.working_rows(table),
		"selected_chip": selected_chip,
		"selected_stake": selected_chip,
		"chip_denominations": _chip_denominations(table),
		"total_wager_cost": total_wager,
		"craps_total_wager": total_wager,
		"available_cash": available_cash,
		"available_chips": available_chips,
		"available_funds": available_cash if street else available_chips,
		"at_risk_working_stake": _working_wager_total(table.get("working_bets", {})),
		"last_returned_stake": int(accounting.get("returned_stake", 0)),
		"last_payout": int(accounting.get("payout", 0)),
		"last_net": int(last_result.get("bankroll_delta", 0)),
		"table_minimum": int(table.get("table_minimum", 0)),
		"table_maximum": int(table.get("table_maximum", 0)),
		"can_roll": (warning or _can_roll(table, pending)) and not roll_active and not dispersed,
		"can_clear": not pending.is_empty() and not roll_active and not dispersed and not warning,
		"can_undo": not _dictionary_array(ui_state.get("craps_pending_history", [])).is_empty() and not roll_active and not dispersed and not warning,
		"can_remove": not pending.is_empty() and not roll_active and not dispersed and not warning,
		"can_repeat": not _dict(table.get("last_committed_bets", {})).is_empty() and pending.is_empty() and not roll_active and not dispersed and not warning,
		"can_rebet": not _dict(table.get("last_resolved_bets", {})).is_empty() and pending.is_empty() and not roll_active and not dispersed and not warning,
		"last_roll": last_roll.duplicate(true),
		"last_result": last_result.duplicate(true),
		"roll_history": CrapsSurfaceViewModelScript.roll_history_rows(table.get("roll_history", []), int(_config().get("visible_history_limit", 0))),
		"hot_shooter_streak": int(table.get("hot_shooter_streak", 0)),
		"table_energy": int(table.get("table_energy", 0)),
		"ritual_actors": _ritual_actors(table, street, warning),
		"ritual_scene_objects": _ritual_scene_objects(table, street, presentation_phase),
		"ritual_energy_tier": _energy_tier(table),
		"craps_setting_available": _setting_available(run_state, environment) and not dispersed,
		"craps_switching_available": _switching_available(run_state) and not street and not dispersed,
		"craps_setting_challenge": setting_challenge.duplicate(true),
		"craps_switching_challenge": switching_challenge.duplicate(true),
		"craps_setting_item_modifiers": skill_item_modifier_badges(run_state, _string_array(_dict(_config().get("setting", {})).get("item_effect_keys", []))),
		"craps_switching_item_modifiers": skill_item_modifier_badges(run_state, _string_array(_dict(_config().get("switching", {})).get("item_effect_keys", []))),
		"result_message": str(last_result.get("message", "")),
		"table_notice": _table_notice(table, pending, street),
	})
	if street:
		spec["craps_variant"] = "street_craps"
		spec["street_presentation"] = str(_street_config().get("presentation", "street_circle"))
		spec["currency"] = str(_street_config().get("currency", "cash"))
		spec["street_dispersed"] = dispersed
		spec["street_disperse_reason"] = str(table.get("street_disperse_reason", ""))
		spec["street_warning"] = warning
		spec["street_warning_reason"] = warning_reason
	return spec


func draw_surface(surface, state: Dictionary, _render_context: Dictionary = {}) -> bool:
	if str(state.get("craps_variant", "")) == "street_craps":
		return _draw_street_surface(surface, state)
	var board := Vector2(900, 474)
	surface.surface_begin_design_space(board)
	surface.draw_rect(Rect2(Vector2.ZERO, board), Color("#071713"))
	surface.draw_rect(Rect2(54, 52, 704, 332), Color("#0b513c"))
	surface.draw_rect(Rect2(54, 52, 704, 332), Color("#e3c675"), false, 2)
	surface.surface_title(str(state.get("table_name", "CRAPS")).to_upper(), Vector2(68, 38), Color("#f5e6a8"))
	_draw_idle_rail_motion(surface)
	_draw_casino_ritual_cast(surface, state)
	_draw_targets(surface, state)
	_draw_point_puck(surface, state)
	_draw_dice(surface, state)
	_draw_history(surface, state)
	_draw_working_bets(surface, state)
	_draw_controls(surface, state)
	surface.surface_end_design_space()
	return true


func surface_motion_signature(surface, _surface_state: Dictionary) -> Dictionary:
	var motion := _idle_rail_motion(surface)
	return {
		"rail_marker_x_tenth": int(round(float(motion.get("marker_x", 0.0)) * 10.0)),
		"rail_glow_milli": int(round(float(motion.get("glow", 0.0)) * 1000.0)),
	}


func surface_action_command(surface_action: String, index: int, _confirm_requested: bool, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var table := _table_state_preview(run_state, environment)
	var session := ui_state.duplicate(true)
	var street := _is_street_table(table, environment)
	if street and bool(table.get("street_dispersed", false)):
		return _message_command(session, "The chalk ring is empty for the rest of tonight.")
	var pending := _pending_bets(session.get("craps_pending_bets", {}))
	var warning_reason := _street_disperse_reason(run_state, environment, 0) if street else ""
	if not warning_reason.is_empty():
		if surface_action == "craps_roll":
			session["craps_ritual_phase"] = "warning"
			return GameModule.surface_command({"ui_state": session, "preserve_surface_ui_state": true, "message": "The lookout calls the warning. Break up now; every unresolved stake returns at face value.", "surface_audio_cue": "dice_shake"})
		if surface_action == "craps_throw":
			return _throw_resolve_command(session, pending)
		return _message_command(session, "No new cash crosses the ring after the lookout's warning.")
	match surface_action:
		"craps_bet":
			var targets := _street_bet_targets(table, _dict(table.get("rules", {}))) if street else CrapsSurfaceViewModelScript.bet_targets(table, _dict(table.get("rules", {})))
			if index < 0 or index >= targets.size():
				return _message_command(session, "That wager is not available.")
			var target: Dictionary = targets[index]
			if not bool(target.get("enabled", false)):
				return _message_command(session, "That wager is not working in this phase.")
			var bet_id := str(target.get("id", ""))
			var chip := int(session.get("selected_chip", _first_chip(table)))
			var validation := CrapsRulesScript.can_place_bet(bet_id, chip, table, pending, _dict(table.get("rules", {})))
			if not bool(validation.get("ok", false)):
				return _message_command(session, str(validation.get("message", "The wager is not available.")))
			if CrapsRulesScript.pending_wager_total(pending) + chip > _wager_capacity(run_state, environment):
				return _message_command(session, "Those chips exceed the funds available for this table.")
			_push_pending_history(session, pending)
			pending[bet_id] = int(pending.get(bet_id, 0)) + chip
			session["craps_pending_bets"] = pending
			session["craps_last_pending_id"] = bet_id
			return GameModule.surface_command({"ui_state": session, "surface_audio_cue": "blackjack_chip"})
		"craps_chip":
			var chips := _chip_denominations(table)
			if chips.is_empty():
				return _message_command(session, "No chip rack is posted.")
			if index >= 0 and index < chips.size():
				session["selected_chip"] = int(chips[index])
			else:
				var current := int(session.get("selected_chip", chips[0]))
				var chip_index := chips.find(current)
				session["selected_chip"] = int(chips[(chip_index + 1) % chips.size()])
			return GameModule.surface_command({"ui_state": session, "set_stake": int(session["selected_chip"]), "surface_audio_cue": "blackjack_chip"})
		"craps_clear":
			_push_pending_history(session, pending)
			session["craps_pending_bets"] = {}
			return GameModule.surface_command({"ui_state": session, "surface_audio_cue": "roulette_chip_sweep"})
		"craps_remove":
			if pending.is_empty():
				return _message_command(session, "There is no pending wager to correct.")
			var remove_id := _pending_id_for_correction(pending, str(session.get("craps_last_pending_id", "")))
			var remove_amount := mini(int(pending.get(remove_id, 0)), int(session.get("selected_chip", _first_chip(table))))
			_push_pending_history(session, pending)
			pending[remove_id] = int(pending.get(remove_id, 0)) - remove_amount
			if int(pending.get(remove_id, 0)) <= 0:
				pending.erase(remove_id)
			session["craps_pending_bets"] = pending
			return GameModule.surface_command({"ui_state": session, "surface_audio_cue": "roulette_chip_sweep", "message": "%d returned from %s." % [remove_amount, remove_id.replace("_", " ").capitalize()]})
		"craps_undo":
			var history := _dictionary_array(session.get("craps_pending_history", []))
			if history.is_empty():
				return _message_command(session, "There is no pending change to undo.")
			session["craps_pending_bets"] = history.pop_back()
			session["craps_pending_history"] = history
			return GameModule.surface_command({"ui_state": session, "surface_audio_cue": "roulette_chip_sweep", "message": "The last pending change is undone."})
		"craps_repeat", "craps_rebet":
			var source_key := "last_committed_bets" if surface_action == "craps_repeat" else "last_resolved_bets"
			var repeated := _pending_bets(table.get(source_key, {}))
			if repeated.is_empty():
				return _message_command(session, "There is no eligible wager set to restore.")
			var repeated_validation := _validate_pending_bets(table, repeated, street)
			if not bool(repeated_validation.get("ok", false)):
				return _message_command(session, str(repeated_validation.get("message", "That wager set is not legal in this phase.")))
			if CrapsRulesScript.pending_wager_total(repeated) > _wager_capacity(run_state, environment):
				return _message_command(session, "That wager set exceeds the funds available now.")
			_push_pending_history(session, pending)
			session["craps_pending_bets"] = repeated
			return GameModule.surface_command({"ui_state": session, "surface_audio_cue": "blackjack_chip", "message": "The eligible wager set is staged again."})
		"craps_roll":
			if not _can_roll(table, pending):
				return _message_command(session, "Place a wager before the dice are offered.")
			session["craps_ritual_phase"] = "dice_offered"
			return GameModule.surface_command({"ui_state": session, "preserve_surface_ui_state": true, "message": "Dice offered. Drag across the throw lane, or press Throw for the equivalent house toss.", "surface_audio_cue": "dice_shake"})
		"craps_throw":
			if not _can_roll(table, pending):
				return _message_command(session, "The dice return without a wager being charged.")
			session["craps_ritual_phase"] = "aiming_throw"
			return _throw_resolve_command(session, pending)
		"craps_setting":
			return _timing_command("setting", session, run_state, table, environment)
		"craps_switch":
			if street:
				return _message_command(session, "Nobody in this circle lets a second pair near the brick.")
			return _timing_command("switching", session, run_state, table, environment)
	return {"handled": false}


func surface_pointer_uses_lightweight_ui_state(surface_action: String) -> bool:
	return surface_action == THROW_ACTION


func surface_pointer_command(surface_action: String, _index: int, phase: String, board_position: Vector2, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	if surface_action != THROW_ACTION:
		return {"handled": false}
	var session := ui_state.duplicate(true)
	var table := _table_state_preview(run_state, environment)
	var pending := _pending_bets(session.get("craps_pending_bets", {}))
	if not _can_roll(table, pending):
		return _message_command(session, "The dice return without a wager being charged.")
	if phase == "begin":
		if not THROW_REGION.has_point(board_position):
			return _message_command(session, "Begin the throw inside the marked dice lane.")
		session["craps_throw_origin"] = board_position
		session["craps_throw_position"] = board_position
		session["craps_ritual_phase"] = "aiming_throw"
		return GameModule.surface_command({"ui_state": session, "preserve_surface_ui_state": true, "surface_audio_cue": "dice_shake"}, true)
	if phase == "cancel":
		return _reject_throw(session, "The stickperson gathers the incomplete throw. No wager is charged.")
	if phase == "move":
		if not session.has("craps_throw_origin"):
			return _reject_throw(session, "The dice remain in the stickperson's hand.")
		session["craps_throw_position"] = board_position
		return GameModule.surface_command({"ui_state": session, "preserve_surface_ui_state": true}, true)
	if phase != "end" or not session.has("craps_throw_origin"):
		return _reject_throw(session, "The dice remain in the stickperson's hand.")
	var origin: Vector2 = session.get("craps_throw_origin", board_position)
	var distance := origin.distance_to(board_position)
	if distance < THROW_MIN_DISTANCE or distance > THROW_MAX_DISTANCE or board_position.y >= origin.y - 8.0:
		return _reject_throw(session, "That release does not reach the far wall. The dice come back; no wager is charged.")
	session.erase("craps_throw_origin")
	session.erase("craps_throw_position")
	session["craps_throw_vector"] = board_position - origin
	session["craps_ritual_phase"] = "aiming_throw"
	return _throw_resolve_command(session, pending, true)


func _throw_resolve_command(session: Dictionary, pending: Dictionary, direct: bool = false) -> Dictionary:
	var command := {
		"ui_state": session,
		"action_id": "roll_craps",
		"action_kind": "legal",
		"set_stake": CrapsRulesScript.pending_wager_total(pending),
		"preserve_surface_ui_state": true,
		"surface_audio_cue": "dice_roll",
	}
	command["direct_resolve" if direct else "resolve"] = true
	return GameModule.surface_command(command, direct)


func _reject_throw(session: Dictionary, message: String) -> Dictionary:
	session.erase("craps_throw_origin")
	session.erase("craps_throw_position")
	session.erase("craps_throw_vector")
	session["craps_ritual_phase"] = "dice_offered"
	return GameModule.surface_command({
		"ui_state": session,
		"preserve_surface_ui_state": true,
		"message": message,
		"surface_audio_cue": "dice_shake",
	}, true)


func wager_cost_for_context(_action_id: String, stake: int, _run_state: RunState, _environment: Dictionary, ui_state: Dictionary = {}) -> int:
	var pending_total := CrapsRulesScript.pending_wager_total(ui_state.get("craps_pending_bets", {}))
	return pending_total if pending_total > 0 else maxi(0, stake)


func resolve(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return resolve_with_context(action_id, stake, run_state, environment, rng, {})


func resolve_with_context(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary = {}) -> Dictionary:
	if not ["roll_craps", "dice_setting", "dice_switching"].has(action_id):
		return _empty_result(action_id, stake, environment, "The stickperson does not recognize that call.")
	var table := _table_state(run_state, environment)
	var street := _is_street_table(table, environment)
	if street and action_id == "dice_switching":
		return _empty_result(action_id, stake, environment, "Street Craps offers the house dice only; no switch is available.")
	if street and bool(table.get("street_dispersed", false)):
		return _empty_result(action_id, stake, environment, "The chalk ring is empty for the rest of tonight.")
	var pending := _pending_bets(ui_state.get("craps_pending_bets", {}))
	if pending.is_empty() and stake > 0:
		if not street or int(table.get("point", 0)) == 0:
			pending["pass_line" if int(table.get("point", 0)) == 0 else "come"] = stake
	var pre_disperse_reason := _street_disperse_reason(run_state, environment, 0) if street else ""
	if not pre_disperse_reason.is_empty():
		return _resolve_street_disperse(run_state, environment, table, pending, pre_disperse_reason, rng)
	var pending_validation := _validate_pending_bets(table, pending, street)
	if not bool(pending_validation.get("ok", false)):
		return _empty_result(action_id, CrapsRulesScript.pending_wager_total(pending), environment, str(pending_validation.get("message", "Those wagers are not available.")))
	var total_wager := CrapsRulesScript.pending_wager_total(pending)
	if total_wager > _wager_capacity(run_state, environment):
		return _empty_result(action_id, total_wager, environment, "The wager exceeds the funds available at this table.")
	if not _can_roll(table, pending):
		return _empty_result(action_id, total_wager, environment, "The dice wait for a working wager.")

	var cheat := _cheat_context(action_id, ui_state, run_state, environment, table)
	if not bool(cheat.get("ok", false)):
		return _empty_result(action_id, total_wager, environment, str(cheat.get("message", "That move is not ready.")))
	var roll := CrapsRulesScript.roll_dice(rng, _dict(table.get("rules", {})), int(cheat.get("bias_permille", 0)))
	var settlement := CrapsRulesScript.settle_roll(table, pending, roll, _dict(table.get("rules", {})))
	table["last_committed_bets"] = pending.duplicate(true)
	table["last_resolved_bets"] = _resolved_rebet_set(pending, settlement)
	table["ritual_sequence"] = int(table.get("ritual_sequence", 0)) + 1
	var room_energy := _project_table_energy(environment, table)
	var settlement_delta := int(settlement.get("bankroll_delta", 0))
	var luck_payout_bonus := 0
	if settlement_delta > 0 and run_state != null:
		luck_payout_bonus = run_state.luck_payout_bonus(maxi(1, total_wager), true) + _item_effect_total("win_bonus", run_state)
	var bankroll_delta := settlement_delta + luck_payout_bonus + int(cheat.get("bankroll_delta", 0))
	var suspicion_delta := int(cheat.get("suspicion_delta", 0))
	var post_disperse_reason := _street_disperse_reason(run_state, environment, suspicion_delta) if street else ""
	var disperse_refund := 0
	if not post_disperse_reason.is_empty():
		disperse_refund = _working_wager_total(table.get("working_bets", {}))
		bankroll_delta += disperse_refund
		var disperse_results := _dictionary_array(settlement.get("bet_results", []))
		if disperse_refund > 0:
			disperse_results.append({"label": "Street interruption", "stake": disperse_refund, "profit": 0, "outcome": "refund"})
		settlement["bet_results"] = disperse_results
		_mark_street_dispersed(table, post_disperse_reason)
	var now_msec := GameModule.deterministic_time_msec(run_state, ui_state)
	var dice := _int_array(roll.get("dice", []))
	var message := _roll_message(roll, settlement, bankroll_delta, table)
	var training := _street_training_delta(run_state, settlement) if street else {}
	if not training.is_empty() and not str(training.get("message", "")).is_empty():
		message = "%s %s" % [message, str(training.get("message", ""))]
	if not post_disperse_reason.is_empty():
		message = "%s %s" % [message, str(_dict(_street_config().get("disperse", {})).get("message", "The circle breaks and unresolved stakes come back."))]
	var patron_line := str(room_energy.get("patron_line", ""))
	if not patron_line.is_empty():
		message = "%s %s" % [message, patron_line]
	var security_message := str(cheat.get("security_message", ""))
	if not security_message.is_empty():
		message = "%s %s" % [message, security_message]
	var last_roll := {
		"dice": dice,
		"total": int(roll.get("total", 0)),
		"initial_total": int(roll.get("initial_total", roll.get("total", 0))),
		"setting_bias_applied": bool(roll.get("setting_bias_applied", false)),
		"point_before": int(settlement.get("point_before", 0)),
		"point_after": int(settlement.get("point_after", 0)),
		"animation_id": "craps:%d:%d-%d" % [int(table.get("roll_count", 0)), int(dice[0]), int(dice[1])],
		"resolved_at_msec": now_msec,
	}
	table["last_roll"] = last_roll
	var history := _dictionary_array(table.get("roll_history", []))
	history.append(last_roll.duplicate(true))
	var history_limit := int(_config().get("stored_history_limit", 0))
	while history.size() > history_limit:
		history.pop_front()
	table["roll_history"] = history
	table["last_result"] = {
		"message": message,
		"bankroll_delta": bankroll_delta,
		"bet_results": _dictionary_array(settlement.get("bet_results", [])),
		"action_id": action_id,
		"skill_grade": str(cheat.get("skill_grade", "")),
	}
	_update_environment_table(environment, table)

	var action_kind := "legal" if action_id == "roll_craps" else "cheat"
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["suspicion_delta"] = suspicion_delta
	deltas["inventory_remove"] = _string_array(cheat.get("inventory_remove", []))
	deltas["messages"] = [message]
	var flags_set: Dictionary = _dict(training.get("flags_set", {})).duplicate(true) if not training.is_empty() else {}
	if street:
		flags_set[_street_guidance_seen_flag()] = true
	if not flags_set.is_empty():
		deltas["flags_set"] = flags_set
	var story_entry := {
		"type": "game_action",
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": action_kind,
		"stake": total_wager,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"roll_total": int(roll.get("total", 0)),
		"point_before": int(settlement.get("point_before", 0)),
		"point_after": int(settlement.get("point_after", 0)),
		"skill_grade": str(cheat.get("skill_grade", "")),
		"skill_outcome": str(cheat.get("skill_outcome", "")),
		"skill_accuracy": int(cheat.get("skill_accuracy", 0)),
		"skill_margin_msec": int(cheat.get("skill_margin_msec", 0)),
		"base_suspicion_delta": int(cheat.get("base_suspicion_delta", 0)),
		"pit_boss_watched": bool(cheat.get("pit_boss_watched", false)),
		"pit_boss_heat_bonus": int(cheat.get("pit_boss_heat_bonus", 0)),
		"security_message": security_message,
		"environment_id": environment.get("id", ""),
		"environment_archetype_id": environment.get("archetype_id", ""),
	}
	if street:
		story_entry["craps_variant"] = "street_craps"
		story_entry["street_disperse_reason"] = post_disperse_reason
		story_entry["street_disperse_refund"] = disperse_refund
	deltas["story_log"] = [story_entry]
	deltas["ended"] = bool(cheat.get("ended", false))
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": action_kind,
		"stake": total_wager,
		"craps_total_wager": total_wager,
		"luck_payout_bonus": luck_payout_bonus,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"deltas": deltas,
		"won": bankroll_delta > 0,
		"environment_id": environment.get("id", ""),
		"environment_archetype_id": environment.get("archetype_id", ""),
		"message": message,
		"craps_roll": last_roll.duplicate(true),
		"craps_point": int(table.get("point", 0)),
		"craps_working_bets": _dict(table.get("working_bets", {})).duplicate(true),
		"craps_bet_results": _dictionary_array(settlement.get("bet_results", [])),
		"craps_table_energy": int(table.get("table_energy", 0)),
		"craps_room_energy": room_energy.duplicate(true),
		"craps_hot_shooter_streak": int(table.get("hot_shooter_streak", 0)),
		"skill_grade": str(cheat.get("skill_grade", "")),
		"skill_outcome": str(cheat.get("skill_outcome", "")),
		"skill_accuracy": int(cheat.get("skill_accuracy", 0)),
		"skill_margin_msec": int(cheat.get("skill_margin_msec", 0)),
		"base_suspicion_delta": int(cheat.get("base_suspicion_delta", 0)),
		"pit_boss_watched": bool(cheat.get("pit_boss_watched", false)),
		"pit_boss_heat_bonus": int(cheat.get("pit_boss_heat_bonus", 0)),
		"skill_security_pressure_checked": action_kind == "cheat",
		"security_message": security_message,
	})
	# build_action_result intentionally normalizes only the shared action contract;
	# restore the Craps-owned settlement payload for UI, audit, and luck consumers.
	result["craps_total_wager"] = total_wager
	result["luck_payout_bonus"] = luck_payout_bonus
	result["craps_roll"] = last_roll.duplicate(true)
	result["craps_point"] = int(table.get("point", 0))
	result["craps_working_bets"] = _dict(table.get("working_bets", {})).duplicate(true)
	result["craps_bet_results"] = _dictionary_array(settlement.get("bet_results", []))
	result["craps_table_energy"] = int(table.get("table_energy", 0))
	result["craps_room_energy"] = room_energy.duplicate(true)
	result["craps_hot_shooter_streak"] = int(table.get("hot_shooter_streak", 0))
	result["craps_public_facts"] = _public_craps_facts(table, settlement, bankroll_delta, action_id, post_disperse_reason)
	result["craps_ritual_receipt"] = "craps.ritual.%d" % int(table.get("ritual_sequence", 0))
	if street:
		result["craps_variant"] = "street_craps"
		result["currency"] = "cash"
		result["street_dispersed"] = not post_disperse_reason.is_empty()
		result["street_disperse_reason"] = post_disperse_reason
		result["street_disperse_refund"] = disperse_refund
	if action_kind == "cheat":
		GameModule.normalize_skill_cheat_contract(result, result)
	GameModule.apply_result(run_state, result, rng)
	return result


func table_energy(run_state: RunState, environment: Dictionary) -> int:
	return int(_table_state_preview(run_state, environment).get("table_energy", 0))


func _project_table_energy(environment: Dictionary, table: Dictionary) -> Dictionary:
	var config := _dict(_config().get("crowd_energy", {})).duplicate(true)
	var scenario_modifiers := _dict(environment.get("scenario_game_modifiers", {}))
	var modifier_key := str(config.get("scenario_modifier_key", "craps_table_energy"))
	var scenario_tuning := _dict(scenario_modifiers.get(modifier_key, {}))
	for key in ["hot_threshold", "energy_multiplier", "music_intensity_scale", "max_volume_nudge", "max_ambience_nudge", "max_bpm_nudge", "patron_lines"]:
		if scenario_tuning.has(key):
			config[key] = scenario_tuning[key]
	var raw_energy := maxi(0, int(table.get("table_energy", 0)))
	var tuned_energy := int(round(float(raw_energy) * maxf(0.0, float(config.get("energy_multiplier", 1.0)))))
	var max_energy := maxi(1, int(_dict(table.get("rules", {})).get("table_energy_max", 100)))
	var intensity := clampf(float(tuned_energy) / float(max_energy) * maxf(0.0, float(config.get("music_intensity_scale", 1.0))), 0.0, 1.0)
	var prior := _dict(environment.get("craps_room_energy", {}))
	var music := _dict(environment.get("music_profile", {})).duplicate(true)
	var base_volume := float(prior.get("base_volume", music.get("volume", 0.0)))
	var base_ambience := float(prior.get("base_ambience", music.get("ambience", 0.0)))
	var base_bpm := float(prior.get("base_bpm", music.get("bpm", 0.0)))
	if not prior.is_empty():
		if not is_equal_approx(float(music.get("volume", base_volume)), float(prior.get("projected_volume", base_volume))):
			base_volume = float(music.get("volume", base_volume))
		if not is_equal_approx(float(music.get("ambience", base_ambience)), float(prior.get("projected_ambience", base_ambience))):
			base_ambience = float(music.get("ambience", base_ambience))
		if not is_equal_approx(float(music.get("bpm", base_bpm)), float(prior.get("projected_bpm", base_bpm))):
			base_bpm = float(music.get("bpm", base_bpm))
	if tuned_energy <= 0:
		if not prior.is_empty():
			music["volume"] = base_volume
			music["ambience"] = base_ambience
			music["bpm"] = base_bpm
			music.erase("craps_table_energy_intensity")
			environment["music_profile"] = music
		environment.erase("craps_room_energy")
		return {}
	var projected_volume := base_volume + float(config.get("max_volume_nudge", 0.0)) * intensity
	var projected_ambience := base_ambience + float(config.get("max_ambience_nudge", 0.0)) * intensity
	var projected_bpm := base_bpm + float(config.get("max_bpm_nudge", 0.0)) * intensity
	music["volume"] = projected_volume
	music["ambience"] = projected_ambience
	music["bpm"] = projected_bpm
	music["craps_table_energy_intensity"] = intensity
	environment["music_profile"] = music
	var lines := _string_array(config.get("patron_lines", []))
	var patron_line := ""
	if tuned_energy >= int(config.get("hot_threshold", max_energy + 1)) and not lines.is_empty():
		patron_line = str(lines[maxi(0, int(table.get("hot_shooter_streak", 1)) - 1) % lines.size()])
	var projection := {
		"source_game_id": get_id(),
		"table_energy": raw_energy,
		"tuned_energy": tuned_energy,
		"intensity": intensity,
		"hot_shooter_streak": int(table.get("hot_shooter_streak", 0)),
		"patron_line": patron_line,
		"base_volume": base_volume,
		"base_ambience": base_ambience,
		"base_bpm": base_bpm,
		"projected_volume": projected_volume,
		"projected_ambience": projected_ambience,
		"projected_bpm": projected_bpm,
		"scenario_tuning_applied": not scenario_tuning.is_empty(),
	}
	environment["craps_room_energy"] = projection
	return projection


func environment_object_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var table := _table_state_preview(run_state, environment)
	if _is_street_table(table, environment):
		var dispersed := bool(table.get("street_dispersed", false))
		var status_label := "CHALK RING OPEN"
		if dispersed:
			status_label = "CIRCLE SCATTERED"
		elif int(table.get("point", 0)) != 0:
			status_label = "POINT %d" % int(table.get("point", 0))
		return {
			"status_label": status_label,
			"status_detail": "Cash returned; gone for tonight" if dispersed else "$%d-$%d · Pass / Don't Pass" % [int(table.get("table_minimum", 0)), int(table.get("table_maximum", 0))],
			"active": not dispersed,
		}
	return {
		"status_label": "POINT %d" % int(table.get("point", 0)) if int(table.get("point", 0)) != 0 else "COME-OUT",
		"status_detail": "Table energy %d" % int(table.get("table_energy", 0)),
		"active": true,
	}


func _cheat_context(action_id: String, ui_state: Dictionary, run_state: RunState, environment: Dictionary, table: Dictionary) -> Dictionary:
	if action_id == "roll_craps":
		return {"ok": true}
	if action_id == "dice_setting" and not _setting_available(run_state, environment):
		return {"ok": false, "message": "Dice setting requires practice or a listed training aid."}
	if action_id == "dice_switching" and not _switching_available(run_state):
		return {"ok": false, "message": "Dice switching requires both the calipers and false-bottom cup."}
	var key := "setting" if action_id == "dice_setting" else "switching"
	var config := _dict(_config().get(key, {}))
	var challenge := _dict(ui_state.get("craps_%s_challenge" % key, {}))
	var grade := str(challenge.get("skill_grade", ui_state.get("craps_%s_grade" % key, "miss")))
	var margin := maxi(0, int(challenge.get("skill_margin_msec", 0)))
	var grade_config := _dict(_dict(config.get("grades", {})).get(grade, {}))
	var bias_permille := int(grade_config.get("bias_permille", 0))
	var success := bool(grade_config.get("success", action_id == "dice_setting"))
	if action_id == "dice_switching" and success and _has_any_item(run_state, _string_array(config.get("loaded_dice_item_ids", []))):
		bias_permille += int(config.get("loaded_dice_bias_bonus_permille", 0))
	var base_heat := maxi(0, int(config.get("base_suspicion", 0)) + int(grade_config.get("suspicion_modifier", 0)))
	var security_multiplier := _security_band_multiplier(environment, config)
	base_heat = int(ceil(float(base_heat) * security_multiplier))
	base_heat = maxi(0, base_heat + _item_effect_total("cheat_suspicion_delta", run_state))
	var pit_status := run_state.pit_boss_watch_status(environment) if run_state != null else {}
	var pit_bonus := int(pit_status.get("cheat_heat_bonus", 0)) if bool(pit_status.get("active", false)) else 0
	var raw_heat := base_heat + (run_state.security_risk_bonus("cheat") if run_state != null else 0) + pit_bonus
	var suspicion_delta := raw_heat
	var security_pressure := run_state.security_action_pressure("cheat", maxi(1, int(table.get("table_minimum", 1))), run_state.suspicion_level() + suspicion_delta) if run_state != null and suspicion_delta > 0 else {}
	var confiscated: Array = []
	if action_id == "dice_switching" and not success and bool(config.get("confiscate_on_failure", false)):
		confiscated = _string_array(config.get("required_item_ids", []))
	return {
		"ok": true,
		"bias_permille": clampi(bias_permille, 0, int(config.get("max_bias_permille", bias_permille))),
		"suspicion_delta": suspicion_delta,
		"base_suspicion_delta": base_heat,
		"bankroll_delta": int(security_pressure.get("bankroll_delta", 0)),
		"security_message": str(security_pressure.get("message", "")),
		"ended": bool(security_pressure.get("ended", false)),
		"inventory_remove": confiscated,
		"skill_grade": grade,
		"skill_outcome": "applied" if success else "caught" if action_id == "dice_switching" else "noticed",
		"skill_accuracy": int(grade_config.get("accuracy", 0)),
		"skill_margin_msec": margin,
		"pit_boss_watched": bool(pit_status.get("watched", false)),
		"pit_boss_heat_bonus": pit_bonus,
	}


func _timing_command(kind: String, session: Dictionary, run_state: RunState, table: Dictionary, environment: Dictionary) -> Dictionary:
	if kind == "setting" and not _setting_available(run_state, environment):
		return _message_command(session, "Practice or a listed training aid is required before setting dice.")
	if kind == "switching" and not _switching_available(run_state):
		return _message_command(session, "The switch requires Dice Calipers and a False-Bottom Cup.")
	var key := "craps_%s_challenge" % kind
	var challenge := _dict(session.get(key, {}))
	var config := _dict(_config().get(kind, {}))
	var now_msec := GameModule.deterministic_time_msec(run_state, session)
	if challenge.is_empty() or not str(challenge.get("skill_grade", "")).is_empty():
		var period := maxi(1, int(config.get("skill_period_msec", 1)))
		var stable := _stable_hash("%s:%s:%d" % [kind, str(table.get("table_name", "craps")), int(table.get("roll_count", 0))])
		challenge = {
			"started_msec": now_msec,
			"target_msec": now_msec + stable % period,
			"period_msec": period,
			"skill_grade": "",
			"skill_margin_msec": 0,
		}
		session[key] = challenge
		return GameModule.surface_command({"ui_state": session, "message": "Release inside the house window."})
	var margin := absi(now_msec - int(challenge.get("target_msec", now_msec)))
	var grade_data := GameModule.skill_timing_grade_from_distance(
		margin,
		int(config.get("skill_perfect_msec", 1)),
		int(config.get("skill_good_msec", 1)),
		int(config.get("skill_close_msec", 1))
	)
	challenge["skill_grade"] = str(grade_data.get("grade", "blown"))
	challenge["skill_margin_msec"] = margin
	session[key] = challenge
	return GameModule.surface_command({
		"ui_state": session,
		"action_id": "dice_setting" if kind == "setting" else "dice_switching",
		"action_kind": "cheat",
		"resolve": true,
		"set_stake": CrapsRulesScript.pending_wager_total(session.get("craps_pending_bets", {})),
	})


func _setting_available(run_state: RunState, environment: Dictionary = {}) -> bool:
	if run_state == null:
		return false
	if _is_street_variant(environment):
		return true
	if bool(run_state.narrative_flags.get(str(_dict(_config().get("setting", {})).get("practice_flag", "")), false)):
		return true
	return _has_any_item(run_state, _string_array(_dict(_config().get("setting", {})).get("practice_item_ids", [])))


func _switching_available(run_state: RunState) -> bool:
	if run_state == null:
		return false
	for item_id in _string_array(_dict(_config().get("switching", {})).get("required_item_ids", [])):
		if not run_state.inventory.has(item_id):
			return false
	return true


func _has_any_item(run_state: RunState, item_ids: Array) -> bool:
	if run_state == null:
		return false
	for item_id in item_ids:
		if run_state.inventory.has(str(item_id)):
			return true
	return false


func _security_band_multiplier(environment: Dictionary, config: Dictionary) -> float:
	var security: Dictionary = environment.get("security_profile", {}) if typeof(environment.get("security_profile", {})) == TYPE_DICTIONARY else {}
	var band := str(security.get("strictness", "standard"))
	return float(_dict(config.get("security_band_multipliers", {})).get(band, config.get("default_security_multiplier", 1.0)))


func _can_roll(table: Dictionary, pending: Dictionary) -> bool:
	return CrapsRulesScript.pending_wager_total(pending) > 0 or not CrapsSurfaceViewModelScript.working_rows(table).is_empty()


func _validate_pending_bets(table: Dictionary, pending: Dictionary, street: bool = false) -> Dictionary:
	var staged := {}
	var ordered_ids := _string_array(_street_config().get("allowed_bets", [])) if street else ["pass_line", "dont_pass", "come", "dont_come", "field", "place_4", "place_5", "place_6", "place_8", "place_9", "place_10", "pass_odds", "come_odds_4", "come_odds_5", "come_odds_6", "come_odds_8", "come_odds_9", "come_odds_10"]
	for bet_id_value in ordered_ids:
		var bet_id := str(bet_id_value)
		var amount := int(pending.get(bet_id, 0))
		if amount <= 0:
			continue
		var validation := CrapsRulesScript.can_place_bet(bet_id, amount, table, staged, _dict(table.get("rules", {})))
		if not bool(validation.get("ok", false)):
			return validation
		staged[bet_id] = amount
	for pending_id_value in pending.keys():
		if not ordered_ids.has(str(pending_id_value)):
			return {"ok": false, "message": "That wager is not offered at this table."}
	return {"ok": true}


func _wager_capacity(run_state: RunState, environment: Dictionary) -> int:
	return run_state.wager_capacity_for_game(get_id(), environment) if run_state != null else 0


func _table_notice(table: Dictionary, pending: Dictionary, street: bool = false) -> String:
	var point := int(table.get("point", 0))
	if street and bool(table.get("street_dispersed", false)):
		return "The chalk ring is empty. Every unresolved stake was returned."
	if CrapsRulesScript.pending_wager_total(pending) > 0:
		return "%d cash ready. The dice move only on your call." % CrapsRulesScript.pending_wager_total(pending) if street else "%d chips ready. The dice move only on your call." % CrapsRulesScript.pending_wager_total(pending)
	if point == 0:
		return "The puck is OFF. Pass and Don't Pass are open."
	if street:
		return "The point is %d. The line rides until the point or seven." % point
	return "The point is %d. Come, Place, and Odds are open." % point


func _roll_message(roll: Dictionary, settlement: Dictionary, bankroll_delta: int, table: Dictionary) -> String:
	var total := int(roll.get("total", 0))
	var prefix := "%d. %s calls the result." % [total, str(table.get("dealer_name", "The stickperson"))]
	if bool(settlement.get("point_made", false)):
		prefix = "%d, point made. The table receives it warmly." % total
	elif bool(settlement.get("seven_out", false)):
		prefix = "Seven out. The house clears the layout."
	elif int(settlement.get("point_before", 0)) == 0 and int(settlement.get("point_after", 0)) != 0:
		prefix = "%d is the point. The puck turns ON." % total
	var currency := "cash" if str(table.get("variant_id", "")) == "street_craps" else "chips"
	return "%s Net %s%d %s." % [prefix, "+" if bankroll_delta >= 0 else "", bankroll_delta, currency]


func _table_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var table := _normalize_table_state(states.get(get_id(), {}), environment)
	if table.is_empty():
		var rng := run_state.create_rng("craps_table") if run_state != null else _fallback_rng(environment)
		table = generate_environment_state(run_state, environment, rng)
	states[get_id()] = table
	environment["game_states"] = states
	return table


func _table_state_preview(run_state: RunState, environment: Dictionary) -> Dictionary:
	var states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var table := _normalize_table_state(states.get(get_id(), {}), environment)
	if not table.is_empty():
		return table
	return generate_environment_state(run_state, environment, _fallback_rng(environment))


func _normalize_table_state(value: Variant, environment: Dictionary) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var table: Dictionary = (value as Dictionary).duplicate(true)
	if str(table.get("schema", "")) != "craps_table_state":
		return {}
	table["point"] = int(table.get("point", 0))
	table["working_bets"] = _normalized_working(table.get("working_bets", {}))
	table["roll_history"] = _dictionary_array(table.get("roll_history", []))
	table["last_roll"] = _dict(table.get("last_roll", {})).duplicate(true)
	table["last_result"] = _dict(table.get("last_result", {})).duplicate(true)
	table["last_committed_bets"] = _pending_bets(table.get("last_committed_bets", {}))
	table["last_resolved_bets"] = _pending_bets(table.get("last_resolved_bets", {}))
	table["ritual_sequence"] = maxi(0, int(table.get("ritual_sequence", 0)))
	table["rules"] = _dict(table.get("rules", _dict(_config().get("rules", {})))).duplicate(true)
	table["chip_denominations"] = _int_array(table.get("chip_denominations", _config().get("chip_denominations", [])))
	table["table_minimum"] = maxi(1, int(table.get("table_minimum", GameModule.stake_floor_for_game(environment, get_id(), 1))))
	table["table_maximum"] = maxi(int(table.get("table_minimum", 1)), int(table.get("table_maximum", GameModule.stake_ceiling_for_game(environment, get_id(), 1))))
	if _is_street_variant(environment) or str(table.get("variant_id", "")) == "street_craps":
		table["variant_id"] = "street_craps"
		table["street_dispersed"] = bool(table.get("street_dispersed", false))
		table["street_disperse_reason"] = str(table.get("street_disperse_reason", ""))
	return table


func _normalized_working(value: Variant) -> Dictionary:
	var source := _dict(value)
	var result := _empty_working_bets()
	for key in ["pass_line", "dont_pass", "pass_odds"]:
		result[key] = maxi(0, int(source.get(key, 0)))
	for key in ["come", "dont_come", "come_odds", "place"]:
		var group := _dict(source.get(key, {}))
		var normalized := {}
		for number_key in group.keys():
			var stake := maxi(0, int(group.get(number_key, 0)))
			if stake > 0:
				normalized[str(number_key)] = stake
		result[key] = normalized
	return result


func _empty_working_bets() -> Dictionary:
	return {"pass_line": 0, "dont_pass": 0, "pass_odds": 0, "come": {}, "dont_come": {}, "come_odds": {}, "place": {}}


func _update_environment_table(environment: Dictionary, table: Dictionary) -> void:
	var states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	states[get_id()] = table
	environment["game_states"] = states


func _pending_bets(value: Variant) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key_value in (value as Dictionary).keys():
		var stake := maxi(0, int((value as Dictionary).get(key_value, 0)))
		if stake > 0:
			result[str(key_value)] = stake
	return result


func _push_pending_history(session: Dictionary, pending: Dictionary) -> void:
	var history := _dictionary_array(session.get("craps_pending_history", []))
	history.append(pending.duplicate(true))
	while history.size() > 16:
		history.pop_front()
	session["craps_pending_history"] = history


func _pending_id_for_correction(pending: Dictionary, preferred: String) -> String:
	if pending.has(preferred):
		return preferred
	var ids := _string_array(pending.keys())
	ids.sort()
	return ids.back() if not ids.is_empty() else ""


func _resolved_rebet_set(pending: Dictionary, settlement: Dictionary) -> Dictionary:
	var resolved_labels := {}
	for result_value in _dictionary_array(settlement.get("bet_results", [])):
		var result: Dictionary = result_value
		if str(result.get("outcome", "")) in ["win", "loss", "push", "refund"]:
			resolved_labels[str(result.get("label", "")).to_lower()] = true
	var rebet := {}
	for bet_id_value in pending.keys():
		var bet_id := str(bet_id_value)
		var label := bet_id.replace("_", " ")
		if resolved_labels.has(label) or bet_id in ["field", "come", "dont_come"]:
			rebet[bet_id] = int(pending.get(bet_id, 0))
	return rebet


func _presentation_phase(last_roll: Dictionary, now_msec: int, duration: int, dispersed: bool, requested_phase: String = "") -> String:
	if dispersed or warning:
		return "dispersed"
	var started := int(last_roll.get("resolved_at_msec", 0))
	if started > 0 and duration > 0 and now_msec >= started and now_msec < started + duration:
		var elapsed := now_msec - started
		if elapsed < duration * 55 / 100:
			return "bounce_read"
		return "dealer_settlement"
	if requested_phase in ["dice_offered", "aiming_throw", "warning"]:
		return requested_phase
	return "betting"


func _last_roll_accounting(last_result: Dictionary) -> Dictionary:
	var returned_stake := 0
	var payout := 0
	for row_value in _dictionary_array(last_result.get("bet_results", [])):
		var row: Dictionary = row_value
		var stake := maxi(0, int(row.get("stake", 0)))
		var profit := int(row.get("profit", 0))
		var outcome := str(row.get("outcome", ""))
		if outcome in ["win", "push", "refund"]:
			returned_stake += stake
		if outcome == "win":
			payout += stake + maxi(0, profit)
		elif outcome in ["push", "refund"]:
			payout += stake
	return {"returned_stake": returned_stake, "payout": payout}


func _energy_tier(table: Dictionary) -> String:
	var rules := _dict(table.get("rules", {}))
	var energy := int(table.get("table_energy", 0))
	var maximum := maxi(1, int(rules.get("table_energy_max", 100)))
	if energy * 4 >= maximum * 3:
		return "hot"
	if energy * 2 >= maximum:
		return "rising"
	return "calm"


func _ritual_actors(table: Dictionary, street: bool, warning: bool = false) -> Array:
	var point := int(table.get("point", 0))
	var last_result := _dict(table.get("last_result", {}))
	var call_state := "idle" if last_result.is_empty() else "seven_out" if str(last_result.get("message", "")).begins_with("Seven out") else "point_on" if point != 0 else "come_out"
	if street:
		return [
			{"id": "caller", "role": "stickperson", "anchor": "circle_north", "behavior": call_state, "pose": "calling", "bounds": Rect2(350, 24, 76, 64), "attention": "dice"},
			{"id": "lookout", "role": "lookout", "anchor": "alley_mouth", "behavior": "warning" if warning else "watching", "pose": "signal" if warning else "lean", "bounds": Rect2(744, 54, 74, 108), "attention": "exit"},
			{"id": "shooter", "role": "player_shooter", "anchor": "circle_south", "behavior": "ready", "pose": "offering", "bounds": Rect2(350, 346, 76, 72), "attention": "dice"},
		]
	return [
		{"id": "stickperson", "role": "stickperson", "anchor": "table_north", "behavior": call_state, "pose": "calling", "bounds": Rect2(300, 18, 72, 64), "attention": "dice"},
		{"id": "base_dealer_left", "role": "base_dealer", "anchor": "table_west", "behavior": "paying" if not last_result.is_empty() else "ready", "pose": "reach", "bounds": Rect2(42, 170, 54, 112), "attention": "layout"},
		{"id": "base_dealer_right", "role": "base_dealer", "anchor": "table_east", "behavior": "collecting" if not last_result.is_empty() else "ready", "pose": "reach", "bounds": Rect2(716, 170, 54, 112), "attention": "layout"},
		{"id": "boxperson", "role": "boxperson", "anchor": "table_northwest", "behavior": "watching", "pose": "seated", "bounds": Rect2(236, 18, 54, 58), "attention": "layout"},
		{"id": "pit_boss", "role": "pit_boss", "anchor": "rail", "behavior": "attentive" if _energy_tier(table) != "calm" else "idle", "pose": "rail" if _energy_tier(table) != "calm" else "floor", "bounds": Rect2(724, 12, 62, 76), "attention": "shooter" if _energy_tier(table) != "calm" else "room"},
	]


func _ritual_scene_objects(table: Dictionary, street: bool, phase: String) -> Array:
	return [
		{"id": "chalk_ring" if street else "point_puck", "state": "dispersed" if street and bool(table.get("street_dispersed", false)) else "on" if int(table.get("point", 0)) != 0 else "off", "bounds": Rect2(170, 42, 436, 336) if street else Rect2(678, 46, 52, 52), "functional_state": "closed" if street and bool(table.get("street_dispersed", false)) else "readable", "z_order": 4},
		{"id": "dice_pair", "state": phase, "bounds": THROW_REGION, "functional_state": "interactive" if phase in ["dice_offered", "aiming_throw"] else "presentation", "z_order": 8},
		{"id": "crowd_rail", "state": _energy_tier(table), "bounds": Rect2(88, 8, 590, 44), "functional_state": "open" if _energy_tier(table) == "calm" else "occupied", "z_order": 2},
	]


func _public_craps_facts(table: Dictionary, settlement: Dictionary, bankroll_delta: int, action_id: String, disperse_reason: String) -> Array:
	var sequence := int(table.get("ritual_sequence", 0))
	var boundary := "craps.roll.%d" % sequence
	var facts: Array = [_craps_fact("roll_resolved", sequence, boundary, {"point_before": int(settlement.get("point_before", 0)), "point_after": int(settlement.get("point_after", 0)), "energy_tier": _energy_tier(table)})]
	if int(settlement.get("point_before", 0)) == 0:
		facts.append(_craps_fact("come_out", sequence, boundary, {"total": int(_dict(table.get("last_roll", {})).get("total", 0)), "point_after": int(settlement.get("point_after", 0))}))
	if int(settlement.get("point_before", 0)) == 0 and int(settlement.get("point_after", 0)) != 0:
		facts.append(_craps_fact("point_set", sequence, boundary, {"point": int(settlement.get("point_after", 0))}))
	if bool(settlement.get("point_made", false)):
		facts.append(_craps_fact("point_made", sequence, boundary, {"streak_tier": int(table.get("hot_shooter_streak", 0)), "energy_tier": _energy_tier(table)}))
	if bool(settlement.get("seven_out", false)):
		facts.append(_craps_fact("seven_out", sequence, boundary, {"energy_tier": _energy_tier(table)}))
		facts.append(_craps_fact("table_cooled", sequence, boundary, {"reason": "seven_out", "energy_tier": _energy_tier(table)}))
	facts.append(_craps_fact("streak_tier", sequence, boundary, {"streak": int(table.get("hot_shooter_streak", 0)), "energy_tier": _energy_tier(table)}))
	if absi(bankroll_delta) >= maxi(1, int(table.get("table_maximum", 1))):
		facts.append(_craps_fact("large_swing", sequence, boundary, {"direction": "win" if bankroll_delta > 0 else "loss", "tier": 1}))
	if action_id != "roll_craps":
		facts.append(_craps_fact("cheat_attempt", sequence, boundary, {"method": action_id}))
		facts.append(_craps_fact("cheat_result", sequence, boundary, {"revealed": true}))
	if not disperse_reason.is_empty():
		facts.append(_craps_fact("street_lookout_warning", sequence, boundary, {"reason": disperse_reason}))
		facts.append(_craps_fact("dispersal", sequence, boundary, {"reason": disperse_reason}))
	return facts


func _craps_fact(local_type: String, sequence: int, boundary: String, payload: Dictionary) -> Dictionary:
	var record := {
		"fact_id": "craps.%s.%d" % [local_type, sequence],
		"fact_type": "craps.%s" % local_type,
		"fact_version": 1,
		"visibility": "public",
		"boundary": boundary,
		"cause": "action_resolution",
		"payload": payload.duplicate(true),
		"receipt_key": "craps.fact.%d.%s" % [sequence, local_type],
	}
	record["content_fingerprint"] = _canonical_json(record).sha256_text()
	return record


func _canonical_json(value: Variant) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		var source := _dict(value)
		var keys := _string_array(source.keys())
		keys.sort()
		var members: Array[String] = []
		for key in keys:
			members.append("%s:%s" % [JSON.stringify(key), _canonical_json(source.get(key))])
		return "{%s}" % ",".join(members)
	if typeof(value) == TYPE_ARRAY:
		var items: Array[String] = []
		for item in value:
			items.append(_canonical_json(item))
		return "[%s]" % ",".join(items)
	return JSON.stringify(value)


func _chip_denominations(table: Dictionary) -> Array:
	var chips := _int_array(table.get("chip_denominations", []))
	return chips if not chips.is_empty() else [1]


func _first_chip(table: Dictionary) -> int:
	return int(_chip_denominations(table)[0])


func _config() -> Dictionary:
	return _dict(definition.get("craps_config", {}))


func _street_config() -> Dictionary:
	return _dict(_dict(_config().get("variants", {})).get("street_craps", {}))


func _street_guidance_seen_flag() -> String:
	return str(_dict(_street_config().get("guidance", {})).get("seen_flag", "street_craps_guidance_seen"))


func _is_street_variant(environment: Dictionary) -> bool:
	var variant := _street_config()
	if variant.is_empty():
		return false
	var modifiers := _dict(environment.get("scenario_game_modifiers", {}))
	var hook_key := str(variant.get("scenario_hook_key", "game_hook"))
	return str(modifiers.get(hook_key, "")) == str(variant.get("scenario_hook_value", "street_craps"))


func _is_street_table(table: Dictionary, environment: Dictionary) -> bool:
	return str(table.get("variant_id", "")) == "street_craps" or _is_street_variant(environment)


func _street_bet_targets(table: Dictionary, rules: Dictionary) -> Array:
	var allowed := _string_array(_street_config().get("allowed_bets", []))
	var targets: Array = []
	for target_value in CrapsSurfaceViewModelScript.bet_targets(table, rules):
		if typeof(target_value) != TYPE_DICTIONARY:
			continue
		var target: Dictionary = (target_value as Dictionary).duplicate(true)
		if not allowed.has(str(target.get("id", ""))):
			continue
		target["rect"] = Rect2(178, 224 if str(target.get("id", "")) == "pass_line" else 292, 420, 52)
		target["payout"] = "Even cash" if str(target.get("id", "")) == "pass_line" else "Even cash · 12 bars"
		targets.append(target)
	return targets


func _street_disperse_reason(run_state: RunState, environment: Dictionary, heat_delta: int) -> String:
	var disperse := _dict(_street_config().get("disperse", {}))
	if bool(disperse.get("sweep_adjacent", false)):
		var modifiers := _dict(environment.get("scenario_game_modifiers", {}))
		if bool(modifiers.get("sweep_adjacent", false)):
			return "sweep_adjacent"
		var node_id := str(environment.get("world_node_id", environment.get("archetype_id", ""))).strip_edges()
		if run_state != null and run_state.town_state != null and run_state.town_state.sweep_is_adjacent(node_id):
			return "sweep_adjacent"
	if heat_delta >= maxi(1, int(disperse.get("heat_spike_delta", 8))):
		return "heat_spike"
	return ""


func _working_wager_total(value: Variant) -> int:
	var working := _dict(value)
	var total := maxi(0, int(working.get("pass_line", 0))) + maxi(0, int(working.get("dont_pass", 0))) + maxi(0, int(working.get("pass_odds", 0)))
	for group_key in ["come", "dont_come", "come_odds", "place"]:
		for stake_value in _dict(working.get(group_key, {})).values():
			total += maxi(0, int(stake_value))
	return total


func _mark_street_dispersed(table: Dictionary, reason: String) -> void:
	table["point"] = 0
	table["working_bets"] = _empty_working_bets()
	table["street_dispersed"] = true
	table["street_disperse_reason"] = reason
	table["hot_shooter_streak"] = 0
	table["table_energy"] = int(_dict(table.get("rules", {})).get("table_energy_min", 0))


func _resolve_street_disperse(run_state: RunState, environment: Dictionary, table: Dictionary, pending: Dictionary, reason: String, rng: RngStream) -> Dictionary:
	var refund := _working_wager_total(table.get("working_bets", {}))
	_mark_street_dispersed(table, reason)
	var message := str(_dict(_street_config().get("disperse", {})).get("message", "The circle breaks and unresolved stakes come back."))
	table["last_result"] = {"message": message, "bankroll_delta": refund, "bet_results": []}
	_update_environment_table(environment, table)
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = refund
	deltas["messages"] = [message]
	deltas["flags_set"] = {_street_guidance_seen_flag(): true}
	deltas["story_log"] = [{
		"type": "game_action",
		"game_id": get_id(),
		"action_id": "street_craps_disperse",
		"action_kind": "environment",
		"stake": CrapsRulesScript.pending_wager_total(pending),
		"bankroll_delta": refund,
		"street_disperse_reason": reason,
		"street_disperse_refund": refund,
		"environment_id": environment.get("id", ""),
		"environment_archetype_id": environment.get("archetype_id", ""),
	}]
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": "street_craps_disperse",
		"action_kind": "environment",
		"stake": CrapsRulesScript.pending_wager_total(pending),
		"bankroll_delta": refund,
		"deltas": deltas,
		"environment_id": environment.get("id", ""),
		"environment_archetype_id": environment.get("archetype_id", ""),
		"message": message,
	})
	result["craps_variant"] = "street_craps"
	result["currency"] = "cash"
	result["street_dispersed"] = true
	result["street_disperse_reason"] = reason
	result["street_disperse_refund"] = refund
	result["street_pending_returned"] = CrapsRulesScript.pending_wager_total(pending)
	GameModule.apply_result(run_state, result, rng)
	return result


func _street_training_delta(run_state: RunState, settlement: Dictionary) -> Dictionary:
	if run_state == null:
		return {}
	var training := _dict(_street_config().get("training", {}))
	var trained_flag := str(training.get("trained_flag", "craps_setting_trained"))
	if bool(run_state.narrative_flags.get(trained_flag, false)):
		return {}
	var grant_outcomes := _string_array(training.get("grant_outcomes", []))
	var completed_line := false
	for result_value in _dictionary_array(settlement.get("bet_results", [])):
		var result: Dictionary = result_value
		if ["Pass Line", "Don't Pass"].has(str(result.get("label", ""))) and grant_outcomes.has(str(result.get("outcome", ""))):
			completed_line = true
			break
	if not completed_line:
		return {}
	var progress_flag := str(training.get("progress_flag", "craps_setting_street_progress"))
	var required := maxi(1, int(training.get("completed_line_resolutions_required", 1)))
	var grant := run_state.grant_shared_training_progress(progress_flag, trained_flag, required, 1, false)
	var progress := int(grant.get("progress", 0))
	var flags: Dictionary = grant.get("flags_set", {}) if typeof(grant.get("flags_set", {})) == TYPE_DICTIONARY else {}
	var message := ""
	if progress >= required:
		message = str(training.get("completion_line", ""))
	return {"flags_set": flags, "message": message}


func _item_effect_total(key: String, run_state: RunState) -> int:
	return run_state.item_effect_total(key, get_family(), "cheat") if run_state != null and run_state.has_method("item_effect_total") else 0


func _message_command(ui_state: Dictionary, message: String) -> Dictionary:
	var state := ui_state.duplicate(true)
	state["surface_message"] = message
	return GameModule.surface_command({"ui_state": state, "message": message})


func _surface_action_blocks() -> Array:
	return [{
		"actions": ["craps_bet", "craps_chip", "craps_clear", "craps_remove", "craps_undo", "craps_repeat", "craps_rebet", "craps_roll", "craps_throw", "craps_setting", "craps_switch"],
		"while_animation": ROLL_CHANNEL,
		"reason": "The dice are in motion; no more bets, please.",
	}]


func _selected_surface_actions(setting: Dictionary, switching: Dictionary) -> Array:
	var result: Array = []
	if not setting.is_empty() and str(setting.get("skill_grade", "")).is_empty():
		result.append("craps_setting")
	if not switching.is_empty() and str(switching.get("skill_grade", "")).is_empty():
		result.append("craps_switch")
	return result


func _draw_street_surface(surface, state: Dictionary) -> bool:
	var board := Vector2(900, 474)
	surface.surface_begin_design_space(board)
	surface.draw_rect(Rect2(Vector2.ZERO, board), Color("#121416"))
	for y in range(42, 432, 42):
		surface.draw_line(Vector2(24, y), Vector2(876, y), Color(0.24, 0.20, 0.19, 0.44), 2.0)
		var offset := 22.0 if int(y / 42) % 2 == 0 else 62.0
		for x in range(int(offset), 880, 84):
			surface.draw_line(Vector2(x, y - 40), Vector2(x, y), Color(0.24, 0.20, 0.19, 0.34), 1.0)
	surface.surface_title(str(state.get("table_name", "THE CHALK RING")).to_upper(), Vector2(58, 38), Color("#f0d3a1"))
	var circle_center := Vector2(388, 210)
	surface.draw_circle(circle_center, 168.0, Color(0.09, 0.10, 0.10, 0.72))
	surface.draw_arc(circle_center, 168.0, 0.0, TAU, 72, Color("#d9c5a4"), 3.0)
	surface.draw_arc(circle_center, 154.0, 0.0, TAU, 72, Color(0.76, 0.70, 0.60, 0.30), 1.0)
	for angle_index in range(7):
		var angle := -2.75 + float(angle_index) * 0.68
		var person := circle_center + Vector2(cos(angle), sin(angle)) * 188.0
		surface.draw_circle(person, 15.0, Color("#2a2524"))
		surface.draw_circle(person + Vector2(0, 24), 21.0, Color("#201d1d"))
	if bool(state.get("street_dispersed", false)):
		surface.surface_label_centered("THE CIRCLE SCATTERED", Rect2(170, 176, 436, 34), 18, Color("#e5b07b"))
		surface.surface_label_centered("UNRESOLVED CASH RETURNED", Rect2(170, 214, 436, 24), 11, Color("#c5b8a5"))
	else:
		_draw_targets(surface, state)
		_draw_street_point(surface, state)
		_draw_street_dice(surface, state)
	_draw_street_side_panel(surface, state)
	_draw_street_controls(surface, state)
	surface.surface_end_design_space()
	return true


func _draw_street_point(surface, state: Dictionary) -> void:
	var point := int(state.get("point", 0))
	var center := Vector2(388, 180)
	surface.draw_circle(center, 28.0, Color("#d8c8a9") if point != 0 else Color("#262626"))
	surface.draw_circle(center, 28.0, Color("#efe1c4"), false, 2.0)
	surface.surface_label_centered("OPEN" if point == 0 else "POINT %d" % point, Rect2(center - Vector2(42, 9), Vector2(84, 18)), 11, Color("#171717") if point != 0 else Color("#efe1c4"))


func _draw_street_dice(surface, state: Dictionary) -> void:
	if bool(state.get("can_roll", false)):
		surface.draw_rect(THROW_REGION, Color(0.85, 0.77, 0.62, 0.08))
		surface.draw_rect(THROW_REGION, Color("#b59b72"), false, 1.0)
		surface.surface_add_exact_hit(THROW_REGION, THROW_ACTION)
	var dice := _int_array(_dict(state.get("last_roll", {})).get("dice", []))
	if dice.size() != 2:
		return
	var progress: float = float(surface.surface_animation_progress(ROLL_CHANNEL)) if surface.surface_animation_active(ROLL_CHANNEL) else 1.0
	var wobble := sin(progress * TAU * 3.0) * (1.0 - progress) * 10.0
	for index in range(2):
		var rect := Rect2(350 + index * 56 + wobble * (1.0 if index == 0 else -1.0), 124 + absf(wobble) * 0.5, 44, 44)
		surface.draw_rect(rect, Color("#d7c9ad"))
		surface.draw_rect(rect, Color("#4a4034"), false, 2.0)
		surface.surface_label_centered(str(dice[index]), rect, 20, Color("#171717"))


func _draw_street_side_panel(surface, state: Dictionary) -> void:
	var rect := Rect2(650, 64, 220, 278)
	surface.draw_rect(rect, Color(0.05, 0.06, 0.06, 0.90))
	surface.draw_rect(rect, Color("#8f775b"), false, 1.0)
	surface.surface_label_centered("CASH IN HAND", Rect2(658, 76, 204, 20), 12, Color("#f0d3a1"))
	var working_rows := _dictionary_array(state.get("working_bet_rows", []))
	var working_text := "No line working"
	if not working_rows.is_empty():
		var row: Dictionary = working_rows[0]
		working_text = "%s  $%d" % [str(row.get("label", "LINE")).to_upper(), int(row.get("stake", 0))]
	surface.surface_label_centered(working_text, Rect2(658, 106, 204, 20), 10, Color("#d8c8a9"))
	surface.surface_label_centered(str(state.get("table_notice", "")), Rect2(666, 140, 188, 64), 9, Color("#bcb3a5"))
	surface.surface_label_centered("LAST THROWS", Rect2(658, 214, 204, 18), 10, Color("#f0d3a1"))
	var rows := _dictionary_array(state.get("roll_history", []))
	for index in range(mini(rows.size(), 4)):
		var row: Dictionary = rows[index]
		var dice := _int_array(row.get("dice", []))
		if dice.size() == 2:
			surface.surface_label_centered("%d   %d + %d" % [int(row.get("total", 0)), int(dice[0]), int(dice[1])], Rect2(670, 238 + index * 22, 180, 18), 9, Color("#c5b8a5"))


func _draw_street_controls(surface, state: Dictionary) -> void:
	_draw_denomination_controls(surface, state, 42.0, 386.0, true)
	var actions := [
		{"id": "craps_remove", "label": "REMOVE", "rect": Rect2(42, 428, 82, 32), "enabled": bool(state.get("can_remove", false))},
		{"id": "craps_undo", "label": "UNDO", "rect": Rect2(130, 428, 72, 32), "enabled": bool(state.get("can_undo", false))},
		{"id": "craps_clear", "label": "CLEAR", "rect": Rect2(208, 428, 72, 32), "enabled": bool(state.get("can_clear", false))},
		{"id": "craps_repeat", "label": "REPEAT", "rect": Rect2(286, 428, 82, 32), "enabled": bool(state.get("can_repeat", false))},
		{"id": "craps_rebet", "label": "RE-BET", "rect": Rect2(374, 428, 82, 32), "enabled": bool(state.get("can_rebet", false))},
		{"id": "craps_roll", "label": "WARNING" if bool(state.get("street_warning", false)) else "OFFER", "rect": Rect2(462, 424, 94, 38), "enabled": bool(state.get("can_roll", false))},
		{"id": "craps_throw", "label": "BREAK UP" if bool(state.get("street_warning", false)) else "THROW", "rect": Rect2(562, 424, 104, 38), "enabled": bool(state.get("can_roll", false))},
	]
	for action_value in actions:
		var action: Dictionary = action_value
		var rect: Rect2 = action.get("rect", Rect2())
		var enabled := bool(action.get("enabled", false))
		surface.draw_rect(rect, Color("#855f31") if enabled else Color("#303130"))
		surface.draw_rect(rect, Color("#f0d3a1") if enabled else Color("#67645f"), false, 1.0)
		surface.surface_label_centered(str(action.get("label", "")), rect, 10, Color("#fff0d0") if enabled else Color("#88847d"))
		if enabled:
			surface.surface_add_exact_hit(rect, str(action.get("id", "")))


func _draw_targets(surface, state: Dictionary) -> void:
	var targets := _dictionary_array(state.get("bet_targets", []))
	var pending := _pending_bets(state.get("craps_pending_bets", {}))
	for index in range(targets.size()):
		var target: Dictionary = targets[index]
		var rect: Rect2 = target.get("rect", Rect2())
		var enabled := bool(target.get("enabled", false))
		var active := int(pending.get(str(target.get("id", "")), 0)) > 0
		var accent := Color("#f5e6a8") if enabled else Color("#53736a")
		surface.draw_rect(rect, Color(0.09, 0.32, 0.25, 0.88) if active else Color(0.02, 0.14, 0.11, 0.52))
		surface.draw_rect(rect, accent, false, 2 if active else 1)
		surface.surface_label_centered(str(target.get("label", "BET")), Rect2(rect.position + Vector2(2, 3), Vector2(rect.size.x - 4, rect.size.y - 16)), 10, accent)
		surface.surface_label_centered(str(target.get("payout", "")), Rect2(rect.position + Vector2(2, rect.size.y - 15), Vector2(rect.size.x - 4, 11)), 7, Color("#d1dfd7"))
		if enabled:
			surface.surface_add_exact_hit(rect, "craps_bet", index)


func _idle_rail_motion(surface) -> Dictionary:
	var clock := float(surface.surface_flicker()) if surface != null and surface.has_method("surface_flicker") else 0.0
	var sweep := (sin(clock * 1.35) + 1.0) * 0.5
	return {
		"marker_x": 92.0 + sweep * 492.0,
		"glow": 0.34 + 0.16 * sin(clock * 2.1),
	}


func _draw_idle_rail_motion(surface) -> void:
	var motion := _idle_rail_motion(surface)
	var marker := Vector2(float(motion.get("marker_x", 338.0)), 65.0)
	var glow := clampf(float(motion.get("glow", 0.34)), 0.18, 0.55)
	# One moving brass rail marker is enough to keep the table alive without
	# allocating snapshots or maintaining another runtime animation channel.
	surface.draw_circle(marker, 6.0, Color(0.94, 0.77, 0.35, glow * 0.45))
	surface.draw_circle(marker, 3.0, Color(0.98, 0.89, 0.58, glow))


func _draw_casino_ritual_cast(surface, state: Dictionary) -> void:
	var tier := str(state.get("ritual_energy_tier", "calm"))
	var crowd_count := 3 if tier == "calm" else 5 if tier == "rising" else 7
	for index in range(crowd_count):
		var x := 106.0 + float(index) * 82.0
		var attention_y := 22.0 if tier == "hot" else 26.0
		surface.draw_circle(Vector2(x, attention_y), 7.0, Color("#b79a72"))
		surface.draw_line(Vector2(x, attention_y + 7.0), Vector2(x, 46.0), Color("#554638"), 5.0)
	# Staff positions are deliberately stable semantic anchors; energy changes
	# crowd occupation and pit attention, while outcomes remain rules-owned.
	surface.draw_circle(Vector2(336, 54), 8.0, Color("#e0c49a"))
	surface.draw_line(Vector2(336, 62), Vector2(336, 80), Color("#4b2330"), 6.0)
	surface.draw_circle(Vector2(68, 226), 8.0, Color("#d5b98f"))
	surface.draw_circle(Vector2(744, 226), 8.0, Color("#d5b98f"))
	if tier != "calm":
		surface.draw_circle(Vector2(752, 48), 9.0, Color("#31253b"))
		surface.draw_line(Vector2(752, 57), Vector2(726, 78), Color("#8a6da0"), 2.0)


func _draw_point_puck(surface, state: Dictionary) -> void:
	var point := int(state.get("point", 0))
	var center := Vector2(704, 72)
	surface.draw_circle(center, 24.0, Color("#f3eee0") if point != 0 else Color("#222a28"))
	surface.draw_circle(center, 24.0, Color("#d6af4b"), false, 2)
	surface.surface_label_centered("OFF" if point == 0 else str(point), Rect2(center - Vector2(22, 8), Vector2(44, 16)), 12, Color("#071713") if point != 0 else Color("#f3eee0"))


func _draw_dice(surface, state: Dictionary) -> void:
	if bool(state.get("can_roll", false)):
		surface.draw_rect(THROW_REGION, Color(0.96, 0.90, 0.69, 0.06))
		surface.draw_rect(THROW_REGION, Color("#d6af4b"), false, 1.0)
		surface.surface_add_exact_hit(THROW_REGION, THROW_ACTION)
	var roll := _dict(state.get("last_roll", {}))
	var dice := _int_array(roll.get("dice", []))
	if dice.size() != 2:
		return
	var progress: float = float(surface.surface_animation_progress(ROLL_CHANNEL)) if surface.surface_animation_active(ROLL_CHANNEL) else 1.0
	var wobble: float = sin(progress * TAU * 3.0) * (1.0 - progress) * 12.0
	for index in range(2):
		var rect := Rect2(638 + index * 54 + wobble * (1.0 if index == 0 else -1.0), 140 + absf(wobble) * 0.5, 42, 42)
		surface.draw_rect(rect, Color("#eee7d2"))
		surface.draw_rect(rect, Color("#9a7735"), false, 2)
		surface.surface_label_centered(str(dice[index]), rect, 20, Color("#171b19"))


func _draw_history(surface, state: Dictionary) -> void:
	var rect := Rect2(774, 52, 112, 210)
	surface.draw_rect(rect, Color("#101c1a"))
	surface.draw_rect(rect, Color("#6d978a"), false, 1)
	surface.surface_label_centered("ROLLS", Rect2(778, 58, 104, 18), 11, Color("#f5e6a8"))
	var rows := _dictionary_array(state.get("roll_history", []))
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var dice := _int_array(row.get("dice", []))
		if dice.size() == 2:
			surface.surface_label_centered("%d  ·  %d + %d" % [int(row.get("total", 0)), int(dice[0]), int(dice[1])], Rect2(780, 82 + index * 22, 100, 18), 9, Color("#d1dfd7"))


func _draw_working_bets(surface, state: Dictionary) -> void:
	var rect := Rect2(774, 272, 112, 112)
	surface.draw_rect(rect, Color("#101c1a"))
	surface.draw_rect(rect, Color("#6d978a"), false, 1)
	surface.surface_label_centered("WORKING", Rect2(778, 276, 104, 16), 10, Color("#f5e6a8"))
	var rows := _dictionary_array(state.get("working_bet_rows", []))
	for index in range(mini(rows.size(), 5)):
		var row: Dictionary = rows[index]
		surface.surface_label_centered("%s  %d" % [str(row.get("label", "")).left(12), int(row.get("stake", 0))], Rect2(778, 296 + index * 16, 104, 14), 7, Color("#d1dfd7"))


func _draw_controls(surface, state: Dictionary) -> void:
	_draw_denomination_controls(surface, state, 64.0, 392.0, false)
	var actions := [
		{"id": "craps_clear", "label": "CLEAR", "rect": Rect2(300, 392, 68, 28), "enabled": bool(state.get("can_clear", false))},
		{"id": "craps_remove", "label": "REMOVE", "rect": Rect2(374, 392, 76, 28), "enabled": bool(state.get("can_remove", false))},
		{"id": "craps_undo", "label": "UNDO", "rect": Rect2(456, 392, 64, 28), "enabled": bool(state.get("can_undo", false))},
		{"id": "craps_repeat", "label": "REPEAT", "rect": Rect2(526, 392, 72, 28), "enabled": bool(state.get("can_repeat", false))},
		{"id": "craps_rebet", "label": "RE-BET", "rect": Rect2(604, 392, 72, 28), "enabled": bool(state.get("can_rebet", false))},
		{"id": "craps_setting", "label": "SET DICE", "rect": Rect2(300, 430, 110, 30), "enabled": bool(state.get("craps_setting_available", false))},
		{"id": "craps_switch", "label": "SWITCH", "rect": Rect2(416, 430, 100, 30), "enabled": bool(state.get("craps_switching_available", false))},
		{"id": "craps_roll", "label": "OFFER", "rect": Rect2(522, 428, 82, 34), "enabled": bool(state.get("can_roll", false))},
		{"id": "craps_throw", "label": "THROW", "rect": Rect2(610, 428, 92, 34), "enabled": bool(state.get("can_roll", false))},
	]
	for action_value in actions:
		var action: Dictionary = action_value
		var rect: Rect2 = action.get("rect", Rect2())
		var enabled := bool(action.get("enabled", false))
		surface.draw_rect(rect, Color("#a4762b") if enabled else Color("#293c37"))
		surface.draw_rect(rect, Color("#f5e6a8") if enabled else Color("#587269"), false, 1)
		surface.surface_label_centered(str(action.get("label", "")), rect, 10, Color("#fff5d2") if enabled else Color("#80978f"))
		if enabled:
			surface.surface_add_exact_hit(rect, str(action.get("id", "")))


func _draw_denomination_controls(surface, state: Dictionary, start_x: float, y: float, street: bool) -> void:
	var denominations := _int_array(state.get("chip_denominations", []))
	var selected := int(state.get("selected_chip", 0))
	for index in range(mini(denominations.size(), 4)):
		var amount := int(denominations[index])
		var rect := Rect2(start_x + float(index) * 58.0, y, 52, 28)
		var active := amount == selected
		surface.draw_rect(rect, Color("#9c7138") if active else Color("#3b493f"))
		surface.draw_rect(rect, Color("#fff0d0") if active else Color("#7c9388"), false, 1.0)
		surface.surface_label_centered(("$" if street else "") + str(amount), rect, 10, Color("#fff5d2"))
		surface.surface_add_exact_hit(rect, "craps_chip", index)


func _empty_result(action_id: String, stake: int, environment: Dictionary, text: String) -> Dictionary:
	return GameModule.build_action_result({
		"ok": false,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": "unknown",
		"stake": stake,
		"environment_id": environment.get("id", ""),
		"environment_archetype_id": environment.get("archetype_id", ""),
		"message": text,
	})


func _fallback_rng(environment: Dictionary) -> RngStream:
	var rng := RngStream.new()
	rng.configure(_stable_hash("%s:%s" % [get_id(), str(environment.get("id", "craps"))]))
	return rng


func _stable_hash(text: String) -> int:
	var value := 216613626
	for index in range(text.length()):
		value = value ^ text.unicode_at(index)
		value = int((value * 16777619) & 0x7fffffff)
	return maxi(1, value)


func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []


func _int_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value:
			result.append(int(entry))
	return result


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value:
			result.append(str(entry))
	return result


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value:
			if typeof(entry) == TYPE_DICTIONARY:
				result.append((entry as Dictionary).duplicate(true))
	return result
