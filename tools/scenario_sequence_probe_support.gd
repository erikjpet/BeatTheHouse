class_name ScenarioSequenceProbeSupport
extends RefCounted

# Shared fail-closed authority for the delivery-day capture, parity, and timing
# probes. Timings and host metadata never enter the canonical semantic hash.

const PACKAGE_PATH := "res://data/environments/scenario_sequences/env06_7_shops_streets.json"
const SCENARIO_ID := "corner_store_delivery_day"
const ARCHETYPE_ID := "corner_store"
const NODE_ID := "corner_store_delivery_day_node"
const EVENT_ID := "scenario_delivery_day_stock"
const RESOLUTION_ID := "delivery_day_stock_resolution"
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
	var checkpoints := _array(semantic.get("checkpoints", []))
	if checkpoints.is_empty():
		failures.append("Probe emitted no semantic checkpoints.")
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
	var ids := _string_array(manifest.get("capture_ids", []))
	if ids != EXPECTED_CAPTURE_IDS:
		failures.append("Capture manifest ids are not the exact authored 21-id sequence.")
	var captures := _array(manifest.get("captures", []))
	if captures.size() != EXPECTED_CAPTURE_IDS.size():
		failures.append("Capture manifest must contain exactly 21 capture records.")
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
