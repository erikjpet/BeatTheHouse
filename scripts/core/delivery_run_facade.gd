class_name DeliveryRunFacade
extends RefCounted

const DeliveryRunModelScript := preload("res://scripts/core/delivery_run_model.gd")
const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")

var active_run: Dictionary = {}
var _run_ref: WeakRef
var _run:
	get: return _run_ref.get_ref() if _run_ref != null else null
	set(value): _run_ref = weakref(value) if value != null else null

var active_delivery_run: Dictionary:
	get: return active_run
	set(value): active_run = value


func bind(run_state: Object) -> DeliveryRunFacade:
	_run = run_state
	return self


func is_active() -> bool:
	return not active_run.is_empty() and str(active_run.get("status", "")) == "active"


func snapshot() -> Dictionary:
	return DeliveryRunModelScript.snapshot(active_run)


func _delivery_checkpoint_outcome() -> String:
	var resolution := JsonCoerceScript._copy_dict(active_delivery_run.get("resolution", {}))
	if str(resolution.get("outcome", "")) == "success": return "delivered"
	return "abandoned" if str(resolution.get("reason", "")) == "abandoned" else "expired"


func _delivery_event_consumer_payload(consequences: Dictionary) -> Dictionary:
	var succeeded := JsonCoerceScript._copy_dict(consequences.get("success", {}))
	var failed := JsonCoerceScript._copy_dict(consequences.get("failure", {}))
	return {
		"success": {
			"cash": maxi(0, int(succeeded.get("bankroll_delta", 0))),
			"clean_speed_bonus_cash": maxi(0, int(succeeded.get("clean_speed_bonus_cash", 0))),
			"heat": maxi(0, int(succeeded.get("suspicion_delta", 0))),
			"flags": JsonCoerceScript._copy_dict(succeeded.get("flags", {})),
		},
		"failure": {
			"heat": maxi(0, int(failed.get("suspicion_delta", 0))),
			"flags": JsonCoerceScript._copy_dict(failed.get("flags", {})),
		},
	}


func delivery_begin_package(spec: Dictionary) -> Dictionary:
	var normalized := spec.duplicate(true)
	normalized["mode"] = DeliveryRunModelScript.MODE_PACKAGE
	normalized["target_count"] = 1
	return _delivery_begin(normalized)


func delivery_begin_multi_stop(spec: Dictionary) -> Dictionary:
	var normalized := spec.duplicate(true)
	normalized["mode"] = DeliveryRunModelScript.MODE_MULTI_STOP
	return _delivery_begin(normalized)


func delivery_begin_hold(spec: Dictionary) -> Dictionary:
	var normalized := spec.duplicate(true)
	normalized["mode"] = DeliveryRunModelScript.MODE_HOLD
	normalized["target_count"] = 1
	return _delivery_begin(normalized)


func delivery_begin_getaway(spec: Dictionary) -> Dictionary:
	if not bool(spec.get("enabled", false)) and not bool(_run.narrative_flags.get("delivery_getaway_enabled", false)):
		return {"ok": false, "message": "The getaway route is not live."}
	var normalized := spec.duplicate(true)
	normalized["mode"] = DeliveryRunModelScript.MODE_GETAWAY
	normalized["target_count"] = 1
	return _delivery_begin(normalized)


