class_name CoinPusherSolver
extends RefCounted

const SCHEMA := "coin_pusher_machine_v3"
const VERSION := 3
const FIXED_HZ := 60
const FP := 1000
const WIDTH := 100000
const TRAY_LIP_Y := 6000
const DECK_Z := 0
const PLATFORM_TOP_Z := 3600
const FACE_EXTENDED_Y := 28000
const FACE_RETRACTED_Y := 46000
const BACK_PLATE_Y := 63000
const BACK_PLATE_GAP := 400
const DROP_Y := 58000
const DROP_Z := 24000
const GUTTER_X := 3000
const COIN_RADIUS := 4300
const COIN_HEIGHT := 1700
const OBJECT_RADIUS := 5200
const OBJECT_HEIGHT := 2800
const PHASE_PERIOD := 240
const STROKE_PERIOD := PHASE_PERIOD
const HARD_BODY_CEILING := 600
const BROADPHASE_CELL := 10000
const CANDIDATE_POOL_CAPACITY := HARD_BODY_CEILING * 32
const SOLVER_PASSES := 6
const SLOP := 60
const BETA := 600
const RESTITUTION_BODY := 100
const RESTITUTION_PEG := 250
const MU_BODY := 500
const MU_DECK := 700
const MU_PLATFORM := 800
## Calibrated for a ~0.6 s unobstructed insert-board fall. The previous 560
## value took roughly a second before peg contacts and read as slow/floaty.
const GRAVITY := 1800
const AIR_DRAG_NUM := 61
const AIR_DRAG_DEN := 64
const SLEEP_SPEED := 140
const SLEEP_TICKS := 5
const HARD_IMPACT_SPEED := 12000
const SUPPORT_VERTICAL_TOLERANCE := 400
const SUPPORT_MARGIN := 800
const SKILL_STOP_RAMP_TICKS := 24
const NATIVE_BACKEND_ID := "coin_pusher_native_integer_v3"
const NATIVE_ABI_VERSION := 3

static var _native_backend: Object = null
static var _native_backend_checked := false
static var _last_step_backend := "gdscript_v3"

# Compile-time integer cosine table. Outcome state never evaluates a float.
const COS_TABLE := [
	1000, 1000, 999, 997, 995, 991, 988, 983, 978, 972, 966, 959, 951, 943, 934, 924, 914, 903, 891, 879,
	866, 853, 839, 824, 809, 793, 777, 760, 743, 725, 707, 688, 669, 649, 629, 609, 588, 566, 545, 522,
	500, 477, 454, 431, 407, 383, 358, 334, 309, 284, 259, 233, 208, 182, 156, 131, 105, 78, 52, 26,
	0, -26, -52, -78, -105, -131, -156, -182, -208, -233, -259, -284, -309, -334, -358, -383, -407, -431, -454, -477,
	-500, -522, -545, -566, -588, -609, -629, -649, -669, -688, -707, -725, -743, -760, -777, -793, -809, -824, -839, -853,
	-866, -879, -891, -903, -914, -924, -934, -943, -951, -959, -966, -972, -978, -983, -988, -991, -995, -997, -999, -1000,
	-1000, -1000, -999, -997, -995, -991, -988, -983, -978, -972, -966, -959, -951, -943, -934, -924, -914, -903, -891, -879,
	-866, -853, -839, -824, -809, -793, -777, -760, -743, -725, -707, -688, -669, -649, -629, -609, -588, -566, -545, -522,
	-500, -477, -454, -431, -407, -383, -358, -334, -309, -284, -259, -233, -208, -182, -156, -131, -105, -78, -52, -26,
	0, 26, 52, 78, 105, 131, 156, 182, 208, 233, 259, 284, 309, 334, 358, 383, 407, 431, 454, 477,
	500, 522, 545, 566, 588, 609, 629, 649, 669, 688, 707, 725, 743, 760, 777, 793, 809, 824, 839, 853,
	866, 879, 891, 903, 914, 924, 934, 943, 951, 959, 966, 972, 978, 983, 988, 991, 995, 997, 999, 1000,
]


class SpatialHash2D:
	extends RefCounted

	const TABLE_CAPACITY := 2048
	var keys_x := PackedInt32Array()
	var keys_y := PackedInt32Array()
	var heads := PackedInt32Array()
	var used := PackedByteArray()
	var next := PackedInt32Array()

	func _init() -> void:
		keys_x.resize(TABLE_CAPACITY)
		keys_y.resize(TABLE_CAPACITY)
		heads.resize(TABLE_CAPACITY)
		used.resize(TABLE_CAPACITY)

	func rebuild(bodies: Array) -> void:
		used.fill(0)
		heads.fill(0)
		next.resize(bodies.size())
		next.fill(0)
		for index in range(bodies.size() - 1, -1, -1):
			var body: Dictionary = bodies[index]
			var cell_x := CoinPusherSolver._floor_div(int(body.get("x", 0)), CoinPusherSolver.BROADPHASE_CELL)
			var cell_y := CoinPusherSolver._floor_div(int(body.get("y", 0)), CoinPusherSolver.BROADPHASE_CELL)
			var slot := _slot(cell_x, cell_y, true)
			next[index] = heads[slot]
			heads[slot] = index + 1

	func head_index(cell_x: int, cell_y: int) -> int:
		var slot := _slot(cell_x, cell_y, false)
		if slot < 0:
			return -1
		return heads[slot] - 1

	func next_index(index: int) -> int:
		if index < 0 or index >= next.size():
			return -1
		return next[index] - 1

	func _slot(cell_x: int, cell_y: int, insert: bool) -> int:
		var slot := ((cell_x * 73856093) ^ (cell_y * 19349663)) & (TABLE_CAPACITY - 1)
		for _probe in range(TABLE_CAPACITY):
			if used[slot] == 0:
				if not insert:
					return -1
				used[slot] = 1
				keys_x[slot] = cell_x
				keys_y[slot] = cell_y
				return slot
			if keys_x[slot] == cell_x and keys_y[slot] == cell_y:
				return slot
			slot = (slot + 1) & (TABLE_CAPACITY - 1)
		return -1


static var _scratch_grid: SpatialHash2D = SpatialHash2D.new()


static func create_machine(seed_rng: RngStream, machine_definition: Dictionary, opening_bodies: int = 0) -> Dictionary:
	var definition := machine_definition.duplicate(true)
	var geometry := _geometry(definition)
	var stroke := _stroke(definition)
	var phase := seed_rng.randi_range(0, maxi(1, int(stroke.get("period_ticks", STROKE_PERIOD))) - 1)
	var state := {
		"schema": SCHEMA,
		"version": VERSION,
		"fixed_hz": FIXED_HZ,
		"fixed_point_scale": FP,
		"machine_id": str(definition.get("machine_id", "")),
		"machine_definition": definition,
		"tick": 0,
		"next_body_id": 1,
		"phase_fp": phase * FP,
		"stroke_cycle_serial": 0,
		"motor_rate_fp": FP,
		"motor_target_rate_fp": FP,
		"motor_run_rate_fp": FP,
		"skill_stop_engaged": false,
		"carriage_x": _default_release_x(definition),
		"selected_hole": 0,
		"face_y": face_y_for_phase(definition, phase),
		"previous_face_y": face_y_for_phase(definition, phase),
		"bodies": [],
		"tray_ledger": [],
		"gutter_ledger": [],
		"refused_inserts": 0,
		"accepted_inserts": 0,
		"opening_body_count": 0,
		"external_origin_count": 0,
		"collected_count": 0,
		"collected_value": 0,
		"last_events": [],
		"last_step_metrics": {},
		"last_invariants": {},
	}
	if opening_bodies > 0:
		_seed_opening_machine(state, seed_rng, mini(opening_bodies, _ceiling(definition)))
	state["opening_body_count"] = (state["bodies"] as Array).size()
	return state


static func public_contract() -> Dictionary:
	return {
		"schema": SCHEMA,
		"version": VERSION,
		"fixed_hz": FIXED_HZ,
		"fixed_point_scale": FP,
		"hard_body_ceiling": HARD_BODY_CEILING,
		"broadphase_cell": BROADPHASE_CELL,
		"candidate_pool_capacity": CANDIDATE_POOL_CAPACITY,
		"solver_passes": SOLVER_PASSES,
		"contact_normal": "radial_euclidean",
		"support_rule": "multi_contact_bracket_nestle",
		"transport_rule": "platform_carry_plus_back_plate",
	}


static func implementation_contract() -> Dictionary:
	var contract := public_contract()
	contract["geometry_amendment"] = "6.2"
	return contract


static func add_coin(state: Dictionary, rng: RngStream, x: int, density: int = 1, provenance: Dictionary = {}) -> Dictionary:
	var definition := _definition(state)
	var bodies: Array = state.get("bodies", [])
	if bodies.size() >= _ceiling(definition):
		state["refused_inserts"] = int(state.get("refused_inserts", 0)) + 1
		var refusal := {"accepted": false, "refused": true, "reason": "ceiling", "returned": true}
		state["last_events"] = [{"kind": "insert_refused", "reason": "ceiling", "returned": true}]
		return refusal
	var geometry := _geometry(definition)
	var coins := _coins(definition)
	var apparatus := _apparatus(definition)
	var board := _drop_board(definition)
	var jitter := maxi(0, int(apparatus.get("release_jitter", 0)))
	var radius := int(coins.get("radius", COIN_RADIUS))
	var release_x := _production_release_x(rng, x, jitter, apparatus, radius, int(geometry.get("width", WIDTH)))
	var body := _new_body(
		state,
		"coin",
		release_x,
		int(board.get("y", DROP_Y)),
		int(board.get("z_top", DROP_Z)),
		radius,
		int(coins.get("height", COIN_HEIGHT)),
		maxi(1, int(coins.get("mass", FP)) * maxi(1, density)),
		{"value": int(coins.get("value", 1)), "provenance": provenance.duplicate(true), "inserted": true}
	)
	body["accepted"] = true
	bodies.append(body)
	state["accepted_inserts"] = int(state.get("accepted_inserts", 0)) + 1
	state["last_events"] = [{"kind": "insert", "body_id": str(body.get("id", "")), "x": int(body.get("x", 0))}]
	_wake_nearby(bodies, int(body.get("x", 0)), int(body.get("y", 0)), radius * 3, str(body.get("id", "")))
	return body


