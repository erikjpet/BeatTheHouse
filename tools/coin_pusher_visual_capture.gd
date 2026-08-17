extends SceneTree

const REQUIRED_CAPTURE_IDS := ["normal_pile_rider", "tell_alarm_chirps", "reduced_motion", "hard_alarm_lockdown", "room_available_after_alarm", "jackpot_ridge", "vault_drop"]

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
	machine["riders"] = [{
		"id": "visual_chip_rider",
		"kind": "chip_stack",
		"label": "chip stack",
		"item_id": "",
		"cash_value": 4,
		"lane": 1,
		"cell": 2,
		"push": 1,
	}]
	machine["tell_rung"] = 0
	machine["last_message"] = "Pick a lane. Read both shelves."
	app.call("_refresh")
	await _settle(3)
	if not bool(app.call("enter_game", "coin_pusher")):
		_fail("Could not enter Quarter Falls in the deterministic Bar fixture.")
		_finish(1)
		return
	await _settle(4)

	await _capture_surface(
		"01_normal_pile_rider_1280x720.png",
		"normal_pile_rider",
		{"expected_tell_rung": 0, "expected_locked": false, "expected_reduce_motion": false}
	)
	machine = _machine(run_state)
	machine["tell_rung"] = 2
	machine["last_message"] = "Alarm chirps. The attendant looks over."
	app.call("_refresh")
	await _settle(3)
	await _capture_surface(
		"02_tell_alarm_chirps_1280x720.png",
		"tell_alarm_chirps",
		{"expected_tell_rung": 2, "expected_locked": false, "expected_reduce_motion": false}
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
			"03_reduced_motion_1280x720.png",
			"reduced_motion",
			{"expected_tell_rung": 2, "expected_locked": false, "expected_reduce_motion": true}
		)
		settings.reduce_motion = false
		app.call("_on_settings_applied")
		await _settle(3)

	machine = _machine(run_state)
	machine["alarm_tolerance_remaining"] = 0
	machine["lower_phase"] = 9
	app.call("_refresh")
	await _settle(2)
	if not bool(app.call("_handle_module_surface_action", "coin_pusher_force", 2, false)):
		_fail("Could not select the visible SLAM force for the alarm capture.")
	if not bool(app.call("_handle_module_surface_action", "coin_pusher_nudge", 0, true)):
		_fail("Could not resolve the deterministic hard-alarm nudge.")
	await _settle(5)
	await _capture_surface(
		"04_hard_alarm_lockdown_1280x720.png",
		"hard_alarm_lockdown",
		{"expected_tell_rung": 3, "expected_locked": true, "expected_reduce_motion": false}
	)

	app.call("back_to_environment")
	app.call("_refresh")
	await _settle(5)
	await _capture_room("05_room_available_after_alarm_1280x720.png")
	for variation_id in ["jackpot_ridge", "vault_drop"]:
		if not _install_variation_fixture(variation_id):
			continue
		await _settle(3)
		if not bool(app.call("enter_game", "coin_pusher")):
			_fail("Could not enter %s for focused visual capture." % variation_id)
			continue
		await _settle(4)
		await _capture_variation_surface("06_jackpot_ridge_1280x720.png" if variation_id == "jackpot_ridge" else "07_vault_drop_1280x720.png", variation_id)
		app.call("back_to_environment")
		await _settle(2)
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
	environment["scenario_game_modifiers"] = {"coin_pusher": {"variation_id": "quarter_falls"}}
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


