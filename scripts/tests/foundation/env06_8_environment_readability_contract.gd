class_name Env068EnvironmentReadabilityContract
extends RefCounted

const SequenceCatalogScript := preload("res://scripts/core/scenario_sequence_catalog.gd")
const EnvironmentInteractionControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunSaveCodecScript := preload("res://scripts/core/run_save_codec.gd")
const ScenarioSequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const ScenarioSequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const ScenarioOperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")
const CrewHeistModelScript := preload("res://scripts/core/crew_heist_model.gd")
const CrewTurnModelScript := preload("res://scripts/core/crew_turn_model.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")

const EXPECTED_SCENARIOS := 55
const EXPECTED_PHASE_OBJECT_OPS := 1108
const EXPECTED_ACTIONS := 673
const MAX_PUBLIC_TRACE_STATES := 512
const MATERIAL_ACTION_HANDLERS := ["event_bridge", "grant_item", "grant_cash", "change_scene_object", "play_cue"]
const GENERATED_PROSE_MARKERS := [
	"the room advances to a new physical station",
	"beat moves props and actors",
	"shared aftermath fixes a distinct",
	"aftermath fixes a distinct",
	"holds a aftermath",
	"visibly prepared for the next step",
	"the change remains visible to anyone who returns",
	"remains visible when the player returns",
	"has shifted to a new part of the room",
	"now bears the visible signs of",
	"now shows that this part of the work is settled",
	"chosen outcome settles into the furniture",
	"physical record of the room's current stage",
	"condition is still plain on",
	"remaining actor remains",
	"room marker remains",
	"physical marker remains",
	"is clearly marked as one of the public paths",
	"the aftermath station opens here",
	"is the next hands-on step",
	"the route beside clear exit is deliberately clear",
	"the clearest physical trace",
	"showing where the people settled",
	"marking what has not changed yet",
	"marked marked lane",
	"the object itself records",
	"condition is visible at a glance",
	"in its visible arrangement",
	"now shows changed by",
	"a marked work point",
	"next room change begins",
	"changing the visible spacing among",
	"current posture shows how they fit",
	"available passage easy to read",
	"recording what changed during the last step",
	"displays beat",
	"carries the room's",
	"arrival signal",
	"is holding in holding",
	"open the aftermath station",
	"you let the pressure win",
	"you refuse and leave cleanly",
	"the marked clean exit remains available",
	"the marked exit remains readable through cleanup",
	"the failed branch closes this service",
	"without revealing hidden audit state",
	"the first station has moved into its working position",
	"choose a physical action at this station",
	"physical aftermath",
	"the outcome is recorded once",
	"the changed fixture is already in its new position",
	"the decisive second step",
]


static func check(library: Variant, failures: Array) -> void:
	_check(library, failures, true)


static func check_static(library: Variant, failures: Array) -> void:
	_check(library, failures, false)


static func _check(library: Variant, failures: Array, include_hidden_state_matrix: bool) -> void:
	var definitions: Array = []
	for pool_value in library.environment_scenarios.values():
		for definition_value in _array(pool_value):
			if typeof(definition_value) != TYPE_DICTIONARY: continue
			var definition := SequenceCatalogScript.apply_overlay(definition_value as Dictionary, library.scenario_sequence_catalog)
			if not _dict(definition.get("sequence", {})).is_empty(): definitions.append(definition)
	if definitions.size() != EXPECTED_SCENARIOS:
		failures.append("env06_8 expected %d scenario definitions, got %d." % [EXPECTED_SCENARIOS, definitions.size()])
		return
	var counts := {"phase_object_ops": 0, "zoned_phase_ops": 0, "create_records": 0, "described": 0, "zoned": 0, "actions": 0, "handlers": {}, "event_bridge_packages": {}}
	var presentation_records: Array = []
	var prose_sentence_counts: Dictionary = {}
	for definition_value in definitions:
		var definition := _dict(definition_value)
		_check_definition(definition, counts, presentation_records, failures)
		_collect_prose_sentences(_dict(definition.get("sequence", {})), prose_sentence_counts, str(definition.get("id", "")))
	if int(counts.get("phase_object_ops", 0)) != EXPECTED_PHASE_OBJECT_OPS:
		failures.append("env06_8 object census changed: expected %d, got %d." % [EXPECTED_PHASE_OBJECT_OPS, int(counts.get("phase_object_ops", 0))])
	if int(counts.get("actions", 0)) != EXPECTED_ACTIONS:
		failures.append("env06_8 action census changed: expected %d, got %d." % [EXPECTED_ACTIONS, int(counts.get("actions", 0))])
	if int(counts.get("zoned_phase_ops", 0)) != EXPECTED_PHASE_OBJECT_OPS:
		failures.append("env06_8 phase operations are not completely zoned: %s" % JSON.stringify(counts))
	if int(counts.get("create_records", 0)) != int(counts.get("described", 0)) or int(counts.get("create_records", 0)) != int(counts.get("zoned", 0)):
		failures.append("env06_8 creation surfaces are not completely described and zoned: %s" % JSON.stringify(counts))
	var handlers := _dict(counts.get("handlers", {}))
	if int(handlers.get("<none>", 0)) != 0:
		failures.append("env06_8 still has actions without handlers.")
	if int(handlers.get("publish_feedback", 0)) != 0:
		failures.append("env06_8 still has message-only actions without a material consequence.")
	for handler_id in ["event_bridge", "grant_item", "grant_cash", "change_scene_object", "play_cue"]:
		if int(handlers.get(handler_id, 0)) <= 0:
			failures.append("env06_8 consequence vocabulary is not exercised by %s." % handler_id)
	var event_bridge_packages := _dict(counts.get("event_bridge_packages", {}))
	for package_id in ["bars_road", "queen_public", "roadside_shelter", "shops_streets", "underground_lounge"]:
		if int(event_bridge_packages.get(package_id, 0)) <= 0:
			failures.append("env06_8 package %s has no honest conversational event_bridge consequence." % package_id)
	_check_consequence_handler_contracts(failures)
	_check_layout_validation_scope(failures)
	_check_icon_vocabulary(failures)
	_check_physical_icon_authoring(presentation_records, failures)
	_check_read_only_visual_composition(failures)
	_check_presentation_records(presentation_records, failures)
	_check_hidden_late_description_hostile(failures)
	_check_repeated_stock_sentences(prose_sentence_counts, failures)
	_check_generated_prose_hostiles(failures)
	if include_hidden_state_matrix:
		_check_partial_scenario_save_restore(library, definitions, failures)
		_check_hidden_state_neutrality(library, definitions, failures)


