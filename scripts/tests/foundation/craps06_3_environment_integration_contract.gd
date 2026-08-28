extends SceneTree

const BindingScript := preload("res://scripts/core/craps06_3_environment_binding.gd")
const HostTransactionScript := preload("res://scripts/core/scenario_host_transaction.gd")
const InventoryScript := preload("res://scripts/core/environment_semantic_inventory.gd")
const SequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")

var failures: Array[String] = []


func _init() -> void:
	for error_value in BindingScript.validate_registration(): failures.append(str(error_value))
	var inventory := _sealed_inventory()
	var response_fingerprints: Array = []
	var surface_targets := {"casino": [], "street": []}
	for profile_id in BindingScript.PROFILE_IDS:
		var case := _committed_case(profile_id, BindingScript.PROFILE_IDS.find(profile_id) + 1)
		var routed := BindingScript.route_committed_transaction(profile_id, case.get("transaction", {}), case.get("state", {}), inventory)
		if not bool(routed.get("ok", false)) or _array(routed.get("facts", [])).size() != 1 or _array(routed.get("responses", [])).size() != 1:
			failures.append("%s did not route one committed public fact and response: %s" % [profile_id, JSON.stringify(routed)])
			continue
		var response := _dict(_array(routed.get("responses", []))[0])
		var applied := BindingScript.apply_response(response, case.get("transaction", {}), case.get("state", {}), inventory, "phase:craps:%s:1" % profile_id.replace(".", "_"))
		if not bool(applied.get("ok", false)): failures.append("%s response did not apply through its restricted env registry authority: %s" % [profile_id, JSON.stringify(applied.get("errors", []))])
		var fingerprint := str(response.get("response_fingerprint", ""))
		if response_fingerprints.has(fingerprint): failures.append("%s response is not materially distinct" % profile_id)
		response_fingerprints.append(fingerprint)
		for operation_value in response.get("operations", []):
			var operation := _dict(operation_value)
			surface_targets[str(response.get("surface_kind", ""))].append("%s::%s" % [operation.get("owner_namespace", ""), operation.get("stable_object_id", "")])
	if _array(surface_targets.get("casino", [])).is_empty() or _array(surface_targets.get("street", [])).is_empty() or surface_targets["casino"] == surface_targets["street"]:
		failures.append("casino and street response targets are not distinct")
	_check_hostile_authority(inventory)
	if failures.is_empty():
		print("CRAPS06_3_ENVIRONMENT_INTEGRATION PASS profiles=5 distinct_responses=5 hostile_authority=9")
		quit(0)
		return
	for failure in failures: push_error(failure)
	quit(1)


func _check_hostile_authority(inventory: Dictionary) -> void:
	var profile_id := "craps.interrupted_street"
	var original := _committed_case(profile_id, 99)
	var transaction := _dict(original.get("transaction", {}))
	var state := _dict(original.get("state", {}))
	var routed := BindingScript.route_committed_transaction(profile_id, transaction, state, inventory)
	if not bool(routed.get("ok", false)):
		failures.append("hostile authority fixture did not begin valid")
		return
	var altered_payload := _committed_case(profile_id, 99, {"payload_reason": "forged"})
	_assert_rejected("recomputed altered payload", profile_id, altered_payload.get("transaction", {}), state, inventory)
	var altered_receipt := _committed_case(profile_id, 99, {"receipt_id": "craps:fixture:forged:receipt"})
	_assert_rejected("recomputed altered command receipt", profile_id, altered_receipt.get("transaction", {}), state, inventory)
	var altered_boundary := _committed_case(profile_id, 99, {"craps_boundary": "craps.roll.100", "target_boundary": 3})
	_assert_rejected("recomputed altered source/safe boundary", profile_id, altered_boundary.get("transaction", {}), state, inventory)
	var blank_context := transaction.duplicate(true)
	blank_context["context"]["context_instance_id"] = ""
	_assert_rejected("blank context", profile_id, blank_context, state, inventory)
	var substituted_context := _committed_case(profile_id, 99, {"context_instance_id": "other_context"})
	_assert_rejected("substituted context", profile_id, substituted_context.get("transaction", {}), state, inventory)
	var substituted_table := _committed_case(profile_id, 99, {"table_id": "foreign_craps_table"})
	_assert_rejected("substituted table", profile_id, substituted_table.get("transaction", {}), state, inventory)
	_assert_rejected("cross-profile replay", "craps.ordinary_street", transaction, state, inventory)
	var queued := _committed_case(profile_id, 99, {"skip_flush": true})
	_assert_rejected("fact before safe-boundary release", profile_id, queued.get("transaction", {}), queued.get("state", {}), inventory)
	var response := _dict(_array(routed.get("responses", []))[0])
	response["operations"] = [{"family": "actor_ops", "op": "spawn", "receipt_id": "forged_actor", "owner_namespace": "scenario", "stable_object_id": "forged_actor", "actor": {"label": "Forged", "actor_id": "forged", "anchor_id": "street_pressure_approach", "behavior": "idle"}}]
	response.erase("response_fingerprint")
	response["response_fingerprint"] = SequenceRuntimeScript.content_fingerprint(response)
	if bool(BindingScript.apply_response(response, transaction, state, inventory, "phase:craps:hostile:1").get("ok", true)):
		failures.append("recomputed arbitrary registry-valid response operation was accepted")


