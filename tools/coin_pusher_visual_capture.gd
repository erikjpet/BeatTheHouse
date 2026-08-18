extends SceneTree

const REQUIRED_CAPTURE_IDS := ["normal_pile_rider_live", "reduced_motion_live"]

# Deterministic, test-only Quarter Falls evidence capture.
# Run windowed so the viewport texture contains real rendered pixels:
#   Godot --path . --script res://tools/coin_pusher_visual_capture.gd

const MainScene := preload("res://scenes/main.tscn")
const OUTPUT_DIR := "res://.tmp/coin_pusher_visual_qa"
const CAPTURE_SIZE := Vector2i(1280, 720)
const FIXTURE_ID := "coin_pusher_visual_capture"
const FIXTURE_SEED := "QUARTER-FALLS-VISUAL-CAPTURE"

var app: Control
var out_dir := OUTPUT_DIR
var captures: Array[Dictionary] = []
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
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "coin_pusher_visual_capture")
	root.add_child(app)
	await _settle(4)
	app.call("start_foundation_run", FIXTURE_SEED)
	await _settle(6)
	if not _install_fixture_environment():
		_finish(1)
		return
	await _settle(5)

	var run_state := app.get("run_state") as RunState
	var machine := _machine(run_state)
	if (machine.get("riders", []) as Array).is_empty():
		_fail("Quarter Falls generation did not persist a rider before compact snapshot creation.")
	app.call("_refresh")
	await _settle(3)
	if not bool(app.call("enter_game", "coin_pusher")):
		_fail("Could not enter Quarter Falls in the deterministic Bar fixture.")
		_finish(1)
		return
	await _settle(4)

	await _capture_surface(
		"01_normal_pile_rider_live_1280x720.png",
		"normal_pile_rider_live",
		false
	)

	var settings: Variant = app.get("user_settings")
	if settings == null:
		_fail("Could not access reduced-motion settings.")
	else:
		settings.reduce_motion = true
		# Exercise the same settings boundary as a real user. The low-level
		# accessibility helper styles controls, while this boundary also rebuilds
		# the active game snapshot with the live host-owned preference.
		app.call("_on_settings_applied")
		await _settle(3)
		await _capture_surface(
			"02_reduced_motion_live_1280x720.png",
			"reduced_motion_live",
			true
		)
		settings.reduce_motion = false
		app.call("_on_settings_applied")
		await _settle(3)

	# Cabinet tells/lockdown and variation captures belong to Stages 3 and 4.
	# This Stage-2 tool intentionally captures the continuous live machine only.
	_write_manifest()
	_finish(1 if failed else 0)


func _install_fixture_environment() -> bool:
	var run_state := app.get("run_state") as RunState
	var library := app.get("library") as ContentLibrary
	if run_state == null or library == null:
		_fail("Could not access the foundation run or content library.")
		return false
	var archetype := library.environment_archetype("bar")
	if archetype.is_empty():
		_fail("The Bar archetype is unavailable.")
		return false
	var rng := run_state.create_rng("coin_pusher_visual_capture:environment")
	var environment := EnvironmentInstance.from_archetype(archetype, 0, rng, library).to_dict()
	environment["id"] = FIXTURE_ID
	environment["archetype_id"] = "bar"
	environment["world_node_id"] = "bar"
	environment["game_ids"] = ["coin_pusher", "bar_dice"]
	environment["event_ids"] = []
	environment["resolved_event_ids"] = []
	environment["item_offers"] = []
	environment["service_ids"] = []
	environment["lender_hooks"] = []
	environment["object_fixtures"] = []
	environment["scenario_game_modifiers"] = {"coin_pusher": {"variation_id": "quarter_falls", "prize_item_ids": ["coffee"]}}
	var states: Dictionary = {}
	for game_id in environment.get("game_ids", []):
		var definition := library.game(str(game_id))
		var module: Variant = app.call("_create_game_module", definition)
		if module == null or not module is GameModule:
			continue
		var game := module as GameModule
		var state := game.generate_environment_state(run_state, environment, run_state.create_rng("coin_pusher_visual_capture:state:%s" % str(game_id)))
		if not state.is_empty():
			states[str(game_id)] = state.duplicate(true)
	environment["game_states"] = states
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)
	run_state.set_environment(environment)
	run_state.bankroll = 500
	run_state.drunk_level = 0
	run_state.pending_drunk_absorption = []
	app.call("back_to_environment")
	app.call("_refresh")
	return not _machine(run_state).is_empty()




