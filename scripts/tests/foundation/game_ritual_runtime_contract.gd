class_name GameRitualRuntimeContract
extends RefCounted

const RuntimeScript := preload("res://scripts/core/game_ritual_runtime.gd")
const SchemaScript := preload("res://scripts/core/game_ritual_schema.gd")
const LayoutScript := preload("res://scripts/core/game_ritual_layout.gd")
const CanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")
const FIXTURE_PATH := "res://scripts/tests/fixtures/game_ritual_vocabulary_v1.json"
const ENVELOPE_FIXTURE_PATH := "res://scripts/tests/fixtures/game_ritual_shared_envelopes_v1.json"


class RetainedRitualHost:
	extends RefCounted
	var _session_id: String
	var _definition: Dictionary
	var _handlers: Dictionary
	var _actions: Dictionary = {}
	var _issued: Dictionary = {}
	var _snapshots: Dictionary = {}

	func _init(definition: Dictionary, handlers: Dictionary = {}, session_id: String = "session.default_01") -> void:
		_definition = definition.duplicate(true)
		_handlers = handlers.duplicate()
		_session_id = session_id
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

	func issue(command: Dictionary) -> Dictionary:
		var fingerprint := str(command.get("content_fingerprint", ""))
		_issued[fingerprint] = "pending"
		return command

	func ritual_authorizes_command(command: Dictionary, replay: bool) -> bool:
		var fingerprint := str(command.get("content_fingerprint", ""))
		var status := str(_issued.get(fingerprint, ""))
		return status == "pending" or (replay and status == "resolved")

	func ritual_consume_command(command: Dictionary) -> bool:
		var fingerprint := str(command.get("content_fingerprint", ""))
		if str(_issued.get(fingerprint, "")) != "pending":
			return false
		_issued[fingerprint] = "resolved"
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
		return bool(_snapshots.get(fingerprint, false))


static func check(_library, failures: Array) -> void:
	var definition := _fixture(failures)
	if definition.is_empty():
		return
	_check_validation(definition, failures)
	_check_runtime_trace(definition, failures)
	_check_seed_parity(definition, failures)
	_check_envelope_boundary(definition, failures)
	_check_handler_allowlists(definition, failures)
	_check_authority_closure(definition, failures)
	_check_hostile_restore(definition, failures)
	_check_layout_and_canvas(definition, failures)
	_check_neutral_opt_in_seams(failures)


static func _check_validation(definition: Dictionary, failures: Array) -> void:
	var errors := SchemaScript.validate_definition(definition)
	if not errors.is_empty():
		failures.append("Frozen game ritual vocabulary is not accepted by its runtime validator: %s" % JSON.stringify(errors))
	if not LayoutScript.validate_definition(definition).is_empty():
		failures.append("Frozen game ritual vocabulary does not satisfy shared layout validation.")
	var malformed := definition.duplicate(true)
	(malformed["ritual_phases"] as Array).remove_at(1)
	if SchemaScript.validate_definition(malformed).is_empty():
		failures.append("Ritual validator accepted a transition to a removed phase.")
	malformed = definition.duplicate(true)
	((malformed["actors"] as Array)[0] as Dictionary)["behavior_states"] = []
	if SchemaScript.validate_definition(malformed).is_empty():
		failures.append("Ritual validator accepted an actor without behavior states.")
	malformed = definition.duplicate(true)
	((malformed["scene_objects"] as Array)[0] as Dictionary).erase("bounds")
	if SchemaScript.validate_definition(malformed).is_empty():
		failures.append("Ritual validator accepted a scene object without bounds.")
	malformed = definition.duplicate(true)
	var tier: Dictionary = (malformed["energy"] as Dictionary)["tiers"][0]
	tier["object_operations"] = []
	if SchemaScript.validate_definition(malformed).is_empty():
		failures.append("Ritual validator accepted an energy tier that touches only audio/text.")
	malformed = definition.duplicate(true)
	((malformed["pointer_verbs"] as Array)[0] as Dictionary)["equivalents"].erase("controller")
	if SchemaScript.validate_definition(malformed).is_empty():
		failures.append("Ritual validator accepted a pointer verb without controller parity.")


