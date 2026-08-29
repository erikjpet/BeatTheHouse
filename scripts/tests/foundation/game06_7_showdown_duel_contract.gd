extends SceneTree

const RITUAL_PROJECTION_PATH := "res://scripts/core/grand_casino_duel_ritual_projection.gd"
const DUEL_MODEL_PATH := "res://scripts/core/grand_casino_duel_model.gd"
const RNG_STREAM_PATH := "res://scripts/core/rng_stream.gd"
const CONTRACT_PATH := "res://data/games/showdown_duel_game_ritual_v1.json"
const DESIGN_PATH := "res://data/games/showdown_duel_ritual_v1.json"
const EVENTS_PATH := "res://data/events/events.json"
const EXPECTED_PHASES := ["approach", "seating", "response", "commitment", "reveal", "phase_break", "crowd_change", "outcome_staging", "exit"]
const REQUIRED_COVERAGE := {
	"dependency_scripts": 3,
	"dependency_instances": 3,
	"contract": 1,
	"ladder_cases": 5,
	"ladder_terminals": 2,
	"determinism_seeds": 10,
	"phase_transitions": 8,
	"phase_machine": 1,
	"privacy": 1,
	"product_adapter": 1,
	"liveness_iterations": 1000,
}

var _projection: Variant
var _duel_model: Variant
var _rng_stream_script: Variant
var _coverage: Dictionary = {}


func _initialize() -> void:
	var failures: Array = []
	if not _load_and_validate_dependencies(failures):
		_finish(failures)
		return
	var contract_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	if typeof(contract_value) != TYPE_DICTIONARY:
		_finish(["SHOWDOWN-DUEL contract JSON did not parse."])
		return
	var contract := contract_value as Dictionary
	var design_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESIGN_PATH))
	if typeof(design_value) != TYPE_DICTIONARY:
		_finish(["SHOWDOWN-DUEL design declaration JSON did not parse."])
		return
	var design := design_value as Dictionary
	_check_contract(contract, design, failures)
	_check_ladder(design, failures)
	_check_ten_seed_determinism(failures)
	_check_phase_machine(failures)
	_check_projection_privacy(failures)
	_check_product_surface_adapter(failures)
	_check_liveness_performance(failures)
	_finish(failures)


func _load_and_validate_dependencies(failures: Array) -> bool:
	_rng_stream_script = _load_script_dependency(RNG_STREAM_PATH, "RngStream", ["configure"], failures)
	_duel_model = _load_script_dependency(DUEL_MODEL_PATH, "GrandCasinoDuelModel", ["outcome_for_margin", "apply_hand", "initialize"], failures)
	_projection = _load_script_dependency(RITUAL_PROJECTION_PATH, "GrandCasinoDuelRitualProjection", ["initial_state", "apply_transition", "normalize_state", "record_one_shot", "public_projection", "public_duel_fingerprint", "sealed_product_projection", "verify_product_projection"], failures)
	if _rng_stream_script == null or _duel_model == null or _projection == null:
		return false
	var projection_constants := _projection.get_script_constant_map()
	if not projection_constants.has("RITUAL_ID") or str(projection_constants.get("RITUAL_ID", "")).is_empty():
		failures.append("GrandCasinoDuelRitualProjection is missing its nonempty RITUAL_ID constant.")
		return false
	for row in [["RngStream", _rng_stream_script], ["GrandCasinoDuelModel", _duel_model], ["GrandCasinoDuelRitualProjection", _projection]]:
		var instance: Variant = (row[1] as Script).new()
		if instance == null:
			failures.append("%s could not be constructed after loading." % str(row[0]))
			continue
		_mark_coverage("dependency_instances")
	if int(_coverage.get("dependency_instances", 0)) != 3:
		return false
	return failures.is_empty()


