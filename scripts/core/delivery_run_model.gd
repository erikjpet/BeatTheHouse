class_name DeliveryRunModel
extends RefCounted

const SCHEMA_VERSION := 1
const MODE_PACKAGE := "package"
const MODE_MULTI_STOP := "multi_stop"
const MODE_HOLD := "hold"
const MODE_GETAWAY := "getaway"
const MODES := [MODE_PACKAGE, MODE_MULTI_STOP, MODE_HOLD, MODE_GETAWAY]
const PHYSICAL_STATE_SCHEMA_VERSION := 1
const CARGO_CARRIED := "carried"
const CARGO_STASHED := "stashed"
const CARGO_DELIVERED := "delivered"
const CARGO_DITCHED := "ditched"
const CARGO_CONFISCATED := "confiscated"
const CARGO_FOUND := "found"
const CARGO_NONE := "none"
const CARGO_STATUSES := [CARGO_CARRIED, CARGO_STASHED, CARGO_DELIVERED, CARGO_DITCHED, CARGO_CONFISCATED, CARGO_FOUND, CARGO_NONE]
const ACTION_MOVE := "move"
const ACTION_HANDOFF := "handoff"
const ACTION_WAIT := "wait"
const ACTION_DUCK := "duck"
const ACTION_STASH := "stash"
const ACTION_RETRIEVE := "retrieve"
const ACTION_DITCH := "ditch"
const ACTION_SIGNAL := "signal"
const ACTION_BREAK_HOLD := "break_hold"
const STREET_ACTIONS := [ACTION_MOVE, ACTION_WAIT, ACTION_DUCK, ACTION_STASH, ACTION_RETRIEVE, ACTION_DITCH, ACTION_SIGNAL, ACTION_BREAK_HOLD]


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
		"cargo_state": _initial_cargo_state(mode, spec),
		"position_state": _initial_position_state(spec),
		"action_receipts": {},
		"target_receipts": {},
		"action_sequence": 0,
		"hold_signals": [],
		"hold_aftermath": {},
		"pursuit_aftermath": {},
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
		"world_applied": false,
	})


static func normalize_state(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).is_empty():
		return {}
	var source: Dictionary = value
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
	var cargo_state := _normalize_cargo_state(source.get("cargo_state", {}), mode, source)
	if cargo_state.is_empty():
		return {}
	var position_state := _normalize_position_state(source.get("position_state", {}), source)
	if position_state.is_empty():
		return {}
	return {
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
		"cargo_state": cargo_state,
		"position_state": position_state,
		"action_receipts": _normalize_action_receipts(source.get("action_receipts", {})),
		"target_receipts": _normalize_action_receipts(source.get("target_receipts", {})),
		"action_sequence": maxi(0, int(source.get("action_sequence", 0))),
		"hold_signals": _normalize_signal_records(source.get("hold_signals", [])),
		"hold_aftermath": _copy_dict(source.get("hold_aftermath", {})),
		"pursuit_aftermath": _copy_dict(source.get("pursuit_aftermath", {})),
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
		"cargo_state": _copy_dict(state.get("cargo_state", {})),
		"position_state": _copy_dict(state.get("position_state", {})),
		"carrying_contraband": str(_copy_dict(state.get("cargo_state", {})).get("status", "")) == CARGO_CARRIED,
		"handoff_pending_node_id": str(state.get("handoff_pending_node_id", "")),
		"hold_required_actions": int(state.get("hold_required_actions", 0)),
		"hold_progress": int(state.get("hold_progress", 0)),
		"pursuit_pressure": int(state.get("pursuit_pressure", 0)),
		"pursuit_limit": int(state.get("pursuit_limit", 0)),
		"assists_available": _copy_array(state.get("assists_available", [])),
		"assists_used": _copy_array(state.get("assists_used", [])),
		"hold_signals": _copy_array(state.get("hold_signals", [])),
		"hold_aftermath": _copy_dict(state.get("hold_aftermath", {})),
		"pursuit_aftermath": _copy_dict(state.get("pursuit_aftermath", {})),
		"resolution": _copy_dict(state.get("resolution", {})),
		"receipt": _copy_dict(state.get("receipt", {})),
	}


