class_name SlotPinballTable
extends RefCounted

# Standalone deterministic 2D pinball simulation for slot bonus prototyping.

const FIXED_DT := 1.0 / 120.0
const MAX_TICKS := 3600
const TRAJECTORY_LIMIT := 720
const EPSILON := 0.000001


func new_table(layout_id: String) -> Dictionary:
	match layout_id:
		"lane_multiball":
			return _lane_multiball_layout()
		"video_feature", "full_table":
			return _video_feature_layout()
		_:
			return _em_bumper_drop_layout()


func begin_session(layout: Dictionary, rng: RngStream, params: Dictionary = {}) -> Dictionary:
	var cap: int = maxi(0, int(params.get("cap", layout.get("cap", 500))))
	var ball_budget: int = maxi(1, int(params.get("ball_budget", layout.get("ball_budget", 1))))
	return {
		"layout_id": str(layout.get("id", "")),
		"layout": layout.duplicate(true),
		"balls": [],
		"input": _normalized_input({}),
		"ball_budget": ball_budget,
		"balls_launched": 0,
		"locks": 0,
		"lit": {},
		"total": 0,
		"cap": cap,
		"event_log": [],
		"trajectory": [],
		"record_trajectory": true,
		"trajectory_stride": 4,
		"tick": 0,
		"time": 0.0,
		"tilt": false,
		"tilt_meter": 0.0,
		"session_variance": float(rng.randi_range(-3, 3)) * 0.001,
		"last_step_events": [],
	}


func set_input(session: Dictionary, input: Dictionary) -> void:
	session["input"] = _normalized_input(input)


func launch_ball(session: Dictionary, rng: RngStream, launch_params: Dictionary = {}) -> Dictionary:
	var layout: Dictionary = _copy_dict(session.get("layout", {}))
	var launched: int = maxi(0, int(session.get("balls_launched", 0)))
	var budget: int = maxi(1, int(session.get("ball_budget", 1)))
	if launched >= budget and not bool(launch_params.get("force", false)):
		return {}
	var start: Vector2 = _vector2_from_value(layout.get("plunger_start", Vector2(0.5, 0.88)), Vector2(0.5, 0.88))
	var lane: String = str(launch_params.get("lane", "center"))
	var lane_starts: Dictionary = _copy_dict(layout.get("lane_starts", {}))
	if lane_starts.has(lane):
		start = _vector2_from_value(lane_starts.get(lane, start), start)
	else:
		start.x = clampf(start.x + _lane_offset(layout, lane), 0.08, 0.92)
	var direction: Vector2 = _vector2_from_value(layout.get("plunger_direction", Vector2(0.0, -1.0)), Vector2(0.0, -1.0))
	var lane_directions: Dictionary = _copy_dict(layout.get("lane_directions", {}))
	if lane_directions.has(lane):
		direction = _vector2_from_value(lane_directions.get(lane, direction), direction)
	if direction.length_squared() <= EPSILON:
		direction = Vector2(0.0, -1.0)
	direction = direction.normalized()
	direction = direction.rotated(clampf(float(launch_params.get("aim_offset", 0.0)), -0.34, 0.34)).normalized()
	var input: Dictionary = _copy_dict(session.get("input", {}))
	var default_power: float = float(input.get("plunger_charge", 0.72))
	var power: float = _normalized_power(launch_params.get("power", default_power))
	var min_speed: float = maxf(0.1, float(layout.get("launch_speed_min", 1.08)))
	var max_speed: float = maxf(min_speed, float(layout.get("launch_speed_max", 1.62)))
	var spread_scale: float = clampf(float(launch_params.get("spread_scale", 0.55)), 0.0, 1.0)
	var spread: float = float(rng.randi_range(-24, 24)) / 1000.0 * spread_scale
	var velocity: Vector2 = direction.rotated(spread) * lerpf(min_speed, max_speed, power)
	var radius: float = maxf(0.005, float(launch_params.get("radius", layout.get("ball_radius", 0.018))))
	var balls: Array = _copy_array(session.get("balls", []))
	var ball: Dictionary = {
		"position": start,
		"velocity": velocity,
		"radius": radius,
		"alive": true,
		"age_ticks": 0,
		"cooldowns": {},
		"lane": lane,
	}
	balls.append(ball)
	session["balls"] = balls
	if not bool(launch_params.get("force", false)):
		session["balls_launched"] = launched + 1
	return ball.duplicate(true)


