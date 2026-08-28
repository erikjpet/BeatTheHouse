class_name GameRitualRuntimeContract
extends RefCounted

const RuntimeScript := preload("res://scripts/core/game_ritual_runtime.gd")
const HostScript := preload("res://scripts/core/game_ritual_host_authority.gd")
const SchemaScript := preload("res://scripts/core/game_ritual_schema.gd")
const LayoutScript := preload("res://scripts/core/game_ritual_layout.gd")
const CanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")
const FIXTURE_PATH := "res://scripts/tests/fixtures/game_ritual_vocabulary_v1.json"


static func check(_library, failures: Array) -> void:
	var definition := _fixture(failures)
	if definition.is_empty(): return
	_check_validation(definition, failures)
	_check_intent_authority(definition, failures)
	_check_hostile_candidates(definition, failures)
	_check_checkpoint_restore(definition, failures)
	_check_layout_and_neutrality(definition, failures)


static func _check_validation(definition: Dictionary, failures: Array) -> void:
	if not SchemaScript.validate_definition(definition).is_empty() or not LayoutScript.validate_definition(definition).is_empty():
		failures.append("Frozen game ritual vocabulary is not accepted by schema/layout validation.")
	var malformed := definition.duplicate(true)
	(malformed["ritual_phases"] as Array).remove_at(1)
	if SchemaScript.validate_definition(malformed).is_empty(): failures.append("Ritual schema accepted a transition to a removed phase.")
	malformed = definition.duplicate(true)
	((malformed["actors"] as Array)[0] as Dictionary)["behavior_states"] = []
	if SchemaScript.validate_definition(malformed).is_empty(): failures.append("Ritual schema accepted an actor without behavior states.")
	malformed = definition.duplicate(true)
	((malformed["scene_objects"] as Array)[0] as Dictionary).erase("bounds")
	if SchemaScript.validate_definition(malformed).is_empty(): failures.append("Ritual schema accepted an object without bounds.")
	var invalid_initial := definition.duplicate(true)
	var open_phase: Dictionary = (invalid_initial["ritual_phases"] as Array)[0]
	(open_phase["entry_operations"] as Array).append({"operation_id": "initial_hostile_pose", "family": "actor_ops", "verb": "set_pose", "source_owner_id": "example_table.standard_session", "target_id": "staff.primary", "arguments": {"pose": "hostile"}})
	var invalid_host = _host(invalid_initial)
	if bool(invalid_host.configuration_result().get("ok", true)):
		failures.append("Initial entry operation bypassed complete candidate validation.")


