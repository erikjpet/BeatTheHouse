extends SceneTree
const MainScene := preload("res://scenes/main.tscn")
const PackScript := preload("res://scripts/ui/environment_art_pack.gd")
var out_dir := ""
var before := false
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		before = before or arg == "--before"
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app: Control = MainScene.instantiate()
	app.set("script_prewarm_stopping", true)
	root.add_child(app)
	await _settle(8)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F6
	key.pressed = true
	if not before:
		_check(not app.call("_handle_environment_art_reload_hotkey", key), "F6 is unavailable outside an Environment Library practice room.")
	app.call("open_environment_test_menu")
	app.call("_environment_test_select_id", app.get("environment_test_archetype_option"), "bar")
	app.call("_refresh_environment_test_identity_options")
	app.call("_environment_test_select_id", app.get("environment_test_scenario_option"), "__none")
	app.get("environment_test_seed_input").text = "LAYOUT-SURVEY-QA"
	var generated: Dictionary = app.call("start_environment_test_session")
	_check(bool(generated.get("ok", false)), "Production practice room generated.")
	await _settle(12)
	var canvas: Control = app.get("environment_canvas")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("reload_before.png"))
	if before:
		_check(not app.has_method("_handle_environment_art_reload_hotkey"), "Before: no authoring reload handler exists.")
	else:
		var manifest_path := "res://data/art/environments/bar.json"
		var alternate_path := "res://assets/art/environments/bar/authoring_test.png"
		_check(not FileAccess.file_exists(alternate_path), "Own temporary PNG path is unused.")
		var original := FileAccess.get_file_as_bytes(manifest_path)
		var manifest: Dictionary = JSON.parse_string(original.get_string_from_utf8())
		manifest["background"]["texture"] = "authoring_test.png"
		var file := FileAccess.open(manifest_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(manifest))
		file.close()
		var image := Image.create(1800, 860, false, Image.FORMAT_RGBA8)
		image.fill(Color.BLUE)
		_check(image.save_png(alternate_path) == OK, "Own unimported blue PNG was saved.")
		var snapshot: Dictionary = canvas.get("foundation_snapshot").duplicate(true)
		var old_clock: float = canvas.get("flicker")
		_check(app.call("_handle_environment_art_reload_hotkey", key), "Physical F6 is handled in native developer practice.")
		var pack: EnvironmentArtPack = canvas.get("environment_art_pack")
		_check(pack != null and pack.background.get_image().get_pixel(0, 0).is_equal_approx(Color.BLUE), "Reload reads the changed JSON and a new raw PNG without an import/restart.")
		await _settle(4)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join("reload_blue.png"))
		image.fill(Color.GREEN)
		_check(image.save_png(alternate_path) == OK, "Own PNG was overwritten green.")
		key.physical_keycode = 0
		key.keycode = KEY_F6
		_check(app.call("_handle_environment_art_reload_hotkey", key), "Logical F6 is handled.")
		pack = canvas.get("environment_art_pack")
		_check(pack != null and pack.background.get_image().get_pixel(0, 0).is_equal_approx(Color.GREEN), "Reload bypasses an older imported/cached texture.")
		canvas.call("set_developer_slot_placement_mode", true)
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join("reload_green.png"))
		_check(float(canvas.get("flicker")) > old_clock and canvas.is_processing(), "Reload preserves autonomous processing and placement clock.")
		_check(canvas.get("foundation_snapshot") == snapshot, "Reload does not mutate the practice snapshot or object geometry.")
		key.echo = true
		_check(not app.call("_handle_environment_art_reload_hotkey", key), "Key repeat is ignored.")
		key.echo = false
		manifest["board_size"] = [899, 430]
		file = FileAccess.open(manifest_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(manifest))
		file.close()
		_check(app.call("_handle_environment_art_reload_hotkey", key) and canvas.get("environment_art_pack") == null, "Invalid saved JSON immediately uses the live code fallback.")
		await _settle(3)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join("reload_invalid_fallback.png"))
		file = FileAccess.open(manifest_path, FileAccess.WRITE)
		file.store_buffer(original)
		file.close()
		DirAccess.remove_absolute(alternate_path)
		_check(app.call("_handle_environment_art_reload_hotkey", key) and canvas.get("environment_art_pack") != null, "Corrected saved inputs restore the pack without restart.")
	var result := {"before": before, "checks": checks, "failures": failures, "editor": OS.has_feature("editor"), "template": OS.has_feature("template")}
	var report := FileAccess.open(out_dir.path_join("reload.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(result, "\t"))
	report.close()
	print("ENVART_RELOAD_CONTRACT " + JSON.stringify(result))
	app.free()
	PackScript.invalidate()
	quit(0 if failures.is_empty() else 1)

func _settle(count: int) -> void:
	for i in range(count):
		await process_frame

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
