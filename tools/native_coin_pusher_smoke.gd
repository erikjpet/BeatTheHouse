extends SceneTree

const Solver := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")

const RESULT_MARKER := "COIN_PUSHER_V3_SMOKE_RESULT="
const REPLAY_TICKS := 260
const OPENING_BODY_COUNT := 40

# This is the default Quarter Falls machine from Amendment 6.2. Keep the
# geometry literal here: this smoke is also a compact cross-export contract,
# so a relabelled or inverted face stroke must fail before replay evidence is
# accepted.
const MACHINE_DEFINITION := {
	"machine_id": "quarter_falls",
	"geometry": {
		"width": 100000,
		"tray_lip_y": 6000,
		"deck_z": 0,
		"platform_top_z": 3600,
		"face_extended_y": 28000,
		"face_retracted_y": 46000,
		"back_plate_y": 63000,
		"back_plate_gap": 400,
		"drop_y": 58000,
		"drop_z": 24000,
		"gutter_x": 3000,
	},
	"stroke": {
		"period_ticks": 240,
		"ramp_ticks": 24,
		"profile": "cosine",
	},
	"apparatus": {
		"type": "rail_slot",
		"rail": {"x_min": 8000, "x_max": 92000, "speed_per_tick": 900},
		"holes": [],
		"drop_board": {"y": 58000, "z_top": 24000, "z_bottom": 3600, "x_min": 0, "x_max": 100000},
		"pegs": [
			{"x": 30000, "z": 9000, "r": 1200},
			{"x": 50000, "z": 9000, "r": 1200},
			{"x": 70000, "z": 9000, "r": 1200},
		],
		"release_jitter": 300,
	},
	"coins": {
		"radius": 4300,
		"height": 1700,
		"mass": 1000,
		"value": 1,
		"drop_cost": 1,
	},
	"ceiling": 600,
}


func _initialize() -> void:
	var report := _run_smoke()
	print(RESULT_MARKER + JSON.stringify(report))
	if bool(report.get("ok", false)):
		# Retain the long-standing CLI marker while qualifying what it proves.
		# The legacy filename is not evidence that a V3 native backend exists.
		print("NATIVE_COIN_PUSHER_SMOKE PASS (V3 export-parity replay; backend=%s; native_backend_available=%s)" % [
			str(report.get("solver_backend", "")),
			str(report.get("native_backend_available", false)),
		])
		quit(0)
		return
	for failure_value in report.get("failures", []):
		push_error(str(failure_value))
	quit(1)


func _run_smoke() -> Dictionary:
	var failures: Array[String] = []
	_check_amendment_6_2_definition(failures)
	_check_solver_contract(failures)

	var snapshot := Solver.create_machine(_rng("PUSHER-V3-SMOKE-SNAPSHOT"), MACHINE_DEFINITION, OPENING_BODY_COUNT)
	_check_created_snapshot(snapshot, failures)
	var snapshot_digest := Solver.canonical_digest(snapshot)
	var snapshot_digest_json := _canonical_json(snapshot_digest)
	var start_tick := int(snapshot.get("tick", 0))
	var input_trace := _input_trace(start_tick)
	_check_input_trace(input_trace, start_tick, failures)
	var input_trace_json := _canonical_json(input_trace)

	var first := Solver.replay_input_trace(
		snapshot,
		_rng("PUSHER-V3-SMOKE-REPLAY"),
		input_trace,
		REPLAY_TICKS
	)
	var second := Solver.replay_input_trace(
		snapshot,
		_rng("PUSHER-V3-SMOKE-REPLAY"),
		input_trace,
		REPLAY_TICKS
	)
	var first_digest := Solver.canonical_digest(first)
	var second_digest := Solver.canonical_digest(second)
	var first_digest_json := _canonical_json(first_digest)
	var second_digest_json := _canonical_json(second_digest)
	var repeat_exact := first_digest_json == second_digest_json

	if _canonical_json(Solver.canonical_digest(snapshot)) != snapshot_digest_json:
		failures.append("V3 replay mutated the settled source snapshot.")
	if not repeat_exact:
		failures.append("V3 tick-stamped input trace was not bit-identical across independent replays.")
	if int(first.get("tick", -1)) != start_tick + REPLAY_TICKS:
		failures.append("V3 replay did not advance exactly %d fixed ticks." % REPLAY_TICKS)
	if int(first_digest.get("accepted_inserts", -1)) != 2:
		failures.append("V3 replay did not apply both tick-stamped drop inputs exactly once.")
	if int(first_digest.get("motor_target_rate_fp", -1)) != Solver.FP:
		failures.append("V3 replay did not apply the tick-stamped skill-stop release.")
	if first_digest_json == snapshot_digest_json:
		failures.append("V3 replay produced no canonical state change from its input trace.")
	if first_digest_json.is_empty() or first_digest_json.sha256_text().is_empty():
		failures.append("V3 replay did not publish a canonical digest suitable for export parity.")

	var native_available := Solver.native_backend_available_for_test()
	var backend := Solver.last_step_backend_for_test()
	if backend.is_empty():
		failures.append("V3 solver did not identify the backend that produced the replay.")

	return {
		"ok": failures.is_empty(),
		"schema": "coin_pusher_v3_export_parity_smoke",
		"version": 1,
		"platform": OS.get_name(),
		"web_feature": OS.has_feature("web"),
		"distribution_feature": OS.has_feature("distribution_build"),
		"solver_schema": str(snapshot.get("schema", "")),
		"solver_version": int(snapshot.get("version", 0)),
		"solver_backend": backend,
		"native_backend_available": native_available,
		"opening_body_count": int(snapshot.get("opening_body_count", -1)),
		"input_count": input_trace.size(),
		"input_trace_sha256": input_trace_json.sha256_text(),
		"replay_ticks": REPLAY_TICKS,
		"initial_digest_sha256": snapshot_digest_json.sha256_text(),
		"final_digest_sha256": first_digest_json.sha256_text(),
		"repeat_digest_sha256": second_digest_json.sha256_text(),
		"repeat_exact": repeat_exact,
		"final_digest": first_digest,
		"failure_count": failures.size(),
		"failures": failures,
	}