func step(session: Dictionary, rng: RngStream) -> Dictionary:
	var event_log: Array = session.get("event_log", []) if typeof(session.get("event_log", [])) == TYPE_ARRAY else []
	var start_event_count: int = event_log.size()
	var layout: Dictionary = session.get("layout", {}) if typeof(session.get("layout", {})) == TYPE_DICTIONARY else {}
	var balls: Array = session.get("balls", []) if typeof(session.get("balls", [])) == TYPE_ARRAY else []
	var gravity: Vector2 = _vector2_from_value(layout.get("gravity", Vector2(0.0, 1.25)), Vector2(0.0, 1.25))
	var damping: float = clampf(float(layout.get("linear_damping", 0.997)), 0.85, 1.0)
	var drained_count := 0
	session["tick"] = maxi(0, int(session.get("tick", 0))) + 1
	session["time"] = float(session.get("time", 0.0)) + FIXED_DT
	_apply_nudge(session, balls)
	for ball_index in range(balls.size()):
		var ball: Dictionary = balls[ball_index] if typeof(balls[ball_index]) == TYPE_DICTIONARY else {}
		if not bool(ball.get("alive", false)):
			balls[ball_index] = ball
			continue
		_decrement_cooldowns(ball)
		var velocity: Vector2 = _vector2_from_value(ball.get("velocity", Vector2.ZERO), Vector2.ZERO)
		var position: Vector2 = _vector2_from_value(ball.get("position", Vector2.ZERO), Vector2.ZERO)
		velocity += gravity * FIXED_DT
		velocity *= damping
		position += velocity * FIXED_DT
		ball["velocity"] = velocity
		ball["position"] = position
		_resolve_static_collisions(session, ball, ball_index, layout, rng)
		_apply_sensor_elements(session, ball, ball_index, layout, rng)
		if bool(ball.get("alive", false)):
			_apply_bounds(session, ball, ball_index, layout)
		if bool(ball.get("alive", false)):
			ball["velocity"] = _clamped_velocity(_vector2_from_value(ball.get("velocity", Vector2.ZERO), Vector2.ZERO), layout)
		ball["age_ticks"] = maxi(0, int(ball.get("age_ticks", 0))) + 1
		var max_age_ticks := maxi(1, int(layout.get("max_ticks", MAX_TICKS)))
		if bool(ball.get("alive", false)) and int(ball.get("age_ticks", 0)) >= max_age_ticks:
			ball["alive"] = false
		if not bool(ball.get("alive", false)):
			drained_count += 1
		balls[ball_index] = ball
	session["balls"] = balls
	if bool(session.get("record_trajectory", true)):
		var stride := maxi(1, int(session.get("trajectory_stride", 1)))
		if int(session.get("tick", 0)) % stride == 0:
			_record_trajectory(session)
	var new_events: Array = []
	for event_index in range(start_event_count, event_log.size()):
		new_events.append(_copy_dict(event_log[event_index]))
	session["last_step_events"] = new_events.duplicate(true)
	return {
		"time": float(session.get("time", 0.0)),
		"tick": int(session.get("tick", 0)),
		"active_count": active_ball_count(session),
		"events": new_events,
		"award": session_award(session),
		"tilt": bool(session.get("tilt", false)),
		"drained_count": drained_count,
	}


func run_ball_to_drain(session: Dictionary, rng: RngStream, input_policy: Variant = {}) -> Dictionary:
	var max_ticks: int = maxi(1, int(_copy_dict(session.get("layout", {})).get("max_ticks", MAX_TICKS)))
	var policy: Dictionary = _copy_dict(input_policy)
	if not policy.is_empty():
		max_ticks = maxi(1, int(policy.get("max_ticks", max_ticks)))
	return run_ticks(session, rng, policy, max_ticks, true)


func run_ticks(session: Dictionary, rng: RngStream, input_policy: Variant = {}, tick_budget: int = 48, drain_on_timeout: bool = false) -> Dictionary:
	var max_ticks: int = maxi(1, mini(maxi(1, tick_budget), int(_copy_dict(session.get("layout", {})).get("max_ticks", MAX_TICKS))))
	var policy: Dictionary = _copy_dict(input_policy)
	if not policy.is_empty():
		max_ticks = maxi(1, mini(max_ticks, int(policy.get("max_ticks", max_ticks))))
	var previous_record_trajectory := bool(session.get("record_trajectory", true))
	var previous_trajectory_stride := maxi(1, int(session.get("trajectory_stride", 1)))
	if policy.has("record_trajectory"):
		session["record_trajectory"] = bool(policy.get("record_trajectory", true))
	if policy.has("trajectory_stride"):
		session["trajectory_stride"] = maxi(1, int(policy.get("trajectory_stride", previous_trajectory_stride)))
	var guard := 0
	var active_count := active_ball_count(session)
	while active_count > 0 and guard < max_ticks:
		var policy_input: Dictionary = _policy_input(session, policy)
		if guard == 0:
			policy_input = _merged_input(policy_input, _copy_dict(policy.get("initial_input", {})))
		set_input(session, policy_input)
		var step_info: Dictionary = step(session, rng)
		guard += 1
		if _cap_reached(session):
			_timeout_drain(session)
		active_count = active_ball_count(session) if _cap_reached(session) else int(step_info.get("active_count", active_ball_count(session)))
	if drain_on_timeout and active_ball_count(session) > 0 and guard >= max_ticks:
		_timeout_drain(session)
	session["record_trajectory"] = previous_record_trajectory
	session["trajectory_stride"] = previous_trajectory_stride
	return {
		"trajectory": _copy_array(session.get("trajectory", [])),
		"events": _copy_array(session.get("event_log", [])),
		"award": session_award(session),
		"ticks": guard,
		"drained": active_ball_count(session) == 0,
		"tilt": bool(session.get("tilt", false)),
	}


func _cap_reached(session: Dictionary) -> bool:
	var cap: int = maxi(0, int(session.get("cap", 0)))
	return cap > 0 and maxi(0, int(session.get("total", 0))) >= cap


