extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const SequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const RolloutManifestScript := preload("res://scripts/core/scenario_sequence_rollout_manifest.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const LOCAL_ACTOR_SCENARIO_ID := "bar_fight_night"
const PROVEN_TARGET_SCENARIO_ID := "corner_store_delivery_day"
const ROUTE_FREE_WORK_MOVES := {
	"back_alley_street_craps": "street_shooter",
	"back_alley_cruiser_parked": "patrol_officer",
	"back_alley_nothing_moving": "returning_regular",
}
const PRESERVED_ROUTE_WORK_MOVES := {
	"pawn_shop_estate_lot_day": "estate_appraiser",
	"pawn_shop_serial_check_day": "records_clerk",
	"pawn_shop_sals_mood": "sal_shopkeeper",
}


class ProductionInstallProbe:
	extends RunGenerator

	var last_result: Dictionary = {}

	func _install_environment(run_state: RunState, environment_data: Dictionary) -> Dictionary:
		var installed := run_state.set_environment(environment_data)
		var finalized := run_state.scenario_finalize_installed_environment(library) if bool(installed.get("ok", false)) else installed
		last_result = {
			"archetype_id": str(environment_data.get("archetype_id", "")),
			"scenario_id": str(environment_data.get("scenario_id", "")),
			"ok": bool(finalized.get("ok", false)),
			"errors": (finalized.get("errors", []) as Array).duplicate(true) if typeof(finalized.get("errors", [])) == TYPE_ARRAY else [],
		}
		return finalized


func _initialize() -> void:
	var failures: Array = []
	var library := ContentLibraryScript.new()
	library.load(false)
	_check_scenario_local_actor_authority(library, failures)
	_check_manifest_exit_authority(library, failures)
	_check_manifest_installed_finalization(library, failures)
	_check_route_free_work_moves(library, failures)
	_check_preserved_route_work_moves(library, failures)
	_check_fence_night_route_free_authority(library, failures)
	_check_unproven_zone_rejection(library, failures)
	if failures.is_empty():
		print("ENV06_7_PRODUCTION_AUTHORITY_CONTRACT_OK local_actor=1 hostile_actor=2 exit_authority=55 exit_cleanup=55 installed_finalization=55 route_free_work_move=3 preserved_route_work_move=3 fence_route_free=1 fence_exit=1 hostile_zone=2")
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


static func _check_manifest_exit_authority(library: Variant, failures: Array) -> void:
	var scenario_ids := RolloutManifestScript.expected_ids()
	if scenario_ids.size() != RolloutManifestScript.EXPECTED_COUNT:
		failures.append("Rollout manifest no longer contains the exact 55-scenario authority set.")
		return
	for scenario_id_value in scenario_ids:
		var scenario_id := str(scenario_id_value)
		var definition: Dictionary = library.scenario(scenario_id)
		if definition.is_empty():
			failures.append("Production scenario %s is missing from the manifest-backed catalog." % scenario_id)
			continue
		var catalog_errors := _array(library.scenario_target_catalog(definition).get("errors", []))
		if not catalog_errors.is_empty():
			failures.append("Production scenario %s lacks valid target authority: %s" % [scenario_id, JSON.stringify(catalog_errors)])
		var sequence := _dict(definition.get("sequence", {}))
		var cleanup := _array(_dict(sequence.get("cleanup", {})).get("operations", []))
		var exit_ids: Array = []
		var exit_scenes: Dictionary = {}
		for phase_value in _array(_dict(sequence.get("phase_graph", {})).get("phases", [])):
			var phase := _dict(phase_value)
			for operation_value in _array(phase.get("interaction_ops", [])):
				var operation := _dict(operation_value)
				var interaction := _dict(operation.get("interaction", {}))
				if str(operation.get("op", "")) == "add" and bool(interaction.get("safe_exit", false)) and bool(interaction.get("enabled", false)):
					exit_ids.append(str(operation.get("stable_object_id", "")))
			for operation_value in _array(phase.get("scene_ops", [])):
				var operation := _dict(operation_value)
				var object := _dict(operation.get("object", {}))
				if str(operation.get("op", "")) == "spawn" \
						and str(object.get("role", "")) == "exit" \
						and str(object.get("zone_id", "")) == "exit_lane" \
						and bool(object.get("visible", false)) \
						and bool(object.get("enabled", false)):
					exit_scenes[str(operation.get("stable_object_id", ""))] = true
		if exit_ids.is_empty():
			failures.append("Production scenario %s has no enabled safe-exit interaction." % scenario_id)
			continue
		for exit_id_value in exit_ids:
			var exit_id := str(exit_id_value)
			if exit_id.is_empty() or not exit_scenes.has(exit_id):
				failures.append("Production scenario %s lacks same-identity exit layout authority for %s." % [scenario_id, exit_id])
			var scene_removed := false
			var interaction_removed := false
			for cleanup_value in cleanup:
				var operation := _dict(cleanup_value)
				if str(operation.get("op", "")) != "remove" or str(operation.get("stable_object_id", "")) != exit_id:
					continue
				scene_removed = scene_removed or str(operation.get("family", "")) == "scene_ops"
				interaction_removed = interaction_removed or str(operation.get("family", "")) == "interaction_ops"
			if not scene_removed or not interaction_removed:
				failures.append("Production scenario %s lacks symmetric exit cleanup for %s." % [scenario_id, exit_id])


static func _check_manifest_installed_finalization(library: Variant, failures: Array) -> void:
	for scenario_id_value in RolloutManifestScript.expected_ids():
		var scenario_id := str(scenario_id_value)
		var definition: Dictionary = library.scenario(scenario_id)
		var archetype_id := str(definition.get("archetype_id", ""))
		if archetype_id.is_empty():
			failures.append("Production install fixture %s lacks an archetype." % scenario_id)
			continue
		var seed := "ENV06-7-INSTALL-CONTRACT-%s" % scenario_id
		var run_state := RunStateScript.new()
		run_state.start_new(seed, RunStateScript.custom_challenge("install_%s" % scenario_id, seed, {
			"home_archetype_id": archetype_id,
			"scenario_pins": {archetype_id: scenario_id},
			"scenario_pins_apply_mutations": true,
		}))
		run_state.begin_act(1)
		var generator := ProductionInstallProbe.new(library)
		generator.next_environment(run_state)
		var result := generator.last_result
		if str(result.get("scenario_id", "")) != scenario_id \
				or str(result.get("archetype_id", "")) != archetype_id \
				or not bool(result.get("ok", false)):
			failures.append("Production installed finalizer rejected %s: %s" % [scenario_id, JSON.stringify(_array(result.get("errors", [])))])


static func _check_route_free_work_moves(library: Variant, failures: Array) -> void:
	for scenario_id_value in ROUTE_FREE_WORK_MOVES.keys():
		var scenario_id := str(scenario_id_value)
		var actor_id := str(ROUTE_FREE_WORK_MOVES.get(scenario_id, ""))
		var definition: Dictionary = library.scenario(scenario_id)
		var arrival_actor := _dict(_first_actor_spawn(definition).get("actor", {}))
		if str(arrival_actor.get("actor_id", "")) != actor_id or not str(arrival_actor.get("route_id", "")).is_empty():
			failures.append("Production scenario %s did not keep %s route-free at arrival." % [scenario_id, actor_id])
		var work_move := false
		for phase_value in _array(_dict(_dict(definition.get("sequence", {})).get("phase_graph", {})).get("phases", [])):
			for operation_value in _array(_dict(phase_value).get("actor_ops", [])):
				var operation := _dict(operation_value)
				if str(operation.get("op", "")) == "set_position" \
						and str(operation.get("stable_object_id", "")) == actor_id \
						and str(operation.get("zone_id", "")) == "service_lane":
					work_move = true
		if not work_move:
			failures.append("Production scenario %s lost the later %s move to service_lane." % [scenario_id, actor_id])


static func _check_preserved_route_work_moves(library: Variant, failures: Array) -> void:
	for scenario_id_value in PRESERVED_ROUTE_WORK_MOVES.keys():
		var scenario_id := str(scenario_id_value)
		var actor_id := str(PRESERVED_ROUTE_WORK_MOVES.get(scenario_id, ""))
		var definition: Dictionary = library.scenario(scenario_id)
		var arrival_actor := _dict(_first_actor_spawn(definition).get("actor", {}))
		if str(arrival_actor.get("actor_id", "")) != actor_id or str(arrival_actor.get("route_id", "")) != "pawn_service_counter":
			failures.append("Production scenario %s did not preserve %s on pawn_service_counter at arrival." % [scenario_id, actor_id])
		var work_move := false
		for phase_value in _array(_dict(_dict(definition.get("sequence", {})).get("phase_graph", {})).get("phases", [])):
			for operation_value in _array(_dict(phase_value).get("actor_ops", [])):
				var operation := _dict(operation_value)
				if str(operation.get("op", "")) == "set_position" \
						and str(operation.get("stable_object_id", "")) == actor_id \
						and str(operation.get("zone_id", "")) == "service_lane":
					work_move = true
		if not work_move:
			failures.append("Production scenario %s lost the later %s move to service_lane." % [scenario_id, actor_id])


static func _check_fence_night_route_free_authority(library: Variant, failures: Array) -> void:
	var definition: Dictionary = library.scenario("back_alley_fence_night")
	var arrival_actor := _dict(_first_actor_spawn(definition).get("actor", {}))
	if str(arrival_actor.get("actor_id", "")) != "rotating_buyer" or not str(arrival_actor.get("route_id", "")).is_empty():
		failures.append("Fence Night arrival buyer did not remain route-free at the collision boundary.")
		return
	var phases := _array(_dict(_dict(definition.get("sequence", {})).get("phase_graph", {})).get("phases", []))
	var work_move := false
	var exit_scene := false
	var exit_interaction := false
	var exit_scene_cleanup := false
	var exit_interaction_cleanup := false
	var cleanup := _dict(_dict(definition.get("sequence", {})).get("cleanup", {}))
	for operation_value in _array(cleanup.get("operations", [])):
		var operation := _dict(operation_value)
		if str(operation.get("op", "")) != "remove" or str(operation.get("stable_object_id", "")) != "back_alley_fence_night_exit":
			continue
		exit_scene_cleanup = exit_scene_cleanup or str(operation.get("family", "")) == "scene_ops"
		exit_interaction_cleanup = exit_interaction_cleanup or str(operation.get("family", "")) == "interaction_ops"
	for phase_value in phases:
		var phase := _dict(phase_value)
		if str(phase.get("id", "")) == "work":
			for operation_value in _array(phase.get("actor_ops", [])):
				var operation := _dict(operation_value)
				if str(operation.get("op", "")) == "set_position" \
						and str(operation.get("stable_object_id", "")) == "rotating_buyer" \
						and str(operation.get("zone_id", "")) == "service_lane":
					work_move = true
		if str(phase.get("id", "")) != "arrival":
			continue
		for operation_value in _array(phase.get("scene_ops", [])):
			var operation := _dict(operation_value)
			var object := _dict(operation.get("object", {}))
			if str(operation.get("op", "")) == "spawn" \
					and str(operation.get("stable_object_id", "")) == "back_alley_fence_night_exit" \
					and str(object.get("zone_id", "")) == "exit_lane" \
					and str(object.get("role", "")) == "exit":
				exit_scene = true
		for operation_value in _array(phase.get("interaction_ops", [])):
			var operation := _dict(operation_value)
			var interaction := _dict(operation.get("interaction", {}))
			if str(operation.get("op", "")) == "add" \
					and str(operation.get("stable_object_id", "")) == "back_alley_fence_night_exit" \
					and str(interaction.get("stable_object_id", "")) == "back_alley_fence_night_exit" \
					and bool(interaction.get("safe_exit", false)):
				exit_interaction = true
	if not work_move:
		failures.append("Fence Night lost the exact work-phase rotating_buyer move to service_lane.")
	if not exit_scene or not exit_interaction:
		failures.append("Fence Night lacks matching arrival exit visual/interaction authority in exit_lane.")
	if not exit_scene_cleanup or not exit_interaction_cleanup:
		failures.append("Fence Night cleanup is not symmetric for its exit scene and interaction identity.")


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
