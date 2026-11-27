extends RefCounted

const ArtContracts := preload("res://scripts/core/art_contracts.gd")
const BOARD_SIZE := Vector2(ArtContracts.ENVIRONMENT_BOARD_SIZE)

# Read rendered views and dispatch mouse input through the actual viewport.
static func push_exact_canvas_mouse_click(
	viewport: Viewport,
	canvas: Control,
	semantic_id: String,
	failures: Array,
	context: String = "harness mouse activation",
	double_click: bool = false
) -> Dictionary:
	var resolved := resolve_exact_canvas_object(canvas, semantic_id, failures, context)
	if not bool(resolved.get("ok", false)):
		return resolved
	if viewport == null:
		return _fail(failures, "%s has no production viewport for %s." % [context, semantic_id], "input")
	var local_position: Vector2 = resolved.get("local_hit_position", Vector2(-1.0, -1.0))
	var global_position := canvas.get_global_transform_with_canvas() * local_position
	var motion := InputEventMouseMotion.new()
	motion.position = global_position
	motion.global_position = global_position
	viewport.push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.double_click = double_click
	press.position = global_position
	press.global_position = global_position
	viewport.push_input(press, true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.button_mask = 0
	release.double_click = double_click
	release.position = global_position
	release.global_position = global_position
	viewport.push_input(release, true)
	return {
		"ok": true,
		"stage": "input_routed",
		"object": _dict(resolved.get("object", {})),
		"semantic_id": semantic_id,
		"local_hit_position": local_position,
		"global_hit_position": global_position,
		"input_class": "InputEventMouseButton",
		"errors": [],
	}

static func observable_host_snapshot(host: Variant) -> Dictionary:
	if host == null:
		return {}
	var room_canvas := host.get("environment_canvas") as Control
	var game_canvas := host.get("game_surface_canvas") as Control
	var message_label := host.get("message_label") as Label
	return {
		"screen": _host_snapshot(host, "current_screen_snapshot"),
		"environment": _host_snapshot(host, "current_environment_view_snapshot"),
		"spatial": _host_snapshot(host, "current_spatial_interaction_snapshot"),
		"game": _host_snapshot(host, "current_game_view_snapshot"),
		"consequence": _host_snapshot(host, "current_consequence_view_snapshot"),
		"status_hud": _host_snapshot(host, "current_run_status_hud_snapshot"),
		"feedback": _host_snapshot(host, "current_environment_result_feedback_snapshot"),
		"event_popup": _host_snapshot(host, "current_event_choice_popup_snapshot"),
		"talk": _host_snapshot(host, "current_talk_dock_snapshot"),
		"inventory": _host_snapshot(host, "current_run_inventory_snapshot"),
		"message": {
			"visible": message_label != null and message_label.is_visible_in_tree(),
			"text": message_label.text.strip_edges() if message_label != null else "",
		},
		"room_canvas": room_canvas.call("current_view_snapshot") if room_canvas != null and room_canvas.visible and room_canvas.has_method("current_view_snapshot") else {},
		"game_canvas": game_canvas.call("current_view_snapshot") if game_canvas != null and game_canvas.visible and game_canvas.has_method("current_view_snapshot") else {},
	}

static func _host_snapshot(host: Variant, method_name: String) -> Dictionary:
	if not host.has_method(method_name):
		return {}
	return _dict(host.call(method_name)).duplicate(true)

static func resolve_exact_canvas_object(
	canvas: Variant,
	semantic_id: String,
	failures: Array,
	context: String = "harness object activation"
) -> Dictionary:
	var exact_id := semantic_id.strip_edges()
	if exact_id.is_empty():
		return _fail(failures, "%s requires a non-empty exact semantic object id." % context, "resolution")
	if canvas == null or not canvas.has_method("current_view_snapshot"):
		return _fail(failures, "%s cannot resolve %s because the environment canvas is unavailable." % [context, exact_id], "resolution")
	if canvas is CanvasItem and not bool(canvas.visible):
		return _fail(failures, "%s resolved canvas is not visible while targeting %s." % [context, exact_id], "visibility")
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	var exact_object: Dictionary = {}
	for value in _array(snapshot.get("objects", [])):
		var object_data := _dict(value)
		if _object_id(object_data) == exact_id:
			exact_object = object_data
			break
	if exact_object.is_empty():
		return _fail(failures, "%s could not find exact semantic object %s; type/render-order fallback is forbidden." % [context, exact_id], "resolution")
	var label := str(exact_object.get("label", ""))
	if not bool(exact_object.get("visible", true)):
		return _fail(failures, "%s selected %s (%s), but it is not visible." % [context, exact_id, label], "visibility")
	if bool(exact_object.get("disabled", false)) or not bool(exact_object.get("enabled", true)) or not bool(exact_object.get("interactive", true)):
		return _fail(failures, "%s selected %s (%s), but it is not enabled and interactive." % [context, exact_id, label], "availability")
	var hit_position := _local_hit_position(canvas, snapshot, exact_object)
	if hit_position.x < 0.0:
		return _fail(failures, "%s selected %s (%s), but its exact rendered hit authority is not hittable." % [context, exact_id, label], "hit_test")
	return {
		"ok": true,
		"stage": "resolved",
		"object": exact_object.duplicate(true),
		"local_hit_position": hit_position,
		"errors": [],
	}

static func _local_hit_position(canvas: Variant, snapshot: Dictionary, object_data: Dictionary) -> Vector2:
	var object_id := _object_id(object_data)
	if object_id.is_empty() or not canvas.has_method("object_id_at_local_position"):
		return Vector2(-1.0, -1.0)
	var board_rect := _rect(snapshot.get("board_rect", {}))
	if not board_rect.has_area():
		return Vector2(-1.0, -1.0)
	var position: Vector2 = object_data.get("position", Vector2(0.5, 0.5))
	var object_size: Vector2 = object_data.get("size", Vector2(128.0, 68.0))
	var center := Vector2(position.x * BOARD_SIZE.x, position.y * BOARD_SIZE.y)
	var half := object_size * 0.5
	var inset := Vector2(minf(10.0, half.x * 0.45), minf(10.0, half.y * 0.45))
	for board_point in [
		center,
		center + Vector2(-half.x + inset.x, 0.0),
		center + Vector2(half.x - inset.x, 0.0),
		center + Vector2(0.0, -half.y + inset.y),
		center + Vector2(0.0, half.y - inset.y),
	]:
		var local_position := board_rect.position + (board_point as Vector2) * (board_rect.size.x / BOARD_SIZE.x)
		if local_position.x < 0.0 or local_position.y < 0.0 or local_position.x > float(canvas.size.x) or local_position.y > float(canvas.size.y):
			continue
		if str(canvas.call("object_id_at_local_position", local_position)) == object_id:
			return local_position
	return Vector2(-1.0, -1.0)

static func _fail(failures: Array, message: String, stage: String, travel: Dictionary = {}, finalization: Dictionary = {}) -> Dictionary:
	failures.append(message)
	return {
		"ok": false,
		"stage": stage,
		"travel": travel.duplicate(true),
		"finalization": finalization.duplicate(true),
		"errors": [message],
	}

static func _object_id(object_data: Dictionary) -> String:
	return str(object_data.get("id", object_data.get("object_id", ""))).strip_edges()

static func _rect(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value
	var data := _dict(value)
	return Rect2(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0)),
		float(data.get("w", data.get("width", 0.0))),
		float(data.get("h", data.get("height", 0.0)))
	)

static func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}

static func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []
