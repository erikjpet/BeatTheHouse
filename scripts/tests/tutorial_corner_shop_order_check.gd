extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const ProfileInventoryScript := preload("res://scripts/core/profile_inventory.gd")

const TEST_SETTINGS_PATH := "user://tutorial_corner_shop_settings.json"
const TEST_META_PATH := "user://tutorial_corner_shop_meta.json"
const TEST_PROFILE_PATH := "user://tutorial_corner_shop_profile.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_prepare_isolated_stores()
	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	await process_frame
	await process_frame
	app.call("_on_start_pressed")
	await process_frame
	var run_state: RunState = app.get("run_state")
	if run_state == null or not run_state.is_tutorial_run():
		_fail("Corner-shop regression could not start the tutorial run.")
		return
	var completed := {
		"tutorial_apartment_xray": true,
		"tutorial_inventory_xray": true,
		"tutorial_open_map_corner": true,
		"tutorial_travel_corner": true,
	}
	run_state.narrative_flags["tutorial_lessons_completed"] = completed.duplicate(true)
	run_state.retire_pending_talk_events()
	var coach_overlay: Control = app.get("coach_overlay")
	coach_overlay.call("begin_tutorial_run", completed)
	var generator: RunGenerator = app.get("generator")
	generator.next_environment(run_state, "corner_store", true)
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_refresh")
	await process_frame
	await process_frame
	var coach: Dictionary = coach_overlay.call("current_snapshot")
	if str(coach.get("lesson_id", "")) != "tutorial_inspect_coffee":
		_fail("Corner Store did not begin on Coffee inspection: %s" % str(coach))
		return
	var environment_canvas: Control = app.get("environment_canvas")
	var coffee_rect: Rect2 = environment_canvas.call("global_rect_for_object", "item:instant_coffee")
	var pencil_rect: Rect2 = environment_canvas.call("global_rect_for_object", "item:ledger_pencil")
	var talk_rect := _rect((app.call("current_talk_dock_snapshot") as Dictionary).get("occupied_rect", {}))
	if not coffee_rect.has_area() or not pencil_rect.has_area() or talk_rect.intersects(coffee_rect) or talk_rect.intersects(pencil_rect):
		_fail("Pal covered a highlighted shelf target: talk=%s coffee=%s pencil=%s" % [str(talk_rect), str(coffee_rect), str(pencil_rect)])
		return
	# Exercise the formerly softlocking route: inspect and purchase Pencil while
	# the Coffee inspection is still active, then return to Coffee.
	if not bool(app.call("focus_interactable_object", "item:ledger_pencil")) \
			or not bool(app.call("activate_interactable_object", "item:ledger_pencil")):
		_fail("Ledger Pencil could not be purchased first.")
		return
	await process_frame
	if not run_state.inventory.has("ledger_pencil") or str(coach_overlay.call("active_lesson_id")) != "tutorial_inspect_coffee":
		_fail("Early Pencil purchase did not preserve the pending Coffee lesson.")
		return
	if not bool(app.call("focus_interactable_object", "item:instant_coffee")):
		_fail("Coffee could not be inspected after Pencil was removed from the shelf.")
		return
	for _frame in range(5):
		await process_frame
	coach = coach_overlay.call("current_snapshot")
	if str(coach.get("lesson_id", "")) != "tutorial_buy_remaining_store_item" \
			or str(coach.get("anchor_id", "")) != "item:instant_coffee":
		_fail("Wrong-order recovery did not point to the remaining Coffee: %s" % str(coach))
		return
	app.call("_sync_coach_environment_anchor_geometry")
	coach = coach_overlay.call("current_snapshot")
	var coffee_action_rect: Rect2 = environment_canvas.call("global_rect_for_selected_object_action", "item:instant_coffee")
	var coffee_anchor_rect := _rect(coach.get("anchor_rect", {}))
	talk_rect = _rect((app.call("current_talk_dock_snapshot") as Dictionary).get("occupied_rect", {}))
	if not coffee_action_rect.has_area() \
			or coffee_anchor_rect.position.distance_to(coffee_action_rect.position) > 0.75 \
			or coffee_anchor_rect.size.distance_to(coffee_action_rect.size) > 0.75 \
			or talk_rect.intersects(coffee_action_rect):
		_fail("Remaining Coffee action was covered or highlighted out of alignment: action=%s talk=%s coach=%s" % [str(coffee_action_rect), str(talk_rect), str(coach)])
		return
	if not bool(app.call("activate_interactable_object", "item:instant_coffee")):
		_fail("Remaining Coffee could not be purchased.")
		return
	for _frame in range(4):
		await process_frame
	if not run_state.inventory.has("instant_coffee") \
			or not run_state.inventory.has("ledger_pencil") \
			or str(coach_overlay.call("active_lesson_id")) != "tutorial_crew_warning":
		_fail("Tutorial advanced without both shop items: inventory=%s lesson=%s" % [str(run_state.inventory), str(coach_overlay.call("active_lesson_id"))])
		return
	var performed: Dictionary = run_state.narrative_flags.get("tutorial_actions_performed", {}) if typeof(run_state.narrative_flags.get("tutorial_actions_performed", {})) == TYPE_DICTIONARY else {}
	if performed.has("item:instant_coffee") or performed.has("item:ledger_pencil"):
		_fail("Completed shelf actions remained recorded and could affect a later lesson: %s" % str(performed))
		return
	print("TUTORIAL CORNER SHOP ORDER CHECK PASS")
	_cleanup()
	quit(0)


func _prepare_isolated_stores() -> void:
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, TEST_SETTINGS_PATH)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, TEST_META_PATH)
	OS.set_environment(ProfileInventoryScript.INVENTORY_PATH_ENV, TEST_PROFILE_PATH)
	_cleanup()
	var settings: UserSettings = UserSettingsScript.new()
	settings.reset()
	settings.save()


func _cleanup() -> void:
	for path in [TEST_SETTINGS_PATH, TEST_META_PATH, TEST_PROFILE_PATH]:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)


func _rect(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = value
	if data.has("position") and data.has("size"):
		return Rect2(data.get("position", Vector2.ZERO), data.get("size", Vector2.ZERO))
	return Rect2(
		Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))),
		Vector2(float(data.get("w", data.get("width", 0.0))), float(data.get("h", data.get("height", 0.0))))
	)


func _fail(message: String) -> void:
	push_error(message)
	_cleanup()
	quit(1)
