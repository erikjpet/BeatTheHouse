extends SceneTree

# Player-path regression for the synchronous Video Poker DRAW boundary. The
# retained histories model a long run, where whole-run sealed proposal copies
# previously made one cabinet click grow into a multi-second stall.

const MainScene := preload("res://scenes/main.tscn")
const SAVE_SLOT := "video_poker_draw_performance_probe"
const MAX_DRAW_INPUT_MSEC := 350.0

var app: Control
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", SAVE_SLOT)
	root.add_child(app)
	await _settle(4)
	if not app.call("start_foundation_run", "VIDEO-POKER-DRAW-PERF"):
		_finish({})
		return
	await _settle(4)
	var run_state: RunState = app.get("run_state")
	run_state.bankroll = 1000000
	_age_run(run_state)
	var environment := _environment_from_archetype(run_state, "delta_queen")
	if environment.is_empty():
		failures.append("Could not build the Video Poker performance room.")
		_finish({})
		return
	environment["game_ids"] = ["video_poker"]
	environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 200}
	environment["game_states"] = {
		"video_poker": {
			"schema": "video_poker_machine_state",
			"version": 3,
			"cabinet_id": "triple_double_bonus",
			"machine_name": "Triple Double Bonus",
			"cabinet_key": "draw-performance-probe",
			"variant_id": "double_double_bonus",
			"paytable_tier_id": "full_pay",
			"coin_denominations": [{"label": "1c", "credits": 1}],
			"denomination_index": 0,
			"multi_hand_count": 3,
			"progressive_meter": 400,
			"holdout_tell": "",
			"hands_played": 0,
			"last_result": {},
		},
	}
	run_state.set_environment(environment)
	app.call("_clear_selected_game_action")
	app.call("clear_interaction_focus")
	app.call("_refresh")
	await _settle(4)
	if not bool(app.call("enter_game", "video_poker", "video_poker")):
		failures.append("Could not enter Video Poker.")
		_finish({})
		return
	await _settle(5)
	var canvas: Control = app.get("game_surface_canvas")
	canvas.emit_signal("surface_action", "video_poker_deal", 0, false)
	await _settle(3)
	var hold_state := _surface_state(canvas)
	if str(hold_state.get("phase", "")) != "hold":
		failures.append("Video Poker did not reach the hold phase before DRAW.")
		_finish({})
		return
	var draw_started_usec := Time.get_ticks_usec()
	canvas.emit_signal("surface_action", "video_poker_draw", 0, false)
	var draw_input_msec := float(Time.get_ticks_usec() - draw_started_usec) / 1000.0
	await _settle(4)
	var settled_state := _surface_state(canvas)
	if str(settled_state.get("phase", "")) != "settled":
		failures.append("Video Poker DRAW did not settle and publish its payout.")
	if draw_input_msec > MAX_DRAW_INPUT_MSEC:
		failures.append("Video Poker DRAW blocked input for %.2f ms (budget %.2f ms)." % [draw_input_msec, MAX_DRAW_INPUT_MSEC])
	var double_up_evidence := await _check_double_up(run_state, canvas)
	_finish({
		"draw_input_msec": draw_input_msec,
		"budget_msec": MAX_DRAW_INPUT_MSEC,
		"story_entries": run_state.story_log.size(),
		"environment_history_entries": run_state.environment_history.size(),
		"phase": str(settled_state.get("phase", "")),
		"hand_result_count": (settled_state.get("hand_results", []) as Array).size() if typeof(settled_state.get("hand_results", [])) == TYPE_ARRAY else 0,
		"double_up": double_up_evidence,
	})


func _age_run(run_state: RunState) -> void:
	var retained_detail := "LONG-RUN-DETAIL-".repeat(32)
	for index in range(240):
		run_state.story_log.append({
			"type": "game_action",
			"game_id": "slot" if index % 2 == 0 else "blackjack",
			"action_id": "aged_action_%d" % index,
			"message": retained_detail,
			"nested": {"index": index, "detail": retained_detail},
		})
	for index in range(256):
		run_state.environment_history.append({
			"id": "aged_room_%d" % index,
			"archetype_id": "bar" if index % 2 == 0 else "grand_casino",
			"display_name": "Aged Room %d" % index,
			"turns": index,
		})


