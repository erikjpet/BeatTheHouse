extends SceneTree

# Production-player proof for the Punchline interior route. Every transition is
# driven through a visible Control or an exact rendered semantic id with real
# viewport input. Seed search only chooses an ordinary run containing the public
# Parking Lot Tip; it does not alter run state or install a fixture.

const MainScene := preload("res://scenes/main.tscn")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const SaveServiceScript := preload("res://scripts/core/save_service.gd")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")

const SETTINGS_PATH := "user://fix06_28_punchline_route_settings.json"
const SEEDS := [
	"PUNCHLINE-PLAYER-00", "PUNCHLINE-PLAYER-01", "PUNCHLINE-PLAYER-02", "PUNCHLINE-PLAYER-03",
	"PUNCHLINE-PLAYER-04", "PUNCHLINE-PLAYER-05", "PUNCHLINE-PLAYER-06", "PUNCHLINE-PLAYER-07",
	"PUNCHLINE-PLAYER-08", "PUNCHLINE-PLAYER-09", "PUNCHLINE-PLAYER-10", "PUNCHLINE-PLAYER-11",
	"PUNCHLINE-PLAYER-12", "PUNCHLINE-PLAYER-13", "PUNCHLINE-PLAYER-14", "PUNCHLINE-PLAYER-15",
	"FIRST-NIGHT-ACE-17", "SCENARIO-AUDIT", "PLAYTEST-CATALOG-01",
]

var failures: Array[String] = []
var last_route_issue := ""
var last_start_issue := ""
var last_event_issue := ""
var last_layer_issue := ""
var report := {
	"schema_version": 1,
	"check_id": "fix06_28_punchline_player_route",
	"authority": {
		"host": "res://scenes/main.tscn",
		"targeting": "exact_rendered_semantic_id",
		"input": "Viewport.push_input(InputEventMouseButton)",
		"fixtures": false,
		"direct_host_actions": false,
	},
	"seed_attempts": [],
	"layers": [],
	"object_audits": [],
	"save_continue": [],
	"revisits": [],
	"l3_gate": {},
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, SETTINGS_PATH)
	var settings: UserSettings = UserSettingsScript.new()
	settings.reset()
	settings.save()
	var selected := await _ordinary_run_with_parking_tip()
	var app: Control = selected.get("app") as Control
	if app == null:
		_fail("No ordinary seeded production run exposed the Parking Lot Tip through the player route.")
		_finish()
		return
	report["seed"] = str(selected.get("seed", ""))

	if not await _choose_event(app, "event:parking_lot_tip", "parking_lot_tip", "follow_tip"):
		_fail("The exact Parking Lot Tip player route did not open The Punchline: %s" % last_event_issue)
		await _dispose(app)
		_finish()
		return
	if not _resolved_events_are_absent(app, "parking_lot_tip"):
		_fail("Resolved Parking Lot Tip remained as a visible generic event object.")
		await _dispose(app)
		_finish()
		return
	var post_tip_environment: Dictionary = (app.get("run_state") as RunState).current_environment
	report["post_tip_semantics"] = {
		"ready": bool(post_tip_environment.get("scenario_semantic_ready", false)),
		"errors": _array(post_tip_environment.get("scenario_sequence_lifecycle_errors", [])).duplicate(),
	}
	if not await _travel_to(app, "small_underground_casino"):
		report["punchline_route_issue"] = last_route_issue
		_fail("The player could not travel to the newly opened exact Punchline node: %s" % last_route_issue)
		await _dispose(app)
		_finish()
		return
	_record_layer(app, "club")
	await _audit_visible_layer_objects(app, "club")
	await _save_continue_same_layer(app, "club")

	if not await _choose_event(app, "event:side_door", "side_door", "punchline_password"):
		_fail("The exact Punchline Side Door player route did not open the hidden casino: %s" % last_event_issue)
		await _dispose(app)
		_finish()
		return
	if _has_object(app.get("environment_canvas") as Control, "event:side_door"):
		_fail("Resolved Side Door remained visible after entering the discovered room.")
		await _dispose(app)
		_finish()
		return
	_record_layer(app, "casino")
	await _audit_visible_layer_objects(app, "casino")
	await _save_continue_same_layer(app, "casino")

	if await _enter_layer(app, "club"):
		report["revisits"].append({"from": "casino", "to": "club", "passed": true})
		_record_layer(app, "club_revisit")
		if _has_object(app.get("environment_canvas") as Control, "event:side_door"):
			_fail("Resolved Side Door returned as a generic event object on layer revisit.")
		if await _enter_layer(app, "casino"):
			report["revisits"].append({"from": "club", "to": "casino", "passed": true})
		else:
			var revisit_environment: Dictionary = (app.get("run_state") as RunState).current_environment
			report["revisit_block"] = {
				"issue": last_layer_issue,
				"layer_discovery": _dict(revisit_environment.get("layer_discovery", {})),
				"layer_transitions": _array(revisit_environment.get("layer_transitions", [])).duplicate(true),
				"visible_layer_targets": _visible_layer_targets(app.get("environment_canvas") as Control),
			}
			_fail("Discovered Punchline casino did not remain a clickable exact layer target on revisit.")
	else:
		_fail("Punchline casino did not expose a clickable exact club revisit target.")

	var canvas := app.get("environment_canvas") as Control
	var back_room_visible := _has_object(canvas, "environment_layer:back_room")
	var back_room_entered := false
	if back_room_visible:
		back_room_entered = await _enter_layer(app, "back_room")
		if back_room_entered:
			_record_layer(app, "back_room")
			await _save_continue_same_layer(app, "back_room")
	report["l3_gate"] = {
		"back_room_target_visible": back_room_visible,
		"back_room_entered": back_room_entered,
		"player_rank_gate": "made Crew standing or Rook escort",
	}
	if not back_room_entered:
		report["l3_gate"]["follow_up"] = "Exercise the exact back-room route from a naturally earned made Crew standing or Rook escort save."
	await _dispose(app)
	_finish()


