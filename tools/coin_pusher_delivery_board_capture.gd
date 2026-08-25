extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const Solver := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")
const Renderer := preload("res://scripts/games/coin_pusher/coin_pusher_renderer.gd")
const CAPTURE_SIZE := Vector2i(1280, 720)
const STAGES := ["release", "pre_contact", "contact", "post_bounce", "mid_fall", "landing"]
const VARIATIONS := [
	{"id": "quarter_falls", "drop_x": 50000},
	{"id": "jackpot_ridge", "drop_x": 50000},
	{"id": "vault_drop", "drop_x": 42000},
]

var app: Control
var canvas: Control
var game: GameModule
var out_dir := ""
var failed := false
var manifest_variations: Array = []


func _init() -> void:
	var timestamp := Time.get_datetime_string_from_system(false, true).replace(":", "-")
	out_dir = "res://.tmp/coin_pusher_delivery_board_%s" % timestamp
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=").strip_edges()
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	root.size = CAPTURE_SIZE
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "coin_pusher_delivery_capture_%d" % Time.get_ticks_usec())
	root.add_child(app)
	await _frames(4)
	app.call("start_game_test_session", "coin_pusher")
	await _frames(8)
	game = app.get("current_game") as GameModule
	canvas = app.get("game_surface_canvas") as Control
	if game == null or canvas == null:
		_fail("Production Coin Pusher surface did not open.")
		_finish()
		return
	app.set_process(false)
	for variation_value in VARIATIONS:
		await _capture_variation(variation_value)
	if manifest_variations.size() != VARIATIONS.size():
		_fail("Delivery capture produced %d/%d required variation records." % [manifest_variations.size(), VARIATIONS.size()])
	_write_manifest()
	_finish()


