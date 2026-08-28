extends SceneTree

const CrewHeistModelScript := preload("res://scripts/core/crew_heist_model.gd")
const FORBIDDEN := ["traitor", "betray", "eligible", "grievance", "weight", "resolution", "clue", "suspect", "loyal", "guilt", "active_member", "member_pool"]


func _initialize() -> void:
	var failures: Array = []
	var locked_config := JSON.stringify(CrewHeistModelScript.config())
	_check_surfaces(failures)
	_check_evidence_and_boundaries(failures)
	_check_dependencies_and_mount(failures)
	_check_ladder_and_failures(failures)
	if JSON.stringify(CrewHeistModelScript.config()) != locked_config: failures.append("Heist surface work mutated locked data, math, RNG, or hidden state.")
	if failures.is_empty():
		print("world06_6 heist surface contract passed plans=2 phases=11 dependencies=6 ladder=4 authority=proposal_only")
		quit(0); return
	for failure in failures: push_error(str(failure))
	quit(1)


func _check_surfaces(failures: Array) -> void:
	var count := CrewHeistModelScript.plan_surface("the_count")
	var whale := CrewHeistModelScript.plan_surface("the_whale_game")
	if _phase_places(count) != ["planning_table", "grand_casino_floor", "count_table", "street_exit", "exit"]: failures.append("The Count lost exact plan/setup/play/getaway/aftermath places.")
	if _phase_places(whale) != ["planning_table", "private_invitational", "private_invitational", "casino_cage", "front_door", "exit"]: failures.append("The Whale Game lost exact plan/setup/play/cage-interview/getaway/aftermath places.")
	if _decision_ids(count) != ["go", "distraction", "exit"] or _decision_ids(whale) != ["show_receipt", "cut_short"]: failures.append("Heist decision inventory changed.")
	_assert_public({"count": count, "whale": whale}, failures)
	if not CrewHeistModelScript.plan_surface("not_a_plan").is_empty(): failures.append("Unknown plan surface was not a no-op.")


func _check_evidence_and_boundaries(failures: Array) -> void:
	var required := {
		"the_count": ["identity", "schedule", "swap_cart", "guard_marker"],
		"the_whale_game": ["vouch", "rig", "name", "drunk", "invitational"],
	}
	for plan_id in required:
		for objective_id in required[plan_id]:
			var requirement := CrewHeistModelScript.objective_evidence_requirements(plan_id, objective_id)
			if requirement.is_empty() or bool(requirement.get("authoritative", true)) or bool(requirement.get("can_mutate", true)) or str(requirement.get("authority_gap", "")) != CrewHeistModelScript.SURFACE_AUTHORITY_GAP: failures.append("%s/%s evidence requirement invented host authority." % [plan_id, objective_id])
	var identity := CrewHeistModelScript.objective_evidence_requirements("the_count", "identity")
	if str(identity.get("source_kind", "")) != "settled_game_session" or not bool(identity.get("distinct_session_ids", false)) or str(identity.get("game_id", "")) != "blackjack" or not bool(identity.get("requires_settled_result", false)): failures.append("The Count permits fixture, generic, or repeated-session identity evidence.")
	var invitational := CrewHeistModelScript.objective_evidence_requirements("the_whale_game", "invitational")
	if invitational.get("game_sequence", []) != ["craps", "blackjack", "craps", "baccarat", "blackjack"] or not bool(invitational.get("requires_game_specific_settlement", false)) or str(invitational.get("lifelines_source", "")) != "finite_coordinated_play_state": failures.append("The Whale Game permits generic rounds or synthetic lifelines.")
	var state := CrewHeistModelScript.begin("the_count", 4); state["status"] = "play"
	for round_index in range(3):
		state["play"]["round"] = round_index
		var expected: String = str(["go", "distraction", "exit"][round_index])
		if CrewHeistModelScript.phase_public_state(state).get("available_decisions", []) != [expected]: failures.append("The Count exposed a decision outside round %d." % round_index)
		var before := JSON.stringify(state)
		if not CrewHeistModelScript.decision_proposal(state, expected, {"source_kind": "fixture", "round": round_index}).is_empty(): failures.append("Decision accepted fixture-shaped evidence at round %d." % round_index)
		var evidence := {"source_kind": "settled_game_session", "session_id": "session:%d" % round_index, "settled": true, "game_id": "blackjack", "environment_archetype_id": "grand_casino", "round": round_index}
		var proposal := CrewHeistModelScript.decision_proposal(state, expected, evidence)
		if proposal.is_empty() or bool(proposal.get("authoritative", true)) or bool(proposal.get("can_mutate", true)) or str(proposal.get("authority_gap", "")) != CrewHeistModelScript.SURFACE_AUTHORITY_GAP: failures.append("Decision was not an explicit host-dependent proposal.")
		if JSON.stringify(state) != before: failures.append("Decision proposal mutated canonical heist state.")
		_assert_public(proposal, failures)
	var whale := CrewHeistModelScript.begin("the_whale_game", 4); whale["status"] = "interview"
	if CrewHeistModelScript.phase_public_state(whale).get("available_decisions", []) != ["show_receipt", "cut_short"]: failures.append("Whale cage interview decisions were not exposed at the interview boundary.")


