extends SceneTree

const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")


func _initialize() -> void:
	var failures: Array = []
	var definitions := CrewStateModelScript.job_definitions()
	if definitions.size() != 13:
		failures.append("world06_4 expected all 13 shipped job definitions; found %d." % definitions.size())
	var locked_before := JSON.stringify(definitions)
	for definition in definitions:
		_check_job(definition, failures)
	if JSON.stringify(CrewStateModelScript.job_definitions()) != locked_before:
		failures.append("world06_4 staged execution mutated locked job definitions or values.")
	_check_room_projection(failures)
	_check_receipts(failures)
	if failures.is_empty():
		print("world06_4 jobs model contract passed jobs=13 values=unchanged")
		quit(0)
		return
	for failure in failures: push_error(str(failure))
	quit(1)


func _check_job(definition: Dictionary, failures: Array) -> void:
	var id := str(definition.get("id", ""))
	var state := CrewStateModelScript.new_job_execution(id, "instance:%s" % id, 5)
	if state.is_empty() or int(state.get("expires_at_action", 0)) != 5 + int(definition.get("expiry_in_actions", 0)):
		failures.append("Job %s did not preserve its exact definition and expiry." % id)
		return
	state = CrewStateModelScript.apply_job_action(state, "%s:accept" % id, "accept")
	var kind := str(definition.get("kind", ""))
	if kind == "stake_horse":
		state = CrewStateModelScript.apply_job_action(state, "%s:stake" % id, "stake_hand")
		var staged := state.get("staged", {}) as Dictionary
		var payload := definition.get("payload", {}) as Dictionary
		if int(staged.get("crew_stake", -1)) != int(payload.get("crew_stake", 0)):
			failures.append("Stake job %s changed its locked crew stake." % id)
		state = CrewStateModelScript.apply_job_action(state, "%s:witness" % id, "stake_witness", {"bankroll_delta": int(payload.get("profit_target", 0))})
		state = CrewStateModelScript.apply_job_action(state, "%s:complete" % id, "complete")
	elif kind == "collection":
		state = CrewStateModelScript.apply_job_action(state, "%s:arrive" % id, "collection_arrive", {"target_node_id": "fixture", "target_present": true})
		state = CrewStateModelScript.apply_job_action(state, "%s:friendly" % id, "collection_friendly")
		var effect := state.get("staged", {}) as Dictionary
		var payload := definition.get("payload", {}) as Dictionary
		if int(effect.get("cash", -1)) != int(payload.get("friendly_cash", 0)) or int(effect.get("heat", -1)) != int(payload.get("friendly_heat", 0)):
			failures.append("Collection job %s changed its friendly cash/heat values." % id)
	else:
		state = CrewStateModelScript.apply_job_action(state, "%s:start" % id, "start")
		state = CrewStateModelScript.apply_job_action(state, "%s:complete" % id, "complete")
	if str(state.get("phase", "")) != "resolved" or str(state.get("outcome", "")) != "success":
		failures.append("Job %s did not reach its model-owned staged success." % id)
	var public_text := JSON.stringify(CrewStateModelScript.job_execution_public_state(state)).to_lower()
	for forbidden in ["grievance_weight", "turn", "traitor", "clue_weight"]:
		if public_text.contains(forbidden): failures.append("Job %s public projection leaked %s." % [id, forbidden])


func _check_room_projection(failures: Array) -> void:
	var trust := CrewStateModelScript.default_trust()
	trust["crew_rook"] = CrewStateModelScript.rank_threshold("associate")
	trust["crew_mags"] = CrewStateModelScript.rank_threshold("made")
	var jobs := {"job:one": {"member_id": "crew_mags", "definition_id": "mags_low_roller_stake", "kind": "stake_horse", "status": "active", "outcome": "", "offered_action": 0, "expires_at_action": 16, "expiry_in_actions": 16, "rewards": {"cash": 10, "trust": 6}, "failure": {"trust": -5, "grievance_kind": "", "grievance_weight": 1}}}
	var room := CrewStateModelScript.layer3_room_state(["crew_rook", "crew_mags"], trust, [], jobs)
	if int(room.get("occupancy_count", 0)) != 2 or (room.get("objects", []) as Array).size() != 6:
		failures.append("Layer 3 projection lost occupancy or six reachable service objects.")
	var text := JSON.stringify(room).to_lower()
	for forbidden in ["grievance_weight", "turn_eligibility", "traitor"]:
		if text.contains(forbidden): failures.append("Layer 3 player-safe projection leaked %s." % forbidden)


func _check_receipts(failures: Array) -> void:
	var state := CrewStateModelScript.new_job_execution("mags_low_roller_stake", "receipt", 0)
	state = CrewStateModelScript.apply_job_action(state, "receipt:accept", "accept")
	var exact := JSON.stringify(state)
	state = CrewStateModelScript.apply_job_action(state, "receipt:accept", "accept")
	if JSON.stringify(state) != exact: failures.append("Job action receipt replay was not exact no-op.")
	state = CrewStateModelScript.apply_job_action(state, "receipt:accept", "stake_hand")
	if JSON.stringify(state) != exact: failures.append("Conflicting job receipt mutated execution state.")
	var hostile := JSON.parse_string(exact) as Dictionary
	var receipts := hostile.get("action_receipts", {}) as Dictionary
	var receipt := receipts.get("receipt:accept", {}) as Dictionary
	receipt["unexpected"] = true
	receipts["receipt:accept"] = receipt
	hostile["action_receipts"] = receipts
	if not CrewStateModelScript.normalize_job_execution(hostile).is_empty(): failures.append("Malformed job receipt did not fail closed.")