func _delivery_begin(spec: Dictionary) -> Dictionary:
	if delivery_has_active_run():
		return {"ok": false, "message": "Finish the route already under your coat."}
	if not _run.has_world_map():
		return {"ok": false, "message": "There is no real town route for that job."}
	var resolved_targets := _delivery_resolve_targets(spec)
	if not bool(resolved_targets.get("ok", false)):
		return {"ok": false, "message": str(resolved_targets.get("message", "That route cannot be offered tonight."))}
	var normalized := spec.duplicate(true)
	normalized["targets"] = JsonCoerceScript._copy_array(resolved_targets.get("targets", []))
	normalized["start_node_id"] = _run.current_world_node_id()
	normalized["current_node_id"] = _run.current_world_node_id()
	if str(normalized.get("deadline_kind", DeliveryRunModelScript.DEADLINE_ACTIONS)) == DeliveryRunModelScript.DEADLINE_CLOCK:
		var deadline_minutes := maxi(1, int(normalized.get("deadline_minutes", 180)))
		normalized["deadline_minutes"] = deadline_minutes
		normalized["started_game_clock_minutes"] = _run.game_clock_minutes
		normalized["deadline_game_clock_minutes"] = _run.game_clock_minutes + deadline_minutes
	var state := DeliveryRunModelScript.begin(normalized, _run._crew_action_index())
	if state.is_empty():
		return {"ok": false, "message": "That route cannot be carried on this town map."}
	_run.world_map = JsonCoerceScript._copy_dict(resolved_targets.get("world_map", _run.world_map))
	active_delivery_run = state
	if str(JsonCoerceScript._copy_dict(delivery_snapshot().get("physical", {})).get("cargo_state", "")) == DeliveryRunModelScript.CARGO_CARRIED:
		_delivery_add_inventory_cargo()
	var target := JsonCoerceScript._copy_dict(JsonCoerceScript._copy_array(delivery_snapshot().get("targets", []))[0])
	var message := "The route is marked. Find %s at %s." % [str(target.get("contact_label", "the marked contact")), str(target.get("label", "the destination"))]
	if str(active_delivery_run.get("deadline_kind", DeliveryRunModelScript.DEADLINE_ACTIONS)) == DeliveryRunModelScript.DEADLINE_CLOCK:
		message += " Make the handoff by %s." % _run._clock_display_for_absolute_minutes(int(active_delivery_run.get("deadline_game_clock_minutes", 0)))
	return {"ok": true, "snapshot": delivery_snapshot(), "message": message}


func delivery_has_active_run() -> bool:
	return is_active()


func delivery_snapshot() -> Dictionary:
	return snapshot()


func delivery_physical_interactions() -> Array:
	if not delivery_has_active_run():
		return []
	var physical := JsonCoerceScript._copy_dict(delivery_snapshot().get("physical", {}))
	var node_id = _run.current_world_node_id()
	if node_id.is_empty() or node_id != str(physical.get("position_node_id", "")):
		return []
	var result: Array = []
	for verb_value in JsonCoerceScript._copy_array(physical.get("available_verbs", [])):
		var verb := str(verb_value)
		# Only a package physically present in the room is a room object. Route
		# choices live in the top action strip; handoff lives on the target person.
		if verb not in ["pickup", "retrieve"]:
			continue
		var label := str({
			"pickup": "Take the package", "wait": "Hold your sightline", "duck": "Duck into cover",
			"stash": "Stash the package", "retrieve": "Retrieve the package", "ditch": "Ditch the package",
			"signal": "Send the signal", "break_hold": "Break the hold",
		}.get(verb, verb.replace("_", " ").capitalize()))
		if verb == "retrieve":
			label = "The Package"
		result.append({
			"object_id": "delivery:%s:%s" % [verb, node_id],
			"node_id": node_id,
			"verb": verb,
			"label": label,
			"cargo_label": str(active_delivery_run.get("cargo_label", "Crew package")),
			"message": "This acts on the route here, at %s." % node_id.replace("_", " ").capitalize(),
		})
	return result


func delivery_top_actions() -> Array:
	if not delivery_has_active_run():
		return []
	var physical := JsonCoerceScript._copy_dict(delivery_snapshot().get("physical", {}))
	if _run.current_world_node_id() != str(physical.get("position_node_id", "")):
		return []
	var target_room_blocked := _delivery_target_room_blocked()
	var labels := {
		"wait": "Hold Sightline", "duck": "Duck Cover", "stash": "Stash Package",
		"ditch": "Ditch Package", "signal": "Send Signal", "break_hold": "Break Hold",
	}
	var result: Array = []
	for verb_value in JsonCoerceScript._copy_array(physical.get("available_verbs", [])):
		var verb := str(verb_value)
		if not labels.has(verb):
			continue
		if target_room_blocked and verb in ["wait", "signal"]:
			continue
		result.append({"id": verb, "label": str(labels.get(verb)), "message": _delivery_physical_action_message(verb)})
	return result