func _check_amendment_6_2_definition(failures: Array[String]) -> void:
	var geometry: Dictionary = MACHINE_DEFINITION.get("geometry", {})
	var expected_geometry := {
		"width": 100000,
		"tray_lip_y": 6000,
		"deck_z": 0,
		"platform_top_z": 3600,
		"face_extended_y": 28000,
		"face_retracted_y": 46000,
		"back_plate_y": 63000,
		"back_plate_gap": 400,
		"drop_y": 58000,
		"drop_z": 24000,
		"gutter_x": 3000,
	}
	_check_exact_dictionary("Amendment 6.2 geometry", geometry, expected_geometry, failures)
	var stroke: Dictionary = MACHINE_DEFINITION.get("stroke", {})
	_check_exact_dictionary("Amendment 6.2 stroke", stroke, {
		"period_ticks": 240,
		"ramp_ticks": 24,
		"profile": "cosine",
	}, failures)
	var coins: Dictionary = MACHINE_DEFINITION.get("coins", {})
	_check_exact_dictionary("Amendment 6.2 coin body", coins, {
		"radius": 4300,
		"height": 1700,
		"mass": 1000,
		"value": 1,
		"drop_cost": 1,
	}, failures)
	var apparatus: Dictionary = MACHINE_DEFINITION.get("apparatus", {})
	var rail: Dictionary = apparatus.get("rail", {})
	_check_exact_dictionary("Amendment 6.2 entry rail", rail, {
		"x_min": 8000,
		"x_max": 92000,
		"speed_per_tick": 900,
	}, failures)
	var expected_pegs := [
		{"x": 30000, "z": 9000, "r": 1200},
		{"x": 50000, "z": 9000, "r": 1200},
		{"x": 70000, "z": 9000, "r": 1200},
	]
	if str(apparatus.get("type", "")) != "rail_slot" \
			or int(apparatus.get("release_jitter", -1)) != 300 \
			or apparatus.get("pegs", []) != expected_pegs:
		failures.append("Amendment 6.2 entry apparatus drifted from the three-peg Quarter Falls contract.")
	if int(MACHINE_DEFINITION.get("ceiling", 0)) != 600:
		failures.append("Amendment 6.2 hard body ceiling drifted from 600.")
	if Solver.face_y_for_phase(MACHINE_DEFINITION, 0) != 28000 \
			or Solver.face_y_for_phase(MACHINE_DEFINITION, 120) != 46000:
		failures.append("Amendment 6.2 face orientation drifted: phase 0 must be extended at y=28000 and phase 120 retracted at y=46000.")
	var delivery_board: Dictionary = apparatus.get("drop_board", {})
	if int(delivery_board.get("y", 0)) != 58000 or int(delivery_board.get("z_top", 0)) != 24000 or int(delivery_board.get("z_bottom", 0)) != 3600:
		failures.append("Amendment 6.2 rear delivery board drifted from the visible 58000/24000-to-3600 contract.")


