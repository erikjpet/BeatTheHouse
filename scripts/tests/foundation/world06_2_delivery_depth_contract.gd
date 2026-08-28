extends SceneTree

const DeliveryRunModelScript := preload("res://scripts/core/delivery_run_model.gd")

const REQUIRED_VERBS := [
	"pickup", "handoff", "move", "wait", "duck", "stash", "retrieve",
	"found", "ditch", "hold_signal", "hold_break", "interruption", "abandon",
]


func _initialize() -> void:
	var failures: Array = []
	_check_generic_action_surface(failures)
	_check_physical_cargo_and_ordered_handoffs(failures)
	_check_stash_retrieve_found_and_ditch(failures)
	_check_handoff_physical_authority_matrix(failures)
	_check_ditch_and_found_location_authority(failures)
	_check_sealed_movement_authority(failures)
	_check_closed_receipt_chain(failures)
	_check_hold_actions_and_interruptions(failures)
	_check_chase_verbs(failures)
	_check_terminal_matrix(failures)
	_check_save_revisit_and_determinism(failures)
	if failures.is_empty():
		print("world06_2 delivery depth contract passed")
		quit(0)
		return
	for failure in failures:
		push_error(str(failure))
	quit(1)


func _check_generic_action_surface(failures: Array) -> void:
	var source := _package_state("SURFACE")
	for verb in REQUIRED_VERBS:
		var before := JSON.stringify(source)
		var result: Dictionary = DeliveryRunModelScript.apply_action(source, verb, {"node_id": "wrong_node", "receipt_key": "surface:%s" % verb})
		if typeof(result) != TYPE_DICTIONARY:
			failures.append("Delivery action %s did not return a dictionary state." % verb)
		if JSON.stringify(source) != before:
			failures.append("Delivery action %s mutated its input state instead of returning a new authoritative state." % verb)


func _check_physical_cargo_and_ordered_handoffs(failures: Array) -> void:
	var state := _package_state("CARGO")
	_assert_cargo(state, "carried", "bar", failures, "begin")
	var wrong_pickup := _act(state, "pickup", "cargo:wrong", {"node_id": "motel"})
	_assert_exact_rejection(wrong_pickup, state, failures, "pickup at the wrong physical node")
	state = _act(state, "pickup", "cargo:pickup", {"node_id": "bar"})
	_assert_cargo(state, "carried", "bar", failures, "pickup")
	var pickup_exact := JSON.stringify(state)
	state = _act(state, "pickup", "cargo:pickup", {"node_id": "bar"})
	if JSON.stringify(state) != pickup_exact:
		failures.append("Replaying the pickup action was not an exact no-op.")
	state = _act(state, "move", "cargo:move:one", {"from_node_id": "bar", "node_id": "pawn_shop"})
	_assert_cargo(state, "carried", "pawn_shop", failures, "first move")
	var early_second := _act(state, "handoff", "cargo:handoff:second:early", {"node_id": "motel", "target_id": "second"})
	_assert_exact_rejection(early_second, state, failures, "out-of-order second handoff")
	state = _act(state, "handoff", "cargo:handoff:first", {"node_id": "pawn_shop", "target_id": "first"})
	if _delivered_target_ids(state) != ["first"]:
		failures.append("First multi-stop handoff did not persist its exact ordered target receipt.")
	var first_exact := JSON.stringify(state)
	state = _act(state, "handoff", "cargo:handoff:first", {"node_id": "pawn_shop", "target_id": "first"})
	if JSON.stringify(state) != first_exact:
		failures.append("Replaying a completed target handoff mutated state or duplicated its receipt.")
	state = _act(state, "move", "cargo:move:two", {"from_node_id": "pawn_shop", "node_id": "motel"})
	state = _act(state, "handoff", "cargo:handoff:second", {"node_id": "motel", "target_id": "second"})
	if str(state.get("status", "")) != "resolved" or str(_dict(state.get("resolution", {})).get("outcome", "")) != "success" \
			or _delivered_target_ids(state) != ["first", "second"]:
		failures.append("Ordered multi-stop handoffs did not resolve success with both target receipts exactly once.")