func _ordinary_run_with_parking_tip() -> Dictionary:
	var seeds := SEEDS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			seeds = [argument.trim_prefix("--seed=")]
			break
	if OS.get_cmdline_user_args().has("--single-seed"):
		seeds = [SEEDS[0]]
	for seed in seeds:
		var app := await _start_app(seed)
		if app == null:
			report["seed_attempts"].append({"seed": seed, "started": false, "start_issue": last_start_issue})
			continue
		var start_screen := _dict(app.call("current_screen_snapshot"))
		var start_map := _dict(start_screen.get("world_map", {}))
		var start_node := _current_node(app)
		var canvas := app.get("environment_canvas") as Control
		var had_departure := _has_object(canvas, "travel:leave")
		var at_corner := start_node == "corner_store" or await _travel_to(app, "corner_store", false)
		var has_tip := at_corner and _has_object(app.get("environment_canvas") as Control, "event:parking_lot_tip")
		report["seed_attempts"].append({"seed": seed, "started": true, "start_node": start_node, "selected_challenge": str(_dict(app.call("current_start_menu_snapshot")).get("selected_challenge_id", "")), "coach_visible": bool(_dict(start_screen.get("coach", {})).get("visible", false)), "event_popup_visible": bool(_dict(app.call("current_event_choice_popup_snapshot")).get("visible", false)), "initial_enabled_nodes": _array(start_map.get("travel_enabled_node_ids", [])).duplicate(), "travel_leave_visible": had_departure, "corner_store": at_corner, "parking_lot_tip": has_tip, "route_issue": last_route_issue})
		if has_tip:
			return {"app": app, "seed": seed}
		await _dispose(app)
	return {}


