extends SceneTree

# Production-host audit for the Hold'em room, animated Crew projections, and
# high-wager conversation handoff. It intentionally uses the game-library
# launcher so the same canvas and TalkDock boundaries as a player are exercised.

const MainScene := preload("res://scenes/main.tscn")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")

var failures: Array[String] = []
const MISSING_ACTION_INDEX := -999


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app := MainScene.instantiate()
	app.set("show_game_library_launcher", true)
	app.set("autosave_slot_id", "crew_holdem_dynamic_table_audit")
	root.add_child(app)
	await _settle(8)
	var start: Dictionary = app.call("start_game_test_session", "crew_draw_poker")
	if not bool(start.get("ok", false)):
		failures.append("The production game launcher could not enter Back-Room Hold'em.")
		await _finish(app, {})
		return
	await _settle(8)
	var library := app.get("library") as ContentLibrary
	var canvas := app.get("game_surface_canvas") as Control
	var run_state := app.get("run_state") as RunState
	if library == null or canvas == null or run_state == null:
		failures.append("The production host did not expose the Hold'em content, canvas, and run state.")
		await _finish(app, {})
		return
	var surface: Dictionary = canvas.call("realtime_surface_state")
	if str(surface.get("surface_template", "")) != "shared_table_game_v1":
		failures.append("Hold'em did not declare the shared table-game room template.")
	var seats: Array = surface.get("seats", []) if typeof(surface.get("seats", [])) == TYPE_ARRAY else []
	if seats.size() != 3 or int(surface.get("animated_crew_count", 0)) != 3:
		failures.append("The room did not project all three Crew opponents as animated seats.")
	for seat_value in seats:
		var seat: Dictionary = seat_value
		var model: Dictionary = seat.get("character_model", {}) if typeof(seat.get("character_model", {})) == TYPE_DICTIONARY else {}
		for key in ["skin_color", "hair_color", "jacket_color", "accent_color", "silhouette", "scale"]:
			if not model.has(key):
				failures.append("%s is missing animated character model field %s." % [str(seat.get("name", "Crew")), key])
	var line_keys := ["poker_heads_up", "poker_raise", "poker_river", "poker_big_pot"]
	for member_value in CrewStateModelScript.MEMBER_IDS:
		var member_id := str(member_value)
		var character := library.character(member_id)
		var voice: Dictionary = character.get("voice", {}) if typeof(character.get("voice", {})) == TYPE_DICTIONARY else {}
		var lines: Dictionary = voice.get("lines", {}) if typeof(voice.get("lines", {})) == TYPE_DICTIONARY else {}
		for line_key in line_keys:
			if typeof(lines.get(line_key, [])) != TYPE_ARRAY or (lines.get(line_key, []) as Array).size() < 2:
				failures.append("%s is missing authored %s table talk." % [member_id, line_key])
	var member_id := str((seats[0] as Dictionary).get("member_id", "")) if not seats.is_empty() else ""
	var request := {
		"event_id": "crew-poker-talk:audit:%s" % member_id,
		"game_id": str(app.get("current_game").call("get_id")),
		"member_id": member_id,
		"member_name": str((seats[0] as Dictionary).get("name", "Crew")) if not seats.is_empty() else "Crew",
		"seat_index": 0,
		"line_key": "poker_heads_up",
		"node_id": "heads_up",
		"phase": "river",
		"action": "raise",
		"pot": 24,
		"heads_up": true,
		"hand_number": 1,
	}
	if not bool(app.call("_enqueue_crew_poker_table_talk", request)):
		failures.append("The production host rejected a valid high-wager Crew conversation request.")
	app.call("_refresh")
	await _settle(5)
	var talk: Dictionary = app.call("current_talk_dock_snapshot")
	if not bool(talk.get("visible", false)) or str(talk.get("speaking_character_id", "")) != member_id:
		failures.append("The high-wager speaker did not open in the existing conversation system.")
	if str(talk.get("voice_line_key", "")) != "poker_heads_up" or str(talk.get("voice_line", "")).is_empty():
		failures.append("The conversation did not resolve the seated character's authored voice.")
	if int(talk.get("choice_count", 0)) != 2 or int(talk.get("ignore_penalty_heat", -1)) != 0:
		failures.append("Friendly table talk choices or consequence-free dismissal were not preserved.")
	if not bool(talk.get("anchored_bottom", false)) or bool(talk.get("anchored_bottom_left", true)):
		failures.append("A left-seat speaker did not place table talk at the established opposite bottom side.")
	var focused_surface: Dictionary = canvas.call("realtime_surface_state")
	var focused := false
	for seat_value in focused_surface.get("seats", []):
		var seat: Dictionary = seat_value
		if str(seat.get("member_id", "")) == member_id:
			focused = bool(seat.get("conversation_active", false))
	if not focused:
		failures.append("The speaking Crew model did not animate as the active conversational focus.")
	var canvas_snapshot: Dictionary = canvas.call("current_view_snapshot")
	for hit_value in canvas_snapshot.get("surface_hit_actions", []):
		if typeof(hit_value) == TYPE_DICTIONARY and str((hit_value as Dictionary).get("action", "")).begins_with("poker_"):
			failures.append("A covered Hold'em action remained selectable behind the open conversation.")
			break
	app.call("_on_talk_dock_choice_requested", str(request.get("event_id", "")), "heads_up_hold_nerve")
	await _settle(5)
	if bool((app.call("current_talk_dock_snapshot") as Dictionary).get("visible", false)):
		failures.append("A valid table-talk response did not close the conversation.")
	var restored_actions := false
	for hit_value in (canvas.call("current_view_snapshot") as Dictionary).get("surface_hit_actions", []):
		if typeof(hit_value) == TYPE_DICTIONARY and str((hit_value as Dictionary).get("action", "")) == "poker_deal":
			restored_actions = true
	if not restored_actions:
		failures.append("Hold'em actions did not return after answering table talk.")
	request["event_id"] = "crew-poker-talk:audit-ignore:%s" % member_id
	request["line_key"] = "poker_big_pot"
	request["node_id"] = "big_pot"
	if not bool(app.call("_enqueue_crew_poker_table_talk", request)):
		failures.append("A second independent table-talk boundary could not be queued.")
	app.call("_refresh")
	await _settle(3)
	var heat_before := run_state.suspicion_level()
	if not bool(app.call("_ignore_talk_event", str(request.get("event_id", "")), "dismiss")):
		failures.append("The table talk could not be dismissed through the normal conversation route.")
	if run_state.suspicion_level() != heat_before:
		failures.append("Dismissing friendly table talk incorrectly generated Heat.")
	app.call("_refresh")
	await _settle(3)
	var betting_evidence := await _exercise_betting_ui(app, canvas, run_state)
	await _finish(app, {"surface_template": surface.get("surface_template", ""), "animated_crew_count": surface.get("animated_crew_count", 0), "speaker": talk.get("speaker", ""), "choice_count": talk.get("choice_count", 0), "anchored_bottom": talk.get("anchored_bottom", false), "anchored_bottom_left": talk.get("anchored_bottom_left", true), "betting": betting_evidence})


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame


func _exercise_betting_ui(app: Control, canvas: Control, run_state: RunState) -> Dictionary:
	var deal_index := _surface_action_index(canvas, "poker_deal")
	if deal_index == MISSING_ACTION_INDEX or not bool(app.call("_handle_module_surface_action", "poker_deal", deal_index, true)):
		failures.append("The visible Deal Hold'em control could not start a hand.")
		return {}
	await _settle(5)
	_check_chip_layout(canvas.call("realtime_surface_state"), "posted blinds")
	if not await _advance_to_player(app, canvas):
		failures.append("Visible Crew decisions did not advance to the player's betting turn.")
		return {}
	var player_state: Dictionary = canvas.call("realtime_surface_state")
	var action_labels: Array = []
	var current_game := app.get("current_game") as GameModule
	for action_value in player_state.get("legal_actions", []):
		var action: Dictionary = action_value
		var action_id := str(action.get("id", ""))
		var label := str(action.get("label", ""))
		action_labels.append(label)
		var surface_action := "poker_raise_open" if action_id == "raise" else "poker_%s" % action_id
		var action_index := _surface_action_index(canvas, surface_action)
		if action_index == MISSING_ACTION_INDEX:
			failures.append("The visible %s option had no selectable hit target." % label)
			continue
		var command: Dictionary = current_game.surface_action_command(surface_action, action_index, true, app.get("game_surface_ui_state"), run_state, run_state.current_environment)
		var command_maps := bool(command.get("handled", false)) and (action_id == "raise" or bool(command.get("resolve", false)) and str(command.get("action_id", "")) == action_id)
		if not command_maps:
			failures.append("Selecting %s did not map to its advertised poker action." % label)
		if action_id in ["call", "all_in"] and not label.contains("$"):
			failures.append("The %s betting option did not state its exact chip amount." % action_id)
	if _surface_action_index(canvas, "poker_tell_style") == MISSING_ACTION_INDEX:
		failures.append("The fake-tell strength selector was not selectable on the player's turn.")
	elif not bool(app.call("_handle_module_surface_action", "poker_tell_style", 1, true)):
		failures.append("The Weak fake-tell option rejected a valid selection.")
	elif str((app.get("game_surface_ui_state") as Dictionary).get("poker_tell_style", "")) != "weak":
		failures.append("Selecting Weak did not update the visible fake-tell choice.")
	var fake_tell_index := _surface_action_index(canvas, "poker_fake_tell")
	if fake_tell_index == MISSING_ACTION_INDEX or not bool(app.call("_handle_module_surface_action", "poker_fake_tell", fake_tell_index, true)):
		failures.append("The visible Fake Tell control could not be selected.")
	await _settle(4)
	if str((canvas.call("realtime_surface_state") as Dictionary).get("turn_owner", "")) != "player":
		failures.append("Fake Tell incorrectly consumed the player's betting turn.")
	var before_raise: Dictionary = canvas.call("realtime_surface_state")
	var raise_open_index := _surface_action_index(canvas, "poker_raise_open")
	if raise_open_index == MISSING_ACTION_INDEX or not bool(app.call("_handle_module_surface_action", "poker_raise_open", raise_open_index, true)):
		failures.append("The visible raise chooser could not be opened.")
		return {"action_labels": action_labels}
	await _settle(3)
	var chooser: Dictionary = canvas.call("realtime_surface_state")
	if not bool(chooser.get("raise_panel_open", false)):
		failures.append("The raise chooser did not remain open after selection (ui=%s)." % JSON.stringify(app.get("game_surface_ui_state")))
	var minimum_raise_to := int(chooser.get("minimum_raise_to", 0))
	var maximum_raise_to := int(chooser.get("maximum_raise_to", 0))
	for selector_action in ["poker_raise_min", "poker_raise_minus_five", "poker_raise_minus_one", "poker_raise_plus_one", "poker_raise_plus_five", "poker_raise_max", "poker_raise_confirm", "poker_raise_cancel"]:
		if _surface_action_index(canvas, selector_action) == MISSING_ACTION_INDEX:
			failures.append("The raise chooser is missing selectable control %s." % selector_action)
	if maximum_raise_to <= minimum_raise_to:
		failures.append("A full-stack raise range was not available to the player.")
	var cancel_index := _surface_action_index(canvas, "poker_raise_cancel")
	if cancel_index == MISSING_ACTION_INDEX or not bool(app.call("_handle_module_surface_action", "poker_raise_cancel", cancel_index, true)):
		failures.append("The raise chooser could not be cancelled.")
	await _settle(3)
	if bool((canvas.call("realtime_surface_state") as Dictionary).get("raise_panel_open", true)):
		failures.append("Cancelling the raise chooser did not restore the normal betting controls.")
	raise_open_index = _surface_action_index(canvas, "poker_raise_open")
	if raise_open_index == MISSING_ACTION_INDEX or not bool(app.call("_handle_module_surface_action", "poker_raise_open", raise_open_index, true)):
		failures.append("The raise chooser could not be reopened after cancellation.")
		return {"action_labels": action_labels}
	await _settle(3)
	var max_index := _surface_action_index(canvas, "poker_raise_max")
	if max_index == MISSING_ACTION_INDEX or not bool(app.call("_handle_module_surface_action", "poker_raise_max", max_index, true)):
		failures.append("The raise chooser could not select the player's full stack.")
	await _settle(2)
	if int((canvas.call("realtime_surface_state") as Dictionary).get("selected_raise_to", 0)) != maximum_raise_to:
		failures.append("Max did not select the exact all-in raise total.")
	for selector_action in ["poker_raise_minus_five", "poker_raise_minus_one"]:
		var selector_index := _surface_action_index(canvas, selector_action)
		if selector_index == MISSING_ACTION_INDEX or not bool(app.call("_handle_module_surface_action", selector_action, selector_index, true)):
			failures.append("The %s control could not adjust the selected raise." % selector_action)
		await _settle(2)
	var expected_below_max := maxi(minimum_raise_to, maximum_raise_to - 6)
	if int((canvas.call("realtime_surface_state") as Dictionary).get("selected_raise_to", 0)) != expected_below_max:
		failures.append("The -$5/-$1 controls did not preserve their exact custom total.")
	var min_index := _surface_action_index(canvas, "poker_raise_min")
	if min_index == MISSING_ACTION_INDEX or not bool(app.call("_handle_module_surface_action", "poker_raise_min", min_index, true)):
		failures.append("The raise chooser could not return to the legal minimum.")
	await _settle(2)
	if int((canvas.call("realtime_surface_state") as Dictionary).get("selected_raise_to", 0)) != minimum_raise_to:
		failures.append("Min did not select the exact minimum full raise.")
	var plus_one_index := _surface_action_index(canvas, "poker_raise_plus_one")
	if plus_one_index == MISSING_ACTION_INDEX or not bool(app.call("_handle_module_surface_action", "poker_raise_plus_one", plus_one_index, true)):
		failures.append("The raise chooser could not select an arbitrary dollar above minimum.")
	await _settle(3)
	var selected_raise_to := int((canvas.call("realtime_surface_state") as Dictionary).get("selected_raise_to", 0))
	if selected_raise_to != minimum_raise_to + 1:
		failures.append("The +$1 raise control did not preserve the exact chosen total.")
	var raise_confirm_index := _surface_action_index(canvas, "poker_raise_confirm")
	if raise_confirm_index == MISSING_ACTION_INDEX or not bool(app.call("_handle_module_surface_action", "poker_raise_confirm", raise_confirm_index, true)):
		failures.append("The selected custom raise could not be confirmed.")
		return {"action_labels": action_labels, "minimum_raise_to": minimum_raise_to, "maximum_raise_to": maximum_raise_to}
	await _settle(5)
	var after_raise: Dictionary = canvas.call("realtime_surface_state")
	_check_chip_layout(after_raise, "player raise")
	var player_round_before := int((before_raise.get("round_contributions", {}) as Dictionary).get("player", 0))
	var expected_raise_cost := selected_raise_to - player_round_before
	if int(after_raise.get("pot", 0)) != int(before_raise.get("pot", 0)) + expected_raise_cost:
		failures.append("The custom raise did not add exactly $%d to the pot ledger." % expected_raise_cost)
	var player_chips_visible := false
	for chip_value in after_raise.get("chip_layout", []):
		if typeof(chip_value) == TYPE_DICTIONARY and str((chip_value as Dictionary).get("owner_id", "")) == "player" and int((chip_value as Dictionary).get("amount", 0)) > 0:
			player_chips_visible = true
	if not player_chips_visible:
		failures.append("The player's selected raise did not appear in front of their seat.")
	var reached_board := await _advance_to_board_street(app, canvas)
	if not reached_board:
		failures.append("A normal check/call path could not reach the community-card streets.")
	else:
		_check_chip_layout(canvas.call("realtime_surface_state"), "community-card street")
	return {"action_labels": action_labels, "minimum_raise_to": minimum_raise_to, "maximum_raise_to": maximum_raise_to, "selected_raise_to": selected_raise_to, "reached_board": reached_board, "raise_pot_before": int(before_raise.get("pot", 0)), "raise_pot_after": int(after_raise.get("pot", 0))}


