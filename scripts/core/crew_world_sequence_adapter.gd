class_name CrewWorldSequenceAdapter
extends RefCounted

# Source-neutral composition seam for environment, crew, and world sequences.
# Every mounted owner retains an independent ScenarioSequenceRuntime state. The
# adapter owns only registration, composition and outcome delivery receipts;
# authored sequence behavior remains in the shared env06_6 schema/runtime.

const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const SequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const SequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")

const CONTAINER_KEY := "world_sequence_instances"
const CONTAINER_SCHEMA_VERSION := 1
const REGISTRATION_SCHEMA_VERSION := 1
const RESERVED_ENVIRONMENT_OWNER_TOKEN := "scenario::environment::active::primary"
const SOURCE_DOMAINS := ["crew", "world"]
const LIFECYCLE_ACTIVE := "active"
const LIFECYCLE_CLEANUP_PENDING := "cleanup_pending"
const LIFECYCLE_CLEANED := "cleaned"
const PROJECTION_COLLECTIONS := ["scene_objects", "interactions", "actors", "services", "games", "routes"]
const HIDDEN_IDENTIFIER_TERMS := [
	"betrayal", "clue", "grievance", "mole", "rat", "snitch", "theturn", "traitor", "turncoat",
]
const HASH_IDENTIFIER_LENGTHS := [32, 40, 64]
# Machine-checks the frozen EventModule seam against both the production event
# catalog and the exact routing syntax used by EventModule. Additions are errors,
# not silently accepted inventory growth.
static func validate_frozen_event_module_inventory(event_catalog: Array, event_module_source: String, frozen_inventory: Dictionary) -> Array:
	var actual_events: Array = []
	for event_value in event_catalog:
		var event := _dict(event_value)
		var event_id := str(event.get("id", "")).strip_edges()
		if _is_event_module_surface_id(event_id) and not actual_events.has(event_id): actual_events.append(event_id)
	var actual_kinds := _source_comparison_literals(event_module_source, 'payload.get("kind"', '== "')
	var actual_direct := _source_comparison_literals(event_module_source, "get_id()", '== "')
	var actual_hooks: Array = []
	for line in event_module_source.split("\n"):
		var trimmed := str(line).strip_edges()
		if not trimmed.begins_with('"crew_') or not trimmed.ends_with('":') or trimmed.count('"') != 2: continue
		var hook_id := trimmed.trim_prefix('"').trim_suffix('":')
		if not actual_hooks.has(hook_id): actual_hooks.append(hook_id)
	var diagnostics: Array = []
	_append_inventory_difference(diagnostics, "event_catalog", actual_events, _array(frozen_inventory.get("event_catalog", [])))
	_append_inventory_difference(diagnostics, "dynamic_kind", actual_kinds, _array(frozen_inventory.get("dynamic_kind", [])))
	_append_inventory_difference(diagnostics, "direct_surface", actual_direct, _array(frozen_inventory.get("direct_surface", [])))
	_append_inventory_difference(diagnostics, "event_hook", actual_hooks, _array(frozen_inventory.get("event_hook", [])))
	return _sorted_diagnostics(diagnostics)


# Wraps unchanged shared-validator messages when they are safe. A path-bearing
# or hidden-bearing message is replaced rather than echoed into public reports.
static func wrap_validation_errors(source_kind: String, source_id: String, definition_id: String, instance_id: String, errors: Array) -> Array:
	var safe_source := _safe_diagnostic_identifier(source_id)
	var safe_definition := _safe_diagnostic_identifier(definition_id)
	var safe_instance := _safe_diagnostic_identifier(instance_id)
	var result: Array = []
	for error_value in errors:
		var shared_error := str(error_value)
		var safe_error := shared_error if _safe_diagnostic_message(shared_error) else "Shared validator rejected authored content."
		var identity := "%s\n%s\n%s\n%s\n%s" % [source_kind, safe_source, safe_definition, safe_instance, safe_error]
		result.append({
			"error_id": "world_sequence_validation_%s" % identity.sha256_text().substr(0, 16),
			"source_kind": source_kind,
			"source_id": safe_source,
			"definition_id": safe_definition,
			"instance_id": safe_instance,
			"error": safe_error,
		})
	return _sorted_diagnostics(result)


# Checks only identifiers and identifier collections. Narrative labels, prompts,
# and feedback remain ordinary prose and are intentionally not inspected.
static func validate_public_identifiers(value: Variant) -> Array:
	var failures: Array = []
	_collect_hidden_identifier_failures(value, "", failures)
	return _unique_strings(failures)


static func owner_token(source: Dictionary, public_instance_token: String) -> String:
	var domain := str(source.get("domain", "")).strip_edges()
	var owner_id := str(source.get("owner_id", "")).strip_edges()
	var definition_id := str(source.get("definition_id", "")).strip_edges()
	var instance_id := public_instance_token.strip_edges()
	if not SOURCE_DOMAINS.has(domain) or not _valid_component(owner_id) or not _valid_component(definition_id) or not _valid_component(instance_id):
		return ""
	return "%s::%s::%s::%s" % [domain, owner_id, definition_id, instance_id]


