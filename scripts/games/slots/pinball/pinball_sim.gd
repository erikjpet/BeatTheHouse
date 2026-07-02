class_name PinballSim
extends RefCounted

const FIXED_DT := 1.0 / 120.0
const RNG_MODULUS := 2147483647
const RNG_MULTIPLIER := 48271
const EPSILON := 0.000001

const EVENT_PEG := 1
const EVENT_BUMPER := 2
const EVENT_WALL := 3
const EVENT_POCKET := 4
const EVENT_DRAIN := 5
const EVENT_SKILL := 6
const EVENT_SLINGSHOT := 7
const EVENT_LAUNCHER := 8
const EVENT_NUDGE := 9
const EVENT_TILT := 10
const EVENT_FLIPPER := 11
const EVENT_MULTIPLIER := 12
const EVENT_TIMEOUT := 13

const SENSOR_SKILL := 1
const SENSOR_SLINGSHOT := 2
const SENSOR_LAUNCHER := 3
const SENSOR_MULTIPLIER := 4

const RECT_DRAIN := 1
const RECT_POCKET := 2

var board_id := ""
var board_title := ""
var gravity := 3.15
var ball_radius := 0.013
var wall_restitution := 0.40
var linear_damping := 0.999
var max_speed := 9.0
var max_ticks := 960
var max_balls := 12
var active_ball_cap := 8
var max_events_per_tick := 12
var tilt_threshold := 1.0
var tilt_decay_per_tick := 0.006
var tilt_per_nudge := 0.34
var launch_position := Vector2(0.5, 0.075)
var launch_min_speed := 0.55
var launch_max_speed := 1.85
var launch_spread := 0.035
var skill_power := 0.82
var skill_width := 0.03

var peg_positions := PackedVector2Array()
var peg_radii := PackedFloat32Array()
var peg_awards := PackedInt32Array()
var peg_restitution := PackedFloat32Array()
var peg_bias := PackedFloat32Array()

var bumper_positions := PackedVector2Array()
var bumper_radii := PackedFloat32Array()
var bumper_awards := PackedInt32Array()
var bumper_restitution := PackedFloat32Array()
var bumper_kicks := PackedVector2Array()
var bumper_cooldowns := PackedInt32Array()
var bumper_ready_tick := PackedInt32Array()

var sensor_positions := PackedVector2Array()
var sensor_radii := PackedFloat32Array()
var sensor_types := PackedInt32Array()
var sensor_awards := PackedInt32Array()
var sensor_kicks := PackedVector2Array()
var sensor_cooldowns := PackedInt32Array()
var sensor_ready_tick := PackedInt32Array()

var rect_positions := PackedVector2Array()
var rect_sizes := PackedVector2Array()
var rect_types := PackedInt32Array()
var rect_awards := PackedInt32Array()

var flipper_positions := PackedVector2Array()
var flipper_radii := PackedFloat32Array()
var flipper_sides := PackedInt32Array()
var flipper_kicks := PackedVector2Array()
var flipper_ready_tick := PackedInt32Array()
var flipper_window_until_tick := PackedInt32Array()

var positions := PackedVector2Array()
var previous_positions := PackedVector2Array()
var velocities := PackedVector2Array()
var spins := PackedFloat32Array()
var active_flags := PackedInt32Array()
var age_ticks := PackedInt32Array()
var ball_sequence := PackedInt32Array()

var event_ticks := PackedInt32Array()
var event_types := PackedInt32Array()
var event_elements := PackedInt32Array()
var event_balls := PackedInt32Array()
var event_awards := PackedInt32Array()
var event_positions := PackedVector2Array()
var event_ring_size := 512
var event_write_index := 0
var event_total_count := 0
var events_this_tick := 0

var tick := 0
var rng_seed := 1
var rng_state := 1
var total_awarded := 0
var session_cap := 500
var session_multiplier := 1
var balls_launched := 0
var drain_count := 0
var timeout_count := 0
var tilt_meter := 0.0
var tilted := false
var max_active_seen := 0
var max_events_seen := 0
var max_tick_usec := 0
var accumulated_tick_usec := 0
var measured_ticks := 0
var nudge_x := 0.0
var nudge_y := 0.0
var nudge_pending := false
var nudge_count := 0
var flipper_window_count := 0
var flipper_rescue_count := 0
var flipper_left_pressed := false
var flipper_right_pressed := false
var bumper_battery_hits_config := 0
var bumper_battery_hits_remaining := 0
var bumper_battery_award_percent := 0
var bumper_battery_kick_percent := 100
var return_spring_uses_config := 0
var return_spring_remaining := 0
var return_spring_impulse := 0


