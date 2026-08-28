class_name GameRitualSchema
extends RefCounted

# Closed, data-only validator for the accepted game_ritual/1 contract. The
# validator knows vocabulary shapes only; it never selects a game or rules path.

const CONTRACT := "game_ritual/1"
const MAX_RECORDS := 128
const TOP_LEVEL_KEYS := [
	"contract", "ritual_id", "initial_phase", "ritual_phases",
	"action_declarations", "staged_commitment", "pointer_verbs", "actors",
	"scene_objects", "energy", "game_facts", "ritual_persistence",
	"handler_registry", "declared_targets",
]
const PHASE_KEYS := ["id", "entry_conditions", "permitted_actions", "entry_operations", "transitions", "terminal"]
const TRANSITION_KEYS := ["id", "condition", "next_phase", "operations"]
const ACTION_KEYS := ["action_id", "handler_id", "parameters"]
const POINTER_KEYS := ["id", "verb", "source_region", "target_regions", "bounds", "phases", "accepted_action", "rejection", "rejection_effects", "equivalents"]
const ACTOR_KEYS := ["id", "role", "anchor", "poses", "behavior_states", "initial_pose", "initial_behavior", "fact_reactions"]
const OBJECT_KEYS := ["id", "anchor", "bounds", "z_layer", "visual_states", "functional_states", "initial_visual_state", "initial_functional_state", "hit_regions", "text_safety_regions"]
const OPERATION_KEYS := ["operation_id", "family", "verb", "source_owner_id", "target_id", "arguments"]
const FACT_KEYS := ["fact_type", "fact_version", "boundary", "visibility", "payload"]
const HANDLER_KEYS := ["handler_id", "version", "accepted_actions", "accepted_operations", "inputs", "outputs", "authority", "persisted_state", "transient_state", "rng", "emitted_facts", "rejection"]
const PERSISTENCE_KEYS := ["authoritative_serialized", "derived_projection", "transient_presentation", "one_shot_receipted", "save_boundaries", "restore_policy"]
const TARGET_KEYS := ["anchors", "regions", "sealed_host_targets"]
const SCHEMA_TYPES := ["bool", "int", "float", "string", "qualified_id", "string_array", "int_array"]
const POINTER_VERBS := ["drag", "hold", "flick", "place", "reveal"]
const RETURN_POLICIES := ["none", "return_to_source", "restore_focus"]
const OPERATION_VERBS := {
	"scene_ops": ["spawn", "replace", "remove", "move", "set_position", "set_visibility", "set_enabled", "set_state", "set_appearance"],
	"interaction_ops": ["add", "remove", "replace", "gate", "augment", "retarget"],
	"actor_ops": ["spawn", "despawn", "replace", "set_position", "set_route", "set_pose", "set_behavior"],
	"transition_ops": ["feedback", "stage", "sound", "music", "scene_change"],
}


