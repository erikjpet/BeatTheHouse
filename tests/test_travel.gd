extends SceneTree

const MAIN := preload("res://scenes/main.tscn")
const SLOT_STATE := preload("res://scripts/games/slots/slot_machine_state.gd")
const DESTINATION := "gas_station_casino"
const TRAVEL_SAVE_PREFIX := "TRAVEL_SAVE "


class CabinetEntryHost extends FoundationMain:
	func _should_stage_cabinet_open() -> bool:
		return true

	func _request_game_module_script_prewarm() -> void:
		super._request_game_module_script_prewarm()
		game_module_script_prewarm_requests.erase(SCRATCH_TICKETS_MODULE_PATH)
		game_module_script_prewarm_requests.erase("res://scripts/games/pull_tabs.gd")


class ContinueHost extends FoundationMain:
	func _should_stage_player_continue() -> bool:
		return true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var app = MAIN.instantiate()
	if arguments.is_empty():
		app.set_script(CabinetEntryHost)
	else:
		app.set_script(ContinueHost)
	root.add_child(app)
	app.continuous_environment_clock_enabled = false
	app.user_settings.coach_tips_enabled = false
	app.autosave_slot_id = "test_travel"
	var failure: String
	if arguments.is_empty():
		failure = _check_roadside_map_scout(app)
		if failure.is_empty():
			failure = await _play_and_save(app)
		if failure.is_empty():
			app.exit_game()
			await process_frame
			failure = "Normal quit did not exit after Save."
	elif arguments.size() == 2 and arguments[0] == "--continue":
		failure = await _continue(app, Marshalls.base64_to_utf8(arguments[1]))
	else:
		failure = "Expected the travel writer or its cold Continue phase."
	app.pending_autosave = false
	app.save_service.wait_for_async_save()
	app.free()
	if not failure.is_empty():
		push_error(failure)
	quit(0 if failure.is_empty() else 1)


func _play_and_save(app) -> String:
	var travel_failure := await _travel(app)
	if not travel_failure.is_empty():
		return travel_failure
	for game_id in ["scratch_tickets", "pull_tabs"]:
		var opening_failure := await _check_staged_cabinet_entry(app, game_id)
		if not opening_failure.is_empty():
			return opening_failure
	if not app.activate_interactable_object("game:slot") or app.current_game == null:
		return "The seeded arrival has no playable Slot cabinet."
	var run: RunState = app.run_state
	var machine_key: String = app.current_game_state_key
	var before := SLOT_STATE.read_machine(run.current_environment, machine_key)
	var cash_before := run.bankroll
	app._on_game_surface_action("slot_bet", 0, false)
	app._on_game_surface_action("slot_spin", 0, false)
	if not app.pending_wager_confirm_action_id.is_empty():
		app.confirm_pending_wager_action()
	await process_frame
	var after := SLOT_STATE.read_machine(run.current_environment, machine_key)
	var stake := int(after.get("coin_in", 0)) - int(before.get("coin_in", 0))
	var payout := int(after.get("coin_out", 0)) - int(before.get("coin_out", 0))
	if not app.last_game_result.get("ok", false) or stake != int(SLOT_STATE.BET_OPTIONS[0]["total_credits"]) \
			or payout < 0 or run.bankroll != cash_before - stake + payout \
			or int(after.get("spin_count", 0)) != int(before.get("spin_count", 0)) + 1:
		return "The paid Slot round did not settle exactly once."

	app.back_to_environment()
	if app.current_game != null:
		return "The settled Slot round did not return to the venue floor."
	var generation: int = app.autosave_completed_generation
	app.open_run_menu()
	app.save_run_from_menu()
	if app.autosave_completed_generation <= generation or not app.save_service.last_save_outcome.get("ok", false):
		return "The run menu did not complete a new Save."
	var expected := JSON.stringify(_resume_state(run, machine_key))
	print(TRAVEL_SAVE_PREFIX + Marshalls.utf8_to_base64(expected))
	return ""


