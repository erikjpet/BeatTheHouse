class_name CrewHeistModel
extends RefCounted

# Deterministic, boundary-driven state model for the two launch heists.

const CONFIG_PATH := "res://data/crew/heist.json"
const CrewTurnModelScript := preload("res://scripts/core/crew_turn_model.gd")
const SCHEMA_VERSION := 1
const SURFACE_SCHEMA_VERSION := 1
const SURFACE_AUTHORITY_GAP := "host_heist_evidence_not_verifiable_in_model"
const PLAN_COUNT := "the_count"
const PLAN_WHALE := "the_whale_game"
const PLAN_IDS := [PLAN_COUNT, PLAN_WHALE]
const STATUS_LOCKED := "locked"
const STATUS_SETUP := "setup"
const STATUS_PLAY := "play"
const STATUS_INTERVIEW := "interview"
const STATUS_GETAWAY := "getaway"
const STATUS_COMPLETED := "completed"
const STATUS_ABORTED := "aborted"
const STATUSES := [STATUS_LOCKED, STATUS_SETUP, STATUS_PLAY, STATUS_INTERVIEW, STATUS_GETAWAY, STATUS_COMPLETED, STATUS_ABORTED]

static var _config_cache: Dictionary = {}


static func config() -> Dictionary:
	if _config_cache.is_empty():
		var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_ARRAY and not (parsed as Array).is_empty() and typeof((parsed as Array)[0]) == TYPE_DICTIONARY:
				_config_cache = ((parsed as Array)[0] as Dictionary).duplicate(true)
	return _config_cache.duplicate(true)


static func plan(plan_id: String) -> Dictionary:
	for value in config().get("plans", []):
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == plan_id:
			return (value as Dictionary).duplicate(true)
	return {}


static func empty_state() -> Dictionary:
	return {}


static func begin(plan_id: String, action_index: int) -> Dictionary:
	if not PLAN_IDS.has(plan_id) or plan(plan_id).is_empty():
		return {}
	return normalize_state({
		"schema_version": SCHEMA_VERSION,
		"plan_id": plan_id,
		"status": STATUS_SETUP,
		"locked_action": maxi(0, action_index),
		"setup": {},
		"play": {"round": 0, "score": 100, "decisions": {}, "hazards": [], "lifelines_used": []},
		"getaway": {},
		"outcome": "",
		"payout": 0,
		"r": {"v": 1, "s": "0"},
		"x": CrewTurnModelScript.empty_state(),
	})


static func normalize_state(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).is_empty():
		return {}
	var source: Dictionary = value
	var plan_id := str(source.get("plan_id", ""))
	if not PLAN_IDS.has(plan_id):
		return {}
	var status := str(source.get("status", STATUS_SETUP))
	if not STATUSES.has(status):
		status = STATUS_ABORTED
	var result := {
		"schema_version": SCHEMA_VERSION,
		"plan_id": plan_id,
		"status": status,
		"locked_action": maxi(0, int(source.get("locked_action", 0))),
		"setup": _copy_dict(source.get("setup", {})),
		"play": _copy_dict(source.get("play", {})),
		"getaway": _copy_dict(source.get("getaway", {})),
		"outcome": str(source.get("outcome", "")),
		"payout": maxi(0, int(source.get("payout", 0))),
		"r": _copy_dict(source.get("r", {"v": 1, "s": "0"})),
		"x": CrewTurnModelScript.normalize_state(source.get("x", {}), ["crew_rook", "crew_velvet", "crew_knuckles", "crew_switch", "crew_mags", "crew_bishop", "crew_lucky"]),
	}
	if source.has("abort"):
		result["abort"] = _copy_dict(source.get("abort", {}))
	if source.has("interview"):
		result["interview"] = _copy_dict(source.get("interview", {}))
	return result


static func setup_complete(state_value: Variant) -> bool:
	var state := normalize_state(state_value)
	if state.is_empty():
		return false
	var setup := _copy_dict(state.get("setup", {}))
	if str(state.get("plan_id", "")) == PLAN_COUNT:
		return bool(setup.get("identity", false)) and bool(setup.get("schedule", false)) and bool(setup.get("swap_cart", false))
	return bool(setup.get("vouch", false)) and bool(setup.get("rig", false)) and bool(setup.get("name", false)) and bool(setup.get("drunk", false))


