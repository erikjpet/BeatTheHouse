extends SceneTree

const Report := preload("res://scripts/ui/run_report_view_model.gd")
const Runtime := preload("res://scripts/core/game_ritual_runtime.gd")
const FIXTURE := "res://scripts/tests/fixtures/integ06_1/v0_5_1/v051_grand_casino_back_room_duel.json"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty():
		quit(2)
		return
	var save := SaveService.new()
	var dest := save.run_save_path("rourke_report_fixture")
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	var file := FileAccess.open(dest, FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(FIXTURE))
	file.close()
	var run: RunState = save.load_run("rourke_report_fixture")
	if run == null:
		push_error("Report fixture failed production load")
		quit(1)
		return
	_compare(run, "preserved fixture")
	# Exercise nonempty scenario and rumor ledgers as well as the original save.
	# This explicitly annotated copy is coverage data, not the Web fixture.
	var annotated := run.detached_host_action_candidate("blackjack")
	annotated.run_status = RunState.RUN_STATUS_FAILED
	annotated.run_failure_reason = "grand_casino_duel_loss"
	var annotated_scenario := false
	for node in annotated.world_map.get("nodes", []):
		if typeof(node) != TYPE_DICTIONARY or not annotated.world_map.get("visited_path", []).has(str(node.get("id", ""))):
			continue
		var environment: Dictionary = node.get("environment", {})
		environment["scenario_id"] = "scenario_report_check"
		environment["scenario_state"] = {"id":"scenario_report_check", "display_name":"Known scenario", "private_runtime_program":{"unused":[1,2,3]}}
		node["environment"] = environment
		annotated.town_state.living_world.heard_by_node[str(node.id)] = {"known_rumor":true}
		annotated_scenario = true
		break
	_check(annotated_scenario, "annotated case reaches a visited room")
	_compare(annotated, "terminal scenario and rumor ledgers")
	print("ROURKE_TERMINAL_REPORT ", JSON.stringify({"failures":failures,"cases":2,"source":"preserved migrated fixture plus explicitly annotated terminal copy","comparison":"complete model/profile parity except unused map node environment storage"}))
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _compare(run: RunState, label: String) -> void:
	var before := Runtime.canonical_json(run.to_save_snapshot())
	var full := run.to_dict()
	full["terminal_score"] = run.terminal_score_summary()
	var started := Time.get_ticks_usec()
	var projected := Report.snapshot_run(run)
	projected["terminal_score"] = run.terminal_score_summary()
	var model := Report.build(projected)
	var usec := Time.get_ticks_usec()-started
	var prior := Report.build(full)
	if run.is_terminal():
		var world: Dictionary = prior.release_0_6.world
		_check(not world.scenarios.is_empty() and int(world.rumors_proved_true) > 0, "annotated terminal case exercises nonempty scenario and rumor ledgers")
	_strip_unrendered_storage(model)
	_strip_unrendered_storage(prior)
	_check(Runtime.canonical_json(model) == Runtime.canonical_json(prior), label+": complete visible report model parity")
	_check(Runtime.canonical_json(Report.release_profile_snapshot(projected)) == Runtime.canonical_json(Report.release_profile_snapshot(full)), label+": complete profile ledger parity")
	_check(before == Runtime.canonical_json(run.to_save_snapshot()), label+": snapshot/build leave every live run field unchanged")
	model.map_snapshot.clear()
	_check(before == Runtime.canonical_json(run.to_save_snapshot()), label+": output edits cannot mutate the run")
	print("ROURKE_REPORT_CASE ", JSON.stringify({"case":label,"project_and_build_usec":usec}))

func _strip_unrendered_storage(model: Dictionary) -> void:
	for node in model.get("map_snapshot", {}).get("nodes", []):
		if typeof(node) == TYPE_DICTIONARY: node.erase("environment")

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
