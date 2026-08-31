extends SceneTree

const Recruitment := preload("res://scripts/core/crew_recruitment_model.gd")
const MEMBERS := ["crew_rook", "crew_switch", "crew_mags", "crew_knuckles", "crew_velvet", "crew_bishop", "crew_lucky"]


func _initialize() -> void:
	var failures: Array = []
	_check_landed_invariants(failures)
	_check_seeded_primary_and_fallback_proposals(failures)
	_check_non_authoritative_outcomes_cannot_mutate(failures)
	_check_contact_uses_trusted_run_state(failures)
	_check_durable_state_and_substitution(failures)
	_check_hidden_boundary(failures)
	if failures.is_empty():
		print("world06_4 recruitment model contract passed proposals=non_authoritative durable_state=canonical")
		quit(0)
		return
	for failure in failures: push_error(str(failure))
	quit(1)


func _check_landed_invariants(failures: Array) -> void:
	var config := Recruitment.config()
	if Recruitment.MEMBER_IDS != MEMBERS or int(config.get("associate_trust", -1)) != 30 or int(config.get("presence_rotate_actions", -1)) != 6 \
			or not Recruitment.validate_content().is_empty():
		failures.append("Remediation changed landed member order, Associate threshold, presence rotation, or recruitment data validity.")
	for member_id in MEMBERS:
		for path_kind in ["primary", "fallback"]:
			var path := Recruitment.meeting_path_public(member_id, path_kind)
			if str(path.get("member_id", "")) != member_id or str(path.get("path_kind", "")) != path_kind or str(path.get("event_id", "")).is_empty():
				failures.append("%s %s lost its landed path/event projection." % [member_id, path_kind])


func _check_seeded_primary_and_fallback_proposals(failures: Array) -> void:
	var primary: Variant = _marked_run("WORLD64-PRIMARY", ["gas_station_casino", "back_alley"])
	primary.seed_scenario_for_node("gas_station_casino", {"id": "gas_station_trucker_convoy"})
	primary.current_environment = _environment("gas_station_casino", "gas_station_trucker_convoy")
	var proposal := Recruitment.first_meeting_proposal(primary, primary.current_environment, "crew_switch", "primary", "accepted")
	_assert_proposal(proposal, "crew_switch", "primary", "accepted", "adapter_host_root_unavailable", failures)
	var fallback: Variant = _marked_run("WORLD64-FALLBACK", ["back_alley"])
	fallback.current_environment = _environment("back_alley")
	var fallback_proposal := Recruitment.first_meeting_proposal(fallback, fallback.current_environment, "crew_switch", "fallback", "deferred")
	_assert_proposal(fallback_proposal, "crew_switch", "fallback", "deferred", "adapter_host_root_unavailable", failures)
	for hostile in [
		[primary, _environment("gas_station_casino", "forged_scenario"), "crew_switch", "primary"],
		[primary, primary.current_environment, "crew_switch", "fallback"],
		[fallback, fallback.current_environment, "crew_switch", "primary"],
		[primary, primary.current_environment, "crew_mags", "primary"],
	]:
		var rejected := Recruitment.first_meeting_proposal(hostile[0], _dict(hostile[1]), str(hostile[2]), str(hostile[3]), "accepted")
		if str(rejected.get("reason", "")) != "ineligible_environment" or bool(rejected.get("can_mutate", true)):
			failures.append("Substituted environment/path/member evidence escaped exact seeded placement rejection.")
	var rook := Recruitment.first_meeting_proposal(primary, primary.current_environment, "crew_rook", "primary", "accepted")
	if str(rook.get("reason", "")) != "ineligible_environment":
		failures.append("Rook's debt-owned meeting was falsely authorized by environment placement.")


