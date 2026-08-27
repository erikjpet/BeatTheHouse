extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const ScenarioCatalogScript := preload("res://scripts/core/scenario_sequence_catalog.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const SequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const SequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")

const AUTHORITATIVE_FAIL_THRESHOLD := 0.820
const HOSTILE_FIXTURE_SCENARIO_ID := "corner_store_delivery_day"
const HARD_DEFINITION_ROWS := [
	"arrival_readable", "semantic_changes", "scenario_interaction", "action_boundaries",
	"choice_or_failure", "material_outcomes", "revisit_coverage", "world_connection",
	"primary_verb", "feedback_and_exit",
]

var output_path := "res://.tmp/env06_6/scenario_sequence_audit.json"
var report_path := "res://.tmp/env06_6/scenario_sequence_audit.md"
var expected_count := 1
var similarity_fail_threshold := AUTHORITATIVE_FAIL_THRESHOLD
var argument_failures: Array = []


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output_path = argument.trim_prefix("--out=").strip_edges()
		elif argument.begins_with("--report="):
			report_path = argument.trim_prefix("--report=").strip_edges()
		elif argument.begins_with("--expected-count="):
			var expected_value := argument.trim_prefix("--expected-count=").strip_edges()
			if not expected_value.is_valid_int() or int(expected_value) <= 0:
				argument_failures.append("--expected-count must be a positive integer.")
			else:
				expected_count = int(expected_value)
		elif argument.begins_with("--similarity-fail-threshold="):
			var threshold_value := argument.trim_prefix("--similarity-fail-threshold=").strip_edges()
			if not threshold_value.is_valid_float() or float(threshold_value) < 0.0 or float(threshold_value) > 1.0:
				argument_failures.append("--similarity-fail-threshold must be between 0 and 1.")
			else:
				similarity_fail_threshold = float(threshold_value)
		else:
			argument_failures.append("Unknown scenario-sequence audit argument: %s" % argument)
	if absf(similarity_fail_threshold - AUTHORITATIVE_FAIL_THRESHOLD) > 0.000001:
		argument_failures.append("--similarity-fail-threshold must equal the schema authority threshold %.3f." % AUTHORITATIVE_FAIL_THRESHOLD)
	if output_path.is_empty() or report_path.is_empty() or output_path == report_path:
		argument_failures.append("Scenario-sequence audit requires distinct non-empty JSON and Markdown output paths.")
	call_deferred("_run")


func _run() -> void:
	var library := ContentLibraryScript.new()
	library.load()
	var catalog := ScenarioCatalogScript.load_catalog()
	var definitions := _definitions(library, catalog)
	var target_inventories := _target_inventories(library, definitions)
	var masked_explanations := _masked_explanations(definitions)
	var authority_report := ScenarioEngineScript.sequence_catalog_audit(definitions, expected_count, masked_explanations, target_inventories)
	var failures: Array = argument_failures.duplicate(true)
	failures.append_array(_strings(library.validation_errors))
	failures.append_array(_strings(catalog.get("failures", [])))
	failures.append_array(_strings(authority_report.get("failures", [])))
	var representative := _representative_definition(definitions)
	var hostile_fixtures := _hostile_fixture_report(representative, _dict(target_inventories.get(HOSTILE_FIXTURE_SCENARIO_ID, {})))
	for fixture_value in hostile_fixtures:
		var fixture := _dict(fixture_value)
		if not bool(fixture.get("rejected", false)):
			failures.append("Scenario audit hostile fixture was not rejected: %s." % str(fixture.get("class", "unknown")))
	var dossiers: Array = []
	for definition_value in definitions:
		dossiers.append(_dossier(_dict(definition_value), authority_report))
	var exact_expected_shape := report_has_exact_shape(authority_report, expected_count)
	var exact_proof_shape := expected_count == 1 and exact_expected_shape
	if expected_count == 1 and not exact_proof_shape:
		failures.append("env06_6 proof audit requires exactly 1 definition and 0 pairwise comparisons.")
	var report := {
		"schema_version": 1,
		"passed": failures.is_empty(),
		"expected_count": expected_count,
		"actual_count": int(authority_report.get("actual_count", definitions.size())),
		"expected_comparison_count": int(authority_report.get("expected_comparison_count", -1)),
		"comparison_count": int(authority_report.get("comparison_count", -1)),
		"exact_expected_shape": exact_expected_shape,
		"exact_env06_6_proof_shape": exact_proof_shape,
		"similarity_fail_threshold": similarity_fail_threshold,
		"threshold_authority": "ScenarioSequenceSchema.uniqueness_band",
		"catalog_root": str(catalog.get("root_path", "")),
		"package_files": _strings(catalog.get("files", [])),
		"failures": failures,
		"warnings": _strings(authority_report.get("warnings", [])),
		"hostile_fixture_rejections": hostile_fixtures,
		"dossiers": dossiers,
	}
	var json_ok := _write_text(output_path, JSON.stringify(report, "\t") + "\n")
	var markdown_ok := _write_text(report_path, _markdown(report))
	if not json_ok or not markdown_ok:
		quit(1)
		return
	print("SCENARIO_SEQUENCE_AUDIT %s count=%d pairs=%d report=%s" % [
		"PASS" if bool(report.get("passed", false)) else "FAIL",
		int(report.get("actual_count", 0)), int(report.get("comparison_count", 0)),
		ProjectSettings.globalize_path(output_path),
	])
	for failure_value in failures:
		push_error(str(failure_value))
	quit(0 if bool(report.get("passed", false)) else 1)


