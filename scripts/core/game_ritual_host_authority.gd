class_name GameRitualHostAuthority
extends RefCounted

# Sole durable owner for a game ritual. Callers submit intent only. Commands,
# target inventory, account/funds context, RNG context, action descriptors,
# proposal engines, checkpoints, and authoritative state never cross that API.

const RuntimeScript := preload("res://scripts/core/game_ritual_runtime.gd")
const LIVE_REQUEST_LIMIT := 128
const LIVE_RECEIPT_LIMIT := 256
const SNAPSHOT_KEYS := ["host_state_version", "ritual_id", "session_id", "definition_digest", "authority_epoch", "runtime_state", "checkpoint", "tail", "live_requests", "content_fingerprint"]
const CHECKPOINT_KEYS := ["checkpoint_version", "ritual_id", "session_id", "definition_digest", "authority_epoch", "high_water_boundary", "high_water_action_sequence", "compacted_state", "compacted_state_digest", "history_chain_digest", "previous_checkpoint_digest", "content_fingerprint"]
const TAIL_KEYS := ["boundary_ordinal", "action_sequence", "command_fingerprint", "response_fingerprint", "pre_state_digest", "post_state", "post_state_digest", "content_fingerprint"]

var _definition: Dictionary
var _handlers: Dictionary
var _session_id: String
var _authoritative_context_provider: Callable
var _external_snapshot_validator: Callable
var _state: Dictionary = {}
var _authority_epoch := 0
var _checkpoint: Dictionary = {}
var _tail: Array = []
var _live_requests: Dictionary = {}
var _snapshots: Dictionary = {}
var _configuration_errors: Array[String] = []


func _init(definition: Dictionary, handlers: Dictionary = {}, session_id: String = "session.default_01", authoritative_context_provider: Callable = Callable(), external_snapshot_validator: Callable = Callable()) -> void:
	_definition = definition.duplicate(true)
	_handlers = handlers.duplicate()
	_session_id = session_id
	_authoritative_context_provider = authoritative_context_provider
	_external_snapshot_validator = external_snapshot_validator
	var engine = RuntimeScript.new()
	var configured: Dictionary = engine.configure(_definition, _session_id)
	if not bool(configured.get("ok", false)):
		for error in configured.get("errors", []): _configuration_errors.append(str(error))
		return
	_state = engine.serialized_state()
	_checkpoint = _make_checkpoint(_core_state(_state), "")


func configuration_result() -> Dictionary:
	return {"ok": _configuration_errors.is_empty(), "errors": _configuration_errors.duplicate(), "projection": public_projection()}


func authority_epoch() -> int:
	return _authority_epoch


func intent_token(tag: String) -> String:
	var safe := tag.to_lower().replace(" ", "_")
	return "request:e%d:%s" % [_authority_epoch, safe]