func _check_dependencies_and_mount(failures: Array) -> void:
	var expected := {
		"the_count": ["dock", "corridor"],
		"the_whale_game": ["cage", "interview", "clean_walk", "hot_chase"],
	}
	for plan_id in expected:
		for dependency_id in expected[plan_id]:
			var proposal := CrewHeistModelScript.dependency_proposal(plan_id, dependency_id)
			if proposal.is_empty() or bool(proposal.get("authoritative", true)) or bool(proposal.get("can_mutate", true)) or str(proposal.get("authority_gap", "")) != CrewHeistModelScript.SURFACE_AUTHORITY_GAP or (proposal.get("requires", []) as Array).is_empty(): failures.append("%s/%s dependency did not remain an explicit host proposal." % [plan_id, dependency_id])
			_assert_public(proposal, failures)
	if not CrewHeistModelScript.dependency_proposal("the_count", "cage").is_empty(): failures.append("Cross-plan dependency proposal did not fail closed.")
	if not CrewHeistModelScript.sequence_mount_marker({}).is_empty(): failures.append("Empty/non-heist mount marker was not an exact no-op.")
	var state := CrewHeistModelScript.begin("the_count", 2)
	var before := JSON.stringify(state)
	var marker := CrewHeistModelScript.sequence_mount_marker(state)
	if bool(marker.get("mounted", true)) or bool(marker.get("scan_world_nodes", true)) or bool(marker.get("authoritative", true)) or bool(marker.get("can_mutate", true)): failures.append("Mount proposal scanned, mounted, mutated, or claimed authority.")
	if JSON.stringify(state) != before: failures.append("Mount proposal mutated heist state.")


func _check_ladder_and_failures(failures: Array) -> void:
	var ladder := CrewHeistModelScript.outcome_ladder_public()
	var expected := [{"id": "clean_sweep", "label": "Clean Sweep", "score_min": 80}, {"id": "out_hot", "label": "Out Hot", "score_min": 55}, {"id": "somebody_got_pinched", "label": "Somebody Got Pinched", "score_min": 0}, {"id": "closed", "label": "Night Closed", "score_min": 0}]
	if ladder != expected: failures.append("Four-rung ladder changed an exact id, label, order, or threshold.")
	if CrewHeistModelScript.ladder(80, true) != "clean_sweep" or CrewHeistModelScript.ladder(79, true) != "out_hot" or CrewHeistModelScript.ladder(79, false) != "somebody_got_pinched": failures.append("Existing ladder math changed.")
	var beats := {}
	for plan_id in CrewHeistModelScript.PLAN_IDS:
		for cause in ["mechanical", "confrontation"]:
			var outcome := "somebody_got_pinched" if cause == "mechanical" else "closed"
			var row := CrewHeistModelScript.aftermath_public(plan_id, outcome, cause)
			var beat := str(row.get("aftermath_beat", ""))
			if row.is_empty() or beats.has(beat) or bool(row.get("authoritative", true)) or bool(row.get("can_mutate", true)): failures.append("%s/%s public failure beat was missing, duplicated, or authoritative." % [plan_id, cause])
			beats[beat] = true
			_assert_public(row, failures)
	if beats.keys().size() != 4: failures.append("Expected four distinct public failure beats.")
	_assert_public({"ladder": ladder}, failures)


func _assert_public(value: Variant, failures: Array) -> void:
	var text := JSON.stringify(value).to_lower()
	for forbidden in FORBIDDEN:
		if text.contains(forbidden): failures.append("Public heist surface leaked forbidden token %s." % forbidden)


func _decision_ids(surface: Dictionary) -> Array:
	var result: Array = []
	for value in surface.get("decisions", []): result.append(str((value as Dictionary).get("id", "")))
	return result


func _phase_places(surface: Dictionary) -> Array:
	var result: Array = []
	for value in surface.get("phases", []): result.append(str((value as Dictionary).get("place", "")))
	return result