func session_award(session: Dictionary) -> int:
	var cap: int = maxi(0, int(session.get("cap", 0)))
	var total := maxi(0, int(session.get("total", 0)))
	return mini(cap, total)


func active_ball_count(session: Dictionary) -> int:
	var total := 0
	var balls: Array = session.get("balls", []) if typeof(session.get("balls", [])) == TYPE_ARRAY else []
	for ball_value in balls:
		var ball: Dictionary = ball_value if typeof(ball_value) == TYPE_DICTIONARY else {}
		if bool(ball.get("alive", false)):
			total += 1
	return total


func add_award_event(session: Dictionary, element_id: String, element_type: String, position_value: Variant, award: int, ball_index: int) -> void:
	var position: Vector2 = _vector2_from_value(position_value, Vector2(0.5, 0.5))
	_register_manual_event(session, element_id, element_type, position, maxi(0, award), maxi(0, ball_index))


func _em_bumper_drop_layout() -> Dictionary:
	return {
		"id": "em_bumper_drop",
		"ball_budget": 1,
		"cap": 500,
		"ball_radius": 0.018,
		"gravity": Vector2(0.0, 2.85),
		"linear_damping": 0.989,
		"restitution": 0.80,
		"launch_speed_min": 2.35,
		"launch_speed_max": 3.45,
		"max_ball_speed": 5.20,
		"plunger_start": Vector2(0.50, 0.82),
		"plunger_direction": Vector2(0.0, -1.0),
		"lane_offsets": {"left": -0.14, "center": 0.0, "right": 0.14},
		"lane_starts": {"left": Vector2(0.22, 0.88), "center": Vector2(0.50, 0.92), "right": Vector2(0.78, 0.88)},
		"lane_directions": {"left": Vector2(0.30, -1.0), "center": Vector2(0.0, -1.0), "right": Vector2(-0.30, -1.0)},
		"max_ticks": 300,
		"elements": [
			_segment("left_rail", "rail", Vector2(0.06, 0.08), Vector2(0.06, 0.94), 0),
			_segment("right_rail", "rail", Vector2(0.94, 0.08), Vector2(0.94, 0.94), 0),
			_segment("top_rail", "rail", Vector2(0.08, 0.08), Vector2(0.92, 0.08), 0),
			_segment("plunger_lane", "plunger_lane", Vector2(0.57, 0.56), Vector2(0.57, 0.96), 0),
			_circle("bumper_lower", "bumper", Vector2(0.25, 0.62), 0.052, 10, 1.04),
			_circle("bumper_center", "bumper", Vector2(0.50, 0.42), 0.060, 12, 1.16),
			_circle("bumper_left", "bumper", Vector2(0.31, 0.30), 0.052, 8, 1.02),
			_circle("bumper_right", "bumper", Vector2(0.69, 0.30), 0.052, 8, 1.02),
			_segment("sling_left", "slingshot", Vector2(0.16, 0.70), Vector2(0.38, 0.78), 5, 0.62),
			_segment("sling_right", "slingshot", Vector2(0.84, 0.70), Vector2(0.62, 0.78), 5, 0.62),
			_sensor_circle("cup_left", "pocket", Vector2(0.20, 0.91), 0.056, 25),
			_sensor_circle("cup_center", "pocket", Vector2(0.50, 0.94), 0.060, 40),
			_sensor_circle("cup_right", "pocket", Vector2(0.80, 0.91), 0.056, 60),
			_drain("main_drain", Rect2(Vector2(0.0, 0.972), Vector2(1.0, 0.08))),
		],
	}


func _lane_multiball_layout() -> Dictionary:
	return {
		"id": "lane_multiball",
		"ball_budget": 3,
		"cap": 1200,
		"ball_radius": 0.017,
		"gravity": Vector2(0.0, 3.10),
		"linear_damping": 0.989,
		"restitution": 0.81,
		"launch_speed_min": 2.75,
		"launch_speed_max": 3.95,
		"max_ball_speed": 5.65,
		"plunger_start": Vector2(0.50, 0.90),
		"plunger_direction": Vector2(0.0, -1.0),
		"lane_offsets": {"left": -0.20, "center": 0.0, "right": 0.20},
		"lane_starts": {"left": Vector2(0.22, 0.90), "center": Vector2(0.50, 0.92), "right": Vector2(0.78, 0.90)},
		"lane_directions": {"left": Vector2(0.34, -1.0), "center": Vector2(0.0, -1.0), "right": Vector2(-0.34, -1.0)},
		"max_ticks": 300,
		"elements": [
			_segment("left_rail", "rail", Vector2(0.05, 0.06), Vector2(0.05, 0.95), 0),
			_segment("right_rail", "rail", Vector2(0.95, 0.06), Vector2(0.95, 0.95), 0),
			_segment("top_rail", "rail", Vector2(0.07, 0.06), Vector2(0.93, 0.06), 0),
			_circle("upper_bumper", "bumper", Vector2(0.50, 0.25), 0.056, 10, 1.08),
			_circle("left_bumper", "bumper", Vector2(0.34, 0.38), 0.050, 8, 1.00),
			_circle("right_bumper", "bumper", Vector2(0.66, 0.38), 0.050, 8, 1.00),
			_sensor_circle("left_lane", "lane", Vector2(0.27, 0.18), 0.048, 14),
			_sensor_circle("center_lane", "lane", Vector2(0.50, 0.15), 0.048, 12),
			_sensor_circle("right_lane", "lane", Vector2(0.73, 0.18), 0.048, 14),
			_sensor_circle("left_ramp", "ramp", Vector2(0.23, 0.55), 0.055, 30, {"lock": true, "route": Vector2(0.58, -0.58)}),
			_sensor_circle("right_ramp", "ramp", Vector2(0.77, 0.55), 0.055, 30, {"lock": true, "route": Vector2(-0.58, -0.58)}),
			_segment("sling_left", "slingshot", Vector2(0.17, 0.73), Vector2(0.39, 0.81), 6, 0.72),
			_segment("sling_right", "slingshot", Vector2(0.83, 0.73), Vector2(0.61, 0.81), 6, 0.72),
			_sensor_circle("lock_cup", "pocket", Vector2(0.50, 0.985), 0.040, 45),
			_drain("main_drain", Rect2(Vector2(0.0, 0.975), Vector2(1.0, 0.08))),
		],
	}


