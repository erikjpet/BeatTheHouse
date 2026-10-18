extends SceneTree

# Captures the five-image itch.io gallery set from the current 0.6 runtime.
# Run windowed so the viewport texture contains the production renderer:
#   godot --path . --rendering-method gl_compatibility --resolution 1280x720 \
#     --script res://tools/itch_screenshots_0_6.gd \
#     -- --out=res://branding/itch/0.6

const MainScene := preload("res://scenes/main.tscn")
const CAPTURE_SIZE := Vector2i(1280, 720)
const COVER_SIZE := Vector2i(630, 500)
const COVER_BACKGROUND := Color("#05070d")
const CAPTURE_SEED := "ITCH-0.6-GALLERY"

var app: Control
var out_dir := "res://branding/itch/0.6"
var captures: Array = []


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	call_deferred("_run")


func _run() -> void:
	var absolute_out := ProjectSettings.globalize_path(out_dir)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_out)
	if directory_error != OK and not DirAccess.dir_exists_absolute(absolute_out):
		_fail("Could not create itch screenshot directory: %s" % absolute_out)
		return
	root.size = CAPTURE_SIZE
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(CAPTURE_SIZE)
	app = MainScene.instantiate()
	app.set("show_game_library_launcher", true)
	app.set("autosave_slot_id", "itch_screenshots_0_6")
	root.add_child(app)
	await _settle(12)
	if not await _capture_cover():
		return
	if not await _capture_environments():
		return
	if not await _capture_blackjack():
		return
	if not await _capture_roulette():
		return
	var manifest := {
		"version": "0.6.0",
		"seed": CAPTURE_SEED,
		"cover_size": [COVER_SIZE.x, COVER_SIZE.y],
		"gameplay_capture_size": [CAPTURE_SIZE.x, CAPTURE_SIZE.y],
		"captures": captures,
	}
	var manifest_file := FileAccess.open("%s/manifest.json" % out_dir, FileAccess.WRITE)
	if manifest_file == null:
		_fail("Could not write screenshot manifest.")
		return
	manifest_file.store_string(JSON.stringify(manifest, "\t"))
	manifest_file.close()
	print("ITCH_SCREENSHOTS_0_6_PASS count=%d dir=%s" % [captures.size(), absolute_out])
	quit(0)


func _capture_cover() -> bool:
	# Use the exact transparent wordmark displayed by the production main menu.
	var texture: Texture2D = load("res://assets/art/ui/beat_the_house_logo.png")
	var source := texture.get_image() if texture != null else null
	if source == null or source.is_empty():
		_fail("Could not load the in-game Beat the House logo.")
		return false
	var scale := minf(float(COVER_SIZE.x) / float(source.get_width()), float(COVER_SIZE.y) / float(source.get_height()))
	var fitted_size := Vector2i(
		maxi(1, roundi(float(source.get_width()) * scale)),
		maxi(1, roundi(float(source.get_height()) * scale))
	)
	source.convert(Image.FORMAT_RGBA8)
	source.resize(fitted_size.x, fitted_size.y, Image.INTERPOLATE_LANCZOS)
	var cover := Image.create(COVER_SIZE.x, COVER_SIZE.y, false, Image.FORMAT_RGBA8)
	cover.fill(COVER_BACKGROUND)
	var offset := Vector2i((COVER_SIZE.x - fitted_size.x) / 2, (COVER_SIZE.y - fitted_size.y) / 2)
	cover.blit_rect(source, Rect2i(Vector2i.ZERO, fitted_size), offset)
	return _save_image("01_cover_logo.png", cover, "In-game Beat the House logo cover")


func _capture_environments() -> bool:
	if not bool(app.call("start_foundation_run", CAPTURE_SEED, {})):
		_fail("Could not start the gallery run.")
		return false
	await _settle(14)
	var run_state: Variant = app.get("run_state")
	if run_state == null:
		_fail("Gallery run did not expose RunState.")
		return false
	run_state.game_clock_minutes = 1260
	if not _set_environment_archetype("jazz_club"):
		return false
	await _settle(14)
	_suppress_capture_overlays()
	await _settle(4)
	if not await _capture_viewport("02_environment_blue_note.png", "Blue Note jazz club at night"):
		return false
	if not _set_environment_archetype("grand_casino"):
		return false
	await _settle(14)
	_suppress_capture_overlays()
	await _settle(4)
	return await _capture_viewport("03_environment_grand_casino.png", "Grand Casino main floor at night")


