class_name DeliveryRunModel
extends RefCounted

const SCHEMA_VERSION := 3
const LEGACY_SCHEMA_VERSION := 2
const CLOSED_CHECKPOINT_SCHEMA_VERSION := 1
const CLOSED_CHECKPOINT_FIELDS := [
	"schema_version", "delivery_instance_id", "job_id", "owner_token", "public_instance_token",
	"outcome_receipt_id", "outcome_receipt_fingerprint", "outcome_cause_fingerprint",
	"resolution_fingerprint", "delivery_receipt_fingerprint", "public_result", "public_result_fingerprint",
]
const MODE_PACKAGE := "package"
const MODE_MULTI_STOP := "multi_stop"
const MODE_HOLD := "hold"
const MODE_GETAWAY := "getaway"
const MODES := [MODE_PACKAGE, MODE_MULTI_STOP, MODE_HOLD, MODE_GETAWAY]
const DEPTH_STATE_SCHEMA_VERSION := 1
const MAX_DEPTH_COMMAND_RECEIPTS := 64
const CARGO_PICKUP_PENDING := "pickup_pending"
const CARGO_CARRIED := "carried"
const CARGO_STASHED := "stashed"
const CARGO_DELIVERED := "delivered"
const CARGO_DITCHED := "ditched"
const CARGO_CONFISCATED := "confiscated"
const CARGO_FOUND := "found"
const CARGO_NONE := "none"
const CARGO_STATES := [
	CARGO_PICKUP_PENDING, CARGO_CARRIED, CARGO_STASHED, CARGO_DELIVERED,
	CARGO_DITCHED, CARGO_CONFISCATED, CARGO_FOUND, CARGO_NONE,
]
const STREET_VERBS := ["pickup", "move", "wait", "duck", "stash", "retrieve", "ditch", "signal", "break_hold", "handoff"]
const HOST_VERBS := STREET_VERBS + ["found", "interruption", "abandon"]


static func begin(spec: Dictionary, started_action: int) -> Dictionary:
	var mode := str(spec.get("mode", MODE_PACKAGE)).strip_edges().to_lower()
	if not MODES.has(mode):
		return {}
	var targets := _normalize_targets(spec.get("targets", []))
	if targets.is_empty():
		return {}
	if mode in [MODE_PACKAGE, MODE_HOLD, MODE_GETAWAY] and targets.size() != 1:
		return {}
	var deadline := maxi(1, int(spec.get("deadline_actions", 1)))
	var assists := _string_array(spec.get("assists", []))
	return normalize_state({
		"schema_version": SCHEMA_VERSION,
		"status": "active",
		"mode": mode,
		"run_id": str(spec.get("run_id", spec.get("route_id", "delivery"))).strip_edges(),
		"job_id": str(spec.get("job_id", "")).strip_edges(),
		"source_event_id": str(spec.get("source_event_id", "")).strip_edges(),
		"started_action": maxi(0, started_action),
		"last_boundary_action": maxi(0, started_action),
		"deadline_total": deadline,
		"deadline_remaining": deadline,
		"targets": targets,
		"cargo_id": str(spec.get("cargo_id", "crew_package")).strip_edges(),
		"cargo_label": str(spec.get("cargo_label", "Crew package")).strip_edges(),
		"cargo_heat_per_travel": maxi(0, int(spec.get("cargo_heat_per_travel", 2))),
		"depth_state": _initial_depth_state(mode, spec),
		"consumer_payload": _copy_dict(spec.get("consumer_payload", {})),
		"fast_threshold_actions": maxi(0, int(spec.get("fast_threshold_actions", deadline - 2))),
		"boundaries_elapsed": 0,
		"arrival_count": 0,
		"handoff_pending_node_id": "",
		"hold_required_actions": maxi(1, int(spec.get("hold_required_actions", spec.get("window_actions", 3)))),
		"hold_progress": 0,
		"hold_attention_limit": clampi(int(spec.get("hold_attention_limit", 70)), 0, 100),
		"pursuit_pressure": maxi(0, int(spec.get("pursuit_pressure", 0))),
		"pursuit_per_boundary": maxi(0, int(spec.get("pursuit_per_boundary", 2))),
		"pursuit_limit": maxi(1, int(spec.get("pursuit_limit", 12))),
		"assists_available": assists,
		"assists_used": [],
		"assists_effect": maxi(1, int(spec.get("assist_relief", 4))),
		"heat_earned": 0,
		"confiscated": false,
		"resolution": {},
		"receipt": {},
		"closed_checkpoint": {},
		"world_applied": false,
	})