static func cargo(state_value: Variant) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty():
		return {}
	var physical := _copy_dict(state.get("cargo_state", {}))
	return {
		"instance_id": str(state.get("job_id", "")) if not str(state.get("job_id", "")).is_empty() else str(state.get("run_id", "")),
		"cargo_id": str(state.get("cargo_id", "")),
		"label": str(state.get("cargo_label", "")),
		"status": str(physical.get("status", CARGO_NONE)),
		"node_id": str(physical.get("node_id", "")),
	}


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
	var target_index := _pending_target_index(state, node_id)
	if target_index < 0:
		return state
	state["arrival_count"] = int(state.get("arrival_count", 0)) + 1
	state = _record_position(state, node_id, "arrival")
	if str(state.get("mode", "")) == MODE_GETAWAY:
		return _resolve(state, "success", "escaped", true)
	if str(state.get("mode", "")) == MODE_HOLD:
		return state
	state["handoff_pending_node_id"] = node_id.strip_edges()
	return state


static func complete_handoff(state_value: Variant, node_id: String) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty() or str(state.get("status", "")) != "active":
		return state
	var clean_node_id := node_id.strip_edges()
	if clean_node_id.is_empty() or clean_node_id != str(state.get("handoff_pending_node_id", "")):
		return state
	var targets: Array = state.get("targets", [])
	var target_index := _pending_target_index(state, clean_node_id)
	if target_index < 0:
		return state
	var target: Dictionary = targets[target_index]
	target["status"] = "delivered"
	target["delivered_boundary"] = int(state.get("boundaries_elapsed", 0))
	target["handoff_node_id"] = clean_node_id
	targets[target_index] = target
	state["targets"] = targets
	var target_receipts := _copy_dict(state.get("target_receipts", {}))
	var target_id := str(target.get("id", "delivery_target_%s" % clean_node_id))
	if not target_receipts.has(target_id):
		target_receipts[target_id] = {"fingerprint": JSON.stringify(target).sha256_text(), "sequence": int(state.get("action_sequence", 0)) + 1, "action": ACTION_HANDOFF}
	state["target_receipts"] = target_receipts
	state["handoff_pending_node_id"] = ""
	if _all_targets_delivered(state):
		state["cargo_state"] = _cargo_at(CARGO_DELIVERED, clean_node_id, "handoff", "")
		return _resolve(state, "success", "delivered", true)
	return state


# Physical cargo actions are model-owned and location-bound. The receipt key is
# required so input replay cannot stash, retrieve or ditch the same object twice.
static func stash(state_value: Variant, node_id: String, stash_id: String, receipt_key: String) -> Dictionary:
	var state := normalize_state(state_value)
	var clean_node := node_id.strip_edges()
	var clean_stash := stash_id.strip_edges()
	var envelope := {"action": ACTION_STASH, "node_id": clean_node, "stash_id": clean_stash}
	if _action_replayed(state, receipt_key, envelope):
		return state
	if not _action_can_apply(state, receipt_key, envelope) or clean_node.is_empty() or clean_stash.is_empty():
		return state
	var cargo := _copy_dict(state.get("cargo_state", {}))
	if str(cargo.get("status", "")) != CARGO_CARRIED or str(_copy_dict(state.get("position_state", {})).get("node_id", "")) != clean_node:
		return state
	state["cargo_state"] = _cargo_at(CARGO_STASHED, clean_node, "stash", clean_stash)
	return _record_action(state, receipt_key, envelope)


