extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const OUTPUT_DIR := "res://.tmp/street_craps_visual_qa"
const MANIFEST_PATH := OUTPUT_DIR + "/manifest.json"
const CAPTURE_SIZE := Vector2i(1280, 720)

var app: Control
var saved_files: Array[String] = []
var evidence: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = CAPTURE_SIZE
	RenderingServer.set_default_clear_color(Color("#08070d"))
	app = MainScene.instantiate()
	app.set("show_game_library_launcher", true)
	app.set("autosave_slot_id", "street_craps_visual_capture")
	root.add_child(app)
	await _settle(8)
	app.call("start_game_test_session", "craps")
	await _settle(8)
	var run_state := app.get("run_state") as RunState
	var game := app.get("current_game") as GameModule
	if run_state == null or game == null:
		_fail("Street Craps capture could not access the live game session.")
		return
	var environment := _street_environment()
	var table := game.generate_environment_state(run_state, environment, run_state.create_rng("street_capture_table"))
	table["point"] = 6
	table["working_bets"] = {"pass_line": 5, "dont_pass": 0, "pass_odds": 0, "come": {}, "dont_come": {}, "come_odds": {}, "place": {}}
	table["roll_history"] = [
		_roll([2, 4], 6, 0, 6, "street:capture:1", 34000),
		_roll([2, 3], 5, 6, 6, "street:capture:2", 36000),
	]
	table["last_roll"] = (table["roll_history"] as Array)[-1]
	environment["game_states"] = {"craps": table}
	run_state.current_environment = environment
	run_state.simulation_msec = 40000
	app.set("game_surface_ui_state", {"selected_chip": 2, "surface_time_msec": 40000})
	app.call("_refresh")
	await _settle(5)
	var canvas := app.get("game_surface_canvas") as Control
	if canvas == null or not canvas.visible:
		_fail("Street Craps capture surface is not visible.")
		return
	var live_snapshot: Dictionary = canvas.call("current_view_snapshot")
	var live_state: Dictionary = live_snapshot.get("state", {})
	var target_ids := _target_ids(live_state.get("bet_targets", []))
	if target_ids != ["pass_line", "dont_pass"] or str(live_state.get("surface_cast", "")) != "circle_of_players":
		_fail("Street Craps capture did not render the two-line circle surface.")
		return
	if not await _capture("01_street_circle.png"):
		return

	var states: Dictionary = run_state.current_environment.get("game_states", {})
	table = states.get("craps", {})
	var dice_start := int(app.call("_current_game_surface_ui_state").get("surface_time_msec", 1))
	table["last_roll"] = _roll([4, 3], 7, 6, 0, "street:capture:dice", dice_start)
	table["roll_history"] = [table["last_roll"]]
	states["craps"] = table
	run_state.current_environment["game_states"] = states
	app.call("_refresh")
	await _settle(3)
	if str((canvas.call("current_view_snapshot") as Dictionary).get("state", {}).get("phase", "")) != "rolling":
		_fail("Street Craps capture did not expose the shared live dice presentation.")
		return
	if not await _capture("02_street_dice.png"):
		return

	states = run_state.current_environment.get("game_states", {})
	table = states.get("craps", {})
	table["point"] = 0
	table["working_bets"] = {"pass_line": 0, "dont_pass": 0, "pass_odds": 0, "come": {}, "dont_come": {}, "come_odds": {}, "place": {}}
	table["street_dispersed"] = true
	table["street_disperse_reason"] = "sweep_adjacent"
	states["craps"] = table
	run_state.current_environment["game_states"] = states
	app.set("game_surface_ui_state", {"selected_chip": 2, "surface_time_msec": dice_start + 2000})
	app.call("_refresh")
	await _settle(3)
	var dispersed_state: Dictionary = (canvas.call("current_view_snapshot") as Dictionary).get("state", {})
	if str(dispersed_state.get("phase", "")) != "dispersed" or bool(dispersed_state.get("can_roll", true)):
		_fail("Street Craps dispersed capture still allowed the circle to play.")
		return
	if not await _capture("03_street_dispersed.png"):
		return
	evidence = {
		"viewport": {"width": CAPTURE_SIZE.x, "height": CAPTURE_SIZE.y},
		"target_ids": target_ids,
		"surface_cast": live_state.get("surface_cast", ""),
		"currency": live_state.get("currency", ""),
		"table_bounds": [live_state.get("table_minimum", 0), live_state.get("table_maximum", 0)],
		"disperse_reason": dispersed_state.get("street_disperse_reason", ""),
	}
	_write_manifest()
	print("STREET_CRAPS_VISUAL_CAPTURE_PASS files=%d dir=%s" % [saved_files.size(), ProjectSettings.globalize_path(OUTPUT_DIR)])
	quit(0)


func _street_environment() -> Dictionary:
	return {
		"id": "back_alley_street_craps_capture",
		"archetype_id": "back_alley",
		"world_node_id": "back_alley",
		"kind": "shop",
		"game_ids": ["craps"],
		"economic_profile": {"stake_floor": 2, "stake_ceiling": 20},
		"scenario_id": "back_alley_street_craps",
		"scenario_game_modifiers": {"game_hook": "street_craps", "table_tone": "street"},
		"scenario_hook_flags": {"craps_onramp": true},
		"music_profile": {"volume": 0.24, "ambience": 0.72, "bpm": 82.0},
		"game_states": {},
	}


func _roll(dice: Array, total: int, point_before: int, point_after: int, animation_id: String, resolved_at_msec: int) -> Dictionary:
	return {"dice": dice.duplicate(), "total": total, "initial_total": total, "setting_bias_applied": false, "point_before": point_before, "point_after": point_after, "animation_id": animation_id, "resolved_at_msec": resolved_at_msec}


func _target_ids(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for target_value in value as Array:
			if typeof(target_value) == TYPE_DICTIONARY:
				result.append(str((target_value as Dictionary).get("id", "")))
	return result


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame


func _capture(file_name: String) -> bool:
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image.get_size() != CAPTURE_SIZE:
		image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_NEAREST)
	var error := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	if error != OK:
		_fail("Could not save Street Craps capture %s." % file_name)
		return false
	saved_files.append(file_name)
	return true


func _write_manifest() -> void:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		_fail("Could not write Street Craps visual capture manifest.")
		return
	file.store_string(JSON.stringify({"tool": "street_craps_visual_capture", "passed": true, "capture_size": {"width": CAPTURE_SIZE.x, "height": CAPTURE_SIZE.y}, "files": saved_files, "evidence": evidence}, "\t"))
	file.close()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
