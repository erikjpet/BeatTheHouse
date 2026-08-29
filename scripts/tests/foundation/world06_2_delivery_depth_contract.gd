extends SceneTree

const DeliveryRunModelScript := preload("res://scripts/core/delivery_run_model.gd")


func _initialize() -> void:
	var failures: Array = []
	_check_schema_migration(failures)
	_check_physical_route(failures)
	_check_location_actions(failures)
	_check_hold_and_pursuit(failures)
	_check_receipts_and_host_boundary(failures)
	if failures.is_empty():
		print("world06_2 delivery depth contract passed")
		quit(0)
		return
	for failure in failures:
		push_error(str(failure))
	quit(1)


func _check_schema_migration(failures: Array) -> void:
	var current := _package_state("SCHEMA")
	if int(current.get("schema_version", 0)) != 3 or int(_dict(current.get("depth_state", {})).get("schema_version", 0)) != 1:
		failures.append("New delivery state did not use the exact versioned physical envelope.")
	var stripped := current.duplicate(true)
	stripped.erase("depth_state")
	_assert_empty(DeliveryRunModelScript.normalize_state(stripped), failures, "schema-3 state with stripped physical state")
	var downgraded := current.duplicate(true)
	downgraded["schema_version"] = 2
	_assert_empty(DeliveryRunModelScript.normalize_state(downgraded), failures, "schema downgrade retaining physical state")
	var legacy := current.duplicate(true)
	legacy["schema_version"] = 2
	legacy.erase("depth_state")
	var migrated := DeliveryRunModelScript.normalize_state(legacy)
	if int(migrated.get("schema_version", 0)) != 3 or str(_physical(migrated).get("cargo_state", "")) != "carried" \
			or str(_dict(migrated.get("depth_state", {})).get("origin", "")) != "legacy_v2":
		failures.append("Exact schema-2 migration did not preserve legacy carried-cargo semantics.")
	var round_trip := DeliveryRunModelScript.normalize_state(current)
	if JSON.stringify(round_trip) != JSON.stringify(current):
		failures.append("Current physical state did not normalize byte-identically.")


func _check_physical_route(failures: Array) -> void:
	var state := _package_state("ROUTE")
	if str(_physical(state).get("cargo_state", "")) != "pickup_pending":
		failures.append("A current delivery did not begin as a physical pickup at its host node.")
	_assert_exact(_act(state, "pickup", "pickup:wrong", {"node_id": "motel", "target_id": "delivery_pickup"}), state, failures, "remote pickup")
	_assert_exact(_act(state, "pickup", "pickup:missing_target", {"node_id": "bar"}), state, failures, "pickup without a mandatory target")
	state = _act(state, "pickup", "pickup:ok", {"node_id": "bar", "target_id": "delivery_pickup"})
	_assert_physical(state, "carried", "bar", failures, "pickup")
	var moved := _act(state, "move", "move:first", {"node_id": "bar", "destination_node_id": "pawn_shop"})
	_assert_physical(moved, "carried", "pawn_shop", failures, "first real-map move")
	_assert_exact(_act(moved, "handoff", "handoff:wrong", {"node_id": "pawn_shop", "target_id": "second"}), moved, failures, "out-of-order handoff")
	moved = _act(moved, "handoff", "handoff:first", {"node_id": "pawn_shop", "target_id": "first"})
	if _delivered_ids(moved) != ["first"]:
		failures.append("First staged handoff did not persist exact multi-stop ordering.")
	moved = _act(moved, "move", "move:second", {"node_id": "pawn_shop", "destination_node_id": "motel"})
	moved = _act(moved, "handoff", "handoff:second", {"node_id": "motel", "target_id": "second"})
	if str(moved.get("status", "")) != "resolved" or str(_dict(moved.get("resolution", {})).get("reason", "")) != "delivered" \
			or str(_physical(moved).get("cargo_state", "")) != "delivered":
		failures.append("Ordered physical handoffs did not reach one delivered terminal state.")


