class_name SlotGame
extends GameModule

# Deterministic full-simulation slot machine module.

const StateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const GeneratorScript := preload("res://scripts/games/slots/slot_machine_generator.gd")
const ResolverScript := preload("res://scripts/games/slots/slot_resolver.gd")
const PresentationScript := preload("res://scripts/games/slots/slot_presentation.gd")
const RendererScript := preload("res://scripts/games/slots/slot_renderer.gd")
const SELECT_BET_PREFIX := "select_bet_option:"
const SLOT_AUTOPLAY_LOSS_HOLD_MSEC := 100
const SLOT_AUTOPLAY_WIN_HOLD_MSEC := 500
const SLOT_RESULT_REVEAL_BEAT_MSEC := 180
const BUFFALO_AUTOPLAY_MAX_DELAY_MSEC := 10000

var generator
var resolver
var presentation
var renderer


func setup(p_definition: Dictionary, p_library: ContentLibrary = null) -> void:
	super.setup(p_definition, p_library)
	generator = GeneratorScript.new()
	resolver = ResolverScript.new()
	presentation = PresentationScript.new()
	renderer = RendererScript.new()


func gameplay_model() -> String:
	return GameModule.GAMEPLAY_MODEL_FULL_SIMULATION


func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
	_ensure_machine_state(run_state, environment, run_state.create_rng("slot_enter") if run_state != null else null)
	var result: Dictionary = super.enter(run_state, environment)
	var machine: Dictionary = StateScript.read_machine(environment, get_id())
	result["message"] = "%s %s machine waits." % [
		str(machine.get("type_id", "pinball")).capitalize(),
		str(machine.get("format_id", "classic_3_reel")).replace("_", " "),
	]
	return result


func actions(run_state: RunState, environment: Dictionary) -> Dictionary:
	_ensure_machine_state(run_state, environment, run_state.create_rng("slot_actions") if run_state != null else null)
	var machine: Dictionary = StateScript.read_machine(environment, get_id())
	var selected: Dictionary = StateScript.selected_bet(machine)
	var ceiling := run_state.wager_stake_ceiling(maxi(20, run_state.bankroll)) if run_state != null else 20
	return {
		"ok": true,
		"type": "game_actions",
		"game_id": get_id(),
		"legal_actions": legal_actions(run_state, environment),
		"cheat_actions": cheat_actions(run_state, environment),
		"stake_floor": 2,
		"stake_ceiling": maxi(2, ceiling),
		"base_stake_ceiling": maxi(2, ceiling),
		"economy_stake_ceiling": maxi(2, ceiling),
		"economy_state": run_state.economy() if run_state != null else {},
		"economy_pressure_applied": false,
		"selected_stake": int(selected.get("total_credits", 2)),
	}


func legal_actions(_run_state: RunState, _environment: Dictionary) -> Array:
	return _slot_copy_array(definition.get("legal_actions", []))


func cheat_actions(run_state: RunState, environment: Dictionary) -> Array:
	var actions: Array = super.cheat_actions(run_state, environment)
	var machine: Dictionary = StateScript.read_machine(environment, get_id())
	var nudge_ready := not _slot_copy_dict(machine.get("last_nudge_offer", {})).is_empty()
	for i in range(actions.size()):
		if typeof(actions[i]) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = actions[i]
		if str(action.get("id", "")) == "nudge":
			action["summary"] = "Shift the near-miss reel; heat +%d." % int(action.get("suspicion_delta", 12)) if nudge_ready else "Pre-commit a risky nudge; heat +%d." % int(action.get("suspicion_delta", 12))
			actions[i] = action
	return actions