func delivery_apply_physical_action(verb: String, idempotency_key: String) -> Dictionary:
	if not delivery_has_active_run():
		return {"ok": false, "message": "No delivery sequence is active."}
	var action := verb.strip_edges()
	var receipt_key := idempotency_key.strip_edges()
	if action not in DeliveryRunModelScript.STREET_VERBS or action in ["move", "handoff"] or receipt_key.is_empty() or receipt_key != idempotency_key:
		return {"ok": false, "message": "That street action is not available."}
	var snapshot := delivery_snapshot()
	var physical := JsonCoerceScript._copy_dict(snapshot.get("physical", {}))
	if not JsonCoerceScript._copy_array(physical.get("available_verbs", [])).has(action):
		return {"ok": false, "message": "That street action is not available now."}
	if action in ["wait", "signal"] and _delivery_target_room_blocked():
		return {"ok": false, "message": _delivery_required_room_message()}
	var node_id = _run.current_world_node_id()
	if node_id.is_empty() or node_id != str(physical.get("position_node_id", "")):
		return {"ok": false, "message": "That street action is not at your present position."}
	var target_id := ""
	var place_id := ""
	var cover_id := ""
	var signal_id := ""
	match action:
		"pickup": target_id = str(physical.get("cargo_place_id", ""))
		"stash": place_id = "%s::delivery_stash" % node_id
		"retrieve": place_id = str(physical.get("cargo_place_id", ""))
		"ditch": place_id = str(physical.get("cargo_place_id", "")) if str(physical.get("cargo_state", "")) == DeliveryRunModelScript.CARGO_STASHED else "%s::delivery_ditch" % node_id
		"duck": cover_id = "%s::delivery_cover" % node_id
		"signal": signal_id = "%s::delivery_signal" % node_id
	var host_context := _delivery_host_context(node_id, "", target_id, place_id, cover_id, signal_id, action)
	var before := JSON.stringify(active_delivery_run)
	var rollback_run = _run.to_dict()
	var candidate := DeliveryRunModelScript.apply_host_action(
		active_delivery_run,
		action,
		receipt_key,
		host_context,
		str(_run.current_environment.get("archetype_id", "")).strip_edges()
	)
	if JSON.stringify(candidate) == before:
		return {"ok": false, "message": "The route no longer accepts that action."}
	active_delivery_run = candidate
	var cargo_after := str(JsonCoerceScript._copy_dict(delivery_snapshot().get("physical", {})).get("cargo_state", ""))
	if action == "retrieve" and cargo_after == DeliveryRunModelScript.CARGO_CARRIED:
		_delivery_add_inventory_cargo()
	elif action in ["stash", "ditch"]:
		_delivery_remove_inventory_cargo()
	var applied = _run._apply_delivery_resolution()
	if not bool(applied.get("ok", false)):
		_run.from_dict(rollback_run)
		return {"ok": false, "message": "The street consequence could not be committed.", "errors": JsonCoerceScript._copy_array(applied.get("errors", []))}
	return {"ok": true, "resolved": not delivery_has_active_run(), "snapshot": delivery_snapshot(), "message": str(_delivery_physical_action_message(action))}


func _delivery_host_context(node_id: String, destination_node_id: String, target_id: String, place_id: String, cover_id: String, signal_id: String, reason: String) -> Dictionary:
	return {
		"schema_version": 1,
		"node_id": node_id.strip_edges(),
		"destination_node_id": destination_node_id.strip_edges(),
		"target_id": target_id.strip_edges(),
		"place_id": place_id.strip_edges(),
		"cover_id": cover_id.strip_edges(),
		"signal_id": signal_id.strip_edges(),
		"reason": reason.strip_edges(),
		"attention": clampi(_run.suspicion_level(), 0, 100),
		"action_index": maxi(0, _run._crew_action_index()),
	}


func _delivery_physical_action_message(verb: String) -> String:
	return str({
		"pickup": "The package has weight now.", "wait": "You hold the sightline.", "duck": "The street loses you for a beat.",
		"stash": "The package stays here until you return.", "retrieve": "The package is back under your coat.",
		"ditch": "The package is gone.", "signal": "The signal crosses the street.", "break_hold": "You leave the sightline early.",
	}.get(verb, "The route changes here."))


func delivery_arrival_interaction() -> Dictionary:
	if not delivery_has_active_run():
		return {}
	if not bool(delivery_snapshot().get("carrying_contraband", false)):
		return {}
	var node_id = _run.current_world_node_id()
	if node_id.is_empty() or node_id != str(active_delivery_run.get("handoff_pending_node_id", "")):
		return {}
	if _delivery_target_room_blocked():
		return {}
	return {
		"object_id": "delivery:handoff:%s" % node_id,
		"node_id": node_id,
		"label": "Make the handoff",
		"cargo_label": str(active_delivery_run.get("cargo_label", "Crew package")),
		"message": "A quiet hand waits inside the room. Pass it over.",
	}


