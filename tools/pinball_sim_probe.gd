extends SceneTree

const BoardsScript := preload("res://scripts/games/slots/pinball/pinball_boards.gd")
const BoardScript := preload("res://scripts/games/slots/pinball/pinball_board.gd")
const SimScript := preload("res://scripts/games/slots/pinball/pinball_sim.gd")

const DEFAULT_SEEDS := 100
const MAX_AVG_TICK_USEC := 150.0


func _init() -> void:
	var seed_count := DEFAULT_SEEDS
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		seed_count = maxi(10, int(args[0]))
	var failures: Array = []
	var compiler := BoardScript.new()
	var board: Dictionary = compiler.compile(BoardsScript.bumper_alley())
	_run_determinism_probe(board, seed_count, failures)
	_run_drain_probe(board, seed_count, failures)
	_run_perf_probe(board, failures)
	if failures.is_empty():
		print("PINBALL_SIM_PROBE_OVERALL status=PASS failures=0")
		quit(0)
		return
	print("PINBALL_SIM_PROBE_OVERALL status=FAIL failures=%d details=%s" % [failures.size(), JSON.stringify(failures)])
	quit(1)


func _run_determinism_probe(board: Dictionary, seed_count: int, failures: Array) -> void:
	for seed_index in range(seed_count):
		var input_script := _script_for_seed(seed_index)
		var first_runner := SimScript.new()
		var second_runner := SimScript.new()
		var first: Dictionary = first_runner.run_headless(9000 + seed_index, board, input_script, {"cap": 500, "launch": _launch_for_seed(seed_index), "max_ticks": 960})
		var second: Dictionary = second_runner.run_headless(9000 + seed_index, board, input_script, {"cap": 500, "launch": _launch_for_seed(seed_index), "max_ticks": 960})
		if JSON.stringify(_deterministic_signature(first)) != JSON.stringify(_deterministic_signature(second)):
			failures.append("determinism mismatch seed=%d first=%s second=%s" % [seed_index, JSON.stringify(first), JSON.stringify(second)])
			break
	print("PINBALL_SIM_DETERMINISM seeds=%d status=%s" % [seed_count, "PASS" if failures.is_empty() else "CHECK"])


func _run_drain_probe(board: Dictionary, seed_count: int, failures: Array) -> void:
	var drained := 0
	var total_ticks := 0
	var total_events := 0
	var total_award := 0
	var event_types := {}
	var max_events_per_tick := 0
	for seed_index in range(seed_count):
		var runner := SimScript.new()
		var result: Dictionary = runner.run_headless(12000 + seed_index, board, _script_for_seed(seed_index), {"cap": 500, "launch": _launch_for_seed(seed_index), "max_ticks": 960})
		total_ticks += int(result.get("ticks", 0))
		total_events += int(result.get("events", 0))
		total_award += int(result.get("award", 0))
		max_events_per_tick = maxi(max_events_per_tick, int(result.get("max_events_per_tick", 0)))
		if int(result.get("active", 0)) == 0:
			drained += 1
		var counts: Dictionary = result.get("event_type_counts", {}) if typeof(result.get("event_type_counts", {})) == TYPE_DICTIONARY else {}
		for key_value in counts.keys():
			event_types[str(key_value)] = true
		if int(result.get("award", 0)) > int(result.get("cap", 0)):
			failures.append("seed %d exceeded cap: %s" % [seed_index, JSON.stringify(result)])
		if bool(result.get("tilted", false)):
			failures.append("seed %d tilted during baseline drain probe" % seed_index)
	var avg_ticks := float(total_ticks) / float(maxi(1, seed_count))
	var avg_events := float(total_events) / float(maxi(1, seed_count))
	var avg_award := float(total_award) / float(maxi(1, seed_count))
	if drained != seed_count:
		failures.append("drain sanity expected all runs drained, got %d/%d" % [drained, seed_count])
	if avg_ticks < 120.0 or avg_ticks > 960.0:
		failures.append("average ticks %.2f outside Ballionaire-style Phase 1 sanity range" % avg_ticks)
	for required_type in [str(SimScript.EVENT_PEG), str(SimScript.EVENT_BUMPER), str(SimScript.EVENT_POCKET), str(SimScript.EVENT_LAUNCHER)]:
		if not bool(event_types.get(required_type, false)):
			failures.append("drain probe did not exercise event type %s" % required_type)
	print("PINBALL_SIM_DRAIN board=%s seeds=%d drained=%d avg_ticks=%.2f avg_events=%.2f avg_award=%.2f max_events_tick=%d event_types=%s" % [
		str(board.get("id", "")),
		seed_count,
		drained,
		avg_ticks,
		avg_events,
		avg_award,
		max_events_per_tick,
		JSON.stringify(event_types.keys()),
	])


func _run_perf_probe(board: Dictionary, failures: Array) -> void:
	var sim := SimScript.new()
	sim.configure(board, 424242, {"cap": 10000})
	for index in range(4):
		sim.launch_ball({"power": 0.58 + float(index) * 0.07, "aim": -0.35 + float(index) * 0.23})
	var before_objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var before_usec := Time.get_ticks_usec()
	var ticks := 2400
	for tick_index in range(ticks):
		if sim.active_ball_count() < 4:
			sim.launch_ball({"power": 0.74, "aim": float((tick_index % 5) - 2) * 0.14})
		if tick_index % 53 == 0:
			sim.set_controls(0.35 if tick_index % 2 == 0 else -0.35, 0.0, false, false)
		sim.step_tick()
	var elapsed_usec := Time.get_ticks_usec() - before_usec
	var after_objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var avg_tick := float(elapsed_usec) / float(maxi(1, ticks))
	var object_delta := after_objects - before_objects
	if avg_tick > MAX_AVG_TICK_USEC:
		failures.append("perf avg %.3fus exceeded %.3fus" % [avg_tick, MAX_AVG_TICK_USEC])
	if object_delta != 0:
		failures.append("hot tick object delta expected 0, got %d" % object_delta)
	print("PINBALL_SIM_PERF ticks=%d avg_tick_us=%.3f sim_reported_avg_us=%.3f max_tick_us=%d object_delta=%d max_active=%d status=%s" % [
		ticks,
		avg_tick,
		float(sim.result_signature().get("avg_tick_usec", 0.0)),
		int(sim.result_signature().get("max_tick_usec", 0)),
		object_delta,
		int(sim.result_signature().get("max_active", 0)),
		"PASS" if avg_tick <= MAX_AVG_TICK_USEC and object_delta == 0 else "CHECK",
	])


func _script_for_seed(seed_index: int) -> Array:
	return [
		{"tick": 80 + (seed_index % 12), "nudge_x": -0.42, "nudge_y": 0.0},
		{"tick": 170 + (seed_index % 18), "nudge_x": 0.36, "nudge_y": 0.0},
		{"tick": 275 + (seed_index % 9), "flipper_left": true},
		{"tick": 292 + (seed_index % 11), "flipper_right": true},
	]


func _launch_for_seed(seed_index: int) -> Dictionary:
	return {
		"power": 0.56 + float(seed_index % 7) * 0.055,
		"aim": -0.42 + float(seed_index % 11) * 0.084,
	}


func _deterministic_signature(result: Dictionary) -> Dictionary:
	var copy := result.duplicate(true)
	copy.erase("avg_tick_usec")
	copy.erase("max_tick_usec")
	return copy
