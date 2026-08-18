class_name CoinPusherLiveSession
extends RefCounted

const CoinPusherSolverScript := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")
const SNAPSHOT_SCHEMA := "coin_pusher_settled_v3"
const SNAPSHOT_VERSION := 2
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
	if not simulation.has("carriage_x"):
		var apparatus: Dictionary = machine_definition.get("apparatus", {}) if typeof(machine_definition.get("apparatus", {})) == TYPE_DICTIONARY else {}
		var rail: Dictionary = apparatus.get("rail", {}) if typeof(apparatus.get("rail", {})) == TYPE_DICTIONARY else {}
		var geometry: Dictionary = machine_definition.get("geometry", {}) if typeof(machine_definition.get("geometry", {})) == TYPE_DICTIONARY else {}
		simulation["carriage_x"] = int(rail.get("default_x", int(geometry.get("width", 100000)) / 2))
	if not simulation.has("selected_hole"):
		simulation["selected_hole"] = 0
	if not simulation.has("collected_count"):
		simulation["collected_count"] = 0
	if not simulation.has("collected_value"):
		simulation["collected_value"] = 0
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
		"durable_ready": true,
		"durable_dirty": false,
		"last_persisted_tick": int(simulation.get("tick", 0)),
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
	session["durable_ready"] = false
	session["durable_dirty"] = true
	return event


static func advance(machine: Dictionary, now_msec: int) -> Dictionary:
	var session: Dictionary = machine.get("live_session", {}) if typeof(machine.get("live_session", {})) == TYPE_DICTIONARY else {}
	var simulation: Dictionary = machine.get("simulation", {}) if typeof(machine.get("simulation", {})) == TYPE_DICTIONARY else {}
	if session.is_empty() or simulation.is_empty() or not bool(session.get("open", false)) or bool(session.get("settling_out", false)):
		return {"ticks": 0, "events": []}
	var previous := int(session.get("last_clock_msec", -1))
	if previous < 0:
		session["last_clock_msec"] = now_msec
		return {"ticks": 0, "events": []}
	# Retain the entire hitch in the accumulator. Per-frame work stays capped,
	# but subsequent frames drain the backlog without deleting simulation time.
	var elapsed := maxi(0, now_msec - previous)
	session["last_clock_msec"] = now_msec
	var units := int(session.get("accumulator_units", 0)) + elapsed * FIXED_HZ
	var due := mini(MAX_CATCH_UP_TICKS, units / 1000)
	if due <= 0:
		session["accumulator_units"] = units
		return {"ticks": 0, "events": []}
	var stepped := _step_traced_ticks(machine, due)
	units -= due * 1000
	session["accumulator_units"] = units
	return {"ticks": due, "events": stepped.get("events", []), "backlog_ticks": units / 1000}


static func begin_chunked_settle(machine: Dictionary) -> Dictionary:
	var session: Dictionary = machine.get("live_session", {}) if typeof(machine.get("live_session", {})) == TYPE_DICTIONARY else {}
	if session.is_empty():
		return {"started": false, "done": true}
	session["input_locked"] = true
	session["settling_out"] = true
	session["settle_ticks"] = 0
	session["backlog_drain_ticks"] = 0
	CoinPusherSolverScript.set_skill_stop(machine.get("simulation", {}), false)
	return {"started": true, "done": false}


