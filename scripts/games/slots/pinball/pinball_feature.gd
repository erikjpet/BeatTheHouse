class_name PinballFeature
extends RefCounted

const BoardsScript := preload("res://scripts/games/slots/pinball/pinball_boards.gd")
const BoardScript := preload("res://scripts/games/slots/pinball/pinball_board.gd")
const SimScript := preload("res://scripts/games/slots/pinball/pinball_sim.gd")
const SequencerScript := preload("res://scripts/games/slots/pinball/pinball_sequencer.gd")
const ItemsScript := preload("res://scripts/games/slots/pinball/pinball_items.gd")

const AIM_MIN := -60
const AIM_MAX := 60
const AIM_STEP := 12
const DIRECT_AIM_STEPS := 24
const DIRECT_START_STEPS := 24
const DIRECT_POWER_STEPS := 20
const LAUNCH_METER_PERIOD_MSEC := 1100
const LAUNCH_METER_MIN_POWER := 20
const LAUNCH_METER_MAX_POWER := 100
const LAUNCH_METER_DEFAULT_SWEET_POWER := 82
const LAUNCH_METER_SWEET_WIDTH := 3
const LAUNCH_METER_GOOD_WIDTH := 8
const LAUNCH_METER_WILD_WIDTH := 22

static var _sessions: Dictionary = {}
static var _runtime_sessions: Dictionary = {}
static var _layouts: Dictionary = {}
static var _compiled_boards: Dictionary = {}
static var _surface_refresh_msec: Dictionary = {}
static var _sequencer_instance = null
static var _session_order: Array[String] = []
const MAX_RUNTIME_SESSIONS := 32
const EVENT_LOG_CAP := 192
const TRAJECTORY_CAP := 120
const DISPLAY_TRAJECTORY_CAP := 24
const HISTORY_CAP := 24
const HISTORY_EVENT_CAP := 6
const HISTORY_TRAJECTORY_CAP := 8
const MOMENTUM_HIT_BONUS := 1
const MOMENTUM_EVENT_TYPES := ["bumper", "slingshot", "launcher", "flipper"]


class RuntimeSession:
	extends RefCounted

	var sim
	var layout: Dictionary = {}
	var layout_view: Dictionary = {}
	var compiled: Dictionary = {}
	var last_surface_msec := 0
	var cached_view_tick := -1
	var cached_view: Dictionary = {}


func open(machine: Dictionary, mode: String, stake: int, rng: RngStream, params: Dictionary = {}) -> Dictionary:
	var session_seed := rng.randi_range(1, 2140000000)
	var session_id := "pinball:%s:%s:%d" % [str(machine.get("format_id", "")), mode, session_seed]
	var layout: Dictionary = BoardsScript.by_id(_board_id_for_mode(mode))
	layout["mode"] = mode
	var item_effects: Dictionary = _dict(params.get("item_effects", {}))
	var compiler := BoardScript.new()
	var compiled: Dictionary = compiler.compile(layout, ItemsScript.compile_modifiers(item_effects))
	var sim := SimScript.new()
	var cap := maxi(1, int(params.get("cap", stake * 12)))
	sim.configure(compiled, session_seed, {"cap": cap})
	_store_session(session_id, sim, layout, compiled)
	var total_balls := maxi(1, int(params.get("ball_budget", _ball_budget_for_mode(mode, stake))) + ItemsScript.ball_budget_bonus(item_effects))
	var skill_width := maxi(LAUNCH_METER_SWEET_WIDTH, int(round(float(compiled.get("skill_width", 0.03)) * 100.0)))
	skill_width = maxi(LAUNCH_METER_SWEET_WIDTH, int(round(float(skill_width * ItemsScript.skill_width_percent(item_effects)) / 100.0)))
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
		"feature_score": 0,
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
		"launch_meter_offset_msec": session_seed % LAUNCH_METER_PERIOD_MSEC,
		"skill_power_target": clampi(int(round(float(compiled.get("skill_power", 0.82)) * 100.0)), LAUNCH_METER_MIN_POWER, LAUNCH_METER_MAX_POWER),
		"skill_power_width": skill_width,
		"selected_lane": "center",
		"selected_path": "center",
		"launch_in_progress": false,
		"pinball_summary": {},
		"pinball_view": {},
		"pinball_item_effects": item_effects,
		"pinball_item_hooks": [],
		"input_log": [],
		"event_log": [],
		"trajectory": [],
		"history": [],
		"display_event_log": [],
		"display_trajectory": [],
		"last_event_count": 0,
		"combo_state": {"route_id": "", "step": 0, "multiplier": 1, "timer_ticks": 0, "label": ""},
		"sequencer_state": _sequencer().initial_state(str(layout.get("id", "")), mode),
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
		"launch_skill": {},
		"animation_duration_msec": 1600,
	}
	_refresh_launch_state(active, mode, false, {})
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
	var before_hooks := _array(active.get("pinball_item_hooks", [])).size()
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
		_refresh_launch_state(active, mode, false, ui_state)
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
			if mode == "video_feature" and int(_dict(sim.compact_snapshot()).get("balls_launched", 0)) == 1:
				sim.launch_ball({"power": 0.68, "aim": -0.28, "position": Vector2(0.42, 0.135)})
				sim.launch_ball({"power": 0.72, "aim": 0.28, "position": Vector2(0.58, 0.135)})
				active["video_auto_multiball_armed"] = true
				active["multiball_started"] = true
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
		if live_display:
			var live_msec := maxi(0, int(ui_state.get("surface_time_msec", ui_state.get("slot_visual_time_msec", 0))))
			_surface_refresh_msec[session_id] = live_msec
			var runtime: RuntimeSession = _runtime_for_static(active)
			if runtime != null:
				runtime.last_surface_msec = live_msec
				runtime.cached_view_tick = -1
	if not live_display and bool(active.get("headless", false)):
		var drain_deadline_tick := int(sim.tick) + int(sim.max_ticks)
		while sim.active_ball_count() > 0 and int(sim.tick) < drain_deadline_tick:
			_run_ticks_with_trajectory(sim, 6, local_trajectory, false)
	var base_events: Array = sim.event_log_since(before_events)
	active["sequence_events"] = []
	_apply_mode_progress(active, sim, mode, base_events)
	local_events = base_events + _sequence_events_to_log(_array(active.get("sequence_events", [])), base_events, sim)
	local_events.append_array(_hook_events_to_log(_array(active.get("pinball_item_hooks", [])).slice(before_hooks), base_events, sim))
	var step_award := maxi(0, int(sim.total_awarded) - before_total)
	var momentum_hit_count := _momentum_hit_count(base_events)
	var momentum_bonus := momentum_hit_count * MOMENTUM_HIT_BONUS
	_refresh_active(active, sim, local_events, local_trajectory)
	active["last_momentum_hit_count"] = momentum_hit_count
	active["last_momentum_bonus"] = momentum_bonus
	if int(active.get("balls_remaining", 0)) <= 0 and sim.active_ball_count() <= 0:
		complete = true
	if complete:
		var finish_result := _finish(machine, active, sim, message)
		_apply_momentum_step_bonus(finish_result, momentum_hit_count, momentum_bonus)
		return finish_result
	machine["active_bonus"] = active
	var step_result := _bonus_step_result(false, step_award, "%s in play." % message if sim.active_ball_count() > 0 else "%s %d balls left." % [message, int(active.get("balls_remaining", 0))], active)
	_apply_momentum_step_bonus(step_result, momentum_hit_count, momentum_bonus)
	return step_result


