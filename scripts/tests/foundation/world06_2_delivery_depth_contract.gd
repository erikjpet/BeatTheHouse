extends SceneTree

const DeliveryRunModelScript := preload("res://scripts/core/delivery_run_model.gd")


func _initialize() -> void:
	var failures: Array = []
	_check_schema_migration(failures)
	_check_physical_route(failures)
	_check_location_actions(failures)
	_check_hold_and_pursuit(failures)
	_check_receipts_and_host_boundary(failures)
	_check_generic_host_surface(failures)
	_check_handoff_authority_matrix(failures)
	_check_host_context_matrix(failures)
	_check_receipt_mutation_matrix(failures)
	_check_terminal_matrix(failures)
	_check_determinism_and_revisit(failures)
	_check_receipt_bound(failures)
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
	legacy["schema_version"] = 1
	var migrated_v1 := DeliveryRunModelScript.normalize_state(legacy)
	if int(migrated_v1.get("schema_version", 0)) != 3 or str(_dict(migrated_v1.get("depth_state", {})).get("origin", "")) != "legacy_v1":
		failures.append("Exact schema-1 migration did not preserve the original delivery save path.")
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
	_assert_exact(DeliveryRunModelScript.note_arrival(state, "pawn_shop"), state, failures, "caller-issued arrival without a host move")
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
	if int(ducked.get("pursuit_pressure", 0)) != 6:
		failures.append("Shared duck verb did not cancel exactly one landed pursuit increment.")
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


func _check_generic_host_surface(failures: Array) -> void:
	for verb_value in DeliveryRunModelScript.HOST_VERBS:
		var source := _package_state("SURFACE_%s" % str(verb_value))
		var before := JSON.stringify(source)
		var result := DeliveryRunModelScript.apply_host_action(source, str(verb_value), "surface:%s" % str(verb_value), _context({"node_id": "wrong_node"}))
		if typeof(result) != TYPE_DICTIONARY:
			failures.append("Host action %s did not return dictionary state." % str(verb_value))
		if JSON.stringify(source) != before:
			failures.append("Host action %s mutated its input state." % str(verb_value))


func _check_handoff_authority_matrix(failures: Array) -> void:
	var carried := _act(_package_state("HANDOFF_MATRIX"), "pickup", "matrix:pickup", {"node_id": "bar", "target_id": "delivery_pickup"})
	_assert_exact(_act(carried, "handoff", "matrix:early", {"node_id": "pawn_shop", "target_id": "first"}), carried, failures, "handoff before host arrival")
	_assert_exact(_act(carried, "handoff", "matrix:remote", {"node_id": "motel", "target_id": "second"}), carried, failures, "remote handoff")
	var stashed := _act(carried, "stash", "matrix:stash", {"node_id": "bar", "place_id": "bar::locker"})
	var stashed_arrival := _act(stashed, "move", "matrix:stash:move", {"node_id": "bar", "destination_node_id": "pawn_shop"})
	_assert_exact(_act(stashed_arrival, "handoff", "matrix:stashed", {"node_id": "pawn_shop", "target_id": "first"}), stashed_arrival, failures, "handoff of remotely stashed cargo")
	var found := _act(stashed, "found", "matrix:found", {"node_id": "bar", "place_id": "bar::locker", "target_id": "sweep"})
	_assert_exact(_act(found, "handoff", "matrix:found:handoff", {"node_id": "pawn_shop", "target_id": "first"}), found, failures, "handoff of found cargo")
	var ditched := _act(carried, "ditch", "matrix:ditch", {"node_id": "bar", "place_id": "bar::drain"})
	_assert_exact(_act(ditched, "handoff", "matrix:ditch:handoff", {"node_id": "pawn_shop", "target_id": "first"}), ditched, failures, "handoff of ditched cargo")


