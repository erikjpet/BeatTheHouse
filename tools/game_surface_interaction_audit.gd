extends SceneTree

# Cross-game pointer reachability audit. Game-specific contracts own authored
# geometry; this tool closes the generic seam by proving that every hit target
# produced by every shipped surface has an unoccluded pointer position and
# emits the action that owns that position at both normal and small-screen hit
# sizes. Overlapping edge zones are recorded because roulette split/corner bets
# and expanded touch margins intentionally intersect; they fail only when one
# makes another authored target unreachable.

const MainScene := preload("res://scenes/main.tscn")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")

const REPORT_PATH := "user://game_surface_interaction_audit_report.json"
const GAME_IDS := [
	"pull_tabs",
	"scratch_tickets",
	"slot",
	"bar_dice",
	"craps",
	"blackjack",
	"baccarat",
	"roulette",
	"crew_draw_poker",
	"video_poker",
	"coin_pusher",
]
const SAMPLE_STEPS := 17
const MIN_RECT_EDGE := 1.0

var app: Control
var failures: Array[String] = []
var game_reports: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	app = MainScene.instantiate() as Control
	if app == null:
		_fail("Could not instantiate the production main scene.")
		_finish()
		return
	get_root().add_child(app)
	await _settle(3)
	for game_id_value in GAME_IDS:
		await _audit_game(str(game_id_value))
	_write_report()
	if app != null:
		app.queue_free()
		app = null
	await _settle(4)
	if failures.is_empty():
		var target_count := 0
		for report in game_reports:
			target_count += int(report.get("target_count", 0))
		print("GAME_SURFACE_INTERACTION_AUDIT status=PASS games=%d targets=%d report=%s" % [game_reports.size(), target_count, REPORT_PATH])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("GAME_SURFACE_INTERACTION_AUDIT status=FAIL games=%d failures=%d report=%s" % [game_reports.size(), failures.size(), REPORT_PATH])
	quit(1)


func _audit_game(game_id: String) -> void:
	var start_result: Dictionary = app.call("start_game_test_session", game_id)
	if not bool(start_result.get("ok", false)):
		_fail("%s practice session could not start: %s" % [game_id, JSON.stringify(start_result)])
		return
	await _settle(3)
	var production_canvas := app.get("game_surface_canvas") as Control
	var game: GameModule = app.get("current_game") as GameModule
	if production_canvas == null or game == null:
		_fail("%s practice session did not expose its production game surface." % game_id)
		return
	var state: Dictionary = production_canvas.call("realtime_surface_state").duplicate(true)
	var report := {
		"game_id": game_id,
		"renderer": str(state.get("surface_renderer", "")),
		"target_count": 0,
		"normal_target_count": 0,
		"small_screen_target_count": 0,
		"intersecting_hit_margin_count": 0,
		"blocked_target_count": 0,
		"outside_board_count": 0,
		"fully_occluded_count": 0,
		"wrong_dispatch_count": 0,
		"external_overlap_count": _external_surface_overlap_count(game_id, production_canvas),
		"modes": [],
	}
	for small_screen in [false, true]:
		var mode_report := await _audit_surface_mode(game_id, game, state, production_canvas.size, small_screen)
		(report.get("modes", []) as Array).append(mode_report)
		var count := int(mode_report.get("target_count", 0))
		report["target_count"] = int(report.get("target_count", 0)) + count
		report["normal_target_count" if not small_screen else "small_screen_target_count"] = count
		for key in ["intersecting_hit_margin_count", "blocked_target_count", "outside_board_count", "fully_occluded_count", "wrong_dispatch_count"]:
			report[key] = int(report.get(key, 0)) + int(mode_report.get(key, 0))
	game_reports.append(report)
	print("GAME_SURFACE_INTERACTION game=%s renderer=%s normal=%d small=%d margin_intersections=%d blocked=%d outside=%d occluded=%d dispatch=%d external=%d" % [
		game_id,
		str(report.get("renderer", "")),
		int(report.get("normal_target_count", 0)),
		int(report.get("small_screen_target_count", 0)),
		int(report.get("intersecting_hit_margin_count", 0)),
		int(report.get("blocked_target_count", 0)),
		int(report.get("outside_board_count", 0)),
		int(report.get("fully_occluded_count", 0)),
		int(report.get("wrong_dispatch_count", 0)),
		int(report.get("external_overlap_count", 0)),
	])


