extends "res://tools/fix06_28_working_order_driver.gd"

# End-to-end player-route proof for fix06_29. This inherits only the production
# scene/input helpers from fix06_28: every progression step below is a rendered
# click and every assertion is made from a visible surface snapshot.

const FIX29_SETTINGS_PATH := "user://fix06_29_punchline_settings.json"
const FIX29_META_PATH := "user://fix06_29_punchline_meta.json"
const FIX29_PROFILE_PATH := "user://fix06_29_punchline_profile.json"
const FIX29_SEED := "FIRST-NIGHT-ACE-17"
const FAVOR_COMPLETIONS_REQUIRED := 11


func _run() -> void:
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, FIX29_SETTINGS_PATH)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, FIX29_META_PATH)
	OS.set_environment(ProfileInventoryScript.INVENTORY_PATH_ENV, FIX29_PROFILE_PATH)
	var isolated_settings: UserSettings = UserSettingsScript.new()
	isolated_settings.reset()
	if isolated_settings.save() != OK:
		_fail("Could not prepare isolated fix06_29 settings.")
		_finish()
		return
	var isolated_profile: ProfileInventory = ProfileInventoryScript.new()
	isolated_profile.from_dict({"tutorial_completed": true})
	if isolated_profile.save() != OK:
		_fail("Could not prepare the ordinary-run profile precondition.")
		_finish()
		return
	report = {
		"schema_version": 1,
		"check_id": "fix06_29_punchline_natural_l3_route",
		"authority": {
			"host": "res://scenes/main.tscn",
			"targeting": "exact_rendered_semantic_id",
			"input": "Viewport.push_input(InputEventMouseButton)",
			"progression": "ordinary visible Crew favors",
			"hidden_state_oracle": false,
			"fixtures": false,
			"direct_product_handlers": false,
		},
		"seed": FIX29_SEED,
		"initial_gate": {},
		"favor_completions": [],
		"progression_persistence": {},
		"entry": {},
		"room": {},
		"room_persistence": {},
		"revisit": {},
		"departure": {},
		"failures": [],
	}
	var app := await _start_app(FIX29_SEED)
	if app == null:
		_fail("The ordinary production run could not start through visible Run Setup.")
		_finish()
		return
	await _resolve_visible_blocking_dialogue(app)
	if not await _travel_until_exact_node(app, FIX29_SEED, "gas_station_casino"):
		_fail("The visible world route could not reach the seeded Parking Lot Tip venue.")
		await _dispose_app(app)
		_finish()
		return
	if not await _choose_inline_event(app, "event:parking_lot_tip", "parking_lot_tip", "follow_tip"):
		_fail("Parking Lot Tip did not open The Punchline through its exact tooltip response.")
	if failures.is_empty() and not await _travel_until_exact_node(app, FIX29_SEED, "small_underground_casino"):
		_fail("The exact visible Punchline destination could not be reached after the tip.")
	if failures.is_empty() and not await _choose_inline_event(app, "event:side_door", "side_door", "punchline_password"):
		_fail("The exact Side Door response did not enter the Punchline casino layer.")
	if failures.is_empty():
		report["initial_gate"] = await _visible_layer_target(app, "back_room")
		var gate := _dict(report["initial_gate"])
		if not bool(gate.get("visible", false)) or bool(gate.get("enabled_action", true)) \
				or not str(gate.get("copy", "")).contains("Rook keeps this door for made company"):
			_fail("The initial exact back-room target did not expose its authored visible locked gate copy.")
	if failures.is_empty() and not await _enter_layer(app, "club"):
		_fail("The casino did not expose the exact visible club return action.")
	if failures.is_empty() and not await _travel_until_exact_node(app, FIX29_SEED, "corner_store"):
		_fail("The player route could not return to Corner Store for normal Crew progression.")

	for favor_number in range(1, FAVOR_COMPLETIONS_REQUIRED + 1):
		if not failures.is_empty():
			break
		var favor := await _complete_visible_crew_favor(app, favor_number)
		report["favor_completions"].append(favor)
		if not bool(favor.get("passed", false)):
			_fail("Visible Crew favor %d did not complete: %s" % [favor_number, JSON.stringify(favor)])
	if failures.is_empty():
		await _resolve_visible_blocking_dialogue(app)
		await create_timer(2.0).timeout
		report["progression_persistence"] = await _verify_save_continue(app, FIX29_SEED)
		if not bool(_dict(report["progression_persistence"]).get("continued", false)):
			_fail("Naturally earned Crew access did not persist through visible Save/Main Menu/Continue.")
	if failures.is_empty() and not await _travel_until_exact_node(app, FIX29_SEED, "small_underground_casino"):
		_fail("The persisted player route could not return to the Punchline destination.")
	if failures.is_empty() and not await _ensure_layer(app, "casino"):
		_fail("The persisted Punchline visit could not reach the casino layer through exact rendered controls.")
	if failures.is_empty():
		var unlocked := await _visible_layer_target(app, "back_room")
		report["entry"] = unlocked
		if not bool(unlocked.get("visible", false)) or not bool(unlocked.get("enabled_action", false)):
			_fail("Naturally earned standing did not visibly unlock the exact back-room action.")
		elif not await _enter_layer(app, "back_room"):
			_fail("The unlocked exact back-room action did not enter the rendered room.")
	if failures.is_empty():
		report["room"] = await _visible_room_inventory(app)
		var room := _dict(report["room"])
		if not bool(room.get("has_poker", false)) or not bool(room.get("has_casino_return", false)) \
				or _array(room.get("actionable_objects", [])).is_empty():
			_fail("The rendered back room did not expose its expected player-readable objects and room actions.")
	if failures.is_empty():
		report["room_persistence"] = await _verify_save_continue(app, FIX29_SEED)
		if not bool(_dict(report["room_persistence"]).get("revisited_same_node", false)) \
				or not bool(_dict(await _visible_room_inventory(app)).get("has_poker", false)):
			_fail("Visible Save/Continue did not restore the same furnished back room.")
	if failures.is_empty():
		if await _enter_layer(app, "casino") and await _enter_layer(app, "back_room"):
			report["revisit"] = {"passed": true, "inventory": await _visible_room_inventory(app)}
		else:
			_fail("The exact back-room/casino controls did not support a visible revisit.")
	if failures.is_empty() and await _enter_layer(app, "casino"):
		report["departure"] = await _depart_punchline(app)
		if not bool(_dict(report["departure"]).get("passed", false)):
			_fail("The Punchline could not be departed through exact visible travel controls.")
	await _dispose_app(app)
	_finish()