func _check_stash_retrieve_found_and_ditch(failures: Array) -> void:
	var carried := _act(_package_state("STASH"), "pickup", "stash:pickup", {"node_id": "bar"})
	var stashed := _act(carried, "stash", "stash:put", {"node_id": "bar", "place_id": "bar::back_booth"})
	_assert_cargo(stashed, "stashed", "bar", failures, "stash")
	var place := _dict(stashed.get("cargo_state", {}))
	if str(place.get("place_kind", "")) != "stash" or str(place.get("place_id", "")) != "bar::back_booth":
		failures.append("A stashed cargo object did not retain its closed physical place identity.")
	var saved_stash := DeliveryRunModelScript.normalize_state(stashed)
	if JSON.stringify(saved_stash) != JSON.stringify(stashed):
		failures.append("A physical stash did not survive model normalization byte-identically.")
	var wrong_retrieve := _act(saved_stash, "retrieve", "stash:get:wrong", {"node_id": "motel", "place_id": "bar::back_booth"})
	_assert_exact_rejection(wrong_retrieve, saved_stash, failures, "stash retrieval at the wrong node")
	var retrieved := _act(saved_stash, "retrieve", "stash:get", {"node_id": "bar", "place_id": "bar::back_booth"})
	_assert_cargo(retrieved, "carried", "bar", failures, "retrieve")
	var found := _act(stashed, "found", "stash:found", {"node_id": "bar", "place_id": "bar::back_booth", "finder_id": "sweep"})
	_assert_failed_resolution(found, "cargo_found", failures)
	var ditched := _act(carried, "ditch", "stash:ditch", {"node_id": "bar", "place_id": "bar::storm_drain"})
	_assert_failed_resolution(ditched, "ditched", failures)
	var exact := JSON.stringify(ditched)
	if JSON.stringify(_act(ditched, "ditch", "stash:ditch", {"node_id": "bar", "place_id": "bar::storm_drain"})) != exact:
		failures.append("Ditch replay changed terminal cargo state or duplicated failure receipts.")


func _check_handoff_physical_authority_matrix(failures: Array) -> void:
	var carried := _package_state("HANDOFF_HOSTILE")
	_assert_exact_rejection(_act(carried, "handoff", "handoff:before_arrival", {"node_id": "pawn_shop", "target_id": "first"}), carried, failures, "handoff before an authentic arrival")
	_assert_exact_rejection(_act(carried, "handoff", "handoff:remote", {"node_id": "motel", "target_id": "second"}), carried, failures, "remote handoff")
	var stashed := _act(carried, "stash", "handoff:stash", {"node_id": "bar", "place_id": "bar::locker"})
	_assert_exact_rejection(_act(stashed, "handoff", "handoff:stashed", {"node_id": "pawn_shop", "target_id": "first"}), stashed, failures, "handoff of stashed cargo")
	var found := _act(stashed, "found", "handoff:found:terminal", {"node_id": "bar", "place_id": "bar::locker", "finder_id": "sweep"})
	_assert_exact_rejection(_act(found, "handoff", "handoff:found", {"node_id": "pawn_shop", "target_id": "first"}), found, failures, "handoff of found cargo")
	var ditched := _act(carried, "ditch", "handoff:ditch:terminal", {"node_id": "bar", "place_id": "bar::drain"})
	_assert_exact_rejection(_act(ditched, "handoff", "handoff:ditched", {"node_id": "pawn_shop", "target_id": "first"}), ditched, failures, "handoff of ditched cargo")
	var arrived := _act(carried, "move", "handoff:arrive", {"node_id": "pawn_shop"})
	_assert_cargo(arrived, "carried", "pawn_shop", failures, "authentic arrival")
	var handed := _act(arrived, "handoff", "handoff:success", {"node_id": "pawn_shop", "target_id": "first"})
	if _delivered_target_ids(handed) != ["first"] or str(handed.get("handoff_pending_node_id", "not-cleared")) != "":
		failures.append("Authentic arrival, matching position, and carried cargo did not authorize exactly one handoff.")


