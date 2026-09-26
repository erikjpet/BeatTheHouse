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
	document["baseline_commit"] = "d7a1b1c7-fixed-slot-release-baseline"
	var provenance: Dictionary = document.get("provenance", {}) if typeof(document.get("provenance", {})) == TYPE_DICTIONARY else {}
	provenance["change_commit"] = "d7a1b1c7f90d789372f68875f3ce1bec3fa5e634"
	provenance["reason"] = "rw06_1 replaced solver-derived room placement with the finalized authored fixed-slot authority and the release Count route; the accepted Crew-ignored bytes must reflect those shipped non-Crew environment records."
	provenance["proof"] = "Both fixed Crew-ignored seeds were recaptured through all five production checkpoints after authored-slot validation stabilized; the contract still requires exact normalized bytes and hashes, inactive world-sequence no-ops, and zero Crew trust."
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
