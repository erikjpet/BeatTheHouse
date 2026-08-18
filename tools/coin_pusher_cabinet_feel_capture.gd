extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const Solver := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")
const OUTPUT_DIR := "res://.tmp/coin_pusher_v3_cabinet_feel"
const CAPTURE_SIZE := Vector2i(1280, 720)

var app: Control
var canvas: Control
var game: GameModule
var machine_definition: Dictionary
var out_dir := OUTPUT_DIR
var captures: Array[Dictionary] = []
var failed := false
var started_msec := 0
var stop_after_idle := false
var stop_after_crossing := false


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=").strip_edges()
		elif argument == "--stop-after-idle":
			stop_after_idle = true
		elif argument == "--stop-after-crossing":
			stop_after_crossing = true
	call_deferred("_run")


func _run() -> void:
	started_msec = Time.get_ticks_msec()
	print("[cabinet-capture] boot %s" % out_dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_progress("boot")
	root.size = CAPTURE_SIZE
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "coin_pusher_cabinet_feel_%d" % Time.get_ticks_usec())
	root.add_child(app)
	_progress("main_scene_added")
	await _frames(4)
	_progress("starting_test_session")
	app.call("start_game_test_session", "coin_pusher")
	await _frames(8)
	_progress("test_session_started")
	game = app.get("current_game") as GameModule
	canvas = app.get("game_surface_canvas") as Control
	var library := app.get("library") as ContentLibrary
	if game == null or canvas == null or library == null:
		_fail("Production Coin Pusher surface did not open.")
		_finish()
		return
	machine_definition = (library.game("coin_pusher").get("coin_pusher_machine", {}) as Dictionary).duplicate(true)
	# Freeze the Foundation host's realtime refresh while retaining Canvas redraws;
	# each capture below publishes an exact, solver-produced public tick state.
	app.set_process(false)
	print("[cabinet-capture] production surface ready")
	_progress("production_surface_ready")
	print("[cabinet-capture] idle")
	_progress("idle")
	await _capture_idle()
	if stop_after_idle:
		_progress("idle_probe_complete")
		_finish()
		return
	print("[cabinet-capture] deck landing")
	_progress("deck_landing")
	await _capture_beside_row()
	print("[cabinet-capture] ratchet")
	_progress("ratchet")
	await _capture_ratchet()
	print("[cabinet-capture] nestle")
	_progress("nestle")
	await _capture_nestle()
	print("[cabinet-capture] depth crossing")
	_progress("depth_crossing")
	await _capture_depth_crossing()
	if stop_after_crossing:
		_finish()
		return
	print("[cabinet-capture] skill stop")
	_progress("skill_stop")
	await _capture_skill_stop()
	print("[cabinet-capture] tray")
	_progress("tray")
	await _capture_tray()
	print("[cabinet-capture] 300-body performance")
	_progress("performance_300")
	await _capture_300_body_perf()
	_write_manifest()
	print("[cabinet-capture] complete")
	_progress("complete")
	_finish()


func _capture_idle() -> void:
	_progress("idle_create_machine")
	var state := _state("cabinet-idle", 90)
	_progress("idle_machine_created")
	var before := int(state.get("face_y", 0))
	Solver.step_ticks(state, {"motor_enabled": true}, 12)
	_progress("idle_ticks_complete")
	var after := int(state.get("face_y", 0))
	await _capture("01_idle_stroking.png", "idle_stroking", state, {"face_before": before, "face_after": after, "motor_live": before != after})


func _capture_beside_row() -> void:
	var state := _state("cabinet-deck-landing", 70)
	_hold_phase(state, 120)
	var positions_before := _body_y_by_id(state)
	var drop := Solver.add_coin(state, _rng("cabinet-deck-drop"), 42000, 1)
	Solver.step_ticks(state, {"motor_enabled": true}, 170)
	var landed := _body(state, str(drop.get("id", "")))
	var advanced_count := _forward_advanced_count(state, positions_before)
	await _capture("02_deck_landing_row_advance.png", "deck_landing_row_advance", state, {
		"drop_support": str(landed.get("support_kind", "exited")),
		"forward_advanced_count": advanced_count,
		"row_advanced": advanced_count > 0 or not (state.get("tray_ledger", []) as Array).is_empty(),
	})


