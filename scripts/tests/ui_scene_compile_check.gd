extends SceneTree

# Fresh-process UI compile smoke test. This catches missing palette tokens,
# scene preload failures, and startup control construction errors before the
# longer production playtest starts driving gameplay.

const MainScene := preload("res://scenes/main.tscn")
const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")
const SfxPlayerScript := preload("res://scripts/ui/sfx_player.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const TEST_SETTINGS_PATH := "user://settings_ui_scene_compile_check.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_use_isolated_user_settings(TEST_SETTINGS_PATH)
	if VisualStyleScript.HOT != VisualStyleScript.PINK:
		push_error("VisualStyle.HOT should alias the production hot/pink token.")
		quit(1)
		return

	var app: Control = MainScene.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	if app.get_script().resource_path != "res://scripts/ui/foundation_main.gd":
		push_error("Main scene is not wired to the foundation UI shell.")
		quit(1)
		return
	if not app.has_method("uses_foundation_runtime") or not bool(app.call("uses_foundation_runtime")):
		push_error("Foundation UI shell did not initialize the README runtime contracts.")
		quit(1)
		return
	if app.get("start_screen") == null:
		push_error("Main UI did not build the start screen.")
		quit(1)
		return
	if app.get("run_screen") == null:
		push_error("Main UI did not build the run screen.")
		quit(1)
		return
	if app.get("run_state") != null:
		push_error("Foundation UI shell should wait for player start before creating RunState.")
		quit(1)
		return
	var start_screen_snapshot: Dictionary = app.call("current_screen_snapshot")
	if str(start_screen_snapshot.get("screen", "")) != "START":
		push_error("Foundation screen router did not start in START state.")
		quit(1)
		return
	var start_screen: Control = app.get("start_screen")
	var run_screen: Control = app.get("run_screen")
	if not start_screen.visible or run_screen.visible:
		push_error("Main UI should show the start/setup state before a run begins.")
		quit(1)
		return
	var save_service: SaveService = app.get("save_service")
	var continue_button: Button = app.get("continue_button")
	if continue_button == null:
		push_error("Main UI did not build the conditional Continue button.")
		quit(1)
		return
	var compile_save_slot := "foundation_ui_compile_autosave"
	var remove_error := _remove_save_slot(save_service, compile_save_slot)
	if remove_error != OK:
		push_error("Could not prepare an empty compile-test save slot.")
		quit(1)
		return
	app.set("autosave_slot_id", compile_save_slot)
	app.call("_refresh_start_screen")
	await process_frame
	var has_start_save := save_service.has_run(compile_save_slot)
	if not continue_button.visible:
		push_error("Main menu should keep the Continue selection visible in the 2x2 sign layout.")
		quit(1)
		return
	if has_start_save:
		push_error("Compile-test save slot should start empty.")
		quit(1)
		return
	if not continue_button.disabled:
		push_error("Continue button should be disabled when no foundation save exists.")
		quit(1)
		return
	var continue_test_run: RunState = RunStateScript.new()
	continue_test_run.start_new("UI-COMPILE-CONTINUE-SAVE")
	var save_error := save_service.save_run(continue_test_run, compile_save_slot)
	if save_error != OK:
		push_error("Could not create compile-test save for Continue state.")
		quit(1)
		return
	app.call("_refresh_start_screen")
	await process_frame
	if continue_button.disabled:
		push_error("Continue button should be enabled when a foundation save exists.")
		quit(1)
		return
	var start_status_label: Label = app.get("start_status_label")
	if start_status_label == null or not start_status_label.visible or start_status_label.text.is_empty():
		push_error("Main menu should show clear Continue/save availability text.")
		quit(1)
		return
	if not _has_visible_text(app, "Simulated gambling only") or not _has_visible_text(app, "no real-money wagering"):
		push_error("Main menu did not present the simulated/no-real-money framing.")
		quit(1)
		return
	if _has_visible_text(app, "Game Test"):
		push_error("Release main menu exposed the temporary Game Test launcher.")
		quit(1)
		return
	var game_library_button: Button = app.get("game_library_button")
	var game_library_page: Control = app.get("game_test_menu")
	if game_library_button == null or game_library_page == null or not game_library_button.visible or game_library_button.disabled:
		push_error("Main menu did not expose the Games page.")
		quit(1)
		return
	if _has_visible_text(app, "Daily Run") or _has_visible_text(app, "Custom Challenge"):
		push_error("Release main menu exposed challenge buttons before challenge content is complete.")
		quit(1)
		return
	var settings_button: Button = app.get("settings_button")
	var inventory_button: Button = app.get("inventory_button")
	var exit_game_button: Button = app.get("exit_game_button")
	var settings_menu: SettingsMenu = app.get("settings_menu")
	var inventory_page: Control = app.get("inventory_page")
	var start_menu_controls: Control = app.get("start_menu_controls")
	if settings_button == null or inventory_button == null or exit_game_button == null or settings_menu == null or inventory_page == null or start_menu_controls == null:
		push_error("Main menu did not expose the required run, settings, inventory, and exit controls.")
		quit(1)
		return
	if not exit_game_button.visible or exit_game_button.disabled:
		push_error("Main menu Exit Game button should be visible and enabled.")
		quit(1)
		return
	game_library_button.emit_signal("pressed")
	await process_frame
	if not game_library_page.visible or start_menu_controls.visible:
		push_error("Games button did not open the main-menu Games page.")
		quit(1)
		return
	if not _has_visible_text(game_library_page, "Game Library") or not _has_visible_text(game_library_page, "Practice any available table"):
		push_error("Games page did not present release-facing practice copy.")
		quit(1)
		return
	var library_for_games: ContentLibrary = app.get("library")
	var expected_game_names := _implemented_game_display_names(library_for_games)
	if expected_game_names.is_empty():
		push_error("Games page test could not find implemented game modules.")
		quit(1)
		return
	for display_name in expected_game_names:
		if not _has_visible_text(game_library_page, str(display_name)):
			push_error("Games page did not expose implemented game: %s." % str(display_name))
			quit(1)
			return
	if app.get("run_state") != null:
		push_error("Opening the Games page should not start or mutate a run.")
		quit(1)
		return
	app.call("close_game_test_menu")
	await process_frame
	if game_library_page.visible or not start_menu_controls.visible:
		push_error("Games page Back did not return to the main menu controls.")
		quit(1)
		return
	if settings_menu.visible:
		push_error("Settings menu should start closed on the main menu.")
		quit(1)
		return
	settings_button.emit_signal("pressed")
	await process_frame
	if not settings_menu.visible or start_menu_controls.visible:
		push_error("Settings button did not open the main menu settings panel.")
		quit(1)
		return
	if settings_menu.get("resolution") == null or settings_menu.get("master") == null or settings_menu.get("music") == null or settings_menu.get("sfx") == null or settings_menu.get("drunk_effect") == null or settings_menu.get("high_contrast") == null:
		push_error("Settings menu did not expose resolution, audio, drunk visual, and high-contrast controls.")
		quit(1)
		return
	var resolution_option: OptionButton = settings_menu.get("resolution")
	var mode_option: OptionButton = settings_menu.get("mode")
	var drunk_effect_option: OptionButton = settings_menu.get("drunk_effect")
	var high_contrast_check: CheckBox = settings_menu.get("high_contrast")
	var reduce_motion_check: CheckBox = settings_menu.get("reduce_motion")
	var ui_scale_slider: HSlider = settings_menu.get("ui")
	var text_size_option: OptionButton = settings_menu.get("text_size")
	if resolution_option.item_count < 2 or mode_option.item_count < 1:
		push_error("Settings menu did not populate resolution or window mode choices.")
		quit(1)
		return
	if drunk_effect_option.item_count < 2:
		push_error("Settings menu did not populate the drunk visual mode choices.")
		quit(1)
		return
	if high_contrast_check == null or reduce_motion_check == null or ui_scale_slider == null or text_size_option == null:
		push_error("Settings menu did not expose release accessibility controls.")
		quit(1)
		return
	var user_settings: UserSettings = app.get("user_settings")
	var original_settings := {}
	if user_settings != null:
		original_settings = user_settings.to_dict()
	resolution_option.select(resolution_option.item_count - 1)
	resolution_option.item_selected.emit(resolution_option.item_count - 1)
	mode_option.select(0)
	mode_option.item_selected.emit(0)
	var target_high_contrast := true
	if not original_settings.is_empty():
		target_high_contrast = not bool(original_settings.get("high_contrast", false))
	high_contrast_check.button_pressed = target_high_contrast
	high_contrast_check.toggled.emit(target_high_contrast)
	reduce_motion_check.button_pressed = true
	reduce_motion_check.toggled.emit(true)
	ui_scale_slider.value = 130
	ui_scale_slider.value_changed.emit(130)
	text_size_option.select(2)
	text_size_option.item_selected.emit(2)
	settings_menu.call("_on_apply")
	await process_frame
	var accessibility_snapshot: Dictionary = app.call("current_accessibility_snapshot")
	if user_settings != null:
		if bool(user_settings.high_contrast) != target_high_contrast:
			push_error("Settings apply did not persist the high-contrast draft to live settings.")
			quit(1)
			return
		if not bool(user_settings.reduce_motion):
			push_error("Settings apply did not persist reduce motion.")
			quit(1)
			return
		if str(user_settings.text_size) != "large" or absf(float(user_settings.ui_scale) - 1.3) > 0.001:
			push_error("Settings apply did not persist large text and UI scale.")
			quit(1)
			return
	if bool(VisualStyleScript.accessibility_snapshot().get("high_contrast_enabled", false)) != target_high_contrast:
		push_error("VisualStyle did not reflect the high-contrast setting.")
		quit(1)
		return
	if bool(accessibility_snapshot.get("showdown_motion_enabled", true)) or bool(accessibility_snapshot.get("terminal_motion_enabled", true)):
		push_error("Reduced motion did not disable showdown and terminal motion policy.")
		quit(1)
		return
	if bool(accessibility_snapshot.get("haptics_supported", true)) or str(accessibility_snapshot.get("haptics_cut_reason", "")).is_empty():
		push_error("Settings did not document the haptics release cut.")
		quit(1)
		return
	var reloaded_settings: UserSettings = UserSettingsScript.new()
	reloaded_settings.load()
	if bool(reloaded_settings.high_contrast) != target_high_contrast or not bool(reloaded_settings.reduce_motion) or str(reloaded_settings.text_size) != "large":
		push_error("Settings save/load did not preserve accessibility settings after restart.")
		quit(1)
		return
	if user_settings != null and not original_settings.is_empty():
		user_settings.from_dict(original_settings)
		user_settings.apply()
		VisualStyleScript.set_high_contrast_enabled(bool(original_settings.get("high_contrast", false)))
		user_settings.save()
		app.call("_on_settings_applied")
	if app.get("run_state") != null:
		push_error("Opening Settings should not start or mutate a run.")
		quit(1)
		return
	app.call("close_settings_menu")
	await process_frame
	if settings_menu.visible or not start_menu_controls.visible:
		push_error("Settings menu did not return to the main menu controls.")
		quit(1)
		return
	inventory_button.emit_signal("pressed")
	await process_frame
	if not inventory_page.visible or start_menu_controls.visible:
		push_error("Inventory button did not open the profile inventory page.")
		quit(1)
		return
	if app.get("profile_inventory") == null or app.get("acquire_chip_button") == null or app.get("inventory_items_list") == null:
		push_error("Profile inventory page did not expose storage controls.")
		quit(1)
		return
	app.call("close_inventory_page")
	await process_frame
	if inventory_page.visible or not start_menu_controls.visible:
		push_error("Inventory page did not return to the main menu controls.")
		quit(1)
		return
	if app.get("save_status_label") == null:
		push_error("Main UI did not build the save status label.")
		quit(1)
		return
	var seed_input: LineEdit = app.get("seed_input")
	var new_run_button: Button = app.get("new_run_button")
	if seed_input == null or new_run_button == null:
		push_error("Main UI did not expose seed input and New Run button.")
		quit(1)
		return
	if seed_input.placeholder_text != "Enter run seed" or seed_input.tooltip_text.is_empty():
		push_error("Seed entry did not expose clear release menu guidance.")
		quit(1)
		return
	seed_input.text = "UI-COMPILE-SEED"
	new_run_button.emit_signal("pressed")
	await process_frame
	if app.get("run_state") == null:
		push_error("New Run button did not create a foundation RunState.")
		quit(1)
		return
	var started_run_state: RunState = app.get("run_state")
	if started_run_state.seed_text != "UI-COMPILE-SEED":
		push_error("New Run did not start with the entered seed.")
		quit(1)
		return
	var run_screen_snapshot: Dictionary = app.call("current_screen_snapshot")
	if str(run_screen_snapshot.get("screen", "")) != "ENVIRONMENT":
		push_error("Foundation screen router did not move to ENVIRONMENT after starting a run.")
		quit(1)
		return
	if start_screen.visible or not run_screen.visible:
		push_error("Main UI did not move from setup to run state after New Run.")
		quit(1)
		return
	if app.get("top_menu_button") == null or app.get("top_settings_button") == null or app.get("top_inventory_button") == null:
		push_error("Run HUD did not expose Menu, Settings, and Inventory buttons together.")
		quit(1)
		return
	var procedural_music_player = app.get("procedural_music_player")
	if procedural_music_player == null:
		push_error("Main UI did not create the procedural music player.")
		quit(1)
		return
	var generated_music: AudioStreamWAV = procedural_music_player.call("preview_stream_for_environment", app.get("run_state").current_environment, 70)
	if generated_music == null:
		push_error("Procedural music player did not generate an environment stream.")
		quit(1)
		return
	if generated_music.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		push_error("Generated environment music stream should loop.")
		quit(1)
		return
	if generated_music.data.size() <= 22050:
		push_error("Generated environment music stream did not contain enough PCM data.")
		quit(1)
		return
	if generated_music.loop_end < 22050 * 24:
		push_error("Generated environment music should be a longer arranged theme, not a short repeated loop.")
		quit(1)
		return
	var music_theory: Dictionary = procedural_music_player.call("music_theory_snapshot_for_environment", app.get("run_state").current_environment, 70)
	if music_theory.is_empty() or str(music_theory.get("mode", "")).is_empty():
		push_error("Procedural music player did not expose a generated mode/harmony plan.")
		quit(1)
		return
	if (music_theory.get("progression_degrees", []) as Array).size() < 4:
		push_error("Generated environment music should use a multi-chord progression.")
		quit(1)
		return
	if (music_theory.get("chord_intervals", []) as Array).size() < 4:
		push_error("Generated environment music did not derive diatonic chord voicings.")
		quit(1)
		return
	if (music_theory.get("motif", []) as Array).size() < 8:
		push_error("Generated environment music did not expose a reusable melodic motif.")
		quit(1)
		return
	var music_latency: Dictionary = procedural_music_player.call("music_generation_latency_snapshot_for_environment", app.get("run_state").current_environment, 70)
	if music_latency.is_empty():
		push_error("Procedural music player did not expose staged generation timing.")
		quit(1)
		return
	if int(music_latency.get("primer_frames", 0)) <= 0 or int(music_latency.get("full_frames", 0)) <= 0:
		push_error("Staged procedural music generation did not produce usable frame counts.")
		quit(1)
		return
	if int(music_latency.get("instant_frames", 0)) <= 0:
		push_error("Live procedural music did not expose an immediate bed frame count.")
		quit(1)
		return
	if int(music_latency.get("primer_frames", 0)) >= int(music_latency.get("full_frames", 0)):
		push_error("Live procedural music primer should be shorter than the full arranged stream.")
		quit(1)
		return
	if float(music_latency.get("instant_seconds", 999.0)) > 1.5:
		push_error("Live procedural music immediate bed is too long to generate at travel arrival.")
		quit(1)
		return
	if float(music_latency.get("primer_seconds", 999.0)) > 4.0:
		push_error("Live procedural music primer is too long to solve first-playback latency.")
		quit(1)
		return
	var transition_policy: Dictionary = procedural_music_player.call("music_transition_policy_snapshot_for_environment", app.get("run_state").current_environment, 70)
	if transition_policy.is_empty() or not bool(transition_policy.get("deferred_stream_changes", false)):
		push_error("Procedural music player did not expose deferred breakpoint transitions.")
		quit(1)
		return
	if int(transition_policy.get("break_steps", 0)) < 4 or float(transition_policy.get("break_seconds", 0.0)) <= 0.0:
		push_error("Procedural music transitions should wait for a musical break point.")
		quit(1)
		return
	var slot_sfx := SfxPlayerScript.new()
	var lever_sfx: AudioStreamWAV = slot_sfx.preview_event_stream("lever")
	var reel_loop_sfx: AudioStreamWAV = slot_sfx.preview_event_stream("reel_loop")
	var jackpot_sfx: AudioStreamWAV = slot_sfx.preview_event_stream("jackpot")
	var pull_tab_thump_sfx: AudioStreamWAV = slot_sfx.preview_event_stream("pull_tab_thump")
	var paper_peel_sfx: AudioStreamWAV = slot_sfx.preview_event_stream("paper_peel")
	if lever_sfx == null or reel_loop_sfx == null or jackpot_sfx == null or pull_tab_thump_sfx == null or paper_peel_sfx == null:
		push_error("SFX player did not generate required procedural streams.")
		quit(1)
		return
	if lever_sfx.data.size() <= 2048 or jackpot_sfx.data.size() <= lever_sfx.data.size():
		push_error("SFX streams are too small to represent distinct machine events.")
		quit(1)
		return
	if pull_tab_thump_sfx.data.size() <= 2048 or paper_peel_sfx.data.size() <= 2048:
		push_error("Pull-tab SFX streams are too small to represent dispenser and paper events.")
		quit(1)
		return
	if reel_loop_sfx.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		push_error("Slot reel whirr SFX should loop while reels are spinning.")
		quit(1)
		return
	slot_sfx.free()
	var viewport_rect := app.get_viewport().get_visible_rect()
	if viewport_rect.size.x < 1279.0 or viewport_rect.size.y < 719.0:
		push_error("UI scene compile check is not running at the 1280x720 target viewport: %s." % str(viewport_rect))
		quit(1)
		return
	if not _control_fits_viewport(run_screen, viewport_rect, "run screen"):
		quit(1)
		return
	if not _control_fits_viewport(app.get("environment_canvas"), viewport_rect, "environment canvas"):
		quit(1)
		return
	if not _control_fits_viewport(app.get("game_surface_canvas"), viewport_rect, "game surface canvas"):
		quit(1)
		return
	if not _control_fits_viewport(app.get("consequence_cards_scroll"), viewport_rect, "consequence cards scroll"):
		quit(1)
		return
	if not _check_game_surface_touch_hit_policy():
		quit(1)
		return
	var initial_environment_canvas: Control = app.get("environment_canvas")
	var initial_game_surface: Control = app.get("game_surface_canvas")
	if initial_environment_canvas == null or not initial_environment_canvas.visible:
		push_error("M1.6B environment mode did not keep the environment canvas primary and visible.")
		quit(1)
		return
	if not _control_clips_contents(initial_environment_canvas, "environment canvas"):
		quit(1)
		return
	if not _environment_canvas_keeps_critical_ui_clear(app, initial_environment_canvas, viewport_rect, "environment canvas"):
		quit(1)
		return
	if initial_game_surface != null and initial_game_surface.visible:
		push_error("M1.6B environment mode still showed the game surface as a competing preview.")
		quit(1)
		return
	var layout_serialized_before := JSON.stringify(app.call("serialized_run_state"))
	var spatial_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	var spatial_objects: Array = spatial_snapshot.get("objects", [])
	if spatial_objects.is_empty():
		push_error("M1.6 spatial interaction model did not expose interactable objects.")
		quit(1)
		return
	for field in ["hover_target_id", "focus_target_id", "selected_object_id", "camera_focus_rect", "camera_focus_point", "current_context_mode"]:
		if not spatial_snapshot.has(field):
			push_error("M1.6 spatial interaction snapshot is missing UI-local field: %s." % field)
			quit(1)
			return
	if _interactable_by_type(spatial_objects, "game").is_empty():
		push_error("M1.6 spatial interaction model did not expose game objects from foundation state.")
		quit(1)
		return
	if _interactable_by_type(spatial_objects, "travel").is_empty():
		push_error("M1.6 spatial interaction model did not expose travel objects from foundation state.")
		quit(1)
		return
	var first_interactable: Dictionary = spatial_objects[0]
	for field in ["object_id", "object_type", "source_id", "label", "enabled", "normalized_rect", "focus_point", "available_actions"]:
		if not first_interactable.has(field):
			push_error("M1.6 interactable object is missing field: %s." % field)
			quit(1)
			return
	var serialized_before_focus := JSON.stringify(app.call("serialized_run_state"))
	var focus_object_id := str(first_interactable.get("object_id", ""))
	if not bool(app.call("focus_interactable_object", focus_object_id)):
		push_error("M1.6 spatial interaction model rejected a valid focus object.")
		quit(1)
		return
	await process_frame
	if serialized_before_focus != JSON.stringify(app.call("serialized_run_state")):
		push_error("M1.6 focusing an interactable object mutated serialized RunState.")
		quit(1)
		return
	var focused_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	if str(focused_snapshot.get("selected_object_id", "")) != focus_object_id or str(focused_snapshot.get("focus_target_id", "")) != focus_object_id:
		push_error("M1.6 focus state was not stored as UI-local state.")
		quit(1)
		return
	if str(first_interactable.get("object_type", "")) == "game":
		var focused_summary_label := app.get("summary_label") as Label
		if focused_summary_label == null or focused_summary_label.text.find("Double-click") == -1:
			push_error("M1.6 focused game object did not expose world-surface interaction guidance.")
			quit(1)
			return
	var focus_canvas: Control = app.get("environment_canvas")
	var focus_canvas_snapshot: Dictionary = focus_canvas.call("current_view_snapshot")
	if not bool(focus_canvas_snapshot.get("camera_focus_active", false)) or float(focus_canvas_snapshot.get("target_camera_zoom", 1.0)) <= 1.0:
		push_error("M1.6 camera focus did not zoom/emphasize a selected object.")
		quit(1)
		return
	if not await _focus_camera_animation_is_stable(focus_canvas, "focused environment canvas"):
		quit(1)
		return
	if not bool(focus_canvas_snapshot.get("clip_contents", false)) or not _control_clips_contents(focus_canvas, "focused environment canvas"):
		quit(1)
		return
	if not _canvas_preserves_art_aspect(focus_canvas_snapshot, "focused environment canvas"):
		quit(1)
		return
	if not _environment_canvas_keeps_critical_ui_clear(app, focus_canvas, viewport_rect, "focused environment canvas"):
		quit(1)
		return
	if not bool(app.call("hover_interactable_object", focus_object_id)):
		push_error("M1.6 spatial interaction model rejected a valid hover object.")
		quit(1)
		return
	if serialized_before_focus != JSON.stringify(app.call("serialized_run_state")):
		push_error("M1.6 hovering an interactable object mutated serialized RunState.")
		quit(1)
		return
	app.call("clear_interaction_focus")
	await process_frame
	var cleared_spatial_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	if str(cleared_spatial_snapshot.get("current_context_mode", "")) != "room" or not str(cleared_spatial_snapshot.get("selected_object_id", "")).is_empty():
		push_error("M1.6 clear focus did not return to room presentation state.")
		quit(1)
		return
	var cleared_canvas_snapshot: Dictionary = focus_canvas.call("current_view_snapshot")
	if bool(cleared_canvas_snapshot.get("camera_focus_active", true)) or float(cleared_canvas_snapshot.get("target_camera_zoom", 0.0)) != 1.0:
		push_error("M1.6 Back to room did not restore the full-room camera target.")
		quit(1)
		return
	if not _environment_canvas_keeps_critical_ui_clear(app, focus_canvas, viewport_rect, "cleared environment canvas"):
		quit(1)
		return
	if serialized_before_focus != JSON.stringify(app.call("serialized_run_state")):
		push_error("M1.6 clearing focus mutated serialized RunState.")
		quit(1)
		return
	var live_environment_canvas: Control = app.get("environment_canvas")
	var canvas_snapshot: Dictionary = live_environment_canvas.call("current_view_snapshot")
	var object_layout: Dictionary = canvas_snapshot.get("object_layout", {})
	if int(object_layout.get("overlap_count", -1)) != 0:
		push_error("Environment object layout allowed overlapping room props: %s." % str(object_layout.get("overlaps", [])))
		quit(1)
		return
	var canvas_object := _canvas_object_by_id(canvas_snapshot.get("objects", []), focus_object_id)
	if canvas_object.is_empty():
		push_error("M1.6 canvas did not receive InteractableObject records for visible hotspots.")
		quit(1)
		return
	if not _canvas_preserves_art_aspect(canvas_snapshot, "live environment canvas"):
		quit(1)
		return
	var click_position := _canvas_local_center_for_object(live_environment_canvas, canvas_object)
	var serialized_before_canvas_click := JSON.stringify(app.call("serialized_run_state"))
	var motion_event := InputEventMouseMotion.new()
	motion_event.position = click_position
	live_environment_canvas.call("_gui_input", motion_event)
	await process_frame
	var hovered_spatial_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	if str(hovered_spatial_snapshot.get("hover_target_id", "")) != focus_object_id:
		push_error("M1.6 hovering a canvas hotspot did not update UI-local hover state.")
		quit(1)
		return
	if serialized_before_canvas_click != JSON.stringify(app.call("serialized_run_state")):
		push_error("M1.6 hovering a canvas hotspot mutated serialized RunState.")
		quit(1)
		return
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = click_position
	live_environment_canvas.call("_gui_input", click_event)
	await process_frame
	var clicked_spatial_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	if str(clicked_spatial_snapshot.get("selected_object_id", "")) != focus_object_id:
		push_error("M1.6 clicking a canvas hotspot did not update UI-local selection state.")
		quit(1)
		return
	var clicked_canvas_snapshot: Dictionary = live_environment_canvas.call("current_view_snapshot")
	var selected_info: Dictionary = clicked_canvas_snapshot.get("selected_info", {})
	var selected_info_lines: Array = selected_info.get("lines", [])
	if not bool(selected_info.get("visible", false)) or str(selected_info.get("object_id", "")) != focus_object_id:
		push_error("M1.6 selected canvas hotspot did not expose an in-scene description card.")
		quit(1)
		return
	if str(selected_info.get("title", "")).strip_edges().is_empty() and selected_info_lines.is_empty():
		push_error("M1.6 selected canvas hotspot description card was empty.")
		quit(1)
		return
	if not _selected_info_text_fits(live_environment_canvas, "selected canvas hotspot"):
		quit(1)
		return
	if serialized_before_canvas_click != JSON.stringify(app.call("serialized_run_state")):
		push_error("M1.6 clicking a canvas hotspot mutated serialized RunState.")
		quit(1)
		return
	if str(first_interactable.get("object_type", "")) == "game":
		if not bool(selected_info.get("action_available", false)) or str(selected_info.get("action_label", "")).strip_edges().is_empty():
			push_error("M1.6 selected canvas hotspot did not expose an info-card action button.")
			quit(1)
			return
		var info_button_position: Vector2 = live_environment_canvas.call("local_position_for_selected_info_action_button")
		if info_button_position.x < 0.0 or info_button_position.y < 0.0:
			push_error("M1.6 selected canvas hotspot action button did not expose a valid click position.")
			quit(1)
			return
		var serialized_before_info_button := JSON.stringify(app.call("serialized_run_state"))
		var info_button_click := InputEventMouseButton.new()
		info_button_click.button_index = MOUSE_BUTTON_LEFT
		info_button_click.pressed = true
		info_button_click.position = info_button_position
		live_environment_canvas.call("_gui_input", info_button_click)
		await process_frame
		if str(app.call("current_screen_snapshot").get("screen", "")) != "GAME":
			push_error("M1.6 selected info-card action button did not activate the selected object.")
			quit(1)
			return
		if serialized_before_info_button != JSON.stringify(app.call("serialized_run_state")):
			push_error("M1.6 selected info-card game activation mutated serialized RunState.")
			quit(1)
			return
		app.call("back_to_environment")
		await process_frame
		live_environment_canvas = app.get("environment_canvas")
	var blank_position := _blank_canvas_position(live_environment_canvas)
	if blank_position.x < 0.0:
		push_error("M1.6 could not find a blank environment canvas area for room-reset verification.")
		quit(1)
		return
	var blank_click_event := InputEventMouseButton.new()
	blank_click_event.button_index = MOUSE_BUTTON_LEFT
	blank_click_event.pressed = true
	blank_click_event.position = blank_position
	live_environment_canvas.call("_gui_input", blank_click_event)
	await process_frame
	var blank_spatial_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	if str(blank_spatial_snapshot.get("current_context_mode", "")) != "room" or not str(blank_spatial_snapshot.get("selected_object_id", "")).is_empty():
		push_error("M1.6 clicking blank environment space did not return to room presentation state.")
		quit(1)
		return
	var blank_canvas_snapshot: Dictionary = live_environment_canvas.call("current_view_snapshot")
	if bool(blank_canvas_snapshot.get("camera_focus_active", true)) or float(blank_canvas_snapshot.get("target_camera_zoom", 0.0)) != 1.0:
		push_error("M1.6 clicking blank environment space did not restore the full-room camera target.")
		quit(1)
		return
	var blank_selected_info: Dictionary = blank_canvas_snapshot.get("selected_info", {})
	if bool(blank_selected_info.get("visible", false)):
		push_error("M1.6 clicking blank environment space left an object description card visible.")
		quit(1)
		return
	if serialized_before_canvas_click != JSON.stringify(app.call("serialized_run_state")):
		push_error("M1.6 clicking blank environment space mutated serialized RunState.")
		quit(1)
		return
	var title_label: Label = app.get("title_label")
	var summary_label: Label = app.get("summary_label")
	var status_label: Label = app.get("status_label")
	var objective_label: Label = app.get("objective_label")
	var actions_list: Control = app.get("actions_list")
	var action_panel_container: Control = app.get("action_panel_container")
	if title_label == null or title_label.text.strip_edges().is_empty():
		push_error("M1.5 environment layout did not show a visible venue title.")
		quit(1)
		return
	if status_label == null or status_label.text.find("Bankroll") == -1 or status_label.text.find("Risk:") == -1:
		push_error("M1.5 top HUD did not show bankroll and risk cue.")
		quit(1)
		return
	if objective_label == null or objective_label.text.find("Goal:") == -1 or objective_label.text.find("Cash:") == -1 or objective_label.text.find("Heat:") == -1 or objective_label.text.find("Next:") == -1:
		push_error("M2-FUN objective HUD did not explain goal, cash, heat, and next opportunity.")
		quit(1)
		return
	if not _control_fits_viewport(objective_label, viewport_rect, "objective HUD"):
		quit(1)
		return
	var objective_snapshot: Dictionary = app.call("current_objective_hud_snapshot")
	if str(objective_snapshot.get("text", "")) != objective_label.text:
		push_error("M2-FUN objective HUD snapshot did not match visible objective text.")
		quit(1)
		return
	var run_hud_snapshot: Dictionary = app.call("current_run_status_hud_snapshot")
	for field in ["status_text", "objective_text", "save_text", "bankroll_text", "heat_text", "heat_meter", "debt_text", "environment_text", "inventory_text", "run_text", "goal_text"]:
		if str(run_hud_snapshot.get(field, "")).strip_edges().is_empty():
			push_error("R100 dynamic run-status HUD is missing field: %s." % field)
			quit(1)
			return
	if status_label.text.find("[$]") == -1 or status_label.text.find("[HEAT]") == -1 or status_label.text.find("[DEBT]") == -1 or status_label.text.find("[RUN]") == -1:
		push_error("R100 dynamic run-status HUD did not show compact bankroll, heat, debt, and run indicators.")
		quit(1)
		return
	if objective_label.text.find("[GOAL]") == -1 or objective_label.text.find("[ENV]") == -1 or objective_label.text.find("[GEAR]") == -1:
		push_error("R100 dynamic run-status HUD did not show objective, environment, and inventory indicators.")
		quit(1)
		return
	if str(run_hud_snapshot.get("heat_meter", "")).find("[") == -1 or str(run_hud_snapshot.get("heat_meter", "")).find("]") == -1:
		push_error("R100 dynamic run-status HUD did not expose a heat meter.")
		quit(1)
		return
	var save_status_label: Label = app.get("save_status_label")
	if save_status_label == null or save_status_label.text.find("[AUTO]") == -1:
		push_error("R100 dynamic run-status HUD did not show autosave status as a compact indicator.")
		quit(1)
		return
	for forbidden_hud_text in ["serialized", "foundation", "contract", "module", "_"]:
		if status_label.text.findn(forbidden_hud_text) != -1 or objective_label.text.findn(forbidden_hud_text) != -1 or save_status_label.text.findn(forbidden_hud_text) != -1:
			push_error("R100 dynamic run-status HUD exposes technical text: %s." % forbidden_hud_text)
			quit(1)
			return
	if action_panel_container == null or action_panel_container.visible or action_panel_container.is_visible_in_tree():
		push_error("World-first UI still shows the old room-object/game-surface side panel.")
		quit(1)
		return
	if _has_visible_text(app, "What can I do?") or _has_visible_text(app, "Use the machine"):
		push_error("R100 UI still exposes the old side-box labels as normal play requirements.")
		quit(1)
		return
	var initial_consequence_panel := app.get("consequence_panel") as Control
	if initial_consequence_panel == null:
		push_error("R100 UI did not expose the compact consequence panel.")
		quit(1)
		return
	if initial_consequence_panel.visible or _has_visible_text(app, "What just happened") or _has_visible_text(app, "Recent consequence"):
		push_error("R100 UI shows an empty consequence panel before the player has a result.")
		quit(1)
		return
	var initial_game_prompt: Dictionary = app.call("current_game_view_snapshot")
	if str(initial_game_prompt.get("display_name", "")) == "No game selected":
		push_error("M1.5 game surface still uses the dead-end 'No game selected' copy.")
		quit(1)
		return
	if summary_label == null or summary_label.text.find("double-click glowing props to act") == -1:
		push_error("World-first environment summary did not prompt the player to inspect and act through room objects.")
		quit(1)
		return
	var initial_environment_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var initial_game_ids: Array = initial_environment_snapshot.get("game_ids", [])
	if initial_game_ids.is_empty():
		push_error("M1.5 first environment layout test needs visible game choices.")
		quit(1)
		return
	var first_game_definition: Dictionary = app.get("library").game(str(initial_game_ids[0]))
	var first_game_name := str(first_game_definition.get("display_name", ""))
	if first_game_name.is_empty() or _interactable_by_type(app.call("current_spatial_interaction_snapshot").get("objects", []), "game").is_empty():
		push_error("World-first environment did not expose the first available game as a room object.")
		quit(1)
		return
	if not _check_final_demo_objective_hud_matrix(app):
		quit(1)
		return
	if not await _check_in_run_menu_flow(app, save_service, viewport_rect):
		quit(1)
		return
	if not await _check_run_journal_flow(app, save_service, viewport_rect):
		quit(1)
		return
	app.call("start_foundation_run", "UI-COMPILE-SEED")
	await process_frame
	var category_snapshot: Dictionary = app.call("current_action_category_snapshot")
	var categories: Array = category_snapshot.get("categories", [])
	var required_categories := [
		{"id": "games", "title": "Games", "screen": "ENVIRONMENT"},
		{"id": "events", "title": "Events", "screen": "EVENT"},
		{"id": "items", "title": "Items", "screen": "ITEMS"},
		{"id": "travel", "title": "Travel", "screen": "TRAVEL"},
	]
	for required in required_categories:
		var category := _category_by_id(categories, str(required.get("id", "")))
		if category.is_empty():
			push_error("M1.5 action category is missing: %s." % str(required.get("title", "")))
			quit(1)
			return
		if str(category.get("description", "")).is_empty() or not category.has("enabled") or not category.has("empty_text"):
			push_error("M1.5 action category lacks description, enabled state, or empty-state copy: %s." % str(required.get("title", "")))
			quit(1)
			return
	var serialized_before_category_clicks := JSON.stringify(app.call("serialized_run_state"))
	for required in required_categories:
		if not bool(app.call("select_action_category", str(required.get("id", "")))):
			push_error("M1.6 compatibility category could not route context: %s." % str(required.get("title", "")))
			quit(1)
			return
		await process_frame
		if serialized_before_category_clicks != JSON.stringify(app.call("serialized_run_state")):
			push_error("Routing an M1.6 context category mutated serialized RunState: %s." % str(required.get("title", "")))
			quit(1)
			return
		var selected_screen: Dictionary = app.call("current_screen_snapshot")
		if str(selected_screen.get("screen", "")) != str(required.get("screen", "")):
			push_error("Foundation screen router did not match selected category: %s." % str(required.get("title", "")))
			quit(1)
			return
	if not (initial_environment_snapshot.get("travel_choices", []) as Array).is_empty():
		app.call("select_action_category", "travel")
		await process_frame
		if _interactable_by_type(app.call("current_spatial_interaction_snapshot").get("objects", []), "travel").is_empty():
			push_error("World-first Travel category did not expose travel choices as room objects.")
			quit(1)
			return
	app.call("select_action_category", "games")
	await process_frame
	await process_frame
	var game_focus_snapshot: Dictionary = (app.get("environment_canvas") as Control).call("current_view_snapshot")
	var game_focus_info: Dictionary = game_focus_snapshot.get("selected_info", {})
	if bool(game_focus_info.get("visible", false)) and not _selected_info_text_fits(app.get("environment_canvas"), "game object info"):
		quit(1)
		return
	if layout_serialized_before != JSON.stringify(app.call("serialized_run_state")):
		push_error("M1.5 layout-only inspection mutated serialized RunState.")
		quit(1)
		return

	app.call("clear_interaction_focus")
	await process_frame
	var first_seed_environment := JSON.stringify(app.call("current_environment_view_snapshot"))
	app.call("start_foundation_run", "UI-COMPILE-SEED")
	await process_frame
	var same_seed_environment := JSON.stringify(app.call("current_environment_view_snapshot"))
	if first_seed_environment != same_seed_environment:
		push_error("Starting the same seed did not produce the same first environment.")
		quit(1)
		return
	app.call("start_foundation_run", "UI-COMPILE-OTHER-SEED")
	await process_frame
	var different_seed_environment := JSON.stringify(app.call("current_environment_view_snapshot"))
	if same_seed_environment == different_seed_environment:
		push_error("Starting a different seed did not change the deterministic first environment.")
		quit(1)
		return
	var custom_challenge := RunStateScript.custom_challenge("ui_compile_variant", "UI-COMPILE-SEED", {"variant": "m1_01"})
	app.call("start_foundation_run", "UI-COMPILE-SEED", custom_challenge)
	await process_frame
	var challenge_seed_value := int(app.get("run_state").seed_value)
	app.call("start_foundation_run", "UI-COMPILE-SEED")
	await process_frame
	if challenge_seed_value == int(app.get("run_state").seed_value):
		push_error("Custom challenge config did not alter the deterministic run seed.")
		quit(1)
		return

	var environment_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var environment_canvas: Control = PixelSceneCanvasScript.new()
	environment_canvas.call("render_environment_snapshot", environment_snapshot)
	root.add_child(environment_canvas)
	await process_frame
	if not bool(environment_canvas.get("uses_foundation_snapshot")):
		push_error("Environment canvas did not render from a foundation snapshot.")
		quit(1)
		return
	environment_canvas.call("render_environment_snapshot", {
		"id": "classic_drunk_room",
		"display_name": "Classic Drunk Room",
		"drunk_level": 35,
		"drunk_effect_mode": "classic",
		"interactable_objects": [],
	})
	await process_frame
	var classic_environment_snapshot: Dictionary = environment_canvas.call("current_view_snapshot")
	if str(classic_environment_snapshot.get("drunk_effect_mode", "")) != "classic" or bool(classic_environment_snapshot.get("drunk_distortion_visible", true)):
		push_error("Classic drunk visual mode should disable the wavy distortion overlay on environment canvases.")
		quit(1)
		return
	environment_canvas.size = Vector2(VisualStyleScript.ENVIRONMENT_BOARD_SIZE)
	environment_canvas.call("render_environment_snapshot", {
		"id": "distortion_drunk_room",
		"display_name": "Distortion Drunk Room",
		"drunk_level": 70,
		"drunk_effect_mode": "distortion",
		"interactable_objects": [{
			"object_id": "service:test_readable_drink",
			"object_type": "service",
			"visual_type": "drink",
			"source_id": "test_readable_drink",
			"label": "Readable Drink",
			"enabled": true,
			"normalized_rect": {"x": 0.45, "y": 0.42, "w": 0.10, "h": 0.16},
		}],
	})
	environment_canvas.call("set_selected_object", "service:test_readable_drink")
	await process_frame
	var distortion_environment_snapshot: Dictionary = environment_canvas.call("current_view_snapshot")
	var environment_distortion_debug: Dictionary = distortion_environment_snapshot.get("drunk_distortion_debug", {})
	if not bool(distortion_environment_snapshot.get("drunk_distortion_visible", false)):
		push_error("Distortion drunk visual mode should enable the wavy overlay on environment canvases.")
		quit(1)
		return
	if absf(float(environment_distortion_debug.get("global_distortion_scale", 0.0)) - 0.80) > 0.001:
		push_error("Environment drunk distortion did not apply the toned-down global strength.")
		quit(1)
		return
	if absf(float(environment_distortion_debug.get("ui_distortion_scale", 0.0)) - (1.0 / 3.0)) > 0.001:
		push_error("Environment drunk distortion did not apply the reduced readable-UI strength.")
		quit(1)
		return
	if int(environment_distortion_debug.get("ui_protected_rect_count", 0)) <= 0:
		push_error("Environment drunk distortion did not protect readable UI regions.")
		quit(1)
		return
	environment_canvas.call("render_environment_snapshot", {
		"id": "reduced_motion_drunk_room",
		"display_name": "Reduced Motion Drunk Room",
		"drunk_level": 70,
		"drunk_effect_mode": "distortion",
		"reduce_motion": true,
		"interactable_objects": [],
	})
	await process_frame
	var reduced_motion_environment_snapshot: Dictionary = environment_canvas.call("current_view_snapshot")
	var reduced_motion_debug: Dictionary = reduced_motion_environment_snapshot.get("drunk_distortion_debug", {})
	if not bool(reduced_motion_environment_snapshot.get("reduce_motion", false)) or bool(reduced_motion_environment_snapshot.get("drunk_distortion_visible", true)) or not bool(reduced_motion_debug.get("reduce_motion", false)):
		push_error("Reduced motion should disable wavy drunk distortion on environment canvases.")
		quit(1)
		return
	environment_canvas.call("render_environment_snapshot", environment_snapshot)
	await process_frame
	var reduced_motion_game_canvas: Control = GameSurfaceCanvasScript.new()
	root.add_child(reduced_motion_game_canvas)
	reduced_motion_game_canvas.call("render_game_snapshot", {
		"game_id": "reduced_motion_surface",
		"reduce_motion": true,
		"surface_animation_channels": [{
			"id": "test_channel",
			"active_id": "animating",
			"active": true,
			"duration_msec": 5000,
		}],
	})
	await process_frame
	var reduced_motion_game_snapshot: Dictionary = reduced_motion_game_canvas.call("current_view_snapshot")
	var reduced_motion_animations: Dictionary = reduced_motion_game_snapshot.get("surface_animations", {})
	var reduced_motion_channel: Dictionary = reduced_motion_animations.get("test_channel", {})
	if not bool(reduced_motion_game_snapshot.get("reduce_motion", false)) or bool(reduced_motion_channel.get("active", true)) or float(reduced_motion_channel.get("progress", 0.0)) < 1.0:
		push_error("Reduced motion should complete game-surface animation channels immediately.")
		quit(1)
		return
	var duplicate_input_canvas: Control = PixelSceneCanvasScript.new()
	duplicate_input_canvas.size = Vector2(VisualStyleScript.ENVIRONMENT_BOARD_SIZE)
	root.add_child(duplicate_input_canvas)
	duplicate_input_canvas.call("render_environment_snapshot", {
		"id": "duplicate_input_room",
		"display_name": "Duplicate Input Room",
		"interactable_objects": [{
			"object_id": "service:test_drink",
			"object_type": "service",
			"visual_type": "drink",
			"source_id": "test_drink",
			"label": "Test Drink",
			"enabled": true,
			"normalized_rect": {"x": 0.45, "y": 0.42, "w": 0.10, "h": 0.16},
		}],
	})
	await process_frame
	var activation_counter := {"count": 0}
	duplicate_input_canvas.object_activated.connect(func(_object_id: String) -> void:
		activation_counter["count"] = int(activation_counter.get("count", 0)) + 1
	)
	var duplicate_click_position := Vector2(
		float(VisualStyleScript.ENVIRONMENT_BOARD_SIZE.x) * 0.50,
		float(VisualStyleScript.ENVIRONMENT_BOARD_SIZE.y) * 0.50
	)
	var duplicate_mouse_event := InputEventMouseButton.new()
	duplicate_mouse_event.button_index = MOUSE_BUTTON_LEFT
	duplicate_mouse_event.pressed = true
	duplicate_mouse_event.double_click = true
	duplicate_mouse_event.position = duplicate_click_position
	duplicate_input_canvas.call("_gui_input", duplicate_mouse_event)
	var duplicate_touch_event := InputEventScreenTouch.new()
	duplicate_touch_event.pressed = true
	duplicate_touch_event.double_tap = true
	duplicate_touch_event.position = duplicate_click_position
	duplicate_input_canvas.call("_gui_input", duplicate_touch_event)
	await process_frame
	if int(activation_counter.get("count", 0)) != 1:
		push_error("Environment canvas applied both mouse and emulated-touch activation for one object.")
		quit(1)
		return
	duplicate_input_canvas.queue_free()

	var serialized_before_selection := JSON.stringify(app.call("serialized_run_state"))
	app.call("select_environment_view_object", 0)
	await process_frame
	var serialized_after_selection := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_selection != serialized_after_selection:
		push_error("UI-local environment selection changed serialized RunState.")
		quit(1)
		return

	var serialized_before_game_entry := JSON.stringify(app.call("serialized_run_state"))
	app.call("enter_first_available_game")
	await process_frame
	if serialized_before_game_entry != JSON.stringify(app.call("serialized_run_state")):
		push_error("Entering a game panel mutated serialized RunState before action resolution.")
		quit(1)
		return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "GAME":
		push_error("Foundation screen router did not move to GAME after entering a game.")
		quit(1)
		return
	var focused_environment_canvas: Control = app.get("environment_canvas")
	var focused_game_surface: Control = app.get("game_surface_canvas")
	if focused_game_surface == null or not focused_game_surface.visible:
		push_error("M1.6B game mode did not make the game surface visible.")
		quit(1)
		return
	if focused_environment_canvas != null and focused_environment_canvas.visible:
		push_error("M1.6B game mode left the environment canvas competing with the game surface.")
		quit(1)
		return
	if focused_game_surface.size.y < 260.0:
		push_error("M1.6B game mode did not enlarge the game surface enough to be primary.")
		quit(1)
		return
	if not _control_fits_viewport(status_label, viewport_rect, "game-mode HUD status"):
		quit(1)
		return
	if not _control_fits_viewport(objective_label, viewport_rect, "game-mode objective HUD"):
		quit(1)
		return
	if not _control_fits_viewport(app.get("save_status_label"), viewport_rect, "game-mode save status"):
		quit(1)
		return
	if not _control_fits_viewport(focused_game_surface, viewport_rect, "focused game surface"):
		quit(1)
		return
	var focused_game_surface_snapshot: Dictionary = focused_game_surface.call("current_view_snapshot")
	if not _canvas_preserves_art_aspect(focused_game_surface_snapshot, "focused game surface"):
		quit(1)
		return
	var surface_back_position: Vector2 = focused_game_surface.call("local_position_for_surface_action", "surface_back", -1)
	if surface_back_position.x < 0.0 or surface_back_position.y < 0.0:
		push_error("World-first game surface did not expose a visible back-to-environment hit region.")
		quit(1)
		return
	var serialized_before_back := JSON.stringify(app.call("serialized_run_state"))
	var surface_back_event := InputEventMouseButton.new()
	surface_back_event.button_index = MOUSE_BUTTON_LEFT
	surface_back_event.pressed = true
	surface_back_event.position = surface_back_position
	focused_game_surface.call("_gui_input", surface_back_event)
	await process_frame
	if serialized_before_back != JSON.stringify(app.call("serialized_run_state")):
		push_error("Surface back to environment mutated serialized RunState.")
		quit(1)
		return
	var backed_out_game_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if str(backed_out_game_snapshot.get("display_name", "")) != "Choose a game":
		push_error("Back to environment did not return the game panel to the game-choice prompt.")
		quit(1)
		return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "ENVIRONMENT":
		push_error("Foundation screen router did not return to ENVIRONMENT after backing out of a game.")
		quit(1)
		return
	if focused_environment_canvas != null and not focused_environment_canvas.visible:
		push_error("M1.6B Back to environment did not restore the full environment canvas.")
		quit(1)
		return
	if focused_game_surface != null and focused_game_surface.visible:
		push_error("M1.6B Back to environment left the game surface visible in room mode.")
		quit(1)
		return
	app.call("enter_first_available_game")
	await process_frame
	var game_snapshot_before: Dictionary = app.call("current_game_view_snapshot")
	var legal_actions: Array = game_snapshot_before.get("legal_actions", [])
	if legal_actions.is_empty():
		push_error("Foundation game did not expose selectable legal actions.")
		quit(1)
		return
	var cheat_actions: Array = game_snapshot_before.get("cheat_actions", [])
	if cheat_actions.is_empty():
		push_error("Foundation game did not expose selectable cheat/advantage actions.")
		quit(1)
		return
	var game_surface_rect := focused_game_surface.get_global_rect()
	if action_panel_container != null and action_panel_container.is_visible_in_tree():
		push_error("World-first game mode still shows the old game-surface side panel.")
		quit(1)
		return
	if game_surface_rect.size.x * game_surface_rect.size.y < viewport_rect.size.x * viewport_rect.size.y * 0.35:
		push_error("World-first game surface is not large enough to carry normal play: surface %s viewport %s." % [str(game_surface_rect), str(viewport_rect)])
		quit(1)
		return
	var legal_action_label := _qa_action_label(legal_actions[0] as Dictionary)
	var cheat_action_label := _qa_action_label(cheat_actions[0] as Dictionary)
	if not bool(game_snapshot_before.get("has_valid_stake", false)):
		push_error("Foundation game did not expose a valid stake range.")
		quit(1)
		return
	var min_stake := int(game_snapshot_before.get("stake_min", 0))
	var max_stake := int(game_snapshot_before.get("stake_max", 0))
	if min_stake <= 0 or max_stake < min_stake:
		push_error("Foundation game stake range is invalid.")
		quit(1)
		return
	if int(game_snapshot_before.get("selected_stake", 0)) != min_stake:
		push_error("Foundation UI did not default to the minimum valid stake.")
		quit(1)
		return
	var serialized_before_surface_sweep := JSON.stringify(app.call("serialized_run_state"))
	var available_game_ids: Array = app.call("current_environment_view_snapshot").get("game_ids", [])
	var presentation_modes := {}
	for available_game_id in available_game_ids:
		app.call("back_to_environment")
		await process_frame
		app.call("enter_game", str(available_game_id))
		await process_frame
		var available_game_snapshot: Dictionary = app.call("current_game_view_snapshot")
		var available_surface_renderer := str(available_game_snapshot.get("surface_renderer", ""))
		if available_surface_renderer.is_empty() or available_surface_renderer == "result":
			push_error("Available foundation game did not choose a distinct presentation surface.")
			quit(1)
			return
		presentation_modes[available_surface_renderer] = true
	if available_game_ids.size() > 1 and presentation_modes.size() < 2:
		push_error("Multiple available foundation games collapsed to one generic presentation surface.")
		quit(1)
		return
	app.call("back_to_environment")
	await process_frame
	app.call("enter_first_available_game")
	await process_frame
	game_snapshot_before = app.call("current_game_view_snapshot")
	if serialized_before_surface_sweep != JSON.stringify(app.call("serialized_run_state")):
		push_error("Sweeping foundation game presentation surfaces mutated serialized RunState.")
		quit(1)
		return

	var game_canvas: Control = GameSurfaceCanvasScript.new()
	game_canvas.call("render_game_snapshot", game_snapshot_before)
	root.add_child(game_canvas)
	await process_frame
	if not bool(game_canvas.get("uses_foundation_snapshot")):
		push_error("Game surface canvas did not render from a foundation snapshot.")
		quit(1)
		return
	var surface_renderer := str(game_snapshot_before.get("surface_renderer", ""))
	if surface_renderer.is_empty() or surface_renderer == "result":
		push_error("Foundation game snapshot did not choose a distinct presentation surface.")
		quit(1)
		return
	var game_canvas_snapshot: Dictionary = game_canvas.call("current_view_snapshot")
	if str(game_canvas_snapshot.get("surface_renderer", "")) != surface_renderer:
		push_error("Game surface canvas did not preserve the requested presentation surface.")
		quit(1)
		return
	var classic_game_snapshot := game_snapshot_before.duplicate(true)
	classic_game_snapshot["drunk_level"] = 35
	classic_game_snapshot["drunk_effect_mode"] = "classic"
	classic_game_snapshot["reduce_motion"] = false
	game_canvas.call("render_game_snapshot", classic_game_snapshot)
	await process_frame
	var classic_game_canvas_snapshot: Dictionary = game_canvas.call("current_view_snapshot")
	if str(classic_game_canvas_snapshot.get("drunk_effect_mode", "")) != "classic" or bool(classic_game_canvas_snapshot.get("drunk_distortion_visible", true)):
		push_error("Classic drunk visual mode should disable the wavy distortion overlay on game surfaces.")
		quit(1)
		return
	var distortion_game_snapshot := game_snapshot_before.duplicate(true)
	distortion_game_snapshot["drunk_level"] = 70
	distortion_game_snapshot["drunk_effect_mode"] = "distortion"
	distortion_game_snapshot["reduce_motion"] = false
	distortion_game_snapshot["surface_ui_protected_regions"] = [{"x": 38, "y": 258, "w": 220, "h": 42}]
	game_canvas.call("render_game_snapshot", distortion_game_snapshot)
	await process_frame
	var distortion_game_canvas_snapshot: Dictionary = game_canvas.call("current_view_snapshot")
	var game_distortion_debug: Dictionary = distortion_game_canvas_snapshot.get("drunk_distortion_debug", {})
	if not bool(distortion_game_canvas_snapshot.get("drunk_distortion_visible", false)):
		push_error("Distortion drunk visual mode should enable the wavy overlay on game surfaces.")
		quit(1)
		return
	if absf(float(game_distortion_debug.get("global_distortion_scale", 0.0)) - 0.80) > 0.001:
		push_error("Game drunk distortion did not apply the toned-down global strength.")
		quit(1)
		return
	if absf(float(game_distortion_debug.get("ui_distortion_scale", 0.0)) - (1.0 / 3.0)) > 0.001:
		push_error("Game drunk distortion did not apply the reduced readable-UI strength.")
		quit(1)
		return
	if int(game_distortion_debug.get("ui_protected_rect_count", 0)) <= 0:
		push_error("Game drunk distortion did not protect readable UI regions.")
		quit(1)
		return
	game_canvas.call("render_game_snapshot", game_snapshot_before)
	await process_frame

	focused_game_surface.queue_redraw()
	await process_frame
	var surface_click_position: Vector2 = focused_game_surface.call("local_position_for_surface_action", "surface_legal", 0)
	if surface_click_position.x < 0.0 or surface_click_position.y < 0.0:
		push_error("M1.6B game surface did not expose a visible legal action hit region.")
		quit(1)
		return
	var serialized_before_surface_selection := JSON.stringify(app.call("serialized_run_state"))
	var surface_click_event := InputEventMouseButton.new()
	surface_click_event.button_index = MOUSE_BUTTON_LEFT
	surface_click_event.pressed = true
	surface_click_event.position = surface_click_position
	focused_game_surface.call("_gui_input", surface_click_event)
	await process_frame
	if serialized_before_surface_selection != JSON.stringify(app.call("serialized_run_state")):
		push_error("M1.6B clicking a game surface action mutated serialized RunState before confirmation.")
		quit(1)
		return
	var surface_selected_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if str(surface_selected_snapshot.get("selected_action_id", "")) != str(legal_actions[0].get("id", "")):
		push_error("M1.6B clicking a game surface action did not update UI-local action selection.")
		quit(1)
		return
	var focused_canvas_snapshot: Dictionary = focused_game_surface.call("current_view_snapshot")
	if int(focused_canvas_snapshot.get("selected_view_index", -1)) < 0:
		push_error("M1.6B game surface did not expose selected surface state after a surface click.")
		quit(1)
		return
	if not _visible_text_fits_viewport(actions_list, "Click the highlighted surface action", viewport_rect, "game-mode surface resolve guidance"):
		quit(1)
		return
	if not _control_fits_viewport(app.get("consequence_cards_scroll"), viewport_rect, "game-mode recent consequence strip"):
		quit(1)
		return

	var legal_action: Dictionary = legal_actions[0]
	var serialized_before_invalid_stake := JSON.stringify(app.call("serialized_run_state"))
	if bool(app.call("set_selected_stake", max_stake + 1)):
		push_error("Foundation UI accepted an invalid stake.")
		quit(1)
		return
	await process_frame
	var serialized_after_invalid_stake := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_invalid_stake != serialized_after_invalid_stake:
		push_error("Invalid stake selection mutated serialized RunState.")
		quit(1)
		return
	var serialized_before_min_stake := JSON.stringify(app.call("serialized_run_state"))
	if not bool(app.call("set_selected_stake", min_stake)):
		push_error("Foundation UI rejected the minimum valid stake.")
		quit(1)
		return
	await process_frame
	var selected_min_stake_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if int(selected_min_stake_snapshot.get("selected_stake", 0)) != min_stake:
		push_error("Foundation UI did not store the selected minimum stake.")
		quit(1)
		return
	var serialized_after_min_stake := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_min_stake != serialized_after_min_stake:
		push_error("Selecting a valid stake mutated serialized RunState.")
		quit(1)
		return
	var serialized_before_legal_selection := JSON.stringify(app.call("serialized_run_state"))
	app.call("select_game_action", str(legal_action.get("id", "")), "legal")
	await process_frame
	var serialized_after_legal_selection := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_legal_selection != serialized_after_legal_selection:
		push_error("Selecting a legal action mutated serialized RunState.")
		quit(1)
		return
	var selected_legal_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if str(selected_legal_snapshot.get("selected_action_id", "")) != str(legal_action.get("id", "")):
		push_error("Foundation UI did not store the selected legal action as UI-local state.")
		quit(1)
		return
	var legal_embeds_outcome := bool(selected_legal_snapshot.get("surface_embeds_outcomes", false)) or bool(selected_legal_snapshot.get("surface_suppresses_game_result_burst", false))
	if str(selected_legal_snapshot.get("selected_action_summary", "")).is_empty() or not _has_visible_text(actions_list, "Click the highlighted surface action"):
		push_error("M1.5 dedicated game panel did not show selected legal action summary and surface resolve guidance.")
		quit(1)
		return
	app.call("resolve_selected_game_action")
	await process_frame
	var serialized_after_action := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_legal_selection == serialized_after_action:
		push_error("Resolving a foundation game action did not update serialized RunState.")
		quit(1)
		return
	var screen_after_legal := str(app.call("current_screen_snapshot").get("screen", ""))
	if (legal_embeds_outcome and screen_after_legal != "GAME") or (not legal_embeds_outcome and screen_after_legal != "RESULT"):
		push_error("Foundation screen router did not move to the expected post-action screen.")
		quit(1)
		return
	var min_result_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if int(min_result_snapshot.get("result_stake", 0)) != min_stake:
		push_error("Foundation game result did not use the selected minimum stake.")
		quit(1)
		return
	var min_bankroll_delta := int(min_result_snapshot.get("bankroll_delta", 0))
	if not legal_embeds_outcome:
		var legal_environment_snapshot: Dictionary = app.call("current_environment_view_snapshot")
		if str(legal_environment_snapshot.get("outcome_message", "")).is_empty() or str(legal_environment_snapshot.get("outcome_object_id", "")).is_empty():
			push_error("Resolved legal action did not create in-scene outcome feedback for the focused object.")
			quit(1)
			return
		var result_environment_canvas: Control = app.get("environment_canvas")
		var live_environment_canvas_snapshot: Dictionary = result_environment_canvas.call("current_view_snapshot")
		if str(live_environment_canvas_snapshot.get("outcome_message", "")).is_empty():
			push_error("Environment canvas did not receive in-scene consequence feedback.")
			quit(1)
			return
		if str(live_environment_canvas_snapshot.get("outcome_anchor", "")) != "environment_panel_top_right" or str(live_environment_canvas_snapshot.get("outcome_interaction_kind", "")) != "informational_result":
			push_error("Environment result feedback was not separated as top-right informational output.")
			quit(1)
			return
		var result_feedback_snapshot: Dictionary = app.call("current_environment_result_feedback_snapshot")
		if str(result_feedback_snapshot.get("anchor", "")) != "environment_panel_top_right" or str(result_feedback_snapshot.get("interaction_kind", "")) != "informational_result":
			push_error("Environment result feedback panel did not expose the top-right informational contract.")
			quit(1)
			return
		var outcome_popup_rect: Dictionary = result_feedback_snapshot.get("popup_rect", {})
		var surface_rect: Dictionary = result_feedback_snapshot.get("surface_rect", {})
		var environment_panel_rect: Dictionary = result_feedback_snapshot.get("panel_rect", {})
		var outcome_right := float(outcome_popup_rect.get("x", 0.0)) + float(outcome_popup_rect.get("w", 0.0))
		var panel_right := float(environment_panel_rect.get("x", 0.0)) + float(environment_panel_rect.get("w", 0.0))
		var outcome_bottom := float(outcome_popup_rect.get("y", 0.0)) + float(outcome_popup_rect.get("h", 0.0))
		var surface_top := float(surface_rect.get("y", 0.0))
		var viewport_top := float(viewport_rect.position.y)
		var popup_left := float(outcome_popup_rect.get("x", 0.0))
		var panel_left := float(environment_panel_rect.get("x", 0.0))
		if outcome_popup_rect.is_empty() or surface_rect.is_empty() or environment_panel_rect.is_empty() or outcome_bottom > surface_top or absf(outcome_right - panel_right) > 24.0 or popup_left < panel_left or float(outcome_popup_rect.get("y", 0.0)) < viewport_top:
			push_error("Environment result feedback was not placed in the top-right HUD band above the environment panel.")
			quit(1)
			return
	if min_bankroll_delta != 0 and status_label.text.find("%+d" % min_bankroll_delta) == -1:
		push_error("Top HUD did not visually emphasize the recent bankroll delta.")
		quit(1)
		return
	var legal_consequence_snapshot: Dictionary = app.call("current_consequence_view_snapshot")
	var legal_consequence_panel := app.get("consequence_panel") as Control
	if legal_consequence_panel == null:
		push_error("Legal action did not expose the consequence data boundary.")
		quit(1)
		return
	if legal_consequence_panel.visible or _has_visible_text(app, "Recent consequence"):
		push_error("Legal action should not consume play space with the old Recent consequence panel.")
		quit(1)
		return
	if int(legal_consequence_snapshot.get("bankroll", 0)) != int(app.call("serialized_run_state").get("bankroll", -1)):
		push_error("Consequence snapshot did not track current bankroll after legal action.")
		quit(1)
		return
	var serialized_before_consequence_view := JSON.stringify(app.call("serialized_run_state"))
	var legal_cards: Array = legal_consequence_snapshot.get("cards", [])
	if _card_by_title(legal_cards, "Play resolved").is_empty():
		push_error("Legal action did not produce a readable consequence outcome card.")
		quit(1)
		return
	if _card_by_title(legal_cards, "Bankroll").is_empty():
		push_error("Legal action consequence cards did not show bankroll change.")
		quit(1)
		return
	if _card_by_title(legal_cards, "Story").is_empty():
		push_error("Legal action consequence cards did not show story/result message.")
		quit(1)
		return
	if _card_by_title(legal_cards, "Next").is_empty():
		push_error("Legal action consequence cards did not suggest next actions.")
		quit(1)
		return
	if _has_visible_text(app, "Play resolved") or _has_visible_text(app, "Recent consequence"):
		push_error("Resolved play leaked old consequence-card text into the normal play layout.")
		quit(1)
		return
	if not _control_fits_viewport(app.get("consequence_cards_scroll"), viewport_rect, "consequence cards scroll after result"):
		quit(1)
		return
	if serialized_before_consequence_view != JSON.stringify(app.call("serialized_run_state")):
		push_error("Displaying legal consequence cards mutated serialized RunState.")
		quit(1)
		return
	if int(legal_consequence_snapshot.get("recent_bankroll_delta", 0)) != min_bankroll_delta:
		push_error("Consequence snapshot did not show the recent legal bankroll delta.")
		quit(1)
		return
	if str(legal_consequence_snapshot.get("recent_result_message", "")).is_empty():
		push_error("Consequence snapshot did not show a recent legal result message.")
		quit(1)
		return
	if not bool(legal_consequence_snapshot.get("travel_available", false)):
		push_error("Consequence snapshot did not show travel availability.")
		quit(1)
		return
	game_canvas.call("render_game_snapshot", app.call("current_game_view_snapshot"))
	await process_frame
	var game_canvas_view: Dictionary = game_canvas.call("current_view_snapshot")
	var game_canvas_state: Dictionary = game_canvas_view.get("state", {})
	if str(game_canvas_state.get("result_message", "")).is_empty():
		push_error("Game surface did not render a foundation game result snapshot.")
		quit(1)
		return
	if str(game_canvas_view.get("outcome_message", "")).is_empty() or int(game_canvas_view.get("outcome_bankroll_delta", 0)) != min_bankroll_delta:
		push_error("Game surface did not expose in-scene result feedback from result-delta data.")
		quit(1)
		return
	if max_stake <= min_stake:
		push_error("Foundation stake validation needs a higher valid stake for the smoke test.")
		quit(1)
		return
	var higher_stake := min_stake + 1
	app.call("start_foundation_run", "UI-COMPILE-SEED")
	await process_frame
	app.call("enter_first_available_game")
	await process_frame
	var higher_snapshot: Dictionary = app.call("current_game_view_snapshot")
	var higher_legal_actions: Array = higher_snapshot.get("legal_actions", [])
	if higher_legal_actions.is_empty():
		push_error("Foundation game did not expose legal actions for higher stake check.")
		quit(1)
		return
	var higher_legal_action: Dictionary = higher_legal_actions[0]
	if bool(higher_snapshot.get("slot_fixed_bet_ladder", false)):
		if not bool(app.call("_handle_module_surface_action", "select_bet_option:bet_5", 0, true)):
			push_error("Foundation slot UI could not select fixed bet_5.")
			quit(1)
			return
		await process_frame
		var fixed_bet_snapshot: Dictionary = app.call("current_game_view_snapshot")
		if str(fixed_bet_snapshot.get("selected_bet_id", "")) != "bet_5" or int(fixed_bet_snapshot.get("selected_bet_total_credits", 0)) != 5:
			push_error("Foundation slot UI did not persist the selected fixed bet_5 option.")
			quit(1)
			return
		var serialized_before_fixed_selection := JSON.stringify(app.call("serialized_run_state"))
		app.call("select_game_action", str(higher_legal_action.get("id", "")), "legal")
		await process_frame
		var serialized_after_fixed_selection := JSON.stringify(app.call("serialized_run_state"))
		if serialized_before_fixed_selection != serialized_after_fixed_selection:
			push_error("Selecting a fixed-bet slot action mutated serialized RunState.")
			quit(1)
			return
		app.call("resolve_selected_game_action")
		await process_frame
		var fixed_result_snapshot: Dictionary = app.call("current_game_view_snapshot")
		if int(fixed_result_snapshot.get("result_stake", fixed_result_snapshot.get("bet_total_credits", 0))) != 5:
			push_error("Foundation slot result did not use selected fixed bet_5 cost.")
			quit(1)
			return
		if int(fixed_result_snapshot.get("bankroll_delta", 0)) == min_bankroll_delta:
			push_error("Fixed bet_5 did not change the deterministic bankroll delta from the minimum bet.")
			quit(1)
			return
	else:
		if not bool(app.call("set_selected_stake", higher_stake)):
			push_error("Foundation UI rejected a higher valid stake.")
			quit(1)
			return
		var serialized_before_higher_selection := JSON.stringify(app.call("serialized_run_state"))
		app.call("select_game_action", str(higher_legal_action.get("id", "")), "legal")
		await process_frame
		var serialized_after_higher_selection := JSON.stringify(app.call("serialized_run_state"))
		if serialized_before_higher_selection != serialized_after_higher_selection:
			push_error("Selecting a higher-stake action mutated serialized RunState.")
			quit(1)
			return
		app.call("resolve_selected_game_action")
		await process_frame
		var higher_result_snapshot: Dictionary = app.call("current_game_view_snapshot")
		if int(higher_result_snapshot.get("result_stake", 0)) != higher_stake:
			push_error("Foundation game result did not use the selected higher stake.")
			quit(1)
			return
		if int(higher_result_snapshot.get("bankroll_delta", 0)) == min_bankroll_delta:
			push_error("Higher valid stake did not change the deterministic bankroll delta.")
			quit(1)
			return

	var cheat_action: Dictionary = cheat_actions[0]
	var serialized_before_cheat_selection := JSON.stringify(app.call("serialized_run_state"))
	app.call("select_game_action", str(cheat_action.get("id", "")), "cheat")
	await process_frame
	var serialized_after_cheat_selection := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_cheat_selection != serialized_after_cheat_selection:
		push_error("Selecting a cheat/advantage action mutated serialized RunState.")
		quit(1)
		return
	var selected_cheat_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if str(selected_cheat_snapshot.get("selected_action_id", "")) != str(cheat_action.get("id", "")):
		push_error("Foundation UI did not store the selected cheat/advantage action as UI-local state.")
		quit(1)
		return
	var cheat_embeds_outcome := bool(selected_cheat_snapshot.get("surface_embeds_outcomes", false)) or bool(selected_cheat_snapshot.get("surface_suppresses_game_result_burst", false))
	if str(selected_cheat_snapshot.get("risk_cue", "")).is_empty() or not _has_visible_text(actions_list, "Click the highlighted surface action"):
		push_error("M1.5 dedicated game panel did not show selected risky action cue and surface resolve guidance.")
		quit(1)
		return
	app.call("resolve_selected_game_action")
	await process_frame
	var serialized_after_cheat_action := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_cheat_selection == serialized_after_cheat_action:
		push_error("Resolving a cheat/advantage action did not update serialized RunState.")
		quit(1)
		return
	var screen_after_cheat := str(app.call("current_screen_snapshot").get("screen", ""))
	if (cheat_embeds_outcome and screen_after_cheat != "GAME") or (not cheat_embeds_outcome and screen_after_cheat != "RESULT"):
		push_error("Foundation screen router did not stay on the expected post-risky-action screen.")
		quit(1)
		return
	var cheat_result_snapshot: Dictionary = app.call("current_game_view_snapshot")
	var cheat_consequence_snapshot: Dictionary = app.call("current_consequence_view_snapshot")
	var cheat_run_state: Dictionary = app.call("serialized_run_state")
	var cheat_suspicion_delta := int(cheat_result_snapshot.get("suspicion_delta", 0))
	if cheat_suspicion_delta != 0 and status_label.text.find("%+d" % cheat_suspicion_delta) == -1:
		push_error("Top HUD did not visually emphasize the recent risk/suspicion delta.")
		quit(1)
		return
	var cheat_cards: Array = cheat_consequence_snapshot.get("cards", [])
	if _card_by_title(cheat_cards, "Risky play resolved").is_empty():
		push_error("Cheat/advantage action did not produce a readable consequence outcome card.")
		quit(1)
		return
	if _card_by_title(cheat_cards, "Risk").is_empty():
		push_error("Cheat/advantage consequence cards did not show risk/suspicion cue.")
		quit(1)
		return
	if _has_visible_text(app, "Risky play resolved") or _has_visible_text(app, "Recent consequence"):
		push_error("Cheat/advantage result leaked old consequence-card text into the normal play layout.")
		quit(1)
		return
	if int(cheat_consequence_snapshot.get("suspicion_level", -1)) != int(cheat_run_state.get("suspicion", {}).get("level", -2)):
		push_error("Consequence snapshot did not track current suspicion after cheat action.")
		quit(1)
		return
	if int(cheat_consequence_snapshot.get("recent_suspicion_delta", 0)) != int(cheat_result_snapshot.get("suspicion_delta", 0)):
		push_error("Consequence snapshot did not show the recent cheat suspicion delta.")
		quit(1)
		return
	if (cheat_consequence_snapshot.get("suspicion_cues", []) as Array).is_empty() and (cheat_consequence_snapshot.get("security_cues", []) as Array).is_empty():
		push_error("Consequence snapshot did not expose suspicion or security cues.")
		quit(1)
		return
	var save_ux_state: Dictionary = app.call("serialized_run_state")
	var save_status_before: Dictionary = app.call("save_status_snapshot")
	if str(save_status_before.get("status_text", "")).is_empty():
		push_error("Save status text should be visible before saving.")
		quit(1)
		return
	var save_path := str(save_status_before.get("save_path", ""))
	if save_path.find("beat_the_house_demo_save") != -1:
		push_error("Foundation save status referenced the demo save path.")
		quit(1)
		return
	app.call("save_foundation_run")
	await process_frame
	var save_status_after: Dictionary = app.call("save_status_snapshot")
	if not bool(save_status_after.get("has_save", false)) or not bool(save_status_after.get("load_available", false)):
		push_error("Saving did not make the foundation Continue/Load state available.")
		quit(1)
		return
	if str(save_status_after.get("status_text", "")).find("Saved") == -1:
		push_error("Save status did not report a saved foundation run.")
		quit(1)
		return
	var save_objects := _interactable_by_type(app.call("current_spatial_interaction_snapshot").get("objects", []), "save")
	var load_objects := _interactable_by_type(app.call("current_spatial_interaction_snapshot").get("objects", []), "load")
	if not save_objects.is_empty() or not load_objects.is_empty():
		push_error("Save/load should not appear as room objects; runs autosave and Continue loads from the main menu.")
		quit(1)
		return
	var saved_visible_environment := str(app.call("current_environment_view_snapshot").get("display_name", ""))
	var saved_game_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if str(saved_game_snapshot.get("result_message", "")).is_empty():
		push_error("Saved active game state did not expose a visible game summary.")
		quit(1)
		return
	app.call("return_to_main_menu")
	await process_frame
	var menu_continue: Button = app.get("continue_button")
	if menu_continue == null or menu_continue.disabled:
		push_error("Autosaved run was not available through the main menu Continue button.")
		quit(1)
		return
	menu_continue.emit_signal("pressed")
	await process_frame
	var loaded_save_ux_state: Dictionary = app.call("serialized_run_state")
	if int(loaded_save_ux_state.get("bankroll", 0)) != int(save_ux_state.get("bankroll", -1)):
		push_error("Load did not restore visible bankroll.")
		quit(1)
		return
	var saved_suspicion: Dictionary = save_ux_state.get("suspicion", {})
	var loaded_suspicion: Dictionary = loaded_save_ux_state.get("suspicion", {})
	if int(loaded_suspicion.get("level", -1)) != int(saved_suspicion.get("level", -2)):
		push_error("Load did not restore visible suspicion level.")
		quit(1)
		return
	if (loaded_suspicion.get("cues", []) as Array).size() != (saved_suspicion.get("cues", []) as Array).size():
		push_error("Load did not restore suspicion cue state.")
		quit(1)
		return
	if JSON.stringify(loaded_save_ux_state.get("narrative_flags", {})) != JSON.stringify(save_ux_state.get("narrative_flags", {})):
		push_error("Load did not restore flags.")
		quit(1)
		return
	if JSON.stringify(loaded_save_ux_state.get("story_log", [])) != JSON.stringify(save_ux_state.get("story_log", [])):
		push_error("Load did not restore story state.")
		quit(1)
		return
	var saved_environment: Dictionary = save_ux_state.get("current_environment", {})
	var loaded_environment: Dictionary = loaded_save_ux_state.get("current_environment", {})
	if str(loaded_environment.get("id", "")) != str(saved_environment.get("id", "")) or str(app.call("current_environment_view_snapshot").get("display_name", "")) != saved_visible_environment:
		push_error("Load did not restore the visible environment.")
		quit(1)
		return
	if JSON.stringify(loaded_environment.get("travel_hooks", [])) != JSON.stringify(saved_environment.get("travel_hooks", [])) or JSON.stringify(loaded_environment.get("next_archetypes", [])) != JSON.stringify(saved_environment.get("next_archetypes", [])):
		push_error("Load did not restore travel state.")
		quit(1)
		return
	var loaded_game_summary: Dictionary = app.call("current_game_view_snapshot")
	if str(loaded_game_summary.get("summary_source", "")) != "saved_story_log" or str(loaded_game_summary.get("result_message", "")).is_empty():
		push_error("Load did not restore a visible saved game state summary.")
		quit(1)
		return
	var loaded_consequence_snapshot: Dictionary = app.call("current_consequence_view_snapshot")
	if int(loaded_consequence_snapshot.get("bankroll", 0)) != int(save_ux_state.get("bankroll", -1)):
		push_error("Consequence panel did not restore bankroll after load.")
		quit(1)
		return
	if (loaded_consequence_snapshot.get("cards", []) as Array).is_empty():
		push_error("Load did not restore coherent consequence cards from saved run state/story.")
		quit(1)
		return
	if int(loaded_consequence_snapshot.get("suspicion_level", -1)) != int(saved_suspicion.get("level", -2)):
		push_error("Consequence panel did not restore suspicion after load.")
		quit(1)
		return
	if (loaded_consequence_snapshot.get("story_messages", []) as Array).is_empty():
		push_error("Consequence panel did not restore story messages after load.")
		quit(1)
		return
	if not bool(loaded_consequence_snapshot.get("travel_available", false)):
		push_error("Consequence panel did not restore travel availability after load.")
		quit(1)
		return
	var loaded_save_status: Dictionary = app.call("save_status_snapshot")
	if str(loaded_save_status.get("status_text", "")).find("Loaded") == -1:
		push_error("Load status did not report the loaded foundation run.")
		quit(1)
		return
	if int(loaded_save_status.get("visible_bankroll", -1)) != int(loaded_save_ux_state.get("bankroll", -2)):
		push_error("Save/load status did not restore visible bankroll summary.")
		quit(1)
		return
	if str(loaded_save_status.get("visible_environment", "")) != saved_visible_environment:
		push_error("Save/load status did not restore visible environment summary.")
		quit(1)
		return
	if str(loaded_save_status.get("visible_risk", "")).is_empty() or str(loaded_save_status.get("visible_story", "")).is_empty() or str(loaded_save_status.get("visible_travel", "")).is_empty():
		push_error("Save/load status did not expose restored risk, story, and travel summaries.")
		quit(1)
		return
	var event_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var event_options: Array = event_snapshot.get("event_options", [])
	if event_options.is_empty():
		var event_seeds := [
			"UI-EVENT-SEED",
			"UI-EVENT-SEED-2",
			"UI-EVENT-SEED-3",
			"UI-EVENT-SEED-4",
			"UI-EVENT-SEED-5",
			"UI-EVENT-SEED-6",
			"UI-EVENT-SEED-7",
			"UI-EVENT-SEED-8",
		]
		for event_seed in event_seeds:
			app.call("start_foundation_run", event_seed)
			await process_frame
			event_snapshot = app.call("current_environment_view_snapshot")
			event_options = event_snapshot.get("event_options", [])
			if not event_options.is_empty():
				break
	if event_options.is_empty():
		push_error("Foundation UI did not expose an eligible event option.")
		quit(1)
		return
	var event_option: Dictionary = event_options[0]
	var event_id := str(event_option.get("id", ""))
	var event_choices: Array = event_option.get("choices", [])
	if event_choices.is_empty():
		push_error("Foundation UI did not expose event choices.")
		quit(1)
		return
	var event_definition: Dictionary = app.get("library").event(event_id)
	var event_module := EventModuleScript.new()
	event_module.setup(event_definition)
	if event_choices.size() != event_module.choices().size():
		push_error("Foundation UI did not show all currently valid event choices.")
		quit(1)
		return
	var serialized_before_event_category := JSON.stringify(app.call("serialized_run_state"))
	app.call("select_action_category", "events")
	await process_frame
	if serialized_before_event_category != JSON.stringify(app.call("serialized_run_state")):
		push_error("Selecting the Events card category mutated serialized RunState.")
		quit(1)
		return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "EVENT":
		push_error("Foundation screen router did not move to EVENT for event cards.")
		quit(1)
		return
	if not _has_visible_text(actions_list, str(event_option.get("display_name", ""))):
		push_error("Event card did not show the eligible event title.")
		quit(1)
		return
	var event_choice: Dictionary = event_choices[0]
	var event_choice_id := str(event_choice.get("id", ""))
	if not _has_visible_text(actions_list, str(event_choice.get("label", ""))):
		push_error("Event card did not show the available event choice.")
		quit(1)
		return
	if str(event_choice.get("text", "")).is_empty() or str(event_choice.get("consequence_summary", "")).is_empty():
		push_error("Event choices did not expose player-facing text and impact summaries.")
		quit(1)
		return
	if str(event_choice.get("identity_summary", "")).find("Choice ID:") == -1 or str(event_choice.get("impact_summary", "")).is_empty():
		push_error("Event choices did not expose normalized choice identity and impact metadata.")
		quit(1)
		return
	var serialized_before_event_selection := JSON.stringify(app.call("serialized_run_state"))
	if not bool(app.call("select_event_choice", event_id, event_choice_id)):
		push_error("Foundation UI rejected an eligible event choice.")
		quit(1)
		return
	await process_frame
	var serialized_after_event_selection := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_event_selection != serialized_after_event_selection:
		push_error("Selecting an event choice mutated serialized RunState.")
		quit(1)
		return
	if not _selected_info_text_fits(app.get("environment_canvas"), "event object info", ["Choices / impact:", "Risk:"]):
		quit(1)
		return
	var event_canvas_snapshot: Dictionary = (app.get("environment_canvas") as Control).call("current_view_snapshot")
	if _canvas_has_object_type(event_canvas_snapshot.get("objects", []), "event_choice"):
		push_error("Selecting an event should not create separate environment response-choice objects.")
		quit(1)
		return
	if _canvas_object_id_with_prefix(event_canvas_snapshot.get("objects", []), "event_choice:"):
		push_error("Selecting an event created legacy event_choice object ids.")
		quit(1)
		return
	var event_selected_info: Dictionary = event_canvas_snapshot.get("selected_info", {})
	var event_info_actions: Array = event_selected_info.get("actions", [])
	if event_info_actions.is_empty():
		push_error("Expanded event card did not expose inline response actions on the canvas.")
		quit(1)
		return
	var first_event_info_action: Dictionary = event_info_actions[0]
	var first_event_info_detail := str(first_event_info_action.get("detail", ""))
	var expected_event_action_id := "event_response:%s:%s" % [event_id, event_choice_id]
	if str(first_event_info_action.get("label", "")) != str(event_choice.get("label", "")):
		push_error("Expanded event card did not show the choice label in the selected canvas info tab.")
		quit(1)
		return
	if first_event_info_detail.find(str(event_choice.get("text", ""))) == -1 or first_event_info_detail.find(str(event_choice.get("consequence_summary", ""))) == -1:
		push_error("Expanded event card did not show choice text and impact as inline subtext.")
		quit(1)
		return
	if str(first_event_info_action.get("emit_object_id", "")) != expected_event_action_id:
		push_error("Expanded event card did not route the response through an inline event action id.")
		quit(1)
		return
	var selected_event_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	if str(selected_event_snapshot.get("selected_event_id", "")) != event_id or str(selected_event_snapshot.get("selected_event_choice_id", "")) != event_choice_id:
		push_error("Foundation UI did not store selected event choice as UI-local state.")
		quit(1)
		return
	for object_value in selected_event_snapshot.get("interactable_objects", []):
		if typeof(object_value) == TYPE_DICTIONARY and str((object_value as Dictionary).get("object_id", "")).begins_with("event_response:"):
			push_error("Selecting an event choice created a separate event response room object.")
			quit(1)
			return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "EVENT":
		push_error("Foundation screen router left EVENT during event choice selection.")
		quit(1)
		return
	var serialized_before_event_activation := JSON.stringify(app.call("serialized_run_state"))
	if not bool(app.call("activate_interactable_object", "event:%s" % event_id)):
		push_error("Foundation UI did not activate a visible event object.")
		quit(1)
		return
	await process_frame
	var popup_snapshot: Dictionary = app.call("current_event_choice_popup_snapshot")
	if bool(popup_snapshot.get("visible", false)) or bool(popup_snapshot.get("blocking", false)):
		push_error("Activating an event should keep responses inline instead of opening a blocking popup.")
		quit(1)
		return
	if serialized_before_event_activation != JSON.stringify(app.call("serialized_run_state")):
		push_error("Activating an event object mutated serialized RunState.")
		quit(1)
		return
	var serialized_before_event_resolve := JSON.stringify(app.call("serialized_run_state"))
	var event_response_position: Vector2 = (app.get("environment_canvas") as Control).call("local_position_for_selected_info_action_button")
	if event_response_position.x < 0.0 or event_response_position.y < 0.0:
		push_error("Expanded event card did not expose a valid canvas click position for the response option.")
		quit(1)
		return
	var event_response_click := InputEventMouseButton.new()
	event_response_click.button_index = MOUSE_BUTTON_LEFT
	event_response_click.pressed = true
	event_response_click.position = event_response_position
	(app.get("environment_canvas") as Control).call("_gui_input", event_response_click)
	await process_frame
	var event_run_state: Dictionary = app.call("serialized_run_state")
	if JSON.stringify(event_run_state) == serialized_before_event_resolve:
		push_error("Resolving an event choice did not update serialized RunState.")
		quit(1)
		return
	if bool(app.call("current_event_choice_popup_snapshot").get("visible", true)):
		push_error("Event choice popup did not close after resolving a choice.")
		quit(1)
		return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "RESULT":
		push_error("Foundation screen router did not move to RESULT after resolving an event.")
		quit(1)
		return
	var resolved_events: Array = event_run_state.get("current_environment", {}).get("resolved_event_ids", [])
	if not resolved_events.has(event_id):
		push_error("Resolved event was not recorded in RunState.")
		quit(1)
		return
	var event_story_log: Array = event_run_state.get("story_log", [])
	if event_story_log.is_empty() or str((event_story_log[event_story_log.size() - 1] as Dictionary).get("type", "")) != "event":
		push_error("Event resolution did not record an event story entry.")
		quit(1)
		return
	app.call("save_foundation_run")
	app.call("load_foundation_run")
	await process_frame
	var loaded_event_run_state: Dictionary = app.call("serialized_run_state")
	if JSON.stringify(loaded_event_run_state.get("story_log", [])) != JSON.stringify(event_run_state.get("story_log", [])):
		push_error("Event story result did not survive SaveService save/load.")
		quit(1)
		return
	if JSON.stringify(loaded_event_run_state.get("current_environment", {}).get("resolved_event_ids", [])) != JSON.stringify(resolved_events):
		push_error("Resolved event state did not survive SaveService save/load.")
		quit(1)
		return

	app.call("start_foundation_run", "UI-ITEM-SEED")
	await process_frame
	var item_start_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var item_travel_choices: Array = item_start_snapshot.get("travel_choices", [])
	if item_travel_choices.is_empty():
		push_error("Foundation item-offer setup did not expose travel toward item offers.")
		quit(1)
		return
	var item_travel_target_id := str((item_travel_choices[0] as Dictionary).get("id", ""))
	app.call("select_travel_option", item_travel_target_id)
	app.call("confirm_selected_travel")
	await process_frame
	var item_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var item_offers: Array = item_snapshot.get("item_offers", [])
	if item_offers.is_empty():
		push_error("Foundation UI did not expose generated item offers.")
		quit(1)
		return
	var item_offer: Dictionary = item_offers[0]
	var item_id := str(item_offer.get("id", ""))
	var item_price := int(item_offer.get("price", -1))
	if item_id.is_empty() or item_price < 0:
		push_error("Foundation item offer view data is missing id or price.")
		quit(1)
		return
	if str(item_offer.get("effect_summary", "")).is_empty():
		push_error("Foundation item offer did not expose an effect summary from data.")
		quit(1)
		return
	var item_asset_path := str(item_offer.get("asset_path", ""))
	if item_asset_path.is_empty() or not ResourceLoader.exists(item_asset_path):
		push_error("Foundation item offer did not expose a valid item icon asset path.")
		quit(1)
		return
	var item_canvas_snapshot: Dictionary = (app.get("environment_canvas") as Control).call("current_view_snapshot")
	var item_canvas_object := _canvas_object_by_id(item_canvas_snapshot.get("objects", []), "item:%s" % item_id)
	if item_canvas_object.is_empty() or str(item_canvas_object.get("asset_path", "")) != item_asset_path:
		push_error("Environment item holder did not receive the item's icon asset path.")
		quit(1)
		return
	var shopkeeper_interactable := _interactable_by_type(app.call("current_spatial_interaction_snapshot").get("objects", []), "shopkeeper")
	if shopkeeper_interactable.is_empty():
		push_error("Item-selling environment did not expose a shopkeeper object.")
		quit(1)
		return
	if not bool(app.call("activate_interactable_object", str(shopkeeper_interactable.get("object_id", "")))):
		push_error("Shopkeeper object could not be activated.")
		quit(1)
		return
	await process_frame
	var shopkeeper_sale_popup: Dictionary = app.call("current_run_inventory_snapshot")
	if not bool(shopkeeper_sale_popup.get("visible", false)) or str(shopkeeper_sale_popup.get("mode", "")) != "merchant_sale" or not bool(shopkeeper_sale_popup.get("merchant_available", false)):
		push_error("Shopkeeper did not open the merchant sell page directly.")
		quit(1)
		return
	if str(shopkeeper_sale_popup.get("anchor", "")) != "screen_center" or str(shopkeeper_sale_popup.get("interaction_kind", "")) != "merchant_sale":
		push_error("Shopkeeper sell page did not use the centered shared popup format.")
		quit(1)
		return
	app.call("close_run_inventory")
	await process_frame
	var item_environment: Dictionary = app.call("serialized_run_state").get("current_environment", {})
	var generated_item_layout: Dictionary = item_environment.get("layout", {})
	var generated_object_rects: Dictionary = generated_item_layout.get("object_rects", {})
	if not generated_object_rects.has("item:%s" % item_id):
		push_error("Generated environment layout did not persist item object placement by item id.")
		quit(1)
		return
	var item_archetype := _archetype_by_id(app.get("library"), str(item_environment.get("archetype_id", "")))
	var item_layout: Dictionary = item_archetype.get("layout", {})
	var item_spots: Array = item_layout.get("item_spots", [])
	if item_spots.is_empty():
		push_error("Foundation item-offer map does not define item_spots for authored placement.")
		quit(1)
		return
	if not _canvas_object_position_matches_board_spot(item_canvas_object, item_spots[0]):
		push_error("Environment item holder ignored the archetype item_spots authored placement.")
		quit(1)
		return
	var serialized_before_item_category := JSON.stringify(app.call("serialized_run_state"))
	app.call("select_action_category", "items")
	await process_frame
	if serialized_before_item_category != JSON.stringify(app.call("serialized_run_state")):
		push_error("Selecting the Items card category mutated serialized RunState.")
		quit(1)
		return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "ITEMS":
		push_error("Foundation screen router did not move to ITEMS for item cards.")
		quit(1)
		return
	if not _has_visible_text(actions_list, str(item_offer.get("display_name", ""))) or not _has_visible_text(actions_list, "Cost:") or not _has_visible_text(actions_list, "Effect:"):
		push_error("Item card did not show title, cost, and effect summary.")
		quit(1)
		return
	var serialized_before_item_selection := JSON.stringify(app.call("serialized_run_state"))
	if not bool(app.call("select_item_offer", item_id)):
		push_error("Foundation UI rejected an available item offer.")
		quit(1)
		return
	await process_frame
	var serialized_after_item_selection := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_item_selection != serialized_after_item_selection:
		push_error("Selecting an item offer mutated serialized RunState.")
		quit(1)
		return
	var selected_item_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	if str(selected_item_snapshot.get("selected_item_offer_id", "")) != item_id:
		push_error("Foundation UI did not store selected item offer as UI-local state.")
		quit(1)
		return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "ITEMS":
		push_error("Foundation screen router left ITEMS during item offer selection.")
		quit(1)
		return
	if not _has_visible_text(actions_list, "Buy / apply"):
		push_error("Item card did not show a buy/apply action after selection.")
		quit(1)
		return
	var item_canvas_after_selection: Dictionary = (app.get("environment_canvas") as Control).call("current_view_snapshot")
	if not _canvas_surviving_object_positions_match(item_canvas_snapshot.get("objects", []), item_canvas_after_selection.get("objects", []), ""):
		push_error("Selecting an item offer reflowed environment objects.")
		quit(1)
		return
	if not _selected_info_text_fits(app.get("environment_canvas"), "shop item object info", ["Cost:", "Effect:"]):
		quit(1)
		return
	var item_run_state: RunState = app.get("run_state")
	var original_item_bankroll := item_run_state.bankroll
	if original_item_bankroll <= item_price:
		push_error("Foundation item-offer test setup unexpectedly cannot afford the selected offer.")
		quit(1)
		return
	item_run_state.change_bankroll((item_price - 1) - item_run_state.bankroll)
	var serialized_before_unaffordable_item := JSON.stringify(app.call("serialized_run_state"))
	if bool(app.call("confirm_selected_item_offer")):
		push_error("Foundation UI allowed an unaffordable item purchase.")
		quit(1)
		return
	await process_frame
	var serialized_after_unaffordable_item := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_unaffordable_item != serialized_after_unaffordable_item:
		push_error("Unaffordable item purchase mutated serialized RunState.")
		quit(1)
		return
	item_run_state.change_bankroll(original_item_bankroll - item_run_state.bankroll)
	var item_canvas_before_purchase: Dictionary = (app.get("environment_canvas") as Control).call("current_view_snapshot")
	var serialized_before_item_purchase: Dictionary = app.call("serialized_run_state")
	if not bool(app.call("confirm_selected_item_offer")):
		push_error("Foundation UI rejected an affordable item purchase.")
		quit(1)
		return
	await process_frame
	if str(app.call("current_screen_snapshot").get("screen", "")) != "RESULT":
		push_error("Foundation screen router did not move to RESULT after item purchase.")
		quit(1)
		return
	var purchased_item_state: Dictionary = app.call("serialized_run_state")
	var purchased_item_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var item_canvas_after_purchase: Dictionary = (app.get("environment_canvas") as Control).call("current_view_snapshot")
	if not _canvas_surviving_object_positions_match(item_canvas_before_purchase.get("objects", []), item_canvas_after_purchase.get("objects", []), "item:%s" % item_id):
		push_error("Item purchase reflowed surviving environment objects instead of only removing the bought item.")
		quit(1)
		return
	var item_result: Dictionary = purchased_item_snapshot.get("last_item_result", {})
	if str(item_result.get("type", "")) != "item_effect" or str(item_result.get("item_effect_id", "")) != item_id:
		push_error("Item purchase did not resolve through the ItemEffect result path.")
		quit(1)
		return
	var item_result_deltas: Dictionary = item_result.get("deltas", {})
	var item_result_effect: Dictionary = item_result.get("effect", {})
	var expected_item_bankroll_delta := int(item_result_effect.get("bankroll_delta", 0)) - item_price
	if int(item_result_deltas.get("bankroll_delta", 0)) != expected_item_bankroll_delta:
		push_error("Item purchase did not include the expected cost delta.")
		quit(1)
		return
	if int(purchased_item_state.get("bankroll", 0)) != int(serialized_before_item_purchase.get("bankroll", 0)) + expected_item_bankroll_delta:
		push_error("Affordable item purchase did not update bankroll as expected.")
		quit(1)
		return
	var purchased_inventory: Array = purchased_item_state.get("inventory", [])
	if not purchased_inventory.has(item_id):
		push_error("Affordable item purchase did not add the item to RunState inventory.")
		quit(1)
		return
	var item_consequence_snapshot: Dictionary = app.call("current_consequence_view_snapshot")
	if (item_consequence_snapshot.get("inventory_items", []) as Array).is_empty() or str(item_consequence_snapshot.get("inventory_summary", "")) == "empty":
		push_error("Consequence panel did not show current inventory after item purchase.")
		quit(1)
		return
	app.call("open_run_inventory")
	await process_frame
	var run_inventory_snapshot: Dictionary = app.call("current_run_inventory_snapshot")
	if not bool(run_inventory_snapshot.get("visible", false)) or str(run_inventory_snapshot.get("mode", "")) != "inspect":
		push_error("Run inventory button did not open the inspect inventory view.")
		quit(1)
		return
	if str(run_inventory_snapshot.get("anchor", "")) != "screen_center" or str(run_inventory_snapshot.get("interaction_kind", "")) != "inventory":
		push_error("Run inventory did not use the centered shared popup format.")
		quit(1)
		return
	var run_inventory_items: Array = run_inventory_snapshot.get("items", [])
	if run_inventory_items.is_empty():
		push_error("Run inventory view did not expose purchased inventory items.")
		quit(1)
		return
	var purchased_inventory_item: Dictionary = run_inventory_items[0]
	if str(purchased_inventory_item.get("id", "")) != item_id or str(purchased_inventory_item.get("display_name", "")).is_empty() or str(purchased_inventory_item.get("item_type", "")).is_empty() or str(purchased_inventory_item.get("domain", "")).is_empty():
		push_error("Run inventory item details did not identify id, display name, type, and domain.")
		quit(1)
		return
	if str(purchased_inventory_item.get("effect_summary", "")).is_empty() or int(purchased_inventory_item.get("sale_price", -1)) < 0 or not bool(purchased_inventory_item.get("sellable", false)):
		push_error("Run inventory item details did not expose effect, sale price, and sellable status.")
		quit(1)
		return
	app.call("close_run_inventory")
	await process_frame
	for remaining_offer in purchased_item_state.get("current_environment", {}).get("item_offers", []):
		if typeof(remaining_offer) == TYPE_DICTIONARY and str((remaining_offer as Dictionary).get("id", "")) == item_id:
			push_error("Purchased item offer was not removed from the environment.")
			quit(1)
			return
	var item_story_log: Array = purchased_item_state.get("story_log", [])
	if item_story_log.is_empty() or str((item_story_log[item_story_log.size() - 1] as Dictionary).get("type", "")) != "item_purchase":
		push_error("Item purchase did not record a serializable story entry.")
		quit(1)
		return
	app.call("save_foundation_run")
	app.call("load_foundation_run")
	await process_frame
	var loaded_item_state: Dictionary = app.call("serialized_run_state")
	if JSON.stringify(loaded_item_state.get("inventory", [])) != JSON.stringify(purchased_item_state.get("inventory", [])):
		push_error("Item purchase inventory state did not survive SaveService save/load.")
		quit(1)
		return
	if int(loaded_item_state.get("bankroll", 0)) != int(purchased_item_state.get("bankroll", 0)):
		push_error("Item purchase bankroll state did not survive SaveService save/load.")
		quit(1)
		return
	var loaded_item_story_log: Array = loaded_item_state.get("story_log", [])
	if loaded_item_story_log.is_empty():
		push_error("Item purchase story state did not survive SaveService save/load.")
		quit(1)
		return
	var loaded_item_story_entry: Dictionary = loaded_item_story_log[loaded_item_story_log.size() - 1]
	if str(loaded_item_story_entry.get("type", "")) != "item_purchase" or str(loaded_item_story_entry.get("item_id", "")) != item_id or int(loaded_item_story_entry.get("price", -1)) != item_price:
		push_error("Loaded item purchase story entry did not preserve purchase details.")
		quit(1)
		return
	if not bool(app.call("open_shopkeeper_sale_page")):
		push_error("Shopkeeper sale page could not be opened in an item-selling environment.")
		quit(1)
		return
	await process_frame
	var sale_inventory_snapshot: Dictionary = app.call("current_run_inventory_snapshot")
	if not bool(sale_inventory_snapshot.get("visible", false)) or str(sale_inventory_snapshot.get("mode", "")) != "merchant_sale" or not bool(sale_inventory_snapshot.get("merchant_available", false)):
		push_error("Shopkeeper sale page did not open merchant sale mode.")
		quit(1)
		return
	if str(sale_inventory_snapshot.get("anchor", "")) != "screen_center" or str(sale_inventory_snapshot.get("interaction_kind", "")) != "merchant_sale":
		push_error("Shopkeeper sale page did not use the centered shared popup format.")
		quit(1)
		return
	var sale_items: Array = sale_inventory_snapshot.get("items", [])
	if sale_items.is_empty():
		push_error("Shopkeeper sale page did not show sellable inventory.")
		quit(1)
		return
	var sale_item: Dictionary = sale_items[0]
	var sale_item_id := str(sale_item.get("id", ""))
	var sale_price := int(sale_item.get("sale_price", -1))
	if sale_item_id.is_empty() or sale_price < 0 or not bool(sale_item.get("sellable", false)):
		push_error("Shopkeeper sale page did not expose sellable item details and sale price.")
		quit(1)
		return
	var serialized_before_item_sale: Dictionary = app.call("serialized_run_state")
	if not bool(app.call("sell_inventory_item", sale_item_id)):
		push_error("Shopkeeper rejected a sellable inventory item.")
		quit(1)
		return
	await process_frame
	var sold_item_state: Dictionary = app.call("serialized_run_state")
	if (sold_item_state.get("inventory", []) as Array).has(sale_item_id):
		push_error("Selling an item did not remove it from RunState inventory.")
		quit(1)
		return
	if int(sold_item_state.get("bankroll", 0)) != int(serialized_before_item_sale.get("bankroll", 0)) + sale_price:
		push_error("Selling an item did not add the expected sale price to bankroll.")
		quit(1)
		return
	var sold_item_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var sale_result: Dictionary = sold_item_snapshot.get("last_item_result", {})
	if str(sale_result.get("type", "")) != "item_sale" or str(sale_result.get("item_id", "")) != sale_item_id:
		push_error("Item sale did not report through the item_sale result path.")
		quit(1)
		return
	var sale_story_log: Array = sold_item_state.get("story_log", [])
	if sale_story_log.is_empty() or str((sale_story_log[sale_story_log.size() - 1] as Dictionary).get("type", "")) != "item_sale":
		push_error("Item sale did not record a serializable story entry.")
		quit(1)
		return
	app.call("save_foundation_run")
	app.call("load_foundation_run")
	await process_frame
	var loaded_sale_state: Dictionary = app.call("serialized_run_state")
	if JSON.stringify(loaded_sale_state.get("inventory", [])) != JSON.stringify(sold_item_state.get("inventory", [])) or int(loaded_sale_state.get("bankroll", 0)) != int(sold_item_state.get("bankroll", 0)):
		push_error("Item sale state did not survive SaveService save/load.")
		quit(1)
		return

	var hook_run_state: RunState = app.get("run_state")
	var hook_library: ContentLibrary = app.get("library")
	hook_library.services = [{
		"id": "fixture_ui_service",
		"display_name": "Fixture Service",
		"description": "A contract fixture service resolved through result deltas.",
		"deltas": {
			"bankroll_delta": 3,
			"flags_set": {"fixture_ui_service_used": true},
		},
	}]
	hook_run_state.current_environment["service_ids"] = ["fixture_ui_service"]
	hook_run_state.current_environment["lender_hooks"] = ["fixture_missing_lender"]
	var hook_spatial_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	var service_interactable := _interactable_by_type(hook_spatial_snapshot.get("objects", []), "service")
	var lender_interactable := _interactable_by_type(hook_spatial_snapshot.get("objects", []), "lender")
	if service_interactable.is_empty() or lender_interactable.is_empty():
		push_error("M1.6 spatial model did not expose service and lender hooks as interactable objects.")
		quit(1)
		return
	app.call("focus_interactable_object", str(service_interactable.get("object_id", "")))
	await process_frame
	if not _has_visible_text(actions_list, "Fixture Service"):
		push_error("Focused service context did not show the supported service hook.")
		quit(1)
		return
	app.call("focus_interactable_object", str(lender_interactable.get("object_id", "")))
	await process_frame
	if not _has_visible_text(actions_list, "Not usable yet") and not _has_visible_text(actions_list, "Not available here yet"):
		push_error("Focused lender context did not show unsupported lender status in player-facing language.")
		quit(1)
		return
	var service_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var service_options: Array = service_snapshot.get("service_options", [])
	if service_options.is_empty():
		push_error("Foundation UI did not expose service hooks when present.")
		quit(1)
		return
	var service_option: Dictionary = service_options[0]
	var service_id := str(service_option.get("id", ""))
	if service_id.is_empty() or not bool(service_option.get("mutation_supported", false)):
		push_error("Foundation UI did not recognize a result-delta service hook.")
		quit(1)
		return
	var serialized_before_service_selection := JSON.stringify(app.call("serialized_run_state"))
	if not bool(app.call("select_service_hook", service_id)):
		push_error("Foundation UI rejected an available service hook.")
		quit(1)
		return
	await process_frame
	var serialized_after_service_selection := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_service_selection != serialized_after_service_selection:
		push_error("Selecting a service hook mutated serialized RunState.")
		quit(1)
		return
	if not bool(app.call("confirm_selected_service_hook")):
		push_error("Foundation UI rejected a supported service hook result.")
		quit(1)
		return
	await process_frame
	var service_result_state: Dictionary = app.call("serialized_run_state")
	if not bool(service_result_state.get("flags", service_result_state.get("narrative_flags", {})).get("fixture_ui_service_used", false)):
		push_error("Supported service hook did not apply flags through result-delta.")
		quit(1)
		return
	var service_result_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var service_result: Dictionary = service_result_snapshot.get("last_hook_result", {})
	if str(service_result.get("type", "")) != "service_hook" or str(service_result.get("source_id", "")) != service_id:
		push_error("Supported service hook did not report a foundation hook result.")
		quit(1)
		return

	var lender_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var lender_options: Array = lender_snapshot.get("lender_options", [])
	if lender_options.is_empty():
		push_error("Foundation UI did not expose lender hooks when present.")
		quit(1)
		return
	var unsupported_lender: Dictionary = lender_options[0]
	var unsupported_lender_id := str(unsupported_lender.get("id", ""))
	if bool(unsupported_lender.get("mutation_supported", true)):
		push_error("Missing lender definition should remain display-only.")
		quit(1)
		return
	var serialized_before_unsupported_lender := JSON.stringify(app.call("serialized_run_state"))
	if not bool(app.call("select_lender_hook", unsupported_lender_id)):
		push_error("Foundation UI rejected a display-only lender hook.")
		quit(1)
		return
	await process_frame
	if bool(app.call("confirm_selected_lender_hook")):
		push_error("Foundation UI allowed an unsupported lender hook to mutate.")
		quit(1)
		return
	await process_frame
	var serialized_after_unsupported_lender := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_unsupported_lender != serialized_after_unsupported_lender:
		push_error("Unsupported lender hook mutated serialized RunState.")
		quit(1)
		return

	hook_library.lenders = [{
		"id": "fixture_ui_lender",
		"display_name": "Fixture Lender",
		"description": "A contract fixture lender resolved through debt_changes.",
		"deltas": {
			"debt_changes": [{"id": "fixture_ui_debt", "lender_id": "fixture_ui_lender", "balance": 12, "status": "active"}],
		},
	}]
	hook_run_state.current_environment["lender_hooks"] = ["fixture_ui_lender"]
	var supported_lender_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var supported_lenders: Array = supported_lender_snapshot.get("lender_options", [])
	if supported_lenders.is_empty() or not bool((supported_lenders[0] as Dictionary).get("mutation_supported", false)):
		push_error("Foundation UI did not recognize a result-delta lender hook.")
		quit(1)
		return
	var lender_id := str((supported_lenders[0] as Dictionary).get("id", ""))
	var debt_count_before_lender := hook_run_state.debt.size()
	var serialized_before_lender_selection := JSON.stringify(app.call("serialized_run_state"))
	if not bool(app.call("select_lender_hook", lender_id)):
		push_error("Foundation UI rejected an available lender hook.")
		quit(1)
		return
	await process_frame
	var serialized_after_lender_selection := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_lender_selection != serialized_after_lender_selection:
		push_error("Selecting a lender hook mutated serialized RunState.")
		quit(1)
		return
	if not bool(app.call("confirm_selected_lender_hook")):
		push_error("Foundation UI rejected a supported lender hook result.")
		quit(1)
		return
	await process_frame
	var lender_result_state: Dictionary = app.call("serialized_run_state")
	if (lender_result_state.get("debt", []) as Array).size() != debt_count_before_lender + 1:
		push_error("Supported lender hook did not apply debt through result-delta.")
		quit(1)
		return
	var lender_consequence_snapshot: Dictionary = app.call("current_consequence_view_snapshot")
	if (lender_consequence_snapshot.get("debt_items", []) as Array).is_empty() or str(lender_consequence_snapshot.get("debt_summary", "")) == "none":
		push_error("Consequence panel did not show current debt after lender hook.")
		quit(1)
		return
	app.call("save_foundation_run")
	app.call("load_foundation_run")
	await process_frame
	var loaded_hook_state: Dictionary = app.call("serialized_run_state")
	if JSON.stringify(loaded_hook_state.get("debt", [])) != JSON.stringify(lender_result_state.get("debt", [])):
		push_error("Supported lender hook result did not survive SaveService save/load.")
		quit(1)
		return
	if not bool(loaded_hook_state.get("narrative_flags", {}).get("fixture_ui_service_used", false)):
		push_error("Supported service hook result did not survive SaveService save/load.")
		quit(1)
		return

	var loaded_environment_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var travel_choices: Array = loaded_environment_snapshot.get("travel_choices", [])
	if travel_choices.is_empty():
		push_error("Foundation UI did not expose travel choices when travel was available.")
		quit(1)
		return
	var travel_choice: Dictionary = travel_choices[0]
	var travel_target_id := str(travel_choice.get("id", ""))
	var serialized_before_travel_category := JSON.stringify(app.call("serialized_run_state"))
	app.call("select_action_category", "travel")
	await process_frame
	if serialized_before_travel_category != JSON.stringify(app.call("serialized_run_state")):
		push_error("Selecting the Travel card category mutated serialized RunState.")
		quit(1)
		return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "TRAVEL":
		push_error("Foundation screen router did not move to TRAVEL for travel cards.")
		quit(1)
		return
	if not _has_visible_text(actions_list, str(travel_choice.get("label", ""))):
		push_error("Travel card did not show the destination label.")
		quit(1)
		return
	var serialized_before_travel_selection := JSON.stringify(app.call("serialized_run_state"))
	if not bool(app.call("select_travel_option", travel_target_id)):
		push_error("Foundation UI rejected an available travel choice.")
		quit(1)
		return
	await process_frame
	var serialized_after_travel_selection := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_travel_selection != serialized_after_travel_selection:
		push_error("Selecting travel mutated serialized RunState before confirmation.")
		quit(1)
		return
	var selected_travel_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	if str(selected_travel_snapshot.get("selected_travel_target_id", "")) != travel_target_id:
		push_error("Foundation UI did not store selected travel as UI-local state.")
		quit(1)
		return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "TRAVEL":
		push_error("Foundation screen router left TRAVEL during destination selection.")
		quit(1)
		return
	if not _has_visible_text(actions_list, "Travel to"):
		push_error("Travel card did not show a travel/leave confirmation action after selection.")
		quit(1)
		return
	app.call("confirm_selected_travel")
	await process_frame
	if app.get("run_state") == null:
		push_error("Foundation UI shell did not keep an active RunState.")
		quit(1)
		return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "RESULT":
		push_error("Foundation screen router did not move to RESULT after travel confirmation.")
		quit(1)
		return
	var post_travel_spatial_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	if not str(post_travel_spatial_snapshot.get("selected_object_id", "")).is_empty():
		push_error("Foundation travel kept the previous room object selected after changing environments.")
		quit(1)
		return
	var traveled_environment: Dictionary = app.call("serialized_run_state").get("current_environment", {})
	if str(traveled_environment.get("archetype_id", "")) != travel_target_id:
		push_error("Selected travel target did not determine the generated environment.")
		quit(1)
		return
	var story_log: Array = app.call("serialized_run_state").get("story_log", [])
	if story_log.is_empty() or str((story_log[story_log.size() - 1] as Dictionary).get("type", "")) != "travel":
		push_error("Foundation travel did not record a travel story entry.")
		quit(1)
		return
	app.call("start_foundation_run", "UI-TRAVEL-SEED")
	await process_frame
	var deterministic_choices_a: Array = app.call("current_environment_view_snapshot").get("travel_choices", [])
	if deterministic_choices_a.is_empty():
		push_error("Foundation deterministic travel check did not expose choices.")
		quit(1)
		return
	var deterministic_target_id := str((deterministic_choices_a[0] as Dictionary).get("id", ""))
	app.call("select_travel_option", deterministic_target_id)
	app.call("confirm_selected_travel")
	await process_frame
	var deterministic_environment_a := JSON.stringify(app.call("current_environment_view_snapshot"))
	app.call("start_foundation_run", "UI-TRAVEL-SEED")
	await process_frame
	app.call("select_travel_option", deterministic_target_id)
	app.call("confirm_selected_travel")
	await process_frame
	var deterministic_environment_b := JSON.stringify(app.call("current_environment_view_snapshot"))
	if deterministic_environment_a != deterministic_environment_b:
		push_error("Same seed/state/travel choice did not generate deterministic travel.")
		quit(1)
		return
	app.call("start_foundation_run", "UI-COMPILE-SEED")
	await process_frame
	app.call("enter_first_available_game")
	await process_frame
	if str(app.call("current_screen_snapshot").get("screen", "")) != "GAME":
		push_error("Failure screen check could not enter a game first.")
		quit(1)
		return
	var failure_fixture_run: RunState = app.get("run_state")
	failure_fixture_run.add_suspicion("ui_failure_screen:police", 100, "behavior", true, {"environment_id": str(failure_fixture_run.current_environment.get("id", ""))})
	app.call("_refresh")
	await process_frame
	var failure_screen_snapshot: Dictionary = app.call("current_screen_snapshot")
	if str(failure_screen_snapshot.get("screen", "")) != "FAILURE":
		push_error("Failed run did not route to the dedicated FAILURE screen.")
		quit(1)
		return
	if bool(failure_screen_snapshot.get("has_game", true)):
		push_error("Failure inside a game did not clear the active game surface.")
		quit(1)
		return
	var failure_panel: Control = app.get("failure_summary_panel")
	if failure_panel == null or not failure_panel.visible:
		push_error("Dedicated failure summary panel was not visible.")
		quit(1)
		return
	if (app.get("game_surface_canvas") as Control).visible:
		push_error("Game surface remained visible over the failure summary.")
		quit(1)
		return
	var failure_summary: Dictionary = app.call("current_failure_summary_snapshot")
	if str(failure_summary.get("reason", "")) != RunState.FAILURE_POLICE_CAPTURE:
		push_error("Failure summary did not preserve the RunState failure reason.")
		quit(1)
		return
	if str(failure_summary.get("current_environment", "")).is_empty() or (failure_summary.get("story_lines", []) as Array).is_empty() or (failure_summary.get("travel_lines", []) as Array).is_empty():
		push_error("Failure summary did not include environment, travel, and story context.")
		quit(1)
		return
	if not _has_visible_text(app, "Captured by police") or not _has_visible_text(app, "Money And Heat"):
		push_error("Failure screen did not present player-facing fail reason and run details.")
		quit(1)
		return
	var failure_reason_cases := [
		{"reason": RunState.FAILURE_BANKROLL_ZERO, "label": "Bankroll zero"},
		{"reason": RunState.FAILURE_STRANDED, "label": "Stranded"},
		{"reason": RunState.FAILURE_POLICE_CAPTURE, "label": "Police capture"},
		{"reason": RunState.FAILURE_CASINO_TAKEN_OUT_BACK, "label": "Casino taken out back"},
	]
	for reason_case in failure_reason_cases:
		var reason_data: Dictionary = reason_case
		app.call("start_foundation_run", "UI-FAILURE-%s" % str(reason_data.get("reason", "")))
		await process_frame
		var reason_fixture_run: RunState = app.get("run_state")
		var reason := str(reason_data.get("reason", ""))
		reason_fixture_run.fail_run(reason, "")
		app.call("_refresh")
		await process_frame
		var reason_screen_snapshot: Dictionary = app.call("current_screen_snapshot")
		var reason_summary: Dictionary = app.call("current_failure_summary_snapshot")
		if str(reason_screen_snapshot.get("screen", "")) != "FAILURE":
			push_error("Failure reason %s did not route to the FAILURE screen." % reason)
			quit(1)
			return
		var expected_reason_label := str(reason_data.get("label", "")).to_lower()
		var actual_reason_label := str(reason_summary.get("reason_label", "")).to_lower()
		if str(reason_summary.get("reason", "")) != reason or actual_reason_label != expected_reason_label:
			push_error("Failure summary did not distinguish reason %s." % reason)
			quit(1)
			return
	app.call("start_foundation_run", "UI-VICTORY-SEED")
	await process_frame
	app.call("enter_first_available_game")
	await process_frame
	if str(app.call("current_screen_snapshot").get("screen", "")) != "GAME":
		push_error("Victory screen check could not enter a game first.")
		quit(1)
		return
	var victory_fixture_run: RunState = app.get("run_state")
	victory_fixture_run.bankroll = 540
	victory_fixture_run.add_suspicion("ui_victory_heat", 18, "behavior", true, {"environment_id": str(victory_fixture_run.current_environment.get("id", ""))})
	victory_fixture_run.log_story({
		"type": "demo_victory",
		"objective_id": "grand_casino_demo_bankroll",
		"environment_id": str(victory_fixture_run.current_environment.get("id", "")),
		"bankroll": victory_fixture_run.bankroll,
		"message": "The host issues you a Grand Casino Players Card and lets you leave with your winnings.",
		"ended": true,
	})
	victory_fixture_run.narrative_flags["demo_victory"] = true
	victory_fixture_run.narrative_flags["demo_victory_route"] = "high_roller_cashout"
	victory_fixture_run.narrative_flags["demo_victory_message"] = RunState.GRAND_CASINO_HIGH_ROLLER_DEFAULT_SUCCESS_MESSAGE
	victory_fixture_run.narrative_flags["demo_finale_completed"] = true
	victory_fixture_run.run_status = RunState.RUN_STATUS_ENDED
	app.call("_refresh")
	await process_frame
	var victory_screen_snapshot: Dictionary = app.call("current_screen_snapshot")
	if str(victory_screen_snapshot.get("screen", "")) != "VICTORY":
		push_error("Ended demo victory did not route to the dedicated VICTORY screen.")
		quit(1)
		return
	if bool(victory_screen_snapshot.get("has_game", true)):
		push_error("Victory inside a game did not clear the active game surface.")
		quit(1)
		return
	var victory_panel: Control = app.get("victory_summary_panel")
	if victory_panel == null or not victory_panel.visible:
		push_error("Dedicated victory summary panel was not visible.")
		quit(1)
		return
	if (app.get("game_surface_canvas") as Control).visible:
		push_error("Game surface remained visible over the victory summary.")
		quit(1)
		return
	var victory_summary: Dictionary = app.call("current_victory_summary_snapshot")
	if str(victory_summary.get("route", "")) != "high_roller_cashout":
		push_error("Victory summary did not preserve the route id.")
		quit(1)
		return
	if str(victory_summary.get("seed", "")) != "UI-VICTORY-SEED" or int(victory_summary.get("bankroll", 0)) != 540 or int(victory_summary.get("heat", 0)) != 18:
		push_error("Victory summary did not include seed, final bankroll, and final heat.")
		quit(1)
		return
	if str(victory_summary.get("current_environment", "")).is_empty() or (victory_summary.get("story_lines", []) as Array).is_empty():
		push_error("Victory summary did not include venue and story context.")
		quit(1)
		return
	if (victory_summary.get("item_lines", []) as Array).is_empty() or (victory_summary.get("debt_lines", []) as Array).is_empty() or (victory_summary.get("alcohol_lines", []) as Array).is_empty():
		push_error("Victory summary did not include item, debt, and alcohol state.")
		quit(1)
		return
	if not _has_visible_text(app, "Demo Victory"):
		push_error("Victory screen did not present the demo victory title.")
		quit(1)
		return
	if not _has_visible_text(app, "Players Card"):
		push_error("Victory screen did not present the Players Card victory route.")
		quit(1)
		return
	if not _has_visible_text(app, "The next act is not implemented yet."):
		push_error("Victory screen did not present the next-act message.")
		quit(1)
		return
	if not _has_visible_text(app, "Main Menu") or not _has_visible_text(app, "New Run"):
		push_error("Victory screen did not present terminal actions.")
		quit(1)
		return
	environment_canvas.queue_free()
	game_canvas.queue_free()
	app.queue_free()
	await process_frame
	print("UI scene compile check passed.")
	quit(0)


func _use_isolated_user_settings(path: String) -> void:
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, path)
	var isolated_settings: UserSettings = UserSettingsScript.new()
	isolated_settings.reset()
	var error := isolated_settings.save()
	if error != OK:
		push_error("Could not prepare isolated UI test settings.")
		quit(1)