func preview(machine: Dictionary, stake: int, definition: Dictionary, rng: RngStream, inputs: Array) -> int:
	var active := open(machine, _mode_for_machine(machine), stake, rng, {
		"cap": _session_cap(stake, _mode_for_machine(machine), 1.0),
		"ball_budget": _ball_budget_for_mode(_mode_for_machine(machine), stake),
	})
	active["headless"] = true
	machine["active_bonus"] = active
	var guard := 0
	while bool(active.get("active", false)) and guard < 24:
		var action_id := "slot_bonus_launch"
		if guard < inputs.size():
			action_id = str(inputs[guard])
		var result: Dictionary = step(machine, action_id, rng, definition, {})
		active = _dict(result.get("active_bonus", machine.get("active_bonus", {})))
		machine["active_bonus"] = active
		guard += 1
	var forecast := maxi(
		int(active.get("feature_score", 0)),
		int(active.get("awarded", active.get("feature_total", 0)))
	)
	return forecast + _input_bonus(inputs, stake, str(active.get("mode", "")))


static func surface_refresh(active: Dictionary, surface_time_msec: int) -> Dictionary:
	var result := active.duplicate(false)
	var runtime: RuntimeSession = _runtime_for_static(result)
	var sim = runtime.sim if runtime != null else _session_for_static(result)
	if sim != null and bool(result.get("active", false)) and sim.active_ball_count() > 0:
		var session_id := str(result.get("runtime_session_id", ""))
		var stored_msec := maxi(0, int(_surface_refresh_msec.get(session_id, 0)))
		var last_msec := maxi(stored_msec, runtime.last_surface_msec if runtime != null else 0)
		var elapsed := 32 if last_msec <= 0 else clampi(surface_time_msec - last_msec, 0, 64)
		var ticks_to_run := 1 if elapsed >= 56 else 0
		if last_msec > 0:
			result["last_physics_real_msec"] = last_msec
			result["pinball_replay_query"] = surface_time_msec < last_msec
		for _i in range(ticks_to_run):
			sim.step_tick()
		if ticks_to_run > 0:
			if runtime != null:
				runtime.last_surface_msec = surface_time_msec
				runtime.cached_view_tick = -1
			_surface_refresh_msec[session_id] = surface_time_msec
			result["last_physics_real_msec"] = surface_time_msec
			result["pinball_replay_query"] = false
		result["physics_tick_budget"] = ticks_to_run
		result["active_ball_count"] = sim.active_ball_count()
		result["pinball_view"] = _cached_live_view(runtime, result, sim)
		result["event_log"] = _tail_array_shallow(result.get("event_log", []), 24)
		result["trajectory"] = _tail_array_shallow(result.get("trajectory", []), 32)
		result["display_event_log"] = _tail_array_shallow(result.get("display_event_log", []), 8)
		result["display_trajectory"] = _tail_array_shallow(result.get("display_trajectory", []), 12)
		result["history"] = []
	elif sim == null and bool(result.get("active", false)):
		var balls_remaining := maxi(0, int(result.get("balls_remaining", result.get("remaining_steps", 0))))
		result["active_ball_count"] = 0
		result["launch_in_progress"] = false
		result["remaining_steps"] = balls_remaining
	return result


