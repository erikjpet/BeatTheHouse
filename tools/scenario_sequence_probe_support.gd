class_name ScenarioSequenceProbeSupport
extends RefCounted

# Shared fail-closed authority for the delivery-day capture, parity, and timing
# probes. Timings and host metadata never enter the canonical semantic hash.

const PACKAGE_PATH := "res://data/environments/scenario_sequences/env06_7_shops_streets.json"
const SCENARIO_ID := "corner_store_delivery_day"
const ARCHETYPE_ID := "corner_store"
const NODE_ID := "corner_store_delivery_day_node"
const EVENT_ID := "scenario_delivery_day_stock"
const RESOLUTION_ID := "clear_the_aisle"
const PROOF_SEED := "corner_store_delivery_day_env06_6"

const EXPECTED_PHASES := ["arrival", "sorting", "verification", "awaiting_stock", "resolution"]
const EXPECTED_OUTCOMES := ["repaired", "broken", "refused", "interrupted"]
const EXPECTED_CAPTURE_IDS := [
	"arrival_delivery_blocked",
	"sorting_aisle_rerouted",
	"verification_station_ready",
	"awaiting_stock_choice",
	"resolution_repaired",
	"resolution_broken",
	"resolution_refused",
	"resolution_interrupted",
	"partial_revisit_awaiting_stock",
	"terminal_revisit_repaired",
	"terminal_revisit_broken",
	"terminal_revisit_refused",
	"terminal_revisit_interrupted",
	"expired_revisit_night_end",
	"reduced_motion_arrival",
	"small_screen_104x76",
	"obstruction_overlay_zero_overlap",
	"hit_target_overlay_44_minimum",
	"base_event_pre_request_gated",
	"base_event_request_delivered",
	"base_event_terminal_gated",
]
const EXPECTED_OBSTRUCTION_TARGET_IDS := [
	"scenario:scenario:delivery_event_gate",
	"scenario:scenario:delivery_exit",
]
const EXPECTED_TRACE_ROWS := [
	{"label": "arrival_delivery_blocked", "phase_id": "arrival", "status": "active", "outcomes": []},
	{"label": "base_event_pre_request_gated", "phase_id": "arrival", "status": "active", "outcomes": []},
	{"label": "obstruction_overlay_zero_overlap", "phase_id": "arrival", "status": "active", "outcomes": []},
	{"label": "hit_target_overlay_44_minimum", "phase_id": "arrival", "status": "active", "outcomes": []},
	{"label": "sorting_aisle_rerouted", "phase_id": "sorting", "status": "active", "outcomes": []},
	{"label": "verification_station_ready", "phase_id": "verification", "status": "active", "outcomes": []},
	{"label": "awaiting_stock_choice", "phase_id": "awaiting_stock", "status": "active", "outcomes": []},
	{"label": "base_event_request_delivered", "phase_id": "awaiting_stock", "status": "active", "outcomes": []},
	{"label": "partial_revisit_awaiting_stock", "phase_id": "awaiting_stock", "status": "active", "outcomes": []},
	{"label": "resolution_repaired", "phase_id": "resolution", "status": "aftermath", "outcomes": ["repaired"]},
	{"label": "terminal_revisit_repaired", "phase_id": "resolution", "status": "aftermath", "outcomes": ["repaired"]},
	{"label": "resolution_broken", "phase_id": "resolution", "status": "aftermath", "outcomes": ["broken"]},
	{"label": "terminal_revisit_broken", "phase_id": "resolution", "status": "aftermath", "outcomes": ["broken"]},
	{"label": "resolution_refused", "phase_id": "resolution", "status": "aftermath", "outcomes": ["refused"]},
	{"label": "terminal_revisit_refused", "phase_id": "resolution", "status": "aftermath", "outcomes": ["refused"]},
	{"label": "base_event_terminal_gated", "phase_id": "resolution", "status": "aftermath", "outcomes": ["refused"]},
	{"label": "resolution_interrupted", "phase_id": "resolution", "status": "aftermath", "outcomes": ["interrupted"]},
	{"label": "terminal_revisit_interrupted", "phase_id": "resolution", "status": "aftermath", "outcomes": ["interrupted"]},
	{"label": "expired_revisit_night_end", "phase_id": "arrival", "status": "cleaned", "outcomes": []},
	{"label": "reduced_motion_arrival", "phase_id": "arrival", "status": "active", "outcomes": []},
	{"label": "small_screen_104x76", "phase_id": "arrival", "status": "active", "outcomes": []},
]

