class_name SlotGame
extends GameModule

# Deterministic full-simulation slot machine module.

const StateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const CatalogScript := preload("res://scripts/games/slots/slot_catalog.gd")
const GeneratorScript := preload("res://scripts/games/slots/slot_machine_generator.gd")
const ResolverScript := preload("res://scripts/games/slots/slot_resolver.gd")
const PresentationScript := preload("res://scripts/games/slots/slot_presentation.gd")
const RendererScript := preload("res://scripts/games/slots/slot_renderer.gd")
const SELECT_BET_PREFIX := "select_bet_option:"
const SLOT_AUTOPLAY_LOSS_HOLD_MSEC := 100
const SLOT_AUTOPLAY_WIN_HOLD_MSEC := 500
const SLOT_RESULT_REVEAL_BEAT_MSEC := 180
const BUFFALO_AUTOPLAY_MAX_DELAY_MSEC := 10000
const SLOT_ENV_PREVIEW_MAX_REELS := 6
const SLOT_ENV_PREVIEW_MAX_ROWS := 4
const LUCKY_REEL_GREASE_ITEM_ID := "lucky_reel_grease"
const COLD_QUARTERS_ITEM_ID := "cold_quarters"
const SPLIT_REEL_NOTE_ITEM_ID := "split_reel_note"

var generator
var resolver
var presentation
var renderer
var catalog


func setup(p_definition: Dictionary, p_library: ContentLibrary = null) -> void:
	super.setup(p_definition, p_library)
	generator = GeneratorScript.new()
	resolver = ResolverScript.new()
	presentation = PresentationScript.new()
	renderer = RendererScript.new()
	catalog = CatalogScript.new()


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
			action["summary"] = "Time the coin chain; heat +%d per nudge." % int(action.get("suspicion_delta", 12)) if nudge_ready else "Watch for a coin-chain tease; heat +%d." % int(action.get("suspicion_delta", 12))
			actions[i] = action
	return actions


