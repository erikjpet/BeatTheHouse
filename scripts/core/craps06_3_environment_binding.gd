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
	if int(source.get("schema_version", 0)) != 1:
		errors.append("craps environment binding schema must be 1")
	if str(source.get("ritual_package_id", "")) != "craps06_3_sequences":
		errors.append("craps environment binding names the wrong ritual package")
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
		if str(binding.get("surface_kind", "")) not in ["casino", "street"]: errors.append("%s has invalid surface_kind" % profile_id)
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


static func route_public_facts(profile_id: String, facts: Array, context: Dictionary, target_boundary: int, sealed_inventory: Dictionary) -> Dictionary:
	var binding := profile_binding(profile_id)
	var errors := validate_registration()
	if binding.is_empty(): errors.append("unknown craps ritual profile %s" % profile_id)
	errors.append_array(InventoryScript.validate(sealed_inventory))
	var exact := InventoryScript.exact_collections(sealed_inventory) if errors.is_empty() else {}
	for collection_value in _dict(binding.get("required_inventory", {})).keys():
		var collection := str(collection_value)
		for identity_value in _array(_dict(binding.get("required_inventory", {})).get(collection, [])):
			if not _array(exact.get(collection, [])).has(str(identity_value)):
				errors.append("sealed inventory lacks %s target %s" % [collection, identity_value])
	if not errors.is_empty(): return {"ok": false, "facts": [], "responses": [], "errors": errors}
	var routed: Array = []
	var responses: Array = []
	for fact_value in facts:
		if typeof(fact_value) != TYPE_DICTIONARY:
			errors.append("craps public fact must be a dictionary")
			break
		var fact := (fact_value as Dictionary).duplicate(true)
		var expected_fingerprint := str(fact.get("content_fingerprint", ""))
		fact.erase("content_fingerprint")
		if str(fact.get("visibility", "")) != "public" or int(fact.get("fact_version", 0)) != 1 or not str(fact.get("fact_type", "")).begins_with("craps."):
			errors.append("craps public fact envelope is invalid")
			break
		if SequenceRuntimeScript.content_fingerprint(fact) != expected_fingerprint:
			errors.append("craps public fact fingerprint mismatch")
			break
		var local_type := str(fact.get("fact_type", "")).trim_prefix("craps.")
		var host_fact := HostTransactionScript.game_fact(
			"craps_%s" % local_type, "craps", "craps", str(context.get("table_id", "")), context,
			str(fact.get("receipt_key", "")), "scenario:%s" % str(fact.get("receipt_key", "")).replace(".", ":"), target_boundary,
			_dict(fact.get("payload", {})).merged({"craps_fact_id": str(fact.get("fact_id", "")), "craps_boundary": str(fact.get("boundary", ""))}, true)
		)
		routed.append(host_fact)
		if str(fact.get("fact_type", "")) == str(binding.get("response_fact", "")):
			responses.append({"profile_id": profile_id, "surface_kind": str(binding.get("surface_kind", "")), "fact_id": str(fact.get("fact_id", "")), "operations": _array(binding.get("operations", []))})
	if not errors.is_empty(): return {"ok": false, "facts": [], "responses": [], "errors": errors}
	return {"ok": true, "facts": routed, "responses": responses, "errors": []}


static func apply_response(response: Dictionary, sealed_inventory: Dictionary, boundary_id: String) -> Dictionary:
	var inventory_errors := InventoryScript.validate(sealed_inventory)
	if not inventory_errors.is_empty(): return {"ok": false, "state": {}, "errors": inventory_errors}
	var exact := InventoryScript.exact_collections(sealed_inventory)
	var state: Dictionary = {"declared_targets": exact.duplicate(true), "target_inventory": exact.duplicate(true)}
	for operation_value in _array(response.get("operations", [])):
		var operation := _dict(operation_value)
		var family := str(operation.get("family", ""))
		var applied := OperationRegistryScript.apply_operations(state, family, [operation], boundary_id)
		if not bool(applied.get("ok", false)): return {"ok": false, "state": {}, "errors": _array(applied.get("errors", []))}
		state = _dict(applied.get("state", {}))
	return {"ok": true, "state": state, "errors": []}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
