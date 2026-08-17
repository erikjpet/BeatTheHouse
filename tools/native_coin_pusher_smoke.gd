extends SceneTree

const Solver := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	if not ClassDB.class_exists("CoinPusherNativeCore"):
		failures.append("CoinPusherNativeCore was not registered")
	else:
		var core: Object = ClassDB.instantiate("CoinPusherNativeCore")
		if str(core.call("backend_id")) != "coin_pusher_native_integer_v1":
			failures.append("native backend identity drifted")
		var contract: Dictionary = core.call("solver_contract") as Dictionary
		if contract != {"abi_version": 1, "schema": "coin_pusher_fixed_point", "state_version": 1, "fixed_point_scale": 1000, "action_ticks": 48}:
			failures.append("native ABI/solver contract drifted")
		for fixture in [[7, 3, 2], [-7, 3, -2], [7, -3, -2], [-7, -3, 2], [7, 0, 0]]:
			if int(core.call("divi", fixture[0], fixture[1])) != fixture[2]:
				failures.append("integer division drifted for %s" % [fixture])
		var int64_min := -9223372036854775807 - 1
		var int64_max := 9223372036854775807
		if int(core.call("divi", int64_min, -1)) != int64_max or int(core.call("divi", int64_min, 1)) != int64_min:
			failures.append("integer division did not define its INT64_MIN edge safely")
		if int(core.call("pusher_face_y", 0, true)) != 92000 or int(core.call("pusher_face_y", 6000, true)) != 68000:
			failures.append("upper pusher phase geometry drifted")
		var columns := {
			"x": PackedInt32Array([10000, 50000, 90000]),
			"vx": PackedInt32Array([1, 2, 3]),
			"vy": PackedInt32Array([-1, -2, -3]),
			"masses": PackedInt32Array([1, 2, 4]),
			"sleeping": PackedByteArray([1, 1, 1]),
			"sleep_ticks": PackedInt32Array([9, 9, 9]),
			"rest_states": PackedStringArray(["resting", "resting", "resting"]),
		}
		var nudged: Dictionary = core.call("apply_nudge_columns", columns, {
			"nudge_x": 12000, "nudge_y": -8000, "aimed_x": 50000, "nudge_radius": 10000,
		}) as Dictionary
		if not bool(nudged.get("ok", false)) or int(nudged.get("woken_count", -1)) != 1:
			failures.append("packed nudge did not select exactly one body")
		elif (nudged.get("vx", PackedInt32Array()) as PackedInt32Array) != PackedInt32Array([1, 6002, 3]):
			failures.append("packed nudge x impulse drifted")
		elif (nudged.get("vy", PackedInt32Array()) as PackedInt32Array) != PackedInt32Array([-1, -4002, -3]):
			failures.append("packed nudge y impulse drifted")
		var malformed: Dictionary = core.call("apply_nudge_columns", {"x": PackedInt32Array([1])}, {}) as Dictionary
		if bool(malformed.get("ok", true)) or str(malformed.get("error", "")) != "column_size_mismatch":
			failures.append("malformed packed columns were accepted")
		var hostile_columns := {
			"x": PackedInt32Array([0]), "vx": PackedInt32Array([2147483647]), "vy": PackedInt32Array([-2147483648]),
			"masses": PackedInt32Array([1]), "sleeping": PackedByteArray([1]),
			"sleep_ticks": PackedInt32Array([9]), "rest_states": PackedStringArray(["resting"]),
		}
		var hostile_before := JSON.stringify(hostile_columns)
		for hostile_config in [
			{"nudge_x": int64_max, "nudge_y": int64_min, "aimed_x": int64_max, "nudge_radius": int64_max},
			{"nudge_x": 100000000, "nudge_y": -100000000, "aimed_x": 0, "nudge_radius": 100000000},
		]:
			var hostile_result: Dictionary = core.call("apply_nudge_columns", hostile_columns, hostile_config) as Dictionary
			if bool(hostile_result.get("ok", true)) or str(hostile_result.get("error", "")) != "numeric_envelope" or JSON.stringify(hostile_columns) != hostile_before:
				failures.append("hostile native nudge escaped numeric rejection or mutated its input")
		_check_exact_step_backends(core, failures)
	if failures.is_empty():
		print("NATIVE_COIN_PUSHER_SMOKE PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_exact_step_backends(core: Object, failures: Array[String]) -> void:
	Solver.reset_native_backend_for_test()
	if not Solver.native_backend_available_for_test():
		failures.append("production solver adapter did not discover the native backend")
		return
	var source := {
		"schema": Solver.SCHEMA, "version": 1, "fixed_hz": Solver.FIXED_HZ, "fixed_point_scale": Solver.FP,
		"tick": 17, "next_body_id": 6, "coin_cap": 160,
		"bodies": [
			_body("native_a", 47000, 31000, 3400, false),
			_body("native_b", 52500, 31000, 3400, true),
			_body("native_support", 49000, 31000, 1700, true),
			_body("native_exit", 50000, Solver.FRONT_EDGE - Solver.COIN_RADIUS - 10, 0, false),
		],
		"upper_phase_fp": 1700, "lower_phase_fp": 2300,
		"last_events": [], "last_step_metrics": {},
	}
	for base_config in [
		{"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true},
		{"captured_upper_phase_fp": 5100, "captured_lower_phase_fp": 6900, "push_scale": 4,
			"capture_presentation_trace": true, "nudge_x": 1200, "nudge_y": -4200,
			"aimed_x": 50000, "nudge_radius": 100000},
	]:
		var reference_state: Dictionary = source.duplicate(true)
		var fallback_state: Dictionary = source.duplicate(true)
		var native_state: Dictionary = source.duplicate(true)
		var reference_result := Solver.step_action_reference_for_test(reference_state, base_config)
		var fallback_config: Dictionary = base_config.duplicate(true)
		fallback_config["_debug_force_solver_backend"] = "gdscript"
		var fallback_result := Solver.step_action(fallback_state, fallback_config)
		if Solver.last_step_backend_for_test() != "gdscript":
			failures.append("production adapter did not mark the forced GDScript fallback")
		var native_config: Dictionary = base_config.duplicate(true)
		native_config["_debug_force_solver_backend"] = "native"
		var native_result := Solver.step_action(native_state, native_config)
		if Solver.last_step_backend_for_test() != "native":
			failures.append("production adapter did not mark the forced native step")
		if JSON.stringify(reference_state) != JSON.stringify(fallback_state) or JSON.stringify(reference_result) != JSON.stringify(fallback_result):
			failures.append("dictionary reference and forced packed GDScript fallback diverged")
		if JSON.stringify(reference_state) != JSON.stringify(native_state):
			failures.append("native authoritative state diverged from the dictionary oracle")
		if JSON.stringify(reference_result) != JSON.stringify(native_result):
			failures.append("native exits/events/trace/metrics diverged from the dictionary oracle")
		if int(native_state.get("tick", -1)) != int(source.get("tick", 0)) + Solver.ACTION_TICKS:
			failures.append("native authoritative step did not advance exactly 48 fixed ticks")
		if native_result.has("debug_stage_timing_usec"):
			failures.append("production native result leaked non-authoritative wall-clock timing")
	_check_hostile_native_boundary(core, source, failures)


func _check_hostile_native_boundary(core: Object, source: Dictionary, failures: Array[String]) -> void:
	var hostile: Dictionary = source.duplicate(true)
	var hostile_body: Dictionary = (hostile.get("bodies", []) as Array)[0]
	hostile_body["vx"] = 2147483000
	hostile_body["vz"] = -2147483000
	hostile_body["cap_pressure_ticks"] = 2147483000
	hostile_body["cap_pressure_accel"] = 2147483000
	var config := {"upper_locked": true, "lower_locked": true}
	if bool(core.call("can_step", hostile, config)):
		failures.append("native boundary accepted an int64-hostile state outside its arithmetic envelope")
	var hostile_before := JSON.stringify(hostile)
	var rejected: Dictionary = core.call("step_action", hostile, config) as Dictionary
	if not rejected.is_empty() or JSON.stringify(hostile) != hostile_before:
		failures.append("native boundary mutated an ineligible state before deterministic fallback")
	var oracle_state: Dictionary = hostile.duplicate(true)
	var fallback_state: Dictionary = hostile.duplicate(true)
	var oracle_result := Solver.step_action_reference_for_test(oracle_state, config)
	var fallback_result := Solver.step_action(fallback_state, config)
	if Solver.last_step_backend_for_test() != "reference":
		failures.append("production adapter did not mark the int64-hostile dictionary fallback")
	if JSON.stringify(oracle_state) != JSON.stringify(fallback_state) or JSON.stringify(oracle_result) != JSON.stringify(fallback_result):
		failures.append("production int64-hostile fallback diverged from the dictionary oracle")

	var duplicate_ids: Dictionary = source.duplicate(true)
	var duplicate_bodies: Array = duplicate_ids.get("bodies", []) as Array
	(duplicate_bodies[1] as Dictionary)["id"] = str((duplicate_bodies[0] as Dictionary).get("id", ""))
	var duplicate_before := JSON.stringify(duplicate_ids)
	if bool(core.call("can_step", duplicate_ids, config)):
		failures.append("native boundary accepted duplicate authoritative body IDs")
	var duplicate_result: Dictionary = core.call("step_action", duplicate_ids, config) as Dictionary
	if not duplicate_result.is_empty() or JSON.stringify(duplicate_ids) != duplicate_before:
		failures.append("native boundary mutated a duplicate-ID state before fallback")


func _body(id: String, x: int, y: int, z: int, sleeping: bool) -> Dictionary:
	return {
		"id": id, "kind": "coin", "x": x, "y": y, "z": z,
		"vx": 0, "vy": 0, "vz": 0,
		"radius": Solver.COIN_RADIUS, "height": Solver.COIN_HEIGHT, "mass": 1,
		"sleep_ticks": 9 if sleeping else 0, "sleeping": sleeping,
		"rest_state": "resting" if sleeping else "settling", "lean_milli": 0, "metadata": {},
	}