func configure(compiled_board: Dictionary, seed_value: int, params: Dictionary = {}) -> void:
	board_id = str(compiled_board.get("id", ""))
	board_title = str(compiled_board.get("title", ""))
	gravity = float(compiled_board.get("gravity", gravity))
	ball_radius = float(compiled_board.get("ball_radius", ball_radius))
	wall_restitution = float(compiled_board.get("wall_restitution", wall_restitution))
	linear_damping = float(compiled_board.get("linear_damping", linear_damping))
	max_speed = float(compiled_board.get("max_speed", max_speed))
	max_ticks = maxi(1, int(compiled_board.get("max_ticks", max_ticks)))
	max_balls = maxi(1, int(compiled_board.get("max_balls", max_balls)))
	active_ball_cap = maxi(1, int(compiled_board.get("active_ball_cap", active_ball_cap)))
	event_ring_size = maxi(32, int(compiled_board.get("event_ring_size", event_ring_size)))
	max_events_per_tick = maxi(1, int(compiled_board.get("max_events_per_tick", max_events_per_tick)))
	tilt_threshold = float(compiled_board.get("tilt_threshold", tilt_threshold))
	tilt_decay_per_tick = float(compiled_board.get("tilt_decay_per_tick", tilt_decay_per_tick))
	tilt_per_nudge = float(compiled_board.get("tilt_per_nudge", tilt_per_nudge))
	launch_position = _vector2(compiled_board.get("launch_position", launch_position), launch_position)
	launch_min_speed = float(compiled_board.get("launch_min_speed", launch_min_speed))
	launch_max_speed = float(compiled_board.get("launch_max_speed", launch_max_speed))
	launch_spread = float(compiled_board.get("launch_spread", launch_spread))
	skill_power = float(compiled_board.get("skill_power", skill_power))
	skill_width = float(compiled_board.get("skill_width", skill_width))
	session_cap = maxi(1, int(params.get("cap", compiled_board.get("cap", 500))))
	peg_positions = compiled_board.get("peg_positions", PackedVector2Array())
	peg_radii = compiled_board.get("peg_radii", PackedFloat32Array())
	peg_awards = compiled_board.get("peg_awards", PackedInt32Array())
	peg_restitution = compiled_board.get("peg_restitution", PackedFloat32Array())
	peg_bias = compiled_board.get("peg_bias", PackedFloat32Array())
	bumper_positions = compiled_board.get("bumper_positions", PackedVector2Array())
	bumper_radii = compiled_board.get("bumper_radii", PackedFloat32Array())
	bumper_awards = compiled_board.get("bumper_awards", PackedInt32Array())
	bumper_restitution = compiled_board.get("bumper_restitution", PackedFloat32Array())
	bumper_kicks = compiled_board.get("bumper_kicks", PackedVector2Array())
	bumper_cooldowns = compiled_board.get("bumper_cooldowns", PackedInt32Array())
	sensor_positions = compiled_board.get("sensor_positions", PackedVector2Array())
	sensor_radii = compiled_board.get("sensor_radii", PackedFloat32Array())
	sensor_types = compiled_board.get("sensor_types", PackedInt32Array())
	sensor_awards = compiled_board.get("sensor_awards", PackedInt32Array())
	sensor_kicks = compiled_board.get("sensor_kicks", PackedVector2Array())
	sensor_cooldowns = compiled_board.get("sensor_cooldowns", PackedInt32Array())
	rect_positions = compiled_board.get("rect_positions", PackedVector2Array())
	rect_sizes = compiled_board.get("rect_sizes", PackedVector2Array())
	rect_types = compiled_board.get("rect_types", PackedInt32Array())
	rect_awards = compiled_board.get("rect_awards", PackedInt32Array())
	flipper_positions = compiled_board.get("flipper_positions", PackedVector2Array())
	flipper_radii = compiled_board.get("flipper_radii", PackedFloat32Array())
	flipper_sides = compiled_board.get("flipper_sides", PackedInt32Array())
	flipper_kicks = compiled_board.get("flipper_kicks", PackedVector2Array())
	bumper_battery_hits_config = maxi(0, int(compiled_board.get("bumper_battery_hits", 0)))
	bumper_battery_award_percent = maxi(0, int(compiled_board.get("bumper_battery_award_percent", 0)))
	bumper_battery_kick_percent = maxi(0, int(compiled_board.get("bumper_battery_kick_percent", 100)))
	return_spring_uses_config = maxi(0, int(compiled_board.get("return_spring_uses", 0)))
	return_spring_impulse = maxi(0, int(compiled_board.get("return_spring_impulse", 0)))
	_resize_runtime_arrays()
	rng_seed = _normalize_seed(seed_value)
	rng_state = rng_seed
	reset_round()


