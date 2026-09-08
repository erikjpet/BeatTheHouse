class_name HarnessProductionFidelity
extends RefCounted

# Shared test support for the two production boundaries most often approximated
# incorrectly by headless harnesses: completing arrival after travel and
# activating one exact rendered semantic object.

const ArtContractsScript := preload("res://scripts/core/art_contracts.gd")

const DEFAULT_LAYOUT_CONTEXT := {
	"viewport_size": {"x": 1280, "y": 720},
}
const BOARD_SIZE := Vector2(ArtContractsScript.ENVIRONMENT_BOARD_SIZE)


static func generate_and_finalize(
	generator: Variant,
	run_state: Variant,
	failures: Array,
	context: String = "harness initial arrival",
	target_id: String = "",
	target_prevalidated: bool = false,
	layout_context: Dictionary = DEFAULT_LAYOUT_CONTEXT
) -> Dictionary:
	if generator == null or run_state == null:
		return _fail(failures, "%s requires a generator and active RunState." % context, "generation")
	var generated: Variant = generator.next_environment(run_state, target_id, target_prevalidated)
	if generated == null or run_state.current_environment.is_empty():
		return _fail(failures, "%s did not install an initial environment." % context, "generation")
	var arrived_id := str(run_state.current_world_node_id())
	if not target_id.strip_edges().is_empty() and arrived_id != target_id.strip_edges():
		return _fail(failures, "%s requested %s but installed %s." % [context, target_id, arrived_id], "generation")
	return finalize_arrival(run_state, generator.library, failures, context, layout_context, {
		"ok": true,
		"source_id": "",
		"target_id": arrived_id,
		"environment": run_state.current_environment.duplicate(true),
	})


static func travel_and_finalize(
	generator: Variant,
	run_state: Variant,
	target_id: String,
	target_prevalidated: bool,
	library: Variant,
	failures: Array,
	context: String = "harness travel",
	layout_context: Dictionary = DEFAULT_LAYOUT_CONTEXT
) -> Dictionary:
	if generator == null or run_state == null:
		return _fail(failures, "%s requires a generator and active RunState." % context, "travel")
	var source_id := str(run_state.current_world_node_id())
	var travel: Dictionary = generator.travel_environment_result(run_state, target_id, target_prevalidated)
	if not bool(travel.get("ok", false)):
		return _fail(
			failures,
			"%s could not travel from %s to %s: %s" % [context, source_id, target_id, JSON.stringify(travel.get("errors", []))],
			"travel",
			travel
		)
	return finalize_arrival(run_state, library, failures, context, layout_context, travel)


static func finalize_arrival(
	run_state: Variant,
	library: Variant,
	failures: Array,
	context: String = "harness arrival",
	layout_context: Dictionary = DEFAULT_LAYOUT_CONTEXT,
	travel: Dictionary = {}
) -> Dictionary:
	if run_state == null or library == null:
		return _fail(failures, "%s requires an active RunState and ContentLibrary." % context, "finalization", travel)
	var target_id := str(run_state.current_world_node_id())
	# Production travel now reports the finalization performed inside its atomic
	# install. Mirror that boundary exactly; direct generation and custom fixture
	# generators omit the marker and still exercise the explicit fallback.
	var finalized: Dictionary = {"ok": true, "inactive": true, "already_finalized": true, "errors": []}
	if not bool(travel.get("scenario_finalized", false)):
		finalized = run_state.scenario_finalize_installed_environment(library, layout_context.duplicate(true))
	if not bool(finalized.get("ok", false)):
		return _fail(
			failures,
			"%s arrived at %s but production room finalization failed; the harness must not inspect or depart this room: %s" % [context, target_id, JSON.stringify(finalized.get("errors", []))],
			"finalization",
			travel,
			finalized
		)
	return {
		"ok": true,
		"stage": "complete",
		"source_id": str(travel.get("source_id", "")),
		"target_id": target_id,
		"travel": travel.duplicate(true),
		"finalization": finalized.duplicate(true),
		"environment": run_state.current_environment.duplicate(true),
		"errors": [],
	}


# Resolves and activates one exact rendered semantic id. It deliberately has no
# object-type, label, or render-order fallback. The callback receives the exact
# object snapshot and its verified local hit position.
static func activate_exact_canvas_object(
	canvas: Variant,
	semantic_id: String,
	activation: Callable,
	failures: Array,
	context: String = "harness object activation"
) -> Dictionary:
	var resolved := resolve_exact_canvas_object(canvas, semantic_id, failures, context)
	if not bool(resolved.get("ok", false)):
		return resolved
	if not activation.is_valid():
		return _fail(failures, "%s has no valid activation callback for %s." % [context, semantic_id], "activation")
	var activation_result: Variant = activation.call(
		_dict(resolved.get("object", {})),
		resolved.get("local_hit_position", Vector2(-1.0, -1.0))
	)
	if typeof(activation_result) == TYPE_BOOL and not bool(activation_result):
		return _fail(failures, "%s callback refused exact object %s." % [context, semantic_id], "activation")
	return {
		"ok": true,
		"stage": "activated",
		"object": _dict(resolved.get("object", {})),
		"local_hit_position": resolved.get("local_hit_position", Vector2(-1.0, -1.0)),
		"activation_result": activation_result,
		"errors": [],
	}