# Eligibility is deliberately pure. Calling this on a crew-ignoring run does
# not create a container, registration marker, cache entry, or scan receipt.
static func eligibility(environment: Dictionary, source: Dictionary, public_instance_token: String, mount_selector: Dictionary) -> Dictionary:
	var token := owner_token(source, public_instance_token)
	var errors := _mount_selector_errors(environment, mount_selector)
	if token.is_empty():
		errors.append("world sequence source and public instance token must be canonical")
	return {"eligible": errors.is_empty(), "owner_token": token, "errors": errors}


static func mount(environment: Dictionary, source: Dictionary, public_instance_token: String, mount_selector: Dictionary, definition: Dictionary, outcome_channels: Dictionary, ownership_claims: Array, registered_outcome_channels: Array, seed_token: String = "") -> Dictionary:
	var eligibility_result := eligibility(environment, source, public_instance_token, mount_selector)
	var errors: Array = _array(eligibility_result.get("errors", []))
	var token := str(eligibility_result.get("owner_token", ""))
	errors.append_array(validate_public_identifiers({
		"source": source,
		"public_instance_token": public_instance_token,
		"mount_selector": mount_selector,
		"definition": definition,
		"outcome_channels": outcome_channels,
		"ownership_claims": ownership_claims,
	}))
	var host_semantics := ScenarioEngineScript.sequence_host_semantics(environment)
	var creation_owners := _definition_creation_owner_namespaces(definition)
	host_semantics["creation_owner_namespaces"] = creation_owners
	var target_inventory := _dict(host_semantics.get("target_inventory", {}))
	target_inventory["event_choices"] = _dict(host_semantics.get("event_choices", {}))
	errors.append_array(SequenceSchemaScript.validate_definition(definition, OperationRegistryScript, target_inventory))
	errors.append_array(_source_definition_errors(source, definition))
	errors.append_array(_creation_owner_errors(source, creation_owners))
	errors.append_array(_outcome_channel_errors(definition, outcome_channels, registered_outcome_channels))
	var claims := _normalized_claims(ownership_claims, errors)
	var container := _container(environment)
	errors.append_array(_ownership_conflicts(token, claims, container, definition_claims(_dict(environment.get("scenario_sequence_definition", {})))))
	if not errors.is_empty():
		return {"ok": false, "owner_token": token, "errors": _unique_strings(errors)}
	var definition_fingerprint := SequenceRuntimeScript.content_fingerprint(definition)
	if container.has(token):
		var existing := _dict(container.get(token, {}))
		if str(existing.get("definition_fingerprint", "")) != definition_fingerprint:
			return {"ok": false, "owner_token": token, "errors": ["world sequence owner token is already bound to different authored content"]}
		var rebound := _rehydrate_entry(existing, definition, host_semantics)
		if not bool(rebound.get("ok", false)):
			return {"ok": false, "owner_token": token, "errors": _array(rebound.get("errors", []))}
		container[token] = _dict(rebound.get("entry", existing))
		environment[CONTAINER_KEY] = container
		return {"ok": true, "replayed": true, "owner_token": token, "registration_marker": str(existing.get("registration_marker", "")), "errors": []}
	var node_id := str(mount_selector.get("node_id", "")).strip_edges()
	var state := SequenceRuntimeScript.initial_state(definition, node_id, seed_token, host_semantics)
	var state_errors := _array(state.get("errors", []))
	if state.is_empty() or str(state.get("status", "")) == SequenceRuntimeScript.STATUS_CLEANED or not state_errors.is_empty():
		return {"ok": false, "owner_token": token, "errors": state_errors if not state_errors.is_empty() else ["world sequence shared runtime rejected initial state"]}
	var marker := SequenceRuntimeScript.content_fingerprint({
		"schema_version": REGISTRATION_SCHEMA_VERSION,
		"owner_token": token,
		"node_id": node_id,
		"definition_fingerprint": definition_fingerprint,
	})
	var entry := {
		"schema_version": REGISTRATION_SCHEMA_VERSION,
		"owner_token": token,
		"source": _public_source(source),
		"public_instance_token": public_instance_token,
		"node_id": node_id,
		"mount_selector": {"node_id": node_id, "zone_id": str(mount_selector.get("zone_id", "")).strip_edges()},
		"definition_fingerprint": definition_fingerprint,
		"registration_marker": marker,
		"lifecycle": LIFECYCLE_ACTIVE,
		"state": state,
		"ownership_claims": claims,
		"outcome_channels": outcome_channels.duplicate(true),
		"outcome_receipts": {},
		"outcome_acknowledgements": {},
	}
	container[token] = entry
	environment[CONTAINER_KEY] = container
	return {"ok": true, "replayed": false, "owner_token": token, "registration_marker": marker, "projection": SequenceRuntimeScript.public_projection(state, definition), "errors": []}


static func snapshot(environment: Dictionary, token: String, definition: Dictionary = {}) -> Dictionary:
	var entry := _dict(_container(environment).get(token, {}))
	if entry.is_empty():
		return {}
	var result := {
		"schema_version": int(entry.get("schema_version", 0)),
		"owner_token": str(entry.get("owner_token", "")),
		"source": _public_source(_dict(entry.get("source", {}))),
		"public_instance_token": str(entry.get("public_instance_token", "")),
		"node_id": str(entry.get("node_id", "")),
		"registration_marker": str(entry.get("registration_marker", "")),
		"lifecycle": str(entry.get("lifecycle", "")),
		"outcome_receipts": _dict(entry.get("outcome_receipts", {})),
		"outcome_acknowledgements": _dict(entry.get("outcome_acknowledgements", {})),
	}
	if SequenceSchemaScript.is_sequence(definition):
		result["projection"] = SequenceRuntimeScript.public_projection(_dict(entry.get("state", {})), definition)
	return result


