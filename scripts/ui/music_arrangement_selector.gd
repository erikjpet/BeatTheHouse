class_name MusicArrangementSelector
extends RefCounted

# Deterministic authored-stem bank selection. The selector works on manifest
# data only so the same decisions are available in headless tests and builds.

const DEFAULT_INTENSITY_BUCKETS := 10


static func select(entry: Dictionary, profile: Dictionary, music_state: Dictionary = {}) -> Dictionary:
	if has_compatibility_sets(entry):
		return _select_compatibility_arrangement(entry, profile, music_state)
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


static func has_compatibility_sets(entry: Dictionary) -> bool:
	return typeof(entry.get("compatibility_sets", [])) == TYPE_ARRAY and not (entry.get("compatibility_sets", []) as Array).is_empty()


static func recipe_definition(entry: Dictionary, recipe_id: String = "") -> Dictionary:
	var recipes_value: Variant = entry.get("arrangement_recipes", [])
	if typeof(recipes_value) != TYPE_ARRAY:
		return {}
	var first: Dictionary = {}
	for recipe_value in recipes_value as Array:
		if typeof(recipe_value) != TYPE_DICTIONARY:
			continue
		var recipe := (recipe_value as Dictionary).duplicate(true)
		if first.is_empty():
			first = recipe
		if not recipe_id.is_empty() and str(recipe.get("id", "")) == recipe_id:
			return recipe
	return first


static func initial_recipe_state(entry: Dictionary, run_seed: Variant = "", visit_id: String = "") -> Dictionary:
	var recipe := recipe_definition(entry)
	var sections := _ordered_string_array(recipe.get("sections", []))
	return {
		"track_id": str(entry.get("id", "")),
		"recipe_id": str(recipe.get("id", "")),
		"cursor": 0,
		"harmonic_section": str(sections[0]).to_upper() if not sections.is_empty() else "A",
		"last_phrase_event_index": -1,
		"last_phrase_event_token": "",
		"section_history": [],
		"run_seed": str(run_seed),
		"visit_id": visit_id,
	}


static func advance_recipe_state(entry: Dictionary, state: Dictionary, phrase_event: Dictionary) -> Dictionary:
	var result := state.duplicate(true)
	if result.is_empty():
		result = initial_recipe_state(entry, phrase_event.get("run_seed", ""), str(phrase_event.get("visit_id", "")))
	var event_index := int(phrase_event.get("phrase_event_index", phrase_event.get("index", -1)))
	var event_token := str(phrase_event.get("event_token", phrase_event.get("token", ""))).strip_edges()
	var last_index := int(result.get("last_phrase_event_index", -1))
	if event_index < 0 or event_index <= last_index or event_index != last_index + 1:
		result["event_accepted"] = false
		return result
	if not event_token.is_empty() and event_token == str(result.get("last_phrase_event_token", "")):
		result["event_accepted"] = false
		return result
	var recipe := recipe_definition(entry, str(result.get("recipe_id", "")))
	var sections := _ordered_string_array(recipe.get("sections", []))
	if sections.is_empty():
		result["event_accepted"] = false
		return result
	var cursor := int(result.get("cursor", -1)) + 1
	var section := str(sections[posmod(cursor, sections.size())]).to_upper()
	var history := _string_array(result.get("section_history", []))
	history.append(section)
	while history.size() > 8:
		history.pop_front()
	result["cursor"] = cursor
	result["harmonic_section"] = section
	result["last_phrase_event_index"] = event_index
	result["last_phrase_event_token"] = event_token
	result["section_history"] = history
	result["event_accepted"] = true
	return result


