extends SceneTree

const CrewHeistModelScript := preload("res://scripts/core/crew_heist_model.gd")


func _initialize() -> void:
	var failures: Array = []
	var locked_config := JSON.stringify(CrewHeistModelScript.config())
	_check_both_plans(failures)
	_check_decision_boundaries(failures)
	_check_ladder_and_aftermath(failures)
	if JSON.stringify(CrewHeistModelScript.config()) != locked_config: failures.append("Heist surface scaffold mutated locked heist data or values.")
	if failures.is_empty():
		print("world06_6 heist surface scaffold passed plans=2 authority=proposal_only")
		quit(0)
		return
	for failure in failures: push_error(str(failure))
	quit(1)


func _check_both_plans(failures: Array) -> void:
	for plan_id in CrewHeistModelScript.PLAN_IDS:
		var surface := CrewHeistModelScript.plan_surface(plan_id)
		if surface.is_empty() or (surface.get("phases", []) as Array).size() < 4 or (surface.get("exits", []) as Array).size() != 2:
			failures.append("Heist surface scaffold omitted phases or exits for %s." % plan_id)
	var count := CrewHeistModelScript.plan_surface("the_count")
	var whale := CrewHeistModelScript.plan_surface("the_whale_game")
	if _decision_ids(count) != ["go", "distraction", "exit"]: failures.append("The Count lost its three authored interleaved decisions.")
	if _phase_places(whale) != ["crew_planning_table", "grand_casino_high_limit", "grand_casino_cage", "grand_casino_front_door", "exit"]: failures.append("The Whale Game lost its table/cage/interview/front-door places.")
	var identity := CrewHeistModelScript.objective_evidence_requirements("the_count", "identity")
	var invitational := CrewHeistModelScript.objective_evidence_requirements("the_whale_game", "invitational")
	if str(identity.get("source_kind", "")) != "settled_game_session" or not bool(identity.get("distinct_session_ids", false)):
		failures.append("The Count scaffold permits fixture-only or non-distinct identity progress.")
	if invitational.get("game_sequence", []) != ["craps", "blackjack", "craps", "baccarat", "blackjack"] or not bool(invitational.get("requires_game_specific_settlement", false)):
		failures.append("The Whale Game scaffold permits generic rounds in place of its exact settled sequence.")
	if not CrewHeistModelScript.sequence_mount_marker({}).is_empty(): failures.append("Empty/non-heist mount marker was not an exact no-op.")


func _check_decision_boundaries(failures: Array) -> void:
	var state := CrewHeistModelScript.begin("the_count", 4)
	state["status"] = "play"
	for round_index in range(3):
		state["play"]["round"] = round_index
		var public_state := CrewHeistModelScript.phase_public_state(state)
		var expected := ["go", "distraction", "exit"][round_index]
		if public_state.get("available_decisions", []) != [expected]: failures.append("The Count exposed decisions outside authored round %d." % round_index)
		var before := JSON.stringify(state)
		if not CrewHeistModelScript.decision_proposal(state, expected, {"source_kind": "fixture", "round": round_index}).is_empty():
			failures.append("Heist decision accepted fixture-shaped evidence at round %d." % round_index)
		var evidence := {"source_kind": "settled_game_session", "session_id": "session:%d" % round_index, "settled": true, "game_id": "blackjack", "environment_archetype_id": "grand_casino", "round": round_index}
		var proposal := CrewHeistModelScript.decision_proposal(state, expected, evidence)
		if proposal.is_empty() or bool(proposal.get("authoritative", true)) or bool(proposal.get("can_mutate", true)) or str(proposal.get("authority_gap", "")) != CrewHeistModelScript.SURFACE_AUTHORITY_GAP:
			failures.append("Heist decision did not remain a non-authoritative host proposal.")
		if JSON.stringify(state) != before: failures.append("Heist decision proposal mutated canonical phase state.")
		_assert_no_hidden(CrewHeistModelScript.phase_public_state(state), failures)


func _check_ladder_and_aftermath(failures: Array) -> void:
	var ladder := CrewHeistModelScript.outcome_ladder_public()
	var expected := [
		{"id": "clean_sweep", "label": "Clean Sweep", "score_min": 80}, {"id": "out_hot", "label": "Out Hot", "score_min": 55},
		{"id": "somebody_got_pinched", "label": "Somebody Got Pinched", "score_min": 0}, {"id": "closed", "label": "Night Closed", "score_min": 0},
	]
	if ladder != expected: failures.append("Heist public ladder changed an exact landed rung, label or threshold.")
	if CrewHeistModelScript.ladder(80, true) != "clean_sweep" or CrewHeistModelScript.ladder(79, true) != "out_hot" or CrewHeistModelScript.ladder(79, false) != "somebody_got_pinched":
		failures.append("Heist deterministic ladder boundary math changed.")
	for plan_id in CrewHeistModelScript.PLAN_IDS:
		var mechanical := CrewHeistModelScript.aftermath_public(plan_id, "somebody_got_pinched", "mechanical")
		var broken := CrewHeistModelScript.aftermath_public(plan_id, "closed", "plan_broke")
		if mechanical.is_empty() or broken.is_empty() or str(mechanical.get("aftermath_beat", "")) == str(broken.get("aftermath_beat", "")):
			failures.append("Heist scaffold did not distinguish mechanical and plan-break aftermath for %s." % plan_id)
		for row in [mechanical, broken]:
			if bool(row.get("authoritative", true)) or bool(row.get("can_mutate", true)): failures.append("Heist aftermath invented host authority.")
	_assert_no_hidden({"ladder": ladder, "count": CrewHeistModelScript.plan_surface("the_count"), "whale": CrewHeistModelScript.plan_surface("the_whale_game")}, failures)


func _assert_no_hidden(value: Variant, failures: Array) -> void:
	var text := JSON.stringify(value).to_lower()
	for forbidden in ["traitor", "grievance", "eligible_member", "resolution_state", "clue_weight"]:
		if text.contains(forbidden): failures.append("Heist player-safe scaffold leaked hidden token %s." % forbidden)


func _decision_ids(surface: Dictionary) -> Array:
	var result: Array = []
	for decision_value in surface.get("decisions", []): result.append(str((decision_value as Dictionary).get("id", "")))
	return result


func _phase_places(surface: Dictionary) -> Array:
	var result: Array = []
	for phase_value in surface.get("phases", []): result.append(str((phase_value as Dictionary).get("place", "")))
	return result