static func projection(environment: Dictionary, token: String, definition: Dictionary) -> Dictionary:
	var entry := _dict(_container(environment).get(token, {}))
	if entry.is_empty() or not SequenceSchemaScript.is_sequence(definition):
		return {}
	var rebound := _rehydrate_entry(entry, definition, ScenarioEngineScript.sequence_host_semantics(environment))
	if not bool(rebound.get("ok", false)):
		return {}
	return SequenceRuntimeScript.public_projection(_dict(_dict(rebound.get("entry", {})).get("state", {})), definition)


static func execute(environment: Dictionary, token: String, definition: Dictionary, command: Dictionary, public_context: Dictionary = {}) -> Dictionary:
	return _apply_runtime_result(environment, token, definition, func(state: Dictionary) -> Dictionary:
		var sealed_command := _sealed_command(state, command)
		if sealed_command.is_empty():
			return {"ok": false, "state": state, "errors": ["world sequence command is not bound to a sealed interaction action"]}
		return SequenceRuntimeScript.apply_command(state, definition, sealed_command, _public_command_context(public_context))
	)


static func enqueue_fact(environment: Dictionary, token: String, definition: Dictionary, fact: Dictionary) -> Dictionary:
	return _apply_runtime_result(environment, token, definition, func(state: Dictionary) -> Dictionary:
		return SequenceRuntimeScript.enqueue_fact(state, definition, fact)
	)


static func flush_facts(environment: Dictionary, token: String, definition: Dictionary, boundary_serial: int) -> Dictionary:
	return _apply_runtime_result(environment, token, definition, func(state: Dictionary) -> Dictionary:
		return SequenceRuntimeScript.flush_facts(state, definition, boundary_serial)
	)


static func record_visit(environment: Dictionary, token: String, definition: Dictionary, visit_id: String) -> Dictionary:
	return _apply_runtime_result(environment, token, definition, func(state: Dictionary) -> Dictionary:
		return SequenceRuntimeScript.record_visit(state, definition, visit_id)
	)


static func apply_reentry(environment: Dictionary, token: String, definition: Dictionary, visit_id: String) -> Dictionary:
	var host := ScenarioEngineScript.sequence_host_semantics(environment)
	return _apply_runtime_result(environment, token, definition, func(state: Dictionary) -> Dictionary:
		return SequenceRuntimeScript.apply_reentry(state, definition, visit_id, host)
	)


static func apply_expiry_boundary(environment: Dictionary, token: String, definition: Dictionary, boundary: String, amount: int = 1) -> Dictionary:
	return _apply_runtime_result(environment, token, definition, func(state: Dictionary) -> Dictionary:
		return SequenceRuntimeScript.apply_expiry_boundary(state, definition, boundary, amount)
	)


# Owner lifecycle sync is the only automatic cleanup ingress. The caller must
# provide the owning model's public active bit; the adapter never inspects model
# internals or polls when no persisted registration marker exists.
static func sync_owner(environment: Dictionary, token: String, definition: Dictionary, owner_active: bool, reason: String = "owner_ended") -> Dictionary:
	var entry := _dict(_container(environment).get(token, {}))
	if entry.is_empty():
		return {"ok": true, "inactive": true, "errors": []}
	if owner_active:
		return {"ok": true, "inactive": false, "unchanged": true, "errors": []}
	if reason in ["expired", "abandoned"]:
		return _apply_runtime_result(environment, token, definition, func(state: Dictionary) -> Dictionary:
			return SequenceRuntimeScript.apply_owner_lifecycle_outcome(state, definition, reason, reason)
		, LIFECYCLE_CLEANUP_PENDING)
	return _apply_runtime_result(environment, token, definition, func(state: Dictionary) -> Dictionary:
		return SequenceRuntimeScript._apply_cleanup(state, definition, reason)
	, LIFECYCLE_CLEANED)


static func unmount(environment: Dictionary, token: String, definition: Dictionary, reason: String = "abandoned") -> Dictionary:
	return sync_owner(environment, token, definition, false, reason)


static func pending_outcomes(environment: Dictionary, token: String) -> Array:
	var entry := _dict(_container(environment).get(token, {}))
	var acknowledgements := _dict(entry.get("outcome_acknowledgements", {}))
	var receipts := _dict(entry.get("outcome_receipts", {}))
	var result: Array = []
	var ids := receipts.keys()
	ids.sort()
	for receipt_id_value in ids:
		var receipt_id := str(receipt_id_value)
		if not acknowledgements.has(receipt_id):
			result.append(_dict(receipts.get(receipt_id, {})))
	return result