static func _check_runtime_trace(definition: Dictionary, failures: Array) -> void:
	var host := RetainedRitualHost.new(definition, {"play.primary": Callable(GameRitualRuntimeContract, "_play_handler")})
	var runtime = RuntimeScript.new(host)
	var configured: Dictionary = runtime.configure(definition)
	if not bool(configured.get("ok", false)):
		failures.append("Ritual runtime rejected the frozen vocabulary: %s" % JSON.stringify(configured))
		return
	var initial := runtime.serialized_state()
	var rejected: Dictionary = _execute(runtime, host, "play.primary", {"commitment_id": "early"}, "trace_reject", {})
	if bool(rejected.get("ok", false)) or str(rejected.get("error_code", "")) != "action_not_permitted":
		failures.append("Ritual runtime did not reject an out-of-phase authoritative action.")
	var rejected_state := runtime.serialized_state()
	for key in initial.keys():
		if initial[key] != rejected_state.get(key):
			failures.append("Rejected ritual action mutated authoritative field %s." % key)
	var place_command := _command_for(runtime, host, "commit.place", _place_parameters("layout.primary", 5), "trace_place")
	var place: Dictionary = runtime.process_command(place_command, {"available_funds": 20})
	var replay: Dictionary = runtime.process_command(place_command, {"available_funds": 20})
	if not bool(place.get("ok", false)) or place != replay:
		failures.append("Ritual request replay was not byte-identical under canonical key ordering.")
	var conflict_command := place_command.duplicate(true)
	(conflict_command["parameters"] as Dictionary)["amount"] = 6
	conflict_command["content_fingerprint"] = RuntimeScript.canonical_fingerprint(_without_fingerprint(conflict_command))
	var conflict: Dictionary = runtime.process_command(conflict_command, {"available_funds": 20})
	if str(conflict.get("error_code", "")) != "authority_mismatch":
		failures.append("Ritual request key did not reject different canonical content.")
	var correct: Dictionary = _execute(runtime, host, "commit.correct", {"item_id": "layout.primary", "amount": 7}, "trace_correct", {"available_funds": 20})
	var undo: Dictionary = _execute(runtime, host, "commit.undo", {}, "trace_undo", {"available_funds": 20})
	if not bool(correct.get("ok", false)) or not bool(undo.get("ok", false)) or int((runtime.prepared_projection()["pending_items"] as Dictionary).get("layout.primary", 0)) != 5:
		failures.append("Staged commitment correction/undo did not preserve the pending set.")
	var confirm_command := _command_for(runtime, host, "commit.confirm", {}, "trace_confirm")
	var confirm: Dictionary = runtime.process_command(confirm_command, {"available_funds": 20})
	var confirm_replay: Dictionary = runtime.process_command(confirm_command, {"available_funds": 20})
	if not bool(confirm.get("ok", false)) or confirm != confirm_replay or str(confirm.get("phase_after", "")) != "committed":
		failures.append("Phase-changing commitment confirmation was not exactly-once replayable.")
	var double_commit: Dictionary = _execute(runtime, host, "commit.confirm", {}, "trace_double", {"available_funds": 20})
	if bool(double_commit.get("ok", true)):
		failures.append("Phase machine permitted a double commitment.")
	var play: Dictionary = _execute(runtime, host, "play.primary", {"commitment_id": "commitment.one"}, "trace_play", {"seed": 19})
	if not bool(play.get("ok", false)) or str(play.get("phase_after", "")) != "resolving" or (runtime.serialized_state().get("fact_envelopes", []) as Array).size() != 1:
		failures.append("Allowlisted rules handler did not advance and publish one action-boundary fact.")
	var fact_envelopes: Array = runtime.serialized_state().get("fact_envelopes", [])
	var fact_keys := ["envelope_version", "fact_id", "fact_type", "fact_version", "payload", "visibility", "boundary", "receipt_key", "content_fingerprint"]
	if fact_envelopes.size() != 1 or not _exact_keys(fact_envelopes[0] as Dictionary, fact_keys) or RuntimeScript.canonical_fingerprint(_without_fingerprint(fact_envelopes[0] as Dictionary)) != str((fact_envelopes[0] as Dictionary).get("content_fingerprint", "")):
		failures.append("Published GameFact did not use the exact closed fingerprinted envelope.")
	var saved := runtime.serialized_state()
	var restored = RuntimeScript.new(host)
	if not bool(restored.configure(definition).get("ok", false)):
		failures.append("Restore proof could not configure a second ritual runtime.")
		return
	var restore_result: Dictionary = restored.restore_snapshot(runtime.authenticated_snapshot())
	if not bool(restore_result.get("ok", false)) or not (restore_result.get("replayed_effects", [1]) as Array).is_empty() or restored.serialized_state() != saved:
		failures.append("Ritual restore changed authoritative state or replayed one-shot effects.")
	var acknowledge: Dictionary = _execute(restored, host, "resolution.acknowledge", {}, "trace_ack", {})
	if not bool(acknowledge.get("ok", false)) or str(acknowledge.get("phase_after", "")) != "open":
		failures.append("Resolution acknowledgement did not return to the legal open phase.")
	var before_energy := restored.serialized_state()
	var energy: Dictionary = restored.set_energy_tier("engaged", "trace_energy")
	if bool(energy.get("ok", true)) or str(energy.get("error_code", "")) != "unsealed_authority" or restored.serialized_state() != before_energy:
		failures.append("Caller reached the sealed energy mutation path.")
	if RuntimeScript.canonical_fingerprint({"b": 2, "a": [1, true]}) != RuntimeScript.canonical_fingerprint({"a": [1, true], "b": 2}):
		failures.append("Ritual canonical fingerprint depends on dictionary insertion order.")


