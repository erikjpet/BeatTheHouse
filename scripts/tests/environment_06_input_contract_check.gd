extends SceneTree

const Canvas := preload("res://scripts/ui/pixel_scene_canvas.gd")
const Policy := preload("res://scripts/ui/mobile_viewport_policy.gd")
const AUTHORED_SIZE := Vector2i(1280, 720)
const OBJECT_ID := "event:inspection_fixture"
const ACTION_IDS := ["fixture:inspect", "fixture:read", "fixture:back"]
const WINDOW_SIZES := [Vector2i(375, 667), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 720)]

# A synthetic, read-only room uses the real canvas and viewport GUI routing.
# Button geometry is queried for targeting; no focus/activation method is called
# to manufacture a successful input. This is native contract evidence, not a
# physical-phone, exported-Web, campaign or popup-host gameplay qualification.
var checks := 0
var failures: Array[String] = []
var facts: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
	return ok


func _settle(frames: int = 4) -> void:
	for _frame in range(frames):
		await process_frame


func _check_policy() -> void:
	for size in WINDOW_SIZES:
		for supported in [false, true]:
			for dpr in [1, 2, 3]:
				_check(Policy.target_size(size * dpr, supported) == AUTHORED_SIZE,
					"fixed 16:9 policy size=%s supported=%s dpr=%s" % [size, supported, dpr])
	_check(Policy.target_size(Vector2i.ZERO, true) == AUTHORED_SIZE, "invalid physical size retains authored root")
	_check(Policy.target_size(Vector2i(390, 844), true, Vector2i(1920, 1080)) == Vector2i(1920, 1080),
		"explicit authored resolution remains authoritative")
	_check(not Policy.portrait_layout(Vector2(AUTHORED_SIZE)), "fixed logical root leaves portrait reflow inactive")


func _canvas() -> PixelSceneCanvas:
	var canvas := Canvas.new()
	canvas.size = Vector2(AUTHORED_SIZE)
	root.add_child(canvas)
	canvas.render_environment_snapshot({
		"id": "environment_06_input_fixture", "display_name": "Inspection Contract", "reduce_motion": true,
		"interactable_objects": [{
			"object_id": OBJECT_ID, "object_type": "event", "visual_type": "event", "source_id": "inspection_fixture",
			"label": "Inspection Fixture", "short_description": "Read-only inline actions.",
			"interactive": true, "enabled": true,
			"available_actions": [{"id": "inspect", "label": "Inspect"}], "confirm_action_id": "inspect",
			"inline_actions": [
				{"label": "Inspect", "emit_object_id": ACTION_IDS[0], "enabled": true},
				{"label": "Read", "emit_object_id": ACTION_IDS[1], "enabled": true},
				{"label": "Back", "emit_object_id": ACTION_IDS[2], "enabled": true},
			],
			"normalized_rect": {"x": 0.25, "y": 0.34, "w": 0.18, "h": 0.22},
		}],
	})
	canvas.reduce_motion = true
	return canvas


func _pointer(logical: Vector2, touch: bool, multi: bool = false) -> void:
	var physical: Vector2 = root.get_final_transform() * logical
	for down in [true, false]:
		var event: InputEvent
		if touch:
			var tap := InputEventScreenTouch.new()
			tap.index = 0
			tap.position = physical
			tap.pressed = down
			tap.double_tap = multi
			event = tap
		else:
			var click := InputEventMouseButton.new()
			click.position = physical
			click.global_position = physical
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = down
			click.double_click = multi
			event = click
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	await _settle()


