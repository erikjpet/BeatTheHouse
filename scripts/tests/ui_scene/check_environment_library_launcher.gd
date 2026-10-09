extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const DeveloperPlacementStoreScript := preload("res://scripts/core/developer_placement_store.gd")

var app: Control
var failures: Array[String] = []
var settings_path := ""
var placement_paths: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	var temp_root := ProjectSettings.globalize_path("res://.tmp/environment_library_launcher_check")
	DirAccess.make_dir_recursive_absolute(temp_root)
	settings_path = temp_root.path_join("settings.json")
	var placement_user_path := temp_root.path_join("placement_user.json")
	var placement_project_path := temp_root.path_join("placement_project.json")
	var placement_report_path := temp_root.path_join("placement_report.json")
	placement_paths = [
		placement_user_path,
		"%s.bak" % placement_user_path,
		placement_project_path,
		"%s.bak" % placement_project_path,
		placement_report_path,
		"%s.bak" % placement_report_path,
	]
	for path in [settings_path, "%s.bak" % settings_path] + placement_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	OS.set_environment("BTH_USER_SETTINGS_PATH", settings_path)
	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV, placement_user_path)
	OS.set_environment(DeveloperPlacementStoreScript.PROJECT_PATH_ENV, placement_project_path)
	OS.set_environment(DeveloperPlacementStoreScript.REPORT_PATH_ENV, placement_report_path)
	var project_file := FileAccess.open(placement_project_path, FileAccess.WRITE)
	project_file.store_string(JSON.stringify({
		"schema_version": DeveloperPlacementStoreScript.SCHEMA_VERSION,
		"rooms": {},
	}, "\t"))
	project_file.close()
	DeveloperPlacementStoreScript.reload()
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "environment_library_launcher_check")
	root.add_child(app)
	await _settle(4)
	app.call("open_settings_menu")
	await _settle(2)
	var settings_menu := app.get("settings_menu") as Control
	_check(settings_menu != null and settings_menu.visible, "Settings must open before the Environment Library workflow check.")
	if settings_menu != null:
		settings_menu.call("_on_developer_slot_placement_mode", true)
	app.call("_on_settings_environment_library_requested")
	await _settle(3)
	var menu := app.get("environment_test_menu") as Control
	var archetypes := app.get("environment_test_archetype_option") as OptionButton
	var scenarios := app.get("environment_test_scenario_option") as OptionButton
	var next_missing_button := app.get("environment_test_next_missing_button") as Button
	_check(menu != null and menu.is_visible_in_tree(), "The main-menu Environments launcher must open the Environment Library.")
	var user_settings: UserSettings = app.get("user_settings")
	_check(user_settings != null and user_settings.developer_slot_placement_mode, "Opening Environment Library must apply the placement-mode toggle instead of discarding it.")
	_check(archetypes != null and archetypes.item_count >= 18, "The Environment Library must list every environment.")
	_check(
		scenarios != null
			and scenarios.item_count >= 1
			and not _has_metadata(scenarios, "__default")
			and _has_metadata(scenarios, "__none"),
		"Placement-pass scenario choices must expose Base / No Scenario without the unrelated Normal Run Selection alias."
	)
	_check(
		_item_text_for_metadata(scenarios, "__none").begins_with("TODO"),
		"Placement-pass choices must label an unsaved base context as TODO."
	)
	var coverage := DeveloperPlacementStoreScript.coverage_snapshot()
	var missing_layouts: Array = coverage.get("missing_layout_ids", [])
	var next_layout_id := str(coverage.get("next_missing_layout_id", "")).strip_edges()
	if next_layout_id.is_empty() and not missing_layouts.is_empty():
		next_layout_id = str(missing_layouts[0])
	var status_label := app.get("environment_test_status_label") as Label
	_check(
		next_missing_button != null and next_missing_button.visible and not next_missing_button.disabled,
		"Placement mode must expose a prominent enabled Load Next Missing action while coverage is incomplete."
	)
	_check(
		status_label != null and status_label.text.contains("0/75 saved") and status_label.text.contains("Next:"),
		"The Environment Library must show friendly global placement progress and the next missing context."
	)
	if next_missing_button != null:
		next_missing_button.pressed.emit()
	await _settle(5)
	var run_state: RunState = app.get("run_state") as RunState
	_check(
		run_state != null
			and str(app.get("current_screen")) == "ENVIRONMENT"
			and DeveloperPlacementStoreScript.layout_id(run_state.current_environment) == next_layout_id,
		"Load Next Missing must select and spawn the exact next coverage layout."
	)
	var following_layout_id := str(missing_layouts[1]) if missing_layouts.size() > 1 else ""
	var next_canvas := app.get("environment_canvas") as PixelSceneCanvas
	if next_canvas != null:
		var required_families: Array = next_canvas.developer_slot_placement_snapshot().get("required_review_families", [])
		for family_value in required_families:
			next_canvas.set_developer_slot_family_visible(str(family_value), true)
		_check(
			next_canvas.developer_layout_save_next_button.visible
				and not next_canvas.developer_layout_save_next_button.disabled,
			"The generated practice room must enable Save & Load Next after all required family tabs are reviewed."
		)
		next_canvas.developer_layout_save_next_button.pressed.emit()
	await _settle(7)
	run_state = app.get("run_state") as RunState
	var saved_coverage := DeveloperPlacementStoreScript.coverage_snapshot()
	_check(
		int(saved_coverage.get("saved_layout_count", 0)) == 1
			and run_state != null
			and DeveloperPlacementStoreScript.layout_id(run_state.current_environment) == following_layout_id,
		"Save & Load Next must synchronously save the current layout and generate the next missing context without using Leave."
	)
	var active_layout_id := DeveloperPlacementStoreScript.layout_id(run_state.current_environment) if run_state != null else ""
	var next_leave_opened := bool(app.call("activate_interactable_object", "travel:leave"))
	await _settle(3)
	var overlay := app.get("environment_test_overlay") as Control
	_check(
		next_leave_opened and overlay != null and overlay.visible and menu.is_visible_in_tree(),
		"Leaving a next-missing practice room must return to the Environment Library."
	)
	var selected_environment: Dictionary = app.call("_environment_test_current_layout_environment")
	_check(
		DeveloperPlacementStoreScript.layout_id(selected_environment) == active_layout_id,
		"Reopening the Environment Library must preserve the exact environment, scenario, and layer selection."
	)
	_select_metadata(archetypes, "small_underground_casino")
	app.call("_on_environment_test_archetype_selected", archetypes.selected)
	var layered_scenario := app.get("environment_test_scenario_option") as OptionButton
	var layered_area := app.get("environment_test_layer_option") as OptionButton
	_check(
		_metadata_ids(layered_area) == ["club", "casino", "back_room"],
		"The Punchline placement pass must list exactly club, casino, and back_room without a duplicate blank/default-layer alias."
	)
	_select_metadata(layered_scenario, "punchline_high_stakes_night")
	app.call("_on_environment_test_scenario_selected", layered_scenario.selected)
	_check(_selected_metadata(layered_area) == "casino" and layered_area.disabled, "An exact layered scenario must select and lock its authored starting area.")
	_select_metadata(layered_scenario, "__none")
	app.call("_on_environment_test_scenario_selected", layered_scenario.selected)
	_check(not layered_area.disabled, "Base / No Scenario must leave layered starting areas selectable.")
	_select_metadata(layered_area, "club")
	var punchline_result: Dictionary = app.call("start_environment_test_session")
	await _settle(3)
	run_state = app.get("run_state") as RunState
	_check(
		bool(punchline_result.get("ok", false))
			and run_state != null
			and run_state.run_status == RunState.RUN_STATUS_ACTIVE
			and str(app.get("current_screen")) == "ENVIRONMENT",
		"Loading The Punchline comedy club from the Environment Library must remain in the active environment instead of routing to Stranded."
	)
	var punchline_leave_opened := bool(app.call("activate_interactable_object", "travel:leave"))
	await _settle(2)
	_check(
		punchline_leave_opened and overlay != null and overlay.visible and menu.is_visible_in_tree(),
		"The Punchline practice exit must return to the Environment Library."
	)
	_select_metadata(archetypes, "bar")
	app.call("_on_environment_test_archetype_selected", archetypes.selected)
	_select_metadata(app.get("environment_test_scenario_option") as OptionButton, "__none")
	_select_metadata(app.get("environment_test_weather_option") as OptionButton, "rain")
	_select_metadata(app.get("environment_test_day_option") as OptionButton, "payday")
	_select_metadata(app.get("environment_test_happening_mode_option") as OptionButton, "none")
	var first: Dictionary = app.call("start_environment_test_session")
	await _settle(3)
	_check(bool(first.get("ok", false)), "The Environment Library must spawn a selected room through the live UI.")
	run_state = app.get("run_state") as RunState
	_check(str(app.get("current_screen")) == "ENVIRONMENT" and run_state != null, "A successful selection must enter the real environment screen.")
	var environment_canvas := app.get("environment_canvas") as PixelSceneCanvas
	_check(environment_canvas != null and bool(environment_canvas.developer_slot_placement_snapshot().get("enabled", false)), "The room spawned from Settings > Environment Library must open with slot placement mode active.")
	_check(str(run_state.current_environment.get("archetype_id", "")) == "bar", "The live UI must install the selected environment.")
	_check(str((run_state.current_environment.get("town_conditions", {}) as Dictionary).get("weather", "")) == "rain", "The live UI must apply exact condition controls.")
	var first_seed := run_state.seed_text
	var first_scenario_selection := _selected_metadata(app.get("environment_test_scenario_option") as OptionButton)
	var refresh_event := InputEventKey.new()
	refresh_event.keycode = KEY_F5
	refresh_event.pressed = true
	app.call("_input", refresh_event)
	await _settle(4)
	run_state = app.get("run_state") as RunState
	_check(
		run_state != null
			and run_state.seed_text != first_seed
			and run_state.seed_text.begins_with("ENVIRONMENT-PRACTICE-v1:ENVIRONMENT-F5-")
			and str(run_state.current_environment.get("archetype_id", "")) == "bar"
			and _selected_metadata(app.get("environment_test_scenario_option") as OptionButton) == first_scenario_selection
			and str((run_state.current_environment.get("town_conditions", {}) as Dictionary).get("weather", "")) == "rain",
		"F5 in an Environment Library room must reroll the seed while preserving the selected room, scenario configuration, and conditions."
	)
	run_state.bankroll = 777
	run_state.inventory = [{"id": "lucky_keychain"}]
	var leave_opened := bool(app.call("activate_interactable_object", "travel:leave"))
	await _settle(2)
	overlay = app.get("environment_test_overlay") as Control
	_check(leave_opened and overlay != null and overlay.visible and menu.is_visible_in_tree(), "The practice Leave object must reopen the Environment Library instead of the travel map.")
	_check(
		_selected_metadata(archetypes) == "bar"
			and _selected_metadata(app.get("environment_test_scenario_option") as OptionButton) == "__none",
		"Returning from a practice room must preserve the owner's current Environment Library selection."
	)
	_select_metadata(archetypes, "corner_store")
	app.call("_on_environment_test_archetype_selected", archetypes.selected)
	_select_metadata(app.get("environment_test_scenario_option") as OptionButton, "__none")
	var second: Dictionary = app.call("start_environment_test_session")
	await _settle(3)
	run_state = app.get("run_state")
	_check(bool(second.get("ok", false)) and str(run_state.current_environment.get("archetype_id", "")) == "corner_store", "The in-room selector must replace the current practice environment.")
	_check(run_state.bankroll == 777 and run_state.inventory == [{"id": "lucky_keychain"}], "Player money and inventory must carry into later practice environments.")
	var corner_leave_opened := bool(app.call("activate_interactable_object", "travel:leave"))
	await _settle(2)
	_check(corner_leave_opened and menu.is_visible_in_tree(), "The corner-store practice exit must reopen the Environment Library.")
	_select_metadata(archetypes, "pawn_shop")
	app.call("_on_environment_test_archetype_selected", archetypes.selected)
	_select_metadata(app.get("environment_test_scenario_option") as OptionButton, "__none")
	var pawn_shop_result: Dictionary = app.call("start_environment_test_session")
	await _settle(3)
	run_state = app.get("run_state") as RunState
	_check(
		bool(pawn_shop_result.get("ok", false))
			and run_state != null
			and str(run_state.current_environment.get("archetype_id", "")) == "pawn_shop",
		"The Environment Library must spawn Sal's pawn shop."
	)
	run_state.inventory = []
	run_state.add_item("creased_luck_card")
	app.call("_refresh")
	await _settle(3)
	var sal: Dictionary = app.call("_interactable_object", "staff:pawn_counter_sal")
	var sal_action_labels: Array[String] = []
	var sell_action_key := ""
	for descriptor_value in sal.get("attached_room_actions", []):
		if typeof(descriptor_value) == TYPE_DICTIONARY:
			var descriptor := descriptor_value as Dictionary
			var descriptor_label := str(descriptor.get("label", ""))
			sal_action_labels.append(descriptor_label)
			if descriptor_label == "Sell Items":
				sell_action_key = str(descriptor.get("key", ""))
	_check(
		not sal.is_empty() and sal_action_labels.has("Pawn Items") and not sell_action_key.is_empty(),
		"The single visible Sal object must expose clearly named pawn and merchant actions: labels=%s" % str(sal_action_labels)
	)
	var sal_sale_opened := bool(app.call("_activate_attached_room_action", "staff:pawn_counter_sal", sell_action_key))
	await _settle(2)
	var sale_snapshot: Dictionary = app.call("current_run_inventory_snapshot")
	_check(
		sal_sale_opened and bool(sale_snapshot.get("visible", false)) and str(sale_snapshot.get("mode", "")) == "merchant_sale",
		"Sal's Sell Items action must open the merchant-sale interface."
	)
	app.call("close_run_inventory")
	await _settle(1)
	var sal_opened := bool(app.call("activate_interactable_object", "staff:pawn_counter_sal"))
	await _settle(2)
	var pawn_snapshot: Dictionary = app.call("current_run_inventory_snapshot")
	var pawn_item_available := false
	for item_value in pawn_snapshot.get("items", []):
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item := item_value as Dictionary
		if str(item.get("id", "")) == "creased_luck_card" and str(item.get("pawn_action", "")) == "pawn":
			pawn_item_available = true
			break
	_check(
		sal_opened
			and bool(pawn_snapshot.get("visible", false))
			and str(pawn_snapshot.get("mode", "")) == "pawn_counter"
			and str(pawn_snapshot.get("container_id", "")) == "sals_pawn_counter"
			and pawn_item_available,
		"Activating Sal must open his pawn counter with carried pawnable items available: opened=%s visible=%s mode=%s container=%s item=%s" % [
			sal_opened,
			pawn_snapshot.get("visible", false),
			pawn_snapshot.get("mode", ""),
			pawn_snapshot.get("container_id", ""),
			pawn_item_available,
		]
	)
	var pawn_bankroll_before := run_state.bankroll
	app.call("_pawn_counter_pawn_item", "sals_pawn_counter", "creased_luck_card")
	await _settle(3)
	pawn_snapshot = app.call("current_run_inventory_snapshot")
	_check(
		run_state.bankroll > pawn_bankroll_before
			and not run_state.inventory.has("creased_luck_card")
			and not run_state.pawn_tickets_for_lender("sals_pawn_counter").is_empty()
			and bool(pawn_snapshot.get("visible", false))
			and str(pawn_snapshot.get("mode", "")) == "pawn_counter",
		"Sal must accept a pawn transaction and keep the refreshed pawn counter open."
	)
	app.call("close_run_inventory")
	await _settle(1)
	app.call("return_to_main_menu")
	await _settle(2)
	_check(app.get("run_state") == null and not bool(app.get("dev_environment_test_mode")), "Leaving environment practice must return cleanly to the main menu.")
	var inactive_seed_text := (app.get("environment_test_seed_input") as LineEdit).text
	app.call("_input", refresh_event)
	await _settle(1)
	_check(
		app.get("run_state") == null and (app.get("environment_test_seed_input") as LineEdit).text == inactive_seed_text,
		"F5 outside an Environment Library room must remain inert and must not start or reroll a normal run."
	)
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


