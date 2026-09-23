extends SceneTree

const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const RoomActionListScript := preload("res://scripts/ui/room_action_list.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const ScenarioSemanticViewModelScript := preload("res://scripts/ui/scenario_semantic_view_model.gd")
const ScenarioSequenceProbeSupportScript := preload("res://tools/scenario_sequence_probe_support.gd")
const HarnessProductionFidelityScript := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")

var failures: Array[String] = []


class OverflowFoundationHost:
	extends FoundationMainScript

	var overflow_fixture_records: Array = []
	var use_overflow_fixture := false
	var delivery_exit_focus_routes := 0
	var delivery_exit_activation_routes := 0

	func _interactable_object_view_list() -> Array:
		if use_overflow_fixture:
			return overflow_fixture_records.duplicate(true)
		return super._interactable_object_view_list()

	func _on_environment_object_focused(object_id: String) -> void:
		if object_id == "scenario::delivery_exit":
			delivery_exit_focus_routes += 1
		super._on_environment_object_focused(object_id)

	func _on_environment_object_activated(object_id: String) -> void:
		if object_id == "scenario::delivery_exit":
			delivery_exit_activation_routes += 1
		super._on_environment_object_activated(object_id)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var app := OverflowFoundationHost.new()
	app.size = Vector2(1280.0, 720.0)
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	await _settle_frames(3)
	if not app.start_foundation_run("RW06-1-OVERFLOW-ACTIONS", {}, false):
		failures.append("RW06-1 overflow contract could not start its production Foundation run.")
		await _finish(app)
		return
	await _settle_frames(4)

	var production_record := _first_enabled_game_record(app.call("_interactable_object_view_list"))
	if production_record.is_empty():
		failures.append("RW06-1 overflow contract found no live production game action; a synthetic fallback is forbidden.")
		await _finish(app)
		return
	production_record["presentation_mode"] = "overflow"
	production_record["presentation_required"] = true
	production_record["visible"] = true
	production_record["focus_order"] = 10

	var disabled_record := {
		"object_id": "overflow_fixture:disabled",
		"object_type": "room",
		"label": "Locked fixture",
		"short_description": "A deliberately disabled action.",
		"presentation_mode": "overflow",
		"presentation_required": true,
		"visible": true,
		"interactive": true,
		"enabled": false,
		"disabled_reason": "Requires the brass key.",
		"focus_order": 20,
		"available_actions": [{"id": "unlock", "label": "Unlock"}],
	}
	var multi_record := {
		"object_id": "overflow_fixture:scenario",
		"object_type": "scenario",
		"label": "Scenario fixture",
		"short_description": "A mixed-source multi-action scenario record.",
		"presentation_mode": "overflow",
		"presentation_required": true,
		"visible": true,
		"interactive": true,
		"enabled": true,
		"focus_order": 30,
		"inline_actions": [
			{"id": "first", "emit_object_id": "overflow_fixture_action:first", "label": "First route"},
			{"id": "second", "emit_object_id": "overflow_fixture_action:second", "label": "Second route"},
			{"id": "secret", "emit_object_id": "overflow_fixture_action:secret", "label": "Secret route", "hidden": true},
		],
		"scenario_sequence_actions": [
			{"id": "sequence", "emit_object_id": "overflow_fixture_action:sequence", "label": "Sequence route"},
			{"id": "secret_sequence", "emit_object_id": "overflow_fixture_action:secret_sequence", "label": "Secret sequence", "presentation_visible": false},
		],
		"available_actions": [
			{"id": "available", "emit_object_id": "overflow_fixture_action:available", "label": "Available route"},
			{"id": "secret_available", "emit_object_id": "overflow_fixture_action:secret_available", "label": "Secret available", "hidden_only": true},
		],
	}
	var mirrored_record := {
		"object_id": "overflow_fixture:mirrored",
		"object_type": "scenario",
		"owner_namespace": "scenario",
		"stable_object_id": "mirrored_console",
		"label": "Mirrored authority fixture",
		"short_description": "The same command is projected through three source fields.",
		"presentation_mode": "overflow",
		"presentation_required": true,
		"visible": true,
		"interactive": true,
		"enabled": true,
		"focus_order": 35,
		"inline_actions": [{
			"id": "mirrored",
			"scenario_command_id": "mirrored",
			"scenario_owner_namespace": "scenario",
			"scenario_stable_object_id": "mirrored_console",
			"emit_object_id": "scenario_action:4:scenario:mirrored_console:mirrored",
			"label": "Mirrored inline route",
		}],
		"scenario_sequence_actions": [{
			"id": "mirrored",
			"scenario_owner_namespace": "scenario",
			"scenario_stable_object_id": "mirrored_console",
			"label": "Mirrored sequence route",
		}],
		"available_actions": [
			{
				"id": "mirrored",
				"scenario_owner_namespace": "scenario",
				"scenario_stable_object_id": "mirrored_console",
				"label": "Mirrored available route",
			},
			{
				"id": "distinct_later",
				"scenario_owner_namespace": "scenario",
				"scenario_stable_object_id": "mirrored_console",
				"label": "Distinct later route",
			},
		],
	}
	var information_record := {
		"object_id": "overflow_fixture:information",
		"object_type": "scenario_scene_object",
		"label": "Read-only fixture",
		"presentation_mode": "overflow",
		"presentation_required": true,
		"visible": true,
		"interactive": false,
		"enabled": true,
		"disabled_reason": "Nothing to do here right now.",
		"focus_order": 40,
		"available_actions": [],
	}
	var hidden_record := {
		"object_id": "overflow_fixture:hidden_action",
		"object_type": "scenario",
		"label": "Hidden-action fixture",
		"presentation_mode": "overflow",
		"presentation_required": true,
		"visible": true,
		"interactive": true,
		"enabled": true,
		"focus_order": 50,
		"inline_actions": [{
			"id": "hidden_only_action",
			"emit_object_id": "overflow_fixture_action:hidden_only",
			"label": "Hidden only action",
			"hidden": true,
		}],
	}
	var records: Array = [production_record, disabled_record, multi_record, mirrored_record, information_record, hidden_record]
	app.overflow_fixture_records = records.duplicate(true)
	app.use_overflow_fixture = true
	var action_list = app.get("room_action_list")
	if action_list == null:
		failures.append("RW06-1 production Foundation host did not mount RoomActionList.")
		await _finish(app)
		return
	var production_handler := Callable(app, "_activate_overflow_room_action")
	if not bool(action_list.call("has_action_dispatcher")) \
			or not bool(action_list.call("action_dispatcher_matches", production_handler)):
		failures.append("RW06-1 production Foundation builder did not configure the fail-closed live overflow dispatcher.")
	var activations: Array[String] = []
	action_list.action_selected.connect(func(_record: Dictionary, action: Dictionary) -> void:
		activations.append(_activation_key(action))
	)
	action_list.render(records)
	await _settle_frames(2)

	_check_dispatch_source_placement()
	_check_rendered_action_surface(action_list, records)
	_check_source_aggregation_and_dedupe(multi_record, mirrored_record)
	_check_action_key_authority_seal()
	_check_canvas_exclusion(records)
	await _check_cancel_and_focus_recovery(action_list)
	await _check_responsive_panel_width(action_list)
	await _check_refresh_focus_recovery(app, action_list, records)
	for mode in ["mouse", "touch", "keyboard", "controller"]:
		await _check_rejected_actions_for_mode(app, action_list, disabled_record, hidden_record, activations, str(mode))
	await _check_downstream_rejection_reopens(app, action_list, activations)

	var baseline_run_snapshot: Dictionary = app.get("run_state").to_dict()
	var delivery_setup := await _install_delivery_day(app, action_list)
	if bool(delivery_setup.get("ok", false)):
		var arrival_snapshot := (delivery_setup.get("arrival_snapshot", {}) as Dictionary).duplicate(true)
		await _check_background_pointer_shield(app, action_list, arrival_snapshot, "mouse")
		await _check_background_pointer_shield(app, action_list, arrival_snapshot, "touch")
		await _check_stale_authority_rejection(app, action_list, arrival_snapshot, activations)
		await _check_inline_scenario_mutation(app, action_list, arrival_snapshot, activations)
		await _check_sequence_scenario_mutation(app, action_list, arrival_snapshot, activations)
	await _restore_run(app, action_list, baseline_run_snapshot)
	for mode in ["mouse", "touch", "keyboard", "controller"]:
		await _check_production_mutation_for_mode(app, action_list, production_record, activations, str(mode))
	await _finish(app)


func _check_rendered_action_surface(action_list: Control, records: Array) -> void:
	var action_sources: Dictionary = {}
	var represented_records: Dictionary = {}
	var disabled_button: Button = null
	var information_button: Button = null
	for button_value in action_list.find_children("*", "Button", true, false):
		var button := button_value as Button
		if button.custom_minimum_size.x < 44.0 or button.custom_minimum_size.y < 44.0:
			failures.append("RW06-1 overflow target is smaller than 44x44: %s." % button.text)
		var object_id := str(button.get_meta("object_id", ""))
		var action_id := str(button.get_meta("action_id", ""))
		if not object_id.is_empty():
			represented_records[object_id] = true
		if not action_id.is_empty():
			action_sources[action_id] = str(button.get_meta("action_source", ""))
		if object_id == "overflow_fixture:disabled":
			disabled_button = button
		elif object_id == "overflow_fixture:information":
			information_button = button
	for record_value in records:
		var object_id := str((record_value as Dictionary).get("object_id", ""))
		if not represented_records.has(object_id):
			failures.append("RW06-1 visible overflow record has no rendered row: %s." % object_id)
	var expected_sources := {
		"overflow_fixture_action:first": RoomActionListScript.SOURCE_INLINE,
		"overflow_fixture_action:second": RoomActionListScript.SOURCE_INLINE,
		"overflow_fixture_action:sequence": RoomActionListScript.SOURCE_SEQUENCE,
		"overflow_fixture_action:available": RoomActionListScript.SOURCE_AVAILABLE,
		"scenario_action:4:scenario:mirrored_console:mirrored": RoomActionListScript.SOURCE_INLINE,
		"distinct_later": RoomActionListScript.SOURCE_AVAILABLE,
	}
	for action_id in expected_sources:
		if str(action_sources.get(action_id, "")) != str(expected_sources[action_id]):
			failures.append("RW06-1 mixed-source action %s was omitted or attributed to the wrong source: %s." % [action_id, action_sources])
	for hidden_id in [
		"overflow_fixture_action:secret",
		"overflow_fixture_action:secret_sequence",
		"overflow_fixture_action:secret_available",
		"overflow_fixture_action:hidden_only",
	]:
		if action_sources.has(hidden_id):
			failures.append("RW06-1 overflow list exposed hidden action %s." % hidden_id)
	if disabled_button == null or not disabled_button.disabled \
			or not disabled_button.text.contains("Requires the brass key.") \
			or not disabled_button.tooltip_text.contains("Requires the brass key."):
		failures.append("RW06-1 disabled overflow action does not visibly explain why it is unavailable.")
	if information_button == null or not information_button.disabled:
		failures.append("RW06-1 actionless visible overflow record was omitted or remained actionable.")


func _check_dispatch_source_placement() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/foundation_main.gd")
	var blocking_body := _source_function_body(source, "_blocking_modal_message")
	var slot_body := _source_function_body(source, "_main_floor_slot_game_id")
	var talk_body := _source_function_body(source, "_talk_dock_input_is_blocked")
	var dispatch_body := _source_function_body(source, "_activate_overflow_room_action")
	if source.count("Close Room actions before doing anything else.") != 1 \
			or not blocking_body.contains("Close Room actions before doing anything else.") \
			or slot_body.contains("Close Room actions"):
		failures.append("RW06-1 RoomActionList modal guard is not confined to _blocking_modal_message().")
	if not talk_body.contains("room_action_list") or not talk_body.contains("is_open"):
		failures.append("RW06-1 TalkDock's separate input route is not blocked while RoomActionList is open.")
	var sequence_index := dispatch_body.find("SOURCE_SEQUENCE")
	var explicit_index := dispatch_body.find("var explicit_scenario_command_id")
	var route_index := dispatch_body.find("var route_as_scenario")
	var id_fallback_index := dispatch_body.find("scenario_command_id = str(live_action.get(\"id\", \"\"))")
	var scenario_index := dispatch_body.find("elif route_as_scenario")
	var game_hook_index := dispatch_body.find("elif object_type == CONTEXT_MODE_GAME_HOOK")
	var emit_index := dispatch_body.find("var emit_object_id")
	if sequence_index < 0 or explicit_index < 0 or route_index < 0 or id_fallback_index < 0 \
			or scenario_index < 0 or game_hook_index < 0 or emit_index < 0 \
			or explicit_index > route_index or route_index > id_fallback_index \
			or sequence_index > scenario_index or scenario_index > game_hook_index or game_hook_index > emit_index \
			or dispatch_body.contains("live_action.get(\"id\", object_data.get(\"scenario_command_id\""):
		failures.append("RW06-1 overflow dispatch no longer prioritizes sequence/scenario authority over generic emit tokens.")


func _check_source_aggregation_and_dedupe(multi_record: Dictionary, mirrored_record: Dictionary) -> void:
	var distinct_entries := RoomActionListScript.action_entries_for_record(multi_record)
	var distinct_sources: Array = []
	for entry_value in distinct_entries:
		distinct_sources.append(str((entry_value as Dictionary).get("_overflow_source", "")))
	if distinct_entries.size() != 4 \
			or distinct_sources != [
				RoomActionListScript.SOURCE_INLINE,
				RoomActionListScript.SOURCE_INLINE,
				RoomActionListScript.SOURCE_SEQUENCE,
				RoomActionListScript.SOURCE_AVAILABLE,
			]:
		failures.append("RW06-1 distinct mixed-source actions were collapsed or reordered: %s." % JSON.stringify(distinct_sources))
	var mirrored_entries := RoomActionListScript.action_entries_for_record(mirrored_record)
	if mirrored_entries.size() != 2:
		failures.append("RW06-1 mirrored command did not collapse to one row while retaining its distinct later-source action: %s." % JSON.stringify(mirrored_entries))
		return
	var mirrored := mirrored_entries[0] as Dictionary
	var distinct := mirrored_entries[1] as Dictionary
	if str(mirrored.get("_overflow_source", "")) != RoomActionListScript.SOURCE_INLINE \
			or str(mirrored.get("scenario_command_id", mirrored.get("id", ""))) != "mirrored" \
			or str(distinct.get("_overflow_source", "")) != RoomActionListScript.SOURCE_AVAILABLE \
			or str(distinct.get("id", "")) != "distinct_later":
		failures.append("RW06-1 mirrored-command dedupe lost deterministic first-source precedence: %s." % JSON.stringify(mirrored_entries))
	var blank_optional_record := {
		"object_id": "scenario::blank_optional",
		"object_type": "scenario",
		"owner_namespace": "scenario",
		"stable_object_id": "blank_optional",
		"inline_actions": [
			{"id": "first_valid_id", "emit_object_id": "", "scenario_command_id": ""},
			{"id": "second_valid_id", "emit_object_id": "", "scenario_command_id": ""},
		],
	}
	var blank_optional_entries := RoomActionListScript.action_entries_for_record(blank_optional_record)
	if blank_optional_entries.size() != 2:
		failures.append("RW06-1 blank optional emit/command fields hid or collapsed valid distinct action ids.")


func _check_action_key_authority_seal() -> void:
	var action := {
		"id": "prepare",
		"scenario_command_id": "prepare",
		"scenario_owner_namespace": "scenario",
		"scenario_stable_object_id": "console",
		"scenario_idempotency_key": "ui:3:scenario:console:prepare",
		"action_origin_owner_namespace": "scenario",
		"action_origin_stable_object_id": "console",
		"action_origin_receipt_key": "receipt:prepare",
		"action_origin_boundary_id": "arrival:3",
		"action_origin_fingerprint": "a".repeat(64),
		"world_sequence_owner_token": "world:owner:3",
	}
	var record := {
		"object_id": "scenario::console",
		"object_type": "scenario_sequence",
		"owner_namespace": "scenario",
		"stable_object_id": "console",
		"enabled": true,
		"interactive": true,
		"scenario_sequence_actions": [action],
	}
	var baseline_entries := RoomActionListScript.action_entries_for_record(record)
	if baseline_entries.size() != 1:
		failures.append("RW06-1 authority-seal fixture could not produce its baseline action.")
		return
	var baseline_key := str((baseline_entries[0] as Dictionary).get("_overflow_action_key", ""))
	for field_value in [
		"scenario_owner_namespace",
		"scenario_stable_object_id",
		"scenario_command_id",
		"scenario_idempotency_key",
		"action_origin_owner_namespace",
		"action_origin_stable_object_id",
		"action_origin_receipt_key",
		"action_origin_boundary_id",
		"action_origin_fingerprint",
		"world_sequence_owner_token",
	]:
		var changed_record := record.duplicate(true)
		var changed_actions := (changed_record.get("scenario_sequence_actions", []) as Array).duplicate(true)
		var changed_action := (changed_actions[0] as Dictionary).duplicate(true)
		changed_action[str(field_value)] = "%s_changed" % str(changed_action.get(str(field_value), "authority"))
		changed_actions[0] = changed_action
		changed_record["scenario_sequence_actions"] = changed_actions
		var changed_entries := RoomActionListScript.action_entries_for_record(changed_record)
		if changed_entries.size() != 1 \
				or str((changed_entries[0] as Dictionary).get("_overflow_action_key", "")) == baseline_key:
			failures.append("RW06-1 overflow action key did not seal %s." % str(field_value))
	for record_field_value in ["owner_namespace", "stable_object_id"]:
		var changed_record := record.duplicate(true)
		changed_record[str(record_field_value)] = "%s_changed" % str(changed_record.get(str(record_field_value), "authority"))
		var changed_entries := RoomActionListScript.action_entries_for_record(changed_record)
		if changed_entries.size() != 1 \
				or str((changed_entries[0] as Dictionary).get("_overflow_action_key", "")) == baseline_key:
			failures.append("RW06-1 overflow action key did not seal record %s." % str(record_field_value))


func _check_canvas_exclusion(records: Array) -> void:
	var canvas := PixelSceneCanvasScript.new()
	canvas.size = Vector2(900.0, 430.0)
	root.add_child(canvas)
	canvas.render_environment_snapshot({
		"id": "rw06_1_overflow_contract",
		"archetype_id": "bar",
		"interactable_objects": records,
	})
	for object_value in canvas.current_view_snapshot().get("objects", []):
		if str((object_value as Dictionary).get("presentation_mode", "room")) == "overflow":
			failures.append("RW06-1 PixelSceneCanvas rendered an overflow-only action record.")
			break
	canvas.queue_free()


func _check_cancel_and_focus_recovery(action_list: Control) -> void:
	var launcher := _launcher_button(action_list)
	action_list.open()
	await process_frame
	_send_key(KEY_ESCAPE)
	await _settle_frames(2)
	if bool(action_list.call("is_open")):
		failures.append("RW06-1 ui_cancel did not close the overflow modal.")
	if launcher == null or root.gui_get_focus_owner() != launcher:
		failures.append("RW06-1 overflow cancel did not restore focus to its launcher.")


func _check_responsive_panel_width(action_list: Control) -> void:
	var original_size := root.size
	root.size = Vector2i(320, 360)
	await _settle_frames(3)
	action_list.open()
	await _settle_frames(2)
	var overlay := action_list.get("_overlay") as Control
	var panel := action_list.get("_panel") as Control
	if overlay == null or panel == null \
			or panel.custom_minimum_size.x > 288.0 \
			or panel.size.x > 288.0 \
			or not overlay.get_global_rect().encloses(panel.get_global_rect()):
		failures.append("RW06-1 compact action panel overflows a 320px-wide viewport.")
	action_list.close()
	root.size = original_size
	await _settle_frames(3)


func _check_refresh_focus_recovery(app: Control, action_list: Control, records: Array) -> void:
	action_list.open()
	await process_frame
	var second := _action_button(action_list, "overflow_fixture_action:second")
	if second == null:
		failures.append("RW06-1 refresh-focus check could not find the second scenario action.")
		action_list.close()
		return
	second.grab_focus()
	await process_frame
	var refreshed := records.duplicate(true)
	var refreshed_multi := (refreshed[2] as Dictionary).duplicate(true)
	var refreshed_inline := (refreshed_multi.get("inline_actions", []) as Array).duplicate(true)
	var refreshed_second := (refreshed_inline[1] as Dictionary).duplicate(true)
	refreshed_second["label"] = "Second route refreshed"
	refreshed_inline[1] = refreshed_second
	refreshed_multi["inline_actions"] = refreshed_inline
	refreshed[2] = refreshed_multi
	app.set("overflow_fixture_records", refreshed.duplicate(true))
	action_list.render(refreshed)
	await _settle_frames(2)
	var replacement := _action_button(action_list, "overflow_fixture_action:second")
	if replacement == null or root.gui_get_focus_owner() != replacement:
		failures.append("RW06-1 overflow refresh did not preserve semantic action focus.")
	action_list.close()
	app.set("overflow_fixture_records", records.duplicate(true))
	action_list.render(records)
	await process_frame


func _install_delivery_day(app: Control, action_list: Control) -> Dictionary:
	action_list.close()
	action_list.render([])
	app.set("use_overflow_fixture", false)
	app.set("interactable_object_view_cache_valid", false)
	var library: Variant = app.get("library")
	var run_state: Variant = app.get("run_state")
	var definition: Dictionary = library.call("scenario", ScenarioSequenceProbeSupportScript.SCENARIO_ID) if library != null else {}
	var archetype: Dictionary = library.call("environment_archetype", ScenarioSequenceProbeSupportScript.ARCHETYPE_ID) if library != null else {}
	if run_state == null or definition.is_empty() or archetype.is_empty():
		failures.append("RW06-1 could not load the shipped delivery-day scenario and corner-store archetype.")
		return {"ok": false}
	var rng: Variant = run_state.call("create_rng", "rw06_1:delivery-day-overflow")
	var environment: Variant = EnvironmentInstanceScript.from_archetype(archetype, 1, rng, library, {}, definition)
	if environment == null:
		failures.append("RW06-1 could not instantiate the shipped delivery-day environment.")
		return {"ok": false}
	var data: Dictionary = environment.call("to_dict")
	data["world_node_id"] = ScenarioSequenceProbeSupportScript.NODE_ID
	var generator := RunGeneratorScript.new(library)
	data["game_states"] = generator.call("_generated_game_states", run_state, data, rng)
	data["layout"] = EnvironmentInstanceScript.ensure_generated_layout(data)
	var proof_map: Dictionary = (run_state.get("world_map") as Dictionary).duplicate(true)
	var proof_nodes: Array = (proof_map.get("nodes", []) as Array).duplicate(true)
	var proof_node: Dictionary = {}
	for node_value in proof_nodes:
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node := node_value as Dictionary
		if str(node.get("id", "")) == ScenarioSequenceProbeSupportScript.ARCHETYPE_ID:
			proof_node = node.duplicate(true)
			break
	if proof_node.is_empty():
		failures.append("RW06-1 production world map has no corner-store node for the delivery-day fixture.")
		return {"ok": false}
	proof_node["id"] = ScenarioSequenceProbeSupportScript.NODE_ID
	proof_node["environment"] = {}
	proof_nodes.append(proof_node)
	proof_map["nodes"] = proof_nodes
	proof_map["current_node_id"] = ScenarioSequenceProbeSupportScript.NODE_ID
	run_state.set("current_environment", {})
	run_state.set("world_map", proof_map)
	if not bool(run_state.call("seed_scenario_for_node", ScenarioSequenceProbeSupportScript.NODE_ID, definition)):
		failures.append("RW06-1 production RunState rejected the shipped delivery-day scenario seed.")
		return {"ok": false}
	var installation: Dictionary = run_state.call("set_environment", data)
	if not bool(installation.get("ok", false)):
		failures.append("RW06-1 production RunState rejected the delivery-day environment: %s." % JSON.stringify(installation.get("errors", [])))
		return {"ok": false}
	app.call("_clear_selected_game_action")
	app.call("_refresh")
	await _settle_frames(6)
	var projection: Dictionary = run_state.call("scenario_sequence_projection")
	if str(projection.get("scenario_id", "")) != ScenarioSequenceProbeSupportScript.SCENARIO_ID \
			or str(projection.get("phase_id", "")) != "arrival":
		failures.append("RW06-1 shipped delivery-day scenario did not finalize at arrival: %s." % JSON.stringify(projection))
		return {"ok": false}
	var live_records := _current_interactable_records(app)
	if _record_by_object_id(live_records, "scenario::delivery_event_gate").is_empty() \
			or _record_by_object_id(live_records, "scenario::delivery_exit").is_empty():
		failures.append("RW06-1 shipped delivery-day obstruction records are unavailable after finalization.")
		return {"ok": false}
	return {
		"ok": true,
		"arrival_snapshot": run_state.to_dict(),
		"live_records": live_records,
	}


func _restore_run(app: Control, action_list: Control, snapshot: Dictionary) -> void:
	action_list.close()
	app.set("use_overflow_fixture", false)
	app.set("interactable_object_view_cache_valid", false)
	var run_state: Variant = app.get("run_state")
	if run_state != null:
		run_state.from_dict(snapshot.duplicate(true))
	app.call("_clear_selected_game_action")
	app.call("_refresh")
	await _settle_frames(5)


func _check_background_pointer_shield(app: Control, action_list: Control, arrival_snapshot: Dictionary, mode: String) -> void:
	await _restore_run(app, action_list, arrival_snapshot)
	var live_records := _current_interactable_records(app)
	var gate := _record_by_object_id(live_records, "scenario::delivery_event_gate")
	var exit_record := _record_by_object_id(live_records, "scenario::delivery_exit")
	if gate.is_empty() or exit_record.is_empty():
		failures.append("RW06-1 %s background shield check lost a shipped delivery obstruction." % mode)
		return
	gate = _as_overflow_record(gate, 1)
	for index in range(live_records.size()):
		if str((live_records[index] as Dictionary).get("object_id", "")) == "scenario::delivery_event_gate":
			live_records[index] = gate
			break
	_install_fixture_records(app, action_list, live_records)
	await _settle_frames(2)
	var canvas: Control = app.get("environment_canvas") as Control
	var resolved := HarnessProductionFidelityScript.resolve_exact_canvas_object(
		canvas,
		"scenario::delivery_exit",
		failures,
		"RW06-1 %s modal background shield" % mode
	)
	if not bool(resolved.get("ok", false)):
		return
	var local_position: Vector2 = resolved.get("local_hit_position", Vector2(-1.0, -1.0))
	var global_position := canvas.get_global_transform_with_canvas() * local_position
	var control_focus_count := int(app.get("delivery_exit_focus_routes"))
	match mode:
		"mouse":
			HarnessProductionFidelityScript.push_exact_canvas_mouse_click(
				root,
				canvas,
				"scenario::delivery_exit",
				failures,
				"RW06-1 mouse background live control",
				false
			)
		"touch":
			_send_touch(global_position)
	await _settle_frames(3)
	if int(app.get("delivery_exit_focus_routes")) != control_focus_count + 1:
		failures.append("RW06-1 %s live control did not route to the real delivery-exit canvas target." % mode)
	await create_timer(0.45).timeout
	action_list.open()
	await _settle_frames(2)
	var first_action := _first_enabled_action_button(action_list)
	if first_action != null:
		first_action.grab_focus()
	await process_frame
	var overlay := action_list.get("_overlay") as Control
	var panel := action_list.get("_panel") as Control
	if overlay == null or not overlay.get_global_rect().has_point(global_position):
		failures.append("RW06-1 %s shield does not cover the real delivery-exit hit point." % mode)
	if panel != null and panel.get_global_rect().has_point(global_position):
		failures.append("RW06-1 %s shield fixture did not exercise a point outside the compact action panel." % mode)
	var before := _mutation_snapshot(app)
	var before_focus_routes := int(app.get("delivery_exit_focus_routes"))
	var before_activation_routes := int(app.get("delivery_exit_activation_routes"))
	match mode:
		"mouse":
			HarnessProductionFidelityScript.push_exact_canvas_mouse_click(
				root,
				canvas,
				"scenario::delivery_exit",
				failures,
				"RW06-1 mouse modal background shield",
				true
			)
		"touch":
			_send_touch(global_position, true)
	await _settle_frames(4)
	var focus_owner := root.gui_get_focus_owner()
	if _mutation_snapshot(app) != before \
			or int(app.get("delivery_exit_focus_routes")) != before_focus_routes \
			or int(app.get("delivery_exit_activation_routes")) != before_activation_routes \
			or not bool(action_list.call("is_open")) \
			or overlay == null \
			or focus_owner == null \
			or not overlay.is_ancestor_of(focus_owner):
		failures.append("RW06-1 %s escaped the full-screen modal shield or mutated the real delivery exit." % mode)
	if str(app.call("_blocking_modal_message")) != "Close Room actions before doing anything else.":
		failures.append("RW06-1 %s modal did not own the production input guard while open." % mode)
	action_list.close()
	await create_timer(0.45).timeout


func _check_stale_authority_rejection(app: Control, action_list: Control, arrival_snapshot: Dictionary, activations: Array[String]) -> void:
	await _restore_run(app, action_list, arrival_snapshot)
	var gate := _record_by_object_id(_current_interactable_records(app), "scenario::delivery_event_gate")
	if gate.is_empty():
		failures.append("RW06-1 stale-authority check could not find the shipped inspect_manifest record.")
		return
	gate = _as_overflow_record(gate, 1)
	_install_fixture_records(app, action_list, [gate])
	await _settle_frames(2)
	var entries := RoomActionListScript.action_entries_for_record(gate)
	if entries.size() != 1:
		failures.append("RW06-1 stale-authority check expected one deduplicated shipped action: %s." % JSON.stringify(entries))
		return
	var stale_action := (entries[0] as Dictionary).duplicate(true)
	action_list.open()
	await process_frame
	var stale_button := _action_button_by_key(action_list, str(stale_action.get("_overflow_action_key", "")))
	if stale_button == null:
		failures.append("RW06-1 stale-authority check could not find its rendered action snapshot.")
		action_list.close()
		return
	stale_button.grab_focus()
	var changed_gate := gate.duplicate(true)
	var changed_actions := (changed_gate.get("scenario_sequence_actions", []) as Array).duplicate(true)
	var changed_action := (changed_actions[0] as Dictionary).duplicate(true)
	changed_action["action_origin_stable_object_id"] = "delivery_exit"
	changed_action["action_origin_fingerprint"] = "0".repeat(64)
	changed_actions[0] = changed_action
	changed_gate["scenario_sequence_actions"] = changed_actions
	_install_fixture_records(app, null, [changed_gate])
	var before := _mutation_snapshot(app)
	var activation_count := activations.size()
	_send_mouse(stale_button.get_global_rect().get_center())
	await _settle_frames(3)
	var direct_result := bool(app.call("_activate_overflow_room_action", gate, stale_action))
	var overlay := action_list.get("_overlay") as Control
	var focus_owner := root.gui_get_focus_owner()
	if direct_result \
			or activations.size() != activation_count \
			or _mutation_snapshot(app) != before \
			or not bool(action_list.call("is_open")) \
			or overlay == null \
			or focus_owner == null \
			or not overlay.is_ancestor_of(focus_owner):
		failures.append("RW06-1 same-ID changed-origin action did not reject byte-stably with its modal/focus intact.")
	action_list.close()


func _check_inline_scenario_mutation(app: Control, action_list: Control, arrival_snapshot: Dictionary, activations: Array[String]) -> void:
	await _restore_run(app, action_list, arrival_snapshot)
	var run_state: Variant = app.get("run_state")
	var projection: Dictionary = run_state.call("scenario_sequence_projection")
	var semantic := projection.get("semantic_state", {}) as Dictionary
	var interaction := (semantic.get("interactions", {}) as Dictionary).get("scenario::delivery_event_gate", {}) as Dictionary
	var visual := (semantic.get("scene_objects", {}) as Dictionary).get("scenario::delivery_event_gate", {}) as Dictionary
	var inline_record := ScenarioSemanticViewModelScript._scenario_record(
		interaction,
		visual,
		{},
		int(projection.get("boundary_serial", 0))
	)
	if inline_record.is_empty():
		failures.append("RW06-1 could not derive the shipping compatibility inline record.")
		return
	inline_record = _as_overflow_record(inline_record, 1)
	var authentic_entries := RoomActionListScript.action_entries_for_record(inline_record)
	if authentic_entries.size() != 1 \
			or str((authentic_entries[0] as Dictionary).get("_overflow_source", "")) != RoomActionListScript.SOURCE_INLINE:
		failures.append("RW06-1 shipping inline+available projection did not dedupe to SOURCE_INLINE: %s." % JSON.stringify(authentic_entries))
		return
	# Compatibility actions can be attached to a base/game record. The sealed
	# scenario_command_id, not this presentation type, owns their dispatch.
	inline_record["object_type"] = "game"
	inline_record["available_actions"] = []
	_install_fixture_records(app, action_list, [inline_record])
	await _settle_frames(2)
	var entries := RoomActionListScript.action_entries_for_record(inline_record)
	if entries.size() != 1 or str((entries[0] as Dictionary).get("_overflow_source", "")) != RoomActionListScript.SOURCE_INLINE:
		failures.append("RW06-1 shipping compatibility action did not remain SOURCE_INLINE: %s." % JSON.stringify(entries))
		return
	var action := entries[0] as Dictionary
	if str(inline_record.get("object_type", "")) == "scenario" \
			or str(action.get("scenario_command_id", "")).strip_edges().is_empty():
		failures.append("RW06-1 compatibility fixture does not prove explicit scenario authority on a non-scenario record.")
		return
	var expected_key := _activation_key(action)
	var prior_count := activations.count(expected_key)
	var before_receipts := _scenario_command_receipt_count(run_state)
	action_list.open()
	await process_frame
	var button := _action_button_by_key(action_list, str(action.get("_overflow_action_key", "")))
	if button == null:
		failures.append("RW06-1 shipping inline scenario action was not rendered.")
		action_list.close()
		return
	_send_mouse(button.get_global_rect().get_center())
	await _settle_frames(6)
	var after_projection: Dictionary = run_state.call("scenario_sequence_projection")
	if str(after_projection.get("phase_id", "")) != "sorting" \
			or _scenario_command_receipt_count(run_state) != before_receipts + 1 \
			or activations.count(expected_key) != prior_count + 1 \
			or bool(action_list.call("is_open")):
		failures.append("RW06-1 shipping tokenized inline action did not reach the real arrival-to-sorting mutation.")


func _check_sequence_scenario_mutation(app: Control, action_list: Control, arrival_snapshot: Dictionary, activations: Array[String]) -> void:
	await _restore_run(app, action_list, arrival_snapshot)
	var run_state: Variant = app.get("run_state")
	var sequence_record := _record_by_object_id(_current_interactable_records(app), "scenario::delivery_event_gate")
	if sequence_record.is_empty():
		failures.append("RW06-1 could not resolve the shipping sequence interaction.")
		return
	sequence_record = _as_overflow_record(sequence_record, 1)
	_install_fixture_records(app, action_list, [sequence_record])
	await _settle_frames(2)
	var entries := RoomActionListScript.action_entries_for_record(sequence_record)
	if entries.size() != 1 or str((entries[0] as Dictionary).get("_overflow_source", "")) != RoomActionListScript.SOURCE_SEQUENCE:
		failures.append("RW06-1 shipping sequence+available projection did not dedupe to SOURCE_SEQUENCE: %s." % JSON.stringify(entries))
		return
	var action := entries[0] as Dictionary
	var expected_key := _activation_key(action)
	var prior_count := activations.count(expected_key)
	var before_receipts := _scenario_command_receipt_count(run_state)
	action_list.open()
	await process_frame
	var button := _action_button_by_key(action_list, str(action.get("_overflow_action_key", "")))
	if button == null:
		failures.append("RW06-1 shipping sequence action was not rendered.")
		action_list.close()
		return
	_send_touch(button.get_global_rect().get_center())
	await _settle_frames(8)
	var after_projection: Dictionary = run_state.call("scenario_sequence_projection")
	if str(after_projection.get("phase_id", "")) != "sorting" \
			or _scenario_command_receipt_count(run_state) != before_receipts + 1 \
			or activations.count(expected_key) != prior_count + 1 \
			or bool(action_list.call("is_open")):
		failures.append("RW06-1 shipping scenario_sequence action did not reach the real arrival-to-sorting mutation.")


func _check_production_mutation_for_mode(app: Control, action_list: Control, production_record: Dictionary, activations: Array[String], mode: String) -> void:
	_install_fixture_records(app, action_list, [production_record.duplicate(true)])
	await _settle_frames(2)
	var entries := RoomActionListScript.action_entries_for_record(production_record)
	if entries.is_empty():
		failures.append("RW06-1 %s mutation check found no production action entry." % mode)
		return
	var production_action := entries[0] as Dictionary
	if str(production_action.get("_overflow_source", "")) != RoomActionListScript.SOURCE_AVAILABLE:
		failures.append("RW06-1 live game action did not exercise SOURCE_AVAILABLE for %s." % mode)
	if not str(production_action.get("scenario_command_id", "")).strip_edges().is_empty() \
			or not str(production_record.get("scenario_command_id", "")).strip_edges().is_empty():
		failures.append("RW06-1 live game action unexpectedly carries explicit scenario authority for %s." % mode)
	var expected_key := _activation_key(production_action)
	var prior_count := activations.count(expected_key)
	var before := _mutation_snapshot(app)
	action_list.open()
	await process_frame
	var button := _action_button_by_key(action_list, str(production_action.get("_overflow_action_key", "")))
	if button == null:
		failures.append("RW06-1 %s mutation check could not find its production button." % mode)
		action_list.close()
		return
	match mode:
		"mouse":
			_send_mouse(button.get_global_rect().get_center())
		"touch":
			_send_touch(button.get_global_rect().get_center())
		"keyboard":
			button.grab_focus()
			_send_key(KEY_ENTER)
		"controller":
			button.grab_focus()
			_send_joy_button(JOY_BUTTON_A)
	await _settle_frames(5)
	if activations.count(expected_key) != prior_count + 1:
		failures.append("RW06-1 %s did not activate the production overflow action exactly once." % mode)
	if str(app.get("current_screen")) != "GAME" or app.get("current_game") == null or _mutation_snapshot(app) == before:
		failures.append("RW06-1 %s overflow action did not reach a real production game-entry mutation." % mode)
	if app.get("current_game") != null:
		app.call("_complete_back_to_environment")
		await _settle_frames(4)
	if str(app.get("current_screen")) != "ENVIRONMENT" or app.get("current_game") != null:
		failures.append("RW06-1 %s production fixture could not return to the room for the next modality." % mode)


func _check_rejected_actions_for_mode(app: Control, action_list: Control, disabled_record: Dictionary, hidden_record: Dictionary, activations: Array[String], mode: String) -> void:
	var rejection_records: Array = [disabled_record.duplicate(true), hidden_record.duplicate(true)]
	_install_fixture_records(app, action_list, rejection_records)
	await _settle_frames(2)
	var disabled_entries := RoomActionListScript.action_entries_for_record(disabled_record)
	if disabled_entries.is_empty():
		failures.append("RW06-1 %s rejection check could not resolve its disabled action metadata." % mode)
		return
	var disabled_action := disabled_entries[0] as Dictionary
	var hidden_raw := ((hidden_record.get("inline_actions", []) as Array)[0] as Dictionary).duplicate(true)
	hidden_raw["_overflow_source"] = RoomActionListScript.SOURCE_INLINE
	hidden_raw["_overflow_index"] = 0
	hidden_raw["_overflow_action_key"] = "forged:hidden-action-key"
	var before := _mutation_snapshot(app)
	var activation_count := activations.size()
	action_list.open()
	await process_frame
	var disabled_button := _action_button(action_list, "unlock")
	if disabled_button == null:
		failures.append("RW06-1 %s rejection check could not find its disabled row." % mode)
	else:
		match mode:
			"mouse":
				_send_mouse(disabled_button.get_global_rect().get_center())
			"touch":
				_send_touch(disabled_button.get_global_rect().get_center())
			"keyboard":
				disabled_button.grab_focus()
				await process_frame
				if root.gui_get_focus_owner() == disabled_button:
					failures.append("RW06-1 keyboard focus reached a disabled overflow action.")
				_send_key(KEY_TAB)
			"controller":
				disabled_button.grab_focus()
				await process_frame
				if root.gui_get_focus_owner() == disabled_button:
					failures.append("RW06-1 controller focus reached a disabled overflow action.")
				_send_joy_button(JOY_BUTTON_DPAD_DOWN)
	await _settle_frames(2)
	if _action_button(action_list, "overflow_fixture_action:hidden_only") != null:
		failures.append("RW06-1 %s rejection surface exposed its hidden action." % mode)
	var disabled_result := bool(app.call("_activate_overflow_room_action", disabled_record, disabled_action))
	var hidden_result := bool(app.call("_activate_overflow_room_action", hidden_record, hidden_raw))
	if disabled_result or hidden_result or activations.size() != activation_count or _mutation_snapshot(app) != before:
		failures.append("RW06-1 %s disabled/hidden action path emitted or mutated production state." % mode)
	if not bool(action_list.call("is_open")):
		failures.append("RW06-1 %s rejected action released the overflow modal." % mode)
	action_list.close()
	await process_frame


func _check_downstream_rejection_reopens(app: Control, action_list: Control, activations: Array[String]) -> void:
	var rejected_record := {
		"object_id": "overflow_fixture:missing_scenario_authority",
		"object_type": "scenario",
		"owner_namespace": "scenario",
		"stable_object_id": "missing_scenario_authority",
		"label": "Missing scenario authority",
		"presentation_mode": "overflow",
		"presentation_required": true,
		"visible": true,
		"interactive": true,
		"enabled": true,
		"inline_actions": [{
			"id": "missing_command",
			"scenario_command_id": "missing_command",
			"scenario_owner_namespace": "scenario",
			"scenario_stable_object_id": "missing_scenario_authority",
		}],
	}
	_install_fixture_records(app, action_list, [rejected_record])
	await _settle_frames(2)
	var entries := RoomActionListScript.action_entries_for_record(rejected_record)
	if entries.size() != 1:
		failures.append("RW06-1 downstream-rejection fixture could not resolve its action.")
		return
	var action := entries[0] as Dictionary
	action_list.open()
	await process_frame
	var button := _action_button_by_key(action_list, str(action.get("_overflow_action_key", "")))
	if button == null:
		failures.append("RW06-1 downstream-rejection fixture was not rendered.")
		action_list.close()
		return
	var before := _mutation_snapshot(app)
	var activation_count := activations.size()
	_send_mouse(button.get_global_rect().get_center())
	await _settle_frames(4)
	var overlay := action_list.get("_overlay") as Control
	var focus_owner := root.gui_get_focus_owner()
	if activations.size() != activation_count \
			or _mutation_snapshot(app) != before \
			or not bool(action_list.call("is_open")) \
			or overlay == null \
			or focus_owner == null \
			or not overlay.is_ancestor_of(focus_owner):
		failures.append("RW06-1 downstream production refusal did not reopen the modal fail-closed.")
	action_list.close()


func _first_enabled_game_record(records: Array) -> Dictionary:
	for record_value in records:
		if typeof(record_value) != TYPE_DICTIONARY:
			continue
		var record := record_value as Dictionary
		if str(record.get("object_type", "")) != "game" \
				or not bool(record.get("visible", true)) \
				or not bool(record.get("enabled", true)) \
				or not bool(record.get("interactive", true)):
			continue
		var actions: Array = record.get("available_actions", [])
		if not actions.is_empty() \
				and (record.get("inline_actions", []) as Array).is_empty() \
				and (record.get("scenario_sequence_actions", []) as Array).is_empty():
			return record.duplicate(true)
	return {}


func _install_fixture_records(app: Control, action_list: Control, records: Array) -> void:
	app.set("overflow_fixture_records", records.duplicate(true))
	app.set("use_overflow_fixture", true)
	app.set("interactable_object_view_cache_valid", false)
	if action_list != null:
		action_list.render(records)


func _current_interactable_records(app: Control) -> Array:
	var snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var value: Variant = snapshot.get("interactable_objects", [])
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


func _record_by_object_id(records: Array, object_id: String) -> Dictionary:
	for record_value in records:
		if typeof(record_value) != TYPE_DICTIONARY:
			continue
		var record := record_value as Dictionary
		if str(record.get("object_id", "")) == object_id:
			return record.duplicate(true)
	return {}


func _as_overflow_record(record_value: Dictionary, focus_order: int) -> Dictionary:
	var record := record_value.duplicate(true)
	record["presentation_mode"] = "overflow"
	record["presentation_required"] = true
	record["visible"] = true
	record["focus_order"] = focus_order
	return record


func _scenario_command_receipt_count(run_state: Variant) -> int:
	if run_state == null:
		return -1
	var environment: Dictionary = run_state.get("current_environment")
	var state_value: Variant = environment.get("scenario_sequence_state", {})
	if typeof(state_value) != TYPE_DICTIONARY:
		return -1
	var receipts_value: Variant = (state_value as Dictionary).get("command_receipts", [])
	return (receipts_value as Array).size() if typeof(receipts_value) == TYPE_ARRAY else -1


func _source_function_body(source: String, function_name: String) -> String:
	var marker := "func %s(" % function_name
	var start := source.find(marker)
	if start < 0:
		return ""
	var finish := source.find("\nfunc ", start + marker.length())
	return source.substr(start) if finish < 0 else source.substr(start, finish - start)


func _first_enabled_action_button(action_list: Control) -> Button:
	for node in action_list.find_children("*", "Button", true, false):
		var button := node as Button
		if not str(button.get_meta("action_key", "")).is_empty() and button.visible and not button.disabled:
			return button
	return null


func _mutation_snapshot(app: Control) -> String:
	var run_state: Variant = app.get("run_state")
	return JSON.stringify({
		"run": run_state.to_dict() if run_state != null else {},
		"screen": str(app.get("current_screen")),
		"game_active": app.get("current_game") != null,
		"selected_object_id": str(app.get("selected_object_id")),
		"focus_target_id": str(app.get("focus_target_id")),
	})


func _activation_key(action: Dictionary) -> String:
	var action_id := str(action.get("emit_object_id", "")).strip_edges()
	if action_id.is_empty():
		action_id = str(action.get("id", "")).strip_edges()
	return "%s|%s" % [
		str(action.get("_overflow_source", "")),
		action_id,
	]


func _action_button(action_list: Control, action_id: String) -> Button:
	for node in action_list.find_children("*", "Button", true, false):
		var button := node as Button
		if str(button.get_meta("action_id", "")) == action_id:
			return button
	return null


func _action_button_by_key(action_list: Control, action_key: String) -> Button:
	for node in action_list.find_children("*", "Button", true, false):
		var button := node as Button
		if str(button.get_meta("action_key", "")) == action_key:
			return button
	return null


func _launcher_button(action_list: Control) -> Button:
	for node in action_list.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text.begins_with("More room actions"):
			return button
	return null


func _send_key(keycode: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.pressed = true
	root.push_input(pressed)
	var released := InputEventKey.new()
	released.keycode = keycode
	released.pressed = false
	root.push_input(released)


func _send_joy_button(button_index: int) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.button_index = button_index
	pressed.pressed = true
	root.push_input(pressed)
	var released := InputEventJoypadButton.new()
	released.button_index = button_index
	released.pressed = false
	root.push_input(released)


func _send_mouse(position: Vector2) -> void:
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.position = position
	pressed.pressed = true
	root.push_input(pressed)
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.position = position
	released.pressed = false
	root.push_input(released)


func _send_touch(position: Vector2, double_tap: bool = false) -> void:
	var pressed := InputEventScreenTouch.new()
	pressed.index = 0
	pressed.position = position
	pressed.pressed = true
	pressed.double_tap = double_tap
	root.push_input(pressed)
	var released := InputEventScreenTouch.new()
	released.index = 0
	released.position = position
	released.pressed = false
	released.double_tap = double_tap
	root.push_input(released)


func _settle_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _finish(app: Control) -> void:
	app.queue_free()
	await _settle_frames(5)
	if failures.is_empty():
		print("RW06_1_OVERFLOW_ACTION_UI PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