func reset_round() -> void:
	tick = 0
	total_awarded = 0
	session_multiplier = 1
	balls_launched = 0
	drain_count = 0
	timeout_count = 0
	tilt_meter = 0.0
	tilted = false
	max_active_seen = 0
	max_events_seen = 0
	max_tick_usec = 0
	accumulated_tick_usec = 0
	measured_ticks = 0
	nudge_pending = false
	nudge_count = 0
	flipper_window_count = 0
	flipper_rescue_count = 0
	bumper_battery_hits_remaining = bumper_battery_hits_config
	return_spring_remaining = return_spring_uses_config
	flipper_left_pressed = false
	flipper_right_pressed = false
	event_write_index = 0
	event_total_count = 0
	_clear_int_array(active_flags)
	_clear_int_array(age_ticks)
	_clear_int_array(ball_sequence)
	_clear_int_array(bumper_ready_tick)
	_clear_int_array(sensor_ready_tick)
	_clear_int_array(flipper_ready_tick)
	_clear_int_array(flipper_window_until_tick)


func launch_ball(params: Dictionary = {}) -> int:
	if active_ball_count() >= active_ball_cap:
		return -1
	var index := _first_free_ball()
	if index < 0:
		return -1
	var power := _normalized_power(params.get("power", 0.68))
	var aim := clampf(float(params.get("aim", 0.0)), -1.0, 1.0)
	var start := _vector2(params.get("position", launch_position), launch_position)
	var angle := aim * 0.52 + _rand_signed() * launch_spread
	var direction := Vector2(sin(angle), cos(angle)).normalized()
	var speed := lerpf(launch_min_speed, launch_max_speed, power)
	positions[index] = start
	previous_positions[index] = start
	velocities[index] = direction * speed
	spins[index] = _rand_signed() * 0.03
	active_flags[index] = 1
	age_ticks[index] = 0
	ball_sequence[index] = balls_launched
	balls_launched += 1
	if absf(power - skill_power) <= skill_width:
		_register_event(EVENT_SKILL, 2000, index, 8, start)
		velocities[index] = velocities[index] + Vector2(0.70, -0.30)
	_update_max_active()
	return index


func set_controls(p_nudge_x: float = 0.0, p_nudge_y: float = 0.0, p_flipper_left: bool = false, p_flipper_right: bool = false) -> void:
	nudge_x = clampf(p_nudge_x, -1.0, 1.0)
	nudge_y = clampf(p_nudge_y, -1.0, 1.0)
	nudge_pending = absf(nudge_x) > 0.001 or absf(nudge_y) > 0.001
	flipper_left_pressed = p_flipper_left
	flipper_right_pressed = p_flipper_right


func apply_input(input: Dictionary) -> void:
	set_controls(
		float(input.get("nudge_x", input.get("x", 0.0))),
		float(input.get("nudge_y", input.get("y", 0.0))),
		bool(input.get("flipper_left", false)),
		bool(input.get("flipper_right", false))
	)


func advance(delta_msec: int, input: Dictionary = {}) -> void:
	if not input.is_empty():
		apply_input(input)
	var ticks_to_run := maxi(1, int(round(float(delta_msec) / (FIXED_DT * 1000.0))))
	for _i in range(ticks_to_run):
		step_tick()


func advance_ticks(ticks_to_run: int) -> void:
	for _i in range(maxi(0, ticks_to_run)):
		step_tick()