static func _check_layout_and_canvas(definition: Dictionary, failures: Array) -> void:
	var hits := LayoutScript.compile_pointer_hits(definition, "open")
	if hits.size() != 1 or str((hits[0] as Dictionary).get("target_region", "")) != "layout.primary":
		failures.append("Ritual layout did not compile the active target-region hit.")
	var canvas = CanvasScript.new()
	canvas.surface_add_ritual_hits(hits)
	if canvas.hit_regions.size() != hits.size() or str((canvas.hit_regions[0] as Dictionary).get("ritual_pointer_id", "")) != "place_primary":
		failures.append("Canvas ritual adapter did not preserve semantic pointer identity.")
	canvas.free()
	var malformed := definition.duplicate(true)
	var bounds: Dictionary = ((malformed["scene_objects"] as Array)[0] as Dictionary)["bounds"]
	bounds["x"] = 880
	if LayoutScript.validate_definition(malformed).is_empty():
		failures.append("Ritual layout accepted an object outside design space.")


static func _check_seed_parity(definition: Dictionary, failures: Array) -> void:
	for seed in range(10):
		var handlers := {"play.primary": Callable(GameRitualRuntimeContract, "_play_handler")}
		var left_host := RetainedRitualHost.new(definition, handlers)
		var right_host := RetainedRitualHost.new(definition, handlers)
		var left = RuntimeScript.new(left_host)
		var right = RuntimeScript.new(right_host)
		left.configure(definition)
		right.configure(definition)
		var left_trace: Array = []
		var right_trace: Array = []
		for runtime in [left, right]:
			var host = left_host if runtime == left else right_host
			var trace: Array = []
			trace.append(_execute(runtime, host, "commit.place", _place_parameters("layout.primary", seed + 1), "seed_%d_place" % seed, {"available_funds": 100}))
			trace.append(_execute(runtime, host, "commit.confirm", {}, "seed_%d_confirm" % seed, {"available_funds": 100}))
			trace.append(_execute(runtime, host, "play.primary", {"commitment_id": "commitment.%d" % seed}, "seed_%d_play" % seed, {"seed": seed}))
			if runtime == left:
				left_trace = trace
			else:
				right_trace = trace
		if RuntimeScript.canonical_json(left_trace) != RuntimeScript.canonical_json(right_trace) or left.serialized_state() != right.serialized_state():
			failures.append("Ritual native/Web-equivalent trace diverged at seed %d." % seed)


