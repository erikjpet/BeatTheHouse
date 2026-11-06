extends SceneTree

# BTH061-BAR-DICE-SHUTDOWN-001. One fresh native scene and its actual SaveService.
# No game/financial outcomes, original storage, UI Save callback or pool sweep.
# The test deliberately holds ONLY this known service after Host destruction so
# it can inspect the outcome BEFORE any optional test-cleanup join.
const MainScene := preload("res://scenes/main.tscn")
const State := preload("res://scripts/core/run_state.gd")
const Store := preload("res://scripts/core/durable_store.gd")
const SLOT := "save_scene_exit_failure"
const SEED := "BTH061-SAVE-SCENE-EXIT-FAILURE-001"
var app: Variant
var service: SaveService
var run: RunState
var checks: int = 0
var failures: Array[String] = []
var facts: Dictionary = {"game_inputs": 0, "ui_save_callbacks": 0, "test_join_before_exit_assertions": false, "cleanup_join_attempted": false}
var private_root: String = ""
var primary_path: String = ""
var primary_sha256: String = ""
var initial_failure_flag: bool = false
var exit_observed: bool = false
var begin_error: int = ERR_UNCONFIGURED


func _initialize() -> void:
	initial_failure_flag = Store.debug_force_write_failure
	private_root = OS.get_environment("BTH_SAVE_SCENE_EXIT_PRIVATE_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	if not _private_paths(): _finish(); return
	call_deferred("_run")


func _run() -> void:
	if not _check(not initial_failure_flag, "Fresh process begins without an inherited failure hook"): _finish(); return
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", SLOT)
	root.add_child(app)
	await _frames(8)
	app._settle_script_prewarm_before_runtime()
	if not _check(bool(app._ensure_run_ui_built()), "Official run UI construction completes before the exit fixture"):
		await _cleanup(); return
	await _frames(2)
	if not _check(bool(app.run_ui_built) and not bool(app.run_ui_build_in_progress), "Pending UI builder has resumed and finished before the initial save"):
		await _cleanup(); return
	facts["run_ui_built_before_save"] = bool(app.run_ui_built)
	facts["run_ui_build_in_progress_before_save"] = bool(app.run_ui_build_in_progress)
	service = app.save_service
	primary_path = ProjectSettings.globalize_path(service.run_save_path(SLOT))
	if not _check(_inside(primary_path) and not FileAccess.file_exists(primary_path) and not FileAccess.file_exists(service.backup_save_path(SLOT)), "Actual owned slot is private and previously unused"):
		await _cleanup(); return
	if not _check(not service.async_save_in_flight(), "Actual MainScene service starts without a registered save"):
		await _cleanup(); return
	run = State.new()
	run.start_new(SEED)
	# This initial RunState is not installed into gameplay. The Host owns the
	# real service; no game, wager, room generation or UI action is requested.
	if not _check(service.save_run(run, SLOT) == OK and bool(service.last_save_outcome.get("ok", false)), "Official synchronous save establishes a valid prior primary"):
		await _cleanup(); return
	primary_sha256 = FileAccess.get_sha256(primary_path)
	facts["prior_primary_exists"] = FileAccess.file_exists(primary_path)
	facts["prior_save_ok"] = bool(service.last_save_outcome.get("ok", false))
	# A declared nonfinancial marker distinguishes the attempted next generation.
	# Its failed persistence must not replace the already validated primary.
	run.narrative_flags["save_scene_exit_failure_candidate"] = true
	app.tree_exiting.connect(_on_host_tree_exiting, CONNECT_ONE_SHOT)
	# Immediate normal Node.free is deliberate for this separate error-path
	# check: no process-frame poll can reclaim the task before Host _exit_tree.
	# The queued-deletion race has its own observe/drain probe.
	Store.debug_force_write_failure = true
	facts["failure_hook_enabled_before_begin"] = Store.debug_force_write_failure
	begin_error = service.begin_save_run(run, SLOT)
	facts["begin_error"] = begin_error
	facts["registered_task_before_free"] = service.async_task_id
	app.free()
	facts["normal_node_free_returned"] = true
	# All exit assertions happen BEFORE optional test cleanup can join anything.
	facts["after_normal_free"] = _service_scalars()
	_check(begin_error == OK and int(facts.get("registered_task_before_free", -1)) >= 0, "A real failed-write task was registered before normal Node.free")
	_check(exit_observed and not is_instance_valid(app), "Actual Host tree exit completed")
	_check(service.async_task_id == -1 and not service.async_save_in_flight(), "Host exit joined its owned task and cleared in-flight state")
	_check(not bool(service.last_save_outcome.get("ok", true)) and int(service.last_save_outcome.get("error", OK)) != OK, "Host exit retains failure rather than a false successful-save acknowledgment")
	_check(int(service.last_save_outcome.get("error", OK)) == ERR_CANT_CREATE, "Asynchronous outcome retains the actual injected ERR_CANT_CREATE")
	_check(FileAccess.file_exists(primary_path) and FileAccess.get_sha256(primary_path) == primary_sha256, "Failed exit save preserves all prior good primary bytes")
	facts["prior_primary_unchanged_before_cleanup"] = FileAccess.file_exists(primary_path) and FileAccess.get_sha256(primary_path) == primary_sha256
	facts["exit_assertions_completed"] = true
	await _cleanup()


func _on_host_tree_exiting() -> void:
	# Node emits this after FoundationMain._exit_tree returns.
	exit_observed = true
	facts["tree_exiting_after_host_exit"] = _service_scalars()


func _service_scalars() -> Dictionary:
	return {"process_frame": Engine.get_process_frames(), "async_task_id": service.async_task_id, "in_flight": service.async_save_in_flight(), "outcome_ok": bool(service.last_save_outcome.get("ok", true)), "error": int(service.last_save_outcome.get("error", OK)), "error_code": str(service.last_save_outcome.get("error_code", ""))}


func _cleanup() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await _frames(2)
	# Only after recording/asserting the candidate behavior may the test reclaim
	# a baseline's still-registered OWN service task. No arbitrary task-ID waits.
	if service != null and service.async_save_in_flight():
		facts["cleanup_join_attempted"] = true
		facts["cleanup_join_error"] = service.wait_for_async_save()
	var reclaimed: bool = service == null or not service.async_save_in_flight()
	_check(reclaimed, "Only the owned task is reclaimed before hook restoration and release")
	if reclaimed:
		Store.debug_force_write_failure = initial_failure_flag
		facts["failure_flag_restored"] = Store.debug_force_write_failure == initial_failure_flag
		service = null
		run = null
		app = null
	_finish()


func _inside(path: String) -> bool:
	var normalized: String = path.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()
	return normalized == private_root.to_lower() or normalized.begins_with(private_root.to_lower() + "/")


func _private_paths() -> bool:
	if not _check(private_root.is_absolute_path() and "native-private-" in private_root and not OS.has_feature("web"), "Explicit fresh native BTH_SAVE_SCENE_EXIT_PRIVATE_ROOT required"): return false
	if not _check(_inside(ProjectSettings.globalize_path("user://")), "Actual user:// is private before MainScene construction"): return false
	for key: String in ["APPDATA", "LOCALAPPDATA", "USERPROFILE", "BTH_WORLD_REENTRY_ROOT", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_USER_SETTINGS_PATH", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH"]:
		var path: String = OS.get_environment(key)
		if not _check(not path.is_empty() and _inside(ProjectSettings.globalize_path(path)), "Private incoming path: " + key): return false
	for key: String in ["BTH_TARGET_OUTPUT", "BTH_DEVELOPER_PLACEMENT_PATH", "BTH_DEVELOPER_PLACEMENT_REPORT_PATH"]:
		var path: String = OS.get_environment(key)
		if not _check(path.is_empty() or _inside(ProjectSettings.globalize_path(path)), "Private optional output: " + key): return false
	return _check(OS.get_environment("BTH_PROJECT_PLACEMENT_PATH").is_empty() and OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "No original fixture/profile or placement override")


func _frames(count: int) -> void:
	for frame in range(count): await process_frame


func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label); push_error(label)
	return ok


func _finish() -> void:
	if service == null or not service.async_save_in_flight(): Store.debug_force_write_failure = initial_failure_flag
	facts["scope"] = "One new native MainScene-owned real asynchronous save, forced DurableStore failure and immediate normal Node.free with no intervening await/poll. No process forced exit, UI Save/game/financial inputs, outcome fixtures or original profiles. Exit assertions precede optional own-service cleanup, hook restoration and reference release. Expected production push_error reports the injected IO failure."
	facts["source_sha256"] = {"test": FileAccess.get_sha256(get_script().resource_path), "host": FileAccess.get_sha256("res://scripts/ui/foundation_main.gd"), "service": FileAccess.get_sha256("res://scripts/core/save_service.gd")}
	var result: Dictionary = {"checks": checks, "failures": failures, "facts": facts}
	var output: String = OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty() and not private_root.is_empty() and _inside(output):
		var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result, "  ")); file.close()
	print("SAVE_SCENE_EXIT_FAILURE_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
