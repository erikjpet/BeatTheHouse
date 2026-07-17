class_name MusicLayerChoreography
extends RefCounted

const ROLE_ORDER := ["pad", "bass", "bass_dark", "lead", "drums_low", "drums_high", "drums_high_double", "tension", "texture"]
const ALLOWED_LEAD_IN_BARS := [1, 2, 4]


static func normalize_recipe(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = value
	var stages: Array = []
	var next_start := 0
	var stages_value: Variant = source.get("stages", [])
	if typeof(stages_value) != TYPE_ARRAY:
		return {}
	for stage_value in stages_value as Array:
		if typeof(stage_value) != TYPE_DICTIONARY:
			continue
		var stage: Dictionary = stage_value
		var stage_id := str(stage.get("id", "")).strip_edges()
		var duration_bars := maxi(1, int(stage.get("duration_bars", 1)))
		var start_bar := maxi(0, int(stage.get("start_bar", next_start)))
		var roles := _normalized_role_gains(stage.get("roles", {}))
		stages.append({
			"id": stage_id if not stage_id.is_empty() else "stage_%d" % stages.size(),
			"start_bar": start_bar,
			"duration_bars": duration_bars,
			"roles": roles,
			"request_fill": bool(stage.get("request_fill", false)),
			"fill_priority": maxi(0, int(stage.get("fill_priority", 20))),
			"change_roles": _string_array(stage.get("change_roles", [])),
		})
		next_start = start_bar + duration_bars
	if stages.is_empty():
		return {}
	stages.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("start_bar", 0)) < int(b.get("start_bar", 0)))
	var cycle_bars := maxi(next_start, int(source.get("cycle_bars", next_start)))
	return {
		"id": str(source.get("id", "layer_choreography")).strip_edges(),
		"cycle_bars": maxi(1, cycle_bars),
		"fade_beats": maxf(0.125, float(source.get("fade_beats", 1.0))),
		"default_lead_in_bars": _normalized_lead_in_bars(int(source.get("default_lead_in_bars", 2))),
		"fill_cooldown_bars": maxi(0, int(source.get("fill_cooldown_bars", 4))),
		"stages": stages,
	}


static func stage_for_bar(recipe_value: Variant, visit_bar: int) -> Dictionary:
	var recipe := normalize_recipe(recipe_value)
	if recipe.is_empty():
		return {}
	var stages: Array = recipe.get("stages", []) as Array
	var cycle_bar := posmod(maxi(0, visit_bar), maxi(1, int(recipe.get("cycle_bars", 1))))
	var selected: Dictionary = stages[0]
	var selected_index := 0
	for index in range(stages.size()):
		var candidate: Dictionary = stages[index]
		if cycle_bar < int(candidate.get("start_bar", 0)):
			break
		selected = candidate
		selected_index = index
	var result := selected.duplicate(true)
	result["index"] = selected_index
	result["visit_bar"] = maxi(0, visit_bar)
	result["cycle_bar"] = cycle_bar
	result["cycle_index"] = maxi(0, visit_bar) / maxi(1, int(recipe.get("cycle_bars", 1)))
	result["next_boundary_bar"] = next_stage_boundary_bar(recipe, visit_bar)
	return result


static func next_stage_boundary_bar(recipe_value: Variant, visit_bar: int) -> int:
	var recipe := normalize_recipe(recipe_value)
	if recipe.is_empty():
		return -1
	var cycle_bars := maxi(1, int(recipe.get("cycle_bars", 1)))
	var cycle_index := maxi(0, visit_bar) / cycle_bars
	var cycle_start := cycle_index * cycle_bars
	var cycle_bar := posmod(maxi(0, visit_bar), cycle_bars)
	for stage_value in recipe.get("stages", []) as Array:
		var start_bar := int((stage_value as Dictionary).get("start_bar", 0))
		if start_bar > cycle_bar:
			return cycle_start + start_bar
	return cycle_start + cycle_bars


static func timeline_snapshot(recipe_value: Variant, bar_count: int) -> Array:
	var recipe := normalize_recipe(recipe_value)
	var result: Array = []
	if recipe.is_empty():
		return result
	for bar in range(maxi(0, bar_count)):
		var stage := stage_for_bar(recipe, bar)
		result.append({
			"bar": bar,
			"stage_id": str(stage.get("id", "")),
			"stage_index": int(stage.get("index", -1)),
			"roles": (stage.get("roles", {}) as Dictionary).duplicate(true),
			"next_boundary_bar": int(stage.get("next_boundary_bar", -1)),
		})
	return result