static func normalize_state(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).is_empty():
		return {}
	var source: Dictionary = value
	var source_schema := int(source.get("schema_version", 0))
	if source_schema not in [LEGACY_SCHEMA_VERSION, SCHEMA_VERSION]:
		return {}
	if source_schema == LEGACY_SCHEMA_VERSION and source.has("depth_state"):
		return {}
	var mode := str(source.get("mode", MODE_PACKAGE)).strip_edges().to_lower()
	if not MODES.has(mode):
		return {}
	var targets := _normalize_targets(source.get("targets", []))
	if targets.is_empty():
		return {}
	var deadline_total := maxi(1, int(source.get("deadline_total", source.get("deadline_actions", 1))))
	var status := str(source.get("status", "active")).strip_edges().to_lower()
	if not ["active", "resolved"].has(status):
		status = "resolved"
	var resolution := _copy_dict(source.get("resolution", {}))
	if status == "resolved" and resolution.is_empty():
		resolution = _resolution("failed", "invalid_state", source, false)
	var depth_state := _normalize_depth_state(source.get("depth_state", {})) if source_schema == SCHEMA_VERSION else _legacy_depth_state(source, mode)
	if depth_state.is_empty():
		return {}
	var result := {
		"schema_version": SCHEMA_VERSION,
		"status": status,
		"mode": mode,
		"run_id": str(source.get("run_id", "delivery")).strip_edges(),
		"job_id": str(source.get("job_id", "")).strip_edges(),
		"source_event_id": str(source.get("source_event_id", "")).strip_edges(),
		"started_action": maxi(0, int(source.get("started_action", 0))),
		"last_boundary_action": maxi(0, int(source.get("last_boundary_action", source.get("started_action", 0)))),
		"deadline_total": deadline_total,
		"deadline_remaining": clampi(int(source.get("deadline_remaining", deadline_total)), 0, deadline_total),
		"targets": targets,
		"cargo_id": str(source.get("cargo_id", "crew_package")).strip_edges(),
		"cargo_label": str(source.get("cargo_label", "Crew package")).strip_edges(),
		"cargo_heat_per_travel": maxi(0, int(source.get("cargo_heat_per_travel", 2))),
		"depth_state": depth_state,
		"consumer_payload": _copy_dict(source.get("consumer_payload", {})),
		"fast_threshold_actions": maxi(0, int(source.get("fast_threshold_actions", deadline_total - 2))),
		"boundaries_elapsed": maxi(0, int(source.get("boundaries_elapsed", 0))),
		"arrival_count": maxi(0, int(source.get("arrival_count", 0))),
		"handoff_pending_node_id": str(source.get("handoff_pending_node_id", "")).strip_edges(),
		"hold_required_actions": maxi(1, int(source.get("hold_required_actions", 3))),
		"hold_progress": maxi(0, int(source.get("hold_progress", 0))),
		"hold_attention_limit": clampi(int(source.get("hold_attention_limit", 70)), 0, 100),
		"pursuit_pressure": maxi(0, int(source.get("pursuit_pressure", 0))),
		"pursuit_per_boundary": maxi(0, int(source.get("pursuit_per_boundary", 2))),
		"pursuit_limit": maxi(1, int(source.get("pursuit_limit", 12))),
		"assists_available": _string_array(source.get("assists_available", source.get("assists", []))),
		"assists_used": _string_array(source.get("assists_used", [])),
		"assists_effect": maxi(1, int(source.get("assists_effect", source.get("assist_relief", 4)))),
		"heat_earned": maxi(0, int(source.get("heat_earned", 0))),
		"confiscated": bool(source.get("confiscated", false)),
		"resolution": resolution,
		"receipt": _copy_dict(source.get("receipt", {})),
		"world_applied": bool(source.get("world_applied", false)),
	}
	# Preserve an untrusted persisted checkpoint byte-for-byte. Validation belongs
	# at the consume boundary; silently normalizing hostile data would turn a
	# detectable corrupt authority record into an ambiguous legacy snapshot.
	if source.has("closed_checkpoint"):
		result["closed_checkpoint"] = _copy_dict(source.get("closed_checkpoint", {}))
	return result


static func closed_checkpoint(state_value: Variant) -> Dictionary:
	var state := normalize_state(state_value)
	return _copy_dict(state.get("closed_checkpoint", {}))


# DeliveryRunModel is the only issuer of the persisted closed checkpoint. The
# caller supplies a preview made from trusted live adapter state; all persisted
# identities and consequence fingerprints are sealed here from the resolved
# delivery state and the canonical public result.
static func commit_closed_checkpoint(state_value: Variant, binding_value: Dictionary, public_result_value: Dictionary) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty() or str(state.get("status", "")) != "resolved":
		return {"ok": false, "state": state, "errors": ["delivery checkpoint requires a resolved delivery"]}
	var binding := binding_value.duplicate(true)
	var public_result := _canonical_public_result(public_result_value)
	if public_result.is_empty() or JSON.stringify(public_result_value) != JSON.stringify(public_result):
		return {"ok": false, "state": state, "errors": ["delivery checkpoint public result is not canonical"]}
	for key in ["owner_token", "public_instance_token", "outcome_receipt_id", "outcome_receipt_fingerprint", "outcome_cause_fingerprint"]:
		if typeof(binding.get(key)) != TYPE_STRING or str(binding.get(key, "")).is_empty() or str(binding.get(key, "")) != str(binding.get(key, "")).strip_edges():
			return {"ok": false, "state": state, "errors": ["delivery checkpoint binding is incomplete or noncanonical"]}
	var delivery_instance_id := str(state.get("job_id", "")).strip_edges()
	if delivery_instance_id.is_empty(): delivery_instance_id = str(state.get("run_id", "")).strip_edges()
	if delivery_instance_id.is_empty() or delivery_instance_id != str(binding.get("public_instance_token", "")):
		return {"ok": false, "state": state, "errors": ["delivery checkpoint public instance does not match the resolved delivery"]}
	var checkpoint := {
		"schema_version": CLOSED_CHECKPOINT_SCHEMA_VERSION,
		"delivery_instance_id": delivery_instance_id,
		"job_id": str(state.get("job_id", "")),
		"owner_token": str(binding.get("owner_token", "")),
		"public_instance_token": str(binding.get("public_instance_token", "")),
		"outcome_receipt_id": str(binding.get("outcome_receipt_id", "")),
		"outcome_receipt_fingerprint": str(binding.get("outcome_receipt_fingerprint", "")),
		"outcome_cause_fingerprint": str(binding.get("outcome_cause_fingerprint", "")),
		"resolution_fingerprint": _fingerprint(_copy_dict(state.get("resolution", {}))),
		"delivery_receipt_fingerprint": _fingerprint(_copy_dict(state.get("receipt", {}))),
		"public_result": public_result,
		"public_result_fingerprint": _fingerprint(public_result),
	}
	state["closed_checkpoint"] = checkpoint
	state["world_applied"] = true
	return {"ok": true, "state": state, "checkpoint": checkpoint.duplicate(true), "public_result": public_result.duplicate(true), "errors": []}