func _check_ditch_and_found_location_authority(failures: Array) -> void:
	var carried := _package_state("LOCATION_AUTHORITY")
	_assert_exact_rejection(_act(carried, "ditch", "ditch:remote", {"node_id": "motel", "place_id": "motel::drain"}), carried, failures, "remote carried-cargo ditch")
	var carried_ditch := _act(carried, "ditch", "ditch:carried:local", {"node_id": "bar", "place_id": "bar::drain"})
	_assert_failed_resolution(carried_ditch, "ditched", failures)
	var stashed := _act(carried, "stash", "location:stash", {"node_id": "bar", "place_id": "bar::locker"})
	for hostile in [
		["ditch:stash:wrong_node", {"node_id": "motel", "place_id": "bar::locker"}],
		["ditch:stash:wrong_place", {"node_id": "bar", "place_id": "bar::drain"}],
		["found:wrong_node", {"node_id": "motel", "place_id": "bar::locker", "finder_id": "sweep"}],
		["found:wrong_place", {"node_id": "bar", "place_id": "bar::drain", "finder_id": "sweep"}],
	]:
		var verb := "found" if str(hostile[0]).begins_with("found") else "ditch"
		_assert_exact_rejection(_act(stashed, verb, str(hostile[0]), _dict(hostile[1])), stashed, failures, str(hostile[0]))
	var exact_ditch := _act(stashed, "ditch", "ditch:stash:exact", {"node_id": "bar", "place_id": "bar::locker"})
	if str(_dict(exact_ditch.get("cargo_state", {})).get("place_id", "")) != "bar::locker":
		failures.append("Ditching stashed cargo did not retain its exact stored node and place.")
	var exact_found := _act(stashed, "found", "found:exact", {"node_id": "bar", "place_id": "bar::locker", "finder_id": "sweep"})
	_assert_failed_resolution(exact_found, "cargo_found", failures)


