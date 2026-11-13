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
	# Time both bodies in the same process frames. Long serial blocks had host
	# clock/load drift up to0.2ms, larger than the measured room-layer difference.
	# Reverse canvas order for the second pair; retain the same strict gate.
	var first := await _measure_pair(original, current, snapshot, false)
	var second := await _measure_pair(original, current, snapshot, true)
	var before := _combine(first["before"], second["before"])
	var after := _combine(first["after"], second["after"])
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
	return {"root_draw_calls": int(first["root_draw_calls"]) + int(second["root_draw_calls"]), "all_draw_callbacks": int(first["all_draw_callbacks"]) + int(second["all_draw_callbacks"]), "mean_cpu_ms_per_root_draw": (float(first["mean_cpu_ms_per_root_draw"]) + float(second["mean_cpu_ms_per_root_draw"])) / 2.0, "p95_cpu_ms_per_callback_frame": float(samples[int(samples.size() * 0.95)]) / 1000.0, "sampling_order": "same-frame original/current then same-frame current/original; 600 autonomous root draws each after 180 warmup draws", "samples": [first, second]}


func _profiled_canvas(source: String, class_name_value: String, snapshot: Dictionary, profile: RefCounted) -> Control:
	var script := GDScript.new()
	script.source_code = source.replace("class_name PixelSceneCanvas", "class_name " + class_name_value).replace("func _draw() -> void:", "func _qa_profile_body() -> void:") + "\nfunc _draw() -> void:\n\tvar began := Time.get_ticks_usec()\n\t_qa_profile_body()\n\tget_meta(\"envart_draw_profile\").record(Time.get_ticks_usec() - began, true)\n"
	if script.reload() != OK:
		return null
	var canvas: Control = script.new()
	canvas.set_meta("envart_draw_profile", profile)
	canvas.size = Vector2(900, 430)
	root.add_child(canvas)
	canvas.call("render_environment_snapshot", snapshot.duplicate(true))
	_set_profile(canvas, profile)
	return canvas


func _measure_pair(original: String, current: String, snapshot: Dictionary, reverse: bool) -> Dictionary:
	var before_profile := ProfileScript.new()
	var after_profile := ProfileScript.new()
	var before := _profiled_canvas(original, "EnvartOriginalProfileCanvas", snapshot, before_profile)
	var after := _profiled_canvas(current, "EnvartCurrentProfileCanvas", snapshot, after_profile)
	if before == null or after == null:
		return {"before": {"compile_failed": true}, "after": {"compile_failed": true}}
	if reverse:
		root.move_child(after, 0)
	var deadline := Time.get_ticks_msec() + 15000
	while mini(before_profile.root_calls, after_profile.root_calls) < 180 and Time.get_ticks_msec() < deadline:
		await process_frame
	# The asynchronous view may create its retained children after publication.
	# Bind them after warmup too, before any measured samples are admitted.
	_set_profile(after, after_profile)
	before_profile.reset()
	after_profile.reset()
	deadline = Time.get_ticks_msec() + 45000
	while mini(before_profile.root_calls, after_profile.root_calls) < 600 and Time.get_ticks_msec() < deadline:
		await process_frame
	var result := {"before": before_profile.result(), "after": after_profile.result()}
	before.free()
	after.free()
	return result


func _set_profile(node: Node, profile: RefCounted) -> void:
	node.set_meta("envart_draw_profile", profile)
	for child in node.get_children():
		_set_profile(child, profile)
