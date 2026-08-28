class_name Craps06EnvironmentBinding
extends RefCounted

const CONFIG_PATH := "res://data/games/rituals/craps06_3_environment_bindings.json"
const RITUAL_PATH := "res://data/games/rituals/craps06_3_sequences.json"
const HostTransactionScript := preload("res://scripts/core/scenario_host_transaction.gd")
const InventoryScript := preload("res://scripts/core/environment_semantic_inventory.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const SequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")

const PROFILE_IDS := [
	"craps.ordinary_casino", "craps.hot_high_stakes", "craps.security_audit",
	"craps.ordinary_street", "craps.interrupted_street",
]


static func config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if typeof(parsed) != TYPE_ARRAY or (parsed as Array).size() != 1 or typeof((parsed as Array)[0]) != TYPE_DICTIONARY:
		return {}
	return ((parsed as Array)[0] as Dictionary).duplicate(true)


static func profile_binding(profile_id: String) -> Dictionary:
	for value in _array(config().get("profiles", [])):
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("profile_id", "")) == profile_id:
			return (value as Dictionary).duplicate(true)
	return {}


static func validate_registration() -> Array:
	var errors: Array = []
	var source := config()
	if int(source.get("schema_version", 0)) != 1: errors.append("craps environment binding schema must be 1")
	if str(source.get("ritual_package_id", "")) != "craps06_3_sequences": errors.append("craps environment binding names the wrong ritual package")
	var ritual: Variant = JSON.parse_string(FileAccess.get_file_as_string(RITUAL_PATH))
	var ritual_record: Dictionary = (ritual as Array)[0] if typeof(ritual) == TYPE_ARRAY and not (ritual as Array).is_empty() and typeof((ritual as Array)[0]) == TYPE_DICTIONARY else {}
	var ritual_ids: Array = []
	for value in _array(ritual_record.get("profiles", [])):
		if typeof(value) == TYPE_DICTIONARY: ritual_ids.append(str((value as Dictionary).get("id", "")))
	var seen: Array = []
	var fingerprints: Array = []
	for value in _array(source.get("profiles", [])):
		if typeof(value) != TYPE_DICTIONARY:
			errors.append("craps environment profile binding must be a dictionary")
			continue
		var binding := value as Dictionary
		var profile_id := str(binding.get("profile_id", ""))
		seen.append(profile_id)
		if not ritual_ids.has(profile_id): errors.append("craps environment binding references unknown ritual profile %s" % profile_id)
		var surface_kind := str(binding.get("surface_kind", ""))
		if surface_kind not in ["casino", "street"]: errors.append("%s has invalid surface_kind" % profile_id)
		var fund_domain := str(binding.get("authoritative_fund_domain", ""))
		if fund_domain != ("chips" if surface_kind == "casino" else "bankroll"): errors.append("%s has invalid authored table authority" % profile_id)
		if not str(binding.get("response_fact", "")).begins_with("craps."): errors.append("%s has invalid response_fact" % profile_id)
		var required := _dict(binding.get("required_inventory", {}))
		for collection in required.keys():
			if str(collection) not in InventoryScript.COLLECTION_KEYS: errors.append("%s has unknown inventory collection %s" % [profile_id, collection])
			for identity_value in _array(required.get(collection, [])):
				if OperationRegistryScript.parse_owned_identity(str(identity_value)).is_empty(): errors.append("%s has invalid owned target %s" % [profile_id, identity_value])
		for operation_value in _array(binding.get("operations", [])):
			if typeof(operation_value) != TYPE_DICTIONARY:
				errors.append("%s contains a non-dictionary operation" % profile_id)
				continue
			errors.append_array(OperationRegistryScript.validate_any_operation(operation_value as Dictionary))
		var fingerprint := SequenceRuntimeScript.content_fingerprint(binding)
		if fingerprints.has(fingerprint): errors.append("craps environment profiles must have distinct material responses")
		fingerprints.append(fingerprint)
	if seen != PROFILE_IDS: errors.append("craps environment binding profile order/identity changed: %s" % JSON.stringify(seen))
	return errors