func submit_intent(action_id: String, parameters: Dictionary, request_key: String) -> Dictionary:
	if not _configuration_errors.is_empty() or _state.is_empty():
		return _host_rejection("internal_fail_closed", request_key, "Ritual host is not configured.")
	var token_epoch := _request_epoch(request_key)
	if token_epoch != _authority_epoch:
		return _host_rejection("stale_phase", request_key, "Intent belongs to a compacted authority epoch.")
	var intent_fingerprint := RuntimeScript.canonical_fingerprint({"action_id": action_id, "parameters": parameters, "request_key": request_key})
	if _live_requests.has(request_key):
		var cached: Dictionary = _live_requests[request_key]
		if str(cached.get("intent_fingerprint", "")) != intent_fingerprint:
			return _host_rejection("receipt_content_conflict", request_key, "Intent key is already bound to different content.")
		return (cached.get("response", {}) as Dictionary).duplicate(true)
	var action := _authenticated_action(action_id)
	if action.is_empty():
		return _host_rejection("unknown_reference", request_key, "Intent action is undeclared.")
	var target_id := _target_for_intent(parameters)
	if target_id.is_empty():
		return _host_rejection("unavailable_target", request_key, "Intent has no sealed target.")
	var command := _command_for(action_id, parameters, request_key, target_id, action)
	var engine = RuntimeScript.new()
	var configured: Dictionary = engine.configure(_definition, _session_id)
	if not bool(configured.get("ok", false)) or not bool(engine.adopt_validated_state(_state).get("ok", false)):
		return _host_rejection("internal_fail_closed", request_key, "Authoritative state could not enter the pure proposal engine.")
	var preflight: Dictionary = engine.preflight_command(command, action)
	if not preflight.is_empty():
		return engine.rejection_for_command(command, preflight)
	var context := _derive_authoritative_context(action_id, parameters)
	if context.is_empty() and _action_requires_context(action_id):
		return _host_rejection("unsealed_authority", request_key, "Trusted account/RNG context is unavailable.")
	var handler_result := _handler_result(action_id, parameters, context)
	var pre_state := _state.duplicate(true)
	var response: Dictionary = engine.propose_command(command, action, context, handler_result)
	if not bool(response.get("ok", false)):
		return response
	var candidate := engine.serialized_state()
	if not _response_matches_candidate(response, engine.prepared_projection()):
		return _host_rejection("internal_fail_closed", request_key, "Result projection does not match the accepted candidate.")
	var tail_record := _tail_record(command, response, pre_state, candidate)
	var candidate_tail := _tail.duplicate(true)
	candidate_tail.append(tail_record)
	var candidate_requests := _live_requests.duplicate(true)
	candidate_requests[request_key] = {"intent_fingerprint": intent_fingerprint, "response": response.duplicate(true)}
	# Atomic publish: either the complete candidate/tail/request graph becomes
	# authoritative, or no host-owned byte changes.
	_state = candidate
	_tail = candidate_tail
	_live_requests = candidate_requests
	if _requires_compaction():
		_compact_completed_boundary()
	return response


func serialized_state() -> Dictionary:
	return _state.duplicate(true)


func public_projection() -> Dictionary:
	if _state.is_empty(): return {}
	var engine = RuntimeScript.new()
	if not bool(engine.configure(_definition, _session_id).get("ok", false)) or not bool(engine.adopt_validated_state(_state).get("ok", false)): return {}
	return engine.prepared_projection()


func authenticated_snapshot() -> Dictionary:
	if _state.is_empty(): return {}
	var snapshot := {"host_state_version": 1, "ritual_id": str(_definition.get("ritual_id", "")), "session_id": _session_id, "definition_digest": RuntimeScript.canonical_fingerprint(_definition), "authority_epoch": _authority_epoch, "runtime_state": _state.duplicate(true), "checkpoint": _checkpoint.duplicate(true), "tail": _tail.duplicate(true), "live_requests": _live_requests.duplicate(true), "content_fingerprint": ""}
	snapshot["content_fingerprint"] = RuntimeScript.canonical_fingerprint(_without_fingerprint(snapshot))
	_snapshots[str(snapshot.get("content_fingerprint", ""))] = true
	return snapshot


func restore_snapshot(snapshot: Dictionary) -> Dictionary:
	var before := _host_bytes()
	var errors := _validate_snapshot(snapshot)
	if not errors.is_empty():
		return {"ok": false, "error_code": "invalid_restore", "errors": errors}
	var fingerprint := str(snapshot.get("content_fingerprint", ""))
	var locally_authorized := bool(_snapshots.get(fingerprint, false))
	var externally_authorized := _external_snapshot_validator.is_valid() and bool(_external_snapshot_validator.call(fingerprint, _session_id, str(snapshot.get("definition_digest", ""))))
	if not locally_authorized and not externally_authorized:
		return {"ok": false, "error_code": "invalid_restore", "errors": ["trusted save ledger did not authorize snapshot"]}
	var restored_state: Dictionary = (snapshot.get("runtime_state", {}) as Dictionary).duplicate(true)
	var engine = RuntimeScript.new()
	if not bool(engine.configure(_definition, _session_id).get("ok", false)) or not bool(engine.adopt_validated_state(restored_state).get("ok", false)):
		return {"ok": false, "error_code": "invalid_restore", "errors": ["runtime state is invalid"]}
	_state = restored_state
	_checkpoint = (snapshot.get("checkpoint", {}) as Dictionary).duplicate(true)
	_tail = (snapshot.get("tail", []) as Array).duplicate(true)
	_authority_epoch = int(snapshot.get("authority_epoch", 0))
	_live_requests = (snapshot.get("live_requests", {}) as Dictionary).duplicate(true)
	if before == _host_bytes():
		pass
	return {"ok": true, "state": _state.duplicate(true), "projection": public_projection(), "replayed_effects": []}


