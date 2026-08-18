extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const ContractScript := preload("res://scripts/tests/foundation/crew_recruitment_contract.gd")
const REPORT_PATH := "res://.tmp/crew06_5_review2/crew_recruitment_focused.json"

func _init() -> void:
	var started := Time.get_ticks_msec()
	var library := ContentLibraryScript.new()
	library.load()
	var failures: Array = library.validation_errors.duplicate(true)
	ContractScript.check(library, failures)
	var report := {
		"passed": failures.is_empty(),
		"failure_count": failures.size(),
		"failures": failures,
		"duration_msec": Time.get_ticks_msec() - started,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH).get_base_dir())
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("Crew recruitment focused check %s report=%s" % ["passed" if failures.is_empty() else "failed", REPORT_PATH])
	quit(0 if failures.is_empty() else 1)
