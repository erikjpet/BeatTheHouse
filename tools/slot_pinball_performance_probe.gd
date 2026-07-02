extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const GeneratorScript := preload("res://scripts/games/slots/slot_machine_generator.gd")
const StateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const PinballScript := preload("res://scripts/games/slots/slot_family_pinball.gd")
const PresentationScript := preload("res://scripts/games/slots/slot_presentation.gd")
const RendererScript := preload("res://scripts/games/slots/slot_renderer.gd")
const BoardsScript := preload("res://scripts/games/slots/pinball/pinball_boards.gd")
const BoardScript := preload("res://scripts/games/slots/pinball/pinball_board.gd")
const SimScript := preload("res://scripts/games/slots/pinball/pinball_sim.gd")

const DEFAULT_FRAMES := 240
const MAX_AVG_SURFACE_USEC := 300.0
const MAX_AVG_TOTAL_USEC := 8000.0
const MAX_AVG_SIM_TICK_USEC := 150.0
const MIN_PHASE0_TOTAL_REDUCTION := 10.0

const FEATURE_SCENARIOS := [
	{"format": "classic_3_reel", "mode": "em_bumper_drop", "phase0_total_us": 1719.546, "inputs": ["slot_bonus_launch"]},
	{"format": "line_5x3", "mode": "lane_multiball", "phase0_total_us": 2264.838, "inputs": ["slot_bonus_left", "slot_bonus_launch"]},
	{"format": "video_feature", "mode": "video_feature", "phase0_total_us": 2497.442, "inputs": ["slot_bonus_right", "slot_bonus_launch"]},
]

var _sim_tick_avg_usec := 0.0


class FakeSurface:
	extends RefCounted

	var elapsed := {}
	var draw_calls := 0
	var label_calls := 0
	var hit_calls := 0

	func reset(time_msec: int) -> void:
		var seconds := float(time_msec) / 1000.0
		elapsed = {"slot_spin": seconds, "slot_feature": seconds, "slot_nudge_chain": seconds}
		draw_calls = 0
		label_calls = 0
		hit_calls = 0

	func surface_begin_design_space_inset(_size: Vector2, _offset: Vector2) -> void:
		pass

	func surface_elapsed(channel_id: String) -> float:
		return float(elapsed.get(channel_id, 0.0))

	func surface_region_hovered(_action: String, _index: int = 0) -> bool:
		return false

	func surface_add_hit(_rect: Rect2, _action: String, _index: int = 0) -> void:
		hit_calls += 1

	func surface_label(_text: String, _pos: Vector2, _font_size: int, _color: Color) -> void:
		label_calls += 1

	func surface_label_centered(_text: String, _rect: Rect2, _font_size: int, _color: Color) -> void:
		label_calls += 1

	func draw_rect(_rect: Rect2, _color: Color, _filled: bool = true, _width: float = -1.0, _antialiased: bool = false) -> void:
		draw_calls += 1

	func draw_texture_rect(_texture: Texture2D, _rect: Rect2, _tile: bool, _modulate: Color = Color(1, 1, 1, 1), _transpose: bool = false) -> void:
		draw_calls += 1

	func draw_circle(_position: Vector2, _radius: float, _color: Color, _filled: bool = true, _width: float = -1.0, _antialiased: bool = false) -> void:
		draw_calls += 1

	func draw_line(_from: Vector2, _to: Vector2, _color: Color, _width: float = -1.0, _antialiased: bool = false) -> void:
		draw_calls += 1

	func draw_polygon(_points: Array, _colors: Array, _uvs: Array = [], _texture: Texture2D = null) -> void:
		draw_calls += 1


func _init() -> void:
	var frames := DEFAULT_FRAMES
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		frames = maxi(30, int(args[0]))
	var failures: Array = []
	_run_sim_tick_perf(failures)
	_run_visual_perf(frames, failures)
	if failures.is_empty():
		print("PINBALL_PERF_OVERALL status=PASS failures=0")
		quit(0)
		return
	print("PINBALL_PERF_OVERALL status=FAIL failures=%d details=%s" % [failures.size(), JSON.stringify(failures)])
	quit(1)


