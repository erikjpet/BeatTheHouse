extends RefCounted

# Opening a game is navigation. Every production activation presentation must
# be observational; persistent changes belong to a resolved player action.

const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const SEED_COUNT := 10
const ACTIVATION_METHODS := [
	"environment_runtime_state",
	"environment_object_state",
	"environment_interactable_objects",
	"enter",
	"actions",
	"surface_state",
	"coach_state",
]


class MutatingActivationFixture:
	extends GameModule

	var mutating_method := ""

	func _mutate(run_state: RunState, method: String) -> void:
		if mutating_method == method:
			run_state.narrative_flags["game_activation_fixture_%s" % method] = true

	func environment_runtime_state(run_state: RunState, environment: Dictionary) -> Dictionary:
		_mutate(run_state, "environment_runtime_state")
		return super.environment_runtime_state(run_state, environment)

	func environment_object_state(run_state: RunState, environment: Dictionary) -> Dictionary:
		_mutate(run_state, "environment_object_state")
		return super.environment_object_state(run_state, environment)

	func environment_interactable_objects(run_state: RunState, environment: Dictionary) -> Array:
		_mutate(run_state, "environment_interactable_objects")
		return super.environment_interactable_objects(run_state, environment)

	func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
		_mutate(run_state, "enter")
		return super.enter(run_state, environment)

	func actions(run_state: RunState, environment: Dictionary) -> Dictionary:
		_mutate(run_state, "actions")
		return super.actions(run_state, environment)

	func surface_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
		_mutate(run_state, "surface_state")
		return super.surface_state(run_state, environment, ui_state)

	func coach_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
		_mutate(run_state, "coach_state")
		return super.coach_state(run_state, environment, ui_state)


static func check(library: ContentLibrary, failures: Array) -> void:
	var covered_game_ids := {}
	var checked_contexts := {}
	_check_generated_environment_sweep(library, covered_game_ids, checked_contexts, failures)
	_check_catalog_coverage(library, covered_game_ids, failures)
	_check_staff_rollover_presentation(library, failures)
	_check_reintroduced_defect_fixture(failures)


static func _check_generated_environment_sweep(library: ContentLibrary, covered_game_ids: Dictionary, checked_contexts: Dictionary, failures: Array) -> void:
	for seed_index in range(SEED_COUNT):
		for archetype_value in library.environment_archetypes:
			if typeof(archetype_value) != TYPE_DICTIONARY:
				continue
			var archetype := archetype_value as Dictionary
			var archetype_id := str(archetype.get("id", "")).strip_edges()
			var scenarios: Array = [{}]
			if seed_index == 0:
				scenarios.append_array(library.scenarios_for_archetype(archetype_id))
			for scenario_value in scenarios:
				var scenario := _dict(scenario_value)
				var scenario_id := str(scenario.get("id", "baseline"))
				var run_state := RunStateScript.new()
				run_state.start_new("GAME-ACTIVATION-%02d-%s-%s" % [seed_index, archetype_id, scenario_id])
				var environment := EnvironmentInstanceScript.from_archetype(
					archetype,
					int(archetype.get("tier", 1)),
					run_state.create_rng("generated_environment"),
					library,
					{},
					scenario
				).to_dict()
				var generator := RunGeneratorScript.new(library)
				environment["game_states"] = generator._generated_game_states(
					run_state,
					environment,
					run_state.create_rng("generated_game_states")
				)
				run_state.set_environment(environment)
				var restored_run := _json_round_trip_run_state(run_state, "%s/%s/seed-%02d" % [archetype_id, scenario_id, seed_index], failures)
				if restored_run == null:
					continue
				run_state = restored_run
				_check_environment(library, run_state, scenario_id, covered_game_ids, checked_contexts, failures)
				if run_state.is_layered_environment():
					_enter_and_check_remaining_layers(library, run_state, scenario_id, covered_game_ids, checked_contexts, failures)


static func _enter_and_check_remaining_layers(library: ContentLibrary, run_state: RunState, scenario_id: String, covered_game_ids: Dictionary, checked_contexts: Dictionary, failures: Array) -> void:
	var remaining := _string_array(run_state.current_environment.get("layer_ids", []))
	remaining.erase(str(run_state.current_environment.get("current_layer_id", "")))
	var generator := RunGeneratorScript.new(library)
	while not remaining.is_empty():
		var entered := false
		for transition_value in _array(run_state.current_environment.get("layer_transitions", [])):
			if typeof(transition_value) != TYPE_DICTIONARY:
				continue
			var target_layer_id := str((transition_value as Dictionary).get("target_layer_id", "")).strip_edges()
			if not remaining.has(target_layer_id):
				continue
			run_state.discover_environment_layer(target_layer_id, "game_activation_class_guard")
			var result := generator.enter_environment_layer(run_state, target_layer_id, false)
			if not bool(result.get("ok", false)):
				failures.append("Game activation class guard could not enter layer %s: %s" % [target_layer_id, str(result.get("message", "unknown failure"))])
				return
			var restored_run := _json_round_trip_run_state(run_state, "%s/%s" % [scenario_id, target_layer_id], failures)
			if restored_run == null:
				return
			run_state = restored_run
			remaining.erase(target_layer_id)
			entered = true
			_check_environment(library, run_state, scenario_id, covered_game_ids, checked_contexts, failures)
			break
		if not entered:
			failures.append("Game activation class guard could not reach generated layers %s." % JSON.stringify(remaining))
			return


