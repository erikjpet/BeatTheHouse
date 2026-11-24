extends SceneTree

const MAIN := preload("res://scenes/main.tscn")
const DESTINATION := "gas_station_casino"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var app = MAIN.instantiate()
	root.add_child(app)
	app.continuous_environment_clock_enabled = false
	app.autosave_slot_id = "test_travel"
	var failure: String = await _travel(app)
	app.pending_autosave = false
	app.save_service.wait_for_async_save()
	app.free()
	if not failure.is_empty():
		push_error(failure)
	quit(0 if failure.is_empty() else 1)


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
	if not app.select_travel_option(DESTINATION) or not app.confirm_selected_travel(true):
		return "The normal travel menu did not accept the quoted route."
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

	app.pending_autosave = false
	if app.save_service.wait_for_async_save() != OK or app.save_service.save_run(run, app.autosave_slot_id) != OK:
		return "Could not save the settled arrival."
	if not app.load_foundation_run():
		return "Could not Continue the settled arrival."
	var restored: RunState = app.run_state
	if restored == run or app.travel_presentation_active or restored.travel_journey_receipt.get("receipt_pending", true):
		return "Continue did not create a fresh run, or reopened an already acknowledged trip."
	if restored.current_world_node_id() != DESTINATION or restored.current_environment.get("id") != run.current_environment.get("id") \
			or restored.environment_travel_count() != count_before + 1 \
			or restored.bankroll != cash_before - fare or restored.grand_casino_chips != chips_before \
			or restored.inventory != items_before or restored.travel_journey_receipt.get("journey_id") != journey:
		return "Continue lost the arrival or changed settled currency, items, or travel count."
	return ""
