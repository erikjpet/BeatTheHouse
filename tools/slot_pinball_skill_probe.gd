extends SceneTree

const BoardsScript := preload("res://scripts/games/slots/pinball/pinball_boards.gd")
const BoardScript := preload("res://scripts/games/slots/pinball/pinball_board.gd")
const SimScript := preload("res://scripts/games/slots/pinball/pinball_sim.gd")
const FeatureScript := preload("res://scripts/games/slots/pinball/pinball_feature.gd")

const DEFAULT_SEEDS := 1000
const MIN_EDGE_PCT := 15.0
const MAX_EDGE_PCT := 25.0


func _init() -> void:
	var seed_count := DEFAULT_SEEDS
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		seed_count = maxi(100, int(args[0]))
	var failures: Array = []
	var compiler := BoardScript.new()
	var board: Dictionary = compiler.compile(BoardsScript.by_id("bumper_alley"))
	_run_launch_meter_audit(failures)
	_run_policy_edge_probe(board, seed_count, failures)
	_run_control_probe(board, failures)
	if failures.is_empty():
		print("PINBALL_SKILL_OVERALL status=PASS failures=0")
		quit(0)
		return
	print("PINBALL_SKILL_OVERALL status=FAIL failures=%d details=%s" % [failures.size(), JSON.stringify(failures)])
	quit(1)


func _run_launch_meter_audit(failures: Array) -> void:
	var active := {
		"mode": "em_bumper_drop",
		"launch_power": 70,
		"launch_meter_offset_msec": 0,
		"skill_power_target": 82,
		"skill_power_width": 3,
		"launch_angle_degrees": 0,
		"balls_remaining": 3,
		"step_index": 0,
	}
	var sweet_time := _time_for_power(active, 82)
	var wild_time := _time_for_power(active, 22)
	var sweet: Dictionary = FeatureScript.launch_meter_snapshot(active, sweet_time, true)
	var wild: Dictionary = FeatureScript.launch_meter_snapshot(active, wild_time, true)
	var later: Dictionary = FeatureScript.launch_meter_snapshot(active, sweet_time + 220, true)
	if str(sweet.get("rating", "")) != "sweet" or int(sweet.get("power", 0)) < 79 or int(sweet.get("power", 0)) > 85:
		failures.append("timed launch meter did not sample a sweet shot at the solved time")
	if str(wild.get("rating", "")) != "wild":
		failures.append("timed launch meter did not expose wild timing away from the sweet spot")
	if int(later.get("power", 0)) == int(sweet.get("power", 0)):
		failures.append("timed launch meter did not change sampled power over time")
	print("PINBALL_SKILL_LAUNCH sweet_time=%d sweet_power=%d sweet_rating=%s wild_time=%d wild_power=%d wild_rating=%s later_power=%d" % [
		sweet_time,
		int(sweet.get("power", 0)),
		str(sweet.get("rating", "")),
		wild_time,
		int(wild.get("power", 0)),
		str(wild.get("rating", "")),
		int(later.get("power", 0)),
	])


func _run_policy_edge_probe(board: Dictionary, seed_count: int, failures: Array) -> void:
	var random_total := 0
	var perfect_total := 0
	var cap_ok := true
	for seed_index in range(seed_count):
		var random_result: Dictionary = _policy_result(board, seed_index, false)
		var perfect_result: Dictionary = _policy_result(board, seed_index, true)
		random_total += int(random_result.get("award", 0))
		perfect_total += int(perfect_result.get("award", 0))
		if int(random_result.get("award", 0)) > int(random_result.get("cap", 0)) or int(perfect_result.get("award", 0)) > int(perfect_result.get("cap", 0)):
			cap_ok = false
	var random_avg := float(random_total) / float(maxi(1, seed_count))
	var perfect_avg := float(perfect_total) / float(maxi(1, seed_count))
	var edge_pct := ((perfect_avg - random_avg) / maxf(1.0, random_avg)) * 100.0
	if edge_pct < MIN_EDGE_PCT or edge_pct > MAX_EDGE_PCT:
		failures.append("perfect policy edge %.2f%% outside %.2f-%.2f%%" % [edge_pct, MIN_EDGE_PCT, MAX_EDGE_PCT])
	if not cap_ok:
		failures.append("skill policy probe exceeded session cap")
	print("PINBALL_SKILL_POLICY seeds=%d random_avg=%.3f perfect_avg=%.3f edge_pct=%.2f cap_ok=%s" % [
		seed_count,
		random_avg,
		perfect_avg,
		edge_pct,
		str(cap_ok),
	])


