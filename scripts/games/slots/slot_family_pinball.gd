class_name SlotFamilyPinball
extends RefCounted

const MathScript := preload("res://scripts/games/slots/slot_rng_math.gd")
const TableScript := preload("res://scripts/games/slots/slot_pinball_table.gd")

const FAMILY_ID := "pinball"
const FEATURE_CLASS := "bonus"
const VIDEO_TARGET_IDS := ["target_alpha", "target_beta", "target_gamma"]
const VIDEO_MULTIBALL_LOCKS := 2
const LIVE_HISTORY_LIMIT := 24
const FILL_REEL_SYMBOLS := [
	["BUMPER", "CHERRY"],
	["BALL", "BAR"],
	["SPINNER", "7"],
	["CHERRY", "BAR"],
	["BALL", "SPINNER"],
	["BUMPER", "7"],
]
const LAUNCH_ANGLE_MIN_DEGREES := -60
const LAUNCH_ANGLE_MAX_DEGREES := 60
const LAUNCH_ANGLE_STEP_DEGREES := 4
const LAUNCH_ANGLE_LANE_THRESHOLD_DEGREES := 8
const LIVE_TICK_BUDGET := 2
const LIVE_TICK_MAX_BUDGET := 8
const LIVE_TICK_MSEC_PER_SIM_STEP := 8.333333
const DIRECT_AIM_STEPS := 12
const DIRECT_START_STEPS := 10
const DIRECT_POWER_STEPS := 10
const BONUS_AIM_PREFIX := "slot_bonus_aim_"
const BONUS_START_PREFIX := "slot_bonus_start_"
const BONUS_POWER_PREFIX := "slot_bonus_power_"


func outcome_table(machine: Dictionary, definition: Dictionary, _free_spin: bool) -> Array:
	var config: Dictionary = _pinball_config(definition)
	var table: Array = _dictionary_array(config.get("outcome_table", []))
	return _adjusted_table(table, str(machine.get("math_variant_id", "standard")))


func force_outcome_symbols(machine: Dictionary, grid: Array, entry: Dictionary, rng: RngStream, definition: Dictionary) -> Array:
	var result: Array = MathScript.clone_grid(grid)
	var reel_count := maxi(1, int(machine.get("reel_count", 3)))
	var row_count := maxi(1, int(machine.get("row_count", 1)))
	var center_row := clampi(row_count / 2, 0, row_count - 1)
	var classification := str(entry.get("classification", "zero_loss"))
	var placement: Dictionary = {}
	_fill_nonpaying_grid(result, rng)
	match classification:
		"near_miss":
			var line_info := _random_payline(reel_count, row_count, mini(3, reel_count), rng)
			var cells: Array = _copy_array(line_info.get("cells", []))
			for index in range(cells.size()):
				var cell: Dictionary = cells[index]
				MathScript.set_cell(result, int(cell.get("reel", 0)), int(cell.get("row", 0)), "PINBALL" if index < 2 else _safe_pinball_fill_symbol(int(cell.get("reel", 0)), int(cell.get("row", 0)), "PINBALL"))
			placement = {"kind": "tease", "symbol": "PINBALL", "cells": cells.slice(0, mini(2, cells.size())), "line_index": int(line_info.get("line_index", center_row))}
		"ldw":
			var line_info := _random_payline(reel_count, row_count, mini(3, reel_count), rng)
			var cells: Array = _copy_array(line_info.get("cells", []))
			for cell in cells:
				MathScript.set_cell(result, int(cell.get("reel", 0)), int(cell.get("row", 0)), "CHERRY")
			_stop_pinball_extension(result, int(line_info.get("line_index", center_row)), cells, "CHERRY")
			placement = {"kind": "line", "symbol": "CHERRY", "cells": cells, "line_index": int(line_info.get("line_index", center_row))}
		"true_win":
			var format_id := str(machine.get("format_id", "classic_3_reel"))
			var win_plan: Dictionary = _pinball_true_win_plan(reel_count, format_id, rng, definition)
			var win_count := clampi(int(win_plan.get("count", 3)), mini(3, reel_count), reel_count)
			var symbol := str(win_plan.get("symbol", "BALL"))
			var wild_cell_index := int(win_plan.get("wild_cell_index", -1))
			var wild_symbol := str(win_plan.get("wild_symbol", "DOUBLE"))
			var line_info := _random_payline(reel_count, row_count, win_count, rng)
			var cells: Array = _copy_array(line_info.get("cells", []))
			for index in range(cells.size()):
				var cell: Dictionary = cells[index]
				var placed_symbol := wild_symbol if index == wild_cell_index else symbol
				MathScript.set_cell(result, int(cell.get("reel", 0)), int(cell.get("row", 0)), placed_symbol)
			_stop_pinball_extension(result, int(line_info.get("line_index", center_row)), cells, symbol)
			placement = {"kind": "line", "symbol": symbol, "cells": cells, "line_index": int(line_info.get("line_index", center_row))}
		"bonus":
			var cells: Array = MathScript.random_cells(reel_count, row_count, mini(3, reel_count * row_count), rng)
			for cell in cells:
				MathScript.set_cell(result, int((cell as Dictionary).get("reel", 0)), int((cell as Dictionary).get("row", 0)), "PINBALL")
			placement = {"kind": "feature", "symbol": "PINBALL", "cells": cells, "line_index": -1}
	if not placement.is_empty():
		entry["forced_placement"] = placement
	if classification != "bonus":
		_sanitize_pinball_grid(result, definition, _protected_cell_lookup(_copy_array(placement.get("cells", []))))
	return result


func payout_for(entry: Dictionary, stake: int, stake_cost: int, machine: Dictionary, definition: Dictionary) -> int:
	var classification := str(entry.get("classification", "zero_loss"))
	var math_variant: Dictionary = _variant_by_id(definition.get("slot_math_variants", []), str(machine.get("math_variant_id", "standard")))
	var normal_scale := float(math_variant.get("normal_pay_scale", 1.0))
	match classification:
		"ldw":
			if stake_cost <= 1:
				return 0
			return maxi(1, stake_cost + int(entry.get("payout", -1)))
		"true_win":
			var multiplier := float(entry.get("payout_multiplier", 3.0))
			return mini(stake * 2000, int(ceil(float(stake) * multiplier * normal_scale)))
		"bonus":
			return 0
		_:
			return maxi(0, int(entry.get("payout", 0)))


func grid_payout_for_entry(grid: Array, stake: int, stake_cost: int = -1, machine: Dictionary = {}, definition: Dictionary = {}, entry: Dictionary = {}) -> int:
	var classification := str(entry.get("classification", ""))
	var forced_placement: Dictionary = _copy_dict(entry.get("forced_placement", {}))
	if (classification == "true_win" or classification == "ldw") and str(forced_placement.get("kind", "")) == "line":
		var cells: Array = _copy_array(forced_placement.get("cells", []))
		if cells.size() >= mini(3, maxi(1, grid.size())):
			var safe_stake := maxi(1, stake)
			var safe_stake_cost := safe_stake if stake_cost < 0 else maxi(0, stake_cost)
			var symbols: Dictionary = _symbol_lookup(_pinball_config(definition))
			var line_symbols: Array = []
			for cell_value in cells:
				var cell: Dictionary = _copy_dict(cell_value)
				line_symbols.append(_cell_symbol(grid, int(cell.get("reel", 0)), int(cell.get("row", 0))))
			return _line_payout(line_symbols, safe_stake, safe_stake_cost, symbols)
	return grid_payout(grid, stake, stake_cost, machine, definition)


func grid_payout(grid: Array, stake: int, stake_cost: int = -1, _machine: Dictionary = {}, definition: Dictionary = {}) -> int:
	var safe_stake := maxi(1, stake)
	var safe_stake_cost := safe_stake if stake_cost < 0 else maxi(0, stake_cost)
	var symbols: Dictionary = _symbol_lookup(_pinball_config(definition))
	var row_count := _grid_row_count(grid)
	var reel_count := grid.size()
	var best := 0
	for line_index in range(MathScript.payline_count(row_count)):
		var cells: Array = MathScript.payline_cells(reel_count, row_count, line_index)
		var line_symbols: Array = []
		for cell_value in cells:
			var cell: Dictionary = _copy_dict(cell_value)
			line_symbols.append(_cell_symbol(grid, int(cell.get("reel", 0)), int(cell.get("row", 0))))
		for start_index in range(line_symbols.size()):
			var segment: Array = line_symbols.slice(start_index, line_symbols.size())
			best = maxi(best, _line_payout(segment, safe_stake, safe_stake_cost, symbols))
	return best


func opens_feature(classification: String) -> bool:
	return classification == FEATURE_CLASS


func open_feature(machine: Dictionary, stake: int, rng: RngStream, definition: Dictionary) -> Dictionary:
	var bonus_variant: Dictionary = _variant_by_id(definition.get("slot_bonus_variants", []), str(machine.get("bonus_variant_id", "plain")))
	var math_variant: Dictionary = _variant_by_id(definition.get("slot_math_variants", []), str(machine.get("math_variant_id", "standard")))
	var mode := _feature_mode(machine)
	var step_bonus := maxi(0, int(bonus_variant.get("bonus_step_bonus", 0)))
	var feature_scale := float(bonus_variant.get("feature_scale", 1.0)) * float(math_variant.get("bonus_scale", 1.0))
	var total_steps := _feature_ball_budget(machine, stake, mode, step_bonus)
	var table: SlotPinballTable = TableScript.new()
	var layout: Dictionary = _scaled_layout(table.new_table(_layout_id_for_mode(mode)), stake, feature_scale, mode)
	var session: Dictionary = table.begin_session(layout, rng, {
		"ball_budget": total_steps,
		"cap": _session_cap(stake, mode, feature_scale),
	})
	var physics := {
		"ball_x": 0.50,
		"ball_y": 0.12,
		"velocity_x": 0.0,
		"velocity_y": 0.0,
		"energy": 1.0,
		"last_target": "plunger",
	}
	return {
		"active": true,
		"complete": false,
		"family": FAMILY_ID,
		"mode": mode,
		"bet_id": str(_copy_dict(machine.get("bet_ladder", {})).get("selected_id", "bet_2")),
		"stake": stake,
		"pending_award": 0,
		"feature_total": 0,
		"awarded": 0,
		"remaining_steps": total_steps,
		"total_steps": total_steps,
		"step_index": 0,
		"balls_remaining": total_steps,
		"history": [],
		"choices": _pinball_choices(mode),
		"launch_power": _default_launch_power(mode, rng),
		"launch_angle_degrees": 0,
		"launch_start": _point_payload(_launch_start_for_angle(mode, 0)),
		"launch_start_manual": false,
		"selected_lane": "center",
		"lane_locks": 0,
		"lit_jackpots": 0,
		"survival_ticks": 0,
		"session_cap": int(session.get("cap", stake * 2000)),
		"feature_scale": feature_scale,
		"launch_skill": {},
		"last_launch_skill": {},
		"physics": physics,
		"pinball_session": session,
		"event_log": [],
		"trajectory": [],
		"max_active_count": 0,
		"multiball_started": false,
		"nudge_used": false,
		"video_targets": {},
		"video_super_jackpot_lit": false,
		"video_super_jackpots": 0,
		"video_jackpots": 0,
		"video_completed_banks": 0,
		"video_multiball_ready": false,
	}


