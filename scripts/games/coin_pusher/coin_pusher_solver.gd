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
const HOT_GRID_KEY_CAPACITY := 1048576
const HOT_POSITION_ABS_LIMIT := 100000000
const HOT_VELOCITY_ABS_LIMIT := 100000000
const HOT_DIMENSION_LIMIT := 10000
const HOT_GENERAL_SCALAR_ABS_LIMIT := 1000000
const HOT_PRESSURE_ACCEL_ABS_LIMIT := 100000
const HOT_BODY_COUNT_LIMIT := 256
# One collision query and one support query per eligible body are the
# MAX_COLLISION_PASSES == 1 ceiling. Keep the open-address table at <= 50%
# load and reserve the exact worst-case flat candidate count without growth.
const HOT_CANDIDATE_CACHE_CAPACITY := 1024
const HOT_CANDIDATE_POOL_CAPACITY := HOT_BODY_COUNT_LIMIT * HOT_BODY_COUNT_LIMIT * 2
const HOT_CACHE_GENERATION_MAX := 2147483647
const HOT_CONFIG_IMPULSE_ABS_LIMIT := 100000000
const HOT_PUSH_SCALE_ABS_LIMIT := 1000
const NATIVE_BACKEND_ID := "coin_pusher_native_integer_v1"
const NATIVE_ABI_VERSION := 1
const PACKED_TRACE_SCHEMA := "coin_pusher_presentation_trace_packed"
const PACKED_TRACE_VERSION := 1
const NATIVE_MUTABLE_BODY_KEYS := {
	"x": true, "y": true, "z": true,
	"vx": true, "vy": true, "vz": true,
	"sleep_ticks": true, "sleeping": true,
	"rest_state": true, "lean_milli": true,
	"cap_pressure_ticks": true, "cap_pressure_accel": true,
}

static var _native_backend: Object = null
static var _native_backend_checked := false
static var _last_step_backend_for_test := "uninitialized"


class HotBodies:
	extends RefCounted

	var refs: Array = []
	var ids: Array = []
	var kinds: Array = []
	var metadata: Array = []
	var rest_states: Array = []
	var x := PackedInt32Array()
	var y := PackedInt32Array()
	var z := PackedInt32Array()
	var vx := PackedInt32Array()
	var vy := PackedInt32Array()
	var vz := PackedInt32Array()
	var radii := PackedInt32Array()
	var heights := PackedInt32Array()
	var masses := PackedInt32Array()
	var sleep_ticks := PackedInt32Array()
	var sleeping := PackedByteArray()
	var lean := PackedInt32Array()
	var cap_pressure_ticks := PackedInt32Array()
	var cap_pressure_accel := PackedInt32Array()

	func load_from(state: Dictionary) -> void:
		refs = state.get("bodies", []) if typeof(state.get("bodies", [])) == TYPE_ARRAY else []
		var count := refs.size()
		ids.resize(count)
		kinds.resize(count)
		metadata.resize(count)
		rest_states.resize(count)
		x.resize(count)
		y.resize(count)
		z.resize(count)
		vx.resize(count)
		vy.resize(count)
		vz.resize(count)
		radii.resize(count)
		heights.resize(count)
		masses.resize(count)
		sleep_ticks.resize(count)
		sleeping.resize(count)
		lean.resize(count)
		cap_pressure_ticks.resize(count)
		cap_pressure_accel.resize(count)
		for index in range(count):
			var body: Dictionary = refs[index]
			ids[index] = str(body.get("id", ""))
			kinds[index] = str(body.get("kind", "coin"))
			metadata[index] = body.get("metadata", {}) if typeof(body.get("metadata", {})) == TYPE_DICTIONARY else {}
			rest_states[index] = str(body.get("rest_state", "settling"))
			x[index] = int(body["x"])
			y[index] = int(body["y"])
			z[index] = int(body["z"])
			vx[index] = int(body["vx"])
			vy[index] = int(body["vy"])
			vz[index] = int(body["vz"])
			radii[index] = int(body["radius"])
			heights[index] = int(body["height"])
			masses[index] = int(body["mass"])
			sleep_ticks[index] = int(body["sleep_ticks"])
			sleeping[index] = 1 if bool(body["sleeping"]) else 0
			lean[index] = int(body.get("lean_milli", 0))
			cap_pressure_ticks[index] = int(body.get("cap_pressure_ticks", 0))
			cap_pressure_accel[index] = int(body.get("cap_pressure_accel", 0))

	func size() -> int:
		return refs.size()

	func remove_at(index: int) -> void:
		refs.remove_at(index)
		ids.remove_at(index)
		kinds.remove_at(index)
		metadata.remove_at(index)
		rest_states.remove_at(index)
		x.remove_at(index)
		y.remove_at(index)
		z.remove_at(index)
		vx.remove_at(index)
		vy.remove_at(index)
		vz.remove_at(index)
		radii.remove_at(index)
		heights.remove_at(index)
		masses.remove_at(index)
		sleep_ticks.remove_at(index)
		sleeping.remove_at(index)
		lean.remove_at(index)
		cap_pressure_ticks.remove_at(index)
		cap_pressure_accel.remove_at(index)

	func write_back(state: Dictionary) -> void:
		for index in range(refs.size()):
			var body: Dictionary = refs[index]
			body["x"] = x[index]
			body["y"] = y[index]
			body["z"] = z[index]
			body["vx"] = vx[index]
			body["vy"] = vy[index]
			body["vz"] = vz[index]
			body["sleep_ticks"] = sleep_ticks[index]
			body["sleeping"] = sleeping[index] != 0
			body["rest_state"] = rest_states[index]
			body["lean_milli"] = lean[index]
			if body.has("cap_pressure_ticks") or cap_pressure_ticks[index] > 0:
				body["cap_pressure_ticks"] = cap_pressure_ticks[index]
			if body.has("cap_pressure_accel") or cap_pressure_accel[index] > 0:
				body["cap_pressure_accel"] = cap_pressure_accel[index]
		state["bodies"] = refs


class HotGrid:
	extends RefCounted

	var head := PackedInt32Array()
	var next := PackedInt32Array()
	var touched := PackedInt32Array()
	var overflow: Dictionary = {}
	var candidate_keys := PackedInt32Array()
	var candidate_generations := PackedInt32Array()
	var candidate_offsets := PackedInt32Array()
	var candidate_lengths := PackedInt32Array()
	var candidate_pool := PackedInt32Array()
	var candidate_pool_used := 0
	var candidate_generation := 0

	func _init() -> void:
		head.resize(CoinPusherSolver.HOT_GRID_KEY_CAPACITY)
		candidate_keys.resize(CoinPusherSolver.HOT_CANDIDATE_CACHE_CAPACITY)
		candidate_generations.resize(CoinPusherSolver.HOT_CANDIDATE_CACHE_CAPACITY)
		candidate_offsets.resize(CoinPusherSolver.HOT_CANDIDATE_CACHE_CAPACITY)
		candidate_lengths.resize(CoinPusherSolver.HOT_CANDIDATE_CACHE_CAPACITY)
		candidate_pool.resize(CoinPusherSolver.HOT_CANDIDATE_POOL_CAPACITY)

	func rebuild(hot: HotBodies) -> void:
		for key in touched:
			head[int(key)] = 0
		touched.clear()
		overflow.clear()
		candidate_pool_used = 0
		if candidate_generation >= CoinPusherSolver.HOT_CACHE_GENERATION_MAX:
			candidate_generations.fill(0)
			candidate_generation = 1
		else:
			candidate_generation += 1
		next.resize(hot.size())
		for index in range(hot.size() - 1, -1, -1):
			var key := CoinPusherSolver._bucket_key(
				CoinPusherSolver._divi(hot.x[index], CoinPusherSolver.BROADPHASE_CELL),
				CoinPusherSolver._divi(hot.y[index], CoinPusherSolver.BROADPHASE_CELL),
				CoinPusherSolver._divi(hot.z[index], CoinPusherSolver.BROADPHASE_CELL)
			)
			if key < 0 or key >= head.size():
				var overflow_members: Array = overflow.get(key, [])
				overflow_members.push_front(index)
				overflow[key] = overflow_members
				continue
			if head[key] == 0:
				touched.append(key)
			next[index] = head[key]
			head[key] = index + 1

	func candidate_slot(center_x: int, center_y: int, center_z: int) -> int:
		var center_key := CoinPusherSolver._bucket_key(center_x, center_y, center_z)
		var cache_slot := (center_key * 1103515245) & (CoinPusherSolver.HOT_CANDIDATE_CACHE_CAPACITY - 1)
		for _probe_index in range(CoinPusherSolver.HOT_CANDIDATE_CACHE_CAPACITY):
			if candidate_generations[cache_slot] != candidate_generation:
				candidate_generations[cache_slot] = candidate_generation
				candidate_keys[cache_slot] = center_key
				candidate_offsets[cache_slot] = candidate_pool_used
				_build_candidate_sequence(cache_slot, center_x, center_y, center_z)
				return cache_slot
			if candidate_keys[cache_slot] == center_key:
				return cache_slot
			cache_slot = (cache_slot + 1) & (CoinPusherSolver.HOT_CANDIDATE_CACHE_CAPACITY - 1)
		return -1

	func _build_candidate_sequence(cache_slot: int, center_x: int, center_y: int, center_z: int) -> void:
		var start_offset := candidate_pool_used
		for z_offset in range(-1, 2):
			for y_offset in range(-1, 2):
				for x_offset in range(-1, 2):
					var key := CoinPusherSolver._bucket_key(center_x + x_offset, center_y + y_offset, center_z + z_offset)
					if key < 0 or key >= head.size():
						for overflow_index in overflow.get(key, []):
							candidate_pool[candidate_pool_used] = int(overflow_index)
							candidate_pool_used += 1
						continue
					var encoded_index := head[key]
					while encoded_index != 0:
						var index := encoded_index - 1
						candidate_pool[candidate_pool_used] = index
						candidate_pool_used += 1
						encoded_index = next[index]
		candidate_lengths[cache_slot] = candidate_pool_used - start_offset

	func set_candidate_generation_for_test(generation: int) -> void:
		candidate_generation = clampi(generation, 0, CoinPusherSolver.HOT_CACHE_GENERATION_MAX)


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
	_normalize_hot_body_fields(state)
	var debug_adapter := bool(config.get("_debug_profile_stages", false))
	var debug_adapter_started_usec := Time.get_ticks_usec() if debug_adapter else 0
	var forced_backend := str(config.get("_debug_force_solver_backend", ""))
	if forced_backend != "gdscript":
		var native := _native_solver_backend()
		if native != null:
			var trusted_native := native.get_class() == "CoinPusherNativeCore" and native.get_script() == null
			# The shipped extension performs the same numeric/body eligibility
			# validation before it mutates its isolated candidate. Let that single
			# native boundary own the trusted check; a rejection returns an empty
			# result and routes the untouched authority through the reference path.
			# Scripted backends retain the explicit GDScript eligibility guard.
			if not trusted_native and _hot_state_requires_reference(state, config):
				_last_step_backend_for_test = "reference"
				return _step_action_dictionary_reference(state, config)
			var debug_stage_started_usec := Time.get_ticks_usec() if debug_adapter else 0
			var native_state := _native_candidate_state(state, not trusted_native)
			var native_config := config.duplicate(not trusted_native)
			var debug_candidate_usec := Time.get_ticks_usec() - debug_stage_started_usec if debug_adapter else 0
			debug_stage_started_usec = Time.get_ticks_usec() if debug_adapter else 0
			# The exact shipped extension validates at the top of step_action before it
			# constructs or mutates the kernel. Calling can_step first repeated the same
			# full-body validation across the GDExtension boundary. Injected/mock
			# backends keep the explicit eligibility call and deep transaction above.
			var native_eligible := trusted_native or bool(native.call("can_step", native_state, native_config))
			var debug_can_step_usec := Time.get_ticks_usec() - debug_stage_started_usec if debug_adapter else 0
			if native_eligible:
				debug_stage_started_usec = Time.get_ticks_usec() if debug_adapter else 0
				var native_result_value: Variant = native.call("step_action", native_state, native_config)
				var debug_native_call_usec := Time.get_ticks_usec() - debug_stage_started_usec if debug_adapter else 0
				var native_result: Dictionary = native_result_value if typeof(native_result_value) == TYPE_DICTIONARY else {}
				debug_stage_started_usec = Time.get_ticks_usec() if debug_adapter else 0
				# Only this synchronous, scriptless extension call may take the compact
				# publication guard: no caller can mutate its isolated candidate between
				# return and validation. Test/injected contracts retain the exhaustive
				# corruption audit exposed below.
				var native_contract_valid := _trusted_native_step_contract_valid(state, native_state, native_result, config) if trusted_native \
						else _native_step_contract_valid(state, native_state, native_result, config, false)
				if native_contract_valid:
					var debug_validate_usec := Time.get_ticks_usec() - debug_stage_started_usec if debug_adapter else 0
					debug_stage_started_usec = Time.get_ticks_usec() if debug_adapter else 0
					_publish_native_state(state, native_state, trusted_native)
					if debug_adapter:
						var debug_profile: Dictionary = native_result.get("debug_stage_timing_usec", {})
						debug_profile["adapter_candidate"] = debug_candidate_usec
						debug_profile["adapter_can_step"] = debug_can_step_usec
						debug_profile["adapter_native_call"] = debug_native_call_usec
						debug_profile["adapter_validate"] = debug_validate_usec
						debug_profile["adapter_publish"] = Time.get_ticks_usec() - debug_stage_started_usec
						debug_profile["adapter_total"] = Time.get_ticks_usec() - debug_adapter_started_usec
						native_result["debug_stage_timing_usec"] = debug_profile
					_last_step_backend_for_test = "native"
					return native_result
			if trusted_native:
				_last_step_backend_for_test = "reference"
				return _step_action_dictionary_reference(state, config)
	if _hot_state_requires_reference(state, config):
		_last_step_backend_for_test = "reference"
		return _step_action_dictionary_reference(state, config)
	_last_step_backend_for_test = "gdscript"
	return _step_action_hot(state, config)