static func live_status(active: Dictionary) -> Dictionary:
	var runtime: RuntimeSession = _runtime_for_static(active)
	var sim = runtime.sim if runtime != null else _session_for_static(active)
	var active_count := 0
	var runtime_tick := 0
	var balls_remaining := maxi(0, int(active.get("balls_remaining", active.get("remaining_steps", 0))))
	var remaining_steps := maxi(0, int(active.get("remaining_steps", balls_remaining)))
	if sim != null:
		active_count = sim.active_ball_count()
		remaining_steps = maxi(0, int(active.get("remaining_steps", balls_remaining + active_count)))
		runtime_tick = int(sim.tick)
	else:
		var summary: Dictionary = _dict_static(active.get("pinball_summary", {}))
		runtime_tick = maxi(0, int(summary.get("tick", _dict_static(active.get("pinball_debug", {})).get("tick", 0))))
		remaining_steps = balls_remaining
	return {
		"active_ball_count": active_count,
		"balls_remaining": balls_remaining,
		"remaining_steps": remaining_steps,
		"runtime_active": sim != null,
		"tick": runtime_tick,
	}


func _refresh_active(active: Dictionary, sim, local_events: Array, local_trajectory: Array) -> void:
	var snapshot: Dictionary = sim.compact_snapshot()
	var total_steps := maxi(1, int(active.get("total_steps", 1)))
	var launched := clampi(int(snapshot.get("balls_launched", 0)), 0, total_steps)
	var live_count := int(snapshot.get("active_ball_count", 0))
	var balls_remaining := maxi(0, total_steps - launched)
	active["feature_total"] = int(snapshot.get("total_awarded", 0))
	active["pending_award"] = int(snapshot.get("total_awarded", 0))
	active["feature_score"] = int(snapshot.get("gross_awarded", snapshot.get("total_awarded", 0)))
	active["balls_remaining"] = balls_remaining
	active["remaining_steps"] = balls_remaining + live_count
	active["active_ball_count"] = live_count
	active["launch_in_progress"] = live_count > 0
	active["step_index"] = maxi(0, int(snapshot.get("drain_count", 0)))
	active["max_active_count"] = maxi(int(active.get("max_active_count", 0)), int(snapshot.get("max_active_seen", 0)))
	active["last_event_count"] = int(snapshot.get("event_total_count", 0))
	active["pinball_summary"] = _summary_for(active, sim)
	active["pinball_debug"] = snapshot
	active["display_event_log"] = _tail_array_shallow(local_events, 16)
	active["display_trajectory"] = _sampled_array_shallow(local_trajectory, DISPLAY_TRAJECTORY_CAP)
	active["event_log"] = _bounded_event_log(_array_static(active.get("event_log", [])), local_events, EVENT_LOG_CAP, int(snapshot.get("total_awarded", 0)), str(active.get("mode", "")))
	active["trajectory"] = _sampled_array_shallow(_array_static(active.get("trajectory", [])) + local_trajectory, TRAJECTORY_CAP)
	_append_history(active, snapshot, local_events, local_trajectory)
	active["pinball_view"] = _view_for(active, sim, local_events, local_trajectory)
	if not local_trajectory.is_empty():
		var last_point: Dictionary = _dict(local_trajectory[local_trajectory.size() - 1])
		active["physics"] = _physics_from_point(_vector2(last_point.get("position", Vector2(0.5, 0.5)), Vector2(0.5, 0.5)), str(last_point.get("element_id", "")))
	active["animation_duration_msec"] = 1600 + mini(2600, int(active["trajectory"].size()) * 18)
	active["physics_frame_index"] = maxi(0, int(active.get("physics_frame_index", 0))) + 1


func _append_history(active: Dictionary, snapshot: Dictionary, local_events: Array, local_trajectory: Array) -> void:
	if local_events.is_empty() and local_trajectory.is_empty():
		return
	var history: Array = _array(active.get("history", []))
	history.append({
		"id": "pinball_step_%03d" % history.size(),
		"tick": int(snapshot.get("tick", 0)),
		"award": _logged_award(local_events),
		"event_log": _tail_array_shallow(local_events, HISTORY_EVENT_CAP),
		"trajectory": _tail_array_shallow(local_trajectory, HISTORY_TRAJECTORY_CAP),
		"event_count": local_events.size(),
		"trajectory_count": local_trajectory.size(),
		"active_balls": int(snapshot.get("active_ball_count", 0)),
		"total": int(snapshot.get("total_awarded", 0)),
	})
	active["history"] = _trimmed(history, HISTORY_CAP)