func _check_location_actions(failures: Array) -> void:
	var carried := _act(_package_state("LOCATION"), "pickup", "location:pickup", {"node_id": "bar", "target_id": "delivery_pickup"})
	_assert_exact(_act(carried, "stash", "stash:remote", {"node_id": "motel", "place_id": "motel::locker"}), carried, failures, "remote stash")
	var stashed := _act(carried, "stash", "stash:put", {"node_id": "bar", "place_id": "bar::locker"})
	_assert_physical(stashed, "stashed", "bar", failures, "stash")
	if str(_physical(stashed).get("cargo_place_id", "")) != "bar::locker":
		failures.append("Stashed cargo did not retain its exact real place.")
	_assert_exact(_act(stashed, "retrieve", "stash:wrong", {"node_id": "bar", "place_id": "bar::drain"}), stashed, failures, "wrong-place retrieval")
	var restored := DeliveryRunModelScript.normalize_state(stashed)
	var retrieved := _act(restored, "retrieve", "stash:get", {"node_id": "bar", "place_id": "bar::locker"})
	_assert_physical(retrieved, "carried", "bar", failures, "save/revisit retrieval")
	var found := _act(stashed, "found", "stash:found", {"node_id": "bar", "place_id": "bar::locker", "target_id": "sweep"})
	_assert_terminal(found, "cargo_found", failures)
	var ditched := _act(carried, "ditch", "stash:ditch", {"node_id": "bar", "place_id": "bar::drain"})
	_assert_terminal(ditched, "ditched", failures)


func _check_hold_and_pursuit(failures: Array) -> void:
	var hold := DeliveryRunModelScript.begin({
		"run_id": "depth_hold", "mode": "hold", "start_node_id": "cage",
		"targets": [{"id": "window", "node_id": "cage"}], "deadline_actions": 6,
		"hold_required_actions": 2, "hold_attention_limit": 40,
	}, 0)
	hold = _act(hold, "wait", "hold:wait", {"node_id": "cage", "attention": 10, "action_index": 1})
	if int(hold.get("hold_progress", 0)) != 1:
		failures.append("A host-issued wait did not advance one hold boundary.")
	hold = _act(hold, "signal", "hold:signal", {"node_id": "cage", "signal_id": "cage_clear", "attention": 10, "action_index": 2})
	if str(_dict(hold.get("resolution", {})).get("reason", "")) != "held_window" or _array(_dict(hold.get("depth_state", {})).get("hold_signals", [])).size() != 1:
		failures.append("Signal did not complete the hold with durable staged aftermath.")
	var broken := _act(DeliveryRunModelScript.begin({"run_id": "break", "mode": "hold", "start_node_id": "cage", "targets": [{"id": "window", "node_id": "cage"}], "deadline_actions": 4}, 0), "break_hold", "hold:break", {"node_id": "cage", "action_index": 1})
	_assert_terminal(broken, "hold_broken", failures)
	var chase := DeliveryRunModelScript.begin({
		"run_id": "chase", "mode": "getaway", "start_node_id": "casino",
		"targets": [{"id": "exit", "node_id": "motel"}], "deadline_actions": 8,
		"pursuit_pressure": 6, "pursuit_per_boundary": 2, "pursuit_limit": 12,
	}, 0)
	var ducked := _act(chase, "duck", "chase:duck", {"node_id": "casino", "cover_id": "casino::alley"})
	if int(ducked.get("pursuit_pressure", 0)) != 4:
		failures.append("Shared duck verb did not use the landed pursuit-pressure relief.")
	var escaped := _act(ducked, "move", "chase:move", {"node_id": "casino", "destination_node_id": "motel"})
	_assert_terminal(escaped, "escaped", failures)


