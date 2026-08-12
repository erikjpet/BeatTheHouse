extends SceneTree

# Captures the Test 11 noon and restored Test 04 midnight backgrounds inside
# the real game UI for every authored environment archetype.
#
# Run windowed:
#   .tools/godot-4.6-stable/Godot_v4.6-stable_win64_console.exe \
#     --path . --script res://tools/test11_environment_time_screenshots.gd \
#     -- --out=D:/absolute/output/directory

const MainScene := preload("res://scenes/main.tscn")
const SEED_TEXT := "TEST11-ENVIRONMENT-TIME-SCREENSHOTS"
const ART_ROOT := "res://review_artifacts/art_rework_test_11"

var app: Control
var out_dir := "user://test11_environment_time_screenshots"
var report := {}


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.make_dir_recursive_absolute("%s/noon" % out_dir)
	DirAccess.make_dir_recursive_absolute("%s/midnight" % out_dir)
	app = MainScene.instantiate()
	root.add_child(app)
	await _settle(5)
	app.call("start_foundation_run", SEED_TEXT, {})
	await _settle(8)
	app.set("continuous_environment_clock_enabled", false)
	var library: Variant = app.get("library")
	var run_state: Variant = app.get("run_state")
	if library == null or run_state == null:
		push_error("Test 11 capture could not start the game run.")
		quit(1)
		return
	var archetypes: Array = library.environment_archetypes
	for phase in ["noon", "midnight"]:
		var clock_minutes := 720 if phase == "noon" else 0
		for archetype_value in archetypes:
			if typeof(archetype_value) != TYPE_DICTIONARY:
				continue
			var archetype: Dictionary = archetype_value
			var archetype_id := str(archetype.get("id", ""))
			if archetype_id.is_empty():
				continue
			await _capture_environment(archetype, archetype_id, phase, clock_minutes, run_state, library)
	var report_file := FileAccess.open("%s/capture_report.json" % out_dir, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "\t"))
		report_file.close()
	print("TEST11_TIME_SCREENSHOTS_DONE %d captures -> %s" % [report.size(), out_dir])
	quit(0)


func _capture_environment(
	archetype: Dictionary,
	archetype_id: String,
	phase: String,
	clock_minutes: int,
	run_state: Variant,
	library: Variant
) -> void:
	run_state.game_clock_minutes = clock_minutes
	var rng: Variant = run_state.create_rng("test11_%s_%s" % [phase, archetype_id])
	var environment: Variant = EnvironmentInstance.from_archetype(
		archetype,
		1,
		rng,
		library,
		run_state.challenge_config
	)
	var data: Dictionary = environment.to_dict()
	data["world_node_id"] = archetype_id
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data)
	if str(archetype.get("kind", "")) == "home":
		var profile: Dictionary = archetype.get("home_profile", {}) if typeof(archetype.get("home_profile", {})) == TYPE_DICTIONARY else {}
		run_state.initialize_home_from_profile(archetype, archetype_id, profile)
		data["home_profile"] = profile.duplicate(true)
		data["home_containers"] = _survey_home_containers(profile)
		data["home_container_index"] = int((data["home_containers"] as Array).size())
		data["home_lost"] = false
	run_state.save_rng(rng)
	run_state.set_environment(data)
	app.call("_clear_selected_game_action")
	app.call("_refresh")
	await _settle(6)
	var canvas: Variant = app.get("environment_canvas")
	if canvas == null:
		push_error("Environment canvas missing for %s %s." % [archetype_id, phase])
		return
	var texture := _load_review_texture("%s/%s/%s_%s.png" % [ART_ROOT, phase, archetype_id, phase])
	if texture == null:
		push_error("Review background missing for %s %s." % [archetype_id, phase])
		return
	canvas.set("background_texture", texture)
	canvas.set("use_external_background", true)
	canvas.call("set_selected_object", "")
	canvas.queue_redraw()
	await _settle(5)
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var output_path := "%s/%s/%s_%s.png" % [out_dir, phase, archetype_id, phase]
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Failed to save %s: %s" % [output_path, error_string(error)])
		return
	var report_key := "%s_%s" % [archetype_id, phase]
	report[report_key] = {
		"environment_id": archetype_id,
		"display_name": str(data.get("display_name", data.get("name", archetype_id))),
		"phase": phase,
		"clock_minutes": clock_minutes,
		"clock_text": run_state.clock_display_text(),
		"background_path": "%s/%s/%s_%s.png" % [ART_ROOT, phase, archetype_id, phase],
		"screenshot_path": output_path,
		"viewport_size": {"x": image.get_width(), "y": image.get_height()},
		"object_layout": _canvas_object_layout(canvas),
	}


func _load_review_texture(path: String) -> Texture2D:
	var image := Image.new()
	var absolute_path := ProjectSettings.globalize_path(path)
	var error := image.load(absolute_path)
	if error != OK:
		push_error("Could not load review image %s: %s" % [absolute_path, error_string(error)])
		return null
	return ImageTexture.create_from_image(image)


func _canvas_object_layout(canvas: Variant) -> Dictionary:
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	return snapshot.get("object_layout", {})


func _survey_home_containers(profile: Dictionary) -> Array:
	var containers: Array = []
	var index := 0
	var values: Array = profile.get("starting_containers", []) if typeof(profile.get("starting_containers", [])) == TYPE_ARRAY else []
	for value in values:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		var item_id := str(entry.get("item_id", entry.get("id", ""))).strip_edges()
		if item_id.is_empty():
			continue
		index += 1
		containers.append({
			"id": "%s_%02d" % [item_id, index],
			"item_id": item_id,
			"display_name": item_id.replace("_", " ").capitalize(),
			"capacity": maxi(0, int(entry.get("capacity", 0))),
			"items": [],
		})
	return containers


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame
