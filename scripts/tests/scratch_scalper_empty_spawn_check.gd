extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const ScratchTicketsScript := preload("res://scripts/games/scratch_tickets.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load(false)
	var game: GameModule = ScratchTicketsScript.new()
	game.setup(library.game("scratch_tickets"), library)
	var found_empty := false
	for sample in range(256):
		var run_state: RunState = RunStateScript.new()
		run_state.start_new("SCRATCH-EMPTY-SCALPER-%d" % sample)
		var environment := {
			"id": "scratch_empty_scalper_%d" % sample,
			"archetype_id": "gas_station_casino",
			"kind": "casino",
			"generated_day": sample,
			"entered_game_clock_minutes": run_state.game_clock_minutes,
			"game_states": {},
		}
		var rng: RngStream = RngStreamScript.new()
		rng.configure(sample + 1)
		var machine: Dictionary = game.generate_environment_state(run_state, environment, rng)
		if int(game.call("_stock_total", machine)) > 0:
			continue
		found_empty = true
		if not bool(machine.get("scalper_present", false)) or str(machine.get("scalper_visit_token", "")).is_empty():
			_fail("An initially empty scratch machine did not generate with its scalper.")
			return
		# Simulate an older/stale save that already carries the current visit token
		# but lacks the new empty-machine invariant. Spawning its room must repair it.
		machine["scalper_present"] = false
		machine["scalper_knows_schedule"] = false
		environment["game_states"] = {"scratch_tickets": machine}
		run_state.current_environment = environment
		var scalper_found := false
		for hook_value in game.environment_interactable_objects(run_state, environment):
			if typeof(hook_value) == TYPE_DICTIONARY and str((hook_value as Dictionary).get("id", "")) == "scratch_ticket_scalper":
				scalper_found = true
				break
		if not scalper_found:
			_fail("The guaranteed empty-machine scalper was not exposed in the spawned environment.")
			return
		break
	if not found_empty:
		_fail("Could not generate an empty scratch-machine fixture.")
		return
	print("scratch_scalper_empty_spawn_check: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