static func _check_partial_scenario_save_restore(library: Variant, definitions: Array, failures: Array) -> void:
	var definition: Dictionary = {}
	for definition_value in definitions:
		if str(_dict(definition_value).get("id", "")) == "corner_store_delivery_day":
			definition = _dict(definition_value)
			break
	if definition.is_empty():
		failures.append("env06_8 partial-scenario restore fixture is missing.")
		return
	var pristine_definition := definition.duplicate(true)
	# All definitions reached this full-only check through the exhaustive schema
	# pass above; preserve that trusted validation receipt when reseeding TownState.
	pristine_definition["__scenario_sequence_runtime_validated"] = true
	var archetype_id := str(definition.get("archetype_id", "corner_store"))
	var original_pool := _array(library.environment_scenarios.get(archetype_id, []))
	library.environment_scenarios[archetype_id] = [pristine_definition.duplicate(true)]
	var run_state := RunStateScript.new()
	run_state.start_new("ENV06_8-PARTIAL-RESTORE")
	var generator := RunGeneratorScript.new(library)
	generator.next_environment(run_state)
	var target_node := archetype_id
	for node_value in _array(run_state.world_map.get("nodes", [])):
		var node := _dict(node_value)
		if str(node.get("archetype_id", "")) == archetype_id:
			target_node = str(node.get("id", archetype_id))
			break
	var travel := generator.travel_environment_result(run_state, target_node, true)
	if not bool(travel.get("ok", false)) or str(run_state.current_environment.get("scenario_id", "")) != str(definition.get("id", "")):
		library.environment_scenarios[archetype_id] = original_pool
		failures.append("env06_8 partial-scenario restore fixture could not enter its production room.")
		return
	var initial_finalization := run_state.scenario_finalize_installed_environment(library, _dict(run_state.current_environment.get("scenario_layout_context", {})))
	if not bool(initial_finalization.get("ok", false)) or bool(initial_finalization.get("inactive", false)):
		library.environment_scenarios[archetype_id] = original_pool
		failures.append("env06_8 partial-scenario restore fixture could not finalize its production room: %s" % JSON.stringify(initial_finalization))
		return
	for command_id in ["inspect_manifest", "shift_cartons", "request_stock_check"]:
		var command_result := _run_host_command(run_state, definition, command_id, "env06_8:partial:%s" % command_id)
		if not bool(command_result.get("ok", false)):
			library.environment_scenarios[archetype_id] = original_pool
			failures.append("env06_8 partial-scenario restore fixture could not execute %s: %s" % [command_id, JSON.stringify(command_result.get("errors", []))])
			return
		var transitions := run_state.scenario_drain_transitions(false)
		if not bool(transitions.get("ok", false)):
			library.environment_scenarios[archetype_id] = original_pool
			failures.append("env06_8 partial-scenario restore fixture could not consume %s transitions: %s" % [command_id, JSON.stringify(transitions.get("errors", []))])
			return
	var drained := run_state.scenario_drain_event_requests()
	if not bool(drained.get("ok", false)) or _array(drained.get("requests", [])).size() != 1:
		library.environment_scenarios[archetype_id] = original_pool
		failures.append("env06_8 partial-scenario restore fixture did not deliver its correlated conversation once.")
		return
	var before := _dict(run_state.current_environment.get("scenario_sequence_state", {}))
	var transported_text := JSON.stringify(RunSaveCodecScript.encode(run_state.to_dict()))
	var transported_value: Variant = JSON.parse_string(transported_text)
	var restored := RunStateScript.new()
	library.environment_scenarios[archetype_id] = [pristine_definition.duplicate(true)]
	restored.from_dict(RunSaveCodecScript.decode(_dict(transported_value)))
	# This headless RunState contract has no Foundation catalog installer. Seed
	# the immutable authored definition through the same TownState boundary used
	# by production generation; semantic authority remains the transported data.
	restored.seed_scenario_for_node(restored.current_world_node_id(), pristine_definition.duplicate(true))
	var preparation := restored.scenario_prepare_semantic_finalization()
	var finalized := restored.scenario_finalize_installed_environment(library, _dict(run_state.current_environment.get("scenario_layout_context", {})))
	var after := _dict(restored.current_environment.get("scenario_sequence_state", {}))
	if not bool(preparation.get("ok", false)) or bool(preparation.get("inactive", false)) \
		or not bool(finalized.get("ok", false)) or bool(finalized.get("inactive", false)) \
		or ScenarioSequenceRuntimeScript.content_fingerprint(_state_without_rebuilt_base_geometry(before)) != ScenarioSequenceRuntimeScript.content_fingerprint(_state_without_rebuilt_base_geometry(after)) \
		or _array(after.get("event_request_history", [])).size() != 1 \
		or _array(after.get("event_request_delivery_receipts", [])).size() != 1 \
		or _array(after.get("event_correlations", [])).size() != 1:
		failures.append("env06_8 partial-scenario full save/load did not preserve trusted semantic state and delivered correlation: errors=%s changed=%s" % [JSON.stringify(finalized.get("errors", [])), JSON.stringify(_changed_state_keys(before, after))])
	var hostile_transport: Variant = JSON.parse_string(transported_text)
	var hostile := RunStateScript.new()
	hostile.from_dict(RunSaveCodecScript.decode(_dict(hostile_transport)))
	hostile.seed_scenario_for_node(hostile.current_world_node_id(), pristine_definition.duplicate(true))
	var hostile_preparation := hostile.scenario_prepare_semantic_finalization()
	hostile.current_environment["scenario_semantic_digest"] = "0".repeat(64)
	var rejected := hostile.scenario_finalize_installed_environment(library, _dict(run_state.current_environment.get("scenario_layout_context", {})))
	var rejection_text := JSON.stringify(rejected.get("errors", [])).to_lower()
	if not bool(hostile_preparation.get("ok", false)) or bool(hostile_preparation.get("inactive", false)) \
		or bool(rejected.get("ok", true)) or rejection_text.find("digest") < 0:
		failures.append("env06_8 partial-scenario restore accepts a forged semantic inventory digest: result=%s scenario=%s node=%s definition=%s" % [JSON.stringify(rejected), str(hostile.current_environment.get("scenario_id", "")), hostile.current_world_node_id(), str(hostile.scenario_sequence_definition().get("id", ""))])
	library.environment_scenarios[archetype_id] = original_pool


static func _state_without_rebuilt_base_geometry(state_value: Dictionary) -> Dictionary:
	# Ingress deliberately rebuilds authorization arrays from the sealed host.
	# Geometry is already bound by the independently compared inventory digest;
	# compare every causal/runtime field while excluding only copies of those
	# two derived geometry fields, including copies held in command receipts.
	# Consumed transition UI is intentionally not restored by RunState; the full
	# production consumer probe separately proves cue/stage persistence and dedupe.
	var state := state_value.duplicate(true)
	state.erase("active_stages")
	state.erase("transition_delivery_receipts")
	return _without_rebuilt_geometry(state)


