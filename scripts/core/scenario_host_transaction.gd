class_name ScenarioHostTransaction
extends RefCounted

# Cross-consumer host boundary for table-game commands. Games author pure deltas;
# only this host replaces table state, mutates accounts, publishes facts, or
# advances interruption/travel requests.

const SCHEMA_VERSION := 2
const FACT_SCHEMA_VERSION := 1
const REQUEST_SCHEMA_VERSION := 1
const MAPPING_MANIFEST_SCHEMA_VERSION := 1
const PREPARED_ENVELOPE_VERSION := 1
const ACCOUNT_DOMAINS := ["bankroll", "chips"]
const POKER_CREW_MEMBER_IDS := ["crew_rook", "crew_velvet", "crew_knuckles", "crew_switch", "crew_mags", "crew_bishop", "crew_lucky"]
const POKER_POLICY_OWNER_IDS := ["poker_policy_crew_rook", "poker_policy_crew_velvet", "poker_policy_crew_knuckles", "poker_policy_crew_switch", "poker_policy_crew_mags", "poker_policy_crew_bishop", "poker_policy_crew_lucky"]
const REQUEST_KINDS := ["interruption", "travel"]
const REQUEST_RESPONSES := ["defer", "accept", "reject"]
const TERMINAL_REQUEST_STATUSES := ["rejected", "applied", "expired"]
const PREPARED_CONTEXT_ALLOWLIST := ["node_id", "environment_visit_id", "night_instance_id", "context_instance_id", "table_id", "table_state_digest", "accounts", "prepared_account", "rng_leases", "host_revision", "host_state_digest"]
const KNOWN_RNG_OWNER_IDS := ["scenario", "craps_throw", "craps_recovery", "poker_cards", "poker_cues"] + POKER_POLICY_OWNER_IDS
const FACT_CONSUMER_NAMESPACES := ["runtime.scenario", "public.system"]
const FACT_PRIVACY_FORBIDDEN_KEYS := ["account_id", "account_balance", "accounts", "rng", "rng_state", "edge_weights", "operation_receipts", "prepared_operation_receipt_ids", "mapping_manifest_sha256", "payload_sha256", "private_runtime_state", "hole_cards", "deck", "discards", "policy", "tell", "pattern", "verification", "future_branches", "packed_turn"]
const PREPARED_SCHEMAS := ["prepared_craps_context", "prepared_craps_interrupt", "prepared_poker_night", "prepared_poker_interrupt"]
const PREPARED_ACK_KEYS := ["status", "ack_receipt_id", "observed_game_state_sha256", "accepted_boundary", "applied_transaction_id", "reason_code"]
const PREPARED_ACK_STATUSES := ["unacknowledged", "accepted", "deferred", "rejected", "applied", "expired"]
const REQUESTED_BOUNDARIES := ["immediate_safe", "after_receipt", "before_next_throw", "between_hands"]
const MAX_FACT_LOG := 128
const MAX_QUEUE := 256
const MAX_RECEIPTS := 2048
const MAX_ACTIVE_RECEIPTS := 512
const MAX_TEXT := 512
const MAX_DEPTH := 10
const MAX_VALUES := 2048


static func initial_state(accounts: Dictionary = {}, table_states: Dictionary = {}, rng_leases: Dictionary = {}) -> Dictionary:
	var result := normalize_state({
		"schema_version": SCHEMA_VERSION,
		"revision": 0,
		"accounts": accounts,
		"table_states": table_states,
		"trust": {},
		"tells": {},
		"authorized_tell_patterns": [],
		"fact_queue": [],
		"fact_log": [],
		"fact_receipts": {},
		"fact_commit_order": 0,
		"fact_compaction_floor": 0,
		"authoritative_receipts": {},
		"receipt_results": {},
		"prepared_requests": {},
		"acknowledgements": [],
		"external_warnings": [],
		"rng_leases": rng_leases,
		"request_delivery_serials": {},
		"safe_boundary": 0,
		"canonical_context": {},
		"table_registry": {},
		"mapping_manifests": {},
		"staged_operation_receipts": {},
		"runtime_records": {"room_ops": [], "travel_ops": []},
		"travel_authorizations": {},
		"publication_outbox": [],
		"publication_receipts": {},
		"receipt_order": [],
		"receipt_archive": {},
		"canonical_snapshot_digest": "",
	})
	result["canonical_snapshot_digest"] = _canonical_snapshot_digest(result)
	return result


static func normalize_state(value: Variant) -> Dictionary:
	var source := _dict(value)
	var source_schema := int(source.get("schema_version", 1))
	return {
		"schema_version": SCHEMA_VERSION,
		"schema_error": "" if source_schema in [1, SCHEMA_VERSION] else "unsupported scenario host ledger schema_version: %d" % source_schema,
		"revision": maxi(0, int(source.get("revision", 0))),
		"accounts": _normalize_accounts(source.get("accounts", {})),
		"table_states": _dict(source.get("table_states", {})),
		"trust": _int_dictionary(source.get("trust", {})),
		"tells": _int_dictionary(source.get("tells", {})),
		"authorized_tell_patterns": _string_array(source.get("authorized_tell_patterns", [])),
		"fact_queue": _dictionary_array(source.get("fact_queue", [])),
		"fact_log": _dictionary_array(source.get("fact_log", [])),
		"fact_receipts": _dict(source.get("fact_receipts", {})),
		"fact_commit_order": maxi(0, int(source.get("fact_commit_order", 0))),
		"fact_compaction_floor": maxi(0, int(source.get("fact_compaction_floor", 0))),
		"authoritative_receipts": _dict(source.get("authoritative_receipts", {})),
		"receipt_results": _dict(source.get("receipt_results", {})),
		"prepared_requests": _dict(source.get("prepared_requests", {})),
		"acknowledgements": _dictionary_array(source.get("acknowledgements", [])),
		"external_warnings": _string_array(source.get("external_warnings", [])),
		"rng_leases": _dict(source.get("rng_leases", {})),
		"request_delivery_serials": _int_dictionary(source.get("request_delivery_serials", {})),
		"safe_boundary": maxi(0, int(source.get("safe_boundary", 0))),
		"canonical_context": _dict(source.get("canonical_context", {})),
		"table_registry": _dict(source.get("table_registry", {})),
		"mapping_manifests": _dict(source.get("mapping_manifests", {})),
		"staged_operation_receipts": _dict(source.get("staged_operation_receipts", {})),
		"runtime_records": _normalize_runtime_records(source.get("runtime_records", {})),
		"travel_authorizations": _dict(source.get("travel_authorizations", {})),
		"publication_outbox": _dictionary_array(source.get("publication_outbox", [])),
		"publication_receipts": _dict(source.get("publication_receipts", {})),
		"receipt_order": _string_array(source.get("receipt_order", [])),
		"receipt_archive": _dict(source.get("receipt_archive", {})),
		"canonical_snapshot_digest": str(source.get("canonical_snapshot_digest", "")),
	}


static func persisted_ledger(state_value: Dictionary) -> Dictionary:
	var state := normalize_state(state_value)
	for key in ["accounts", "table_states", "trust", "tells", "authorized_tell_patterns", "canonical_snapshot_digest"]:
		state.erase(key)
	return state


static func bind_canonical_snapshot(ledger_value: Dictionary, snapshot: Dictionary) -> Dictionary:
	var combined := ledger_value.duplicate(true)
	combined["accounts"] = _dict(snapshot.get("accounts", {}))
	combined["table_states"] = _dict(snapshot.get("table_states", {}))
	combined["trust"] = _dict(snapshot.get("trust", {}))
	combined["tells"] = _dict(snapshot.get("tells", {}))
	combined["authorized_tell_patterns"] = _string_array(snapshot.get("authorized_tell_patterns", []))
	combined["canonical_context"] = _public_context_projection(_dict(snapshot.get("canonical_context", {})))
	combined["runtime_records"] = _normalize_runtime_records(snapshot.get("runtime_records", combined.get("runtime_records", {})))
	combined["canonical_snapshot_digest"] = ""
	var result := normalize_state(combined)
	result["canonical_snapshot_digest"] = _canonical_snapshot_digest(result)
	return result


static func public_context(node_id: String, environment_visit_id: String, night_instance_id: String, context_instance_id: String) -> Dictionary:
	return {
		"node_id": node_id.strip_edges(),
		"environment_visit_id": environment_visit_id.strip_edges(),
		"night_instance_id": night_instance_id.strip_edges(),
		"context_instance_id": context_instance_id.strip_edges(),
	}


static func inject_public_context(environment_value: Dictionary, context: Dictionary) -> Dictionary:
	var errors := _validate_context(context)
	if not errors.is_empty():
		return {"ok": false, "environment": environment_value.duplicate(true), "errors": errors}
	var environment := environment_value.duplicate(true)
	environment["world_node_id"] = str(context.get("node_id", ""))
	environment["environment_visit_id"] = str(context.get("environment_visit_id", ""))
	environment["night_instance_id"] = str(context.get("night_instance_id", ""))
	environment["context_instance_id"] = str(context.get("context_instance_id", ""))
	return {"ok": true, "environment": environment, "errors": []}


static func prepared_game_context(state_value: Dictionary, context: Dictionary, table_id: String, producer_id: String, requested_keys: Array = []) -> Dictionary:
	var state := normalize_state(state_value)
	var errors := _validate_context(context)
	if not _valid_id(producer_id): errors.append("prepared context requires a producer_id.")
	if not _valid_id(table_id) or not _dict(state.get("table_states", {})).has(table_id):
		errors.append("prepared context references an unknown table_id.")
	elif str(_dict(_dict(state.get("table_states", {})).get(table_id, {})).get("producer_id", "")) != producer_id:
		errors.append("prepared context producer does not own this table.")
	var keys := PREPARED_CONTEXT_ALLOWLIST.duplicate() if requested_keys.is_empty() else requested_keys.duplicate()
	for key_value in keys:
		if not PREPARED_CONTEXT_ALLOWLIST.has(str(key_value)):
			errors.append("prepared context key is not game-facing: %s." % str(key_value))
	if not errors.is_empty():
		return {"ok": false, "context": {}, "errors": errors}
	var available := context.duplicate(true)
	available["table_id"] = table_id
	available["table_state_digest"] = state_digest(_dict(_dict(state.get("table_states", {})).get(table_id, {})))
	var prepared_account_id := _prepared_account_id(state, producer_id, table_id)
	var prepared_accounts: Dictionary = {}
	if not prepared_account_id.is_empty(): prepared_accounts[prepared_account_id] = _dict(_dict(state.get("accounts", {})).get(prepared_account_id, {}))
	if producer_id in ["craps", "poker"] and (prepared_account_id.is_empty() or _dict(prepared_accounts.get(prepared_account_id, {})).is_empty()):
		return {"ok": false, "context": {}, "errors": ["prepared context has no authorized canonical account."]}
	available["accounts"] = prepared_accounts
	available["prepared_account"] = {"account_id": prepared_account_id, "fund_domain": str(_dict(prepared_accounts.get(prepared_account_id, {})).get("fund_domain", ""))} if not prepared_account_id.is_empty() else {}
	available["rng_leases"] = _owned_rng_lease_projection(state, producer_id)
	available["host_revision"] = int(state.get("revision", 0))
	available["host_state_digest"] = state_digest(state)
	var result: Dictionary = {}
	for key_value in keys:
		result[str(key_value)] = _copy_variant(available.get(str(key_value)))
	return {"ok": true, "context": result, "errors": []}


