extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")

const PRODUCTION_AUTHORITY_SHA256 := "d97b3dd830bc58b9b4d72b06a55bb9e1d67fdb1fc3299d473d7a4e11f4a4ce2c"
const PRODUCTION_AUTHORITY_BYTES := 1323503


func _init() -> void:
	var failures: Array[String] = []
	var started_usec := Time.get_ticks_usec()
	var library = ContentLibraryScript.new()
	library.load(true)
	var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	var authority: Dictionary = library.scenario_sequence_catalog.get("uniqueness_audit", {})
	var authority_json := JSON.stringify(authority)
	if authority_json.sha256_text() != PRODUCTION_AUTHORITY_SHA256 or authority_json.to_utf8_buffer().size() != PRODUCTION_AUTHORITY_BYTES:
		failures.append("Optimized production authority JSON differs from the exact a091 legacy baseline.")
	if (authority.get("pairs", []) as Array).size() != 1485 or (authority.get("failures", []) as Array).size() != 80 or not (authority.get("warnings", []) as Array).is_empty():
		failures.append("Optimized production authority shape/findings differ from the exact a091 legacy baseline.")
	var threshold_band: Dictionary = Schema.uniqueness_band(0.820)
	var equal_band: Dictionary = Schema.uniqueness_band(0.0, true)
	if str(threshold_band.get("status", "")) != "fail" or str(threshold_band.get("severity", "")) != "P1" or not bool(threshold_band.get("blocking", false)):
		failures.append("The 0.820 P1 similarity threshold changed.")
	if str(equal_band.get("status", "")) != "equal_hash_hard_fail" or str(equal_band.get("severity", "")) != "P1" or not bool(equal_band.get("blocking", false)):
		failures.append("The equal-hash P1 threshold changed.")
	var signatures := [
		{},
		{"phases": [{"ops": ["scene:add", "actor:spawn"], "terminal": false}], "objectives": ["command", "fact"], "reentry": {"partial": "resume"}},
		{"phases": [{"ops": ["scene:add", "actor:spawn"], "terminal": true}], "objectives": ["command", "fact"], "reentry": {"partial": "resume"}},
		{"phases": [{"ops": ["service:add", "route:unlock"], "terminal": false}], "objectives": ["world_boundary"], "expiry": {"boundary": "night_end"}},
	]
	var tokens: Array = []
	var canonical_texts: Array = []
	for signature_value in signatures:
		var signature: Dictionary = signature_value
		tokens.append(Schema._signature_tokens(signature))
		canonical_texts.append(JSON.stringify(Schema._canonical_variant(signature)))
	var old_report: Array = []
	var new_report: Array = []
	for left_index in range(signatures.size()):
		for right_index in range(left_index + 1, signatures.size()):
			var left: Dictionary = signatures[left_index]
			var right: Dictionary = signatures[right_index]
			var old_similarity := _legacy_similarity(left, right)
			var old_equal := JSON.stringify(Schema._canonical_variant(left)) == JSON.stringify(Schema._canonical_variant(right))
			var new_similarity := Schema._signature_similarity_from_tokens(tokens[left_index], tokens[right_index])
			var new_equal := str(canonical_texts[left_index]) == str(canonical_texts[right_index])
			old_report.append(_pair_row(left_index, right_index, old_similarity, old_equal))
			new_report.append(_pair_row(left_index, right_index, new_similarity, new_equal))
	if JSON.stringify(old_report) != JSON.stringify(new_report):
		failures.append("Precomputed signature pair report differs from the legacy per-pair report: old=%s new=%s" % [JSON.stringify(old_report), JSON.stringify(new_report)])
	if failures.is_empty():
		print("SCENARIO_UNIQUENESS_PAIR_PRECOMPUTE PASS production_pairs=1485 production_failures=80 representative_pairs=6 elapsed_ms=%.1f" % elapsed_ms)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _legacy_similarity(left: Dictionary, right: Dictionary) -> float:
	var left_tokens: Dictionary = Schema._signature_tokens(left)
	var right_tokens: Dictionary = Schema._signature_tokens(right)
	if left_tokens.is_empty() and right_tokens.is_empty():
		return 1.0
	var union: Dictionary = left_tokens.duplicate(true)
	var intersection := 0
	for token_value in right_tokens.keys():
		var token := str(token_value)
		if left_tokens.has(token):
			intersection += 1
		union[token] = true
	return float(intersection) / float(maxi(1, union.size()))


func _pair_row(left_index: int, right_index: int, similarity: float, equal_hash: bool) -> Dictionary:
	var band: Dictionary = Schema.uniqueness_band(similarity, equal_hash)
	return {
		"left": left_index,
		"right": right_index,
		"similarity": similarity,
		"equal_normalized_hash": equal_hash,
		"status": str(band.get("status", "")),
		"severity": str(band.get("severity", "")),
		"blocking": bool(band.get("blocking", false)),
	}