func _capture_ratchet() -> void:
	var state := _state("cabinet-ratchet", 56)
	_hold_phase(state, 0)
	var drop := Solver.add_coin(state, _rng("cabinet-ratchet-drop"), 57000, 1)
	Solver.step_ticks(state, {"motor_enabled": true}, 110)
	var landed := _body(state, str(drop.get("id", "")))
	var y_before := int(landed.get("y", 0))
	Solver.step_ticks(state, {"motor_enabled": true}, 720)
	var after := _body(state, str(drop.get("id", "")))
	await _capture("03_platform_ratchet_three_cycles.png", "platform_ratchet_three_cycles", state, {
		"cycles": 3,
		"start_y": y_before,
		"end_y": int(after.get("y", -1)),
		"transported_or_exited": after.is_empty() or int(after.get("y", y_before)) != y_before,
	})


func _capture_nestle() -> void:
	var state := _state("cabinet-nestle", 0)
	var a := Solver.add_coin(state, _rng("cabinet-nestle-a"), 45000, 1)
	var b := Solver.add_coin(state, _rng("cabinet-nestle-b"), 55000, 1)
	var top := Solver.add_coin(state, _rng("cabinet-nestle-top"), 50000, 1)
	_configure_body(a, 45700, 18000, 0, "deck", "resting")
	_configure_body(b, 54300, 18000, 0, "deck", "resting")
	_configure_body(top, 50000, 18000, 1900, "", "falling")
	Solver.step_ticks(state, {"motor_enabled": false}, 120)
	var settled := _body(state, str(top.get("id", "")))
	await _capture("04_stack_nestles_into_pocket.png", "stack_nestles_into_pocket", state, {
		"top_x": int(settled.get("x", -1)),
		"top_z": int(settled.get("z", -1)),
		"rest_state": str(settled.get("rest_state", "")),
		"nestled": str(settled.get("rest_state", "")) == "resting" and int(settled.get("z", 0)) >= 1600,
	})


func _capture_skill_stop() -> void:
	var state := _state("cabinet-skill-stop", 72)
	Solver.set_skill_stop(state, true)
	Solver.step_ticks(state, {"motor_enabled": true}, 24)
	for index in range(5):
		Solver.add_coin(state, _rng("cabinet-bank-%d" % index), 47000 + index * 1200, 1)
	Solver.step_ticks(state, {"motor_enabled": true}, 110)
	var positions_before := _body_y_by_id(state)
	Solver.set_skill_stop(state, false)
	Solver.step_ticks(state, {"motor_enabled": true}, 360)
	var advanced_count := _forward_advanced_count(state, positions_before)
	await _capture("05_skill_stop_bank_release.png", "skill_stop_bank_release", state, {
		"banked_coins": 5,
		"forward_advanced_count": advanced_count,
		"large_release_advanced": advanced_count >= 5 or not (state.get("tray_ledger", []) as Array).is_empty(),
	})


func _capture_depth_crossing() -> void:
	var rear_puck := {"id": "cross_puck", "kind": "puck", "x": 50000, "y": 40000, "z": 0, "rest_state": "resting", "support_kind": "deck", "vx": 0, "vy": 0}
	var front_fragment := {"id": "cross_fragment", "kind": "fragment", "x": 50000, "y": 39000, "z": 0, "rest_state": "resting", "support_kind": "deck", "vx": 0, "vy": 0}
	_apply_body_views([rear_puck, front_fragment], 77, {}, 77)
	var teal_sample := await _sample_design_pixel(_project_for_capture(50000, 39000, 0), "08_depth_crossing_teal_front.png")
	rear_puck["y"] = 38000
	front_fragment["y"] = 40000
	_apply_body_views([rear_puck, front_fragment], 77, {}, 78)
	var purple_sample := await _sample_design_pixel(_project_for_capture(50000, 38000, 0), "09_depth_crossing_purple_front.png")
	var crossing_valid := teal_sample.g > teal_sample.r + 0.06 and purple_sample.r > purple_sample.g + 0.06
	if not crossing_valid:
		_fail("Exact-order GL crossing probe did not change the visible overlap owner: teal=%s purple=%s." % [teal_sample, purple_sample])
	captures.append({
		"id": "exact_depth_crossing",
		"file": "",
		"saved": true,
		"state_valid": crossing_valid,
		"evidence": {
			"presentation_view_serials": [77, 78],
			"teal_front_rgb": [teal_sample.r, teal_sample.g, teal_sample.b],
			"purple_front_rgb": [purple_sample.r, purple_sample.g, purple_sample.b],
			"visible_owner_changed": crossing_valid,
		},
	})


