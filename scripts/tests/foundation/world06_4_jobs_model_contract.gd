extends SceneTree

const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")


func _initialize() -> void:
	var failures: Array = []
	var definitions := CrewStateModelScript.job_definitions()
	if definitions.size() != 13: failures.append("world06_4 expected all 13 shipped job definitions; found %d." % definitions.size())
	var locked := JSON.stringify(definitions)
	for definition in definitions: _check_job(definition, failures)
	if JSON.stringify(CrewStateModelScript.job_definitions()) != locked: failures.append("Job projections mutated locked definitions or values.")
	_check_room_projection(failures)
	_check_hostility(failures)
	if failures.is_empty():
		print("world06_4 jobs model contract passed jobs=13 values=unchanged authority=proposal_only gap=host_commitment_not_verifiable_in_model")
		quit(0)
		return
	for failure in failures: push_error(str(failure))
	quit(1)


func _check_job(definition: Dictionary, failures: Array) -> void:
	var id := str(definition.get("id", ""))
	var state := CrewStateModelScript.new_job_execution(id, "instance:%s" % id, 5)
	if state.is_empty() or int(state.get("expires_at_action", 0)) != 5 + int(definition.get("expiry_in_actions", 0)): failures.append("Job %s lost its exact deadline." % id); return
	var verbs: Array = (definition.get("semantics", {}) as Dictionary).get("public_verbs", [])
	if state.get("verbs", []) != verbs or verbs.size() < 4: failures.append("Job %s lost its authored played-work verbs." % id)
	if bool(state.get("authoritative", true)) or str(state.get("authority_gap", "")) != "host_commitment_not_verifiable_in_model": failures.append("Job %s falsely claimed authority." % id)
	var exact := JSON.stringify(state)
	var claimed := {"committed": true, "definition_id": id, "evidence_id": "caller", "instance_id": "instance:%s" % id, "source_kind": "job", "verb": "offer"}
	var requests := [
		["accept", {"owner_member_id": str(definition.get("member_id", "")), "owner_present": true, "job_evidence": claimed}],
		["start", {"job_evidence": claimed}],
		["play_step", {"verb": str(verbs[0]), "evidence": claimed}],
		["complete", {"job_evidence": claimed}], ["fail", {"job_evidence": claimed}], ["abandon", {"job_evidence": claimed}],
		["expire", {"action_index": int(state.get("expires_at_action", 0)), "job_evidence": claimed}],
	]
	for index in range(requests.size()):
		var request: Array = requests[index]
		if JSON.stringify(CrewStateModelScript.apply_job_action(state, "%s:%d" % [id, index], str(request[0]), request[1])) != exact: failures.append("Job %s trusted caller-authored %s evidence." % [id, str(request[0])])
	var public_state := CrewStateModelScript.job_execution_public_state(state)
	if str(public_state.get("phase", "")) != "offered_proposal" or bool(public_state.get("authoritative", true)) or str(public_state.get("authority_gap", "")) != "host_commitment_not_verifiable_in_model": failures.append("Job %s did not expose the exact authority gap." % id)
	var kind := str(definition.get("kind", ""))
	if kind == "stake_horse" and (not verbs.has("accept_stake") or not verbs.has("play") or not verbs.has("settle")): failures.append("Stake job %s lost stake/play/witness verbs." % id)
	if kind == "collection" and (not verbs.has("show_note") or not verbs.has("ask") or not verbs.has("press") or not verbs.has("leave")): failures.append("Collection job %s lost world collection verbs." % id)
	if kind in ["package_run", "package_delivery"] and (not verbs.has("carry") or not verbs.has("handoff")): failures.append("Package job %s lost carry/handoff verbs." % id)
	if kind == "numbers_route" and (not verbs.has("collect") or not verbs.has("deliver")): failures.append("Numbers job %s lost collect/deliver verbs." % id)
	if kind == "lookout_hold" and (not verbs.has("take_position") or not verbs.has("watch") or not verbs.has("signal")): failures.append("Lookout job %s lost position/watch/signal verbs." % id)


func _check_room_projection(failures: Array) -> void:
	var trust := CrewStateModelScript.default_trust(); trust["crew_rook"] = 30; trust["crew_mags"] = 60
	var jobs := {"job:one": {"member_id": "crew_mags", "definition_id": "mags_low_roller_stake", "kind": "stake_horse", "status": "active", "outcome": "", "offered_action": 0, "expires_at_action": 16, "expiry_in_actions": 16, "rewards": {"cash": 10, "trust": 6}, "failure": {"trust": -5, "grievance_kind": "", "grievance_weight": 1}}}
	var room := CrewStateModelScript.layer3_room_state(["crew_rook", "crew_mags"], trust, [], jobs)
	if int(room.get("occupancy_count", 0)) != 2: failures.append("Layer 3 occupancy projection changed.")
	var ids: Array = []
	for row in room.get("objects", []): ids.append(str((row as Dictionary).get("id", "")))
	if ids != ["job_board", "numbers_desk", "planning_table", "mags_bench", "rook_ride", "practice_rig"]: failures.append("Room/service/Practice Rig proposal inventory changed.")
	for forbidden in ["grievance_weight", "turn_eligibility", "traitor"]:
		if JSON.stringify(room).to_lower().contains(forbidden): failures.append("Room projection leaked %s." % forbidden)


func _check_hostility(failures: Array) -> void:
	var state := CrewStateModelScript.new_job_execution("mags_low_roller_stake", "hostile", 0)
	var exact := JSON.stringify(state)
	for key in ["unknown", "action_receipts", "receipt_fingerprint"]:
		var hostile := JSON.parse_string(exact) as Dictionary; hostile[key] = true
		if not CrewStateModelScript.normalize_job_execution(hostile).is_empty(): failures.append("Unknown/authority state key %s did not fail closed." % key)
	var empty_id := JSON.parse_string(exact) as Dictionary; empty_id["instance_id"] = ""
	if not CrewStateModelScript.normalize_job_execution(empty_id).is_empty(): failures.append("Empty instance_id did not fail closed.")
	for key in ["definition_id", "definition_fingerprint", "member_id", "kind", "payload", "expires_at_action", "verbs"]:
		var forged := JSON.parse_string(exact) as Dictionary
		forged[key] = "forged" if key not in ["payload", "verbs", "expires_at_action"] else ({} if key == "payload" else ([] if key == "verbs" else 999))
		if not CrewStateModelScript.normalize_job_execution(forged).is_empty(): failures.append("Forged definition-bound %s did not fail closed." % key)
	for key in ["phase", "step_index", "evidence_claims", "proposal_chain", "proposal_sequence", "outcome_proposal", "authoritative", "authority_gap"]:
		var forged := JSON.parse_string(exact) as Dictionary
		match key:
			"phase": forged[key] = "accepted_proposal"
			"step_index", "proposal_sequence": forged[key] = 1
			"evidence_claims", "proposal_chain": forged[key] = [{"caller": "forged"}]
			"outcome_proposal": forged[key] = "success"
			"authoritative": forged[key] = true
			"authority_gap": forged[key] = ""
		if not CrewStateModelScript.normalize_job_execution(forged).is_empty(): failures.append("Forged proposal state %s did not fail closed." % key)
	var caller_context := {"committed": true, "definition_id": "mags_low_roller_stake", "instance_id": "hostile", "source_kind": "game", "verb": "settle", "evidence_id": "forged", "unexpected": true}
	if JSON.stringify(CrewStateModelScript.apply_job_action(state, "forged", "complete", caller_context)) != exact: failures.append("Caller-forged evidence mutated model state.")