static func add_feature(state: Dictionary, kind: String, feature_id: String, x: int, y: int, metadata: Dictionary = {}) -> Dictionary:
	var definition := _definition(state)
	var bodies: Array = state.get("bodies", [])
	if bodies.size() >= _ceiling(definition):
		state["refused_inserts"] = int(state.get("refused_inserts", 0)) + 1
		return {"accepted": false, "refused": true, "reason": "ceiling", "returned": true}
	var meta := metadata.duplicate(true)
	meta["feature_id"] = feature_id
	var body := _new_body(state, kind, x, y, int(metadata.get("z", PLATFORM_TOP_Z)), int(metadata.get("radius", OBJECT_RADIUS)), int(metadata.get("height", OBJECT_HEIGHT)), maxi(1, int(metadata.get("mass", 2000))), meta)
	body["accepted"] = true
	bodies.append(body)
	state["accepted_inserts"] = int(state.get("accepted_inserts", 0)) + 1
	return body


static func return_gutter_body(state: Dictionary, return_data: Dictionary) -> Dictionary:
	var ledger: Array = state.get("gutter_ledger", []) if typeof(state.get("gutter_ledger", [])) == TYPE_ARRAY else []
	var body_id := str(return_data.get("body_id", ""))
	var ledger_index := -1
	for index in range(ledger.size() - 1, -1, -1):
		if typeof(ledger[index]) == TYPE_DICTIONARY and str((ledger[index] as Dictionary).get("body_id", "")) == body_id:
			ledger_index = index
			break
	if ledger_index < 0:
		return {"accepted": false, "reason": "gutter_body_missing"}
	var entry: Dictionary = ledger[ledger_index]
	ledger.remove_at(ledger_index)
	var definition := _definition(state)
	var geometry := _geometry(definition)
	var coins := _coins(definition)
	var radius := int(return_data.get("radius", coins.get("radius", COIN_RADIUS)))
	var height := int(return_data.get("height", coins.get("height", COIN_HEIGHT)))
	var mass := maxi(1, int(return_data.get("mass", coins.get("mass", FP))))
	var left_side := str(return_data.get("side", "left")) == "left"
	var gutter := int(geometry.get("gutter_x", GUTTER_X))
	var width := int(geometry.get("width", WIDTH))
	var deck := int(geometry.get("deck_z", DECK_Z))
	var lip := int(geometry.get("tray_lip_y", TRAY_LIP_Y))
	var metadata: Dictionary = return_data.get("metadata", {}) if typeof(return_data.get("metadata", {})) == TYPE_DICTIONARY else {}
	metadata["value"] = int(entry.get("value", metadata.get("value", 1)))
	metadata["item_id"] = str(entry.get("item_id", metadata.get("item_id", "")))
	metadata["provenance"] = (entry.get("provenance", {}) as Dictionary).duplicate(true) if typeof(entry.get("provenance", {})) == TYPE_DICTIONARY else {}
	var body := {
		"id": body_id,
		"kind": str(return_data.get("body_kind", entry.get("kind", "coin"))),
		"x": gutter + radius + 100 if left_side else width - gutter - radius - 100,
		"y": lip + radius + 1200,
		"z": deck + height,
		"vx": 900 if left_side else -900,
		"vy": 300,
		"vz": 0,
		"x_remainder": 0, "y_remainder": 0, "z_remainder": 0,
		"radius": radius, "height": height, "mass": mass,
		"sleeping": false, "sleep_ticks": 0, "rest_state": "falling",
		"fall_start_z": deck + height, "support_kind": "", "carried_sleep": false,
		"meta": metadata,
		"accepted": true,
	}
	(state.get("bodies", []) as Array).append(body)
	return body


static func _production_release_x(rng: RngStream, requested_x: int, jitter: int, apparatus: Dictionary, radius: int, width: int) -> int:
	var legal_offsets: Array[int] = []
	var pegs: Array = apparatus.get("pegs", []) if typeof(apparatus.get("pegs", [])) == TYPE_ARRAY else []
	for offset in range(-jitter, jitter + 1):
		var candidate := clampi(requested_x + offset, radius, width - radius)
		var exact_symmetry := false
		for peg_value in pegs:
			if typeof(peg_value) == TYPE_DICTIONARY and candidate == int((peg_value as Dictionary).get("x", candidate + 1)):
				exact_symmetry = true
				break
		if not exact_symmetry:
			legal_offsets.append(offset)
	if legal_offsets.is_empty():
		# A malformed zero-width apparatus still gets a deterministic release;
		# production definitions guarantee authored nonzero jitter around pegs.
		return clampi(requested_x, radius, width - radius)
	return clampi(requested_x + legal_offsets[rng.randi_range(0, legal_offsets.size() - 1)], radius, width - radius)


static func set_skill_stop(state: Dictionary, engaged: bool, resume_rate_fp: int = -1) -> void:
	if resume_rate_fp >= 0:
		state["motor_run_rate_fp"] = resume_rate_fp
	state["skill_stop_engaged"] = engaged
	state["motor_target_rate_fp"] = 0 if engaged else int(state.get("motor_run_rate_fp", FP))


static func set_motor_run_rate(state: Dictionary, rate_fp: int) -> int:
	var actual := maxi(0, rate_fp)
	state["motor_run_rate_fp"] = actual
	if not bool(state.get("skill_stop_engaged", false)):
		state["motor_target_rate_fp"] = actual
	return actual


static func set_carriage(state: Dictionary, requested_x: int) -> int:
	var definition := _definition(state)
	var apparatus := _apparatus(definition)
	var apparatus_type := str(apparatus.get("type", "rail_slot"))
	if apparatus_type == "hole_set":
		var holes: Array = apparatus.get("holes", []) if typeof(apparatus.get("holes", [])) == TYPE_ARRAY else []
		if holes.is_empty():
			state["carriage_x"] = _default_release_x(definition)
			return int(state["carriage_x"])
		var best_index := 0
		var best_distance := absi(int(holes[0]) - requested_x)
		for index in range(1, holes.size()):
			var distance := absi(int(holes[index]) - requested_x)
			if distance < best_distance:
				best_index = index
				best_distance = distance
		state["selected_hole"] = best_index
		state["carriage_x"] = int(holes[best_index])
		return int(state["carriage_x"])
	var rail: Dictionary = apparatus.get("rail", {}) if typeof(apparatus.get("rail", {})) == TYPE_DICTIONARY else {}
	var width := int(_geometry(definition).get("width", WIDTH))
	var minimum := int(rail.get("x_min", 0))
	var maximum := int(rail.get("x_max", width))
	state["carriage_x"] = clampi(requested_x, minimum, maximum)
	return int(state["carriage_x"])


static func select_hole(state: Dictionary, requested_index: int) -> int:
	var holes: Array = _apparatus(_definition(state)).get("holes", [])
	if holes.is_empty():
		return set_carriage(state, int(state.get("carriage_x", WIDTH / 2)))
	var index := clampi(requested_index, 0, holes.size() - 1)
	state["selected_hole"] = index
	state["carriage_x"] = int(holes[index])
	return int(state["carriage_x"])


static func apply_nudge(state: Dictionary, impulse_x: int, impulse_y: int) -> int:
	var affected := 0
	for body_value in state.get("bodies", []):
		var body: Dictionary = body_value
		var mass := maxi(1, int(body.get("mass", FP)))
		body["vx"] = int(body.get("vx", 0)) + _divi(impulse_x * FP, mass)
		body["vy"] = int(body.get("vy", 0)) + _divi(impulse_y * FP, mass)
		_wake(body)
		affected += 1
	return affected


static func step_ticks(state: Dictionary, config: Dictionary, tick_count: int) -> Dictionary:
	var native := _native_solver_backend()
	if native != null and bool(native.call("can_step", state, config)):
		var result_value: Variant = native.call("step_ticks", state, config, tick_count)
		if typeof(result_value) == TYPE_DICTIONARY and not (result_value as Dictionary).is_empty():
			_last_step_backend = "native_v3"
			var native_result := result_value as Dictionary
			_debug_assert_invariants(native_result)
			return native_result
	_last_step_backend = "gdscript_v3"
	return _step_ticks_gdscript(state, config, tick_count)


static func step_ticks_reference_for_test(state: Dictionary, config: Dictionary, tick_count: int) -> Dictionary:
	return _step_ticks_gdscript(state, config, tick_count)


static func _step_ticks_gdscript(state: Dictionary, config: Dictionary, tick_count: int) -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	var events: Array = []
	var collision_count := 0
	var max_candidate_count := 0
	var energy_ok := true
	var conservation_ok := true
	var input_trace: Array = config.get("input_trace", []) if typeof(config.get("input_trace", [])) == TYPE_ARRAY else []
	var trace_cursor := 0
	for local_tick in range(maxi(0, tick_count)):
		while trace_cursor < input_trace.size():
			var input_value: Variant = input_trace[trace_cursor]
			if typeof(input_value) != TYPE_DICTIONARY:
				trace_cursor += 1
				continue
			var input: Dictionary = input_value
			if int(input.get("tick", -1)) != int(state.get("tick", 0)):
				break
			_apply_trace_input(state, input, config.get("rng"))
			trace_cursor += 1
		var tick_result := _step_one_tick(state, config)
		events.append_array(tick_result.get("events", []))
		collision_count += int(tick_result.get("collision_count", 0))
		max_candidate_count = maxi(max_candidate_count, int(tick_result.get("candidate_count", 0)))
		energy_ok = energy_ok and bool(tick_result.get("energy_ok", false))
		conservation_ok = conservation_ok and bool(tick_result.get("conservation_ok", false))
	state["last_events"] = events
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	var metrics := {
		"fixed_ticks": maxi(0, tick_count),
		"body_count": (state.get("bodies", []) as Array).size(),
		"awake_count": awake_count(state),
		"collision_count": collision_count,
		"collision_passes": SOLVER_PASSES,
		"candidate_count_peak": max_candidate_count,
		"candidate_pool_capacity": CANDIDATE_POOL_CAPACITY,
		"elapsed_usec": elapsed_usec,
		"tick_average_usec": _divi(elapsed_usec, maxi(1, tick_count)),
	}
	state["last_step_metrics"] = metrics
	state["last_invariants"] = _invariant_report(state, energy_ok)
	state["last_invariants"]["conservation_ok"] = conservation_ok
	var result := {"events": events, "metrics": metrics, "invariants": state["last_invariants"]}
	_debug_assert_invariants(result)
	return result