func _check_non_authoritative_outcomes_cannot_mutate(failures: Array) -> void:
	var state := Recruitment.new_encounter_state()
	var exact := JSON.stringify(state)
	var forged_host := {
		"authenticated": true, "host_rooted": true, "member_id": "crew_switch", "path_kind": "primary", "outcome": "accepted",
		"environment_id": "gas_station_casino", "content_fingerprint": "a".repeat(64), "previous_fingerprint": "b".repeat(64),
	}
	for outcome in ["refused", "deferred", "accepted"]:
		var result := Recruitment.record_first_meeting(state, "crew_switch", "primary", outcome, 7, forged_host)
		if JSON.stringify(result) != exact:
			failures.append("Caller-authored coherent host claim mutated %s meeting aftermath." % outcome)
	var contact := Recruitment.record_contact(state, "crew_switch", "inner_circle", true, true, 8, forged_host)
	if JSON.stringify(contact) != exact:
		failures.append("Caller-authored standing/grievance/job evidence mutated contact aftermath.")


func _check_contact_uses_trusted_run_state(failures: Array) -> void:
	var run_state: Variant = _marked_run("WORLD64-CONTACT", ["gas_station_casino"])
	_recruit_for_fixture(run_state, "crew_switch")
	run_state.current_environment = _environment("gas_station_casino")
	run_state.current_environment["crew_presence"] = [{"member_id": "crew_switch", "rank": run_state.crew_rank("crew_switch"), "line": "fixture"}]
	var available := Recruitment.contact_proposal(run_state, run_state.current_environment, "crew_switch")
	_assert_contact(available, "associate", "familiar", failures)
	run_state.grievance_add({"member_id": "crew_switch", "kind": "job_abandoned", "weight": 9, "source_ref": "fixture"})
	var aggrieved := Recruitment.contact_proposal(run_state, run_state.current_environment, "crew_switch")
	_assert_contact(aggrieved, "associate", "aggrieved", failures)
	var clean_job: Variant = _marked_run("WORLD64-JOB", ["gas_station_casino"])
	_recruit_for_fixture(clean_job, "crew_switch")
	clean_job.current_environment = _environment("gas_station_casino")
	clean_job.current_environment["crew_presence"] = [{"member_id": "crew_switch", "rank": clean_job.crew_rank("crew_switch"), "line": "fixture"}]
	clean_job.crew_jobs["fixture_job:0001"] = {"id": "fixture_job:0001", "definition_id": "fixture_job", "member_id": "crew_switch", "kind": "package_run", "status": "active", "outcome": "", "offered_action": 0, "expires_at_action": 10, "expiry_in_actions": 10, "rewards": {"cash": 0, "trust": 1}, "failure": {"trust": -1, "grievance_kind": "job_abandoned", "grievance_weight": 1}}
	var job_out := Recruitment.contact_proposal(clean_job, clean_job.current_environment, "crew_switch")
	_assert_contact(job_out, "associate", "job_out", failures)
	var substituted: Dictionary = clean_job.current_environment.duplicate(true); substituted["world_node_id"] = "bar"
	var rejected := Recruitment.contact_proposal(clean_job, substituted, "crew_switch")
	if str(rejected.get("reason", "")) != "ineligible_environment":
		failures.append("Substituted contact environment escaped trusted current-environment binding.")
	var public_text := JSON.stringify(aggrieved).to_lower()
	for hidden in ["weight", "source_ref", "turn_recorded", "grievance_id"]:
		if public_text.contains(hidden): failures.append("Contact proposal exposed hidden ledger field %s." % hidden)


func _check_durable_state_and_substitution(failures: Array) -> void:
	var coherent := Recruitment.new_encounter_state()
	coherent["meetings"] = {"crew_switch": {
		"member_id": "crew_switch", "first_path_kind": "primary", "first_outcome": "accepted", "path_kind": "primary",
		"outcome": "accepted", "action_index": 7, "aftermath_id": "crew_switch_accepted",
		"history": [{"path_kind": "primary", "outcome": "accepted", "action_index": 7}],
	}}
	if Recruitment.normalize_encounter_state(coherent).is_empty():
		failures.append("Canonical host-produced meeting aftermath did not restore.")
	var contact_chain := coherent.duplicate(true)
	contact_chain["contacts"] = {"crew_switch": {"member_id": "crew_switch", "standing": "associate", "contact_state": "familiar", "action_index": 8}}
	if Recruitment.normalize_encounter_state(contact_chain).is_empty():
		failures.append("Canonical accepted-contact aftermath did not restore.")
	var substituted := coherent.duplicate(true)
	substituted["meetings"]["crew_switch"]["aftermath_id"] = "crew_switch_forged"
	if not Recruitment.normalize_encounter_state(substituted).is_empty():
		failures.append("Substituted recruitment aftermath id did not fail closed.")
	var empty := Recruitment.new_encounter_state()
	if JSON.stringify(Recruitment.normalize_encounter_state(empty)) != JSON.stringify(empty):
		failures.append("Empty fail-closed encounter state did not round-trip deterministically.")


