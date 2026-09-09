extends SceneTree

# Production-host audit for the Hold'em room, animated Crew projections, and
# high-wager conversation handoff. It intentionally uses the game-library
# launcher so the same canvas and TalkDock boundaries as a player are exercised.

const MainScene := preload("res://scenes/main.tscn")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")

var failures: Array[String] = []


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
		_finish(app, {})
		return
	await _settle(8)
	var library := app.get("library") as ContentLibrary
	var canvas := app.get("game_surface_canvas") as Control
	var run_state := app.get("run_state") as RunState
	if library == null or canvas == null or run_state == null:
		failures.append("The production host did not expose the Hold'em content, canvas, and run state.")
		_finish(app, {})
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
	_finish(app, {"surface_template": surface.get("surface_template", ""), "animated_crew_count": surface.get("animated_crew_count", 0), "speaker": talk.get("speaker", ""), "choice_count": talk.get("choice_count", 0), "anchored_bottom": talk.get("anchored_bottom", false), "anchored_bottom_left": talk.get("anchored_bottom_left", true)})


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame


func _finish(app: Control, evidence: Dictionary) -> void:
	print(JSON.stringify({"passed": failures.is_empty(), "failures": failures, "evidence": evidence}))
	if app != null:
		app.queue_free()
		await process_frame
	quit(0 if failures.is_empty() else 1)
