class_name SlotMachineState
extends RefCounted

# Canonical persistent slot state schema and normalization.

const SCHEMA_VERSION := 1
const BET_OPTIONS := [
	{"id": "bet_2", "label": "MIN", "total_credits": 2},
	{"id": "bet_5", "label": "LOW", "total_credits": 5},
	{"id": "bet_10", "label": "MID", "total_credits": 10},
	{"id": "bet_15", "label": "HIGH", "total_credits": 15},
	{"id": "bet_20", "label": "MAX", "total_credits": 20},
]


static func read_machine(environment: Dictionary, game_id: String) -> Dictionary:
	var states: Dictionary = _copy_dict(environment.get("game_states", {}))
	var machine: Variant = states.get(game_id, {})
	if typeof(machine) != TYPE_DICTIONARY:
		return {}
	return (machine as Dictionary).duplicate(true)


static func write_machine(environment: Dictionary, game_id: String, machine: Dictionary) -> void:
	var states: Dictionary = _copy_dict(environment.get("game_states", {}))
	states[game_id] = normalize(machine)
	environment["game_states"] = states


static func normalize(machine_value: Variant) -> Dictionary:
	var machine: Dictionary = _copy_dict(machine_value)
	machine["schema_version"] = SCHEMA_VERSION
	machine["format_id"] = str(machine.get("format_id", "classic_3_reel"))
	machine["type_id"] = str(machine.get("type_id", "pinball"))
	machine["math_variant_id"] = str(machine.get("math_variant_id", "standard"))
	machine["cabinet_variant_id"] = str(machine.get("cabinet_variant_id", "neon_magenta"))
	machine["bonus_variant_id"] = str(machine.get("bonus_variant_id", "plain"))
	machine["machine_key"] = str(machine.get("machine_key", "%s:%s:%s:%s:%s" % [
		machine["format_id"],
		machine["type_id"],
		machine["math_variant_id"],
		machine["bonus_variant_id"],
		machine["cabinet_variant_id"],
	]))
	machine["reel_count"] = maxi(1, int(machine.get("reel_count", 3)))
	machine["row_count"] = maxi(1, int(machine.get("row_count", 1)))
	machine["pay_model"] = str(machine.get("pay_model", "single_line"))
	machine["reel_heights"] = _int_array(machine.get("reel_heights", []))
	machine["reel_strips"] = _strip_array(machine.get("reel_strips", []))
	machine["bonus_reel_strips"] = _strip_array(machine.get("bonus_reel_strips", machine.get("reel_strips", [])))
	machine["reel_stops"] = _int_array(machine.get("reel_stops", []))
	machine["last_grid"] = _grid_array(machine.get("last_grid", _blank_grid(int(machine["reel_count"]), int(machine["row_count"]))))
	machine["last_previous_grid"] = _grid_array(machine.get("last_previous_grid", []))
	machine["last_reels"] = _copy_array(machine.get("last_reels", []))
	machine["last_payout"] = maxi(0, int(machine.get("last_payout", 0)))
	machine["last_net"] = int(machine.get("last_net", 0))
	machine["last_stake_cost"] = maxi(0, int(machine.get("last_stake_cost", 0)))
	machine["last_line_payout"] = maxi(0, int(machine.get("last_line_payout", 0)))
	machine["last_classification"] = str(machine.get("last_classification", "idle"))
	machine["last_outcome_id"] = str(machine.get("last_outcome_id", ""))
	machine["previous_result_payout"] = maxi(0, int(machine.get("previous_result_payout", 0)))
	machine["previous_result_net"] = int(machine.get("previous_result_net", 0))
	machine["previous_result_classification"] = str(machine.get("previous_result_classification", "idle"))
	machine["previous_result_reason"] = str(machine.get("previous_result_reason", ""))
	machine["free_spins"] = maxi(0, int(machine.get("free_spins", 0)))
	machine["spin_count"] = maxi(0, int(machine.get("spin_count", 0)))
	machine["coin_in"] = maxi(0, int(machine.get("coin_in", 0)))
	machine["coin_out"] = maxi(0, int(machine.get("coin_out", 0)))
	machine["last_bonus_total"] = maxi(0, int(machine.get("last_bonus_total", 0)))
	machine["last_bonus_mode"] = str(machine.get("last_bonus_mode", ""))
	machine["last_bonus_complete"] = bool(machine.get("last_bonus_complete", false))
	var last_bonus_replay: Dictionary = _copy_dict(machine.get("last_bonus_replay", {}))
	machine["last_bonus_replay"] = _normalize_active_bonus(last_bonus_replay) if not last_bonus_replay.is_empty() else {}
	machine["last_tease_events"] = _copy_array(machine.get("last_tease_events", []))
	machine["last_nudge_offer"] = _copy_dict(machine.get("last_nudge_offer", {}))
	machine["slot_animation_id"] = str(machine.get("slot_animation_id", ""))
	machine["slot_animation_duration_msec"] = maxi(0, int(machine.get("slot_animation_duration_msec", 0)))
	machine["slot_animation_started_msec"] = maxi(0, int(machine.get("slot_animation_started_msec", 0)))
	machine["slot_autoplay_active"] = bool(machine.get("slot_autoplay_active", false))
	machine["slot_autoplay_next_msec"] = maxi(0, int(machine.get("slot_autoplay_next_msec", 0)))
	machine["active_bonus"] = _normalize_active_bonus(machine.get("active_bonus", {}))
	machine["bonus_state"] = _normalize_bonus_state(machine.get("bonus_state", {}))
	machine["bet_ladder"] = _normalize_bet_ladder(machine.get("bet_ladder", {}))
	machine["pinball_feature_state"] = _copy_dict(machine.get("pinball_feature_state", {}))
	machine["buffalo_feature_state"] = _copy_dict(machine.get("buffalo_feature_state", {}))
	return machine


