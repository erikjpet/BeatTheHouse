class_name ScratchTicketMask
extends RefCounted

const RegionModelScript := preload("res://scripts/games/scratch_ticket_region_model.gd")
const MASK_COLUMNS := 256
const MASK_ROWS := 192
const DEFAULT_BRUSH_RADIUS := 15.0
const DEFAULT_PASS_REMOVAL := 0.66
const DEFAULT_SWEEP_THRESHOLD := 0.80

static var _layout_templates: Dictionary = {}


static func prime(ticket_type: Dictionary) -> void:
	var type_id := str(ticket_type.get("id", ""))
	if type_id.is_empty():
		return
	_template_for(type_id, RegionModelScript.layout_template(type_id))


static func initialize(ticket: Dictionary, ticket_type: Dictionary) -> void:
	var scratch: Dictionary = ticket_type.get("scratch", {}) if typeof(ticket_type.get("scratch", {})) == TYPE_DICTIONARY else {}
	scratch = scratch.duplicate(true)
	scratch["mask_columns"] = MASK_COLUMNS
	scratch["mask_rows"] = MASK_ROWS
	scratch["brush_radius"] = maxf(8.0, float(scratch.get("brush_radius", DEFAULT_BRUSH_RADIUS)))
	scratch["pass_removal"] = clampf(float(scratch.get("pass_removal", DEFAULT_PASS_REMOVAL)), 0.10, 0.90)
	scratch["sweep_threshold"] = clampf(float(scratch.get("sweep_threshold", DEFAULT_SWEEP_THRESHOLD)), 0.50, 0.98)
	scratch["mask_kind"] = "continuous_high_resolution"
	ticket["scratch"] = scratch
	var regions := RegionModelScript.build(ticket)
	var template := _template_for(str(ticket.get("type_id", "")), regions)
	var mask: Array = (template.get("mask", []) as Array).duplicate()
	var sample_totals: Array = template.get("sample_totals", []) as Array
	for region_index in range(regions.size()):
		var region: Dictionary = regions[region_index]
		var sample_total := int(sample_totals[region_index]) if region_index < sample_totals.size() else 0
		region["sample_total"] = sample_total
		region["mask_remaining_units"] = sample_total * 255
		region["coverage"] = 0.0
		region["revealed"] = false
		regions[region_index] = region
	ticket["scratch_regions"] = regions
	ticket["sections"] = sections_from_regions(regions)
	ticket["latex_mask"] = mask
	ticket["mask_revision"] = 0
	ticket["region_layout_version"] = RegionModelScript.LAYOUT_VERSION
	ticket["result_ready"] = false


static func _template_for(type_id: String, regions: Array) -> Dictionary:
	var key := "%s:%d:%dx%d" % [type_id, RegionModelScript.LAYOUT_VERSION, MASK_COLUMNS, MASK_ROWS]
	var cached_value: Variant = _layout_templates.get(key, {})
	if typeof(cached_value) == TYPE_DICTIONARY and not (cached_value as Dictionary).is_empty():
		return cached_value as Dictionary
	var mask: Array = []
	mask.resize(MASK_COLUMNS * MASK_ROWS)
	mask.fill(0)
	var sample_totals: Array = []
	for region_value in regions:
		var region: Dictionary = region_value
		sample_totals.append(_rasterize_region(mask, region, 255))
	var built := {"mask": mask, "sample_totals": sample_totals}
	_layout_templates[key] = built
	return built


