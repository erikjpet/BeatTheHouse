extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const GeneratorScript := preload("res://scripts/games/slots/slot_machine_generator.gd")
const StateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const PinballScript := preload("res://scripts/games/slots/slot_family_pinball.gd")
const PresentationScript := preload("res://scripts/games/slots/slot_presentation.gd")
const RendererScript := preload("res://scripts/games/slots/slot_renderer.gd")

const DEFAULT_FRAMES := 240
const MAX_AVG_SURFACE_USEC := 2500.0
const MAX_AVG_TOTAL_USEC := 8000.0

const FEATURE_SCENARIOS := [
	{"format": "classic_3_reel", "mode": "em_bumper_drop", "inputs": ["slot_bonus_launch", "slot_bonus_left"]},
	{"format": "line_5x3", "mode": "lane_multiball", "inputs": ["slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch"]},
	{"format": "video_feature", "mode": "video_feature", "inputs": ["slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch"]},
]


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
		var sample: Dictionary = _completed_feature_sample(definition, generator, pinball, scenario)
		var machine: Dictionary = _dict(sample.get("machine", {}))
		var run_state: RunState = sample.get("run_state", null)
		var surface_usec := 0
		var signature_usec := 0
		var draw_usec := 0
		var max_draw_calls := 0
		var max_label_calls := 0
		var max_hit_calls := 0
		for frame in range(frames):
			var time_msec := frame * 16
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
		if avg_surface > MAX_AVG_SURFACE_USEC:
			failures.append("%s surface_state avg %.3fus exceeded %.3fus" % [str(scenario.get("mode", "")), avg_surface, MAX_AVG_SURFACE_USEC])
		if avg_total > MAX_AVG_TOTAL_USEC:
			failures.append("%s visual avg %.3fus exceeded %.3fus" % [str(scenario.get("mode", "")), avg_total, MAX_AVG_TOTAL_USEC])
		print("PINBALL_PERF_VISUAL mode=%s frames=%d avg_surface_us=%.3f avg_signature_us=%.3f avg_draw_us=%.3f avg_total_us=%.3f max_draw_calls=%d max_label_calls=%d max_hit_calls=%d" % [
			str(scenario.get("mode", "")),
			frames,
			avg_surface,
			avg_signature,
			avg_draw,
			avg_total,
			max_draw_calls,
			max_label_calls,
			max_hit_calls,
		])


func _completed_feature_sample(definition: Dictionary, generator, pinball, scenario: Dictionary) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PINBALL-PERF-VISUAL-%s" % str(scenario.get("mode", "")))
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
	var guard := 0
	var last_step: Dictionary = {}
	while bool(_dict(machine.get("active_bonus", {})).get("active", false)) and guard < 160:
		var action_id := str(inputs[posmod(guard, inputs.size())])
		last_step = pinball.step_bonus(machine, action_id, rng, definition, {"surface_time_msec": 240 + guard * 180})
		guard += 1
	var replay: Dictionary = _dict(last_step.get("active_bonus", machine.get("last_bonus_replay", {})))
	var duration := maxi(1800, int(replay.get("animation_duration_msec", 0)))
	machine["last_bonus_replay"] = replay
	machine["active_bonus"] = {"active": false, "complete": true}
	machine["slot_animation_id"] = "bonus:pinball_perf:%s" % str(scenario.get("mode", ""))
	machine["slot_animation_duration_msec"] = duration
	machine["slot_animation_plan"] = {"id": machine["slot_animation_id"], "duration_msec": duration, "feature_duration_msec": duration}
	return {"machine": machine, "run_state": run_state}


func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}