static func selected_bet(machine: Dictionary) -> Dictionary:
	var ladder: Dictionary = _normalize_bet_ladder(machine.get("bet_ladder", {}))
	var selected_id := str(ladder.get("selected_id", "bet_2"))
	for option_value in BET_OPTIONS:
		var option: Dictionary = option_value
		if str(option.get("id", "")) == selected_id:
			return option.duplicate(true)
	return (BET_OPTIONS[0] as Dictionary).duplicate(true)


static func set_selected_bet(machine: Dictionary, bet_id: String) -> Dictionary:
	var ladder: Dictionary = _normalize_bet_ladder(machine.get("bet_ladder", {}))
	for option_value in BET_OPTIONS:
		var option: Dictionary = option_value
		if str(option.get("id", "")) == bet_id:
			ladder["selected_id"] = bet_id
			ladder["selected_total"] = int(option.get("total_credits", 2))
			machine["bet_ladder"] = ladder
			return machine
	return machine


static func set_selected_bet_by_index(machine: Dictionary, index: int) -> Dictionary:
	var safe_index := clampi(index, 0, BET_OPTIONS.size() - 1)
	var option: Dictionary = BET_OPTIONS[safe_index]
	return set_selected_bet(machine, str(option.get("id", "bet_2")))


static func per_bet_bucket(machine: Dictionary, bet_id: String) -> Dictionary:
	var bonus_state: Dictionary = _normalize_bonus_state(machine.get("bonus_state", {}))
	var buckets: Dictionary = _copy_dict(bonus_state.get("per_bet", {}))
	if not buckets.has(bet_id) or typeof(buckets.get(bet_id)) != TYPE_DICTIONARY:
		buckets[bet_id] = _default_per_bet_bucket()
	bonus_state["per_bet"] = buckets
	machine["bonus_state"] = bonus_state
	return (buckets[bet_id] as Dictionary).duplicate(true)


static func set_per_bet_bucket(machine: Dictionary, bet_id: String, bucket: Dictionary) -> void:
	var bonus_state: Dictionary = _normalize_bonus_state(machine.get("bonus_state", {}))
	var buckets: Dictionary = _copy_dict(bonus_state.get("per_bet", {}))
	buckets[bet_id] = _normalize_per_bet_bucket(bucket)
	bonus_state["per_bet"] = buckets
	machine["bonus_state"] = bonus_state