static func retrieve(state_value: Variant, node_id: String, stash_id: String, receipt_key: String) -> Dictionary:
	var state := normalize_state(state_value)
	var clean_node := node_id.strip_edges()
	var clean_stash := stash_id.strip_edges()
	var envelope := {"action": ACTION_RETRIEVE, "node_id": clean_node, "stash_id": clean_stash}
	if _action_replayed(state, receipt_key, envelope):
		return state
	if not _action_can_apply(state, receipt_key, envelope):
		return state
	var cargo := _copy_dict(state.get("cargo_state", {}))
	if str(cargo.get("status", "")) != CARGO_STASHED or str(cargo.get("node_id", "")) != clean_node or str(cargo.get("place_id", "")) != clean_stash:
		return state
	state["cargo_state"] = _cargo_at(CARGO_CARRIED, clean_node, "player", "player")
	return _record_action(state, receipt_key, envelope)


static func ditch(state_value: Variant, node_id: String, receipt_key: String, reason: String = "ditched", place_id: String = "") -> Dictionary:
	var state := normalize_state(state_value)
	var clean_node := node_id.strip_edges()
	var clean_reason := reason.strip_edges() if not reason.strip_edges().is_empty() else "ditched"
	var clean_place := place_id.strip_edges()
	var envelope := {"action": ACTION_DITCH, "node_id": clean_node, "reason": clean_reason, "place_id": clean_place}
	if _action_replayed(state, receipt_key, envelope):
		return state
	if not _action_can_apply(state, receipt_key, envelope):
		return state
	var cargo := _copy_dict(state.get("cargo_state", {}))
	if str(cargo.get("status", "")) not in [CARGO_CARRIED, CARGO_STASHED]:
		return state
	state["cargo_state"] = _cargo_at(CARGO_DITCHED, clean_node, "street", clean_place)
	state = _record_action(state, receipt_key, envelope)
	return _resolve(state, "failed", clean_reason, false)


# One hold choice advances one established action boundary. Signals are durable
# scene facts; breaking early is a distinct terminal aftermath.
static func apply_hold_action(state_value: Variant, action_id: String, node_id: String, attention: int, action_index: int, receipt_key: String, signal_id: String = "") -> Dictionary:
	var state := normalize_state(state_value)
	var clean_action := action_id.strip_edges()
	var clean_node := node_id.strip_edges()
	var clean_signal := signal_id.strip_edges()
	var envelope := {"action": clean_action, "node_id": clean_node, "attention": attention, "action_index": action_index, "signal_id": clean_signal}
	if _action_replayed(state, receipt_key, envelope):
		return state
	if str(state.get("mode", "")) != MODE_HOLD or not _action_can_apply(state, receipt_key, envelope):
		return state
	var hold_node := str(_copy_dict(_copy_array(state.get("targets", []))[0]).get("node_id", ""))
	if clean_node != hold_node:
		return state
	if clean_action == ACTION_BREAK_HOLD:
		state["hold_aftermath"] = {"outcome": "broken_early", "node_id": clean_node, "action_index": action_index}
		state = _record_action(state, receipt_key, envelope)
		return _resolve(state, "failed", "hold_broken", false)
	if clean_action not in [ACTION_WAIT, ACTION_SIGNAL] or (clean_action == ACTION_SIGNAL and clean_signal.is_empty()):
		return state
	if clean_action == ACTION_SIGNAL:
		var signals := _copy_array(state.get("hold_signals", []))
		signals.append({"signal_id": clean_signal, "node_id": clean_node, "action_index": action_index})
		state["hold_signals"] = signals
	state = _record_action(state, receipt_key, envelope)
	state = advance_boundaries(state, 1, clean_node, attention, action_index)
	if str(state.get("status", "")) == "resolved":
		var resolution := _copy_dict(state.get("resolution", {}))
		state["hold_aftermath"] = {"outcome": str(resolution.get("reason", "failed")), "node_id": clean_node, "action_index": action_index}
	return state


