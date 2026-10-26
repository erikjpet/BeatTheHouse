extends SceneTree

const ScreenScript := preload("res://scripts/ui/run_inventory_screen.gd")
var failures: Array[String] = []
var checks := 0
var actions := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for count in [7, 8, 20]:
		root.size = Vector2i(1280, 720)
		var screen := ScreenScript.new()
		root.add_child(screen)
		screen.sell_requested.connect(func(_id: String): actions += 1)
		screen.repair_requested.connect(func(_id: String): actions += 1)
		var model := _model(count)
		var original := JSON.stringify(model)
		screen.open(model)
		for frame in range(4): await process_frame
		var surface: InventoryContainerSurface = screen.get("_container_surface")
		var snapshot := surface.layout_snapshot()
		var shown := _keys(snapshot)
		var heading: Label = surface.get("_container_label")
		var pages := int(snapshot.get("visible_page_count", 0))
		_check(shown.size() == count or pages > 1, "Fresh %d-item screen leaves items outside its navigable pages." % count)
		_check(heading.text.contains("Page") == (pages > 1), "Fresh %d-item heading disagrees with settled page count." % count)
		var next: Button = surface.get("_next_button")
		for step in range(count + 2):
			if shown.size() == count: break
			next.pressed.emit()
			await process_frame
			_check(surface.active_container_key() == "carried", "Next skips unseen carried items in %d-item screen." % count)
			if surface.active_container_key() != "carried": break
			for key in _keys(surface.layout_snapshot()): shown[key] = true
		_check(shown.size() == count, "Fresh %d-item navigation missed %d owned items." % [count, count - shown.size()])
		screen.select_item("item_%02d" % (count - 1), "carried", false)
		root.size = Vector2i(960, 640)
		screen.refresh_layout()
		for frame in range(4): await process_frame
		_check(_keys(surface.layout_snapshot()).has("carried:%d" % (count - 1)), "Resize hid the selected last item in %d-item screen." % count)
		_check(JSON.stringify(model) == original and actions == 0, "Presentation reflow mutated input or submitted an item action.")
		screen.queue_free()
		await process_frame
	if failures.is_empty(): print("INVENTORY_CARD_RESIZE_PAGING PASS checks=%d actions=%d" % [checks, actions])
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _model(count: int) -> Dictionary:
	var items: Array = []
	var slots: Array = []
	for index in range(count):
		var item := {"id": "item_%02d" % index, "display_name": "Item %02d" % index, "storage_source": "carried", "selection_key": "carried:%d" % index, "can_sell": true, "sell_price": 22}
		items.append(item)
		slots.append({"slot_index": index, "occupied": true, "actionable": true, "selection_key": item.selection_key, "item": item})
	return {"mode": "sell", "title": "Sell Items", "summary": "Resize paging fixture", "items": items, "selected": {"id": "item_00", "source": "carried"}, "selected_key": "carried:0", "layout": {"presentation": "grouped_card_grid"}, "containers": [{"key": "carried", "container_type": "loose_carry", "display_name": "Loose Carry", "capacity": 0, "slots": slots}, {"key": "bag", "container_type": "bag", "display_name": "Bag", "capacity": 3, "slots": []}]}

func _keys(snapshot: Dictionary) -> Dictionary:
	var keys := {}
	for slot in snapshot.get("slots", []):
		if bool(slot.get("occupied", false)): keys[str(slot.get("selection_key", ""))] = true
	return keys

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