func _control_fits_viewport(control: Variant, viewport_rect, label: String) -> bool:
	if control == null or not (control is Control):
		push_error("%s was not available for viewport layout verification." % label)
		return false
	var rect := (control as Control).get_global_rect()
	var min_x := float(viewport_rect.position.x) - 1.0
	var min_y := float(viewport_rect.position.y) - 1.0
	var max_x := float(viewport_rect.position.x + viewport_rect.size.x) + 1.0
	var max_y := float(viewport_rect.position.y + viewport_rect.size.y) + 1.0
	if rect.position.x < min_x or rect.position.y < min_y or rect.end.x > max_x or rect.end.y > max_y:
		push_error("%s is clipped outside the visible viewport: %s within %s." % [label, str(rect), str(viewport_rect)])
		return false
	return true


func _control_clips_contents(control: Variant, label: String) -> bool:
	if control == null or not (control is Control):
		push_error("%s was not available for clipping verification." % label)
		return false
	if not bool((control as Control).get("clip_contents")):
		push_error("%s does not clip its drawing to the assigned visual area." % label)
		return false
	return true


func _canvas_preserves_art_aspect(snapshot: Dictionary, label: String) -> bool:
	if not bool(snapshot.get("preserves_aspect_ratio", false)):
		push_error("%s does not report aspect-preserving art rendering." % label)
		return false
	var board_rect := _snapshot_rect(snapshot.get("board_rect", {}))
	var board_aspect := float(snapshot.get("board_aspect_ratio", 0.0))
	if board_rect.size.x <= 0.0 or board_rect.size.y <= 0.0 or board_aspect <= 0.0:
		push_error("%s did not expose a usable rendered board rect." % label)
		return false
	var rendered_aspect := board_rect.size.x / board_rect.size.y
	if absf(rendered_aspect - board_aspect) > 0.01:
		push_error("%s stretches art: rendered aspect %.3f, board aspect %.3f." % [label, rendered_aspect, board_aspect])
		return false
	return true