func _begin_visible_crew_marker(app: Control) -> Dictionary:
	var result := {"passed": false, "message": ""}
	var reached_corner := await _travel_until_exact_node(app, FIX29_SEED, "corner_store", "crew_favor_delivery")
	if str(_visible_talk_snapshot(app).get("event_id", "")) == "crew_favor_delivery" \
			or str(_visible_event_popup_snapshot(app).get("event_id", "")) == "crew_favor_delivery":
		result["passed"] = true
		result["message"] = "The existing Crew marker produced its next visible favor."
		return result
	if not reached_corner:
		# Crew work can naturally carry the clock past the Corner Store's open
		# hours. Spend the night on an exact, ordinary motel/Punchline route and
		# resume after morning rather than mutating the clock.
		await create_timer(0.8).timeout
		await _settle(8)
		var overnight := await _advance_night_through_visible_travel(app)
		result["overnight_travel"] = overnight
		if not bool(overnight.get("passed", false)):
			result["visible_message"] = _observable_visible_message(app)
			return result
		if bool(overnight.get("event_ready", false)):
			result["passed"] = true
			result["message"] = "The overnight route produced the next visible Crew favor."
			return result
		reached_corner = await _travel_until_exact_node(app, FIX29_SEED, "corner_store", "crew_favor_delivery")
		if str(_visible_talk_snapshot(app).get("event_id", "")) == "crew_favor_delivery" \
				or str(_visible_event_popup_snapshot(app).get("event_id", "")) == "crew_favor_delivery":
			result["passed"] = true
			result["message"] = "The reopened route produced the next visible Crew favor."
			return result
		if not reached_corner:
			result["visible_message"] = _observable_visible_message(app)
			return result
	await _resolve_visible_blocking_dialogue(app, "crew_favor_delivery")
	var lender := await _activate_exact_room_action(app, "lender:the_crew", 0)
	result["opened_talk"] = _visible_talk_snapshot(app)
	if not bool(lender.get("ok", false)):
		result["lender"] = lender
		return result
	var accepted := await _choose_visible_talk_choice(app, "accept", "lender_conversation:borrow:the_crew")
	result["borrow_attempt"] = accepted.duplicate(true)
	if not bool(accepted.get("resolved", false)):
		accepted = await _choose_visible_talk_choice(app, "accept", "lender_conversation:repay:the_crew")
		result["repay_attempt"] = accepted.duplicate(true)
		if bool(accepted.get("resolved", false)):
			lender = await _activate_exact_room_action(app, "lender:the_crew", 0)
			result["reopen_lender"] = lender.duplicate(true)
			result["reopened_talk"] = _visible_talk_snapshot(app)
			if bool(lender.get("ok", false)):
				accepted = await _choose_visible_talk_choice(app, "accept", "lender_conversation:borrow:the_crew")
	result["passed"] = bool(accepted.get("resolved", false))
	result["message"] = str(accepted.get("visible_message", ""))
	return result


