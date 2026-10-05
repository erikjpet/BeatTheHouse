extends SceneTree

const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")

var failures: Array[String] = []
var signal_order: Array[String] = []
var locked_request: Dictionary = {}
var layout_request: Dictionary = {}
var reset_request_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var canvas: PixelSceneCanvas = PixelSceneCanvasScript.new()
	canvas.size = Vector2(900.0, 430.0)
	root.add_child(canvas)
	await process_frame
	canvas.developer_placement_lock_requested.connect(_capture_lock)
	canvas.developer_placement_reset_requested.connect(_capture_reset)
	canvas.developer_layout_save_requested.connect(_capture_layout)
	var lotto_snapshot := {
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
			"practice_session": true,
		},
		"interactable_objects": [],
	}
	canvas.render_environment_snapshot(lotto_snapshot)
	canvas.set_developer_slot_placement_mode(true)
	await process_frame

	_check(
		canvas.developer_layout_save_button != null
			and canvas.developer_layout_save_button.visible
			and canvas.developer_layout_save_button.text == "Save Current Layout",
		"Slot placement mode must expose a prominent Save Current Layout action."
	)
	_check(
		canvas.developer_layout_save_next_button != null
			and canvas.developer_layout_save_next_button.visible
			and canvas.developer_layout_save_next_button.text == "Save & Load Next Missing",
		"A practice placement pass must expose the one-click Save & Load Next Missing action."
	)
	_check(
		canvas.developer_placement_minimize_button != null
			and canvas.developer_placement_minimize_button.visible
			and canvas.developer_placement_restore_button != null
			and not canvas.developer_placement_restore_button.visible,
		"Placement mode must expose a clear Minimize control while keeping Restore out of the way."
	)
	await process_frame
	await process_frame
	var expanded_panel_rect := canvas.developer_placement_panel.get_rect()
	var covered_slot: Dictionary = {}
	var covered_local_position := Vector2.ZERO
	var expected_clicked_slot_id := ""
	for slot_value in canvas.call("_developer_slots"):
		var candidate := slot_value as Dictionary
		var candidate_position: Vector2 = canvas.call("_board_to_local_position", canvas.call("_developer_slot_rect", candidate).get_center())
		var candidate_id := str(canvas.call("_developer_slot_id_at_local_position", candidate_position))
		if expanded_panel_rect.has_point(candidate_position) \
				and not canvas.developer_placement_restore_button.get_rect().has_point(candidate_position) \
				and not candidate_id.is_empty():
			covered_slot = candidate
			covered_local_position = candidate_position
			expected_clicked_slot_id = candidate_id
			break
	_check(
		not covered_slot.is_empty() and not expected_clicked_slot_id.is_empty(),
		"The click-through fixture must find a visible, selectable slot beneath the expanded menu."
	)
	canvas.developer_placement_minimize_button.pressed.emit()
	await process_frame
	_check(
		bool(canvas.developer_slot_placement_snapshot().get("panel_minimized", false))
			and not canvas.developer_placement_panel.visible
			and canvas.developer_placement_restore_button.visible
			and canvas.developer_placement_restore_button.has_focus(),
		"Minimize must fully hide the blocking menu, expose Restore, and transfer keyboard focus."
	)
	canvas.developer_slot_selected_id = ""
	await _click_canvas(canvas, covered_local_position)
	_check(
		not expected_clicked_slot_id.is_empty() and canvas.developer_slot_selected_id == expected_clicked_slot_id,
		"A visible slot beneath the former menu rectangle must be selectable while the menu is minimized (expected %s, selected %s)." % [expected_clicked_slot_id, canvas.developer_slot_selected_id]
	)
	canvas.call("_finish_developer_slot_placement_edit")
	canvas.developer_slot_selected_id = ""
	canvas.developer_slot_hovered_id = ""
	canvas.developer_placement_restore_button.pressed.emit()
	await process_frame
	_check(
		not bool(canvas.developer_slot_placement_snapshot().get("panel_minimized", true))
			and canvas.developer_placement_panel.visible
			and not canvas.developer_placement_restore_button.visible
			and canvas.developer_placement_minimize_button.has_focus(),
		"Restore must bring back the complete menu and return focus to Minimize."
	)
	var initial_slot_snapshot := canvas.developer_slot_placement_snapshot()
	_check(
		(initial_slot_snapshot.get("marker_label_ids", []) as Array).is_empty(),
		"Unselected markers must stay compact instead of drawing dozens of colliding labels."
	)
	var visible_slots: Array = canvas.call("_developer_slots")
	if not visible_slots.is_empty():
		var hovered_id := str((visible_slots[0] as Dictionary).get("id", ""))
		canvas.developer_slot_hovered_id = hovered_id
		canvas.call("_update_developer_placement_panel")
		var hover_snapshot := canvas.developer_slot_placement_snapshot()
		_check(
			(hover_snapshot.get("marker_label_ids", []) as Array) == [hovered_id]
				and canvas.developer_placement_label.text.contains(hovered_id),
			"Hovering one marker must expose only that marker's stable ID and panel details."
		)
		canvas.developer_slot_hovered_id = ""
		canvas.call("_update_developer_placement_panel")
	var distribution_override := OS.get_environment("BTH_DISTRIBUTION_BUILD")
	OS.set_environment("BTH_DISTRIBUTION_BUILD", "1")
	canvas.call("_update_developer_placement_panel")
	_check(
		canvas.developer_placement_promote_button != null and not canvas.developer_placement_promote_button.visible,
		"Packaged/distribution builds must hide the source-checkout-only Save to Project action."
	)
	OS.set_environment("BTH_DISTRIBUTION_BUILD", distribution_override)
	canvas.call("_update_developer_placement_panel")
	_check(
		canvas.developer_slot_context_label != null
			and canvas.developer_slot_context_label.text.contains("corner_store::corner_store_lotto_fever | NOT SAVED")
			and canvas.developer_slot_context_label.text.contains("SCENARIO-LOCAL editing")
			and canvas.developer_slot_context_label.text.contains("ROOM-SHARED markers are locked")
			and canvas.developer_slot_context_label.text.contains("Progress: 12/75 saved | 63 remaining")
			and canvas.developer_slot_context_label.text.contains("Next missing:"),
		"Slot placement mode must keep the exact context, saved state, coverage, and next missing layout visible."
	)
	_check(
		canvas.developer_placement_export_button.tooltip_text.contains("complete effective placement authority"),
		"The in-game export help must describe the self-contained effective placement report."
	)

	# Visibility choices are temporary to one layout. Load Next Missing must always
	# reopen a complete review surface and relock shared room geometry.
	canvas.set_developer_slot_show_empty_capacity(false)
	canvas.set_developer_slot_show_runtime_reserves(false)
	canvas.set_developer_slot_edit_shared_in_scenario(true)
	canvas.developer_placement_minimize_button.pressed.emit()
	canvas.render_environment_snapshot({
		"archetype_id": "corner_store",
		"display_name": "Corner Store",
		"scenario_id": "corner_store_dead_shift",
		"scenario_state": {"id": "corner_store_dead_shift"},
		"scenario_sequence_state": {
			"scenario_id": "corner_store_dead_shift",
			"phase_id": "arrival",
			"status": "active",
		},
		"interactable_objects": [],
	})
	var changed_context := canvas.developer_slot_placement_snapshot()
	_check(
		bool(changed_context.get("show_empty_capacity", false))
			and bool(changed_context.get("show_runtime_reserves", false))
			and not bool(changed_context.get("edit_shared_in_scenario", true)),
		"Every new layout must restore complete marker visibility and relock ROOM-SHARED positions."
	)
	_check(
		bool(changed_context.get("panel_minimized", false)) and canvas.developer_placement_restore_button.visible,
		"Loading another environment/scenario must preserve the minimized menu so it does not block the next room."
	)
	canvas.developer_placement_restore_button.pressed.emit()
	canvas.developer_slot_selected_id = "fixed.item_shop_1"
	var nudge := InputEventAction.new()
	nudge.action = "ui_right"
	nudge.pressed = true
	canvas.call("_handle_developer_slot_placement_input", nudge)
	canvas.call("_reset_active_developer_placement")
	_check(
		not bool(canvas.developer_slot_placement_snapshot().get("pending", true))
			and reset_request_count == 0,
		"Keyboard nudging and Reset must not mutate a locked ROOM-SHARED marker."
	)
	canvas.render_environment_snapshot(lotto_snapshot)
	var base_snapshot := lotto_snapshot.duplicate(true)
	base_snapshot["scenario_id"] = ""
	base_snapshot["scenario_state"] = {}
	base_snapshot["scenario_sequence_state"] = {}
	(base_snapshot["developer_placement_progress"] as Dictionary)["layout_id"] = "corner_store::base"
	canvas.render_environment_snapshot(base_snapshot)
	var base_review := canvas.developer_slot_placement_snapshot()
	var base_required: Array = base_review.get("required_review_families", [])
	_check(
		base_required.size() > 1
			and not bool(base_review.get("review_ready", true))
			and canvas.developer_layout_save_button.disabled,
		"A base layout must remain unsavable until every nonempty family tab has been visited."
	)
	var signal_count_before_blocked_save := signal_order.size()
	canvas.call("_save_current_developer_slot_layout")
	_check(signal_order.size() == signal_count_before_blocked_save, "An incomplete base-family review must not emit a layout save.")
	for family_value in base_required:
		canvas.set_developer_slot_family_visible(str(family_value), true)
	var completed_base_review := canvas.developer_slot_placement_snapshot()
	_check(
		bool(completed_base_review.get("review_ready", false))
			and (completed_base_review.get("missing_review_families", []) as Array).is_empty()
			and not canvas.developer_layout_save_button.disabled,
		"Visiting every required base family must make the layout ready to save."
	)
	canvas.render_environment_snapshot(lotto_snapshot)
	_apply_maximum_accessibility_fixture(canvas.developer_placement_panel)
	_apply_maximum_accessibility_fixture(canvas.developer_placement_restore_button)
	canvas.call("_update_developer_placement_panel")
	await process_frame
	await process_frame
	var available_rect := Rect2(
		Vector2(PixelSceneCanvasScript.DEVELOPER_PANEL_MARGIN, PixelSceneCanvasScript.DEVELOPER_PANEL_MARGIN),
		canvas.size - Vector2.ONE * PixelSceneCanvasScript.DEVELOPER_PANEL_MARGIN * 2.0
	)
	var panel_rect := canvas.developer_placement_panel.get_rect()
	_check(available_rect.encloses(panel_rect), "The placement panel must remain clamped inside a 900x430 environment canvas at maximum accessibility scale.")
	_check(
		canvas.developer_placement_panel.get_global_rect().encloses(canvas.developer_placement_minimize_button.get_global_rect())
			and not canvas.developer_placement_scroll.is_ancestor_of(canvas.developer_placement_minimize_button),
		"Minimize must remain in a fixed header instead of scrolling out of reach."
	)
	canvas.developer_placement_minimize_button.pressed.emit()
	await process_frame
	var restore_rect := canvas.developer_placement_restore_button.get_rect()
	_check(
		available_rect.encloses(restore_rect)
			and restore_rect.size.y >= 52.0
			and not panel_rect.intersects(restore_rect),
		"Restore must remain a reachable, low-obstruction control at 900x430 and maximum text scale."
	)
	canvas.developer_placement_restore_button.pressed.emit()
	await process_frame
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
		canvas.set_developer_slot_edit_shared_in_scenario(true)
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
		signal_order.clear()
		layout_request.clear()
		canvas.developer_layout_save_next_button.pressed.emit()
		_check(
			signal_order == ["layout"] and bool(layout_request.get("load_next_missing", false)),
			"Save & Load Next Missing must emit one synchronous full-layout request with the advance flag."
		)

	canvas.set_developer_placement_mode(true)
	_check(not canvas.developer_layout_save_button.visible, "Save Current Layout must stay hidden in spawned-object placement mode.")
	canvas.developer_placement_minimize_button.grab_focus()
	await _send_key(KEY_F2)
	_check(
		bool(canvas.developer_placement_snapshot().get("panel_minimized", false))
			and canvas.developer_placement_restore_button.visible
			and canvas.developer_placement_restore_button.has_focus(),
		"F2 must minimize the menu and transfer focus in spawned-object placement mode (snapshot %s, focus %s)." % [canvas.developer_placement_snapshot(), str(canvas.get_viewport().gui_get_focus_owner())]
	)
	await _send_key(KEY_F2)
	_check(
		not bool(canvas.developer_placement_snapshot().get("panel_minimized", true))
			and canvas.developer_placement_panel.visible
			and canvas.developer_placement_minimize_button.has_focus(),
		"A second F2 must restore the menu even after focus moved to Restore."
	)
	canvas.developer_placement_minimize_button.pressed.emit()
	canvas.set_developer_placement_mode(false)
	_check(
		not canvas.developer_placement_panel.visible
			and not canvas.developer_placement_restore_button.visible
			and not bool(canvas.developer_placement_snapshot().get("panel_minimized", true)),
		"Leaving placement mode must hide both controls and clear minimized state."
	)
	canvas.set_developer_placement_mode(true)
	_check(canvas.developer_placement_panel.visible and not canvas.developer_placement_restore_button.visible, "Re-entering placement mode must start with the full menu available.")
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


func _capture_reset(_request: Dictionary) -> void:
	reset_request_count += 1


func _apply_maximum_accessibility_fixture(node: Node) -> void:
	var control := node as Control
	if control != null:
		if control is Label or control is BaseButton:
			control.add_theme_font_size_override("font_size", 24)
		if control is BaseButton:
			control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, 52.0)
	for child in node.get_children():
		_apply_maximum_accessibility_fixture(child)


func _click_canvas(canvas: Control, local_position: Vector2) -> void:
	var global_position := canvas.get_global_transform_with_canvas() * local_position
	var motion := InputEventMouseMotion.new()
	motion.position = global_position
	motion.global_position = global_position
	root.push_input(motion, true)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = global_position
	press.global_position = global_position
	root.push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = global_position
	release.global_position = global_position
	root.push_input(release, true)
	await process_frame


func _send_key(keycode: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.pressed = true
	root.push_input(pressed, true)
	await process_frame
	var released := InputEventKey.new()
	released.keycode = keycode
	released.pressed = false
	root.push_input(released, true)
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