static func active_bonus_incomplete(machine: Dictionary) -> bool:
	var active: Dictionary = _normalize_active_bonus(machine.get("active_bonus", {}))
	return bool(active.get("active", false)) and not bool(active.get("complete", false))


static func canonical_geometry(definition: Dictionary, family_id: String, format_id: String) -> Dictionary:
	for format_value in _dictionary_array(definition.get("slot_formats", [])):
		var format: Dictionary = format_value
		if str(format.get("id", "")) != format_id:
			continue
		var geometries: Dictionary = _copy_dict(format.get("geometry", {}))
		var geometry: Dictionary = _copy_dict(geometries.get(family_id, {}))
		if not geometry.is_empty():
			return {
				"reel_count": maxi(1, int(geometry.get("reel_count", 3))),
				"row_count": maxi(1, int(geometry.get("row_count", 1))),
				"pay_model": str(geometry.get("pay_model", format.get("pay_model", "single_line"))),
			}
	return {"reel_count": 3, "row_count": 1, "pay_model": "single_line"}


static func behavior_combo_count(definition: Dictionary) -> int:
	return _dictionary_array(definition.get("slot_formats", [])).size() * _dictionary_array(definition.get("slot_types", [])).size() * _dictionary_array(definition.get("slot_math_variants", [])).size() * _dictionary_array(definition.get("slot_bonus_variants", [])).size()


static func visual_machine_count(definition: Dictionary) -> int:
	return behavior_combo_count(definition) * _dictionary_array(definition.get("slot_cabinet_variants", [])).size()


static func _normalize_bet_ladder(value: Variant) -> Dictionary:
	var ladder: Dictionary = _copy_dict(value)
	var selected_id := str(ladder.get("selected_id", "bet_2"))
	var selected_total := 2
	var found := false
	for option_value in BET_OPTIONS:
		var option: Dictionary = option_value
		if str(option.get("id", "")) == selected_id:
			selected_total = int(option.get("total_credits", 2))
			found = true
			break
	if not found:
		selected_id = "bet_2"
		selected_total = 2
	return {
		"options": BET_OPTIONS.duplicate(true),
		"selected_id": selected_id,
		"selected_total": selected_total,
		"locked": bool(ladder.get("locked", false)),
		"locked_bet_id": str(ladder.get("locked_bet_id", "")),
		"locked_total": maxi(0, int(ladder.get("locked_total", 0))),
	}


static func _normalize_bonus_state(value: Variant) -> Dictionary:
	var source: Dictionary = _copy_dict(value)
	var per_bet: Dictionary = _copy_dict(source.get("per_bet", {}))
	for option_value in BET_OPTIONS:
		var option: Dictionary = option_value
		var bet_id := str(option.get("id", ""))
		per_bet[bet_id] = _normalize_per_bet_bucket(per_bet.get(bet_id, {}))
	return {
		"per_bet": per_bet,
		"gold_buffalo_total_collected": maxi(0, int(source.get("gold_buffalo_total_collected", 0))),
		"gold_buffalo_conversions": maxi(0, int(source.get("gold_buffalo_conversions", 0))),
		"buffalo_grand_prize": maxi(0, int(source.get("buffalo_grand_prize", 0))),
		"must_hit_forces": maxi(0, int(source.get("must_hit_forces", 0))),
		"feature_completions": maxi(0, int(source.get("feature_completions", 0))),
	}


static func _normalize_per_bet_bucket(value: Variant) -> Dictionary:
	var bucket: Dictionary = _copy_dict(value)
	return {
		"gold_buffalo_heads": clampi(int(bucket.get("gold_buffalo_heads", 0)), 0, 1000000),
		"gold_buffalo_max_seen": maxi(0, int(bucket.get("gold_buffalo_max_seen", 0))),
		"must_hit_meter": maxi(100, int(bucket.get("must_hit_meter", 100))),
		"must_hit_ready": bool(bucket.get("must_hit_ready", false)),
		"feature_completion_count": maxi(0, int(bucket.get("feature_completion_count", 0))),
	}


