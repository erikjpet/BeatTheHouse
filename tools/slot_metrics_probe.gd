extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const SlotMachineGeneratorScript := preload("res://scripts/games/slots/slot_machine_generator.gd")
const SlotMachineStateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const SlotResolverScript := preload("res://scripts/games/slots/slot_resolver.gd")
const SlotFamilyPinballScript := preload("res://scripts/games/slots/slot_family_pinball.gd")


func _init() -> void:
	var spins := 10000
	var args: Array = OS.get_cmdline_user_args()
	if not args.is_empty():
		spins = maxi(1, int(args[0]))
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	var definition: Dictionary = library.game("slot")
	var resolver = SlotResolverScript.new()
	var scenarios := [
		{"key": "pinball_classic_standard_plain", "family": "pinball", "format": "classic_3_reel"},
		{"key": "pinball_line_standard_plain", "family": "pinball", "format": "line_5x3"},
		{"key": "pinball_video_standard_plain", "family": "pinball", "format": "video_feature"},
		{"key": "buffalo_classic_standard_plain", "family": "buffalo", "format": "classic_3_reel"},
		{"key": "buffalo_line_standard_plain", "family": "buffalo", "format": "line_5x3"},
		{"key": "buffalo_video_standard_plain", "family": "buffalo", "format": "video_feature"},
	]
	for scenario_value in scenarios:
		var scenario: Dictionary = scenario_value
		var run_state: RunState = RunStateScript.new()
		run_state.start_new("SLOT-PROBE-%s" % str(scenario.get("key", "")))
		var generator = SlotMachineGeneratorScript.new()
		var machine: Dictionary = generator.build_machine_from_ids(definition, {
			"format_id": str(scenario.get("format", "")),
			"type_id": str(scenario.get("family", "")),
			"math_variant_id": "standard",
			"bonus_variant_id": "plain",
			"cabinet_variant_id": "neon_magenta",
		}, run_state.create_rng("machine"))
		machine = SlotMachineStateScript.set_selected_bet(machine, "bet_10")
		var metrics: Dictionary = resolver.monte_carlo_metrics(machine, definition, spins, 10, run_state.create_rng("metrics"))
		print("PROBE key=%s spins=%d rtp=%.5f hit=%.5f true=%.5f ldw=%.5f near=%.5f feature=%.5f cache=%s" % [
			str(scenario.get("key", "")),
			spins,
			float(metrics.get("rtp", 0.0)),
			float(metrics.get("hit_frequency", 0.0)),
			float(metrics.get("true_win_frequency", 0.0)),
			float(metrics.get("ldw_frequency", 0.0)),
			float(metrics.get("near_miss_frequency", 0.0)),
			float(metrics.get("feature_frequency", 0.0)),
			JSON.stringify(metrics.get("feature_award_cache", {})),
		])
	var pinball = SlotFamilyPinballScript.new()
	var pin_run: RunState = RunStateScript.new()
	pin_run.start_new("SLOT-PROBE-PINBALL-INPUT")
	var pin_generator = SlotMachineGeneratorScript.new()
	var pin_machine: Dictionary = pin_generator.build_machine_from_ids(definition, {
		"format_id": "video_feature",
		"type_id": "pinball",
		"math_variant_id": "standard",
		"bonus_variant_id": "plain",
		"cabinet_variant_id": "neon_magenta",
	}, pin_run.create_rng("machine"))
	var short_total: int = pinball.preview_feature_award(pin_machine.duplicate(true), 10, definition, pin_run.create_rng("slot_pin_video_short"), ["slot_bonus_launch"])
	var keepalive_total: int = pinball.preview_feature_award(pin_machine.duplicate(true), 10, definition, pin_run.create_rng("slot_pin_video_keep"), ["slot_bonus_left", "slot_bonus_right", "slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch"])
	print("PROBE pinball_video_input short=%d keepalive=%d" % [short_total, keepalive_total])
	quit(0)
