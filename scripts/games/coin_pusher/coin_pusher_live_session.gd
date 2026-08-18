class_name CoinPusherLiveSession
extends RefCounted

const CoinPusherSolverScript := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")
const SNAPSHOT_SCHEMA := "coin_pusher_settled_v3"
const SNAPSHOT_VERSION := 1
const FIXED_HZ := 60
const MAX_CATCH_UP_TICKS := 4
const MAX_SETTLE_TICKS := 1200


static func begin(machine: Dictionary, machine_definition: Dictionary, seed: int) -> Dictionary:
	if typeof(machine.get("simulation", {})) != TYPE_DICTIONARY \
			or str((machine.get("simulation", {}) as Dictionary).get("schema", "")) != CoinPusherSolverScript.SCHEMA:
		var snapshot: Dictionary = machine.get("settled_state", {}) if typeof(machine.get("settled_state", {})) == TYPE_DICTIONARY else {}
		if str(snapshot.get("schema", "")) == SNAPSHOT_SCHEMA:
			machine["simulation"] = restore_snapshot(snapshot, machine_definition)
			machine["variation_state"] = (snapshot.get("sub_game", {}) as Dictionary).duplicate(true) if typeof(snapshot.get("sub_game", {})) == TYPE_DICTIONARY else {}
			var alarm: Dictionary = snapshot.get("alarm", {}) if typeof(snapshot.get("alarm", {})) == TYPE_DICTIONARY else {}
			machine["tell_rung"] = int(alarm.get("tell_rung", machine.get("tell_rung", 0)))
			machine["alarm_tolerance_remaining"] = int(alarm.get("tolerance", machine.get("alarm_tolerance_remaining", 0)))
			machine["locked_down"] = bool(alarm.get("night_lock", machine.get("locked_down", false)))
	var simulation: Dictionary = machine.get("simulation", {}) if typeof(machine.get("simulation", {})) == TYPE_DICTIONARY else {}
	var rng := RngStream.new()
	rng.configure(seed)
	machine["live_session"] = {
		"open": true,
		"input_locked": false,
		"last_clock_msec": -1,
		"accumulator_units": 0,
		"input_trace": [],
		"input_cursor": 0,
		"rng": rng.snapshot(),
		"start_snapshot": CoinPusherSolverScript.canonical_digest(simulation),
		"liveness_ticks": 0,
	}
	return machine["live_session"]


static func queue_input(machine: Dictionary, input: Dictionary) -> Dictionary:
	var simulation: Dictionary = machine.get("simulation", {}) if typeof(machine.get("simulation", {})) == TYPE_DICTIONARY else {}
	var session: Dictionary = machine.get("live_session", {}) if typeof(machine.get("live_session", {})) == TYPE_DICTIONARY else {}
	if session.is_empty() or bool(session.get("input_locked", false)):
		return {}
	var event := input.duplicate(true)
	event["tick"] = int(simulation.get("tick", 0))
	(session["input_trace"] as Array).append(event)
	return event


static func advance(machine: Dictionary, now_msec: int) -> Dictionary:
	var session: Dictionary = machine.get("live_session", {}) if typeof(machine.get("live_session", {})) == TYPE_DICTIONARY else {}
	var simulation: Dictionary = machine.get("simulation", {}) if typeof(machine.get("simulation", {})) == TYPE_DICTIONARY else {}
	if session.is_empty() or simulation.is_empty() or not bool(session.get("open", false)):
		return {"ticks": 0, "events": []}
	var previous := int(session.get("last_clock_msec", -1))
	if previous < 0:
		session["last_clock_msec"] = now_msec
		return {"ticks": 0, "events": []}
	var elapsed := clampi(now_msec - previous, 0, 1000)
	session["last_clock_msec"] = now_msec
	var units := int(session.get("accumulator_units", 0)) + elapsed * FIXED_HZ
	var due := mini(MAX_CATCH_UP_TICKS, units / 1000)
	if due <= 0:
		session["accumulator_units"] = units
		return {"ticks": 0, "events": []}
	var rng := _session_rng(session)
	var all_events: Array = []
	for _tick in range(due):
		var tick_value := int(simulation.get("tick", 0))
		var trace_slice: Array = []
		var cursor := int(session.get("input_cursor", 0))
		var trace: Array = session.get("input_trace", [])
		while cursor < trace.size() and int((trace[cursor] as Dictionary).get("tick", -1)) == tick_value:
			trace_slice.append(trace[cursor])
			cursor += 1
		session["input_cursor"] = cursor
		var result := CoinPusherSolverScript.step_ticks(simulation, {"input_trace": trace_slice, "rng": rng, "motor_enabled": not bool(machine.get("locked_down", false))}, 1)
		all_events.append_array(result.get("events", []))
	units -= due * 1000
	session["accumulator_units"] = units
	session["rng"] = rng.snapshot()
	session["liveness_ticks"] = int(session.get("liveness_ticks", 0)) + due
	return {"ticks": due, "events": all_events, "backlog_ticks": units / 1000}