static func game_fact(fact_type: String, producer_id: String, game_id: String, table_id: String, context: Dictionary, producer_receipt: String, scenario_receipt: String, target_boundary: int, payload: Dictionary) -> Dictionary:
	return {
		"schema_version": FACT_SCHEMA_VERSION,
		"fact_type": fact_type.strip_edges(),
		"producer_id": producer_id.strip_edges(),
		"game_id": game_id.strip_edges(),
		"table_id": table_id.strip_edges(),
		"context": _public_context_projection(context),
		"producer_receipt": producer_receipt.strip_edges(),
		"scenario_receipt": scenario_receipt.strip_edges(),
		"target_boundary": target_boundary,
		"payload": payload.duplicate(true),
		"commit_order": 0,
	}


static func prepared_request(request_id: String, kind: String, table_id: String, context: Dictionary, table_digest: String, target_boundary: int, delivery_serial: int, expires_at_boundary: int, payload: Dictionary) -> Dictionary:
	return {
		"schema_version": REQUEST_SCHEMA_VERSION,
		"request_id": request_id.strip_edges(),
		"kind": kind.strip_edges(),
		"table_id": table_id.strip_edges(),
		"context": _public_context_projection(context),
		"table_digest": table_digest.strip_edges(),
		"target_boundary": target_boundary,
		"delivery_serial": delivery_serial,
		"expires_at_boundary": expires_at_boundary,
		"payload": payload.duplicate(true),
		"status": "prepared",
	}


static func mapping_manifest(manifest_id: String, mappings: Array) -> Dictionary:
	var result := {
		"schema": "scenario_game_mapping_manifest",
		"version": MAPPING_MANIFEST_SCHEMA_VERSION,
		"manifest_id": manifest_id.strip_edges(),
		"mappings": _dictionary_array(mappings),
		"manifest_sha256": "",
	}
	result["manifest_sha256"] = state_digest(_manifest_hash_body(result))
	return result


static func register_mapping_manifest(state_value: Dictionary, manifest_value: Dictionary, receipt_id: String, expected_revision: int, expected_digest: String) -> Dictionary:
	var state := normalize_state(state_value)
	var manifest := manifest_value.duplicate(true)
	var fingerprint := state_digest({"kind": "mapping_manifest_registered", "manifest": manifest})
	var replay := _receipt_replay(state, receipt_id, fingerprint)
	if not replay.is_empty(): return replay
	var errors := _validate_protocol_cas(state, receipt_id, expected_revision, expected_digest)
	errors.append_array(_validate_mapping_manifest(manifest))
	var manifest_id := str(manifest.get("manifest_id", ""))
	var manifests := _dict(state.get("mapping_manifests", {}))
	if manifests.has(manifest_id) and state_digest(manifests.get(manifest_id)) != state_digest(manifest):
		errors.append("mapping manifest id is already bound to different content.")
	if not errors.is_empty(): return _failed(state, errors)
	var next := state.duplicate(true)
	manifests = _dict(next.get("mapping_manifests", {}))
	var stored := manifest.duplicate(true)
	stored["accepted"] = true
	stored["registration_receipt_id"] = receipt_id
	manifests[manifest_id] = stored
	next["mapping_manifests"] = manifests
	_record_receipt(next, receipt_id, fingerprint, {"kind": "mapping_manifest_registered", "manifest_id": manifest_id, "manifest_sha256": str(manifest.get("manifest_sha256", ""))})
	_bump_revision(next)
	return _success(next, receipt_id, {"kind": "mapping_manifest_registered", "manifest_id": manifest_id})


# Host-owned registration is the only depth API that may add producer/game/table
# ownership. Consumers supply opaque machine state and cannot seed owner fields.
static func register_table(state_value: Dictionary, table_instance_id: String, producer_id: String, game_id: String, prepared_account_id: String, machine_state: Dictionary, receipt_id: String, expected_revision: int, expected_digest: String) -> Dictionary:
	var state := normalize_state(state_value)
	var fingerprint := state_digest({"kind": "table_registered", "table_instance_id": table_instance_id, "producer_id": producer_id, "game_id": game_id, "prepared_account_id": prepared_account_id, "machine_state": machine_state})
	var replay := _receipt_replay(state, receipt_id, fingerprint)
	if not replay.is_empty(): return replay
	var errors := _validate_protocol_cas(state, receipt_id, expected_revision, expected_digest)
	if not _valid_id(table_instance_id) or producer_id not in ["craps", "poker"] or game_id != producer_id:
		errors.append("table registration requires a valid table and known producer/game pair.")
	if machine_state.has("producer_id") or machine_state.has("game_id") or machine_state.has("prepared_account_id"):
		errors.append("table machine state cannot seed host-owned ownership fields.")
	var account := _dict(_dict(state.get("accounts", {})).get(prepared_account_id, {}))
	if prepared_account_id.is_empty() or account.is_empty() or (producer_id == "poker" and str(account.get("fund_domain", "")) != "bankroll"):
		errors.append("table registration requires a canonical prepared account.")
	errors.append_array(_validate_bounded("registered table state", machine_state))
	var registry := _dict(state.get("table_registry", {}))
	if registry.has(table_instance_id): errors.append("table instance is already registered; use the migration seam.")
	if not errors.is_empty(): return _failed(state, errors)
	var next := state.duplicate(true)
	var table := machine_state.duplicate(true)
	table["producer_id"] = producer_id
	table["game_id"] = game_id
	table["prepared_account_id"] = prepared_account_id
	var tables := _dict(next.get("table_states", {}))
	tables[table_instance_id] = table
	next["table_states"] = tables
	registry = _dict(next.get("table_registry", {}))
	registry[table_instance_id] = {"producer_id": producer_id, "game_id": game_id, "prepared_account_id": prepared_account_id, "registration_receipt_id": receipt_id}
	next["table_registry"] = registry
	next["canonical_snapshot_digest"] = _canonical_snapshot_digest(next)
	_record_receipt(next, receipt_id, fingerprint, {"kind": "table_registered", "table_instance_id": table_instance_id})
	_bump_revision(next)
	return _success(next, receipt_id, {"kind": "table_registered", "table_instance_id": table_instance_id})


static func migrate_registered_table(state_value: Dictionary, table_instance_id: String, expected_table_digest: String, replacement_machine_state: Dictionary, receipt_id: String, expected_revision: int, expected_digest: String) -> Dictionary:
	var state := normalize_state(state_value)
	var registry_record := _dict(_dict(state.get("table_registry", {})).get(table_instance_id, {}))
	var table := _dict(_dict(state.get("table_states", {})).get(table_instance_id, {}))
	var fingerprint := state_digest({"kind": "table_migrated", "table_instance_id": table_instance_id, "expected_table_digest": expected_table_digest, "replacement_machine_state": replacement_machine_state})
	var replay := _receipt_replay(state, receipt_id, fingerprint)
	if not replay.is_empty(): return replay
	var errors := _validate_protocol_cas(state, receipt_id, expected_revision, expected_digest)
	if registry_record.is_empty() or table.is_empty(): errors.append("table migration requires a registered table.")
	if expected_table_digest != state_digest(table): errors.append("table migration expected digest is stale.")
	if replacement_machine_state.has("producer_id") or replacement_machine_state.has("game_id") or replacement_machine_state.has("prepared_account_id"):
		errors.append("table migration cannot replace host-owned ownership fields.")
	errors.append_array(_validate_bounded("migrated table state", replacement_machine_state))
	if not errors.is_empty(): return _failed(state, errors)
	var next := state.duplicate(true)
	var replacement := replacement_machine_state.duplicate(true)
	for key in ["producer_id", "game_id", "prepared_account_id"]: replacement[key] = registry_record.get(key)
	var tables := _dict(next.get("table_states", {}))
	tables[table_instance_id] = replacement
	next["table_states"] = tables
	next["canonical_snapshot_digest"] = _canonical_snapshot_digest(next)
	_record_receipt(next, receipt_id, fingerprint, {"kind": "table_migrated", "table_instance_id": table_instance_id})
	_bump_revision(next)
	return _success(next, receipt_id, {"kind": "table_migrated", "table_instance_id": table_instance_id})


static func register_scoped_rng_lease(state_value: Dictionary, producer_id: String, owner_id: String, scope: Dictionary, initial_state_value: Variant, receipt_id: String, expected_revision: int, expected_digest: String) -> Dictionary:
	var state := normalize_state(state_value)
	var scope_projection := _rng_scope_projection(scope)
	var lease_id := "%s_%s" % [owner_id, state_digest(scope_projection).substr(0, 16)]
	var fingerprint := state_digest({"kind": "rng_lease_registered", "producer_id": producer_id, "owner_id": owner_id, "scope": scope_projection, "initial_state": initial_state_value})
	var replay := _receipt_replay(state, receipt_id, fingerprint)
	if not replay.is_empty(): return replay
	var errors := _validate_protocol_cas(state, receipt_id, expected_revision, expected_digest)
	if owner_id not in KNOWN_RNG_OWNER_IDS or not _producer_owns_lease(producer_id, owner_id): errors.append("RNG lease registration uses an unknown or foreign owner class.")
	if scope_projection.is_empty(): errors.append("RNG lease registration requires a table/session/hand/action/request scope.")
	errors.append_array(_validate_bounded("RNG lease initial state", initial_state_value))
	var leases := _dict(state.get("rng_leases", {}))
	if leases.has(lease_id) and state_digest(_dict(leases.get(lease_id, {})).get("current_state")) != state_digest(initial_state_value):
		errors.append("scoped RNG lease identity is already bound to different initial state.")
	if not errors.is_empty(): return _failed(state, errors)
	var next := state.duplicate(true)
	leases = _dict(next.get("rng_leases", {}))
	leases[lease_id] = {"owner_id": owner_id, "stream_id": lease_id, "scope": scope_projection, "state_type": typeof(initial_state_value), "current_state": _copy_variant(initial_state_value), "receipts": []}
	next["rng_leases"] = leases
	_record_receipt(next, receipt_id, fingerprint, {"kind": "rng_lease_registered", "lease_id": lease_id})
	_bump_revision(next)
	return _success(next, receipt_id, {"kind": "rng_lease_registered", "lease_id": lease_id})


