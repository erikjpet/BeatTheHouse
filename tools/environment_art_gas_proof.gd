extends "res://tools/environment_art_baseline_capture.gd"
const PackScript := preload("res://scripts/ui/environment_art_pack.gd")
const CanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
var baseline_source := ""
var findings: Array[String] = []
var checks := 0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline-source="):
			baseline_source = argument.trim_prefix("--baseline-source=")


func _run() -> void:
	if baseline_source.is_empty() or not FileAccess.file_exists(baseline_source):
		push_error("Gas proof requires the exact Phase0 canvas source.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.set("script_prewarm_stopping", true)
	root.add_child(app)
	await _settle(8)
	await _capture_gas_menu()
	app.call("open_environment_test_menu")
	app.call("_environment_test_select_id", app.get("environment_test_archetype_option"), "gas_station_casino")
	app.call("_refresh_environment_test_identity_options")
	var selections := ["__none", "gas_station_trucker_convoy", "gas_station_tour_bus_stop", "gas_station_graveyard_shift", "gas_station_road_crew_payday", "gas_station_storm_shelter"]
	var original := GDScript.new()
	original.source_code = FileAccess.get_file_as_string(baseline_source).replace("class_name PixelSceneCanvas", "class_name EnvartGasOriginalCanvas")
	if original.reload() != OK:
		quit(1)
		return
	for scenario in selections:
		app.call("_environment_test_select_id", app.get("environment_test_scenario_option"), scenario)
		app.get("environment_test_seed_input").text = SEED_TEXT
		var generated: Dictionary = app.call("start_environment_test_session")
		_check(bool(generated.get("ok", false)), "Production practice generation: " + scenario)
		if not bool(generated.get("ok", false)):
			continue
		await _settle(8)
		var canvas: Control = app.get("environment_canvas")
		var snapshot: Dictionary = canvas.get("foundation_snapshot")
		_check(str(snapshot.get("scenario_id", "")) == ("" if scenario == "__none" else scenario), "Exact scenario selected: " + scenario)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join(scenario + "_play.png"))
		if scenario == "__none":
			await _record_idle_cost()
		var pair := await _compare_pair(original, snapshot, scenario)
		report[scenario] = {"snapshot": snapshot, "comparison": pair}
		# Normal Reduce Motion setting, never process disabling, gives an exact
		# static geometry and image comparison as well as the live paired views.
		var reduced := snapshot.duplicate(true)
		reduced["reduce_motion"] = true
		var still_pair := await _compare_pair(original, reduced, scenario + "_reduced")
		report[scenario]["reduce_motion_comparison"] = still_pair
	var run_state: Variant = app.get("run_state")
	run_state.begin_closing_time(run_state.current_environment, 1380)
	app.call("_refresh")
	await _settle(8)
	var closing_canvas: Control = app.get("environment_canvas")
	_check(run_state.closing_time_active() and closing_canvas.get("environment_art_pack") != null, "Closing-time grace state retains the active room art.")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("closing_time.png"))
	report["closing_time"] = {"status": run_state.closing_time_status(), "note": "Gas has no natural closing hours; public begin_closing_time API installs the production grace presentation for this focused fixture."}
	closing_canvas.call("set_developer_slot_placement_mode", true)
	var began: Dictionary = closing_canvas.call("current_view_snapshot")
	await RenderingServer.frame_post_draw
	var first := root.get_texture().get_image()
	await create_timer(0.45).timeout
	await RenderingServer.frame_post_draw
	var second := root.get_texture().get_image()
	var ended: Dictionary = closing_canvas.call("current_view_snapshot")
	_check(float(ended["scene_animation_time"]) > float(began["scene_animation_time"]) and int(ended["scene_idle_animation_redraw_count"]) > int(began["scene_idle_animation_redraw_count"]), "Packed clock and redraws advance autonomously while placement is open.")
	_check(first.get_data() != second.get_data(), "Packed play visibly changes with no pointer input.")
	first.save_png(out_dir.path_join("placement_idle_a.png"))
	second.save_png(out_dir.path_join("placement_idle_b.png"))
	report["placement_liveness"] = {"before": began, "after": ended}
	var file := FileAccess.open(out_dir.path_join("gas_proof.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "findings": findings, "views": report}, "\t"))
	file.close()
	print("ENVART_GAS_PROOF " + JSON.stringify({"checks": checks, "findings": findings, "scenario_count": 5}))
	app.queue_free()
	await process_frame
	quit(0 if findings.is_empty() else 1)


func _compare_pair(original: GDScript, snapshot: Dictionary, name_value: String) -> Dictionary:
	var before_view := SubViewport.new()
	var after_view := SubViewport.new()
	before_view.size = Vector2i(900, 430)
	after_view.size = before_view.size
	before_view.disable_3d = true
	after_view.disable_3d = true
	before_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	after_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(before_view)
	root.add_child(after_view)
	var before: Control = original.new()
	var after: Control = CanvasScript.new()
	before.size = Vector2(900, 430)
	after.size = before.size
	before_view.add_child(before)
	after_view.add_child(after)
	before.call("render_environment_snapshot", snapshot)
	after.call("render_environment_snapshot", snapshot)
	await _settle(8)
	await RenderingServer.frame_post_draw
	var before_layout: Dictionary = before.call("current_view_snapshot")
	var after_layout: Dictionary = after.call("current_view_snapshot")
	var equal_layout: bool = before_layout["object_layout"] == after_layout["object_layout"]
	_check(equal_layout, "Every object, label, footprint, hit rectangle and z order matches the original at the same live clock: " + name_value)
	var before_image := before_view.get_texture().get_image()
	var after_image := after_view.get_texture().get_image()
	before_image.save_png(out_dir.path_join(name_value + "_original.png"))
	after_image.save_png(out_dir.path_join(name_value + "_pack.png"))
	var stable := true
	if bool(snapshot.get("reduce_motion", false)):
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		stable = after_image.get_data() == after_view.get_texture().get_image().get_data()
		_check(stable, "Reduce Motion stays pixel-identical over time: " + name_value)
	var result := {"layout_equal": equal_layout, "before_layout": before_layout["object_layout"], "after_layout": after_layout["object_layout"], "reduce_motion_stable": stable, "pack_active": after.get("environment_art_pack") != null}
	_check(bool(result["pack_active"]), "The proof actually uses the pack: " + name_value)
	before_view.free()
	after_view.free()
	return result


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		findings.append(message)
		push_error(message)
