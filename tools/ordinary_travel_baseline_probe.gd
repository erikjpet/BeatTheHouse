extends SceneTree

const MainScene := preload("res://scenes/main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var app := MainScene.instantiate() as Control
	root.add_child(app)
	for _frame in range(3):
		await process_frame
	app.call("start_foundation_run", "DELIVERY-ORDINARY-BASELINE")
	for _frame in range(3):
		await process_frame
	var run_state: RunState = app.get("run_state")
	var choices: Array = app.call("current_environment_view_snapshot").get("travel_choices", [])
	var choice: Dictionary = {}
	for choice_value in choices:
		if typeof(choice_value) == TYPE_DICTIONARY and bool((choice_value as Dictionary).get("enabled", false)):
			choice = (choice_value as Dictionary).duplicate(true)
			break
	if choice.is_empty():
		push_error("No ordinary travel choice for baseline.")
		quit(1)
		return
	var target_id := str(choice.get("id", ""))
	var before := {
		"bankroll": run_state.bankroll,
		"heat": run_state.suspicion_level(),
		"clock": run_state.game_clock_minutes,
		"travel_count": run_state.environment_travel_count(),
	}
	if not bool(app.call("select_travel_option", target_id)):
		push_error("Could not select baseline travel.")
		quit(1)
		return
	app.call("confirm_selected_travel")
	for _frame in range(30):
		await process_frame
		if run_state.current_world_node_id() == target_id and not bool(app.get("travel_transition_active")):
			break
	var travel_story: Dictionary = {}
	for entry_value in run_state.story_log:
		if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("type", "")) == "travel":
			travel_story = (entry_value as Dictionary).duplicate(true)
	var result := {
		"provenance_commit": "f4a66f679d1d507c5f79aa02960fb65760d0646b",
		"seed": "DELIVERY-ORDINARY-BASELINE",
		"target_id": target_id,
		"route_choice_sha256": JSON.stringify(choice).sha256_text(),
		"bankroll_delta": run_state.bankroll - int(before.get("bankroll", 0)),
		"heat_delta": run_state.suspicion_level() - int(before.get("heat", 0)),
		"clock_delta": run_state.game_clock_minutes - int(before.get("clock", 0)),
		"travel_count_delta": run_state.environment_travel_count() - int(before.get("travel_count", 0)),
		"current_world_node_id": run_state.current_world_node_id(),
		"current_environment_sha256": JSON.stringify(run_state.current_environment).sha256_text(),
		"world_map_sha256": JSON.stringify(run_state.world_map).sha256_text(),
		"rng_state": run_state.rng_state,
		"town_action_index": int(run_state.town_state.action_index),
		"travel_story_sha256": JSON.stringify(travel_story).sha256_text(),
	}
	print(JSON.stringify(result))
	app.queue_free()
	quit(0)
