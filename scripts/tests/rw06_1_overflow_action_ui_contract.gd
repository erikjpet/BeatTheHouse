extends SceneTree

const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const RoomActionListScript := preload("res://scripts/ui/room_action_list.gd")

var failures: Array[String] = []


class OverflowFoundationHost:
	extends FoundationMainScript

	var overflow_fixture_records: Array = []
	var use_overflow_fixture := false

	func _interactable_object_view_list() -> Array:
		if use_overflow_fixture:
			return overflow_fixture_records.duplicate(true)
		return super._interactable_object_view_list()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var app := OverflowFoundationHost.new()
	app.size = Vector2(1280.0, 720.0)
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	await _settle_frames(3)
	if not app.start_foundation_run("RW06-1-OVERFLOW-ACTIONS", {}, false):
		failures.append("RW06-1 overflow contract could not start its production Foundation run.")
		await _finish(app)
		return
	await _settle_frames(4)

	var production_record := _first_enabled_game_record(app.call("_interactable_object_view_list"))
	if production_record.is_empty():
		production_record = _fallback_production_game_record(app)
	if production_record.is_empty():
		failures.append("RW06-1 overflow contract found no resolvable production game action.")
		await _finish(app)
		return
	production_record["presentation_mode"] = "overflow"
	production_record["presentation_required"] = true
	production_record["visible"] = true
	production_record["focus_order"] = 10

	var disabled_record := {
		"object_id": "overflow_fixture:disabled",
		"object_type": "room",
		"label": "Locked fixture",
		"short_description": "A deliberately disabled action.",
		"presentation_mode": "overflow",
		"presentation_required": true,
		"visible": true,
		"interactive": true,
		"enabled": false,
		"disabled_reason": "Requires the brass key.",
		"focus_order": 20,
		"available_actions": [{"id": "unlock", "label": "Unlock"}],
	}
	var multi_record := {
		"object_id": "overflow_fixture:scenario",
		"object_type": "scenario",
		"label": "Scenario fixture",
		"short_description": "A mixed-source multi-action scenario record.",
		"presentation_mode": "overflow",
		"presentation_required": true,
		"visible": true,
		"interactive": true,
		"enabled": true,
		"focus_order": 30,
		"inline_actions": [
			{"id": "first", "emit_object_id": "overflow_fixture_action:first", "label": "First route"},
			{"id": "second", "emit_object_id": "overflow_fixture_action:second", "label": "Second route"},
			{"id": "secret", "emit_object_id": "overflow_fixture_action:secret", "label": "Secret route", "hidden": true},
		],
		"scenario_sequence_actions": [
			{"id": "sequence", "emit_object_id": "overflow_fixture_action:sequence", "label": "Sequence route"},
			{"id": "secret_sequence", "emit_object_id": "overflow_fixture_action:secret_sequence", "label": "Secret sequence", "presentation_visible": false},
		],
		"available_actions": [
			{"id": "available", "emit_object_id": "overflow_fixture_action:available", "label": "Available route"},
			{"id": "secret_available", "emit_object_id": "overflow_fixture_action:secret_available", "label": "Secret available", "hidden_only": true},
		],
	}
	var information_record := {
		"object_id": "overflow_fixture:information",
		"object_type": "scenario_scene_object",
		"label": "Read-only fixture",
		"presentation_mode": "overflow",
		"presentation_required": true,
		"visible": true,
		"interactive": false,
		"enabled": true,
		"disabled_reason": "Nothing to do here right now.",
		"focus_order": 40,
		"available_actions": [],
	}
	var hidden_record := {
		"object_id": "overflow_fixture:hidden_action",
		"object_type": "scenario",
		"label": "Hidden-action fixture",
		"presentation_mode": "overflow",
		"presentation_required": true,
		"visible": true,
		"interactive": true,
		"enabled": true,
		"focus_order": 50,
		"inline_actions": [{
			"id": "hidden_only_action",
			"emit_object_id": "overflow_fixture_action:hidden_only",
			"label": "Hidden only action",
			"hidden": true,
		}],
	}
	var records: Array = [production_record, disabled_record, multi_record, information_record, hidden_record]
	app.overflow_fixture_records = records.duplicate(true)
	app.use_overflow_fixture = true
	var action_list = app.get("room_action_list")
	if action_list == null:
		failures.append("RW06-1 production Foundation host did not mount RoomActionList.")
		await _finish(app)
		return
	var production_handler := Callable(app, "_activate_overflow_room_action")
	if not action_list.action_selected.is_connected(production_handler):
		failures.append("RW06-1 production Foundation builder did not connect overflow actions to its live dispatch hook.")
	var activations: Array[String] = []
	action_list.action_selected.connect(func(_record: Dictionary, action: Dictionary) -> void:
		activations.append(_activation_key(action))
	)
	action_list.render(records)
	await _settle_frames(2)

	_check_rendered_action_surface(action_list, records)
	_check_canvas_exclusion(records)
	await _check_cancel_and_focus_recovery(action_list)
	await _check_refresh_focus_recovery(app, action_list, records)
	await _check_mixed_source_dispatch(app, action_list, records, activations)
	for mode in ["mouse", "touch", "keyboard", "controller"]:
		await _check_production_mutation_for_mode(app, action_list, production_record, activations, str(mode))
		await _check_rejected_actions_for_mode(app, action_list, disabled_record, hidden_record, activations, str(mode))
	await _finish(app)


