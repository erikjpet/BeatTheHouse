extends SceneTree

# Discovers deterministic catalog assignments for candidate seeds in one process.
# It deliberately uses prevalidated travel to visit every map node. The output is
# discovery evidence only and cannot qualify a natural owner-playtest route.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

var seed_values: Array = []
var output_path := ""
var source_commit := ""
var source_tree := ""
var build_identity := ""


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seeds="):
			seed_values = _clean_strings(argument.trim_prefix("--seeds=").split(",", false))
		elif argument.begins_with("--out="):
			output_path = argument.trim_prefix("--out=").strip_edges()
		elif argument.begins_with("--source-commit="):
			source_commit = argument.trim_prefix("--source-commit=").strip_edges()
		elif argument.begins_with("--source-tree="):
			source_tree = argument.trim_prefix("--source-tree=").strip_edges()
		elif argument.begins_with("--build-identity="):
			build_identity = argument.trim_prefix("--build-identity=").strip_edges()
	if not _is_lower_hex_identity(source_commit) or not _is_lower_hex_identity(source_tree) or build_identity.is_empty():
		push_error("Catalog discovery requires --source-commit, --source-tree, and --build-identity provenance.")
		quit(2)
		return
	if seed_values.is_empty():
		for index in range(1, 13):
			seed_values.append("PLAYTEST-CATALOG-%02d" % index)
	call_deferred("_run")


func _run() -> void:
	var library := ContentLibraryScript.new()
	library.load()
	if not library.validation_errors.is_empty():
		for error_value in library.validation_errors:
			push_error(str(error_value))
		quit(1)
		return
	var reports: Array = []
	for seed_value in seed_values:
		reports.append(_audit_seed(library, str(seed_value)))
	var all_scenario_ids := _scenario_catalog_ids(library)
	var selection := _greedy_scenario_selection(reports, all_scenario_ids)
	var tool_path := ProjectSettings.globalize_path("res://tools/playtest06_2_seed_catalog_probe.gd")
	var report := {
		"schema_version": 2,
		"source_commit": source_commit,
		"source_tree": source_tree,
		"build_identity": build_identity,
		"tool_source_sha256": FileAccess.get_sha256(tool_path),
		"godot_version": Engine.get_version_info(),
		"authority": "DIAGNOSTIC_PREVALIDATED_TRAVEL",
		"owner_playtest_eligible": false,
		"warning": "Assignments prove deterministic catalog generation only. They do not prove natural travel, route prerequisites, branch outcomes, or player reachability.",
		"seed_reports": reports,
		"greedy_scenario_seed_ids": selection.get("seed_ids", []),
		"covered_scenario_ids": selection.get("covered", []),
		"missing_scenario_ids": selection.get("missing", []),
		"catalog_counts": {
			"archetypes": library.environment_archetypes.size(),
			"games": library.games.size(),
			"scenarios": all_scenario_ids.size(),
		},
	}
	var encoded := JSON.stringify(report, "\t")
	print(encoded)
	if not output_path.is_empty() and not _write_output(output_path, encoded):
		quit(1)
		return
	quit(0)


