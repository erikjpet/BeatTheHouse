extends SceneTree

const Canvas := preload("res://scripts/ui/game_surface_canvas.gd")
var checks := 0
var failures: Array[String] = []

class RoutedCanvas extends GameSurfaceCanvas:
	var routed_events: Array = []
	func _draw() -> void:
		pass
	func _gui_input(event: InputEvent) -> void:
		routed_events.append({"kind": event.get_class(), "device": event.device})
		super._gui_input(event)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	# The first action blocks past the old 750ms heuristic, as a real Web
	# purchase did. Its marked emulated partner still belongs to that gesture.
	for touch_first in [false, true]:
		var canvas := _canvas()
		var calls := {"count": 0}
		canvas.surface_add_exact_invisible_hit(Rect2(10, 10, 100, 80), "purchase", 3)
		canvas.surface_action.connect(func(_action, _index, _confirm):
			calls.count += 1
			if calls.count == 1: OS.delay_msec(800)
		)
		var point := canvas._board_to_screen(Vector2(50, 40))
		var first: InputEvent = _touch(point, true) if touch_first else _mouse(point, true)
		canvas._gui_input(first)
		var partner: InputEvent = _mouse(point, true, InputEvent.DEVICE_ID_EMULATION) if touch_first else _touch(point, true, InputEvent.DEVICE_ID_EMULATION)
		canvas._gui_input(partner)
		_check(calls.count == 1, "A delayed emulated %s must not buy a second ticket." % ("mouse" if touch_first else "touch"))
		canvas._gui_input(_touch(point, false) if touch_first else _mouse(point, false))
		canvas._gui_input(_mouse(point, false, InputEvent.DEVICE_ID_EMULATION) if touch_first else _touch(point, false, InputEvent.DEVICE_ID_EMULATION))
		canvas._gui_input(_touch(point, true) if touch_first else _mouse(point, true))
		_check(calls.count == 2, "A second physical %s gesture must remain usable." % ("touch" if touch_first else "mouse"))
		canvas.queue_free()

	for touch_first in [false, true]:
		var canvas := _canvas()
		var phases: Array = []
		canvas.surface_add_drag_hit(Rect2(10, 10, 100, 80), "peel", 0)
		canvas.surface_pointer_action.connect(func(_action, _index, phase, _position): phases.append(phase))
		var point := canvas._board_to_screen(Vector2(50, 40))
		canvas._gui_input(_touch(point, true) if touch_first else _mouse(point, true))
		_check(phases == ["begin"], "Physical pointer must begin a captured gesture.")
		canvas._gui_input(_mouse(point, false, InputEvent.DEVICE_ID_EMULATION) if touch_first else _touch(point, false, InputEvent.DEVICE_ID_EMULATION))
		_check(canvas.captured_surface_action == "peel" and phases == ["begin"], "An emulated release must not end the physical pointer capture.")
		if touch_first:
			var drag := InputEventScreenDrag.new()
			drag.position = point + Vector2(10, 0)
			canvas._gui_input(drag)
		else:
			var motion := InputEventMouseMotion.new()
			motion.position = point + Vector2(10, 0)
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			canvas._gui_input(motion)
		canvas._gui_input(_touch(point, false) if touch_first else _mouse(point, false))
		_check(phases.has("move") and phases.back() == "end" and canvas.captured_surface_action.is_empty(), "Physical drag and release must finish the same captured gesture.")
		canvas.queue_free()

	var keyboard_canvas := _canvas()
	var keyboard_phases: Array = []
	keyboard_canvas.surface_add_hold_hit(Rect2(10, 10, 100, 80), "hold", 0)
	keyboard_canvas.surface_pointer_action.connect(func(_action, _index, phase, _position): keyboard_phases.append(phase))
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	keyboard_canvas._gui_input(key)
	key = InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = false
	keyboard_canvas._gui_input(key)
	_check(keyboard_phases == ["begin", "end"], "Keyboard hold/release must remain available.")
	keyboard_canvas.queue_free()
	await process_frame
	# Verify that dropping marked copies preserves real viewport-routed mouse
	# and touch input with the project's two emulation settings enabled.
	for touch_first in [false, true]:
		var canvas := RoutedCanvas.new()
		canvas.size = Vector2(960, 540)
		root.add_child(canvas)
		await process_frame
		canvas.surface_add_exact_invisible_hit(Rect2(10, 10, 100, 80), "purchase", 3)
		var calls := {"count": 0}
		canvas.surface_action.connect(func(_action, _index, _confirm):
			calls.count += 1
			if calls.count == 1: OS.delay_msec(800)
		)
		var point := canvas._board_to_screen(Vector2(50, 40))
		Input.parse_input_event(_touch(point, true) if touch_first else _mouse(point, true))
		Input.flush_buffered_events()
		await process_frame
		_check(calls.count == 1, "Real viewport-routed %s must activate exactly once with emulation enabled." % ("touch" if touch_first else "mouse"))
		print("SURFACE_ROUTED_POINTER " + JSON.stringify({"touch": touch_first, "calls": calls.count, "events": canvas.routed_events}))
		Input.parse_input_event(_touch(point, false) if touch_first else _mouse(point, false))
		Input.flush_buffered_events()
		canvas.queue_free()
		await process_frame
	print("SURFACE_EMULATED_POINTER_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _canvas() -> GameSurfaceCanvas:
	var canvas := Canvas.new()
	canvas.size = Vector2(960, 540)
	root.add_child(canvas)
	canvas.set_process(false)
	return canvas

func _mouse(point: Vector2, pressed: bool, device: int = 0) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.device = device
	return event

func _touch(point: Vector2, pressed: bool, device: int = 0) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.index = 0
	event.pressed = pressed
	event.device = device
	return event

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
