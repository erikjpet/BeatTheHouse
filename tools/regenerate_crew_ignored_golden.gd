extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const CrewIgnoredGoldenProbeScript := preload("res://scripts/tests/foundation/crew_ignored_golden_probe.gd")
const OUTPUT_PATH := "res://scripts/tests/fixtures/crew06_5_ignored_run_baseline.json"

var write_enabled := false
var baseline_commit := ""


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--write":
			write_enabled = true
		elif argument.begins_with("--baseline-commit="):
			baseline_commit = argument.trim_prefix("--baseline-commit=").strip_edges()
	call_deferred("_run")


func _run() -> void:
	if not write_enabled or baseline_commit.is_empty():
		push_error("Golden regeneration requires --write and --baseline-commit=<scope>.")
		quit(2)
		return
	var library := ContentLibraryScript.new()
	library.load(false)
	var document := {
		"baseline_commit": baseline_commit,
		"capture": CrewIgnoredGoldenProbeScript.capture(library),
		"schema_version": 1,
	}
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write crew-ignored golden fixture.")
		quit(1)
		return
	file.store_string(JSON.stringify(document, "  ") + "\n")
	file.close()
	print("CREW_IGNORED_GOLDEN_REGENERATED path=%s baseline=%s" % [ProjectSettings.globalize_path(OUTPUT_PATH), baseline_commit])
	quit(0)
