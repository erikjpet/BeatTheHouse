class_name GrandCasinoDuelModel
extends RefCounted

# Pure, action-boundary state transitions for Rourke's blackjack duel.

const OUTCOME_WALK_OUT_CLEAN := "walk_out_clean"
const OUTCOME_SHOWN_THE_DOOR := "shown_the_door"
const OUTCOME_TAKEN_OUT_BACK := "taken_out_back"


static func initialize(terms: Dictionary, rng: RngStream) -> Dictionary:
	var rules := _copy_dict(terms.get("rules", {}))
	var stacks := _copy_dict(terms.get("starting_stacks", {}))
	var hand_limit := clampi(int(rules.get("hand_limit", 5)), 1, 12)
	var cheat_level := clampi(int(terms.get("rourke_cheat_level", 0)), 0, 3)
	var edge_catalog := _dictionary_array(terms.get("edge_catalog", []))
	var edge_schedule: Array = []
	for hand_index in range(hand_limit):
		var edge: Dictionary = {
			"hand_index": hand_index,
			"active": false,
			"called": false,
			"stripped": false,
		}
		if rng != null and not edge_catalog.is_empty():
			var hand_rng := rng.fork("edge:%d" % hand_index)
			var chance := clampi(
				int(rules.get("rourke_edge_base_chance", 10))
				+ cheat_level * int(rules.get("rourke_edge_chance_per_level", 20)),
				0,
				95
			)
			if hand_rng.randi_range(1, 100) <= chance:
				edge.merge(_copy_dict(hand_rng.pick(edge_catalog, edge_catalog[0])), true)
				edge["active"] = true
		edge_schedule.append(edge)
	var player_stack := maxi(1, int(stacks.get("player", 100)))
	var rourke_stack := maxi(1, int(stacks.get("rourke", 100)))
	return {
		"version": 1,
		"status": "active",
		"outcome": "",
		"hand_index": 0,
		"hand_limit": hand_limit,
		"player_stack": player_stack,
		"rourke_stack": rourke_stack,
		"starting_player_stack": player_stack,
		"starting_rourke_stack": rourke_stack,
		"ante": maxi(1, int(rules.get("base_ante", 20)) + int(_copy_dict(terms.get("handicaps", {})).get("forced_ante", 0))),
		"edge_schedule": edge_schedule,
		"hands": [],
		"blackjack_session": {},
		"last_bark": str(_copy_dict(terms.get("barks", {})).get("intro", "Sit down. Five hands. Then the door decides.")),
		"margin": player_stack - rourke_stack,
	}


static func current_edge(state: Dictionary) -> Dictionary:
	var hand_index := maxi(0, int(state.get("hand_index", 0)))
	var schedule := _copy_array(state.get("edge_schedule", []))
	if hand_index >= schedule.size() or typeof(schedule[hand_index]) != TYPE_DICTIONARY:
		return {}
	return _copy_dict(schedule[hand_index])


static func call_out(state: Dictionary, edge_id: String, terms: Dictionary) -> Dictionary:
	var next_state := state.duplicate(true)
	if str(next_state.get("status", "")) != "active":
		return {"ok": false, "message": "The duel is already over.", "state": next_state}
	var hand_index := maxi(0, int(next_state.get("hand_index", 0)))
	var schedule := _copy_array(next_state.get("edge_schedule", []))
	if hand_index >= schedule.size():
		return {"ok": false, "message": "No hand is waiting for a challenge.", "state": next_state}
	var edge := _copy_dict(schedule[hand_index])
	if bool(edge.get("called", false)):
		return {"ok": false, "message": "You already made your call this hand.", "state": next_state}
	edge["called"] = true
	var correct := bool(edge.get("active", false)) and str(edge.get("id", "")) == edge_id
	var rules := _copy_dict(terms.get("rules", {}))
	var swing := maxi(0, int(rules.get("correct_call_swing", 8))) if correct else maxi(0, int(rules.get("false_call_cost", 6)))
	var transfer := swing if correct else -swing
	_apply_transfer(next_state, transfer)
	edge["stripped"] = correct
	edge["correct_call"] = correct
	edge["called_edge_id"] = edge_id
	schedule[hand_index] = edge
	next_state["edge_schedule"] = schedule
	var barks := _copy_dict(terms.get("barks", {}))
	next_state["last_bark"] = str(barks.get("caught_edge", "Good eye. The hand plays straight.")) if correct else str(barks.get("false_call", "Wrong tell. Pay for the noise."))
	_evaluate_terminal(next_state, terms)
	return {
		"ok": true,
		"correct": correct,
		"swing": transfer,
		"edge": edge,
		"message": "You catch Rourke's edge and strip it from the hand." if correct else "The accusation misses. Rourke takes the penalty chips.",
		"state": next_state,
	}