static func ladder(score: int, getaway_success: bool, made: bool = false, bust: bool = false) -> String:
	var adjusted := clampi(score, 0, 100)
	if not getaway_success:
		adjusted -= 25
	if made:
		adjusted -= 25
	if bust:
		adjusted -= 20
	if adjusted >= 80:
		return "clean_sweep"
	if adjusted >= 55:
		return "out_hot"
	return "somebody_got_pinched"


static func payout_for(state_value: Variant, outcome: String) -> int:
	var state := normalize_state(state_value)
	var definition := plan(str(state.get("plan_id", "")))
	var tuning := _copy_dict(definition.get("payout", {}))
	if str(state.get("plan_id", "")) == PLAN_COUNT:
		var value := int(tuning.get("base", 0))
		if outcome == "clean_sweep":
			value += int(tuning.get("clean_bonus", 0))
		elif outcome == "somebody_got_pinched":
			value -= int(tuning.get("hot_penalty", 0))
		return maxi(0, value)
	var play := _copy_dict(state.get("play", {}))
	return clampi(int(play.get("pot", tuning.get("minimum", 0))), int(tuning.get("minimum", 0)), int(tuning.get("maximum", 0)))


static func ending_line(plan_id: String, outcome: String) -> String:
	return str(_copy_dict(_copy_dict(config().get("ending_copy", {})).get(plan_id, {})).get(outcome, "The crew leaves before the room can name what happened."))


static func plan_surface(plan_id: String) -> Dictionary:
	if not PLAN_IDS.has(plan_id) or plan(plan_id).is_empty(): return {}
	if plan_id == PLAN_COUNT:
		var decision_rounds := _copy_dict(_copy_dict(plan(PLAN_COUNT).get("play", {})).get("decision_rounds", {}))
		return {
			"plan_id": PLAN_COUNT, "label": "The Count", "phases": [
				_phase("plan", "planning_table", ["review_plan"]),
				_phase("setup", "grand_casino_floor", ["identity", "schedule", "swap_cart"]),
				_phase("play", "count_table", ["hold_boring_blackjack_session"]),
				_phase("getaway", "street_exit", ["move_count_cart"]),
				_phase("aftermath", "exit", ["leave_the_count"]),
			],
			"decisions": [
				_decision("go", "play", int(decision_rounds.get("go", -1)), "count_table", ["call_early", "hold"]),
				_decision("distraction", "play", int(decision_rounds.get("distraction", -1)), "count_table", ["cause_incident", "stay_quiet"]),
				_decision("exit", "play", int(decision_rounds.get("exit", -1)), "count_cart", ["dock", "corridor"]),
			],
			"exits": [
				dependency_proposal(PLAN_COUNT, "dock"), dependency_proposal(PLAN_COUNT, "corridor"),
			],
		}
	return {
		"plan_id": PLAN_WHALE, "label": "The Whale Game", "phases": [
			_phase("plan", "planning_table", ["review_plan"]),
			_phase("setup", "private_invitational", ["vouch", "rig", "name", "drunk"]),
			_phase("play", "private_invitational", ["complete_mixed_invitational"]),
			_phase("interview", "casino_cage", ["cash_out", "answer_cage_interview"]),
			_phase("getaway", "front_door", ["leave_with_receipt"]),
			_phase("aftermath", "exit", ["leave_the_whale_game"]),
		],
		"decisions": [
			_decision("show_receipt", "interview", -1, "grand_casino_cage", ["show_receipt"]),
			_decision("cut_short", "interview", -1, "grand_casino_cage", ["cut_short"]),
		],
		"exits": [
			dependency_proposal(PLAN_WHALE, "clean_walk"), dependency_proposal(PLAN_WHALE, "hot_chase"),
		],
	}


