extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const CoinPusherGameScript := preload("res://scripts/games/coin_pusher.gd")
const SolverScript := preload("res://scripts/games/coin_pusher/coin_pusher_solver.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")
const OUTPUT_DIR := "res://.tmp/pusher06_2_feel_captures"
const CAPTURE_SIZE := Vector2i(1280, 720)
const REQUIRED_IDS := ["drop_disturbs_pile", "stack_topples", "upper_to_lower", "nudge_shifts_pile", "tray_fall", "gutter_loss", "tell_ladder_alarm"]
const TELL_STAGE_IDS := ["steady", "cabinet_rock", "chirp", "attendant_glance", "alarm_lock"]
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
	var state := _packed_state(7101)
	var incoming := SolverScript.add_coin(state, _rng(7102), 2, 5, 1)
	incoming["id"] = "incoming_drop"
	var before := state.duplicate(true)
	var step := SolverScript.step_action(state, {"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true})
	var metrics: Dictionary = step.get("metrics", {})
	return _fixture("drop_disturbs_pile", "01_drop_disturbs_pile_1280x720.png", "DROP LANDS AND DISTURBS THE PACKED PILE", before, state, step, int(metrics.get("collision_count", 0)) > 0 and int(metrics.get("moved_count", 0)) >= 2)


func _topple_fixture() -> Dictionary:
	var state := _packed_state(7201)
	(state["bodies"] as Array).append_array([
		_body("topple_support", 50000, 30000, 0, true),
		_body("topple_leaner", 50000, 30000, SolverScript.COIN_HEIGHT, false),
		_body("topple_landing", 52700, 30000, 9000, false),
	])
	var before := state.duplicate(true)
	var step := SolverScript.step_action(state, {"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true})
	return _fixture("stack_topples", "02_stack_topples_1280x720.png", "LEANING STACK TOPPLES", before, state, step, int((step.get("metrics", {}) as Dictionary).get("topple_count", 0)) > 0)


func _upper_lower_fixture() -> Dictionary:
	var state := _packed_state(7301)
	(state["bodies"] as Array).append_array([
		_body("upper_fall", 50000, SolverScript.UPPER_EDGE - 1000, SolverScript.UPPER_FLOOR_Z, false),
	])
	var before := state.duplicate(true)
	var step := SolverScript.step_action(state, {"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true})
	return _fixture("upper_to_lower", "03_upper_to_lower_1280x720.png", "UPPER SHELF FALLS TO LOWER FIELD", before, state, step, int((step.get("metrics", {}) as Dictionary).get("upper_lower_fall_count", 0)) > 0)


func _nudge_fixture() -> Dictionary:
	var state := _packed_state(7401)
	var before := state.duplicate(true)
	var before_digest := JSON.stringify(SolverScript.canonical_digest(state))
	var step := SolverScript.step_action(state, {"upper_locked": true, "lower_locked": true, "nudge_x": 12000, "nudge_y": -22000, "aimed_x": 50000, "nudge_radius": 14000, "capture_presentation_trace": true})
	return _fixture("nudge_shifts_pile", "04_nudge_shifts_pile_1280x720.png", "NUDGE SHIFTS A REAL PILE", before, state, step, JSON.stringify(SolverScript.canonical_digest(state)) != before_digest and int((step.get("metrics", {}) as Dictionary).get("moved_count", 0)) > 0)


func _tray_fixture() -> Dictionary:
	var state := _packed_state(7501)
	(state["bodies"] as Array).append(_body("tray_hanger", 50000, 2000, 0, false))
	var before := state.duplicate(true)
	var step := SolverScript.step_action(state, {"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true})
	return _fixture("tray_fall", "05_tray_fall_1280x720.png", "EDGE HANGER FALLS INTO THE TRAY", before, state, step, _has_outcome(step, "tray"))


func _gutter_fixture() -> Dictionary:
	var state := _packed_state(7601)
	(state["bodies"] as Array).append(_body("gutter_coin", 1000, 2000, 0, false))
	var before := state.duplicate(true)
	var step := SolverScript.step_action(state, {"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true})
	return _fixture("gutter_loss", "06_gutter_loss_1280x720.png", "GREEDY SIDE SHOT FALLS INTO THE GUTTER", before, state, step, _has_outcome(step, "gutter"))


func _fixture(id: String, file_name: String, title: String, before: Dictionary, after: Dictionary, step: Dictionary, valid: bool) -> Dictionary:
	return {"id": id, "file": file_name, "title": title, "before": before, "after": after, "step": step, "valid": valid}


static func presentation_trace_for_capture(payload: Dictionary) -> Array:
	# Native actions publish compact packed authority while the reference/fallback
	# path may still provide legacy frame Arrays. Keep every capture proof on one
	# compatibility boundary so visual QA observes the same action in either build.
	var packed_value: Variant = payload.get("presentation_trace_packed", {})
	if typeof(packed_value) == TYPE_DICTIONARY and not (packed_value as Dictionary).is_empty():
		var decoded := SolverScript.decode_packed_presentation_trace(packed_value as Dictionary)
		if not decoded.is_empty():
			return decoded
	var patch_value: Variant = payload.get("surface_presentation_snapshot_patch", {})
	if typeof(patch_value) == TYPE_DICTIONARY:
		var patch: Dictionary = patch_value
		packed_value = patch.get("trace_packed", {})
		if typeof(packed_value) == TYPE_DICTIONARY and not (packed_value as Dictionary).is_empty():
			var decoded_patch := SolverScript.decode_packed_presentation_trace(packed_value as Dictionary)
			if not decoded_patch.is_empty():
				return decoded_patch
	var legacy_value: Variant = payload.get("presentation_trace", [])
	if typeof(legacy_value) == TYPE_ARRAY and not (legacy_value as Array).is_empty():
		return legacy_value as Array
	if typeof(patch_value) == TYPE_DICTIONARY:
		legacy_value = (patch_value as Dictionary).get("trace", [])
		if typeof(legacy_value) == TYPE_ARRAY:
			return legacy_value as Array
	return []


func _capture_fixture(fixture: Dictionary) -> void:
	var before_surface := _surface_for_simulation(fixture.get("before", {}), 0)
	var after_surface := _surface_for_simulation(fixture.get("after", {}), 900)
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
	var before_body_count := ((fixture.get("before", {}) as Dictionary).get("bodies", []) as Array).size()
	var trace := presentation_trace_for_capture(fixture.get("step", {}) as Dictionary)
	var trace_starts_from_same_pile := not trace.is_empty() and typeof(trace.front()) == TYPE_DICTIONARY \
		and ((trace.front() as Dictionary).get("bodies", []) as Array).size() == before_body_count
	var valid := bool(fixture.get("valid", false)) and before_body_count >= SHIPPED_OPENING_COIN_COUNT and trace_starts_from_same_pile and saved
	if not valid:
		failed = true
		push_error("Physics feel capture failed: %s" % str(fixture.get("id", "unknown")))
	captures.append({
		"id": str(fixture.get("id", "")), "file": str(fixture.get("file", "")), "saved": saved, "state_valid": bool(fixture.get("valid", false)),
		"before_body_count": before_body_count,
		"after_body_count": ((fixture.get("after", {}) as Dictionary).get("bodies", []) as Array).size(),
		"same_state_evidence": trace_starts_from_same_pile,
		"before": SolverScript.canonical_digest(fixture.get("before", {})), "after": SolverScript.canonical_digest(fixture.get("after", {})),
		"events": (fixture.get("step", {}) as Dictionary).get("events", []), "motion_events": (fixture.get("step", {}) as Dictionary).get("motion_events", []),
		"metrics": (fixture.get("step", {}) as Dictionary).get("metrics", {}),
	})
	root.remove_child(panel)
	panel.queue_free()
	await process_frame


func _capture_replay_sequence(fixture: Dictionary) -> void:
	var step: Dictionary = fixture.get("step", {})
	var trace := presentation_trace_for_capture(step)
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
	for panel_index in range(frame_indices.size()):
		var trace_frame: Dictionary = trace[int(frame_indices[panel_index])] if typeof(trace[int(frame_indices[panel_index])]) == TYPE_DICTIONARY else {}
		var snapshot := _surface_for_trace_frame(fixture.get("after", {}), trace_frame, panel_index * 267)
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


func _surface_for_trace_frame(simulation: Dictionary, trace_frame: Dictionary, surface_time_msec: int) -> Dictionary:
	var snapshot := _surface_for_simulation(simulation, surface_time_msec)
	(snapshot.get("coin_pusher_snapshot", {}) as Dictionary)["bodies"] = (trace_frame.get("bodies", []) as Array).duplicate(true)
	return snapshot


func _capture_tell_ladder() -> void:
	var packed := _packed_state(9701)
	var machine: Dictionary = ((run_state.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {}) as Dictionary)
	machine["simulation"] = packed.duplicate(true)
	machine["riders"] = []
	machine["base_alarm_tolerance"] = 3
	machine["tolerance_modifier"] = 0
	machine["alarm_tolerance_remaining"] = 3
	machine["tell_rung"] = 0
	machine["locked_down"] = false
	var before := packed.duplicate(true)
	var stage_surfaces: Array = [game.surface_state(run_state, run_state.current_environment, {"coin_pusher_lane": 2, "surface_time_msec": 0}).duplicate(true)]
	var stage_results: Array = []
	var first_result: Dictionary = {}
	var alarm_result: Dictionary = {}
	var first_warning: Dictionary = {}
	var alarm: Dictionary = {}
	for nudge_index in range(4):
		var result := game.resolve_with_context("nudge_machine", 0, run_state, run_state.current_environment, _rng(9702 + nudge_index), {
			"coin_pusher_lane": 2, "coin_pusher_force": "tap", "coin_pusher_direction": "front",
			"coin_pusher_upper_input_phase": 2, "coin_pusher_lower_input_phase": 9,
			"coin_pusher_capture_presentation_trace": true,
		})
		GameModule.apply_result(run_state, result, _rng(9802 + nudge_index))
		stage_results.append(result.duplicate(true))
		stage_surfaces.append(_surface_with_result_events(result, (nudge_index + 1) * 900).duplicate(true))
		if nudge_index == 0:
			first_result = result
			first_warning = _surface_with_result_events(result, nudge_index * 900)
		if bool(result.get("coin_pusher_hard_alarm", false)):
			alarm_result = result
			alarm = _surface_with_result_events(result, nudge_index * 900)
	if first_warning.is_empty():
		first_warning = game.surface_state(run_state, run_state.current_environment, {"surface_time_msec": 0})
	if alarm.is_empty():
		alarm = game.surface_state(run_state, run_state.current_environment, {"surface_time_msec": 2700})
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
	_add_surface_panel(panel, first_warning, Vector2(20, 92), "RUNG 1 — ROCK / FIRST LAMP")
	_add_surface_panel(panel, alarm, Vector2(650, 92), "RUNG 3 — ATTENDANT / ALARM / LOCK")
	await process_frame
	await RenderingServer.frame_post_draw
	var file_name := "07_tell_ladder_alarm_1280x720.png"
	var image := root.get_viewport().get_texture().get_image()
	var saved := image != null and image.save_png("%s/%s" % [out_dir, file_name]) == OK
	var first_snapshot: Dictionary = first_warning.get("coin_pusher_snapshot", {})
	var alarm_snapshot: Dictionary = alarm.get("coin_pusher_snapshot", {})
	var first_trace := presentation_trace_for_capture(first_result)
	var trace_starts_from_same_pile := not first_trace.is_empty() and typeof(first_trace.front()) == TYPE_DICTIONARY \
		and ((first_trace.front() as Dictionary).get("bodies", []) as Array).size() == (before.get("bodies", []) as Array).size()
	var stage_evidence: Array = []
	var stages_valid := stage_surfaces.size() == TELL_STAGE_IDS.size() and stage_results.size() == 4
	var expected_rungs := [0, 1, 2, 3, 3]
	var expected_events := ["", "tell_rock", "tell_chirp", "attendant_glance", "alarm"]
	var evidence_stage_count := mini(stage_surfaces.size(), TELL_STAGE_IDS.size())
	for stage_index in range(evidence_stage_count):
		var stage_surface: Dictionary = stage_surfaces[stage_index]
		var stage_snapshot: Dictionary = stage_surface.get("coin_pusher_snapshot", {}) if typeof(stage_surface.get("coin_pusher_snapshot", {})) == TYPE_DICTIONARY else {}
		var stage_event_kinds: Array = []
		for event_value in stage_snapshot.get("events", []):
			if typeof(event_value) == TYPE_DICTIONARY:
				stage_event_kinds.append(str((event_value as Dictionary).get("kind", "")))
		var expected_locked := stage_index == TELL_STAGE_IDS.size() - 1
		var expected_event := str(expected_events[stage_index])
		var stage_valid := int(stage_snapshot.get("tell_rung", -1)) == int(expected_rungs[stage_index]) \
			and bool(stage_snapshot.get("locked", false)) == expected_locked \
			and (expected_event.is_empty() or stage_event_kinds.has(expected_event))
		stages_valid = stages_valid and stage_valid
		stage_evidence.append({
			"id": str(TELL_STAGE_IDS[stage_index]),
			"tell_rung": int(stage_snapshot.get("tell_rung", -1)),
			"locked": bool(stage_snapshot.get("locked", false)),
			"event_kinds": stage_event_kinds,
			"body_count": (stage_snapshot.get("bodies", []) as Array).size(),
			"valid": stage_valid,
		})
	var state_valid := stages_valid and int(first_snapshot.get("tell_rung", 0)) == 1 \
		and int(alarm_snapshot.get("tell_rung", 0)) == 3 \
		and bool(alarm_snapshot.get("locked", false)) \
		and bool(alarm_result.get("coin_pusher_hard_alarm", false)) \
		and (before.get("bodies", []) as Array).size() >= SHIPPED_OPENING_COIN_COUNT \
		and trace_starts_from_same_pile
	if not saved or not state_valid:
		failed = true
	captures.append({
		"id": "tell_ladder_alarm", "file": file_name, "saved": saved, "state_valid": state_valid,
		"before_body_count": (before.get("bodies", []) as Array).size(),
		"after_body_count": (((machine.get("simulation", {}) as Dictionary).get("bodies", []) as Array).size()),
		"same_state_evidence": trace_starts_from_same_pile,
		"before": SolverScript.canonical_digest(before),
		"after": SolverScript.canonical_digest(machine.get("simulation", {})),
		"first_events": ((first_result.get("surface_presentation_snapshot_patch", {}) as Dictionary).get("events", []) as Array).duplicate(true),
		"alarm_events": ((alarm_result.get("surface_presentation_snapshot_patch", {}) as Dictionary).get("events", []) as Array).duplicate(true),
		"metrics": alarm_result.get("coin_pusher_solver_metrics", {}),
		"rungs": TELL_STAGE_IDS.duplicate(),
		"stage_evidence": stage_evidence,
	})
	machine["tell_rung"] = 0
	machine["locked_down"] = false
	machine["last_message"] = "Pick a lane. Read both shelves."
	root.remove_child(panel)
	panel.queue_free()
	await process_frame
	var stage_files: Array = []
	var stage_files_saved := true
	for stage_index in range(evidence_stage_count):
		var stage_file := "07%c_tell_%s_1280x720.png" % [97 + stage_index, str(TELL_STAGE_IDS[stage_index])]
		var stage_saved := await _capture_tell_stage(stage_surfaces[stage_index], str(TELL_STAGE_IDS[stage_index]), stage_file)
		stage_files.append({"id": str(TELL_STAGE_IDS[stage_index]), "file": stage_file, "saved": stage_saved})
		stage_files_saved = stage_files_saved and stage_saved
	var capture_record: Dictionary = captures.back()
	capture_record["stage_files"] = stage_files
	capture_record["state_valid"] = bool(capture_record.get("state_valid", false)) and stage_files_saved
	if not stage_files_saved:
		failed = true


func _capture_tell_stage(surface_state: Dictionary, stage_id: String, file_name: String) -> bool:
	var panel := ColorRect.new()
	panel.color = Color("#070b14")
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(panel)
	var title := Label.new()
	title.text = "TELL LADDER: %s" % stage_id.to_upper()
	title.position = Vector2(32, 18)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#e9f4ff"))
	panel.add_child(title)
	var snapshot: Dictionary = surface_state.get("coin_pusher_snapshot", {}) if typeof(surface_state.get("coin_pusher_snapshot", {})) == TYPE_DICTIONARY else {}
	var proof := Label.new()
	proof.text = "PRODUCTION STATE   RUNG %d   %s" % [int(snapshot.get("tell_rung", -1)), "MACHINE LOCKED" if bool(snapshot.get("locked", false)) else "MACHINE LIVE"]
	proof.position = Vector2(32, 56)
	proof.add_theme_font_size_override("font_size", 18)
	proof.add_theme_color_override("font_color", Color("#ff6b5f") if bool(snapshot.get("locked", false)) else Color("#58e1d4"))
	panel.add_child(proof)
	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.position = Vector2(40, 94)
	canvas.size = Vector2(1200, 580)
	canvas.set_game_module(game)
	canvas.render_game_snapshot(surface_state)
	canvas.set_process(false)
	canvas.set("flicker", 0.75)
	panel.add_child(canvas)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var saved := image != null and image.save_png("%s/%s" % [out_dir, file_name]) == OK
	root.remove_child(panel)
	panel.queue_free()
	await process_frame
	return saved


func _surface_with_result_events(result: Dictionary, surface_time_msec: int) -> Dictionary:
	var surface := game.surface_state(run_state, run_state.current_environment, {"coin_pusher_lane": 2, "surface_time_msec": surface_time_msec})
	var snapshot: Dictionary = surface.get("coin_pusher_snapshot", {}) if typeof(surface.get("coin_pusher_snapshot", {})) == TYPE_DICTIONARY else {}
	var patch: Dictionary = result.get("surface_presentation_snapshot_patch", {}) if typeof(result.get("surface_presentation_snapshot_patch", {})) == TYPE_DICTIONARY else {}
	for key in patch.keys():
		var value: Variant = patch.get(key)
		snapshot[key] = (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else value
	return surface


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


func _packed_state(seed_value: int) -> Dictionary:
	return SolverScript.create(_rng(seed_value), SHIPPED_COIN_CAP, SHIPPED_OPENING_COIN_COUNT, 5)


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