# Shared pursuit verbs use only the landed pressure increment and assist relief.
# Duck consumes a boundary and cancels that boundary's pressure increment; it
# never introduces a new relief or probability value.
static func apply_pursuit_action(state_value: Variant, action_id: String, node_id: String, attention: int, action_index: int, receipt_key: String, context: Dictionary = {}) -> Dictionary:
	var state := normalize_state(state_value)
	var clean_action := action_id.strip_edges()
	var clean_node := node_id.strip_edges()
	var envelope := {"action": clean_action, "node_id": clean_node, "attention": attention, "action_index": action_index, "context": context.duplicate(true)}
	if _action_replayed(state, receipt_key, envelope):
		return state
	if str(state.get("mode", "")) != MODE_GETAWAY or clean_action not in [ACTION_MOVE, ACTION_WAIT, ACTION_DUCK] or not _action_can_apply(state, receipt_key, envelope):
		return state
	if clean_action == ACTION_DUCK:
		var cover_id := str(context.get("cover_id", "")).strip_edges()
		if cover_id.is_empty():
			return state
		state["pursuit_pressure"] = maxi(0, int(state.get("pursuit_pressure", 0)) - int(state.get("pursuit_per_boundary", 0)))
	state = _record_position(state, clean_node, clean_action)
	state = _record_action(state, receipt_key, envelope)
	state = advance_boundaries(state, 1, clean_node, attention, action_index)
	if clean_action == ACTION_MOVE and str(state.get("status", "")) == "active":
		state = note_arrival(state, clean_node)
	if str(state.get("status", "")) == "resolved":
		var resolution := _copy_dict(state.get("resolution", {}))
		state["pursuit_aftermath"] = {"outcome": str(resolution.get("reason", "failed")), "node_id": clean_node, "action_index": action_index}
	return state


# Generic public verb seam. It is a dispatcher over the same immutable model
# methods, not a second state or consequence authority.
static func apply_action(state_value: Variant, verb: String, context: Dictionary) -> Dictionary:
	var receipt_key := str(context.get("receipt_key", "")).strip_edges()
	if typeof(state_value) == TYPE_DICTIONARY and not receipt_key.is_empty() \
			and _copy_dict(_copy_dict(state_value).get("action_receipts", {})).has(receipt_key):
		return _copy_dict(state_value)
	var state := normalize_state(state_value)
	var action := verb.strip_edges()
	var node_id := str(context.get("node_id", "")).strip_edges()
	var action_index := maxi(0, int(context.get("action_index", int(state.get("last_boundary_action", 0)) + 1)))
	var attention := clampi(int(context.get("attention", 0)), 0, 100)
	match action:
		"pickup":
			var pickup_envelope := {"action": action, "node_id": node_id, "action_index": action_index}
			if _action_replayed(state, receipt_key, pickup_envelope): return state
			if not _action_can_apply(state, receipt_key, pickup_envelope): return state
			var physical := _copy_dict(state.get("cargo_state", {}))
			if str(physical.get("status", "")) not in [CARGO_STASHED, CARGO_CARRIED] or (not str(physical.get("node_id", "")).is_empty() and str(physical.get("node_id", "")) != node_id): return state
			state["cargo_state"] = _cargo_at(CARGO_CARRIED, node_id, "player", "player")
			return _record_action(state, receipt_key, pickup_envelope)
		"handoff":
			var handoff_envelope := {"action": action, "node_id": node_id, "action_index": action_index}
			if _action_replayed(state, receipt_key, handoff_envelope): return state
			if not _action_can_apply(state, receipt_key, handoff_envelope): return state
			var next_target_index := _next_pending_target_index(state)
			if next_target_index < 0: return state
			var next_target := _copy_dict(_copy_array(state.get("targets", []))[next_target_index])
			if str(next_target.get("node_id", "")) != node_id: return state
			var requested_target_id := str(context.get("target_id", "")).strip_edges()
			if not requested_target_id.is_empty() and requested_target_id != str(next_target.get("id", "")): return state
			var arrived := note_arrival(state, node_id)
			var handed := complete_handoff(arrived, node_id)
			if JSON.stringify(handed) == JSON.stringify(state): return state
			return _record_action(handed, receipt_key, handoff_envelope)
		ACTION_MOVE, ACTION_WAIT, ACTION_DUCK:
			return apply_pursuit_action(state, action, node_id, attention, action_index, receipt_key, _copy_dict(context.get("context", context))) if str(state.get("mode", "")) == MODE_GETAWAY else _apply_ordinary_street_boundary(state, action, node_id, attention, action_index, receipt_key, context)
		ACTION_STASH:
			return stash(state, node_id, str(context.get("stash_id", context.get("place_id", ""))), receipt_key)
		ACTION_RETRIEVE:
			return retrieve(state, node_id, str(context.get("stash_id", context.get("place_id", ""))), receipt_key)
		"found":
			return _apply_cargo_found(state, node_id, receipt_key, str(context.get("finder_id", "unknown")))
		ACTION_DITCH:
			return ditch(state, node_id, receipt_key, str(context.get("reason", "ditched")), str(context.get("place_id", "")))
		"hold_signal":
			return apply_hold_action(state, ACTION_SIGNAL, node_id, attention, action_index, receipt_key, str(context.get("signal_id", "signal")))
		"hold_break":
			return apply_hold_action(state, ACTION_BREAK_HOLD, node_id, attention, action_index, receipt_key)
		"interruption":
			return _apply_interruption(state, node_id, receipt_key, str(context.get("reason", "interrupted")))
		"abandon":
			var abandon_envelope := {"action": action, "node_id": node_id, "reason": str(context.get("reason", "abandoned"))}
			if _action_replayed(state, receipt_key, abandon_envelope): return state
			if not _action_can_apply(state, receipt_key, abandon_envelope): return state
			return abandon(_record_action(state, receipt_key, abandon_envelope), str(context.get("reason", "abandoned")))
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
	var node_id := str(_copy_dict(state.get("position_state", {})).get("node_id", ""))
	state["cargo_state"] = _cargo_at(CARGO_CONFISCATED, node_id, "police", "")
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
		if str(target.get("status", "pending")) != "pending":
			continue
		return index if str(target.get("node_id", "")) == clean_node_id else -1
	return -1


