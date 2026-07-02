class_name PinballItems
extends RefCounted

const EXISTING_ITEMS := [
	"slot_pinball_drain_cleaner_uses",
	"slot_pinball_jackpot_magnet_uses",
	"slot_pinball_splitter_token_uses",
	"slot_pinball_return_spring_uses",
	"slot_pinball_tilt_dampener_percent",
	"slot_pinball_bumper_battery_hits",
]

const NEW_ITEMS := [
	"slot_pinball_rubber_pegs",
	"slot_pinball_magnet_cup_radius_percent",
	"slot_pinball_extra_ball_token",
	"slot_pinball_plunger_tuner_width_percent",
	"slot_pinball_lock_jammer_uses",
]


static func compile_modifiers(item_effects: Dictionary) -> Dictionary:
	return {
		"rubber_pegs": _has(item_effects, "slot_pinball_rubber_pegs"),
		"magnet_cup_radius_percent": maxi(
			int(item_effects.get("slot_pinball_magnet_cup_radius_percent", 0)),
			10 if _has(item_effects, "slot_pinball_jackpot_magnet_uses") else 0
		),
		"tilt_dampener_percent": clampi(int(item_effects.get("slot_pinball_tilt_dampener_percent", 0)), 0, 90),
		"bumper_battery_hits": maxi(0, int(item_effects.get("slot_pinball_bumper_battery_hits", 0))),
		"bumper_battery_award_percent": maxi(0, int(item_effects.get("slot_pinball_bumper_battery_award_percent", 0))),
		"bumper_battery_kick_percent": maxi(0, int(item_effects.get("slot_pinball_bumper_battery_kick_percent", 100))),
		"return_spring_uses": maxi(0, int(item_effects.get("slot_pinball_return_spring_uses", 0))),
		"return_spring_impulse": maxi(0, int(item_effects.get("slot_pinball_return_spring_impulse", 0))),
	}


static func ball_budget_bonus(item_effects: Dictionary) -> int:
	return maxi(0, int(item_effects.get("slot_pinball_extra_ball_token", 0)))


static func skill_width_percent(item_effects: Dictionary) -> int:
	return maxi(100, int(item_effects.get("slot_pinball_plunger_tuner_width_percent", 100)))


static func lock_gain(active: Dictionary, state: Dictionary) -> int:
	var item_effects: Dictionary = _dict(active.get("pinball_item_effects", {}))
	if int(item_effects.get("slot_pinball_lock_jammer_uses", 0)) <= 0:
		return 1
	if bool(state.get("lock_jammer_used", false)):
		return 1
	state["lock_jammer_used"] = true
	_record_hook(active, "slot_pinball_lock_jammer", "lock_counted_double", 0)
	return 2


static func apply_event_hooks(active: Dictionary, sim, _mode: String, events: Array) -> void:
	var item_effects: Dictionary = _dict(active.get("pinball_item_effects", {}))
	if item_effects.is_empty() or events.is_empty():
		return
	_apply_splitter_token(active, sim, item_effects)
	_apply_jackpot_magnet(active, sim, item_effects)
	_apply_bumper_battery(active, sim, item_effects, events)


static func apply_drain_cleaner(active: Dictionary, sim) -> void:
	var item_effects: Dictionary = _dict(active.get("pinball_item_effects", {}))
	if int(item_effects.get("slot_pinball_drain_cleaner_uses", 0)) <= 0:
		return
	if bool(active.get("drain_cleaner_used", false)):
		return
	var stake := maxi(1, int(active.get("stake", 1)))
	var floor_percent := maxi(0, int(item_effects.get("slot_pinball_drain_cleaner_floor_percent", 0)))
	var award_percent := maxi(0, int(item_effects.get("slot_pinball_drain_cleaner_award_percent", 0)))
	var floor_award := int(round(float(stake * floor_percent) / 100.0))
	var bump_award := int(round(float(stake * award_percent) / 100.0))
	var target := maxi(floor_award, int(sim.total_awarded) + bump_award if int(sim.total_awarded) < floor_award else int(sim.total_awarded))
	var cap := maxi(1, int(active.get("session_cap", sim.session_cap)))
	var paid := maxi(0, mini(cap, target) - int(sim.total_awarded))
	if paid <= 0:
		return
	sim.total_awarded += paid
	active["drain_cleaner_used"] = true
	_record_hook(active, "slot_pinball_drain_cleaner", "floor_top_up", paid)


