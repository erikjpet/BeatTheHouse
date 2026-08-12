extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const SaveServiceScript := preload("res://scripts/core/save_service.gd")
const TEST_SLOT := "main_menu_redesign_check"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var saves = SaveServiceScript.new()
	saves.clear_run(TEST_SLOT)
	var app: Control = MainScene.instantiate()
	app.set("autosave_slot_id", TEST_SLOT)
	root.add_child(app)
	await process_frame
	await process_frame
	var snapshot: Dictionary = app.call("current_start_menu_snapshot")
	_check(bool(snapshot.get("logo_loaded", false)), "new logo was not loaded")
	_check(not str(snapshot.get("background_environment_id", "")).is_empty(), "random background was not selected")
	_check(str(snapshot.get("primary_action_text", "")) == "PLAY", "fresh slot did not show Play")
	var background: PixelSceneCanvas = app.get("main_menu_background")
	var background_view: Dictionary = background.current_view_snapshot() if background != null else {}
	_check(background != null and background.mouse_filter == Control.MOUSE_FILTER_IGNORE, "menu environment was not click-through")
	_check(is_equal_approx(float(background_view.get("camera_zoom", 0.0)), 1.0), "menu environment did not keep in-game camera framing")
	_check(bool(background_view.get("scene_idle_animation_active", false)), "menu environment animations were not active")
	_check(bool(background_view.get("background_texture_loaded", false)) if background_view.has("background_texture_loaded") else background != null and background.get("background_texture") != null, "menu environment did not load its production background")
	var action_row: HBoxContainer = app.get("main_menu_action_row")
	var marquee_buttons: Array[Button] = [app.get("new_run_button"), app.get("daily_run_button"), app.get("run_config_button"), app.get("replay_tutorial_button"), app.get("collections_button")]
	_check(action_row != null and action_row.get_child_count() == 3, "main-menu actions were not centered as one grid")
	var plate_texture := load("res://assets/art/ui/main_menu_button_plate.png") as Texture2D
	var plate_image := plate_texture.get_image() if plate_texture != null else null
	_check(plate_image != null and plate_image.get_pixel(0, 0).a <= 0.01 and plate_image.get_pixel(plate_image.get_width() - 1, plate_image.get_height() - 1).a <= 0.01, "main-menu marquee exterior was not transparent")
	_check(plate_image != null and plate_image.get_pixel(plate_image.get_width() / 2, plate_image.get_height() / 2).a >= 0.99, "main-menu marquee interior panel lost opacity")
	for button in marquee_buttons:
		_check(button != null and button.get_theme_stylebox("normal") is StyleBoxTexture, "main-menu action did not use the pixel marquee image")
		_check(button != null and button.get_theme_stylebox("focus") is StyleBoxTexture, "main-menu action focus state did not use the pixel marquee image")
	for config_button: Button in [app.get("content_group_config_button"), app.get("challenge_select_button"), app.get("delete_saved_run_button")]:
		_check(config_button != null and not (config_button.get_theme_stylebox("normal") is StyleBoxTexture), "run-configuration action incorrectly reused the main-menu marquee image")
	_check(app.get("career_button") == null, "Career remains on the main menu")
	_check(app.get("inventory_button") == null, "Inventory remains on the main menu")
	_check(app.get("game_library_button") == null, "Games remains on the main menu")
	var settings_menu: SettingsMenu = app.get("settings_menu")
	_check(settings_menu != null and settings_menu.game_library != null, "debug game library was not moved into Settings")
	app.call("start_foundation_run", "MAIN-MENU-RESUME-CHECK")
	await process_frame
	app.call("return_to_main_menu")
	await process_frame
	_check(str(app.call("current_start_menu_snapshot").get("primary_action_text", "")) == "CONTINUE", "saved slot did not replace Play with Continue")
	for button in marquee_buttons:
		_check(button != null and button.is_visible_in_tree(), "main-menu action remained hidden after reopening the menu")
	app.call("open_run_configuration")
	_check(bool(app.call("current_start_menu_snapshot").get("run_config_visible", false)), "run configuration did not open")
	app.call("close_run_configuration")
	app.call("open_run_configuration")
	_check(bool(app.call("current_start_menu_snapshot").get("run_config_visible", false)), "run configuration did not reopen")
	app.call("close_run_configuration")
	for button in marquee_buttons:
		_check(button != null and button.is_visible_in_tree(), "main-menu action remained hidden after reopening and closing Run Setup")
	app.call("open_run_configuration")
	app.call("open_content_group_config")
	_check(bool(app.call("current_start_menu_snapshot").get("content_group_config_visible", false)), "run content did not open inside setup")
	var music: ProceduralMusicPlayer = app.get("procedural_music_player")
	var theory := music.music_theory_snapshot_for_environment(music.main_menu_theme_environment(), 0)
	_check(int(theory.get("phrase_count", 0)) == 6, "menu overture did not generate its six-part tour")
	_check(str(theory.get("palette_id", "")) == "menu_tour_ensemble", "menu overture palette was not selected")
	saves.clear_run(TEST_SLOT)
	if failures.is_empty():
		print("MAIN_MENU_REDESIGN_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
