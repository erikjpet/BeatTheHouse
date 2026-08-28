extends SceneTree

const BindingScript := preload("res://scripts/core/craps06_3_environment_binding.gd")
const HostTransactionScript := preload("res://scripts/core/scenario_host_transaction.gd")
const InventoryScript := preload("res://scripts/core/environment_semantic_inventory.gd")
const SequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")

var failures: Array[String] = []


func _init() -> void:
	for error_value in BindingScript.validate_registration(): failures.append(str(error_value))
	var context := HostTransactionScript.public_context("craps_node", "visit_1", "night_1", "craps_context_1")
	context["table_id"] = "craps_table"
	var inventory := _sealed_inventory()
	var response_fingerprints: Array = []
	var surface_targets := {"casino": [], "street": []}
	for profile_id in BindingScript.PROFILE_IDS:
		var binding := BindingScript.profile_binding(profile_id)
		var fact := _public_fact(str(binding.get("response_fact", "")), BindingScript.PROFILE_IDS.find(profile_id) + 1)
		var routed := BindingScript.route_public_facts(profile_id, [fact], context, 4, inventory)
		if not bool(routed.get("ok", false)) or (routed.get("facts", []) as Array).size() != 1 or (routed.get("responses", []) as Array).size() != 1:
			failures.append("%s did not route one authenticated public fact and response: %s" % [profile_id, JSON.stringify(routed)])
			continue
		var host_fact: Dictionary = (routed.get("facts", []) as Array)[0]
		if str(host_fact.get("producer_id", "")) != "craps" or str(host_fact.get("game_id", "")) != "craps" or not str(host_fact.get("fact_type", "")).begins_with("craps_"):
			failures.append("%s bypassed the accepted game fact envelope" % profile_id)
		var response: Dictionary = (routed.get("responses", []) as Array)[0]
		var applied := BindingScript.apply_response(response, inventory, "phase:craps:%s:1" % profile_id.replace(".", "_"))
		if not bool(applied.get("ok", false)):
			failures.append("%s response did not apply through the env operation registry: %s" % [profile_id, JSON.stringify(applied.get("errors", []))])
		var fingerprint := SequenceRuntimeScript.content_fingerprint(response.get("operations", []))
		if response_fingerprints.has(fingerprint): failures.append("%s response is not materially distinct" % profile_id)
		response_fingerprints.append(fingerprint)
		var kind := str(response.get("surface_kind", ""))
		for operation_value in response.get("operations", []):
			var operation: Dictionary = operation_value
			surface_targets[kind].append("%s::%s" % [operation.get("owner_namespace", ""), operation.get("stable_object_id", "")])
	if (surface_targets["casino"] as Array).is_empty() or (surface_targets["street"] as Array).is_empty() or surface_targets["casino"] == surface_targets["street"]:
		failures.append("casino and street response targets are not distinct")
	_check_fail_closed(context, inventory)
	if failures.is_empty():
		print("CRAPS06_3_ENVIRONMENT_INTEGRATION PASS profiles=5 distinct_responses=5")
		quit(0)
		return
	for failure in failures: push_error(failure)
	quit(1)


func _check_fail_closed(context: Dictionary, inventory: Dictionary) -> void:
	var binding := BindingScript.profile_binding("craps.interrupted_street")
	var fact := _public_fact(str(binding.get("response_fact", "")), 99)
	var missing_route := inventory.duplicate(true)
	var guaranteed: Dictionary = missing_route.get("guaranteed", {})
	(guaranteed.get("routes", []) as Array).erase("base::world:street_exit")
	missing_route["guaranteed"] = guaranteed
	var rejected := BindingScript.route_public_facts("craps.interrupted_street", [fact], context, 4, missing_route)
	if bool(rejected.get("ok", false)) or not (rejected.get("facts", []) as Array).is_empty() or not (rejected.get("responses", []) as Array).is_empty():
		failures.append("missing/tampered sealed route authority did not fail closed")
	var forged := fact.duplicate(true)
	forged["payload"] = {"reason": "forged"}
	var forged_result := BindingScript.route_public_facts("craps.interrupted_street", [forged], context, 4, inventory)
	if bool(forged_result.get("ok", false)) or not (forged_result.get("facts", []) as Array).is_empty():
		failures.append("changed craps fact content reused an old fingerprint")


func _sealed_inventory() -> Dictionary:
	return InventoryScript.for_instance({
		"id": "craps_binding_fixture",
		"current_layer_id": "",
		"layout": {"object_rects": {}},
		"semantic_zones": {},
		"semantic_anchors": {
			"craps_table_north": {"position": [500, 100]},
			"craps_rail": {"position": [850, 250]},
			"craps_security_rail": {"position": [900, 300]},
			"street_lookout_post": {"position": [120, 300]},
			"street_pressure_approach": {"position": [880, 400]}
		},
		"travel_hooks": ["street_exit"]
	})


func _public_fact(fact_type: String, serial: int) -> Dictionary:
	var local_type := fact_type.trim_prefix("craps.")
	var fact := {
		"fact_id": "craps.%s.%d" % [local_type, serial], "fact_type": fact_type,
		"fact_version": 1, "visibility": "public", "boundary": "craps.roll.%d" % serial,
		"cause": "action_resolution", "payload": {"point": 6, "reason": "sweep", "streak": 2, "method": "switch_dice"},
		"receipt_key": "craps.fact.%d.%s" % [serial, local_type]
	}
	fact["content_fingerprint"] = SequenceRuntimeScript.content_fingerprint(fact)
	return fact