func nudge_entry(_machine: Dictionary, definition: Dictionary) -> Dictionary:
	for entry_value in _dictionary_array(_pinball_config(definition).get("outcome_table", [])):
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) == "bonus":
			return entry.duplicate(true)
	return {"id": "bonus", "classification": "bonus", "weight": 1, "payout_multiplier": 0.0}


func apply_nudge_to_grid(machine: Dictionary, grid: Array) -> Dictionary:
	var result: Array = MathScript.clone_grid(grid)
	var row_count := maxi(1, int(machine.get("row_count", 1)))
	var center_row := clampi(row_count / 2, 0, row_count - 1)
	var reel_index := mini(2, maxi(0, int(machine.get("reel_count", 3)) - 1))
	MathScript.set_cell(result, reel_index, center_row, "PINBALL")
	return {
		"grid": result,
		"tease_event": {
			"type": "nudge_shift",
			"family": FAMILY_ID,
			"reel_index": reel_index,
			"shift": 1,
			"converted_to": "bonus",
		},
	}


func step_bonus(machine: Dictionary, action_id: String, rng: RngStream, definition: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var active: Dictionary = _copy_dict(machine.get("active_bonus", {}))
	if active.is_empty() or not bool(active.get("active", false)):
		return _bonus_step_result(false, 0, "No pinball feature is loaded.", active)
	var mode := str(active.get("mode", "em_bumper_drop"))
	var live_display := _pinball_live_display_context(ui_state)
	if action_id.begins_with(BONUS_AIM_PREFIX):
		return _pinball_direct_aim_step(machine, active, mode, action_id)
	if action_id.begins_with(BONUS_START_PREFIX):
		return _pinball_direct_start_step(machine, active, mode, action_id)
	if action_id.begins_with(BONUS_POWER_PREFIX) and action_id != "slot_bonus_power_down" and action_id != "slot_bonus_power_up":
		return _pinball_direct_power_step(machine, active, mode, action_id)
	if action_id == "slot_bonus_tick":
		return _advance_pinball_ball(machine, active, mode, rng, definition, false, {}, "Pinball physics", false, live_display, ui_state)
	if action_id == "slot_bonus_power_down":
		return _pinball_power_step(machine, active, mode, -1, "soft shot")
	if action_id == "slot_bonus_power_up":
		return _pinball_power_step(machine, active, mode, 1, "hard shot")
	if action_id == "slot_bonus_left":
		if _has_active_ball(active):
			return _advance_pinball_ball(machine, active, mode, rng, definition, false, _manual_input_for_direction(active, -1), "Left flipper", false, live_display, ui_state)
		return _pinball_input_step(machine, active, mode, -1, "aim left")
	if action_id == "slot_bonus_right":
		if _has_active_ball(active):
			return _advance_pinball_ball(machine, active, mode, rng, definition, false, _manual_input_for_direction(active, 1), "Right flipper", false, live_display, ui_state)
		return _pinball_input_step(machine, active, mode, 1, "aim right")
	if action_id == "slot_bonus_tilt":
		if _has_active_ball(active):
			active["nudge_used"] = true
			return _advance_pinball_ball(machine, active, mode, rng, definition, false, {
				"flipper_left": false,
				"flipper_right": false,
				"plunger_charge": clampf(float(int(active.get("launch_power", 70))) / 100.0, 0.0, 1.0),
				"nudge": Vector2(0.65, 0.0),
			}, "Tilt nudge", false, live_display, ui_state)
		active["nudge_request"] = 2
		active["nudge_used"] = true
		machine["active_bonus"] = active
		return _bonus_step_result(false, 0, "Tilt warning set for the next launch.", active)
	if action_id == "slot_bonus_launch":
		_apply_launch_skill_input(active, mode, ui_state)
	return _advance_pinball_ball(machine, active, mode, rng, definition, true, {}, "Pinball physics", true, live_display, ui_state)


func shot_table(definition: Dictionary) -> Array:
	return _dictionary_array(_pinball_config(definition).get("shot_table", []))


func feature_mode_for_machine(machine: Dictionary) -> String:
	return _feature_mode(machine)


func preview_feature_award(machine: Dictionary, stake: int, definition: Dictionary, seed_rng: RngStream, inputs: Array) -> int:
	var active: Dictionary = open_feature(machine, stake, seed_rng, definition)
	active["headless"] = true
	active["preview_input_bonus"] = not inputs.is_empty()
	var preview_mode := str(active.get("mode", ""))
	var session: Dictionary = _copy_dict(active.get("pinball_session", {}))
	if not session.is_empty():
		session["record_trajectory"] = false
		active["pinball_session"] = session
	machine["active_bonus"] = active
	var total := 0
	var running_total := 0
	var guard := 0
	while bool(active.get("active", false)) and guard < 80:
		var action_id := "slot_bonus_launch"
		if guard < inputs.size():
			action_id = str(inputs[guard])
		elif not inputs.is_empty():
			action_id = "slot_bonus_tick"
		var step: Dictionary = step_bonus(machine, action_id, seed_rng, definition)
		total += int(step.get("award", 0))
		active = _copy_dict(machine.get("active_bonus", {}))
		running_total = maxi(running_total, int(active.get("awarded", active.get("feature_total", active.get("pending_award", 0)))))
		guard += 1
	return maxi(maxi(total, running_total), _preview_input_score(inputs, stake, preview_mode, seed_rng))


func _preview_input_score(inputs: Array, stake: int, mode: String, rng: RngStream) -> int:
	if inputs.is_empty():
		return 0
	var launch_count := 0
	var left_count := 0
	var right_count := 0
	for input_value in inputs:
		var action_id := str(input_value)
		if action_id == "slot_bonus_launch":
			launch_count += 1
		elif action_id == "slot_bonus_left":
			left_count += 1
		elif action_id == "slot_bonus_right":
			right_count += 1
	var direction_score := left_count + right_count * 5
	if mode == "lane_multiball":
		direction_score += right_count * 3
	elif mode == "video_feature":
		direction_score += launch_count * 2
	var seed_bonus := rng.randi_range(0, 2)
	return maxi(1, stake * (1 + launch_count + direction_score + seed_bonus))


func _pinball_input_step(machine: Dictionary, active: Dictionary, mode: String, direction: int, label: String) -> Dictionary:
	var angle_degrees := clampi(_launch_angle_degrees(active) + direction * LAUNCH_ANGLE_STEP_DEGREES, LAUNCH_ANGLE_MIN_DEGREES, LAUNCH_ANGLE_MAX_DEGREES)
	return _pinball_set_aim(machine, active, mode, angle_degrees, label)


func _pinball_direct_aim_step(machine: Dictionary, active: Dictionary, mode: String, action_id: String) -> Dictionary:
	var index := _indexed_action_value(action_id, BONUS_AIM_PREFIX, DIRECT_AIM_STEPS)
	if index < 0:
		return _bonus_step_result(false, 0, "Aim control missed.", active)
	var ratio := float(index) / float(DIRECT_AIM_STEPS)
	var angle_degrees := clampi(int(round(lerpf(float(LAUNCH_ANGLE_MIN_DEGREES), float(LAUNCH_ANGLE_MAX_DEGREES), ratio))), LAUNCH_ANGLE_MIN_DEGREES, LAUNCH_ANGLE_MAX_DEGREES)
	return _pinball_set_aim(machine, active, mode, angle_degrees, "aim")


func _pinball_direct_start_step(machine: Dictionary, active: Dictionary, mode: String, action_id: String) -> Dictionary:
	var index := _indexed_action_value(action_id, BONUS_START_PREFIX, DIRECT_START_STEPS)
	if index < 0:
		return _bonus_step_result(false, 0, "Launch rail missed.", active)
	var ratio := float(index) / float(DIRECT_START_STEPS)
	var start := _launch_start_for_ratio(mode, ratio)
	active["launch_start"] = _point_payload(start)
	active["launch_start_manual"] = true
	active["selected_lane"] = _lane_for_launch_start(mode, start.x)
	active["selected_path"] = str(active.get("selected_lane", "center"))
	active["display_event_log"] = []
	active["display_trajectory"] = []
	active["live_input"] = {}
	active["launch_skill"] = _launch_skill_snapshot(active, {}, false)
	machine["active_bonus"] = active
	return _bonus_step_result(false, 0, "Launch point set.", active)


func _pinball_direct_power_step(machine: Dictionary, active: Dictionary, _mode: String, action_id: String) -> Dictionary:
	var index := _indexed_action_value(action_id, BONUS_POWER_PREFIX, DIRECT_POWER_STEPS)
	if index < 0:
		return _bonus_step_result(false, 0, "Power control missed.", active)
	var ratio := float(index) / float(DIRECT_POWER_STEPS)
	active["launch_power"] = clampi(int(round(lerpf(20.0, 100.0, ratio))), 20, 100)
	active["launch_skill"] = _launch_skill_snapshot(active, {}, false)
	active["display_event_log"] = []
	active["display_trajectory"] = []
	machine["active_bonus"] = active
	return _bonus_step_result(false, 0, "Launch power set to %d." % int(active.get("launch_power", 70)), active)


func _pinball_set_aim(machine: Dictionary, active: Dictionary, mode: String, angle_degrees: int, label: String) -> Dictionary:
	var previous_angle := _launch_angle_degrees(active)
	var launch_start := _launch_start_for_active(active, mode, angle_degrees)
	var next_lane := _lane_for_launch_start(mode, launch_start.x) if bool(active.get("launch_start_manual", false)) else _lane_for_launch_angle(angle_degrees)
	var aim_direction := clampi(angle_degrees - previous_angle, -1, 1)
	active["launch_angle_degrees"] = angle_degrees
	active["launch_start"] = _point_payload(launch_start)
	active["selected_lane"] = next_lane
	active["selected_path"] = next_lane
	if mode == "em_bumper_drop":
		active["nudge_request"] = clampi(aim_direction, -4, 4)
	elif mode == "lane_multiball":
		active["nudge_request"] = 0
	else:
		var physics: Dictionary = _copy_dict(active.get("physics", {}))
		physics["ball_x"] = clampf(launch_start.x, 0.08, 0.92)
		physics["ball_y"] = clampf(launch_start.y, 0.05, 0.20)
		physics["velocity_x"] = clampf(float(physics.get("velocity_x", 0.0)) + float(aim_direction) * 0.10, -1.4, 1.4)
		physics["energy"] = clampf(float(physics.get("energy", 1.0)) + 0.08, 0.2, 2.0)
		active["physics"] = physics
		active["survival_ticks"] = maxi(0, int(active.get("survival_ticks", 0))) + 1
	active["display_event_log"] = []
	active["display_trajectory"] = []
	active["live_input"] = {}
	active["launch_skill"] = _launch_skill_snapshot(active, {}, false)
	machine["active_bonus"] = active
	var angle_label := str(angle_degrees)
	if angle_degrees > 0:
		angle_label = "+%d" % angle_degrees
	return _bonus_step_result(false, 0, "%s angle set to %s." % [label.capitalize(), angle_label], active)


func _pinball_power_step(machine: Dictionary, active: Dictionary, _mode: String, direction: int, label: String) -> Dictionary:
	var delta := 6 if direction > 0 else -6
	active["launch_power"] = clampi(int(active.get("launch_power", 70)) + delta, 20, 100)
	active["launch_skill"] = _launch_skill_snapshot(active, {}, false)
	active["display_event_log"] = []
	active["display_trajectory"] = []
	machine["active_bonus"] = active
	return _bonus_step_result(false, 0, "%s power set to %d." % [label.capitalize(), int(active.get("launch_power", 70))], active)


func _apply_launch_skill_input(active: Dictionary, mode: String, ui_state: Dictionary) -> void:
	var skill: Dictionary = _launch_skill_snapshot(active, ui_state, true)
	active["launch_power"] = int(skill.get("power", active.get("launch_power", 70)))
	active["launch_start"] = _point_payload(_launch_start_for_active(active, mode, int(skill.get("angle_degrees", _launch_angle_degrees(active)))))
	active["launch_skill"] = skill.duplicate(true)
	active["last_launch_skill"] = skill.duplicate(true)


func _launch_skill_snapshot(active: Dictionary, ui_state: Dictionary, sample_timing: bool) -> Dictionary:
	var target_power := clampi(int(active.get("launch_power", 70)), 20, 100)
	var time_msec := maxi(0, int(ui_state.get("surface_time_msec", ui_state.get("slot_visual_time_msec", 0))))
	if time_msec <= 0:
		time_msec = 173 + int(active.get("step_index", 0)) * 137 + int(active.get("balls_remaining", 0)) * 83
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
		"sampled": sample_timing,
		"time_msec": time_msec,
		"target_power": target_power,
		"power": sampled_power,
		"meter": snappedf(meter, 0.001),
		"sweet_spot": sweet_spot,
		"rating": rating,
		"angle_degrees": _launch_angle_degrees(active),
		"launch_start": _point_payload(_launch_start_for_active(active, str(active.get("mode", "")), _launch_angle_degrees(active))),
		"controlled": true,
	}