func _check_sealed_movement_authority(failures: Array) -> void:
	var state := _package_state("SEALED_MOVEMENT")
	var move_context := {"node_id": "pawn_shop", "receipt_key": "sealed:move", "movement_authority": _movement_authority("bar", "pawn_shop", "bar_to_pawn")}
	var moved := DeliveryRunModelScript.apply_action(state, "move", move_context)
	if JSON.stringify(moved) == JSON.stringify(state):
		failures.append("Exact sealed source, destination, and route authority did not authorize adjacent movement.")
	for hostile_value in [
		{"node_id": "pawn_shop", "receipt_key": "sealed:missing"},
		{"node_id": "pawn_shop", "receipt_key": "sealed:source", "movement_authority": _with_field(_movement_authority("bar", "pawn_shop", "bar_to_pawn"), "source_node_id", "motel")},
		{"node_id": "motel", "receipt_key": "sealed:adjacency", "movement_authority": _with_field(_movement_authority("bar", "pawn_shop", "bar_to_pawn"), "destination_node_id", "motel")},
		{"node_id": "pawn_shop", "receipt_key": "sealed:route", "movement_authority": _with_field(_movement_authority("bar", "pawn_shop", "bar_to_pawn"), "route_id", "forged_route")},
		{"node_id": "pawn_shop", "receipt_key": "sealed:extra", "movement_authority": _with_extra(_movement_authority("bar", "pawn_shop", "bar_to_pawn"))},
		{"node_id": "pawn_shop", "receipt_key": "sealed:digest", "movement_authority": _with_bad_content_fingerprint(_movement_authority("bar", "pawn_shop", "bar_to_pawn"))},
	]:
		_assert_exact_rejection(DeliveryRunModelScript.apply_action(state, "move", _dict(hostile_value)), state, failures, "forged or malformed movement authority")
	var wait_ok := DeliveryRunModelScript.apply_action(state, "wait", {"node_id": "bar", "receipt_key": "sealed:wait", "movement_authority": _movement_authority("bar", "bar", "stay")})
	if JSON.stringify(wait_ok) == JSON.stringify(state):
		failures.append("Exact sealed stay authority did not authorize wait at the current node.")
	_assert_exact_rejection(DeliveryRunModelScript.apply_action(state, "wait", {"node_id": "pawn_shop", "receipt_key": "sealed:wait:remote", "movement_authority": _movement_authority("bar", "pawn_shop", "stay")}), state, failures, "remote wait")
	var duck_context := {"node_id": "bar", "receipt_key": "sealed:duck", "movement_authority": _movement_authority("bar", "bar", "stay"), "cover_id": "bar::dumpster", "cover_authority": _cover_authority("bar", "bar::dumpster")}
	var ducked := DeliveryRunModelScript.apply_action(state, "duck", duck_context)
	if JSON.stringify(ducked) == JSON.stringify(state):
		failures.append("Exact node-bound sealed cover authority did not authorize duck.")
	for hostile_cover in [
		{"node_id": "bar", "receipt_key": "sealed:duck:missing", "movement_authority": _movement_authority("bar", "bar", "stay"), "cover_id": "bar::dumpster"},
		{"node_id": "bar", "receipt_key": "sealed:duck:node", "movement_authority": _movement_authority("bar", "bar", "stay"), "cover_id": "motel::bed", "cover_authority": _cover_authority("motel", "motel::bed")},
		{"node_id": "bar", "receipt_key": "sealed:duck:id", "movement_authority": _movement_authority("bar", "bar", "stay"), "cover_id": "bar::dumpster", "cover_authority": _cover_authority("bar", "bar::booth")},
		{"node_id": "bar", "receipt_key": "sealed:duck:forged", "movement_authority": _movement_authority("bar", "bar", "stay"), "cover_id": "bar::dumpster", "cover_authority": _with_bad_content_fingerprint(_cover_authority("bar", "bar::dumpster"))},
	]:
		_assert_exact_rejection(DeliveryRunModelScript.apply_action(state, "duck", _dict(hostile_cover)), state, failures, "forged or cross-node cover authority")


func _check_closed_receipt_chain(failures: Array) -> void:
	var state := _act(_package_state("RECEIPTS"), "wait", "receipt:one", {"node_id": "bar"})
	state = _act(state, "move", "receipt:two", {"node_id": "pawn_shop"})
	var receipts := _dict(state.get("action_receipts", {}))
	var expected_keys := ["action", "envelope_fingerprint", "previous_receipt_fingerprint", "receipt_fingerprint", "receipt_key", "schema_version", "sequence"]
	for key in ["receipt:one", "receipt:two"]:
		var receipt := _dict(receipts.get(key, {}))
		var actual_keys: Array = receipt.keys()
		actual_keys.sort()
		if actual_keys != expected_keys or int(receipt.get("schema_version", 0)) != 1 or str(receipt.get("receipt_key", "")) != key:
			failures.append("Action receipt %s did not preserve the exact closed authenticated shape." % key)
		for digest_key in ["envelope_fingerprint", "previous_receipt_fingerprint", "receipt_fingerprint"]:
			var digest := str(receipt.get(digest_key, ""))
			if digest.length() != 64 or digest.to_lower() != digest or not digest.is_valid_hex_number():
				failures.append("Action receipt %s field %s was not lowercase 64-hex." % [key, digest_key])
	var conflicting := DeliveryRunModelScript.apply_action(state, "stash", {"node_id": "pawn_shop", "stash_id": "pawn_shop::locker", "receipt_key": "receipt:two"})
	_assert_exact_rejection(conflicting, state, failures, "conflicting replay envelope")
	for mutation in ["extra", "key", "action", "sequence", "envelope", "previous", "receipt", "malformed"]:
		var hostile := state.duplicate(true)
		var hostile_receipts := _dict(hostile.get("action_receipts", {}))
		var target := _dict(hostile_receipts.get("receipt:two", {}))
		match mutation:
			"extra": target["unexpected"] = true
			"key": target["receipt_key"] = "receipt:forged"
			"action": target["action"] = "stash"
			"sequence": target["sequence"] = 99
			"envelope": target["envelope_fingerprint"] = "0".repeat(64)
			"previous": target["previous_receipt_fingerprint"] = "1".repeat(64)
			"receipt": target["receipt_fingerprint"] = "2".repeat(64)
			"malformed": target["receipt_fingerprint"] = "not_hex"
		hostile_receipts["receipt:two"] = target
		hostile["action_receipts"] = hostile_receipts
		if not DeliveryRunModelScript.normalize_state(hostile).is_empty():
			failures.append("Malformed restored receipt chain did not fail closed: %s." % mutation)


