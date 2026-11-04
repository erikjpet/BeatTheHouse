extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const SLOT := "pull_tab_machine_save_check"
var failures: Array[String] = []
var checks := 0
var completed := false

func _initialize() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty():
		completed = true
		push_error("Pull Tabs save check requires an explicitly isolated distribution root")
		quit(1)
		return
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _pile(run: RunState) -> Dictionary:
	return run.portable_ticket_state("pull_tabs", run.current_environment)

func _snapshot(run: RunState) -> Dictionary:
	var machine: Dictionary = run.current_environment.get("game_states", {}).get("pull_tabs", {})
	return JSON.parse_string(JSON.stringify({
		"pile": _pile(run), "cash": run.bankroll, "chips": run.grand_casino_chips,
		"rng": str(run.rng_state), "heat": run.suspicion_level(),
		"tickets_sold": machine.get("tickets_sold", 0), "deals": machine.get("deals", []),
	}))

func _expected_path() -> String:
	return SaveService.new().run_save_path(SLOT).get_base_dir().path_join("pull_tab_expected.json")

func _verify_slot(slot: String, expected: Dictionary) -> void:
	var loaded: RunState = SaveService.new().load_run(slot)
	_check(loaded != null, slot + " is not loadable")
	if loaded != null:
		_check(_snapshot(loaded) == expected, slot + " changed ticket/stock/wallet/heat/RNG")
		_check(_pile(loaded).get("tray_stack", []).is_empty() and _pile(loaded).get("ticket_stack", []).size() == 1, slot + " lost collected custody")

func _run() -> void:
	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", SLOT)
	root.add_child(app)
	for _frame in range(4):
		await process_frame
	app.get("user_settings").coach_tips_enabled = false
	if OS.get_cmdline_user_args().has("--cold"):
		var expected_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(_expected_path()))
		if typeof(expected_value) != TYPE_DICTIONARY or (expected_value as Dictionary).is_empty():
			_check(false, "cold check requires the retained warm-phase receipt")
			await _finish(app)
			return
		var expected: Dictionary = expected_value
		for slot in [SLOT, SLOT + "_floor"]:
			_verify_slot(slot, expected)
			app.set("autosave_slot_id", slot)
			_check(bool(app.call("load_foundation_run")), slot + " cold Continue failed")
			var resumed: RunState = app.get("run_state")
			_check(resumed != null and _snapshot(resumed) == expected, slot + " cold host changed saved state")
			_check(bool(app.call("enter_game", "pull_tabs")), slot + " cold machine entry failed")
			app.call("_on_game_surface_action", "pull_tab_collect_tray", 0, false)
			_check(_snapshot(app.get("run_state")) == expected, slot + " repeat Collect changed state")
		await _finish(app)
		return
	_check(bool(app.call("start_foundation_run", "BTH061-STABILITY-B")), "run start failed")
	_check(bool(app.call("select_travel_option", "bar")) and bool(app.call("confirm_selected_travel", true)), "normal travel failed")
	var run: RunState = app.get("run_state")
	print("PULLTAB_ROOM ", run.current_environment.get("game_ids", []))
	_check(bool(app.call("enter_game", "pull_tabs")), "enter Pull Tabs failed")
	if app.get("current_game") != null:
		var before := run.bankroll
		app.call("_on_game_surface_action", "pull_tab_buy", 1, false)
		for _frame in range(6):
			await process_frame
		print("PULLTAB_PURCHASE wallet=", run.bankroll, " pile=", JSON.stringify(_pile(run)))
		_check(run.bankroll == before - 2 and _pile(run).get("tray_stack", []).size() == 1, "one normal $2 purchase failed")
		app.call("_on_game_surface_action", "pull_tab_collect_tray", 0, false)
		print("PULLTAB_COLLECT wallet=", run.bankroll, " pile=", JSON.stringify(_pile(run)))
		_check(_pile(run).get("ticket_stack", []).size() == 1 and _pile(run).get("tray_stack", []).is_empty(), "warm collection failed")
		var expected := _snapshot(run)
		app.call("open_run_menu")
		app.call("save_run_from_menu")
		print("PULLTAB_SAVE status=", app.get("save_status_message"), " menu=", app.get("run_menu_overlay").visible)
		_check(not bool(app.get("run_menu_overlay").visible), "machine Menu Save was not accepted")
		_verify_slot(SLOT, expected)
		_check(bool(app.call("load_foundation_run")), "warm Continue failed")
		_check(_snapshot(app.get("run_state")) == expected, "warm Continue changed ticket/stock/wallet/heat/RNG")
		_check(bool(app.call("enter_game", "pull_tabs")), "warm machine re-entry failed")
		app.call("_on_game_surface_action", "pull_tab_collect_tray", 0, false)
		_check(_snapshot(app.get("run_state")) == expected, "repeat Collect changed state")
		app.call("back_to_environment")
		app.set("autosave_slot_id", SLOT + "_floor")
		app.call("open_run_menu")
		app.call("save_run_from_menu")
		_check(not bool(app.get("run_menu_overlay").visible), "floor Menu Save was not accepted")
		_verify_slot(SLOT + "_floor", expected)
		var file := FileAccess.open(_expected_path(), FileAccess.WRITE)
		_check(file != null, "expected-state receipt write failed")
		if file != null:
			file.store_string(JSON.stringify(expected))
			file.close()
	await _finish(app)

func _finish(app: Control) -> void:
	app.get("save_service").wait_for_async_save()
	app.queue_free()
	for _frame in range(8):
		await process_frame
	completed = true
	print("PULL_TAB_MACHINE_SAVE cold=", OS.get_cmdline_user_args().has("--cold"), " checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func _finalize() -> void:
	if not completed:
		push_error("Pull Tabs machine save check exited before completion")