func delivery_complete_handoff(node_id: String = "") -> Dictionary:
	if not delivery_has_active_run():
		return {"ok": false, "message": "There is no package to hand over."}
	var target_id := node_id.strip_edges()
	var host_node_id = _run.current_world_node_id()
	if target_id.is_empty(): target_id = host_node_id
	if host_node_id.is_empty() or target_id != host_node_id:
		return {"ok": false, "message": "This is not the marked handoff."}
	var target := _delivery_pending_target_at(target_id)
	if target.is_empty():
		return {"ok": false, "message": "This is not the marked handoff."}
	if _delivery_target_room_blocked():
		return {"ok": false, "message": _delivery_required_room_message()}
	var before := JSON.stringify(delivery_snapshot())
	var rollback_run = _run.to_dict()
	var receipt_key := "handoff:%s:%s:%d" % [str(active_delivery_run.get("run_id", "delivery")), str(target.get("id", "target")), maxi(0, _run._crew_action_index())]
	active_delivery_run = DeliveryRunModelScript.apply_host_action(
		active_delivery_run,
		"handoff",
		receipt_key,
		_delivery_host_context(target_id, "", str(target.get("id", "")), "", "", "", "handoff"),
		str(_run.current_environment.get("archetype_id", "")).strip_edges()
	)
	if JSON.stringify(delivery_snapshot()) == before:
		return {"ok": false, "message": "This is not the marked handoff."}
	_delivery_remove_inventory_cargo()
	var applied = _run._apply_delivery_resolution()
	if not bool(applied.get("ok", false)):
		_run.from_dict(rollback_run)
		var apply_errors := JsonCoerceScript._copy_array(applied.get("errors", []))
		return {"ok": false, "message": str(apply_errors[0]) if not apply_errors.is_empty() else "The delivery consequence could not be committed.", "errors": apply_errors}
	var receipt := JsonCoerceScript._copy_dict(active_delivery_run.get("receipt", {}))
	var handoff_message := str(receipt.get("payment_note", "The package changes hands. Nothing else does."))
	return {"ok": true, "resolved": not delivery_has_active_run(), "snapshot": delivery_snapshot(), "message": handoff_message}


func _delivery_pending_target_at(node_id: String) -> Dictionary:
	for target_value in JsonCoerceScript._copy_array(delivery_snapshot().get("targets", [])):
		var target := JsonCoerceScript._copy_dict(target_value)
		if str(target.get("status", "pending")) == "pending" and str(target.get("node_id", "")) == node_id:
			return target
	return {}


func delivery_use_getaway_assist(assist_id: String) -> Dictionary:
	if not delivery_has_active_run():
		return {"ok": false, "message": "No getaway is active."}
	var before := JSON.stringify(delivery_snapshot())
	active_delivery_run = DeliveryRunModelScript.use_assist(active_delivery_run, assist_id)
	if JSON.stringify(delivery_snapshot()) == before:
		return {"ok": false, "message": "That assist is not available."}
	return {"ok": true, "snapshot": delivery_snapshot(), "message": "One favor burns. The pressure drops."}


func delivery_abandon(_reason: String = "abandoned") -> Dictionary:
	if not delivery_has_active_run():
		return {"ok": false, "message": "No delivery is active."}
	var rollback_run = _run.to_dict()
	var receipt_key := "abandon:%s:%d" % [str(active_delivery_run.get("run_id", "delivery")), maxi(0, _run._crew_action_index())]
	var before := JSON.stringify(active_delivery_run)
	active_delivery_run = DeliveryRunModelScript.apply_host_action(
		active_delivery_run,
		"abandon",
		receipt_key,
		_delivery_host_context(_run.current_world_node_id(), "", "", "", "", "", "abandoned")
	)
	if JSON.stringify(active_delivery_run) == before:
		return {"ok": false, "message": "The route could not be closed safely."}
	var applied = _run._apply_delivery_resolution()
	if not bool(applied.get("ok", false)):
		_run.from_dict(rollback_run)
		return {"ok": false, "message": "The route could not be closed safely.", "errors": JsonCoerceScript._copy_array(applied.get("errors", []))}
	return {"ok": true, "resolved": true, "snapshot": delivery_snapshot(), "message": "The route closes without you."}


