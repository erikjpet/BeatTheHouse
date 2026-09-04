extends SceneTree

# Opt-in integration reproduction for the Foundation-to-RunState Crew Play
# authority seam. This intentionally exits non-zero while a successful player-
# facing game entry fails to bind current_environment.active_game_id.

const MainScene := preload("res://scenes/main.tscn")


func _init() -> void:
	call_deferred("_run_reproduction")


func _run_reproduction() -> void:
	var app_value: Variant = MainScene.instantiate()
	if not app_value is Control:
		_finish({"failure": "Main scene did not instantiate FoundationMain."}, false)
		return
	var app: Control = app_value
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	await process_frame
	await process_frame
	if not app.has_method("uses_foundation_runtime") or not bool(app.call("uses_foundation_runtime")):
		_finish({"failure": "Main scene did not initialize FoundationMain."}, false)
		return
	app.call("start_foundation_run", "INTEG06-1-CREW-PLAY-ENTRY", {}, false)
	await process_frame
	await process_frame
	var run: Variant = app.get("run_state")
	if run == null:
		_finish({"failure": "FoundationMain did not create RunState."}, false)
		return
	run.call("crew_add_trust", "crew_switch", 1000, "integ06_1_entry_repro")
	var environment := {
		"id": "integ06_1_grand_casino_table",
		"archetype_id": "grand_casino",
		"world_node_id": "grand_casino",
		"kind": "casino",
		"game_ids": ["blackjack"],
		"crew_presence": [{"member_id": "crew_switch", "rank": "made", "line": "integ06_1_entry_repro"}],
		"game_states": {"blackjack": {"schema": "blackjack_table_state", "running_count": 0, "recorded_running_count": 0}},
		"economic_profile": {"stake_floor": 5, "stake_ceiling": 100},
		"security_profile": {"strictness": "high"},
		"turns": 0,
	}
	run.set("current_environment", environment)
	var entered := bool(app.call("enter_game", "blackjack", "blackjack"))
	await process_frame
	var game: Variant = app.get("current_game")
	var current_game_id := ""
	if game != null:
		var definition: Variant = game.get("definition")
		if typeof(definition) == TYPE_DICTIONARY:
			current_game_id = str((definition as Dictionary).get("id", ""))
	var entered_environment: Dictionary = (run.get("current_environment") as Dictionary).duplicate(true)
	var unbound_action_ids := _action_ids(game.call("legal_actions", run, entered_environment) if game != null else [])
	var activation_before_binding: Dictionary = run.call("crew_play_activate", "spotter", "blackjack", entered_environment)

	var bound_environment := entered_environment.duplicate(true)
	bound_environment["active_game_id"] = "blackjack"
	run.set("current_environment", bound_environment)
	var bound_action_ids := _action_ids(game.call("legal_actions", run, bound_environment) if game != null else [])
	var entry_is_real := entered and current_game_id == "blackjack" and str(app.get("current_screen")) == "GAME"
	var unreachable := entry_is_real \
		and str(entered_environment.get("active_game_id", "")).is_empty() \
		and not unbound_action_ids.has("crew_play:spotter") \
		and not bool(activation_before_binding.get("ok", false)) \
		and bound_action_ids.has("crew_play:spotter")
	var report := {
		"schema": "beat_the_house.integ06_1_crew_play_entry_reproduction/v1",
		"version": 1,
		"foundation_entry_success": entry_is_real,
		"current_screen": str(app.get("current_screen")),
		"current_game_id": current_game_id,
		"active_game_id_after_entry": str(entered_environment.get("active_game_id", "")),
		"crew_action_ids_after_entry": unbound_action_ids,
		"activation_after_entry_ok": bool(activation_before_binding.get("ok", false)),
		"activation_after_entry_message": str(activation_before_binding.get("message", "")),
		"crew_action_ids_with_required_binding_control": bound_action_ids,
		"regression_reproduced": unreachable,
		"required_smallest_fix": "Foundation game entry must bind current_environment.active_game_id to the entered game before GameModule.enter/legal_actions, and clear that binding on every game-exit path.",
	}
	app.queue_free()
	await process_frame
	_finish(report, not unreachable)


func _action_ids(actions_value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(actions_value) != TYPE_ARRAY:
		return result
	for action_value in actions_value:
		if typeof(action_value) != TYPE_DICTIONARY:
			continue
		var action_id := str((action_value as Dictionary).get("id", "")).strip_edges()
		if not action_id.is_empty():
			result.append(action_id)
	return result


func _finish(report: Dictionary, passed: bool) -> void:
	report["passed"] = passed
	print("INTEG06_1_CREW_PLAY_ENTRY_REPRO=%s" % JSON.stringify(report))
	if not passed:
		push_error("INTEG06_1 CREW PLAY ENTRY REPRO FAIL: Foundation entry leaves Crew Play unreachable.")
	quit(0 if passed else 1)
