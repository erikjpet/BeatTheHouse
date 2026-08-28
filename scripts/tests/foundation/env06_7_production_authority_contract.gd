extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const SequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")

const LOCAL_ACTOR_SCENARIO_ID := "bar_fight_night"
const PROVEN_TARGET_SCENARIO_ID := "corner_store_delivery_day"


func _initialize() -> void:
	var failures: Array = []
	var library := ContentLibraryScript.new()
	library.load(false)
	_check_scenario_local_actor_authority(library, failures)
	_check_unproven_zone_rejection(library, failures)
	if failures.is_empty():
		print("ENV06_7_PRODUCTION_AUTHORITY_CONTRACT_OK local_actor=1 hostile_actor=2 hostile_zone=2")
		quit(0)
		return
	for failure_value in failures:
		printerr("ENV06_7_PRODUCTION_AUTHORITY_CONTRACT_FAIL %s" % str(failure_value))
	quit(1)


static func _check_scenario_local_actor_authority(library: Variant, failures: Array) -> void:
	var definition: Dictionary = library.scenario(LOCAL_ACTOR_SCENARIO_ID)
	if definition.is_empty():
		failures.append("Production scenario %s is missing." % LOCAL_ACTOR_SCENARIO_ID)
		return
	var references := {
		"archetype_ids": {str(definition.get("archetype_id", "")): true},
		"actor_ids": {},
		"archetype": library.environment_archetype(str(definition.get("archetype_id", ""))),
	}
	var positive_errors := ScenarioEngineScript.validate_sequence_definition(definition, references)
	if _contains(positive_errors, "references unknown actor"):
		failures.append("Structurally valid scenario-owned local actor was rejected: %s" % _matching(positive_errors, "references unknown actor"))

	var malformed: Dictionary = definition.duplicate(true)
	if not _mutate_first_actor_spawn(malformed, "malformed"):
		failures.append("Production scenario %s has no actor spawn fixture." % LOCAL_ACTOR_SCENARIO_ID)
	else:
		var malformed_errors := ScenarioEngineScript.validate_sequence_definition(malformed, references)
		if not _contains(malformed_errors, "actor requires label and actor_id") or not _contains(malformed_errors, "references unknown actor"):
			failures.append("Malformed scenario-local actor did not fail both structure and actor authority checks.")

	var external: Dictionary = definition.duplicate(true)
	if _mutate_first_actor_spawn(external, "external"):
		var external_errors := ScenarioEngineScript.validate_sequence_definition(external, references)
		if not _contains(external_errors, "references unknown actor hostile_external_actor"):
			failures.append("External unknown actor was not rejected by actor authority.")


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
		var hostile: Dictionary = definition.duplicate(true)
		var zones := _array(hostile["sequence"]["declared_targets"].get("zones", []))
		zones.append("base::zone:%s" % zone_id)
		hostile["sequence"]["declared_targets"]["zones"] = zones
		var errors := SequenceSchemaScript.validate_definition(hostile, OperationRegistryScript, inventory)
		if not _contains(errors, "is not present in the validated archetype/base inventory"):
			failures.append("Unproven production zone %s was not rejected." % zone_id)


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
