class_name SlotDefinitionCache
extends RefCounted

# Immutable, content-derived slot data shared by every matching cabinet.
# Returned arrays are live cache values and must never be mutated by callers.

const StateScript := preload("res://scripts/games/slots/slot_machine_state.gd")

var _definition_fingerprint := 0
var _views: Dictionary = {}
var _definition: Dictionary = {}


func configure(definition: Dictionary) -> void:
	var fingerprint := hash(JSON.stringify(definition))
	if fingerprint == _definition_fingerprint and not _views.is_empty():
		return
	_definition_fingerprint = fingerprint
	_definition = definition
	_views.clear()


func bind_machine(machine: Dictionary) -> Dictionary:
	var view := view_for_machine(machine)
	if view.is_empty():
		return machine
	machine["reel_count"] = int(view.get("reel_count", machine.get("reel_count", 3)))
	machine["row_count"] = int(view.get("row_count", machine.get("row_count", 1)))
	machine["pay_model"] = str(view.get("pay_model", machine.get("pay_model", "single_line")))
	machine["reel_heights"] = view.get("reel_heights", [])
	machine["reel_strips"] = view.get("reel_strips", [])
	machine["bonus_reel_strips"] = view.get("bonus_reel_strips", view.get("reel_strips", []))
	return machine


func compact_machine_for_storage(machine: Dictionary) -> Dictionary:
	for key in StateScript.IMMUTABLE_DEFINITION_STATE_KEYS:
		machine.erase(key)
	return machine


func owned_runtime_machine(source: Dictionary) -> Dictionary:
	if source.is_empty():
		return {}
	# Runtime mutations replace top-level machine fields. Nested feature/item
	# helpers already take an owned copy before changing their value, so a
	# shallow machine fork is sufficient and avoids cloning a 10-60 KB active
	# feature twice for every scheduled tick.
	var result: Dictionary = source.duplicate(false)
	for key in StateScript.IMMUTABLE_DEFINITION_STATE_KEYS:
		result.erase(key)
	return bind_machine(result)


func view_for_machine(machine: Dictionary) -> Dictionary:
	if _definition.is_empty():
		return {}
	var family_id := str(machine.get("type_id", "pinball"))
	var format_id := str(machine.get("format_id", "classic_3_reel"))
	var key := "%s|%s" % [family_id, format_id]
	var cached: Variant = _views.get(key)
	if typeof(cached) == TYPE_DICTIONARY:
		return cached as Dictionary
	var geometry := StateScript.canonical_geometry(_definition, family_id, format_id)
	var reel_count := maxi(1, int(geometry.get("reel_count", machine.get("reel_count", 3))))
	var strips := _configured_strips(family_id, format_id, reel_count)
	var heights: Array = []
	for strip_value in strips:
		heights.append((strip_value as Array).size() if typeof(strip_value) == TYPE_ARRAY else 0)
	var view := {
		"reel_count": reel_count,
		"row_count": maxi(1, int(geometry.get("row_count", machine.get("row_count", 1)))),
		"pay_model": str(geometry.get("pay_model", machine.get("pay_model", "single_line"))),
		"reel_heights": heights,
		"reel_strips": strips,
		"bonus_reel_strips": strips,
	}
	_views[key] = view
	return view


func _configured_strips(family_id: String, format_id: String, reel_count: int) -> Array:
	var family_config_value: Variant = _definition.get("slot_%s_config" % family_id, {})
	var family_config: Dictionary = family_config_value as Dictionary if typeof(family_config_value) == TYPE_DICTIONARY else {}
	var by_format_value: Variant = family_config.get("reel_strips", {})
	var by_format: Dictionary = by_format_value as Dictionary if typeof(by_format_value) == TYPE_DICTIONARY else {}
	var source: Variant = by_format.get(format_id, [])
	var strips: Array = []
	if typeof(source) == TYPE_ARRAY:
		for strip_value in source as Array:
			if typeof(strip_value) != TYPE_ARRAY:
				continue
			var strip: Array = []
			for symbol_value in strip_value as Array:
				strip.append(str(symbol_value))
			strips.append(strip)
	while strips.size() < reel_count:
		strips.append(_fallback_strip(family_id))
	if strips.size() > reel_count:
		strips = strips.slice(0, reel_count)
	return strips


func _fallback_strip(family_id: String) -> Array:
	if family_id == "buffalo":
		return ["BLANK", "A", "K", "Q", "J", "10", "BUFFALO", "SUNSET", "GOLD_TOKEN", "EAGLE", "WOLF", "HORSE", "ELK", "CASH"]
	return ["BLANK", "BUMPER", "BALL", "SPINNER", "CHERRY", "BAR", "7", "DOUBLE", "DOUBLE_7", "PINBALL", "WILD"]

