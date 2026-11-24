extends SceneTree

const CASES := [
	"boot", "content", "money_roundtrip", "travel", "full_run", "liveness",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# A fresh process keeps liveness standalone and lets us catch script errors
	# even when Godot does not propagate them in its exit code.
	var scratch := OS.get_environment("BTH_TEST_TMPDIR")
	if scratch.is_empty():
		scratch = OS.get_temp_dir()
	scratch = scratch.replace("\\", "/").simplify_path()
	var project := ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	if not scratch.is_absolute_path() or scratch.to_lower().begins_with("c:/") \
			or scratch == project or scratch.begins_with(project + "/"):
		push_error("Set BTH_TEST_TMPDIR to an absolute scratch path outside the repository and off drive C:.")
		quit(1)
		return
	var sandbox := scratch.path_join("bth-tests-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(sandbox) != OK:
		push_error("Could not create test scratch directory: " + sandbox)
		quit(1)
		return
	var failures := 0
	for test in CASES:
		var test_dir := sandbox.path_join(test)
		if not _isolate(test_dir):
			print("FAIL ", test, ": could not prepare isolated data directories")
			failures += 1
			continue
		var output: Array = []
		var exit_code := OS.execute(OS.get_executable_path(), [
			"--headless", "--path", project, "--script", "res://tests/test_%s.gd" % test,
		], output, true)
		var log_text := "".join(output)
		var passed := exit_code == 0 and not _has_error(log_text)
		print("PASS " if passed else "FAIL ", test)
		if not passed:
			failures += 1
			printerr("Exit ", exit_code, ":\n", log_text.strip_edges())
	_remove_tree(sandbox)
	quit(0 if failures == 0 else 1)


func _isolate(path: String) -> bool:
	for key in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "APPDATA", "LOCALAPPDATA",
			"USERPROFILE", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR"]:
		var value := path.path_join(key.to_lower())
		if DirAccess.make_dir_recursive_absolute(value) != OK:
			return false
		OS.set_environment(key, value)
	for key in ["BTH_USER_SETTINGS_PATH", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH",
			"BTH_DEVELOPER_PLACEMENT_PATH", "BTH_DEVELOPER_PLACEMENT_REPORT_PATH", "BTH_PROJECT_PLACEMENT_PATH"]:
		OS.unset_environment(key)
	return true


func _has_error(output: String) -> bool:
	for line in output.split("\n", false):
		var rendered := line.strip_edges()
		if rendered.begins_with("SCRIPT ERROR:") or rendered.begins_with("ERROR:"):
			return true
	return false


func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for filename in directory.get_files():
		DirAccess.remove_absolute(path.path_join(filename))
	for folder in directory.get_directories():
		_remove_tree(path.path_join(folder))
	DirAccess.remove_absolute(path)