func reflected_runtime_probe() -> Dictionary:
	# A deliberately returned fresh engine proves that reflection yields no host,
	# issuance journal, authoritative context, or durable state capability.
	return {"runtime": RuntimeScript.new(), "host_state_fingerprint": RuntimeScript.canonical_fingerprint(_state)}


func _authenticated_action(action_id: String) -> Dictionary:
	for declaration in _definition.get("action_declarations", []):
		if str((declaration as Dictionary).get("action_id", "")) == action_id:
			return {"action_id": action_id, "origin_owner_id": str(_definition.get("ritual_id", "")), "origin_stable_id": "action.%s" % action_id.replace(".", "_"), "operation_receipt_key": "receipt:operation:%s" % action_id.replace(".", "_"), "boundary_id": "boundary.phase_entry.live", "content_fingerprint": RuntimeScript.canonical_fingerprint({"action_id": action_id, "owner": str(_definition.get("ritual_id", "")), "session_id": _session_id})}
	return {}


func _derive_authoritative_context(action_id: String, parameters: Dictionary) -> Dictionary:
	if not _authoritative_context_provider.is_valid(): return {} if _action_requires_context(action_id) else {"authority": "none"}
	var value: Variant = _authoritative_context_provider.call(action_id, parameters.duplicate(true), _state.duplicate(true))
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func _action_requires_context(action_id: String) -> bool:
	return action_id.begins_with("commit.") or not _handler_id(action_id) in ["commitment.edit", "resolution.ack"]


func _handler_id(action_id: String) -> String:
	for action in _definition.get("action_declarations", []):
		if str((action as Dictionary).get("action_id", "")) == action_id: return str((action as Dictionary).get("handler_id", ""))
	return ""


func _handler_result(action_id: String, parameters: Dictionary, context: Dictionary) -> Dictionary:
	var handler_id := _handler_id(action_id)
	if handler_id in ["commitment.edit", "resolution.ack"]: return {}
	var callback: Variant = _handlers.get(handler_id)
	if typeof(callback) != TYPE_CALLABLE or not (callback as Callable).is_valid(): return {"ok": false, "error_code": "handler_unavailable"}
	var value: Variant = (callback as Callable).call(action_id, parameters.duplicate(true), _state.duplicate(true), context.duplicate(true))
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {"ok": false, "error_code": "handler_contract_violation"}


func _target_for_intent(parameters: Dictionary) -> String:
	var regions: Array = ((_definition.get("declared_targets", {}) as Dictionary).get("regions", []) as Array)
	if parameters.has("item_id"):
		var item_id := str(parameters.get("item_id", ""))
		return item_id if regions.has(item_id) else ""
	return str(regions[0]) if not regions.is_empty() else ""


func _command_for(action_id: String, parameters: Dictionary, request_key: String, target_id: String, action: Dictionary) -> Dictionary:
	var source_targets: Array = ((_definition.get("declared_targets", {}) as Dictionary).get("sealed_host_targets", []) as Array)
	var source_id := str(source_targets[0]) if not source_targets.is_empty() else target_id
	var tag := request_key.replace(":", "_").replace("-", "_")
	var command := {"envelope_version": 1, "ritual_id": str(_definition.get("ritual_id", "")), "session_id": _session_id, "command_id": "command.%s" % tag, "request_key": request_key, "action_id": action_id, "expected_phase": str(_state.get("phase_id", "")), "source_id": source_id, "target_id": target_id, "parameters": parameters.duplicate(true), "authenticated_action": action.duplicate(true), "boundary": {"boundary_id": "boundary.command.%s" % tag, "kind": "command", "ritual_id": str(_definition.get("ritual_id", "")), "session_id": _session_id, "phase_id": str(_state.get("phase_id", "")), "ordinal": int(_state.get("boundary_ordinal", 0)) + 1, "cause_receipt_key": "receipt:command:%s" % tag}, "receipt_key": "receipt:command:%s" % tag, "content_fingerprint": ""}
	command["content_fingerprint"] = RuntimeScript.canonical_fingerprint(_without_fingerprint(command))
	return command