func _start_app(seed: String) -> Control:
	last_start_issue = ""
	var app := MainScene.instantiate() as Control
	app.set("continuous_environment_clock_enabled", false)
	var slot_id := "fix06_28_punchline_%s" % seed.to_lower().replace("-", "_")
	app.set("autosave_slot_id", slot_id)
	SaveServiceScript.new().clear_run(slot_id)
	root.add_child(app)
	await _settle(6)
	var setup := app.get("run_config_button") as Button
	if setup == null or not setup.is_visible_in_tree() or setup.disabled:
		last_start_issue = "run_setup_unavailable"
		await _dispose(app)
		return null
	await _click(app.get_viewport(), setup.get_global_rect().get_center())
	await _settle(4)
	# A fresh profile auto-starts the authored tutorial, whose coach intentionally
	# gates the first departure. Choose an ordinary visible challenge so this
	# remains a fresh, player-created run while exposing the normal world graph.
	var challenges := app.get("challenge_select_button") as Button
	if challenges == null or not challenges.is_visible_in_tree() or challenges.disabled:
		last_start_issue = "challenge_picker_unavailable"
		await _dispose(app)
		return null
	await _click(app.get_viewport(), challenges.get_global_rect().get_center())
	await _settle(4)
	var challenge_button_map: Dictionary = app.get("challenge_buttons") if typeof(app.get("challenge_buttons")) == TYPE_DICTIONARY else {}
	var dry_run := challenge_button_map.get("dry_run") as Button
	if dry_run == null:
		last_start_issue = "dry_run_option_unavailable"
		await _dispose(app)
		return null
	await _click(app.get_viewport(), dry_run.get_global_rect().get_center())
	await _settle(4)
	var seed_input := app.get("seed_input") as LineEdit
	var start := app.get("run_config_start_button") as Button
	if seed_input == null or start == null or not seed_input.is_visible_in_tree() or not start.is_visible_in_tree():
		last_start_issue = "run_config_controls_unavailable_after_challenge"
		await _dispose(app)
		return null
	await _replace_text(app.get_viewport(), seed_input, seed)
	await _click(app.get_viewport(), start.get_global_rect().get_center())
	await _settle(12)
	if str(_dict(app.call("current_screen_snapshot")).get("screen", "")) != "ENVIRONMENT":
		last_start_issue = "start_did_not_enter_environment:%s" % str(_dict(app.call("current_screen_snapshot")).get("screen", ""))
		await _dispose(app)
		return null
	return app


func _choose_event(app: Control, object_id: String, event_id: String, choice_id: String) -> bool:
	last_event_issue = ""
	var canvas := app.get("environment_canvas") as Control
	var local_failures: Array = []
	var routed := Fidelity.push_exact_canvas_mouse_click(app.get_viewport(), canvas, object_id, local_failures, "Punchline player event %s" % event_id)
	await _settle(4)
	if not bool(routed.get("ok", false)) or not Fidelity.exact_selection_matches(app, object_id):
		last_event_issue = "selection:%s" % JSON.stringify(local_failures)
		return false
	var selected_snapshot := _dict(canvas.call("current_view_snapshot"))
	var selected_info := _dict(selected_snapshot.get("selected_info", {}))
	var selected_actions := _array(selected_info.get("actions", []))
	var expected_response_id := "event_response:%s:%s" % [event_id, choice_id]
	var action_index := 0
	for index in range(selected_actions.size()):
		var action := _dict(selected_actions[index])
		if str(action.get("emit_object_id", "")) == expected_response_id:
			action_index = index
			break
	var local_position: Vector2 = canvas.call("local_position_for_selected_info_action_button", action_index)
	if local_position.x < 0.0:
		last_event_issue = "info_action_unavailable:%s" % JSON.stringify(selected_actions)
		return false
	await _click(app.get_viewport(), canvas.get_global_rect().position + local_position)
	await _settle(5)
	var popup := _dict(app.call("current_event_choice_popup_snapshot"))
	if not bool(popup.get("visible", false)) or str(popup.get("event_id", "")) != event_id:
		# Event response choices now live directly in the selected room tooltip.
		# Clicking the requested inline response can therefore resolve immediately
		# without opening the compatibility popup.
		if _event_choice_was_resolved(app, event_id, choice_id):
			return true
		last_event_issue = "popup:%s actions:%s resolved:%s layer:%s" % [
			JSON.stringify(popup),
			JSON.stringify(selected_actions),
			JSON.stringify(_array((app.get("run_state") as RunState).current_environment.get("resolved_event_ids", []))),
			str((app.get("run_state") as RunState).current_environment.get("current_layer_id", "")),
		]
		return false
	var label := ""
	for value in _array(popup.get("choices", [])):
		var choice := _dict(value)
		if str(choice.get("id", "")) == choice_id:
			label = str(choice.get("label", ""))
			break
	if label.is_empty():
		last_event_issue = "choice_missing:%s" % choice_id
		return false
	var button := _find_button(app.get("event_choice_popup_choices_list") as Node, label)
	if button == null:
		last_event_issue = "choice_button_missing:%s" % label
		return false
	await _click(app.get_viewport(), button.get_global_rect().get_center())
	await _settle(14)
	var completed := str(_dict(app.call("current_event_choice_popup_snapshot")).get("event_id", "")) != event_id
	if not completed:
		last_event_issue = str((app.get("message_label") as Label).text) if app.get("message_label") is Label else "event remained open"
	return completed