static func _check_environment(library: ContentLibrary, source_run: RunState, scenario_id: String, covered_game_ids: Dictionary, checked_contexts: Dictionary, failures: Array) -> void:
	var environment := source_run.current_environment
	var archetype_id := str(environment.get("archetype_id", ""))
	var layer_id := str(environment.get("current_layer_id", "base"))
	for game_id_value in _string_array(environment.get("game_ids", [])):
		var game_id := str(game_id_value)
		covered_game_ids[game_id] = true
		for state_key_value in _generated_state_keys(environment, game_id):
			var state_key := str(state_key_value)
			var context_key := "%s|%s|%s|%s|%s" % [game_id, state_key, archetype_id, layer_id, scenario_id]
			if checked_contexts.has(context_key):
				continue
			checked_contexts[context_key] = true
			var game := _load_game(library, game_id, failures)
			if game == null:
				continue
			# This is the same transient seam used by FoundationMain when a player
			# opens a non-default generated fixture. It must select presentation
			# without recording that selection in the serialized environment.
			game.set_transient_state_key_context(state_key)
			var violation := _activation_violation(game, source_run)
			game.set_transient_state_key_context("")
			if not violation.is_empty():
				failures.append("Game activation mutated serialized RunState for %s (%s) in %s/%s/%s: %s" % [game_id, state_key, archetype_id, layer_id, scenario_id, violation])


static func _check_catalog_coverage(library: ContentLibrary, covered_game_ids: Dictionary, failures: Array) -> void:
	for definition_value in library.games:
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition := definition_value as Dictionary
		var game_id := str(definition.get("id", "")).strip_edges()
		var module_path := str(definition.get("module_path", "")).strip_edges()
		if game_id.is_empty() or module_path.is_empty() or module_path.ends_with("_ui.gd") or module_path.begins_with("res://data/runtime/"):
			continue
		if not covered_game_ids.has(game_id):
			failures.append("Game activation class guard never reached production game %s in generated environments." % game_id)


static func _check_staff_rollover_presentation(library: ContentLibrary, failures: Array) -> void:
	var archetype := library.environment_archetype("grand_casino")
	if archetype.is_empty():
		failures.append("Game activation class guard could not resolve the Grand Casino rollover fixture.")
		return
	var run_state := RunStateScript.new()
	run_state.start_new("GAME-ACTIVATION-STAFF-ROLLOVER")
	var environment := EnvironmentInstanceScript.from_archetype(
		archetype,
		int(archetype.get("tier", 3)),
		run_state.create_rng("staff_rollover_environment"),
		library
	).to_dict()
	var generator := RunGeneratorScript.new(library)
	environment["game_states"] = generator._generated_game_states(
		run_state,
		environment,
		run_state.create_rng("staff_rollover_game_states")
	)
	run_state.set_environment(environment)
	run_state = _json_round_trip_run_state(run_state, "Grand Casino staff rollover fixture", failures)
	if run_state == null:
		return
	run_state.advance_game_clock_minutes(1440)
	# Keep each action-boundary proof comfortably funded; this fixture is about
	# staff persistence, not wager rejection.
	run_state.bankroll = 1000
	run_state.grand_casino_chips = 1000
	var staffing := run_state.grand_casino_staffing_snapshot()
	var rollover_day := run_state.game_day()
	if int(staffing.get("day", 0)) != rollover_day:
		failures.append("Grand Casino staffing did not advance to the real game-clock rollover day.")
	var assignments := _dict(staffing.get("assignments", {}))
	for role in ["blackjack", "baccarat", "roulette", "bartender"]:
		if not assignments.has(role):
			failures.append("Grand Casino %s staffing assignment was missing after the real rollover." % role)
			continue
		var assignment := _dict(assignments.get(role, {}))
		if int(assignment.get("day", 0)) != rollover_day:
			failures.append("Grand Casino %s staffing assignment did not retain the real rollover day." % role)

	var rollover_snapshot := run_state.to_dict()
	var rollover_text := JSON.stringify(rollover_snapshot)
	for game_id in ["blackjack", "roulette", "bar_dice", "baccarat"]:
		var game := _load_game(library, game_id, failures)
		if game == null:
			continue
		var method_run := RunStateScript.new()
		method_run.from_dict(rollover_snapshot.duplicate(true))
		game.environment_object_state(method_run, method_run.current_environment)
		if JSON.stringify(method_run.to_dict()) != rollover_text:
			var paths: Array = []
			_collect_changed_paths(rollover_snapshot, method_run.to_dict(), "", paths)
			failures.append("Grand Casino %s passive presentation mutated serialized state after a real staff rollover: %s" % [game_id, ", ".join(paths)])
			continue
		_commit_staff_action_boundary(game_id, game, method_run)
		var role_id: String = "bartender" if game_id == "bar_dice" else game_id
		var expected_assignment := _dict(assignments.get(role_id, {}))
		var game_states := _dict(method_run.current_environment.get("game_states", {}))
		var persisted_table := _dict(game_states.get(game_id, {}))
		if persisted_table.is_empty():
			failures.append("Grand Casino %s real action boundary did not retain its generated game state." % game_id)
			continue
		if int(persisted_table.get("staff_assignment_day", 0)) != rollover_day \
				or str(persisted_table.get("staff_assignment_id", "")) != str(expected_assignment.get("id", "")):
			failures.append("Grand Casino %s real action boundary did not persist rollover staff %s on day %d." % [game_id, str(expected_assignment.get("id", "")), rollover_day])


