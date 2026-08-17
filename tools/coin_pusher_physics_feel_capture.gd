extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const CoinPusherGameScript := preload("res://scripts/games/coin_pusher.gd")
const SolverScript := preload("res://scripts/games/coin_pusher/coin_pusher_solver.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")
const OUTPUT_DIR := "res://.tmp/pusher06_2_feel_captures"
const CAPTURE_SIZE := Vector2i(1280, 720)
const REQUIRED_IDS := ["drop_disturbs_pile", "stack_topples", "upper_to_lower", "nudge_shifts_pile", "tray_fall", "gutter_loss", "tell_ladder_alarm"]
const SHIPPED_COIN_CAP := 160
const SHIPPED_OPENING_COIN_COUNT := 150

var out_dir := OUTPUT_DIR
var game: GameModule
var run_state: RunState
var environment: Dictionary
var captures: Array = []
var sequences: Array = []
var failed := false


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=").strip_edges()
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	root.size = CAPTURE_SIZE
	RenderingServer.set_default_clear_color(Color("#070b14"))
	var library := ContentLibraryScript.new()
	library.load()
	game = CoinPusherGameScript.new()
	game.setup(library.game("coin_pusher"), library)
	run_state = RunStateScript.new()
	run_state.start_new("REWORK06-2-FEEL-CAPTURES")
	run_state.bankroll = 100000
	environment = {
		"id": "rework06_2_feel", "archetype_id": "bar", "world_node_id": "bar", "name": "Roadside Bar",
		"kind": "casino", "tier": 1, "game_ids": ["coin_pusher"],
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 100}, "security_profile": {"strictness": "normal"},
		"scenario_game_modifiers": {"coin_pusher": {"variation_id": "quarter_falls"}}, "game_states": {},
	}
	var machine := game.generate_environment_state(run_state, environment, run_state.create_rng("feel_machine"))
	machine["riders"] = []
	environment["game_states"] = {"coin_pusher": machine}
	run_state.set_environment(environment)

	var fixtures := [
		_drop_fixture(), _topple_fixture(), _upper_lower_fixture(), _nudge_fixture(), _tray_fixture(), _gutter_fixture(),
	]
	for fixture_value in fixtures:
		await _capture_fixture(fixture_value as Dictionary)
	await _capture_tell_ladder()
	for fixture_index in [0, 2, 3, 4, 5]:
		await _capture_replay_sequence(fixtures[fixture_index] as Dictionary)
	_write_manifest()
	print("COIN_PUSHER_FEEL_CAPTURE_%s captures=%d out=%s" % ["FAIL" if failed else "PASS", captures.size(), ProjectSettings.globalize_path(out_dir)])
	quit(1 if failed else 0)


