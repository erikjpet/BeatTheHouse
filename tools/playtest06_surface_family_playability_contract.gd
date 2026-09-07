extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const ProfileInventoryScript := preload("res://scripts/core/profile_inventory.gd")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")

const TEST_SETTINGS_PATH := "user://playtest06_surface_family_settings.json"
const TEST_META_COLLECTION_PATH := "user://playtest06_surface_family_meta.json"
const TEST_PROFILE_INVENTORY_PATH := "user://playtest06_surface_family_profile.json"

const REPRESENTATIVES := [
	{"family": "novelty", "game_id": "pull_tabs"},
	{"family": "slots", "game_id": "slot"},
	{"family": "dice", "game_id": "bar_dice"},
	{"family": "cards", "game_id": "video_poker"},
	{"family": "wheel", "game_id": "roulette"},
	{"family": "coin_pusher", "game_id": "coin_pusher"},
]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, TEST_SETTINGS_PATH)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, TEST_META_COLLECTION_PATH)
	OS.set_environment(ProfileInventoryScript.INVENTORY_PATH_ENV, TEST_PROFILE_INVENTORY_PATH)
	var isolated_settings: UserSettings = UserSettingsScript.new()
	isolated_settings.reset()
	if isolated_settings.save() != OK:
		push_error("Could not prepare isolated playtest settings.")
		quit(1)
		return
	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	await process_frame
	await process_frame

	var passed: Array[String] = []
	for representative in REPRESENTATIVES:
		var family := str(representative.get("family", ""))
		var game_id := str(representative.get("game_id", ""))
		var start_result: Dictionary = app.call("start_game_test_session", game_id)
		await process_frame
		await process_frame
		if not bool(start_result.get("ok", false)):
			failures.append("%s/%s could not open: %s" % [family, game_id, str(start_result.get("errors", []))])
			continue
		var screen: Dictionary = app.call("current_screen_snapshot")
		var before_view: Dictionary = app.call("current_game_view_snapshot")
		if str(screen.get("screen", "")) != "GAME" or str(before_view.get("game_id", "")) != game_id:
			failures.append("%s/%s did not become the active game surface." % [family, game_id])
			continue
		var canvas: Control = app.get("game_surface_canvas")
		if canvas == null or not canvas.visible:
			failures.append("%s/%s opened without a visible owned surface." % [family, game_id])
			continue
		var before_state := JSON.stringify(app.call("serialized_run_state"))
		var before_surface := JSON.stringify(canvas.call("current_view_snapshot"))
		var before_result := JSON.stringify(app.get("last_game_result"))
		app.call("_on_game_surface_action", "surface_legal", 0, true)
		await process_frame
		await process_frame
		var after_state := JSON.stringify(app.call("serialized_run_state"))
		var after_surface := JSON.stringify(canvas.call("current_view_snapshot"))
		var after_result := JSON.stringify(app.get("last_game_result"))
		if before_state == after_state and before_surface == after_surface and before_result == after_result:
			failures.append("%s/%s opened but its primary play action produced no surface, result, or run-state change." % [family, game_id])
			continue
		passed.append("%s=%s" % [family, game_id])

	app.queue_free()
	await process_frame
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		print("PLAYTEST06_SURFACE_FAMILY FAIL passed=%s failures=%s" % [str(passed), str(failures)])
		quit(1)
		return
	print("PLAYTEST06_SURFACE_FAMILY PASS %s" % ", ".join(passed))
	quit(0)