func _capture_variation(spec: Dictionary) -> void:
	var variation_id := str(spec["id"])
	var definition: Dictionary = game.call("_machine_definition", variation_id)
	if definition.is_empty():
		_fail("Missing production machine definition for %s." % variation_id)
		return
	var state := Solver.create_machine(_rng("delivery:%s" % variation_id), definition, 0)
	var previous_views := Solver.body_views(state)
	var dropped: Dictionary = Solver.add_coin(state, _rng("delivery-drop:%s" % variation_id), int(spec["drop_x"]), 1)
	var body_id := str(dropped.get("id", ""))
	var frames := {
		"release": _frame_record(state, previous_views, body_id, []),
	}
	var last_falling: Dictionary = frames["release"]
	var contact_z := 0
	var contact_seen := false
	var post_pending := false
	var invariants_ok := true
	var invariant_failures: Array = []
	for _tick in range(5000):
		previous_views = Solver.body_views(state)
		# Acceptance captures use the canonical reference step explicitly so an
		# obsolete local native binary cannot fabricate a green presentation run.
		# The stage's export-parity gate proves the rebuilt native path separately.
		var result: Dictionary = Solver.step_ticks_reference_for_test(state, {"motor_enabled": true}, 1)
		var tick_energy_ok := bool((result.get("invariants", {}) as Dictionary).get("energy_ok", false))
		invariants_ok = invariants_ok and tick_energy_ok and bool((result.get("invariants", {}) as Dictionary).get("conservation_ok", false))
		var events: Array = result.get("events", [])
		var record := _frame_record(state, previous_views, body_id, events)
		var body: Dictionary = record.get("body", {})
		if not tick_energy_ok:
			var before_body := _body_from_views(previous_views, body_id)
			var integrated := before_body.duplicate(true)
			integrated["vx"] = int(int(integrated.get("vx", 0)) * 61 / 64)
			integrated["vy"] = int(int(integrated.get("vy", 0)) * 61 / 64)
			integrated["vz"] = int(integrated.get("vz", 0)) - Solver.GRAVITY
			var before_energy := _body_energy(before_body)
			var integrated_energy := _body_energy(integrated)
			invariant_failures.append({"tick": int(state.get("tick", 0)), "before": before_body, "after": body, "before_energy": before_energy, "gravity_integrated_energy": integrated_energy, "allowed_without_platform_or_support_work": maxi(before_energy, integrated_energy), "after_energy": _body_energy(body), "events": events.duplicate(true)})
		var is_falling := str(body.get("rest_state", "")) == "falling"
		var hit_peg := _has_body_event(events, "peg_impact", body_id)
		var landed := _has_landing_event(events, body_id)
		if not contact_seen and is_falling and not hit_peg:
			last_falling = record
		if hit_peg and not contact_seen:
			frames["pre_contact"] = last_falling
			frames["contact"] = record
			contact_z = int(body.get("z", 0))
			contact_seen = true
			post_pending = true
			continue
		if post_pending:
			frames["post_bounce"] = record
			post_pending = false
			continue
		if contact_seen and not frames.has("mid_fall") and is_falling and int(body.get("z", contact_z)) < contact_z - 1000:
			frames["mid_fall"] = record
		if landed:
			frames["landing"] = record
			break
	if not _valid_stage_sequence(frames, body_id) or not invariants_ok:
		_fail("%s did not produce the required real release/bounce/landing sequence: stages=%s final_tick=%d final_body=%s invariant_failures=%s" % [variation_id, JSON.stringify(frames.keys()), int(state.get("tick", -1)), JSON.stringify(_body_from_views(Solver.body_views(state), body_id)), JSON.stringify(invariant_failures)])
		return
	var normal_images: Array[Image] = []
	var reduced_images: Array[Image] = []
	var stage_evidence: Array = []
	for stage in STAGES:
		var record: Dictionary = frames[stage]
		normal_images.append(await _render_frame(definition, variation_id, record, false))
		reduced_images.append(await _render_frame(definition, variation_id, record, true))
		stage_evidence.append({
			"stage": stage,
			"tick": int(record.get("tick", -1)),
			"body_id": body_id,
			"body": record.get("body", {}),
			"events": record.get("events", []),
			"previous_body": _body_from_views(record.get("previous_views", []), body_id),
		})
	var shadow_record: Dictionary = frames["mid_fall"]
	var shadow_image: Image = await _render_frame(definition, variation_id, shadow_record, false)
	var shadow_control: Image = await _render_frame(definition, variation_id, shadow_record, false, {}, body_id)
	var shadow_evidence := _airborne_shadow_pixel_evidence(definition, shadow_record, body_id, shadow_image, shadow_control)
	var shadow_file := "%s_airborne_shadow.png" % variation_id
	var shadow_control_file := "%s_airborne_shadow_body_removed_control.png" % variation_id
	var shadow_files_saved := shadow_image.save_png("%s/%s" % [out_dir, shadow_file]) == OK and shadow_control.save_png("%s/%s" % [out_dir, shadow_control_file]) == OK
	shadow_evidence["airborne_capture"] = shadow_file
	shadow_evidence["body_removed_control_capture"] = shadow_control_file
	shadow_evidence["captures_saved"] = shadow_files_saved
	shadow_evidence["passed"] = bool(shadow_evidence.get("passed", false)) and shadow_files_saved
	var normal_file := "%s_delivery_normal.png" % variation_id
	var reduced_file := "%s_delivery_reduced_motion.png" % variation_id
	var normal_saved := _save_strip(normal_images, "%s/%s" % [out_dir, normal_file])
	var reduced_saved := _save_strip(reduced_images, "%s/%s" % [out_dir, reduced_file])
	var presentation: Dictionary = game.renderer_signature(canvas.call("realtime_surface_state"))
	var board: Dictionary = presentation.get("delivery_board", {})
	var board_source: Dictionary = board.get("source", {})
	var apparatus: Dictionary = definition.get("apparatus", {})
	var exact_peg_projection := (board.get("pegs", []) as Array).size() == (apparatus.get("pegs", []) as Array).size()
	var continuity := (board.get("landing_left", Vector2.ZERO) as Vector2).distance_to(_normal_landing(definition, int(board_source.get("x_min", 0)))) <= 1.0 \
		and (board.get("landing_right", Vector2.ZERO) as Vector2).distance_to(_normal_landing(definition, int(board_source.get("x_max", 100000)))) <= 1.0
	var bounded := _board_is_bounded(board)
	var entry_hardware_ok := _entry_hardware_is_bounded(presentation.get("entry_hardware", {}))
	var release_clear := _release_disks_clear(definition, int(spec["drop_x"]))
	var board_height := absf((board.get("landing_left", Vector2.ZERO) as Vector2).y - (board.get("top_left", Vector2.ZERO) as Vector2).y)
	var readable_height := board_height >= 120.0 and board_height <= 160.0
	var vault_evidence := {}
	if variation_id == "vault_drop":
		vault_evidence = await _capture_vault_hardware(definition, shadow_record)
	if not normal_saved or not reduced_saved or not exact_peg_projection or not continuity or not bounded or not entry_hardware_ok or not release_clear or not readable_height or not bool(shadow_evidence.get("passed", false)) or (variation_id == "vault_drop" and not bool(vault_evidence.get("passed", false))):
		_fail("%s delivery presentation evidence was incomplete." % variation_id)
	manifest_variations.append({
		"variation_id": variation_id,
		"body_id": body_id,
		"normal_strip": normal_file,
		"reduced_motion_strip": reduced_file,
		"capture_size": {"width": CAPTURE_SIZE.x, "height": CAPTURE_SIZE.y},
		"stages": stage_evidence,
		"apparatus": apparatus.duplicate(true),
		"presentation": presentation,
		"airborne_shadow_pixel_evidence": shadow_evidence,
		"vault_hardware_evidence": vault_evidence,
		"evidence": {
			"same_body_id_all_stages": true,
			"real_peg_impact": true,
			"upper_support_landing": true,
			"energy_and_conservation_invariants": invariants_ok,
			"exact_public_peg_projection": exact_peg_projection,
			"board_to_platform_continuity_px_lte_1": continuity,
			"board_bounded_inside_playfield": bounded,
			"board_height_design_px": board_height,
			"board_height_120_to_160_px": readable_height,
			"entry_hardware_inside_playfield_not_backglass": entry_hardware_ok,
			"release_disk_clear_of_pegs": release_clear,
			"airborne_shadow_visibly_offset": bool(shadow_evidence.get("passed", false)),
			"normal_and_reduced_motion_at_minimum_viewport": normal_saved and reduced_saved,
		},
	})