static func closed_checkpoint_errors(state_value: Variant, binding_value: Dictionary = {}) -> Array:
	var state := normalize_state(state_value)
	var checkpoint := _copy_dict(state.get("closed_checkpoint", {}))
	var errors: Array = []
	if checkpoint.is_empty(): return ["delivery closed checkpoint is missing"]
	var keys := checkpoint.keys()
	keys.sort()
	var expected := CLOSED_CHECKPOINT_FIELDS.duplicate()
	expected.sort()
	if keys != expected: errors.append("delivery closed checkpoint fields are not exact")
	if typeof(checkpoint.get("schema_version")) != TYPE_INT or int(checkpoint.get("schema_version", 0)) != CLOSED_CHECKPOINT_SCHEMA_VERSION:
		errors.append("delivery closed checkpoint schema is invalid")
	for key in CLOSED_CHECKPOINT_FIELDS:
		if key in ["schema_version", "public_result"]: continue
		if typeof(checkpoint.get(key)) != TYPE_STRING:
			errors.append("delivery closed checkpoint field %s has the wrong type" % key)
	var delivery_instance_id := str(state.get("job_id", "")).strip_edges()
	if delivery_instance_id.is_empty(): delivery_instance_id = str(state.get("run_id", "")).strip_edges()
	if str(checkpoint.get("delivery_instance_id", "")) != delivery_instance_id \
			or str(checkpoint.get("job_id", "")) != str(state.get("job_id", "")) \
			or str(checkpoint.get("public_instance_token", "")) != delivery_instance_id:
		errors.append("delivery closed checkpoint does not bind this delivery instance")
	for key in ["delivery_instance_id", "owner_token", "public_instance_token", "outcome_receipt_id", "outcome_receipt_fingerprint", "outcome_cause_fingerprint", "resolution_fingerprint", "delivery_receipt_fingerprint", "public_result_fingerprint"]:
		var text := str(checkpoint.get(key, ""))
		if text.is_empty() or text != text.strip_edges(): errors.append("delivery closed checkpoint field %s is noncanonical" % key)
	if str(checkpoint.get("resolution_fingerprint", "")) != _fingerprint(_copy_dict(state.get("resolution", {}))):
		errors.append("delivery closed checkpoint resolution fingerprint does not match")
	if str(checkpoint.get("delivery_receipt_fingerprint", "")) != _fingerprint(_copy_dict(state.get("receipt", {}))):
		errors.append("delivery closed checkpoint receipt fingerprint does not match")
	var public_result := _copy_dict(checkpoint.get("public_result", {}))
	var canonical_public_result := _canonical_public_result(public_result)
	if canonical_public_result.is_empty() or JSON.stringify(public_result) != JSON.stringify(canonical_public_result):
		errors.append("delivery closed checkpoint public result is not canonical")
	elif str(checkpoint.get("public_result_fingerprint", "")) != _fingerprint(public_result):
		errors.append("delivery closed checkpoint public result fingerprint does not match")
	for key in ["owner_token", "public_instance_token", "outcome_receipt_id", "outcome_receipt_fingerprint", "outcome_cause_fingerprint"]:
		if binding_value.has(key) and str(checkpoint.get(key, "")) != str(binding_value.get(key, "")):
			errors.append("delivery closed checkpoint does not match live %s" % key)
	if not bool(state.get("world_applied", false)):
		errors.append("delivery closed checkpoint exists without committed world consequences")
	return errors


static func snapshot(state_value: Variant) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty():
		return {}
	var delivered := 0
	for target_value in state.get("targets", []):
		if typeof(target_value) == TYPE_DICTIONARY and str((target_value as Dictionary).get("status", "pending")) == "delivered":
			delivered += 1
	return {
		"schema_version": SCHEMA_VERSION,
		"status": str(state.get("status", "active")),
		"mode": str(state.get("mode", MODE_PACKAGE)),
		"run_id": str(state.get("run_id", "delivery")),
		"job_id": str(state.get("job_id", "")),
		"deadline_total": int(state.get("deadline_total", 1)),
		"deadline_remaining": int(state.get("deadline_remaining", 0)),
		"targets": _copy_array(state.get("targets", [])),
		"target_count": (state.get("targets", []) as Array).size(),
		"delivered_count": delivered,
		"cargo_id": str(state.get("cargo_id", "")),
		"cargo_label": str(state.get("cargo_label", "Crew package")),
		"physical": physical_projection(state),
		"carrying_contraband": str(_copy_dict(_copy_dict(state.get("depth_state", {})).get("cargo", {})).get("status", "")) == CARGO_CARRIED,
		"handoff_pending_node_id": str(state.get("handoff_pending_node_id", "")),
		"hold_required_actions": int(state.get("hold_required_actions", 0)),
		"hold_progress": int(state.get("hold_progress", 0)),
		"pursuit_pressure": int(state.get("pursuit_pressure", 0)),
		"pursuit_limit": int(state.get("pursuit_limit", 0)),
		"assists_available": _copy_array(state.get("assists_available", [])),
		"assists_used": _copy_array(state.get("assists_used", [])),
		"resolution": _copy_dict(state.get("resolution", {})),
		"receipt": _copy_dict(state.get("receipt", {})),
	}


static func physical_projection(state_value: Variant) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty():
		return {}
	var depth := _copy_dict(state.get("depth_state", {}))
	var cargo := _copy_dict(depth.get("cargo", {}))
	var position := _copy_dict(depth.get("position", {}))
	return {
		"schema_version": DEPTH_STATE_SCHEMA_VERSION,
		"instance_id": str(state.get("job_id", "")) if not str(state.get("job_id", "")).is_empty() else str(state.get("run_id", "")),
		"mode": str(state.get("mode", "")),
		"cargo_id": str(state.get("cargo_id", "")),
		"cargo_label": str(state.get("cargo_label", "")),
		"cargo_state": str(cargo.get("status", CARGO_NONE)),
		"cargo_node_id": str(cargo.get("node_id", "")),
		"cargo_place_kind": str(cargo.get("place_kind", "")),
		"cargo_place_id": str(cargo.get("place_id", "")),
		"position_node_id": str(position.get("node_id", "")),
		"previous_node_id": str(position.get("previous_node_id", "")),
		"last_verb": str(position.get("last_verb", "")),
		"command_sequence": int(depth.get("command_sequence", 0)),
		"available_verbs": _available_physical_verbs(state),
		"hold_signals": _copy_array(depth.get("hold_signals", [])),
		"hold_aftermath": _copy_dict(depth.get("hold_aftermath", {})),
		"pursuit_aftermath": _copy_dict(depth.get("pursuit_aftermath", {})),
	}


