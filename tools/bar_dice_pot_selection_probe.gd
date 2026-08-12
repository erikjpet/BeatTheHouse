extends SceneTree

# Reproduces Bar Dice ante changes through the production Main scene and the
# rendered GameSurfaceCanvas hit regions. This intentionally does not call the
# game module's selection command directly.

const MainScene := preload("res://scenes/main.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	var app: Control = MainScene.instantiate()
	app.set("show_game_library_launcher", true)
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "bar_dice_pot_selection_probe")
	root.add_child(app)
	await _settle(10)
	app.call("start_game_test_session", "bar_dice")
	await _settle(12)

	var canvas: GameSurfaceCanvas = app.get("game_surface_canvas")
	var game: GameModule = app.get("current_game")
	if canvas == null or game == null or game.get_id() != "bar_dice":
		_fail("The production Bar Dice surface did not open.")
		_finish([])
		return

	var initial_surface: Dictionary = canvas.realtime_surface_state()
	var ladder: Array = initial_surface.get("stake_ladder", [])
	var observations: Array[Dictionary] = []
	if ladder.size() < 2:
		_fail("The Bar Dice fixture did not expose multiple ante choices.")
	else:
		var sequence := [ladder.size() - 1, 0, ladder.size() / 2, ladder.size() - 1]
		for index_value in sequence:
			var index := int(index_value)
			var rect := canvas.global_rect_for_surface_action("bar_dice_stake", index)
			if not rect.has_area():
				_fail("Ante index %d has no rendered hit region." % index)
				continue
			_click_viewport_global(rect.get_center())
			await _settle(8)
			var ui_state: Dictionary = app.get("game_surface_ui_state")
			var surface: Dictionary = canvas.realtime_surface_state()
			var selected_index := int(ui_state.get("selected_stake_index", -1))
			var active_stake := int(surface.get("active_stake", -1))
			observations.append({
				"clicked_index": index,
				"expected_stake": int(ladder[index]),
				"selected_index": selected_index,
				"active_stake": active_stake,
			})
			if selected_index != index or active_stake != int(ladder[index]):
				_fail("Clicking ante index %d selected index %d with stake %d." % [index, selected_index, active_stake])

		app.call("back_to_environment")
		await _settle(8)
		app.call("enter_game", "bar_dice")
		await _settle(10)
		var reopened_index := mini(1, ladder.size() - 1)
		var reopened_rect := canvas.global_rect_for_surface_action("bar_dice_stake", reopened_index)
		if not reopened_rect.has_area():
			_fail("The reopened Bar Dice surface lost its ante hit regions.")
		else:
			_click_viewport_global(reopened_rect.get_center())
			await _settle(8)
			var reopened_ui: Dictionary = app.get("game_surface_ui_state")
			var reopened_surface: Dictionary = canvas.realtime_surface_state()
			observations.append({
				"reopened": true,
				"clicked_index": reopened_index,
				"expected_stake": int(ladder[reopened_index]),
				"selected_index": int(reopened_ui.get("selected_stake_index", -1)),
				"active_stake": int(reopened_surface.get("active_stake", -1)),
			})
			if int(reopened_ui.get("selected_stake_index", -1)) != reopened_index or int(reopened_surface.get("active_stake", -1)) != int(ladder[reopened_index]):
				_fail("The reopened Bar Dice surface did not accept a new ante selection.")

	_finish(observations)


func _click_viewport_global(global_position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = global_position
	press.global_position = global_position
	Input.parse_input_event(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = global_position
	release.global_position = global_position
	Input.parse_input_event(release)


func _settle(frame_count: int) -> void:
	for _index in range(frame_count):
		await process_frame


func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)


func _finish(observations: Array) -> void:
	print("BAR_DICE_POT_SELECTION_PROBE %s" % JSON.stringify({
		"passed": failures.is_empty(),
		"failures": failures,
		"observations": observations,
	}))
	quit(0 if failures.is_empty() else 1)