static func step_action_reference_for_test(state: Dictionary, config: Dictionary) -> Dictionary:
	return _step_action_dictionary_reference(state, config)


static func hot_state_eligible_for_test(state: Dictionary, config: Dictionary = {}) -> bool:
	var candidate := state.duplicate(true)
	_normalize_hot_body_fields(candidate)
	return not _hot_state_requires_reference(candidate, config)


static func native_backend_available_for_test() -> bool:
	return _native_solver_backend() != null


static func last_step_backend_for_test() -> String:
	return _last_step_backend_for_test


static func reset_native_backend_for_test() -> void:
	_native_backend = null
	_native_backend_checked = false
	_last_step_backend_for_test = "uninitialized"


static func install_native_backend_for_test(backend: Object) -> void:
	_native_backend = backend if _native_backend_contract_valid(backend) else null
	_native_backend_checked = true
	_last_step_backend_for_test = "uninitialized"


static func native_step_contract_valid_for_test(before: Dictionary, candidate: Dictionary, result: Dictionary, config: Dictionary, trusted_native: bool) -> bool:
	return _native_step_contract_valid(before, candidate, result, config, trusted_native)


static func finalize_packed_presentation_trace(packed_trace: Dictionary, state: Dictionary, tick_offset: int) -> Dictionary:
	if not _packed_trace_contract_valid(packed_trace):
		return {}
	# Shipped native traces already author the persisted tick-49 pile while the
	# first solver kernel is hot. Keep this compatibility entry point idempotent;
	# old 13-frame traces can still be finalized during a rolling upgrade.
	if int(packed_trace.get("frame_count", 0)) == ACTION_TICKS / PRESENTATION_TRACE_INTERVAL_TICKS + 2:
		return packed_trace
	var native := _native_solver_backend()
	if native == null or native.get_class() != "CoinPusherNativeCore" or native.get_script() != null \
			or not native.has_method("append_presentation_trace_frame"):
		return {}
	var value: Variant = native.call("append_presentation_trace_frame", packed_trace, state, tick_offset)
	var finalized: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	return finalized if _packed_trace_contract_valid(finalized) and int(finalized.get("frame_count", 0)) == int(packed_trace.get("frame_count", 0)) + 1 else {}


static func decode_packed_presentation_trace(packed_trace: Dictionary) -> Array:
	if not _packed_trace_contract_valid(packed_trace):
		return []
	var frame_offsets: PackedInt32Array = packed_trace["frame_offsets"]
	var tick_offsets: PackedInt32Array = packed_trace["tick_offsets"]
	var upper_phases: PackedInt32Array = packed_trace["upper_phase_fp"]
	var lower_phases: PackedInt32Array = packed_trace["lower_phase_fp"]
	var body_ids: PackedStringArray = packed_trace["body_ids"]
	var body_kinds: PackedStringArray = packed_trace["body_kinds"]
	var body_radii: PackedInt32Array = packed_trace["body_radii"]
	var body_heights: PackedInt32Array = packed_trace["body_heights"]
	var body_masses: PackedInt32Array = packed_trace["body_masses"]
	var body_metadata: Array = packed_trace["body_metadata"]
	var row_body_indices: PackedInt32Array = packed_trace["row_body_indices"]
	var row_material_categories: PackedStringArray = packed_trace["row_material_categories"]
	var row_x: PackedInt32Array = packed_trace["row_x"]
	var row_y: PackedInt32Array = packed_trace["row_y"]
	var row_z: PackedInt32Array = packed_trace["row_z"]
	var row_radius: PackedInt32Array = packed_trace["row_radius"]
	var row_height: PackedInt32Array = packed_trace["row_height"]
	var row_sleeping: PackedByteArray = packed_trace["row_sleeping"]
	var row_rest_states: PackedStringArray = packed_trace["row_rest_states"]
	var row_has_level: PackedByteArray = packed_trace["row_has_level"]
	var row_levels: PackedStringArray = packed_trace["row_levels"]
	var row_lean: PackedInt32Array = packed_trace["row_lean_milli"]
	var frames: Array = []
	for frame_index in range(int(packed_trace["frame_count"])):
		var frame_bodies: Array = []
		for row_index in range(frame_offsets[frame_index], frame_offsets[frame_index + 1]):
			var body_index := row_body_indices[row_index]
			var body := {
				"id": body_ids[body_index],
				"kind": body_kinds[body_index],
				"material_category": row_material_categories[row_index],
				"x": row_x[row_index], "y": row_y[row_index], "z": row_z[row_index],
				"radius": row_radius[row_index], "height": row_height[row_index], "mass": body_masses[body_index],
				"sleeping": row_sleeping[row_index] != 0,
				"rest_state": row_rest_states[row_index],
			}
			if row_has_level[row_index] != 0:
				body["level"] = row_levels[row_index]
			body["lean_milli"] = row_lean[row_index]
			body["metadata"] = (body_metadata[body_index] as Dictionary).duplicate(true) if typeof(body_metadata[body_index]) == TYPE_DICTIONARY else {}
			frame_bodies.append(body)
		frames.append({
			"tick_offset": tick_offsets[frame_index],
			"upper_phase_fp": upper_phases[frame_index],
			"lower_phase_fp": lower_phases[frame_index],
			"bodies": frame_bodies,
		})
	return frames


static func _native_solver_backend() -> Object:
	if _native_backend_checked:
		return _native_backend
	_native_backend_checked = true
	if not ClassDB.class_exists("CoinPusherNativeCore"):
		return null
	var candidate: Object = ClassDB.instantiate("CoinPusherNativeCore")
	if _native_backend_contract_valid(candidate):
		_native_backend = candidate
	return _native_backend


static func _native_backend_contract_valid(backend: Object) -> bool:
	if backend == null:
		return false
	for method_name in ["backend_id", "solver_contract", "can_step", "step_action", "append_presentation_trace_frame"]:
		if not backend.has_method(method_name):
			return false
	if str(backend.call("backend_id")) != NATIVE_BACKEND_ID:
		return false
	var contract_value: Variant = backend.call("solver_contract")
	if typeof(contract_value) != TYPE_DICTIONARY:
		return false
	var contract: Dictionary = contract_value
	return int(contract.get("abi_version", -1)) == NATIVE_ABI_VERSION \
		and str(contract.get("schema", "")) == SCHEMA \
		and int(contract.get("state_version", -1)) == VERSION \
		and int(contract.get("fixed_point_scale", -1)) == FP \
		and int(contract.get("action_ticks", -1)) == ACTION_TICKS \
		and int(contract.get("packed_trace_version", -1)) == PACKED_TRACE_VERSION


static func _packed_trace_contract_valid(packed_trace: Dictionary) -> bool:
	if str(packed_trace.get("schema", "")) != PACKED_TRACE_SCHEMA or int(packed_trace.get("version", 0)) != PACKED_TRACE_VERSION:
		return false
	var frame_count := int(packed_trace.get("frame_count", -1))
	if frame_count < 0:
		return false
	var packed_int_fields := ["frame_offsets", "tick_offsets", "upper_phase_fp", "lower_phase_fp", "body_radii", "body_heights", "body_masses", "row_body_indices", "row_x", "row_y", "row_z", "row_radius", "row_height", "row_lean_milli"]
	for field in packed_int_fields:
		if typeof(packed_trace.get(field)) != TYPE_PACKED_INT32_ARRAY:
			return false
	for field in ["body_ids", "body_kinds", "row_material_categories", "row_rest_states", "row_levels"]:
		if typeof(packed_trace.get(field)) != TYPE_PACKED_STRING_ARRAY:
			return false
	for field in ["row_sleeping", "row_has_level"]:
		if typeof(packed_trace.get(field)) != TYPE_PACKED_BYTE_ARRAY:
			return false
	if typeof(packed_trace.get("body_metadata")) != TYPE_ARRAY:
		return false
	var offsets: PackedInt32Array = packed_trace["frame_offsets"]
	var rows: PackedInt32Array = packed_trace["row_body_indices"]
	var descriptors: PackedStringArray = packed_trace["body_ids"]
	if offsets.size() != frame_count + 1 or offsets.is_empty() or offsets[0] != 0 or offsets[offsets.size() - 1] != rows.size():
		return false
	if (packed_trace["tick_offsets"] as PackedInt32Array).size() != frame_count \
			or (packed_trace["upper_phase_fp"] as PackedInt32Array).size() != frame_count \
			or (packed_trace["lower_phase_fp"] as PackedInt32Array).size() != frame_count:
		return false
	for field in ["body_kinds", "body_radii", "body_heights", "body_masses", "body_metadata"]:
		if int(packed_trace[field].size()) != descriptors.size():
			return false
	for field in ["row_material_categories", "row_x", "row_y", "row_z", "row_radius", "row_height", "row_sleeping", "row_rest_states", "row_has_level", "row_levels", "row_lean_milli"]:
		if packed_trace[field].size() != rows.size():
			return false
	for frame_index in range(frame_count):
		if offsets[frame_index] > offsets[frame_index + 1]:
			return false
	for body_index in rows:
		if body_index < 0 or body_index >= descriptors.size():
			return false
	return true


static func _native_candidate_state(state: Dictionary, deep_copy_values: bool = true) -> Dictionary:
	var candidate := {}
	for key in ["schema", "version", "fixed_hz", "fixed_point_scale", "tick", "upper_phase_fp", "lower_phase_fp"]:
		if state.has(key):
			candidate[key] = state[key]
	var bodies_value: Variant = state.get("bodies", [])
	if typeof(bodies_value) != TYPE_ARRAY:
		candidate["bodies"] = bodies_value
		return candidate
	var candidate_bodies: Array = []
	for body_value in (bodies_value as Array):
		candidate_bodies.append((body_value as Dictionary).duplicate(deep_copy_values) if typeof(body_value) == TYPE_DICTIONARY else body_value)
	candidate["bodies"] = candidate_bodies
	return candidate


static func _publish_native_state(state: Dictionary, candidate: Dictionary, trusted_native: bool = false) -> void:
	var original_bodies: Array = state.get("bodies", [])
	var candidate_bodies: Array = candidate.get("bodies", [])
	if trusted_native:
		# The trusted contract has already proved that candidates are the
		# source-order subsequence left after reported physical exits. Publish
		# linearly so body Dictionary identities remain authoritative aliases.
		var original_index := 0
		var candidate_index := 0
		while original_index < original_bodies.size():
			var original_body: Dictionary = original_bodies[original_index]
			if candidate_index >= candidate_bodies.size() \
					or str(original_body.get("id", "")) != str((candidate_bodies[candidate_index] as Dictionary).get("id", "")):
				original_bodies.remove_at(original_index)
				continue
			var candidate_body: Dictionary = candidate_bodies[candidate_index]
			for mutable_key in ["x", "y", "z", "vx", "vy", "vz", "sleep_ticks", "sleeping", "rest_state", "lean_milli"]:
				original_body[mutable_key] = candidate_body[mutable_key]
			for pressure_key in ["cap_pressure_ticks", "cap_pressure_accel"]:
				if original_body.has(pressure_key) or int(candidate_body.get(pressure_key, 0)) > 0:
					original_body[pressure_key] = candidate_body.get(pressure_key, 0)
			original_index += 1
			candidate_index += 1
	else:
		var candidate_by_id := {}
		for candidate_value in candidate_bodies:
			var candidate_body: Dictionary = candidate_value
			candidate_by_id[str(candidate_body.get("id", ""))] = candidate_body
		for index in range(original_bodies.size() - 1, -1, -1):
			var original_body: Dictionary = original_bodies[index]
			var body_id := str(original_body.get("id", ""))
			if candidate_by_id.has(body_id):
				var candidate_body: Dictionary = candidate_by_id[body_id]
				for mutable_key in ["x", "y", "z", "vx", "vy", "vz", "sleep_ticks", "sleeping", "rest_state", "lean_milli"]:
					original_body[mutable_key] = candidate_body[mutable_key]
				for pressure_key in ["cap_pressure_ticks", "cap_pressure_accel"]:
					if original_body.has(pressure_key) or int(candidate_body.get(pressure_key, 0)) > 0:
						original_body[pressure_key] = candidate_body.get(pressure_key, 0)
			else:
				original_bodies.remove_at(index)
	state["bodies"] = original_bodies
	state["tick"] = candidate["tick"]
	for phase_key in ["upper_phase_fp", "lower_phase_fp"]:
		if candidate.has(phase_key):
			state[phase_key] = candidate[phase_key]
	state["last_events"] = candidate["last_events"]
	state["last_motion_events"] = candidate["last_motion_events"]
	state["last_step_metrics"] = candidate["last_step_metrics"]


static func _native_step_contract_valid(before: Dictionary, candidate: Dictionary, result: Dictionary, config: Dictionary, trusted_native: bool = false) -> bool:
	if result.is_empty() or typeof(candidate.get("bodies", null)) != TYPE_ARRAY:
		return false
	if typeof(candidate.get("tick", null)) != TYPE_INT or int(candidate.get("tick", -1)) != int(before.get("tick", 0)) + ACTION_TICKS:
		return false
	if str(candidate.get("schema", "")) != SCHEMA or int(candidate.get("version", -1)) != VERSION:
		return false
	for phase_spec in [["upper_phase_fp", "upper_locked"], ["lower_phase_fp", "lower_locked"]]:
		var phase_key: String = phase_spec[0]
		var captured := config.has("captured_%s" % phase_key)
		var publishes := captured or not bool(config.get(phase_spec[1], false))
		if publishes:
			var phase := int(candidate.get(phase_key, -1))
			if typeof(candidate.get(phase_key, null)) != TYPE_INT or phase < 0 or phase >= PHASE_PERIOD:
				return false
		elif candidate.has(phase_key) != before.has(phase_key) \
				or (candidate.has(phase_key) and (typeof(candidate[phase_key]) != typeof(before[phase_key]) or candidate[phase_key] != before[phase_key])):
			return false
	var required_types := {
		"events": TYPE_ARRAY,
		"motion_events": TYPE_ARRAY,
		"presentation_events": TYPE_ARRAY,
		"metrics": TYPE_DICTIONARY,
		"presentation_trace": TYPE_ARRAY,
	}
	for key in required_types:
		if typeof(result.get(key, null)) != int(required_types[key]):
			return false
	var allowed_keys := required_types.keys()
	var captures_trace := bool(config.get("capture_presentation_trace", false))
	if trusted_native and captures_trace:
		if not (result.get("presentation_trace", []) as Array).is_empty() \
				or typeof(result.get("presentation_trace_packed")) != TYPE_DICTIONARY \
				or not _packed_trace_contract_valid(result.get("presentation_trace_packed", {})) \
				or int((result.get("presentation_trace_packed", {}) as Dictionary).get("frame_count", 0)) != ACTION_TICKS / PRESENTATION_TRACE_INTERVAL_TICKS + 2:
			return false
		allowed_keys.append("presentation_trace_packed")
	elif result.has("presentation_trace_packed"):
		return false
	if bool(config.get("_debug_profile_stages", false)):
		if typeof(result.get("debug_stage_timing_usec", null)) != TYPE_DICTIONARY:
			return false
		allowed_keys.append("debug_stage_timing_usec")
	elif result.has("debug_stage_timing_usec"):
		return false
	if result.size() != allowed_keys.size():
		return false
	for key in result:
		if not allowed_keys.has(key):
			return false
	var metrics: Dictionary = result.get("metrics", {})
	var metric_keys := ["fixed_ticks", "body_count", "awake_count", "woken_count", "moved_count", "collision_passes", "collision_count", "topple_count", "upper_lower_fall_count"]
	if metrics.size() != metric_keys.size():
		return false
	for metric_key in metric_keys:
		if typeof(metrics.get(metric_key, null)) != TYPE_INT:
			return false
	if int(metrics.get("fixed_ticks", -1)) != ACTION_TICKS or int(metrics.get("body_count", -1)) != (candidate.get("bodies", []) as Array).size():
		return false
	if typeof(candidate.get("last_events", null)) != TYPE_ARRAY \
			or typeof(candidate.get("last_motion_events", null)) != TYPE_ARRAY \
			or typeof(candidate.get("last_step_metrics", null)) != TYPE_DICTIONARY:
		return false
	if candidate["last_events"] != result["events"] \
			or candidate["last_motion_events"] != result["motion_events"] \
			or candidate["last_step_metrics"] != result["metrics"]:
		return false
	var before_bodies: Array = before.get("bodies", [])
	var candidate_bodies: Array = candidate.get("bodies", [])
	if trusted_native:
		# validate_step_input() guarantees unique source IDs. The exact unscripted
		# kernel may only retain bodies in source order or remove a body reported by
		# one physical-exit event. Immutable body shape and values remain guarded.
		var physical_exit_ids := {}
		for event_value in result.get("events", []):
			if typeof(event_value) != TYPE_DICTIONARY:
				return false
			var exit_event: Dictionary = event_value
			var exit_id := str(exit_event.get("body_id", ""))
			if exit_id.is_empty() or str(exit_event.get("cause", "")) != "physical_fall" or physical_exit_ids.has(exit_id):
				return false
			physical_exit_ids[exit_id] = true
		var before_index := 0
		for candidate_value in candidate_bodies:
			if typeof(candidate_value) != TYPE_DICTIONARY:
				return false
			var candidate_body: Dictionary = candidate_value
			var candidate_id := str(candidate_body.get("id", ""))
			while before_index < before_bodies.size() and str((before_bodies[before_index] as Dictionary).get("id", "")) != candidate_id:
				var removed_id := str((before_bodies[before_index] as Dictionary).get("id", ""))
				if not physical_exit_ids.erase(removed_id):
					return false
				before_index += 1
			if before_index >= before_bodies.size():
				return false
			var before_body: Dictionary = before_bodies[before_index]
			before_index += 1
			for int_key in ["x", "y", "z", "vx", "vy", "vz", "sleep_ticks", "lean_milli"]:
				if typeof(candidate_body.get(int_key, null)) != TYPE_INT:
					return false
			if typeof(candidate_body.get("sleeping", null)) != TYPE_BOOL or typeof(candidate_body.get("rest_state", null)) != TYPE_STRING:
				return false
			for pressure_key in ["cap_pressure_ticks", "cap_pressure_accel"]:
				if before_body.has(pressure_key) and not candidate_body.has(pressure_key):
					return false
				if candidate_body.has(pressure_key) and typeof(candidate_body[pressure_key]) != TYPE_INT:
					return false
			for key in before_body:
				if not NATIVE_MUTABLE_BODY_KEYS.has(key) and (not candidate_body.has(key) or typeof(candidate_body[key]) != typeof(before_body[key]) or candidate_body[key] != before_body[key]):
					return false
			for key in candidate_body:
				if not NATIVE_MUTABLE_BODY_KEYS.has(key) and not before_body.has(key):
					return false
		while before_index < before_bodies.size():
			var removed_id := str((before_bodies[before_index] as Dictionary).get("id", ""))
			if not physical_exit_ids.erase(removed_id):
				return false
			before_index += 1
		return physical_exit_ids.is_empty()
	var candidate_ids := {}
	var before_by_id := {}
	for before_value in before_bodies:
		before_by_id[str((before_value as Dictionary).get("id", ""))] = before_value
	for candidate_value in candidate_bodies:
		if typeof(candidate_value) != TYPE_DICTIONARY:
			return false
		var candidate_id := str((candidate_value as Dictionary).get("id", ""))
		if candidate_ids.has(candidate_id):
			return false
		candidate_ids[candidate_id] = true
		if not before_by_id.has(candidate_id):
			return false
		var candidate_body: Dictionary = candidate_value
		var before_body: Dictionary = before_by_id[candidate_id]
		for int_key in ["x", "y", "z", "vx", "vy", "vz", "sleep_ticks", "lean_milli"]:
			if typeof(candidate_body.get(int_key, null)) != TYPE_INT:
				return false
		if typeof(candidate_body.get("sleeping", null)) != TYPE_BOOL or typeof(candidate_body.get("rest_state", null)) != TYPE_STRING:
			return false
		for pressure_key in ["cap_pressure_ticks", "cap_pressure_accel"]:
			if before_body.has(pressure_key) and not candidate_body.has(pressure_key):
				return false
			if candidate_body.has(pressure_key) and typeof(candidate_body[pressure_key]) != TYPE_INT:
				return false
		if not trusted_native:
			for key in before_body:
				if not NATIVE_MUTABLE_BODY_KEYS.has(key) and (not candidate_body.has(key) or typeof(candidate_body[key]) != typeof(before_body[key]) or candidate_body[key] != before_body[key]):
					return false
			for key in candidate_body:
				if not NATIVE_MUTABLE_BODY_KEYS.has(key) and not before_body.has(key):
					return false
	var candidate_index := 0
	for before_value in before_bodies:
		if candidate_index < candidate_bodies.size() \
				and str((before_value as Dictionary).get("id", "")) == str((candidate_bodies[candidate_index] as Dictionary).get("id", "")):
			candidate_index += 1
	return candidate_index == candidate_bodies.size()


