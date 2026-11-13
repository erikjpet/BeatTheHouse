extends SceneTree
const PackScript := preload("res://scripts/ui/environment_art_pack.gd")
const CanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
var out_dir := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	call_deferred("_run")


func _run() -> void:
	if out_dir.is_empty():
		quit(1)
		return
	root.size = Vector2i(900, 430)
	PackScript.invalidate()
	var canvas: Control = CanvasScript.new()
	canvas.size = Vector2(900, 430)
	root.add_child(canvas)
	var memory_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var texture_before := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	var began := Time.get_ticks_usec()
	canvas.call("render_environment_snapshot", {"archetype_id": "gas_station_casino", "interactable_objects": [], "reduce_motion": false})
	var publication_usec := Time.get_ticks_usec() - began
	var first_pack_frame := -1
	var fallback_frames := 0
	var samples: Array = []
	for frame in range(90):
		await process_frame
		await RenderingServer.frame_post_draw
		var ready := canvas.get("environment_art_pack") != null
		if ready and first_pack_frame < 0:
			first_pack_frame = frame
		if not ready:
			fallback_frames += 1
		if frame == 0 or (ready and frame == first_pack_frame):
			root.get_texture().get_image().save_png(out_dir.path_join("entry_frame_%d.png" % frame))
		samples.append({"frame": frame, "pack_ready": ready, "clock": canvas.get("flicker"), "texture_bytes": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)})
	var result := {"snapshot_publication_usec": publication_usec, "first_pack_frame": first_pack_frame, "code_fallback_frames": fallback_frames, "memory_before": memory_before, "memory_after": Performance.get_monitor(Performance.MEMORY_STATIC), "texture_before": texture_before, "texture_after": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED), "samples": samples, "no_input_clock_advanced": float(samples[-1]["clock"]) > float(samples[0]["clock"])}
	var file := FileAccess.open(out_dir.path_join("load.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("ENVART_LOAD_PROBE " + JSON.stringify({"snapshot_publication_usec": publication_usec, "first_pack_frame": first_pack_frame, "fallback_frames": fallback_frames, "clock_advanced": result["no_input_clock_advanced"]}))
	canvas.free()
	PackScript.invalidate()
	quit(0 if first_pack_frame >= 0 and result["no_input_clock_advanced"] else 1)
