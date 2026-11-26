class_name ScratchTicketFoilRenderer
extends RefCounted

# Paints deterministic latex/foil textures for active Scratch Tickets; exposed
# style identities describe appearance only and never influence outcomes.

# One retained batch per cabinet. The UI may replace a ticket or its mask at
# Continue, while brush strokes update the current mask in place.
const EMPTY_PALETTE := {}

var _batch: MultiMesh
var _white_texture: ImageTexture
var _mask: Array = []
var _regions: Array = []
var _art_frame := Rect2()
var _dimensions := Vector2i.ZERO
var _mask_revision := -1
var _type_id := ""
var _palette: Dictionary = {}
var _base := Color.WHITE
var _glint := Color.WHITE


func draw(surface, ticket: Dictionary, art_frame: Rect2, state: Dictionary) -> void:
	var scratch: Variant = ticket.get("scratch")
	var mask: Variant = ticket.get("latex_mask")
	var regions: Variant = ticket.get("scratch_regions")
	if not scratch is Dictionary or not mask is Array or not regions is Array:
		return
	var dimensions := Vector2i(maxi(1, int(scratch.get("mask_columns", 1))), maxi(1, int(scratch.get("mask_rows", 1))))
	if mask.size() != dimensions.x * dimensions.y:
		return
	var revision := int(ticket.get("mask_revision", -1))
	var type_id := str(ticket.get("type_id", ""))
	var palette: Variant = ticket.get("palette")
	var face: Variant = ticket.get("face")
	if face is Dictionary:
		palette = face.get("palette", palette)
	if not palette is Dictionary:
		palette = EMPTY_PALETTE
	if _batch == null or not is_same(mask, _mask) or not is_same(regions, _regions) \
			or _mask_revision != revision or _art_frame != art_frame or _dimensions != dimensions \
			or _type_id != type_id or _palette != palette:
		_mask = mask
		_regions = regions
		_art_frame = art_frame
		_dimensions = dimensions
		_mask_revision = revision
		_type_id = type_id
		_palette = palette.duplicate(false)
		_build_batch()
	if _batch.instance_count > 0:
		surface.draw_multimesh(_batch, _white_texture)
	if bool(state.get("scratch_drag_active", false)):
		var crumbs: Array = state.get("scratch_crumbs", []) if typeof(state.get("scratch_crumbs", [])) == TYPE_ARRAY else []
		for crumb_value in crumbs:
			if typeof(crumb_value) != TYPE_DICTIONARY:
				continue
			var crumb: Dictionary = crumb_value
			surface.draw_circle(Vector2(float(crumb.get("x", 0.0)), float(crumb.get("y", 0.0))), float(crumb.get("r", 1.5)), Color(_base.r, _base.g, _base.b, 0.72))
		var point: Vector2 = state.get("scratch_last_pointer", Vector2.ZERO)
		var radius := maxf(8.0, float(state.get("scratch_brush_radius", 15.0)))
		surface.draw_circle(point, radius, Color(_glint.r, _glint.g, _glint.b, 0.18), false, 1)


static func style_id(ticket: Dictionary) -> String:
	return "%s_integrated_security_foil" % str(ticket.get("type_id", "ticket"))


func clear() -> void:
	if _batch == null:
		return
	_batch = null
	_mask = []
	_regions = []


func _build_batch() -> void:
	var colors := _foil_colors(_type_id, _palette)
	_base = colors[0]
	var dark: Color = colors[1]
	_glint = colors[2]
	var buffer := PackedFloat32Array()
	for region_value in _regions:
		if region_value is Dictionary:
			_append_region(buffer, region_value, dark)
	if _batch == null:
		_batch = MultiMesh.new()
		_batch.transform_format = MultiMesh.TRANSFORM_2D
		_batch.use_colors = true
		_batch.mesh = _make_unit_quad()
		if _white_texture == null:
			var pixel := Image.create(1, 1, false, Image.FORMAT_RGBA8)
			pixel.fill(Color.WHITE)
			_white_texture = ImageTexture.create_from_image(pixel)
	# Each tinted quad has two padded 2D transform rows and one RGBA row.
	_batch.instance_count = int(buffer.size() / 12.0)
	if not buffer.is_empty():
		_batch.buffer = buffer


static func _make_unit_quad() -> ArrayMesh:
	# The 2D-only Web export provides ArrayMesh but omits QuadMesh. Keep the
	# same centered unit quad so the foil's instance transforms stay identical.
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(0.5, -0.5, 0.0),
		Vector3(-0.5, -0.5, 0.0),
		Vector3(0.5, 0.5, 0.0),
		Vector3(-0.5, 0.5, 0.0),
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 0.0),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _append_region(buffer: PackedFloat32Array, region: Dictionary, dark: Color) -> void:
	var columns := _dimensions.x
	var rows := _dimensions.y
	var art_frame := _art_frame
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
			var alpha_bucket := _alpha_bucket(int(_mask[offset + column]))
			if alpha_bucket <= 0:
				column += 1
				continue
			var run_start := column
			column += 1
			while column < column_end and _alpha_bucket(int(_mask[offset + column])) == alpha_bucket:
				column += 1
			var alpha := float(alpha_bucket) / 32.0
			var run_rect := Rect2(
				art_frame.position + Vector2(float(run_start) * sample_size.x, float(row) * sample_size.y),
				Vector2(float(column - run_start) * sample_size.x + 0.20, sample_size.y + 0.20)
			)
			_append_run(buffer, run_rect, row, alpha, dark)


func _append_run(buffer: PackedFloat32Array, rect: Rect2, row: int, alpha: float, dark: Color) -> void:
	# Material variation is anchored to the ticket row, never to the start of a
	# run. Splitting a row with the brush therefore cannot restyle untouched
	# coating elsewhere on that row.
	var phase := posmod(row, 12)
	var coat := _base
	if phase <= 1:
		coat = _base.lerp(_glint, 0.055)
	elif phase >= 10:
		coat = _base.lerp(dark, 0.045)
	_append_quad(buffer, rect, Color(coat.r, coat.g, coat.b, alpha))
	if phase == 0 or phase == 6:
		var line_color := _glint if phase == 0 else dark
		line_color.a = (0.20 if phase == 0 else 0.14) * alpha
		_append_quad(buffer, Rect2(rect.position - Vector2(0, 0.5), Vector2(rect.size.x, 1)), line_color)


static func _append_quad(buffer: PackedFloat32Array, rect: Rect2, color: Color) -> void:
	var center := rect.get_center()
	buffer.append(rect.size.x)
	buffer.append(0.0)
	buffer.append(0.0)
	buffer.append(center.x)
	buffer.append(0.0)
	buffer.append(rect.size.y)
	buffer.append(0.0)
	buffer.append(center.y)
	buffer.append(color.r)
	buffer.append(color.g)
	buffer.append(color.b)
	buffer.append(color.a)


static func _foil_colors(type_id: String, palette: Dictionary) -> Array:
	var latex := Color(str(palette.get("latex", "#aeb3bd")))
	var paper := Color(str(palette.get("paper", "#f3ead4")))
	var ink := Color(str(palette.get("ink", "#34323a")))
	var accent := Color(str(palette.get("accent", "#b44961")))
	var trim := Color(str(palette.get("trim", "#e7c85c")))
	var base := latex.lerp(paper, 0.78)
	match type_id:
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