func _check_host_context_matrix(failures: Array) -> void:
	var state := _act(_package_state("HOST_CONTEXT"), "pickup", "host:pickup", {"node_id": "bar", "target_id": "delivery_pickup"})
	var missing := _context({"node_id": "bar", "destination_node_id": "pawn_shop"})
	missing.erase("target_id")
	_assert_exact(DeliveryRunModelScript.apply_host_action(state, "move", "host:missing", missing), state, failures, "host context missing an exact field")
	var extra := _context({"node_id": "bar", "destination_node_id": "pawn_shop"})
	extra["authority"] = true
	_assert_exact(DeliveryRunModelScript.apply_host_action(state, "move", "host:extra", extra), state, failures, "host context with caller authority")
	_assert_exact(_act(state, "move", "host:same", {"node_id": "bar", "destination_node_id": "bar"}), state, failures, "zero-length move")
	_assert_exact(_act(state, "wait", "host:remote_wait", {"node_id": "motel"}), state, failures, "remote wait")
	_assert_exact(_act(state, "duck", "host:no_cover", {"node_id": "bar"}), state, failures, "duck without host cover")
	var whitespace := _context({"node_id": " bar ", "place_id": "bar::locker"})
	_assert_exact(DeliveryRunModelScript.apply_host_action(state, "stash", "host:whitespace", whitespace), state, failures, "noncanonical host text")


func _check_receipt_mutation_matrix(failures: Array) -> void:
	var state := _act(_package_state("RECEIPT_MATRIX"), "pickup", "receipt:pickup", {"node_id": "bar", "target_id": "delivery_pickup"})
	state = _act(state, "wait", "receipt:wait", {"node_id": "bar", "action_index": 1})
	for mutation in ["extra", "key", "command", "sequence", "envelope", "previous", "receipt", "malformed"]:
		var hostile := state.duplicate(true)
		var depth := _dict(hostile.get("depth_state", {}))
		var receipts := _array(depth.get("command_receipts", []))
		var receipt := _dict(receipts[1])
		match mutation:
			"extra": receipt["unexpected"] = true
			"key": receipt["receipt_key"] = "receipt:forged"
			"command": receipt["command_id"] = "stash"
			"sequence": receipt["sequence"] = 99
			"envelope": receipt["command_record_fingerprint"] = "0".repeat(64)
			"previous": receipt["previous_receipt_fingerprint"] = "1".repeat(64)
			"receipt": receipt["receipt_fingerprint"] = "2".repeat(64)
			"malformed": receipt["receipt_fingerprint"] = "not_hex"
		receipts[1] = receipt
		depth["command_receipts"] = receipts
		hostile["depth_state"] = depth
		_assert_empty(DeliveryRunModelScript.normalize_state(hostile), failures, "receipt mutation %s" % mutation)


func _check_terminal_matrix(failures: Array) -> void:
	var abandoned := _act(_package_state("ABANDON"), "abandon", "terminal:abandon", {"reason": "abandoned"})
	_assert_terminal(abandoned, "abandoned", failures)
	var expiring := _package_state("EXPIRE")
	expiring["deadline_remaining"] = 1
	expiring = DeliveryRunModelScript.advance_boundaries(expiring, 1, "bar", 0, 1)
	_assert_terminal(expiring, "deadline", failures)
	var hold := DeliveryRunModelScript.begin({"run_id": "interrupt", "mode": "hold", "start_node_id": "cage", "targets": [{"id": "window", "node_id": "cage"}], "deadline_actions": 5}, 0)
	hold = _act(hold, "interruption", "terminal:interrupt", {"node_id": "cage", "reason": "room_scenario"})
	_assert_terminal(hold, "room_scenario", failures)
	if str(_dict(_dict(hold.get("depth_state", {})).get("hold_aftermath", {})).get("outcome", "")) != "room_scenario":
		failures.append("Hold interruption did not persist its distinct aftermath.")
	var caught := DeliveryRunModelScript.begin({
		"run_id": "caught", "mode": "getaway", "start_node_id": "casino", "targets": [{"id": "exit", "node_id": "motel"}],
		"deadline_actions": 8, "pursuit_pressure": 4, "pursuit_per_boundary": 2, "pursuit_limit": 5,
	}, 0)
	caught = _act(caught, "wait", "terminal:caught", {"node_id": "casino", "action_index": 1})
	_assert_terminal(caught, "caught", failures)


