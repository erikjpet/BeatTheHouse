extends SceneTree

# Deliberately invokes the native encoder's recursion failure. Its ERROR stderr
# is expected in this standalone negative probe, not a normal contract-suite log.
const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")


func _init() -> void:
	print("SCENARIO_MEMO_ENCODING_FAILURE expected_native_recursion_errors_begin")
	var loop: Dictionary = {}
	loop["cycle"] = loop
	var prime := {"id": "memo_cycle_prime", "unused": loop}
	var invalid := {"id": "memo_cycle_invalid", "sequence": {"cycle": loop}}
	Schema._clear_successful_validation_memo_for_tests()
	var cold_errors := Schema.validate_definition(invalid)
	Schema._clear_successful_validation_memo_for_tests()
	var prime_errors := Schema.validate_definition(prime)
	var after_prime := Schema._successful_validation_memo_stats_for_tests()
	var warm_errors := Schema.validate_definition(invalid)
	var repeat_errors := Schema.validate_definition(invalid)
	var after_warm := Schema._successful_validation_memo_stats_for_tests()
	var ok := prime_errors.is_empty() and int(after_prime.entries) == 0 and not cold_errors.is_empty() \
		and cold_errors == warm_errors and cold_errors == repeat_errors \
		and int(after_warm.entries) == 0 and int(after_warm.hits) == 0 and int(after_warm.full_runs) == 3
	print(JSON.stringify({"kind": "serialization_failure_memo_probe", "ok": ok, "after_prime": after_prime,
		"cold_errors": cold_errors, "warm_errors": warm_errors, "repeat_errors": repeat_errors, "after_warm": after_warm}))
	# Break the synthetic reference cycle before teardown.
	loop.clear()
	if ok:
		print("SCENARIO_MEMO_ENCODING_FAILURE PASS expected_native_recursion_errors_end")
	else:
		push_error("Failed native encoding reused or stored a successful validation key.")
	quit(0 if ok else 1)