func _selected_metadata(option: OptionButton) -> String:
	if option == null or option.selected < 0:
		return ""
	return str(option.get_item_metadata(option.selected))


func _has_metadata(option: OptionButton, wanted: String) -> bool:
	if option == null:
		return false
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == wanted:
			return true
	return false


func _item_text_for_metadata(option: OptionButton, wanted: String) -> String:
	if option == null:
		return ""
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == wanted:
			return option.get_item_text(index)
	return ""


func _metadata_ids(option: OptionButton) -> Array[String]:
	var result: Array[String] = []
	if option == null:
		return result
	for index in range(option.item_count):
		result.append(str(option.get_item_metadata(index)))
	return result


func _settle(frames: int) -> void:
	for _frame in range(frames):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	OS.set_environment("BTH_USER_SETTINGS_PATH", "")
	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV, "")
	OS.set_environment(DeveloperPlacementStoreScript.PROJECT_PATH_ENV, "")
	OS.set_environment(DeveloperPlacementStoreScript.REPORT_PATH_ENV, "")
	DeveloperPlacementStoreScript.reload()
	var cleanup_paths: Array[String] = [settings_path, "%s.bak" % settings_path]
	cleanup_paths.append_array(placement_paths)
	for path in cleanup_paths:
		if not path.is_empty() and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if not settings_path.is_empty():
		var temp_root := settings_path.get_base_dir()
		if DirAccess.dir_exists_absolute(temp_root):
			DirAccess.remove_absolute(temp_root)
	print("ENVIRONMENT_LIBRARY_LAUNCHER_CHECK %s" % JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