func _check_hold_actions_and_interruptions(failures: Array) -> void:
	var hold := DeliveryRunModelScript.begin({
		"run_id": "depth_hold", "mode": "hold", "pickup_node_id": "cage", "targets": [{"id": "window", "node_id": "cage"}],
		"deadline_actions": 6, "hold_required_actions": 2, "hold_attention_limit": 40,
	}, 0)
	hold = _act(hold, "pickup", "hold:pickup", {"node_id": "cage"})
	var passive := _act(hold, "wait", "hold:wait", {"node_id": "cage", "attention": 10, "action_index": 1})
	if int(passive.get("hold_progress", 0)) != 1:
		failures.append("A real wait action did not advance exactly one bounded hold step.")
	var signaled := _act(passive, "hold_signal", "hold:signal:one", {"node_id": "cage", "attention": 10, "action_index": 2, "signal_id": "cage_clear"})
	if str(signaled.get("status", "")) != "resolved" or str(_dict(signaled.get("resolution", {})).get("reason", "")) != "held_window" \
			or _array(signaled.get("hold_signals", [])).size() != 1:
		failures.append("A real hold signal did not complete the window with one durable signal receipt.")
	var interrupted := _act(hold, "interruption", "hold:interrupt", {"node_id": "cage", "reason": "room_scenario"})
	_assert_failed_resolution(interrupted, "room_scenario", failures)
	if str(_dict(interrupted.get("hold_aftermath", {})).get("outcome", "")) != "room_scenario":
		failures.append("Hold interruption did not retain its distinct physical aftermath.")
	var broken := _act(hold, "hold_break", "hold:break", {"node_id": "cage", "reason": "left_sightline"})
	_assert_failed_resolution(broken, "hold_broken", failures)


func _check_chase_verbs(failures: Array) -> void:
	var chase := DeliveryRunModelScript.begin({
		"run_id": "depth_chase", "mode": "getaway", "pickup_node_id": "casino", "targets": [{"id": "exit", "node_id": "motel"}],
		"deadline_actions": 9, "pursuit_pressure": 4, "pursuit_per_boundary": 2, "pursuit_limit": 12,
	}, 0)
	for step in [
		["move", "chase:move", {"from_node_id": "casino", "node_id": "bar", "position_id": "bar::alley"}],
		["wait", "chase:wait", {"node_id": "bar", "position_id": "bar::alley", "attention": 5, "action_index": 1}],
		["duck", "chase:duck", {"node_id": "bar", "position_id": "bar::dumpster", "cover_id": "bar::dumpster"}],
		["stash", "chase:stash", {"node_id": "bar", "stash_id": "bar::dumpster"}],
		["retrieve", "chase:retrieve", {"node_id": "bar", "stash_id": "bar::dumpster"}],
	]:
		var before := JSON.stringify(chase)
		chase = _act(chase, str(step[0]), str(step[1]), _dict(step[2]))
		if JSON.stringify(chase) == before or not _action_receipt_ids(chase).has(str(step[1])):
			failures.append("Chase verb %s did not materially act on model position/cargo/pursuit state with a receipt." % str(step[0]))
	var ditched := _act(chase, "ditch", "chase:ditch", {"node_id": "bar", "place_id": "bar::drain"})
	_assert_failed_resolution(ditched, "ditched", failures)