func _install_variation_fixture(variation_id: String) -> bool:
	var run_state := app.get("run_state") as RunState
	var library := app.get("library") as ContentLibrary
	if run_state == null or library == null:
		_fail("Could not access runtime for %s capture." % variation_id)
		return false
	var definition := library.game("coin_pusher")
	var module: Variant = app.call("_create_game_module", definition)
	if module == null or not module is GameModule:
		_fail("Could not create Coin Pusher module for %s capture." % variation_id)
		return false
	run_state.current_environment["scenario_game_modifiers"] = {"coin_pusher": {"variation_id": variation_id}}
	var game := module as GameModule
	var machine := game.generate_environment_state(run_state, run_state.current_environment, run_state.create_rng("coin_pusher_visual:%s" % variation_id))
	if variation_id == "vault_drop":
		run_state.add_item("xray_glasses")
		var vault_state: Dictionary = machine.get("variation_state", {})
		vault_state["banked_fragments"] = 3
	var states: Dictionary = run_state.current_environment.get("game_states", {})
	states["coin_pusher"] = machine
	run_state.current_environment["game_states"] = states
	game.environment_state_generated(run_state, run_state.current_environment, machine)
	app.call("_refresh")
	return str(machine.get("variation_id", "")) == variation_id


func _capture_variation_surface(file_name: String, variation_id: String) -> void:
	var canvas := app.get("game_surface_canvas") as Control
	if canvas == null or not canvas.visible or not canvas.has_method("realtime_surface_state"):
		_fail("%s surface was unavailable." % variation_id)
		return
	canvas.set_process(false)
	canvas.set("flicker", 0.75)
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	var state: Dictionary = canvas.call("realtime_surface_state")
	var presentation := _presentation_snapshot(state)
	var features: Array = presentation.get("features", []) if typeof(presentation.get("features", [])) == TYPE_ARRAY else []
	var valid := str(state.get("coin_pusher_variation_id", "")) == variation_id and not features.is_empty()
	if variation_id == "jackpot_ridge":
		valid = valid and str(state.get("coin_pusher_variation_name", "")) == "Jackpot Ridge" and state.has("coin_pusher_cascade_remaining")
	else:
		valid = valid and str(state.get("coin_pusher_variation_name", "")) == "The Vault Drop" and (state.get("coin_pusher_vault_cells", []) as Array).size() == 9 and int(state.get("coin_pusher_vault_fragments", 0)) == 3
	if not valid:
		_fail("%s surface did not expose its unique feature state." % variation_id)
	var saved := await _save_viewport(file_name)
	captures.append({
		"id": variation_id, "file": file_name, "saved": saved, "state_valid": valid,
		"variation_id": str(state.get("coin_pusher_variation_id", "")), "feature_count": features.size(),
		"vault_cell_count": (state.get("coin_pusher_vault_cells", []) as Array).size(),
		"vault_meter": int(state.get("coin_pusher_vault_meter", 0)),
	})