func _video_feature_layout() -> Dictionary:
	return {
		"id": "video_feature",
		"ball_budget": 4,
		"cap": 2000,
		"ball_radius": 0.016,
		"gravity": Vector2(0.0, 3.05),
		"linear_damping": 0.989,
		"restitution": 0.82,
		"launch_speed_min": 2.90,
		"launch_speed_max": 4.05,
		"max_ball_speed": 5.90,
		"plunger_start": Vector2(0.90, 0.90),
		"plunger_direction": Vector2(-0.20, -1.0),
		"lane_offsets": {"left": -0.02, "center": 0.0, "right": 0.02},
		"lane_starts": {"left": Vector2(0.88, 0.90), "center": Vector2(0.90, 0.91), "right": Vector2(0.92, 0.90)},
		"lane_directions": {"left": Vector2(-0.66, -1.0), "center": Vector2(-0.36, -1.0), "right": Vector2(-0.12, -1.0)},
		"max_ticks": 360,
		"elements": [
			_segment("left_wall", "wall", Vector2(0.05, 0.05), Vector2(0.05, 0.93), 0),
			_segment("right_wall", "wall", Vector2(0.95, 0.05), Vector2(0.95, 0.93), 0),
			_segment("top_wall", "wall", Vector2(0.07, 0.05), Vector2(0.93, 0.05), 0),
			_segment("left_guide", "rail", Vector2(0.16, 0.62), Vector2(0.34, 0.72), 0),
			_segment("right_guide", "rail", Vector2(0.84, 0.62), Vector2(0.66, 0.72), 0),
			_circle("pop_a", "bumper", Vector2(0.34, 0.30), 0.048, 9, 1.08),
			_circle("pop_b", "bumper", Vector2(0.50, 0.22), 0.050, 10, 1.10),
			_circle("pop_c", "bumper", Vector2(0.66, 0.32), 0.048, 9, 1.08),
			_circle("mini_bumper", "bumper", Vector2(0.50, 0.44), 0.042, 7, 0.92),
			_sensor_circle("spinner", "spinner", Vector2(0.26, 0.44), 0.046, 13, {"route": Vector2(0.44, -0.30)}),
			_sensor_circle("left_orbit", "orbit", Vector2(0.16, 0.24), 0.046, 17, {"route": Vector2(0.56, -0.38)}),
			_sensor_circle("right_orbit", "orbit", Vector2(0.84, 0.24), 0.046, 17, {"route": Vector2(-0.56, -0.38)}),
			_sensor_circle("target_alpha", "drop_target", Vector2(0.41, 0.48), 0.040, 16, {"light": "target_alpha", "route": Vector2(-0.18, -0.12)}),
			_sensor_circle("target_beta", "drop_target", Vector2(0.50, 0.52), 0.040, 16, {"light": "target_beta", "route": Vector2(0.0, -0.16)}),
			_sensor_circle("target_gamma", "drop_target", Vector2(0.59, 0.48), 0.040, 16, {"light": "target_gamma", "route": Vector2(0.18, -0.12)}),
			_sensor_circle("left_ramp", "ramp", Vector2(0.22, 0.58), 0.052, 23, {"lock": true, "light": "left_ramp", "route": Vector2(0.62, -0.54)}),
			_sensor_circle("right_ramp", "ramp", Vector2(0.78, 0.58), 0.052, 23, {"lock": true, "light": "right_ramp", "route": Vector2(-0.62, -0.54)}),
			_sensor_circle("center_lock", "ramp", Vector2(0.50, 0.64), 0.046, 18, {"lock": true, "light": "center_lock", "route": Vector2(0.0, -0.48)}),
			_segment("sling_left", "slingshot", Vector2(0.15, 0.72), Vector2(0.36, 0.79), 7, 0.76),
			_segment("sling_right", "slingshot", Vector2(0.85, 0.72), Vector2(0.64, 0.79), 7, 0.76),
			_flipper("left_flipper", Vector2(0.23, 0.86), Vector2(0.43, 0.80), Vector2(0.26, -1.18), "flipper_left"),
			_flipper("right_flipper", Vector2(0.77, 0.86), Vector2(0.57, 0.80), Vector2(-0.26, -1.18), "flipper_right"),
			_sensor_circle("cup_left", "pocket", Vector2(0.22, 0.91), 0.052, 22),
			_sensor_circle("cup_center", "pocket", Vector2(0.50, 0.92), 0.054, 30),
			_sensor_circle("cup_right", "pocket", Vector2(0.78, 0.91), 0.052, 26),
			_drain("main_drain", Rect2(Vector2(0.38, 0.947), Vector2(0.24, 0.09))),
		],
	}