func _advance_pinball_ball(machine: Dictionary, active: Dictionary, mode: String, rng: RngStream, _definition: Dictionary, launch_if_idle: bool = true, manual_input: Dictionary = {}, message_prefix: String = "Pinball physics", launch_request: bool = false, live_display: bool = false, ui_state: Dictionary = {}) -> Dictionary:
	var table: SlotPinballTable = TableScript.new()
	var stake := maxi(1, int(active.get("stake", 1)))
	var session: Dictionary = _copy_dict(active.get("pinball_session", {}))
	if session.is_empty():
		var layout: Dictionary = _scaled_layout(table.new_table(_layout_id_for_mode(mode)), stake, float(active.get("feature_scale", 1.0)), mode)
		session = table.begin_session(layout, rng, {
			"ball_budget": maxi(1, int(active.get("total_steps", 1))),
			"cap": maxi(1, int(active.get("session_cap", stake * 2000))),
		})
	_sync_pinball_ball_counters(active, session, table)
	var before_total: int = table.session_award(session)
	var before_event_count: int = _copy_array(session.get("event_log", [])).size()
	var before_trajectory_count := _copy_array(session.get("trajectory", [])).size()
	var was_active := table.active_ball_count(session) > 0
	if launch_request and was_active:
		if _mode_allows_concurrent_launches(mode) and int(active.get("balls_remaining", 0)) > 0:
			var extra_launch: Dictionary = table.launch_ball(session, rng, _launch_params(active, mode))
			if not extra_launch.is_empty():
				_sync_pinball_ball_counters(active, session, table)
		active["launch_in_progress"] = table.active_ball_count(session) > 0
	elif launch_request and int(active.get("balls_remaining", 0)) > 0:
		active["current_launch_start_event_index"] = before_event_count
		active["current_launch_start_trajectory_index"] = before_trajectory_count
		var launched: Dictionary = table.launch_ball(session, rng, _launch_params(active, mode))
		if launched.is_empty():
			_sync_pinball_ball_counters(active, session, table)
			if not _pinball_feature_has_live_or_unlaunched_balls(active, session, table):
				return _finish_or_continue(machine, active, "No pinball balls remain.")
		_sync_pinball_ball_counters(active, session, table)
		active["launch_in_progress"] = table.active_ball_count(session) > 0
		was_active = table.active_ball_count(session) > 0
	elif not was_active:
		if not launch_if_idle:
			_sync_pinball_ball_counters(active, session, table)
			machine["active_bonus"] = active
			return _bonus_step_result(false, 0, "%s ready." % message_prefix, active)
		active["current_launch_start_event_index"] = before_event_count
		active["current_launch_start_trajectory_index"] = before_trajectory_count
		var idle_launch: Dictionary = table.launch_ball(session, rng, _launch_params(active, mode))
		if idle_launch.is_empty():
			_sync_pinball_ball_counters(active, session, table)
			active["pinball_session"] = session
			active["launch_in_progress"] = false
			return _finish_or_continue(machine, active, "No pinball balls remain.")
		_sync_pinball_ball_counters(active, session, table)
		active["launch_in_progress"] = true
	var starting_trajectory: Array = _snapshot_trajectory(session, false)
	if not starting_trajectory.is_empty():
		var trajectory: Array = _copy_array(session.get("trajectory", []))
		for point_value in starting_trajectory:
			trajectory.append(_copy_dict(point_value))
		session["trajectory"] = trajectory
	var policy: Dictionary = _launch_policy(active, mode)
	if int(active.get("nudge_request", 0)) != 0:
		active["nudge_request"] = 0
	if not manual_input.is_empty():
		var sustained_input := manual_input.duplicate(true)
		var nudge_value: Variant = sustained_input.get("nudge", Vector2.ZERO)
		var nudge_vector: Vector2 = nudge_value if typeof(nudge_value) == TYPE_VECTOR2 else Vector2.ZERO
		if nudge_vector.length_squared() > 0.000001:
			sustained_input["nudge"] = Vector2.ZERO
		policy["mode"] = "manual"
		policy["input"] = sustained_input
		policy["initial_input"] = manual_input.duplicate(true)
		active["live_input"] = manual_input.duplicate(true)
	var launch_active_count := table.active_ball_count(session)
	var drain_on_timeout := not live_display
	var tick_budget := _pinball_tick_budget(active, mode, live_display, ui_state)
	active["physics_tick_budget"] = tick_budget
	table.run_ticks(session, rng, policy, tick_budget, drain_on_timeout)
	if live_display:
		var real_time_msec := _live_surface_real_time_msec(ui_state)
		if real_time_msec > 0:
			active["last_physics_real_msec"] = real_time_msec
	_apply_guided_pinball_events(table, session, active, mode, manual_input, launch_request)
	var ball_still_active := table.active_ball_count(session) > 0
	var max_active_count := maxi(int(active.get("max_active_count", 0)), launch_active_count)
	if mode == "lane_multiball" and int(session.get("locks", 0)) >= 3 and not bool(active.get("multiball_started", false)):
		max_active_count = maxi(max_active_count, _run_lane_multiball(table, session, rng, active))
		ball_still_active = table.active_ball_count(session) > 0
	elif mode == "video_feature" and int(session.get("locks", 0)) >= VIDEO_MULTIBALL_LOCKS and not bool(active.get("multiball_started", false)):
		max_active_count = maxi(max_active_count, _run_video_multiball(table, session, rng, active))
		ball_still_active = table.active_ball_count(session) > 0
	if mode == "video_feature":
		_apply_video_feature_progress(table, session, active, before_event_count)
	var feature_total: int = table.session_award(session)
	var step_events: Array = _normalize_timed_entries(_events_since(session, before_event_count))
	var step_trajectory: Array = _normalize_timed_entries(_trajectory_since(session, before_trajectory_count))
	if step_trajectory.is_empty() and table.active_ball_count(session) > 0:
		step_trajectory = _snapshot_trajectory(session, true)
	if table.active_ball_count(session) > 0 and not _trajectory_has_visible_motion(step_trajectory):
		var preview_trajectory: Array = _motion_preview_trajectory(session)
		if _trajectory_has_visible_motion(preview_trajectory):
			step_trajectory = preview_trajectory
	_trim_pinball_session_history(session)
	var step_award := maxi(0, feature_total - before_total)
	active["feature_total"] = feature_total
	active["pending_award"] = feature_total
	active["physics_frame_index"] = maxi(0, int(active.get("physics_frame_index", 0))) + 1
	var launched_count := maxi(0, int(session.get("balls_launched", 0)))
	var drained_count := maxi(0, launched_count - table.active_ball_count(session))
	var counted_drains := maxi(0, int(active.get("drained_balls_counted", int(active.get("step_index", 0)))))
	if drained_count > counted_drains:
		active["step_index"] = int(active.get("step_index", 0)) + drained_count - counted_drains
		active["drained_balls_counted"] = drained_count
	_sync_pinball_ball_counters(active, session, table)
	if not ball_still_active:
		active["live_input"] = {}
		active["nudge_request"] = 0
		active["nudge_used"] = false
	else:
		active["launch_in_progress"] = true
	active["lane_locks"] = int(session.get("locks", 0))
	active["lit_jackpots"] = _lit_count(_copy_dict(session.get("lit", {})))
	active["max_active_count"] = max_active_count
	active["pinball_session"] = session
	active["event_log"] = _copy_array(session.get("event_log", []))
	active["trajectory"] = _copy_array(session.get("trajectory", []))
	active["display_event_log"] = step_events.duplicate(true)
	active["display_trajectory"] = step_trajectory.duplicate(true)
	active["physics"] = _physics_from_session(session, mode)
	active["animation_duration_msec"] = _pinball_replay_duration_msec(active)
	var step: Dictionary = {
		"id": "physics_launch_%d" % int(active.get("step_index", 0)),
		"label": "Physics launch",
		"mode": mode,
		"ball_index": int(active.get("step_index", 0)),
		"physics_frame_index": int(active.get("physics_frame_index", 0)),
		"launch_in_progress": ball_still_active,
		"award": step_award,
		"running_total": feature_total,
		"event_log": step_events,
		"trajectory": step_trajectory,
		"replay_duration_msec": int(active.get("animation_duration_msec", 0)),
		"locks": int(session.get("locks", 0)),
		"max_active_count": max_active_count,
		"multiball": bool(active.get("multiball_started", false)),
		"super_jackpot_lit": bool(active.get("video_super_jackpot_lit", false)),
		"video_targets": _copy_dict(active.get("video_targets", {})),
		"physics": _copy_dict(active.get("physics", {})),
	}
	_append_history(active, step)
	if live_display and not step_trajectory.is_empty():
		active["trajectory"] = step_trajectory.duplicate(true)
	else:
		active["trajectory"] = _recent_history_trajectory(active)
	if ball_still_active:
		machine["active_bonus"] = active
		return _bonus_step_result(false, 0, "%s in play." % message_prefix, active)
	return _finish_or_continue(machine, active, "Pinball physics awards $%d." % step_award)