static func report_has_exact_shape(authority_report: Dictionary, required_count: int) -> bool:
	var required_comparisons := int(required_count * (required_count - 1) / 2)
	return int(authority_report.get("actual_count", -1)) == required_count \
		and int(authority_report.get("expected_comparison_count", -1)) == required_comparisons \
		and int(authority_report.get("comparison_count", -1)) == required_comparisons


static func hostile_fixture_report_for_definitions(definitions: Array) -> Array:
	return _hostile_fixture_report(_representative_definition(definitions))


static func _definitions(library: ContentLibrary, catalog: Dictionary) -> Array:
	var result: Array = []
	var scenario_ids := _dict(catalog.get("overlays", {})).keys()
	scenario_ids.sort()
	for scenario_id_value in scenario_ids:
		var definition := library.scenario(str(scenario_id_value))
		if not definition.is_empty():
			result.append(definition)
	return result


static func _target_inventories(library: ContentLibrary, definitions: Array) -> Dictionary:
	var result: Dictionary = {}
	for definition_value in definitions:
		var definition := _dict(definition_value)
		var scenario_id := str(definition.get("id", ""))
		var catalog := library.scenario_target_catalog(definition)
		if catalog.is_empty() or not _array(catalog.get("errors", [])).is_empty():
			continue
		var inventory := _dict(catalog.get("guaranteed", {}))
		inventory["event_choices"] = _dict(catalog.get("event_choices", {}))
		result[scenario_id] = inventory
	return result


static func _masked_explanations(definitions: Array) -> Dictionary:
	var result: Dictionary = {}
	for definition_value in definitions:
		var authoring := _dict(_dict(definition_value).get("sequence_authoring", {}))
		for key_value in _dict(authoring.get("masked_visual_explanations", {})).keys():
			result[str(key_value)] = str(_dict(authoring.get("masked_visual_explanations", {})).get(key_value, ""))
	return result


static func _representative_definition(definitions: Array) -> Dictionary:
	var definition := ScenarioCatalogScript.definition_for_id(definitions, HOSTILE_FIXTURE_SCENARIO_ID)
	return definition


static func _dossier(definition: Dictionary, authority_report: Dictionary) -> Dictionary:
	var sequence := SequenceSchemaScript.sequence(definition)
	var authoring := _dict(definition.get("sequence_authoring", {}))
	var calculated := SequenceSchemaScript.calculated_completion_contract(definition)
	var supported_rows: Array = []
	var unsupported_rows: Array = []
	for row_value in HARD_DEFINITION_ROWS:
		var row := str(row_value)
		if bool(calculated.get(row, false)):
			supported_rows.append(row)
		else:
			unsupported_rows.append(row)
	var uniqueness_row: Dictionary = {}
	for row_value in _array(authority_report.get("rows", [])):
		var row := _dict(row_value)
		if str(row.get("id", "")) == str(definition.get("id", "")):
			uniqueness_row = row
			break
	return {
		"id": str(definition.get("id", "")),
		"package": {
			"id": str(definition.get("sequence_package_id", "")),
			"handler_pack": str(definition.get("sequence_handler_pack", "")),
			"renderer_id": str(definition.get("sequence_renderer_id", "")),
		},
		"phase_graph": {
			"initial_phase": str(_dict(sequence.get("phase_graph", {})).get("initial_phase", "")),
			"phases": _phase_rows(sequence),
			"reachable_terminal_branches": _reachable_terminal_rows(sequence),
		},
		"player_verbs": _strings(authoring.get("player_verbs", [])),
		"objectives": _objective_rows(sequence),
		"persistence": {
			"local_state_schema": _dict(sequence.get("local_state_schema", {})),
			"reentry_policy": _dict(sequence.get("reentry_policy", {})),
			"expiry": _dict(sequence.get("expiry", {})),
			"cleanup": _dict(sequence.get("cleanup", {})),
			"aftermath_outcomes": _sorted_strings(_dict(sequence.get("aftermath", {})).keys()),
		},
		"normalized_signature": _dict(uniqueness_row.get("signature", SequenceSchemaScript.normalized_signature(definition))),
		"nearest_id": str(uniqueness_row.get("nearest_id", "")),
		"nearest_similarity": float(uniqueness_row.get("nearest_similarity", 0.0)),
		"references": _dict(authoring.get("references", {})),
		"evidence": {
			"arrival_summary": str(authoring.get("arrival_summary", "")),
			"world_connections": _strings(authoring.get("world_connections", [])),
			"capture_ids": _strings(authoring.get("capture_ids", [])),
			"seed_evidence": _dict(authoring.get("seed_evidence", {})),
		},
		"hard_definition": {
			"required_row_count": HARD_DEFINITION_ROWS.size(),
			"supported_count": supported_rows.size(),
			"supported_rows": supported_rows,
			"unsupported_rows": unsupported_rows,
			"owner_exceptions": _array(sequence.get("owner_exceptions", [])),
		},
	}