func _check_rendered_action_surface(action_list: Control, records: Array) -> void:
	var action_sources: Dictionary = {}
	var represented_records: Dictionary = {}
	var disabled_button: Button = null
	var information_button: Button = null
	for button_value in action_list.find_children("*", "Button", true, false):
		var button := button_value as Button
		if button.custom_minimum_size.x < 44.0 or button.custom_minimum_size.y < 44.0:
			failures.append("RW06-1 overflow target is smaller than 44x44: %s." % button.text)
		var object_id := str(button.get_meta("object_id", ""))
		var action_id := str(button.get_meta("action_id", ""))
		if not object_id.is_empty():
			represented_records[object_id] = true
		if not action_id.is_empty():
			action_sources[action_id] = str(button.get_meta("action_source", ""))
		if object_id == "overflow_fixture:disabled":
			disabled_button = button
		elif object_id == "overflow_fixture:information":
			information_button = button
	for record_value in records:
		var object_id := str((record_value as Dictionary).get("object_id", ""))
		if not represented_records.has(object_id):
			failures.append("RW06-1 visible overflow record has no rendered row: %s." % object_id)
	var expected_sources := {
		"overflow_fixture_action:first": RoomActionListScript.SOURCE_INLINE,
		"overflow_fixture_action:second": RoomActionListScript.SOURCE_INLINE,
		"overflow_fixture_action:sequence": RoomActionListScript.SOURCE_SEQUENCE,
		"overflow_fixture_action:available": RoomActionListScript.SOURCE_AVAILABLE,
	}
	for action_id in expected_sources:
		if str(action_sources.get(action_id, "")) != str(expected_sources[action_id]):
			failures.append("RW06-1 mixed-source action %s was omitted or attributed to the wrong source: %s." % [action_id, action_sources])
	for hidden_id in [
		"overflow_fixture_action:secret",
		"overflow_fixture_action:secret_sequence",
		"overflow_fixture_action:secret_available",
		"overflow_fixture_action:hidden_only",
	]:
		if action_sources.has(hidden_id):
			failures.append("RW06-1 overflow list exposed hidden action %s." % hidden_id)
	if disabled_button == null or not disabled_button.disabled \
			or not disabled_button.text.contains("Requires the brass key.") \
			or not disabled_button.tooltip_text.contains("Requires the brass key."):
		failures.append("RW06-1 disabled overflow action does not visibly explain why it is unavailable.")
	if information_button == null or not information_button.disabled:
		failures.append("RW06-1 actionless visible overflow record was omitted or remained actionable.")