static func advance_chunked_settle(machine: Dictionary, tick_budget: int = 8) -> Dictionary:
	var session: Dictionary = machine.get("live_session", {}) if typeof(machine.get("live_session", {})) == TYPE_DICTIONARY else {}
	var simulation: Dictionary = machine.get("simulation", {}) if typeof(machine.get("simulation", {})) == TYPE_DICTIONARY else {}
	if session.is_empty() or simulation.is_empty():
		return {"done": true, "ticks": 0}
	var budget := maxi(1, tick_budget)
	var accumulator_units := int(session.get("accumulator_units", 0))
	var trace: Array = session.get("input_trace", []) if typeof(session.get("input_trace", [])) == TYPE_ARRAY else []
	var has_pending_input := int(session.get("input_cursor", 0)) < trace.size()
	if accumulator_units >= 1000 or has_pending_input:
		var backlog_ticks := accumulator_units / 1000
		var drain_ticks := mini(mini(MAX_CATCH_UP_TICKS, budget), maxi(1 if has_pending_input else 0, backlog_ticks))
		var stepped := _step_traced_ticks(machine, drain_ticks)
		session["accumulator_units"] = maxi(0, accumulator_units - mini(backlog_ticks, drain_ticks) * 1000)
		session["backlog_drain_ticks"] = int(session.get("backlog_drain_ticks", 0)) + drain_ticks
		return {"done": false, "ticks": drain_ticks, "total_ticks": int(session.get("settle_ticks", 0)), "backlog_ticks": int(session.get("accumulator_units", 0)) / 1000, "draining_backlog": true, "bounded": true, "events": stepped.get("events", [])}
	var used := int(session.get("settle_ticks", 0))
	var ticks := mini(budget, MAX_SETTLE_TICKS - used)
	var events: Array = []
	if ticks > 0 and not CoinPusherSolverScript.all_steady(simulation, not bool(machine.get("locked_down", false))):
		var step_result := CoinPusherSolverScript.step_ticks(simulation, {"motor_enabled": not bool(machine.get("locked_down", false))}, ticks)
		events = step_result.get("events", []) if typeof(step_result.get("events", [])) == TYPE_ARRAY else []
		used += ticks
		session["settle_ticks"] = used
	var done := CoinPusherSolverScript.all_steady(simulation, not bool(machine.get("locked_down", false))) or used >= MAX_SETTLE_TICKS
	return {"done": done, "ticks": ticks, "total_ticks": used, "bounded": used <= MAX_SETTLE_TICKS, "events": events}


static func freeze_after_chunked_settle(machine: Dictionary, settle_ticks: int) -> Dictionary:
	var simulation: Dictionary = machine.get("simulation", {}) if typeof(machine.get("simulation", {})) == TYPE_DICTIONARY else {}
	if simulation.is_empty():
		return machine.get("settled_state", {})
	var snapshot := make_snapshot(simulation, machine)
	machine["settled_state"] = snapshot
	machine["last_snapshot_bytes"] = JSON.stringify(snapshot).to_utf8_buffer().size()
	machine["last_settle_ticks"] = settle_ticks
	machine.erase("simulation")
	machine.erase("live_session")
	return snapshot