static func dependency_proposal(plan_id: String, dependency_id: String) -> Dictionary:
	var proposals := {
		"the_count:dock": {"id": "dock", "place": "loading_dock", "requires": ["host_route_open", "host_shared_chase"], "public_verbs": ["arrive", "load", "board", "leave"]},
		"the_count:corridor": {"id": "corridor", "place": "service_corridor", "requires": ["host_window_heat_record", "host_guard_marker_record", "host_shared_chase"], "public_verbs": ["arrive", "guide", "carry", "leave"]},
		"the_whale_game:cage": {"id": "cage", "place": "casino_cage", "requires": ["host_chip_flow", "host_cage_receipt"], "public_verbs": ["arrive", "cash_out", "present_receipt"]},
		"the_whale_game:interview": {"id": "interview", "place": "interview_room", "requires": ["host_cage_receipt", "host_interview_result"], "public_verbs": ["arrive", "listen", "answer", "leave"]},
		"the_whale_game:clean_walk": {"id": "clean_walk", "place": "front_door", "requires": ["host_cage_receipt", "host_clean_score", "host_zero_pursuit"], "public_verbs": ["arrive", "present_receipt", "walk", "leave"]},
		"the_whale_game:hot_chase": {"id": "hot_chase", "place": "street_exit", "requires": ["host_interview_result", "host_shared_chase"], "public_verbs": ["arrive", "run", "board", "escape"]},
	}
	var proposal := _copy_dict(proposals.get("%s:%s" % [plan_id, dependency_id], {}))
	if proposal.is_empty(): return {}
	proposal.merge({"authoritative": false, "can_mutate": false, "authority_gap": SURFACE_AUTHORITY_GAP})
	return proposal


static func objective_evidence_requirements(plan_id: String, objective_id: String) -> Dictionary:
	var requirements := {
		"the_count:identity": {"source_kind": "settled_game_session", "distinct_session_ids": true, "game_id": "blackjack", "venue_role": "grand_casino", "requires_settled_result": true},
		"the_count:schedule": {"source_kind": "world_hold_completion", "place_role": "grand_casino_cage", "requires_action_boundaries": true},
		"the_count:swap_cart": {"source_kind": "delivery_resolution", "destination_role": "loading_dock", "requires_delivered_cargo": true},
		"the_count:guard_marker": {"source_kind": "debt_court_settlement", "optional": true},
		"the_whale_game:vouch": {"source_kind": "scenario_table_settlement", "requires_authored_whale_table": true, "requires_deliberate_loss": true},
		"the_whale_game:rig": {"source_kind": "inventory_and_training", "component_item": "false_bottom_cup", "training_flag": "craps_setting_trained"},
		"the_whale_game:name": {"source_kind": "venue_spend_witness", "requires_real_spend": true, "requires_distinct_sightings": true},
		"the_whale_game:drunk": {"source_kind": "automatic_plan_beat"},
		"the_whale_game:invitational": {"source_kind": "settled_game_sequence", "game_sequence": ["craps", "blackjack", "craps", "baccarat", "blackjack"], "requires_game_specific_settlement": true, "lifelines_source": "finite_coordinated_play_state"},
	}
	var proposal := _copy_dict(requirements.get("%s:%s" % [plan_id, objective_id], {}))
	if proposal.is_empty(): return {}
	proposal.merge({"authoritative": false, "can_mutate": false, "authority_gap": SURFACE_AUTHORITY_GAP})
	return proposal


static func phase_public_state(state_value: Variant) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty(): return {}
	var plan_id := str(state.get("plan_id", ""))
	var status := str(state.get("status", ""))
	var surface := plan_surface(plan_id)
	var phase_id := "aftermath" if status in [STATUS_COMPLETED, STATUS_ABORTED] else status
	var phase := _phase_by_id(surface.get("phases", []), phase_id)
	if phase.is_empty(): return {}
	return {
		"schema_version": SURFACE_SCHEMA_VERSION, "plan_id": plan_id, "phase": phase_id, "place": str(phase.get("place", "")),
		"objectives": (phase.get("objectives", []) as Array).duplicate(), "available_decisions": _available_decisions(state, surface),
		"authoritative": false, "can_mutate": false, "authority_gap": SURFACE_AUTHORITY_GAP,
	}


static func decision_proposal(state_value: Variant, decision_id: String, evidence: Dictionary) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty(): return {}
	var surface := plan_surface(str(state.get("plan_id", "")))
	var available := _available_decisions(state, surface)
	if not available.has(decision_id) or not _production_decision_evidence_valid(state, decision_id, evidence): return {}
	return {
		"plan_id": str(state.get("plan_id", "")), "decision_id": decision_id, "phase": str(state.get("status", "")), "evidence_kind": str(evidence.get("source_kind", "")),
		"next_step_proposal": "host_apply_decision", "authoritative": false, "can_mutate": false, "authority_gap": SURFACE_AUTHORITY_GAP,
	}


static func sequence_mount_marker(state_value: Variant) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty(): return {}
	return {
		"schema_version": SURFACE_SCHEMA_VERSION, "plan_id": str(state.get("plan_id", "")), "registration_marker_required": true,
		"mounted": false, "scan_world_nodes": false, "authoritative": false, "can_mutate": false, "authority_gap": SURFACE_AUTHORITY_GAP,
	}


static func outcome_ladder_public() -> Array:
	var result: Array = []
	for outcome_value in config().get("outcomes", []):
		var outcome := _copy_dict(outcome_value)
		result.append({"id": str(outcome.get("id", "")), "label": str(outcome.get("label", "")), "score_min": int(outcome.get("score_min", 0))})
	return result


static func aftermath_public(plan_id: String, outcome: String, cause: String) -> Dictionary:
	if not PLAN_IDS.has(plan_id) or outcome not in ["somebody_got_pinched", "closed"] or cause not in ["mechanical", "confrontation"]: return {}
	var beat := "identity_shortfall" if plan_id == PLAN_COUNT and cause == "mechanical" else "corridor_closes" if plan_id == PLAN_COUNT else "table_breaks" if cause == "mechanical" else "rig_is_read"
	var semantics := _copy_dict(plan(plan_id).get("semantics", {}))
	var descriptor := _copy_dict(_copy_dict(semantics.get("failure_beats", {})).get(beat, {}))
	if descriptor.is_empty(): return {}
	return {
		"plan_id": plan_id, "outcome": outcome, "cause_public": cause, "aftermath_beat": beat, "descriptor": descriptor,
		"authoritative": false, "can_mutate": false, "authority_gap": SURFACE_AUTHORITY_GAP,
	}


static func _phase(id: String, place: String, objectives: Array) -> Dictionary:
	return {"id": id, "place": place, "objectives": objectives.duplicate()}


static func _decision(id: String, phase: String, round: int, place: String, choices: Array) -> Dictionary:
	return {"id": id, "phase": phase, "round": round, "place": place, "choices": choices.duplicate()}


static func _phase_by_id(phases_value: Variant, phase_id: String) -> Dictionary:
	for phase_value in _copy_array(phases_value):
		var phase := _copy_dict(phase_value)
		if str(phase.get("id", "")) == phase_id: return phase
	return {}


static func _available_decisions(state: Dictionary, surface: Dictionary) -> Array:
	var result: Array = []
	var status := str(state.get("status", ""))
	var play := _copy_dict(state.get("play", {}))
	var made: Dictionary = _copy_dict(play.get("decisions", {}))
	for decision_value in _copy_array(surface.get("decisions", [])):
		var decision := _copy_dict(decision_value)
		var decision_id := str(decision.get("id", ""))
		if str(decision.get("phase", "")) != status or made.has(decision_id): continue
		var boundary := int(decision.get("round", -1))
		if boundary >= 0 and int(play.get("round", -1)) != boundary: continue
		result.append(decision_id)
	return result


static func _production_decision_evidence_valid(state: Dictionary, decision_id: String, evidence: Dictionary) -> bool:
	var plan_id := str(state.get("plan_id", ""))
	if plan_id == PLAN_COUNT:
		if not _exact_keys(evidence, ["environment_archetype_id", "game_id", "round", "session_id", "settled", "source_kind"]): return false
		return str(evidence.get("source_kind", "")) == "settled_game_session" and bool(evidence.get("settled", false)) \
			and str(evidence.get("session_id", "")).strip_edges().length() > 0 and str(evidence.get("game_id", "")) == "blackjack" \
			and str(evidence.get("environment_archetype_id", "")) in ["grand_casino", "grand_casino_high_limit"] \
			and int(evidence.get("round", -1)) == int(_copy_dict(state.get("play", {})).get("round", -2))
	if not _exact_keys(evidence, ["place_role", "receipt_verified", "source_kind"]): return false
	if str(evidence.get("source_kind", "")) != "cage_interview" or str(evidence.get("place_role", "")) != "grand_casino_cage": return false
	return decision_id == "cut_short" or bool(evidence.get("receipt_verified", false))


static func _exact_keys(value: Dictionary, expected: Array) -> bool:
	var keys := value.keys(); keys.sort()
	var exact := expected.duplicate(); exact.sort()
	return keys == exact


static func validate_content() -> Array:
	var failures: Array = []
	var source := config()
	if int(source.get("schema_version", 0)) != SCHEMA_VERSION or int(source.get("state_schema_version", 0)) != SCHEMA_VERSION:
		failures.append("heist.json schema versions must match CrewHeistModel.")
	var ids: Array = []
	for value in source.get("plans", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = value
		ids.append(str(row.get("id", "")))
		if _copy_array(row.get("world_criteria", [])).is_empty() or _copy_array(row.get("crew_criteria", [])).is_empty() or _copy_dict(row.get("setup", {})).is_empty() or _copy_dict(row.get("play", {})).is_empty() or _copy_dict(row.get("getaway", {})).is_empty():
			failures.append("Heist plan %s is missing criteria or phase tuning." % str(row.get("id", "")))
		var expected_architects := ["crew_bishop"] if str(row.get("id", "")) == PLAN_COUNT else ["crew_velvet", "crew_mags"]
		if _copy_array(row.get("architects", [])) != expected_architects:
			failures.append("Heist plan %s must expose its exact crew06_9 loyal-architect set." % str(row.get("id", "")))
		var setup := _copy_dict(row.get("setup", {}))
		var play := _copy_dict(row.get("play", {}))
		if str(row.get("id", "")) == PLAN_COUNT:
			var decision_rounds := _copy_dict(play.get("decision_rounds", {}))
			if int(play.get("window_actions", 0)) <= 0 or int(decision_rounds.get("go", -1)) != 0 or int(decision_rounds.get("distraction", -1)) != 1 or int(decision_rounds.get("exit", -1)) != 2:
				failures.append("The Count must author its action window and three interleaved decision rounds.")
			var routes := _copy_dict(_copy_dict(row.get("getaway", {})).get("routes", {}))
			if not routes.has("dock") or not routes.has("corridor"):
				failures.append("The Count must author distinct dock and corridor getaway routes.")
		else:
			if _copy_array(play.get("game_sequence", [])) != ["craps", "blackjack", "craps", "baccarat", "blackjack"]:
				failures.append("The Whale Game must author its mixed craps/card invitational sequence.")
			var rig := _copy_dict(setup.get("rig", {}))
			if str(rig.get("component_item", "")) != "false_bottom_cup" or str(rig.get("training_flag", "")) != "craps_setting_trained":
				failures.append("The Whale Game rig schema must match its reachable item and training producers.")
			if _copy_dict(row.get("interview", {})).is_empty():
				failures.append("The Whale Game must author its cage interview beat.")
	if ids != PLAN_IDS:
		failures.append("heist.json must ship Plans A and B only, in contract order.")
	failures.append_array(CrewTurnModelScript.validate_tuning(_copy_dict(source.get("hidden_resolution", {}))))
	var outcomes := _copy_array(source.get("outcomes", []))
	if outcomes.size() != 4 or str(_copy_dict(outcomes[3]).get("id", "")) != "closed":
		failures.append("heist.json must fill the outcome ladder's fourth slot with the hidden failure beat.")
	for forbidden in ["the_jackpot_job", "lights_out"]:
		if JSON.stringify(source).to_lower().find(forbidden) != -1:
			failures.append("heist.json contains a forbidden future-plan coupling: %s." % forbidden)
	return failures


static func _copy_dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _copy_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
