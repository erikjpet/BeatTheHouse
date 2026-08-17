extends SceneTree

const Solver := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")


class ScriptedNativeSubclass:
	extends CoinPusherNativeCore

	var can_step_called := false
	var step_action_called := false

	@warning_ignore("native_method_override")
	func can_step(state: Dictionary, _config: Dictionary) -> bool:
		can_step_called = true
		var bodies: Array = state.get("bodies", [])
		if not bodies.is_empty():
			var metadata: Dictionary = (bodies[0] as Dictionary).get("metadata", {})
			var nested: Dictionary = metadata.get("nested", {})
			nested["sentinel"] = "scripted_mutation"
		return false

	@warning_ignore("native_method_override")
	func step_action(_state: Dictionary, _config: Dictionary) -> Dictionary:
		step_action_called = true
		return {}


func _initialize() -> void:
	var failures: Array[String] = []
	if not ClassDB.class_exists("CoinPusherNativeCore"):
		failures.append("CoinPusherNativeCore was not registered")
	else:
		var core: Object = ClassDB.instantiate("CoinPusherNativeCore")
		if str(core.call("backend_id")) != "coin_pusher_native_integer_v1":
			failures.append("native backend identity drifted")
		var contract: Dictionary = core.call("solver_contract") as Dictionary
		if contract != {"abi_version": 1, "schema": "coin_pusher_fixed_point", "state_version": 1, "fixed_point_scale": 1000, "action_ticks": 48, "packed_trace_version": 1}:
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
		var decoded_native_result := _legacy_solver_result(native_result)
		if JSON.stringify(reference_result) != JSON.stringify(decoded_native_result):
			failures.append("native exits/events/trace/metrics diverged from the dictionary oracle")
		if int(native_state.get("tick", -1)) != int(source.get("tick", 0)) + Solver.ACTION_TICKS:
			failures.append("native authoritative step did not advance exactly 48 fixed ticks")
		if native_result.has("debug_stage_timing_usec"):
			failures.append("production native result leaked non-authoritative wall-clock timing")
		_check_trace_contract(source, native_state, decoded_native_result, failures)
		var finalized_packed := Solver.finalize_packed_presentation_trace(native_result.get("presentation_trace_packed", {}), native_state, Solver.ACTION_TICKS + 1)
		var finalized_trace := Solver.decode_packed_presentation_trace(finalized_packed)
		var expected_finalized_trace: Array = reference_result.get("presentation_trace", []).duplicate(true)
		expected_finalized_trace.append({
			"tick_offset": Solver.ACTION_TICKS + 1,
			"upper_phase_fp": int(native_state.get("upper_phase_fp", 0)),
			"lower_phase_fp": int(native_state.get("lower_phase_fp", 0)),
			"bodies": Solver.body_views(native_state),
		})
		if JSON.stringify(finalized_trace) != JSON.stringify(expected_finalized_trace):
			failures.append("native packed tick-49 finalization did not decode to the exact legacy 14-frame trace")
		_check_trusted_contract_negatives(core, source, base_config, failures)
	_check_scripted_native_transaction(source, failures)
	_check_full_cap_adapter_selection(failures)
	_check_hostile_native_boundary(core, source, failures)


func _check_full_cap_adapter_selection(failures: Array[String]) -> void:
	var rng := RngStream.new()
	rng.configure(19770123)
	var state: Dictionary = Solver.create(rng, 160, 160, 5)
	var drop_rng := rng.fork("full-cap-drop")
	Solver.add_coin(state, drop_rng, 2, 5)
	var result := Solver.step_action(state, {
		"captured_upper_phase_fp": 1700,
		"captured_lower_phase_fp": 2300,
		"push_scale": 3,
		"capture_presentation_trace": true,
		"_debug_profile_stages": true,
	})
	if Solver.last_step_backend_for_test() != "native":
		failures.append("full-cap production adapter rejected the real native result and double-ran the GDScript fallback")
	if int((result.get("metrics", {}) as Dictionary).get("fixed_ticks", 0)) != Solver.ACTION_TICKS:
		failures.append("full-cap native adapter smoke did not complete its fixed-tick action")
	if int((result.get("presentation_trace_packed", {}) as Dictionary).get("frame_count", 0)) != 13 \
			or Solver.decode_packed_presentation_trace(result.get("presentation_trace_packed", {})).size() != 13:
		failures.append("full-cap native adapter did not publish all 13 solver frames through the packed trace boundary")