func _frame_record(state: Dictionary, previous_views: Array, body_id: String, events: Array) -> Dictionary:
	var current_views := Solver.body_views(state)
	return {
		"tick": int(state.get("tick", 0)),
		"state": state.duplicate(true),
		"previous_views": previous_views.duplicate(true),
		"current_views": current_views,
		"body": _body_from_views(current_views, body_id),
		"events": events.duplicate(true),
	}


func _render_frame(definition: Dictionary, variation_id: String, record: Dictionary, reduced_motion: bool, extra_patch: Dictionary = {}, excluded_body_id: String = "") -> Image:
	var state: Dictionary = record["state"]
	var tray: Array = state.get("tray_ledger", [])
	var current_views: Array = (record["current_views"] as Array).duplicate(true)
	var previous_views: Array = (record["previous_views"] as Array).duplicate(true)
	if not excluded_body_id.is_empty():
		current_views = current_views.filter(func(body): return str((body as Dictionary).get("id", "")) != excluded_body_id)
		previous_views = previous_views.filter(func(body): return str((body as Dictionary).get("id", "")) != excluded_body_id)
	var patch := {
		"coin_pusher_variation_id": variation_id,
		"coin_pusher_geometry": (definition.get("geometry", {}) as Dictionary).duplicate(true),
		"coin_pusher_apparatus": (definition.get("apparatus", {}) as Dictionary).duplicate(true),
		"coin_pusher_cabinet": (definition.get("cabinet", {}) as Dictionary).duplicate(true),
		"coin_pusher_coin_height": int((definition.get("coins", {}) as Dictionary).get("height", 1700)),
		"coin_pusher_bodies": current_views,
		"coin_pusher_previous_bodies": previous_views,
		"coin_pusher_body_count": current_views.size(),
		"coin_pusher_face_position_y": int(state.get("face_y", 28000)),
		"coin_pusher_previous_face_position_y": int(state.get("previous_face_y", state.get("face_y", 28000))),
		"coin_pusher_carriage_x": int(state.get("carriage_x", 50000)),
		"coin_pusher_selected_hole": int(state.get("selected_hole", 0)),
		"coin_pusher_presentation_view_serial": int(record.get("tick", 0)) + (1000000 if not excluded_body_id.is_empty() else 0),
		"coin_pusher_interpolation_alpha": 0.5,
		"coin_pusher_tray_count": tray.size(),
		"coin_pusher_tray_value": _ledger_value(tray),
		"reduce_motion": reduced_motion,
	}
	patch.merge(extra_patch, true)
	canvas.call("apply_surface_state_patch", patch)
	canvas.queue_redraw()
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null:
		return Image.new()
	var result := image.duplicate()
	# Windows display scaling can expose physical framebuffer pixels here; the
	# acceptance artifact is the project's authored 1280x720 logical viewport.
	if result.get_size() != CAPTURE_SIZE:
		result.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	return result