func _assert_rejected(label: String, profile_id: String, transaction: Dictionary, state: Dictionary, inventory: Dictionary) -> void:
	var result := BindingScript.route_committed_transaction(profile_id, transaction, state, inventory)
	if bool(result.get("ok", true)) or not _array(result.get("facts", [])).is_empty() or not _array(result.get("responses", [])).is_empty(): failures.append("%s did not fail closed" % label)


func _committed_case(profile_id: String, serial: int, overrides: Dictionary = {}) -> Dictionary:
	var binding := BindingScript.profile_binding(profile_id)
	var casino := str(binding.get("surface_kind", "")) == "casino"
	var account_id := "grand_casino_chips" if casino else "player_bankroll"
	var fund_domain := "chips" if casino else "bankroll"
	var table_id := str(overrides.get("table_id", "craps_table_%d" % serial))
	var receipt_id := str(overrides.get("receipt_id", "craps:fixture:roll:%d" % serial))
	var context := HostTransactionScript.public_context("craps_node", "visit_%d" % serial, "night_1", str(overrides.get("context_instance_id", "context_%d" % serial)))
	var initial_table := {"producer_id": "craps", "game_id": "craps", "active": true, "ritual_sequence": serial - 1, "prepared_account_id": account_id}
	var replacement := {"producer_id": "craps", "game_id": "craps", "active": true, "ritual_sequence": serial, "prepared_account_id": account_id}
	var initial := HostTransactionScript.initial_state({account_id: {"fund_domain": fund_domain, "balance": 100}}, {table_id: initial_table}, {})
	var expected_boundary := str(overrides.get("craps_boundary", "craps.roll.%d" % serial))
	var local_type := str(binding.get("response_fact", "")).trim_prefix("craps.")
	var payload := {
		"ritual_package_id": "craps06_3_sequences", "ritual_profile_id": profile_id,
		"craps_fact_id": "craps.%s.%d" % [local_type, serial], "craps_boundary": expected_boundary,
		"craps_receipt_key": "craps.fact.%d.%s" % [serial, local_type],
		"craps_public_payload": {"reason": str(overrides.get("payload_reason", "sweep")), "point": 6, "streak": 2},
	}
	var target_boundary := int(overrides.get("target_boundary", 4))
	var fact := HostTransactionScript.game_fact(str(binding.get("response_fact", "")).replace(".", "_"), "craps", "craps", table_id, context, receipt_id, "scenario:craps:fact:%d" % serial, target_boundary, payload)
	var command := HostTransactionScript.game_command("craps", "craps", table_id, receipt_id, context, HostTransactionScript.state_digest(initial_table), replacement, {"facts": [fact]})
	var transaction := HostTransactionScript.reduce_game_command(initial, command)
	if not bool(transaction.get("ok", false)):
		failures.append("could not prepare authoritative fixture %s: %s" % [profile_id, JSON.stringify(transaction.get("errors", []))])
		return {"transaction": transaction, "state": initial}
	var committed := HostTransactionScript.commit_game_command(initial, transaction)
	if not bool(committed.get("ok", false)):
		failures.append("could not commit authoritative fixture %s: %s" % [profile_id, JSON.stringify(committed.get("errors", []))])
		return {"transaction": transaction, "state": initial}
	var state := _dict(committed.get("state", {}))
	if not bool(overrides.get("skip_flush", false)):
		var flushed := HostTransactionScript.flush_game_facts(state, target_boundary)
		if not bool(flushed.get("ok", false)): failures.append("could not release fixture at safe boundary")
		state = _dict(flushed.get("state", {}))
	return {"transaction": transaction, "state": state}


func _sealed_inventory() -> Dictionary:
	return InventoryScript.for_instance({
		"id": "craps_binding_fixture", "current_layer_id": "", "layout": {"object_rects": {}}, "semantic_zones": {},
		"semantic_anchors": {
			"craps_table_north": {"position": [500, 100]}, "craps_rail": {"position": [850, 250]},
			"craps_security_rail": {"position": [900, 300]}, "street_lookout_post": {"position": [120, 300]},
			"street_pressure_approach": {"position": [880, 400]},
		},
		"travel_hooks": ["street_exit"],
	})


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