func _run_visual_perf(frames: int, failures: Array) -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	var definition: Dictionary = library.game("slot")
	var generator = GeneratorScript.new()
	var pinball = PinballScript.new()
	var presentation = PresentationScript.new()
	var renderer = RendererScript.new()
	var fake_surface := FakeSurface.new()
	for scenario_value in FEATURE_SCENARIOS:
		var scenario: Dictionary = scenario_value
		var sample: Dictionary = _active_feature_sample(definition, generator, pinball, scenario)
		var machine: Dictionary = _dict(sample.get("machine", {}))
		var run_state: RunState = sample.get("run_state", null)
		var surface_usec := 0
		var signature_usec := 0
		var draw_usec := 0
		var max_draw_calls := 0
		var max_label_calls := 0
		var max_hit_calls := 0
		for frame in range(frames):
			var time_msec := 1000 + frame * 16
			var before_surface := Time.get_ticks_usec()
			var surface_state: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": time_msec})
			surface_usec += Time.get_ticks_usec() - before_surface
			var before_signature := Time.get_ticks_usec()
			var manifest: Dictionary = renderer.render_signature(surface_state, definition, time_msec, "feature")
			signature_usec += Time.get_ticks_usec() - before_signature
			if int(manifest.get("pinball_peg_count", 0)) <= 0:
				failures.append("%s visual manifest lost pinball geometry" % str(scenario.get("mode", "")))
				break
			fake_surface.reset(time_msec)
			var before_draw := Time.get_ticks_usec()
			renderer.draw(fake_surface, surface_state, definition)
			draw_usec += Time.get_ticks_usec() - before_draw
			max_draw_calls = maxi(max_draw_calls, fake_surface.draw_calls)
			max_label_calls = maxi(max_label_calls, fake_surface.label_calls)
			max_hit_calls = maxi(max_hit_calls, fake_surface.hit_calls)
		var avg_surface := float(surface_usec) / float(maxi(1, frames))
		var avg_signature := float(signature_usec) / float(maxi(1, frames))
		var avg_draw := float(draw_usec) / float(maxi(1, frames))
		var avg_total := avg_surface + avg_signature + avg_draw
		var avg_feature_overhead := maxf(1.0, avg_surface - _sim_tick_avg_usec * 2.0)
		var reduction := float(scenario.get("phase0_total_us", 1.0)) / avg_feature_overhead
		if avg_surface > MAX_AVG_SURFACE_USEC:
			failures.append("%s surface_state avg %.3fus exceeded %.3fus" % [str(scenario.get("mode", "")), avg_surface, MAX_AVG_SURFACE_USEC])
		if reduction < MIN_PHASE0_TOTAL_REDUCTION:
			failures.append("%s live feature overhead reduction %.2fx below %.2fx vs Phase 0 total frame cost" % [str(scenario.get("mode", "")), reduction, MIN_PHASE0_TOTAL_REDUCTION])
		if avg_total > MAX_AVG_TOTAL_USEC:
			failures.append("%s visual avg %.3fus exceeded %.3fus" % [str(scenario.get("mode", "")), avg_total, MAX_AVG_TOTAL_USEC])
		print("PINBALL_PERF_LIVE mode=%s frames=%d avg_surface_us=%.3f avg_feature_overhead_us=%.3f avg_signature_us=%.3f avg_draw_us=%.3f avg_total_us=%.3f phase0_total_us=%.3f reduction_vs_phase0_total=%.2fx max_draw_calls=%d max_label_calls=%d max_hit_calls=%d" % [
			str(scenario.get("mode", "")),
			frames,
			avg_surface,
			avg_feature_overhead,
			avg_signature,
			avg_draw,
			avg_total,
			float(scenario.get("phase0_total_us", 0.0)),
			reduction,
			max_draw_calls,
			max_label_calls,
			max_hit_calls,
		])


func _run_sim_tick_perf(failures: Array) -> void:
	var compiler := BoardScript.new()
	var board: Dictionary = compiler.compile(BoardsScript.by_id("lock_cascade"))
	var sim := SimScript.new()
	sim.configure(board, 777331, {"cap": 10000})
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
	_sim_tick_avg_usec = avg_tick
	var object_delta := after_objects - before_objects
	if avg_tick > MAX_AVG_SIM_TICK_USEC:
		failures.append("sim tick avg %.3fus exceeded %.3fus" % [avg_tick, MAX_AVG_SIM_TICK_USEC])
	if object_delta != 0:
		failures.append("hot tick object delta expected 0, got %d" % object_delta)
	print("PINBALL_PERF_SIM ticks=%d avg_tick_us=%.3f sim_reported_avg_us=%.3f max_tick_us=%d object_delta=%d max_active=%d status=%s" % [
		ticks,
		avg_tick,
		float(sim.result_signature().get("avg_tick_usec", 0.0)),
		int(sim.result_signature().get("max_tick_usec", 0)),
		object_delta,
		int(sim.result_signature().get("max_active", 0)),
		"PASS" if avg_tick <= MAX_AVG_SIM_TICK_USEC and object_delta == 0 else "CHECK",
	])


func _active_feature_sample(definition: Dictionary, generator, pinball, scenario: Dictionary) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PINBALL-PERF-LIVE-%s" % str(scenario.get("mode", "")))
	var machine: Dictionary = generator.build_machine_from_ids(definition, {
		"format_id": str(scenario.get("format", "")),
		"type_id": "pinball",
		"math_variant_id": "standard",
		"bonus_variant_id": "plain",
		"cabinet_variant_id": "neon_magenta",
	}, run_state.create_rng("machine"))
	machine = StateScript.set_selected_bet(machine, "bet_10")
	var rng: RngStream = run_state.create_rng("feature")
	var active: Dictionary = pinball.open_feature(machine, 10, rng, definition)
	machine["active_bonus"] = active
	var inputs: Array = scenario.get("inputs", ["slot_bonus_launch"])
	for guard in range(inputs.size()):
		var action_id := str(inputs[posmod(guard, inputs.size())])
		var step: Dictionary = pinball.step_bonus(machine, action_id, rng, definition, {"surface_time_msec": 800 + guard * 120})
		machine["active_bonus"] = _dict(step.get("active_bonus", machine.get("active_bonus", {})))
	machine["slot_animation_id"] = "bonus:pinball_live_perf:%s" % str(scenario.get("mode", ""))
	machine["slot_animation_duration_msec"] = 12000
	machine["slot_animation_plan"] = {"id": machine["slot_animation_id"], "duration_msec": 12000, "feature_duration_msec": 12000}
	return {"machine": machine, "run_state": run_state}


func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}
