extends SceneTree

const Canvas := preload("res://scripts/ui/pixel_scene_canvas.gd")
const Main := preload("res://scripts/ui/foundation_main.gd")

class PublicationHost extends Main:
	var next_snapshot: Dictionary = {}
	func _ready() -> void: set_process(false)
	func _environment_view_snapshot() -> Dictionary: return next_snapshot.duplicate(true)
	func _environment_snapshot_signature() -> String: return "arrival-fixture"
	func _character_offer_visible_cache_stamp() -> int: return 0
	func _current_talk_dock_environment_reserved_rect() -> Rect2: return Rect2()

var checks := 0
var failures: Array[String] = []

func _init() -> void: call_deferred("_run")

func _snapshot() -> Dictionary:
	return {"id": "punchline_1", "archetype_id": "small_underground_casino", "world_node_id": "small_underground_casino", "current_layer_id": "club", "environment_visit_id": "visit1", "context_instance_id": "context1", "reduce_motion": true,
		"interactable_objects": [{"object_id": "service:shared", "object_type": "service", "source_id": "shared", "label": "Overlapping room object", "short_description": "Enter the next room.", "interactive": true, "enabled": true, "available_actions": [{"id": "enter_room", "label": "Enter"}], "confirm_action_id": "enter_room", "normalized_rect": {"x": 0.25, "y": 0.34, "w": 0.18, "h": 0.22}}]}

func _canvas() -> PixelSceneCanvas:
	var canvas := Canvas.new()
	canvas.size = Vector2(1280, 720)
	root.add_child(canvas)
	canvas.render_environment_snapshot(_snapshot())
	return canvas