# Routes an exact rendered room object through the same viewport InputEvent path
# used by a physical mouse.  The caller must await frames and then inspect the
# production host; this helper deliberately does not call an interaction
# controller or a host action method on the caller's behalf.
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
	var global_position := canvas.get_global_rect().position + local_position
	var motion := InputEventMouseMotion.new()
	motion.position = global_position
	motion.global_position = global_position
	viewport.push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.double_click = double_click
	press.position = global_position
	press.global_position = global_position
	viewport.push_input(press, true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
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


# Records only player-observable host/canvas state.  Serialized RunState is
# intentionally excluded: a hidden variable flip cannot satisfy the owner's
# visible-consequence acceptance bar.
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


# Returns admissible visible evidence for one accepted action.  Merely changing
# focus, hover, camera, animation, or hidden serialized state is never evidence.
static func observable_consequence_evidence(
	before: Dictionary,
	after: Dictionary,
	target_semantic_id: String
) -> Dictionary:
	var channels: Array[String] = []
	for channel in ["message", "feedback", "event_popup", "talk", "inventory", "consequence"]:
		var before_channel := _visible_message_signature(_dict(before.get(channel, {})))
		var after_channel := _visible_message_signature(_dict(after.get(channel, {})))
		if bool(after_channel.get("visible", false)) and JSON.stringify(before_channel) != JSON.stringify(after_channel):
			channels.append(channel)
	var before_target := _rendered_object_signature(_dict(before.get("room_canvas", {})), target_semantic_id)
	var after_target := _rendered_object_signature(_dict(after.get("room_canvas", {})), target_semantic_id)
	if not before_target.is_empty() and JSON.stringify(before_target) != JSON.stringify(after_target):
		channels.append("target_rendered_state")
	var before_rewards := _public_reward_signature(_dict(before.get("status_hud", {})), _dict(before.get("environment", {})))
	var after_rewards := _public_reward_signature(_dict(after.get("status_hud", {})), _dict(after.get("environment", {})))
	if JSON.stringify(before_rewards) != JSON.stringify(after_rewards):
		channels.append("item_or_cash")
	var before_screen := _dict(before.get("screen", {}))
	var after_screen := _dict(after.get("screen", {}))
	var before_name := str(before_screen.get("screen", ""))
	var after_name := str(after_screen.get("screen", ""))
	if after_name != before_name and after_name in ["GAME", "CONSEQUENCE", "EVENT"]:
		channels.append("opened_surface")
	if not bool(before_screen.get("world_map_overlay_visible", false)) and bool(after_screen.get("world_map_overlay_visible", false)):
		channels.append("opened_world_map")
	return {
		"ok": not channels.is_empty(),
		"channels": channels,
		"target_semantic_id": target_semantic_id,
		"before_target": before_target,
		"after_target": after_target,
	}


static func exact_selection_matches(host: Variant, semantic_id: String) -> bool:
	if host == null or not host.has_method("current_spatial_interaction_snapshot"):
		return false
	var snapshot: Dictionary = host.call("current_spatial_interaction_snapshot")
	return str(snapshot.get("selected_object_id", "")) == semantic_id.strip_edges()


static func _host_snapshot(host: Variant, method_name: String) -> Dictionary:
	if not host.has_method(method_name):
		return {}
	return _dict(host.call(method_name)).duplicate(true)


static func _visible_message_signature(snapshot: Dictionary) -> Dictionary:
	var signature := {"visible": bool(snapshot.get("visible", false))}
	for key in ["title", "message", "text", "body", "summary", "detail", "description", "acknowledgement", "lines", "choices", "mode", "interaction_kind", "items", "shop_description"]:
		if snapshot.has(key):
			signature[key] = snapshot.get(key)
	return signature


static func _rendered_object_signature(canvas_snapshot: Dictionary, semantic_id: String) -> Dictionary:
	for value in _array(canvas_snapshot.get("objects", [])):
		var object_data := _dict(value)
		if _object_id(object_data) != semantic_id:
			continue
		var signature := {}
		for key in ["id", "object_id", "prop", "visual_key", "icon_key", "asset_path", "state", "visible", "disabled", "enabled"]:
			if object_data.has(key):
				signature[key] = object_data.get(key)
		return signature
	return {}


static func _public_reward_signature(status_hud: Dictionary, environment: Dictionary) -> Dictionary:
	var signature := {}
	for source in [status_hud, environment]:
		for key in ["cash", "bankroll", "money", "inventory", "items", "item_count", "inventory_count"]:
			if (source as Dictionary).has(key):
				signature[key] = (source as Dictionary).get(key)
	return signature


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