static func _trusted_native_step_contract_valid(before: Dictionary, candidate: Dictionary, result: Dictionary, config: Dictionary) -> bool:
	# CoinPusherNativeCore is the shipped, scriptless extension selected by exact
	# class identity and a versioned solver contract. Its own boundary validates
	# every input body before constructing an isolated candidate. Rewalking every
	# immutable body field and every packed replay row in GDScript duplicated that
	# trusted boundary on every action. Keep a constant-shape publication guard;
	# injected/scripted backends still take the exhaustive transaction above.
	if result.is_empty() or typeof(candidate.get("bodies", null)) != TYPE_ARRAY:
		return false
	if str(candidate.get("schema", "")) != SCHEMA or int(candidate.get("version", -1)) != VERSION \
			or typeof(candidate.get("tick", null)) != TYPE_INT \
			or int(candidate.get("tick", -1)) != int(before.get("tick", 0)) + ACTION_TICKS:
		return false
	for phase_spec in [["upper_phase_fp", "upper_locked"], ["lower_phase_fp", "lower_locked"]]:
		var phase_key: String = phase_spec[0]
		var captured := config.has("captured_%s" % phase_key)
		if captured or not bool(config.get(phase_spec[1], false)):
			var phase := int(candidate.get(phase_key, -1))
			if typeof(candidate.get(phase_key, null)) != TYPE_INT or phase < 0 or phase >= PHASE_PERIOD:
				return false
		elif candidate.has(phase_key) != before.has(phase_key) \
				or (candidate.has(phase_key) and candidate[phase_key] != before[phase_key]):
			return false
	var required_types := {
		"events": TYPE_ARRAY,
		"motion_events": TYPE_ARRAY,
		"presentation_events": TYPE_ARRAY,
		"metrics": TYPE_DICTIONARY,
		"presentation_trace": TYPE_ARRAY,
	}
	for key in required_types:
		if typeof(result.get(key, null)) != int(required_types[key]):
			return false
	var allowed_keys := required_types.keys()
	if bool(config.get("capture_presentation_trace", false)):
		if not (result.get("presentation_trace", []) as Array).is_empty() \
				or not _trusted_packed_trace_shape_valid(result.get("presentation_trace_packed", {})):
			return false
		allowed_keys.append("presentation_trace_packed")
	elif result.has("presentation_trace_packed"):
		return false
	if bool(config.get("_debug_profile_stages", false)):
		if typeof(result.get("debug_stage_timing_usec", null)) != TYPE_DICTIONARY:
			return false
		allowed_keys.append("debug_stage_timing_usec")
	elif result.has("debug_stage_timing_usec"):
		return false
	if result.size() != allowed_keys.size():
		return false
	for key in result:
		if not allowed_keys.has(key):
			return false
	var metrics: Dictionary = result.get("metrics", {})
	var metric_keys := ["fixed_ticks", "body_count", "awake_count", "woken_count", "moved_count", "collision_passes", "collision_count", "topple_count", "upper_lower_fall_count"]
	if metrics.size() != metric_keys.size():
		return false
	for metric_key in metric_keys:
		if typeof(metrics.get(metric_key, null)) != TYPE_INT:
			return false
	if int(metrics.get("fixed_ticks", -1)) != ACTION_TICKS \
			or int(metrics.get("body_count", -1)) != (candidate.get("bodies", []) as Array).size() \
			or (candidate.get("bodies", []) as Array).size() > (before.get("bodies", []) as Array).size():
		return false
	return typeof(candidate.get("last_events", null)) == TYPE_ARRAY \
			and typeof(candidate.get("last_motion_events", null)) == TYPE_ARRAY \
			and typeof(candidate.get("last_step_metrics", null)) == TYPE_DICTIONARY \
			and candidate["last_events"] == result["events"] \
			and candidate["last_motion_events"] == result["motion_events"] \
			and candidate["last_step_metrics"] == result["metrics"]


