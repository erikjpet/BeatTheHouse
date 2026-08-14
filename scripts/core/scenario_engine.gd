class_name ScenarioEngine
extends RefCounted

# Deterministic scenario overlays. Selection belongs to RunGenerator; this
# module only builds and advances the selected node-owned state.

const STATE_SCHEMA_VERSION := 1
const ALLOWED_MUTATION_KEYS := [
	"patron_set",
	"staff_set",
	"event_pool_add",
	"event_pool_remove",
	"economic_profile_overrides",
	"game_modifier_hooks",
	"service_add",
	"service_remove",
	"music_profile_override",
	"presentation",
	"exclusive_opportunity",
	"security_overrides",
	"hook_flags",
]
const ALLOWED_PRESENTATION_KEYS := ["palette_tint", "lighting_key", "crowd_density", "signage_line"]
const ALLOWED_EXCLUSIVE_KEYS := ["event_id", "offer_id", "game_id"]
const ALLOWED_SECURITY_KEYS := ["strictness_band", "cheat_risk_window", "machine_alarm_tolerance_band"]


static func initial_state(definition: Dictionary) -> Dictionary:
	if definition.is_empty():
		return {}
	return {
		"schema_version": STATE_SCHEMA_VERSION,
		"id": str(definition.get("id", "")).strip_edges(),
		"archetype_id": str(definition.get("archetype_id", "")).strip_edges(),
		"layer_id": str(definition.get("layer_id", "")).strip_edges(),
		"display_name": str(definition.get("display_name", "")).strip_edges(),
		"placeholder": bool(definition.get("placeholder", false)),
		"phase_index": 0,
		"phase_action_counter": 0,
		"mutations": _copy_dict(definition.get("mutations", {})),
		"phases": _copy_array(definition.get("phases", [])),
		"town_weight_tags": _string_array(definition.get("town_weight_tags", [])),
	}


