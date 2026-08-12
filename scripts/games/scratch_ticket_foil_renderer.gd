class_name ScratchTicketFoilRenderer
extends RefCounted

static func draw(surface, ticket: Dictionary, art_frame: Rect2, state: Dictionary = {}) -> void:
	if ticket.is_empty():
		return
	var scratch: Dictionary = ticket.get("scratch", {}) if typeof(ticket.get("scratch", {})) == TYPE_DICTIONARY else {}
	var columns := maxi(1, int(scratch.get("mask_columns", 1)))
	var rows := maxi(1, int(scratch.get("mask_rows", 1)))
	var mask: Array = ticket.get("latex_mask", []) if typeof(ticket.get("latex_mask", [])) == TYPE_ARRAY else []
	if mask.size() != columns * rows:
		return
	var regions: Array = ticket.get("scratch_regions", []) if typeof(ticket.get("scratch_regions", [])) == TYPE_ARRAY else []
	var colors := _foil_colors(ticket)
	var base: Color = colors[0]
	var dark: Color = colors[1]
	var glint: Color = colors[2]
	for region_value in regions:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		_paint_region_mask(surface, mask, columns, rows, region, art_frame, base, dark, glint)
	if bool(state.get("scratch_drag_active", false)):
		var crumbs: Array = state.get("scratch_crumbs", []) if typeof(state.get("scratch_crumbs", [])) == TYPE_ARRAY else []
		for crumb_value in crumbs:
			if typeof(crumb_value) != TYPE_DICTIONARY:
				continue
			var crumb: Dictionary = crumb_value
			surface.draw_circle(Vector2(float(crumb.get("x", 0.0)), float(crumb.get("y", 0.0))), float(crumb.get("r", 1.5)), Color(base.r, base.g, base.b, 0.72))
		var point: Vector2 = state.get("scratch_last_pointer", Vector2.ZERO)
		var radius := maxf(8.0, float(state.get("scratch_brush_radius", 15.0)))
		surface.draw_circle(point, radius, Color(glint.r, glint.g, glint.b, 0.18), false, 1)


static func style_id(ticket: Dictionary) -> String:
	return "%s_integrated_security_foil" % str(ticket.get("type_id", "ticket"))


static func _paint_region_mask(surface, mask: Array, columns: int, rows: int, region: Dictionary, art_frame: Rect2, base: Color, dark: Color, glint: Color) -> void:
	var values: Array = region.get("art_rect", []) if typeof(region.get("art_rect", [])) == TYPE_ARRAY else []
	if values.size() < 4:
		return
	var column_start := clampi(ceili(float(values[0]) * columns - 0.5), 0, columns)
	var column_end := clampi(ceili((float(values[0]) + float(values[2])) * columns - 0.5), column_start, columns)
	var row_start := clampi(ceili(float(values[1]) * rows - 0.5), 0, rows)
	var row_end := clampi(ceili((float(values[1]) + float(values[3])) * rows - 0.5), row_start, rows)
	var sample_size := Vector2(art_frame.size.x / float(columns), art_frame.size.y / float(rows))
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
			var alpha := float(alpha_bucket) / 32.0
			var run_rect := Rect2(
				art_frame.position + Vector2(float(run_start) * sample_size.x, float(row) * sample_size.y),
				Vector2(float(column - run_start) * sample_size.x + 0.20, sample_size.y + 0.20)
			)
			_paint_run(surface, run_rect, row, alpha, base, dark, glint)


static func _paint_run(surface, rect: Rect2, row: int, alpha: float, base: Color, dark: Color, glint: Color) -> void:
	# Material variation is anchored to the ticket row, never to the start of a
	# run. Splitting a row with the brush therefore cannot restyle untouched
	# coating elsewhere on that row.
	var phase := posmod(row, 12)
	var coat := base
	if phase <= 1:
		coat = base.lerp(glint, 0.055)
	elif phase >= 10:
		coat = base.lerp(dark, 0.045)
	surface.draw_rect(rect, Color(coat.r, coat.g, coat.b, alpha))
	if phase == 0:
		surface.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(glint.r, glint.g, glint.b, 0.20 * alpha), 1)
	elif phase == 6:
		surface.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(dark.r, dark.g, dark.b, 0.14 * alpha), 1)


static func _foil_colors(ticket: Dictionary) -> Array:
	var face: Dictionary = ticket.get("face", {}) if typeof(ticket.get("face", {})) == TYPE_DICTIONARY else {}
	var palette: Dictionary = face.get("palette", ticket.get("palette", {})) if typeof(face.get("palette", ticket.get("palette", {}))) == TYPE_DICTIONARY else {}
	var latex := Color(str(palette.get("latex", "#aeb3bd")))
	var paper := Color(str(palette.get("paper", "#f3ead4")))
	var ink := Color(str(palette.get("ink", "#34323a")))
	var accent := Color(str(palette.get("accent", "#b44961")))
	var trim := Color(str(palette.get("trim", "#e7c85c")))
	var base := latex.lerp(paper, 0.78)
	match str(ticket.get("type_id", "")):
		"two_fer":
			base = Color("#ead8a4").lerp(trim, 0.08)
		"lucky_7s":
			base = Color("#11284a").lerp(accent, 0.07)
		"tic_tac_gold":
			base = Color("#ead59c").lerp(trim, 0.08)
		"crossword_corner":
			base = Color("#ddd3bc").lerp(paper, 0.28)
		"bonus_bingo":
			base = Color("#e4e6cc").lerp(paper, 0.26)
		"high_roller_holdem":
			base = Color("#e2cf9f").lerp(trim, 0.07)
		"golden_vault":
			base = Color("#9b793f").lerp(trim, 0.10)
	var dark := ink.lerp(accent, 0.22)
	var glint := trim.lerp(Color.WHITE, 0.34)
	return [base, dark, glint]


static func _alpha_bucket(alpha: int) -> int:
	if alpha <= 0:
		return 0
	return clampi(ceili(float(alpha) / 8.0), 1, 32)
