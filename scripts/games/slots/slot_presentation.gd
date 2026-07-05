class_name SlotPresentation
extends RefCounted

const StateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const CatalogScript := preload("res://scripts/games/slots/slot_catalog.gd")
const PinballFeatureScript := preload("res://scripts/games/slots/pinball/pinball_feature.gd")
const BUFFALO_GRAND_BASE_MULTIPLIER := 50
const BUFFALO_BONUS_MAX_ANIMATION_MSEC := 10000
const PINBALL_BONUS_ALERT_DURATION_MSEC := 2000
const PINBALL_BONUS_ALERT_VOLUME_DB := -21.0
const PINBALL_BONUS_ALERT_STINGER_VOLUME_DB := -8.5

var catalog


func _init() -> void:
	catalog = CatalogScript.new()


func surface_state(machine: Dictionary, run_state: RunState, definition: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	machine = _surface_machine_view(machine)
	var stored_active_bonus: Dictionary = machine.get("active_bonus", {}) if typeof(machine.get("active_bonus", {})) == TYPE_DICTIONARY else {}
	var surface_time_msec := maxi(0, int(ui_state.get("drunk_scaled_surface_time_msec", ui_state.get("surface_time_msec", 0))))
	var fast_animation_id := str(machine.get("slot_animation_id", ""))
	if str(stored_active_bonus.get("family", "")) == "pinball" and bool(stored_active_bonus.get("active", false)) and not bool(stored_active_bonus.get("complete", false)) and fast_animation_id.begins_with("bonus:"):
		return _pinball_active_surface_state(machine, stored_active_bonus, run_state, surface_time_msec, ui_state)
	var selected_bet: Dictionary = StateScript.selected_bet(machine)
	var animation_duration := maxi(0, int(machine.get("slot_animation_duration_msec", 0)))
	var animation_id := str(machine.get("slot_animation_id", ""))
	var active_bonus: Dictionary = _display_active_bonus(machine, stored_active_bonus, surface_time_msec)
	active_bonus = _with_pinball_alert_metadata(active_bonus, machine)
	var spin_motion_active := not animation_id.is_empty() and animation_duration > 0
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
	var nudge_timing: Dictionary = _nudge_chain_timing_state(nudge_offer, ui_state)
	var nudge_available := not nudge_offer.is_empty() and bool(nudge_timing.get("available", false))
	var nudge_chain_id := str(nudge_offer.get("event_id", "")) if str(nudge_offer.get("type", "")) == "coin_chain" else ""
	var nudge_chain_channel := GameModule.surface_animation_channel(
		"slot_nudge_chain",
		nudge_chain_id,
		int(nudge_offer.get("duration_msec", 0)),
		0,
		{"metadata": {
			"active_index": int(nudge_offer.get("active_index", 0)),
			"collected_count": int(nudge_offer.get("collected_count", 0)),
		}}
	)
	var result_message := _surface_message(machine, active_bonus)
	if str(active_bonus.get("family", "")) == "pinball" and bool(active_bonus.get("active", false)):
		active_bonus["pinball_launch_meter"] = _pinball_launch_meter(active_bonus, surface_time_msec)
	var bet_options: Array = _bet_options(selected_bet)
	var surface_motion_active := spin_motion_active or feature_active or nudge_available
	return _slot_surface_spec({
		"surface_renderer": "slot_machine",
		"surface_life": "reel_machine",
		"surface_cast": "machine",
		"surface_controls_native": true,
		"surface_fixed_price_actions": true,
		"surface_stake_controls_required": false,
		"surface_animates_idle": surface_motion_active,
		"surface_realtime_state_refresh": nudge_available or (feature_active and (str(active_bonus.get("family", "")) == "pinball" or str(active_bonus.get("family", "")) == "buffalo")),
		"surface_embeds_outcomes": true,
		"surface_suppresses_game_result_burst": true,
		"surface_action_bindings": {
			"legal": {"action": "slot_spin", "index": 0},
			"cheat": {"action": "slot_nudge", "index": 0},
		},
		"native_selected_surface_actions": _selected_actions(ui_state),
		"surface_animation_channels": [spin_channel, feature_channel, nudge_chain_channel],
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
				"nudge_chain_channel": "slot_nudge_chain",
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
		"slot_bonus_steps": _surface_bonus_steps(active_bonus),
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
		"slot_nudge_tease_level": int(nudge_offer.get("coin_count", nudge_offer.get("visible_coin_count", 0))),
		"slot_nudge_tease_outcome_hint": str(nudge_timing.get("hint", "")),
		"slot_nudge_applied": _last_tease_was_nudge(machine),
		"slot_nudge_chain": _copy_dict(nudge_timing.get("chain", {})),
		"slot_nudge_chain_active": nudge_available and str(nudge_offer.get("type", "")) == "coin_chain",
		"slot_nudge_chain_event_id": nudge_chain_id,
		"slot_nudge_chain_elapsed_msec": int(nudge_timing.get("input_msec", -1)),
		"slot_nudge_chain_active_index": int(nudge_offer.get("active_index", 0)),
		"slot_nudge_chain_collected_count": int(nudge_offer.get("collected_count", 0)),
		"slot_nudge_chain_banked_payout": int(nudge_offer.get("banked_payout", 0)),
		"slot_nudge_chain_coins": _copy_array(nudge_offer.get("coins", [])),
		"slot_nudge_chain_last_grade": str(nudge_offer.get("last_grade", "")),
		"slot_nudge_chain_last_award": int(nudge_offer.get("last_award", 0)),
		"slot_nudge_chain_last_spawned": bool(nudge_offer.get("last_spawned", false)),
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


func _pinball_active_surface_state(machine: Dictionary, active_bonus: Dictionary, run_state: RunState, surface_time_msec: int, ui_state: Dictionary) -> Dictionary:
	var live: Dictionary = PinballFeatureScript.surface_refresh(active_bonus, surface_time_msec)
	live = _with_pinball_alert_metadata(live, machine)
	live["pinball_launch_meter"] = _pinball_launch_meter(live, surface_time_msec)
	var pinball_scene: Dictionary = _feature_scene(live)
	var pinball_cues: Array = []
	var pinball_cues_value: Variant = pinball_scene.get("audio_cues", [])
	if typeof(pinball_cues_value) == TYPE_ARRAY:
		pinball_cues = pinball_cues_value as Array
	var animation_id := str(machine.get("slot_animation_id", "pinball:live"))
	var feature_channel := {
		"id": "slot_feature",
		"active_id": "%s:%s:%d" % [str(live.get("family", "")), str(live.get("mode", "")), int(machine.get("spin_count", 0))],
		"duration_msec": 0,
		"started_msec": 0,
		"active": true,
		"restart_on_active_id_change": true,
		"metadata": {"mode": str(live.get("mode", ""))},
	}
	var skin := {
		"cabinet_identity": "pinball",
		"cabinet_title": "Pinball Bonus",
		"topper_style": "pinball",
		"material": "neon",
		"motion_style": "live",
		"palette": {
			"primary": "#24112f",
			"secondary": "#090b13",
			"accent": "#ff4fb3",
			"light": "#35e0ff",
			"trim": "#f7c845",
			"glass": "#9bd5ff",
			"shadow": "#020308",
		},
	}
	var result_message := "Bonus active: %s." % str(live.get("mode", "feature")).replace("_", " ").capitalize()
	var bet_ladder: Dictionary = machine.get("bet_ladder", {}) if typeof(machine.get("bet_ladder", {})) == TYPE_DICTIONARY else {}
	var selected_bet: Dictionary = machine.get("selected_bet", {}) if typeof(machine.get("selected_bet", {})) == TYPE_DICTIONARY else {}
	var selected_bet_id := str(selected_bet.get("id", bet_ladder.get("selected_id", "bet_2")))
	var selected_bet_total := int(selected_bet.get("total_credits", 2))
	return {
		"surface_renderer": "slot_machine",
		"surface_life": "reel_machine",
		"surface_cast": "machine",
		"surface_controls_native": true,
		"surface_fixed_price_actions": true,
		"surface_stake_controls_required": false,
		"surface_animates_idle": true,
		"surface_realtime_state_refresh": true,
		"surface_embeds_outcomes": true,
		"surface_suppresses_game_result_burst": true,
		"surface_action_bindings": {
			"legal": {"action": "slot_spin", "index": 0},
			"cheat": {"action": "slot_nudge", "index": 0},
		},
		"native_selected_surface_actions": _selected_actions(ui_state),
		"surface_animation_channels": [feature_channel],
		"surface_action_blocks": [],
		"surface_audio": {
			"profile_id": "slot_machine:%s" % str(machine.get("machine_key", "")),
			"action_cues": {
				"slot_bonus_left": "machine_button",
				"slot_bonus_launch": "machine_button",
				"slot_bonus_right": "machine_button",
				"slot_bonus_tilt": "machine_button",
			},
			"feature_cues": pinball_cues,
			"channels": {
				"feature": "slot_feature",
				"feature_animation_channel": "slot_feature",
			},
		},
		"machine_key": str(machine.get("machine_key", "")),
		"slot_skin": skin,
		"slot_format_id": str(machine.get("format_id", "")),
		"slot_type_id": str(machine.get("type_id", "pinball")),
		"slot_cabinet_identity": str(skin.get("cabinet_identity", "")),
		"slot_cabinet_title": str(skin.get("cabinet_title", "")),
		"slot_cabinet_signature": "pinball:pinball:neon:live",
		"slot_reel_count": int(machine.get("reel_count", 3)),
		"slot_row_count": int(machine.get("row_count", 1)),
		"slot_grid": [],
		"slot_previous_grid": [],
		"slot_reel_stops": [],
		"slot_reel_strips": [],
		"slot_reel_stop_times": [],
		"slot_reel_timeline": [],
		"slot_animation_plan": {},
		"slot_animation_id": animation_id,
		"slot_animation_duration_msec": int(machine.get("slot_animation_duration_msec", 0)),
		"slot_visual_time_msec": surface_time_msec,
		"slot_attract_phase": 0.0,
		"slot_bonus_start_time": 0,
		"slot_audio_cues": [],
		"slot_feature_scene": pinball_scene,
		"slot_bonus_steps": [],
		"slot_bonus_total": int(live.get("feature_total", live.get("pending_award", 0))),
		"slot_payout": int(machine.get("last_payout", 0)),
		"slot_stake_cost": int(machine.get("last_stake_cost", 0)),
		"slot_net": int(machine.get("last_net", 0)),
		"slot_classification": str(machine.get("last_classification", "bonus")),
		"slot_active_bonus": live,
		"slot_active_bonus_active": true,
		"slot_fixed_bet_ladder": true,
		"bet_options": [],
		"slot_bet_options": [],
		"selected_bet_id": selected_bet_id,
		"selected_bet_total_credits": selected_bet_total,
		"slot_selected_bet_id": selected_bet_id,
		"selected_stake": selected_bet_total,
		"slot_selected_bet": selected_bet_total,
		"bankroll": run_state.bankroll if run_state != null else 0,
		"suspicion_level": run_state.suspicion_level() if run_state != null else 0,
		"result_message": result_message,
		"outcome_message": result_message,
		"has_recent_outcome": true,
	}


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


func _display_active_bonus(machine: Dictionary, active_bonus: Dictionary, surface_time_msec: int = 0) -> Dictionary:
	var live: Dictionary = _copy_dict_shallow(active_bonus)
	if bool(live.get("active", false)) and not bool(live.get("complete", false)):
		return _pinball_display_bonus(live, surface_time_msec)
	if not str(machine.get("slot_animation_id", "")).begins_with("bonus:"):
		return _pinball_display_bonus(live, surface_time_msec)
	var replay: Dictionary = _copy_dict_shallow(machine.get("last_bonus_replay", {}))
	if replay.is_empty() or not ["pinball", "buffalo"].has(str(replay.get("family", ""))):
		return _pinball_display_bonus(live, surface_time_msec)
	var plan: Dictionary = _copy_dict(machine.get("slot_animation_plan", {}))
	var plan_duration := maxi(0, int(plan.get("feature_duration_msec", 0)))
	if plan_duration <= 0:
		return _pinball_display_bonus(live, surface_time_msec)
	if surface_time_msec > plan_duration:
		return _pinball_display_bonus(live, surface_time_msec)
	replay["active"] = true
	replay["complete"] = true
	replay["visual_replay"] = true
	var replay_duration := maxi(int(replay.get("animation_duration_msec", 0)), plan_duration)
	if str(replay.get("family", "")) == "buffalo":
		replay_duration = mini(replay_duration, BUFFALO_BONUS_MAX_ANIMATION_MSEC)
	replay["animation_duration_msec"] = replay_duration
	return _pinball_display_bonus(replay, surface_time_msec)


func _pinball_display_bonus(active_bonus: Dictionary, surface_time_msec: int) -> Dictionary:
	if str(active_bonus.get("family", "")) != "pinball":
		return active_bonus
	return PinballFeatureScript.surface_refresh(active_bonus, surface_time_msec)


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


func _nudge_chain_timing_state(offer: Dictionary, ui_state: Dictionary) -> Dictionary:
	if offer.is_empty():
		return {"available": false, "window_active": false, "input_msec": -1, "window_msec": {}, "hint": "", "chain": {}}
	if str(offer.get("type", "")) != "coin_chain":
		var legacy := _nudge_timing_state(offer, ui_state)
		legacy["chain"] = {}
		return legacy
	var coins: Array = _copy_array(offer.get("coins", []))
	var active_index := clampi(int(offer.get("active_index", 0)), 0, maxi(0, coins.size() - 1))
	var active_coin: Dictionary = _copy_dict(coins[active_index]) if active_index < coins.size() else {}
	var input_msec := _surface_nudge_chain_elapsed_msec(ui_state)
	var window: Dictionary = _nudge_chain_window_for_surface(offer, active_coin, input_msec)
	var distance := int(window.get("distance_msec", 9999))
	var perfect_width := maxi(1, int(offer.get("skill_perfect_msec", 75)))
	var good_width := maxi(perfect_width, int(offer.get("skill_good_msec", offer.get("skill_close_msec", 210))))
	var ready_msec := maxi(0, int(active_coin.get("ready_msec", 0)))
	var window_active := input_msec >= int(window.get("start", 0)) and input_msec <= int(window.get("end", 0))
	var hint := "watch the coin"
	if input_msec < ready_msec:
		hint = "coin incoming"
	elif window_active:
		hint = "perfect timing" if distance <= perfect_width else "good timing" if distance <= good_width else "line it up"
	else:
		hint = "line it up"
	var chain := offer.duplicate(true)
	chain["active_coin"] = active_coin
	chain["active_window_msec"] = window
	chain["input_msec"] = input_msec
	chain["window_active"] = window_active
	chain["hint"] = hint
	return {
		"available": true,
		"window_active": window_active,
		"input_msec": input_msec,
		"window_msec": window,
		"hint": hint,
		"chain": chain,
	}


func _surface_nudge_chain_elapsed_msec(ui_state: Dictionary) -> int:
	if int(ui_state.get("slot_nudge_chain_input_msec", -1)) >= 0:
		return int(ui_state.get("slot_nudge_chain_input_msec", -1))
	var runtime: Dictionary = _copy_dict(ui_state.get("surface_runtime_status", {}))
	var animations: Dictionary = _copy_dict(runtime.get("surface_animations", {}))
	var chain: Dictionary = _copy_dict(animations.get("slot_nudge_chain", {}))
	if not chain.is_empty():
		return maxi(0, int(round(float(chain.get("elapsed", 0.0)) * 1000.0)))
	if int(ui_state.get("slot_tease_input_msec", -1)) >= 0:
		return int(ui_state.get("slot_tease_input_msec", -1))
	return maxi(0, int(ui_state.get("surface_time_msec", ui_state.get("drunk_scaled_surface_time_msec", 0))))


func _nudge_chain_window_for_surface(offer: Dictionary, coin: Dictionary, input_msec: int) -> Dictionary:
	var ready_msec := maxi(0, int(coin.get("ready_msec", 0)))
	var cycle := maxi(1, int(offer.get("peek_cycle_msec", 1200)))
	var good_width := maxi(1, int(offer.get("skill_good_msec", offer.get("skill_close_msec", 210))))
	var local := input_msec - ready_msec
	var cycle_index := maxi(0, int(floor(float(maxi(0, local)) / float(cycle))))
	var apex := ready_msec + cycle_index * cycle + cycle / 2
	var next_apex := apex + cycle
	if absi(input_msec - next_apex) < absi(input_msec - apex):
		apex = next_apex
	return {
		"start": apex - good_width,
		"perfect": apex,
		"end": apex + good_width,
		"distance_msec": absi(input_msec - apex),
		"cycle_msec": cycle,
	}


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
	var buckets: Dictionary = _copy_dict(bonus_state.get("per_bet", {}))
	var bet_id := str(selected_bet.get("id", active_bonus.get("bet_id", "bet_2")))
	var bucket: Dictionary = _copy_dict(buckets.get(bet_id, {}))
	var stored := maxi(0, int(bucket.get("buffalo_grand_prize", 0)))
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
	var chain_offer: Dictionary = _copy_dict(machine.get("last_nudge_offer", {}))
	if str(chain_offer.get("type", "")) == "coin_chain":
		var active_index := int(chain_offer.get("active_index", 0))
		var coins: Array = _copy_array(chain_offer.get("coins", []))
		var active_coin: Dictionary = _copy_dict(coins[active_index]) if active_index >= 0 and active_index < coins.size() else {}
		var cycle := maxi(1, int(chain_offer.get("peek_cycle_msec", 1200)))
		var ready_msec := maxi(0, int(active_coin.get("ready_msec", chain_offer.get("first_ready_msec", 0))))
		var apex_sec := float(ready_msec + cycle / 2) / 1000.0
		cues.append({"phase": "nudge_chain_peek", "cue_id": "gold_coin_tease", "time_sec": maxf(0.0, apex_sec - 0.16), "marker": "nudge_chain_peek_%d" % active_index, "volume_db": 1.0 + float(active_index) * 0.25, "pitch": 0.96 + float(active_index) * 0.035})
		var last_grade := str(chain_offer.get("last_grade", ""))
		if last_grade == "perfect" or last_grade == "good":
			var collect_sec := float(maxi(0, int(chain_offer.get("last_input_msec", 0)))) / 1000.0
			cues.append({"phase": "nudge_chain_collect", "cue_id": "bonus_step_buffalo" if str(machine.get("type_id", "")) == "buffalo" else "bumper", "time_sec": collect_sec, "marker": "nudge_chain_collect_%d_%s" % [int(chain_offer.get("collected_count", 0)), last_grade], "volume_db": 0.8, "pitch": 1.0 + float(int(chain_offer.get("collected_count", 0))) * 0.045})
			if bool(chain_offer.get("last_spawned", false)):
				cues.append({"phase": "nudge_chain_spawn", "cue_id": "double_gold_coin_tease", "time_sec": collect_sec + 0.08, "marker": "nudge_chain_spawn_%d" % active_index, "volume_db": 1.4, "pitch": 1.06 + float(active_index) * 0.035})
	else:
		for event_value in _copy_array(machine.get("last_tease_events", [])):
			var event: Dictionary = _copy_dict(event_value)
			if str(event.get("type", "")) == "nudge_coin_chain" and str(event.get("skill_outcome", "")) == "clean_miss":
				cues.append({"phase": "nudge_chain_break", "cue_id": "lose", "time_sec": 0.0, "marker": "nudge_chain_break_%d" % int(event.get("coin_index", 0)), "volume_db": -3.0, "pitch": 0.86})
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
		"history": [] if str(active_bonus.get("family", "")) == "pinball" else _copy_array(active_bonus.get("history", [])),
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
	var alert_active := _pinball_bonus_alert_active(active_bonus)
	var phase := "launch"
	if bool(active_bonus.get("complete", false)):
		phase = "celebration"
	elif bool(active_bonus.get("launch_in_progress", false)):
		phase = "play"
	var feature_music: Dictionary = {}
	if alert_active:
		feature_music = {
			"cue_id": "bonus_music_pinball",
			"loop": true,
			"style": "kinetic_plinko_feature",
			"volume_db": PINBALL_BONUS_ALERT_VOLUME_DB,
			"pitch": 1.0 + clampf(float(step_index) / float(total_steps + 2), 0.0, 0.10),
		}
	return {
		"feature_phase": phase,
		"feature_music": feature_music,
		"launch_meter": _copy_dict_shallow(active_bonus.get("pinball_launch_meter", {})),
		"audio_cues": _pinball_feature_audio_cues(active_bonus, phase, alert_active),
	}


func _pinball_feature_audio_cues(active_bonus: Dictionary, phase: String, alert_active: bool) -> Array:
	var cues: Array = []
	if alert_active:
		cues.append({"phase": "feature_transition", "cue_id": "pinball_feature_intro", "time_sec": 0.08, "marker": "pinball_feature_intro", "volume_db": PINBALL_BONUS_ALERT_STINGER_VOLUME_DB})
		if phase == "launch":
			cues.append({"phase": "plunger_charge", "cue_id": "pinball_plunger_charge", "time_sec": 0.22, "marker": "pinball_plunger_charge", "volume_db": PINBALL_BONUS_ALERT_STINGER_VOLUME_DB})
		else:
			cues.append({"phase": "table_music", "cue_id": "pinball_shot_counter", "time_sec": 0.38, "marker": "pinball_shot_counter", "volume_db": PINBALL_BONUS_ALERT_STINGER_VOLUME_DB})
	var recent: Array = _pinball_recent_audio_events(active_bonus)
	for index in range(mini(recent.size(), 6)):
		var event: Dictionary = _copy_dict_shallow(recent[index])
		var event_type := str(event.get("element_type", ""))
		var cue_id := _pinball_event_cue_id(event_type)
		var award := maxi(0, int(event.get("award", 0)))
		var volume := -4.0 + minf(5.0, float(award) * 0.08)
		cues.append({"phase": "pinball_hit", "cue_id": cue_id, "time_sec": 0.54 + float(index) * 0.075, "marker": "pinball_hit_%d_%s" % [index, event_type], "pitch": 0.92 + float(index) * 0.025 + minf(0.18, float(award) * 0.004), "volume_db": volume})
	return cues


func _with_pinball_alert_metadata(active_bonus: Dictionary, machine: Dictionary) -> Dictionary:
	if str(active_bonus.get("family", "")) != "pinball":
		return active_bonus
	var result: Dictionary = active_bonus.duplicate(false)
	result["slot_pending_feature_alert"] = bool(machine.get("slot_pending_feature_alert", false))
	result["slot_pending_feature_alert_msec"] = maxi(0, int(machine.get("slot_pending_feature_alert_msec", 0)))
	return result


func _pinball_bonus_alert_active(active_bonus: Dictionary) -> bool:
	if not bool(active_bonus.get("slot_pending_feature_alert", false)):
		return false
	var alert_msec := maxi(0, int(active_bonus.get("slot_pending_feature_alert_msec", 0)))
	if alert_msec <= 0:
		return false
	var age_msec := maxi(0, Time.get_ticks_msec() - alert_msec)
	return age_msec <= PINBALL_BONUS_ALERT_DURATION_MSEC


func _pinball_recent_audio_events(active_bonus: Dictionary) -> Array:
	var source: Array = []
	var display_value: Variant = active_bonus.get("display_event_log", [])
	if typeof(display_value) == TYPE_ARRAY and not (display_value as Array).is_empty():
		source = display_value as Array
	else:
		var event_value: Variant = active_bonus.get("event_log", [])
		if typeof(event_value) == TYPE_ARRAY:
			source = event_value as Array
	var result: Array = []
	var start_index := maxi(0, source.size() - 6)
	for index in range(start_index, source.size()):
		if typeof(source[index]) == TYPE_DICTIONARY:
			result.append(source[index])
	return result


func _pinball_event_cue_id(event_type: String) -> String:
	match event_type:
		"peg":
			return "pinball_peg_tick"
		"bumper", "slingshot":
			return "pinball_bumper_pop"
		"launcher", "spawner":
			return "pinball_launcher_fire"
		"target":
			return "pinball_target_hit"
		"gate", "multiplier":
			return "pinball_gate_chime"
		"pocket":
			return "pinball_cup_hit"
		"jackpot":
			return "pinball_jackpot_lane"
		"super_jackpot":
			return "pinball_super_jackpot"
		"drain":
			return "pinball_drain"
		"flipper":
			return "pinball_flipper"
		_:
			return "pinball_shot_counter"


func _pinball_launch_meter(active_bonus: Dictionary, surface_time_msec: int) -> Dictionary:
	var meter: Dictionary = PinballFeatureScript.launch_meter_snapshot(active_bonus, surface_time_msec, false)
	meter["sampled_power"] = int(meter.get("power", active_bonus.get("launch_power", 70)))
	meter["lane"] = str(active_bonus.get("selected_lane", "center"))
	meter["angle_degrees"] = clampi(int(active_bonus.get("launch_angle_degrees", 0)), -60, 60)
	return meter


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
			"volume_db": -5.0,
			"priority": "feature",
			"duck_background_music": true,
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
		if typeof(event_value) == TYPE_DICTIONARY and (str((event_value as Dictionary).get("type", "")) == "nudge_shift" or str((event_value as Dictionary).get("type", "")) == "nudge_coin_chain"):
			return true
	return false


func _surface_machine_view(machine: Dictionary) -> Dictionary:
	return machine.duplicate(false)


func _slot_surface_spec(payload: Dictionary = {}) -> Dictionary:
	var spec := payload.duplicate(false)
	spec["surface_renderer"] = str(spec.get("surface_renderer", spec.get("renderer", "result")))
	spec["surface_life"] = str(spec.get("surface_life", spec.get("surface_renderer", "result")))
	spec["surface_cast"] = str(spec.get("surface_cast", "none"))
	spec["surface_controls_native"] = bool(spec.get("surface_controls_native", false))
	spec["surface_fixed_price_actions"] = bool(spec.get("surface_fixed_price_actions", false))
	spec["surface_stake_controls_required"] = bool(spec.get("surface_stake_controls_required", true))
	spec["surface_animates_idle"] = bool(spec.get("surface_animates_idle", false))
	spec["surface_realtime_state_refresh"] = bool(spec.get("surface_realtime_state_refresh", false))
	spec["surface_embeds_outcomes"] = bool(spec.get("surface_embeds_outcomes", false))
	spec["surface_suppresses_game_result_burst"] = bool(spec.get("surface_suppresses_game_result_burst", false))
	spec["surface_action_bindings"] = _copy_dict(spec.get("surface_action_bindings", {}))
	spec["native_selected_surface_actions"] = _copy_array(spec.get("native_selected_surface_actions", []))
	if bool(spec.get("surface_animation_channels_normalized", false)):
		spec["surface_animation_channels"] = _copy_array_shallow(spec.get("surface_animation_channels", []))
	else:
		spec["surface_animation_channels"] = GameModule._normalize_surface_animation_channels(spec.get("surface_animation_channels", []))
	spec.erase("surface_animation_channels_normalized")
	spec["surface_audio"] = _copy_dict_shallow(spec.get("surface_audio", {}))
	spec["surface_action_blocks"] = _copy_array(spec.get("surface_action_blocks", []))
	spec["surface_state_labels"] = _copy_array(spec.get("surface_state_labels", []))
	spec["surface_result_display"] = _copy_dict(spec.get("surface_result_display", {}))
	return spec


func _surface_bonus_steps(active_bonus: Dictionary) -> Array:
	if str(active_bonus.get("family", "")) == "pinball":
		return []
	return _copy_array(active_bonus.get("history", []))


func _copy_dict_shallow(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(false)


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _copy_array_shallow(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(false)


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
