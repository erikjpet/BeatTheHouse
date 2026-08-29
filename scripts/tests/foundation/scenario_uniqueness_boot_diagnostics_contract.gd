extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const SequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")


func _init() -> void:
	var failures: Array[String] = []
	var fatal_messages := [
		"product/schema failure",
		"scenario e vs f: 1.000 (equal_hash_hard_fail).",
		"scenario g vs h: 0.820 (fail).",
	]
	var review_messages := [
		"scenario a vs b: 0.720 (blocking_review).",
		"scenario c vs d: 0.600 (warning). Missing receipt-bound masked visual evidence.",
	]
	var report := {
		"failures": fatal_messages + review_messages,
		"pairs": [
			{"left_id": "a", "right_id": "b", "similarity": 0.720, "status": "blocking_review", "masked_visual_evidence_valid": false},
			{"left_id": "c", "right_id": "d", "similarity": 0.600, "status": "warning", "masked_visual_evidence_valid": false},
			{"left_id": "e", "right_id": "f", "similarity": 1.000, "status": "equal_hash_hard_fail", "masked_visual_evidence_valid": false},
			{"left_id": "g", "right_id": "h", "similarity": 0.820, "status": "fail", "masked_visual_evidence_valid": false},
		],
		"warnings": ["receipt-bound 0.600 similarity warning"],
	}
	var channels := ContentLibraryScript.scenario_uniqueness_validation_channels(report)
	if channels.get("errors", []) != fatal_messages:
		failures.append("Product/P1 failures did not remain boot-fatal.")
	var expected_warnings := review_messages + ["receipt-bound 0.600 similarity warning"]
	if channels.get("warnings", []) != expected_warnings:
		failures.append("P2 review/evidence findings were not preserved as boot warnings.")
	for message in review_messages:
		if (channels.get("errors", []) as Array).has(message):
			failures.append("P2 review finding leaked into boot-fatal errors: %s" % message)
	for score in [0.820, 0.999]:
		var band := SequenceSchemaScript.uniqueness_band(score)
		if str(band.get("severity", "")) != "P1" or not bool(band.get("blocking", false)):
			failures.append("Similarity %.3f no longer remains P1 boot-fatal authority." % score)
	var equal_band := SequenceSchemaScript.uniqueness_band(0.0, true)
	if str(equal_band.get("status", "")) != "equal_hash_hard_fail" or str(equal_band.get("severity", "")) != "P1" or not bool(equal_band.get("blocking", false)):
		failures.append("Equal normalized hashes no longer remain P1 boot-fatal authority.")
	for score in [0.720, 0.819]:
		var band := SequenceSchemaScript.uniqueness_band(score)
		if str(band.get("status", "")) != "blocking_review" or str(band.get("severity", "")) != "P2" or not bool(band.get("blocking", false)):
			failures.append("Similarity %.3f no longer remains a blocking P2 review finding." % score)
	var hostile_report := SequenceSchemaScript.catalog_uniqueness_report([], 1)
	var hostile_channels := ContentLibraryScript.scenario_uniqueness_validation_channels(hostile_report)
	if (hostile_channels.get("errors", []) as Array).is_empty() or not _contains(hostile_channels.get("errors", []), "expected 1 definitions"):
		failures.append("Catalog cardinality/product failure did not remain boot-fatal.")
	var library = ContentLibraryScript.new()
	library.load_all(true)
	if not library.validation_errors.is_empty():
		failures.append("The exact production catalog still emits boot-fatal validation errors: %s" % JSON.stringify(library.validation_errors))
	var audit: Dictionary = library.scenario_sequence_catalog.get("uniqueness_audit", {})
	var exact_review_count := 0
	for finding_value in audit.get("failures", []):
		var finding := str(finding_value)
		if finding.contains("(blocking_review).") or finding.contains("Missing receipt-bound masked visual evidence"):
			exact_review_count += 1
			if not library.validation_warnings.has(finding):
				failures.append("Exact P2 audit finding was not preserved as a boot warning: %s" % finding)
	if exact_review_count == 0:
		failures.append("The exact audit no longer reports its outstanding P2 review/evidence findings.")
	if failures.is_empty():
		print("SCENARIO_UNIQUENESS_BOOT_DIAGNOSTICS PASS fatal=4 synthetic_review=3 exact_review=%d threshold=0.820" % exact_review_count)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _contains(values: Array, needle: String) -> bool:
	for value in values:
		if str(value).contains(needle):
			return true
	return false