static func _trusted_packed_trace_shape_valid(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var packed: Dictionary = value
	var frame_count := int(packed.get("frame_count", -1))
	if str(packed.get("schema", "")) != PACKED_TRACE_SCHEMA or int(packed.get("version", 0)) != PACKED_TRACE_VERSION \
			or frame_count != ACTION_TICKS / PRESENTATION_TRACE_INTERVAL_TICKS + 2:
		return false
	var required_types := {
		"frame_offsets": TYPE_PACKED_INT32_ARRAY, "tick_offsets": TYPE_PACKED_INT32_ARRAY,
		"upper_phase_fp": TYPE_PACKED_INT32_ARRAY, "lower_phase_fp": TYPE_PACKED_INT32_ARRAY,
		"body_ids": TYPE_PACKED_STRING_ARRAY, "body_kinds": TYPE_PACKED_STRING_ARRAY,
		"body_radii": TYPE_PACKED_INT32_ARRAY, "body_heights": TYPE_PACKED_INT32_ARRAY,
		"body_masses": TYPE_PACKED_INT32_ARRAY, "body_metadata": TYPE_ARRAY,
		"row_body_indices": TYPE_PACKED_INT32_ARRAY, "row_material_categories": TYPE_PACKED_STRING_ARRAY,
		"row_x": TYPE_PACKED_INT32_ARRAY, "row_y": TYPE_PACKED_INT32_ARRAY, "row_z": TYPE_PACKED_INT32_ARRAY,
		"row_radius": TYPE_PACKED_INT32_ARRAY, "row_height": TYPE_PACKED_INT32_ARRAY,
		"row_sleeping": TYPE_PACKED_BYTE_ARRAY, "row_rest_states": TYPE_PACKED_STRING_ARRAY,
		"row_has_level": TYPE_PACKED_BYTE_ARRAY, "row_levels": TYPE_PACKED_STRING_ARRAY,
		"row_lean_milli": TYPE_PACKED_INT32_ARRAY,
	}
	for key in required_types:
		if typeof(packed.get(key, null)) != int(required_types[key]):
			return false
	var offsets: PackedInt32Array = packed.get("frame_offsets", PackedInt32Array())
	var descriptors: PackedStringArray = packed.get("body_ids", PackedStringArray())
	var rows: PackedInt32Array = packed.get("row_body_indices", PackedInt32Array())
	if offsets.size() != frame_count + 1 or offsets[0] != 0 or offsets[frame_count] != rows.size():
		return false
	for field in ["tick_offsets", "upper_phase_fp", "lower_phase_fp"]:
		if packed[field].size() != frame_count:
			return false
	for field in ["body_kinds", "body_radii", "body_heights", "body_masses", "body_metadata"]:
		if packed[field].size() != descriptors.size():
			return false
	for field in ["row_material_categories", "row_x", "row_y", "row_z", "row_radius", "row_height", "row_sleeping", "row_rest_states", "row_has_level", "row_levels", "row_lean_milli"]:
		if packed[field].size() != rows.size():
			return false
	return true


static func _step_action_dictionary_reference(state: Dictionary, config: Dictionary) -> Dictionary:
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
	if capture_trace:
		presentation_trace.append(_presentation_trace_frame(state, ACTION_TICKS + 1, []))
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


static func _step_action_hot(state: Dictionary, config: Dictionary) -> Dictionary:
	# Test-only timings are returned with the action result and never written into
	# authoritative state. Production calls perform no clock reads and return no
	# timing data.
	var debug_profile_stages := bool(config.get("_debug_profile_stages", false))
	var debug_stage_timing_usec: Dictionary = {
		"pack": 0,
		"push_integrate_48_ticks": 0,
		"collision_visited_setup": 0,
		"grid": 0,
		"collisions": 0,
		"supports": 0,
		"trace_construction": 0,
		"final_scan": 0,
		"writeback": 0,
		"solver_result_assembly": 0,
		"solver_total": 0,
	} if debug_profile_stages else {}
	var debug_total_started_usec := Time.get_ticks_usec() if debug_profile_stages else 0
	var debug_stage_started_usec := Time.get_ticks_usec() if debug_profile_stages else 0
	if config.has("captured_upper_phase_fp"):
		state["upper_phase_fp"] = posmod(int(config.get("captured_upper_phase_fp", 0)), PHASE_PERIOD)
	if config.has("captured_lower_phase_fp"):
		state["lower_phase_fp"] = posmod(int(config.get("captured_lower_phase_fp", 0)), PHASE_PERIOD)
	var hot := HotBodies.new()
	hot.load_from(state)
	if debug_profile_stages:
		debug_stage_timing_usec["pack"] = Time.get_ticks_usec() - debug_stage_started_usec
	var events: Array = []
	var motion_events: Array = []
	var motion_event_keys := {}
	var capture_trace := bool(config.get("capture_presentation_trace", false))
	var emit_presentation_events := bool(config.get("emit_presentation_events", true))
	var presentation_trace: Array = []
	var exit_trails: Array = []
	if capture_trace:
		debug_stage_started_usec = Time.get_ticks_usec() if debug_profile_stages else 0
		presentation_trace.append(_hot_presentation_trace_frame(hot, state, 0, []))
		if debug_profile_stages:
			debug_stage_timing_usec["trace_construction"] = Time.get_ticks_usec() - debug_stage_started_usec
	var start_x := hot.x.duplicate()
	var start_y := hot.y.duplicate()
	var start_z := hot.z.duplicate()
	var peak_z := hot.z.duplicate() if emit_presentation_events else PackedInt32Array()
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
	debug_stage_started_usec = Time.get_ticks_usec() if debug_profile_stages else 0
	var collision_visited := PackedInt32Array()
	collision_visited.resize(hot.size() * hot.size())
	if debug_profile_stages:
		debug_stage_timing_usec["collision_visited_setup"] = Time.get_ticks_usec() - debug_stage_started_usec
	debug_stage_started_usec = Time.get_ticks_usec() if debug_profile_stages else 0
	var hot_grid := HotGrid.new()
	if config.has("_debug_hot_grid_generation"):
		hot_grid.set_candidate_generation_for_test(int(config.get("_debug_hot_grid_generation", 0)))
	if debug_profile_stages:
		debug_stage_timing_usec["grid"] = Time.get_ticks_usec() - debug_stage_started_usec
	if nudge_x != 0 or nudge_y != 0:
		debug_stage_started_usec = Time.get_ticks_usec() if debug_profile_stages else 0
		wake_count += _hot_apply_nudge(hot, nudge_x, nudge_y, aimed_x, nudge_radius)
		if debug_profile_stages:
			debug_stage_timing_usec["push_integrate_48_ticks"] = Time.get_ticks_usec() - debug_stage_started_usec
	var integration_indices := PackedInt32Array()
	var awake_indices := PackedInt32Array()
	var support_indices := PackedInt32Array()
	var support_seen := PackedByteArray()
	support_seen.resize(hot.size())
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
		integration_indices.clear()
		debug_stage_started_usec = Time.get_ticks_usec() if debug_profile_stages else 0
		wake_count += _hot_apply_pushers(hot, old_upper, new_upper, old_lower, new_lower, push_scale, integration_indices)
		if not integration_indices.is_empty():
			_hot_integrate(hot, integration_indices, events, motion_events, motion_event_keys, peak_z, tick_index + 1, start_x, start_y, start_z)
		if debug_profile_stages:
			debug_stage_timing_usec["push_integrate_48_ticks"] = int(debug_stage_timing_usec.get("push_integrate_48_ticks", 0)) + Time.get_ticks_usec() - debug_stage_started_usec
		if not integration_indices.is_empty():
			debug_stage_started_usec = Time.get_ticks_usec() if debug_profile_stages else 0
			awake_indices.clear()
			var hot_sleeping := hot.sleeping
			for index in range(hot_sleeping.size()):
				if hot_sleeping[index] == 0:
					awake_indices.append(index)
			hot_grid.rebuild(hot)
			if debug_profile_stages:
				debug_stage_timing_usec["grid"] = int(debug_stage_timing_usec.get("grid", 0)) + Time.get_ticks_usec() - debug_stage_started_usec
			debug_stage_started_usec = Time.get_ticks_usec() if debug_profile_stages else 0
			support_indices.clear()
			support_indices.append_array(awake_indices)
			support_seen.fill(0)
			for awake_index in awake_indices:
				support_seen[int(awake_index)] = 1
			if debug_profile_stages:
				debug_stage_timing_usec["supports"] = int(debug_stage_timing_usec.get("supports", 0)) + Time.get_ticks_usec() - debug_stage_started_usec
			debug_stage_started_usec = Time.get_ticks_usec() if debug_profile_stages else 0
			for _pass_index in range(MAX_COLLISION_PASSES):
				var visit_generation := tick_index * MAX_COLLISION_PASSES + _pass_index + 1
				var resolved := _hot_resolve_collisions(hot, hot_grid, collision_visited, visit_generation, awake_indices, support_indices, support_seen)
				collision_count += resolved
				if resolved <= 0:
					break
			if debug_profile_stages:
				debug_stage_timing_usec["collisions"] = int(debug_stage_timing_usec.get("collisions", 0)) + Time.get_ticks_usec() - debug_stage_started_usec
			debug_stage_started_usec = Time.get_ticks_usec() if debug_profile_stages else 0
			support_indices.sort()
			_hot_resolve_supports(hot, hot_grid, support_indices, motion_events, motion_event_keys, peak_z, tick_index + 1)
			if debug_profile_stages:
				debug_stage_timing_usec["supports"] = int(debug_stage_timing_usec.get("supports", 0)) + Time.get_ticks_usec() - debug_stage_started_usec
		state["tick"] = int(state.get("tick", 0)) + 1
		if capture_trace:
			debug_stage_started_usec = Time.get_ticks_usec() if debug_profile_stages else 0
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
				presentation_trace.append(_hot_presentation_trace_frame(hot, state, tick_index + 1, exit_views))
			if debug_profile_stages:
				debug_stage_timing_usec["trace_construction"] = int(debug_stage_timing_usec.get("trace_construction", 0)) + Time.get_ticks_usec() - debug_stage_started_usec
	debug_stage_started_usec = Time.get_ticks_usec() if debug_profile_stages else 0
	var moved_count := 0
	for index in range(hot.size()):
		if absi(start_x[index] - hot.x[index]) > 180 or absi(start_y[index] - hot.y[index]) > 180 or absi(start_z[index] - hot.z[index]) > 180:
			moved_count += 1
	if debug_profile_stages:
		debug_stage_timing_usec["final_scan"] = Time.get_ticks_usec() - debug_stage_started_usec
	debug_stage_started_usec = Time.get_ticks_usec() if debug_profile_stages else 0
	hot.write_back(state)
	if debug_profile_stages:
		debug_stage_timing_usec["writeback"] = Time.get_ticks_usec() - debug_stage_started_usec
	if capture_trace:
		debug_stage_started_usec = Time.get_ticks_usec() if debug_profile_stages else 0
		presentation_trace.append(_presentation_trace_frame(state, ACTION_TICKS + 1, []))
		if debug_profile_stages:
			debug_stage_timing_usec["trace_construction"] = int(debug_stage_timing_usec.get("trace_construction", 0)) + Time.get_ticks_usec() - debug_stage_started_usec
	debug_stage_started_usec = Time.get_ticks_usec() if debug_profile_stages else 0
	var awake_count := 0
	var sleeping := hot.sleeping
	for index in range(sleeping.size()):
		if sleeping[index] == 0:
			awake_count += 1
	var topple_count := 0
	var upper_lower_fall_count := 0
	for event_index in range(motion_events.size()):
		var motion_value: Variant = motion_events[event_index]
		if typeof(motion_value) != TYPE_DICTIONARY:
			continue
		var motion_kind := str((motion_value as Dictionary).get("kind", ""))
		if motion_kind == "topple":
			topple_count += 1
		elif motion_kind == "upper_to_lower":
			upper_lower_fall_count += 1
	state["last_events"] = events
	state["last_motion_events"] = motion_events
	state["last_step_metrics"] = {
		"fixed_ticks": ACTION_TICKS,
		"body_count": hot.size(),
		"awake_count": awake_count,
		"woken_count": wake_count,
		"moved_count": moved_count,
		"collision_passes": MAX_COLLISION_PASSES,
		"collision_count": collision_count,
		"topple_count": topple_count,
		"upper_lower_fall_count": upper_lower_fall_count,
	}
	var presentation_events := _hot_presentation_event_views(hot, events, motion_events, state["last_step_metrics"], config) if emit_presentation_events else []
	var result := {
		"events": events,
		"motion_events": motion_events,
		"presentation_events": presentation_events,
		"metrics": state["last_step_metrics"],
		"presentation_trace": presentation_trace,
	}
	if debug_profile_stages:
		debug_stage_timing_usec["solver_result_assembly"] = Time.get_ticks_usec() - debug_stage_started_usec
		debug_stage_timing_usec["solver_total"] = Time.get_ticks_usec() - debug_total_started_usec
		result["debug_stage_timing_usec"] = debug_stage_timing_usec
	return result


static func apply_nudge_only(state: Dictionary, x_impulse: int, y_impulse: int, aimed_x: int, radius: int) -> int:
	return _apply_nudge(state, x_impulse, y_impulse, aimed_x, radius)


static func _hot_apply_nudge(hot: HotBodies, x_impulse: int, y_impulse: int, aimed_x: int, radius: int) -> int:
	var count := 0
	var xs := hot.x
	var vxs := hot.vx
	var vys := hot.vy
	var masses := hot.masses
	var sleeping := hot.sleeping
	var sleep_ticks := hot.sleep_ticks
	var rest_states := hot.rest_states
	for index in range(xs.size()):
		if absi(xs[index] - aimed_x) > radius:
			continue
		var mass := maxi(1, masses[index])
		vxs[index] += _divi(x_impulse, mass)
		vys[index] += _divi(y_impulse, mass)
		sleeping[index] = 0
		sleep_ticks[index] = 0
		rest_states[index] = "settling"
		count += 1
	hot.vx = vxs
	hot.vy = vys
	hot.sleeping = sleeping
	hot.sleep_ticks = sleep_ticks
	return count


static func _hot_apply_pushers(hot: HotBodies, old_upper: int, new_upper: int, old_lower: int, new_lower: int, push_scale: int, active_indices: PackedInt32Array) -> int:
	var upper_active := new_upper < old_upper
	var lower_active := new_lower < old_lower
	var count := 0
	var ys := hot.y
	var zs := hot.z
	var vys := hot.vy
	var radii := hot.radii
	var heights := hot.heights
	var sleeping := hot.sleeping
	var sleep_ticks := hot.sleep_ticks
	var rest_states := hot.rest_states
	for index in range(ys.size()):
		var body_y := ys[index]
		var body_z := zs[index]
		var upper := body_y >= UPPER_EDGE and body_z >= UPPER_FLOOR_Z
		var active := upper_active if upper else lower_active
		var old_face := old_upper if upper else old_lower
		var new_face := new_upper if upper else new_lower
		var floor_z := UPPER_FLOOR_Z if upper else LOWER_FLOOR_Z
		var eligible := active and (upper or (body_y >= FRONT_EDGE and body_y < UPPER_EDGE and body_z < UPPER_FLOOR_Z + COIN_HEIGHT))
		if eligible and body_y > new_face - radii[index] and body_y < old_face + radii[index] and body_z <= floor_z + heights[index] * 5:
			ys[index] = mini(body_y, new_face - radii[index])
			vys[index] -= (old_face - new_face) * push_scale
			sleeping[index] = 0
			sleep_ticks[index] = 0
			rest_states[index] = "settling"
			count += 1
		if sleeping[index] == 0:
			active_indices.append(index)
	hot.y = ys
	hot.vy = vys
	hot.sleeping = sleeping
	hot.sleep_ticks = sleep_ticks
	return count


static func _hot_append_impact_motion_event(events: Array, event_keys: Dictionary, hot: HotBodies, index: int, material: String, stack_depth: int, fall_height: int, tick_offset: int) -> void:
	var body_id := str(hot.ids[index])
	var event_key := "impact|%s" % body_id
	if body_id.is_empty() or event_keys.has(event_key):
		return
	events.append({
		"kind": "impact", "body_id": body_id,
		"x": hot.x[index], "y": hot.y[index], "z": hot.z[index],
		"tick_offset": tick_offset, "material": material,
		"stack_depth": maxi(0, stack_depth),
		"fall_height_milli": maxi(0, _divi(fall_height * FP, COIN_HEIGHT)),
	})
	event_keys[event_key] = true


static func _hot_integrate(hot: HotBodies, active_indices: PackedInt32Array, events: Array, motion_events: Array, motion_event_keys: Dictionary, peak_z: PackedInt32Array, tick_offset: int, start_x: PackedInt32Array, start_y: PackedInt32Array, start_z: PackedInt32Array) -> void:
	var exit_indices := PackedInt32Array()
	var body_count := hot.size()
	var xs := hot.x
	var ys := hot.y
	var zs := hot.z
	var vxs := hot.vx
	var vys := hot.vy
	var vzs := hot.vz
	var radii := hot.radii
	var masses := hot.masses
	var ids := hot.ids
	var kinds := hot.kinds
	var metadata := hot.metadata
	var sleeping := hot.sleeping
	var sleep_ticks := hot.sleep_ticks
	var rest_states := hot.rest_states
	var pressure_ticks := hot.cap_pressure_ticks
	var pressure_accel := hot.cap_pressure_accel
	for active_position in range(active_indices.size()):
		var index := active_indices[active_position]
		if index < 0 or index >= body_count:
			continue
		var previous_z := zs[index]
		if not peak_z.is_empty():
			peak_z[index] = maxi(peak_z[index], previous_z)
		if pressure_ticks[index] > 0:
			vys[index] -= maxi(0, pressure_accel[index])
			pressure_ticks[index] -= 1
		var was_upper := zs[index] >= UPPER_FLOOR_Z
		vzs[index] -= GRAVITY
		vxs[index] = _divi(vxs[index] * AIR_DRAG_NUM, AIR_DRAG_DEN)
		vys[index] = _divi(vys[index] * AIR_DRAG_NUM, AIR_DRAG_DEN)
		xs[index] += _divi(vxs[index], FIXED_HZ)
		ys[index] += _divi(vys[index], FIXED_HZ)
		zs[index] += _divi(vzs[index], FIXED_HZ)
		var exit := ""
		if xs[index] < -radii[index] or xs[index] > WIDTH + radii[index]:
			exit = "gutter"
		elif ys[index] < FRONT_EDGE - radii[index]:
			exit = "tray" if xs[index] >= TRAY_LEFT and xs[index] <= TRAY_RIGHT else "gutter"
		if not exit.is_empty():
			events.append({
				"body_id": str(ids[index]), "kind": str(kinds[index]),
				"outcome": exit, "cause": "physical_fall",
				"x": xs[index], "y": ys[index], "z": zs[index],
				"mass": masses[index], "tick_offset": tick_offset,
				"metadata": (metadata[index] as Dictionary).duplicate(true),
			})
			exit_indices.append(index)
			continue
		var base_z := UPPER_FLOOR_Z if ys[index] >= UPPER_EDGE else LOWER_FLOOR_Z
		if was_upper and ys[index] < UPPER_EDGE:
			motion_events.append({"kind": "upper_to_lower", "body_id": str(ids[index]), "x": xs[index], "y": ys[index], "z": zs[index], "tick_offset": tick_offset})
		if zs[index] <= base_z:
			var fall_height := maxi(0, (peak_z[index] if not peak_z.is_empty() else previous_z) - base_z)
			if not peak_z.is_empty() and previous_z > base_z and fall_height > 0:
				_hot_append_impact_motion_event(motion_events, motion_event_keys, hot, index, "coin_on_metal", 0, fall_height, tick_offset)
			zs[index] = base_z
			vzs[index] = 0
			vxs[index] = _divi(vxs[index] * FLOOR_DRAG_NUM, FLOOR_DRAG_DEN)
			vys[index] = _divi(vys[index] * FLOOR_DRAG_NUM, FLOOR_DRAG_DEN)
			var speed := absi(vxs[index]) + absi(vys[index]) + absi(vzs[index])
			if speed <= SLEEP_SPEED:
				sleep_ticks[index] += 1
				if sleep_ticks[index] >= SLEEP_TICKS:
					vxs[index] = 0
					vys[index] = 0
					vzs[index] = 0
					sleeping[index] = 1
					rest_states[index] = "resting"
			else:
				sleep_ticks[index] = 0
				rest_states[index] = "settling"
		else:
			rest_states[index] = "falling"
			sleep_ticks[index] = 0
	hot.x = xs
	hot.y = ys
	hot.z = zs
	hot.vx = vxs
	hot.vy = vys
	hot.vz = vzs
	hot.sleeping = sleeping
	hot.sleep_ticks = sleep_ticks
	hot.cap_pressure_ticks = pressure_ticks
	for exit_position in range(exit_indices.size() - 1, -1, -1):
		var exit_index := exit_indices[exit_position]
		hot.remove_at(exit_index)
		start_x.remove_at(exit_index)
		start_y.remove_at(exit_index)
		start_z.remove_at(exit_index)
		if not peak_z.is_empty():
			peak_z.remove_at(exit_index)


static func _hot_resolve_collisions(hot: HotBodies, grid: HotGrid, visited_pairs: PackedInt32Array, visit_generation: int, awake_indices: PackedInt32Array, support_indices: PackedInt32Array, support_seen: PackedByteArray) -> int:
	if awake_indices.is_empty():
		return 0
	var resolved := 0
	var body_count := hot.size()
	# Hoist the reference-backed packed columns once for the dense pair loop.
	# This preserves candidate/pair order while avoiding object-property
	# dispatch for every scalar read and write; the final assignments make the
	# column publication explicit for static readers.
	var xs := hot.x
	var ys := hot.y
	var zs := hot.z
	var vxs := hot.vx
	var vys := hot.vy
	var radii := hot.radii
	var heights := hot.heights
	var sleeping := hot.sleeping
	var sleep_ticks := hot.sleep_ticks
	var rest_states := hot.rest_states
	for awake_position in range(awake_indices.size()):
		var left_index := awake_indices[awake_position]
		var center_x := _divi(xs[left_index], BROADPHASE_CELL)
		var center_y := _divi(ys[left_index], BROADPHASE_CELL)
		var center_z := _divi(zs[left_index], BROADPHASE_CELL)
		var cache_slot := grid.candidate_slot(center_x, center_y, center_z)
		var candidate_offset := grid.candidate_offsets[cache_slot]
		var candidate_length := grid.candidate_lengths[cache_slot]
		for candidate_position in range(candidate_length):
			var right_index := grid.candidate_pool[candidate_offset + candidate_position]
			if right_index == left_index:
				continue
			var low := mini(left_index, right_index)
			var high := maxi(left_index, right_index)
			var pair_key := low * body_count + high
			if visited_pairs[pair_key] == visit_generation:
				continue
			visited_pairs[pair_key] = visit_generation
			var dx := xs[right_index] - xs[left_index]
			var dy := ys[right_index] - ys[left_index]
			var min_distance := radii[left_index] + radii[right_index]
			if absi(dx) >= min_distance or absi(dy) >= min_distance or dx * dx + dy * dy >= min_distance * min_distance:
				continue
			var z_gap := absi(zs[left_index] - zs[right_index])
			if z_gap >= mini(heights[left_index], heights[right_index]):
				continue
			var overlap := min_distance - maxi(absi(dx), absi(dy))
			if overlap <= 0:
				continue
			if absi(dx) >= absi(dy):
				var sign_x := 1 if dx >= 0 else -1
				xs[right_index] += _divi(sign_x * overlap, 2)
				xs[left_index] -= _divi(sign_x * overlap, 2)
				vxs[right_index] += sign_x * overlap * 5
				vxs[left_index] -= sign_x * overlap * 5
			else:
				var sign_y := 1 if dy >= 0 else -1
				ys[right_index] += _divi(sign_y * overlap, 2)
				ys[left_index] -= _divi(sign_y * overlap, 2)
				vys[right_index] += sign_y * overlap * 5
				vys[left_index] -= sign_y * overlap * 5
			if sleeping[right_index] != 0 and support_seen[right_index] == 0:
				support_seen[right_index] = 1
				support_indices.append(right_index)
			sleeping[left_index] = 0
			sleep_ticks[left_index] = 0
			rest_states[left_index] = "settling"
			sleeping[right_index] = 0
			sleep_ticks[right_index] = 0
			rest_states[right_index] = "settling"
			resolved += 1
	hot.x = xs
	hot.y = ys
	hot.vx = vxs
	hot.vy = vys
	hot.sleeping = sleeping
	hot.sleep_ticks = sleep_ticks
	return resolved


static func _hot_resolve_supports(hot: HotBodies, grid: HotGrid, active_indices: PackedInt32Array, motion_events: Array, motion_event_keys: Dictionary, peak_z: PackedInt32Array, tick_offset: int) -> void:
	var body_count := hot.size()
	var xs := hot.x
	var ys := hot.y
	var zs := hot.z
	var vxs := hot.vx
	var vys := hot.vy
	var vzs := hot.vz
	var radii := hot.radii
	var heights := hot.heights
	var ids := hot.ids
	var lean_values := hot.lean
	var sleeping := hot.sleeping
	var sleep_ticks := hot.sleep_ticks
	var rest_states := hot.rest_states
	for active_position in range(active_indices.size()):
		var body_index := active_indices[active_position]
		if body_index < 0 or body_index >= body_count:
			continue
		var base_z := UPPER_FLOOR_Z if ys[body_index] >= UPPER_EDGE else LOWER_FLOOR_Z
		if zs[body_index] <= base_z:
			lean_values[body_index] = 0
			continue
		var support_index := -1
		var support_distance := 1 << 30
		var center_x := _divi(xs[body_index], BROADPHASE_CELL)
		var center_y := _divi(ys[body_index], BROADPHASE_CELL)
		var center_z := _divi(zs[body_index], BROADPHASE_CELL)
		var cache_slot := grid.candidate_slot(center_x, center_y, center_z)
		var candidate_offset := grid.candidate_offsets[cache_slot]
		var candidate_length := grid.candidate_lengths[cache_slot]
		for candidate_position in range(candidate_length):
			var candidate_index := grid.candidate_pool[candidate_offset + candidate_position]
			if candidate_index == body_index:
				continue
			var candidate_target_z := zs[candidate_index] + heights[candidate_index]
			if candidate_target_z > zs[body_index] + COIN_HEIGHT or candidate_target_z < zs[body_index] - COIN_HEIGHT * 2:
				continue
			var candidate_dx := xs[body_index] - xs[candidate_index]
			var candidate_dy := ys[body_index] - ys[candidate_index]
			var distance := candidate_dx * candidate_dx + candidate_dy * candidate_dy
			var support_radius := mini(radii[body_index], radii[candidate_index])
			if distance < support_radius * support_radius and distance < support_distance:
				support_index = candidate_index
				support_distance = distance
		if support_index < 0:
			rest_states[body_index] = "falling"
			sleeping[body_index] = 0
			continue
		var target_z := zs[support_index] + heights[support_index]
		if vzs[body_index] <= 0 and zs[body_index] <= target_z + COIN_HEIGHT:
			var fall_height := maxi(0, (peak_z[body_index] if not peak_z.is_empty() else zs[body_index]) - target_z)
			if not peak_z.is_empty() and fall_height > 0:
				var stack_depth := maxi(1, _divi(target_z - base_z, COIN_HEIGHT))
				_hot_append_impact_motion_event(motion_events, motion_event_keys, hot, body_index, "coin_on_coin", stack_depth, fall_height, tick_offset)
			zs[body_index] = target_z
			vzs[body_index] = 0
			var dx := xs[body_index] - xs[support_index]
			var dy := ys[body_index] - ys[support_index]
			var lean := _divi(maxi(absi(dx), absi(dy)) * FP, maxi(1, radii[body_index]))
			lean_values[body_index] = lean
			if lean > 620:
				var topple_key := "topple|%s" % str(ids[body_index])
				if not motion_event_keys.has(topple_key):
					motion_events.append({"kind": "topple", "body_id": str(ids[body_index]), "support_id": str(ids[support_index]), "lean_milli": lean})
					motion_event_keys[topple_key] = true
				vxs[body_index] += 120 if dx >= 0 else -120
				vys[body_index] += 120 if dy >= 0 else -120
				zs[body_index] = target_z + 80
				rest_states[body_index] = "toppling"
				sleeping[body_index] = 0
			else:
				var speed := absi(vxs[body_index]) + absi(vys[body_index]) + absi(vzs[body_index])
				if speed <= SLEEP_SPEED:
					sleep_ticks[body_index] += 1
					if sleep_ticks[body_index] >= SLEEP_TICKS:
						vxs[body_index] = 0
						vys[body_index] = 0
						vzs[body_index] = 0
						sleeping[body_index] = 1
						rest_states[body_index] = "resting"
				else:
					sleep_ticks[body_index] = 0
					sleeping[body_index] = 0
					rest_states[body_index] = "settling"
	hot.z = zs
	hot.vx = vxs
	hot.vy = vys
	hot.vz = vzs
	hot.lean = lean_values
	hot.sleeping = sleeping
	hot.sleep_ticks = sleep_ticks


static func _hot_body_views(hot: HotBodies) -> Array:
	var result: Array = []
	for index in range(hot.size()):
		var kind := str(hot.kinds[index])
		result.append({
			"id": str(hot.ids[index]), "kind": kind,
			"material_category": "coin" if kind == "coin" else "feature_puck" if kind == "puck" else "key_fragment" if kind == "fragment" else "prize_rider" if kind == "rider" else "physical_object",
			"x": hot.x[index], "y": hot.y[index], "z": hot.z[index],
			"radius": hot.radii[index], "height": hot.heights[index], "mass": hot.masses[index],
			"sleeping": hot.sleeping[index] != 0, "rest_state": str(hot.rest_states[index]),
			"level": "upper" if hot.y[index] >= UPPER_EDGE and hot.z[index] >= UPPER_FLOOR_Z else "lower" if hot.y[index] >= FRONT_EDGE and hot.z[index] >= LOWER_FLOOR_Z and hot.z[index] < UPPER_FLOOR_Z else "falling",
			"lean_milli": hot.lean[index], "metadata": (hot.metadata[index] as Dictionary).duplicate(true),
		})
	result.sort_custom(_body_view_depth_before)
	return result


static func _hot_presentation_trace_frame(hot: HotBodies, state: Dictionary, tick_offset: int, exit_views: Array) -> Dictionary:
	var bodies := _hot_body_views(hot)
	if not exit_views.is_empty():
		bodies.append_array(exit_views)
		bodies.sort_custom(_body_view_depth_before)
	return {
		"tick_offset": tick_offset,
		"upper_phase_fp": int(state.get("upper_phase_fp", 0)),
		"lower_phase_fp": int(state.get("lower_phase_fp", 0)),
		"bodies": bodies,
	}


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
	# Generation owns the depth gradient. Fixed quotas make every shipped
	# cabinet visibly packed at the pusher and progressively thinner toward the
	# ledge, while best-candidate placement and stack lean remain run-seeded.
	var shelf_specs := [
		{"id": "lower", "min_y": 8500, "max_y": 48500, "upper": false},
		{"id": "upper", "min_y": 55000, "max_y": 92500, "upper": true},
	]
	var shelf_targets := _opening_balanced_counts(opening_coins, shelf_specs.size())
	var shelf_base_targets := _opening_balanced_counts(mini(opening_coins, 110), shelf_specs.size())
	var shelf_supports: Array = []
	var shelf_depth_targets: Array = []
	var shelf_base_depth_targets: Array = []
	for shelf_index in range(shelf_specs.size()):
		var shelf: Dictionary = shelf_specs[shelf_index]
		var depth_targets := _opening_gradient_targets(int(shelf_targets[shelf_index]))
		var base_depth_targets := _opening_scaled_targets(depth_targets, int(shelf_base_targets[shelf_index]))
		var bands := _opening_depth_bands(shelf)
		var supports := {"rear": [], "mid": [], "front": []}
		for band_value in bands:
			var band: Dictionary = band_value
			var band_id := str(band.get("id", "front"))
			var band_bodies: Array = []
			for _coin_index in range(int(base_depth_targets.get(band_id, 0))):
				var candidate := _opening_best_candidate(rng, band, band_bodies)
				var base_z := UPPER_FLOOR_Z if bool(shelf.get("upper", false)) else LOWER_FLOOR_Z
				var body := _body(state, "coin", candidate.x, candidate.y, base_z, COIN_RADIUS, COIN_HEIGHT, 1, {
					"opening_pile": true,
					"opening_shelf": str(shelf.get("id", "lower")),
					"opening_depth_band": band_id,
				})
				_set_opening_body_rest(body)
				(state["bodies"] as Array).append(body)
				band_bodies.append(body)
				(supports[band_id] as Array).append(body)
		shelf_supports.append(supports)
		shelf_depth_targets.append(depth_targets)
		shelf_base_depth_targets.append(base_depth_targets)
	var stack_layers := {}
	for shelf_index in range(shelf_specs.size()):
		var shelf: Dictionary = shelf_specs[shelf_index]
		var bands := _opening_depth_bands(shelf)
		var supports: Dictionary = shelf_supports[shelf_index]
		var depth_targets: Dictionary = shelf_depth_targets[shelf_index]
		var base_depth_targets: Dictionary = shelf_base_depth_targets[shelf_index]
		for band_value in bands:
			var band: Dictionary = band_value
			var band_id := str(band.get("id", "front"))
			var stack_count := int(depth_targets.get(band_id, 0)) - int(base_depth_targets.get(band_id, 0))
			for _stack_index in range(stack_count):
				var candidates: Array = []
				for support_value in supports.get(band_id, []):
					var support: Dictionary = support_value
					if int(stack_layers.get(str(support.get("id", "")), 0)) < 2:
						candidates.append(support)
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
					clampi(int(support.get("y", 0)) + lean_y, int(band.get("min_y", FRONT_EDGE)), int(band.get("max_y", REAR_EDGE))),
					int(support.get("z", 0)) + layer * COIN_HEIGHT,
					COIN_RADIUS,
					COIN_HEIGHT,
					1,
					{
						"opening_pile": true,
						"opening_shelf": str(shelf.get("id", "lower")),
						"opening_depth_band": band_id,
						"opening_stack_layer": layer,
					}
				)
				stacked["lean_milli"] = _divi(maxi(absi(lean_x), absi(lean_y)) * FP, COIN_RADIUS)
				_set_opening_body_rest(stacked)
				(state["bodies"] as Array).append(stacked)