static func ensure(ticket: Dictionary) -> void:
	if ticket.is_empty():
		return
	var scratch: Dictionary = ticket.get("scratch", {}) if typeof(ticket.get("scratch", {})) == TYPE_DICTIONARY else {}
	var mask: Array = ticket.get("latex_mask", []) if typeof(ticket.get("latex_mask", [])) == TYPE_ARRAY else []
	var old_regions := _dictionary_array(ticket.get("scratch_regions", []))
	var current := int(ticket.get("region_layout_version", 0)) == RegionModelScript.LAYOUT_VERSION
	current = current and int(scratch.get("mask_columns", 0)) == MASK_COLUMNS and int(scratch.get("mask_rows", 0)) == MASK_ROWS
	current = current and mask.size() == MASK_COLUMNS * MASK_ROWS and not old_regions.is_empty()
	if current:
		return
	var progress_by_id: Dictionary = {}
	for region_value in old_regions:
		var old_region: Dictionary = region_value
		progress_by_id[str(old_region.get("id", ""))] = _region_progress(old_region)
	var fallback_revealed := bool(ticket.get("result_ready", false))
	var ticket_type := {"scratch": scratch}
	initialize(ticket, ticket_type)
	var regions := _dictionary_array(ticket.get("scratch_regions", []))
	mask = ticket.get("latex_mask", []) as Array
	for region_index in range(regions.size()):
		var region: Dictionary = regions[region_index]
		var progress := float(progress_by_id.get(str(region.get("id", "")), 1.0 if fallback_revealed else 0.0))
		if progress <= 0.0:
			continue
		if progress >= 0.995:
			_clear_region(mask, region)
			region["coverage"] = 1.0
			region["revealed"] = true
			region["mask_remaining_units"] = 0
		else:
			_apply_linear_progress(mask, region, progress)
			var remaining_units := _remaining_units(mask, region)
			region["mask_remaining_units"] = remaining_units
			region["coverage"] = 1.0 - float(remaining_units) / float(maxi(1, int(region.get("sample_total", 0)) * 255))
		regions[region_index] = region
	ticket["scratch_regions"] = regions
	ticket["sections"] = sections_from_regions(regions)
	ticket["latex_mask"] = mask
	ticket["mask_revision"] = int(ticket.get("mask_revision", 0)) + 1
	ticket["result_ready"] = ticket_complete(ticket)