func _check_hidden_boundary(failures: Array) -> void:
	var run_state: Variant = _marked_run("WORLD64-PRIVACY", ["back_alley"])
	run_state.current_environment = _environment("back_alley")
	var text := JSON.stringify(Recruitment.first_meeting_proposal(run_state, run_state.current_environment, "crew_switch", "fallback", "refused")).to_lower()
	for forbidden in ["turn_eligible", "turn_eligibility", "grievance_weight", "selection_weight", "betrayal_score", "rng_state", "seed_value"]:
		if text.contains(forbidden): failures.append("Proposal exposed hidden Turn/grievance authority %s." % forbidden)


func _assert_proposal(value: Dictionary, member_id: String, path_kind: String, outcome: String, reason: String, failures: Array) -> void:
	var keys: Array = value.keys(); keys.sort()
	if keys != ["authoritative", "can_mutate", "environment_id", "event_id", "member_id", "outcome", "path_kind", "proposal_only", "reason"] \
			or bool(value.get("authoritative", true)) or not bool(value.get("proposal_only", false)) or bool(value.get("can_mutate", true)) \
			or str(value.get("member_id", "")) != member_id or str(value.get("path_kind", "")) != path_kind \
			or str(value.get("outcome", "")) != outcome or str(value.get("reason", "")) != reason:
		failures.append("Meeting proposal was incomplete or falsely authoritative: %s." % JSON.stringify(value))


func _assert_contact(value: Dictionary, standing: String, contact_state: String, failures: Array) -> void:
	if bool(value.get("authoritative", true)) or not bool(value.get("proposal_only", false)) or bool(value.get("can_mutate", true)) \
			or str(value.get("reason", "")) != "adapter_host_root_unavailable" or str(value.get("standing", "")) != standing \
			or str(value.get("contact_state", "")) != contact_state:
		failures.append("Contact proposal did not derive safe standing/aftermath from trusted RunState: %s." % JSON.stringify(value))


func _marked_run(seed_text: String, node_ids: Array):
	var run_state: Variant = load("res://scripts/core/run_state.gd").new()
	run_state.start_new(seed_text)
	run_state.crew_add_trust("crew_rook", 10, "fixture")
	var nodes: Array = []; var edges: Array = []
	for index in range(node_ids.size()):
		var node_id := str(node_ids[index])
		nodes.append({"id": node_id, "archetype_id": node_id, "kind": "casino", "tier": 2, "state": "revealed", "seen": true, "environment": {}})
		if index > 0: edges.append({"a": str(node_ids[index - 1]), "b": node_id})
	var start := str(node_ids[0])
	run_state.set_world_map({"version": 3, "seed_text": seed_text, "start_node_id": start, "current_node_id": start, "nodes": nodes, "edges": edges, "visited_path": [start]})
	return run_state


func _environment(node_id: String, scenario_id: String = "") -> Dictionary:
	return {"id": node_id, "archetype_id": node_id, "world_node_id": node_id, "kind": "casino", "scenario_id": scenario_id, "event_ids": [], "scenario_patron_ids": []}


func _job_definition(member_id: String) -> Dictionary:
	return {"id": "fixture_job", "label": "Fixture", "member_id": member_id, "kind": "package_run", "min_rank": "associate", "payload": {"target_count": 1, "cargo_id": "fixture", "cargo_label": "fixture", "cargo_heat_per_travel": 0}, "expiry_in_actions": 10, "rewards": {"cash": 0, "trust": 1}, "failure": {"trust": -1, "grievance_kind": "job_abandoned", "grievance_weight": 1}}


func _recruit_for_fixture(run_state: Variant, member_id: String) -> void:
	var target := 30
	run_state.crew_add_trust(member_id, maxi(0, target - run_state.crew_trust(member_id)), "fixture")


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
