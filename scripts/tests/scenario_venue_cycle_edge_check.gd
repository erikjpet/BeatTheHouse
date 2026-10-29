extends "res://scripts/tests/scenario_venue_cycle_captured_check.gd"

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "private edge-test root required"): _finish(); return
	_install(OS.get_environment("BTH_CAPTURED_FIXTURE"))
	root.size = Vector2i(1280, 720)
	var app := Host.new(); app.continuous_environment_clock_enabled = false; app.script_prewarm_stopping = true; root.add_child(app)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "genuine edge fixture Continue"): app.queue_free(); await process_frame; _finish(); return
	var run: RunState = app.run_state
	var mode := OS.get_environment("BTH_VENUE_CASE")
	var archetype := str(run.current_environment.archetype_id)
	facts = {"mode": mode, "archetype": archetype}
	var protected := _protected(run)
	var old_record := run.environment_situation_cycle(archetype).duplicate(true)
	if mode == "crew_destination":
		var now := run.game_clock_minutes
		var original := run.current_environment.duplicate(true)
		var node := WorldMap.node_by_id(run.world_map, "back_alley")
		_check(not node.get("environment", {}).is_empty() and str(node.get("state", "")) == WorldMap.STATE_VISITED, "genuine other visited room available during active delivery")
		var rng := RngStream.new(); rng.configure(run.seed_value, run.seed_value)
		var room := app.generator._world_environment_data_for_node(run, run.world_map, node, rng)
		facts["destination_errors"] = app.generator._last_environment_install_errors
		facts["protected_diff"] = _different_paths(protected, _protected(run))
		facts["source_room_diff"] = _different_paths(original, run.current_environment)
		_check(not room.is_empty() and str(room.get("environment_situation_cycle_id", "")).begins_with("venue:v1:") or room.is_empty() and not app.generator._last_environment_install_errors.is_empty(), "ordinary lazy destination either installs current cycle or rejects invalid historical room explicitly")
		_check(_protected(run) == protected and run.game_clock_minutes == now and _different_paths(original, run.current_environment).is_empty(), "destination scenario transaction preserves active job/cargo/deadline/Crew and source room exactly without travel/time")
		app.save_foundation_run(); _check(app.return_to_main_menu(), "active delivery private normal Save/Menu")
		app.save_service = SaveService.new(); _check(app.load_foundation_run(), "active delivery ordinary fresh-service Continue")
		_check(_protected(app.run_state) == protected, "one original accepted package and unrelated world state persist across lazy rollover Save/Continue")
		facts["job_deadline_preserved"] = true
	elif mode == "tamper":
		var closed_at := int(old_record.closes_at)
		_check(bool(run.advance_game_clock_minutes(closed_at - run.game_clock_minutes).get("ok", false)), "advance to actual venue close")
		var state: Dictionary = run.current_environment.get("scenario_sequence_state", {})
		var receipt := str(state.command_receipts[0])
		state.command_fingerprints[receipt] = "forged"
		var before_room := run.current_environment.duplicate(true)
		var before_run := _protected(run)
		var rejected := app.generator.refresh_current_venue_scenario_cycle(run)
		_check(not bool(rejected.get("ok", true)), "tampered command authority cannot be retired/re-signed")
		_check(_different_paths(before_room, run.current_environment).is_empty(), "rejected retirement restores exact original invalid room envelope")
		_check(_protected(run) == before_run and _different_paths(old_record, run.environment_situation_cycle(archetype)).is_empty(), "rejected retirement preserves funds/RNG/journal and selection")
		facts["expected_rejection"] = rejected.get("errors", [])
	elif mode == "skip":
		clock_reference = RunState.new(); clock_reference.from_dict(run.to_dict()); clock_reference.current_environment = run.current_environment.duplicate(true)
		clock_reference.restore_scenario_definition_cache(run.scenario_definition_cache_snapshot())
		var target := (int(floor(float(run.game_clock_minutes) / 1440.0)) + 5) * 1440 + 720
		_check(_advance(app, target), "skip five venue cycles using normal clock API")
		var next := run.environment_situation_cycle(archetype)
		_check(next.get("history", {}).size() == old_record.get("history", {}).size() + 1, "retire existing situation once; never create unseen skipped scenarios/rewards")
		_check(int(next.opened_at) <= target and int(next.closes_at) > target, "only latest current opening selected")
		_check(_protected(run) == protected, "skipped cycles preserve paid state and root RNG")
		var stable := next.duplicate(true)
		for repeat in range(3): app._prepare_room_presentation_at_boundary()
		_check(_different_paths(stable, run.environment_situation_cycle(archetype)).is_empty(), "skipped-cycle result is stable on repeated reads")
		facts["history_count"] = next.get("history", {}).size(); facts["selected"] = next.get("scenario_id", "")
	else:
		# Exercise the same destination stage used by ordinary travel/preview on a
		# detached genuine stored room. No fare, visit or game action is fabricated.
		var original := run.current_environment.duplicate(true)
		var node := WorldMap.node_by_id(run.world_map, run.current_world_node_id())
		_check(not node.is_empty(), "genuine stored world node available")
		node["environment"] = original.duplicate(true); node["state"] = WorldMap.STATE_VISITED
		var target := (int(floor(float(run.game_clock_minutes) / 1440.0)) + 3) * 1440 + 720
		_check(bool(run.advance_game_clock_minutes(target - run.game_clock_minutes).get("ok", false)), "advance while destination remained stored")
		_check(run.scenario_for_node(archetype).is_empty(), "expired room is not advertised by pure map reads")
		var before_games: Dictionary = original.get("game_states", {}).duplicate(true)
		var rng := RngStream.new(); rng.configure(run.seed_value, run.seed_value)
		var result := app.generator._world_environment_data_for_node(run, run.world_map, node, rng)
		_check(not result.is_empty() and str(result.get("environment_situation_cycle_id", "")).begins_with("venue:v1:"), "normal destination stage reconciles elapsed cycles")
		_check(_different_paths(before_games, result.get("game_states", {})).is_empty(), "destination rollover preserves all existing paid machine states")
		_check(run.environment_situation_cycle(archetype).get("history", {}).size() == old_record.get("history", {}).size() + 1, "lazy destination retires existing causal journal once")
		_check(bool(EnvironmentInstance.object_manifest_errors(result).is_empty()), "destination retains strict physical manifest")
		facts["selected"] = result.get("scenario_id", "")
	app.queue_free(); await process_frame; _finish()