func _airborne_shadow_pixel_evidence(definition: Dictionary, record: Dictionary, body_id: String, image: Image, control: Image) -> Dictionary:
	var body := _body_from_views(record.get("current_views", []), body_id)
	var previous := _body_from_views(record.get("previous_views", []), body_id)
	var renderer = Renderer.new()
	var projection_state := {
		"coin_pusher_geometry": definition.get("geometry", {}),
		"coin_pusher_apparatus": definition.get("apparatus", {}),
		"coin_pusher_coin_height": int((definition.get("coins", {}) as Dictionary).get("height", 1700)),
	}
	var board: Dictionary = renderer.debug_delivery_board_for_test(projection_state).get("source", {})
	var x := lerpf(float(previous.get("x", body.get("x", 0))), float(body.get("x", 0)), 0.5)
	var y := lerpf(float(previous.get("y", body.get("y", 0))), float(body.get("y", 0)), 0.5)
	var z := lerpf(float(previous.get("z", body.get("z", 0))), float(body.get("z", 0)), 0.5)
	var on_board := absi(int(round(y)) - int(board.get("y", 0))) <= int(body.get("radius", 4300)) and z >= float(board.get("z_bottom", 0))
	var body_point: Vector2 = renderer.debug_project_delivery_board_point_for_test(projection_state, x, z) if on_board else renderer.debug_project_for_test(projection_state, x, y, z)
	var shadow_base: Vector2 = renderer.debug_project_delivery_board_point_for_test(projection_state, x, z) if on_board and z > float(board.get("z_bottom", 0)) + float(projection_state["coin_pusher_coin_height"]) else renderer.debug_project_for_test(projection_state, x, y, float(board.get("z_bottom", 0)))
	var shadow_offset: Vector2 = renderer.render_signature(projection_state).get("airborne_shadow_offset", Vector2.ZERO)
	var shadow_point := shadow_base + shadow_offset
	var transform_values: Dictionary = canvas.call("debug_design_space_transform", Vector2(900, 430))
	var scale: Vector2 = transform_values.get("scale", Vector2.ONE)
	var origin: Vector2 = canvas.global_position + transform_values.get("position", Vector2.ZERO)
	var changed_pixels := 0
	var max_delta := 0.0
	# The right-hand crescent is beyond the coin ellipse, so any delta here is
	# the separately drawn airborne shadow rather than the coin itself.
	for dx in range(10, 17):
		for dy in range(-4, 5):
			var viewport_point := origin + (shadow_point + Vector2(dx, dy)) * scale
			var pixel := Vector2i(roundi(viewport_point.x), roundi(viewport_point.y))
			if not Rect2i(Vector2i.ZERO, image.get_size()).has_point(pixel):
				continue
			var delta := _color_delta(image.get_pixelv(pixel), control.get_pixelv(pixel))
			if delta > 0.035:
				changed_pixels += 1
			max_delta = maxf(max_delta, delta)
	var live_backed := str(body.get("id", "")) == body_id and str(previous.get("id", "")) == body_id and str(body.get("rest_state", "")) == "falling"
	return {
		"passed": live_backed and shadow_offset.length() >= 12.0 and changed_pixels >= 12 and max_delta >= 0.10,
		"live_falling_body": live_backed,
		"body_id": body_id,
		"tick": int(record.get("tick", -1)),
		"body_design_point": body_point,
		"shadow_design_point": shadow_point,
		"shadow_offset": shadow_offset,
		"right_crescent_changed_pixels": changed_pixels,
		"right_crescent_max_rgb_delta": max_delta,
		"control_removed_only_body_id": body_id,
	}


