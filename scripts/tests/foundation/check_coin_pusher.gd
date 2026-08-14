extends SceneTree

const PUSHER_DETERMINISM_ACTIONS := 200
const PUSHER_EV_ACTIONS := 2400


func _check_coin_pusher_contract(library: ContentLibrary, failures: Array) -> void:
	var definition := library.game("coin_pusher")
	if definition.is_empty():
		failures.append("Quarter Falls game definition is missing.")
		return
	var game: GameModule = CoinPusherGameScript.new()
	game.setup(definition, library)
	_check_coin_pusher_data_contract(library, definition, failures)
	_check_coin_pusher_surface_liveness(game, failures)
	_check_coin_pusher_determinism(game, failures)
	_check_coin_pusher_security_bands(game, failures)
	_check_coin_pusher_nudge_alarm(game, library, failures)
	_check_coin_pusher_persistence_and_reset(game, failures)
	_check_coin_pusher_prize_items(game, failures)
	_check_coin_pusher_items(game, failures)
	_check_coin_pusher_economy(game, definition, failures)


func _check_coin_pusher_data_contract(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	if str(definition.get("module_path", "")) != "res://scripts/games/coin_pusher.gd" or str(definition.get("family", "")) != "coin_pusher":
		failures.append("Quarter Falls is not registered as the data-routed coin_pusher family.")
	var tuning: Dictionary = definition.get("coin_pusher_tuning", {}) if typeof(definition.get("coin_pusher_tuning", {})) == TYPE_DICTIONARY else {}
	for key in ["lane_count", "cell_count", "cell_capacity", "upper_phase_step", "lower_phase_step", "hard_alarm_heat", "documented_ev_band", "scenario_reset_contract", "prize_riders"]:
		if not tuning.has(key):
			failures.append("Quarter Falls tuning is missing %s." % key)
	var reset_contract: Dictionary = tuning.get("scenario_reset_contract", {}) if typeof(tuning.get("scenario_reset_contract", {})) == TYPE_DICTIONARY else {}
	if str(reset_contract.get("path", "")) != "scenario_game_modifiers.coin_pusher" or str(reset_contract.get("flag", "")) != "reset_pile":
		failures.append("Quarter Falls did not document the scenario pile-reset flag.")
	for venue_id in ["gas_station_casino", "corner_store", "bar"]:
		var venue := library.environment_archetype(venue_id)
		var pool: Array = venue.get("game_pool", []) if typeof(venue.get("game_pool", [])) == TYPE_ARRAY else []
		if not pool.has("coin_pusher"):
			failures.append("Tier-1 venue %s does not seed Quarter Falls availability." % venue_id)
	var corner := library.environment_archetype("corner_store")
	if JSON.stringify(corner.get("game_count", [])) != JSON.stringify([0, 1]):
		failures.append("Corner Store Quarter Falls placement must remain optional [0,1].")
	for untouched_id in ["motel", "pawn_shop", "back_alley"]:
		var pool: Array = library.environment_archetype(untouched_id).get("game_pool", [])
		if pool.has("coin_pusher"):
			failures.append("Quarter Falls leaked into non-target venue %s." % untouched_id)


func _check_coin_pusher_surface_liveness(game: GameModule, failures: Array) -> void:
	var fixture := _coin_pusher_fixture(game, "PUSHER-LIVENESS")
	var run_state: RunState = fixture.get("run_state")
	var surface := game.surface_state(run_state, run_state.current_environment, {"surface_time_msec": 1000})
	if str(surface.get("surface_renderer", "")) != "coin_pusher" or not bool(surface.get("surface_controls_native", false)):
		failures.append("Quarter Falls did not expose its native machine surface.")
	if bool(surface.get("surface_realtime_state_refresh", false)):
		failures.append("Quarter Falls must not rebuild its pile snapshot per frame.")
	_check_idle_animation_liveness_contract(surface, "Quarter Falls attract surface", failures)
	_check_surface_visual_motion_advances(game, surface, "Quarter Falls attract surface", failures)
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	game.draw_surface(harness, surface, {"contract_harness": true})
	for action in ["coin_pusher_lane", "coin_pusher_force", "coin_pusher_direction", "coin_pusher_drop", "coin_pusher_nudge"]:
		if not _surface_harness_has_action(harness, action):
			failures.append("Quarter Falls renderer is missing native action %s." % action)


func _check_coin_pusher_determinism(game: GameModule, failures: Array) -> void:
	var first := _coin_pusher_scripted_session(game, "PUSHER-200", PUSHER_DETERMINISM_ACTIONS)
	var second := _coin_pusher_scripted_session(game, "PUSHER-200", PUSHER_DETERMINISM_ACTIONS)
	if str(first.get("digest", "")) != str(second.get("digest", "")):
		failures.append("Quarter Falls 200-action pile evolution diverged for identical seed and inputs.")
	if JSON.stringify(first.get("outcomes", [])) != JSON.stringify(second.get("outcomes", [])):
		failures.append("Quarter Falls 200-action payouts/gutters diverged for identical seed and inputs.")
	if int(first.get("actions", 0)) != PUSHER_DETERMINISM_ACTIONS:
		failures.append("Quarter Falls deterministic fixture did not complete all 200 actions.")


func _check_coin_pusher_security_bands(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PUSHER-SECURITY-BANDS")
	var normal := _coin_pusher_environment("security_normal")
	var lax := _coin_pusher_environment("security_lax")
	var strict := _coin_pusher_environment("security_strict")
	var swept := _coin_pusher_environment("security_swept")
	normal["security_profile"] = {"machine_alarm_tolerance_band": "normal"}
	lax["security_profile"] = {"machine_alarm_tolerance_band": "lax"}
	strict["security_profile"] = {"machine_alarm_tolerance_band": "strict"}
	swept["security_profile"] = {"machine_alarm_tolerance_band": "normal", "pusher_alarm_tolerance_band_delta": 1}
	var base_seed := 481516
	var normal_state := game.generate_environment_state(run_state, normal, _configured_rng(base_seed))
	var lax_state := game.generate_environment_state(run_state, lax, _configured_rng(base_seed))
	var strict_state := game.generate_environment_state(run_state, strict, _configured_rng(base_seed))
	var swept_state := game.generate_environment_state(run_state, swept, _configured_rng(base_seed))
	var normal_tolerance := int(normal_state.get("alarm_tolerance_remaining", 0))
	if int(lax_state.get("alarm_tolerance_remaining", 0)) != normal_tolerance + 2:
		failures.append("Graveyard/lax scenario band did not add two pusher tolerance steps.")
	if int(strict_state.get("alarm_tolerance_remaining", 0)) != normal_tolerance - 2:
		failures.append("Serial-Check/strict adjacency band did not remove two pusher tolerance steps.")
	if int(swept_state.get("alarm_tolerance_remaining", 0)) != normal_tolerance + 1:
		failures.append("Swept-window pusher tolerance modifier did not add one band step.")
	var adjacency_run: RunState = RunStateScript.new()
	adjacency_run.start_new("PUSHER-SERIAL-ADJACENCY")
	adjacency_run.world_map = {
		"current_node_id": "bar_node",
		"start_node_id": "bar_node",
		"nodes": [
			{"id": "bar_node", "archetype_id": "bar", "label": "Roadside Bar", "kind": "casino", "tier": 1},
			{"id": "pawn_node", "archetype_id": "pawn_shop", "label": "Sal's Pawn", "kind": "shop", "tier": 1},
		],
		"edges": [{"a": "bar_node", "b": "pawn_node"}],
	}
	adjacency_run.town_state.configure_world(adjacency_run.world_map)
	var adjacency_environment := _coin_pusher_environment("bar_node")
	adjacency_environment["world_node_id"] = "bar_node"
	adjacency_run.set_environment(adjacency_environment)
	var adjacency_baseline := game.generate_environment_state(adjacency_run, adjacency_run.current_environment, _configured_rng(base_seed))
	var serial_definition := game.library.scenario("pawn_shop_serial_check_day")
	adjacency_run.seed_scenario_for_node("pawn_node", serial_definition)
	var adjacency_strict := game.generate_environment_state(adjacency_run, adjacency_run.current_environment, _configured_rng(base_seed))
	if int(adjacency_strict.get("alarm_tolerance_remaining", 0)) != int(adjacency_baseline.get("alarm_tolerance_remaining", 0)) - 2:
		failures.append("Authored nearby_alarm_tolerance_band on an adjacent production Serial-Check scenario did not tighten pusher tolerance.")
	var public_surface := game.surface_state(run_state, {"id": "hidden", "game_states": {"coin_pusher": normal_state}}, {})
	if public_surface.has("alarm_tolerance_remaining") or public_surface.has("base_alarm_tolerance"):
		failures.append("Quarter Falls leaked hidden machine tolerance into its public surface.")


func _check_coin_pusher_nudge_alarm(game: GameModule, library: ContentLibrary, failures: Array) -> void:
	var fixture := _coin_pusher_fixture(game, "PUSHER-ALARM")
	var run_state: RunState = fixture.get("run_state")
	var environment: Dictionary = run_state.current_environment
	var machine: Dictionary = (environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	_machine_hanger_fixture(machine, 2)
	machine["base_alarm_tolerance"] = 3
	machine["tolerance_modifier"] = 0
	machine["alarm_tolerance_remaining"] = 3
	machine["tell_rung"] = 0
	var digest_before_clean := game.deterministic_state_digest(environment)
	var clean := game.resolve_with_context("nudge_machine", 0, run_state, environment, run_state.create_rng("clean_nudge"), {
		"coin_pusher_force": "tap", "coin_pusher_direction": "front", "coin_pusher_lane": 2, "coin_pusher_timing_phase": 3,
	})
	if not bool(clean.get("coin_pusher_clean_drop", false)) or int(clean.get("coin_pusher_tolerance_spent", -1)) != 0:
		failures.append("Well-timed, aimed Quarter Falls nudge did not preserve tolerance and clean the hanger.")
	if game.deterministic_state_digest(environment) == digest_before_clean:
		failures.append("A clean Quarter Falls nudge did not evolve the coarse pile.")
	machine = (environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	_machine_hanger_fixture(machine, 2)
	machine["base_alarm_tolerance"] = 3
	machine["tolerance_modifier"] = 0
	machine["alarm_tolerance_remaining"] = 3
	machine["tell_rung"] = 0
	var tell_rungs: Array = []
	var alarm_result: Dictionary = {}
	for nudge_index in range(4):
		alarm_result = game.resolve_with_context("nudge_machine", 0, run_state, environment, run_state.create_rng("bad_nudge_%d" % nudge_index), {
			"coin_pusher_force": "tap", "coin_pusher_direction": "front", "coin_pusher_lane": 2, "coin_pusher_timing_phase": 9,
		})
		if nudge_index < 3:
			tell_rungs.append(int(alarm_result.get("coin_pusher_tell_rung", -1)))
		GameModule.apply_result(run_state, alarm_result, run_state.create_rng("bad_nudge_apply_%d" % nudge_index))
	if JSON.stringify(tell_rungs) != JSON.stringify([1, 2, 3]):
		failures.append("Quarter Falls tell ladder did not fire rock, chirp, attendant glance in order: %s." % JSON.stringify(tell_rungs))
	if not bool(alarm_result.get("coin_pusher_hard_alarm", false)) or not bool(alarm_result.get("coin_pusher_machine_locked", false)):
		failures.append("Quarter Falls tolerance crossing did not lock only the machine.")
	if int(alarm_result.get("suspicion_delta", 0)) < 8 or bool(alarm_result.get("ended", false)) or not bool(alarm_result.get("coin_pusher_player_remains_in_environment", false)):
		failures.append("Quarter Falls hard alarm was not significant heat with a nonterminal stay-in-environment result.")
	if str(run_state.current_environment.get("id", "")) != str(environment.get("id", "")) or run_state.run_status != RunState.RUN_STATUS_ACTIVE:
		failures.append("Quarter Falls hard alarm forced departure or ended the active run.")
	var other_definition := library.game("bar_dice")
	var other_script: Script = load(str(other_definition.get("module_path", "")))
	var other_game: GameModule = other_script.new() if other_script != null else null
	if other_game == null:
		failures.append("Quarter Falls coexistence fixture could not load the other venue game.")
	else:
		other_game.setup(other_definition, library)
		var other_actions := other_game.actions(run_state, environment)
		if (other_actions.get("legal_actions", []) as Array).is_empty():
			failures.append("Quarter Falls alarm disabled another game in the same venue.")
	var locked_actions := game.actions(run_state, environment)
	if not (locked_actions.get("legal_actions", []) as Array).is_empty() or not (locked_actions.get("cheat_actions", []) as Array).is_empty():
		failures.append("Quarter Falls locked cabinet still offered machine actions.")
	if run_state.rumor_fact("pusher:%s" % run_state.current_world_node_id()).is_empty():
		failures.append("Quarter Falls pile did not publish its truth-traced pusher rumor fact.")
	if run_state.reputation_value(run_state.current_world_node_id(), "alarm_tripped") <= 0.0:
		failures.append("Quarter Falls alarm did not flow through the existing reputation writer.")
	var slam_fixture := _coin_pusher_fixture(game, "PUSHER-SLAM-GRAB")
	var slam_run: RunState = slam_fixture.get("run_state")
	var slam_machine: Dictionary = (slam_run.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	_machine_hanger_fixture(slam_machine, 2)
	slam_machine["alarm_tolerance_remaining"] = 0
	var slam_result := game.resolve_with_context("nudge_machine", 0, slam_run, slam_run.current_environment, slam_run.create_rng("slam_grab"), {
		"coin_pusher_force": "slam", "coin_pusher_direction": "front", "coin_pusher_lane": 2, "coin_pusher_timing_phase": 9,
	})
	if not bool(slam_result.get("coin_pusher_hard_alarm", false)) or int(slam_result.get("coin_pusher_payout", 0)) < 4:
		failures.append("Quarter Falls slam-and-grab did not deliver a meaningful drop before/with the alarm.")
	run_state.suspicion = {}
	game.enter(run_state, environment)
	var floor_after_first_entry := run_state.suspicion_level()
	game.enter(run_state, environment)
	if floor_after_first_entry < 12 or run_state.suspicion_level() != floor_after_first_entry:
		failures.append("Quarter Falls staff-watch suspicion floor was not venue-scoped and idempotent on revisit.")


func _check_coin_pusher_persistence_and_reset(game: GameModule, failures: Array) -> void:
	var fixture := _coin_pusher_fixture(game, "PUSHER-PERSIST")
	var run_state: RunState = fixture.get("run_state")
	var environment: Dictionary = run_state.current_environment
	for index in range(12):
		var result := game.resolve_with_context("drop_quarter", 1, run_state, environment, run_state.create_rng("persist_%d" % index), {"coin_pusher_lane": index % 5})
		GameModule.apply_result(run_state, result, run_state.create_rng("persist_apply_%d" % index))
	var persisted_digest := game.deterministic_state_digest(environment)
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	if game.deterministic_state_digest(restored.current_environment) != persisted_digest:
		failures.append("Quarter Falls pile did not survive RunState save/load round-trip.")
	var revisit_environment := restored.current_environment.duplicate(true)
	restored.set_environment({"id": "away", "archetype_id": "motel", "world_node_id": "motel", "game_ids": []})
	restored.set_environment(revisit_environment)
	if game.deterministic_state_digest(restored.current_environment) != persisted_digest:
		failures.append("Quarter Falls pile changed across leave/revisit without a scenario reset.")
	restored.current_environment["scenario_game_modifiers"] = {"coin_pusher": {"reset_pile": true, "reset_token": "someone_else_played_a"}}
	game.enter(restored, restored.current_environment)
	var reset_state: Dictionary = (restored.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	if int(reset_state.get("action_count", -1)) != 0 or game.deterministic_state_digest(restored.current_environment) == persisted_digest:
		failures.append("Quarter Falls scenario reset token did not replace the persisted pile.")
	var reset_digest := game.deterministic_state_digest(restored.current_environment)
	game.enter(restored, restored.current_environment)
	if game.deterministic_state_digest(restored.current_environment) != reset_digest:
		failures.append("Quarter Falls scenario reset token reapplied more than once.")


func _check_coin_pusher_prize_items(game: GameModule, failures: Array) -> void:
	var fixture := _coin_pusher_fixture(game, "PUSHER-PRIZE")
	var run_state: RunState = fixture.get("run_state")
	var environment: Dictionary = run_state.current_environment
	var machine: Dictionary = (environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	_machine_hanger_fixture(machine, 2)
	machine["riders"] = [{"id": "fixture_prize", "kind": "scenario_item", "label": "lucky penny", "item_id": "lucky_penny", "cash_value": 0, "lane": 2, "cell": 0, "push": 1}]
	var result := game.resolve_with_context("nudge_machine", 0, run_state, environment, run_state.create_rng("prize_push"), {
		"coin_pusher_force": "shove", "coin_pusher_direction": "front", "coin_pusher_lane": 2, "coin_pusher_timing_phase": 3,
	})
	GameModule.apply_result(run_state, result, run_state.create_rng("prize_apply"))
	if not run_state.inventory.has("lucky_penny") or (result.get("coin_pusher_prizes", []) as Array).is_empty():
		failures.append("Quarter Falls scenario inventory prize did not ride the pile into inventory.")


func _check_coin_pusher_items(game: GameModule, failures: Array) -> void:
	var fixture := _coin_pusher_fixture(game, "PUSHER-ITEMS")
	var run_state: RunState = fixture.get("run_state")
	run_state.add_item("cold_quarters")
	run_state.add_item("coin_return_shim")
	var command := game.active_item_command("cold_quarters", run_state, run_state.current_environment, run_state.create_rng("cold_arm"))
	if not bool(command.get("handled", false)):
		failures.append("Cold Quarters could not arm the Quarter Falls dense drop.")
	else:
		GameModule.apply_result(run_state, command.get("result", {}), run_state.create_rng("cold_apply"))
		var state: Dictionary = (run_state.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
		if not bool(state.get("cold_quarters_armed", false)) or run_state.inventory.has("cold_quarters"):
			failures.append("Cold Quarters did not persist one dense armed drop and consume the item.")
	game.enter(run_state, run_state.current_environment)
	var item_state: Dictionary = (run_state.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	if int(item_state.get("shim_uses_remaining", 0)) != 3:
		failures.append("Coin-Return Shim did not seed its limited three-use recovery state.")


func _check_coin_pusher_economy(game: GameModule, definition: Dictionary, failures: Array) -> void:
	var session := _coin_pusher_scripted_session(game, "PUSHER-EV", PUSHER_EV_ACTIONS)
	var cost := maxi(1, int(session.get("cost", 0)))
	var ev := float(session.get("payout", 0)) / float(cost)
	var tuning: Dictionary = definition.get("coin_pusher_tuning", {})
	var band: Array = tuning.get("documented_ev_band", [])
	if band.size() != 2 or ev < float(band[0]) or ev > float(band[1]):
		failures.append("Quarter Falls long-run coin EV %.4f fell outside documented band %s." % [ev, JSON.stringify(band)])


func _coin_pusher_scripted_session(game: GameModule, seed_text: String, action_count: int) -> Dictionary:
	var fixture := _coin_pusher_fixture(game, seed_text)
	var run_state: RunState = fixture.get("run_state")
	var rng := run_state.create_rng("scripted_session")
	var outcomes: Array = []
	var payout := 0
	var cost := 0
	for index in range(action_count):
		var result := game.resolve_with_context("drop_quarter", 1, run_state, run_state.current_environment, rng, {"coin_pusher_lane": index % 5})
		if not bool(result.get("ok", false)):
			break
		payout += int(result.get("coin_pusher_payout", 0))
		cost += 1
		outcomes.append([int(result.get("coin_pusher_payout", 0)), bool(result.get("coin_pusher_gutter", false))])
		GameModule.apply_result(run_state, result, rng)
	return {"digest": game.deterministic_state_digest(run_state.current_environment), "outcomes": outcomes, "actions": outcomes.size(), "payout": payout, "cost": cost}


func _coin_pusher_fixture(game: GameModule, seed_text: String) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 100000
	run_state.town_state.configure_world({
		"nodes": [
			{"id": "bar", "label": "Roadside Bar", "kind": "casino", "tier": 1},
			{"id": "motel", "label": "Pink Motel", "kind": "service", "tier": 1},
		],
		"edges": [{"a": "bar", "b": "motel"}],
	})
	var environment := _coin_pusher_environment("%s_node" % seed_text.to_lower().replace("-", "_"))
	var generated := game.generate_environment_state(run_state, environment, run_state.create_rng("coin_pusher_initial"))
	environment["game_states"] = {"coin_pusher": generated}
	run_state.set_environment(environment)
	return {"run_state": run_state, "environment": run_state.current_environment}


func _coin_pusher_environment(id: String) -> Dictionary:
	return {
		"id": id,
		"archetype_id": "bar",
		"world_node_id": "bar",
		"name": "Roadside Bar",
		"kind": "casino",
		"tier": 1,
		"game_ids": ["coin_pusher", "bar_dice"],
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 100},
		"security_profile": {"strictness": "normal"},
		"game_states": {},
	}


func _machine_hanger_fixture(machine: Dictionary, lane: int) -> void:
	var lanes: Array = machine.get("lanes", [])
	if lane < 0 or lane >= lanes.size():
		return
	var lane_data: Dictionary = lanes[lane]
	var cells: Array = lane_data.get("cells", [])
	if cells.is_empty():
		return
	var front: Dictionary = cells[0]
	front["height"] = 10
	front["edge_hang"] = true
	cells[0] = front
	lane_data["cells"] = cells
	lanes[lane] = lane_data
	machine["lanes"] = lanes


func _configured_rng(seed_value: int) -> RngStream:
	var rng := RngStream.new()
	rng.configure(seed_value)
	return rng
