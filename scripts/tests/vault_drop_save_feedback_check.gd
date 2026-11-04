extends SceneTree

# Independent normal-host regression; never reads/replays the R04 paid drop.
const MainScene := preload("res://scenes/main.tscn")
# Source-only cabinet-type qualification, not paid-result selection: FNV64
# abs2798434022198271472 -> RNG seed1781198789 -> roll81 -> Vault (71..100).
const SEED := "BTH061-VAULT-SAVE-001-F"
class BusySaveService extends SaveService:
	func save_run(_state: RunState, _slot: String = "autosave") -> Error:
		return ERR_BUSY

var failures: Array[String] = []
var checks := 0
var completed := false
var private_root := ""

func _initialize() -> void:
	private_root = OS.get_environment("BTH_VAULT_SAVE_PRIVATE_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	if private_root.is_empty() or not private_root.is_absolute_path() or not _inside(ProjectSettings.globalize_path("user://")) or OS.has_feature("web") or not OS.get_environment("BTH_PROJECT_PLACEMENT_PATH").is_empty():
		completed = true
		push_error("Vault check requires native user:// inside an explicit private root and shipped project placement")
		quit(1)
		return
	for key in ["BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_USER_SETTINGS_PATH", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_DEVELOPER_PLACEMENT_PATH", "BTH_DEVELOPER_PLACEMENT_REPORT_PATH"]:
		var value := OS.get_environment(key)
		if not value.is_empty() and not _inside(ProjectSettings.globalize_path(value)):
			completed = true
			push_error("Nonprivate persistence override: " + key)
			quit(1)
			return
	call_deferred("_run")

func _inside(path: String) -> bool:
	var normalized := path.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()
	return not private_root.is_empty() and (normalized == private_root.to_lower() or normalized.begins_with(private_root.to_lower() + "/"))

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
	return ok

func _open_app(case_id: String) -> Control:
	var profile := private_root.path_join(case_id)
	OS.set_environment("BTH_DISTRIBUTION_BUILD", "1")
	OS.set_environment("BTH_DISTRIBUTION_DATA_ROOT", profile)
	for pair in [["BTH_SAVE_DIR", "saves"], ["BTH_USER_SETTINGS_PATH", "settings.json"], ["BTH_PROFILE_INVENTORY_PATH", "inventory.json"], ["BTH_META_COLLECTION_PATH", "meta.json"], ["BTH_DEVELOPER_PLACEMENT_PATH", "placement.json"], ["BTH_DEVELOPER_PLACEMENT_REPORT_PATH", "placement_report.json"]]:
		var target := profile.path_join(pair[1])
		if not _check(_inside(target), "Computed persistence path escaped the private case"):
			return null
		OS.set_environment(pair[0], target)
	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	for _frame in range(4):
		await process_frame
	app.get("user_settings").coach_tips_enabled = false
	var path := ProjectSettings.globalize_path(app.get("save_service").run_save_path(str(app.get("autosave_slot_id"))))
	if not _check(_inside(path) and path.replace("\\", "/").begins_with(profile + "/saves/"), "Actual SaveService path escaped the private case"):
		await _close_app(app)
		return null
	return app

func _await_publication(app: Control) -> void:
	for _frame in range(12):
		await process_frame
		if int(app.get("room_publication_checked_generation")) >= int(app.get("room_publication_generation")) and not bool(app.get("travel_transition_active")):
			break

func _route_facts(app: Control) -> String:
	var run: RunState = app.get("run_state")
	var proof: Dictionary = run.validate_room_action_authority() if run != null else {}
	var message: Variant = app.get("message_label")
	return JSON.stringify({"screen": app.get("current_screen"), "node": run.current_world_node_id() if run != null else "", "clock": run.game_clock_minutes if run != null else -1, "message": str(message.text) if message != null else "", "modal": app.call("_blocking_modal_message"), "targets": app.call("_travel_target_ids"), "corner_choice": app.call("_travel_choice", "corner_store"), "authority_ok": proof.get("ok", false), "authority_errors": proof.get("errors", []), "publication": [app.get("room_publication_generation"), app.get("room_publication_checked_generation")]})

func _after_refusal_menu(_app: Control) -> void:
	pass # Optional rendered helper overrides this; the base check does not yield.

func _additional_completion_checks() -> void:
	pass # Optional rendered helper qualifies captures before the base exit.

func _close_app(app: Control) -> void:
	app.get("save_service").wait_for_async_save()
	app.queue_free()
	for _frame in range(8):
		await process_frame

func _disk(app: Control) -> Dictionary:
	var path: String = app.get("save_service").run_save_path(str(app.get("autosave_slot_id")))
	return {"primary": FileAccess.get_sha256(path), "backup": FileAccess.get_sha256(path + ".bak") if FileAccess.file_exists(path + ".bak") else ""}

func _snapshot(run: RunState, game: GameModule, live: bool = false) -> Dictionary:
	var machine: Dictionary = JSON.parse_string(str(game.call("deterministic_state_digest", run.current_environment)))
	var session := {}
	if live:
		var active: Dictionary = game.get("_live_machines").get(str(game.call("_live_key", run, run.current_environment)), {})
		machine = game.call("_digest_state", active)
		var inputs: Dictionary = active.get("live_session", {})
		session = {"input_trace": inputs.get("input_trace", []), "input_cursor": inputs.get("input_cursor", 0), "durable_ready": inputs.get("durable_ready", false), "drop_queue": active.get("drop_queue", []), "paid_drop_pending": active.get("paid_drop_pending", false)}
	return JSON.parse_string(JSON.stringify({"cash": run.bankroll, "chips": run.grand_casino_chips, "heat": run.suspicion_level(), "rng": str(run.rng_state), "clock": run.game_clock_minutes, "inventory": run.inventory, "machine": machine, "live_inputs": session}))

func _verify_loaded(app: Control, expected: Dictionary, label: String) -> void:
	var slot := str(app.get("autosave_slot_id"))
	app.call("_ensure_full_content_library_loaded")
	var game: GameModule = app.call("_game_module_for_id", "coin_pusher")
	if not _check(game != null, label + " normal production module unavailable"):
		return
	var loaded: RunState = SaveService.new().load_run(slot)
	_check(loaded != null and _snapshot(loaded, game) == expected, label + " fresh-service load changed wallet/RNG/clock/full settled Vault/tray")
	if _check(bool(app.call("load_foundation_run")), label + " normal Continue failed"):
		_check(_snapshot(app.get("run_state"), game) == expected, label + " Continue changed settled state")

func _vault_case() -> void:
	var app := await _open_app("vault")
	if app == null:
		return
	if not _check(bool(app.call("start_foundation_run", SEED)), "Independent start failed: " + _route_facts(app)):
		await _close_app(app)
		return
	await _await_publication(app)
	print("VAULT_SAVE_ROUTE after_start=", _route_facts(app))
	if not _check(bool(app.call("select_travel_option", "corner_store")), "Normal Corner Store selection failed: " + _route_facts(app)):
		await _close_app(app)
		return
	if not _check(bool(app.call("confirm_selected_travel", true)), "Normal Corner Store confirmation failed: " + _route_facts(app)):
		await _close_app(app)
		return
	await _await_publication(app)
	if not _check(bool(app.call("_autosave_foundation_run", "Baseline.", true)), "Baseline checkpoint failed"):
		await _close_app(app)
		return
	var disk_before := _disk(app)
	if not _check(bool(app.call("enter_game", "coin_pusher")), "Normal machine entry failed"):
		await _close_app(app)
		return
	var run: RunState = app.get("run_state")
	var game: GameModule = app.get("current_game")
	var surface: Dictionary = game.surface_state(run, run.current_environment)
	var initial := _snapshot(run, game)
	print("VAULT_SAVE_FIXTURE seed=", SEED, " environment=", run.current_environment.get("id"), " node=", run.current_environment.get("world_node_id"), " variation=", initial.machine.get("variation_id"))
	var fixture_ok := _check(run.seed_text == SEED and not run.is_tutorial_run() and not bool(app.get("dev_game_test_mode")) and str(run.current_environment.get("world_node_id")) == "corner_store" and str(run.current_environment.get("archetype_id")) == "corner_store", "Fixture is not the independent normal Corner Store run")
	fixture_ok = _check(not (run.current_environment.get("scenario_game_modifiers", {}).get("coin_pusher", {}) as Dictionary).has("variation_id"), "Fixture forced its cabinet variation") and fixture_ok
	fixture_ok = _check(str(initial.machine.get("variation_id")) == "vault_drop" and str(surface.get("coin_pusher_variation_id")) == "vault_drop", "Fixture is not an actual generated Vault Drop") and fixture_ok
	fixture_ok = _check(str(surface.get("coin_pusher_cabinet", {}).get("identity")) == "vault_drop" and surface.get("coin_pusher_vault_cells", []).size() == 9, "Vault surface cabinet/cell binding is incomplete") and fixture_ok
	if not fixture_ok:
		await _close_app(app)
		return
	var before_cash := run.bankroll
	app.call("_on_game_surface_pointer_action", "coin_pusher_drop_charge", -1, "begin", Vector2(576, 374))
	app.call("_on_game_surface_pointer_action", "coin_pusher_drop_charge", -1, "end", Vector2(576, 374))
	_check(run.bankroll == before_cash - 1 and not game.foundation_save_ready(run, run.current_environment), "One production drop did not leave one debit and unsettled authority")
	app.call("open_run_menu")
	var live_before := _snapshot(run, game, true)
	app.call("save_run_from_menu")
	var text := str(app.get("run_menu_status_label").text)
	_check(bool(app.get("run_menu_overlay").visible) and text.contains("Not saved") and text.contains("Resume") and text.contains("Leave"), "Refusal is not visible with recovery instructions: " + text)
	_check(not bool(app.get("_web_manual_save_pending")) and str(app.get("save_status_message")) != "Saved to Resume Slot." and not text.contains("Saving to Resume Slot"), "Refused Save acknowledged success or pending durability")
	_check(_snapshot(run, game, true) == live_before and _disk(app) == disk_before, "Refused Save changed live wallet/RNG/physics/Vault/tray or checkpoint")
	app.call("_refresh_run_menu")
	_check(str(app.get("run_menu_status_label").text) == text, "Refresh lost refusal feedback")
	await _after_refusal_menu(app)
	_check(_snapshot(run, game, true) == live_before and _disk(app) == disk_before, "Optional refusal capture changed protected live/checkpoint state")
	app.call("close_run_menu")
	app.call("open_run_menu")
	_check(str(app.get("run_menu_status_label").text) == text, "Reopening Run Menu lost refusal feedback")
	app.call("close_run_menu")
	app.call("back_to_environment")
	var deadline := Time.get_ticks_msec() + 120000
	while bool(app.get("game_exit_settle_active")) and Time.get_ticks_msec() < deadline:
		await process_frame
	if _check(not bool(app.get("game_exit_settle_active")) and str(app.get("current_screen")) == "ENVIRONMENT", "Normal Leave did not complete chunked settlement"):
		var expected := _snapshot(run, game)
		app.call("open_run_menu")
		app.call("save_run_from_menu")
		_check(not bool(app.get("run_menu_overlay").visible), "Settled floor Save did not succeed")
		_verify_loaded(app, expected, "Warm")
		var file := FileAccess.open(private_root.path_join("vault/expected.json"), FileAccess.WRITE)
		if _check(file != null, "Could not retain independent cold expectation"):
			file.store_string(JSON.stringify(expected))
			file.close()
	await _close_app(app)

func _refuse_busy(app: Control, service: SaveService) -> void:
	service.wait_for_async_save()
	var before := _disk(app)
	app.set("save_service", BusySaveService.new())
	app.call("open_run_menu")
	app.call("save_run_from_menu")
	_check(bool(app.get("run_menu_overlay").visible) and str(app.get("run_menu_status_label").text).contains("Not saved"), "Busy storage refusal was not visible in Run Menu")
	_check(_disk(app) == before and str(app.get("save_status_message")) != "Saved to Resume Slot.", "Busy Save changed disk or acknowledged success")
	app.set("save_service", service)

func _verify_clear_menu(app: Control, label: String) -> void:
	_check(not bool(app.get("run_menu_overlay").visible), label + " did not close Run Menu")
	app.call("open_run_menu")
	_check(not str(app.get("run_menu_status_label").text).contains("Not saved"), label + " retained old refusal feedback")
	app.call("close_run_menu")

func _busy_case() -> void:
	var app := await _open_app("busy")
	if app == null:
		return
	_check(bool(app.call("start_foundation_run", "BTH061-VAULT-SAVE-BUSY-INDEPENDENT-1")), "Busy case did not start")
	await _await_publication(app)
	_check(bool(app.call("_autosave_foundation_run", "Baseline.", true)), "Busy baseline failed")
	var service: SaveService = app.get("save_service")
	_refuse_busy(app, service)
	app.call("save_run_from_menu")
	_verify_clear_menu(app, "Successful retry")
	_refuse_busy(app, service)
	var previous: RunState = app.get("run_state")
	app.call("load_run_from_menu")
	_check(app.get("run_state") != previous, "Load did not install the saved run")
	_verify_clear_menu(app, "Successful Load")
	_refuse_busy(app, service)
	_check(bool(app.call("start_foundation_run", "BTH061-VAULT-SAVE-BUSY-NEW-RUN-1")), "New Run did not start")
	_verify_clear_menu(app, "Successful New Run")
	await _close_app(app)

func _run() -> void:
	var cold := OS.get_cmdline_user_args().has("--cold")
	if cold:
		var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(private_root.path_join("vault/expected.json")))
		if _check(typeof(expected) == TYPE_DICTIONARY, "No owned warm expectation for cold phase"):
			var app := await _open_app("vault")
			if app != null:
				_verify_loaded(app, expected, "Separate-process cold")
				await _close_app(app)
	else:
		if _check(not DirAccess.dir_exists_absolute(private_root.path_join("vault")) and not DirAccess.dir_exists_absolute(private_root.path_join("busy")), "Warm cases require fresh private fixture directories"):
			await _vault_case()
			await _busy_case()
	_additional_completion_checks()
	completed = true
	print("VAULT_DROP_SAVE_FEEDBACK cold=", cold, " checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func _finalize() -> void:
	if not completed:
		push_error("Vault save feedback check exited before completion")