# Computes the neutral terminal receipt from the exact mounted registration,
# trusted definition fingerprint and live terminal cause. It does not persist a
# receipt, acknowledgement or lifecycle mutation.
static func preview_outcome(environment: Dictionary, token: String, definition: Dictionary, outcome: String, owner_cause: Dictionary = {}) -> Dictionary:
	var entry := _dict(_container(environment).get(token, {}))
	var clean_outcome := outcome.strip_edges()
	if entry.is_empty() or str(entry.get("owner_token", "")) != token:
		return {"ok": false, "errors": ["world sequence outcome preview is not bound to a mounted owner"]}
	if str(entry.get("definition_fingerprint", "")) != SequenceRuntimeScript.content_fingerprint(definition):
		return {"ok": false, "errors": ["world sequence outcome preview definition does not match"]}
	var channel_id := str(_dict(entry.get("outcome_channels", {})).get(clean_outcome, ""))
	if channel_id.is_empty():
		return {"ok": false, "errors": ["world sequence outcome preview channel is not registered"]}
	var state := _dict(entry.get("state", {}))
	var runtime_terminal := _array(state.get("resolved_outcomes", [])).has(clean_outcome)
	if not runtime_terminal:
		for record_value in _array(state.get("branch_resolution_records", [])):
			if str(_dict(record_value).get("terminal_outcome", "")) == clean_outcome:
				runtime_terminal = true
				break
	var cause_fingerprint := ""
	if runtime_terminal:
		cause_fingerprint = SequenceRuntimeScript.content_fingerprint({
			"owner_token": token,
			"outcome": clean_outcome,
			"definition_fingerprint": str(entry.get("definition_fingerprint", "")),
			"runtime_status": str(state.get("status", "")),
		})
	elif clean_outcome in ["expired", "abandoned"]:
		var expected_owner_cause := {
			"schema_version": 1,
			"owner_token": token,
			"public_instance_token": str(entry.get("public_instance_token", "")),
			"outcome": clean_outcome,
			"delivery_resolution_fingerprint": str(owner_cause.get("delivery_resolution_fingerprint", "")),
		}
		if owner_cause != expected_owner_cause or str(expected_owner_cause.get("delivery_resolution_fingerprint", "")).is_empty():
			return {"ok": false, "errors": ["world sequence owner terminal cause is not exact"]}
		cause_fingerprint = SequenceRuntimeScript.content_fingerprint(expected_owner_cause)
	else:
		return {"ok": false, "errors": ["world sequence runtime has not reached the requested terminal outcome"]}
	var receipt_id := "world_outcome:%s:%s" % [token, clean_outcome]
	var receipt := {
		"receipt_id": receipt_id,
		"owner_token": token,
		"public_instance_token": str(entry.get("public_instance_token", "")),
		"channel_id": channel_id,
		"outcome": clean_outcome,
		"cause_fingerprint": cause_fingerprint,
	}
	receipt["receipt_fingerprint"] = SequenceRuntimeScript.content_fingerprint(receipt)
	return {"ok": true, "receipt": receipt, "errors": []}


# Materializes exactly the previously previewed receipt after the owner model's
# closed checkpoint is durable. Owner-driven expiry/abandon also reaches its
# shared-runtime terminal here; acknowledgement and cleanup remain independent.
static func confirm_outcome(environment: Dictionary, token: String, definition: Dictionary, expected_receipt: Dictionary, owner_cause: Dictionary = {}) -> Dictionary:
	var outcome := str(expected_receipt.get("outcome", ""))
	var preview := preview_outcome(environment, token, definition, outcome, owner_cause)
	if not bool(preview.get("ok", false)):
		return preview
	if _dict(preview.get("receipt", {})) != expected_receipt:
		return {"ok": false, "errors": ["world sequence confirmed outcome differs from its trusted preview"]}
	var entry := _dict(_container(environment).get(token, {}))
	var state := _dict(entry.get("state", {}))
	if not _array(state.get("resolved_outcomes", [])).has(outcome):
		var terminal := _apply_runtime_result(environment, token, definition, func(live_state: Dictionary) -> Dictionary:
			return SequenceRuntimeScript.apply_owner_lifecycle_outcome(live_state, definition, outcome, outcome)
		, LIFECYCLE_CLEANUP_PENDING)
		if not bool(terminal.get("ok", false)):
			return terminal
	entry = _dict(_container(environment).get(token, {}))
	var receipts := _dict(entry.get("outcome_receipts", {}))
	var receipt_id := str(expected_receipt.get("receipt_id", ""))
	if receipts.has(receipt_id):
		if _dict(receipts.get(receipt_id, {})) != expected_receipt:
			return {"ok": false, "errors": ["world sequence outcome receipt was reused with different content"]}
		return {"ok": true, "replayed": true, "receipt": expected_receipt.duplicate(true), "errors": []}
	receipts[receipt_id] = expected_receipt.duplicate(true)
	entry["outcome_receipts"] = receipts
	entry["lifecycle"] = LIFECYCLE_CLEANUP_PENDING
	var container := _container(environment)
	container[token] = entry
	environment[CONTAINER_KEY] = container
	return {"ok": true, "replayed": false, "receipt": expected_receipt.duplicate(true), "errors": []}