static func resolve_fill_request(fill_metadata_value: Variant, requests_value: Variant, default_lead_in_bars: int = 2) -> Dictionary:
	var fills: Dictionary = fill_metadata_value as Dictionary if typeof(fill_metadata_value) == TYPE_DICTIONARY else {}
	var requests: Array = requests_value as Array if typeof(requests_value) == TYPE_ARRAY else []
	var ranked: Array = []
	for request_value in requests:
		if typeof(request_value) != TYPE_DICTIONARY:
			continue
		var request: Dictionary = request_value
		var normalized := request.duplicate(true)
		var kind := str(normalized.get("kind", "layer")).strip_edges().to_lower()
		var base_priority := 100 if kind == "section" else 20
		normalized["priority"] = maxi(base_priority, int(normalized.get("priority", base_priority)))
		normalized["id"] = str(normalized.get("id", "%s_%d" % [kind, ranked.size()]))
		ranked.append(normalized)
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var priority_a := int(a.get("priority", 0))
		var priority_b := int(b.get("priority", 0))
		return str(a.get("id", "")) < str(b.get("id", "")) if priority_a == priority_b else priority_a > priority_b
	)
	for request_value in ranked:
		var request: Dictionary = request_value
		var candidates: Array = []
		for fill_value in fills.keys():
			var fill_id := str(fill_value)
			var metadata_value: Variant = fills.get(fill_value)
			if typeof(metadata_value) != TYPE_DICTIONARY:
				continue
			var metadata: Dictionary = metadata_value
			if not _fill_is_compatible(metadata, request):
				continue
			candidates.append({"fill_id": fill_id, "metadata": metadata, "priority": int(metadata.get("priority", 0))})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var priority_a := int(a.get("priority", 0))
			var priority_b := int(b.get("priority", 0))
			return str(a.get("fill_id", "")) < str(b.get("fill_id", "")) if priority_a == priority_b else priority_a > priority_b
		)
		if candidates.is_empty():
			continue
		var winner: Dictionary = candidates[0]
		var metadata: Dictionary = winner.get("metadata", {}) as Dictionary
		return {
			"request_id": str(request.get("id", "")),
			"request_kind": str(request.get("kind", "layer")),
			"request_priority": int(request.get("priority", 0)),
			"fill_id": str(winner.get("fill_id", "")),
			"lead_in_bars": _normalized_lead_in_bars(int(metadata.get("lead_in_bars", request.get("lead_in_bars", default_lead_in_bars)))),
			"quiet_fallback": false,
			"compatible": true,
		}
	var fallback_request: Dictionary = ranked[0] if not ranked.is_empty() else {}
	return {
		"request_id": str(fallback_request.get("id", "")),
		"request_kind": str(fallback_request.get("kind", "layer")),
		"request_priority": int(fallback_request.get("priority", 0)),
		"fill_id": "",
		"lead_in_bars": _normalized_lead_in_bars(int(fallback_request.get("lead_in_bars", default_lead_in_bars))),
		"quiet_fallback": not fallback_request.is_empty(),
		"compatible": false,
	}


static func _fill_is_compatible(metadata: Dictionary, request: Dictionary) -> bool:
	if bool(metadata.get("loop", false)):
		return false
	var source_section := str(request.get("source_section", "")).strip_edges().to_upper()
	var destination_section := str(request.get("destination_section", "")).strip_edges().to_upper()
	var destination_progression := str(request.get("destination_progression_id", request.get("progression_id", ""))).strip_edges()
	var source_sections := _upper_string_array(metadata.get("source_sections", []))
	var destination_sections := _upper_string_array(metadata.get("destination_sections", metadata.get("harmonic_sections", [])))
	var progressions := _string_array(metadata.get("progression_compatibility", []))
	if not source_sections.is_empty() and not source_sections.has(source_section):
		return false
	if not destination_sections.is_empty() and not destination_sections.has(destination_section):
		return false
	if not progressions.is_empty() and not destination_progression.is_empty() and not progressions.has(destination_progression):
		return false
	var introduced_roles := _string_array(metadata.get("introduces_roles", []))
	var change_roles := _string_array(request.get("change_roles", []))
	if not introduced_roles.is_empty() and not change_roles.is_empty():
		var overlaps := false
		for role in change_roles:
			if introduced_roles.has(role):
				overlaps = true
				break
		if not overlaps:
			return false
	return true


static func _normalized_role_gains(value: Variant) -> Dictionary:
	var source: Dictionary = value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
	var result := {}
	for role in ROLE_ORDER:
		result[role] = clampf(float(source.get(role, 0.0)), 0.0, 1.0)
	return result


static func _normalized_lead_in_bars(value: int) -> int:
	return value if ALLOWED_LEAD_IN_BARS.has(value) else 2


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value as Array:
		var text := str(item).strip_edges()
		if not text.is_empty() and not result.has(text):
			result.append(text)
	return result


static func _upper_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	for item in _string_array(value):
		var text := item.to_upper()
		if not result.has(text):
			result.append(text)
	return result
