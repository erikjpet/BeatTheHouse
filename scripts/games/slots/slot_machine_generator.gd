class_name SlotMachineGenerator
extends RefCounted

const MathScript := preload("res://scripts/games/slots/slot_rng_math.gd")
const StateScript := preload("res://scripts/games/slots/slot_machine_state.gd")


func generate_machine(run_state: RunState, environment: Dictionary, rng: RngStream, definition: Dictionary, game_id: String) -> Dictionary:
	var environment_id := str(environment.get("id", "environment"))
	var archetype_id := str(environment.get("archetype_id", environment.get("kind", "archetype")))
	var stream_key := "slot_machine:%s:%s:%s" % [game_id, environment_id, archetype_id]
	var generation_rng: RngStream = run_state.create_rng(stream_key) if run_state != null else rng.fork(stream_key)
	var format: Dictionary = MathScript.weighted_pick(_dictionary_array(definition.get("slot_formats", [])), generation_rng)
	var family: Dictionary = MathScript.weighted_pick(_dictionary_array(definition.get("slot_types", [])), generation_rng)
	var math_variant: Dictionary = MathScript.weighted_pick(_dictionary_array(definition.get("slot_math_variants", [])), generation_rng)
	var cabinet: Dictionary = MathScript.weighted_pick(_dictionary_array(definition.get("slot_cabinet_variants", [])), generation_rng)
	var bonus: Dictionary = MathScript.weighted_pick(_dictionary_array(definition.get("slot_bonus_variants", [])), generation_rng)
	return build_machine_from_ids(definition, {
		"format_id": str(format.get("id", "classic_3_reel")),
		"type_id": str(family.get("id", "pinball")),
		"math_variant_id": str(math_variant.get("id", "standard")),
		"cabinet_variant_id": str(cabinet.get("id", "neon_magenta")),
		"bonus_variant_id": str(bonus.get("id", "plain")),
	}, generation_rng)


func build_machine_from_ids(definition: Dictionary, ids: Dictionary, rng: RngStream) -> Dictionary:
	var format_id := str(ids.get("format_id", "classic_3_reel"))
	var family_id := str(ids.get("type_id", "pinball"))
	var math_id := str(ids.get("math_variant_id", "standard"))
	var cabinet_id := str(ids.get("cabinet_variant_id", "neon_magenta"))
	var bonus_id := str(ids.get("bonus_variant_id", "plain"))
	var geometry: Dictionary = StateScript.canonical_geometry(definition, family_id, format_id)
	var reel_count := int(geometry.get("reel_count", 3))
	var row_count := int(geometry.get("row_count", 1))
	var strips: Array = _configured_strips(definition, family_id, format_id, reel_count)
	var stops: Array = MathScript.pick_reel_stops(strips, rng)
	var grid: Array = MathScript.project_grid(strips, stops, reel_count, row_count)
	var machine := {
		"schema_version": StateScript.SCHEMA_VERSION,
		"format_id": format_id,
		"type_id": family_id,
		"math_variant_id": math_id,
		"cabinet_variant_id": cabinet_id,
		"bonus_variant_id": bonus_id,
		"machine_key": "%s:%s:%s:%s:%s" % [format_id, family_id, math_id, bonus_id, cabinet_id],
		"reel_count": reel_count,
		"row_count": row_count,
		"reel_heights": _reel_heights(strips),
		"pay_model": str(geometry.get("pay_model", "single_line")),
		"reel_strips": strips,
		"bonus_reel_strips": strips.duplicate(true),
		"reel_stops": stops,
		"last_grid": grid,
		"last_previous_grid": [],
		"last_reels": [],
		"last_payout": 0,
		"last_net": 0,
		"last_stake_cost": 0,
		"last_line_payout": 0,
		"last_classification": "idle",
		"last_outcome_id": "",
		"previous_result_payout": 0,
		"previous_result_net": 0,
		"previous_result_classification": "idle",
		"previous_result_reason": "",
		"free_spins": 0,
		"spin_count": 0,
		"coin_in": 0,
		"coin_out": 0,
		"last_bonus_total": 0,
		"last_bonus_mode": "",
		"last_bonus_complete": false,
		"last_tease_events": [],
		"last_nudge_offer": {},
		"active_bonus": {"active": false, "complete": true},
		"bonus_state": {},
		"bet_ladder": {"selected_id": "bet_2"},
		"pinball_feature_state": {
			"skill_target_power": rng.randi_range(35, 65),
		},
		"buffalo_feature_state": {},
	}
	return StateScript.normalize(machine)


func all_behavior_keys(definition: Dictionary) -> Array:
	var keys: Array = []
	for format_value in _dictionary_array(definition.get("slot_formats", [])):
		var format: Dictionary = format_value
		for family_value in _dictionary_array(definition.get("slot_types", [])):
			var family: Dictionary = family_value
			for math_value in _dictionary_array(definition.get("slot_math_variants", [])):
				var math_variant: Dictionary = math_value
				for bonus_value in _dictionary_array(definition.get("slot_bonus_variants", [])):
					var bonus: Dictionary = bonus_value
					keys.append("%s:%s:%s:%s" % [
						str(format.get("id", "")),
						str(family.get("id", "")),
						str(math_variant.get("id", "")),
						str(bonus.get("id", "")),
					])
	return keys


func all_visual_keys(definition: Dictionary) -> Array:
	var keys: Array = []
	for behavior_key in all_behavior_keys(definition):
		for cabinet_value in _dictionary_array(definition.get("slot_cabinet_variants", [])):
			var cabinet: Dictionary = cabinet_value
			keys.append("%s:%s" % [behavior_key, str(cabinet.get("id", ""))])
	return keys


func _configured_strips(definition: Dictionary, family_id: String, format_id: String, reel_count: int) -> Array:
	var config_key := "slot_%s_config" % family_id
	var family_config: Dictionary = _copy_dict(definition.get(config_key, {}))
	var by_format: Dictionary = _copy_dict(family_config.get("reel_strips", {}))
	var source: Variant = by_format.get(format_id, [])
	var strips: Array = []
	if typeof(source) == TYPE_ARRAY:
		var source_strips: Array = source as Array
		for strip_value in source_strips:
			if typeof(strip_value) == TYPE_ARRAY:
				var strip: Array = []
				var symbols: Array = strip_value as Array
				for symbol in symbols:
					strip.append(str(symbol))
				strips.append(strip)
	while strips.size() < reel_count:
		strips.append(_fallback_strip(family_id))
	if strips.size() > reel_count:
		strips = strips.slice(0, reel_count)
	return strips


func _fallback_strip(family_id: String) -> Array:
	if family_id == "buffalo":
		return ["BLANK", "A", "K", "Q", "J", "10", "BUFFALO", "SUNSET", "GOLD_TOKEN", "EAGLE", "WOLF", "HORSE", "ELK", "CASH"]
	return ["BLANK", "BUMPER", "BALL", "SPINNER", "CHERRY", "BAR", "7", "DOUBLE", "DOUBLE_7", "PINBALL", "WILD"]


func _reel_heights(strips: Array) -> Array:
	var heights: Array = []
	for strip_value in strips:
		heights.append(_array_size(strip_value))
	return heights


func _array_size(value: Variant) -> int:
	if typeof(value) != TYPE_ARRAY:
		return 0
	return (value as Array).size()


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var source: Array = value as Array
	for entry in source:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