func delivery_resolve_travel_arrival(route: Dictionary = {}, route_risk: Dictionary = {}) -> Dictionary:
	if not delivery_has_active_run():
		return {}
	var rollback_run = _run.to_dict()
	var rollback_environment = _run.current_environment.duplicate(true)
	var rollback_world_map = _run.world_map.duplicate(true)
	var rollback_room_states = _run.grand_casino_room_states.duplicate(true)
	var node_id = _run.current_world_node_id()
	var physical_before := JsonCoerceScript._copy_dict(delivery_snapshot().get("physical", {}))
	var source_node_id := str(physical_before.get("position_node_id", ""))
	var current_archetype_id := str(_run.current_environment.get("archetype_id", "")).strip_edges()
	# Grand Casino interior doors retain one canonical world-node identity. They
	# may change which authored room can complete a delivery, but they are not a
	# second street movement and must not be rejected or counted twice. Require
	# the exact authored local-door envelope so an empty or stale arrival call at
	# Grand cannot masquerade as a room transition.
	if not source_node_id.is_empty() and source_node_id == node_id \
			and node_id == _run.GRAND_CASINO_ARCHETYPE_ID \
			and current_archetype_id in _run.GRAND_CASINO_ARCHETYPE_IDS \
			and bool(route.get("local_casino_room", false)) \
			and str(route.get("target_node_id", "")).strip_edges() == node_id \
			and str(route.get("destination_archetype", "")).strip_edges() == current_archetype_id:
		return {
			"ok": true,
			"resolved": false,
			"room_transition": true,
			"handoff_ready": not delivery_arrival_interaction().is_empty(),
			"snapshot": delivery_snapshot(),
		}
	var route_query := WorldMap.prepare_path_query(_run.world_map, source_node_id, true)
	var authoritative_path := WorldMap.prepared_path(route_query, node_id)
	if source_node_id.is_empty() or source_node_id == node_id or authoritative_path.is_empty() or not WorldMap.prepared_path_uses_real_edges(route_query, authoritative_path):
		return {"ok": false, "resolved": false, "snapshot": delivery_snapshot(), "errors": ["delivery travel did not cross an authoritative real-map route"]}
	var security_heat := _delivery_arrival_security_heat()
	if security_heat > 0:
		_run.add_suspicion("delivery_arrival", security_heat, "contraband", true, {
			"node_id": node_id,
			"cargo_id": str(active_delivery_run.get("cargo_id", "")),
			"route_risk_triggered": bool(route_risk.get("triggered", false)),
		}, true)
		active_delivery_run = DeliveryRunModelScript.add_heat(active_delivery_run, security_heat)
	# Travel is one delivery action boundary. Ordinary travel never enters here.
	var advance_result = _run.advance_environment_turns(1)
	if not bool(advance_result.get("ok", false)):
		_run.from_dict(rollback_run)
		_run.current_environment = rollback_environment
		_run.world_map = rollback_world_map
		_run.grand_casino_room_states = rollback_room_states
		return {"ok": false, "resolved": false, "snapshot": delivery_snapshot(), "errors": JsonCoerceScript._copy_array(advance_result.get("errors", []))}
	if not delivery_has_active_run():
		# Expiry, capture, and other modeled terminal outcomes are successful
		# gameplay commits, not failed travel transactions. Returning `ok=false`
		# made Foundation restore the pre-travel lifecycle snapshot, which revived
		# the same one-action delivery and trapped the player on an enabled route
		# that could only fail again.
		var resolution := JsonCoerceScript._copy_dict(active_delivery_run.get("resolution", {}))
		var reason := str(resolution.get("reason", "failed"))
		return {
			"ok": true,
			"resolved": true,
			"handoff_ready": false,
			"message": "The delivery window closed before the handoff." if reason == "deadline" else "The delivery route closed before the handoff.",
			"snapshot": delivery_snapshot(),
		}
	var move_receipt := "travel:%s:%s:%d" % [source_node_id, node_id, maxi(0, _run._crew_action_index())]
	var move_context := _delivery_host_context(source_node_id, node_id, "", "", "", "", str(route.get("id", route.get("target_node_id", node_id))))
	var before_move := JSON.stringify(active_delivery_run)
	active_delivery_run = DeliveryRunModelScript.apply_host_action(active_delivery_run, "move", move_receipt, move_context)
	if JSON.stringify(active_delivery_run) == before_move:
		_run.from_dict(rollback_run)
		_run.current_environment = rollback_environment
		_run.world_map = rollback_world_map
		_run.grand_casino_room_states = rollback_room_states
		return {"ok": false, "resolved": false, "snapshot": delivery_snapshot(), "errors": ["delivery model rejected the authoritative travel arrival"]}
	_run._apply_delivery_resolution()
	return {
		"ok": true,
		"resolved": not delivery_has_active_run(),
		"handoff_ready": not delivery_arrival_interaction().is_empty(),
		"route_id": str(route.get("id", route.get("target_node_id", node_id))),
		"snapshot": delivery_snapshot(),
	}