static func _select_compatibility_arrangement(entry: Dictionary, profile: Dictionary, music_state: Dictionary) -> Dictionary:
	var track_id := str(entry.get("id", "")).strip_edges()
	var context := selection_context(profile, music_state, entry)
	var arrangement_state := _copy_dict(music_state.get("music_arrangement_state", music_state.get("arrangement_state", {})))
	if arrangement_state.is_empty():
		arrangement_state = initial_recipe_state(entry, music_state.get("run_seed", ""), str(music_state.get("music_visit_id", "")))
	var active_section := str(arrangement_state.get("harmonic_section", context.get("harmonic_section", "A"))).to_upper()
	context["harmonic_section"] = active_section
	context["recipe_id"] = str(arrangement_state.get("recipe_id", ""))
	context["recipe_cursor"] = int(arrangement_state.get("cursor", -1))
	context["visit_id"] = str(arrangement_state.get("visit_id", music_state.get("music_visit_id", "")))
	var sets: Array = entry.get("compatibility_sets", []) as Array
	var set_candidates: Array = []
	var excluded: Array = []
	for set_value in sets:
		if typeof(set_value) != TYPE_DICTIONARY:
			continue
		var set_data := (set_value as Dictionary).duplicate(true)
		var reasons: Array[String] = []
		if not bool(set_data.get("enabled", true)) or float(set_data.get("weight", 1.0)) <= 0.0:
			reasons.append("disabled_or_zero_weight")
		var sections := _string_array(set_data.get("harmonic_sections", set_data.get("sections", [])))
		if not sections.is_empty() and not sections.has(active_section):
			reasons.append("harmonic_section")
		if reasons.is_empty():
			set_candidates.append(set_data)
		else:
			excluded.append({"kind": "compatibility_set", "id": str(set_data.get("id", "")), "reasons": reasons})
	if set_candidates.is_empty():
		return _compatibility_failure(context, excluded, "no_compatible_set")
	var history_text := ">".join(_string_array(arrangement_state.get("section_history", [])))
	var set_seed := "%s|%s|%s|%s|%s|%s|cursor=%d|event=%d" % [track_id, str(music_state.get("run_seed", arrangement_state.get("run_seed", ""))), str(context.get("visit_id", "")), active_section, str(context.get("recipe_id", "")), history_text, int(arrangement_state.get("cursor", 0)), int(arrangement_state.get("last_phrase_event_index", -1))]
	var selected_set := _weighted_pick(set_candidates, _stable_hash(set_seed))
	var selected_set_id := str(selected_set.get("id", ""))
	var selected_progression_id := str(selected_set.get("progression_id", selected_set_id))
	var allowed_roles := _copy_dict(selected_set.get("roles", {}))
	var banks := _copy_dict(entry.get("stem_banks", {}))
	var selected_stems := {}
	var selected_variants := {}
	var selected_ids := {}
	var selected_tags := {}
	var selected_groups := {}
	var selected_role_epochs := {}
	var recipe := recipe_definition(entry, str(arrangement_state.get("recipe_id", "")))
	var role_policies := _copy_dict(recipe.get("role_policies", {}))
	var prior_variant_ids := _copy_dict(arrangement_state.get("selected_variant_ids", {}))
	var prior_role_epochs := _copy_dict(arrangement_state.get("selected_role_epochs", {}))
	var selection_memory_ids := prior_variant_ids.duplicate(true)
	var selection_memory_epochs := prior_role_epochs.duplicate(true)
	var target_role_epochs := _copy_dict(arrangement_state.get("role_epochs", {}))
	for tag_value in context.get("tags", []):
		selected_tags[str(tag_value)] = true
	var roles := allowed_roles.keys()
	roles.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for role_value in roles:
		var role := str(role_value)
		var allowed_ids := _string_array(allowed_roles.get(role_value))
		var bank := _bank_data(banks.get(role))
		var candidates: Array = []
		for variant_value in bank.get("variants", []):
			if typeof(variant_value) != TYPE_DICTIONARY:
				continue
			var variant := (variant_value as Dictionary).duplicate(true)
			var variant_id := str(variant.get("id", ""))
			var reasons := _variant_exclusion_reasons(variant, context, selected_ids, selected_tags, selected_groups)
			if not allowed_ids.has(variant_id):
				reasons.append("not_in_compatibility_set")
			if not _string_array(variant.get("progression_compatibility", [])).has(selected_progression_id):
				reasons.append("progression_incompatible")
			if reasons.is_empty():
				candidates.append(variant)
			else:
				excluded.append({"kind": "variant", "role": role, "id": variant_id, "reasons": reasons})
		if candidates.is_empty():
			continue
		var policy := _copy_dict(role_policies.get(role, {}))
		var change_every := maxi(1, int(policy.get("change_every", 1)))
		var target_epoch := int(target_role_epochs.get(role, maxi(0, int(arrangement_state.get("cursor", -1))) / change_every))
		var memory_key := "%s:%s" % [selected_set_id, role]
		var prior_id := str(prior_variant_ids.get(memory_key, prior_variant_ids.get(role, "")))
		var prior_epoch := int(prior_role_epochs.get(memory_key, prior_role_epochs.get(role, -1)))
		var contrast_set_id := str(selected_set.get("contrast_with_set_id", "")).strip_edges()
		var force_contrast := not contrast_set_id.is_empty() and _string_array(selected_set.get("force_change_roles", [])).has(role)
		if force_contrast:
			prior_id = str(prior_variant_ids.get("%s:%s" % [contrast_set_id, role], ""))
		var role_seed := "%s|%s|%s|%s|%s|%s" % [set_seed, selected_set_id, role, str(bank.get("seed_salt", "")), int(context.get("intensity_bucket", 0)), history_text]
		var selected: Dictionary = {}
		if not force_contrast and bool(policy.get("retain", false)) and prior_epoch == target_epoch:
			for candidate_value in candidates:
				if str((candidate_value as Dictionary).get("id", "")) == prior_id:
					selected = (candidate_value as Dictionary).duplicate(true)
					break
		if selected.is_empty() and not prior_id.is_empty() and (force_contrast or (prior_epoch >= 0 and prior_epoch != target_epoch)) and candidates.size() > 1:
			var changed_candidates: Array = []
			for candidate_value in candidates:
				if str((candidate_value as Dictionary).get("id", "")) != prior_id:
					changed_candidates.append(candidate_value)
			if not changed_candidates.is_empty():
				candidates = changed_candidates
		if selected.is_empty():
			selected = _weighted_pick(candidates, _stable_hash("%s|epoch=%d" % [role_seed, target_epoch]))
		var selected_id := str(selected.get("id", ""))
		selected_stems[role] = selected.duplicate(true)
		selected_variants[role] = {"id": selected_id, "weight": float(selected.get("weight", 1.0)), "tags": _string_array(selected.get("tags", [])), "harmonic_section": active_section, "intensity": float(context.get("intensity", 0.0)), "compatibility_set_id": selected_set_id}
		selected_ids[selected_id] = true
		selected_role_epochs[role] = target_epoch
		selection_memory_ids[memory_key] = selected_id
		selection_memory_epochs[memory_key] = target_epoch
		for tag_value in _string_array(selected.get("tags", [])):
			selected_tags[tag_value] = true
		var group := str(selected.get("mutual_exclusion_group", selected.get("exclusive_group", ""))).strip_edges()
		if not group.is_empty():
			selected_groups[group] = selected_id
	var required_roles := _string_array(entry.get("compatibility_required_roles", selected_set.get("required_roles", [])))
	var missing_roles: Array[String] = []
	for role in required_roles:
		if not selected_stems.has(role):
			missing_roles.append(role)
	if not missing_roles.is_empty():
		excluded.append({"kind": "compatibility_set", "id": selected_set_id, "reasons": ["missing_required_roles"], "roles": missing_roles})
		return _compatibility_failure(context, excluded, "missing_required_roles")
	var signature_parts: Array[String] = ["section=%s" % active_section, "set=%s" % selected_set_id]
	for role_value in selected_variants.keys():
		signature_parts.append("%s=%s" % [str(role_value), str((selected_variants[role_value] as Dictionary).get("id", ""))])
	signature_parts.sort()
	var tags := selected_tags.keys()
	tags.sort()
	return {"stems": selected_stems, "selected_variants": selected_variants, "selected_tags": tags, "selected_groups": selected_groups, "selected_role_epochs": selected_role_epochs, "selection_memory_ids": selection_memory_ids, "selection_memory_epochs": selection_memory_epochs, "selection_context": context, "selection_key": ",".join(signature_parts), "compatibility_set_id": selected_set_id, "progression_id": selected_progression_id, "recipe_state": arrangement_state, "excluded_candidates": excluded, "valid": true}


