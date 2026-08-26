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
	"sequence_signature", "owner_exceptions", "fact_subscriptions",
]
const ALLOWED_EXCEPTION_ROWS := [
	"arrival_readable", "semantic_changes", "scenario_interaction", "action_boundaries",
	"choice_or_failure", "material_outcomes", "revisit_coverage", "world_connection",
	"primary_verb", "feedback_and_exit",
]


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
	_validate_local_state_schema(label, _dict(authored.get("local_state_schema", {})), errors)
	_validate_phase_graph(label, _dict(authored.get("phase_graph", {})), operation_registry, errors)
	_validate_objectives(label, _array(authored.get("objectives", [])), errors)
	_validate_reentry_expiry_cleanup(label, authored, operation_registry, errors)
	_validate_aftermath(label, _dict(authored.get("aftermath", {})), operation_registry, errors)
	_validate_fact_subscriptions(label, _array(authored.get("fact_subscriptions", [])), operation_registry, errors)
	_validate_tags_and_exceptions(label, authored, errors)
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
		if typeof(phase_value) != TYPE_DICTIONARY:
			continue
		var phase_data := phase_value as Dictionary
		var op_features: Array = []
		for family in ["scene_ops", "interaction_ops", "actor_ops", "transition_ops"]:
			for op_value in _array(phase_data.get(family, [])):
				if typeof(op_value) == TYPE_DICTIONARY:
					var op := op_value as Dictionary
					op_features.append("%s:%s:%s" % [family, str(op.get("op", "")), str(op.get("role", op.get("channel", "")))])
		op_features.sort()
		var branches: Array = []
		for branch_value in _array(phase_data.get("branches", [])):
			if typeof(branch_value) != TYPE_DICTIONARY:
				continue
			var branch := branch_value as Dictionary
			var condition := _dict(branch.get("condition", {}))
			branches.append("%s:%s:%s" % [str(condition.get("type", "")), str(condition.get("command_id", condition.get("fact_type", ""))), str(branch.get("outcome", "phase" if not str(branch.get("next_phase", "")).is_empty() else "terminal"))])
		branches.sort()
		phase_features.append({
			"ops": op_features,
			"branches": branches,
			"objective_count": _string_array(phase_data.get("objective_ids", [])).size(),
			"terminal": bool(phase_data.get("terminal", false)),
			"action_boundary": maxi(0, int(phase_data.get("advance_after_actions", 0))) > 0,
		})
	var objective_features: Array = []
	for objective_value in _array(authored.get("objectives", [])):
		if typeof(objective_value) != TYPE_DICTIONARY:
			continue
		var objective := objective_value as Dictionary
		var steps: Array = []
		for step_value in _array(objective.get("steps", [])):
			if typeof(step_value) == TYPE_DICTIONARY:
				var step := step_value as Dictionary
				steps.append("%s:%s" % [str(step.get("kind", "")), str(step.get("command_id", step.get("fact_type", "")))])
		objective_features.append({"steps": steps, "outcomes": _string_array(objective.get("outcomes", [])).size()})
	var aftermath_domains: Array = []
	for outcome_value in _sorted_keys(_dict(authored.get("aftermath", {}))):
		var aftermath := _dict(_dict(authored.get("aftermath", {})).get(outcome_value, {}))
		var domains: Array = []
		for domain in ["scene_ops", "interaction_ops", "actor_ops", "service_ops", "game_ops", "route_ops"]:
			if not _array(aftermath.get(domain, [])).is_empty():
				domains.append(domain)
		aftermath_domains.append(domains)
	return {
		"phase_count": phase_features.size(),
		"phases": phase_features,
		"objectives": objective_features,
		"aftermath_domains": aftermath_domains,
		"fact_types": _fact_subscription_types(authored.get("fact_subscriptions", [])),
		"mechanic_tags": _sorted_strings(authored.get("mechanic_tags", [])),
		"reentry": str(_dict(authored.get("reentry_policy", {})).get("partial", "")),
		"expiry": str(_dict(authored.get("expiry", {})).get("boundary", "")),
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


static func _validate_local_state_schema(label: String, fields: Dictionary, errors: Array) -> void:
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
	var ids: Dictionary = {}
	for phase_value in phases:
		if typeof(phase_value) != TYPE_DICTIONARY:
			errors.append("%s phase must be a dictionary." % label)
			continue
		var phase_data := phase_value as Dictionary
		var phase_id := str(phase_data.get("id", "")).strip_edges()
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
			for operation_value in _array(phase_data.get(family, [])):
				if typeof(operation_value) != TYPE_DICTIONARY:
					errors.append("%s phase %s %s entry must be a dictionary." % [label, phase_id, family])
				elif operation_registry != null and operation_registry.has_method("validate_operation"):
					for operation_error in operation_registry.call("validate_operation", family, operation_value as Dictionary):
						errors.append("%s phase %s: %s" % [label, phase_id, str(operation_error)])
		for branch_value in _array(phase_data.get("branches", [])):
			if typeof(branch_value) != TYPE_DICTIONARY:
				errors.append("%s phase %s branch must be a dictionary." % [label, phase_id])
				continue
			var branch := branch_value as Dictionary
			if not _valid_id(str(branch.get("id", ""))):
				errors.append("%s phase %s has invalid branch id." % [label, phase_id])
			_validate_condition("%s phase %s branch" % [label, phase_id], _dict(branch.get("condition", {})), errors)
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
	_validate_reachability(label, initial_id, phases, ids, errors)


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


static func _validate_objectives(label: String, objectives: Array, errors: Array) -> void:
	var ids: Dictionary = {}
	for objective_value in objectives:
		if typeof(objective_value) != TYPE_DICTIONARY:
			errors.append("%s objective must be a dictionary." % label)
			continue
		var objective := objective_value as Dictionary
		var objective_id := str(objective.get("id", "")).strip_edges()
		if not _valid_id(objective_id) or ids.has(objective_id):
			errors.append("%s has invalid or duplicate objective id %s." % [label, objective_id])
		else:
			ids[objective_id] = true
		if str(objective.get("label", "")).strip_edges().is_empty() or str(objective.get("progress_label", "")).strip_edges().is_empty():
			errors.append("%s objective %s requires public label and progress_label." % [label, objective_id])
		var steps := _array(objective.get("steps", []))
		if steps.is_empty():
			errors.append("%s objective %s requires at least one step." % [label, objective_id])
		var step_ids: Dictionary = {}
		for step_value in steps:
			var step := _dict(step_value)
			var step_id := str(step.get("id", "")).strip_edges()
			if not _valid_id(step_id) or step_ids.has(step_id) or str(step.get("label", "")).strip_edges().is_empty():
				errors.append("%s objective %s has invalid/duplicate/unlabeled step %s." % [label, objective_id, step_id])
			step_ids[step_id] = true
			if not ["command", "fact", "world_boundary"].has(str(step.get("kind", ""))):
				errors.append("%s objective %s step %s has invalid kind." % [label, objective_id, step_id])
		for outcome_value in _string_array(objective.get("outcomes", [])):
			if not OBJECTIVE_OUTCOMES.has(str(outcome_value)):
				errors.append("%s objective %s has invalid outcome %s." % [label, objective_id, str(outcome_value)])


static func _validate_reentry_expiry_cleanup(label: String, authored: Dictionary, operation_registry: Variant, errors: Array) -> void:
	var reentry := _dict(authored.get("reentry_policy", {}))
	for key in ["partial", "terminal", "expired"]:
		if not REENTRY_POLICIES.has(str(reentry.get(key, ""))):
			errors.append("%s reentry_policy.%s is invalid." % [label, key])
	var expiry := _dict(authored.get("expiry", {}))
	if not EXPIRY_BOUNDARIES.has(str(expiry.get("boundary", ""))) or not EXPIRY_POLICIES.has(str(expiry.get("policy", ""))):
		errors.append("%s expiry requires a registered boundary and policy." % label)
	if int(expiry.get("after", 0)) < 0:
		errors.append("%s expiry.after must be non-negative." % label)
	var cleanup := _dict(authored.get("cleanup", {}))
	if cleanup.is_empty() or _array(cleanup.get("operations", [])).is_empty():
		errors.append("%s cleanup must declare operations." % label)
	for operation_value in _array(cleanup.get("operations", [])):
		if typeof(operation_value) != TYPE_DICTIONARY:
			errors.append("%s cleanup operation must be a dictionary." % label)
		elif operation_registry != null and operation_registry.has_method("validate_any_operation"):
			for operation_error in operation_registry.call("validate_any_operation", operation_value as Dictionary):
				errors.append("%s cleanup: %s" % [label, str(operation_error)])


static func _validate_aftermath(label: String, aftermaths: Dictionary, operation_registry: Variant, errors: Array) -> void:
	if aftermaths.size() < 2:
		errors.append("%s aftermath must define at least two material outcomes." % label)
	for outcome_value in _sorted_keys(aftermaths):
		var outcome_id := str(outcome_value)
		var aftermath := _dict(aftermaths.get(outcome_value, {}))
		if not _valid_id(outcome_id) or str(aftermath.get("label", "")).strip_edges().is_empty() or str(aftermath.get("revisit_feedback", "")).strip_edges().is_empty():
			errors.append("%s aftermath %s requires valid id, label, and revisit_feedback." % [label, outcome_id])
		var change_count := 0
		for family in ["scene_ops", "interaction_ops", "actor_ops", "service_ops", "game_ops", "route_ops"]:
			change_count += _array(aftermath.get(family, [])).size()
			for operation_value in _array(aftermath.get(family, [])):
				if typeof(operation_value) == TYPE_DICTIONARY and operation_registry != null and operation_registry.has_method("validate_operation"):
					for operation_error in operation_registry.call("validate_operation", family, operation_value as Dictionary):
						errors.append("%s aftermath %s: %s" % [label, outcome_id, str(operation_error)])
		if change_count <= 0:
			errors.append("%s aftermath %s has no semantic change." % [label, outcome_id])


static func _validate_tags_and_exceptions(label: String, authored: Dictionary, errors: Array) -> void:
	if _string_array(authored.get("mechanic_tags", [])).is_empty() or str(authored.get("sequence_signature", "")).strip_edges().is_empty():
		errors.append("%s requires mechanic_tags and an authored sequence_signature." % label)
	for exception_value in _array(authored.get("owner_exceptions", [])):
		var exception := _dict(exception_value)
		_append_unknown_keys("%s owner exception" % label, exception, ["row", "reason", "owner", "approved_on"], errors)
		if not ALLOWED_EXCEPTION_ROWS.has(str(exception.get("row", ""))) or str(exception.get("reason", "")).strip_edges().is_empty() or str(exception.get("owner", "")).strip_edges().is_empty() or str(exception.get("approved_on", "")).strip_edges().is_empty():
			errors.append("%s owner exception must name row, reason, owner, and approved_on." % label)


static func _validate_fact_subscriptions(label: String, subscriptions: Array, operation_registry: Variant, errors: Array) -> void:
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
		if operation_registry == null or not operation_registry.has_method("registered_handlers") or not (operation_registry.call("registered_handlers") as Dictionary).has(handler_id):
			errors.append("%s fact subscription references unregistered handler %s." % [label, handler_id])
		if typeof(subscription.get("inputs", {})) != TYPE_DICTIONARY:
			errors.append("%s fact subscription inputs must be a dictionary." % label)


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
