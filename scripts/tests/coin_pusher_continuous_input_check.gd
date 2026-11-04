extends Node

# Deterministic scheduling regression, run through the supported .tscn entry.
# Uses production module pointer and realtime APIs with disposable state. The
# clock is synthetic; call timings are diagnostics, not rendered FPS evidence.
# Export this scene with the qualified Web template to exercise the actual Web
# branch. A native pass cannot certify Web publication behavior.
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const CoinPusherGameScript := preload("res://scripts/games/coin_pusher.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const GameModuleScript := preload("res://scripts/core/game_module.gd")
const SolverScript := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")
const RESULT_MARKER := "COIN_PUSHER_CONTINUOUS_INPUT_RESULT="
const DRAG_ACTION := "coin_pusher_carriage_drag"
const PHASES := [
	{"id": "idle", "frames": 120, "drag": false, "drops": 0},
	{"id": "feeding", "frames": 120, "drag": false, "drops": 12},
	{"id": "continuous_drag_feeding", "frames": 180, "drag": true, "drops": 12},
	{"id": "released", "frames": 60, "drag": false, "drops": 0},
]


func _ready() -> void:
	call_deferred("_run_check")


func _run_check() -> void:
	var library := ContentLibraryScript.new()
	library.load(false)
	var definition: Dictionary = library.game("coin_pusher")
	var failures: Array[String] = []
	if definition.is_empty():
		_publish({"ok": false, "failures": ["Coin Pusher definition missing."]})
		return
	var game := CoinPusherGameScript.new()
	game.setup(definition, library)
	var run_state := RunStateScript.new()
	run_state.start_new("PERF-AUDIT-CONTINUOUS-PUSHER")
	run_state.bankroll = 500
	var environment: Dictionary = {
		"id": "performance_pusher_synthetic", "world_node_id": "performance_pusher_synthetic",
		"scenario_game_modifiers": {"coin_pusher": {"variation_id": "quarter_falls"}},
		"game_states": {},
	}
	run_state.current_environment = environment
	environment["game_states"] = {"coin_pusher": game.generate_environment_state(run_state, environment, run_state.create_rng("pusher-generation"))}
	game.enter(run_state, environment)
	var machines: Dictionary = game.get("_live_machines")
	if machines.size() != 1:
		_publish({"ok": false, "failures": ["Expected one disposable live machine."]})
		return
	var machine: Dictionary = machines.values()[0]
	var session: Dictionary = machine.get("live_session", {})
	var simulation: Dictionary = machine.get("simulation", {})
	var ui_state: Dictionary = {"surface_time_msec": 0}
	var surface: Dictionary = game.surface_state(run_state, environment, ui_state)
	var renderer: RefCounted = game.call("_coin_pusher_renderer")
	var hardware_layout: Dictionary = renderer.call("debug_entry_hardware_layout_for_test", surface)
	var drag_rect: Rect2 = hardware_layout.get("drag_rect", Rect2())
	if not drag_rect.has_area():
		_publish({"ok": false, "failures": ["Production rail drag rectangle missing."]})
		return
	var drag_point := Vector2(drag_rect.position.x + drag_rect.size.x * 0.1, drag_rect.get_center().y)
	_merge(surface, game.surface_realtime_state_patch(run_state, environment, ui_state, surface))
	var reports: Array = []
	var frame := 0
	var last_publication_msec := 0
	var expected_drop_count := 0
	var initial_turns := int(environment.get("turns", 0))
	for phase_value in PHASES:
		var phase: Dictionary = phase_value
		var drag := bool(phase["drag"])
		var drops := int(phase["drops"])
		if drops > 0:
			var result: Dictionary = game.resolve("drop_quarter", drops, run_state, environment, run_state.create_rng("drop-%s" % phase["id"]))
			var applied: Dictionary = GameModuleScript.apply_result(run_state, result)
			if not bool(applied.get("ok", false)):
				failures.append("Drop result failed in %s: %s" % [phase["id"], JSON.stringify(applied)])
			expected_drop_count += drops
		if drag:
			var begin: Dictionary = game.surface_pointer_command(DRAG_ACTION, 0, "begin", drag_point, ui_state, run_state, environment)
			ui_state = begin.get("ui_state", ui_state)
			_merge(surface, begin.get("surface_state_patch", {}))
		var tick_before := int(simulation.get("tick", 0))
		var publications := 0
		var nozzle_updates := 0
		var max_publication_age_msec := 0
		var max_backlog_ticks := 0
		var pointer_usec: Array = []
		var realtime_usec: Array = []
		var native_usec: Array = []
		for phase_frame in range(int(phase["frames"])):
			frame += 1
			var now_msec := int(round(float(frame) * 1000.0 / 60.0))
			if drag:
				var pointer_started := Time.get_ticks_usec()
				# Use the rendered production rail geometry, keeping the sweep inside
				# its endpoints so clamping never creates stationary edge frames.
				var normalized_x := 0.1 + float((phase_frame + 1) % 60) * 0.8 / 59.0
				drag_point.x = drag_rect.position.x + drag_rect.size.x * normalized_x
				var command: Dictionary = game.surface_pointer_command(DRAG_ACTION, 0, "move", drag_point, ui_state, run_state, environment)
				ui_state = command.get("ui_state", ui_state)
				var pointer_patch: Dictionary = command.get("surface_state_patch", {})
				if int(pointer_patch.get("coin_pusher_carriage_x", -1)) != int(surface.get("coin_pusher_carriage_x", -1)):
					nozzle_updates += 1
				_merge(surface, pointer_patch)
				pointer_usec.append(Time.get_ticks_usec() - pointer_started)
			ui_state["surface_time_msec"] = now_msec
			var serial_before := int(session.get("presentation_view_serial", 0))
			var realtime_started := Time.get_ticks_usec()
			var patch: Dictionary = game.surface_realtime_state_patch(run_state, environment, ui_state, surface)
			realtime_usec.append(Time.get_ticks_usec() - realtime_started)
			_merge(surface, patch)
			if int(session.get("presentation_view_serial", 0)) > serial_before:
				publications += 1
				last_publication_msec = now_msec
			max_publication_age_msec = maxi(max_publication_age_msec, now_msec - last_publication_msec)
			max_backlog_ticks = maxi(max_backlog_ticks, int(session.get("accumulator_units", 0)) / 1000)
			var metrics: Dictionary = session.get("last_step_metrics", {})
			native_usec.append(int(metrics.get("elapsed_usec", 0)))
		if drag:
			var ending: Dictionary = game.surface_pointer_command(DRAG_ACTION, 0, "end", drag_point, ui_state, run_state, environment)
			ui_state = ending.get("ui_state", ui_state)
			_merge(surface, ending.get("surface_state_patch", {}))
		var authority_ticks := int(simulation.get("tick", 0)) - tick_before
		var invariants: Dictionary = simulation.get("last_invariants", {})
		var row: Dictionary = {
			"phase": str(phase["id"]), "frames": int(phase["frames"]),
			"authority_ticks": authority_ticks, "published_frames": publications,
			"nozzle_updates": nozzle_updates, "max_publication_age_msec": max_publication_age_msec,
			"max_backlog_ticks": max_backlog_ticks, "input_trace_count": (session.get("input_trace", []) as Array).size(),
			"pointer_call_usec": _stats(pointer_usec), "module_realtime_call_usec": _stats(realtime_usec),
			"native_step_usec": _stats(native_usec), "invariants": invariants.duplicate(true),
		}
		reports.append(row)
		if authority_ticks < int(phase["frames"]) - 1:
			failures.append("Authority lost synthetic time during %s." % phase["id"])
		# A generous 15 Hz floor accepts the bounded 30 Hz Web publisher, while
		# rejecting a publisher indefinitely postponed by sustained input.
		if publications < int(phase["frames"]) / 4 or max_publication_age_msec > 100:
			failures.append("Coin body presentation starved during %s: %d publications, maximum age %d ms." % [phase["id"], publications, max_publication_age_msec])
		if drag and nozzle_updates < int(phase["frames"]) - 2:
			failures.append("Continuous rail input did not move the nozzle throughout its sample.")
		if not bool(invariants.get("conservation_ok", false)):
			failures.append("Coin conservation failed during %s." % phase["id"])
	# This Quarter Falls fixture has no feature bonus drops. Native authority
	# counters account for every emitted attempt even after trace compaction.
	var emitted_drops := int(simulation.get("accepted_inserts", 0)) + int(simulation.get("refused_inserts", 0))
	var pending_drops := 0
	for queued_value in machine.get("drop_queue", []):
		var queued: Dictionary = queued_value
		if not bool(queued.get("bonus_origin", false)):
			pending_drops += int(queued.get("remaining", 0))
	if emitted_drops + pending_drops != expected_drop_count or run_state.bankroll != 500 - expected_drop_count or int(environment.get("turns", 0)) != initial_turns:
		failures.append("Drop queue, cash, or free carriage turn accounting changed.")
	_publish({
		"ok": failures.is_empty(), "failures": failures, "platform": OS.get_name(), "web_feature": OS.has_feature("web"),
		"fidelity": "synthetic 60Hz clock through production module APIs; no rendered frame or full-host performance claim",
		"solver_backend": SolverScript.last_step_backend_for_test(), "phases": reports,
		"reserved_drops": expected_drop_count, "emitted_drops": emitted_drops, "pending_drops": pending_drops,
		"bankroll": run_state.bankroll, "turns_before": initial_turns, "turns_after": int(environment.get("turns", 0)),
	})


func _merge(target: Dictionary, patch: Dictionary) -> void:
	for key in patch:
		target[key] = patch[key]


func _stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {"count": 0}
	values.sort()
	var total := 0
	for value in values:
		total += int(value)
	return {"count": values.size(), "mean": float(total) / values.size(), "p95": int(values[mini(values.size() - 1, ceili(float(values.size()) * 0.95) - 1)]), "max": int(values.back())}


func _publish(report: Dictionary) -> void:
	var payload := JSON.stringify(report)
	print(RESULT_MARKER + payload)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.BTHCoinPusherContinuousInput = JSON.parse(%s); document.title = 'BTH_COIN_PUSHER_CONTINUOUS_INPUT_DONE';" % JSON.stringify(payload), true)
	else:
		get_tree().quit(0 if bool(report.get("ok", false)) else 1)