func _enter_layer(app: Control, layer_id: String) -> bool:
	last_layer_issue = ""
	var canvas := app.get("environment_canvas") as Control
	var semantic_id := "environment_layer:%s" % layer_id
	if not _has_object(canvas, semantic_id):
		last_layer_issue = "target_not_visible"
		return false
	var local_failures: Array = []
	var routed := Fidelity.push_exact_canvas_mouse_click(app.get_viewport(), canvas, semantic_id, local_failures, "Punchline layer %s" % layer_id)
	await _settle(4)
	if not bool(routed.get("ok", false)):
		last_layer_issue = "exact_click:%s" % JSON.stringify(local_failures)
		return false
	if not Fidelity.exact_selection_matches(app, semantic_id):
		last_layer_issue = "selection_mismatch"
		return false
	var local_position: Vector2 = canvas.call("local_position_for_selected_info_action_button")
	if local_position.x < 0.0:
		last_layer_issue = "action_button_unavailable"
		return false
	await _click(app.get_viewport(), canvas.get_global_rect().position + local_position)
	await _settle(14)
	if _current_layer(app) != layer_id:
		last_layer_issue = "action_not_committed:%s" % str((app.get("message_label") as Label).text) if app.get("message_label") is Label else "action_not_committed"
		return false
	return true


func _travel_to(app: Control, target_id: String, record_failure: bool = true) -> bool:
	last_route_issue = ""
	var visited_nodes := {_current_node(app): true}
	for leg in range(8):
		if _current_node(app) == target_id:
			return true
		var canvas := app.get("environment_canvas") as Control
		await _clear_room_focus(app, canvas)
		var local_failures: Array = []
		var routed := Fidelity.push_exact_canvas_mouse_click(app.get_viewport(), canvas, "travel:leave", local_failures, "Punchline route departure leg %d" % leg, true)
		await _settle(10)
		var screen := _dict(app.call("current_screen_snapshot"))
		if not bool(routed.get("ok", false)) or not bool(screen.get("world_map_overlay_visible", false)):
			last_route_issue = "departure:%s" % JSON.stringify(local_failures)
			if record_failure: _fail("Exact travel:leave did not open the production world map.")
			return false
		var map := _dict(screen.get("world_map", {}))
		var next_node := _best_enabled_step(map, target_id, visited_nodes)
		if next_node.is_empty():
			last_route_issue = "no_enabled_graph_step:%s" % target_id
			if record_failure: _fail("Production map exposed no enabled graph step toward exact node %s." % target_id)
			return false
		var node_button := _find_node_button(app, next_node)
		if node_button == null:
			last_route_issue = "enabled_button_missing:%s" % next_node
			return false
		await _click(app.get_viewport(), node_button.get_global_rect().get_center())
		# The map detail card is laid out after selection; wait for its production
		# confirm control to reach its final hit rectangle before clicking it.
		await _settle(10)
		var confirm := app.get("world_map_confirm_button") as Button
		if confirm == null or not confirm.is_visible_in_tree() or confirm.disabled:
			last_route_issue = "confirmation_disabled:%s" % next_node
			if record_failure: _fail("Exact node %s did not enable visible travel confirmation." % next_node)
			return false
		await _click(app.get_viewport(), confirm.get_global_rect().get_center())
		var arrived := await _wait_for_arrival(app, next_node, 240)
		if not arrived:
			var failed_screen := _dict(app.call("current_screen_snapshot"))
			var player_message := str((app.get("message_label") as Label).text) if app.get("message_label") is Label else ""
			last_route_issue = "arrival_not_committed:%s:at=%s:screen=%s:message=%s" % [next_node, _current_node(app), str(failed_screen.get("screen", "")), player_message]
			return false
		visited_nodes[next_node] = true
	last_route_issue = "graph_leg_budget:%s" % target_id
	return false


func _wait_for_arrival(app: Control, node_id: String, frame_budget: int = 240) -> bool:
	for _frame in range(frame_budget):
		var screen := _dict(app.call("current_screen_snapshot"))
		# RESULT is a non-modal presentation layer over the arrived room. There is
		# no shipped acknowledgement button; exact room objects remain the player's
		# route onward, so committed arrival is node identity plus a cleared travel
		# transition rather than an invented direct callback.
		if _current_node(app) == node_id and not bool(screen.get("travel_transition_active", false)):
			return true
		await process_frame
	return false


