extends SceneTree

const ScenarioPresentationContractScript := preload("res://scripts/tests/foundation/scenario_presentation_contract.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array = []
	ScenarioPresentationContractScript.check(failures)
	var report := {
		"passed": failures.is_empty(),
		"failures": failures,
	}
	print("SCENARIO_PRESENTATION_PROBE %s" % JSON.stringify(report))
	for failure in failures:
		push_error(str(failure))
	quit(0 if failures.is_empty() else 1)