func _check_canvas_exclusion(records: Array) -> void:
	var canvas := PixelSceneCanvasScript.new()
	canvas.size = Vector2(900.0, 430.0)
	root.add_child(canvas)
	canvas.render_environment_snapshot({
		"id": "rw06_1_overflow_contract",
		"archetype_id": "bar",
		"interactable_objects": records,
	})
	for object_value in canvas.current_view_snapshot().get("objects", []):
		if str((object_value as Dictionary).get("presentation_mode", "room")) == "overflow":
			failures.append("RW06-1 PixelSceneCanvas rendered an overflow-only action record.")
			break
	canvas.queue_free()


func _check_cancel_and_focus_recovery(action_list: Control) -> void:
	var launcher := _launcher_button(action_list)
	action_list.open()
	await process_frame
	_send_key(KEY_ESCAPE)
	await _settle_frames(2)
	var panel := action_list.get("_panel") as Control
	if panel != null and panel.visible:
		failures.append("RW06-1 ui_cancel did not close the overflow modal.")
	if launcher == null or root.gui_get_focus_owner() != launcher:
		failures.append("RW06-1 overflow cancel did not restore focus to its launcher.")


func _check_refresh_focus_recovery(app: Control, action_list: Control, records: Array) -> void:
	action_list.open()
	await process_frame
	var second := _action_button(action_list, "overflow_fixture_action:second")
	if second == null:
		failures.append("RW06-1 refresh-focus check could not find the second scenario action.")
		action_list.close()
		return
	second.grab_focus()
	await process_frame
	var refreshed := records.duplicate(true)
	var refreshed_multi := (refreshed[2] as Dictionary).duplicate(true)
	var refreshed_inline := (refreshed_multi.get("inline_actions", []) as Array).duplicate(true)
	var refreshed_second := (refreshed_inline[1] as Dictionary).duplicate(true)
	refreshed_second["label"] = "Second route refreshed"
	refreshed_inline[1] = refreshed_second
	refreshed_multi["inline_actions"] = refreshed_inline
	refreshed[2] = refreshed_multi
	app.set("overflow_fixture_records", refreshed.duplicate(true))
	action_list.render(refreshed)
	await _settle_frames(2)
	var replacement := _action_button(action_list, "overflow_fixture_action:second")
	if replacement == null or root.gui_get_focus_owner() != replacement:
		failures.append("RW06-1 overflow refresh did not preserve semantic action focus.")
	action_list.close()
	app.set("overflow_fixture_records", records.duplicate(true))
	action_list.render(records)
	await process_frame


func _check_mixed_source_dispatch(app: Control, action_list: Control, records: Array, activations: Array[String]) -> void:
	app.set("overflow_fixture_records", records.duplicate(true))
	action_list.render(records)
	var before := _mutation_snapshot(app)
	for case_value in [
		{"id": "overflow_fixture_action:first", "source": RoomActionListScript.SOURCE_INLINE},
		{"id": "overflow_fixture_action:second", "source": RoomActionListScript.SOURCE_INLINE},
		{"id": "overflow_fixture_action:sequence", "source": RoomActionListScript.SOURCE_SEQUENCE},
		{"id": "overflow_fixture_action:available", "source": RoomActionListScript.SOURCE_AVAILABLE},
	]:
		var case_data := case_value as Dictionary
		var expected_key := "%s|%s" % [str(case_data.get("source", "")), str(case_data.get("id", ""))]
		var prior_count := activations.count(expected_key)
		action_list.open()
		await process_frame
		var button := _action_button(action_list, str(case_data.get("id", "")))
		if button == null:
			failures.append("RW06-1 mixed-source dispatch could not find %s." % expected_key)
			action_list.close()
			continue
		button.emit_signal("pressed")
		await _settle_frames(2)
		if activations.count(expected_key) != prior_count + 1:
			failures.append("RW06-1 mixed-source action did not dispatch independently: %s." % expected_key)
	if _mutation_snapshot(app) != before:
		failures.append("RW06-1 unresolved mixed-source fixture actions mutated production state.")


