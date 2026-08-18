class_name DeliveryRunModel
extends RefCounted

const SCHEMA_VERSION := 1
const MODE_PACKAGE := "package"
const MODE_MULTI_STOP := "multi_stop"
const MODE_HOLD := "hold"
const MODE_GETAWAY := "getaway"
const MODES := [MODE_PACKAGE, MODE_MULTI_STOP, MODE_HOLD, MODE_GETAWAY]


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
		"carrying_contraband": str(state.get("status", "")) == "active" and not bool(state.get("confiscated", false)),
		"handoff_pending_node_id": str(state.get("handoff_pending_node_id", "")),
		"hold_required_actions": int(state.get("hold_required_actions", 0)),
		"hold_progress": int(state.get("hold_progress", 0)),
		"pursuit_pressure": int(state.get("pursuit_pressure", 0)),
		"pursuit_limit": int(state.get("pursuit_limit", 0)),
		"assists_available": _copy_array(state.get("assists_available", [])),
		"assists_used": _copy_array(state.get("assists_used", [])),
		"resolution": _copy_dict(state.get("resolution", {})),
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
	state["arrival_count"] = int(state.get("arrival_count", 0)) + 1
	var target_index := _pending_target_index(state, node_id)
	if target_index < 0:
		return state
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
	targets[target_index] = target
	state["targets"] = targets
	state["handoff_pending_node_id"] = ""
	if _all_targets_delivered(state):
		return _resolve(state, "success", "delivered", true)
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
