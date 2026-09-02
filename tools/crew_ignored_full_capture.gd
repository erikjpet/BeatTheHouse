extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
var out_path := "res://.tmp/crew_ignored_full_capture.json"


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=").strip_edges()
	call_deferred("_run")


func _run() -> void:
	var profile_root := "res://.tmp/crew_ignored_full_capture_profile"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profile_root))
	OS.set_environment("BTH_DISTRIBUTION_BUILD", "1")
	OS.set_environment("BTH_DISTRIBUTION_DATA_ROOT", "%s/distribution" % profile_root)
	OS.set_environment("BTH_USER_SETTINGS_PATH", "%s/settings.json" % profile_root)
	OS.set_environment("BTH_PROFILE_INVENTORY_PATH", "%s/profile_inventory.json" % profile_root)
	OS.set_environment("BTH_META_COLLECTION_PATH", "%s/meta_collection.json" % profile_root)
	var app := MainScene.instantiate() as Control
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "crew_ignored_full_capture")
	root.add_child(app)
	for _index in range(6):
		await process_frame
	var library := app.get("library") as ContentLibrary
	var runs: Array = []
	for seed_value in ["CREW-IGNORED-GOLDEN-A", "CREW-IGNORED-GOLDEN-B"]:
		var run_state := RunState.new()
		run_state.start_new(str(seed_value))
		_set_world(run_state)
		var generator := RunGeneratorScript.new(library)
		generator.next_environment(run_state, "bar", true)
		var checkpoints: Array = [_checkpoint("initial_bar", run_state)]
		run_state.advance_environment_turns(1)
		checkpoints.append(_checkpoint("bar_action_boundary", run_state))
		generator.next_environment(run_state, "gas_station_casino", true)
		checkpoints.append(_checkpoint("ordinary_travel", run_state))
		generator.next_environment(run_state, "bar", true)
		checkpoints.append(_checkpoint("bar_revisit", run_state))
		var restored := RunState.new()
		restored.from_dict(run_state.to_dict())
		checkpoints.append(_checkpoint("save_load_round_trip", restored))
		runs.append({"seed": str(seed_value), "checkpoints": checkpoints})
	var absolute_path := ProjectSettings.globalize_path(out_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % absolute_path)
		quit(1)
		return
	file.store_string(JSON.stringify({"schema_version": 1, "runs": runs}, "\t") + "\n")
	file.close()
	print("CREW_IGNORED_FULL_CAPTURE_PASS out=%s" % absolute_path)
	quit(0)


func _checkpoint(label: String, run_state: RunState) -> Dictionary:
	return {
		"label": label,
		"run_state": run_state.to_dict(),
		"current_environment": run_state.current_environment.duplicate(true),
		"world_environments": _world_environments(run_state.world_map),
	}


func _world_environments(world_map: Dictionary) -> Array:
	var result: Array = []
	for node_value in world_map.get("nodes", []):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node := node_value as Dictionary
		result.append({
			"id": str(node.get("id", "")),
			"environment": (node.get("environment", {}) as Dictionary).duplicate(true) if typeof(node.get("environment", {})) == TYPE_DICTIONARY else {},
		})
	return result


func _set_world(run_state: RunState) -> void:
	run_state.set_world_map({
		"version": 3,
		"seed_text": run_state.seed_text,
		"start_node_id": "bar",
		"current_node_id": "bar",
		"nodes": [
			{"id": "bar", "archetype_id": "bar", "display_name": "Bar", "kind": "casino", "tier": 1, "state": "revealed", "seen": true, "environment": {}},
			{"id": "gas_station_casino", "archetype_id": "gas_station_casino", "display_name": "Gas Station Casino", "kind": "casino", "tier": 1, "state": "revealed", "seen": true, "environment": {}},
			{"id": "motel", "archetype_id": "motel", "display_name": "Motel", "kind": "shop", "tier": 1, "state": "revealed", "seen": true, "environment": {}},
		],
		"edges": [{"from": "bar", "to": "gas_station_casino"}, {"from": "gas_station_casino", "to": "motel"}, {"from": "motel", "to": "bar"}],
		"visited_path": ["bar"],
	})