static func settle_and_freeze(machine: Dictionary) -> Dictionary:
	var session: Dictionary = machine.get("live_session", {}) if typeof(machine.get("live_session", {})) == TYPE_DICTIONARY else {}
	var simulation: Dictionary = machine.get("simulation", {}) if typeof(machine.get("simulation", {})) == TYPE_DICTIONARY else {}
	if simulation.is_empty():
		return {"settled": true, "ticks": 0, "snapshot_bytes": 0}
	session["input_locked"] = true
	_flush_pending(machine)
	CoinPusherSolverScript.set_skill_stop(simulation, false)
	var result := CoinPusherSolverScript.settle(simulation, not bool(machine.get("locked_down", false)), MAX_SETTLE_TICKS)
	var snapshot := make_snapshot(simulation, machine)
	machine["settled_state"] = snapshot
	machine.erase("simulation")
	machine.erase("live_session")
	result["snapshot_bytes"] = JSON.stringify(snapshot).to_utf8_buffer().size()
	return result


static func make_snapshot(simulation: Dictionary, machine: Dictionary = {}) -> Dictionary:
	var bytes := PackedByteArray()
	var extras: Array = []
	for body_value in simulation.get("bodies", []):
		var body: Dictionary = body_value
		var kind := str(body.get("kind", "coin"))
		var metadata: Dictionary = body.get("meta", {}) if typeof(body.get("meta", {})) == TYPE_DICTIONARY else {}
		var compact_coin := kind == "coin" \
				and str(metadata.get("item_id", "")).is_empty() \
				and (typeof(metadata.get("provenance", {})) != TYPE_DICTIONARY or (metadata.get("provenance", {}) as Dictionary).is_empty())
		if not compact_coin:
			extras.append(_settled_body(body))
			continue
		var numeric_id := int(str(body.get("id", "body_00000")).get_slice("_", 1))
		_append_u16(bytes, clampi(numeric_id, 0, 65535))
		_append_u16(bytes, _quantize_100(int(body.get("x", 0))))
		_append_u16(bytes, _quantize_100(int(body.get("y", 0))))
		_append_u16(bytes, _quantize_100(int(body.get("z", 0))))
		var flags := 0
		if str(body.get("support_kind", "")) == "platform":
			flags |= 1
		if bool(body.get("carried_sleep", false)):
			flags |= 2
		bytes.append(flags)
	var snapshot := {
		"schema": SNAPSHOT_SCHEMA,
		"version": SNAPSHOT_VERSION,
		"machine_id": str(simulation.get("machine_id", "")),
		"phase_fp": int(simulation.get("phase_fp", 0)),
		"carriage_x": int(simulation.get("carriage_x", 50000)),
		"selected_hole": int(simulation.get("selected_hole", 0)),
		"next_body_id": int(simulation.get("next_body_id", 1)),
		"coin_blob": Marshalls.raw_to_base64(bytes),
		"extra_bodies": extras,
		"tray_ledger": (simulation.get("tray_ledger", []) as Array).duplicate(true),
		"sub_game": (machine.get("variation_state", {}) as Dictionary).duplicate(true) if typeof(machine.get("variation_state", {})) == TYPE_DICTIONARY else {},
		"alarm": {
			"tell_rung": int(machine.get("tell_rung", 0)),
			"tolerance": int(machine.get("alarm_tolerance_remaining", 0)),
			"night_lock": bool(machine.get("locked_down", false)),
		},
	}
	return snapshot


