class_name ScenarioSequenceSchema
extends RefCounted

# Data-only contract for authored room sequences. Runtime state is normalized by
# ScenarioSequenceRuntime; this class validates immutable definitions.

const SCHEMA_VERSION := 2
const LOCAL_TYPES := ["bool", "int", "float", "string", "enum", "string_array", "int_array"]
const REENTRY_POLICIES := ["resume", "restart", "aftermath", "expired"]
const EXPIRY_BOUNDARIES := ["none", "leave", "visit_end", "night_end", "town_action"]
const EXPIRY_POLICIES := ["resume", "fail", "ignore", "cancel", "cleanup"]
const OBJECTIVE_OUTCOMES := ["success", "failure", "ignore", "cancel"]
const CONDITION_TYPES := ["always", "command", "fact", "local_equals", "local_min", "objective", "outcome", "receipt"]
const FACT_TYPES := [
	"game_result", "event_result", "service_result", "travel_departed", "travel_arrived",
	"crew_changed", "crew_job_changed", "heat_changed", "heat_band_changed",
	"town_transition", "sweep_changed", "world_boundary", "scenario_command",
]
const ALLOWED_SEQUENCE_KEYS := [
	"schema_version", "local_state_schema", "phase_graph", "objectives",
	"reentry_policy", "expiry", "cleanup", "aftermath", "mechanic_tags",
	"sequence_signature", "owner_exceptions", "fact_subscriptions", "completion_contract",
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
const CONDITION_KEYS := ["type", "command_id", "fact_type", "key", "value", "objective_id", "step_id", "outcome", "receipt_id"]
const OBJECTIVE_KEYS := ["id", "label", "progress_label", "steps", "outcomes"]
const STEP_KEYS := ["id", "label", "kind", "command_id", "fact_type"]
const AFTERMATH_KEYS := ["label", "revisit_feedback", "scene_ops", "interaction_ops", "actor_ops", "service_ops", "game_ops", "route_ops"]


static func sequence(definition: Dictionary) -> Dictionary:
	var value: Variant = definition.get("sequence", {})
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func is_sequence(definition: Dictionary) -> bool:
	return not sequence(definition).is_empty()


static func validate_definition(definition: Dictionary, operation_registry: Variant = null) -> Array:
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
	_validate_local_state_schema(label, _dict(authored.get("local_state_schema", {})), errors)
	_validate_phase_graph(label, _dict(authored.get("phase_graph", {})), operation_registry, errors)
	_validate_objectives(label, _array(authored.get("objectives", [])), errors)
	_validate_reentry_expiry_cleanup(label, authored, operation_registry, errors)
	var reachable_outcomes := _reachable_outcomes(_dict(authored.get("phase_graph", {})))
	_validate_cross_references(label, authored, reachable_outcomes, errors)
	_validate_aftermath(label, _dict(authored.get("aftermath", {})), reachable_outcomes, operation_registry, errors)
	_validate_fact_subscriptions(label, _array(authored.get("fact_subscriptions", [])), operation_registry, errors)
	_validate_tags_and_exceptions(label, authored, errors)
	_validate_completion_contract(label, _dict(authored.get("completion_contract", {})), definition, errors)
	_validate_cross_family_identity_collisions(label, authored, errors)
	_validate_no_executable_strings(label, authored, errors)
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


static func phase_ids(definition: Dictionary) -> Array:
	var result: Array = []
	for phase_value in _array(_dict(sequence(definition).get("phase_graph", {})).get("phases", [])):
		if typeof(phase_value) == TYPE_DICTIONARY:
			var phase_id := str((phase_value as Dictionary).get("id", "")).strip_edges()
			if not phase_id.is_empty() and not result.has(phase_id):
				result.append(phase_id)
	return result


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
			return (phase_value as Dictionary).duplicate(true)
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
		"mechanic_tags": _sorted_strings(authored.get("mechanic_tags", [])),
		"reentry": _canonical_variant(_dict(authored.get("reentry_policy", {}))),
		"expiry": _canonical_variant(_dict(authored.get("expiry", {}))),
	}


