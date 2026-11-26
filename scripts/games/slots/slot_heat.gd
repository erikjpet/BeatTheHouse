extends RefCounted

# The room's nudge forecast and action settlement use the same Heat rules.
const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")
const StateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const NUDGE_ACTION := "nudge"


static func apply_nudge_item_heat(machine: Dictionary, item_effects: Dictionary, nudge_event: Dictionary) -> void:
	var item_state: Dictionary = JsonCoerceScript._copy_dict(machine.get("slot_item_state", {}))
	var cold_charges := maxi(0, int(item_state.get("cold_quarters_charges", 0)))
	if cold_charges > 0:
		var reduction := maxi(0, int(item_effects.get("slot_cold_quarter_heat_reduction", 0)))
		if reduction > 0:
			item_effects["cheat_suspicion_delta"] = int(item_effects.get("cheat_suspicion_delta", 0)) - reduction
			item_effects["slot_cold_quarter_used"] = true
			cold_charges -= 1
			if cold_charges <= 0:
				item_state.erase("cold_quarters_charges")
			else:
				item_state["cold_quarters_charges"] = cold_charges
			item_effects["slot_cold_quarters_remaining"] = cold_charges
	var skill_outcome := str(nudge_event.get("skill_outcome", ""))
	if bool(nudge_event.get("lucky_reel_grease_active", false)) and (skill_outcome == "clean_miss" or skill_outcome == "blown"):
		var heat_bonus := maxi(0, int(item_state.get("lucky_reel_grease_failed_nudge_heat_bonus", 14)))
		item_effects["cheat_suspicion_delta"] = int(item_effects.get("cheat_suspicion_delta", 0)) + heat_bonus
		item_effects["slot_grease_failed_nudge_heat_bonus_applied"] = heat_bonus
	machine["slot_item_state"] = item_state


static func preview_nudge_heat(machine: Dictionary, run_state: RunState, definition: Dictionary, environment: Dictionary, item_effects: Dictionary) -> Dictionary:
	# Use the settlement helpers on detached item state. Forecast the worst
	# skill outcome cost without spending a Cold Quarter or resolving an action.
	var projected_machine := {"slot_item_state": JsonCoerceScript._copy_dict(machine.get("slot_item_state", {}))}
	var projected_effects := item_effects.duplicate(true)
	var offer := JsonCoerceScript._copy_dict(machine.get("last_nudge_offer", {}))
	apply_nudge_item_heat(projected_machine, projected_effects, {
		"skill_outcome": "blown",
		"lucky_reel_grease_active": bool(offer.get("lucky_reel_grease_active", false)),
	})
	var stake := maxi(1, int(StateScript.selected_bet(machine).get("total_credits", 2)))
	return cheat_heat(NUDGE_ACTION, stake, run_state, definition, environment, projected_effects)


static func cheat_heat(action_id: String, stake: int, run_state: RunState, definition: Dictionary, environment: Dictionary, item_effects: Dictionary) -> Dictionary:
	var cheat_def: Dictionary = _cheat_action_def(definition, action_id)
	var base_heat := int(cheat_def.get("suspicion_delta", 12))
	if run_state == null:
		return {
			"suspicion_delta": maxi(0, base_heat),
			"base_suspicion_delta": maxi(0, base_heat),
			"security_bankroll_delta": 0,
			"security_message": "",
			"security_ended": false,
			"pit_boss_watched": false,
			"pit_boss_heat_bonus": 0,
		}
	var pit_boss_status: Dictionary = run_state.pit_boss_watch_status(environment)
	var pit_boss_bonus := int(pit_boss_status.get("cheat_heat_bonus", 0)) if bool(pit_boss_status.get("active", false)) else 0
	var raw_heat := maxi(0, base_heat + int(item_effects.get("cheat_suspicion_delta", 0)) + run_state.security_risk_bonus("cheat") + pit_boss_bonus)
	var suspicion_delta := run_state.alcohol_adjusted_suspicion_delta(raw_heat) if raw_heat > 0 else 0
	var security_pressure: Dictionary = run_state.security_action_pressure("cheat", stake, run_state.suspicion_level() + suspicion_delta) if suspicion_delta > 0 else {}
	var security_message := str(security_pressure.get("message", ""))
	var pit_boss_summary := str(pit_boss_status.get("summary", "")) if bool(pit_boss_status.get("active", false)) else ""
	if not pit_boss_summary.is_empty():
		security_message = "%s %s" % [pit_boss_summary, security_message]
		security_message = security_message.strip_edges()
	return {
		"suspicion_delta": suspicion_delta,
		"base_suspicion_delta": maxi(0, base_heat),
		"security_bankroll_delta": int(security_pressure.get("bankroll_delta", 0)),
		"security_message": security_message,
		"security_ended": bool(security_pressure.get("ended", false)),
		"pit_boss_watched": bool(pit_boss_status.get("watched", false)),
		"pit_boss_heat_bonus": pit_boss_bonus,
	}


static func _cheat_action_def(definition: Dictionary, action_id: String) -> Dictionary:
	var actions: Array = definition.get("cheat_actions", []) if typeof(definition.get("cheat_actions", [])) == TYPE_ARRAY else []
	for action_value in actions:
		if typeof(action_value) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_value
		if str(action.get("id", "")) == action_id:
			return action.duplicate(true)
	return {}
