class_name CoinPusherSolver
extends RefCounted

const SCHEMA := "coin_pusher_fixed_point"
const VERSION := 1
const FIXED_HZ := 60
const FP := 1000
const WIDTH := 100000
const FRONT_EDGE := 7000
const UPPER_EDGE := 52000
const REAR_EDGE := 95000
const UPPER_FLOOR_Z := 12000
const LOWER_FLOOR_Z := 0
const COIN_RADIUS := 4300
const COIN_HEIGHT := 1700
const OBJECT_RADIUS := 5200
const OBJECT_HEIGHT := 2800
const GRAVITY := 560
const AIR_DRAG_NUM := 61
const AIR_DRAG_DEN := 64
const FLOOR_DRAG_NUM := 42
const FLOOR_DRAG_DEN := 64
const SLEEP_SPEED := 90
const SLEEP_TICKS := 8
const ACTION_TICKS := 48
const PRESENTATION_TRACE_INTERVAL_TICKS := 4
const PHASE_PERIOD := 12000
const TRAY_LEFT := 2000
const TRAY_RIGHT := 98000
const MAX_COLLISION_PASSES := 1
const BROADPHASE_CELL := 10000


static func public_contract() -> Dictionary:
	return {
		"schema": SCHEMA,
		"fixed_hz": FIXED_HZ,
		"fixed_point_scale": FP,
		"width": WIDTH,
		"front_edge": FRONT_EDGE,
		"upper_edge": UPPER_EDGE,
		"rear_edge": REAR_EDGE,
		"upper_floor_z": UPPER_FLOOR_Z,
		"lower_floor_z": LOWER_FLOOR_Z,
		"coin_radius": COIN_RADIUS,
		"coin_height": COIN_HEIGHT,
		"object_radius": OBJECT_RADIUS,
		"object_height": OBJECT_HEIGHT,
		"action_ticks": ACTION_TICKS,
		"phase_period": PHASE_PERIOD,
		"tray_left": TRAY_LEFT,
		"tray_right": TRAY_RIGHT,
	}


static func create(seed_rng: RngStream, coin_cap: int, opening_coins: int, lane_count: int) -> Dictionary:
	var state := {
		"schema": SCHEMA,
		"version": VERSION,
		"fixed_hz": FIXED_HZ,
		"fixed_point_scale": FP,
		"tick": 0,
		"next_body_id": 1,
		"coin_cap": maxi(32, coin_cap),
		"bodies": [],
		"upper_phase_fp": seed_rng.randi_range(0, PHASE_PERIOD - 1),
		"lower_phase_fp": seed_rng.randi_range(0, PHASE_PERIOD - 1),
		"last_events": [],
		"last_step_metrics": {},
	}
	_seed_opening_pile(state, seed_rng, mini(opening_coins, int(state["coin_cap"])), lane_count)
	return state


static func migrate_height_grid(source: Dictionary, seed_rng: RngStream, coin_cap: int, lane_count: int) -> Dictionary:
	var total := 0
	var lanes: Array = source.get("lanes", []) if typeof(source.get("lanes", [])) == TYPE_ARRAY else []
	for lane_value in lanes:
		if typeof(lane_value) != TYPE_DICTIONARY:
			continue
		for cell_value in (lane_value as Dictionary).get("cells", []):
			if typeof(cell_value) == TYPE_DICTIONARY:
				total += maxi(0, int((cell_value as Dictionary).get("height", 0)))
	return create(seed_rng, coin_cap, mini(total, coin_cap), lane_count)


static func add_coin(state: Dictionary, rng: RngStream, lane: int, lane_count: int, density: int = 1) -> Dictionary:
	if coin_count(state) >= maxi(1, int(state.get("coin_cap", 48))):
		_pressurize_full_pile(state, lane, lane_count)
	var lane_width := _divi(WIDTH, maxi(1, lane_count))
	var x := clampi(lane * lane_width + _divi(lane_width, 2) + rng.randi_range(-_divi(lane_width, 6), _divi(lane_width, 6)), COIN_RADIUS, WIDTH - COIN_RADIUS)
	var body := _body(state, "coin", x, REAR_EDGE - 3500, UPPER_FLOOR_Z + 12500, COIN_RADIUS, COIN_HEIGHT, maxi(1, density), {})
	body["vz"] = -900
	body["vy"] = -220 - maxi(0, density - 1) * 90
	(state["bodies"] as Array).append(body)
	return body


