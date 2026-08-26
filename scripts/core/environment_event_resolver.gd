class_name EnvironmentEventResolver
extends RefCounted

# Single authority for environment event candidate filtering and selection.
# Catalog analysis and EnvironmentInstance generation both consume this code so
# interaction modes, scopes, required ids, count ranges, and unique-class
# priority/order cannot drift between authorization and runtime materialization.


static func candidate_ids(archetype: Dictionary, event_definitions: Array) -> Array:
	var pool := _string_array(archetype.get("event_pool", []))
	if event_definitions.is_empty():
		return pool
	var scopes := _string_array(archetype.get("event_scopes", []))
	var result: Array = []
	for definition_value in event_definitions:
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition := definition_value as Dictionary
		var event_id := str(definition.get("id", "")).strip_edges()
		if event_id.is_empty() or result.has(event_id):
			continue
		if str(definition.get("interaction_mode", "interactable")) != "interactable":
			continue
		if not pool.is_empty() and not pool.has(event_id):
			continue
		if _event_fits(definition, scopes):
			result.append(event_id)
	return result


static func select_ids(archetype: Dictionary, event_definitions: Array, rng: Variant) -> Array:
	var candidates := candidate_ids(archetype, event_definitions)
	var required := _required_ids(archetype, candidates)
	var count := _count(archetype.get("event_count", 1), rng)
	var picked := _pick_ids_with_required(candidates, count, required, rng)
	var resolved := _filter_unique_event_ids(picked, event_definitions)
	return rng.pick_many(resolved, resolved.size())


# Exact membership envelope over every selection permitted by the authored
# count range. Order-only final shuffling is deliberately excluded.
static func selection_contract(archetype: Dictionary, event_definitions: Array) -> Dictionary:
	var candidates := candidate_ids(archetype, event_definitions)
	var required := _required_ids(archetype, candidates)
	var optional: Array = []
	for event_id in candidates:
		if not required.has(event_id):
			optional.append(event_id)
	var count_bounds := _count_bounds(archetype.get("event_count", 1))
	var minimum_selected := mini(candidates.size(), maxi(int(count_bounds[0]), required.size()))
	var maximum_selected := mini(candidates.size(), maxi(int(count_bounds[1]), required.size()))
	var minimum_optional := maxi(0, minimum_selected - required.size())
	var maximum_optional := maxi(0, maximum_selected - required.size())
	var definitions_by_id := _definitions_by_id(event_definitions)
	var candidate_indexes: Dictionary = {}
	for index in range(candidates.size()):
		candidate_indexes[str(candidates[index])] = index
	var possible: Array = []
	var guaranteed: Array = []
	for event_id_value in candidates:
		var event_id := str(event_id_value)
		var blockers := _unique_class_blockers(event_id, candidates, definitions_by_id, candidate_indexes)
		var required_blocker := false
		var optional_blockers: Array = []
		for blocker_id in blockers:
			if required.has(blocker_id):
				required_blocker = true
			else:
				optional_blockers.append(blocker_id)
		var event_required := required.has(event_id)
		var non_blocking_optional_count := optional.size() - optional_blockers.size()
		if not event_required and optional.has(event_id) and not optional_blockers.has(event_id):
			non_blocking_optional_count -= 1
		var can_select_without_blocker := false
		if not required_blocker:
			for optional_count in range(minimum_optional, maximum_optional + 1):
				if event_required and optional_count <= non_blocking_optional_count:
					can_select_without_blocker = true
					break
				if not event_required and optional_count >= 1 and optional_count - 1 <= non_blocking_optional_count:
					can_select_without_blocker = true
					break
		if can_select_without_blocker:
			possible.append(event_id)
		var event_selected_in_every_outcome := event_required or minimum_optional >= optional.size()
		var blocker_selected_in_any_outcome := required_blocker or not optional_blockers.is_empty() and maximum_optional > 0
		if event_selected_in_every_outcome and not blocker_selected_in_any_outcome:
			guaranteed.append(event_id)
	possible.sort()
	guaranteed.sort()
	return {
		"candidates": candidates.duplicate(),
		"required": required.duplicate(),
		"possible": possible,
		"guaranteed": guaranteed,
		"minimum_selected_count": minimum_selected,
		"maximum_selected_count": maximum_selected,
	}


static func _required_ids(archetype: Dictionary, candidates: Array) -> Array:
	var result: Array = []
	for required_id in _string_array(archetype.get("required_event_ids", [])):
		if candidates.has(required_id) and not result.has(required_id):
			result.append(required_id)
	return result


