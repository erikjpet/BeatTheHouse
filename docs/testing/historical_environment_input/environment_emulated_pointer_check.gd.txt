extends SceneTree

const Canvas := preload("res://scripts/ui/pixel_scene_canvas.gd")
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	for touch_first in [false, true]:
		var canvas := _canvas()
		await process_frame
		canvas.set_selected_object("event:counter")
		var button: Rect2 = canvas._selected_info_action_button_rect()
		_check(button.has_area(), "The real room card must expose its redemption action.")
		var point: Vector2 = canvas._board_to_local_position(button.get_center())
		var calls := {"count": 0}
		canvas.object_activated.connect(func(_id):
			calls.count += 1
			# Reproduce a Web redemption that stalls beyond the old heuristic.
			if calls.count == 1: OS.delay_msec(800)
		)
		Input.parse_input_event(_touch(point, true) if touch_first else _mouse(point, true))
		Input.flush_buffered_events()
		await process_frame
		_check(calls.count == 1, "One viewport-routed physical %s must activate the counter once despite delayed emulation." % ("touch" if touch_first else "mouse"))
		Input.parse_input_event(_touch(point, false) if touch_first else _mouse(point, false))
		Input.flush_buffered_events()
		await process_frame
		var before_repeat: int = calls.count
		Input.parse_input_event(_touch(point, true) if touch_first else _mouse(point, true))
		Input.flush_buffered_events()
		await process_frame
		_check(calls.count == before_repeat + 1, "A separate physical counter press must remain usable.")
		Input.parse_input_event(_touch(point, false) if touch_first else _mouse(point, false))
		Input.flush_buffered_events()
		canvas.queue_free()
		await process_frame

	var keyboard_canvas := _canvas()
	await process_frame
	keyboard_canvas.set_selected_object("event:counter")
	var keyboard_calls := {"count": 0}
	keyboard_canvas.object_activated.connect(func(_id): keyboard_calls.count += 1)
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	key.device = InputEvent.DEVICE_ID_EMULATION
	keyboard_canvas._gui_input(key)
	_check(keyboard_calls.count == 1, "The pointer filter must preserve keyboard action routing, including synthetic non-pointer events.")
	keyboard_canvas.queue_free()
	await process_frame
	print("ENVIRONMENT_EMULATED_POINTER_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _canvas() -> PixelSceneCanvas:
	var canvas := Canvas.new()
	canvas.size = Vector2(1280, 720)
	root.add_child(canvas)
	canvas.render_environment_snapshot({
		"id": "counter_pointer_fixture", "display_name": "Counter", "reduce_motion": true,
		"interactable_objects": [{
			"object_id": "event:counter", "object_type": "event", "visual_type": "event",
			"source_id": "counter", "label": "Counter", "short_description": "Redeem a paid ticket.",
			"interactive": true, "enabled": true,
			"available_actions": [{"id": "redeem_pull_tab_winners", "label": "Cash In Pull Tabs"}],
			"confirm_action_id": "redeem_pull_tab_winners",
			"normalized_rect": {"x": 0.25, "y": 0.34, "w": 0.18, "h": 0.22},
		}],
	})
	canvas.reduce_motion = true
	return canvas

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
