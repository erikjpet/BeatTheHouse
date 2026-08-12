extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const OUTPUT_DIR := "res://review_artifacts/blackjack_table_cleanup"
const CAPTURE_SIZE := Vector2i(1280, 720)

var app: Control


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var blackjack_source := FileAccess.get_file_as_string("res://scripts/games/blackjack.gd")
	if blackjack_source.contains("_draw_discard_tray") or blackjack_source.contains("var pad := Rect2(card_start.x - 5"):
		push_error("Legacy blackjack patron-overlap renderer is still present.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = CAPTURE_SIZE
	app = MainScene.instantiate()
	app.set("show_game_library_launcher", true)
	app.set("autosave_slot_id", "blackjack_table_visual_capture")
	root.add_child(app)
	await _settle(8)
	app.call("start_game_test_session", "blackjack")
	await _settle(8)
	await _capture("01_table_idle.png")
	app.call("_handle_module_surface_action", "blackjack_deal", 0, true)
	await create_timer(0.7).timeout
	await _settle(3)
	await _capture("02_table_dealing.png")
	await create_timer(3.5).timeout
	await _settle(3)
	await _capture("03_table_dealt.png")
	print("BLACKJACK_TABLE_VISUAL_CAPTURE_PASS dir=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
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