func _capture_blackjack() -> bool:
	var started: Dictionary = app.call("start_game_test_session", "blackjack")
	if not bool(started.get("ok", false)):
		_fail("Could not start the Blackjack capture session: %s" % JSON.stringify(started))
		return false
	var run_state: Variant = app.get("run_state")
	if run_state != null:
		run_state.bankroll = 500
	_suppress_capture_overlays()
	await _settle(8)
	if not bool(app.call("_handle_module_surface_action", "blackjack_deal", 0, true)):
		_fail("Blackjack Deal was not handled.")
		return false
	await create_timer(3.7).timeout
	await _settle(3)
	# The deterministic gallery seed opens on a playable total. Capture the
	# third card in motion to show an actual decision rather than an idle table.
	if not bool(app.call("_handle_module_surface_action", "blackjack_hit", 0, false, true)):
		_fail("Blackjack Hit was not handled.")
		return false
	await create_timer(0.55).timeout
	await _settle(2)
	_suppress_capture_overlays()
	return await _capture_viewport("04_blackjack_in_action.png", "Blackjack hand after a live hit")


func _capture_roulette() -> bool:
	var started: Dictionary = app.call("start_game_test_session", "roulette")
	if not bool(started.get("ok", false)):
		_fail("Could not start the Roulette capture session: %s" % JSON.stringify(started))
		return false
	var run_state: Variant = app.get("run_state")
	if run_state != null:
		run_state.bankroll = 500
	_suppress_capture_overlays()
	await _settle(8)
	if not bool(app.call("_handle_module_surface_action", "roulette_chip", 2, false, true)):
		_fail("Roulette chip selection was not handled.")
		return false
	for bet_index in [1, 17, 40]:
		if not bool(app.call("_handle_module_surface_action", "roulette_bet", bet_index, false, true)):
			_fail("Roulette bet %d was not handled." % bet_index)
			return false
	await _settle(3)
	if not bool(app.call("_handle_module_surface_action", "roulette_spin", 0, true, true)):
		_fail("Roulette Spin was not handled.")
		return false
	await create_timer(0.65).timeout
	await _settle(2)
	_suppress_capture_overlays()
	return await _capture_viewport("05_roulette_live_spin.png", "Roulette wheel spinning with three active bets")


func _set_environment_archetype(archetype_id: String) -> bool:
	var library: Variant = app.get("library")
	var run_state: Variant = app.get("run_state")
	if library == null or run_state == null:
		_fail("Environment capture is missing the content library or RunState.")
		return false
	var archetype: Dictionary = library.environment_archetype(archetype_id)
	if archetype.is_empty():
		_fail("Environment archetype not found: %s" % archetype_id)
		return false
	var rng: Variant = run_state.create_rng("itch_gallery:%s" % archetype_id)
	var environment: Variant = EnvironmentInstance.from_archetype(archetype, 1, rng, library, run_state.challenge_config)
	var data: Dictionary = environment.to_dict()
	data["world_node_id"] = archetype_id
	data["entered_game_clock_minutes"] = run_state.game_clock_minutes
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data)
	run_state.save_rng(rng)
	run_state.set_environment(data)
	app.set("last_game_result", {})
	app.set("last_environment_runtime_result", {})
	app.set("last_item_result", {})
	app.set("last_hook_result", {})
	if app.has_method("_clear_selected_game_action"):
		app.call("_clear_selected_game_action")
	if app.has_method("_clear_selected_travel"):
		app.call("_clear_selected_travel")
	if app.has_method("clear_interaction_focus"):
		app.call("clear_interaction_focus")
	if app.has_method("_refresh"):
		app.call("_refresh")
	if app.has_method("_show_message"):
		app.call("_show_message", "")
	if app.has_method("_refresh"):
		app.call("_refresh")
	if app.has_method("_show_message"):
		app.call("_show_message", "")
	return true


func _suppress_capture_overlays() -> void:
	for method_name in ["_hide_event_choice_popup", "_hide_run_inventory_popup", "_hide_run_journal_popup", "_hide_world_map_overlay", "_hide_travel_transition"]:
		if app.has_method(method_name):
			app.call(method_name)
	var talk_dock: Variant = app.get("talk_dock")
	if talk_dock != null:
		if talk_dock.has_method("clear_entry"):
			talk_dock.call("clear_entry")
		if talk_dock is CanvasItem:
			talk_dock.visible = false
	var coach_overlay: Variant = app.get("coach_overlay")
	if coach_overlay != null and coach_overlay is CanvasItem:
		coach_overlay.visible = false
		coach_overlay.process_mode = Node.PROCESS_MODE_DISABLED


func _capture_viewport(file_name: String, caption: String) -> bool:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Viewport capture was empty: %s" % file_name)
		return false
	if image.get_size() != CAPTURE_SIZE:
		image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_NEAREST)
	return _save_image(file_name, image, caption)


func _save_image(file_name: String, image: Image, caption: String) -> bool:
	var path := "%s/%s" % [out_dir, file_name]
	var error := image.save_png(path)
	if error != OK:
		_fail("Could not save %s: %s" % [path, error_string(error)])
		return false
	captures.append({
		"file": file_name,
		"caption": caption,
		"width": image.get_width(),
		"height": image.get_height(),
		"sha256": FileAccess.get_sha256(path),
	})
	print("ITCH_SCREENSHOT %s" % file_name)
	return true


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