const PERFORMANCE_BUDGETS := {
	"native_transition_p95_ms": 16.0,
	"native_transition_max_ms": 45.0,
	"native_prepared_frame_p95_ms": 16.6,
	"web_transition_p95_ms": 120.0,
	"web_transition_max_ms": 1200.0,
	"web_prepared_frame_p95_ms": 120.0,
}
const REQUIRED_PERFORMANCE_ROWS := [
	"content_schema_catalog_preparation",
	"command",
	"command_request_drain_event_delivery",
	"fact_publish_flush_terminal_cleanup",
	"projection_layout",
	"save",
	"load_rebuild",
	"reentry",
	"expiry",
	"terminal_cleanup",
	"steady_prepared_frame",
]


static func production_contract() -> Dictionary:
	var failures: Array = []
	failures.append_array(_trace_contract_failures())
	var raw_text := FileAccess.get_file_as_string(PACKAGE_PATH)
	if raw_text.is_empty():
		return {"ok": false, "failures": ["Production sequence package could not be read."]}
	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "failures": ["Production sequence package is not an object envelope."]}
	var package: Dictionary = parsed
	if int(package.get("schema_version", 0)) != 1:
		failures.append("Production sequence package schema_version is not 1.")
	if str(package.get("package_id", "")) != "env06_7_shops_streets":
		failures.append("Production sequence package id changed.")
	if str(package.get("handler_pack", "")) != "shops_streets" or str(package.get("renderer_id", "")) != "shops_streets":
		failures.append("Production sequence extension identity changed.")
	var matches: Array = []
	for scenario_value in _array(package.get("scenarios", [])):
		if typeof(scenario_value) != TYPE_DICTIONARY:
			continue
		var scenario: Dictionary = scenario_value
		if str(scenario.get("scenario_id", "")) == SCENARIO_ID:
			matches.append(scenario)
	if matches.size() != 1:
		failures.append("Production sequence package must contain the proof scenario exactly once.")
		return {"ok": false, "failures": failures, "package": package}
	var row: Dictionary = matches[0]
	var authoring := _dict(row.get("authoring", {}))
	var capture_ids := _string_array(authoring.get("capture_ids", []))
	var seed_evidence := _dict(authoring.get("seed_evidence", {}))
	if capture_ids != EXPECTED_CAPTURE_IDS:
		failures.append("Production capture ids do not exactly match the executable 21-id contract.")
	if str(seed_evidence.get("proof_seed", "")) != PROOF_SEED:
		failures.append("Production proof seed changed.")
	if _string_array(seed_evidence.get("expected_outcomes", [])) != EXPECTED_OUTCOMES:
		failures.append("Production outcome evidence changed.")
	var phase_graph := _dict(_dict(row.get("sequence", {})).get("phase_graph", {}))
	var phase_ids: Array = []
	for phase_value in _array(phase_graph.get("phases", [])):
		if typeof(phase_value) == TYPE_DICTIONARY:
			phase_ids.append(str((phase_value as Dictionary).get("id", "")))
	if phase_ids != EXPECTED_PHASES:
		failures.append("Production phase graph identity/order changed.")
	return {
		"ok": failures.is_empty(),
		"failures": failures,
		"package": package,
		"scenario_row": row,
		"capture_ids": capture_ids,
		"proof_seed": str(seed_evidence.get("proof_seed", "")),
		"phase_ids": phase_ids,
	}


static func obstruction_target_contract(records_value: Variant) -> Dictionary:
	var failures: Array = []
	var by_id: Dictionary = {}
	for record_value in _array(records_value):
		var record := _dict(record_value)
		var object_id := str(record.get("object_id", ""))
		if not EXPECTED_OBSTRUCTION_TARGET_IDS.has(object_id):
			continue
		if by_id.has(object_id):
			failures.append("Production obstruction target %s appears more than once." % object_id)
			continue
		var expected_stable_id := "delivery_event_gate" if object_id == EXPECTED_OBSTRUCTION_TARGET_IDS[0] else "delivery_exit"
		var expected_safe_exit := object_id == EXPECTED_OBSTRUCTION_TARGET_IDS[1]
		var expected_role := "workstation" if not expected_safe_exit else "exit"
		if str(record.get("object_type", "")) != "scenario" \
			or str(record.get("owner_namespace", "")) != "scenario" \
			or str(record.get("stable_object_id", "")) != expected_stable_id \
			or str(record.get("role", "")) != expected_role:
			failures.append("Production obstruction target %s lost its scenario identity." % object_id)
		if not bool(record.get("enabled", false)) or not bool(record.get("interactive", false)):
			failures.append("Production obstruction target %s is not enabled and interactive." % object_id)
		if bool(record.get("safe_exit", false)) != expected_safe_exit:
			failures.append("Production obstruction target %s has incorrect safe-exit authority." % object_id)
		var expected_command_ids := ["inspect_manifest"] if not expected_safe_exit else ["ignore_delivery", "refuse_sort"]
		var enabled_command_ids: Array = []
		for action_value in _array(record.get("inline_actions", [])):
			var action := _dict(action_value)
			if not bool(action.get("enabled", false)):
				continue
			var command_id := str(action.get("scenario_command_id", ""))
			var emit_object_id := str(action.get("emit_object_id", ""))
			var expected_token_suffix := ":scenario:%s:%s" % [expected_stable_id, command_id]
			enabled_command_ids.append(command_id)
			if command_id.is_empty() \
				or not emit_object_id.begins_with("scenario_action:") \
				or not emit_object_id.ends_with(expected_token_suffix):
				failures.append("Production obstruction target %s contains an enabled action without exact token authority." % object_id)
		if enabled_command_ids != expected_command_ids:
			failures.append("Production obstruction target %s lost its exact enabled tokenized scenario actions." % object_id)
		by_id[object_id] = record.duplicate(true)
	var targets: Array = []
	for expected_id_value in EXPECTED_OBSTRUCTION_TARGET_IDS:
		var expected_id := str(expected_id_value)
		if not by_id.has(expected_id):
			failures.append("Production obstruction target is missing: %s." % expected_id)
			continue
		targets.append(_dict(by_id.get(expected_id, {})).duplicate(true))
	var target_ids: Array = []
	for target_value in targets:
		target_ids.append(str(_dict(target_value).get("object_id", "")))
	if target_ids.size() == 2 and target_ids[0] == target_ids[1]:
		failures.append("Production obstruction target identities collapsed.")
	return {
		"ok": failures.is_empty(),
		"failures": failures,
		"targets": targets,
		"target_object_ids": target_ids,
		"non_exit_object_id": EXPECTED_OBSTRUCTION_TARGET_IDS[0] if by_id.has(EXPECTED_OBSTRUCTION_TARGET_IDS[0]) else "",
		"safe_exit_object_id": EXPECTED_OBSTRUCTION_TARGET_IDS[1] if by_id.has(EXPECTED_OBSTRUCTION_TARGET_IDS[1]) else "",
	}


static func canonical_semantic(report: Dictionary) -> Dictionary:
	var semantic := _dict(report.get("semantic", {})).duplicate(true)
	return _canonical_dictionary(semantic)


static func canonical_semantic_text(report: Dictionary) -> String:
	return JSON.stringify(canonical_semantic(report), "", true, true)


static func canonical_semantic_sha256(report: Dictionary) -> String:
	return canonical_semantic_text(report).sha256_text()