func _snapshot_rect(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value as Rect2
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = value
	return Rect2(
		Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))),
		Vector2(float(data.get("w", 0.0)), float(data.get("h", 0.0)))
	)


func _focus_camera_animation_is_stable(canvas: Control, label: String) -> bool:
	if canvas == null or not canvas.has_method("current_view_snapshot"):
		push_error("%s could not expose camera motion diagnostics." % label)
		return false
	var start_snapshot: Dictionary = canvas.call("current_view_snapshot")
	var target_offset: Vector2 = start_snapshot.get("target_camera_offset", Vector2.ZERO)
	var target_zoom := float(start_snapshot.get("target_camera_zoom", 1.0))
	var previous_offset: Vector2 = start_snapshot.get("camera_offset", Vector2.ZERO)
	var previous_zoom := float(start_snapshot.get("camera_zoom", 1.0))
	var previous_distance := previous_offset.distance_to(target_offset) + absf(previous_zoom - target_zoom) * 120.0
	var target_refresh_count := int(start_snapshot.get("camera_target_refresh_count", -1))
	if target_refresh_count < 0:
		push_error("%s did not expose camera target refresh diagnostics." % label)
		return false
	for _index in range(8):
		await process_frame
		var snapshot: Dictionary = canvas.call("current_view_snapshot")
		if int(snapshot.get("camera_target_refresh_count", -1)) != target_refresh_count:
			push_error("%s recalculated its focus target during camera glide, which can cause visible stutter." % label)
			return false
		var current_target_offset: Vector2 = snapshot.get("target_camera_offset", Vector2.ZERO)
		var current_target_zoom := float(snapshot.get("target_camera_zoom", 1.0))
		if current_target_offset.distance_to(target_offset) > 0.25 or absf(current_target_zoom - target_zoom) > 0.001:
			push_error("%s focus camera target drifted while animating." % label)
			return false
		var current_offset: Vector2 = snapshot.get("camera_offset", Vector2.ZERO)
		var current_zoom := float(snapshot.get("camera_zoom", 1.0))
		var distance := current_offset.distance_to(target_offset) + absf(current_zoom - target_zoom) * 120.0
		if distance > previous_distance + 1.0:
			push_error("%s focus camera moved away from its target during animation." % label)
			return false
		var offset_step := current_offset.distance_to(previous_offset)
		var remaining_offset := previous_offset.distance_to(target_offset)
		if offset_step > maxf(remaining_offset * 0.45, 3.0):
			push_error("%s focus camera jumped too far in one frame: %.2f px." % [label, offset_step])
			return false
		if absf(current_zoom - previous_zoom) > 0.16:
			push_error("%s focus camera zoom jumped too far in one frame." % label)
			return false
		previous_offset = current_offset
		previous_zoom = current_zoom
		previous_distance = distance
	return true


