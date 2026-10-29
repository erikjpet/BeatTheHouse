extends "res://scripts/tests/scenario_venue_cycle_captured_check.gd"
func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "private travel root"): _finish(); return
	var mode := OS.get_environment("BTH_TRAVEL033_MODE")
	if mode != "cold": _install(OS.get_environment("BTH_CAPTURED_FIXTURE"))
	facts = {"mode": mode, "test_sha256": FileAccess.get_sha256("res://scripts/tests/travel_destination_rejection_check.gd")}
	if mode == "terminal":
		var terminal: RunState = SaveService.new().load_run("foundation_ui_autosave")
		_check(terminal != null and terminal.is_terminal() and terminal.bankroll == 52 and terminal.run_failure_reason == "stranded", "original terminal copy never revived/refunded")
		_finish(); return
	root.size = Vector2i(1280, 720)
	var app := Host.new(); app.continuous_environment_clock_enabled = false; app.script_prewarm_stopping = true; root.add_child(app)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "normal private Continue"): app.queue_free(); _finish(); return
	var run: RunState = app.run_state
	facts["before"] = _travel_facts(run)
	if mode == "cold":
		_check(run.bankroll == 47 and run.current_world_node_id() == "corner_store" and not run.is_terminal(), "independent process Store47 arrival")
		_assert_arrival(app)
	else:
		_check(run.bankroll == 52 and run.current_world_node_id() == "gas_station_casino" and not run.is_terminal(), "genuine active Gas52")
		var source := run.current_environment.duplicate(true)
		var games := _all_games(run)
		var protected := _protected(run)
		_check(source.get("scenario_sequence_state", {}).get("command_receipts", []).size() == 5, "five accepted Convoy receipts")
		var node := WorldMap.node_by_id(run.world_map, "corner_store")
		var stored: Dictionary = node.get("environment", {})
		_check(str(stored.get("scenario_id", "")) == "corner_store_lotto_fever" and str(stored.get("environment_situation_cycle_id", "")) == "venue:v1:360", "genuine old Lotto opening")
		var old_fingerprint := Runtime.content_fingerprint(EnvironmentInstance._durable_sequence_state(stored.get("scenario_sequence_state", {})))
		if mode == "reject":
			_check(stored.has("scenario_semantic_digest"), "synthetic corruption targets existing sealed digest")
			stored["scenario_semantic_digest"] = "forged" # synthetic private corruption
			var map := run.world_map.duplicate(true)
			for destination in map.nodes:
				if str(destination.get("id", "")) == "corner_store": destination["environment"] = stored
			run.set_world_map(map)
			var baseline := run.to_dict()
			_check(app.open_world_map() and app.select_world_map_node("corner_store"), "normal invalid destination map selection")
			var rejected := app.confirm_world_map_travel(); facts["rejected"] = rejected
			_check(not bool(rejected.get("ok", true)) and not rejected.get("errors", []).is_empty(), "explicit invalid destination error")
			_check(run.current_world_node_id() == "gas_station_casino" and run.bankroll == 52 and not run.is_terminal(), "rejection playable Gas52 no fare/terminal")
			_check(_different_paths(protected, _protected(run)).is_empty(), "rejection preserves funds/items/debt/paid games/Heat/history/RNG")
			facts["rollback_diffs"] = _different_paths(baseline, run.to_dict())
			_check(facts.rollback_diffs.is_empty(), "entire rejected transaction including time/town/destination restored")
			_check(not _has_room_unavailable(app) and bool(run.validate_room_action_authority().get("ok", false)), "rejected trip leaves strict usable origin")
		else:
			var control := RunState.new(); control.from_dict(run.to_dict())
			app.generator._prime_town_scenarios(control, control.world_map)
			var selected: String = str(control.environment_situation_cycle("corner_store").get("scenario_id", ""))
			var recent := control.recent_scenario_ids("corner_store")
			var choice := app._travel_choice("corner_store")
			facts["quote"] = {"enabled": choice.get("enabled"), "cost": choice.get("cost"), "minutes": choice.get("travel_minutes")}
			_check(bool(choice.get("enabled", false)) and int(choice.get("cost", -1)) == 5 and int(choice.get("travel_minutes", -1)) == 36, "posted OPEN5/36 route")
			var before_clock := run.game_clock_minutes
			_check(app.open_world_map() and app.select_world_map_node("corner_store") and not app.world_map_confirm_button.disabled, "normal enabled map selection")
			var result := app.confirm_world_map_travel(); facts["travel"] = result
			for frame in range(3): await process_frame
			_check(bool(result.get("ok", false)), "normal Travel commits reopened Store")
			_check(run.bankroll == 47 and run.game_clock_minutes == before_clock + 36 and not run.is_terminal(), "one5 fare36minutes no Stranded")
			_check(str(run.current_environment.get("scenario_id", "")) == selected and run.recent_scenario_ids("corner_store") == recent, "primed selection reused no second RNG/recent lease")
			var prior_source: Dictionary = WorldMap.node_by_id(run.world_map, "gas_station_casino").get("environment", {})
			_check(_different_paths(source.get("scenario_sequence_state", {}), prior_source.get("scenario_sequence_state", {})).is_empty(), "source accepted commands/outcome unchanged")
			facts["game_diffs"] = _different_paths(games, _all_games(run))
			_check(facts.game_diffs.is_empty(), "all stored paid machine states exact")
			_assert_arrival(app)
			var history: Dictionary = run.environment_situation_cycle("corner_store").get("history", {})
			_check(history.size() == 1 and history.has("venue:v1:360|room"), "exactly one old-opening journal")
			_check(str(history.get("venue:v1:360|room", {}).get("source_fingerprint", "")) == old_fingerprint, "original causal journal retained")
			var stable := run.to_dict()
			var empty := app.generator._install_environment_with_rollback(run, {}, {}, false)
			_check(not bool(empty.get("ok", true)) and _different_paths(stable, run.to_dict()).is_empty(), "empty destination rejected before any mutation/economy")
			for repeat in range(2): app._prepare_room_presentation_at_boundary()
			_check(_different_paths(stable, run.to_dict()).is_empty(), "repeat publication no rewards/fare/reselection")
			app.save_foundation_run()
			app.save_service.wait_for_async_save()
			_check(app.return_to_main_menu(), "normal Main Menu")
			app.save_service = SaveService.new()
			_check(app.load_foundation_run(), "fresh-service Continue")
			_check(app.run_state.bankroll == 47 and not app.run_state.is_terminal(), "one arrival survives cold service")
			_check(_different_paths(games, _all_games(app.run_state)).is_empty(), "paid machine states survive Save/Continue")
			_assert_arrival(app)
	facts["after"] = _travel_facts(app.run_state)
	app.save_service.wait_for_async_save(); app.queue_free(); await process_frame; _finish()