static func timing_summary(samples_value: Variant) -> Dictionary:
	var samples: Array[float] = []
	for sample_value in _array(samples_value):
		samples.append(maxf(0.0, float(sample_value)))
	samples.sort()
	if samples.is_empty():
		return {"count": 0, "min_ms": 0.0, "p50_ms": 0.0, "p95_ms": 0.0, "max_ms": 0.0}
	return {
		"count": samples.size(),
		"min_ms": samples[0],
		"p50_ms": _percentile(samples, 0.50),
		"p95_ms": _percentile(samples, 0.95),
		"max_ms": samples[samples.size() - 1],
	}


static func validate_probe_report(report: Dictionary, expected_platform: String) -> Array:
	var failures: Array = []
	if str(report.get("schema", "")) != "env06_6_scenario_sequence_probe_v1":
		failures.append("Probe report schema changed.")
	if not bool(report.get("ok", false)):
		failures.append("Probe report did not pass.")
	if str(report.get("platform", "")) != expected_platform:
		failures.append("Probe platform mismatch: expected %s." % expected_platform)
	if str(report.get("scenario_id", "")) != SCENARIO_ID or str(report.get("seed", "")) != PROOF_SEED:
		failures.append("Probe did not execute the production scenario/seed.")
	if not _array(report.get("failures", [])).is_empty():
		failures.append("Probe contains runtime failures.")
	var semantic := _dict(report.get("semantic", {}))
	if _string_array(semantic.get("capture_ids", [])) != EXPECTED_CAPTURE_IDS:
		failures.append("Probe semantic capture ids are not the exact authored 21-id contract.")
	failures.append_array(_validate_runtime_trace(semantic.get("checkpoints", []), "label", true))
	if _string_array(semantic.get("outcomes", [])) != EXPECTED_OUTCOMES:
		failures.append("Probe did not execute the exact four material outcomes.")
	if str(report.get("semantic_sha256", "")) != canonical_semantic_sha256(report):
		failures.append("Probe semantic SHA-256 does not match its canonical payload.")
	var performance := _dict(report.get("performance", {}))
	var named_rows := _dict(performance.get("named_rows", {}))
	for row_id in REQUIRED_PERFORMANCE_ROWS:
		var row := _dict(named_rows.get(row_id, {}))
		if int(row.get("count", 0)) <= 0 or float(row.get("max_ms", 0.0)) <= 0.0:
			failures.append("Probe is missing nonzero required performance row %s." % row_id)
	if not _array(performance.get("missing_rows", [])).is_empty():
		failures.append("Probe reports missing required performance rows.")
	var transition := _dict(performance.get("transition", {}))
	var prepared := _dict(performance.get("prepared_frame", {}))
	if int(transition.get("count", 0)) <= 0 or int(prepared.get("count", 0)) <= 0:
		failures.append("Probe did not emit transition and prepared-frame timings.")
	if int(performance.get("failed_transitions", -1)) != 0 or int(performance.get("missing_transitions", -1)) != 0:
		failures.append("Probe contains failed or missing transitions.")
	if not bool(_dict(performance.get("steady_frame", {})).get("unchanged", false)):
		failures.append("Steady prepared frames reconstructed authoritative state or render projections.")
	failures.append_array(validate_performance_budget(report, expected_platform))
	return failures


static func validate_performance_budget(report: Dictionary, platform: String) -> Array:
	var failures: Array = []
	var performance := _dict(report.get("performance", {}))
	var transition := _dict(performance.get("transition", {}))
	var prepared := _dict(performance.get("prepared_frame", {}))
	if platform == "Web":
		if float(transition.get("p95_ms", INF)) > float(PERFORMANCE_BUDGETS.web_transition_p95_ms): failures.append("Web transition p95 exceeded 120 ms.")
		if float(transition.get("max_ms", INF)) > float(PERFORMANCE_BUDGETS.web_transition_max_ms): failures.append("Web transition max exceeded 1200 ms.")
		if float(prepared.get("p95_ms", INF)) > float(PERFORMANCE_BUDGETS.web_prepared_frame_p95_ms): failures.append("Web prepared-frame p95 exceeded 120 ms.")
	else:
		if float(transition.get("p95_ms", INF)) > float(PERFORMANCE_BUDGETS.native_transition_p95_ms): failures.append("Native transition p95 exceeded 16 ms.")
		if float(transition.get("max_ms", INF)) > float(PERFORMANCE_BUDGETS.native_transition_max_ms): failures.append("Native transition max exceeded 45 ms.")
		if float(prepared.get("p95_ms", INF)) > float(PERFORMANCE_BUDGETS.native_prepared_frame_p95_ms): failures.append("Native prepared-frame p95 exceeded 16.6 ms.")
	return failures