func _run() -> void:
	root.size = Vector2i(1280, 720)
	for field in ["id", "archetype_id", "world_node_id", "current_layer_id", "environment_visit_id", "context_instance_id"]:
		var canvas := _canvas()
		await process_frame
		canvas.set_selected_object("service:shared")
		canvas._set_hovered_object("service:shared")
		var next := _snapshot()
		next[field] = "destination"
		canvas.render_environment_snapshot(next)
		_check(canvas.selected_object_id.is_empty() and canvas.hovered_object_id.is_empty(), "%s arrival retained shared-ID focus/hover" % field)
		_check(is_equal_approx(canvas.camera_zoom, 1.0) and canvas.camera_offset.is_zero_approx(), "%s arrival retained source camera" % field)
		canvas.queue_free()
		await process_frame

	var same := _canvas()
	same.set_selected_object("service:shared")
	var refreshed := _snapshot()
	refreshed["game_clock_minutes"] = 123
	refreshed["scenario_phase_index"] = 2
	same.render_environment_snapshot(refreshed)
	_check(same.selected_object_id == "service:shared", "ordinary same-room refresh cleared deliberate selection")
	same.queue_free()
	await process_frame
	var emulated := _canvas()
	var stale_press := _mouse(Vector2(400, 300), true)
	stale_press.device = InputEvent.DEVICE_ID_EMULATION
	emulated._gui_input(stale_press)
	_check(emulated.selected_object_id.is_empty() and emulated.arrival_hover_requires_motion, "emulated outgoing press reopened arrival hover/focus")
	emulated.queue_free()
	await process_frame
	await _check_pointer_handoff(false)
	await _check_pointer_handoff(true)
	await _check_publication()
	var changed_during_focus := _canvas()
	changed_during_focus.set_selected_object("service:shared")
	var activations := {"count": 0}
	changed_during_focus.object_focused.connect(func(_id):
		var next := _snapshot()
		next["current_layer_id"] = "casino"
		changed_during_focus.render_environment_snapshot(next)
	)
	changed_during_focus.object_activated.connect(func(_id): activations.count += 1)
	changed_during_focus._activate_selected_info_action_by_index()
	_check(activations.count == 0 and changed_during_focus.selected_object_id.is_empty(), "source activation continued after its focus callback changed rooms")
	changed_during_focus.queue_free()
	await process_frame
	var changed_during_camera := _canvas()
	var camera_callbacks := {"changed": false, "focus": 0, "activation": 0}
	changed_during_camera.view_geometry_changed.connect(func():
		if camera_callbacks.changed or changed_during_camera.selected_object_id.is_empty(): return
		camera_callbacks.changed = true
		var next := _snapshot()
		next["current_layer_id"] = "casino"
		changed_during_camera.render_environment_snapshot(next)
	)
	changed_during_camera.object_focused.connect(func(_id): camera_callbacks.focus += 1)
	changed_during_camera.object_activated.connect(func(_id): camera_callbacks.activation += 1)
	changed_during_camera._activate_object_at_local_position(changed_during_camera.global_rect_for_object("service:shared").get_center())
	_check(camera_callbacks.changed and camera_callbacks.focus == 0 and camera_callbacks.activation == 0 and changed_during_camera.selected_object_id.is_empty(), "camera callback leaked source focus/activation into destination")
	changed_during_camera.queue_free()
	await process_frame
	print("ENVIRONMENT_ARRIVAL_FOCUS_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _check_pointer_handoff(touch: bool) -> void:
	var canvas := _canvas()
	await process_frame
	canvas.set_selected_object("service:shared")
	var action: Rect2 = canvas._selected_info_action_button_rect()
	_check(action.has_area(), "source fixture must expose its real room card action")
	var point := canvas._board_to_local_position(action.get_center())
	var calls := {"count": 0}
	canvas.object_activated.connect(func(_id):
		calls.count += 1
		var next := _snapshot()
		next["current_layer_id"] = "casino"
		canvas.render_environment_snapshot(next)
	)
	Input.parse_input_event(_touch(point, true) if touch else _mouse(point, true))
	Input.flush_buffered_events()
	await process_frame
	_check(calls.count == 1 and canvas.selected_object_id.is_empty(), "viewport-routed source gesture did not arrive unfocused")
	var destination_point := canvas.global_rect_for_object("service:shared").get_center()
	canvas._gui_input(_touch(destination_point, true) if touch else _mouse(destination_point, true))
	_check(canvas.selected_object_id.is_empty(), "held outgoing gesture focused overlapping destination")
	# A release outside the canvas (e.g. a travel overlay) must retire the hold.
	Input.parse_input_event(_touch(Vector2(-20, -20), false) if touch else _mouse(Vector2(-20, -20), false))
	Input.flush_buffered_events()
	await process_frame
	Input.parse_input_event(_touch(destination_point, true) if touch else _mouse(destination_point, true))
	Input.flush_buffered_events()
	await process_frame
	_check(canvas.selected_object_id == "service:shared" and calls.count == 1, "fresh destination %s was blocked or activated instead of selecting" % ("touch" if touch else "mouse"))
	Input.parse_input_event(_touch(destination_point, false) if touch else _mouse(destination_point, false))
	Input.flush_buffered_events()
	var menu := Button.new()
	menu.position = Vector2(10, 10)
	menu.size = Vector2(140, 45)
	menu.text = "Menu"
	var menu_calls := {"count": 0}
	menu.pressed.connect(func(): menu_calls.count += 1)
	root.add_child(menu)
	Input.parse_input_event(_mouse(Vector2(40, 30), true))
	Input.parse_input_event(_mouse(Vector2(40, 30), false))
	Input.flush_buffered_events()
	await process_frame
	_check(menu_calls.count == 1, "arrival release observer consumed fresh menu input")
	menu.queue_free()
	canvas.queue_free()
	await process_frame

func _check_publication() -> void:
	var host := PublicationHost.new()
	host.run_state = RunState.new()
	host.run_state.pending_triggered_events = [{"event_id": "keep_prompt", "presentation": "talk"}]
	root.add_child(host)
	host.environment_canvas = _canvas()
	host.selected_object_id = "service:shared"
	host.focus_target_id = "service:shared"
	host.hover_target_id = "service:shared"
	host.pending_action_panel_object = {"object_id": "service:shared", "label": "Stale source card"}
	host.next_snapshot = _snapshot()
	host.next_snapshot["current_layer_id"] = "casino"
	host.run_state.current_environment = host.next_snapshot.duplicate(true)
	var before := JSON.stringify([host.run_state.bankroll, host.run_state.rng_state, host.run_state.game_clock_minutes, host.run_state.pending_triggered_events])
	host._render_environment_canvas_snapshot()
	_check(host.selected_object_id.is_empty() and host.focus_target_id.is_empty() and host.hover_target_id.is_empty(), "authoritative publication retained host focus")
	_check(host.pending_action_panel_object.is_empty(), "deferred source card survived arrival")
	_check(JSON.stringify([host.run_state.bankroll, host.run_state.rng_state, host.run_state.game_clock_minutes, host.run_state.pending_triggered_events]) == before, "arrival changed money/RNG/clock or pending prompt")
	host.environment_canvas.queue_free()
	host.queue_free()
	await process_frame

func _mouse(point: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event

func _touch(point: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.index = 0
	event.pressed = pressed
	return event

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
