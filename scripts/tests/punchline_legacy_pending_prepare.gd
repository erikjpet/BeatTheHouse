extends SceneTree

# Synthetic prepatch fixture producer only. The reviewed external supervisor
# owns process admission, private AppData, the OS Job and its hard deadline.
# This script never binds its RunState to FoundationMain or evaluates terminal
# UI state. Generated saves and install authority must stay outside Git.
const SEED := "PUNCHLINE-WITNESS-CHAIRS-ONE"
const SCENARIO_ID := "punchline_debt_court"
const EVENT_ID := "scenario_debt_court_office_hours"
const CHOICE_ID := "watch_the_next_name"
const SLOT := "punchline_legacy_pending_disposable"
const SOURCE_COMMIT := "d8856cd5c61c5136dfe7d14582b57111af5d40dc"
const EXPECTED_RUN_STATE_SHA := "ce4004bf88b8fad184bd0b2699c3d366d9b1c434bbe63ef884460bebcff89290"
const EXPECTED_EVENT_MODULE_SHA := "b571d0f8d2f9937ae8c5d85da6db059047fc2cdb0c2e0af5ed72c9ac6141f133"
const EXPECTED_SEQUENCE_DATA_SHA := "192f09b244fb9e62d027cf5996936e7dddaf502eca2387678585b70ecb15c1fa"
const PREDICATE_ERROR := "scenario event_result does not match an authored payload predicate or delivered event request"
const DEADLINE_MSEC := 40000

var failures: Array[String] = []
var observations: Dictionary = {"stage": "punchline_legacy_prepare", "fixture": "synthetic prepatch Punchline ordinary Watch; not a user save"}
var fixture_root := ""
var report_path := ""
var private_user_dir := ""
var task_root := ""
var started_msec := 0
var finished := false


class RecordingRun:
	extends RunState

	var flush_trace: Array = []

	func scenario_flush_facts(boundary_serial: int = -1) -> Dictionary:
		var result := super.scenario_flush_facts(boundary_serial)
		if flush_trace.size() < 12:
			flush_trace.append({
				"ok": bool(result.get("ok", false)),
				"errors": (result.get("errors", []) as Array).duplicate(true),
				"processed_count": (result.get("processed", []) as Array).size(),
				"boundary_serial": boundary_serial,
			})
		return result


