extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const ContractScript := preload("res://scripts/tests/foundation/env06_8_environment_readability_contract.gd")


func _init() -> void:
	var library := ContentLibraryScript.new()
	library.load()
	var failures: Array = []
	var telemetry: Dictionary = {}
	var started_usec := Time.get_ticks_usec()
	ContractScript.check_geometry(library, failures, telemetry)
	var elapsed_msec := int((Time.get_ticks_usec() - started_usec) / 1000)
	if failures.is_empty():
		print("ENV06_8_ENVIRONMENT_GEOMETRY PASS scenarios=55 reachable_states=%d layouts=%d candidate_checks=%d max_search=%d candidate_limit=%d elapsed_msec=%d" % [
			int(telemetry.get("reachable_state_count", 0)),
			int(telemetry.get("layout_state_count", 0)),
			int(telemetry.get("candidate_checks", 0)),
			int(telemetry.get("max_search", 0)),
			int(telemetry.get("candidate_limit", 0)),
			elapsed_msec,
		])
		quit(0)
		return
	for failure in failures:
		printerr("ENV06_8_ENVIRONMENT_GEOMETRY_FAIL %s" % str(failure))
	printerr("ENV06_8_ENVIRONMENT_GEOMETRY_SUMMARY scenarios=55 reachable_states=%d layouts=%d candidate_checks=%d max_search=%d candidate_limit=%d elapsed_msec=%d failures=%d" % [
		int(telemetry.get("reachable_state_count", 0)),
		int(telemetry.get("layout_state_count", 0)),
		int(telemetry.get("candidate_checks", 0)),
		int(telemetry.get("max_search", 0)),
		int(telemetry.get("candidate_limit", 0)),
		elapsed_msec,
		failures.size(),
	])
	quit(1)
