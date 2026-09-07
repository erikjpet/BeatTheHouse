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
	var finalized: Dictionary = run_state.scenario_finalize_installed_environment(library, layout_context.duplicate(true))
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
