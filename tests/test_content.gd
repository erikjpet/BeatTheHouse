extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var count := _check_directory("res://data", failures)
	var library := ContentLibrary.new()
	library.load()
	for failure in library.validation_errors:
		failures.append(str(failure))
	if count == 0 or library.games.is_empty() or not library.validation_complete:
		failures.append("The authored data catalog did not load.")
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check_directory(path: String, failures: Array[String]) -> int:
	var dir := DirAccess.open(path)
	if dir == null:
		failures.append("Cannot read " + path)
		return 0
	var count := 0
	for child in dir.get_directories():
		count += _check_directory(path.path_join(child), failures)
	for filename in dir.get_files():
		var file := path.path_join(filename)
		if filename.get_extension() == "json":
			count += 1
			var source := FileAccess.open(file, FileAccess.READ)
			if source == null:
				failures.append("Cannot open " + file)
				continue
			var parser := JSON.new()
			if parser.parse(source.get_as_text()) != OK:
				failures.append("%s:%d: %s" % [file, parser.get_error_line(), parser.get_error_message()])
		elif filename.get_extension() in ["tres", "tscn"]:
			count += 1
			if ResourceLoader.load(file) == null:
				failures.append("Cannot load " + file)
	return count
