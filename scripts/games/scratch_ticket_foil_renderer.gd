class_name ScratchTicketFoilRenderer
extends RefCounted

const RegionModelScript := preload("res://scripts/games/scratch_ticket_region_model.gd")


static func draw(surface, ticket: Dictionary, ticket_rect: Rect2, state: Dictionary = {}) -> void:
	if ticket.is_empty():
		return
	var scratch: Dictionary = ticket.get("scratch", {}) if typeof(ticket.get("scratch", {})) == TYPE_DICTIONARY else {}
	var columns := maxi(1, int(scratch.get("mask_columns", 1)))
	var rows := maxi(1, int(scratch.get("mask_rows", 1)))
	var mask: Array = ticket.get("latex_mask", []) if typeof(ticket.get("latex_mask", [])) == TYPE_ARRAY else []
	if mask.size() != columns * rows:
		return
	var regions: Array = ticket.get("scratch_regions", []) if typeof(ticket.get("scratch_regions", [])) == TYPE_ARRAY else []
	var type_id := str(ticket.get("type_id", ""))
	var colors := _foil_colors(type_id)
	var base: Color = colors[0]
	var dark: Color = colors[1]
	var glint: Color = colors[2]
	for region_index in range(regions.size()):
		var region_value: Variant = regions[region_index]
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		_paint_region_mask(surface, mask, columns, rows, region, ticket_rect, type_id, base, dark, glint)
		var coverage := float(region.get("coverage", 0.0))
		var rect := RegionModelScript.rect_for(region, ticket_rect)
		if coverage < 0.001:
			_paint_full_coating_design(surface, type_id, rect, region_index, base, dark, glint)
		if coverage < 0.015 and rect.size.x >= 44.0 and rect.size.y >= 22.0:
			surface.surface_label_centered("SCRATCH", rect, clampi(int(rect.size.y * 0.24), 5, 8), Color(glint.r, glint.g, glint.b, 0.92))
	var crumbs: Array = state.get("scratch_crumbs", []) if typeof(state.get("scratch_crumbs", [])) == TYPE_ARRAY else []
	for crumb_value in crumbs:
		if typeof(crumb_value) != TYPE_DICTIONARY:
			continue
		var crumb: Dictionary = crumb_value
		surface.draw_circle(Vector2(float(crumb.get("x", 0.0)), float(crumb.get("y", 0.0))), float(crumb.get("r", 1.5)), Color(base.r, base.g, base.b, 0.88))
	if bool(state.get("scratch_drag_active", false)):
		var point: Vector2 = state.get("scratch_last_pointer", Vector2.ZERO)
		var radius := maxf(8.0, float(state.get("scratch_brush_radius", 15.0)))
		surface.draw_circle(point, radius, Color(glint.r, glint.g, glint.b, 0.22), false, 2)
		surface.draw_circle(point - Vector2(radius * 0.22, radius * 0.18), maxf(1.5, radius * 0.11), Color(base.r, base.g, base.b, 0.90))


static func style_id(ticket: Dictionary) -> String:
	return "%s_designed_foil" % str(ticket.get("type_id", "ticket"))


