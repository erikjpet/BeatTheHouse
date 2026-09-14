extends SceneTree

const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("Usage: -- res://data/environments/scenario_sequences/<package>.json")
		quit(2)
		return
	var path := str(args[0])
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		printerr("Could not parse %s" % path)
		quit(2)
		return
	var package := (parsed as Dictionary).duplicate(true)
	var scenarios := (package.get("scenarios", []) as Array).duplicate(true)
	for index in range(scenarios.size()):
		var row := (scenarios[index] as Dictionary).duplicate(true)
		var definition := {"id": str(row.get("scenario_id", "")), "sequence": (row.get("sequence", {}) as Dictionary).duplicate(true)}
		definition["sequence"]["sequence_signature"] = ""
		definition["sequence"]["sequence_signature"] = Schema.calculated_signature_hash(definition)
		row["sequence"] = definition["sequence"]
		scenarios[index] = row
	package["scenarios"] = scenarios
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Could not open %s" % path)
		quit(2)
		return
	file.store_string(JSON.stringify(package, "  ", false) + "\n")
	file.close()
	print("ENV06_8_RESIGNED scenarios=%d path=%s" % [scenarios.size(), path])
	quit(0)
