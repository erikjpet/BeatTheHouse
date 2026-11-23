extends SceneTree

# Cold-start, pointer-driven acceptance for the release Games screen. The main
# UI suite owns broad interaction coverage; this focused check proves that every
# advertised launcher can be reached and opens its exact production game.

const MainScene := preload("res://scenes/main.tscn")
const APPROVED_ROOT := "e:/codexqa/bth/"

# Only the explicitly approved D: root can use the guarded manifest path.
const D_QA_ROOT := "d:/codexqa/bth"
const D_QA_ENV := {
	"BTH_QA_WORKSPACE": ["workspace"],
	"BTH_QA_RUN_DIR": ["run_root"],
	"BTH_QA_PROFILE_DIR": ["profile"],
	"BTH_SAVE_DIR": ["save_dir"],
	"BTH_USER_SETTINGS_PATH": ["localappdata", "settings.json"],
	"BTH_PROFILE_INVENTORY_PATH": ["localappdata", "profile-inventory.json"],
	"BTH_META_COLLECTION_PATH": ["localappdata", "meta-collection.json"],
	"BTH_QA_EVIDENCE_DIR": ["evidence"],
	"BTH_QA_TEMP_DIR": ["temp"],
	"APPDATA": ["appdata"],
	"LOCALAPPDATA": ["localappdata"],
	"TEMP": ["temp"],
	"TMP": ["temp"],
}

const EXPECTED_LAUNCHERS := [
	{"id": "scratch_tickets", "label": "Scratch Tickets"},
	{"id": "pull_tabs", "label": "Pull Tabs"},
	{"id": "slot", "label": "Slot"},
	{"id": "bar_dice", "label": "Bar Dice"},
	{"id": "blackjack", "label": "Blackjack"},
	{"id": "baccarat", "label": "Baccarat"},
	{"id": "craps", "label": "Craps"},
	{"id": "roulette", "label": "Roulette"},
	{"id": "crew_draw_poker", "label": "Back-Room Hold'em"},
	{"id": "video_poker", "label": "Video Poker"},
	{"id": "coin_pusher", "label": "Quarter Falls"},
]