static func _check_intent_authority(definition: Dictionary, failures: Array) -> void:
	var host = _host(definition)
	if not bool(host.configuration_result().get("ok", false)):
		failures.append("Retained host rejected the frozen ritual: %s" % JSON.stringify(host.configuration_result()))
		return
	var initial: Dictionary = host.serialized_state()
	var early: Dictionary = _submit(host, "play.primary", {"commitment_id": "commitment.seed_1"}, "early", {"seed": 999})
	if bool(early.get("ok", true)) or host.serialized_state() != initial: failures.append("Out-of-phase intent changed authoritative host state.")
	var place_token: String = host.intent_token("place")
	var place: Dictionary = host.submit_intent("commit.place", _place_parameters("layout.primary", 5), place_token)
	if not _response_projection_matches(place, host.public_projection(), true): failures.append("Place result projection is not its accepted post-state.")
	var replay: Dictionary = host.submit_intent("commit.place", _place_parameters("layout.primary", 5), place_token)
	if not bool(place.get("ok", false)) or replay != place: failures.append("Host-derived funds intent was not exactly-once replayable.")
	var conflict: Dictionary = host.submit_intent("commit.place", _place_parameters("layout.primary", 6), place_token)
	if str(conflict.get("error_code", "")) != "receipt_content_conflict": failures.append("Intent-key content conflict did not fail closed.")
	var confirm: Dictionary = _submit(host, "commit.confirm", {}, "confirm")
	if not _response_projection_matches(confirm, host.public_projection(), true): failures.append("Confirm result projection is not its accepted post-state.")
	var play: Dictionary = _submit(host, "play.primary", {"commitment_id": "commitment.seed_19"}, "play", {"seed": 999999})
	if not bool(confirm.get("ok", false)) or not bool(play.get("ok", false)) or str(play.get("authoritative_result_ref", "")) != "result.seed_19.commitment_seed_19": failures.append("Host-owned phase/RNG authority did not drive the accepted trace.")
	for response in [place, confirm, play]:
		if not _response_projection_matches(response as Dictionary, host.public_projection(), response == play):
			# Earlier responses intentionally describe their own accepted boundary;
			# the live equality assertion belongs to the latest response.
			if response == play: failures.append("Accepted RitualResult projection does not equal post-commit authority.")
	var before_ghost: Dictionary = host.serialized_state()
	var ghost: Dictionary = _submit(host, "resolution.acknowledge", {}, "ack")
	if not bool(ghost.get("ok", false)): failures.append("Resolution acknowledgement did not reopen the ritual.")
	before_ghost = host.serialized_state()
	ghost = _submit(host, "commit.place", _place_parameters("layout.ghost", 5), "ghost")
	if bool(ghost.get("ok", true)) or host.serialized_state() != before_ghost: failures.append("Undeclared wager item reached pending authority.")
	var probe: Dictionary = host.reflected_runtime_probe()
	var reflected = probe.get("runtime")
	var before_reflection: Dictionary = host.serialized_state()
	var leaked_capability := false
	for method in host.get_method_list():
		if str((method as Dictionary).get("name", "")) == "submit_intent":
			var args: Array = (method as Dictionary).get("args", [])
			if args.size() != 3: leaked_capability = true
			for arg in args:
				if str((arg as Dictionary).get("name", "")).contains("context"): leaked_capability = true
	for property in reflected.get_property_list():
		var name := str((property as Dictionary).get("name", ""))
		if name in ["script", "resource_path", "resource_name", "resource_local_to_scene", "resource_scene_unique_id"]: continue
		var value: Variant = reflected.get(name)
		if typeof(value) in [TYPE_OBJECT, TYPE_CALLABLE] or name.contains("host") or name.contains("lease") or name.contains("issued") or name.contains("context"): leaked_capability = true
	var reflected_state: Variant = reflected.get("state")
	if typeof(reflected_state) == TYPE_DICTIONARY: (reflected_state as Dictionary)["authority"] = "forged"
	reflected.call("process_command", {})
	if leaked_capability or host.serialized_state() != before_reflection: failures.append("Reflected pure runtime exposed or exercised host authority.")


static func _check_hostile_candidates(definition: Dictionary, failures: Array) -> void:
	for callback in [Callable(GameRitualRuntimeContract, "_duplicate_operation_handler"), Callable(GameRitualRuntimeContract, "_invalid_persisted_handler")]:
		var host = _host(definition, {"play.primary": callback})
		_submit(host, "commit.place", _place_parameters("layout.primary", 5), "candidate_place")
		_submit(host, "commit.confirm", {}, "candidate_confirm")
		var before: Dictionary = host.serialized_state()
		var rejected: Dictionary = _submit(host, "play.primary", {"commitment_id": "commitment.seed_4"}, "candidate_play")
		if bool(rejected.get("ok", true)) or host.serialized_state() != before: failures.append("Duplicate operation or invalid persisted proposal published authority.")
	var altered := definition.duplicate(true)
	for handler_value in altered.get("handler_registry", []):
		var handler: Dictionary = handler_value
		if str(handler.get("handler_id", "")) == "play.primary": (handler["accepted_operations"] as Array).append("energy_engaged_staff")
	var altered_host = _host(altered, {"play.primary": Callable(GameRitualRuntimeContract, "_invalid_declared_operation_handler")})
	_submit(altered_host, "commit.place", _place_parameters("layout.primary", 5), "altered_place")
	_submit(altered_host, "commit.confirm", {}, "altered_confirm")
	var altered_before: Dictionary = altered_host.serialized_state()
	var altered_result: Dictionary = _submit(altered_host, "play.primary", {"commitment_id": "commitment.seed_4"}, "altered_play")
	if bool(altered_result.get("ok", true)) or altered_host.serialized_state() != altered_before: failures.append("Allowlisted operation with undeclared arguments published authority.")


