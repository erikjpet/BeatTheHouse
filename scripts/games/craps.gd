class_name CrapsGame
extends GameModule

const CrapsRulesScript := preload("res://scripts/games/craps/craps_rules.gd")
const CrapsSurfaceViewModelScript := preload("res://scripts/games/craps/craps_surface_view_model.gd")

const ROLL_CHANNEL := "craps_roll"
const DICE_CALIPERS_ITEM_ID := "dice_calipers"
const FALSE_BOTTOM_CUP_ITEM_ID := "false_bottom_cup"


func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
	var result := super.enter(run_state, environment)
	var table := _table_state_preview(run_state, environment)
	result["message"] = "%s sets the dice at %s. The minimum is %d chips." % [
		str(table.get("dealer_name", "The stickperson")),
		str(table.get("table_name", "the craps table")),
		int(table.get("table_minimum", 0)),
	]
	return result


func generate_environment_state(_run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var config := _config()
	var rules := _dict(config.get("rules", {})).duplicate(true)
	var economic: Dictionary = environment.get("economic_profile", {}) if typeof(environment.get("economic_profile", {})) == TYPE_DICTIONARY else {}
	var table_minimum := maxi(int(config.get("minimum_stake", 1)), GameModule.stake_floor_for_game(environment, get_id(), int(config.get("minimum_stake", 1))))
	var table_maximum := maxi(table_minimum, GameModule.stake_ceiling_for_game(environment, get_id(), int(config.get("maximum_stake", table_minimum))))
	return {
		"schema": "craps_table_state",
		"version": int(config.get("state_version", 1)),
		"table_name": str(rng.pick(_array(config.get("table_names", [])), "Marble Dice")),
		"dealer_name": str(rng.pick(_array(config.get("dealer_names", [])), "The stickperson")),
		"table_minimum": maxi(table_minimum, int(economic.get("stake_floor", table_minimum))),
		"table_maximum": maxi(table_maximum, int(economic.get("stake_ceiling", table_maximum))),
		"chip_denominations": _int_array(config.get("chip_denominations", [])),
		"rules": rules,
		"point": 0,
		"working_bets": _empty_working_bets(),
		"roll_count": 0,
		"roll_history": [],
		"last_roll": {},
		"last_result": {},
		"hot_shooter_streak": 0,
		"table_energy": int(rules.get("table_energy_min", 0)),
		"normalized_version": int(config.get("state_version", 1)),
	}


func surface_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var table := _table_state_preview(run_state, environment)
	var rules := _dict(table.get("rules", {}))
	var pending := _pending_bets(ui_state.get("craps_pending_bets", {}))
	var selected_chip := int(ui_state.get("selected_chip", _first_chip(table)))
	var targets := CrapsSurfaceViewModelScript.bet_targets(table, rules)
	var total_wager := CrapsRulesScript.pending_wager_total(pending)
	var last_roll := _dict(table.get("last_roll", {}))
	var roll_started := int(last_roll.get("resolved_at_msec", 0))
	var duration := int(_config().get("roll_animation_duration_msec", 0))
	var now_msec := int(ui_state.get("surface_time_msec", Time.get_ticks_msec()))
	var roll_active := roll_started > 0 and now_msec >= roll_started and now_msec < roll_started + duration
	var setting_challenge := _dict(ui_state.get("craps_setting_challenge", {}))
	var switching_challenge := _dict(ui_state.get("craps_switching_challenge", {}))
	var setting_active := not setting_challenge.is_empty() and str(setting_challenge.get("skill_grade", "")).is_empty()
	var switching_active := not switching_challenge.is_empty() and str(switching_challenge.get("skill_grade", "")).is_empty()
	return GameModule.surface_spec({
		"surface_renderer": "craps",
		"surface_life": "immersive_table",
		"surface_cast": "dealer_table",
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
			{"metadata": {"dice": _int_array(last_roll.get("dice", []))}}
		)],
		"surface_action_blocks": _surface_action_blocks(),
		"surface_action_bindings": {
			"legal": {"action": "craps_roll", "index": 0},
			"cheat": {"action": "craps_setting", "index": 0},
		},
		"native_selected_surface_actions": _selected_surface_actions(setting_challenge, switching_challenge),
		"surface_state_labels": [
			{"label": "Point", "value": "OFF" if int(table.get("point", 0)) == 0 else str(table.get("point", 0))},
			{"label": "New wagers", "value": "%d chips" % total_wager},
			{"label": "Energy", "value": str(table.get("table_energy", 0))},
		],
		"phase": "rolling" if roll_active else "betting",
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
		"table_minimum": int(table.get("table_minimum", 0)),
		"table_maximum": int(table.get("table_maximum", 0)),
		"can_roll": _can_roll(table, pending) and not roll_active,
		"can_clear": not pending.is_empty() and not roll_active,
		"last_roll": last_roll.duplicate(true),
		"last_result": _dict(table.get("last_result", {})).duplicate(true),
		"roll_history": CrapsSurfaceViewModelScript.roll_history_rows(table.get("roll_history", []), int(_config().get("visible_history_limit", 0))),
		"hot_shooter_streak": int(table.get("hot_shooter_streak", 0)),
		"table_energy": int(table.get("table_energy", 0)),
		"craps_setting_available": _setting_available(run_state),
		"craps_switching_available": _switching_available(run_state),
		"craps_setting_challenge": setting_challenge.duplicate(true),
		"craps_switching_challenge": switching_challenge.duplicate(true),
		"craps_setting_item_modifiers": skill_item_modifier_badges(run_state, _string_array(_dict(_config().get("setting", {})).get("item_effect_keys", []))),
		"craps_switching_item_modifiers": skill_item_modifier_badges(run_state, _string_array(_dict(_config().get("switching", {})).get("item_effect_keys", []))),
		"result_message": str(_dict(table.get("last_result", {})).get("message", "")),
		"table_notice": _table_notice(table, pending),
	})