var app: Control
var failures: Array[String] = []
var launch_records: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _guarded_rendered_environment():
		_finish(false)
		return
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "game_library_launcher_check")
	root.add_child(app)
	await _settle(3)
	var library: ContentLibrary = app.get("library")
	var cold_catalog_was_staged := library != null and not library.is_fully_loaded()
	if not await _open_games_by_pointer():
		_finish(cold_catalog_was_staged)
		return
	var menu := app.get("game_test_menu") as Control
	var buttons := _launch_buttons_by_id(menu)
	var canonical_ids: Array = app.call("_implemented_game_ids")
	if canonical_ids.size() != EXPECTED_LAUNCHERS.size():
		_fail("The canonical Games registry no longer contains the eleven expected playable games.")
	if buttons.size() != EXPECTED_LAUNCHERS.size():
		_fail("Games page exposed %d launchers instead of %d: %s." % [buttons.size(), EXPECTED_LAUNCHERS.size(), JSON.stringify(buttons.keys())])
	for expected_value in EXPECTED_LAUNCHERS:
		var expected: Dictionary = expected_value
		var game_id := str(expected.get("id", ""))
		var label := str(expected.get("label", ""))
		if not menu.is_visible_in_tree():
			_fail("The retained CRT selector was unavailable before %s." % label)
			break
		buttons = _launch_buttons_by_id(menu)
		var button := buttons.get(game_id) as Button
		var record := {"game_id": game_id, "label": label, "clicked": false, "entered": false, "returned_to_crt": false}
		launch_records.append(record)
		var definition: Dictionary = library.game(game_id)
		if not canonical_ids.has(game_id) or label != str(definition.get("display_name", "")):
			_fail("Expected game %s disagrees with the canonical current Games registry." % game_id)
		if button == null or button.text != label or button.disabled or not button.is_visible_in_tree():
			_fail("Games page did not expose an enabled %s launcher for %s." % [label, game_id])
			continue
		if button.icon == null or str(button.get_meta("game_icon_asset_path", "")) != str(definition.get("asset_path", "")):
			_fail("%s does not expose its canonical existing icon." % label)
		await _scroll_control_into_view(button)
		var button_rect := button.get_global_rect()
		if not _visible_clip(button).grow(1.0).encloses(button_rect):
			_fail("%s launcher could not be brought fully into the visible CRT display." % label)
			continue
		# Alternate near the left and right visible tile edges. This exercises the
		# actual curved-display hit region, rather than proving only its center.
		var edge_fraction := minf(0.15, 8.0 / maxf(1.0, button_rect.size.x))
		var point := _hit_point(button, Vector2(edge_fraction if launch_records.size() % 2 == 1 else 1.0 - edge_fraction, 0.5))
		record["point"] = {"x": point.x, "y": point.y}
		if not await _stable_pointer_target(button, point, label):
			continue
		await _click_pointer(point)
		record["clicked"] = true
		await _settle(2)
		var current_game: GameModule = app.get("current_game")
		var entered := str(app.get("current_screen")) == "GAME" and current_game != null and current_game.get_id() == game_id
		record["entered"] = entered
		if not entered:
			_fail("Clicking %s did not open %s; screen=%s current_game=%s." % [label, game_id, str(app.get("current_screen")), current_game.get_id() if current_game != null else ""])
		if not entered:
			break
		var surface := app.get("game_surface_canvas") as Control
		var leave_rect: Rect2 = surface.call("global_rect_for_surface_action", "surface_back", -1) if surface != null else Rect2()
		if not leave_rect.has_area():
			_fail("%s did not expose its normal rendered Leave control." % label)
			break
		await _move_pointer(leave_rect.get_center())
		await _click_pointer(leave_rect.get_center())
		# Quarter Falls keeps its normal chunked exit settlement. Wait for that
		# production path instead of clearing the active module to change screens.
		for _frame in range(600):
			if menu.is_visible_in_tree() and app.get("current_game") == null:
				break
			await process_frame
		record["returned_to_crt"] = menu == app.get("game_test_menu") and menu.is_visible_in_tree() and app.get("current_game") == null and str(app.get("current_screen")) == "CRT"
		if not bool(record["returned_to_crt"]):
			_fail("Leaving %s did not return to the same CRT selector." % label)
			break
	var exit_button := menu.get("exit_button") as Button
	if exit_button == null or not await _stable_pointer_target(exit_button, _hit_point(exit_button), "Exit TV"):
		_finish(cold_catalog_was_staged)
		return
	await _click_pointer(_hit_point(exit_button))
	await _settle(2)
	if str(app.get("current_screen")) != "START" or bool(app.call("_crt_practice_active")) or app.get("run_state") != null:
		_fail("Exit CRT did not restore the title-screen origin.")
	_finish(cold_catalog_was_staged)


func _finish(cold_catalog_was_staged: bool) -> void:
	print("GAME_LIBRARY_LAUNCHER_CHECK %s" % JSON.stringify({
		"passed": failures.is_empty(),
		"cold_catalog_was_staged": cold_catalog_was_staged,
		"expected_count": EXPECTED_LAUNCHERS.size(),
		"launches": launch_records,
		"failures": failures,
	}))
	quit(0 if failures.is_empty() else 1)


func _open_games_by_pointer() -> bool:
	var library_button := app.get("game_library_button") as Button
	if library_button == null or library_button.disabled or not library_button.is_visible_in_tree():
		_fail("Main menu Games button was unavailable.")
		return false
	if not await _stable_pointer_target(library_button, library_button.get_global_rect().get_center(), "Main menu Games"):
		return false
	await _click_pointer(library_button.get_global_rect().get_center())
	await _settle(2)
	var menu := app.get("game_test_menu") as Control
	var library: ContentLibrary = app.get("library")
	if menu == null or not menu.is_visible_in_tree() or library == null or not library.is_fully_loaded():
		_fail("Pointer-clicking Games did not show the complete game catalog.")
		return false
	return true