func _run_control_probe(board: Dictionary, failures: Array) -> void:
	var nudge_sim := SimScript.new()
	nudge_sim.configure(board, 99107, {"cap": 500})
	nudge_sim.launch_ball({"power": 0.70, "aim": 0.0})
	var before_nudge_events := int(nudge_sim.event_total_count)
	nudge_sim.set_controls(0.70, 0.0, false, false)
	nudge_sim.step_tick()
	var nudge_seen := _events_have_type(nudge_sim.event_log_since(before_nudge_events), "nudge")
	for _index in range(4):
		nudge_sim.set_controls(1.0, 1.0, true, true)
		nudge_sim.step_tick()
	var tilt_ok := bool(nudge_sim.compact_snapshot().get("tilted", false)) and nudge_sim.active_ball_count() == 0

	var flipper_sim := SimScript.new()
	flipper_sim.configure(board, 22109, {"cap": 500})
	var ball_index := flipper_sim.launch_ball({"power": 0.48, "aim": 0.0, "position": Vector2(0.16, 0.790)})
	flipper_sim.positions[ball_index] = Vector2(0.16, 0.805)
	flipper_sim.velocities[ball_index] = Vector2(0.04, 1.25)
	flipper_sim.step_tick()
	var before_flipper_events := int(flipper_sim.event_total_count)
	flipper_sim.set_controls(0.0, 0.0, true, false)
	flipper_sim.step_tick()
	var flipper_seen := _events_have_type(flipper_sim.event_log_since(before_flipper_events), "flipper")
	var flipper_snapshot: Dictionary = flipper_sim.compact_snapshot()
	var flipper_ok := flipper_seen and int(flipper_snapshot.get("flipper_window_count", 0)) > 0 and int(flipper_snapshot.get("flipper_rescue_count", 0)) > 0 and flipper_sim.active_ball_count() > 0

	if not nudge_seen or float(nudge_sim.compact_snapshot().get("tilt_meter", 0.0)) <= 0.0:
		failures.append("nudge did not produce event and tilt-meter movement")
	if not tilt_ok:
		failures.append("over-nudge did not tilt and drain the ball")
	if not flipper_ok:
		failures.append("timed flipper rescue window did not relaunch an outlane approach")
	print("PINBALL_SKILL_CONTROLS nudge_seen=%s nudge_count=%d tilt_ok=%s flipper_seen=%s flipper_windows=%d flipper_rescues=%d active_after_rescue=%d" % [
		str(nudge_seen),
		int(nudge_sim.compact_snapshot().get("nudge_count", 0)),
		str(tilt_ok),
		str(flipper_seen),
		int(flipper_snapshot.get("flipper_window_count", 0)),
		int(flipper_snapshot.get("flipper_rescue_count", 0)),
		flipper_sim.active_ball_count(),
	])


func _policy_result(board: Dictionary, seed_index: int, perfect: bool) -> Dictionary:
	var sim := SimScript.new()
	var cap := 500
	if perfect:
		sim.run_headless(41000 + seed_index, board, _perfect_script(seed_index), {
			"cap": cap,
			"launch": {
				"power": float(board.get("skill_power", 0.82)),
				"aim": 0.0,
				"position": Vector2(0.50, 0.075),
			},
			"max_ticks": int(board.get("max_ticks", 960)),
		})
	else:
		sim.run_headless(41000 + seed_index, board, _random_script(seed_index), {
			"cap": cap,
			"launch": _random_launch(seed_index),
			"max_ticks": int(board.get("max_ticks", 960)),
		})
	return sim.result_signature()


func _perfect_script(seed_index: int) -> Array:
	return [
		{"tick": 74 + (seed_index % 5), "nudge_x": -0.28, "nudge_y": 0.0},
		{"tick": 148 + (seed_index % 7), "nudge_x": 0.32, "nudge_y": 0.0},
		{"tick": 258 + (seed_index % 5), "flipper_left": true},
		{"tick": 276 + (seed_index % 7), "flipper_right": true},
	]


func _random_script(seed_index: int) -> Array:
	var first_tick := 55 + _hash_int(seed_index, 3, 160)
	var second_tick := 150 + _hash_int(seed_index, 4, 180)
	return [
		{"tick": first_tick, "nudge_x": -0.50 + float(_hash_int(seed_index, 5, 101)) / 100.0, "nudge_y": 0.0},
		{"tick": second_tick, "nudge_x": -0.50 + float(_hash_int(seed_index, 6, 101)) / 100.0, "nudge_y": 0.0},
		{"tick": 235 + _hash_int(seed_index, 7, 140), "flipper_left": _hash_int(seed_index, 8, 2) == 0},
		{"tick": 245 + _hash_int(seed_index, 9, 150), "flipper_right": _hash_int(seed_index, 10, 2) == 0},
	]


func _random_launch(seed_index: int) -> Dictionary:
	return {
		"power": 0.20 + float(_hash_int(seed_index, 1, 81)) / 100.0,
		"aim": -0.90 + float(_hash_int(seed_index, 2, 181)) / 100.0,
		"position": Vector2(0.16 + float(_hash_int(seed_index, 11, 69)) / 100.0, 0.075),
	}


func _time_for_power(active: Dictionary, target_power: int) -> int:
	var best_time := 0
	var best_error := 999
	for time_msec in range(0, 1100):
		var sample: Dictionary = FeatureScript.launch_meter_snapshot(active, time_msec, true)
		var error := absi(int(sample.get("power", 0)) - target_power)
		if error < best_error:
			best_error = error
			best_time = time_msec
	return best_time


func _events_have_type(events: Array, event_type: String) -> bool:
	for event_value in events:
		var event: Dictionary = event_value if typeof(event_value) == TYPE_DICTIONARY else {}
		if str(event.get("element_type", "")) == event_type:
			return true
	return false


func _hash_int(seed_index: int, salt: int, modulo: int) -> int:
	var value := int(abs(seed_index * 1103515245 + salt * 12345 + 67890))
	return posmod(value, maxi(1, modulo))
