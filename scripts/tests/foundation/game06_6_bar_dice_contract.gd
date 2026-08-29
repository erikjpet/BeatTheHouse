extends SceneTree

const RitualProjectionScript := preload("res://scripts/core/bar_dice_ritual_projection.gd")
const BarDiceGameScript := preload("res://scripts/games/bar_dice.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const GameModuleScript := preload("res://scripts/core/game_module.gd")
const RuntimeScript := preload("res://scripts/core/game_ritual_runtime.gd")
const ActionAuthorityScript := preload("res://scripts/core/blackjack_action_authority.gd")
const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const CONTRACT_PATH := "res://data/games/bar_dice_game_ritual_v1.json"
const EXPECTED_PHASES := ["agree_wager", "cover", "shake", "throw", "reveal", "call", "settle"]
const FORBIDDEN_PRIVATE_FIELDS := ["future_dice", "next_rng", "timing_target", "private_throw", "hidden_sweep", "wall_clock_result"]

var _projection: Variant = RitualProjectionScript


func _initialize() -> void:
	var failures: Array = []
	var contract_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	if typeof(contract_value) != TYPE_DICTIONARY:
		_finish(["BAR-DICE canonical contract JSON did not parse."])
		return
	_check_contract(contract_value as Dictionary, failures)
	_check_phase_machine(failures)
	_check_cover_and_money_projection(failures)
	_check_interruption(failures)
	_check_ten_seed_noninterference(failures)
	_check_product_authority_and_phase_binding(failures)
	_check_sealed_wager_identity(failures)
	_check_liveness_performance(failures)
	_finish(failures)


func _check_contract(contract: Dictionary, failures: Array) -> void:
	if str(contract.get("contract", "")) != "game_ritual/1" or str(contract.get("ritual_id", "")) != _projection.RITUAL_ID:
		failures.append("Frozen ritual identity changed.")
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
	if phase_ids != EXPECTED_PHASES: failures.append("BAR-DICE phase order changed.")
	var declared_actions: Dictionary = {}
	for declaration_value in _array(contract.get("action_declarations", [])):
		var declaration := _dict(declaration_value)
		declared_actions[str(declaration.get("action_id", ""))] = true
	for action_id in permitted.keys():
		if not declared_actions.has(action_id): failures.append("Permitted action %s lacks a declaration." % action_id)
	var reachable := {"agree_wager":true}
	var changed := true
	while changed:
		changed = false
		for phase_id in reachable.keys():
			for transition_value in _array(_dict(phase_by_id.get(phase_id, {})).get("transitions", [])):
				var next_phase := str(_dict(transition_value).get("next_phase", ""))
				if phase_by_id.has(next_phase) and not reachable.has(next_phase): reachable[next_phase] = true; changed = true
	if reachable.size() != EXPECTED_PHASES.size(): failures.append("BAR-DICE graph contains an unreachable phase.")
	for verb_value in _array(contract.get("pointer_verbs", [])):
		var verb := _dict(verb_value)
		var action_id := str(verb.get("accepted_action", ""))
		if not declared_actions.has(action_id): failures.append("Pointer verb %s lacks a declared action." % str(verb.get("id", "")))
		for mode in ["keyboard", "controller", "reduced_motion"]:
			if str(_dict(_dict(verb.get("equivalents", {})).get(mode, {})).get("action_id", "")) != action_id:
				failures.append("Pointer verb %s lacks identical %s parity." % [str(verb.get("id", "")), mode])
	for actor_value in _array(contract.get("actors", [])):
		var actor := _dict(actor_value)
		if _array(actor.get("behavior_states", [])).is_empty(): failures.append("Actor %s has no bounded states." % str(actor.get("id", "")))
	for object_value in _array(contract.get("scene_objects", [])):
		var object := _dict(object_value)
		var bounds := _dict(object.get("bounds", {}))
		if int(bounds.get("w", 0)) <= 0 or int(bounds.get("h", 0)) <= 0: failures.append("Object %s lacks bounded geometry." % str(object.get("id", "")))
		for hit_value in _array(object.get("hit_regions", [])):
			var hit := _dict(hit_value)
			var hit_bounds := _dict(hit.get("bounds", {}))
			if int(hit.get("minimum_touch_target", 0)) < 44 or int(hit_bounds.get("w", 0)) < 44 or int(hit_bounds.get("h", 0)) < 44:
				failures.append("Object %s violates the 44px target minimum." % str(object.get("id", "")))
	for tier_value in _array(_dict(contract.get("energy", {})).get("tiers", [])):
		var tier := _dict(tier_value)
		if _array(tier.get("actor_operations", [])).is_empty() or _array(tier.get("object_operations", [])).is_empty():
			failures.append("Energy tier %s must change actor and object state." % str(tier.get("id", "")))
	var persistence := _dict(contract.get("ritual_persistence", {}))
	if _array(persistence.get("save_boundaries", [])) != EXPECTED_PHASES or not _array(persistence.get("one_shot_receipted", [])).has("settlement_audio"):
		failures.append("Persistence does not bind every phase and settlement one-shot.")


func _check_phase_machine(failures: Array) -> void:
	var state: Dictionary = _projection.initial_state(_base_authority(1))
	var before := _fingerprint(state)
	var skipped: Dictionary = _projection.apply_transition(state, "throw", "receipt:skip", _throw_authority(1))
	if bool(skipped.get("ok", false)) or _fingerprint(skipped.get("state", {})) != before:
		failures.append("Phase machine accepted a skip or mutated on rejection.")
	var steps := [["cover", "cover"], ["shake", "cover_ack"], ["throw", "shake"], ["reveal", "throw"], ["call", "reveal"], ["settle", "call"]]
	for index in range(steps.size()):
		var step := steps[index] as Array
		var authority := _throw_authority(1) if str(step[0]) in ["reveal", "call", "settle"] else _covered_authority(1)
		var receipt := "receipt:transition:%02d:%s" % [index, str(step[1])]
		var result: Dictionary = _projection.apply_transition(state, str(step[0]), receipt, authority)
		if not bool(result.get("ok", false)): failures.append("Legal phase transition %d failed: %s." % [index, str(result.get("error_code", ""))]); return
		state = _dict(result.get("state", {}))
		var replay: Dictionary = _projection.apply_transition(state, str(step[0]), receipt, authority)
		if not bool(replay.get("ok", false)) or not bool(replay.get("replayed", false)) or _fingerprint(replay.get("state", {})) != _fingerprint(state):
			failures.append("Transition %d did not replay exactly once." % index)
		var conflict_authority := authority.duplicate(true); conflict_authority["result_serial"] = 99
		var conflict: Dictionary = _projection.apply_transition(state, str(step[0]), receipt, conflict_authority)
		if bool(conflict.get("ok", false)) or _fingerprint(conflict.get("state", {})) != _fingerprint(state): failures.append("Receipt conflict %d mutated state." % index)
		var restored: Dictionary = _projection.normalize_state(JSON.parse_string(JSON.stringify(state)))
		if _fingerprint(restored) != _fingerprint(state): failures.append("Phase %s save/load drifted." % str(step[0]))
	var one_shot: Dictionary = _projection.record_one_shot(state, "settlement_audio", "receipt:one_shot:settle")
	var replay_one_shot: Dictionary = _projection.record_one_shot(_dict(one_shot.get("state", {})), "settlement_audio", "receipt:one_shot:settle")
	if not bool(one_shot.get("emit", false)) or bool(replay_one_shot.get("emit", true)) or not bool(replay_one_shot.get("replayed", false)):
		failures.append("Settlement one-shot replayed.")


func _check_cover_and_money_projection(failures: Array) -> void:
	var ritual: Dictionary = _projection.initial_state(_base_authority(2))
	var partial := _covered_authority(2)
	partial["cover_status"] = "partial"; partial["proposed_total"] = 20; partial["covered_total"] = 12; partial["returned_stake"] = 8; partial["at_risk_total"] = 12
	var projection: Dictionary = _projection.public_projection(ritual, partial)
	var money := _dict(projection.get("money", {}))
	if int(money.get("covered_total", -1)) + int(money.get("returned_stake", -1)) != int(money.get("proposed_total", -1)):
		failures.append("Partial cover projection does not conserve proposed cash.")
	if int(money.get("payout", -1)) != 0 or int(money.get("net_change", -1)) != 0: failures.append("Unsettled projection exposed a cash settlement.")
	var refused := partial.duplicate(true); refused["cover_status"] = "refused"; refused["covered_total"] = 0; refused["returned_stake"] = 20; refused["at_risk_total"] = 0; refused["outcome"] = "refused"
	var terminal: Dictionary = _projection.apply_transition(ritual, "settle", "receipt:refused", refused)
	if not bool(terminal.get("ok", false)): failures.append("Refused cover did not return through settle.")
	var refused_projection: Dictionary = _projection.public_projection(_dict(terminal.get("state", {})), refused)
	var refused_money := _dict(refused_projection.get("money", {}))
	if int(refused_money.get("returned_stake", 0)) != 20 or int(refused_money.get("at_risk_total", 1)) != 0 or int(refused_money.get("net_change", 1)) != 0:
		failures.append("Refused cover charged or stranded cash.")


func _check_interruption(failures: Array) -> void:
	var phases := ["agree_wager", "cover", "shake", "throw", "reveal", "call"]
	for phase_id in phases:
		var ritual := _state_at_phase(phase_id, 3, failures)
		if ritual.is_empty(): continue
		var authority := _covered_authority(3)
		authority["interrupted"] = true; authority["interruption_reason"] = "sweep_adjacent"; authority["returned_stake"] = 10; authority["at_risk_total"] = 0; authority["outcome"] = "interrupted"; authority["aftermath_receipt"] = "aftermath:sweep:3"
		var result: Dictionary = _projection.apply_transition(ritual, "settle", "receipt:interrupt:%s" % phase_id, authority)
		if not bool(result.get("ok", false)): failures.append("Interruption could not settle from %s." % phase_id); continue
		var public: Dictionary = _projection.public_projection(_dict(result.get("state", {})), authority)
		var interruption := _dict(public.get("interruption", {}))
		if not bool(interruption.get("active", false)) or int(interruption.get("returned_stake", 0)) != 10 or str(interruption.get("aftermath_receipt", "")).is_empty():
			failures.append("Interruption from %s lost refund or aftermath." % phase_id)


func _check_ten_seed_noninterference(failures: Array) -> void:
	for seed in range(1, 11):
		var authority := _throw_authority(seed)
		var ritual_a: Dictionary = _projection.initial_state(authority)
		var hidden_variant := authority.duplicate(true)
		hidden_variant["future_dice"] = [6, 6, 6, 6, 6]; hidden_variant["next_rng"] = seed * 999; hidden_variant["timing_target"] = 77; hidden_variant["hidden_sweep"] = true
		var ritual_b: Dictionary = _projection.initial_state(hidden_variant)
		if _fingerprint(ritual_a) != _fingerprint(ritual_b): failures.append("Private input changed initial ritual at seed %d." % seed)
		var projection_a: Dictionary = _projection.public_projection(ritual_a, authority)
		var projection_b: Dictionary = _projection.public_projection(ritual_b, hidden_variant)
		if _fingerprint(projection_a) != _fingerprint(projection_b): failures.append("Private input changed actor/onlooker projection at seed %d." % seed)
		for forbidden in FORBIDDEN_PRIVATE_FIELDS:
			if _contains_key(projection_a, forbidden): failures.append("Projection leaked %s at seed %d." % [forbidden, seed])
		if str(_dict(_dict(projection_a.get("opponent_actor", {})).get("tell", {})).get("source_fact", "")) not in ["cover_status", "rounds_played", "outcome"]:
			failures.append("Opponent tell lacks a public source at seed %d." % seed)
		var web_round_trip: Variant = JSON.parse_string(JSON.stringify(projection_a))
		if _fingerprint(projection_a) != _fingerprint(web_round_trip): failures.append("Canonical parity drifted at seed %d." % seed)


func _check_product_authority_and_phase_binding(failures: Array) -> void:
	var game = BarDiceGameScript.new()
	game.definition = {"id":"bar_dice","family":"dice","legal_actions":[],"cheat_actions":[]}
	var contract: Dictionary = game.sealed_action_authority_contract()
	if game.sealed_action_authority_script() == null \
			or str(contract.get("resolve_proposal_method", "")) != "_bar_dice_resolve_proposal" \
			or str(contract.get("wager_cost_proposal_method", "")) != "_bar_dice_wager_cost_proposal" \
			or str(contract.get("authoritative_result_marker", "")) != "sealed_action_authoritative":
		failures.append("Shipped Bar Dice is not bound to the accepted sealed host contract.")
		return
	var run: RunState = RunStateScript.new()
	run.start_new("GAME06_6_PRODUCT_AUTHORITY")
	run.bankroll = 100
	run.current_environment = {"id":"bar_dice_contract_room","archetype_id":"street_register","economic_profile":{"stake_floor":1,"stake_ceiling":20},"game_states":{}}
	var environment: Dictionary = run.current_environment
	var ui: Dictionary = {}
	var command: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, ui, run, environment)
	ui = _dict(command.get("ui_state", {}))
	if str(ui.get("bar_dice_ritual_phase", "")) != "cover" or bool(command.get("resolve", false)): failures.append("Product wager agreement skipped or resolved through cover.")
	command = game.surface_action_command("bar_dice_ack_cover", 0, false, ui, run, environment); ui = _dict(command.get("ui_state", {}))
	if str(ui.get("bar_dice_ritual_phase", "")) != "shake" or not bool(ui.get("rolled", false)): failures.append("Product cover acknowledgement did not open the bounded shake.")
	command = game.surface_action_command("bar_dice_resolve", 0, false, ui, run, environment); ui = _dict(command.get("ui_state", {}))
	if str(ui.get("bar_dice_ritual_phase", "")) != "throw" or bool(command.get("resolve", false)): failures.append("Product shake resolved instead of staging the throw.")
	command = game.surface_action_command("bar_dice_throw", 0, false, ui, run, environment); ui = _dict(command.get("ui_state", {}))
	if str(ui.get("bar_dice_ritual_phase", "")) != "reveal" or bool(command.get("resolve", false)): failures.append("Product throw rerolled or settled before reveal.")
	command = game.surface_action_command("bar_dice_reveal", 0, false, ui, run, environment); ui = _dict(command.get("ui_state", {}))
	if str(ui.get("bar_dice_ritual_phase", "")) != "call" or bool(command.get("resolve", false)): failures.append("Product reveal settled before the call.")
	command = game.surface_action_command("bar_dice_ack_call", 0, false, ui, run, environment)
	if not bool(command.get("resolve", false)) or str(command.get("action_id", "")) != "roll": failures.append("Product call did not nominate exactly one sealed settlement intent.")
	var authorized_stake := int(command.get("set_stake", 0))
	var snapshot_before := RuntimeScript.canonical_json(run.to_save_snapshot())
	var rng := RngStreamScript.new(); rng.configure(606)
	var rng_before := RuntimeScript.canonical_json(rng.snapshot())
	var compatibility: Dictionary = game.resolve_with_context("roll", authorized_stake, run, environment, rng, ui)
	if not bool(compatibility.get("bar_dice_compatibility_simulation", false)) or not bool(compatibility.get("sealed_action_authoritative", false)):
		failures.append("Legacy Bar Dice resolve did not fail closed as a receipt-required simulation.")
	if RuntimeScript.canonical_json(run.to_save_snapshot()) != snapshot_before or RuntimeScript.canonical_json(rng.snapshot()) != rng_before:
		failures.append("Legacy Bar Dice resolve mutated live run or RNG outside Foundation.")
	GameModuleScript.apply_result(run, compatibility, rng)
	if RuntimeScript.canonical_json(run.to_save_snapshot()) != snapshot_before:
		failures.append("Receipt-free Bar Dice compatibility result applied to canonical state.")
	var proposal: Dictionary = game.call("_bar_dice_resolve_proposal", "roll", authorized_stake, run.to_save_snapshot(), rng.snapshot(), ui)
	var result := _dict(proposal.get("result", {}))
	if not bool(proposal.get("ok", false)) or not bool(result.get("bar_dice_proposal_requires_apply", false)) or str(proposal.get("output_fingerprint", "")).is_empty():
		failures.append("Pure Bar Dice proposal did not produce a host-verifiable apply boundary.")


