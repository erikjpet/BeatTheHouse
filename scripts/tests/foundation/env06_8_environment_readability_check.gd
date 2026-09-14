extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const ContractScript := preload("res://scripts/tests/foundation/env06_8_environment_readability_contract.gd")


func _init() -> void:
	var library := ContentLibraryScript.new()
	library.load()
	var failures: Array = []
	ContractScript.check(library, failures)
	if failures.is_empty():
		# Counts are re-derived by the contract itself; printing frozen baseline
		# figures here misreported the post-rework catalog as its pre-rework size.
		print("ENV06_8_ENVIRONMENT_READABILITY PASS")
		quit(0)
		return
	for failure in failures: printerr("ENV06_8_ENVIRONMENT_READABILITY_FAIL %s" % str(failure))
	quit(1)
