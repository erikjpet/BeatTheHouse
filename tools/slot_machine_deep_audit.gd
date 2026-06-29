extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const GeneratorScript := preload("res://scripts/games/slots/slot_machine_generator.gd")
const StateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const ResolverScript := preload("res://scripts/games/slots/slot_resolver.gd")


func _init() -> void:
	var spins := 10000
	var args: Array = OS.get_cmdline_user_args()
	if not args.is_empty():
		spins = maxi(1, int(args[0]))
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	var definition: Dictionary = library.game("slot")
	var generator = GeneratorScript.new()
	var resolver = ResolverScript.new()
	var scenarios := [
		{"key": "pinball_classic_standard_plain", "family": "pinball", "format": "classic_3_reel"},
		{"key": "pinball_line_standard_plain", "family": "pinball", "format": "line_5x3"},
		{"key": "pinball_video_standard_plain", "family": "pinball", "format": "video_feature"},
		{"key": "buffalo_classic_standard_plain", "family": "buffalo", "format": "classic_3_reel"},
		{"key": "buffalo_line_standard_plain", "family": "buffalo", "format": "line_5x3"},
		{"key": "buffalo_video_standard_plain", "family": "buffalo", "format": "video_feature"},
	]
	var missed: Array = []
	for scenario_value in scenarios:
		var scenario: Dictionary = scenario_value
		var metrics: Dictionary = _scenario_metrics(definition, generator, resolver, scenario, spins)
		var failures: Array = _target_failures(definition, scenario, metrics)
		for failure in failures:
			missed.append("%s:%s" % [str(scenario.get("key", "")), str(failure)])
		print("DEEP_AUDIT key=%s spins=%d rtp=%.5f hit=%.5f true=%.5f ldw=%.5f near=%.5f feature=%.5f bands=%s" % [
			str(scenario.get("key", "")),
			spins,
			float(metrics.get("rtp", 0.0)),
			float(metrics.get("hit_frequency", 0.0)),
			float(metrics.get("true_win_frequency", 0.0)),
			float(metrics.get("ldw_frequency", 0.0)),
			float(metrics.get("near_miss_frequency", 0.0)),
			float(metrics.get("feature_frequency", 0.0)),
			"PASS" if failures.is_empty() else "FAIL:%s" % JSON.stringify(failures),
		])
	if missed.is_empty():
		print("DEEP_AUDIT_OVERALL status=PASS missed_bands=0")
		quit(0)
		return
	print("DEEP_AUDIT_OVERALL status=FAIL missed_bands=%d details=%s" % [missed.size(), JSON.stringify(missed)])
	quit(1)


func _scenario_metrics(definition: Dictionary, generator, resolver, scenario: Dictionary, spins: int) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SLOT-DEEP-AUDIT-%s" % str(scenario.get("key", "")))
	var machine: Dictionary = generator.build_machine_from_ids(definition, {
		"format_id": str(scenario.get("format", "")),
		"type_id": str(scenario.get("family", "")),
		"math_variant_id": "standard",
		"bonus_variant_id": "plain",
		"cabinet_variant_id": "neon_magenta",
	}, run_state.create_rng("machine"))
	machine = StateScript.set_selected_bet(machine, "bet_10")
	var bet: Dictionary = StateScript.selected_bet(machine)
	var rng: RngStream = run_state.create_rng("metrics")
	var total_delta := 0
	var total_stake := 0
	var hit_count := 0
	var true_win_count := 0
	var ldw_count := 0
	var near_miss_count := 0
	var feature_count := 0
	for _spin_index in range(spins):
		if StateScript.active_bonus_incomplete(machine):
			machine["active_bonus"] = {"active": false, "complete": true}
		var resolved: Dictionary = resolver.resolve_spin(machine, "spin", bet, rng, definition, {}, false, true)
		machine = _dict(resolved.get("machine", machine))
		var result: Dictionary = _dict(resolved.get("result", {}))
		var stake_cost := maxi(0, int(result.get("slot_stake_cost", 10)))
		var payout := maxi(0, int(result.get("slot_payout", 0)))
		var classification := str(result.get("slot_classification", ""))
		total_delta += int(result.get("bankroll_delta", 0))
		total_stake += stake_cost
		if payout > 0 or bool(result.get("slot_feature_triggered", false)):
			hit_count += 1
		if classification == "true_win":
			true_win_count += 1
		elif classification == "ldw":
			ldw_count += 1
		elif classification == "near_miss":
			near_miss_count += 1
		if bool(result.get("slot_feature_triggered", false)):
			feature_count += 1
			var feature_award: int = int(resolver.complete_active_bonus_for_metrics(machine, rng, definition))
			total_delta += feature_award
			machine["active_bonus"] = {"active": false, "complete": true}
	var safe_spins := maxi(1, spins)
	var safe_stake := maxi(1, total_stake)
	return {
		"rtp": float(total_delta + total_stake) / float(safe_stake),
		"hit_frequency": float(hit_count) / float(safe_spins),
		"true_win_frequency": float(true_win_count) / float(safe_spins),
		"ldw_frequency": float(ldw_count) / float(safe_spins),
		"near_miss_frequency": float(near_miss_count) / float(safe_spins),
		"feature_frequency": float(feature_count) / float(safe_spins),
	}


func _target_failures(definition: Dictionary, scenario: Dictionary, metrics: Dictionary) -> Array:
	var targets: Dictionary = _targets_for(definition, str(scenario.get("family", "")))
	var failures: Array = []
	_check_band(failures, "rtp", float(metrics.get("rtp", 0.0)), float(targets.get("rtp", 0.0)) - float(targets.get("rtp_tolerance", 0.0)), float(targets.get("rtp", 0.0)) + float(targets.get("rtp_tolerance", 0.0)))
	_check_band(failures, "hit", float(metrics.get("hit_frequency", 0.0)), float(targets.get("hit_frequency_min", 0.0)), float(targets.get("hit_frequency_max", 1.0)))
	_check_band(failures, "true", float(metrics.get("true_win_frequency", 0.0)), float(targets.get("true_win_min", 0.0)), float(targets.get("true_win_max", 1.0)))
	_check_band(failures, "ldw", float(metrics.get("ldw_frequency", 0.0)), float(targets.get("ldw_min", 0.0)), float(targets.get("ldw_max", 1.0)))
	_check_band(failures, "near", float(metrics.get("near_miss_frequency", 0.0)), float(targets.get("near_miss", 0.0)) - float(targets.get("near_miss_tolerance", 0.0)), float(targets.get("near_miss", 0.0)) + float(targets.get("near_miss_tolerance", 0.0)))
	_check_band(failures, "feature", float(metrics.get("feature_frequency", 0.0)), float(targets.get("feature_frequency", 0.0)) - float(targets.get("feature_tolerance", 0.0)), float(targets.get("feature_frequency", 0.0)) + float(targets.get("feature_tolerance", 0.0)))
	return failures


func _check_band(failures: Array, label: String, value: float, low: float, high: float) -> void:
	if value < low or value > high:
		failures.append("%s=%.5f outside %.5f..%.5f" % [label, value, low, high])


func _targets_for(definition: Dictionary, family_id: String) -> Dictionary:
	var config_key := "slot_%s_config" % family_id
	var config: Dictionary = _dict(definition.get(config_key, {}))
	return _dict(config.get("targets", {}))


func _dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
