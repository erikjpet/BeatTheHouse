class_name AttributeBadges
extends RefCounted

# Read-only translator from content dictionaries to shared attribute badge rows.

const GLYPH_REGISTRY_PATH := "res://data/art/attribute_glyphs.json"
const VALID_POLARITIES := {
	"class": true,
	"neutral": true,
	"positive_good": true,
	"positive_bad": true,
}

static var _registry_loaded := false
static var _registry: Dictionary = {}
static var _validation_errors: Array = []


static func registry() -> Dictionary:
	_ensure_registry()
	return _registry.duplicate(true)


static func validation_errors() -> Array:
	_ensure_registry()
	return _validation_errors.duplicate()


static func glyph_ids() -> Array:
	var ids := _string_array(_glyphs().keys())
	ids.sort()
	return ids


static func glyph_definition(glyph_id: String) -> Dictionary:
	var glyphs := _glyphs()
	var value: Variant = glyphs.get(glyph_id, {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


static func class_badge(kind: String, class_id: String) -> Dictionary:
	var clean_kind := kind.strip_edges().to_lower()
	var clean_class := class_id.strip_edges().to_lower()
	var classes := _class_badges()
	var kind_value: Variant = classes.get(clean_kind, {})
	if typeof(kind_value) != TYPE_DICTIONARY:
		return {}
	var map := kind_value as Dictionary
	var glyph_id := str(map.get(clean_class, map.get("_default", ""))).strip_edges()
	if glyph_id.is_empty():
		return {}
	var value_text := _class_value_text(clean_kind, clean_class)
	var tooltip := "%s: %s" % [_glyph_label(glyph_id), _title_text(clean_class)]
	return _badge(glyph_id, value_text, "class", tooltip)


static func class_badge_map(kind: String) -> Dictionary:
	var classes := _class_badges()
	var value: Variant = classes.get(kind.strip_edges().to_lower(), {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


static func legend_entries() -> Array:
	var result: Array = []
	for glyph_id_value in glyph_ids():
		var glyph_id := str(glyph_id_value)
		var glyph := glyph_definition(glyph_id)
		if glyph.is_empty():
			continue
		result.append({
			"glyph_id": glyph_id,
			"label": str(glyph.get("label", glyph_id)),
			"description": str(glyph.get("description", "")),
			"palette": str(glyph.get("palette", "soft")),
			"polarity": str(glyph.get("polarity", "neutral")),
			"badge": _badge(glyph_id, "", _badge_polarity(glyph_id, 0), str(glyph.get("description", ""))),
		})
	return result


static func for_route(route: Dictionary, route_risk: Dictionary = {}) -> Array:
	var source := route.duplicate(true)
	var risk_event := route_risk.duplicate(true)
	if risk_event.is_empty():
		risk_event = _copy_dict(source.get("risk_event", {}))
	var badges: Array = []
	var risk := str(source.get("risk", "")).strip_edges().to_lower()
	badges.append(class_badge("route", risk))
	if source.has("cost"):
		_add_badge(badges, _badge("cost", str(maxi(0, int(source.get("cost", 0)))), _badge_polarity("cost", int(source.get("cost", 0))), "Route fare"))
	var distance := str(source.get("distance", "")).strip_edges().to_lower()
	if not distance.is_empty():
		_add_badge(badges, _badge("distance", _distance_value_text(distance), "neutral", "Travel distance: %s" % _title_text(distance)))
	var tier := _risk_tier(risk)
	if tier > 0:
		_add_badge(badges, _badge("risk_tier", _pip_text(tier), _badge_polarity("risk_tier", tier), "Route risk tier"))
	var risk_decay := int(source.get("risk_decay", 0))
	if risk_decay > 0:
		_add_badge(badges, _badge("risk_decay", str(risk_decay), _badge_polarity("risk_decay", risk_decay), "Heat cooling while traveling"))
	var suspicion_delta := int(source.get("suspicion_delta", 0))
	if suspicion_delta != 0:
		_add_delta_badge(badges, "suspicion", suspicion_delta, "Route heat change")
	if not risk_event.is_empty():
		var chance := int(risk_event.get("chance_percent", 0))
		if chance > 0:
			_add_badge(badges, _badge("risk_tier", "%d%%" % chance, "bad", "Chance of route trouble"))
		_append_delta_badges(badges, risk_event)
	return _filtered_badges(badges)


static func for_item(item: Dictionary) -> Array:
	var source := item.duplicate(true)
	var badges: Array = []
	var item_class := str(source.get("item_class", source.get("class", source.get("item_type", "")))).strip_edges().to_lower()
	badges.append(class_badge("item", item_class))
	if bool(source.get("pickup", false)):
		_add_badge(badges, _badge("cost", "0", "good", "Pickup item"))
	elif source.has("price"):
		_add_badge(badges, _badge("cost", str(maxi(0, int(source.get("price", 0)))), _badge_polarity("cost", int(source.get("price", 0))), "Item price"))
	elif source.has("price_min"):
		var price_min := maxi(0, int(source.get("price_min", 0)))
		var price_max := maxi(price_min, int(source.get("price_max", price_min)))
		if price_max > 0:
			var price_text := str(price_min) if price_min == price_max else "%d-%d" % [price_min, price_max]
			_add_badge(badges, _badge("cost", price_text, _badge_polarity("cost", price_min), "Item price range"))
	elif source.has("sale_price") and int(source.get("sale_price", 0)) > 0:
		_add_badge(badges, _badge("bankroll", str(maxi(0, int(source.get("sale_price", 0)))), "good", "Sale value"))
	var effect := _definition_effect(source)
	_append_effect_badges(badges, effect)
	if int(source.get("capacity", source.get("container_capacity", 0))) > 0:
		_add_badge(badges, _badge("inventory", "x%d" % int(source.get("capacity", source.get("container_capacity", 0))), "neutral", "Storage capacity"))
	return _filtered_badges(badges)


static func for_event_choice(choice: Dictionary) -> Array:
	var source := choice.duplicate(true)
	var badges: Array = []
	var event_type := str(source.get("event_type", source.get("type", ""))).strip_edges().to_lower()
	if not event_type.is_empty():
		badges.append(class_badge("event", event_type))
	var consequences := _copy_dict(source.get("consequences", source.get("effects", source.get("deltas", {}))))
	_append_delta_badges(badges, consequences)
	var check := _copy_dict(source.get("check", consequences.get("check", {})))
	if not check.is_empty():
		var chance := int(check.get("chance_percent", check.get("base_chance", check.get("chance", 0))))
		if chance > 0:
			_add_badge(badges, _badge("win_chance", "%d%%" % chance, _badge_polarity("win_chance", chance), "Check chance"))
		var success := _copy_dict(check.get("success_consequences", {}))
		if not success.is_empty():
			_append_delta_badges(badges, success)
	return _filtered_badges(badges)


static func for_service(service: Dictionary) -> Array:
	var source := service.duplicate(true)
	var badges: Array = []
	var category := str(source.get("category", "")).strip_edges().to_lower()
	badges.append(class_badge("service", category))
	if source.has("cost"):
		_add_badge(badges, _badge("cost", str(maxi(0, int(source.get("cost", 0)))), _badge_polarity("cost", int(source.get("cost", 0))), "Service cost"))
	_append_delta_badges(badges, _definition_effect(source))
	return _filtered_badges(badges)


static func for_lender(lender: Dictionary) -> Array:
	var source := lender.duplicate(true)
	var badges: Array = []
	var lender_type := str(source.get("lender_type", source.get("category", ""))).strip_edges().to_lower()
	badges.append(class_badge("lender", lender_type))
	var debt_profile := _copy_dict(source.get("debt_profile", source.get("debt", {})))
	if not debt_profile.is_empty():
		var amount := int(debt_profile.get("principal", debt_profile.get("amount", debt_profile.get("bankroll_delta", 0))))
		if amount != 0:
			_add_badge(badges, _badge("debt", str(abs(amount)), _badge_polarity("debt", abs(amount)), "Debt principal"))
		else:
			_add_badge(badges, _badge("debt", "loan", "bad", "Debt contract"))
	_append_delta_badges(badges, _definition_effect(source))
	return _filtered_badges(badges)


static func from_deltas(deltas: Dictionary) -> Array:
	var badges: Array = []
	_append_delta_badges(badges, deltas)
	return _filtered_badges(badges)


static func palette_token_for_badge(badge: Dictionary) -> String:
	var glyph_id := str(badge.get("glyph_id", "")).strip_edges()
	var glyph := glyph_definition(glyph_id)
	var polarity := str(badge.get("polarity", "")).strip_edges().to_lower()
	match polarity:
		"good":
			return "teal"
		"bad":
			return "pink"
		"class":
			return str(glyph.get("palette", "yellow"))
		"neutral":
			return str(glyph.get("palette", "cyan"))
		_:
			return str(glyph.get("palette", "soft"))


static func _append_delta_badges(badges: Array, deltas: Dictionary) -> void:
	_add_delta_badge(badges, "bankroll", int(deltas.get("bankroll_delta", 0)), "Bankroll change")
	_add_delta_badge(badges, "suspicion", int(deltas.get("suspicion_delta", deltas.get("heat_delta", 0))), "Heat change")
	_add_delta_badge(badges, "luck", int(deltas.get("baseline_luck_delta", 0)), "Luck change")
	_add_delta_badge(badges, "alcohol", int(deltas.get("alcohol_intake", 0)), "Drink intake")
	_add_delta_badge(badges, "alcohol", int(deltas.get("drunk_delta", 0)), "Drunkness change")
	_add_delta_badge(badges, "alcohol", int(deltas.get("pending_drunk_absorption_delta", 0)), "Pending drink change")
	var steady_turns := int(deltas.get("drunk_distortion_suppression_turns", 0))
	if steady_turns > 0:
		_add_badge(badges, _badge("time_actions", "%da" % steady_turns, "good", "Steady vision duration"))
	var heat_cooldown_actions := int(deltas.get("heat_cooldown_actions", 0))
	var heat_cooldown_per_action := int(deltas.get("heat_cooldown_per_action", 0))
	if heat_cooldown_actions > 0 and heat_cooldown_per_action > 0:
		_add_badge(badges, _badge("time_actions", "%da" % heat_cooldown_actions, "good", "Heat cooldown duration"))
		_add_badge(badges, _badge("suspicion", "-%d/a" % heat_cooldown_per_action, "good", "Heat cooldown per action"))
	var debt_changes := _copy_array(deltas.get("debt_changes", []))
	if deltas.has("debt"):
		debt_changes.append(_copy_dict(deltas.get("debt", {})))
	if not debt_changes.is_empty():
		_add_badge(badges, _badge("debt", "+%d" % debt_changes.size(), "bad", "Debt change"))
	var inventory_add := _copy_array(deltas.get("inventory_add", []))
	if not inventory_add.is_empty():
		_add_badge(badges, _badge("inventory", "+%d" % inventory_add.size(), "good", "Item gained"))
	var inventory_remove := _copy_array(deltas.get("inventory_remove", []))
	if not inventory_remove.is_empty():
		_add_badge(badges, _badge("inventory", "-%d" % inventory_remove.size(), "bad", "Item removed"))
	var travel_hooks := _copy_array(deltas.get("travel_hooks_add", []))
	for route_id in _single_or_array_strings(deltas.get("unlock_travel_route", deltas.get("unlock_travel_routes", []))):
		if not travel_hooks.has(route_id):
			travel_hooks.append(route_id)
	if not travel_hooks.is_empty():
		_add_badge(badges, _badge("class_route", "+%d" % travel_hooks.size(), "good", "Route unlocked"))
	var story_flags := _copy_dict(deltas.get("story_flags_set", {}))
	var single_story_flag := str(deltas.get("set_story_flag", "")).strip_edges()
	if not single_story_flag.is_empty():
		story_flags[single_story_flag] = true
	for flag_id in _single_or_array_strings(deltas.get("set_story_flags", [])):
		story_flags[str(flag_id)] = true
	if not story_flags.is_empty():
		_add_badge(badges, _badge("story", "+%d" % story_flags.size(), "good", "Story flag"))


static func _append_effect_badges(badges: Array, effect: Dictionary) -> void:
	_append_delta_badges(badges, effect)
	_add_delta_badge(badges, "win_chance", int(effect.get("win_chance", effect.get("legal_win_chance", 0))), "Win chance")
	_add_delta_badge(badges, "win_bonus", int(effect.get("win_bonus", 0)), "Win bonus")
	_add_delta_badge(badges, "suspicion", int(effect.get("cheat_suspicion_delta", 0)), "Cheat heat change")
	if bool(effect.get("active_item", false)) or str(effect.get("active_mode", "")).strip_edges() != "":
		_add_badge(badges, _badge("time_actions", "use", "neutral", "Active item"))
	if int(effect.get("travel_scouting_level", 0)) > 0:
		_add_badge(badges, _badge("distance", "scout", "good", "Travel scouting"))
	var families := _copy_dict(effect.get("families", {}))
	for family_value in families.values():
		if typeof(family_value) == TYPE_DICTIONARY:
			_append_family_effect_badges(badges, family_value as Dictionary)


static func _append_family_effect_badges(badges: Array, effect: Dictionary) -> void:
	_add_delta_badge(badges, "win_chance", int(effect.get("win_chance", effect.get("slot_reel_win_weight_percent", 0))), "Family win weight")
	_add_delta_badge(badges, "win_bonus", int(effect.get("win_bonus", effect.get("slot_feature_weight_bonus_percent", 0))), "Family payout or feature weight")


static func _definition_effect(definition: Dictionary) -> Dictionary:
	for key in ["deltas", "result_delta", "result_deltas", "effect", "consequences"]:
		var value: Variant = definition.get(key, {})
		if typeof(value) == TYPE_DICTIONARY and not (value as Dictionary).is_empty():
			return (value as Dictionary).duplicate(true)
	return {}


static func _add_delta_badge(badges: Array, glyph_id: String, value: int, tooltip: String) -> void:
	if value == 0:
		return
	_add_badge(badges, _badge(glyph_id, "%+d" % value, _badge_polarity(glyph_id, value), tooltip))


static func _add_badge(badges: Array, badge: Dictionary) -> void:
	if badge.is_empty():
		return
	badges.append(badge)


static func _filtered_badges(badges: Array) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for badge_value in badges:
		if typeof(badge_value) != TYPE_DICTIONARY:
			continue
		var badge: Dictionary = badge_value
		var glyph_id := str(badge.get("glyph_id", "")).strip_edges()
		if glyph_id.is_empty() or glyph_definition(glyph_id).is_empty():
			continue
		var key := "%s|%s|%s" % [glyph_id, str(badge.get("value_text", "")), str(badge.get("polarity", ""))]
		if seen.has(key):
			continue
		seen[key] = true
		result.append(badge.duplicate(true))
	return result


static func _badge(glyph_id: String, value_text: String, polarity: String, tooltip: String = "") -> Dictionary:
	var clean_id := glyph_id.strip_edges()
	if clean_id.is_empty() or glyph_definition(clean_id).is_empty():
		return {}
	return {
		"glyph_id": clean_id,
		"value_text": value_text.strip_edges(),
		"polarity": polarity.strip_edges().to_lower(),
		"tooltip": tooltip.strip_edges(),
	}


static func _badge_polarity(glyph_id: String, value: int) -> String:
	if value == 0:
		return "neutral"
	var glyph := glyph_definition(glyph_id)
	var rule := str(glyph.get("polarity", "neutral"))
	if rule == "positive_good":
		return "good" if value > 0 else "bad"
	if rule == "positive_bad":
		return "bad" if value > 0 else "good"
	if rule == "class":
		return "class"
	return "neutral"


static func _glyph_label(glyph_id: String) -> String:
	var glyph := glyph_definition(glyph_id)
	return str(glyph.get("label", glyph_id))


static func _risk_tier(risk: String) -> int:
	match risk.strip_edges().to_lower():
		"low":
			return 1
		"medium":
			return 2
		"high", "boss":
			return 3
		_:
			return 0


static func _pip_text(tier: int) -> String:
	var result := ""
	for _index in range(clampi(tier, 1, 3)):
		result += "!"
	return result


static func _distance_value_text(distance: String) -> String:
	match distance:
		"near":
			return "near"
		"local":
			return "local"
		"far":
			return "far"
		"remote":
			return "remote"
		_:
			return distance


static func _class_value_text(kind: String, class_id: String) -> String:
	var key := "%s:%s" % [kind, class_id]
	match key:
		"item:active":
			return "Act"
		"item:consumable":
			return "Use"
		"item:container":
			return "Box"
		"item:contraband":
			return "Hot"
		"item:damaged":
			return "Dmg"
		"item:permanent":
			return "Perm"
		"item:temporary":
			return "Temp"
		"route:low":
			return "Low"
		"route:medium":
			return "Med"
		"route:high":
			return "High"
		"route:boss":
			return "Boss"
		_:
			var title := _title_text(class_id)
			return title.left(6) if title.length() > 6 else title


static func _title_text(value: String) -> String:
	var clean := value.strip_edges().replace("_", " ")
	if clean.is_empty():
		return "General"
	return clean.capitalize()


static func _ensure_registry() -> void:
	if _registry_loaded:
		return
	_registry_loaded = true
	_registry = {}
	_validation_errors = []
	if not FileAccess.file_exists(GLYPH_REGISTRY_PATH):
		_validation_errors.append("Missing attribute glyph registry: %s" % GLYPH_REGISTRY_PATH)
		return
	var text := FileAccess.get_file_as_string(GLYPH_REGISTRY_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_validation_errors.append("Attribute glyph registry must be a JSON dictionary.")
		return
	_registry = (parsed as Dictionary).duplicate(true)
	_validate_registry()


static func _validate_registry() -> void:
	var glyphs := _glyphs()
	if glyphs.is_empty():
		_validation_errors.append("Attribute glyph registry has no glyphs.")
	for glyph_id_value in glyphs.keys():
		var glyph_id := str(glyph_id_value)
		var glyph_value: Variant = glyphs.get(glyph_id, {})
		if typeof(glyph_value) != TYPE_DICTIONARY:
			_validation_errors.append("Attribute glyph %s must be a dictionary." % glyph_id)
			continue
		var glyph := glyph_value as Dictionary
		if str(glyph.get("label", "")).strip_edges().is_empty():
			_validation_errors.append("Attribute glyph %s is missing label." % glyph_id)
		var polarity := str(glyph.get("polarity", "neutral")).strip_edges()
		if not bool(VALID_POLARITIES.get(polarity, false)):
			_validation_errors.append("Attribute glyph %s has unsupported polarity: %s." % [glyph_id, polarity])
		var sprite_value: Variant = glyph.get("sprite", {})
		if typeof(sprite_value) != TYPE_DICTIONARY:
			_validation_errors.append("Attribute glyph %s sprite must be a dictionary." % glyph_id)
			continue
		var sprite := sprite_value as Dictionary
		var shapes_value: Variant = sprite.get("shapes", [])
		if typeof(shapes_value) != TYPE_ARRAY or (shapes_value as Array).is_empty():
			_validation_errors.append("Attribute glyph %s sprite.shapes must be a non-empty array." % glyph_id)
	for kind_value in _class_badges().keys():
		var kind := str(kind_value)
		var map_value: Variant = _class_badges().get(kind, {})
		if typeof(map_value) != TYPE_DICTIONARY:
			_validation_errors.append("Attribute class_badges.%s must be a dictionary." % kind)
			continue
		var map := map_value as Dictionary
		if str(map.get("_default", "")).strip_edges().is_empty():
			_validation_errors.append("Attribute class_badges.%s is missing _default." % kind)
		for class_value in map.keys():
			var glyph_id := str(map.get(class_value, ""))
			if glyph_definition(glyph_id).is_empty():
				_validation_errors.append("Attribute class_badges.%s.%s references unknown glyph %s." % [kind, str(class_value), glyph_id])


static func _glyphs() -> Dictionary:
	_ensure_registry()
	var value: Variant = _registry.get("glyphs", {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value as Dictionary


static func _class_badges() -> Dictionary:
	_ensure_registry()
	var value: Variant = _registry.get("class_badges", {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value as Dictionary


static func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


static func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var text := str(entry).strip_edges()
		if not text.is_empty():
			result.append(text)
	return result


static func _single_or_array_strings(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return _string_array(value)
	var text := str(value).strip_edges()
	return [] if text.is_empty() else [text]