static func _check_envelope_boundary(definition: Dictionary, failures: Array) -> void:
	var fixture_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(ENVELOPE_FIXTURE_PATH))
	if typeof(fixture_value) != TYPE_DICTIONARY:
		failures.append("Shared ritual envelope fixture is not valid JSON.")
		return
	var fixture: Dictionary = fixture_value
	var command: Dictionary = (fixture.get("command", {}) as Dictionary).duplicate(true)
	# Godot's JSON parser materializes every JSON number as float; restore the
	# frozen schema's integer semantics before exercising the live envelope.
	(command["parameters"] as Dictionary)["amount"] = int((command["parameters"] as Dictionary).get("amount", 0))
	var weights: Array = (command["parameters"] as Dictionary).get("weights", [])
	for index in range(weights.size()): weights[index] = int(weights[index])
	(command["boundary"] as Dictionary)["ordinal"] = int((command["boundary"] as Dictionary).get("ordinal", 0))
	command["content_fingerprint"] = RuntimeScript.canonical_fingerprint(_without_fingerprint(command))
	var host := RetainedRitualHost.new(definition, {}, str(command.get("session_id", "")))
	command["authenticated_action"] = host.ritual_authenticated_action(str(command.get("action_id", "")))
	command["content_fingerprint"] = RuntimeScript.canonical_fingerprint(_without_fingerprint(command))
	host.issue(command)
	var runtime = RuntimeScript.new(host)
	var configured: Dictionary = runtime.configure(definition)
	var command_validation: Dictionary = runtime.validate_command_envelope(command)
	if not bool(configured.get("ok", false)) or not command_validation.is_empty():
		failures.append("Runtime rejected the complete frozen RitualCommand envelope: %s" % JSON.stringify(command_validation))
		return
	var result: Dictionary = runtime.process_command(command, {"available_funds": 100})
	var replay: Dictionary = runtime.process_command(command, {"available_funds": 100})
	var result_keys := ["envelope_version", "ok", "ritual_id", "session_id", "command_id", "request_key", "phase_before", "phase_after", "authoritative_result_ref", "state_receipts", "operation_receipts", "fact_receipts", "boundary", "receipt_key", "content_fingerprint", "public_projection"]
	if not bool(result.get("ok", false)) or result != replay or not _exact_keys(result, result_keys) or RuntimeScript.canonical_fingerprint(_without_fingerprint(result)) != str(result.get("content_fingerprint", "")):
		failures.append("Complete RitualCommand did not produce an exact fingerprinted replay-safe RitualResult: first=%s replay=%s" % [JSON.stringify(result), JSON.stringify(replay)])
	var envelope_state := runtime.serialized_state()
	var cache: Dictionary = (envelope_state.get("envelope_request_cache", {}) as Dictionary).get(str(command.get("request_key", "")), {})
	var cache_keys := ["request_key", "command_receipt_key", "command_content_fingerprint", "response_receipt_key", "response_content_fingerprint", "status"]
	var receipt_keys := ["receipt_key", "content_fingerprint", "boundary_id", "envelope_kind", "status"]
	if not _exact_keys(cache, cache_keys) or str(cache.get("response_content_fingerprint", "")) != str(result.get("content_fingerprint", "")):
		failures.append("RequestCacheRecord did not bind the exact command/result fingerprints.")
	for receipt in envelope_state.get("envelope_receipts", []):
		if not _exact_keys(receipt as Dictionary, receipt_keys): failures.append("ReceiptRecord did not use the exact closed shape.")
	var hostile := command.duplicate(true)
	hostile["extra"] = true
	var rejected: Dictionary = runtime.process_command(hostile)
	var rejection_keys := ["envelope_version", "ok", "ritual_id", "session_id", "command_id", "request_key", "phase", "error_code", "public_message", "retryable", "return_policy", "boundary", "receipt_key", "content_fingerprint", "public_projection"]
	if bool(rejected.get("ok", true)) or str(rejected.get("error_code", "")) != "invalid_envelope" or not _exact_keys(rejected, rejection_keys) or RuntimeScript.canonical_fingerprint(_without_fingerprint(rejected)) != str(rejected.get("content_fingerprint", "")):
		failures.append("Hostile open command did not return the exact closed RitualRejection taxonomy envelope.")
	hostile = command.duplicate(true)
	(hostile["authenticated_action"] as Dictionary)["origin_stable_id"] = "action.hostile_origin"
	hostile["content_fingerprint"] = RuntimeScript.canonical_fingerprint(_without_fingerprint(hostile))
	if str(runtime.validate_command_envelope(hostile).get("error_code", "")) != "authority_mismatch":
		failures.append("Caller-supplied authenticated origin overrode the live trusted action descriptor.")
	hostile = command.duplicate(true)
	hostile["content_fingerprint"] = "f".repeat(64)
	var fingerprint_host := RetainedRitualHost.new(definition, {}, str(command.get("session_id", "")))
	fingerprint_host.issue(hostile)
	var fingerprint_runtime = RuntimeScript.new(fingerprint_host)
	fingerprint_runtime.configure(definition)
	if str(fingerprint_runtime.validate_command_envelope(hostile).get("error_code", "")) != "receipt_content_conflict":
		failures.append("Supplied noncanonical command fingerprint did not fail closed.")