static func scratch(ticket: Dictionary, from: Vector2, to: Vector2, ticket_rect: Rect2) -> Dictionary:
	ensure(ticket)
	var scratch_data: Dictionary = ticket.get("scratch", {}) if typeof(ticket.get("scratch", {})) == TYPE_DICTIONARY else {}
	var brush_radius := maxf(8.0, float(scratch_data.get("brush_radius", DEFAULT_BRUSH_RADIUS)))
	var pass_removal := clampf(float(scratch_data.get("pass_removal", DEFAULT_PASS_REMOVAL)), 0.10, 0.90)
	var threshold := clampf(float(scratch_data.get("sweep_threshold", DEFAULT_SWEEP_THRESHOLD)), 0.50, 0.98)
	var mask: Array = ticket.get("latex_mask", []) if typeof(ticket.get("latex_mask", [])) == TYPE_ARRAY else []
	var regions: Array = ticket.get("scratch_regions", []) if typeof(ticket.get("scratch_regions", [])) == TYPE_ARRAY else []
	if mask.size() != MASK_COLUMNS * MASK_ROWS or regions.is_empty():
		return {"erased_samples": 0, "message": "This ticket's coating is damaged."}
	var bounds := Rect2(Vector2(minf(from.x, to.x), minf(from.y, to.y)), Vector2(absf(to.x - from.x), absf(to.y - from.y))).grow(brush_radius)
	if not ticket_rect.intersects(bounds):
		return {"erased_samples": 0, "message": "Drag across the printed coating."}
	var clipped := bounds.intersection(ticket_rect)
	var column_start := clampi(floori((clipped.position.x - ticket_rect.position.x) / ticket_rect.size.x * MASK_COLUMNS), 0, MASK_COLUMNS - 1)
	var column_end := clampi(ceili((clipped.end.x - ticket_rect.position.x) / ticket_rect.size.x * MASK_COLUMNS), column_start + 1, MASK_COLUMNS)
	var row_start := clampi(floori((clipped.position.y - ticket_rect.position.y) / ticket_rect.size.y * MASK_ROWS), 0, MASK_ROWS - 1)
	var row_end := clampi(ceili((clipped.end.y - ticket_rect.position.y) / ticket_rect.size.y * MASK_ROWS), row_start + 1, MASK_ROWS)
	var erased_samples := 0
	var erased_units := 0
	var segment := to - from
	var segment_length_squared := segment.length_squared()
	var radius_squared := brush_radius * brush_radius
	var sample_step_x := ticket_rect.size.x / float(MASK_COLUMNS)
	var sample_step_y := ticket_rect.size.y / float(MASK_ROWS)
	for region_index in range(regions.size()):
		var region: Dictionary = regions[region_index]
		if bool(region.get("revealed", false)):
			continue
		var region_range := _region_ranges(region)
		var region_column_start := maxi(column_start, int(region_range[0]))
		var region_column_end := mini(column_end, int(region_range[1]))
		var region_row_start := maxi(row_start, int(region_range[2]))
		var region_row_end := mini(row_end, int(region_range[3]))
		if region_column_start >= region_column_end or region_row_start >= region_row_end:
			continue
		var removed_from_region := 0
		for row in range(region_row_start, region_row_end):
			var offset := row * MASK_COLUMNS
			var sample_y := ticket_rect.position.y + (float(row) + 0.5) * sample_step_y
			for column in range(region_column_start, region_column_end):
				var sample_index := offset + column
				var old_alpha := int(mask[sample_index])
				if old_alpha <= 0:
					continue
				var sample_x := ticket_rect.position.x + (float(column) + 0.5) * sample_step_x
				var relative_x := sample_x - from.x
				var relative_y := sample_y - from.y
				var projection := 0.0
				if segment_length_squared > 0.0001:
					projection = clampf((relative_x * segment.x + relative_y * segment.y) / segment_length_squared, 0.0, 1.0)
				var distance_x := relative_x - segment.x * projection
				var distance_y := relative_y - segment.y * projection
				var distance_squared := distance_x * distance_x + distance_y * distance_y
				if distance_squared > radius_squared:
					continue
				var distance := sqrt(distance_squared)
				var edge_falloff := 1.0 - smoothstep(brush_radius * 0.58, brush_radius, distance)
				var removal := clampf(pass_removal * lerpf(0.24, 1.0, edge_falloff), 0.05, pass_removal)
				var new_alpha := 0 if edge_falloff >= 0.72 or old_alpha <= 2 else clampi(int(round(float(old_alpha) * (1.0 - removal))), 0, old_alpha - 1)
				var removed := old_alpha - new_alpha
				mask[sample_index] = new_alpha
				erased_samples += 1
				erased_units += removed
				removed_from_region += removed
		if removed_from_region > 0:
			region["mask_remaining_units"] = maxi(0, int(region.get("mask_remaining_units", 0)) - removed_from_region)
			regions[region_index] = region
	var swept_regions: Array = []
	for region_index in range(regions.size()):
		var region: Dictionary = regions[region_index]
		if bool(region.get("revealed", false)):
			continue
		var total_units := maxi(1, int(region.get("sample_total", 0)) * 255)
		var coverage := 1.0 - float(region.get("mask_remaining_units", total_units)) / float(total_units)
		region["coverage"] = clampf(coverage, 0.0, 1.0)
		if coverage >= threshold:
			_clear_region(mask, region)
			region["revealed"] = true
			region["coverage"] = 1.0
			region["mask_remaining_units"] = 0
			swept_regions.append(region)
		regions[region_index] = region
	ticket["latex_mask"] = mask
	ticket["scratch_regions"] = regions
	ticket["sections"] = sections_from_regions(regions)
	ticket["mask_revision"] = int(ticket.get("mask_revision", 0)) + 1
	var complete := ticket_complete(ticket)
	ticket["result_ready"] = complete
	var interpolated_dabs := maxi(1, ceili(from.distance_to(to) / maxf(2.0, brush_radius * 0.32)))
	var message := "The coating lifts in a clean, soft trail."
	if not swept_regions.is_empty():
		message = "%s clears clean." % str((swept_regions[0] as Dictionary).get("label", "That spot"))
	return {
		"erased_samples": erased_samples,
		"erased_units": erased_units,
		"interpolated_dabs": interpolated_dabs,
		"swept_sections": swept_regions,
		"swept_regions": swept_regions,
		"penalty": 0,
		"ticket_complete": complete,
		"message": message,
	}


