extends SceneTree

const PoliceSweepModelScript := preload("res://scripts/core/police_sweep_model.gd")


func _initialize() -> void:
	var failures: Array = []
	_check_costed_rungs(failures)
	_check_encounter_proposals(failures)
	_check_save_revisit_and_wake(failures)
	_check_ten_seed_determinism(failures)
	if failures.is_empty():
		print("world06_5 sweep model contract passed rungs=5 seeds=10 authority=proposal_only gap=host_encounter_resolution_not_verifiable_in_model")
		quit(0)
		return
	for failure in failures: push_error(str(failure))
	quit(1)


func _check_costed_rungs(failures: Array) -> void:
	var config := _encounter_config()
	var locked := JSON.stringify(config)
	var rungs := PoliceSweepModelScript.encounter_costed_rungs(config)
	var expected := [
		["pass_over", [["cash", [2, 6]], ["travel_delay", [1, 1]]]],
		["shakedown", [["cash", [10, 28]], ["travel_delay", [1, 1]]]],
		["confiscation", [["contraband", [1, 1]], ["cash", [8, 16]], ["travel_delay", [2, 2]]]],
		["travel_lock", [["travel_delay", [2, 4]], ["cash", [6, 12]]]],
		["punchline_l2_near_miss", [["travel_delay", [2, 2]], ["cash", [6, 12]]]],
	]
	if rungs.size() != expected.size(): failures.append("Sweep projection did not expose all five landed costed rungs.")
	for index in range(mini(rungs.size(), expected.size())):
		var rung: Dictionary = rungs[index]
		var expected_rung: Array = expected[index]
		if str(rung.get("outcome", "")) != str(expected_rung[0]) or not bool(rung.get("run_continues", false)):
			failures.append("Sweep rung %d changed its landed outcome or costed-continue contract." % index)
		var options: Array = rung.get("cost_options", [])
		if options.size() != (expected_rung[1] as Array).size(): failures.append("Sweep rung %s changed its number of landed cost paths." % str(expected_rung[0]))
		for option_index in range(mini(options.size(), (expected_rung[1] as Array).size())):
			var option: Dictionary = options[option_index]
			var expected_option: Array = (expected_rung[1] as Array)[option_index]
			if str(option.get("cost_kind", "")) != str(expected_option[0]) or option.get("amount_range", []) != expected_option[1]:
				failures.append("Sweep rung %s changed landed cost option %d." % [str(expected_rung[0]), option_index])
	if JSON.stringify(config) != locked: failures.append("Sweep encounter projection mutated landed encounter tuning.")