func _best_enabled_step(map: Dictionary, target_id: String, visited_nodes: Dictionary) -> String:
	var current := str(map.get("current_node_id", ""))
	var best := ""
	var first_enabled := ""
	var best_distance := 1000000
	for enabled_value in _array(map.get("travel_enabled_node_ids", [])):
		var enabled := str(enabled_value)
		if enabled.is_empty() or enabled == current:
			continue
		if first_enabled.is_empty() and not visited_nodes.has(enabled): first_enabled = enabled
		if enabled == target_id:
			return enabled
		var distance := _graph_distance(map, enabled, target_id)
		if distance >= 0 and distance < best_distance:
			best_distance = distance
			best = enabled
	# The player-facing map intentionally hides undiscovered nodes and their
	# connecting edges. When the target has no visible path yet, take a currently
	# enabled public route and re-evaluate from the arrived room.
	return best if not best.is_empty() else first_enabled


func _graph_distance(map: Dictionary, start_id: String, target_id: String) -> int:
	var frontier: Array = [start_id]
	var distance := {start_id: 0}
	while not frontier.is_empty():
		var current := str(frontier.pop_front())
		if current == target_id:
			return int(distance.get(current, 0))
		for edge_value in _array(map.get("edges", [])):
			var edge := _dict(edge_value)
			var a := str(edge.get("a", ""))
			var b := str(edge.get("b", ""))
			var neighbor := b if a == current else a if b == current else ""
			if neighbor.is_empty() or distance.has(neighbor):
				continue
			distance[neighbor] = int(distance.get(current, 0)) + 1
			frontier.append(neighbor)
	return -1


func _clear_room_focus(app: Control, canvas: Control) -> void:
	if canvas == null or not canvas.has_method("object_id_at_local_position"):
		return
	for local_position in [Vector2(8.0, 8.0), Vector2(canvas.size.x - 8.0, 8.0), Vector2(8.0, canvas.size.y - 8.0)]:
		if str(canvas.call("object_id_at_local_position", local_position)).is_empty():
			await _click(app.get_viewport(), canvas.get_global_rect().position + local_position)
			await _settle(4)
			await create_timer(0.2).timeout
			return


func _save_continue_same_layer(app: Control, layer_id: String) -> bool:
	var menu := app.get("top_menu_button") as Button
	if menu == null or not menu.is_visible_in_tree() or menu.disabled:
		_fail("Punchline %s did not expose the visible run menu." % layer_id)
		return false
	await _click(app.get_viewport(), menu.get_global_rect().get_center())
	await _settle(3)
	var save := app.get("run_menu_save_button") as Button
	var main_menu := app.get("run_menu_main_menu_button") as Button
	if save == null or main_menu == null or not save.is_visible_in_tree() or save.disabled:
		_fail("Punchline %s save controls were unavailable." % layer_id)
		return false
	await _click(app.get_viewport(), save.get_global_rect().get_center())
	await _settle(5)
	await _click(app.get_viewport(), main_menu.get_global_rect().get_center())
	await _settle(7)
	var continue_button := app.get("new_run_button") as Button
	if continue_button == null or continue_button.text != "CONTINUE" or continue_button.disabled:
		_fail("Punchline %s save did not expose visible CONTINUE." % layer_id)
		return false
	await _click(app.get_viewport(), continue_button.get_global_rect().get_center())
	await _settle(16)
	var passed := _current_node(app) == "small_underground_casino" and _current_layer(app) == layer_id
	report["save_continue"].append({"layer": layer_id, "passed": passed})
	if not passed: _fail("Visible Continue did not restore Punchline %s." % layer_id)
	return passed


func _record_layer(app: Control, label: String) -> void:
	var canvas := app.get("environment_canvas") as Control
	var snapshot := _dict(canvas.call("current_view_snapshot"))
	var environment: Dictionary = (app.get("run_state") as RunState).current_environment
	var layer_report := {
		"label": label,
		"layer_id": _current_layer(app),
		"art_key": str(snapshot.get("art_key", snapshot.get("environment_id", ""))),
		"object_count": _array(snapshot.get("objects", [])).size(),
		"scenario_semantic_ready": bool(environment.get("scenario_semantic_ready", false)),
		"scenario_lifecycle_errors": _array(environment.get("scenario_sequence_lifecycle_errors", [])).duplicate(true),
		"scenario_layout_audit": _dict(environment.get("scenario_layout_audit", {})),
	}
	if not _array(layer_report.get("scenario_lifecycle_errors", [])).is_empty():
		layer_report["object_layout_entries"] = _array(_dict(snapshot.get("object_layout", {})).get("objects", [])).duplicate(true)
	report["layers"].append(layer_report)