func _advance_night_through_visible_travel(app: Control) -> Dictionary:
	var result := {"passed": false, "legs": [], "room_actions": 0, "event_ready": false}
	if bool(_dict(app.call("current_screen_snapshot")).get("world_map_overlay_visible", false)):
		await _close_visible_world_map(app)
	# A riverboat visit can hold departure for a small authored action count. Its
	# map says exactly why every route is disabled; spend only visible room actions
	# until that published lock clears.
	for _action in range(6):
		var current_map := _dict(_dict(app.call("current_screen_snapshot")).get("world_map", {}))
		if not _array(current_map.get("travel_enabled_node_ids", [])).is_empty():
			break
		var ordinary := await _activate_first_ordinary_room_action(app)
		if not bool(ordinary.get("ok", false)):
			return result
		result["room_actions"] = int(result["room_actions"]) + 1
		await _resolve_visible_blocking_dialogue(app, "crew_favor_delivery")
		if str(_visible_talk_snapshot(app).get("event_id", "")) == "crew_favor_delivery" \
				or str(_visible_event_popup_snapshot(app).get("event_id", "")) == "crew_favor_delivery":
			result["event_ready"] = true
			result["passed"] = true
			return result
	if _current_visible_node_id(app) != "motel" and not await _travel_until_exact_node(app, FIX29_SEED, "motel", "crew_favor_delivery"):
		return result
	for _leg in range(8):
		if str(_visible_talk_snapshot(app).get("event_id", "")) == "crew_favor_delivery" \
				or str(_visible_event_popup_snapshot(app).get("event_id", "")) == "crew_favor_delivery":
			result["event_ready"] = true
			result["passed"] = true
			return result
		var map := _dict(_dict(app.call("current_screen_snapshot")).get("world_map", {}))
		var enabled := _array(map.get("travel_enabled_node_ids", []))
		if enabled.has("corner_store"):
			result["passed"] = true
			return result
		var current := str(map.get("current_node_id", ""))
		var next_id := "small_underground_casino" if current == "motel" else "motel"
		if not enabled.has(next_id):
			return result
		result["legs"].append({"from": current, "to": next_id})
		if not await _travel_one_exact_leg(app, FIX29_SEED, next_id):
			return result
		await _resolve_visible_blocking_dialogue(app, "crew_favor_delivery")
	return result


func _complete_visible_crew_favor(app: Control, favor_number: int) -> Dictionary:
	var result := {"number": favor_number, "borrowed": false, "marker_continues": false, "job_started": false, "pickup": false, "target": "", "handoff": false, "passed": false, "messages": []}
	var borrow := await _begin_visible_crew_marker(app)
	result["borrowed"] = bool(borrow.get("passed", false))
	result["messages"].append(str(borrow.get("message", "")))
	if not bool(result["borrowed"]):
		result["lender"] = borrow
		return result
	var cadence_target := "corner_store"
	for attempt in range(72):
		var pickup_id := _first_visible_room_object_with_prefix(app, "delivery:pickup:")
		if not pickup_id.is_empty():
			result["job_started"] = true
			break
		var talk := _visible_talk_snapshot(app)
		if str(talk.get("event_id", "")) == "crew_favor_delivery":
			var talk_choice := await _choose_visible_talk_choice(app, "run_package", "crew_favor_delivery")
			result["job_started"] = bool(talk_choice.get("resolved", false))
			result["messages"].append(str(talk_choice.get("visible_message", "")))
			continue
		var popup := _visible_event_popup_snapshot(app)
		if str(popup.get("event_id", "")) == "crew_favor_delivery":
			var popup_choice := await _choose_visible_event_popup_choice(app, "run_package", "crew_favor_delivery")
			result["job_started"] = bool(popup_choice.get("resolved", false))
			result["messages"].append(str(popup_choice.get("visible_message", "")))
			continue
		if bool(talk.get("visible", false)) or bool(popup.get("visible", false)):
			await _resolve_visible_blocking_dialogue(app, "crew_favor_delivery")
			continue
		var ordinary := await _activate_first_ordinary_room_action(app)
		if bool(ordinary.get("ok", false)):
			continue
		var next_target := "house" if cadence_target == "corner_store" else "corner_store"
		if not await _travel_until_exact_node(app, FIX29_SEED, next_target, "crew_favor_delivery"):
			break
		cadence_target = next_target
	var pickup_id := _first_visible_room_object_with_prefix(app, "delivery:pickup:")
	if pickup_id.is_empty():
		return result
	var pickup := await _activate_exact_room_action(app, pickup_id, 0)
	result["pickup"] = bool(pickup.get("ok", false))
	result["messages"].append(str(pickup.get("visible_message", "")))
	if not bool(result["pickup"]):
		return result
	var target_id := await _open_map_and_visible_delivery_target(app)
	result["target"] = target_id
	if target_id.is_empty():
		return result
	var map := _dict(_dict(app.call("current_screen_snapshot")).get("world_map", {}))
	result["map_before_target"] = {"current": str(map.get("current_node_id", "")), "enabled": _array(map.get("travel_enabled_node_ids", [])).duplicate()}
	var arrived := false
	if _array(map.get("travel_enabled_node_ids", [])).has(target_id):
		arrived = await _confirm_open_map_target(app, target_id)
		# Arrival may immediately open a room event or tutorial dialogue before the
		# map helper's fixed frame wait observes its final screen. Treat the visible
		# destination identity as authoritative after clearing that modal.
		if not arrived:
			await _resolve_visible_blocking_dialogue(app)
			arrived = _current_visible_node_id(app) == target_id
	else:
		if bool(_dict(app.call("current_screen_snapshot")).get("world_map_overlay_visible", false)):
			await _close_visible_world_map(app)
		arrived = await _travel_until_exact_node(app, FIX29_SEED, target_id)
	result["arrival_probe"] = {"arrived": arrived, "current": _current_visible_node_id(app), "screen": str(app.get("current_screen"))}
	if not arrived:
		return result
	# The destination is visible before its presentation-only travel curtain has
	# finished releasing input. A player necessarily waits through that curtain.
	await create_timer(0.8).timeout
	await _settle(3)
	await _resolve_visible_blocking_dialogue(app)
	var handoff_id := _first_visible_room_object_with_prefix(app, "delivery:handoff:")
	if handoff_id.is_empty() and _room_has_object(app, "crew::package_handoff"):
		handoff_id = "crew::package_handoff"
	if handoff_id.is_empty():
		return result
	result["handoff_id"] = handoff_id
	var handoff := await _activate_exact_room_action(app, handoff_id, 0)
	result["handoff_action"] = handoff.duplicate(true)
	var handoff_message := str(handoff.get("visible_message", ""))
	result["messages"].append(handoff_message)
	var handoff_removed := not _room_has_object(app, handoff_id)
	if not handoff_removed:
		var retry_errors: Array = []
		Fidelity.push_exact_canvas_mouse_click(app.get_viewport(), app.get("environment_canvas"), handoff_id, retry_errors, "fix06_29 handoff activation", true)
		await _settle(8)
		handoff_removed = not _room_has_object(app, handoff_id)
	# Punchline deliveries can target its already discovered casino interior.
	# The exterior handoff is a visible direction, not completion. A travel result
	# can remain on the status layer while the room action commits, so disappearance
	# of the exact rendered handoff is the visible completion proof.
	if bool(handoff.get("ok", false)) and not handoff_removed and handoff_message.contains("waiting inside") \
			and _room_has_object(app, "environment_layer:casino"):
		var entered_casino := await _enter_layer(app, "casino")
		var interior_handoff_id := _first_visible_room_object_with_prefix(app, "delivery:handoff:")
		if interior_handoff_id.is_empty() and _room_has_object(app, "crew::package_handoff"):
			interior_handoff_id = "crew::package_handoff"
		if not interior_handoff_id.is_empty():
			handoff = await _activate_exact_room_action(app, interior_handoff_id, 0)
			handoff_message = str(handoff.get("visible_message", ""))
			result["messages"].append(handoff_message)
			handoff_removed = not _room_has_object(app, interior_handoff_id)
		result["entered_casino"] = entered_casino
	result["handoff"] = bool(handoff.get("ok", false)) and (handoff_removed or handoff_message.contains("package changes hands"))
	for _stop in range(4):
		if not bool(result["handoff"]):
			break
		var next_target_id := await _open_map_and_visible_delivery_target(app)
		if next_target_id.is_empty():
			break
		var next_arrived := await _travel_until_exact_node(app, FIX29_SEED, next_target_id)
		if not next_arrived:
			result["handoff"] = false
			break
		await create_timer(0.8).timeout
		await _resolve_visible_blocking_dialogue(app)
		var next_handoff_id := _first_visible_room_object_with_prefix(app, "delivery:handoff:")
		if next_handoff_id.is_empty() and _room_has_object(app, "crew::package_handoff"):
			next_handoff_id = "crew::package_handoff"
		if next_handoff_id.is_empty():
			result["handoff"] = false
			break
		var next_handoff := await _activate_exact_room_action(app, next_handoff_id, 0)
		result["messages"].append(str(next_handoff.get("visible_message", "")))
		result["handoff"] = bool(next_handoff.get("ok", false)) and not _room_has_object(app, next_handoff_id)
	result["passed"] = bool(result["borrowed"]) and bool(result["job_started"]) and bool(result["pickup"]) and bool(result["handoff"])
	return result


