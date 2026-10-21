extends SceneTree

# Actor copy is part of the authored sequence signature. Check the two edited
# roadside cards without running the full catalog audit or relaxing validation.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var library := ContentLibrary.new()
	library.load(false)
	var catalog: Script = load("res://scripts/core/scenario_sequence_catalog.gd")
	var schema: Script = load("res://scripts/core/scenario_sequence_schema.gd")
	var registry: Script = load("res://scripts/core/scenario_operation_registry.gd")
	var failures: Array = []
	var rows: Array = []
	for scenario_id in ["motel_wedding_overflow", "gas_station_tour_bus_stop"]:
		var definition: Dictionary = catalog.legacy_definition(scenario_id)
		var target: Dictionary = library.scenario_target_catalog(definition)
		var inventory: Dictionary = target.get("guaranteed", {}).duplicate(true)
		inventory["event_choices"] = target.get("event_choices", {})
		var errors: Array = schema.validate_definition(definition, registry, inventory)
		var calculated: String = schema.calculated_signature_hash(definition)
		rows.append({"id":scenario_id,"authored":definition.get("sequence", {}).get("sequence_signature", ""),"calculated":calculated,"errors":errors})
		failures.append_array(errors)
		var changed := definition.duplicate(true)
		# A changed signed actor payload must still be rejected; the check below
		# mutates the exact operation payload rather than exempting presentation.
		var phase: Dictionary = changed.sequence.phase_graph.phases[0]
		var actor_ops: Array = phase.get("actor_ops", [])
		if actor_ops.is_empty():
			failures.append("Selected sequence lost its signed actor payload.")
		else:
			var operation: Dictionary = actor_ops[0]
			if operation.has("actor"):
				operation.actor["description"] = "Unacknowledged actor text edit."
			else:
				operation["description"] = "Unacknowledged actor text edit."
			if schema.calculated_signature_hash(changed) == calculated:
				failures.append("Actor copy edit unexpectedly escaped the authored signature.")
			var changed_errors: Array = schema.validate_definition(changed, registry, inventory)
			if not changed_errors.any(func(error: Variant) -> bool: return str(error).contains("sequence_signature mismatch")):
				failures.append("Changed actor copy escaped strict schema rejection.")
	var result := {"rows":rows,"failures":failures}
	var output := OS.get_environment("BTH_SCRATCH_REPRO_REPORT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(result));file.close()
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