func _check_sealed_wager_identity(failures: Array) -> void:
	var game = BarDiceGameScript.new()
	game.definition = {"id":"bar_dice","family":"dice","legal_actions":[],"cheat_actions":[]}
	var run: RunState = RunStateScript.new()
	run.start_new("GAME06_6_SEALED_WAGER_IDENTITY")
	run.bankroll = 100
	var environment := {"id":"bar_dice_wager_identity","archetype_id":"street_register","economic_profile":{"stake_floor":1,"stake_ceiling":20},"game_states":{}}
	var table: Dictionary = game.generate_environment_state(run, environment, run.create_rng("bar_dice_wager_identity_table"))
	table["stake_ladder"] = [1, 2, 5, 10, 20]
	table["selected_stake_index"] = 2
	environment["game_states"] = {"bar_dice":table}
	run.current_environment = environment
	var host: Control = FoundationMainScript.new()
	host.set("current_game", game)
	host.set("game_module_cache", {"bar_dice":game})
	host.set("run_state", run)
	host.set("selected_stake", 5)
	var bankroll_before := run.bankroll
	var result: Dictionary = host.call("_sealed_action_host_resolve_intent", "roll", 5)
	if not bool(result.get("ok", false)) or not bool(result.get(ActionAuthorityScript.HOST_COMMITTED_KEY, false)):
		failures.append("Sealed Bar Dice host rejected an authored $5 ladder wager.")
	else:
		var funding := _dict(result.get(ActionAuthorityScript.HOST_FUNDING_LEASE_KEY, {}))
		var delivery := _dict(result.get(ActionAuthorityScript.HOST_DELIVERY_KEY, {}))
		var receipt := _dict(result.get(ActionAuthorityScript.HOST_APPLY_RECEIPT_KEY, {}))
		var story_log := _array(_dict(result.get("deltas", {})).get("story_log", []))
		var story_entry := _dict(story_log[0]) if not story_log.is_empty() else {}
		for wager_value in [
			int(result.get(ActionAuthorityScript.HOST_WAGER_COST_KEY, -1)),
			int(funding.get("wager", -1)),
			int(delivery.get("stake", -1)),
			int(receipt.get("stake", -1)),
			int(result.get("stake", -1)),
			int(story_entry.get("stake_cost", -1)),
			int(result.get("bar_dice_stake", -1)),
		]:
			if wager_value != 5:
				failures.append("Sealed Bar Dice funding, proposal, settlement, and receipt did not retain one exact $5 wager.")
				break
		var bankroll_delta := int(result.get("bankroll_delta", 0))
		if run.bankroll - bankroll_before != bankroll_delta:
			failures.append("Sealed Bar Dice settlement delta did not match the committed bankroll change.")
		if bankroll_delta < 0 and bankroll_delta != -5:
			failures.append("A losing sealed $5 Bar Dice wager settled against a different stake basis.")
	host.free()

	var rejected_run: RunState = RunStateScript.new()
	rejected_run.start_new("GAME06_6_BELOW_MINIMUM_REJECTION")
	rejected_run.bankroll = 100
	var rejected_environment := {"id":"bar_dice_below_minimum","archetype_id":"street_register","economic_profile":{"stake_floor":5,"stake_ceiling":20},"game_states":{}}
	var rejected_table: Dictionary = game.generate_environment_state(rejected_run, rejected_environment, rejected_run.create_rng("bar_dice_below_minimum_table"))
	rejected_table["stake_ladder"] = [5, 10, 20]
	rejected_table["selected_stake_index"] = 0
	rejected_environment["game_states"] = {"bar_dice":rejected_table}
	rejected_run.current_environment = rejected_environment
	var rejected_table_before := rejected_table.duplicate(true)
	var rejected_bankroll_before := rejected_run.bankroll
	var rejected_chips_before := rejected_run.grand_casino_chips
	var rejected_rng_before := rejected_run.rng_state
	var rejected_host: Control = FoundationMainScript.new()
	rejected_host.set("current_game", game)
	rejected_host.set("game_module_cache", {"bar_dice":game})
	rejected_host.set("run_state", rejected_run)
	rejected_host.set("selected_stake", 1)
	var rejected: Dictionary = rejected_host.call("_sealed_action_host_resolve_intent", "roll", 1)
	var rejected_after: Dictionary = game.call("_table_state_preview", rejected_run, rejected_run.current_environment)
	rejected_after.erase(ActionAuthorityScript.LEDGER_KEY)
	if bool(rejected.get("ok", true)) or bool(rejected.get(ActionAuthorityScript.HOST_COMMITTED_KEY, true)):
		failures.append("Sealed Bar Dice host accepted a wager below the authored table minimum.")
	if rejected_run.bankroll != rejected_bankroll_before or rejected_run.grand_casino_chips != rejected_chips_before or rejected_run.rng_state != rejected_rng_before:
		failures.append("Below-minimum Bar Dice rejection changed money or RNG state.")
	if RuntimeScript.canonical_json(rejected_after) != RuntimeScript.canonical_json(rejected_table_before):
		failures.append("Below-minimum Bar Dice rejection changed product table state.")
	rejected_host.free()


