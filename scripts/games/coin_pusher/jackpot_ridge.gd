class_name JackpotRidgeVariation
extends RefCounted


static func initial_state(config: Dictionary, rng: RngStream, lane_count: int, cell_count: int) -> Dictionary:
	var schedule: Array = []
	var cursor := 0
	var schedule_count := maxi(6, int(config.get("schedule_count", 18)))
	for index in range(schedule_count):
		cursor += rng.randi_range(maxi(1, int(config.get("spawn_gap_min", 2))), maxi(2, int(config.get("spawn_gap_max", 5))))
		var kind_roll := rng.randi_range(1, 100)
		var kind := "multiplier" if kind_roll <= 55 else "lock" if kind_roll <= 78 else "dud"
		var multiplier_values: Array = config.get("multiplier_values", [2, 3, 5]) if typeof(config.get("multiplier_values", [])) == TYPE_ARRAY else [2, 3, 5]
		schedule.append({
			"id": "ridge_puck_%02d" % index,
			"spawn_action": cursor,
			"kind": kind,
			"multiplier": int(multiplier_values[rng.randi_range(0, multiplier_values.size() - 1)]) if kind == "multiplier" else 1,
			"charges": maxi(1, int(config.get("multiplier_drop_count", 2))),
			"shelf": "upper" if rng.randi_range(0, 1) == 0 else "lower",
			"spawn_x_milli": rng.randi_range(80, 920),
			"spawn_depth_milli": rng.randi_range(100, 900),
		})
	var state := {
		"puck_schedule": schedule,
		"schedule_cursor": 0,
		"pucks": [],
		"armed_multipliers": [],
		"shelf_cycle": 0,
		"ridge_run_count": 0,
		"ridge_run_cycles_remaining": 0,
		"ridge_cycle_serial": 0,
		"multiplier_banks_by_cycle": {},
		"upper_lock_cycles": 0,
		"lower_lock_cycles": 0,
		"last_feature_message": "Sequence the pucks. Duds choke a lane.",
	}
	_seed_opening_pucks(state, config, rng, lane_count, cell_count)
	return state


static func prepare_action(state: Dictionary, action_count: int) -> void:
	var schedule: Array = state.get("puck_schedule", []) if typeof(state.get("puck_schedule", [])) == TYPE_ARRAY else []
	var pucks: Array = state.get("pucks", []) if typeof(state.get("pucks", [])) == TYPE_ARRAY else []
	var cursor := maxi(0, int(state.get("schedule_cursor", 0)))
	while cursor < schedule.size() and int((schedule[cursor] as Dictionary).get("spawn_action", 0)) <= action_count:
		pucks.append((schedule[cursor] as Dictionary).duplicate(true))
		cursor += 1
	state["schedule_cursor"] = cursor
	state["pucks"] = pucks


static func payout_multiplier(state: Dictionary) -> int:
	var multiplier := 1
	for value in state.get("armed_multipliers", []):
		if typeof(value) == TYPE_DICTIONARY and int((value as Dictionary).get("remaining", 0)) > 0:
			multiplier = maxi(multiplier, int((value as Dictionary).get("multiplier", 1)))
	return multiplier


