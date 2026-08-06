extends "res://tools/tutorial_guided_run_capture.gd"

const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")


func _init() -> void:
	call_deferred("_run_nonoverlap_check")


func _run_nonoverlap_check() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	await _settle(8)
	app.call("start_tutorial_run")
	await _settle(10)
	var run_state: RunState = app.get("run_state")
	if run_state == null:
		_fail("Tutorial target check could not start a run.")
		return

	_clear_guide_state()
	_stage_environment("gas_station_casino")
	if not run_state.inventory.has("xray_glasses"):
		run_state.add_item("xray_glasses")
	app.call("enter_game", "pull_tabs", "pull_tabs")
	await _settle(8)
	_stage_guide_lesson("tutorial_gas_xray_buy")
	await _settle(8)
	if not _active_target_is_clear("pull-tab Buy"):
		return
	app.call("_on_game_surface_action", "pull_tab_buy", 0, false)
	await _settle(8)
	if str(app.get("coach_overlay").call("active_anchor_id")) != "pull_tab_collect_tray":
		_fail("Pull-tab lesson did not move its highlight to the collection tray.")
		return
	if not _active_target_is_clear("pull-tab collection tray"):
		return

	_clear_guide_state()
	_stage_environment("small_underground_casino")
	app.call("enter_game", "blackjack", "blackjack")
	await _settle(8)
	_stage_blackjack_raised_bet_surface()
	_stage_guide_lesson("tutorial_blackjack_raise")
	await _settle(8)
	if str(app.get("coach_overlay").call("active_anchor_id")) != "surface_stake_up":
		_fail("Blackjack raise lesson did not highlight the chip control.")
		return
	if not _active_target_is_clear("blackjack chip control"):
		return
	if not _game_surface_freeze_keeps_presentation_alive():
		return
	if not _tutorial_runtime_dialogue_interventions_work():
		return
	_clear_guide_state()
	app.set("game_surface_ui_state", {})
	app.call("_refresh")
	await _settle(8)
	var stake_before_raise := int(app.call("_current_selected_stake"))
	app.call("_on_game_surface_action", "surface_stake_up", -1, false)
	await _settle(8)
	var stake_after_raise := int(app.call("_current_selected_stake"))
	if stake_after_raise <= stake_before_raise:
		_fail("Blackjack tutorial chip control did not increase the wager through the live surface-action route.")
		return

	print("tutorial_talk_target_nonoverlap_check: PASS")
	quit(0)


func _game_surface_freeze_keeps_presentation_alive() -> bool:
	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.size = Vector2(900, 420)
	root.add_child(canvas)
	canvas.call("render_game_snapshot", {
		"game_id": "blackjack",
		"surface_renderer": "blackjack",
		"surface_time_msec": 5000,
		"surface_animates_idle": true,
		"reduce_motion": false,
	})
	canvas.call("set_environment_activity_paused", true)
	var before: Dictionary = canvas.call("current_view_snapshot")
	for _frame_index in range(12):
		canvas.call("_process", 1.0 / 60.0)
	var after: Dictionary = canvas.call("current_view_snapshot")
	var simulation_frozen := int(after.get("surface_simulation_time_msec", -2)) == int(before.get("surface_simulation_time_msec", -1))
	var presentation_alive := int(after.get("surface_animation_redraw_count", -2)) > int(before.get("surface_animation_redraw_count", -1))
	canvas.queue_free()
	if not simulation_frozen or not presentation_alive:
		_fail("Pal freeze did not separate blackjack logic time from environment presentation animation: before=%s after=%s." % [str(before), str(after)])
		return false
	return true


func _tutorial_runtime_dialogue_interventions_work() -> bool:
	_clear_guide_state()
	var run_state: RunState = app.get("run_state")
	run_state.suspicion["level"] = 98
	run_state.add_suspicion("tutorial_heat_ui_fixture", 8)
	app.call("_evaluate_run_terminal_state")
	app.call("_refresh_talk_dock")
	var heat_entry := run_state.next_pending_talk_event()
	if run_state.suspicion_level() != RunState.TUTORIAL_HEAT_INTERVENTION_LEVEL \
		or str(heat_entry.get("dialogue_id", "")) != "tutorial_pal_guidance" \
		or str(heat_entry.get("current_node", "")) != "heat_99" \
		or not bool(app.call("_simulation_progression_paused")):
		_fail("Tutorial Heat did not cool to 75 and queue a freezing Pal intervention: heat=%d entry=%s." % [run_state.suspicion_level(), str(heat_entry)])
		return false
	_clear_guide_state()
	if not bool(app.call("_enqueue_tutorial_dialogue_without_refresh", "tutorial_blackjack_dealer_reprieve", "warning", "tutorial_intervention:blackjack_peek_reprieve", "tutorial_intervention", "Fixture Dealer")):
		_fail("Tutorial caught-Peek result could not enqueue the authored dealer reprieve dialogue.")
		return false
	app.call("_refresh_talk_dock")
	var dealer_entry := run_state.next_pending_talk_event()
	if str(dealer_entry.get("dialogue_id", "")) != "tutorial_blackjack_dealer_reprieve" \
		or str((dealer_entry.get("speaker", {}) as Dictionary).get("name", "")) != "Fixture Dealer" \
		or bool(app.call("_simulation_progression_paused")):
		_fail("Dealer reprieve did not take priority without inheriting Pal's tutorial freeze: %s." % str(dealer_entry))
		return false
	return true


func _active_target_is_clear(label: String) -> bool:
	var dock_snapshot: Dictionary = app.get("talk_dock").call("current_snapshot")
	var coach_snapshot: Dictionary = app.get("coach_overlay").call("current_snapshot")
	var occupied: Rect2 = dock_snapshot.get("occupied_rect", Rect2())
	var target := _snapshot_rect(coach_snapshot.get("anchor_rect", {}))
	if not bool(dock_snapshot.get("visible", false)) or not target.has_area():
		_fail("%s fixture did not expose both Pal and the live highlight." % label)
		return false
	if occupied.intersects(target.grow(10.0)):
		_fail("Pal overlapped the highlighted %s: talk=%s target=%s." % [label, str(occupied), str(target)])
		return false
	return true


func _snapshot_rect(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = value
	return Rect2(
		Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))),
		Vector2(float(data.get("w", data.get("width", 0.0))), float(data.get("h", data.get("height", 0.0))))
	)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
