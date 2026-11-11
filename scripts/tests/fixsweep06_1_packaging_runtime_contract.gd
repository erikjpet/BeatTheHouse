extends SceneTree

const BuildIdentityScript := preload("res://scripts/core/build_identity.gd")
const MainScript := preload("res://scripts/ui/foundation_main.gd")
const CoinPusherSolverScript := preload("res://scripts/games/coin_pusher/coin_pusher_solver.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if str(ProjectSettings.get_setting("application/config/version", "")) != "0.6.0":
		failures.append("D3: project release stamp is not 0.6.0.")
	if BuildIdentityScript.display_version() != BuildIdentityScript.RELEASE_VERSION:
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
	var manifest_fixture := {"schema": "beat_the_house.build_manifest/v1"}
	for field in BuildIdentityScript.REQUIRED_FIELDS:
		manifest_fixture[field] = "retained-internal-value"
	manifest_fixture["source_commit"] = "973f0ba2ae5fbf50f38cac3346a433c13a1e5c2c"
	manifest_fixture["build_version"] = "0.6.0-dev+fixture"
	BuildIdentityScript._manifest_loaded = true
	BuildIdentityScript._manifest_cache = manifest_fixture.duplicate(true)
	if BuildIdentityScript.display_version() != "%s (973f0ba2ae5f)" % BuildIdentityScript.RELEASE_VERSION:
		failures.append("CLOSE-04: distribution display does not show RELEASE_VERSION and the short source commit.")
	if BuildIdentityScript.telemetry_identity().get("build_version") != manifest_fixture["build_version"]:
		failures.append("CLOSE-04: retained internal telemetry identity changed.")
	OS.set_environment("BTH_FORCE_DISTRIBUTION_BUILD", "")
	BuildIdentityScript.reset_cache_for_test()
	var menu := MainScript.new()
	root.add_child(menu)
	for frame in range(8):
		await process_frame
	var menu_text := str(menu.current_start_menu_snapshot().get("release_version_text", ""))
	if menu_text != "Version %s" % BuildIdentityScript.RELEASE_VERSION:
		failures.append("CLOSE-04: source menu does not show RELEASE_VERSION: %s" % menu_text)
	print("CLOSE04_SOURCE_MENU ", menu_text)
	menu.queue_free()
	await process_frame

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