func _check_liveness_performance(failures: Array) -> void:
	var ritual: Dictionary = _projection.initial_state(_base_authority(1))
	var started := Time.get_ticks_usec()
	var digest := ""
	for index in range(1000):
		var authority := _covered_authority(index % 10 + 1); authority["attention"] = index % 100
		digest = _fingerprint(_projection.public_projection(ritual, authority))
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	if digest.is_empty() or elapsed_ms <= 0.0 or elapsed_ms > 1000.0: failures.append("Projection liveness/performance failed: %.3f ms." % elapsed_ms)


func _state_at_phase(target: String, seed: int, failures: Array) -> Dictionary:
	var state: Dictionary = _projection.initial_state(_base_authority(seed))
	if target == "agree_wager": return state
	var phases := ["cover", "shake", "throw", "reveal", "call"]
	for index in range(phases.find(target) + 1):
		var next_phase: String = str(phases[index])
		var authority := _throw_authority(seed) if next_phase in ["reveal", "call"] else _covered_authority(seed)
		var result: Dictionary = _projection.apply_transition(state, next_phase, "receipt:build:%s:%d" % [target, index], authority)
		if not bool(result.get("ok", false)): failures.append("Could not build phase %s." % target); return {}
		state = _dict(result.get("state", {}))
	return state