func _sequence_events_to_log(sequence_events: Array, source_events: Array, sim) -> Array:
	var result: Array = []
	for index in range(sequence_events.size()):
		var sequence: Dictionary = _dict(sequence_events[index])
		var award := maxi(0, int(sequence.get("award", 0)))
		if award <= 0:
			continue
		var sequence_id := str(sequence.get("sequence_id", "combo"))
		result.append(_manual_award_event(_sequence_event_type(sequence_id), sequence_id, award, source_events, sim, float(index + 1) * 0.0003))
	return result


func _hook_events_to_log(hook_events: Array, source_events: Array, sim) -> Array:
	var result: Array = []
	for index in range(hook_events.size()):
		var hook: Dictionary = _dict(hook_events[index])
		var award := maxi(0, int(hook.get("award", 0)))
		if award <= 0:
			continue
		var item_id := str(hook.get("item", "pinball_item"))
		result.append(_manual_award_event("item", item_id, award, source_events, sim, float(index + 1) * 0.0005))
	return result


func _manual_award_event(event_type: String, element_id: String, award: int, source_events: Array, sim, time_offset: float = 0.0001) -> Dictionary:
	return {
		"element_id": element_id,
		"element_type": event_type,
		"position": _last_event_position(source_events),
		"award": maxi(0, award),
		"time": snappedf(_last_event_time(source_events, sim) + time_offset, 0.0001),
		"ball_index": _last_event_ball(source_events),
	}


func _sequence_event_type(sequence_id: String) -> String:
	match sequence_id:
		"locks_multiball", "video_multiball", "alley_loop":
			return "launcher"
		"cascade":
			return "spawner"
		"portal_combo":
			return "gate"
		"qualify_super":
			return "target"
		"super_jackpot":
			return "super_jackpot"
		"jackpot", "jackpot_works":
			return "jackpot"
		"bumper_streak":
			return "bumper"
		_:
			return "combo"


func _last_event_position(source_events: Array) -> Dictionary:
	for index in range(source_events.size() - 1, -1, -1):
		var event: Dictionary = _dict(source_events[index])
		var position: Variant = event.get("position", {})
		if typeof(position) == TYPE_DICTIONARY:
			return (position as Dictionary).duplicate(true)
	return _point_payload(Vector2(0.5, 0.5))


func _last_event_time(source_events: Array, sim) -> float:
	for index in range(source_events.size() - 1, -1, -1):
		var event: Dictionary = _dict(source_events[index])
		if event.has("time"):
			return float(event.get("time", 0.0))
	return float(sim.tick) * SimScript.FIXED_DT


func _last_event_ball(source_events: Array) -> int:
	for index in range(source_events.size() - 1, -1, -1):
		var event: Dictionary = _dict(source_events[index])
		if event.has("ball_index"):
			return int(event.get("ball_index", 0))
	return 0


func _logged_award(events: Array) -> int:
	var total := 0
	for event_value in events:
		total += maxi(0, int(_dict(event_value).get("award", 0)))
	return total


func _momentum_hit_count(events: Array) -> int:
	var count := 0
	for event_value in events:
		var event: Dictionary = _dict(event_value)
		if MOMENTUM_EVENT_TYPES.has(str(event.get("element_type", ""))):
			count += 1
	return count


func _apply_momentum_step_bonus(step_result: Dictionary, hit_count: int, bonus: int) -> void:
	var safe_hits := maxi(0, hit_count)
	var safe_bonus := maxi(0, bonus)
	var active: Dictionary = _dict(step_result.get("active_bonus", {}))
	var session_cap := maxi(0, int(active.get("session_cap", 0)))
	if session_cap > 0:
		var feature_total := maxi(maxi(0, int(active.get("feature_total", 0))), maxi(0, int(active.get("awarded", 0))))
		safe_bonus = mini(safe_bonus, maxi(0, session_cap - feature_total))
	if safe_hits <= 0 or safe_bonus <= 0:
		return
	step_result["pinball_momentum_hit_count"] = safe_hits
	step_result["pinball_momentum_bonus"] = safe_bonus
	active["last_momentum_hit_count"] = safe_hits
	active["last_momentum_bonus"] = safe_bonus
	step_result["active_bonus"] = active
	var message := str(step_result.get("message", "")).strip_edges()
	var bonus_text := "Momentum bonus +$%d." % safe_bonus
	step_result["message"] = "%s %s" % [message, bonus_text] if not message.is_empty() else bonus_text


