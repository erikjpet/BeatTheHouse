extends SceneTree

# Cold-start, pointer-driven acceptance for the release Games screen. The main
# UI suite owns broad interaction coverage; this focused check proves that every
# advertised launcher can be reached and opens its exact production game.

const MainScene := preload("res://scenes/main.tscn")
const EXPECTED_LAUNCHERS := [
	{"id": "scratch_tickets", "label": "Scratch Tickets"},
	{"id": "pull_tabs", "label": "Pull Tabs"},
	{"id": "slot", "label": "Slot"},
	{"id": "bar_dice", "label": "Bar Dice"},
	{"id": "blackjack", "label": "Blackjack"},
	{"id": "baccarat", "label": "Baccarat"},
	{"id": "craps", "label": "Craps"},
	{"id": "roulette", "label": "Roulette"},
	{"id": "crew_draw_poker", "label": "Back-Room Poker"},
	{"id": "video_poker", "label": "Video Poker"},
	{"id": "coin_pusher", "label": "Quarter Falls"},
]

var app: Control
var failures: Array[String] = []
var launch_records: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
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
	if buttons.size() != EXPECTED_LAUNCHERS.size():
		_fail("Games page exposed %d launchers instead of %d: %s." % [buttons.size(), EXPECTED_LAUNCHERS.size(), JSON.stringify(buttons.keys())])
	for expected_value in EXPECTED_LAUNCHERS:
		var expected: Dictionary = expected_value
		var game_id := str(expected.get("id", ""))
		var label := str(expected.get("label", ""))
		if not menu.is_visible_in_tree() and not await _open_games_by_pointer():
			break
		buttons = _launch_buttons_by_id(menu)
		var button := buttons.get(game_id) as Button
		var record := {"game_id": game_id, "label": label, "clicked": false, "entered": false}
		launch_records.append(record)
		if button == null or button.text != label or button.disabled or not button.is_visible_in_tree():
			_fail("Games page did not expose an enabled %s launcher for %s." % [label, game_id])
			continue
		await _scroll_control_into_view(button)
		var scroll := _ancestor_scroll_container(button)
		var button_rect := button.get_global_rect()
		if scroll == null or not scroll.get_global_rect().grow(1.0).encloses(button_rect):
			_fail("%s launcher could not be brought fully into its visible scroll area." % label)
			continue
		await _move_pointer(button_rect.get_center())
		var hovered := app.get_viewport().gui_get_hovered_control()
		if hovered != button and (hovered == null or not button.is_ancestor_of(hovered)):
			_fail("%s launcher was covered by %s at its center point." % [label, hovered.name if hovered != null else "nothing"])
			continue
		await _click_pointer(button_rect.get_center())
		record["clicked"] = true
		await _settle(2)
		var current_game: GameModule = app.get("current_game")
		var entered := str(app.get("current_screen")) == "GAME" and current_game != null and current_game.get_id() == game_id
		record["entered"] = entered
		if not entered:
			_fail("Clicking %s did not open %s; screen=%s current_game=%s." % [label, game_id, str(app.get("current_screen")), current_game.get_id() if current_game != null else ""])
		app.call("return_to_main_menu")
		await _settle(2)
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
	await _move_pointer(library_button.get_global_rect().get_center())
	var hovered := app.get_viewport().gui_get_hovered_control()
	if hovered != library_button and (hovered == null or not library_button.is_ancestor_of(hovered)):
		_fail("Main menu Games button was covered at its center point.")
		return false
	await _click_pointer(library_button.get_global_rect().get_center())
	await _settle(2)
	var menu := app.get("game_test_menu") as Control
	var library: ContentLibrary = app.get("library")
	if menu == null or not menu.is_visible_in_tree() or library == null or not library.is_fully_loaded():
		_fail("Pointer-clicking Games did not show the complete game catalog.")
		return false
	return true


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
		app.get_viewport().push_input(wheel, true)
		await process_frame
		wheel = wheel.duplicate()
		wheel.pressed = false
		app.get_viewport().push_input(wheel, true)
		await process_frame


func _move_pointer(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	app.get_viewport().push_input(motion, true)
	await process_frame


func _click_pointer(position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	press.global_position = position
	app.get_viewport().push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	release.global_position = position
	app.get_viewport().push_input(release, true)
	await process_frame


func _settle(frames: int) -> void:
	for _frame in range(maxi(1, frames)):
		await process_frame


func _fail(message: String) -> void:
	if not failures.has(message):
		failures.append(message)
	push_error(message)