func step_tick() -> void:
	var before_usec := Time.get_ticks_usec()
	tick += 1
	events_this_tick = 0
	_decay_tilt()
	_apply_nudge()
	for ball_index in range(max_balls):
		if active_flags[ball_index] == 0:
			continue
		_step_ball(ball_index)
	_update_max_active()
	var elapsed := Time.get_ticks_usec() - before_usec
	accumulated_tick_usec += elapsed
	measured_ticks += 1
	max_tick_usec = maxi(max_tick_usec, elapsed)
	max_events_seen = maxi(max_events_seen, events_this_tick)
	flipper_left_pressed = false
	flipper_right_pressed = false


func active_ball_count() -> int:
	var total := 0
	for index in range(max_balls):
		total += active_flags[index]
	return total


func result_signature() -> Dictionary:
	var type_counts := {}
	var event_count := mini(event_total_count, event_ring_size)
	for offset in range(event_count):
		var ring_index := posmod(event_write_index - event_count + offset, event_ring_size)
		var type_id := int(event_types[ring_index])
		type_counts[str(type_id)] = int(type_counts.get(str(type_id), 0)) + 1
	return {
		"board_id": board_id,
		"seed": rng_seed,
		"ticks": tick,
		"award": total_awarded,
		"cap": session_cap,
		"balls_launched": balls_launched,
		"drains": drain_count,
		"timeouts": timeout_count,
		"active": active_ball_count(),
		"tilted": tilted,
		"events": event_total_count,
		"event_type_counts": type_counts,
		"max_active": max_active_seen,
		"max_events_per_tick": max_events_seen,
		"nudge_count": nudge_count,
		"flipper_window_count": flipper_window_count,
		"flipper_rescue_count": flipper_rescue_count,
		"bumper_battery_hits_remaining": bumper_battery_hits_remaining,
		"return_spring_remaining": return_spring_remaining,
		"avg_tick_usec": float(accumulated_tick_usec) / float(maxi(1, measured_ticks)),
		"max_tick_usec": max_tick_usec,
		"rng_state": rng_state,
	}


func event_log_since(start_total_count: int = 0) -> Array:
	var result: Array = []
	var available := mini(event_total_count, event_ring_size)
	var first_count := event_total_count - available
	var begin_count := clampi(start_total_count, first_count, event_total_count)
	for absolute_count in range(begin_count, event_total_count):
		var ring_index := posmod(event_write_index - (event_total_count - absolute_count), event_ring_size)
		result.append({
			"element_id": _event_element_id(int(event_types[ring_index]), int(event_elements[ring_index])),
			"element_type": _event_type_name(int(event_types[ring_index])),
			"position": _point_payload(event_positions[ring_index]),
			"award": int(event_awards[ring_index]),
			"time": snappedf(float(event_ticks[ring_index]) * FIXED_DT, 0.0001),
			"ball_index": int(event_balls[ring_index]),
		})
	return result


func active_position_log(local_time: float = -1.0) -> Array:
	var result: Array = []
	var time_value := snappedf(float(tick) * FIXED_DT, 0.0001) if local_time < 0.0 else snappedf(local_time, 0.0001)
	for ball_index in range(max_balls):
		if active_flags[ball_index] == 0:
			continue
		result.append({
			"time": time_value,
			"ball_index": ball_index,
			"position": _point_payload(positions[ball_index]),
		})
	return result


func compact_snapshot() -> Dictionary:
	return {
		"tick": tick,
		"total_awarded": total_awarded,
		"balls_launched": balls_launched,
		"active_ball_count": active_ball_count(),
		"drain_count": drain_count,
		"tilt_meter": snappedf(tilt_meter, 0.001),
		"tilted": tilted,
		"session_multiplier": session_multiplier,
		"event_total_count": event_total_count,
		"max_active_seen": max_active_seen,
		"nudge_count": nudge_count,
		"flipper_window_count": flipper_window_count,
		"flipper_rescue_count": flipper_rescue_count,
		"bumper_battery_hits_remaining": bumper_battery_hits_remaining,
		"return_spring_remaining": return_spring_remaining,
		"avg_tick_usec": float(accumulated_tick_usec) / float(maxi(1, measured_ticks)),
		"max_tick_usec": max_tick_usec,
		"max_events_per_tick": max_events_seen,
	}