func _finish(machine: Dictionary, active: Dictionary, sim, message: String) -> Dictionary:
	var finish_events: Array = []
	var finish_source_events: Array = _array(active.get("display_event_log", []))
	var before_hooks := _array(active.get("pinball_item_hooks", [])).size()
	ItemsScript.apply_drain_cleaner(active, sim)
	finish_events.append_array(_hook_events_to_log(_array(active.get("pinball_item_hooks", [])).slice(before_hooks), finish_source_events, sim))
	var minimum := _minimum_award(active)
	if int(sim.total_awarded) < minimum:
		var floor_paid := minimum - int(sim.total_awarded)
		sim.total_awarded = minimum
		active["feature_total"] = minimum
		active["pending_award"] = minimum
		finish_events.append(_manual_award_event("floor", "pinball_floor", floor_paid, finish_source_events, sim))
	var award_cap := int(active.get("session_cap", sim.session_cap))
	if bool(active.get("reference_policy", false)):
		award_cap = mini(award_cap, _reference_policy_cap(active))
	var award := mini(award_cap, maxi(minimum, int(sim.total_awarded)))
	active["active"] = false
	active["complete"] = true
	active["awarded"] = award
	active["feature_total"] = award
	active["pending_award"] = award
	active["feature_score"] = maxi(int(active.get("feature_score", 0)), int(sim.gross_awarded))
	active["active_ball_count"] = 0
	active["remaining_steps"] = 0
	active["balls_remaining"] = 0
	active["launch_in_progress"] = false
	if not finish_events.is_empty():
		active["display_event_log"] = finish_events
		var event_log: Array = _array_static(active.get("event_log", []))
		event_log.append_array(finish_events)
		active["event_log"] = _final_event_log(event_log, EVENT_LOG_CAP, award, str(active.get("mode", "")))
	else:
		active["event_log"] = _final_event_log(_array_static(active.get("event_log", [])), EVENT_LOG_CAP, award, str(active.get("mode", "")))
	active["pinball_view"] = _view_for(active, sim, [], [])
	_erase_session(str(active.get("runtime_session_id", "")))
	machine["last_bonus_replay"] = active.duplicate(true)
	machine["active_bonus"] = {"active": false, "complete": true}
	return _bonus_step_result(true, award, "%s Total $%d." % [message, award], active)


func _session_for(active: Dictionary):
	var session_id := str(active.get("runtime_session_id", ""))
	if _sessions.has(session_id):
		return _sessions[session_id]
	var compiler := BoardScript.new()
	var layout: Dictionary = BoardsScript.by_id(_board_id_for_mode(str(active.get("mode", ""))))
	var compiled: Dictionary = compiler.compile(layout, ItemsScript.compile_modifiers(_dict(active.get("pinball_item_effects", {}))))
	var sim := SimScript.new()
	sim.configure(compiled, int(active.get("runtime_seed", 1)), {"cap": int(active.get("session_cap", 500))})
	_restore_session_progress(active, sim)
	_store_session(session_id, sim, layout, compiled)
	return sim


static func _session_for_static(active: Dictionary):
	var session_id := str(active.get("runtime_session_id", ""))
	return _sessions.get(session_id, null)


static func _runtime_for_static(active: Dictionary) -> RuntimeSession:
	var session_id := str(active.get("runtime_session_id", ""))
	var runtime: Variant = _runtime_sessions.get(session_id, null)
	return runtime as RuntimeSession if runtime is RuntimeSession else null


static func _store_session(session_id: String, sim, layout: Dictionary, compiled: Dictionary) -> void:
	if session_id.is_empty():
		return
	var layout_view := _layout_view(layout)
	var runtime := RuntimeSession.new()
	runtime.sim = sim
	runtime.layout = layout
	runtime.layout_view = layout_view
	runtime.compiled = compiled
	_sessions[session_id] = sim
	_runtime_sessions[session_id] = runtime
	_layouts[session_id] = layout_view
	_compiled_boards[session_id] = compiled
	_surface_refresh_msec[session_id] = 0
	_session_order.erase(session_id)
	_session_order.append(session_id)
	_prune_session_cache()


static func _erase_session(session_id: String) -> void:
	if session_id.is_empty():
		return
	_sessions.erase(session_id)
	_runtime_sessions.erase(session_id)
	_layouts.erase(session_id)
	_compiled_boards.erase(session_id)
	_surface_refresh_msec.erase(session_id)
	_session_order.erase(session_id)


static func clear_runtime_session_cache() -> void:
	_sessions.clear()
	_runtime_sessions.clear()
	_layouts.clear()
	_compiled_boards.clear()
	_surface_refresh_msec.clear()
	_session_order.clear()


static func runtime_session_cache_size() -> int:
	return _session_order.size()


static func runtime_session_debug_snapshot() -> Dictionary:
	var cached_view_count := 0
	var cached_view_bytes := 0
	var sim_count := 0
	for session_id_value in _session_order:
		var session_id := str(session_id_value)
		if _sessions.has(session_id):
			sim_count += 1
		var runtime_value: Variant = _runtime_sessions.get(session_id, null)
		if not (runtime_value is RuntimeSession):
			continue
		var runtime := runtime_value as RuntimeSession
		if runtime.cached_view.is_empty():
			continue
		cached_view_count += 1
		cached_view_bytes += JSON.stringify(runtime.cached_view).length()
	return {
		"session_order_size": _session_order.size(),
		"sessions_size": _sessions.size(),
		"runtime_sessions_size": _runtime_sessions.size(),
		"layouts_size": _layouts.size(),
		"compiled_boards_size": _compiled_boards.size(),
		"surface_refresh_size": _surface_refresh_msec.size(),
		"sim_count": sim_count,
		"cached_view_count": cached_view_count,
		"cached_view_bytes": cached_view_bytes,
	}


static func _prune_session_cache() -> void:
	while _session_order.size() > MAX_RUNTIME_SESSIONS:
		_erase_session(str(_session_order[0]))