func _audit_surface_mode(game_id: String, game: GameModule, state: Dictionary, canvas_size: Vector2, small_screen: bool) -> Dictionary:
	var canvas := GameSurfaceCanvasScript.new() as Control
	canvas.size = canvas_size
	canvas.set("reduce_motion", true)
	get_root().add_child(canvas)
	canvas.call("set_small_screen_mode", small_screen)
	canvas.call("set_game_module", game)
	canvas.call("render_game_snapshot", state.duplicate(true))
	await _settle(2)
	var raw_regions: Array = canvas.get("hit_regions") as Array
	var regions: Array[Dictionary] = []
	for value in raw_regions:
		if typeof(value) == TYPE_DICTIONARY:
			regions.append((value as Dictionary).duplicate(true))
	var board_size: Vector2 = canvas.call("surface_board_size")
	var mode_name := "small" if small_screen else "normal"
	var mode_report := {
		"mode": mode_name,
		"target_count": regions.size(),
		"intersecting_hit_margin_count": 0,
		"intersecting_hit_margins": [],
		"blocked_target_count": 0,
		"outside_board_count": 0,
		"fully_occluded_count": 0,
		"wrong_dispatch_count": 0,
		"targets": [],
	}
	if regions.is_empty():
		_fail("%s %s surface exposed no pointer targets." % [game_id, mode_name])
	var overlap_pairs := _substantial_overlap_pairs(canvas, regions)
	mode_report["intersecting_hit_margin_count"] = overlap_pairs.size()
	mode_report["intersecting_hit_margins"] = overlap_pairs
	var observed := {"actions": [], "pointers": [], "blocked": []}
	canvas.connect("surface_action", func(action: String, index: int, confirm_requested: bool) -> void:
		(observed["actions"] as Array).append({"action": action, "index": index, "confirm": confirm_requested})
	)
	canvas.connect("surface_pointer_action", func(action: String, index: int, phase: String, _position: Vector2) -> void:
		(observed["pointers"] as Array).append({"action": action, "index": index, "phase": phase})
	)
	canvas.connect("surface_action_blocked", func(action: String, reason: String) -> void:
		(observed["blocked"] as Array).append({"action": action, "reason": reason})
	)
	for region_index in range(regions.size()):
		var region: Dictionary = regions[region_index]
		var rect: Rect2 = region.get("rect", Rect2())
		var resolved: Dictionary = canvas.call("_resolved_surface_action_binding", str(region.get("action", "")), int(region.get("index", -1)))
		var expected_action := str(resolved.get("action", region.get("action", "")))
		var expected_index := int(resolved.get("index", region.get("index", -1)))
		var target := {"action": expected_action, "index": expected_index, "rect": _rect_snapshot(rect), "reachable": false, "dispatch": ""}
		var outside := not rect.has_area() or rect.size.x < MIN_RECT_EDGE or rect.size.y < MIN_RECT_EDGE \
				or rect.position.x < -0.01 or rect.position.y < -0.01 \
				or rect.end.x > board_size.x + 0.01 or rect.end.y > board_size.y + 0.01
		if outside:
			mode_report["outside_board_count"] = int(mode_report.get("outside_board_count", 0)) + 1
			_fail("%s %s target %s/%d is empty or outside its board: rect=%s board=%s." % [game_id, mode_name, expected_action, expected_index, str(rect), str(board_size)])
			(mode_report.get("targets", []) as Array).append(target)
			continue
		var point := _reachable_point(canvas, regions, region_index)
		if point.x < 0.0:
			mode_report["fully_occluded_count"] = int(mode_report.get("fully_occluded_count", 0)) + 1
			_fail("%s %s target %s/%d is fully occluded by later hit regions." % [game_id, mode_name, expected_action, expected_index])
			(mode_report.get("targets", []) as Array).append(target)
			continue
		(observed["actions"] as Array).clear()
		(observed["pointers"] as Array).clear()
		(observed["blocked"] as Array).clear()
		var local_position: Vector2 = canvas.call("_board_to_screen", point)
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = local_position
		canvas.call("_gui_input", press)
		var dispatched: Dictionary = {}
		if not (observed["actions"] as Array).is_empty():
			dispatched = (observed["actions"] as Array)[0] as Dictionary
			target["dispatch"] = "action"
		elif not (observed["pointers"] as Array).is_empty():
			dispatched = (observed["pointers"] as Array)[0] as Dictionary
			target["dispatch"] = "pointer"
			var release := InputEventMouseButton.new()
			release.button_index = MOUSE_BUTTON_LEFT
			release.pressed = false
			release.position = local_position
			canvas.call("_gui_input", release)
		elif not (observed["blocked"] as Array).is_empty():
			mode_report["blocked_target_count"] = int(mode_report.get("blocked_target_count", 0)) + 1
			target["dispatch"] = "blocked"
			_fail("%s %s target %s/%d rendered but blocked pointer selection: %s." % [game_id, mode_name, expected_action, expected_index, JSON.stringify(observed["blocked"])])
		else:
			mode_report["wrong_dispatch_count"] = int(mode_report.get("wrong_dispatch_count", 0)) + 1
			target["dispatch"] = "none"
			_fail("%s %s target %s/%d accepted no pointer action." % [game_id, mode_name, expected_action, expected_index])
		if not dispatched.is_empty():
			var actual_action := str(dispatched.get("action", ""))
			var actual_index := int(dispatched.get("index", -1))
			if actual_action != expected_action or actual_index != expected_index:
				mode_report["wrong_dispatch_count"] = int(mode_report.get("wrong_dispatch_count", 0)) + 1
				_fail("%s %s target %s/%d dispatched %s/%d." % [game_id, mode_name, expected_action, expected_index, actual_action, actual_index])
			else:
				target["reachable"] = true
		(mode_report.get("targets", []) as Array).append(target)
	canvas.queue_free()
	await _settle(2)
	return mode_report