func _environment_from_archetype(run_state: RunState, archetype_id: String) -> Dictionary:
	var library: ContentLibrary = app.get("library")
	var archetype: Dictionary = library.environment_archetype(archetype_id) if library != null else {}
	if archetype.is_empty():
		return {}
	var rng: RngStream = run_state.create_rng("video_poker_draw_performance:%s" % archetype_id)
	var instance := EnvironmentInstance.from_archetype(archetype, 1, rng, library, run_state.challenge_config)
	var environment: Dictionary = instance.to_dict()
	environment["world_node_id"] = archetype_id
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)
	run_state.save_rng(rng)
	return environment


func _surface_state(canvas: Control) -> Dictionary:
	if canvas == null:
		return {}
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	return snapshot.get("state", {}) as Dictionary if typeof(snapshot.get("state", {})) == TYPE_DICTIONARY else {}


func _check_double_up(run_state: RunState, canvas: Control) -> Dictionary:
	var environment := run_state.current_environment.duplicate(true)
	var game_states: Dictionary = environment.get("game_states", {})
	var machine: Dictionary = game_states.get("video_poker", {})
	var hand := [
		{"rank": 11, "suit": 0}, {"rank": 11, "suit": 1}, {"rank": 5, "suit": 2},
		{"rank": 8, "suit": 3}, {"rank": 13, "suit": 0},
	]
	machine["last_result"] = {
		"hand": hand, "hands": [hand],
		"hand_results": [{"hand": hand, "pay_key": "jacks_or_better", "pay_label": "Jacks or Better", "total": 10}],
		"pay_key": "jacks_or_better", "pay_label": "Jacks or Better", "bet_level": 4,
		"coin_count": 5, "coin_value": 1, "bet_credits": 5, "gross_credits": 10,
		"win_credits": 5, "double_credits": 5, "double_chain": 0,
		"bankroll_delta": 5, "summary": "Jacks or Better. Paid 10 credits.",
	}
	game_states["video_poker"] = machine
	environment["game_states"] = game_states
	run_state.current_environment = environment
	app.call("_clear_selected_game_action")
	app.set("game_surface_ui_state", {})
	app.call("_refresh")
	await _settle(3)
	canvas.emit_signal("surface_action", "video_poker_double", 0, false)
	await _settle(3)
	var open_phase := str(_surface_state(canvas).get("phase", ""))
	canvas.emit_signal("surface_action", "video_poker_double_pick", 2, false)
	await _settle(3)
	var settled_surface := _surface_state(canvas)
	var settled_phase := str(settled_surface.get("phase", ""))
	var last_result: Dictionary = app.get("last_game_result")
	if open_phase != "double_up" or settled_phase == "double_up":
		failures.append("Video Poker double-up regressed while optimizing DRAW: %s -> %s (%s)." % [open_phase, settled_phase, str(last_result.get("message", ""))])
	return {
		"open_phase": open_phase,
		"settled_phase": settled_phase,
		"result_ok": bool(last_result.get("ok", false)),
		"result_message": str(last_result.get("message", "")),
		"error_code": str(last_result.get("error_code", "")),
		"selected_actions": settled_surface.get("native_selected_surface_actions", []),
		"surface_blocks": settled_surface.get("surface_action_blocks", []),
		"deferred_refresh_pending": bool(app.get("deferred_embedded_refresh_pending")),
		"message": str((app.get("message_label") as Label).text) if app.get("message_label") is Label else "",
	}


func _settle(frames: int) -> void:
	for _frame in range(frames):
		await process_frame


func _finish(evidence: Dictionary) -> void:
	print(JSON.stringify({
		"tool": "video_poker_draw_performance_probe",
		"passed": failures.is_empty(),
		"failures": failures,
		"evidence": evidence,
	}, "\t"))
	if app != null:
		app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