static func validate_capture_manifest(manifest: Dictionary) -> Array:
	var failures: Array = []
	if str(manifest.get("schema", "")) != "env06_6_scenario_sequence_capture_manifest_v1":
		failures.append("Capture manifest schema changed.")
	if not bool(manifest.get("passed", false)) or not _array(manifest.get("failures", [])).is_empty():
		failures.append("Capture manifest did not pass.")
	if str(manifest.get("scenario_id", "")) != SCENARIO_ID or str(manifest.get("seed", "")) != PROOF_SEED:
		failures.append("Capture manifest did not execute the production scenario/seed.")
	var ids := _string_array(manifest.get("capture_ids", []))
	if ids != EXPECTED_CAPTURE_IDS:
		failures.append("Capture manifest ids are not the exact authored 21-id sequence.")
	var captures := _array(manifest.get("captures", []))
	if captures.size() != EXPECTED_CAPTURE_IDS.size():
		failures.append("Capture manifest must contain exactly 21 capture records.")
	failures.append_array(_validate_runtime_trace(captures, "capture_id", false))
	var seen: Dictionary = {}
	var by_id: Dictionary = {}
	for capture_value in captures:
		var capture := _dict(capture_value)
		var capture_id := str(capture.get("capture_id", ""))
		seen[capture_id] = int(seen.get(capture_id, 0)) + 1
		by_id[capture_id] = capture
		if str(capture.get("png_sha256", "")).length() != 64:
			failures.append("Capture %s has no PNG SHA-256." % capture_id)
		if not bool(capture.get("live_assertions_passed", false)):
			failures.append("Capture %s did not pass live assertions." % capture_id)
		if int(capture.get("width", 0)) < 1280 or int(capture.get("height", 0)) < 720 or str(capture.get("image_format", "")) != "png":
			failures.append("Capture %s is not a full 1280x720-or-larger PNG." % capture_id)
		if str(capture.get("status", "")).is_empty() or str(capture.get("visual_state_sha256", "")).length() != 64:
			failures.append("Capture %s has no authoritative status/visual-state fingerprint." % capture_id)
	for expected_id in EXPECTED_CAPTURE_IDS:
		if int(seen.get(expected_id, 0)) != 1:
			failures.append("Capture id %s was not produced exactly once." % expected_id)
	var outcome_rows := {
		"resolution_repaired": "repaired",
		"resolution_broken": "broken",
		"resolution_refused": "refused",
		"resolution_interrupted": "interrupted",
	}
	var material_png_hashes: Array = []
	var material_state_hashes: Array = []
	for capture_id_value in outcome_rows.keys():
		var capture_id := str(capture_id_value)
		var capture := _dict(by_id.get(capture_id, {}))
		if _string_array(capture.get("outcomes", [])) != [str(outcome_rows.get(capture_id, ""))]:
			failures.append("Capture %s does not prove its exact material outcome." % capture_id)
		material_png_hashes.append(str(capture.get("png_sha256", "")))
		material_state_hashes.append(str(capture.get("visual_state_sha256", "")))
	if _unique_strings(material_png_hashes).size() != 4 or _unique_strings(material_state_hashes).size() != 4:
		failures.append("The four material outcomes are not visually and authoritatively distinct.")
	return failures


