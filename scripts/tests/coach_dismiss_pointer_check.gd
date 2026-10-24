extends SceneTree

const Coach := preload("res://scripts/ui/coach_overlay.gd")
const FocusScope := preload("res://scripts/ui/modal_focus_scope.gd")

var checks := 0
var failures: Array[String] = []
var behind_presses := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := Control.new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scene)
	var coach := Coach.new()
	scene.add_child(coach)
	await process_frame
	var menu := Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.add_child(menu)
	var behind := Button.new()
	behind.text = "Abandon Run"
	behind.pressed.connect(func(): behind_presses += 1)
	menu.add_child(behind)
	var scope := FocusScope.new()
	scope.push_scope(menu, behind)
	for tutorial in [false, true]:
		_show(coach, tutorial)
		await process_frame
		await process_frame
		# Opening the real Run Menu moves it after the already-visible coach.
		# The coach still draws above it through z_index, while GUI picking uses
		# the later modal's tree order.
		menu.move_to_front()
		var button_rect: Rect2 = coach.ok_button.get_global_rect()
		_check(button_rect.has_area() and coach.panel.visible, "The visible dismiss button must have real layout.")
		behind.position = button_rect.position - Vector2(8, 8)
		behind.size = button_rect.size + Vector2(16, 16)
		await process_frame
		var count_before := behind_presses
		await _click(button_rect.get_center())
		_check(behind_presses == count_before, "Visible coach dismiss must not activate a later modal control beneath it.")
		_check(coach.active_lesson_id().is_empty(), "The dismiss click must finish the visible lesson.")

	_show(coach, false)
	await process_frame
	await process_frame
	menu.move_to_front()
	var dismiss_rect: Rect2 = coach.ok_button.get_global_rect()
	var before_cancel := behind_presses
	await _pointer(dismiss_rect.get_center(), true)
	await _pointer(Vector2(20, 20), false)
	_check(behind_presses == before_cancel and not coach.active_lesson_id().is_empty(), "Dragging off dismiss must cancel without firing the covered control or completing advice.")
	var body_point: Vector2 = coach.panel.get_global_rect().position + Vector2(36, 50)
	behind.position = body_point - Vector2(15, 15)
	behind.size = Vector2(30, 30)
	await process_frame
	var before_body := behind_presses
	await _click(body_point)
	_check(behind_presses == before_body + 1, "Ambient copy must remain non-modal outside its dismiss control.")
	coach.set_panel_suppressed(true)
	behind.position = dismiss_rect.position
	behind.size = dismiss_rect.size
	await process_frame
	var before_hidden := behind_presses
	await _click(dismiss_rect.get_center())
	_check(behind_presses == before_hidden + 1, "A suppressed coach panel must not capture a covered control.")
	scope.clear()
	scene.queue_free()
	await process_frame
	print("COACH_DISMISS_POINTER_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _show(coach, tutorial: bool) -> void:
	coach.restore_seen({})
	coach.set_lessons([{
		"id": "dismiss_pointer_fixture", "scope": "tutorial_run" if tutorial else "normal_run",
		"trigger": {"screen": "ENVIRONMENT"}, "anchor": {"kind": "none"},
		"copy": "Jobs build standing. Miss one and the crew remembers.",
		"completion": {"type": "explicit_ok" if tutorial else "any_action"},
	}])
	coach.evaluate_at_boundary({"screen": "ENVIRONMENT", "run": {"tutorial": tutorial}, "viewport_rect": Rect2(0, 0, 1280, 720)})

func _click(point: Vector2) -> void:
	await _pointer(point, true)
	await _pointer(point, false)

func _pointer(point: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
