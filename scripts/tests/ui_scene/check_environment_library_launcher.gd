extends SceneTree

const MainScene := preload("res://scenes/main.tscn")

var app: Control
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "environment_library_launcher_check")
	root.add_child(app)
	await _settle(4)
	app.call("open_environment_test_menu")
	await _settle(3)
	var menu := app.get("environment_test_menu") as Control
	var archetypes := app.get("environment_test_archetype_option") as OptionButton
	var scenarios := app.get("environment_test_scenario_option") as OptionButton
	_check(menu != null and menu.is_visible_in_tree(), "The main-menu Environments launcher must open the Environment Library.")
	_check(archetypes != null and archetypes.item_count >= 18, "The Environment Library must list every environment.")
	_check(scenarios != null and scenarios.item_count >= 2, "Every environment must include normal and base scenario choices.")
	_select_metadata(archetypes, "bar")
	app.call("_on_environment_test_archetype_selected", archetypes.selected)
	_select_metadata(app.get("environment_test_scenario_option") as OptionButton, "__none")
	_select_metadata(app.get("environment_test_weather_option") as OptionButton, "rain")
	_select_metadata(app.get("environment_test_day_option") as OptionButton, "payday")
	_select_metadata(app.get("environment_test_happening_mode_option") as OptionButton, "none")
	var first: Dictionary = app.call("start_environment_test_session")
	await _settle(3)
	_check(bool(first.get("ok", false)), "The Environment Library must spawn a selected room through the live UI.")
	var run_state: RunState = app.get("run_state")
	_check(str(app.get("current_screen")) == "ENVIRONMENT" and run_state != null, "A successful selection must enter the real environment screen.")
	_check(str(run_state.current_environment.get("archetype_id", "")) == "bar", "The live UI must install the selected environment.")
	_check(str((run_state.current_environment.get("town_conditions", {}) as Dictionary).get("weather", "")) == "rain", "The live UI must apply exact condition controls.")
	run_state.bankroll = 777
	run_state.inventory = [{"id": "lucky_keychain"}]
	var leave_opened := bool(app.call("activate_interactable_object", "travel:leave"))
	await _settle(2)
	var overlay := app.get("environment_test_overlay") as Control
	_check(leave_opened and overlay != null and overlay.visible and menu.is_visible_in_tree(), "The practice Leave object must reopen the Environment Library instead of the travel map.")
	_select_metadata(archetypes, "corner_store")
	app.call("_on_environment_test_archetype_selected", archetypes.selected)
	_select_metadata(app.get("environment_test_scenario_option") as OptionButton, "__none")
	var second: Dictionary = app.call("start_environment_test_session")
	await _settle(3)
	run_state = app.get("run_state")
	_check(bool(second.get("ok", false)) and str(run_state.current_environment.get("archetype_id", "")) == "corner_store", "The in-room selector must replace the current practice environment.")
	_check(run_state.bankroll == 777 and run_state.inventory == [{"id": "lucky_keychain"}], "Player money and inventory must carry into later practice environments.")
	app.call("return_to_main_menu")
	await _settle(2)
	_check(app.get("run_state") == null and not bool(app.get("dev_environment_test_mode")), "Leaving environment practice must return cleanly to the main menu.")
	_finish()


func _select_metadata(option: OptionButton, wanted: String) -> void:
	if option == null:
		_fail("Missing selector for %s." % wanted)
		return
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == wanted:
			option.select(index)
			return
	_fail("Selector did not contain %s." % wanted)


func _settle(frames: int) -> void:
	for _frame in range(frames):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	print("ENVIRONMENT_LIBRARY_LAUNCHER_CHECK %s" % JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