static func make_snapshot(simulation: Dictionary, machine: Dictionary = {}) -> Dictionary:
	var bytes := PackedByteArray()
	var extras: Array = []
	var provenance_sidecar := {}
	var multiplier_nibbles := PackedByteArray()
	var has_multipliers := false
	var compact_count := 0
	var previous_id := 0
	for body_value in simulation.get("bodies", []):
		var body: Dictionary = body_value
		var kind := str(body.get("kind", "coin"))
		var metadata: Dictionary = body.get("meta", {}) if typeof(body.get("meta", {})) == TYPE_DICTIONARY else {}
		var compact_coin := kind == "coin" and str(metadata.get("item_id", "")).is_empty()
		if not compact_coin:
			extras.append(_settled_body(body))
			continue
		var numeric_id := int(str(body.get("id", "body_00000")).get_slice("_", 1))
		_append_varuint(bytes, _zigzag_encode(numeric_id - previous_id))
		previous_id = numeric_id
		var flags := 0
		if str(body.get("support_kind", "")) == "platform":
			flags |= 1
		if bool(body.get("carried_sleep", false)):
			flags |= 2
		if bool(metadata.get("opening", false)):
			flags |= 4
		var x := clampi(_quantize_100(int(body.get("x", 0))), 0, 1023)
		var y := clampi(_quantize_100(int(body.get("y", 0))), 0, 1023)
		var z := clampi(_quantize_100(int(body.get("z", 0))), 0, 511)
		_append_u32(bytes, x | (y << 10) | (z << 20) | (flags << 29))
		var provenance: Dictionary = metadata.get("provenance", {}) if typeof(metadata.get("provenance", {})) == TYPE_DICTIONARY else {}
		var ridge_multiplier := clampi(int(provenance.get("ridge_multiplier", 0)) if str(provenance.get("variation_id", "")) == "jackpot_ridge" else 0, 0, 15)
		var default_nonpaying := not provenance.is_empty() and str(provenance.get("variation_id", "")) != "jackpot_ridge" \
				and int(provenance.get("ridge_multiplier", 1)) == 1 and provenance.keys().all(func(key: Variant) -> bool: return str(key) in ["variation_id", "ridge_multiplier"])
		has_multipliers = has_multipliers or ridge_multiplier > 0
		if compact_count % 2 == 0:
			multiplier_nibbles.append(ridge_multiplier)
		else:
			multiplier_nibbles[multiplier_nibbles.size() - 1] = int(multiplier_nibbles[multiplier_nibbles.size() - 1]) | (ridge_multiplier << 4)
		if not provenance.is_empty() and ridge_multiplier == 0 and not default_nonpaying:
			provenance_sidecar[str(numeric_id)] = provenance.duplicate(true)
		compact_count += 1
	var packed_tray := _pack_tray(simulation.get("tray_ledger", []))
	var snapshot := {
		"schema": SNAPSHOT_SCHEMA,
		"version": SNAPSHOT_VERSION,
		"machine_id": str(simulation.get("machine_id", "")),
		"phase_fp": int(simulation.get("phase_fp", 0)),
		"carriage_x": int(simulation.get("carriage_x", 50000)),
		"selected_hole": int(simulation.get("selected_hole", 0)),
		"next_body_id": int(simulation.get("next_body_id", 1)),
		"coin_count": compact_count,
		"coin_blob": Marshalls.raw_to_base64(bytes),
		"coin_multiplier_blob": Marshalls.raw_to_base64(multiplier_nibbles) if has_multipliers else "",
		"coin_provenance": provenance_sidecar,
		"extra_bodies": extras,
		"tray_count": int(packed_tray.get("count", 0)),
		"tray_coin_blob": str(packed_tray.get("coin_blob", "")),
		"tray_extras": packed_tray.get("extras", []),
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
	if int(snapshot.get("version", 1)) >= 2:
		var previous_id := 0
		var sidecar: Dictionary = snapshot.get("coin_provenance", {}) if typeof(snapshot.get("coin_provenance", {})) == TYPE_DICTIONARY else {}
		var multipliers := Marshalls.base64_to_raw(str(snapshot.get("coin_multiplier_blob", "")))
		for coin_index in range(maxi(0, int(snapshot.get("coin_count", 0)))):
			var decoded := _read_varuint(raw, cursor)
			cursor = int(decoded.get("cursor", cursor))
			var body_id := previous_id + _zigzag_decode(int(decoded.get("value", 0)))
			previous_id = body_id
			if cursor + 3 >= raw.size():
				break
			var packed := _read_u32(raw, cursor)
			cursor += 4
			var flags := (packed >> 29) & 7
			var metadata := {"value": 1}
			if (flags & 4) != 0:
				metadata["opening"] = true
			if typeof(sidecar.get(str(body_id), {})) == TYPE_DICTIONARY and not (sidecar.get(str(body_id), {}) as Dictionary).is_empty():
				metadata["provenance"] = (sidecar.get(str(body_id), {}) as Dictionary).duplicate(true)
			elif coin_index / 2 < multipliers.size():
				var multiplier := (int(multipliers[coin_index / 2]) >> (4 if coin_index % 2 == 1 else 0)) & 15
				if multiplier > 0:
					metadata["provenance"] = {"variation_id": "jackpot_ridge", "ridge_multiplier": multiplier}
			bodies.append(_restored_body("body_%05d" % body_id, "coin", (packed & 1023) * 100, ((packed >> 10) & 1023) * 100, ((packed >> 20) & 511) * 100, metadata, machine_definition, "platform" if (flags & 1) != 0 else "deck", (flags & 2) != 0))
	else:
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
	var restored_tray: Array = _restore_tray(snapshot)
	simulation["opening_body_count"] = bodies.size() + restored_tray.size()
	simulation["accepted_inserts"] = 0
	simulation["collected_count"] = 0
	simulation["collected_value"] = 0
	simulation["tray_ledger"] = restored_tray
	simulation["skill_stop_engaged"] = false
	simulation["motor_rate_fp"] = CoinPusherSolverScript.FP
	simulation["motor_target_rate_fp"] = CoinPusherSolverScript.FP
	return simulation


static func _session_rng(session: Dictionary) -> RngStream:
	var rng := RngStream.new()
	rng.restore(session.get("rng", {}))
	return rng


static func _step_traced_ticks(machine: Dictionary, tick_count: int) -> Dictionary:
	var session: Dictionary = machine.get("live_session", {})
	var simulation: Dictionary = machine.get("simulation", {})
	var rng := _session_rng(session)
	var all_events: Array = []
	for _tick in range(maxi(0, tick_count)):
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
	session["rng"] = rng.snapshot()
	session["liveness_ticks"] = int(session.get("liveness_ticks", 0)) + maxi(0, tick_count)
	return {"events": all_events}


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


static func _append_u32(bytes: PackedByteArray, value: int) -> void:
	for shift in [0, 8, 16, 24]:
		bytes.append((value >> shift) & 255)


static func _read_u32(bytes: PackedByteArray, offset: int) -> int:
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8) | (int(bytes[offset + 2]) << 16) | (int(bytes[offset + 3]) << 24)


