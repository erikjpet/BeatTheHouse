class_name ItemEffect
extends RefCounted

# Base contract for data-backed item effects.

const DIRECT_DELTA_KEYS := [
	"bankroll_delta",
	"suspicion_delta",
	"alcohol_intake",
	"drunk_delta",
	"alcoholic_delta",
	"baseline_luck_delta",
	"debt_changes",
	"inventory_add",
	"inventory_remove",
	"flags_set",
	"travel_hooks_add",
	"travel_changes",
	"story_log",
	"messages",
	"ended",
	"item_hooks",
	"event_hooks",
]

const EFFECT_METADATA_KEYS := [
	"families",
]

var definition: Dictionary = {}


# Stores the item definition used by this effect.
func setup(p_definition: Dictionary) -> void:
	definition = p_definition.duplicate(true)


# Returns this item effect id.
func get_id() -> String:
	return str(definition.get("id", ""))


# Returns the item class from README itemization.
func get_item_class() -> String:
	return str(definition.get("class", ""))


# Returns the effect domain.
func get_domain() -> String:
	return str(definition.get("domain", "global"))


# Returns a copy of the effect payload.
func effect_data() -> Dictionary:
	return _copy_dict(definition.get("effect", {}))


# Checks whether the effect applies to the supplied context.
func applies(context: Dictionary) -> bool:
	var domain := get_domain()
	if domain == "global":
		return true
	var context_domain := str(context.get("domain", ""))
	if context_domain == domain:
		return true
	var domains := _string_array(context.get("domains", []))
	if domains.has(domain):
		return true
	if domain == "games" and (context_domain == "game" or domains.has("game")):
		return true
	if domain == "security" and (context_domain == "suspicion" or domains.has("suspicion") or str(context.get("action_kind", "")) == "cheat"):
		return true
	return domains.has(domain)


# Returns modifiers that affect the supplied domain context.
func modifiers_for(context: Dictionary) -> Dictionary:
	if not applies(context):
		return {}
	var effect := effect_data()
	var modifiers: Dictionary = {}
	_merge_modifier_source(modifiers, effect)
	var family := str(context.get("game_family", context.get("family", "")))
	var families := _copy_dict(effect.get("families", {}))
	if not family.is_empty() and families.has(family):
		_merge_modifier_source(modifiers, _copy_dict(families.get(family, {})))
	var action_kind := str(context.get("action_kind", ""))
	if action_kind == "legal":
		_merge_prefixed_modifiers(modifiers, effect, "legal_")
	elif action_kind == "cheat":
		_merge_prefixed_modifiers(modifiers, effect, "cheat_")
	return modifiers


# Adds effect data to the supplied context and optionally applies direct deltas.
func apply(context: Dictionary, run_state: RunState = null) -> Dictionary:
	var applied := applies(context)
	var modifiers := modifiers_for(context) if applied else {}
	var deltas := _result_deltas(context, modifiers, applied)
	var result: Dictionary = context.duplicate(true)
	result["item_effect_id"] = get_id()
	result["item_id"] = get_id()
	result["item_class"] = get_item_class()
	result["domain"] = get_domain()
	result["applied"] = applied
	result["ok"] = applied
	result["type"] = "item_effect"
	result["source_id"] = get_id()
	result["action_id"] = str(context.get("action_id", ""))
	result["action_kind"] = str(context.get("action_kind", ""))
	result["environment_id"] = str(context.get("environment_id", ""))
	result["effect"] = effect_data() if applied else {}
	result["modifiers"] = modifiers
	result["deltas"] = deltas
	result["message"] = ""
	result["messages"] = _copy_array(deltas.get("messages", []))
	result["ended"] = bool(deltas.get("ended", false))
	result["state"] = GameModule.RESULT_ENDED if bool(result["ended"]) else GameModule.RESULT_CONTINUE
	if run_state != null:
		GameModule.apply_result(run_state, result)
	return result