func _delivery_required_target_archetype_id() -> String:
	return str(JsonCoerceScript._copy_dict(active_delivery_run.get("consumer_payload", {})).get("required_target_archetype_id", "")).strip_edges()


func _delivery_target_room_blocked() -> bool:
	var required_archetype_id := _delivery_required_target_archetype_id()
	if required_archetype_id.is_empty() or not delivery_has_active_run():
		return false
	var target_node_id := ""
	for target_value in JsonCoerceScript._copy_array(delivery_snapshot().get("targets", [])):
		var target := JsonCoerceScript._copy_dict(target_value)
		if str(target.get("status", "pending")) == "pending":
			target_node_id = str(target.get("node_id", "")).strip_edges()
			break
	return not target_node_id.is_empty() \
		and _run.current_world_node_id() == target_node_id \
		and str(_run.current_environment.get("archetype_id", "")).strip_edges() != required_archetype_id


func _delivery_required_room_message() -> String:
	var required_archetype_id := _delivery_required_target_archetype_id()
	if required_archetype_id.is_empty():
		return "This is not the marked handoff."
	return "The marked route continues inside %s." % required_archetype_id.replace("_", " ").capitalize()


func delivery_map_layer() -> Dictionary:
	if not delivery_has_active_run():
		return {}
	var delivery_view := delivery_snapshot()
	var physical := JsonCoerceScript._copy_dict(delivery_view.get("physical", {}))
	var public_sweep = _run.sweep_status()
	var edge_reads: Array = []
	for edge_value in JsonCoerceScript._copy_array(_run.world_map.get("edges", [])):
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		var a := str(edge.get("a", "")).strip_edges()
		var b := str(edge.get("b", "")).strip_edges()
		if not WorldMap.is_node_visible(_run.world_map, a) or not WorldMap.is_node_visible(_run.world_map, b):
			continue
		var score := 0
		var reasons: Array = []
		var weather = _run.weather_now()
		if weather in ["rain", "storm", "fog"]:
			score += 1
			reasons.append("weather cover" if weather == "fog" else "bad weather")
		var attention := 0.0
		if _run.town_state != null:
			attention = maxf(float(_run.town_state.local_reputation(a).get("attention", 0.0)), float(_run.town_state.local_reputation(b).get("attention", 0.0)))
		if attention >= 0.5:
			score += 1
			reasons.append("local attention")
		var law_pressure := _delivery_scenario_law_pressure([a, b])
		if law_pressure > 0:
			score += law_pressure
			reasons.append("venue pressure")
		if not public_sweep.is_empty() and bool(public_sweep.get("active", false)):
			var sweep_nodes := [str(public_sweep.get("current_node_id", "")), str(public_sweep.get("heading_node_id", ""))]
			if a in sweep_nodes or b in sweep_nodes:
				score += 2
				reasons.append("reported sweep")
		elif public_sweep.is_empty():
			reasons.append("sweep unknown")
		var band := "low" if score <= 1 else "guarded" if score <= 3 else "hot"
		edge_reads.append({
			"edge_id": str(edge.get("id", "%s--%s" % [a, b])),
			"a": a,
			"b": b,
			"band": band,
			"reasons": reasons,
		})
	return {
		"active": true,
		"mode": str(active_delivery_run.get("mode", "package")),
		"targets": JsonCoerceScript._copy_array(delivery_view.get("targets", [])),
		"deadline_remaining": int(active_delivery_run.get("deadline_remaining", 0)),
		"cargo": {
			"id": str(active_delivery_run.get("cargo_id", "")),
			"label": str(active_delivery_run.get("cargo_label", "Crew package")),
			"contraband": bool(delivery_view.get("carrying_contraband", false)),
			"status": str(physical.get("cargo_state", "none")),
			"node_id": str(physical.get("cargo_node_id", "")),
			"place_id": str(physical.get("cargo_place_id", "")),
		},
		"edge_reads": edge_reads,
	}


