extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const Catalog := preload("res://scripts/core/scenario_sequence_catalog.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const Registry := preload("res://scripts/core/scenario_operation_registry.gd")
const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")

const PRODUCTION_AUTHORITY_SHA256 := "d125295258aa94a2315281e7cdf7877b3b107f7e4328df85f81aca6688273f4a"
const PRODUCTION_AUTHORITY_BYTES := 1400483


func _init() -> void:
	var failures: Array[String] = []
	var started_usec := Time.get_ticks_usec()
	var library = ContentLibraryScript.new()
	library.load(true)
	var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	var authority: Dictionary = library.scenario_sequence_catalog.get("uniqueness_audit", {})
	var authority_json := JSON.stringify(authority)
	if authority_json.sha256_text() != PRODUCTION_AUTHORITY_SHA256 or authority_json.to_utf8_buffer().size() != PRODUCTION_AUTHORITY_BYTES:
		failures.append("Optimized production authority JSON differs from the exact accepted ENV-06.7 baseline: sha256=%s bytes=%d expected_sha256=%s expected_bytes=%d." % [authority_json.sha256_text(), authority_json.to_utf8_buffer().size(), PRODUCTION_AUTHORITY_SHA256, PRODUCTION_AUTHORITY_BYTES])
	if (authority.get("pairs", []) as Array).size() != 1485 or not (authority.get("failures", []) as Array).is_empty() or (authority.get("warnings", []) as Array).size() != 27:
		failures.append("Optimized production authority shape/findings differ from the exact accepted ENV-06.7 baseline.")
	var audit_inputs := _production_audit_inputs(library)
	var definitions: Array = audit_inputs.get("definitions", [])
	var target_inventories: Dictionary = audit_inputs.get("target_inventories", {})
	var masked_visual_explanations: Dictionary = audit_inputs.get("masked_visual_explanations", {})
	var full_started_usec := Time.get_ticks_usec()
	var full_report := Schema.catalog_uniqueness_report(definitions, definitions.size(), Registry, masked_visual_explanations, target_inventories)
	var full_elapsed_ms := float(Time.get_ticks_usec() - full_started_usec) / 1000.0
	if JSON.stringify(full_report) != authority_json:
		failures.append("Same-call receipt audit differs from the unchanged full-validation audit.")
	if definitions.size() != 55:
		failures.append("Production receipt proof must bind all 55 sequence definitions.")
	elif not definitions.is_empty():
		var registry_context_fingerprint := ScenarioEngineScript._sequence_validation_registry_context_fingerprint()
		var receipts: Array = []
		for definition_value in definitions:
			var production_definition: Dictionary = definition_value
			var production_id := str(production_definition.get("id", ""))
			receipts.append(ScenarioEngineScript._sequence_validation_receipt(production_definition, target_inventories.get(production_id, {}), registry_context_fingerprint))
		if not ScenarioEngineScript._sequence_validation_receipts_match(definitions, 55, target_inventories, receipts, registry_context_fingerprint):
			failures.append("Fresh exact 55-definition receipt set was not accepted.")
		var first_definition: Dictionary = definitions[0]
		var first_id := str(first_definition.get("id", ""))
		var hostile_definitions := definitions.duplicate(true)
		var hostile_definition: Dictionary = hostile_definitions[0]
		hostile_definition["display_name"] = "%s hostile stale receipt" % str(hostile_definition.get("display_name", ""))
		hostile_definitions[0] = hostile_definition
		if ScenarioEngineScript._sequence_validation_receipts_match(hostile_definitions, 55, target_inventories, receipts, registry_context_fingerprint):
			failures.append("A stale same-id definition receipt bypassed full validation fallback.")
		var hostile_target_inventories := target_inventories.duplicate(true)
		var hostile_target: Dictionary = hostile_target_inventories.get(first_id, {}).duplicate(true)
		hostile_target["hostile_unvalidated_target"] = true
		hostile_target_inventories[first_id] = hostile_target
		if ScenarioEngineScript._sequence_validation_receipts_match(definitions, 55, hostile_target_inventories, receipts, registry_context_fingerprint):
			failures.append("A stale target-inventory receipt bypassed full validation fallback.")
		var missing_receipts := receipts.duplicate(true)
		missing_receipts.pop_back()
		if ScenarioEngineScript._sequence_validation_receipts_match(definitions, 55, target_inventories, missing_receipts, registry_context_fingerprint):
			failures.append("A missing validation receipt bypassed full validation fallback.")
		var forged_receipts := receipts.duplicate(true)
		var forged_receipt: Dictionary = forged_receipts[0]
		forged_receipt["receipt_fingerprint"] = "0".repeat(64)
		forged_receipts[0] = forged_receipt
		if ScenarioEngineScript._sequence_validation_receipts_match(definitions, 55, target_inventories, forged_receipts, registry_context_fingerprint):
			failures.append("A forged validation receipt bypassed full validation fallback.")
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
		print("SCENARIO_UNIQUENESS_PAIR_PRECOMPUTE PASS production_pairs=1485 production_failures=0 production_warnings=27 representative_pairs=6 receipt_load_ms=%.1f full_audit_ms=%.1f" % [elapsed_ms, full_elapsed_ms])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _production_audit_inputs(library: Variant) -> Dictionary:
	var definitions: Array = []
	var target_inventories: Dictionary = {}
	var masked_visual_explanations: Dictionary = {}
	for archetype_key_value in library.environment_scenarios.keys():
		var pool_value: Variant = library.environment_scenarios.get(archetype_key_value)
		if typeof(pool_value) != TYPE_ARRAY:
			continue
		for scenario_value in pool_value as Array:
			if typeof(scenario_value) != TYPE_DICTIONARY:
				continue
			var definition: Dictionary = Catalog.apply_overlay(scenario_value as Dictionary, library.scenario_sequence_catalog)
			if not definition.has("sequence"):
				continue
			definitions.append(definition.duplicate(true))
			var scenario_id := str(definition.get("id", ""))
			var target_catalog: Dictionary = library.scenario_target_catalog(definition)
			if not target_catalog.is_empty() and (target_catalog.get("errors", []) as Array).is_empty():
				var target_inventory: Dictionary = (target_catalog.get("guaranteed", {}) as Dictionary).duplicate(true)
				target_inventory["event_choices"] = target_catalog.get("event_choices", {}) as Dictionary
				target_inventories[scenario_id] = target_inventory
			var authored: Dictionary = definition.get("sequence_authoring", {})
			var authored_explanations: Dictionary = authored.get("masked_visual_explanations", {})
			for pair_key_value in authored_explanations.keys():
				masked_visual_explanations[str(pair_key_value)] = (authored_explanations.get(pair_key_value, {}) as Dictionary).duplicate(true)
	return {
		"definitions": definitions,
		"target_inventories": target_inventories,
		"masked_visual_explanations": masked_visual_explanations,
	}


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
