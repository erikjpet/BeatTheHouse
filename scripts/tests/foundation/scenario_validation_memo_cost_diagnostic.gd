extends SceneTree
const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")
const Registry := preload("res://scripts/core/scenario_operation_registry.gd")
const Catalog := preload("res://scripts/core/scenario_sequence_catalog.gd")
const Library := preload("res://scripts/core/content_library.gd")

func _init() -> void:
	var library := Library.new()
	library.load(true)
	var fixtures: Array[Dictionary] = []
	for pool in library.environment_scenarios.values():
		for scenario in pool:
			var definition := Catalog.apply_overlay(scenario, library.scenario_sequence_catalog)
			if not Schema.is_sequence(definition): continue
			var target_catalog := library.scenario_target_catalog(definition)
			var targets: Dictionary = target_catalog.get("guaranteed", {}).duplicate(true)
			targets["event_choices"] = target_catalog.get("event_choices", {}).duplicate(true)
			fixtures.append({"definition": definition, "targets": targets})
	var legacy_usec := 0
	var typed_usec := 0
	var samples := 0
	for iteration in range(3):
		for fixture in fixtures:
			var started := Time.get_ticks_usec()
			if iteration % 2 == 0:
				_legacy_key(fixture.definition, fixture.targets)
				legacy_usec += Time.get_ticks_usec() - started
				started = Time.get_ticks_usec()
				Schema._successful_validation_memo_key(fixture.definition, fixture.targets, Registry)
				typed_usec += Time.get_ticks_usec() - started
			else:
				Schema._successful_validation_memo_key(fixture.definition, fixture.targets, Registry)
				typed_usec += Time.get_ticks_usec() - started
				started = Time.get_ticks_usec()
				_legacy_key(fixture.definition, fixture.targets)
				legacy_usec += Time.get_ticks_usec() - started
			samples += 1
	var fixture := fixtures[0]
	Schema._clear_successful_validation_memo_for_tests()
	var errors := Schema.validate_definition(fixture.definition, Registry, fixture.targets)
	var hits_started := Time.get_ticks_usec()
	for index in range(32):
		errors.append_array(Schema.validate_definition(fixture.definition, Registry, fixture.targets))
	var hits_usec := Time.get_ticks_usec() - hits_started
	var stats := Schema._successful_validation_memo_stats_for_tests()
	var ok := fixtures.size() == 55 and errors.is_empty() and int(stats.full_runs) == 1 and int(stats.hits) == 32 and int(stats.entries) == 1
	print(JSON.stringify({"kind":"native_key_cost_diagnostic", "ok":ok, "production_definitions":fixtures.size(), "samples_each":samples, "legacy_mean_usec":float(legacy_usec)/samples, "typed_mean_usec":float(typed_usec)/samples, "typed_legacy_ratio":float(typed_usec)/legacy_usec, "actual_32_hit_mean_usec":float(hits_usec)/32, "memo_stats":stats}))
	quit(0 if ok else 1)

func _legacy_key(definition: Dictionary, targets: Dictionary) -> String:
	var memo_definition := definition.duplicate(false)
	memo_definition.erase("__scenario_sequence_runtime_validated")
	memo_definition.erase("__scenario_sequence_catalog_resolved")
	return JSON.stringify({"memo_version":2, "definition":memo_definition, "target_inventory":Schema._validation_authority_memo_projection(definition, targets), "operation_registry":Schema._operation_registry_memo_identity(Registry)}).sha256_text()
