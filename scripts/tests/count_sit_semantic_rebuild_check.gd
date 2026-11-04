extends SceneTree

# Synthetic Count decision boundary. No original profile, wager, or Save is used.
const MainScene := preload("res://scenes/main.tscn")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const SLOT := "count_sit_semantic_synthetic"
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var private_root := OS.get_environment("BTH_COUNT_PRIVATE_ROOT").replace("\\", "/").trim_suffix("/")
	var user_dir := ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not private_root.is_absolute_path() or not private_root.contains("/native-private-count-sit-") or not user_dir.begins_with(private_root + "/"):
		print("COUNT_SIT_PROBE ", JSON.stringify({"error": "private root containment"}))
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	var app := MainScene.instantiate()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for i in range(2): await process_frame
	app.set_process(false)
	app._ensure_run_ui_built()
	app._ensure_full_content_library_loaded()
	if OS.get_environment("BTH_COUNT_SIT_COLD") == "1":
		var cold: RunState = SaveService.new().load_run(SLOT)
		_check(cold != null, "fresh process restores synthetic Sit checkpoint")
		if cold != null:
			app.run_state = cold
			app._prepare_room_presentation_at_boundary()
			facts["cold"] = {"cash": cold.bankroll, "chips": cold.grand_casino_chips,
				"heat": cold.suspicion_level(), "decision": cold.crew_heist_state.get("play", {}).get("decisions", {}).get("distraction", ""),
				"pending_rebuild": cold.current_environment.get("scenario_restore_pending_trusted_rebuild", false)}
			_check(cold._scenario_semantic_ready() and bool(cold.validate_room_action_authority().get("ok", false)), "cold Sit room has strict semantic and object authority")
			_check(facts.cold.decision == "sit" and facts.cold.cash == 100 and facts.cold.chips == 0, "cold Sit decision and finances persist without replay")
		app.queue_free()
		await process_frame
		print("COUNT_SIT_PROBE ", JSON.stringify({"checks": checks, "failures": failures, "facts": facts, "mode": "cold"}))
		quit(0 if failures.is_empty() else 1)
		return
	var run := RunState.new()
	run.start_new("COUNT-SIT-SYNTHETIC-R06")
	run.game_clock_minutes = 3 * 1440 + 135
	var errors: Array = []
	var arrival := Fidelity.generate_and_finalize(app.generator, run, errors, "synthetic Count Sit room", "grand_casino", true)
	_check(bool(arrival.get("ok", false)) and errors.is_empty(), "synthetic Grand room installs with valid authority")
	if errors.is_empty():
		app.run_state = run
		run.world_map["current_node_id"] = str(run.current_environment.get("world_node_id", "grand_casino"))
		var count := CrewHeistModel.begin("the_count", 14)
		count["status"] = CrewHeistModel.STATUS_PLAY
		count["setup"] = {"identity": true, "schedule": true, "swap_cart": true}
		run.crew_heist_state = count
		run.narrative_flags["heist_live_table_active"] = true
		_check(run._crew_heist_boundary_sync() and run.current_environment.get("event_ids", []).has("heist_live_table"), "live table is authored in current room")
		var event := EventModule.new()
		event.setup(app.library.event("heist_live_table"), app.library)
		var hold := event.resolve(run, run.current_environment, "go_hold")
		facts["hold"] = {"ok": hold.get("ok", false), "message": hold.get("message", "")}
		_check(bool(hold.get("ok", false)), "ordinary Hold decision succeeds")
		if bool(hold.get("ok", false)):
			var play_state: Dictionary = run.crew_heist_state.duplicate(true)
			var play: Dictionary = play_state.get("play", {}).duplicate(true)
			play["round"] = 1
			play_state["play"] = play
			run.crew_heist_state = play_state
			var finalized := run.scenario_finalize_installed_environment(app.library)
			facts["finalized"] = {"ok": finalized.get("ok", false), "errors": finalized.get("errors", [])}
			facts["before_semantics"] = {"scenario_present": run.scenario_sequence_present(), "semantic_ready": run._scenario_semantic_ready(), "pending_rebuild": run.current_environment.get("scenario_restore_pending_trusted_rebuild", false), "scenario_id": run.current_environment.get("scenario_id", "")}
			_check(bool(finalized.get("ok", false)) and run._scenario_semantic_ready(), "mounted Count room has strict semantic proof before Sit")
			var choices: Array = event.choices(run, run.current_environment)
			facts["choice_ids"] = choices.map(func(c): return str(c.get("id", "")))
			_check(facts.choice_ids.has("distraction_sit"), "Sit is an authored available choice")
			var before := {"cash": run.bankroll, "chips": run.grand_casino_chips, "heat": run.suspicion_level(), "clock": run.game_clock_minutes}
			facts["before"] = before
			var sit := event.resolve(run, run.current_environment, "distraction_sit")
			facts["sit"] = {"ok": sit.get("ok", false), "message": sit.get("message", ""), "errors": sit.get("errors", [])}
			facts["pending_rebuild"] = run.current_environment.get("scenario_restore_pending_trusted_rebuild", false)
			facts["after"] = {"cash": run.bankroll, "chips": run.grand_casino_chips, "heat": run.suspicion_level(), "clock": run.game_clock_minutes}
			_check(bool(sit.get("ok", false)), "Sit decision passes post-hook semantic turn preflight")
			if bool(sit.get("ok", false)):
				_check(run._scenario_semantic_ready(), "room remains strictly finalized after Sit")
				_check(run.bankroll == before.cash and run.grand_casino_chips == before.chips, "Sit does not touch cash or chips")
				_check(str(run.crew_heist_state.get("play", {}).get("decisions", {}).get("distraction", "")) == "sit", "Sit records only its authored decision")
				var committed := {"cash": run.bankroll, "chips": run.grand_casino_chips,
					"heat": run.suspicion_level(), "heist": run.crew_heist_state.duplicate(true), "rng": run.rng_state}
				var repeat := event.resolve(run, run.current_environment, "distraction_sit")
				facts["repeat"] = {"ok": repeat.get("ok", false), "message": repeat.get("message", "")}
				_check(not bool(repeat.get("ok", true)), "Sit cannot be accepted twice")
				_check(run.bankroll == committed.cash and run.grand_casino_chips == committed.chips \
					and run.suspicion_level() == committed.heat and run.crew_heist_state == committed.heist \
					and run.rng_state == committed.rng, "rejected repeat leaves financial, Crew and RNG state unchanged")
				var saved: Error = app.save_service.save_run(run, SLOT)
				_check(saved == OK, "synthetic Sit checkpoint saves through official service")
	app.queue_free()
	await process_frame
	print("COUNT_SIT_PROBE ", JSON.stringify({"checks": checks, "failures": failures, "facts": facts}))
	quit(0 if failures.is_empty() else 1)