static func finish_drop(state: Dictionary) -> void:
	var remaining: Array = []
	for value in state.get("armed_multipliers", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var charge := (value as Dictionary).duplicate(false)
		charge["remaining"] = int(charge.get("remaining", 0)) - 1
		if int(charge.get("remaining", 0)) > 0:
			remaining.append(charge)
	state["armed_multipliers"] = remaining


static func tolerance_band_bonus(run_state: RunState, config: Dictionary) -> int:
	if run_state == null:
		return 0
	var bands := maxi(0, run_state.item_effect_total("coin_pusher_nudge_tolerance_band_delta", "coin_pusher"))
	return bands * maxi(1, int(config.get("tolerance_band_size", 2)))


static func apply_physical_events(state: Dictionary, physics_events: Array, config: Dictionary, fallback_cycle: int = 0) -> Dictionary:
	var pucks: Array = state.get("pucks", []) if typeof(state.get("pucks", [])) == TYPE_ARRAY else []
	var remaining: Array = []
	var banked: Array = []
	var lost: Array = []
	var outcomes := {}
	var outcome_cycles := {}
	for event_value in physics_events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		if str(event.get("body_kind", event.get("kind", ""))) != "puck":
			continue
		var metadata: Dictionary = event.get("metadata", {}) if typeof(event.get("metadata", {})) == TYPE_DICTIONARY else {}
		outcomes[str(metadata.get("feature_id", ""))] = str(event.get("outcome", ""))
		outcome_cycles[str(metadata.get("feature_id", ""))] = int(event.get("stroke_cycle", fallback_cycle))
	for value in pucks:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var puck: Dictionary = value
		var outcome := str(outcomes.get(str(puck.get("id", "")), ""))
		if outcome == "tray":
			banked.append(puck)
		elif outcome == "gutter":
			lost.append(puck)
		else:
			remaining.append(puck)
	state["pucks"] = remaining
	var multiplier_drops := 0
	var banks_by_cycle: Dictionary = state.get("multiplier_banks_by_cycle", {}) if typeof(state.get("multiplier_banks_by_cycle", {})) == TYPE_DICTIONARY else {}
	var triggered_cycle := -1
	for puck in banked:
		match str((puck as Dictionary).get("kind", "")):
			"multiplier":
				multiplier_drops += 1
				var bank_cycle := int(outcome_cycles.get(str((puck as Dictionary).get("id", "")), fallback_cycle))
				banks_by_cycle[str(bank_cycle)] = int(banks_by_cycle.get(str(bank_cycle), 0)) + 1
				if int(banks_by_cycle[str(bank_cycle)]) >= 3:
					triggered_cycle = bank_cycle
				var charges: Array = state.get("armed_multipliers", []) if typeof(state.get("armed_multipliers", [])) == TYPE_ARRAY else []
				charges.append({"multiplier": int((puck as Dictionary).get("multiplier", 2)), "remaining": int((puck as Dictionary).get("charges", 2))})
				state["armed_multipliers"] = charges
			"lock":
				var lock_key := "%s_lock_cycles" % str((puck as Dictionary).get("shelf", "upper"))
				state[lock_key] = maxi(int(state.get(lock_key, 0)), maxi(1, int(config.get("lock_cycles", 1))))
			"dud":
				pass
	state["multiplier_banks_by_cycle"] = banks_by_cycle
	var ridge_triggered := triggered_cycle >= 0
	if ridge_triggered:
		state["ridge_run_cycles_remaining"] = maxi(int(state.get("ridge_run_cycles_remaining", 0)), maxi(1, int(config.get("ridge_run_cycles", 3))))
		state["ridge_run_count"] = int(state.get("ridge_run_count", 0)) + 1
		state["last_feature_message"] = "RIDGE RUN. Motor doubles for %d cycles." % int(state.get("ridge_run_cycles_remaining", 0))
	elif not banked.is_empty():
		state["last_feature_message"] = "%d feature puck%s physically banked." % [banked.size(), "" if banked.size() == 1 else "s"]
	elif not lost.is_empty():
		state["last_feature_message"] = "%d puck%s vanished into the side gutter." % [lost.size(), "" if lost.size() == 1 else "s"]
	return {"banked": banked, "lost": lost, "ridge_run_triggered": ridge_triggered, "multiplier_drops": multiplier_drops}


static func advance_stroke_cycle(state: Dictionary, cycle_serial: int) -> int:
	var previous := int(state.get("ridge_cycle_serial", cycle_serial))
	state["ridge_cycle_serial"] = cycle_serial
	if cycle_serial <= previous:
		return int(state.get("ridge_run_cycles_remaining", 0))
	var elapsed := cycle_serial - previous
	state["ridge_run_cycles_remaining"] = maxi(0, int(state.get("ridge_run_cycles_remaining", 0)) - elapsed)
	var retained := {}
	for key in (state.get("multiplier_banks_by_cycle", {}) as Dictionary).keys():
		if int(str(key)) >= cycle_serial - 1:
			retained[key] = (state.get("multiplier_banks_by_cycle", {}) as Dictionary)[key]
	state["multiplier_banks_by_cycle"] = retained
	return int(state.get("ridge_run_cycles_remaining", 0))


static func motor_rate_multiplier(state: Dictionary, config: Dictionary) -> int:
	return maxi(1, int(config.get("ridge_run_rate", 2))) if int(state.get("ridge_run_cycles_remaining", 0)) > 0 else 1


static func jammed_holes(state: Dictionary, body_views: Array, machine_definition: Dictionary) -> Array:
	var apparatus: Dictionary = machine_definition.get("apparatus", {}) if typeof(machine_definition.get("apparatus", {})) == TYPE_DICTIONARY else {}
	var sub_game: Dictionary = machine_definition.get("sub_game", {}) if typeof(machine_definition.get("sub_game", {})) == TYPE_DICTIONARY else {}
	var holes: Array = apparatus.get("holes", []) if typeof(apparatus.get("holes", [])) == TYPE_ARRAY else []
	var mouth_y := int(sub_game.get("jam_mouth_y", 14000))
	var radius := maxi(1, int(sub_game.get("jam_radius", 5200)))
	var dud_ids := {}
	for puck_value in state.get("pucks", []):
		if typeof(puck_value) == TYPE_DICTIONARY and str((puck_value as Dictionary).get("kind", "")) == "dud":
			dud_ids[str((puck_value as Dictionary).get("id", ""))] = true
	var result: Array = []
	for body_value in body_views:
		if typeof(body_value) != TYPE_DICTIONARY or str((body_value as Dictionary).get("kind", "")) != "puck":
			continue
		var body: Dictionary = body_value
		var metadata: Dictionary = body.get("metadata", {}) if typeof(body.get("metadata", {})) == TYPE_DICTIONARY else {}
		if not bool(dud_ids.get(str(metadata.get("feature_id", "")), false)) or absi(int(body.get("y", 0)) - mouth_y) > radius:
			continue
		for hole_index in range(holes.size()):
			if absi(int(body.get("x", 0)) - int(holes[hole_index])) <= radius and not result.has(hole_index):
				result.append(hole_index)
	result.sort()
	return result


static func views(state: Dictionary) -> Array:
	var result: Array = []
	for value in state.get("pucks", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var puck: Dictionary = value
		result.append({
			"id": str(puck.get("id", "")), "kind": str(puck.get("kind", "dud")),
			"multiplier": int(puck.get("multiplier", 1)),
		})
	return result


static func _seed_opening_pucks(state: Dictionary, config: Dictionary, rng: RngStream, lane_count: int, cell_count: int) -> void:
	var kinds := ["multiplier", "multiplier", "lock", "dud"]
	var pucks: Array = []
	for index in range(kinds.size()):
		var kind := str(kinds[index])
		pucks.append({
			"id": "ridge_open_%02d" % index, "spawn_action": 0, "kind": kind,
			"multiplier": [2, 3, 5][rng.randi_range(0, 2)] if kind == "multiplier" else 1,
			"charges": maxi(1, int(config.get("multiplier_drop_count", 2))),
			"shelf": "upper" if index % 2 == 0 else "lower",
			"spawn_x_milli": rng.randi_range(80, 920),
			"spawn_depth_milli": rng.randi_range(100, 900),
		})
	state["pucks"] = pucks
