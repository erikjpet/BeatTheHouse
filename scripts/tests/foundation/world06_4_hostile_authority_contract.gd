extends SceneTree

const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const CrewRecruitmentModelScript := preload("res://scripts/core/crew_recruitment_model.gd")


func _initialize() -> void:
	var failures: Array = []
	if not (CrewStateModelScript as Script).can_instantiate():
		failures.append("CrewStateModel did not compile; hostile authority checks could not execute.")
	else:
		_check_job_envelope_authority(failures)
		_check_job_lifecycle_authority(failures)
	if not (CrewRecruitmentModelScript as Script).can_instantiate():
		failures.append("CrewRecruitmentModel did not compile; hostile authority checks could not execute.")
	else:
		_check_recruitment_authority(failures)
	if failures.is_empty():
		print("world06_4 hostile authority contract passed authority=host-root-required")
		quit(0)
		return
	for failure in failures:
		push_error(str(failure))
	quit(1)


func _check_job_envelope_authority(failures: Array) -> void:
	var definition := CrewStateModelScript.job_definition("mags_low_roller_stake")
	var clean := CrewStateModelScript.new_job_execution("mags_low_roller_stake", "hostile:stake", 7)
	if clean.is_empty() or CrewStateModelScript.normalize_job_execution(clean).is_empty():
		failures.append("Job proposal envelope did not normalize from its exact constructor output.")
		return
	var substitutions := {
		"definition": ["definition_id", "velvet_queen_stake"],
		"member": ["member_id", "crew_velvet"],
		"kind": ["kind", "collection"],
		"deadline": ["expires_at_action", int(clean.get("expires_at_action", 0)) + 1],
		"payload": ["payload", {"game_id": "blackjack", "venue_id": "forged", "crew_stake": 20, "profit_target": 12, "success_split": 10}],
		"instance": ["instance_id", ""],
	}
	for label in substitutions:
		var hostile: Dictionary = clean.duplicate(true)
		var substitution: Array = substitutions[label]
		hostile[substitution[0]] = substitution[1]
		if not CrewStateModelScript.normalize_job_execution(hostile).is_empty():
			failures.append("Job envelope accepted substituted %s authority." % label)
	var forged: Dictionary = clean.duplicate(true)
	forged["environment"] = {"world_node_id": "forged_casino", "scenario_id": "forged"}
	forged["path"] = ["forged_a", "forged_b"]
	forged["ledger"] = {"cash": 999999, "heat": -999}
	forged["job_evidence"] = {"settled": true, "game_id": str((definition.get("payload", {}) as Dictionary).get("game_id", ""))}
	forged["action_sequence"] = 2
	forged["action_receipts"] = {
		"one": {"sequence": 1, "previous": "genesis", "fingerprint": "a".repeat(64)},
		"two": {"sequence": 2, "previous": "a".repeat(64), "fingerprint": "b".repeat(64)},
	}
	forged["receipt_fingerprint"] = "c".repeat(64)
	if not CrewStateModelScript.normalize_job_execution(forged).is_empty():
		failures.append("Job envelope accepted a coherent caller-authored authority chain with substituted environment/path/ledger/evidence.")
	var unknown: Dictionary = clean.duplicate(true)
	unknown["unknown_authority"] = true
	if not CrewStateModelScript.normalize_job_execution(unknown).is_empty():
		failures.append("Job envelope accepted an unknown top-level key.")