static func native_backend_available_for_test() -> bool:
	return _native_solver_backend() != null


static func last_step_backend_for_test() -> String:
	return _last_step_backend


static func reset_native_backend_for_test() -> void:
	_native_backend = null
	_native_backend_checked = false


static func _native_solver_backend() -> Object:
	if _native_backend_checked:
		return _native_backend
	_native_backend_checked = true
	if not ClassDB.class_exists("CoinPusherNativeCore"):
		return null
	var candidate: Object = ClassDB.instantiate("CoinPusherNativeCore")
	if candidate == null:
		return null
	for method_name in ["backend_id", "solver_contract", "can_step", "step_ticks"]:
		if not candidate.has_method(method_name):
			return null
	if str(candidate.call("backend_id")) != NATIVE_BACKEND_ID:
		return null
	var contract_value: Variant = candidate.call("solver_contract")
	if typeof(contract_value) != TYPE_DICTIONARY:
		return null
	var contract: Dictionary = contract_value
	if int(contract.get("abi_version", -1)) != NATIVE_ABI_VERSION \
			or str(contract.get("schema", "")) != SCHEMA \
			or int(contract.get("state_version", -1)) != VERSION \
			or int(contract.get("fixed_hz", -1)) != FIXED_HZ \
			or int(contract.get("fixed_point_scale", -1)) != FP \
			or str(contract.get("geometry_amendment", "")) != "6.2" \
			or str(contract.get("contact_normal", "")) != "radial_euclidean" \
			or int(contract.get("collision_passes", -1)) != SOLVER_PASSES \
			or str(contract.get("transport_rule", "")) != "platform_carry_plus_back_plate":
		return null
	_native_backend = candidate
	return _native_backend


static func replay_input_trace(snapshot: Dictionary, rng: RngStream, trace: Array, ticks: int) -> Dictionary:
	var state := snapshot.duplicate(true)
	step_ticks(state, {"input_trace": trace, "rng": rng}, ticks)
	return state


static func settle(state: Dictionary, motor_running: bool, max_ticks: int = 1200) -> Dictionary:
	var used := 0
	while used < max_ticks and not all_steady(state, motor_running):
		step_ticks(state, {"motor_enabled": motor_running}, mini(8, max_ticks - used))
		used += mini(8, max_ticks - used)
	var result := {"settled": all_steady(state, motor_running), "ticks": used, "awake_count": awake_count(state)}
	if max_ticks >= 1200:
		assert(bool(result.get("settled", false)), "Coin Pusher V3 exceeded the 1200-tick settle guarantee.")
	return result


static func _debug_assert_invariants(result: Dictionary) -> void:
	var invariants: Dictionary = result.get("invariants", {}) if typeof(result.get("invariants", {})) == TYPE_DICTIONARY else {}
	assert(bool(invariants.get("energy_ok", false)), "Coin Pusher V3 gained energy beyond platform/gravity/input work.")
	assert(bool(invariants.get("conservation_ok", false)), "Coin Pusher V3 body conservation did not reconcile.")


static func all_steady(state: Dictionary, motor_running: bool = true) -> bool:
	for body_value in state.get("bodies", []):
		var body: Dictionary = body_value
		if not bool(body.get("sleeping", false)):
			return false
		if motor_running and str(body.get("support_kind", "")) == "platform" and not bool(body.get("carried_sleep", false)):
			return false
	return true


static func collect_tray(state: Dictionary) -> Dictionary:
	var value := 0
	var items: Array = []
	var ledger: Array = state.get("tray_ledger", [])
	for entry_value in ledger:
		var entry: Dictionary = entry_value
		value += maxi(0, int(entry.get("value", 0)))
		if not str(entry.get("item_id", "")).is_empty():
			items.append(str(entry.get("item_id", "")))
	state["tray_ledger"] = []
	state["collected_count"] = int(state.get("collected_count", 0)) + ledger.size()
	state["collected_value"] = int(state.get("collected_value", 0)) + value
	return {"value": value, "items": items, "count": ledger.size()}


static func face_y_for_phase(definition: Dictionary, phase: int) -> int:
	var geometry := _geometry(definition)
	var stroke := _stroke(definition)
	var period := maxi(1, int(stroke.get("period_ticks", STROKE_PERIOD)))
	var index := posmod(phase, period)
	var cosine := int(COS_TABLE[index * COS_TABLE.size() / period])
	var extended := int(geometry.get("face_extended_y", FACE_EXTENDED_Y))
	var retracted := int(geometry.get("face_retracted_y", FACE_RETRACTED_Y))
	return extended + _divi((retracted - extended) * (FP - cosine), 2 * FP)


static func body_views(state: Dictionary) -> Array:
	var views: Array = []
	for body_value in state.get("bodies", []):
		var body: Dictionary = body_value
		views.append({
			"id": str(body.get("id", "")),
			"kind": str(body.get("kind", "coin")),
			"x": int(body.get("x", 0)),
			"y": int(body.get("y", 0)),
			"z": int(body.get("z", 0)),
			"vx": int(body.get("vx", 0)),
			"vy": int(body.get("vy", 0)),
			"vz": int(body.get("vz", 0)),
			"x_remainder": int(body.get("x_remainder", 0)),
			"y_remainder": int(body.get("y_remainder", 0)),
			"z_remainder": int(body.get("z_remainder", 0)),
			"radius": int(body.get("radius", COIN_RADIUS)),
			"height": int(body.get("height", COIN_HEIGHT)),
			"mass": int(body.get("mass", FP)),
			"sleeping": bool(body.get("sleeping", false)),
			"rest_state": str(body.get("rest_state", "falling")),
			"support_kind": str(body.get("support_kind", "")),
			"support_root": "platform" if str(body.get("support_kind", "")) == "platform" or (str(body.get("support_kind", "")) == "body" and bool(body.get("carried_sleep", false))) else "deck" if not str(body.get("support_kind", "")).is_empty() else "",
			"peg_contact_key": str(body.get("peg_contact_key", "")),
			"metadata": (body.get("meta", {}) as Dictionary).duplicate(true),
		})
	return views


static func canonical_digest(state: Dictionary) -> Dictionary:
	return {
		"schema": str(state.get("schema", "")),
		"version": int(state.get("version", 0)),
		"machine_id": str(state.get("machine_id", "")),
		"tick": int(state.get("tick", 0)),
		"next_body_id": int(state.get("next_body_id", 0)),
		"phase_fp": int(state.get("phase_fp", 0)),
		"stroke_cycle_serial": int(state.get("stroke_cycle_serial", 0)),
		"motor_rate_fp": int(state.get("motor_rate_fp", 0)),
		"motor_target_rate_fp": int(state.get("motor_target_rate_fp", 0)),
		"motor_run_rate_fp": int(state.get("motor_run_rate_fp", FP)),
		"skill_stop_engaged": bool(state.get("skill_stop_engaged", false)),
		"carriage_x": int(state.get("carriage_x", _default_release_x(_definition(state)))),
		"selected_hole": int(state.get("selected_hole", 0)),
		"face_y": int(state.get("face_y", 0)),
		"bodies": body_views(state),
		"tray_ledger": (state.get("tray_ledger", []) as Array).duplicate(true),
		"gutter_ledger": (state.get("gutter_ledger", []) as Array).duplicate(true),
		"refused_inserts": int(state.get("refused_inserts", 0)),
		"accepted_inserts": int(state.get("accepted_inserts", 0)),
		"opening_body_count": int(state.get("opening_body_count", 0)),
		"external_origin_count": int(state.get("external_origin_count", 0)),
		"collected_count": int(state.get("collected_count", 0)),
		"collected_value": int(state.get("collected_value", 0)),
	}


static func coin_count(state: Dictionary) -> int:
	var count := 0
	for body_value in state.get("bodies", []):
		if str((body_value as Dictionary).get("kind", "")) == "coin":
			count += 1
	return count


static func awake_count(state: Dictionary) -> int:
	var count := 0
	for body_value in state.get("bodies", []):
		if not bool((body_value as Dictionary).get("sleeping", false)):
			count += 1
	return count


static func edge_hanger_count(state: Dictionary) -> int:
	var geometry := _geometry(_definition(state))
	var lip := int(geometry.get("tray_lip_y", TRAY_LIP_Y))
	var count := 0
	for body_value in state.get("bodies", []):
		var body: Dictionary = body_value
		if int(body.get("y", 0)) - int(body.get("radius", COIN_RADIUS)) <= lip + 1200:
			count += 1
	return count


