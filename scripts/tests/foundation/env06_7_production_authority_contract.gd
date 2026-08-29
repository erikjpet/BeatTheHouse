extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const SequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")

const LOCAL_ACTOR_SCENARIO_ID := "bar_fight_night"
const PROVEN_TARGET_SCENARIO_ID := "corner_store_delivery_day"
const LOCAL_ROUTE_SCENARIOS := {
	"back_alley_street_craps": "alley_service_counter",
	"back_alley_cruiser_parked": "alley_service_counter",
	"back_alley_fence_night": "alley_service_counter",
	"back_alley_nothing_moving": "alley_service_counter",
	"pawn_shop_estate_lot_day": "pawn_service_counter",
	"pawn_shop_serial_check_day": "pawn_service_counter",
	"pawn_shop_sals_mood": "pawn_service_counter",
}


func _initialize() -> void:
	var failures: Array = []
	var library := ContentLibraryScript.new()
	library.load(false)
	_check_scenario_local_actor_authority(library, failures)
	_check_scenario_local_route_authority(library, failures)
	_check_unproven_zone_rejection(library, failures)
	if failures.is_empty():
		print("ENV06_7_PRODUCTION_AUTHORITY_CONTRACT_OK local_actor=1 hostile_actor=2 local_route=7 hostile_route=7 hostile_zone=2")
		quit(0)
		return
	for failure_value in failures:
		printerr("ENV06_7_PRODUCTION_AUTHORITY_CONTRACT_FAIL %s" % str(failure_value))
	quit(1)


static func _check_scenario_local_actor_authority(library: Variant, failures: Array) -> void:
	var production_definition: Dictionary = library.scenario(LOCAL_ACTOR_SCENARIO_ID)
	if production_definition.is_empty():
		failures.append("Production scenario %s is missing." % LOCAL_ACTOR_SCENARIO_ID)
		return
	var definition := _actor_authority_projection(production_definition)
	if definition.is_empty():
		failures.append("Production scenario %s has no actor spawn fixture." % LOCAL_ACTOR_SCENARIO_ID)
		return
	var references := {
		"archetype_ids": {str(definition.get("archetype_id", "")): true},
		"actor_ids": {},
		"archetype": library.environment_archetype(str(definition.get("archetype_id", ""))),
	}
	var positive_errors := ScenarioEngineScript.validate_sequence_definition(definition, references)
	if _contains(positive_errors, "references unknown actor") or _contains(positive_errors, "references unknown actors id"):
		failures.append("Structurally valid scenario-owned local actor was rejected: %s" % _matching(positive_errors, "references unknown actor"))

	var malformed: Dictionary = definition.duplicate(true)
	if _mutate_first_actor_spawn(malformed, "malformed"):
		var malformed_errors := ScenarioEngineScript.validate_sequence_definition(malformed, references)
		if not _contains(malformed_errors, "actor requires label and actor_id") or not _contains(malformed_errors, "references unknown actor") or not _contains(malformed_errors, "references unknown actors id"):
			failures.append("Malformed scenario-local actor did not fail structure, spawn authority, and authoring-reference authority checks.")

	var external: Dictionary = definition.duplicate(true)
	if _mutate_first_actor_spawn(external, "external"):
		var external_errors := ScenarioEngineScript.validate_sequence_definition(external, references)
		if not _contains(external_errors, "references unknown actor hostile_external_actor") or not _contains(external_errors, "references unknown actors id"):
			failures.append("External unknown actor was not rejected by spawn and authoring-reference authority.")


static func _check_unproven_zone_rejection(library: Variant, failures: Array) -> void:
	var definition: Dictionary = library.scenario(PROVEN_TARGET_SCENARIO_ID)
	var catalog: Dictionary = library.scenario_target_catalog(definition)
	var catalog_errors := _array(catalog.get("errors", []))
	if definition.is_empty() or catalog.is_empty() or not catalog_errors.is_empty():
		failures.append("Production target authority fixture is unavailable: %s" % JSON.stringify(catalog_errors))
		return
	var inventory := _dict(catalog.get("guaranteed", {}))
	inventory["event_choices"] = _dict(catalog.get("event_choices", {}))
	for zone_id in ["work_2", "hostile_arbitrary_zone"]:
		var hostile := {
			"id": str(definition.get("id", "")),
			"archetype_id": str(definition.get("archetype_id", "")),
			"sequence": {
				"schema_version": int(_dict(definition.get("sequence", {})).get("schema_version", 0)),
				"declared_targets": _dict(_dict(definition.get("sequence", {})).get("declared_targets", {})),
			},
		}
		var zones := _array(hostile["sequence"]["declared_targets"].get("zones", []))
		zones.append("base::zone:%s" % zone_id)
		hostile["sequence"]["declared_targets"]["zones"] = zones
		var errors := SequenceSchemaScript.validate_definition(hostile, OperationRegistryScript, inventory)
		if not _contains(errors, "is not present in the validated archetype/base inventory"):
			failures.append("Unproven production zone %s was not rejected." % zone_id)