static func add_feature(state: Dictionary, kind: String, feature_id: String, lane: int, depth_milli: int, lane_count: int, metadata: Dictionary = {}) -> Dictionary:
	var lane_width := _divi(WIDTH, maxi(1, lane_count))
	var x := clampi(lane * lane_width + _divi(lane_width, 2), OBJECT_RADIUS, WIDTH - OBJECT_RADIUS)
	var y := clampi(depth_milli, FRONT_EDGE + OBJECT_RADIUS, REAR_EDGE - OBJECT_RADIUS)
	var base_z := UPPER_FLOOR_Z if y >= UPPER_EDGE else LOWER_FLOOR_Z
	var body_metadata := metadata.duplicate(true)
	body_metadata["feature_id"] = feature_id
	var body := _body(state, kind, x, y, base_z, OBJECT_RADIUS, OBJECT_HEIGHT, maxi(2, int(metadata.get("mass", 2))), body_metadata)
	(state["bodies"] as Array).append(body)
	return body


static func add_recovered_coin(state: Dictionary, rng: RngStream, lane_count: int) -> Dictionary:
	var lane := rng.randi_range(0, maxi(0, lane_count - 1))
	var lane_width := _divi(WIDTH, maxi(1, lane_count))
	var body := _body(state, "coin", lane * lane_width + _divi(lane_width, 2), UPPER_EDGE - 7000, LOWER_FLOOR_Z + 6000, COIN_RADIUS, COIN_HEIGHT, 1, {"shim_recovered": true})
	body["vy"] = -400
	body["vz"] = -600
	(state["bodies"] as Array).append(body)
	return body