static func reveal_all(ticket: Dictionary) -> void:
	ensure(ticket)
	var mask: Array = ticket.get("latex_mask", []) if typeof(ticket.get("latex_mask", [])) == TYPE_ARRAY else []
	mask.fill(0)
	var regions := _dictionary_array(ticket.get("scratch_regions", []))
	for index in range(regions.size()):
		var region: Dictionary = regions[index]
		region["revealed"] = true
		region["coverage"] = 1.0
		region["mask_remaining_units"] = 0
		regions[index] = region
	ticket["latex_mask"] = mask
	ticket["scratch_regions"] = regions
	ticket["sections"] = sections_from_regions(regions)
	ticket["mask_revision"] = int(ticket.get("mask_revision", 0)) + 1
	ticket["result_ready"] = true


static func compact_settled(ticket: Dictionary) -> Dictionary:
	# A filed ticket is a receipt, not a scratch surface. Keeping its 49,152
	# mask samples makes every later save, travel snapshot, and conversation
	# pay for presentation data that can never be interacted with again.
	var receipt := ticket.duplicate(false)
	receipt.erase("latex_mask")
	receipt.erase("scratch_regions")
	receipt.erase("sections")
	receipt.erase("mask_revision")
	receipt["mask_compacted"] = true
	return receipt


static func ticket_complete(ticket: Dictionary) -> bool:
	var regions := _dictionary_array(ticket.get("scratch_regions", []))
	if regions.is_empty():
		return false
	for region_value in regions:
		if not bool((region_value as Dictionary).get("revealed", false)):
			return false
	return true


static func sections_from_regions(regions: Array) -> Array:
	var by_id: Dictionary = {}
	var order: Array = []
	for region_value in regions:
		var region: Dictionary = region_value
		var section_id := str(region.get("section_id", "play"))
		if not by_id.has(section_id):
			by_id[section_id] = {"id": section_id, "label": section_id.to_upper().replace("_", " "), "sample_total": 0, "mask_remaining_units": 0, "coverage": 0.0, "revealed": true}
			order.append(section_id)
		var section: Dictionary = by_id[section_id]
		section["sample_total"] = int(section.get("sample_total", 0)) + int(region.get("sample_total", 0))
		section["mask_remaining_units"] = int(section.get("mask_remaining_units", 0)) + int(region.get("mask_remaining_units", 0))
		section["revealed"] = bool(section.get("revealed", true)) and bool(region.get("revealed", false))
		by_id[section_id] = section
	var result: Array = []
	for section_id in order:
		var section: Dictionary = by_id[section_id]
		var total_units := maxi(1, int(section.get("sample_total", 0)) * 255)
		section["coverage"] = 1.0 - float(section.get("mask_remaining_units", total_units)) / float(total_units)
		result.append(section)
	return result


static func _rasterize_region(mask: Array, region: Dictionary, alpha: int) -> int:
	var ranges := _region_ranges(region)
	var changed := 0
	for row in range(int(ranges[2]), int(ranges[3])):
		var offset := row * MASK_COLUMNS
		for column in range(int(ranges[0]), int(ranges[1])):
			if not _sample_inside_region(region, column, row):
				continue
			var index := offset + column
			if int(mask[index]) == alpha:
				continue
			mask[index] = alpha
			changed += 1
	return changed


