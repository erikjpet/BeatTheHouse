class_name MusicArrangementSelector
extends RefCounted

# Deterministic authored-stem bank selection. The selector works on manifest
# data only so the same decisions are available in headless tests and builds.

const DEFAULT_INTENSITY_BUCKETS := 10


static func select(entry: Dictionary, profile: Dictionary, music_state: Dictionary = {}) -> Dictionary:
	var track_id := str(entry.get("id", "")).strip_edges()
	var context := selection_context(profile, music_state, entry)
	var selected_stems := _copy_dict(entry.get("stems", {}))
	var selected_variants := {}
	var selected_ids := {}
	var selected_tags := {}
	var selected_groups := {}
	for tag_value in context.get("tags", []):
		selected_tags[str(tag_value)] = true
	var banks := _copy_dict(entry.get("stem_banks", {}))
	var roles := banks.keys()
	roles.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for role_value in roles:
		var role := str(role_value).strip_edges()
		var bank := _bank_data(banks.get(role_value))
		var candidates: Array = []
		for variant_value in bank.get("variants", []):
			if typeof(variant_value) != TYPE_DICTIONARY:
				continue
			var variant: Dictionary = (variant_value as Dictionary).duplicate(true)
			if _variant_matches(variant, context, selected_ids, selected_tags, selected_groups):
				candidates.append(variant)
		if candidates.is_empty():
			continue
		var seed_text := "%s|%s|%s|%s|%s|%d" % [
			track_id,
			str(profile.get("environment_id", profile.get("archetype_id", ""))),
			role,
			str(context.get("harmonic_section", "A")),
			str(bank.get("seed_salt", "")),
			int(context.get("intensity_bucket", 0)),
		]
		var selected := _weighted_pick(candidates, _stable_hash(seed_text))
		if selected.is_empty():
			continue
		selected_stems[role] = selected.duplicate(true)
		var variant_id := str(selected.get("id", "%s_%d" % [role, candidates.find(selected)])).strip_edges()
		selected_variants[role] = {
			"id": variant_id,
			"weight": maxf(0.0, float(selected.get("weight", 1.0))),
			"tags": _string_array(selected.get("tags", [])),
			"harmonic_section": str(context.get("harmonic_section", "A")),
			"intensity": float(context.get("intensity", 0.0)),
		}
		selected_ids[variant_id] = true
		for tag_value in _string_array(selected.get("tags", [])):
			selected_tags[str(tag_value)] = true
		var group := str(selected.get("mutual_exclusion_group", selected.get("exclusive_group", ""))).strip_edges()
		if not group.is_empty():
			selected_groups[group] = variant_id
	var signature_parts: Array[String] = ["section=%s" % str(context.get("harmonic_section", "A"))]
	var selected_roles := selected_variants.keys()
	selected_roles.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for role_value in selected_roles:
		signature_parts.append("%s=%s" % [str(role_value), str((selected_variants.get(role_value, {}) as Dictionary).get("id", ""))])
	return {
		"stems": selected_stems,
		"selected_variants": selected_variants,
		"selected_tags": selected_tags.keys(),
		"selected_groups": selected_groups,
		"selection_context": context,
		"selection_key": ",".join(signature_parts) if not signature_parts.is_empty() else "base",
	}


static func selection_context(profile: Dictionary, music_state: Dictionary = {}, entry: Dictionary = {}) -> Dictionary:
	var heat := clampf(float(music_state.get("heat", music_state.get("heat_level", 0.0))), 0.0, 100.0)
	var intensity := clampf(float(music_state.get("music_intensity", heat / 100.0)), 0.0, 1.0)
	var bucket_count := maxi(1, int(music_state.get("intensity_bucket_count", DEFAULT_INTENSITY_BUCKETS)))
	var tags := _string_array(music_state.get("music_tags", []))
	for automatic_tag in _automatic_tags(music_state, intensity):
		if not tags.has(automatic_tag):
			tags.append(automatic_tag)
	var harmonic_section := str(music_state.get("harmonic_section", profile.get("harmonic_section", ""))).strip_edges().to_upper()
	if harmonic_section.is_empty():
		var arrangement := _string_array(entry.get("arrangement", []))
		if not arrangement.is_empty():
			harmonic_section = str(arrangement[posmod(int(music_state.get("musical_bar", 0)), arrangement.size())]).to_upper()
	if harmonic_section.is_empty():
		harmonic_section = "A"
	return {
		"intensity": intensity,
		"intensity_bucket": mini(bucket_count - 1, floori(intensity * float(bucket_count))),
		"harmonic_section": harmonic_section,
		"tags": tags,
	}