static func bind_legacy_position(state_value: Variant, host_node_id: String) -> Dictionary:
	var state := normalize_state(state_value)
	var clean_node := host_node_id.strip_edges()
	if state.is_empty() or clean_node.is_empty():
		return state
	var depth := _copy_dict(state.get("depth_state", {}))
	var position := _copy_dict(depth.get("position", {}))
	if str(depth.get("origin", "")) != "legacy_v2" or not str(position.get("node_id", "")).is_empty():
		return state
	depth["position"] = _physical_position(clean_node, "", "legacy_restore")
	var cargo := _copy_dict(depth.get("cargo", {}))
	if str(cargo.get("status", "")) == CARGO_CARRIED and str(cargo.get("node_id", "")).is_empty():
		cargo["node_id"] = clean_node
		depth["cargo"] = cargo
	state["depth_state"] = depth
	return state


static func advance_boundaries(state_value: Variant, amount: int, current_node_id: String, attention: int, action_index: int) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty() or str(state.get("status", "")) != "active" or amount <= 0:
		return state
	for _boundary in range(amount):
		if str(state.get("status", "")) != "active":
			break
		state["boundaries_elapsed"] = int(state.get("boundaries_elapsed", 0)) + 1
		state["deadline_remaining"] = maxi(0, int(state.get("deadline_remaining", 0)) - 1)
		state["last_boundary_action"] = maxi(int(state.get("last_boundary_action", 0)), action_index - amount + _boundary + 1)
		if str(state.get("mode", "")) == MODE_HOLD:
			var target_node_id := str(((state.get("targets", []) as Array)[0] as Dictionary).get("node_id", ""))
			if current_node_id == target_node_id:
				if attention > int(state.get("hold_attention_limit", 70)):
					state = _resolve(state, "failed", "attention", false)
					continue
				state["hold_progress"] = int(state.get("hold_progress", 0)) + 1
				if int(state.get("hold_progress", 0)) >= int(state.get("hold_required_actions", 1)):
					state = _resolve(state, "success", "held_window", true)
					continue
		elif str(state.get("mode", "")) == MODE_GETAWAY:
			var consumer_payload := _copy_dict(state.get("consumer_payload", {}))
			var start_grace := maxi(0, int(consumer_payload.get("start_boundary_grace", 0)))
			if start_grace > 0:
				consumer_payload["start_boundary_grace"] = start_grace - 1
				state["consumer_payload"] = consumer_payload
			else:
				state["pursuit_pressure"] = int(state.get("pursuit_pressure", 0)) + int(state.get("pursuit_per_boundary", 0))
			if int(state.get("pursuit_pressure", 0)) >= int(state.get("pursuit_limit", 1)):
				state = _resolve(state, "failed", "caught", false)
				continue
		if int(state.get("deadline_remaining", 0)) <= 0:
			state = _resolve(state, "failed", "deadline", false)
	return state


static func note_arrival(state_value: Variant, node_id: String) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty() or str(state.get("status", "")) != "active":
		return state
	var clean_node_id := node_id.strip_edges()
	if clean_node_id.is_empty():
		return state
	state = _record_physical_position(state, clean_node_id, "move")
	state["arrival_count"] = int(state.get("arrival_count", 0)) + 1
	var target_index := _pending_target_index(state, clean_node_id)
	if target_index < 0:
		return state
	if str(state.get("mode", "")) == MODE_GETAWAY:
		return _resolve(state, "success", "escaped", true)
	if str(state.get("mode", "")) == MODE_HOLD:
		return state
	state["handoff_pending_node_id"] = clean_node_id
	return state


static func complete_handoff(state_value: Variant, node_id: String) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty() or str(state.get("status", "")) != "active":
		return state
	var clean_node_id := node_id.strip_edges()
	if clean_node_id.is_empty() or clean_node_id != str(state.get("handoff_pending_node_id", "")):
		return state
	var depth := _copy_dict(state.get("depth_state", {}))
	var cargo := _copy_dict(depth.get("cargo", {}))
	var position := _copy_dict(depth.get("position", {}))
	if str(cargo.get("status", "")) != CARGO_CARRIED or str(cargo.get("node_id", "")) != clean_node_id \
			or str(position.get("node_id", "")) != clean_node_id:
		return state
	var targets: Array = state.get("targets", [])
	var target_index := _pending_target_index(state, clean_node_id)
	if target_index < 0:
		return state
	var target: Dictionary = targets[target_index]
	target["status"] = "delivered"
	target["delivered_boundary"] = int(state.get("boundaries_elapsed", 0))
	targets[target_index] = target
	state["targets"] = targets
	state["handoff_pending_node_id"] = ""
	if _all_targets_delivered(state):
		depth["cargo"] = _physical_cargo(CARGO_DELIVERED, clean_node_id, "handoff", str(target.get("id", "")))
		state["depth_state"] = depth
		return _resolve(state, "success", "delivered", true)
	return state