static func _paint_region_mask(surface, mask: Array, columns: int, rows: int, region: Dictionary, ticket_rect: Rect2, type_id: String, base: Color, dark: Color, glint: Color) -> void:
	var values: Array = region.get("rect", []) if typeof(region.get("rect", [])) == TYPE_ARRAY else []
	if values.size() < 4:
		return
	var column_start := clampi(ceili(float(values[0]) * columns - 0.5), 0, columns)
	var column_end := clampi(ceili((float(values[0]) + float(values[2])) * columns - 0.5), column_start, columns)
	var row_start := clampi(ceili(float(values[1]) * rows - 0.5), 0, rows)
	var row_end := clampi(ceili((float(values[1]) + float(values[3])) * rows - 0.5), row_start, rows)
	var sample_size := Vector2(ticket_rect.size.x / float(columns), ticket_rect.size.y / float(rows))
	for row in range(row_start, row_end):
		var offset := row * columns
		var column := column_start
		while column < column_end:
			var alpha_bucket := _alpha_bucket(int(mask[offset + column]))
			if alpha_bucket <= 0:
				column += 1
				continue
			var run_start := column
			column += 1
			while column < column_end and _alpha_bucket(int(mask[offset + column])) == alpha_bucket:
				column += 1
			var alpha := float(alpha_bucket) / 15.0
			var run_rect := Rect2(
				ticket_rect.position + Vector2(float(run_start) * sample_size.x, float(row) * sample_size.y),
				Vector2(float(column - run_start) * sample_size.x + 0.35, sample_size.y + 0.35)
			)
			_paint_run(surface, run_rect, row, run_start, type_id, alpha, base, dark, glint)


static func _paint_run(surface, rect: Rect2, row: int, column: int, type_id: String, alpha: float, base: Color, dark: Color, glint: Color) -> void:
	surface.draw_rect(rect, Color(base.r, base.g, base.b, alpha))
	var phase := posmod(row + column, 12)
	match type_id:
		"two_fer":
			if phase == 0:
				surface.draw_line(rect.position + Vector2(0, rect.size.y), rect.position + Vector2(rect.size.x, 0), Color(glint.r, glint.g, glint.b, 0.44 * alpha), 1)
			elif phase == 6:
				surface.draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(dark.r, dark.g, dark.b, 0.34 * alpha), 1)
		"lucky_7s":
			if phase % 4 == 0:
				surface.draw_line(rect.position + Vector2(0, rect.size.y * 0.5), rect.position + Vector2(rect.size.x, rect.size.y * 0.5), Color(glint.r, glint.g, glint.b, 0.48 * alpha), 1)
		"tic_tac_gold":
			if phase == 2 or phase == 8:
				surface.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y * 0.20), Vector2(rect.size.x, maxf(1.0, rect.size.y * 0.32))), Color(glint.r, glint.g, glint.b, 0.26 * alpha))
		"crossword_corner":
			if phase % 3 == 0:
				surface.draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(dark.r, dark.g, dark.b, 0.26 * alpha), 1)
		"bonus_bingo":
			if phase == 0 or phase == 7:
				var radius := minf(2.0, rect.size.y * 0.45)
				surface.draw_circle(rect.position + Vector2(maxf(radius, rect.size.x * 0.5), rect.size.y * 0.5), radius, Color(glint.r, glint.g, glint.b, 0.32 * alpha))
		"high_roller_holdem":
			if phase == 1:
				surface.draw_line(rect.position + Vector2(0, rect.size.y), rect.position + Vector2(rect.size.x, 0), Color(glint.r, glint.g, glint.b, 0.35 * alpha), 1)
			elif phase == 7:
				surface.draw_line(rect.position, rect.position + Vector2(rect.size.x, rect.size.y), Color(dark.r, dark.g, dark.b, 0.28 * alpha), 1)
		"golden_vault":
			if phase % 4 == 0:
				surface.draw_rect(Rect2(rect.position, Vector2(rect.size.x, maxf(1.0, rect.size.y * 0.36))), Color(glint.r, glint.g, glint.b, 0.32 * alpha))
			elif phase == 6:
				surface.draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(dark.r, dark.g, dark.b, 0.42 * alpha), 1)


