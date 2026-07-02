class_name PinballSequencer
extends RefCounted

const ItemsScript := preload("res://scripts/games/slots/pinball/pinball_items.gd")


func initial_state(board_id: String, mode: String) -> Dictionary:
	return {
		"board_id": board_id,
		"mode": mode,
		"locks": 0,
		"target_bank": 0,
		"bumper_streak": 0,
		"multiplier": 1,
		"multiball": false,
		"cascade_spawns": 0,
		"super_lit": false,
		"wizard": false,
		"portal_combo": 0,
		"alley_loop": 0,
		"sequence_hits": {},
		"sequence_award_total": 0,
		"lit": {},
		"last_label": "",
	}


func apply(active: Dictionary, sim, mode: String, events: Array) -> Dictionary:
	var state: Dictionary = _dict(active.get("sequencer_state", initial_state(str(active.get("board_id", "")), mode)))
	var sequence_events: Array = []
	for event_value in events:
		var event: Dictionary = _dict(event_value)
		var event_type := str(event.get("element_type", ""))
		match mode:
			"lane_multiball":
				_apply_lock_cascade(active, sim, state, event_type, sequence_events)
			"video_feature":
				_apply_jackpot_works(active, sim, state, event_type, sequence_events)
			_:
				_apply_bumper_alley(active, sim, state, event_type, sequence_events)
		_decay_combo_state(state, event_type)
	active["sequencer_state"] = state
	active["lane_locks"] = int(state.get("locks", 0))
	active["lit_jackpots"] = _lit_count(_dict(state.get("lit", {})))
	active["multiball_started"] = bool(state.get("multiball", false))
	active["video_super_jackpot_lit"] = bool(state.get("super_lit", false))
	active["video_multiball_ready"] = mode == "video_feature" and int(state.get("locks", 0)) >= 2 and not bool(state.get("multiball", false))
	active["combo_state"] = {
		"route_id": str(state.get("last_label", "")).to_lower().replace(" ", "_"),
		"step": maxi(0, int(state.get("bumper_streak", 0))),
		"multiplier": maxi(1, int(state.get("multiplier", 1))),
		"timer_ticks": 120,
		"label": str(state.get("last_label", "")),
	}
	active["lit"] = _dict(state.get("lit", {}))
	active["sequence_events"] = sequence_events
	return state


func _apply_bumper_alley(active: Dictionary, sim, state: Dictionary, event_type: String, sequence_events: Array) -> void:
	if event_type == "skill_shot":
		_award(active, sim, state, "skill_shot", "SKILL SHOT", _stake(active) * 4, sequence_events)
		_light(state, "double_pockets", true)
	if event_type == "bumper" or event_type == "slingshot":
		state["bumper_streak"] = int(state.get("bumper_streak", 0)) + 1
		if int(state.get("bumper_streak", 0)) >= 4:
			state["multiplier"] = mini(3, int(state.get("multiplier", 1)) + 1)
			_award(active, sim, state, "bumper_streak", "BUMPER STREAK", _stake(active) * 2, sequence_events)
			_light(state, "bumper_streak", true)
			state["bumper_streak"] = 0
	elif event_type == "peg":
		state["bumper_streak"] = maxi(0, int(state.get("bumper_streak", 0)) - 1)
	elif event_type == "launcher":
		state["alley_loop"] = 1
	elif event_type == "pocket" and int(state.get("alley_loop", 0)) > 0:
		_award(active, sim, state, "alley_loop", "ALLEY LOOP", _stake(active) * 3, sequence_events)
		state["alley_loop"] = 0


func _apply_lock_cascade(active: Dictionary, sim, state: Dictionary, event_type: String, sequence_events: Array) -> void:
	if event_type == "launcher":
		state["locks"] = clampi(int(state.get("locks", 0)) + ItemsScript.lock_gain(active, state), 0, 3)
		_light(state, "lock_%d" % int(state.get("locks", 0)), true)
		if int(state.get("locks", 0)) >= 3 and not bool(state.get("multiball", false)):
			state["multiball"] = true
			state["multiplier"] = maxi(2, int(state.get("multiplier", 1)))
			_launch_extra_balls(sim, 3)
			_award(active, sim, state, "locks_multiball", "LOCKS MULTIBALL", _stake(active) * 4, sequence_events)
	if bool(state.get("multiball", false)) and event_type == "skill_shot" and int(state.get("cascade_spawns", 0)) < 2:
		state["cascade_spawns"] = int(state.get("cascade_spawns", 0)) + 1
		_launch_extra_balls(sim, 1)
		_award(active, sim, state, "cascade", "CASCADE", _stake(active) * 2, sequence_events)
	if bool(state.get("multiball", false)) and event_type == "pocket":
		_award(active, sim, state, "jackpot", "JACKPOT", _stake(active) * 6, sequence_events)
		_light(state, "jackpot", false)
	if event_type == "multiplier":
		state["multiplier"] = mini(4, int(state.get("multiplier", 1)) + 1)
		_award(active, sim, state, "portal_combo", "PORTAL COMBO", _stake(active) * 2, sequence_events)