func _load_script_dependency(path: String, label: String, required_methods: Array, failures: Array) -> Script:
	var failure_count_before := failures.size()
	var resource: Resource = load(path)
	if resource == null or not resource is Script:
		failures.append("%s dependency did not load as a Script: %s" % [label, path])
		return null
	var script := resource as Script
	if not script.can_instantiate():
		failures.append("%s dependency failed to compile or cannot instantiate: %s" % [label, path])
		return null
	var method_names: Dictionary = {}
	for method_value in script.get_script_method_list():
		var method := _dict(method_value)
		method_names[str(method.get("name", ""))] = true
	for required_method in required_methods:
		if not method_names.has(str(required_method)):
			failures.append("%s dependency is missing required method %s." % [label, str(required_method)])
	if failures.size() != failure_count_before:
		return null
	_mark_coverage("dependency_scripts")
	return script


func _check_contract(contract: Dictionary, design: Dictionary, failures: Array) -> void:
	if str(contract.get("contract", "")) != "game_ritual/1" or str(contract.get("ritual_id", "")) != _projection.RITUAL_ID: failures.append("Frozen ritual identity changed.")
	var phases := _array(contract.get("ritual_phases", []))
	var phase_ids: Array = []
	var phase_by_id: Dictionary = {}
	var permitted: Dictionary = {}
	for phase_value in phases:
		var phase := _dict(phase_value)
		var phase_id := str(phase.get("id", ""))
		phase_ids.append(phase_id)
		phase_by_id[phase_id] = phase
		for action_value in _array(phase.get("permitted_actions", [])): permitted[str(action_value)] = true
	if phase_ids != EXPECTED_PHASES: failures.append("SHOWDOWN-DUEL staging phase order changed.")
	var declared_actions: Dictionary = {}
	for declaration_value in _array(contract.get("action_declarations", [])):
		var declaration := _dict(declaration_value)
		declared_actions[str(declaration.get("action_id", ""))] = true
	for action_id in permitted.keys():
		if not declared_actions.has(action_id): failures.append("Permitted action %s lacks a declaration." % action_id)
	var reachable := {"approach":true}
	var changed := true
	while changed:
		changed = false
		for phase_id in reachable.keys():
			for transition_value in _array(_dict(phase_by_id.get(phase_id, {})).get("transitions", [])):
				var next_phase := str(_dict(transition_value).get("next_phase", ""))
				if phase_by_id.has(next_phase) and not reachable.has(next_phase): reachable[next_phase] = true; changed = true
	if reachable.size() != EXPECTED_PHASES.size(): failures.append("SHOWDOWN-DUEL graph contains an unreachable staging phase.")
	for verb_value in _array(contract.get("pointer_verbs", [])):
		var verb := _dict(verb_value)
		var action_id := str(verb.get("accepted_action", ""))
		if not declared_actions.has(action_id): failures.append("Pointer verb %s lacks a declared action." % str(verb.get("id", "")))
		for phase_id in _array(verb.get("phases", [])):
			if not _array(_dict(phase_by_id.get(str(phase_id), {})).get("permitted_actions", [])).has(action_id): failures.append("Pointer verb %s is not permitted in %s." % [str(verb.get("id", "")), str(phase_id)])
		var equivalents := _dict(verb.get("equivalents", {}))
		for mode in ["keyboard", "controller", "reduced_motion"]:
			if str(_dict(equivalents.get(mode, {})).get("action_id", "")) != action_id: failures.append("Pointer verb %s lacks identical %s action parity." % [str(verb.get("id", "")), mode])
	for actor_value in _array(contract.get("actors", [])):
		var actor := _dict(actor_value)
		if _array(actor.get("behavior_states", [])).is_empty(): failures.append("Actor %s has no bounded behavior states." % str(actor.get("id", "")))
	for object_value in _array(contract.get("scene_objects", [])):
		var object := _dict(object_value)
		var bounds := _dict(object.get("bounds", {}))
		if int(bounds.get("w", 0)) <= 0 or int(bounds.get("h", 0)) <= 0: failures.append("Scene object %s lacks bounded geometry." % str(object.get("id", "")))
		for hit_value in _array(object.get("hit_regions", [])):
			var hit := _dict(hit_value)
			var hit_bounds := _dict(hit.get("bounds", {}))
			if int(hit.get("minimum_touch_target", 0)) < 44 or int(hit_bounds.get("w", 0)) < 44 or int(hit_bounds.get("h", 0)) < 44: failures.append("Interactive object %s violates the 44px target minimum." % str(object.get("id", "")))
	for tier_value in _array(_dict(contract.get("energy", {})).get("tiers", [])):
		var tier := _dict(tier_value)
		var state_operations := _array(tier.get("actor_operations", [])) + _array(tier.get("object_operations", [])) + _array(tier.get("interaction_operations", []))
		if state_operations.is_empty(): failures.append("Energy tier touches no actor/object state.")
	var persistence := _dict(contract.get("ritual_persistence", {}))
	if _array(persistence.get("save_boundaries", [])) != EXPECTED_PHASES or not _array(persistence.get("one_shot_receipted", [])).has("ending_audio"): failures.append("Persistence does not bind every phase and ending one-shot.")
	if str(design.get("contract", "")) != "showdown_duel_projection/1": failures.append("SHOWDOWN-DUEL design declaration identity changed.")
	var privacy := _dict(design.get("privacy", {}))
	for forbidden in ["turn_member_id", "turn_eligible_members", "turn_roll", "turn_threshold", "hidden_contradiction", "x"]:
		if not _array(privacy.get("forbidden_fields", [])).has(forbidden): failures.append("Privacy contract lost forbidden field %s." % forbidden)
	_mark_coverage("contract")