func _capture_surface(file_name: String, capture_id: String, expected: Dictionary) -> void:
	var canvas := app.get("game_surface_canvas") as Control
	if canvas == null or not canvas.visible or not canvas.has_method("realtime_surface_state"):
		_fail("Quarter Falls surface is unavailable for %s." % capture_id)
		return
	# Freeze presentation-only animation at the same authored phase on every run.
	canvas.set_process(false)
	canvas.set("flicker", 0.75)
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	var state: Dictionary = canvas.call("realtime_surface_state")
	var presentation := _presentation_snapshot(state)
	var runtime: Dictionary = canvas.call("surface_runtime_status")
	var expected_reduce_motion := bool(expected.get("expected_reduce_motion", false))
	var motion_before: Dictionary = {}
	var motion_after: Dictionary = {}
	var animation_redraw_count := -1
	var motion_frozen := not expected_reduce_motion
	if expected_reduce_motion:
		canvas.call("reset_performance_counters")
		motion_before = canvas.call("debug_surface_motion_sample")
		for _frame_index in range(18):
			canvas.call("debug_advance_idle_liveness", 1.0 / 60.0)
		motion_after = canvas.call("debug_surface_motion_sample")
		runtime = canvas.call("surface_runtime_status")
		animation_redraw_count = int(runtime.get("surface_animation_redraw_count", -1))
		motion_frozen = JSON.stringify(motion_before) == JSON.stringify(motion_after) \
			and animation_redraw_count == 0 \
			and not bool(runtime.get("surface_continuous_redraw_active", true))
	var valid := str(state.get("surface_renderer", "")) == "coin_pusher" \
		and (presentation.get("bodies", []) as Array).size() >= 24 \
		and (state.get("coin_pusher_lanes", []) as Array).size() == 5 \
		and (presentation.get("riders", []) as Array).size() == 1 \
		and int(presentation.get("tell_rung", -1)) == int(expected.get("expected_tell_rung", -2)) \
		and bool(presentation.get("locked", false)) == bool(expected.get("expected_locked", false)) \
		and bool(runtime.get("reduce_motion", false)) == expected_reduce_motion \
		and motion_frozen
	if not valid:
		_fail("Quarter Falls surface state did not match %s expectations." % capture_id)
	var saved := await _save_viewport(file_name)
	captures.append({
		"id": capture_id,
		"file": file_name,
		"saved": saved,
		"state_valid": valid,
		"surface_renderer": str(state.get("surface_renderer", "")),
		"body_count": (presentation.get("bodies", []) as Array).size(),
		"lane_count": (state.get("coin_pusher_lanes", []) as Array).size(),
		"rider_count": (presentation.get("riders", []) as Array).size(),
		"tell_rung": int(presentation.get("tell_rung", -1)),
		"tell": str(state.get("coin_pusher_tell", "")),
		"locked": bool(state.get("coin_pusher_locked", false)),
		"expected_reduce_motion": expected_reduce_motion,
		"reduce_motion": bool(runtime.get("reduce_motion", false)),
		"motion_before": motion_before,
		"motion_after": motion_after,
		"motion_frozen": motion_frozen,
		"animation_redraw_count": animation_redraw_count,
		"continuous_redraw_active": bool(runtime.get("surface_continuous_redraw_active", false)),
	})


func _capture_room(file_name: String) -> void:
	var run_state := app.get("run_state") as RunState
	var canvas := app.get("environment_canvas") as Control
	var view: Dictionary = canvas.call("current_view_snapshot") if canvas != null and canvas.has_method("current_view_snapshot") else {}
	var other_game: Dictionary = {}
	for object_value in view.get("objects", []):
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = object_value
		if str(object_data.get("source_id", "")) == "bar_dice" or str(object_data.get("id", "")) == "game:bar_dice":
			other_game = object_data
			break
	var machine := _machine(run_state)
	var valid := canvas != null and canvas.visible \
		and bool(machine.get("locked_down", false)) \
		and not other_game.is_empty() \
		and not bool(other_game.get("disabled", false))
	if not valid:
		_fail("The room-available capture did not preserve the locked pusher and enabled Bar Dice table.")
	var saved := await _save_viewport(file_name)
	captures.append({
		"id": "room_available_after_alarm",
		"file": file_name,
		"saved": saved,
		"state_valid": valid,
		"pusher_locked": bool(machine.get("locked_down", false)),
		"other_game_id": str(other_game.get("source_id", "")),
		"other_game_disabled": bool(other_game.get("disabled", true)),
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
		if capture_id == "reduced_motion":
			reduced_motion_proof_passed = bool(capture.get("reduce_motion", false)) \
				and bool(capture.get("motion_frozen", false)) \
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
	var value: Variant = surface_state.get("coin_pusher_snapshot", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _settle(frame_count: int) -> void:
	for _index in range(frame_count):
		await process_frame


func _fail(message: String) -> void:
	failed = true
	push_error(message)


func _finish(exit_code: int) -> void:
	print("COIN_PUSHER_VISUAL_CAPTURE_%s captures=%d out=%s" % ["PASS" if exit_code == 0 else "FAIL", captures.size(), ProjectSettings.globalize_path(out_dir)])
	quit(exit_code)