static func _next_pending_target_index(state: Dictionary) -> int:
	var targets := _copy_array(state.get("targets", []))
	for index in range(targets.size()):
		if str(_copy_dict(targets[index]).get("status", "pending")) == "pending":
			return index
	return -1


static func _all_targets_delivered(state: Dictionary) -> bool:
	for target_value in state.get("targets", []):
		if typeof(target_value) != TYPE_DICTIONARY or str((target_value as Dictionary).get("status", "pending")) != "delivered":
			return false
	return true


static func _initial_cargo_state(mode: String, spec: Dictionary) -> Dictionary:
	if mode == MODE_HOLD:
		return _cargo_at(CARGO_NONE, "", "none", "")
	return _cargo_at(CARGO_CARRIED, str(spec.get("pickup_node_id", spec.get("start_node_id", ""))).strip_edges(), "player", "player")


static func _normalize_cargo_state(value: Variant, mode: String, source: Dictionary) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).is_empty():
		# Explicit schema-1 migration: landed saves had only cargo_id plus the
		# confiscated/resolved flags, so those facts close the physical location.
		if mode not in [MODE_PACKAGE, MODE_MULTI_STOP]:
			return _cargo_at(CARGO_NONE, "", "none", "")
		if bool(source.get("confiscated", false)):
			return _cargo_at(CARGO_CONFISCATED, "", "police", "")
		if str(source.get("status", "active")) == "resolved":
			var legacy_resolution := _copy_dict(source.get("resolution", {}))
			var reason := str(legacy_resolution.get("reason", ""))
			if str(legacy_resolution.get("outcome", "")) == "success":
				return _cargo_at(CARGO_DELIVERED, "", "legacy_resolution", "")
			if reason == "swept":
				return _cargo_at(CARGO_CONFISCATED, "", "police", "")
			if reason == "cargo_found":
				return _cargo_at(CARGO_FOUND, "", "finder", "")
			if reason in ["ditched", "abandoned"]:
				return _cargo_at(CARGO_DITCHED, "", "legacy_resolution", "")
			return _cargo_at(CARGO_CARRIED, "", "player", "player")
		return _cargo_at(CARGO_CARRIED, "", "player", "player")
	var source_cargo: Dictionary = value
	if int(source_cargo.get("schema_version", 0)) != PHYSICAL_STATE_SCHEMA_VERSION:
		return {}
	var status := str(source_cargo.get("status", "")).strip_edges()
	var node_id := str(source_cargo.get("node_id", "")).strip_edges()
	var place_kind := str(source_cargo.get("place_kind", "")).strip_edges()
	var place_id := str(source_cargo.get("place_id", "")).strip_edges()
	if status not in CARGO_STATUSES or place_kind.is_empty():
		return {}
	if status == CARGO_STASHED and (node_id.is_empty() or place_id.is_empty()):
		return {}
	return _cargo_at(status, node_id, place_kind, place_id)