static func stage_prepared_operation_receipts(state_value: Dictionary, operations: Array, receipt_id: String, expected_revision: int, expected_digest: String) -> Dictionary:
	var state := normalize_state(state_value)
	var fingerprint := state_digest({"kind": "prepared_operations_staged", "operations": operations})
	var replay := _receipt_replay(state, receipt_id, fingerprint)
	if not replay.is_empty(): return replay
	var errors := _validate_protocol_cas(state, receipt_id, expected_revision, expected_digest)
	var ids: Dictionary = {}
	for operation_value in operations:
		var operation := _dict(operation_value)
		_append_unknown_keys("prepared operation", operation, ["operation_receipt_id", "request_id", "delivery_serial", "context_instance_id", "kind", "payload"], errors)
		var operation_id := str(operation.get("operation_receipt_id", ""))
		if not _valid_scoped_receipt(operation_id) or ids.has(operation_id): errors.append("prepared operation receipts must be unique stable scoped ids.")
		if str(operation.get("kind", "")) not in ["room", "travel"] or typeof(operation.get("payload")) != TYPE_DICTIONARY: errors.append("prepared operation requires a room/travel kind and bounded payload.")
		if int(operation.get("delivery_serial", 0)) <= 0 or not _valid_id(str(operation.get("request_id", ""))) or not _valid_id(str(operation.get("context_instance_id", ""))): errors.append("prepared operation requires request/context/delivery binding.")
		errors.append_array(_validate_bounded("prepared operation payload", operation.get("payload", {})))
		ids[operation_id] = true
	if not errors.is_empty(): return _failed(state, errors)
	var next := state.duplicate(true)
	var staged := _dict(next.get("staged_operation_receipts", {}))
	for operation_value in operations:
		var operation := _dict(operation_value)
		var operation_id := str(operation.get("operation_receipt_id", ""))
		if staged.has(operation_id) and state_digest(staged.get(operation_id)) != state_digest(operation): return _failed(state, ["prepared operation receipt conflicts with staged content."])
		var stored := operation.duplicate(true)
		stored["consumed"] = false
		staged[operation_id] = stored
	next["staged_operation_receipts"] = staged
	_record_receipt(next, receipt_id, fingerprint, {"kind": "prepared_operations_staged", "operation_receipt_ids": ids.keys()})
	_bump_revision(next)
	return _success(next, receipt_id, {"kind": "prepared_operations_staged", "operation_receipt_ids": ids.keys()})


static func stage_prepared_request(state_value: Dictionary, envelope_value: Dictionary, receipt_id: String, expected_revision: int, expected_digest: String) -> Dictionary:
	var state := normalize_state(state_value)
	var envelope := envelope_value.duplicate(true)
	var fingerprint := state_digest({"kind": "prepared_request_staged", "envelope": envelope})
	var replay := _receipt_replay(state, receipt_id, fingerprint)
	if not replay.is_empty(): return replay
	var errors := _validate_protocol_cas(state, receipt_id, expected_revision, expected_digest)
	errors.append_array(_validate_prepared_envelope(state, envelope))
	var request_id := _prepared_envelope_request_id(envelope)
	var requests := _dict(state.get("prepared_requests", {}))
	if requests.has(request_id):
		var existing := _dict(requests.get(request_id, {}))
		if int(existing.get("delivery_serial", 0)) == int(envelope.get("delivery_serial", 0)) and str(existing.get("payload_sha256", "")) != str(envelope.get("payload_sha256", "")):
			errors.append("same request and delivery_serial cannot be resubmitted with divergent payload.")
		else:
			errors.append("prepared request id is already staged.")
	if not errors.is_empty(): return _failed(state, errors)
	var next := state.duplicate(true)
	requests = _dict(next.get("prepared_requests", {}))
	var stored := envelope.duplicate(true)
	stored["request_id"] = request_id
	stored["status"] = "prepared"
	stored["prepared_receipt"] = receipt_id
	stored["table_id"] = _prepared_envelope_table_id(envelope)
	stored["producer_id"] = "craps" if str(envelope.get("consumer", "")) == "game.craps" else "poker"
	stored["game_id"] = stored["producer_id"]
	stored["context"] = _public_context_projection({"node_id": str(_dict(state.get("canonical_context", {})).get("node_id", "")), "environment_visit_id": str(envelope.get("environment_visit_id", "")), "night_instance_id": str(envelope.get("night_instance_id", "")), "context_instance_id": str(envelope.get("context_instance_id", ""))})
	stored["table_digest"] = str(envelope.get("expected_game_state_sha256", ""))
	requests[request_id] = stored
	next["prepared_requests"] = requests
	var serials := _dict(next.get("request_delivery_serials", {}))
	serials[str(stored.get("table_id", ""))] = int(envelope.get("delivery_serial", 0))
	next["request_delivery_serials"] = serials
	_append_acknowledgement(next, {"ack_id": "%s_prepared" % request_id, "kind": "request_prepared", "request_id": request_id, "phase": "prepared", "receipt_id": receipt_id})
	_record_receipt(next, receipt_id, fingerprint, {"kind": "prepared_request_staged", "request_id": request_id})
	_bump_revision(next)
	return _success(next, receipt_id, {"kind": "prepared_request_staged", "request_id": request_id})


static func respond_to_staged_request(state_value: Dictionary, request_id: String, response: String, acknowledgement: Dictionary, receipt_id: String, expected_revision: int, expected_digest: String) -> Dictionary:
	var state := normalize_state(state_value)
	var fingerprint := state_digest({"kind": "prepared_request_response", "request_id": request_id, "response": response, "acknowledgement": acknowledgement})
	var replay := _receipt_replay(state, receipt_id, fingerprint)
	if not replay.is_empty(): return replay
	var errors := _validate_protocol_cas(state, receipt_id, expected_revision, expected_digest)
	var requests := _dict(state.get("prepared_requests", {}))
	var request := _dict(requests.get(request_id, {}))
	if request.is_empty() or str(request.get("schema", "")) not in PREPARED_SCHEMAS: errors.append("typed prepared request is unknown.")
	errors.append_array(_validate_prepared_acknowledgement(acknowledgement, response))
	if response not in REQUEST_RESPONSES: errors.append("prepared request response must be accept, defer, or reject.")
	if str(request.get("status", "")) not in ["prepared", "deferred"]: errors.append("prepared request cannot receive this response in its current state.")
	var expired := _request_is_expired(state, request)
	if expired and response == "accept": errors.append("expired prepared request cannot be accepted.")
	if not request.is_empty() and str(acknowledgement.get("observed_game_state_sha256", "")) != state_digest(_dict(_dict(state.get("table_states", {})).get(str(request.get("table_id", "")), {}))):
		errors.append("prepared request response observed a different game-state digest.")
	if not errors.is_empty(): return _failed(state, errors)
	var next := state.duplicate(true)
	requests = _dict(next.get("prepared_requests", {}))
	request = _dict(requests.get(request_id, {}))
	var status := "expired" if expired else ("accepted" if response == "accept" else ("deferred" if response == "defer" else "rejected"))
	request["status"] = status
	request["acknowledgement"] = acknowledgement.duplicate(true)
	request["response_receipt"] = receipt_id
	requests[request_id] = request
	next["prepared_requests"] = requests
	_append_acknowledgement(next, {"ack_id": "%s_%s" % [request_id, status], "kind": "game_%s" % status, "request_id": request_id, "phase": "response", "receipt_id": receipt_id})
	_record_receipt(next, receipt_id, fingerprint, {"kind": "prepared_request_response", "request_id": request_id, "status": status})
	_bump_revision(next)
	return _success(next, receipt_id, {"kind": "prepared_request_response", "request_id": request_id, "status": status})


# Phase two is intentionally one CAS. Every effect is validated against the
# detached input state before the first write to `next`.
static func complete_prepared_game_request(state_value: Dictionary, completion_value: Dictionary) -> Dictionary:
	var state := normalize_state(state_value)
	var completion := completion_value.duplicate(true)
	var receipt_id := str(completion.get("transaction_id", ""))
	var fingerprint := state_digest(_completion_fingerprint_body(completion))
	var replay := _receipt_replay(state, receipt_id, fingerprint)
	if not replay.is_empty(): return replay
	var errors := _validate_atomic_completion(state, completion)
	if not errors.is_empty(): return _failed(state, errors)
	var request_id := str(completion.get("request_id", ""))
	var request := _dict(_dict(state.get("prepared_requests", {})).get(request_id, {}))
	var next := state.duplicate(true)
	var tables := _dict(next.get("table_states", {}))
	tables[str(request.get("table_id", ""))] = _dict(completion.get("replacement_table_state", {}))
	next["table_states"] = tables
	_apply_account_ops(next, _dictionary_array(completion.get("account_ops", [])))
	_apply_named_delta_ops(next, "trust", "subject_id", _dictionary_array(completion.get("trust_ops", [])))
	_apply_named_delta_ops(next, "tells", "pattern_id", _dictionary_array(completion.get("tell_ops", [])))
	_apply_rng_updates(next, str(request.get("producer_id", "")), receipt_id, _dictionary_array(completion.get("rng_updates", [])))
	_commit_facts(next, _dictionary_array(completion.get("facts", [])))
	_apply_staged_runtime_operations(next, request, _string_array(completion.get("prepared_operation_receipt_ids", [])), receipt_id)
	var requests := _dict(next.get("prepared_requests", {}))
	var stored := _dict(requests.get(request_id, {}))
	stored["status"] = "applied"
	stored["runtime_receipt"] = receipt_id
	var acknowledgement := _dict(completion.get("acknowledgement", {}))
	acknowledgement["status"] = "applied"
	acknowledgement["applied_transaction_id"] = receipt_id
	stored["acknowledgement"] = acknowledgement
	requests[request_id] = stored
	next["prepared_requests"] = requests
	_append_acknowledgement(next, {"ack_id": "%s_applied" % request_id, "kind": "runtime_applied", "request_id": request_id, "phase": "atomic_phase_2", "receipt_id": receipt_id})
	_stage_publications(next, request, completion)
	next["canonical_snapshot_digest"] = _canonical_snapshot_digest(next)
	var redacted := {"kind": "prepared_request_completed", "request_id": request_id, "status": "applied", "transaction_id": receipt_id, "travel_authorization_token": _travel_token_for_transaction(next, receipt_id)}
	_record_receipt(next, receipt_id, fingerprint, redacted)
	_bump_revision(next)
	return _success(next, receipt_id, redacted)


static func travel_preflight(state_value: Dictionary, transition_kind: String, target_id: String, authorization_token: String, consume: bool = false) -> Dictionary:
	var state := normalize_state(state_value)
	if not _has_live_host_boundary(state): return {"ok": true, "state": state, "required": false, "errors": []}
	var authorization := _dict(_dict(state.get("travel_authorizations", {})).get(authorization_token, {}))
	var errors: Array = []
	if authorization.is_empty() or bool(authorization.get("consumed", false)): errors.append("live game travel requires an unused host authorization token.")
	if str(authorization.get("transition_kind", "")) != transition_kind or str(authorization.get("target_id", "")) != target_id.strip_edges(): errors.append("travel authorization kind/target binding does not match.")
	if _dict(authorization.get("context", {})) != _dict(state.get("canonical_context", {})): errors.append("travel authorization context is stale.")
	if str(authorization.get("table_registry_sha256", "")) != state_digest(state.get("table_registry", {})): errors.append("travel authorization table binding is stale.")
	if not errors.is_empty(): return _failed(state, errors)
	if not consume: return {"ok": true, "state": state, "required": true, "errors": []}
	var next := state.duplicate(true)
	var authorizations := _dict(next.get("travel_authorizations", {}))
	authorization["consumed"] = true
	authorizations[authorization_token] = authorization
	next["travel_authorizations"] = authorizations
	_bump_revision(next)
	return {"ok": true, "state": next, "required": true, "errors": []}


