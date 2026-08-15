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
			"lane": rng.randi_range(0, lane_count - 1),
			"cell": rng.randi_range(1, maxi(1, cell_count - 1)),
			"push": 0,
		})
	var state := {
		"puck_schedule": schedule,
		"schedule_cursor": 0,
		"pucks": [],
		"jammed_lanes": [],
		"armed_multipliers": [],
		"shelf_cycle": 0,
		"ridge_run_count": 0,
		"cascade_remaining": 0,
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
	_refresh_jams(state)


static func lane_is_jammed(state: Dictionary, lane: int) -> bool:
	return _int_array(state.get("jammed_lanes", [])).has(lane)


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


static func push_strength_bonus(state: Dictionary, run_state: RunState, from_nudge: bool) -> int:
	var bonus := 1 if int(state.get("cascade_remaining", 0)) > 0 else 0
	if from_nudge and run_state != null and run_state.inventory.has("weighted_keyring"):
		bonus += 1
	return bonus


static func tolerance_band_bonus(run_state: RunState, config: Dictionary) -> int:
	if run_state == null:
		return 0
	var bands := maxi(0, run_state.item_effect_total("coin_pusher_nudge_tolerance_band_delta", "coin_pusher"))
	return bands * maxi(1, int(config.get("tolerance_band_size", 2)))


static func apply_movement(state: Dictionary, movement_events: Array, context: Dictionary, config: Dictionary) -> Dictionary:
	var pucks: Array = state.get("pucks", []) if typeof(state.get("pucks", [])) == TYPE_ARRAY else []
	var remaining: Array = []
	var dropped: Array = []
	var threshold := maxi(1, int(config.get("puck_push_threshold", 2)))
	var aimed_lane := int(context.get("aimed_lane", -1))
	var from_nudge := bool(context.get("from_nudge", false))
	for value in pucks:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var puck := (value as Dictionary).duplicate(false)
		var movement := _matching_movement(movement_events, int(puck.get("lane", -1)), int(puck.get("cell", -1)))
		if from_nudge and int(puck.get("lane", -1)) == aimed_lane:
			movement += maxi(1, int(context.get("push_strength", 0)) / 2)
		puck["push"] = int(puck.get("push", 0)) + movement
		while int(puck.get("push", 0)) >= threshold:
			puck["push"] = int(puck.get("push", 0)) - threshold
			puck["cell"] = int(puck.get("cell", 0)) - 1
		if int(puck.get("cell", 0)) < 0:
			dropped.append(puck)
		else:
			remaining.append(puck)
	state["pucks"] = remaining
	var multiplier_drops := 0
	for puck in dropped:
		match str((puck as Dictionary).get("kind", "")):
			"multiplier":
				multiplier_drops += 1
				var charges: Array = state.get("armed_multipliers", []) if typeof(state.get("armed_multipliers", [])) == TYPE_ARRAY else []
				charges.append({"multiplier": int((puck as Dictionary).get("multiplier", 2)), "remaining": int((puck as Dictionary).get("charges", 2))})
				state["armed_multipliers"] = charges
			"lock":
				var lock_key := "%s_lock_cycles" % str((puck as Dictionary).get("shelf", "upper"))
				state[lock_key] = maxi(int(state.get(lock_key, 0)), maxi(1, int(config.get("lock_cycles", 1))))
			"dud":
				pass
	var ridge_triggered := multiplier_drops >= 3
	if ridge_triggered:
		state["cascade_remaining"] = maxi(int(state.get("cascade_remaining", 0)), maxi(1, int(config.get("ridge_run_cycles", 3))))
		state["ridge_run_count"] = int(state.get("ridge_run_count", 0)) + 1
		state["last_feature_message"] = "RIDGE RUN. Back wall doubles for %d cycles." % int(state.get("cascade_remaining", 0))
	elif not dropped.is_empty():
		state["last_feature_message"] = "%d feature puck%s cleared the lip." % [dropped.size(), "" if dropped.size() == 1 else "s"]
	_refresh_jams(state)
	return {"dropped": dropped, "ridge_run_triggered": ridge_triggered, "multiplier_drops": multiplier_drops}


static func shelf_locked(state: Dictionary, shelf: String) -> bool:
	return int(state.get("%s_lock_cycles" % shelf, 0)) > 0


static func finish_shelf_cycle(state: Dictionary) -> void:
	state["shelf_cycle"] = int(state.get("shelf_cycle", 0)) + 1
	for key in ["upper_lock_cycles", "lower_lock_cycles", "cascade_remaining"]:
		state[key] = maxi(0, int(state.get(key, 0)) - 1)


static func views(state: Dictionary) -> Array:
	var result: Array = []
	for value in state.get("pucks", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var puck: Dictionary = value
		result.append({
			"id": str(puck.get("id", "")), "kind": str(puck.get("kind", "dud")),
			"lane": int(puck.get("lane", 0)), "cell": int(puck.get("cell", 0)),
			"push": int(puck.get("push", 0)), "multiplier": int(puck.get("multiplier", 1)),
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
			"lane": (index + rng.randi_range(0, lane_count - 1)) % lane_count,
			"cell": rng.randi_range(0, maxi(1, cell_count - 2)), "push": 0,
		})
	state["pucks"] = pucks
	_refresh_jams(state)


static func _matching_movement(events: Array, lane: int, cell: int) -> int:
	var movement := 0
	for value in events:
		if typeof(value) == TYPE_DICTIONARY and int((value as Dictionary).get("lane", -1)) == lane and int((value as Dictionary).get("cell", -1)) == cell:
			movement += maxi(0, int((value as Dictionary).get("moved", 0)))
	return movement


static func _refresh_jams(state: Dictionary) -> void:
	var jams: Array = []
	for value in state.get("pucks", []):
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("kind", "")) == "dud":
			var lane := int((value as Dictionary).get("lane", -1))
			if lane >= 0 and not jams.has(lane):
				jams.append(lane)
	jams.sort()
	state["jammed_lanes"] = jams


static func _int_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value as Array:
			result.append(int(entry))
	return result