func _base_authority(seed: int) -> Dictionary:
	return {"round_id":"bar:%d" % seed,"result_serial":seed,"available_cash":100,"opponent_available_cash":80,"proposed_total":10,"covered_total":0,"returned_stake":0,"at_risk_total":0,"cover_status":"pending","rounds_played":seed - 1,"attention":seed * 4}


func _covered_authority(seed: int) -> Dictionary:
	var authority := _base_authority(seed)
	authority["cover_status"] = "accepted"; authority["covered_total"] = 10; authority["at_risk_total"] = 10
	return authority


func _throw_authority(seed: int) -> Dictionary:
	var authority := _covered_authority(seed)
	authority["authoritative_result_ref"] = "bar:result:%d" % seed; authority["outcome"] = "win" if seed % 2 == 0 else "lose"; authority["payout"] = 18 if seed % 2 == 0 else 0; authority["net_change"] = 8 if seed % 2 == 0 else -10; authority["rake"] = 2; authority["carryover_pot"] = 0
	return authority


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


func _finish(failures: Array) -> void:
	if failures.is_empty():
		print("GAME06_6_BAR_DICE_CONTRACT_OK phases=7 seeds=10")
		quit(0)
		return
	for failure in failures: printerr("GAME06_6_BAR_DICE_CONTRACT_FAIL: %s" % str(failure))
	quit(1)
