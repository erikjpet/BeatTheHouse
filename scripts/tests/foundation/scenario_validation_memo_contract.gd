extends SceneTree

const Catalog := preload("res://scripts/core/scenario_sequence_catalog.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const Registry := preload("res://scripts/core/scenario_operation_registry.gd")
const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")

# Integrated environment/scenario work after ENV-06.7 legitimately expanded
# the authored signatures and eliminated the remaining similarity warnings.
const PRODUCTION_AUTHORITY_SHA256 := "72da67b4adb39cc4f19f09f891e306bc90c5c15e8c94b87037197805dcbe4698"


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

		# Random room population can add unrelated objects and event choices, but
		# those cannot change this sequence's declared authority. They must reuse the
		# same static validation proof while a missing declared target still misses
		# the memo and fails closed.
		var unrelated_target := target_inventory.duplicate(true)
		var unrelated_events: Dictionary = unrelated_target.get("event_choices", {}).duplicate(true) if typeof(unrelated_target.get("event_choices", {})) == TYPE_DICTIONARY else {}
		unrelated_events["memo_unrelated_event"] = ["memo_unrelated_choice"]
		unrelated_target["event_choices"] = unrelated_events
		var unrelated_errors := Schema.validate_definition(definition, Registry, unrelated_target)
		var unrelated_stats := Schema._successful_validation_memo_stats_for_tests()
		if not unrelated_errors.is_empty() or int(unrelated_stats.get("full_runs", -1)) != 1 or int(unrelated_stats.get("hits", -1)) != 2:
			failures.append("Unrelated room population invalidated the scenario authority memo: %s" % JSON.stringify(unrelated_stats))

		var missing_declared_target := target_inventory.duplicate(true)
		var removed_declared_identity := false
		var authored: Dictionary = definition.get("sequence", {}) if typeof(definition.get("sequence", {})) == TYPE_DICTIONARY else {}
		var declared: Dictionary = authored.get("declared_targets", {}) if typeof(authored.get("declared_targets", {})) == TYPE_DICTIONARY else {}
		for collection_key in ["scene_objects", "interactions", "actors", "services", "games", "routes", "anchors", "zones"]:
			var declared_values: Array = declared.get(collection_key, []) if typeof(declared.get(collection_key, [])) == TYPE_ARRAY else []
			var available_values: Array = missing_declared_target.get(collection_key, []).duplicate(true) if typeof(missing_declared_target.get(collection_key, [])) == TYPE_ARRAY else []
			if declared_values.is_empty() or not available_values.has(str(declared_values[0])):
				continue
			available_values.erase(str(declared_values[0]))
			missing_declared_target[collection_key] = available_values
			removed_declared_identity = true
			break
		var missing_errors_a := Schema.validate_definition(definition, Registry, missing_declared_target)
		var missing_errors_b := Schema.validate_definition(definition, Registry, missing_declared_target)
		if not removed_declared_identity or missing_errors_a.is_empty() or JSON.stringify(missing_errors_a) != JSON.stringify(missing_errors_b):
			failures.append("Declared-target authority mutation did not miss the memo and reject deterministically.")

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
		if int(hostile_stats.get("full_runs", -1)) != 9 or int(hostile_stats.get("hits", -1)) != 2 or int(hostile_stats.get("entries", -1)) != 1:
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