func _check_terminal_matrix(failures: Array) -> void:
	var abandoned := _act(_package_state("ABANDON"), "abandon", "terminal:abandon", {"reason": "abandoned"})
	_assert_failed_resolution(abandoned, "abandoned", failures)
	var expired := DeliveryRunModelScript.advance_boundaries(_package_state("EXPIRE", 1), 1, "bar", 0, 1)
	_assert_failed_resolution(expired, "deadline", failures)
	var caught := DeliveryRunModelScript.begin({"run_id": "caught", "mode": "getaway", "pickup_node_id": "casino", "targets": [{"id": "exit", "node_id": "motel"}], "deadline_actions": 8, "pursuit_pressure": 4, "pursuit_per_boundary": 2, "pursuit_limit": 5}, 0)
	caught = _act(caught, "wait", "caught:wait", {"node_id": "casino", "action_index": 1})
	_assert_failed_resolution(caught, "caught", failures)


func _check_save_revisit_and_determinism(failures: Array) -> void:
	var state := _act(_package_state("SAVE"), "pickup", "save:pickup", {"node_id": "bar"})
	state = _act(state, "move", "save:move", {"from_node_id": "bar", "node_id": "pawn_shop"})
	state = _act(state, "stash", "save:stash", {"node_id": "pawn_shop", "stash_id": "pawn_shop::locker"})
	var restored := DeliveryRunModelScript.normalize_state(state)
	if JSON.stringify(restored) != JSON.stringify(state):
		failures.append("Save/reload normalization changed physical cargo, location, or action receipts.")
	var revisit_wrong := _act(restored, "retrieve", "save:retrieve:away", {"node_id": "bar", "stash_id": "pawn_shop::locker"})
	_assert_exact_rejection(revisit_wrong, restored, failures, "retrieve before revisiting the stash node")
	var revisit := _act(restored, "retrieve", "save:retrieve", {"node_id": "pawn_shop", "stash_id": "pawn_shop::locker"})
	_assert_cargo(revisit, "carried", "pawn_shop", failures, "revisit retrieve")
	var twin_a := _package_state("DETERMINISTIC")
	var twin_b := _package_state("DETERMINISTIC")
	for step in [["pickup", "d:1", {"node_id": "bar"}], ["move", "d:2", {"from_node_id": "bar", "node_id": "pawn_shop"}], ["stash", "d:3", {"node_id": "pawn_shop", "stash_id": "pawn_shop::locker"}]]:
		twin_a = _act(twin_a, str(step[0]), str(step[1]), _dict(step[2]))
		twin_b = _act(twin_b, str(step[0]), str(step[1]), _dict(step[2]))
	if JSON.stringify(twin_a) != JSON.stringify(twin_b):
		failures.append("Identical physical delivery action sequences did not reproduce byte-identically.")
	var exact := JSON.stringify(twin_a)
	for receipt_id in ["d:1", "d:2", "d:3"]:
		twin_a = _act(twin_a, "stash", receipt_id, {"node_id": "pawn_shop", "stash_id": "pawn_shop::locker"})
	if JSON.stringify(twin_a) != exact:
		failures.append("Replayed delivery action receipts were not exact no-ops.")


func _package_state(suffix: String, deadline: int = 12) -> Dictionary:
	return DeliveryRunModelScript.begin({
		"run_id": "depth_%s" % suffix.to_lower(), "mode": "multi_stop", "pickup_node_id": "bar",
		"cargo_id": "sealed_case", "cargo_label": "Sealed case", "targets": [
			{"id": "first", "node_id": "pawn_shop"}, {"id": "second", "node_id": "motel"},
		], "deadline_actions": deadline,
	}, 0)