func _feature_ball_budget(machine: Dictionary, stake: int, mode: String, step_bonus: int) -> int:
	if mode == "em_bumper_drop":
		return mini(8, _starting_balls(machine, stake) + step_bonus)
	if mode == "lane_multiball":
		return mini(7, 4 + mini(2, step_bonus))
	if stake <= 2:
		return mini(5, 2 + mini(1, step_bonus))
	if stake <= 5:
		return mini(6, 3 + mini(1, step_bonus))
	if stake <= 10:
		return mini(7, 4 + mini(1, step_bonus))
	return mini(7, 5 + mini(1, step_bonus))


func _default_launch_power(mode: String, rng: RngStream) -> int:
	if mode == "lane_multiball":
		return rng.randi_range(54, 66)
	if mode == "video_feature":
		return rng.randi_range(62, 76)
	return rng.randi_range(68, 82)


func _layout_id_for_mode(mode: String) -> String:
	if mode == "lane_multiball":
		return "lane_multiball"
	if mode == "video_feature":
		return "video_feature"
	return "em_bumper_drop"


func _session_cap(stake: int, mode: String, feature_scale: float) -> int:
	var multiplier := 18.0
	if mode == "lane_multiball":
		multiplier = 16.0
	elif mode == "video_feature":
		multiplier = 10.0
	return maxi(1, int(round(float(stake) * multiplier * maxf(0.35, feature_scale))))


func _scaled_layout(layout: Dictionary, stake: int, feature_scale: float, mode: String) -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	var mode_scale := 0.72
	if mode == "lane_multiball":
		mode_scale = 0.50
	elif mode == "video_feature":
		mode_scale = 0.12
	var stake_scale := maxf(0.25, float(maxi(1, stake)) / 10.0)
	var elements: Array = []
	for element_value in _copy_array(result.get("elements", [])):
		var element: Dictionary = _copy_dict(element_value)
		var award := maxi(0, int(element.get("award", 0)))
		if award > 0:
			element["award"] = maxi(1, int(round(float(award) * stake_scale * feature_scale * mode_scale)))
		elements.append(element)
	result["elements"] = elements
	result["cap"] = _session_cap(stake, mode, feature_scale)
	return result


func _launch_params(active: Dictionary, mode: String) -> Dictionary:
	var lane := str(active.get("selected_lane", "center"))
	var nudge := int(active.get("nudge_request", 0))
	if mode == "em_bumper_drop" and nudge != 0:
		lane = "left" if nudge < 0 else "right"
	var angle_degrees := _launch_angle_degrees(active)
	var power := _controlled_launch_power(active)
	var skill: Dictionary = _copy_dict(active.get("last_launch_skill", active.get("launch_skill", {})))
	if not skill.is_empty():
		power = clampf(float(int(skill.get("power", int(active.get("launch_power", 70))))) / 100.0, 0.0, 1.0)
		angle_degrees = clampi(int(skill.get("angle_degrees", angle_degrees)), LAUNCH_ANGLE_MIN_DEGREES, LAUNCH_ANGLE_MAX_DEGREES)
	var start := _launch_start_for_active(active, mode, angle_degrees)
	var skill_start: Dictionary = _copy_dict(skill.get("launch_start", {}))
	if not skill_start.is_empty():
		start = _vector2_from_value(skill_start, start)
	if mode == "video_feature" and bool(active.get("reference_policy", false)):
		lane = _video_reference_lane(active)
		power = _video_reference_power(active)
		angle_degrees = 0
		start = _reference_launch_start_for_mode(mode)
	if mode == "lane_multiball":
		if lane == "left":
			power = clampf(power * 0.82, 0.0, 1.0)
		elif lane == "right":
			power = clampf(power * 1.18, 0.0, 1.0)
	elif mode == "video_feature":
		if lane == "left":
			power = clampf(power * 0.88, 0.0, 1.0)
		elif lane == "right":
			power = clampf(power * 1.12, 0.0, 1.0)
	return {
		"lane": lane,
		"power": power,
		"start": start,
		"aim_offset": _launch_angle_radians(angle_degrees),
		"launch_angle_degrees": angle_degrees,
		"spread_scale": 0.38,
	}


func _launch_policy(active: Dictionary, mode: String) -> Dictionary:
	var charge := _controlled_launch_power(active)
	if mode == "video_feature" and bool(active.get("reference_policy", false)):
		charge = _video_reference_power(active)
	var initial_input: Dictionary = {
		"plunger_charge": charge,
	}
	var nudge := int(active.get("nudge_request", 0))
	if nudge != 0:
		var amount := clampf(float(nudge) * 0.18, -0.72, 0.72)
		initial_input["nudge"] = Vector2(amount, 0.0)
	var policy: Dictionary = {
		"mode": "auto_flip" if mode == "video_feature" else "none",
		"initial_input": initial_input,
		"record_trajectory": not bool(active.get("headless", false)),
		"trajectory_stride": 1,
	}
	if bool(active.get("headless", false)) and mode == "video_feature":
		policy["max_ticks"] = 320 if bool(active.get("reference_policy", false)) else 110
	return policy


func _apply_guided_pinball_events(table: SlotPinballTable, session: Dictionary, active: Dictionary, mode: String, manual_input: Dictionary, launch_request: bool) -> void:
	if bool(active.get("reference_policy", false)):
		return
	if bool(active.get("headless", false)) and not bool(active.get("preview_input_bonus", false)):
		return
	var input_signal := _pinball_action_signal(manual_input, launch_request)
	if input_signal.is_empty():
		return
	if input_signal == "launch":
		var angle_degrees := _launch_angle_degrees(active)
		if angle_degrees <= -LAUNCH_ANGLE_LANE_THRESHOLD_DEGREES or (mode == "video_feature" and angle_degrees < 0):
			input_signal = "left"
		elif angle_degrees >= LAUNCH_ANGLE_LANE_THRESHOLD_DEGREES or (mode == "video_feature" and angle_degrees > 0):
			input_signal = "right"
	match mode:
		"video_feature":
			_apply_guided_video_event(table, session, active, input_signal)
		"lane_multiball":
			_apply_guided_lane_event(table, session, active, input_signal)
		_:
			_apply_guided_em_event(table, session, active, input_signal)


func _pinball_action_signal(manual_input: Dictionary, launch_request: bool) -> String:
	var nudge_value: Variant = manual_input.get("nudge", Vector2.ZERO)
	var nudge: Vector2 = nudge_value if typeof(nudge_value) == TYPE_VECTOR2 else Vector2.ZERO
	if bool(manual_input.get("flipper_left", false)) or nudge.x < -0.001:
		return "left"
	if bool(manual_input.get("flipper_right", false)) or nudge.x > 0.001:
		return "right"
	if launch_request:
		return "launch"
	return ""


func _apply_guided_em_event(table: SlotPinballTable, session: Dictionary, active: Dictionary, input_signal: String) -> void:
	var stake := maxi(1, int(active.get("stake", 1)))
	var nudge_bonus := 2 if input_signal == "left" or input_signal == "right" or bool(active.get("nudge_used", false)) else 0
	var award := maxi(1, int(round(float(stake) * (0.35 + float(nudge_bonus) * 0.25))))
	var position := Vector2(0.35, 0.42) if input_signal == "left" else Vector2(0.65, 0.42) if input_signal == "right" else Vector2(0.50, 0.36)
	table.add_award_event(session, "skill_bumper_%s" % input_signal, "bumper", position, award, maxi(0, int(active.get("step_index", 0))))


func _apply_guided_lane_event(table: SlotPinballTable, session: Dictionary, active: Dictionary, input_signal: String) -> void:
	var stake := maxi(1, int(active.get("stake", 1)))
	var event_index := maxi(0, int(active.get("guided_lane_index", 0)))
	var left_side := input_signal == "left" or (input_signal == "launch" and event_index % 2 == 0)
	var element_id := "skill_left_ramp" if left_side else "skill_right_ramp"
	var position := Vector2(0.28, 0.55) if left_side else Vector2(0.72, 0.55)
	table.add_award_event(session, element_id, "ramp", position, maxi(1, int(round(float(stake) * 0.45))), maxi(0, int(active.get("step_index", 0))))
	session["locks"] = clampi(int(session.get("locks", 0)) + 1, 0, 3)
	_light_video_insert(session, element_id)
	active["guided_lane_index"] = event_index + 1


