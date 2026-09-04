extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const TutorialFlowScript := preload("res://scripts/core/tutorial_flow.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")


func _init() -> void:
	var failures: Array = []
	var library := ContentLibraryScript.new()
	library.load(false)
	if library.validation_complete:
		failures.append("Deferred runtime fixture unexpectedly ran the exhaustive content audit.")
	var config := TutorialFlowScript.challenge_config(library)
	var run_state := RunStateScript.new()
	run_state.start_new(str(config.get("seed_text", "FIRST-NIGHT-ACE-17")), config)
	run_state.begin_act(1)
	var generator := RunGeneratorScript.new(library)
	var started_msec := Time.get_ticks_msec()
	generator.next_environment(run_state)
	var generation_msec := Time.get_ticks_msec() - started_msec
	if generation_msec > 5000:
		failures.append("Deferred tutorial generation exceeded 5000 ms: %d ms." % generation_msec)
	if str(run_state.current_environment.get("archetype_id", "")) != "apartment":
		failures.append("Deferred tutorial generation did not enter the authored apartment.")
	var seeded_corner := run_state._seeded_scenario_definition_for_node_readonly("corner_store")
	if str(seeded_corner.get("id", "")) != "corner_store_delivery_day" or not bool(seeded_corner.get(ScenarioEngineScript.SEQUENCE_SUPPRESSION_KEY, false)):
		failures.append("Town priming did not retain the tutorial's suppressed Corner Store pin.")
	if bool(seeded_corner.get(ScenarioEngineScript.VALIDATED_SEQUENCE_MARKER, false)):
		failures.append("Unvisited scenario carried a semantic validation receipt before installation.")
	var entered := generator.next_environment(run_state, "corner_store", true)
	if entered == null or str(run_state.current_environment.get("archetype_id", "")) != "corner_store":
		failures.append("The deferred selected scenario could not be installed.")
	if run_state.current_environment.has("scenario_sequence_state"):
		failures.append("The tutorial's explicitly suppressed scenario installed a dynamic sequence.")
	var delivery_definition: Dictionary = {}
	for definition_value in library.environment_scenarios.get("corner_store", []):
		if typeof(definition_value) == TYPE_DICTIONARY and str((definition_value as Dictionary).get("id", "")) == "corner_store_delivery_day":
			delivery_definition = definition_value as Dictionary
			break
	var validated_definition := library._runtime_validated_scenario_definition(delivery_definition)
	if not bool(validated_definition.get(ScenarioEngineScript.VALIDATED_SEQUENCE_MARKER, false)):
		failures.append("Selected production scenario did not carry an exact accepted-package runtime receipt.")
	var tampered_definition := validated_definition.duplicate(true)
	tampered_definition["sequence_renderer_id"] = "tampered_renderer"
	if library._runtime_scenario_sequence_authorization_errors(tampered_definition).is_empty():
		failures.append("Runtime package authorization accepted a tampered renderer identity.")
	if library.validation_complete:
		failures.append("Selected scenario validation escalated into the exhaustive catalog audit.")
	if not library.validation_errors.is_empty():
		failures.append("Selected scenario validation reported errors: %s" % JSON.stringify(library.validation_errors))
	if failures.is_empty():
		print("PERF06_DEFERRED_VALIDATION_PASS generation_msec=%d" % generation_msec)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