static func _phase_rows(sequence: Dictionary) -> Array:
	var rows: Array = []
	for phase_value in _array(_dict(sequence.get("phase_graph", {})).get("phases", [])):
		var phase := _dict(phase_value)
		var branches: Array = []
		for branch_value in _array(phase.get("branches", [])):
			var branch := _dict(branch_value)
			branches.append({
				"id": str(branch.get("id", "")), "condition": _dict(branch.get("condition", {})),
				"next_phase": str(branch.get("next_phase", "")), "outcome": str(branch.get("outcome", "")),
			})
		rows.append({
			"id": str(phase.get("id", "")), "terminal": bool(phase.get("terminal", false)),
			"arrival_feedback": str(phase.get("arrival_feedback", "")), "exit_prompt": str(phase.get("exit_prompt", "")),
			"scene_deltas": _operation_rows(phase.get("scene_ops", [])),
			"interaction_deltas": _operation_rows(phase.get("interaction_ops", [])),
			"actor_deltas": _operation_rows(phase.get("actor_ops", [])),
			"branches": branches,
		})
	return rows


static func _operation_rows(value: Variant) -> Array:
	var result: Array = []
	for operation_value in _array(value):
		var operation := _dict(operation_value)
		result.append({
			"op": str(operation.get("op", "")), "receipt_id": str(operation.get("receipt_id", "")),
			"owner_namespace": str(operation.get("owner_namespace", "")),
			"stable_object_id": str(operation.get("stable_object_id", "")),
			"target_owner_namespace": str(operation.get("target_owner_namespace", "")),
			"target_stable_object_id": str(operation.get("target_stable_object_id", "")),
		})
	return result


static func _reachable_terminal_rows(sequence: Dictionary) -> Array:
	var graph := _dict(sequence.get("phase_graph", {}))
	var phases: Dictionary = {}
	for phase_value in _array(graph.get("phases", [])):
		var phase := _dict(phase_value)
		phases[str(phase.get("id", ""))] = phase
	var reached: Dictionary = {}
	var pending: Array = [str(graph.get("initial_phase", ""))]
	var result: Array = []
	while not pending.is_empty():
		var phase_id := str(pending.pop_front())
		if reached.has(phase_id) or not phases.has(phase_id):
			continue
		reached[phase_id] = true
		var phase := _dict(phases.get(phase_id, {}))
		for branch_value in _array(phase.get("branches", [])):
			var branch := _dict(branch_value)
			var target := str(branch.get("next_phase", ""))
			var outcome := str(branch.get("outcome", ""))
			if not target.is_empty():
				pending.append(target)
			elif bool(phase.get("terminal", false)) and not outcome.is_empty():
				result.append({"phase_id": phase_id, "branch_id": str(branch.get("id", "")), "outcome": outcome})
	result.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(a) < JSON.stringify(b))
	return result


static func _objective_rows(sequence: Dictionary) -> Array:
	var result: Array = []
	for objective_value in _array(sequence.get("objectives", [])):
		var objective := _dict(objective_value)
		result.append({
			"id": str(objective.get("id", "")), "label": str(objective.get("label", "")),
			"steps": _array(objective.get("steps", [])), "outcomes": _strings(objective.get("outcomes", [])),
		})
	return result


