extends SceneTree

const Canvas := preload("res://scripts/ui/pixel_scene_canvas.gd")
var checks := 0
var failures: Array[String] = []

func _init() -> void: call_deferred("_run")

func _snapshot() -> Dictionary:
	return {"id": "room", "archetype_id": "alley", "current_layer_id": "main", "reduce_motion": true,
		"interactable_objects": [
			{"object_id": "service:table", "object_type": "service", "source_id": "table", "label": "Street Table", "interactive": true, "enabled": true, "available_actions": [{"id": "enter", "label": "Enter"}], "confirm_action_id": "enter", "normalized_rect": {"x": 0.28, "y": 0.42, "w": 0.13, "h": 0.16}},
			{"object_id": "service:ring", "object_type": "service", "source_id": "ring", "label": "Chalk Ring", "interactive": true, "enabled": true, "available_actions": [{"id": "inspect", "label": "Inspect"}], "confirm_action_id": "inspect", "normalized_rect": {"x": 0.28, "y": 0.72, "w": 0.13, "h": 0.14}}]}

func _canvas() -> PixelSceneCanvas:
	var canvas := Canvas.new()
	canvas.size = Vector2(1280, 720)
	root.add_child(canvas)
	canvas.render_environment_snapshot(_snapshot())
	return canvas

func _send(canvas: PixelSceneCanvas, point: Vector2, touch: bool, pressed: bool, multi: bool = false, route_to_canvas: bool = true) -> void:
	var event: InputEvent
	if touch:
		var tap := InputEventScreenTouch.new()
		tap.index = 0
		tap.position = point
		tap.pressed = pressed
		tap.double_tap = multi
		event = tap
	else:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = point
		click.global_position = point
		click.pressed = pressed
		click.double_click = multi
		event = click
	canvas._input(event)
	if route_to_canvas: canvas._gui_input(event)

func _first_focus(canvas: PixelSceneCanvas, touch: bool) -> Vector2:
	var point := canvas.global_rect_for_object("service:table").get_center()
	_send(canvas, point, touch, true)
	_send(canvas, point, touch, false)
	_check(canvas.selected_object_id == "service:table", "first press must focus the table")
	return point

func _shift_camera(canvas: PixelSceneCanvas, point: Vector2) -> void:
	# Deterministic presentation-only fixture for the camera movement observed
	# between real Web clicks. Room objects and interaction context do not move.
	canvas.camera_offset += point - canvas.global_rect_for_object("service:ring").get_center()
	canvas.target_camera_offset = canvas.camera_offset
	_check(canvas.object_id_at_local_position(point) == "service:ring", "fixture must put the neighbor beneath the stationary pointer")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	for touch in [false, true]:
		for mode in ["camera", "fresh", "removed", "disabled", "refresh", "transition", "overlay", "direct"]:
			var canvas := _canvas()
			await process_frame
			var activated: Array[String] = []
			canvas.object_activated.connect(func(id): activated.append(id))
			var point := canvas.global_rect_for_object("service:table").get_center()
			if mode != "direct": point = _first_focus(canvas, touch)
			if mode in ["camera", "fresh", "removed", "disabled", "refresh", "overlay"]: _shift_camera(canvas, point)
			if mode == "removed":
				var next := _snapshot()
				next["interactable_objects"].remove_at(0)
				canvas.render_environment_snapshot(next)
			elif mode == "transition":
				var next := _snapshot()
				next["current_layer_id"] = "destination"
				canvas.render_environment_snapshot(next)
			elif mode in ["disabled", "refresh"]:
				var next := _snapshot()
				next["scenario_phase_index"] = 2
				if mode == "disabled": next["interactable_objects"][0]["enabled"] = false
				canvas.render_environment_snapshot(next)
			elif mode == "overlay":
				# A menu owns the first press; its second click must not fall through
				# to an older room gesture when the menu closes.
				_send(canvas, Vector2(10, 10), touch, true, false, false)
				_send(canvas, Vector2(10, 10), touch, false, false, false)
			_send(canvas, point, touch, true, mode != "fresh")
			_send(canvas, point, touch, false, mode != "fresh")
			if mode in ["camera", "refresh", "direct"]:
				_check(activated == ["service:table"], "%s %s multi-click activated %s instead of original table" % ["touch" if touch else "mouse", mode, activated])
			elif mode == "fresh":
				_check(activated.is_empty() and canvas.selected_object_id == "service:ring", "fresh single press must select the neighbor without activation")
			elif mode in ["disabled", "overlay"]:
				_check(activated.is_empty() and canvas.selected_object_id == "service:table", "%s %s gesture activated an unavailable/stale target" % ["touch" if touch else "mouse", mode])
			else:
				_check(activated.is_empty() and canvas.selected_object_id.is_empty(), "%s %s multi-click retargeted a removed/source-room gesture" % ["touch" if touch else "mouse", mode])
			canvas.queue_free()
			await process_frame
	print("WORLD_DOUBLE_CLICK_FOCUS_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