func _audit_visible_layer_objects(app: Control, label: String) -> bool:
	var canvas := app.get("environment_canvas") as Control
	var initial_snapshot := _dict(canvas.call("current_view_snapshot"))
	var object_layout := _dict(initial_snapshot.get("object_layout", {}))
	var overlap_count := maxi(0, int(object_layout.get("overlap_count", 0)))
	var object_ids: Array[String] = []
	var action_expected: Dictionary = {}
	var visible_count := 0
	var unavailable_count := 0
	var deferred_gate_count := 0
	var presentation_failure_errors: Array = []
	for value in _array(initial_snapshot.get("objects", [])):
		var object_data := _dict(value)
		var object_id := str(object_data.get("id", object_data.get("object_id", ""))).strip_edges()
		if object_id.is_empty() or not bool(object_data.get("visible", true)):
			continue
		if object_id == "scenario::presentation_failure":
			presentation_failure_errors = _array(object_data.get("scenario_projection_errors", [])).duplicate(true)
		visible_count += 1
		if label == "casino" and object_id == "environment_layer:back_room":
			# This target is intentionally reserved for the separately recorded L3
			# progression gate; this fresh-run route must not bypass or satisfy it.
			deferred_gate_count += 1
			continue
		if not bool(object_data.get("enabled", true)) or not bool(object_data.get("interactive", true)):
			unavailable_count += 1
			continue
		object_ids.append(object_id)
		action_expected[object_id] = bool(object_data.get("enabled", true)) and bool(object_data.get("interactive", true)) and (not _array(object_data.get("available_actions", [])).is_empty() or not str(object_data.get("confirm_action_id", "")).is_empty())
	var selected_count := 0
	var populated_panel_count := 0
	var action_panel_count := 0
	var audit_failures: Array[String] = []
	if overlap_count > 0:
		audit_failures.append("environment_plane_overlap:%d" % overlap_count)
	for object_id in object_ids:
		# Close the prior canvas-drawn info card before resolving the next exact
		# target; otherwise its action region can physically cover that target.
		await _clear_room_focus(app, canvas)
		var local_failures: Array = []
		var routed := Fidelity.resolve_exact_canvas_object(canvas, object_id, local_failures, "Punchline %s object audit" % label)
		if bool(routed.get("ok", false)):
			var local_position: Vector2 = routed.get("local_hit_position", Vector2(-1.0, -1.0))
			await _click(app.get_viewport(), canvas.get_global_rect().position + local_position)
		await _settle(3)
		var snapshot := _dict(canvas.call("current_view_snapshot"))
		var info := _dict(snapshot.get("selected_info", {}))
		var selected := bool(routed.get("ok", false)) and Fidelity.exact_selection_matches(app, object_id)
		if selected:
			selected_count += 1
		else:
			audit_failures.append("%s:selection" % object_id)
			continue
		var panel_populated := bool(info.get("visible", false)) and str(info.get("object_id", "")) == object_id and not str(info.get("title", "")).strip_edges().is_empty() and not _array(info.get("lines", [])).is_empty()
		if panel_populated:
			populated_panel_count += 1
		else:
			audit_failures.append("%s:panel" % object_id)
		if bool(info.get("action_available", false)):
			action_panel_count += 1
		elif bool(action_expected.get(object_id, false)):
			audit_failures.append("%s:action" % object_id)
	report["object_audits"].append({
		"layer": label,
		"visible": visible_count,
		"visible_unavailable": unavailable_count,
		"deferred_progression_gates": deferred_gate_count,
		"available_interactions": object_ids.size(),
		"selected": selected_count,
		"populated_panels": populated_panel_count,
		"action_panels": action_panel_count,
		"environment_plane_overlap_count": overlap_count,
		"environment_plane_overlaps": _array(object_layout.get("overlaps", [])).duplicate(true),
		"presentation_failure_errors": presentation_failure_errors,
		"failures": audit_failures.duplicate(),
	})
	if not audit_failures.is_empty():
		_fail("Punchline %s exact object/panel/action audit failed: %s" % [label, ", ".join(audit_failures)])
		return false
	return true


