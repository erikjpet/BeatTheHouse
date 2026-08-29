extends SceneTree

const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")
const PACKAGE_PATH := "res://data/environments/scenario_sequences/env06_7_roadside_shelter.json"


func _init() -> void:
	var source := FileAccess.get_file_as_string(PACKAGE_PATH)
	var parsed: Variant = JSON.parse_string(source)
	if typeof(parsed) != TYPE_DICTIONARY:
		printerr("Package B signer could not parse the package.")
		quit(1)
		return
	var package := (parsed as Dictionary).duplicate(true)
	var scenarios: Array = package.get("scenarios", [])
	for index in range(scenarios.size()):
		var row := (scenarios[index] as Dictionary).duplicate(true)
		var definition := {"id": str(row.get("scenario_id", "")), "sequence": (row.get("sequence", {}) as Dictionary).duplicate(true)}
		definition["sequence"]["sequence_signature"] = ""
		definition["sequence"]["sequence_signature"] = Schema.calculated_signature_hash(definition)
		row["sequence"] = definition["sequence"]
		scenarios[index] = row
	package["scenarios"] = scenarios
	var file := FileAccess.open(PACKAGE_PATH, FileAccess.WRITE)
	if file == null:
		printerr("Package B signer could not open the package for writing.")
		quit(1)
		return
	file.store_string(JSON.stringify(package, "  ", false) + "\n")
	file.close()
	print("PACKAGE_B_SIGNED count=%d" % scenarios.size())
	quit(0)