func _choose_inline_event(app: Control, object_id: String, event_id: String, choice_id: String) -> bool:
	var debug := {"object_id": object_id, "event_id": event_id, "choice_id": choice_id}
	var canvas := app.get("environment_canvas") as Control
	var local_failures: Array = []
	var selected := Fidelity.push_exact_canvas_mouse_click(app.get_viewport(), canvas, object_id, local_failures, "fix06_29 event %s" % event_id)
	await _settle(4)
	debug["selection"] = selected
	debug["selection_errors"] = local_failures
	if not bool(selected.get("ok", false)) or not Fidelity.exact_selection_matches(app, object_id):
		report["last_event_route"] = debug
		return false
	var actions := _array(_dict(_dict(canvas.call("current_view_snapshot")).get("selected_info", {})).get("actions", []))
	debug["actions"] = actions.duplicate(true)
	var expected_id := "event_response:%s:%s" % [event_id, choice_id]
	var action_index := -1
	for index in range(actions.size()):
		if str(_dict(actions[index]).get("emit_object_id", "")) == expected_id:
			action_index = index
			break
	if action_index < 0:
		report["last_event_route"] = debug
		return false
	var local_position: Vector2 = canvas.call("local_position_for_selected_info_action_button", action_index)
	if local_position.x < 0.0:
		report["last_event_route"] = debug
		return false
	await _push_click(app.get_viewport(), canvas.get_global_transform_with_canvas() * local_position)
	await _settle(8)
	var popup := _visible_event_popup_snapshot(app)
	if bool(popup.get("visible", false)) and str(popup.get("event_id", "")) == event_id:
		var resolved := await _choose_visible_event_popup_choice(app, choice_id, event_id)
		debug["popup_resolution"] = resolved
		report["last_event_route"] = debug
		return bool(resolved.get("resolved", false))
	debug["visible_message"] = _observable_visible_message(app)
	debug["object_remains"] = _room_has_object(app, object_id)
	report["last_event_route"] = debug
	return not bool(debug["object_remains"])


