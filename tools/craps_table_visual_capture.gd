extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const OUTPUT_DIR := "res://.tmp/craps_table_visual_qa"
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
	app.set("autosave_slot_id", "craps_table_visual_capture")
	root.add_child(app)
	await _settle(8)
	app.call("start_game_test_session", "craps")
	await _settle(8)
	var run_state := app.get("run_state") as RunState
	if run_state == null:
		_fail("Craps capture could not access RunState.")
		return
	run_state.simulation_msec = 40000
	_configure_table(run_state, 37000, [3, 5], 8, "craps:capture:idle")
	app.set("game_surface_ui_state", {"selected_chip": 5, "craps_pending_bets": {"field": 5}, "surface_time_msec": 40000})
	app.call("_refresh")
	await _settle(5)
	var canvas := app.get("game_surface_canvas") as Control
	if canvas == null or not canvas.visible:
		_fail("Craps capture surface is not visible.")
		return
	var full_snapshot: Dictionary = canvas.call("current_view_snapshot")
	var full_state: Dictionary = full_snapshot.get("state", {})
	var target_ids := _target_ids(full_state.get("bet_targets", []))
	for expected_target in ["field", "come", "dont_come", "pass_line", "dont_pass", "place_4", "place_5", "place_6", "place_8", "place_9", "place_10", "pass_odds", "come_odds_5"]:
		if not target_ids.has(expected_target):
			_fail("Craps capture is missing bet target %s." % expected_target)
			return
	if not await _capture("01_full_bet_surface.png"):
		return

	var idle_before: Dictionary = canvas.call("debug_surface_motion_sample")
	if not await _capture("02_idle_liveness_before.png"):
		return
	canvas.call("debug_advance_idle_liveness", 0.5)
	await _settle(2)
	var idle_after: Dictionary = canvas.call("debug_surface_motion_sample")
	if JSON.stringify(idle_before) == JSON.stringify(idle_after):
		_fail("Craps capture idle rail marker remained frozen.")
		return
	if not await _capture("03_idle_liveness_after.png"):
		return

	_configure_table(run_state, 40000, [5, 2], 7, "craps:capture:dice")
	app.call("_refresh")
	await _settle(3)
	var dice_state: Dictionary = (canvas.call("current_view_snapshot") as Dictionary).get("state", {})
	if str(dice_state.get("phase", "")) != "rolling":
		_fail("Craps capture did not enter deterministic dice presentation.")
		return
	if not await _capture("04_dice_presentation.png"):
		return

	_configure_table(run_state, 37000, [3, 5], 8, "craps:capture:reduced")
	var settings: Variant = app.get("user_settings")
	settings.reduce_motion = true
	app.call("_apply_accessibility_settings")
	app.call("_refresh")
	await _settle(3)
	var reduced_before: Dictionary = canvas.call("debug_surface_motion_sample")
	canvas.call("debug_advance_idle_liveness", 0.5)
	var reduced_after: Dictionary = canvas.call("debug_surface_motion_sample")
	if JSON.stringify(reduced_before) != JSON.stringify(reduced_after):
		_fail("Craps capture reduced-motion state still advanced.")
		return
	if not await _capture("05_reduced_motion_surface.png"):
		return
	evidence = {
		"viewport": {"width": CAPTURE_SIZE.x, "height": CAPTURE_SIZE.y},
		"target_ids": target_ids,
		"working_bet_rows": full_state.get("working_bet_rows", []),
		"roll_history": full_state.get("roll_history", []),
		"idle_motion_before": idle_before,
		"idle_motion_after": idle_after,
		"reduced_motion_before": reduced_before,
		"reduced_motion_after": reduced_after,
	}
	_write_manifest()
	print("CRAPS_TABLE_VISUAL_CAPTURE_PASS files=%d dir=%s" % [saved_files.size(), ProjectSettings.globalize_path(OUTPUT_DIR)])
	quit(0)


func _configure_table(run_state: RunState, resolved_at_msec: int, dice: Array, total: int, animation_id: String) -> void:
	var environment := run_state.current_environment
	var states: Dictionary = environment.get("game_states", {})
	var table: Dictionary = states.get("craps", {})
	table["point"] = 8
	table["working_bets"] = {
		"pass_line": 25,
		"dont_pass": 25,
		"pass_odds": 50,
		"come": {"5": 10},
		"dont_come": {"9": 10},
		"come_odds": {"5": 15},
		"place": {"6": 12, "10": 10},
	}
	var history: Array = [
		_roll([2, 4], 6, 5, 5, "craps:capture:1", 31000),
		_roll([3, 5], 8, 5, 8, "craps:capture:2", 33000),
		_roll([4, 3], 7, 8, 0, "craps:capture:3", 35000),
		_roll(dice, total, 8, 8 if total != 7 else 0, animation_id, resolved_at_msec),
	]
	table["roll_count"] = history.size()
	table["roll_history"] = history
	table["last_roll"] = history[-1].duplicate(true)
	table["last_result"] = {"message": "Deterministic Craps visual capture.", "bankroll_delta": 0, "bet_results": []}
	table["hot_shooter_streak"] = 2
	table["table_energy"] = 24
	states["craps"] = table
	environment["game_states"] = states
	run_state.current_environment = environment


func _roll(dice: Array, total: int, point_before: int, point_after: int, animation_id: String, resolved_at_msec: int) -> Dictionary:
	return {
		"dice": dice.duplicate(),
		"total": total,
		"initial_total": total,
		"setting_bias_applied": false,
		"point_before": point_before,
		"point_after": point_after,
		"animation_id": animation_id,
		"resolved_at_msec": resolved_at_msec,
	}


func _target_ids(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
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
		_fail("Could not save Craps capture %s." % file_name)
		return false
	saved_files.append(file_name)
	return true


func _write_manifest() -> void:
	var manifest := {
		"tool": "craps_table_visual_capture",
		"passed": true,
		"capture_size": {"width": CAPTURE_SIZE.x, "height": CAPTURE_SIZE.y},
		"files": saved_files,
		"evidence": evidence,
	}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		_fail("Could not write Craps visual capture manifest.")
		return
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