func _check_solver_contract(failures: Array[String]) -> void:
	var contract := Solver.implementation_contract()
	var expected := {
		"schema": "coin_pusher_machine_v3",
		"version": 3,
		"fixed_hz": 60,
		"fixed_point_scale": 1000,
		"hard_body_ceiling": 600,
		"broadphase_cell": 10000,
		"candidate_pool_capacity": 19200,
		"solver_passes": 6,
		"contact_normal": "radial_euclidean",
		"support_rule": "multi_contact_bracket_nestle",
		"transport_rule": "platform_carry_plus_back_plate",
		"geometry_amendment": "6.2",
	}
	_check_exact_dictionary("V3 solver implementation contract", contract, expected, failures)


func _check_created_snapshot(snapshot: Dictionary, failures: Array[String]) -> void:
	if str(snapshot.get("schema", "")) != "coin_pusher_machine_v3" \
			or int(snapshot.get("version", 0)) != 3 \
			or int(snapshot.get("fixed_hz", 0)) != 60 \
			or int(snapshot.get("fixed_point_scale", 0)) != 1000:
		failures.append("create_machine did not publish the V3 fixed-point snapshot contract.")
	if str(snapshot.get("machine_id", "")) != "quarter_falls":
		failures.append("create_machine lost the Quarter Falls machine identity.")
	if int(snapshot.get("opening_body_count", -1)) != OPENING_BODY_COUNT \
			or (snapshot.get("bodies", []) as Array).size() != OPENING_BODY_COUNT:
		failures.append("create_machine did not seed exactly %d opening bodies." % OPENING_BODY_COUNT)
	var definition: Dictionary = snapshot.get("machine_definition", {})
	if definition != MACHINE_DEFINITION:
		failures.append("create_machine did not retain the exact Amendment 6.2 machine definition.")


func _check_input_trace(trace: Array, start_tick: int, failures: Array[String]) -> void:
	var previous_tick := start_tick - 1
	var allowed_kinds := ["drop", "skill_stop", "nudge"]
	for input_value in trace:
		if typeof(input_value) != TYPE_DICTIONARY:
			failures.append("V3 export-parity input trace contains a non-dictionary entry.")
			continue
		var input: Dictionary = input_value
		var tick := int(input.get("tick", -1))
		if tick <= previous_tick or tick < start_tick or tick >= start_tick + REPLAY_TICKS:
			failures.append("V3 export-parity input trace is not strictly ordered within the replay window at tick %d." % tick)
		if not allowed_kinds.has(str(input.get("kind", ""))):
			failures.append("V3 export-parity input trace contains unsupported kind '%s'." % str(input.get("kind", "")))
		previous_tick = tick


func _input_trace(start_tick: int) -> Array:
	return [
		{"tick": start_tick + 5, "kind": "drop", "x": 42000, "density": 1},
		{"tick": start_tick + 60, "kind": "skill_stop", "engaged": true},
		{"tick": start_tick + 96, "kind": "drop", "x": 58000, "density": 2},
		{"tick": start_tick + 130, "kind": "skill_stop", "engaged": false},
		{"tick": start_tick + 160, "kind": "nudge", "x": 700, "y": -900},
	]


func _check_exact_dictionary(label: String, actual: Dictionary, expected: Dictionary, failures: Array[String]) -> void:
	if actual != expected:
		failures.append("%s drifted: expected %s, got %s." % [
			label,
			_canonical_json(expected),
			_canonical_json(actual),
		])


func _canonical_json(value: Variant) -> String:
	return JSON.stringify(value, "", true)


func _rng(seed: String) -> RngStream:
	var rng := RngStream.new()
	rng.configure(_stable_hash(seed))
	return rng


func _stable_hash(value: String) -> int:
	var hash_value := 2166136261
	for byte in value.to_utf8_buffer():
		hash_value = int((hash_value ^ int(byte)) * 16777619) & 0x7fffffff
	return hash_value