static func _restore_session_progress(active: Dictionary, sim) -> void:
	var cap := maxi(1, int(active.get("session_cap", sim.session_cap)))
	var restored_total := maxi(maxi(maxi(0, int(active.get("feature_total", 0))), int(active.get("pending_award", 0))), int(active.get("awarded", 0)))
	sim.total_awarded = mini(cap, restored_total)
	sim.gross_awarded = maxi(sim.total_awarded, int(active.get("feature_score", restored_total)))
	var total_steps := maxi(0, int(active.get("total_steps", active.get("balls_remaining", 0))))
	var balls_remaining := clampi(int(active.get("balls_remaining", total_steps)), 0, total_steps)
	var debug: Dictionary = _dict_static(active.get("pinball_debug", {}))
	var launched := clampi(total_steps - balls_remaining, 0, total_steps)
	launched = maxi(launched, int(active.get("step_index", 0)))
	launched = maxi(launched, int(debug.get("balls_launched", 0)))
	sim.balls_launched = clampi(launched, 0, maxi(total_steps, launched))
	sim.drain_count = clampi(maxi(int(active.get("step_index", 0)), int(debug.get("drain_count", 0))), 0, maxi(sim.balls_launched, 0))
	sim.max_active_seen = maxi(int(active.get("max_active_count", 0)), int(debug.get("max_active_seen", 0)))


func _run_ticks_with_trajectory(sim, ticks_to_run: int, trajectory: Array, _local_time: bool) -> void:
	for index in range(maxi(0, ticks_to_run)):
		sim.step_tick()
		if index % 3 == 0 or sim.active_ball_count() == 0:
			trajectory.append_array(sim.active_position_log())


func _apply_mode_progress(active: Dictionary, sim, mode: String, events: Array) -> void:
	if events.is_empty():
		return
	var sequencer: Object = _sequencer()
	sequencer.apply(active, sim, mode, events)
	ItemsScript.apply_event_hooks(active, sim, mode, events)


func _view_for(active: Dictionary, sim, local_events: Array, local_trajectory: Array) -> Dictionary:
	return _view_for_static(active, sim, local_events, local_trajectory)


static func _cached_live_view(runtime: RuntimeSession, active: Dictionary, sim) -> Dictionary:
	if runtime != null and runtime.cached_view_tick == int(sim.tick) and not runtime.cached_view.is_empty():
		return runtime.cached_view
	var balls: Array = sim.active_position_log()
	var view: Dictionary = _view_for_static(active, sim, [], balls, balls, runtime.layout_view if runtime != null else {})
	if runtime != null:
		runtime.cached_view_tick = int(sim.tick)
		runtime.cached_view = view
	return view


static func _view_for_static(active: Dictionary, sim, local_events: Array, local_trajectory: Array, balls_override: Array = [], layout_override: Dictionary = {}) -> Dictionary:
	var session_id := str(active.get("runtime_session_id", ""))
	var balls: Array = balls_override
	if balls.is_empty() and sim.active_ball_count() > 0:
		balls = sim.active_position_log()
	var layout: Dictionary = layout_override
	if layout.is_empty():
		layout = _layouts.get(session_id, {})
	return {
		"layout": layout,
		"balls": balls,
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
			"state": _dict(active.get("sequencer_state", {})),
		},
		"item_hooks": _array(active.get("pinball_item_hooks", [])),
		"input_log": _array(active.get("input_log", [])),
	}


static func _sequencer():
	if _sequencer_instance == null:
		_sequencer_instance = SequencerScript.new()
	return _sequencer_instance


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
		elements.append({"id": str(sensor.get("id", "")), "type": sensor_type, "shape": "sensor_circle", "position": sensor.get("position", Vector2.ZERO), "radius": sensor.get("radius", 0.04), "award": sensor.get("award", 0), "label": str(sensor.get("label", sensor_type.left(4).to_upper())), "light": str(sensor.get("id", "")), "route": sensor.get("kick", Vector2(0.0, -1.0))})
	for rect_value in _array_static(layout.get("rects", [])):
		var rect_element: Dictionary = _dict_static(rect_value)
		var rect_type := str(rect_element.get("type", "pocket"))
		elements.append({"id": str(rect_element.get("id", "")), "type": rect_type, "shape": "drain_rect" if rect_type == "drain" else "slot_rect", "rect": rect_element.get("rect", Rect2()), "award": rect_element.get("award", 0), "label": str(rect_element.get("label", rect_element.get("award", "")))})
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


static func launch_meter_snapshot(active: Dictionary, time_msec: int, sampled: bool = false) -> Dictionary:
	return _launch_skill_snapshot(active, str(active.get("mode", "em_bumper_drop")), time_msec, int(active.get("launch_power", 70)), sampled)


