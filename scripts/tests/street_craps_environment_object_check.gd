extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const CrapsGameScript := preload("res://scripts/games/craps.gd")
const EnvironmentInteractionViewModelScript := preload("res://scripts/ui/environment_interaction_view_model.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	_check(library.validation_errors.is_empty(), "Content must load before the Street Craps room-object check.")
	var game: GameModule = CrapsGameScript.new()
	game.setup(library.game("craps"), library)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("STREET-CRAPS-ENVIRONMENT-OBJECT")
	run_state.bankroll = 100
	var environment := {
		"id": "back_alley_street_craps_fixture",
		"archetype_id": "back_alley",
		"world_node_id": "back_alley",
		"kind": "shop",
		"game_ids": ["craps"],
		"economic_profile": {"stake_floor": 2, "stake_ceiling": 20},
		"scenario_id": "back_alley_street_craps",
		"scenario_game_modifiers": {"game_hook": "street_craps", "table_tone": "street"},
		"scenario_hook_flags": {"craps_onramp": true},
		"game_states": {},
	}
	var table := game.generate_environment_state(run_state, environment, run_state.create_rng("street_craps_room_object"))
	environment["game_states"] = {"craps": table}
	run_state.current_environment = environment
	var object_state := game.environment_object_state(run_state, environment)
	_check(str(object_state.get("environment_prop", "")) == "street_craps_circle", "Street Craps must publish its dedicated floor-object identity.")
	_check(str(object_state.get("display_name", "")) == "Street Craps", "The alley object must be labeled Street Craps instead of generic casino Craps.")

	var records := EnvironmentInteractionViewModelScript.interactable_object_view_list(run_state, library, {
		"selection": {},
		"layout": {},
		"game_sources": [{
			"id": "craps",
			"definition": library.game("craps"),
			"runtime_state": {},
			"object_state": object_state,
			"fixture_object_states": {},
		}],
	})
	var street_record := _record_by_id(records, "game:craps")
	_check(str(street_record.get("prop", "")) == "street_craps_circle", "The interaction projection replaced the dedicated street object with the casino table prop.")
	_check(str(street_record.get("label", "")) == "Street Craps", "The interaction projection lost the Street Craps object label.")

	var canvas: PixelSceneCanvas = PixelSceneCanvasScript.new()
	canvas.size = Vector2(900.0, 430.0)
	root.add_child(canvas)
	await process_frame
	canvas.render_environment_snapshot({
		"id": environment.id,
		"archetype_id": environment.archetype_id,
		"scenario_id": environment.scenario_id,
		"interactable_objects": records,
	})
	await process_frame
	var rendered := _record_by_id(canvas.current_view_snapshot().get("objects", []), "game:craps")
	_check(str(rendered.get("prop", "")) == "street_craps_circle", "The production room renderer routed Street Craps back to the casino table.")
	canvas.queue_free()
	await process_frame
	_finish()


func _record_by_id(records: Array, object_id: String) -> Dictionary:
	for record_value in records:
		if typeof(record_value) == TYPE_DICTIONARY and str((record_value as Dictionary).get("object_id", (record_value as Dictionary).get("id", ""))) == object_id:
			return record_value as Dictionary
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("STREET_CRAPS_ENVIRONMENT_OBJECT_CHECK PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