func _apply_jackpot_works(active: Dictionary, sim, state: Dictionary, event_type: String, sequence_events: Array) -> void:
	if event_type == "bumper" or event_type == "skill_shot" or event_type == "multiplier":
		state["target_bank"] = clampi(int(state.get("target_bank", 0)) + 1, 0, 6)
		_light(state, "target_%d" % int(state.get("target_bank", 0)), true)
		if int(state.get("target_bank", 0)) >= 3 and not bool(state.get("super_lit", false)):
			state["super_lit"] = true
			_award(active, sim, state, "qualify_super", "SUPER LIT", _stake(active) * 2, sequence_events)
	if event_type == "launcher":
		state["locks"] = clampi(int(state.get("locks", 0)) + 1, 0, 2)
		_light(state, "video_lock_%d" % int(state.get("locks", 0)), true)
		if int(state.get("locks", 0)) >= 2 and not bool(state.get("multiball", false)):
			state["multiball"] = true
			_launch_extra_balls(sim, 3)
			_award(active, sim, state, "video_multiball", "VIDEO MULTIBALL", _stake(active) * 4, sequence_events)
	if bool(state.get("super_lit", false)) and event_type == "pocket":
		state["super_lit"] = false
		active["video_super_jackpots"] = int(active.get("video_super_jackpots", 0)) + 1
		_award(active, sim, state, "super_jackpot", "SUPER JACKPOT", _stake(active) * 9, sequence_events)
	if bool(state.get("multiball", false)) and int(state.get("target_bank", 0)) >= 6 and not bool(state.get("wizard", false)):
		state["wizard"] = true
		state["multiplier"] = mini(5, maxi(2, int(state.get("multiplier", 1)) + 1))
		_award(active, sim, state, "jackpot_works", "JACKPOT WORKS", _stake(active) * 10, sequence_events)


func _award(active: Dictionary, sim, state: Dictionary, sequence_id: String, label: String, amount: int, sequence_events: Array) -> void:
	var hits: Dictionary = _dict(state.get("sequence_hits", {}))
	var award := maxi(1, amount * maxi(1, int(state.get("multiplier", 1))))
	var cap := maxi(1, int(active.get("session_cap", sim.session_cap)))
	var room := maxi(0, cap - int(sim.total_awarded))
	var paid := mini(room, award)
	if paid <= 0:
		return
	sim.total_awarded += paid
	hits[sequence_id] = int(hits.get(sequence_id, 0)) + 1
	state["sequence_hits"] = hits
	state["sequence_award_total"] = int(state.get("sequence_award_total", 0)) + paid
	state["last_label"] = label
	sequence_events.append({"sequence_id": sequence_id, "label": label, "award": paid})


func _launch_extra_balls(sim, count: int) -> void:
	for index in range(maxi(0, count)):
		if sim.active_ball_count() >= 8:
			return
		var aim := -0.35 + float(index % 3) * 0.35
		sim.launch_ball({"power": 0.68, "aim": aim})


func _decay_combo_state(state: Dictionary, event_type: String) -> void:
	if event_type == "drain":
		state["bumper_streak"] = 0


func _light(state: Dictionary, key: String, value: bool) -> void:
	var lit: Dictionary = _dict(state.get("lit", {}))
	lit[key] = value
	state["lit"] = lit


func _lit_count(lit: Dictionary) -> int:
	var total := 0
	for key_value in lit.keys():
		if bool(lit.get(key_value, false)):
			total += 1
	return total


func _stake(active: Dictionary) -> int:
	return maxi(1, int(active.get("stake", 1)))


func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}