static func _append_varuint(bytes: PackedByteArray, value: int) -> void:
	var remaining := maxi(0, value)
	while remaining >= 128:
		bytes.append((remaining & 127) | 128)
		remaining >>= 7
	bytes.append(remaining)


static func _read_varuint(bytes: PackedByteArray, offset: int) -> Dictionary:
	var value := 0
	var shift := 0
	var cursor := offset
	while cursor < bytes.size() and shift <= 28:
		var byte := int(bytes[cursor])
		cursor += 1
		value |= (byte & 127) << shift
		if (byte & 128) == 0:
			break
		shift += 7
	return {"value": value, "cursor": cursor}


static func _zigzag_encode(value: int) -> int:
	return (value << 1) ^ (value >> 31)


static func _zigzag_decode(value: int) -> int:
	return (value >> 1) ^ -(value & 1)


static func _pack_tray(value: Variant) -> Dictionary:
	var ledger: Array = value if typeof(value) == TYPE_ARRAY else []
	var coin_bytes := PackedByteArray()
	var extras: Array = []
	for index in range(ledger.size()):
		var entry: Dictionary = ledger[index] if typeof(ledger[index]) == TYPE_DICTIONARY else {}
		var provenance: Dictionary = entry.get("provenance", {}) if typeof(entry.get("provenance", {})) == TYPE_DICTIONARY else {}
		var variation := str(provenance.get("variation_id", ""))
		var multiplier := clampi(int(provenance.get("ridge_multiplier", 0)) if variation == "jackpot_ridge" else 0, 0, 15)
		var default_nonpaying := not provenance.is_empty() and variation != "jackpot_ridge" \
				and int(provenance.get("ridge_multiplier", 1)) == 1 and provenance.keys().all(func(key: Variant) -> bool: return str(key) in ["variation_id", "ridge_multiplier"])
		var compact := str(entry.get("kind", "coin")) == "coin" and str(entry.get("item_id", "")).is_empty() \
				and int(entry.get("value", 0)) >= 0 and int(entry.get("value", 0)) <= 15 \
				and (provenance.is_empty() or multiplier > 0 or default_nonpaying)
		if compact:
			coin_bytes.append((int(entry.get("value", 0)) & 15) | (multiplier << 4))
		else:
			extras.append({"index": index, "entry": entry.duplicate(true)})
	return {"count": ledger.size(), "coin_blob": Marshalls.raw_to_base64(coin_bytes) if not coin_bytes.is_empty() else "", "extras": extras}


static func _restore_tray(snapshot: Dictionary) -> Array:
	if int(snapshot.get("version", 1)) < 2 or not snapshot.has("tray_count"):
		return (snapshot.get("tray_ledger", []) as Array).duplicate(true)
	var total := maxi(0, int(snapshot.get("tray_count", 0)))
	var result: Array = []
	result.resize(total)
	var occupied := {}
	for extra_value in snapshot.get("tray_extras", []):
		if typeof(extra_value) != TYPE_DICTIONARY:
			continue
		var index := clampi(int((extra_value as Dictionary).get("index", -1)), 0, maxi(0, total - 1))
		result[index] = ((extra_value as Dictionary).get("entry", {}) as Dictionary).duplicate(true)
		occupied[index] = true
	var coin_bytes := Marshalls.base64_to_raw(str(snapshot.get("tray_coin_blob", "")))
	var coin_cursor := 0
	for index in range(total):
		if occupied.has(index):
			continue
		if coin_cursor >= coin_bytes.size():
			result[index] = {"kind": "coin", "value": 0, "item_id": "", "provenance": {}}
			continue
		var packed := int(coin_bytes[coin_cursor])
		coin_cursor += 1
		var multiplier := (packed >> 4) & 15
		result[index] = {"kind": "coin", "value": packed & 15, "item_id": "", "provenance": {"variation_id": "jackpot_ridge", "ridge_multiplier": multiplier} if multiplier > 0 else {}}
	return result


static func _quantize_100(value: int) -> int:
	return clampi((value + 50) / 100 if value >= 0 else -((-value + 50) / 100), 0, 65535)