static func _step_one_tick(state: Dictionary, config: Dictionary) -> Dictionary:
	var definition := _definition(state)
	var geometry := _geometry(definition)
	var bodies: Array = state.get("bodies", [])
	var before_energy := _kinetic_energy(bodies)
	var events: Array = []
	var old_face := int(state.get("face_y", face_y_for_phase(definition, 0)))
	var cycle_completed := _update_motor(state, bool(config.get("motor_enabled", true)))
	if cycle_completed:
		events.append({"kind": "stroke_cycle", "stroke_cycle": int(state.get("stroke_cycle_serial", 0)), "phase_fp": int(state.get("phase_fp", 0)), "tick": int(state.get("tick", 0))})
	var new_face := int(state.get("face_y", old_face))
	var face_delta := new_face - old_face
	_apply_platform_carry_and_plate(bodies, geometry, old_face, new_face, face_delta)
	_apply_full_height_face(bodies, geometry, old_face, new_face, face_delta)
	var platform_work := maxi(0, _kinetic_energy(bodies) - before_energy)
	var before_gravity := _kinetic_energy(bodies)
	_integrate_bodies(bodies, definition)
	var gravity_work := maxi(0, _kinetic_energy(bodies) - before_gravity)
	_apply_peg_contacts(bodies, definition, events)
	var grid := _scratch_grid
	grid.rebuild(bodies)
	var nestle_work := _resolve_supports(bodies, definition, new_face, events, grid)
	grid.rebuild(bodies)
	var pairs: Array = _contact_pairs(bodies, grid)
	var active_mask := _active_island_mask(bodies, pairs)
	var static_candidates := _static_candidate_indices(bodies, geometry, active_mask, new_face)
	var collisions := 0
	for _pass in range(SOLVER_PASSES):
		for pair_key_value in pairs:
			var pair_key := int(pair_key_value)
			var left_index := pair_key / HARD_BODY_CEILING
			var right_index := pair_key % HARD_BODY_CEILING
			if left_index >= bodies.size() or right_index >= bodies.size():
				continue
			if active_mask[left_index] == 0 and active_mask[right_index] == 0:
				continue
			if _resolve_body_contact(bodies[left_index], bodies[right_index]):
				collisions += 1
		platform_work += _resolve_static_contacts(bodies, geometry, static_candidates, new_face, face_delta)
	nestle_work += _resolve_supports(bodies, definition, new_face, events, grid)
	for body_value in bodies:
		var settled_body: Dictionary = body_value
		if not bool(settled_body.get("sleeping", false)) and str(settled_body.get("rest_state", "")) == "resting" and not str(settled_body.get("support_kind", "")).is_empty():
			_update_sleep(settled_body)
	for body_value in bodies:
		(body_value as Dictionary).erase("peg_contact_this_tick")
	_process_exits(state, events)
	state["tick"] = int(state.get("tick", 0)) + 1
	var after_energy := _kinetic_energy(state.get("bodies", []))
	var energy_ok := after_energy <= before_energy + platform_work + gravity_work + nestle_work
	var active_count := bodies.size()
	var origin_count := int(state.get("opening_body_count", 0)) + int(state.get("accepted_inserts", 0)) + int(state.get("external_origin_count", 0))
	var conservation_ok := active_count + (state.get("tray_ledger", []) as Array).size() + (state.get("gutter_ledger", []) as Array).size() + int(state.get("collected_count", 0)) == origin_count
	return {"events": events, "collision_count": collisions, "candidate_count": pairs.size(), "energy_ok": energy_ok, "conservation_ok": conservation_ok}


static func _update_motor(state: Dictionary, motor_enabled: bool) -> bool:
	var definition := _definition(state)
	var stroke := _stroke(definition)
	var period := maxi(1, int(stroke.get("period_ticks", STROKE_PERIOD)))
	var ramp_ticks := maxi(1, int(stroke.get("ramp_ticks", SKILL_STOP_RAMP_TICKS)))
	var target := int(state.get("motor_target_rate_fp", FP)) if motor_enabled else 0
	var rate := int(state.get("motor_rate_fp", FP))
	var ramp_delta := _divi(FP + ramp_ticks - 1, ramp_ticks)
	if rate < target:
		rate = mini(target, rate + ramp_delta)
	elif rate > target:
		rate = maxi(target, rate - ramp_delta)
	state["motor_rate_fp"] = rate
	state["previous_face_y"] = int(state.get("face_y", face_y_for_phase(definition, 0)))
	var previous_phase_fp := int(state.get("phase_fp", 0))
	state["phase_fp"] = posmod(previous_phase_fp + rate, period * FP)
	var completed := rate > 0 and int(state.get("phase_fp", 0)) < previous_phase_fp
	if completed:
		state["stroke_cycle_serial"] = int(state.get("stroke_cycle_serial", 0)) + 1
	state["face_y"] = face_y_for_phase(definition, _divi(int(state.get("phase_fp", 0)), FP))
	return completed


static func _apply_platform_carry_and_plate(bodies: Array, geometry: Dictionary, old_face: int, new_face: int, face_delta: int) -> void:
	var platform_top := int(geometry.get("platform_top_z", PLATFORM_TOP_Z))
	var plate_y := int(geometry.get("back_plate_y", BACK_PLATE_Y))
	var plate_bottom := platform_top + int(geometry.get("back_plate_gap", BACK_PLATE_GAP))
	for body_value in bodies:
		var body: Dictionary = body_value
		var radius := int(body.get("radius", COIN_RADIUS))
		var height := int(body.get("height", COIN_HEIGHT))
		var previous_support_kind := str(body.get("support_kind", ""))
		var direct_platform_support := previous_support_kind == "platform" or (absi(int(body.get("z", 0)) - platform_top) <= SUPPORT_VERTICAL_TOLERANCE and int(body.get("y", 0)) >= old_face)
		var inherited_platform_carry := bool(body.get("carried_sleep", false)) and previous_support_kind == "body"
		var riding := direct_platform_support or inherited_platform_carry
		if riding:
			var carry_delta := face_delta
			var slip_limit := maxi(1, _divi(MU_PLATFORM * GRAVITY, FP))
			carry_delta = clampi(carry_delta, -slip_limit, slip_limit)
			var proposed_y := int(body.get("y", 0)) + carry_delta
			var blocked_by_plate := int(body.get("z", 0)) + height > plate_bottom and proposed_y + radius > plate_y
			if blocked_by_plate:
				proposed_y = plate_y - radius
				body["carried_sleep"] = false
				body["plate_blocked"] = true
				if face_delta != 0:
					_wake(body)
			else:
				body["plate_blocked"] = false
			body["y"] = proposed_y
			if proposed_y >= new_face:
				body["support_kind"] = "platform" if direct_platform_support else previous_support_kind
			else:
				if direct_platform_support:
					body["pending_platform_deposit"] = true
					body["support_kind"] = ""
					_wake(body)
			if bool(body.get("sleeping", false)) and not blocked_by_plate:
				body["carried_sleep"] = true


static func _apply_full_height_face(bodies: Array, geometry: Dictionary, old_face: int, new_face: int, face_delta: int) -> void:
	if face_delta >= 0:
		return
	var platform_top := int(geometry.get("platform_top_z", PLATFORM_TOP_Z))
	for body_value in bodies:
		var body: Dictionary = body_value
		if int(body.get("z", 0)) >= platform_top:
			continue
		var radius := int(body.get("radius", COIN_RADIUS))
		var y := int(body.get("y", 0))
		if y < new_face and new_face - (y + radius) <= radius:
			_wake(body)
		if y + radius >= new_face and y - radius <= old_face:
			body["y"] = new_face - radius
			body["vy"] = mini(int(body.get("vy", 0)), face_delta * FIXED_HZ)
			_wake(body)