func _check_receipts_and_host_boundary(failures: Array) -> void:
	var state := _act(_package_state("RECEIPT"), "pickup", "receipt:one", {"node_id": "bar", "target_id": "delivery_pickup"})
	var exact := JSON.stringify(state)
	state = _act(state, "pickup", "receipt:one", {"node_id": "bar", "target_id": "delivery_pickup"})
	if JSON.stringify(state) != exact:
		failures.append("Exact host command replay was not a byte-identical no-op.")
	_assert_exact(_act(state, "stash", "receipt:one", {"node_id": "bar", "place_id": "bar::locker"}), state, failures, "conflicting receipt replay")
	var malformed_context := _context({"node_id": "bar", "place_id": "bar::locker"})
	malformed_context["caller_authority"] = true
	_assert_exact(DeliveryRunModelScript.apply_host_action(state, "stash", "receipt:malformed", malformed_context), state, failures, "caller-supplied authority field")
	var depth := _dict(state.get("depth_state", {}))
	var receipts := _array(depth.get("command_receipts", []))
	if receipts.size() != 1 or int(depth.get("command_sequence", 0)) != 1:
		failures.append("Physical command receipt journal was not exact and bounded.")
	var hostile := state.duplicate(true)
	var hostile_depth := _dict(hostile.get("depth_state", {}))
	var hostile_receipts := _array(hostile_depth.get("command_receipts", []))
	var hostile_receipt := _dict(hostile_receipts[0])
	hostile_receipt["unexpected"] = true
	hostile_receipts[0] = hostile_receipt
	hostile_depth["command_receipts"] = hostile_receipts
	hostile["depth_state"] = hostile_depth
	_assert_empty(DeliveryRunModelScript.normalize_state(hostile), failures, "tampered physical receipt")


func _package_state(suffix: String) -> Dictionary:
	return DeliveryRunModelScript.begin({
		"run_id": "depth_%s" % suffix.to_lower(), "mode": "multi_stop", "start_node_id": "bar",
		"pickup_object_id": "delivery_pickup", "cargo_id": "sealed_case", "cargo_label": "Sealed case",
		"targets": [{"id": "first", "node_id": "pawn_shop"}, {"id": "second", "node_id": "motel"}],
		"deadline_actions": 12,
	}, 0)


func _act(state: Dictionary, verb: String, receipt_key: String, overrides: Dictionary = {}) -> Dictionary:
	return DeliveryRunModelScript.apply_host_action(state, verb, receipt_key, _context(overrides))


func _context(overrides: Dictionary = {}) -> Dictionary:
	var result := {
		"schema_version": 1, "node_id": "", "destination_node_id": "", "target_id": "", "place_id": "",
		"cover_id": "", "signal_id": "", "reason": "", "attention": 0, "action_index": 0,
	}
	for key_value in overrides.keys():
		result[key_value] = overrides.get(key_value)
	return result


func _physical(state: Dictionary) -> Dictionary:
	return DeliveryRunModelScript.physical_projection(state)


func _delivered_ids(state: Dictionary) -> Array:
	var result: Array = []
	for target_value in _array(state.get("targets", [])):
		var target := _dict(target_value)
		if str(target.get("status", "")) == "delivered": result.append(str(target.get("id", "")))
	return result


func _assert_physical(state: Dictionary, status: String, node_id: String, failures: Array, stage: String) -> void:
	var physical := _physical(state)
	if str(physical.get("cargo_state", "")) != status or str(physical.get("cargo_node_id", "")) != node_id:
		failures.append("%s did not preserve physical cargo status/location." % stage)


func _assert_terminal(state: Dictionary, reason: String, failures: Array) -> void:
	if str(state.get("status", "")) != "resolved" or str(_dict(state.get("resolution", {})).get("reason", "")) != reason:
		failures.append("Terminal reason %s did not resolve exactly once." % reason)


func _assert_exact(actual: Dictionary, expected: Dictionary, failures: Array, label: String) -> void:
	if JSON.stringify(actual) != JSON.stringify(expected): failures.append("Rejected %s was not an exact no-op." % label)


func _assert_empty(actual: Dictionary, failures: Array, label: String) -> void:
	if not actual.is_empty(): failures.append("Rejected %s did not fail closed." % label)


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
