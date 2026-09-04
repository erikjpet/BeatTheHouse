extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const ContractScript := preload("res://scripts/tests/foundation/env06_8_environment_readability_contract.gd")


func _init() -> void:
	var library := ContentLibraryScript.new()
	library.load()
	var failures: Array = []
	ContractScript._check_production_hidden_state_boundary(library, failures)
	if failures.is_empty():
		print("ENV06_8_HIDDEN_BOUNDARY PASS negative=arrival,complication,aftermath positive=heat_changed")
		quit(0)
		return
	for failure in failures:
		printerr("ENV06_8_HIDDEN_BOUNDARY_FAIL %s" % str(failure))
	quit(1)
