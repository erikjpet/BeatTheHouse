extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const SLOT := "foundation_ui_autosave"

class BusySaveService extends SaveService:
	func save_run(_state: RunState, _slot: String = "autosave") -> Error:
		return ERR_BUSY

class UnsettledGame extends GameModule:
	func foundation_save_ready(_state: RunState, _environment: Dictionary) -> bool:
		return false

var failures: Array[String] = []
var suite_root := ""
var case_number := 0
var completed := false


func _init() -> void:
	call_deferred("_run")


func _finalize() -> void:
	# An exit regression must not turn an early quit(0) into a passing check.
	if not completed:
		push_error("Save-navigation check exited before completing its recovery cases.")


func _run() -> void:
	suite_root = ProjectSettings.globalize_path("user://save_navigation_durability_%d" % OS.get_process_id())
	await _check_paid_drop("BTH061-STABILITY-B", "bar")
	await _check_paid_drop("BTH061-STABILITY-D", "corner_store", true)
	await _check_storage_failure()
	await _check_terminal_new_run_failure()
	await _check_interrupted_settle_failure()
	await _check_forced_save_results()
	completed = true
	if failures.is_empty():
		print("SAVE_NAVIGATION_DURABILITY PASS paid_drop_seeds=2 storage_failure_recovery=true interrupted_settle_recovery=true forced_save_results=true")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _open_app() -> Control:
	case_number += 1
	var profile := suite_root.path_join("case_%d" % case_number)
	DirAccess.make_dir_recursive_absolute(profile)
	OS.set_environment("BTH_DISTRIBUTION_BUILD", "1")
	OS.set_environment("BTH_DISTRIBUTION_DATA_ROOT", profile)
	OS.set_environment("BTH_USER_SETTINGS_PATH", profile.path_join("settings.json"))
	OS.set_environment("BTH_PROFILE_INVENTORY_PATH", profile.path_join("inventory.json"))
	OS.set_environment("BTH_META_COLLECTION_PATH", profile.path_join("meta.json"))
	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	for _frame in range(4):
		await process_frame
	app.get("user_settings").coach_tips_enabled = false
	return app


func _close_app(app: Control) -> void:
	for _frame in range(8):
		await process_frame
	var service: SaveService = app.get("save_service")
	if service != null:
		service.wait_for_async_save()
	app.queue_free()
	for _frame in range(12):
		await process_frame


func _start_at(app: Control, seed: String, destination: String) -> bool:
	if not bool(app.call("start_foundation_run", seed)):
		_check(false, "%s did not start." % seed)
		return false
	if not bool(app.call("select_travel_option", destination)) or not bool(app.call("confirm_selected_travel", true)):
		_check(false, "%s could not travel normally to %s." % [seed, destination])
		return false
	return true


func _paid_drop(app: Control) -> bool:
	if not bool(app.call("enter_game", "coin_pusher")):
		_check(false, "Generated room did not expose Coin Pusher.")
		return false
	var state: RunState = app.get("run_state")
	var before := state.bankroll
	# The production pointer-intent path owns the price, claim, native input and
	# result. This is a lifecycle regression, not a substituted solver fixture.
	app.call("_on_game_surface_pointer_action", "coin_pusher_drop_charge", -1, "begin", Vector2(576, 374))
	app.call("_on_game_surface_pointer_action", "coin_pusher_drop_charge", -1, "end", Vector2(576, 374))
	var game: GameModule = app.get("current_game")
	var paid := state.bankroll == before - 1 and not game.foundation_save_ready(state, state.current_environment)
	_check(paid, "The production drop did not debit one unit and leave unsettled authority.")
	return paid


