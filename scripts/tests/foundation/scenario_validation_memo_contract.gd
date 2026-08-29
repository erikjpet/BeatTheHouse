extends SceneTree

const Catalog := preload("res://scripts/core/scenario_sequence_catalog.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const Registry := preload("res://scripts/core/scenario_operation_registry.gd")
const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")

const PRODUCTION_AUTHORITY_SHA256 := "d97b3dd830bc58b9b4d72b06a55bb9e1d67fdb1fc3299d473d7a4e11f4a4ce2c"


class RejectingRegistry:
	extends RefCounted

	func registered_operations() -> Dictionary:
		return {"hostile_registry": ["reject"]}

	func registered_handlers() -> Dictionary:
		return {}

	func validate_operation(_family: String, _operation: Dictionary) -> Array:
		return ["substitute registry rejected operation"]

	func validate_any_operation(_operation: Dictionary) -> Array:
		return ["substitute registry rejected operation"]

	func validate_handler_inputs(_handler_id: String, _inputs: Dictionary, _local_schema: Dictionary = {}, _reachable_outcomes: Array = [], _context: Dictionary = {}) -> Array:
		return ["substitute registry rejected handler"]


func _init() -> void:
	var failures: Array[String] = []
	Schema._clear_successful_validation_memo_for_tests()
	var load_started_usec := Time.get_ticks_usec()
	var library = ContentLibraryScript.new()
	library.load(true)
	var load_elapsed_ms := float(Time.get_ticks_usec() - load_started_usec) / 1000.0
	var authority: Dictionary = library.scenario_sequence_catalog.get("uniqueness_audit", {})
	if JSON.stringify(authority).sha256_text() != PRODUCTION_AUTHORITY_SHA256 or (authority.get("pairs", []) as Array).size() != 1485:
		failures.append("Validation memo changed the exact production uniqueness authority.")
	var load_stats := Schema._successful_validation_memo_stats_for_tests()
	if int(load_stats.get("entries", 0)) <= 0 or int(load_stats.get("entries", 0)) > Schema.SUCCESSFUL_VALIDATION_MEMO_MAX_ENTRIES or int(load_stats.get("hits", 0)) < 55:
		failures.append("Production load did not exercise the bounded positive-result memo: %s" % JSON.stringify(load_stats))

	var fixture := _first_sequence_fixture(library)
	var definition: Dictionary = fixture.get("definition", {})
	var target_inventory: Dictionary = fixture.get("target_inventory", {})
	if definition.is_empty() or target_inventory.is_empty():
		failures.append("Could not build a production sequence memo fixture.")
	else:
		Schema._clear_successful_validation_memo_for_tests()
		var first_errors := Schema.validate_definition(definition, Registry, target_inventory)
		var second_errors := Schema.validate_definition(definition, Registry, target_inventory)
		var exact_stats := Schema._successful_validation_memo_stats_for_tests()
		if not first_errors.is_empty() or JSON.stringify(first_errors) != JSON.stringify(second_errors) or int(exact_stats.get("full_runs", -1)) != 1 or int(exact_stats.get("hits", -1)) != 1 or int(exact_stats.get("entries", -1)) != 1:
			failures.append("Exact repeated validation did not reuse one successful full result: %s" % JSON.stringify(exact_stats))

		var hostile_definition := definition.duplicate(true)
		var hostile_sequence: Dictionary = hostile_definition.get("sequence", {})
		hostile_sequence["sequence_signature"] = "0".repeat(64)
		hostile_definition["sequence"] = hostile_sequence
		var hostile_errors_a := Schema.validate_definition(hostile_definition, Registry, target_inventory)
		var hostile_errors_b := Schema.validate_definition(hostile_definition, Registry, target_inventory)
		if hostile_errors_a.is_empty() or JSON.stringify(hostile_errors_a) != JSON.stringify(hostile_errors_b):
			failures.append("Same-id definition mutation did not revalidate and reject deterministically.")

		var hostile_target: Dictionary = {}
		var target_errors_a := Schema.validate_definition(definition, Registry, hostile_target)
		var target_errors_b := Schema.validate_definition(definition, Registry, hostile_target)
		if target_errors_a.is_empty() or JSON.stringify(target_errors_a) != JSON.stringify(target_errors_b):
			failures.append("Target-inventory mutation did not revalidate and reject deterministically.")

		var substitute_registry := RejectingRegistry.new()
		var registry_errors_a := Schema.validate_definition(definition, substitute_registry, target_inventory)
		var registry_errors_b := Schema.validate_definition(definition, substitute_registry, target_inventory)
		if registry_errors_a.is_empty() or JSON.stringify(registry_errors_a) != JSON.stringify(registry_errors_b):
			failures.append("Registry substitution did not revalidate and reject deterministically.")
		var hostile_stats := Schema._successful_validation_memo_stats_for_tests()
		if int(hostile_stats.get("full_runs", -1)) != 7 or int(hostile_stats.get("hits", -1)) != 1 or int(hostile_stats.get("entries", -1)) != 1:
			failures.append("Invalid or mutated validation inputs entered the positive-result memo: %s" % JSON.stringify(hostile_stats))

	Schema._clear_successful_validation_memo_for_tests()
	for memo_index in range(Schema.SUCCESSFUL_VALIDATION_MEMO_MAX_ENTRIES + 1):
		Schema._remember_successful_validation("bounded_fixture_%03d" % memo_index)
	var bounded_stats := Schema._successful_validation_memo_stats_for_tests()
	if int(bounded_stats.get("entries", -1)) != Schema.SUCCESSFUL_VALIDATION_MEMO_MAX_ENTRIES or int(bounded_stats.get("order_entries", -1)) != Schema.SUCCESSFUL_VALIDATION_MEMO_MAX_ENTRIES or int(bounded_stats.get("evictions", -1)) != 1:
		failures.append("Successful validation memo did not enforce deterministic FIFO eviction: %s" % JSON.stringify(bounded_stats))
	Schema._clear_successful_validation_memo_for_tests()

	if failures.is_empty():
		print("SCENARIO_VALIDATION_MEMO PASS production_pairs=1485 load_ms=%.1f load_hits=%d bounded_entries=%d" % [load_elapsed_ms, int(load_stats.get("hits", 0)), Schema.SUCCESSFUL_VALIDATION_MEMO_MAX_ENTRIES])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _first_sequence_fixture(library: Variant) -> Dictionary:
	for pool_value in library.environment_scenarios.values():
		if typeof(pool_value) != TYPE_ARRAY:
			continue
		for scenario_value in pool_value as Array:
			if typeof(scenario_value) != TYPE_DICTIONARY:
				continue
			var definition: Dictionary = Catalog.apply_overlay(scenario_value as Dictionary, library.scenario_sequence_catalog)
			if not Schema.is_sequence(definition):
				continue
			var target_catalog: Dictionary = library.scenario_target_catalog(definition)
			if target_catalog.is_empty() or not (target_catalog.get("errors", []) as Array).is_empty():
				continue
			var target_inventory: Dictionary = (target_catalog.get("guaranteed", {}) as Dictionary).duplicate(true)
			target_inventory["event_choices"] = (target_catalog.get("event_choices", {}) as Dictionary).duplicate(true)
			return {"definition": definition, "target_inventory": target_inventory}
	return {}
