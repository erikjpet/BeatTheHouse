extends RefCounted

# Test setup only. Geometry and semantic admission come from the same current
# owners as production. No readiness flag, digest or successful result is minted.
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const BaseRecordsScript := preload("res://scripts/core/environment_base_semantic_records.gd")
const RegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const ResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")
const ControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")
const ModelScript := preload("res://scripts/ui/scenario_semantic_view_model.gd")


static func room(library: Variant, disabled: bool = false) -> Dictionary:
	if library == null:
		return {"ok": false, "errors": ["Projection fixture requires the loaded library."]}
	var archetype: Dictionary = library.environment_archetype("bar")
	var environment := {
		"id": "projection_contract_room", "archetype_id": "bar", "world_node_id": "projection_contract_node",
		"environment_visit_id": "projection_contract_visit", "current_layer_id": "",
		# An explicit non-catalog fixture identity selects the existing unscoped
		# authored map before generation; a clean bar deliberately has no generic
		# catalog scenario capacity. The real binder still selects/validates slots.
		"scenario_id": "projection_contract", "scenario_state": {"id": "projection_contract", "layer_id": ""},
		"game_ids": [], "event_ids": [], "service_ids": [], "lender_hooks": [], "item_offers": [],
		"travel_hooks": ["bar"], "next_archetypes": [],
		"semantic_anchors": archetype.get("semantic_anchors", {}).duplicate(true),
		"semantic_zones": archetype.get("semantic_zones", {}).duplicate(true),
		"layout": archetype.get("layout", {}).duplicate(true),
	}
	environment["layout"] = EnvironmentInstanceScript.ensure_generated_layout(environment, library)
	var authoritative := BaseRecordsScript.authoritative_interactable_records(environment, library)
	if not bool(authoritative.get("ok", false)): return authoritative
	var records: Array = []
	for value in authoritative.get("records", []):
		if str(value.get("object_id", "")) != "travel:leave": continue
		var record: Dictionary = value.duplicate(true)
		record["focus_order"] = 20
		if disabled:
			record["enabled"] = false
			record["disabled_reason"] = "Route unavailable."
		records.append(record)
	if records.size() != 1:
		return {"ok": false, "errors": ["Current room producer did not create its single leave control."]}
	var stamped := BaseRecordsScript.stamp_interactable_records(records, environment, library)
	return {"ok": stamped.get("ok", false), "errors": stamped.get("errors", []), "environment": environment, "records": stamped.get("records", [])}


static func resolve_then_project(base_records: Array, projection: Dictionary, environment: Dictionary = {}) -> Dictionary:
	var finalized := ResolverScript.resolve(base_records, projection, environment)
	return ControllerScript.project_finalized_sequence_interaction_result(base_records, finalized)


static func resolved_records(base_records: Array, projection: Dictionary, environment: Dictionary = {}) -> Array:
	return resolve_then_project(base_records, projection, environment).get("records", [])


static func console_interaction(stable_id: String = "console:night") -> Dictionary:
	return {
		"owner_namespace": "scenario", "stable_object_id": stable_id, "mode": "add", "present": true,
		"label": "Brace console", "state_label": "Exit lane exposed", "prompt": "Choose how to brace the lane.",
		"enabled": true, "disabled_reason": "", "available_actions": [
			{"id": "brace:exit", "label": "Brace exit", "input_action": "confirm", "non_color_state": "ready"},
			{"id": "refuse", "label": "Refuse", "input_action": "ui_down", "non_color_state": "choice"},
		],
		"input_actions": ["confirm", "ui_down"], "non_color_state": "ready", "focus_order": 1,
		"hit_bounds": {"w": 60.0, "h": 52.0}, "min_target_size": 44.0, "safe_exit": true, "alternate_exit": false,
	}