func _guarded_rendered_environment() -> bool:
	if DisplayServer.get_name() == "headless":
		_fail("Launcher pointer acceptance requires a rendered native display.")
		return false
	if _qa_path(OS.get_environment("BTH_QA_RUN_DIR")).begins_with(D_QA_ROOT + "/"):
		return _guarded_d_environment()
	for key in ["BTH_QA_WORKSPACE", "BTH_QA_RUN_DIR", "BTH_QA_PROFILE_DIR", "BTH_SAVE_DIR", "BTH_USER_SETTINGS_PATH", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_QA_EVIDENCE_DIR"]:
		if not OS.get_environment(key).replace("\\", "/").simplify_path().to_lower().begins_with(APPROVED_ROOT):
			_fail("Missing or non-approved disposable QA path: %s." % key)
			return false
	if not ProjectSettings.globalize_path("res://").replace("\\", "/").to_lower().begins_with(APPROVED_ROOT) or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(APPROVED_ROOT):
		_fail("Launcher checkout and engine user data must stay on the admitted E: QA root.")
		return false
	return true


func _qa_path(value: String) -> String:
	return value.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()


func _guarded_d_environment() -> bool:
	var run := _qa_path(OS.get_environment("BTH_QA_RUN_DIR"))
	var evidence := run.path_join("evidence")
	if run.get_base_dir() != D_QA_ROOT.path_join("runs") or _qa_path(OS.get_environment("BTH_QA_EVIDENCE_DIR")) != evidence:
		_fail("D: launcher requires the guarded run evidence directory.")
		return false
	var manifest_path := evidence.path_join("storage-manifest.json")
	var manifest_text := FileAccess.get_file_as_string(manifest_path)
	var manifest: Variant = JSON.parse_string(manifest_text)
	var claim: Variant = JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("launch-claim.json")))
	var env := {}
	for key: String in D_QA_ENV:
		env[key] = OS.get_environment(key)
	if not _matches_d_manifest(manifest, claim, FileAccess.get_sha256(manifest_path), env,
			ProjectSettings.globalize_path("res://"), OS.get_user_data_dir()):
		_fail("D: launcher requires a prepared storage manifest and matching guarded launch claim and paths.")
		return false
	return true


func _matches_d_manifest(manifest: Variant, claim: Variant, digest: String, env: Dictionary,
		checkout: String, engine_data: String) -> bool:
	if not manifest is Dictionary or not claim is Dictionary or digest.is_empty():
		return false
	if manifest.get("schema") != "bth-qa-storage/v1" or manifest.get("prepared") != true:
		return false
	if claim.get("schema") != "bth.qa_launch_claim/v1" or claim.get("manifest_sha256") != digest:
		return false
	var paths: Variant = manifest.get("paths")
	var run_id: Variant = manifest.get("run_id")
	if not paths is Dictionary or not run_id is String:
		return false
	if run_id.is_empty() or run_id.contains("/") or run_id.contains("\\") or run_id == "." or run_id == "..":
		return false
	var run := D_QA_ROOT.path_join("runs").path_join(run_id.to_lower())
	var evidence := run.path_join("evidence")
	if _qa_path(str(paths.get("root", ""))) != D_QA_ROOT or _qa_path(str(manifest.get("manifest_path", ""))) != evidence.path_join("storage-manifest.json"):
		return false
	if _qa_path(str(paths.get("run_root", ""))) != run:
		return false
	for name: String in ["profile", "temp", "evidence", "appdata", "localappdata", "home", "cache", "save_dir", "pycache"]:
		if _qa_path(str(paths.get(name, ""))) != run.path_join(name):
			return false
	var workspace := _qa_path(str(paths.get("workspace", "")))
	if not workspace.begins_with(D_QA_ROOT + "/") or _qa_path(checkout) != workspace:
		return false
	for key: String in D_QA_ENV:
		var binding: Array = D_QA_ENV[key]
		var expected := _qa_path(str(paths.get(binding[0], "")))
		if binding.size() == 2:
			expected = expected.path_join(binding[1])
		if _qa_path(str(env.get(key, ""))) != expected:
			return false
	return _qa_path(engine_data).begins_with(run.path_join("appdata") + "/")