static func _pick_ids_with_required(candidates: Array, count: int, required: Array, rng: Variant) -> Array:
	var selected_count := maxi(count, required.size())
	var remaining: Array = []
	for event_id in candidates:
		if not required.has(event_id):
			remaining.append(event_id)
	var picks: Array = rng.pick_many(remaining, maxi(0, selected_count - required.size()))
	var selected: Dictionary = {}
	for event_id in required:
		selected[str(event_id)] = true
	for event_id in picks:
		selected[str(event_id)] = true
	var result: Array = []
	for event_id in candidates:
		if bool(selected.get(str(event_id), false)):
			result.append(event_id)
	return result


static func _filter_unique_event_ids(event_ids: Array, event_definitions: Array) -> Array:
	var definitions_by_id := _definitions_by_id(event_definitions)
	var result: Array = []
	var class_indexes: Dictionary = {}
	for event_id_value in event_ids:
		var event_id := str(event_id_value).strip_edges()
		if event_id.is_empty():
			continue
		var definition := _dict(definitions_by_id.get(event_id, {}))
		var unique_class := str(definition.get("unique_object_class", "")).strip_edges()
		if unique_class.is_empty() or bool(definition.get("allow_duplicate_unique_class", false)):
			result.append(event_id)
			continue
		if not class_indexes.has(unique_class):
			class_indexes[unique_class] = result.size()
			result.append(event_id)
			continue
		var existing_index := int(class_indexes.get(unique_class, -1))
		var existing := _dict(definitions_by_id.get(str(result[existing_index]), {}))
		if int(definition.get("unique_object_priority", 0)) > int(existing.get("unique_object_priority", 0)):
			result[existing_index] = event_id
	return result


static func _unique_class_blockers(event_id: String, candidates: Array, definitions_by_id: Dictionary, candidate_indexes: Dictionary) -> Array:
	var definition := _dict(definitions_by_id.get(event_id, {}))
	var unique_class := str(definition.get("unique_object_class", "")).strip_edges()
	if unique_class.is_empty() or bool(definition.get("allow_duplicate_unique_class", false)):
		return []
	var priority := int(definition.get("unique_object_priority", 0))
	var event_index := int(candidate_indexes.get(event_id, -1))
	var result: Array = []
	for candidate_id_value in candidates:
		var candidate_id := str(candidate_id_value)
		if candidate_id == event_id:
			continue
		var candidate := _dict(definitions_by_id.get(candidate_id, {}))
		if bool(candidate.get("allow_duplicate_unique_class", false)) or str(candidate.get("unique_object_class", "")).strip_edges() != unique_class:
			continue
		var candidate_priority := int(candidate.get("unique_object_priority", 0))
		var candidate_index := int(candidate_indexes.get(candidate_id, -1))
		if candidate_priority > priority or candidate_priority == priority and candidate_index < event_index:
			result.append(candidate_id)
	return result


static func _event_fits(definition: Dictionary, scopes: Array) -> bool:
	var event_scopes := _string_array(definition.get("scopes", []))
	if event_scopes.has("any"):
		return true
	for scope in scopes:
		if event_scopes.has(scope):
			return true
	return false


static func _count(requested_count: Variant, rng: Variant) -> int:
	if typeof(requested_count) == TYPE_ARRAY and (requested_count as Array).size() >= 2:
		return rng.randi_range(int((requested_count as Array)[0]), int((requested_count as Array)[1]))
	return int(requested_count)


static func _count_bounds(requested_count: Variant) -> Array:
	if typeof(requested_count) == TYPE_ARRAY and (requested_count as Array).size() >= 2:
		var first := maxi(0, int((requested_count as Array)[0]))
		var second := maxi(0, int((requested_count as Array)[1]))
		return [mini(first, second), maxi(first, second)]
	var count := maxi(0, int(requested_count))
	return [count, count]


static func _definitions_by_id(event_definitions: Array) -> Dictionary:
	var result: Dictionary = {}
	for definition_value in event_definitions:
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition := definition_value as Dictionary
		var event_id := str(definition.get("id", "")).strip_edges()
		if not event_id.is_empty() and not result.has(event_id):
			result[event_id] = definition
	return result


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value as Array:
		var text := str(item).strip_edges()
		if not text.is_empty() and not result.has(text):
			result.append(text)
	return result


static func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
