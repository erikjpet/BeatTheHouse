class_name SlotPresentation
extends RefCounted

const StateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const CatalogScript := preload("res://scripts/games/slots/slot_catalog.gd")
const BUFFALO_GRAND_BASE_MULTIPLIER := 1200
const BUFFALO_BONUS_MAX_ANIMATION_MSEC := 10000

var catalog


func _init() -> void:
	catalog = CatalogScript.new()


func surface_state(machine: Dictionary, run_state: RunState, definition: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	machine = StateScript.normalize(machine)
	var selected_bet: Dictionary = StateScript.selected_bet(machine)
	var stored_active_bonus: Dictionary = machine.get("active_bonus", {}) if typeof(machine.get("active_bonus", {})) == TYPE_DICTIONARY else {}
	var active_bonus: Dictionary = _display_active_bonus(machine, stored_active_bonus)
	var animation_duration := maxi(0, int(machine.get("slot_animation_duration_msec", 0)))
	var animation_id := str(machine.get("slot_animation_id", ""))
	var surface_time_msec := maxi(0, int(ui_state.get("drunk_scaled_surface_time_msec", ui_state.get("surface_time_msec", 0))))
	var spin_channel := GameModule.surface_animation_channel(
		"slot_spin",
		animation_id,
		animation_duration,
		int(machine.get("slot_animation_started_msec", 0)),
		{"metadata": {"classification": str(machine.get("last_classification", "idle"))}}
	)
	var feature_active := _bonus_visible_on_surface(active_bonus)
	var feature_active_id := ""
	if feature_active:
		feature_active_id = "%s:%s:%d" % [str(active_bonus.get("family", "")), str(active_bonus.get("mode", "")), int(machine.get("spin_count", 0))]
		if bool(active_bonus.get("visual_replay", false)):
			feature_active_id = "%s:replay:%s" % [feature_active_id, animation_id]
	var feature_channel := GameModule.surface_animation_channel(
		"slot_feature",
		feature_active_id,
		_feature_channel_duration_msec(machine, active_bonus),
		0,
		{"metadata": {"mode": str(active_bonus.get("mode", ""))}}
	)
	var skin: Dictionary = catalog.skin_for_machine(machine, definition)
	var timeline: Array = _reel_timeline(machine)
	var nudge_offer: Dictionary = _copy_dict(machine.get("last_nudge_offer", {}))
	var nudge_timing: Dictionary = _nudge_timing_state(nudge_offer, ui_state)
	var nudge_available := not nudge_offer.is_empty() and bool(nudge_timing.get("available", false))
	var result_message := _surface_message(machine, active_bonus)
	if str(active_bonus.get("family", "")) == "pinball" and bool(active_bonus.get("active", false)):
		active_bonus["pinball_launch_meter"] = _pinball_launch_meter(active_bonus, surface_time_msec)
	var bet_options: Array = _bet_options(selected_bet)
	return GameModule.surface_spec({
		"surface_renderer": "slot_machine",
		"surface_life": "reel_machine",
		"surface_cast": "machine",
		"surface_controls_native": true,
		"surface_fixed_price_actions": true,
		"surface_stake_controls_required": false,
		"surface_animates_idle": true,
		"surface_realtime_state_refresh": feature_active and str(active_bonus.get("family", "")) == "pinball",
		"surface_embeds_outcomes": true,
		"surface_suppresses_game_result_burst": true,
		"surface_action_bindings": {
			"legal": {"action": "slot_spin", "index": 0},
			"cheat": {"action": "slot_nudge", "index": 0},
		},
		"native_selected_surface_actions": _selected_actions(ui_state),
		"surface_animation_channels": [spin_channel, feature_channel],
		"surface_action_blocks": [
			{"actions": ["slot_spin"], "while_animation": "slot_spin"},
		],
		"surface_audio": GameModule.surface_audio_spec({
			"profile_id": "slot_machine:%s" % str(machine.get("machine_key", "")),
			"action_cues": {
				"slot_spin": "machine_button",
				"slot_nudge": "machine_button",
				"slot_auto_toggle": "machine_button",
				"slot_bonus_left": "machine_button",
				"slot_bonus_launch": "machine_button",
				"slot_bonus_right": "machine_button",
				"slot_bonus_power_down": "machine_button",
				"slot_bonus_power_up": "machine_button",
				"slot_bonus_tilt": "machine_button",
			},
			"state_sync": {
				"method": "reel_machine_state",
				"animation_channel": "slot_spin",
				"feature_animation_channel": "slot_feature",
			},
		}),
		"machine_key": str(machine.get("machine_key", "")),
		"slot_skin": skin,
		"slot_format_id": str(machine.get("format_id", "")),
		"slot_type_id": str(machine.get("type_id", "")),
		"slot_math_variant_id": str(machine.get("math_variant_id", "")),
		"slot_bonus_variant_id": str(machine.get("bonus_variant_id", "")),
		"slot_cabinet_variant_id": str(machine.get("cabinet_variant_id", "")),
		"slot_cabinet_identity": str(skin.get("cabinet_identity", "")),
		"slot_cabinet_title": str(skin.get("cabinet_title", "")),
		"slot_cabinet_signature": "%s:%s:%s:%s" % [
			str(skin.get("cabinet_identity", "")),
			str(skin.get("topper_style", "")),
			str(skin.get("material", "")),
			str(skin.get("motion_style", "")),
		],
		"slot_reel_count": int(machine.get("reel_count", 3)),
		"slot_row_count": int(machine.get("row_count", 1)),
		"slot_grid": _copy_array(machine.get("last_grid", [])),
		"slot_previous_grid": _copy_array(machine.get("last_previous_grid", [])),
		"slot_reel_stops": _copy_array(machine.get("reel_stops", [])),
		"slot_reel_strips": _copy_array(machine.get("reel_strips", [])),
		"slot_reel_stop_times": _reel_stop_times(machine),
		"slot_reel_timeline": timeline,
		"slot_animation_plan": _copy_dict(machine.get("slot_animation_plan", {})),
		"slot_animation_id": animation_id,
		"slot_animation_duration_msec": animation_duration,
		"slot_visual_time_msec": surface_time_msec,
		"slot_attract_phase": _attract_phase(surface_time_msec, skin),
		"slot_bonus_start_time": _bonus_start_time(machine),
		"slot_audio_cues": _audio_cues(machine),
		"slot_feature_scene": _feature_scene(active_bonus),
		"slot_bonus_steps": _copy_array(active_bonus.get("history", [])),
		"slot_bonus_total": int(active_bonus.get("feature_total", active_bonus.get("pending_award", machine.get("last_bonus_total", 0)))),
		"slot_payout": int(machine.get("last_payout", 0)),
		"slot_stake_cost": int(machine.get("last_stake_cost", 0)),
		"slot_net": int(machine.get("last_net", 0)),
		"slot_classification": str(machine.get("last_classification", "idle")),
		"slot_outcome_id": str(machine.get("last_outcome_id", "")),
		"slot_previous_payout": int(machine.get("previous_result_payout", 0)),
		"slot_previous_net": int(machine.get("previous_result_net", 0)),
		"slot_previous_classification": str(machine.get("previous_result_classification", "idle")),
		"slot_previous_reason": str(machine.get("previous_result_reason", "")),
		"slot_previous_result_message": _previous_surface_message(machine),
		"spin_count": int(machine.get("spin_count", 0)),
		"slot_spin_count": int(machine.get("spin_count", 0)),
		"slot_win_cells": _copy_array(machine.get("slot_win_cells", [])),
		"slot_win_symbol": str(machine.get("slot_win_symbol", "")),
		"slot_win_count": int(machine.get("slot_win_count", 0)),
		"slot_win_kind": str(machine.get("slot_win_kind", "none")),
		"slot_win_line_index": int(machine.get("slot_win_line_index", -1)),
		"slot_win_multiplier": int(machine.get("slot_win_multiplier", 1)),
		"slot_win_amount": int(machine.get("slot_win_amount", machine.get("last_payout", 0))),
		"slot_win_reason": str(machine.get("slot_win_reason", "")),
		"slot_celebration_tier": str(machine.get("slot_celebration_tier", "none")),
		"slot_tease_events": _copy_array(machine.get("last_tease_events", [])),
		"slot_nudge_available": nudge_available,
		"slot_nudge_tease_window_active": bool(nudge_timing.get("window_active", false)),
		"slot_nudge_tease_window_msec": _copy_dict(nudge_timing.get("window_msec", {})),
		"slot_nudge_tease_input_msec": int(nudge_timing.get("input_msec", -1)),
		"slot_nudge_tease_level": int(nudge_offer.get("visible_coin_count", 0)),
		"slot_nudge_tease_outcome_hint": str(nudge_timing.get("hint", "")),
		"slot_nudge_applied": _last_tease_was_nudge(machine),
		"slot_autoplay_active": bool(machine.get("slot_autoplay_active", false)),
		"slot_free_spins": int(machine.get("free_spins", 0)),
		"slot_active_bonus": active_bonus.duplicate(true),
		"slot_active_bonus_active": feature_active,
		"slot_buffalo_grand_prize": _buffalo_grand_prize(machine, active_bonus, selected_bet),
		"slot_fixed_bet_ladder": true,
		"bet_options": bet_options.duplicate(true),
		"selected_bet_id": str(selected_bet.get("id", "bet_2")),
		"selected_bet_total_credits": int(selected_bet.get("total_credits", 2)),
		"slot_bet_options": bet_options.duplicate(true),
		"slot_selected_bet_id": str(selected_bet.get("id", "bet_2")),
		"slot_selected_bet": int(selected_bet.get("total_credits", 2)),
		"selected_stake": int(selected_bet.get("total_credits", 2)),
		"bankroll": run_state.bankroll if run_state != null else 0,
		"suspicion_level": run_state.suspicion_level() if run_state != null else 0,
		"result_message": result_message,
		"outcome_message": result_message,
		"has_recent_outcome": str(machine.get("last_classification", "idle")) != "idle",
	})


func _surface_message(machine: Dictionary, active_bonus: Dictionary) -> String:
	if bool(active_bonus.get("visual_replay", false)):
		return "Bonus pays $%d." % int(active_bonus.get("awarded", active_bonus.get("feature_total", 0)))
	if bool(active_bonus.get("active", false)) and not bool(active_bonus.get("complete", false)):
		return "Bonus active: %s." % str(active_bonus.get("mode", "feature")).replace("_", " ").capitalize()
	return _result_message(
		str(machine.get("last_classification", "idle")),
		int(machine.get("last_payout", 0)),
		int(machine.get("last_net", 0)),
		str(machine.get("slot_win_reason", ""))
	)


func _previous_surface_message(machine: Dictionary) -> String:
	return _result_message(
		str(machine.get("previous_result_classification", "idle")),
		int(machine.get("previous_result_payout", 0)),
		int(machine.get("previous_result_net", 0)),
		str(machine.get("previous_result_reason", ""))
	)


func _result_message(classification: String, payout: int, net: int, reason: String) -> String:
	if classification == "idle":
		return "Pick a bet and spin."
	if not reason.is_empty():
		if classification == "near_miss":
			return reason
		if payout > 0:
			return "WIN $%d - %s" % [payout, reason]
		return reason
	if classification == "near_miss":
		return "Near miss. Nudge is live."
	if payout > 0:
		return "%s paid $%d, net %+d." % [classification.replace("_", " ").capitalize(), payout, net]
	return "%s, net %+d." % [classification.replace("_", " ").capitalize(), net]


func _display_active_bonus(machine: Dictionary, active_bonus: Dictionary) -> Dictionary:
	var live: Dictionary = active_bonus.duplicate(true)
	if bool(live.get("active", false)) and not bool(live.get("complete", false)):
		return live
	if not str(machine.get("slot_animation_id", "")).begins_with("bonus:"):
		return live
	var replay: Dictionary = _copy_dict(machine.get("last_bonus_replay", {}))
	if replay.is_empty() or not ["pinball", "buffalo"].has(str(replay.get("family", ""))):
		return live
	var plan: Dictionary = _copy_dict(machine.get("slot_animation_plan", {}))
	var plan_duration := maxi(0, int(plan.get("feature_duration_msec", 0)))
	if plan_duration <= 0:
		return live
	replay["active"] = true
	replay["complete"] = true
	replay["visual_replay"] = true
	var replay_duration := maxi(int(replay.get("animation_duration_msec", 0)), plan_duration)
	if str(replay.get("family", "")) == "buffalo":
		replay_duration = mini(replay_duration, BUFFALO_BONUS_MAX_ANIMATION_MSEC)
	replay["animation_duration_msec"] = replay_duration
	return replay


func _bonus_visible_on_surface(active_bonus: Dictionary) -> bool:
	if bool(active_bonus.get("visual_replay", false)):
		return true
	return bool(active_bonus.get("active", false)) and not bool(active_bonus.get("complete", false))


func _selected_actions(ui_state: Dictionary) -> Array:
	var action_id := str(ui_state.get("selected_action_id", ""))
	if action_id == "spin":
		return ["slot_spin"]
	if action_id == "nudge":
		return ["slot_nudge"]
	return []


func _nudge_timing_state(offer: Dictionary, ui_state: Dictionary) -> Dictionary:
	if offer.is_empty():
		return {"available": false, "window_active": false, "input_msec": -1, "window_msec": {}, "hint": ""}
	var window: Dictionary = _copy_dict(offer.get("skill_window_msec", {}))
	var start_msec := maxi(0, int(window.get("start", 0)))
	var end_msec := maxi(start_msec, int(window.get("end", 0)))
	var perfect_msec := clampi(int(window.get("perfect", start_msec)), start_msec, end_msec)
	var input_msec := _surface_spin_elapsed_msec(ui_state)
	var spin_active := _surface_spin_active(ui_state)
	var window_active := spin_active and input_msec >= start_msec and input_msec <= end_msec
	var post_spin_available := bool(offer.get("post_spin_available", false)) and (input_msec < 0 or not spin_active)
	var hint := ""
	if window_active:
		var distance := absi(input_msec - perfect_msec)
		hint = "line it up" if distance > int(offer.get("skill_close_msec", 210)) else "good timing" if distance > int(offer.get("skill_perfect_msec", 75)) else "perfect timing"
	elif post_spin_available:
		hint = "stored nudge"
	return {
		"available": true,
		"window_active": window_active,
		"input_msec": input_msec,
		"window_msec": window,
		"hint": hint if not hint.is_empty() else "time the stop",
	}


func _surface_spin_elapsed_msec(ui_state: Dictionary) -> int:
	if int(ui_state.get("slot_tease_input_msec", -1)) >= 0:
		return int(ui_state.get("slot_tease_input_msec", -1))
	var runtime: Dictionary = _copy_dict(ui_state.get("surface_runtime_status", {}))
	var animations: Dictionary = _copy_dict(runtime.get("surface_animations", {}))
	var spin: Dictionary = _copy_dict(animations.get("slot_spin", {}))
	if spin.is_empty():
		return -1
	return maxi(0, int(round(float(spin.get("elapsed", 0.0)) * 1000.0)))


func _surface_spin_active(ui_state: Dictionary) -> bool:
	var runtime: Dictionary = _copy_dict(ui_state.get("surface_runtime_status", {}))
	var animations: Dictionary = _copy_dict(runtime.get("surface_animations", {}))
	var spin: Dictionary = _copy_dict(animations.get("slot_spin", {}))
	return bool(spin.get("active", false))


func _bet_options(selected_bet: Dictionary) -> Array:
	var selected_id := str(selected_bet.get("id", "bet_2"))
	var result: Array = []
	for option_value in StateScript.BET_OPTIONS:
		var option: Dictionary = (option_value as Dictionary).duplicate(true)
		option["display_tier"] = str(option.get("label", "bet")).to_lower()
		option["selected"] = str(option.get("id", "")) == selected_id
		option["enabled"] = true
		result.append(option)
	return result


func _reel_stop_times(machine: Dictionary) -> Array:
	var stored: Array = _copy_array(machine.get("slot_reel_stop_times", []))
	if not stored.is_empty():
		return stored
	var plan: Dictionary = _copy_dict(machine.get("slot_animation_plan", {}))
	var plan_stops: Array = _copy_array(plan.get("reel_stop_times", []))
	if not plan_stops.is_empty():
		return plan_stops
	var count := maxi(1, int(machine.get("reel_count", 3)))
	var duration := float(maxi(1, int(machine.get("slot_animation_duration_msec", 2200)))) / 1000.0
	var result: Array = []
	for index in range(count):
		result.append(minf(duration - 0.20, 0.50 + float(index) * 0.22))
	return result


func _reel_timeline(machine: Dictionary) -> Array:
	var stored: Array = _copy_array(machine.get("slot_reel_timeline", []))
	if not stored.is_empty():
		return stored
	var plan: Dictionary = _copy_dict(machine.get("slot_animation_plan", {}))
	var plan_timeline: Array = _copy_array(plan.get("reel_timeline", []))
	if not plan_timeline.is_empty():
		return plan_timeline
	var count := maxi(1, int(machine.get("reel_count", 3)))
	var stops: Array = _reel_stop_times(machine)
	var result: Array = []
	for index in range(count):
		var stop_time := float(stops[index]) if index < stops.size() else 0.8 + float(index) * 0.25
		var settle_end := stop_time + 0.22
		result.append({
			"reel": index,
			"spin_up_start": 0.0,
			"spin_up_end": maxf(0.08, stop_time - 0.54),
			"decel_start": maxf(0.12, stop_time - 0.32),
			"stop_time": stop_time,
			"settle_end": settle_end,
			"phase_order": ["spin_up", "decel", "settle"],
		})
	return result


func _attract_phase(surface_time_msec: int, skin: Dictionary) -> Dictionary:
	var loop_msec := 3600
	var phase := float(posmod(surface_time_msec, loop_msec)) / float(loop_msec)
	var chase_index := int(floor(phase * 18.0))
	return {
		"phase": phase,
		"chase_index": chase_index,
		"topper_frame": "%s:%02d" % [str(skin.get("topper_style", "")), chase_index],
		"motion_style": str(skin.get("motion_style", "")),
	}


func _bonus_start_time(machine: Dictionary) -> float:
	if machine.has("slot_bonus_start_time"):
		return float(machine.get("slot_bonus_start_time", 0.0))
	var plan: Dictionary = _copy_dict(machine.get("slot_animation_plan", {}))
	if plan.has("bonus_start_time"):
		return float(plan.get("bonus_start_time", 0.0))
	var stops: Array = _reel_stop_times(machine)
	if stops.is_empty():
		return 0.90
	return float(stops[stops.size() - 1]) + 0.40


func _feature_channel_duration_msec(machine: Dictionary, active_bonus: Dictionary) -> int:
	if str(active_bonus.get("family", "")) == "pinball" and bool(active_bonus.get("active", false)) and not bool(active_bonus.get("complete", false)):
		return 0
	var active_duration := maxi(0, int(active_bonus.get("animation_duration_msec", 0)))
	if active_duration > 0:
		return _cap_buffalo_feature_duration(active_bonus, active_duration)
	var plan: Dictionary = _copy_dict(machine.get("slot_animation_plan", {}))
	var plan_duration := maxi(0, int(plan.get("feature_duration_msec", 0)))
	if plan_duration > 0:
		return _cap_buffalo_feature_duration(active_bonus, plan_duration)
	var steps := maxi(0, int(active_bonus.get("total_steps", active_bonus.get("remaining_steps", 0))))
	if steps > 0:
		return _cap_buffalo_feature_duration(active_bonus, int(round(float(steps) * 720.0 + 900.0)))
	return _cap_buffalo_feature_duration(active_bonus, maxi(900, int(machine.get("slot_animation_duration_msec", 900))))


func _cap_buffalo_feature_duration(active_bonus: Dictionary, duration_msec: int) -> int:
	if str(active_bonus.get("family", "")) == "buffalo":
		return mini(maxi(0, duration_msec), BUFFALO_BONUS_MAX_ANIMATION_MSEC)
	return duration_msec


func _buffalo_grand_prize(machine: Dictionary, active_bonus: Dictionary, selected_bet: Dictionary) -> int:
	if str(machine.get("type_id", "")) != "buffalo" and str(active_bonus.get("family", "")) != "buffalo":
		return 0
	var awarded := maxi(0, int(active_bonus.get("grand_prize_awarded", 0)))
	if awarded > 0:
		return awarded
	var active_grand := maxi(0, int(active_bonus.get("grand_prize", 0)))
	if active_grand > 0:
		return active_grand
	var bonus_state: Dictionary = _copy_dict(machine.get("bonus_state", {}))
	var stored := maxi(0, int(bonus_state.get("buffalo_grand_prize", 0)))
	if stored > 0:
		return stored
	var ladder: Dictionary = _copy_dict(active_bonus.get("jackpot_ladder", {}))
	for tier_value in _copy_array(ladder.get("tiers", [])):
		var tier: Dictionary = _copy_dict(tier_value)
		if str(tier.get("id", "")) == "grand":
			var ladder_award := maxi(0, int(tier.get("award", 0)))
			if ladder_award > 0:
				return ladder_award
	return maxi(1, int(selected_bet.get("total_credits", 2))) * BUFFALO_GRAND_BASE_MULTIPLIER


func _audio_cues(machine: Dictionary) -> Array:
	var stops: Array = _reel_stop_times(machine)
	var cues: Array = [
		{"phase": "spin_start", "cue_id": "slot_spin_start", "time_sec": 0.0, "marker": "spin_start"},
		{"phase": "spin_loop", "cue_id": "slot_spin_loop", "time_sec": 0.0, "marker": "spin_loop"},
	]
	for index in range(stops.size()):
		cues.append({"phase": "reel_stop", "cue_id": "slot_reel_stop_%d" % index, "time_sec": float(stops[index]), "reel_index": index, "marker": "reel_stop_%d" % index})
	var plan: Dictionary = _copy_dict(machine.get("slot_animation_plan", {}))
	var tease_coin_count := int(plan.get("tease_coin_count", 0))
	if tease_coin_count > 0:
		var first_reel := clampi(int(plan.get("tease_first_coin_reel", 0)), 0, maxi(0, stops.size() - 1))
		var first_time := float(stops[first_reel]) if first_reel >= 0 and first_reel < stops.size() else 0.45
		cues.append({"phase": "gold_coin_tease", "cue_id": "gold_coin_tease", "time_sec": first_time, "marker": "gold_coin_tease", "volume_db": 1.5, "pitch": 0.96})
		cues.append({"phase": "tease_slow_roll", "cue_id": "slot_tease_slow_roll", "time_sec": first_time + 0.10, "marker": "tease_slow_roll", "volume_db": -1.5})
		if tease_coin_count >= 2:
			var second_reel := clampi(int(plan.get("tease_second_coin_reel", first_reel + 1)), 0, maxi(0, stops.size() - 1))
			var second_time := float(stops[second_reel]) if second_reel >= 0 and second_reel < stops.size() else first_time + 0.42
			cues.append({"phase": "double_gold_coin_tease", "cue_id": "double_gold_coin_tease", "time_sec": second_time, "marker": "double_gold_coin_tease", "volume_db": 2.0, "pitch": 1.03})
	var classification := str(machine.get("last_classification", ""))
	var final_time := (float(stops[stops.size() - 1]) if not stops.is_empty() else 0.8) + 0.30
	if classification == "near_miss":
		cues.append({"phase": "near_miss", "cue_id": "slot_tease_resolve", "time_sec": maxf(0.0, final_time - 0.34), "marker": "near_miss"})
	elif int(machine.get("last_payout", 0)) > 0:
		cues.append({"phase": "true_win", "cue_id": "slot_payout", "time_sec": final_time, "marker": "payout"})
	else:
		cues.append({"phase": "final_loss", "cue_id": "slot_loss", "time_sec": final_time, "marker": "loss"})
	return cues


func _feature_scene(active_bonus: Dictionary) -> Dictionary:
	if active_bonus.is_empty() or not bool(active_bonus.get("active", false)):
		return {"active": false}
	var scene: Dictionary = {
		"active": not bool(active_bonus.get("complete", false)),
		"scene_id": "%s:%s" % [str(active_bonus.get("family", "")), str(active_bonus.get("mode", ""))],
		"mode": str(active_bonus.get("mode", "")),
		"step_index": int(active_bonus.get("step_index", 0)),
		"remaining_steps": int(active_bonus.get("remaining_steps", 0)),
		"pending_award": int(active_bonus.get("pending_award", 0)),
		"feature_total": int(active_bonus.get("feature_total", active_bonus.get("pending_award", 0))),
		"display_mode": str(active_bonus.get("display_mode", active_bonus.get("mode", ""))),
		"choices": _copy_array(active_bonus.get("choices", [])),
		"history": _copy_array(active_bonus.get("history", [])),
		"audio_cues": [
			{"phase": "feature_transition", "cue_id": "slot_bonus_transition", "time_sec": 0.1, "marker": "feature_transition"},
		],
	}
	if str(active_bonus.get("family", "")) == "buffalo":
		var buffalo_scene: Dictionary = _buffalo_feature_scene(active_bonus)
		for key_value in buffalo_scene.keys():
			scene[key_value] = buffalo_scene[key_value]
	elif str(active_bonus.get("family", "")) == "pinball":
		var pinball_scene: Dictionary = _pinball_feature_scene(active_bonus)
		for key_value in pinball_scene.keys():
			scene[key_value] = pinball_scene[key_value]
	return scene


func _pinball_feature_scene(active_bonus: Dictionary) -> Dictionary:
	var mode := str(active_bonus.get("mode", "pinball"))
	var total_steps := maxi(1, int(active_bonus.get("total_steps", active_bonus.get("remaining_steps", 1))))
	var step_index := maxi(0, int(active_bonus.get("step_index", 0)))
	var phase := "launch"
	if bool(active_bonus.get("complete", false)):
		phase = "celebration"
	elif bool(active_bonus.get("launch_in_progress", false)):
		phase = "play"
	return {
		"feature_phase": phase,
		"feature_music": {
			"cue_id": "bonus_music_pinball",
			"loop": true,
			"style": "kinetic_pinball_feature",
			"volume_db": -15.0,
			"pitch": 1.0 + clampf(float(step_index) / float(total_steps + 2), 0.0, 0.10),
		},
		"launch_meter": _copy_dict(active_bonus.get("pinball_launch_meter", {})),
		"audio_cues": _pinball_feature_audio_cues(active_bonus, phase),
	}


func _pinball_feature_audio_cues(active_bonus: Dictionary, phase: String) -> Array:
	var cues: Array = [
		{"phase": "feature_transition", "cue_id": "pinball_feature_intro", "time_sec": 0.08, "marker": "pinball_feature_intro"},
	]
	if phase == "launch":
		cues.append({"phase": "plunger_charge", "cue_id": "pinball_plunger_charge", "time_sec": 0.22, "marker": "pinball_plunger_charge"})
	else:
		cues.append({"phase": "table_music", "cue_id": "pinball_shot_counter", "time_sec": 0.38, "marker": "pinball_shot_counter"})
	var recent: Array = _copy_array(active_bonus.get("display_event_log", []))
	if recent.is_empty():
		recent = _copy_array(active_bonus.get("event_log", []))
	for index in range(mini(recent.size(), 6)):
		var event: Dictionary = _copy_dict(recent[index])
		var event_type := str(event.get("element_type", ""))
		var cue_id := "pinball_cup_hit" if event_type == "pocket" else "pinball_jackpot_lane" if event_type == "super_jackpot" or event_type == "jackpot" else "pinball_lane_lit" if event_type == "ramp" or event_type == "orbit" else "pinball_flipper" if event_type == "flipper" else "pinball_shot_counter"
		cues.append({"phase": "pinball_hit", "cue_id": cue_id, "time_sec": 0.62 + float(index) * 0.10, "marker": "pinball_hit_%d" % index, "pitch": 0.96 + float(index) * 0.025})
	return cues


func _pinball_launch_meter(active_bonus: Dictionary, surface_time_msec: int) -> Dictionary:
	var target_power := clampi(int(active_bonus.get("launch_power", 70)), 20, 100)
	var time_msec := maxi(0, surface_time_msec)
	if time_msec <= 0:
		time_msec = 173 + int(active_bonus.get("step_index", 0)) * 137 + int(active_bonus.get("balls_remaining", 0)) * 83
	var meter := clampf(float(target_power) / 100.0, 0.0, 1.0)
	var sampled_power := target_power
	var sweet_spot := 82
	var error := absi(sampled_power - sweet_spot)
	var rating := "clean"
	if error <= 4:
		rating = "sweet"
	elif error <= 10:
		rating = "good"
	elif error >= 24:
		rating = "wild"
	return {
		"target_power": target_power,
		"sampled_power": sampled_power,
		"meter": snappedf(meter, 0.001),
		"sweet_spot": sweet_spot,
		"rating": rating,
		"time_msec": time_msec,
		"lane": str(active_bonus.get("selected_lane", "center")),
		"angle_degrees": clampi(int(active_bonus.get("launch_angle_degrees", 0)), -60, 60),
		"controlled": true,
	}


func _buffalo_feature_scene(active_bonus: Dictionary) -> Dictionary:
	var mode := str(active_bonus.get("mode", ""))
	var total_steps := maxi(1, int(active_bonus.get("total_steps", active_bonus.get("remaining_steps", 1))))
	var step_index := maxi(0, int(active_bonus.get("step_index", 0)))
	var phase := str(active_bonus.get("feature_phase", "transition"))
	if bool(active_bonus.get("complete", false)):
		phase = "celebration"
	elif step_index > 0:
		phase = "play"
	var phases: Array = [
		{"id": "transition", "start_msec": 0, "duration_msec": 900},
		{"id": "play", "start_msec": 900, "duration_msec": maxi(720, total_steps * 720)},
		{"id": "celebration", "start_msec": 900 + maxi(720, total_steps * 720), "duration_msec": 900},
	]
	var collection_meter: Dictionary = _copy_dict(active_bonus.get("collection_meter", {}))
	if collection_meter.is_empty():
		var cycle := maxi(0, int(active_bonus.get("coins_since_retrigger", 0)))
		collection_meter = {"value": cycle, "threshold": 3, "cycle": cycle, "total": maxi(0, int(active_bonus.get("coins_collected", 0))), "coin_total": maxi(0, int(active_bonus.get("coin_total", 0)))}
	var fill_meter: Dictionary = _copy_dict(active_bonus.get("fill_meter", {}))
	if fill_meter.is_empty():
		var locks: Array = _copy_array(active_bonus.get("locks", []))
		var max_cells := maxi(1, int(active_bonus.get("max_cells", maxi(1, locks.size()))))
		fill_meter = {"locked": locks.size(), "max": max_cells, "ratio": float(locks.size()) / float(max_cells)}
	return {
		"feature_phase": phase,
		"phases": phases,
		"feature_music": {
			"cue_id": "bonus_music_buffalo",
			"loop": true,
			"style": "stampede_bonus",
			"volume_db": -15.5,
			"pitch": 1.0 + clampf(float(step_index) / float(total_steps + 1), 0.0, 0.12),
		},
		"stampede": {"active": true, "intensity": clampf(float(step_index + 1) / float(total_steps + 1), 0.0, 1.0)},
		"jackpot_ladder": _copy_dict(active_bonus.get("jackpot_ladder", {})),
		"trophy_pick": {
			"active": bool(active_bonus.get("trophy_pick_active", false)),
			"choices": _copy_array(active_bonus.get("trophy_choices", active_bonus.get("choices", []))),
			"reveals": _copy_array(active_bonus.get("trophy_reveals", [])),
			"selected_path": str(active_bonus.get("trophy_selected_path", active_bonus.get("selected_path", ""))),
		},
		"collection_meter": collection_meter,
		"fill_meter": fill_meter,
		"collected_coins": _copy_array(active_bonus.get("collected_coins", [])),
		"last_collected_coins": _copy_array(active_bonus.get("last_collected_coins", [])),
		"coins_collected": maxi(0, int(active_bonus.get("coins_collected", 0))),
		"coins_since_retrigger": maxi(0, int(active_bonus.get("coins_since_retrigger", 0))),
		"coin_total": maxi(0, int(active_bonus.get("coin_total", 0))),
		"coin_collect_total": maxi(0, int(active_bonus.get("coin_collect_total", 0))),
		"coin_collect_awarded": bool(active_bonus.get("coin_collect_awarded", false)),
		"last_retrigger_grant": maxi(0, int(active_bonus.get("last_retrigger_grant", 0))),
		"spin_win_total": maxi(0, int(active_bonus.get("spin_win_total", active_bonus.get("feature_total", 0)))),
		"last_lock_events": _copy_array(active_bonus.get("last_lock_events", [])),
		"audio_cues": _buffalo_feature_audio_cues(active_bonus, mode, phases),
	}


func _buffalo_feature_audio_cues(active_bonus: Dictionary, mode: String, phases: Array) -> Array:
	var cues: Array = [
		{"phase": "feature_transition", "cue_id": "bonus_start_buffalo", "time_sec": 0.10, "marker": "buffalo_stampede"},
		{"phase": "buffalo_drums", "cue_id": "bonus_step_buffalo", "time_sec": 0.72, "marker": "buffalo_drums"},
	]
	if mode == "hold_and_spin":
		var locks: Array = _copy_array(active_bonus.get("locks", []))
		for index in range(mini(locks.size(), 8)):
			cues.append({"phase": "coin_slam", "cue_id": "bonus_step_buffalo", "time_sec": 0.95 + float(index) * 0.10, "marker": "coin_slam_%d" % index, "pitch": 0.88 + float(index) * 0.025})
		if _buffalo_fill_ratio(active_bonus) >= 1.0:
			cues.append({"phase": "grand_roar", "cue_id": "jackpot_buffalo", "time_sec": 1.34, "marker": "grand_roar"})
	elif mode == "free_games":
		for index in range(mini(_copy_array(active_bonus.get("last_collected_coins", [])).size(), 8)):
			cues.append({"phase": "coin_collect", "cue_id": "bonus_step_buffalo", "time_sec": 0.95 + float(index) * 0.08, "marker": "free_coin_%d" % index, "pitch": 1.0 + float(index) * 0.025})
		if int(active_bonus.get("last_retrigger_grant", 0)) > 0:
			cues.append({"phase": "retrigger", "cue_id": "bonus_total_buffalo", "time_sec": 1.18, "marker": "free_games_retrigger"})
	elif mode == "wheel":
		cues.append({"phase": "trophy_reveal", "cue_id": "jackpot_hit_buffalo", "time_sec": 1.18, "marker": "trophy_reveal"})
		if str(active_bonus.get("selected_path", "")).contains("jackpot"):
			cues.append({"phase": "jackpot", "cue_id": "jackpot_buffalo", "time_sec": 1.55, "marker": "trophy_jackpot"})
	var play_start := 0.90
	if phases.size() > 1 and typeof(phases[1]) == TYPE_DICTIONARY:
		play_start = float((phases[1] as Dictionary).get("start_msec", 900)) / 1000.0
	cues.append({"phase": "buffalo_play", "cue_id": "bonus_step_buffalo", "time_sec": play_start, "marker": "buffalo_play"})
	return cues


func _buffalo_fill_ratio(active_bonus: Dictionary) -> float:
	var meter: Dictionary = _copy_dict(active_bonus.get("fill_meter", {}))
	if not meter.is_empty():
		return clampf(float(meter.get("ratio", 0.0)), 0.0, 1.0)
	var locks: Array = _copy_array(active_bonus.get("locks", []))
	var max_cells := maxi(1, int(active_bonus.get("max_cells", maxi(1, locks.size()))))
	return clampf(float(locks.size()) / float(max_cells), 0.0, 1.0)


func _last_tease_was_nudge(machine: Dictionary) -> bool:
	for event_value in _copy_array(machine.get("last_tease_events", [])):
		if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("type", "")) == "nudge_shift":
			return true
	return false


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
