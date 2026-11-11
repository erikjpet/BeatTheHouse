extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/core/durable_store.gd")

class FailedBackgroundSave extends SaveService:
	func _write_payload_atomic(_payload: Dictionary, _path: String, _backup_path: String, _primary_digest: String = "", _result_box: Dictionary = {}, _verified_storage: Dictionary = {}) -> Error:
		return ERR_BUSY

var checks := 0
var failures: Array[String] = []
var observations: Array = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var run := RunState.new()
	run.start_new("AUD061-09-ASYNC-RETRY")
	var service := FailedBackgroundSave.new()
	_check(service.begin_save_run(run, "retry") == OK and service.async_save_in_flight(), "actual async task starts")
	var result := service.save_run(run, "retry")
	observations.append({"case": "retry", "result": result, "outcome": service.last_save_outcome, "file_exists": FileAccess.file_exists(service.run_save_path("retry")), "task_drained": not service.async_save_in_flight()})
	_check(result == OK and FileAccess.file_exists(service.run_save_path("retry")), "explicit save tries current write after old async failure")
	_check(not service.async_save_in_flight(), "failed worker is joined before synchronous write")
	var diagnostic: Variant = service.get("last_async_failure_outcome")
	_check(diagnostic is Dictionary and int(diagnostic.get("error", OK)) == ERR_BUSY, "older async failure retained for diagnostics")

	service = FailedBackgroundSave.new()
	_check(service.begin_save_run(run, "both_fail") == OK, "second actual async task starts")
	Store.set_debug_force_write_failure(true)
	result = service.save_run(run, "both_fail")
	Store.reset_debug_faults()
	observations.append({"case": "both_fail", "result": result, "outcome": service.last_save_outcome, "task_drained": not service.async_save_in_flight()})
	_check(result == ERR_CANT_CREATE and int(service.last_save_outcome.get("error", OK)) == ERR_CANT_CREATE, "two failures report second write error rather than older ERR_BUSY")
	_check(not service.async_save_in_flight(), "second failed worker is drained")

	var healthy := SaveService.new()
	_check(healthy.save_run(run, "clear") == OK and healthy.save_run(run, "clear") == OK, "clear fixture has primary and backup")
	service = FailedBackgroundSave.new()
	_check(service.begin_save_run(run, "clear") == OK, "clear begins actual failing task")
	result = service.clear_run("clear")
	observations.append({"case": "clear", "result": result, "primary_exists": FileAccess.file_exists(service.run_save_path("clear")), "backup_exists": FileAccess.file_exists(service.backup_save_path("clear")), "task_drained": not service.async_save_in_flight()})
	_check(result == OK and not FileAccess.file_exists(service.run_save_path("clear")) and not FileAccess.file_exists(service.backup_save_path("clear")), "clear removes both generations after old worker failure")
	_check(not service.async_save_in_flight(), "clear joins owned task")

	var app: Control = MainScene.instantiate()
	root.add_child(app)
	await process_frame
	_check(bool(app.call("start_foundation_run", "AUD061-09-HOST", {}, true)), "normal host run starts")
	_check(bool(app.call("_autosave_foundation_run", "Baseline.", true)), "host baseline saves")
	var state: RunState = app.get("run_state")
	service = FailedBackgroundSave.new()
	_check(service.begin_save_run(state, "foundation_ui_autosave") == OK, "host has actual failed in-flight save")
	app.set("save_service", service)
	app.set("autosave_inflight_generation", app.get("autosave_dirty_generation"))
	state.change_bankroll(-1, true)
	app.call("_mark_autosave_dirty")
	var saved: bool = app.call("_write_foundation_run_save", "Explicit retry.", true)
	var loaded: RunState = service.load_run("foundation_ui_autosave")
	observations.append({"case": "host", "saved": saved, "cash": state.bankroll, "loaded_cash": loaded.bankroll if loaded != null else -1, "outcome": service.last_save_outcome, "task_drained": not service.async_save_in_flight()})
	_check(saved and loaded != null and loaded.bankroll == state.bankroll, "host synchronous save writes current state after old failure")
	_check(not bool(app.get("pending_autosave")) and not bool(app.get("autosave_retry_blocked")), "successful new write clears current failure state")
	diagnostic = service.get("last_async_failure_outcome")
	_check(diagnostic is Dictionary and int(diagnostic.get("error", OK)) == ERR_BUSY, "host retains older drain failure separately")
	app.queue_free()
	await process_frame
	print("AUD061_ASYNC_RETRY " + JSON.stringify({"checks": checks, "failures": failures, "observations": observations}))
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("AUD061-09: " + label)