static func game_command(producer_id: String, game_id: String, table_id: String, receipt_id: String, context: Dictionary, expected_table_digest: String, replacement_table_state: Dictionary, deltas: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"producer_id": producer_id.strip_edges(),
		"game_id": game_id.strip_edges(),
		"table_id": table_id.strip_edges(),
		"receipt_id": receipt_id.strip_edges(),
		"expected_runtime_revision": int(context.get("host_revision", -1)),
		"context": _public_context_projection(context),
		"expected_table_digest": expected_table_digest.strip_edges(),
		"replacement_table_state": replacement_table_state.duplicate(true),
		"account_ops": _dictionary_array(deltas.get("account_ops", [])),
		"trust_ops": _dictionary_array(deltas.get("trust_ops", [])),
		"tell_ops": _dictionary_array(deltas.get("tell_ops", [])),
		"facts": _dictionary_array(deltas.get("facts", [])),
		"prepared_acknowledgements": _dictionary_array(deltas.get("prepared_acknowledgements", [])),
		"external_warnings": _string_array(deltas.get("external_warnings", [])),
		"rng_updates": _dictionary_array(deltas.get("rng_updates", [])),
		"prepared_request": _dict(deltas.get("prepared_request", {})),
	}


static func pre_travel_hook(command_value: Dictionary, request: Dictionary) -> Dictionary:
	var command := command_value.duplicate(true)
	var errors: Array = []
	if str(request.get("kind", "")) != "travel":
		errors.append("pre-travel hook requires a prepared travel request.")
	if command.has("room_ops") or command.has("travel_ops"):
		errors.append("games cannot mutate room or travel runtime records.")
	if not errors.is_empty():
		return {"ok": false, "command": command, "errors": errors}
	command["prepared_request"] = request.duplicate(true)
	return {"ok": true, "command": command, "errors": []}


static func reduce_game_command(state_value: Dictionary, command_value: Dictionary) -> Dictionary:
	var state := normalize_state(state_value)
	var command := command_value.duplicate(true)
	var transaction := {
		"ok": true,
		"schema_version": SCHEMA_VERSION,
		"expected_revision": int(state.get("revision", 0)),
		"expected_state_digest": state_digest(state),
		"receipt_id": str(command.get("receipt_id", "")),
		"command_expected_runtime_revision": int(command.get("expected_runtime_revision", -1)),
		"fingerprint": "",
		"producer_id": str(command.get("producer_id", "")),
		"game_id": str(command.get("game_id", "")),
		"table_id": str(command.get("table_id", "")),
		"context": _dict(command.get("context", {})),
		"replacement_table_state": _dict(command.get("replacement_table_state", {})),
		"account_ops": _dictionary_array(command.get("account_ops", [])),
		"trust_ops": _dictionary_array(command.get("trust_ops", [])),
		"tell_ops": _dictionary_array(command.get("tell_ops", [])),
		"facts": _dictionary_array(command.get("facts", [])),
		"prepared_acknowledgements": _dictionary_array(command.get("prepared_acknowledgements", [])),
		"external_warnings": _string_array(command.get("external_warnings", [])),
		"rng_updates": _dictionary_array(command.get("rng_updates", [])),
		"prepared_request": _dict(command.get("prepared_request", {})),
	}
	transaction["fingerprint"] = _transaction_fingerprint(transaction)
	# Command-level idempotency is checked before table/account/context staleness so
	# a retry observes its stored result even after later canonical mutations.
	var replay := _receipt_replay(state, str(transaction.get("receipt_id", "")), str(transaction.get("fingerprint", "")))
	if not replay.is_empty(): return replay
	var errors := _validate_game_command(state, command)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	return transaction


static func commit_game_command(state_value: Dictionary, transaction_value: Dictionary) -> Dictionary:
	var state := normalize_state(state_value)
	var transaction := transaction_value.duplicate(true)
	var receipt_id := str(transaction.get("receipt_id", ""))
	var fingerprint := str(transaction.get("fingerprint", ""))
	if fingerprint != _transaction_fingerprint(transaction):
		return {"ok": false, "state": state, "errors": ["game transaction fingerprint does not match its typed effects."]}
	var replay := _receipt_replay(state, receipt_id, fingerprint)
	if not replay.is_empty():
		return replay
	var errors := _validate_transaction(state, transaction)
	if not errors.is_empty():
		return {"ok": false, "state": state, "errors": errors}
	var next := state.duplicate(true)
	var prepared_account_id := _prepared_account_id(state, str(transaction.get("producer_id", "")), str(transaction.get("table_id", "")))
	var tables := _dict(next.get("table_states", {}))
	tables[str(transaction.get("table_id", ""))] = _dict(transaction.get("replacement_table_state", {}))
	next["table_states"] = tables
	_apply_account_ops(next, _dictionary_array(transaction.get("account_ops", [])))
	_apply_named_delta_ops(next, "trust", "subject_id", _dictionary_array(transaction.get("trust_ops", [])))
	_apply_named_delta_ops(next, "tells", "pattern_id", _dictionary_array(transaction.get("tell_ops", [])))
	_apply_rng_updates(next, str(transaction.get("producer_id", "")), receipt_id, _dictionary_array(transaction.get("rng_updates", [])))
	_commit_facts(next, _dictionary_array(transaction.get("facts", [])))
	_commit_prepared_request(next, _dict(transaction.get("prepared_request", {})), receipt_id, str(transaction.get("producer_id", "")), str(transaction.get("game_id", "")), prepared_account_id)
	for acknowledgement_value in _dictionary_array(transaction.get("prepared_acknowledgements", [])):
		var acknowledgement := acknowledgement_value.duplicate(true)
		acknowledgement["receipt_id"] = receipt_id
		acknowledgement["phase"] = "prepared"
		_append_acknowledgement(next, acknowledgement)
	for warning_value in _string_array(transaction.get("external_warnings", [])):
		var warnings := _string_array(next.get("external_warnings", []))
		warnings.append(str(warning_value))
		next["external_warnings"] = warnings
	_record_receipt(next, receipt_id, fingerprint, {
		"kind": "game_command", "table_id": str(transaction.get("table_id", "")),
		"account_ops": _dictionary_array(transaction.get("account_ops", [])),
		"trust_ops": _dictionary_array(transaction.get("trust_ops", [])),
		"tell_ops": _dictionary_array(transaction.get("tell_ops", [])),
		"facts": _dictionary_array(transaction.get("facts", [])),
	})
	next["canonical_snapshot_digest"] = _canonical_snapshot_digest(next)
	_bump_revision(next)
	return {"ok": true, "state": next, "replayed": false, "receipt_id": receipt_id, "errors": []}


static func flush_game_facts(state_value: Dictionary, safe_boundary: int) -> Dictionary:
	var state := normalize_state(state_value)
	if safe_boundary < int(state.get("safe_boundary", 0)):
		return {"ok": false, "state": state, "processed": [], "errors": ["safe boundary cannot move backward."]}
	var order_errors := _validate_fact_order(state)
	if not order_errors.is_empty():
		return {"ok": false, "state": state, "processed": [], "errors": order_errors}
	var next := state.duplicate(true)
	var queue := _dictionary_array(next.get("fact_queue", []))
	queue.sort_custom(func(a: Variant, b: Variant) -> bool: return int((a as Dictionary).get("commit_order", 0)) < int((b as Dictionary).get("commit_order", 0)))
	var remaining: Array = []
	var log := _dictionary_array(next.get("fact_log", []))
	var processed: Array = []
	for fact_value in queue:
		var fact := fact_value as Dictionary
		if int(fact.get("target_boundary", 0)) <= safe_boundary:
			log.append(fact.duplicate(true))
			processed.append(_fact_id(fact))
		else:
			remaining.append(fact.duplicate(true))
	if log.size() > MAX_FACT_LOG:
		var remove_count := log.size() - MAX_FACT_LOG
		for _index in range(remove_count):
			var removed := log.pop_front() as Dictionary
			next["fact_compaction_floor"] = maxi(int(next.get("fact_compaction_floor", 0)), int(removed.get("commit_order", 0)))
	next["fact_log"] = log
	next["fact_queue"] = remaining
	next["safe_boundary"] = safe_boundary
	if not processed.is_empty() or safe_boundary != int(state.get("safe_boundary", 0)):
		_bump_revision(next)
	return {"ok": true, "state": next, "processed": processed, "errors": []}


static func respond_to_prepared_request(state_value: Dictionary, request_id: String, response: String, receipt_id: String, expected_revision: int, expected_digest: String) -> Dictionary:
	var state := normalize_state(state_value)
	var fingerprint := state_digest({"kind": "request_response", "request_id": request_id, "response": response})
	var replay := _receipt_replay(state, receipt_id, fingerprint)
	if not replay.is_empty(): return replay
	var errors := _validate_protocol_cas(state, receipt_id, expected_revision, expected_digest)
	var requests := _dict(state.get("prepared_requests", {}))
	var request := _dict(requests.get(request_id, {}))
	if request.is_empty(): errors.append("prepared request is unknown.")
	else: errors.append_array(_validate_stored_request_binding(state, request_id, request))
	if not REQUEST_RESPONSES.has(response): errors.append("prepared request response must be defer or accept.")
	if not ["prepared", "deferred"].has(str(request.get("status", ""))): errors.append("prepared request cannot receive this response in its current state.")
	if response == "accept" and state_digest(_dict(_dict(state.get("table_states", {})).get(str(request.get("table_id", "")), {}))) != str(request.get("table_digest", "")):
		errors.append("prepared request table digest changed before acceptance.")
	if not errors.is_empty(): return {"ok": false, "state": state, "errors": errors}
	var next := state.duplicate(true)
	requests = _dict(next.get("prepared_requests", {}))
	request = _dict(requests.get(request_id, {}))
	request["status"] = "deferred" if response == "defer" else "accepted"
	request["response_receipt"] = receipt_id
	requests[request_id] = request
	next["prepared_requests"] = requests
	_append_acknowledgement(next, {"ack_id": "%s_%s" % [request_id, response], "kind": "game_%s" % response, "request_id": request_id, "phase": "prepared", "receipt_id": receipt_id})
	_record_receipt(next, receipt_id, fingerprint, {"kind": "request_response", "request_id": request_id})
	_bump_revision(next)
	return {"ok": true, "state": next, "replayed": false, "errors": []}


static func complete_prepared_request_economy(state_value: Dictionary, request_id: String, account_ops: Array, receipt_id: String, expected_revision: int, expected_digest: String) -> Dictionary:
	var state := normalize_state(state_value)
	var fingerprint := state_digest({"kind": "economic_complete", "request_id": request_id, "account_ops": account_ops})
	var replay := _receipt_replay(state, receipt_id, fingerprint)
	if not replay.is_empty(): return replay
	var errors := _validate_protocol_cas(state, receipt_id, expected_revision, expected_digest)
	errors.append_array(_validate_account_ops(state, account_ops))
	var request := _dict(_dict(state.get("prepared_requests", {})).get(request_id, {}))
	if not request.is_empty(): errors.append_array(_validate_stored_request_binding(state, request_id, request))
	if str(request.get("status", "")) != "accepted": errors.append("prepared request must be accepted before economic completion.")
	if not request.is_empty() and state_digest(_dict(_dict(state.get("table_states", {})).get(str(request.get("table_id", "")), {}))) != str(request.get("table_digest", "")):
		errors.append("prepared request table changed before economic completion.")
	for operation_value in account_ops:
		var operation := _dict(operation_value)
		if str(operation.get("account_id", "")) != str(request.get("prepared_account_id", "")) or str(operation.get("fund_domain", "")) != str(request.get("prepared_fund_domain", "")):
			errors.append("prepared request economics attempted a different account or fund domain.")
	if not errors.is_empty(): return {"ok": false, "state": state, "errors": errors}
	var next := state.duplicate(true)
	_apply_account_ops(next, account_ops)
	next["canonical_snapshot_digest"] = _canonical_snapshot_digest(next)
	_set_request_status(next, request_id, "economic_complete", "economic_receipt", receipt_id)
	_append_acknowledgement(next, {"ack_id": "%s_economic" % request_id, "kind": "economic_complete", "request_id": request_id, "phase": "economic", "receipt_id": receipt_id})
	_record_receipt(next, receipt_id, fingerprint, {"kind": "economic_complete", "request_id": request_id})
	_bump_revision(next)
	return {"ok": true, "state": next, "replayed": false, "errors": []}


