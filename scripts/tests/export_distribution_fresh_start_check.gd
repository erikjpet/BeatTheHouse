extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const PersistencePathsScript := preload("res://scripts/core/persistence_paths.gd")
const ProfileInventoryScript := preload("res://scripts/core/profile_inventory.gd")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const SaveServiceScript := preload("res://scripts/core/save_service.gd")

const TEST_ROOT := "user://distribution_fresh_start_check"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment(PersistencePathsScript.DISTRIBUTION_FEATURE_ENV, "true")
	OS.set_environment(PersistencePathsScript.DISTRIBUTION_ROOT_ENV, TEST_ROOT)
	_remove_test_root()

	var save_service: SaveService = SaveServiceScript.new()
	var expected_paths := {
		"profile": "%s/profile_inventory.json" % TEST_ROOT,
		"collection": "%s/meta_collection.json" % TEST_ROOT,
		"settings": "%s/settings.json" % TEST_ROOT,
		"run": "%s/saves/autosave.json" % TEST_ROOT,
	}
	if ProfileInventoryScript.store_path() != expected_paths["profile"] \
			or MetaCollectionServiceScript.store_path() != expected_paths["collection"] \
			or UserSettingsScript.settings_path() != expected_paths["settings"] \
			or save_service.run_save_path() != expected_paths["run"]:
		_fail("Distribution persistence did not resolve into its isolated namespace: %s" % str(expected_paths))
		return
	for path_value in expected_paths.values():
		if FileAccess.file_exists(str(path_value)):
			_fail("Fresh distribution fixture unexpectedly contained persistent data: %s" % str(path_value))
			return

	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	for _frame in range(5):
		await process_frame
	var profile: ProfileInventory = app.get("profile_inventory")
	var play_button: Button = app.get("new_run_button")
	if profile == null \
			or profile.loaded_from_disk \
			or profile.tutorial_completed \
			or bool(app.call("_has_foundation_save")) \
			or play_button == null \
			or play_button.text != "PLAY":
		_fail("A clean distribution did not open on the fresh Play state.")
		return

	app.call("_on_start_pressed")
	for _frame in range(6):
		await process_frame
	var run_state: RunState = app.get("run_state")
	if run_state == null or not run_state.is_tutorial_run():
		_fail("The first Play press in a clean distribution did not launch the tutorial.")
		return

	var app_save_service: SaveService = app.get("save_service")
	if app_save_service != null:
		app_save_service.wait_for_async_save()
	app.queue_free()
	await process_frame
	_cleanup_environment()
	print("export_distribution_fresh_start_check: PASS")
	quit(0)


func _remove_test_root() -> void:
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	if not DirAccess.dir_exists_absolute(absolute_root):
		return
	_remove_directory_contents(absolute_root)
	DirAccess.remove_absolute(absolute_root)


func _remove_directory_contents(absolute_directory: String) -> void:
	var directory := DirAccess.open(absolute_directory)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var absolute_entry := absolute_directory.path_join(entry)
			if directory.current_is_dir():
				_remove_directory_contents(absolute_entry)
				DirAccess.remove_absolute(absolute_entry)
			else:
				DirAccess.remove_absolute(absolute_entry)
		entry = directory.get_next()
	directory.list_dir_end()


func _cleanup_environment() -> void:
	_remove_test_root()
	OS.set_environment(PersistencePathsScript.DISTRIBUTION_FEATURE_ENV, "")
	OS.set_environment(PersistencePathsScript.DISTRIBUTION_ROOT_ENV, "")


func _fail(message: String) -> void:
	push_error(message)
	_cleanup_environment()
	quit(1)