static func validate_definition(definition: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	_closed(definition, TOP_LEVEL_KEYS, TOP_LEVEL_KEYS, "definition", errors)
	if str(definition.get("contract", "")) != CONTRACT:
		errors.append("definition.contract must be game_ritual/1")
	if not _qualified_id(str(definition.get("ritual_id", ""))):
		errors.append("definition.ritual_id is not a canonical qualified id")
	if _contains_unsafe_value(definition):
		errors.append("definition contains an executable, object, resource, or unsafe path value")

	var actions := _validate_actions(definition.get("action_declarations", []), errors)
	var phases := _validate_phases(definition.get("ritual_phases", []), actions, errors)
	var initial_phase := str(definition.get("initial_phase", ""))
	if not phases.has(initial_phase):
		errors.append("definition.initial_phase does not resolve")
	_validate_phase_reachability(initial_phase, phases, errors)

	var targets := _validate_targets(definition.get("declared_targets", {}), errors)
	var facts := _validate_facts(definition.get("game_facts", []), errors)
	var handlers := _validate_handlers(definition.get("handler_registry", []), actions, facts, errors)
	for action_id in actions.keys():
		var handler_id := str((actions[action_id] as Dictionary).get("handler_id", ""))
		if not handlers.has(handler_id):
			errors.append("action %s references unknown handler %s" % [action_id, handler_id])
	_validate_commitment(definition.get("staged_commitment", {}), actions, errors)
	_validate_pointer_verbs(definition.get("pointer_verbs", []), actions, phases, targets, errors)
	var actors := _validate_actors(definition.get("actors", []), targets, facts, errors)
	var objects := _validate_objects(definition.get("scene_objects", []), targets, errors)
	_validate_energy(definition.get("energy", {}), actors, objects, errors)
	_validate_operations_in_definition(definition, actors, objects, errors)
	_validate_persistence(definition.get("ritual_persistence", {}), errors)
	return errors


static func is_valid(definition: Dictionary) -> bool:
	return validate_definition(definition).is_empty()


static func _validate_actions(value: Variant, errors: Array[String]) -> Dictionary:
	var result := {}
	var records := _records(value, "action_declarations", errors)
	for index in range(records.size()):
		var item: Dictionary = records[index]
		var path := "action_declarations[%d]" % index
		_closed(item, ACTION_KEYS, ACTION_KEYS, path, errors)
		var action_id := str(item.get("action_id", ""))
		if not _qualified_id(action_id):
			errors.append("%s.action_id is invalid" % path)
		elif result.has(action_id):
			errors.append("duplicate action id %s" % action_id)
		else:
			result[action_id] = item
		if not _qualified_id(str(item.get("handler_id", ""))):
			errors.append("%s.handler_id is invalid" % path)
		_validate_type_map(item.get("parameters", {}), "%s.parameters" % path, errors)
	return result


static func _validate_phases(value: Variant, actions: Dictionary, errors: Array[String]) -> Dictionary:
	var result := {}
	var records := _records(value, "ritual_phases", errors)
	if records.is_empty():
		errors.append("ritual_phases must not be empty")
	for index in range(records.size()):
		var phase: Dictionary = records[index]
		var path := "ritual_phases[%d]" % index
		_closed(phase, PHASE_KEYS, PHASE_KEYS, path, errors)
		var phase_id := str(phase.get("id", ""))
		if not _local_id(phase_id):
			errors.append("%s.id is invalid" % path)
		elif result.has(phase_id):
			errors.append("duplicate phase id %s" % phase_id)
		else:
			result[phase_id] = phase
		for action_id in _strings(phase.get("permitted_actions", []), "%s.permitted_actions" % path, errors):
			if not actions.has(action_id):
				errors.append("%s permits undeclared action %s" % [path, action_id])
		for condition in _records(phase.get("entry_conditions", []), "%s.entry_conditions" % path, errors):
			_validate_condition(condition, actions, "%s.entry_condition" % path, errors)
		for transition_index in range(_records(phase.get("transitions", []), "%s.transitions" % path, errors).size()):
			var transition: Dictionary = _records(phase.get("transitions", []), "%s.transitions" % path, errors)[transition_index]
			var transition_path := "%s.transitions[%d]" % [path, transition_index]
			_closed(transition, TRANSITION_KEYS, TRANSITION_KEYS, transition_path, errors)
			if not _local_id(str(transition.get("id", ""))):
				errors.append("%s.id is invalid" % transition_path)
			_validate_condition(transition.get("condition", {}), actions, "%s.condition" % transition_path, errors)
	return result


static func _validate_phase_reachability(initial_phase: String, phases: Dictionary, errors: Array[String]) -> void:
	if not phases.has(initial_phase):
		return
	var seen := {initial_phase: true}
	var pending: Array = [initial_phase]
	while not pending.is_empty():
		var phase_id := str(pending.pop_front())
		var phase: Dictionary = phases[phase_id]
		for transition in _dictionary_array(phase.get("transitions", [])):
			var next_phase := str(transition.get("next_phase", ""))
			if not phases.has(next_phase):
				errors.append("phase %s transitions to unknown phase %s" % [phase_id, next_phase])
			elif not seen.has(next_phase):
				seen[next_phase] = true
				pending.append(next_phase)
	for phase_id in phases.keys():
		if not seen.has(phase_id):
			errors.append("phase %s is unreachable from %s" % [phase_id, initial_phase])


static func _validate_condition(value: Variant, actions: Dictionary, path: String, errors: Array[String]) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("%s must be a condition record" % path)
		return
	var condition: Dictionary = value
	var kind := str(condition.get("kind", ""))
	var allowed := ["kind"]
	match kind:
		"accepted_action":
			allowed.append("action_id")
			if not actions.has(str(condition.get("action_id", ""))):
				errors.append("%s references an undeclared action" % path)
		"fact":
			allowed.append_array(["fact_type", "payload_equals"])
		"receipt_present":
			allowed.append_array(["receipt_kind", "receipt_key", "content_fingerprint"])
			if not _fingerprint(str(condition.get("content_fingerprint", ""))):
				errors.append("%s receipt fingerprint is invalid" % path)
		"authoritative_result_present":
			pass
		"public_state_equals":
			allowed.append_array(["key", "value"])
		_:
			errors.append("%s has unknown condition kind %s" % [path, kind])
	_closed(condition, allowed, allowed, path, errors)


static func _validate_commitment(value: Variant, actions: Dictionary, errors: Array[String]) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("staged_commitment must be a dictionary")
		return
	var item: Dictionary = value
	var keys := ["pending_collection", "working_collection", "resolution_collection", "funds_authority", "actions", "readable_totals"]
	_closed(item, keys, keys, "staged_commitment", errors)
	var required_effects := ["add_or_increment_one", "replace_one_pending_amount", "remove_one_pending_item", "reverse_last_pending_edit", "remove_all_pending_items", "copy_last_eligible_commitment", "copy_eligible_resolved_items", "authorize_pending_set"]
	var effects: Array = []
	for index in range(_records(item.get("actions", []), "staged_commitment.actions", errors).size()):
		var action: Dictionary = _records(item.get("actions", []), "staged_commitment.actions", errors)[index]
		_closed(action, ["id", "effect"], ["id", "effect"], "staged_commitment.actions[%d]" % index, errors)
		if not actions.has(str(action.get("id", ""))):
			errors.append("staged commitment action is undeclared: %s" % str(action.get("id", "")))
		effects.append(str(action.get("effect", "")))
	for effect in required_effects:
		if not effects.has(effect):
			errors.append("staged_commitment is missing effect %s" % effect)
	for total in ["available_funds", "pending_total", "at_risk_total", "returned_stake", "payout", "net_change"]:
		if not _strings(item.get("readable_totals", []), "staged_commitment.readable_totals", errors).has(total):
			errors.append("staged_commitment.readable_totals is missing %s" % total)


static func _validate_pointer_verbs(value: Variant, actions: Dictionary, phases: Dictionary, targets: Dictionary, errors: Array[String]) -> void:
	for index in range(_records(value, "pointer_verbs", errors).size()):
		var pointer: Dictionary = _records(value, "pointer_verbs", errors)[index]
		var path := "pointer_verbs[%d]" % index
		_closed(pointer, POINTER_KEYS, POINTER_KEYS, path, errors)
		if not _local_id(str(pointer.get("id", ""))) or not POINTER_VERBS.has(str(pointer.get("verb", ""))):
			errors.append("%s id or verb is invalid" % path)
		if not targets.get("regions", {}).has(str(pointer.get("source_region", ""))):
			errors.append("%s source_region is unbound" % path)
		for target in _strings(pointer.get("target_regions", []), "%s.target_regions" % path, errors):
			if not targets.get("regions", {}).has(target):
				errors.append("%s target region %s is unbound" % [path, target])
		for phase_id in _strings(pointer.get("phases", []), "%s.phases" % path, errors):
			if not phases.has(phase_id):
				errors.append("%s phase %s is unknown" % [path, phase_id])
		if not actions.has(str(pointer.get("accepted_action", ""))):
			errors.append("%s accepted_action is undeclared" % path)
		if not RETURN_POLICIES.has(str(pointer.get("rejection", ""))):
			errors.append("%s rejection policy is invalid" % path)
		_validate_pointer_bounds(pointer.get("bounds", {}), "%s.bounds" % path, errors)
		_validate_equivalents(pointer.get("equivalents", {}), path, errors)


static func _validate_pointer_bounds(value: Variant, path: String, errors: Array[String]) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("%s must be a dictionary" % path)
		return
	var bounds: Dictionary = value
	_closed(bounds, ["space", "min_distance", "max_distance"], ["space", "min_distance", "max_distance"], path, errors)
	if str(bounds.get("space", "")) != "design" or int(bounds.get("min_distance", -1)) < 0 or int(bounds.get("max_distance", -1)) < int(bounds.get("min_distance", 0)):
		errors.append("%s is not a valid design-space distance range" % path)


static func _validate_equivalents(value: Variant, path: String, errors: Array[String]) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("%s.equivalents must be a dictionary" % path)
		return
	var equivalents: Dictionary = value
	_closed(equivalents, ["keyboard", "controller", "reduced_motion"], ["keyboard", "controller", "reduced_motion"], "%s.equivalents" % path, errors)
	for kind in ["keyboard", "controller", "reduced_motion"]:
		var equivalent: Dictionary = equivalents.get(kind, {}) if typeof(equivalents.get(kind, {})) == TYPE_DICTIONARY else {}
		var keys := ["action_id", "target_selection"]
		if kind == "reduced_motion":
			keys.append("staging")
		_closed(equivalent, keys, keys, "%s.equivalents.%s" % [path, kind], errors)
		if not ["focus", "cycle", "direct_semantic"].has(str(equivalent.get("target_selection", ""))):
			errors.append("%s %s equivalent has invalid target selection" % [path, kind])
		if kind == "reduced_motion" and not ["instant", "short", "authored_text"].has(str(equivalent.get("staging", ""))):
			errors.append("%s reduced-motion staging is invalid" % path)


static func _validate_actors(value: Variant, targets: Dictionary, facts: Dictionary, errors: Array[String]) -> Dictionary:
	var result := {}
	for index in range(_records(value, "actors", errors).size()):
		var actor: Dictionary = _records(value, "actors", errors)[index]
		var path := "actors[%d]" % index
		_closed(actor, ACTOR_KEYS, ACTOR_KEYS, path, errors)
		var actor_id := str(actor.get("id", ""))
		if not _qualified_id(actor_id) or result.has(actor_id):
			errors.append("%s id is invalid or duplicate" % path)
		else:
			result[actor_id] = actor
		if not targets.get("anchors", {}).has(str(actor.get("anchor", ""))):
			errors.append("%s anchor is undeclared" % path)
		var poses := _strings(actor.get("poses", []), "%s.poses" % path, errors)
		var behaviors := _strings(actor.get("behavior_states", []), "%s.behavior_states" % path, errors)
		if poses.is_empty() or not poses.has(str(actor.get("initial_pose", ""))):
			errors.append("%s must declare and select an initial pose" % path)
		if behaviors.is_empty() or not behaviors.has(str(actor.get("initial_behavior", ""))):
			errors.append("%s must declare and select an initial behavior" % path)
		for reaction in _records(actor.get("fact_reactions", []), "%s.fact_reactions" % path, errors):
			_closed(reaction, ["fact_type", "operation_ids"], ["fact_type", "operation_ids"], "%s.fact_reaction" % path, errors)
			if not facts.has(str(reaction.get("fact_type", ""))):
				errors.append("%s reacts to undeclared fact" % path)
	return result


static func _validate_objects(value: Variant, targets: Dictionary, errors: Array[String]) -> Dictionary:
	var result := {}
	for index in range(_records(value, "scene_objects", errors).size()):
		var object: Dictionary = _records(value, "scene_objects", errors)[index]
		var path := "scene_objects[%d]" % index
		_closed(object, OBJECT_KEYS, OBJECT_KEYS, path, errors)
		var object_id := str(object.get("id", ""))
		if not _qualified_id(object_id) or result.has(object_id):
			errors.append("%s id is invalid or duplicate" % path)
		else:
			result[object_id] = object
		if not targets.get("anchors", {}).has(str(object.get("anchor", ""))):
			errors.append("%s anchor is undeclared" % path)
		_validate_rect(object.get("bounds", {}), "%s.bounds" % path, errors)
		var visual := _strings(object.get("visual_states", []), "%s.visual_states" % path, errors)
		var functional := _strings(object.get("functional_states", []), "%s.functional_states" % path, errors)
		if visual.is_empty() or not visual.has(str(object.get("initial_visual_state", ""))):
			errors.append("%s initial visual state is undeclared" % path)
		if functional.is_empty() or not functional.has(str(object.get("initial_functional_state", ""))):
			errors.append("%s initial functional state is undeclared" % path)
		for hit in _records(object.get("hit_regions", []), "%s.hit_regions" % path, errors):
			_closed(hit, ["id", "bounds", "minimum_touch_target"], ["id", "bounds", "minimum_touch_target"], "%s.hit_region" % path, errors)
			_validate_rect(hit.get("bounds", {}), "%s.hit_region.bounds" % path, errors)
			if int(hit.get("minimum_touch_target", 0)) < 1:
				errors.append("%s has an unreachable touch target" % path)
		for region in _records(object.get("text_safety_regions", []), "%s.text_safety_regions" % path, errors):
			_closed(region, ["id", "bounds"], ["id", "bounds"], "%s.text_safety_region" % path, errors)
			_validate_rect(region.get("bounds", {}), "%s.text_safety_region.bounds" % path, errors)
	return result


static func _validate_energy(value: Variant, actors: Dictionary, objects: Dictionary, errors: Array[String]) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("energy must be a dictionary")
		return
	var energy: Dictionary = value
	_closed(energy, ["initial_tier", "tiers"], ["initial_tier", "tiers"], "energy", errors)
	var tier_ids: Array = []
	for index in range(_records(energy.get("tiers", []), "energy.tiers", errors).size()):
		var tier: Dictionary = _records(energy.get("tiers", []), "energy.tiers", errors)[index]
		var path := "energy.tiers[%d]" % index
		var keys := ["id", "actor_operations", "object_operations", "interaction_operations", "audio_cues"]
		_closed(tier, keys, keys, path, errors)
		var tier_id := str(tier.get("id", ""))
		tier_ids.append(tier_id)
		var actor_ops := _records(tier.get("actor_operations", []), "%s.actor_operations" % path, errors)
		var object_ops := _records(tier.get("object_operations", []), "%s.object_operations" % path, errors)
		var interaction_ops := _records(tier.get("interaction_operations", []), "%s.interaction_operations" % path, errors)
		if actor_ops.is_empty() and object_ops.is_empty() and interaction_ops.is_empty():
			errors.append("%s changes only music/text; an actor, object, or interactable change is required" % path)
	if not tier_ids.has(str(energy.get("initial_tier", ""))):
		errors.append("energy.initial_tier is undeclared")


static func _validate_facts(value: Variant, errors: Array[String]) -> Dictionary:
	var result := {}
	for index in range(_records(value, "game_facts", errors).size()):
		var fact: Dictionary = _records(value, "game_facts", errors)[index]
		var path := "game_facts[%d]" % index
		_closed(fact, FACT_KEYS, FACT_KEYS, path, errors)
		var fact_type := str(fact.get("fact_type", ""))
		if not _qualified_id(fact_type) or result.has(fact_type):
			errors.append("%s fact_type is invalid or duplicate" % path)
		else:
			result[fact_type] = fact
		if int(fact.get("fact_version", 0)) < 1 or str(fact.get("boundary", "")) != "action" or str(fact.get("visibility", "")) != "public":
			errors.append("%s must be a positive-version public action-boundary fact" % path)
		_validate_type_map(fact.get("payload", {}), "%s.payload" % path, errors)
	return result


static func _validate_handlers(value: Variant, actions: Dictionary, facts: Dictionary, errors: Array[String]) -> Dictionary:
	var result := {}
	for index in range(_records(value, "handler_registry", errors).size()):
		var handler: Dictionary = _records(value, "handler_registry", errors)[index]
		var path := "handler_registry[%d]" % index
		_closed(handler, HANDLER_KEYS, HANDLER_KEYS, path, errors)
		var handler_id := str(handler.get("handler_id", ""))
		if not _qualified_id(handler_id) or result.has(handler_id):
			errors.append("%s handler_id is invalid or duplicate" % path)
		else:
			result[handler_id] = handler
		if int(handler.get("version", 0)) < 1:
			errors.append("%s version must be positive" % path)
		for action_id in _strings(handler.get("accepted_actions", []), "%s.accepted_actions" % path, errors):
			if not actions.has(action_id):
				errors.append("%s accepts undeclared action %s" % [path, action_id])
		for fact_type in _strings(handler.get("emitted_facts", []), "%s.emitted_facts" % path, errors):
			if not facts.has(fact_type):
				errors.append("%s emits undeclared fact %s" % [path, fact_type])
		_validate_type_map(handler.get("inputs", {}), "%s.inputs" % path, errors)
		_validate_type_map(handler.get("outputs", {}), "%s.outputs" % path, errors)
		var rng: Dictionary = handler.get("rng", {}) if typeof(handler.get("rng", {})) == TYPE_DICTIONARY else {}
		_closed(rng, ["owner", "stream", "consumption"], ["owner", "stream", "consumption"], "%s.rng" % path, errors)
	return result


static func _validate_targets(value: Variant, errors: Array[String]) -> Dictionary:
	var result := {"anchors": {}, "regions": {}, "sealed_host_targets": {}}
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("declared_targets must be a dictionary")
		return result
	var targets: Dictionary = value
	_closed(targets, TARGET_KEYS, TARGET_KEYS, "declared_targets", errors)
	for kind in TARGET_KEYS:
		for item in _strings(targets.get(kind, []), "declared_targets.%s" % kind, errors):
			if not _qualified_id(item):
				errors.append("declared target %s is invalid" % item)
			else:
				result[kind][item] = true
	return result


static func _validate_operations_in_definition(definition: Dictionary, actors: Dictionary, objects: Dictionary, errors: Array[String]) -> void:
	var operations: Array = []
	for phase in _dictionary_array(definition.get("ritual_phases", [])):
		operations.append_array(_dictionary_array(phase.get("entry_operations", [])))
		for transition in _dictionary_array(phase.get("transitions", [])):
			operations.append_array(_dictionary_array(transition.get("operations", [])))
	var energy: Dictionary = definition.get("energy", {}) if typeof(definition.get("energy", {})) == TYPE_DICTIONARY else {}
	for tier in _dictionary_array(energy.get("tiers", [])):
		for key in ["actor_operations", "object_operations", "interaction_operations"]:
			operations.append_array(_dictionary_array(tier.get(key, [])))
	var ids := {}
	for index in range(operations.size()):
		var operation: Dictionary = operations[index]
		var path := "operation[%d]" % index
		_closed(operation, OPERATION_KEYS, OPERATION_KEYS, path, errors)
		var operation_id := str(operation.get("operation_id", ""))
		if not _local_id(operation_id):
			errors.append("%s operation_id is invalid" % path)
		elif ids.has(operation_id) and JSON.stringify(ids[operation_id], "", true) != JSON.stringify(operation, "", true):
			errors.append("operation id %s has conflicting definitions" % operation_id)
		else:
			ids[operation_id] = operation
		var family := str(operation.get("family", ""))
		var verb := str(operation.get("verb", ""))
		if not OPERATION_VERBS.has(family) or not (OPERATION_VERBS.get(family, []) as Array).has(verb):
			errors.append("%s uses unregistered operation %s.%s" % [path, family, verb])
		var target_id := str(operation.get("target_id", ""))
		if family == "actor_ops" and not actors.has(target_id):
			errors.append("%s actor target is unknown" % path)
		if family == "scene_ops" and not objects.has(target_id):
			errors.append("%s object target is unknown" % path)


static func _validate_persistence(value: Variant, errors: Array[String]) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("ritual_persistence must be a dictionary")
		return
	var persistence: Dictionary = value
	_closed(persistence, PERSISTENCE_KEYS, PERSISTENCE_KEYS, "ritual_persistence", errors)
	if str(persistence.get("restore_policy", "")) != "restore_legal_phase_without_replay":
		errors.append("ritual_persistence.restore_policy is invalid")
	if not _strings(persistence.get("save_boundaries", []), "ritual_persistence.save_boundaries", errors).has("action"):
		errors.append("ritual persistence must save at action boundaries")


static func _validate_type_map(value: Variant, path: String, errors: Array[String]) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("%s must be a schema map" % path)
		return
	for key in (value as Dictionary).keys():
		if not _local_id(str(key)) or not SCHEMA_TYPES.has(str((value as Dictionary)[key])):
			errors.append("%s contains invalid field/type %s=%s" % [path, key, (value as Dictionary)[key]])


static func _validate_rect(value: Variant, path: String, errors: Array[String]) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("%s must be a design rectangle" % path)
		return
	var rect: Dictionary = value
	_closed(rect, ["space", "x", "y", "w", "h"], ["space", "x", "y", "w", "h"], path, errors)
	if str(rect.get("space", "")) != "design" or int(rect.get("x", -1)) < 0 or int(rect.get("y", -1)) < 0 or int(rect.get("w", 0)) <= 0 or int(rect.get("h", 0)) <= 0:
		errors.append("%s must be a positive in-canvas design rectangle" % path)


static func _closed(value: Dictionary, allowed: Array, required: Array, path: String, errors: Array[String]) -> void:
	for key in value.keys():
		if not allowed.has(str(key)):
			errors.append("%s has unknown field %s" % [path, key])
	for key in required:
		if not value.has(key):
			errors.append("%s is missing field %s" % [path, key])


static func _records(value: Variant, path: String, errors: Array[String]) -> Array:
	if typeof(value) != TYPE_ARRAY:
		errors.append("%s must be an array" % path)
		return []
	if (value as Array).size() > MAX_RECORDS:
		errors.append("%s exceeds the bounded record limit" % path)
	return _dictionary_array(value)


static func _strings(value: Variant, path: String, errors: Array[String]) -> Array:
	if typeof(value) != TYPE_ARRAY:
		errors.append("%s must be an array" % path)
		return []
	var result: Array = []
	for item in value:
		if typeof(item) != TYPE_STRING:
			errors.append("%s must contain strings only" % path)
		else:
			result.append(str(item))
	return result


static func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for item in value:
			if typeof(item) == TYPE_DICTIONARY:
				result.append(item as Dictionary)
	return result


static func _local_id(value: String) -> bool:
	if value.is_empty() or value.length() > 64:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if index == 0:
			if code < 97 or code > 122:
				return false
		elif not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and code != 95:
			return false
	return true


static func _qualified_id(value: String) -> bool:
	if value.is_empty() or value.length() > 192:
		return false
	for atom in value.split(".", false):
		if not _local_id(atom):
			return false
	return true


static func _fingerprint(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return false
	return true


static func _contains_unsafe_value(value: Variant) -> bool:
	var type := typeof(value)
	if type == TYPE_OBJECT or type == TYPE_CALLABLE or type == TYPE_SIGNAL:
		return true
	if type == TYPE_STRING:
		var text := str(value).to_lower()
		return text.begins_with("res://") or text.begins_with("user://") or text.contains("/root/") or text.contains("\\")
	if type == TYPE_DICTIONARY:
		for key in (value as Dictionary).keys():
			if _contains_unsafe_value((value as Dictionary)[key]):
				return true
	if type == TYPE_ARRAY:
		for item in value:
			if _contains_unsafe_value(item):
				return true
	return false