static func _check_handler_allowlists(definition: Dictionary, failures: Array) -> void:
	for callback in [Callable(GameRitualRuntimeContract, "_hostile_operation_handler"), Callable(GameRitualRuntimeContract, "_hostile_fact_handler")]:
		var host := RetainedRitualHost.new(definition, {"play.primary": callback})
		var runtime = RuntimeScript.new(host)
		runtime.configure(definition)
		_execute(runtime, host, "commit.place", _place_parameters("layout.primary", 5), "allow_place", {"available_funds": 20})
		_execute(runtime, host, "commit.confirm", {}, "allow_confirm", {"available_funds": 20})
		var before := runtime.serialized_state()
		var rejected: Dictionary = _execute(runtime, host, "play.primary", {"commitment_id": "commitment.one"}, "allow_hostile_%d" % absi(callback.hash()), {})
		var after := runtime.serialized_state()
		if bool(rejected.get("ok", true)):
			failures.append("Handler emitted an operation/fact outside its own allowlist without rejection.")
		if before != after: failures.append("Hostile cross-handler emission mutated authoritative state.")


static func _check_authority_closure(definition: Dictionary, failures: Array) -> void:
	var host := RetainedRitualHost.new(definition)
	var runtime = RuntimeScript.new(host)
	runtime.configure(definition)
	var before := runtime.serialized_state()
	var attempts: Array = [
		runtime.process_action("commit.place", _place_parameters("layout.primary", 5), "direct_action", {"available_funds": 20}),
		runtime._reduce_action("commit.place", _place_parameters("layout.primary", 5), "forged_reducer", {"available_funds": 20}),
		runtime.set_energy_tier("engaged", "direct_energy"),
		runtime._apply_energy_tier("engaged", "forged_energy"),
		runtime.restore(before),
		runtime._restore_state(before),
	]
	for attempt in attempts:
		if bool((attempt as Dictionary).get("ok", false)) and not (attempt as Dictionary).has("state"):
			failures.append("Caller reached a sealed ritual mutation or restore path.")
	if bool(runtime.configure(definition).get("ok", true)):
		failures.append("Caller reconfigured an already-live ritual authority.")
	if runtime.serialized_state() != before:
		failures.append("Unauthorized ritual authority attempts changed hidden state.")


