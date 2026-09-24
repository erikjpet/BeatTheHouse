extends SceneTree

const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const RoomActionListScript := preload("res://scripts/ui/room_action_list.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EnvironmentBaseSemanticRecordsScript := preload("res://scripts/core/environment_base_semantic_records.gd")
const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")
const EnvironmentSemanticInventoryScript := preload("res://scripts/core/environment_semantic_inventory.gd")
const ArtContractsScript := preload("res://scripts/core/art_contracts.gd")
const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")
const ScenarioSemanticViewModelScript := preload("res://scripts/ui/scenario_semantic_view_model.gd")
const EnvironmentInteractionControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")
const ScenarioSequenceProbeSupportScript := preload("res://tools/scenario_sequence_probe_support.gd")
const HarnessProductionFidelityScript := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const TOUCH_MODALITY_ISOLATION_SECONDS := 0.80

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


class CleanupQuitter:
	extends Node

	var frames_remaining := 12
	var exit_code := 0

	func _process(_delta: float) -> void:
		frames_remaining -= 1
		if frames_remaining <= 0:
			get_tree().quit(exit_code)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_semantic_scenario_presentation_policy()
	await _check_selected_info_action_enabled_gate()
	var app := OverflowFoundationHost.new()
	app.size = Vector2(1280.0, 720.0)
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	await _settle_frames(3)
	if not app.start_foundation_run("RW06-1-OVERFLOW-ACTIONS", {}, false):
		failures.append("RW06-1 overflow contract could not start its production Foundation run.")
		_finish(app)
		return
	await _settle_frames(4)
	var action_list = app.get("room_action_list")
	if action_list == null:
		failures.append("RW06-1 production Foundation host did not mount RoomActionList.")
		_finish(app)
		return
	await _check_sealed_overflow_production_chain(action_list)
	var production_room_installed: bool = await _install_production_game_room(app)
	if not production_room_installed:
		_finish(app)
		return

	var production_record := _first_enabled_game_record(app.call("_interactable_object_view_list"))
	if production_record.is_empty():
		failures.append("RW06-1 overflow contract found no live production game action; a synthetic fallback is forbidden.")
		_finish(app)
		return
	_check_exact_overflow_semantic_retention(app, production_record)
	_check_late_binding_persistence(app, production_record)
	_check_capacity_simplification_action_reachability()
	_check_canonical_expanded_target()
	_check_authority_geometry_round_trip()
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
	var authored_info_order := 41
	for spec_value in _abstract_scenario_action_specs():
		var spec := spec_value as Dictionary
		records.append({
			"object_id": "scenario::%s" % str(spec.get("stable_id", "")),
			"object_type": "scenario_scene_object",
			"label": str(spec.get("label", "")),
			"short_description": str(spec.get("summary", "")),
			"presentation_mode": "overflow",
			"presentation_required": true,
			"visible": true,
			"interactive": true,
			"enabled": true,
			"focus_order": authored_info_order,
			"inline_actions": [],
			"scenario_sequence_actions": [],
			"available_actions": [],
		})
		authored_info_order += 1
	app.overflow_fixture_records = records.duplicate(true)
	app.use_overflow_fixture = true
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
	await _check_record_scenario_authority_staleness(app, action_list, records, activations)
	await _check_canvas_exclusion(records)
	await _check_cancel_and_focus_recovery(action_list)
	await _check_responsive_panel_width(action_list)
	await _check_refresh_focus_recovery(app, action_list, records)
	for mode in ["mouse", "touch", "keyboard", "controller"]:
		if mode == "touch":
			await _isolate_touch_from_prior_mouse()
		await _check_rejected_actions_for_mode(app, action_list, disabled_record, hidden_record, activations, str(mode))
	await _check_downstream_rejection_reopens(app, action_list, activations)

	var baseline_run_snapshot: Dictionary = app.get("run_state").to_dict()
	var delivery_setup := await _install_delivery_day(app, action_list)
	if bool(delivery_setup.get("ok", false)):
		var arrival_snapshot := (delivery_setup.get("arrival_snapshot", {}) as Dictionary).duplicate(true)
		await _check_background_pointer_shield(app, action_list, arrival_snapshot, "mouse")
		await _isolate_touch_from_prior_mouse()
		await _check_background_pointer_shield(app, action_list, arrival_snapshot, "touch")
		await _check_stale_authority_rejection(app, action_list, arrival_snapshot, activations)
		await _check_inline_scenario_mutation(app, action_list, arrival_snapshot, activations)
		await _isolate_touch_from_prior_mouse()
		await _check_sequence_scenario_mutation(app, action_list, arrival_snapshot, activations)
	await _restore_run(app, action_list, baseline_run_snapshot)
	for mode in ["mouse", "touch", "keyboard", "controller"]:
		if mode == "touch":
			await _isolate_touch_from_prior_mouse()
		await _check_production_mutation_for_mode(app, action_list, production_record, activations, str(mode))
	# Keep the production host alive while its final environment refresh and any
	# UI coroutines resume. Freeing it on the same frame can strand anonymous
	# GDScriptFunctionState objects at engine shutdown.
	await _settle_frames(12)
	_finish(app)


func _check_rendered_action_surface(action_list: Control, records: Array) -> void:
	var action_sources: Dictionary = {}
	var represented_records: Dictionary = {}
	var disabled_button: Button = null
	var information_button: Button = null
	var authored_information_buttons: Dictionary = {}
	var authored_information_summaries: Dictionary = {}
	for spec_value in _abstract_scenario_action_specs():
		var spec := spec_value as Dictionary
		authored_information_summaries["scenario::%s" % str(spec.get("stable_id", ""))] = str(spec.get("summary", ""))
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
		elif authored_information_summaries.has(object_id):
			authored_information_buttons[object_id] = button
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
	for object_id_value in authored_information_summaries.keys():
		var object_id := str(object_id_value)
		var button := authored_information_buttons.get(object_id) as Button
		var summary := str(authored_information_summaries.get(object_id, ""))
		if button == null or not button.disabled \
				or not button.text.contains(summary) or not button.tooltip_text.contains(summary):
			failures.append("RW06-1 authored actionless obstacle %s lost its non-actionable label/summary row." % object_id)


func _check_dispatch_source_placement() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/foundation_main.gd")
	var action_list_source := FileAccess.get_file_as_string("res://scripts/ui/room_action_list.gd")
	var blocking_body := _source_function_body(source, "_blocking_modal_message")
	var slot_body := _source_function_body(source, "_main_floor_slot_game_id")
	var talk_body := _source_function_body(source, "_talk_dock_input_is_blocked")
	var dispatch_body := _source_function_body(source, "_activate_overflow_room_action")
	var key_body := _source_function_body(action_list_source, "_action_key")
	var identity_body := _source_function_body(action_list_source, "_logical_dispatch_identity")
	var effective_body := _source_function_body(action_list_source, "_effective_scenario_command_id")
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
	var effective_sequence_index := effective_body.find("_uses_scenario_sequence_dispatch")
	var effective_action_index := effective_body.find("action.get(\"scenario_command_id\"")
	var effective_record_index := effective_body.find("record.get(\"scenario_command_id\"")
	var effective_true_scenario_index := effective_body.find("== \"scenario\"")
	var effective_id_fallback_index := effective_body.rfind("return str(action.get(\"id\"")
	if effective_sequence_index < 0 or effective_action_index < 0 or effective_record_index < 0 \
			or effective_true_scenario_index < 0 or effective_id_fallback_index < 0 \
			or effective_sequence_index > effective_action_index \
			or effective_action_index > effective_record_index \
			or effective_record_index > effective_true_scenario_index \
			or effective_true_scenario_index > effective_id_fallback_index \
			or not key_body.contains("record_scenario_command_id") \
			or not key_body.contains("effective_scenario_command_id") \
			or not identity_body.contains("_effective_scenario_command_id(record, action, source)") \
			or not identity_body.contains("object_type == \"scenario\""):
		failures.append("RW06-1 RoomActionList key/dedupe authority no longer mirrors sequence/action/record scenario dispatch precedence.")


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
	var record_authority_mirror := {
		"object_id": "overflow_fixture:record_authority_mirror",
		"object_type": "game",
		"owner_namespace": "scenario",
		"stable_object_id": "record_authority_mirror",
		"scenario_command_id": "record_owned_command",
		"inline_actions": [{"id": "inline_alias"}],
		"scenario_sequence_actions": [{"id": "sequence_owned_command"}],
		"available_actions": [{"id": "available_alias"}],
	}
	var record_authority_entries := RoomActionListScript.action_entries_for_record(record_authority_mirror)
	if record_authority_entries.size() != 2 \
			or str((record_authority_entries[0] as Dictionary).get("_overflow_source", "")) != RoomActionListScript.SOURCE_INLINE \
			or str((record_authority_entries[0] as Dictionary).get("id", "")) != "inline_alias" \
			or str((record_authority_entries[1] as Dictionary).get("_overflow_source", "")) != RoomActionListScript.SOURCE_SEQUENCE \
			or str((record_authority_entries[1] as Dictionary).get("id", "")) != "sequence_owned_command":
		failures.append("RW06-1 record-level scenario authority did not dedupe inline/available mirrors with first-source precedence while preserving the sequence-owned action: %s." % JSON.stringify(record_authority_entries))
	var action_precedence_record := record_authority_mirror.duplicate(true)
	action_precedence_record["scenario_sequence_actions"] = []
	action_precedence_record["inline_actions"] = [{
		"id": "action_override_alias",
		"scenario_command_id": "action_owned_command",
	}]
	var action_precedence_entries := RoomActionListScript.action_entries_for_record(action_precedence_record)
	if action_precedence_entries.size() != 2 \
			or str((action_precedence_entries[0] as Dictionary).get("_overflow_dispatch_identity", "")) \
			== str((action_precedence_entries[1] as Dictionary).get("_overflow_dispatch_identity", "")):
		failures.append("RW06-1 action-level scenario authority did not override the record-level command before dedupe: %s." % JSON.stringify(action_precedence_entries))
	var emit_only_scenario := {
		"object_id": "scenario::emit_only",
		"object_type": "scenario",
		"owner_namespace": "scenario",
		"stable_object_id": "emit_only",
		"inline_actions": [{"id": "", "emit_object_id": "scenario_action:emit_only"}],
	}
	var emit_only_entries := RoomActionListScript.action_entries_for_record(emit_only_scenario)
	if emit_only_entries.size() != 1 \
			or not str((emit_only_entries[0] as Dictionary).get("_overflow_dispatch_identity", "")).begins_with("scenario:"):
		failures.append("RW06-1 visible emit-only true-scenario action escaped scenario identity parity: %s." % JSON.stringify(emit_only_entries))


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
		"scenario_command_id": "record_prepare",
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
	for record_field_value in ["owner_namespace", "stable_object_id", "scenario_command_id"]:
		var changed_record := record.duplicate(true)
		changed_record[str(record_field_value)] = "%s_changed" % str(changed_record.get(str(record_field_value), "authority"))
		var changed_entries := RoomActionListScript.action_entries_for_record(changed_record)
		if changed_entries.size() != 1 \
				or str((changed_entries[0] as Dictionary).get("_overflow_action_key", "")) == baseline_key:
			failures.append("RW06-1 overflow action key did not seal record %s." % str(record_field_value))


func _check_record_scenario_authority_staleness(
	app: Control,
	action_list: Control,
	restore_records: Array,
	activations: Array[String]
) -> void:
	var base_record := {
		"object_id": "overflow_fixture:record_scenario_authority",
		"object_type": "game",
		"owner_namespace": "scenario",
		"stable_object_id": "record_scenario_authority",
		"scenario_owner_namespace": "scenario",
		"scenario_stable_object_id": "record_scenario_authority",
		"label": "Record scenario authority",
		"presentation_mode": "overflow",
		"presentation_required": true,
		"visible": true,
		"interactive": true,
		"enabled": true,
		"available_actions": [{
			"id": "ordinary_action_alias",
			"label": "Record-owned command",
		}],
	}
	var cases := [
		{
			"name": "mutated",
			"rendered_has_command": true,
			"rendered_command": "record_owned_command",
			"live_has_command": true,
			"live_command": "changed_record_command",
		},
		{
			"name": "removed",
			"rendered_has_command": true,
			"rendered_command": "record_owned_command",
			"live_has_command": false,
			"live_command": "",
		},
		{
			"name": "added",
			"rendered_has_command": false,
			"rendered_command": "",
			"live_has_command": true,
			"live_command": "added_record_command",
		},
	]
	for case_value in cases:
		var case_data := case_value as Dictionary
		var rendered_record := base_record.duplicate(true)
		if bool(case_data.get("rendered_has_command", false)):
			rendered_record["scenario_command_id"] = str(case_data.get("rendered_command", ""))
		else:
			rendered_record.erase("scenario_command_id")
		var live_record := rendered_record.duplicate(true)
		if bool(case_data.get("live_has_command", false)):
			live_record["scenario_command_id"] = str(case_data.get("live_command", ""))
		else:
			live_record.erase("scenario_command_id")
		var rendered_entries := RoomActionListScript.action_entries_for_record(rendered_record)
		var live_entries := RoomActionListScript.action_entries_for_record(live_record)
		if rendered_entries.size() != 1 or live_entries.size() != 1:
			failures.append("RW06-1 %s record-authority fixture did not resolve one action per snapshot." % str(case_data.get("name", "unknown")))
			continue
		var stale_action := (rendered_entries[0] as Dictionary).duplicate(true)
		var stale_key := str(stale_action.get("_overflow_action_key", ""))
		var live_key := str((live_entries[0] as Dictionary).get("_overflow_action_key", ""))
		if stale_key.is_empty() or live_key.is_empty() or stale_key == live_key:
			failures.append("RW06-1 %s live record-level scenario command change did not rotate the sealed action key." % str(case_data.get("name", "unknown")))
			continue
		_install_fixture_records(app, action_list, [rendered_record])
		await _settle_frames(2)
		action_list.open()
		await process_frame
		var stale_button := _action_button_by_key(action_list, stale_key)
		if stale_button == null:
			failures.append("RW06-1 %s record-authority fixture did not render its sealed action." % str(case_data.get("name", "unknown")))
			action_list.close()
			continue
		stale_button.grab_focus()
		await process_frame
		# Change only the production lookup snapshot. The modal deliberately keeps
		# its rendered record/action so selecting it exercises stale-key rejection.
		_install_fixture_records(app, null, [live_record])
		var before := _mutation_snapshot(app)
		var activation_count := activations.size()
		_send_mouse(stale_button.get_global_rect().get_center())
		await _settle_frames(3)
		var direct_result := bool(app.call("_activate_overflow_room_action", rendered_record, stale_action))
		var overlay := action_list.get("_overlay") as Control
		if direct_result \
				or activations.size() != activation_count \
				or _mutation_snapshot(app) != before \
				or not bool(action_list.call("is_open")) \
				or overlay == null \
				or root.gui_get_focus_owner() != stale_button \
				or not overlay.is_ancestor_of(stale_button):
			failures.append("RW06-1 %s live record-level scenario command change did not reject without signal/state/modal/focus drift." % str(case_data.get("name", "unknown")))
		action_list.close()
	_install_fixture_records(app, action_list, restore_records)
	await _settle_frames(2)


func _abstract_scenario_action_specs() -> Array:
	return [
		{
			"stable_id": "delta_queen_wedding_charter_ceremony_rope",
			"role": "barrier",
			"label": "Ceremony rope",
			"summary": "Ceremony ropes divide the front promenade into competing lanes.",
		},
		{
			"stable_id": "bar_live_band_task_0",
			"role": "task_station",
			"label": "Trace dead cable",
			"summary": "Trace the dead cable from the stage before the set can continue.",
		},
		{
			"stable_id": "grand_casino_audit_night_work_1_choice_0",
			"role": "decision_route",
			"label": "Route 1",
			"summary": "Choose the first public audit route.",
		},
		{
			"stable_id": "grand_casino_audit_night_cage_seal",
			"role": "evidence",
			"label": "Audit cage seal",
			"summary": "The intact seal identifies the first inspected zone.",
		},
		{
			"stable_id": "bar_dead_tuesday_bartender_zone",
			"role": "task_zone",
			"label": "Bartender work zone",
			"summary": "The bartender work zone is one available focus for the night.",
		},
	]


func _check_semantic_scenario_presentation_policy() -> void:
	var surface_map := EnvironmentPlacementScript.surface_map_by_id("bar").duplicate(true)
	var synthetic_preferences := (surface_map.get("scenario_slot_ids", {}) as Dictionary).duplicate(true)
	var synthetic_art := (surface_map.get("scenario_art_keys", {}) as Dictionary).duplicate(true)
	synthetic_preferences["physical_table"] = "stage.event_pool_table_1"
	synthetic_art["physical_table"] = "room_surface"
	for spec_value in _abstract_scenario_action_specs():
		var spec := spec_value as Dictionary
		var stable_id := str(spec.get("stable_id", ""))
		synthetic_preferences[stable_id] = "stage.event_floor_fixture_1"
		synthetic_art[stable_id] = "room_surface"
	surface_map["scenario_slot_ids"] = synthetic_preferences
	surface_map["scenario_art_keys"] = synthetic_art
	surface_map["scenario_overflow_ids"] = []

	var abstract_entries: Array = []
	for spec_value in _abstract_scenario_action_specs():
		var spec := spec_value as Dictionary
		var stable_id := str(spec.get("stable_id", ""))
		var entry := {
			"identity": "scenario::%s" % stable_id,
			"actor": false,
			"safe_exit": false,
			"semantic": {
				"owner_namespace": "scenario", "stable_object_id": stable_id,
				"present": true, "visible": true, "enabled": true,
				"role": str(spec.get("role", "")), "label": str(spec.get("label", "")),
				"description": str(spec.get("summary", "")),
			},
		}
		abstract_entries.append(entry)
		if EnvironmentSlotBinderScript.scenario_visual_requires_room_slot(surface_map, entry) \
				or not EnvironmentSlotBinderScript.scenario_visual_art_key(surface_map, entry).is_empty():
			failures.append("RW06-1 abstract %s acquired physical authority from a slot/art hint." % stable_id)

	var physical_prop := {
		"identity": "scenario::physical_table", "actor": false, "safe_exit": false,
		"semantic": {"stable_object_id": "physical_table", "present": true, "visible": true, "role": "game_fixture", "label": "Physical table"},
	}
	if not EnvironmentSlotBinderScript.scenario_visual_requires_room_slot(surface_map, physical_prop) \
			or EnvironmentSlotBinderScript.scenario_visual_art_key(surface_map, physical_prop) != "room_surface":
		failures.append("RW06-1 exact stable-id plus closed art authority did not authorize a concrete physical prop.")
	var delta_surface := EnvironmentPlacementScript.surface_map_by_id("delta_queen").duplicate(true)
	var navigation_lamp := {
		"identity": "scenario::delta_queen_fog_delay_fog_signal", "actor": false, "safe_exit": false,
		"semantic": {
			"stable_object_id": "delta_queen_fog_delay_fog_signal", "present": true,
			"visible": true, "role": "navigation", "label": "Fog signal",
		},
	}
	if not EnvironmentSlotBinderScript.scenario_visual_requires_room_slot(delta_surface, navigation_lamp) \
			or EnvironmentSlotBinderScript.scenario_visual_art_key(delta_surface, navigation_lamp) != "room_signal":
		failures.append("RW06-1 reviewed navigation lamp did not receive its exact concrete room authority.")
	var unmapped_delta := delta_surface.duplicate(true)
	var unmapped_art := (unmapped_delta.get("scenario_art_keys", {}) as Dictionary).duplicate(true)
	unmapped_art.erase("delta_queen_fog_delay_fog_signal")
	unmapped_delta["scenario_art_keys"] = unmapped_art
	if EnvironmentSlotBinderScript.scenario_visual_requires_room_slot(unmapped_delta, navigation_lamp) \
			or not EnvironmentSlotBinderScript.scenario_visual_art_key(unmapped_delta, navigation_lamp).is_empty():
		failures.append("RW06-1 unmapped navigation semantic escaped the geometry-free action list.")
	var unknown_prop := physical_prop.duplicate(true)
	unknown_prop["identity"] = "scenario::unknown_physical_prop"
	var unknown_semantic := (unknown_prop.get("semantic", {}) as Dictionary).duplicate(true)
	unknown_semantic["stable_object_id"] = "unknown_physical_prop"
	unknown_prop["semantic"] = unknown_semantic
	if EnvironmentSlotBinderScript.scenario_visual_requires_room_slot(surface_map, unknown_prop):
		failures.append("RW06-1 unreviewed scene object acquired room geometry from physical-sounding semantics.")

	# Runtime binding uses production Bar data: abstract records stay geometry-free
	# while actors and required exits retain their dedicated physical contracts.
	var actor := {
		"identity": "scenario::contract_actor", "actor": true, "safe_exit": false,
		"placement_class": "standing_person",
		"semantic": {"stable_object_id": "contract_actor", "present": true, "visible": true, "role": "patron", "label": "Contract actor"},
	}
	var safe_exit := {
		"identity": "scenario::contract_safe_exit", "actor": false, "safe_exit": true,
		"placement_class": "doorway",
		"semantic": {"stable_object_id": "contract_safe_exit", "present": true, "visible": true, "role": "exit", "label": "Safe exit"},
	}
	var first_entries := abstract_entries.duplicate(true) + [actor, safe_exit]
	var repeat_entries := first_entries.duplicate(true)
	repeat_entries.reverse()
	var first := EnvironmentSlotBinderScript.bind_scenario_visuals({"archetype_id": "bar"}, first_entries)
	var repeat := EnvironmentSlotBinderScript.bind_scenario_visuals({"archetype_id": "bar"}, repeat_entries)
	if not bool(first.get("ok", false)) or not bool(repeat.get("ok", false)):
		failures.append("RW06-1 semantic room/action-list binding failed: %s." % JSON.stringify([first.get("errors", []), repeat.get("errors", [])]))
	else:
		var bindings := first.get("slot_bindings", {}) as Dictionary
		for entry_value in abstract_entries:
			var identity := str((entry_value as Dictionary).get("identity", ""))
			var binding := bindings.get(identity, {}) as Dictionary
			if str(binding.get("presentation_mode", "")) != "overflow" \
					or str(binding.get("overflow_reason", "")) != "action_list_authored" \
					or not str(binding.get("slot_id", "")).is_empty() \
					or not str(binding.get("placement_class", "")).is_empty():
				failures.append("RW06-1 %s did not retain geometry-free authored action-list authority." % identity)
		for identity in ["scenario::contract_actor", "scenario::contract_safe_exit"]:
			var binding := bindings.get(identity, {}) as Dictionary
			if str(binding.get("presentation_mode", "")) != "room" or str(binding.get("slot_id", "")).is_empty():
				failures.append("RW06-1 dedicated actor/required-exit physical contract failed for %s." % identity)
		if str(first.get("binding_digest", "")) != str(repeat.get("binding_digest", "")) \
				or JSON.stringify(bindings) != JSON.stringify(repeat.get("slot_bindings", {})):
			failures.append("RW06-1 semantic binding changed with input order.")

	var digest_mutation := surface_map.duplicate(true)
	var mutated_art := (digest_mutation.get("scenario_art_keys", {}) as Dictionary).duplicate(true)
	mutated_art["physical_table"] = "paper_note"
	digest_mutation["scenario_art_keys"] = mutated_art
	if EnvironmentSlotBinderScript.slot_map_digest(surface_map) == EnvironmentSlotBinderScript.slot_map_digest(digest_mutation):
		failures.append("RW06-1 slot-map digest ignored scenario-art authority mutation.")

	var hostile_surface := surface_map.duplicate(true)
	var known_id := "physical_table"
	hostile_surface["scenario_overflow_ids"] = [known_id]
	var valid_overflow_errors: Array = []
	if not EnvironmentSlotBinderScript._scenario_overflow_policy(hostile_surface, valid_overflow_errors).has(known_id) or not valid_overflow_errors.is_empty():
		failures.append("RW06-1 concrete physical-spill policy rejected valid exact authority.")
	for hostile_value in [
		{"name": "non-array", "value": known_id},
		{"name": "non-string", "value": [17]},
		{"name": "prefixed", "value": ["scenario::%s" % known_id]},
		{"name": "duplicate", "value": [known_id, known_id]},
		{"name": "unknown", "value": ["invented_scenario_obstacle"]},
	]:
		var hostile := hostile_value as Dictionary
		var candidate := hostile_surface.duplicate(true)
		candidate["scenario_overflow_ids"] = hostile.get("value")
		var hostile_errors: Array = []
		EnvironmentSlotBinderScript._scenario_overflow_policy(candidate, hostile_errors)
		if hostile_errors.is_empty():
			failures.append("RW06-1 scenario-overflow runtime policy accepted hostile %s authority." % str(hostile.get("name", "unknown")))

	for hostile_art_value in [
		{"name": "non-object", "value": ["physical_table"]},
		{"name": "generic-placeholder", "value": {"physical_table": "room_fixture"}},
		{"name": "unknown-id", "value": {"invented_physical_prop": "room_surface"}},
	]:
		var hostile_art := hostile_art_value as Dictionary
		var candidate := surface_map.duplicate(true)
		candidate["scenario_art_keys"] = hostile_art.get("value")
		var art_errors: Array = []
		var candidate_art: Dictionary = candidate.get("scenario_art_keys", {}) if typeof(candidate.get("scenario_art_keys", {})) == TYPE_DICTIONARY else {}
		EnvironmentSlotBinderScript._validate_scenario_art_policy(candidate, candidate_art, art_errors)
		if art_errors.is_empty():
			failures.append("RW06-1 scenario-art policy accepted hostile %s authority." % str(hostile_art.get("name", "unknown")))


func _check_selected_info_action_enabled_gate() -> void:
	var canvas := PixelSceneCanvasScript.new()
	canvas.size = Vector2(900.0, 430.0)
	root.add_child(canvas)
	await process_frame
	canvas.grab_focus()
	await process_frame
	if root.gui_get_focus_owner() != canvas:
		failures.append("RW06-1 selected-info input fixture could not focus its live canvas.")
	var records: Array = [
		_selected_info_gate_record("inline_object_disabled", false, true, true, true, true),
		_selected_info_gate_record("inline_action_disabled", true, false, true, true, true),
		_selected_info_gate_record("single_object_disabled", false, true, false, true, true),
		_selected_info_gate_record("single_action_disabled", true, false, false, true, true),
		_selected_info_gate_record("single_missing_confirm", true, true, false, false, true),
		_selected_info_gate_record("inline_enabled", true, true, true, true, true),
		_selected_info_gate_record("single_enabled", true, true, false, true, true),
	]
	canvas.render_environment_snapshot({
		"id": "rw06_1_selected_info_gate",
		"archetype_id": "bar",
		"display_name": "Selected action gate",
		"reduce_motion": true,
		"interactable_objects": records,
	})
	var activations: Array[String] = []
	canvas.object_activated.connect(func(object_id: String) -> void: activations.append(object_id))
	for record_index in range(5):
		var record := records[record_index] as Dictionary
		var object_id := str(record.get("object_id", ""))
		canvas.set_selected_object(object_id)
		var actions := canvas.current_view_snapshot().get("selected_info", {}).get("actions", []) as Array
		if actions.size() != 1 or bool((actions[0] as Dictionary).get("enabled", true)):
			failures.append("RW06-1 disabled selected-info case %s did not snapshot enabled:false." % object_id)
			continue
		var before := activations.size()
		_send_canvas_accept(canvas)
		_send_canvas_mouse(canvas, canvas.local_position_for_selected_info_action_button())
		if activations.size() != before:
			failures.append("RW06-1 disabled selected-info case %s emitted through keyboard or physical mouse." % object_id)

	canvas.set_selected_object("selected_info:inline_enabled")
	var inline_snapshot := canvas.current_view_snapshot().get("selected_info", {}) as Dictionary
	var inline_actions := inline_snapshot.get("actions", []) as Array
	var inline_before := activations.size()
	_send_canvas_accept(canvas)
	if inline_actions.size() != 1 or not bool((inline_actions[0] as Dictionary).get("enabled", false)) \
			or str((inline_actions[0] as Dictionary).get("label", "")) != "Visible inline" \
			or activations.size() != inline_before + 1 \
			or activations.back() != "selected_info_emit:inline_enabled":
		failures.append("RW06-1 enabled inline selected-info action did not omit hidden state and emit exactly once by keyboard.")

	canvas.set_selected_object("selected_info:single_enabled")
	var single_snapshot := canvas.current_view_snapshot().get("selected_info", {}) as Dictionary
	var single_actions := single_snapshot.get("actions", []) as Array
	var single_before := activations.size()
	var single_position := canvas.local_position_for_selected_info_action_button()
	var single_entry_before := canvas.call("_selected_info_action_entry_at_local_position", single_position) as Dictionary
	_send_canvas_mouse(canvas, single_position)
	if single_actions.size() != 1 or not bool((single_actions[0] as Dictionary).get("enabled", false)) \
			or str((single_actions[0] as Dictionary).get("label", "")) != "Visible Single" \
			or activations.size() != single_before + 1 \
			or activations.back() != "selected_info:single_enabled":
		failures.append("RW06-1 enabled single selected-info action did not omit hidden state and emit exactly once by physical mouse: %s." % JSON.stringify({
			"position": str(single_position),
			"entry_before": single_entry_before,
			"snapshot": single_snapshot,
			"activation_count_before": single_before,
			"activations": activations,
			"selected_object_id": str(canvas.get("selected_object_id")),
		}))
	canvas.release_focus()
	await process_frame
	canvas.queue_free()
	await process_frame


func _selected_info_gate_record(
	suffix: String,
	object_enabled: bool,
	action_enabled: bool,
	inline: bool,
	with_confirm: bool,
	include_hidden: bool
) -> Dictionary:
	var object_id := "selected_info:%s" % suffix
	var visible_action := {
		"id": "visible_%s" % suffix,
		"emit_object_id": "selected_info_emit:%s" % suffix,
		"label": "Visible inline" if inline else "Visible single",
		"enabled": action_enabled,
		"disabled": not action_enabled,
	}
	var hidden_action := {
		"id": "hidden_%s" % suffix,
		"emit_object_id": "selected_info_emit:hidden_%s" % suffix,
		"label": "Hidden action",
		"hidden": true,
	}
	var actions: Array = [visible_action]
	if include_hidden:
		actions.push_front(hidden_action)
	return {
		"object_id": object_id,
		"object_type": "event",
		"visual_type": "event",
		"label": suffix.replace("_", " ").capitalize(),
		"short_description": "Selected action authority fixture.",
		"presentation_mode": "room",
		"visible": true,
		"interactive": true,
		"enabled": object_enabled,
		"normalized_rect": {"x": 0.08, "y": 0.18, "w": 0.12, "h": 0.16},
		"inline_actions": actions if inline else [],
		"available_actions": [] if inline else actions,
		"confirm_action_id": "confirm_%s" % suffix if with_confirm else "",
	}


func _send_canvas_accept(canvas: Control) -> void:
	# Exercise the same focused viewport dispatch used by a real keyboard.
	if canvas == null or not canvas.is_inside_tree():
		failures.append("RW06-1 selected-info keyboard fixture lost its live canvas.")
		return
	canvas.grab_focus()
	_send_key(KEY_ENTER)


func _send_canvas_mouse(canvas: Control, position: Vector2) -> void:
	# Route through the viewport's production input dispatch. Calling _gui_input
	# directly is not a physical mouse proof and makes accept_event() run outside
	# the viewport dispatch lifecycle.
	if canvas == null or not canvas.is_inside_tree():
		failures.append("RW06-1 selected-info mouse fixture lost its live canvas.")
		return
	_send_mouse(position)


func _check_canvas_exclusion(records: Array) -> void:
	var canvas := PixelSceneCanvasScript.new()
	canvas.size = Vector2(900.0, 430.0)
	root.add_child(canvas)
	canvas.render_environment_snapshot({
		"id": "rw06_1_overflow_contract",
		"archetype_id": "bar",
		"interactable_objects": records,
	})
	await process_frame
	for object_value in canvas.current_view_snapshot().get("objects", []):
		if str((object_value as Dictionary).get("presentation_mode", "room")) == "overflow":
			failures.append("RW06-1 PixelSceneCanvas rendered an overflow-only action record.")
			break
	canvas.queue_free()
	await process_frame


func _check_sealed_overflow_production_chain(action_list: Control) -> void:
	var identity := "scenario::sealed_overflow_probe"
	var scene_objects: Dictionary = {}
	scene_objects[identity] = {
		"owner_namespace": "scenario",
		"stable_object_id": "sealed_overflow_probe",
		"present": true,
		"visible": true,
		"enabled": true,
		"label": "Sealed overflow probe",
		"description": "An abstract room task that must stay in More room actions.",
		"role": "task_station",
	}
	var interactions: Dictionary = {}
	interactions[identity] = {
		"owner_namespace": "scenario",
		"stable_object_id": "sealed_overflow_probe",
		"present": true,
		"label": "Sealed overflow probe",
		"prompt": "Inspect the abstract room task.",
		"enabled": true,
		"disabled_reason": "",
		"available_actions": [{
			"id": "inspect_probe",
			"label": "Inspect probe",
			"input_action": "confirm",
			"non_color_state": "ready",
		}],
		"input_actions": ["confirm"],
		"non_color_state": "available",
		"focus_order": 1,
		"hit_bounds": {"w": 44.0, "h": 44.0},
	}
	var projection := {
		"scenario_id": "rw06_1_sealed_overflow_probe",
		"phase_id": "arrival",
		"status": "active",
		"boundary_serial": 1,
		"semantic_state": {
			"scene_objects": scene_objects,
			"actors": {},
			"interactions": interactions,
			"services": {},
			"games": {},
			"routes": {},
		},
	}
	var resolved := ScenarioLayoutResolverScript.resolve([], projection, {
		"id": "rw06_1_sealed_overflow_probe",
		"archetype_id": "bar",
	})
	if not bool(resolved.get("ok", false)):
		failures.append("RW06-1 abstract production-chain probe did not resolve: %s." % JSON.stringify(resolved.get("errors", [])))
		return
	var renderer_snapshot := ScenarioLayoutResolverScript.sealed_renderer_snapshot(resolved)
	if not bool(renderer_snapshot.get("ok", false)):
		failures.append("RW06-1 abstract production-chain probe did not produce a sealed renderer snapshot: %s." % JSON.stringify(renderer_snapshot.get("errors", [])))
		return
	var authority := (resolved.get("layout_authority", {}) as Dictionary).get(identity, {}) as Dictionary
	var sealed_visual: Dictionary = {}
	for visual_value in renderer_snapshot.get("visual_objects", []) as Array:
		var visual := visual_value as Dictionary
		if str(visual.get("semantic_identity", "")) == identity:
			sealed_visual = visual
			break
	if sealed_visual.is_empty() \
			or str(sealed_visual.get("presentation_mode", "")) != "overflow" \
			or str(sealed_visual.get("presentation_mode", "")) != str(authority.get("presentation_mode", "")) \
			or str(sealed_visual.get("placement_class", "")) != str(authority.get("placement_class", "")) \
			or str(sealed_visual.get("slot_id", "")) != str(authority.get("slot_id", "")) \
			or str(sealed_visual.get("contact", "")) != str(authority.get("contact", "")) \
			or not (sealed_visual.get("normalized_rect", {}) as Dictionary).is_empty() \
			or not (sealed_visual.get("focus_rect", {}) as Dictionary).is_empty() \
			or not (sealed_visual.get("small_screen_rect", {}) as Dictionary).is_empty() \
			or not (sealed_visual.get("label_rect", {}) as Dictionary).is_empty() \
			or not (sealed_visual.get("small_screen_label_rect", {}) as Dictionary).is_empty():
		failures.append("RW06-1 sealed renderer DTO lost geometry-free overflow authority: %s." % JSON.stringify(sealed_visual))

	var composed := EnvironmentInteractionControllerScript.project_finalized_sequence_interaction_result([], resolved)
	var composed_records := composed.get("records", []) as Array
	var composed_record: Dictionary = {}
	for record_value in composed_records:
		var record := record_value as Dictionary
		if str(record.get("object_id", "")) == identity:
			composed_record = record
			break
	var action_entries := RoomActionListScript.action_entries_for_record(composed_record)
	if not bool(composed.get("ok", false)) \
			or composed_record.is_empty() \
			or str(composed_record.get("presentation_mode", "")) != "overflow" \
			or not (composed_record.get("normalized_rect", {}) as Dictionary).is_empty() \
			or not (composed_record.get("small_screen_rect", {}) as Dictionary).is_empty() \
			or action_entries.size() != 1 \
			or str((action_entries[0] as Dictionary).get("id", "")) != "inspect_probe":
		failures.append("RW06-1 production composition lost the abstract action-list record or public action: %s." % JSON.stringify({
			"composition_errors": composed.get("errors", []),
			"record": composed_record,
			"action_entries": action_entries,
		}))
	else:
		action_list.render(composed_records)
		await _settle_frames(2)
		var action_key := str((action_entries[0] as Dictionary).get("_overflow_action_key", ""))
		if not bool(action_list.visible) or action_key.is_empty() or _action_button_by_key(action_list, action_key) == null:
			failures.append("RW06-1 actual More room actions UI omitted the sealed abstract public action.")
		action_list.render([])

	for path_value in [
		{"label": "composed", "interactable_objects": composed_records},
		{"label": "renderer fallback", "interactable_objects": []},
	]:
		var path := path_value as Dictionary
		var canvas := PixelSceneCanvasScript.new()
		canvas.size = Vector2(900.0, 430.0)
		root.add_child(canvas)
		canvas.render_environment_snapshot({
			"id": "rw06_1_sealed_overflow_probe",
			"archetype_id": "bar",
			"interactable_objects": path.get("interactable_objects", []),
			"scenario_render_snapshot": renderer_snapshot,
		})
		await process_frame
		for object_value in canvas.current_view_snapshot().get("objects", []) as Array:
			if str((object_value as Dictionary).get("id", "")) == identity:
				failures.append("RW06-1 PixelSceneCanvas %s path rendered the sealed overflow-only abstract record." % str(path.get("label", "")))
				break
		canvas.queue_free()
		await process_frame


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
		var viewport_size := root.get_visible_rect().size
		var overlay_rect := overlay.get_global_rect() if overlay != null else Rect2()
		var panel_rect := panel.get_global_rect() if panel != null else Rect2()
		var panel_minimum := panel.custom_minimum_size if panel != null else Vector2.ZERO
		var panel_combined := panel.get_combined_minimum_size() if panel != null else Vector2.ZERO
		var list_combined := (action_list.get("_list") as Control).get_combined_minimum_size() if action_list.get("_list") is Control else Vector2.ZERO
		failures.append("RW06-1 compact action panel overflows a 320px-wide viewport: %s." % JSON.stringify({
			"root_size": {"x": root.size.x, "y": root.size.y},
			"viewport_size": {"x": viewport_size.x, "y": viewport_size.y},
			"overlay_rect": {"x": overlay_rect.position.x, "y": overlay_rect.position.y, "w": overlay_rect.size.x, "h": overlay_rect.size.y},
			"panel_rect": {"x": panel_rect.position.x, "y": panel_rect.position.y, "w": panel_rect.size.x, "h": panel_rect.size.y},
			"panel_size": {"x": panel.size.x if panel != null else 0.0, "y": panel.size.y if panel != null else 0.0},
			"panel_custom_minimum": {"x": panel_minimum.x, "y": panel_minimum.y},
			"panel_combined_minimum": {"x": panel_combined.x, "y": panel_combined.y},
			"list_combined_minimum": {"x": list_combined.x, "y": list_combined.y},
		}))
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
	var generator: Variant = app.get("generator")
	if generator == null:
		failures.append("RW06-1 delivery-day fixture has no production host generator.")
		return {"ok": false}
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
		var failed_environment := run_state.get("current_environment") as Dictionary
		failures.append("RW06-1 shipped delivery-day scenario did not finalize at arrival: %s." % JSON.stringify({
			"projection": projection,
			"semantic_ready": bool(failed_environment.get("scenario_semantic_ready", false)),
			"lifecycle_errors": failed_environment.get("scenario_sequence_lifecycle_errors", []),
			"layout_audit": failed_environment.get("scenario_layout_audit", {}),
		}))
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


func _install_production_game_room(app: Control) -> bool:
	var library: Variant = app.get("library")
	var run_state: Variant = app.get("run_state")
	var archetype: Dictionary = library.call("environment_archetype", "bar") if library != null else {}
	if run_state == null or archetype.is_empty():
		failures.append("RW06-1 overflow contract could not load the production Bar archetype.")
		return false
	var rng: Variant = run_state.call("create_rng", "rw06_1:production-overflow-game")
	var environment: Variant = EnvironmentInstanceScript.from_archetype(archetype, 1, rng, library)
	if environment == null:
		failures.append("RW06-1 overflow contract could not instantiate a production Bar.")
		return false
	var data: Dictionary = environment.call("to_dict")
	# A dedicated unseeded node guarantees this is a plain production room, not a
	# synthetic game record and not an unrelated world-map scenario fixture.
	data["world_node_id"] = "rw06_1_overflow_bar"
	var generator: Variant = app.get("generator")
	if generator == null:
		failures.append("RW06-1 Bar fixture has no production host generator.")
		return false
	data["game_states"] = generator.call("_generated_game_states", run_state, data, rng)
	data["layout"] = EnvironmentInstanceScript.ensure_generated_layout(data, library)
	var installation: Dictionary = run_state.call("set_environment", data)
	if not bool(installation.get("ok", false)):
		failures.append("RW06-1 production Bar install failed: %s." % JSON.stringify(installation.get("errors", [])))
		return false
	app.call("_clear_selected_game_action")
	app.call("_refresh")
	await _settle_frames(6)
	if _first_enabled_game_record(app.call("_interactable_object_view_list")).is_empty():
		failures.append("RW06-1 installed production Bar exposed no enabled game action.")
		return false
	return true


func _check_exact_overflow_semantic_retention(app: Control, production_record: Dictionary) -> void:
	var run_state: Variant = app.get("run_state")
	var library: Variant = app.get("library")
	if run_state == null or library == null:
		failures.append("RW06-1 overflow semantic regression lacks production state/library authority.")
		return
	var environment: Dictionary = (run_state.get("current_environment") as Dictionary).duplicate(true)
	var source_id := str(production_record.get("source_id", "")).strip_edges()
	var presentation_id := str(production_record.get("object_id", "")).strip_edges()
	var presentation_parts := presentation_id.split(":", false)
	if source_id.is_empty() and presentation_parts.size() >= 2:
		source_id = str(presentation_parts[1])
	if source_id.is_empty() or presentation_id.is_empty():
		failures.append("RW06-1 overflow semantic regression could not identify its production game record.")
		return
	# Derive the positive fixture from the production binder. This proves real
	# class/kind/schema/map authority instead of handcrafting a plausible seal.
	var requested_records: Array = []
	for index in range(64):
		var record := production_record.duplicate(true)
		record["object_id"] = "game:%s:%d" % [source_id, index + 100]
		record["source_id"] = source_id
		record.erase("slot_binding_source_id")
		requested_records.append(record)
	var original_layout := (environment.get("layout", {}) as Dictionary).duplicate(true)
	var binding_environment := environment.duplicate(true)
	binding_environment["layout"] = original_layout
	var binding := EnvironmentSlotBinderScript.bind_base_records(
		binding_environment,
		requested_records,
		original_layout.get("slot_bindings", {}) as Dictionary
	)
	if not bool(binding.get("ok", false)):
		failures.append("RW06-1 production binder could not create the overflow semantic fixture: %s." % JSON.stringify(binding.get("errors", [])))
		return
	var layout := original_layout.duplicate(true)
	layout["slot_schema_version"] = int(binding.get("slot_schema_version", 0))
	layout["slot_map_digest"] = str(binding.get("slot_map_digest", ""))
	layout["slot_binding_digest"] = str(binding.get("binding_digest", ""))
	layout["slot_bindings"] = (binding.get("slot_bindings", {}) as Dictionary).duplicate(true)
	layout["slot_overflow_ids"] = (binding.get("overflow_ids", []) as Array).duplicate(true)
	layout["object_rects"] = (binding.get("object_rects", {}) as Dictionary).duplicate(true)
	environment["layout"] = layout
	var selected_overflow_ids: Array = []
	for record_value in requested_records:
		var object_id := str((record_value as Dictionary).get("object_id", ""))
		if (layout.get("slot_overflow_ids", []) as Array).has(object_id):
			selected_overflow_ids.append(object_id)
			if selected_overflow_ids.size() == 2: break
	if selected_overflow_ids.size() != 2:
		failures.append("RW06-1 production binder did not yield two repeated-fixture overflow identities.")
		return
	var authoritative := EnvironmentBaseSemanticRecordsScript.authoritative_interactable_records(environment, library)
	var authoritative_records: Array = []
	for record_value in authoritative.get("records", []) as Array:
		if selected_overflow_ids.has(str((record_value as Dictionary).get("object_id", ""))):
			authoritative_records.append(record_value)
	var stamped := EnvironmentBaseSemanticRecordsScript.stamp_interactable_records(authoritative_records, environment, library)
	var stamped_records: Array = stamped.get("records", [])
	var produced := EnvironmentBaseSemanticRecordsScript.from_interactable_records(stamped_records)
	var interactions: Array = produced.get("interactions", [])
	environment["scenario_base_interactions"] = interactions.duplicate(true)
	environment["scenario_base_actors"] = []
	var inventory := EnvironmentSemanticInventoryScript.for_instance(environment, library, interactions, [])
	var inventory_errors := EnvironmentSemanticInventoryScript.validate(inventory)
	var binding_errors := EnvironmentSemanticInventoryScript.validate_instance_binding(inventory, environment)
	if not bool(authoritative.get("ok", false)) or not bool(stamped.get("ok", false)) or not bool(produced.get("ok", false)) or not inventory_errors.is_empty() or not binding_errors.is_empty():
		var semantic_errors: Array = []
		semantic_errors.append_array(authoritative.get("errors", []) as Array)
		semantic_errors.append_array(stamped.get("errors", []) as Array)
		semantic_errors.append_array(produced.get("errors", []) as Array)
		semantic_errors.append_array(inventory_errors)
		semantic_errors.append_array(binding_errors)
		failures.append("RW06-1 exact overflow semantic retention failed: %s." % JSON.stringify(semantic_errors))
		return
	if authoritative_records.size() != 2 or stamped_records.size() != 2 or interactions.size() != 2:
		failures.append("RW06-1 slot-binding-only repeated game fixtures were omitted: authority=%d stamped=%d interactions=%d." % [authoritative_records.size(), stamped_records.size(), interactions.size()])
		return
	var seen: Dictionary = {}
	for index in range(stamped_records.size()):
		var stamped_record := stamped_records[index] as Dictionary
		var interaction := interactions[index] as Dictionary
		var object_id := str(stamped_record.get("object_id", ""))
		seen[object_id] = true
		if str(stamped_record.get("presentation_mode", "")) != "overflow" \
				or stamped_record.has("normalized_hit_rect") \
				or stamped_record.has("focus_rect") \
				or interaction.has("normalized_hit_rect") \
				or str(interaction.get("presentation_object_id", "")) != object_id \
				or float((interaction.get("hit_bounds", {}) as Dictionary).get("w", 0.0)) < 44.0 \
				or (interaction.get("available_actions", []) as Array).is_empty():
			failures.append("RW06-1 overflow interaction lost geometry-free action/identity authority: %s." % JSON.stringify(interaction))
	if not seen.has(selected_overflow_ids[0]) or not seen.has(selected_overflow_ids[1]):
		failures.append("RW06-1 repeated overflow fixture identities collapsed: %s." % JSON.stringify(seen.keys()))
	var target_id := str(selected_overflow_ids[0])
	var hostile_layouts: Dictionary = {}
	var missing_digest := layout.duplicate(true)
	missing_digest.erase("slot_binding_digest")
	hostile_layouts["missing digest"] = missing_digest
	var stale_digest := layout.duplicate(true)
	stale_digest["slot_binding_digest"] = "0".repeat(64)
	hostile_layouts["stale digest"] = stale_digest
	var wrong_schema := layout.duplicate(true)
	wrong_schema["slot_schema_version"] = int(layout.get("slot_schema_version", 0)) + 1
	hostile_layouts["wrong schema"] = wrong_schema
	var wrong_map := layout.duplicate(true)
	wrong_map["slot_map_digest"] = "0".repeat(64)
	hostile_layouts["wrong map digest"] = wrong_map
	var missing_membership := layout.duplicate(true)
	var missing_membership_ids := (missing_membership.get("slot_overflow_ids", []) as Array).duplicate(true)
	missing_membership_ids.erase(target_id)
	missing_membership["slot_overflow_ids"] = missing_membership_ids
	hostile_layouts["overflow membership"] = missing_membership
	var wrong_kind := layout.duplicate(true)
	var wrong_kind_bindings := (wrong_kind.get("slot_bindings", {}) as Dictionary).duplicate(true)
	(wrong_kind_bindings[target_id] as Dictionary)["kind"] = "stage"
	wrong_kind["slot_bindings"] = wrong_kind_bindings
	wrong_kind["slot_binding_digest"] = EnvironmentSlotBinderScript.binding_digest(wrong_kind_bindings)
	hostile_layouts["wrong kind"] = wrong_kind
	var open_binding := layout.duplicate(true)
	var open_bindings := (open_binding.get("slot_bindings", {}) as Dictionary).duplicate(true)
	var open_target_binding := (open_bindings.get(target_id, {}) as Dictionary).duplicate(true)
	open_target_binding["forged"] = true
	open_bindings[target_id] = open_target_binding
	open_binding["slot_bindings"] = open_bindings
	open_binding["slot_binding_digest"] = EnvironmentSlotBinderScript.binding_digest(open_bindings)
	hostile_layouts["open binding schema"] = open_binding
	var wrong_class := layout.duplicate(true)
	var wrong_class_bindings := (wrong_class.get("slot_bindings", {}) as Dictionary).duplicate(true)
	var target_binding := wrong_class_bindings.get(target_id, {}) as Dictionary
	target_binding["placement_class"] = "standing_person" if str(target_binding.get("placement_class", "")) != "standing_person" else "floor_fixture"
	wrong_class_bindings[target_id] = target_binding
	wrong_class["slot_bindings"] = wrong_class_bindings
	wrong_class["slot_binding_digest"] = EnvironmentSlotBinderScript.binding_digest(wrong_class_bindings)
	hostile_layouts["wrong class"] = wrong_class
	var wrong_slot := layout.duplicate(true)
	var wrong_slot_bindings := (wrong_slot.get("slot_bindings", {}) as Dictionary).duplicate(true)
	var wrong_slot_binding := wrong_slot_bindings.get(target_id, {}) as Dictionary
	wrong_slot_binding["presentation_mode"] = "room"
	wrong_slot_binding["slot_id"] = "forged.slot"
	wrong_slot_binding["slot"] = {"id": "forged.slot", "footprint_class": str(wrong_slot_binding.get("placement_class", "")), "hit_rect": [10, 10, 44, 44]}
	wrong_slot_bindings[target_id] = wrong_slot_binding
	wrong_slot["slot_bindings"] = wrong_slot_bindings
	var wrong_slot_overflow := (wrong_slot.get("slot_overflow_ids", []) as Array).duplicate(true)
	wrong_slot_overflow.erase(target_id)
	wrong_slot["slot_overflow_ids"] = wrong_slot_overflow
	var wrong_slot_rects := (wrong_slot.get("object_rects", {}) as Dictionary).duplicate(true)
	wrong_slot_rects[target_id] = {"x": 10.0 / 900.0, "y": 10.0 / 430.0, "w": 44.0 / 900.0, "h": 44.0 / 430.0}
	wrong_slot["object_rects"] = wrong_slot_rects
	wrong_slot["slot_binding_digest"] = EnvironmentSlotBinderScript.binding_digest(wrong_slot_bindings)
	hostile_layouts["wrong slot"] = wrong_slot
	var overflow_geometry := layout.duplicate(true)
	var overflow_geometry_rects := (overflow_geometry.get("object_rects", {}) as Dictionary).duplicate(true)
	overflow_geometry_rects[target_id] = {"x": 0.1, "y": 0.1, "w": 0.1, "h": 0.1}
	overflow_geometry["object_rects"] = overflow_geometry_rects
	hostile_layouts["overflow object_rect"] = overflow_geometry
	for label_value in hostile_layouts.keys():
		var hostile_environment := environment.duplicate(true)
		hostile_environment["layout"] = hostile_layouts.get(label_value)
		if bool(EnvironmentBaseSemanticRecordsScript.stamp_interactable_records(authoritative_records, hostile_environment, library).get("ok", true)) \
				or EnvironmentSemanticInventoryScript.validate(EnvironmentSemanticInventoryScript.for_instance(hostile_environment, library, interactions, [])).is_empty():
			failures.append("RW06-1 %s hostile slot authority survived stamp/inventory validation." % str(label_value))
	var room_source_id := ""
	var layout_bindings := layout.get("slot_bindings", {}) as Dictionary
	var binding_ids := layout_bindings.keys()
	binding_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	for binding_id_value in binding_ids:
		var candidate_id := str(binding_id_value)
		if str((layout_bindings.get(candidate_id, {}) as Dictionary).get("presentation_mode", "")) == "room":
			room_source_id = candidate_id
			break
	if room_source_id.is_empty():
		failures.append("RW06-1 alias authority regression found no production room binding.")
	else:
		var alias_id := "game:%s:9998" % source_id
		var alias_layout := layout.duplicate(true)
		var alias_bindings := (alias_layout.get("slot_bindings", {}) as Dictionary).duplicate(true)
		var alias_binding := (alias_bindings.get(room_source_id, {}) as Dictionary).duplicate(true)
		alias_binding["identity"] = alias_id
		alias_bindings[alias_id] = alias_binding
		alias_layout["slot_bindings"] = alias_bindings
		var alias_rects := (alias_layout.get("object_rects", {}) as Dictionary).duplicate(true)
		if alias_rects.has(room_source_id):
			alias_rects[alias_id] = alias_rects.get(room_source_id, {})
		alias_layout["object_rects"] = alias_rects
		alias_layout["slot_binding_digest"] = EnvironmentSlotBinderScript.binding_digest(alias_bindings)
		var alias_environment := environment.duplicate(true)
		alias_environment["layout"] = alias_layout
		var alias_record := production_record.duplicate(true)
		alias_record["object_id"] = alias_id
		alias_record["source_id"] = source_id
		alias_record["placement_class"] = str(alias_binding.get("placement_class", ""))
		alias_record["slot_binding_source_id"] = room_source_id
		if not bool(EnvironmentSlotBinderScript.validate_base_layout_authority(alias_environment, [alias_record]).get("ok", false)):
			failures.append("RW06-1 explicit current slot-binding alias was rejected.")
		var unaliased_record := alias_record.duplicate(true)
		unaliased_record.erase("slot_binding_source_id")
		if bool(EnvironmentSlotBinderScript.validate_base_layout_authority(alias_environment, [unaliased_record]).get("ok", true)):
			failures.append("RW06-1 duplicate room slot without an explicit current alias was accepted.")


func _check_capacity_simplification_action_reachability() -> void:
	var gas_ids: Array[String] = [
		"event:scenario_graveyard_maintenance",
		"event:side_door",
		"travel:back_alley",
		"travel:corner_store",
		"travel:delta_queen",
		"travel:grand_casino",
		"travel:kitty_cat_lounge",
		"travel:leave",
	]
	var gas_records: Array = []
	for object_id in gas_ids:
		gas_records.append(_capacity_action_record(
			object_id,
			"event" if object_id.begins_with("event:") else "travel",
			"doorway"
		))
	var gas_environment := {"archetype_id": "gas_station_casino"}
	var gas_first := EnvironmentSlotBinderScript.bind_base_records(gas_environment, gas_records)
	var gas_second := EnvironmentSlotBinderScript.bind_base_records(gas_environment, gas_records)
	if not bool(gas_first.get("ok", false)) or not bool(gas_second.get("ok", false)):
		failures.append("RW06-1 Gas Station capacity regression could not bind its multi-travel composition: %s." % JSON.stringify(gas_first.get("errors", [])))
	else:
		var gas_bindings := gas_first.get("slot_bindings", {}) as Dictionary
		var gas_overflow := gas_first.get("overflow_ids", []) as Array
		if JSON.stringify(gas_bindings) != JSON.stringify(gas_second.get("slot_bindings", {})) \
				or JSON.stringify(gas_overflow) != JSON.stringify(gas_second.get("overflow_ids", [])):
			failures.append("RW06-1 Gas Station multi-travel binding is not deterministic.")
		var gas_room_ids: Array[String] = []
		for object_id in gas_ids:
			var binding := gas_bindings.get(object_id, {}) as Dictionary
			if str(binding.get("presentation_mode", "")) == "room":
				gas_room_ids.append(object_id)
		if gas_room_ids != ["event:scenario_graveyard_maintenance"] \
				or str((gas_bindings.get("event:scenario_graveyard_maintenance", {}) as Dictionary).get("slot_id", "")) != "base.door_left_middle" \
				or gas_overflow.size() != gas_ids.size() - 1:
			failures.append("RW06-1 Gas Station must bind one retained doorway and route every remaining travel record to authenticated overflow: rooms=%s overflow=%s." % [JSON.stringify(gas_room_ids), JSON.stringify(gas_overflow)])
		_check_capacity_action_records("Gas Station", gas_first.get("records", []) as Array, gas_ids)

	var jazz_records: Array = [_capacity_action_record("travel:leave", "travel", "doorway")]
	var jazz_ids: Array[String] = ["travel:leave"]
	for index in range(5):
		var object_id := "travel:jazz_capacity_%d" % index
		var record := _capacity_action_record(object_id, "travel", "doorway")
		record["layout_spot_field"] = "travel_spots"
		record["layout_index"] = index
		jazz_records.append(record)
		jazz_ids.append(object_id)
	var jazz_environment := {"archetype_id": "jazz_club"}
	var jazz_first := EnvironmentSlotBinderScript.bind_base_records(jazz_environment, jazz_records)
	var jazz_second := EnvironmentSlotBinderScript.bind_base_records(jazz_environment, jazz_records)
	if not bool(jazz_first.get("ok", false)) or not bool(jazz_second.get("ok", false)):
		failures.append("RW06-1 Jazz Club capacity regression could not bind its multi-travel composition: %s." % JSON.stringify(jazz_first.get("errors", [])))
	else:
		var jazz_bindings := jazz_first.get("slot_bindings", {}) as Dictionary
		var jazz_overflow := jazz_first.get("overflow_ids", []) as Array
		if JSON.stringify(jazz_bindings) != JSON.stringify(jazz_second.get("slot_bindings", {})) \
				or JSON.stringify(jazz_overflow) != JSON.stringify(jazz_second.get("overflow_ids", [])):
			failures.append("RW06-1 Jazz Club multi-travel binding is not deterministic.")
		var jazz_room_ids: Array[String] = []
		for object_id in jazz_ids:
			var binding := jazz_bindings.get(object_id, {}) as Dictionary
			if str(binding.get("presentation_mode", "")) == "room":
				jazz_room_ids.append(object_id)
				if str(binding.get("slot_id", "")) != "base.door_right_upper":
					failures.append("RW06-1 Jazz Club travel record escaped the retained upper doorway: %s." % JSON.stringify(binding))
		if jazz_room_ids.size() != 1 or jazz_overflow.size() != jazz_ids.size() - 1:
			failures.append("RW06-1 Jazz Club must bind one retained doorway and route every remaining travel record to authenticated overflow: rooms=%s overflow=%s." % [JSON.stringify(jazz_room_ids), JSON.stringify(jazz_overflow)])
		_check_capacity_action_records("Jazz Club", jazz_first.get("records", []) as Array, jazz_ids)

	var delta_records: Array = [
		_capacity_action_record("event:scenario_captains_invitational_card", "event", "surface_item"),
		_capacity_action_record("event:grand_casino_invite", "event", "wall_mounted"),
		_capacity_action_record("event:scenario_engine_trouble_repairs", "event", "wall_mounted"),
		_capacity_action_record("event:scenario_whale_aboard_vouch", "event", "wall_mounted"),
		_capacity_action_record("item:payment_calendar", "item", "wall_mounted"),
	]
	var delta_ids: Array[String] = []
	for record_value in delta_records:
		delta_ids.append(str((record_value as Dictionary).get("object_id", "")))
	var delta_environment := {"archetype_id": "delta_queen"}
	var delta_first := EnvironmentSlotBinderScript.bind_base_records(delta_environment, delta_records)
	var delta_second := EnvironmentSlotBinderScript.bind_base_records(delta_environment, delta_records)
	if not bool(delta_first.get("ok", false)) or not bool(delta_second.get("ok", false)):
		failures.append("RW06-1 Delta Queen wall-capacity regression could not bind its co-present fixtures: %s." % JSON.stringify(delta_first.get("errors", [])))
		return
	var delta_bindings := delta_first.get("slot_bindings", {}) as Dictionary
	var delta_overflow := delta_first.get("overflow_ids", []) as Array
	if JSON.stringify(delta_bindings) != JSON.stringify(delta_second.get("slot_bindings", {})) \
			or JSON.stringify(delta_overflow) != JSON.stringify(delta_second.get("overflow_ids", [])):
		failures.append("RW06-1 Delta Queen co-presence binding is not deterministic.")
	var wall_room_ids: Array[String] = []
	for object_id in delta_ids:
		var binding := delta_bindings.get(object_id, {}) as Dictionary
		if str(binding.get("slot_id", "")) == "base.event_wall_1":
			wall_room_ids.append(object_id)
	var table_binding := delta_bindings.get("event:scenario_captains_invitational_card", {}) as Dictionary
	if wall_room_ids != ["event:grand_casino_invite"] \
			or str(table_binding.get("presentation_mode", "")) != "room" \
			or str(table_binding.get("slot_id", "")) != "base.event_table_1" \
			or delta_overflow.size() != 3:
		failures.append("RW06-1 Delta Queen must preserve event_table_1 independently while one wall record stays in-room and three retain overflow actions: wall=%s table=%s overflow=%s." % [JSON.stringify(wall_room_ids), JSON.stringify(table_binding), JSON.stringify(delta_overflow)])
	_check_capacity_action_records("Delta Queen", delta_first.get("records", []) as Array, delta_ids)


func _capacity_action_record(object_id: String, object_type: String, placement_class: String) -> Dictionary:
	var action_suffix := object_id.replace(":", "_")
	return {
		"object_id": object_id,
		"object_type": object_type,
		"placement_class": placement_class,
		"label": object_id,
		"presentation_required": true,
		"visible": true,
		"interactive": true,
		"enabled": true,
		"available_actions": [
			{
				"id": "visible_%s" % action_suffix,
				"emit_object_id": "capacity_action:visible:%s" % action_suffix,
				"label": "Use %s" % object_id,
			},
			{
				"id": "hidden_%s" % action_suffix,
				"emit_object_id": "capacity_action:hidden:%s" % action_suffix,
				"label": "Hidden %s" % object_id,
				"hidden_only": true,
			},
		],
	}


func _check_capacity_action_records(label: String, records: Array, expected_ids: Array[String]) -> void:
	var seen: Dictionary = {}
	for record_value in records:
		var record := record_value as Dictionary
		var object_id := str(record.get("object_id", ""))
		if not expected_ids.has(object_id):
			continue
		seen[object_id] = true
		var action_suffix := object_id.replace(":", "_")
		var entries := RoomActionListScript.action_entries_for_record(record)
		if entries.size() != 1 \
				or str((entries[0] as Dictionary).get("emit_object_id", "")) != "capacity_action:visible:%s" % action_suffix:
			failures.append("RW06-1 %s record %s lost its independent visible action or exposed hidden-only state: %s." % [label, object_id, JSON.stringify(entries)])
		if str(record.get("presentation_mode", "")) == "overflow" \
				and (not (record.get("normalized_rect", {}) as Dictionary).is_empty() \
				or not (record.get("focus_rect", {}) as Dictionary).is_empty()):
			failures.append("RW06-1 %s overflow record %s retained forged room geometry." % [label, object_id])
	if seen.size() != expected_ids.size():
		failures.append("RW06-1 %s capacity regression omitted records: expected=%s seen=%s." % [label, JSON.stringify(expected_ids), JSON.stringify(seen.keys())])


func _check_canonical_expanded_target() -> void:
	var canonical := Vector2(ArtContractsScript.ENVIRONMENT_OBJECT_HIT_SIZE)
	var expanded := EnvironmentSlotBinderScript.expanded_rect(Rect2(200.0, 200.0, 44.0, 44.0))
	if expanded.size != canonical or Vector2(ScenarioLayoutResolverScript.SMALL_SCREEN_TARGET) != canonical:
		failures.append("RW06-1 expanded slot authority diverges from ArtContracts: binder=%s resolver=%s canonical=%s." % [expanded.size, ScenarioLayoutResolverScript.SMALL_SCREEN_TARGET, canonical])


func _check_authority_geometry_round_trip() -> void:
	var edge_rect := {
		"x": (900.0 - 44.0) / 900.0,
		"y": (430.0 - 44.0) / 430.0,
		"w": 44.0 / 900.0,
		"h": 44.0 / 430.0,
	}
	var label_rect := {"x": 0.8, "y": 0.8, "w": 0.1, "h": 0.05}
	var authority_record := {
		"actor_route_points": [],
		"actor_route_stage": {},
		"contact": "base",
		"identity": "base::edge_round_trip",
		"label_rect": label_rect.duplicate(true),
		"normalized_hit_rect": edge_rect.duplicate(true),
		"placement_class": "floor_fixture",
		"presentation_interactive": true,
		"presentation_mode": "room",
		"presentation_object_id": "game:edge_round_trip",
		"presentation_required": true,
		"presentation_visible": true,
		"semantic_actor_member": false,
		"semantic_interaction_member": true,
		"semantic_scene_object_member": true,
		"slot_id": "edge.slot",
		"small_screen_label_rect": label_rect.duplicate(true),
		"small_screen_rect": edge_rect.duplicate(true),
		"source": "sealed_base_record",
		"visual_kind": "base_record",
		"z_order": 0,
	}
	var edge_errors: Array = []
	ScenarioLayoutResolverScript._validate_authority({"base::edge_round_trip": authority_record}, edge_errors)
	if not edge_errors.is_empty():
		failures.append("RW06-1 exact board-edge normalized round trip was rejected: %s." % JSON.stringify(edge_errors))
	var forged := authority_record.duplicate(true)
	var forged_rect := edge_rect.duplicate(true)
	forged_rect["x"] = float(forged_rect.get("x", 0.0)) + 0.01
	forged["normalized_hit_rect"] = forged_rect
	var forged_errors: Array = []
	ScenarioLayoutResolverScript._validate_authority({"base::edge_round_trip": forged}, forged_errors)
	if forged_errors.is_empty():
		failures.append("RW06-1 beyond-epsilon board geometry survived sealed authority validation.")
	var overflow_record := {
		"owner_namespace": "base",
		"stable_object_id": "overflow_round_trip",
		"object_id": "game:overflow_round_trip",
		"object_type": "game",
		"presentation_mode": "overflow",
		"visible": true,
		"interactive": true,
		"focus_rect": {},
		"label_rect": {},
		"small_screen_rect": {},
		"small_screen_label_rect": {},
	}
	var overflow_build_errors: Array = []
	var overflow_authority := ScenarioLayoutResolverScript._base_layout_authority([overflow_record], overflow_build_errors)
	var sealed_overflow := overflow_authority.get("base::overflow_round_trip", {}) as Dictionary
	var overflow_validation_errors: Array = []
	ScenarioLayoutResolverScript._validate_authority(overflow_authority, overflow_validation_errors)
	for rect_key in ["normalized_hit_rect", "small_screen_rect", "label_rect", "small_screen_label_rect"]:
		if not (sealed_overflow.get(rect_key, {}) as Dictionary).is_empty():
			overflow_build_errors.append("Overflow authority retained %s geometry." % rect_key)
	if not overflow_build_errors.is_empty() or not overflow_validation_errors.is_empty():
		failures.append("RW06-1 geometry-free overflow authority did not survive build/validation: %s." % JSON.stringify({
			"build_errors": overflow_build_errors,
			"validation_errors": overflow_validation_errors,
			"authority": sealed_overflow,
		}))


func _check_late_binding_persistence(app: Control, production_record: Dictionary) -> void:
	var run_state: Variant = app.get("run_state")
	if run_state == null:
		failures.append("RW06-1 late overflow reload regression lacks RunState.")
		return
	var original_snapshot: Dictionary = run_state.to_dict()
	var environment := (run_state.get("current_environment") as Dictionary).duplicate(true)
	var layout := (environment.get("layout", {}) as Dictionary).duplicate(true)
	var source_id := str(production_record.get("source_id", "")).strip_edges()
	if source_id.is_empty():
		var parts := str(production_record.get("object_id", "")).split(":", false)
		if parts.size() >= 2:
			source_id = str(parts[1])
	var records: Array = []
	var late_ids: Array = []
	var late_count := 64
	for index in range(late_count):
		var record := production_record.duplicate(true)
		var object_id := "game:%s:%d" % [source_id, index + 100]
		record["object_id"] = object_id
		record["source_id"] = source_id
		record.erase("slot_binding_source_id")
		records.append(record)
		late_ids.append(object_id)
	var binding_environment := environment.duplicate(true)
	binding_environment["layout"] = layout
	var binding := EnvironmentSlotBinderScript.bind_base_records(
		binding_environment,
		records,
		layout.get("slot_bindings", {}) as Dictionary
	)
	var overflow_ids := binding.get("overflow_ids", []) as Array
	var late_overflow_id := ""
	for object_id_value in late_ids:
		if overflow_ids.has(object_id_value):
			late_overflow_id = str(object_id_value)
			break
	if late_overflow_id.is_empty():
		failures.append("RW06-1 late production records did not exercise fixed-slot overflow.")
		run_state.from_dict(original_snapshot)
		return
	var committed_layout := EnvironmentInteractionControllerScript.commit_base_record_binding(run_state, layout, binding)
	var committed_digest := str(committed_layout.get("slot_binding_digest", ""))
	var committed_snapshot: Dictionary = run_state.to_dict()
	run_state.from_dict(committed_snapshot)
	var reloaded_environment := run_state.get("current_environment") as Dictionary
	var reloaded_layout := reloaded_environment.get("layout", {}) as Dictionary
	if not (reloaded_layout.get("slot_overflow_ids", []) as Array).has(late_overflow_id) \
			or str(reloaded_layout.get("slot_binding_digest", "")) != committed_digest \
			or str(((reloaded_layout.get("slot_bindings", {}) as Dictionary).get(late_overflow_id, {}) as Dictionary).get("presentation_mode", "")) != "overflow":
		failures.append("RW06-1 late overflow binding authority did not survive RunState reload.")
	_check_controller_authority_rejection(app, original_snapshot)
	_check_terminal_service_refresh(app, original_snapshot)
	run_state.from_dict(original_snapshot)
	_invalidate_interactable_caches(app)


func _check_controller_authority_rejection(app: Control, baseline_snapshot: Dictionary) -> void:
	var run_state: Variant = app.get("run_state")
	run_state.from_dict(baseline_snapshot.duplicate(true))
	_invalidate_interactable_caches(app)
	app.call("_interactable_object_view_list")
	var stable_snapshot: Dictionary = run_state.to_dict()
	_check_cache_key_authority_rotation(app, stable_snapshot)
	var environment := (run_state.get("current_environment") as Dictionary).duplicate(true)
	var layout := (environment.get("layout", {}) as Dictionary).duplicate(true)
	var room_id := ""
	for binding_id_value in (layout.get("slot_bindings", {}) as Dictionary).keys():
		if str(((layout.get("slot_bindings", {}) as Dictionary).get(binding_id_value, {}) as Dictionary).get("presentation_mode", "")) == "room":
			room_id = str(binding_id_value)
			break
	if room_id.is_empty():
		failures.append("RW06-1 controller hostile-authority regression found no room binding.")
		return
	var hostile_layouts: Dictionary = {}
	var missing_digest := layout.duplicate(true)
	missing_digest.erase("slot_binding_digest")
	hostile_layouts["missing digest"] = missing_digest
	var stale_digest := layout.duplicate(true)
	stale_digest["slot_binding_digest"] = "f".repeat(64)
	hostile_layouts["stale digest"] = stale_digest
	var wrong_schema := layout.duplicate(true)
	wrong_schema["slot_schema_version"] = int(layout.get("slot_schema_version", 0)) + 1
	hostile_layouts["wrong schema"] = wrong_schema
	var wrong_map := layout.duplicate(true)
	wrong_map["slot_map_digest"] = "f".repeat(64)
	hostile_layouts["wrong map digest"] = wrong_map
	var wrong_kind := layout.duplicate(true)
	var wrong_kind_bindings := (wrong_kind.get("slot_bindings", {}) as Dictionary).duplicate(true)
	(wrong_kind_bindings[room_id] as Dictionary)["kind"] = "stage"
	wrong_kind["slot_bindings"] = wrong_kind_bindings
	wrong_kind["slot_binding_digest"] = EnvironmentSlotBinderScript.binding_digest(wrong_kind_bindings)
	hostile_layouts["wrong kind"] = wrong_kind
	var open_binding := layout.duplicate(true)
	var open_bindings := (open_binding.get("slot_bindings", {}) as Dictionary).duplicate(true)
	var open_room_binding := (open_bindings.get(room_id, {}) as Dictionary).duplicate(true)
	open_room_binding["forged"] = true
	open_bindings[room_id] = open_room_binding
	open_binding["slot_bindings"] = open_bindings
	open_binding["slot_binding_digest"] = EnvironmentSlotBinderScript.binding_digest(open_bindings)
	hostile_layouts["open binding schema"] = open_binding
	var wrong_class := layout.duplicate(true)
	var wrong_class_bindings := (wrong_class.get("slot_bindings", {}) as Dictionary).duplicate(true)
	var wrong_class_binding := wrong_class_bindings.get(room_id, {}) as Dictionary
	wrong_class_binding["placement_class"] = "standing_person" if str(wrong_class_binding.get("placement_class", "")) != "standing_person" else "floor_fixture"
	wrong_class_bindings[room_id] = wrong_class_binding
	wrong_class["slot_bindings"] = wrong_class_bindings
	wrong_class["slot_binding_digest"] = EnvironmentSlotBinderScript.binding_digest(wrong_class_bindings)
	hostile_layouts["wrong class"] = wrong_class
	var wrong_slot := layout.duplicate(true)
	var wrong_slot_bindings := (wrong_slot.get("slot_bindings", {}) as Dictionary).duplicate(true)
	var wrong_slot_binding := wrong_slot_bindings.get(room_id, {}) as Dictionary
	wrong_slot_binding["slot_id"] = "forged.slot"
	wrong_slot_binding["slot"] = {"id": "forged.slot", "footprint_class": str(wrong_slot_binding.get("placement_class", "")), "hit_rect": [10, 10, 44, 44]}
	wrong_slot_bindings[room_id] = wrong_slot_binding
	wrong_slot["slot_bindings"] = wrong_slot_bindings
	wrong_slot["slot_binding_digest"] = EnvironmentSlotBinderScript.binding_digest(wrong_slot_bindings)
	hostile_layouts["wrong slot"] = wrong_slot
	var forged_membership := layout.duplicate(true)
	var forged_membership_ids := (forged_membership.get("slot_overflow_ids", []) as Array).duplicate(true)
	forged_membership_ids.append(room_id)
	forged_membership_ids.sort()
	forged_membership["slot_overflow_ids"] = forged_membership_ids
	hostile_layouts["overflow membership"] = forged_membership
	var wrong_rect := layout.duplicate(true)
	var wrong_rects := (wrong_rect.get("object_rects", {}) as Dictionary).duplicate(true)
	var mutated_rect := (wrong_rects.get(room_id, {}) as Dictionary).duplicate(true)
	mutated_rect["x"] = float(mutated_rect.get("x", 0.0)) + 0.001
	wrong_rects[room_id] = mutated_rect
	wrong_rect["object_rects"] = wrong_rects
	hostile_layouts["object_rect mismatch"] = wrong_rect
	var duplicate_slot := layout.duplicate(true)
	var duplicate_bindings := (duplicate_slot.get("slot_bindings", {}) as Dictionary).duplicate(true)
	var duplicate_id := "%s:forged_duplicate" % room_id
	var duplicate_binding := (duplicate_bindings.get(room_id, {}) as Dictionary).duplicate(true)
	duplicate_binding["identity"] = duplicate_id
	duplicate_bindings[duplicate_id] = duplicate_binding
	duplicate_slot["slot_bindings"] = duplicate_bindings
	var duplicate_rects := (duplicate_slot.get("object_rects", {}) as Dictionary).duplicate(true)
	duplicate_rects[duplicate_id] = duplicate_rects.get(room_id, {})
	duplicate_slot["object_rects"] = duplicate_rects
	duplicate_slot["slot_binding_digest"] = EnvironmentSlotBinderScript.binding_digest(duplicate_bindings)
	hostile_layouts["duplicate room slot"] = duplicate_slot
	for label_value in hostile_layouts.keys():
		run_state.from_dict(stable_snapshot.duplicate(true))
		var hostile_environment := (run_state.get("current_environment") as Dictionary).duplicate(true)
		hostile_environment["layout"] = hostile_layouts.get(label_value)
		run_state.set("current_environment", hostile_environment)
		var before := JSON.stringify(run_state.get("current_environment"))
		_invalidate_interactable_caches(app)
		app.call("_interactable_object_view_list")
		var after := JSON.stringify(run_state.get("current_environment"))
		if after != before:
			failures.append("RW06-1 controller mutated or healed %s base authority." % str(label_value))
	run_state.from_dict(stable_snapshot)
	_invalidate_interactable_caches(app)


func _check_cache_key_authority_rotation(app: Control, stable_snapshot: Dictionary) -> void:
	var run_state: Variant = app.get("run_state")
	run_state.from_dict(stable_snapshot.duplicate(true))
	var baseline_key := str(app.call("_interactable_object_cache_key"))
	var stable_environment := run_state.get("current_environment") as Dictionary
	var stable_layout := stable_environment.get("layout", {}) as Dictionary
	var mutations := {
		"slot schema version": int(stable_layout.get("slot_schema_version", 0)) + 1,
		"slot map digest": "cache-key-map-mutation",
		"slot binding digest": "cache-key-binding-mutation",
		"slot overflow ids": ["cache-key-overflow-mutation"],
	}
	var fields := {
		"slot schema version": "slot_schema_version",
		"slot map digest": "slot_map_digest",
		"slot binding digest": "slot_binding_digest",
		"slot overflow ids": "slot_overflow_ids",
	}
	for label_value in fields.keys():
		run_state.from_dict(stable_snapshot.duplicate(true))
		var environment := (run_state.get("current_environment") as Dictionary).duplicate(true)
		var layout := (environment.get("layout", {}) as Dictionary).duplicate(true)
		layout[str(fields.get(label_value))] = mutations.get(label_value)
		environment["layout"] = layout
		run_state.set("current_environment", environment)
		if str(app.call("_interactable_object_cache_key")) == baseline_key:
			failures.append("RW06-1 interactable catalog cache key ignored %s authority." % str(label_value))
	run_state.from_dict(stable_snapshot.duplicate(true))


func _check_terminal_service_refresh(app: Control, baseline_snapshot: Dictionary) -> void:
	var run_state: Variant = app.get("run_state")
	var library: Variant = app.get("library")
	if run_state == null or library == null:
		failures.append("RW06-1 terminal-service refresh regression lacks production state/library authority.")
		return
	run_state.from_dict(baseline_snapshot.duplicate(true))
	_invalidate_interactable_caches(app)
	app.call("_interactable_object_view_list")
	var environment := run_state.get("current_environment") as Dictionary
	var layout := environment.get("layout", {}) as Dictionary
	var bindings := layout.get("slot_bindings", {}) as Dictionary
	var object_rects := layout.get("object_rects", {}) as Dictionary
	var service_source_id := ""
	var service_object_id := ""
	var installed_service_ids := environment.get("service_ids", []) as Array
	for service_id_value in installed_service_ids:
		var candidate_source_id := str(service_id_value)
		var candidate_object_id := "service:%s" % candidate_source_id
		var candidate_binding := bindings.get(candidate_object_id, {}) as Dictionary
		if not candidate_binding.is_empty():
			service_source_id = candidate_source_id
			service_object_id = candidate_object_id
			break
	if service_object_id.is_empty():
		failures.append("RW06-1 terminal-service refresh found no live production service binding.")
		run_state.from_dict(baseline_snapshot.duplicate(true))
		return
	# The deterministic Bar may initially overflow its drink behind a room-bound
	# surface game. Swap those same-class authorities so the first half exercises
	# a real room reservation; both records remain production controller inputs.
	var service_binding := bindings.get(service_object_id, {}) as Dictionary
	if str(service_binding.get("presentation_mode", "")) != "room" or not object_rects.has(service_object_id):
		var donor_id := ""
		for binding_id_value in bindings.keys():
			var candidate_id := str(binding_id_value)
			var candidate_binding := bindings.get(candidate_id, {}) as Dictionary
			if candidate_id != service_object_id \
					and str(candidate_binding.get("presentation_mode", "")) == "room" \
					and str(candidate_binding.get("placement_class", "")) == str(service_binding.get("placement_class", "")) \
					and object_rects.has(candidate_id):
				donor_id = candidate_id
				break
		if donor_id.is_empty():
			failures.append("RW06-1 terminal-service refresh found no same-class production room donor.")
			run_state.from_dict(baseline_snapshot.duplicate(true))
			return
		var swapped_environment := environment.duplicate(true)
		var swapped_layout := (swapped_environment.get("layout", {}) as Dictionary).duplicate(true)
		var swapped_bindings := (swapped_layout.get("slot_bindings", {}) as Dictionary).duplicate(true)
		var donor_binding := (swapped_bindings.get(donor_id, {}) as Dictionary).duplicate(true)
		var room_service_binding := donor_binding.duplicate(true)
		room_service_binding["identity"] = service_object_id
		var overflow_donor_binding := service_binding.duplicate(true)
		overflow_donor_binding["identity"] = donor_id
		overflow_donor_binding["presentation_mode"] = "overflow"
		overflow_donor_binding["slot_id"] = ""
		overflow_donor_binding["slot"] = {}
		swapped_bindings[service_object_id] = room_service_binding
		swapped_bindings[donor_id] = overflow_donor_binding
		var swapped_rects := (swapped_layout.get("object_rects", {}) as Dictionary).duplicate(true)
		swapped_rects[service_object_id] = swapped_rects.get(donor_id, {})
		swapped_rects.erase(donor_id)
		var swapped_overflow_ids := (swapped_layout.get("slot_overflow_ids", []) as Array).duplicate(true)
		swapped_overflow_ids.erase(service_object_id)
		if not swapped_overflow_ids.has(donor_id): swapped_overflow_ids.append(donor_id)
		swapped_overflow_ids.sort()
		swapped_layout["slot_bindings"] = swapped_bindings
		swapped_layout["slot_overflow_ids"] = swapped_overflow_ids
		swapped_layout["slot_binding_digest"] = EnvironmentSlotBinderScript.binding_digest(swapped_bindings)
		swapped_layout["object_rects"] = swapped_rects
		swapped_environment["layout"] = swapped_layout
		var swapped_authority := EnvironmentSlotBinderScript.validate_base_layout_authority(swapped_environment)
		if not bool(swapped_authority.get("ok", false)):
			failures.append("RW06-1 could not construct a valid production room service fixture: %s." % JSON.stringify(swapped_authority.get("errors", [])))
			run_state.from_dict(baseline_snapshot.duplicate(true))
			return
		run_state.set("current_environment", swapped_environment)
		_invalidate_interactable_caches(app)
		app.call("_interactable_object_view_list")
		environment = run_state.get("current_environment") as Dictionary
		layout = environment.get("layout", {}) as Dictionary
		bindings = layout.get("slot_bindings", {}) as Dictionary
		object_rects = layout.get("object_rects", {}) as Dictionary
		service_binding = bindings.get(service_object_id, {}) as Dictionary
	if str(service_binding.get("presentation_mode", "")) != "room" or not object_rects.has(service_object_id):
		failures.append("RW06-1 terminal-service room fixture did not survive the production controller.")
		run_state.from_dict(baseline_snapshot.duplicate(true))
		return
	var stable_snapshot: Dictionary = run_state.to_dict()
	var definition: Dictionary = library.call("service", service_source_id)
	var category := str(definition.get("category", "")).strip_edges()
	if category.is_empty():
		failures.append("RW06-1 terminal-service refresh found no catalog category for %s." % service_source_id)
		run_state.from_dict(baseline_snapshot.duplicate(true))
		return

	# The service remains installed in the environment while challenge category
	# availability removes it from the complete live interaction refresh.
	_set_blocked_service_category(run_state, category)
	var service_options := app.call("_service_hook_view_list") as Array
	for option_value in service_options:
		if typeof(option_value) == TYPE_DICTIONARY and str((option_value as Dictionary).get("id", "")) == service_source_id:
			failures.append("RW06-1 blocked service category did not hide %s from the production service view." % service_source_id)
			break
	_invalidate_interactable_caches(app)
	var room_refresh_records := app.call("_interactable_object_view_list") as Array
	if not _record_by_object_id(room_refresh_records, service_object_id).is_empty():
		failures.append("RW06-1 categorical-unavailable room service survived the production controller refresh.")
	_assert_terminal_service_state(run_state, library, service_source_id, service_object_id, true, "room refresh", room_refresh_records)
	var room_committed_snapshot: Dictionary = run_state.to_dict()
	run_state.from_dict(room_committed_snapshot.duplicate(true))
	_invalidate_interactable_caches(app)
	var room_reload_records := app.call("_interactable_object_view_list") as Array
	_assert_terminal_service_records(room_reload_records, service_object_id, "room reload")
	_assert_terminal_service_state(run_state, library, service_source_id, service_object_id, true, "room reload", room_reload_records)
	_revisit_terminal_service_environment(app, service_source_id, service_object_id, true, library, "room revisit")

	# Exercise the same actual refresh starting from valid geometry-free overflow
	# authority. Unlike a room reservation, absent overflow has nothing durable to
	# reserve and must be removed from the envelope completely.
	run_state.from_dict(stable_snapshot.duplicate(true))
	var overflow_environment := (run_state.get("current_environment") as Dictionary).duplicate(true)
	var overflow_layout := (overflow_environment.get("layout", {}) as Dictionary).duplicate(true)
	var overflow_bindings := (overflow_layout.get("slot_bindings", {}) as Dictionary).duplicate(true)
	var overflow_binding := (overflow_bindings.get(service_object_id, {}) as Dictionary).duplicate(true)
	overflow_binding["presentation_mode"] = "overflow"
	overflow_binding["slot_id"] = ""
	overflow_binding["slot"] = {}
	overflow_bindings[service_object_id] = overflow_binding
	var overflow_rects := (overflow_layout.get("object_rects", {}) as Dictionary).duplicate(true)
	overflow_rects.erase(service_object_id)
	var overflow_ids := (overflow_layout.get("slot_overflow_ids", []) as Array).duplicate(true)
	if not overflow_ids.has(service_object_id): overflow_ids.append(service_object_id)
	overflow_ids.sort()
	overflow_layout["slot_bindings"] = overflow_bindings
	overflow_layout["slot_overflow_ids"] = overflow_ids
	overflow_layout["slot_binding_digest"] = EnvironmentSlotBinderScript.binding_digest(overflow_bindings)
	overflow_layout["object_rects"] = overflow_rects
	overflow_environment["layout"] = overflow_layout
	var overflow_authority := EnvironmentSlotBinderScript.validate_base_layout_authority(overflow_environment)
	if not bool(overflow_authority.get("ok", false)):
		failures.append("RW06-1 could not construct valid production overflow service authority: %s." % JSON.stringify(overflow_authority.get("errors", [])))
		run_state.from_dict(baseline_snapshot.duplicate(true))
		return
	run_state.set("current_environment", overflow_environment)
	_set_blocked_service_category(run_state, category)
	_invalidate_interactable_caches(app)
	var overflow_refresh_records := app.call("_interactable_object_view_list") as Array
	if not _record_by_object_id(overflow_refresh_records, service_object_id).is_empty():
		failures.append("RW06-1 categorical-unavailable overflow service survived the production controller refresh.")
	_assert_terminal_service_state(run_state, library, service_source_id, service_object_id, false, "overflow refresh", overflow_refresh_records)
	var overflow_committed_snapshot: Dictionary = run_state.to_dict()
	run_state.from_dict(overflow_committed_snapshot.duplicate(true))
	_invalidate_interactable_caches(app)
	var overflow_reload_records := app.call("_interactable_object_view_list") as Array
	_assert_terminal_service_records(overflow_reload_records, service_object_id, "overflow reload")
	_assert_terminal_service_state(run_state, library, service_source_id, service_object_id, false, "overflow reload", overflow_reload_records)
	_revisit_terminal_service_environment(app, service_source_id, service_object_id, false, library, "overflow revisit")
	run_state.from_dict(baseline_snapshot.duplicate(true))
	_invalidate_interactable_caches(app)


func _revisit_terminal_service_environment(app: Control, service_source_id: String, service_object_id: String, preserve_room_binding: bool, library: Variant, label: String) -> void:
	var run_state: Variant = app.get("run_state")
	var revisit_environment := (run_state.get("current_environment") as Dictionary).duplicate(true)
	revisit_environment["departed_game_clock_minutes"] = int(revisit_environment.get("entered_game_clock_minutes", 0))
	var installation: Dictionary = run_state.call("set_environment", revisit_environment)
	if not bool(installation.get("ok", false)):
		failures.append("RW06-1 %s could not reinstall the production environment: %s." % [label, JSON.stringify(installation.get("errors", []))])
		return
	_invalidate_interactable_caches(app)
	var revisit_records := app.call("_interactable_object_view_list") as Array
	_assert_terminal_service_records(revisit_records, service_object_id, label)
	_assert_terminal_service_state(run_state, library, service_source_id, service_object_id, preserve_room_binding, label, revisit_records)


func _assert_terminal_service_records(records: Array, service_object_id: String, label: String) -> void:
	if not _record_by_object_id(records, service_object_id).is_empty():
		failures.append("RW06-1 %s resurrected the categorically unavailable service through the production controller." % label)


func _assert_terminal_service_state(run_state: Variant, _library: Variant, service_source_id: String, service_object_id: String, preserve_room_binding: bool, label: String, records: Array) -> void:
	var environment := run_state.get("current_environment") as Dictionary
	var layout := environment.get("layout", {}) as Dictionary
	var bindings := layout.get("slot_bindings", {}) as Dictionary
	var overflow_ids := layout.get("slot_overflow_ids", []) as Array
	var object_rects := layout.get("object_rects", {}) as Dictionary
	if not (environment.get("service_ids", []) as Array).has(service_source_id):
		failures.append("RW06-1 %s removed the categorically unavailable service from environment.service_ids." % label)
	if preserve_room_binding:
		var binding := bindings.get(service_object_id, {}) as Dictionary
		if str(binding.get("presentation_mode", "")) != "room" or object_rects.has(service_object_id) or overflow_ids.has(service_object_id):
			failures.append("RW06-1 %s did not retain only the dormant room reservation: %s." % [label, JSON.stringify({
				"binding": binding,
				"has_rect": object_rects.has(service_object_id),
				"in_overflow": overflow_ids.has(service_object_id),
				"commit_diagnostics": _terminal_binding_diagnostics(environment, records, service_object_id),
			})])
	elif bindings.has(service_object_id) or object_rects.has(service_object_id) or overflow_ids.has(service_object_id):
		failures.append("RW06-1 %s retained absent overflow service authority: %s." % [label, JSON.stringify({
			"binding": bindings.get(service_object_id, {}),
			"has_rect": object_rects.has(service_object_id),
			"in_overflow": overflow_ids.has(service_object_id),
			"commit_diagnostics": _terminal_binding_diagnostics(environment, records, service_object_id),
		})])
	# Category availability is RunState authority; the environment-only semantic
	# constructor cannot infer it. Authenticate the persisted room/overflow envelope
	# here, while the surrounding assertions prove the real controller excludes the
	# service before and after reload/revisit.
	var authenticated := EnvironmentSlotBinderScript.validate_base_layout_authority(environment)
	if not bool(authenticated.get("ok", false)):
		failures.append("RW06-1 %s left unauthenticated terminal-service layout authority: %s." % [label, JSON.stringify(authenticated.get("errors", []))])


func _terminal_binding_diagnostics(environment: Dictionary, records: Array, service_object_id: String) -> Dictionary:
	var controller_errors: Array = []
	var binding_records: Array = []
	for record_value in records:
		if typeof(record_value) != TYPE_DICTIONARY:
			continue
		var record := record_value as Dictionary
		if str(record.get("object_id", "")) == "scenario::presentation_failure":
			controller_errors.append_array(record.get("scenario_projection_errors", []) as Array)
			continue
		binding_records.append(record)
	var layout := environment.get("layout", {}) as Dictionary
	var bindings := layout.get("slot_bindings", {}) as Dictionary
	var prior_authority := EnvironmentSlotBinderScript.validate_base_layout_authority(environment, binding_records, true)
	var rebinding := EnvironmentSlotBinderScript.bind_base_records(environment, binding_records, bindings)
	var diagnostics := {
		"controller_errors": controller_errors,
		"prior_authority_errors": prior_authority.get("errors", []),
		"rebinding_ok": bool(rebinding.get("ok", false)),
		"rebinding_errors": rebinding.get("errors", []),
	}
	if not bool(rebinding.get("ok", false)):
		return diagnostics
	var candidate_layout := layout.duplicate(true)
	candidate_layout["slot_schema_version"] = int(rebinding.get("slot_schema_version", 0))
	candidate_layout["slot_map_digest"] = str(rebinding.get("slot_map_digest", ""))
	candidate_layout["slot_bindings"] = (rebinding.get("slot_bindings", {}) as Dictionary).duplicate(true)
	candidate_layout["slot_overflow_ids"] = (rebinding.get("overflow_ids", []) as Array).duplicate(true)
	candidate_layout["slot_binding_digest"] = str(rebinding.get("binding_digest", ""))
	candidate_layout["object_rects"] = (rebinding.get("object_rects", {}) as Dictionary).duplicate(true)
	var candidate_environment := environment.duplicate(true)
	candidate_environment["layout"] = candidate_layout
	var candidate_authority := EnvironmentSlotBinderScript.validate_base_layout_authority(
		candidate_environment,
		rebinding.get("records", []) as Array
	)
	diagnostics["candidate_authority_errors"] = candidate_authority.get("errors", [])
	diagnostics["candidate_service_binding"] = (candidate_layout.get("slot_bindings", {}) as Dictionary).get(service_object_id, {})
	diagnostics["candidate_has_rect"] = (candidate_layout.get("object_rects", {}) as Dictionary).has(service_object_id)
	diagnostics["candidate_in_overflow"] = (candidate_layout.get("slot_overflow_ids", []) as Array).has(service_object_id)
	return diagnostics


func _set_blocked_service_category(run_state: Variant, category: String) -> void:
	var challenge := (run_state.get("challenge_config") as Dictionary).duplicate(true)
	var modifiers := (challenge.get("modifiers", {}) as Dictionary).duplicate(true)
	modifiers["blocked_service_categories"] = [category]
	challenge["modifiers"] = modifiers
	run_state.set("challenge_config", challenge)


func _invalidate_interactable_caches(app: Control) -> void:
	app.set("interactable_object_catalog_cache_valid", false)
	app.set("interactable_object_view_cache_valid", false)


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
			await _send_touch(global_position)
	await _settle_frames(3)
	if int(app.get("delivery_exit_focus_routes")) != control_focus_count + 1:
		failures.append("RW06-1 %s live control did not route to the real delivery-exit canvas target: %s." % [
			mode,
			JSON.stringify(_touch_route_diagnostics(global_position, canvas) if mode == "touch" else {}),
		])
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
			await _send_touch(global_position, true)
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
	var touch_diagnostics := _touch_route_diagnostics(button.get_global_rect().get_center(), button)
	await _send_touch(button.get_global_rect().get_center())
	await _settle_frames(8)
	var after_projection: Dictionary = run_state.call("scenario_sequence_projection")
	if str(after_projection.get("phase_id", "")) != "sorting" \
			or _scenario_command_receipt_count(run_state) != before_receipts + 1 \
			or activations.count(expected_key) != prior_count + 1 \
			or bool(action_list.call("is_open")):
		failures.append("RW06-1 shipping scenario_sequence action did not reach the real arrival-to-sorting mutation: %s." % JSON.stringify(touch_diagnostics))


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
	var touch_diagnostics := _touch_route_diagnostics(button.get_global_rect().get_center(), button) if mode == "touch" else {}
	match mode:
		"mouse":
			_send_mouse(button.get_global_rect().get_center())
		"touch":
			await _send_touch(button.get_global_rect().get_center())
		"keyboard":
			button.grab_focus()
			_send_key(KEY_ENTER)
		"controller":
			button.grab_focus()
			_send_joy_button(JOY_BUTTON_A)
	await _settle_frames(5)
	if activations.count(expected_key) != prior_count + 1:
		failures.append("RW06-1 %s did not activate the production overflow action exactly once: %s." % [mode, JSON.stringify(touch_diagnostics)])
	if str(app.get("current_screen")) != "GAME" or app.get("current_game") == null or _mutation_snapshot(app) == before:
		failures.append("RW06-1 %s overflow action did not reach a real production game-entry mutation: %s." % [mode, JSON.stringify(touch_diagnostics)])
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
				await _send_touch(disabled_button.get_global_rect().get_center())
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
	var static_finish := source.find("\nstatic func ", start + marker.length())
	if static_finish >= 0 and (finish < 0 or static_finish < finish):
		finish = static_finish
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
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.position = position
	pressed.global_position = position
	pressed.button_mask = MOUSE_BUTTON_MASK_LEFT
	pressed.pressed = true
	root.push_input(pressed, true)
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.position = position
	released.global_position = position
	released.button_mask = 0
	released.pressed = false
	root.push_input(released, true)


func _send_touch(position: Vector2, double_tap: bool = false) -> void:
	# Input.parse_input_event accepts screen/window coordinates, while every caller
	# resolves an exact logical canvas-global hit point. The root may be physically
	# tiny in headless mode (64x64 with a stretched 1280x720 canvas), so use Godot's
	# canonical Viewport transform instead of an ad-hoc size ratio.
	var screen_position := root.get_screen_transform() * position
	var pressed := InputEventScreenTouch.new()
	pressed.index = 0
	pressed.position = screen_position
	pressed.pressed = true
	pressed.double_tap = double_tap
	# Feed touch through Input so the engine's production touch-to-pointer path is
	# exercised. Viewport.push_input bypasses that emulation layer in headless runs.
	Input.parse_input_event(pressed)
	pressed = null
	await process_frame
	var released := InputEventScreenTouch.new()
	released.index = 0
	released.position = screen_position
	released.pressed = false
	released.double_tap = double_tap
	Input.parse_input_event(released)
	released = null
	await process_frame


func _isolate_touch_from_prior_mouse() -> void:
	# PixelSceneCanvas rejects mouse/touch pairs at the same point for 750 ms so
	# browsers cannot apply one physical gesture twice. Separate independent
	# modality fixtures beyond that production window instead of disabling it.
	await create_timer(TOUCH_MODALITY_ISOLATION_SECONDS).timeout


func _touch_route_diagnostics(position: Vector2, target: Control = null) -> Dictionary:
	var now_msec := Time.get_ticks_msec()
	var viewport_size := root.get_visible_rect().size
	var screen_position := root.get_screen_transform() * position
	var result := {
		"now_msec": now_msec,
		"logical_position": {"x": position.x, "y": position.y},
		"screen_position": {"x": screen_position.x, "y": screen_position.y},
		"screen_transform": str(root.get_screen_transform()),
		"root_size": {"x": root.size.x, "y": root.size.y},
		"viewport_size": {"x": viewport_size.x, "y": viewport_size.y},
		"emulate_mouse_from_touch": bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", false)),
		"emulate_touch_from_mouse": bool(ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false)),
	}
	if target != null:
		var target_rect := target.get_global_rect()
		result["target_rect"] = {
			"x": target_rect.position.x,
			"y": target_rect.position.y,
			"w": target_rect.size.x,
			"h": target_rect.size.y,
		}
		result["target_visible"] = target.is_visible_in_tree()
		result["target_mouse_filter"] = int(target.mouse_filter)
		if target.has_method("_touch_duplicates_recent_mouse_press"):
			var last_mouse_msec := int(target.get("last_mouse_press_msec"))
			var last_touch_msec := int(target.get("last_touch_press_msec"))
			result["last_mouse_press_msec"] = last_mouse_msec
			result["last_touch_press_msec"] = last_touch_msec
			result["elapsed_since_mouse_msec"] = now_msec - last_mouse_msec
			result["elapsed_since_touch_msec"] = now_msec - last_touch_msec
	return result


func _settle_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _finish(app: Control) -> void:
	var save_service: Variant = app.get("save_service")
	if save_service != null and bool(save_service.call("async_save_in_flight")):
		var save_error := int(save_service.call("wait_for_async_save"))
		if save_error != OK or bool(save_service.call("async_save_in_flight")):
			failures.append("RW06-1 teardown could not join its production autosave: %d." % save_error)
	app.call("_drain_script_prewarm_requests_for_shutdown")
	app.queue_free()
	var exit_code := 0
	if failures.is_empty():
		print("RW06_1_OVERFLOW_ACTION_UI PASS")
	else:
		exit_code = 1
		for failure in failures:
			push_error(failure)
	var quitter := CleanupQuitter.new()
	quitter.exit_code = exit_code
	root.add_child(quitter)