func _delivery_resolve_targets(spec: Dictionary) -> Dictionary:
	var requested: Array = []
	for source_value in [spec.get("targets", []), spec.get("stops", []), spec.get("target_node_ids", [])]:
		if typeof(source_value) != TYPE_ARRAY or (source_value as Array).is_empty():
			continue
		for entry_value in source_value as Array:
			var node_id := str((entry_value as Dictionary).get("node_id", (entry_value as Dictionary).get("id", ""))).strip_edges() if typeof(entry_value) == TYPE_DICTIONARY else str(entry_value).strip_edges()
			if not node_id.is_empty() and not requested.has(node_id):
				requested.append(node_id)
		break
	var count := maxi(1, int(spec.get("target_count", requested.size() if not requested.is_empty() else 1)))
	var origin_id = _run.current_world_node_id()
	var offer_path_query := WorldMap.prepare_path_query(_run.world_map, origin_id, false)
	var buckets := [[], [], []]
	var nodes_value: Variant = _run.world_map.get("nodes", [])
	if typeof(nodes_value) == TYPE_ARRAY:
		for node_value in nodes_value as Array:
			if typeof(node_value) != TYPE_DICTIONARY:
				continue
			var node: Dictionary = node_value
			var node_id := str(node.get("id", "")).strip_edges()
			if node_id.is_empty() or (node_id == origin_id and str(spec.get("mode", "")) != DeliveryRunModelScript.MODE_HOLD):
				continue
			if str(node.get("archetype_id", "")).strip_edges().is_empty() or str(node.get("kind", "")).strip_edges().is_empty():
				continue
			if str(spec.get("mode", "")) in [DeliveryRunModelScript.MODE_PACKAGE, DeliveryRunModelScript.MODE_MULTI_STOP] and _delivery_target_is_home(node):
				continue
			if not WorldMap.prepared_has_path(offer_path_query, node_id) and node_id != origin_id:
				continue
			# Familiar places are the default: first rooms the player has entered,
			# then the rest of the discovered map. Hidden real nodes remain the last
			# bucket so courier work can still pull the player into unseen town.
			var bucket_index := 0 if str(node.get("state", "hidden")) == WorldMap.STATE_VISITED else 1 if WorldMap.prepared_is_node_visible(offer_path_query, node_id) else 2
			(buckets[bucket_index] as Array).append(node_id)
	var candidates: Array = []
	var target_rng = _run.create_rng("delivery_targets:%s:%d" % [str(spec.get("run_id", spec.get("route_id", "delivery"))), _run._crew_action_index()])
	for bucket_value in buckets:
		var bucket: Array = bucket_value
		bucket.sort()
		for chosen_value in target_rng.pick_many(bucket, bucket.size()):
			candidates.append(str(chosen_value))
	var chosen_ids := requested if not requested.is_empty() else candidates.slice(0, mini(count, candidates.size()))
	if chosen_ids.size() != count:
		return {"ok": false, "message": "The job has no complete real route tonight."}
	var allows_origin_return = str(spec.get("mode", "")) == DeliveryRunModelScript.MODE_MULTI_STOP \
		and chosen_ids.size() > 1 and str(chosen_ids[chosen_ids.size() - 1]) == origin_id
	var reveal_ids: Array = []
	var targets: Array = []
	for node_id_value in chosen_ids:
		var node_id := str(node_id_value)
		if not candidates.has(node_id) and not (allows_origin_return and node_id == origin_id):
			return {"ok": false, "message": "%s is not a reachable venue tonight." % node_id.replace("_", " ").capitalize()}
		var path := WorldMap.prepared_path(offer_path_query, node_id) if node_id != origin_id else [origin_id]
		if path.is_empty() or not WorldMap.prepared_path_uses_real_edges(offer_path_query, path):
			return {"ok": false, "message": "The route to %s is not a real map path." % node_id.replace("_", " ").capitalize()}
		for path_id_value in path:
			var path_id := str(path_id_value)
			if not WorldMap.prepared_is_node_visible(offer_path_query, path_id) and not reveal_ids.has(path_id):
				reveal_ids.append(path_id)
		var node := WorldMap.node_metadata_by_id(_run.world_map, node_id)
		var was_visible := WorldMap.prepared_is_node_visible(offer_path_query, node_id)
		targets.append({
			"id": "delivery_target_%s" % node_id,
			"node_id": node_id,
			"label": str(node.get("label", node_id.replace("_", " ").capitalize())),
			"contact_id": "delivery_contact_%s" % node_id,
			"contact_label": _delivery_contact_label(node),
			"was_visited_at_offer": str(node.get("state", "hidden")) == WorldMap.STATE_VISITED,
			"was_visible_at_offer": was_visible,
			"revealed_by_job": not was_visible,
		})
	var offered_map := WorldMap.unlock_nodes(_run.world_map, reveal_ids, WorldMap.DISCOVERY_SOURCE_EVENT)
	var offered_path_query := WorldMap.prepare_path_query(offered_map, origin_id, true)
	for target_value in targets:
		var node_id := str((target_value as Dictionary).get("node_id", ""))
		var visible_path := WorldMap.prepared_path(offered_path_query, node_id) if node_id != origin_id else [origin_id]
		if visible_path.is_empty() or not WorldMap.prepared_path_uses_real_edges(offered_path_query, visible_path):
			return {"ok": false, "message": "The revealed courier route is incomplete."}
	return {"ok": true, "targets": targets, "world_map": offered_map}


