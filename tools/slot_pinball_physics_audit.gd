extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const GeneratorScript := preload("res://scripts/games/slots/slot_machine_generator.gd")
const StateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const PinballScript := preload("res://scripts/games/slots/slot_family_pinball.gd")
const BoardsScript := preload("res://scripts/games/slots/pinball/pinball_boards.gd")
const BoardScript := preload("res://scripts/games/slots/pinball/pinball_board.gd")
const SimScript := preload("res://scripts/games/slots/pinball/pinball_sim.gd")

const FEATURE_SCENARIOS := [
	{"format": "classic_3_reel", "mode": "em_bumper_drop", "inputs": ["slot_bonus_launch", "slot_bonus_left"]},
	{"format": "line_5x3", "mode": "lane_multiball", "inputs": ["slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch"]},
	{"format": "video_feature", "mode": "video_feature", "inputs": ["slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch"]},
]


func _init() -> void:
	var runs := 96
	var args: Array = OS.get_cmdline_user_args()
	if not args.is_empty():
		runs = maxi(2, int(args[0]))
	var failures: Array = []
	var compiler := BoardScript.new()
	var board: Dictionary = compiler.compile(BoardsScript.by_id("bumper_alley"))
	_run_direct_sim_audit(board, runs, failures)
	_run_feature_audit(runs, failures)
	_run_item_effect_audit(failures)
	if failures.is_empty():
		print("PINBALL_SIM_AUDIT_OVERALL status=PASS failures=0")
		quit(0)
		return
	print("PINBALL_SIM_AUDIT_OVERALL status=FAIL failures=%d details=%s" % [failures.size(), JSON.stringify(failures)])
	quit(1)


func _run_direct_sim_audit(board: Dictionary, runs: int, failures: Array) -> void:
	var first := _direct_signature(board, 17)
	var repeat := _direct_signature(board, 17)
	if JSON.stringify(first) != JSON.stringify(repeat):
		failures.append("direct sim deterministic signature mismatch")
	var drained := 0
	var total_award := 0
	var total_ticks := 0
	var max_award := 0
	var max_active := 0
	var max_events_tick := 0
	var event_types: Dictionary = {}
	for run_index in range(runs):
		var signature: Dictionary = _direct_signature(board, run_index)
		total_award += int(signature.get("award", 0))
		total_ticks += int(signature.get("ticks", 0))
		max_award = maxi(max_award, int(signature.get("award", 0)))
		max_active = maxi(max_active, int(signature.get("max_active", 0)))
		max_events_tick = maxi(max_events_tick, int(signature.get("max_events_per_tick", 0)))
		if int(signature.get("active", 0)) == 0:
			drained += 1
		if int(signature.get("award", 0)) > int(signature.get("cap", 0)):
			failures.append("direct run %d exceeded payout cap" % run_index)
		var counts: Dictionary = _dict(signature.get("event_type_counts", {}))
		for key_value in counts.keys():
			event_types[str(key_value)] = true
	for required_type in [str(SimScript.EVENT_PEG), str(SimScript.EVENT_BUMPER), str(SimScript.EVENT_POCKET)]:
		if not bool(event_types.get(required_type, false)):
			failures.append("direct sim did not exercise event type %s" % required_type)
	if drained < runs:
		failures.append("direct sim left active balls in %d/%d runs" % [runs - drained, runs])
	print("PINBALL_SIM_AUDIT_DIRECT runs=%d drained=%d avg=%.2f max=%d avg_ticks=%.2f max_active=%d events_tick=%d event_types=%s" % [
		runs,
		drained,
		float(total_award) / float(maxi(1, runs)),
		max_award,
		float(total_ticks) / float(maxi(1, runs)),
		max_active,
		max_events_tick,
		JSON.stringify(event_types.keys()),
	])


