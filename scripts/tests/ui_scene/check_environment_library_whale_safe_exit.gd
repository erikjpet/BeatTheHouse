extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const DeveloperPlacementStoreScript := preload("res://scripts/core/developer_placement_store.gd")

var app: Control
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	var temp_root := ProjectSettings.globalize_path("res://.tmp/environment_library_whale_safe_exit_check")
	DirAccess.make_dir_recursive_absolute(temp_root)
	OS.set_environment("BTH_USER_SETTINGS_PATH", temp_root.path_join("settings.json"))
	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV, temp_root.path_join("placement_user.json"))
	DeveloperPlacementStoreScript.reload()
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "environment_library_whale_safe_exit_check")
	root.add_child(app)
	await _settle(4)
	app.call("open_settings_menu")
	await _settle(2)
	var settings_menu := app.get("settings_menu") as Control
	if settings_menu != null:
		settings_menu.call("_on_developer_slot_placement_mode", true)
	app.call("_on_settings_environment_library_requested")
	await _settle(3)
	var archetypes := app.get("environment_test_archetype_option") as OptionButton
	_select_metadata(archetypes, "delta_queen")
	app.call("_on_environment_test_archetype_selected", archetypes.selected)
	var scenarios := app.get("environment_test_scenario_option") as OptionButton
	_select_metadata(scenarios, "delta_queen_whale_aboard")
	app.call("_on_environment_test_scenario_selected", scenarios.selected)
	var result: Dictionary = app.call("start_environment_test_session")
	await _settle(5)
	_check(bool(result.get("ok", false)), "Whale Aboard must load in Environment Library repair mode.")
	var records: Array = app.call("_interactable_object_view_list")
	var safe_exit := _record(records, "scenario::delta_queen_whale_aboard_safe_exit")
	_check(not safe_exit.is_empty(), "Whale Aboard's safe exit must remain a visible room record.")
	_check(not (safe_exit.get("available_actions", []) as Array).is_empty(), "Whale Aboard's visible safe exit must retain its action directly.")
	_finish()


func _record(records: Array, object_id: String) -> Dictionary:
	for value in records:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("object_id", "")) == object_id:
			return value as Dictionary
	return {}


func _select_metadata(option: OptionButton, wanted: String) -> void:
	if option == null:
		failures.append("Missing selector for %s." % wanted)
		return
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == wanted:
			option.select(index)
			return
	failures.append("Selector did not contain %s." % wanted)


func _settle(frames: int) -> void:
	for _frame in range(frames):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ENVIRONMENT_LIBRARY_WHALE_SAFE_EXIT_CHECK PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
