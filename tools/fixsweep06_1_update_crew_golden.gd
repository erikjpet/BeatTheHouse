extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const CrewIgnoredGoldenProbeScript := preload("res://scripts/tests/foundation/crew_ignored_golden_probe.gd")
const TARGET := "res://scripts/tests/fixtures/crew06_5_ignored_run_baseline.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library := ContentLibraryScript.new()
	library.load()
	var existing_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(TARGET))
	if typeof(existing_value) != TYPE_DICTIONARY:
		push_error("Crew ignored golden fixture is missing or malformed.")
		quit(1)
		return
	var document: Dictionary = existing_value
	document["capture"] = CrewIgnoredGoldenProbeScript.capture(library)
	var provenance: Dictionary = document.get("provenance", {}) if typeof(document.get("provenance", {})) == TYPE_DICTIONARY else {}
	provenance["reason"] = "postfix06_2 corrected production environment scenario placement and canonical RunState persistence while preserving Crew-ignored behavior and immutable producer context."
	provenance["proof"] = "Both fixed Crew-ignored seeds were recaptured through all five production checkpoints after the postfix06_2 focused persistence and scenario-placement regressions passed; the contract still requires exact normalized bytes and hashes, inactive world-sequence no-ops, and zero Crew trust."
	document["provenance"] = provenance
	var file := FileAccess.open(TARGET, FileAccess.WRITE)
	if file == null:
		push_error("Could not open Crew ignored golden fixture for update.")
		quit(1)
		return
	file.store_string(JSON.stringify(document, "    ") + "\n")
	file.close()
	print("FIXSWEEP06_1_CREW_GOLDEN_UPDATED")
	quit(0)