func _key(keycode: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame


func _empty_point(canvas: PixelSceneCanvas) -> Vector2:
	# Pick a clear part of the actual canvas outside the selected card and prop.
	for point in [Vector2(16, 16), Vector2(1264, 16), Vector2(16, 704), Vector2(1264, 704)]:
		if canvas.object_id_at_local_position(point).is_empty() \
				and canvas._selected_info_action_entry_at_local_position(point).is_empty():
			return point
	return Vector2(-1, -1)


func _input_case(size: Vector2i, touch: bool) -> void:
	root.size = size
	root.content_scale_size = Policy.target_size(size, true)
	await _settle()
	var label := "%s %s" % [size, "touch" if touch else "mouse"]
	_check(root.content_scale_size == AUTHORED_SIZE, label + " root keeps authored resolution")
	_check(root.get_visible_rect().size.is_equal_approx(Vector2(AUTHORED_SIZE)), label + " actual logical viewport is 1280x720")
	var canvas := _canvas()
	var activated: Array[String] = []
	var focused: Array[String] = []
	var routed := {"physical_presses": 0}
	canvas.object_activated.connect(func(id: String): activated.append(id))
	canvas.object_focused.connect(func(id: String): focused.append(id))
	canvas.gui_input.connect(func(event: InputEvent):
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if (event is InputEventScreenTouch and event.pressed) \
				or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			routed.physical_presses += 1
	)
	await _settle()
	var object_rect: Rect2 = canvas.global_rect_for_object(OBJECT_ID)
	if not _check(object_rect.has_area(), label + " rendered object has a real hit rectangle"):
		canvas.queue_free()
		await _settle()
		return
	await _pointer(object_rect.get_center(), touch)
	_check(canvas.selected_object_id == OBJECT_ID and focused == [OBJECT_ID], label + " one physical press selects and focuses the object")
	_check(activated.is_empty(), label + " selection performs no action")
	_check(canvas.camera_focus_active and is_equal_approx(canvas.camera_zoom, canvas.target_camera_zoom), label + " camera focus settles normally")
	var info: Dictionary = canvas._selected_object_info()
	var entries: Array = canvas._selected_info_action_entries_for_rect(info, canvas._animated_info_card_rect(info))
	if not _check(entries.size() == 3, label + " real selected card exposes all three inline buttons"):
		canvas.queue_free()
		await _settle()
		return
	var expected: Array[String] = []
	# The first post-selection press is explicitly recognized as a second tap or
	# click. It must hit Read, rather than replay the object's default Inspect.
	# A later recognized press must likewise reach Back after Inspect was used.
	for index in [1, 0, 2]:
		var rect: Rect2 = entries[index].button_rect
		_check(rect.has_area() and rect.size.y <= 32.0, label + " action %d uses the ordinary small inline rectangle" % index)
		var local: Vector2 = canvas.local_position_for_selected_info_action_button(index)
		_check(canvas.get_global_rect().has_point(local), label + " action %d is inside the drawn canvas" % index)
		await _pointer(canvas.get_global_transform_with_canvas() * local, touch, index != 0)
		expected.append(ACTION_IDS[index])
		_check(activated == expected, label + " button %d emits exactly its own action once" % index)
		_check(canvas.selected_object_id == OBJECT_ID and not focused.has(""), label + " button %d retains item focus" % index)
		_check(canvas.camera_focus_active, label + " button %d retains the focused environment view" % index)
	canvas.grab_focus()
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	expected.append(ACTION_IDS[1])
	_check(activated == expected, label + " keyboard Down and Enter activate the second inline action")
	_check(canvas.selected_object_id == OBJECT_ID and not focused.has(""), label + " keyboard action retains focus")
	var empty := _empty_point(canvas)
	_check(empty.x >= 0.0, label + " clear canvas space exists")
	if empty.x >= 0.0:
		await _pointer(canvas.get_global_transform_with_canvas() * empty, touch)
		_check(canvas.selected_object_id.is_empty() and focused.back() == "", label + " empty-space press returns to the full environment")
		_check(activated == expected, label + " empty-space press does not invoke an action")
	_check(routed.physical_presses == 5, label + " all five physical presses traversed viewport GUI routing")
	facts.append({"window": size, "touch": touch, "logical": root.get_visible_rect().size,
		"final_transform": root.get_final_transform(), "actions": activated, "focus": focused,
		"physical_presses": routed.physical_presses})
	canvas.queue_free()
	await _settle()


func _run() -> void:
	_check_policy()
	Input.use_accumulated_input = false
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for size in WINDOW_SIZES:
		for touch in [false, true]:
			await _input_case(size, touch)
	var result := {"checks": checks, "failures": failures, "facts": facts,
		"scope": "Synthetic read-only canvas fixture; real native viewport mouse/touch/key GUI input. No campaign, save, browser or physical-phone proof."}
	print("ENVIRONMENT_06_INPUT_CONTRACT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