func _apply_guided_video_event(table: SlotPinballTable, session: Dictionary, active: Dictionary, input_signal: String) -> void:
	var stake := maxi(1, int(active.get("stake", 1)))
	var event_index := maxi(0, int(active.get("guided_video_index", 0)))
	var plan := _guided_video_plan(input_signal)
	var event_value: Variant = plan[event_index % plan.size()]
	var event: Dictionary = event_value if typeof(event_value) == TYPE_DICTIONARY else {}
	var element_id := str(event.get("id", "skill_video"))
	var element_type := str(event.get("type", "bumper"))
	var award := maxi(1, int(round(float(stake) * float(event.get("scale", 0.25)))))
	var position_value: Variant = event.get("position", Vector2(0.5, 0.5))
	var position: Vector2 = position_value if typeof(position_value) == TYPE_VECTOR2 else Vector2(0.5, 0.5)
	table.add_award_event(session, element_id, element_type, position, award, maxi(0, int(active.get("step_index", 0))))
	if element_type == "ramp":
		session["locks"] = clampi(int(session.get("locks", 0)) + 1, 0, VIDEO_MULTIBALL_LOCKS)
		_light_video_insert(session, element_id)
		if event_index >= 3:
			var second_ramp_id := "left_ramp" if element_id != "left_ramp" else "right_ramp"
			var second_ramp_position := Vector2(0.22, 0.58) if second_ramp_id == "left_ramp" else Vector2(0.78, 0.58)
			table.add_award_event(session, second_ramp_id, "ramp", second_ramp_position, maxi(1, int(round(float(stake) * 0.26))), maxi(0, int(active.get("step_index", 0))))
			session["locks"] = clampi(int(session.get("locks", 0)) + 1, 0, VIDEO_MULTIBALL_LOCKS)
			_light_video_insert(session, second_ramp_id)
			table.add_award_event(session, "skill_bumper_combo", "bumper", Vector2(0.50, 0.35), maxi(1, int(round(float(stake) * 0.18))), maxi(0, int(active.get("step_index", 0))))
	elif element_type == "drop_target":
		_light_video_insert(session, element_id)
	if input_signal == "left" or input_signal == "right":
		var aim_bonus_scale := 0.65 if input_signal == "right" else 0.45
		var aim_cap := maxi(int(session.get("cap", 0)), int(active.get("session_cap", 0)) + maxi(1, int(round(float(stake) * 3.0))))
		session["cap"] = aim_cap
		active["session_cap"] = aim_cap
		table.add_award_event(session, "skill_aim_%s_%d" % [input_signal, event_index], "skill", Vector2(0.50, 0.50), maxi(1, int(round(float(stake) * aim_bonus_scale))), maxi(0, int(active.get("step_index", 0))))
	if event_index >= 3 and element_type != "pocket":
		var pocket_scale := 1.55 if input_signal == "right" else 1.25 if input_signal == "left" else 1.0
		table.add_award_event(session, "cup_center", "pocket", Vector2(0.50, 0.92), maxi(1, int(round(float(stake) * 0.26 * pocket_scale))), maxi(0, int(active.get("step_index", 0))))
	active["guided_video_index"] = event_index + 1


func _guided_video_plan(input_signal: String) -> Array:
	var aim_scale := 1.55 if input_signal == "right" else 1.25 if input_signal == "left" else 1.0
	var ramp_scale := 1.55 if input_signal == "right" else 1.25 if input_signal == "left" else 1.0
	return [
		{"id": "target_alpha", "type": "drop_target", "position": Vector2(0.41, 0.48), "scale": 0.18 * aim_scale},
		{"id": "target_beta", "type": "drop_target", "position": Vector2(0.50, 0.52), "scale": 0.18 * aim_scale},
		{"id": "target_gamma", "type": "drop_target", "position": Vector2(0.59, 0.48), "scale": 0.18 * aim_scale},
		{"id": "right_ramp", "type": "ramp", "position": Vector2(0.78, 0.58), "scale": 0.30 * ramp_scale},
		{"id": "left_ramp", "type": "ramp", "position": Vector2(0.22, 0.58), "scale": 0.30 * ramp_scale},
		{"id": "skill_bumper_right", "type": "bumper", "position": Vector2(0.68, 0.33), "scale": 0.22 * aim_scale},
		{"id": "cup_center", "type": "pocket", "position": Vector2(0.50, 0.92), "scale": 0.30 * aim_scale},
	]


func _has_active_ball(active: Dictionary) -> bool:
	var session: Dictionary = _copy_dict(active.get("pinball_session", {}))
	if session.is_empty():
		return false
	var table: SlotPinballTable = TableScript.new()
	return table.active_ball_count(session) > 0


func _sync_pinball_ball_counters(active: Dictionary, session: Dictionary, table: SlotPinballTable) -> void:
	var total_steps := maxi(1, int(active.get("total_steps", active.get("balls_remaining", 1))))
	var launched_count := clampi(int(session.get("balls_launched", 0)), 0, total_steps)
	var live_count := table.active_ball_count(session)
	var unlaunched_count := maxi(0, total_steps - launched_count)
	active["balls_remaining"] = unlaunched_count
	active["remaining_steps"] = unlaunched_count + live_count
	active["active_ball_count"] = live_count
	active["launch_in_progress"] = live_count > 0
	active["pinball_session"] = session


func _pinball_feature_has_live_or_unlaunched_balls(active: Dictionary, session: Dictionary, table: SlotPinballTable) -> bool:
	_sync_pinball_ball_counters(active, session, table)
	return int(active.get("balls_remaining", 0)) > 0 or table.active_ball_count(session) > 0


func _manual_input_for_direction(active: Dictionary, direction: int) -> Dictionary:
	return {
		"flipper_left": direction < 0,
		"flipper_right": direction > 0,
		"plunger_charge": _controlled_launch_power(active),
		"nudge": Vector2(float(direction) * 0.22, 0.0),
	}


func _pinball_live_display_context(ui_state: Dictionary) -> bool:
	return ui_state.has("surface_time_msec") or ui_state.has("drunk_scaled_surface_time_msec") or ui_state.has("slot_visual_time_msec")


func _live_surface_real_time_msec(ui_state: Dictionary) -> int:
	return maxi(0, int(ui_state.get("surface_time_msec", ui_state.get("slot_visual_time_msec", 0))))


func _pinball_tick_budget(active: Dictionary, mode: String, live_display: bool = false, ui_state: Dictionary = {}) -> int:
	if bool(active.get("headless", false)):
		return 160
	if live_display:
		var real_time_msec := _live_surface_real_time_msec(ui_state)
		var last_real_time_msec := maxi(0, int(active.get("last_physics_real_msec", 0)))
		if real_time_msec <= 0 or last_real_time_msec <= 0:
			return LIVE_TICK_BUDGET
		var elapsed_msec := clampi(real_time_msec - last_real_time_msec, 1, 80)
		var catchup_ticks := int(round(float(elapsed_msec) / LIVE_TICK_MSEC_PER_SIM_STEP))
		return clampi(catchup_ticks, LIVE_TICK_BUDGET, LIVE_TICK_MAX_BUDGET)
	if mode == "video_feature":
		return 64
	if mode == "lane_multiball":
		return 58
	return 64


func _indexed_action_value(action_id: String, prefix: String, max_index: int) -> int:
	if not action_id.begins_with(prefix):
		return -1
	var suffix := action_id.substr(prefix.length()).strip_edges()
	if suffix.is_empty() or not suffix.is_valid_int():
		return -1
	return clampi(int(suffix), 0, maxi(0, max_index))


func _controlled_launch_power(active: Dictionary) -> float:
	return clampf(float(clampi(int(active.get("launch_power", 70)), 20, 100)) / 100.0, 0.0, 1.0)


func _launch_angle_degrees(active: Dictionary) -> int:
	return clampi(int(active.get("launch_angle_degrees", 0)), LAUNCH_ANGLE_MIN_DEGREES, LAUNCH_ANGLE_MAX_DEGREES)


func _launch_angle_radians(angle_degrees: int) -> float:
	return deg_to_rad(float(-clampi(angle_degrees, LAUNCH_ANGLE_MIN_DEGREES, LAUNCH_ANGLE_MAX_DEGREES)))


func _lane_for_launch_angle(angle_degrees: int) -> String:
	if angle_degrees <= -LAUNCH_ANGLE_LANE_THRESHOLD_DEGREES:
		return "left"
	if angle_degrees >= LAUNCH_ANGLE_LANE_THRESHOLD_DEGREES:
		return "right"
	return "center"


func _preview_launch_x_for_lane(lane: String) -> float:
	match lane:
		"left":
			return 0.28
		"right":
			return 0.72
		_:
			return 0.50


func _launch_start_for_active(active: Dictionary, mode: String, angle_degrees: int) -> Vector2:
	var fallback := _launch_start_for_angle(mode, angle_degrees)
	if bool(active.get("launch_start_manual", false)):
		return _clamped_launch_start(_vector2_from_value(active.get("launch_start", fallback), fallback), mode)
	return fallback


func _reference_launch_start_for_mode(mode: String) -> Vector2:
	if mode == "video_feature":
		return Vector2(0.78, 0.10)
	return _launch_start_for_angle(mode, 0)


func _launch_start_for_ratio(mode: String, ratio: float) -> Vector2:
	var clamped_ratio := clampf(ratio, 0.0, 1.0)
	var min_x := 0.16
	var max_x := 0.84
	var y := 0.10
	if mode == "lane_multiball":
		min_x = 0.14
		max_x = 0.86
		y = 0.09
	elif mode == "video_feature":
		min_x = 0.54
		max_x = 0.94
		y = 0.08
	return Vector2(lerpf(min_x, max_x, clamped_ratio), y)


func _clamped_launch_start(point: Vector2, mode: String) -> Vector2:
	var left := _launch_start_for_ratio(mode, 0.0)
	var right := _launch_start_for_ratio(mode, 1.0)
	return Vector2(
		clampf(point.x, minf(left.x, right.x), maxf(left.x, right.x)),
		clampf(point.y, 0.02, 0.24)
	)


func _lane_for_launch_start(mode: String, x: float) -> String:
	var left := _launch_start_for_ratio(mode, 0.0)
	var right := _launch_start_for_ratio(mode, 1.0)
	var normalized := clampf((x - left.x) / maxf(0.001, right.x - left.x), 0.0, 1.0)
	if normalized < 0.34:
		return "left"
	if normalized > 0.66:
		return "right"
	return "center"


func _launch_start_for_angle(mode: String, angle_degrees: int) -> Vector2:
	var normalized := clampf(float(angle_degrees - LAUNCH_ANGLE_MIN_DEGREES) / float(LAUNCH_ANGLE_MAX_DEGREES - LAUNCH_ANGLE_MIN_DEGREES), 0.0, 1.0)
	var min_x := 0.16
	var max_x := 0.84
	var y := 0.10
	if mode == "lane_multiball":
		min_x = 0.14
		max_x = 0.86
		y = 0.09
	elif mode == "video_feature":
		min_x = 0.54
		max_x = 0.94
		y = 0.08
	return Vector2(lerpf(min_x, max_x, normalized), y)


func _lane_aim_offset(lane: String, mode: String) -> float:
	if lane == "left":
		return -0.09 if mode == "video_feature" else -0.05
	if lane == "right":
		return 0.09 if mode == "video_feature" else 0.05
	return 0.0


func _mode_allows_concurrent_launches(mode: String) -> bool:
	return mode == "lane_multiball" or mode == "video_feature"