func _response_matches_candidate(response: Dictionary, projection: Dictionary) -> bool:
	var public: Dictionary = response.get("public_projection", {})
	return str(response.get("phase_after", "")) == str(projection.get("phase_id", "")) and str(public.get("phase_id", "")) == str(projection.get("phase_id", "")) and int(public.get("pending_total", -1)) == int((projection.get("readable_totals", {}) as Dictionary).get("pending_total", 0)) and int(public.get("at_risk_total", -1)) == int((projection.get("readable_totals", {}) as Dictionary).get("at_risk_total", 0))


func _requires_compaction() -> bool:
	return _live_requests.size() > LIVE_REQUEST_LIMIT or (_state.get("envelope_receipts", []) as Array).size() > LIVE_RECEIPT_LIMIT


func _compact_completed_boundary() -> void:
	var causal_graph := {"checkpoint": _checkpoint, "tail": _tail, "requests": _live_requests, "receipts": _state.get("receipts", []), "envelope_receipts": _state.get("envelope_receipts", []), "facts": _state.get("fact_envelopes", []), "operations": _state.get("operation_envelopes", []), "cache": _state.get("envelope_request_cache", {}), "responses": (_state.get("handler_state", {}) as Dictionary).get("_ritual_cached_responses", {})}
	var previous := str(_checkpoint.get("content_fingerprint", ""))
	var core := _core_state(_state)
	_authority_epoch += 1
	_checkpoint = _make_checkpoint(core, RuntimeScript.canonical_fingerprint({"previous": previous, "graph": causal_graph}))
	_state = core.duplicate(true)
	_state["receipts"] = []
	_state["envelope_receipts"] = []
	_state["fact_envelopes"] = []
	_state["operation_envelopes"] = []
	_state["envelope_request_cache"] = {}
	var handler_state: Dictionary = _state.get("handler_state", {})
	handler_state["_ritual_cached_responses"] = {}
	_state["handler_state"] = handler_state
	_tail = []
	_live_requests = {}


func _make_checkpoint(core: Dictionary, history_digest: String) -> Dictionary:
	var previous := str(_checkpoint.get("content_fingerprint", ""))
	var checkpoint := {"checkpoint_version": 1, "ritual_id": str(_definition.get("ritual_id", "")), "session_id": _session_id, "definition_digest": RuntimeScript.canonical_fingerprint(_definition), "authority_epoch": _authority_epoch, "high_water_boundary": int(core.get("boundary_ordinal", 0)), "high_water_action_sequence": int(core.get("action_sequence", 0)), "compacted_state": core.duplicate(true), "compacted_state_digest": RuntimeScript.canonical_fingerprint(core), "history_chain_digest": history_digest if not history_digest.is_empty() else RuntimeScript.canonical_fingerprint({"genesis": core}), "previous_checkpoint_digest": previous, "content_fingerprint": ""}
	checkpoint["content_fingerprint"] = RuntimeScript.canonical_fingerprint(_without_fingerprint(checkpoint))
	return checkpoint


func _tail_record(command: Dictionary, response: Dictionary, pre_state: Dictionary, post_state: Dictionary) -> Dictionary:
	var record := {"boundary_ordinal": int(post_state.get("boundary_ordinal", 0)), "action_sequence": int(post_state.get("action_sequence", 0)), "command_fingerprint": str(command.get("content_fingerprint", "")), "response_fingerprint": str(response.get("content_fingerprint", "")), "pre_state_digest": RuntimeScript.canonical_fingerprint(_core_state(pre_state)), "post_state": _core_state(post_state), "post_state_digest": RuntimeScript.canonical_fingerprint(_core_state(post_state)), "content_fingerprint": ""}
	record["content_fingerprint"] = RuntimeScript.canonical_fingerprint(_without_fingerprint(record))
	return record


func _core_state(source: Dictionary) -> Dictionary:
	var core := source.duplicate(true)
	core["receipts"] = []
	core["envelope_receipts"] = []
	core["fact_envelopes"] = []
	core["operation_envelopes"] = []
	core["one_shot_cues"] = []
	var result_refs: Array = core.get("authoritative_result_refs", [])
	core["authoritative_result_refs"] = [result_refs.back()] if not result_refs.is_empty() else []
	var item_resolutions: Array = core.get("item_resolutions", [])
	core["item_resolutions"] = item_resolutions.slice(maxi(0, item_resolutions.size() - 128))
	core["envelope_request_cache"] = {}
	var handler_state: Dictionary = core.get("handler_state", {})
	handler_state["_ritual_cached_responses"] = {}
	core["handler_state"] = handler_state
	return core