func _check_production_mutation_for_mode(app: Control, action_list: Control, production_record: Dictionary, activations: Array[String], mode: String) -> void:
	app.set("overflow_fixture_records", [production_record.duplicate(true)])
	action_list.render([production_record])
	await _settle_frames(2)
	var entries := RoomActionListScript.action_entries_for_record(production_record)
	if entries.is_empty():
		failures.append("RW06-1 %s mutation check found no production action entry." % mode)
		return
	var production_action := entries[0] as Dictionary
	var expected_key := _activation_key(production_action)
	var prior_count := activations.count(expected_key)
	var before := _mutation_snapshot(app)
	action_list.open()
	await process_frame
	var button := _action_button_by_key(action_list, str(production_action.get("_overflow_action_key", "")))
	if button == null:
		failures.append("RW06-1 %s mutation check could not find its production button." % mode)
		action_list.close()
		return
	match mode:
		"mouse":
			_send_mouse(button.get_global_rect().get_center())
		"touch":
			_send_touch(button.get_global_rect().get_center())
		"keyboard":
			button.grab_focus()
			_send_key(KEY_ENTER)
		"controller":
			button.grab_focus()
			_send_joy_button(JOY_BUTTON_A)
	await _settle_frames(5)
	if activations.count(expected_key) != prior_count + 1:
		failures.append("RW06-1 %s did not activate the production overflow action exactly once." % mode)
	if str(app.get("current_screen")) != "GAME" or app.get("current_game") == null or _mutation_snapshot(app) == before:
		failures.append("RW06-1 %s overflow action did not reach a real production game-entry mutation." % mode)
	if app.get("current_game") != null:
		app.call("_complete_back_to_environment")
		await _settle_frames(4)
	if str(app.get("current_screen")) != "ENVIRONMENT" or app.get("current_game") != null:
		failures.append("RW06-1 %s production fixture could not return to the room for the next modality." % mode)


func _check_rejected_actions_for_mode(app: Control, action_list: Control, disabled_record: Dictionary, hidden_record: Dictionary, activations: Array[String], mode: String) -> void:
	var rejection_records: Array = [disabled_record.duplicate(true), hidden_record.duplicate(true)]
	app.set("overflow_fixture_records", rejection_records.duplicate(true))
	action_list.render(rejection_records)
	await _settle_frames(2)
	var disabled_entries := RoomActionListScript.action_entries_for_record(disabled_record)
	if disabled_entries.is_empty():
		failures.append("RW06-1 %s rejection check could not resolve its disabled action metadata." % mode)
		return
	var disabled_action := disabled_entries[0] as Dictionary
	var hidden_raw := ((hidden_record.get("inline_actions", []) as Array)[0] as Dictionary).duplicate(true)
	hidden_raw["_overflow_source"] = RoomActionListScript.SOURCE_INLINE
	hidden_raw["_overflow_index"] = 0
	hidden_raw["_overflow_action_key"] = "%s:%s:0:%s" % [
		str(hidden_record.get("object_id", "")),
		RoomActionListScript.SOURCE_INLINE,
		str(hidden_raw.get("emit_object_id", hidden_raw.get("id", ""))),
	]
	var before := _mutation_snapshot(app)
	var activation_count := activations.size()
	action_list.open()
	await process_frame
	var disabled_button := _action_button(action_list, "unlock")
	if disabled_button == null:
		failures.append("RW06-1 %s rejection check could not find its disabled row." % mode)
	else:
		match mode:
			"mouse":
				_send_mouse(disabled_button.get_global_rect().get_center())
			"touch":
				_send_touch(disabled_button.get_global_rect().get_center())
			"keyboard":
				disabled_button.grab_focus()
				await process_frame
				if root.gui_get_focus_owner() == disabled_button:
					failures.append("RW06-1 keyboard focus reached a disabled overflow action.")
				_send_key(KEY_TAB)
			"controller":
				disabled_button.grab_focus()
				await process_frame
				if root.gui_get_focus_owner() == disabled_button:
					failures.append("RW06-1 controller focus reached a disabled overflow action.")
				_send_joy_button(JOY_BUTTON_DPAD_DOWN)
	await _settle_frames(2)
	if _action_button(action_list, "overflow_fixture_action:hidden_only") != null:
		failures.append("RW06-1 %s rejection surface exposed its hidden action." % mode)
	var disabled_result := bool(app.call("_activate_overflow_room_action", disabled_record, disabled_action))
	var hidden_result := bool(app.call("_activate_overflow_room_action", hidden_record, hidden_raw))
	if disabled_result or hidden_result or activations.size() != activation_count or _mutation_snapshot(app) != before:
		failures.append("RW06-1 %s disabled/hidden action path emitted or mutated production state." % mode)
	var panel := action_list.get("_panel") as Control
	if panel != null and panel.visible:
		action_list.close()
	await process_frame