static func _default_per_bet_bucket() -> Dictionary:
	return {
		"gold_buffalo_heads": 0,
		"gold_buffalo_max_seen": 0,
		"must_hit_meter": 100,
		"must_hit_ready": false,
		"feature_completion_count": 0,
	}


static func _normalize_active_bonus(value: Variant) -> Dictionary:
	var active: Dictionary = _copy_dict(value)
	if active.is_empty():
		return {"active": false, "complete": true}
	active["active"] = bool(active.get("active", false))
	active["complete"] = bool(active.get("complete", not bool(active.get("active", false))))
	active["mode"] = str(active.get("mode", ""))
	active["family"] = str(active.get("family", ""))
	active["visual_replay"] = bool(active.get("visual_replay", false))
	active["bet_id"] = str(active.get("bet_id", ""))
	active["stake"] = maxi(0, int(active.get("stake", 0)))
	active["pending_award"] = maxi(0, int(active.get("pending_award", 0)))
	active["feature_total"] = maxi(0, int(active.get("feature_total", active.get("pending_award", 0))))
	active["awarded"] = maxi(0, int(active.get("awarded", 0)))
	active["remaining_steps"] = maxi(0, int(active.get("remaining_steps", 0)))
	active["total_steps"] = maxi(0, int(active.get("total_steps", 0)))
	active["step_index"] = maxi(0, int(active.get("step_index", 0)))
	active["history"] = _copy_array(active.get("history", []))
	active["choices"] = _copy_array(active.get("choices", []))
	active["shot_queue"] = _copy_array(active.get("shot_queue", []))
	active["locks"] = _copy_array(active.get("locks", []))
	active["launch_power"] = clampi(int(active.get("launch_power", 50)), 0, 100)
	active["launch_angle_degrees"] = clampi(int(active.get("launch_angle_degrees", 0)), -60, 60)
	active["launch_start"] = _copy_dict(active.get("launch_start", {}))
	active["selected_path"] = str(active.get("selected_path", ""))
	active["display_mode"] = str(active.get("display_mode", ""))
	active["selected_lane"] = str(active.get("selected_lane", "center"))
	active["balls_remaining"] = maxi(0, int(active.get("balls_remaining", active.get("remaining_steps", 0))))
	active["respins_remaining"] = maxi(0, int(active.get("respins_remaining", active.get("remaining_steps", 0))))
	active["max_cells"] = maxi(0, int(active.get("max_cells", 0)))
	active["retrigger_count"] = maxi(0, int(active.get("retrigger_count", 0)))
	active["spin_win_total"] = maxi(0, int(active.get("spin_win_total", active.get("feature_total", 0))))
	active["collected_coins"] = _copy_array(active.get("collected_coins", []))
	active["last_collected_coins"] = _copy_array(active.get("last_collected_coins", []))
	active["coins_collected"] = maxi(0, int(active.get("coins_collected", 0)))
	active["coins_since_retrigger"] = maxi(0, int(active.get("coins_since_retrigger", 0)))
	active["coin_total"] = maxi(0, int(active.get("coin_total", 0)))
	active["coin_collect_total"] = maxi(0, int(active.get("coin_collect_total", 0)))
	active["coin_collect_awarded"] = bool(active.get("coin_collect_awarded", false))
	active["coin_reveals"] = _copy_array(active.get("coin_reveals", []))
	active["coin_reveal_total"] = maxi(0, int(active.get("coin_reveal_total", active.get("coin_collect_total", 0))))
	active["last_retrigger_grant"] = maxi(0, int(active.get("last_retrigger_grant", 0)))
	active["lane_locks"] = maxi(0, int(active.get("lane_locks", 0)))
	active["lit_jackpots"] = maxi(0, int(active.get("lit_jackpots", 0)))
	active["survival_ticks"] = maxi(0, int(active.get("survival_ticks", 0)))
	active["session_cap"] = maxi(0, int(active.get("session_cap", 0)))
	active["grand_prize"] = maxi(0, int(active.get("grand_prize", 0)))
	active["grand_prize_awarded"] = maxi(0, int(active.get("grand_prize_awarded", 0)))
	active["nudge_request"] = clampi(int(active.get("nudge_request", 0)), -4, 4)
	active["feature_scale"] = maxf(0.0, float(active.get("feature_scale", 1.0)))
	active["physics"] = _copy_dict(active.get("physics", {}))
	active["pinball_session"] = _copy_dict(active.get("pinball_session", {}))
	active["event_log"] = _copy_array(active.get("event_log", []))
	active["trajectory"] = _copy_array(active.get("trajectory", []))
	active["display_event_log"] = _copy_array(active.get("display_event_log", []))
	active["display_trajectory"] = _copy_array(active.get("display_trajectory", []))
	active["animation_duration_msec"] = maxi(0, int(active.get("animation_duration_msec", 0)))
	active["launch_in_progress"] = bool(active.get("launch_in_progress", false))
	active["physics_tick_budget"] = maxi(0, int(active.get("physics_tick_budget", 0)))
	active["physics_frame_index"] = maxi(0, int(active.get("physics_frame_index", 0)))
	active["current_launch_start_event_index"] = maxi(0, int(active.get("current_launch_start_event_index", 0)))
	active["current_launch_start_trajectory_index"] = maxi(0, int(active.get("current_launch_start_trajectory_index", 0)))
	active["live_input"] = _copy_dict(active.get("live_input", {}))
	active["max_active_count"] = maxi(0, int(active.get("max_active_count", 0)))
	active["multiball_started"] = bool(active.get("multiball_started", false))
	active["nudge_used"] = bool(active.get("nudge_used", false))
	active["video_targets"] = _copy_dict(active.get("video_targets", {}))
	active["video_super_jackpot_lit"] = bool(active.get("video_super_jackpot_lit", false))
	active["video_super_jackpots"] = maxi(0, int(active.get("video_super_jackpots", 0)))
	active["video_jackpots"] = maxi(0, int(active.get("video_jackpots", 0)))
	active["video_completed_banks"] = maxi(0, int(active.get("video_completed_banks", 0)))
	active["video_multiball_ready"] = bool(active.get("video_multiball_ready", false))
	active["jackpot_tier"] = str(active.get("jackpot_tier", ""))
	active["feature_phase"] = str(active.get("feature_phase", ""))
	active["collection_meter"] = _copy_dict(active.get("collection_meter", {}))
	active["fill_meter"] = _copy_dict(active.get("fill_meter", {}))
	active["jackpot_ladder"] = _copy_dict(active.get("jackpot_ladder", {}))
	active["last_lock_events"] = _copy_array(active.get("last_lock_events", []))
	active["gateway_type"] = str(active.get("gateway_type", ""))
	active["feature_origin"] = str(active.get("feature_origin", ""))
	active["trophy_pick_active"] = bool(active.get("trophy_pick_active", false))
	active["trophy_choices"] = _copy_array(active.get("trophy_choices", []))
	active["trophy_reveals"] = _copy_array(active.get("trophy_reveals", []))
	active["trophy_selected_path"] = str(active.get("trophy_selected_path", ""))
	active["wheel_angle"] = int(active.get("wheel_angle", 0))
	return active


static func _blank_grid(reel_count: int, row_count: int) -> Array:
	var grid: Array = []
	for _reel_index in range(maxi(1, reel_count)):
		var column: Array = []
		for _row_index in range(maxi(1, row_count)):
			column.append("BLANK")
		grid.append(column)
	return grid


static func _grid_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var source: Array = value as Array
	for column_value in source:
		if typeof(column_value) == TYPE_ARRAY:
			var column: Array = []
			var cells: Array = column_value as Array
			for cell in cells:
				column.append(str(cell))
			result.append(column)
	return result


static func _strip_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var source: Array = value as Array
	for strip_value in source:
		if typeof(strip_value) == TYPE_ARRAY:
			var strip: Array = []
			var symbols: Array = strip_value as Array
			for symbol in symbols:
				strip.append(str(symbol))
			result.append(strip)
	return result


static func _int_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var source: Array = value as Array
	for entry in source:
		result.append(int(entry))
	return result


static func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var source: Array = value as Array
	for entry in source:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


static func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