func draw_surface(surface, state: Dictionary, _render_context: Dictionary = {}) -> bool:
	var board := Vector2(900, 430)
	surface.surface_begin_design_space(board)
	surface.draw_rect(Rect2(Vector2.ZERO, board), Color("#071713"))
	surface.draw_rect(Rect2(54, 52, 704, 332), Color("#0b513c"))
	surface.draw_rect(Rect2(54, 52, 704, 332), Color("#e3c675"), false, 2)
	surface.surface_title(str(state.get("table_name", "CRAPS")).to_upper(), Vector2(68, 38), Color("#f5e6a8"))
	_draw_targets(surface, state)
	_draw_point_puck(surface, state)
	_draw_dice(surface, state)
	_draw_history(surface, state)
	_draw_working_bets(surface, state)
	_draw_controls(surface, state)
	surface.surface_end_design_space()
	return true


func surface_action_command(surface_action: String, index: int, _confirm_requested: bool, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var table := _table_state_preview(run_state, environment)
	var session := ui_state.duplicate(true)
	var pending := _pending_bets(session.get("craps_pending_bets", {}))
	match surface_action:
		"craps_bet":
			var targets := CrapsSurfaceViewModelScript.bet_targets(table, _dict(table.get("rules", {})))
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
			pending[bet_id] = int(pending.get(bet_id, 0)) + chip
			session["craps_pending_bets"] = pending
			return GameModule.surface_command({"ui_state": session, "surface_audio_cue": "blackjack_chip"})
		"craps_chip":
			var chips := _chip_denominations(table)
			if chips.is_empty():
				return _message_command(session, "No chip rack is posted.")
			var current := int(session.get("selected_chip", chips[0]))
			var chip_index := chips.find(current)
			session["selected_chip"] = int(chips[(chip_index + 1) % chips.size()])
			return GameModule.surface_command({"ui_state": session, "set_stake": int(session["selected_chip"]), "surface_audio_cue": "blackjack_chip"})
		"craps_clear":
			session["craps_pending_bets"] = {}
			return GameModule.surface_command({"ui_state": session, "surface_audio_cue": "roulette_chip_sweep"})
		"craps_roll":
			if not _can_roll(table, pending):
				return _message_command(session, "Place a wager before the dice are offered.")
			return GameModule.surface_command({"ui_state": session, "action_id": "roll_craps", "action_kind": "legal", "resolve": true, "set_stake": CrapsRulesScript.pending_wager_total(pending)})
		"craps_setting":
			return _timing_command("setting", session, run_state, table)
		"craps_switch":
			return _timing_command("switching", session, run_state, table)
	return {"handled": false}


func wager_cost_for_context(_action_id: String, stake: int, _run_state: RunState, _environment: Dictionary, ui_state: Dictionary = {}) -> int:
	var pending_total := CrapsRulesScript.pending_wager_total(ui_state.get("craps_pending_bets", {}))
	return pending_total if pending_total > 0 else maxi(0, stake)


func resolve(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return resolve_with_context(action_id, stake, run_state, environment, rng, {})


func resolve_with_context(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary = {}) -> Dictionary:
	if not ["roll_craps", "dice_setting", "dice_switching"].has(action_id):
		return _empty_result(action_id, stake, environment, "The stickperson does not recognize that call.")
	var table := _table_state(run_state, environment)
	var pending := _pending_bets(ui_state.get("craps_pending_bets", {}))
	if pending.is_empty() and stake > 0:
		pending["pass_line" if int(table.get("point", 0)) == 0 else "come"] = stake
	var pending_validation := _validate_pending_bets(table, pending)
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
	var roll := CrapsRulesScript.roll_dice(rng, int(cheat.get("bias_permille", 0)))
	var settlement := CrapsRulesScript.settle_roll(table, pending, roll, _dict(table.get("rules", {})))
	var room_energy := _project_table_energy(environment, table)
	var settlement_delta := int(settlement.get("bankroll_delta", 0))
	var luck_payout_bonus := 0
	if settlement_delta > 0 and run_state != null:
		luck_payout_bonus = run_state.luck_payout_bonus(maxi(1, total_wager), true) + _item_effect_total("win_bonus", run_state)
	var bankroll_delta := settlement_delta + luck_payout_bonus + int(cheat.get("bankroll_delta", 0))
	var suspicion_delta := int(cheat.get("suspicion_delta", 0))
	var now_msec := GameModule.deterministic_time_msec(run_state, ui_state)
	var dice := _int_array(roll.get("dice", []))
	var message := _roll_message(roll, settlement, bankroll_delta, table)
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
	return {
		"status_label": "POINT %d" % int(table.get("point", 0)) if int(table.get("point", 0)) != 0 else "COME-OUT",
		"status_detail": "Table energy %d" % int(table.get("table_energy", 0)),
		"active": true,
	}


func _cheat_context(action_id: String, ui_state: Dictionary, run_state: RunState, environment: Dictionary, table: Dictionary) -> Dictionary:
	if action_id == "roll_craps":
		return {"ok": true}
	if action_id == "dice_setting" and not _setting_available(run_state):
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


func _timing_command(kind: String, session: Dictionary, run_state: RunState, table: Dictionary) -> Dictionary:
	if kind == "setting" and not _setting_available(run_state):
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


func _setting_available(run_state: RunState) -> bool:
	if run_state == null:
		return false
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


func _validate_pending_bets(table: Dictionary, pending: Dictionary) -> Dictionary:
	var staged := {}
	var ordered_ids := ["pass_line", "dont_pass", "come", "dont_come", "field", "place_4", "place_5", "place_6", "place_8", "place_9", "place_10", "pass_odds", "come_odds_4", "come_odds_5", "come_odds_6", "come_odds_8", "come_odds_9", "come_odds_10"]
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


func _table_notice(table: Dictionary, pending: Dictionary) -> String:
	var point := int(table.get("point", 0))
	if CrapsRulesScript.pending_wager_total(pending) > 0:
		return "%d chips ready. The dice move only on your call." % CrapsRulesScript.pending_wager_total(pending)
	if point == 0:
		return "The puck is OFF. Pass and Don't Pass are open."
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
	return "%s Net %s%d chips." % [prefix, "+" if bankroll_delta >= 0 else "", bankroll_delta]


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
	table["rules"] = _dict(table.get("rules", _dict(_config().get("rules", {})))).duplicate(true)
	table["chip_denominations"] = _int_array(table.get("chip_denominations", _config().get("chip_denominations", [])))
	table["table_minimum"] = maxi(1, int(table.get("table_minimum", GameModule.stake_floor_for_game(environment, get_id(), 1))))
	table["table_maximum"] = maxi(int(table.get("table_minimum", 1)), int(table.get("table_maximum", GameModule.stake_ceiling_for_game(environment, get_id(), 1))))
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


func _chip_denominations(table: Dictionary) -> Array:
	var chips := _int_array(table.get("chip_denominations", []))
	return chips if not chips.is_empty() else [1]


func _first_chip(table: Dictionary) -> int:
	return int(_chip_denominations(table)[0])


func _config() -> Dictionary:
	return _dict(definition.get("craps_config", {}))


func _item_effect_total(key: String, run_state: RunState) -> int:
	return run_state.item_effect_total(key, get_family(), "cheat") if run_state != null and run_state.has_method("item_effect_total") else 0


func _message_command(ui_state: Dictionary, message: String) -> Dictionary:
	var state := ui_state.duplicate(true)
	state["surface_message"] = message
	return GameModule.surface_command({"ui_state": state, "message": message})


func _surface_action_blocks() -> Array:
	return [{
		"actions": ["craps_bet", "craps_chip", "craps_clear", "craps_roll", "craps_setting", "craps_switch"],
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


func _draw_point_puck(surface, state: Dictionary) -> void:
	var point := int(state.get("point", 0))
	var center := Vector2(704, 72)
	surface.draw_circle(center, 24.0, Color("#f3eee0") if point != 0 else Color("#222a28"))
	surface.draw_circle(center, 24.0, Color("#d6af4b"), false, 2)
	surface.surface_label_centered("OFF" if point == 0 else str(point), Rect2(center - Vector2(22, 8), Vector2(44, 16)), 12, Color("#071713") if point != 0 else Color("#f3eee0"))


func _draw_dice(surface, state: Dictionary) -> void:
	var roll := _dict(state.get("last_roll", {}))
	var dice := _int_array(roll.get("dice", []))
	if dice.size() != 2:
		return
	var progress := surface.surface_animation_progress(ROLL_CHANNEL) if surface.surface_animation_active(ROLL_CHANNEL) else 1.0
	var wobble := sin(progress * TAU * 3.0) * (1.0 - progress) * 12.0
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
	var actions := [
		{"id": "craps_chip", "label": "CHIP %d" % int(state.get("selected_chip", 0)), "rect": Rect2(64, 392, 112, 28), "enabled": true},
		{"id": "craps_clear", "label": "CLEAR", "rect": Rect2(184, 392, 94, 28), "enabled": bool(state.get("can_clear", false))},
		{"id": "craps_setting", "label": "SET DICE", "rect": Rect2(286, 392, 110, 28), "enabled": bool(state.get("craps_setting_available", false))},
		{"id": "craps_switch", "label": "SWITCH", "rect": Rect2(404, 392, 100, 28), "enabled": bool(state.get("craps_switching_available", false))},
		{"id": "craps_roll", "label": "ROLL", "rect": Rect2(620, 388, 138, 34), "enabled": bool(state.get("can_roll", false))},
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