static func acknowledge_prepared_request_unwound(state_value: Dictionary, request_id: String, replacement_table_state: Dictionary, receipt_id: String, expected_revision: int, expected_digest: String) -> Dictionary:
	var state := normalize_state(state_value)
	var fingerprint := state_digest({"kind": "game_unwound", "request_id": request_id, "table": replacement_table_state})
	var replay := _receipt_replay(state, receipt_id, fingerprint)
	if not replay.is_empty(): return replay
	var errors := _validate_protocol_cas(state, receipt_id, expected_revision, expected_digest)
	var request := _dict(_dict(state.get("prepared_requests", {})).get(request_id, {}))
	if not request.is_empty(): errors.append_array(_validate_stored_request_binding(state, request_id, request))
	if str(request.get("status", "")) != "economic_complete": errors.append("prepared request must complete economics before game unwind.")
	if not request.is_empty() and state_digest(_dict(_dict(state.get("table_states", {})).get(str(request.get("table_id", "")), {}))) != str(request.get("table_digest", "")):
		errors.append("prepared request table changed before game unwind.")
	if replacement_table_state.is_empty() or bool(replacement_table_state.get("active", true)):
		errors.append("game unwind must publish an inactive retained table state.")
	if str(replacement_table_state.get("producer_id", "")) != str(request.get("producer_id", "")) or str(replacement_table_state.get("game_id", "")) != str(request.get("game_id", "")):
		errors.append("game unwind cannot switch table producer/game ownership.")
	if str(request.get("producer_id", "")) == "craps" and str(replacement_table_state.get("prepared_account_id", "player_bankroll")) != str(request.get("prepared_account_id", "")):
		errors.append("game unwind cannot switch its prepared account identity.")
	errors.append_array(_validate_bounded("game unwind table state", replacement_table_state))
	if not errors.is_empty(): return {"ok": false, "state": state, "errors": errors}
	var next := state.duplicate(true)
	var tables := _dict(next.get("table_states", {}))
	tables[str(request.get("table_id", ""))] = replacement_table_state.duplicate(true)
	next["table_states"] = tables
	next["canonical_snapshot_digest"] = _canonical_snapshot_digest(next)
	_set_request_status(next, request_id, "game_unwound", "unwind_receipt", receipt_id)
	var requests := _dict(next.get("prepared_requests", {}))
	var stored_request := _dict(requests.get(request_id, {}))
	stored_request["unwound_table_digest"] = state_digest(replacement_table_state)
	requests[request_id] = stored_request
	next["prepared_requests"] = requests
	_append_acknowledgement(next, {"ack_id": "%s_unwound" % request_id, "kind": "game_unwound", "request_id": request_id, "phase": "runtime", "receipt_id": receipt_id})
	_record_receipt(next, receipt_id, fingerprint, {"kind": "game_unwound", "request_id": request_id})
	_bump_revision(next)
	return {"ok": true, "state": next, "replayed": false, "errors": []}


static func apply_prepared_request_runtime(state_value: Dictionary, request_id: String, receipt_id: String, expected_revision: int, expected_digest: String) -> Dictionary:
	var state := normalize_state(state_value)
	var fingerprint := state_digest({"kind": "runtime_applied", "request_id": request_id})
	var replay := _receipt_replay(state, receipt_id, fingerprint)
	if not replay.is_empty(): return replay
	var errors := _validate_protocol_cas(state, receipt_id, expected_revision, expected_digest)
	var request := _dict(_dict(state.get("prepared_requests", {})).get(request_id, {}))
	if not request.is_empty(): errors.append_array(_validate_stored_request_binding(state, request_id, request))
	if str(request.get("status", "")) != "game_unwound": errors.append("prepared request requires economic completion and game unwind before runtime apply.")
	if not request.is_empty() and state_digest(_dict(_dict(state.get("table_states", {})).get(str(request.get("table_id", "")), {}))) != str(request.get("unwound_table_digest", "")):
		errors.append("prepared request unwound table changed before runtime apply.")
	if int(request.get("target_boundary", 0)) > int(state.get("safe_boundary", 0)): errors.append("prepared request target safe boundary has not been reached.")
	if int(request.get("expires_at_boundary", 0)) < int(state.get("safe_boundary", 0)): errors.append("prepared request expired before runtime apply.")
	if not errors.is_empty(): return {"ok": false, "state": state, "errors": errors}
	var next := state.duplicate(true)
	_set_request_status(next, request_id, "applied", "runtime_receipt", receipt_id)
	_append_acknowledgement(next, {"ack_id": "%s_applied" % request_id, "kind": "runtime_applied", "request_id": request_id, "phase": "runtime", "receipt_id": receipt_id})
	_record_receipt(next, receipt_id, fingerprint, {"kind": "runtime_applied", "request_id": request_id})
	_bump_revision(next)
	return {"ok": true, "state": next, "replayed": false, "errors": []}


static func state_digest(value: Variant) -> String:
	return JSON.stringify(_canonical_variant(value)).sha256_text()


static func _validate_game_command(state: Dictionary, command: Dictionary) -> Array:
	var errors: Array = []
	errors.append_array(_validate_canonical_snapshot(state))
	errors.append_array(_validate_rng_registry(state))
	_append_unknown_keys("game command", command, ["schema_version", "producer_id", "game_id", "table_id", "receipt_id", "expected_runtime_revision", "context", "expected_table_digest", "replacement_table_state", "account_ops", "trust_ops", "tell_ops", "facts", "prepared_acknowledgements", "external_warnings", "rng_updates", "prepared_request"], errors)
	if int(command.get("schema_version", 0)) != SCHEMA_VERSION: errors.append("game command schema_version is invalid.")
	for key in ["producer_id", "game_id", "table_id"]:
		if not _valid_id(str(command.get(key, ""))): errors.append("game command requires valid %s." % key)
	if not _valid_scoped_receipt(str(command.get("receipt_id", ""))): errors.append("game command requires a stable scoped receipt_id.")
	errors.append_array(_validate_context(_dict(command.get("context", {}))))
	if not _dict(state.get("canonical_context", {})).is_empty() and _dict(command.get("context", {})) != _dict(state.get("canonical_context", {})): errors.append("game command context does not match the canonical host context.")
	var command_revision := int(command.get("expected_runtime_revision", -1))
	if command_revision >= 0 and command_revision != int(state.get("revision", 0)): errors.append("game command expected runtime revision is stale.")
	var table_id := str(command.get("table_id", ""))
	var tables := _dict(state.get("table_states", {}))
	if not tables.has(table_id): errors.append("game command references an unknown table.")
	errors.append_array(_validate_table_ownership(state, str(command.get("producer_id", "")), str(command.get("game_id", "")), table_id, _dict(command.get("replacement_table_state", {}))))
	if str(command.get("expected_table_digest", "")) != state_digest(_dict(tables.get(table_id, {}))): errors.append("game command table digest is stale.")
	if typeof(command.get("replacement_table_state")) != TYPE_DICTIONARY: errors.append("game command requires a replacement table state.")
	errors.append_array(_validate_bounded("replacement table state", command.get("replacement_table_state", {})))
	errors.append_array(_validate_bounded("game command effects", {
		"account_ops": command.get("account_ops", []), "trust_ops": command.get("trust_ops", []), "tell_ops": command.get("tell_ops", []),
		"facts": command.get("facts", []), "prepared_acknowledgements": command.get("prepared_acknowledgements", []),
		"external_warnings": command.get("external_warnings", []), "rng_updates": command.get("rng_updates", []), "prepared_request": command.get("prepared_request", {}),
	}))
	errors.append_array(_validate_producer_effects(state, command, table_id))
	errors.append_array(_validate_account_ops(state, _array(command.get("account_ops", []))))
	errors.append_array(_validate_named_delta_ops(state, "trust", _array(command.get("trust_ops", [])), "subject_id"))
	errors.append_array(_validate_named_delta_ops(state, "tell", _array(command.get("tell_ops", [])), "pattern_id"))
	if _array(state.get("fact_queue", [])).size() + _array(command.get("facts", [])).size() > MAX_QUEUE: errors.append("GameFact queue capacity reached.")
	var batch_facts: Dictionary = {}
	for fact_value in _array(command.get("facts", [])):
		var fact := _dict(fact_value)
		errors.append_array(_validate_fact(state, fact, str(command.get("producer_id", "")), str(command.get("game_id", "")), table_id, _dict(command.get("context", {}))))
		var fact_id := _fact_id(fact)
		var fact_fingerprint := state_digest(fact)
		if batch_facts.has(fact_id) and str(batch_facts.get(fact_id, "")) != fact_fingerprint: errors.append("GameFact batch reuses one receipt for conflicting content.")
		elif batch_facts.has(fact_id): errors.append("GameFact batch contains a duplicate receipt.")
		batch_facts[fact_id] = fact_fingerprint
	for ack_value in _array(command.get("prepared_acknowledgements", [])):
		var acknowledgement := _dict(ack_value)
		_append_unknown_keys("prepared acknowledgement", acknowledgement, ["ack_id", "kind", "message"], errors)
		if not _valid_id(str(acknowledgement.get("ack_id", ""))) or not _valid_id(str(acknowledgement.get("kind", ""))): errors.append("prepared acknowledgement requires ack_id and kind.")
	for warning_value in _array(command.get("external_warnings", [])):
		if typeof(warning_value) != TYPE_STRING or str(warning_value).strip_edges().is_empty() or str(warning_value).length() > MAX_TEXT: errors.append("external warning must be bounded public text.")
	var updated_lease_ids: Dictionary = {}
	for update_value in _array(command.get("rng_updates", [])):
		var lease_id := str(_dict(update_value).get("lease_id", ""))
		if updated_lease_ids.has(lease_id): errors.append("game command cannot update one RNG lease more than once.")
		updated_lease_ids[lease_id] = true
		errors.append_array(_validate_rng_update(state, str(command.get("producer_id", "")), str(command.get("receipt_id", "")), _dict(update_value)))
	var request := _dict(command.get("prepared_request", {}))
	if not request.is_empty(): errors.append_array(_validate_prepared_request(state, request, table_id, _dict(command.get("context", {})), _dict(command.get("replacement_table_state", {}))))
	return errors