func _check_job_lifecycle_authority(failures: Array) -> void:
	for definition_value in CrewStateModelScript.job_definitions():
		var definition: Dictionary = definition_value
		var definition_id := str(definition.get("id", ""))
		var state := CrewStateModelScript.new_job_execution(definition_id, "hostile:%s" % definition_id, 4)
		if state.is_empty():
			failures.append("Job %s did not create a proposal envelope." % definition_id)
			continue
		_assert_exact_noop(state, CrewStateModelScript.apply_job_action(state, "illegal:start", "start"), "Job %s started before acceptance." % definition_id, failures)
		_assert_exact_noop(state, CrewStateModelScript.apply_job_action(state, "illegal:complete", "complete"), "Job %s completed without evidence." % definition_id, failures)
		_assert_exact_noop(state, CrewStateModelScript.apply_job_action(state, "illegal:expire", "expire", {"action_index": int(state.get("expires_at_action", 0)) - 1}), "Job %s expired before its deadline." % definition_id, failures)
		_assert_exact_noop(state, CrewStateModelScript.apply_job_action(state, "illegal:unknown", "host_commit", {"host_root": "forged"}), "Job %s accepted an unknown host action." % definition_id, failures)
		_assert_exact_noop(state, CrewStateModelScript.apply_job_action(state, "forged:accept", "accept", {"owner_member_id": str(definition.get("member_id", "")), "owner_present": true, "owner_trust": 999, "host_root": "caller-authored"}), "Job %s accepted extra caller-authored host evidence." % definition_id, failures)
		var accepted := CrewStateModelScript.apply_job_action(state, "proposal:accept", "accept", {
			"owner_member_id": str(definition.get("member_id", "")),
			"owner_present": true,
			"owner_trust": CrewStateModelScript.rank_threshold(str(definition.get("min_rank", "associate"))),
		})
		if bool(accepted.get("authoritative", true)) or str(accepted.get("phase", "")) != "accepted_proposal":
			failures.append("Job %s acceptance did not remain an explicitly non-authoritative proposal." % definition_id)
			continue
		var active := CrewStateModelScript.apply_job_action(accepted, "proposal:start", "start")
		var before_step := active.duplicate(true)
		var verbs: Array = active.get("verbs", [])
		if verbs.is_empty():
			failures.append("Job %s exposes no modeled execution verbs." % definition_id)
			continue
		_assert_exact_noop(active, CrewStateModelScript.apply_job_action(active, "wrong:verb", "play_step", {"verb": "caller_substitution", "evidence_claim": {"settled": true}}), "Job %s accepted a substituted execution verb." % definition_id, failures)
		for index in range(verbs.size()):
			var evidence := {"claimed_environment": "caller-authored", "claimed_path": ["a", "b"], "claimed_ledger_delta": 999, "claimed_job_settled": true}
			active = CrewStateModelScript.apply_job_action(active, "claim:%s:%d" % [definition_id, index], "play_step", {"verb": str(verbs[index]), "evidence_claim": evidence})
			var claims: Array = active.get("evidence_claims", [])
			if claims.size() != index + 1 or bool((claims.back() as Dictionary).get("trusted", true)):
				failures.append("Job %s promoted caller-authored evidence at step %d." % [definition_id, index])
				break
		if JSON.stringify(active) == JSON.stringify(before_step):
			failures.append("Job %s did not record any proposal evidence." % definition_id)
		var terminal := CrewStateModelScript.apply_job_action(active, "proposal:complete", "complete")
		if str(terminal.get("phase", "")) != "terminal_proposal" or str(terminal.get("outcome_proposal", "")) != "success" or bool(terminal.get("authoritative", true)):
			failures.append("Job %s did not end as a non-authoritative terminal proposal." % definition_id)
		for forbidden_key in ["effect", "rewards", "failure", "cash", "heat", "trust", "grievance", "job_record", "host_root"]:
			if terminal.has(forbidden_key): failures.append("Job %s proposal committed forbidden %s state." % [definition_id, forbidden_key])
		var public_text := JSON.stringify(CrewStateModelScript.job_execution_public_state(terminal)).to_lower()
		for hidden in ["grievance_weight", "traitor", "turn_eligibility", "clue_weight", "receipt_fingerprint"]:
			if public_text.contains(hidden): failures.append("Job %s public projection leaked %s." % [definition_id, hidden])
		_assert_exact_noop(terminal, CrewStateModelScript.apply_job_action(terminal, "after:terminal", "play_step", {"verb": str(verbs[0]), "evidence_claim": {}}), "Job %s mutated after terminal proposal." % definition_id, failures)
	var expiring := CrewStateModelScript.new_job_execution("knuckles_friendly_collection", "hostile:expiry", 10)
	var expired := CrewStateModelScript.apply_job_action(expiring, "proposal:expiry", "expire", {"action_index": int(expiring.get("expires_at_action", 0))})
	if str(expired.get("phase", "")) != "terminal_proposal" or str(expired.get("outcome_proposal", "")) != "abandoned" or bool(expired.get("authoritative", true)):
		failures.append("Deadline-valid expiry did not remain a non-authoritative abandoned proposal.")


func _check_recruitment_authority(failures: Array) -> void:
	var clean := CrewRecruitmentModelScript.new_encounter_state()
	if clean.is_empty() or CrewRecruitmentModelScript.normalize_encounter_state(clean).is_empty():
		failures.append("Recruitment model did not accept its exact empty envelope.")
		return
	var unknown: Dictionary = clean.duplicate(true)
	unknown["host_root"] = "forged"
	if not CrewRecruitmentModelScript.normalize_encounter_state(unknown).is_empty():
		failures.append("Recruitment envelope accepted an unknown host-root key.")
	var forged: Dictionary = clean.duplicate(true)
	forged["meetings"] = {"crew_mags": {
		"member_id": "crew_mags", "path_kind": "road", "outcome": "accepted", "environment_id": "forged",
		"path": ["forged"], "ledger": {"trust": 999}, "job_evidence": {"completed": true},
		"authority_chain": [{"sequence": 1, "previous": "genesis", "fingerprint": "d".repeat(64)}],
	}}
	forged["contacts"] = {"crew_mags": {"standing": "inner_circle", "contact_state": "trusted"}}
	if not CrewRecruitmentModelScript.normalize_encounter_state(forged).is_empty():
		failures.append("Recruitment envelope accepted coherent caller-authored meeting/contact authority.")
	var exact := JSON.stringify(clean)
	var meeting_result := CrewRecruitmentModelScript.record_first_meeting(clean, "crew_mags", "road", "accepted", 12, {"host_root": "forged", "environment_id": "forged"})
	if JSON.stringify(meeting_result) != exact:
		failures.append("Recruitment state mutated from caller-authored meeting authority.")
	var contact_result := CrewRecruitmentModelScript.record_contact(clean, "crew_mags", "inner_circle", false, false, 13, {"host_root": "forged", "ledger": {"trust": 999}})
	if JSON.stringify(contact_result) != exact:
		failures.append("Recruitment state mutated from caller-authored contact authority.")
	var proposal := CrewRecruitmentModelScript.first_meeting_proposal(null, {"id": "forged", "world_node_id": "forged", "scenario_id": "forged"}, "crew_mags", "road", "accepted")
	if bool(proposal.get("authoritative", true)) or bool(proposal.get("can_mutate", true)) or not bool(proposal.get("proposal_only", false)):
		failures.append("Ineligible recruitment output was not explicitly non-mutating and proposal-only.")
	var public_text := JSON.stringify(CrewRecruitmentModelScript.encounter_public_state(clean, "crew_mags")).to_lower()
	for hidden in ["grievance_weight", "traitor", "turn_eligibility", "clue_weight", "authority_chain", "host_root"]:
		if public_text.contains(hidden): failures.append("Recruitment public projection leaked %s." % hidden)


func _assert_exact_noop(before: Dictionary, after: Dictionary, message: String, failures: Array) -> void:
	if JSON.stringify(before) != JSON.stringify(after):
		failures.append(message)