static func _launch_skill_snapshot(active: Dictionary, mode: String, time_msec: int, power: int, sampled: bool) -> Dictionary:
	var target_power := clampi(power, LAUNCH_METER_MIN_POWER, LAUNCH_METER_MAX_POWER)
	var sampled_power := _launch_meter_power(active, time_msec, target_power)
	var sweet := clampi(int(active.get("skill_power_target", LAUNCH_METER_DEFAULT_SWEET_POWER)), LAUNCH_METER_MIN_POWER, LAUNCH_METER_MAX_POWER)
	var sweet_width := maxi(LAUNCH_METER_SWEET_WIDTH, int(active.get("skill_power_width", LAUNCH_METER_SWEET_WIDTH)))
	var error := absi(sampled_power - sweet)
	var rating := "clean"
	if error <= sweet_width:
		rating = "sweet"
	elif error <= LAUNCH_METER_GOOD_WIDTH:
		rating = "good"
	elif error >= LAUNCH_METER_WILD_WIDTH:
		rating = "wild"
	return {
		"sampled": sampled,
		"time_msec": maxi(0, time_msec),
		"target_power": target_power,
		"power": sampled_power,
		"meter": snappedf(_power_to_meter(sampled_power), 0.001),
		"sweet_spot": sweet,
		"sweet_meter": snappedf(_power_to_meter(sweet), 0.001),
		"error": error,
		"rating": rating,
		"angle_degrees": int(active.get("launch_angle_degrees", 0)),
		"launch_start": _point_payload(_vector2(active.get("launch_start", _launch_start_for_angle(mode, int(active.get("launch_angle_degrees", 0)))), _launch_start_for_angle(mode, int(active.get("launch_angle_degrees", 0))))),
		"controlled": true,
		"timed": true,
	}


func _launch_params(active: Dictionary, mode: String) -> Dictionary:
	var skill: Dictionary = _dict(active.get("last_launch_skill", active.get("launch_skill", {})))
	var sampled_power := int(skill.get("power", active.get("launch_power", 70)))
	var aim := clampf(float(int(active.get("launch_angle_degrees", 0))) / 60.0, -1.0, 1.0)
	if str(skill.get("rating", "")) == "wild":
		var sweet := int(skill.get("sweet_spot", LAUNCH_METER_DEFAULT_SWEET_POWER))
		aim = clampf(aim + clampf(float(sampled_power - sweet) / 120.0, -0.22, 0.22), -1.0, 1.0)
	elif str(skill.get("rating", "")) == "sweet":
		aim = clampf(aim * 0.78, -1.0, 1.0)
	return {
		"power": clampf(float(sampled_power) / 100.0, 0.0, 1.0),
		"aim": aim,
		"position": _vector2(active.get("launch_start", _launch_start_for_angle(mode, 0)), _launch_start_for_angle(mode, 0)),
	}


func _adjust_aim(active: Dictionary, mode: String, delta: int) -> void:
	active["launch_angle_degrees"] = clampi(int(active.get("launch_angle_degrees", 0)) + delta, AIM_MIN, AIM_MAX)
	active["selected_lane"] = _lane_for_angle(int(active.get("launch_angle_degrees", 0)))
	active["selected_path"] = active["selected_lane"]
	if not bool(active.get("launch_start_manual", false)):
		active["launch_start"] = _point_payload(_launch_start_for_angle(mode, int(active.get("launch_angle_degrees", 0))))
	active["physics"] = _physics_from_point(_vector2(active.get("launch_start", _launch_start_for_angle(mode, int(active.get("launch_angle_degrees", 0)))), _launch_start_for_angle(mode, int(active.get("launch_angle_degrees", 0)))), "plunger")
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
	active["physics"] = _physics_from_point(start, "plunger")
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
	return clampi(int(round(float(sim.max_ticks) * 0.16)), 72, 132)


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


func _reference_policy_cap(active: Dictionary) -> int:
	var stake := maxi(1, int(active.get("stake", 1)))
	var feature_scale := maxf(0.35, float(active.get("feature_scale", 1.0)))
	if str(active.get("mode", "")) == "video_feature":
		return maxi(1, int(round(float(stake) * 10.0 * feature_scale)))
	return maxi(1, int(active.get("session_cap", stake)))


func _mode_for_machine(machine: Dictionary) -> String:
	match str(machine.get("format_id", "classic_3_reel")):
		"line_5x3":
			return "lane_multiball"
		"video_feature":
			return "video_feature"
		_:
			return "em_bumper_drop"


func _board_id_for_mode(mode: String) -> String:
	if mode == "lane_multiball":
		return "lock_cascade"
	if mode == "video_feature":
		return "jackpot_works"
	return "bumper_alley"


func _default_launch_power(mode: String, rng: RngStream) -> int:
	if mode == "lane_multiball":
		return rng.randi_range(48, 64)
	if mode == "video_feature":
		return rng.randi_range(52, 70)
	return rng.randi_range(44, 60)


func _session_cap(stake: int, mode: String, feature_scale: float) -> int:
	var multiplier := 11.5
	if mode == "lane_multiball":
		multiplier = 14.2
	elif mode == "video_feature":
		multiplier = 30.0
	return maxi(1, int(round(float(stake) * multiplier * maxf(0.35, feature_scale))))


func _compile_modifiers(params: Dictionary) -> Dictionary:
	var item_effects: Dictionary = _dict(params.get("item_effects", {}))
	return ItemsScript.compile_modifiers(item_effects)


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
		score *= 20
	return maxi(0, score * maxi(1, stake) / 2)