func _capture_surface(file_name: String, capture_id: String, expected_reduce_motion: bool) -> void:
	var canvas := app.get("game_surface_canvas") as Control
	if canvas == null or not canvas.visible or not canvas.has_method("realtime_surface_state"):
		_fail("Quarter Falls surface is unavailable for %s." % capture_id)
		return
	canvas.call("reset_performance_counters")
	var before_state: Dictionary = canvas.call("realtime_surface_state")
	var before_motion: Dictionary = canvas.call("debug_surface_motion_sample")
	var before_ticks := int(before_state.get("coin_pusher_liveness_ticks", 0))
	await _settle(18 if expected_reduce_motion else 12)
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	var state: Dictionary = canvas.call("realtime_surface_state")
	var presentation := _presentation_snapshot(state)
	var runtime: Dictionary = canvas.call("surface_runtime_status")
	var after_motion: Dictionary = canvas.call("debug_surface_motion_sample")
	var bodies: Array = presentation.get("bodies", [])
	var solver_advanced := int(state.get("coin_pusher_liveness_ticks", 0)) > before_ticks \
		and JSON.stringify(before_motion) != JSON.stringify(after_motion)
	var reduced_schedule_valid := not expected_reduce_motion \
		or (int(runtime.get("surface_animation_redraw_count", -1)) == 0 \
		and not bool(runtime.get("surface_continuous_redraw_active", true)))
	var valid := str(state.get("surface_renderer", "")) == "coin_pusher" \
		and str(state.get("surface_life", "")) == "coin_pusher_v3_alive_cabinet" \
		and bool(state.get("coin_pusher_alive_cabinet", false)) \
		and bodies.size() >= 24 \
		and _distinct_axis_count(bodies, "x") > 5 \
		and _distinct_axis_count(bodies, "y") > 6 \
		and (presentation.get("riders", []) as Array).size() >= 1 \
		and bool(runtime.get("reduce_motion", false)) == expected_reduce_motion \
		and solver_advanced \
		and reduced_schedule_valid
	if not valid:
		_fail("Quarter Falls Stage-3 alive cabinet did not match %s expectations." % capture_id)
	var saved := await _save_viewport(file_name)
	captures.append({
		"id": capture_id,
		"file": file_name,
		"saved": saved,
		"state_valid": valid,
		"surface_renderer": str(state.get("surface_renderer", "")),
		"body_count": bodies.size(),
		"distinct_x_count": _distinct_axis_count(bodies, "x"),
		"distinct_y_count": _distinct_axis_count(bodies, "y"),
		"rider_count": (presentation.get("riders", []) as Array).size(),
		"expected_reduce_motion": expected_reduce_motion,
		"reduce_motion": bool(runtime.get("reduce_motion", false)),
		"solver_ticks_before": before_ticks,
		"solver_ticks_after": int(state.get("coin_pusher_liveness_ticks", 0)),
		"motion_before": before_motion,
		"motion_after": after_motion,
		"solver_advanced": solver_advanced,
		"animation_redraw_count": int(runtime.get("surface_animation_redraw_count", -1)),
		"continuous_redraw_active": bool(runtime.get("surface_continuous_redraw_active", false)),
	})


func _save_viewport(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	if image == null:
		_fail("Viewport capture is unavailable; run the helper windowed.")
		return false
	if image.get_size() != CAPTURE_SIZE:
		image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_NEAREST)
	var error := image.save_png("%s/%s" % [out_dir, file_name])
	if error != OK:
		_fail("Could not save %s (error %d)." % [file_name, error])
		return false
	return true


func _write_manifest() -> void:
	var required_capture_ids := REQUIRED_CAPTURE_IDS
	var valid_capture_count := 0
	var saved_capture_count := 0
	var captured_ids: Array = []
	var reduced_motion_proof_passed := false
	for capture in captures:
		var capture_id := str(capture.get("id", ""))
		captured_ids.append(capture_id)
		if bool(capture.get("state_valid", false)):
			valid_capture_count += 1
		if bool(capture.get("saved", false)):
			saved_capture_count += 1
		if capture_id == "reduced_motion_live":
			reduced_motion_proof_passed = bool(capture.get("reduce_motion", false)) \
				and bool(capture.get("solver_advanced", false)) \
				and int(capture.get("animation_redraw_count", -1)) == 0 \
				and not bool(capture.get("continuous_redraw_active", true))
	var manifest_authoritative_pass := captures.size() == required_capture_ids.size() \
		and JSON.stringify(captured_ids) == JSON.stringify(required_capture_ids) \
		and valid_capture_count == required_capture_ids.size() \
		and saved_capture_count == required_capture_ids.size() \
		and reduced_motion_proof_passed
	if not manifest_authoritative_pass:
		_fail("Quarter Falls focused capture manifest did not satisfy every required visual proof.")
	var manifest := {
		"fixture": "Quarter Falls canonical visual QA",
		"seed": FIXTURE_SEED,
		"environment_id": FIXTURE_ID,
		"capture_size": {"width": CAPTURE_SIZE.x, "height": CAPTURE_SIZE.y},
		"deterministic_presentation_flicker": 0.75,
		"required_capture_ids": required_capture_ids,
		"required_capture_count": required_capture_ids.size(),
		"valid_capture_count": valid_capture_count,
		"saved_capture_count": saved_capture_count,
		"reduced_motion_proof_passed": reduced_motion_proof_passed,
		"passed": not failed and manifest_authoritative_pass,
		"captures": captures,
	}
	var file := FileAccess.open("%s/manifest.json" % out_dir, FileAccess.WRITE)
	if file == null:
		_fail("Could not write the Quarter Falls capture manifest.")
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()


func _machine(run_state: RunState) -> Dictionary:
	if run_state == null:
		return {}
	var states: Dictionary = run_state.current_environment.get("game_states", {}) if typeof(run_state.current_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var value: Variant = states.get("coin_pusher", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _presentation_snapshot(surface_state: Dictionary) -> Dictionary:
	return {
		"bodies": (surface_state.get("coin_pusher_bodies", []) as Array).duplicate(true),
		"features": (surface_state.get("coin_pusher_features", []) as Array).duplicate(true),
		"riders": (surface_state.get("coin_pusher_riders", []) as Array).duplicate(true),
	}


func _distinct_axis_count(bodies: Array, axis: String) -> int:
	var values := {}
	for body_value in bodies:
		if typeof(body_value) == TYPE_DICTIONARY:
			values[int((body_value as Dictionary).get(axis, 0))] = true
	return values.size()


func _settle(frame_count: int) -> void:
	for _index in range(frame_count):
		await process_frame


func _fail(message: String) -> void:
	failed = true
	push_error(message)


func _finish(exit_code: int) -> void:
	print("COIN_PUSHER_VISUAL_CAPTURE_%s captures=%d out=%s" % ["PASS" if exit_code == 0 else "FAIL", captures.size(), ProjectSettings.globalize_path(out_dir)])
	quit(exit_code)