func _delivery_target_is_home(node: Dictionary) -> bool:
	var node_id := str(node.get("id", "")).strip_edges()
	var archetype_id := str(node.get("archetype_id", "")).strip_edges()
	return str(node.get("kind", "")).strip_edges() == "home" \
		or node_id == str(_run.home_state.get("home_node_id", "")).strip_edges() \
		or archetype_id in ["apartment", "house", "motel_room"]


func _delivery_contact_label(node: Dictionary) -> String:
	var archetype_id := str(node.get("archetype_id", "")).strip_edges()
	if archetype_id == "back_alley": return "the alley lookout"
	if archetype_id == "corner_store": return "the counter clerk"
	if archetype_id == "pawn_shop": return "the shop contact"
	if archetype_id == "motel": return "the desk clerk"
	if archetype_id in ["bar", "jazz_club"]: return "the bartender"
	if str(node.get("kind", "")) in ["casino", "boss", "club"]: return "the floor contact"
	return "the marked contact"


func _delivery_add_inventory_cargo() -> void:
	if str(active_delivery_run.get("cargo_id", "")) == "crew_package":
		_run.add_item("crew_package")


func _delivery_remove_inventory_cargo() -> void:
	if str(active_delivery_run.get("cargo_id", "")) == "crew_package":
		_run.remove_item("crew_package")


func _delivery_scenario_law_pressure(node_ids: Array) -> int:
	var total := 0
	var seen := {}
	for node_id_value in node_ids:
		var node_id := str(node_id_value).strip_edges()
		if node_id.is_empty() or seen.has(node_id):
			continue
		seen[node_id] = true
		var definition = _run._seeded_scenario_definition_for_node_readonly(node_id)
		var mutations: Dictionary = definition.get("mutations", {}) if typeof(definition.get("mutations", {})) == TYPE_DICTIONARY else {}
		var security: Dictionary = mutations.get("security_overrides", {}) if typeof(mutations.get("security_overrides", {})) == TYPE_DICTIONARY else {}
		match str(security.get("strictness_band", "")).to_lower():
			"high", "strict", "maximum":
				total += 2
			"medium", "uneven":
				total += 1
	return clampi(total, 0, 4)


func _delivery_arrival_security_heat() -> int:
	if not delivery_has_active_run() or not bool(delivery_snapshot().get("carrying_contraband", false)):
		return 0
	var heat := maxi(0, int(active_delivery_run.get("cargo_heat_per_travel", 2)))
	var security := JsonCoerceScript._copy_dict(_run.current_environment.get("security_profile", {}))
	match str(security.get("strictness_band", security.get("strictness", "low"))).to_lower():
		"medium":
			heat += 1
		"high", "strict", "maximum":
			heat += 2
	heat += _delivery_scenario_law_pressure([_run.current_world_node_id()])
	return heat
