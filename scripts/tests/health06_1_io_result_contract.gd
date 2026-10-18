extends SceneTree

const IoResultScript := preload("res://scripts/core/io_result.gd")
const KeysScript := preload("res://scripts/core/keys.gd")
const DurableStoreScript := preload("res://scripts/core/durable_store.gd")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const GameModuleScript := preload("res://scripts/core/game_module.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_check_shape()
	_check_boundaries()
	if _failures.is_empty():
		print("HEALTH06_1_IO_RESULT PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check_shape() -> void:
	var success := IoResultScript.ok({"value": 4})
	_expect(IoResultScript.is_ok(success), "CH-27: success constructor is not successful.")
	_expect(IoResultScript.assert_shape(success).is_empty(), "CH-27: success constructor has an invalid shape.")
	var failure := IoResultScript.failed(ERR_FILE_CANT_OPEN, "fixture_failure", "Fixture failed.")
	_expect(not IoResultScript.is_ok(failure), "CH-27: failure constructor is successful.")
	_expect(IoResultScript.assert_shape(failure).is_empty(), "CH-27: failure constructor has an invalid shape.")
	_expect(not IoResultScript.assert_shape({"ok": false}).is_empty(), "CH-27: malformed result escaped validation.")
	_expect(KeysScript.ID == "id" and KeysScript.DISPLAY_NAME == "display_name" and KeysScript.BANKROLL_DELTA == "bankroll_delta", "CH-27: high-frequency key constants drifted.")


func _check_boundaries() -> void:
	var invalid_write := DurableStoreScript.write_json("", {})
	_expect(not IoResultScript.is_ok(invalid_write) and IoResultScript.assert_shape(invalid_write).is_empty(), "CH-27: DurableStore failure is not an IoResult.")
	var missing_settings: UserSettings = UserSettingsScript.new()
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, "user://health06_1_missing_settings.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://health06_1_missing_settings.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://health06_1_missing_settings.json.bak"))
	var load_result := missing_settings.load()
	_expect(not IoResultScript.is_ok(load_result) and IoResultScript.assert_shape(load_result).is_empty(), "CH-27: UserSettings.load missing-file result is not an IoResult.")
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, "")
	var service: RunActionService = RunActionServiceScript.new()
	var service_failure: Dictionary = service.call("_service_error", "Fixture transaction failed.")
	_expect(not IoResultScript.is_ok(service_failure) and IoResultScript.assert_shape(service_failure).is_empty(), "CH-27: RunActionService failure is not an IoResult.")
	var missing_run := GameModuleScript.apply_result(null, {"ok": true})
	_expect(not IoResultScript.is_ok(missing_run) and IoResultScript.assert_shape(missing_run).is_empty(), "CH-27: GameModule missing-run exit is still silent.")
	var rejected := GameModuleScript.apply_result(RunStateScript.new(), {"ok": false, "error_code": "fixture_rejected", "message": "Rejected."})
	_expect(not IoResultScript.is_ok(rejected) and IoResultScript.assert_shape(rejected).is_empty(), "CH-27: GameModule rejected-result exit is still silent.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