static func physical(library: Variant, stable_id: String = "console:night") -> Dictionary:
	var fixture := room(library)
	if not bool(fixture.get("ok", false)): return fixture
	var environment: Dictionary = fixture["environment"]
	var anchors: Dictionary = environment.get("semantic_anchors", {}).duplicate(true)
	anchors["projection_contract_console"] = {"position": [198.0, 190.0]}
	environment["semantic_anchors"] = anchors
	var identity := "scenario::" + stable_id
	var interaction := console_interaction(stable_id)
	# Brace/refuse are console commands. The generated Leave control owns the
	# room's safe exit. Tagging this prop as a safe exit selects a doorway's
	# 64px footprint in the current owner; author the concrete barrier instead.
	interaction["safe_exit"] = false
	var projection := {"scenario_id": "projection_contract", "phase_id": "arrival", "status": "active", "boundary_serial": 7, "semantic_state": {
		"scene_objects": {identity: {"owner_namespace": "scenario", "stable_object_id": stable_id, "present": true,
			"label": "Brace console", "description": "A braced service console changes the exit lane.", "role": "obstacle",
			"anchor_id": "projection_contract_console", "icon_key": "room_barrier", "bounds": {"w": 72.0, "h": 56.0},
			"visible": true, "enabled": true, "state": "braced", "appearance": "striped"}},
		"actors": {}, "interactions": {identity: interaction},
	}}
	var finalized := ResolverScript.resolve(fixture["records"], projection, environment)
	var published := ControllerScript.project_finalized_sequence_interaction_result(fixture["records"], finalized)
	var renderer := ResolverScript.sealed_renderer_snapshot(finalized)
	return {"ok": bool(published.get("ok", false)) and bool(renderer.get("ok", false)),
		"errors": published.get("errors", []) + renderer.get("errors", []), "environment": environment,
		"base_records": fixture["records"], "finalized": finalized, "public": published, "renderer": renderer}


static func reduced_projection(fixture: Dictionary, overlays: Array) -> Dictionary:
	if not bool(fixture.get("ok", false)): return fixture
	var closed := BaseRecordsScript.from_interactable_records(fixture["records"])
	if not bool(closed.get("ok", false)): return closed
	var reduced := RegistryScript.resolve_interactions(closed["interactions"], overlays)
	var interactions: Dictionary = {}
	for value in reduced.get("records", []):
		interactions[RegistryScript.identity_from(value)] = value
	var projection := {"scenario_id": "projection_contract", "phase_id": "arrival", "status": "active", "boundary_serial": 7,
		"semantic_state": {"scene_objects": {}, "actors": {}, "interactions": interactions}}
	var published := resolve_then_project(fixture["records"], projection, fixture["environment"])
	return {"ok": bool(reduced.get("ok", false)) and bool(published.get("ok", false)),
		"reduction": reduced, "public": published, "records": published.get("records", []),
		"errors": reduced.get("errors", []) + published.get("errors", [])}


static func accepted_token_unit_record(reduction: Dictionary, overlays: Array, enabled: bool = true) -> Dictionary:
	# This is explicitly a unit fixture for the retained legacy descriptor branch.
	# It has no room geometry/publication and cannot authenticate a room action.
	var inline: Array = []
	for accepted in reduction.get("accepted_overlay_source_identities", []):
		for overlay in overlays:
			if RegistryScript.identity_from(overlay) == str(accepted):
				var interaction: Dictionary = overlay.duplicate(true)
				interaction["enabled"] = enabled
				inline.append_array(ModelScript.inline_actions_for_interaction(interaction, 7))
	return {"interactive": true, "enabled": enabled, "inline_actions": inline}


static func augmented_action_ids(record: Dictionary) -> Array:
	var ids: Array = []
	var record_identity := RegistryScript.identity_from(record)
	for action in record.get("available_actions", []):
		# Registry stamps every action, including the host's ordinary action.
		# Only another complete source identity contributes an augment here.
		var origin := RegistryScript.identity(str(action.get("action_origin_owner_namespace", "")), str(action.get("action_origin_stable_object_id", "")))
		if origin != "::" and origin != record_identity: ids.append(str(action.get("id", "")))
	return ids
