extends SceneTree

const DEFAULT_REPORT_PATH := "res://.tmp/gdscript_load_check/report.json"

var failures: Array[String] = []
var checked_files: Array[String] = []


func _init() -> void:
	var options := _options()
	var roots: Array = options.get("roots", ["res://scripts", "res://tools"])
	var excludes: Array = options.get("excludes", [])
	var changed_list := str(options.get("changed_list", ""))
	var files: Array[String] = []
	if changed_list.is_empty():
		for root in roots:
			_collect_gd_files(str(root), excludes, files)
	else:
		files = _changed_files(changed_list, excludes)
	files.sort()
	for path in files:
		_check_script(path)
	var report := {
		"tool": "gdscript_load_check",
		"passed": failures.is_empty(),
		"failure_count": failures.size(),
		"failures": failures,
		"checked_count": checked_files.size(),
		"checked_files": checked_files,
	}
	_write_report(str(options.get("report", DEFAULT_REPORT_PATH)), report)
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)


func _options() -> Dictionary:
	var options := {
		"roots": ["res://scripts", "res://tools"],
		"excludes": [],
		"changed_list": "",
		"report": DEFAULT_REPORT_PATH,
	}
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg).strip_edges()
		if arg.begins_with("--roots="):
			options["roots"] = _split_csv(arg.get_slice("=", 1))
		elif arg.begins_with("--exclude="):
			options["excludes"] = _split_csv(arg.get_slice("=", 1))
		elif arg.begins_with("--changed-list="):
			options["changed_list"] = arg.get_slice("=", 1)
		elif arg.begins_with("--report="):
			options["report"] = arg.get_slice("=", 1)
	return options


func _collect_gd_files(root: String, excludes: Array, files: Array[String]) -> void:
	if _excluded(root, excludes):
		return
	var dir := DirAccess.open(root)
	if dir == null:
		failures.append("Could not open script root: %s" % root)
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		var path := root.path_join(entry)
		if _excluded(path, excludes):
			continue
		if dir.current_is_dir():
			_collect_gd_files(path, excludes, files)
		elif path.ends_with(".gd"):
			files.append(path)
	dir.list_dir_end()


func _changed_files(changed_list_path: String, excludes: Array) -> Array[String]:
	var result: Array[String] = []
	var global_path := ProjectSettings.globalize_path(changed_list_path)
	if not FileAccess.file_exists(global_path):
		failures.append("Changed-list file does not exist: %s" % changed_list_path)
		return result
	var text := FileAccess.get_file_as_string(global_path)
	for raw_line in text.split("\n"):
		var line := str(raw_line).strip_edges()
		if line.is_empty() or not line.ends_with(".gd"):
			continue
		var path := line
		if not path.begins_with("res://"):
			path = "res://" + path.trim_prefix("./").replace("\\", "/")
		if not _excluded(path, excludes):
			result.append(path)
	return result


func _check_script(path: String) -> void:
	checked_files.append(path)
	var script = load(path)
	if script == null:
		failures.append("Failed to load script: %s" % path)


func _excluded(path: String, excludes: Array) -> bool:
	for raw_prefix in excludes:
		var prefix := str(raw_prefix)
		if not prefix.is_empty() and path.begins_with(prefix):
			return true
	return false


func _split_csv(value: String) -> Array:
	var result: Array = []
	for raw_part in value.split(","):
		var part := str(raw_part).strip_edges()
		if not part.is_empty():
			result.append(part)
	return result


func _write_report(report_path: String, report: Dictionary) -> void:
	var global_path := ProjectSettings.globalize_path(report_path)
	DirAccess.make_dir_recursive_absolute(global_path.get_base_dir())
	var file := FileAccess.open(global_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