func _check_chip_layout(state: Dictionary, phase_label: String) -> void:
	var chips: Array = state.get("chip_layout", []) if typeof(state.get("chip_layout", [])) == TYPE_ARRAY else []
	var represented_amount := 0
	var protected := [
		Rect2(305, 158, 286, 70),
		Rect2(385, 245, 126, 81),
		Rect2(513, 283, 18, 18),
		Rect2(138, 337, 548, 35),
		Rect2(697, 346, 150, 27),
		Rect2(70, 382, 760, 34),
		Rect2(92, 173, 142, 16),
		Rect2(535, 131, 128, 16),
		Rect2(664, 173, 142, 16),
	]
	for index in range(chips.size()):
		var chip: Dictionary = chips[index]
		represented_amount += int(chip.get("amount", 0))
		var bounds: Rect2 = chip.get("bounds", Rect2()) if typeof(chip.get("bounds", Rect2())) == TYPE_RECT2 else Rect2()
		if not bounds.has_area():
			failures.append("The %s chip group had no measurable placement bounds." % phase_label)
			continue
		for protected_rect in protected:
			if bounds.intersects(protected_rect):
				failures.append("A %s chip group overlapped cards, labels, or controls." % phase_label)
				break
		for other_index in range(index):
			var other: Dictionary = chips[other_index]
			var other_bounds: Rect2 = other.get("bounds", Rect2()) if typeof(other.get("bounds", Rect2())) == TYPE_RECT2 else Rect2()
			if bounds.intersects(other_bounds):
				failures.append("Two independently owned %s chip groups overlapped." % phase_label)
	if represented_amount != int(state.get("pot", 0)):
		failures.append("The %s chip groups represented $%d of a $%d pot." % [phase_label, represented_amount, int(state.get("pot", 0))])