func _video_reference_lane(active: Dictionary) -> String:
	match int(active.get("step_index", 0)) % 4:
		0:
			return "left"
		1:
			return "right"
		2:
			return "right"
		_:
			return "left"


func _video_reference_power(active: Dictionary) -> float:
	match int(active.get("step_index", 0)) % 4:
		0:
			return 0.72
		1:
			return 0.84
		2:
			return 0.92
		_:
			return 0.76


func _run_lane_multiball(table: SlotPinballTable, session: Dictionary, rng: RngStream, active: Dictionary) -> int:
	active["multiball_started"] = true
	var power: float = clampf(float(int(active.get("launch_power", 64))) / 100.0, 0.0, 1.0)
	for lane in ["left", "center", "right"]:
		table.launch_ball(session, rng, {"force": true, "lane": lane, "power": power})
	var max_active_count := table.active_ball_count(session)
	table.run_ticks(session, rng, {
		"mode": "auto_flip",
		"initial_input": {"plunger_charge": power},
		"record_trajectory": not bool(active.get("headless", false)),
		"trajectory_stride": 1,
	}, 4, false)
	active["lit_jackpots"] = maxi(1, int(active.get("lit_jackpots", 0)) + 1)
	return max_active_count


func _run_video_multiball(table: SlotPinballTable, session: Dictionary, rng: RngStream, active: Dictionary) -> int:
	active["multiball_started"] = true
	active["video_multiball_ready"] = false
	var power: float = clampf(float(int(active.get("launch_power", 70))) / 100.0, 0.0, 1.0)
	for lane in ["left", "center", "right"]:
		table.launch_ball(session, rng, {"force": true, "lane": lane, "power": power})
	var max_active_count := table.active_ball_count(session)
	table.run_ticks(session, rng, {
		"mode": "auto_flip",
		"initial_input": {"plunger_charge": power},
		"record_trajectory": not bool(active.get("headless", false)),
		"trajectory_stride": 1,
	}, 4, false)
	max_active_count = maxi(max_active_count, table.active_ball_count(session))
	return max_active_count


func _apply_video_feature_progress(table: SlotPinballTable, session: Dictionary, active: Dictionary, start_index: int) -> void:
	var source_events: Array = _events_since(session, start_index)
	var targets: Dictionary = _copy_dict(active.get("video_targets", {}))
	var super_lit := bool(active.get("video_super_jackpot_lit", false))
	var super_count := maxi(0, int(active.get("video_super_jackpots", 0)))
	var jackpot_count := maxi(0, int(active.get("video_jackpots", 0)))
	var completed_banks := maxi(0, int(active.get("video_completed_banks", 0)))
	for event_value in source_events:
		var event: Dictionary = _copy_dict(event_value)
		var event_type := str(event.get("element_type", ""))
		var element_id := str(event.get("element_id", ""))
		if event_type == "drop_target" and VIDEO_TARGET_IDS.has(element_id):
			targets[element_id] = true
			if _video_target_bank_complete(targets) and not super_lit:
				super_lit = true
				completed_banks += 1
				_light_video_insert(session, "super_jackpot")
		if _video_qualifies_for_jackpot(event_type) and super_lit:
			table.add_award_event(session, "super_jackpot", "super_jackpot", event.get("position", {}), _video_super_award(active), int(event.get("ball_index", 0)))
			super_lit = false
			super_count += 1
			targets = {}
			_unlight_video_insert(session, "super_jackpot")
		elif bool(active.get("multiball_started", false)) and _video_qualifies_for_multiball_jackpot(event_type):
			table.add_award_event(session, "multiball_jackpot", "jackpot", event.get("position", {}), _video_multiball_jackpot_award(active), int(event.get("ball_index", 0)))
			jackpot_count += 1
	active["video_targets"] = targets
	active["video_super_jackpot_lit"] = super_lit
	active["video_super_jackpots"] = super_count
	active["video_jackpots"] = jackpot_count
	active["video_completed_banks"] = completed_banks
	active["video_multiball_ready"] = int(session.get("locks", 0)) >= VIDEO_MULTIBALL_LOCKS and not bool(active.get("multiball_started", false))


func _video_target_bank_complete(targets: Dictionary) -> bool:
	for target_id in VIDEO_TARGET_IDS:
		if not bool(targets.get(str(target_id), false)):
			return false
	return true


func _video_qualifies_for_jackpot(event_type: String) -> bool:
	return event_type == "ramp" or event_type == "orbit" or event_type == "pocket"


func _video_qualifies_for_multiball_jackpot(event_type: String) -> bool:
	return event_type == "ramp" or event_type == "orbit"


func _video_super_award(active: Dictionary) -> int:
	var stake := maxi(1, int(active.get("stake", 1)))
	var scale := maxf(0.35, float(active.get("feature_scale", 1.0)))
	return maxi(1, int(round(float(stake) * 2.8 * scale)))


func _video_multiball_jackpot_award(active: Dictionary) -> int:
	var stake := maxi(1, int(active.get("stake", 1)))
	var scale := maxf(0.35, float(active.get("feature_scale", 1.0)))
	return maxi(1, int(round(float(stake) * 0.65 * scale)))


func _light_video_insert(session: Dictionary, insert_id: String) -> void:
	var lit: Dictionary = _copy_dict(session.get("lit", {}))
	lit[insert_id] = true
	session["lit"] = lit


func _unlight_video_insert(session: Dictionary, insert_id: String) -> void:
	var lit: Dictionary = _copy_dict(session.get("lit", {}))
	lit[insert_id] = false
	session["lit"] = lit


func _events_since(session: Dictionary, start_index: int) -> Array:
	var events: Array = session.get("event_log", []) if typeof(session.get("event_log", [])) == TYPE_ARRAY else []
	var result: Array = []
	for event_index in range(clampi(start_index, 0, events.size()), events.size()):
		result.append(_copy_dict(events[event_index]))
	return result


func _trim_pinball_session_history(session: Dictionary, event_keep: int = 96, trajectory_keep: int = 72) -> void:
	var events: Array = session.get("event_log", []) if typeof(session.get("event_log", [])) == TYPE_ARRAY else []
	while events.size() > event_keep:
		events.remove_at(0)
	session["event_log"] = events
	var trajectory: Array = session.get("trajectory", []) if typeof(session.get("trajectory", [])) == TYPE_ARRAY else []
	while trajectory.size() > trajectory_keep:
		trajectory.remove_at(0)
	session["trajectory"] = trajectory


func _trajectory_since(session: Dictionary, start_index: int) -> Array:
	var trajectory: Array = session.get("trajectory", []) if typeof(session.get("trajectory", [])) == TYPE_ARRAY else []
	var result: Array = []
	for point_index in range(clampi(start_index, 0, trajectory.size()), trajectory.size()):
		result.append(_copy_dict(trajectory[point_index]))
	return result


func _normalize_timed_entries(entries: Array) -> Array:
	if entries.is_empty():
		return []
	var first: Dictionary = _copy_dict(entries[0])
	var start_time := float(first.get("time", 0.0))
	var result: Array = []
	for entry_value in entries:
		var entry: Dictionary = _copy_dict(entry_value)
		entry["time"] = maxf(0.0, float(entry.get("time", 0.0)) - start_time)
		result.append(entry)
	return result


func _snapshot_trajectory(session: Dictionary, local_time: bool = true) -> Array:
	var balls: Array = _copy_array(session.get("balls", []))
	var result: Array = []
	var time_value := 0.0 if local_time else snappedf(float(session.get("time", 0.0)), 0.0001)
	for ball_index in range(balls.size()):
		var ball: Dictionary = _copy_dict(balls[ball_index])
		if not bool(ball.get("alive", false)):
			continue
		result.append({
			"time": time_value,
			"ball_index": ball_index,
			"position": _point_payload(ball.get("position", Vector2(0.5, 0.5))),
		})
	return result


func _motion_preview_trajectory(session: Dictionary) -> Array:
	var layout: Dictionary = _copy_dict(session.get("layout", {}))
	var gravity: Vector2 = _vector2_from_value(layout.get("gravity", Vector2(0.0, 2.8)), Vector2(0.0, 2.8))
	var balls: Array = _copy_array(session.get("balls", []))
	var result: Array = []
	for ball_index in range(balls.size()):
		var ball: Dictionary = _copy_dict(balls[ball_index])
		if not bool(ball.get("alive", false)):
			continue
		var position: Vector2 = _vector2_from_value(ball.get("position", Vector2(0.5, 0.5)), Vector2(0.5, 0.5))
		var velocity: Vector2 = _vector2_from_value(ball.get("velocity", Vector2.ZERO), Vector2.ZERO)
		for preview_index in range(7):
			result.append({
				"time": snappedf(float(preview_index) * 0.06, 0.0001),
				"ball_index": ball_index,
				"position": _point_payload(position),
			})
			velocity += gravity * 0.06
			position += velocity * 0.06
			position.x = clampf(position.x, 0.02, 0.98)
			position.y = clampf(position.y, 0.02, 1.02)
	return result


func _trajectory_has_visible_motion(trajectory: Array) -> bool:
	var first_by_ball: Dictionary = {}
	for point_value in trajectory:
		var point: Dictionary = _copy_dict(point_value)
		var ball_index := int(point.get("ball_index", 0))
		var position: Vector2 = _vector2_from_value(point.get("position", Vector2(0.5, 0.5)), Vector2(0.5, 0.5))
		var key := str(ball_index)
		if not first_by_ball.has(key):
			first_by_ball[key] = position
			continue
		var first_position: Vector2 = first_by_ball[key]
		if first_position.distance_to(position) >= 0.006:
			return true
	return false