func run_headless(seed_value: int, compiled_board: Dictionary, input_script: Array, params: Dictionary = {}) -> Dictionary:
	configure(compiled_board, seed_value, params)
	var launch_params: Variant = params.get("launch", {"power": 0.68, "aim": 0.0})
	if typeof(launch_params) == TYPE_DICTIONARY:
		launch_ball(launch_params)
	else:
		launch_ball()
	var script_index := 0
	var max_run_ticks := maxi(1, int(params.get("max_ticks", compiled_board.get("max_ticks", 960))))
	while active_ball_count() > 0 and tick < max_run_ticks:
		while script_index < input_script.size():
			var entry: Dictionary = input_script[script_index] if typeof(input_script[script_index]) == TYPE_DICTIONARY else {}
			if int(entry.get("tick", 0)) != tick:
				break
			if bool(entry.get("launch", false)):
				launch_ball(entry)
			apply_input(entry)
			script_index += 1
		step_tick()
	return result_signature()


func _resize_runtime_arrays() -> void:
	positions.resize(max_balls)
	previous_positions.resize(max_balls)
	velocities.resize(max_balls)
	spins.resize(max_balls)
	active_flags.resize(max_balls)
	age_ticks.resize(max_balls)
	ball_sequence.resize(max_balls)
	bumper_ready_tick.resize(bumper_positions.size())
	sensor_ready_tick.resize(sensor_positions.size())
	flipper_ready_tick.resize(flipper_positions.size())
	flipper_window_until_tick.resize(flipper_positions.size())
	event_ticks.resize(event_ring_size)
	event_types.resize(event_ring_size)
	event_elements.resize(event_ring_size)
	event_balls.resize(event_ring_size)
	event_awards.resize(event_ring_size)
	event_positions.resize(event_ring_size)


func _step_ball(ball_index: int) -> void:
	var pos := positions[ball_index]
	var vel := velocities[ball_index]
	previous_positions[ball_index] = pos
	vel.y += gravity * FIXED_DT
	vel *= linear_damping
	vel = _clamped_velocity(vel)
	positions[ball_index] = pos
	velocities[ball_index] = vel
	_try_return_spring(ball_index)
	pos = positions[ball_index]
	vel = velocities[ball_index]
	var substeps := clampi(int(ceil(vel.length() / 2.25)), 1, 4)
	var sub_dt := FIXED_DT / float(substeps)
	for _substep in range(substeps):
		pos += vel * sub_dt
		_resolve_walls(ball_index, pos, vel)
		pos = positions[ball_index]
		vel = velocities[ball_index]
		_resolve_pegs(ball_index, pos, vel)
		pos = positions[ball_index]
		vel = velocities[ball_index]
		_resolve_bumpers(ball_index, pos, vel)
		pos = positions[ball_index]
		vel = velocities[ball_index]
		_resolve_sensors(ball_index, pos, vel)
		pos = positions[ball_index]
		vel = velocities[ball_index]
		_resolve_flippers(ball_index, pos, vel)
		pos = positions[ball_index]
		vel = velocities[ball_index]
		_resolve_rects(ball_index, pos)
		if active_flags[ball_index] == 0:
			return
		pos = positions[ball_index]
		vel = velocities[ball_index]
	_try_return_spring(ball_index)
	age_ticks[ball_index] = age_ticks[ball_index] + 1
	if age_ticks[ball_index] >= max_ticks:
		timeout_count += 1
		_drain_ball(ball_index, EVENT_TIMEOUT, 3999, positions[ball_index])


func _resolve_walls(ball_index: int, pos: Vector2, vel: Vector2) -> void:
	var hit := false
	if pos.x < ball_radius:
		pos.x = ball_radius
		vel.x = absf(vel.x) * wall_restitution
		hit = true
	elif pos.x > 1.0 - ball_radius:
		pos.x = 1.0 - ball_radius
		vel.x = -absf(vel.x) * wall_restitution
		hit = true
	if pos.y < ball_radius:
		pos.y = ball_radius
		vel.y = absf(vel.y) * wall_restitution
		hit = true
	if pos.y > 1.030:
		positions[ball_index] = pos
		velocities[ball_index] = vel
		_drain_ball(ball_index, EVENT_DRAIN, 3998, pos)
		return
	positions[ball_index] = pos
	velocities[ball_index] = _clamped_velocity(vel)
	if hit:
		_register_event(EVENT_WALL, -1, ball_index, 0, pos)