static func _cargo_at(status: String, node_id: String, place_kind: String, place_id: String) -> Dictionary:
	return {"schema_version": PHYSICAL_STATE_SCHEMA_VERSION, "status": status, "node_id": node_id.strip_edges(), "place_kind": place_kind.strip_edges(), "place_id": place_id.strip_edges()}


static func _initial_position_state(spec: Dictionary) -> Dictionary:
	return {"schema_version": PHYSICAL_STATE_SCHEMA_VERSION, "node_id": str(spec.get("start_node_id", spec.get("pickup_node_id", spec.get("current_node_id", "")))).strip_edges(), "previous_node_id": "", "last_action": "start"}


static func _normalize_position_state(value: Variant, source: Dictionary) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).is_empty():
		return _initial_position_state(source)
	var position: Dictionary = value
	if int(position.get("schema_version", 0)) != PHYSICAL_STATE_SCHEMA_VERSION:
		return {}
	return {"schema_version": PHYSICAL_STATE_SCHEMA_VERSION, "node_id": str(position.get("node_id", "")).strip_edges(), "previous_node_id": str(position.get("previous_node_id", "")).strip_edges(), "last_action": str(position.get("last_action", "")).strip_edges()}


static func _record_position(state_value: Dictionary, node_id: String, action_id: String) -> Dictionary:
	var state := state_value.duplicate(true)
	var position := _copy_dict(state.get("position_state", {}))
	var clean_node := node_id.strip_edges()
	if not clean_node.is_empty() and clean_node != str(position.get("node_id", "")):
		position["previous_node_id"] = str(position.get("node_id", ""))
		position["node_id"] = clean_node
	position["last_action"] = action_id.strip_edges()
	state["position_state"] = position
	var cargo := _copy_dict(state.get("cargo_state", {}))
	if str(cargo.get("status", "")) == CARGO_CARRIED:
		cargo["node_id"] = clean_node
		state["cargo_state"] = cargo
	return state


static func _apply_ordinary_street_boundary(state_value: Dictionary, action_id: String, node_id: String, attention: int, action_index: int, receipt_key: String, context: Dictionary) -> Dictionary:
	var state := normalize_state(state_value)
	var envelope := {"action": action_id, "node_id": node_id, "attention": attention, "action_index": action_index, "context": context.duplicate(true)}
	if _action_replayed(state, receipt_key, envelope):
		return state
	if not _action_can_apply(state, receipt_key, envelope) or action_id not in [ACTION_MOVE, ACTION_WAIT, ACTION_DUCK]:
		return state
	if str(state.get("mode", "")) == MODE_HOLD:
		return apply_hold_action(state, ACTION_WAIT, node_id, attention, action_index, receipt_key)
	state = _record_position(state, node_id, action_id)
	state = _record_action(state, receipt_key, envelope)
	state = advance_boundaries(state, 1, node_id, attention, action_index)
	if action_id == ACTION_MOVE and str(state.get("status", "")) == "active":
		state = note_arrival(state, node_id)
	return state