# Internal host seam. RunState derives every field from live map/environment
# state and passes a closed record only after the physical action has occurred.
# UI callers can request a verb, but cannot supply location, route, cover,
# attention, target, or consequence authority.
static func apply_host_action(state_value: Variant, verb: String, receipt_key: String, host_context_value: Dictionary) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty():
		return {}
	var action := verb.strip_edges()
	var clean_receipt := receipt_key.strip_edges()
	var host_context := _normalize_host_context(host_context_value)
	if action not in HOST_VERBS or clean_receipt.is_empty() or clean_receipt != receipt_key or host_context.is_empty():
		return state
	var envelope := {"command_id": action, "host_context": host_context}
	var replay := _depth_receipt_replay(state, clean_receipt, envelope)
	if replay >= 0:
		return state
	if replay == -2 or str(state.get("status", "")) != "active":
		return state
	if _copy_array(_copy_dict(state.get("depth_state", {})).get("command_receipts", [])).size() >= MAX_DEPTH_COMMAND_RECEIPTS:
		return state
	var node_id := str(host_context.get("node_id", ""))
	var destination_node_id := str(host_context.get("destination_node_id", ""))
	var target_id := str(host_context.get("target_id", ""))
	var place_id := str(host_context.get("place_id", ""))
	var cover_id := str(host_context.get("cover_id", ""))
	var signal_id := str(host_context.get("signal_id", ""))
	var action_index := int(host_context.get("action_index", 0))
	var attention := int(host_context.get("attention", 0))
	var depth := _copy_dict(state.get("depth_state", {}))
	var cargo := _copy_dict(depth.get("cargo", {}))
	var position := _copy_dict(depth.get("position", {}))
	match action:
		"pickup":
			if str(cargo.get("status", "")) != CARGO_PICKUP_PENDING or node_id.is_empty() \
					or node_id != str(cargo.get("node_id", "")) or node_id != str(position.get("node_id", "")) \
					or target_id.is_empty() or target_id != str(cargo.get("place_id", "")):
				return state
			depth["cargo"] = _physical_cargo(CARGO_CARRIED, node_id, "player", "player")
			state["depth_state"] = depth
		"move":
			if node_id.is_empty() or destination_node_id.is_empty() or node_id != str(position.get("node_id", "")) or node_id == destination_node_id:
				return state
			state = _record_physical_position(state, destination_node_id, action)
			state = note_arrival(state, destination_node_id)
		"wait":
			if node_id.is_empty() or node_id != str(position.get("node_id", "")):
				return state
			state = _record_physical_position(state, node_id, action)
			if str(state.get("mode", "")) == MODE_HOLD:
				state = _advance_hold_choice(state, node_id, attention, action_index, "")
		"duck":
			if node_id.is_empty() or node_id != str(position.get("node_id", "")) or cover_id.is_empty():
				return state
			state = _record_physical_position(state, node_id, action)
			if str(state.get("mode", "")) == MODE_GETAWAY:
				state["pursuit_pressure"] = maxi(0, int(state.get("pursuit_pressure", 0)) - int(state.get("pursuit_per_boundary", 0)))
		"stash":
			if str(cargo.get("status", "")) != CARGO_CARRIED or node_id.is_empty() or place_id.is_empty() \
					or node_id != str(position.get("node_id", "")) or node_id != str(cargo.get("node_id", "")):
				return state
			depth["cargo"] = _physical_cargo(CARGO_STASHED, node_id, "stash", place_id)
			state["depth_state"] = depth
		"retrieve":
			if str(cargo.get("status", "")) != CARGO_STASHED or node_id.is_empty() or place_id.is_empty() \
					or node_id != str(position.get("node_id", "")) or node_id != str(cargo.get("node_id", "")) \
					or place_id != str(cargo.get("place_id", "")):
				return state
			depth["cargo"] = _physical_cargo(CARGO_CARRIED, node_id, "player", "player")
			state["depth_state"] = depth
		"ditch":
			if str(cargo.get("status", "")) not in [CARGO_CARRIED, CARGO_STASHED] or node_id.is_empty() \
					or node_id != str(cargo.get("node_id", "")) or (str(cargo.get("status", "")) == CARGO_STASHED and place_id != str(cargo.get("place_id", ""))):
				return state
			depth["cargo"] = _physical_cargo(CARGO_DITCHED, node_id, "street", place_id)
			state["depth_state"] = depth
			state = _resolve(state, "failed", "ditched", false)
		"found":
			if str(cargo.get("status", "")) != CARGO_STASHED or node_id.is_empty() or place_id.is_empty() \
					or node_id != str(cargo.get("node_id", "")) or place_id != str(cargo.get("place_id", "")):
				return state
			depth["cargo"] = _physical_cargo(CARGO_FOUND, node_id, "finder", target_id)
			state["depth_state"] = depth
			state = _resolve(state, "failed", "cargo_found", false)
		"signal":
			if str(state.get("mode", "")) != MODE_HOLD or signal_id.is_empty():
				return state
			state = _advance_hold_choice(state, node_id, attention, action_index, signal_id)
		"break_hold":
			if str(state.get("mode", "")) != MODE_HOLD or node_id != str(position.get("node_id", "")):
				return state
			depth["hold_aftermath"] = {"outcome": "broken_early", "node_id": node_id, "action_index": action_index}
			state["depth_state"] = depth
			state = _resolve(state, "failed", "hold_broken", false)
		"interruption":
			var interruption_reason := str(host_context.get("reason", "interrupted"))
			if interruption_reason.is_empty(): interruption_reason = "interrupted"
			if str(state.get("mode", "")) == MODE_HOLD:
				depth["hold_aftermath"] = {"outcome": interruption_reason, "node_id": node_id, "action_index": action_index}
			elif str(state.get("mode", "")) == MODE_GETAWAY:
				depth["pursuit_aftermath"] = {"outcome": interruption_reason, "node_id": node_id, "action_index": action_index}
			state["depth_state"] = depth
			state = _resolve(state, "failed", interruption_reason, false)
		"abandon":
			var abandon_reason := str(host_context.get("reason", "abandoned"))
			if abandon_reason.is_empty(): abandon_reason = "abandoned"
			state = _resolve(state, "failed", abandon_reason, false)
		"handoff":
			var next_target_index := _next_pending_target_index(state)
			if next_target_index < 0:
				return state
			var next_target := _copy_dict(_copy_array(state.get("targets", []))[next_target_index])
			if target_id.is_empty() or target_id != str(next_target.get("id", "")) or node_id != str(next_target.get("node_id", "")):
				return state
			var handed := complete_handoff(state, node_id)
			if JSON.stringify(handed) == JSON.stringify(state):
				return state
			state = handed
	state = _append_depth_receipt(state, clean_receipt, action, envelope)
	return state


static func use_assist(state_value: Variant, assist_id: String) -> Dictionary:
	var state := normalize_state(state_value)
	var clean_id := assist_id.strip_edges()
	if state.is_empty() or str(state.get("status", "")) != "active" or str(state.get("mode", "")) != MODE_GETAWAY:
		return state
	var available := _string_array(state.get("assists_available", []))
	var used := _string_array(state.get("assists_used", []))
	if clean_id.is_empty() or not available.has(clean_id) or used.has(clean_id):
		return state
	used.append(clean_id)
	state["assists_used"] = used
	state["pursuit_pressure"] = maxi(0, int(state.get("pursuit_pressure", 0)) - int(state.get("assists_effect", 4)))
	return state


static func add_heat(state_value: Variant, amount: int) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty():
		return state
	state["heat_earned"] = int(state.get("heat_earned", 0)) + maxi(0, amount)
	return state