func _capture_tray() -> void:
	var state := _state("cabinet-tray", 0)
	for index in range(12):
		var coin := Solver.add_coin(state, _rng("cabinet-tray-%d" % index), 21000 + index % 6 * 11000, 1)
		_configure_body(coin, 21000 + index % 6 * 11000, 5200 - index / 6 * 300, 0, "deck", "resting")
	Solver.step_ticks(state, {"motor_enabled": false}, 1)
	var tray_before := (state.get("tray_ledger", []) as Array).size()
	await _capture("06_tray_heap_grown.png", "tray_heap_grown", state, {"tray_count": tray_before, "heap_grew": tray_before == 12})
	var collected := Solver.collect_tray(state)
	await _capture("07_tray_collected.png", "tray_collected", state, {"collected_count": int(collected.get("count", 0)), "collected_value": int(collected.get("value", 0)), "tray_empty": (state.get("tray_ledger", []) as Array).is_empty()})


func _capture_300_body_perf() -> void:
	var state := _state("cabinet-perf-300", 300)
	Solver.step_ticks(state, {"motor_enabled": true}, 12)
	_apply_state(state)
	for _warmup in range(60):
		await process_frame
	canvas.call("reset_performance_counters")
	for _index in range(240):
		canvas.queue_redraw()
		await process_frame
	var performance: Dictionary = canvas.call("performance_counters")
	captures.append({"id": "performance_300", "file": "", "saved": true, "state_valid": float(performance.get("draw_p95_ms", 999.0)) <= 5.0, "metrics": performance})
	if float(performance.get("draw_p95_ms", 999.0)) > 5.0:
		_fail("300-body cabinet draw p95 exceeded 5.0ms: %s" % JSON.stringify(performance))


func _capture(file_name: String, capture_id: String, solver_state: Dictionary, evidence: Dictionary) -> void:
	_progress("%s_apply" % capture_id)
	_apply_state(solver_state)
	canvas.queue_redraw()
	_progress("%s_waiting_for_frames" % capture_id)
	# Headless RenderingServer.frame_post_draw can be starved by a concurrent
	# editor/headless renderer. Two bounded SceneTree frames flush the queued
	# Canvas draw and keep this QA tool from becoming an unkillable silent wait.
	await process_frame
	await process_frame
	_progress("%s_draw_complete" % capture_id)
	var image := root.get_viewport().get_texture().get_image()
	var saved := image != null and image.save_png("%s/%s" % [out_dir, file_name]) == OK
	var signature: Dictionary = game.renderer_signature(canvas.call("realtime_surface_state"))
	var valid := saved and not str(signature.get("identity", "")).is_empty() and int(signature.get("body_count", -1)) == (solver_state.get("bodies", []) as Array).size()
	for value in evidence.values():
		if typeof(value) == TYPE_BOOL:
			valid = valid and bool(value)
	if not valid:
		_fail("Feel capture %s did not prove its physical state." % capture_id)
	captures.append({"id": capture_id, "file": file_name, "saved": saved, "state_valid": valid, "signature": signature, "evidence": evidence})


func _apply_state(solver_state: Dictionary) -> void:
	var bodies := Solver.body_views(solver_state)
	_apply_body_views(bodies, int(solver_state.get("tick", 0)), solver_state)


func _apply_body_views(bodies: Array, liveness_tick: int, solver_state: Dictionary = {}, presentation_view_serial: int = -1) -> void:
	var view_serial := liveness_tick if presentation_view_serial < 0 else presentation_view_serial
	canvas.call("apply_surface_state_patch", {
		"coin_pusher_bodies": bodies,
		"coin_pusher_previous_bodies": bodies,
		"coin_pusher_body_count": bodies.size(),
		"coin_pusher_face_position_y": int(solver_state.get("face_y", 28000)),
		"coin_pusher_phase_fp": int(solver_state.get("phase_fp", 0)),
		"coin_pusher_liveness_ticks": liveness_tick,
		"coin_pusher_presentation_view_serial": view_serial,
		"coin_pusher_motor_rate_fp": int(solver_state.get("motor_rate_fp", 1000)),
		"coin_pusher_skill_stop_engaged": bool(solver_state.get("skill_stop_engaged", false)),
		"coin_pusher_tray_count": (solver_state.get("tray_ledger", []) as Array).size(),
		"coin_pusher_tray_value": _ledger_value(solver_state.get("tray_ledger", [])),
		"coin_pusher_interpolation_alpha": 1.0,
	})


func _sample_design_pixel(design_point: Vector2, debug_file: String = "") -> Color:
	canvas.queue_redraw()
	await process_frame
	await process_frame
	var transform_values: Dictionary = canvas.call("debug_design_space_transform", Vector2(900, 430))
	var viewport_point: Vector2 = canvas.global_position + transform_values.get("position", Vector2.ZERO) + design_point * (transform_values.get("scale", Vector2.ONE) as Vector2)
	var image := root.get_viewport().get_texture().get_image()
	if image == null:
		return Color.BLACK
	if not debug_file.is_empty():
		image.save_png("%s/%s" % [out_dir, debug_file])
	return image.get_pixelv(Vector2i(roundi(viewport_point.x), roundi(viewport_point.y)))