static func step_action(state: Dictionary, config: Dictionary) -> Dictionary:
	# Presentation time is sampled only when the player commits an action. The
	# sampled fixed-point phases become explicit deterministic solver inputs.
	if config.has("captured_upper_phase_fp"):
		state["upper_phase_fp"] = posmod(int(config.get("captured_upper_phase_fp", 0)), PHASE_PERIOD)
	if config.has("captured_lower_phase_fp"):
		state["lower_phase_fp"] = posmod(int(config.get("captured_lower_phase_fp", 0)), PHASE_PERIOD)
	var events: Array = []
	var motion_events: Array = []
	var capture_trace := bool(config.get("capture_presentation_trace", false))
	var presentation_trace: Array = []
	var exit_trails: Array = []
	if capture_trace:
		presentation_trace.append(_presentation_trace_frame(state, 0, []))
	var start_positions := _positions_by_id(state)
	var nudge_x := int(config.get("nudge_x", 0))
	var nudge_y := int(config.get("nudge_y", 0))
	var aimed_x := int(config.get("aimed_x", _divi(WIDTH, 2)))
	var nudge_radius := maxi(COIN_RADIUS * 2, int(config.get("nudge_radius", WIDTH)))
	var push_scale := maxi(1, int(config.get("push_scale", 1)))
	var upper_locked := bool(config.get("upper_locked", false))
	var lower_locked := bool(config.get("lower_locked", false))
	var ridge_double := bool(config.get("ridge_double", false))
	var wake_count := 0
	var collision_count := 0
	if nudge_x != 0 or nudge_y != 0:
		wake_count += _apply_nudge(state, nudge_x, nudge_y, aimed_x, nudge_radius)
	for tick_index in range(ACTION_TICKS):
		var event_count_before := events.size()
		var old_upper := _pusher_face_y(int(state.get("upper_phase_fp", 0)), true)
		var old_lower := _pusher_face_y(int(state.get("lower_phase_fp", 0)), false)
		if not upper_locked:
			state["upper_phase_fp"] = posmod(int(state.get("upper_phase_fp", 0)) + 280 * (2 if ridge_double else 1), PHASE_PERIOD)
		if not lower_locked:
			state["lower_phase_fp"] = posmod(int(state.get("lower_phase_fp", 0)) + 360 * (2 if ridge_double else 1), PHASE_PERIOD)
		var new_upper := _pusher_face_y(int(state.get("upper_phase_fp", 0)), true)
		var new_lower := _pusher_face_y(int(state.get("lower_phase_fp", 0)), false)
		var woke_this_tick := _apply_pusher(state, old_upper, new_upper, true, push_scale)
		woke_this_tick += _apply_pusher(state, old_lower, new_lower, false, push_scale)
		wake_count += woke_this_tick
		if woke_this_tick > 0 or awake_count(state) > 0:
			_integrate(state, events, motion_events)
			var tick_buckets := _spatial_buckets(state.get("bodies", []) if typeof(state.get("bodies", [])) == TYPE_ARRAY else [])
			for _pass_index in range(MAX_COLLISION_PASSES):
				var resolved := _resolve_collisions(state, tick_buckets)
				collision_count += resolved
				if resolved <= 0:
					break
			_resolve_supports(state, tick_buckets, motion_events)
		state["tick"] = int(state.get("tick", 0)) + 1
		if capture_trace:
			for event_index in range(event_count_before, events.size()):
				exit_trails.append({"views": _presentation_exit_views(events[event_index]), "index": 0})
			if (tick_index + 1) % PRESENTATION_TRACE_INTERVAL_TICKS == 0 or tick_index + 1 == ACTION_TICKS:
				var exit_views: Array = []
				var remaining_trails: Array = []
				for trail_value in exit_trails:
					var trail: Dictionary = trail_value if typeof(trail_value) == TYPE_DICTIONARY else {}
					var views: Array = trail.get("views", []) if typeof(trail.get("views", [])) == TYPE_ARRAY else []
					var view_index := int(trail.get("index", 0))
					if view_index < views.size():
						exit_views.append(views[view_index])
						trail["index"] = view_index + 1
						if view_index + 1 < views.size():
							remaining_trails.append(trail)
				exit_trails = remaining_trails
				presentation_trace.append(_presentation_trace_frame(state, tick_index + 1, exit_views))
	var moved_count := 0
	for value in state.get("bodies", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = value
		var before: Array = start_positions.get(str(body.get("id", "")), [])
		if before.size() == 3 and (absi(int(before[0]) - int(body.get("x", 0))) > 180 or absi(int(before[1]) - int(body.get("y", 0))) > 180 or absi(int(before[2]) - int(body.get("z", 0))) > 180):
			moved_count += 1
	state["last_events"] = events
	state["last_motion_events"] = motion_events
	state["last_step_metrics"] = {
		"fixed_ticks": ACTION_TICKS,
		"body_count": (state.get("bodies", []) as Array).size(),
		"awake_count": awake_count(state),
		"woken_count": wake_count,
		"moved_count": moved_count,
		"collision_passes": MAX_COLLISION_PASSES,
		"collision_count": collision_count,
		"topple_count": _motion_event_count(motion_events, "topple"),
		"upper_lower_fall_count": _motion_event_count(motion_events, "upper_to_lower"),
	}
	return {
		"events": events,
		"motion_events": motion_events,
		"metrics": state["last_step_metrics"],
		"presentation_trace": presentation_trace,
	}


static func apply_nudge_only(state: Dictionary, x_impulse: int, y_impulse: int, aimed_x: int, radius: int) -> int:
	return _apply_nudge(state, x_impulse, y_impulse, aimed_x, radius)


static func body_views(state: Dictionary) -> Array:
	var result: Array = []
	for value in state.get("bodies", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = value
		result.append({
			"id": str(body.get("id", "")),
			"kind": str(body.get("kind", "coin")),
			"x": int(body.get("x", 0)),
			"y": int(body.get("y", 0)),
			"z": int(body.get("z", 0)),
			"radius": int(body.get("radius", COIN_RADIUS)),
			"height": int(body.get("height", COIN_HEIGHT)),
			"mass": int(body.get("mass", 1)),
			"sleeping": bool(body.get("sleeping", false)),
			"rest_state": str(body.get("rest_state", "settling")),
			"level": level_for_body(body),
			"lean_milli": int(body.get("lean_milli", 0)),
			"metadata": (body.get("metadata", {}) as Dictionary).duplicate(true) if typeof(body.get("metadata", {})) == TYPE_DICTIONARY else {},
		})
	return result


static func _presentation_trace_frame(state: Dictionary, tick_offset: int, exit_views: Array) -> Dictionary:
	var bodies := body_views(state)
	for exit_view in exit_views:
		bodies.append(exit_view)
	return {
		"tick_offset": tick_offset,
		"upper_phase_fp": int(state.get("upper_phase_fp", 0)),
		"lower_phase_fp": int(state.get("lower_phase_fp", 0)),
		"bodies": bodies,
	}


static func _presentation_exit_views(event_value: Variant) -> Array:
	var event: Dictionary = event_value if typeof(event_value) == TYPE_DICTIONARY else {}
	var first := {
		"id": str(event.get("body_id", "")),
		"kind": str(event.get("kind", "coin")),
		"x": int(event.get("x", 0)),
		"y": int(event.get("y", 0)),
		"z": int(event.get("z", 0)),
		"radius": COIN_RADIUS if str(event.get("kind", "coin")) == "coin" else OBJECT_RADIUS,
		"height": COIN_HEIGHT if str(event.get("kind", "coin")) == "coin" else OBJECT_HEIGHT,
		"mass": int(event.get("mass", 1)),
		"sleeping": false,
		"rest_state": "falling_%s" % str(event.get("outcome", "tray")),
		"lean_milli": 0,
		"metadata": (event.get("metadata", {}) as Dictionary).duplicate(true) if typeof(event.get("metadata", {})) == TYPE_DICTIONARY else {},
	}
	var second := first.duplicate(true)
	second["y"] = int(first.get("y", 0)) - 4500
	second["z"] = int(first.get("z", 0)) - 6000
	return [first, second]


static func coin_count(state: Dictionary) -> int:
	var count := 0
	for value in state.get("bodies", []):
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("kind", "")) == "coin":
			count += 1
	return count


static func awake_count(state: Dictionary) -> int:
	var count := 0
	for value in state.get("bodies", []):
		if typeof(value) == TYPE_DICTIONARY and not bool((value as Dictionary).get("sleeping", false)):
			count += 1
	return count


static func edge_hanger_count(state: Dictionary) -> int:
	var count := 0
	for value in state.get("bodies", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = value
		if int(body.get("y", FRONT_EDGE + COIN_RADIUS)) < FRONT_EDGE + int(body.get("radius", COIN_RADIUS)) and int(body.get("y", 0)) >= FRONT_EDGE:
			count += 1
	return count


static func level_for_body(body: Dictionary) -> String:
	var y := int(body.get("y", 0))
	var z := int(body.get("z", 0))
	if y >= UPPER_EDGE and z >= UPPER_FLOOR_Z:
		return "upper"
	if y >= FRONT_EDGE and z >= LOWER_FLOOR_Z:
		return "lower" if z < UPPER_FLOOR_Z else "falling"
	return "falling"


static func canonical_digest(state: Dictionary) -> Dictionary:
	var bodies: Array = []
	for view in body_views(state):
		var body: Dictionary = view
		bodies.append({
			"id": body.get("id", ""), "kind": body.get("kind", ""),
			"x": body.get("x", 0), "y": body.get("y", 0), "z": body.get("z", 0),
			"mass": body.get("mass", 1), "sleeping": body.get("sleeping", false),
			"rest_state": body.get("rest_state", ""), "metadata": body.get("metadata", {}),
		})
	return {
		"schema": str(state.get("schema", "")), "version": int(state.get("version", 0)),
		"fixed_hz": int(state.get("fixed_hz", 0)), "fixed_point_scale": int(state.get("fixed_point_scale", 0)),
		"tick": int(state.get("tick", 0)), "next_body_id": int(state.get("next_body_id", 0)),
		"coin_cap": int(state.get("coin_cap", 0)), "upper_phase_fp": int(state.get("upper_phase_fp", 0)),
		"lower_phase_fp": int(state.get("lower_phase_fp", 0)), "bodies": bodies,
	}


static func _seed_opening_pile(state: Dictionary, rng: RngStream, opening_coins: int, _lane_count: int) -> void:
	var stack_count := mini(8, maxi(0, opening_coins - 24))
	var base_count := opening_coins - stack_count
	var half := maxi(1, _divi(base_count + 1, 2))
	var column_width := _divi(WIDTH, 10)
	for index in range(opening_coins):
		var stacked := index >= base_count
		var source_index := index - base_count if stacked else index
		var upper := source_index >= half
		var local_index := source_index - half if upper else source_index
		var column := posmod(local_index, 10)
		var row := _divi(local_index, 10)
		var y_base := UPPER_EDGE + 8500 if upper else FRONT_EDGE + 8500
		var y := y_base + row * 10000 + (0 if stacked else rng.randi_range(-450, 450))
		var x := clampi(column * column_width + _divi(column_width, 2) + (600 if stacked else rng.randi_range(-450, 450)), COIN_RADIUS, WIDTH - COIN_RADIUS)
		var base_z := UPPER_FLOOR_Z if upper else LOWER_FLOOR_Z
		var body := _body(state, "coin", x, y, base_z + (COIN_HEIGHT if stacked else 0), COIN_RADIUS, COIN_HEIGHT, 1, {})
		body["sleeping"] = true
		body["sleep_ticks"] = SLEEP_TICKS
		body["rest_state"] = "resting"
		(state["bodies"] as Array).append(body)


static func _body(state: Dictionary, kind: String, x: int, y: int, z: int, radius: int, height: int, mass: int, metadata: Dictionary) -> Dictionary:
	var body_id := int(state.get("next_body_id", 1))
	state["next_body_id"] = body_id + 1
	return {
		"id": "body_%05d" % body_id,
		"kind": kind,
		"x": x, "y": y, "z": z,
		"vx": 0, "vy": 0, "vz": 0,
		"radius": radius, "height": height, "mass": maxi(1, mass),
		"sleep_ticks": 0, "sleeping": false, "rest_state": "settling", "lean_milli": 0,
		"metadata": metadata.duplicate(true),
	}


static func _pressurize_full_pile(state: Dictionary, lane: int, lane_count: int) -> void:
	var bodies: Array = state.get("bodies", []) if typeof(state.get("bodies", [])) == TYPE_ARRAY else []
	var lane_width := _divi(WIDTH, maxi(1, lane_count))
	var lane_center := lane * lane_width + _divi(lane_width, 2)
	var candidate: Dictionary = {}
	var candidate_key: Array = []
	for value in bodies:
		if typeof(value) != TYPE_DICTIONARY or str((value as Dictionary).get("kind", "")) != "coin":
			continue
		var body: Dictionary = value
		var key := [int(body.get("y", 0)), absi(int(body.get("x", 0)) - lane_center), str(body.get("id", ""))]
		if candidate.is_empty() or _key_before(key, candidate_key):
			candidate = body
			candidate_key = key
	if candidate.is_empty():
		return
	# The cabinet cannot accept a 49th coin. Compressing a full pile gives the
	# frontmost real coin enough physical momentum to traverse the remaining
	# ledge distance during this same 48-tick sweep; removal still occurs only
	# when integration observes the body crossing the tray/gutter boundary.
	var remaining_distance := maxi(0, int(candidate.get("y", 0)) - (FRONT_EDGE - int(candidate.get("radius", COIN_RADIUS))))
	var pressure_accel := maxi(12000, remaining_distance * 3 / 4)
	candidate["cap_pressure_ticks"] = ACTION_TICKS
	candidate["cap_pressure_accel"] = pressure_accel
	candidate["vy"] = mini(int(candidate.get("vy", 0)), -pressure_accel)
	var edge_bias := -16000 if lane == 0 else 16000 if lane == lane_count - 1 else 0
	candidate["vx"] = int(candidate.get("vx", 0)) + edge_bias
	_wake(candidate)


static func _apply_nudge(state: Dictionary, x_impulse: int, y_impulse: int, aimed_x: int, radius: int) -> int:
	var count := 0
	for value in state.get("bodies", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = value
		if absi(int(body.get("x", 0)) - aimed_x) > radius:
			continue
		var mass := maxi(1, int(body.get("mass", 1)))
		body["vx"] = int(body.get("vx", 0)) + _divi(x_impulse, mass)
		body["vy"] = int(body.get("vy", 0)) + _divi(y_impulse, mass)
		_wake(body)
		count += 1
	return count


static func _apply_pusher(state: Dictionary, old_face: int, new_face: int, upper: bool, push_scale: int) -> int:
	if new_face >= old_face:
		return 0
	var count := 0
	var floor_z := UPPER_FLOOR_Z if upper else LOWER_FLOOR_Z
	for value in state.get("bodies", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = value
		var y := int(body.get("y", 0))
		var z := int(body.get("z", 0))
		if upper != (y >= UPPER_EDGE and z >= UPPER_FLOOR_Z):
			continue
		if not upper and (y < FRONT_EDGE or y >= UPPER_EDGE or z >= UPPER_FLOOR_Z + COIN_HEIGHT):
			continue
		if y > new_face - int(body.get("radius", COIN_RADIUS)) and y < old_face + int(body.get("radius", COIN_RADIUS)) and z <= floor_z + int(body.get("height", COIN_HEIGHT)) * 5:
			body["y"] = mini(y, new_face - int(body.get("radius", COIN_RADIUS)))
			body["vy"] = int(body.get("vy", 0)) - (old_face - new_face) * push_scale
			_wake(body)
			count += 1
	return count


static func _integrate(state: Dictionary, events: Array, motion_events: Array) -> void:
	var bodies: Array = state.get("bodies", []) if typeof(state.get("bodies", [])) == TYPE_ARRAY else []
	var exit_indices: Array = []
	for body_index in range(bodies.size()):
		var value: Variant = bodies[body_index]
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = value
		if bool(body.get("sleeping", false)):
			continue
		var cap_pressure_ticks := maxi(0, int(body.get("cap_pressure_ticks", 0)))
		if cap_pressure_ticks > 0:
			body["vy"] = int(body.get("vy", 0)) - maxi(0, int(body.get("cap_pressure_accel", 0)))
			body["cap_pressure_ticks"] = cap_pressure_ticks - 1
		var was_upper := int(body.get("z", 0)) >= UPPER_FLOOR_Z
		body["vz"] = int(body.get("vz", 0)) - GRAVITY
		body["vx"] = _divi(int(body.get("vx", 0)) * AIR_DRAG_NUM, AIR_DRAG_DEN)
		body["vy"] = _divi(int(body.get("vy", 0)) * AIR_DRAG_NUM, AIR_DRAG_DEN)
		body["x"] = int(body.get("x", 0)) + _divi(int(body.get("vx", 0)), FIXED_HZ)
		body["y"] = int(body.get("y", 0)) + _divi(int(body.get("vy", 0)), FIXED_HZ)
		body["z"] = int(body.get("z", 0)) + _divi(int(body.get("vz", 0)), FIXED_HZ)
		var exit := _exit_kind(body)
		if not exit.is_empty():
			events.append(_exit_event(body, exit, "physical_fall"))
			exit_indices.append(body_index)
			continue
		var base_z := _floor_z(body)
		if was_upper and int(body.get("y", 0)) < UPPER_EDGE:
			motion_events.append({"kind": "upper_to_lower", "body_id": str(body.get("id", "")), "x": int(body.get("x", 0)), "y": int(body.get("y", 0)), "z": int(body.get("z", 0))})
		if int(body.get("z", 0)) <= base_z:
			body["z"] = base_z
			body["vz"] = 0
			body["vx"] = _divi(int(body.get("vx", 0)) * FLOOR_DRAG_NUM, FLOOR_DRAG_DEN)
			body["vy"] = _divi(int(body.get("vy", 0)) * FLOOR_DRAG_NUM, FLOOR_DRAG_DEN)
			_update_sleep(body)
		else:
			body["rest_state"] = "falling"
			body["sleep_ticks"] = 0
	for exit_index in range(exit_indices.size() - 1, -1, -1):
		bodies.remove_at(int(exit_indices[exit_index]))


static func _resolve_collisions(state: Dictionary, buckets: Dictionary) -> int:
	var bodies: Array = state.get("bodies", []) if typeof(state.get("bodies", [])) == TYPE_ARRAY else []
	var awake_indices := PackedInt32Array()
	for index in range(bodies.size()):
		if typeof(bodies[index]) == TYPE_DICTIONARY and not bool((bodies[index] as Dictionary).get("sleeping", false)):
			awake_indices.append(index)
	if awake_indices.is_empty():
		return 0
	var visited_pairs := PackedByteArray()
	visited_pairs.resize(bodies.size() * bodies.size())
	var resolved := 0
	for left_index_value in awake_indices:
		var left_index := int(left_index_value)
		var left: Dictionary = bodies[left_index]
		var center_x := _divi(int(left.get("x", 0)), BROADPHASE_CELL)
		var center_y := _divi(int(left.get("y", 0)), BROADPHASE_CELL)
		var center_z := _divi(int(left.get("z", 0)), BROADPHASE_CELL)
		for z_offset in range(-1, 2):
			for y_offset in range(-1, 2):
				for x_offset in range(-1, 2):
					var bucket_value: Variant = buckets.get(_bucket_key(center_x + x_offset, center_y + y_offset, center_z + z_offset), null)
					if typeof(bucket_value) != TYPE_ARRAY:
						continue
					for right_index_value in bucket_value as Array:
						var right_index := int(right_index_value)
						if right_index == left_index:
							continue
						var low := mini(left_index, right_index)
						var high := maxi(left_index, right_index)
						var pair_key := low * bodies.size() + high
						if visited_pairs[pair_key] != 0:
							continue
						visited_pairs[pair_key] = 1
						if typeof(bodies[right_index]) != TYPE_DICTIONARY:
							continue
						var right: Dictionary = bodies[right_index]
						var dx := int(right.get("x", 0)) - int(left.get("x", 0))
						var dy := int(right.get("y", 0)) - int(left.get("y", 0))
						var min_distance := int(left.get("radius", COIN_RADIUS)) + int(right.get("radius", COIN_RADIUS))
						if absi(dx) >= min_distance or absi(dy) >= min_distance or dx * dx + dy * dy >= min_distance * min_distance:
							continue
						var z_gap := absi(int(left.get("z", 0)) - int(right.get("z", 0)))
						if z_gap >= mini(int(left.get("height", COIN_HEIGHT)), int(right.get("height", COIN_HEIGHT))):
							continue
						var overlap := min_distance - maxi(absi(dx), absi(dy))
						if overlap <= 0:
							continue
						if absi(dx) >= absi(dy):
							var sign_x := 1 if dx >= 0 else -1
							right["x"] = int(right.get("x", 0)) + _divi(sign_x * overlap, 2)
							left["x"] = int(left.get("x", 0)) - _divi(sign_x * overlap, 2)
							right["vx"] = int(right.get("vx", 0)) + sign_x * overlap * 5
							left["vx"] = int(left.get("vx", 0)) - sign_x * overlap * 5
						else:
							var sign_y := 1 if dy >= 0 else -1
							right["y"] = int(right.get("y", 0)) + _divi(sign_y * overlap, 2)
							left["y"] = int(left.get("y", 0)) - _divi(sign_y * overlap, 2)
							right["vy"] = int(right.get("vy", 0)) + sign_y * overlap * 5
							left["vy"] = int(left.get("vy", 0)) - sign_y * overlap * 5
						_wake(left)
						_wake(right)
						resolved += 1
	return resolved


static func _resolve_supports(state: Dictionary, buckets: Dictionary, motion_events: Array) -> void:
	var bodies: Array = state.get("bodies", []) if typeof(state.get("bodies", [])) == TYPE_ARRAY else []
	for value in bodies:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = value
		if bool(body.get("sleeping", false)):
			continue
		var base_z := _floor_z(body)
		if int(body.get("z", 0)) <= base_z:
			body["lean_milli"] = 0
			continue
		var support: Dictionary = {}
		var support_distance := 1 << 30
		var center_x := _divi(int(body.get("x", 0)), BROADPHASE_CELL)
		var center_y := _divi(int(body.get("y", 0)), BROADPHASE_CELL)
		var center_z := _divi(int(body.get("z", 0)), BROADPHASE_CELL)
		for z_offset in range(-1, 2):
			for y_offset in range(-1, 2):
				for x_offset in range(-1, 2):
					var bucket_value: Variant = buckets.get(_bucket_key(center_x + x_offset, center_y + y_offset, center_z + z_offset), null)
					if typeof(bucket_value) != TYPE_ARRAY:
						continue
					for candidate_index_value in bucket_value as Array:
						var candidate_index := int(candidate_index_value)
						if candidate_index < 0 or candidate_index >= bodies.size() or bodies[candidate_index] == value or typeof(bodies[candidate_index]) != TYPE_DICTIONARY:
							continue
						var candidate: Dictionary = bodies[candidate_index]
						var target_z := int(candidate.get("z", 0)) + int(candidate.get("height", COIN_HEIGHT))
						if target_z > int(body.get("z", 0)) + COIN_HEIGHT or target_z < int(body.get("z", 0)) - COIN_HEIGHT * 2:
							continue
						var dx := int(body.get("x", 0)) - int(candidate.get("x", 0))
						var dy := int(body.get("y", 0)) - int(candidate.get("y", 0))
						var distance := dx * dx + dy * dy
						var support_radius := mini(int(body.get("radius", COIN_RADIUS)), int(candidate.get("radius", COIN_RADIUS)))
						if distance < support_radius * support_radius and distance < support_distance:
							support = candidate
							support_distance = distance
		if support.is_empty():
			body["rest_state"] = "falling"
			body["sleeping"] = false
			continue
		var target_z := int(support.get("z", 0)) + int(support.get("height", COIN_HEIGHT))
		if int(body.get("vz", 0)) <= 0 and int(body.get("z", 0)) <= target_z + COIN_HEIGHT:
			body["z"] = target_z
			body["vz"] = 0
			var dx := int(body.get("x", 0)) - int(support.get("x", 0))
			var dy := int(body.get("y", 0)) - int(support.get("y", 0))
			var lean := _divi(maxi(absi(dx), absi(dy)) * FP, maxi(1, int(body.get("radius", COIN_RADIUS))))
			body["lean_milli"] = lean
			if lean > 620:
				if not _motion_event_has_body(motion_events, "topple", str(body.get("id", ""))):
					motion_events.append({"kind": "topple", "body_id": str(body.get("id", "")), "support_id": str(support.get("id", "")), "lean_milli": lean})
				body["vx"] = int(body.get("vx", 0)) + (120 if dx >= 0 else -120)
				body["vy"] = int(body.get("vy", 0)) + (120 if dy >= 0 else -120)
				body["z"] = target_z + 80
				body["rest_state"] = "toppling"
				body["sleeping"] = false
			else:
				_update_sleep(body)


static func _update_sleep(body: Dictionary) -> void:
	var speed := absi(int(body.get("vx", 0))) + absi(int(body.get("vy", 0))) + absi(int(body.get("vz", 0)))
	if speed <= SLEEP_SPEED:
		body["sleep_ticks"] = int(body.get("sleep_ticks", 0)) + 1
		if int(body.get("sleep_ticks", 0)) >= SLEEP_TICKS:
			body["vx"] = 0
			body["vy"] = 0
			body["vz"] = 0
			body["sleeping"] = true
			body["rest_state"] = "resting"
	else:
		body["sleep_ticks"] = 0
		body["rest_state"] = "settling"


static func _wake(body: Dictionary) -> void:
	body["sleeping"] = false
	body["sleep_ticks"] = 0
	body["rest_state"] = "settling"


static func _floor_z(body: Dictionary) -> int:
	return UPPER_FLOOR_Z if int(body.get("y", 0)) >= UPPER_EDGE else LOWER_FLOOR_Z


static func _exit_kind(body: Dictionary) -> String:
	var x := int(body.get("x", 0))
	var y := int(body.get("y", 0))
	var radius := int(body.get("radius", COIN_RADIUS))
	if x < -radius or x > WIDTH + radius:
		return "gutter"
	if y >= FRONT_EDGE - radius:
		return ""
	return "tray" if x >= TRAY_LEFT and x <= TRAY_RIGHT else "gutter"


static func _exit_event(body: Dictionary, outcome: String, cause: String) -> Dictionary:
	return {
		"body_id": str(body.get("id", "")), "kind": str(body.get("kind", "coin")),
		"outcome": outcome, "cause": cause,
		"x": int(body.get("x", 0)), "y": int(body.get("y", 0)), "z": int(body.get("z", 0)),
		"mass": int(body.get("mass", 1)),
		"metadata": (body.get("metadata", {}) as Dictionary).duplicate(true) if typeof(body.get("metadata", {})) == TYPE_DICTIONARY else {},
	}


static func _positions_by_id(state: Dictionary) -> Dictionary:
	var result := {}
	for value in state.get("bodies", []):
		if typeof(value) == TYPE_DICTIONARY:
			var body: Dictionary = value
			result[str(body.get("id", ""))] = [int(body.get("x", 0)), int(body.get("y", 0)), int(body.get("z", 0))]
	return result


static func _motion_event_count(events: Array, kind: String) -> int:
	var count := 0
	for value in events:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("kind", "")) == kind:
			count += 1
	return count


static func _motion_event_has_body(events: Array, kind: String, body_id: String) -> bool:
	for value in events:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("kind", "")) == kind and str((value as Dictionary).get("body_id", "")) == body_id:
			return true
	return false


static func _spatial_buckets(bodies: Array) -> Dictionary:
	var result := {}
	for index in range(bodies.size()):
		if typeof(bodies[index]) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = bodies[index]
		var key := _bucket_key(_divi(int(body.get("x", 0)), BROADPHASE_CELL), _divi(int(body.get("y", 0)), BROADPHASE_CELL), _divi(int(body.get("z", 0)), BROADPHASE_CELL))
		if result.has(key):
			(result[key] as Array).append(index)
		else:
			result[key] = [index]
	return result


static func _bucket_key(x: int, y: int, z: int) -> int:
	return (x + 32) + (y + 32) * 128 + (z + 32) * 16384


static func _key_before(left: Array, right: Array) -> bool:
	if right.is_empty():
		return true
	for index in range(mini(left.size(), right.size())):
		if left[index] == right[index]:
			continue
		return left[index] < right[index]
	return left.size() < right.size()


static func _pusher_face_y(phase_fp: int, upper: bool) -> int:
	var half := _divi(PHASE_PERIOD, 2)
	var folded := phase_fp if phase_fp <= half else PHASE_PERIOD - phase_fp
	var travel := 24000 if upper else 18000
	var rear := REAR_EDGE - 3000 if upper else UPPER_EDGE - 3000
	return rear - _divi(folded * travel, half)


static func _divi(numerator: int, denominator: int) -> int:
	if denominator == 0:
		return 0
	return int(numerator / denominator)