func _legacy_solver_result(result: Dictionary) -> Dictionary:
	if typeof(result.get("presentation_trace_packed")) != TYPE_DICTIONARY:
		return result
	var comparable := result.duplicate(false)
	comparable["presentation_trace"] = Solver.decode_packed_presentation_trace(result.get("presentation_trace_packed", {}))
	comparable.erase("presentation_trace_packed")
	return comparable


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


func _check_scripted_native_transaction(source: Dictionary, failures: Array[String]) -> void:
	var backend := ScriptedNativeSubclass.new()
	Solver.install_native_backend_for_test(backend)
	var config := {"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true}
	var oracle_state := source.duplicate(true)
	var oracle_result := Solver.step_action_reference_for_test(oracle_state, config)
	var actual_state := source.duplicate(true)
	var actual_result := Solver.step_action(actual_state, config)
	if not backend.can_step_called or backend.step_action_called:
		failures.append("scripted native subclass bypassed the untrusted can_step transaction")
	if JSON.stringify(actual_state) != JSON.stringify(oracle_state) or JSON.stringify(actual_result) != JSON.stringify(oracle_result):
		failures.append("scripted native subclass leaked a nested candidate mutation or changed deterministic fallback")
	if Solver.last_step_backend_for_test() != "gdscript":
		failures.append("scripted native subclass was incorrectly trusted as the exact native backend")
	Solver.reset_native_backend_for_test()


func _check_trusted_contract_negatives(core: Object, source: Dictionary, config: Dictionary, failures: Array[String]) -> void:
	var before := source.duplicate(true)
	var candidate := source.duplicate(true)
	var result: Dictionary = core.call("step_action", candidate, config) as Dictionary
	if not Solver.native_step_contract_valid_for_test(before, candidate, result, config, true):
		failures.append("trusted native contract rejected an exact native result")
		return
	var fixtures: Array = []
	var duplicate_candidate := candidate.duplicate(true)
	(duplicate_candidate.get("bodies", []) as Array).append(((duplicate_candidate.get("bodies", []) as Array)[0] as Dictionary).duplicate(true))
	var duplicate_result := result.duplicate(true)
	_sync_contract_body_count(duplicate_candidate, duplicate_result)
	fixtures.append(["duplicate body", duplicate_candidate, duplicate_result])
	var reorder_candidate := candidate.duplicate(true)
	var reorder_bodies: Array = reorder_candidate.get("bodies", [])
	if reorder_bodies.size() >= 2:
		var reordered: Variant = reorder_bodies[0]
		reorder_bodies[0] = reorder_bodies[1]
		reorder_bodies[1] = reordered
	fixtures.append(["reordered body", reorder_candidate, result.duplicate(true)])
	var missing_candidate := candidate.duplicate(true)
	(missing_candidate.get("bodies", []) as Array).remove_at(0)
	var missing_result := result.duplicate(true)
	_sync_contract_body_count(missing_candidate, missing_result)
	fixtures.append(["unreported missing body", missing_candidate, missing_result])
	var extra_candidate := candidate.duplicate(true)
	var extra_body := ((extra_candidate.get("bodies", []) as Array)[0] as Dictionary).duplicate(true)
	extra_body["id"] = "native_extra"
	(extra_candidate.get("bodies", []) as Array).append(extra_body)
	var extra_result := result.duplicate(true)
	_sync_contract_body_count(extra_candidate, extra_result)
	fixtures.append(["extra body", extra_candidate, extra_result])
	for mutation in ["add", "remove", "change"]:
		var immutable_candidate := candidate.duplicate(true)
		var immutable_body: Dictionary = (immutable_candidate.get("bodies", []) as Array)[0]
		if mutation == "add":
			immutable_body["smuggled"] = true
		elif mutation == "remove":
			immutable_body.erase("kind")
		else:
			immutable_body["kind"] = "rider"
		fixtures.append(["immutable %s" % mutation, immutable_candidate, result.duplicate(true)])
	var malformed_candidate := candidate.duplicate(true)
	((malformed_candidate.get("bodies", []) as Array)[0] as Dictionary)["x"] = "bad"
	fixtures.append(["malformed mutable", malformed_candidate, result.duplicate(true)])
	var unreported_result := result.duplicate(true)
	unreported_result["events"] = []
	var unreported_candidate := candidate.duplicate(true)
	unreported_candidate["last_events"] = []
	fixtures.append(["unreported physical exit", unreported_candidate, unreported_result])
	for fixture in fixtures:
		if Solver.native_step_contract_valid_for_test(before, fixture[1], fixture[2], config, true):
			failures.append("trusted native contract accepted %s" % str(fixture[0]))


func _sync_contract_body_count(candidate: Dictionary, result: Dictionary) -> void:
	var metrics: Dictionary = result.get("metrics", {})
	metrics["body_count"] = (candidate.get("bodies", []) as Array).size()
	result["metrics"] = metrics
	candidate["last_step_metrics"] = metrics


func _check_trace_contract(source: Dictionary, authority: Dictionary, result: Dictionary, failures: Array[String]) -> void:
	var trace: Array = result.get("presentation_trace", [])
	var expected_keys := ["id", "kind", "material_category", "x", "y", "z", "radius", "height", "mass", "sleeping", "rest_state", "level", "lean_milli", "metadata"]
	var expected_exit_keys := ["id", "kind", "material_category", "x", "y", "z", "radius", "height", "mass", "sleeping", "rest_state", "lean_milli", "metadata"]
	for frame_value in trace:
		var frame: Dictionary = frame_value
		for body_value in frame.get("bodies", []):
			var body: Dictionary = body_value
			var expected: Array = expected_keys if body.has("level") else expected_exit_keys
			if body.keys() != expected:
				failures.append("native trace body key insertion order diverged from the reference contract")
				return
	var first_metadata := _trace_metadata(trace, "native_a", 0)
	var second_metadata := _trace_metadata(trace, "native_a", 1)
	var authority_metadata := _body_metadata(authority, "native_a")
	if first_metadata.is_empty() or second_metadata.is_empty() or authority_metadata.is_empty():
		failures.append("native trace metadata isolation fixture was incomplete")
		return
	((first_metadata.get("nested", {}) as Dictionary))["sentinel"] = "frame_mutation"
	if str(((second_metadata.get("nested", {}) as Dictionary)).get("sentinel", "")) != "native_a" \
			or str(((authority_metadata.get("nested", {}) as Dictionary)).get("sentinel", "")) != "native_a":
		failures.append("native trace frame nested metadata aliased a sibling frame or authority")
	var events: Array = result.get("events", [])
	if not events.is_empty():
		var event_metadata: Dictionary = (events[0] as Dictionary).get("metadata", {})
		var exit_frame_metadata := _trace_metadata(trace, str((events[0] as Dictionary).get("body_id", "")), 1)
		if not event_metadata.is_empty() and not exit_frame_metadata.is_empty():
			((event_metadata.get("nested", {}) as Dictionary))["sentinel"] = "event_mutation"
			if str(((exit_frame_metadata.get("nested", {}) as Dictionary)).get("sentinel", "")) == "event_mutation":
				failures.append("native physical-exit nested metadata aliased its published trace frame")
	var source_metadata := _body_metadata(source, "native_exit")
	if not source_metadata.is_empty() and str(((source_metadata.get("nested", {}) as Dictionary)).get("sentinel", "")) != "native_exit":
		failures.append("native published metadata mutated the source authority")


func _trace_metadata(trace: Array, body_id: String, occurrence: int) -> Dictionary:
	var found := 0
	for frame_value in trace:
		for body_value in (frame_value as Dictionary).get("bodies", []):
			var body: Dictionary = body_value
			if str(body.get("id", "")) == body_id:
				if found == occurrence:
					return body.get("metadata", {})
				found += 1
	return {}


func _body_metadata(state: Dictionary, body_id: String) -> Dictionary:
	for body_value in state.get("bodies", []):
		var body: Dictionary = body_value
		if str(body.get("id", "")) == body_id:
			return body.get("metadata", {})
	return {}


func _body(id: String, x: int, y: int, z: int, sleeping: bool) -> Dictionary:
	return {
		"id": id, "kind": "coin", "x": x, "y": y, "z": z,
		"vx": 0, "vy": 0, "vz": 0,
		"radius": Solver.COIN_RADIUS, "height": Solver.COIN_HEIGHT, "mass": 1,
		"sleep_ticks": 9 if sleeping else 0, "sleeping": sleeping,
		"rest_state": "resting" if sleeping else "settling", "lean_milli": 0,
		"metadata": {"nested": {"sentinel": id}},
	}