func _resolve_static_collisions(session: Dictionary, ball: Dictionary, ball_index: int, layout: Dictionary, rng: RngStream) -> void:
	var elements: Array = layout.get("elements", []) if typeof(layout.get("elements", [])) == TYPE_ARRAY else []
	for element_value in elements:
		var element: Dictionary = element_value if typeof(element_value) == TYPE_DICTIONARY else {}
		var shape: String = str(element.get("shape", ""))
		if shape == "segment":
			_resolve_segment_collision(session, ball, ball_index, element, layout, rng)
		elif shape == "circle":
			_resolve_circle_collision(session, ball, ball_index, element, layout, rng)


func _resolve_segment_collision(session: Dictionary, ball: Dictionary, ball_index: int, element: Dictionary, layout: Dictionary, rng: RngStream) -> void:
	var a: Vector2 = _vector2_from_value(element.get("a", Vector2.ZERO), Vector2.ZERO)
	var b: Vector2 = _vector2_from_value(element.get("b", Vector2.ZERO), Vector2.ZERO)
	var position: Vector2 = _vector2_from_value(ball.get("position", Vector2.ZERO), Vector2.ZERO)
	var velocity: Vector2 = _vector2_from_value(ball.get("velocity", Vector2.ZERO), Vector2.ZERO)
	var radius: float = maxf(0.001, float(ball.get("radius", 0.018)))
	var thickness: float = maxf(0.0, float(element.get("thickness", 0.006)))
	var closest: Vector2 = _closest_point_on_segment(position, a, b)
	var delta: Vector2 = position - closest
	var distance: float = delta.length()
	var minimum: float = radius + thickness
	if distance > minimum:
		return
	var normal: Vector2 = delta / distance if distance > EPSILON else _segment_normal(a, b)
	position = closest + normal * (minimum + 0.0002)
	var normal_speed: float = velocity.dot(normal)
	if normal_speed < 0.0:
		var restitution: float = clampf(float(layout.get("restitution", 0.8)) * float(element.get("restitution", 1.0)), 0.05, 1.1)
		velocity -= normal * ((1.0 + restitution) * normal_speed)
		velocity *= clampf(float(element.get("tangent_damping", 0.985)), 0.5, 1.0)
	var element_type: String = str(element.get("type", "wall"))
	var active: bool = _element_input_active(session, element)
	var element_id: String = str(element.get("id", "element"))
	if (active or element_type == "slingshot") and _cooldown_ready(ball, element_id):
		var impulse: Vector2 = normal * float(element.get("impulse", 0.0))
		if active:
			impulse += _vector2_from_value(element.get("active_impulse", Vector2.ZERO), Vector2.ZERO)
		velocity += impulse + _tiny_variance(rng, 0.003)
		_register_element_event(session, ball, ball_index, element, position)
	ball["position"] = position
	ball["velocity"] = velocity


func _resolve_circle_collision(session: Dictionary, ball: Dictionary, ball_index: int, element: Dictionary, layout: Dictionary, rng: RngStream) -> void:
	var center: Vector2 = _vector2_from_value(element.get("position", Vector2.ZERO), Vector2.ZERO)
	var position: Vector2 = _vector2_from_value(ball.get("position", Vector2.ZERO), Vector2.ZERO)
	var velocity: Vector2 = _vector2_from_value(ball.get("velocity", Vector2.ZERO), Vector2.ZERO)
	var ball_radius: float = maxf(0.001, float(ball.get("radius", 0.018)))
	var element_radius: float = maxf(0.001, float(element.get("radius", 0.04)))
	var delta: Vector2 = position - center
	var distance: float = delta.length()
	var minimum: float = ball_radius + element_radius
	if distance > minimum:
		return
	var normal: Vector2 = delta / distance if distance > EPSILON else Vector2(0.0, -1.0)
	position = center + normal * (minimum + 0.0002)
	var normal_speed: float = velocity.dot(normal)
	if normal_speed < 0.0:
		var restitution: float = clampf(float(layout.get("restitution", 0.8)) * float(element.get("restitution", 1.0)), 0.05, 1.15)
		velocity -= normal * ((1.0 + restitution) * normal_speed)
	var element_id: String = str(element.get("id", "element"))
	if _cooldown_ready(ball, element_id):
		var impulse: float = maxf(0.0, float(element.get("impulse", 0.0)))
		velocity += normal * impulse + _tiny_variance(rng, 0.004)
		_register_element_event(session, ball, ball_index, element, position)
	ball["position"] = position
	ball["velocity"] = velocity


