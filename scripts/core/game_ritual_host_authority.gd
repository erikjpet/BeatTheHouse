class_name GameRitualHostAuthority
extends RefCounted

# Retained production-side authority for GameRitualRuntime. The owner of this
# object is the trusted game host: UI callers receive commands, never this
# journal or its issuance methods.

const RuntimeScript := preload("res://scripts/core/game_ritual_runtime.gd")

var _session_id: String
var _definition: Dictionary
var _handlers: Dictionary
var _actions: Dictionary = {}
var _issued: Dictionary = {}
var _snapshots: Dictionary = {}
var _external_snapshot_validator: Callable


func _init(definition: Dictionary, handlers: Dictionary = {}, session_id: String = "session.default_01", external_snapshot_validator: Callable = Callable()) -> void:
	_definition = definition.duplicate(true)
	_handlers = handlers.duplicate()
	_session_id = session_id
	_external_snapshot_validator = external_snapshot_validator
	for declaration in definition.get("action_declarations", []):
		var action_id := str((declaration as Dictionary).get("action_id", ""))
		_actions[action_id] = {
			"action_id": action_id,
			"origin_owner_id": str(definition.get("ritual_id", "")),
			"origin_stable_id": "action.%s" % action_id.replace(".", "_"),
			"operation_receipt_key": "receipt:operation:%s" % action_id.replace(".", "_"),
			"boundary_id": "boundary.phase_entry.live",
			"content_fingerprint": RuntimeScript.canonical_fingerprint({"action_id": action_id, "owner": str(definition.get("ritual_id", "")), "session_id": session_id}),
		}


func ritual_session_id() -> String:
	return _session_id


func ritual_authenticated_action(action_id: String) -> Dictionary:
	return (_actions.get(action_id, {}) as Dictionary).duplicate(true)


# Trusted host boundary. The lease is sealed under the exact command
# fingerprint, so caller arguments to GameRitualRuntime cannot replace money,
# RNG, account, or other authoritative inputs.
func issue_command(command: Dictionary, authoritative_context: Dictionary = {}) -> Dictionary:
	var fingerprint := str(command.get("content_fingerprint", ""))
	if fingerprint.length() != 64 or RuntimeScript.canonical_fingerprint(_without_fingerprint(command)) != fingerprint:
		return {}
	_issued[fingerprint] = {"status": "pending", "context": authoritative_context.duplicate(true)}
	return command.duplicate(true)


func ritual_authorizes_command(command: Dictionary, replay: bool) -> bool:
	var issued: Dictionary = _issued.get(str(command.get("content_fingerprint", "")), {})
	var status := str(issued.get("status", ""))
	return status == "pending" or (replay and status == "resolved")


func ritual_execution_lease(command: Dictionary) -> Dictionary:
	var fingerprint := str(command.get("content_fingerprint", ""))
	var issued: Dictionary = _issued.get(fingerprint, {})
	if str(issued.get("status", "")) != "pending":
		return {}
	var context: Dictionary = (issued.get("context", {}) as Dictionary).duplicate(true)
	var lease := {"command_content_fingerprint": fingerprint, "context": context, "content_fingerprint": ""}
	lease["content_fingerprint"] = RuntimeScript.canonical_fingerprint({"command_content_fingerprint": fingerprint, "context": context})
	return lease


func ritual_consume_command(command: Dictionary) -> bool:
	var fingerprint := str(command.get("content_fingerprint", ""))
	var issued: Dictionary = _issued.get(fingerprint, {})
	if str(issued.get("status", "")) != "pending":
		return false
	issued["status"] = "resolved"
	_issued[fingerprint] = issued
	return true


func ritual_handle_action(handler_id: String, action_id: String, parameters: Dictionary, candidate: Dictionary, context: Dictionary) -> Dictionary:
	var callback: Variant = _handlers.get(handler_id)
	if typeof(callback) != TYPE_CALLABLE or not (callback as Callable).is_valid():
		return {"ok": false, "error_code": "handler_unavailable", "message": "No retained host handler is registered."}
	var response: Variant = (callback as Callable).call(action_id, parameters.duplicate(true), candidate.duplicate(true), context.duplicate(true))
	return (response as Dictionary).duplicate(true) if typeof(response) == TYPE_DICTIONARY else {"ok": false, "error_code": "handler_contract_violation"}


func ritual_record_snapshot(fingerprint: String) -> bool:
	if fingerprint.length() != 64:
		return false
	_snapshots[fingerprint] = true
	return true


func ritual_authorizes_snapshot(fingerprint: String) -> bool:
	if bool(_snapshots.get(fingerprint, false)):
		return true
	# A fresh process has no in-memory authority. It may restore only if a
	# trusted external save/account ledger validates this snapshot identity
	# against the sealed ritual definition. Absence fails closed.
	if not _external_snapshot_validator.is_valid():
		return false
	return bool(_external_snapshot_validator.call(fingerprint, _session_id, RuntimeScript.canonical_fingerprint(_definition)))


func _without_fingerprint(value: Dictionary) -> Dictionary:
	var copy := value.duplicate(true)
	copy.erase("content_fingerprint")
	return copy
