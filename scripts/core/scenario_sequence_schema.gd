class_name ScenarioSequenceSchema
extends RefCounted

# Data-only contract for authored room sequences. Runtime state is normalized by
# ScenarioSequenceRuntime; this class validates immutable definitions.

const DefaultOperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")

const SCHEMA_VERSION := 2
const LOCAL_TYPES := ["bool", "int", "float", "string", "enum", "string_array", "int_array"]
const REENTRY_POLICIES := ["resume", "restart", "aftermath", "expired"]
const EXPIRY_BOUNDARIES := ["none", "leave", "visit_end", "night_end", "town_action"]
const EXPIRY_POLICIES := ["resume", "fail", "ignore", "cancel", "cleanup"]
const OBJECTIVE_OUTCOMES := ["success", "failure", "ignore", "cancel"]
const CONDITION_TYPES := ["always", "command", "fact", "local_equals", "local_min", "objective", "outcome", "receipt"]
const RECEIPT_KINDS := ["command", "fact", "operation", "transition", "cleanup", "visit"]
const FACT_TYPES := [
	"game_result", "event_result", "service_result", "travel_departed", "travel_arrived",
	"crew_changed", "crew_job_changed", "heat_changed", "heat_band_changed",
	"town_transition", "sweep_changed", "world_boundary", "scenario_command",
]
const FACT_PREDICATE_FIELDS := {
	"game_result": ["game_id", "action_id", "won", "ended", "bankroll_delta", "chips_delta", "applied_heat_delta"],
	"event_result": ["event_id", "choice_id", "resolution_id", "resolved", "ok"],
	"service_result": ["kind", "service_id", "ok", "action_id"],
	"travel_departed": ["source_id", "target_id", "travel_kind"],
	"travel_arrived": ["source_id", "target_id", "travel_kind"],
	"crew_changed": ["member_id", "change", "value"],
	"crew_job_changed": ["job_id", "definition_id", "member_id", "status", "outcome"],
	"heat_changed": ["previous", "current", "applied_delta", "source"],
	"heat_band_changed": ["previous_band", "current_band", "current", "source"],
	"town_transition": ["action_index", "weather", "day_type", "happening_ids"],
	"sweep_changed": ["action_index", "node_id", "segment_index", "active"],
	"world_boundary": ["amount", "action_index"],
	"scenario_command": ["command_id", "receipt_id"],
}
const FACT_PREDICATE_FIELD_TYPES := {
	"game_result": {"game_id": TYPE_STRING, "action_id": TYPE_STRING, "won": TYPE_BOOL, "ended": TYPE_BOOL, "bankroll_delta": TYPE_INT, "chips_delta": TYPE_INT, "applied_heat_delta": TYPE_INT},
	"event_result": {"event_id": TYPE_STRING, "choice_id": TYPE_STRING, "resolution_id": TYPE_STRING, "resolved": TYPE_BOOL, "ok": TYPE_BOOL},
	"service_result": {"kind": TYPE_STRING, "service_id": TYPE_STRING, "ok": TYPE_BOOL, "action_id": TYPE_STRING},
	"travel_departed": {"source_id": TYPE_STRING, "target_id": TYPE_STRING, "travel_kind": TYPE_STRING},
	"travel_arrived": {"source_id": TYPE_STRING, "target_id": TYPE_STRING, "travel_kind": TYPE_STRING},
	"crew_changed": {"member_id": TYPE_STRING, "change": TYPE_STRING, "value": -1},
	"crew_job_changed": {"job_id": TYPE_STRING, "definition_id": TYPE_STRING, "member_id": TYPE_STRING, "status": TYPE_STRING, "outcome": TYPE_STRING},
	"heat_changed": {"previous": TYPE_INT, "current": TYPE_INT, "applied_delta": TYPE_INT, "source": TYPE_STRING},
	"heat_band_changed": {"previous_band": TYPE_STRING, "current_band": TYPE_STRING, "current": TYPE_INT, "source": TYPE_STRING},
	"town_transition": {"action_index": TYPE_INT, "weather": TYPE_STRING, "day_type": TYPE_STRING, "happening_ids": TYPE_ARRAY},
	"sweep_changed": {"action_index": TYPE_INT, "node_id": TYPE_STRING, "segment_index": TYPE_INT, "active": TYPE_BOOL},
	"world_boundary": {"amount": TYPE_INT, "action_index": TYPE_INT},
	"scenario_command": {"command_id": TYPE_STRING, "receipt_id": TYPE_STRING},
}
const FACT_PAYLOAD_TYPES := {
	"game_result": {"game_id": "string", "action_id": "string", "won": "bool", "ended": "bool", "bankroll_delta": "int", "chips_delta": "int", "applied_heat_delta": "int"},
	"event_result": {"event_id": "string", "choice_id": "string", "resolution_id": "string", "resolved": "bool", "ok": "bool"},
	"service_result": {"kind": "string", "service_id": "string", "ok": "bool", "action_id": "string"},
	"travel_departed": {"source_id": "string", "target_id": "string", "travel_kind": "string"},
	"travel_arrived": {"source_id": "string", "target_id": "string", "travel_kind": "string"},
	"crew_changed": {"member_id": "string", "change": "string", "value": "dynamic"},
	"crew_job_changed": {"job_id": "string", "status": "string", "definition_id": "string", "member_id": "string", "outcome": "string"},
	"heat_changed": {"previous": "int", "current": "int", "applied_delta": "int", "source": "string"},
	"heat_band_changed": {"previous_band": "string", "current_band": "string", "current": "int", "source": "string"},
	"town_transition": {"action_index": "int", "weather": "string", "day_type": "string", "happening_ids": "string_array"},
	"sweep_changed": {"action_index": "int", "node_id": "string", "segment_index": "int", "active": "bool"},
	"world_boundary": {"amount": "int", "action_index": "int"},
	"scenario_command": {"command_id": "string", "receipt_id": "string"},
}
const ALLOWED_SEQUENCE_KEYS := [
	"schema_version", "local_state_schema", "phase_graph", "objectives",
	"reentry_policy", "expiry", "cleanup", "aftermath", "mechanic_tags",
	"sequence_signature", "owner_exceptions", "fact_subscriptions", "completion_contract", "declared_targets",
]
const ALLOWED_EXCEPTION_ROWS := [
	"arrival_readable", "semantic_changes", "scenario_interaction", "action_boundaries",
	"choice_or_failure", "material_outcomes", "revisit_coverage", "world_connection",
	"primary_verb", "feedback_and_exit",
]
const MAX_PHASES := 16
const MAX_BRANCHES_PER_PHASE := 8
const MAX_OBJECTIVES := 8
const MAX_STEPS_PER_OBJECTIVE := 8
const MAX_LOCAL_FIELDS := 32
const MAX_FACT_SUBSCRIPTIONS := 32
const MAX_AFTERMATHS := 8
const MAX_OPERATIONS_PER_FAMILY := 32
const MAX_COLLECTION_ENTRIES := 64
const MAX_DATA_DEPTH := 12
const MAX_TOTAL_VALUES := 4096
const MAX_TEXT_LENGTH := 512
const PHASE_KEYS := ["id", "label", "arrival_feedback", "exit_prompt", "terminal", "entry_conditions", "objective_ids", "advance_after_actions", "scene_ops", "interaction_ops", "actor_ops", "transition_ops", "branches"]
const BRANCH_KEYS := ["id", "condition", "next_phase", "outcome", "objective_outcomes"]
const CONDITION_KEYS := ["type", "command_id", "fact_type", "payload_equals", "key", "value", "objective_id", "step_id", "outcome", "receipt_kind", "family", "boundary_id", "receipt_id"]
const OBJECTIVE_KEYS := ["id", "label", "progress_label", "steps", "outcomes"]
const STEP_KEYS := ["id", "label", "kind", "command_id", "fact_type", "payload_equals"]
const AFTERMATH_KEYS := ["label", "revisit_feedback", "scene_ops", "interaction_ops", "actor_ops", "service_ops", "game_ops", "route_ops"]


static func sequence(definition: Dictionary) -> Dictionary:
	var value: Variant = definition.get("sequence", {})
	return (value as Dictionary).duplicate(false) if typeof(value) == TYPE_DICTIONARY else {}


static func is_sequence(definition: Dictionary) -> bool:
	return not sequence(definition).is_empty()


static func validate_definition(definition: Dictionary, operation_registry: Variant = null, target_inventory: Dictionary = {}) -> Array:
	if operation_registry == null:
		operation_registry = DefaultOperationRegistryScript
	var errors: Array = []
	var scenario_id := str(definition.get("id", "")).strip_edges()
	var authored := sequence(definition)
	if authored.is_empty():
		return errors
	var label := "scenario %s sequence" % scenario_id
	_append_unknown_keys(label, authored, ALLOWED_SEQUENCE_KEYS, errors)
	if int(authored.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("%s schema_version must be %d." % [label, SCHEMA_VERSION])
	_validate_shape_bounds(label, authored, errors)
	if not errors.is_empty():
		return errors
	_validate_declared_targets(label, authored.get("declared_targets", {}), target_inventory, errors)
	_validate_local_state_schema(label, _dict(authored.get("local_state_schema", {})), errors)
	_validate_phase_graph(label, authored, _dict(authored.get("phase_graph", {})), operation_registry, errors)
	_validate_objectives(label, _array(authored.get("objectives", [])), errors)
	_validate_reentry_expiry_cleanup(label, authored, operation_registry, errors)
	var reachable_outcomes := _reachable_outcomes(_dict(authored.get("phase_graph", {})))
	_validate_cross_references(label, authored, reachable_outcomes, operation_registry, target_inventory, errors)
	_validate_aftermath(label, authored, _dict(authored.get("aftermath", {})), reachable_outcomes, operation_registry, target_inventory, errors)
	_validate_fact_subscriptions(label, _array(authored.get("fact_subscriptions", [])), operation_registry, errors)
	_validate_event_bridge_authorizers(label, authored, errors)
	_validate_tags_and_exceptions(label, authored, errors)
	_validate_completion_contract(label, _dict(authored.get("completion_contract", {})), definition, errors)
	_validate_cross_family_identity_collisions(label, authored, errors)
	_validate_no_executable_strings(label, authored, errors)
	var authored_signature := str(authored.get("sequence_signature", "")).strip_edges()
	var calculated_signature := calculated_signature_hash(definition)
	if authored_signature != calculated_signature:
		errors.append("%s sequence_signature mismatch (authored %s, calculated %s)." % [label, authored_signature, calculated_signature])
	return errors


static func default_local_state(definition: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var fields := _dict(sequence(definition).get("local_state_schema", {}))
	var keys := fields.keys()
	keys.sort()
	for key_value in keys:
		var field_id := str(key_value)
		var field := _dict(fields.get(key_value, {}))
		result[field_id] = _normalized_local_value(str(field.get("type", "")), field.get("default"), field)
	return result


static func normalize_local_state(definition: Dictionary, value: Variant) -> Dictionary:
	var result := default_local_state(definition)
	if typeof(value) != TYPE_DICTIONARY:
		return result
	var fields := _dict(sequence(definition).get("local_state_schema", {}))
	for key_value in fields.keys():
		var field_id := str(key_value)
		if (value as Dictionary).has(field_id):
			var field := _dict(fields.get(field_id, {}))
			result[field_id] = _normalized_local_value(str(field.get("type", "")), (value as Dictionary).get(field_id), field)
	return result


# Local fields are private unless the authored schema opts them into the public
# projection. This keeps newly added branch/control state runtime-owned.
static func public_local_state(definition: Dictionary, value: Variant) -> Dictionary:
	var normalized := normalize_local_state(definition, value)
	var fields := _dict(sequence(definition).get("local_state_schema", {}))
	var result: Dictionary = {}
	var keys := fields.keys()
	keys.sort()
	for key_value in keys:
		var field_id := str(key_value)
		if str(_dict(fields.get(key_value, {})).get("visibility", "private")) == "public":
			result[field_id] = normalized.get(field_id)
	return result


static func phase_ids(definition: Dictionary) -> Array:
	var result: Array = []
	for phase_value in _array(_dict(sequence(definition).get("phase_graph", {})).get("phases", [])):
		if typeof(phase_value) == TYPE_DICTIONARY:
			var phase_id := str((phase_value as Dictionary).get("id", "")).strip_edges()
			if not phase_id.is_empty() and not result.has(phase_id):
				result.append(phase_id)
	return result


static func reachable_outcome_ids(definition: Dictionary) -> Array:
	return _reachable_outcomes(_dict(sequence(definition).get("phase_graph", {})))


static func initial_phase_id(definition: Dictionary) -> String:
	var graph := _dict(sequence(definition).get("phase_graph", {}))
	var authored := str(graph.get("initial_phase", "")).strip_edges()
	if not authored.is_empty():
		return authored
	var ids := phase_ids(definition)
	return str(ids[0]) if not ids.is_empty() else ""


static func phase(definition: Dictionary, phase_id: String) -> Dictionary:
	for phase_value in _array(_dict(sequence(definition).get("phase_graph", {})).get("phases", [])):
		if typeof(phase_value) == TYPE_DICTIONARY and str((phase_value as Dictionary).get("id", "")) == phase_id:
			return (phase_value as Dictionary).duplicate(false)
	return {}


# Author labels and ids are deliberately excluded. The audit compares both this
# calculated signature and the authored signature so renaming cannot hide a
# complete-sequence duplicate.
static func normalized_signature(definition: Dictionary) -> Dictionary:
	var authored := sequence(definition)
	if authored.is_empty():
		return {}
	var graph := _dict(authored.get("phase_graph", {}))
	var phase_features: Array = []
	for phase_value in _array(graph.get("phases", [])):
		var phase_data := _dict(phase_value)
		var operation_features: Array = []
		for family in ["scene_ops", "interaction_ops", "actor_ops", "transition_ops"]:
			for op_value in _array(phase_data.get(family, [])):
				operation_features.append(_normalized_operation_feature(family, _dict(op_value)))
		operation_features.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(a) < JSON.stringify(b))
		var branches: Array = []
		for branch_value in _array(phase_data.get("branches", [])):
			var branch := _dict(branch_value)
			var condition := _dict(branch.get("condition", {}))
			branches.append({
				"condition": _normalized_condition_feature(condition),
				"edge": "phase" if not str(branch.get("next_phase", "")).is_empty() else "outcome",
				"objective_outcomes": _sorted_strings(_dict(branch.get("objective_outcomes", {})).values()),
			})
		branches.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(a) < JSON.stringify(b))
		phase_features.append({
			"ops": operation_features,
			"branches": branches,
			"objective_count": _string_array(phase_data.get("objective_ids", [])).size(),
			"terminal": bool(phase_data.get("terminal", false)),
			"advance_after_actions": maxi(0, int(phase_data.get("advance_after_actions", 0))),
		})
	phase_features.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(a) < JSON.stringify(b))
	var objective_features: Array = []
	for objective_value in _array(authored.get("objectives", [])):
		var objective := _dict(objective_value)
		var steps: Array = []
		for step_value in _array(objective.get("steps", [])):
			var step := _dict(step_value)
			steps.append({"kind": str(step.get("kind", "")), "source": str(step.get("fact_type", "world" if str(step.get("kind", "")) == "world_boundary" else "command"))})
		steps.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(a) < JSON.stringify(b))
		objective_features.append({"steps": steps, "outcome_count": _string_array(objective.get("outcomes", [])).size()})
	objective_features.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(a) < JSON.stringify(b))
	var aftermath_features: Array = []
	for aftermath_value in _dict(authored.get("aftermath", {})).values():
		aftermath_features.append(_normalized_aftermath_effect(_dict(aftermath_value)))
	aftermath_features.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(a) < JSON.stringify(b))
	var cleanup_features: Array = []
	for operation_value in _array(_dict(authored.get("cleanup", {})).get("operations", [])):
		var operation := _dict(operation_value)
		cleanup_features.append(_normalized_operation_feature(str(operation.get("family", "")), operation))
	cleanup_features.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(a) < JSON.stringify(b))
	return {
		"phase_count": phase_features.size(),
		"phases": phase_features,
		"topology": _normalized_topology(graph),
		"objectives": objective_features,
		"aftermath": aftermath_features,
		"cleanup": cleanup_features,
		"fact_types": _fact_subscription_types(authored.get("fact_subscriptions", [])),
		# Authored prose/tags are review labels, not calculated uniqueness evidence.
		# Similarity is derived only from normalized executable semantics.
		"declared_target_counts": _declared_target_counts(authored.get("declared_targets", {})),
		"reentry": _canonical_variant(_dict(authored.get("reentry_policy", {}))),
		"expiry": _canonical_variant(_dict(authored.get("expiry", {}))),
	}