func _capture_vault_hardware(definition: Dictionary, record: Dictionary) -> Dictionary:
	var forces := {"tap": {"tolerance_cost": 1, "push_strength": 1}, "shove": {"tolerance_cost": 2, "push_strength": 2}, "slam": {"tolerance_cost": 4, "push_strength": 4}}
	var cells: Array = []
	for index in range(6):
		cells.append({"index": index, "label": "?", "opened": false, "peeked": false, "selection_action": "coin_pusher_vault_cell_%d" % index})
	var bindings := _capture_hardware_bindings(definition, forces, cells)
	bindings["open_vault_cell"]["enabled"] = false
	bindings["stop_vault_round"]["enabled"] = false
	bindings["peek_vault_cell"]["enabled"] = false
	var closed_machine := {"variation_id": "vault_drop", "nudge_force": "tap", "nudge_direction": "front", "vault_selected_cell": 0, "variation_state": {"vault_round_active": false}}
	var base_patch := {
		"coin_pusher_nudge_forces": forces,
		"coin_pusher_nudge_force": "tap",
		"coin_pusher_nudge_direction": "front",
		"coin_pusher_vault_cells": cells,
		"coin_pusher_vault_selected_cell": 0,
		"coin_pusher_vault_round_active": false,
		"coin_pusher_feature_hardware": game.call("_feature_hardware_descriptor", closed_machine, {"cells": cells}),
		"surface_action_bindings": bindings,
		"coin_pusher_locked": false,
	}
	var closed := await _render_frame(definition, "vault_drop", record, false, base_patch)
	var closed_signature: Dictionary = game.renderer_signature(canvas.call("realtime_surface_state"))
	var open_bindings: Dictionary = bindings.duplicate(true)
	open_bindings["start_vault_round"]["enabled"] = false
	open_bindings["open_vault_cell"]["enabled"] = true
	open_bindings["stop_vault_round"]["enabled"] = true
	open_bindings["peek_vault_cell"]["enabled"] = true
	var open_cells := cells.duplicate(true)
	(open_cells[2] as Dictionary)["peeked"] = true
	(open_cells[2] as Dictionary)["label"] = "$50"
	var open_patch := base_patch.duplicate(true)
	var open_machine := {"variation_id": "vault_drop", "nudge_force": "tap", "nudge_direction": "front", "vault_selected_cell": 2, "variation_state": {"vault_round_active": true}}
	open_patch.merge({"coin_pusher_vault_round_active": true, "coin_pusher_vault_cells": open_cells, "coin_pusher_vault_selected_cell": 2, "coin_pusher_feature_hardware": game.call("_feature_hardware_descriptor", open_machine, {"cells": open_cells}), "surface_action_bindings": open_bindings}, true)
	var open := await _render_frame(definition, "vault_drop", record, false, open_patch)
	var open_signature: Dictionary = game.renderer_signature(canvas.call("realtime_surface_state"))
	var locked_bindings: Dictionary = open_bindings.duplicate(true)
	for action in locked_bindings.keys():
		(locked_bindings[action] as Dictionary)["enabled"] = false
	var locked_patch := open_patch.duplicate(true)
	locked_patch.merge({"coin_pusher_locked": true, "surface_action_bindings": locked_bindings}, true)
	var locked := await _render_frame(definition, "vault_drop", record, false, locked_patch)
	var locked_signature: Dictionary = game.renderer_signature(canvas.call("realtime_surface_state"))
	var files := ["vault_door_closed.png", "vault_door_cells_selected.png", "vault_alarm_locked_dark.png"]
	var images: Array[Image] = [closed, open, locked]
	var saved := true
	for index in range(files.size()):
		saved = images[index].save_png("%s/%s" % [out_dir, files[index]]) == OK and saved
	var normal_luma := _design_rect_luminance(open, Renderer.CABINET_RECT)
	var locked_luma := _design_rect_luminance(locked, Renderer.CABINET_RECT)
	var expected_closed := _expected_enabled_hardware_actions(definition, bindings, forces, cells)
	var expected_open := _expected_enabled_hardware_actions(definition, open_bindings, forces, open_cells)
	var closed_actions: Array = closed_signature.get("hardware_actions", [])
	var open_actions: Array = open_signature.get("hardware_actions", [])
	var locked_actions: Array = locked_signature.get("hardware_actions", [])
	var door_pixels_change := _image_region_delta(closed, open, Rect2(52, 402, 540, 24))
	return {
		"passed": saved and closed_actions == expected_closed and open_actions == expected_open and locked_actions.is_empty() and locked_luma < normal_luma * 0.55 and door_pixels_change > 0.01,
		"captures": files,
		"closed_hardware_actions": closed_actions,
		"closed_expected_actions": expected_closed,
		"open_hardware_actions": open_actions,
		"open_expected_actions": expected_open,
		"locked_hardware_actions": locked_actions,
		"locked_controls_inert": locked_actions.is_empty(),
		"normal_cabinet_luminance": normal_luma,
		"locked_cabinet_luminance": locked_luma,
		"locked_luminance_ratio": locked_luma / maxf(normal_luma, 0.0001),
		"door_cell_region_rgb_delta": door_pixels_change,
	}