# The owning model applies its existing API first, then acknowledges with only
# the public result. Consumer payloads, shortfall calculations and private model
# state are never accepted or serialized by this seam.
static func acknowledge_outcome(environment: Dictionary, token: String, receipt_id: String, public_result: Dictionary) -> Dictionary:
	var forbidden := ["consumer_payload", "payment_shortfall", "private_state", "hidden_state", "grievance"]
	for key in forbidden:
		if public_result.has(key):
			return {"ok": false, "errors": ["world sequence outcome acknowledgement contains a private consumer field"]}
	var container := _container(environment)
	var entry := _dict(container.get(token, {}))
	var receipts := _dict(entry.get("outcome_receipts", {}))
	if entry.is_empty() or not receipts.has(receipt_id):
		return {"ok": false, "errors": ["world sequence outcome receipt is not registered"]}
	var acknowledgements := _dict(entry.get("outcome_acknowledgements", {}))
	var fingerprint := SequenceRuntimeScript.content_fingerprint(public_result)
	if acknowledgements.has(receipt_id):
		var existing := _dict(acknowledgements.get(receipt_id, {}))
		if str(existing.get("result_fingerprint", "")) != fingerprint:
			return {"ok": false, "errors": ["world sequence outcome receipt was reused with different public result content"]}
		return {"ok": true, "replayed": true, "receipt_id": receipt_id, "public_result": _dict(existing.get("public_result", {})), "errors": []}
	acknowledgements[receipt_id] = {"result_fingerprint": fingerprint, "public_result": public_result.duplicate(true)}
	entry["outcome_acknowledgements"] = acknowledgements
	# Acknowledgement completes delivery to the owning model, not runtime
	# cleanup. Keep cleanup authority explicit and retryable until sync_owner()
	# successfully applies the shared runtime cleanup operation.
	entry["lifecycle"] = LIFECYCLE_CLEANUP_PENDING
	container[token] = entry
	environment[CONTAINER_KEY] = container
	return {"ok": true, "replayed": false, "receipt_id": receipt_id, "public_result": public_result.duplicate(true), "errors": []}


static func composed_projection(environment: Dictionary, definitions: Dictionary, environment_projection: Dictionary = {}) -> Dictionary:
	var result := environment_projection.duplicate(true)
	var semantic := _dict(result.get("semantic_state", {}))
	for collection in PROJECTION_COLLECTIONS:
		semantic[collection] = _dict(semantic.get(collection, {}))
	var errors: Array = []
	var tokens := _container(environment).keys()
	tokens.sort()
	for token_value in tokens:
		var token := str(token_value)
		var entry := _dict(_container(environment).get(token, {}))
		var definition := _dict(definitions.get(token, {}))
		if not SequenceSchemaScript.is_sequence(definition):
			continue
		var creation_owners := _array(_dict(_dict(entry.get("state", {})).get("semantic_state", {})).get("creation_owner_namespaces", []))
		var owner_projection := projection(environment, token, definition)
		var owner_semantic := _dict(owner_projection.get("semantic_state", {}))
		for collection in PROJECTION_COLLECTIONS:
			var target := _dict(semantic.get(collection, {}))
			for identity_value in _dict(owner_semantic.get(collection, {})).keys():
				var identity := str(identity_value)
				var record := _dict(_dict(owner_semantic.get(collection, {})).get(identity_value, {}))
				if creation_owners.has(str(record.get("owner_namespace", ""))):
					record["world_sequence_owner_token"] = token
				if collection == "interactions":
					var actions: Array = []
					for action_value in _array(record.get("available_actions", [])):
						var action := _dict(action_value)
						for field in ["owner_namespace", "stable_object_id", "operation_receipt_key", "operation_boundary_id", "operation_fingerprint"]:
							var action_field := "action_origin_%s" % field.trim_prefix("operation_")
							if record.has(field): action[action_field] = record.get(field)
						if creation_owners.has(str(action.get("action_origin_owner_namespace", ""))):
							action["world_sequence_owner_token"] = token
						actions.append(action)
					record["available_actions"] = actions
				if target.has(identity) and JSON.stringify(target.get(identity)) != JSON.stringify(record):
					errors.append("world sequence composed projection conflicts at %s/%s" % [collection, identity])
				else:
					target[identity] = record
			semantic[collection] = target
	if not errors.is_empty():
		return {"ok": false, "errors": _unique_strings(errors), "semantic_state": {}}
	result["semantic_state"] = semantic
	result["ok"] = true
	result["errors"] = []
	return result


static func definition_claims(definition: Dictionary) -> Array:
	var result: Array = []
	var authored := SequenceSchemaScript.sequence(definition)
	for family in ["scene_ops", "interaction_ops", "actor_ops"]:
		for operation_value in _all_operations(authored, family):
			var operation := _dict(operation_value)
			var owner := str(operation.get("target_owner_namespace", operation.get("owner_namespace", "")))
			var stable_id := str(operation.get("target_stable_object_id", operation.get("stable_object_id", "")))
			if owner.is_empty() or stable_id.is_empty():
				continue
			var claim := {"target": "%s::%s" % [owner, stable_id], "property": family, "mode": "exclusive"}
			if not result.has(claim):
				result.append(claim)
	return result