func _reachable_point(canvas: Control, regions: Array[Dictionary], target_index: int) -> Vector2:
	var target: Dictionary = regions[target_index]
	var rect: Rect2 = target.get("rect", Rect2())
	var resolved: Dictionary = canvas.call("_resolved_surface_action_binding", str(target.get("action", "")), int(target.get("index", -1)))
	var expected_action := str(resolved.get("action", target.get("action", "")))
	var expected_index := int(resolved.get("index", target.get("index", -1)))
	var candidates: Array[Vector2] = [rect.get_center()]
	for y_index in range(SAMPLE_STEPS):
		for x_index in range(SAMPLE_STEPS):
			var x_ratio := (float(x_index) + 0.5) / float(SAMPLE_STEPS)
			var y_ratio := (float(y_index) + 0.5) / float(SAMPLE_STEPS)
			candidates.append(rect.position + Vector2(rect.size.x * x_ratio, rect.size.y * y_ratio))
	for point in candidates:
		var owner := _topmost_target_at(canvas, regions, point)
		if str(owner.get("action", "")) == expected_action and int(owner.get("index", -1)) == expected_index:
			return point
	return Vector2(-1.0, -1.0)


func _topmost_target_at(canvas: Control, regions: Array[Dictionary], point: Vector2) -> Dictionary:
	for index in range(regions.size() - 1, -1, -1):
		var region: Dictionary = regions[index]
		var rect: Rect2 = region.get("rect", Rect2())
		if not rect.has_point(point):
			continue
		var resolved: Dictionary = canvas.call("_resolved_surface_action_binding", str(region.get("action", "")), int(region.get("index", -1)))
		return {
			"action": str(resolved.get("action", region.get("action", ""))),
			"index": int(resolved.get("index", region.get("index", -1))),
		}
	return {}


func _substantial_overlap_pairs(canvas: Control, regions: Array[Dictionary]) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	for left_index in range(regions.size()):
		var left: Dictionary = regions[left_index]
		var left_rect: Rect2 = left.get("rect", Rect2())
		var left_target: Dictionary = canvas.call("_resolved_surface_action_binding", str(left.get("action", "")), int(left.get("index", -1)))
		for right_index in range(left_index + 1, regions.size()):
			var right: Dictionary = regions[right_index]
			var right_rect: Rect2 = right.get("rect", Rect2())
			var intersection := left_rect.intersection(right_rect)
			if not intersection.has_area():
				continue
			var right_target: Dictionary = canvas.call("_resolved_surface_action_binding", str(right.get("action", "")), int(right.get("index", -1)))
			if str(left_target.get("action", left.get("action", ""))) == str(right_target.get("action", right.get("action", ""))) \
					and int(left_target.get("index", left.get("index", -1))) == int(right_target.get("index", right.get("index", -1))):
				continue
			var smaller_area := minf(left_rect.get_area(), right_rect.get_area())
			if smaller_area <= 0.0 or intersection.get_area() / smaller_area < 0.15:
				continue
			pairs.append({
				"left": "%s/%d" % [str(left_target.get("action", left.get("action", ""))), int(left_target.get("index", left.get("index", -1)))],
				"right": "%s/%d" % [str(right_target.get("action", right.get("action", ""))), int(right_target.get("index", right.get("index", -1)))],
				"intersection": _rect_snapshot(intersection),
				"smaller_fraction": intersection.get_area() / smaller_area,
			})
	return pairs


func _external_surface_overlap_count(game_id: String, surface: Control) -> int:
	var surface_rect := surface.get_global_rect()
	var count := 0
	for field_name in ["structured_hud", "status_label", "objective_label", "save_status_label", "actions_list", "consequence_panel", "environment_canvas"]:
		var control := app.get(field_name) as Control
		if control == null or control == surface or not control.visible or not control.is_visible_in_tree():
			continue
		if surface_rect.intersects(control.get_global_rect()):
			count += 1
			_fail("%s game surface overlaps visible external control %s: surface=%s control=%s." % [game_id, field_name, str(surface_rect), str(control.get_global_rect())])
	return count


func _rect_snapshot(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y}


func _write_report() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		_fail("Could not write %s." % REPORT_PATH)
		return
	file.store_string(JSON.stringify({
		"tool": "game_surface_interaction_audit",
		"passed": failures.is_empty(),
		"game_count": game_reports.size(),
		"failures": failures,
		"games": game_reports,
	}, "\t"))
	file.close()


func _fail(message: String) -> void:
	failures.append(message)


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _finish() -> void:
	_write_report()
	for failure in failures:
		push_error(failure)
	quit(1)