func _drop_fixture() -> Dictionary:
	var state := SolverScript.create(_rng(7101), 48, 0, 5)
	var incoming := SolverScript.add_coin(state, _rng(7102), 2, 5, 1)
	incoming["id"] = "incoming_drop"
	var landing_x := int(incoming.get("x", 50000))
	var landing_y := int(incoming.get("y", SolverScript.REAR_EDGE - 3500))
	(state["bodies"] as Array).push_front(_body("drop_stack", landing_x, landing_y, SolverScript.UPPER_FLOOR_Z + SolverScript.COIN_HEIGHT, true))
	(state["bodies"] as Array).push_front(_body("drop_support", landing_x, landing_y, SolverScript.UPPER_FLOOR_Z, true))
	var before := state.duplicate(true)
	var step := SolverScript.step_action(state, {"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true})
	var metrics: Dictionary = step.get("metrics", {})
	return _fixture("drop_disturbs_pile", "01_drop_disturbs_pile_1280x720.png", "DROP LANDS AND DISTURBS THE PILE", before, state, step, int(metrics.get("collision_count", 0)) > 0 and int(metrics.get("moved_count", 0)) >= 2)


func _topple_fixture() -> Dictionary:
	var state := SolverScript.create(_rng(7201), 48, 0, 5)
	state["bodies"] = [
		_body("topple_support", 50000, 30000, 0, true),
		_body("topple_leaner", 50000, 30000, SolverScript.COIN_HEIGHT, false),
		_body("topple_landing", 52700, 30000, 9000, false),
	]
	var before := state.duplicate(true)
	var step := SolverScript.step_action(state, {"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true})
	return _fixture("stack_topples", "02_stack_topples_1280x720.png", "LEANING STACK TOPPLES", before, state, step, int((step.get("metrics", {}) as Dictionary).get("topple_count", 0)) > 0)


func _upper_lower_fixture() -> Dictionary:
	var state := SolverScript.create(_rng(7301), 48, 0, 5)
	state["bodies"] = [
		_body("upper_fall", 50000, SolverScript.UPPER_EDGE - 1000, SolverScript.UPPER_FLOOR_Z, false),
		_body("lower_landing", 50000, SolverScript.UPPER_EDGE - 9000, 0, true),
	]
	var before := state.duplicate(true)
	var step := SolverScript.step_action(state, {"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true})
	return _fixture("upper_to_lower", "03_upper_to_lower_1280x720.png", "UPPER SHELF FALLS TO LOWER FIELD", before, state, step, int((step.get("metrics", {}) as Dictionary).get("upper_lower_fall_count", 0)) > 0)


func _nudge_fixture() -> Dictionary:
	var state := SolverScript.create(_rng(7401), 48, 0, 5)
	state["bodies"] = [
		_body("nudge_base", 50000, 9000, 0, true),
		_body("nudge_top", 52000, 9000, SolverScript.COIN_HEIGHT, true),
		_body("nudge_neighbor", 42000, 10000, 0, true),
	]
	var before := state.duplicate(true)
	var before_digest := JSON.stringify(SolverScript.canonical_digest(state))
	var step := SolverScript.step_action(state, {"upper_locked": true, "lower_locked": true, "nudge_x": 12000, "nudge_y": -22000, "aimed_x": 50000, "nudge_radius": 14000, "capture_presentation_trace": true})
	return _fixture("nudge_shifts_pile", "04_nudge_shifts_pile_1280x720.png", "NUDGE SHIFTS A REAL PILE", before, state, step, JSON.stringify(SolverScript.canonical_digest(state)) != before_digest and int((step.get("metrics", {}) as Dictionary).get("moved_count", 0)) > 0)


func _tray_fixture() -> Dictionary:
	var state := SolverScript.create(_rng(7501), 48, 0, 5)
	state["bodies"] = [_body("tray_hanger", 50000, 2000, 0, false)]
	var before := state.duplicate(true)
	var step := SolverScript.step_action(state, {"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true})
	return _fixture("tray_fall", "05_tray_fall_1280x720.png", "EDGE HANGER FALLS INTO THE TRAY", before, state, step, _has_outcome(step, "tray"))


func _gutter_fixture() -> Dictionary:
	var state := SolverScript.create(_rng(7601), 48, 0, 5)
	state["bodies"] = [_body("gutter_coin", 1000, 2000, 0, false)]
	var before := state.duplicate(true)
	var step := SolverScript.step_action(state, {"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true})
	return _fixture("gutter_loss", "06_gutter_loss_1280x720.png", "GREEDY SIDE SHOT FALLS INTO THE GUTTER", before, state, step, _has_outcome(step, "gutter"))


func _fixture(id: String, file_name: String, title: String, before: Dictionary, after: Dictionary, step: Dictionary, valid: bool) -> Dictionary:
	return {"id": id, "file": file_name, "title": title, "before": before, "after": after, "step": step, "valid": valid}


func _capture_fixture(fixture: Dictionary) -> void:
	var background := SolverScript.create(_rng(8000 + captures.size()), SHIPPED_COIN_CAP, SHIPPED_OPENING_COIN_COUNT, 5)
	var before_visual := background.duplicate(true)
	var after_visual := background.duplicate(true)
	(before_visual["bodies"] as Array).append_array(((fixture.get("before", {}) as Dictionary).get("bodies", []) as Array).duplicate(true))
	(after_visual["bodies"] as Array).append_array(((fixture.get("after", {}) as Dictionary).get("bodies", []) as Array).duplicate(true))
	var before_surface := _surface_for_simulation(before_visual, 0)
	var after_surface := _surface_for_simulation(after_visual, 900)
	var panel := ColorRect.new()
	panel.color = Color("#070b14")
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(panel)
	var title := Label.new()
	title.text = str(fixture.get("title", "COIN PUSHER PHYSICS"))
	title.position = Vector2(24, 16)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#e9f4ff"))
	panel.add_child(title)
	var proof := Label.new()
	proof.text = _proof_line(fixture)
	proof.position = Vector2(24, 49)
	proof.add_theme_font_size_override("font_size", 14)
	proof.add_theme_color_override("font_color", Color("#58e1d4") if bool(fixture.get("valid", false)) else Color("#ff6b5f"))
	panel.add_child(proof)
	_add_surface_panel(panel, before_surface, Vector2(20, 92), "BEFORE")
	_add_surface_panel(panel, after_surface, Vector2(650, 92), "AFTER 48 FIXED TICKS")
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var saved := image != null and image.save_png("%s/%s" % [out_dir, str(fixture.get("file", "capture.png"))]) == OK
	var valid := bool(fixture.get("valid", false)) and saved
	if not valid:
		failed = true
		push_error("Physics feel capture failed: %s" % str(fixture.get("id", "unknown")))
	captures.append({
		"id": str(fixture.get("id", "")), "file": str(fixture.get("file", "")), "saved": saved, "state_valid": bool(fixture.get("valid", false)),
		"before": SolverScript.canonical_digest(fixture.get("before", {})), "after": SolverScript.canonical_digest(fixture.get("after", {})),
		"events": (fixture.get("step", {}) as Dictionary).get("events", []), "motion_events": (fixture.get("step", {}) as Dictionary).get("motion_events", []),
		"metrics": (fixture.get("step", {}) as Dictionary).get("metrics", {}),
	})
	root.remove_child(panel)
	panel.queue_free()
	await process_frame


func _capture_replay_sequence(fixture: Dictionary) -> void:
	var step: Dictionary = fixture.get("step", {})
	var trace: Array = step.get("presentation_trace", []) if typeof(step.get("presentation_trace", [])) == TYPE_ARRAY else []
	if trace.size() < 4:
		failed = true
		return
	var panel := ColorRect.new()
	panel.color = Color("#070b14")
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(panel)
	var title := Label.new()
	title.text = "%s — AUTHORITATIVE 800MS REPLAY" % str(fixture.get("title", "COIN PUSHER PHYSICS"))
	title.position = Vector2(24, 16)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#e9f4ff"))
	panel.add_child(title)
	var proof := Label.new()
	proof.text = "PREBUILT FIXED-TICK FRAMES — RENDER ONLY SELECTS; FINAL PILE IS ALREADY COMMITTED"
	proof.position = Vector2(24, 48)
	proof.add_theme_font_size_override("font_size", 13)
	proof.add_theme_color_override("font_color", Color("#58e1d4"))
	panel.add_child(proof)
	var frame_indices := _sequence_frame_indices(trace)
	var background := SolverScript.create(_rng(9000 + sequences.size()), SHIPPED_COIN_CAP, SHIPPED_OPENING_COIN_COUNT, 5)
	for panel_index in range(frame_indices.size()):
		var trace_frame: Dictionary = trace[int(frame_indices[panel_index])] if typeof(trace[int(frame_indices[panel_index])]) == TYPE_DICTIONARY else {}
		var snapshot := _surface_for_trace_frame(background, trace_frame, panel_index * 267)
		_add_sequence_surface_panel(panel, snapshot, Vector2(12 + panel_index * 316, 94), "TICK %d" % int(trace_frame.get("tick_offset", 0)))
	await process_frame
	await RenderingServer.frame_post_draw
	var file_name := "sequence_%s_1280x720.png" % str(fixture.get("id", "physics"))
	var image := root.get_viewport().get_texture().get_image()
	var saved := image != null and image.save_png("%s/%s" % [out_dir, file_name]) == OK
	var positions_advance := _trace_positions_advance(trace)
	var sampled_tick_offsets: Array = []
	for frame_index in frame_indices:
		sampled_tick_offsets.append(int((trace[int(frame_index)] as Dictionary).get("tick_offset", 0)))
	if not saved or not positions_advance:
		failed = true
	sequences.append({
		"id": "%s_replay" % str(fixture.get("id", "")),
		"file": file_name,
		"saved": saved,
		"positions_advance": positions_advance,
		"frame_count": trace.size(),
		"sampled_tick_offsets": sampled_tick_offsets,
	})
	root.remove_child(panel)
	panel.queue_free()
	await process_frame


func _surface_for_trace_frame(background: Dictionary, trace_frame: Dictionary, surface_time_msec: int) -> Dictionary:
	var snapshot := _surface_for_simulation(background, surface_time_msec)
	var bodies := SolverScript.body_views(background)
	for body_value in trace_frame.get("bodies", []):
		bodies.append(body_value)
	snapshot["coin_pusher_bodies"] = bodies
	(snapshot.get("coin_pusher_snapshot", {}) as Dictionary)["bodies"] = bodies
	return snapshot


func _capture_tell_ladder() -> void:
	var background := SolverScript.create(_rng(9701), SHIPPED_COIN_CAP, SHIPPED_OPENING_COIN_COUNT, 5)
	var panel := ColorRect.new()
	panel.color = Color("#070b14")
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(panel)
	var title := Label.new()
	title.text = "THE TELL LADDER — WALK THE LINE ON PURPOSE"
	title.position = Vector2(24, 16)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#e9f4ff"))
	panel.add_child(title)
	var proof := Label.new()
	proof.text = "RUNG 1: CABINET ROCK  >  RUNG 2: CHIRP  >  RUNG 3: ATTENDANT GLANCE  >  MACHINE ALARM + LOCK"
	proof.position = Vector2(24, 49)
	proof.add_theme_font_size_override("font_size", 14)
	proof.add_theme_color_override("font_color", Color("#ff8e5b"))
	panel.add_child(proof)
	var first_warning := _tell_surface(background, 1, false, 0)
	var alarm := _tell_surface(background, 3, true, 900)
	_add_surface_panel(panel, first_warning, Vector2(20, 92), "RUNG 1 — ROCK / FIRST LAMP")
	_add_surface_panel(panel, alarm, Vector2(650, 92), "RUNG 3 — ATTENDANT / ALARM / LOCK")
	await process_frame
	await RenderingServer.frame_post_draw
	var file_name := "07_tell_ladder_alarm_1280x720.png"
	var image := root.get_viewport().get_texture().get_image()
	var saved := image != null and image.save_png("%s/%s" % [out_dir, file_name]) == OK
	var state_valid := int(first_warning.get("coin_pusher_tell_rung", 0)) == 1 \
		and int(alarm.get("coin_pusher_tell_rung", 0)) == 3 \
		and bool(alarm.get("coin_pusher_locked", false))
	if not saved or not state_valid:
		failed = true
	captures.append({
		"id": "tell_ladder_alarm", "file": file_name, "saved": saved, "state_valid": state_valid,
		"rungs": ["steady", "cabinet_rock", "chirp", "attendant_glance", "alarm_lock"],
	})
	var machine: Dictionary = ((run_state.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {}) as Dictionary)
	machine["tell_rung"] = 0
	machine["locked_down"] = false
	machine["last_message"] = "Pick a lane. Read both shelves."
	root.remove_child(panel)
	panel.queue_free()
	await process_frame


func _tell_surface(simulation: Dictionary, tell_rung: int, alarmed: bool, surface_time_msec: int) -> Dictionary:
	var machine: Dictionary = ((run_state.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {}) as Dictionary)
	machine["tell_rung"] = tell_rung
	machine["locked_down"] = alarmed
	machine["last_message"] = "Attendant looks over. Alarm line crossed." if alarmed else "The cabinet rocks under the first warning."
	var snapshot := _surface_for_simulation(simulation, surface_time_msec)
	snapshot["coin_pusher_presentation_events"] = [{
		"kind": "alarm" if alarmed else "tell_rock", "body_id": "cabinet",
		"x": SolverScript.WIDTH / 2, "y": SolverScript.UPPER_EDGE, "z": 0,
		"intensity_milli": 1000 if alarmed else 540, "tick_offset": SolverScript.ACTION_TICKS,
		"metadata": {"tell_rung": tell_rung},
	}]
	return snapshot


func _add_sequence_surface_panel(parent: Control, snapshot: Dictionary, position: Vector2, caption: String) -> void:
	var label := Label.new()
	label.text = caption
	label.position = position + Vector2(0, -24)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("#f6cb56"))
	parent.add_child(label)
	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.position = position
	canvas.size = Vector2(300, 144)
	canvas.set_game_module(game)
	canvas.render_game_snapshot(snapshot)
	canvas.set_process(false)
	canvas.set("flicker", 0.75)
	parent.add_child(canvas)


func _trace_positions_advance(trace: Array) -> bool:
	if trace.size() < 2 or typeof(trace.front()) != TYPE_DICTIONARY or typeof(trace.back()) != TYPE_DICTIONARY:
		return false
	return JSON.stringify((trace.front() as Dictionary).get("bodies", [])) != JSON.stringify((trace.back() as Dictionary).get("bodies", []))


func _sequence_frame_indices(trace: Array) -> Array:
	for frame_index in range(trace.size()):
		var frame: Dictionary = trace[frame_index] if typeof(trace[frame_index]) == TYPE_DICTIONARY else {}
		for body_value in frame.get("bodies", []):
			if typeof(body_value) == TYPE_DICTIONARY and str((body_value as Dictionary).get("rest_state", "")).begins_with("falling_"):
				return [0, frame_index, mini(frame_index + 1, trace.size() - 1), mini(frame_index + 2, trace.size() - 1)]
	return [0, trace.size() / 3, (trace.size() * 2) / 3, trace.size() - 1]


func _add_surface_panel(parent: Control, snapshot: Dictionary, position: Vector2, caption: String) -> void:
	var label := Label.new()
	label.text = caption
	label.position = position + Vector2(0, -26)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("#f6cb56"))
	parent.add_child(label)
	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.position = position
	canvas.size = Vector2(610, 560)
	canvas.set_game_module(game)
	canvas.render_game_snapshot(snapshot)
	canvas.set_process(false)
	canvas.set("flicker", 0.75)
	parent.add_child(canvas)


func _surface_for_simulation(simulation: Dictionary, surface_time_msec: int) -> Dictionary:
	var machine: Dictionary = ((run_state.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {}) as Dictionary)
	machine["simulation"] = simulation.duplicate(true)
	machine["riders"] = []
	return game.surface_state(run_state, run_state.current_environment, {"coin_pusher_lane": 2, "surface_time_msec": surface_time_msec})


func _proof_line(fixture: Dictionary) -> String:
	var step: Dictionary = fixture.get("step", {})
	var metrics: Dictionary = step.get("metrics", {})
	return "PHYSICAL PROOF  collisions %d  moved %d  topples %d  upper→lower %d  exits %d" % [
		int(metrics.get("collision_count", 0)), int(metrics.get("moved_count", 0)), int(metrics.get("topple_count", 0)),
		int(metrics.get("upper_lower_fall_count", 0)), (step.get("events", []) as Array).size(),
	]


func _has_outcome(step: Dictionary, outcome: String) -> bool:
	for value in step.get("events", []):
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("outcome", "")) == outcome and str((value as Dictionary).get("cause", "")) == "physical_fall":
			return true
	return false


func _body(id: String, x: int, y: int, z: int, sleeping: bool) -> Dictionary:
	return {
		"id": id, "kind": "coin", "x": x, "y": y, "z": z, "vx": 0, "vy": 0, "vz": 0,
		"radius": SolverScript.COIN_RADIUS, "height": SolverScript.COIN_HEIGHT, "mass": 1,
		"sleep_ticks": SolverScript.SLEEP_TICKS if sleeping else 0, "sleeping": sleeping,
		"rest_state": "resting" if sleeping else "settling", "lean_milli": 0, "metadata": {},
	}


func _rng(seed_value: int) -> RngStream:
	var rng := RngStream.new()
	rng.configure(seed_value)
	return rng


func _write_manifest() -> void:
	var captured_ids: Array = []
	for capture in captures:
		captured_ids.append(str((capture as Dictionary).get("id", "")))
	var passed := not failed and JSON.stringify(captured_ids) == JSON.stringify(REQUIRED_IDS) and captures.size() == REQUIRED_IDS.size() and sequences.size() == 5
	var manifest := {"schema": "coin_pusher_physics_feel_captures", "passed": passed, "coin_cap": SHIPPED_COIN_CAP, "opening_coin_count": SHIPPED_OPENING_COIN_COUNT, "capture_size": {"width": CAPTURE_SIZE.x, "height": CAPTURE_SIZE.y}, "required_ids": REQUIRED_IDS, "captures": captures, "replay_sequences": sequences}
	var file := FileAccess.open("%s/manifest.json" % out_dir, FileAccess.WRITE)
	if file == null:
		failed = true
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()