static func signature_text(definition: Dictionary) -> String:
	return JSON.stringify(_canonical_variant(normalized_signature(definition)))


static func signature_similarity(left: Dictionary, right: Dictionary) -> float:
	var left_tokens := _signature_tokens(left)
	var right_tokens := _signature_tokens(right)
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


static func catalog_uniqueness_report(definitions: Array, expected_count: int, operation_registry: Variant = null, masked_visual_explanations: Dictionary = {}) -> Dictionary:
	var failures: Array = []
	var warnings: Array = []
	var rows: Array = []
	var dossiers: Array = []
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
		var validation := validate_definition(definition, operation_registry)
		if not validation.is_empty():
			failures.append("scenario %s is invalid: %s" % [scenario_id, JSON.stringify(validation)])
		var authored := sequence(definition)
		var phases := _array(_dict(authored.get("phase_graph", {})).get("phases", []))
		var branch_count := 0
		for phase_value in phases: branch_count += _array(_dict(phase_value).get("branches", [])).size()
		rows.append({"id": scenario_id, "signature": normalized_signature(definition), "nearest_id": "", "nearest_similarity": 0.0})
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
			var similarity := signature_similarity(left_signature, right_signature)
			if similarity > float(left_row.get("nearest_similarity", 0.0)):
				left_row["nearest_similarity"] = similarity
				left_row["nearest_id"] = str(right_row.get("id", ""))
				rows[left_index] = left_row
			if similarity > float(right_row.get("nearest_similarity", 0.0)):
				right_row["nearest_similarity"] = similarity
				right_row["nearest_id"] = str(left_row.get("id", ""))
				rows[right_index] = right_row
			var equal_hash := JSON.stringify(_canonical_variant(left_signature)) == JSON.stringify(_canonical_variant(right_signature))
			var band := uniqueness_band(similarity, equal_hash)
			var pair_ids := [str(left_row.get("id", "")), str(right_row.get("id", ""))]
			pair_ids.sort()
			var pair_key := "%s::%s" % [pair_ids[0], pair_ids[1]]
			var diagnostic := "scenario %s vs %s: %.3f (%s)." % [str(left_row.get("id", "")), str(right_row.get("id", "")), similarity, str(band.get("status", ""))]
			if bool(band.get("blocking", false)):
				failures.append(diagnostic)
			elif str(band.get("status", "")) == "warning":
				if str(masked_visual_explanations.get(pair_key, "")).strip_edges().is_empty():
					failures.append("%s Missing masked visual explanation." % diagnostic)
				else:
					warnings.append(diagnostic)
	rows.sort_custom(func(a: Variant, b: Variant) -> bool: return str((a as Dictionary).get("id", "")) < str((b as Dictionary).get("id", "")))
	dossiers.sort_custom(func(a: Variant, b: Variant) -> bool: return str((a as Dictionary).get("id", "")) < str((b as Dictionary).get("id", "")))
	var expected_comparisons := int(expected_count * (expected_count - 1) / 2)
	if comparison_count != expected_comparisons:
		failures.append("scenario sequence rollout expected %d pairwise comparisons, got %d." % [expected_comparisons, comparison_count])
	return {"ok": failures.is_empty(), "expected_count": expected_count, "actual_count": definitions.size(), "expected_comparison_count": expected_comparisons, "comparison_count": comparison_count, "rows": rows, "dossiers": dossiers, "failures": failures, "warnings": warnings}


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
		if not _valid_id(field_id):
			errors.append("%s local_state_schema has invalid field id: %s." % [label, field_id])
		continue
		var field := _dict(fields.get(field_value, {}))
		_append_unknown_keys("%s local field %s" % [label, field_id], field, ["type", "default", "values", "min", "max"], errors)
		var type_id := str(field.get("type", ""))
		if not LOCAL_TYPES.has(type_id):
			errors.append("%s local field %s has unsupported type %s." % [label, field_id, type_id])
		elif not field.has("default") or not _local_value_matches(type_id, field.get("default"), field):
			errors.append("%s local field %s has an invalid or missing default." % [label, field_id])


