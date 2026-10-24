extends SceneTree

const SurfaceScript := preload("res://scripts/ui/inventory_container_surface.gd")
var failures: Array[String] = []
var checks := 0
var confirmed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for compact in [false, true]:
		var surface := SurfaceScript.new()
		surface.size = Vector2(420, 420) if not compact else Vector2(310, 400)
		root.add_child(surface)
		surface.configure(Callable())
		surface.set_small_screen_mode(compact)
		surface.slot_confirmed.connect(func(_key: String): confirmed += 1)
		var model := {"layout": {"presentation": "grouped_card_grid"}, "containers": [
			_container("carried", "Carried Items", 2), _container("tickets", "Pawn Tickets", 1),
		], "selected_key": "carried:0"}
		var original := JSON.stringify(model)
		surface.update_model(model)
		await process_frame
		var next_button: Button = surface.get("_next_button")
		var previous_button: Button = surface.get("_previous_button")
		var heading: Label = surface.get("_container_label")
		_check(next_button.visible and previous_button.visible, "Two one-page containers hide their navigation.")
		_check(heading.text.contains("Carried Items") and heading.text.contains("2"), "Heading does not identify the rendered carried container.")
		next_button.pressed.emit()
		await process_frame
		_check(surface.active_container_key() == "tickets", "Next did not reach pawn tickets.")
		_check(surface.layout_snapshot().get("rendered_slot_count", 0) == 1 and surface.selected_key() == "tickets:0", "Ticket was not visibly selected.")
		_check(heading.text.contains("Pawn Tickets") and heading.text.contains("1"), "Heading does not identify the rendered ticket container.")
		previous_button.pressed.emit()
		_check(surface.active_container_key() == "carried", "Previous did not return to carried items.")
		_check(JSON.stringify(model) == original and confirmed == 0, "Navigation mutated the input model or confirmed an item action.")
		surface.update_model({"layout": {"presentation": "grouped_card_grid"}, "containers": [_container("only", "Only", 1)], "selected_key": "only:0", "focus_explicit": true})
		_check(not next_button.visible and not previous_button.visible, "Single page exposes unnecessary navigation.")
		surface.update_model({"layout": {"presentation": "grouped_card_grid"}, "containers": [_container("many", "Many", 20)], "selected_key": "many:0", "focus_explicit": true})
		_check(next_button.visible and previous_button.visible, "Existing multi-page navigation disappeared.")
		next_button.pressed.emit()
		_check(surface.active_container_key() == "many" and surface.layout_snapshot().get("active_page_index", 0) == 1, "Next did not advance within a paged container.")
		previous_button.pressed.emit()
		_check(surface.layout_snapshot().get("active_page_index", -1) == 0, "Previous did not return to first page.")
		surface.update_model({"layout": {"presentation": "grouped_card_grid"}, "containers": [_container("empty", "Empty", 0), _container("tickets", "Pawn Tickets", 1)], "selected_key": "", "focus_explicit": true})
		_check(next_button.visible and previous_button.visible, "An empty carried container hides the ticket switcher.")
		surface.queue_free()
		await process_frame
	if failures.is_empty(): print("INVENTORY_CARD_CONTAINER_NAVIGATION PASS checks=%d desktop_and_compact=true model_unchanged=true no_item_confirmation=true" % checks)
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _container(key: String, title: String, count: int) -> Dictionary:
	var slots: Array = []
	for index in range(count):
		slots.append({"slot_index": index, "occupied": true, "selection_key": "%s:%d" % [key, index], "item": {"id": "%s_%d" % [key, index], "display_name": "%s %d" % [title, index]}})
	return {"key": key, "container_type": "loose_carry", "display_name": title, "capacity": 0, "slots": slots}

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
