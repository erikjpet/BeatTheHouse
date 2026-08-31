extends SceneTree

const ContractScript := preload("res://scripts/tests/foundation/game_ritual_runtime_contract.gd")


func _init() -> void:
	var failures: Array = []
	ContractScript.check(null, failures)
	if failures.is_empty():
		print("Game ritual runtime checks passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