static func _opening_balanced_counts(total: int, bucket_count: int) -> Array:
	var result: Array = []
	for bucket_index in range(maxi(1, bucket_count)):
		var count := maxi(0, total) / maxi(1, bucket_count)
		if bucket_index < maxi(0, total) % maxi(1, bucket_count):
			count += 1
		result.append(count)
	return result


static func _opening_gradient_targets(total: int) -> Dictionary:
	var safe_total := maxi(0, total)
	if safe_total < 6:
		var front_small := safe_total / 5
		var mid_small := safe_total / 3
		return {"rear": safe_total - front_small - mid_small, "mid": mid_small, "front": front_small}
	var front := maxi(1, safe_total / 5)
	var mid := maxi(front + 1, safe_total / 3)
	var rear := safe_total - front - mid
	while rear <= mid and front > 1:
		front -= 1
		rear += 1
	while rear <= mid and mid > front + 1:
		mid -= 1
		rear += 1
	return {"rear": rear, "mid": mid, "front": front}


static func _opening_scaled_targets(full_targets: Dictionary, total: int) -> Dictionary:
	var full_total := maxi(1, int(full_targets.get("rear", 0)) + int(full_targets.get("mid", 0)) + int(full_targets.get("front", 0)))
	var result := {"rear": 0, "mid": 0, "front": 0}
	for band_id in ["rear", "mid", "front"]:
		result[band_id] = mini(
			int(full_targets.get(band_id, 0)),
			_opening_mul_div_round(int(full_targets.get(band_id, 0)), clampi(total, 0, full_total), full_total)
		)
	var assigned := int(result.get("rear", 0)) + int(result.get("mid", 0)) + int(result.get("front", 0))
	while assigned < total:
		for band_id in ["rear", "mid", "front"]:
			if assigned >= total:
				break
			if int(result.get(band_id, 0)) < int(full_targets.get(band_id, 0)):
				result[band_id] = int(result.get(band_id, 0)) + 1
				assigned += 1
	while assigned > total:
		for band_id in ["front", "mid", "rear"]:
			if assigned <= total:
				break
			if int(result.get(band_id, 0)) > 0:
				result[band_id] = int(result.get(band_id, 0)) - 1
				assigned -= 1
	return result


