extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library := ContentLibraryScript.new()
	library.load()
	_check(library.validation_errors.is_empty(), "The content library must load before environment practice generation.")
	if not failures.is_empty():
		_finish()
		return
	_check(library.environment_archetypes.size() >= 18, "Environment practice must expose the complete environment catalog.")
	var scenario_count := 0
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) == TYPE_DICTIONARY:
			scenario_count += library.scenarios_for_archetype(str((archetype_value as Dictionary).get("id", ""))).size()
	_check(scenario_count >= 55, "Environment practice must expose every authored scenario, including debug-only content.")

	var bar_scenarios := library.scenarios_for_archetype("bar")
	_check(not bar_scenarios.is_empty(), "The fixture environment needs an exact scenario.")
	var scenario_id := str((bar_scenarios[0] as Dictionary).get("id", "")) if not bar_scenarios.is_empty() else ""
	var request := {
		"archetype_id": "bar",
		"scenario_id": scenario_id,
		"layer_id": "",
		"generation_key": "repeatable|bar|%s|storm|payday|fight" % scenario_id,
		"condition_overrides": {
			"weather": "storm",
			"day_type": "payday",
			"happenings": ["fight_night"],
		},
		"depth": 0,
	}
	var first := _generate(library, "repeatable", request)
	var second := _generate(library, "repeatable", request)
	if not bool(first.get("ok", false)):
		print("ENVIRONMENT_TEST_FIXTURE_ERROR ", JSON.stringify(first))
	_check(bool(first.get("ok", false)) and bool(second.get("ok", false)), "An exact environment-practice request must generate successfully.")
	var first_environment: Dictionary = first.get("environment", {})
	var second_environment: Dictionary = second.get("environment", {})
	_check(JSON.stringify(first_environment) == JSON.stringify(second_environment), "The same practice seed and selections must reproduce the same environment instance.")
	_check(str(first_environment.get("archetype_id", "")) == "bar", "The requested archetype must be installed.")
	_check(str(first_environment.get("scenario_id", "")) == scenario_id, "The requested scenario must be installed exactly.")
	var town: Dictionary = first_environment.get("town_conditions", {})
	_check(str(town.get("weather", "")) == "storm" and str(town.get("day_type", "")) == "payday", "Exact weather and calendar selections must reach the normal town modifier pipeline.")
	_check((town.get("active_happenings", []) as Array).has("fight_night"), "Exact town happenings must be active in the spawned room.")
	var flags: Dictionary = first_environment.get("local_narrative_flags", {})
	var rects: Dictionary = (first_environment.get("layout", {}) as Dictionary).get("object_rects", {})
	_check(bool(flags.get("environment_test_session", false)) and rects.has("travel:leave"), "Every practice room must expose the Environment Library exit object.")

	var normal_seed_state := RunStateScript.new()
	normal_seed_state.start_new("repeatable")
	var practice_seed_state := RunStateScript.new()
	practice_seed_state.start_new("ENVIRONMENT-PRACTICE-v1:repeatable", RunStateScript.custom_challenge("environment_practice", "ENVIRONMENT-PRACTICE-v1:repeatable"))
	_check(normal_seed_state.seed_value != practice_seed_state.seed_value, "Practice seeds must be deterministic but namespaced away from normal-run seeds.")

	var player := RunStateScript.new()
	player.start_new("player-state")
	player.bankroll = 731
	player.inventory = [{"id": "lucky_keychain"}]
	player.suspicion = {"level": 42, "cues": ["fixture"], "local_levels": {"bar": 42}}
	player.drunk_level = 3
	var carried := player.environment_test_player_state()
	var replacement := RunStateScript.new()
	replacement.start_new("replacement")
	_check(replacement.restore_environment_test_player_state(carried), "The versioned player-state carry snapshot must restore successfully.")
	_check(replacement.bankroll == 731 and replacement.inventory == player.inventory and int(replacement.suspicion.get("level", 0)) == 42 and replacement.drunk_level == 3, "Money, items, heat, and player attributes must carry between practice rooms.")
	player.story_flags["room_specific_fixture"] = true
	carried = player.environment_test_player_state()
	_check(not carried.has("story_flags") and not carried.has("narrative_flags") and not carried.has("active_delivery_run"), "Room, story, and quest state must not leak through the player-only carry snapshot.")

	var layered_scenarios := library.scenarios_for_archetype("small_underground_casino")
	var casino_scenario_id := ""
	for layered_scenario_value in layered_scenarios:
		var layered_scenario: Dictionary = layered_scenario_value
		if str(layered_scenario.get("layer_id", "")) == "casino":
			casino_scenario_id = str(layered_scenario.get("id", ""))
			break
	var scenario_layer_request := request.duplicate(true)
	scenario_layer_request["archetype_id"] = "small_underground_casino"
	scenario_layer_request["scenario_id"] = casino_scenario_id
	scenario_layer_request["layer_id"] = ""
	scenario_layer_request["generation_key"] = "layered-scenario-location"
	var scenario_layer := _generate(library, "scenario-layer", scenario_layer_request)
	if not bool(scenario_layer.get("ok", false)) or str((scenario_layer.get("environment", {}) as Dictionary).get("current_layer_id", "")) != "casino":
		print("ENVIRONMENT_TEST_SCENARIO_LAYER_ERROR ", JSON.stringify(scenario_layer))
	_check(bool(scenario_layer.get("ok", false)) and str((scenario_layer.get("environment", {}) as Dictionary).get("current_layer_id", "")) == "casino", "Scenario / Normal Entrance must open a layered scenario in its authored room.")

	var layered_request := request.duplicate(true)
	layered_request["archetype_id"] = "small_underground_casino"
	layered_request["scenario_id"] = "__none"
	layered_request["layer_id"] = "back_room"
	layered_request["generation_key"] = "layered-back-room"
	var layered := _generate(library, "layered", layered_request)
	if not bool(layered.get("ok", false)):
		print("ENVIRONMENT_TEST_LAYER_ERROR ", JSON.stringify(layered))
	_check(bool(layered.get("ok", false)), "Every layered-environment starting area must be directly testable.")
	var layered_environment: Dictionary = layered.get("environment", {})
	_check(str(layered_environment.get("current_layer_id", "")) == "back_room", "The selected layered starting area must become active.")
	_check(bool((layered_environment.get("local_narrative_flags", {}) as Dictionary).get("environment_test_session", false)), "The Environment Library exit must survive a layered-room projection.")

	_finish()


func _generate(library: ContentLibrary, visible_seed: String, request: Dictionary) -> Dictionary:
	var run_state := RunStateScript.new()
	var domain_seed := "ENVIRONMENT-PRACTICE-v1:%s" % visible_seed
	var scenario_id := str(request.get("scenario_id", "__default"))
	var modifiers := {"environment_practice": true}
	if scenario_id not in ["__default", "__none"]:
		modifiers["scenario_pins"] = {str(request.get("archetype_id", "")): scenario_id}
	run_state.start_new(domain_seed, RunStateScript.custom_challenge("environment_practice", domain_seed, modifiers))
	run_state.bankroll = 100000
	var generator := RunGeneratorScript.new(library)
	return generator.environment_test_result(run_state, request)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ENVIRONMENT_TEST_MODE_CHECK PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