func _capture_hardware_bindings(definition: Dictionary, forces: Dictionary, cells: Array) -> Dictionary:
	var bindings := {
		"coin_pusher_drop": {"enabled": true}, "coin_pusher_skill_stop": {"enabled": true},
		"coin_pusher_collect": {"enabled": true}, "coin_pusher_nudge": {"enabled": true},
		"start_vault_round": {"enabled": true}, "open_vault_cell": {"enabled": true},
		"stop_vault_round": {"enabled": true}, "peek_vault_cell": {"enabled": true},
	}
	var apparatus: Dictionary = definition.get("apparatus", {})
	if str(apparatus.get("type", "rail_slot")) == "hole_set":
		for index in range((apparatus.get("holes", []) as Array).size()):
			bindings["coin_pusher_hole_%d" % index] = {"enabled": true}
	else:
		bindings["coin_pusher_carriage_left"] = {"enabled": true}
		bindings["coin_pusher_carriage_right"] = {"enabled": true}
	for force in forces.keys():
		bindings["coin_pusher_force_%s" % str(force)] = {"enabled": true}
	for direction in ["left", "front", "right"]:
		bindings["coin_pusher_direction_%s" % direction] = {"enabled": true}
	for cell in cells:
		bindings[str((cell as Dictionary)["selection_action"])] = {"enabled": true}
	return bindings


func _expected_enabled_hardware_actions(definition: Dictionary, bindings: Dictionary, forces: Dictionary, cells: Array) -> Array:
	var result: Array = []
	for action in ["coin_pusher_drop", "coin_pusher_skill_stop", "coin_pusher_collect", "coin_pusher_nudge"]:
		if bool((bindings[action] as Dictionary).get("enabled", false)):
			result.append(action)
	var apparatus: Dictionary = definition.get("apparatus", {})
	if str(apparatus.get("type", "rail_slot")) == "hole_set":
		for index in range((apparatus.get("holes", []) as Array).size()):
			var action := "coin_pusher_hole_%d" % index
			if bool((bindings[action] as Dictionary).get("enabled", false)):
				result.append(action)
	else:
		if bool((bindings["coin_pusher_carriage_left"] as Dictionary).get("enabled", false)) and bool((bindings["coin_pusher_carriage_right"] as Dictionary).get("enabled", false)):
			result.append("coin_pusher_carriage_drag")
		for action in ["coin_pusher_carriage_left", "coin_pusher_carriage_right"]:
			if bool((bindings[action] as Dictionary).get("enabled", false)):
				result.append(action)
	for force in forces.keys():
		var force_action := "coin_pusher_force_%s" % str(force)
		if bool((bindings[force_action] as Dictionary).get("enabled", false)):
			result.append(force_action)
	for direction in ["left", "front", "right"]:
		var direction_action := "coin_pusher_direction_%s" % direction
		if bool((bindings[direction_action] as Dictionary).get("enabled", false)):
			result.append(direction_action)
	for cell in cells:
		var action := str((cell as Dictionary)["selection_action"])
		if bool((bindings[action] as Dictionary).get("enabled", false)):
			result.append(action)
	for action in ["start_vault_round", "open_vault_cell", "stop_vault_round", "peek_vault_cell"]:
		if bool((bindings[action] as Dictionary).get("enabled", false)):
			result.append(action)
	return result