static func _opening_mul_div_round(value: int, multiplier: int, divisor: int) -> int:
	# Exact quotient/remainder accumulation avoids an overflowing value*multiplier
	# numerator. Rounding is the deterministic integer half-denominator rule.
	var safe_divisor := maxi(1, divisor)
	var remaining := clampi(multiplier, 0, safe_divisor)
	var term_quotient := clampi(value, 0, safe_divisor) / safe_divisor
	var term_remainder := clampi(value, 0, safe_divisor) % safe_divisor
	var result_quotient := 0
	var result_remainder := 0
	while remaining > 0:
		if (remaining & 1) != 0:
			var remainder_gap := safe_divisor - term_remainder
			if result_remainder >= remainder_gap:
				result_remainder -= remainder_gap
				result_quotient += term_quotient + 1
			else:
				result_remainder += term_remainder
				result_quotient += term_quotient
		remaining = remaining >> 1
		if remaining <= 0:
			break
		var doubled_remainder_gap := safe_divisor - term_remainder
		if term_remainder >= doubled_remainder_gap:
			term_remainder -= doubled_remainder_gap
			term_quotient = term_quotient * 2 + 1
		else:
			term_remainder += term_remainder
			term_quotient *= 2
	var half_denominator := safe_divisor / 2 + safe_divisor % 2
	return result_quotient + (1 if result_remainder >= half_denominator else 0)