func _check_encounter_proposals(failures: Array) -> void:
	var model := _configured_model(7719)
	var claim := model.claim_encounter(str(model.status().get("current_node_id", "")))
	var cargo := {"cargo_id": "delivery:numbers_slips", "cargo_label": "Numbers bag", "contraband": true, "hidden_value": 999}
	var proposal := model.encounter_proposal(claim, cargo, ["pawn_shop", "bar", "bar"], {})
	if proposal.is_empty() or PoliceSweepModelScript.normalize_encounter_proposal(proposal).is_empty():
		failures.append("Sweep did not create an exact model-owned encounter proposal from its claimed track segment.")
		return
	var public_state := PoliceSweepModelScript.encounter_public_state(proposal)
	var cargo_public: Dictionary = public_state.get("cargo_context", {})
	if str(cargo_public.get("cargo_id", "")) != "delivery:numbers_slips" or not bool(cargo_public.get("contraband", false)) or cargo_public.has("hidden_value"):
		failures.append("Sweep encounter did not preserve player-safe delivery cargo context.")
	var intel: Dictionary = public_state.get("intel_projection", {})
	if bool(intel.get("available", true)) or str(intel.get("authority_gap", "")) != PoliceSweepModelScript.INTEL_AUTHORITY_GAP:
		failures.append("Sweep encounter did not report the exact unrepresentable intel authority gap.")
	if not PoliceSweepModelScript.encounter_action_proposal(proposal, "use_intel").is_empty():
		failures.append("Sweep encounter allowed unavailable intel to be used.")
	var observe := PoliceSweepModelScript.encounter_action_proposal(proposal, "observe_officers")
	if bool(observe.get("authoritative", true)) or bool(observe.get("can_mutate", true)) or str(observe.get("next_phase_proposal", "")) != "route_choice_proposal" or JSON.stringify(proposal) != JSON.stringify(PoliceSweepModelScript.normalize_encounter_proposal(proposal)):
		failures.append("Sweep observation was not a non-mutating route-choice proposal.")
	var observer_outputs := [
		model.encounter_proposal(claim, cargo, ["pawn_shop", "bar", "bar"], true),
		model.encounter_proposal(claim, cargo, ["pawn_shop", "bar", "bar"], {"sweep_intel": true}),
		model.encounter_proposal(claim, cargo, ["pawn_shop", "bar", "bar"], {"sweep_intel": {"host_signed": true}, "authority": "substituted"}),
	]
	for observer_output in observer_outputs:
		if JSON.stringify(observer_output) != JSON.stringify(proposal): failures.append("Otherwise-identical observer changed proposal bytes from caller-authored capability input.")
	var status_without := model.intel_status({})
	for hostile_capability in [true, {"sweep_intel": true}, {"capability": "recomputed", "sweep_intel": {"available": true}}]:
		if JSON.stringify(model.intel_status(hostile_capability)) != JSON.stringify(status_without): failures.append("Caller-authored capability changed public intel behavior or bytes.")
	var before_report := JSON.stringify(model.snapshot())
	if JSON.stringify(model.report_intel_at_boundary({"sweep_intel": true})) != JSON.stringify(status_without) or JSON.stringify(model.snapshot()) != before_report:
		failures.append("Caller-authored intel report mutated model state or exposed track facts.")
	var sighting := model.record_personal_sighting("direct")
	for hostile_capability in [true, {"sweep_intel": true}, {"sweep_intel": {"host_signed": true}}]:
		if JSON.stringify(model.map_marker(hostile_capability)) != JSON.stringify(sighting): failures.append("Caller-authored capability changed personal-marker observer bytes.")
	var marker_text := JSON.stringify(sighting).to_lower()
	for hidden in ["node_id", "heading", "segment", "action", "stale_actions"]:
		if marker_text.contains(hidden): failures.append("Personal marker leaked unauthenticated %s intel." % hidden)
	var before_model := JSON.stringify(model.snapshot())
	for outcome_value in PoliceSweepModelScript.ENCOUNTER_OUTCOMES:
		var outcome := str(outcome_value)
		var rung := _rung_by_outcome(proposal.get("costed_rungs", []), outcome)
		for option_value in rung.get("cost_options", []):
			var option: Dictionary = option_value
			var range: Array = option.get("amount_range", [])
			var aftermath := PoliceSweepModelScript.aftermath_proposal(proposal, outcome, str(option.get("cost_kind", "")), int(range[0]))
			if aftermath.is_empty() or not bool(aftermath.get("run_continues", false)) or bool(aftermath.get("authoritative", true)) or bool(aftermath.get("can_mutate", true)):
				failures.append("Sweep aftermath %s/%s was not a non-mutating costed continue proposal." % [outcome, str(option.get("cost_kind", ""))])
	if str(PoliceSweepModelScript.aftermath_proposal(proposal, "confiscation", "contraband", 1).get("cargo_consequence", "")) != "host_may_confiscate_delivery":
		failures.append("Sweep confiscation proposal did not carry the delivery-cargo consequence to the host boundary.")
	if JSON.stringify(model.snapshot()) != before_model:
		failures.append("Sweep presentation proposals mutated the authoritative track or encounter claim state.")
	var hostile: Dictionary = proposal.duplicate(true)
	hostile["host_committed"] = true
	if not PoliceSweepModelScript.normalize_encounter_proposal(hostile).is_empty(): failures.append("Sweep proposal accepted an invented host authority key.")
	var forged_identity: Dictionary = proposal.duplicate(true)
	forged_identity["encounter_id"] = JSON.stringify(proposal).sha256_text()
	if not PoliceSweepModelScript.normalize_encounter_proposal(forged_identity).is_empty(): failures.append("Sweep proposal treated a recomputed self-identity as authority.")
	var forged_track: Dictionary = proposal.duplicate(true)
	forged_track["encounter_id"] = JSON.stringify(proposal).sha256_text()
	forged_track["current_node_id"] = str(model.status().get("current_node_id", ""))
	forged_track["heading_node_id"] = str(model.status().get("heading_node_id", ""))
	forged_track["next_move_action"] = int(model.status().get("next_move_action", -1))
	if not PoliceSweepModelScript.normalize_encounter_proposal(forged_track).is_empty(): failures.append("Sweep proposal accepted recomputed identity plus substituted live track facts.")
	for key in ["positions", "costed_rungs", "authority_gap", "intel_projection"]:
		var tampered: Dictionary = proposal.duplicate(true)
		match key:
			"positions": (tampered[key] as Dictionary)["officers"] = "caller_claims_clear"
			"costed_rungs": ((tampered[key] as Array)[0] as Dictionary)["run_continues"] = false
			"authority_gap": tampered[key] = "caller_says_committed"
			"intel_projection": tampered[key] = {"available": true, "authority_gap": "caller_says_capable"}
		if not PoliceSweepModelScript.normalize_encounter_proposal(tampered).is_empty(): failures.append("Sweep proposal accepted substituted %s state." % key)
	var public_text := JSON.stringify(public_state).to_lower()
	for hidden in ["current_node_id", "previous_node_id", "heading_node_id", "next_move_action", "start_action", "end_action", "action_index", "segment_index", "encounter_seed", "encounter_id", "pressure", "turn", "heist", "grievance_weight", "traitor", "hidden_value"]:
		if public_text.contains(hidden): failures.append("Sweep player-safe encounter projection leaked %s." % hidden)