func _first_enabled_game_record(records: Array) -> Dictionary:
	for record_value in records:
		if typeof(record_value) != TYPE_DICTIONARY:
			continue
		var record := record_value as Dictionary
		if str(record.get("object_type", "")) != "game" \
				or not bool(record.get("visible", true)) \
				or not bool(record.get("enabled", true)) \
				or not bool(record.get("interactive", true)):
			continue
		var actions: Array = record.get("available_actions", [])
		if not actions.is_empty():
			return record.duplicate(true)
	return {}


func _fallback_production_game_record(app: Control) -> Dictionary:
	var library: Variant = app.get("library")
	if library == null:
		return {}
	for game_id_value in ["blackjack", "slot", "video_poker", "bar_dice"]:
		var game_id := str(game_id_value)
		var definition: Dictionary = library.game(game_id)
		if definition.is_empty():
			continue
		return {
			"object_id": "game:%s" % game_id,
			"object_type": "game",
			"source_id": game_id,
			"label": str(definition.get("display_name", game_id.capitalize())),
			"short_description": "Production game-entry fixture.",
			"interactive": true,
			"enabled": true,
			"available_actions": [{"id": "enter_game", "label": "Enter game"}],
			"confirm_action_id": "enter_game",
		}
	return {}


func _mutation_snapshot(app: Control) -> String:
	var run_state: Variant = app.get("run_state")
	return JSON.stringify({
		"run": run_state.to_dict() if run_state != null else {},
		"screen": str(app.get("current_screen")),
		"game_active": app.get("current_game") != null,
	})


func _activation_key(action: Dictionary) -> String:
	return "%s|%s" % [
		str(action.get("_overflow_source", "")),
		str(action.get("emit_object_id", action.get("id", ""))),
	]


func _action_button(action_list: Control, action_id: String) -> Button:
	for node in action_list.find_children("*", "Button", true, false):
		var button := node as Button
		if str(button.get_meta("action_id", "")) == action_id:
			return button
	return null


func _action_button_by_key(action_list: Control, action_key: String) -> Button:
	for node in action_list.find_children("*", "Button", true, false):
		var button := node as Button
		if str(button.get_meta("action_key", "")) == action_key:
			return button
	return null


func _launcher_button(action_list: Control) -> Button:
	for node in action_list.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text.begins_with("More room actions"):
			return button
	return null


func _send_key(keycode: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.pressed = true
	root.push_input(pressed)
	var released := InputEventKey.new()
	released.keycode = keycode
	released.pressed = false
	root.push_input(released)


func _send_joy_button(button_index: int) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.button_index = button_index
	pressed.pressed = true
	root.push_input(pressed)
	var released := InputEventJoypadButton.new()
	released.button_index = button_index
	released.pressed = false
	root.push_input(released)


func _send_mouse(position: Vector2) -> void:
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.position = position
	pressed.pressed = true
	root.push_input(pressed)
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.position = position
	released.pressed = false
	root.push_input(released)


func _send_touch(position: Vector2) -> void:
	var pressed := InputEventScreenTouch.new()
	pressed.index = 0
	pressed.position = position
	pressed.pressed = true
	root.push_input(pressed)
	var released := InputEventScreenTouch.new()
	released.index = 0
	released.position = position
	released.pressed = false
	root.push_input(released)


func _settle_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _finish(app: Control) -> void:
	app.queue_free()
	await _settle_frames(5)
	if failures.is_empty():
		print("RW06_1_OVERFLOW_ACTION_UI PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
