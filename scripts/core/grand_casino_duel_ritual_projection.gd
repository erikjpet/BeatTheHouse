class_name GrandCasinoDuelRitualProjection
extends RefCounted

# Contract-only presentation projection. This type cannot deal cards, transfer
# chips, roll detection, publish heat, choose a route, or settle an ending.

const RITUAL_ID := "grand_casino.showdown_duel"
const STATE_VERSION := 1
const PHASES := ["approach", "seating", "response", "commitment", "reveal", "phase_break", "crowd_change", "outcome_staging", "exit"]
const DUEL_OUTCOMES := ["walk_out_clean", "shown_the_door", "taken_out_back"]
const ROUTES := ["high_roller_cashout", "pit_boss_showdown", "crew_heist"]
const PUBLIC_CREW_FIELDS := ["member_id", "presentation_id", "pose", "public_state"]
const PUBLIC_CREW_STATES := ["present", "supporting", "departing"]


static func initial_state(authority_ref: Dictionary) -> Dictionary:
	return {
		"schema_version": STATE_VERSION,
		"ritual_id": RITUAL_ID,
		"phase_id": "approach",
		"phase_entry_receipts": ["receipt:phase_entry:approach"],
		"transition_receipts": {},
		"one_shot_receipts": {},
		"authoritative_duel_ref": _public_authority_ref(authority_ref),
		"authoritative_result_ref": "",
		"selected_ending": "",
		"outcome_receipt": "",
	}