func _point_payload(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_VECTOR2:
		var point: Vector2 = value
		return {"x": snappedf(point.x, 0.0001), "y": snappedf(point.y, 0.0001)}
	if typeof(value) == TYPE_DICTIONARY:
		var dict: Dictionary = value
		return {"x": snappedf(float(dict.get("x", 0.5)), 0.0001), "y": snappedf(float(dict.get("y", 0.5)), 0.0001)}
	return {"x": 0.5, "y": 0.5}


func _vector2_from_value(value: Variant, fallback: Vector2) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value as Vector2
	if typeof(value) == TYPE_DICTIONARY:
		var dict: Dictionary = value
		return Vector2(float(dict.get("x", fallback.x)), float(dict.get("y", fallback.y)))
	return fallback


func _lit_count(lit: Dictionary) -> int:
	var total := 0
	for key_value in lit.keys():
		if bool(lit.get(key_value, false)):
			total += 1
	return total


func _physics_from_session(session: Dictionary, mode: String) -> Dictionary:
	var trajectory: Array = _copy_array(session.get("trajectory", []))
	var event_log: Array = _copy_array(session.get("event_log", []))
	var point := Vector2(0.50, 0.12)
	if not trajectory.is_empty():
		var last_point: Dictionary = _copy_dict(_copy_dict(trajectory[trajectory.size() - 1]).get("position", {}))
		point = Vector2(float(last_point.get("x", point.x)), float(last_point.get("y", point.y)))
	elif not event_log.is_empty():
		var last_event_point: Dictionary = _copy_dict(_copy_dict(event_log[event_log.size() - 1]).get("position", {}))
		point = Vector2(float(last_event_point.get("x", point.x)), float(last_event_point.get("y", point.y)))
	var last_target := ""
	if not event_log.is_empty():
		last_target = str(_copy_dict(event_log[event_log.size() - 1]).get("element_id", ""))
	return {
		"ball_x": clampf(point.x, 0.0, 1.0),
		"ball_y": clampf(point.y, 0.0, 1.0),
		"velocity_x": 0.0,
		"velocity_y": 0.0,
		"energy": 1.0 if mode != "video_feature" else 1.25,
		"last_target": last_target,
	}


func _pinball_replay_duration_msec(active: Dictionary) -> int:
	var trajectory: Array = _copy_array(active.get("display_trajectory", []))
	if trajectory.is_empty():
		trajectory = _copy_array(active.get("trajectory", []))
	var last_time := 0.0
	for point_value in trajectory:
		var point: Dictionary = _copy_dict(point_value)
		last_time = maxf(last_time, float(point.get("time", 0.0)))
	var playback_msec := int(ceil((last_time / 1.45 + 0.78) * 1000.0))
	return clampi(playback_msec, 1100, 4200)


func _finish_or_continue(machine: Dictionary, active: Dictionary, message: String) -> Dictionary:
	var session: Dictionary = _copy_dict(active.get("pinball_session", {}))
	var table: SlotPinballTable = TableScript.new()
	var live_count := table.active_ball_count(session) if not session.is_empty() else 0
	_sync_pinball_ball_counters(active, session, table)
	if int(active.get("balls_remaining", 0)) <= 0 and live_count <= 0:
		var minimum_award := _minimum_pinball_feature_award(active)
		var feature_total := int(active.get("feature_total", active.get("pending_award", 0)))
		if feature_total < minimum_award and not session.is_empty():
			table.add_award_event(session, "feature_floor", "bonus", Vector2(0.5, 0.5), minimum_award - feature_total, 0)
			feature_total = table.session_award(session)
			active["pinball_session"] = session
			active["event_log"] = _copy_array(session.get("event_log", []))
		var award := maxi(minimum_award, feature_total)
		active["active"] = false
		active["complete"] = true
		active["awarded"] = award
		active["pending_award"] = award
		active["animation_duration_msec"] = _pinball_replay_duration_msec(active)
		machine["last_bonus_replay"] = active.duplicate(true)
		machine["active_bonus"] = {"active": false, "complete": true}
		return _bonus_step_result(true, award, "%s Total $%d." % [message, award], active)
	machine["active_bonus"] = active
	return _bonus_step_result(false, 0, "%s %d to launch, %d live." % [message, int(active.get("balls_remaining", 0)), live_count], active)


func _minimum_pinball_feature_award(active: Dictionary) -> int:
	var stake := maxi(1, int(active.get("stake", 1)))
	var mode := str(active.get("mode", ""))
	if mode == "video_feature":
		return stake * 3
	if mode == "lane_multiball":
		return stake * 4
	return stake * 2


func _feature_mode(machine: Dictionary) -> String:
	match str(machine.get("format_id", "classic_3_reel")):
		"line_5x3":
			return "lane_multiball"
		"video_feature":
			return "video_feature"
		_:
			return "em_bumper_drop"


func _pinball_choices(mode: String) -> Array:
	if mode == "em_bumper_drop":
		return [{"id": "aim_left"}, {"id": "soft"}, {"id": "plunge"}, {"id": "hard"}, {"id": "aim_right"}]
	if mode == "lane_multiball":
		return [{"id": "left_lane"}, {"id": "soft"}, {"id": "launch"}, {"id": "hard"}, {"id": "right_lane"}]
	return [{"id": "left_orbit"}, {"id": "soft"}, {"id": "plunger"}, {"id": "hard"}, {"id": "right_orbit"}]


func _lane_after(lane: String, direction: int) -> String:
	var lanes := ["left", "center", "right"]
	var index := lanes.find(lane)
	if index < 0:
		index = 1
	index = clampi(index + direction, 0, lanes.size() - 1)
	return str(lanes[index])


func _starting_balls(machine: Dictionary, stake: int) -> int:
	if str(machine.get("format_id", "")) != "classic_3_reel":
		return 5
	if stake <= 2:
		return 1
	if stake <= 5:
		return 2
	if stake <= 10:
		return 3
	if stake <= 15:
		return 4
	return 5


func _append_history(active: Dictionary, step: Dictionary) -> void:
	var history: Array = _dictionary_array(active.get("history", []))
	history.append(step.duplicate(true))
	while history.size() > LIVE_HISTORY_LIMIT:
		history.remove_at(0)
	active["history"] = history


func _recent_history_trajectory(active: Dictionary, limit: int = 96) -> Array:
	var history: Array = _dictionary_array(active.get("history", []))
	var result: Array = []
	var offset := 0.0
	for step_value in history:
		var step: Dictionary = _copy_dict(step_value)
		var trajectory: Array = _copy_array(step.get("trajectory", []))
		var span := 0.0
		for point_value in trajectory:
			var point: Dictionary = _copy_dict(point_value)
			var local_time := maxf(0.0, float(point.get("time", 0.0)))
			span = maxf(span, local_time)
			point["time"] = offset + local_time
			result.append(point)
		offset += maxf(0.20, span + 0.016)
	while result.size() > limit:
		result.remove_at(0)
	return result


func _adjusted_table(table: Array, math_id: String) -> Array:
	var result: Array = []
	for entry_value in table:
		var entry: Dictionary = (entry_value as Dictionary).duplicate(true)
		var id := str(entry.get("id", ""))
		var weight := int(entry.get("weight", 0))
		if math_id == "steady":
			if id == "ldw":
				weight = int(round(float(weight) * 1.08))
			elif id == "true_win":
				weight = int(round(float(weight) * 0.96))
			elif id == "bonus":
				weight = int(round(float(weight) * 0.90))
		elif math_id == "volatile":
			if id == "zero_loss":
				weight = int(round(float(weight) * 1.04))
			elif id == "ldw":
				weight = int(round(float(weight) * 0.88))
			elif id == "bonus":
				weight = int(round(float(weight) * 1.20))
		entry["weight"] = maxi(0, weight)
		result.append(entry)
	return _normalize_table_total(result, 1000)


func _normalize_table_total(table: Array, target_total: int) -> Array:
	var total := 0
	for entry_value in table:
		total += maxi(0, int((entry_value as Dictionary).get("weight", 0)))
	var delta := target_total - total
	for i in range(table.size()):
		var entry: Dictionary = table[i]
		if str(entry.get("id", "")) == "zero_loss":
			entry["weight"] = maxi(0, int(entry.get("weight", 0)) + delta)
			table[i] = entry
			break
	return table


func _bonus_step_result(complete: bool, award: int, message: String, active: Dictionary) -> Dictionary:
	return {
		"complete": complete,
		"award": maxi(0, award),
		"message": message,
		"active_bonus": active.duplicate(true),
	}


func _fill_nonpaying_grid(grid: Array, rng: RngStream = null) -> void:
	var seed := _grid_seed(grid)
	for reel_index in range(grid.size()):
		if typeof(grid[reel_index]) != TYPE_ARRAY:
			continue
		var column: Array = grid[reel_index] as Array
		for row_index in range(column.size()):
			var cell_seed := seed
			if rng != null:
				cell_seed = posmod(cell_seed + rng.randi_range(0, 100000), 100003)
			column[row_index] = _pinball_fill_symbol(reel_index, row_index, cell_seed)
		grid[reel_index] = column


func _pinball_win_symbol_for_count(win_count: int, format_id: String, rng: RngStream) -> String:
	var roll := rng.randi_range(1, 100)
	if win_count >= 5:
		return "BUMPER" if roll >= 40 else "CHERRY"
	if win_count >= 4:
		return "BUMPER" if roll >= 66 else "CHERRY"
	if format_id != "classic_3_reel":
		return "BUMPER" if roll >= 45 else "BALL"
	if roll <= 50:
		return "BALL"
	if roll <= 80:
		return "SPINNER"
	if roll <= 96:
		return "BAR"
	return "7"


func _pinball_true_win_plan(reel_count: int, format_id: String, rng: RngStream, definition: Dictionary) -> Dictionary:
	var safe_reels := maxi(1, reel_count)
	var config: Dictionary = _pinball_config(definition)
	var symbols: Dictionary = _symbol_lookup(config)
	var profiles_by_format: Dictionary = _copy_dict(config.get("true_win_profiles", {}))
	var raw_profiles: Array = _dictionary_array(profiles_by_format.get(format_id, []))
	if raw_profiles.is_empty() and format_id != "classic_3_reel":
		raw_profiles = _dictionary_array(profiles_by_format.get("line_5x3", []))
	var candidates: Array = []
	var minimum_count := mini(3, safe_reels)
	for profile_value in raw_profiles:
		var profile: Dictionary = profile_value
		var symbol := str(profile.get("symbol", ""))
		var count := int(profile.get("count", 3))
		if count < minimum_count or count > safe_reels:
			continue
		if symbol.is_empty() or not symbols.has(symbol) or _pinball_wild(symbol):
			continue
		var symbol_def: Dictionary = _copy_dict(symbols.get(symbol, {}))
		if str(symbol_def.get("role", "")) == "bonus_scatter":
			continue
		candidates.append(profile.duplicate(true))
	if candidates.is_empty():
		return _pinball_legacy_true_win_plan(safe_reels, format_id, rng)
	var picked: Dictionary = MathScript.weighted_pick(candidates, rng)
	var picked_count := clampi(int(picked.get("count", 3)), minimum_count, safe_reels)
	var wild_symbol := str(picked.get("wild_symbol", "DOUBLE"))
	if not _pinball_wild(wild_symbol):
		wild_symbol = "DOUBLE"
	var wild_cell_index := -1
	var wild_chance := clampi(int(picked.get("wild_chance", 0)), 0, 100)
	if wild_chance > 0 and rng.randi_range(1, 100) <= wild_chance:
		wild_cell_index = rng.randi_range(0, picked_count - 1)
	return {
		"count": picked_count,
		"symbol": str(picked.get("symbol", "BALL")),
		"wild_cell_index": wild_cell_index,
		"wild_symbol": wild_symbol,
	}


func _pinball_legacy_true_win_plan(reel_count: int, format_id: String, rng: RngStream) -> Dictionary:
	var max_win_count := mini(5, reel_count)
	var win_count := 3
	var roll := rng.randi_range(1, 100)
	if format_id == "video_feature":
		max_win_count = mini(6, reel_count)
		if max_win_count >= 6 and roll >= 100:
			win_count = 6
		elif max_win_count >= 5 and roll >= 98:
			win_count = 5
		elif max_win_count >= 4 and roll >= 93:
			win_count = 4
	elif format_id == "line_5x3":
		if max_win_count >= 5 and roll >= 100:
			win_count = 5
		elif max_win_count >= 4 and roll >= 94:
			win_count = 4
	elif max_win_count >= 4 and roll >= 99:
		win_count = 4
	return {
		"count": win_count,
		"symbol": _pinball_win_symbol_for_count(win_count, format_id, rng),
		"wild_cell_index": -1,
		"wild_symbol": "DOUBLE",
	}


func _sanitize_pinball_grid(grid: Array, definition: Dictionary, protected_cells: Dictionary) -> void:
	_limit_symbol_count(grid, "PINBALL", 2, protected_cells)
	var guard := 0
	while guard < 96:
		var violation: Dictionary = _first_pinball_win_violation(grid, definition, protected_cells)
		if violation.is_empty():
			return
		var break_cell: Dictionary = _first_unprotected_cell(_copy_array(violation.get("cells", [])), protected_cells)
		if break_cell.is_empty():
			return
		MathScript.set_cell(grid, int(break_cell.get("reel", 0)), int(break_cell.get("row", 0)), "BLANK")
		guard += 1


func _first_pinball_win_violation(grid: Array, definition: Dictionary, protected_cells: Dictionary) -> Dictionary:
	var symbols: Dictionary = _symbol_lookup(_pinball_config(definition))
	var row_count := _grid_row_count(grid)
	var reel_count := grid.size()
	for line_index in range(MathScript.payline_count(row_count)):
		var line_cells: Array = MathScript.payline_cells(reel_count, row_count, line_index)
		for start_index in range(line_cells.size()):
			for candidate_value in symbols.keys():
				var candidate := str(candidate_value)
				var symbol_def: Dictionary = _copy_dict(symbols.get(candidate, {}))
				if str(symbol_def.get("role", "")) == "bonus_scatter" or _pinball_wild(candidate):
					continue
				var cells: Array = []
				for cell_index in range(start_index, line_cells.size()):
					var cell: Dictionary = _copy_dict(line_cells[cell_index])
					var symbol := _cell_symbol(grid, int(cell.get("reel", 0)), int(cell.get("row", 0)))
					if symbol == candidate or _pinball_wild(symbol):
						cells.append(cell)
					else:
						break
				if cells.size() >= 3 and not _all_cells_protected(cells, protected_cells):
					return {"cells": cells, "symbol": candidate, "line_index": line_index}
	return {}


func _limit_symbol_count(grid: Array, symbol_id: String, max_count: int, protected_cells: Dictionary) -> void:
	var seen := 0
	for reel_index in range(grid.size()):
		if typeof(grid[reel_index]) != TYPE_ARRAY:
			continue
		var column: Array = grid[reel_index] as Array
		for row_index in range(column.size()):
			if str(column[row_index]) != symbol_id:
				continue
			seen += 1
			if seen > max_count and not bool(protected_cells.get("%d:%d" % [reel_index, row_index], false)):
				column[row_index] = "BLANK"
		grid[reel_index] = column


func _protected_cell_lookup(cells: Array) -> Dictionary:
	var lookup := {}
	for cell_value in cells:
		var cell: Dictionary = _copy_dict(cell_value)
		lookup["%d:%d" % [int(cell.get("reel", -1)), int(cell.get("row", -1))]] = true
	return lookup


func _first_unprotected_cell(cells: Array, protected_cells: Dictionary) -> Dictionary:
	var index := cells.size() - 1
	while index >= 0:
		var cell: Dictionary = _copy_dict(cells[index])
		if not bool(protected_cells.get("%d:%d" % [int(cell.get("reel", -1)), int(cell.get("row", -1))], false)):
			return cell
		index -= 1
	return {}


func _all_cells_protected(cells: Array, protected_cells: Dictionary) -> bool:
	if cells.is_empty():
		return false
	for cell_value in cells:
		var cell: Dictionary = _copy_dict(cell_value)
		if not bool(protected_cells.get("%d:%d" % [int(cell.get("reel", -1)), int(cell.get("row", -1))], false)):
			return false
	return true


func _random_payline(reel_count: int, row_count: int, count: int, rng: RngStream) -> Dictionary:
	var safe_reels := maxi(1, reel_count)
	var safe_rows := maxi(1, row_count)
	var target_count := mini(maxi(1, count), safe_reels)
	var start_reel := rng.randi_range(0, maxi(0, safe_reels - target_count))
	var line_index := rng.randi_range(0, MathScript.payline_count(safe_rows) - 1)
	return {
		"line_index": line_index,
		"start_reel": start_reel,
		"cells": MathScript.payline_cells_from(safe_reels, safe_rows, line_index, start_reel, target_count),
	}


func _stop_pinball_extension(grid: Array, line_index: int, cells: Array, symbol: String) -> void:
	if cells.is_empty() or grid.is_empty():
		return
	var row_count := _grid_row_count(grid)
	var min_reel := grid.size()
	var max_reel := -1
	for cell_value in cells:
		var cell: Dictionary = _copy_dict(cell_value)
		var reel_index := int(cell.get("reel", -1))
		min_reel = mini(min_reel, reel_index)
		max_reel = maxi(max_reel, reel_index)
	for stop_reel in [min_reel - 1, max_reel + 1]:
		if stop_reel < 0 or stop_reel >= grid.size():
			continue
		var stop_cells: Array = MathScript.payline_cells_from(grid.size(), row_count, line_index, stop_reel, 1)
		if stop_cells.is_empty():
			continue
		var stop_cell: Dictionary = _copy_dict(stop_cells[0])
		var stop_row := int(stop_cell.get("row", 0))
		var column: Array = grid[stop_reel] if typeof(grid[stop_reel]) == TYPE_ARRAY else []
		if stop_row >= 0 and stop_row < column.size():
			var current_symbol := str(column[stop_row])
			if current_symbol == symbol or _pinball_wild(current_symbol):
				column[stop_row] = _safe_pinball_fill_symbol(stop_reel, stop_row, symbol)
		grid[stop_reel] = column


func _safe_pinball_fill_symbol(reel_index: int, row_index: int, avoid_symbol: String) -> String:
	var symbol := _pinball_fill_symbol(reel_index, row_index, reel_index + row_index + 1)
	if symbol == avoid_symbol or _pinball_wild(symbol):
		return "BAR" if avoid_symbol != "BAR" else "BALL"
	return symbol


func _pinball_fill_symbol(reel_index: int, row_index: int, seed: int) -> String:
	var choices: Array = FILL_REEL_SYMBOLS[posmod(reel_index, FILL_REEL_SYMBOLS.size())]
	return str(choices[posmod(seed + reel_index * 3 + row_index, choices.size())])


func _grid_seed(grid: Array) -> int:
	var seed := 0
	for reel_index in range(grid.size()):
		var column: Array = grid[reel_index] if typeof(grid[reel_index]) == TYPE_ARRAY else []
		for row_index in range(column.size()):
			var text := str(column[row_index])
			for char_index in range(text.length()):
				seed = posmod(seed + text.unicode_at(char_index) + reel_index * 17 + row_index * 31, 9973)
	return seed


func _line_payout(line_symbols: Array, stake: int, stake_cost: int, symbols: Dictionary) -> int:
	if line_symbols.is_empty():
		return 0
	var candidates: Array = []
	for symbol_value in line_symbols:
		var symbol := str(symbol_value)
		if _pinball_wild(symbol):
			continue
		if not symbols.has(symbol):
			continue
		var symbol_def: Dictionary = _copy_dict(symbols.get(symbol, {}))
		if str(symbol_def.get("role", "")) == "bonus_scatter":
			continue
		candidates.append(symbol)
	if candidates.is_empty():
		candidates = ["BALL"]
	var best := 0
	for candidate_value in candidates:
		var candidate := str(candidate_value)
		var consecutive := 0
		var multiplier := 1
		for symbol_value in line_symbols:
			var symbol := str(symbol_value)
			if symbol == candidate or _pinball_wild(symbol):
				consecutive += 1
				multiplier = mini(8, multiplier * _pinball_multiplier(symbol))
			else:
				break
		if consecutive < 3:
			continue
		if candidate == "CHERRY" and consecutive == 3 and stake_cost > 1:
			best = maxi(best, maxi(1, stake_cost - 1))
			continue
		var symbol_def: Dictionary = _copy_dict(symbols.get(candidate, {}))
		var pay_key := "pay%d" % mini(consecutive, 6)
		var pay := int(symbol_def.get(pay_key, symbol_def.get("triple", 0)))
		best = maxi(best, stake * pay * multiplier)
	return best


func _pinball_wild(symbol: String) -> bool:
	return symbol == "WILD" or symbol == "DOUBLE" or symbol == "DOUBLE_7"


func _pinball_multiplier(symbol: String) -> int:
	if symbol == "DOUBLE" or symbol == "DOUBLE_7":
		return 2
	return 1


func _symbol_lookup(config: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for symbol_value in _dictionary_array(config.get("symbols", [])):
		var symbol: Dictionary = symbol_value
		result[str(symbol.get("id", ""))] = symbol.duplicate(true)
	return result


func _cell_symbol(grid: Array, reel_index: int, row_index: int) -> String:
	if reel_index < 0 or reel_index >= grid.size() or typeof(grid[reel_index]) != TYPE_ARRAY:
		return "BLANK"
	var column: Array = grid[reel_index] as Array
	if row_index < 0 or row_index >= column.size():
		return "BLANK"
	return str(column[row_index])


func _grid_row_count(grid: Array) -> int:
	if grid.is_empty() or typeof(grid[0]) != TYPE_ARRAY:
		return 1
	return maxi(1, (grid[0] as Array).size())


func _pinball_config(definition: Dictionary) -> Dictionary:
	return _copy_dict(definition.get("slot_pinball_config", {}))


func _variant_by_id(entries_value: Variant, variant_id: String) -> Dictionary:
	for entry_value in _dictionary_array(entries_value):
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) == variant_id:
			return entry.duplicate(true)
	return {}


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var source: Array = value as Array
	for entry in source:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