func _run_feature_audit(runs: int, failures: Array) -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	var definition: Dictionary = library.game("slot")
	var generator := GeneratorScript.new()
	var pinball := PinballScript.new()
	var sample_count := maxi(2, mini(runs, 100))
	for scenario_value in FEATURE_SCENARIOS:
		var scenario: Dictionary = _dict(scenario_value)
		var first := _feature_signature(definition, generator, pinball, scenario, 23)
		var repeat := _feature_signature(definition, generator, pinball, scenario, 23)
		if JSON.stringify(first) != JSON.stringify(repeat):
			failures.append("%s feature deterministic signature mismatch" % str(scenario.get("mode", "")))
		var completed := 0
		var total_award := 0
		var max_award := 0
		var max_active := 0
		for run_index in range(sample_count):
			var signature: Dictionary = _feature_signature(definition, generator, pinball, scenario, run_index)
			total_award += int(signature.get("award", 0))
			max_award = maxi(max_award, int(signature.get("award", 0)))
			max_active = maxi(max_active, int(signature.get("max_active", 0)))
			if bool(signature.get("complete", false)):
				completed += 1
			if int(signature.get("award", 0)) > int(signature.get("cap", 0)):
				failures.append("%s feature run %d exceeded session cap" % [str(scenario.get("mode", "")), run_index])
		if completed < sample_count:
			failures.append("%s feature completed %d/%d runs" % [str(scenario.get("mode", "")), completed, sample_count])
		print("PINBALL_SIM_AUDIT_FEATURE mode=%s runs=%d complete=%d avg=%.2f max=%d max_active=%d" % [
			str(scenario.get("mode", "")),
			sample_count,
			completed,
			float(total_award) / float(maxi(1, sample_count)),
			max_award,
			max_active,
		])


func _run_item_effect_audit(failures: Array) -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	var definition: Dictionary = library.game("slot")
	var generator := GeneratorScript.new()
	var pinball := PinballScript.new()
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PINBALL-SIM-ITEMS")
	var machine: Dictionary = generator.build_machine_from_ids(definition, {
		"format_id": "classic_3_reel",
		"type_id": "pinball",
		"math_variant_id": "standard",
		"bonus_variant_id": "plain",
		"cabinet_variant_id": "neon_magenta",
	}, run_state.create_rng("machine"))
	machine = StateScript.set_selected_bet(machine, "bet_10")
	var active: Dictionary = pinball.open_feature(machine, 10, run_state.create_rng("item_open"), definition, {"slot_pinball_rubber_pegs": 1})
	var effects: Dictionary = _dict(active.get("pinball_item_effects", {}))
	if not effects.has("slot_pinball_rubber_pegs"):
		failures.append("pinball feature did not preserve pinball item effects for the new sim adapter")
	print("PINBALL_SIM_AUDIT_ITEMS effects=%s" % JSON.stringify(effects.keys()))


func _direct_signature(board: Dictionary, run_index: int) -> Dictionary:
	var sim := SimScript.new()
	sim.configure(board, 10000 + run_index, {"cap": 500})
	sim.launch_ball(_launch_for_seed(run_index))
	sim.advance_ticks(960)
	var result: Dictionary = sim.result_signature()
	result.erase("avg_tick_usec")
	result.erase("max_tick_usec")
	return result


func _feature_signature(definition: Dictionary, generator, pinball, scenario: Dictionary, run_index: int) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PINBALL-SIM-FEATURE-%s-%d" % [str(scenario.get("mode", "")), run_index])
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
	active["headless"] = true
	machine["active_bonus"] = active
	var inputs: Array = _array(scenario.get("inputs", ["slot_bonus_launch"]))
	var guard := 0
	while bool(_dict(machine.get("active_bonus", {})).get("active", false)) and guard < 48:
		var action_id := str(inputs[posmod(guard, inputs.size())])
		var step: Dictionary = pinball.step_bonus(machine, action_id, rng, definition)
		machine["active_bonus"] = _dict(step.get("active_bonus", machine.get("active_bonus", {})))
		guard += 1
	var completed: Dictionary = _dict(machine.get("last_bonus_replay", machine.get("active_bonus", {})))
	return {
		"mode": str(scenario.get("mode", "")),
		"complete": bool(completed.get("complete", false)),
		"award": int(completed.get("awarded", completed.get("feature_total", 0))),
		"cap": int(completed.get("session_cap", 0)),
		"max_active": int(completed.get("max_active_count", 0)),
		"events": _array(completed.get("event_log", [])).size(),
	}


func _launch_for_seed(seed_index: int) -> Dictionary:
	return {
		"power": 0.56 + float(seed_index % 7) * 0.055,
		"aim": -0.42 + float(seed_index % 11) * 0.084,
	}


func _array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []


func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}