static func confiscate(state_value: Variant, reason: String = "swept") -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty() or str(state.get("status", "")) != "active":
		return state
	state["confiscated"] = true
	var depth := _copy_dict(state.get("depth_state", {}))
	var position := _copy_dict(depth.get("position", {}))
	depth["cargo"] = _physical_cargo(CARGO_CONFISCATED, str(position.get("node_id", "")), "police", "")
	state["depth_state"] = depth
	return _resolve(state, "failed", reason.strip_edges() if not reason.strip_edges().is_empty() else "swept", false)


static func abandon(state_value: Variant, reason: String = "abandoned") -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty() or str(state.get("status", "")) != "active":
		return state
	return _resolve(state, "failed", reason.strip_edges() if not reason.strip_edges().is_empty() else "abandoned", false)


static func _resolve(state_value: Dictionary, outcome: String, reason: String, clean: bool) -> Dictionary:
	var state := state_value.duplicate(true)
	state["status"] = "resolved"
	state["handoff_pending_node_id"] = ""
	state["resolution"] = _resolution(outcome, reason, state, clean)
	return state


static func _resolution(outcome: String, reason: String, state: Dictionary, clean: bool) -> Dictionary:
	var elapsed := maxi(0, int(state.get("boundaries_elapsed", 0)))
	return {
		"outcome": outcome,
		"reason": reason,
		"clean": clean and int(state.get("heat_earned", 0)) <= 0 and not bool(state.get("confiscated", false)),
		"fast": outcome == "success" and elapsed <= int(state.get("fast_threshold_actions", 0)),
		"boundaries_elapsed": elapsed,
		"deadline_remaining": maxi(0, int(state.get("deadline_remaining", 0))),
	}


static func _pending_target_index(state: Dictionary, node_id: String) -> int:
	var clean_node_id := node_id.strip_edges()
	var targets: Array = state.get("targets", [])
	for index in range(targets.size()):
		if typeof(targets[index]) != TYPE_DICTIONARY:
			continue
		var target: Dictionary = targets[index]
		if str(target.get("node_id", "")) == clean_node_id and str(target.get("status", "pending")) == "pending":
			return index
	return -1


static func _all_targets_delivered(state: Dictionary) -> bool:
	for target_value in state.get("targets", []):
		if typeof(target_value) != TYPE_DICTIONARY or str((target_value as Dictionary).get("status", "pending")) != "delivered":
			return false
	return true


static func _next_pending_target_index(state: Dictionary) -> int:
	var targets := _copy_array(state.get("targets", []))
	for index in range(targets.size()):
		if str(_copy_dict(targets[index]).get("status", "pending")) == "pending":
			return index
	return -1


static func _record_physical_position(state_value: Dictionary, node_id: String, verb: String) -> Dictionary:
	var state := state_value.duplicate(true)
	var depth := _copy_dict(state.get("depth_state", {}))
	var position := _copy_dict(depth.get("position", {}))
	var clean_node := node_id.strip_edges()
	if clean_node.is_empty():
		return state
	if clean_node != str(position.get("node_id", "")):
		position["previous_node_id"] = str(position.get("node_id", ""))
		position["node_id"] = clean_node
	position["last_verb"] = verb.strip_edges()
	depth["position"] = position
	var cargo := _copy_dict(depth.get("cargo", {}))
	if str(cargo.get("status", "")) == CARGO_CARRIED:
		cargo["node_id"] = clean_node
		depth["cargo"] = cargo
	state["depth_state"] = depth
	return state


static func _advance_hold_choice(state_value: Dictionary, node_id: String, attention: int, action_index: int, signal_id: String) -> Dictionary:
	var state := state_value.duplicate(true)
	var targets := _copy_array(state.get("targets", []))
	if targets.is_empty() or node_id != str(_copy_dict(targets[0]).get("node_id", "")):
		return state_value
	var depth := _copy_dict(state.get("depth_state", {}))
	if not signal_id.is_empty():
		var signals := _copy_array(depth.get("hold_signals", []))
		if signals.size() >= MAX_DEPTH_COMMAND_RECEIPTS:
			return state_value
		signals.append({"signal_id": signal_id, "node_id": node_id, "action_index": action_index})
		depth["hold_signals"] = signals
		state["depth_state"] = depth
	state = advance_boundaries(state, 1, node_id, clampi(attention, 0, 100), action_index)
	if str(state.get("status", "")) == "resolved":
		depth = _copy_dict(state.get("depth_state", {}))
		depth["hold_aftermath"] = {"outcome": str(_copy_dict(state.get("resolution", {})).get("reason", "failed")), "node_id": node_id, "action_index": action_index}
		state["depth_state"] = depth
	return state