static func _hostile_fixture_report(definition: Dictionary, target_inventory: Dictionary = {}) -> Array:
	if definition.is_empty():
		return [{"class": "fixture_source", "rejected": false, "diagnostic": "schema-valid proof scenario %s is required" % HOSTILE_FIXTURE_SCENARIO_ID}]
	var result: Array = []
	var unreachable := definition.duplicate(true)
	var unreachable_phases := _phases(unreachable)
	var orphan_phase := _dict(unreachable_phases[unreachable_phases.size() - 1])
	orphan_phase["id"] = "hostile_orphan_phase"
	orphan_phase["branches"] = [{"id": "hostile_orphan_outcome", "condition": {"type": "always"}, "outcome": "repaired"}]
	unreachable_phases.append(orphan_phase)
	_set_phases(unreachable, unreachable_phases)
	result.append(_schema_rejection("unreachable_phase", unreachable, "unreachable phase", target_inventory))

	var nonterminating := definition.duplicate(true)
	var looping_phases := _phases(nonterminating)
	var resolution := _dict(looping_phases[looping_phases.size() - 1])
	resolution["terminal"] = false
	resolution["branches"] = [{"id": "hostile_loop", "condition": {"type": "always"}, "next_phase": str(resolution.get("id", ""))}]
	looping_phases[looping_phases.size() - 1] = resolution
	_set_phases(nonterminating, looping_phases)
	result.append(_schema_rejection("nonterminating_graph", nonterminating, "no path to a terminal outcome", target_inventory))

	var no_cleanup := definition.duplicate(true)
	no_cleanup["sequence"]["cleanup"]["operations"] = []
	result.append(_schema_rejection("missing_cleanup", no_cleanup, "cleanup must declare operations", target_inventory))

	var duplicate_receipt := definition.duplicate(true)
	var receipt_phases := _phases(duplicate_receipt)
	var receipt_phase := _dict(receipt_phases[0])
	var receipt_ops := _array(receipt_phase.get("scene_ops", []))
	receipt_ops.append(_dict(receipt_ops[0]))
	receipt_phase["scene_ops"] = receipt_ops
	receipt_phases[0] = receipt_phase
	_set_phases(duplicate_receipt, receipt_phases)
	result.append(_schema_rejection("duplicate_receipt", duplicate_receipt, "duplicate authored receipt_id", target_inventory))

	var duplicate_reward := definition.duplicate(true)
	duplicate_reward["sequence"]["aftermath"]["broken"] = _dict(duplicate_reward["sequence"]["aftermath"]["repaired"])
	result.append(_schema_rejection("duplicate_reward_material_effect", duplicate_reward, "duplicates the normalized material effect", target_inventory))

	var state_only := definition.duplicate(true)
	var state_only_phases := _phases(state_only)
	for index in range(state_only_phases.size()):
		var phase := _dict(state_only_phases[index])
		phase["scene_ops"] = []
		phase["actor_ops"] = []
		state_only_phases[index] = phase
	_set_phases(state_only, state_only_phases)
	result.append(_schema_rejection("unreadable_state_only_transition", state_only, "completion_contract.arrival_readable is not supported", target_inventory))

	var invalid_reference := definition.duplicate(true)
	invalid_reference["sequence_authoring"]["references"]["objects"] = ["invented::hostile_object"]
	var reference_errors := ScenarioEngineScript.validate_sequence_definition(invalid_reference, {})
	result.append({"class": "invalid_reference", "rejected": _contains(reference_errors, "invalid object identity"), "diagnostic": _matching(reference_errors, "invalid object identity")})

	var missing_evidence := definition.duplicate(true)
	missing_evidence["sequence_authoring"]["capture_ids"] = []
	var evidence_errors := ScenarioEngineScript.validate_sequence_definition(missing_evidence, {})
	result.append({"class": "missing_evidence", "rejected": _contains(evidence_errors, "requires capture_ids and seed_evidence"), "diagnostic": _matching(evidence_errors, "requires capture_ids and seed_evidence")})

	var orphan_result := OperationRegistryScript.resolve_interactions([], [{
		"owner_namespace": "scenario", "stable_object_id": "hostile_orphan_hit_region",
		"presentation_object_id": "scenario::hostile_orphan_hit_region", "label": "Hostile orphan",
		"state_label": "Blocked", "prompt": "Unavailable.", "enabled": false, "disabled_reason": "Hostile fixture.",
		"available_actions": [], "input_actions": ["confirm"], "non_color_state": "blocked", "focus_order": 0,
		"hit_bounds": {"w": 44, "h": 44}, "min_target_size": 44, "safe_exit": false, "alternate_exit": false,
		"mode": "gate", "target_owner_namespace": "event", "target_stable_object_id": "hostile_missing_target",
	}])
	result.append({"class": "orphan_hit_region", "rejected": not bool(orphan_result.get("ok", true)) and _contains(_array(orphan_result.get("errors", [])), "targets missing identity"), "diagnostic": _matching(_array(orphan_result.get("errors", [])), "targets missing identity")})

	var equivalent := definition.duplicate(true)
	equivalent["id"] = "hostile_equivalent_signature"
	var equivalent_report := ScenarioEngineScript.sequence_catalog_audit([definition, equivalent], 2, {})
	result.append({"class": "equivalent_signature", "rejected": not bool(equivalent_report.get("ok", true)) and _contains(_array(equivalent_report.get("failures", [])), "equal_hash_hard_fail"), "diagnostic": _matching(_array(equivalent_report.get("failures", [])), "equal_hash_hard_fail")})
	return result


