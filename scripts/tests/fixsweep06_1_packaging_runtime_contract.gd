extends SceneTree

const BuildIdentityScript := preload("res://scripts/core/build_identity.gd")
const CoinPusherSolverScript := preload("res://scripts/games/coin_pusher/coin_pusher_solver.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if str(ProjectSettings.get_setting("application/config/version", "")) != "0.6.0":
		failures.append("D3: project release stamp is not 0.6.0.")
	if BuildIdentityScript.display_version() != "0.6.0":
		failures.append("BTH-033: unpacked release source runtime has the wrong release identity.")
	var source_identity := BuildIdentityScript.telemetry_identity({"bth_perf_source_commit": "fixture", "bth_perf_export_sha256": "fixture-export"})
	if str(source_identity.get("identity_source", "")) != "source_harness" or str(source_identity.get("source_commit", "")) != "fixture":
		failures.append("BTH-033: source-tree telemetry compatibility boundary changed unexpectedly.")
	OS.set_environment("BTH_FORCE_DISTRIBUTION_BUILD", "1")
	BuildIdentityScript.reset_cache_for_test()
	var distribution_identity := BuildIdentityScript.telemetry_identity({"bth_perf_source_commit": "untrusted-caller"})
	if BuildIdentityScript.display_version() != "UNBOUND-DISTRIBUTION-BUILD" \
			or str(distribution_identity.get("identity_source", "")) != "missing_embedded_manifest" \
			or not str(distribution_identity.get("source_commit", "")).is_empty():
		failures.append("BTH-033: manifest-less distribution trusted caller identity: %s" % JSON.stringify(distribution_identity))
	OS.set_environment("BTH_FORCE_DISTRIBUTION_BUILD", "")
	BuildIdentityScript.reset_cache_for_test()

	OS.set_environment("BTH_FORCE_DISTRIBUTION_NATIVE_REQUIRED", "1")
	CoinPusherSolverScript.force_native_backend_missing_for_test()
	var stopped := CoinPusherSolverScript.step_ticks({"bodies": []}, {}, 1)
	if bool(stopped.get("ok", true)) \
			or str(stopped.get("error_code", "")) != "native_extension_required" \
			or CoinPusherSolverScript.last_step_backend_for_test() != "native_extension_required":
		failures.append("BTH-041: distribution solver silently fell back without native authority: %s" % JSON.stringify(stopped))
	OS.set_environment("BTH_FORCE_DISTRIBUTION_NATIVE_REQUIRED", "")
	CoinPusherSolverScript.reset_native_backend_for_test()

	if failures.is_empty():
		print("FIXSWEEP06_1_PACKAGING_RUNTIME PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