static func _validate_phase_graph(label: String, graph: Dictionary, operation_registry: Variant, errors: Array) -> void:
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
		var objective_outcomes := _string_array(objective.get("outcomes", []))
		if objective_outcomes.is_empty():
			errors.append("%s objective %s requires outcomes." % [label, objective_id])
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


static func _validate_aftermath(label: String, aftermaths: Dictionary, reachable_outcomes: Array, operation_registry: Variant, errors: Array) -> void:
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
	for outcome_value in _sorted_keys(aftermaths):
		var outcome_id := str(outcome_value)
		var aftermath := _dict(aftermaths.get(outcome_value, {}))
		_append_unknown_keys("%s aftermath %s" % [label, outcome_id], aftermath, AFTERMATH_KEYS, errors)
		if not _valid_id(outcome_id) or str(aftermath.get("label", "")).strip_edges().is_empty() or str(aftermath.get("revisit_feedback", "")).strip_edges().is_empty():
			errors.append("%s aftermath %s requires valid id, label, and revisit_feedback." % [label, outcome_id])
		var change_count := 0
		for family in ["scene_ops", "interaction_ops", "actor_ops", "service_ops", "game_ops", "route_ops"]:
			var operations := _array(aftermath.get(family, []))
			_validate_operation_receipt_uniqueness("%s aftermath %s %s" % [label, outcome_id, family], operations, errors)
			change_count += operations.size()
			if not operations.is_empty():
				material_axes[family] = true
			for operation_value in operations:
				if typeof(operation_value) == TYPE_DICTIONARY and operation_registry != null and operation_registry.has_method("validate_operation"):
					for operation_error in operation_registry.call("validate_operation", family, operation_value as Dictionary):
						errors.append("%s aftermath %s: %s" % [label, outcome_id, str(operation_error)])
		if change_count <= 0:
			errors.append("%s aftermath %s has no semantic change." % [label, outcome_id])
		var effect_signature := JSON.stringify(_normalized_aftermath_effect(aftermath))
		if effect_signatures.has(effect_signature):
			errors.append("%s aftermath %s duplicates the normalized material effect of %s." % [label, outcome_id, str(effect_signatures.get(effect_signature, ""))])
		else:
			effect_signatures[effect_signature] = outcome_id
	if material_axes.size() < 2:
		errors.append("%s aftermath requires at least two independent material axes." % label)


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


static func _validate_cross_references(label: String, authored: Dictionary, reachable_outcomes: Array, errors: Array) -> void:
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
				authored_receipts[str(_dict(operation_value).get("receipt_id", ""))] = true
	for aftermath_value in _dict(authored.get("aftermath", {})).values():
		var receipt_aftermath := _dict(aftermath_value)
		for family in ["scene_ops", "interaction_ops", "actor_ops", "service_ops", "game_ops", "route_ops"]:
			for operation_value in _array(receipt_aftermath.get(family, [])):
				authored_receipts[str(_dict(operation_value).get("receipt_id", ""))] = true
	for operation_value in _array(_dict(authored.get("cleanup", {})).get("operations", [])):
		authored_receipts[str(_dict(operation_value).get("receipt_id", ""))] = true
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
				_validate_action_refs("%s phase %s action" % [label, phase_id], _dict(action_value), local_ids, objective_steps, errors)
	for subscription_value in _array(authored.get("fact_subscriptions", [])):
		var subscription := _dict(subscription_value)
		if not subscription.is_empty():
			_validate_handler_input_refs("%s fact subscription" % label, str(subscription.get("handler", "")), _dict(subscription.get("inputs", {})), local_ids, objective_steps, errors)
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
			if not local_ids.has(str(condition.get("key", ""))):
				errors.append("%s references unknown local state %s." % [label, str(condition.get("key", ""))])
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
			var receipt_parts := receipt_id.split(":", false)
			if not _valid_receipt_id(receipt_id):
				errors.append("%s requires a stable scoped receipt_id." % label)
			elif receipt_parts.is_empty() or not authored_receipts.has(str(receipt_parts[receipt_parts.size() - 1])):
				errors.append("%s references unknown authored receipt %s." % [label, receipt_id])


