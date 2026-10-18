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
	run_state.start_new("DAVE-OBJECT-DEBUG-gas_station_casino")
	var node := {
		"id": "gas_station_casino",
		"archetype_id": "gas_station_casino",
		"kind": "shop",
		"tier": 1,
		"state": "revealed",
		"seen": true,
		"environment": {},
	}
	run_state.set_world_map({
		"version": 3,
		"seed_text": "DAVE-OBJECT-DEBUG-gas_station_casino",
		"start_node_id": "gas_station_casino",
		"current_node_id": "gas_station_casino",
		"nodes": [node],
		"edges": [],
		"visited_path": ["gas_station_casino"],
	})
	run_state.configure_town_world(run_state.world_map)
	run_state.town_state.living_world.itinerary_schedules["dave_bus_regular"] = [{
		"node_id": "gas_station_casino",
		"start_action": 0,
		"end_action": 999,
	}]
	var environment := EnvironmentInstanceScript.from_archetype(
		library.environment_archetype("gas_station_casino"),
		1,
		run_state.create_rng("dave_gas_station_casino"),
		library
	).to_dict()
	environment["id"] = "gas_station_casino"
	environment["world_node_id"] = "gas_station_casino"
	run_state.apply_town_generation_modifiers(environment, run_state.create_rng("dave_town_context"))
	environment["layout"] = EnvironmentInstanceScript.ensure_generated_layout(environment, library)
	run_state.current_environment = environment
	var before_rects: Dictionary = (run_state.current_environment.get("layout", {}) as Dictionary).get("object_rects", {})
	_expect(before_rects.has("event:chain06_dave_same_bus"), "Dave's Last Stop did not begin with an authenticated room object.", failures)
	var module := EventModuleScript.new()
	module.setup(library.event("chain06_dave_same_bus"), library)
	var result := module.resolve(run_state, run_state.current_environment, "sit_in_the_silence")
	_expect(bool(result.get("ok", false)), "Dave's Last Stop could not resolve.", failures)
	var after_layout: Dictionary = run_state.current_environment.get("layout", {})
	var after_rects: Dictionary = after_layout.get("object_rects", {})
	_expect(not after_rects.is_empty(), "Dave's Last Stop handoff cleared every object from the environment.", failures)
	_expect(after_rects.has("event:chain06_dave_last_stop"), "Dave's follow-up beat did not receive a valid room placement.", failures)
	for object_id_value in before_rects.keys():
		var object_id := str(object_id_value)
		if object_id != "event:chain06_dave_same_bus":
			_expect(after_rects.has(object_id), "Dave's Last Stop handoff removed unrelated room object %s." % object_id, failures)
	var placement_errors: Array = after_layout.get("placement_errors", [])
	_expect(placement_errors.is_empty(), "Dave's Last Stop handoff produced placement errors: %s" % JSON.stringify(placement_errors), failures)
	if failures.is_empty():
		print("Dave Last Stop environment object check passed.")
		quit(0)
		return
	for failure in failures:
		push_error(str(failure))
	quit(1)


func _expect(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		failures.append(message)