static func _automatic_tags(music_state: Dictionary, intensity: float) -> Array[String]:
	var tags: Array[String] = []
	tags.append("intensity_low" if intensity < 0.34 else "intensity_mid" if intensity < 0.67 else "intensity_high")
	if bool(music_state.get("watched", false)) or bool(music_state.get("staff_attention_active", false)):
		tags.append("attention")
	if bool(music_state.get("showdown_pending", false)) or bool(music_state.get("showdown_active", false)) or bool(music_state.get("boss_floor", false)):
		tags.append("showdown")
	if int(music_state.get("alcohol_tier", 0)) > 0:
		tags.append("drunk")
	if bool(music_state.get("overdue_debt", false)) or float(music_state.get("bankroll_pressure", 0.0)) >= 0.5:
		tags.append("pressure")
	return tags


static func _bank_data(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_ARRAY:
		return {"variants": (value as Array).duplicate(true), "seed_salt": ""}
	if typeof(value) != TYPE_DICTIONARY:
		return {"variants": [], "seed_salt": ""}
	var bank := (value as Dictionary).duplicate(true)
	if typeof(bank.get("variants", [])) != TYPE_ARRAY:
		bank["variants"] = []
	return bank


static func _variant_matches(variant: Dictionary, context: Dictionary, selected_ids: Dictionary, selected_tags: Dictionary, selected_groups: Dictionary) -> bool:
	if not bool(variant.get("enabled", true)) or float(variant.get("weight", 1.0)) <= 0.0:
		return false
	var intensity := float(context.get("intensity", 0.0))
	if intensity + 0.0001 < float(variant.get("intensity_min", 0.0)) or intensity - 0.0001 > float(variant.get("intensity_max", 1.0)):
		return false
	var sections := _string_array(variant.get("harmonic_sections", variant.get("sections", [])))
	if not sections.is_empty() and not sections.has(str(context.get("harmonic_section", "A"))):
		return false
	for required_tag in _string_array(variant.get("requires_tags", [])):
		if not bool(selected_tags.get(required_tag, false)):
			return false
	for excluded_id in _string_array(variant.get("excludes", variant.get("exclude_ids", []))):
		if bool(selected_ids.get(excluded_id, false)):
			return false
	for excluded_tag in _string_array(variant.get("exclude_tags", [])):
		if bool(selected_tags.get(excluded_tag, false)):
			return false
	var group := str(variant.get("mutual_exclusion_group", variant.get("exclusive_group", ""))).strip_edges()
	return group.is_empty() or not selected_groups.has(group)


static func _weighted_pick(candidates: Array, seed: int) -> Dictionary:
	var total := 0.0
	for candidate_value in candidates:
		if typeof(candidate_value) == TYPE_DICTIONARY:
			total += maxf(0.0, float((candidate_value as Dictionary).get("weight", 1.0)))
	if total <= 0.0:
		return {}
	var unit := float(posmod(seed, 1000003)) / 1000003.0
	var cursor := unit * total
	for candidate_value in candidates:
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = candidate_value
		cursor -= maxf(0.0, float(candidate.get("weight", 1.0)))
		if cursor <= 0.0:
			return candidate.duplicate(true)
	return (candidates.back() as Dictionary).duplicate(true)


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) == TYPE_STRING:
		var text := str(value).strip_edges()
		if not text.is_empty():
			result.append(text)
	elif typeof(value) == TYPE_ARRAY:
		for item in value as Array:
			var text := str(item).strip_edges()
			if not text.is_empty() and not result.has(text):
				result.append(text)
	return result


static func _copy_dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _stable_hash(text: String) -> int:
	var value := 2166136261
	for index in range(text.length()):
		value = int((value ^ text.unicode_at(index)) * 16777619) & 0x7fffffff
	return value