static func _declared_target_counts(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	var declared := _dict(value)
	for collection_key in ["scene_objects", "interactions", "actors", "services", "games", "routes", "anchors", "zones"]:
		result[collection_key] = _string_array(declared.get(collection_key, [])).size()
	return result


static func signature_text(definition: Dictionary) -> String:
	return JSON.stringify(_canonical_variant(normalized_signature(definition)))


static func calculated_signature_hash(definition: Dictionary) -> String:
	return signature_text(definition).sha256_text()


static func signature_similarity(left: Dictionary, right: Dictionary) -> float:
	return _signature_similarity_from_tokens(_signature_tokens(left), _signature_tokens(right))


static func _signature_similarity_from_tokens(left_tokens: Dictionary, right_tokens: Dictionary) -> float:
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


static func catalog_uniqueness_report(definitions: Array, expected_count: int, operation_registry: Variant = null, masked_visual_explanations: Dictionary = {}, target_inventories: Dictionary = {}) -> Dictionary:
	var failures: Array = []
	var warnings: Array = []
	var rows: Array = []
	var dossiers: Array = []
	var pairs: Array = []
	var signature_tokens: Array = []
	var canonical_signature_texts: Array = []
	var ids: Dictionary = {}
	if definitions.size() != expected_count:
		failures.append("scenario sequence rollout expected %d definitions, got %d." % [expected_count, definitions.size()])
	for definition_value in definitions:
		var definition := _dict(definition_value)
		var scenario_id := str(definition.get("id", "")).strip_edges()
		if not _valid_id(scenario_id) or ids.has(scenario_id):
			failures.append("scenario sequence rollout has invalid or duplicate id %s." % scenario_id)
			continue
		ids[scenario_id] = true
		if not is_sequence(definition):
			failures.append("scenario %s is missing its required sequence." % scenario_id)
		var validation := validate_definition(definition, operation_registry, _dict(target_inventories.get(scenario_id, {})))
		if not validation.is_empty():
			failures.append("scenario %s is invalid: %s" % [scenario_id, JSON.stringify(validation)])
		var authored := sequence(definition)
		var phases := _array(_dict(authored.get("phase_graph", {})).get("phases", []))
		var branch_count := 0
		for phase_value in phases: branch_count += _array(_dict(phase_value).get("branches", [])).size()
		var signature := normalized_signature(definition)
		rows.append({"id": scenario_id, "signature": signature, "authored_signature": str(authored.get("sequence_signature", "")), "calculated_signature": calculated_signature_hash(definition), "nearest_id": "", "nearest_similarity": 0.0})
		signature_tokens.append(_signature_tokens(signature))
		canonical_signature_texts.append(JSON.stringify(_canonical_variant(signature)))
		dossiers.append({
			"id": scenario_id,
			"package_id": str(definition.get("sequence_package_id", "")),
			"handler_pack": str(definition.get("sequence_handler_pack", "")),
			"renderer_id": str(definition.get("sequence_renderer_id", "")),
			"phase_count": phases.size(),
			"branch_count": branch_count,
			"objective_count": _array(authored.get("objectives", [])).size(),
			"mechanic_tags": _string_array(authored.get("mechanic_tags", [])),
			"calculated_completion": calculated_completion_contract(definition),
			"capture_ids": _string_array(_dict(definition.get("sequence_authoring", {})).get("capture_ids", [])),
			"seed_evidence": _dict(_dict(definition.get("sequence_authoring", {})).get("seed_evidence", {})),
		})
	var comparison_count := 0
	for left_index in range(rows.size()):
		for right_index in range(left_index + 1, rows.size()):
			comparison_count += 1
			var left_row := _dict(rows[left_index])
			var right_row := _dict(rows[right_index])
			var left_signature := _dict(left_row.get("signature", {}))
			var right_signature := _dict(right_row.get("signature", {}))
			var similarity := _signature_similarity_from_tokens(_dict(signature_tokens[left_index]), _dict(signature_tokens[right_index]))
			if similarity > float(left_row.get("nearest_similarity", 0.0)):
				left_row["nearest_similarity"] = similarity
				left_row["nearest_id"] = str(right_row.get("id", ""))
				rows[left_index] = left_row
			if similarity > float(right_row.get("nearest_similarity", 0.0)):
				right_row["nearest_similarity"] = similarity
				right_row["nearest_id"] = str(left_row.get("id", ""))
				rows[right_index] = right_row
			var equal_hash := str(canonical_signature_texts[left_index]) == str(canonical_signature_texts[right_index])
			var band := uniqueness_band(similarity, equal_hash)
			var pair_ids := [str(left_row.get("id", "")), str(right_row.get("id", ""))]
			pair_ids.sort()
			var pair_key := "%s::%s" % [pair_ids[0], pair_ids[1]]
			var diagnostic := "scenario %s vs %s: %.3f (%s)." % [str(left_row.get("id", "")), str(right_row.get("id", "")), similarity, str(band.get("status", ""))]
			var evidence := _dict(masked_visual_explanations.get(pair_key, {}))
			var explanation := str(evidence.get("explanation", "")).strip_edges()
			var evidence_valid := not explanation.is_empty() and _valid_sha256(str(evidence.get("capture_receipt_sha256", ""))) and _valid_sha256(str(evidence.get("reviewer_receipt_sha256", "")))
			pairs.append({"left_id": str(left_row.get("id", "")), "right_id": str(right_row.get("id", "")), "similarity": similarity, "equal_normalized_hash": equal_hash, "status": str(band.get("status", "")), "blocking": bool(band.get("blocking", false)), "masked_visual_evidence": evidence.duplicate(true), "masked_visual_evidence_valid": evidence_valid})
			if bool(band.get("blocking", false)):
				failures.append(diagnostic)
			elif str(band.get("status", "")) == "warning":
				if not evidence_valid:
					failures.append("%s Missing receipt-bound masked visual evidence." % diagnostic)
				else:
					warnings.append(diagnostic)
	rows.sort_custom(func(a: Variant, b: Variant) -> bool: return str((a as Dictionary).get("id", "")) < str((b as Dictionary).get("id", "")))
	dossiers.sort_custom(func(a: Variant, b: Variant) -> bool: return str((a as Dictionary).get("id", "")) < str((b as Dictionary).get("id", "")))
	pairs.sort_custom(func(a: Variant, b: Variant) -> bool: return "%s::%s" % [str((a as Dictionary).get("left_id", "")), str((a as Dictionary).get("right_id", ""))] < "%s::%s" % [str((b as Dictionary).get("left_id", "")), str((b as Dictionary).get("right_id", ""))])
	var expected_comparisons := int(expected_count * (expected_count - 1) / 2)
	if comparison_count != expected_comparisons:
		failures.append("scenario sequence rollout expected %d pairwise comparisons, got %d." % [expected_comparisons, comparison_count])
	return {"ok": failures.is_empty(), "expected_count": expected_count, "actual_count": definitions.size(), "expected_comparison_count": expected_comparisons, "comparison_count": comparison_count, "rows": rows, "pairs": pairs, "dossiers": dossiers, "failures": failures, "warnings": warnings}


static func catalog_rollout_report(definitions: Array, expected_ids: Array, operation_registry: Variant = null, masked_visual_explanations: Dictionary = {}, required_sequence_ids: Array = [], target_inventories: Dictionary = {}) -> Dictionary:
	var expected := _sorted_strings(expected_ids)
	var actual: Array = []
	var by_id: Dictionary = {}
	for definition_value in definitions:
		if typeof(definition_value) == TYPE_DICTIONARY:
			var definition := definition_value as Dictionary
			var scenario_id := str(definition.get("id", "")).strip_edges()
			actual.append(scenario_id)
			by_id[scenario_id] = definition
	actual = _sorted_strings(actual)
	var required := _sorted_strings(required_sequence_ids)
	var required_definitions: Array = []
	var preflight_failures: Array = []
	for required_id_value in required:
		var required_id := str(required_id_value)
		if not expected.has(required_id):
			preflight_failures.append("sequence-required scenario %s is not declared in the production catalog manifest." % required_id)
		elif not by_id.has(required_id):
			preflight_failures.append("sequence-required scenario %s is missing from the production catalog." % required_id)
		elif not is_sequence(_dict(by_id.get(required_id, {}))):
			preflight_failures.append("sequence-required scenario %s is missing its required sequence." % required_id)
		else:
			required_definitions.append(_dict(by_id.get(required_id, {})))
	var report := catalog_uniqueness_report(required_definitions, required.size(), operation_registry, masked_visual_explanations, target_inventories)
	var failures := preflight_failures + _array(report.get("failures", []))
	if definitions.size() != expected.size():
		failures.append("scenario catalog manifest expected %d definitions, got %d." % [expected.size(), definitions.size()])
	if actual != expected:
		failures.append("scenario sequence rollout ids must exactly match the production manifest (expected %s, got %s)." % [JSON.stringify(expected), JSON.stringify(actual)])
	var status_rows: Array = []
	for scenario_id_value in expected:
		var scenario_id := str(scenario_id_value)
		status_rows.append({"id": scenario_id, "status": "sequence_required" if required.has(scenario_id) else "legacy_pending_env06_7"})
	report["expected_ids"] = expected
	report["actual_ids"] = actual
	report["catalog_expected_count"] = expected.size()
	report["catalog_actual_count"] = definitions.size()
	report["required_sequence_ids"] = required
	report["rollout_statuses"] = status_rows
	report["failures"] = failures
	report["ok"] = failures.is_empty()
	return report


static func uniqueness_band(similarity: float, equal_normalized_hash: bool = false) -> Dictionary:
	var score := clampf(similarity, 0.0, 1.0)
	if equal_normalized_hash:
		return {"status": "equal_hash_hard_fail", "severity": "P1", "blocking": true}
	if score >= 0.820:
		return {"status": "fail", "severity": "P1", "blocking": true}
	if score >= 0.720:
		return {"status": "blocking_review", "severity": "P2", "blocking": true}
	if score >= 0.600:
		return {"status": "warning", "severity": "P2", "blocking": false}
	return {"status": "pass", "severity": "", "blocking": false}


static func _validate_local_state_schema(label: String, fields: Dictionary, errors: Array) -> void:
	if fields.size() > MAX_LOCAL_FIELDS:
		errors.append("%s local_state_schema exceeds %d fields." % [label, MAX_LOCAL_FIELDS])
	for field_value in _sorted_keys(fields):
		var field_id := str(field_value)
		if typeof(field_value) != TYPE_STRING or not _valid_id(field_id):
			errors.append("%s local_state_schema has invalid field id: %s." % [label, field_id])
			continue
		var field := _dict(fields.get(field_value, {}))
		var type_id := str(field.get("type", "")) if typeof(field.get("type")) == TYPE_STRING else ""
		var allowed_keys := ["type", "default", "visibility"]
		if type_id == "enum": allowed_keys.append("values")
		if type_id in ["int", "float"] and (field.has("min") or field.has("max")): allowed_keys.append_array(["min", "max"])
		_append_unknown_keys("%s local field %s" % [label, field_id], field, allowed_keys, errors)
		if not LOCAL_TYPES.has(type_id):
			errors.append("%s local field %s has unsupported type %s." % [label, field_id, type_id])
		elif str(field.get("visibility", "private")) not in ["private", "public"]:
			errors.append("%s local field %s visibility must be private or public." % [label, field_id])
		elif type_id in ["int", "float"] and field.has("min") != field.has("max"):
			errors.append("%s local field %s must declare both min and max or neither." % [label, field_id])
		elif type_id == "enum" and not _canonical_string_values(field.get("values", [])):
			errors.append("%s local field %s requires nonempty unique string enum values." % [label, field_id])
		elif not field.has("default") or not _local_value_matches(type_id, field.get("default"), field):
			errors.append("%s local field %s has an invalid or missing default." % [label, field_id])
		elif field.has("min") and (not _local_value_matches(type_id, field.get("min"), {}) or not _local_value_matches(type_id, field.get("max"), {}) or float(field.get("min")) > float(field.get("max"))):
			errors.append("%s local field %s has invalid bounds." % [label, field_id])


static func _validate_phase_graph(label: String, authored: Dictionary, graph: Dictionary, operation_registry: Variant, errors: Array) -> void:
	_append_unknown_keys("%s phase_graph" % label, graph, ["initial_phase", "phases"], errors)
	var phases := _array(graph.get("phases", []))
	if phases.is_empty():
		errors.append("%s phase_graph must contain phases." % label)
		return
	if phases.size() > MAX_PHASES:
		errors.append("%s phase_graph exceeds %d phases." % [label, MAX_PHASES])
	var ids: Dictionary = {}
	var branch_ids: Dictionary = {}
	for phase_value in phases:
		if typeof(phase_value) != TYPE_DICTIONARY:
			errors.append("%s phase must be a dictionary." % label)
			continue
		var phase_data := phase_value as Dictionary
		var phase_id := str(phase_data.get("id", "")).strip_edges()
		_append_unknown_keys("%s phase %s" % [label, phase_id], phase_data, PHASE_KEYS, errors)
		if not _valid_id(phase_id) or ids.has(phase_id):
			errors.append("%s has invalid or duplicate phase id %s." % [label, phase_id])
		else:
			ids[phase_id] = true
		if str(phase_data.get("label", "")).strip_edges().is_empty() or str(phase_data.get("arrival_feedback", "")).strip_edges().is_empty() or str(phase_data.get("exit_prompt", "")).strip_edges().is_empty():
			errors.append("%s phase %s requires label, arrival_feedback, and exit_prompt." % [label, phase_id])
		if int(phase_data.get("advance_after_actions", 0)) < 0:
			errors.append("%s phase %s advance_after_actions must be non-negative." % [label, phase_id])
		for condition_value in _array(phase_data.get("entry_conditions", [])):
			_validate_condition("%s phase %s entry" % [label, phase_id], _dict(condition_value), errors)
		for family in ["scene_ops", "interaction_ops", "actor_ops", "transition_ops"]:
			var operations := _array(phase_data.get(family, []))
			_validate_operation_receipt_uniqueness("%s phase %s %s" % [label, phase_id, family], operations, errors)
			for operation_value in operations:
				if typeof(operation_value) != TYPE_DICTIONARY:
					errors.append("%s phase %s %s entry must be a dictionary." % [label, phase_id, family])
				elif operation_registry != null and operation_registry.has_method("validate_operation"):
					for operation_error in operation_registry.call("validate_operation", family, operation_value as Dictionary):
						errors.append("%s phase %s: %s" % [label, phase_id, str(operation_error)])
		_validate_phase_safe_exit(label, authored, phase_data, errors)
		var branches := _array(phase_data.get("branches", []))
		if branches.is_empty():
			errors.append("%s phase %s is a dead end without a terminal branch." % [label, phase_id])
		if branches.size() > MAX_BRANCHES_PER_PHASE:
			errors.append("%s phase %s exceeds %d branches." % [label, phase_id, MAX_BRANCHES_PER_PHASE])
		var seen_conditions: Dictionary = {}
		for branch_index in range(branches.size()):
			var branch_value: Variant = branches[branch_index]
			if typeof(branch_value) != TYPE_DICTIONARY:
				errors.append("%s phase %s branch must be a dictionary." % [label, phase_id])
				continue
			var branch := branch_value as Dictionary
			_append_unknown_keys("%s phase %s branch" % [label, phase_id], branch, BRANCH_KEYS, errors)
			var branch_id := str(branch.get("id", "")).strip_edges()
			if not _valid_id(branch_id) or branch_ids.has(branch_id):
				errors.append("%s phase %s has invalid or duplicate branch id %s." % [label, phase_id, branch_id])
			else:
				branch_ids[branch_id] = phase_id
			_validate_condition("%s phase %s branch" % [label, phase_id], _dict(branch.get("condition", {})), errors)
			var condition_fingerprint := JSON.stringify(_canonical_variant(_dict(branch.get("condition", {}))))
			if seen_conditions.has(condition_fingerprint):
				errors.append("%s phase %s branch %s is structurally shadowed by an earlier identical condition." % [label, phase_id, branch_id])
			seen_conditions[condition_fingerprint] = true
			if str(_dict(branch.get("condition", {})).get("type", "")) == "always" and branch_index < branches.size() - 1:
				errors.append("%s phase %s has an always branch before later unreachable branches." % [label, phase_id])
			if branch.has("objective_outcomes") and typeof(branch.get("objective_outcomes")) != TYPE_DICTIONARY:
				errors.append("%s phase %s branch %s objective_outcomes must be a dictionary." % [label, phase_id, branch_id])
	var initial_id := str(graph.get("initial_phase", "")).strip_edges()
	if initial_id.is_empty() or not ids.has(initial_id):
		errors.append("%s initial_phase is missing or unknown: %s." % [label, initial_id])
	for phase_value in phases:
		if typeof(phase_value) != TYPE_DICTIONARY:
			continue
		var phase_data := phase_value as Dictionary
		for branch_value in _array(phase_data.get("branches", [])):
			var branch := _dict(branch_value)
			var target := str(branch.get("next_phase", "")).strip_edges()
			var outcome := str(branch.get("outcome", "")).strip_edges()
			if target.is_empty() == outcome.is_empty():
				errors.append("%s branch %s must name exactly one next_phase or outcome." % [label, str(branch.get("id", ""))])
			elif not target.is_empty() and not ids.has(target):
				errors.append("%s branch %s references unknown phase %s." % [label, str(branch.get("id", "")), target])
			elif not outcome.is_empty() and not bool(phase_data.get("terminal", false)):
				errors.append("%s non-terminal phase %s cannot emit outcome %s." % [label, str(phase_data.get("id", "")), outcome])
			if bool(phase_data.get("terminal", false)) and not target.is_empty():
				errors.append("%s terminal phase %s cannot branch to another phase." % [label, str(phase_data.get("id", ""))])
	_validate_reachability(label, initial_id, phases, ids, errors)
	_validate_termination(label, initial_id, phases, ids, errors)
	var outcomes := _reachable_outcomes(graph)
	if outcomes.size() < 3:
		errors.append("%s requires at least three reachable terminal outcomes." % label)


static func _validate_reachability(label: String, initial_id: String, phases: Array, ids: Dictionary, errors: Array) -> void:
	if not ids.has(initial_id):
		return
	var reached := {initial_id: true}
	var pending: Array = [initial_id]
	while not pending.is_empty():
		var current := str(pending.pop_front())
		for phase_value in phases:
			if typeof(phase_value) != TYPE_DICTIONARY or str((phase_value as Dictionary).get("id", "")) != current:
				continue
			for branch_value in _array((phase_value as Dictionary).get("branches", [])):
				var target := str(_dict(branch_value).get("next_phase", "")).strip_edges()
				if not target.is_empty() and ids.has(target) and not reached.has(target):
					reached[target] = true
					pending.append(target)
	for phase_value in ids.keys():
		if not reached.has(str(phase_value)):
			errors.append("%s contains unreachable phase %s." % [label, str(phase_value)])


static func _validate_termination(label: String, initial_id: String, phases: Array, ids: Dictionary, errors: Array) -> void:
	if not ids.has(initial_id):
		return
	var predecessors: Dictionary = {}
	var terminating: Dictionary = {}
	for phase_value in phases:
		var phase_data := _dict(phase_value)
		var phase_id := str(phase_data.get("id", ""))
		predecessors[phase_id] = []
	for phase_value in phases:
		var phase_data := _dict(phase_value)
		var phase_id := str(phase_data.get("id", ""))
		for branch_value in _array(phase_data.get("branches", [])):
			var branch := _dict(branch_value)
			var target := str(branch.get("next_phase", "")).strip_edges()
			if not str(branch.get("outcome", "")).strip_edges().is_empty():
				terminating[phase_id] = true
			elif ids.has(target):
				var reverse := _array(predecessors.get(target, []))
				if not reverse.has(phase_id):
					reverse.append(phase_id)
				predecessors[target] = reverse
	var pending := terminating.keys()
	while not pending.is_empty():
		var target := str(pending.pop_front())
		for predecessor_value in _array(predecessors.get(target, [])):
			var predecessor := str(predecessor_value)
			if not terminating.has(predecessor):
				terminating[predecessor] = true
				pending.append(predecessor)
	for phase_id_value in ids.keys():
		if not terminating.has(str(phase_id_value)):
			errors.append("%s phase %s has no path to a terminal outcome." % [label, str(phase_id_value)])


static func _validate_objectives(label: String, objectives: Array, errors: Array) -> void:
	if objectives.size() > MAX_OBJECTIVES:
		errors.append("%s exceeds %d objectives." % [label, MAX_OBJECTIVES])
	var ids: Dictionary = {}
	for objective_value in objectives:
		if typeof(objective_value) != TYPE_DICTIONARY:
			errors.append("%s objective must be a dictionary." % label)
			continue
		var objective := objective_value as Dictionary
		var objective_id := str(objective.get("id", "")).strip_edges()
		_append_unknown_keys("%s objective %s" % [label, objective_id], objective, OBJECTIVE_KEYS, errors)
		if not _valid_id(objective_id) or ids.has(objective_id):
			errors.append("%s has invalid or duplicate objective id %s." % [label, objective_id])
		else:
			ids[objective_id] = true
		if str(objective.get("label", "")).strip_edges().is_empty() or str(objective.get("progress_label", "")).strip_edges().is_empty():
			errors.append("%s objective %s requires public label and progress_label." % [label, objective_id])
		var steps := _array(objective.get("steps", []))
		if steps.is_empty():
			errors.append("%s objective %s requires at least one step." % [label, objective_id])
		if steps.size() > MAX_STEPS_PER_OBJECTIVE:
			errors.append("%s objective %s exceeds %d steps." % [label, objective_id, MAX_STEPS_PER_OBJECTIVE])
		var step_ids: Dictionary = {}
		for step_value in steps:
			var step := _dict(step_value)
			var step_id := str(step.get("id", "")).strip_edges()
			_append_unknown_keys("%s objective %s step %s" % [label, objective_id, step_id], step, STEP_KEYS, errors)
			if not _valid_id(step_id) or step_ids.has(step_id) or str(step.get("label", "")).strip_edges().is_empty():
				errors.append("%s objective %s has invalid/duplicate/unlabeled step %s." % [label, objective_id, step_id])
			step_ids[step_id] = true
			var kind := str(step.get("kind", ""))
			if not ["command", "fact", "world_boundary"].has(kind):
				errors.append("%s objective %s step %s has invalid kind." % [label, objective_id, step_id])
			elif kind == "command" and not _valid_id(str(step.get("command_id", ""))):
				errors.append("%s objective %s step %s requires command_id." % [label, objective_id, step_id])
			elif kind == "fact" and not FACT_TYPES.has(str(step.get("fact_type", ""))):
				errors.append("%s objective %s step %s requires registered fact_type." % [label, objective_id, step_id])
			elif kind == "fact":
				_validate_fact_payload_predicate("%s objective %s step %s" % [label, objective_id, step_id], str(step.get("fact_type", "")), step.get("payload_equals", {}), errors)
		var objective_outcomes := _string_array(objective.get("outcomes", []))
		var sorted_outcomes := objective_outcomes.duplicate()
		sorted_outcomes.sort()
		var expected_outcomes := OBJECTIVE_OUTCOMES.duplicate()
		expected_outcomes.sort()
		if sorted_outcomes != expected_outcomes:
			errors.append("%s objective %s outcomes must exactly declare success, failure, ignore, and cancel." % [label, objective_id])
		for outcome_value in objective_outcomes:
			if not OBJECTIVE_OUTCOMES.has(str(outcome_value)):
				errors.append("%s objective %s has invalid outcome %s." % [label, objective_id, str(outcome_value)])


static func _validate_reentry_expiry_cleanup(label: String, authored: Dictionary, operation_registry: Variant, errors: Array) -> void:
	var reentry := _dict(authored.get("reentry_policy", {}))
	_append_unknown_keys("%s reentry_policy" % label, reentry, ["partial", "terminal", "expired"], errors)
	for key in ["partial", "terminal", "expired"]:
		if not REENTRY_POLICIES.has(str(reentry.get(key, ""))):
			errors.append("%s reentry_policy.%s is invalid." % [label, key])
	var expiry := _dict(authored.get("expiry", {}))
	_append_unknown_keys("%s expiry" % label, expiry, ["boundary", "after", "policy"], errors)
	if not EXPIRY_BOUNDARIES.has(str(expiry.get("boundary", ""))) or not EXPIRY_POLICIES.has(str(expiry.get("policy", ""))):
		errors.append("%s expiry requires a registered boundary and policy." % label)
	if int(expiry.get("after", 0)) < 0:
		errors.append("%s expiry.after must be non-negative." % label)
	var cleanup := _dict(authored.get("cleanup", {}))
	_append_unknown_keys("%s cleanup" % label, cleanup, ["operations"], errors)
	if cleanup.is_empty() or _array(cleanup.get("operations", [])).is_empty():
		errors.append("%s cleanup must declare operations." % label)
	var cleanup_by_family: Dictionary = {}
	for operation_value in _array(cleanup.get("operations", [])):
		if typeof(operation_value) != TYPE_DICTIONARY:
			errors.append("%s cleanup operation must be a dictionary." % label)
		elif operation_registry != null and operation_registry.has_method("validate_any_operation"):
			for operation_error in operation_registry.call("validate_any_operation", operation_value as Dictionary):
				errors.append("%s cleanup: %s" % [label, str(operation_error)])
		if typeof(operation_value) == TYPE_DICTIONARY:
			var family := str((operation_value as Dictionary).get("family", ""))
			var operations := _array(cleanup_by_family.get(family, []))
			operations.append(operation_value)
			cleanup_by_family[family] = operations
	for family_value in cleanup_by_family.keys():
		_validate_operation_receipt_uniqueness("%s cleanup %s" % [label, str(family_value)], _array(cleanup_by_family.get(family_value, [])), errors)


static func _validate_declared_targets(label: String, value: Variant, target_inventory: Dictionary, errors: Array) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("%s declared_targets must be a dictionary." % label)
		return
	var declared := value as Dictionary
	var allowed := ["scene_objects", "interactions", "actors", "services", "games", "routes", "anchors", "zones"]
	_append_unknown_keys("%s declared_targets" % label, declared, allowed, errors)
	for collection_key in allowed:
		if typeof(declared.get(collection_key, [])) != TYPE_ARRAY:
			errors.append("%s declared_targets.%s must be an array." % [label, collection_key])
			continue
		var identities := _string_array(declared.get(collection_key, []))
		if identities.size() != _array(declared.get(collection_key, [])).size():
			errors.append("%s declared_targets.%s contains invalid or duplicate identities." % [label, collection_key])
		for identity_value in identities:
			if not DefaultOperationRegistryScript.validate_owned_identity(str(identity_value)).is_empty():
				errors.append("%s declared_targets.%s contains invalid identity %s." % [label, collection_key, str(identity_value)])
			elif target_inventory.is_empty():
				errors.append("%s declared_targets.%s identity %s has no independent target catalog proof." % [label, collection_key, str(identity_value)])
			elif not _string_array(target_inventory.get(collection_key, [])).has(str(identity_value)):
				errors.append("%s declared_targets.%s identity %s is not present in the validated archetype/base inventory." % [label, collection_key, str(identity_value)])


static func verified_declared_targets(definition: Dictionary, target_inventory: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var declared := _dict(sequence(definition).get("declared_targets", {}))
	for collection_key in ["scene_objects", "interactions", "actors", "services", "games", "routes", "anchors", "zones"]:
		var available := _string_array(target_inventory.get(collection_key, []))
		var verified: Array = []
		for identity_value in _string_array(declared.get(collection_key, [])):
			if available.has(str(identity_value)): verified.append(str(identity_value))
		result[collection_key] = verified
	return result


static func _validate_phase_safe_exit(label: String, authored: Dictionary, phase_data: Dictionary, errors: Array) -> void:
	var has_safe_exit := _has_persistent_initial_safe_exit(authored)
	var blocked_targets: Dictionary = {}
	var alternate_commands: Dictionary = {}
	for operation_value in _array(phase_data.get("interaction_ops", [])):
		var operation := _dict(operation_value)
		var op_id := str(operation.get("op", ""))
		if op_id == "add":
			var interaction := _dict(operation.get("interaction", {}))
			if bool(interaction.get("safe_exit", false)) and bool(interaction.get("enabled", false)) and not _array(interaction.get("available_actions", [])).is_empty():
				has_safe_exit = true
			if bool(interaction.get("alternate_exit", false)) and bool(interaction.get("enabled", false)):
				for action_value in _array(interaction.get("available_actions", [])):
					alternate_commands[str(_dict(action_value).get("id", ""))] = true
		elif op_id == "gate" and not bool(operation.get("enabled", true)) and not str(operation.get("disabled_reason", "")).strip_edges().is_empty():
			blocked_targets["%s::%s" % [str(operation.get("target_owner_namespace", "")), str(operation.get("target_stable_object_id", ""))]] = true
	if has_safe_exit or blocked_targets.is_empty():
		return
	var alternate_proof := false
	for objective_value in _array(authored.get("objectives", [])):
		var objective := _dict(objective_value)
		if not _string_array(phase_data.get("objective_ids", [])).has(str(objective.get("id", ""))): continue
		for step_value in _array(objective.get("steps", [])):
			var step := _dict(step_value)
			if str(step.get("kind", "")) != "command" or not alternate_commands.has(str(step.get("command_id", ""))): continue
			for branch_value in _array(phase_data.get("branches", [])):
				var branch := _dict(branch_value)
				var condition := _dict(branch.get("condition", {}))
				if (str(condition.get("type", "")) == "command" and str(condition.get("command_id", "")) == str(step.get("command_id", ""))) or (str(condition.get("type", "")) == "objective" and str(condition.get("objective_id", "")) == str(objective.get("id", "")) and str(condition.get("step_id", "")) == str(step.get("id", ""))):
					alternate_proof = not str(branch.get("next_phase", "")).strip_edges().is_empty() or not str(branch.get("outcome", "")).strip_edges().is_empty()
	var declared := _dict(authored.get("declared_targets", {}))
	if blocked_targets.is_empty(): alternate_proof = false
	for blocked_target_value in blocked_targets.keys():
		if not _string_array(declared.get("interactions", [])).has(str(blocked_target_value)) and not _string_array(declared.get("routes", [])).has(str(blocked_target_value)):
			alternate_proof = false
	if not alternate_proof:
		errors.append("%s phase %s must prove an enabled safe-exit action or bind each readable blocked route/exit to a reachable alternate objective action and branch." % [label, str(phase_data.get("id", ""))])


static func _has_persistent_initial_safe_exit(authored: Dictionary) -> bool:
	var graph := _dict(authored.get("phase_graph", {}))
	var initial_phase := str(graph.get("initial_phase", ""))
	var safe_identities: Dictionary = {}
	for phase_value in _array(graph.get("phases", [])):
		var phase := _dict(phase_value)
		if str(phase.get("id", "")) != initial_phase: continue
		for operation_value in _array(phase.get("interaction_ops", [])):
			var operation := _dict(operation_value)
			var interaction := _dict(operation.get("interaction", {}))
			if str(operation.get("op", "")) == "add" and bool(interaction.get("safe_exit", false)) and bool(interaction.get("enabled", false)) and not _array(interaction.get("available_actions", [])).is_empty():
				safe_identities["%s::%s" % [str(operation.get("owner_namespace", "")), str(operation.get("stable_object_id", ""))]] = true
	if safe_identities.is_empty(): return false
	for phase_value in _array(graph.get("phases", [])):
		for operation_value in _array(_dict(phase_value).get("interaction_ops", [])):
			var operation := _dict(operation_value)
			var source_identity := "%s::%s" % [str(operation.get("owner_namespace", "")), str(operation.get("stable_object_id", ""))]
			var target_identity := "%s::%s" % [str(operation.get("target_owner_namespace", "")), str(operation.get("target_stable_object_id", ""))]
			if str(operation.get("op", "")) in ["remove", "replace"]: safe_identities.erase(source_identity)
			if target_identity != "::" and str(operation.get("op", "")) in ["replace", "gate"] and (str(operation.get("op", "")) == "replace" or not bool(operation.get("enabled", true))): safe_identities.erase(target_identity)
	return not safe_identities.is_empty()


static func _validate_aftermath(label: String, authored: Dictionary, aftermaths: Dictionary, reachable_outcomes: Array, operation_registry: Variant, target_inventory: Dictionary, errors: Array) -> void:
	if aftermaths.size() < 3:
		errors.append("%s aftermath must define at least three material outcomes." % label)
	if aftermaths.size() > MAX_AFTERMATHS:
		errors.append("%s aftermath exceeds %d outcomes." % [label, MAX_AFTERMATHS])
	var keys := _sorted_strings(aftermaths.keys())
	var expected := _sorted_strings(reachable_outcomes)
	if keys != expected:
		errors.append("%s aftermath keys must exactly match reachable outcomes (expected %s, got %s)." % [label, JSON.stringify(expected), JSON.stringify(keys)])
	var material_axes: Dictionary = {}
	var effect_signatures: Dictionary = {}
	# Targets created during active phases are real runtime objects; external
	# room fixtures must be named explicitly in declared_targets.
	var terminal_target_paths := _material_target_paths_by_outcome(authored, target_inventory, errors)
	for outcome_value in _sorted_keys(aftermaths):
		var outcome_id := str(outcome_value)
		var aftermath := _dict(aftermaths.get(outcome_value, {}))
		var outcome_paths := _array(terminal_target_paths.get(outcome_id, []))
		_append_unknown_keys("%s aftermath %s" % [label, outcome_id], aftermath, AFTERMATH_KEYS, errors)
		if not _valid_id(outcome_id) or str(aftermath.get("label", "")).strip_edges().is_empty() or str(aftermath.get("revisit_feedback", "")).strip_edges().is_empty():
			errors.append("%s aftermath %s requires valid id, label, and revisit_feedback." % [label, outcome_id])
		var change_count := 0
		for family in ["scene_ops", "interaction_ops", "actor_ops", "service_ops", "game_ops", "route_ops"]:
			var operations := _array(aftermath.get(family, []))
			_validate_operation_receipt_uniqueness("%s aftermath %s %s" % [label, outcome_id, family], operations, errors)
			for operation_value in operations:
				if typeof(operation_value) != TYPE_DICTIONARY:
					continue
				var operation := operation_value as Dictionary
				var operation_errors: Array = []
				if operation_registry != null and operation_registry.has_method("validate_operation"):
					operation_errors = operation_registry.call("validate_operation", family, operation)
					for operation_error in operation_errors:
						errors.append("%s aftermath %s: %s" % [label, outcome_id, str(operation_error)])
				var valid_on_every_path := not outcome_paths.is_empty()
				for path_value in outcome_paths:
					if not _operation_has_material_target(family, operation, _dict(path_value)):
						valid_on_every_path = false
						break
				if operation_errors.is_empty() and valid_on_every_path:
					change_count += 1
					material_axes[family] = true
					for path_value in outcome_paths: _apply_material_target_projection(family, operation, path_value as Dictionary)
				elif operation_errors.is_empty():
					errors.append("%s aftermath %s operation %s is not material on every reachable terminal path." % [label, outcome_id, str(operation.get("receipt_id", ""))])
		if change_count <= 0:
			errors.append("%s aftermath %s has no semantic change." % [label, outcome_id])
		var effect_signature := JSON.stringify(_canonical_variant(outcome_paths))
		if effect_signatures.has(effect_signature):
			errors.append("%s aftermath %s duplicates the normalized material effect of %s." % [label, outcome_id, str(effect_signatures.get(effect_signature, ""))])
		else:
			effect_signatures[effect_signature] = outcome_id
	if material_axes.size() < 2:
		errors.append("%s aftermath requires at least two independent material axes." % label)


static func _material_target_seed(authored: Dictionary, target_inventory: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var declared := _dict(authored.get("declared_targets", {}))
	for collection_key in ["scene_objects", "interactions", "actors", "services", "games", "routes", "anchors", "zones"]:
		var keys: Dictionary = {}
		for identity_value in _string_array(declared.get(collection_key, [])):
			if not target_inventory.is_empty() and _string_array(target_inventory.get(collection_key, [])).has(str(identity_value)):
				keys[str(identity_value)] = {"present": true, "source": "base", "target_identity": str(identity_value), "material_origin": "base", "material_dirty": false}
		result[collection_key] = keys
	return result


static func _material_target_paths_by_outcome(authored: Dictionary, target_inventory: Dictionary, errors: Array = []) -> Dictionary:
	var graph := _dict(authored.get("phase_graph", {}))
	var phase_index: Dictionary = {}
	for phase_value in _array(graph.get("phases", [])):
		var phase_data := _dict(phase_value)
		phase_index[str(phase_data.get("id", ""))] = phase_data
	var pending: Array = [{"phase_id": str(graph.get("initial_phase", "")), "targets": _material_target_seed(authored, target_inventory), "visited": []}]
	var outcomes: Dictionary = {}
	var path_count := 0
	var base_targets := _material_target_seed(authored, target_inventory)
	while not pending.is_empty() and path_count < 512:
		path_count += 1
		var item := _dict(pending.pop_front())
		var phase_id := str(item.get("phase_id", ""))
		var phase_data := _dict(phase_index.get(phase_id, {}))
		if phase_data.is_empty(): continue
		var visited := _string_array(item.get("visited", []))
		if visited.has(phase_id):
			if not _contains_error(errors, "material path repeats phase %s" % phase_id): errors.append("sequence material path repeats phase %s; phase cycles are not permitted." % phase_id)
			continue
		visited.append(phase_id)
		var targets := _dict(item.get("targets", {})).duplicate(true)
		for family in ["scene_ops", "interaction_ops", "actor_ops"]:
			for operation_value in _array(phase_data.get(family, [])):
				var operation := _dict(operation_value)
				if not _operation_has_material_target(family, operation, targets):
					errors.append("sequence phase %s operation %s is duplicate or targets an object that is not live on every incoming path." % [phase_id, str(operation.get("receipt_id", ""))])
					continue
				_apply_material_target_projection(family, operation, targets)
		if _phase_can_request_cleanup(authored, targets):
			_proven_cleanup_projection(authored, targets, base_targets, "phase %s request_cleanup" % phase_id, errors)
		for branch_value in _array(phase_data.get("branches", [])):
			var branch := _dict(branch_value)
			var outcome_id := str(branch.get("outcome", ""))
			var next_phase := str(branch.get("next_phase", ""))
			if not outcome_id.is_empty():
				var paths := _array(outcomes.get(outcome_id, []))
				var fingerprint := JSON.stringify(_canonical_variant(targets))
				var duplicate := false
				for path_value in paths:
					if JSON.stringify(_canonical_variant(path_value)) == fingerprint: duplicate = true
				if not duplicate: paths.append(targets.duplicate(true))
				outcomes[outcome_id] = paths
			elif phase_index.has(next_phase):
				pending.append({"phase_id": next_phase, "targets": targets.duplicate(true), "visited": visited.duplicate(false)})
	if not pending.is_empty():
		errors.append("sequence material path exploration exceeds the explicit 512-path limit.")
	var terminal_obligations: Dictionary = {}
	for cleanup_value in _array(_dict(authored.get("cleanup", {})).get("operations", [])):
		var cleanup := _dict(cleanup_value)
		var family := str(cleanup.get("family", ""))
		for paths_value in outcomes.values():
			for path_value in _array(paths_value):
				if _cleanup_operation_has_obligation(family, cleanup, _dict(path_value), base_targets):
					terminal_obligations[str(cleanup.get("receipt_id", ""))] = true
	var cleaned_outcomes: Dictionary = {}
	for outcome_value in outcomes.keys():
		var cleaned_paths: Array = []
		for path_value in _array(outcomes.get(outcome_value, [])):
			cleaned_paths.append(_proven_cleanup_projection(authored, _dict(path_value), base_targets, "terminal path for outcome %s" % str(outcome_value), errors, terminal_obligations))
		cleaned_outcomes[outcome_value] = cleaned_paths
	return cleaned_outcomes


static func _operation_has_material_target(family: String, operation: Dictionary, known_targets: Dictionary) -> bool:
	if family == "transition_ops": return true
	var op_id := str(operation.get("op", ""))
	var collection_key := _operation_collection_key(family)
	var targets := _dict(known_targets.get(collection_key, {}))
	var source_key := "%s::%s" % [str(operation.get("owner_namespace", "")), str(operation.get("stable_object_id", ""))]
	if family == "interaction_ops" and not ["add", "remove"].has(op_id):
		var target_key := "%s::%s" % [str(operation.get("target_owner_namespace", "")), str(operation.get("target_stable_object_id", ""))]
		if not _material_target_live(targets, target_key):
			return false
		if not targets.has(source_key):
			return true
		var existing_overlay := _dict(targets.get(source_key, {}))
		return _material_target_live(targets, source_key) \
			and str(existing_overlay.get("material_kind", "")) == "interaction_overlay" \
			and str(existing_overlay.get("overlay_target_identity", "")) == target_key
	if family == "scene_ops" and op_id == "spawn" or family in ["interaction_ops", "service_ops", "game_ops"] and op_id == "add" or family == "actor_ops" and op_id == "spawn":
		return not targets.has(source_key)
	return _material_target_live(targets, source_key)


static func _apply_material_target_projection(family: String, operation: Dictionary, known_targets: Dictionary) -> void:
	if family == "transition_ops": return
	var collection_key := _operation_collection_key(family)
	var targets := _dict(known_targets.get(collection_key, {}))
	var source_key := "%s::%s" % [str(operation.get("owner_namespace", "")), str(operation.get("stable_object_id", ""))]
	var op_id := str(operation.get("op", ""))
	if ["remove", "despawn"].has(op_id):
		var removed := _dict(targets.get(source_key, {})).duplicate(true)
		if family == "interaction_ops" and str(removed.get("material_kind", "")) == "interaction_overlay":
			var overlay_target := str(removed.get("overlay_target_identity", ""))
			var target_snapshot := _dict(removed.get("overlay_target_snapshot", {}))
			if not overlay_target.is_empty() and not target_snapshot.is_empty():
				targets[overlay_target] = target_snapshot.duplicate(true)
		if str(removed.get("material_origin", "")) == "base":
			removed["present"] = false
			removed["material_dirty"] = true
			targets[source_key] = removed
		else:
			targets.erase(source_key)
	elif family == "scene_ops" and op_id == "spawn" or family in ["interaction_ops", "service_ops", "game_ops"] and op_id == "add" or family == "actor_ops" and op_id == "spawn":
		targets[source_key] = _material_created_state(family, operation, source_key)
	elif family == "interaction_ops" and not ["add", "remove"].has(op_id):
		var target_key := "%s::%s" % [str(operation.get("target_owner_namespace", "")), str(operation.get("target_stable_object_id", ""))]
		var current := _dict(targets.get(target_key, {})).duplicate(true)
		var overlay := _material_created_state(family, operation, source_key)
		overlay["material_kind"] = "interaction_overlay"
		overlay["overlay_target_identity"] = target_key
		var previous_overlay := _dict(targets.get(source_key, {}))
		overlay["overlay_target_snapshot"] = _dict(previous_overlay.get("overlay_target_snapshot", current)).duplicate(true)
		targets[source_key] = overlay
		if op_id == "replace":
			current["present"] = false
			current["material_dirty"] = true
			targets[target_key] = current
		else:
			_apply_material_fields(current, op_id, operation)
			current["material_dirty"] = true
			targets[target_key] = current
	elif targets.has(source_key):
		var current := _dict(targets.get(source_key, {})).duplicate(true)
		if op_id == "replace" and str(current.get("material_origin", "")) == "base":
			var replacement_payload := _dict(operation.get("object", operation.get("actor", operation.get("interaction", {}))))
			for payload_key in replacement_payload.keys(): current[str(payload_key)] = replacement_payload.get(payload_key)
		else:
			_apply_material_fields(current, op_id, operation)
		if str(current.get("material_origin", "")) == "base": current["material_dirty"] = true
		targets[source_key] = current
	known_targets[collection_key] = targets


static func _material_created_state(family: String, operation: Dictionary, identity: String) -> Dictionary:
	var payload := _dict(operation.get("object", operation.get("actor", operation.get("interaction", {})))).duplicate(true)
	payload["owner_namespace"] = str(operation.get("owner_namespace", ""))
	payload["stable_object_id"] = str(operation.get("stable_object_id", ""))
	payload["target_identity"] = identity
	payload["family"] = family
	payload["present"] = true
	payload["material_origin"] = "sequence"
	payload["material_dirty"] = false
	payload["requests_cleanup"] = _actions_request_cleanup(_array(payload.get("available_actions", operation.get("available_actions", []))))
	return payload


static func _material_target_live(targets: Dictionary, identity: String) -> bool:
	return targets.has(identity) and bool(_dict(targets.get(identity, {})).get("present", false))


static func _cleanup_operation_has_obligation(family: String, operation: Dictionary, known_targets: Dictionary, base_targets: Dictionary) -> bool:
	if family == "transition_ops": return true
	var collection_key := _operation_collection_key(family)
	var targets := _dict(known_targets.get(collection_key, {}))
	var baseline := _dict(base_targets.get(collection_key, {}))
	var source_key := "%s::%s" % [str(operation.get("owner_namespace", "")), str(operation.get("stable_object_id", ""))]
	var op_id := str(operation.get("op", ""))
	if family == "interaction_ops" and not ["add", "remove"].has(op_id):
		var target_key := "%s::%s" % [str(operation.get("target_owner_namespace", "")), str(operation.get("target_stable_object_id", ""))]
		var existing_overlay := _dict(targets.get(source_key, {}))
		var restores_overlay := _material_target_live(targets, source_key) \
			and str(existing_overlay.get("material_kind", "")) == "interaction_overlay" \
			and str(existing_overlay.get("overlay_target_identity", "")) == target_key \
			and baseline.has(target_key) \
			and bool(_dict(targets.get(target_key, {})).get("material_dirty", false))
		var installs_terminal_overlay := not targets.has(source_key) \
			and baseline.has(target_key) \
			and _material_target_live(targets, target_key)
		return restores_overlay or installs_terminal_overlay
	var current := _dict(targets.get(source_key, {}))
	if baseline.has(source_key): return bool(current.get("material_dirty", false))
	return ["remove", "despawn"].has(op_id) and _material_target_live(targets, source_key) and str(current.get("material_origin", "")) == "sequence"


static func _apply_cleanup_material_projection(family: String, operation: Dictionary, known_targets: Dictionary, base_targets: Dictionary) -> void:
	if family == "transition_ops": return
	var collection_key := _operation_collection_key(family)
	var targets := _dict(known_targets.get(collection_key, {}))
	var baseline := _dict(base_targets.get(collection_key, {}))
	var source_key := "%s::%s" % [str(operation.get("owner_namespace", "")), str(operation.get("stable_object_id", ""))]
	var op_id := str(operation.get("op", ""))
	if family == "interaction_ops" and not ["add", "remove"].has(op_id):
		var target_key := "%s::%s" % [str(operation.get("target_owner_namespace", "")), str(operation.get("target_stable_object_id", ""))]
		if targets.has(source_key):
			targets.erase(source_key)
			if baseline.has(target_key): targets[target_key] = _dict(baseline.get(target_key, {})).duplicate(true)
		else:
			var current := _dict(targets.get(target_key, {})).duplicate(true)
			var overlay := _material_created_state(family, operation, source_key)
			overlay["material_kind"] = "interaction_overlay"
			overlay["material_origin"] = "cleanup"
			overlay["overlay_target_identity"] = target_key
			overlay["overlay_target_snapshot"] = current.duplicate(true)
			targets[source_key] = overlay
			_apply_material_fields(current, op_id, operation)
			current["material_dirty"] = true
			targets[target_key] = current
	elif baseline.has(source_key):
		targets[source_key] = _dict(baseline.get(source_key, {})).duplicate(true)
	elif ["remove", "despawn"].has(op_id):
		var removed := _dict(targets.get(source_key, {}))
		if family == "interaction_ops" and str(removed.get("material_kind", "")) == "interaction_overlay":
			var overlay_target := str(removed.get("overlay_target_identity", ""))
			if baseline.has(overlay_target): targets[overlay_target] = _dict(baseline.get(overlay_target, {})).duplicate(true)
		targets.erase(source_key)
	known_targets[collection_key] = targets


static func _proven_cleanup_projection(authored: Dictionary, targets_value: Dictionary, base_targets: Dictionary, path_label: String, errors: Array, terminal_obligations: Dictionary = {}) -> Dictionary:
	var cleaned := targets_value.duplicate(true)
	for cleanup_value in _array(_dict(authored.get("cleanup", {})).get("operations", [])):
		var cleanup := _dict(cleanup_value)
		var family := str(cleanup.get("family", ""))
		if not _cleanup_operation_has_obligation(family, cleanup, cleaned, base_targets):
			if not terminal_obligations.has(str(cleanup.get("receipt_id", ""))):
				errors.append("sequence %s cleanup operation %s has no exact live mutation/tombstone/overlay obligation." % [path_label, str(cleanup.get("receipt_id", ""))])
			continue
		_apply_cleanup_material_projection(family, cleanup, cleaned, base_targets)
	for collection_key in ["scene_objects", "interactions", "actors", "services", "games", "routes"]:
		var collection := _dict(cleaned.get(collection_key, {}))
		for target_value in collection.values():
			var target := _dict(target_value)
			if str(target.get("material_origin", "")) == "sequence" and bool(target.get("present", false)):
				errors.append("sequence %s leaks temporary %s target %s after cleanup." % [path_label, collection_key, str(target.get("target_identity", ""))])
		var baseline_collection := _dict(base_targets.get(collection_key, {}))
		for identity_value in baseline_collection.keys():
			var identity := str(identity_value)
			var retained_cleanup_overlay := false
			if collection_key == "interactions":
				for overlay_value in collection.values():
					var overlay := _dict(overlay_value)
					if bool(overlay.get("present", false)) \
					and str(overlay.get("material_kind", "")) == "interaction_overlay" \
					and str(overlay.get("material_origin", "")) == "cleanup" \
					and str(overlay.get("overlay_target_identity", "")) == identity:
						retained_cleanup_overlay = true
						break
			if retained_cleanup_overlay:
				continue
			if not collection.has(identity) or _canonical_variant(collection.get(identity)) != _canonical_variant(baseline_collection.get(identity)):
				errors.append("sequence %s does not restore exact base %s target %s after cleanup." % [path_label, collection_key, identity])
	return cleaned


static func _phase_can_request_cleanup(authored: Dictionary, known_targets: Dictionary) -> bool:
	for subscription_value in _array(authored.get("fact_subscriptions", [])):
		if str(_dict(subscription_value).get("handler", "")) == "request_cleanup": return true
	for target_value in _dict(known_targets.get("interactions", {})).values():
		var target := _dict(target_value)
		if bool(target.get("present", false)) and bool(target.get("requests_cleanup", false)): return true
	return false


static func _actions_request_cleanup(actions: Array) -> bool:
	for action_value in actions:
		if str(_dict(action_value).get("handler", "")) == "request_cleanup": return true
	return false


static func _apply_material_fields(current: Dictionary, op_id: String, operation: Dictionary) -> void:
	match op_id:
		"move", "set_position":
			if operation.has("anchor_id"): current["anchor_id"] = str(operation.get("anchor_id", ""))
			if operation.has("zone_id"): current["zone_id"] = str(operation.get("zone_id", ""))
		"reveal": current["visible"] = true
		"hide": current["visible"] = false
		"enable", "open":
			current["enabled"] = true
			current["disabled_reason"] = ""
		"disable", "close":
			current["enabled"] = false
			current["disabled_reason"] = str(operation.get("disabled_reason", "Unavailable."))
		"set_state": current["state"] = str(operation.get("state", ""))
		"set_appearance": current["appearance"] = str(operation.get("appearance", ""))
		"set_route": current["route_id"] = str(operation.get("route_id", ""))
		"set_pose": current["pose"] = str(operation.get("pose", ""))
		"set_behavior": current["behavior"] = str(operation.get("behavior", "idle"))
		"gate":
			current["enabled"] = bool(operation.get("enabled", false))
			current["disabled_reason"] = str(operation.get("disabled_reason", "Unavailable.")) if not bool(current.get("enabled", false)) else ""
		"retarget": current["source_id"] = str(operation.get("source_id", current.get("source_id", "")))
		"augment":
			var actions := _array(current.get("available_actions", [])).duplicate(true)
			for action_value in _array(operation.get("available_actions", [])): actions.append(_dict(action_value).duplicate(true))
			current["available_actions"] = actions
		"set_modifier": current["modifier"] = _dict(operation.get("modifier", {})).duplicate(true)


static func _operation_collection_key(family: String) -> String:
	return {"scene_ops": "scene_objects", "interaction_ops": "interactions", "actor_ops": "actors", "service_ops": "services", "game_ops": "games", "route_ops": "routes"}.get(family, "")


static func _validate_operation_receipt_uniqueness(label: String, operations: Array, errors: Array) -> void:
	if operations.size() > MAX_OPERATIONS_PER_FAMILY:
		errors.append("%s exceeds %d operations." % [label, MAX_OPERATIONS_PER_FAMILY])
	var receipts: Dictionary = {}
	for operation_value in operations:
		var receipt_id := str(_dict(operation_value).get("receipt_id", "")).strip_edges()
		if receipt_id.is_empty():
			continue
		if receipts.has(receipt_id):
			errors.append("%s contains duplicate authored receipt_id %s." % [label, receipt_id])
		else:
			receipts[receipt_id] = true


static func _validate_cross_references(label: String, authored: Dictionary, reachable_outcomes: Array, operation_registry: Variant, target_inventory: Dictionary, errors: Array) -> void:
	var local_ids := _dict(authored.get("local_state_schema", {}))
	var subscribed_facts := _fact_subscription_types(authored.get("fact_subscriptions", []))
	var authored_receipts: Dictionary = {}
	var objective_steps: Dictionary = {}
	for objective_value in _array(authored.get("objectives", [])):
		var objective := _dict(objective_value)
		var objective_id := str(objective.get("id", ""))
		var steps: Dictionary = {}
		for step_value in _array(objective.get("steps", [])):
			steps[str(_dict(step_value).get("id", ""))] = true
		objective_steps[objective_id] = steps
	var graph := _dict(authored.get("phase_graph", {}))
	for phase_value in _array(graph.get("phases", [])):
		var receipt_phase := _dict(phase_value)
		for family in ["scene_ops", "interaction_ops", "actor_ops", "transition_ops"]:
			for operation_value in _array(receipt_phase.get(family, [])):
				authored_receipts["%s::%s" % [family, str(_dict(operation_value).get("receipt_id", ""))]] = true
	for aftermath_value in _dict(authored.get("aftermath", {})).values():
		var receipt_aftermath := _dict(aftermath_value)
		for family in ["scene_ops", "interaction_ops", "actor_ops", "service_ops", "game_ops", "route_ops"]:
			for operation_value in _array(receipt_aftermath.get(family, [])):
				authored_receipts["%s::%s" % [family, str(_dict(operation_value).get("receipt_id", ""))]] = true
	for operation_value in _array(_dict(authored.get("cleanup", {})).get("operations", [])):
		var cleanup_operation := _dict(operation_value)
		authored_receipts["%s::%s" % [str(cleanup_operation.get("family", "")), str(cleanup_operation.get("receipt_id", ""))]] = true
	for phase_value in _array(graph.get("phases", [])):
		var phase_data := _dict(phase_value)
		var phase_id := str(phase_data.get("id", ""))
		for objective_id_value in _string_array(phase_data.get("objective_ids", [])):
			if not objective_steps.has(str(objective_id_value)):
				errors.append("%s phase %s references unknown objective %s." % [label, phase_id, str(objective_id_value)])
		for condition_value in _array(phase_data.get("entry_conditions", [])):
			_validate_condition_refs("%s phase %s entry" % [label, phase_id], _dict(condition_value), local_ids, objective_steps, reachable_outcomes, subscribed_facts, authored_receipts, errors)
		for branch_value in _array(phase_data.get("branches", [])):
			var branch := _dict(branch_value)
			_validate_condition_refs("%s phase %s branch" % [label, phase_id], _dict(branch.get("condition", {})), local_ids, objective_steps, reachable_outcomes, subscribed_facts, authored_receipts, errors)
			for objective_id_value in _dict(branch.get("objective_outcomes", {})).keys():
				var objective_id := str(objective_id_value)
				var objective_outcome := str(_dict(branch.get("objective_outcomes", {})).get(objective_id_value, ""))
				if not objective_steps.has(objective_id) or not OBJECTIVE_OUTCOMES.has(objective_outcome):
					errors.append("%s phase %s branch references invalid objective outcome %s/%s." % [label, phase_id, objective_id, objective_outcome])
		for operation_value in _array(phase_data.get("interaction_ops", [])):
			var interaction := _dict(_dict(operation_value).get("interaction", {}))
			for action_value in _array(interaction.get("available_actions", _dict(operation_value).get("available_actions", []))):
				_validate_action_refs("%s phase %s action" % [label, phase_id], _dict(action_value), local_ids, objective_steps, reachable_outcomes, operation_registry, _string_array(phase_data.get("objective_ids", [])), _dict(target_inventory.get("event_choices", {})), errors)
	for subscription_value in _array(authored.get("fact_subscriptions", [])):
		var subscription := _dict(subscription_value)
		if not subscription.is_empty():
			_validate_handler_input_refs("%s fact subscription" % label, str(subscription.get("handler", "")), _dict(subscription.get("inputs", {})), local_ids, objective_steps, reachable_outcomes, operation_registry, {"source": "fact", "fact_payload_types": _dict(FACT_PAYLOAD_TYPES.get(str(subscription.get("fact_type", "")), {})), "event_choices": _dict(target_inventory.get("event_choices", {}))}, errors)
	for objective_value in _array(authored.get("objectives", [])):
		for step_value in _array(_dict(objective_value).get("steps", [])):
			var step := _dict(step_value)
			if str(step.get("kind", "")) == "fact" and not subscribed_facts.has(str(step.get("fact_type", ""))):
				errors.append("%s objective fact step references unsubscribed fact %s." % [label, str(step.get("fact_type", ""))])


static func _validate_condition_refs(label: String, condition: Dictionary, local_ids: Dictionary, objective_steps: Dictionary, reachable_outcomes: Array, subscribed_facts: Array, authored_receipts: Dictionary, errors: Array) -> void:
	match str(condition.get("type", "")):
		"fact":
			if not subscribed_facts.has(str(condition.get("fact_type", ""))):
				errors.append("%s references unsubscribed fact %s." % [label, str(condition.get("fact_type", ""))])
		"local_equals", "local_min":
			var local_key := str(condition.get("key", ""))
			if not local_ids.has(local_key):
				errors.append("%s references unknown local state %s." % [label, str(condition.get("key", ""))])
			elif str(condition.get("type", "")) == "local_min":
				var descriptor := _dict(local_ids.get(local_key, {}))
				if str(descriptor.get("type", "")) != "int" or not condition.has("value") or typeof(condition.get("value")) != TYPE_INT or not _local_value_matches("int", condition.get("value"), descriptor):
					errors.append("%s local_min requires an exact integer threshold within the referenced integer local field domain." % label)
		"objective":
			var objective_id := str(condition.get("objective_id", ""))
			var step_id := str(condition.get("step_id", ""))
			if not objective_steps.has(objective_id) or not _dict(objective_steps.get(objective_id, {})).has(step_id):
				errors.append("%s references unknown objective step %s/%s." % [label, objective_id, step_id])
		"outcome":
			if not reachable_outcomes.has(str(condition.get("outcome", ""))):
				errors.append("%s references unknown outcome %s." % [label, str(condition.get("outcome", ""))])
		"receipt":
			var receipt_id := str(condition.get("receipt_id", ""))
			var receipt_kind := str(condition.get("receipt_kind", ""))
			if receipt_kind == "operation":
				var family := str(condition.get("family", ""))
				if not authored_receipts.has("%s::%s" % [family, receipt_id]):
					errors.append("%s references unknown authored operation receipt %s/%s." % [label, family, receipt_id])


static func _validate_action_refs(label: String, action: Dictionary, local_ids: Dictionary, objective_steps: Dictionary, reachable_outcomes: Array, operation_registry: Variant, phase_objective_ids: Array, event_choices: Dictionary, errors: Array) -> void:
	for requirement_value in _array(action.get("requires_objective_steps", [])):
		var requirement := _dict(requirement_value)
		var objective_id := str(requirement.get("objective_id", ""))
		var step_id := str(requirement.get("step_id", ""))
		if not objective_steps.has(objective_id) or not _dict(objective_steps.get(objective_id, {})).has(step_id):
			errors.append("%s references unknown objective step %s/%s." % [label, objective_id, step_id])
	for requirement_value in _array(action.get("requires_local", [])):
		var requirement := _dict(requirement_value)
		if not local_ids.has(str(requirement.get("key", ""))):
			errors.append("%s references unknown local state %s." % [label, str(requirement.get("key", ""))])
	_validate_handler_input_refs(label, str(action.get("handler", "")), _dict(action.get("inputs", {})), local_ids, objective_steps, reachable_outcomes, operation_registry, {"source": "command", "phase_objective_ids": phase_objective_ids, "event_choices": event_choices}, errors)


static func _validate_handler_input_refs(label: String, handler_id: String, inputs: Dictionary, local_ids: Dictionary, objective_steps: Dictionary, reachable_outcomes: Array, operation_registry: Variant, context: Dictionary, errors: Array) -> void:
	if handler_id.is_empty(): return
	if handler_id in ["set_local", "increment_local"] and not local_ids.has(str(inputs.get("key", ""))):
		errors.append("%s handler references unknown local state %s." % [label, str(inputs.get("key", ""))])
	elif handler_id == "event_bridge" and (not _valid_id(str(inputs.get("event_id", ""))) or not _valid_id(str(inputs.get("resolution_id", "")))):
		errors.append("%s event_bridge requires non-empty stable event_id and resolution_id." % label)
	elif handler_id in ["complete_objective_step", "resolve_objective"]:
		var objective_id := str(inputs.get("objective_id", ""))
		if handler_id == "resolve_objective":
			if not objective_steps.has(objective_id) or not OBJECTIVE_OUTCOMES.has(str(inputs.get("outcome", ""))):
				errors.append("%s handler references invalid objective outcome %s/%s." % [label, objective_id, str(inputs.get("outcome", ""))])
		else:
			var step_id := str(inputs.get("step_id", ""))
			if not objective_steps.has(objective_id) or not _dict(objective_steps.get(objective_id, {})).has(step_id):
				errors.append("%s handler references unknown objective step %s/%s." % [label, objective_id, step_id])
	if operation_registry != null and operation_registry.has_method("validate_handler_inputs"):
		var validation_context := context.duplicate(true)
		validation_context["objective_steps"] = objective_steps
		for handler_error in operation_registry.call("validate_handler_inputs", handler_id, inputs, local_ids, reachable_outcomes, validation_context):
			errors.append("%s: %s" % [label, str(handler_error)])


static func _validate_event_bridge_authorizers(label: String, authored: Dictionary, errors: Array) -> void:
	var bridges: Dictionary = {}
	var predicates: Array = []
	var graph := _dict(authored.get("phase_graph", {}))
	for phase_value in _array(graph.get("phases", [])):
		var phase := _dict(phase_value)
		for operation_value in _array(phase.get("interaction_ops", [])):
			var operation := _dict(operation_value)
			var interaction := _dict(operation.get("interaction", {}))
			for action_value in _array(interaction.get("available_actions", operation.get("available_actions", []))):
				var action := _dict(action_value)
				if str(action.get("handler", "")) == "event_bridge":
					_track_event_bridge(_dict(action.get("inputs", {})), bridges)
		for condition_value in _array(phase.get("entry_conditions", [])):
			_append_event_result_predicate(_dict(condition_value), predicates)
		for branch_value in _array(phase.get("branches", [])):
			_append_event_result_predicate(_dict(_dict(branch_value).get("condition", {})), predicates)
	for subscription_value in _array(authored.get("fact_subscriptions", [])):
		var subscription := _dict(subscription_value)
		if str(subscription.get("fact_type", "")) == "event_result":
			predicates.append(_dict(subscription.get("payload_equals", {})))
		if str(subscription.get("handler", "")) == "event_bridge":
			_track_event_bridge(_dict(subscription.get("inputs", {})), bridges)
	for objective_value in _array(authored.get("objectives", [])):
		for step_value in _array(_dict(objective_value).get("steps", [])):
			var step := _dict(step_value)
			if str(step.get("kind", "")) == "fact" and str(step.get("fact_type", "")) == "event_result":
				predicates.append(_dict(step.get("payload_equals", {})))
	var bridge_keys := bridges.keys()
	bridge_keys.sort()
	for bridge_key_value in bridge_keys:
		var bridge := _dict(bridges.get(bridge_key_value, {}))
		var authorized := false
		for predicate_value in predicates:
			if _is_exact_event_bridge_authorizer(_dict(predicate_value), str(bridge.get("event_id", "")), str(bridge.get("resolution_id", ""))):
				authorized = true
				break
		if not authorized:
			errors.append("%s event_bridge %s/%s requires an exact event_result authorizer with event_id, choice_id, resolution_id, resolved, and ok." % [label, str(bridge.get("event_id", "")), str(bridge.get("resolution_id", ""))])


static func _track_event_bridge(inputs: Dictionary, bridges: Dictionary) -> void:
	var event_id := str(inputs.get("event_id", "")).strip_edges()
	var resolution_id := str(inputs.get("resolution_id", "")).strip_edges()
	if not _valid_id(event_id) or not _valid_id(resolution_id):
		return
	bridges["%s::%s" % [event_id, resolution_id]] = {"event_id": event_id, "resolution_id": resolution_id}


static func _append_event_result_predicate(condition: Dictionary, predicates: Array) -> void:
	if str(condition.get("type", "")) == "fact" and str(condition.get("fact_type", "")) == "event_result":
		predicates.append(_dict(condition.get("payload_equals", {})))


static func _is_exact_event_bridge_authorizer(predicate: Dictionary, event_id: String, resolution_id: String) -> bool:
	return str(predicate.get("event_id", "")) == event_id \
		and str(predicate.get("resolution_id", "")) == resolution_id \
		and predicate.has("choice_id") and typeof(predicate.get("choice_id")) == TYPE_STRING and not str(predicate.get("choice_id", "")).strip_edges().is_empty() \
		and predicate.has("resolved") and typeof(predicate.get("resolved")) == TYPE_BOOL \
		and predicate.has("ok") and typeof(predicate.get("ok")) == TYPE_BOOL


static func _reachable_outcomes(graph: Dictionary) -> Array:
	var phases := _array(graph.get("phases", []))
	var initial_id := str(graph.get("initial_phase", "")).strip_edges()
	var index: Dictionary = {}
	for phase_value in phases:
		var phase_data := _dict(phase_value)
		index[str(phase_data.get("id", ""))] = phase_data
	if not index.has(initial_id):
		return []
	var reached := {initial_id: true}
	var pending: Array = [initial_id]
	var outcomes: Array = []
	while not pending.is_empty():
		var phase_id := str(pending.pop_front())
		var phase_data := _dict(index.get(phase_id, {}))
		for branch_value in _array(phase_data.get("branches", [])):
			var branch := _dict(branch_value)
			var outcome := str(branch.get("outcome", "")).strip_edges()
			var target := str(branch.get("next_phase", "")).strip_edges()
			if bool(phase_data.get("terminal", false)) and not outcome.is_empty() and not outcomes.has(outcome):
				outcomes.append(outcome)
			elif index.has(target) and not reached.has(target):
				reached[target] = true
				pending.append(target)
	outcomes.sort()
	return outcomes


static func _normalized_aftermath_effect(aftermath: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for family in ["scene_ops", "interaction_ops", "actor_ops", "service_ops", "game_ops", "route_ops"]:
		var features: Array = []
		for operation_value in _array(aftermath.get(family, [])):
			features.append(_normalized_operation_feature(family, _dict(operation_value)))
		features.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(a) < JSON.stringify(b))
		if not features.is_empty():
			result[family] = features
	return result


static func _normalized_operation_feature(family: String, operation: Dictionary) -> Dictionary:
	var semantic_operation := _signature_identity_invariant(operation)
	semantic_operation.erase("family")
	return {"family": family, "effect": _canonical_variant(semantic_operation)}


static func _signature_identity_invariant(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	for identity_key in ["receipt_id", "stable_object_id", "presentation_object_id", "target_stable_object_id"]:
		result.erase(identity_key)
	for payload_key in ["object", "actor", "interaction"]:
		if typeof(result.get(payload_key)) == TYPE_DICTIONARY:
			result[payload_key] = _signature_identity_invariant(result.get(payload_key) as Dictionary)
	return result


static func _normalized_condition_feature(condition: Dictionary) -> Dictionary:
	var type_id := str(condition.get("type", ""))
	var result := {"type": type_id}
	if type_id == "fact":
		result["fact_type"] = str(condition.get("fact_type", ""))
	elif type_id in ["local_equals", "local_min"]:
		result["value_type"] = typeof(condition.get("value"))
	return result


static func _normalized_topology(graph: Dictionary) -> Array:
	var phases := _array(graph.get("phases", []))
	var feature_by_id: Dictionary = {}
	for phase_value in phases:
		var phase_data := _dict(phase_value)
		var phase_id := str(phase_data.get("id", ""))
		var phase_edges := 0
		var outcome_edges := 0
		for branch_value in _array(phase_data.get("branches", [])):
			if str(_dict(branch_value).get("next_phase", "")).strip_edges().is_empty():
				outcome_edges += 1
			else:
				phase_edges += 1
		feature_by_id[phase_id] = {"phase_edges": phase_edges, "outcome_edges": outcome_edges, "terminal": bool(phase_data.get("terminal", false)), "depth": -1}
	var initial := str(graph.get("initial_phase", ""))
	if feature_by_id.has(initial):
		var initial_feature := _dict(feature_by_id.get(initial, {}))
		initial_feature["depth"] = 0
		feature_by_id[initial] = initial_feature
		var pending: Array = [initial]
		while not pending.is_empty():
			var phase_id := str(pending.pop_front())
			var depth := int(_dict(feature_by_id.get(phase_id, {})).get("depth", 0))
			for phase_value in phases:
				var phase_data := _dict(phase_value)
				if str(phase_data.get("id", "")) != phase_id:
					continue
				for branch_value in _array(phase_data.get("branches", [])):
					var target := str(_dict(branch_value).get("next_phase", ""))
					if feature_by_id.has(target) and int(_dict(feature_by_id.get(target, {})).get("depth", -1)) < 0:
						var target_feature := _dict(feature_by_id.get(target, {}))
						target_feature["depth"] = depth + 1
						feature_by_id[target] = target_feature
						pending.append(target)
	var result := feature_by_id.values()
	result.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(a) < JSON.stringify(b))
	return result


static func _validate_shape_bounds(label: String, value: Variant, errors: Array) -> void:
	var counter := {"count": 0}
	_validate_bounded_value(label, value, 0, counter, [], errors)


static func _validate_bounded_value(label: String, value: Variant, depth: int, counter: Dictionary, ancestors: Array, errors: Array) -> void:
	counter["count"] = int(counter.get("count", 0)) + 1
	if int(counter.get("count", 0)) > MAX_TOTAL_VALUES:
		if not _contains_error(errors, "total value limit"):
			errors.append("%s exceeds the total value limit." % label)
		return
	if depth > MAX_DATA_DEPTH:
		if not _contains_error(errors, "nesting depth"):
			errors.append("%s exceeds the maximum nesting depth." % label)
		return
	if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		for ancestor in ancestors:
			if is_same(ancestor, value):
				errors.append("%s contains a recursive container cycle." % label)
				return
		ancestors = ancestors.duplicate(false)
		ancestors.append(value)
	match typeof(value):
		TYPE_DICTIONARY:
			if (value as Dictionary).size() > MAX_COLLECTION_ENTRIES:
				errors.append("%s contains an oversized dictionary." % label)
			for key_value in (value as Dictionary).keys():
				if typeof(key_value) != TYPE_STRING or str(key_value).length() > MAX_TEXT_LENGTH:
					errors.append("%s contains an invalid or oversized dictionary key." % label)
					continue
				_validate_bounded_value(label, (value as Dictionary).get(key_value), depth + 1, counter, ancestors, errors)
		TYPE_ARRAY:
			if (value as Array).size() > MAX_COLLECTION_ENTRIES:
				errors.append("%s contains an oversized array." % label)
			for nested in value as Array:
				_validate_bounded_value(label, nested, depth + 1, counter, ancestors, errors)
		TYPE_STRING:
			if str(value).length() > MAX_TEXT_LENGTH:
				errors.append("%s contains text longer than %d characters." % [label, MAX_TEXT_LENGTH])
		TYPE_FLOAT:
			if is_nan(float(value)) or is_inf(float(value)):
				errors.append("%s contains a non-finite number." % label)
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			pass
		_:
			errors.append("%s contains unsupported Variant type %d." % [label, typeof(value)])


static func _contains_error(errors: Array, needle: String) -> bool:
	for error_value in errors:
		if str(error_value).contains(needle):
			return true
	return false


static func _valid_sha256(value: String) -> bool:
	if value.length() != 64 or value != value.to_lower(): return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102): return false
	return true


static func _valid_semantic_object_id(value: String) -> bool:
	var parts := value.split(":", false)
	if parts.is_empty() or parts.size() > 2: return false
	for part in parts:
		if not _valid_id(str(part)): return false
	return true


static func _validate_tags_and_exceptions(label: String, authored: Dictionary, errors: Array) -> void:
	if _string_array(authored.get("mechanic_tags", [])).is_empty() or str(authored.get("sequence_signature", "")).strip_edges().is_empty():
		errors.append("%s requires mechanic_tags and an authored sequence_signature." % label)
	for exception_value in _array(authored.get("owner_exceptions", [])):
		var exception := _dict(exception_value)
		_append_unknown_keys("%s owner exception" % label, exception, ["row", "reason", "owner", "approved_on"], errors)
		if not ALLOWED_EXCEPTION_ROWS.has(str(exception.get("row", ""))) or str(exception.get("reason", "")).strip_edges().is_empty() or str(exception.get("owner", "")).strip_edges().is_empty() or str(exception.get("approved_on", "")).strip_edges().is_empty():
			errors.append("%s owner exception must name row, reason, owner, and approved_on." % label)


static func _validate_completion_contract(label: String, contract: Dictionary, definition: Dictionary, errors: Array) -> void:
	_append_unknown_keys("%s completion_contract" % label, contract, ALLOWED_EXCEPTION_ROWS, errors)
	var calculated := calculated_completion_contract(definition)
	var exception_rows := _owner_exception_rows(sequence(definition).get("owner_exceptions", []))
	for row_value in ALLOWED_EXCEPTION_ROWS:
		var row := str(row_value)
		var excepted := exception_rows.has(row)
		if (not contract.has(row) or typeof(contract.get(row)) != TYPE_BOOL or not bool(contract.get(row, false))) and not excepted:
			errors.append("%s completion_contract.%s must be explicitly true." % [label, row])
		elif not bool(calculated.get(row, false)) and not excepted:
			errors.append("%s completion_contract.%s is not supported by calculated sequence structure." % [label, row])


static func calculated_completion_contract(definition: Dictionary) -> Dictionary:
	var authored := sequence(definition)
	var graph := _dict(authored.get("phase_graph", {}))
	var phases := _array(graph.get("phases", []))
	var initial := phase(definition, str(graph.get("initial_phase", "")))
	var semantic_changes: Dictionary = {}
	var has_interaction := false
	var has_action := false
	var action_boundaries: Dictionary = {}
	var has_safe_exit := false
	var has_feedback := false
	var has_world_route := false
	var outcomes: Array = []
	for phase_value in phases:
		var phase_data := _dict(phase_value)
		for family in ["scene_ops", "actor_ops"]:
			for operation_value in _array(phase_data.get(family, [])):
				var operation := _dict(operation_value)
				semantic_changes["%s:%s:%s" % [family, str(operation.get("owner_namespace", "")), str(operation.get("stable_object_id", ""))]] = true
		for transition_value in _array(phase_data.get("transition_ops", [])):
			if str(_dict(transition_value).get("op", "")) in ["feedback", "stage", "scene_change"]: has_feedback = true
		for interaction_value in _array(phase_data.get("interaction_ops", [])):
			var operation := _dict(interaction_value)
			var interaction := _dict(operation.get("interaction", {}))
			if str(operation.get("op", "")) in ["add", "replace"] and not interaction.is_empty(): has_interaction = true
			if str(operation.get("op", "")) == "augment": has_interaction = true
			var actions := _array(operation.get("available_actions", interaction.get("available_actions", [])))
			if not actions.is_empty(): has_action = true
			if bool(interaction.get("safe_exit", false)): has_safe_exit = true
		for branch_value in _array(phase_data.get("branches", [])):
			var branch := _dict(branch_value)
			var condition := _dict(branch.get("condition", {}))
			var condition_type := str(condition.get("type", ""))
			if condition_type == "command": action_boundaries["command:%s" % str(condition.get("command_id", ""))] = true
			elif condition_type == "fact": action_boundaries["fact:%s" % str(condition.get("fact_type", ""))] = true
			elif condition_type == "objective": action_boundaries["objective:%s" % str(condition.get("objective_id", ""))] = true
			var outcome := str(branch.get("outcome", ""))
			if not outcome.is_empty() and not outcomes.has(outcome): outcomes.append(outcome)
	for objective_value in _array(authored.get("objectives", [])):
		for step_value in _array(_dict(objective_value).get("steps", [])):
			var step := _dict(step_value)
			var step_kind := str(step.get("kind", ""))
			if step_kind == "command": action_boundaries["command:%s" % str(step.get("command_id", ""))] = true
			elif step_kind == "fact": action_boundaries["fact:%s" % str(step.get("fact_type", ""))] = true
			elif step_kind == "world_boundary": action_boundaries["world_boundary"] = true
	var aftermaths := _dict(authored.get("aftermath", {}))
	var material_aftermath_signatures: Dictionary = {}
	var revisit_feedback_complete := not aftermaths.is_empty()
	for aftermath_value in aftermaths.values():
		var aftermath := _dict(aftermath_value)
		if str(aftermath.get("revisit_feedback", "")).strip_edges().is_empty(): revisit_feedback_complete = false
		var material_effect: Array = []
		for family in ["scene_ops", "actor_ops", "service_ops", "game_ops", "route_ops"]:
			for operation_value in _array(aftermath.get(family, [])):
				var operation := _dict(operation_value)
				material_effect.append(_normalized_operation_feature(family, operation))
				if family in ["scene_ops", "actor_ops"]:
					semantic_changes["%s:%s:%s" % [family, str(operation.get("owner_namespace", "")), str(operation.get("stable_object_id", ""))]] = true
				if family in ["service_ops", "game_ops", "route_ops"]: has_world_route = true
		if not material_effect.is_empty():
			material_effect.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(a) < JSON.stringify(b))
			material_aftermath_signatures[JSON.stringify(material_effect)] = true
	var reentry := _dict(authored.get("reentry_policy", {}))
	var expiry := _dict(authored.get("expiry", {}))
	var all_exit_prompts := not phases.is_empty()
	for phase_value in phases:
		if str(_dict(phase_value).get("exit_prompt", "")).strip_edges().is_empty(): all_exit_prompts = false
	return {
		"arrival_readable": not str(initial.get("arrival_feedback", "")).strip_edges().is_empty() and (not _array(initial.get("scene_ops", [])).is_empty() or not _array(initial.get("actor_ops", [])).is_empty()),
		"semantic_changes": semantic_changes.size() >= 2,
		"scenario_interaction": has_interaction and has_action,
		"action_boundaries": action_boundaries.size() >= 2 and phases.size() >= 3,
		"choice_or_failure": outcomes.size() >= 2,
		"material_outcomes": aftermaths.size() >= 2 and material_aftermath_signatures.size() >= 2,
		"revisit_coverage": reentry.has("partial") and reentry.has("terminal") and reentry.has("expired") and not str(expiry.get("boundary", "")).is_empty() and revisit_feedback_complete,
		"world_connection": has_safe_exit or has_world_route,
		"primary_verb": has_action and not action_boundaries.is_empty(),
		"feedback_and_exit": has_feedback and all_exit_prompts and has_safe_exit,
	}


static func _owner_exception_rows(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	for exception_value in _array(value):
		var exception := _dict(exception_value)
		var row := str(exception.get("row", ""))
		if ALLOWED_EXCEPTION_ROWS.has(row) and not str(exception.get("reason", "")).strip_edges().is_empty() and not str(exception.get("owner", "")).strip_edges().is_empty() and not str(exception.get("approved_on", "")).strip_edges().is_empty():
			result[row] = true
	return result


static func _validate_cross_family_identity_collisions(label: String, authored: Dictionary, errors: Array) -> void:
	var created: Dictionary = {}
	var operation_groups: Array = []
	for phase_value in _array(_dict(authored.get("phase_graph", {})).get("phases", [])):
		var phase_data := _dict(phase_value)
		operation_groups.append_array(_array(phase_data.get("scene_ops", [])))
		operation_groups.append_array(_array(phase_data.get("actor_ops", [])))
	for aftermath_value in _dict(authored.get("aftermath", {})).values():
		var aftermath := _dict(aftermath_value)
		operation_groups.append_array(_array(aftermath.get("scene_ops", [])))
		operation_groups.append_array(_array(aftermath.get("actor_ops", [])))
	for operation_value in operation_groups:
		var operation := _dict(operation_value)
		var family := str(operation.get("family", ""))
		if not ((family == "scene_ops" and str(operation.get("op", "")) == "spawn") or (family == "actor_ops" and str(operation.get("op", "")) == "spawn")):
			continue
		var identity := "%s::%s" % [str(operation.get("owner_namespace", "")), str(operation.get("stable_object_id", ""))]
		if created.has(identity) and str(created.get(identity, "")) != family:
			errors.append("%s reuses semantic identity %s across scene and actor families." % [label, identity])
		else:
			created[identity] = family


static func _validate_fact_subscriptions(label: String, subscriptions: Array, operation_registry: Variant, errors: Array) -> void:
	if subscriptions.size() > MAX_FACT_SUBSCRIPTIONS:
		errors.append("%s exceeds %d fact subscriptions." % [label, MAX_FACT_SUBSCRIPTIONS])
	for subscription_value in subscriptions:
		if typeof(subscription_value) == TYPE_STRING:
			var fact_type := str(subscription_value)
			if fact_type != fact_type.strip_edges() or not FACT_TYPES.has(fact_type):
				errors.append("%s fact subscription references unregistered fact type %s." % [label, fact_type])
			elif fact_type == "event_result":
				errors.append("%s event_result fact subscription requires a dictionary with payload_equals.event_id." % label)
			continue
		if typeof(subscription_value) != TYPE_DICTIONARY:
			errors.append("%s fact subscription must be a fact id or dictionary." % label)
			continue
		var subscription := subscription_value as Dictionary
		_append_unknown_keys("%s fact subscription" % label, subscription, ["fact_type", "payload_equals", "handler", "inputs"], errors)
		var fact_type := str(subscription.get("fact_type", ""))
		if fact_type != fact_type.strip_edges() or not FACT_TYPES.has(fact_type):
			errors.append("%s fact subscription references unregistered fact type %s." % [label, fact_type])
		else:
			_validate_fact_payload_predicate("%s fact subscription" % label, fact_type, subscription.get("payload_equals", {}), errors)
		var handler_id := str(subscription.get("handler", ""))
		var handlers := operation_registry.call("registered_handlers") as Dictionary if operation_registry != null and operation_registry.has_method("registered_handlers") else {}
		if handler_id != handler_id.strip_edges() or (not handler_id.is_empty() and not handlers.has(handler_id)):
			errors.append("%s fact subscription references unregistered handler %s." % [label, handler_id])
		if typeof(subscription.get("inputs", {})) != TYPE_DICTIONARY:
			errors.append("%s fact subscription inputs must be a dictionary." % label)
		elif handler_id.is_empty() and not _dict(subscription.get("inputs", {})).is_empty():
			errors.append("%s fact subscription cannot declare inputs without a handler." % label)
		elif handlers.has(handler_id):
			var inputs := _dict(subscription.get("inputs", {}))
			var expected := _array(_dict(handlers.get(handler_id, {})).get("inputs", []))
			_append_unknown_keys("%s fact subscription inputs" % label, inputs, expected + ["value_from_payload"], errors)
			for input_value in expected:
				var input_id := str(input_value)
				if not inputs.has(input_id) and not (input_id == "value" and inputs.has("value_from_payload")):
					errors.append("%s fact subscription handler %s requires input %s." % [label, handler_id, input_id])


static func _fact_subscription_types(value: Variant) -> Array:
	var result: Array = []
	for subscription_value in _array(value):
		var fact_type := str((subscription_value as Dictionary).get("fact_type", "")) if typeof(subscription_value) == TYPE_DICTIONARY else str(subscription_value)
		fact_type = fact_type.strip_edges()
		if not fact_type.is_empty() and not result.has(fact_type):
			result.append(fact_type)
	result.sort()
	return result


static func _validate_condition(label: String, condition: Dictionary, errors: Array) -> void:
	_append_unknown_keys(label, condition, CONDITION_KEYS, errors)
	var type_id := str(condition.get("type", "")).strip_edges()
	if not CONDITION_TYPES.has(type_id):
		errors.append("%s condition has invalid type %s." % [label, type_id])
		return
	if type_id == "command" and not _valid_id(str(condition.get("command_id", ""))):
		errors.append("%s command condition requires command_id." % label)
	elif type_id == "fact" and not FACT_TYPES.has(str(condition.get("fact_type", "")).strip_edges()):
		errors.append("%s fact condition requires a registered fact_type." % label)
	elif type_id == "fact":
		_validate_fact_payload_predicate(label, str(condition.get("fact_type", "")), condition.get("payload_equals", {}), errors)
	elif ["local_equals", "local_min"].has(type_id) and not _valid_id(str(condition.get("key", ""))):
		errors.append("%s local condition requires key." % label)
	elif type_id == "local_min" and (not condition.has("value") or typeof(condition.get("value")) != TYPE_INT):
		errors.append("%s local_min condition requires an exact integer value." % label)
	elif type_id == "objective" and (not _valid_id(str(condition.get("objective_id", ""))) or not _valid_id(str(condition.get("step_id", "")))):
		errors.append("%s objective condition requires objective_id and step_id." % label)
	elif type_id == "outcome" and not _valid_id(str(condition.get("outcome", ""))):
		errors.append("%s outcome condition requires outcome." % label)
	elif type_id == "receipt":
		var receipt_kind := str(condition.get("receipt_kind", "")).strip_edges()
		var receipt_id := str(condition.get("receipt_id", "")).strip_edges()
		if not RECEIPT_KINDS.has(receipt_kind) or not _valid_receipt_component(receipt_id):
			errors.append("%s receipt condition requires receipt_kind and exact receipt_id." % label)
		elif receipt_kind == "operation":
			if not ["scene_ops", "interaction_ops", "actor_ops", "transition_ops", "service_ops", "game_ops", "route_ops"].has(str(condition.get("family", ""))) or not _valid_boundary_id(str(condition.get("boundary_id", ""))):
				errors.append("%s operation receipt condition requires exact family and boundary_id." % label)


static func _validate_fact_payload_predicate(label: String, fact_type: String, value: Variant, errors: Array) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("%s payload_equals must be a dictionary." % label)
		return
	var predicate := value as Dictionary
	if predicate.size() > 8:
		errors.append("%s payload_equals exceeds 8 fields." % label)
	var allowed := _array(FACT_PREDICATE_FIELDS.get(fact_type, []))
	var field_types := _dict(FACT_PREDICATE_FIELD_TYPES.get(fact_type, {}))
	for key_value in predicate.keys():
		var key := str(key_value)
		if not allowed.has(key):
			errors.append("%s payload_equals references unknown %s field %s." % [label, fact_type, key])
		var expected_type := int(field_types.get(key, -1))
		if expected_type >= 0 and typeof(predicate.get(key_value)) != expected_type:
			errors.append("%s payload_equals.%s has the wrong type for %s." % [label, key, fact_type])
		elif fact_type == "town_transition" and key == "happening_ids" and _string_array(predicate.get(key_value, [])).size() != _array(predicate.get(key_value, [])).size():
			errors.append("%s payload_equals.happening_ids must contain unique stable strings." % label)
		elif not _bounded_predicate_value(predicate.get(key_value)):
			errors.append("%s payload_equals.%s is not a bounded scalar or scalar array." % [label, key])
	if fact_type == "event_result":
		if not predicate.has("event_id") or typeof(predicate.get("event_id")) != TYPE_STRING or str(predicate.get("event_id", "")).strip_edges().is_empty():
			errors.append("%s event_result requires payload_equals.event_id." % label)
		if predicate.has("resolution_id") and (typeof(predicate.get("resolution_id")) != TYPE_STRING or str(predicate.get("resolution_id", "")).strip_edges().is_empty()):
			errors.append("%s event_result payload_equals.resolution_id must be a non-empty string when present." % label)


static func _bounded_predicate_value(value: Variant) -> bool:
	if typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT]:
		return true
	if typeof(value) == TYPE_STRING:
		return not str(value).strip_edges().is_empty() and str(value).length() <= 128
	if typeof(value) != TYPE_ARRAY or (value as Array).size() > 16:
		return false
	for item_value in value as Array:
		if typeof(item_value) not in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
			return false
		if typeof(item_value) == TYPE_STRING and (str(item_value).strip_edges().is_empty() or str(item_value).length() > 128):
			return false
	return true


static func _validate_no_executable_strings(label: String, value: Variant, errors: Array, path: String = "", depth: int = 0, ancestors: Array = []) -> void:
	if depth > MAX_DATA_DEPTH:
		return
	if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		for ancestor in ancestors:
			if is_same(ancestor, value):
				return
		ancestors = ancestors.duplicate(false)
		ancestors.append(value)
	if typeof(value) == TYPE_DICTIONARY:
		for key_value in (value as Dictionary).keys():
			_validate_no_executable_strings(label, (value as Dictionary).get(key_value), errors, "%s.%s" % [path, str(key_value)], depth + 1, ancestors)
	elif typeof(value) == TYPE_ARRAY:
		for index in range((value as Array).size()):
			_validate_no_executable_strings(label, (value as Array)[index], errors, "%s[%d]" % [path, index], depth + 1, ancestors)
	elif typeof(value) == TYPE_STRING:
		var text := str(value)
		if text.begins_with("res://") or text.begins_with("user://") or text.contains("../") or text.contains("/root/") or text.contains("get_node("):
			errors.append("%s contains forbidden executable/resource path at %s." % [label, path])


static func _local_value_matches(type_id: String, value: Variant, field: Dictionary) -> bool:
	match type_id:
		"bool":
			return typeof(value) == TYPE_BOOL
		"int":
			return typeof(value) == TYPE_INT and int(value) >= int(field.get("min", value)) and int(value) <= int(field.get("max", value))
		"float":
			return [TYPE_FLOAT, TYPE_INT].has(typeof(value)) and not is_nan(float(value)) and not is_inf(float(value)) and float(value) >= float(field.get("min", value)) and float(value) <= float(field.get("max", value))
		"string":
			return typeof(value) == TYPE_STRING
		"enum":
			return typeof(value) == TYPE_STRING and _string_array(field.get("values", [])).has(str(value))
		"string_array":
			if typeof(value) != TYPE_ARRAY or not _all_type(value as Array, TYPE_STRING): return false
			var seen: Dictionary = {}
			for item_value in value as Array:
				if str(item_value).is_empty() or str(item_value) != str(item_value).strip_edges() or seen.has(str(item_value)): return false
				seen[str(item_value)] = true
			return true
		"int_array":
			return typeof(value) == TYPE_ARRAY and _all_type(value as Array, TYPE_INT)
	return false


static func _normalized_local_value(type_id: String, value: Variant, field: Dictionary) -> Variant:
	match type_id:
		"bool": return bool(value) if typeof(value) == TYPE_BOOL else bool(field.get("default", false))
		"int":
			var integer_value := int(value) if typeof(value) == TYPE_INT else int(field.get("default", 0))
			return clampi(integer_value, int(field.get("min", integer_value)), int(field.get("max", integer_value)))
		"float":
			var float_value := float(value) if [TYPE_FLOAT, TYPE_INT].has(typeof(value)) else float(field.get("default", 0.0))
			return clampf(float_value, float(field.get("min", float_value)), float(field.get("max", float_value)))
		"string": return str(value) if typeof(value) == TYPE_STRING else str(field.get("default", ""))
		"enum": return str(value) if typeof(value) == TYPE_STRING and _string_array(field.get("values", [])).has(str(value)) else str(field.get("default", ""))
		"string_array": return _string_array(value) if typeof(value) == TYPE_ARRAY else _string_array(field.get("default", []))
		"int_array":
			var result: Array = []
			var source := _array(value) if typeof(value) == TYPE_ARRAY and _all_type(value as Array, TYPE_INT) else _array(field.get("default", []))
			for item in source:
				result.append(int(item))
			return result
	return value


static func _all_type(values: Array, expected: int) -> bool:
	for value in values:
		if typeof(value) != expected:
			return false
	return true


static func _signature_tokens(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	_collect_signature_tokens(_canonical_variant(value), result, "", 0, [])
	return result


static func _collect_signature_tokens(value: Variant, result: Dictionary, path: String, depth: int, ancestors: Array) -> void:
	if depth > MAX_DATA_DEPTH:
		result["%s=<depth-limit>" % path] = true
		return
	if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		for ancestor in ancestors:
			if is_same(ancestor, value):
				result["%s=<cycle>" % path] = true
				return
		ancestors = ancestors.duplicate(false)
		ancestors.append(value)
	if typeof(value) == TYPE_DICTIONARY:
		for key_value in _sorted_keys(value as Dictionary):
			_collect_signature_tokens((value as Dictionary).get(key_value), result, "%s/%s" % [path, str(key_value)], depth + 1, ancestors)
	elif typeof(value) == TYPE_ARRAY:
		for index in range((value as Array).size()):
			_collect_signature_tokens((value as Array)[index], result, "%s/%d" % [path, index], depth + 1, ancestors)
	else:
		result["%s=%s" % [path, str(value)]] = true


static func _canonical_variant(value: Variant) -> Variant:
	return _canonical_variant_inner(value, 0, [])


static func _canonical_variant_inner(value: Variant, depth: int, ancestors: Array) -> Variant:
	if depth > MAX_DATA_DEPTH:
		return "<depth-limit>"
	if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		for ancestor in ancestors:
			if is_same(ancestor, value):
				return "<cycle>"
		ancestors = ancestors.duplicate(false)
		ancestors.append(value)
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		for key_value in _sorted_keys(value as Dictionary):
			result[str(key_value)] = _canonical_variant_inner((value as Dictionary).get(key_value), depth + 1, ancestors)
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for item in value as Array:
			result.append(_canonical_variant_inner(item, depth + 1, ancestors))
		return result
	return value


static func _valid_id(value: String) -> bool:
	var text := value
	if text != text.strip_edges() or text.length() > MAX_TEXT_LENGTH: return false
	if text.is_empty():
		return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and code != 95 and code != 45:
			return false
	return true


static func _canonical_string_values(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY or (value as Array).is_empty(): return false
	var seen: Dictionary = {}
	for item_value in value as Array:
		if typeof(item_value) != TYPE_STRING: return false
		var item := str(item_value)
		if item.is_empty() or item != item.strip_edges() or seen.has(item): return false
		seen[item] = true
	return true


static func _valid_receipt_id(value: String) -> bool:
	var text := value.strip_edges()
	if text.is_empty():
		return false
	var parts := text.split(":", false)
	if parts.size() < 2:
		return false
	for part_value in parts:
		if not _valid_id(str(part_value)):
			return false
	return true


static func _valid_receipt_component(value: String) -> bool:
	var text := value.strip_edges()
	if text.is_empty() or text.length() > MAX_TEXT_LENGTH:
		return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and code != 95 and code != 45 and code != 58:
			return false
	return true


static func _valid_boundary_id(value: String) -> bool:
	var parts := value.strip_edges().split(":", false)
	if parts.size() < 4:
		return false
	for part_value in parts:
		if not _valid_id(str(part_value)):
			return false
	return true


static func _append_unknown_keys(label: String, value: Dictionary, allowed: Array, errors: Array) -> void:
	for key_value in value.keys():
		if not allowed.has(str(key_value)):
			errors.append("%s contains unknown key: %s." % [label, str(key_value)])


static func _sorted_keys(value: Dictionary) -> Array:
	var keys := value.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	return keys


static func _sorted_strings(value: Variant) -> Array:
	var result := _string_array(value)
	result.sort()
	return result


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item_value in value as Array:
		var item := str(item_value).strip_edges()
		if not item.is_empty() and not result.has(item):
			result.append(item)
	return result


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(false) if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(false) if typeof(value) == TYPE_DICTIONARY else {}