func _try_return_spring(ball_index: int) -> void:
	if return_spring_remaining <= 0 or active_flags[ball_index] == 0:
		return
	var pos := positions[ball_index]
	var vel := velocities[ball_index]
	if pos.y < 0.700 or pos.y > 0.950:
		return
	if vel.y < 0.05 or vel.length() > 0.92:
		return
	var impulse := maxf(0.60, float(return_spring_impulse) / 100.0)
	vel += Vector2(0.0, -impulse)
	pos.y = maxf(ball_radius, pos.y - 0.006)
	return_spring_remaining -= 1
	positions[ball_index] = pos
	velocities[ball_index] = _clamped_velocity(vel)
	_register_event(EVENT_LAUNCHER, -4, ball_index, 0, pos)


func _resolve_pegs(ball_index: int, pos: Vector2, vel: Vector2) -> void:
	for index in range(peg_positions.size()):
		var peg_pos := peg_positions[index]
		var min_dist := ball_radius + float(peg_radii[index])
		var delta := pos - peg_pos
		var dist_sq := delta.length_squared()
		if dist_sq >= min_dist * min_dist or dist_sq <= EPSILON:
			continue
		var dist := sqrt(dist_sq)
		var normal := delta / dist
		pos = peg_pos + normal * (min_dist + 0.0002)
		vel = _bounce_velocity(ball_index, vel, normal, float(peg_restitution[index]), float(peg_bias[index]))
		positions[ball_index] = pos
		velocities[ball_index] = _clamped_velocity(vel)
		_register_event(EVENT_PEG, index, ball_index, int(peg_awards[index]), pos)


func _resolve_bumpers(ball_index: int, pos: Vector2, vel: Vector2) -> void:
	for index in range(bumper_positions.size()):
		var bumper_pos := bumper_positions[index]
		var min_dist := ball_radius + float(bumper_radii[index])
		var delta := pos - bumper_pos
		var dist_sq := delta.length_squared()
		if dist_sq >= min_dist * min_dist or dist_sq <= EPSILON:
			continue
		var dist := sqrt(dist_sq)
		var normal := delta / dist
		pos = bumper_pos + normal * (min_dist + 0.0003)
		var kick := bumper_kicks[index]
		var award := int(bumper_awards[index])
		if bumper_battery_hits_remaining > 0:
			kick *= maxf(1.0, float(bumper_battery_kick_percent) / 100.0)
			award += maxi(1, int(round(float(maxi(1, award) * bumper_battery_award_percent) / 100.0)))
			bumper_battery_hits_remaining -= 1
		vel = _bounce_velocity(ball_index, vel, normal, float(bumper_restitution[index]), 0.0) + kick
		positions[ball_index] = pos
		velocities[ball_index] = _clamped_velocity(vel)
		if tick >= int(bumper_ready_tick[index]):
			bumper_ready_tick[index] = tick + int(bumper_cooldowns[index])
			_register_event(EVENT_BUMPER, 1000 + index, ball_index, award, pos)


func _resolve_sensors(ball_index: int, pos: Vector2, vel: Vector2) -> void:
	for index in range(sensor_positions.size()):
		var sensor_pos := sensor_positions[index]
		var min_dist := ball_radius + float(sensor_radii[index])
		var delta := pos - sensor_pos
		if delta.length_squared() >= min_dist * min_dist:
			continue
		if tick < int(sensor_ready_tick[index]):
			continue
		sensor_ready_tick[index] = tick + int(sensor_cooldowns[index])
		var sensor_type := int(sensor_types[index])
		var event_type := EVENT_LAUNCHER
		if sensor_type == SENSOR_SKILL:
			event_type = EVENT_SKILL
		elif sensor_type == SENSOR_SLINGSHOT:
			event_type = EVENT_SLINGSHOT
		elif sensor_type == SENSOR_MULTIPLIER:
			event_type = EVENT_MULTIPLIER
			session_multiplier = mini(3, session_multiplier + 1)
		vel += sensor_kicks[index]
		positions[ball_index] = pos
		velocities[ball_index] = _clamped_velocity(vel)
		_register_event(event_type, 2000 + index, ball_index, int(sensor_awards[index]), pos)