static func _commit_staff_action_boundary(game_id: String, game: GameModule, run_state: RunState) -> void:
	var environment := run_state.current_environment
	var rng := run_state.create_rng("staff_rollover_action:%s" % game_id)
	match game_id:
		"blackjack":
			game.resolve_with_context("blackjack_place_bet", 10, run_state, environment, rng, {})
		"roulette":
			game.resolve_with_context("spin_roulette", 10, run_state, environment, rng, {"roulette_bets": [game.call("_default_smoke_bet", 10)]})
		"bar_dice":
			var roll_command := game.surface_action_command("bar_dice_roll", 0, false, {}, run_state, environment)
			game.resolve_with_context("roll", 10, run_state, environment, rng, _dict(roll_command.get("ui_state", {})))
		"baccarat":
			game.resolve_with_context("deal_baccarat", 20, run_state, environment, rng, {"baccarat_bets": {"player": 20}})


static func _check_reintroduced_defect_fixture(failures: Array) -> void:
	var environment := {
		"id": "game_activation_fixture_environment",
		"archetype_id": "fixture",
		"kind": "casino",
		"tier": 1,
		"game_ids": ["game_activation_fixture"],
		"game_states": {},
	}
	var clean_run := RunStateScript.new()
	clean_run.start_new("GAME-ACTIVATION-CLEAN-FIXTURE")
	clean_run.set_environment(environment)
	clean_run = _json_round_trip_run_state(clean_run, "clean negative-control fixture", failures)
	if clean_run == null:
		return
	var clean_game := GameModule.new()
	clean_game.setup({"id": "game_activation_fixture", "display_name": "Activation Fixture", "legal_actions": [], "cheat_actions": []})
	var clean_violation := _activation_violation(clean_game, clean_run)
	if not clean_violation.is_empty():
		failures.append("Clean game activation fixture unexpectedly mutated RunState: %s" % clean_violation)

	for method in ACTIVATION_METHODS:
		var broken_run := RunStateScript.new()
		broken_run.start_new("GAME-ACTIVATION-BROKEN-%s-FIXTURE" % method)
		broken_run.set_environment(environment)
		broken_run = _json_round_trip_run_state(broken_run, "%s negative fixture" % method, failures)
		if broken_run == null:
			continue
		var broken_game := MutatingActivationFixture.new()
		broken_game.mutating_method = method
		broken_game.setup({"id": "game_activation_fixture", "display_name": "Activation Fixture", "legal_actions": [], "cheat_actions": []})
		var defect_violation := _activation_violation(broken_game, broken_run)
		var expected_path := "narrative_flags.game_activation_fixture_%s" % method
		if defect_violation.find("%s changed" % method) == -1 or defect_violation.find(expected_path) == -1:
			failures.append("Game activation class guard did not detect the reintroduced mutate-on-%s fixture: %s" % [method, defect_violation])


