extends SceneTree

const MAIN := preload("res://scenes/main.tscn")
const SLOT_STATE := preload("res://scripts/games/slots/slot_machine_state.gd")
const ROOM := "gas_station_casino"
const ROUND_LIMIT := 24


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var app = MAIN.instantiate()
	root.add_child(app)
	app.continuous_environment_clock_enabled = false
	app.user_settings.coach_tips_enabled = false
	app.user_settings.reduce_motion = true
	var failure: String = await _play_run(app)
	app.pending_autosave = false
	app.save_service.wait_for_async_save()
	app.free()
	if not failure.is_empty():
		push_error(failure)
	quit(0 if failure.is_empty() else 1)


func _play_run(app) -> String:
	if not app.start_foundation_run("SMALL-WALLET", {"modifiers": {"home_archetype_id": "back_alley"}}, false):
		return "The bot could not start a fresh run."
	var run: RunState = app.run_state
	if not app.select_travel_option(ROOM) or not app.confirm_selected_travel(true):
		return "The bot could not take the ordinary route to its casino."
	if app.travel_presentation_active and is_instance_valid(app.travel_cinematic_overlay):
		app.travel_cinematic_overlay.skip_to_receipt()
		app.travel_cinematic_overlay.acknowledge()
	for frame in range(30):
		if not app.travel_presentation_active and not app.travel_transition_active:
			break
		await process_frame
	app.back_to_environment()
	if run.current_world_node_id() != ROOM or not app.enter_game("slot"):
		return "The bot arrived without access to the generated Slot cabinet."

	var rounds := 0
	for round_index in range(ROUND_LIMIT):
		if run.is_terminal():
			break
		var machine := SLOT_STATE.read_machine(run.current_environment, app.current_game_state_key)
		var bet_index := _choose_bet(run.bankroll)
		if bet_index < 0:
			return "The bot could not choose an affordable stake with $%d remaining." % run.bankroll
		app._on_game_surface_action("slot_bet", bet_index, false)
		app._on_game_surface_action("slot_spin", 0, false)
		if not app.pending_wager_confirm_action_id.is_empty():
			app.confirm_pending_wager_action()
		await process_frame
		var settled := SLOT_STATE.read_machine(run.current_environment, app.current_game_state_key if app.current_game != null else "slot")
		if int(settled.get("spin_count", -1)) != int(machine.get("spin_count", -1)) + 1:
			return "Slot never settled round %d (cash $%d, result %s)." % [round_index + 1, run.bankroll, app.last_game_result.get("action_id", "none")]
		rounds += 1
		if not run.has_liquid_run_funds():
			app.back_to_environment()
		# Wait for the ordinary result to be readable before pressing Spin again.
		for step in range(240):
			if run.is_terminal() or not app.game_surface_canvas.surface_animation_active("slot_spin"):
				break
			await process_frame

	if rounds < 2 or not run.is_terminal() or run.run_failure_reason != RunState.FAILURE_BANKROLL_ZERO \
			or run.run_status != RunState.RUN_STATUS_FAILED or run.bankroll != 0:
		return "The bot did not reach the natural broke ending: %d rounds, %s, %s, $%d." % [rounds, run.run_status, run.run_failure_reason, run.bankroll]
	return ""


func _choose_bet(cash: int) -> int:
	# First spend odd cash on an odd stake; then prefer the largest wager that
	# does not leave a wallet smaller than the cabinet's minimum stake.
	var stakes := [2, 5, 10, 15, 20]
	if cash % 2 != 0 and cash >= 5:
		return 3 if cash >= 15 else 1
	for index in range(stakes.size() - 1, -1, -1):
		if cash >= stakes[index] and cash - stakes[index] != 1:
			return index
	return -1