static func _check_scenario_local_route_authority(library: Variant, failures: Array) -> void:
	for scenario_id_value in LOCAL_ROUTE_SCENARIOS.keys():
		var scenario_id := str(scenario_id_value)
		var expected_route := str(LOCAL_ROUTE_SCENARIOS.get(scenario_id, ""))
		var definition: Dictionary = library.scenario(scenario_id)
		var operation := _first_actor_spawn(definition)
		var actor := _dict(operation.get("actor", {}))
		if str(actor.get("route_id", "")) != expected_route:
			failures.append("Production scenario %s does not bind its local actor to exact canonical route %s." % [scenario_id, expected_route])
			continue
		var catalog: Dictionary = library.scenario_target_catalog(definition)
		var catalog_errors := _array(catalog.get("errors", []))
		var inventory := _dict(catalog.get("guaranteed", {}))
		inventory["event_choices"] = _dict(catalog.get("event_choices", {}))
		if not catalog_errors.is_empty() or not _array(inventory.get("anchors", [])).has("base::anchor:%s" % expected_route):
			failures.append("Production scenario %s lacks sealed anchor proof for local route %s: %s" % [scenario_id, expected_route, JSON.stringify(catalog_errors)])
			continue
		var references := {
			"archetype_ids": {str(definition.get("archetype_id", "")): true},
			"actor_ids": {},
			"archetype": library.environment_archetype(str(definition.get("archetype_id", ""))),
			"scenario_semantic_inventory": _dict(catalog.get("inventory", {})),
		}
		var positive_errors := ScenarioEngineScript.validate_sequence_definition(definition, references, inventory)
		if not positive_errors.is_empty():
			failures.append("Canonical local route %s/%s did not resolve from production authority: %s" % [scenario_id, expected_route, JSON.stringify(positive_errors)])
			continue
		var hostile := definition.duplicate(true)
		if not _mutate_first_actor_route(hostile, "%s_unproven_route" % scenario_id):
			failures.append("Production scenario %s has no local actor route fixture." % scenario_id)
			continue
		var hostile_errors := ScenarioEngineScript.validate_sequence_definition(hostile, references, inventory)
		if not _contains(hostile_errors, "unresolved route") or not _contains(hostile_errors, "unknown sealed route/anchor alias"):
			failures.append("Hostile local route alias for %s was not rejected by sealed production authority: %s" % [scenario_id, JSON.stringify(hostile_errors)])


static func _actor_authority_projection(definition: Dictionary) -> Dictionary:
	var source_sequence := _dict(definition.get("sequence", {}))
	var source_phases := _array(_dict(source_sequence.get("phase_graph", {})).get("phases", []))
	for source_phase_value in source_phases:
		for operation_value in _array(_dict(source_phase_value).get("actor_ops", [])):
			var operation := _dict(operation_value)
			if str(operation.get("family", "")) != "actor_ops" or str(operation.get("op", "")) != "spawn":
				continue
			return {
				"id": str(definition.get("id", "")),
				"archetype_id": str(definition.get("archetype_id", "")),
				"sequence_authoring": {"references": {"actors": [str(_dict(operation.get("actor", {})).get("actor_id", ""))]}},
				"sequence": {
					"schema_version": int(source_sequence.get("schema_version", 0)),
					"phase_graph": {
						"initial_phase": "actor_authority",
						"phases": [{
							"id": "actor_authority", "label": "Actor authority", "arrival_feedback": "Authority fixture.",
							"exit_prompt": "Exit.", "terminal": true, "entry_conditions": [], "objective_ids": [],
							"advance_after_actions": 0, "scene_ops": [], "interaction_ops": [], "actor_ops": [operation],
							"transition_ops": [], "branches": [{"id": "actor_authority_done", "condition": {"type": "always"}, "outcome": "authority_done"}],
						}],
					},
				},
			}
	return {}


static func _first_actor_spawn(definition: Dictionary) -> Dictionary:
	for phase_value in _array(_dict(_dict(definition.get("sequence", {})).get("phase_graph", {})).get("phases", [])):
		for operation_value in _array(_dict(phase_value).get("actor_ops", [])):
			var operation := _dict(operation_value)
			if str(operation.get("family", "")) == "actor_ops" and str(operation.get("op", "")) == "spawn":
				return operation
	return {}


static func _mutate_first_actor_route(definition: Dictionary, route_id: String) -> bool:
	var phases: Array = _array(_dict(_dict(definition.get("sequence", {})).get("phase_graph", {})).get("phases", []))
	for phase_index in range(phases.size()):
		var phase := _dict(phases[phase_index])
		var operations := _array(phase.get("actor_ops", []))
		for operation_index in range(operations.size()):
			var operation := _dict(operations[operation_index])
			if str(operation.get("family", "")) != "actor_ops" or str(operation.get("op", "")) != "spawn":
				continue
			var actor := _dict(operation.get("actor", {}))
			actor["route_id"] = route_id
			operation["actor"] = actor
			operations[operation_index] = operation
			phase["actor_ops"] = operations
			phases[phase_index] = phase
			definition["sequence"]["phase_graph"]["phases"] = phases
			return true
	return false


static func _mutate_first_actor_spawn(definition: Dictionary, mode: String) -> bool:
	var phases: Array = _array(_dict(_dict(definition.get("sequence", {})).get("phase_graph", {})).get("phases", []))
	for phase_index in range(phases.size()):
		var phase := _dict(phases[phase_index])
		var operations := _array(phase.get("actor_ops", []))
		for operation_index in range(operations.size()):
			var operation := _dict(operations[operation_index])
			if str(operation.get("family", "")) != "actor_ops" or str(operation.get("op", "")) != "spawn":
				continue
			var actor := _dict(operation.get("actor", {}))
			if mode == "malformed":
				actor["label"] = ""
			elif mode == "external":
				operation["owner_namespace"] = "base"
				actor["actor_id"] = "hostile_external_actor"
			operation["actor"] = actor
			operations[operation_index] = operation
			phase["actor_ops"] = operations
			phases[phase_index] = phase
			definition["sequence"]["phase_graph"]["phases"] = phases
			return true
	return false


static func _matching(values: Array, needle: String) -> String:
	for value in values:
		if str(value).contains(needle):
			return str(value)
	return ""


static func _contains(values: Array, needle: String) -> bool:
	return not _matching(values, needle).is_empty()


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
