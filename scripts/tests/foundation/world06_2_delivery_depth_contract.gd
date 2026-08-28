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
	return DeliveryRunModelScript.apply_action(state, verb, payload)


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
