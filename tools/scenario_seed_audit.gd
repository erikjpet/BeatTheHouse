extends SceneTree

# Prints deterministic first-visit scenario assignments for one complete map.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

var seed_text := "SCENARIO-AUDIT"
var output_path := ""


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			seed_text = argument.trim_prefix("--seed=").strip_edges()
		elif argument.begins_with("--out="):
			output_path = argument.trim_prefix("--out=").strip_edges()
	call_deferred("_run")


func _run() -> void:
	var library := ContentLibraryScript.new()
	library.load()
	if not library.validation_errors.is_empty():
		for error_value in library.validation_errors:
			push_error(str(error_value))
		quit(1)
		return
	var run_state := RunStateScript.new()
	run_state.start_new(seed_text)
	var generator := RunGeneratorScript.new(library)
	generator.next_environment(run_state)
	var node_ids: Array = []
	for node_value in run_state.world_map.get("nodes", []):
		if typeof(node_value) == TYPE_DICTIONARY:
			node_ids.append(str((node_value as Dictionary).get("id", "")))
	node_ids.sort()
	for node_id_value in node_ids:
		var node_id := str(node_id_value)
		if node_id.is_empty() or node_id == run_state.current_world_node_id():
			continue
		generator.next_environment(run_state, node_id, true)
	var assignments: Array = []
	for node_id_value in node_ids:
		var node_id := str(node_id_value)
		var scenario := run_state.scenario_for_node(node_id)
		assignments.append({
			"node_id": node_id,
			"scenario_id": str(scenario.get("id", "")),
			"display_name": str(scenario.get("display_name", "")),
			"phase_index": int(scenario.get("phase_index", 0)),
		})
	var report := {"seed": seed_text, "assignments": assignments}
	var encoded := JSON.stringify(report, "\t")
	print(encoded)
	if not output_path.is_empty():
		var absolute_path := ProjectSettings.globalize_path(output_path)
		DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
		var file := FileAccess.open(absolute_path, FileAccess.WRITE)
		if file == null:
			push_error("Could not write scenario audit: %s" % output_path)
			quit(1)
			return
		file.store_string(encoded)
		file.close()
	quit(0)