static func _validate_transaction(state: Dictionary, transaction: Dictionary) -> Array:
	var errors: Array = []
	errors.append_array(_validate_canonical_snapshot(state))
	errors.append_array(_validate_rng_registry(state))
	_append_unknown_keys("game transaction", transaction, ["ok", "schema_version", "expected_revision", "expected_state_digest", "command_expected_runtime_revision", "receipt_id", "fingerprint", "producer_id", "game_id", "table_id", "context", "replacement_table_state", "account_ops", "trust_ops", "tell_ops", "facts", "prepared_acknowledgements", "external_warnings", "rng_updates", "prepared_request"], errors)
	if not bool(transaction.get("ok", false)): errors.append("game transaction must be an accepted reducer result.")
	if int(transaction.get("schema_version", 0)) != SCHEMA_VERSION: errors.append("game transaction schema_version is invalid.")
	if int(transaction.get("expected_revision", -1)) != int(state.get("revision", 0)): errors.append("game transaction revision is stale.")
	if str(transaction.get("expected_state_digest", "")) != state_digest(state): errors.append("game transaction state digest is stale.")
	if not _valid_scoped_receipt(str(transaction.get("receipt_id", ""))) or str(transaction.get("fingerprint", "")).is_empty(): errors.append("game transaction receipt/fingerprint is invalid.")
	for key in ["producer_id", "game_id", "table_id"]:
		if not _valid_id(str(transaction.get(key, ""))): errors.append("game transaction requires valid %s." % key)
	errors.append_array(_validate_context(_dict(transaction.get("context", {}))))
	if not _dict(state.get("canonical_context", {})).is_empty() and _dict(transaction.get("context", {})) != _dict(state.get("canonical_context", {})): errors.append("game transaction context does not match the canonical host context.")
	var table_id := str(transaction.get("table_id", ""))
	if not _dict(state.get("table_states", {})).has(table_id): errors.append("game transaction references an unknown table.")
	errors.append_array(_validate_table_ownership(state, str(transaction.get("producer_id", "")), str(transaction.get("game_id", "")), table_id, _dict(transaction.get("replacement_table_state", {}))))
	if typeof(transaction.get("replacement_table_state")) != TYPE_DICTIONARY: errors.append("game transaction replacement table state is invalid.")
	errors.append_array(_validate_bounded("replacement table state", transaction.get("replacement_table_state", {})))
	errors.append_array(_validate_bounded("game transaction effects", {
		"account_ops": transaction.get("account_ops", []), "trust_ops": transaction.get("trust_ops", []), "tell_ops": transaction.get("tell_ops", []),
		"facts": transaction.get("facts", []), "prepared_acknowledgements": transaction.get("prepared_acknowledgements", []),
		"external_warnings": transaction.get("external_warnings", []), "rng_updates": transaction.get("rng_updates", []), "prepared_request": transaction.get("prepared_request", {}),
	}))
	errors.append_array(_validate_producer_effects(state, transaction, table_id))
	errors.append_array(_validate_account_ops(state, _array(transaction.get("account_ops", []))))
	errors.append_array(_validate_named_delta_ops(state, "trust", _array(transaction.get("trust_ops", [])), "subject_id"))
	errors.append_array(_validate_named_delta_ops(state, "tell", _array(transaction.get("tell_ops", [])), "pattern_id"))
	if _array(state.get("fact_queue", [])).size() + _array(transaction.get("facts", [])).size() > MAX_QUEUE: errors.append("GameFact queue capacity reached.")
	var batch_facts: Dictionary = {}
	for fact_value in _array(transaction.get("facts", [])):
		var fact := _dict(fact_value)
		errors.append_array(_validate_fact(state, fact, str(transaction.get("producer_id", "")), str(transaction.get("game_id", "")), table_id, _dict(transaction.get("context", {}))))
		var fact_id := _fact_id(fact)
		var fact_fingerprint := state_digest(fact)
		if batch_facts.has(fact_id) and str(batch_facts.get(fact_id, "")) != fact_fingerprint: errors.append("GameFact batch reuses one receipt for conflicting content.")
		elif batch_facts.has(fact_id): errors.append("GameFact batch contains a duplicate receipt.")
		batch_facts[fact_id] = fact_fingerprint
	for ack_value in _array(transaction.get("prepared_acknowledgements", [])):
		var acknowledgement := _dict(ack_value)
		_append_unknown_keys("prepared acknowledgement", acknowledgement, ["ack_id", "kind", "message"], errors)
		if not _valid_id(str(acknowledgement.get("ack_id", ""))) or not _valid_id(str(acknowledgement.get("kind", ""))): errors.append("prepared acknowledgement requires ack_id and kind.")
	for warning_value in _array(transaction.get("external_warnings", [])):
		if typeof(warning_value) != TYPE_STRING or str(warning_value).strip_edges().is_empty() or str(warning_value).length() > MAX_TEXT: errors.append("external warning must be bounded public text.")
	var updated_lease_ids: Dictionary = {}
	for update_value in _array(transaction.get("rng_updates", [])):
		var lease_id := str(_dict(update_value).get("lease_id", ""))
		if updated_lease_ids.has(lease_id): errors.append("game transaction cannot update one RNG lease more than once.")
		updated_lease_ids[lease_id] = true
		errors.append_array(_validate_rng_update(state, str(transaction.get("producer_id", "")), str(transaction.get("receipt_id", "")), _dict(update_value)))
	var request := _dict(transaction.get("prepared_request", {}))
	if not request.is_empty(): errors.append_array(_validate_prepared_request(state, request, table_id, _dict(transaction.get("context", {})), _dict(transaction.get("replacement_table_state", {}))))
	return errors


static func _validate_account_ops(state: Dictionary, operations: Array) -> Array:
	var errors: Array = []
	var domains: Dictionary = {}
	var account_ids: Dictionary = {}
	var accounts := _dict(state.get("accounts", {}))
	for operation_value in operations:
		var operation := _dict(operation_value)
		_append_unknown_keys("account operation", operation, ["account_id", "fund_domain", "account_before", "account_after", "delta", "reason"], errors)
		var account_id := str(operation.get("account_id", ""))
		var domain := str(operation.get("fund_domain", ""))
		var account := _dict(accounts.get(account_id, {}))
		if not _valid_id(account_id) or account_ids.has(account_id) or not ACCOUNT_DOMAINS.has(domain) or str(account.get("fund_domain", "")) != domain:
			errors.append("account operation requires a unique persisted account_id and matching fund_domain.")
		if typeof(operation.get("account_before")) != TYPE_INT or typeof(operation.get("account_after")) != TYPE_INT or typeof(operation.get("delta")) != TYPE_INT or str(operation.get("reason", "")).strip_edges().is_empty():
			errors.append("account operation requires explicit before/after/delta and reason.")
		elif int(account.get("balance", 0)) != int(operation.get("account_before", 0)) or int(operation.get("account_after", 0)) != int(operation.get("account_before", 0)) + int(operation.get("delta", 0)):
			errors.append("account operation before/after CAS is stale or inconsistent.")
		elif int(operation.get("account_after", 0)) < 0:
			errors.append("account operation would make %s negative." % account_id)
		account_ids[account_id] = true
		domains[domain] = true
	if domains.size() > 1: errors.append("game transaction cannot mix account domains.")
	return errors


static func _validate_named_delta_ops(state: Dictionary, label: String, operations: Array, id_key: String) -> Array:
	var errors: Array = []
	var values := _dict(state.get("trust" if label == "trust" else "tells", {}))
	var ids: Dictionary = {}
	for operation_value in operations:
		var operation := _dict(operation_value)
		_append_unknown_keys("%s operation" % label, operation, [id_key, "before", "after", "delta", "reason"], errors)
		var stable_id := str(operation.get(id_key, ""))
		var valid_stable_id := _valid_id(stable_id) if label == "trust" else _valid_pattern_id(stable_id)
		if not valid_stable_id or ids.has(stable_id) or typeof(operation.get("before")) != TYPE_INT or typeof(operation.get("after")) != TYPE_INT or typeof(operation.get("delta")) != TYPE_INT or str(operation.get("reason", "")).strip_edges().is_empty():
			errors.append("%s operation requires unique %s, before/after/delta, and reason." % [label, id_key])
		elif int(values.get(stable_id, 0)) != int(operation.get("before", 0)) or int(operation.get("after", 0)) != int(operation.get("before", 0)) + int(operation.get("delta", 0)):
			errors.append("%s operation before/after CAS is stale or inconsistent." % label)
		ids[stable_id] = true
	return errors


static func _validate_fact(state: Dictionary, fact: Dictionary, producer_id: String, game_id: String, table_id: String, context: Dictionary) -> Array:
	var errors: Array = []
	_append_unknown_keys("GameFact", fact, ["schema_version", "fact_type", "producer_id", "game_id", "table_id", "context", "producer_receipt", "scenario_receipt", "target_boundary", "payload", "commit_order"], errors)
	if int(fact.get("schema_version", 0)) != FACT_SCHEMA_VERSION or not _valid_id(str(fact.get("fact_type", ""))) or not _valid_id(str(fact.get("game_id", ""))): errors.append("GameFact type/schema is invalid.")
	if str(fact.get("producer_id", "")) != producer_id or str(fact.get("game_id", "")) != game_id or str(fact.get("table_id", "")) != table_id: errors.append("GameFact producer/game/table ownership is invalid.")
	if _dict(fact.get("context", {})) != context: errors.append("GameFact context does not match its prepared game context.")
	if not _valid_scoped_receipt(str(fact.get("producer_receipt", ""))) or not _valid_scoped_receipt(str(fact.get("scenario_receipt", ""))): errors.append("GameFact requires producer and scenario receipts.")
	if int(fact.get("commit_order", 0)) != 0: errors.append("GameFact commit_order is host-owned.")
	if int(fact.get("target_boundary", -1)) < int(state.get("safe_boundary", 0)): errors.append("GameFact targets an already-passed safe boundary.")
	if typeof(fact.get("payload")) != TYPE_DICTIONARY: errors.append("GameFact payload must be a dictionary.")
	errors.append_array(_validate_bounded("GameFact payload", fact.get("payload", {})))
	var fact_id := _fact_id(fact)
	var fingerprint := state_digest(fact)
	var receipts := _dict(state.get("fact_receipts", {}))
	if not receipts.has(fact_id) and receipts.size() >= MAX_RECEIPTS: errors.append("GameFact lifetime receipt limit reached.")
	if receipts.has(fact_id) and str(receipts.get(fact_id, "")) != fingerprint: errors.append("GameFact receipt was reused for conflicting content.")
	return errors


static func _validate_rng_update(state: Dictionary, producer_id: String, command_receipt: String, update: Dictionary) -> Array:
	var errors: Array = []
	_append_unknown_keys("RNG lease update", update, ["lease_id", "owner_id", "before_state", "after_state", "receipt_id"], errors)
	var lease_id := str(update.get("lease_id", ""))
	var owner_id := str(update.get("owner_id", ""))
	var lease := _dict(_dict(state.get("rng_leases", {})).get(lease_id, {}))
	if lease.is_empty() or str(lease.get("owner_id", "")) != owner_id or not _producer_owns_lease(producer_id, owner_id): errors.append("RNG update uses a wrong or foreign lease.")
	if str(update.get("receipt_id", "")) != command_receipt: errors.append("RNG lease update must share the game command receipt.")
	if state_digest(update.get("before_state")) != state_digest(lease.get("current_state")): errors.append("RNG lease before_state is stale.")
	if state_digest(update.get("before_state")) == state_digest(update.get("after_state")): errors.append("RNG lease after_state must advance.")
	return errors