func _act(state: Dictionary, verb: String, action_id: String, context: Dictionary) -> Dictionary:
	var payload := context.duplicate(true)
	payload["receipt_key"] = action_id
	if verb in ["move", "wait", "duck"] and not payload.has("movement_authority"):
		var source_node := str(_dict(state.get("position_state", {})).get("node_id", ""))
		var destination_node := str(payload.get("node_id", source_node))
		var route_id := "stay" if verb in ["wait", "duck"] else "%s_to_%s" % [source_node, destination_node]
		payload["movement_authority"] = _movement_authority(source_node, destination_node, route_id)
	if verb == "duck" and not payload.has("cover_authority"):
		var cover_id := str(payload.get("cover_id", _dict(payload.get("context", {})).get("cover_id", "")))
		payload["cover_authority"] = _cover_authority(str(payload.get("node_id", "")), cover_id)
	return DeliveryRunModelScript.apply_action(state, verb, payload)


func _movement_authority(source_node_id: String, destination_node_id: String, route_id: String) -> Dictionary:
	var authority := {"schema_version": 1, "source_node_id": source_node_id, "destination_node_id": destination_node_id, "route_id": route_id}
	var canonical := {"destination_node_id": destination_node_id, "route_id": route_id, "schema_version": 1, "source_node_id": source_node_id}
	authority["content_fingerprint"] = JSON.stringify(canonical).sha256_text()
	return authority


func _cover_authority(node_id: String, cover_id: String) -> Dictionary:
	var authority := {"schema_version": 1, "node_id": node_id, "cover_id": cover_id}
	var canonical := {"cover_id": cover_id, "node_id": node_id, "schema_version": 1}
	authority["content_fingerprint"] = JSON.stringify(canonical).sha256_text()
	return authority


func _with_extra(authority_value: Dictionary) -> Dictionary:
	var authority := authority_value.duplicate(true)
	authority["unexpected"] = true
	return authority


func _with_bad_content_fingerprint(authority_value: Dictionary) -> Dictionary:
	var authority := authority_value.duplicate(true)
	authority["content_fingerprint"] = "0".repeat(64)
	return authority


func _with_field(authority_value: Dictionary, key: String, value: Variant) -> Dictionary:
	var authority := authority_value.duplicate(true)
	authority[key] = value
	return authority


func _assert_cargo(state: Dictionary, expected_status: String, expected_node: String, failures: Array, stage: String) -> void:
	var cargo := DeliveryRunModelScript.cargo(state)
	var allowed := ["instance_id", "cargo_id", "label", "status", "node_id"]
	for key_value in cargo.keys():
		if not allowed.has(str(key_value)):
			failures.append("%s cargo projection exposed an unregistered field %s." % [stage, str(key_value)])
	if str(cargo.get("instance_id", "")).is_empty() or str(cargo.get("cargo_id", "")) != "sealed_case" \
			or str(cargo.get("label", "")) != "Sealed case" or str(cargo.get("status", "")) != expected_status \
			or str(cargo.get("node_id", "")) != expected_node:
		failures.append("%s did not preserve physical cargo identity/status/location: %s." % [stage, JSON.stringify(cargo)])


func _assert_exact_rejection(actual: Dictionary, expected: Dictionary, failures: Array, label: String) -> void:
	if JSON.stringify(actual) != JSON.stringify(expected):
		failures.append("Rejected %s was not an exact state no-op." % label)


func _assert_failed_resolution(state: Dictionary, reason: String, failures: Array) -> void:
	if str(state.get("status", "")) != "resolved" or str(_dict(state.get("resolution", {})).get("outcome", "")) != "failed" \
			or str(_dict(state.get("resolution", {})).get("reason", "")) != reason:
		failures.append("Delivery terminal reason %s did not resolve once through the model: %s." % [reason, JSON.stringify(state.get("resolution", {}))])


func _delivered_target_ids(state: Dictionary) -> Array:
	var result: Array = []
	for target_value in _array(state.get("targets", [])):
		var target := _dict(target_value)
		if str(target.get("status", "")) == "delivered":
			result.append(str(target.get("id", "")))
	return result


func _action_receipt_ids(state: Dictionary) -> Array:
	var result: Array = _dict(state.get("action_receipts", {})).keys()
	result.sort()
	return result


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
