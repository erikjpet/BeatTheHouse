extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const ProfileInventoryScript := preload("res://scripts/core/profile_inventory.gd")

const TEST_SETTINGS_PATH := "user://terminal_run_resume_settings.json"
const TEST_META_PATH := "user://terminal_run_resume_meta.json"
const TEST_PROFILE_PATH := "user://terminal_run_resume_profile.json"
const TERMINAL_CHECKPOINT_FLAG := "terminal_resume_checkpoint_saved"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, TEST_SETTINGS_PATH)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, TEST_META_PATH)
	OS.set_environment(ProfileInventoryScript.INVENTORY_PATH_ENV, TEST_PROFILE_PATH)
	for path in [TEST_SETTINGS_PATH, TEST_META_PATH, TEST_PROFILE_PATH]:
		_remove_file_family(path)
	var settings := UserSettingsScript.new()
	settings.reset()
	if settings.save() != OK:
		push_error("Terminal resume check could not prepare isolated settings.")
		quit(1)
		return
	if not await _check_terminal_resume(RunState.RUN_STATUS_ENDED, "VICTORY", "terminal_resume_victory"):
		quit(1)
		return
	if not await _check_terminal_resume(RunState.RUN_STATUS_FAILED, "FAILURE", "terminal_resume_failure"):
		quit(1)
		return
	print("Terminal run resume check passed.")
	quit(0)


func _check_terminal_resume(status: String, expected_screen: String, slot_id: String) -> bool:
	var source_app: Control = MainScene.instantiate()
	source_app.set("continuous_environment_clock_enabled", false)
	root.add_child(source_app)
	await process_frame
	await process_frame
	var source_save_service: SaveService = source_app.get("save_service")
	if source_save_service == null or source_save_service.clear_run(slot_id) != OK:
		push_error("Terminal resume check could not prepare slot %s." % slot_id)
		source_app.queue_free()
		return false
	source_app.set("autosave_slot_id", slot_id)
	if not bool(source_app.call("start_foundation_run", "TERMINAL-RESUME-%s" % expected_screen, {}, false)):
		push_error("Terminal resume check could not start its %s fixture." % expected_screen)
		source_app.queue_free()
		return false
	var source_run: RunState = source_app.get("run_state")
	source_run.run_status = status
	if status == RunState.RUN_STATUS_ENDED:
		source_run.narrative_flags["demo_victory"] = true
		source_run.narrative_flags["demo_victory_message"] = "Terminal resume victory fixture."
		source_app.call("_route_ended_run_if_needed", {"message": "Terminal resume victory fixture."})
	else:
		source_run.run_failure_reason = RunState.FAILURE_BANKROLL_ZERO
		source_run.run_failure_message = "Terminal resume failure fixture."
		source_app.call("_route_failed_run_if_needed", {"message": source_run.run_failure_message})
	await process_frame
	var saved_run: Variant = source_save_service.load_run(slot_id)
	if saved_run == null \
			or saved_run.run_status != status \
			or not bool(saved_run.narrative_flags.get(TERMINAL_CHECKPOINT_FLAG, false)):
		push_error("%s did not synchronously persist its terminal Resume Slot checkpoint." % expected_screen)
		source_save_service.clear_run(slot_id)
		source_app.queue_free()
		return false
	source_app.queue_free()
	await process_frame
	await process_frame

	var resumed_app: Control = MainScene.instantiate()
	resumed_app.set("continuous_environment_clock_enabled", false)
	root.add_child(resumed_app)
	await process_frame
	await process_frame
	resumed_app.set("autosave_slot_id", slot_id)
	resumed_app.call("_refresh_start_screen")
	await process_frame
	var continue_button: Button = resumed_app.get("continue_button")
	if continue_button == null or continue_button.disabled or continue_button.text != "CONTINUE":
		push_error("%s terminal checkpoint was not offered as Continue." % expected_screen)
		(resumed_app.get("save_service") as SaveService).clear_run(slot_id)
		resumed_app.queue_free()
		return false
	if not bool(resumed_app.call("start_or_continue_primary")):
		push_error("Continue could not load the %s terminal checkpoint." % expected_screen)
		(resumed_app.get("save_service") as SaveService).clear_run(slot_id)
		resumed_app.queue_free()
		return false
	await process_frame
	await process_frame
	var resumed_run: RunState = resumed_app.get("run_state")
	var snapshot: Dictionary = resumed_app.call("current_screen_snapshot")
	var report: Dictionary = snapshot.get("run_report", {}) if typeof(snapshot.get("run_report", {})) == TYPE_DICTIONARY else {}
	if resumed_run == null or resumed_run.run_status != status \
			or str(snapshot.get("screen", "")) != expected_screen \
			or report.is_empty():
		push_error("Continue did not route the %s checkpoint directly to its end screen: %s" % [expected_screen, JSON.stringify(snapshot)])
		(resumed_app.get("save_service") as SaveService).clear_run(slot_id)
		resumed_app.queue_free()
		return false
	var cleanup_error := (resumed_app.get("save_service") as SaveService).clear_run(slot_id)
	resumed_app.queue_free()
	await process_frame
	return cleanup_error == OK


func _remove_file_family(path: String) -> void:
	for candidate in [path, "%s.bak" % path, "%s.tmp" % path]:
		var absolute_path := ProjectSettings.globalize_path(candidate)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
