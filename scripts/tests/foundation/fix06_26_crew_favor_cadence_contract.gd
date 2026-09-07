extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array = []
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	var definition := library.event("crew_favor_delivery")
	var speaker: Dictionary = definition.get("speaker", {}) if typeof(definition.get("speaker", {})) == TYPE_DICTIONARY else {}
	var cadence: Dictionary = definition.get("cadence", {}) if typeof(definition.get("cadence", {})) == TYPE_DICTIONARY else {}
	if definition.is_empty() or bool(speaker.get("environment_actor", true)):
		failures.append("Crew favor is not authored as a remote call eligible outside staffed rooms.")
	if not bool(cadence.get("bypass_budget", false)):
		failures.append("Crew favor does not bypass the ordinary quiet-visit event budget.")
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("FIX06-26-CREW-FAVOR-CADENCE")
	run_state.current_environment = {
		"id": "home_fixture", "archetype_id": "house", "world_node_id": "house",
		"kind": "home", "tier": 1, "turns": 2, "resolved_event_ids": [],
	}
	run_state.narrative_flags["crew_favor_pending"] = true
	var context := {"trigger": "action", "type": "action", "source": "game_action", "turns": 2}
	var shortlisted := false
	for candidate_value in library.action_trigger_event_candidates_for_context_readonly("game_action", context, run_state.current_environment):
		if typeof(candidate_value) == TYPE_DICTIONARY and str((candidate_value as Dictionary).get("id", "")) == "crew_favor_delivery":
			shortlisted = true
			break
	var module: EventModule = EventModuleScript.new()
	module.setup(definition, library)
	if not shortlisted or not module.can_trigger(run_state, run_state.current_environment, context):
		failures.append("Crew favor is absent from the shipped home/action candidate path.")
	if not run_state.event_cadence_allows_world_event("crew_favor_delivery", "random", "game_action", definition):
		failures.append("Crew favor is rejected by the shipped cadence gate after its debt becomes due.")
	if failures.is_empty():
		print("FIX06_26_CREW_FAVOR_CADENCE PASS remote_call=true candidate=true cadence=true")
		quit(0)
		return
	for failure in failures:
		push_error(str(failure))
	quit(1)