func _validate_snapshot(snapshot: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not _closed_shape(snapshot, SNAPSHOT_KEYS): errors.append("snapshot shape is invalid"); return errors
	if int(snapshot.get("host_state_version", 0)) != 1 or str(snapshot.get("ritual_id", "")) != str(_definition.get("ritual_id", "")) or str(snapshot.get("session_id", "")) != _session_id or str(snapshot.get("definition_digest", "")) != RuntimeScript.canonical_fingerprint(_definition): errors.append("snapshot identity is invalid")
	if RuntimeScript.canonical_fingerprint(_without_fingerprint(snapshot)) != str(snapshot.get("content_fingerprint", "")): errors.append("snapshot fingerprint is invalid")
	var checkpoint: Dictionary = snapshot.get("checkpoint", {}) if typeof(snapshot.get("checkpoint")) == TYPE_DICTIONARY else {}
	if not _closed_shape(checkpoint, CHECKPOINT_KEYS) or RuntimeScript.canonical_fingerprint(_without_fingerprint(checkpoint)) != str(checkpoint.get("content_fingerprint", "")) or RuntimeScript.canonical_fingerprint(checkpoint.get("compacted_state", {})) != str(checkpoint.get("compacted_state_digest", "")): errors.append("checkpoint is invalid")
	if int(checkpoint.get("authority_epoch", -1)) != int(snapshot.get("authority_epoch", -2)): errors.append("checkpoint epoch is invalid")
	var expected_pre := str(checkpoint.get("compacted_state_digest", ""))
	var expected_boundary := int(checkpoint.get("high_water_boundary", 0))
	for value in snapshot.get("tail", []):
		if typeof(value) != TYPE_DICTIONARY: errors.append("tail record is invalid"); continue
		var record: Dictionary = value
		if not _closed_shape(record, TAIL_KEYS) or RuntimeScript.canonical_fingerprint(_without_fingerprint(record)) != str(record.get("content_fingerprint", "")): errors.append("tail fingerprint is invalid"); continue
		if int(record.get("boundary_ordinal", 0)) != expected_boundary + 1 or str(record.get("pre_state_digest", "")) != expected_pre or RuntimeScript.canonical_fingerprint(record.get("post_state", {})) != str(record.get("post_state_digest", "")): errors.append("tail chain is invalid")
		expected_boundary = int(record.get("boundary_ordinal", 0)); expected_pre = str(record.get("post_state_digest", ""))
	if expected_pre != RuntimeScript.canonical_fingerprint(_core_state(snapshot.get("runtime_state", {}) as Dictionary)): errors.append("tail does not reconstruct final state")
	if (snapshot.get("tail", []) as Array).size() > LIVE_REQUEST_LIMIT or (snapshot.get("live_requests", {}) as Dictionary).size() > LIVE_REQUEST_LIMIT or ((snapshot.get("runtime_state", {}) as Dictionary).get("envelope_receipts", []) as Array).size() > LIVE_RECEIPT_LIMIT: errors.append("live causal tail exceeds bound")
	return errors


func _request_epoch(request_key: String) -> int:
	var atoms := request_key.split(":", false)
	if atoms.size() < 3 or not str(atoms[1]).begins_with("e"): return -1
	return str(atoms[1]).trim_prefix("e").to_int()


func _host_rejection(error_code: String, request_key: String, message: String) -> Dictionary:
	return {"ok": false, "error_code": error_code, "request_key": request_key, "message": message, "public_projection": public_projection()}


func _host_bytes() -> String:
	return RuntimeScript.canonical_json({"state": _state, "checkpoint": _checkpoint, "tail": _tail, "epoch": _authority_epoch, "requests": _live_requests})


func _without_fingerprint(value: Dictionary) -> Dictionary:
	var copy := value.duplicate(true)
	copy.erase("content_fingerprint")
	return copy


func _closed_shape(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size(): return false
	for key in keys:
		if not value.has(key): return false
	return true
