class_name CoinPusherGame
extends GameModule

const STATE_SCHEMA := "coin_pusher_pile"
const DROP_ACTION := "drop_quarter"
const NUDGE_ACTION := "nudge_machine"
const COLD_QUARTERS_ITEM_ID := "cold_quarters"
const SHIM_ITEM_ID := "coin_return_shim"
const RUMOR_CLASS := "pusher_pile"
const SURFACE_SIZE := Vector2(900, 430)
const C_BG := Color("#070b14")
const C_CASE := Color("#182338")
const C_GLASS := Color("#113148")
const C_COIN := Color("#f6cb56")
const C_HANG := Color("#ff6b5f")
const C_TEAL := Color("#58e1d4")
const C_TEXT := Color("#e9f4ff")


func gameplay_model() -> String:
	return GameModule.GAMEPLAY_MODEL_FULL_SIMULATION


func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
	# Surface entry is presentation-only. Machine normalization, rumor updates,
	# and staff-watch consequences belong to generation/action boundaries.
	var machine := _read_machine_state(run_state, environment)
	var result := super.enter(run_state, environment)
	if bool(machine.get("locked_down", false)):
		result["message"] = "Red lights. This cabinet is done for tonight. The rest of the room is still yours."
	elif bool(machine.get("staff_watch_memory", false)):
		result["message"] = "Quarter Falls is live again. Staff remember your hands and keep one eye here."
	else:
		result["message"] = "Quarter Falls shoves two shelves under a pile that remembers every coin."
	return result