# Only facts already committed by ScenarioHostTransaction and released at its
# safe boundary can reach environment response selection. The prepared
# transaction remains the immutable proof of table/context/result provenance.
static func route_committed_transaction(profile_id: String, prepared_transaction: Dictionary, committed_host_state: Dictionary, sealed_inventory: Dictionary) -> Dictionary:
	var binding := profile_binding(profile_id)
	var errors := validate_registration()
	if binding.is_empty(): errors.append("unknown craps ritual profile %s" % profile_id)
	errors.append_array(InventoryScript.validate(sealed_inventory))
	var exact := InventoryScript.exact_collections(sealed_inventory) if errors.is_empty() else {}
	for collection_value in _dict(binding.get("required_inventory", {})).keys():
		var collection := str(collection_value)
		for identity_value in _array(_dict(binding.get("required_inventory", {})).get(collection, [])):
			if not _array(exact.get(collection, [])).has(str(identity_value)): errors.append("sealed inventory lacks %s target %s" % [collection, identity_value])
	errors.append_array(_transaction_authority_errors(profile_id, binding, prepared_transaction, committed_host_state))
	if not errors.is_empty(): return {"ok": false, "facts": [], "responses": [], "errors": errors}
	var routed: Array = []
	var responses: Array = []
	for fact_value in _array(prepared_transaction.get("facts", [])):
		var fact := _dict(fact_value)
		var payload := _dict(fact.get("payload", {}))
		if str(payload.get("ritual_profile_id", "")) != profile_id: continue
		routed.append(fact.duplicate(true))
		if str(fact.get("fact_type", "")) == str(binding.get("response_fact", "")).replace(".", "_"):
			var response := _catalog_response(binding, prepared_transaction, fact)
			responses.append(response)
	return {"ok": true, "facts": routed, "responses": responses, "errors": []}


static func apply_response(response: Dictionary, prepared_transaction: Dictionary, committed_host_state: Dictionary, sealed_inventory: Dictionary, boundary_id: String) -> Dictionary:
	var profile_id := str(response.get("profile_id", ""))
	var binding := profile_binding(profile_id)
	var errors := validate_registration()
	errors.append_array(InventoryScript.validate(sealed_inventory))
	errors.append_array(_transaction_authority_errors(profile_id, binding, prepared_transaction, committed_host_state))
	var expected: Dictionary = {}
	for fact_value in _array(prepared_transaction.get("facts", [])):
		var fact := _dict(fact_value)
		if str(fact.get("fact_type", "")) == str(binding.get("response_fact", "")).replace(".", "_") and str(_dict(fact.get("payload", {})).get("ritual_profile_id", "")) == profile_id:
			expected = _catalog_response(binding, prepared_transaction, fact)
			break
	if expected.is_empty() or response != expected: errors.append("environment response is not the exact immutable catalog response emitted for this committed fact")
	if not errors.is_empty(): return {"ok": false, "state": {}, "errors": errors}
	var restricted := _empty_collections()
	for collection_value in _dict(binding.get("required_inventory", {})).keys():
		restricted[str(collection_value)] = _array(_dict(binding.get("required_inventory", {})).get(collection_value, []))
	var state: Dictionary = {"declared_targets": restricted.duplicate(true), "target_inventory": restricted.duplicate(true)}
	for operation_value in _array(binding.get("operations", [])):
		var operation := _dict(operation_value)
		var applied := OperationRegistryScript.apply_operations(state, str(operation.get("family", "")), [operation], boundary_id)
		if not bool(applied.get("ok", false)): return {"ok": false, "state": {}, "errors": _array(applied.get("errors", []))}
		state = _dict(applied.get("state", {}))
	return {"ok": true, "state": state, "errors": []}