func _check_save_revisit_and_wake(failures: Array) -> void:
	var model := _configured_model(4021)
	var claim := model.claim_encounter(str(model.status().get("current_node_id", "")))
	var proposal := model.encounter_proposal(claim, {"cargo_id": "delivery:crew_package", "cargo_label": "Crew package", "contraband": false}, ["pawn_shop"], {"sweep_intel": true})
	var restored_proposal := PoliceSweepModelScript.normalize_encounter_proposal(JSON.parse_string(JSON.stringify(proposal)))
	if JSON.stringify(restored_proposal) != JSON.stringify(proposal): failures.append("Sweep encounter proposal did not survive exact save/load normalization.")
	var snapshot := model.snapshot()
	var restored := PoliceSweepModelScript.new()
	if not restored.restore(snapshot, 4021, _sweep_config()): failures.append("Sweep track did not restore mid-encounter.")
	restored.configure_world(_map_fixture(), _happening_fixture(), _sweep_config(), int(claim.get("action_index", 0)))
	var revisited := restored.encounter_proposal(claim, {"cargo_id": "delivery:crew_package", "cargo_label": "Crew package", "contraband": false}, ["pawn_shop"], {"sweep_intel": true})
	if JSON.stringify(revisited) != JSON.stringify(proposal): failures.append("Sweep revisit changed or replayed its deterministic encounter proposal.")
	var departed_node := str((model.segments[0] as Dictionary).get("node_id", ""))
	var departure_action := int((model.segments[0] as Dictionary).get("end_action", 0))
	model.advance_to(departure_action)
	var wake := model.swept_window_aftermath(departed_node)
	if int(wake.get("security_strictness_band_delta", 0)) != -1 or not bool(wake.get("cheat_window_open", false)) or int(wake.get("pusher_alarm_tolerance_band_delta", 0)) != 1 or str(wake.get("officer_presence", "")) != "departed":
		failures.append("Sweep node aftermath changed the landed wake or omitted visible departure cues.")
	var wake_restored := PoliceSweepModelScript.new()
	if not wake_restored.restore(model.snapshot(), 4021, _sweep_config()): failures.append("Sweep wake snapshot did not restore.")
	wake_restored.configure_world(_map_fixture(), _happening_fixture(), _sweep_config(), departure_action)
	if JSON.stringify(wake_restored.swept_window_aftermath(departed_node)) != JSON.stringify(wake): failures.append("Sweep wake changed on node revisit after save/load.")
	wake_restored.advance_to(departure_action + int(_sweep_config().get("swept_window_actions", 0)))
	if not wake_restored.swept_window_aftermath(departed_node).is_empty(): failures.append("Sweep wake remained visible after its landed expiry window.")