func _project_for_capture(x: int, y: int, z: int) -> Vector2:
	var depth := clampf(float(y) / 63000.0, 0.0, 1.0)
	var width_factor := lerpf(1.0, 0.78, depth)
	var screen_x := 450.0 + (float(x) / 100000.0 - 0.5) * 584.0 * 0.90 * width_factor
	var screen_y := 317.0 - 18.0 - depth * 139.0 - float(z) / 1700.0 * 11.0
	return Vector2(screen_x, screen_y)


func _state(seed: String, opening_count: int) -> Dictionary:
	return Solver.create_machine(_rng(seed), machine_definition, opening_count)


func _hold_phase(state: Dictionary, phase: int) -> void:
	state["phase_fp"] = phase * Solver.FP
	state["face_y"] = Solver.face_y_for_phase(machine_definition, phase)
	state["previous_face_y"] = int(state["face_y"])


func _configure_body(body: Dictionary, x: int, y: int, z: int, support: String, rest: String) -> void:
	body["x"] = x
	body["y"] = y
	body["z"] = z
	body["vx"] = 0
	body["vy"] = 0
	body["vz"] = 0
	body["support_kind"] = support
	body["rest_state"] = rest
	body["sleeping"] = rest == "resting"
	body["sleep_ticks"] = 8 if rest == "resting" else 0
	body["carried_sleep"] = support == "platform"


func _front_y(state: Dictionary) -> int:
	var front := 1000000
	for body_value in state.get("bodies", []):
		if typeof(body_value) == TYPE_DICTIONARY:
			front = mini(front, int((body_value as Dictionary).get("y", front)))
	return front


func _body_y_by_id(state: Dictionary) -> Dictionary:
	var result := {}
	for body_value in state.get("bodies", []):
		if typeof(body_value) == TYPE_DICTIONARY:
			result[str((body_value as Dictionary).get("id", ""))] = int((body_value as Dictionary).get("y", 0))
	return result


func _forward_advanced_count(state: Dictionary, before: Dictionary) -> int:
	var result := 0
	for body_value in state.get("bodies", []):
		if typeof(body_value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = body_value
		var body_id := str(body.get("id", ""))
		if before.has(body_id) and int(body.get("y", 0)) < int(before.get(body_id, 0)) - 100:
			result += 1
	return result


func _body(state: Dictionary, body_id: String) -> Dictionary:
	for body_value in state.get("bodies", []):
		if typeof(body_value) == TYPE_DICTIONARY and str((body_value as Dictionary).get("id", "")) == body_id:
			return body_value
	return {}


func _ledger_value(value: Variant) -> int:
	var result := 0
	var ledger: Array = value if typeof(value) == TYPE_ARRAY else []
	for entry_value in ledger:
		if typeof(entry_value) == TYPE_DICTIONARY:
			result += int((entry_value as Dictionary).get("value", 0))
	return result


func _rng(seed: String) -> RngStream:
	var rng := RngStream.new()
	rng.configure(seed.hash() & 0x7fffffff)
	return rng


func _write_manifest() -> void:
	var screenshot_count := 0
	var valid_count := 0
	for capture in captures:
		if not str(capture.get("file", "")).is_empty():
			screenshot_count += 1
		if bool(capture.get("state_valid", false)):
			valid_count += 1
	var manifest := {"schema": "coin_pusher_v3_cabinet_feel", "capture_size": {"width": CAPTURE_SIZE.x, "height": CAPTURE_SIZE.y}, "required_screenshot_count": 7, "screenshot_count": screenshot_count, "valid_count": valid_count, "passed": not failed and screenshot_count == 7 and valid_count == captures.size(), "captures": captures}
	var file := FileAccess.open("%s/manifest.json" % out_dir, FileAccess.WRITE)
	if file == null:
		_fail("Could not write cabinet feel manifest.")
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()


func _progress(phase: String) -> void:
	var file := FileAccess.open("%s/progress.json" % out_dir, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"phase": phase, "elapsed_msec": Time.get_ticks_msec() - started_msec}) + "\n")
	file.close()


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _fail(message: String) -> void:
	failed = true
	push_error(message)


func _finish() -> void:
	print("COIN_PUSHER_CABINET_FEEL_%s captures=%d out=%s" % ["FAIL" if failed else "PASS", captures.size(), ProjectSettings.globalize_path(out_dir)])
	quit(1 if failed else 0)