func _init() -> void:
	# FIRST operation: no RunState, profile or authority access before this guard.
	if not _private_userdata_confirmed():
		push_error("REFUSED: resolved user:// must match the task-owned disposable directory.")
		quit(64)
		return
	if not OS.get_cmdline_user_args().has("--punchline-qualification-authorized") or OS.get_environment("BTH_SCRATCH_REGRESSION_STAGE") != "punchline_legacy_prepare":
		push_error("REFUSED: --punchline-qualification-authorized is required.")
		quit(64)
		return
	fixture_root = OS.get_environment("BTH_SCRATCH_FIXTURE_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	report_path = OS.get_environment("BTH_SCRATCH_REPRO_REPORT").replace("\\", "/").simplify_path()
	var allowed_fixtures := task_root.path_join("repro-fixtures")
	if fixture_root.is_empty() or not _within(fixture_root, allowed_fixtures, true) \
		or report_path.is_empty() or not _within(report_path, task_root) \
		or FileAccess.file_exists(report_path):
		push_error("REFUSED: new task-local report and task repro-fixtures root are required.")
		quit(64)
		return
	if DirAccess.dir_exists_absolute(fixture_root.path_join("punchline_old_pending")) \
		or FileAccess.file_exists(fixture_root.path_join("punchline_old_pending")):
		push_error("REFUSED: preserved Punchline fixture bundle already exists.")
		quit(64)
		return
	call_deferred("_run")


func _run() -> void:
	started_msec = Time.get_ticks_msec()
	create_timer(float(DEADLINE_MSEC) / 1000.0).timeout.connect(func() -> void:
		if not finished:
			failures.append("In-engine 40s preparation deadline expired.")
			_finish(124)
	)
	if not _require(FileAccess.get_sha256("res://scripts/core/run_state.gd") == EXPECTED_RUN_STATE_SHA \
		and FileAccess.get_sha256("res://scripts/core/event_module.gd") == EXPECTED_EVENT_MODULE_SHA \
		and FileAccess.get_sha256("res://data/environments/scenario_sequences/env06_7_underground_lounge.json") == EXPECTED_SEQUENCE_DATA_SHA,
		"Legacy producer requires the exact reviewed prepatch source bodies."):
		_finish()
		return
	var library := ContentLibrary.new()
	library.load(false)
	if not _require(library.validation_errors.is_empty() and library.is_fully_loaded(), "Normal deferred-validation content load failed.") or not _within_deadline():
		_finish()
		return
	var save_script: Script = load("res://scripts/core/save_service.gd")
	var save_service: RefCounted = save_script.new()
	var save_path := ProjectSettings.globalize_path(str(save_service.call("run_save_path", SLOT)))
	var backup_path := ProjectSettings.globalize_path(str(save_service.call("backup_save_path", SLOT)))
	var profile_script: Script = load("res://scripts/core/profile_inventory.gd")
	var profile_path := ProjectSettings.globalize_path(str(profile_script.store_path()))
	var authority_path := private_user_dir.path_join(".crew_host_authority_v1")
	for path in [save_path, backup_path, profile_path, profile_path + ".bak", authority_path]:
		if not _require(_within(path, private_user_dir) and not FileAccess.file_exists(path), "Fixture storage must be new and inside the verified private user directory."):
			_finish()
			return
	var run := RecordingRun.new()
	run.start_new(SEED, RunState.custom_challenge("punchline_witness_chairs", SEED, {
		"scenario_pins": {"small_underground_casino": SCENARIO_ID},
	}))
	run.game_clock_minutes = 7515
	run.bankroll = 25
	run.begin_act(1)
	var generator := RunGenerator.new(library)
	var installed := generator.travel_environment_result(run, "small_underground_casino", true)
	observations["factory_install"] = _result_summary(installed)
	if not _require(bool(installed.get("ok", false)), "Normal pinned Debt Court factory installation failed.") or not _within_deadline():
		_finish()
		return
	run.add_suspicion("punchline_repro_setup", 3 - run.suspicion_level(), "behavior", false)
	var env := run.current_environment
	var controller: Script = load("res://scripts/ui/environment_interaction_controller.gd")
	var baseline_join: Dictionary = controller._object_manifest_join_proof(env.duplicate(true))
	observations["baseline_strict_join"] = _result_summary(baseline_join)
	observations["baseline_signature"] = _signature(run)
	if not _require(str(env.get("scenario_id", "")) == SCENARIO_ID and bool(run.call("_scenario_semantic_ready")), "Normal factory did not seal the requested Debt Court scenario.") \
		or not _require(bool(baseline_join.get("ok", false)), "Factory baseline strict manifest join rejected.") \
		or not _require(run.game_clock_minutes == 7515 and run.bankroll == 25 and run.suspicion_level() == 3 and run.drunk_level == 0, "Factory time, cash, heat or sobriety differs from the requested setup.") \
		or not _require(not run.is_tutorial_run() and not run.is_terminal() and run.run_status == RunState.RUN_STATUS_ACTIVE and run.debt.is_empty(), "Fixture must remain an active normal run with no debt."):
		_finish()
		return
	var module_script: Script = load("res://scripts/core/event_module.gd")
	var module: RefCounted = module_script.new()
	module.call("setup", library.event(EVENT_ID), library)
	if not _require(bool(module.call("can_trigger", run, env)), "Normal Collector event cannot trigger in the sealed factory room."):
		_finish()
		return
	var event_result: Dictionary = module.call("resolve", run, env, CHOICE_ID)
	observations["event_result"] = _result_summary(event_result)
	observations["real_flush_trace"] = run.flush_trace.duplicate(true)
	var state: Dictionary = run.current_environment.get("scenario_sequence_state", {})
	var queue: Array = state.get("fact_queue", [])
	var matching: Array = []
	for value in queue:
		var fact: Dictionary = value
		var payload: Dictionary = fact.get("payload", {})
		if str(fact.get("fact_type", "")) == "event_result" and str(payload.get("event_id", "")) == EVENT_ID and str(payload.get("choice_id", "")) == CHOICE_ID:
			matching.append(fact.duplicate(true))
	var flush_rejected := false
	for value in run.flush_trace:
		if not bool(value.get("ok", false)) and (value.get("errors", []) as Array).has(PREDICATE_ERROR):
			flush_rejected = true
	observations["pending_event_facts"] = matching.duplicate(true)
	if not _require(bool(event_result.get("ok", false)) and (run.current_environment.get("resolved_event_ids", []) as Array).has(EVENT_ID), "Real ordinary Watch did not resolve successfully.") \
		or not _require(flush_rejected and matching.size() == 1, "Real prepatch event flush did not retain exactly one rejected ordinary Watch fact.") \
		or not _require(str((matching[0].get("payload", {}) as Dictionary).get("resolution_id", "")) == "", "Ordinary Watch unexpectedly acquired bridge correlation.") \
		or not _require(not run.is_terminal() and run.run_status == RunState.RUN_STATUS_ACTIVE and run.bankroll == 25, "Event-only fixture unexpectedly changed cash or ended the run.") \
		or not _within_deadline():
		_finish()
		return
	var original_signature := _signature(run)
	var detached := RunState.new()
	detached.from_dict(run.to_dict().duplicate(true))
	if not _require(detached.restore_trusted_scenario_semantics(run.current_environment), "Detached diagnostic could not retain the exact trusted same-process room semantics."):
		_finish()
		return
	var detached_before := _signature(detached)
	var failed_turn := detached.advance_environment_turns(1)
	observations["detached_failed_turn"] = _result_summary(failed_turn)
	observations["detached_turn_unchanged"] = _signature(detached) == detached_before
	observations["original_unchanged_by_diagnostic"] = _signature(run) == original_signature
	if not _require(not bool(failed_turn.get("ok", false)) and (failed_turn.get("errors", []) as Array).has(PREDICATE_ERROR), "Detached normal turn did not reject the retained fact for the expected predicate reason.") \
		or not _require(bool(observations["detached_turn_unchanged"]) and bool(observations["original_unchanged_by_diagnostic"]), "Detached rejected turn changed the copied or original run."):
		_finish()
		return
	# Two ordinary saves of the same pending state create a genuine primary and
	# backup generation through DurableStore's normal rotation, not copied JSON.
	for generation in range(2):
		var save_error := int(save_service.call("save_run", run, SLOT))
		if not _require(save_error == OK, "Normal SaveService pending fixture save failed at generation %d." % generation) or not _within_deadline():
			_finish()
			return
	var profile: RefCounted = profile_script.new()
	profile.call("from_dict", {})
	for generation in range(2):
		if not _require(int(profile.call("save")) == OK, "Normal private profile save failed.") or not _within_deadline():
			_finish()
			return
	if not _require(_signature(run) == original_signature and not run.is_terminal(), "Fixture serialization changed the original pending run."):
		_finish()
		return
	var bundle := fixture_root.path_join("punchline_old_pending")
	if not _require(not DirAccess.dir_exists_absolute(bundle) and not FileAccess.file_exists(bundle), "Refusing to overwrite a preserved fixture bundle.") \
		or not _require(DirAccess.make_dir_recursive_absolute(bundle) == OK, "Could not create the private fixture bundle."):
		_finish()
		return
	var sources := {
		"save.json": save_path,
		"save.json.bak": backup_path,
		"crew-authority.bin": authority_path,
		"profile_inventory.json": profile_path,
		"profile_inventory.json.bak": profile_path + ".bak",
	}
	var hashes: Dictionary = {}
	for name_value in sources:
		var name := str(name_value)
		var source := str(sources[name_value])
		if not _require(FileAccess.file_exists(source) and _within(source, private_user_dir), "Expected private fixture companion is absent or escaped its namespace.") \
			or not _require(DirAccess.copy_absolute(source, bundle.path_join(name)) == OK, "Could not preserve a known fixture companion."):
			_finish()
			return
		var source_hash := FileAccess.get_sha256(source)
		var copied_hash := FileAccess.get_sha256(bundle.path_join(name))
		if not _require(not source_hash.is_empty() and source_hash == copied_hash, "Preserved fixture companion hash mismatch."):
			_finish()
			return
		hashes[name] = copied_hash
	var metadata := {
		"kind": "synthetic_prepatch_punchline_pending_ordinary_watch",
		"source_commit": SOURCE_COMMIT, "slot_id": SLOT, "seed": SEED,
		"save_sha256": str(hashes["save.json"]), "backup_sha256": str(hashes["save.json.bak"]),
		"authority_sha256": str(hashes["crew-authority.bin"]),
		"profile_sha256": str(hashes["profile_inventory.json"]),
		"profile_backup_sha256": str(hashes["profile_inventory.json.bak"]),
		"expected_semantic_digest": str(run.current_environment.get("scenario_semantic_digest", "")),
		"expected_semantic_version": int(run.current_environment.get("scenario_semantic_inventory_version", 0)),
		"expected_pending_fact": matching[0].duplicate(true),
		"signature": original_signature,
		"save_generations": 2, "host_run_bound": false,
		"source_hashes": {"run_state": EXPECTED_RUN_STATE_SHA, "event_module": EXPECTED_EVENT_MODULE_SHA, "sequence_data": EXPECTED_SEQUENCE_DATA_SHA},
	}
	var metadata_text := JSON.stringify(metadata)
	var metadata_file := FileAccess.open(bundle.path_join("metadata.json"), FileAccess.WRITE) if metadata_text.to_utf8_buffer().size() <= 65536 else null
	if not _require(metadata_file != null, "Could not open bounded fixture metadata."):
		_finish()
		return
	metadata_file.store_string(metadata_text)
	var metadata_error := metadata_file.get_error()
	metadata_file.close()
	_require(metadata_error == OK, "Could not write fixture metadata.")
	observations["fixture_metadata"] = metadata
	observations["fixture_bundle"] = bundle
	observations["original_pending_run_active"] = not run.is_terminal() and run.run_status == RunState.RUN_STATUS_ACTIVE
	observations["save_preserved"] = failures.is_empty()
	_within_deadline()
	_finish()


func _signature(run: RunState) -> Dictionary:
	var env := run.current_environment
	var state: Dictionary = env.get("scenario_sequence_state", {})
	return {
		"bankroll": run.bankroll, "grand_casino_chips": run.grand_casino_chips,
		"game_clock_minutes": run.game_clock_minutes, "rng_seed": run.rng_seed, "rng_state": run.rng_state,
		"run_status": run.run_status, "turns": int(env.get("turns", 0)),
		"debt": run.debt.duplicate(true), "story_log": run.story_log.duplicate(true),
		"semantic_digest": str(env.get("scenario_semantic_digest", "")),
		"semantic_version": int(env.get("scenario_semantic_inventory_version", 0)),
		"queue": (state.get("fact_queue", []) as Array).duplicate(true),
		"command_receipts": (state.get("command_receipts", []) as Array).duplicate(true),
		"fact_receipts": (state.get("fact_receipts", []) as Array).duplicate(true),
	}


func _result_summary(result: Dictionary) -> Dictionary:
	return {
		"ok": bool(result.get("ok", false)), "applied": bool(result.get("applied", false)),
		"errors": (result.get("errors", []) as Array).duplicate(true),
		"message": str(result.get("message", "")),
		"event_id": str(result.get("event_id", result.get("source_id", ""))),
		"choice_id": str(result.get("choice_id", result.get("action_id", ""))),
		"resolution_id": str(result.get("resolution_id", "")),
	}


func _private_userdata_confirmed() -> bool:
	var actual := ProjectSettings.globalize_path("user://")
	var expected := OS.get_environment("BTH_SCRATCH_REPRO_USER_DIR")
	task_root = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	private_user_dir = actual.replace("\\", "/").simplify_path().trim_suffix("/")
	return not expected.is_empty() and _canonical(actual) == _canonical(expected) and _within(actual, task_root)


func _canonical(path: String) -> String:
	return path.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()


func _within(path: String, parent: String, allow_equal: bool = false) -> bool:
	var clean := _canonical(path)
	var root_path := _canonical(parent)
	return not root_path.is_empty() and (clean.begins_with(root_path + "/") or allow_equal and clean == root_path)


func _within_deadline() -> bool:
	return _require(Time.get_ticks_msec() - started_msec <= DEADLINE_MSEC, "In-engine 40s preparation deadline exceeded at a synchronous API boundary.")


func _require(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	return condition


func _finish(forced_code: int = -1) -> void:
	if finished:
		return
	finished = true
	observations["elapsed_msec"] = Time.get_ticks_msec() - started_msec
	observations["failures"] = failures.duplicate()
	var report_text := JSON.stringify(observations)
	var report := FileAccess.open(report_path, FileAccess.WRITE) if report_text.to_utf8_buffer().size() <= 65536 else null
	var written := report != null
	if report != null:
		report.store_string(report_text)
		written = report.get_error() == OK
		report.close()
	var exit_code := forced_code if forced_code >= 0 else (0 if failures.is_empty() else 1)
	if not written:
		exit_code = 74
	print("PUNCHLINE_LEGACY_PENDING_PREPARE status=%s failures=%d" % ["PASS" if exit_code == 0 else "FAIL", failures.size()])
	quit(exit_code)
