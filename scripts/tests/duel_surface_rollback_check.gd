extends SceneTree

# Focused regression; requires a NEW absolute --owned-data-root directory.
# Existing saves and reports are never removed.
const Contract := preload("res://scripts/tests/foundation/duel_surface_rollback_contract.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const PersistencePathsScript := preload("res://scripts/core/persistence_paths.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture_path := "res://scripts/tests/foundation/duel_surface_rollback_contract.gd"
	var report_path := OS.get_environment("BTH_TARGET_OUTPUT")
	var owned_root := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): report_path = argument.trim_prefix("--report=")
		elif argument.begins_with("--owned-data-root="): owned_root = argument.trim_prefix("--owned-data-root=").replace("\\", "/")
	var report := {"schema": "bth_duel_surface_rollback_v1", "fixture_source": fixture_path, "owned_data_root": owned_root, "failures": [], "cases": []}
	var failures: Array = []
	if owned_root.is_empty() or not owned_root.is_absolute_path() or owned_root.contains(".."):
		failures.append("Provide an explicit new absolute --owned-data-root without parent traversal.")
	elif DirAccess.dir_exists_absolute(owned_root) or FileAccess.file_exists(owned_root):
		failures.append("Owned data root already exists; preserve it and use a fresh directory.")
	elif DirAccess.make_dir_recursive_absolute(owned_root) != OK:
		failures.append("Could not create the explicitly owned data root.")
	else:
		OS.set_environment("BTH_DISTRIBUTION_DATA_ROOT", owned_root)
		if PersistencePathsScript.distribution_root() != owned_root:
			failures.append("PersistencePaths did not select the explicit owned root.")
	if fixture_path.is_empty() or not FileAccess.file_exists(fixture_path):
		failures.append("External fixture source is missing.")
	if failures.is_empty():
		var library := ContentLibraryScript.new()
		library.load(true)
		report["library_validation_errors"] = library.validation_errors.duplicate(true)
		if not library.validation_errors.is_empty():
			failures.append("Current production ContentLibrary did not load cleanly.")
		else:
			var fixture := Contract.new()
			var result: Dictionary = await fixture.run(library, self)
			report["cases"] = result.get("cases", [])
			failures.append_array(result.get("failures", []))
	report["failures"] = failures
	report["failure_count"] = failures.size()
	report["passed"] = failures.is_empty()
	if not report_path.is_empty():
		var output := FileAccess.open(report_path, FileAccess.WRITE)
		if output != null: output.store_string(JSON.stringify(report, "\t"))
	print("DUEL_SURFACE_ROLLBACK_RESULT ", JSON.stringify(report))
	for failure in failures: push_error(str(failure))
	quit(0 if failures.is_empty() else 1)