func _apply_sensor_elements(session: Dictionary, ball: Dictionary, ball_index: int, layout: Dictionary, rng: RngStream) -> void:
	if not bool(ball.get("alive", false)):
		return
	var position: Vector2 = _vector2_from_value(ball.get("position", Vector2.ZERO), Vector2.ZERO)
	var radius: float = maxf(0.001, float(ball.get("radius", 0.018)))
	var elements: Array = layout.get("elements", []) if typeof(layout.get("elements", [])) == TYPE_ARRAY else []
	for element_value in elements:
		var element: Dictionary = element_value if typeof(element_value) == TYPE_DICTIONARY else {}
		var shape: String = str(element.get("shape", ""))
		if shape == "sensor_circle":
			var center: Vector2 = _vector2_from_value(element.get("position", Vector2.ZERO), Vector2.ZERO)
			var element_radius: float = maxf(0.001, float(element.get("radius", 0.04)))
			var element_id: String = str(element.get("id", "element"))
			if position.distance_to(center) <= radius + element_radius and _cooldown_ready(ball, element_id):
				_register_element_event(session, ball, ball_index, element, position)
				_apply_sensor_behavior(session, ball, element, rng)
		elif shape == "drain_rect":
			var rect: Rect2 = _rect2_from_value(element.get("rect", Rect2()))
			if rect.has_point(position):
				_register_element_event(session, ball, ball_index, element, position)
				ball["alive"] = false
				return


func _apply_sensor_behavior(session: Dictionary, ball: Dictionary, element: Dictionary, rng: RngStream) -> void:
	var element_type: String = str(element.get("type", ""))
	var velocity: Vector2 = _vector2_from_value(ball.get("velocity", Vector2.ZERO), Vector2.ZERO)
	if element.has("route"):
		var route: Vector2 = _vector2_from_value(element.get("route", Vector2.ZERO), Vector2.ZERO)
		if route.length_squared() > EPSILON:
			velocity += route.normalized() * maxf(0.18, float(element.get("route_impulse", 0.52))) + _tiny_variance(rng, 0.001)
	if bool(element.get("lock", false)):
		session["locks"] = mini(3, maxi(0, int(session.get("locks", 0))) + 1)
	if element.has("light"):
		var lit: Dictionary = _copy_dict(session.get("lit", {}))
		lit[str(element.get("light", ""))] = true
		session["lit"] = lit
	if element_type == "drain":
		ball["alive"] = false
	else:
		ball["velocity"] = velocity


func _apply_bounds(session: Dictionary, ball: Dictionary, ball_index: int, layout: Dictionary) -> void:
	var position: Vector2 = _vector2_from_value(ball.get("position", Vector2.ZERO), Vector2.ZERO)
	var velocity: Vector2 = _vector2_from_value(ball.get("velocity", Vector2.ZERO), Vector2.ZERO)
	var radius: float = maxf(0.001, float(ball.get("radius", 0.018)))
	var restitution: float = clampf(float(layout.get("restitution", 0.8)), 0.05, 1.1)
	if position.x < radius:
		position.x = radius
		velocity.x = absf(velocity.x) * restitution
	elif position.x > 1.0 - radius:
		position.x = 1.0 - radius
		velocity.x = -absf(velocity.x) * restitution
	if position.y < radius:
		position.y = radius
		velocity.y = absf(velocity.y) * restitution
	elif position.y > 1.0 - radius:
		_register_manual_event(session, "bounds_drain", "drain", position, 0, ball_index)
		ball["alive"] = false
	ball["position"] = position
	ball["velocity"] = velocity


func _apply_nudge(session: Dictionary, balls: Array) -> void:
	if bool(session.get("tilt", false)):
		return
	var input: Dictionary = _copy_dict(session.get("input", {}))
	var nudge: Vector2 = _vector2_from_value(input.get("nudge", Vector2.ZERO), Vector2.ZERO)
	if nudge.length_squared() <= EPSILON:
		return
	var tilt_meter: float = maxf(0.0, float(session.get("tilt_meter", 0.0))) + nudge.length()
	session["tilt_meter"] = tilt_meter
	if tilt_meter > 3.0:
		session["tilt"] = true
		for ball_index in range(balls.size()):
			var tilted_ball: Dictionary = balls[ball_index] if typeof(balls[ball_index]) == TYPE_DICTIONARY else {}
			if bool(tilted_ball.get("alive", false)):
				var position: Vector2 = _vector2_from_value(tilted_ball.get("position", Vector2.ZERO), Vector2.ZERO)
				_register_manual_event(session, "tilt", "tilt", position, 0, ball_index)
				_register_manual_event(session, "tilt_drain", "drain", position, 0, ball_index)
				tilted_ball["alive"] = false
				balls[ball_index] = tilted_ball
		return
	var impulse: Vector2 = nudge * 0.55
	for ball_index in range(balls.size()):
		var ball: Dictionary = balls[ball_index] if typeof(balls[ball_index]) == TYPE_DICTIONARY else {}
		if bool(ball.get("alive", false)):
			var velocity: Vector2 = _vector2_from_value(ball.get("velocity", Vector2.ZERO), Vector2.ZERO)
			var position: Vector2 = _vector2_from_value(ball.get("position", Vector2.ZERO), Vector2.ZERO)
			ball["velocity"] = velocity + impulse
			_register_manual_event(session, "nudge", "input", position, 0, ball_index)
			balls[ball_index] = ball


