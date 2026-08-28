extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const ScenarioSequenceContractScript := preload("res://scripts/tests/foundation/scenario_sequence_contract.gd")
const ScenarioSemanticPresentationContractScript := preload("res://scripts/tests/foundation/scenario_semantic_presentation_contract.gd")
const EnvironmentSemanticInventoryContractScript := preload("res://scripts/tests/foundation/environment_semantic_inventory_contract.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library = ContentLibraryScript.new()
	library.load()
	var failures: Array = []
	ScenarioSequenceContractScript.check(library, failures, self)
	ScenarioSemanticPresentationContractScript.check(library, failures)
	EnvironmentSemanticInventoryContractScript.check(library, failures)
	if failures.is_empty():
		print("env06_6 full scenario contract passed")
		quit(0)
		return
	print("ENV06_6_FAILURES_JSON=" + JSON.stringify(failures))
	for failure_value in failures:
		push_error(str(failure_value))
	quit(1)