static func _opening_depth_bands(shelf: Dictionary) -> Array:
	var min_y := int(shelf.get("min_y", FRONT_EDGE))
	var max_y := maxi(min_y + 2, int(shelf.get("max_y", UPPER_EDGE - COIN_RADIUS)))
	var span := max_y - min_y + 1
	var mid_start := min_y + span / 3
	var rear_start := min_y + span * 2 / 3
	return [
		{"id": "rear", "min_y": rear_start, "max_y": max_y},
		{"id": "mid", "min_y": mid_start, "max_y": rear_start - 1},
		{"id": "front", "min_y": min_y, "max_y": mid_start - 1},
	]


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
		if not body.has("kind"):
			body["kind"] = "coin"
		if not body.has("rest_state"):
			body["rest_state"] = "settling"
		if not body.has("lean_milli"):
			body["lean_milli"] = 0
		if not body.has("metadata") or typeof(body.get("metadata")) != TYPE_DICTIONARY:
			body["metadata"] = {}
		body["x"] = int(body.get("x", 0))
		body["y"] = int(body.get("y", 0))
		body["z"] = int(body.get("z", 0))
		body["vx"] = int(body.get("vx", 0))
		body["vy"] = int(body.get("vy", 0))
		body["vz"] = int(body.get("vz", 0))
		body["radius"] = int(body.get("radius", COIN_RADIUS))
		body["height"] = int(body.get("height", COIN_HEIGHT))
		body["mass"] = int(body.get("mass", 1))
		body["sleep_ticks"] = int(body.get("sleep_ticks", 0))
		body["sleeping"] = bool(body.get("sleeping", false))
		body["rest_state"] = str(body.get("rest_state", "settling"))
		body["lean_milli"] = int(body.get("lean_milli", 0))
		if body.has("cap_pressure_ticks"):
			body["cap_pressure_ticks"] = int(body.get("cap_pressure_ticks", 0))
		if body.has("cap_pressure_accel"):
			body["cap_pressure_accel"] = int(body.get("cap_pressure_accel", 0))


static func _hot_state_requires_reference(state: Dictionary, config: Dictionary = {}) -> bool:
	var bodies: Array = state.get("bodies", []) if typeof(state.get("bodies", [])) == TYPE_ARRAY else []
	if bodies.size() > HOT_BODY_COUNT_LIMIT:
		return true
	if not config.has("captured_upper_phase_fp"):
		var upper_phase := int(state.get("upper_phase_fp", 0))
		if upper_phase < 0 or upper_phase >= PHASE_PERIOD:
			return true
	if not config.has("captured_lower_phase_fp"):
		var lower_phase := int(state.get("lower_phase_fp", 0))
		if lower_phase < 0 or lower_phase >= PHASE_PERIOD:
			return true
	for config_key in ["nudge_x", "nudge_y", "aimed_x", "nudge_radius"]:
		var config_value := int(config.get(config_key, 0))
		if config_value < -HOT_CONFIG_IMPULSE_ABS_LIMIT or config_value > HOT_CONFIG_IMPULSE_ABS_LIMIT:
			return true
	var requested_push_scale := int(config.get("push_scale", 1))
	if requested_push_scale < -HOT_PUSH_SCALE_ABS_LIMIT or requested_push_scale > HOT_PUSH_SCALE_ABS_LIMIT:
		return true
	var seen_ids := {}
	for body_value in bodies:
		if typeof(body_value) != TYPE_DICTIONARY:
			return true
		var body_id := str((body_value as Dictionary).get("id", ""))
		if seen_ids.has(body_id):
			return true
		seen_ids[body_id] = true
		var body: Dictionary = body_value
		for position_key in ["x", "y", "z"]:
			var position_value := int(body.get(position_key, 0))
			if position_value < -HOT_POSITION_ABS_LIMIT or position_value > HOT_POSITION_ABS_LIMIT:
				return true
		for velocity_key in ["vx", "vy", "vz"]:
			var velocity_value := int(body.get(velocity_key, 0))
			if velocity_value < -HOT_VELOCITY_ABS_LIMIT or velocity_value > HOT_VELOCITY_ABS_LIMIT:
				return true
		var radius := int(body.get("radius", COIN_RADIUS))
		var height := int(body.get("height", COIN_HEIGHT))
		if radius <= 0 or radius > HOT_DIMENSION_LIMIT or height <= 0 or height > HOT_DIMENSION_LIMIT:
			return true
		for scalar_key in ["mass", "sleep_ticks", "lean_milli", "cap_pressure_ticks"]:
			var scalar_value := int(body.get(scalar_key, 0))
			if scalar_value < -HOT_GENERAL_SCALAR_ABS_LIMIT or scalar_value > HOT_GENERAL_SCALAR_ABS_LIMIT:
				return true
		var pressure_accel := int(body.get("cap_pressure_accel", 0))
		if pressure_accel < -HOT_PRESSURE_ACCEL_ABS_LIMIT or pressure_accel > HOT_PRESSURE_ACCEL_ABS_LIMIT:
			return true
		var center_x := _divi(int(body.get("x", 0)), BROADPHASE_CELL)
		var center_y := _divi(int(body.get("y", 0)), BROADPHASE_CELL)
		var center_z := _divi(int(body.get("z", 0)), BROADPHASE_CELL)
		var low_key := _bucket_key(center_x - 1, center_y - 1, center_z - 1)
		var high_key := _bucket_key(center_x + 1, center_y + 1, center_z + 1)
		if low_key < 0 or high_key >= HOT_GRID_KEY_CAPACITY:
			return true
	return false


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


static func _hot_presentation_event_views(hot: HotBodies, exits: Array, motion_events: Array, metrics: Dictionary, config: Dictionary) -> Array:
	var result: Array = []
	var focus_index := -1
	var sleeping := hot.sleeping
	for index in range(sleeping.size()):
		if sleeping[index] == 0:
			focus_index = index
			break
	if focus_index < 0 and hot.size() > 0:
		focus_index = 0
	var moved_count := int(metrics.get("moved_count", 0))
	if moved_count > 1:
		result.append(_hot_presentation_event("slide", hot, focus_index, mini(1000, 180 + moved_count * 24), ACTION_TICKS / 2, {"moved_count": moved_count}))
	var body_index_by_id := {}
	var ids := hot.ids
	if not motion_events.is_empty():
		for index in range(ids.size()):
			body_index_by_id[str(ids[index])] = index
	for motion_index in range(motion_events.size()):
		var motion_value: Variant = motion_events[motion_index]
		if typeof(motion_value) != TYPE_DICTIONARY:
			continue
		var motion: Dictionary = motion_value
		var kind := str(motion.get("kind", ""))
		var intensity := 720 if kind == "topple" else 820
		if kind == "impact":
			intensity = mini(1000, 320 + int(motion.get("fall_height_milli", 0)) / 8 + int(motion.get("stack_depth", 0)) * 70)
		var body_index := int(body_index_by_id.get(str(motion.get("body_id", "")), -1))
		if body_index >= 0:
			result.append(_hot_presentation_event(kind, hot, body_index, intensity, int(motion.get("tick_offset", ACTION_TICKS / 2)), motion))
		else:
			result.append(_presentation_event(kind, motion, intensity, int(motion.get("tick_offset", ACTION_TICKS / 2)), motion))
	var tray_total := 0
	var gutter_total := 0
	for exit_index in range(exits.size()):
		var exit_value: Variant = exits[exit_index]
		if typeof(exit_value) != TYPE_DICTIONARY:
			continue
		if str((exit_value as Dictionary).get("outcome", "gutter")) == "tray":
			tray_total += 1
		else:
			gutter_total += 1
	var tray_index := 0
	var gutter_index := 0
	for exit_index in range(exits.size()):
		var exit_value: Variant = exits[exit_index]
		if typeof(exit_value) != TYPE_DICTIONARY:
			continue
		var exit_event: Dictionary = exit_value
		var outcome := str(exit_event.get("outcome", "gutter"))
		var tick_offset := int(exit_event.get("tick_offset", ACTION_TICKS))
		var group_index := tray_index if outcome == "tray" else gutter_index
		var group_count := tray_total if outcome == "tray" else gutter_total
		if outcome == "tray":
			tray_index += 1
		else:
			gutter_index += 1
		result.append(_presentation_event("ledge_tip", exit_event, 760, maxi(0, tick_offset - 3), {"outcome": outcome}))
		result.append(_presentation_event("tray_landing" if outcome == "tray" else "gutter_loss", exit_event, mini(1000, 450 + int(exit_event.get("mass", 1)) * 110), tick_offset, {
			"outcome": outcome,
			"group_count": group_count,
			"group_index": group_index,
		}))
	if int(config.get("nudge_x", 0)) != 0 or int(config.get("nudge_y", 0)) != 0:
		result.append(_hot_presentation_event("cabinet_shake", hot, focus_index, mini(1000, (absi(int(config.get("nudge_x", 0))) + absi(int(config.get("nudge_y", 0)))) / 24), 1, {}))
	return result


static func _hot_presentation_event(kind: String, hot: HotBodies, body_index: int, intensity_milli: int, tick_offset: int, metadata: Dictionary) -> Dictionary:
	var body_id := ""
	if body_index >= 0:
		var body: Dictionary = hot.refs[body_index]
		body_id = str(body.get("body_id", hot.ids[body_index]))
	return {
		"kind": kind,
		"body_id": body_id,
		"x": hot.x[body_index] if body_index >= 0 else _divi(WIDTH, 2),
		"y": hot.y[body_index] if body_index >= 0 else UPPER_EDGE,
		"z": hot.z[body_index] if body_index >= 0 else 0,
		"intensity_milli": clampi(intensity_milli, 0, 1000),
		"tick_offset": clampi(tick_offset, 0, ACTION_TICKS),
		"metadata": metadata.duplicate(true),
	}


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