func _selected_info_text_fits(canvas_value: Variant, label: String, required_fragments: Array = []) -> bool:
	if canvas_value == null or not (canvas_value is Control):
		push_error("%s did not have an environment canvas for info-card verification." % label)
		return false
	var canvas := canvas_value as Control
	if not canvas.has_method("current_view_snapshot"):
		push_error("%s canvas did not expose a view snapshot." % label)
		return false
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	var selected_info: Dictionary = snapshot.get("selected_info", {})
	if not bool(selected_info.get("visible", false)):
		push_error("%s did not expose a visible in-scene info card." % label)
		return false
	var lines: Array = selected_info.get("lines", [])
	if lines.is_empty():
		push_error("%s info card did not expose any body text." % label)
		return false
	var card_rect := _snapshot_rect(selected_info.get("rect", {}))
	var visible_board_rect := _snapshot_rect(selected_info.get("visible_board_rect", {}))
	if card_rect.size.x <= 0.0 or card_rect.size.y <= 0.0 or visible_board_rect.size.x <= 0.0 or visible_board_rect.size.y <= 0.0:
		push_error("%s info card did not expose valid placement rects." % label)
		return false
	if card_rect.position.x < visible_board_rect.position.x - 0.01 or card_rect.position.y < visible_board_rect.position.y - 0.01 or card_rect.end.x > visible_board_rect.end.x + 0.01 or card_rect.end.y > visible_board_rect.end.y + 0.01:
		push_error("%s info card was clipped outside the visible environment plane." % label)
		return false
	var object_rect := _snapshot_rect(selected_info.get("object_rect", {}))
	if object_rect.size.x > 0.0 and object_rect.size.y > 0.0 and card_rect.intersects(object_rect):
		push_error("%s info card covered the selected environment object." % label)
		return false
	var max_chars := int(selected_info.get("max_line_chars", 42))
	var joined := ""
	for line in lines:
		var text := str(line)
		joined += "%s\n" % text
		if text.find("\n") != -1 or text.find("\t") != -1:
			push_error("%s info card contains multiline text that can clip: %s" % [label, text])
			return false
		if text.find("...") != -1:
			push_error("%s info card still uses ellipsis truncation instead of fitted copy: %s" % [label, text])
			return false
		if text.length() > max_chars:
			push_error("%s info card line exceeds the compact text limit: %s" % [label, text])
			return false
	for fragment in required_fragments:
		if joined.find(str(fragment)) == -1:
			push_error("%s info card omitted expected context: %s" % [label, str(fragment)])
			return false
	return true