func _check_ladder(contract: Dictionary, failures: Array) -> void:
	var authority := _dict(contract.get("outcome_authority", {}))
	var thresholds := _dict(authority.get("margin_thresholds", {}))
	if int(thresholds.get("walk_out_clean_min", 0)) != 12 or int(thresholds.get("shown_the_door_min", 0)) != -60: failures.append("Data-backed duel thresholds changed.")
	var cases := [[12,"walk_out_clean"],[11,"shown_the_door"],[-59,"shown_the_door"],[-60,"shown_the_door"],[-61,"taken_out_back"]]
	for case_value in cases:
		var row := case_value as Array
		var outcome: Variant = _duel_model.call("outcome_for_margin", int(row[0]), thresholds)
		if typeof(outcome) != TYPE_STRING or str(outcome).is_empty():
			failures.append("Outcome ladder returned an empty/null result at margin %d." % int(row[0]))
			continue
		_mark_coverage("ladder_cases")
		if str(outcome) != str(row[1]): failures.append("Outcome ladder changed at margin %d." % int(row[0]))
	var terms := _duel_terms()
	if terms.is_empty():
		failures.append("SHOWDOWN-DUEL terms could not be loaded from events data.")
		return
	var player_zero := _duel_state(10, 10, 0, 5)
	var player_value: Variant = _duel_model.call("apply_hand", player_zero, {"transfer":-10}, terms)
	var player_result := _dict(player_value)
	if player_result.is_empty() or _dict(player_result.get("state", {})).is_empty(): failures.append("Player stack-zero model result was empty/null.")
	else: _mark_coverage("ladder_terminals")
	if str(_dict(player_result.get("state", {})).get("outcome", "")) != "taken_out_back": failures.append("Player stack-zero terminal changed.")
	var rourke_zero := _duel_state(10, 10, 0, 5)
	var rourke_value: Variant = _duel_model.call("apply_hand", rourke_zero, {"transfer":10}, terms)
	var rourke_result := _dict(rourke_value)
	if rourke_result.is_empty() or _dict(rourke_result.get("state", {})).is_empty(): failures.append("Rourke stack-zero model result was empty/null.")
	else: _mark_coverage("ladder_terminals")
	if str(_dict(rourke_result.get("state", {})).get("outcome", "")) != "walk_out_clean": failures.append("Rourke stack-zero terminal changed.")
	var rules := _dict(terms.get("rules", {}))
	for pair in [["hand_limit",5],["base_ante",20],["correct_call_swing",18],["false_call_cost",6],["player_cheat_detection_base",55],["player_cheat_detection_per_aggression",5],["player_cheat_detection_per_cheat_level",5],["player_cheat_caught_penalty",18]]:
		if int(rules.get(str(pair[0]), -1)) != int(pair[1]): failures.append("Shipped duel rule %s changed." % str(pair[0]))