func _resolve_rects(ball_index: int, pos: Vector2) -> void:
	for index in range(rect_positions.size()):
		var rect_pos := rect_positions[index]
		var rect_size := rect_sizes[index]
		if pos.x < rect_pos.x or pos.x > rect_pos.x + rect_size.x or pos.y < rect_pos.y or pos.y > rect_pos.y + rect_size.y:
			continue
		var rect_type := int(rect_types[index])
		if rect_type == RECT_DRAIN:
			_drain_ball(ball_index, EVENT_DRAIN, 3000 + index, pos)
			return
		if rect_type == RECT_POCKET:
			_register_event(EVENT_POCKET, 3000 + index, ball_index, int(rect_awards[index]), pos)
			_drain_ball(ball_index, EVENT_DRAIN, 3000 + index, pos)
			return


func _resolve_flippers(ball_index: int, pos: Vector2, vel: Vector2) -> void:
	_update_flipper_windows(pos, vel)
	if not flipper_left_pressed and not flipper_right_pressed:
		return
	for index in range(flipper_positions.size()):
		var side := int(flipper_sides[index])
		if side < 0 and not flipper_left_pressed:
			continue
		if side > 0 and not flipper_right_pressed:
			continue
		if tick < int(flipper_ready_tick[index]):
			continue
		var delta := pos - flipper_positions[index]
		var min_dist := ball_radius + float(flipper_radii[index])
		var within_window := tick <= int(flipper_window_until_tick[index]) and _in_flipper_approach(pos, vel, side)
		if delta.length_squared() >= min_dist * min_dist and not within_window:
			continue
		if within_window and delta.length_squared() >= min_dist * min_dist:
			pos = flipper_positions[index] + Vector2(float(-side) * 0.035, -0.020)
		vel = flipper_kicks[index] + Vector2(float(-side) * 0.15, 0.0)
		flipper_ready_tick[index] = tick + 18
		positions[ball_index] = pos
		velocities[ball_index] = _clamped_velocity(vel)
		flipper_rescue_count += 1
		_register_event(EVENT_FLIPPER, 4000 + index, ball_index, 0, pos)


func _update_flipper_windows(pos: Vector2, vel: Vector2) -> void:
	if vel.y < 0.12:
		return
	for index in range(flipper_positions.size()):
		var side := int(flipper_sides[index])
		if not _in_flipper_approach(pos, vel, side):
			continue
		if tick > int(flipper_window_until_tick[index]):
			flipper_window_count += 1
		flipper_window_until_tick[index] = maxi(int(flipper_window_until_tick[index]), tick + 18)


func _in_flipper_approach(pos: Vector2, _vel: Vector2, side: int) -> bool:
	if pos.y < 0.760 or pos.y > 0.965:
		return false
	if side < 0:
		return pos.x <= 0.300
	if side > 0:
		return pos.x >= 0.700
	return false


func _apply_nudge() -> void:
	if not nudge_pending or tilted:
		return
	var impulse := Vector2(nudge_x * 0.52, -maxf(0.0, nudge_y) * 0.16)
	var nudged_any := false
	for ball_index in range(max_balls):
		if active_flags[ball_index] == 0:
			continue
		velocities[ball_index] = _clamped_velocity(velocities[ball_index] + impulse)
		_register_event(EVENT_NUDGE, -2, ball_index, 0, positions[ball_index])
		nudged_any = true
	if nudged_any:
		nudge_count += 1
	tilt_meter += tilt_per_nudge * maxf(0.35, absf(nudge_x) + absf(nudge_y))
	nudge_pending = false
	if tilt_meter > tilt_threshold:
		tilted = true
		for ball_index in range(max_balls):
			if active_flags[ball_index] != 0:
				_drain_ball(ball_index, EVENT_TILT, -3, positions[ball_index])


func _decay_tilt() -> void:
	if tilt_meter > 0.0 and not nudge_pending:
		tilt_meter = maxf(0.0, tilt_meter - tilt_decay_per_tick)


func _bounce_velocity(ball_index: int, vel: Vector2, normal: Vector2, restitution: float, side_bias: float) -> Vector2:
	var vn := vel.dot(normal)
	if vn < 0.0:
		vel -= normal * ((1.0 + restitution) * vn)
	else:
		vel += normal * (0.08 * restitution)
	var tangent := Vector2(-normal.y, normal.x)
	var spin := float(spins[ball_index])
	var tangential := vel.dot(tangent)
	spin = clampf(spin * 0.76 + tangential * 0.018 + side_bias, -0.45, 0.45)
	spins[ball_index] = spin
	vel += tangent * (spin * 0.070 + side_bias)
	return vel