static func _launch_meter_power(active: Dictionary, time_msec: int, target_power: int) -> int:
	var resolved_time := maxi(0, time_msec)
	if resolved_time <= 0:
		resolved_time = 173 + int(active.get("step_index", 0)) * 137 + int(active.get("balls_remaining", 0)) * 83
	var offset := int(active.get("launch_meter_offset_msec", 0))
	var cycle := fposmod(float(resolved_time + offset), float(LAUNCH_METER_PERIOD_MSEC)) / float(LAUNCH_METER_PERIOD_MSEC)
	var triangle := 1.0 - absf(cycle * 2.0 - 1.0)
	var eased := 0.5 - cos(triangle * PI) * 0.5
	var bias := clampf((float(target_power) - 60.0) / 160.0, -0.12, 0.12)
	var value := clampf(eased + bias, 0.0, 1.0)
	return clampi(int(round(lerpf(float(LAUNCH_METER_MIN_POWER), float(LAUNCH_METER_MAX_POWER), value))), LAUNCH_METER_MIN_POWER, LAUNCH_METER_MAX_POWER)


static func _power_to_meter(power: int) -> float:
	return clampf(float(power - LAUNCH_METER_MIN_POWER) / float(LAUNCH_METER_MAX_POWER - LAUNCH_METER_MIN_POWER), 0.0, 1.0)


func _lane_for_angle(angle: int) -> String:
	if angle <= -8:
		return "left"
	if angle >= 8:
		return "right"
	return "center"


static func _launch_start_for_angle(_mode: String, angle_degrees: int) -> Vector2:
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


static func _sampled_array_shallow(values: Array, keep: int) -> Array:
	var safe_keep := maxi(0, keep)
	if safe_keep <= 0:
		return []
	if values.size() <= safe_keep:
		return values
	if safe_keep == 1:
		return [values[values.size() - 1]]
	var result: Array = []
	var last_index := values.size() - 1
	for sample_index in range(safe_keep):
		var source_index := int(round(float(sample_index) * float(last_index) / float(safe_keep - 1)))
		result.append(values[clampi(source_index, 0, last_index)])
	return result


static func _bounded_event_log(existing_events: Array, local_events: Array, keep: int, target_award: int, mode: String) -> Array:
	var combined: Array = []
	combined.append_array(existing_events)
	combined.append_array(local_events)
	var safe_keep := maxi(1, keep)
	var result: Array = _sampled_array_shallow(combined, safe_keep)
	var missing_award := maxi(0, target_award - _logged_award_static(result))
	if missing_award > 0:
		while result.size() >= safe_keep:
			result.remove_at(0)
		result.insert(0, _summary_award_event(mode, missing_award, combined))
	return result


static func _final_event_log(events: Array, keep: int, target_award: int, mode: String) -> Array:
	var safe_keep := maxi(1, keep)
	var sampled: Array = _sampled_array_shallow(events, safe_keep)
	var result: Array = []
	var running_award := 0
	var content_slots := maxi(0, safe_keep - 1)
	for event_value in sampled:
		if result.size() >= content_slots:
			break
		var event: Dictionary = _dict_static(event_value)
		if event.is_empty():
			continue
		var event_award := maxi(0, int(event.get("award", 0)))
		if event_award > 0 and running_award + event_award > target_award:
			continue
		result.append(event)
		running_award += event_award
	var missing_award := maxi(0, target_award - running_award)
	if missing_award > 0:
		result.insert(0, _summary_award_event(mode, missing_award, events))
	while result.size() > safe_keep:
		result.remove_at(1 if result.size() > 1 else 0)
	return result


static func _summary_award_event(mode: String, award: int, source_events: Array) -> Dictionary:
	var event_type := "bumper"
	if mode == "lane_multiball":
		event_type = "launcher"
	elif mode == "video_feature":
		event_type = "jackpot"
	var position := _point_payload(Vector2(0.5, 0.5))
	var event_time := 0.0
	var ball_index := 0
	for index in range(source_events.size() - 1, -1, -1):
		var source: Dictionary = _dict_static(source_events[index])
		if source.is_empty():
			continue
		var source_type := str(source.get("element_type", ""))
		if source_type == "gate" or source_type == "launcher" or source_type == "jackpot" or source_type == "bumper":
			event_type = source_type
		var source_position: Variant = source.get("position", {})
		if typeof(source_position) == TYPE_DICTIONARY:
			position = (source_position as Dictionary).duplicate(true)
		event_time = float(source.get("time", event_time))
		ball_index = int(source.get("ball_index", ball_index))
		break
	return {
		"element_id": "bounded_award_summary",
		"element_type": event_type,
		"position": position,
		"award": maxi(0, award),
		"time": snappedf(event_time, 0.0001),
		"ball_index": ball_index,
		"summary": true,
	}


static func _logged_award_static(events: Array) -> int:
	var total := 0
	for event_value in events:
		total += maxi(0, int(_dict_static(event_value).get("award", 0)))
	return total


static func _tail_array_shallow(value: Variant, keep: int) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var source := value as Array
	var start_index := maxi(0, source.size() - maxi(0, keep))
	var result: Array = []
	for index in range(start_index, source.size()):
		result.append(source[index])
	return result


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