func _record_trajectory(session: Dictionary) -> void:
	var trajectory: Array = session.get("trajectory", []) if typeof(session.get("trajectory", [])) == TYPE_ARRAY else []
	var balls: Array = session.get("balls", []) if typeof(session.get("balls", [])) == TYPE_ARRAY else []
	var time_value: float = float(session.get("time", 0.0))
	for ball_index in range(balls.size()):
		var ball: Dictionary = balls[ball_index] if typeof(balls[ball_index]) == TYPE_DICTIONARY else {}
		if bool(ball.get("alive", false)):
			var position: Vector2 = _vector2_from_value(ball.get("position", Vector2.ZERO), Vector2.ZERO)
			trajectory.append({
				"time": _quantized(time_value),
				"ball_index": ball_index,
				"position": _point_payload(position),
			})
	while trajectory.size() > TRAJECTORY_LIMIT:
		trajectory.remove_at(0)
	session["trajectory"] = trajectory


func _register_element_event(session: Dictionary, ball: Dictionary, ball_index: int, element: Dictionary, position: Vector2) -> void:
	var element_id: String = str(element.get("id", "element"))
	if not _cooldown_ready(ball, element_id):
		return
	var award: int = maxi(0, int(element.get("award", 0)))
	var effective_award: int = _effective_award(session, award)
	_register_manual_event(session, element_id, str(element.get("type", "")), position, effective_award, ball_index)
	_set_cooldown(ball, element_id, maxi(4, int(element.get("cooldown_ticks", 12))))
	if bool(element.get("extra_ball", false)):
		session["ball_budget"] = maxi(1, int(session.get("ball_budget", 1))) + 1


func _register_manual_event(session: Dictionary, element_id: String, element_type: String, position: Vector2, award: int, ball_index: int) -> void:
	var event_log: Array = session.get("event_log", []) if typeof(session.get("event_log", [])) == TYPE_ARRAY else []
	var effective_award: int = _effective_award(session, maxi(0, award))
	if award > 0 and effective_award <= 0:
		return
	event_log.append({
		"element_id": element_id,
		"element_type": element_type,
		"position": _point_payload(position),
		"award": effective_award,
		"time": _quantized(float(session.get("time", 0.0))),
		"ball_index": ball_index,
	})
	session["event_log"] = event_log
	session["total"] = mini(maxi(0, int(session.get("cap", 0))), maxi(0, int(session.get("total", 0))) + effective_award)


func _effective_award(session: Dictionary, award: int) -> int:
	var cap: int = maxi(0, int(session.get("cap", 0)))
	var total: int = maxi(0, int(session.get("total", 0)))
	return clampi(maxi(0, award), 0, maxi(0, cap - total))


func _policy_input(session: Dictionary, input_policy: Variant) -> Dictionary:
	var policy: Dictionary = _copy_dict(input_policy)
	var mode: String = str(policy.get("mode", "none"))
	if mode == "manual":
		return _copy_dict(policy.get("input", {}))
	if mode != "auto_flip":
		return {}
	var left := false
	var right := false
	var balls: Array = session.get("balls", []) if typeof(session.get("balls", [])) == TYPE_ARRAY else []
	for ball_value in balls:
		var ball: Dictionary = ball_value if typeof(ball_value) == TYPE_DICTIONARY else {}
		if not bool(ball.get("alive", false)):
			continue
		var position: Vector2 = _vector2_from_value(ball.get("position", Vector2.ZERO), Vector2.ZERO)
		if position.y > 0.72:
			if position.x < 0.50:
				left = true
			else:
				right = true
	return {
		"flipper_left": left,
		"flipper_right": right,
		"plunger_charge": 0.76,
		"nudge": Vector2.ZERO,
	}


func _merged_input(base: Dictionary, override: Dictionary) -> Dictionary:
	if override.is_empty():
		return base
	var result: Dictionary = base.duplicate(true)
	for key_value in override.keys():
		var key: String = str(key_value)
		result[key] = override[key]
	return result


func _timeout_drain(session: Dictionary) -> void:
	var balls: Array = session.get("balls", []) if typeof(session.get("balls", [])) == TYPE_ARRAY else []
	for ball_index in range(balls.size()):
		var ball: Dictionary = balls[ball_index] if typeof(balls[ball_index]) == TYPE_DICTIONARY else {}
		if bool(ball.get("alive", false)):
			var position: Vector2 = _vector2_from_value(ball.get("position", Vector2.ZERO), Vector2.ZERO)
			_register_manual_event(session, "timeout_drain", "drain", position, 0, ball_index)
			ball["alive"] = false
			balls[ball_index] = ball
	session["balls"] = balls


func _normalized_input(input: Dictionary) -> Dictionary:
	return {
		"flipper_left": bool(input.get("flipper_left", false)),
		"flipper_right": bool(input.get("flipper_right", false)),
		"plunger_charge": _normalized_power(input.get("plunger_charge", 0.0)),
		"nudge": _vector2_from_value(input.get("nudge", Vector2.ZERO), Vector2.ZERO),
	}


