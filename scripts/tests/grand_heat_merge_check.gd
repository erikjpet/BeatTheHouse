extends SceneTree

const MergeCases := preload("res://scripts/tests/grand_heat_merge_cases.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var report: Dictionary = MergeCases.exercise()
	report["suite"] = "grand_heat_merge"
	print(JSON.stringify(report))
	for failure in report.failures:
		push_error(str(failure))
	quit(0 if report.failures.is_empty() else 1)