static func _static_candidate_indices(bodies: Array, geometry: Dictionary, active_mask: PackedByteArray, face_y: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var width := int(geometry.get("width", WIDTH))
	var platform_top := int(geometry.get("platform_top_z", PLATFORM_TOP_Z))
	var plate_y := int(geometry.get("back_plate_y", BACK_PLATE_Y))
	var plate_bottom := platform_top + int(geometry.get("back_plate_gap", BACK_PLATE_GAP))
	for body_index in range(bodies.size()):
		if body_index >= active_mask.size() or active_mask[body_index] == 0:
			continue
		var body: Dictionary = bodies[body_index]
		var radius := int(body.get("radius", COIN_RADIUS))
		var near_side := int(body.get("x", 0)) < radius * 2 or int(body.get("x", 0)) > width - radius * 2
		var near_plate := int(body.get("z", 0)) + int(body.get("height", COIN_HEIGHT)) > plate_bottom and int(body.get("y", 0)) + radius * 2 > plate_y
		var body_y := int(body.get("y", 0))
		var near_face := int(body.get("z", 0)) < platform_top and body_y < face_y and body_y + radius * 2 > face_y
		if near_side or near_plate or near_face:
			result.append(body_index)
	return result


static func _resolve_static_contacts(bodies: Array, geometry: Dictionary, candidate_indices: PackedInt32Array, face_y: int, face_delta: int) -> int:
	var width := int(geometry.get("width", WIDTH))
	var lip := int(geometry.get("tray_lip_y", TRAY_LIP_Y))
	var platform_top := int(geometry.get("platform_top_z", PLATFORM_TOP_Z))
	var plate_y := int(geometry.get("back_plate_y", BACK_PLATE_Y))
	var plate_bottom := platform_top + int(geometry.get("back_plate_gap", BACK_PLATE_GAP))
	var face_work := 0
	for body_index_value in candidate_indices:
		var body_index := int(body_index_value)
		if body_index < 0 or body_index >= bodies.size():
			continue
		var body: Dictionary = bodies[body_index]
		var radius := int(body.get("radius", COIN_RADIUS))
		if int(body.get("z", 0)) < platform_top and int(body.get("y", 0)) < face_y and int(body.get("y", 0)) > face_y - radius:
			var before_face := _body_kinetic_energy(body)
			var face_penetration := int(body.get("y", 0)) - (face_y - radius)
			var face_correction := _divi(maxi(0, face_penetration - SLOP) * BETA, FP)
			body["y"] = int(body.get("y", 0)) - face_correction
			var face_relative_normal := face_delta * FIXED_HZ - int(body.get("vy", 0))
			if face_relative_normal < 0:
				body["vy"] = int(body.get("vy", 0)) + face_relative_normal
			face_work += maxi(0, _body_kinetic_energy(body) - before_face)
			if face_correction > 0:
				_wake(body)
		if int(body.get("z", 0)) + int(body.get("height", COIN_HEIGHT)) > plate_bottom:
			var plate_limit := plate_y - radius
			if int(body.get("y", 0)) > plate_limit:
				var plate_penetration := int(body.get("y", 0)) - plate_limit
				var plate_correction := _divi(maxi(0, plate_penetration - SLOP) * BETA, FP)
				body["y"] = int(body.get("y", 0)) - plate_correction
				if int(body.get("vy", 0)) > 0:
					body["vy"] = 0
		if int(body.get("y", 0)) <= lip + radius:
			continue
		if int(body.get("x", 0)) < radius:
			var left_penetration := radius - int(body.get("x", 0))
			var left_correction := _divi(maxi(0, left_penetration - SLOP) * BETA, FP)
			body["x"] = int(body.get("x", 0)) + left_correction
			if int(body.get("vx", 0)) < 0:
				body["vx"] = 0
		elif int(body.get("x", 0)) > width - radius:
			var right_penetration := int(body.get("x", 0)) - (width - radius)
			var right_correction := _divi(maxi(0, right_penetration - SLOP) * BETA, FP)
			body["x"] = int(body.get("x", 0)) - right_correction
			if int(body.get("vx", 0)) > 0:
				body["vx"] = 0
	return face_work


static func _integrate_bodies(bodies: Array, definition: Dictionary) -> void:
	for body_value in bodies:
		var body: Dictionary = body_value
		if bool(body.get("sleeping", false)):
			continue
		body["vz"] = int(body.get("vz", 0)) - GRAVITY
		body["vx"] = _divi(int(body.get("vx", 0)) * AIR_DRAG_NUM, AIR_DRAG_DEN)
		body["vy"] = _divi(int(body.get("vy", 0)) * AIR_DRAG_NUM, AIR_DRAG_DEN)
		_integrate_axis(body, "x", "vx", "x_remainder")
		_integrate_axis(body, "y", "vy", "y_remainder")
		_integrate_axis(body, "z", "vz", "z_remainder")


static func _apply_peg_contacts(bodies: Array, definition: Dictionary, events: Array) -> void:
	var geometry := _geometry(definition)
	var drop_y := int(geometry.get("drop_y", DROP_Y))
	for body_value in bodies:
		(body_value as Dictionary).erase("peg_contact_this_tick")
	for body_value in bodies:
		var body: Dictionary = body_value
		if bool(body.get("sleeping", false)):
			continue
		if str(body.get("rest_state", "")) != "falling":
			body.erase("peg_contact_key")
			continue
		if absi(int(body.get("y", 0)) - drop_y) > int(body.get("radius", COIN_RADIUS)):
			continue
		var previous_peg_key := str(body.get("peg_contact_key", ""))
		var current_peg_key := ""
		var pegs: Array = _apparatus(definition).get("pegs", []) if typeof(_apparatus(definition).get("pegs", [])) == TYPE_ARRAY else []
		for peg_index in range(pegs.size()):
			var peg_value: Variant = pegs[peg_index]
			if typeof(peg_value) != TYPE_DICTIONARY:
				continue
			var peg: Dictionary = peg_value
			var pre_x := int(body.get("x", 0))
			var pre_z := int(body.get("z", 0))
			var dx := int(body.get("x", 0)) - int(peg.get("x", 0))
			var dz := int(body.get("z", 0)) - int(peg.get("z", 0))
			var minimum := int(body.get("radius", COIN_RADIUS)) + int(peg.get("r", 1200))
			var distance_sq := dx * dx + dz * dz
			if distance_sq >= minimum * minimum:
				continue
			current_peg_key = str(peg_index)
			var distance := maxi(1, _isqrt(distance_sq))
			var nx := _divi(dx * FP, distance)
			var nz := _divi(dz * FP, distance)
			# A vertical crown has the valid radial normal (0, +1); never author a
			# left/right outcome from peg identity. Only true coincident centers
			# lack a normal and use a fixed deterministic separation axis.
			if distance_sq == 0:
				nx = FP
				nz = 0
			var penetration := minimum - distance
			var correction := _divi(maxi(0, penetration - SLOP) * BETA, FP)
			if distance_sq == 0:
				body["x"] = int(body.get("x", 0)) + _divi(nx * correction, FP)
				body["z"] = int(body.get("z", 0)) + _divi(nz * correction, FP)
			else:
				# Separate along the exact radial geometry, rounding each nonzero
				# component away from the peg. Quantizing the normal first maps dx=1
				# to nx=0 and creates an artificial vertical pin lattice.
				body["x"] = int(body.get("x", 0)) + _radial_correction_component(dx, correction, distance)
				body["z"] = int(body.get("z", 0)) + _radial_correction_component(dz, correction, distance)
			var relative := _divi(int(body.get("vx", 0)) * nx + int(body.get("vz", 0)) * nz, FP)
			if relative < 0:
				# Stabilize low-speed resting contact so discrete gravity cannot
				# sustain a perpetual micro-bounce. Full impacts retain E=250.
				var restitution := 0 if -relative < GRAVITY * 2 and not bool((body.get("meta", {}) as Dictionary).get("inserted", false)) else RESTITUTION_PEG
				var impulse := -_divi((FP + restitution) * relative, FP)
				var conservative_delta := _conservative_peg_impulse_delta(int(body.get("vx", 0)), int(body.get("vz", 0)), impulse, nx, nz)
				body["vx"] = int(body.get("vx", 0)) + conservative_delta.x
				body["vz"] = int(body.get("vz", 0)) + conservative_delta.y
				var friction_budget := _divi(MU_BODY * impulse, FP)
				var tx := -nz
				var tz := nx
				var tangent := _divi(int(body.get("vx", 0)) * tx + int(body.get("vz", 0)) * tz, FP)
				# A disk-on-pin contact has rotational compliance. The body schema has
				# no angular state, so use the disk's 1:2 translational/rotational
				# effective-mass split instead of falsely cancelling all COM tangent.
				# Apply rotational compliance once on contact entry. Reapplying it
				# every tick erases the rolling tangent because the body schema has
				# no angular state, creating an artificial permanent pin balance.
				var tangent_impulse := clampi(-_divi(tangent, 3), -friction_budget, friction_budget) if previous_peg_key != current_peg_key else 0
				var friction_vx := int(body.get("vx", 0))
				var friction_vz := int(body.get("vz", 0))
				var tangent_dx := _divi(tangent_impulse * tx, FP)
				var tangent_dz := _divi(tangent_impulse * tz, FP)
				# Integer projection onto an approximate unit tangent can round a
				# dissipative impulse into a one-unit energy gain. Reject that rounded
				# candidate instead of weakening the solver's no-energy-gain contract.
				if (friction_vx + tangent_dx) * (friction_vx + tangent_dx) + (friction_vz + tangent_dz) * (friction_vz + tangent_dz) > friction_vx * friction_vx + friction_vz * friction_vz:
					tangent_impulse = 0
					tangent_dx = 0
					tangent_dz = 0
				body["vx"] = friction_vx + tangent_dx
				body["vz"] = friction_vz + tangent_dz
				var remaining := maxi(0, friction_budget - absi(tangent_impulse))
				body["vy"] = int(body.get("vy", 0)) + clampi(-int(body.get("vy", 0)), -remaining, remaining)
			events.append({"kind": "peg_impact", "body_id": str(body.get("id", "")), "peg": {"x": int(peg.get("x", 0)), "z": int(peg.get("z", 0)), "r": int(peg.get("r", 1200))}, "pre_x": pre_x, "pre_z": pre_z, "post_x": int(body.get("x", 0)), "post_z": int(body.get("z", 0))})
		if current_peg_key.is_empty():
			body.erase("peg_contact_key")
		else:
			body["peg_contact_key"] = current_peg_key


static func _radial_correction_component(component: int, correction: int, distance: int) -> int:
	if component == 0 or correction <= 0:
		return 0
	var magnitude := _divi(absi(component) * correction + maxi(1, distance) - 1, maxi(1, distance))
	return magnitude if component > 0 else -magnitude


static func _conservative_peg_impulse_delta(vx: int, vz: int, impulse: int, nx: int, nz: int) -> Vector2i:
	var x_numerator := impulse * nx
	var z_numerator := impulse * nz
	var x_floor := _floor_div(x_numerator, FP)
	var x_ceil := -_floor_div(-x_numerator, FP)
	var z_floor := _floor_div(z_numerator, FP)
	var z_ceil := -_floor_div(-z_numerator, FP)
	var before_energy := vx * vx + vz * vz
	var best := Vector2i.ZERO
	var best_error := 0x7fffffffffffffff
	var found := false
	for delta_x in [x_floor, x_ceil]:
		for delta_z in [z_floor, z_ceil]:
			var after_energy: int = (vx + delta_x) * (vx + delta_x) + (vz + delta_z) * (vz + delta_z)
			if after_energy > before_energy:
				continue
			var error_x: int = delta_x * FP - x_numerator
			var error_z: int = delta_z * FP - z_numerator
			var error: int = error_x * error_x + error_z * error_z
			if not found or error < best_error or (error == best_error and (delta_x < best.x or (delta_x == best.x and delta_z < best.y))):
				found = true
				best_error = error
				best = Vector2i(delta_x, delta_z)
	return best


static func _contact_pairs(bodies: Array, grid: SpatialHash2D) -> Array:
	var encoded_pairs: Array = []
	var queued := PackedByteArray()
	queued.resize(bodies.size())
	var queue := PackedInt32Array()
	for index in range(bodies.size()):
		if not bool((bodies[index] as Dictionary).get("sleeping", false)):
			queued[index] = 1
			queue.append(index)
	var pair_seen: Dictionary = {}
	var cursor := 0
	while cursor < queue.size():
		var left_index := int(queue[cursor])
		cursor += 1
		var left: Dictionary = bodies[left_index]
		var cell_x := _floor_div(int(left.get("x", 0)), BROADPHASE_CELL)
		var cell_y := _floor_div(int(left.get("y", 0)), BROADPHASE_CELL)
		for offset_y in range(-1, 2):
			for offset_x in range(-1, 2):
				var right_index := grid.head_index(cell_x + offset_x, cell_y + offset_y)
				while right_index >= 0:
					if right_index == left_index:
						right_index = grid.next_index(right_index)
						continue
					var right: Dictionary = bodies[right_index]
					if not _z_bands_overlap(left, right):
						right_index = grid.next_index(right_index)
						continue
					var dx := int(right.get("x", 0)) - int(left.get("x", 0))
					var dy := int(right.get("y", 0)) - int(left.get("y", 0))
					var minimum := int(left.get("radius", COIN_RADIUS)) + int(right.get("radius", COIN_RADIUS))
					if dx * dx + dy * dy < minimum * minimum:
						var left_id := str(left.get("id", ""))
						var right_id := str(right.get("id", ""))
						var low_index := left_index if left_id <= right_id else right_index
						var high_index := right_index if left_id <= right_id else left_index
						var encoded := low_index * HARD_BODY_CEILING + high_index
						if not pair_seen.has(encoded):
							pair_seen[encoded] = true
							if encoded_pairs.size() < CANDIDATE_POOL_CAPACITY:
								encoded_pairs.append(encoded)
						if queued[right_index] == 0:
							queued[right_index] = 1
							queue.append(right_index)
					right_index = grid.next_index(right_index)
	encoded_pairs.sort_custom(_pair_id_less.bind(bodies))
	return encoded_pairs


static func _pair_id_less(left_key_value: Variant, right_key_value: Variant, bodies: Array) -> bool:
	var left_key := int(left_key_value)
	var right_key := int(right_key_value)
	var left_low := str((bodies[left_key / HARD_BODY_CEILING] as Dictionary).get("id", ""))
	var left_high := str((bodies[left_key % HARD_BODY_CEILING] as Dictionary).get("id", ""))
	var right_low := str((bodies[right_key / HARD_BODY_CEILING] as Dictionary).get("id", ""))
	var right_high := str((bodies[right_key % HARD_BODY_CEILING] as Dictionary).get("id", ""))
	return left_low < right_low or (left_low == right_low and left_high < right_high)


static func _active_island_mask(bodies: Array, pairs: Array) -> PackedByteArray:
	var active := PackedByteArray()
	active.resize(bodies.size())
	var changed := true
	for index in range(bodies.size()):
		if not bool((bodies[index] as Dictionary).get("sleeping", false)):
			active[index] = 1
	while changed:
		changed = false
		for pair_key_value in pairs:
			var pair_key := int(pair_key_value)
			var left := pair_key / HARD_BODY_CEILING
			var right := pair_key % HARD_BODY_CEILING
			if active[left] != active[right]:
				active[left] = 1
				active[right] = 1
				changed = true
	return active


static func _resolve_body_contact(left: Dictionary, right: Dictionary) -> bool:
	if not _z_bands_overlap(left, right):
		return false
	var dx := int(right.get("x", 0)) - int(left.get("x", 0))
	var dy := int(right.get("y", 0)) - int(left.get("y", 0))
	if dx == 0 and dy == 0:
		dx = 1 if str(left.get("id", "")) < str(right.get("id", "")) else -1
	var minimum := int(left.get("radius", COIN_RADIUS)) + int(right.get("radius", COIN_RADIUS))
	var distance_sq := dx * dx + dy * dy
	if distance_sq >= minimum * minimum:
		return false
	var left_was_awake := not bool(left.get("sleeping", false))
	var right_was_awake := not bool(right.get("sleeping", false))
	var left_is_moving := absi(int(left.get("vx", 0))) + absi(int(left.get("vy", 0))) + absi(int(left.get("vz", 0))) >= SLEEP_SPEED
	var right_is_moving := absi(int(right.get("vx", 0))) + absi(int(right.get("vy", 0))) + absi(int(right.get("vz", 0))) >= SLEEP_SPEED
	# A merely not-yet-asleep resting body must not perpetually wake an
	# overlapping sleeper.  Only a body carrying meaningful motion propagates
	# an awake island through contact.
	if left_was_awake and left_is_moving and not right_was_awake:
		_wake(right)
	elif right_was_awake and right_is_moving and not left_was_awake:
		_wake(left)
	var distance := maxi(1, _isqrt(distance_sq))
	var nx := _divi(dx * FP, distance)
	var ny := _divi(dy * FP, distance)
	var penetration := minimum - distance
	var correction := _divi(maxi(0, penetration - SLOP) * BETA, FP)
	var contact_changed := false
	var inverse_left := _divi(FP * FP, maxi(1, int(left.get("mass", FP))))
	var inverse_right := _divi(FP * FP, maxi(1, int(right.get("mass", FP))))
	var inverse_sum := maxi(1, inverse_left + inverse_right)
	var left_correction := _divi(correction * inverse_left, inverse_sum)
	var right_correction := correction - left_correction
	left["x"] = int(left.get("x", 0)) - _divi(nx * left_correction, FP)
	left["y"] = int(left.get("y", 0)) - _divi(ny * left_correction, FP)
	right["x"] = int(right.get("x", 0)) + _divi(nx * right_correction, FP)
	right["y"] = int(right.get("y", 0)) + _divi(ny * right_correction, FP)
	var relative_x := int(right.get("vx", 0)) - int(left.get("vx", 0))
	var relative_y := int(right.get("vy", 0)) - int(left.get("vy", 0))
	var relative_normal := _divi(relative_x * nx + relative_y * ny, FP)
	if relative_normal < 0:
		var left_v_before := Vector3i(int(left.get("vx", 0)), int(left.get("vy", 0)), int(left.get("vz", 0)))
		var right_v_before := Vector3i(int(right.get("vx", 0)), int(right.get("vy", 0)), int(right.get("vz", 0)))
		var pair_energy_before := _body_kinetic_energy(left) + _body_kinetic_energy(right)
		contact_changed = relative_normal < -SLEEP_SPEED
		var impulse := -_divi((FP + RESTITUTION_BODY) * relative_normal, inverse_sum)
		var left_velocity_delta := _divi(impulse * inverse_left, FP)
		var right_velocity_delta := _divi(impulse * inverse_right, FP)
		left["vx"] = int(left.get("vx", 0)) - _divi(left_velocity_delta * nx, FP)
		left["vy"] = int(left.get("vy", 0)) - _divi(left_velocity_delta * ny, FP)
		right["vx"] = int(right.get("vx", 0)) + _divi(right_velocity_delta * nx, FP)
		right["vy"] = int(right.get("vy", 0)) + _divi(right_velocity_delta * ny, FP)
		var tangent_x := -ny
		var tangent_y := nx
		var relative_tangent := _divi(relative_x * tangent_x + relative_y * tangent_y, FP)
		var tangent_impulse := clampi(-_divi(relative_tangent * FP, inverse_sum), -_divi(MU_BODY * impulse, FP), _divi(MU_BODY * impulse, FP))
		var left_tangent_delta := _divi(tangent_impulse * inverse_left, FP)
		var right_tangent_delta := _divi(tangent_impulse * inverse_right, FP)
		left["vx"] = int(left.get("vx", 0)) - _divi(left_tangent_delta * tangent_x, FP)
		left["vy"] = int(left.get("vy", 0)) - _divi(left_tangent_delta * tangent_y, FP)
		right["vx"] = int(right.get("vx", 0)) + _divi(right_tangent_delta * tangent_x, FP)
		right["vy"] = int(right.get("vy", 0)) + _divi(right_tangent_delta * tangent_y, FP)
		# The authored collision is dissipative. Integer normal/tangent projection
		# can occasionally round the four velocity components into a net gain;
		# refuse that rounded impulse while retaining positional separation.
		if _body_kinetic_energy(left) + _body_kinetic_energy(right) > pair_energy_before:
			left["vx"] = left_v_before.x
			left["vy"] = left_v_before.y
			left["vz"] = left_v_before.z
			right["vx"] = right_v_before.x
			right["vy"] = right_v_before.y
			right["vz"] = right_v_before.z
			contact_changed = false
	if contact_changed:
		_wake(left)
		_wake(right)
	return true


static func _resolve_supports(bodies: Array, definition: Dictionary, face_y: int, events: Array, grid: SpatialHash2D) -> int:
	var geometry := _geometry(definition)
	var platform_top := int(geometry.get("platform_top_z", PLATFORM_TOP_Z))
	var deck_z := int(geometry.get("deck_z", DECK_Z))
	var nestle_work := 0
	for body_index in range(bodies.size()):
		var body: Dictionary = bodies[body_index]
		if bool(body.get("sleeping", false)):
			continue
		var previous_support := "platform" if bool(body.get("pending_platform_deposit", false)) else str(body.get("support_kind", ""))
		var surface_z := platform_top if int(body.get("y", 0)) >= face_y else deck_z
		var surface_kind := "platform" if int(body.get("y", 0)) >= face_y else "deck"
		var stable := int(body.get("z", 0)) <= surface_z + SUPPORT_VERTICAL_TOLERANCE
		if stable and int(body.get("vz", 0)) <= 0:
			var was_surface_falling := str(body.get("rest_state", "")) == "falling"
			var fall_start_z := int(body.get("fall_start_z", body.get("z", surface_z)))
			var impact_speed := absi(int(body.get("vz", 0)))
			body["z"] = surface_z
			body["vz"] = 0
			body["z_remainder"] = 0
			body["support_kind"] = surface_kind
			body["carried_sleep"] = surface_kind == "platform"
			body["rest_state"] = "resting"
			_apply_surface_friction(body, MU_PLATFORM if surface_kind == "platform" else MU_DECK)
			if was_surface_falling:
				var first_support := bool((body.get("meta", {}) as Dictionary).get("inserted", false)) and not bool((body.get("meta", {}) as Dictionary).get("first_support_recorded", false))
				events.append({"kind": "impact", "body_id": str(body.get("id", "")), "support": surface_kind, "support_root": surface_kind, "first_support": first_support, "fall_height": maxi(0, fall_start_z - surface_z), "impact_speed": impact_speed, "impact_class": "hard" if impact_speed >= HARD_IMPACT_SPEED else "soft", "stack_depth": 0})
				if first_support:
					(body.get("meta", {}) as Dictionary)["first_support_recorded"] = true
				body.erase("fall_start_z")
			if previous_support == "platform" and surface_kind == "deck":
				events.append({"kind": "platform_deposit", "body_id": str(body.get("id", ""))})
				body.erase("pending_platform_deposit")
			continue
		var support_top := surface_z
		var support_count := 0
		var centered := false
		var x_low := false
		var x_high := false
		var y_low := false
		var y_high := false
		var centroid_x := 0
		var centroid_y := 0
		var top_carried := false
		var cell_x := _floor_div(int(body.get("x", 0)), BROADPHASE_CELL)
		var cell_y := _floor_div(int(body.get("y", 0)), BROADPHASE_CELL)
		for offset_y in range(-1, 2):
			for offset_x in range(-1, 2):
				var support_index := grid.head_index(cell_x + offset_x, cell_y + offset_y)
				while support_index >= 0:
					if support_index == body_index:
						support_index = grid.next_index(support_index)
						continue
					var support: Dictionary = bodies[support_index]
					var top := int(support.get("z", 0)) + int(support.get("height", COIN_HEIGHT))
					if absi(int(body.get("z", 0)) - top) > SUPPORT_VERTICAL_TOLERANCE:
						support_index = grid.next_index(support_index)
						continue
					var dx := int(support.get("x", 0)) - int(body.get("x", 0))
					var dy := int(support.get("y", 0)) - int(body.get("y", 0))
					var reach := _divi((int(body.get("radius", COIN_RADIUS)) + int(support.get("radius", COIN_RADIUS))) * 9, 10)
					if dx * dx + dy * dy >= reach * reach:
						support_index = grid.next_index(support_index)
						continue
					support_count += 1
					centered = centered or _isqrt(dx * dx + dy * dy) < int(body.get("radius", COIN_RADIUS)) / 2
					x_low = x_low or dx <= SUPPORT_MARGIN
					x_high = x_high or dx >= -SUPPORT_MARGIN
					y_low = y_low or dy <= SUPPORT_MARGIN
					y_high = y_high or dy >= -SUPPORT_MARGIN
					centroid_x += dx
					centroid_y += dy
					var support_carried := bool(support.get("carried_sleep", false)) or str(support.get("support_kind", "")) == "platform"
					if top > support_top:
						support_top = top
						top_carried = support_carried
					elif top == support_top:
						top_carried = top_carried or support_carried
					support_index = grid.next_index(support_index)
		if support_count > 0:
			stable = stable or centered or (x_low and x_high and y_low and y_high)
			if not stable:
				var before_nestle := _body_kinetic_energy(body)
				centroid_x = _divi(centroid_x, support_count)
				centroid_y = _divi(centroid_y, support_count)
				var length := maxi(1, _isqrt(centroid_x * centroid_x + centroid_y * centroid_y))
				# `centroid_*` points from this body toward its supports. Move into
				# the bracket; subtracting here drove marginal stacks away forever.
				body["vx"] = int(body.get("vx", 0)) + _divi(centroid_x * GRAVITY, 2 * length)
				body["vy"] = int(body.get("vy", 0)) + _divi(centroid_y * GRAVITY, 2 * length)
				nestle_work += maxi(0, _body_kinetic_energy(body) - before_nestle)
		if stable and int(body.get("vz", 0)) <= 0:
			var was_falling := str(body.get("rest_state", "")) == "falling"
			var fall_start_z := int(body.get("fall_start_z", body.get("z", support_top)))
			var impact_speed := absi(int(body.get("vz", 0)))
			body["z"] = support_top
			body["vz"] = 0
			body["z_remainder"] = 0
			body["support_kind"] = surface_kind if support_top == surface_z else "body"
			body["carried_sleep"] = str(body.get("support_kind", "")) == "platform"
			if str(body.get("support_kind", "")) == "body":
				body["carried_sleep"] = top_carried
			body["rest_state"] = "resting"
			_apply_surface_friction(body, MU_PLATFORM if str(body.get("support_kind", "")) == "platform" else MU_DECK)
			if was_falling:
				var stack_depth := maxi(0, _divi(support_top - surface_z, maxi(1, int(body.get("height", COIN_HEIGHT)))))
				var support_root := "platform" if str(body.get("support_kind", "")) == "platform" or (str(body.get("support_kind", "")) == "body" and top_carried) else "deck"
				var first_support := bool((body.get("meta", {}) as Dictionary).get("inserted", false)) and not bool((body.get("meta", {}) as Dictionary).get("first_support_recorded", false))
				events.append({"kind": "impact", "body_id": str(body.get("id", "")), "support": str(body.get("support_kind", "")), "support_root": support_root, "first_support": first_support, "fall_height": maxi(0, fall_start_z - support_top), "impact_speed": impact_speed, "impact_class": "hard" if impact_speed >= HARD_IMPACT_SPEED else "soft", "stack_depth": stack_depth})
				if first_support:
					(body.get("meta", {}) as Dictionary)["first_support_recorded"] = true
				body.erase("fall_start_z")
		else:
			if str(body.get("rest_state", "")) != "falling":
				body["fall_start_z"] = int(body.get("z", 0))
			if previous_support == "platform":
				body["pending_platform_deposit"] = true
			body["support_kind"] = ""
			body["carried_sleep"] = false
			body["rest_state"] = "falling"
			body["sleep_ticks"] = 0
			body["sleeping"] = false
		if previous_support == "platform" and str(body.get("support_kind", "")) == "deck":
			events.append({"kind": "platform_deposit", "body_id": str(body.get("id", ""))})
			body.erase("pending_platform_deposit")
	return nestle_work


static func _process_exits(state: Dictionary, events: Array) -> void:
	var definition := _definition(state)
	var geometry := _geometry(definition)
	var width := int(geometry.get("width", WIDTH))
	var lip := int(geometry.get("tray_lip_y", TRAY_LIP_Y))
	var gutter := int(geometry.get("gutter_x", GUTTER_X))
	var bodies: Array = state.get("bodies", [])
	for index in range(bodies.size() - 1, -1, -1):
		var body: Dictionary = bodies[index]
		var radius := int(body.get("radius", COIN_RADIUS))
		var x := int(body.get("x", 0))
		var y := int(body.get("y", 0))
		var outcome := ""
		if y - radius < lip:
			outcome = "tray" if x >= gutter and x <= width - gutter else "gutter"
		elif x + radius < gutter or x - radius > width - gutter:
			outcome = "gutter"
		if outcome.is_empty():
			continue
		var entry := {
			"body_id": str(body.get("id", "")),
			"kind": str(body.get("kind", "coin")),
			"value": int((body.get("meta", {}) as Dictionary).get("value", 1 if str(body.get("kind", "")) == "coin" else 0)),
			"item_id": str((body.get("meta", {}) as Dictionary).get("item_id", "")),
			"provenance": ((body.get("meta", {}) as Dictionary).get("provenance", {}) as Dictionary).duplicate(true) if typeof((body.get("meta", {}) as Dictionary).get("provenance", {})) == TYPE_DICTIONARY else {},
		}
		if outcome == "tray":
			(state["tray_ledger"] as Array).append(entry)
		else:
			(state["gutter_ledger"] as Array).append(entry)
		events.append({"kind": outcome, "outcome": outcome, "body_id": str(body.get("id", "")), "body_kind": str(body.get("kind", "coin")), "x": x, "radius": radius, "height": int(body.get("height", COIN_HEIGHT)), "mass": int(body.get("mass", FP)), "tick": int(state.get("tick", 0)), "stroke_cycle": int(state.get("stroke_cycle_serial", 0)), "phase_fp": int(state.get("phase_fp", 0)), "metadata": (body.get("meta", {}) as Dictionary).duplicate(true)})
		bodies.remove_at(index)


static func _apply_trace_input(state: Dictionary, input: Dictionary, rng_value: Variant) -> void:
	match str(input.get("kind", "")):
		"drop":
			if rng_value is RngStream:
				add_coin(state, rng_value as RngStream, int(input.get("x", state.get("carriage_x", WIDTH / 2))), int(input.get("density", 1)), input.get("provenance", {}))
		"carriage":
			set_carriage(state, int(input.get("x", state.get("carriage_x", WIDTH / 2))))
		"hole":
			select_hole(state, int(input.get("index", 0)))
		"skill_stop":
			set_skill_stop(state, bool(input.get("engaged", false)), int(input.get("resume_rate_fp", state.get("motor_run_rate_fp", FP))))
		"motor_rate":
			set_motor_run_rate(state, int(input.get("rate_fp", FP)))
		"nudge":
			apply_nudge(state, int(input.get("x", 0)), int(input.get("y", 0)))
		"gutter_return":
			return_gutter_body(state, input)
		"collect":
			collect_tray(state)


static func _seed_opening_machine(state: Dictionary, rng: RngStream, count: int) -> void:
	var definition := _definition(state)
	var geometry := _geometry(definition)
	var coins := _coins(definition)
	var radius := int(coins.get("radius", COIN_RADIUS))
	var height := int(coins.get("height", COIN_HEIGHT))
	var mass := int(coins.get("mass", FP))
	var face := int(state.get("face_y", FACE_EXTENDED_Y))
	var plate := int(geometry.get("back_plate_y", BACK_PLATE_Y))
	var width := int(geometry.get("width", WIDTH))
	var bodies: Array = state.get("bodies", [])
	var base_positions: Array = []
	var x_step := maxi(radius * 2 + 500, _divi(width - radius * 2, 10))
	var wiggle := [-1700, 700, 1800, -600, -1800, 500, 1600, -900, -1500, 1000]
	# Three authored-width rows on the platform preserve visible top stock.
	for row in range(3):
		for column in range(10):
			var x := radius + 500 + column * x_step + (x_step / 2 if row % 2 == 1 else 0)
			if x > width - radius:
				continue
			var y := plate - radius - row * 8800 + int(wiggle[column]) / 3
			var on_platform := y >= face
			base_positions.append({"x": x, "y": y, "z": int(geometry.get("platform_top_z", PLATFORM_TOP_Z)) if on_platform else int(geometry.get("deck_z", DECK_Z)), "support": "platform" if on_platform else "deck", "carried": on_platform})
	# Two staggered deck rows fill the moving face's working mass without overlap.
	for row in range(2):
		for column in range(10):
			var x := radius + 500 + column * x_step + (x_step / 2 if row % 2 == 1 else 0)
			if x > width - radius:
				continue
			var y := int(geometry.get("tray_lip_y", TRAY_LIP_Y)) + radius + 1200 + row * 7900 + int(wiggle[(column + row * 3) % wiggle.size()]) / 3
			base_positions.append({"x": x, "y": y, "z": int(geometry.get("deck_z", DECK_Z)), "support": "deck", "carried": false})
	for index in range(count):
		var base: Dictionary = base_positions[index % base_positions.size()]
		var layer := index / base_positions.size()
		var layer_x_jitter := rng.randi_range(-180, 180) if layer > 0 else 0
		var layer_y_jitter := rng.randi_range(-180, 180) if layer > 0 else 0
		var body := _new_body(state, "coin", clampi(int(base.get("x", 0)) + layer_x_jitter, radius, width - radius), int(base.get("y", 0)) + layer_y_jitter, int(base.get("z", 0)) + layer * height, radius, height, mass, {"value": int(coins.get("value", 1)), "opening": true})
		body["support_kind"] = str(base.get("support", "deck")) if layer == 0 else "body"
		body["sleeping"] = true
		body["sleep_ticks"] = SLEEP_TICKS
		body["rest_state"] = "resting"
		body["carried_sleep"] = bool(base.get("carried", false))
		# Opening stock is already asleep. Persist only outcome-bearing values;
		# both solver backends reconstruct these zero transient fields exactly.
		for transient_key in ["vx", "vy", "vz", "x_remainder", "y_remainder", "z_remainder", "fall_start_z"]:
			body.erase(transient_key)
		if not bool(body.get("carried_sleep", false)):
			body.erase("carried_sleep")
		bodies.append(body)


static func _new_body(state: Dictionary, kind: String, x: int, y: int, z: int, radius: int, height: int, mass: int, meta: Dictionary) -> Dictionary:
	var next_id := int(state.get("next_body_id", 1))
	state["next_body_id"] = next_id + 1
	return {
		"id": "body_%05d" % next_id,
		"kind": kind,
		"x": x,
		"y": y,
		"z": z,
		"vx": 0,
		"vy": 0,
		"vz": 0,
		"x_remainder": 0,
		"y_remainder": 0,
		"z_remainder": 0,
		"radius": radius,
		"height": height,
		"mass": maxi(1, mass),
		"sleeping": false,
		"sleep_ticks": 0,
		"rest_state": "falling",
		"fall_start_z": z,
		"support_kind": "",
		"carried_sleep": false,
		"meta": meta.duplicate(true),
	}


static func _invariant_report(state: Dictionary, energy_ok: bool) -> Dictionary:
	var active_count := (state.get("bodies", []) as Array).size()
	var tray_count := (state.get("tray_ledger", []) as Array).size()
	var gutter_count := (state.get("gutter_ledger", []) as Array).size()
	var collected_count := int(state.get("collected_count", 0))
	var origin_count := int(state.get("opening_body_count", 0)) + int(state.get("accepted_inserts", 0)) + int(state.get("external_origin_count", 0))
	return {
		"energy_ok": energy_ok,
		"conservation_ok": active_count + tray_count + gutter_count + collected_count == origin_count,
		"active": active_count,
		"tray": tray_count,
		"gutter": gutter_count,
		"collected": collected_count,
		"origin": origin_count,
		"refused": int(state.get("refused_inserts", 0)),
	}


static func _kinetic_energy(bodies: Array) -> int:
	var energy := 0
	for body_value in bodies:
		var body: Dictionary = body_value
		if bool(body.get("sleeping", false)):
			continue
		energy += _body_kinetic_energy(body)
	return energy


static func _body_kinetic_energy(body: Dictionary) -> int:
	var mass := maxi(1, int(body.get("mass", FP)))
	var vx := int(body.get("vx", 0))
	var vy := int(body.get("vy", 0))
	var vz := int(body.get("vz", 0))
	# Keep the exact common fixed-point numerator for invariant comparisons.
	# Per-axis/per-body division made a dissipative contact appear to gain one
	# unit when truncation landed on opposite sides of a boundary.
	return mass * (vx * vx + vy * vy + vz * vz)


static func _integrate_axis(body: Dictionary, position_key: String, velocity_key: String, remainder_key: String) -> void:
	var total := int(body.get(remainder_key, 0)) + int(body.get(velocity_key, 0))
	var whole := _divi(total, FIXED_HZ)
	body[position_key] = int(body.get(position_key, 0)) + whole
	body[remainder_key] = total - whole * FIXED_HZ


static func _total_mass(bodies: Array) -> int:
	var total := 0
	for body_value in bodies:
		var body: Dictionary = body_value
		if not bool(body.get("sleeping", false)):
			total += maxi(1, int(body.get("mass", FP)))
	return total


static func _apply_surface_friction(body: Dictionary, coefficient: int) -> void:
	var keep := clampi(FP - _divi(coefficient, 8), 0, FP)
	body["vx"] = _divi(int(body.get("vx", 0)) * keep, FP)
	body["vy"] = _divi(int(body.get("vy", 0)) * keep, FP)


static func _update_sleep(body: Dictionary) -> void:
	var speed := absi(int(body.get("vx", 0))) + absi(int(body.get("vy", 0))) + absi(int(body.get("vz", 0)))
	if speed < SLEEP_SPEED:
		body["vx"] = 0
		body["vy"] = 0
		body["vz"] = 0
		body["sleep_ticks"] = int(body.get("sleep_ticks", 0)) + 1
		if int(body.get("sleep_ticks", 0)) >= SLEEP_TICKS:
			body["sleeping"] = true
			body["vx"] = 0
			body["vy"] = 0
			body["vz"] = 0
			body["x_remainder"] = 0
			body["y_remainder"] = 0
			body["z_remainder"] = 0
	else:
		body["sleep_ticks"] = 0
		body["sleeping"] = false


static func _wake(body: Dictionary) -> void:
	if bool(body.get("sleeping", false)):
		body["sleep_ticks"] = 0
	body["sleeping"] = false
	body["carried_sleep"] = false
	if str(body.get("rest_state", "")) != "falling":
		body["rest_state"] = "settling"


static func _wake_nearby(bodies: Array, x: int, y: int, radius: int, excluded_id: String = "") -> void:
	var radius_sq := radius * radius
	for body_value in bodies:
		var body: Dictionary = body_value
		if not excluded_id.is_empty() and str(body.get("id", "")) == excluded_id:
			continue
		var dx := int(body.get("x", 0)) - x
		var dy := int(body.get("y", 0)) - y
		if dx * dx + dy * dy <= radius_sq:
			_wake(body)


static func _position_clear(bodies: Array, x: int, y: int, minimum: int) -> bool:
	var minimum_sq := minimum * minimum
	for body_value in bodies:
		var body: Dictionary = body_value
		if int(body.get("z", 0)) > DECK_Z + SUPPORT_VERTICAL_TOLERANCE:
			continue
		var dx := int(body.get("x", 0)) - x
		var dy := int(body.get("y", 0)) - y
		if dx * dx + dy * dy < minimum_sq:
			return false
	return true


static func _z_bands_overlap(left: Dictionary, right: Dictionary) -> bool:
	var left_base := int(left.get("z", 0))
	var right_base := int(right.get("z", 0))
	return left_base < right_base + int(right.get("height", COIN_HEIGHT)) and right_base < left_base + int(left.get("height", COIN_HEIGHT))


static func _definition(state: Dictionary) -> Dictionary:
	return state.get("machine_definition", {}) if typeof(state.get("machine_definition", {})) == TYPE_DICTIONARY else {}


static func _geometry(definition: Dictionary) -> Dictionary:
	return definition.get("geometry", {}) if typeof(definition.get("geometry", {})) == TYPE_DICTIONARY else {}


static func _stroke(definition: Dictionary) -> Dictionary:
	return definition.get("stroke", {}) if typeof(definition.get("stroke", {})) == TYPE_DICTIONARY else {}


static func _apparatus(definition: Dictionary) -> Dictionary:
	return definition.get("apparatus", {}) if typeof(definition.get("apparatus", {})) == TYPE_DICTIONARY else {}


static func _drop_board(definition: Dictionary) -> Dictionary:
	var apparatus := _apparatus(definition)
	var authored: Dictionary = apparatus.get("drop_board", {}) if typeof(apparatus.get("drop_board", {})) == TYPE_DICTIONARY else {}
	var geometry := _geometry(definition)
	return {
		"y": int(authored.get("y", geometry.get("drop_y", DROP_Y))),
		"z_top": int(authored.get("z_top", geometry.get("drop_z", DROP_Z))),
		"z_bottom": int(authored.get("z_bottom", geometry.get("platform_top_z", PLATFORM_TOP_Z))),
	}


static func _default_release_x(definition: Dictionary) -> int:
	var apparatus := _apparatus(definition)
	var holes: Array = apparatus.get("holes", []) if typeof(apparatus.get("holes", [])) == TYPE_ARRAY else []
	if str(apparatus.get("type", "rail_slot")) == "hole_set" and not holes.is_empty():
		return int(holes[holes.size() / 2])
	var rail: Dictionary = apparatus.get("rail", {}) if typeof(apparatus.get("rail", {})) == TYPE_DICTIONARY else {}
	var width := int(_geometry(definition).get("width", WIDTH))
	return (int(rail.get("x_min", 0)) + int(rail.get("x_max", width))) / 2


static func _coins(definition: Dictionary) -> Dictionary:
	return definition.get("coins", {}) if typeof(definition.get("coins", {})) == TYPE_DICTIONARY else {}


static func _ceiling(definition: Dictionary) -> int:
	return clampi(int(definition.get("ceiling", HARD_BODY_CEILING)), 1, HARD_BODY_CEILING)


static func _isqrt(value: int) -> int:
	if value <= 0:
		return 0
	var estimate := value
	var next := _divi(estimate + _divi(value, estimate), 2)
	while next < estimate:
		estimate = next
		next = _divi(estimate + _divi(value, estimate), 2)
	return estimate


static func _floor_div(value: int, divisor: int) -> int:
	if divisor <= 0:
		return 0
	if value >= 0:
		return value / divisor
	return -_divi(-value + divisor - 1, divisor)


static func _divi(numerator: int, denominator: int) -> int:
	if denominator == 0:
		return 0
	return int(numerator / denominator)