static func _check_checkpoint_restore(definition: Dictionary, failures: Array) -> void:
	var host = _host(definition)
	var old_token: String = host.intent_token("old_place")
	host.submit_intent("commit.place", _place_parameters("layout.primary", 5), old_token)
	_submit(host, "commit.confirm", {}, "old_confirm")
	_submit(host, "play.primary", {"commitment_id": "commitment.seed_0"}, "old_play")
	_submit(host, "resolution.acknowledge", {}, "old_ack")
	for round_index in range(32):
		_submit(host, "commit.place", _place_parameters("layout.primary", 5), "long_%d_place" % round_index)
		_submit(host, "commit.confirm", {}, "long_%d_confirm" % round_index)
		_submit(host, "play.primary", {"commitment_id": "commitment.seed_%d" % (round_index + 1)}, "long_%d_play" % round_index)
		_submit(host, "resolution.acknowledge", {}, "long_%d_ack" % round_index)
	var state: Dictionary = host.serialized_state()
	if (state.get("envelope_request_cache", {}) as Dictionary).size() > 128 or (state.get("envelope_receipts", []) as Array).size() > 256: failures.append("Coordinated checkpoint left a live causal collection above its bound.")
	var before_stale: Dictionary = host.serialized_state()
	var stale: Dictionary = host.submit_intent("commit.place", _place_parameters("layout.primary", 5), old_token)
	if str(stale.get("error_code", "")) != "stale_phase" or host.serialized_state() != before_stale: failures.append("Pre-checkpoint intent did not reject as stale and consequence-free.")
	var tail_token: String = host.intent_token("tail_replay_place")
	var tail_response: Dictionary = host.submit_intent("commit.place", _place_parameters("layout.primary", 5), tail_token)
	var snapshot: Dictionary = host.authenticated_snapshot()
	var saved: Dictionary = host.serialized_state()
	var restore: Dictionary = host.restore_snapshot(snapshot)
	if not bool(restore.get("ok", false)) or host.serialized_state() != saved or not (restore.get("replayed_effects", [1]) as Array).is_empty(): failures.append("Checkpoint/tail restore was not exact and effect-free: %s" % JSON.stringify(restore))
	var replay_before: Dictionary = host.serialized_state()
	var tail_replay: Dictionary = host.submit_intent("commit.place", _place_parameters("layout.primary", 5), tail_token)
	if tail_replay != tail_response or host.serialized_state() != replay_before: failures.append("Retained-tail intent replay was not byte-identical and consequence-free.")
	var fresh = _host(definition)
	var fresh_before: Dictionary = fresh.serialized_state()
	var fresh_result: Dictionary = fresh.restore_snapshot(snapshot)
	if bool(fresh_result.get("ok", true)) or fresh.serialized_state() != fresh_before: failures.append("Fresh process self-authorized a snapshot without trusted save ledger.")
	for field in ["authority_epoch", "checkpoint", "tail"]:
		var hostile: Dictionary = snapshot.duplicate(true)
		if field == "authority_epoch": hostile[field] = int(hostile.get(field, 0)) + 1
		elif field == "checkpoint": (hostile[field] as Dictionary)["high_water_boundary"] = int((hostile[field] as Dictionary).get("high_water_boundary", 0)) + 1
		elif not (hostile[field] as Array).is_empty(): ((hostile[field] as Array)[0] as Dictionary)["pre_state_digest"] = "0".repeat(64)
		hostile["content_fingerprint"] = RuntimeScript.canonical_fingerprint(_without_fingerprint(hostile))
		var before: Dictionary = host.serialized_state()
		var rejected: Dictionary = host.restore_snapshot(hostile)
		if bool(rejected.get("ok", true)) or host.serialized_state() != before: failures.append("Hostile checkpoint/tail field %s did not fail closed." % field)


static func _check_layout_and_neutrality(definition: Dictionary, failures: Array) -> void:
	var hits := LayoutScript.compile_pointer_hits(definition, "open")
	var canvas = CanvasScript.new()
	canvas.surface_add_ritual_hits(hits)
	if hits.size() != 1 or canvas.hit_regions.size() != 1: failures.append("Ritual layout/canvas opt-in seam did not preserve one semantic hit.")
	canvas.free()
	var sources := (FileAccess.get_file_as_string("res://scripts/core/game_ritual_runtime.gd") + FileAccess.get_file_as_string("res://scripts/core/game_ritual_host_authority.gd")).to_lower()
	for forbidden in ["craps", "blackjack", "roulette", "baccarat", "poker", "slots", "pusher"]:
		if sources.contains(forbidden): failures.append("Shared ritual authority contains game-specific token %s." % forbidden)