func _normalized_power(value: Variant) -> float:
	var power: float = float(value)
	if power > 1.0:
		power /= 100.0
	return clampf(power, 0.0, 1.0)


func _element_input_active(session: Dictionary, element: Dictionary) -> bool:
	var key: String = str(element.get("input", ""))
	if key.is_empty():
		return false
	var input: Dictionary = _copy_dict(session.get("input", {}))
	return bool(input.get(key, false))


func _closest_point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var length_sq: float = ab.length_squared()
	if length_sq <= EPSILON:
		return a
	var t: float = clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return a + ab * t


func _segment_normal(a: Vector2, b: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	if ab.length_squared() <= EPSILON:
		return Vector2(0.0, -1.0)
	return Vector2(-ab.y, ab.x).normalized()


func _tiny_variance(rng: RngStream, magnitude: float) -> Vector2:
	if magnitude <= 0.0:
		return Vector2.ZERO
	return Vector2(float(rng.randi_range(-100, 100)) / 100.0, float(rng.randi_range(-100, 100)) / 100.0) * magnitude


func _clamped_velocity(velocity: Vector2, layout: Dictionary) -> Vector2:
	var max_speed := maxf(0.45, float(layout.get("max_ball_speed", 2.25)))
	var length := velocity.length()
	if length <= max_speed:
		return velocity
	return velocity.normalized() * max_speed


func _cooldown_ready(ball: Dictionary, element_id: String) -> bool:
	var cooldowns: Dictionary = _copy_dict(ball.get("cooldowns", {}))
	return int(cooldowns.get(element_id, 0)) <= 0


func _set_cooldown(ball: Dictionary, element_id: String, ticks: int) -> void:
	var cooldowns: Dictionary = _copy_dict(ball.get("cooldowns", {}))
	cooldowns[element_id] = maxi(1, ticks)
	ball["cooldowns"] = cooldowns


func _decrement_cooldowns(ball: Dictionary) -> void:
	var cooldowns: Dictionary = _copy_dict(ball.get("cooldowns", {}))
	var keys: Array = cooldowns.keys()
	for key_value in keys:
		var key: String = str(key_value)
		cooldowns[key] = maxi(0, int(cooldowns.get(key, 0)) - 1)
	ball["cooldowns"] = cooldowns


func _lane_offset(layout: Dictionary, lane: String) -> float:
	var offsets: Dictionary = _copy_dict(layout.get("lane_offsets", {}))
	return float(offsets.get(lane, 0.0))


func _segment(id: String, element_type: String, a: Vector2, b: Vector2, award: int, impulse: float = 0.0) -> Dictionary:
	return {
		"id": id,
		"type": element_type,
		"shape": "segment",
		"a": a,
		"b": b,
		"thickness": 0.006,
		"award": award,
		"impulse": impulse,
		"cooldown_ticks": 12,
	}


func _flipper(id: String, a: Vector2, b: Vector2, active_impulse: Vector2, input_key: String) -> Dictionary:
	var element: Dictionary = _segment(id, "flipper", a, b, 0, 0.0)
	element["thickness"] = 0.012
	element["active_impulse"] = active_impulse
	element["input"] = input_key
	element["cooldown_ticks"] = 5
	return element


func _circle(id: String, element_type: String, position: Vector2, radius: float, award: int, impulse: float) -> Dictionary:
	return {
		"id": id,
		"type": element_type,
		"shape": "circle",
		"position": position,
		"radius": radius,
		"award": award,
		"impulse": impulse,
		"cooldown_ticks": 14,
	}


func _sensor_circle(id: String, element_type: String, position: Vector2, radius: float, award: int, extras: Dictionary = {}) -> Dictionary:
	var element: Dictionary = {
		"id": id,
		"type": element_type,
		"shape": "sensor_circle",
		"position": position,
		"radius": radius,
		"award": award,
		"cooldown_ticks": 18,
	}
	for key_value in extras.keys():
		var key: String = str(key_value)
		element[key] = extras[key]
	return element


func _drain(id: String, rect: Rect2) -> Dictionary:
	return {
		"id": id,
		"type": "drain",
		"shape": "drain_rect",
		"rect": rect,
		"award": 0,
		"cooldown_ticks": 1,
	}


func _point_payload(point: Vector2) -> Dictionary:
	return {
		"x": _quantized(point.x),
		"y": _quantized(point.y),
	}


func _quantized(value: float) -> float:
	return round(value * 100000.0) / 100000.0


func _vector2_from_value(value: Variant, fallback: Vector2) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value as Vector2
	if typeof(value) == TYPE_DICTIONARY:
		var dict: Dictionary = value
		return Vector2(float(dict.get("x", fallback.x)), float(dict.get("y", fallback.y)))
	if typeof(value) == TYPE_ARRAY:
		var array: Array = value
		if array.size() >= 2:
			return Vector2(float(array[0]), float(array[1]))
	return fallback


func _rect2_from_value(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value as Rect2
	if typeof(value) == TYPE_DICTIONARY:
		var dict: Dictionary = value
		return Rect2(
			Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0))),
			Vector2(float(dict.get("w", 0.0)), float(dict.get("h", 0.0)))
		)
	return Rect2()


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