static func _apply_cargo_found(state_value: Dictionary, node_id: String, receipt_key: String, finder_id: String) -> Dictionary:
	var state := normalize_state(state_value)
	var envelope := {"action": "found", "node_id": node_id.strip_edges(), "finder_id": finder_id.strip_edges()}
	if _action_replayed(state, receipt_key, envelope):
		return state
	if not _action_can_apply(state, receipt_key, envelope):
		return state
	var cargo_state := _copy_dict(state.get("cargo_state", {}))
	if str(cargo_state.get("status", "")) != CARGO_STASHED or str(cargo_state.get("node_id", "")) != node_id.strip_edges():
		return state
	state["cargo_state"] = _cargo_at(CARGO_FOUND, node_id, "finder", finder_id)
	state = _record_action(state, receipt_key, envelope)
	return _resolve(state, "failed", "cargo_found", false)


static func _apply_interruption(state_value: Dictionary, node_id: String, receipt_key: String, reason: String) -> Dictionary:
	var state := normalize_state(state_value)
	var clean_reason := reason.strip_edges() if not reason.strip_edges().is_empty() else "interrupted"
	var envelope := {"action": "interruption", "node_id": node_id.strip_edges(), "reason": clean_reason}
	if _action_replayed(state, receipt_key, envelope):
		return state
	if not _action_can_apply(state, receipt_key, envelope):
		return state
	state = _record_action(state, receipt_key, envelope)
	if str(state.get("mode", "")) == MODE_HOLD:
		state["hold_aftermath"] = {"outcome": clean_reason, "node_id": node_id.strip_edges()}
	elif str(state.get("mode", "")) == MODE_GETAWAY:
		state["pursuit_aftermath"] = {"outcome": clean_reason, "node_id": node_id.strip_edges()}
	return _resolve(state, "failed", clean_reason, false)


static func _action_can_apply(state: Dictionary, receipt_key: String, envelope: Dictionary) -> bool:
	if state.is_empty() or str(state.get("status", "")) != "active" or receipt_key.strip_edges().is_empty():
		return false
	var existing := _copy_dict(_copy_dict(state.get("action_receipts", {})).get(receipt_key.strip_edges(), {}))
	return existing.is_empty()


static func _action_replayed(state: Dictionary, receipt_key: String, envelope: Dictionary) -> bool:
	if receipt_key.strip_edges().is_empty():
		return false
	var existing := _copy_dict(_copy_dict(state.get("action_receipts", {})).get(receipt_key.strip_edges(), {}))
	return not existing.is_empty() and str(existing.get("fingerprint", "")) == JSON.stringify(envelope).sha256_text()


static func _record_action(state_value: Dictionary, receipt_key: String, envelope: Dictionary) -> Dictionary:
	var state := state_value.duplicate(true)
	var receipts := _copy_dict(state.get("action_receipts", {}))
	var clean_key := receipt_key.strip_edges()
	if receipts.has(clean_key):
		return state
	var sequence := int(state.get("action_sequence", 0)) + 1
	receipts[clean_key] = {"fingerprint": JSON.stringify(envelope).sha256_text(), "sequence": sequence, "action": str(envelope.get("action", ""))}
	state["action_receipts"] = receipts
	state["action_sequence"] = sequence
	return state


static func _normalize_action_receipts(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key_value in (value as Dictionary).keys():
		var key := str(key_value).strip_edges()
		var receipt := _copy_dict((value as Dictionary).get(key_value, {}))
		var fingerprint := str(receipt.get("fingerprint", "")).strip_edges()
		if key.is_empty() or fingerprint.length() != 64:
			continue
		result[key] = {"fingerprint": fingerprint, "sequence": maxi(1, int(receipt.get("sequence", 1))), "action": str(receipt.get("action", "")).strip_edges()}
	return result


static func _normalize_signal_records(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value as Array:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var signal_id := str(entry.get("signal_id", "")).strip_edges()
		if signal_id.is_empty():
			continue
		result.append({"signal_id": signal_id, "node_id": str(entry.get("node_id", "")).strip_edges(), "action_index": maxi(0, int(entry.get("action_index", 0)))})
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