static func _check_hostile_restore(definition: Dictionary, failures: Array) -> void:
	var host := RetainedRitualHost.new(definition)
	var runtime = RuntimeScript.new(host)
	runtime.configure(definition)
	var valid := runtime.authenticated_snapshot()
	var restored = RuntimeScript.new(host)
	restored.configure(definition)
	if not bool(restored.restore_snapshot(valid).get("ok", false)):
		failures.append("Authenticated closed restore rejected its own exact snapshot.")
	var hostile_cases: Array = []
	var state: Dictionary
	state = (valid.get("state", {}) as Dictionary).duplicate(true); state["unknown"] = true; hostile_cases.append(_sealed_snapshot(valid, state))
	state = (valid.get("state", {}) as Dictionary).duplicate(true); state["action_sequence"] = "1"; hostile_cases.append(_sealed_snapshot(valid, state))
	state = (valid.get("state", {}) as Dictionary).duplicate(true); (state["actor_states"] as Dictionary)["ghost.actor"] = {}; hostile_cases.append(_sealed_snapshot(valid, state))
	state = (valid.get("state", {}) as Dictionary).duplicate(true); (state["envelope_request_cache"] as Dictionary)["request:bad"] = {"extra": true}; hostile_cases.append(_sealed_snapshot(valid, state))
	state = (valid.get("state", {}) as Dictionary).duplicate(true); state["contract"] = "game_ritual/2"; hostile_cases.append(_sealed_snapshot(valid, state))
	state = (valid.get("state", {}) as Dictionary).duplicate(true); state["transition_sequence"] = 2; state["action_sequence"] = 1; hostile_cases.append(_sealed_snapshot(valid, state))
	state = (valid.get("state", {}) as Dictionary).duplicate(true); state["state_version"] = 2; hostile_cases.append(_sealed_snapshot(valid, state))
	var fingerprint_hostile := valid.duplicate(true); fingerprint_hostile["content_fingerprint"] = "0".repeat(64); hostile_cases.append(fingerprint_hostile)
	var migration_hostile := valid.duplicate(true); migration_hostile["envelope_version"] = 2; migration_hostile["content_fingerprint"] = RuntimeScript.canonical_fingerprint(_without_fingerprint(migration_hostile)); hostile_cases.append(migration_hostile)
	for index in range(hostile_cases.size()):
		var before := restored.serialized_state()
		var result: Dictionary = restored.restore_snapshot(hostile_cases[index])
		if bool(result.get("ok", true)) or str(result.get("error_code", "")) != "invalid_restore" or restored.serialized_state() != before:
			failures.append("Hostile restore/migration case %d did not fail closed without mutation." % index)


static func _check_neutral_opt_in_seams(failures: Array) -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/core/game_ritual_runtime.gd").to_lower()
	var layout_source := FileAccess.get_file_as_string("res://scripts/core/game_ritual_layout.gd").to_lower()
	for forbidden in ["craps", "blackjack", "roulette", "baccarat", "poker", "slots", "pusher"]:
		if runtime_source.contains(forbidden) or layout_source.contains(forbidden):
			failures.append("Shared ritual implementation contains game-specific token %s." % forbidden)
	var canvas_source := FileAccess.get_file_as_string("res://scripts/ui/game_surface_canvas.gd")
	if canvas_source.count("surface_add_ritual_hits(") != 1:
		failures.append("Ritual canvas seam is not opt-in; an existing path invokes it implicitly.")


static func _command_for(runtime, host: RetainedRitualHost, action_id: String, parameters: Dictionary, tag: String) -> Dictionary:
	var snapshot: Dictionary = runtime.serialized_state()
	var authenticated: Dictionary = host.ritual_authenticated_action(action_id)
	var command := {
		"envelope_version": 1,
		"ritual_id": str(runtime.definition.get("ritual_id", "")),
		"session_id": str(snapshot.get("session_id", "")),
		"command_id": "command.%s" % tag,
		"request_key": "request:%s" % tag,
		"action_id": action_id,
		"expected_phase": str(snapshot.get("phase_id", "")),
		"source_id": "player.reserve",
		"target_id": "layout.primary",
		"parameters": parameters.duplicate(true),
		"authenticated_action": authenticated.duplicate(true),
		"boundary": {
			"boundary_id": "boundary.command.%s" % tag,
			"kind": "command",
			"ritual_id": str(runtime.definition.get("ritual_id", "")),
			"session_id": str(snapshot.get("session_id", "")),
			"phase_id": str(snapshot.get("phase_id", "")),
			"ordinal": int(snapshot.get("boundary_ordinal", 0)) + 1,
			"cause_receipt_key": "receipt:command:%s" % tag,
		},
		"receipt_key": "receipt:command:%s" % tag,
		"content_fingerprint": "",
	}
	command["content_fingerprint"] = RuntimeScript.canonical_fingerprint(_without_fingerprint(command))
	return host.issue(command)


static func _execute(runtime, host: RetainedRitualHost, action_id: String, parameters: Dictionary, tag: String, context: Dictionary) -> Dictionary:
	return runtime.process_command(_command_for(runtime, host, action_id, parameters, tag), context)


static func _place_parameters(item_id: String, amount: int) -> Dictionary:
	return {"item_id": item_id, "amount": amount, "confidence": 1.0, "note": "", "labels": [], "weights": []}


static func _play_handler(_action_id: String, parameters: Dictionary, _candidate: Dictionary, context: Dictionary) -> Dictionary:
	var result_id := "result.%d.%s" % [int(context.get("seed", 0)), str(parameters.get("commitment_id", ""))]
	return {
		"ok": true,
		"persisted_state": {"authoritative_result_refs": [{"result_id": result_id}]},
		"result": {"result_id": result_id, "net_change": 10},
		"facts": [{"fact_type": "resolution.completed", "payload": {"result_id": result_id, "net_change": 10}}],
		"operations": [],
	}


static func _hostile_operation_handler(_action_id: String, _parameters: Dictionary, _candidate: Dictionary, _context: Dictionary) -> Dictionary:
	return {"ok": true, "persisted_state": {}, "result": {}, "facts": [], "operations": [{"operation_id": "staff_offer", "family": "actor_ops", "verb": "set_pose", "source_owner_id": "example_table.standard_session", "target_id": "staff.primary", "arguments": {"pose": "offer"}}]}


static func _hostile_fact_handler(_action_id: String, _parameters: Dictionary, _candidate: Dictionary, _context: Dictionary) -> Dictionary:
	return {"ok": true, "persisted_state": {}, "result": {}, "facts": [{"fact_type": "commitment.accepted", "payload": {"commitment_id": "commitment.hostile", "at_risk_total": 5}}], "operations": []}


static func _without_fingerprint(value: Dictionary) -> Dictionary:
	var copy := value.duplicate(true)
	copy.erase("content_fingerprint")
	return copy


static func _exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size(): return false
	for key in keys:
		if not value.has(key): return false
	return true


static func _sealed_snapshot(base: Dictionary, state: Dictionary) -> Dictionary:
	var snapshot := base.duplicate(true)
	snapshot["state"] = state
	snapshot["content_fingerprint"] = RuntimeScript.canonical_fingerprint(_without_fingerprint(snapshot))
	return snapshot


static func _fixture(failures: Array) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("Frozen ritual vocabulary fixture is not valid JSON.")
		return {}
	return parsed