func _audit_seed(library: Variant, seed_value: String) -> Dictionary:
	var run_state := RunStateScript.new()
	run_state.start_new(seed_value)
	var generator := RunGeneratorScript.new(library)
	generator.next_environment(run_state)
	var node_ids: Array = []
	for node_value in run_state.world_map.get("nodes", []):
		if typeof(node_value) == TYPE_DICTIONARY:
			var node_id := str((node_value as Dictionary).get("id", "")).strip_edges()
			if not node_id.is_empty():
				node_ids.append(node_id)
	node_ids.sort()
	for node_id_value in node_ids:
		var node_id := str(node_id_value)
		if node_id == run_state.current_world_node_id():
			continue
		generator.next_environment(run_state, node_id, true)
	var assignments: Array = []
	var archetype_ids: Array = []
	var game_ids: Array = []
	var pusher_machine_ids: Array = []
	var scenario_ids: Array = []
	for node_value in run_state.world_map.get("nodes", []):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		var archetype_id := str(node.get("archetype_id", node_id))
		var environment: Dictionary = node.get("environment", {}) if typeof(node.get("environment", {})) == TYPE_DICTIONARY else {}
		var node_games := _clean_strings(environment.get("game_ids", []))
		var node_machines := _pusher_variations(environment)
		var scenario := run_state.scenario_for_node(node_id)
		var scenario_id := str(scenario.get("id", "")).strip_edges()
		_append_unique(archetype_ids, archetype_id)
		for game_id in node_games:
			_append_unique(game_ids, str(game_id))
		for machine_id in node_machines:
			_append_unique(pusher_machine_ids, str(machine_id))
		_append_unique(scenario_ids, scenario_id)
		assignments.append({
			"node_id": node_id,
			"archetype_id": archetype_id,
			"game_ids": node_games,
			"pusher_machine_ids": node_machines,
			"scenario_id": scenario_id,
		})
	archetype_ids.sort()
	game_ids.sort()
	pusher_machine_ids.sort()
	scenario_ids.sort()
	assignments.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("node_id", "")) < str(b.get("node_id", "")))
	return {
		"seed": seed_value,
		"archetype_ids": archetype_ids,
		"game_ids": game_ids,
		"pusher_machine_ids": pusher_machine_ids,
		"scenario_ids": scenario_ids,
		"assignments": assignments,
	}


func _pusher_variations(environment: Dictionary) -> Array:
	var result: Array = []
	var states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	for key_value in states.keys():
		var key := str(key_value)
		if key != "coin_pusher" and not key.begins_with("coin_pusher:"):
			continue
		var state_value: Variant = states.get(key, {})
		if typeof(state_value) != TYPE_DICTIONARY:
			continue
		_append_unique(result, str((state_value as Dictionary).get("variation_id", "")))
	result.sort()
	return result


func _scenario_catalog_ids(library: Variant) -> Array:
	var result: Array = []
	for pool_value in library.environment_scenarios.values():
		if typeof(pool_value) != TYPE_ARRAY:
			continue
		for scenario_value in pool_value as Array:
			if typeof(scenario_value) == TYPE_DICTIONARY:
				_append_unique(result, str((scenario_value as Dictionary).get("id", "")))
	result.sort()
	return result


func _greedy_scenario_selection(reports: Array, catalog_ids: Array) -> Dictionary:
	var remaining: Dictionary = {}
	for scenario_id in catalog_ids:
		remaining[str(scenario_id)] = true
	var available := reports.duplicate(true)
	var selected: Array = []
	var covered: Array = []
	while not remaining.is_empty() and not available.is_empty():
		var best_index := -1
		var best_gain := 0
		for index in range(available.size()):
			var candidate: Dictionary = available[index]
			var gain := 0
			for scenario_id in candidate.get("scenario_ids", []):
				if remaining.has(str(scenario_id)):
					gain += 1
			if gain > best_gain:
				best_gain = gain
				best_index = index
		if best_index < 0:
			break
		var best: Dictionary = available.pop_at(best_index)
		selected.append(str(best.get("seed", "")))
		for scenario_id in best.get("scenario_ids", []):
			var clean_id := str(scenario_id)
			if remaining.has(clean_id):
				remaining.erase(clean_id)
				covered.append(clean_id)
	covered.sort()
	var missing: Array = remaining.keys()
	missing.sort()
	return {"seed_ids": selected, "covered": covered, "missing": missing}


func _clean_strings(values: Variant) -> Array:
	var result: Array = []
	if typeof(values) not in [TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY]:
		return result
	for value in values:
		_append_unique(result, str(value).strip_edges())
	return result


func _append_unique(values: Array, value: String) -> void:
	var clean := value.strip_edges()
	if not clean.is_empty() and not values.has(clean):
		values.append(clean)


func _is_lower_hex_identity(value: String) -> bool:
	if value.length() != 40:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return false
	return true


func _write_output(path: String, encoded: String) -> bool:
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write playtest seed catalog report: %s" % path)
		return false
	file.store_string(encoded)
	file.close()
	return true
