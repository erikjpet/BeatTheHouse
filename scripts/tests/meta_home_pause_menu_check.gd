extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var isolated_root := OS.get_environment("BTH_SAVE_DIR")
	if isolated_root.is_empty():
		printerr("This check requires the isolated native runner.")
		quit(1)
		return
	isolated_root = isolated_root.path_join("meta_pause_%d" % OS.get_process_id())
	for key in ["BTH_SAVE_DIR", "BTH_DISTRIBUTION_DATA_ROOT"]:
		OS.set_environment(key, isolated_root.path_join(key))
	for key in ["BTH_USER_SETTINGS_PATH", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH"]:
		OS.set_environment(key, isolated_root.path_join(key + ".json"))
	var app := MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("script_prewarm_stopping", true)
	root.add_child(app)
	await process_frame
	await process_frame
	app.call("open_meta_home")
	await process_frame
	_check(bool(app.call("_is_meta_session")), "Fixture did not enter real Home mode.")
	var state: RunState = app.get("run_state")
	var before := state.to_dict()
	app.call("_refresh_run_menu")
	var status: Label = app.get("run_menu_status_label")
	var save_button: Button = app.get("run_menu_save_button")
	var abandon_button: Button = app.get("run_menu_abandon_button")
	_check(save_button.disabled, "Home exposes a Save action rejected by its existing save guard.")
	_check(abandon_button.disabled, "Home exposes Abandon for its temporary session.")
	_check(status.text.contains("Home") and not status.text.contains("Bankroll") and not status.text.contains("META-HOME"), "Home menu leaks the temporary run's seed/Bankroll100.")
	_check(status.text.contains("automatically") and status.text.contains("Resume Slot"), "Home menu does not explain separate profile/run saving.")
	_check(not bool(app.call("_autosave_foundation_run", "Meta test", true)), "Existing Home save guard did not reject a run-slot save.")
	_check(state.to_dict() == before, "Home menu or rejected save mutated game state.")
	var normal := RunState.new()
	normal.start_new("NORMAL-PAUSE-MENU")
	normal.bankroll = 39
	normal.current_environment = {"id": "normal_menu_fixture", "archetype_id": "bar", "display_name": "Normal Venue"}
	app.set("meta_session_active", false)
	app.set("run_state", normal)
	app.call("_refresh_run_menu")
	_check(not save_button.disabled and not abandon_button.disabled, "Ordinary active run lost its Save/Abandon controls.")
	_check(status.text.contains("Bankroll 39") and status.text.contains("NORMAL-PAUSE-MENU"), "Ordinary run status changed.")
	_check(normal.bankroll == 39 and normal.run_status == RunState.RUN_STATUS_ACTIVE, "Menu refresh changed ordinary run state.")
	app.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty(): print("META_HOME_PAUSE_MENU PASS checks=%d home_and_normal=true existing_save_guard=true state_unchanged=true" % checks)
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