static func _transaction_authority_errors(profile_id: String, binding: Dictionary, transaction: Dictionary, host_state: Dictionary) -> Array:
	var errors: Array = []
	if binding.is_empty(): return ["profile has no authored environment binding"]
	var receipt_id := str(transaction.get("receipt_id", ""))
	var table_id := str(transaction.get("table_id", ""))
	var context := _dict(transaction.get("context", {}))
	if not bool(transaction.get("ok", false)) or str(transaction.get("producer_id", "")) != "craps" or str(transaction.get("game_id", "")) != "craps": errors.append("environment routing requires a prepared Craps host transaction")
	if receipt_id.is_empty() or table_id.is_empty(): errors.append("prepared transaction requires authoritative command receipt and table identity")
	for key in ["node_id", "environment_visit_id", "night_instance_id", "context_instance_id"]:
		if str(context.get(key, "")).strip_edges().is_empty(): errors.append("prepared transaction context lacks %s authority" % key)
	var receipts := _dict(host_state.get("authoritative_receipts", {}))
	if str(receipts.get(receipt_id, "")) != str(transaction.get("fingerprint", "")) or str(transaction.get("fingerprint", "")).is_empty(): errors.append("prepared transaction is not bound to the committed authoritative receipt")
	var result := _dict(_dict(host_state.get("receipt_results", {})).get(receipt_id, {}))
	if str(result.get("kind", "")) != "game_command" or str(result.get("table_id", "")) != table_id or _array(result.get("facts", [])) != _array(transaction.get("facts", [])): errors.append("committed receipt result does not match the prepared transaction")
	var table := _dict(_dict(host_state.get("table_states", {})).get(table_id, {}))
	if table.is_empty() or str(table.get("producer_id", "")) != "craps" or str(table.get("game_id", "")) != "craps" or table != _dict(transaction.get("replacement_table_state", {})): errors.append("committed table ownership/state does not match the prepared transaction")
	var prepared_account_id := str(table.get("prepared_account_id", ""))
	var prepared_account := _dict(_dict(host_state.get("accounts", {})).get(prepared_account_id, {}))
	if prepared_account_id.is_empty() or str(prepared_account.get("fund_domain", "")) != str(binding.get("authoritative_fund_domain", "")): errors.append("profile is not authorized for this prepared table/account context")
	var expected_boundary := "craps.roll.%d" % int(table.get("ritual_sequence", -1))
	var safe_boundary := int(host_state.get("safe_boundary", -1))
	var log := _array(host_state.get("fact_log", []))
	for fact_value in _array(transaction.get("facts", [])):
		var fact := _dict(fact_value)
		var payload := _dict(fact.get("payload", {}))
		if str(fact.get("producer_id", "")) != "craps" or str(fact.get("game_id", "")) != "craps" or str(fact.get("table_id", "")) != table_id or _dict(fact.get("context", {})) != context: errors.append("committed Craps fact has foreign table/context ownership")
		if str(fact.get("producer_receipt", "")) != receipt_id: errors.append("committed Craps fact is not bound to the authoritative command receipt")
		if str(payload.get("ritual_package_id", "")) != str(config().get("ritual_package_id", "")) or str(payload.get("ritual_profile_id", "")) != profile_id: errors.append("committed Craps fact is not bound to the selected authored profile")
		if str(payload.get("craps_boundary", "")) != expected_boundary or int(fact.get("target_boundary", -1)) > safe_boundary: errors.append("committed Craps fact lacks the exact safe-boundary source binding")
		if not _logged_fact(log, fact): errors.append("prepared Craps fact was not released by the committed host safe boundary")
	return errors


static func _logged_fact(log: Array, prepared_fact: Dictionary) -> bool:
	for value in log:
		var logged := _dict(value)
		logged["commit_order"] = 0
		if logged == prepared_fact: return true
	return false


static func _catalog_response(binding: Dictionary, transaction: Dictionary, fact: Dictionary) -> Dictionary:
	var response := {
		"profile_id": str(binding.get("profile_id", "")),
		"ritual_package_id": str(config().get("ritual_package_id", "")),
		"surface_kind": str(binding.get("surface_kind", "")),
		"command_receipt": str(transaction.get("receipt_id", "")),
		"transaction_fingerprint": str(transaction.get("fingerprint", "")),
		"fact_receipt": str(fact.get("scenario_receipt", "")),
		"binding_fingerprint": SequenceRuntimeScript.content_fingerprint(binding),
		"operations": _array(binding.get("operations", [])),
	}
	response["response_fingerprint"] = SequenceRuntimeScript.content_fingerprint(response)
	return response


static func _empty_collections() -> Dictionary:
	var result: Dictionary = {}
	for key in InventoryScript.COLLECTION_KEYS: result[str(key)] = []
	return result


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