func _canvas_local_center_for_object(canvas: Control, object_data: Dictionary) -> Vector2:
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	var position: Vector2 = object_data.get("position", Vector2(0.5, 0.5))
	var board_point := Vector2(position.x * VisualStyleScript.ENVIRONMENT_BOARD_SIZE.x, position.y * VisualStyleScript.ENVIRONMENT_BOARD_SIZE.y)
	var board_rect := _snapshot_rect(snapshot.get("board_rect", {}))
	if board_rect.size.x > 0.0 and board_rect.size.y > 0.0:
		var scale := board_rect.size.x / float(VisualStyleScript.ENVIRONMENT_BOARD_SIZE.x)
		return board_rect.position + board_point * scale
	return Vector2(position.x * canvas.size.x, position.y * canvas.size.y)


func _blank_canvas_position(canvas: Control) -> Vector2:
	var candidates := [
		Vector2(8.0, 8.0),
		Vector2(canvas.size.x - 8.0, 8.0),
		Vector2(8.0, canvas.size.y - 8.0),
		Vector2(canvas.size.x - 8.0, canvas.size.y - 8.0),
		Vector2(canvas.size.x * 0.5, 8.0),
		Vector2(canvas.size.x * 0.5, canvas.size.y - 8.0),
	]
	for candidate in candidates:
		if _canvas_position_is_blank(canvas, candidate):
			return candidate
	for row in range(1, 6):
		for column in range(1, 8):
			var candidate := Vector2(canvas.size.x * float(column) / 8.0, canvas.size.y * float(row) / 6.0)
			if _canvas_position_is_blank(canvas, candidate):
				return candidate
	return Vector2(-1.0, -1.0)