func _travel_until_exact_node(app: Control, seed: String, target_id: String, preserve_event_id: String = "") -> bool:
	var visited: Dictionary = {}
	var trace: Array = []
	for _hop in range(24):
		if not preserve_event_id.is_empty() and (str(_visible_event_popup_snapshot(app).get("event_id", "")) == preserve_event_id \
				or str(_visible_talk_snapshot(app).get("event_id", "")) == preserve_event_id):
			return true
		var map := _dict(_dict(app.call("current_screen_snapshot")).get("world_map", {}))
		var current_id := str(map.get("current_node_id", ""))
		if current_id == target_id:
			return true
		visited[current_id] = true
		var enabled_ids := _array(map.get("travel_enabled_node_ids", []))
		var next_id := target_id if enabled_ids.has(target_id) else _closest_visible_route_hop(map, enabled_ids, target_id, visited)
		trace.append({"current": current_id, "enabled": enabled_ids.duplicate(), "next": next_id})
		report["last_travel_trace"] = trace.duplicate(true)
		if next_id.is_empty():
			return false
		var departed := await _travel_one_exact_leg(app, seed, next_id)
		if not departed:
			# Arrival events are modal above the map. Clear that visible event first so
			# the public tab's published current-node identity can catch up.
			await _resolve_visible_blocking_dialogue(app, preserve_event_id)
			await _settle(4)
		# Destination events may open on the same frame as arrival and keep the map
		# helper from observing its usual post-travel screen. The exact visible world
		# node is the authoritative completion signal in that case.
		if not departed and _current_visible_node_id(app) == next_id:
			departed = true
		# A just-dismissed result/travel curtain can release input a frame after the
		# visible room returns. Retry the same exact rendered control once, only if
		# the player is still in the source room and the map still publishes it.
		if not departed and _current_visible_node_id(app) == current_id:
			await create_timer(0.8).timeout
			await _settle(8)
			var retry_map := _dict(_dict(app.call("current_screen_snapshot")).get("world_map", {}))
			if _array(retry_map.get("travel_enabled_node_ids", [])).has(next_id):
				departed = await _travel_one_exact_leg(app, seed, next_id)
		if not departed:
			return false
		await _resolve_visible_blocking_dialogue(app, preserve_event_id)
	return _current_visible_node_id(app) == target_id


