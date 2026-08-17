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
	_normalize_hot_body_fields(state)
	if config.has("captured_upper_phase_fp"):
		state["upper_phase_fp"] = posmod(int(config.get("captured_upper_phase_fp", 0)), PHASE_PERIOD)
	if config.has("captured_lower_phase_fp"):
		state["lower_phase_fp"] = posmod(int(config.get("captured_lower_phase_fp", 0)), PHASE_PERIOD)
	var events: Array = []
	var motion_events: Array = []
	var motion_event_keys := {}
	var capture_trace := bool(config.get("capture_presentation_trace", false))
	var emit_presentation_events := bool(config.get("emit_presentation_events", true))
	var presentation_trace: Array = []
	var exit_trails: Array = []
	if capture_trace:
		presentation_trace.append(_presentation_trace_frame(state, 0, []))
	var start_positions := _positions_by_id(state)
	var peak_z_by_id := _peak_z_by_id(state) if emit_presentation_events else {}
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
	var collision_visited := PackedInt32Array()
	var starting_body_count := (state.get("bodies", []) as Array).size()
	collision_visited.resize(starting_body_count * starting_body_count)
	var cached_spatial_keys := PackedInt32Array()
	var cached_spatial_buckets := {}
	var cached_neighbor_indices := {}
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
		var integration_indices := PackedInt32Array()
		var woke_this_tick := _apply_pushers(state, old_upper, new_upper, old_lower, new_lower, push_scale, integration_indices)
		wake_count += woke_this_tick
		if not integration_indices.is_empty():
			_integrate(state, integration_indices, events, motion_events, motion_event_keys, peak_z_by_id, tick_index + 1)
			var awake_indices := PackedInt32Array()
			var bodies: Array = state.get("bodies", []) if typeof(state.get("bodies", [])) == TYPE_ARRAY else []
			var spatial_keys := _spatial_keys(bodies, awake_indices)
			if spatial_keys != cached_spatial_keys:
				cached_spatial_keys = spatial_keys
				cached_spatial_buckets = _spatial_buckets(spatial_keys)
				cached_neighbor_indices = {}
			var support_indices := awake_indices.duplicate()
			var support_seen := PackedByteArray()
			support_seen.resize(bodies.size())
			for awake_index in awake_indices:
				support_seen[int(awake_index)] = 1
			for _pass_index in range(MAX_COLLISION_PASSES):
				var visit_generation := tick_index * MAX_COLLISION_PASSES + _pass_index + 1
				var resolved := _resolve_collisions(state, cached_spatial_buckets, collision_visited, visit_generation, awake_indices, cached_neighbor_indices, support_indices, support_seen)
				collision_count += resolved
				if resolved <= 0:
					break
			support_indices.sort()
			_resolve_supports(state, cached_spatial_buckets, cached_neighbor_indices, support_indices, motion_events, motion_event_keys, peak_z_by_id, tick_index + 1)
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
	var presentation_events := _presentation_event_views(state, events, motion_events, state["last_step_metrics"], config) if emit_presentation_events else []
	return {
		"events": events,
		"motion_events": motion_events,
		"presentation_events": presentation_events,
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
			"material_category": _presentation_material_category(body),
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
	result.sort_custom(_body_view_depth_before)
	return result


static func _presentation_trace_frame(state: Dictionary, tick_offset: int, exit_views: Array) -> Dictionary:
	var bodies := body_views(state)
	# body_views() already returns the stable depth order used by presentation.
	# Only exits can disturb it, so avoid sorting all 150-160 bodies again on
	# the overwhelmingly common frames that have no exiting body.
	if not exit_views.is_empty():
		for exit_view in exit_views:
			bodies.append(exit_view)
		bodies.sort_custom(_body_view_depth_before)
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
		"material_category": "coin" if str(event.get("kind", "coin")) == "coin" else "physical_object",
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


static func _body_view_depth_before(left_value: Variant, right_value: Variant) -> bool:
	var left: Dictionary = left_value if typeof(left_value) == TYPE_DICTIONARY else {}
	var right: Dictionary = right_value if typeof(right_value) == TYPE_DICTIONARY else {}
	var left_depth := int(left.get("y", 0)) * 10 - int(left.get("z", 0))
	var right_depth := int(right.get("y", 0)) * 10 - int(right.get("z", 0))
	if left_depth == right_depth:
		return str(left.get("id", "")) < str(right.get("id", ""))
	return left_depth > right_depth


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
	# Best-candidate sampling gives each seeded cabinet a natural, compressed
	# field without reintroducing the old lane/height-grid model. It is performed
	# once at generation time and consumes only the run-scoped RNG.
	var shelf_specs := [
		{"min_y": 8500, "max_y": 48500, "upper": false},
		{"min_y": 55000, "max_y": 92500, "upper": true},
	]
	var base_target := mini(opening_coins, 110)
	var base_bodies: Array = []
	for shelf_index in range(shelf_specs.size()):
		var shelf: Dictionary = shelf_specs[shelf_index]
		var count := base_target / shelf_specs.size()
		if shelf_index < base_target % shelf_specs.size():
			count += 1
		var shelf_bodies: Array = []
		for _coin_index in range(count):
			var candidate := _opening_best_candidate(rng, shelf, shelf_bodies)
			var base_z := UPPER_FLOOR_Z if bool(shelf.get("upper", false)) else LOWER_FLOOR_Z
			var body := _body(state, "coin", candidate.x, candidate.y, base_z, COIN_RADIUS, COIN_HEIGHT, 1, {"opening_pile": true})
			_set_opening_body_rest(body)
			(state["bodies"] as Array).append(body)
			base_bodies.append(body)
			shelf_bodies.append(body)
	var stack_layers := {}
	while (state["bodies"] as Array).size() < opening_coins and not base_bodies.is_empty():
		var candidates: Array = []
		for base_value in base_bodies:
			var base: Dictionary = base_value
			var base_id := str(base.get("id", ""))
			var layers := int(stack_layers.get(base_id, 0))
			var y := int(base.get("y", 0))
			if layers < 2 and (y >= 26000 and y < UPPER_EDGE or y >= 72000):
				candidates.append(base)
		if candidates.is_empty():
			break
		var support: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
		var support_id := str(support.get("id", ""))
		var layer := int(stack_layers.get(support_id, 0)) + 1
		stack_layers[support_id] = layer
		var lean_x := rng.randi_range(-1900, 1900)
		var lean_y := rng.randi_range(-1450, 1450)
		var stacked := _body(
			state,
			"coin",
			clampi(int(support.get("x", 0)) + lean_x, COIN_RADIUS, WIDTH - COIN_RADIUS),
			int(support.get("y", 0)) + lean_y,
			int(support.get("z", 0)) + layer * COIN_HEIGHT,
			COIN_RADIUS,
			COIN_HEIGHT,
			1,
			{"opening_pile": true, "opening_stack_layer": layer}
		)
		stacked["lean_milli"] = _divi(maxi(absi(lean_x), absi(lean_y)) * FP, COIN_RADIUS)
		_set_opening_body_rest(stacked)
		(state["bodies"] as Array).append(stacked)


static func _opening_best_candidate(rng: RngStream, shelf: Dictionary, existing: Array) -> Vector2i:
	var best := Vector2i(WIDTH / 2, int(shelf.get("min_y", FRONT_EDGE)))
	var best_nearest_distance := -1
	for _attempt in range(16):
		var candidate := Vector2i(
			rng.randi_range(COIN_RADIUS, WIDTH - COIN_RADIUS),
			rng.randi_range(int(shelf.get("min_y", FRONT_EDGE)), int(shelf.get("max_y", UPPER_EDGE - COIN_RADIUS)))
		)
		var nearest_distance := 1 << 62
		for value in existing:
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var body: Dictionary = value
			var dx := candidate.x - int(body.get("x", 0))
			var dy := candidate.y - int(body.get("y", 0))
			nearest_distance = mini(nearest_distance, dx * dx + dy * dy)
		if existing.is_empty():
			nearest_distance = 1 << 61
		if nearest_distance > best_nearest_distance:
			best_nearest_distance = nearest_distance
			best = candidate
	return best


static func _set_opening_body_rest(body: Dictionary) -> void:
	body["sleeping"] = true
	body["sleep_ticks"] = SLEEP_TICKS
	body["rest_state"] = "resting"


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
		if absi(int(body["x"]) - aimed_x) > radius:
			continue
		var mass := maxi(1, int(body["mass"]))
		body["vx"] = int(body["vx"]) + _divi(x_impulse, mass)
		body["vy"] = int(body["vy"]) + _divi(y_impulse, mass)
		_wake(body)
		count += 1
	return count


static func _apply_pushers(state: Dictionary, old_upper: int, new_upper: int, old_lower: int, new_lower: int, push_scale: int, active_indices: PackedInt32Array) -> int:
	var upper_active := new_upper < old_upper
	var lower_active := new_lower < old_lower
	var count := 0
	var bodies: Array = state.get("bodies", []) if typeof(state.get("bodies", [])) == TYPE_ARRAY else []
	for body_index in range(bodies.size()):
		var value: Variant = bodies[body_index]
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = value
		var y := int(body["y"])
		var z := int(body["z"])
		var upper := y >= UPPER_EDGE and z >= UPPER_FLOOR_Z
		var active := upper_active if upper else lower_active
		var old_face := old_upper if upper else old_lower
		var new_face := new_upper if upper else new_lower
		var floor_z := UPPER_FLOOR_Z if upper else LOWER_FLOOR_Z
		var eligible := active and (upper or (y >= FRONT_EDGE and y < UPPER_EDGE and z < UPPER_FLOOR_Z + COIN_HEIGHT))
		var radius := int(body["radius"])
		if eligible and y > new_face - radius and y < old_face + radius and z <= floor_z + int(body["height"]) * 5:
			body["y"] = mini(y, new_face - radius)
			body["vy"] = int(body["vy"]) - (old_face - new_face) * push_scale
			_wake(body)
			count += 1
		if not bool(body["sleeping"]):
			active_indices.append(body_index)
	return count


static func _integrate(state: Dictionary, active_indices: PackedInt32Array, events: Array, motion_events: Array, motion_event_keys: Dictionary, peak_z_by_id: Dictionary, tick_offset: int) -> void:
	var bodies: Array = state.get("bodies", []) if typeof(state.get("bodies", [])) == TYPE_ARRAY else []
	var exit_indices: Array = []
	for body_index_value in active_indices:
		var body_index := int(body_index_value)
		if body_index < 0 or body_index >= bodies.size():
			continue
		var value: Variant = bodies[body_index]
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = value
		var body_id := str(body["id"])
		var previous_z := int(body["z"])
		if not peak_z_by_id.is_empty():
			peak_z_by_id[body_id] = maxi(int(peak_z_by_id.get(body_id, previous_z)), previous_z)
		var cap_pressure_ticks := maxi(0, int(body.get("cap_pressure_ticks", 0)))
		if cap_pressure_ticks > 0:
			body["vy"] = int(body["vy"]) - maxi(0, int(body.get("cap_pressure_accel", 0)))
			body["cap_pressure_ticks"] = cap_pressure_ticks - 1
		var was_upper := int(body["z"]) >= UPPER_FLOOR_Z
		body["vz"] = int(body["vz"]) - GRAVITY
		body["vx"] = _divi(int(body["vx"]) * AIR_DRAG_NUM, AIR_DRAG_DEN)
		body["vy"] = _divi(int(body["vy"]) * AIR_DRAG_NUM, AIR_DRAG_DEN)
		body["x"] = int(body["x"]) + _divi(int(body["vx"]), FIXED_HZ)
		body["y"] = int(body["y"]) + _divi(int(body["vy"]), FIXED_HZ)
		body["z"] = int(body["z"]) + _divi(int(body["vz"]), FIXED_HZ)
		var exit := _exit_kind(body)
		if not exit.is_empty():
			events.append(_exit_event(body, exit, "physical_fall", tick_offset))
			exit_indices.append(body_index)
			continue
		var base_z := _floor_z(body)
		if was_upper and int(body["y"]) < UPPER_EDGE:
			motion_events.append({"kind": "upper_to_lower", "body_id": str(body["id"]), "x": int(body["x"]), "y": int(body["y"]), "z": int(body["z"]), "tick_offset": tick_offset})
		if int(body["z"]) <= base_z:
			var fall_height := maxi(0, int(peak_z_by_id.get(body_id, previous_z)) - base_z)
			if not peak_z_by_id.is_empty() and previous_z > base_z and fall_height > 0:
				_append_impact_motion_event(motion_events, motion_event_keys, body, "coin_on_metal", 0, fall_height, tick_offset)
			body["z"] = base_z
			body["vz"] = 0
			body["vx"] = _divi(int(body["vx"]) * FLOOR_DRAG_NUM, FLOOR_DRAG_DEN)
			body["vy"] = _divi(int(body["vy"]) * FLOOR_DRAG_NUM, FLOOR_DRAG_DEN)
			_update_sleep(body)
		else:
			body["rest_state"] = "falling"
			body["sleep_ticks"] = 0
	for exit_index in range(exit_indices.size() - 1, -1, -1):
		bodies.remove_at(int(exit_indices[exit_index]))


static func _resolve_collisions(state: Dictionary, buckets: Dictionary, visited_pairs: PackedInt32Array, visit_generation: int, awake_indices: PackedInt32Array, neighbor_cache: Dictionary, support_indices: PackedInt32Array, support_seen: PackedByteArray) -> int:
	var bodies: Array = state.get("bodies", []) if typeof(state.get("bodies", [])) == TYPE_ARRAY else []
	if awake_indices.is_empty():
		return 0
	var resolved := 0
	for left_index_value in awake_indices:
		var left_index := int(left_index_value)
		var left: Dictionary = bodies[left_index]
		var center_x := _divi(int(left["x"]), BROADPHASE_CELL)
		var center_y := _divi(int(left["y"]), BROADPHASE_CELL)
		var center_z := _divi(int(left["z"]), BROADPHASE_CELL)
		for right_index_value in _neighbor_indices(buckets, neighbor_cache, center_x, center_y, center_z):
			var right_index := int(right_index_value)
			if right_index == left_index:
				continue
			var low := mini(left_index, right_index)
			var high := maxi(left_index, right_index)
			var pair_key := low * bodies.size() + high
			if visited_pairs[pair_key] == visit_generation:
				continue
			visited_pairs[pair_key] = visit_generation
			if typeof(bodies[right_index]) != TYPE_DICTIONARY:
				continue
			var right: Dictionary = bodies[right_index]
			var dx := int(right["x"]) - int(left["x"])
			var dy := int(right["y"]) - int(left["y"])
			var min_distance := int(left["radius"]) + int(right["radius"])
			if absi(dx) >= min_distance or absi(dy) >= min_distance or dx * dx + dy * dy >= min_distance * min_distance:
				continue
			var z_gap := absi(int(left["z"]) - int(right["z"]))
			if z_gap >= mini(int(left["height"]), int(right["height"])):
				continue
			var overlap := min_distance - maxi(absi(dx), absi(dy))
			if overlap <= 0:
				continue
			if absi(dx) >= absi(dy):
				var sign_x := 1 if dx >= 0 else -1
				right["x"] = int(right["x"]) + _divi(sign_x * overlap, 2)
				left["x"] = int(left["x"]) - _divi(sign_x * overlap, 2)
				right["vx"] = int(right["vx"]) + sign_x * overlap * 5
				left["vx"] = int(left["vx"]) - sign_x * overlap * 5
			else:
				var sign_y := 1 if dy >= 0 else -1
				right["y"] = int(right["y"]) + _divi(sign_y * overlap, 2)
				left["y"] = int(left["y"]) - _divi(sign_y * overlap, 2)
				right["vy"] = int(right["vy"]) + sign_y * overlap * 5
				left["vy"] = int(left["vy"]) - sign_y * overlap * 5
			if bool(right["sleeping"]) and support_seen[right_index] == 0:
				support_seen[right_index] = 1
				support_indices.append(right_index)
			_wake(left)
			_wake(right)
			resolved += 1
	return resolved


static func _resolve_supports(state: Dictionary, buckets: Dictionary, neighbor_cache: Dictionary, active_indices: PackedInt32Array, motion_events: Array, motion_event_keys: Dictionary, peak_z_by_id: Dictionary, tick_offset: int) -> void:
	var bodies: Array = state.get("bodies", []) if typeof(state.get("bodies", [])) == TYPE_ARRAY else []
	for body_index_value in active_indices:
		var body_index := int(body_index_value)
		if body_index < 0 or body_index >= bodies.size():
			continue
		var value: Variant = bodies[body_index]
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = value
		var base_z := _floor_z(body)
		if int(body["z"]) <= base_z:
			body["lean_milli"] = 0
			continue
		var support: Dictionary = {}
		var support_distance := 1 << 30
		var center_x := _divi(int(body["x"]), BROADPHASE_CELL)
		var center_y := _divi(int(body["y"]), BROADPHASE_CELL)
		var center_z := _divi(int(body["z"]), BROADPHASE_CELL)
		for candidate_index_value in _neighbor_indices(buckets, neighbor_cache, center_x, center_y, center_z):
			var candidate_index := int(candidate_index_value)
			if candidate_index < 0 or candidate_index >= bodies.size() or bodies[candidate_index] == value or typeof(bodies[candidate_index]) != TYPE_DICTIONARY:
				continue
			var candidate: Dictionary = bodies[candidate_index]
			var target_z := int(candidate["z"]) + int(candidate["height"])
			if target_z > int(body["z"]) + COIN_HEIGHT or target_z < int(body["z"]) - COIN_HEIGHT * 2:
				continue
			var dx := int(body["x"]) - int(candidate["x"])
			var dy := int(body["y"]) - int(candidate["y"])
			var distance := dx * dx + dy * dy
			var support_radius := mini(int(body["radius"]), int(candidate["radius"]))
			if distance < support_radius * support_radius and distance < support_distance:
				support = candidate
				support_distance = distance
		if support.is_empty():
			body["rest_state"] = "falling"
			body["sleeping"] = false
			continue
		var target_z := int(support["z"]) + int(support["height"])
		if int(body["vz"]) <= 0 and int(body["z"]) <= target_z + COIN_HEIGHT:
			var fall_height := maxi(0, int(peak_z_by_id.get(str(body["id"]), int(body["z"]))) - target_z)
			if not peak_z_by_id.is_empty() and fall_height > 0:
				var stack_depth := maxi(1, _divi(target_z - _floor_z(body), COIN_HEIGHT))
				_append_impact_motion_event(motion_events, motion_event_keys, body, "coin_on_coin", stack_depth, fall_height, tick_offset)
			body["z"] = target_z
			body["vz"] = 0
			var dx := int(body["x"]) - int(support["x"])
			var dy := int(body["y"]) - int(support["y"])
			var lean := _divi(maxi(absi(dx), absi(dy)) * FP, maxi(1, int(body["radius"])))
			body["lean_milli"] = lean
			if lean > 620:
				var topple_key := "topple|%s" % str(body["id"])
				if not motion_event_keys.has(topple_key):
					motion_events.append({"kind": "topple", "body_id": str(body["id"]), "support_id": str(support["id"]), "lean_milli": lean})
					motion_event_keys[topple_key] = true
				body["vx"] = int(body["vx"]) + (120 if dx >= 0 else -120)
				body["vy"] = int(body["vy"]) + (120 if dy >= 0 else -120)
				body["z"] = target_z + 80
				body["rest_state"] = "toppling"
				body["sleeping"] = false
			else:
				_update_sleep(body)


static func _update_sleep(body: Dictionary) -> void:
	var speed := absi(int(body["vx"])) + absi(int(body["vy"])) + absi(int(body["vz"]))
	if speed <= SLEEP_SPEED:
		body["sleep_ticks"] = int(body["sleep_ticks"]) + 1
		if int(body["sleep_ticks"]) >= SLEEP_TICKS:
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
	return UPPER_FLOOR_Z if int(body["y"]) >= UPPER_EDGE else LOWER_FLOOR_Z


static func _exit_kind(body: Dictionary) -> String:
	var x := int(body.get("x", 0))
	var y := int(body.get("y", 0))
	var radius := int(body.get("radius", COIN_RADIUS))
	if x < -radius or x > WIDTH + radius:
		return "gutter"
	if y >= FRONT_EDGE - radius:
		return ""
	return "tray" if x >= TRAY_LEFT and x <= TRAY_RIGHT else "gutter"


static func _exit_event(body: Dictionary, outcome: String, cause: String, tick_offset: int = ACTION_TICKS) -> Dictionary:
	return {
		"body_id": str(body.get("id", "")), "kind": str(body.get("kind", "coin")),
		"outcome": outcome, "cause": cause,
		"x": int(body.get("x", 0)), "y": int(body.get("y", 0)), "z": int(body.get("z", 0)),
		"mass": int(body.get("mass", 1)),
		"tick_offset": tick_offset,
		"metadata": (body.get("metadata", {}) as Dictionary).duplicate(true) if typeof(body.get("metadata", {})) == TYPE_DICTIONARY else {},
	}


static func _normalize_hot_body_fields(state: Dictionary) -> void:
	var bodies: Array = state.get("bodies", []) if typeof(state.get("bodies", [])) == TYPE_ARRAY else []
	for body_value in bodies:
		if typeof(body_value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = body_value
		if not body.has("id"):
			body["id"] = ""
		if not body.has("x"):
			body["x"] = 0
		if not body.has("y"):
			body["y"] = 0
		if not body.has("z"):
			body["z"] = 0
		if not body.has("vx"):
			body["vx"] = 0
		if not body.has("vy"):
			body["vy"] = 0
		if not body.has("vz"):
			body["vz"] = 0
		if not body.has("radius"):
			body["radius"] = COIN_RADIUS
		if not body.has("height"):
			body["height"] = COIN_HEIGHT
		if not body.has("mass"):
			body["mass"] = 1
		if not body.has("sleep_ticks"):
			body["sleep_ticks"] = 0
		if not body.has("sleeping"):
			body["sleeping"] = false


static func _presentation_event_views(state: Dictionary, exits: Array, motion_events: Array, metrics: Dictionary, config: Dictionary) -> Array:
	var result: Array = []
	var focus := _presentation_focus_body(state)
	var moved_count := int(metrics.get("moved_count", 0))
	if moved_count > 1:
		result.append(_presentation_event("slide", focus, mini(1000, 180 + moved_count * 24), ACTION_TICKS / 2, {"moved_count": moved_count}))
	for motion_value in motion_events:
		if typeof(motion_value) != TYPE_DICTIONARY:
			continue
		var motion: Dictionary = motion_value
		var kind := str(motion.get("kind", ""))
		var body := _presentation_body_by_id(state, str(motion.get("body_id", "")))
		if body.is_empty():
			body = motion
		var intensity := 720 if kind == "topple" else 820
		if kind == "impact":
			intensity = mini(1000, 320 + int(motion.get("fall_height_milli", 0)) / 8 + int(motion.get("stack_depth", 0)) * 70)
		result.append(_presentation_event(kind, body, intensity, int(motion.get("tick_offset", ACTION_TICKS / 2)), motion))
	var outcome_totals := {"tray": 0, "gutter": 0}
	for exit_value in exits:
		if typeof(exit_value) == TYPE_DICTIONARY:
			var counted_outcome := str((exit_value as Dictionary).get("outcome", "gutter"))
			outcome_totals[counted_outcome] = int(outcome_totals.get(counted_outcome, 0)) + 1
	var outcome_indices := {"tray": 0, "gutter": 0}
	for exit_value in exits:
		if typeof(exit_value) != TYPE_DICTIONARY:
			continue
		var exit_event: Dictionary = exit_value
		var outcome := str(exit_event.get("outcome", "gutter"))
		var tick_offset := int(exit_event.get("tick_offset", ACTION_TICKS))
		var group_index := int(outcome_indices.get(outcome, 0))
		outcome_indices[outcome] = group_index + 1
		result.append(_presentation_event("ledge_tip", exit_event, 760, maxi(0, tick_offset - 3), {"outcome": outcome}))
		result.append(_presentation_event("tray_landing" if outcome == "tray" else "gutter_loss", exit_event, mini(1000, 450 + int(exit_event.get("mass", 1)) * 110), tick_offset, {
			"outcome": outcome,
			"group_count": int(outcome_totals.get(outcome, 1)),
			"group_index": group_index,
		}))
	if int(config.get("nudge_x", 0)) != 0 or int(config.get("nudge_y", 0)) != 0:
		result.append(_presentation_event("cabinet_shake", focus, mini(1000, (absi(int(config.get("nudge_x", 0))) + absi(int(config.get("nudge_y", 0)))) / 24), 1, {}))
	return result


static func _presentation_focus_body(state: Dictionary) -> Dictionary:
	for body_value in state.get("bodies", []):
		if typeof(body_value) == TYPE_DICTIONARY and not bool((body_value as Dictionary).get("sleeping", false)):
			return (body_value as Dictionary).duplicate(true)
	var bodies: Array = state.get("bodies", []) if typeof(state.get("bodies", [])) == TYPE_ARRAY else []
	return (bodies[0] as Dictionary).duplicate(true) if not bodies.is_empty() and typeof(bodies[0]) == TYPE_DICTIONARY else {}


static func _presentation_body_by_id(state: Dictionary, body_id: String) -> Dictionary:
	for body_value in state.get("bodies", []):
		if typeof(body_value) == TYPE_DICTIONARY and str((body_value as Dictionary).get("id", "")) == body_id:
			return (body_value as Dictionary).duplicate(true)
	return {}


static func _presentation_event(kind: String, body: Dictionary, intensity_milli: int, tick_offset: int, metadata: Dictionary) -> Dictionary:
	return {
		"kind": kind,
		"body_id": str(body.get("body_id", body.get("id", ""))),
		"x": int(body.get("x", WIDTH / 2)),
		"y": int(body.get("y", UPPER_EDGE)),
		"z": int(body.get("z", 0)),
		"intensity_milli": clampi(intensity_milli, 0, 1000),
		"tick_offset": clampi(tick_offset, 0, ACTION_TICKS),
		"metadata": metadata.duplicate(true),
	}


static func _presentation_material_category(body: Dictionary) -> String:
	match str(body.get("kind", "coin")):
		"coin":
			return "coin"
		"puck":
			return "feature_puck"
		"fragment":
			return "key_fragment"
		"rider":
			return "prize_rider"
	return "physical_object"


static func _positions_by_id(state: Dictionary) -> Dictionary:
	var result := {}
	for value in state.get("bodies", []):
		if typeof(value) == TYPE_DICTIONARY:
			var body: Dictionary = value
			result[str(body.get("id", ""))] = [int(body.get("x", 0)), int(body.get("y", 0)), int(body.get("z", 0))]
	return result


static func _peak_z_by_id(state: Dictionary) -> Dictionary:
	var result := {}
	for value in state.get("bodies", []):
		if typeof(value) == TYPE_DICTIONARY:
			var body: Dictionary = value
			result[str(body.get("id", ""))] = int(body.get("z", 0))
	return result


static func _append_impact_motion_event(events: Array, event_keys: Dictionary, body: Dictionary, material: String, stack_depth: int, fall_height: int, tick_offset: int) -> void:
	var body_id := str(body.get("id", ""))
	var event_key := "impact|%s" % body_id
	if body_id.is_empty() or event_keys.has(event_key):
		return
	events.append({
		"kind": "impact",
		"body_id": body_id,
		"x": int(body.get("x", 0)),
		"y": int(body.get("y", 0)),
		"z": int(body.get("z", 0)),
		"tick_offset": tick_offset,
		"material": material,
		"stack_depth": maxi(0, stack_depth),
		"fall_height_milli": maxi(0, _divi(fall_height * FP, COIN_HEIGHT)),
	})
	event_keys[event_key] = true


static func _motion_event_count(events: Array, kind: String) -> int:
	var count := 0
	for value in events:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("kind", "")) == kind:
			count += 1
	return count


static func _spatial_keys(bodies: Array, awake_indices: PackedInt32Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	for index in range(bodies.size()):
		if typeof(bodies[index]) != TYPE_DICTIONARY:
			result.append(0)
			continue
		var body: Dictionary = bodies[index]
		if not bool(body["sleeping"]):
			awake_indices.append(index)
		var key := _bucket_key(_divi(int(body["x"]), BROADPHASE_CELL), _divi(int(body["y"]), BROADPHASE_CELL), _divi(int(body["z"]), BROADPHASE_CELL))
		result.append(key)
	return result


static func _spatial_buckets(spatial_keys: PackedInt32Array) -> Dictionary:
	var result := {}
	for index in range(spatial_keys.size()):
		var key := int(spatial_keys[index])
		if result.has(key):
			(result[key] as Array).append(index)
		else:
			result[key] = [index]
	return result


static func _neighbor_indices(buckets: Dictionary, cache: Dictionary, center_x: int, center_y: int, center_z: int) -> Array:
	var center_key := _bucket_key(center_x, center_y, center_z)
	if cache.has(center_key):
		return cache[center_key] as Array
	var result: Array = []
	for z_offset in range(-1, 2):
		for y_offset in range(-1, 2):
			for x_offset in range(-1, 2):
				var bucket_value: Variant = buckets.get(_bucket_key(center_x + x_offset, center_y + y_offset, center_z + z_offset), null)
				if typeof(bucket_value) == TYPE_ARRAY:
					result.append_array(bucket_value as Array)
	cache[center_key] = result
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