func _canvas_position_is_blank(canvas: Control, local_position: Vector2) -> bool:
	if local_position.x < 0.0 or local_position.y < 0.0 or local_position.x > canvas.size.x or local_position.y > canvas.size.y:
		return false
	if canvas.has_method("object_id_at_local_position"):
		return str(canvas.call("object_id_at_local_position", local_position)).is_empty()
	return true


func _environment_canvas_keeps_critical_ui_clear(app: Control, canvas: Control, viewport_rect, label: String) -> bool:
	if not _control_fits_viewport(canvas, viewport_rect, label):
		return false
	var critical_controls := [
		{"name": "status_label", "label": "HUD status"},
		{"name": "objective_label", "label": "objective HUD"},
		{"name": "save_status_label", "label": "save status"},
		{"name": "actions_list", "label": "context controls"},
		{"name": "consequence_cards_scroll", "label": "result controls"},
		{"name": "game_surface_canvas", "label": "game surface"},
	]
	var canvas_rect := canvas.get_global_rect()
	for entry in critical_controls:
		var control := app.get(str(entry.get("name", ""))) as Control
		if control == null or not control.visible or not control.is_visible_in_tree():
			continue
		var control_label := "%s near %s" % [str(entry.get("label", "")), label]
		if not _control_fits_viewport(control, viewport_rect, control_label):
			return false
		if control != canvas and canvas_rect.intersects(control.get_global_rect()):
			push_error("%s overlaps %s: canvas %s, control %s." % [label, str(entry.get("label", "")), str(canvas_rect), str(control.get_global_rect())])
			return false
	return true