func _check_paid_drop(seed: String, destination: String, empty_projection: bool = false) -> void:
	var app := await _open_app()
	if not _start_at(app, seed, destination):
		await _close_app(app)
		return
	_check(bool(app.call("_autosave_foundation_run", "Baseline.", true)), "%s baseline did not save." % seed)
	if not _paid_drop(app):
		await _close_app(app)
		return
	var state: RunState = app.get("run_state")
	var game: GameModule = app.get("current_game")
	app.call("open_run_menu")
	app.call("save_run_from_menu")
	_check(bool(app.get("run_menu_overlay").visible), "Deferred manual Save dismissed the menu as if it were durable.")
	if empty_projection:
		app.set("game_surface_ui_state", {})
	var leave_result: Variant = app.call("return_to_main_menu")
	var left: bool = typeof(leave_result) == TYPE_BOOL and leave_result == true
	_check(left and app.get("run_state") == null, "%s Main Menu did not finish a durable exit." % seed)
	var expected_digest := str(game.call("deterministic_state_digest", state.current_environment))
	var saved: RunState = app.get("save_service").load_run(SLOT)
	_check(saved != null, "%s has no loadable final save." % seed)
	if saved != null:
		_check(saved.bankroll == state.bankroll, "%s rolled back the paid drop's cash." % seed)
		_check(saved.rng_state == state.rng_state, "%s changed RNG across the final write." % seed)
		var actual_digest := str(game.call("deterministic_state_digest", saved.current_environment))
		# Disk JSON normalizes integral floats; compare the complete parsed
		# projection so numeric formatting cannot masquerade as lost physics.
		var same_machine: bool = JSON.parse_string(actual_digest) == JSON.parse_string(expected_digest)
		if not same_machine:
			for pair in [["expected", expected_digest], ["actual", actual_digest]]:
				var file := FileAccess.open(suite_root.path_join("%s_%s_machine.json" % [seed, pair[0]]), FileAccess.WRITE)
				file.store_string(str(pair[1]))
				file.close()
		_check(same_machine, "%s lost settled machine/tray authority." % seed)
		_check(bool(app.call("load_foundation_run")), "%s Continue rejected the final save." % seed)
		var resumed: RunState = app.get("run_state")
		_check(resumed != null and resumed.bankroll == state.bankroll, "%s Continue restored older cash." % seed)
	await _close_app(app)


func _block_save_directory(app: Control) -> Dictionary:
	var service: SaveService = app.get("save_service")
	service.wait_for_async_save()
	var save_dir := ProjectSettings.globalize_path(service.run_save_path(SLOT)).get_base_dir()
	var retained := save_dir + "-retained"
	var fingerprints := {}
	for suffix in ["", ".bak"]:
		var path: String = service.run_save_path(SLOT) + suffix
		if FileAccess.file_exists(path):
			fingerprints[suffix] = FileAccess.get_sha256(path)
	_check(DirAccess.rename_absolute(save_dir, retained) == OK, "Could not retain the isolated save directory.")
	var blocker := FileAccess.open(save_dir, FileAccess.WRITE)
	if blocker != null:
		blocker.store_string("save-navigation-contract-owned-blocker")
		blocker.close()
	else:
		_check(false, "Could not create the isolated storage fault.")
	return {"path":save_dir, "retained":retained, "fingerprints":fingerprints}


func _restore_save_directory(blocked: Dictionary) -> void:
	var path := str(blocked.path)
	if FileAccess.get_file_as_string(path) == "save-navigation-contract-owned-blocker":
		DirAccess.remove_absolute(path)
	_check(DirAccess.rename_absolute(str(blocked.retained), path) == OK, "Could not restore the isolated save directory.")
	for suffix in blocked.fingerprints:
		_check(FileAccess.get_sha256(path.path_join(SLOT + ".json" + suffix)) == str(blocked.fingerprints[suffix]), "Failed navigation changed the retained primary/backup.")


func _check_storage_failure() -> void:
	var app := await _open_app()
	_check(bool(app.call("start_foundation_run", "BTH061-SAVE-FAILURE")), "Storage case did not start.")
	_check(bool(app.call("_autosave_foundation_run", "Baseline.", true)), "Storage case baseline did not save.")
	var blocked := _block_save_directory(app)
	var state: RunState = app.get("run_state")
	var original_cash := state.bankroll
	_check(bool(app.call("select_travel_option", "bar")) and bool(app.call("confirm_selected_travel", true)), "Storage case normal travel failed.")
	var latest_cash := state.bankroll
	_check(latest_cash < original_cash, "Storage case did not create paid unsaved progress.")
	app.call("open_run_menu")
	var leave_result: Variant = app.call("return_to_main_menu")
	_check(leave_result != true, "Main Menu accepted an unsuccessful save.")
	var retained: bool = app.get("run_state") == state
	_check(retained, "Main Menu discarded the unsaved live run.")
	if retained:
		app.call("exit_game")
		app.notification(Control.NOTIFICATION_WM_CLOSE_REQUEST)
		_check(not auto_accept_quit, "The engine still accepts native close before save recovery.")
		_check(app.get("run_state") == state, "Exit/native close discarded the unsaved run.")
		app.call("_on_run_report_home_requested")
		_check(app.get("run_state") == state and not bool(app.get("meta_session_active")), "Home replaced the run after rejected Main Menu navigation.")
	_restore_save_directory(blocked)
	if retained:
		app.call("save_run_from_menu")
		_check(not bool(app.get("run_menu_overlay").visible), "Successful retry did not dismiss the save menu.")
		_check(bool(app.call("return_to_main_menu")), "Save recovery could not return to Main Menu.")
		_check(bool(app.call("load_foundation_run")), "Save recovery could not Continue.")
		_check(app.get("run_state").bankroll == latest_cash, "Save recovery restored the old bankroll.")
	await _close_app(app)


