extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const OUTPUT_DIR := "res://review_artifacts/main_menu_redesign"
const CAPTURE_SIZE := Vector2i(1280, 720)

var app: Control


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = CAPTURE_SIZE
	app = MainScene.instantiate()
	root.add_child(app)
	await _settle(10)
	await _capture("01_main_menu.png")
	app.call("open_run_configuration")
	await _settle(4)
	await _capture("02_run_configuration.png")
	app.call("close_run_configuration")
	app.call("start_foundation_run", "MAIN-MENU-REOPEN-CAPTURE")
	await _settle(4)
	app.call("return_to_main_menu")
	await _settle(6)
	await _capture("04_main_menu_reopened.png")
	print("MAIN_MENU_CAPTURE_PASS dir=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame


func _capture(file_name: String) -> void:
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image.get_size() != CAPTURE_SIZE:
		image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_NEAREST)
	var error := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	if error != OK:
		push_error("Could not save %s" % file_name)
		quit(1)