func _visible_text_fits_viewport(node: Node, text: String, viewport_rect, label: String) -> bool:
	if text.is_empty():
		push_error("%s had no text to verify." % label)
		return false
	var control := _find_visible_text_control(node, text)
	if control == null:
		push_error("%s was not visible in the critical game UI: %s." % [label, text])
		return false
	return _control_fits_viewport(control, viewport_rect, label)


func _find_visible_text_control(node: Node, text: String) -> Control:
	if node == null:
		return null
	if node is CanvasItem and not (node as CanvasItem).visible:
		return null
	if node is Label and (node as Label).text.find(text) != -1:
		return node as Control
	if node is Button and (node as Button).text.find(text) != -1:
		return node as Control
	if node is LineEdit and (node as LineEdit).text.find(text) != -1:
		return node as Control
	if node is SpinBox:
		var spin_line := (node as SpinBox).get_line_edit()
		if spin_line != null and spin_line.text.find(text) != -1:
			return node as Control
	for child in node.get_children():
		var found := _find_visible_text_control(child, text)
		if found != null:
			return found
	return null


func _qa_action_label(action: Dictionary) -> String:
	var label := str(action.get("label", ""))
	if not label.is_empty():
		return label
	var action_id := str(action.get("id", ""))
	if action_id.is_empty():
		return "Action"
	return action_id.replace("_", " ").capitalize()


func _check_in_run_menu_flow(app: Control, save_service: SaveService, viewport_rect: Rect2) -> bool:
	if save_service == null:
		push_error("Run menu flow test could not access SaveService.")
		return false
	var menu_slot := "foundation_ui_run_menu_slot"
	var remove_error := _remove_save_slot(save_service, menu_slot)
	if remove_error != OK:
		push_error("Could not prepare the run-menu test save slot.")
		return false
	app.set("autosave_slot_id", menu_slot)

	app.call("start_foundation_run", "UI-RUN-MENU-SCREENS")
	await process_frame
	var top_menu_button: Button = app.get("top_menu_button")
	if top_menu_button == null:
		push_error("Run HUD did not expose the Menu button.")
		return false
	var serialized_before_button_menu := JSON.stringify(app.call("serialized_run_state"))
	top_menu_button.emit_signal("pressed")
	await process_frame
	var button_menu_snapshot: Dictionary = app.call("current_run_menu_snapshot")
	if not bool(button_menu_snapshot.get("visible", false)):
		push_error("HUD Menu button did not open the in-run menu overlay.")
		return false
	if not _has_visible_text(app, "Resume") or not _has_visible_text(app, "Save") or not _has_visible_text(app, "Load") or not _has_visible_text(app, "Abandon Run"):
		push_error("In-run menu did not expose the required player-facing actions.")
		return false
	if not _has_visible_text(app, "Resume Slot") or not _has_visible_text(app, "Save overwrites"):
		push_error("In-run menu did not explain the single save-slot overwrite policy.")
		return false
	if not _control_fits_viewport(app.get("run_menu_panel"), viewport_rect, "run menu panel"):
		return false
	if serialized_before_button_menu != JSON.stringify(app.call("serialized_run_state")):
		push_error("Opening the in-run menu from the HUD mutated serialized RunState.")
		return false
	app.call("close_run_menu")
	await process_frame
	if bool(app.call("current_run_menu_snapshot").get("visible", true)):
		push_error("Resume did not close the in-run menu overlay.")
		return false
	if serialized_before_button_menu != JSON.stringify(app.call("serialized_run_state")):
		push_error("Resuming from the in-run menu mutated serialized RunState.")
		return false
	if not await _check_run_menu_open_resume(app, "ENVIRONMENT", "environment screen"):
		return false

	app.call("enter_first_available_game")
	await process_frame
	if not await _check_run_menu_open_resume(app, "GAME", "game screen"):
		return false
	app.call("back_to_environment")
	await process_frame

	if not bool(app.call("select_action_category", "events")):
		push_error("Run menu screen test could not open the event category.")
		return false
	await process_frame
	if not await _check_run_menu_open_resume(app, "EVENT", "event screen"):
		return false
	if not bool(app.call("select_action_category", "travel")):
		push_error("Run menu screen test could not open the travel category.")
		return false
	await process_frame
	if not await _check_run_menu_open_resume(app, "TRAVEL", "travel screen"):
		return false
	app.call("_set_current_screen", "RESULT")
	app.call("_refresh")
	await process_frame
	if not await _check_run_menu_open_resume(app, "RESULT", "result screen"):
		return false

	app.call("start_foundation_run", "UI-RUN-MENU-FAILURE")
	await process_frame
	var failure_run: RunState = app.get("run_state")
	failure_run.fail_run(RunState.FAILURE_POLICE_CAPTURE, RunState.POLICE_CAPTURE_FAILURE_MESSAGE)
	app.call("_refresh")
	await process_frame
	if not await _check_run_menu_open_resume(app, "FAILURE", "failure screen"):
		return false

	app.call("start_foundation_run", "UI-RUN-MENU-VICTORY")
	await process_frame
	var victory_run: RunState = app.get("run_state")
	victory_run.narrative_flags["demo_victory"] = true
	victory_run.narrative_flags["demo_victory_route"] = "high_roller_cashout"
	victory_run.narrative_flags["demo_victory_message"] = RunState.GRAND_CASINO_HIGH_ROLLER_DEFAULT_SUCCESS_MESSAGE
	victory_run.narrative_flags["demo_finale_completed"] = true
	victory_run.run_status = RunState.RUN_STATUS_ENDED
	app.call("_refresh")
	await process_frame
	if not await _check_run_menu_open_resume(app, "VICTORY", "victory screen"):
		return false

	app.call("start_foundation_run", "UI-RUN-MENU-SAVE-ENV")
	await process_frame
	app.call("open_run_menu")
	await process_frame
	app.call("save_run_from_menu")
	await process_frame
	var env_saved_state: Dictionary = app.call("serialized_run_state")
	var env_saved_bankroll := int(env_saved_state.get("bankroll", 0))
	var env_saved_seed := str(env_saved_state.get("seed_text", ""))
	var env_run: RunState = app.get("run_state")
	env_run.bankroll += 77
	app.call("load_run_from_menu")
	await process_frame
	var env_loaded_state: Dictionary = app.call("serialized_run_state")
	if int(env_loaded_state.get("bankroll", 0)) != env_saved_bankroll or str(env_loaded_state.get("seed_text", "")) != env_saved_seed:
		push_error("In-run menu load did not restore the environment-screen save.")
		return false
	if str(app.call("current_screen_snapshot").get("screen", "")) != "ENVIRONMENT":
		push_error("Environment-screen in-run load did not return to a playable run view.")
		return false

	app.call("start_foundation_run", "UI-RUN-MENU-SAVE-GAME")
	await process_frame
	app.call("enter_first_available_game")
	await process_frame
	if str(app.call("current_screen_snapshot").get("screen", "")) != "GAME":
		push_error("Run menu game-surface save test could not enter a game.")
		return false
	app.call("open_run_menu")
	await process_frame
	app.call("save_run_from_menu")
	await process_frame
	var game_saved_state: Dictionary = app.call("serialized_run_state")
	var game_saved_bankroll := int(game_saved_state.get("bankroll", 0))
	var game_saved_seed := str(game_saved_state.get("seed_text", ""))
	var game_run: RunState = app.get("run_state")
	game_run.bankroll += 41
	app.call("load_run_from_menu")
	await process_frame
	var game_loaded_state: Dictionary = app.call("serialized_run_state")
	if int(game_loaded_state.get("bankroll", 0)) != game_saved_bankroll or str(game_loaded_state.get("seed_text", "")) != game_saved_seed:
		push_error("In-run menu load did not restore the game-surface save.")
		return false
	if str(app.call("current_screen_snapshot").get("screen", "")) == "START":
		push_error("Game-surface in-run load incorrectly returned to the main menu.")
		return false

	app.call("start_foundation_run", "UI-RUN-MENU-ABANDON")
	await process_frame
	app.call("open_run_menu")
	await process_frame
	app.call("abandon_run_from_menu")
	await process_frame
	var abandoned_run: RunState = app.get("run_state")
	if abandoned_run.run_status != RunState.RUN_STATUS_FAILED or abandoned_run.run_failure_reason != RunState.FAILURE_ABANDONED:
		push_error("Abandon Run did not set the abandoned terminal failure reason.")
		return false
	if str(app.call("current_screen_snapshot").get("screen", "")) != "FAILURE":
		push_error("Abandon Run did not route to the failure summary.")
		return false
	if bool(app.call("current_run_menu_snapshot").get("visible", true)):
		push_error("Abandon Run left the in-run menu visible over the terminal summary.")
		return false
	if not _has_visible_text(app, "Run abandoned"):
		push_error("Abandon Run did not present a clear terminal summary title.")
		return false
	return true


func _check_run_menu_open_resume(app: Control, expected_screen: String, label: String) -> bool:
	var screen_before := str(app.call("current_screen_snapshot").get("screen", ""))
	if screen_before != expected_screen:
		push_error("Run menu %s expected screen %s before open but saw %s." % [label, expected_screen, screen_before])
		return false
	var serialized_before := JSON.stringify(app.call("serialized_run_state"))
	app.call("open_run_menu")
	await process_frame
	var open_snapshot: Dictionary = app.call("current_run_menu_snapshot")
	if not bool(open_snapshot.get("visible", false)):
		push_error("Run menu did not open from %s." % label)
		return false
	if str(open_snapshot.get("screen", "")) != expected_screen:
		push_error("Run menu snapshot did not preserve %s while open." % label)
		return false
	if serialized_before != JSON.stringify(app.call("serialized_run_state")):
		push_error("Run menu open mutated serialized RunState from %s." % label)
		return false
	app.call("close_run_menu")
	await process_frame
	var close_snapshot: Dictionary = app.call("current_run_menu_snapshot")
	if bool(close_snapshot.get("visible", true)):
		push_error("Run menu resume did not close from %s." % label)
		return false
	if str(app.call("current_screen_snapshot").get("screen", "")) != expected_screen:
		push_error("Run menu resume did not return to %s." % label)
		return false
	if serialized_before != JSON.stringify(app.call("serialized_run_state")):
		push_error("Run menu resume mutated serialized RunState from %s." % label)
		return false
	return true


func _check_run_journal_flow(app: Control, save_service: SaveService, viewport_rect: Rect2) -> bool:
	if save_service == null:
		push_error("Run journal flow test could not access SaveService.")
		return false
	var journal_slot := "foundation_ui_run_journal_slot"
	var remove_error := _remove_save_slot(save_service, journal_slot)
	if remove_error != OK:
		push_error("Could not prepare the run-journal test save slot.")
		return false
	app.set("autosave_slot_id", journal_slot)
	app.call("start_foundation_run", "UI-RUN-JOURNAL")
	await process_frame
	var journal_run: RunState = app.get("run_state")
	_add_run_journal_fixture_entries(journal_run)
	app.call("_refresh")
	await process_frame

	app.call("open_run_menu")
	await process_frame
	var menu_snapshot: Dictionary = app.call("current_run_menu_snapshot")
	if bool(menu_snapshot.get("journal_disabled", true)) or not _has_visible_text(app, "Journal"):
		push_error("Run menu did not expose an enabled Journal action.")
		return false
	if not _click_visible_button(app, "Journal"):
		push_error("Run menu Journal button was not clickable.")
		return false
	await process_frame
	var serialized_before_open := JSON.stringify(app.call("serialized_run_state"))
	var journal_snapshot: Dictionary = app.call("current_run_journal_snapshot")
	if not bool(journal_snapshot.get("visible", false)) or not bool(journal_snapshot.get("read_only", false)):
		push_error("Run journal did not open as a read-only overlay.")
		return false
	if not _control_fits_viewport(app.get("run_journal_panel"), viewport_rect, "run journal panel"):
		return false
	if serialized_before_open != JSON.stringify(app.call("serialized_run_state")):
		push_error("Opening the run journal mutated serialized RunState.")
		return false
	var entries: Array = journal_snapshot.get("entries", [])
	if entries.size() < 12:
		push_error("Run journal did not expose the expected story entry count.")
		return false
	if not _journal_entry_matches(entries, 0, "Travel", "travel"):
		return false
	if not _journal_entry_matches(entries, 1, "Debt", "debt"):
		return false
	if not _journal_entry_matches(entries, 2, "Item Bought", "item"):
		return false
	if not _journal_entry_matches(entries, 5, "Event", "event"):
		return false
	if not _journal_entry_matches(entries, 6, "Notable Win", "game"):
		return false
	if not _journal_entry_matches(entries, 8, "Heat Spike", "heat"):
		return false
	if not _journal_has_title(entries, "High-Roller Review") or not _journal_has_title(entries, "Rourke's Attention") or not _journal_has_title(entries, "Back Room") or not _journal_has_title(entries, "Showdown Outcome"):
		push_error("Run journal did not include Grand Casino endgame entries.")
		return false
	for entry_index in range(entries.size()):
		var entry: Dictionary = entries[entry_index]
		if int(entry.get("index", 0)) != entry_index + 1:
			push_error("Run journal entries were not exposed in chronological order.")
			return false
	app.call("close_run_journal")
	await process_frame
	if bool(app.call("current_run_journal_snapshot").get("visible", true)):
		push_error("Run journal did not close.")
		return false
	if serialized_before_open != JSON.stringify(app.call("serialized_run_state")):
		push_error("Closing the run journal mutated serialized RunState.")
		return false
	app.call("close_run_menu")
	await process_frame

	app.call("open_run_menu")
	await process_frame
	app.call("save_run_from_menu")
	await process_frame
	var saved_entries_json := JSON.stringify((app.call("current_run_journal_snapshot") as Dictionary).get("entries", []))
	journal_run = app.get("run_state")
	journal_run.story_log = []
	app.call("load_run_from_menu")
	await process_frame
	app.call("open_run_journal")
	await process_frame
	var loaded_journal_snapshot: Dictionary = app.call("current_run_journal_snapshot")
	if JSON.stringify(loaded_journal_snapshot.get("entries", [])) != saved_entries_json:
		push_error("Run journal contents did not survive save/load.")
		return false
	app.call("close_run_journal")
	await process_frame

	app.call("start_foundation_run", "UI-RUN-JOURNAL-TERMINAL")
	await process_frame
	var terminal_run: RunState = app.get("run_state")
	terminal_run.fail_run(RunState.FAILURE_POLICE_CAPTURE, RunState.POLICE_CAPTURE_FAILURE_MESSAGE)
	app.call("_refresh")
	await process_frame
	app.call("open_run_journal")
	await process_frame
	var terminal_snapshot: Dictionary = app.call("current_run_journal_snapshot")
	var terminal_entries: Array = terminal_snapshot.get("entries", [])
	if terminal_entries.is_empty() or str((terminal_entries[terminal_entries.size() - 1] as Dictionary).get("category", "")) != "terminal":
		push_error("Run journal did not derive a terminal result entry for a failed run.")
		return false
	app.call("close_run_journal")
	await process_frame
	return true