# Builds shared result deltas from direct effect keys and passive modifiers.
func _result_deltas(context: Dictionary, modifiers: Dictionary, applied: bool) -> Dictionary:
	var deltas := GameModule.empty_result_deltas()
	if not applied:
		return deltas
	var effect := effect_data()
	deltas["bankroll_delta"] = int(effect.get("bankroll_delta", 0))
	deltas["suspicion_delta"] = int(effect.get("suspicion_delta", 0))
	deltas["alcohol_intake"] = int(effect.get("alcohol_intake", 0))
	deltas["drunk_delta"] = int(effect.get("drunk_delta", 0))
	deltas["alcoholic_delta"] = int(effect.get("alcoholic_delta", 0))
	deltas["baseline_luck_delta"] = int(effect.get("baseline_luck_delta", 0))
	deltas["debt_changes"] = _copy_array(effect.get("debt_changes", []))
	deltas["inventory_add"] = _copy_array(effect.get("inventory_add", []))
	deltas["inventory_remove"] = _copy_array(effect.get("inventory_remove", []))
	deltas["flags_set"] = _copy_dict(effect.get("flags_set", {}))
	deltas["travel_hooks_add"] = _copy_array(effect.get("travel_hooks_add", []))
	deltas["travel_changes"] = _copy_dict(effect.get("travel_changes", {}))
	deltas["story_log"] = _copy_array(effect.get("story_log", []))
	deltas["messages"] = _copy_array(effect.get("messages", []))
	deltas["ended"] = bool(effect.get("ended", false))
	deltas["event_hooks"] = _copy_array(effect.get("event_hooks", []))
	if not modifiers.is_empty():
		deltas["item_hooks"] = [{
			"item_id": get_id(),
			"item_class": get_item_class(),
			"domain": get_domain(),
			"context_domain": str(context.get("domain", "")),
			"game_family": str(context.get("game_family", context.get("family", ""))),
			"action_kind": str(context.get("action_kind", "")),
			"modifiers": modifiers.duplicate(true),
		}]
	else:
		deltas["item_hooks"] = _copy_array(effect.get("item_hooks", []))
	return deltas


# Adds non-delta effect keys as passive modifiers.
func _merge_modifier_source(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		var key_text := str(key)
		if DIRECT_DELTA_KEYS.has(key_text) or EFFECT_METADATA_KEYS.has(key_text) or _is_action_prefixed_key(key_text):
			continue
		_merge_modifier_value(target, key_text, source[key])


# Adds action-kind modifiers in their base form, such as legal_win_chance -> win_chance.
func _merge_prefixed_modifiers(target: Dictionary, source: Dictionary, prefix: String) -> void:
	for key in source.keys():
		var key_text := str(key)
		if not key_text.begins_with(prefix):
			continue
		var base_key := key_text.substr(prefix.length())
		if base_key.is_empty():
			continue
		_merge_modifier_value(target, base_key, source[key])


# Keeps legal_/cheat_ effects scoped to their matching action context.
func _is_action_prefixed_key(key: String) -> bool:
	return key.begins_with("legal_") or key.begins_with("cheat_")


# Merges numeric modifiers additively and copies structured modifiers.
func _merge_modifier_value(target: Dictionary, key: String, value: Variant) -> void:
	var value_type := typeof(value)
	if value_type == TYPE_INT or value_type == TYPE_FLOAT:
		target[key] = target.get(key, 0) + value
	elif value_type == TYPE_DICTIONARY:
		target[key] = _copy_dict(value)
	elif value_type == TYPE_ARRAY:
		target[key] = _copy_array(value)
	else:
		target[key] = value


# Safely duplicates array content.
static func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


# Normalizes a variant array into string ids.
static func _string_array(value: Variant) -> Array:
	var result: Array = []
	for entry in _copy_array(value):
		var id := str(entry)
		if not id.is_empty():
			result.append(id)
	return result


# Safely duplicates dictionary content.
static func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