static func _paint_full_coating_design(surface, type_id: String, rect: Rect2, _region_index: int, _base: Color, dark: Color, glint: Color) -> void:
	var inset := rect.grow(-2.0)
	if inset.size.x <= 2.0 or inset.size.y <= 2.0:
		return
	surface.draw_rect(inset, Color(glint.r, glint.g, glint.b, 0.34), false, 1)
	match type_id:
		"two_fer":
			for stripe in range(5):
				var x := inset.position.x + float(stripe) * inset.size.x / 4.0
				surface.draw_line(Vector2(x - 9, inset.end.y), Vector2(x + 9, inset.position.y), Color(glint.r, glint.g, glint.b, 0.23), 2)
			surface.draw_circle(inset.get_center(), minf(inset.size.x, inset.size.y) * 0.30, Color(dark.r, dark.g, dark.b, 0.20), false, 2)
		"lucky_7s":
			surface.surface_label_centered("?", inset, clampi(int(inset.size.y * 0.54), 7, 16), Color(glint.r, glint.g, glint.b, 0.24))
			for dot in range(4):
				var x := inset.position.x + (float(dot) + 0.5) * inset.size.x / 4.0
				surface.draw_circle(Vector2(x, inset.position.y + 4), 1.4, glint)
		"tic_tac_gold":
			surface.draw_circle(inset.get_center(), minf(inset.size.x, inset.size.y) * 0.30, Color(glint.r, glint.g, glint.b, 0.24), false, 2)
			surface.surface_label_centered("?", inset, clampi(int(inset.size.y * 0.45), 5, 12), Color(dark.r, dark.g, dark.b, 0.30))
		"crossword_corner":
			if inset.size.x >= 18.0 and inset.size.y >= 13.0:
				surface.surface_label_centered("?", inset, clampi(int(inset.size.y * 0.54), 5, 10), Color(glint.r, glint.g, glint.b, 0.28))
		"bonus_bingo":
			surface.draw_circle(inset.get_center(), minf(inset.size.x, inset.size.y) * 0.34, Color(glint.r, glint.g, glint.b, 0.25), false, 2)
			if inset.size.x >= 24.0:
				surface.draw_circle(inset.get_center(), minf(inset.size.x, inset.size.y) * 0.18, Color(dark.r, dark.g, dark.b, 0.18))
		"high_roller_holdem":
			var diamond := PackedVector2Array([
				inset.get_center() - Vector2(0, inset.size.y * 0.30),
				inset.get_center() + Vector2(inset.size.y * 0.22, 0),
				inset.get_center() + Vector2(0, inset.size.y * 0.30),
				inset.get_center() - Vector2(inset.size.y * 0.22, 0),
			])
			surface.draw_polygon(diamond, [Color(glint.r, glint.g, glint.b, 0.22)])
		"golden_vault":
			for bar in range(3):
				var y := inset.position.y + (float(bar) + 1.0) * inset.size.y / 4.0
				surface.draw_line(Vector2(inset.position.x + 3, y), Vector2(inset.end.x - 3, y), Color(glint.r, glint.g, glint.b, 0.27), 2)
			surface.draw_circle(inset.get_center(), minf(inset.size.x, inset.size.y) * 0.27, Color(dark.r, dark.g, dark.b, 0.24), false, 2)


static func _foil_colors(type_id: String) -> Array:
	match type_id:
		"two_fer": return [Color("#d8b0d8"), Color("#683d72"), Color("#fff2ff")]
		"lucky_7s": return [Color("#75366f"), Color("#32152f"), Color("#ffcfeb")]
		"tic_tac_gold": return [Color("#b88a36"), Color("#57401e"), Color("#fff0a6")]
		"crossword_corner": return [Color("#b4aca0"), Color("#4b4a48"), Color("#f7f0df")]
		"bonus_bingo": return [Color("#77b991"), Color("#275f45"), Color("#e9ffe9")]
		"high_roller_holdem": return [Color("#b34e62"), Color("#4a1826"), Color("#ffd7df")]
		"golden_vault": return [Color("#b58a35"), Color("#4c3515"), Color("#fff0a3")]
	return [Color("#aeb3bd"), Color("#4d5360"), Color("#f6f8ff")]


static func _alpha_bucket(alpha: int) -> int:
	if alpha <= 0:
		return 0
	return clampi(ceili(float(alpha) / 17.0), 1, 15)
