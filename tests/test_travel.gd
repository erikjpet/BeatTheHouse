extends SceneTree

const MAIN := preload("res://scenes/main.tscn")
const SLOT_STATE := preload("res://scripts/games/slots/slot_machine_state.gd")
const DESTINATION := "gas_station_casino"
const TRAVEL_SAVE_PREFIX := "TRAVEL_SAVE "


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var app = MAIN.instantiate()
	root.add_child(app)
	app.continuous_environment_clock_enabled = false
	app.user_settings.coach_tips_enabled = false
	app.autosave_slot_id = "test_travel"
	var arguments := OS.get_cmdline_user_args()
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
		failure = _continue(app, Marshalls.base64_to_utf8(arguments[1]))
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


func _continue(app, expected: String) -> String:
	var snapshot: Variant = JSON.parse_string(expected)
	if not snapshot is Dictionary or str(snapshot.get("machine_key", "")).is_empty():
		return "Cold Continue did not receive a valid saved-state snapshot."
	if not app.start_or_continue_primary() or app.run_state == null:
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
	if not app.open_world_map() or not app.select_world_map_node(DESTINATION):
		return "The world map did not accept the quoted route."
	app.world_map_confirm_button.pressed.emit()
	if app._pending_player_map_travel.is_empty() or run.bankroll != cash_before \
			or run.environment_travel_count() != count_before:
		return "The Travel button committed the route before its departure preparation."
	var deadline := Time.get_ticks_msec() + 20000
	while not app._pending_player_map_travel.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
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