static func _validate_action_refs(label: String, action: Dictionary, local_ids: Dictionary, objective_steps: Dictionary, errors: Array) -> void:
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
	_validate_handler_input_refs(label, str(action.get("handler", "")), _dict(action.get("inputs", {})), local_ids, objective_steps, errors)


static func _validate_handler_input_refs(label: String, handler_id: String, inputs: Dictionary, local_ids: Dictionary, objective_steps: Dictionary, errors: Array) -> void:
	if handler_id in ["set_local", "increment_local"] and not local_ids.has(str(inputs.get("key", ""))):
		errors.append("%s handler references unknown local state %s." % [label, str(inputs.get("key", ""))])
	elif handler_id in ["complete_objective_step", "resolve_objective"]:
		var objective_id := str(inputs.get("objective_id", ""))
		if handler_id == "resolve_objective":
			if not objective_steps.has(objective_id) or not OBJECTIVE_OUTCOMES.has(str(inputs.get("outcome", ""))):
				errors.append("%s handler references invalid objective outcome %s/%s." % [label, objective_id, str(inputs.get("outcome", ""))])
		else:
			var step_id := str(inputs.get("step_id", ""))
			if not objective_steps.has(objective_id) or not _dict(objective_steps.get(objective_id, {})).has(step_id):
				errors.append("%s handler references unknown objective step %s/%s." % [label, objective_id, step_id])


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
	var payload := _dict(operation.get("object", operation.get("actor", operation.get("interaction", {}))))
	var result := {
		"family": family,
		"op": str(operation.get("op", "")),
		"mode": str(operation.get("mode", "")),
		"owner": str(operation.get("owner_namespace", "")),
	}
	for key in ["state", "appearance", "behavior", "pose", "enabled", "source_id", "channel", "duration_boundaries"]:
		if operation.has(key):
			result[key] = operation.get(key)
	for key in ["role", "behavior", "enabled", "safe_exit"]:
		if payload.has(key):
			result["payload_%s" % key] = payload.get(key)
	var action_features: Array = []
	for action_value in _array(payload.get("available_actions", operation.get("available_actions", []))):
		var action := _dict(action_value)
		action_features.append({
			"handler": str(action.get("handler", "")),
			"cost_band": 0 if int(action.get("cost", 0)) <= 0 else 1 if int(action.get("cost", 0)) < 10 else 2,
			"objective_preconditions": _array(action.get("requires_objective_steps", [])).size(),
			"local_preconditions": _array(action.get("requires_local", [])).size(),
		})
	action_features.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(a) < JSON.stringify(b))
	if not action_features.is_empty():
		result["actions"] = action_features
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
	_validate_bounded_value(label, value, 0, counter, errors)


static func _validate_bounded_value(label: String, value: Variant, depth: int, counter: Dictionary, errors: Array) -> void:
	counter["count"] = int(counter.get("count", 0)) + 1
	if int(counter.get("count", 0)) > MAX_TOTAL_VALUES:
		if not _contains_error(errors, "total value limit"):
			errors.append("%s exceeds the total value limit." % label)
		return
	if depth > MAX_DATA_DEPTH:
		if not _contains_error(errors, "nesting depth"):
			errors.append("%s exceeds the maximum nesting depth." % label)
		return
	match typeof(value):
		TYPE_DICTIONARY:
			if (value as Dictionary).size() > MAX_COLLECTION_ENTRIES:
				errors.append("%s contains an oversized dictionary." % label)
			for nested in (value as Dictionary).values():
				_validate_bounded_value(label, nested, depth + 1, counter, errors)
		TYPE_ARRAY:
			if (value as Array).size() > MAX_COLLECTION_ENTRIES:
				errors.append("%s contains an oversized array." % label)
			for nested in value as Array:
				_validate_bounded_value(label, nested, depth + 1, counter, errors)
		TYPE_STRING:
			if str(value).length() > MAX_TEXT_LENGTH:
				errors.append("%s contains text longer than %d characters." % [label, MAX_TEXT_LENGTH])
		TYPE_FLOAT:
			if is_nan(float(value)) or is_inf(float(value)):
				errors.append("%s contains a non-finite number." % label)