static func _percentile(sorted_samples: Array[float], percentile: float) -> float:
	if sorted_samples.is_empty():
		return 0.0
	var rank := ceili(percentile * float(sorted_samples.size())) - 1
	return sorted_samples[clampi(rank, 0, sorted_samples.size() - 1)]


static func _validate_runtime_trace(rows_value: Variant, label_key: String, nested_projection: bool) -> Array:
	var failures: Array = []
	var rows := _array(rows_value)
	if rows.size() != EXPECTED_TRACE_ROWS.size():
		failures.append("Runtime evidence trace must contain exactly 21 ordered records.")
	var seen: Dictionary = {}
	for index in range(rows.size()):
		var row := _dict(rows[index])
		var label := str(row.get(label_key, ""))
		seen[label] = int(seen.get(label, 0)) + 1
		if index >= EXPECTED_TRACE_ROWS.size():
			failures.append("Runtime evidence trace contains unexpected trailing record %s." % label)
			continue
		var expected := _dict(EXPECTED_TRACE_ROWS[index])
		var expected_label := str(expected.get("label", ""))
		if label != expected_label:
			failures.append("Runtime evidence record %d expected %s but saw %s." % [index, expected_label, label])
		var projection := _dict(row.get("projection", {})) if nested_projection else row
		if str(projection.get("scenario_id", "")) != SCENARIO_ID or str(projection.get("node_id", "")) != NODE_ID:
			failures.append("Runtime evidence record %s lost production scenario/node identity." % expected_label)
		if str(projection.get("phase_id", "")) != str(expected.get("phase_id", "")) \
			or str(projection.get("status", "")) != str(expected.get("status", "")):
			failures.append("Runtime evidence record %s has the wrong phase/status invariant." % expected_label)
		var outcome_key := "resolved_outcomes" if nested_projection else "outcomes"
		if _string_array(projection.get(outcome_key, [])) != _string_array(expected.get("outcomes", [])):
			failures.append("Runtime evidence record %s has the wrong outcome invariant." % expected_label)
	for expected_value in EXPECTED_TRACE_ROWS:
		var expected_label := str(_dict(expected_value).get("label", ""))
		if int(seen.get(expected_label, 0)) != 1:
			failures.append("Runtime evidence record %s was not produced exactly once." % expected_label)
	return failures


static func _trace_contract_failures() -> Array:
	var failures: Array = []
	var trace_labels: Array = []
	for row_value in EXPECTED_TRACE_ROWS:
		var row := _dict(row_value)
		trace_labels.append(str(row.get("label", "")))
		if str(row.get("phase_id", "")).is_empty() or str(row.get("status", "")).is_empty() or typeof(row.get("outcomes", [])) != TYPE_ARRAY:
			failures.append("Pinned runtime trace row is incomplete: %s." % str(row.get("label", "")))
	var sorted_trace := trace_labels.duplicate()
	var sorted_captures := EXPECTED_CAPTURE_IDS.duplicate()
	sorted_trace.sort()
	sorted_captures.sort()
	if trace_labels.size() != 21 or _unique_strings(trace_labels).size() != 21 or sorted_trace != sorted_captures:
		failures.append("Pinned runtime trace must contain every authored capture id exactly once.")
	return failures


static func _canonical_dictionary(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var keys: Array = source.keys()
	keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	for key_value in keys:
		result[str(key_value)] = _canonical_variant(source.get(key_value))
	return result


static func _canonical_variant(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		return _canonical_dictionary(value)
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for child in value as Array:
			result.append(_canonical_variant(child))
		return result
	if typeof(value) == TYPE_VECTOR2:
		var vector: Vector2 = value
		return {"x": vector.x, "y": vector.y}
	if typeof(value) == TYPE_RECT2:
		var rect: Rect2 = value
		return {"position": _canonical_variant(rect.position), "size": _canonical_variant(rect.size)}
	return value


static func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	for item in _array(value):
		result.append(str(item))
	return result


static func _unique_strings(value: Array) -> Array:
	var result: Array = []
	for item in value:
		var text := str(item)
		if not result.has(text):
			result.append(text)
	return result