static func restore_snapshot(snapshot: Dictionary, machine_definition: Dictionary) -> Dictionary:
	var rng := RngStream.new()
	rng.configure(1)
	var simulation := CoinPusherSolverScript.create_machine(rng, machine_definition, 0)
	simulation["phase_fp"] = int(snapshot.get("phase_fp", 0))
	var period := maxi(1, int((machine_definition.get("stroke", {}) as Dictionary).get("period_ticks", 240)))
	var phase := posmod(int(simulation["phase_fp"]) / CoinPusherSolverScript.FP, period)
	simulation["face_y"] = CoinPusherSolverScript.face_y_for_phase(machine_definition, phase)
	simulation["previous_face_y"] = int(simulation["face_y"])
	simulation["carriage_x"] = int(snapshot.get("carriage_x", 50000))
	simulation["selected_hole"] = int(snapshot.get("selected_hole", 0))
	simulation["next_body_id"] = int(snapshot.get("next_body_id", 1))
	var bodies: Array = []
	var raw := Marshalls.base64_to_raw(str(snapshot.get("coin_blob", "")))
	var cursor := 0
	while cursor + 8 < raw.size():
		var body_id := _read_u16(raw, cursor)
		cursor += 2
		var x := _read_u16(raw, cursor) * 100
		cursor += 2
		var y := _read_u16(raw, cursor) * 100
		cursor += 2
		var z := _read_u16(raw, cursor) * 100
		cursor += 2
		var flags := int(raw[cursor])
		cursor += 1
		bodies.append(_restored_body("body_%05d" % body_id, "coin", x, y, z, {}, machine_definition, "platform" if (flags & 1) != 0 else "deck", (flags & 2) != 0))
	for body_value in snapshot.get("extra_bodies", []):
		if typeof(body_value) == TYPE_DICTIONARY:
			bodies.append(_restore_extra(body_value as Dictionary, machine_definition))
	simulation["bodies"] = bodies
	simulation["opening_body_count"] = bodies.size()
	simulation["accepted_inserts"] = bodies.size()
	simulation["tray_ledger"] = (snapshot.get("tray_ledger", []) as Array).duplicate(true)
	simulation["skill_stop_engaged"] = false
	simulation["motor_rate_fp"] = CoinPusherSolverScript.FP
	simulation["motor_target_rate_fp"] = CoinPusherSolverScript.FP
	return simulation


static func _flush_pending(machine: Dictionary) -> void:
	var session: Dictionary = machine.get("live_session", {})
	var simulation: Dictionary = machine.get("simulation", {})
	var trace: Array = session.get("input_trace", [])
	var cursor := int(session.get("input_cursor", 0))
	if cursor >= trace.size():
		return
	var rng := _session_rng(session)
	var pending: Array = []
	for index in range(cursor, trace.size()):
		var event: Dictionary = (trace[index] as Dictionary).duplicate(true)
		event["tick"] = int(simulation.get("tick", 0))
		pending.append(event)
	CoinPusherSolverScript.step_ticks(simulation, {"input_trace": pending, "rng": rng}, 1)
	session["input_cursor"] = trace.size()
	session["rng"] = rng.snapshot()


static func _session_rng(session: Dictionary) -> RngStream:
	var rng := RngStream.new()
	rng.restore(session.get("rng", {}))
	return rng


static func _settled_body(body: Dictionary) -> Dictionary:
	return {"id": str(body.get("id", "")), "kind": str(body.get("kind", "coin")), "x": _quantize_100(int(body.get("x", 0))), "y": _quantize_100(int(body.get("y", 0))), "z": _quantize_100(int(body.get("z", 0))), "support": str(body.get("support_kind", "deck")), "carried": bool(body.get("carried_sleep", false)), "meta": (body.get("meta", {}) as Dictionary).duplicate(true)}


static func _restore_extra(body: Dictionary, definition: Dictionary) -> Dictionary:
	return _restored_body(str(body.get("id", "")), str(body.get("kind", "coin")), int(body.get("x", 0)) * 100, int(body.get("y", 0)) * 100, int(body.get("z", 0)) * 100, body.get("meta", {}), definition, str(body.get("support", "deck")), bool(body.get("carried", false)))


static func _restored_body(id: String, kind: String, x: int, y: int, z: int, meta: Dictionary, definition: Dictionary, support: String, carried: bool) -> Dictionary:
	var coins: Dictionary = definition.get("coins", {})
	return {"id": id, "kind": kind, "x": x, "y": y, "z": z, "vx": 0, "vy": 0, "vz": 0, "radius": int(coins.get("radius", 4300)), "height": int(coins.get("height", 1700)), "mass": int(coins.get("mass", 1000)), "sleeping": true, "sleep_ticks": 8, "rest_state": "resting", "support_kind": support, "carried_sleep": carried, "meta": meta.duplicate(true)}


static func _append_u16(bytes: PackedByteArray, value: int) -> void:
	bytes.append(value & 255)
	bytes.append((value >> 8) & 255)


static func _read_u16(bytes: PackedByteArray, offset: int) -> int:
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8)


static func _quantize_100(value: int) -> int:
	return clampi((value + 50) / 100 if value >= 0 else -((-value + 50) / 100), 0, 65535)