func _assert_arrival(app: Host) -> void:
	var run: RunState = app.run_state
	_check(str(run.current_environment.get("id", "")) == "corner_store_002" and str(run.current_environment.get("environment_situation_cycle_id", "")) == "venue:v1:1800", "same Store identity new opening")
	_check(EnvironmentInstance.object_manifest_errors(run.current_environment).is_empty(), "strict destination manifest")
	_check(bool(run.validate_room_action_authority().get("ok", false)), "strict destination action authority")
	_check(not _has_room_unavailable(app) and not app._interactable_object_view_list().is_empty(), "usable destination controls")
func _all_games(run: RunState) -> Dictionary:
	var result: Dictionary = {}
	for node in run.world_map.get("nodes", []):
		var environment: Dictionary = node.get("environment", {})
		if str(node.get("id", "")) == run.current_world_node_id(): environment = run.current_environment
		if not environment.is_empty():
			var games: Dictionary = environment.get("game_states", {}).duplicate(true)
			# Existing save compaction omits only empty Scratch piles. Normalize
			# those exact defaults; every nonempty paid asset/ledger stays exact.
			if games.has("scratch_tickets"):
				var scratch: Dictionary = games.scratch_tickets
				for key in ["tray_stack", "pending_queue", "winner_pile", "loser_pile"]:
					if not scratch.has(key): scratch[key] = []
				if not scratch.has("active_ticket"): scratch["active_ticket"] = {}
				if not scratch.has("loser_archive_count"): scratch["loser_archive_count"] = 0
			result[str(node.id)] = games
	return result
func _travel_facts(run: RunState) -> Dictionary:
	return {"node": run.current_world_node_id(), "id": run.current_environment.get("id"), "cash": run.bankroll, "Heat": run.suspicion_level(), "clock": run.game_clock_minutes, "status": run.run_status, "failure": run.run_failure_reason}