func _has_object(canvas: Control, semantic_id: String) -> bool:
	if canvas == null or not canvas.has_method("current_view_snapshot"):
		return false
	for value in _array(_dict(canvas.call("current_view_snapshot")).get("objects", [])):
		var object_data := _dict(value)
		if str(object_data.get("id", object_data.get("object_id", ""))) == semantic_id and bool(object_data.get("visible", true)):
			return true
	return false


func _resolved_events_are_absent(app: Control, expected_event_id: String) -> bool:
	var run: RunState = app.get("run_state") as RunState
	if run == null:
		return false
	var resolved := _array(run.current_environment.get("resolved_event_ids", []))
	if not resolved.has(expected_event_id):
		return false
	var canvas := app.get("environment_canvas") as Control
	for event_id_value in resolved:
		if _has_object(canvas, "event:%s" % str(event_id_value)):
			return false
	return true


func _event_choice_was_resolved(app: Control, event_id: String, choice_id: String) -> bool:
	var run: RunState = app.get("run_state") as RunState
	if run == null:
		return false
	for index in range(run.story_log.size() - 1, -1, -1):
		var entry := _dict(run.story_log[index])
		if str(entry.get("type", "")) != "event" or str(entry.get("event_id", "")) != event_id:
			continue
		return str(entry.get("choice_id", "")) == choice_id
	return false


func _visible_layer_targets(canvas: Control) -> Array:
	var result: Array = []
	if canvas == null or not canvas.has_method("current_view_snapshot"):
		return result
	for value in _array(_dict(canvas.call("current_view_snapshot")).get("objects", [])):
		var object_data := _dict(value)
		var object_id := str(object_data.get("id", object_data.get("object_id", "")))
		if object_id.begins_with("environment_layer:") and bool(object_data.get("visible", true)):
			result.append(object_id)
	return result


func _current_node(app: Control) -> String:
	return str(_dict(_dict(app.call("current_screen_snapshot")).get("world_map", {})).get("current_node_id", ""))


func _current_layer(app: Control) -> String:
	var run_state: RunState = app.get("run_state")
	return str(run_state.current_environment.get("current_layer_id", "")) if run_state != null else ""


func _find_node_button(node: Node, target_id: String) -> Button:
	if node is Button and node.is_visible_in_tree() and not (node as Button).disabled and str(node.get_meta("node_id", "")) == target_id:
		return node as Button
	for child in node.get_children():
		var found := _find_node_button(child, target_id)
		if found != null: return found
	return null


func _find_button(node: Node, label: String) -> Button:
	if node == null: return null
	if node is Button and node.is_visible_in_tree() and not (node as Button).disabled and (node as Button).text == label:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, label)
		if found != null: return found
	return null


func _replace_text(viewport: Viewport, input: LineEdit, value: String) -> void:
	await _click(viewport, input.get_global_rect().get_center())
	var select_all := InputEventKey.new()
	select_all.pressed = true
	select_all.ctrl_pressed = true
	select_all.keycode = KEY_A
	viewport.push_input(select_all, true)
	await process_frame
	select_all = select_all.duplicate()
	select_all.pressed = false
	viewport.push_input(select_all, true)
	var erase := InputEventKey.new()
	erase.pressed = true
	erase.keycode = KEY_BACKSPACE
	viewport.push_input(erase, true)
	await process_frame
	erase = erase.duplicate()
	erase.pressed = false
	viewport.push_input(erase, true)
	for character in value:
		var key := InputEventKey.new()
		key.pressed = true
		key.unicode = character.unicode_at(0)
		viewport.push_input(key, true)
		await process_frame
		key = key.duplicate()
		key.pressed = false
		viewport.push_input(key, true)


func _click(viewport: Viewport, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	viewport.push_input(motion, true)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	press.global_position = position
	viewport.push_input(press, true)
	await process_frame
	var release := press.duplicate()
	release.pressed = false
	viewport.push_input(release, true)
	await process_frame


func _settle(frames: int = 4) -> void:
	for _frame in range(frames): await process_frame


func _dispose(app: Control) -> void:
	if app != null and is_instance_valid(app): app.queue_free()
	await _settle(3)


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	report["failures"] = failures.duplicate()
	report["passed"] = failures.is_empty()
	print("FIX06_28_PUNCHLINE_PLAYER_ROUTE %s" % JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []
