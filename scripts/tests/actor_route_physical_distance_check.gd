extends SceneTree

const CanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const BOARD := Vector2(900.0, 430.0)
var failures: Array = []
var checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var canvas := CanvasScript.new()
	# Independent pixel coordinates: lengths 98 + 200 + 106 + 102 = 506.
	var route := [_point(250, 220), _point(250, 318), _point(450, 318), _point(556, 318), _point(556, 216)]
	_expect("start", _at(canvas, route, 0.0), Vector2(250, 220))
	_expect("quarter physical distance", _at(canvas, route, 0.25), Vector2(278.5, 318))
	_expect("half physical distance", _at(canvas, route, 0.5), Vector2(405, 318))
	_expect("endpoint", _at(canvas, route, 1.0), Vector2(556, 216))
	_expect("before start", _at(canvas, route, -1.0), Vector2(250, 220))
	_expect("after endpoint", _at(canvas, route, 2.0), Vector2(556, 216))
	_expect("ping-pong return", _at(canvas, route, 1.5, "ping_pong"), Vector2(405, 318))
	_expect("ping-pong complete cycle", _at(canvas, route, 2.0, "ping_pong"), Vector2(250, 220))
	_expect("two points", _at(canvas, [route.front(), route.back()], 0.5), Vector2(403, 218))
	_expect("zero-length segment", _at(canvas, [route.front(), route.front(), route.back()], 0.5), Vector2(403, 218))
	_expect("all coincident", _at(canvas, [route.front(), route.front(), route.front()], 0.5), Vector2(250, 220))
	# The tolerance is measured in pixels with the corrected distance metric.
	var subpixel := [_point(450, 215), _point(450.36, 215), _point(450.72, 215)]
	_expect("subpixel physical distance", _at(canvas, subpixel, 0.5), Vector2(450.36, 215))
	canvas.reduce_motion = true
	_expect("reduced-motion endpoint", _at(canvas, route, 0.5, "to_endpoint", {"reduced_motion_endpoint": _point(810, 43)}), Vector2(810, 43))
	canvas.small_screen_mode = true
	_expect("small-screen reduced endpoint", _at(canvas, route, 0.5, "to_endpoint", {"small_screen_endpoint": _point(720, 86)}), Vector2(720, 86))
	canvas.reduce_motion = false
	_expect("small-screen two points", _at(canvas, [route.front(), route.back()], 0.5, "to_endpoint", {"small_screen_start": _point(90, 43), "small_screen_endpoint": _point(810, 387)}), Vector2(450, 215))
	canvas.free()
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures}
	var output_path := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output_path.is_empty():
		var output := FileAccess.open(output_path, FileAccess.WRITE)
		if output != null: output.store_string(JSON.stringify(result, "\t"))
	print("Actor route physical distance: ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)


func _at(canvas: Control, points: Array, seconds: float, mode: String = "to_endpoint", stage_options: Dictionary = {}) -> Vector2:
	var stage := {"duration_sec": 1.0, "mode": mode}
	stage.merge(stage_options, true)
	var record := {"id": "physical_distance_fixture", "actor_route_stage": stage, "actor_route_points": points}
	var before := var_to_bytes(record)
	canvas.actor_route_time = seconds
	canvas.actor_route_started_at_cache[canvas._actor_route_cache_key(record)] = 0.0
	var position: Vector2 = canvas._actor_route_position(record)
	if var_to_bytes(record) != before: failures.append("Route interpolation mutated its input.")
	return position * BOARD


func _point(x: float, y: float) -> Dictionary:
	return {"x": x / BOARD.x, "y": y / BOARD.y}


func _expect(label: String, actual: Vector2, expected: Vector2) -> void:
	checks += 1
	if actual.distance_to(expected) > 0.001:
		failures.append("%s: got %s, expected %s." % [label, actual, expected])
