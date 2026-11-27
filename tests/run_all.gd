extends SceneTree

const CASES := [
	"boot", "content", "money_roundtrip", "travel", "full_run", "terminal_persistence", "liveness",
	"gold_solver", "crew_solver",
]
const TRAVEL_SAVE_PREFIX := "TRAVEL_SAVE "
const WINDOWS_BOOT_TIMEOUT_MSEC := 60000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var windows_exe := ""
	if not arguments.is_empty():
		if OS.get_name() != "Windows" or arguments.size() != 2 or arguments[0] != "--windows-exe":
			push_error("Optional Windows usage is -- --windows-exe <absolute path to the extracted EXE>.")
			quit(1)
			return
		windows_exe = arguments[1].replace("\\", "/").simplify_path()
		if not windows_exe.is_absolute_path() or not windows_exe.to_lower().ends_with(".exe") \
				or not FileAccess.file_exists(windows_exe):
			push_error("--windows-exe must name an existing Windows export by absolute path.")
			quit(1)
			return

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
		if not _isolate(sandbox.path_join(test)):
			print("FAIL ", test, ": could not prepare isolated data directories")
			failures += 1
			continue
		var passed := _run_source_case(project, test)
		print("PASS " if passed else "FAIL ", test)
		failures += int(not passed)
	if not windows_exe.is_empty():
		var boot_dir := sandbox.path_join("windows_package_boot")
		var passed := _isolate(boot_dir) and _run_windows_package(windows_exe, boot_dir)
		print("PASS " if passed else "FAIL ", "windows_package_boot")
		failures += int(not passed)
	_remove_tree(sandbox)
	quit(0 if failures == 0 else 1)


func _run_source_case(project: String, test: String) -> bool:
	var executable := OS.get_executable_path()
	var arguments := PackedStringArray([
		"--headless", "--path", project, "--script", "res://tests/test_%s.gd" % test,
	])
	if test == "boot":
		arguments.append_array(["--", "--bth_perf=1"])
	var output: Array = []
	var exit_code := OS.execute(executable, arguments, output, true)
	var log_text := "".join(output)
	if not _clean_exit(exit_code, log_text):
		return false
	if test != "travel":
		return true

	# Reuse only the travel case's sandbox after its writer has fully exited.
	for line in log_text.split("\n", false):
		if line.begins_with(TRAVEL_SAVE_PREFIX):
			var expected := line.trim_prefix(TRAVEL_SAVE_PREFIX).strip_edges()
			if expected.is_empty():
				break
			arguments.append_array(["--", "--continue", expected])
			output.clear()
			exit_code = OS.execute(executable, arguments, output, true)
			return _clean_exit(exit_code, "".join(output))
	printerr("Travel exited without a saved-state snapshot for cold Continue.")
	return false


func _run_windows_package(executable: String, boot_dir: String) -> bool:
	var log_path := boot_dir.path_join("engine.log")
	# Let the exact EXE load its embedded PCK without a script or pack override.
	var pid := OS.create_process(executable, [
		"--headless", "--audio-driver", "Dummy", "--quit-after", "300", "--log-file", log_path,
	], false)
	if pid < 0:
		printerr("Could not start the Windows package.")
		return false
	var deadline := Time.get_ticks_msec() + WINDOWS_BOOT_TIMEOUT_MSEC
	while OS.is_process_running(pid) and Time.get_ticks_msec() < deadline:
		OS.delay_msec(50)
	if OS.is_process_running(pid):
		var stop_error := OS.kill(pid)
		printerr("Windows package did not exit within the boot timeout. Stop result: ", error_string(stop_error))
		return false
	var log_text := FileAccess.get_file_as_string(log_path)
	if log_text.strip_edges().is_empty():
		printerr("Windows package did not write a startup log.")
		return false
	return _clean_exit(OS.get_process_exit_code(pid), log_text)


func _isolate(path: String) -> bool:
	for key in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "APPDATA", "LOCALAPPDATA",
			"USERPROFILE", "TEMP", "TMP", "TMPDIR", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR"]:
		var value := path.path_join(key.to_lower())
		if DirAccess.make_dir_recursive_absolute(value) != OK:
			return false
		OS.set_environment(key, value)
	for key in ["BTH_USER_SETTINGS_PATH", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH",
			"BTH_DEVELOPER_PLACEMENT_PATH", "BTH_DEVELOPER_PLACEMENT_REPORT_PATH", "BTH_PROJECT_PLACEMENT_PATH"]:
		OS.unset_environment(key)
	return true


func _clean_exit(exit_code: int, output: String) -> bool:
	if exit_code == 0 and not _has_error(output):
		return true
	printerr("Exit ", exit_code, ":\n", output.strip_edges())
	return false


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
