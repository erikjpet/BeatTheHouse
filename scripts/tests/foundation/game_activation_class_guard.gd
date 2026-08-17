extends RefCounted

# Opening a game is navigation. Every production activation presentation must
# be observational; persistent changes belong to a resolved player action.

const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const SEED_COUNT := 10
const ACTIVATION_METHODS := ["enter", "actions", "surface_state", "coach_state"]


class MutatingEntryFixture:
	extends GameModule

	func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
		run_state.narrative_flags["game_activation_fixture_seen"] = true
		return super.enter(run_state, environment)


static func check(library: ContentLibrary, failures: Array) -> void:
	var covered_game_ids := {}
	var checked_contexts := {}
	_check_generated_environment_sweep(library, covered_game_ids, checked_contexts, failures)
	_check_catalog_coverage(library, covered_game_ids, failures)
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
	var pending_checks: Array = []
	for game_id_value in _string_array(environment.get("game_ids", [])):
		var game_id := str(game_id_value)
		covered_game_ids[game_id] = true
		var game := _load_game(library, game_id, failures)
		if game == null:
			continue
		# Initial room rendering establishes each game's environment-facing
		# presentation before focus/click snapshots are compared by M1.6.
		_settle_room_presentation(game, source_run)
		var context_key := "%s|%s|%s|%s" % [game_id, archetype_id, layer_id, scenario_id]
		if checked_contexts.has(context_key):
			continue
		checked_contexts[context_key] = true
		pending_checks.append({"game_id": game_id, "game": game})
	var settled_snapshot := source_run.to_dict()
	for check_value in pending_checks:
		var check := check_value as Dictionary
		var game_id := str(check.get("game_id", ""))
		var game := check.get("game") as GameModule
		var violation := _activation_violation(game, source_run)
		if not violation.is_empty():
			failures.append("Game activation mutated serialized RunState for %s in %s/%s/%s: %s" % [game_id, archetype_id, layer_id, scenario_id, violation])
			source_run.from_dict(settled_snapshot)


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
	var clean_game := GameModule.new()
	clean_game.setup({"id": "game_activation_fixture", "display_name": "Activation Fixture", "legal_actions": [], "cheat_actions": []})
	var clean_violation := _activation_violation(clean_game, clean_run)
	if not clean_violation.is_empty():
		failures.append("Clean game activation fixture unexpectedly mutated RunState: %s" % clean_violation)

	var broken_run := RunStateScript.new()
	broken_run.start_new("GAME-ACTIVATION-BROKEN-FIXTURE")
	broken_run.set_environment(environment)
	var broken_game := MutatingEntryFixture.new()
	broken_game.setup({"id": "game_activation_fixture", "display_name": "Activation Fixture", "legal_actions": [], "cheat_actions": []})
	var defect_violation := _activation_violation(broken_game, broken_run)
	if defect_violation.is_empty() or defect_violation.find("narrative_flags.game_activation_fixture_seen") == -1:
		failures.append("Game activation class guard did not detect the reintroduced mutate-on-enter fixture.")


static func _activation_violation(game: GameModule, run_state: RunState) -> String:
	for method in ACTIVATION_METHODS:
		var before := run_state.to_dict()
		var before_text := JSON.stringify(before)
		match method:
			"enter":
				game.enter(run_state, run_state.current_environment)
			"actions":
				game.actions(run_state, run_state.current_environment)
			"surface_state":
				game.surface_state(run_state, run_state.current_environment, {})
			"coach_state":
				game.coach_state(run_state, run_state.current_environment, {})
		var after := run_state.to_dict()
		if before_text != JSON.stringify(after):
			var paths: Array = []
			_collect_changed_paths(before, after, "", paths)
			return "%s changed %s" % [method, ", ".join(paths)]
	return ""


static func _settle_room_presentation(game: GameModule, run_state: RunState) -> void:
	# The room snapshot exists before M1.6 begins observing focus and activation.
	# Match that production boundary: runtime/object/hook previews may establish
	# their generated presentation cache, but the later info-card and game-open
	# path must remain byte-stable.
	game.environment_runtime_state(run_state, run_state.current_environment)
	game.environment_object_state(run_state, run_state.current_environment)
	game.environment_interactable_objects(run_state, run_state.current_environment)


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
