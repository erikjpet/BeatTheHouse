class_name PinballFeature
extends RefCounted

const BoardsScript := preload("res://scripts/games/slots/pinball/pinball_boards.gd")
const BoardScript := preload("res://scripts/games/slots/pinball/pinball_board.gd")
const SimScript := preload("res://scripts/games/slots/pinball/pinball_sim.gd")

const AIM_MIN := -60
const AIM_MAX := 60
const AIM_STEP := 2
const DIRECT_AIM_STEPS := 24
const DIRECT_START_STEPS := 24
const DIRECT_POWER_STEPS := 20

static var _sessions: Dictionary = {}
static var _layouts: Dictionary = {}
static var _compiled_boards: Dictionary = {}


func open(machine: Dictionary, mode: String, stake: int, rng: RngStream, params: Dictionary = {}) -> Dictionary:
	var session_seed := rng.randi_range(1, 2140000000)
	var session_id := "pinball:%s:%s:%d" % [str(machine.get("format_id", "")), mode, session_seed]
	var layout: Dictionary = BoardsScript.by_id(_board_id_for_mode(mode))
	layout["mode"] = mode
	if mode == "lane_multiball":
		layout["title"] = "Lock & Cascade"
		layout["id"] = "lock_cascade"
	elif mode == "video_feature":
		layout["title"] = "Jackpot Works"
		layout["id"] = "jackpot_works"
	var compiler := BoardScript.new()
	var compiled: Dictionary = compiler.compile(layout, _compile_modifiers(params))
	var sim := SimScript.new()
	var cap := maxi(1, int(params.get("cap", stake * 12)))
	sim.configure(compiled, session_seed, {"cap": cap})
	_sessions[session_id] = sim
	_layouts[session_id] = _layout_view(layout)
	_compiled_boards[session_id] = compiled
	var total_balls := maxi(1, int(params.get("ball_budget", _ball_budget_for_mode(mode, stake))))
	var active := {
		"active": true,
		"complete": false,
		"family": "pinball",
		"mode": mode,
		"runtime_session_id": session_id,
		"runtime_seed": session_seed,
		"board_id": str(layout.get("id", "")),
		"bet_id": str(params.get("bet_id", "")),
		"stake": stake,
		"feature_scale": float(params.get("feature_scale", 1.0)),
		"session_cap": cap,
		"pending_award": 0,
		"feature_total": 0,
		"awarded": 0,
		"remaining_steps": total_balls,
		"total_steps": total_balls,
		"balls_remaining": total_balls,
		"step_index": 0,
		"active_ball_count": 0,
		"launch_power": int(params.get("launch_power", _default_launch_power(mode, rng))),
		"launch_angle_degrees": 0,
		"launch_start": _point_payload(_launch_start_for_angle(mode, 0)),
		"launch_start_manual": false,
		"selected_lane": "center",
		"selected_path": "center",
		"launch_in_progress": false,
		"pinball_summary": {},
		"pinball_view": {},
		"pinball_item_effects": _dict(params.get("item_effects", {})),
		"input_log": [],
		"event_log": [],
		"trajectory": [],
		"display_event_log": [],
		"display_trajectory": [],
		"last_event_count": 0,
		"combo_state": {"route_id": "", "step": 0, "multiplier": 1, "timer_ticks": 0, "label": ""},
		"pinball_debug": {},
		"lane_locks": 0,
		"lit_jackpots": 0,
		"max_active_count": 0,
		"multiball_started": false,
		"video_targets": {},
		"video_super_jackpot_lit": false,
		"video_super_jackpots": 0,
		"video_jackpots": 0,
		"video_completed_banks": 0,
		"video_multiball_ready": false,
		"physics": _physics_from_point(_launch_start_for_angle(mode, 0), "plunger"),
		"physics_tick_budget": 0,
		"physics_frame_index": 0,
		"last_launch_skill": {},
		"launch_skill": _launch_skill_snapshot({}, mode, 0, int(params.get("launch_power", 70)), false),
		"animation_duration_msec": 1600,
	}
	_refresh_active(active, sim, [], [])
	return active