static func _clear_region(mask: Array, region: Dictionary) -> void:
	var ranges := _region_ranges(region)
	for row in range(int(ranges[2]), int(ranges[3])):
		var offset := row * MASK_COLUMNS
		for column in range(int(ranges[0]), int(ranges[1])):
			if _sample_inside_region(region, column, row):
				mask[offset + column] = 0


static func _apply_linear_progress(mask: Array, region: Dictionary, progress: float) -> void:
	var ranges := _region_ranges(region)
	# Migration preserves the old completion percentage exactly (to one mask
	# sample), including ellipses whose cleared area is not linear in width.
	var target := clampi(roundi(float(region.get("sample_total", 0)) * progress), 0, int(region.get("sample_total", 0)))
	var cleared := 0
	for column in range(int(ranges[0]), int(ranges[1])):
		for row in range(int(ranges[2]), int(ranges[3])):
			if cleared >= target:
				return
			if _sample_inside_region(region, column, row):
				mask[row * MASK_COLUMNS + column] = 0
				cleared += 1


static func _remaining_units(mask: Array, region: Dictionary) -> int:
	var ranges := _region_ranges(region)
	var total := 0
	for row in range(int(ranges[2]), int(ranges[3])):
		var offset := row * MASK_COLUMNS
		for column in range(int(ranges[0]), int(ranges[1])):
			if _sample_inside_region(region, column, row):
				total += int(mask[offset + column])
	return total


static func _sample_inside_region(region: Dictionary, column: int, row: int) -> bool:
	if str(region.get("mask_shape", "rect")) != "ellipse":
		return true
	var values: Array = region.get("art_rect", []) if typeof(region.get("art_rect", [])) == TYPE_ARRAY else []
	if values.size() < 4:
		return true
	var center_x := (float(values[0]) + float(values[2]) * 0.5) * MASK_COLUMNS
	var center_y := (float(values[1]) + float(values[3]) * 0.5) * MASK_ROWS
	var radius_x := maxf(0.5, float(values[2]) * MASK_COLUMNS * 0.5)
	var radius_y := maxf(0.5, float(values[3]) * MASK_ROWS * 0.5)
	var dx := (float(column) + 0.5 - center_x) / radius_x
	var dy := (float(row) + 0.5 - center_y) / radius_y
	return dx * dx + dy * dy <= 1.0


static func _region_ranges(region: Dictionary) -> Array:
	# Foil is rasterized from the measured printed well. The mechanic rect is a
	# bounded inset; using art_rect here lets one mask cell over-cover the edge so
	# 256x192 quantization cannot leave a visible residue crescent.
	var values: Array = region.get("art_rect", []) if typeof(region.get("art_rect", [])) == TYPE_ARRAY else [0.0, 0.0, 1.0, 1.0]
	var left := clampi(ceili(float(values[0]) * MASK_COLUMNS - 0.5), 0, MASK_COLUMNS)
	var right := clampi(ceili((float(values[0]) + float(values[2])) * MASK_COLUMNS - 0.5), left, MASK_COLUMNS)
	var top := clampi(ceili(float(values[1]) * MASK_ROWS - 0.5), 0, MASK_ROWS)
	var bottom := clampi(ceili((float(values[1]) + float(values[3])) * MASK_ROWS - 0.5), top, MASK_ROWS)
	return [left, right, top, bottom]


static func _region_progress(region: Dictionary) -> float:
	if bool(region.get("revealed", false)):
		return 1.0
	var total := maxi(1, int(region.get("sample_total", 0)) * 255)
	return clampf(float(region.get("coverage", 1.0 - float(region.get("mask_remaining_units", total)) / float(total))), 0.0, 1.0)


static func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value as Array:
			if typeof(entry) == TYPE_DICTIONARY:
				result.append(entry)
	return result