func generate_environment_state(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return generator.generate_machine(run_state, environment, rng, definition, get_id())


func surface_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var machine: Dictionary = _ensure_machine_state(run_state, environment, run_state.create_rng("slot_surface") if run_state != null else null)
	return presentation.surface_state(machine, run_state, definition, ui_state)


func draw_surface(surface_canvas, surface_state: Dictionary, _render_context: Dictionary = {}) -> bool:
	return bool(renderer.draw(surface_canvas, surface_state, definition))


func resolve(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return resolve_with_context(action_id, stake, run_state, environment, rng, {})


func resolve_with_context(action_id: String, _stake: int, run_state: RunState, environment: Dictionary, rng: RngStream, _ui_state: Dictionary = {}) -> Dictionary:
	var machine: Dictionary = _ensure_machine_state(run_state, environment, rng)
	var normalized_action := _normalize_action(action_id)
	if normalized_action.begins_with("slot_bonus_"):
		var bonus_resolved: Dictionary = resolver.resolve_bonus_action(machine, normalized_action, rng, definition, environment, run_state, _slot_cross_game_item_effects(run_state, false), _ui_state)
		var bonus_machine: Dictionary = _slot_copy_dict(bonus_resolved.get("machine", machine))
		if bool(bonus_machine.get("slot_autoplay_active", false)):
			bonus_machine["slot_autoplay_next_msec"] = _slot_autoplay_next_msec(bonus_machine, _ui_state)
		StateScript.write_machine(environment, get_id(), bonus_machine)
		return _slot_copy_dict(bonus_resolved.get("result", {}))
	if normalized_action != "spin" and normalized_action != "nudge":
		return _empty_slot_result(normalized_action, environment, "That slot action is not available.")
	var selected_bet: Dictionary = StateScript.selected_bet(machine)
	var resolved: Dictionary = resolver.resolve_spin(machine, normalized_action, selected_bet, rng, definition, environment, true, false, run_state, _slot_cross_game_item_effects(run_state, normalized_action == "nudge"), _ui_state)
	var resolved_machine: Dictionary = _slot_copy_dict(resolved.get("machine", machine))
	if bool(resolved_machine.get("slot_autoplay_active", false)):
		resolved_machine["slot_autoplay_next_msec"] = _slot_autoplay_next_msec(resolved_machine, _ui_state)
	StateScript.write_machine(environment, get_id(), resolved_machine)
	return _slot_copy_dict(resolved.get("result", {}))


func wager_cost_for_context(action_id: String, _stake: int, run_state: RunState, environment: Dictionary, _ui_state: Dictionary = {}) -> int:
	var normalized_action := _normalize_action(action_id)
	if normalized_action.begins_with("slot_bonus_") or normalized_action == "slot_bet" or normalized_action == "slot_auto_toggle":
		return 0
	var machine: Dictionary = _ensure_machine_state(run_state, environment, run_state.create_rng("slot_cost") if run_state != null else null)
	var selected: Dictionary = StateScript.selected_bet(machine)
	if normalized_action == "nudge" and not _slot_copy_dict(machine.get("last_nudge_offer", {})).is_empty():
		return 0
	if normalized_action == "spin" and int(machine.get("free_spins", 0)) > 0:
		return 0
	return maxi(0, int(selected.get("total_credits", 2)))


func surface_action_command(surface_action: String, index: int, confirm_requested: bool, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine: Dictionary = _ensure_machine_state(run_state, environment, run_state.create_rng("slot_surface_action") if run_state != null else null)
	if surface_action.begins_with(SELECT_BET_PREFIX):
		var bet_id := surface_action.substr(SELECT_BET_PREFIX.length())
		machine = StateScript.set_selected_bet(machine, bet_id)
		StateScript.write_machine(environment, get_id(), machine)
		return GameModule.surface_command({
			"handled": true,
			"environment_changed": true,
			"selected_index": index,
			"set_stake": int(StateScript.selected_bet(machine).get("total_credits", 2)),
			"message": "Bet set to $%d." % int(StateScript.selected_bet(machine).get("total_credits", 2)),
		})
	if _is_pinball_direct_bonus_action(surface_action):
		return GameModule.surface_command({
			"handled": true,
			"action_id": surface_action,
			"action_kind": "bonus",
			"direct_resolve": true,
			"skip_stake_validation": true,
			"preserve_surface_ui_state": true,
			"selected_index": index,
			"message": "Bonus input.",
		})
	match surface_action:
		"spin", "slot_spin":
			return GameModule.surface_command({
				"handled": true,
				"action_id": "spin",
				"action_kind": "legal",
				"resolve": confirm_requested or str(ui_state.get("selected_action_id", "")) == "spin",
				"selected_index": index,
				"set_stake": int(StateScript.selected_bet(machine).get("total_credits", 2)),
				"message": "Spin selected.",
			})
		"nudge", "slot_nudge":
			var nudge_ready := not _slot_copy_dict(machine.get("last_nudge_offer", {})).is_empty()
			return GameModule.surface_command({
				"handled": true,
				"action_id": "nudge",
				"action_kind": "cheat",
				"direct_resolve": nudge_ready,
				"resolve": nudge_ready or confirm_requested or str(ui_state.get("selected_action_id", "")) == "nudge",
				"selected_index": index,
				"set_stake": int(StateScript.selected_bet(machine).get("total_credits", 2)),
				"message": "Nudge selected.",
			})
		"slot_bet":
			machine = StateScript.set_selected_bet_by_index(machine, index)
			StateScript.write_machine(environment, get_id(), machine)
			return GameModule.surface_command({
				"handled": true,
				"environment_changed": true,
				"selected_index": index,
				"set_stake": int(StateScript.selected_bet(machine).get("total_credits", 2)),
				"message": "Bet set to $%d." % int(StateScript.selected_bet(machine).get("total_credits", 2)),
			})
		"slot_auto_toggle":
			machine["slot_autoplay_active"] = not bool(machine.get("slot_autoplay_active", false))
			StateScript.write_machine(environment, get_id(), machine)
			return GameModule.surface_command({
				"handled": true,
				"environment_changed": true,
				"message": "Autoplay on." if bool(machine.get("slot_autoplay_active", false)) else "Autoplay off.",
			})
		"launch", "left", "right", "soft", "hard", "power_down", "power_up", "tilt", "tick", "slot_bonus_launch", "slot_bonus_left", "slot_bonus_right", "slot_bonus_power_down", "slot_bonus_power_up", "slot_bonus_soft", "slot_bonus_hard", "slot_bonus_tilt", "slot_bonus_tick":
			return GameModule.surface_command({
				"handled": true,
				"action_id": _normalize_bonus_action(surface_action),
				"action_kind": "bonus",
				"direct_resolve": true,
				"skip_stake_validation": true,
				"preserve_surface_ui_state": true,
				"selected_index": index,
				"message": "Bonus input.",
			})
	return {"handled": false}


func surface_needs_auto_tick(ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> bool:
	var machine: Dictionary = StateScript.read_machine(environment, get_id())
	var pinball_time := _pinball_surface_timing_msec(ui_state)
	if _pinball_bonus_runtime_tick_due(machine, pinball_time):
		return true
	var surface_time := _surface_timing_msec(ui_state)
	if machine.is_empty() or not bool(machine.get("slot_autoplay_active", false)):
		return false
	var next_msec := int(machine.get("slot_autoplay_next_msec", 0))
	return surface_time <= 0 or next_msec <= 0 or surface_time >= next_msec


func surface_auto_action_command(ui_state: Dictionary, _run_state: RunState, environment: Dictionary, _surface_status: Dictionary = {}) -> Dictionary:
	var machine: Dictionary = StateScript.read_machine(environment, get_id())
	if machine.is_empty():
		return {"handled": false}
	var surface_time := _surface_timing_msec(ui_state)
	var pinball_time := _pinball_surface_timing_msec(ui_state)
	if _pinball_bonus_runtime_tick_due(machine, pinball_time):
		machine["slot_pinball_next_tick_msec"] = pinball_time + _slot_pinball_tick_interval_msec(machine)
		StateScript.write_machine(environment, get_id(), machine)
		return GameModule.surface_command({
			"handled": true,
			"action_id": "slot_bonus_tick",
			"action_kind": "bonus",
			"direct_resolve": true,
			"skip_stake_validation": true,
			"preserve_surface_ui_state": true,
			"message": "Pinball physics tick.",
		})
	if StateScript.active_bonus_incomplete(machine):
		if _slot_active_bonus_family(machine) == "pinball":
			machine["slot_autoplay_active"] = false
			machine["slot_autoplay_next_msec"] = 0
			StateScript.write_machine(environment, get_id(), machine)
			return GameModule.surface_command({
				"handled": true,
				"environment_changed": true,
				"message": "Autoplay paused for pinball.",
			})
		machine["slot_autoplay_next_msec"] = surface_time + _slot_autoplay_delay_msec(machine)
		StateScript.write_machine(environment, get_id(), machine)
		return GameModule.surface_command({
			"handled": true,
			"action_id": "slot_bonus_launch",
			"action_kind": "bonus",
			"direct_resolve": true,
			"skip_stake_validation": true,
			"preserve_surface_ui_state": true,
			"message": "Autoplay bonus step.",
		})
	return GameModule.surface_command({
		"handled": true,
		"action_id": "spin",
		"action_kind": "legal",
		"direct_resolve": true,
		"ui_state": {
			"surface_time_msec": int(ui_state.get("surface_time_msec", surface_time)),
			"drunk_scaled_surface_time_msec": surface_time,
		},
		"set_stake": int(StateScript.selected_bet(machine).get("total_credits", 2)),
		"message": "Autoplay spin.",
	})


func environment_runtime_needs_tick(_run_state: RunState, environment: Dictionary, now_msec: int) -> bool:
	var machine: Dictionary = StateScript.read_machine(environment, get_id())
	if machine.is_empty() or not bool(machine.get("slot_autoplay_active", false)):
		return false
	var next_msec := int(machine.get("slot_autoplay_next_msec", 0))
	return next_msec <= 0 or now_msec >= next_msec


func environment_runtime_tick(run_state: RunState, environment: Dictionary, rng: RngStream, now_msec: int) -> Dictionary:
	var machine: Dictionary = _ensure_machine_state(run_state, environment, rng)
	if machine.is_empty() or not bool(machine.get("slot_autoplay_active", false)):
		return {"handled": false}
	if StateScript.active_bonus_incomplete(machine):
		if _slot_active_bonus_family(machine) == "pinball" and not _pinball_bonus_runtime_tick_due(machine, now_msec):
			machine["slot_autoplay_active"] = false
			machine["slot_autoplay_next_msec"] = 0
			StateScript.write_machine(environment, get_id(), machine)
			return {
				"handled": true,
				"message": "Autoplay paused for pinball.",
			}
		var bonus_action := "slot_bonus_tick" if _pinball_bonus_runtime_tick_due(machine, now_msec) else "slot_bonus_launch"
		var bonus_resolved: Dictionary = resolver.resolve_bonus_action(machine, bonus_action, rng, definition, environment, run_state, _slot_cross_game_item_effects(run_state, false))
		var bonus_machine: Dictionary = _slot_copy_dict(bonus_resolved.get("machine", machine))
		bonus_machine["slot_autoplay_active"] = true
		if bonus_action == "slot_bonus_tick":
			bonus_machine["slot_pinball_next_tick_msec"] = now_msec + _slot_pinball_tick_interval_msec(bonus_machine)
		bonus_machine["slot_autoplay_next_msec"] = now_msec + (_slot_pinball_tick_interval_msec(bonus_machine) if bonus_action == "slot_bonus_tick" else _slot_autoplay_delay_msec(bonus_machine))
		StateScript.write_machine(environment, get_id(), bonus_machine)
		return {
			"handled": true,
			"result": _slot_copy_dict(bonus_resolved.get("result", {})),
			"message": "Autoplay bonus step.",
		}
	machine["slot_autoplay_next_msec"] = now_msec + _slot_autoplay_delay_msec(machine)
	StateScript.write_machine(environment, get_id(), machine)
	var selected_bet: Dictionary = StateScript.selected_bet(machine)
	var resolved: Dictionary = resolver.resolve_spin(machine, "spin", selected_bet, rng, definition, environment, true, false, run_state, _slot_cross_game_item_effects(run_state, false))
	var resolved_machine: Dictionary = _slot_copy_dict(resolved.get("machine", machine))
	resolved_machine["slot_autoplay_active"] = true
	resolved_machine["slot_autoplay_next_msec"] = now_msec + _slot_autoplay_delay_msec(resolved_machine)
	StateScript.write_machine(environment, get_id(), resolved_machine)
	return {
		"handled": true,
		"result": _slot_copy_dict(resolved.get("result", {})),
		"message": "Autoplay spin.",
	}


func environment_runtime_state(_run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine: Dictionary = StateScript.read_machine(environment, get_id())
	if machine.is_empty():
		return {}
	return {
		"active": bool(machine.get("slot_autoplay_active", false)) or StateScript.active_bonus_incomplete(machine),
		"status_label": "AUTO" if bool(machine.get("slot_autoplay_active", false)) else "BONUS" if StateScript.active_bonus_incomplete(machine) else "",
		"status_summary": "Slot spins %d, coin in $%d, coin out $%d." % [int(machine.get("spin_count", 0)), int(machine.get("coin_in", 0)), int(machine.get("coin_out", 0))],
		"spin_count": int(machine.get("spin_count", 0)),
		"slot_autoplay_active": bool(machine.get("slot_autoplay_active", false)),
	}


func environment_object_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var runtime := environment_runtime_state(run_state, environment)
	if runtime.is_empty():
		return {}
	return {
		"status_summary": str(runtime.get("status_summary", "")),
		"state_badge": str(runtime.get("status_label", "")),
		"runtime_state": runtime,
		"visual_state": {
			"machine_family": str(StateScript.read_machine(environment, get_id()).get("type_id", "slot")),
			"machine_key": str(StateScript.read_machine(environment, get_id()).get("machine_key", "")),
		},
	}


func _ensure_machine_state(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var machine: Dictionary = StateScript.read_machine(environment, get_id())
	if machine.is_empty():
		var generation_rng: RngStream = rng
		if generation_rng == null and run_state != null:
			generation_rng = run_state.create_rng("slot_generate")
		if generation_rng == null:
			generation_rng = RngStream.new()
			generation_rng.configure(1)
		machine = generator.generate_machine(run_state, environment, generation_rng, definition, get_id())
		StateScript.write_machine(environment, get_id(), machine)
	else:
		machine = StateScript.normalize(machine)
		StateScript.write_machine(environment, get_id(), machine)
	return machine


func _empty_slot_result(action_id: String, environment: Dictionary, text: String) -> Dictionary:
	return GameModule.build_action_result({
		"ok": false,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": "unknown",
		"stake": 0,
		"environment_id": str(environment.get("id", "")),
		"message": text,
	})


func _normalize_action(action_id: String) -> String:
	match action_id:
		"slot_spin", "spin":
			return "spin"
		"slot_nudge", "nudge":
			return "nudge"
		_:
			return action_id


func _normalize_bonus_action(action_id: String) -> String:
	match action_id:
		"launch":
			return "slot_bonus_launch"
		"left":
			return "slot_bonus_left"
		"right":
			return "slot_bonus_right"
		"power_down", "soft", "slot_bonus_soft":
			return "slot_bonus_power_down"
		"power_up", "hard", "slot_bonus_hard":
			return "slot_bonus_power_up"
		"tilt":
			return "slot_bonus_tilt"
		"tick":
			return "slot_bonus_tick"
		_:
			return action_id


func _is_pinball_direct_bonus_action(action_id: String) -> bool:
	return action_id.begins_with("slot_bonus_aim_") or action_id.begins_with("slot_bonus_start_") or action_id.begins_with("slot_bonus_power_")


func _slot_autoplay_delay_msec(machine: Dictionary) -> int:
	var plan: Dictionary = _slot_copy_dict(machine.get("slot_animation_plan", {}))
	var delay := 0
	if not StateScript.active_bonus_incomplete(machine) and not str(machine.get("slot_animation_id", "")).begins_with("bonus:") and not _slot_copy_array(plan.get("reel_timeline", [])).is_empty():
		delay = _slot_spin_reveal_msec(plan) + _slot_autoplay_outcome_hold_msec(machine)
	else:
		delay = _slot_legacy_autoplay_delay_msec(machine)
	if _slot_active_bonus_family(machine) == "buffalo" or str(machine.get("type_id", "")) == "buffalo":
		delay = mini(delay, BUFFALO_AUTOPLAY_MAX_DELAY_MSEC)
	return delay


func _slot_legacy_autoplay_delay_msec(machine: Dictionary) -> int:
	var plan: Dictionary = _slot_copy_dict(machine.get("slot_animation_plan", {}))
	var duration := maxi(0, int(machine.get("slot_animation_duration_msec", 0)))
	duration = maxi(duration, int(plan.get("duration_msec", 0)))
	duration = maxi(duration, int(plan.get("feature_duration_msec", 0)))
	duration = maxi(duration, int(plan.get("count_up_end_msec", 0)))
	duration = maxi(duration, int(plan.get("celebration_start_msec", 0)) + int(plan.get("celebration_duration_msec", 0)))
	for entry_value in _slot_copy_array(plan.get("reel_timeline", [])):
		var entry: Dictionary = _slot_copy_dict(entry_value)
		duration = maxi(duration, int(ceil(float(entry.get("settle_end", 0.0)) * 1000.0)))
	return maxi(900, duration + 120)


func _slot_spin_reveal_msec(plan: Dictionary) -> int:
	var reveal_msec := 0
	for entry_value in _slot_copy_array(plan.get("reel_timeline", [])):
		var entry: Dictionary = _slot_copy_dict(entry_value)
		reveal_msec = maxi(reveal_msec, int(ceil(float(entry.get("settle_end", entry.get("stop_time", 0.0))) * 1000.0)))
	return reveal_msec + SLOT_RESULT_REVEAL_BEAT_MSEC


func _slot_autoplay_outcome_hold_msec(machine: Dictionary) -> int:
	if int(machine.get("last_payout", 0)) > 0:
		return SLOT_AUTOPLAY_WIN_HOLD_MSEC
	if str(machine.get("last_classification", "")) == "near_miss":
		return SLOT_AUTOPLAY_WIN_HOLD_MSEC
	if str(machine.get("slot_celebration_tier", "none")) != "none":
		return SLOT_AUTOPLAY_WIN_HOLD_MSEC
	return SLOT_AUTOPLAY_LOSS_HOLD_MSEC


func _slot_autoplay_next_msec(machine: Dictionary, ui_state: Dictionary) -> int:
	var base_msec := _surface_timing_msec(ui_state)
	if base_msec <= 0:
		base_msec = Time.get_ticks_msec()
	return base_msec + _slot_autoplay_delay_msec(machine)


func _surface_timing_msec(ui_state: Dictionary) -> int:
	return maxi(0, int(ui_state.get("drunk_scaled_surface_time_msec", ui_state.get("surface_time_msec", 0))))


func _pinball_surface_timing_msec(ui_state: Dictionary) -> int:
	return maxi(0, int(ui_state.get("surface_time_msec", _surface_timing_msec(ui_state))))


func _pinball_bonus_runtime_tick_due(machine: Dictionary, surface_time_msec: int) -> bool:
	if machine.is_empty():
		return false
	var active: Dictionary = _slot_copy_dict(machine.get("active_bonus", {}))
	if str(active.get("family", machine.get("type_id", ""))) != "pinball":
		return false
	if not bool(active.get("active", false)) or bool(active.get("complete", false)):
		return false
	if not bool(active.get("launch_in_progress", false)):
		return false
	var next_msec := int(machine.get("slot_pinball_next_tick_msec", 0))
	if surface_time_msec <= 0:
		return next_msec <= 0
	return next_msec <= 0 or surface_time_msec >= next_msec


func _slot_active_bonus_family(machine: Dictionary) -> String:
	var active: Dictionary = _slot_copy_dict(machine.get("active_bonus", {}))
	return str(active.get("family", machine.get("type_id", "")))


func _slot_pinball_tick_interval_msec(machine: Dictionary) -> int:
	var active: Dictionary = _slot_copy_dict(machine.get("active_bonus", {}))
	if str(active.get("family", machine.get("type_id", ""))) != "pinball":
		return 16
	return 16


func _slot_cross_game_item_effects(run_state: RunState, is_cheat: bool) -> Dictionary:
	if run_state == null:
		return {}
	return {
		"win_bonus": _item_bonus("win_bonus", run_state, is_cheat),
		"payout_delta": _item_bonus("payout_delta", run_state, is_cheat),
		"loss_reduction": _item_bonus("loss_reduction", run_state, is_cheat),
		"cheat_suspicion_delta": _item_bonus("cheat_suspicion_delta", run_state, true),
	}


func _slot_copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _slot_copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
