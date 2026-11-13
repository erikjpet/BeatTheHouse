extends SceneTree

const PackScript := preload("res://scripts/ui/environment_art_pack.gd")
const CanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const ROOMS := ["corner_store", "back_alley", "motel", "motel_room", "apartment", "house", "pawn_shop", "bar", "jazz_club", "kitty_cat_lounge", "delta_queen", "beach", "gas_station_casino", "small_underground_casino", "punchline_club", "punchline_back_room", "grand_casino", "grand_casino_high_limit", "grand_casino_back_room", "grand_casino_cage"]
var baseline_source := ""
var out_dir := ""
var viewport: SubViewport


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline-source="):
			baseline_source = argument.trim_prefix("--baseline-source=")
		elif argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	call_deferred("_run")


func _run() -> void:
	if baseline_source.is_empty() or out_dir.is_empty() or not FileAccess.file_exists(baseline_source):
		push_error("Pixel comparison requires explicit original-source evidence and an admitted output directory.")
		quit(1)
		return
	var source := FileAccess.get_file_as_string(baseline_source)
	if source.count("class_name PixelSceneCanvas") != 1:
		push_error("Baseline source identity is invalid.")
		quit(1)
		return
	var baseline := GDScript.new()
	baseline.source_code = source.replace("class_name PixelSceneCanvas", "class_name EnvartBaselinePixelCanvas")
	if baseline.reload() != OK:
		push_error("Original canvas source did not compile.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	viewport = SubViewport.new()
	viewport.size = Vector2i(900, 430)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var results: Array = []
	var failed := false
	for room in ROOMS:
		var archetype: String = room
		var context := {}
		var layer := ""
		if room in ["punchline_club", "punchline_back_room"]:
			archetype = "small_underground_casino"
			context["art_key"] = room
			layer = "club" if room == "punchline_club" else "back_room"
		var snapshot := {"archetype_id": archetype, "visual_context": context, "current_layer_id": layer, "interactable_objects": [], "reduce_motion": true}
		PackScript.invalidate()
		# Loader rejection and absence both yield null; exercise that exact draw
		# boundary with a stationary Reduce Motion fixture. Live scheduling has a
		# separate unchanged no-pointer gate and a real packed-room check.
		PackScript._cache[room] = null
		var before: Image = await _capture(baseline, snapshot)
		var after: Image = await _capture(CanvasScript, snapshot)
		var same := before.get_data() == after.get_data()
		failed = failed or not same
		before.save_png(out_dir.path_join(room + "_before.png"))
		after.save_png(out_dir.path_join(room + "_after.png"))
		results.append({"room": room, "pixels_identical": same, "size": [900, 430]})
	PackScript.invalidate()
	var file := FileAccess.open(out_dir.path_join("pixel_comparison.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"baseline_commit": "e5152c34bfe146600214fb206ec80a5e3e8a27cb", "controlled_motion": "Reduce Motion, no objects", "results": results}, "\t"))
	file.close()
	print("ENVART_FALLBACK_PIXELS " + JSON.stringify({"rooms": results.size(), "all_identical": not failed}))
	viewport.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _capture(script: Script, snapshot: Dictionary) -> Image:
	var canvas: Control = script.new()
	canvas.size = Vector2(900, 430)
	viewport.add_child(canvas)
	canvas.call("render_environment_snapshot", snapshot.duplicate(true))
	for index in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	canvas.free()
	return image
