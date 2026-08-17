class_name CrewIgnoredGoldenProbe
extends RefCounted

# Full serialized checkpoints for runs that never take the Crew loan or gain
# Crew trust. The accepted-main fixture includes authored scenario anchors, so
# no fields are broadly stripped: only a real byte-for-byte match passes.

const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const SEEDS := ["CREW-IGNORED-GOLDEN-A", "CREW-IGNORED-GOLDEN-B"]


static func capture(library: ContentLibrary) -> Dictionary:
	var runs: Array = []
	for seed_value in SEEDS:
		var run_state := RunStateScript.new()
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
		var restored := RunStateScript.new()
		restored.from_dict(run_state.to_dict())
		checkpoints.append(_checkpoint("save_load_round_trip", restored))
		runs.append({"seed": str(seed_value), "checkpoints": checkpoints})
	return {"schema_version": 1, "runs": runs}


static func _checkpoint(label: String, run_state: RunState) -> Dictionary:
	var run_json := JSON.stringify(run_state.to_dict())
	var environment_json := JSON.stringify(run_state.current_environment)
	var world_environment_json := JSON.stringify(_world_environments(run_state.world_map))
	return {
		"label": label,
		"run_state_bytes": run_json.to_utf8_buffer().size(),
		"run_state_sha256": run_json.sha256_text(),
		"current_environment_bytes": environment_json.to_utf8_buffer().size(),
		"current_environment_sha256": environment_json.sha256_text(),
		"world_environments_bytes": world_environment_json.to_utf8_buffer().size(),
		"world_environments_sha256": world_environment_json.sha256_text(),
	}


static func _world_environments(world_map: Dictionary) -> Array:
	var result: Array = []
	for node_value in world_map.get("nodes", []):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		result.append({
			"id": str(node.get("id", "")),
			"environment": (node.get("environment", {}) as Dictionary).duplicate(true) if typeof(node.get("environment", {})) == TYPE_DICTIONARY else {},
		})
	return result


static func _set_world(run_state: RunState) -> void:
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
