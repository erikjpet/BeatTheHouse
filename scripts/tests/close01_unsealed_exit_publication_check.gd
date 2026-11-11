extends "res://tools/foundation_performance_probe.gd"
var exit_checks := 0
func _expect_exit(value: bool, message: String) -> void:
	exit_checks += 1
	if not value: failures.append(message)
func _run() -> void:
	seed_prefix = "CHECK-GODOT-PERF"
	_use_isolated_meta_collection_store(TEST_META_COLLECTION_PATH)
	await _open_fresh_app()
	_expect_exit(_start_synthetic_probe_run("late-crew"),"Real closed-route fixture starts")
	await _settle(3)
	var run: RunState = app.get("run_state")
	var generator := RunGenerator.new(app.get("library"))
	var arrival := HarnessProductionFidelityScript.travel_and_finalize(generator,run,"delta_queen",true,app.get("library"),failures,"closed-route exit publication")
	_expect_exit(bool(arrival.get("ok",false)),"Real Delta arrival finalizes")
	_expect_exit(not run.room_presentation_snapshot().is_empty(),"Delta has committed valid room")
	var has_exit := false
	for row in run.current_environment.get("object_manifest",{}).get("rows",[]):
		if str(row.get("presentation_object_id","")) == "travel:leave": has_exit = true
	_expect_exit(not has_exit and run.current_environment.get("next_archetypes",[]).is_empty(),"Exact fixture has no authorized exit")
	app.call("_refresh_run_action_service")
	app.call("clear_interaction_focus")
	app.call("_refresh")
	await _settle(2)
	var catalog: Array = app.call("room_catalog_snapshot")
	var real_table := false
	for record in catalog:
		_expect_exit(not bool(record.get("room_geometry_rejected",false)),"Valid Delta room must not be rejected for phantom exit: "+str(record.get("object_id")))
		_expect_exit(str(record.get("object_id","")) != "travel:leave","No unsealed physical Leave door")
		if str(record.get("object_id","")) == "game:blackjack": real_table = true
	_expect_exit(real_table,"Valid Delta table remains visible")
	var before := JSON.stringify(run.to_dict())
	_expect_exit(bool(app.call("open_world_map")),"Normal global map still opens locked-route inspection")
	app.call("close_world_map")
	_expect_exit(JSON.stringify(run.to_dict()) == before,"Map inspection preserves complete run")
	_expect_exit(_start_synthetic_probe_run("authorized-exit"),"Normal exit control starts")
	run = app.get("run_state")
	generator = RunGenerator.new(app.get("library"))
	arrival = HarnessProductionFidelityScript.travel_and_finalize(generator,run,"corner_store",true,app.get("library"),failures,"authorized Corner exit")
	_expect_exit(bool(arrival.get("ok",false)),"Corner arrival finalizes")
	app.call("_refresh_run_action_service")
	app.call("clear_interaction_focus")
	app.call("_refresh")
	var found := false
	for record in app.call("room_catalog_snapshot"):
		if str(record.get("object_id","")) == "travel:leave" and str(record.get("presentation_mode","")) == "room": found = true
	_expect_exit(found,"Authorized sealed Leave door remains tangible")
	print("CLOSE01_EXIT_PUBLICATION "+JSON.stringify({"checks":exit_checks,"failures":failures}))
	if app != null: app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