static func normalize_state(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = value
	var scenario_id := str(source.get("id", "")).strip_edges()
	if scenario_id.is_empty():
		return {}
	var phases := _copy_array(source.get("phases", []))
	var phase_index := maxi(0, int(source.get("phase_index", 0)))
	if not phases.is_empty():
		phase_index = mini(phase_index, phases.size() - 1)
	else:
		phase_index = 0
	return {
		"schema_version": STATE_SCHEMA_VERSION,
		"id": scenario_id,
		"archetype_id": str(source.get("archetype_id", "")).strip_edges(),
		"layer_id": str(source.get("layer_id", "")).strip_edges(),
		"display_name": str(source.get("display_name", scenario_id)).strip_edges(),
		"placeholder": bool(source.get("placeholder", false)),
		"phase_index": phase_index,
		"phase_action_counter": maxi(0, int(source.get("phase_action_counter", 0))),
		"mutations": _copy_dict(source.get("mutations", {})),
		"phases": phases,
		"town_weight_tags": _string_array(source.get("town_weight_tags", [])),
	}


static func apply_to_archetype(archetype: Dictionary, state_value: Variant) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty():
		return archetype
	var result := archetype.duplicate(true)
	if not _state_targets_layer(state, result):
		return result
	_apply_mutations(result, _copy_dict(state.get("mutations", {})), true)
	var phases := _copy_array(state.get("phases", []))
	var phase_index := mini(maxi(0, int(state.get("phase_index", 0))), phases.size() - 1)
	for index in range(phase_index + 1):
		if index < phases.size() and typeof(phases[index]) == TYPE_DICTIONARY:
			_apply_mutations(result, _copy_dict((phases[index] as Dictionary).get("mutations", {})), true)
	return result


static func attach_to_environment(environment: Dictionary, state_value: Variant) -> void:
	var state := normalize_state(state_value)
	if state.is_empty():
		return
	environment["scenario_state"] = state
	environment["scenario_id"] = str(state.get("id", ""))
	environment["scenario_phase_index"] = int(state.get("phase_index", 0))
	environment["scenario_phase_action_counter"] = int(state.get("phase_action_counter", 0))
	environment["scenario_applied_phase_index"] = int(state.get("phase_index", 0)) if _state_targets_layer(state, environment) else -1
	_apply_exclusive_opportunity(environment)


static func advance_environment(environment: Dictionary, amount: int) -> bool:
	if amount <= 0:
		return false
	var state := normalize_state(environment.get("scenario_state", {}))
	if state.is_empty():
		return false
	var phases := _copy_array(state.get("phases", []))
	if phases.is_empty():
		return false
	var changed := false
	var applies_here := _state_targets_layer(state, environment)
	var remaining := amount
	while remaining > 0:
		var phase_index := mini(maxi(0, int(state.get("phase_index", 0))), phases.size() - 1)
		var phase: Dictionary = phases[phase_index] if typeof(phases[phase_index]) == TYPE_DICTIONARY else {}
		var threshold := maxi(0, int(phase.get("advance_after_actions", 0)))
		if threshold <= 0 or phase_index >= phases.size() - 1:
			state["phase_action_counter"] = maxi(0, int(state.get("phase_action_counter", 0))) + remaining
			remaining = 0
			continue
		var counter := maxi(0, int(state.get("phase_action_counter", 0)))
		var consumed := mini(remaining, maxi(1, threshold - counter))
		counter += consumed
		remaining -= consumed
		if counter < threshold:
			state["phase_action_counter"] = counter
			continue
		phase_index += 1
		state["phase_index"] = phase_index
		state["phase_action_counter"] = 0
		var next_phase: Dictionary = phases[phase_index] if typeof(phases[phase_index]) == TYPE_DICTIONARY else {}
		if applies_here:
			_apply_mutations(environment, _copy_dict(next_phase.get("mutations", {})), false)
			environment["scenario_applied_phase_index"] = phase_index
			_apply_exclusive_opportunity(environment)
		changed = true
	environment["scenario_state"] = state
	environment["scenario_id"] = str(state.get("id", ""))
	environment["scenario_phase_index"] = int(state.get("phase_index", 0))
	environment["scenario_phase_action_counter"] = int(state.get("phase_action_counter", 0))
	return changed


# Synchronizes a stored layer with the authoritative node scenario cursor.
static func reconcile_environment(environment: Dictionary, state_value: Variant) -> void:
	var state := normalize_state(state_value)
	if state.is_empty():
		return
	environment["scenario_state"] = state
	environment["scenario_id"] = str(state.get("id", ""))
	environment["scenario_phase_index"] = int(state.get("phase_index", 0))
	environment["scenario_phase_action_counter"] = int(state.get("phase_action_counter", 0))
	if not _state_targets_layer(state, environment):
		return
	var phases := _copy_array(state.get("phases", []))
	var applied_index := int(environment.get("scenario_applied_phase_index", -1))
	var target_index := mini(maxi(0, int(state.get("phase_index", 0))), phases.size() - 1) if not phases.is_empty() else -1
	for index in range(applied_index + 1, target_index + 1):
		if index >= 0 and index < phases.size() and typeof(phases[index]) == TYPE_DICTIONARY:
			_apply_mutations(environment, _copy_dict((phases[index] as Dictionary).get("mutations", {})), false)
	environment["scenario_applied_phase_index"] = target_index
	_apply_exclusive_opportunity(environment)


static func public_snapshot(state_value: Variant) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty():
		return {}
	return {
		"id": str(state.get("id", "")),
		"archetype_id": str(state.get("archetype_id", "")),
		"layer_id": str(state.get("layer_id", "")),
		"display_name": str(state.get("display_name", "")),
		"phase_index": int(state.get("phase_index", 0)),
		"phase_action_counter": int(state.get("phase_action_counter", 0)),
	}


static func _state_targets_layer(state: Dictionary, target: Dictionary) -> bool:
	var wanted := str(state.get("layer_id", "")).strip_edges()
	if wanted.is_empty():
		return true
	return str(target.get("current_layer_id", "")).strip_edges() == wanted


static func _apply_mutations(target: Dictionary, mutations: Dictionary, generation: bool) -> void:
	if mutations.is_empty():
		return
	if mutations.has("patron_set"):
		target["scenario_patron_ids"] = _string_array(mutations.get("patron_set", []))
	if mutations.has("staff_set"):
		target["scenario_staff_ids"] = _string_array(mutations.get("staff_set", []))
	_apply_id_delta(target, "event_pool" if generation else "event_ids", mutations.get("event_pool_add", []), mutations.get("event_pool_remove", []))
	_apply_id_delta(target, "service_pool" if generation else "service_ids", mutations.get("service_add", []), mutations.get("service_remove", []))
	if mutations.has("economic_profile_overrides"):
		target["economic_profile"] = _deep_merge(_copy_dict(target.get("economic_profile", {})), _copy_dict(mutations.get("economic_profile_overrides", {})))
	if mutations.has("game_modifier_hooks"):
		target["scenario_game_modifiers"] = _deep_merge(_copy_dict(target.get("scenario_game_modifiers", {})), _copy_dict(mutations.get("game_modifier_hooks", {})))
	if mutations.has("music_profile_override"):
		target["music_profile"] = _deep_merge(_copy_dict(target.get("music_profile", {})), _copy_dict(mutations.get("music_profile_override", {})))
	if mutations.has("presentation"):
		var presentation := _deep_merge(_copy_dict(target.get("scenario_presentation", {})), _copy_dict(mutations.get("presentation", {})))
		target["scenario_presentation"] = presentation
		target["visual_context"] = _deep_merge(_copy_dict(target.get("visual_context", {})), presentation)
	if mutations.has("exclusive_opportunity"):
		target["scenario_exclusive_opportunity"] = _copy_dict(mutations.get("exclusive_opportunity", {}))
	if mutations.has("security_overrides"):
		target["security_profile"] = _deep_merge(_copy_dict(target.get("security_profile", {})), _copy_dict(mutations.get("security_overrides", {})))
	if mutations.has("hook_flags"):
		target["scenario_hook_flags"] = _deep_merge(_copy_dict(target.get("scenario_hook_flags", {})), _copy_dict(mutations.get("hook_flags", {})))


static func _apply_exclusive_opportunity(environment: Dictionary) -> void:
	var opportunity := _copy_dict(environment.get("scenario_exclusive_opportunity", {}))
	var event_id := str(opportunity.get("event_id", "")).strip_edges()
	if not event_id.is_empty():
		_apply_id_delta(environment, "event_ids", [event_id], [])
	var game_id := str(opportunity.get("game_id", "")).strip_edges()
	if not game_id.is_empty():
		_apply_id_delta(environment, "game_ids", [game_id], [])


static func _apply_id_delta(target: Dictionary, key: String, additions_value: Variant, removals_value: Variant) -> void:
	var values := _string_array(target.get(key, []))
	for remove_id in _string_array(removals_value):
		while values.has(remove_id):
			values.erase(remove_id)
	for add_id in _string_array(additions_value):
		if not values.has(add_id):
			values.append(add_id)
	target[key] = values


static func _deep_merge(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key_value in overlay.keys():
		var value: Variant = overlay.get(key_value)
		if typeof(value) == TYPE_DICTIONARY and typeof(result.get(key_value)) == TYPE_DICTIONARY:
			result[key_value] = _deep_merge(result.get(key_value, {}) as Dictionary, value as Dictionary)
		elif typeof(value) == TYPE_DICTIONARY:
			result[key_value] = (value as Dictionary).duplicate(true)
		elif typeof(value) == TYPE_ARRAY:
			result[key_value] = (value as Array).duplicate(true)
		else:
			result[key_value] = value
	return result


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value as Array:
		var entry := str(entry_value).strip_edges()
		if not entry.is_empty() and not result.has(entry):
			result.append(entry)
	return result


static func _copy_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _copy_dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
