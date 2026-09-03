extends "res://scripts/tests/tutorial_dialogue_trigger_cadence_check.gd"


func _init() -> void:
	call_deferred("_run_repeated_reprieve_contract")


func _run_repeated_reprieve_contract() -> void:
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
	var baseline := _blackjack_count_fixture_baseline()
	var independent_baseline := _blackjack_count_fixture_baseline()
	if not bool(baseline.get("valid", false)):
		_fail("Repeated reprieve baseline contract changed: fingerprint=%s heat=%d." % [str(baseline.get("fingerprint", "")), int(baseline.get("heat", -1))])
		return
	if str(independent_baseline.get("fingerprint", "")) != str(baseline.get("fingerprint", "")) \
			or int(independent_baseline.get("heat", -1)) != int(baseline.get("heat", -2)):
		_fail("Fresh repeated reprieve fixtures did not share one normalized semantic baseline: first=%s/%d second=%s/%d." % [str(baseline.get("fingerprint", "")), int(baseline.get("heat", -1)), str(independent_baseline.get("fingerprint", "")), int(independent_baseline.get("heat", -1))])
		return
	if not _blackjack_isolated_repeated_peek_reprieve_is_terminal(baseline):
		return
	_remove_test_file(TEST_META_PATH)
	_remove_test_file(TEST_PROFILE_PATH)
	print("game06_2_repeated_reprieve_contract: PASS")
	quit(0)