static func _validate_prepared_request(state: Dictionary, request: Dictionary, table_id: String, context: Dictionary, expected_table_state: Dictionary = {}) -> Array:
	var errors: Array = []
	_append_unknown_keys("prepared request", request, ["schema_version", "request_id", "kind", "table_id", "context", "table_digest", "target_boundary", "delivery_serial", "expires_at_boundary", "payload", "status"], errors)
	var request_id := str(request.get("request_id", ""))
	if int(request.get("schema_version", 0)) != REQUEST_SCHEMA_VERSION or not _valid_id(request_id) or not REQUEST_KINDS.has(str(request.get("kind", ""))): errors.append("prepared request type/schema/id is invalid.")
	if str(request.get("table_id", "")) != table_id or _dict(request.get("context", {})) != context: errors.append("prepared request table/context is invalid.")
	if str(request.get("status", "")) != "prepared": errors.append("new prepared request must start prepared.")
	var table_state := expected_table_state if not expected_table_state.is_empty() else _dict(_dict(state.get("table_states", {})).get(table_id, {}))
	if str(request.get("table_digest", "")) != state_digest(table_state): errors.append("prepared request table digest is stale.")
	var target := int(request.get("target_boundary", -1))
	var expiry := int(request.get("expires_at_boundary", -1))
	if target < int(state.get("safe_boundary", 0)) or expiry < target: errors.append("prepared request boundary/expiry is invalid.")
	var expected_serial := int(_dict(state.get("request_delivery_serials", {})).get(table_id, 0)) + 1
	if int(request.get("delivery_serial", 0)) != expected_serial: errors.append("prepared request delivery_serial is out of order.")
	if _dict(state.get("prepared_requests", {})).has(request_id): errors.append("prepared request id already exists.")
	var payload := _dict(request.get("payload", {}))
	if str(request.get("kind", "")) == "travel" and not _valid_id(str(payload.get("target_node_id", ""))): errors.append("prepared travel request requires target_node_id.")
	if str(request.get("kind", "")) == "interruption" and not _valid_id(str(payload.get("reason_id", ""))): errors.append("prepared interruption requires reason_id.")
	return errors


static func _validate_stored_request_binding(state: Dictionary, request_id: String, request: Dictionary) -> Array:
	var errors: Array = []
	var table_id := str(request.get("table_id", ""))
	var producer_id := str(request.get("producer_id", ""))
	var game_id := str(request.get("game_id", ""))
	var table := _dict(_dict(state.get("table_states", {})).get(table_id, {}))
	if str(request.get("request_id", "")) != request_id or table.is_empty(): errors.append("stored prepared request identity/table binding is invalid.")
	if str(table.get("producer_id", "")) != producer_id or str(table.get("game_id", "")) != game_id: errors.append("stored prepared request producer/game binding is invalid.")
	var prepared_account_id := str(request.get("prepared_account_id", ""))
	var prepared_account := _dict(_dict(state.get("accounts", {})).get(prepared_account_id, {}))
	if prepared_account_id != _prepared_account_id(state, producer_id, table_id) or str(prepared_account.get("fund_domain", "")) != str(request.get("prepared_fund_domain", "")):
		errors.append("stored prepared request account/fund binding is invalid.")
	errors.append_array(_validate_context(_dict(request.get("context", {}))))
	return errors


static func _validate_context(context: Dictionary) -> Array:
	var errors: Array = []
	_append_unknown_keys("public game context", context, ["node_id", "environment_visit_id", "night_instance_id", "context_instance_id"], errors)
	for key in ["node_id", "environment_visit_id", "night_instance_id", "context_instance_id"]:
		if not _valid_id(str(context.get(key, ""))): errors.append("public game context requires persisted %s." % key)
	return errors


static func _public_context_projection(context: Dictionary) -> Dictionary:
	return public_context(
		str(context.get("node_id", "")),
		str(context.get("environment_visit_id", "")),
		str(context.get("night_instance_id", "")),
		str(context.get("context_instance_id", ""))
	)


static func _validate_protocol_cas(state: Dictionary, receipt_id: String, expected_revision: int, expected_digest: String) -> Array:
	var errors: Array = []
	errors.append_array(_validate_canonical_snapshot(state))
	if not _valid_scoped_receipt(receipt_id): errors.append("protocol mutation requires a stable scoped receipt.")
	if _dict(state.get("authoritative_receipts", {})).size() >= MAX_RECEIPTS: errors.append("host transaction lifetime receipt limit reached.")
	if expected_revision != int(state.get("revision", 0)): errors.append("protocol mutation revision is stale.")
	if expected_digest != state_digest(state): errors.append("protocol mutation state digest is stale.")
	return errors


static func _validate_fact_order(state: Dictionary) -> Array:
	var errors: Array = []
	var floor := int(state.get("fact_compaction_floor", 0))
	var seen: Dictionary = {}
	var previous := floor
	var combined := _dictionary_array(state.get("fact_log", [])) + _dictionary_array(state.get("fact_queue", []))
	combined.sort_custom(func(a: Variant, b: Variant) -> bool: return int((a as Dictionary).get("commit_order", 0)) < int((b as Dictionary).get("commit_order", 0)))
	for fact_value in combined:
		var order := int((fact_value as Dictionary).get("commit_order", 0))
		if order <= floor or seen.has(order) or order <= previous: errors.append("GameFact commit order is invalid or out of order.")
		seen[order] = true
		previous = order
	return errors


static func _commit_facts(state: Dictionary, facts: Array) -> void:
	var queue := _dictionary_array(state.get("fact_queue", []))
	var receipts := _dict(state.get("fact_receipts", {}))
	for fact_value in facts:
		var fact := (fact_value as Dictionary).duplicate(true)
		var fact_id := _fact_id(fact)
		if receipts.has(fact_id): continue
		state["fact_commit_order"] = int(state.get("fact_commit_order", 0)) + 1
		fact["commit_order"] = int(state.get("fact_commit_order", 0))
		receipts[fact_id] = state_digest(fact_value)
		queue.append(fact)
	state["fact_receipts"] = receipts
	state["fact_queue"] = queue


static func _commit_prepared_request(state: Dictionary, request: Dictionary, receipt_id: String, producer_id: String, game_id: String, prepared_account_id: String) -> void:
	if request.is_empty(): return
	var requests := _dict(state.get("prepared_requests", {}))
	var stored := request.duplicate(true)
	stored["prepared_receipt"] = receipt_id
	stored["producer_id"] = producer_id
	stored["game_id"] = game_id
	stored["prepared_account_id"] = prepared_account_id
	stored["prepared_fund_domain"] = str(_dict(_dict(state.get("accounts", {})).get(prepared_account_id, {})).get("fund_domain", ""))
	requests[str(stored.get("request_id", ""))] = stored
	state["prepared_requests"] = requests
	var serials := _dict(state.get("request_delivery_serials", {}))
	serials[str(stored.get("table_id", ""))] = int(stored.get("delivery_serial", 0))
	state["request_delivery_serials"] = serials
	_append_acknowledgement(state, {"ack_id": "%s_prepared" % str(stored.get("request_id", "")), "kind": "request_prepared", "request_id": str(stored.get("request_id", "")), "phase": "prepared", "receipt_id": receipt_id})


static func _apply_account_ops(state: Dictionary, operations: Array) -> void:
	var accounts := _dict(state.get("accounts", {}))
	for operation_value in operations:
		var operation := operation_value as Dictionary
		var account_id := str(operation.get("account_id", ""))
		var account := _dict(accounts.get(account_id, {}))
		account["fund_domain"] = str(operation.get("fund_domain", ""))
		account["balance"] = int(operation.get("account_after", 0))
		accounts[account_id] = account
	state["accounts"] = accounts


static func _apply_named_delta_ops(state: Dictionary, state_key: String, id_key: String, operations: Array) -> void:
	var values := _dict(state.get(state_key, {}))
	for operation_value in operations:
		var operation := operation_value as Dictionary
		var stable_id := str(operation.get(id_key, ""))
		values[stable_id] = int(operation.get("after", 0))
	state[state_key] = values


static func _apply_rng_updates(state: Dictionary, _producer_id: String, receipt_id: String, updates: Array) -> void:
	var leases := _dict(state.get("rng_leases", {}))
	for update_value in updates:
		var update := update_value as Dictionary
		var lease_id := str(update.get("lease_id", ""))
		var lease := _dict(leases.get(lease_id, {}))
		lease["current_state"] = _copy_variant(update.get("after_state"))
		var receipts := _string_array(lease.get("receipts", []))
		if not receipts.has(receipt_id): receipts.append(receipt_id)
		lease["receipts"] = receipts
		leases[lease_id] = lease
	state["rng_leases"] = leases


static func _producer_owns_lease(producer_id: String, owner_id: String) -> bool:
	if producer_id == "scenario": return owner_id == "scenario"
	if producer_id == "craps": return owner_id in ["craps_throw", "craps_recovery"]
	if producer_id == "poker": return owner_id == "poker_cards" or POKER_POLICY_OWNER_IDS.has(owner_id)
	return owner_id == producer_id


static func _prepared_account_id(state: Dictionary, producer_id: String, table_id: String) -> String:
	if producer_id == "poker": return "player_bankroll"
	if producer_id != "craps": return ""
	var table := _dict(_dict(state.get("table_states", {})).get(table_id, {}))
	var selected := str(table.get("prepared_account_id", "player_bankroll"))
	return selected if ["player_bankroll", "grand_casino_chips"].has(selected) else ""


static func _validate_table_ownership(state: Dictionary, producer_id: String, game_id: String, table_id: String, replacement: Dictionary) -> Array:
	var errors: Array = []
	var table := _dict(_dict(state.get("table_states", {})).get(table_id, {}))
	if table.is_empty(): return errors
	if str(table.get("producer_id", "")) != producer_id or str(table.get("game_id", "")) != game_id:
		errors.append("game command producer/game does not own this table.")
	if str(replacement.get("producer_id", "")) != producer_id or str(replacement.get("game_id", "")) != game_id:
		errors.append("replacement table state cannot remove or switch producer/game ownership.")
	if producer_id == "craps":
		var prepared_before := str(table.get("prepared_account_id", "player_bankroll"))
		var prepared_after := str(replacement.get("prepared_account_id", "player_bankroll"))
		if prepared_before != prepared_after or not ["player_bankroll", "grand_casino_chips"].has(prepared_after):
			errors.append("replacement Craps table state cannot switch its prepared account identity.")
	return errors


