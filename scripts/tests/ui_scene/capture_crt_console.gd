extends SceneTree

# First real corrected-CRT image, using the production title Games button.
# Launch only inside a fresh admitted E: QA Job, without --headless.
const MainScene := preload("res://scenes/main.tscn")
var app: Control


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("A rendered native display is required.")
		return
	for key in ["BTH_QA_WORKSPACE", "BTH_QA_EVIDENCE_DIR", "BTH_SAVE_DIR", "BTH_USER_SETTINGS_PATH", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH"]:
		if not OS.get_environment(key).replace("\\", "/").simplify_path().to_lower().begins_with("e:/codexqa/bth/"):
			_fail("Fresh admitted E: paths required: " + key)
			return
	if not ProjectSettings.globalize_path("res://").replace("\\", "/").to_lower().begins_with("e:/codexqa/bth/workspaces/"):
		_fail("The rendered checkout must be the approved E: mirror.")
		return
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "crt_corrected_capture_fresh")
	root.add_child(app)
	await _frames(5)
	var button := app.get("game_library_button") as Button
	if button == null or not button.is_visible_in_tree() or button.disabled:
		_fail("The real title Games button is unavailable.")
		return
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = point - root.get_mouse_position()
	Input.parse_input_event(motion)
	await _frames(2)
	var press := InputEventMouseButton.new()
	press.position = button.get_global_rect().get_center()
	press.global_position = press.position
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.button_mask = 0
	Input.parse_input_event(release)
	await _frames(12)
	var menu := app.get("game_test_menu") as Control
	if menu == null or not menu.is_visible_in_tree() or str(app.get("current_screen")) != "CRT" or not menu.has_method("get_display_viewport"):
		_fail("Games did not reach the corrected CRT display.")
		return
	var display: SubViewport = menu.call("get_display_viewport")
	var tiles := menu.find_children("Launch_*", "Button", true, false)
	if display.size != Vector2i(768, 576) or tiles.size() != 11 or menu.find_child("GameSelectGrid", true, false) == null:
		_fail("The corrected 4:3 eleven-game grid identity is missing.")
		return
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	var destination := OS.get_environment("BTH_QA_EVIDENCE_DIR").path_join("crt-corrected-desktop-first.png")
	if capture == null or capture.is_empty() or capture.save_png(destination) != OK:
		_fail("The rendered game viewport PNG could not be saved.")
		return
	print("CRT_CORRECTED_SCREENSHOT " + JSON.stringify({"path": destination, "sha256": FileAccess.get_sha256(destination), "pixels": [capture.get_width(), capture.get_height()], "source_menu_sha256": FileAccess.get_sha256("res://scripts/ui/crt_practice_menu.gd"), "source_shader_sha256": FileAccess.get_sha256("res://scripts/ui/crt_practice_screen.gdshader"), "route": "real title Games mouse press/release", "grid_count": tiles.size()}))
	app.call("close_game_test_menu")
	app.queue_free()
	await process_frame
	quit(0)


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame
		await RenderingServer.frame_post_draw


func _fail(message: String) -> void:
	push_error("CRT_CAPTURE_FAILED: " + message)
	quit(1)