static func _host(definition: Dictionary, handlers: Dictionary = {}):
	var merged := {"play.primary": Callable(GameRitualRuntimeContract, "_play_handler")}
	for key in handlers.keys(): merged[key] = handlers[key]
	return HostScript.new(definition, merged, "session.default_01", Callable(GameRitualRuntimeContract, "_authoritative_context"))


static func _submit(host, action_id: String, parameters: Dictionary, tag: String, caller_context: Dictionary = {}) -> Dictionary:
	return host.submit_intent(action_id, parameters, host.intent_token(tag))


static func _authoritative_context(action_id: String, parameters: Dictionary, _state: Dictionary) -> Dictionary:
	var seed := 0
	if action_id == "play.primary":
		var commitment := str(parameters.get("commitment_id", ""))
		seed = commitment.get_slice("seed_", 1).to_int() if commitment.contains("seed_") else 0
	return {"available_funds": 100, "seed": seed, "account_id": "account.test_ritual"}


static func _place_parameters(item_id: String, amount: int) -> Dictionary:
	return {"item_id": item_id, "amount": amount, "confidence": 1.0, "note": "", "labels": [], "weights": []}


static func _play_handler(_action_id: String, parameters: Dictionary, _candidate: Dictionary, context: Dictionary) -> Dictionary:
	var result_id := "result.seed_%d.%s" % [int(context.get("seed", 0)), str(parameters.get("commitment_id", "")).replace(".", "_")]
	return {"ok": true, "persisted_state": {"authoritative_result_refs": [{"result_id": result_id}]}, "result": {"result_id": result_id, "payout": 15, "net_change": 10}, "facts": [{"fact_type": "resolution.completed", "payload": {"result_id": result_id, "net_change": 10}}], "operations": []}


static func _duplicate_operation_handler(action_id: String, parameters: Dictionary, candidate: Dictionary, context: Dictionary) -> Dictionary:
	var result := _play_handler(action_id, parameters, candidate, context)
	result["operations"] = [{"operation_id": "apparatus_activate", "family": "scene_ops", "verb": "set_state", "source_owner_id": "example_table.standard_session", "target_id": "apparatus.primary", "arguments": {"state_slot": "visual", "state": "active"}}]
	return result


static func _invalid_persisted_handler(action_id: String, parameters: Dictionary, candidate: Dictionary, context: Dictionary) -> Dictionary:
	var result := _play_handler(action_id, parameters, candidate, context)
	result["persisted_state"] = {"authoritative_result_refs": [{"result_id": ""}]}
	return result


static func _invalid_declared_operation_handler(action_id: String, parameters: Dictionary, candidate: Dictionary, context: Dictionary) -> Dictionary:
	var result := _play_handler(action_id, parameters, candidate, context)
	result["operations"] = [{"operation_id": "energy_engaged_staff", "family": "actor_ops", "verb": "set_behavior", "source_owner_id": "example_table.standard_session", "target_id": "staff.primary", "arguments": {"behavior": "hostile"}}]
	return result


static func _response_projection_matches(response: Dictionary, projection: Dictionary, current: bool) -> bool:
	if not current: return true
	var public: Dictionary = response.get("public_projection", {})
	return str(public.get("phase_id", "")) == str(projection.get("phase_id", "")) and int(public.get("pending_total", -1)) == int((projection.get("readable_totals", {}) as Dictionary).get("pending_total", 0)) and int(public.get("at_risk_total", -1)) == int((projection.get("readable_totals", {}) as Dictionary).get("at_risk_total", 0))


static func _without_fingerprint(value: Dictionary) -> Dictionary:
	var copy := value.duplicate(true)
	copy.erase("content_fingerprint")
	return copy


static func _fixture(failures: Array) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("Frozen ritual fixture is invalid JSON.")
		return {}
	return (parsed as Dictionary).duplicate(true)