func _check_terminal_new_run_failure() -> void:
	var app := await _open_app()
	_check(bool(app.call("start_foundation_run", "BTH061-TERMINAL-SAVE-FAILURE")), "Terminal storage case did not start.")
	_check(bool(app.call("_autosave_foundation_run", "Baseline.", true)), "Terminal storage baseline did not save.")
	var blocked := _block_save_directory(app)
	var state: RunState = app.get("run_state")
	state.bankroll = 0
	state.run_status = RunState.RUN_STATUS_FAILED
	state.run_failure_reason = RunState.FAILURE_BANKROLL_ZERO
	state.run_failure_message = "Terminal save-recovery fixture."
	app.call("_route_failed_run_if_needed", {"message": state.run_failure_message})
	app.call("_on_run_report_new_run_requested")
	var retained: bool = app.get("run_state") == state
	_check(retained, "New Run discarded a terminal run after its checkpoint failed.")
	_restore_save_directory(blocked)
	if retained:
		app.call("_on_run_report_new_run_requested")
		_check(app.get("run_state") != state, "New Run could not continue after storage recovery.")
		var saved: RunState = app.get("save_service").load_run(SLOT)
		_check(saved != null and saved.seed_text == state.seed_text and saved.is_terminal(), "New Run replaced the failed terminal checkpoint with an older active save.")
	await _close_app(app)


func _check_interrupted_settle_failure() -> void:
	var app := await _open_app()
	if not _start_at(app, "BTH061-STABILITY-B", "bar"):
		await _close_app(app)
		return
	_check(bool(app.call("_autosave_foundation_run", "Baseline.", true)), "Settle case baseline did not save.")
	if not _paid_drop(app):
		await _close_app(app)
		return
	var state: RunState = app.get("run_state")
	var game: GameModule = app.get("current_game")
	var blocked := _block_save_directory(app)
	app.call("back_to_environment")
	await process_frame
	_check(bool(app.get("game_exit_settle_active")), "Settle race did not reach the yielded exit boundary.")
	app.call("return_to_main_menu")
	var retained: bool = app.get("run_state") == state
	_check(retained, "Rejected navigation lost the settling run.")
	if retained:
		for _frame in range(8):
			await process_frame
		_check(not bool(app.get("game_exit_settle_active")), "Rejected navigation retained an obsolete exit coroutine.")
		_check(app.get("current_game") == game and str(app.get("current_screen")) == "GAME", "Old settle coroutine navigated after save rejection.")
	_restore_save_directory(blocked)
	if retained:
		_check(bool(app.call("return_to_main_menu")), "Settled live state was not recoverable for retry.")
	await _close_app(app)


func _check_forced_save_results() -> void:
	var app := await _open_app()
	_check(bool(app.call("start_foundation_run", "BTH061-SAVE-RESULTS")), "Result case did not start.")
	app.get("save_service").wait_for_async_save()
	app.set("current_game", UnsettledGame.new())
	_check(not bool(app.call("_autosave_foundation_run", "Forced.", true)), "Forced save reported success for unsettled state.")
	_check(bool(app.call("_autosave_foundation_run", "Queued.", false)), "Ordinary unsettled autosave rejected queueing.")
	app.set("current_game", null)
	app.set("save_service", BusySaveService.new())
	_check(not bool(app.call("_write_foundation_run_save", "Forced.", true)), "Synchronous ERR_BUSY reported a durable save.")
	_check(bool(app.get("pending_autosave")), "Busy final save lost its retryable dirty state.")
	await _close_app(app)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