static func normalize_state(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY: return {}
	var source := value as Dictionary
	var phase_id := str(source.get("phase_id", ""))
	if int(source.get("schema_version", 0)) != STATE_VERSION or str(source.get("ritual_id", "")) != RITUAL_ID or not PHASES.has(phase_id): return {}
	var normalized := {
		"schema_version": STATE_VERSION,
		"ritual_id": RITUAL_ID,
		"phase_id": phase_id,
		"phase_entry_receipts": _bounded_strings(source.get("phase_entry_receipts", []), 32),
		"transition_receipts": _bounded_dictionary(source.get("transition_receipts", {}), 64),
		"one_shot_receipts": _bounded_dictionary(source.get("one_shot_receipts", {}), 64),
		"authoritative_duel_ref": _public_authority_ref(_dict(source.get("authoritative_duel_ref", {}))),
		"authoritative_result_ref": str(source.get("authoritative_result_ref", "")),
		"selected_ending": str(source.get("selected_ending", "")),
		"outcome_receipt": str(source.get("outcome_receipt", "")),
	}
	if not normalized.selected_ending.is_empty() and not _valid_ending(normalized.selected_ending): return {}
	return normalized


static func apply_transition(state_value: Dictionary, next_phase: String, receipt_key: String, authority: Dictionary) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty(): return {"ok": false, "state": state_value, "error_code": "invalid_state"}
	var clean_receipt := receipt_key.strip_edges()
	if clean_receipt.is_empty() or clean_receipt.length() > 128: return {"ok": false, "state": state, "error_code": "invalid_receipt"}
	var phase_before := str(state.get("phase_id", ""))
	var result_ref := str(authority.get("authoritative_result_ref", ""))
	var ending := _ending_from_authority(authority)
	var content := {"phase_before":phase_before,"phase_after":next_phase,"authoritative_result_ref":result_ref,"selected_ending":ending}
	var fingerprint := _fingerprint(content)
	var receipts: Dictionary = state.get("transition_receipts", {})
	if receipts.has(clean_receipt):
		var prior := _dict(receipts.get(clean_receipt, {}))
		if str(prior.get("content_fingerprint", "")) == fingerprint: return {"ok": true, "state": state, "replayed": true}
		return {"ok": false, "state": state, "error_code": "receipt_content_conflict"}
	if not _allowed_transition(phase_before, next_phase, authority): return {"ok": false, "state": state, "error_code": "phase_transition_rejected"}
	if next_phase == "outcome_staging" and ending.is_empty(): return {"ok": false, "state": state, "error_code": "authoritative_result_missing"}
	var next := state.duplicate(true)
	next["phase_id"] = next_phase
	next["authoritative_result_ref"] = result_ref
	if next_phase == "outcome_staging":
		next["selected_ending"] = ending
		next["outcome_receipt"] = clean_receipt
	receipts = _dict(next.get("transition_receipts", {}))
	receipts[clean_receipt] = {"phase_before":phase_before,"phase_after":next_phase,"content_fingerprint":fingerprint,"authoritative_result_ref":result_ref}
	next["transition_receipts"] = receipts
	var entries: Array = next.get("phase_entry_receipts", [])
	entries.append("receipt:phase_entry:%s:%d" % [next_phase, entries.size() + 1])
	next["phase_entry_receipts"] = entries
	return {"ok": true, "state": next, "replayed": false}


static func record_one_shot(state_value: Dictionary, effect_id: String, receipt_key: String) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty(): return {"ok": false, "state": state_value, "error_code": "invalid_state"}
	var content := {"effect_id":effect_id,"phase_id":str(state.get("phase_id", ""))}
	var fingerprint := _fingerprint(content)
	var receipts: Dictionary = state.get("one_shot_receipts", {})
	if receipts.has(receipt_key):
		if str(_dict(receipts.get(receipt_key, {})).get("content_fingerprint", "")) == fingerprint: return {"ok": true, "state": state, "replayed": true, "emit": false}
		return {"ok": false, "state": state, "error_code": "receipt_content_conflict", "emit": false}
	var next := state.duplicate(true)
	receipts = _dict(next.get("one_shot_receipts", {}))
	receipts[receipt_key] = {"effect_id":effect_id,"phase_id":str(state.get("phase_id", "")),"content_fingerprint":fingerprint}
	next["one_shot_receipts"] = receipts
	return {"ok": true, "state": next, "replayed": false, "emit": true}


static func public_projection(duel_state: Dictionary, ritual_state_value: Dictionary, authority: Dictionary, public_crew: Array = []) -> Dictionary:
	var ritual_state := normalize_state(ritual_state_value)
	if ritual_state.is_empty(): return {}
	var outcome := str(duel_state.get("outcome", ""))
	var route_id := str(authority.get("route_id", ""))
	var ending := _ending_from_authority(authority)
	if ending.is_empty() and DUEL_OUTCOMES.has(outcome): ending = outcome
	var hand_index := maxi(0, int(duel_state.get("hand_index", 0)))
	var hand_limit := maxi(1, int(duel_state.get("hand_limit", 5)))
	var player_stack := maxi(0, int(duel_state.get("player_stack", 0)))
	var rourke_stack := maxi(0, int(duel_state.get("rourke_stack", 0)))
	var margin := player_stack - rourke_stack
	var rourke_state := _rourke_behavior(duel_state, margin, outcome)
	var room := _room_projection(hand_index, hand_limit, margin, outcome, route_id)
	return {
		"ritual_id": RITUAL_ID,
		"phase_id": str(ritual_state.get("phase_id", "")),
		"authoritative_result_ref": str(ritual_state.get("authoritative_result_ref", "")),
		"selected_ending": ending,
		"rourke_actor": {"id":"actor.rourke","behavior_state":rourke_state,"pose":_rourke_pose(str(ritual_state.get("phase_id", "")), outcome),"bark":str(duel_state.get("last_bark", ""))},
		"room_state": room,
		"player_stakes": {"player_stack":player_stack,"rourke_stack":rourke_stack,"margin":margin,"ante":maxi(0, int(duel_state.get("ante", 0))),"hand_number":mini(hand_index + 1, hand_limit),"hand_limit":hand_limit,"outcome":outcome},
		"current_edge": _public_edge(_dict(authority.get("current_edge", {}))),
		"public_crew_actors": _public_crew(public_crew),
		"available_controls": _controls_for_phase(str(ritual_state.get("phase_id", ""))),
		"energy_tier": _energy_tier(margin),
		"reduced_motion_equivalent": true,
		"colorblind_state_labels": [rourke_state, str(room.get("crowd_state", "")), str(room.get("security_state", ""))],
	}


static func _allowed_transition(current: String, next_phase: String, authority: Dictionary) -> bool:
	if next_phase == "outcome_staging" and ["seating", "commitment", "reveal", "crowd_change"].has(current): return not _ending_from_authority(authority).is_empty()
	var allowed := {
		"approach":["seating"], "seating":["response"], "response":["response", "commitment"],
		"commitment":["reveal"], "reveal":["phase_break"], "phase_break":["crowd_change"],
		"crowd_change":["commitment"], "outcome_staging":["exit"], "exit":[],
	}
	return _array(allowed.get(current, [])).has(next_phase)


static func _ending_from_authority(authority: Dictionary) -> String:
	var route_id := str(authority.get("route_id", ""))
	var outcome := str(authority.get("outcome", ""))
	if route_id == "crew_heist": return "crew_heist_final"
	if route_id == "high_roller_cashout": return "high_roller_final"
	if route_id == "pit_boss_showdown" and DUEL_OUTCOMES.has(outcome): return outcome
	if DUEL_OUTCOMES.has(outcome): return outcome
	return ""


static func _valid_ending(value: String) -> bool:
	return DUEL_OUTCOMES.has(value) or ["crew_heist_final", "high_roller_final"].has(value)


static func _rourke_behavior(duel: Dictionary, margin: int, outcome: String) -> String:
	if outcome == "walk_out_clean": return "respect"
	if outcome == "shown_the_door": return "contempt"
	if outcome == "taken_out_back": return "confidence"
	var edge := _dict(duel.get("current_edge", {}))
	if bool(edge.get("active", false)) and not bool(edge.get("called", false)): return "suspicion"
	if margin >= 12: return "realizing_loss"
	var hands := _array(duel.get("hands", []))
	if not hands.is_empty() and int(_dict(hands[hands.size() - 1]).get("transfer", 0)) > 0: return "tilt"
	if margin > 0: return "pressure"
	if margin < 0: return "confidence"
	return "arrival" if int(duel.get("hand_index", 0)) == 0 else "pressure"


static func _rourke_pose(phase_id: String, outcome: String) -> String:
	if phase_id == "approach": return "arrival"
	if phase_id == "outcome_staging" or phase_id == "exit": return "departing" if outcome == "walk_out_clean" else "standing"
	return "leaning" if ["reveal", "phase_break"].has(phase_id) else "seated"


static func _room_projection(hand_index: int, hand_limit: int, margin: int, outcome: String, route_id: String) -> Dictionary:
	var crowd_state := "full"
	if hand_index >= hand_limit - 1: crowd_state = "empty" if margin >= 0 else "hostile"
	elif hand_index >= 2: crowd_state = "thinning"
	if outcome == "walk_out_clean" or route_id in ["high_roller_cashout", "crew_heist"]: crowd_state = "celebrating"
	elif outcome in ["shown_the_door", "taken_out_back"]: crowd_state = "hostile"
	return {
		"crowd_state": crowd_state,
		"rail_state": "empty" if crowd_state == "empty" else "tight" if crowd_state == "hostile" else "open",
		"staff_state": "settling" if not outcome.is_empty() else "watching",
		"security_state": "high" if crowd_state == "hostile" else "present" if hand_index >= 2 else "low",
		"table_state": "settled" if not outcome.is_empty() else "active",
		"exit_state": "crew" if route_id == "crew_heist" else "victory" if outcome in ["walk_out_clean", "shown_the_door"] or route_id == "high_roller_cashout" else "failure" if outcome == "taken_out_back" else "blocked",
	}


static func _controls_for_phase(phase_id: String) -> Array:
	var controls := {
		"approach":["showdown.respond"], "seating":["showdown.ack_pat_down"], "response":["interrogation.respond"],
		"commitment":["commit.place","commit.correct","commit.remove","commit.undo","commit.clear","commit.repeat","commit.rebet","commit.confirm","duel.call_edge","duel.cheat"],
		"reveal":["result.reveal"], "phase_break":["staging.ack_break"], "crowd_change":["staging.ack_crowd"],
		"outcome_staging":["ending.ack"], "exit":[],
	}
	return _array(controls.get(phase_id, []))


static func _energy_tier(margin: int) -> String:
	if margin >= 12: return "player_pressing"
	if margin <= -12: return "house_pressing"
	return "controlled"


static func _public_edge(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in ["id", "label", "active", "called", "stripped", "correct_call", "called_edge_id"]:
		if value.has(key): result[key] = value.get(key)
	return result


static func _public_crew(value: Array) -> Array:
	var result: Array = []
	for actor_value in value:
		if typeof(actor_value) != TYPE_DICTIONARY: continue
		var source := actor_value as Dictionary
		var public: Dictionary = {}
		for key in PUBLIC_CREW_FIELDS:
			if source.has(key): public[key] = source.get(key)
		if str(public.get("member_id", "")).is_empty() or not PUBLIC_CREW_STATES.has(str(public.get("public_state", ""))): continue
		result.append(public)
	return result


static func _public_authority_ref(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in ["duel_id", "attempt", "route_id", "result_serial", "duel_content_fingerprint"]:
		if value.has(key): result[key] = value.get(key)
	return result


static func _fingerprint(value: Variant) -> String:
	return JSON.stringify(_canonical(value)).sha256_text()


static func _canonical(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var source := value as Dictionary
		var keys: Array = source.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var result: Dictionary = {}
		for key in keys: result[str(key)] = _canonical(source.get(key))
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for item in value as Array: result.append(_canonical(item))
		return result
	return value


static func _bounded_strings(value: Variant, limit: int) -> Array:
	var result: Array = []
	for item in _array(value):
		var text := str(item)
		if not text.is_empty() and text.length() <= 128 and result.size() < limit: result.append(text)
	return result


static func _bounded_dictionary(value: Variant, limit: int) -> Dictionary:
	var source := _dict(value)
	var result: Dictionary = {}
	var keys: Array = source.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for key in keys:
		if result.size() >= limit: break
		result[str(key)] = _dict(source.get(key))
	return result


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