static func verified_item_keys() -> Array:
	return EXISTING_ITEMS + NEW_ITEMS


static func _apply_splitter_token(active: Dictionary, sim, item_effects: Dictionary) -> void:
	if int(item_effects.get("slot_pinball_splitter_token_uses", 0)) <= 0:
		return
	if bool(active.get("splitter_token_used", false)):
		return
	for sequence_value in _array(active.get("sequence_events", [])):
		var sequence: Dictionary = _dict(sequence_value)
		if str(sequence.get("sequence_id", "")) != "cascade":
			continue
		var count := maxi(1, int(item_effects.get("slot_pinball_splitter_token_extra_balls", 1)))
		for index in range(count):
			sim.launch_ball({"power": 0.66, "aim": -0.18 + float(index) * 0.18})
		active["splitter_token_used"] = true
		_record_hook(active, "slot_pinball_splitter_token", "extra_cascade_ball", 0)
		return


static func _apply_jackpot_magnet(active: Dictionary, sim, item_effects: Dictionary) -> void:
	var uses := maxi(0, int(item_effects.get("slot_pinball_jackpot_magnet_uses", 0)))
	if uses <= 0:
		return
	var used := maxi(0, int(active.get("jackpot_magnet_used", 0)))
	if used >= uses:
		return
	for sequence_value in _array(active.get("sequence_events", [])):
		var sequence: Dictionary = _dict(sequence_value)
		var sequence_id := str(sequence.get("sequence_id", ""))
		if sequence_id.find("jackpot") < 0:
			continue
		var percent := maxi(0, int(item_effects.get("slot_pinball_jackpot_magnet_award_percent", 0)))
		var bonus := maxi(1, int(round(float(int(sequence.get("award", 0)) * percent) / 100.0)))
		var room := maxi(0, int(active.get("session_cap", sim.session_cap)) - int(sim.total_awarded))
		var paid := mini(room, bonus)
		if paid > 0:
			sim.total_awarded += paid
			_record_hook(active, "slot_pinball_jackpot_magnet", "jackpot_bonus", paid)
		active["jackpot_magnet_used"] = used + 1
		active["lit_jackpots"] = maxi(int(active.get("lit_jackpots", 0)), int(active.get("lit_jackpots", 0)) + int(item_effects.get("slot_pinball_jackpot_magnet_progress_bonus", 0)))
		return


static func _apply_bumper_battery(active: Dictionary, sim, item_effects: Dictionary, events: Array) -> void:
	var max_hits := maxi(0, int(item_effects.get("slot_pinball_bumper_battery_hits", 0)))
	if max_hits <= 0:
		return
	var used := maxi(0, int(active.get("bumper_battery_used", 0)))
	for event_value in events:
		if used >= max_hits:
			break
		var event: Dictionary = _dict(event_value)
		if str(event.get("element_type", "")) != "bumper":
			continue
		var bonus := maxi(1, int(round(float(maxi(1, int(event.get("award", 1))) * int(item_effects.get("slot_pinball_bumper_battery_award_percent", 0))) / 100.0)))
		var room := maxi(0, int(active.get("session_cap", sim.session_cap)) - int(sim.total_awarded))
		var paid := mini(room, bonus)
		if paid > 0:
			sim.total_awarded += paid
			_record_hook(active, "slot_pinball_bumper_battery", "charged_bumper", paid)
		used += 1
	active["bumper_battery_used"] = used


static func _record_hook(active: Dictionary, item_id: String, hook: String, award: int) -> void:
	var hooks: Array = _array(active.get("pinball_item_hooks", []))
	hooks.append({"item": item_id, "hook": hook, "award": maxi(0, award)})
	while hooks.size() > 48:
		hooks.remove_at(0)
	active["pinball_item_hooks"] = hooks


static func _has(item_effects: Dictionary, key: String) -> bool:
	return int(item_effects.get(key, 0)) != 0 or bool(item_effects.get(key, false))


static func _array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}