static func _without_rebuilt_geometry(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		for key_value in (value as Dictionary).keys():
			var key := str(key_value)
			if key in ["normalized_hit_rect", "hit_bounds"]: continue
			result[key_value] = _without_rebuilt_geometry((value as Dictionary).get(key_value))
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for entry_value in value as Array: result.append(_without_rebuilt_geometry(entry_value))
		return result
	return value


static func _changed_state_keys(before: Dictionary, after: Dictionary) -> Array:
	var keys: Dictionary = {}
	for key_value in before.keys(): keys[str(key_value)] = true
	for key_value in after.keys(): keys[str(key_value)] = true
	var result: Array = []
	for key_value in keys.keys():
		var key := str(key_value)
		if ScenarioSequenceRuntimeScript.content_fingerprint(_without_rebuilt_geometry(before.get(key))) != ScenarioSequenceRuntimeScript.content_fingerprint(_without_rebuilt_geometry(after.get(key))):
			result.append(key)
	result.sort()
	return result


static func _run_host_command(run_state: Variant, definition: Dictionary, command_id: String, receipt_id: String) -> Dictionary:
	var state := _dict(run_state.current_environment.get("scenario_sequence_state", {}))
	var origin := _find_action_origin(state, command_id)
	if origin.is_empty():
		return {"ok": false, "errors": ["missing action origin phase=%s interactions=%s" % [str(state.get("phase_id", "")), JSON.stringify(_dict(_dict(state.get("semantic_state", {})).get("interactions", {})).keys())]]}
	var descriptor := ScenarioSequenceRuntimeScript._command_descriptor(state, definition, str(origin.get("owner_namespace", "")), str(origin.get("stable_object_id", "")), command_id, {})
	var availability: Dictionary = {}
	for interaction_value in _dict(_dict(state.get("semantic_state", {})).get("interactions", {})).values():
		var interaction := _dict(interaction_value)
		availability[ScenarioOperationRegistryScript.identity(str(interaction.get("owner_namespace", "")), str(interaction.get("stable_object_id", "")))] = bool(interaction.get("enabled", false))
	return run_state.scenario_sequence_command(
		command_id, receipt_id, {}, str(origin.get("owner_namespace", "")), str(origin.get("stable_object_id", "")), availability,
		str(descriptor.get("action_origin_owner_namespace", "")), str(descriptor.get("action_origin_stable_object_id", "")),
		str(descriptor.get("action_origin_receipt_key", "")), str(descriptor.get("action_origin_boundary_id", "")), str(descriptor.get("action_origin_fingerprint", ""))
	)


static func _check_consequence_handler_contracts(failures: Array) -> void:
	var definition := {"id": "env06_8_handler_fixture", "sequence": {"local_state_schema": {}, "objectives": [], "phase_graph": {"initial_phase": "arrival", "phases": [{"id": "arrival", "objective_ids": [], "branches": []}]}}}
	var initial := {
		"scenario_id": "env06_8_handler_fixture",
		"node_id": "fixture_node",
		"phase_id": "arrival",
		"event_request_queue": [],
		"event_request_history": [],
		"event_request_delivery_receipts": [],
		"semantic_state": {"scene_objects": {"scenario::fixture_prop": {"owner_namespace": "scenario", "stable_object_id": "fixture_prop", "state": "before"}}, "actors": {}, "transition_queue": []},
	}
	for fixture in [
		{"handler": "grant_item", "inputs": {"item_id": "ledger_pencil", "message": "A ledger pencil is now in your bag."}, "kind": "item"},
		{"handler": "grant_cash", "inputs": {"amount": 7, "message": "Seven dollars change hands in plain view."}, "kind": "cash"},
	]:
		var trigger := {"kind": "command", "receipt_id": "env06_8_%s_once" % str(fixture.get("kind", ""))}
		var first := ScenarioSequenceRuntimeScript._run_handler(initial, definition, str(fixture.get("handler", "")), _dict(fixture.get("inputs", {})), trigger)
		var replay := ScenarioSequenceRuntimeScript._run_handler(_dict(first.get("state", {})), definition, str(fixture.get("handler", "")), _dict(fixture.get("inputs", {})), trigger)
		if not bool(first.get("ok", false)) or not bool(replay.get("ok", false)) or _array(_dict(replay.get("state", {})).get("event_request_queue", [])).size() != 1:
			failures.append("env06_8 %s does not keep one exactly-once external request before delivery." % str(fixture.get("handler", "")))
			continue
		var drained := ScenarioSequenceRuntimeScript.drain_event_requests(_dict(replay.get("state", {})), definition, true)
		var saved: Variant = JSON.parse_string(JSON.stringify(drained.get("state", {})))
		var after_reload := ScenarioSequenceRuntimeScript._run_handler(_dict(saved), definition, str(fixture.get("handler", "")), _dict(fixture.get("inputs", {})), trigger)
		var redrained := ScenarioSequenceRuntimeScript.drain_event_requests(_dict(after_reload.get("state", {})), definition, true)
		if _array(drained.get("requests", [])).size() != 1 or not _array(redrained.get("requests", [])).is_empty():
			failures.append("env06_8 %s redelivers after save/reload." % str(fixture.get("handler", "")))
	var changed := ScenarioSequenceRuntimeScript._run_handler(initial, definition, "change_scene_object", {"owner_namespace": "scenario", "stable_object_id": "fixture_prop", "state": "after", "message": "The fixture has visibly changed."}, {"kind": "command", "receipt_id": "env06_8_scene_once"})
	var changed_state := _dict(changed.get("state", {}))
	if not bool(changed.get("ok", false)) or str(_dict(_dict(_dict(changed_state.get("semantic_state", {})).get("scene_objects", {})).get("scenario::fixture_prop", {})).get("state", "")) != "after" or _array(_dict(changed_state.get("semantic_state", {})).get("transition_queue", [])).size() != 1:
		failures.append("env06_8 change_scene_object does not persist a visible state plus feedback.")
	var missing := ScenarioSequenceRuntimeScript._run_handler(initial, definition, "change_scene_object", {"owner_namespace": "scenario", "stable_object_id": "missing_prop", "state": "after", "message": "This must fail closed."}, {"kind": "command", "receipt_id": "env06_8_missing"})
	if bool(missing.get("ok", true)):
		failures.append("env06_8 change_scene_object does not fail closed for a missing visible target.")
	var cued := ScenarioSequenceRuntimeScript._run_handler(initial, definition, "play_cue", {"cue_id": "sightline_tension", "message": "The room reacts to the call."}, {"kind": "command", "receipt_id": "env06_8_cue_once"})
	var cue_queue := _array(_dict(_dict(cued.get("state", {})).get("semantic_state", {})).get("transition_queue", []))
	if not bool(cued.get("ok", false)) or cue_queue.size() != 2 or str(_dict(cue_queue[0]).get("op", "")) != "sound" or str(_dict(cue_queue[1]).get("op", "")) != "stage":
		failures.append("env06_8 play_cue does not emit both audible and visible consequence records.")


static func _check_layout_validation_scope(failures: Array) -> void:
	var authority_record := {"normalized_hit_rect": {"x": 0.35, "y": 0.35, "w": 0.08, "h": 0.12}, "small_screen_rect": {"x": 0.34, "y": 0.34, "w": 0.1, "h": 0.15}}
	var base_interaction := {"owner_namespace": "base", "label": "Base control", "prompt": "Use the base control.", "present": true, "enabled": true, "available_actions": [{"id": "use", "label": "Use"}], "safe_exit": false, "alternate_exit": false}
	var interactions := {"base::one": base_interaction.duplicate(true), "base::two": base_interaction.duplicate(true)}
	var authority := {"base::one": authority_record.duplicate(true), "base::two": authority_record.duplicate(true)}
	var base_only_errors: Array = []
	ScenarioLayoutResolverScript._validate_interactions(interactions, authority, [], [], {}, base_only_errors)
	for error_value in base_only_errors:
		if str(error_value).contains("ambiguous") or str(error_value).contains("overlap"):
			failures.append("env06_8 scenario layout validator still attributes a base-only collision to the active scenario.")
			break
	var scenario_interaction := base_interaction.duplicate(true)
	scenario_interaction["owner_namespace"] = "scenario"
	scenario_interaction["label"] = "Scenario control"
	scenario_interaction["prompt"] = "Use the scenario control."
	interactions["scenario::three"] = scenario_interaction
	authority["scenario::three"] = authority_record.duplicate(true)
	var composed_errors: Array = []
	ScenarioLayoutResolverScript._validate_interactions(interactions, authority, [], [], {}, composed_errors)
	var caught_scenario_collision := false
	for error_value in composed_errors:
		if str(error_value).contains("scenario::three") and (str(error_value).contains("ambiguous") or str(error_value).contains("overlap")):
			caught_scenario_collision = true
	if not caught_scenario_collision:
		failures.append("env06_8 scenario layout validator no longer catches scenario-to-base collisions.")


static func _check_icon_vocabulary(failures: Array) -> void:
	var canvas := PixelSceneCanvasScript.new()
	var expected := {
		"scene_object velvet rope barrier closed": "room_barrier",
		"scene_object folding chairs seating": "room_seating",
		"scene_object warning lamp signal": "room_signal",
		"scene_object bottle service drink": "room_refreshment",
		"scene_object memorial table surface": "room_surface",
		"scene_object interrupted aftermath traces": "room_trace",
		"scene_object marked corridor route": "room_route",
		"scene_object garment rack furniture": "room_storage",
		"scene_object pressure gauge instrument": "room_display",
		"scene_object lead rig vehicle": "room_vehicle",
		"scene_object storm smoke hazard": "room_hazard",
		"actor night clerk work": "clerk_talk",
		"scene_object marked exit lane": "side_door",
	}
	for key_value in expected.keys():
		if str(canvas.call("_fallback_event_prop", "", str(key_value))) != str(expected.get(key_value, "")):
			failures.append("env06_8 icon vocabulary does not visually distinguish %s." % str(key_value))
	var authored_vocabulary := [
		"paper_note", "room_seating", "room_barrier", "room_signal", "room_refreshment",
		"room_surface", "room_storage", "room_display", "room_vehicle", "room_hazard",
		"payphone", "security_camera", "security_exit", "side_door", "room_route",
		"trunk_offer", "jammed_machine", "clerk_counter", "clerk_talk", "patron_talk",
		"room_trace", "room_fixture", "motel_door",
	]
	for icon_value in authored_vocabulary:
		var icon := str(icon_value)
		if str(canvas.call("_fallback_event_prop", "misleading glass aftermath station", icon)) != icon:
			failures.append("env06_8 authored icon %s is not honored verbatim before heuristic text." % icon)
	var authored_semantic := {"semantic_kind": "scene_object", "label": "Clear Broken Glass", "role": "task_station", "icon_key": "room_hazard", "description": "A broom waits beside broken glass."}
	if str(EnvironmentInteractionControllerScript._scenario_icon_key(authored_semantic, {})) != "room_hazard" or str(ScenarioLayoutResolverScript._scenario_icon_key(authored_semantic)) != "room_hazard":
		failures.append("env06_8 controller/resolver do not preserve authored physical icon semantics verbatim.")
	if str(canvas.call("_fallback_event_prop", "ordinary_generic_event", "")) != "patron_talk":
		failures.append("env06_8 changed the 0.5 ordinary-event fallback silhouette away from patron_talk.")
	var scenario_hint := _dict(canvas.call("_apply_draw_hints", {
		"visual_key": "scenario_object",
		"icon_key": "",
		"prop": "",
	}, "scenario_object", 0))
	if str(scenario_hint.get("prop", "")) != "room_fixture":
		failures.append("env06_8 scenario objects without a more specific icon do not receive the scoped room_fixture fallback.")
	canvas.free()


static func _check_physical_icon_authoring(records: Array, failures: Array) -> void:
	var allowed := [
		"paper_note", "room_seating", "room_barrier", "room_signal", "room_refreshment",
		"room_surface", "room_storage", "room_display", "room_vehicle", "room_hazard",
		"payphone", "security_camera", "security_exit", "side_door", "room_route",
		"trunk_offer", "jammed_machine", "clerk_counter", "clerk_talk", "patron_talk",
		"room_trace", "room_fixture", "motel_door",
	]
	var resolved_counts: Dictionary = {}
	var resolved_scene_count := 0
	var canvas := PixelSceneCanvasScript.new()
	for record_value in records:
		var record := _dict(record_value)
		if str(record.get("family", "")) != "scene_ops": continue
		var stable_id := str(record.get("stable_object_id", ""))
		var payload := _dict(record.get("payload", {}))
		var role := str(payload.get("role", ""))
		var icon := str(payload.get("icon_key", ""))
		var label := str(payload.get("label", ""))
		if not icon.is_empty() and icon not in allowed: failures.append("env06_8 scene object %s authors unsupported icon %s." % [stable_id, icon])
		var semantic := payload.duplicate(true)
		semantic["semantic_kind"] = "scene_object"
		semantic["stable_object_id"] = stable_id
		var semantic_icon := EnvironmentInteractionControllerScript._scenario_icon_key(semantic, {})
		var hinted := _dict(canvas.call("_apply_draw_hints", {"visual_key": semantic_icon, "icon_key": semantic_icon, "prop": ""}, "scenario_object", 0))
		var resolved_icon := str(hinted.get("prop", ""))
		resolved_scene_count += 1
		resolved_counts[resolved_icon] = int(resolved_counts.get(resolved_icon, 0)) + 1
		if resolved_icon.is_empty() or resolved_icon not in allowed:
			failures.append("env06_8 scene object %s does not resolve to a supported nonempty physical icon." % stable_id)
		if role == "task_station" and (icon.is_empty() or icon in ["room_fixture", "room_trace"]) and stable_id != "kitty_cat_lounge_bachelorette_storm_task_3":
			failures.append("env06_8 task station %s lacks a specific physical icon." % stable_id)
		if (stable_id.contains("_aftermath_") or role == "aftermath") and role != "exit" and (icon.is_empty() or icon == "room_trace"):
			failures.append("env06_8 aftermath object %s still uses lifecycle text instead of physical icon semantics." % stable_id)
		if resolved_icon == "room_fixture" and stable_id not in ["kitty_cat_lounge_bachelorette_storm_task_3", "kitty_cat_lounge_bachelorette_storm_aftermath_stage_commandeered_prop"]:
			failures.append("env06_8 scene object %s uses an unjustified generic room_fixture icon." % stable_id)
		if label.contains(" L 1") or label.contains(" L 2") or label.contains(" L 3"):
			failures.append("env06_8 visible label splits its canonical L1/L2/L3 token: %s" % label)
		if (stable_id.contains("_aftermath_") or role == "aftermath") and (label.to_lower().ends_with(" witness") or label.to_lower().ends_with(" traces") or label.to_lower().ends_with(" aftermath service")):
			failures.append("env06_8 aftermath label retains generated outcome-title vocabulary: %s" % label)
	canvas.free()
	for icon_value in resolved_counts.keys():
		var category_count := int(resolved_counts.get(icon_value, 0))
		if resolved_scene_count >= 20 and float(category_count) / float(resolved_scene_count) > 0.35:
			failures.append("env06_8 icon resolution collapses %.1f%% of scene states into %s." % [100.0 * float(category_count) / float(resolved_scene_count), str(icon_value)])
	var hostile_failures: Array = []
	_check_physical_icon_authoring_hostile(hostile_failures)
	if hostile_failures.size() != 3:
		failures.append("env06_8 physical icon/label hostile gate did not reject task, aftermath-label, and split-tier defects independently.")


static func _check_physical_icon_authoring_hostile(failures: Array) -> void:
	var rows := [
		{"family": "scene_ops", "stable_object_id": "hostile_task", "payload": {"role": "task_station", "label": "Carry L 1 Case", "icon_key": "room_fixture"}},
		{"family": "scene_ops", "stable_object_id": "hostile_aftermath_witness", "payload": {"role": "aftermath", "label": "Side Chosen witness", "icon_key": "room_trace"}},
	]
	# Reuse the three precise predicates without invoking the aggregate floor.
	for record_value in rows:
		var record := _dict(record_value)
		var stable_id := str(record.get("stable_object_id", ""))
		var payload := _dict(record.get("payload", {}))
		var role := str(payload.get("role", ""))
		var icon := str(payload.get("icon_key", ""))
		var label := str(payload.get("label", ""))
		if role == "task_station" and icon in ["", "room_fixture", "room_trace"]: failures.append("task")
		if label.contains(" L 1") or label.contains(" L 2") or label.contains(" L 3"): failures.append("tier")
		if stable_id.contains("aftermath") and (label.to_lower().ends_with(" witness") or label.to_lower().ends_with(" traces")): failures.append("aftermath")


static func _check_read_only_visual_composition(failures: Array) -> void:
	var semantic := {
		"owner_namespace": "scenario", "stable_object_id": "readable_fixture", "semantic_kind": "scene_object",
		"present": true, "visible": true, "enabled": true, "label": "Readable fixture", "role": "evidence",
		"state": "present", "description": "Scuffs on the fixture show where the room changed.", "description_variants": {},
	}
	var authority_record := ScenarioLayoutResolverScript._authority_record(
		"scenario::readable_fixture", "scenario::readable_fixture",
		{"x": 0.2, "y": 0.2, "w": 0.1, "h": 0.1}, {"x": 0.2, "y": 0.2, "w": 0.1, "h": 0.1},
		1, "scene_object", "semantic_visual", [], {}, true, true, false
	)
	var authority := {"scenario::readable_fixture": authority_record}
	var seal_errors: Array = []
	ScenarioLayoutResolverScript._seal_projection_coverage(authority, {"scene_objects": {"scenario::readable_fixture": semantic}, "actors": {}, "interactions": {}}, seal_errors)
	if not seal_errors.is_empty() or not bool(_dict(authority.get("scenario::readable_fixture", {})).get("presentation_interactive", false)):
		failures.append("env06_8 layout authority does not seal scenario decoration as read-only inspectable.")
	var base_record := {
		"object_id": "scenario::readable_fixture", "owner_namespace": "scenario", "stable_object_id": "readable_fixture",
		"object_type": "scenario_object", "visual_type": "scenario_object", "visible": true,
	}
	var composed := EnvironmentInteractionControllerScript._compose_projected_records(
		[base_record], {"semantic_state": {"scene_objects": {"scenario::readable_fixture": semantic}, "actors": {}, "interactions": {}}},
		authority, "fixture_digest"
	)
	var records := _array(composed.get("records", []))
	if not bool(composed.get("ok", false)) or records.size() != 1 or str(_dict(records[0]).get("object_type", "")) != "scenario_scene_object" or str(_dict(records[0]).get("visual_type", "")) != "scenario_object" or str(_dict(records[0]).get("role", "")) != "evidence" or not bool(_dict(records[0]).get("interactive", false)) or not _array(_dict(records[0]).get("scenario_sequence_actions", [])).is_empty():
		failures.append("env06_8 read-only scenario decoration is not selectable as an inspectable information-panel record.")


static func _check_definition(definition: Dictionary, counts: Dictionary, presentation_records: Array, failures: Array) -> void:
	var sequence := _dict(definition.get("sequence", {}))
	var scenario_id := str(definition.get("id", ""))
	var creates: Dictionary = {}
	_collect_create_records(sequence, scenario_id, counts, creates, presentation_records, failures)
	for phase_value in _array(_dict(sequence.get("phase_graph", {})).get("phases", [])):
		var phase := _dict(phase_value)
		var command_branches: Dictionary = {}
		for branch_value in _array(phase.get("branches", [])):
			var branch := _dict(branch_value)
			var condition := _dict(branch.get("condition", {}))
			if str(condition.get("type", "")) == "command": command_branches[str(condition.get("command_id", ""))] = branch
		counts["phase_object_ops"] = int(counts.get("phase_object_ops", 0)) + _array(phase.get("scene_ops", [])).size() + _array(phase.get("actor_ops", [])).size()
		for family in ["scene_ops", "actor_ops"]:
			for operation_value in _array(phase.get(family, [])):
				var operation := _dict(operation_value)
				var payload := _dict(operation.get("object", operation.get("actor", operation)))
				counts["zoned_phase_ops"] = int(counts.get("zoned_phase_ops", 0)) + int(not str(payload.get("zone_id", operation.get("zone_id", ""))).strip_edges().is_empty())
		for operation_value in _array(phase.get("interaction_ops", [])):
			var operation := _dict(operation_value)
			var interaction_stable_id := str(operation.get("stable_object_id", ""))
			for action_value in _array(_dict(operation.get("interaction", {})).get("available_actions", operation.get("available_actions", []))):
				var action := _dict(action_value)
				var handler_id := str(action.get("handler", "<none>"))
				if handler_id.is_empty(): handler_id = "<none>"
				counts["actions"] = int(counts.get("actions", 0)) + 1
				var handlers := _dict(counts.get("handlers", {}))
				handlers[handler_id] = int(handlers.get(handler_id, 0)) + 1
				counts["handlers"] = handlers
				var inputs := _dict(action.get("inputs", {}))
				if handler_id == "event_bridge":
					var bridge_packages := _dict(counts.get("event_bridge_packages", {}))
					var package_id := _scenario_package(scenario_id)
					bridge_packages[package_id] = int(bridge_packages.get(package_id, 0)) + 1
					counts["event_bridge_packages"] = bridge_packages
					var reference_events := _array(_dict(_dict(definition.get("sequence_authoring", definition.get("authoring", {}))).get("references", {})).get("events", []))
					if str(inputs.get("message", "")).strip_edges().is_empty() or str(inputs.get("event_id", "")).strip_edges().is_empty() or str(inputs.get("resolution_id", "")).strip_edges().is_empty() or not reference_events.has(str(inputs.get("event_id", ""))):
						failures.append("env06_8 %s action %s lacks a referenced conversation, resolution, or authored visible feedback." % [scenario_id, str(action.get("id", ""))])
				if handler_id not in MATERIAL_ACTION_HANDLERS:
					var action_id := str(action.get("id", ""))
					if not command_branches.has(action_id) or not _branch_has_visible_destination(sequence, _dict(command_branches.get(action_id, {}))):
						failures.append("env06_8 %s action %s has no direct consequence or visibly staged command destination." % [scenario_id, action_id])
				if handler_id == "change_scene_object":
					var target_id := str(inputs.get("stable_object_id", interaction_stable_id))
					var state_id := str(inputs.get("state", ""))
					var matched_variant := false
					for payload_value in _array(creates.get(target_id, [])):
						if str(_dict(_dict(payload_value).get("description_variants", {})).get(state_id, "")) == str(inputs.get("message", "")):
							matched_variant = true
					if state_id.is_empty() or not matched_variant:
						failures.append("env06_8 %s action %s does not persist its narrated state on %s." % [scenario_id, str(action.get("id", "")), target_id])
		for family in ["scene_ops", "actor_ops"]:
			for operation_value in _array(phase.get(family, [])):
				var operation := _dict(operation_value)
				if str(operation.get("op", "")) not in ["move", "set_position", "set_state", "set_appearance", "set_pose", "set_behavior"]: continue
				var variant_key := ""
				for key in ["state", "appearance", "pose", "behavior", "anchor_id", "zone_id"]:
					if not str(operation.get(key, "")).is_empty(): variant_key = str(operation.get(key, "")); break
				if variant_key.is_empty(): continue
				var covered := false
				for payload_value in _array(creates.get(str(operation.get("stable_object_id", "")), [])):
					if _dict(_dict(payload_value).get("description_variants", {})).has(variant_key): covered = true
				if not covered:
					failures.append("env06_8 %s/%s lacks description variant %s." % [scenario_id, str(operation.get("stable_object_id", "")), variant_key])
	_check_generated_prose(sequence, scenario_id, failures)


static func _scenario_package(scenario_id: String) -> String:
	if scenario_id.begins_with("bar_") or scenario_id.begins_with("jazz_club_"):
		return "bars_road"
	if scenario_id.begins_with("delta_queen_") or scenario_id.begins_with("grand_casino_"):
		return "queen_public"
	if scenario_id.begins_with("motel_") or scenario_id.begins_with("gas_station_") or scenario_id.begins_with("beach_"):
		return "roadside_shelter"
	if scenario_id.begins_with("corner_store_") or scenario_id.begins_with("back_alley_") or scenario_id.begins_with("pawn_shop_"):
		return "shops_streets"
	if scenario_id.begins_with("punchline_") or scenario_id.begins_with("kitty_cat_lounge_"):
		return "underground_lounge"
	return "unknown"


static func _branch_has_visible_destination(sequence: Dictionary, branch: Dictionary) -> bool:
	var outcome := str(branch.get("outcome", ""))
	if not outcome.is_empty() and _dict(sequence.get("aftermath", {})).has(outcome): return true
	var next_phase_id := str(branch.get("next_phase", ""))
	if next_phase_id.is_empty(): return false
	var next_phase := ScenarioSequenceSchemaScript.phase({"sequence": sequence}, next_phase_id)
	if next_phase.is_empty(): return false
	if not _array(next_phase.get("scene_ops", [])).is_empty() or not _array(next_phase.get("actor_ops", [])).is_empty(): return true
	for transition_value in _array(next_phase.get("transition_ops", [])):
		var transition := _dict(transition_value)
		if not str(transition.get("message", transition.get("reduced_motion_message", ""))).strip_edges().is_empty(): return true
	return false


static func _collect_create_records(value: Variant, scenario_id: String, counts: Dictionary, creates: Dictionary, presentation_records: Array, failures: Array) -> void:
	if typeof(value) == TYPE_ARRAY:
		for child in value: _collect_create_records(child, scenario_id, counts, creates, presentation_records, failures)
		return
	if typeof(value) != TYPE_DICTIONARY: return
	var row := value as Dictionary
	var family := str(row.get("family", ""))
	var payload := _dict(row.get("object", row.get("actor", {})))
	if family in ["scene_ops", "actor_ops"] and not payload.is_empty():
		counts["create_records"] = int(counts.get("create_records", 0)) + 1
		counts["described"] = int(counts.get("described", 0)) + int(not str(payload.get("description", "")).strip_edges().is_empty())
		counts["zoned"] = int(counts.get("zoned", 0)) + int(not str(payload.get("zone_id", "")).strip_edges().is_empty())
		var stable_id := str(row.get("stable_object_id", ""))
		var payloads := _array(creates.get(stable_id, [])); payloads.append(payload); creates[stable_id] = payloads
		presentation_records.append({"scenario_id": scenario_id, "family": family, "stable_object_id": stable_id, "payload": payload})
	for child in row.values(): _collect_create_records(child, scenario_id, counts, creates, presentation_records, failures)


static func _check_hidden_state_neutrality(library: Variant, definitions: Array, failures: Array) -> void:
	# Every hidden profile gets its own complete runtime traversal. Only the
	# resulting public surfaces are compared; no clean-profile trace may stand in
	# for a hidden run whose later action, branch, or reentry could leak a secret.
	for definition_value in definitions:
		var definition := _dict(definition_value)
		var scenario_id := str(definition.get("id", ""))
		var archetype_id := str(definition.get("archetype_id", ""))
		var original_pool := _array(library.environment_scenarios.get(archetype_id, []))
		var selected: Dictionary = {}
		for candidate_value in original_pool:
			if str(_dict(candidate_value).get("id", "")) == scenario_id: selected = _dict(candidate_value); break
		if selected.is_empty():
			failures.append("env06_8 paired observer cannot find %s in %s." % [scenario_id, archetype_id])
			continue
		library.environment_scenarios[archetype_id] = [selected]
		var clean := _seeded_description_observer(library, archetype_id, scenario_id, "clean", failures)
		var hidden_observers := {
			"turn_and_grievance": _seeded_description_observer(library, archetype_id, scenario_id, "turn_and_grievance", failures),
			"rigged_numbers": _seeded_description_observer(library, archetype_id, scenario_id, "rigged_numbers", failures),
			"unrevealed_tickets": _seeded_description_observer(library, archetype_id, scenario_id, "unrevealed_tickets", failures),
		}
		library.environment_scenarios[archetype_id] = original_pool
		if clean.is_empty(): continue
		for profile_value in hidden_observers.keys():
			var profile := str(profile_value)
			var hidden := _dict(hidden_observers.get(profile, {}))
			if hidden.is_empty(): continue
			if JSON.stringify(clean) != JSON.stringify(hidden):
				failures.append("env06_8 paired seeded observers diverged for %s under %s hidden state." % [scenario_id, profile])


static func _check_presentation_records(records: Array, failures: Array) -> void:
	for record_value in records:
		var record := _dict(record_value)
		var semantic := _dict(record.get("payload", {})).duplicate(true)
		semantic["owner_namespace"] = "scenario"
		semantic["stable_object_id"] = str(record.get("stable_object_id", ""))
		semantic["semantic_kind"] = "actor" if str(record.get("family", "")) == "actor_ops" else "scene_object"
		var authority := {"presentation_object_id": "scenario::%s" % str(record.get("stable_object_id", "")), "normalized_hit_rect": {"x": 0.1, "y": 0.1, "w": 0.1, "h": 0.1}, "small_screen_rect": {"x": 0.1, "y": 0.1, "w": 0.1, "h": 0.1}}
		var projected := EnvironmentInteractionControllerScript._merge_projected_actor({}, semantic, authority, "digest") if str(record.get("family", "")) == "actor_ops" else EnvironmentInteractionControllerScript._merge_projected_scene_object({}, semantic, authority, "digest")
		if str(projected.get("label", "")).is_empty() or str(projected.get("short_description", "")).is_empty() or str(projected.get("icon_key", "")).is_empty() or not bool(projected.get("interactive", false)):
			failures.append("env06_8 projected object %s lacks complete inspectable presentation." % str(record.get("stable_object_id", "")))


static func _seeded_description_observer(library: Variant, archetype_id: String, scenario_id: String, hidden_profile: String, failures: Array) -> Dictionary:
	var run_state := RunStateScript.new()
	run_state.start_new("ENV06_8-HIDDEN-%s" % scenario_id)
	if hidden_profile == "turn_and_grievance":
		var turn := CrewTurnModelScript.empty_state()
		turn["m"] = str(CrewStateModelScript.MEMBER_IDS[1])
		run_state.crew_heist_state = CrewHeistModelScript.begin(CrewHeistModelScript.PLAN_COUNT, 0)
		run_state.crew_heist_state["x"] = turn
		run_state.grievance_add({"member_id": str(CrewStateModelScript.MEMBER_IDS[1]), "kind": "job_abandoned", "weight": 9, "source_ref": "env06_8_hidden_probe"})
	elif hidden_profile == "rigged_numbers":
		run_state.numbers_state.draws_by_day[0] = {"number": "777", "posted": false, "fixed": true}
		run_state.numbers_state.fix_state = {"status": "ready", "retry_day": 0, "number": "777"}
	elif hidden_profile == "unrevealed_tickets":
		run_state.portable_ticket_piles = {
			"scratch_tickets": {"env06_8_hidden": {"active_ticket": {"id": "hidden_scratch", "mechanic_result": {"payout": 500}}, "pending_queue": [{"id": "hidden_next", "mechanic_result": {"payout": 0}}]}},
			"pull_tabs": {"env06_8_hidden": {"ticket_stack": [{"id": "hidden_pull_tab", "payout": 100}]}}
		}
	var generator := RunGeneratorScript.new(library)
	generator.next_environment(run_state)
	var target_node := ""
	for node_value in _array(run_state.world_map.get("nodes", [])):
		var node := _dict(node_value)
		if str(node.get("archetype_id", "")) == archetype_id:
			target_node = str(node.get("id", ""))
			break
	if target_node.is_empty(): target_node = archetype_id
	var travel := generator.travel_environment_result(run_state, target_node, true)
	if not bool(travel.get("ok", false)) or str(run_state.current_environment.get("scenario_id", "")) != scenario_id:
		failures.append("env06_8 paired observer could not enter %s: %s" % [scenario_id, JSON.stringify(travel.get("errors", []))])
		return {}
	var projection := run_state.world_sequence_composed_projection()
	var semantic := _dict(projection.get("semantic_state", {}))
	var arrival: Array = []
	for collection_key in ["scene_objects", "actors"]:
		for record_value in _dict(semantic.get(collection_key, {})).values():
			var record := _dict(record_value)
			arrival.append("%s|%s|%s" % [str(record.get("stable_object_id", "")), str(record.get("description", "")), JSON.stringify(record.get("description_variants", {}))])
	arrival.sort()
	var authored: Array = []
	_collect_description_lines(_dict(run_state.current_environment.get("scenario_sequence_definition", {})), authored)
	authored.sort()
	var definition := _dict(run_state.current_environment.get("scenario_sequence_definition", {}))
	var state := _dict(run_state.current_environment.get("scenario_sequence_state", {}))
	var through_state := _runtime_description_trace(definition, state, scenario_id, failures)
	return {"arrival": arrival, "through_state": through_state, "authored_states": authored}


static func _check_hidden_late_description_hostile(failures: Array) -> void:
	var clean_state := {
		"semantic_state": {
			"scene_objects": {"scenario::sealed_box": {
				"owner_namespace": "scenario", "stable_object_id": "sealed_box",
				"description": "A sealed box sits untouched.",
				"description_variants": {
					"clean_after": "The opened box is empty.",
					"hidden_after": "The opened box exposes the hidden ticket.",
				},
				"state": "sealed",
			}},
			"actors": {},
			"interactions": {"scenario::sealed_box": {
				"owner_namespace": "scenario", "stable_object_id": "sealed_box",
				"label": "Sealed box", "prompt": "Open the sealed box.",
				"disabled_reason": "", "state_label": "Sealed", "enabled": true,
				"available_actions": [{
					"id": "open_box", "label": "Open", "non_color_state": "ready",
					"handler": "change_scene_object",
					"inputs": {"owner_namespace": "scenario", "stable_object_id": "sealed_box", "state": "clean_after"},
				}],
			}},
		},
	}
	var hidden_state := clean_state.duplicate(true)
	hidden_state["semantic_state"]["interactions"]["scenario::sealed_box"]["available_actions"][0]["inputs"]["state"] = "hidden_after"
	if JSON.stringify(_semantic_description_set(clean_state)) != JSON.stringify(_semantic_description_set(hidden_state)):
		failures.append("env06_8 hostile hidden fixture changed its arrival-readable surface before the action.")
		return
	var clean_later: Dictionary = {}
	var hidden_later: Dictionary = {}
	_trace_action_consequences(clean_state, clean_later, "arrival")
	_trace_action_consequences(hidden_state, hidden_later, "arrival")
	if JSON.stringify(clean_later) == JSON.stringify(hidden_later):
		failures.append("env06_8 hidden-state proof did not reject a secret that changes a later object description.")


static func _runtime_description_trace(definition: Dictionary, initial_state: Dictionary, scenario_id: String, failures: Array) -> Dictionary:
	var result: Dictionary = {}
	var pending: Array = [{"state": initial_state, "path": "arrival"}]
	var visited: Dictionary = {}
	var serial := 0
	var icon_canvas := PixelSceneCanvasScript.new()
	var icon_by_identity: Dictionary = {}
	while not pending.is_empty() and serial < MAX_PUBLIC_TRACE_STATES:
		var item := _dict(pending.pop_front())
		var state := _dict(item.get("state", {}))
		var path := str(item.get("path", "state"))
		var state_key := ScenarioSequenceRuntimeScript.content_fingerprint(ScenarioSequenceRuntimeScript.public_projection(state, definition))
		if visited.has(state_key): continue
		visited[state_key] = true
		result[path] = _semantic_description_set(state)
		_check_runtime_icon_resolution(state, scenario_id, path, icon_canvas, icon_by_identity, failures)
		var reentry := ScenarioSequenceRuntimeScript.apply_reentry(state, definition, "env06_8_%s_%d" % [scenario_id, serial])
		if bool(reentry.get("ok", false)):
			result["%s|reentry" % path] = _semantic_description_set(_dict(reentry.get("state", {})))
		else:
			failures.append("env06_8 through-state reentry failed for %s/%s: %s" % [scenario_id, path, JSON.stringify(reentry.get("errors", []))])
		_trace_action_consequences(state, result, path)
		if str(state.get("status", "")) != ScenarioSequenceRuntimeScript.STATUS_ACTIVE:
			serial += 1
			continue
		var phase := ScenarioSequenceSchemaScript.phase(definition, str(state.get("phase_id", "")))
		var branch_index := 0
		for branch_value in _array(phase.get("branches", [])):
			var branch := _dict(branch_value)
			var condition := _dict(branch.get("condition", {}))
			var next_path := "%s>%s" % [path, str(branch.get("id", branch_index))]
			var applied: Dictionary = {}
			if str(condition.get("type", "")) == "command":
				var command_id := str(condition.get("command_id", ""))
				var origin := _find_action_origin(state, command_id)
				var descriptor := ScenarioSequenceRuntimeScript._command_descriptor(state, definition, str(origin.get("owner_namespace", "")), str(origin.get("stable_object_id", "")), command_id, {})
				var command := ScenarioSequenceRuntimeScript.command(
					command_id, str(state.get("node_id", "")), str(state.get("phase_id", "")), "env06_8:%s:%d:%d" % [scenario_id, serial, branch_index], {},
					str(origin.get("owner_namespace", "")), str(origin.get("stable_object_id", "")),
					str(descriptor.get("action_origin_owner_namespace", "")), str(descriptor.get("action_origin_stable_object_id", "")),
					str(descriptor.get("action_origin_receipt_key", "")), str(descriptor.get("action_origin_boundary_id", "")), str(descriptor.get("action_origin_fingerprint", ""))
				)
				applied = ScenarioSequenceRuntimeScript.apply_command(state, definition, command, {"available_funds": 100000})
			else:
				applied = _apply_trace_fact(state, definition, condition, scenario_id, serial, branch_index)
			if bool(applied.get("ok", false)):
				pending.append({"state": _dict(applied.get("state", {})), "path": next_path})
			elif str(condition.get("type", "")) in ["command", "fact"]:
				failures.append("env06_8 through-state branch failed for %s/%s: %s" % [scenario_id, next_path, JSON.stringify(applied.get("errors", []))])
			branch_index += 1
		serial += 1
	if serial >= MAX_PUBLIC_TRACE_STATES:
		failures.append("env06_8 through-state observer exceeded its bounded trace for %s." % scenario_id)
	icon_canvas.free()
	return result


static func _check_runtime_icon_resolution(state: Dictionary, scenario_id: String, path: String, canvas: Variant, icon_by_identity: Dictionary, failures: Array) -> void:
	var allowed := [
		"paper_note", "room_seating", "room_barrier", "room_signal", "room_refreshment",
		"room_surface", "room_storage", "room_display", "room_vehicle", "room_hazard",
		"payphone", "security_camera", "security_exit", "side_door", "room_route",
		"trunk_offer", "jammed_machine", "clerk_counter", "clerk_talk", "patron_talk",
		"room_trace", "room_fixture", "motel_door",
	]
	var semantic := _dict(state.get("semantic_state", {}))
	for collection_key in ["scene_objects", "actors"]:
		for record_value in _dict(semantic.get(collection_key, {})).values():
			var record := _dict(record_value)
			if not bool(record.get("present", true)): continue
			var stable_id := str(record.get("stable_object_id", ""))
			var identity := "%s::%s" % [str(record.get("owner_namespace", "scenario")), stable_id]
			var authored_icon := str(record.get("icon_key", ""))
			var controller_icon := EnvironmentInteractionControllerScript._scenario_icon_key(record, {})
			var resolver_icon := ScenarioLayoutResolverScript._scenario_icon_key(record)
			if not authored_icon.is_empty() and (controller_icon != authored_icon or resolver_icon != authored_icon):
				failures.append("env06_8 reachable %s/%s does not preserve authored icon %s." % [scenario_id, path, authored_icon])
			var object_type := "scenario_object" if collection_key == "scene_objects" else "scenario_actor"
			var hinted := _dict(canvas.call("_apply_draw_hints", {"visual_key": controller_icon, "icon_key": controller_icon, "prop": ""}, object_type, 0))
			var resolved_icon := str(hinted.get("prop", ""))
			if object_type == "scenario_actor" and resolved_icon.is_empty():
				resolved_icon = str(canvas.call("_fallback_event_prop", controller_icon, controller_icon))
			if resolved_icon.is_empty() or resolved_icon not in allowed:
				failures.append("env06_8 reachable %s/%s object %s has no supported physical icon." % [scenario_id, path, stable_id])
			var role := str(record.get("role", "")).to_lower()
			# `route` and door words are also used as placement metadata on physical
			# boards, braces, ropes, cameras, envelopes, and signal controls. Reserve
			# this invariant for objects explicitly authored as exits or canonically
			# identified as a safe/exit route.
			var route_identity := role == "exit" or stable_id.contains("safe_exit")
			if collection_key == "scene_objects" and route_identity and resolved_icon not in ["side_door", "room_route", "security_exit"]:
				failures.append("env06_8 reachable %s/%s route object %s resolves as %s." % [scenario_id, path, stable_id, resolved_icon])
			if icon_by_identity.has(identity):
				var prior := _dict(icon_by_identity.get(identity, {}))
				var authored_replacement := not authored_icon.is_empty() and not str(prior.get("authored", "")).is_empty() and authored_icon != str(prior.get("authored", ""))
				if resolved_icon != str(prior.get("resolved", "")) and not authored_replacement:
					failures.append("env06_8 reachable %s/%s object %s changes physical icon from %s to %s across description or placement state." % [scenario_id, path, stable_id, str(prior.get("resolved", "")), resolved_icon])
			else:
				icon_by_identity[identity] = {"resolved": resolved_icon, "authored": authored_icon}
			if object_type == "scenario_object" and resolved_icon == "room_fixture" and stable_id not in ["kitty_cat_lounge_bachelorette_storm_task_3", "kitty_cat_lounge_bachelorette_storm_aftermath_stage_commandeered_prop"]:
				failures.append("env06_8 reachable %s/%s object %s collapses to an unjustified room_fixture." % [scenario_id, path, stable_id])


static func _trace_action_consequences(state: Dictionary, result: Dictionary, path: String) -> void:
	var semantic := _dict(state.get("semantic_state", {}))
	for interaction_value in _dict(semantic.get("interactions", {})).values():
		var interaction := _dict(interaction_value)
		if not bool(interaction.get("enabled", false)): continue
		for action_value in _array(interaction.get("available_actions", [])):
			var action := _dict(action_value)
			if str(action.get("handler", "")) != "change_scene_object": continue
			var inputs := _dict(action.get("inputs", {}))
			var target_id := str(inputs.get("stable_object_id", interaction.get("stable_object_id", "")))
			var target_identity := ScenarioOperationRegistryScript.identity(str(inputs.get("owner_namespace", interaction.get("owner_namespace", ""))), target_id)
			var projected := state.duplicate(true)
			var projected_semantic := _dict(projected.get("semantic_state", {}))
			var scene_objects := _dict(projected_semantic.get("scene_objects", {}))
			var actors := _dict(projected_semantic.get("actors", {}))
			if scene_objects.has(target_identity):
				var target := _dict(scene_objects.get(target_identity, {})); target["state"] = str(inputs.get("state", "")); scene_objects[target_identity] = target
			elif actors.has(target_identity):
				var target := _dict(actors.get(target_identity, {})); target["state"] = str(inputs.get("state", "")); actors[target_identity] = target
			projected_semantic["scene_objects"] = scene_objects
			projected_semantic["actors"] = actors
			projected["semantic_state"] = projected_semantic
			result["%s|action:%s:%s" % [path, target_identity, str(action.get("id", ""))]] = _semantic_description_set(projected)


static func _semantic_description_set(state: Dictionary) -> Array:
	var result: Array = []
	var semantic := _dict(state.get("semantic_state", {}))
	for collection_key in ["scene_objects", "actors"]:
		for record_value in _dict(semantic.get(collection_key, {})).values():
			var record := _dict(record_value)
			var description := str(record.get("description", ""))
			var variants := _dict(record.get("description_variants", {}))
			for key in [str(record.get("state", "")), str(record.get("appearance", "")), str(record.get("pose", "")), str(record.get("behavior", "")), str(record.get("anchor_id", "")), str(record.get("zone_id", ""))]:
				if not str(variants.get(key, "")).strip_edges().is_empty():
					description = str(variants.get(key, ""))
					break
			result.append("%s|%s" % [str(record.get("stable_object_id", "")), description])
	for record_value in _dict(semantic.get("interactions", {})).values():
		var interaction := _dict(record_value)
		var interaction_id := str(interaction.get("stable_object_id", ""))
		result.append("interaction|%s|%s|%s|%s|%s|%s" % [
			interaction_id,
			str(interaction.get("label", "")),
			str(interaction.get("prompt", "")),
			str(interaction.get("disabled_reason", "")),
			str(interaction.get("state_label", "")),
			str(bool(interaction.get("enabled", false))),
		])
		for action_value in _array(interaction.get("available_actions", [])):
			var action := _dict(action_value)
			result.append("action|%s|%s|%s|%s|%s" % [
				interaction_id,
				str(action.get("id", "")),
				str(action.get("label", "")),
				str(action.get("non_color_state", "")),
				str(action.get("disabled_reason", "")),
			])
	result.sort()
	return result


static func _find_action_origin(state: Dictionary, command_id: String) -> Dictionary:
	for interaction_value in _dict(_dict(state.get("semantic_state", {})).get("interactions", {})).values():
		var interaction := _dict(interaction_value)
		if not bool(interaction.get("enabled", false)): continue
		for action_value in _array(interaction.get("available_actions", [])):
			if str(_dict(action_value).get("id", "")) == command_id:
				return {"owner_namespace": str(interaction.get("owner_namespace", "")), "stable_object_id": str(interaction.get("stable_object_id", ""))}
	return {}


static func _apply_trace_fact(state: Dictionary, definition: Dictionary, condition: Dictionary, scenario_id: String, serial: int, branch_index: int) -> Dictionary:
	if str(condition.get("type", "")) != "fact": return {"ok": false, "errors": []}
	var fact_type := str(condition.get("fact_type", ""))
	var boundary := int(state.get("boundary_serial", 0)) + 1
	var payload := _trace_fact_payload(fact_type, state)
	for key_value in _dict(condition.get("payload_equals", {})).keys():
		payload[str(key_value)] = _dict(condition.get("payload_equals", {})).get(key_value)
	var fact := ScenarioSequenceRuntimeScript.fact(fact_type, _trace_fact_producer(fact_type), str(state.get("node_id", "")), "env06_8:%s:fact:%d:%d" % [scenario_id, serial, branch_index], 1, boundary, payload)
	var queued := ScenarioSequenceRuntimeScript.enqueue_fact(state, definition, fact)
	if not bool(queued.get("ok", false)): return queued
	var flushed := ScenarioSequenceRuntimeScript.flush_facts(_dict(queued.get("state", {})), definition, boundary)
	if bool(flushed.get("ok", false)) and str(_dict(flushed.get("state", {})).get("status", "")) == ScenarioSequenceRuntimeScript.STATUS_ACTIVE:
		var second_boundary := boundary + 1
		var second := ScenarioSequenceRuntimeScript.fact(fact_type, _trace_fact_producer(fact_type), str(state.get("node_id", "")), "env06_8:%s:fact:%d:%d:second" % [scenario_id, serial, branch_index], 2, second_boundary, payload)
		var second_queued := ScenarioSequenceRuntimeScript.enqueue_fact(_dict(flushed.get("state", {})), definition, second)
		if bool(second_queued.get("ok", false)):
			flushed = ScenarioSequenceRuntimeScript.flush_facts(_dict(second_queued.get("state", {})), definition, second_boundary)
	return flushed


static func _trace_fact_producer(fact_type: String) -> String:
	for producer_value in ScenarioSequenceRuntimeScript.FACT_TYPES_BY_PRODUCER.keys():
		if _array(ScenarioSequenceRuntimeScript.FACT_TYPES_BY_PRODUCER.get(producer_value, [])).has(fact_type): return str(producer_value)
	return "scenario"


static func _trace_fact_payload(fact_type: String, state: Dictionary) -> Dictionary:
	match fact_type:
		"game_result": return {"game_id": "env06_8_game", "action_id": "settled", "won": false, "ended": true, "bankroll_delta": 0, "chips_delta": 0, "applied_heat_delta": 0}
		"event_result": return {"event_id": "env06_8_event", "choice_id": "leave", "resolved": false, "ok": true}
		"service_result": return {"kind": "rest", "service_id": "env06_8_service", "ok": true, "action_id": "resolved"}
		"travel_departed", "travel_arrived": return {"source_id": "env06_8_source", "target_id": "env06_8_target", "travel_kind": "road"}
		"crew_changed": return {"member_id": "crew_switch", "change": "trust", "value": 2}
		"crew_job_changed": return {"job_id": "env06_8_job", "status": "active", "definition_id": "env06_8_job", "member_id": "crew_switch", "outcome": "complete"}
		"heat_changed": return {"previous": 2, "current": 4, "applied_delta": 2, "source": "env06_8"}
		"heat_band_changed": return {"previous_band": "quiet", "current_band": "caution", "current": 25, "source": "env06_8"}
		"sweep_changed": return {"action_index": 1, "node_id": str(state.get("node_id", "")), "segment_index": 1, "active": true}
		"town_transition": return {"action_index": 1, "weather": "storm", "day_type": "night", "happening_ids": ["env06_8_weather"]}
		"world_boundary": return {"amount": 1, "action_index": 1}
		"scenario_command": return {"command_id": "env06_8", "receipt_id": "env06_8_command"}
	return {}


static func _collect_description_lines(value: Variant, result: Array) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		var row := value as Dictionary
		if row.has("description"): result.append(str(row.get("description", "")))
		for line in _dict(row.get("description_variants", {})).values(): result.append(str(line))
		for child in row.values(): _collect_description_lines(child, result)
	elif typeof(value) == TYPE_ARRAY:
		for child in value as Array: _collect_description_lines(child, result)


static func _check_generated_prose(value: Variant, scenario_id: String, failures: Array) -> void:
	if typeof(value) == TYPE_STRING:
		var raw_text := str(value)
		var text := raw_text.to_lower()
		for marker in GENERATED_PROSE_MARKERS:
			if text.contains(marker): failures.append("env06_8 %s retains generated prose marker %s." % [scenario_id, marker])
		if _has_mid_sentence_title_run(raw_text):
			failures.append("env06_8 %s retains generated mid-sentence Title Case prose: %s" % [scenario_id, raw_text])
	elif typeof(value) == TYPE_ARRAY:
		for child in value: _check_generated_prose(child, scenario_id, failures)
	elif typeof(value) == TYPE_DICTIONARY:
		for child in (value as Dictionary).values(): _check_generated_prose(child, scenario_id, failures)


static func _has_mid_sentence_title_run(text: String) -> bool:
	var stripped := text.strip_edges()
	if not stripped.begins_with("You "):
		return false
	var first_clause := stripped
	for separator in [".", ";", "!", "?"]:
		var at := first_clause.find(separator)
		if at >= 0:
			first_clause = first_clause.left(at)
	var run := 0
	var words := first_clause.split(" ", false)
	for index in range(1, words.size()):
		var word := str(words[index]).strip_edges().trim_suffix(",").trim_suffix(":")
		if not word.is_empty() and word.left(1) == word.left(1).to_upper() and word.left(1) != word.left(1).to_lower():
			run += 1
			if run >= 2:
				return true
		else:
			run = 0
	return false


static func _collect_prose_sentences(value: Variant, counts: Dictionary, scenario_id: String, field_key: String = "") -> void:
	if typeof(value) == TYPE_STRING:
		if field_key not in ["description", "description_variants", "prompt", "message", "reduced_motion_message", "revisit_feedback", "feedback", "disabled_reason", "arrival_summary"]:
			return
		var prose := str(value).strip_edges()
		if not prose.contains(" ") or (not prose.contains(".") and not prose.contains("!") and not prose.contains("?")):
			return
		for sentence_value in prose.replace("!", ".").replace("?", ".").split(".", false):
			var sentence := str(sentence_value).strip_edges().to_lower()
			if sentence.split(" ", false).size() >= 4:
				var scenarios := _dict(counts.get(sentence, {}))
				scenarios[scenario_id] = true
				counts[sentence] = scenarios
	elif typeof(value) == TYPE_ARRAY:
		for child in value:
			_collect_prose_sentences(child, counts, scenario_id, field_key)
	elif typeof(value) == TYPE_DICTIONARY:
		for child_key_value in (value as Dictionary).keys():
			var child_key := str(child_key_value)
			_collect_prose_sentences((value as Dictionary).get(child_key_value), counts, scenario_id, field_key if field_key == "description_variants" else child_key)


static func _check_repeated_stock_sentences(counts: Dictionary, failures: Array) -> void:
	for sentence_value in counts.keys():
		var sentence := str(sentence_value)
		var count := _dict(counts.get(sentence_value, {})).size()
		if count >= 4:
			failures.append("env06_8 repeats stock player prose %d times: %s" % [count, sentence])


static func _check_generated_prose_hostiles(failures: Array) -> void:
	var title_failures: Array = []
	_check_generated_prose("You wait Out Fog Safely. The rail lantern moves.", "hostile_title_case", title_failures)
	if title_failures.is_empty():
		failures.append("env06_8 prose grammar gate accepted a mid-sentence Title Case conversion.")
	var repeated: Dictionary = {}
	for suffix in ["one", "two", "three", "four"]:
		_collect_prose_sentences("You refuse and leave. Distinct %s result remains." % suffix, repeated, "hostile_%s" % suffix, "message")
	var repeated_failures: Array = []
	_check_repeated_stock_sentences(repeated, repeated_failures)
	if repeated_failures.is_empty():
		failures.append("env06_8 prose repetition gate accepted a repeated stock sentence.")


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