func _check_ten_seed_determinism(failures: Array) -> void:
	var terms := _duel_terms()
	if terms.is_empty():
		failures.append("Ten-seed determinism has no SHOWDOWN-DUEL terms.")
		return
	for seed in range(1, 11):
		var rng_a: Variant = _rng_stream_script.new()
		var rng_b: Variant = _rng_stream_script.new()
		if rng_a == null or rng_b == null or not rng_a.has_method("configure") or not rng_b.has_method("configure"):
			failures.append("RngStream construction/configure failed at seed %d." % seed)
			continue
		rng_a.call("configure", seed)
		rng_b.call("configure", seed)
		var state_a := _dict(_duel_model.call("initialize", terms, rng_a))
		var state_b := _dict(_duel_model.call("initialize", terms, rng_b))
		if state_a.is_empty() or state_b.is_empty():
			failures.append("Duel model returned an empty/null initialized state at seed %d." % seed)
			continue
		if _fingerprint(state_a) != _fingerprint(state_b): failures.append("Duel authority drifted at seed %d." % seed)
		var ritual_a := _dict(_projection.call("initial_state", {"duel_id":"showdown","attempt":seed,"route_id":"pit_boss_showdown","result_serial":0}))
		var ritual_b := _dict(_projection.call("initial_state", {"duel_id":"showdown","attempt":seed,"route_id":"pit_boss_showdown","result_serial":0,"turn_roll":seed * 999}))
		if ritual_a.is_empty() or ritual_b.is_empty():
			failures.append("Ritual projection returned an empty/null initial state at seed %d." % seed)
			continue
		if _fingerprint(ritual_a) != _fingerprint(ritual_b): failures.append("Hidden input changed ritual authority at seed %d." % seed)
		_mark_coverage("determinism_seeds")


func _check_phase_machine(failures: Array) -> void:
	var state: Dictionary = _projection.initial_state({"duel_id":"showdown","attempt":1,"route_id":"pit_boss_showdown","result_serial":0})
	var before := _fingerprint(state)
	var skipped: Dictionary = _projection.apply_transition(state, "commitment", "receipt:transition:skip", {"authoritative_result_ref":"result:skip"})
	if bool(skipped.get("ok", false)) or _fingerprint(skipped.get("state", {})) != before: failures.append("Phase machine accepted a skip or mutated on rejection.")
	var steps := [["seating","walk"],["response","pat_down"],["response","interrogation_beat_1"],["commitment","duel_terms"],["reveal","hand_1"],["phase_break","hand_1_reveal"],["crowd_change","hand_1_break"],["commitment","hand_2_ready"]]
	for index in range(steps.size()):
		var step := steps[index] as Array
		var receipt := "receipt:transition:%02d" % index
		var result: Dictionary = _projection.apply_transition(state, str(step[0]), receipt, {"authoritative_result_ref":str(step[1])})
		if not bool(result.get("ok", false)): failures.append("Legal phase transition %d failed." % index); return
		state = _dict(result.get("state", {}))
		if state.is_empty(): failures.append("Legal phase transition %d returned empty/null state." % index); return
		_mark_coverage("phase_transitions")
		var replay: Dictionary = _projection.apply_transition(state, str(step[0]), receipt, {"authoritative_result_ref":str(step[1])})
		if not bool(replay.get("ok", false)) or not bool(replay.get("replayed", false)) or _fingerprint(replay.get("state", {})) != _fingerprint(state): failures.append("Transition %d did not replay exactly once." % index)
		var conflict: Dictionary = _projection.apply_transition(state, str(step[0]), receipt, {"authoritative_result_ref":"conflict"})
		if bool(conflict.get("ok", false)) or _fingerprint(conflict.get("state", {})) != _fingerprint(state): failures.append("Transition receipt conflict %d mutated state." % index)
		var restored: Dictionary = _projection.normalize_state(JSON.parse_string(JSON.stringify(state)))
		if _fingerprint(restored) != _fingerprint(state): failures.append("Phase %s save/load drifted." % str(step[0]))
	var terminal: Dictionary = _projection.apply_transition(state, "outcome_staging", "receipt:transition:outcome", {"authoritative_result_ref":"duel:complete","route_id":"pit_boss_showdown","outcome":"shown_the_door"})
	if not bool(terminal.get("ok", false)) or str(_dict(terminal.get("state", {})).get("selected_ending", "")) != "shown_the_door": failures.append("Authoritative duel ending failed.")
	state = _dict(terminal.get("state", {}))
	var one_shot: Dictionary = _projection.record_one_shot(state, "ending_dialogue", "receipt:one_shot:ending")
	var replay_one_shot: Dictionary = _projection.record_one_shot(_dict(one_shot.get("state", {})), "ending_dialogue", "receipt:one_shot:ending")
	if not bool(one_shot.get("emit", false)) or bool(replay_one_shot.get("emit", true)) or not bool(replay_one_shot.get("replayed", false)): failures.append("Ending one-shot replayed.")
	_mark_coverage("phase_machine")


func _check_projection_privacy(failures: Array) -> void:
	var ritual: Dictionary = _projection.initial_state({"duel_id":"showdown","attempt":1,"route_id":"pit_boss_showdown","result_serial":0,"x":{"turn_member_id":"crew_ace"}})
	var duel := _duel_state(130, 90, 3, 5)
	duel["last_bark"] = "The room goes quiet."
	duel["current_edge"] = {"id":"deck_stack","active":true,"called":false,"private_roll":99}
	var public_crew := [{"member_id":"crew_ace","presentation_id":"crew_ace_rail","pose":"rail","public_state":"supporting","turn_roll":99,"hidden_contradiction":"crew_rook"}]
	var projection_a: Dictionary = _projection.public_projection(duel, ritual, {"route_id":"pit_boss_showdown","current_edge":duel.current_edge,"turn_member_id":"crew_rook"}, public_crew)
	public_crew[0]["turn_roll"] = 1
	public_crew[0]["hidden_contradiction"] = "crew_bishop"
	var projection_b: Dictionary = _projection.public_projection(duel, ritual, {"route_id":"pit_boss_showdown","current_edge":duel.current_edge,"turn_member_id":"crew_bishop"}, public_crew)
	if _fingerprint(projection_a) != _fingerprint(projection_b): failures.append("Hidden Turn state changed the public projection.")
	for forbidden in ["turn_member_id","turn_roll","hidden_contradiction","private_roll","x"]:
		if _contains_key(projection_a, forbidden): failures.append("Public projection leaked %s." % forbidden)
	if str(_dict(projection_a.get("rourke_actor", {})).get("behavior_state", "")) != "suspicion": failures.append("Rourke state did not derive from the public active edge.")
	if int(_dict(projection_a.get("player_stakes", {})).get("margin", 0)) != 40 or str(projection_a.get("energy_tier", "")) != "player_pressing": failures.append("Player stakes/energy did not derive from duel authority.")
	var crew_ending: Dictionary = _projection.apply_transition(ritual, "outcome_staging", "receipt:crew:ending", {"authoritative_result_ref":"crew:complete","route_id":"crew_heist"})
	var crew_projection: Dictionary = _projection.public_projection({}, _dict(crew_ending.get("state", {})), {"route_id":"crew_heist"}, public_crew)
	if str(crew_projection.get("selected_ending", "")) != "crew_heist_final" or str(_dict(crew_projection.get("room_state", {})).get("exit_state", "")) != "crew": failures.append("Crew ending collapsed into the duel ending.")
	var web_round_trip: Variant = JSON.parse_string(JSON.stringify(projection_a))
	if _fingerprint(projection_a) != _fingerprint(web_round_trip): failures.append("Native/Web canonical projection parity drifted.")
	if projection_a.is_empty() or projection_b.is_empty(): failures.append("Privacy projection returned an empty/null public surface.")
	else: _mark_coverage("privacy")


