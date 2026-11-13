extends "res://tools/environment_layout_screenshots.gd"

# Reuses the production-order layout survey, adding all layered room identities.
# Run windowed with -- --out=<admitted evidence directory>.
func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(out_dir)
	app = MainScene.instantiate()
	app.set("script_prewarm_stopping", true)
	root.add_child(app)
	await _settle(10)
	await _capture_gas_menu()
	app.call("open_environment_test_menu")
	await _settle(4)
	var library: Variant = app.get("library")
	if library == null:
		push_error("Environment art baseline could not start a run.")
		quit(1)
		return
	for value in library.environment_archetypes:
		var archetype: Dictionary = value
		var id := str(archetype.get("id", ""))
		var layers: Dictionary = archetype.get("layers", {})
		if layers.is_empty():
			await _capture_base_practice(id, "")
		else:
			for layer_value in layers.keys():
				await _capture_base_practice(id, str(layer_value))
	var file := FileAccess.open(out_dir.path_join("layout_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("ENVART_BASELINE_DONE %d room views -> %s" % [report.size(), out_dir])
	app.queue_free()
	await process_frame
	quit(0)


func _capture_base_practice(id: String, layer: String) -> void:
	var archetype_option: OptionButton = app.get("environment_test_archetype_option")
	app.call("_environment_test_select_id", archetype_option, id)
	app.call("_refresh_environment_test_identity_options")
	app.call("_environment_test_select_id", app.get("environment_test_scenario_option"), "__none")
	if not layer.is_empty():
		app.call("_environment_test_select_id", app.get("environment_test_layer_option"), layer)
	var seed_input: LineEdit = app.get("environment_test_seed_input")
	seed_input.text = SEED_TEXT
	var result: Dictionary = app.call("start_environment_test_session")
	if not bool(result.get("ok", false)):
		push_error("Baseline practice generation failed: %s" % result)
		quit(1)
		return
	await _settle(8)
	var canvas: Control = app.get("environment_canvas")
	var art_id := str(canvas.get("environment_id"))
	var snapshot: Dictionary = canvas.get("foundation_snapshot")
	if not str(snapshot.get("scenario_id", "")).is_empty():
		push_error("Baseline unexpectedly has an active scenario: %s" % art_id)
		quit(1)
		return
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(art_id + ".png"))
	report[art_id] = {
		"archetype_id": id, "layer_id": layer, "scenario_id": "",
		"canvas_object_layout": _canvas_object_layout(),
		"snapshot": snapshot,
	}
	if art_id == "gas_station_casino":
		await _record_idle_cost()


func _capture_gas_menu() -> void:
	var library: Variant = app.get("library")
	for value in library.environment_archetypes:
		var archetype: Dictionary = value
		if str(archetype.get("id", "")) != "gas_station_casino":
			continue
		var snapshot := archetype.duplicate(true)
		snapshot["archetype_id"] = "gas_station_casino"
		snapshot["reduce_motion"] = false
		var background: Control = app.get("main_menu_background")
		var context: Dictionary = snapshot.get("visual_context", {})
		background.set("background_texture", load(str(context.get("asset_path", ""))))
		background.set("use_external_background", true)
		background.call("render_environment_snapshot", snapshot)
		await _settle(10)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("gas_station_casino_menu_before.png"))
		return


func _record_idle_cost() -> void:
	var canvas: Control = app.get("environment_canvas")
	canvas.call("reset_performance_counters")
	var samples: Array[float] = []
	var memory_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	for index in range(180):
		await process_frame
		samples.append(canvas.get_process_delta_time() * 1000.0)
	var overlay := preload("res://scripts/ui/perf_telemetry_overlay.gd").new()
	# The existing overlay explicitly reports a whole-frame upper bound for rooms.
	var cost: Dictionary = overlay.call("_surface_draw_stats", {}, samples)
	overlay.free()
	var result := {
		"environment_id": "gas_station_casino",
		"platform": OS.get_name(),
		"idle_draw_cost": cost,
		"memory_static_before_bytes": memory_before,
		"memory_static_after_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"texture_memory_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"liveness": canvas.call("performance_live_status"),
		"viewport": [root.size.x, root.size.y],
	}
	var file := FileAccess.open(out_dir.path_join("gas_station_idle_cost.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
