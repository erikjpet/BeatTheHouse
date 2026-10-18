extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")


func _init() -> void:
	var failures: Array = []
	var library := ContentLibraryScript.new()
	library.load()
	var run_state := RunStateScript.new()
	run_state.start_new("ROURKE-NOTICED-OBJECT-DEBUG")
	run_state.bankroll = 170
	var node := {
		"id": "grand_casino",
		"archetype_id": "grand_casino",
		"kind": "boss",
		"tier": 3,
		"state": "revealed",
		"seen": true,
		"environment": {},
	}
	run_state.set_world_map({
		"version": 3,
		"seed_text": "ROURKE-NOTICED-OBJECT-DEBUG",
		"start_node_id": "grand_casino",
		"current_node_id": "grand_casino",
		"nodes": [node],
		"edges": [],
		"visited_path": ["grand_casino"],
	})
	run_state.configure_town_world(run_state.world_map)
	var environment := EnvironmentInstanceScript.from_archetype(
		library.environment_archetype("grand_casino"),
		3,
		run_state.create_rng("rourke_noticed_grand"),
		library
	).to_dict()
	environment["id"] = "grand_casino"
	environment["world_node_id"] = "grand_casino"
	run_state.apply_town_generation_modifiers(environment, run_state.create_rng("rourke_noticed_town"))
	environment["layout"] = EnvironmentInstanceScript.ensure_generated_layout(environment, library)
	run_state.current_environment = environment
	var before_layout: Dictionary = run_state.current_environment.get("layout", {})
	var before_rects: Dictionary = before_layout.get("object_rects", {})
	_expect(before_rects.has("event:chain06_rourke_noticed"), "Rourke's Noticed beat did not begin with an authenticated room object.", failures)
	var module := EventModuleScript.new()
	module.setup(library.event("chain06_rourke_noticed"), library)
	var result := module.resolve(run_state, run_state.current_environment, "let_the_check_pass")
	_expect(bool(result.get("ok", false)), "Rourke's Noticed beat could not resolve.", failures)
	var after_layout: Dictionary = run_state.current_environment.get("layout", {})
	var after_rects: Dictionary = after_layout.get("object_rects", {})
	_expect(not after_rects.is_empty(), "Rourke's Noticed handoff cleared every Grand Casino object.", failures)
	_expect(after_rects.has("event:chain06_rourke_named"), "Rourke's Named beat did not receive its wall placement.", failures)
	for object_id_value in before_rects.keys():
		var object_id := str(object_id_value)
		if object_id != "event:chain06_rourke_noticed":
			_expect(after_rects.has(object_id), "Rourke's Noticed handoff removed unrelated room object %s." % object_id, failures)
	var placement_errors: Array = after_layout.get("placement_errors", [])
	_expect(placement_errors.is_empty(), "Rourke's Noticed handoff produced placement errors: %s" % JSON.stringify(placement_errors), failures)
	var manifest_errors := EnvironmentInstanceScript.object_manifest_errors(run_state.current_environment)
	_expect(manifest_errors.is_empty(), "Rourke's Noticed handoff left a stale object manifest: %s" % JSON.stringify(manifest_errors), failures)
	_expect(str(run_state.current_environment.get("character_chain_ambient_line", "")).contains("check your face"), "Rourke's staff-register ambience was not retained.", failures)
	if failures.is_empty():
		print("Rourke Noticed environment object check passed.")
		quit(0)
		return
	for failure in failures:
		push_error(str(failure))
	quit(1)


func _expect(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		failures.append(message)
