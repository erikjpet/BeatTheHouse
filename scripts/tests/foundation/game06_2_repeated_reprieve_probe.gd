extends "res://scripts/tests/tutorial_dialogue_trigger_cadence_check.gd"


func _init() -> void:
	call_deferred("_run_repeated_reprieve_probe")


func _run_repeated_reprieve_probe() -> void:
	OS.set_environment("BTH_META_COLLECTION_PATH", TEST_META_PATH)
	OS.set_environment("BTH_PROFILE_INVENTORY_PATH", TEST_PROFILE_PATH)
	_remove_test_file(TEST_META_PATH)
	_remove_test_file(TEST_PROFILE_PATH)
	root.content_scale_size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.set("autosave_slot_id", TEST_SAVE_SLOT)
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	await _settle(8)
	app.call("start_tutorial_run")
	await _settle(10)
	var run_state: RunState = app.get("run_state")
	if run_state == null:
		_fail("Repeated reprieve probe could not start a tutorial run.")
		return
	var baseline := _blackjack_count_fixture_baseline(run_state)
	if not _blackjack_isolated_repeated_peek_reprieve_is_terminal(baseline):
		return
	var save_service: SaveService = app.get("save_service")
	if save_service != null:
		save_service.clear_run(TEST_SAVE_SLOT)
	_remove_test_file(TEST_META_PATH)
	_remove_test_file(TEST_PROFILE_PATH)
	print("game06_2_repeated_reprieve_probe: PASS")
	quit(0)