static func _contains_error(errors: Array, needle: String) -> bool:
	for error_value in errors:
		if str(error_value).contains(needle):
			return true
	return false


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
			var fact_type := str(subscription_value).strip_edges()
			if not FACT_TYPES.has(fact_type):
				errors.append("%s fact subscription references unregistered fact type %s." % [label, fact_type])
			continue
		if typeof(subscription_value) != TYPE_DICTIONARY:
			errors.append("%s fact subscription must be a fact id or dictionary." % label)
			continue
		var subscription := subscription_value as Dictionary
		_append_unknown_keys("%s fact subscription" % label, subscription, ["fact_type", "handler", "inputs"], errors)
		var fact_type := str(subscription.get("fact_type", "")).strip_edges()
		if not FACT_TYPES.has(fact_type):
			errors.append("%s fact subscription references unregistered fact type %s." % [label, fact_type])
		var handler_id := str(subscription.get("handler", "")).strip_edges()
		var handlers := operation_registry.call("registered_handlers") as Dictionary if operation_registry != null and operation_registry.has_method("registered_handlers") else {}
		if not handlers.has(handler_id):
			errors.append("%s fact subscription references unregistered handler %s." % [label, handler_id])
		if typeof(subscription.get("inputs", {})) != TYPE_DICTIONARY:
			errors.append("%s fact subscription inputs must be a dictionary." % label)
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
	elif ["local_equals", "local_min"].has(type_id) and not _valid_id(str(condition.get("key", ""))):
		errors.append("%s local condition requires key." % label)
	elif type_id == "objective" and (not _valid_id(str(condition.get("objective_id", ""))) or not _valid_id(str(condition.get("step_id", "")))):
		errors.append("%s objective condition requires objective_id and step_id." % label)
	elif type_id == "outcome" and not _valid_id(str(condition.get("outcome", ""))):
		errors.append("%s outcome condition requires outcome." % label)
	elif type_id == "receipt" and not _valid_receipt_id(str(condition.get("receipt_id", ""))):
		errors.append("%s receipt condition requires scoped receipt_id." % label)


static func _validate_no_executable_strings(label: String, value: Variant, errors: Array, path: String = "") -> void:
	if typeof(value) == TYPE_DICTIONARY:
		for key_value in (value as Dictionary).keys():
			_validate_no_executable_strings(label, (value as Dictionary).get(key_value), errors, "%s.%s" % [path, str(key_value)])
	elif typeof(value) == TYPE_ARRAY:
		for index in range((value as Array).size()):
			_validate_no_executable_strings(label, (value as Array)[index], errors, "%s[%d]" % [path, index])
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
			return [TYPE_FLOAT, TYPE_INT].has(typeof(value)) and float(value) >= float(field.get("min", value)) and float(value) <= float(field.get("max", value))
		"string":
			return typeof(value) == TYPE_STRING
		"enum":
			return typeof(value) == TYPE_STRING and _string_array(field.get("values", [])).has(str(value))
		"string_array":
			return typeof(value) == TYPE_ARRAY and _all_type(value as Array, TYPE_STRING)
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
	_collect_signature_tokens(_canonical_variant(value), result, "")
	return result


static func _collect_signature_tokens(value: Variant, result: Dictionary, path: String) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		for key_value in _sorted_keys(value as Dictionary):
			_collect_signature_tokens((value as Dictionary).get(key_value), result, "%s/%s" % [path, str(key_value)])
	elif typeof(value) == TYPE_ARRAY:
		for index in range((value as Array).size()):
			_collect_signature_tokens((value as Array)[index], result, "%s/%d" % [path, index])
	else:
		result["%s=%s" % [path, str(value)]] = true


static func _canonical_variant(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		for key_value in _sorted_keys(value as Dictionary):
			result[str(key_value)] = _canonical_variant((value as Dictionary).get(key_value))
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for item in value as Array:
			result.append(_canonical_variant(item))
		return result
	return value


static func _valid_id(value: String) -> bool:
	var text := value.strip_edges()
	if text.is_empty():
		return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and code != 95 and code != 45:
			return false
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
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