func _check_staged_cabinet_entry(app, game_id: String) -> String:
	var cabinet := "game:%s" % game_id
	var module_path: String = app.library.game(game_id).get("module_path", "")
	var run: RunState = app.run_state
	var bankroll := run.bankroll
	var clock := run.game_clock_minutes
	app.environment_canvas.object_focused.emit(cabinet)
	await process_frame
	var preview: Dictionary = app._game_entry_preview(game_id)
	if not bool(preview.get("ok", false)) or ResourceLoader.has_cached(module_path):
		return "Inspecting %s must show its actions without loading the playable cabinet." % game_id
	app.environment_canvas.object_activated.emit(cabinet)
	if app._pending_cabinet_open.is_empty() or app.current_game != null or app.open_world_map():
		return "A cold cabinet opening must keep the run on the room floor and own room input."
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	root.push_input(cancel)
	if not app._pending_cabinet_open.is_empty() or app.current_game != null:
		return "Cancel must discard the pending cabinet opening."
	app.environment_canvas.object_activated.emit(cabinet)
	if app._pending_cabinet_open.is_empty():
		return "The canceled opening must accept another room activation."
	for frame in range(32):
		if app._pending_cabinet_open.is_empty():
			break
		if app.run_state != run or run.bankroll != bankroll or run.game_clock_minutes != clock or app.current_game != null:
			return "Cabinet preparation must keep the room and run intact."
		await process_frame
	if app.current_game == null or app.current_game.get_id() != game_id or app.current_game_state_key != game_id:
		return "Cabinet preparation must enter the original physical cabinet."
	app.back_to_environment()
	return ""


func _continue(app, expected: String) -> String:
	var snapshot: Variant = JSON.parse_string(expected)
	if not snapshot is Dictionary or str(snapshot.get("machine_key", "")).is_empty():
		return "Cold Continue did not receive a valid saved-state snapshot."
	app.autosave_loadable_available = app.save_service.has_run(app.autosave_slot_id)
	if not app.start_or_continue_primary(true) or not app._player_continue_staged:
		return "Cold Continue did not start staged restoration."
	app.new_run_button.pressed.emit()
	if app._pending_player_start.is_valid():
		return "Continue accepted another title request during restoration."
	for frame in range(240):
		if app._player_continue_staged:
			if app.run_state != null or app.run_screen.visible:
				return "Continue published the run before its restoration finished."
		if app.run_state != null and app._player_start_presentation_stage < 0:
			break
		await process_frame
	if app.run_state == null:
		return "The new process could not Continue the saved run."
	if app.save_service.last_load_result().get("outcome") != SaveService.LOAD_OUTCOME_PRIMARY:
		return "Cold Continue did not load the primary save."
	var run: RunState = app.run_state
	if app.travel_presentation_active or run.travel_journey_receipt.get("receipt_pending", true):
		return "Cold Continue replayed an acknowledged trip."
	var restored := JSON.stringify(_resume_state(run, str(snapshot["machine_key"])))
	if restored != expected:
		return "Cold Continue changed the saved location or settlement.\nExpected: %s\nRestored: %s" % [expected, restored]
	return ""


func _resume_state(run: RunState, machine_key: String) -> Dictionary:
	var machine := SLOT_STATE.read_machine(run.current_environment, machine_key)
	return {
		"seed": run.seed_text,
		"node": run.current_world_node_id(),
		"venue": run.current_environment.get("id"),
		"travel_count": run.environment_travel_count(),
		"journey_id": run.travel_journey_receipt.get("journey_id"),
		"cash": run.bankroll,
		"chips": run.grand_casino_chips,
		"items": run.inventory,
		"machine_key": machine_key,
		"spins": int(machine.get("spin_count", -1)),
		"coin_in": int(machine.get("coin_in", -1)),
		"coin_out": int(machine.get("coin_out", -1)),
	}


func _check_roadside_map_scout(app) -> String:
	const SCOUT_STOP := "motel"
	if not app.start_foundation_run("STANDARD-TRAVEL-back_alley-2", {"modifiers": {"home_archetype_id": "back_alley"}}, false):
		return "Could not start the Roadside Map run."
	app.run_state.add_item("roadside_map")
	if not app.open_world_map() or not app.select_world_map_node(SCOUT_STOP) or not app.world_map_detail_label.is_visible_in_tree():
		return "The revealed destination must open its map details."
	var scout: Dictionary = app._travel_choice(SCOUT_STOP).get("preview", {})
	var scout_lines: Array = scout.get("lines", [])
	if scout.get("level", "") != "full" or scout_lines.size() < 2:
		return "Roadside Map did not provide a full scout for the revealed destination."
	for line in scout_lines:
		if not str(line) in app.world_map_detail_label.text:
			return "The selected map stop omitted part of its full scout."
	app.close_world_map()
	return ""