func actions(run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine := _read_machine_state(run_state, environment)
	var capacity := run_state.wager_capacity_for_game(get_id(), environment) if run_state != null else 0
	return {
		"ok": true,
		"type": "game_actions",
		"game_id": get_id(),
		"legal_actions": [] if bool(machine.get("locked_down", false)) else legal_actions(run_state, environment),
		"cheat_actions": [] if bool(machine.get("locked_down", false)) else cheat_actions(run_state, environment),
		"stake_floor": _drop_cost(),
		"stake_ceiling": maxi(_drop_cost(), capacity),
		"base_stake_ceiling": maxi(_drop_cost(), capacity),
		"economy_state": run_state.economy() if run_state != null else {},
		"economy_pressure_applied": false,
	}


func wager_cost_for_context(action_id: String, _stake: int, _run_state: RunState, _environment: Dictionary, _ui_state: Dictionary = {}) -> int:
	return _drop_cost() if action_id == DROP_ACTION else 0


func generate_environment_state(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var machine := _generate_machine_state(run_state, environment, rng)
	_initialize_owned_shim(run_state, machine)
	return machine


func environment_state_generated(run_state: RunState, environment: Dictionary, generated_state: Dictionary) -> void:
	_register_pile_rumor(run_state, environment, generated_state)


func environment_object_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine := _read_machine_state(run_state, environment)
	return {
		"coin_pusher_locked": bool(machine.get("locked_down", false)),
		"staff_watch": bool(machine.get("staff_watch_memory", false)),
		"status_line": "Attendant keeps eyes on this cabinet." if bool(machine.get("staff_watch_memory", false)) else "Two shelves shove under a live pile.",
	}


func surface_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var machine := _read_machine_state(run_state, environment)
	var selected_lane := clampi(int(ui_state.get("coin_pusher_lane", int(machine.get("last_lane", _lane_count() / 2)))), 0, _lane_count() - 1)
	var force_order := _force_order()
	var direction_order := _direction_order()
	var force := str(ui_state.get("coin_pusher_force", _default_force()))
	var direction := str(ui_state.get("coin_pusher_direction", _default_direction()))
	if not force_order.has(force):
		force = _default_force()
	if not direction_order.has(direction):
		direction = _default_direction()
	return GameModule.surface_spec({
		"surface_renderer": "coin_pusher",
		"surface_life": "coin_pusher_attract",
		"surface_cast": "machine",
		"surface_controls_native": true,
		"surface_fixed_price_actions": true,
		"surface_stake_controls_required": false,
		"surface_animates_idle": true,
		"surface_web_idle_animation_fps": 15.0,
		"surface_embeds_outcomes": true,
		"surface_suppresses_game_result_burst": true,
		"surface_time_msec": int(ui_state.get("surface_time_msec", 1)),
		"coin_pusher_cells": _cell_views(machine),
		"coin_pusher_riders": _rider_views(machine),
		"coin_pusher_lanes": _lane_views(machine),
		"coin_pusher_lane": selected_lane,
		"coin_pusher_force": force,
		"coin_pusher_direction": direction,
		"coin_pusher_force_order": force_order,
		"coin_pusher_direction_order": direction_order,
		"coin_pusher_variation_id": _variation_id(),
		"coin_pusher_phase_steps": _phase_steps(),
		"coin_pusher_upper_phase": int(machine.get("upper_phase", 0)),
		"coin_pusher_lower_phase": int(machine.get("lower_phase", 0)),
		"coin_pusher_tray_value": int(machine.get("tray_value", 0)),
		"coin_pusher_tell_rung": int(machine.get("tell_rung", 0)),
		"coin_pusher_tell": _tell_label(int(machine.get("tell_rung", 0))),
		"coin_pusher_locked": bool(machine.get("locked_down", false)),
		"coin_pusher_last_message": str(machine.get("last_message", "Pick a lane. Read both shelves.")),
		"coin_pusher_action_count": int(machine.get("action_count", 0)),
		"coin_pusher_cold_armed": bool(machine.get("cold_quarters_armed", false)),
		"coin_pusher_shim_uses": int(machine.get("shim_uses_remaining", 0)),
		"native_selected_surface_actions": [DROP_ACTION, NUDGE_ACTION],
		"surface_action_bindings": {
			"legal": {"action": DROP_ACTION, "index": 0},
			"cheat": {"action": NUDGE_ACTION, "index": 0},
		},
		"surface_animation_channels": [
			GameModule.surface_animation_channel(
				"coin_pusher_rock",
				"tell_%d_action_%d" % [int(machine.get("tell_rung", 0)), int(machine.get("action_count", 0))] if int(machine.get("tell_rung", 0)) > 0 else "",
				460,
				0,
				{"active": int(machine.get("tell_rung", 0)) > 0, "metadata": {"tell_rung": int(machine.get("tell_rung", 0))}}
			),
		],
		"surface_audio": GameModule.surface_audio_spec({
			"profile_id": "coin_pusher",
			"action_cues": {
				"coin_pusher_drop": "machine_button",
				"coin_pusher_nudge": "table_hit",
			},
		}),
	})


func surface_action_command(surface_action: String, index: int, _confirm_requested: bool, ui_state: Dictionary, _run_state: RunState, _environment: Dictionary) -> Dictionary:
	var next := ui_state.duplicate(true)
	match surface_action:
		"coin_pusher_lane":
			next["coin_pusher_lane"] = clampi(index, 0, _lane_count() - 1)
			return GameModule.surface_command({"ui_state": next, "preserve_surface_ui_state": true, "message": "Lane %d lined up." % (clampi(index, 0, _lane_count() - 1) + 1)})
		"coin_pusher_force":
			var force_order := _force_order()
			next["coin_pusher_force"] = str(force_order[clampi(index, 0, force_order.size() - 1)])
			return GameModule.surface_command({"ui_state": next, "preserve_surface_ui_state": true, "message": "%s force ready." % str(next["coin_pusher_force"]).capitalize()})
		"coin_pusher_direction":
			var direction_order := _direction_order()
			next["coin_pusher_direction"] = str(direction_order[clampi(index, 0, direction_order.size() - 1)])
			return GameModule.surface_command({"ui_state": next, "preserve_surface_ui_state": true, "message": "%s nudge lined up." % str(next["coin_pusher_direction"]).capitalize()})
		"coin_pusher_drop":
			return GameModule.surface_command({"ui_state": next, "action_id": DROP_ACTION, "action_kind": "legal", "resolve": true, "direct_resolve": true, "set_stake": _drop_cost(), "preserve_surface_ui_state": true, "message": "Quarter committed."})
		"coin_pusher_nudge":
			return GameModule.surface_command({"ui_state": next, "action_id": NUDGE_ACTION, "action_kind": "risky", "resolve": true, "direct_resolve": true, "skip_stake_validation": true, "preserve_surface_ui_state": true, "message": "Hands on the cabinet."})
	return {"handled": false}


func surface_motion_signature(surface, surface_state: Dictionary) -> Dictionary:
	var motion_phase := float(surface.surface_flicker()) if surface != null and surface.has_method("surface_flicker") else 0.0
	var rider_lane := 0
	var riders: Array = surface_state.get("coin_pusher_riders", []) if typeof(surface_state.get("coin_pusher_riders", [])) == TYPE_ARRAY else []
	if not riders.is_empty() and typeof(riders[0]) == TYPE_DICTIONARY:
		rider_lane = int((riders[0] as Dictionary).get("lane", 0))
	return {
		"attract_shift_milli": int(round(sin(motion_phase * 2.0) * 2500.0)),
		"rider_bob_milli": int(round(sin(motion_phase * 3.0 + float(rider_lane) * 0.7) * 2500.0)),
	}


func draw_surface(surface, state: Dictionary, _render_context: Dictionary = {}) -> bool:
	if str(state.get("surface_renderer", "")) != "coin_pusher":
		return false
	surface.surface_begin_design_space(SURFACE_SIZE)
	surface.draw_rect(Rect2(Vector2.ZERO, SURFACE_SIZE), C_BG)
	var cabinet := Rect2(32, 18, 610, 390)
	if int(state.get("coin_pusher_tell_rung", 0)) > 0:
		cabinet.position.x += sin(float(surface.surface_flicker()) * 14.0) * float(int(state.get("coin_pusher_tell_rung", 0)))
	surface.draw_rect(cabinet, C_CASE)
	surface.draw_rect(Rect2(56, 48, 562, 282), C_GLASS)
	var flicker := float(surface.surface_flicker())
	var attract_shift := sin(flicker * 2.0) * 2.5
	_draw_shelf(surface, 80.0 + attract_shift, int(state.get("coin_pusher_upper_phase", 0)), C_TEAL)
	_draw_shelf(surface, 225.0 - attract_shift, int(state.get("coin_pusher_lower_phase", 0)), Color("#ff8e5b"))
	_draw_cells(surface, state)
	_draw_lane_approaches(surface, state)
	_draw_riders(surface, state)
	_draw_console(surface, state)
	surface.surface_end_design_space()
	return true


func resolve(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return resolve_with_context(action_id, stake, run_state, environment, rng, {})


func resolve_with_context(action_id: String, _stake: int, run_state: RunState, environment: Dictionary, rng: RngStream, ui_state: Dictionary = {}) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, true)
	if bool(machine.get("locked_down", false)):
		return _empty_pusher_result(action_id, environment, "Red light. This cabinet stays dead tonight; the rest of the room is open.")
	if action_id == DROP_ACTION:
		return _resolve_drop(run_state, environment, machine, rng, ui_state)
	if action_id == NUDGE_ACTION:
		return _resolve_nudge(run_state, environment, machine, rng, ui_state)
	return _empty_pusher_result(action_id, environment, "That button does nothing but collect fingerprints.")


func active_item_command(item_id: String, run_state: RunState, environment: Dictionary, _rng: RngStream) -> Dictionary:
	if item_id != COLD_QUARTERS_ITEM_ID or run_state == null or not run_state.inventory.has(item_id):
		return {"handled": false}
	var machine := _ensure_machine_state(run_state, environment, true)
	if bool(machine.get("locked_down", false)):
		return {"handled": true, "message": "Cold metal won't wake a locked cabinet."}
	machine["cold_quarters_armed"] = true
	machine["cold_quarters_density_armed"] = maxi(_cold_density(), run_state.item_effect_total("coin_pusher_drop_density", "coin_pusher"))
	_write_machine_state(environment, machine)
	var deltas := GameModule.empty_result_deltas()
	deltas["inventory_remove"] = [item_id]
	var message := "Cold quarters loaded. The next drop hits heavy."
	deltas["messages"] = [message]
	var result := GameModule.build_action_result({
		"source_id": get_id(), "game_id": get_id(), "action_id": "load_cold_quarters", "action_kind": "item",
		"environment_id": str(environment.get("id", "")), "deltas": deltas, "message": message,
	})
	return {"handled": true, "environment_changed": true, "result": result, "message": message}


func deterministic_state_digest(environment: Dictionary) -> String:
	var machine := _read_machine_state(null, environment)
	return JSON.stringify(_digest_state(machine), "", true)


func _resolve_drop(run_state: RunState, environment: Dictionary, machine: Dictionary, rng: RngStream, ui_state: Dictionary) -> Dictionary:
	var cost := _drop_cost()
	if run_state != null and run_state.wager_capacity_for_game(get_id(), environment) < cost:
		return _empty_pusher_result(DROP_ACTION, environment, "You need a dollar to feed this thing.")
	var lane := clampi(int(ui_state.get("coin_pusher_lane", machine.get("last_lane", _lane_count() / 2))), 0, _lane_count() - 1)
	var density := maxi(_cold_density(), int(machine.get("cold_quarters_density_armed", 0))) if bool(machine.get("cold_quarters_armed", false)) else 1
	machine["cold_quarters_armed"] = false
	machine["cold_quarters_density_armed"] = 0
	var gutter := _drop_hits_gutter(lane, int(machine.get("upper_phase", 0)), rng)
	var shim_recovered := false
	if gutter and _shim_available(run_state, machine):
		gutter = false
		shim_recovered = true
		machine["shim_uses_remaining"] = maxi(0, int(machine.get("shim_uses_remaining", 0)) - 1)
	var payout := 0
	var prizes: Array = []
	if not gutter:
		_add_coins(machine, lane, _cell_count() - 1, density)
		var settle := _settle_shelves(machine, rng, density, lane, false)
		payout = int(settle.get("payout", 0))
		prizes = settle.get("prizes", []) if typeof(settle.get("prizes", [])) == TYPE_ARRAY else []
		payout += _prize_cash(prizes)
	_advance_shelves(machine)
	machine["action_count"] = int(machine.get("action_count", 0)) + 1
	machine["last_lane"] = lane
	machine["total_cost"] = int(machine.get("total_cost", 0)) + cost
	machine["total_payout"] = int(machine.get("total_payout", 0)) + payout
	machine["tray_value"] = int(machine.get("tray_value", 0)) + payout
	var message := "Side gutter. Quarter gone." if gutter else "%s drops. Tray pays $%d." % ["Cold weight" if density > 1 else "Quarter", payout]
	if shim_recovered:
		message = "The shim catches the gutter and kicks the quarter back. " + message
	if not prizes.is_empty():
		message += " Prize rider down: %s." % _prize_labels(prizes)
	machine["last_message"] = message
	_write_machine_state(environment, machine)
	_register_pile_rumor(run_state, environment, machine)
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = payout - cost
	var staff_watch_heat := _staff_watch_suspicion_delta(run_state, machine)
	deltas["suspicion_delta"] = staff_watch_heat
	deltas["inventory_add"] = _inventory_prizes(prizes)
	deltas["story_log"] = [_story_entry(DROP_ACTION, "legal", environment, payout - cost, 0, {"lane": lane, "gutter": gutter, "prizes": prizes})]
	deltas["messages"] = [message]
	var result := GameModule.build_action_result({
		"source_id": get_id(), "game_id": get_id(), "action_id": DROP_ACTION, "action_kind": "legal", "stake": cost,
		"environment_id": str(environment.get("id", "")), "environment_archetype_id": str(environment.get("archetype_id", "")),
		"bankroll_delta": payout - cost, "suspicion_delta": staff_watch_heat, "deltas": deltas, "won": payout > cost or not prizes.is_empty(), "message": message,
	})
	result["host_apply_result"] = true
	result["coin_pusher_payout"] = payout
	result["coin_pusher_prizes"] = prizes
	result["coin_pusher_gutter"] = gutter
	result["coin_pusher_shim_recovered"] = shim_recovered
	result["preserve_surface_ui_state"] = true
	return result


func _resolve_nudge(run_state: RunState, environment: Dictionary, machine: Dictionary, rng: RngStream, ui_state: Dictionary) -> Dictionary:
	# Staff memory predating this action may restore its floor. A hard alarm
	# created by this action starts watching from the following action onward.
	var staff_watch_heat := _staff_watch_suspicion_delta(run_state, machine)
	var force_order := _force_order()
	var direction_order := _direction_order()
	var force := str(ui_state.get("coin_pusher_force", _default_force()))
	var direction := str(ui_state.get("coin_pusher_direction", _default_direction()))
	if not force_order.has(force):
		force = _default_force()
	if not direction_order.has(direction):
		direction = _default_direction()
	var lane := clampi(int(ui_state.get("coin_pusher_lane", machine.get("last_lane", _lane_count() / 2))), 0, _lane_count() - 1)
	var timing_phase := int(ui_state.get("coin_pusher_timing_phase", machine.get("lower_phase", 0)))
	var phase_distance := _phase_distance(timing_phase, _clean_nudge_phase())
	var clean_window := _clean_window()
	var aimed := _direction_matches_hanger(machine, direction, lane)
	var clean := phase_distance <= clean_window and aimed
	var authored_push := _force_push_strength(force)
	var tolerance_cost := 0 if clean else _force_tolerance_cost(force)
	var tolerance_before := int(machine.get("alarm_tolerance_remaining", 1))
	var previous_tell := int(machine.get("tell_rung", 0))
	machine["alarm_tolerance_remaining"] = tolerance_before - tolerance_cost
	var push_strength := authored_push if clean else maxi(0, authored_push - _mistimed_push_penalty())
	if force == "slam":
		push_strength += _slam_bonus_push()
	var settle := _settle_shelves(machine, rng, push_strength, lane, true, direction)
	var payout := int(settle.get("payout", 0))
	var prizes: Array = settle.get("prizes", []) if typeof(settle.get("prizes", [])) == TYPE_ARRAY else []
	payout += _prize_cash(prizes)
	var alarmed := int(machine.get("alarm_tolerance_remaining", 0)) < 0
	var heat := 0
	if alarmed:
		heat = _alarm_heat()
		machine["locked_down"] = true
		machine["lockdown_night"] = _night_id(run_state)
		machine["staff_watch_memory"] = true
		machine["suspicion_floor"] = maxi(int(machine.get("suspicion_floor", 0)), _watch_suspicion_floor())
		machine["tell_rung"] = 3
	else:
		machine["tell_rung"] = _tell_rung(machine)
		if int(machine.get("tell_rung", 0)) >= 3 and previous_tell < 3:
			heat = _attendant_glance_heat()
	_advance_shelves(machine)
	machine["action_count"] = int(machine.get("action_count", 0)) + 1
	machine["total_payout"] = int(machine.get("total_payout", 0)) + payout
	machine["tray_value"] = int(machine.get("tray_value", 0)) + payout
	var message := _nudge_message(force, clean, payout, alarmed)
	if not prizes.is_empty():
		message += " Rider down: %s." % _prize_labels(prizes)
	machine["last_message"] = message
	_write_machine_state(environment, machine)
	_register_pile_rumor(run_state, environment, machine)
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = payout
	var total_heat := heat + staff_watch_heat
	deltas["suspicion_delta"] = total_heat
	deltas["inventory_add"] = _inventory_prizes(prizes)
	deltas["story_log"] = [_story_entry(NUDGE_ACTION, "risky", environment, payout, heat, {
		"force": force, "direction": direction, "clean": clean, "phase_distance": phase_distance,
		"tell_rung": int(machine.get("tell_rung", 0)), "hard_alarm": alarmed, "machine_lockdown_only": alarmed,
	})]
	deltas["messages"] = [message]
	var result := GameModule.build_action_result({
		"source_id": "coin_pusher_alarm" if alarmed else get_id(), "game_id": get_id(), "action_id": "nudge_alarm" if alarmed else NUDGE_ACTION,
		"action_kind": "risky", "stake": 0, "environment_id": str(environment.get("id", "")),
		"environment_archetype_id": str(environment.get("archetype_id", "")), "bankroll_delta": payout,
		"suspicion_delta": total_heat, "deltas": deltas, "won": payout > 0, "message": message,
		"skill_outcome": "clean_drop" if clean else "alarm" if alarmed else "wasted_tolerance",
		"skill_grade": "perfect" if clean else "blown" if alarmed else "partial",
		"skill_accuracy": 100 if clean else maxi(0, _skill_accuracy_base() - phase_distance * _skill_accuracy_phase_penalty()),
		"base_suspicion_delta": heat,
	})
	result["host_apply_result"] = true
	result["coin_pusher_hard_alarm"] = alarmed
	result["coin_pusher_machine_locked"] = bool(machine.get("locked_down", false))
	result["coin_pusher_player_remains_in_environment"] = true
	result["coin_pusher_environment_id_before"] = str(environment.get("id", ""))
	result["coin_pusher_tell_rung"] = int(machine.get("tell_rung", 0))
	result["coin_pusher_clean_drop"] = clean
	result["coin_pusher_tolerance_spent"] = tolerance_cost
	result["coin_pusher_force_push"] = authored_push
	result["coin_pusher_push_strength"] = push_strength
	result["coin_pusher_payout"] = payout
	result["coin_pusher_prizes"] = prizes
	result["preserve_surface_ui_state"] = true
	if not alarmed and int(machine.get("tell_rung", 0)) == 2 and previous_tell < 2:
		result["surface_audio_cue"] = "alarm_chirp"
	return result


func _generate_machine_state(run_state: RunState, environment: Dictionary, rng: RngStream = null) -> Dictionary:
	var local_rng := rng
	if local_rng == null:
		local_rng = RngStream.new()
		local_rng.configure(_stable_hash("%s:%s:%s" % [get_id(), str(run_state.seed_text if run_state != null else "fallback"), str(environment.get("id", "node"))]))
	var lanes: Array = []
	for lane_index in range(_lane_count()):
		var cells: Array = []
		for cell_index in range(_cell_count()):
			var base_height := local_rng.randi_range(_initial_height_min(), _initial_height_max())
			if cell_index == 0:
				base_height += local_rng.randi_range(0, 2)
			cells.append({"height": base_height, "edge_hang": cell_index == 0 and base_height >= _cell_capacity()})
		lanes.append({"cells": cells, "approach": lane_index - (_lane_count() / 2)})
	var base_tolerance := local_rng.randi_range(_tolerance_min(), _tolerance_max())
	var tolerance := maxi(1, base_tolerance + _security_tolerance_delta(environment, run_state))
	var machine := {
		"schema": STATE_SCHEMA,
		"version": _state_version(),
		"variation_id": _variation_id(),
		"lanes": lanes,
		"riders": _seed_prize_riders(environment, local_rng),
		"upper_phase": local_rng.randi_range(0, _phase_steps() - 1),
		"lower_phase": local_rng.randi_range(0, _phase_steps() - 1),
		"action_count": 0,
		"last_lane": _lane_count() / 2,
		"tray_value": 0,
		"total_cost": 0,
		"total_payout": 0,
		"base_alarm_tolerance": base_tolerance,
		"alarm_tolerance_remaining": tolerance,
		"tolerance_modifier": tolerance - base_tolerance,
		"tell_rung": 0,
		"locked_down": false,
		"lockdown_night": "",
		"staff_watch_memory": false,
		"suspicion_floor": 0,
		"cold_quarters_armed": false,
		"cold_quarters_density_armed": 0,
		"shim_initialized": false,
		"shim_uses_remaining": 0,
		"scenario_reset_token": _scenario_reset_token(environment),
		"last_message": "Pick a lane. Read both shelves.",
	}
	_update_edge_hangers(machine)
	return machine


func _ensure_machine_state(run_state: RunState, environment: Dictionary, persist: bool) -> Dictionary:
	var game_states := _game_states(environment)
	var value: Variant = game_states.get(get_id(), {})
	var machine: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	# Read paths may normalize an old schema, roll a nightly lock forward, or
	# initialize item state. Never let those operations write through an alias.
	if not persist and not machine.is_empty():
		machine = machine.duplicate(true)
	var reset_token := _scenario_reset_token(environment)
	if machine.is_empty() or str(machine.get("schema", "")) != STATE_SCHEMA:
		machine = _generate_machine_state(run_state, environment)
	elif int(machine.get("version", 0)) < _state_version() or str(machine.get("variation_id", "")) != _variation_id():
		machine = _normalize_machine_state(machine)
	elif not reset_token.is_empty() and reset_token != str(machine.get("scenario_reset_token", "")):
		machine = _generate_machine_state(run_state, environment)
		machine["scenario_reset_token"] = reset_token
	if bool(machine.get("locked_down", false)) and run_state != null and str(machine.get("lockdown_night", "")) != _night_id(run_state):
		machine["locked_down"] = false
		machine["lockdown_night"] = ""
		machine["tolerance_modifier"] = _security_tolerance_delta(environment, run_state)
		machine["alarm_tolerance_remaining"] = maxi(1, int(machine.get("base_alarm_tolerance", _tolerance_min())) + int(machine.get("tolerance_modifier", 0)))
		machine["tell_rung"] = 0
	_initialize_owned_shim(run_state, machine)
	if persist:
		_write_machine_state(environment, machine)
	return machine


func _read_machine_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	return _ensure_machine_state(run_state, environment, false)


func _write_machine_state(environment: Dictionary, machine: Dictionary) -> void:
	var game_states := _game_states(environment).duplicate(false)
	game_states[get_id()] = machine
	environment["game_states"] = game_states


func _initialize_owned_shim(run_state: RunState, machine: Dictionary) -> void:
	if run_state == null or bool(machine.get("shim_initialized", false)) or not run_state.inventory.has(SHIM_ITEM_ID):
		return
	machine["shim_initialized"] = true
	machine["shim_uses_remaining"] = _shim_uses(run_state)


func _game_states(environment: Dictionary) -> Dictionary:
	var value: Variant = environment.get("game_states", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _normalize_machine_state(source: Dictionary) -> Dictionary:
	var machine := source.duplicate(true)
	machine["schema"] = STATE_SCHEMA
	machine["version"] = _state_version()
	machine["variation_id"] = _variation_id()
	for key in ["tray_value", "total_cost", "total_payout", "action_count", "tell_rung", "suspicion_floor"]:
		machine[key] = maxi(0, int(machine.get(key, 0)))
	machine["staff_watch_memory"] = bool(machine.get("staff_watch_memory", false))
	machine["locked_down"] = bool(machine.get("locked_down", false))
	return machine


func _settle_shelves(machine: Dictionary, rng: RngStream, push_strength: int, aimed_lane: int, from_nudge: bool, direction: String = "front") -> Dictionary:
	var payout := 0
	var prizes: Array = []
	var passes := clampi(push_strength, 0, _max_settle_passes())
	for pass_index in range(passes):
		for lane_index in range(_lane_count()):
			if from_nudge and not _nudge_affects_lane(direction, aimed_lane, lane_index):
				continue
			for cell_index in range(_cell_count()):
				var cell := _cell(machine, lane_index, cell_index)
				var phase := int(machine.get("lower_phase" if cell_index < _cell_count() / 2 else "upper_phase", 0))
				var threshold := _cell_capacity() + (_retracted_stack_threshold_bonus() if not _phase_is_forward(phase) else 0)
				if int(cell.get("height", 0)) <= threshold:
					continue
				var move_count := mini(int(cell.get("height", 0)) - threshold, 1 + (_strong_push_extra_coins() if push_strength >= _strong_push_threshold() and pass_index == 0 else 0))
				if rng.randi_range(1, 100) > _push_chance(phase, from_nudge):
					continue
				cell["height"] = maxi(0, int(cell.get("height", 0)) - move_count)
				_set_cell(machine, lane_index, cell_index, cell)
				var rider_result := _advance_riders(machine, lane_index, cell_index, move_count)
				prizes.append_array(rider_result.get("prizes", []))
				if cell_index == 0:
					payout += move_count * _coin_value()
				else:
					_add_coins(machine, lane_index, cell_index - 1, move_count)
	_update_edge_hangers(machine)
	return {"payout": payout, "prizes": prizes}


func _advance_riders(machine: Dictionary, lane: int, cell_index: int, moved: int) -> Dictionary:
	var riders: Array = machine.get("riders", []) if typeof(machine.get("riders", [])) == TYPE_ARRAY else []
	var remaining: Array = []
	var prizes: Array = []
	for value in riders:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var rider: Dictionary = value
		if int(rider.get("lane", -1)) == lane and int(rider.get("cell", -1)) == cell_index:
			rider = rider.duplicate(false)
			rider["push"] = int(rider.get("push", 0)) + moved
			if int(rider.get("push", 0)) >= _rider_push_threshold():
				rider["push"] = 0
				rider["cell"] = cell_index - 1
		if int(rider.get("cell", 0)) < 0:
			prizes.append(rider)
		else:
			remaining.append(rider)
	machine["riders"] = remaining
	return {"prizes": prizes}


func _add_coins(machine: Dictionary, lane: int, cell_index: int, amount: int) -> void:
	if amount <= 0:
		return
	var cell := _cell(machine, lane, cell_index)
	cell["height"] = int(cell.get("height", 0)) + amount
	_set_cell(machine, lane, cell_index, cell)


func _cell(machine: Dictionary, lane: int, cell_index: int) -> Dictionary:
	var lanes: Array = machine.get("lanes", []) if typeof(machine.get("lanes", [])) == TYPE_ARRAY else []
	if lane < 0 or lane >= lanes.size() or typeof(lanes[lane]) != TYPE_DICTIONARY:
		return {"height": 0, "edge_hang": false}
	var cells: Array = (lanes[lane] as Dictionary).get("cells", []) if typeof((lanes[lane] as Dictionary).get("cells", [])) == TYPE_ARRAY else []
	if cell_index < 0 or cell_index >= cells.size() or typeof(cells[cell_index]) != TYPE_DICTIONARY:
		return {"height": 0, "edge_hang": false}
	return cells[cell_index]


func _set_cell(machine: Dictionary, lane: int, cell_index: int, cell: Dictionary) -> void:
	var lanes: Array = machine.get("lanes", []) if typeof(machine.get("lanes", [])) == TYPE_ARRAY else []
	if lane < 0 or lane >= lanes.size() or typeof(lanes[lane]) != TYPE_DICTIONARY:
		return
	var lane_data: Dictionary = lanes[lane]
	var cells: Array = lane_data.get("cells", []) if typeof(lane_data.get("cells", [])) == TYPE_ARRAY else []
	if cell_index < 0 or cell_index >= cells.size():
		return
	cells[cell_index] = cell
	lane_data["cells"] = cells
	lanes[lane] = lane_data
	machine["lanes"] = lanes


func _update_edge_hangers(machine: Dictionary) -> void:
	for lane in range(_lane_count()):
		var cell := _cell(machine, lane, 0)
		cell["edge_hang"] = int(cell.get("height", 0)) >= _cell_capacity()
		_set_cell(machine, lane, 0, cell)


func _advance_shelves(machine: Dictionary) -> void:
	machine["upper_phase"] = posmod(int(machine.get("upper_phase", 0)) + _upper_phase_step(), _phase_steps())
	machine["lower_phase"] = posmod(int(machine.get("lower_phase", 0)) + _lower_phase_step(), _phase_steps())


func _drop_hits_gutter(lane: int, phase: int, rng: RngStream) -> bool:
	var edge := lane == 0 or lane == _lane_count() - 1
	var chance := _gutter_edge_percent() if edge else _gutter_center_percent()
	if not _phase_is_forward(phase):
		chance += _gutter_retracted_bonus()
	return rng.randi_range(1, 100) <= chance


func _direction_matches_hanger(machine: Dictionary, direction: String, lane: int) -> bool:
	if direction == "front":
		return bool(_cell(machine, lane, 0).get("edge_hang", false))
	if direction == "left":
		for index in range(0, _lane_count() / 2 + 1):
			if bool(_cell(machine, index, 0).get("edge_hang", false)):
				return true
	if direction == "right":
		for index in range(_lane_count() / 2, _lane_count()):
			if bool(_cell(machine, index, 0).get("edge_hang", false)):
				return true
	return false


func _nudge_affects_lane(direction: String, aimed_lane: int, lane: int) -> bool:
	if direction == "front":
		return abs(lane - aimed_lane) <= _front_nudge_lane_radius()
	if direction == "left":
		return lane <= _lane_count() / 2
	return lane >= _lane_count() / 2


func _security_tolerance_delta(environment: Dictionary, run_state: RunState = null) -> int:
	var security: Dictionary = environment.get("security_profile", {}) if typeof(environment.get("security_profile", {})) == TYPE_DICTIONARY else {}
	var band := str(security.get("machine_alarm_tolerance_band", security.get("strictness", "normal"))).to_lower()
	var channels: Dictionary = security.get("security_override_channels", {}) if typeof(security.get("security_override_channels", {})) == TYPE_DICTIONARY else {}
	var sweep: Dictionary = channels.get("police_sweep", {}) if typeof(channels.get("police_sweep", {})) == TYPE_DICTIONARY else {}
	var direct_delta := 0
	if sweep.is_empty():
		direct_delta = _security_band_delta(band) + int(security.get("pusher_alarm_tolerance_band_delta", 0))
	else:
		var base_band := str(sweep.get("base_machine_alarm_tolerance_band", "normal")).to_lower()
		direct_delta = _security_band_delta(base_band) + int(sweep.get("pusher_alarm_tolerance_band_delta", security.get("pusher_alarm_tolerance_band_delta", 0)))
	var adjacent_delta := _adjacent_scenario_tolerance_delta(run_state)
	return direct_delta if adjacent_delta == 0 else mini(direct_delta, adjacent_delta)


func _adjacent_scenario_tolerance_delta(run_state: RunState) -> int:
	if run_state == null or library == null or run_state.world_map.is_empty():
		return 0
	var current_node := run_state.current_world_node_id()
	if current_node.is_empty():
		return 0
	var strictest_delta := 0
	var edges: Array = run_state.world_map.get("edges", []) if typeof(run_state.world_map.get("edges", [])) == TYPE_ARRAY else []
	for edge_value in edges:
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		var a := str(edge.get("a", ""))
		var b := str(edge.get("b", ""))
		var neighbor := b if a == current_node else a if b == current_node else ""
		if neighbor.is_empty():
			continue
		var public_scenario := run_state.scenario_for_node(neighbor)
		var scenario_definition := library.scenario(str(public_scenario.get("id", "")))
		var mutations: Dictionary = scenario_definition.get("mutations", {}) if typeof(scenario_definition.get("mutations", {})) == TYPE_DICTIONARY else {}
		var hooks: Dictionary = mutations.get("hook_flags", {}) if typeof(mutations.get("hook_flags", {})) == TYPE_DICTIONARY else {}
		var nearby_band := str(hooks.get("nearby_alarm_tolerance_band", "")).to_lower()
		if not nearby_band.is_empty():
			strictest_delta = mini(strictest_delta, _security_band_delta(nearby_band))
	return strictest_delta


func _tell_rung(machine: Dictionary) -> int:
	var tolerance := int(machine.get("alarm_tolerance_remaining", 0))
	var base := maxi(1, int(machine.get("base_alarm_tolerance", 1)) + int(machine.get("tolerance_modifier", 0)))
	if tolerance <= 0:
		return 3
	if tolerance <= maxi(1, base / 3):
		return 2
	if tolerance <= maxi(2, (base * 2) / 3):
		return 1
	return 0


func _tell_label(rung: int) -> String:
	var labels := _tell_labels()
	return str(labels[clampi(rung, 0, labels.size() - 1)])


func _phase_distance(a: int, b: int) -> int:
	var steps := _phase_steps()
	var direct: int = abs(posmod(a, steps) - posmod(b, steps))
	return mini(direct, steps - direct)


func _phase_is_forward(phase: int) -> bool:
	return _phase_distance(phase, _clean_nudge_phase()) <= _forward_phase_window()


func _shim_available(run_state: RunState, machine: Dictionary) -> bool:
	return run_state != null and run_state.inventory.has(SHIM_ITEM_ID) and int(machine.get("shim_uses_remaining", 0)) > 0


func _scenario_reset_token(environment: Dictionary) -> String:
	var modifiers: Dictionary = environment.get("scenario_game_modifiers", {}) if typeof(environment.get("scenario_game_modifiers", {})) == TYPE_DICTIONARY else {}
	var pusher: Dictionary = modifiers.get("coin_pusher", {}) if typeof(modifiers.get("coin_pusher", {})) == TYPE_DICTIONARY else {}
	if not bool(pusher.get("reset_pile", false)):
		return ""
	return str(pusher.get("reset_token", environment.get("scenario_id", "scenario_reset")))


func _night_id(run_state: RunState) -> String:
	if run_state == null:
		return "night"
	return "%s:%d" % [str(run_state.seed_text), int(run_state.game_day())]


func _register_pile_rumor(run_state: RunState, environment: Dictionary, machine: Dictionary) -> void:
	if run_state == null:
		return
	var node_id := str(environment.get("world_node_id", ""))
	if node_id.is_empty():
		node_id = str(environment.get("id", ""))
	if node_id.is_empty():
		node_id = run_state.current_world_node_id()
	if node_id.is_empty():
		return
	var hangers := _hanger_count(machine)
	var detail := "hanging off the lip" if hangers >= 2 else "fat in the middle" if _pile_coin_count(machine) >= _lane_count() * _cell_count() * _cell_capacity() else "still hungry"
	run_state.register_rumor_fact(RUMOR_CLASS, "pusher:%s" % node_id, {
		"target_node_id": node_id,
		"target_name": str(environment.get("name", environment.get("display_name", node_id))),
		"fact_detail": detail,
		"source_id": get_id(),
		"truth_trace": {"game_id": get_id(), "environment_id": str(environment.get("id", "")), "action_count": int(machine.get("action_count", 0))},
	})


func _staff_watch_suspicion_delta(run_state: RunState, machine: Dictionary) -> int:
	if run_state == null or not bool(machine.get("staff_watch_memory", false)):
		return 0
	return maxi(0, int(machine.get("suspicion_floor", 0)) - run_state.suspicion_level())


func _seed_prize_riders(environment: Dictionary, rng: RngStream) -> Array:
	var tuning := _tuning()
	var definitions: Array = tuning.get("prize_riders", []) if typeof(tuning.get("prize_riders", [])) == TYPE_ARRAY else []
	var scenario_items: Array = []
	var modifiers: Dictionary = environment.get("scenario_game_modifiers", {}) if typeof(environment.get("scenario_game_modifiers", {})) == TYPE_DICTIONARY else {}
	var pusher: Dictionary = modifiers.get("coin_pusher", {}) if typeof(modifiers.get("coin_pusher", {})) == TYPE_DICTIONARY else {}
	if typeof(pusher.get("prize_item_ids", [])) == TYPE_ARRAY:
		scenario_items = pusher.get("prize_item_ids", [])
	var riders: Array = []
	var count := rng.randi_range(_prize_count_min(), _prize_count_max())
	for index in range(count):
		var picked: Dictionary = _weighted_prize(definitions, rng)
		if picked.is_empty():
			continue
		var item_id := str(picked.get("item_id", ""))
		if str(picked.get("kind", "")) == "scenario_item" and not scenario_items.is_empty():
			item_id = str(scenario_items[rng.randi_range(0, scenario_items.size() - 1)])
		if str(picked.get("kind", "")) == "scenario_item" and item_id.is_empty():
			continue
		riders.append({
			"id": "rider_%02d" % index,
			"kind": str(picked.get("kind", "chip_stack")),
			"label": str(picked.get("label", "chip stack")),
			"item_id": item_id,
			"cash_value": maxi(0, int(picked.get("cash_value", 0))),
			"lane": rng.randi_range(0, _lane_count() - 1),
			"cell": rng.randi_range(1, mini(_prize_initial_cell_max(), _cell_count() - 1)),
			"push": rng.randi_range(0, maxi(0, _rider_push_threshold() - 1)),
		})
	return riders


func _weighted_prize(definitions: Array, rng: RngStream) -> Dictionary:
	var total := 0
	for value in definitions:
		if typeof(value) == TYPE_DICTIONARY:
			total += maxi(0, int((value as Dictionary).get("weight", 0)))
	if total <= 0:
		return {}
	var roll := rng.randi_range(1, total)
	for value in definitions:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		roll -= maxi(0, int((value as Dictionary).get("weight", 0)))
		if roll <= 0:
			return (value as Dictionary).duplicate(true)
	return {}


func _inventory_prizes(prizes: Array) -> Array:
	var result: Array = []
	for value in prizes:
		if typeof(value) == TYPE_DICTIONARY:
			var item_id := str((value as Dictionary).get("item_id", ""))
			if not item_id.is_empty() and not result.has(item_id):
				result.append(item_id)
	return result


func _prize_cash(prizes: Array) -> int:
	var result := 0
	for value in prizes:
		if typeof(value) == TYPE_DICTIONARY:
			result += maxi(0, int((value as Dictionary).get("cash_value", 0)))
	return result


func _prize_labels(prizes: Array) -> String:
	var labels: Array = []
	for value in prizes:
		if typeof(value) == TYPE_DICTIONARY:
			labels.append(str((value as Dictionary).get("label", (value as Dictionary).get("item_id", "prize"))))
	return ", ".join(labels)


func _story_entry(action_id: String, kind: String, environment: Dictionary, bankroll_delta: int, heat: int, context: Dictionary) -> Dictionary:
	return {
		"type": "game_action", "source_id": get_id(), "game_id": get_id(), "action_id": action_id,
		"action_kind": kind, "environment_id": str(environment.get("id", "")), "bankroll_delta": bankroll_delta,
		"suspicion_delta": heat, "context": context,
	}


func _empty_pusher_result(action_id: String, environment: Dictionary, message: String) -> Dictionary:
	return GameModule.build_action_result({
		"ok": false, "source_id": get_id(), "game_id": get_id(), "action_id": action_id,
		"environment_id": str(environment.get("id", "")), "message": message,
	})


func _nudge_message(force: String, clean: bool, payout: int, alarmed: bool) -> String:
	if alarmed:
		return "%s hits hard. $%d spills before the alarm kills this cabinet. Staff clock you; nobody throws you out." % [force.capitalize(), payout]
	if clean:
		return "%s lands with the shelf. Hangers peel clean for $%d." % [force.capitalize(), payout]
	return "%s misses the shelf. The cabinet complains; $%d shakes loose." % [force.capitalize(), payout]


func _cell_views(machine: Dictionary) -> Array:
	var result: Array = []
	for lane in range(_lane_count()):
		for cell_index in range(_cell_count()):
			var cell := _cell(machine, lane, cell_index)
			result.append({"lane": lane, "cell": cell_index, "height": int(cell.get("height", 0)), "edge_hang": bool(cell.get("edge_hang", false))})
	return result


func _rider_views(machine: Dictionary) -> Array:
	var result: Array = []
	var riders: Array = machine.get("riders", []) if typeof(machine.get("riders", [])) == TYPE_ARRAY else []
	for value in riders:
		if typeof(value) == TYPE_DICTIONARY:
			var rider: Dictionary = value
			result.append({"label": str(rider.get("label", "prize")), "kind": str(rider.get("kind", "prize")), "lane": int(rider.get("lane", 0)), "cell": int(rider.get("cell", 0)), "push": int(rider.get("push", 0))})
	return result


func _lane_views(machine: Dictionary) -> Array:
	var result: Array = []
	var lanes: Array = machine.get("lanes", []) if typeof(machine.get("lanes", [])) == TYPE_ARRAY else []
	for lane_index in range(lanes.size()):
		var lane: Dictionary = lanes[lane_index] if typeof(lanes[lane_index]) == TYPE_DICTIONARY else {}
		result.append({"lane": lane_index, "approach": int(lane.get("approach", lane_index - (_lane_count() / 2)))})
	return result


func _digest_state(machine: Dictionary) -> Dictionary:
	return {
		"schema": str(machine.get("schema", "")), "version": int(machine.get("version", 0)), "variation_id": str(machine.get("variation_id", "")),
		"lanes": machine.get("lanes", []), "riders": machine.get("riders", []),
		"upper_phase": int(machine.get("upper_phase", 0)), "lower_phase": int(machine.get("lower_phase", 0)),
		"action_count": int(machine.get("action_count", 0)), "tray_value": int(machine.get("tray_value", 0)),
		"total_cost": int(machine.get("total_cost", 0)), "total_payout": int(machine.get("total_payout", 0)),
		"alarm_tolerance_remaining": int(machine.get("alarm_tolerance_remaining", 0)), "tell_rung": int(machine.get("tell_rung", 0)),
		"locked_down": bool(machine.get("locked_down", false)), "staff_watch_memory": bool(machine.get("staff_watch_memory", false)),
		"suspicion_floor": int(machine.get("suspicion_floor", 0)), "shim_uses_remaining": int(machine.get("shim_uses_remaining", 0)),
	}


func _draw_shelf(surface, y: float, phase: int, color: Color) -> void:
	var offset := sin(float(phase) / float(_phase_steps()) * TAU) * 14.0
	surface.draw_rect(Rect2(82 + offset, y, 505, 14), color)
	surface.draw_rect(Rect2(82 + offset, y, 505, 14), C_TEXT, false, 1)


func _draw_cells(surface, state: Dictionary) -> void:
	var selected_lane := int(state.get("coin_pusher_lane", 0))
	for value in state.get("coin_pusher_cells", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var cell: Dictionary = value
		var lane := int(cell.get("lane", 0))
		var depth := int(cell.get("cell", 0))
		var x := 83.0 + float(lane) * 103.0
		var y := 286.0 - float(depth) * 38.0
		var rect := Rect2(x, y, 84, 28)
		surface.draw_rect(rect, Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.12 if lane != selected_lane else 0.25))
		surface.draw_rect(rect, C_HANG if bool(cell.get("edge_hang", false)) else Color(C_TEXT.r, C_TEXT.g, C_TEXT.b, 0.3), false, 1)
		var height := int(cell.get("height", 0))
		for coin in range(mini(height, 6)):
			surface.draw_circle(Vector2(x + 10 + coin * 12, y + 14 - (coin % 2) * 4), 5, C_COIN)
		surface.surface_label("%d" % height, Vector2(x + 68, y + 17), 7, C_TEXT)
	for lane in range(_lane_count()):
		var button := Rect2(83 + lane * 103, 338, 84, 28)
		surface.draw_rect(button, C_TEAL if lane == selected_lane else C_CASE)
		surface.surface_label_centered("LANE %d" % (lane + 1), button, 8, C_BG if lane == selected_lane else C_TEXT)
		surface.surface_add_exact_hit(button, "coin_pusher_lane", lane)


func _draw_lane_approaches(surface, state: Dictionary) -> void:
	for value in state.get("coin_pusher_lanes", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var lane: Dictionary = value
		var lane_index := int(lane.get("lane", 0))
		var approach := int(lane.get("approach", 0))
		var center := Vector2(125.0 + float(lane_index) * 103.0, 327.0)
		surface.draw_line(center + Vector2(float(approach) * 5.0, -17.0), center, C_TEAL, 2.0)
		var label := "C"
		if approach < 0:
			label = "L%d" % absi(approach)
		elif approach > 0:
			label = "R%d" % approach
		surface.surface_label_centered(label, Rect2(center.x - 20.0, center.y - 14.0, 40.0, 12.0), 6, C_TEXT)


func _draw_riders(surface, state: Dictionary) -> void:
	var flicker := float(surface.surface_flicker())
	for value in state.get("coin_pusher_riders", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var rider: Dictionary = value
		var lane := int(rider.get("lane", 0))
		var cell := int(rider.get("cell", 0))
		var progress := clampf(float(int(rider.get("push", 0))) / float(_rider_push_threshold()), 0.0, 1.0)
		var bob := sin(flicker * 3.0 + float(lane) * 0.7) * 2.5
		var position := Vector2(105.0 + float(lane) * 103.0, 276.0 - float(cell) * 38.0 + progress * 18.0 + bob)
		surface.draw_circle(position, 8.0, C_HANG)
		surface.draw_circle(position, 5.0, C_COIN)
		surface.surface_label("R:%s" % str(rider.get("label", "prize")).left(9).to_upper(), position + Vector2(10.0, 3.0), 6, C_TEXT)


func _draw_console(surface, state: Dictionary) -> void:
	var panel := Rect2(660, 18, 222, 390)
	surface.draw_rect(panel, Color("#111826"))
	surface.surface_label("QUARTER FALLS", Vector2(678, 48), 14, C_COIN)
	surface.surface_label("Tray $%d" % int(state.get("coin_pusher_tray_value", 0)), Vector2(678, 74), 11, C_TEAL)
	surface.surface_label("Tell: %s" % str(state.get("coin_pusher_tell", "steady")), Vector2(678, 96), 8, C_HANG if int(state.get("coin_pusher_tell_rung", 0)) > 0 else C_TEXT)
	var locked := bool(state.get("coin_pusher_locked", false))
	if locked:
		surface.surface_label("LOCKED TONIGHT", Vector2(678, 128), 13, C_HANG)
		surface.surface_label("Back out. Other games stay open.", Vector2(678, 152), 7, C_TEXT)
		return
	var force_order: Array = state.get("coin_pusher_force_order", _force_order()) if typeof(state.get("coin_pusher_force_order", [])) == TYPE_ARRAY else _force_order()
	for index in range(force_order.size()):
		var rect := Rect2(676 + index * 67, 130, 61, 28)
		var selected := str(state.get("coin_pusher_force", _default_force())) == str(force_order[index])
		surface.draw_rect(rect, C_HANG if selected else C_CASE)
		surface.surface_label_centered(str(force_order[index]).to_upper(), rect, 7, C_BG if selected else C_TEXT)
		surface.surface_add_exact_hit(rect, "coin_pusher_force", index)
	var direction_order: Array = state.get("coin_pusher_direction_order", _direction_order()) if typeof(state.get("coin_pusher_direction_order", [])) == TYPE_ARRAY else _direction_order()
	for index in range(direction_order.size()):
		var rect := Rect2(676 + index * 67, 168, 61, 28)
		var selected := str(state.get("coin_pusher_direction", _default_direction())) == str(direction_order[index])
		surface.draw_rect(rect, C_TEAL if selected else C_CASE)
		surface.surface_label_centered(str(direction_order[index]).to_upper(), rect, 7, C_BG if selected else C_TEXT)
		surface.surface_add_exact_hit(rect, "coin_pusher_direction", index)
	var drop_rect := Rect2(676, 218, 194, 54)
	surface.draw_rect(drop_rect, C_COIN)
	surface.surface_label_centered("DROP $%d" % _drop_cost(), drop_rect, 13, C_BG)
	surface.surface_add_exact_hit(drop_rect, "coin_pusher_drop", 0)
	var nudge_rect := Rect2(676, 282, 194, 54)
	surface.draw_rect(nudge_rect, C_HANG)
	surface.surface_label_centered("NUDGE", nudge_rect, 13, C_BG)
	surface.surface_add_exact_hit(nudge_rect, "coin_pusher_nudge", 0)
	surface.surface_label(str(state.get("coin_pusher_last_message", "")).left(34), Vector2(678, 366), 7, C_TEXT)


func _hanger_count(machine: Dictionary) -> int:
	var count := 0
	for lane in range(_lane_count()):
		if bool(_cell(machine, lane, 0).get("edge_hang", false)):
			count += 1
	return count


func _pile_coin_count(machine: Dictionary) -> int:
	var count := 0
	for lane in range(_lane_count()):
		for cell_index in range(_cell_count()):
			count += int(_cell(machine, lane, cell_index).get("height", 0))
	return count


func _tuning() -> Dictionary:
	var value: Variant = definition.get("coin_pusher_tuning", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _int_tuning(key: String, fallback: int) -> int:
	return int(_tuning().get(key, fallback))


func _string_array_tuning(key: String, fallback: Array) -> Array:
	var source: Variant = _tuning().get(key, [])
	var result: Array = []
	if typeof(source) == TYPE_ARRAY:
		for value in source:
			var text := str(value)
			if not text.is_empty() and not result.has(text):
				result.append(text)
	return result if not result.is_empty() else fallback.duplicate()


func _state_version() -> int:
	return maxi(1, _int_tuning("state_schema_version", 1))


func _variation_id() -> String:
	var authored := str(_tuning().get("variation_id", "quarter_falls"))
	return authored if not authored.is_empty() else "quarter_falls"


func _phase_steps() -> int:
	return maxi(2, _int_tuning("phase_steps", 12))


func _force_order() -> Array:
	return _string_array_tuning("force_order", ["tap", "shove", "slam"])


func _direction_order() -> Array:
	return _string_array_tuning("direction_order", ["left", "right", "front"])


func _default_force() -> String:
	var order := _force_order()
	var authored := str(_tuning().get("default_force", order[0]))
	return authored if order.has(authored) else str(order[0])


func _default_direction() -> String:
	var order := _direction_order()
	var authored := str(_tuning().get("default_direction", order[0]))
	return authored if order.has(authored) else str(order[0])


func _tell_labels() -> Array:
	return _string_array_tuning("tell_labels", ["steady", "cabinet rocks", "alarm chirps", "attendant looks over"])


func _security_band_delta(band: String) -> int:
	var deltas: Dictionary = _tuning().get("security_band_deltas", {}) if typeof(_tuning().get("security_band_deltas", {})) == TYPE_DICTIONARY else {}
	return int(deltas.get(band, 0))


func _force_tolerance_cost(force: String) -> int:
	return maxi(0, int(_force_tuning(force).get("tolerance_cost", 1)))


func _force_push_strength(force: String) -> int:
	return maxi(0, int(_force_tuning(force).get("push_strength", 1)))


func _force_tuning(force: String) -> Dictionary:
	var forces: Dictionary = _tuning().get("nudge_forces", {}) if typeof(_tuning().get("nudge_forces", {})) == TYPE_DICTIONARY else {}
	var value: Variant = forces.get(force, {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _lane_count() -> int:
	return clampi(_int_tuning("lane_count", 5), 3, 7)


func _cell_count() -> int:
	return clampi(_int_tuning("cell_count", 6), 4, 8)


func _cell_capacity() -> int:
	return maxi(2, _int_tuning("cell_capacity", 4))


func _initial_height_min() -> int:
	return maxi(0, _int_tuning("initial_height_min", 2))


func _initial_height_max() -> int:
	return maxi(_initial_height_min(), _int_tuning("initial_height_max", 5))


func _drop_cost() -> int:
	return maxi(1, _int_tuning("drop_cost", 1))


func _coin_value() -> int:
	return maxi(1, _int_tuning("coin_value", 1))


func _upper_phase_step() -> int:
	return maxi(1, _int_tuning("upper_phase_step", 3))


func _lower_phase_step() -> int:
	return maxi(1, _int_tuning("lower_phase_step", 5))


func _clean_nudge_phase() -> int:
	return posmod(_int_tuning("clean_nudge_phase", 3), _phase_steps())


func _clean_window() -> int:
	return clampi(_int_tuning("clean_nudge_window_steps", 1), 0, _phase_steps() / 2)


func _push_chance(phase: int, from_nudge: bool) -> int:
	var base := _int_tuning("nudge_push_percent", 94) if from_nudge else _int_tuning("shelf_push_percent", 78)
	return clampi(base + (_forward_push_bonus() if _phase_is_forward(phase) else -_retracted_push_penalty()), 1, 100)


func _mistimed_push_penalty() -> int:
	return maxi(0, _int_tuning("mistimed_push_penalty", 2))


func _skill_accuracy_base() -> int:
	return clampi(_int_tuning("skill_accuracy_base", 70), 0, 100)


func _skill_accuracy_phase_penalty() -> int:
	return maxi(0, _int_tuning("skill_accuracy_phase_penalty", 12))


func _max_settle_passes() -> int:
	return maxi(1, _int_tuning("max_settle_passes", 6))


func _retracted_stack_threshold_bonus() -> int:
	return maxi(0, _int_tuning("retracted_stack_threshold_bonus", 1))


func _strong_push_threshold() -> int:
	return maxi(1, _int_tuning("strong_push_threshold", 4))


func _strong_push_extra_coins() -> int:
	return maxi(0, _int_tuning("strong_push_extra_coins", 1))


func _front_nudge_lane_radius() -> int:
	return maxi(0, _int_tuning("front_nudge_lane_radius", 1))


func _forward_phase_window() -> int:
	return clampi(_int_tuning("forward_phase_window_steps", 2), 0, _phase_steps() / 2)


func _forward_push_bonus() -> int:
	return maxi(0, _int_tuning("forward_push_bonus_percent", 8))


func _retracted_push_penalty() -> int:
	return maxi(0, _int_tuning("retracted_push_penalty_percent", 10))


func _prize_initial_cell_max() -> int:
	return maxi(1, _int_tuning("prize_initial_cell_max", 3))


func _gutter_edge_percent() -> int:
	return clampi(_int_tuning("gutter_edge_percent", 24), 0, 100)


func _gutter_center_percent() -> int:
	return clampi(_int_tuning("gutter_center_percent", 4), 0, 100)


func _gutter_retracted_bonus() -> int:
	return clampi(_int_tuning("gutter_retracted_bonus_percent", 8), 0, 100)


func _cold_density() -> int:
	return maxi(2, _int_tuning("cold_quarters_density", 3))


func _shim_uses(run_state: RunState = null) -> int:
	var authored := run_state.item_effect_total("coin_pusher_gutter_recovery_uses", "coin_pusher") if run_state != null else 0
	return maxi(1, authored if authored > 0 else _int_tuning("coin_return_shim_uses", 3))


func _slam_bonus_push() -> int:
	return maxi(1, _int_tuning("slam_bonus_push", 2))


func _alarm_heat() -> int:
	return maxi(8, _int_tuning("hard_alarm_heat", 22))


func _watch_suspicion_floor() -> int:
	return maxi(1, _int_tuning("staff_watch_suspicion_floor", 12))


func _attendant_glance_heat() -> int:
	return maxi(1, _int_tuning("attendant_glance_heat", 2))


func _tolerance_min() -> int:
	return maxi(2, _int_tuning("alarm_tolerance_min", 6))


func _tolerance_max() -> int:
	return maxi(_tolerance_min(), _int_tuning("alarm_tolerance_max", 9))


func _rider_push_threshold() -> int:
	return maxi(1, _int_tuning("rider_push_threshold", 2))


func _prize_count_min() -> int:
	return maxi(0, _int_tuning("prize_count_min", 1))


func _prize_count_max() -> int:
	return maxi(_prize_count_min(), _int_tuning("prize_count_max", 3))


func _stable_hash(text: String) -> int:
	var value := 2166136261
	for index in range(text.length()):
		value = int((value ^ text.unicode_at(index)) * 16777619)
	return abs(value) if value != 0 else 1
