extends "res://tools/environment_art_baseline_capture.gd"

# Same real Base / No Scenario generation as Phase0, plus the required 2x
# resolution and unmodified camera-easing path for the proof room.
func _capture_base_practice(id: String, layer: String) -> void:
	await super._capture_base_practice(id, layer)
	if id != "gas_station_casino":
		return
	var canvas: Control = app.get("environment_canvas")
	root.size = Vector2i(1920, 1080)
	await _settle(8)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("gas_station_casino_1920.png"))
	var layout: Dictionary = _canvas_object_layout()
	var objects: Array = layout.get("objects", [])
	var camera_samples: Array = []
	if not objects.is_empty():
		canvas.call("set_selected_object", str(objects[0].get("id", "")), false)
		for index in range(3):
			await _settle(5)
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("gas_station_camera_%d.png" % index))
			camera_samples.append({"zoom": canvas.get("camera_zoom"), "offset": canvas.get("camera_offset"), "texture_filter": canvas.texture_filter})
	canvas.call("set_selected_object", "", true)
	root.size = Vector2i(1280, 720)
	await _settle(4)
	var file := FileAccess.open(out_dir.path_join("camera_samples.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(camera_samples, "\t"))
	file.close()


func _capture_gas_menu() -> void:
	app.call("_reroll_main_menu_background")
	var canvas: Control = app.get("main_menu_background")
	for frame in range(180):
		await process_frame
		if canvas.get("environment_art_pack") != null:
			break
	await _settle(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("gas_station_casino_menu_after.png"))
	var before: Dictionary = canvas.call("current_view_snapshot")
	await create_timer(0.45).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("gas_station_casino_menu_idle.png"))
	var file := FileAccess.open(out_dir.path_join("menu_liveness.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"before": before, "after": canvas.call("current_view_snapshot"), "pack_active": canvas.get("environment_art_pack") != null}, "\t"))
	file.close()
