extends SceneTree

const DurableStoreScript := preload("res://scripts/core/durable_store.gd")
const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")
const ProfileInventoryScript := preload("res://scripts/core/profile_inventory.gd")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const DeveloperPlacementStoreScript := preload("res://scripts/core/developer_placement_store.gd")
const PersistencePathsScript := preload("res://scripts/core/persistence_paths.gd")
const SaveServiceScript := preload("res://scripts/core/save_service.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const ROOT := "user://health06_1_durable_store_contract"
const DIRECT_PATH := ROOT + "/direct.json"
const PROFILE_PATH := ROOT + "/profile.json"
const META_PATH := ROOT + "/meta.json"
const SETTINGS_PATH := ROOT + "/settings.json"
const PLACEMENT_PATH := ROOT + "/placements.json"
const PROJECT_PLACEMENT_PATH := ROOT + "/project_placements.json"
const RUN_ROOT := ROOT + "/distribution"
const RUN_SLOT := "health06_1"

var failures: Array[String] = []
var _saved_environment: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var shipped_placements := DurableStoreScript.read_json(DeveloperPlacementStoreScript.PROJECT_PATH)
	var shipped_rooms: Dictionary = (shipped_placements.get("data", {}) as Dictionary).get("rooms", {})
	_expect(bool(shipped_placements.get("ok", false)) and shipped_rooms.has("gas_station_casino"), "CH-01: durable project-resource reads dropped shipped placement overrides: %s" % str(shipped_placements))
	_capture_environment()
	_cleanup()
	_configure_environment()
	_check_direct_durability()
	_check_json_coercion()
	_check_profile_recovery()
	_check_meta_recovery()
	_check_settings_recovery()
	_check_placement_failure_reporting()
	_check_run_save_recovery_and_trust()
	_check_distribution_root_validation()
	DurableStoreScript.reset_debug_faults()
	_restore_environment()
	_cleanup()
	if failures.is_empty():
		print("HEALTH06_1_DURABLE_STORE PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_direct_durability() -> void:
	var first := DurableStoreScript.write_json(DIRECT_PATH, {"generation": 1}, Callable(self, "_valid_generation"))
	_expect(bool(first.get("ok", false)), "CH-01: initial durable write failed: %s" % JSON.stringify(first))
	var first_bytes := FileAccess.get_file_as_bytes(DIRECT_PATH)

	DurableStoreScript.set_debug_force_write_failure(true)
	var write_failure := DurableStoreScript.write_json(DIRECT_PATH, {"generation": 2}, Callable(self, "_valid_generation"))
	DurableStoreScript.reset_debug_faults()
	_expect(not bool(write_failure.get("ok", true)), "CH-01/02: induced write failure reported success.")
	_expect(FileAccess.get_file_as_bytes(DIRECT_PATH) == first_bytes, "CH-01: write failure changed the prior primary bytes.")

	DurableStoreScript.set_debug_force_rename_failure(true)
	var rename_failure := DurableStoreScript.write_json(DIRECT_PATH, {"generation": 2}, Callable(self, "_valid_generation"))
	DurableStoreScript.reset_debug_faults()
	_expect(not bool(rename_failure.get("ok", true)), "CH-01: induced rename failure reported success.")
	_expect(FileAccess.get_file_as_bytes(DIRECT_PATH) == first_bytes, "CH-01: rename failure did not restore the prior primary byte-for-byte.")

	var second := DurableStoreScript.write_json(DIRECT_PATH, {"generation": 2}, Callable(self, "_valid_generation"))
	_expect(bool(second.get("ok", false)), "CH-01: replacement durable write failed: %s" % JSON.stringify(second))
	var fresh_read := DurableStoreScript.read_json(DIRECT_PATH, Callable(self, "_valid_generation"))
	_expect(bool(fresh_read.get("ok", false)) and int((fresh_read.get("data", {}) as Dictionary).get("generation", 0)) == 2, "CH-01: reported-success generation was not re-readable.")
	_write_raw(DIRECT_PATH, "{corrupt")
	var recovered := DurableStoreScript.read_json(DIRECT_PATH, Callable(self, "_valid_generation"))
	_expect(str(recovered.get("outcome", "")) == DurableStoreScript.OUTCOME_BACKUP, "CH-01: corrupt primary did not load its backup: %s" % JSON.stringify(recovered))
	_expect(int((recovered.get("data", {}) as Dictionary).get("generation", 0)) == 1, "CH-01: backup recovery returned the wrong generation.")
	var status := DurableStoreScript.status(DIRECT_PATH, Callable(self, "_valid_generation"))
	_expect(not bool(status.get("primary_loadable", true)) and bool(status.get("backup_loadable", false)), "CH-01: durable status did not distinguish corrupt primary from valid backup.")


func _check_json_coercion() -> void:
	for malformed in [17, ["windowed"], null]:
		_expect(JsonCoerceScript.coerce_enum(malformed, ["windowed", "fullscreen"], "windowed") == "windowed", "CH-04: malformed enum did not clamp to its default.")
	var settings := UserSettingsScript.new()
	for malformed in [17, ["fullscreen"], null]:
		settings.from_dict({"window_mode": malformed, "text_size": malformed})
		_expect(settings.window_mode == "windowed", "CH-04: malformed window mode did not default.")
		_expect(settings.text_size == "normal", "CH-04: malformed text size did not default.")


func _check_profile_recovery() -> void:
	var profile := ProfileInventoryScript.new()
	profile.tutorial_completed = false
	_expect(profile.save() == OK, "CH-01: profile generation one failed to save.")
	profile.tutorial_completed = true
	_expect(profile.save() == OK, "CH-01: profile generation two failed to save.")
	_write_raw(PROFILE_PATH, "{corrupt")
	var fresh := ProfileInventoryScript.new()
	fresh.load()
	_expect(fresh.loaded_from_disk and not fresh.tutorial_completed, "CH-01: profile did not recover its prior backup generation.")
	_expect(str(fresh.last_load_outcome.get("outcome", "")) == DurableStoreScript.OUTCOME_BACKUP, "CH-01: profile did not surface backup recovery.")


func _check_meta_recovery() -> void:
	var meta := MetaCollectionServiceScript.new()
	meta.add_gold(11)
	_expect(meta.save() == OK, "CH-01: meta generation one failed to save.")
	meta.add_gold(7)
	_expect(meta.save() == OK, "CH-01: meta generation two failed to save.")
	_write_raw(META_PATH, "{corrupt")
	var fresh := MetaCollectionServiceScript.new()
	fresh.load()
	_expect(int(fresh.snapshot().get("gold_balance", 0)) == 11, "CH-01: meta collection did not recover its prior backup generation.")
	_expect(str(fresh.last_load_outcome.get("outcome", "")) == DurableStoreScript.OUTCOME_BACKUP, "CH-01: meta collection did not surface backup recovery.")


func _check_settings_recovery() -> void:
	var settings := UserSettingsScript.new()
	settings.text_size = "small"
	_expect(settings.save() == OK, "CH-02: settings generation one failed to save.")
	settings.text_size = "large"
	_expect(settings.save() == OK, "CH-02: settings generation two failed to save.")
	_write_raw(SETTINGS_PATH, "{corrupt")
	var fresh := UserSettingsScript.new()
	var outcome: Dictionary = fresh.load()
	_expect(fresh.text_size == "small", "CH-02: settings did not recover their prior backup generation.")
	_expect(str(outcome.get("code", "")) == "loaded_backup", "CH-02/03: settings did not surface backup recovery: %s" % JSON.stringify(outcome))


func _check_placement_failure_reporting() -> void:
	DeveloperPlacementStoreScript.reload()
	var environment := {"archetype_id": "health_room", "current_layer_id": "main"}
	var first: Dictionary = DeveloperPlacementStoreScript.save_position(environment, "object_slot_positions", "fixture", Vector2(24, 36))
	_expect(bool(first.get("ok", false)), "CH-05: initial developer placement failed.")
	var prior_bytes := FileAccess.get_file_as_bytes(PLACEMENT_PATH)
	DurableStoreScript.set_debug_force_write_failure(true)
	var failed: Dictionary = DeveloperPlacementStoreScript.save_position(environment, "object_slot_positions", "fixture", Vector2(48, 72))
	DurableStoreScript.reset_debug_faults()
	_expect(not bool(failed.get("ok", true)), "CH-05: failed developer placement write reported success.")
	_expect(FileAccess.get_file_as_bytes(PLACEMENT_PATH) == prior_bytes, "CH-05: failed developer placement write changed the prior generation.")
	DeveloperPlacementStoreScript.reload()
	var loaded: Dictionary = DeveloperPlacementStoreScript.slot_overrides(environment, "object_slot_positions")
	_expect(loaded.get("fixture", []) == [24.0, 36.0], "CH-05: developer placement was not re-readable after failure.")


func _check_run_save_recovery_and_trust() -> void:
	var service := SaveServiceScript.new()
	var run_state := RunStateScript.new()
	run_state.start_new("HEALTH06_1_DURABLE")
	_expect(service.save_run(run_state, RUN_SLOT) == OK, "CH-01/02: run generation one failed to save.")
	run_state.bankroll += 1
	_expect(service.save_run(run_state, RUN_SLOT) == OK, "CH-01/02: run generation two failed to save.")
	var primary_path := service.run_save_path(RUN_SLOT)
	_write_raw(primary_path, "{corrupt")
	var recovery_service := SaveServiceScript.new()
	var recovered: Variant = recovery_service.load_run(RUN_SLOT)
	_expect(recovered != null, "CH-01: run save did not recover from backup.")
	_expect(str(recovery_service.last_load_outcome.get("outcome", "")) == DurableStoreScript.OUTCOME_BACKUP, "CH-01: run recovery did not surface its backup outcome.")
	# Re-establish a valid primary, then prove a failed save invalidates its trust cache.
	_expect(service.save_run(run_state, RUN_SLOT) == OK, "CH-01: run primary could not be re-established.")
	_expect(service.trusted_primary_fingerprints.has(RUN_SLOT), "CH-01: successful run save did not establish a trusted fingerprint.")
	DurableStoreScript.set_debug_force_rename_failure(true)
	run_state.bankroll += 1
	var failed_save := service.save_run(run_state, RUN_SLOT)
	DurableStoreScript.reset_debug_faults()
	_expect(failed_save != OK, "CH-01: induced run rename failure reported success.")
	_expect(not service.trusted_primary_fingerprints.has(RUN_SLOT), "CH-01: failed run save retained a trusted-primary fingerprint.")


func _check_distribution_root_validation() -> void:
	OS.set_environment(PersistencePathsScript.DISTRIBUTION_FEATURE_ENV, "1")
	for invalid_root in ["   ", "relative/path", "../escape", "user://safe/../escape", "C:/safe/../escape"]:
		OS.set_environment(PersistencePathsScript.DISTRIBUTION_ROOT_ENV, invalid_root)
		_expect(PersistencePathsScript.distribution_root() == PersistencePathsScript.DISTRIBUTION_ROOT, "CH-06: invalid distribution root was accepted: %s" % invalid_root)
	OS.set_environment(PersistencePathsScript.DISTRIBUTION_ROOT_ENV, "user://isolated/root/")
	_expect(PersistencePathsScript.distribution_root() == "user://isolated/root", "CH-06: valid user root was rejected or not normalized.")
	var absolute_root := ProjectSettings.globalize_path(ROOT + "/absolute")
	OS.set_environment(PersistencePathsScript.DISTRIBUTION_ROOT_ENV, absolute_root)
	_expect(PersistencePathsScript.distribution_root() == absolute_root.trim_suffix("/").trim_suffix("\\"), "CH-06: valid absolute test-isolation root was rejected.")


func _valid_generation(data: Dictionary) -> bool:
	return int(data.get("generation", 0)) > 0


func _capture_environment() -> void:
	for key in [
		ProfileInventoryScript.INVENTORY_PATH_ENV,
		MetaCollectionServiceScript.STORE_PATH_ENV,
		UserSettingsScript.SETTINGS_PATH_ENV,
		DeveloperPlacementStoreScript.USER_PATH_ENV,
		DeveloperPlacementStoreScript.PROJECT_PATH_ENV,
		PersistencePathsScript.DISTRIBUTION_FEATURE_ENV,
		PersistencePathsScript.DISTRIBUTION_ROOT_ENV,
	]:
		_saved_environment[key] = OS.get_environment(key)


func _configure_environment() -> void:
	OS.set_environment(ProfileInventoryScript.INVENTORY_PATH_ENV, PROFILE_PATH)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, META_PATH)
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, SETTINGS_PATH)
	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV, PLACEMENT_PATH)
	OS.set_environment(DeveloperPlacementStoreScript.PROJECT_PATH_ENV, PROJECT_PLACEMENT_PATH)
	OS.set_environment(PersistencePathsScript.DISTRIBUTION_FEATURE_ENV, "1")
	OS.set_environment(PersistencePathsScript.DISTRIBUTION_ROOT_ENV, RUN_ROOT)


func _restore_environment() -> void:
	for key in _saved_environment.keys():
		OS.set_environment(str(key), str(_saved_environment[key]))


func _cleanup() -> void:
	for path in [DIRECT_PATH, PROFILE_PATH, META_PATH, SETTINGS_PATH, PLACEMENT_PATH, PROJECT_PLACEMENT_PATH]:
		_remove_generation(path)
	_remove_generation("%s/saves/run_%s.json" % [RUN_ROOT, RUN_SLOT])


func _remove_generation(path: String) -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var absolute_path := ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)


func _write_raw(path: String, text: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Fixture could not write %s (error %d)." % [path, FileAccess.get_open_error()])
		return
	file.store_string(text)
	var error := file.get_error()
	file.close()
	if error != OK:
		failures.append("Fixture write failed for %s (error %d)." % [path, error])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
