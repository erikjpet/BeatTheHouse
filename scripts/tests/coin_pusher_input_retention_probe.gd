extends Node

# PERF-AUDIT-20261104-003 attribution probe. Actual live-session queue/advance
# and native solver, with an intentionally empty valid cabinet and a synthetic
# 60 Hz clock. This measures retained input state, not typical rendered play,
# real-time FPS, or a whole-game leak. It never reads/writes player saves.
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const SolverScript := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")
const LiveSessionScript := preload("res://scripts/games/coin_pusher/coin_pusher_live_session.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const CHECKPOINTS := [1000, 10000, 30000]
const WARMUP_FRAMES := 60
const RESULT_MARKER := "COIN_PUSHER_INPUT_RETENTION_RESULT="


func _ready() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	var started_usec := Time.get_ticks_usec()
	var failures: Array[String] = []
	var library := ContentLibraryScript.new()
	library.load(false)
	var definition: Dictionary = library.game("coin_pusher").get("coin_pusher_machine", {})
	if definition.is_empty():
		_publish({"ok": false, "failures": ["Authored machine definition missing."]})
		return
	var rng := RngStreamScript.new()
	rng.configure(61104003)
	var simulation: Dictionary = SolverScript.create_machine(rng, definition, 0)
	var machine: Dictionary = {"simulation": simulation, "motor_started": true, "locked_down": false}
	var session: Dictionary = LiveSessionScript.begin(machine, definition, 61104003, true)
	LiveSessionScript.advance(machine, 0, false)
	for frame in range(1, WARMUP_FRAMES + 1):
		LiveSessionScript.advance(machine, _clock_msec(frame), false)
	if SolverScript.last_step_backend_for_test() != "native_v3":
		_publish({"ok": false, "failures": ["Native solver unavailable; refusing a different backend measurement."]})
		return
	var authority_tick_before := int(simulation.get("tick", 0))
	var baseline_memory_bytes := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var samples: Array = [_sample(0, session, baseline_memory_bytes)]
	var maximum_backlog_ticks := 0
	for event_index in range(1, int(CHECKPOINTS.back()) + 1):
		# Scalar positioning mirrors production carriage acceptance; each event
		# still enters the real trace and is consumed by real native advancement.
		var requested_x := 8000 + (event_index % 600) * 140
		var accepted_x := SolverScript.set_carriage(simulation, requested_x)
		LiveSessionScript.queue_input(machine, {"kind": "carriage", "x": accepted_x})
		LiveSessionScript.advance(machine, _clock_msec(WARMUP_FRAMES + event_index), false)
		maximum_backlog_ticks = maxi(maximum_backlog_ticks, int(session.get("accumulator_units", 0)) / 1000)
		if CHECKPOINTS.has(event_index):
			var sample: Dictionary = _sample(event_index, session, baseline_memory_bytes)
			sample["authority_ticks_since_baseline"] = int(simulation.get("tick", 0)) - authority_tick_before
			sample["elapsed_wall_usec"] = Time.get_ticks_usec() - started_usec
			samples.append(sample)
			if int(sample["pending_input_count"]) != 0:
				failures.append("Checkpoint %d retained unconsumed input; cannot attribute all retained entries to history." % event_index)
			if int(sample["authority_ticks_since_baseline"]) != event_index:
				failures.append("Checkpoint %d did not advance the exact synthetic authority time." % event_index)
	var invariants: Dictionary = simulation.get("last_invariants", {})
	if not bool(invariants.get("conservation_ok", false)) or int(invariants.get("active", -1)) != 0:
		failures.append("Empty-cabinet conservation changed during retention probe.")
	var memory_before_release := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	# Diagnostic cleanup of this disposable fixture only. No further stepping
	# follows: isolate how much memory releases with the consumed trace graph.
	# Keep the old Array lookup in a returned helper frame, so the VM cannot
	# retain its temporary reference until this measurement function returns.
	var retained_before_release := _release_trace(session)
	var memory_after_release := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	_publish({
		"ok": failures.is_empty(), "failures": failures,
		"fidelity": "synthetic 60Hz carriage inputs through real queue_input/advance; zero-body native cabinet; retained-state attribution only",
		"platform": OS.get_name(), "web_feature": OS.has_feature("web"), "solver_backend": SolverScript.last_step_backend_for_test(),
		"warmup_frames": WARMUP_FRAMES, "body_count": 0, "events": int(CHECKPOINTS.back()),
		"synthetic_duration_msec": _clock_msec(int(CHECKPOINTS.back())),
		"baseline_static_memory_bytes": baseline_memory_bytes, "samples": samples,
		"max_backlog_ticks": maximum_backlog_ticks, "invariants": invariants,
		"diagnostic_release": {"consumed_entries_before": retained_before_release, "static_memory_before_bytes": memory_before_release,
			"static_memory_after_bytes": memory_after_release, "released_bytes": memory_before_release - memory_after_release,
			"growth_remaining_bytes": memory_after_release - baseline_memory_bytes},
		"elapsed_wall_usec": Time.get_ticks_usec() - started_usec,
	})


func _sample(events: int, session: Dictionary, baseline_memory_bytes: int) -> Dictionary:
	var retained := (session.get("input_trace", []) as Array).size()
	var cursor := int(session.get("input_cursor", 0))
	var memory_bytes := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	return {"events_queued": events, "retained_input_count": retained, "input_cursor": cursor,
		"total_input_count": int(session.get("input_count", retained)),
		"pending_input_count": retained - cursor, "static_memory_bytes": memory_bytes,
		"static_memory_growth_bytes": memory_bytes - baseline_memory_bytes}


func _release_trace(session: Dictionary) -> int:
	var trace: Array = session.get("input_trace", [])
	var retained := trace.size()
	session["input_trace"] = []
	session["input_cursor"] = 0
	return retained


func _clock_msec(frame: int) -> int:
	return int(round(float(frame) * 1000.0 / 60.0))


func _publish(report: Dictionary) -> void:
	var payload := JSON.stringify(report)
	print(RESULT_MARKER + payload)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.BTHCoinPusherInputRetention = JSON.parse(%s); document.title = 'BTH_COIN_PUSHER_INPUT_RETENTION_DONE';" % JSON.stringify(payload), true)
	else:
		get_tree().quit(0 if bool(report.get("ok", false)) else 1)