func _closest_visible_route_hop(map: Dictionary, enabled_ids: Array, target_id: String, visited: Dictionary) -> String:
	var adjacency: Dictionary = {}
	for edge_value in _array(map.get("edges", [])):
		var edge := _dict(edge_value)
		var a := str(edge.get("a", ""))
		var b := str(edge.get("b", ""))
		if a.is_empty() or b.is_empty():
			continue
		var from_a := _array(adjacency.get(a, []))
		if not from_a.has(b):
			from_a.append(b)
		adjacency[a] = from_a
		var from_b := _array(adjacency.get(b, []))
		if not from_b.has(a):
			from_b.append(a)
		adjacency[b] = from_b
	var distance: Dictionary = {target_id: 0}
	var queue: Array = [target_id]
	while not queue.is_empty():
		var node_id := str(queue.pop_front())
		for neighbor_value in _array(adjacency.get(node_id, [])):
			var neighbor := str(neighbor_value)
			if distance.has(neighbor):
				continue
			distance[neighbor] = int(distance.get(node_id, 0)) + 1
			queue.append(neighbor)
	var best_id := ""
	var best_distance := 1 << 20
	for enabled_value in enabled_ids:
		var candidate := str(enabled_value)
		if candidate.is_empty() or visited.has(candidate) or not distance.has(candidate):
			continue
		var candidate_distance := int(distance.get(candidate, best_distance))
		if candidate_distance < best_distance or candidate_distance == best_distance and (best_id.is_empty() or candidate < best_id):
			best_id = candidate
			best_distance = candidate_distance
	if not best_id.is_empty():
		return best_id
	for enabled_value in enabled_ids:
		var candidate := str(enabled_value)
		if not candidate.is_empty() and not visited.has(candidate):
			return candidate
	return ""


func _visible_layer_target(app: Control, layer_id: String) -> Dictionary:
	var result := {"semantic_id": "environment_layer:%s" % layer_id, "visible": false, "enabled_action": false, "copy": "", "actions": []}
	var canvas := app.get("environment_canvas") as Control
	if canvas == null:
		return result
	var view := _dict(canvas.call("current_view_snapshot"))
	var object_data: Dictionary = {}
	for value in _array(view.get("objects", [])):
		if _object_id(_dict(value)) == str(result["semantic_id"]):
			object_data = _dict(value)
			break
	if object_data.is_empty() or not bool(object_data.get("visible", true)):
		return result
	var board_rect := _rect(view.get("board_rect", {}))
	var normalized_position: Vector2 = object_data.get("position", Vector2(0.5, 0.5))
	var board_position := normalized_position * Vector2(900.0, 430.0)
	var local_position := board_rect.position + board_position * (board_rect.size.x / 900.0)
	if str(canvas.call("object_id_at_local_position", local_position)) != str(result["semantic_id"]):
		result["errors"] = ["exact rendered hit authority did not resolve the layer target"]
		return result
	await _push_click(app.get_viewport(), canvas.get_global_transform_with_canvas() * local_position)
	await _settle(4)
	result["visible"] = Fidelity.exact_selection_matches(app, str(result["semantic_id"]))
	if not bool(result["visible"]):
		result["errors"] = ["real pointer input did not focus the exact rendered target"]
		return result
	var panel := _dict(_dict(canvas.call("current_view_snapshot")).get("selected_info", {}))
	result["actions"] = _array(panel.get("actions", [])).duplicate(true)
	result["enabled_action"] = not _array(result["actions"]).is_empty()
	var copy_lines: Array[String] = [str(panel.get("title", ""))]
	for line_value in _array(panel.get("lines", [])):
		copy_lines.append(str(line_value))
	result["copy"] = " ".join(copy_lines)
	return result


func _enter_layer(app: Control, layer_id: String) -> bool:
	var target := await _visible_layer_target(app, layer_id)
	report["last_layer_route"] = {"layer_id": layer_id, "target": target}
	if not bool(target.get("visible", false)) or not bool(target.get("enabled_action", false)):
		return false
	var action := await _activate_exact_room_action(app, "environment_layer:%s" % layer_id, 0)
	report["last_layer_route"]["action"] = action
	if not bool(action.get("ok", false)):
		return false
	await _resolve_visible_blocking_dialogue(app)
	if layer_id == "back_room":
		return bool(_dict(await _visible_room_inventory(app)).get("has_poker", false))
	return _room_has_object(app, "environment_layer:back_room") if layer_id == "casino" else _room_has_object(app, "event:side_door") or _room_has_object(app, "environment_layer:casino")