static func _activation_violation(game: GameModule, run_state: RunState) -> String:
	var source_snapshot := run_state.to_dict()
	for method in ACTIVATION_METHODS:
		var method_run := _run_state_from_json_snapshot(source_snapshot)
		if method_run == null:
			return "%s could not restore its pre-activation JSON fixture" % method
		var before := method_run.to_dict()
		var before_text := JSON.stringify(before)
		match method:
			"environment_runtime_state":
				game.environment_runtime_state(method_run, method_run.current_environment)
			"environment_object_state":
				game.environment_object_state(method_run, method_run.current_environment)
			"environment_interactable_objects":
				game.environment_interactable_objects(method_run, method_run.current_environment)
			"enter":
				game.enter(method_run, method_run.current_environment)
			"actions":
				game.actions(method_run, method_run.current_environment)
			"surface_state":
				game.surface_state(method_run, method_run.current_environment, {})
			"coach_state":
				game.coach_state(method_run, method_run.current_environment, {})
		var after := method_run.to_dict()
		if before_text != JSON.stringify(after):
			var paths: Array = []
			_collect_changed_paths(before, after, "", paths)
			return "%s changed %s" % [method, ", ".join(paths)]
		var restored_after_open := _run_state_from_json_snapshot(after)
		if restored_after_open == null or JSON.stringify(restored_after_open.to_dict()) != before_text:
			return "%s changed after serialize/restore" % method
	return ""


static func _generated_state_keys(environment: Dictionary, game_id: String) -> Array:
	var result: Array = []
	var game_states_value: Variant = environment.get("game_states", {})
	if typeof(game_states_value) == TYPE_DICTIONARY:
		for state_key_value in (game_states_value as Dictionary).keys():
			var state_key := str(state_key_value).strip_edges()
			if state_key == game_id or state_key.begins_with("%s:" % game_id):
				result.append(state_key)
	if not result.has(game_id):
		result.append(game_id)
	result.sort()
	return result


static func _json_round_trip_run_state(run_state: RunState, label: String, failures: Array) -> RunState:
	var snapshot := run_state.to_dict()
	var restored := _run_state_from_json_snapshot(snapshot)
	if restored == null:
		failures.append("Game activation class guard could not JSON-roundtrip %s." % label)
		return null
	# from_dict() intentionally normalizes legacy/default fields. The restored
	# representation, not the pre-codec in-memory dictionary, is the activation
	# baseline used below.
	return restored


static func _run_state_from_json_snapshot(snapshot: Dictionary) -> RunState:
	var parsed: Variant = JSON.parse_string(JSON.stringify(snapshot))
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var restored := RunStateScript.new()
	restored.from_dict(parsed as Dictionary)
	return restored


static func _load_game(library: ContentLibrary, game_id: String, failures: Array) -> GameModule:
	var definition := library.game(game_id)
	var module_path := str(definition.get("module_path", "")).strip_edges()
	if definition.is_empty() or module_path.is_empty():
		failures.append("Game activation class guard could not resolve module %s." % game_id)
		return null
	var module_script: Script = load(module_path)
	if module_script == null:
		failures.append("Game activation class guard could not load %s for %s." % [module_path, game_id])
		return null
	var instance = module_script.new()
	if not instance is GameModule:
		failures.append("Game activation class guard found a non-GameModule at %s." % module_path)
		return null
	var game := instance as GameModule
	game.setup(definition, library)
	return game


static func _collect_changed_paths(before: Variant, after: Variant, path: String, paths: Array) -> void:
	if paths.size() >= 12:
		return
	if typeof(before) != typeof(after):
		paths.append(path if not path.is_empty() else "<root>")
		return
	if typeof(before) == TYPE_DICTIONARY:
		var before_dict := before as Dictionary
		var after_dict := after as Dictionary
		var keys: Array = []
		for key_value in before_dict.keys():
			var key := str(key_value)
			if not keys.has(key):
				keys.append(key)
		for key_value in after_dict.keys():
			var key := str(key_value)
			if not keys.has(key):
				keys.append(key)
		keys.sort()
		for key_value in keys:
			var key := str(key_value)
			var child_path := key if path.is_empty() else "%s.%s" % [path, key]
			if not before_dict.has(key) or not after_dict.has(key):
				paths.append(child_path)
			elif JSON.stringify(before_dict.get(key)) != JSON.stringify(after_dict.get(key)):
				_collect_changed_paths(before_dict.get(key), after_dict.get(key), child_path, paths)
			if paths.size() >= 12:
				return
		return
	if typeof(before) == TYPE_ARRAY:
		var before_array := before as Array
		var after_array := after as Array
		if before_array.size() != after_array.size():
			paths.append("%s.size" % path)
			return
		for index in range(before_array.size()):
			if JSON.stringify(before_array[index]) != JSON.stringify(after_array[index]):
				_collect_changed_paths(before_array[index], after_array[index], "%s[%d]" % [path, index], paths)
			if paths.size() >= 12:
				return
		return
	if before != after:
		paths.append(path if not path.is_empty() else "<root>")


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	for entry_value in _array(value):
		var entry := str(entry_value).strip_edges()
		if not entry.is_empty():
			result.append(entry)
	return result
