extends SceneTree

const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")

var failures: Array[String] = []
var signal_order: Array[String] = []
var locked_request: Dictionary = {}
var layout_request: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var canvas: PixelSceneCanvas = PixelSceneCanvasScript.new()
	canvas.size = Vector2(900.0, 430.0)
	root.add_child(canvas)
	await process_frame
	canvas.developer_placement_lock_requested.connect(_capture_lock)
	canvas.developer_layout_save_requested.connect(_capture_layout)
	canvas.render_environment_snapshot({
		"archetype_id": "corner_store",
		"display_name": "Corner Store",
		"scenario_id": "corner_store_lotto_fever",
		"scenario_state": {"id": "corner_store_lotto_fever"},
		"scenario_sequence_state": {
			"scenario_id": "corner_store_lotto_fever",
			"phase_id": "arrival",
			"status": "active",
		},
		"developer_placement_progress": {
			"layout_id": "corner_store::corner_store_lotto_fever",
			"saved": false,
			"saved_layout_count": 12,
			"expected_layout_count": 75,
			"missing_layout_count": 63,
			"next_missing_layout_id": "corner_store::corner_store_lotto_fever",
			"complete": false,
		},
		"interactable_objects": [],
	})
	canvas.set_developer_slot_placement_mode(true)
	await process_frame

	_check(
		canvas.developer_layout_save_button != null
			and canvas.developer_layout_save_button.visible
			and canvas.developer_layout_save_button.text == "Save Current Layout",
		"Slot placement mode must expose a prominent Save Current Layout action."
	)
	_check(
		canvas.developer_slot_context_label != null
			and canvas.developer_slot_context_label.text.contains("corner_store::corner_store_lotto_fever | NOT SAVED")
			and canvas.developer_slot_context_label.text.contains("Progress: 12/75 saved | 63 remaining")
			and canvas.developer_slot_context_label.text.contains("Next missing:"),
		"Slot placement mode must keep the exact context, saved state, coverage, and next missing layout visible."
	)
	_apply_maximum_accessibility_fixture(canvas.developer_placement_panel)
	canvas.call("_update_developer_placement_panel")
	await process_frame
	await process_frame
	var available_rect := Rect2(
		Vector2(PixelSceneCanvasScript.DEVELOPER_PANEL_MARGIN, PixelSceneCanvasScript.DEVELOPER_PANEL_MARGIN),
		canvas.size - Vector2.ONE * PixelSceneCanvasScript.DEVELOPER_PANEL_MARGIN * 2.0
	)
	var panel_rect := canvas.developer_placement_panel.get_rect()
	_check(available_rect.encloses(panel_rect), "The placement panel must remain clamped inside a 900x430 environment canvas at maximum accessibility scale.")
	var scroll := canvas.developer_placement_scroll
	var vertical_scroll := scroll.get_v_scroll_bar()
	var horizontal_scroll := scroll.get_h_scroll_bar()
	_check(
		vertical_scroll.visible and vertical_scroll.max_value > vertical_scroll.page,
		"An overflowing accessibility layout must expose a usable vertical scrollbar."
	)
	_check(not horizontal_scroll.visible and scroll.scroll_horizontal == 0, "Wrapped placement controls must not require horizontal scrolling.")
	var scroll_rect := scroll.get_global_rect()
	for button_value in canvas.developer_slot_filter_buttons.values():
		var button := button_value as BaseButton
		_check(
			button.custom_minimum_size.y >= 52.0
				and button.get_global_rect().position.x >= scroll_rect.position.x - 0.5
				and button.get_global_rect().end.x <= scroll_rect.end.x + 0.5,
			"Every family filter must wrap within the scroll viewport and retain its 52px touch target."
		)
	scroll.ensure_control_visible(canvas.developer_layout_save_button)
	await process_frame
	_check(scroll.get_global_rect().encloses(canvas.developer_layout_save_button.get_global_rect()), "Save Current Layout must be reachable by scrolling at maximum accessibility scale.")
	scroll.ensure_control_visible(canvas.developer_placement_export_button)
	await process_frame
	_check(scroll.get_global_rect().encloses(canvas.developer_placement_export_button.get_global_rect()), "Export Placement Report must be reachable by scrolling at maximum accessibility scale.")
	canvas.developer_placement_export_button.grab_focus()
	await process_frame
	_check(scroll.get_global_rect().encloses(canvas.developer_placement_export_button.get_global_rect()), "Keyboard focus must keep the final placement action inside the scroll viewport.")
	var all_slots: Array = canvas.call("_developer_slots", true)
	var initial_request: Dictionary = canvas.call("_developer_full_slot_layout_request")
	var initial_positions: Dictionary = initial_request.get("full_positions", {})
	_check(
		not all_slots.is_empty() and initial_positions.size() == all_slots.size(),
		"The full-layout payload must include every active effective slot, including hidden families and capacity."
	)
	for slot_value in all_slots:
		var slot := slot_value as Dictionary
		var slot_id := str(slot.get("id", ""))
		_check(initial_positions.has(slot_id), "The full-layout payload omitted active slot %s." % slot_id)
		_check(typeof(initial_positions.get(slot_id)) == TYPE_VECTOR2, "Saved slot %s must carry a Vector2 position." % slot_id)

	var moved_slot: Dictionary = canvas.call("_developer_slot", "fixed.item_shop_1")
	_check(not moved_slot.is_empty(), "The UI fixture requires fixed.item_shop_1.")
	if not moved_slot.is_empty():
		var original_position: Vector2 = canvas.call("_developer_slot_position", moved_slot)
		var rect: Rect2 = canvas.call("_developer_slot_rect", moved_slot)
		var delta := Vector2(12.0, 8.0)
		canvas.developer_slot_selected_id = "fixed.item_shop_1"
		canvas.call("_begin_developer_slot_placement_drag", rect.get_center())
		canvas.call("_update_developer_slot_placement_preview", rect.position + delta)
		canvas.developer_layout_save_button.pressed.emit()
		var positions: Dictionary = layout_request.get("full_positions", {})
		_check(signal_order == ["lock", "layout"], "Save Current Layout must lock a valid pending drag before emitting the full snapshot.")
		_check(str((layout_request.get("environment", {}) as Dictionary).get("scenario_id", "")) == "corner_store_lotto_fever", "The layout payload must preserve the exact scenario context.")
		_check(str(layout_request.get("field", "")) == "slot_positions", "The layout payload must target slot_positions.")
		_check(int(layout_request.get("slot_count", -1)) == all_slots.size(), "The layout payload slot count must match the complete active slot set.")
		_check((positions.get("fixed.item_shop_1", Vector2.ZERO) as Vector2).is_equal_approx(original_position + delta), "The full snapshot must contain the newly locked pending position.")

	canvas.set_developer_placement_mode(true)
	_check(not canvas.developer_layout_save_button.visible, "Save Current Layout must stay hidden in spawned-object placement mode.")
	canvas.queue_free()
	await process_frame

	if failures.is_empty():
		print("DEVELOPER_LAYOUT_SAVE_UI_CHECK PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _capture_lock(request: Dictionary) -> void:
	signal_order.append("lock")
	locked_request = request.duplicate(true)


func _capture_layout(request: Dictionary) -> void:
	signal_order.append("layout")
	layout_request = request.duplicate(true)


func _apply_maximum_accessibility_fixture(node: Node) -> void:
	var control := node as Control
	if control != null:
		if control is Label or control is BaseButton:
			control.add_theme_font_size_override("font_size", 24)
		if control is BaseButton:
			control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, 52.0)
	for child in node.get_children():
		_apply_maximum_accessibility_fixture(child)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