func step(machine: Dictionary, action_id: String, rng: RngStream, _definition: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
	var active: Dictionary = _dict(machine.get("active_bonus", {}))
	if active.is_empty() or not bool(active.get("active", false)):
		return _bonus_step_result(false, 0, "No pinball feature is loaded.", active)
	var mode := str(active.get("mode", "em_bumper_drop"))
	var session_id := str(active.get("runtime_session_id", ""))
	var sim = _session_for(active)
	var message := "Pinball ready."
	var complete := false
	var before_total := int(sim.total_awarded)
	var before_events := maxi(0, int(active.get("last_event_count", 0)))
	var local_events: Array = []
	var local_trajectory: Array = []
	if action_id.begins_with("slot_bonus_aim_"):
		_apply_direct_aim(active, mode, action_id)
		machine["active_bonus"] = active
		return _bonus_step_result(false, 0, "Aim set.", active)
	if action_id.begins_with("slot_bonus_start_"):
		_apply_direct_start(active, mode, action_id)
		machine["active_bonus"] = active
		return _bonus_step_result(false, 0, "Launch point set.", active)
	if action_id.begins_with("slot_bonus_power_") and action_id != "slot_bonus_power_down" and action_id != "slot_bonus_power_up":
		_apply_direct_power(active, action_id)
		machine["active_bonus"] = active
		return _bonus_step_result(false, 0, "Launch power set.", active)
	if action_id == "slot_bonus_power_down":
		active["launch_power"] = clampi(int(active.get("launch_power", 70)) - 6, 20, 100)
		_refresh_launch_state(active, mode, false, ui_state)
		machine["active_bonus"] = active
		return _bonus_step_result(false, 0, "Soft shot.", active)
	if action_id == "slot_bonus_power_up":
		active["launch_power"] = clampi(int(active.get("launch_power", 70)) + 6, 20, 100)
		_refresh_launch_state(active, mode, false, ui_state)
		machine["active_bonus"] = active
		return _bonus_step_result(false, 0, "Hard shot.", active)
	var live_before: bool = sim.active_ball_count() > 0
	if action_id == "slot_bonus_left":
		if live_before:
			sim.set_controls(-0.55, 0.0, true, false)
			_log_input(active, action_id)
			message = "Left nudge."
		else:
			_adjust_aim(active, mode, -AIM_STEP)
			machine["active_bonus"] = active
			return _bonus_step_result(false, 0, "Aim left.", active)
	elif action_id == "slot_bonus_right":
		if live_before:
			sim.set_controls(0.55, 0.0, false, true)
			_log_input(active, action_id)
			message = "Right nudge."
		else:
			_adjust_aim(active, mode, AIM_STEP)
			machine["active_bonus"] = active
			return _bonus_step_result(false, 0, "Aim right.", active)
	elif action_id == "slot_bonus_tilt":
		sim.set_controls(1.0, 1.0, true, true)
		_log_input(active, action_id)
		message = "Tilt nudge."
	elif action_id == "slot_bonus_launch":
		if not live_before and int(active.get("balls_remaining", 0)) > 0:
			_refresh_launch_state(active, mode, true, ui_state)
			sim.launch_ball(_launch_params(active, mode))
			_log_input(active, "slot_bonus_launch")
			message = "Pinball launch."
		elif not live_before:
			complete = true
	else:
		message = "Pinball physics."
	var live_display := _live_display(ui_state)
	var ticks_to_run := _ticks_for_step(active, sim, live_display)
	if ticks_to_run > 0 and sim.active_ball_count() > 0:
		active["physics_tick_budget"] = ticks_to_run
		_run_ticks_with_trajectory(sim, ticks_to_run, local_trajectory, live_display)
	if not live_display:
		while sim.active_ball_count() > 0 and int(sim.tick) < int(sim.max_ticks):
			_run_ticks_with_trajectory(sim, 6, local_trajectory, false)
	_apply_mode_progress(active, sim, mode)
	local_events = sim.event_log_since(before_events)
	var step_award := maxi(0, int(sim.total_awarded) - before_total)
	_refresh_active(active, sim, local_events, local_trajectory)
	if int(active.get("balls_remaining", 0)) <= 0 and sim.active_ball_count() <= 0:
		complete = true
	if complete:
		return _finish(machine, active, sim, message)
	machine["active_bonus"] = active
	return _bonus_step_result(false, step_award, "%s in play." % message if sim.active_ball_count() > 0 else "%s %d balls left." % [message, int(active.get("balls_remaining", 0))], active)


func preview(machine: Dictionary, stake: int, definition: Dictionary, rng: RngStream, inputs: Array) -> int:
	var active := open(machine, _mode_for_machine(machine), stake, rng, {
		"cap": _session_cap(stake, _mode_for_machine(machine), 1.0),
		"ball_budget": _ball_budget_for_mode(_mode_for_machine(machine), stake),
	})
	active["headless"] = true
	machine["active_bonus"] = active
	var total := 0
	var guard := 0
	while bool(active.get("active", false)) and guard < 24:
		var action_id := "slot_bonus_launch"
		if guard < inputs.size():
			action_id = str(inputs[guard])
		var result: Dictionary = step(machine, action_id, rng, definition, {})
		total += int(result.get("award", 0))
		active = _dict(result.get("active_bonus", machine.get("active_bonus", {})))
		machine["active_bonus"] = active
		guard += 1
	return maxi(total, int(active.get("awarded", active.get("feature_total", 0)))) + _input_bonus(inputs, stake, str(active.get("mode", "")))


static func surface_refresh(active: Dictionary, surface_time_msec: int) -> Dictionary:
	var result := active.duplicate(false)
	var sim = _session_for_static(result)
	if sim != null and bool(result.get("active", false)) and sim.active_ball_count() > 0:
		var last_msec := maxi(0, int(result.get("last_physics_real_msec", 0)))
		var elapsed := 16 if last_msec <= 0 else clampi(surface_time_msec - last_msec, 1, 34)
		var ticks_to_run := clampi(int(round(float(elapsed) / (SimScript.FIXED_DT * 1000.0))), 1, 3)
		for _i in range(ticks_to_run):
			sim.step_tick()
		result["last_physics_real_msec"] = surface_time_msec
		result["active_ball_count"] = sim.active_ball_count()
		result["pinball_view"] = _view_for_static(result, sim, [], sim.active_position_log())
	return result


func _refresh_active(active: Dictionary, sim, local_events: Array, local_trajectory: Array) -> void:
	var snapshot: Dictionary = sim.compact_snapshot()
	var total_steps := maxi(1, int(active.get("total_steps", 1)))
	var launched := clampi(int(snapshot.get("balls_launched", 0)), 0, total_steps)
	var live_count := int(snapshot.get("active_ball_count", 0))
	var balls_remaining := maxi(0, total_steps - launched)
	active["feature_total"] = int(snapshot.get("total_awarded", 0))
	active["pending_award"] = int(snapshot.get("total_awarded", 0))
	active["balls_remaining"] = balls_remaining
	active["remaining_steps"] = balls_remaining + live_count
	active["active_ball_count"] = live_count
	active["launch_in_progress"] = live_count > 0
	active["step_index"] = maxi(0, int(snapshot.get("drain_count", 0)))
	active["max_active_count"] = maxi(int(active.get("max_active_count", 0)), int(snapshot.get("max_active_seen", 0)))
	active["last_event_count"] = int(snapshot.get("event_total_count", 0))
	active["pinball_summary"] = _summary_for(active, sim)
	active["pinball_debug"] = snapshot
	active["display_event_log"] = local_events
	active["display_trajectory"] = local_trajectory
	active["event_log"] = _trimmed(_array(active.get("event_log", [])) + local_events, 160)
	active["trajectory"] = _trimmed(_array(active.get("trajectory", [])) + local_trajectory, 220)
	active["pinball_view"] = _view_for(active, sim, local_events, local_trajectory)
	if not local_trajectory.is_empty():
		var last_point: Dictionary = _dict(local_trajectory[local_trajectory.size() - 1])
		active["physics"] = _physics_from_point(_vector2(last_point.get("position", Vector2(0.5, 0.5)), Vector2(0.5, 0.5)), str(last_point.get("element_id", "")))
	active["animation_duration_msec"] = 1600 + mini(2600, int(active["trajectory"].size()) * 18)
	active["physics_frame_index"] = maxi(0, int(active.get("physics_frame_index", 0))) + 1


func _finish(machine: Dictionary, active: Dictionary, sim, message: String) -> Dictionary:
	var minimum := _minimum_award(active)
	if int(sim.total_awarded) < minimum:
		sim.total_awarded = minimum
		active["feature_total"] = minimum
		active["pending_award"] = minimum
	var award := mini(int(active.get("session_cap", sim.session_cap)), maxi(minimum, int(sim.total_awarded)))
	active["active"] = false
	active["complete"] = true
	active["awarded"] = award
	active["feature_total"] = award
	active["pending_award"] = award
	active["active_ball_count"] = 0
	active["remaining_steps"] = 0
	active["balls_remaining"] = 0
	active["launch_in_progress"] = false
	active["pinball_view"] = _view_for(active, sim, [], [])
	_sessions.erase(str(active.get("runtime_session_id", "")))
	machine["last_bonus_replay"] = active.duplicate(true)
	machine["active_bonus"] = {"active": false, "complete": true}
	return _bonus_step_result(true, award, "%s Total $%d." % [message, award], active)


func _session_for(active: Dictionary):
	var session_id := str(active.get("runtime_session_id", ""))
	if _sessions.has(session_id):
		return _sessions[session_id]
	var compiler := BoardScript.new()
	var layout: Dictionary = BoardsScript.by_id(_board_id_for_mode(str(active.get("mode", ""))))
	var compiled: Dictionary = compiler.compile(layout)
	var sim := SimScript.new()
	sim.configure(compiled, int(active.get("runtime_seed", 1)), {"cap": int(active.get("session_cap", 500))})
	_sessions[session_id] = sim
	_layouts[session_id] = _layout_view(layout)
	_compiled_boards[session_id] = compiled
	return sim


static func _session_for_static(active: Dictionary):
	var session_id := str(active.get("runtime_session_id", ""))
	return _sessions.get(session_id, null)


func _run_ticks_with_trajectory(sim, ticks_to_run: int, trajectory: Array, local_time: bool) -> void:
	var start_tick := int(sim.tick)
	for index in range(maxi(0, ticks_to_run)):
		sim.step_tick()
		if index % 3 == 0 or sim.active_ball_count() == 0:
			var local_sec := float(sim.tick - start_tick) * SimScript.FIXED_DT if local_time else -1.0
			trajectory.append_array(sim.active_position_log(local_sec))


func _apply_mode_progress(active: Dictionary, sim, mode: String) -> void:
	var events: Array = sim.event_log_since(maxi(0, int(active.get("last_event_count", 0))))
	var bumper_hits := 0
	for event_value in events:
		var event: Dictionary = _dict(event_value)
		match str(event.get("element_type", "")):
			"bumper", "slingshot":
				bumper_hits += 1
			"launcher":
				active["lane_locks"] = maxi(int(active.get("lane_locks", 0)), 1)
			"skill_shot":
				active["lit_jackpots"] = maxi(1, int(active.get("lit_jackpots", 0)))
	if bumper_hits >= 4:
		active["combo_state"] = {"route_id": "bumper_streak", "step": 4, "multiplier": 2, "timer_ticks": 120, "label": "BUMPER STREAK"}
	if mode == "lane_multiball" and int(active.get("lane_locks", 0)) >= 1 and not bool(active.get("multiball_started", false)):
		active["multiball_started"] = true
		for aim in [-0.35, 0.0, 0.35]:
			sim.launch_ball({"power": 0.70, "aim": aim})
		active["lane_locks"] = 3
	if mode == "video_feature":
		active["video_completed_banks"] = maxi(1, int(active.get("video_completed_banks", 0)))
		active["video_super_jackpot_lit"] = true
		if int(active.get("lane_locks", 0)) >= 1:
			active["video_super_jackpots"] = maxi(1, int(active.get("video_super_jackpots", 0)))


func _view_for(active: Dictionary, sim, local_events: Array, local_trajectory: Array) -> Dictionary:
	return _view_for_static(active, sim, local_events, local_trajectory)


static func _view_for_static(active: Dictionary, sim, local_events: Array, local_trajectory: Array) -> Dictionary:
	var session_id := str(active.get("runtime_session_id", ""))
	return {
		"layout": _layouts.get(session_id, {}),
		"balls": sim.active_position_log(),
		"events": local_events,
		"trajectory": local_trajectory,
		"time": float(sim.tick) * SimScript.FIXED_DT,
		"lit": _dict_static(active.get("lit", {})),
		"jackpot_progress": int(active.get("lit_jackpots", 0)),
	}


func _summary_for(active: Dictionary, sim) -> Dictionary:
	return {
		"seed": int(active.get("runtime_seed", 0)),
		"board_id": str(active.get("board_id", "")),
		"balls_remaining": int(active.get("balls_remaining", 0)),
		"total_awarded": int(sim.total_awarded),
		"sequencer_snapshot": {
			"locks": int(active.get("lane_locks", 0)),
			"multiball": bool(active.get("multiball_started", false)),
			"combo": _dict(active.get("combo_state", {})),
		},
		"input_log": _array(active.get("input_log", [])),
	}


static func _layout_view(layout: Dictionary) -> Dictionary:
	var elements: Array = []
	for peg_value in _array_static(layout.get("pegs", [])):
		var peg: Dictionary = _dict_static(peg_value)
		elements.append({"id": str(peg.get("id", "")), "type": "peg", "shape": "circle", "position": peg.get("position", Vector2.ZERO), "radius": peg.get("radius", 0.013), "award": peg.get("award", 0)})
	for bumper_value in _array_static(layout.get("bumpers", [])):
		var bumper: Dictionary = _dict_static(bumper_value)
		elements.append({"id": str(bumper.get("id", "")), "type": "bumper", "shape": "circle", "position": bumper.get("position", Vector2.ZERO), "radius": bumper.get("radius", 0.045), "award": bumper.get("award", 0), "label": "POP"})
	for sensor_value in _array_static(layout.get("sensors", [])):
		var sensor: Dictionary = _dict_static(sensor_value)
		var sensor_type := str(sensor.get("type", "sensor"))
		elements.append({"id": str(sensor.get("id", "")), "type": sensor_type, "shape": "sensor_circle", "position": sensor.get("position", Vector2.ZERO), "radius": sensor.get("radius", 0.04), "award": sensor.get("award", 0), "label": sensor_type.left(4).to_upper(), "light": str(sensor.get("id", ""))})
	for rect_value in _array_static(layout.get("rects", [])):
		var rect_element: Dictionary = _dict_static(rect_value)
		var rect_type := str(rect_element.get("type", "pocket"))
		elements.append({"id": str(rect_element.get("id", "")), "type": rect_type, "shape": "drain_rect" if rect_type == "drain" else "slot_rect", "rect": rect_element.get("rect", Rect2()), "award": rect_element.get("award", 0), "label": str(rect_element.get("award", ""))})
	for flipper_value in _array_static(layout.get("flippers", [])):
		var flipper: Dictionary = _dict_static(flipper_value)
		var pos: Vector2 = flipper.get("position", Vector2.ZERO)
		var side := int(flipper.get("side", 0))
		elements.append({"id": str(flipper.get("id", "")), "type": "flipper", "shape": "segment", "a": pos + Vector2(float(side) * 0.08, 0.02), "b": pos + Vector2(float(-side) * 0.08, -0.02), "pivot": pos, "rest_tip": pos + Vector2(float(-side) * 0.08, -0.02), "active_tip": pos + Vector2(float(-side) * 0.11, -0.07)})
	return {
		"id": str(layout.get("id", "")),
		"board_style": "plinko",
		"archetype": str(layout.get("mode", "")),
		"board_title": str(layout.get("title", "")),
		"gravity": Vector2(0.0, float(layout.get("gravity", 3.15))),
		"launch_speed_min": float(layout.get("launch_min_speed", 0.55)),
		"launch_speed_max": float(layout.get("launch_max_speed", 1.85)),
		"lane_starts": {"left": Vector2(0.20, 0.075), "center": Vector2(0.50, 0.075), "right": Vector2(0.80, 0.075)},
		"lane_directions": {"left": Vector2(-0.22, 1.0), "center": Vector2(0.0, 1.0), "right": Vector2(0.22, 1.0)},
		"elements": elements,
	}


func _refresh_launch_state(active: Dictionary, mode: String, sampled: bool, ui_state: Dictionary) -> void:
	var skill := _launch_skill_snapshot(active, mode, int(ui_state.get("surface_time_msec", 0)), int(active.get("launch_power", 70)), sampled)
	active["launch_skill"] = skill
	if sampled:
		active["last_launch_skill"] = skill.duplicate(true)


func _launch_skill_snapshot(active: Dictionary, mode: String, time_msec: int, power: int, sampled: bool) -> Dictionary:
	var safe_power := clampi(power, 20, 100)
	var sweet := 82
	var error := absi(safe_power - sweet)
	var rating := "clean"
	if error <= 4:
		rating = "sweet"
	elif error <= 10:
		rating = "good"
	elif error >= 24:
		rating = "wild"
	return {
		"sampled": sampled,
		"time_msec": maxi(0, time_msec),
		"target_power": safe_power,
		"power": safe_power,
		"meter": snappedf(float(safe_power) / 100.0, 0.001),
		"sweet_spot": sweet,
		"rating": rating,
		"angle_degrees": int(active.get("launch_angle_degrees", 0)),
		"launch_start": _point_payload(_launch_start_for_angle(mode, int(active.get("launch_angle_degrees", 0)))),
		"controlled": true,
	}


func _launch_params(active: Dictionary, mode: String) -> Dictionary:
	return {
		"power": clampf(float(int(active.get("launch_power", 70))) / 100.0, 0.0, 1.0),
		"aim": clampf(float(int(active.get("launch_angle_degrees", 0))) / 60.0, -1.0, 1.0),
		"position": _vector2(active.get("launch_start", _launch_start_for_angle(mode, 0)), _launch_start_for_angle(mode, 0)),
	}


func _adjust_aim(active: Dictionary, mode: String, delta: int) -> void:
	active["launch_angle_degrees"] = clampi(int(active.get("launch_angle_degrees", 0)) + delta, AIM_MIN, AIM_MAX)
	active["selected_lane"] = _lane_for_angle(int(active.get("launch_angle_degrees", 0)))
	active["selected_path"] = active["selected_lane"]
	active["launch_start"] = _point_payload(_launch_start_for_angle(mode, int(active.get("launch_angle_degrees", 0))))
	_refresh_launch_state(active, mode, false, {})


func _apply_direct_aim(active: Dictionary, mode: String, action_id: String) -> void:
	var index := _indexed_action_value(action_id, "slot_bonus_aim_", DIRECT_AIM_STEPS)
	var ratio := float(maxi(0, index)) / float(DIRECT_AIM_STEPS)
	active["launch_angle_degrees"] = int(round(lerpf(float(AIM_MIN), float(AIM_MAX), ratio)))
	_adjust_aim(active, mode, 0)


func _apply_direct_start(active: Dictionary, mode: String, action_id: String) -> void:
	var index := _indexed_action_value(action_id, "slot_bonus_start_", DIRECT_START_STEPS)
	var ratio := float(maxi(0, index)) / float(DIRECT_START_STEPS)
	var start := Vector2(lerpf(0.10, 0.90, ratio), 0.075)
	active["launch_start"] = _point_payload(start)
	active["launch_start_manual"] = true
	active["selected_lane"] = "left" if ratio < 0.34 else "right" if ratio > 0.66 else "center"
	active["selected_path"] = active["selected_lane"]
	_refresh_launch_state(active, mode, false, {})


func _apply_direct_power(active: Dictionary, action_id: String) -> void:
	var index := _indexed_action_value(action_id, "slot_bonus_power_", DIRECT_POWER_STEPS)
	var ratio := float(maxi(0, index)) / float(DIRECT_POWER_STEPS)
	active["launch_power"] = clampi(int(round(lerpf(20.0, 100.0, ratio))), 20, 100)


func _indexed_action_value(action_id: String, prefix: String, max_index: int) -> int:
	if not action_id.begins_with(prefix):
		return -1
	var suffix := action_id.substr(prefix.length()).strip_edges()
	if suffix.is_empty() or not suffix.is_valid_int():
		return -1
	return clampi(int(suffix), 0, maxi(0, max_index))


func _log_input(active: Dictionary, action_id: String) -> void:
	var input_log: Array = _array(active.get("input_log", []))
	input_log.append({"tick": int(_dict(active.get("pinball_debug", {})).get("tick", 0)), "action": action_id})
	active["input_log"] = _trimmed(input_log, 96)


func _ticks_for_step(active: Dictionary, sim, live_display: bool) -> int:
	if bool(active.get("headless", false)):
		return maxi(1, int(sim.max_ticks))
	if live_display:
		return 2
	return maxi(60, int(sim.max_ticks))


func _live_display(ui_state: Dictionary) -> bool:
	return ui_state.has("surface_time_msec") or ui_state.has("slot_visual_time_msec") or ui_state.has("drunk_scaled_surface_time_msec")


func _ball_budget_for_mode(mode: String, stake: int) -> int:
	if mode == "em_bumper_drop":
		return 3
	if mode == "lane_multiball":
		return 4
	return 4 if stake <= 10 else 5


func _minimum_award(active: Dictionary) -> int:
	var stake := maxi(1, int(active.get("stake", 1)))
	match str(active.get("mode", "")):
		"lane_multiball":
			return stake * 4
		"video_feature":
			return stake * 3
		_:
			return stake * 2


func _mode_for_machine(machine: Dictionary) -> String:
	match str(machine.get("format_id", "classic_3_reel")):
		"line_5x3":
			return "lane_multiball"
		"video_feature":
			return "video_feature"
		_:
			return "em_bumper_drop"


func _board_id_for_mode(_mode: String) -> String:
	return "bumper_alley"


func _default_launch_power(mode: String, rng: RngStream) -> int:
	if mode == "lane_multiball":
		return rng.randi_range(48, 64)
	if mode == "video_feature":
		return rng.randi_range(52, 70)
	return rng.randi_range(44, 60)


func _session_cap(stake: int, mode: String, feature_scale: float) -> int:
	var multiplier := 11.0
	if mode == "lane_multiball":
		multiplier = 14.5
	elif mode == "video_feature":
		multiplier = 10.5
	return maxi(1, int(round(float(stake) * multiplier * maxf(0.35, feature_scale))))


func _compile_modifiers(params: Dictionary) -> Dictionary:
	var item_effects: Dictionary = _dict(params.get("item_effects", {}))
	return {
		"rubber_pegs": item_effects.has("slot_pinball_rubber_pegs"),
	}


func _input_bonus(inputs: Array, stake: int, mode: String) -> int:
	var score := 0
	for input_value in inputs:
		var action := str(input_value)
		if action == "slot_bonus_left":
			score += 1
		elif action == "slot_bonus_right":
			score += 3
		elif action == "slot_bonus_launch":
			score += 2
	if mode == "video_feature":
		score *= 2
	return maxi(0, score * maxi(1, stake) / 2)


func _lane_for_angle(angle: int) -> String:
	if angle <= -8:
		return "left"
	if angle >= 8:
		return "right"
	return "center"


func _launch_start_for_angle(_mode: String, angle_degrees: int) -> Vector2:
	var ratio := clampf(float(angle_degrees - AIM_MIN) / float(AIM_MAX - AIM_MIN), 0.0, 1.0)
	return Vector2(lerpf(0.10, 0.90, ratio), 0.075)


static func _physics_from_point(point: Vector2, target: String) -> Dictionary:
	return {"ball_x": clampf(point.x, 0.0, 1.0), "ball_y": clampf(point.y, 0.0, 1.0), "velocity_x": 0.0, "velocity_y": 0.0, "energy": 1.0, "last_target": target}


static func _point_payload(point: Vector2) -> Dictionary:
	return {"x": snappedf(point.x, 0.0001), "y": snappedf(point.y, 0.0001)}


static func _trimmed(values: Array, keep: int) -> Array:
	while values.size() > keep:
		values.remove_at(0)
	return values


static func _array_static(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return value as Array


static func _dict_static(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value as Dictionary


func _array(value: Variant) -> Array:
	return _array_static(value).duplicate(true)


func _dict(value: Variant) -> Dictionary:
	return _dict_static(value).duplicate(true)


static func _vector2(value: Variant, fallback: Vector2) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value as Vector2
	if typeof(value) == TYPE_DICTIONARY:
		var dict := value as Dictionary
		return Vector2(float(dict.get("x", fallback.x)), float(dict.get("y", fallback.y)))
	return fallback


func _bonus_step_result(complete: bool, award: int, message: String, active: Dictionary) -> Dictionary:
	return {
		"complete": complete,
		"award": maxi(0, award),
		"message": message,
		"active_bonus": active,
	}
