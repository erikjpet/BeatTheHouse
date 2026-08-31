extends SceneTree

const ScenarioSequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const ScenarioOperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const PATH := "res://data/crew/world06_6_heist_sequences.json"


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_ARRAY or (parsed as Array).size() != 9:
		push_error("World 6 heist package source must contain exactly nine packages.")
		quit(1)
		return
	for package_value in parsed as Array:
		if typeof(package_value) != TYPE_DICTIONARY:
			push_error("World 6 heist package row is malformed.")
			quit(1)
			return
		var package := package_value as Dictionary
		var definitions: Array = package.get("definitions", []) if typeof(package.get("definitions", [])) == TYPE_ARRAY else []
		if definitions.size() != 1 or typeof(definitions[0]) != TYPE_DICTIONARY:
			push_error("World 6 heist package must contain exactly one definition.")
			quit(1)
			return
		var definition := definitions[0] as Dictionary
		var sequence: Dictionary = definition.get("sequence", {}) if typeof(definition.get("sequence", {})) == TYPE_DICTIONARY else {}
		sequence["sequence_signature"] = ScenarioSequenceSchemaScript.calculated_signature_hash(definition)
		definition["sequence"] = sequence
		var target_inventory := {
			"scene_objects": [], "interactions": [], "actors": [], "services": [],
			"games": [], "routes": [], "anchors": [], "zones": ["base::zone:center"],
		}
		var validation_errors := ScenarioSequenceSchemaScript.validate_definition(definition, ScenarioOperationRegistryScript, target_inventory)
		if not validation_errors.is_empty():
			push_error("World 6 heist package %s failed shared sequence validation: %s" % [str(package.get("package_id", "")), JSON.stringify(validation_errors)])
			quit(1)
			return
		definitions[0] = definition
		package["definitions"] = definitions
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("World 6 heist package source could not be opened for signing.")
		quit(1)
		return
	file.store_string(JSON.stringify(parsed, "  ", false) + "\n")
	file.close()
	print("WORLD06_6_SIGNED_PACKAGES=9")
	quit(0)
