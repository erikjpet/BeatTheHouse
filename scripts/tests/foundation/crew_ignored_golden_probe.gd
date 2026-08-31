class_name CrewIgnoredGoldenProbe
extends RefCounted

# Full serialized checkpoints for runs that never take the Crew loan or gain
# Crew trust. The accepted fixture includes authored scenario anchors and the
# persisted Coin Pusher settled state, so no fields are broadly stripped: only
# a real byte-for-byte match passes.

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


# Separate from capture() so the accepted golden schema and fixture remain
# byte-for-byte stable. This exercises every generic inactive RunState seam that
# is specified to be a pure query or an empty-registration boundary no-op.
static func world_sequence_noop_failures(library: ContentLibrary) -> Array:
	var failures: Array = []
	var run_state := RunStateScript.new()
	run_state.start_new("CREW-IGNORED-WORLD-SEQUENCE-NOOP")
	_set_world(run_state)
	RunGeneratorScript.new(library).next_environment(run_state, "bar", true)
	if not run_state.world_sequence_registrations.is_empty():
		failures.append("ignored fixture began with world-sequence registrations: %s" % JSON.stringify(run_state.world_sequence_registrations))
		return failures
	var baseline := _world_sequence_noop_snapshot(run_state)
	var token := "crew::crew::ignored_definition::ignored_instance"
	var calls := [
		{"label": "activate_current_mounts", "call": func() -> Variant: return run_state.world_sequence_activate_current_mounts()},
		{"label": "snapshot", "call": func() -> Variant: return run_state.world_sequence_snapshot(token)},
		{"label": "projection", "call": func() -> Variant: return run_state.world_sequence_projection(token)},
		{"label": "mounted_owner_lookup", "call": func() -> Variant: return run_state.world_sequence_mounted_owner_for_channel("delivery_handoff")},
		{"label": "public_instance_owner_lookup", "call": func() -> Variant: return run_state.world_sequence_owner_for_public_instance("delivery_handoff", "ignored_instance")},
		{"label": "composed_projection", "call": func() -> Variant: return run_state.world_sequence_composed_projection()},
		{"label": "execute", "call": func() -> Variant: return run_state.world_sequence_execute(token, {})},
		{"label": "command", "call": func() -> Variant: return run_state.world_sequence_command(token, "ignored_command", "ignored_receipt")},
		{"label": "enqueue_fact", "call": func() -> Variant: return run_state.world_sequence_enqueue_fact(token, {})},
		{"label": "flush_facts", "call": func() -> Variant: return run_state.world_sequence_flush_facts(token, 0)},
		{"label": "record_visit", "call": func() -> Variant: return run_state.world_sequence_record_visit(token, "ignored_visit")},
		{"label": "apply_reentry", "call": func() -> Variant: return run_state.world_sequence_apply_reentry(token, "ignored_visit")},
		{"label": "apply_expiry", "call": func() -> Variant: return run_state.world_sequence_apply_expiry(token, "town_action", 1)},
		{"label": "sync_owner_active", "call": func() -> Variant: return run_state.world_sequence_sync_owner(token, true, "owner_active")},
		{"label": "sync_owner_ended", "call": func() -> Variant: return run_state.world_sequence_sync_owner(token, false, "owner_ended")},
		{"label": "unmount", "call": func() -> Variant: return run_state.world_sequence_unmount(token, "abandoned")},
		{"label": "pending_outcomes", "call": func() -> Variant: return run_state.world_sequence_pending_outcomes(token)},
		{"label": "ack_outcome", "call": func() -> Variant: return run_state.world_sequence_ack_outcome(token, "ignored_outcome", {"ok": true})},
		{"label": "prepare_semantic_finalization", "call": func() -> Variant: return run_state.world_sequence_prepare_semantic_finalization()},
		{"label": "finalize_base_semantics", "call": func() -> Variant: return run_state.world_sequence_finalize_base_semantics([], library, {})},
	]
	for call_value in calls:
		var call_data: Dictionary = call_value
		var callback: Callable = call_data.get("call", Callable())
		if not callback.is_valid():
			failures.append("ignored world-sequence no-op %s has no callable probe" % str(call_data.get("label", "unknown")))
			continue
		callback.call()
		_append_world_sequence_noop_diff(str(call_data.get("label", "unknown")), baseline, _world_sequence_noop_snapshot(run_state), failures)
	return failures


static func _world_sequence_noop_snapshot(run_state: RunState) -> Dictionary:
	var run_dict := run_state.to_dict()
	var save_dict := run_state.to_save_snapshot()
	var current_environment := run_state.current_environment.duplicate(true)
	var world_map := run_state.world_map.duplicate(true)
	var registrations := run_state.world_sequence_registrations.duplicate(true)
	return {
		"to_dict": _json_identity(run_dict),
		"to_save_snapshot": _json_identity(save_dict),
		"current_environment": _json_identity(current_environment),
		"world_map": _json_identity(world_map),
		"registrations": _json_identity(registrations),
		"serialized_key_sets": {
			"to_dict": _serialized_key_paths(run_dict),
			"to_save_snapshot": _serialized_key_paths(save_dict),
			"current_environment": _serialized_key_paths(current_environment),
			"world_map": _serialized_key_paths(world_map),
			"registrations": _serialized_key_paths(registrations),
		},
	}


static func _json_identity(value: Variant) -> Dictionary:
	var text := JSON.stringify(value)
	return {"json": text, "bytes": text.to_utf8_buffer().size(), "sha256": text.sha256_text()}


static func _serialized_key_paths(value: Variant, path: String = "$") -> Array:
	var result: Array = []
	if typeof(value) == TYPE_DICTIONARY:
		var keys := (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key_value in keys:
			var child_path := "%s.%s" % [path, str(key_value)]
			result.append(child_path)
			result.append_array(_serialized_key_paths((value as Dictionary).get(key_value), child_path))
	elif typeof(value) == TYPE_ARRAY:
		for index in range((value as Array).size()):
			var child_path := "%s[%d]" % [path, index]
			result.append_array(_serialized_key_paths((value as Array)[index], child_path))
	return result


static func _append_world_sequence_noop_diff(label: String, expected: Dictionary, actual: Dictionary, failures: Array) -> void:
	for surface in ["to_dict", "to_save_snapshot", "current_environment", "world_map", "registrations"]:
		var expected_identity: Dictionary = expected.get(surface, {})
		var actual_identity: Dictionary = actual.get(surface, {})
		if str(actual_identity.get("json", "")) != str(expected_identity.get("json", "")):
			failures.append("ignored world-sequence no-op %s changed exact %s JSON bytes (before=%d/%s after=%d/%s)" % [
				label, surface,
				int(expected_identity.get("bytes", -1)), str(expected_identity.get("sha256", "")),
				int(actual_identity.get("bytes", -1)), str(actual_identity.get("sha256", "")),
			])
	var expected_keys: Dictionary = expected.get("serialized_key_sets", {})
	var actual_keys: Dictionary = actual.get("serialized_key_sets", {})
	for surface in ["to_dict", "to_save_snapshot", "current_environment", "world_map", "registrations"]:
		if actual_keys.get(surface, []) != expected_keys.get(surface, []):
			failures.append("ignored world-sequence no-op %s changed the recursive serialized key set for %s" % [label, surface])


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