func _check_ten_seed_determinism(failures: Array) -> void:
	for seed_value in range(10):
		var first := _configured_model(9000 + seed_value)
		var second := _configured_model(9000 + seed_value)
		var first_claim := first.claim_encounter(str(first.status().get("current_node_id", "")))
		var second_claim := second.claim_encounter(str(second.status().get("current_node_id", "")))
		var first_proposal := first.encounter_proposal(first_claim, {}, ["pawn_shop", "bar"], {"sweep_intel": true})
		var second_proposal := second.encounter_proposal(second_claim, {}, ["pawn_shop", "bar"], {"sweep_intel": true})
		if JSON.stringify(first.segments) != JSON.stringify(second.segments) or JSON.stringify(first_proposal) != JSON.stringify(second_proposal):
			failures.append("Sweep encounter proposal was not deterministic at seed %d." % seed_value)


func _configured_model(seed_value: int) -> PoliceSweepModel:
	var model := PoliceSweepModelScript.new()
	model.reset(seed_value, _sweep_config())
	model.configure_world(_map_fixture(), _happening_fixture(), _sweep_config(), 0)
	return model


func _rung_by_outcome(rungs: Array, outcome: String) -> Dictionary:
	for rung_value in rungs:
		if str((rung_value as Dictionary).get("outcome", "")) == outcome: return rung_value as Dictionary
	return {}


func _happening_fixture() -> Dictionary:
	return {"start_action": 0, "end_action": 12}


func _sweep_config() -> Dictionary:
	return {"dwell_actions": [2, 2], "swept_window_actions": 3, "adjacent_sighting_chance_percent": 100, "encounter": _encounter_config()}


func _encounter_config() -> Dictionary:
	return {
		"heat_bands": [{"max": 24, "points": 0}, {"max": 49, "points": 2}, {"max": 74, "points": 4}, {"max": 100, "points": 6}],
		"contraband_points_each": 2, "street_debt_points_each": 1, "pass_over_max_score": 1, "shakedown_max_score": 4, "confiscation_max_score": 7,
		"pass_over_fee": [2, 6], "pass_over_fallback_lock_actions": 1, "shakedown_fee": [10, 28], "shakedown_fallback_lock_actions": 1,
		"empty_confiscation_fee": [8, 16], "empty_confiscation_fallback_lock_actions": 2, "travel_lock_actions": [2, 4], "occupied_lock_fine": [6, 12],
		"punchline_l2_heat_threshold": 75, "punchline_near_miss_lock_actions": 2,
	}


func _map_fixture() -> Dictionary:
	return {
		"nodes": [
			{"id": "back_alley", "kind": "street", "tier": 1}, {"id": "pawn_shop", "kind": "shop", "tier": 2},
			{"id": "bar", "kind": "casino", "tier": 1}, {"id": "small_underground_casino", "kind": "casino", "tier": 2}, {"id": "grand_casino", "kind": "boss", "tier": 3},
		],
		"edges": [{"a": "back_alley", "b": "pawn_shop"}, {"a": "pawn_shop", "b": "bar"}, {"a": "bar", "b": "small_underground_casino"}, {"a": "small_underground_casino", "b": "grand_casino"}],
	}
