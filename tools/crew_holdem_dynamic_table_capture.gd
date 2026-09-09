extends SceneTree

# Windowed production-host captures for the shared Hold'em room and its
# character-specific high-wager conversation overlay.

const MainScene := preload("res://scenes/main.tscn")
const OUTPUT_DIR := "res://review_artifacts/holdem_dynamic_table"
const CAPTURE_SIZE := Vector2i(1280, 720)
const COMPACT_CAPTURE_SIZE := Vector2i(960, 540)
const MISSING_ACTION_INDEX := -999


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = CAPTURE_SIZE
	RenderingServer.set_default_clear_color(Color("#05060a"))
	var app := MainScene.instantiate()
	app.set("show_game_library_launcher", true)
	app.set("autosave_slot_id", "crew_holdem_dynamic_table_capture")
	root.add_child(app)
	await _settle(8)
	var start: Dictionary = app.call("start_game_test_session", "crew_draw_poker")
	if not bool(start.get("ok", false)):
		push_error("Could not open Back-Room Hold'em through the game launcher.")
		quit(1)
		return
	await _settle(8)
	var canvas := app.get("game_surface_canvas") as Control
	var idle: Dictionary = canvas.call("realtime_surface_state")
	if str(idle.get("surface_template", "")) != "shared_table_game_v1" or int(idle.get("animated_crew_count", 0)) != 3:
		push_error("Hold'em did not render the shared room with three animated Crew seats.")
		quit(1)
		return
	if not await _capture("01_shared_room_idle.png"):
		quit(1)
		return
	app.call("_handle_module_surface_action", "poker_deal", 0, true)
	await _settle(8)
	if not await _capture("02_live_holdem_hand.png"):
		quit(1)
		return
	if not await _advance_to_player(app, canvas):
		push_error("Could not reach the player's first betting decision.")
		quit(1)
		return
	if not await _capture("04_player_betting_choices.png"):
		quit(1)
		return
	root.size = COMPACT_CAPTURE_SIZE
	await _settle(6)
	if not await _capture("07_compact_player_betting_choices.png", COMPACT_CAPTURE_SIZE):
		quit(1)
		return
	root.size = CAPTURE_SIZE
	await _settle(6)
	var raise_open_index := _surface_action_index(canvas, "poker_raise_open")
	if raise_open_index == MISSING_ACTION_INDEX or not bool(app.call("_handle_module_surface_action", "poker_raise_open", raise_open_index, true)):
		push_error("The visible raise chooser could not be opened.")
		quit(1)
		return
	await _settle(4)
	if not await _capture("08_raise_selection_open.png"):
		quit(1)
		return
	var plus_one_index := _surface_action_index(canvas, "poker_raise_plus_one")
	if plus_one_index == MISSING_ACTION_INDEX or not bool(app.call("_handle_module_surface_action", "poker_raise_plus_one", plus_one_index, true)):
		push_error("The raise chooser could not select a custom whole-dollar amount. hits=%s" % JSON.stringify((canvas.call("current_view_snapshot") as Dictionary).get("surface_hit_actions", [])))
		quit(1)
		return
	await _settle(4)
	if not await _capture("09_custom_raise_selection.png"):
		quit(1)
		return
	root.size = COMPACT_CAPTURE_SIZE
	await _settle(6)
	if not await _capture("10_compact_custom_raise_selection.png", COMPACT_CAPTURE_SIZE):
		quit(1)
		return
	root.size = CAPTURE_SIZE
	await _settle(6)
	var confirm_index := _surface_action_index(canvas, "poker_raise_confirm")
	if confirm_index == MISSING_ACTION_INDEX or not bool(app.call("_handle_module_surface_action", "poker_raise_confirm", confirm_index, true)):
		push_error("The selected custom raise could not be confirmed.")
		quit(1)
		return
	await _settle(6)
	if not await _capture("05_raise_chips_placed.png"):
		quit(1)
		return
	if not await _advance_to_board_street(app, canvas):
		push_error("Could not reach a community-card street through visible controls.")
		quit(1)
		return
	if not await _capture("06_board_and_swept_pot.png"):
		quit(1)
		return
	var live: Dictionary = canvas.call("realtime_surface_state")
	var seats: Array = live.get("seats", []) if typeof(live.get("seats", [])) == TYPE_ARRAY else []
	var member_id := str((seats[0] as Dictionary).get("member_id", "")) if not seats.is_empty() else ""
	var member_name := str((seats[0] as Dictionary).get("name", "Crew")) if not seats.is_empty() else "Crew"
	var request := {
		"event_id": "crew-poker-talk:visual:%s" % member_id,
		"game_id": str(app.get("current_game").call("get_id")),
		"member_id": member_id,
		"member_name": member_name,
		"seat_index": 0,
		"line_key": "poker_raise",
		"node_id": "raise_pressure",
		"phase": "turn",
		"action": "raise",
		"pot": 24,
		"heads_up": true,
		"hand_number": 1,
	}
	if not bool(app.call("_enqueue_crew_poker_table_talk", request)):
		push_error("Could not open the high-wager Crew conversation.")
		quit(1)
		return
	app.call("_refresh")
	await _settle(8)
	var talk_dock := app.get("talk_dock") as Control
	if talk_dock != null:
		talk_dock.call("_complete_body_reveal")
	await _settle(2)
	if not await _capture("03_high_wager_table_talk.png"):
		quit(1)
		return
	var talk: Dictionary = app.call("current_talk_dock_snapshot")
	if not bool(talk.get("visible", false)) or not bool(talk.get("anchored_bottom", false)) or bool(talk.get("anchored_bottom_left", true)) or str(talk.get("speaking_character_id", "")) != member_id:
		push_error("The high-wager conversation was not visibly anchored away from the controls.")
		quit(1)
		return
	print("CREW_HOLDEM_DYNAMIC_TABLE_CAPTURE_PASS dir=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame


func _advance_to_player(app: Control, canvas: Control) -> bool:
	for _step in range(12):
		await _answer_visible_talk(app)
		var state: Dictionary = canvas.call("realtime_surface_state")
		if str(state.get("turn_owner", "")) == "player":
			return true
		var observe_index := _surface_action_index(canvas, "poker_observe")
		if observe_index == MISSING_ACTION_INDEX or not bool(app.call("_handle_module_surface_action", "poker_observe", observe_index, true)):
			return false
		await _settle(4)
	return false


func _advance_to_board_street(app: Control, canvas: Control) -> bool:
	for _step in range(40):
		await _answer_visible_talk(app)
		var state: Dictionary = canvas.call("realtime_surface_state")
		if str(state.get("phase", "")) in ["flop", "turn", "river"] and not (state.get("community_cards", []) as Array).is_empty():
			return true
		var observe_index := _surface_action_index(canvas, "poker_observe")
		if observe_index != MISSING_ACTION_INDEX:
			app.call("_handle_module_surface_action", "poker_observe", observe_index, true)
		else:
			var call_index := _surface_action_index(canvas, "poker_call")
			if call_index == MISSING_ACTION_INDEX:
				return false
			app.call("_handle_module_surface_action", "poker_call", call_index, true)
		await _settle(4)
	return false


func _answer_visible_talk(app: Control) -> void:
	var talk: Dictionary = app.call("current_talk_dock_snapshot")
	if not bool(talk.get("visible", false)):
		return
	var choice_ids: Array = talk.get("choice_ids", []) if typeof(talk.get("choice_ids", [])) == TYPE_ARRAY else []
	if not choice_ids.is_empty():
		app.call("_on_talk_dock_choice_requested", str(talk.get("event_id", "")), str(choice_ids[0]))
		await _settle(3)


func _surface_action_index(canvas: Control, action: String) -> int:
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	for hit_value in snapshot.get("surface_hit_actions", []):
		if typeof(hit_value) == TYPE_DICTIONARY and str((hit_value as Dictionary).get("action", "")) == action:
			return int((hit_value as Dictionary).get("index", -1))
	return MISSING_ACTION_INDEX


func _capture(file_name: String, expected_size: Vector2i = CAPTURE_SIZE) -> bool:
	await process_frame
	var texture := root.get_viewport().get_texture()
	if texture == null:
		push_error("Could not capture %s because the active renderer has no viewport texture." % file_name)
		return false
	var image := texture.get_image()
	if image == null or image.is_empty():
		push_error("Could not capture %s because the viewport returned no image." % file_name)
		return false
	if image.get_size() != expected_size:
		image.resize(expected_size.x, expected_size.y, Image.INTERPOLATE_NEAREST)
	var error := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	if error != OK:
		push_error("Could not save %s." % file_name)
		return false
	return true