static func durable_container(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	for token_value in _dict(value).keys():
		var token := str(token_value)
		var entry := _dict(_dict(value).get(token_value, {}))
		if str(entry.get("owner_token", "")) != token or int(entry.get("schema_version", 0)) != REGISTRATION_SCHEMA_VERSION:
			continue
		var state := _durable_state(entry.get("state", {}))
		if state.is_empty():
			continue
		entry["state"] = state
		result[token] = entry
	return result


static func _apply_runtime_result(environment: Dictionary, token: String, definition: Dictionary, operation: Callable, lifecycle_override: String = "") -> Dictionary:
	var container := _container(environment)
	var entry := _dict(container.get(token, {}))
	if entry.is_empty():
		return {"ok": false, "errors": ["world sequence owner token is not mounted"]}
	if str(entry.get("definition_fingerprint", "")) != SequenceRuntimeScript.content_fingerprint(definition):
		return {"ok": false, "errors": ["world sequence definition content does not match the mounted owner"]}
	var rebound := _rehydrate_entry(entry, definition, ScenarioEngineScript.sequence_host_semantics(environment))
	if not bool(rebound.get("ok", false)):
		return {"ok": false, "errors": _array(rebound.get("errors", []))}
	entry = _dict(rebound.get("entry", entry))
	var before_state := _dict(entry.get("state", {}))
	var result: Dictionary = operation.call(before_state)
	if not bool(result.get("ok", false)):
		return result
	var next := _dict(result.get("state", {}))
	if next.is_empty():
		return {"ok": false, "errors": ["world sequence operation produced no authoritative next state"]}
	entry["state"] = next
	if not lifecycle_override.is_empty():
		entry["lifecycle"] = lifecycle_override
	elif str(next.get("status", "")) == SequenceRuntimeScript.STATUS_AFTERMATH:
		entry["lifecycle"] = LIFECYCLE_CLEANUP_PENDING
	elif str(next.get("status", "")) == SequenceRuntimeScript.STATUS_CLEANED:
		entry["lifecycle"] = LIFECYCLE_CLEANED
	container[token] = entry
	environment[CONTAINER_KEY] = container
	result["state"] = next.duplicate(true)
	result["projection"] = SequenceRuntimeScript.public_projection(next, definition)
	return result


static func _rehydrate_entry(entry_value: Dictionary, definition: Dictionary, host_semantics: Dictionary) -> Dictionary:
	var entry := entry_value.duplicate(true)
	if str(entry.get("definition_fingerprint", "")) != SequenceRuntimeScript.content_fingerprint(definition):
		return {"ok": false, "errors": ["world sequence definition fingerprint changed"]}
	var bound_host := host_semantics.duplicate(true)
	bound_host["creation_owner_namespaces"] = _definition_creation_owner_namespaces(definition)
	var state := SequenceRuntimeScript.normalize_state(entry.get("state", {}), definition, bound_host)
	if state.is_empty():
		return {"ok": false, "errors": ["persisted world sequence state cannot be normalized"]}
	entry["state"] = state
	return {"ok": true, "entry": entry, "errors": []}


static func _source_definition_errors(source: Dictionary, definition: Dictionary) -> Array:
	var errors: Array = []
	if str(source.get("definition_id", "")) != str(definition.get("id", "")):
		errors.append("world sequence source definition_id must equal the shared runtime definition id")
	for key in source.keys():
		if not ["domain", "owner_id", "definition_id"].has(str(key)):
			errors.append("world sequence source contains unknown field %s" % str(key))
	return errors


static func _creation_owner_errors(source: Dictionary, owners: Array) -> Array:
	var errors: Array = []
	if owners.is_empty(): return errors
	if owners.has("base") or owners.has("scenario"):
		errors.append("crew/world sequence cannot claim base or reserved environment creation ownership")
	if str(source.get("domain", "")) == "crew" and owners != ["crew"]:
		errors.append("crew sequence creates must use only the crew owner namespace")
	return errors


static func _outcome_channel_errors(definition: Dictionary, channels: Dictionary, registered: Array) -> Array:
	var errors: Array = []
	var reachable := SequenceSchemaScript.reachable_outcome_ids(definition)
	for outcome_value in reachable:
		var outcome := str(outcome_value)
		var channel := str(channels.get(outcome, ""))
		if channel.is_empty():
			errors.append("world sequence reachable outcome %s has no owning channel" % outcome)
		elif not registered.has(channel):
			errors.append("world sequence outcome channel is not registered: %s" % channel)
	for outcome_key in channels.keys():
		if not reachable.has(str(outcome_key)):
			errors.append("world sequence outcome channel names unreachable outcome %s" % str(outcome_key))
	return errors


static func _normalized_claims(value: Array, errors: Array) -> Array:
	var result: Array = []
	for index in range(value.size()):
		var claim := _dict(value[index])
		for key in claim.keys():
			if not ["target", "property", "mode"].has(str(key)):
				errors.append("world sequence ownership claim %d contains unknown field %s" % [index, str(key)])
		var target := str(claim.get("target", ""))
		var property := str(claim.get("property", ""))
		var mode := str(claim.get("mode", ""))
		if OperationRegistryScript.validate_owned_identity(target).is_empty() and _valid_component(property) and ["exclusive", "shared"].has(mode):
			var normalized := {"target": target, "property": property, "mode": mode}
			if result.has(normalized):
				errors.append("world sequence duplicates an ownership claim")
			else:
				result.append(normalized)
		else:
			errors.append("world sequence ownership claim %d is malformed" % index)
	return result


static func _ownership_conflicts(token: String, claims: Array, container: Dictionary, reserved_claims: Array) -> Array:
	var errors: Array = []
	var occupied := reserved_claims.duplicate(true)
	for other_token_value in container.keys():
		if str(other_token_value) == token:
			continue
		occupied.append_array(_array(_dict(container.get(other_token_value, {})).get("ownership_claims", [])))
	for claim_value in claims:
		var claim := _dict(claim_value)
		for occupied_value in occupied:
			var existing := _dict(occupied_value)
			if str(claim.get("target", "")) == str(existing.get("target", "")) and str(claim.get("property", "")) == str(existing.get("property", "")) and (str(claim.get("mode", "")) == "exclusive" or str(existing.get("mode", "")) == "exclusive"):
				errors.append("world sequence exclusive ownership conflict at %s/%s" % [str(claim.get("target", "")), str(claim.get("property", ""))])
	return errors


static func _mount_selector_errors(environment: Dictionary, selector: Dictionary) -> Array:
	var errors: Array = []
	for key in selector.keys():
		if not ["node_id", "zone_id"].has(str(key)):
			errors.append("world sequence mount selector contains unknown field %s" % str(key))
	var node_id := str(selector.get("node_id", "")).strip_edges()
	var current_node := str(environment.get("world_node_id", environment.get("archetype_id", environment.get("id", "")))).strip_edges()
	if node_id.is_empty() or node_id != current_node:
		errors.append("world sequence mount selector is not bound to the current public world node")
	var zone_id := str(selector.get("zone_id", "")).strip_edges()
	if not zone_id.is_empty() and not _valid_component(zone_id):
		errors.append("world sequence mount zone must be canonical")
	return errors


static func _public_command_context(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in ["available_funds", "host_interaction_availability"]:
		if value.has(key):
			result[key] = _copy_variant(value.get(key))
	return result


static func _sealed_command(state: Dictionary, command: Dictionary) -> Dictionary:
	var identity := OperationRegistryScript.identity(str(command.get("owner_namespace", "")), str(command.get("stable_object_id", "")))
	var interaction := _dict(_dict(_dict(state.get("semantic_state", {})).get("interactions", {})).get(identity, {}))
	if interaction.is_empty(): return {}
	var sealed_action: Dictionary = {}
	for action_value in _array(interaction.get("available_actions", [])):
		var action := _dict(action_value)
		if str(action.get("id", "")) == str(command.get("command_id", "")):
			sealed_action = action
			break
	if sealed_action.is_empty(): return {}
	var result := command.duplicate(true)
	result["action_origin_owner_namespace"] = str(interaction.get("owner_namespace", ""))
	result["action_origin_stable_object_id"] = str(interaction.get("stable_object_id", ""))
	result["action_origin_receipt_key"] = str(interaction.get("operation_receipt_key", ""))
	result["action_origin_boundary_id"] = str(interaction.get("operation_boundary_id", ""))
	result["action_origin_fingerprint"] = str(interaction.get("operation_fingerprint", ""))
	return result


static func _public_source(value: Dictionary) -> Dictionary:
	return {"domain": str(value.get("domain", "")), "owner_id": str(value.get("owner_id", "")), "definition_id": str(value.get("definition_id", ""))}


static func _container(environment: Dictionary) -> Dictionary:
	return _dict(environment.get(CONTAINER_KEY, {}))


static func _durable_state(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not SequenceRuntimeScript._persisted_collections_within_limits(value as Dictionary):
		return {}
	var state := (value as Dictionary).duplicate(true)
	var semantic := _dict(state.get("semantic_state", {}))
	for key in ["target_inventory", "declared_targets", "base_interactions", "event_choices", "scene_objects", "interactions", "actors", "services", "games", "routes", "transition_queue", "tombstones"]:
		semantic.erase(key)
	state["semantic_state"] = semantic
	state.erase("resolved_branches")
	state.erase("resolved_outcomes")
	return state


static func _all_operations(authored: Dictionary, family: String) -> Array:
	var result: Array = []
	for phase_value in _array(_dict(authored.get("phase_graph", {})).get("phases", [])):
		result.append_array(_array(_dict(phase_value).get(family, [])))
	for aftermath_value in _dict(authored.get("aftermath", {})).values():
		result.append_array(_array(_dict(aftermath_value).get(family, [])))
	result.append_array(_array(_dict(authored.get("cleanup", {})).get(family, [])))
	return result


static func _definition_creation_owner_namespaces(definition: Dictionary) -> Array:
	var result: Array = []
	var authored := SequenceSchemaScript.sequence(definition)
	for family in ["scene_ops", "interaction_ops", "actor_ops", "service_ops", "game_ops"]:
		for operation_value in _all_operations(authored, family):
			var operation := _dict(operation_value)
			var op_id := str(operation.get("op", ""))
			var creates: bool = family == "scene_ops" and op_id == "spawn" or family == "interaction_ops" and op_id == "add" or family == "actor_ops" and op_id == "spawn" or family in ["service_ops", "game_ops"] and op_id == "add"
			var owner := str(operation.get("owner_namespace", ""))
			if creates and not owner.is_empty() and not result.has(owner): result.append(owner)
	result.sort()
	return result


static func _is_event_module_surface_id(value: String) -> bool:
	return value == "heist_live_table" or value.begins_with("crew_") or value.begins_with("recruitment_") \
		or value.begins_with("numbers_") or value.begins_with("police_sweep_")


static func _source_comparison_literals(source: String, subject_marker: String, comparison_marker: String) -> Array:
	var result: Array = []
	for line_value in source.split("\n"):
		var line := str(line_value)
		if not line.contains(subject_marker): continue
		var marker_index := line.find(comparison_marker)
		if marker_index < 0: continue
		var value_start := marker_index + comparison_marker.length()
		var value_end := line.find('"', value_start)
		if value_end <= value_start: continue
		var value := line.substr(value_start, value_end - value_start)
		if _is_event_module_surface_id(value) or value.begins_with("crew_"):
			if not result.has(value): result.append(value)
	result.sort()
	return result


static func _append_inventory_difference(diagnostics: Array, source_kind: String, actual_value: Array, frozen_value: Array) -> void:
	var actual := actual_value.duplicate()
	var frozen := frozen_value.duplicate()
	actual.sort()
	frozen.sort()
	for source_id_value in actual:
		var source_id := str(source_id_value)
		if frozen.has(source_id): continue
		diagnostics.append_array(wrap_validation_errors(source_kind, source_id, "", "", ["Unclassified EventModule crew/world surface."]))
	for source_id_value in frozen:
		var source_id := str(source_id_value)
		if actual.has(source_id): continue
		diagnostics.append_array(wrap_validation_errors(source_kind, source_id, "", "", ["Frozen EventModule crew/world surface is no longer routed."]))


static func _sorted_diagnostics(value: Array) -> Array:
	var result := value.duplicate(true)
	result.sort_custom(func(a: Variant, b: Variant) -> bool:
		return _diagnostic_sort_key(_dict(a)) < _diagnostic_sort_key(_dict(b))
	)
	return result


static func _diagnostic_sort_key(value: Dictionary) -> String:
	return "%s\u001f%s\u001f%s\u001f%s\u001f%s" % [
		str(value.get("instance_id", "")), str(value.get("source_kind", "")),
		str(value.get("source_id", "")), str(value.get("definition_id", "")),
		str(value.get("error_id", "")),
	]


static func _safe_diagnostic_identifier(value: String) -> String:
	return "redacted" if _identifier_hidden_reason(value) != "" else value


static func _safe_diagnostic_message(value: String) -> bool:
	var lower := value.to_lower()
	if lower.contains("res://") or lower.contains("user://") or lower.contains(":\\") or lower.contains(":/"):
		return false
	for term in HIDDEN_IDENTIFIER_TERMS:
		if lower.contains(term) or term == "theturn" and lower.contains("the_turn"): return false
	return _identifier_hidden_reason(value) == ""


static func _collect_hidden_identifier_failures(value: Variant, field_name: String, failures: Array) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		for key_value in (value as Dictionary).keys():
			var key := str(key_value)
			var key_reason := _identifier_hidden_reason(key)
			if not key_reason.is_empty(): failures.append("world sequence public identifier is forbidden: %s" % key_reason)
			_collect_hidden_identifier_failures((value as Dictionary).get(key_value), key, failures)
		return
	if typeof(value) == TYPE_ARRAY:
		for item in value as Array: _collect_hidden_identifier_failures(item, field_name, failures)
		return
	if typeof(value) != TYPE_STRING or not _identifier_field(field_name): return
	var reason := _identifier_hidden_reason(str(value))
	if not reason.is_empty(): failures.append("world sequence public identifier is forbidden: %s" % reason)


static func _identifier_field(value: String) -> bool:
	if value in ["sequence_signature", "operation_fingerprint", "definition_fingerprint", "cause_fingerprint", "result_fingerprint", "content_fingerprint"]:
		return false
	return value.ends_with("_id") or value.ends_with("_ids") or value.ends_with("_token") \
		or value in ["owner_namespace", "handler", "fact", "facts", "outcome", "outcomes", "capability", "capabilities", "mechanic_tags"]


static func _identifier_hidden_reason(value: String) -> String:
	var lower := value.strip_edges().to_lower()
	if lower.is_empty(): return ""
	var compact := lower.replace("_", "").replace("-", "").replace(":", "").replace(".", "")
	var segments := lower.replace("-", "_").replace(":", "_").replace(".", "_").split("_", false)
	for term in HIDDEN_IDENTIFIER_TERMS:
		if compact == term or segments.has(term): return "hidden semantic identifier"
	if _hash_like_identifier(lower): return "opaque identity hash"
	return ""


static func _hash_like_identifier(value: String) -> bool:
	var pieces := value.replace("-", "_").replace(":", "_").split("_", false)
	for piece_value in pieces:
		var piece := str(piece_value)
		if piece.length() not in HASH_IDENTIFIER_LENGTHS and piece.length() < 16: continue
		var all_hex := true
		for index in range(piece.length()):
			var code := piece.unicode_at(index)
			if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
				all_hex = false
				break
		if all_hex: return true
	return false


static func _valid_component(value: String) -> bool:
	if value.is_empty() or value != value.strip_edges() or value.length() > 128 or value.contains("::"):
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and not [45, 58, 95].has(code):
			return false
	return true


static func _unique_strings(value: Array) -> Array:
	var result: Array = []
	for item in value:
		var text := str(item)
		if not text.is_empty() and not result.has(text):
			result.append(text)
	return result


static func _copy_variant(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return value


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