func _check_determinism_and_revisit(failures: Array) -> void:
	var twin_a := _package_state("DETERMINISTIC")
	var twin_b := _package_state("DETERMINISTIC")
	for step in [
		["pickup", "d:1", {"node_id": "bar", "target_id": "delivery_pickup"}],
		["move", "d:2", {"node_id": "bar", "destination_node_id": "pawn_shop"}],
		["stash", "d:3", {"node_id": "pawn_shop", "place_id": "pawn_shop::locker"}],
	]:
		twin_a = _act(twin_a, str(step[0]), str(step[1]), _dict(step[2]))
		twin_b = _act(twin_b, str(step[0]), str(step[1]), _dict(step[2]))
	if JSON.stringify(twin_a) != JSON.stringify(twin_b):
		failures.append("Identical physical command sequences were not byte-deterministic.")
	var saved := DeliveryRunModelScript.normalize_state(twin_a)
	if JSON.stringify(saved) != JSON.stringify(twin_a):
		failures.append("Save normalization changed the deterministic physical command chain.")
	_assert_exact(_act(saved, "retrieve", "d:away", {"node_id": "bar", "place_id": "pawn_shop::locker"}), saved, failures, "retrieve before revisiting stash")
	var revisited := _act(saved, "wait", "d:revisit_position", {"node_id": "pawn_shop", "action_index": 3})
	var retrieved := _act(revisited, "retrieve", "d:retrieve", {"node_id": "pawn_shop", "place_id": "pawn_shop::locker"})
	_assert_physical(retrieved, "carried", "pawn_shop", failures, "deterministic revisit retrieval")
	for seed_index in range(10):
		var seed_a := _package_state("SEED_%d" % seed_index)
		var seed_b := _package_state("SEED_%d" % seed_index)
		for step in [
			["pickup", "seed:%d:pickup" % seed_index, {"node_id": "bar", "target_id": "delivery_pickup"}],
			["wait", "seed:%d:wait" % seed_index, {"node_id": "bar", "action_index": 1}],
			["stash", "seed:%d:stash" % seed_index, {"node_id": "bar", "place_id": "bar::locker"}],
		]:
			seed_a = _act(seed_a, str(step[0]), str(step[1]), _dict(step[2]))
			seed_b = _act(seed_b, str(step[0]), str(step[1]), _dict(step[2]))
		if JSON.stringify(seed_a) != JSON.stringify(seed_b):
			failures.append("Physical route determinism diverged at seed index %d." % seed_index)


func _check_receipt_bound(failures: Array) -> void:
	var state := DeliveryRunModelScript.begin({
		"run_id": "bounded", "mode": "package", "start_node_id": "bar", "targets": [{"id": "target", "node_id": "motel"}],
		"deadline_actions": 100,
	}, 0)
	state = _act(state, "pickup", "bound:pickup", {"node_id": "bar", "target_id": "delivery_pickup"})
	for index in range(63):
		state = _act(state, "wait", "bound:wait:%d" % index, {"node_id": "bar", "action_index": index + 1})
	var exact := state.duplicate(true)
	state = _act(state, "stash", "bound:overflow", {"node_id": "bar", "place_id": "bar::locker"})
	_assert_exact(state, exact, failures, "command beyond the bounded receipt journal")
	if _array(_dict(state.get("depth_state", {})).get("command_receipts", [])).size() != DeliveryRunModelScript.MAX_DEPTH_COMMAND_RECEIPTS:
		failures.append("Physical receipt journal did not stop at its published bound.")


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
