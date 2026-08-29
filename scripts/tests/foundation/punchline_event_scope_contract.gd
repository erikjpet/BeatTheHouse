extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const SCOPE_CASES := {
	"punchline_debt_court": "scenario_debt_court_office_hours",
	"punchline_raid_jitters": "scenario_raid_jitters_check",
}


func _init() -> void:
	var failures: Array[String] = []
	var library = ContentLibraryScript.new()
	library.load(true)
	var archetype: Dictionary = library.environment_archetype("small_underground_casino")
	for scenario_id_value in SCOPE_CASES.keys():
		var scenario_id := str(scenario_id_value)
		var event_id := str(SCOPE_CASES.get(scenario_id_value, ""))
		var definition: Dictionary = library.scenario(scenario_id)
		var event_definition: Dictionary = library.event(event_id)
		if str(definition.get("layer_id", "")) != "club" or event_definition.get("scopes", []) != ["club"]:
			failures.append("%s and %s do not share the authoritative club scope." % [scenario_id, event_id])
			continue

		var club_run = RunStateScript.new()
		club_run.start_new("PUNCHLINE-SCOPE-CLUB-%s" % scenario_id)
		var club_environment := EnvironmentInstanceScript.from_archetype_layer(archetype, "club", 2, club_run.create_rng("club"), library, {}, definition).to_dict()
		club_run.set_environment(club_environment)
		var module = EventModuleScript.new()
		module.setup(event_definition, library)
		if str(club_environment.get("kind", "")) != "club" or not (club_environment.get("event_ids", []) as Array).has(event_id) or not module.can_trigger(club_run, club_run.current_environment):
			failures.append("%s was not attached and selectable on its club scenario layer." % event_id)

		var casino_run = RunStateScript.new()
		casino_run.start_new("PUNCHLINE-SCOPE-CASINO-%s" % scenario_id)
		var casino_environment := EnvironmentInstanceScript.from_archetype_layer(archetype, "casino", 2, casino_run.create_rng("casino"), library, {}, definition).to_dict()
		if (casino_environment.get("event_ids", []) as Array).has(event_id):
			failures.append("%s leaked from its club scenario into the casino layer." % event_id)
		var forced_event_ids: Array = (casino_environment.get("event_ids", []) as Array).duplicate()
		if not forced_event_ids.has(event_id):
			forced_event_ids.append(event_id)
		casino_environment["event_ids"] = forced_event_ids
		casino_run.set_environment(casino_environment)
		if str(casino_environment.get("kind", "")) != "casino" or module.can_trigger(casino_run, casino_run.current_environment):
			failures.append("%s did not reject an explicitly injected casino-layer trigger." % event_id)

	if failures.is_empty():
		print("PUNCHLINE_EVENT_SCOPE PASS club_selectable=2 casino_rejected=2")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