static func apply_hand(state: Dictionary, hand_result: Dictionary, terms: Dictionary) -> Dictionary:
	var next_state := state.duplicate(true)
	if str(next_state.get("status", "")) != "active":
		return {"ok": false, "message": "The duel is already over.", "state": next_state}
	var transfer := int(hand_result.get("transfer", 0))
	var caught_penalty := maxi(0, int(hand_result.get("caught_penalty", 0)))
	transfer -= caught_penalty
	_apply_transfer(next_state, transfer)
	var hands := _copy_array(next_state.get("hands", []))
	var recorded := hand_result.duplicate(true)
	recorded["hand_index"] = maxi(0, int(next_state.get("hand_index", 0)))
	recorded["transfer"] = transfer
	recorded["player_stack"] = int(next_state.get("player_stack", 0))
	recorded["rourke_stack"] = int(next_state.get("rourke_stack", 0))
	hands.append(recorded)
	next_state["hands"] = hands
	next_state["hand_index"] = int(next_state.get("hand_index", 0)) + 1
	next_state["blackjack_session"] = {}
	var barks := _copy_dict(terms.get("barks", {}))
	if transfer > 0:
		next_state["last_bark"] = str(barks.get("player_win", "One hand. The house is still here."))
	elif transfer < 0:
		next_state["last_bark"] = str(barks.get("rourke_win", "That is what the room does to a story."))
	else:
		next_state["last_bark"] = str(barks.get("push", "Nothing moves. Deal again."))
	_evaluate_terminal(next_state, terms)
	return {
		"ok": true,
		"transfer": transfer,
		"state": next_state,
		"outcome": str(next_state.get("outcome", "")),
	}


static func outcome_for_margin(margin: int, thresholds: Dictionary) -> String:
	if margin >= int(thresholds.get("walk_out_clean_min", 12)):
		return OUTCOME_WALK_OUT_CLEAN
	if margin >= int(thresholds.get("shown_the_door_min", -8)):
		return OUTCOME_SHOWN_THE_DOOR
	return OUTCOME_TAKEN_OUT_BACK


static func _evaluate_terminal(state: Dictionary, terms: Dictionary) -> void:
	var player_stack := maxi(0, int(state.get("player_stack", 0)))
	var rourke_stack := maxi(0, int(state.get("rourke_stack", 0)))
	var margin := player_stack - rourke_stack
	state["margin"] = margin
	var outcome := ""
	if player_stack <= 0:
		outcome = OUTCOME_TAKEN_OUT_BACK
	elif rourke_stack <= 0:
		outcome = OUTCOME_WALK_OUT_CLEAN
	elif int(state.get("hand_index", 0)) >= maxi(1, int(state.get("hand_limit", 5))):
		outcome = outcome_for_margin(margin, _copy_dict(terms.get("margin_thresholds", {})))
	if outcome.is_empty():
		return
	state["status"] = "complete"
	state["outcome"] = outcome


static func _apply_transfer(state: Dictionary, requested_transfer: int) -> void:
	var player_stack := maxi(0, int(state.get("player_stack", 0)))
	var rourke_stack := maxi(0, int(state.get("rourke_stack", 0)))
	var transfer := clampi(requested_transfer, -player_stack, rourke_stack)
	state["player_stack"] = player_stack + transfer
	state["rourke_stack"] = rourke_stack - transfer
	state["margin"] = int(state.get("player_stack", 0)) - int(state.get("rourke_stack", 0))


static func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	for entry_value in _copy_array(value):
		if typeof(entry_value) == TYPE_DICTIONARY:
			result.append((entry_value as Dictionary).duplicate(true))
	return result


static func _copy_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _copy_dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