func _advance_to_player(app: Control, canvas: Control) -> bool:
	for _step in range(12):
		await _answer_visible_talk(app)
		var state: Dictionary = canvas.call("realtime_surface_state")
		if str(state.get("turn_owner", "")) == "player":
			return true
		var observe_index := _surface_action_index(canvas, "poker_observe")
		if observe_index == MISSING_ACTION_INDEX or not bool(app.call("_handle_module_surface_action", "poker_observe", observe_index, true)):
			return false
		await _settle(3)
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
		await _settle(3)
	return false


func _answer_visible_talk(app: Control) -> void:
	var talk: Dictionary = app.call("current_talk_dock_snapshot")
	if not bool(talk.get("visible", false)):
		return
	var choice_ids: Array = talk.get("choice_ids", []) if typeof(talk.get("choice_ids", [])) == TYPE_ARRAY else []
	if not choice_ids.is_empty():
		app.call("_on_talk_dock_choice_requested", str(talk.get("event_id", "")), str(choice_ids[0]))
		await _settle(2)


func _surface_action_index(canvas: Control, action: String) -> int:
	for hit_value in (canvas.call("current_view_snapshot") as Dictionary).get("surface_hit_actions", []):
		if typeof(hit_value) == TYPE_DICTIONARY and str((hit_value as Dictionary).get("action", "")) == action:
			return int((hit_value as Dictionary).get("index", -1))
	return MISSING_ACTION_INDEX


func _finish(app: Control, evidence: Dictionary) -> void:
	print(JSON.stringify({"passed": failures.is_empty(), "failures": failures, "evidence": evidence}))
	if app != null:
		app.queue_free()
		await process_frame
	quit(0 if failures.is_empty() else 1)