func _drain_ball(ball_index: int, event_type: int, element_index: int, pos: Vector2) -> void:
	if active_flags[ball_index] == 0:
		return
	active_flags[ball_index] = 0
	drain_count += 1
	_register_event(event_type, element_index, ball_index, 0, pos)


func _register_event(event_type: int, element_index: int, ball_index: int, award: int, pos: Vector2) -> void:
	if events_this_tick >= max_events_per_tick:
		return
	var effective_award := 0
	if award > 0 and total_awarded < session_cap:
		effective_award = mini(session_cap - total_awarded, maxi(0, award * session_multiplier))
		total_awarded += effective_award
	event_ticks[event_write_index] = tick
	event_types[event_write_index] = event_type
	event_elements[event_write_index] = element_index
	event_balls[event_write_index] = ball_index
	event_awards[event_write_index] = effective_award
	event_positions[event_write_index] = pos
	event_write_index = posmod(event_write_index + 1, event_ring_size)
	event_total_count += 1
	events_this_tick += 1


func _clamped_velocity(vel: Vector2) -> Vector2:
	var length := vel.length()
	if length <= max_speed:
		return vel
	return vel / length * max_speed


func _first_free_ball() -> int:
	for index in range(max_balls):
		if active_flags[index] == 0:
			return index
	return -1


func _update_max_active() -> void:
	max_active_seen = maxi(max_active_seen, active_ball_count())


func _rand() -> int:
	rng_state = int((rng_state * RNG_MULTIPLIER) % RNG_MODULUS)
	return rng_state


func _rand_unit() -> float:
	return float(_rand() % 100000) / 99999.0


func _rand_signed() -> float:
	return _rand_unit() * 2.0 - 1.0


static func _normalize_seed(value: int) -> int:
	var normalized: int = abs(value) % RNG_MODULUS
	return 1 if normalized == 0 else normalized


static func _normalized_power(value: Variant) -> float:
	var power := float(value)
	if power > 1.0:
		power /= 100.0
	return clampf(power, 0.0, 1.0)


static func _vector2(value: Variant, fallback: Vector2) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value as Vector2
	if typeof(value) == TYPE_DICTIONARY:
		var dict := value as Dictionary
		return Vector2(float(dict.get("x", fallback.x)), float(dict.get("y", fallback.y)))
	if typeof(value) == TYPE_ARRAY:
		var array := value as Array
		if array.size() >= 2:
			return Vector2(float(array[0]), float(array[1]))
	return fallback


static func _clear_int_array(values: PackedInt32Array) -> void:
	for index in range(values.size()):
		values[index] = 0


static func _point_payload(point: Vector2) -> Dictionary:
	return {
		"x": snappedf(point.x, 0.0001),
		"y": snappedf(point.y, 0.0001),
	}


static func _event_type_name(event_type: int) -> String:
	match event_type:
		EVENT_PEG:
			return "peg"
		EVENT_BUMPER:
			return "bumper"
		EVENT_WALL:
			return "wall"
		EVENT_POCKET:
			return "pocket"
		EVENT_DRAIN:
			return "drain"
		EVENT_SKILL:
			return "skill_shot"
		EVENT_SLINGSHOT:
			return "slingshot"
		EVENT_LAUNCHER:
			return "launcher"
		EVENT_NUDGE:
			return "nudge"
		EVENT_TILT:
			return "tilt"
		EVENT_FLIPPER:
			return "flipper"
		EVENT_MULTIPLIER:
			return "multiplier"
		EVENT_TIMEOUT:
			return "drain"
		_:
			return "event"


static func _event_element_id(event_type: int, element_index: int) -> String:
	if element_index >= 4000:
		return "flipper_%d" % (element_index - 4000)
	if element_index >= 3000:
		return "slot_%d" % (element_index - 3000)
	if element_index >= 2000:
		return "sensor_%d" % (element_index - 2000)
	if element_index >= 1000:
		return "bumper_%d" % (element_index - 1000)
	if element_index >= 0:
		return "peg_%d" % element_index
	return _event_type_name(event_type)