static func _compatibility_failure(context: Dictionary, excluded: Array, reason: String) -> Dictionary:
	return {"stems": {}, "selected_variants": {}, "selected_tags": [], "selected_groups": {}, "selection_context": context, "selection_key": "invalid:%s" % reason, "compatibility_set_id": "", "progression_id": "", "excluded_candidates": excluded, "valid": false, "failure_reason": reason}


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
	return _variant_exclusion_reasons(variant, context, selected_ids, selected_tags, selected_groups).is_empty()


static func _variant_exclusion_reasons(variant: Dictionary, context: Dictionary, selected_ids: Dictionary, selected_tags: Dictionary, selected_groups: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	if not bool(variant.get("enabled", true)) or float(variant.get("weight", 1.0)) <= 0.0:
		reasons.append("disabled_or_zero_weight")
	var intensity := float(context.get("intensity", 0.0))
	if intensity + 0.0001 < float(variant.get("intensity_min", 0.0)) or intensity - 0.0001 > float(variant.get("intensity_max", 1.0)):
		reasons.append("intensity")
	var sections := _string_array(variant.get("harmonic_sections", variant.get("sections", [])))
	if not sections.is_empty() and not sections.has(str(context.get("harmonic_section", "A"))):
		reasons.append("harmonic_section")
	for required_tag in _string_array(variant.get("requires_tags", [])):
		if not bool(selected_tags.get(required_tag, false)):
			reasons.append("missing_tag:%s" % required_tag)
	for excluded_id in _string_array(variant.get("excludes", variant.get("exclude_ids", []))):
		if bool(selected_ids.get(excluded_id, false)):
			reasons.append("excluded_id:%s" % excluded_id)
	for excluded_tag in _string_array(variant.get("exclude_tags", [])):
		if bool(selected_tags.get(excluded_tag, false)):
			reasons.append("excluded_tag:%s" % excluded_tag)
	var group := str(variant.get("mutual_exclusion_group", variant.get("exclusive_group", ""))).strip_edges()
	if not group.is_empty() and selected_groups.has(group):
		reasons.append("mutual_exclusion_group:%s" % group)
	return reasons


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


static func _ordered_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) == TYPE_STRING:
		var text := str(value).strip_edges()
		if not text.is_empty():
			result.append(text)
	elif typeof(value) == TYPE_ARRAY:
		for item in value as Array:
			var text := str(item).strip_edges()
			if not text.is_empty():
				result.append(text)
	return result


static func _copy_dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _stable_hash(text: String) -> int:
	var value := 2166136261
	for index in range(text.length()):
		value = int((value ^ text.unicode_at(index)) * 16777619) & 0x7fffffff
	return value