func _ensure_layer(app: Control, layer_id: String) -> bool:
	if layer_id == "casino" and _room_has_object(app, "environment_layer:back_room"):
		return true
	return await _enter_layer(app, layer_id)


func _visible_room_inventory(app: Control) -> Dictionary:
	var result := {"object_ids": [], "actionable_objects": [], "has_poker": false, "has_casino_return": false}
	var canvas := app.get("environment_canvas") as Control
	if canvas == null:
		return result
	for value in _array(_dict(canvas.call("current_view_snapshot")).get("objects", [])):
		var object_data := _dict(value)
		var object_id := _object_id(object_data)
		if object_id.is_empty() or not bool(object_data.get("visible", true)):
			continue
		result["object_ids"].append(object_id)
		if object_id == "game:crew_draw_poker":
			result["has_poker"] = true
		if object_id == "environment_layer:casino":
			result["has_casino_return"] = true
		var local_failures: Array = []
		var selected := Fidelity.push_exact_canvas_mouse_click(app.get_viewport(), canvas, object_id, local_failures, "fix06_29 room inventory")
		await _settle(2)
		if bool(selected.get("ok", false)):
			var panel := _dict(_dict(canvas.call("current_view_snapshot")).get("selected_info", {}))
			if not _array(panel.get("actions", [])).is_empty():
				result["actionable_objects"].append({"semantic_id": object_id, "actions": _array(panel.get("actions", [])).duplicate(true)})
	return result


func _depart_punchline(app: Control) -> Dictionary:
	var result := {"passed": false, "from": _current_visible_node_id(app), "to": ""}
	var canvas := app.get("environment_canvas") as Control
	var local_failures: Array = []
	var opened := Fidelity.push_exact_canvas_mouse_click(app.get_viewport(), canvas, "travel:leave", local_failures, "fix06_29 departure", true)
	await _settle(8)
	if not bool(opened.get("ok", false)):
		result["errors"] = local_failures
		return result
	var map := _dict(_dict(app.call("current_screen_snapshot")).get("world_map", {}))
	for node_id_value in _array(map.get("travel_enabled_node_ids", [])):
		var node_id := str(node_id_value)
		if node_id == str(result["from"]):
			continue
		if await _confirm_open_map_target(app, node_id):
			result["to"] = node_id
			result["passed"] = _current_visible_node_id(app) == node_id
			return result
	return result


func _room_has_object(app: Control, semantic_id: String) -> bool:
	var canvas := app.get("environment_canvas") as Control
	if canvas == null:
		return false
	for value in _array(_dict(canvas.call("current_view_snapshot")).get("objects", [])):
		if _object_id(_dict(value)) == semantic_id:
			return true
	return false


func _report_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			return argument.trim_prefix("--report=")
	return "res://.tmp/fix06_29_punchline_natural_l3_route.json"


func _finish() -> void:
	report["failures"] = failures.duplicate()
	report["passed"] = failures.is_empty()
	var report_path := _report_path()
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	call_deferred("_finish_after_cleanup", report_path)


func _finish_after_cleanup(report_path: String) -> void:
	# The production host tears down through queued UI cleanup. Let those nodes
	# finish a short, bounded frame window before engine leak diagnostics. The
	# verbose route proved there is no live owner; normal-speed shutdown needs
	# enough frames for the final zero-reference notification to drain as well.
	for _frame in range(12):
		await process_frame
	if failures.is_empty():
		print("FIX06_29_PUNCHLINE_NATURAL_L3 PASS favors=%d" % FAVOR_COMPLETIONS_REQUIRED)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("FIX06_29_PUNCHLINE_NATURAL_L3 FAIL failures=%d report=%s" % [failures.size(), report_path])
	quit(1)
