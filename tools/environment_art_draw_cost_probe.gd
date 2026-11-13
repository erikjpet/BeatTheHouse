extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const ProfileScript := preload("res://tools/environment_art_draw_profile.gd")
const PackScript := preload("res://scripts/ui/environment_art_pack.gd")
var original_source := ""
var out_dir := ""
var app: Control


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline-source="):
			original_source = argument.trim_prefix("--baseline-source=")
		elif argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	call_deferred("_run")


func _run() -> void:
	if original_source.is_empty() or out_dir.is_empty() or not FileAccess.file_exists(original_source):
		push_error("Draw cost probe requires explicit original-source and output paths.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	app = MainScene.instantiate()
	app.set("script_prewarm_stopping", true)
	root.add_child(app)
	for index in range(8):
		await process_frame
	app.call("open_environment_test_menu")
	app.call("_environment_test_select_id", app.get("environment_test_archetype_option"), "gas_station_casino")
	app.call("_refresh_environment_test_identity_options")
	app.call("_environment_test_select_id", app.get("environment_test_scenario_option"), "__none")
	var generated: Dictionary = app.call("start_environment_test_session")
	if not bool(generated.get("ok", false)):
		push_error("Draw cost probe could not create the real Gas Station room.")
		quit(1)
		return
	var live_canvas: Control = app.get("environment_canvas")
	var snapshot: Dictionary = live_canvas.get("foundation_snapshot")
	snapshot = snapshot.duplicate(true)
	app.visible = false
	var original := FileAccess.get_file_as_string(original_source)
	var before_first := await _measure(original, "EnvartOriginalProfileCanvas", snapshot)
	var current := FileAccess.get_file_as_string("res://scripts/ui/pixel_scene_canvas.gd")
	var renderer_path := "res://scripts/ui/environment_art_renderer.gd"
	if current.contains(renderer_path):
		var renderer := FileAccess.get_file_as_string(renderer_path).replace("class_name EnvironmentArtRenderer", "class_name EnvartProfileRenderer")
		renderer = renderer.replace("\tfunc _draw() -> void:", "\tfunc _draw() -> void:\n\t\tvar began := Time.get_ticks_usec()\n\t\t_qa_profile_body()\n\t\tif has_meta(\"envart_draw_profile\"):\n\t\t\tget_meta(\"envart_draw_profile\").record(Time.get_ticks_usec() - began, false)\n\n\tfunc _qa_profile_body() -> void:")
		var path := out_dir.path_join("profile_renderer.gd")
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(renderer)
		file.close()
		current = current.replace(renderer_path, path.replace("\\", "/"))
	var after_first := await _measure(current, "EnvartCurrentProfileCanvas", snapshot)
	var after_second := await _measure(current, "EnvartCurrentProfileCanvas2", snapshot)
	var before_second := await _measure(original, "EnvartOriginalProfileCanvas2", snapshot)
	var before := _combine(before_first, before_second)
	var after := _combine(after_first, after_second)
	var passed := int(before.get("root_draw_calls", 0)) >= 1200 and int(after.get("root_draw_calls", 0)) >= 1200 and float(after.get("mean_cpu_ms_per_root_draw", INF)) <= float(before.get("mean_cpu_ms_per_root_draw", 0.0)) and float(after.get("p95_cpu_ms_per_callback_frame", INF)) <= float(before.get("p95_cpu_ms_per_callback_frame", 0.0))
	var result := {"passed": passed, "before_original": before, "after_current": after, "room": "gas_station_casino", "real_generated_snapshot": true, "object_count": snapshot.get("interactable_objects", []).size(), "scope": "Paired native CPU draw bodies, all retained art children included. Excludes GPU timing and instrumentation bookkeeping; no scheduling or pointer intervention."}
	var file := FileAccess.open(out_dir.path_join("draw_cost.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("ENVART_PAIRED_DRAW_COST " + JSON.stringify({"passed": passed, "before_mean_ms": before.get("mean_cpu_ms_per_root_draw"), "after_mean_ms": after.get("mean_cpu_ms_per_root_draw"), "before_p95_ms": before.get("p95_cpu_ms_per_callback_frame"), "after_p95_ms": after.get("p95_cpu_ms_per_callback_frame")}))
	app.queue_free()
	await process_frame
	PackScript.invalidate()
	quit(0 if passed else 1)


func _combine(first: Dictionary, second: Dictionary) -> Dictionary:
	if first.get("compile_failed", false) or second.get("compile_failed", false):
		return {"compile_failed": true, "samples": [first, second]}
	var samples: Array = first["callback_frame_usec"] + second["callback_frame_usec"]
	samples.sort()
	return {"root_draw_calls": int(first["root_draw_calls"]) + int(second["root_draw_calls"]), "all_draw_callbacks": int(first["all_draw_callbacks"]) + int(second["all_draw_callbacks"]), "mean_cpu_ms_per_root_draw": (float(first["mean_cpu_ms_per_root_draw"]) + float(second["mean_cpu_ms_per_root_draw"])) / 2.0, "p95_cpu_ms_per_callback_frame": float(samples[int(samples.size() * 0.95)]) / 1000.0, "sampling_order": "original,current,current,original; 600 autonomous root draws each after 180 warmup draws", "samples": [first, second]}


func _measure(source: String, class_name_value: String, snapshot: Dictionary) -> Dictionary:
	var script := GDScript.new()
	script.source_code = source.replace("class_name PixelSceneCanvas", "class_name " + class_name_value).replace("func _draw() -> void:", "func _qa_profile_body() -> void:") + "\nfunc _draw() -> void:\n\tvar began := Time.get_ticks_usec()\n\t_qa_profile_body()\n\tget_meta(\"envart_draw_profile\").record(Time.get_ticks_usec() - began, true)\n"
	if script.reload() != OK:
		return {"compile_failed": true}
	var canvas: Control = script.new()
	var profile := ProfileScript.new()
	canvas.set_meta("envart_draw_profile", profile)
	canvas.size = Vector2(900, 430)
	root.add_child(canvas)
	canvas.call("render_environment_snapshot", snapshot.duplicate(true))
	_set_profile(canvas, profile)
	var deadline := Time.get_ticks_msec() + 15000
	while profile.root_calls < 180 and Time.get_ticks_msec() < deadline:
		await process_frame
	profile.reset()
	deadline = Time.get_ticks_msec() + 45000
	while profile.root_calls < 600 and Time.get_ticks_msec() < deadline:
		await process_frame
	var result: Dictionary = profile.result()
	canvas.free()
	return result


func _set_profile(node: Node, profile: RefCounted) -> void:
	node.set_meta("envart_draw_profile", profile)
	for child in node.get_children():
		_set_profile(child, profile)