func _design_rect_luminance(image: Image, design_rect: Rect2) -> float:
	var transform_values: Dictionary = canvas.call("debug_design_space_transform", Vector2(900, 430))
	var scale: Vector2 = transform_values.get("scale", Vector2.ONE)
	var origin: Vector2 = canvas.global_position + transform_values.get("position", Vector2.ZERO)
	var total := 0.0
	var count := 0
	for y in range(int(design_rect.position.y), int(design_rect.end.y), 4):
		for x in range(int(design_rect.position.x), int(design_rect.end.x), 4):
			var pixel := Vector2i(origin + Vector2(x, y) * scale)
			if Rect2i(Vector2i.ZERO, image.get_size()).has_point(pixel):
				var color := image.get_pixelv(pixel)
				total += color.get_luminance()
				count += 1
	return total / float(maxi(1, count))


func _image_region_delta(first: Image, second: Image, design_rect: Rect2) -> float:
	var transform_values: Dictionary = canvas.call("debug_design_space_transform", Vector2(900, 430))
	var scale: Vector2 = transform_values.get("scale", Vector2.ONE)
	var origin: Vector2 = canvas.global_position + transform_values.get("position", Vector2.ZERO)
	var total := 0.0
	var count := 0
	for y in range(int(design_rect.position.y), int(design_rect.end.y), 2):
		for x in range(int(design_rect.position.x), int(design_rect.end.x), 2):
			var pixel := Vector2i(origin + Vector2(x, y) * scale)
			if Rect2i(Vector2i.ZERO, first.get_size()).has_point(pixel):
				total += _color_delta(first.get_pixelv(pixel), second.get_pixelv(pixel))
				count += 1
	return total / float(maxi(1, count))


func _color_delta(first: Color, second: Color) -> float:
	return (absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b)) / 3.0


func _save_strip(images: Array[Image], path: String) -> bool:
	if images.size() != STAGES.size():
		return false
	var strip := Image.create(CAPTURE_SIZE.x * images.size(), CAPTURE_SIZE.y, false, Image.FORMAT_RGBA8)
	for index in range(images.size()):
		var frame: Image = images[index]
		if frame.is_empty():
			return false
		strip.blit_rect(frame, Rect2i(Vector2i.ZERO, CAPTURE_SIZE), Vector2i(index * CAPTURE_SIZE.x, 0))
	return strip.save_png(path) == OK


func _valid_stage_sequence(frames: Dictionary, body_id: String) -> bool:
	for stage in STAGES:
		if not frames.has(stage) or str((frames[stage] as Dictionary).get("body", {}).get("id", "")) != body_id:
			return false
	var contact: Dictionary = frames["contact"]
	var landing: Dictionary = frames["landing"]
	var support := str((landing.get("body", {}) as Dictionary).get("support_kind", ""))
	return _has_body_event(contact.get("events", []), "peg_impact", body_id) \
		and _has_landing_event(landing.get("events", []), body_id) \
		and support in ["platform", "body"] \
		and int((frames["release"] as Dictionary).get("tick", -1)) < int(landing.get("tick", -1))


func _has_body_event(events: Array, kind: String, body_id: String) -> bool:
	for event_value in events:
		if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("kind", "")) == kind and str((event_value as Dictionary).get("body_id", "")) == body_id:
			return true
	return false


func _has_landing_event(events: Array, body_id: String) -> bool:
	for event_value in events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		if str(event.get("kind", "")) == "impact" and str(event.get("body_id", "")) == body_id and str(event.get("support", "")) in ["platform", "body"]:
			return true
	return false


func _body_from_views(views: Array, body_id: String) -> Dictionary:
	for body_value in views:
		if typeof(body_value) == TYPE_DICTIONARY and str((body_value as Dictionary).get("id", "")) == body_id:
			return (body_value as Dictionary).duplicate(true)
	return {}


func _normal_landing(definition: Dictionary, x: int) -> Vector2:
	var geometry: Dictionary = definition.get("geometry", {})
	var apparatus: Dictionary = definition.get("apparatus", {})
	var board: Dictionary = apparatus.get("drop_board", {})
	var state := {"coin_pusher_geometry": geometry, "coin_pusher_coin_height": int((definition.get("coins", {}) as Dictionary).get("height", 1700))}
	var renderer = Renderer.new()
	return renderer.debug_project_for_test(state, float(x), float(board.get("y", geometry.get("drop_y", 58000))), float(board.get("z_bottom", geometry.get("platform_top_z", 3600))))


func _board_is_bounded(board: Dictionary) -> bool:
	var rect: Rect2 = Renderer.PLAYFIELD_RECT
	for key in ["top_left", "top_right", "landing_left", "landing_right"]:
		if not rect.has_point(board.get(key, Vector2(-1, -1))):
			return false
	for peg_value in board.get("pegs", []):
		if typeof(peg_value) != TYPE_DICTIONARY:
			return false
		var peg: Dictionary = peg_value
		var center: Vector2 = peg.get("center", Vector2(-1, -1))
		var radius: Vector2 = peg.get("radius", Vector2.ZERO)
		if not rect.encloses(Rect2(center - radius, radius * 2.0)):
			return false
	return true


func _entry_hardware_is_bounded(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var layout: Dictionary = value
	var playfield: Rect2 = Renderer.PLAYFIELD_RECT
	var backglass: Rect2 = Renderer.BACKGLASS_RECT
	if str(layout.get("type", "")) == "hole_set":
		var targets: Array = layout.get("targets", [])
		if targets.size() != 3:
			return false
		for target_value in targets:
			var rect: Rect2 = (target_value as Dictionary).get("rect", Rect2())
			if rect.size.x < 44.0 or rect.size.y < 44.0 or not playfield.encloses(rect) or rect.intersects(backglass):
				return false
		return true
	var drag_rect: Rect2 = layout.get("drag_rect", Rect2())
	return drag_rect.size.y <= 44.0 and playfield.encloses(drag_rect) and not drag_rect.intersects(backglass)


func _release_disks_clear(definition: Dictionary, release_x: int) -> bool:
	var apparatus: Dictionary = definition.get("apparatus", {})
	var board: Dictionary = apparatus.get("drop_board", {})
	var release_z := int(board.get("z_top", (definition.get("geometry", {}) as Dictionary).get("drop_z", 24000)))
	var coin_radius := int((definition.get("coins", {}) as Dictionary).get("radius", 4300))
	for peg_value in apparatus.get("pegs", []):
		if typeof(peg_value) != TYPE_DICTIONARY:
			continue
		var peg: Dictionary = peg_value
		var dx := release_x - int(peg.get("x", 0))
		var dz := release_z - int(peg.get("z", 0))
		var clearance := coin_radius + int(peg.get("r", 0))
		if dx * dx + dz * dz < clearance * clearance:
			return false
	return true


func _ledger_value(ledger: Array) -> int:
	var total := 0
	for value in ledger:
		if typeof(value) == TYPE_DICTIONARY:
			total += int((value as Dictionary).get("value", 0))
	return total


func _body_energy(body: Dictionary) -> int:
	var mass := maxi(1, int(body.get("mass", 1000)))
	var vx := int(body.get("vx", 0))
	var vy := int(body.get("vy", 0))
	var vz := int(body.get("vz", 0))
	return int(mass * (int(vx * vx / 1000) + int(vy * vy / 1000) + int(vz * vz / 1000)) / 2000)


func _rng(seed: String) -> RngStream:
	var rng := RngStream.new()
	rng.configure(seed.hash() & 0x7fffffff)
	return rng


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _write_manifest() -> void:
	var manifest := {
		"schema": "coin_pusher_v3_delivery_board_capture",
		"generated_at": Time.get_datetime_string_from_system(false, true),
		"production_surface": true,
		"solver_backend": "gdscript_reference_v3",
		"stage_order": STAGES,
		"passed": not failed and manifest_variations.size() == VARIATIONS.size(),
		"variations": manifest_variations,
	}
	var file := FileAccess.open("%s/manifest.json" % out_dir, FileAccess.WRITE)
	if file == null:
		_fail("Could not write delivery-board manifest.")
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()


func _fail(message: String) -> void:
	failed = true
	push_error(message)


func _finish() -> void:
	print("COIN_PUSHER_DELIVERY_BOARD_CAPTURE_%s out=%s" % ["FAIL" if failed else "PASS", ProjectSettings.globalize_path(out_dir)])
	quit(1 if failed else 0)
