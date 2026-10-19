extends SceneTree

# Focused regression: the tangible counter's visible card must reach the
# existing redemption transaction, including after restoring a run snapshot.
const MainScene := preload("res://scenes/main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "ticket_counter_regression")
	root.add_child(app)
	await process_frame
	await process_frame
	for scenario in ["__none", "gas_station_trucker_convoy", "gas_station_tour_bus_stop", "gas_station_graveyard_shift", "gas_station_road_crew_payday", "gas_station_storm_shelter"]:
		var installed: Dictionary = {}
		var run: RunState
		# Sequence-owned scenarios must match the seeded destination definition;
		# choose a matching seed instead of bypassing that generation authority.
		for attempt in range(24):
			app.call("start_foundation_run", "TICKET-COUNTER-%s-%d" % [scenario, attempt], {}, false)
			run = app.get("run_state")
			var generator: RunGenerator = app.get("generator")
			installed = generator.environment_test_result(run, {"archetype_id": "gas_station_casino", "scenario_id": scenario})
			if bool(installed.get("ok", false)):
				break
		_check(bool(installed.get("ok", false)), "%s generation: %s" % [scenario, installed.get("errors", [])])
		if not bool(installed.get("ok", false)):
			continue
		app.call("_set_current_screen", "ENVIRONMENT")
		app.call("_refresh_runtime_environment_views")
		var records: Array = app.call("_interactable_object_view_list")
		var counter: Dictionary = {}
		for record in records:
			if str(record.get("object_id", "")) == "character:nell":
				counter = record
		_check(not counter.is_empty(), "%s has no Nell counter." % scenario)
		var canvas: Control = app.get("environment_canvas")
		canvas.call("set_selected_object", "character:nell")
		var actions: Array = canvas.call("_selected_info_inline_actions", canvas.call("_scene_object", "character:nell"))
		var cash_action: Dictionary = {}
		var pull_action: Dictionary = {}
		for action in actions:
			if str(action.get("label", "")) == "Cash In Scratchers":
				cash_action = action
			if str(action.get("label", "")) == "Cash In Pull Tabs":
				pull_action = action
		_check(not pull_action.is_empty(), "%s visible counter has no Cash In Pull Tabs." % scenario)
		_check(not cash_action.is_empty(), "%s visible counter has no Cash In Scratchers." % scenario)
		if cash_action.is_empty():
			continue
		var game: GameModule = app.call("_game_module_for_id", "scratch_tickets")
		var environment := run.current_environment
		var machine: Dictionary = environment.game_states.scratch_tickets
		var winner: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", "golden_vault"), run.create_rng("counter-ticket"), 0, "counter")
		winner["payout"] = 5
		winner["settled"] = true
		machine["winner_pile"] = [winner]
		environment.game_states.scratch_tickets = machine
		run.capture_portable_ticket_piles_from_environment(environment)
		# Restore through the production save schema before consuming the winner.
		var saved := run.to_dict()
		run.from_dict(saved)
		app.call("_refresh_runtime_environment_views")
		var before := run.bankroll
		var inventory_before := run.inventory.duplicate(true)
		await create_timer(0.2).timeout
		app.call("_on_environment_object_activated", str(cash_action.get("emit_object_id", "")))
		_check(run.bankroll == before + 5, "%s visible counter paid %d instead of exactly $5 after restore." % [scenario, run.bankroll - before])
		_check((run.current_environment.game_states.scratch_tickets.get("winner_pile", []) as Array).is_empty(), "%s retained redeemed winners." % scenario)
		var after := run.bankroll
		var second: Dictionary = game.environment_action_command("scratch_ticket_clerk", "redeem_scratch_winners", run, run.current_environment, run.create_rng("empty-counter"))
		GameModule.apply_result(run, second.get("result", {}), run.create_rng("empty-apply"))
		_check(run.bankroll == after, "%s paid the same winner twice or paid with no tickets." % scenario)
		var inventory_after := run.inventory.duplicate(true)
		inventory_before.erase(RunState.SCRATCH_TICKET_PILE_ITEM_ID)
		inventory_after.erase(RunState.SCRATCH_TICKET_PILE_ITEM_ID)
		_check(inventory_after == inventory_before, "%s changed unrelated inventory during cashout." % scenario)
		print("TICKET_COUNTER scenario=%s cash_delta=%d repeat_delta=%d" % [scenario, after - before, run.bankroll - after])
		var pull: GameModule = app.call("_game_module_for_id", "pull_tabs")
		var pull_machine: Dictionary = run.current_environment.game_states.pull_tabs
		pull_machine["winner_pile"] = [{"id": "counter:pull:%s" % scenario, "display_name": "Test Pull Tab", "payout": 7, "price": 1, "revealed": true}]
		run.current_environment.game_states.pull_tabs = pull_machine
		run.capture_portable_ticket_piles_from_environment(run.current_environment)
		run.from_dict(run.to_dict())
		app.call("_set_current_screen", "ENVIRONMENT")
		app.call("_refresh_runtime_environment_views")
		var pull_before := run.bankroll
		await create_timer(0.2).timeout
		app.call("_on_environment_object_activated", str(pull_action.get("emit_object_id", "")))
		_check(run.bankroll == pull_before + 7, "%s Pull Tabs counter did not pay exactly $7 after restore." % scenario)
		var pull_second: Dictionary = pull.environment_action_command("ticket_redeemer", "redeem_pull_tab_winners", run, run.current_environment, run.create_rng("empty-pull"))
		GameModule.apply_result(run, pull_second.get("result", {}), run.create_rng("empty-pull-apply"))
		_check(run.bankroll == pull_before + 7, "%s Pull Tabs paid twice with no winners." % scenario)
		print("PULL_COUNTER scenario=%s cash_delta=%d" % [scenario, run.bankroll - pull_before])
	app.queue_free()
	await process_frame
	if failures.is_empty():
		print("TICKET_COUNTER_REDEMPTION_CHECK PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