func _travel(app) -> String:
	app.user_settings.reduce_motion = false
	app.travel_transition_force_web_runtime_for_test = true
	if not app.start_foundation_run("STANDARD-TRAVEL-back_alley-0", {"modifiers": {"home_archetype_id": "back_alley"}}, false):
		return "Could not start a fresh seeded travel run."
	var run: RunState = app.run_state
	var quote: Dictionary = app._travel_choice(DESTINATION)
	var fare := int(quote.get("cost", 0))
	if not quote.get("enabled", false) or fare <= 0:
		return "Travel fixture needs an open route with a positive fare: %s." % quote
	var cash_before := run.bankroll
	var chips_before := run.grand_casino_chips
	var items_before := run.inventory.duplicate(true)
	var count_before := run.environment_travel_count()
	var clock_before := run.game_clock_minutes
	if not app.open_world_map() or not app.select_world_map_node(DESTINATION):
		return "The world map did not accept the quoted route."
	app.world_map_confirm_button.pressed.emit()
	if app._pending_player_map_travel.is_empty() or run.bankroll != cash_before \
			or run.environment_travel_count() != count_before:
		return "The Travel button committed the route before its departure preparation."
	var deadline := Time.get_ticks_msec() + 20000
	var skipped_departure := false
	var staged_departure := false
	while not app._pending_player_map_travel.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
		if app._player_map_travel_staged:
			if not staged_departure and (app.return_to_main_menu() or app.leave_without_saving_confirmation.visible):
				return "Leaving during browser travel bypassed the active trip or showed a save failure."
			staged_departure = true
			if run.game_clock_minutes != clock_before or run.bankroll != cash_before or not run.travel_journey_receipt.is_empty():
				return "Browser room preparation changed the departing run."
		if (not skipped_departure and is_instance_valid(app.travel_cinematic_overlay)
				and app.travel_cinematic_overlay.departure_pending()):
			if (run.bankroll != cash_before or run.game_clock_minutes != clock_before
					or run.environment_travel_count() != count_before or not run.travel_journey_receipt.is_empty()):
				return "The departure choreography published travel before settlement."
			app.travel_cinematic_overlay.skip_to_receipt()
			if not app.travel_cinematic_overlay.departure_pending() or app.travel_cinematic_overlay.phase == "receipt":
				return "Skipping a pending departure displayed a receipt before settlement."
			skipped_departure = true
	if not staged_departure:
		return "The browser route did not prepare the destination across frames."
	if not skipped_departure:
		return "The queued route did not show its departure before settlement."
	var journey := str(run.travel_journey_receipt.get("journey_id", ""))
	if app.travel_presentation_active and is_instance_valid(app.travel_cinematic_overlay):
		app.travel_cinematic_overlay.skip_to_receipt()
		# Skip automatically acknowledges a fresh journey; reduced motion exposes Continue.
		await process_frame
		if app.travel_presentation_active and app.travel_cinematic_overlay.phase == "receipt":
			app.travel_cinematic_overlay.acknowledge()
	for frame in range(30):
		if not app.travel_presentation_active and not app.travel_transition_active:
			break
		await process_frame
	var receipt := run.travel_journey_receipt
	if journey.is_empty() or receipt.get("journey_id") != journey or receipt.get("receipt_pending", true) \
			or app.travel_presentation_active or app.travel_transition_active:
		return "Arrival did not acknowledge the committed journey."
	if run.current_world_node_id() != DESTINATION or run.environment_travel_count() != count_before + 1 \
			or receipt.get("effective_destination_environment_id") != run.current_environment.get("id") \
			or receipt.get("route_risk", {}).get("triggered", false):
		return "Fixture did not make exactly one ordinary trip to the chosen destination."
	if int(receipt.get("quoted_departure_fare", -1)) != fare or run.bankroll != cash_before - fare \
			or run.grand_casino_chips != chips_before or run.inventory != items_before:
		return "One trip must charge the quoted fare once and preserve chips and items."
	return ""