func _visible_clip(control: Control) -> Rect2:
	var clip := control.get_viewport().get_visible_rect()
	var ancestor := control.get_parent()
	while ancestor != null and ancestor != control.get_viewport():
		if ancestor is Control and (ancestor as Control).clip_contents:
			clip = clip.intersection((ancestor as Control).get_global_rect())
		ancestor = ancestor.get_parent()
	return clip


func _stable_pointer_target(control: Control, point: Vector2, label: String) -> bool:
	for _attempt in range(3):
		await _settle_rendered(2)
		var before := control.get_global_rect()
		await _move_pointer(point)
		var hovered := control.get_viewport().gui_get_hovered_control()
		var local_point := _display_point(control, point)
		if before.is_equal_approx(control.get_global_rect()) and before.has_point(local_point) and _visible_clip(control).has_point(local_point) and (hovered == control or hovered != null and control.is_ancestor_of(hovered)):
			return true
	_fail("%s never exposed its stable, uncovered visible hit target." % label)
	return false


func _hit_point(control: Control, normalized: Vector2 = Vector2(0.5, 0.5)) -> Vector2:
	var menu := app.get("game_test_menu") as Control
	if menu != null and menu.has_method("get_display_viewport") and control.get_viewport() == menu.call("get_display_viewport"):
		return menu.call("display_hit_point", control, normalized)
	return control.get_global_rect().position + control.get_global_rect().size * normalized


func _display_point(control: Control, global_point: Vector2) -> Vector2:
	var menu := app.get("game_test_menu") as Control
	if menu != null and menu.has_method("get_display_viewport") and control.get_viewport() == menu.call("get_display_viewport"):
		return menu.call("global_to_display", global_point)
	return global_point


func _launch_buttons_by_id(node: Node) -> Dictionary:
	var result := {}
	if node == null:
		return result
	if node is Button and node.has_meta("game_test_id"):
		var game_id := str(node.get_meta("game_test_id", ""))
		if result.has(game_id):
			_fail("Games page exposed duplicate launcher id %s." % game_id)
		else:
			result[game_id] = node
	for child in node.get_children():
		var child_buttons := _launch_buttons_by_id(child)
		for game_id in child_buttons:
			if result.has(game_id):
				_fail("Games page exposed duplicate launcher id %s." % game_id)
			else:
				result[game_id] = child_buttons.get(game_id)
	return result


func _ancestor_scroll_container(control: Control) -> ScrollContainer:
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			return ancestor as ScrollContainer
		ancestor = ancestor.get_parent()
	return null


func _scroll_control_into_view(control: Control) -> void:
	var scroll := _ancestor_scroll_container(control)
	if scroll == null:
		return
	for _attempt in range(20):
		var control_rect := control.get_global_rect()
		var clip_rect := scroll.get_global_rect()
		if clip_rect.grow(1.0).encloses(control_rect):
			return
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if control_rect.get_center().y > clip_rect.get_center().y else MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.factor = 4.0
		wheel.position = clip_rect.get_center()
		wheel.global_position = wheel.position
		Input.parse_input_event(wheel)
		await process_frame
		wheel = wheel.duplicate()
		wheel.pressed = false
		Input.parse_input_event(wheel)
		await process_frame


func _move_pointer(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	motion.relative = position - root.get_mouse_position()
	Input.parse_input_event(motion)
	await _settle_rendered(2)


func _click_pointer(position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	press.position = position
	press.global_position = position
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	release.global_position = position
	Input.parse_input_event(release)
	await _settle_rendered(2)


func _settle_rendered(frames: int) -> void:
	for _frame in range(maxi(1, frames)):
		await process_frame
		await RenderingServer.frame_post_draw


func _settle(frames: int) -> void:
	for _frame in range(maxi(1, frames)):
		await process_frame


func _fail(message: String) -> void:
	if not failures.has(message):
		failures.append(message)
	push_error(message)