static func _normalize_host_context(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = value
	var keys := source.keys()
	keys.sort()
	var exact := ["action_index", "attention", "cover_id", "destination_node_id", "node_id", "place_id", "reason", "schema_version", "signal_id", "target_id"]
	if keys != exact or typeof(source.get("schema_version")) != TYPE_INT or int(source.get("schema_version", 0)) != 1 \
			or typeof(source.get("action_index")) != TYPE_INT or int(source.get("action_index", -1)) < 0 \
			or typeof(source.get("attention")) != TYPE_INT or int(source.get("attention", -1)) not in range(0, 101):
		return {}
	var result := {"schema_version": 1, "action_index": int(source.get("action_index", 0)), "attention": int(source.get("attention", 0))}
	for key in ["cover_id", "destination_node_id", "node_id", "place_id", "reason", "signal_id", "target_id"]:
		if typeof(source.get(key)) != TYPE_STRING or str(source.get(key, "")) != str(source.get(key, "")).strip_edges():
			return {}
		result[key] = str(source.get(key, ""))
	return result


static func _depth_receipt_replay(state: Dictionary, receipt_key: String, envelope: Dictionary) -> int:
	var expected_fingerprint := _fingerprint(envelope)
	for receipt_value in _copy_array(_copy_dict(state.get("depth_state", {})).get("command_receipts", [])):
		var receipt := _copy_dict(receipt_value)
		if str(receipt.get("receipt_key", "")) != receipt_key:
			continue
		return int(receipt.get("sequence", 0)) if str(receipt.get("command_record_fingerprint", "")) == expected_fingerprint else -2
	return -1


static func _append_depth_receipt(state_value: Dictionary, receipt_key: String, command_id: String, envelope: Dictionary) -> Dictionary:
	var state := state_value.duplicate(true)
	var depth := _copy_dict(state.get("depth_state", {}))
	var receipts := _copy_array(depth.get("command_receipts", []))
	if receipts.size() >= MAX_DEPTH_COMMAND_RECEIPTS:
		return state_value
	receipts.append({
		"receipt_key": receipt_key,
		"command_id": command_id,
		"command_record_fingerprint": _fingerprint(envelope),
		"sequence": receipts.size() + 1,
	})
	depth["command_receipts"] = receipts
	depth["command_sequence"] = receipts.size()
	state["depth_state"] = depth
	return state


static func _initial_depth_state(mode: String, spec: Dictionary) -> Dictionary:
	var origin_node_id := str(spec.get("start_node_id", spec.get("current_node_id", ""))).strip_edges()
	var cargo_status := CARGO_NONE if mode in [MODE_HOLD, MODE_GETAWAY] else CARGO_PICKUP_PENDING
	var cargo_place_kind := "none" if cargo_status == CARGO_NONE else "pickup_contact"
	var cargo_place_id := "" if cargo_status == CARGO_NONE else str(spec.get("pickup_object_id", "delivery_pickup")).strip_edges()
	return {
		"schema_version": DEPTH_STATE_SCHEMA_VERSION,
		"origin": "current",
		"cargo": _physical_cargo(cargo_status, origin_node_id, cargo_place_kind, cargo_place_id),
		"position": _physical_position(origin_node_id, "", "start"),
		"command_receipts": [],
		"command_sequence": 0,
		"hold_signals": [],
		"hold_aftermath": {},
		"pursuit_aftermath": {},
	}


static func _legacy_depth_state(source: Dictionary, mode: String) -> Dictionary:
	var node_id := str(source.get("handoff_pending_node_id", "")).strip_edges()
	var cargo_status := CARGO_NONE if mode in [MODE_HOLD, MODE_GETAWAY] else CARGO_CARRIED
	if bool(source.get("confiscated", false)):
		cargo_status = CARGO_CONFISCATED
	elif str(source.get("status", "active")) == "resolved":
		var resolution := _copy_dict(source.get("resolution", {}))
		if str(resolution.get("outcome", "")) == "success":
			cargo_status = CARGO_DELIVERED
		elif str(resolution.get("reason", "")) == "swept":
			cargo_status = CARGO_CONFISCATED
		elif str(resolution.get("reason", "")) in ["ditched", "cargo_found"]:
			cargo_status = CARGO_DITCHED if str(resolution.get("reason", "")) == "ditched" else CARGO_FOUND
	var place_kind := "none" if cargo_status == CARGO_NONE else "legacy_v2"
	return {
		"schema_version": DEPTH_STATE_SCHEMA_VERSION,
		"origin": "legacy_v2",
		"cargo": _physical_cargo(cargo_status, node_id, place_kind, ""),
		"position": _physical_position(node_id, "", "legacy_restore"),
		"command_receipts": [],
		"command_sequence": 0,
		"hold_signals": [],
		"hold_aftermath": {},
		"pursuit_aftermath": {},
	}


static func _normalize_depth_state(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = value
	var keys := source.keys()
	keys.sort()
	var exact := ["cargo", "command_receipts", "command_sequence", "hold_aftermath", "hold_signals", "origin", "position", "pursuit_aftermath", "schema_version"]
	exact.sort()
	if keys != exact or typeof(source.get("schema_version")) != TYPE_INT or int(source.get("schema_version", 0)) != DEPTH_STATE_SCHEMA_VERSION:
		return {}
	if str(source.get("origin", "")) not in ["current", "legacy_v2"]:
		return {}
	var cargo := _normalize_physical_cargo(source.get("cargo", {}))
	var position := _normalize_physical_position(source.get("position", {}))
	var receipts := _normalize_depth_receipts(source.get("command_receipts", []))
	if cargo.is_empty() or position.is_empty() or receipts.size() != _copy_array(source.get("command_receipts", [])).size() \
			or receipts.size() > MAX_DEPTH_COMMAND_RECEIPTS or int(source.get("command_sequence", -1)) != receipts.size():
		return {}
	if typeof(source.get("hold_signals")) != TYPE_ARRAY or (source.get("hold_signals", []) as Array).size() > MAX_DEPTH_COMMAND_RECEIPTS \
			or typeof(source.get("hold_aftermath")) != TYPE_DICTIONARY or typeof(source.get("pursuit_aftermath")) != TYPE_DICTIONARY:
		return {}
	return {
		"schema_version": DEPTH_STATE_SCHEMA_VERSION,
		"origin": str(source.get("origin", "")),
		"cargo": cargo,
		"position": position,
		"command_receipts": receipts,
		"command_sequence": receipts.size(),
		"hold_signals": _copy_array(source.get("hold_signals", [])),
		"hold_aftermath": _copy_dict(source.get("hold_aftermath", {})),
		"pursuit_aftermath": _copy_dict(source.get("pursuit_aftermath", {})),
	}


static func _physical_cargo(status: String, node_id: String, place_kind: String, place_id: String) -> Dictionary:
	return {
		"schema_version": DEPTH_STATE_SCHEMA_VERSION,
		"status": status,
		"node_id": node_id.strip_edges(),
		"place_kind": place_kind.strip_edges(),
		"place_id": place_id.strip_edges(),
	}


static func _normalize_physical_cargo(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var cargo: Dictionary = value
	var keys := cargo.keys()
	keys.sort()
	if keys != ["node_id", "place_id", "place_kind", "schema_version", "status"] \
			or typeof(cargo.get("schema_version")) != TYPE_INT or int(cargo.get("schema_version", 0)) != DEPTH_STATE_SCHEMA_VERSION:
		return {}
	var status := str(cargo.get("status", ""))
	var node_id := str(cargo.get("node_id", ""))
	var place_kind := str(cargo.get("place_kind", ""))
	var place_id := str(cargo.get("place_id", ""))
	if status not in CARGO_STATES or node_id != node_id.strip_edges() or place_kind != place_kind.strip_edges() or place_id != place_id.strip_edges():
		return {}
	if status == CARGO_STASHED and (node_id.is_empty() or place_kind != "stash" or place_id.is_empty()):
		return {}
	if status == CARGO_PICKUP_PENDING and (node_id.is_empty() or place_kind != "pickup_contact" or place_id.is_empty()):
		return {}
	return _physical_cargo(status, node_id, place_kind, place_id)


static func _physical_position(node_id: String, previous_node_id: String, last_verb: String) -> Dictionary:
	return {
		"schema_version": DEPTH_STATE_SCHEMA_VERSION,
		"node_id": node_id.strip_edges(),
		"previous_node_id": previous_node_id.strip_edges(),
		"last_verb": last_verb.strip_edges(),
	}


static func _normalize_physical_position(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var position: Dictionary = value
	var keys := position.keys()
	keys.sort()
	if keys != ["last_verb", "node_id", "previous_node_id", "schema_version"] \
			or typeof(position.get("schema_version")) != TYPE_INT or int(position.get("schema_version", 0)) != DEPTH_STATE_SCHEMA_VERSION:
		return {}
	for key in ["node_id", "previous_node_id", "last_verb"]:
		if typeof(position.get(key)) != TYPE_STRING or str(position.get(key, "")) != str(position.get(key, "")).strip_edges():
			return {}
	return _physical_position(str(position.get("node_id", "")), str(position.get("previous_node_id", "")), str(position.get("last_verb", "")))


static func _normalize_depth_receipts(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var result: Array = []
	for index in range((value as Array).size()):
		var receipt_value: Variant = (value as Array)[index]
		if typeof(receipt_value) != TYPE_DICTIONARY:
			return []
		var receipt: Dictionary = receipt_value
		var keys := receipt.keys()
		keys.sort()
		if keys != ["command_id", "command_record_fingerprint", "receipt_key", "sequence"] \
				or typeof(receipt.get("sequence")) != TYPE_INT or int(receipt.get("sequence", 0)) != index + 1:
			return []
		for key in ["command_id", "command_record_fingerprint", "receipt_key"]:
			if typeof(receipt.get(key)) != TYPE_STRING or str(receipt.get(key, "")).is_empty() or str(receipt.get(key, "")) != str(receipt.get(key, "")).strip_edges():
				return []
		result.append(receipt.duplicate(true))
	return result


static func _available_physical_verbs(state: Dictionary) -> Array:
	if str(state.get("status", "")) != "active":
		return []
	var mode := str(state.get("mode", ""))
	var depth := _copy_dict(state.get("depth_state", {}))
	var cargo := _copy_dict(depth.get("cargo", {}))
	var position := _copy_dict(depth.get("position", {}))
	var cargo_status := str(cargo.get("status", CARGO_NONE))
	if cargo_status == CARGO_PICKUP_PENDING:
		return ["pickup"] if str(cargo.get("node_id", "")) == str(position.get("node_id", "")) else ["move"]
	if mode == MODE_HOLD:
		return ["wait", "signal", "break_hold"]
	if mode == MODE_GETAWAY:
		return ["move", "wait", "duck"]
	var result := ["move", "wait", "duck"]
	if cargo_status == CARGO_CARRIED:
		result.append_array(["stash", "ditch"])
		if not str(state.get("handoff_pending_node_id", "")).is_empty(): result.append("handoff")
	elif cargo_status == CARGO_STASHED:
		result.append_array(["retrieve", "ditch"])
	return result


static func _normalize_targets(value: Variant) -> Array:
	var result: Array = []
	var seen := {}
	if typeof(value) != TYPE_ARRAY:
		return result
	for target_value in value as Array:
		if typeof(target_value) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = target_value
		var node_id := str(source.get("node_id", source.get("id", ""))).strip_edges()
		if node_id.is_empty() or seen.has(node_id):
			continue
		seen[node_id] = true
		var status := str(source.get("status", "pending")).strip_edges().to_lower()
		if not ["pending", "delivered"].has(status):
			status = "pending"
		result.append({
			"id": str(source.get("id", "delivery_target_%s" % node_id)).strip_edges(),
			"node_id": node_id,
			"label": str(source.get("label", node_id.replace("_", " ").capitalize())).strip_edges(),
			"status": status,
			"was_visited_at_offer": bool(source.get("was_visited_at_offer", false)),
			"was_visible_at_offer": bool(source.get("was_visible_at_offer", false)),
			"revealed_by_job": bool(source.get("revealed_by_job", false)),
			"delivered_boundary": maxi(0, int(source.get("delivered_boundary", 0))),
		})
	return result


static func _copy_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _copy_dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value as Array:
		var entry := str(entry_value).strip_edges()
		if not entry.is_empty() and not result.has(entry):
			result.append(entry)
	return result


static func _canonical_public_result(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = value
	var allowed := ["ok", "resolved", "message", "outcome"]
	for key_value in source.keys():
		if not allowed.has(str(key_value)):
			return {}
	if typeof(source.get("ok")) != TYPE_BOOL or not bool(source.get("ok", false)) \
			or typeof(source.get("resolved")) != TYPE_BOOL or not bool(source.get("resolved", false)) \
			or typeof(source.get("message")) != TYPE_STRING:
		return {}
	var message := str(source.get("message", ""))
	if message != message.strip_edges():
		return {}
	var result := {"ok": true, "resolved": true, "message": message}
	if source.has("outcome"):
		if typeof(source.get("outcome")) != TYPE_STRING or str(source.get("outcome", "")) not in ["delivered", "expired", "abandoned"]:
			return {}
		result["outcome"] = str(source.get("outcome", ""))
	return result


static func _fingerprint(value: Variant) -> String:
	return JSON.stringify(_canonical_variant(value)).sha256_text()


static func _canonical_variant(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var source: Dictionary = value
		var result: Dictionary = {}
		var keys := source.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key_value in keys:
			result[str(key_value)] = _canonical_variant(source.get(key_value))
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for entry in value as Array:
			result.append(_canonical_variant(entry))
		return result
	return value