func _add_run_journal_fixture_entries(run_state: RunState) -> void:
	run_state.log_story({
		"type": "travel",
		"to_environment_name": "Corner Store",
		"to_archetype_id": "corner_store",
		"message": "Traveled to Corner Store.",
	})
	run_state.log_story({
		"type": "lender_hook",
		"lender_id": "fast_eddie",
		"debt_changes": [{"lender_id": "fast_eddie", "balance": 30}],
		"message": "Fast Eddie fronts a little cash.",
	})
	run_state.log_story({
		"type": "item_purchase",
		"item_id": "cheap_sunglasses",
		"item_name": "Cheap Sunglasses",
		"bankroll_delta": -12,
		"message": "Bought Cheap Sunglasses.",
	})
	run_state.log_story({
		"type": "item_sale",
		"item_id": "scratch_pad",
		"item_name": "Scratch Pad",
		"bankroll_delta": 4,
		"message": "Sold Scratch Pad.",
	})
	run_state.log_story({
		"type": "item_use",
		"item_id": "cheap_sunglasses",
		"inventory_remove": ["cheap_sunglasses"],
		"message": "Used Cheap Sunglasses.",
	})
	run_state.log_story({
		"type": "event",
		"event_id": "machine_jam",
		"message": "A jammed machine makes the floor pause.",
	})
	run_state.log_story({
		"type": "game_action",
		"game_id": "blackjack",
		"bankroll_delta": 120,
		"message": "Blackjack pays out hard.",
	})
	run_state.log_story({
		"type": "game_action",
		"game_id": "roulette",
		"bankroll_delta": -35,
		"message": "Roulette takes a bite.",
	})
	run_state.log_story({
		"type": "game_action",
		"game_id": "baccarat",
		"suspicion_delta": 12,
		"message": "A risky baccarat press spikes heat.",
	})
	run_state.log_story({
		"type": "grand_casino_high_roller_ready",
		"event_id": "high_roller_cashout",
		"bankroll": 520,
		"net_winnings": 260,
		"message": "The casino host is ready to issue the Players Card.",
	})
	run_state.log_story({
		"type": "grand_casino_heat_reroute",
		"event_id": "the_house_calls",
		"attention_sources": ["rourke_watch"],
		"heat": 72,
		"message": "Rourke calls you to the back room.",
	})
	run_state.log_story({
		"type": "grand_casino_showdown_arrival",
		"event_id": "the_house_calls",
		"attention_sources": ["rourke_watch"],
		"heat": 72,
		"message": "Rourke takes you to the back room.",
	})
	run_state.log_story({
		"type": "demo_finale_result",
		"event_id": "the_house_calls",
		"branch": "pit_boss_showdown",
		"ended": true,
		"message": "Rourke lets you walk with your winnings.",
	})


func _journal_entry_matches(entries: Array, index: int, title: String, category: String) -> bool:
	if index < 0 or index >= entries.size() or typeof(entries[index]) != TYPE_DICTIONARY:
		push_error("Run journal entry %d was missing." % index)
		return false
	var entry: Dictionary = entries[index]
	if str(entry.get("title", "")) != title or str(entry.get("category", "")) != category:
		push_error("Run journal entry %d expected %s/%s but saw %s/%s." % [
			index,
			title,
			category,
			str(entry.get("title", "")),
			str(entry.get("category", "")),
		])
		return false
	return true


func _journal_has_title(entries: Array, title: String) -> bool:
	for entry_value in entries:
		if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("title", "")) == title:
			return true
	return false


func _check_final_demo_objective_hud_matrix(app: Control) -> bool:
	var pre_grand_snapshot: Dictionary = app.call("current_objective_hud_snapshot")
	if not _assert_objective_state(pre_grand_snapshot, "pre-grand", "pre-Grand objective HUD"):
		return false
	var pre_grand_guidance: Dictionary = pre_grand_snapshot.get("guidance", {})
	var pre_grand_text := str(pre_grand_guidance.get("text", pre_grand_snapshot.get("goal", "")))
	if pre_grand_text.find("Grand Casino") == -1 or pre_grand_text.find("heat") == -1:
		push_error("Pre-Grand objective guidance should mention reaching the Grand Casino and managing heat.")
		return false

	var grand_environment := _grand_casino_environment_for_ui(app)
	if grand_environment.is_empty():
		push_error("Could not build Grand Casino HUD fixture environment.")
		return false
	var objective: Dictionary = grand_environment.get("demo_objective", {})
	var high_roller_target := int(objective.get("high_roller_target_bankroll", objective.get("target_bankroll", 0)))
	var high_roller_net := int(objective.get("high_roller_net_winnings", 75))
	var high_roller_min_games := int(objective.get("high_roller_min_grand_casino_games", 3))
	var showdown_heat_threshold := int(objective.get("showdown_heat_threshold", 70))

	var close_cashout_run := _grand_casino_fixture_run("UI-HUD-GRAND-CLOSE", grand_environment)
	_record_grand_casino_clean_games(close_cashout_run, maxi(0, high_roller_min_games - 1))
	close_cashout_run.bankroll = maxi(high_roller_target - 20, int(close_cashout_run.narrative_flags.get("grand_casino_entry_bankroll", 0)) + high_roller_net)
	close_cashout_run.evaluate_environment_objective_state()
	_set_ui_fixture_run(app, close_cashout_run)
	var close_snapshot: Dictionary = app.call("current_objective_hud_snapshot")
	if not _assert_objective_state(close_snapshot, "grand-incomplete", "Grand Casino close cashout HUD"):
		return false
	if str(close_snapshot.get("goal", "")).find("Close to Players Card") == -1 or not bool((close_snapshot.get("guidance", {}) as Dictionary).get("clean_progress_close", false)):
		push_error("Grand Casino close Players Card HUD did not present clean progress guidance.")
		return false

	var heat_close_run := _grand_casino_fixture_run("UI-HUD-GRAND-HEAT", grand_environment)
	heat_close_run.add_suspicion("ui_hud_heat_close", maxi(0, showdown_heat_threshold - 5), "behavior")
	heat_close_run.evaluate_environment_objective_state()
	_set_ui_fixture_run(app, heat_close_run)
	var heat_snapshot: Dictionary = app.call("current_objective_hud_snapshot")
	if not _assert_objective_state(heat_snapshot, "grand-incomplete", "Grand Casino heat pressure HUD"):
		return false
	if str(heat_snapshot.get("goal", "")).find("Rourke") == -1 or not bool((heat_snapshot.get("guidance", {}) as Dictionary).get("heat_pressure_close", false)):
		push_error("Grand Casino heat-pressure HUD did not present Rourke pressure guidance.")
		return false

	var high_roller_run := _grand_casino_fixture_run("UI-HUD-HIGH-ROLLER", grand_environment)
	_record_grand_casino_clean_games(high_roller_run, high_roller_min_games)
	high_roller_run.bankroll = maxi(high_roller_target, int(high_roller_run.narrative_flags.get("grand_casino_entry_bankroll", 0)) + high_roller_net)
	high_roller_run.evaluate_environment_objective_state()
	_set_ui_fixture_run(app, high_roller_run)
	var high_roller_snapshot: Dictionary = app.call("current_objective_hud_snapshot")
	if not _assert_objective_state(high_roller_snapshot, "high-roller-ready", "High-roller ready objective HUD"):
		return false
	if not _assert_next_objective(high_roller_snapshot, "event", "event:high_roller_cashout", "High-roller ready objective HUD"):
		return false

	var showdown_run := _grand_casino_fixture_run("UI-HUD-SHOWDOWN", grand_environment)
	showdown_run.add_suspicion("ui_hud_showdown", showdown_heat_threshold, "behavior")
	showdown_run.evaluate_environment_objective_state()
	_set_ui_fixture_run(app, showdown_run)
	var showdown_snapshot: Dictionary = app.call("current_objective_hud_snapshot")
	if not _assert_objective_state(showdown_snapshot, "showdown-pending", "Showdown pending objective HUD"):
		return false
	if not _assert_next_objective(showdown_snapshot, "event", "event:the_house_calls", "Showdown pending objective HUD"):
		return false

	var victory_run := _grand_casino_fixture_run("UI-HUD-VICTORY", grand_environment)
	victory_run.narrative_flags["demo_victory"] = true
	victory_run.narrative_flags["demo_victory_route"] = "high_roller_cashout"
	victory_run.narrative_flags["demo_victory_message"] = RunState.GRAND_CASINO_HIGH_ROLLER_DEFAULT_SUCCESS_MESSAGE
	victory_run.narrative_flags["demo_finale_completed"] = true
	victory_run.run_status = RunState.RUN_STATUS_ENDED
	_set_ui_fixture_run(app, victory_run)
	var victory_snapshot: Dictionary = app.call("current_objective_hud_snapshot")
	if not _assert_objective_state(victory_snapshot, "victory", "Victory objective HUD"):
		return false
	if not _assert_next_objective(victory_snapshot, "menu", "main_menu", "Victory objective HUD"):
		return false

	var failure_run := _grand_casino_fixture_run("UI-HUD-FAILURE", grand_environment)
	failure_run.fail_run(RunState.FAILURE_CASINO_TAKEN_OUT_BACK, RunState.CASINO_TAKEN_OUT_BACK_FAILURE_MESSAGE)
	_set_ui_fixture_run(app, failure_run)
	var failure_snapshot: Dictionary = app.call("current_objective_hud_snapshot")
	if not _assert_objective_state(failure_snapshot, "failure", "Failure objective HUD"):
		return false
	if not _assert_next_objective(failure_snapshot, "menu", "main_menu", "Failure objective HUD"):
		return false
	return true


func _assert_objective_state(snapshot: Dictionary, expected_state: String, label: String) -> bool:
	var actual_state := str(snapshot.get("objective_state", ""))
	if actual_state != expected_state:
		push_error("%s expected objective_state %s but got %s." % [label, expected_state, actual_state])
		return false
	var guidance: Dictionary = snapshot.get("guidance", {})
	if str(guidance.get("state", "")) != expected_state:
		push_error("%s guidance state did not match the HUD state." % label)
		return false
	if str(guidance.get("text", "")).strip_edges().is_empty():
		push_error("%s did not expose player-facing guidance text." % label)
		return false
	if str(snapshot.get("goal", "")).strip_edges().is_empty() or str(snapshot.get("text", "")).find("[GOAL]") == -1:
		push_error("%s did not expose stable visible goal text." % label)
		return false
	return true


func _assert_next_objective(snapshot: Dictionary, expected_type: String, expected_id: String, label: String) -> bool:
	var next_objective: Dictionary = snapshot.get("next_objective", {})
	if str(next_objective.get("object_type", "")) != expected_type or str(next_objective.get("object_id", "")) != expected_id:
		push_error("%s pointed next objective at %s/%s instead of %s/%s." % [
			label,
			str(next_objective.get("object_type", "")),
			str(next_objective.get("object_id", "")),
			expected_type,
			expected_id,
		])
		return false
	return true


func _set_ui_fixture_run(app: Control, run_state: RunState) -> void:
	app.set("run_state", run_state)
	app.set("current_game", null)
	app.call("_refresh_run_action_service")
	app.call("_refresh_runtime_environment_views")


func _grand_casino_fixture_run(seed_text: String, environment: Dictionary) -> RunState:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.set_environment(environment.duplicate(true))
	return run_state


func _record_grand_casino_clean_games(run_state: RunState, count: int) -> void:
	for game_index in range(maxi(0, count)):
		run_state.record_grand_casino_game_result({
			"ok": true,
			"type": "game_action",
			"source_id": "blackjack",
			"game_id": "blackjack",
			"action_id": "clean_hud_progress",
			"action_kind": "legal",
			"stake": 10 + game_index,
			"deltas": {
				"story_log": [{
					"type": "game_action",
					"game_id": "blackjack",
					"stake_cost": 10 + game_index,
				}],
			},
			"message": "Clean Grand Casino progress.",
		})


func _grand_casino_environment_for_ui(app: Control) -> Dictionary:
	var library: ContentLibrary = app.get("library")
	var archetype := _archetype_by_id(library, "grand_casino")
	if archetype.is_empty():
		return {}
	var environment := archetype.duplicate(true)
	environment["id"] = "grand_casino_ui_hud_fixture"
	environment["archetype_id"] = "grand_casino"
	environment["display_name"] = "Grand Casino"
	environment["kind"] = "boss"
	environment["game_ids"] = (environment.get("game_pool", []) as Array).duplicate()
	environment["event_ids"] = []
	environment["travel_hooks"] = (environment.get("travel_hooks", []) as Array).duplicate()
	return environment


func _remove_save_slot(save_service: SaveService, slot_id: String) -> Error:
	if save_service == null:
		return ERR_UNCONFIGURED
	var path := save_service.run_save_path(slot_id)
	if not FileAccess.file_exists(path):
		return OK
	var user_dir := DirAccess.open("user://")
	if user_dir == null:
		return ERR_CANT_OPEN
	var relative_path := path.replace("user://", "")
	return user_dir.remove(relative_path)


func _check_game_surface_touch_hit_policy() -> bool:
	var touch_canvas: Control = GameSurfaceCanvasScript.new()
	touch_canvas.size = Vector2(900, 320)
	root.add_child(touch_canvas)
	touch_canvas.call("surface_add_hit", Rect2(12, 12, 12, 16), "surface_stake_up")
	touch_canvas.call("surface_add_exact_hit", Rect2(40, 40, 12, 16), "dense_board_probe")
	var snapshot: Dictionary = touch_canvas.call("current_view_snapshot")
	var regions: Array = snapshot.get("surface_hit_actions", [])
	var control_rect := _surface_hit_rect(regions, "surface_stake_up")
	var dense_rect := _surface_hit_rect(regions, "dense_board_probe")
	touch_canvas.queue_free()
	if control_rect.size.x < 44.0 or control_rect.size.y < 44.0:
		push_error("Game surface touch controls should expand small hit regions to at least 44x44.")
		return false
	if absf(dense_rect.size.x - 12.0) > 0.001 or absf(dense_rect.size.y - 16.0) > 0.001:
		push_error("Dense game-board hit regions should keep exact geometry to avoid overlapping betting grids.")
		return false
	return true


func _surface_hit_rect(regions: Array, action: String) -> Rect2:
	for region_value in regions:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		if str(region.get("action", "")) != action:
			continue
		var rect: Variant = region.get("rect", Rect2())
		if typeof(rect) == TYPE_RECT2:
			return rect as Rect2
	return Rect2()


func _has_visible_text(node: Node, text: String) -> bool:
	if node == null:
		return false
	if node is CanvasItem and not (node as CanvasItem).visible:
		return false
	if node is Label and (node as Label).text.find(text) != -1:
		return true
	if node is Button and (node as Button).text.find(text) != -1:
		return true
	if node is LineEdit and (node as LineEdit).text.find(text) != -1:
		return true
	for child in node.get_children():
		if _has_visible_text(child, text):
			return true
	return false


func _click_visible_button(node: Node, text: String) -> bool:
	if node == null:
		return false
	if node is CanvasItem and not (node as CanvasItem).visible:
		return false
	if node is Button:
		var button := node as Button
		if not button.disabled and button.text == text:
			button.emit_signal("pressed")
			return true
	for child in node.get_children():
		if _click_visible_button(child, text):
			return true
	return false


func _category_by_id(categories: Array, category_id: String) -> Dictionary:
	for category in categories:
		if typeof(category) == TYPE_DICTIONARY and str((category as Dictionary).get("id", "")) == category_id:
			return (category as Dictionary).duplicate(true)
	return {}


func _interactable_by_type(objects: Array, object_type: String) -> Dictionary:
	for object_data in objects:
		if typeof(object_data) == TYPE_DICTIONARY and str((object_data as Dictionary).get("object_type", "")) == object_type:
			return (object_data as Dictionary).duplicate(true)
	return {}


func _canvas_object_by_id(objects: Array, object_id: String) -> Dictionary:
	for object_data in objects:
		if typeof(object_data) == TYPE_DICTIONARY and str((object_data as Dictionary).get("id", "")) == object_id:
			return (object_data as Dictionary).duplicate(true)
	return {}


func _canvas_has_object_type(objects: Array, object_type: String) -> bool:
	for object_data in objects:
		if typeof(object_data) == TYPE_DICTIONARY and str((object_data as Dictionary).get("type", "")) == object_type:
			return true
	return false


func _canvas_object_id_with_prefix(objects: Array, prefix: String) -> bool:
	for object_data in objects:
		if typeof(object_data) == TYPE_DICTIONARY and str((object_data as Dictionary).get("id", "")).begins_with(prefix):
			return true
	return false


func _canvas_object_position_matches_board_spot(object_data: Dictionary, board_spot: Variant) -> bool:
	var expected := _board_spot_to_normalized_position(board_spot)
	if expected.x < 0.0 or expected.y < 0.0:
		return false
	var actual: Variant = object_data.get("position", Vector2(-1.0, -1.0))
	if typeof(actual) != TYPE_VECTOR2:
		return false
	return (actual as Vector2).distance_to(expected) <= 0.001


func _board_spot_to_normalized_position(board_spot: Variant) -> Vector2:
	var point := Vector2(-1.0, -1.0)
	if typeof(board_spot) == TYPE_ARRAY:
		var parts := board_spot as Array
		if parts.size() >= 2:
			point = Vector2(float(parts[0]), float(parts[1]))
	elif typeof(board_spot) == TYPE_DICTIONARY:
		var data := board_spot as Dictionary
		point = Vector2(float(data.get("x", -1.0)), float(data.get("y", -1.0)))
	if point.x < 0.0 or point.y < 0.0:
		return Vector2(-1.0, -1.0)
	var board_size := Vector2(VisualStyleScript.ENVIRONMENT_BOARD_SIZE)
	return Vector2(point.x / board_size.x, point.y / board_size.y)


func _archetype_by_id(library: ContentLibrary, archetype_id: String) -> Dictionary:
	if library == null or archetype_id.is_empty():
		return {}
	for archetype in library.environment_archetypes:
		if typeof(archetype) == TYPE_DICTIONARY and str((archetype as Dictionary).get("id", "")) == archetype_id:
			return (archetype as Dictionary).duplicate(true)
	return {}


func _implemented_game_display_names(library: ContentLibrary) -> Array:
	var result: Array = []
	if library == null:
		return result
	for game_value in library.games:
		if typeof(game_value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = game_value
		var game_id := str(definition.get("id", ""))
		var module_path := str(definition.get("module_path", ""))
		if game_id.is_empty() or module_path.is_empty():
			continue
		if module_path.ends_with("_ui.gd") or module_path.begins_with("res://data/runtime/"):
			continue
		if not ResourceLoader.exists(module_path):
			continue
		result.append(str(definition.get("display_name", game_id.capitalize())))
	return result


func _canvas_surviving_object_positions_match(before_objects: Array, after_objects: Array, removed_object_id: String) -> bool:
	for object_data in before_objects:
		if typeof(object_data) != TYPE_DICTIONARY:
			continue
		var object_id := str((object_data as Dictionary).get("id", ""))
		if object_id.is_empty() or object_id == removed_object_id:
			continue
		var after_object := _canvas_object_by_id(after_objects, object_id)
		if after_object.is_empty():
			continue
		var before_position: Variant = (object_data as Dictionary).get("position", Vector2(0.5, 0.5))
		var after_position: Variant = after_object.get("position", Vector2(0.5, 0.5))
		if typeof(before_position) != TYPE_VECTOR2 or typeof(after_position) != TYPE_VECTOR2:
			return false
		if (before_position as Vector2).distance_to(after_position as Vector2) > 0.0001:
			return false
	return true


func _card_by_title(cards: Array, title: String) -> Dictionary:
	for card in cards:
		if typeof(card) == TYPE_DICTIONARY and str((card as Dictionary).get("title", "")) == title:
			return (card as Dictionary).duplicate(true)
	return {}