func _check_product_surface_adapter(failures: Array) -> void:
	var duel := _duel_state(112, 88, 2, 5)
	duel["attempt"] = 3
	duel["hands"] = [{"hand_index":0,"transfer":12,"player_stack":112,"rourke_stack":88,"private_roll":99}]
	duel["blackjack_session"] = {"dealer_cards":[{"rank":14}],"private_shoe_cursor":17}
	duel["edge_schedule"] = [{}, {}, {"id":"deck_stack","active":true,"called":false,"private_roll":99}]
	var fingerprint: String = _projection.public_duel_fingerprint(duel)
	var authority := {
		"duel_id":"grand_casino_showdown",
		"route_id":"pit_boss_showdown",
		"attempt":3,
		"result_serial":1,
		"authoritative_result_ref":"duel:3:hand:1:active",
		"duel_content_fingerprint":fingerprint,
		"current_edge":{"id":"deck_stack","active":true,"called":false,"private_roll":99},
		"turn_member_id":"crew_ace",
	}
	var commitment: Dictionary = _projection.sealed_product_projection(duel, "player_turn", authority)
	if commitment.is_empty() or not _projection.verify_product_projection(commitment, duel, "player_turn", authority): failures.append("Authentic live duel projection did not mount on the product surface.")
	if str(commitment.get("phase_id", "")) != "commitment": failures.append("Live Blackjack decision phase did not map to duel commitment staging.")
	if not _array(commitment.get("public_crew_actors", [])).is_empty(): failures.append("Product adapter accepted crew presence without the sealed World6 seam.")
	for forbidden in ["turn_member_id","private_roll","private_shoe_cursor","edge_schedule","blackjack_session"]:
		if _contains_key(commitment, forbidden): failures.append("Product adapter leaked %s." % forbidden)
	var reveal: Dictionary = _projection.sealed_product_projection(duel, "settlement", authority)
	if reveal.is_empty(): failures.append("Settled product projection returned empty/null output.")
	if str(reveal.get("phase_id", "")) != "reveal": failures.append("Settled Blackjack hand did not map to duel reveal staging.")
	var tampered := reveal.duplicate(true)
	var tampered_actor := _dict(tampered.get("rourke_actor", {})); tampered_actor["behavior_state"] = "respect"; tampered["rourke_actor"] = tampered_actor
	if _projection.verify_product_projection(tampered, duel, "settlement", authority): failures.append("Tampered product projection passed its closed seal.")
	var forged_authority := authority.duplicate(true); forged_authority["duel_content_fingerprint"] = "forged"
	if not _projection.sealed_product_projection(duel, "player_turn", forged_authority).is_empty(): failures.append("Forged duel authority mounted on the product surface.")
	var private_variant := duel.duplicate(true)
	private_variant["blackjack_session"] = {"dealer_cards":[{"rank":2}],"private_shoe_cursor":999}
	private_variant["edge_schedule"] = [{}, {}, {"id":"deck_stack","active":true,"called":false,"private_roll":1}]
	if _projection.public_duel_fingerprint(private_variant) != fingerprint: failures.append("Private Blackjack authority changed the public duel fingerprint.")
	var complete := duel.duplicate(true); complete["status"] = "complete"; complete["outcome"] = "shown_the_door"
	var complete_authority := authority.duplicate(true); complete_authority["duel_content_fingerprint"] = _projection.public_duel_fingerprint(complete); complete_authority["authoritative_result_ref"] = "duel:3:complete"
	var terminal: Dictionary = _projection.sealed_product_projection(complete, "wagering", complete_authority)
	if terminal.is_empty(): failures.append("Terminal product projection returned empty/null output.")
	if str(terminal.get("phase_id", "")) != "outcome_staging" or str(terminal.get("selected_ending", "")) != "shown_the_door": failures.append("Terminal duel authority did not produce its distinct outcome staging.")
	if not commitment.is_empty() and not reveal.is_empty() and not terminal.is_empty(): _mark_coverage("product_adapter")