static func _validate_producer_effects(state: Dictionary, command: Dictionary, table_id: String) -> Array:
	var errors: Array = []
	var producer_id := str(command.get("producer_id", ""))
	var allowed_account := _prepared_account_id(state, producer_id, table_id)
	for operation_value in _array(command.get("account_ops", [])):
		var operation := _dict(operation_value)
		if allowed_account.is_empty() or str(operation.get("account_id", "")) != allowed_account:
			errors.append("game producer attempted a cross-account mutation.")
	if producer_id == "craps" and (not _array(command.get("trust_ops", [])).is_empty() or not _array(command.get("tell_ops", [])).is_empty()):
		errors.append("Craps cannot author trust or tell effects.")
	if producer_id != "poker" and producer_id != "craps" and (not _array(command.get("account_ops", [])).is_empty() or not _array(command.get("trust_ops", [])).is_empty() or not _array(command.get("tell_ops", [])).is_empty()):
		errors.append("game producer has no registered cross-state effect authority.")
	if producer_id == "poker":
		for operation_value in _array(command.get("account_ops", [])):
			if str(_dict(operation_value).get("fund_domain", "")) != "bankroll": errors.append("Poker cannot mutate casino chips.")
		for operation_value in _array(command.get("trust_ops", [])):
			if not POKER_CREW_MEMBER_IDS.has(str(_dict(operation_value).get("subject_id", ""))): errors.append("Poker trust effects require a registered Crew subject.")
		for operation_value in _array(command.get("tell_ops", [])):
			var parts := str(_dict(operation_value).get("pattern_id", "")).split(":", false)
			if parts.size() != 2 or not POKER_CREW_MEMBER_IDS.has(str(parts[0])): errors.append("Poker tell effects require a member-scoped Crew pattern.")
	return errors


static func _owned_rng_lease_projection(state: Dictionary, producer_id: String) -> Array:
	var result: Array = []
	for lease_id_value in _dict(state.get("rng_leases", {})).keys():
		var lease_id := str(lease_id_value)
		var lease := _dict(_dict(state.get("rng_leases", {})).get(lease_id_value, {}))
		if not _producer_owns_lease(producer_id, str(lease.get("owner_id", ""))): continue
		result.append({
			"lease_id": lease_id,
			"owner_id": str(lease.get("owner_id", "")),
			"stream_id": str(lease.get("stream_id", "")),
			"current_state": _copy_variant(lease.get("current_state")),
		})
	result.sort_custom(func(a: Variant, b: Variant) -> bool: return str((a as Dictionary).get("lease_id", "")) < str((b as Dictionary).get("lease_id", "")))
	return result


static func _set_request_status(state: Dictionary, request_id: String, status: String, receipt_key: String, receipt_id: String) -> void:
	var requests := _dict(state.get("prepared_requests", {}))
	var request := _dict(requests.get(request_id, {}))
	request["status"] = status
	request[receipt_key] = receipt_id
	requests[request_id] = request
	state["prepared_requests"] = requests


static func _append_acknowledgement(state: Dictionary, acknowledgement: Dictionary) -> void:
	var values := _dictionary_array(state.get("acknowledgements", []))
	values.append(acknowledgement.duplicate(true))
	state["acknowledgements"] = values


static func _record_receipt(state: Dictionary, receipt_id: String, fingerprint: String, result: Dictionary) -> void:
	var receipts := _dict(state.get("authoritative_receipts", {}))
	receipts[receipt_id] = fingerprint
	state["authoritative_receipts"] = receipts
	var results := _dict(state.get("receipt_results", {}))
	results[receipt_id] = result.duplicate(true)
	state["receipt_results"] = results


static func _receipt_replay(state: Dictionary, receipt_id: String, fingerprint: String) -> Dictionary:
	var receipts := _dict(state.get("authoritative_receipts", {}))
	if not receipts.has(receipt_id): return {}
	if str(receipts.get(receipt_id, "")) != fingerprint:
		return {"ok": false, "state": state, "errors": ["authoritative receipt was reused for conflicting content."]}
	return {"ok": true, "state": state, "replayed": true, "receipt_id": receipt_id, "result": _dict(_dict(state.get("receipt_results", {})).get(receipt_id, {})), "errors": []}


static func _bump_revision(state: Dictionary) -> void:
	state["revision"] = int(state.get("revision", 0)) + 1


static func _fact_id(fact: Dictionary) -> String:
	return "%s|%s" % [str(fact.get("producer_receipt", "")), str(fact.get("scenario_receipt", ""))]


static func _transaction_fingerprint(transaction: Dictionary) -> String:
	return state_digest({
		"schema_version": int(transaction.get("schema_version", 0)),
		"receipt_id": str(transaction.get("receipt_id", "")),
		"producer_id": str(transaction.get("producer_id", "")),
		"game_id": str(transaction.get("game_id", "")),
		"table_id": str(transaction.get("table_id", "")),
		"context": _dict(transaction.get("context", {})),
		"replacement_table_state": _dict(transaction.get("replacement_table_state", {})),
		"account_ops": _dictionary_array(transaction.get("account_ops", [])),
		"trust_ops": _dictionary_array(transaction.get("trust_ops", [])),
		"tell_ops": _dictionary_array(transaction.get("tell_ops", [])),
		"facts": _dictionary_array(transaction.get("facts", [])),
		"prepared_acknowledgements": _dictionary_array(transaction.get("prepared_acknowledgements", [])),
		"external_warnings": _string_array(transaction.get("external_warnings", [])),
		"rng_updates": _dictionary_array(transaction.get("rng_updates", [])),
		"prepared_request": _dict(transaction.get("prepared_request", {})),
	})


static func _canonical_snapshot_digest(state: Dictionary) -> String:
	return state_digest({
		"accounts": _dict(state.get("accounts", {})),
		"table_states": _dict(state.get("table_states", {})),
		"trust": _dict(state.get("trust", {})),
		"tells": _dict(state.get("tells", {})),
	})


static func _validate_canonical_snapshot(state: Dictionary) -> Array:
	if str(state.get("canonical_snapshot_digest", "")) != _canonical_snapshot_digest(state):
		return ["canonical RunState snapshot diverged before host transaction validation."]
	return []


static func _validate_rng_registry(state: Dictionary) -> Array:
	var errors: Array = []
	var streams: Dictionary = {}
	for lease_id_value in _dict(state.get("rng_leases", {})).keys():
		var lease_id := str(lease_id_value)
		var lease := _dict(_dict(state.get("rng_leases", {})).get(lease_id_value, {}))
		_append_unknown_keys("RNG lease", lease, ["owner_id", "stream_id", "current_state", "receipts"], errors)
		var owner_id := str(lease.get("owner_id", ""))
		var stream_id := str(lease.get("stream_id", ""))
		if not _valid_id(lease_id) or not _valid_id(owner_id) or not _valid_id(stream_id) or streams.has(stream_id) or not lease.has("current_state"):
			errors.append("RNG lease registry requires unique persisted lease/owner/stream identities and current_state.")
		match owner_id:
			"scenario":
				if lease_id != "scenario_main" or stream_id != "scenario": errors.append("Scenario RNG lease identity is invalid.")
			"craps_throw":
				if lease_id != "craps_throw_main" or stream_id != "craps_throw": errors.append("Craps throw RNG lease identity is invalid.")
			"craps_recovery":
				if lease_id != "craps_recovery_main" or stream_id != "craps_recovery": errors.append("Craps recovery RNG lease identity is invalid.")
			"poker_cards":
				if lease_id != "poker_cards_main" or stream_id != "poker_cards": errors.append("Poker cards RNG lease identity is invalid.")
			_:
				if POKER_POLICY_OWNER_IDS.has(owner_id) and (lease_id != owner_id or stream_id != owner_id): errors.append("Poker policy RNG lease identity is invalid.")
		streams[stream_id] = true
		for receipt_value in _array(lease.get("receipts", [])):
			if not _valid_scoped_receipt(str(receipt_value)): errors.append("RNG lease contains an invalid authoritative receipt.")
		errors.append_array(_validate_bounded("RNG lease state", lease.get("current_state")))
	return errors


static func _validate_bounded(label: String, value: Variant) -> Array:
	var errors: Array = []
	_validate_bounded_value(label, value, 0, {"count": 0}, errors)
	return errors


static func _validate_bounded_value(label: String, value: Variant, depth: int, counter: Dictionary, errors: Array) -> void:
	counter["count"] = int(counter.get("count", 0)) + 1
	if int(counter.get("count", 0)) > MAX_VALUES:
		if not _contains_text(errors, "value limit"): errors.append("%s exceeds the value limit." % label)
		return
	if depth > MAX_DEPTH:
		if not _contains_text(errors, "nesting depth"): errors.append("%s exceeds nesting depth." % label)
		return
	match typeof(value):
		TYPE_DICTIONARY:
			for nested in (value as Dictionary).values(): _validate_bounded_value(label, nested, depth + 1, counter, errors)
		TYPE_ARRAY:
			for nested in value as Array: _validate_bounded_value(label, nested, depth + 1, counter, errors)
		TYPE_STRING:
			if str(value).length() > MAX_TEXT: errors.append("%s contains oversized text." % label)
		TYPE_FLOAT:
			if is_nan(float(value)) or is_inf(float(value)): errors.append("%s contains a non-finite number." % label)


static func _append_unknown_keys(label: String, value: Dictionary, allowed: Array, errors: Array) -> void:
	for key_value in value.keys():
		if not allowed.has(str(key_value)): errors.append("%s contains unknown key: %s." % [label, str(key_value)])


static func _valid_id(value: String) -> bool:
	var text := value.strip_edges()
	if text.is_empty(): return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and code != 95 and code != 45: return false
	return true


static func _valid_scoped_receipt(value: String) -> bool:
	var parts := value.strip_edges().split(":", false)
	if parts.size() < 4: return false
	for part_value in parts:
		if not _valid_id(str(part_value)): return false
	return true


static func _valid_pattern_id(value: String) -> bool:
	var parts := value.strip_edges().split(":", false)
	if parts.size() == 1: return _valid_id(str(parts[0]))
	return parts.size() == 2 and _valid_id(str(parts[0])) and _valid_id(str(parts[1]))


static func _canonical_variant(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		var keys := (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key_value in keys: result[str(key_value)] = _canonical_variant((value as Dictionary).get(key_value))
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for item_value in value as Array: result.append(_canonical_variant(item_value))
		return result
	return value


static func _copy_variant(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY: return (value as Dictionary).duplicate(true)
	if typeof(value) == TYPE_ARRAY: return (value as Array).duplicate(true)
	return value


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	for item_value in _array(value):
		if typeof(item_value) == TYPE_DICTIONARY: result.append((item_value as Dictionary).duplicate(true))
	return result


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	for item_value in _array(value):
		if typeof(item_value) == TYPE_STRING and not str(item_value).strip_edges().is_empty(): result.append(str(item_value).strip_edges())
	return result


static func _normalize_accounts(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	for account_id_value in _dict(value).keys():
		var account_id := str(account_id_value)
		var account := _dict(_dict(value).get(account_id_value, {}))
		var domain := str(account.get("fund_domain", ""))
		if _valid_id(account_id) and ACCOUNT_DOMAINS.has(domain):
			result[account_id] = {"fund_domain": domain, "balance": maxi(0, int(account.get("balance", 0)))}
	return result


static func _int_dictionary(value: Variant, allowed_keys: Array = []) -> Dictionary:
	var result: Dictionary = {}
	for key_value in _dict(value).keys():
		var key := str(key_value)
		if allowed_keys.is_empty() or allowed_keys.has(key): result[key] = int(_dict(value).get(key_value, 0))
	for allowed_value in allowed_keys:
		if not result.has(str(allowed_value)): result[str(allowed_value)] = 0
	return result


static func _contains_text(values: Array, needle: String) -> bool:
	for value in values:
		if str(value).contains(needle): return true
	return false