func generate_environment_state(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return generator.generate_machine(run_state, environment, rng, definition, get_id())


func active_item_command(item_id: String, run_state: RunState, environment: Dictionary, _rng: RngStream) -> Dictionary:
	var machine: Dictionary = _ensure_machine_state(run_state, environment, run_state.create_rng("slot_active_item") if run_state != null else null)
	match item_id:
		LUCKY_REEL_GREASE_ITEM_ID:
			return _arm_lucky_reel_grease(machine, environment)
		COLD_QUARTERS_ITEM_ID:
			return _load_cold_quarters(machine, environment)
		SPLIT_REEL_NOTE_ITEM_ID:
			return _arm_split_reel_note(machine, run_state, environment)
	return {"handled": false}


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
		var bonus_resolved: Dictionary = resolver.resolve_bonus_action(machine, normalized_action, rng, definition, environment, run_state, _slot_cross_game_item_effects(run_state, machine, false), _ui_state)
		var bonus_machine: Dictionary = _slot_copy_dict(bonus_resolved.get("machine", machine))
		if bool(bonus_machine.get("slot_autoplay_active", false)):
			bonus_machine["slot_autoplay_next_msec"] = _slot_autoplay_next_msec(bonus_machine, _ui_state)
		if _buffalo_bonus_auto_action(bonus_machine).is_empty():
			bonus_machine.erase("slot_bonus_auto_next_msec")
		else:
			bonus_machine["slot_bonus_auto_next_msec"] = _slot_bonus_auto_next_msec(bonus_machine, _ui_state)
		StateScript.write_machine(environment, get_id(), bonus_machine)
		return _slot_copy_dict(bonus_resolved.get("result", {}))
	if normalized_action != "spin" and normalized_action != "nudge":
		return _empty_slot_result(normalized_action, environment, "That slot action is not available.")
	var selected_bet: Dictionary = StateScript.selected_bet(machine)
	var resolved: Dictionary = resolver.resolve_spin(machine, normalized_action, selected_bet, rng, definition, environment, true, false, run_state, _slot_cross_game_item_effects(run_state, machine, normalized_action == "nudge"), _ui_state)
	var resolved_machine: Dictionary = _slot_copy_dict(resolved.get("machine", machine))
	if _slot_feature_pending(resolved_machine):
		resolved_machine = _mark_slot_feature_pending(resolved_machine, Time.get_ticks_msec())
	elif bool(resolved_machine.get("slot_autoplay_active", false)):
		resolved_machine["slot_autoplay_next_msec"] = _slot_autoplay_next_msec(resolved_machine, _ui_state)
	if _buffalo_bonus_auto_action(resolved_machine).is_empty():
		resolved_machine.erase("slot_bonus_auto_next_msec")
	else:
		resolved_machine["slot_bonus_auto_next_msec"] = _slot_bonus_auto_next_msec(resolved_machine, _ui_state)
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
				"message": "Coin-chain nudge selected." if nudge_ready else "Nudge selected.",
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
	var buffalo_bonus_action := _buffalo_bonus_auto_action(machine)
	if not buffalo_bonus_action.is_empty():
		var bonus_surface_time := _surface_timing_msec(ui_state)
		var next_msec := int(machine.get("slot_bonus_auto_next_msec", 0))
		return bonus_surface_time <= 0 or next_msec <= 0 or bonus_surface_time >= next_msec
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
	var buffalo_bonus_action := _buffalo_bonus_auto_action(machine)
	if not buffalo_bonus_action.is_empty():
		if surface_time <= 0:
			surface_time = Time.get_ticks_msec()
		var next_msec := int(machine.get("slot_bonus_auto_next_msec", 0))
		if next_msec <= 0:
			machine["slot_bonus_auto_next_msec"] = surface_time + _slot_bonus_auto_delay_msec(machine)
			StateScript.write_machine(environment, get_id(), machine)
			return GameModule.surface_command({
				"handled": true,
				"environment_changed": true,
				"message": "Buffalo feature reels are winding up.",
			})
		if surface_time < next_msec:
			return {"handled": false}
		return GameModule.surface_command({
			"handled": true,
			"action_id": buffalo_bonus_action,
			"action_kind": "bonus",
			"direct_resolve": true,
			"skip_stake_validation": true,
			"preserve_surface_ui_state": true,
			"ui_state": {
				"surface_time_msec": int(ui_state.get("surface_time_msec", surface_time)),
				"drunk_scaled_surface_time_msec": surface_time,
			},
			"message": "Buffalo feature auto spin.",
		})
	if StateScript.active_bonus_incomplete(machine):
		var paused_family := _slot_active_bonus_family(machine)
		machine["slot_autoplay_active"] = false
		machine["slot_autoplay_next_msec"] = 0
		StateScript.write_machine(environment, get_id(), machine)
		return GameModule.surface_command({
			"handled": true,
			"environment_changed": true,
			"message": "Autoplay paused for %s bonus." % paused_family.capitalize(),
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


func surface_pause_repeating_action_for_confirmation(_ui_state: Dictionary, _run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine: Dictionary = StateScript.read_machine(environment, get_id())
	if machine.is_empty() or not bool(machine.get("slot_autoplay_active", false)):
		return {"handled": false}
	machine["slot_autoplay_active"] = false
	machine["slot_autoplay_next_msec"] = 0
	StateScript.write_machine(environment, get_id(), machine)
	return GameModule.surface_command({
		"handled": true,
		"environment_changed": true,
		"message": "Autoplay paused for all-in confirmation.",
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
		var paused_family := _slot_active_bonus_family(machine)
		machine = _mark_slot_feature_pending(machine, now_msec)
		StateScript.write_machine(environment, get_id(), machine)
		return {
			"handled": true,
			"message": "Autoplay paused for %s bonus." % paused_family.capitalize(),
			"attention": true,
			"audio_cue": _slot_feature_audio_cue(machine),
		}
	machine["slot_autoplay_next_msec"] = now_msec + _slot_autoplay_delay_msec(machine)
	StateScript.write_machine(environment, get_id(), machine)
	var selected_bet: Dictionary = StateScript.selected_bet(machine)
	var resolved: Dictionary = resolver.resolve_spin(machine, "spin", selected_bet, rng, definition, environment, true, false, run_state, _slot_cross_game_item_effects(run_state, machine, false))
	var resolved_machine: Dictionary = _slot_copy_dict(resolved.get("machine", machine))
	var feature_pending := _slot_feature_pending(resolved_machine)
	if feature_pending:
		resolved_machine = _mark_slot_feature_pending(resolved_machine, now_msec)
	else:
		resolved_machine["slot_autoplay_active"] = true
		resolved_machine["slot_autoplay_next_msec"] = now_msec + _slot_autoplay_delay_msec(resolved_machine)
	StateScript.write_machine(environment, get_id(), resolved_machine)
	var result: Dictionary = _slot_copy_dict(resolved.get("result", {}))
	if feature_pending:
		result["slot_pending_feature"] = true
	return {
		"handled": true,
		"result": result,
		"message": "Slot feature ready. Open the machine to play it.",
		"attention": feature_pending,
		"audio_cue": _slot_feature_audio_cue(resolved_machine) if feature_pending else "",
	}


func environment_runtime_state(_run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine: Dictionary = StateScript.read_machine(environment, get_id())
	if machine.is_empty():
		return {}
	return _slot_environment_runtime_state_for_machine(machine)


func environment_object_state(_run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine: Dictionary = StateScript.read_machine(environment, get_id())
	if machine.is_empty():
		return {}
	var preview := _slot_environment_preview(machine)
	var runtime := _slot_environment_runtime_state_for_machine(machine, preview)
	return {
		"status_summary": str(runtime.get("status_summary", "")),
		"state_badge": str(runtime.get("status_label", "")),
		"runtime_state": runtime,
		"visual_state": _slot_environment_visual_state(machine, preview),
	}


func _slot_environment_runtime_state_for_machine(machine: Dictionary, preview: Dictionary = {}, now_msec: int = -1) -> Dictionary:
	var active_bonus: Dictionary = _slot_copy_dict(machine.get("active_bonus", {}))
	var nudge_offer: Dictionary = _slot_copy_dict(machine.get("last_nudge_offer", {}))
	var bonus_preview: Dictionary = _slot_copy_dict(preview.get("bonus", {}))
	var nudge_preview: Dictionary = _slot_copy_dict(preview.get("nudge_chain", {}))
	var phase := str(preview.get("phase", ""))
	if phase.is_empty():
		if now_msec < 0:
			now_msec = Time.get_ticks_msec()
		phase = _slot_runtime_phase(machine, active_bonus, nudge_offer, now_msec)
	var bonus_active := bool(bonus_preview.get("active", bool(active_bonus.get("active", false)) and not bool(active_bonus.get("complete", false))))
	var nudge_chain_active := bool(nudge_preview.get("active", not nudge_offer.is_empty() and str(nudge_offer.get("type", "")) == "coin_chain"))
	var active := bool(preview.get("active", _slot_preview_active(machine, active_bonus, nudge_offer, phase)))
	var caption := str(preview.get("caption", _slot_preview_caption(phase, machine, active_bonus, nudge_offer)))
	return {
		"active": active,
		"status_label": str(preview.get("status_label", _slot_preview_status_label(phase, machine, active_bonus, nudge_offer))),
		"status_summary": "Slot spins %d, coin in $%d, coin out $%d." % [int(machine.get("spin_count", 0)), int(machine.get("coin_in", 0)), int(machine.get("coin_out", 0))],
		"spin_count": int(machine.get("spin_count", 0)),
		"slot_autoplay_active": bool(machine.get("slot_autoplay_active", false)),
		"slot_bonus_active": bonus_active,
		"slot_pending_feature": bool(preview.get("pending_feature", bonus_active)),
		"slot_pending_feature_alert": bool(machine.get("slot_pending_feature_alert", false)),
		"slot_bonus_family": str(bonus_preview.get("family", active_bonus.get("family", ""))),
		"slot_feature_audio_cue": _slot_feature_audio_cue(machine) if bool(preview.get("pending_feature", bonus_active)) else "",
		"slot_free_spins": int(machine.get("free_spins", 0)),
		"slot_last_payout": int(machine.get("last_payout", 0)),
		"slot_last_classification": str(machine.get("last_classification", "idle")),
		"slot_preview_phase": phase,
		"slot_preview_caption": caption,
		"slot_nudge_chain_active": nudge_chain_active,
	}


func _slot_environment_visual_state(machine: Dictionary, preview: Dictionary = {}) -> Dictionary:
	var skin: Dictionary = {}
	var environment_catalog = catalog
	if environment_catalog == null:
		environment_catalog = CatalogScript.new()
	if environment_catalog != null:
		skin = environment_catalog.skin_for_machine(machine, definition)
	var active_bonus: Dictionary = _slot_copy_dict(machine.get("active_bonus", {}))
	var resolved_preview := preview
	if resolved_preview.is_empty():
		resolved_preview = _slot_environment_preview(machine)
	return {
		"machine_family": str(machine.get("type_id", "slot")),
		"machine_format": str(machine.get("format_id", "")),
		"machine_key": str(machine.get("machine_key", "")),
		"cabinet_variant_id": str(machine.get("cabinet_variant_id", "")),
		"cabinet_identity": str(skin.get("cabinet_identity", "")),
		"cabinet_title": str(skin.get("cabinet_title", "")),
		"cabinet_material": str(skin.get("material", "")),
		"cabinet_topper_style": str(skin.get("topper_style", "")),
		"cabinet_motion_style": str(skin.get("motion_style", "")),
		"cabinet_background_path": str(skin.get("background_path", "")),
		"feature_name": str(skin.get("feature_name", "")),
		"pay_model": str(skin.get("pay_model", "")),
		"reel_count": int(skin.get("reel_count", machine.get("reel_count", 3))),
		"row_count": int(skin.get("row_count", machine.get("row_count", 1))),
		"last_classification": str(machine.get("last_classification", "idle")),
		"last_payout": int(machine.get("last_payout", 0)),
		"free_spins": int(machine.get("free_spins", 0)),
		"active_bonus_family": str(active_bonus.get("family", "")),
		"slot_preview": resolved_preview,
	}


func _slot_environment_preview(machine: Dictionary, now_msec: int = -1) -> Dictionary:
	if now_msec < 0:
		now_msec = Time.get_ticks_msec()
	var reel_count := clampi(int(machine.get("reel_count", 3)), 1, SLOT_ENV_PREVIEW_MAX_REELS)
	var row_count := clampi(int(machine.get("row_count", 1)), 1, SLOT_ENV_PREVIEW_MAX_ROWS)
	var active_bonus: Dictionary = _slot_copy_dict(machine.get("active_bonus", {}))
	var nudge_offer: Dictionary = _slot_copy_dict(machine.get("last_nudge_offer", {}))
	var selected_bet: Dictionary = StateScript.selected_bet(machine)
	var spin_plan: Dictionary = _slot_copy_dict(machine.get("slot_animation_plan", {}))
	var autoplay_delay := _slot_autoplay_delay_msec(machine) if bool(machine.get("slot_autoplay_active", false)) else 0
	var phase := _slot_preview_phase(machine, active_bonus, nudge_offer, now_msec, autoplay_delay, spin_plan)
	var autoplay_next := maxi(0, int(machine.get("slot_autoplay_next_msec", 0)))
	var remaining := maxi(0, autoplay_next - now_msec) if autoplay_next > 0 else 0
	var elapsed := maxi(0, autoplay_delay - remaining) if autoplay_delay > 0 else 0
	var preview := {
		"schema_version": 1,
		"active": _slot_preview_active(machine, active_bonus, nudge_offer, phase),
		"phase": phase,
		"status_label": _slot_preview_status_label(phase, machine, active_bonus, nudge_offer),
		"caption": _slot_preview_caption(phase, machine, active_bonus, nudge_offer),
		"family": str(machine.get("type_id", "slot")),
		"format_id": str(machine.get("format_id", "")),
		"machine_key": str(machine.get("machine_key", "")),
		"reel_count": reel_count,
		"row_count": row_count,
		"grid": _slot_preview_grid(machine.get("last_grid", []), reel_count, row_count),
		"previous_grid": _slot_preview_grid(machine.get("last_previous_grid", []), reel_count, row_count),
		"win_cells": _slot_preview_cells(machine.get("slot_win_cells", [])),
		"win_symbol": str(machine.get("slot_win_symbol", "")),
		"win_reason": str(machine.get("slot_win_reason", "")),
		"payout": maxi(0, int(machine.get("last_payout", 0))),
		"net": int(machine.get("last_net", 0)),
		"classification": str(machine.get("last_classification", "idle")),
		"celebration_tier": str(machine.get("slot_celebration_tier", "none")),
		"spin_count": maxi(0, int(machine.get("spin_count", 0))),
		"selected_bet": int(selected_bet.get("total_credits", 2)),
		"autoplay_active": bool(machine.get("slot_autoplay_active", false)),
		"pending_feature": bool(active_bonus.get("active", false)) and not bool(active_bonus.get("complete", false)),
		"pending_feature_alert": bool(machine.get("slot_pending_feature_alert", false)),
		"autoplay_next_msec": autoplay_next,
		"autoplay_delay_msec": autoplay_delay,
		"autoplay_remaining_msec": remaining,
		"preview_elapsed_msec": elapsed,
		"spin": {
			"animation_id": str(machine.get("slot_animation_id", "")),
			"duration_msec": maxi(0, int(machine.get("slot_animation_duration_msec", 0))),
			"timeline": _slot_preview_timeline(machine.get("slot_reel_timeline", spin_plan.get("reel_timeline", []))),
		},
		"bonus": _slot_preview_bonus(machine, active_bonus),
		"nudge_chain": _slot_preview_nudge_chain(nudge_offer),
	}
	return preview


func _slot_runtime_phase(machine: Dictionary, active_bonus: Dictionary, nudge_offer: Dictionary, now_msec: int) -> String:
	if not nudge_offer.is_empty():
		return "nudge_chain" if str(nudge_offer.get("type", "")) == "coin_chain" else "nudge"
	if bool(active_bonus.get("active", false)) and not bool(active_bonus.get("complete", false)):
		return "bonus"
	var classification := str(machine.get("last_classification", "idle"))
	if bool(machine.get("slot_autoplay_active", false)):
		var animation_id := str(machine.get("slot_animation_id", ""))
		var autoplay_next := int(machine.get("slot_autoplay_next_msec", 0))
		var remaining := maxi(0, autoplay_next - now_msec) if autoplay_next > 0 else 0
		if not animation_id.is_empty() and remaining > _slot_autoplay_outcome_hold_msec(machine):
			return "spinning"
	if maxi(0, int(machine.get("last_payout", 0))) > 0:
		return "win"
	if classification == "near_miss":
		return "near_miss"
	if classification == "nudge_chain_break":
		return "miss"
	if classification == "idle":
		return "autoplay_wait" if bool(machine.get("slot_autoplay_active", false)) else "idle"
	return "autoplay_wait" if bool(machine.get("slot_autoplay_active", false)) else "loss"


func _slot_preview_phase(machine: Dictionary, active_bonus: Dictionary, nudge_offer: Dictionary, now_msec: int, autoplay_delay_msec: int = -1, spin_plan: Dictionary = {}) -> String:
	if not nudge_offer.is_empty():
		return "nudge_chain" if str(nudge_offer.get("type", "")) == "coin_chain" else "nudge"
	if bool(active_bonus.get("active", false)) and not bool(active_bonus.get("complete", false)):
		return "bonus"
	var classification := str(machine.get("last_classification", "idle"))
	if bool(machine.get("slot_autoplay_active", false)):
		var plan: Dictionary = spin_plan if not spin_plan.is_empty() else _slot_copy_dict(machine.get("slot_animation_plan", {}))
		var delay := autoplay_delay_msec if autoplay_delay_msec >= 0 else _slot_autoplay_delay_msec(machine)
		var remaining := maxi(0, int(machine.get("slot_autoplay_next_msec", 0)) - now_msec)
		var elapsed := maxi(0, delay - remaining)
		if not str(machine.get("slot_animation_id", "")).is_empty() and elapsed < _slot_spin_reveal_msec(plan):
			return "spinning"
	if maxi(0, int(machine.get("last_payout", 0))) > 0:
		return "win"
	if classification == "near_miss":
		return "near_miss"
	if classification == "nudge_chain_break":
		return "miss"
	if classification == "idle":
		return "autoplay_wait" if bool(machine.get("slot_autoplay_active", false)) else "idle"
	return "autoplay_wait" if bool(machine.get("slot_autoplay_active", false)) else "loss"


func _slot_preview_active(machine: Dictionary, active_bonus: Dictionary, nudge_offer: Dictionary, phase: String) -> bool:
	if bool(machine.get("slot_autoplay_active", false)) or not nudge_offer.is_empty():
		return true
	if bool(active_bonus.get("active", false)) and not bool(active_bonus.get("complete", false)):
		return true
	return ["spinning", "bonus", "nudge_chain"].has(phase)


func _slot_preview_status_label(phase: String, machine: Dictionary, _active_bonus: Dictionary, _nudge_offer: Dictionary) -> String:
	match phase:
		"spinning":
			return "SPIN"
		"nudge_chain", "nudge":
			return "NUDGE"
		"bonus":
			return "BONUS"
		"win":
			return "WIN"
		"near_miss":
			return "CLOSE"
		"miss":
			return "MISS"
		"autoplay_wait":
			return "AUTO" if bool(machine.get("slot_autoplay_active", false)) else ""
		_:
			return ""


func _slot_preview_caption(phase: String, machine: Dictionary, active_bonus: Dictionary, nudge_offer: Dictionary) -> String:
	match phase:
		"spinning":
			return "Reels spinning"
		"nudge_chain":
			return "Coin chain %d/%d bank $%d" % [
				int(nudge_offer.get("collected_count", 0)),
				int(nudge_offer.get("coin_count", _slot_copy_array(nudge_offer.get("coins", [])).size())),
				int(nudge_offer.get("banked_payout", 0)),
			]
		"nudge":
			return "Timed nudge ready"
		"bonus":
			return "%s %d left" % [
				str(active_bonus.get("mode", "bonus")).replace("_", " ").capitalize(),
				int(active_bonus.get("remaining_steps", active_bonus.get("remaining_spins", machine.get("free_spins", 0)))),
			]
		"win":
			return "Won $%d" % maxi(0, int(machine.get("last_payout", 0)))
		"near_miss":
			return "Near miss"
		"miss":
			return "Chain broke"
		"autoplay_wait":
			return "Autoplay waiting"
		_:
			return "Ready"


func _slot_preview_grid(value: Variant, reel_count: int, row_count: int) -> Array:
	var source: Array = _slot_copy_array(value)
	var result: Array = []
	for reel_index in range(reel_count):
		var column_source: Array = []
		if reel_index < source.size() and typeof(source[reel_index]) == TYPE_ARRAY:
			column_source = (source[reel_index] as Array)
		var column: Array = []
		for row_index in range(row_count):
			var symbol := "BLANK"
			if row_index < column_source.size():
				symbol = str(column_source[row_index])
			column.append(symbol)
		result.append(column)
	return result


func _slot_preview_cells(value: Variant) -> Array:
	var result: Array = []
	for cell_value in _slot_copy_array(value):
		var cell: Dictionary = _slot_copy_dict(cell_value)
		result.append({
			"reel": int(cell.get("reel", -1)),
			"row": int(cell.get("row", -1)),
		})
		if result.size() >= 12:
			break
	return result


func _slot_preview_timeline(value: Variant) -> Array:
	var result: Array = []
	var index := 0
	for entry_value in _slot_copy_array(value):
		var entry: Dictionary = _slot_copy_dict(entry_value)
		result.append({
			"reel": int(entry.get("reel", index)),
			"stop_msec": int(round(float(entry.get("stop_time", 0.0)) * 1000.0)),
			"settle_msec": int(round(float(entry.get("settle_end", entry.get("stop_time", 0.0))) * 1000.0)),
			"tease": bool(entry.get("tease", false)),
		})
		index += 1
		if result.size() >= SLOT_ENV_PREVIEW_MAX_REELS:
			break
	return result


func _slot_preview_bonus(machine: Dictionary, active_bonus: Dictionary) -> Dictionary:
	var active := bool(active_bonus.get("active", false)) and not bool(active_bonus.get("complete", false))
	return {
		"active": active,
		"family": str(active_bonus.get("family", machine.get("type_id", ""))),
		"mode": str(active_bonus.get("mode", "")),
		"step_index": int(active_bonus.get("step_index", 0)),
		"total_steps": int(active_bonus.get("total_steps", active_bonus.get("total_spins", 0))),
		"remaining_steps": int(active_bonus.get("remaining_steps", active_bonus.get("remaining_spins", machine.get("free_spins", 0)))),
		"feature_total": int(active_bonus.get("feature_total", active_bonus.get("pending_award", machine.get("last_bonus_total", 0)))),
		"jackpot_tier": str(active_bonus.get("jackpot_tier", "")),
		"free_spins": int(machine.get("free_spins", 0)),
	}


func _slot_preview_nudge_chain(nudge_offer: Dictionary) -> Dictionary:
	var coins: Array = []
	for coin_value in _slot_copy_array(nudge_offer.get("coins", [])):
		var coin: Dictionary = _slot_copy_dict(coin_value)
		coins.append({
			"index": int(coin.get("index", coins.size())),
			"row": int(coin.get("row", coins.size())),
			"side": str(coin.get("side", "left")),
			"collected": bool(coin.get("collected", false)),
			"ready_msec": int(coin.get("ready_msec", -1)),
		})
		if coins.size() >= SLOT_ENV_PREVIEW_MAX_ROWS:
			break
	return {
		"active": not nudge_offer.is_empty(),
		"type": str(nudge_offer.get("type", "")),
		"coin_count": int(nudge_offer.get("coin_count", coins.size())),
		"active_index": int(nudge_offer.get("active_index", 0)),
		"collected_count": int(nudge_offer.get("collected_count", 0)),
		"banked_payout": int(nudge_offer.get("banked_payout", 0)),
		"last_grade": str(nudge_offer.get("last_grade", "")),
		"last_award": int(nudge_offer.get("last_award", 0)),
		"last_spawned": bool(nudge_offer.get("last_spawned", false)),
		"coins": coins,
	}


func _slot_feature_pending(machine: Dictionary) -> bool:
	return StateScript.active_bonus_incomplete(machine)


func _mark_slot_feature_pending(machine: Dictionary, now_msec: int) -> Dictionary:
	var marked := machine.duplicate(true)
	marked["slot_autoplay_active"] = false
	marked["slot_autoplay_next_msec"] = 0
	marked["slot_pending_feature_alert"] = true
	marked["slot_pending_feature_alert_msec"] = maxi(0, now_msec)
	return marked


func _slot_feature_audio_cue(machine: Dictionary) -> String:
	var family := _slot_active_bonus_family(machine)
	if family == "buffalo":
		return "bonus_start_buffalo"
	if family == "pinball":
		return "bonus_start_pinball"
	return "bonus_start"


func _arm_lucky_reel_grease(machine: Dictionary, environment: Dictionary) -> Dictionary:
	var item_state: Dictionary = _slot_copy_dict(machine.get("slot_item_state", {}))
	item_state["lucky_reel_grease_spins"] = 10
	item_state["lucky_reel_grease_target"] = 3
	item_state["lucky_reel_grease_near_misses"] = 0
	item_state["lucky_reel_grease_failed_nudge_heat_bonus"] = 14
	machine["slot_item_state"] = item_state
	StateScript.write_machine(environment, get_id(), machine)
	return _slot_active_item_result(
		LUCKY_REEL_GREASE_ITEM_ID,
		"arm_lucky_reel_grease",
		"Lucky Reel Grease slicks this cabinet for ten spins. Bonuses now need a clean nudge.",
		environment,
		[LUCKY_REEL_GREASE_ITEM_ID],
		0
	)


func _load_cold_quarters(machine: Dictionary, environment: Dictionary) -> Dictionary:
	var item_state: Dictionary = _slot_copy_dict(machine.get("slot_item_state", {}))
	item_state["cold_quarters_charges"] = maxi(6, int(item_state.get("cold_quarters_charges", 0)))
	item_state["cold_quarter_heat_reduction"] = 6
	machine["slot_item_state"] = item_state
	StateScript.write_machine(environment, get_id(), machine)
	return _slot_active_item_result(
		COLD_QUARTERS_ITEM_ID,
		"load_cold_quarters",
		"Six Cold Quarters are ready for nudge attempts on this cabinet.",
		environment,
		[COLD_QUARTERS_ITEM_ID],
		0
	)


func _arm_split_reel_note(machine: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var item_state: Dictionary = _slot_copy_dict(machine.get("slot_item_state", {}))
	item_state["split_reel_note_armed"] = true
	item_state["split_reel_note_perfect_msec_bonus"] = 55
	item_state["split_reel_note_close_msec_bonus"] = 90
	machine["slot_item_state"] = item_state
	StateScript.write_machine(environment, get_id(), machine)
	var heat_delta := 0
	if run_state != null:
		var watch_status: Dictionary = run_state.pit_boss_watch_status(environment)
		if bool(watch_status.get("watched", false)):
			heat_delta = 6
	var message := "Split-Reel Note is tucked by the Buffalo controls for the next tease."
	if heat_delta > 0:
		message += " Staff catch the move."
	return _slot_active_item_result(
		SPLIT_REEL_NOTE_ITEM_ID,
		"arm_split_reel_note",
		message,
		environment,
		[SPLIT_REEL_NOTE_ITEM_ID],
		heat_delta
	)


func _slot_active_item_result(item_id: String, action_id: String, message: String, environment: Dictionary, inventory_remove: Array, suspicion_delta: int) -> Dictionary:
	var deltas := GameModule.empty_result_deltas()
	deltas["inventory_remove"] = inventory_remove.duplicate()
	deltas["suspicion_delta"] = maxi(0, suspicion_delta)
	deltas["messages"] = [message]
	deltas["story_log"] = [{
		"type": "active_item",
		"game_id": get_id(),
		"item_id": item_id,
		"action_id": action_id,
		"inventory_remove": inventory_remove.duplicate(),
		"suspicion_delta": maxi(0, suspicion_delta),
		"environment_id": str(environment.get("id", "")),
	}]
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "active_item",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": "active_item",
		"stake": 0,
		"deltas": deltas,
		"won": false,
		"environment_id": str(environment.get("id", "")),
		"message": message,
	})
	result["host_apply_result"] = true
	return {
		"handled": true,
		"environment_changed": true,
		"result": result,
		"message": message,
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


func _slot_bonus_auto_next_msec(machine: Dictionary, ui_state: Dictionary) -> int:
	var base_msec := _surface_timing_msec(ui_state)
	if base_msec <= 0:
		base_msec = Time.get_ticks_msec()
	return base_msec + _slot_bonus_auto_delay_msec(machine)


func _slot_bonus_auto_delay_msec(machine: Dictionary) -> int:
	return mini(BUFFALO_AUTOPLAY_MAX_DELAY_MSEC, maxi(900, _slot_autoplay_delay_msec(machine)))


func _buffalo_bonus_auto_action(machine: Dictionary) -> String:
	var active: Dictionary = _slot_copy_dict(machine.get("active_bonus", {}))
	if active.is_empty() or not bool(active.get("active", false)) or bool(active.get("complete", false)):
		return ""
	if str(active.get("family", machine.get("type_id", ""))) != "buffalo":
		return ""
	match str(active.get("mode", "")):
		"free_games", "hold_and_spin":
			return "slot_bonus_launch"
		_:
			return ""


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


func _slot_cross_game_item_effects(run_state: RunState, machine: Dictionary, is_cheat: bool) -> Dictionary:
	if run_state == null:
		return {}
	var item_state: Dictionary = _slot_copy_dict(machine.get("slot_item_state", {}))
	return {
		"win_bonus": _item_bonus("win_bonus", run_state, is_cheat),
		"payout_delta": _item_bonus("payout_delta", run_state, is_cheat),
		"loss_reduction": _item_bonus("loss_reduction", run_state, is_cheat),
		"cheat_suspicion_delta": _item_bonus("cheat_suspicion_delta", run_state, true),
		"slot_three_reel_loss_refund_percent": _item_bonus("slot_three_reel_loss_refund_percent", run_state, false),
		"slot_nudge_perfect_msec_bonus": _item_bonus("slot_nudge_perfect_msec_bonus", run_state, is_cheat),
		"slot_nudge_close_msec_bonus": _item_bonus("slot_nudge_close_msec_bonus", run_state, is_cheat),
		"slot_gold_tooth_coin_upgrade_chance": _item_bonus("slot_gold_tooth_coin_upgrade_chance", run_state, false),
		"slot_gold_tooth_coin_multiplier": _item_bonus("slot_gold_tooth_coin_multiplier", run_state, false),
		"slot_first_bonus_bonus_percent": _item_bonus("slot_first_bonus_bonus_percent", run_state, false),
		"slot_first_bonus_bonus_cap": _item_bonus("slot_first_bonus_bonus_cap", run_state, false),
		"slot_feature_weight_bonus_percent": _item_bonus("slot_feature_weight_bonus_percent", run_state, false),
		"slot_reel_win_weight_percent": _item_bonus("slot_reel_win_weight_percent", run_state, false),
		"slot_cold_quarter_heat_reduction": int(item_state.get("cold_quarter_heat_reduction", _item_bonus("slot_cold_quarter_heat_reduction", run_state, is_cheat))),
		"slot_split_reel_note_perfect_msec_bonus": int(item_state.get("split_reel_note_perfect_msec_bonus", _item_bonus("slot_split_reel_note_perfect_msec_bonus", run_state, is_cheat))),
		"slot_split_reel_note_close_msec_bonus": int(item_state.get("split_reel_note_close_msec_bonus", _item_bonus("slot_split_reel_note_close_msec_bonus", run_state, is_cheat))),
	}


func _slot_copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _slot_copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