func _check_liveness_performance(failures: Array) -> void:
	var ritual: Dictionary = _projection.initial_state({"duel_id":"showdown","attempt":1,"route_id":"pit_boss_showdown","result_serial":0})
	var duel := _duel_state(100, 105, 2, 5)
	var started := Time.get_ticks_usec()
	var digest := ""
	for index in range(1000):
		duel["hand_index"] = index % 5
		var projected := _dict(_projection.call("public_projection", duel, ritual, {"route_id":"pit_boss_showdown"}, []))
		if projected.is_empty():
			failures.append("Liveness projection returned empty/null output at iteration %d." % index)
			return
		digest = _fingerprint(projected)
		_mark_coverage("liveness_iterations")
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	if digest.is_empty() or elapsed_ms <= 0.0 or elapsed_ms > 1000.0: failures.append("Projection liveness/performance failed: %.3f ms." % elapsed_ms)


func _duel_terms() -> Dictionary:
	var events_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(EVENTS_PATH))
	for event_value in _array(events_value):
		var event := _dict(event_value)
		if str(event.get("id", "")) != "the_house_calls": continue
		var terms := _dict(_dict(event.get("payload", {})).get("duel_terms", {}))
		terms["starting_stacks"] = {"player":100,"rourke":105}
		terms["handicaps"] = {"forced_ante":0}
		terms["rourke_cheat_level"] = 2
		return terms
	return {}


func _duel_state(player_stack: int, rourke_stack: int, hand_index: int, hand_limit: int) -> Dictionary:
	return {"version":1,"status":"active","outcome":"","hand_index":hand_index,"hand_limit":hand_limit,"player_stack":player_stack,"rourke_stack":rourke_stack,"starting_player_stack":player_stack,"starting_rourke_stack":rourke_stack,"ante":20,"edge_schedule":[],"hands":[],"blackjack_session":{},"last_bark":"","margin":player_stack-rourke_stack}


func _fingerprint(value: Variant) -> String:
	return JSON.stringify(_canonical(value)).sha256_text()


func _canonical(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT and float(value) == floor(float(value)): return int(value)
	if typeof(value) == TYPE_DICTIONARY:
		var source := value as Dictionary
		var keys: Array = source.keys(); keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var result: Dictionary = {}
		for key in keys: result[str(key)] = _canonical(source.get(key))
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for item in value as Array: result.append(_canonical(item))
		return result
	return value


func _contains_key(value: Variant, key_name: String) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		var source := value as Dictionary
		if source.has(key_name): return true
		for nested in source.values():
			if _contains_key(nested, key_name): return true
	elif typeof(value) == TYPE_ARRAY:
		for nested in value as Array:
			if _contains_key(nested, key_name): return true
	return false


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func _mark_coverage(id: String, amount: int = 1) -> void:
	_coverage[id] = int(_coverage.get(id, 0)) + amount


func _finish(failures: Array) -> void:
	for id_value in REQUIRED_COVERAGE.keys():
		var id := str(id_value)
		var expected := int(REQUIRED_COVERAGE.get(id, 0))
		var actual := int(_coverage.get(id, 0))
		if actual != expected:
			failures.append("Required coverage %s was incomplete: expected=%d actual=%d." % [id, expected, actual])
	if failures.is_empty():
		print("GAME06_7_SHOWDOWN_DUEL_CONTRACT_OK phases=9 seeds=10")
		quit(0)
		return
	for failure in failures: printerr("GAME06_7_SHOWDOWN_DUEL_CONTRACT_FAIL: %s" % str(failure))
	quit(1)