static func _schema_rejection(fixture_class: String, definition: Dictionary, needle: String, target_inventory: Dictionary = {}) -> Dictionary:
	var errors := SequenceSchemaScript.validate_definition(definition, OperationRegistryScript, target_inventory)
	return {"class": fixture_class, "rejected": _contains(errors, needle), "diagnostic": _matching(errors, needle)}


static func _phases(definition: Dictionary) -> Array:
	return _array(_dict(_dict(definition.get("sequence", {})).get("phase_graph", {})).get("phases", []))


static func _set_phases(definition: Dictionary, phases: Array) -> void:
	definition["sequence"]["phase_graph"]["phases"] = phases


static func _markdown(report: Dictionary) -> String:
	var lines: Array = [
		"# Scenario Sequence Audit", "",
		"- Result: **%s**" % ("PASS" if bool(report.get("passed", false)) else "FAIL"),
		"- Definitions: `%d` (expected `%d`)" % [int(report.get("actual_count", 0)), int(report.get("expected_count", 0))],
		"- Pairwise comparisons: `%d` (expected `%d`)" % [int(report.get("comparison_count", 0)), int(report.get("expected_comparison_count", 0))],
		"- Authoritative fail threshold: `%.3f`" % float(report.get("similarity_fail_threshold", 0.0)), "",
		"## Hostile fixture rejection", "", "| Class | Rejected | Diagnostic |", "| --- | --- | --- |",
	]
	for fixture_value in _array(report.get("hostile_fixture_rejections", [])):
		var fixture := _dict(fixture_value)
		lines.append("| `%s` | %s | %s |" % [str(fixture.get("class", "")), "yes" if bool(fixture.get("rejected", false)) else "no", _markdown_cell(str(fixture.get("diagnostic", "")))])
	for dossier_value in _array(report.get("dossiers", [])):
		var dossier := _dict(dossier_value)
		var hard := _dict(dossier.get("hard_definition", {}))
		lines.append_array(["", "## `%s`" % str(dossier.get("id", "")), "", "- Hard definition: `%d/%d`; owner exceptions: `%d`." % [int(hard.get("supported_count", 0)), int(hard.get("required_row_count", 0)), _array(hard.get("owner_exceptions", [])).size()], "- Nearest sequence: `%s`; similarity: `%.3f`." % [str(dossier.get("nearest_id", "")), float(dossier.get("nearest_similarity", 0.0))], "- Reachable terminal branches: `%d`." % _array(_dict(dossier.get("phase_graph", {})).get("reachable_terminal_branches", [])).size(), "- Capture ids: `%d`." % _array(_dict(dossier.get("evidence", {})).get("capture_ids", [])).size()])
	if not _array(report.get("failures", [])).is_empty():
		lines.append_array(["", "## Failures", ""])
		for failure_value in _array(report.get("failures", [])):
			lines.append("- %s" % str(failure_value))
	return "\n".join(lines) + "\n"


static func _write_text(path: String, content: String) -> bool:
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write scenario-sequence audit output: %s" % path)
		return false
	file.store_string(content)
	file.close()
	return true


static func _markdown_cell(value: String) -> String:
	return value.replace("|", "\\|").replace("\n", " ")


static func _matching(values: Array, needle: String) -> String:
	for value in values:
		if str(value).contains(needle):
			return str(value)
	return ""


static func _contains(values: Array, needle: String) -> bool:
	return not _matching(values, needle).is_empty()


static func _sorted_strings(value: Variant) -> Array:
	var result := _strings(value)
	result.sort()
	return result


static func _strings(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for item_value in value as Array:
			result.append(str(item_value))
	return result


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
