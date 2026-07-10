class_name AttributeBadgeRow
extends RefCounted

# Shared badge renderer for Control cards and immediate-mode canvas surfaces.

const AttributeBadgesScript := preload("res://scripts/core/attribute_badges.gd")
const IconSpriteRendererScript := preload("res://scripts/ui/icon_sprite_renderer.gd")
const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")

const MAX_TEXTURE_CACHE := 192
const DEFAULT_GLYPH_SIZE := 16
const MIN_CONTROL_GLYPH_SIZE := 12
const MAX_CONTROL_GLYPH_SIZE := 18
const CANVAS_BADGE_HEIGHT := 22.0
const CONTROL_BADGE_TEXT_WIDTH := 116.0

static var _texture_cache: Dictionary = {}


static func control_row(badges: Array, glyph_size: int = DEFAULT_GLYPH_SIZE) -> HFlowContainer:
	var safe_glyph_size := clampi(glyph_size, MIN_CONTROL_GLYPH_SIZE, MAX_CONTROL_GLYPH_SIZE)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0.0, float(safe_glyph_size) + 8.0)
	for badge_value in badges:
		if typeof(badge_value) != TYPE_DICTIONARY:
			continue
		var badge: Dictionary = badge_value
		var glyph_id := str(badge.get("glyph_id", "")).strip_edges()
		if glyph_id.is_empty():
			continue
		var tooltip := _tooltip_text(badge)
		var collapsed_width := float(safe_glyph_size) + 8.0
		var expanded_width := collapsed_width + CONTROL_BADGE_TEXT_WIDTH
		var row_height := float(safe_glyph_size) + 6.0
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override("panel", _cell_style(_badge_color(badge)))
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.mouse_default_cursor_shape = Control.CURSOR_ARROW
		cell.custom_minimum_size = Vector2(collapsed_width, row_height)
		cell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var cell_box := HBoxContainer.new()
		cell_box.add_theme_constant_override("separation", 4)
		cell.add_child(cell_box)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(safe_glyph_size, safe_glyph_size)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = texture_for_badge(badge, safe_glyph_size, false)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell_box.add_child(icon)
		var label := Label.new()
		label.text = tooltip
		label.visible = false
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.custom_minimum_size = Vector2(CONTROL_BADGE_TEXT_WIDTH - 4.0, float(safe_glyph_size))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", VisualStyleScript.accessible_color(_badge_color(badge)))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell_box.add_child(label)
		cell.mouse_entered.connect(func() -> void:
			cell.custom_minimum_size = Vector2(expanded_width, row_height)
			label.visible = true
		)
		cell.mouse_exited.connect(func() -> void:
			label.visible = false
			cell.custom_minimum_size = Vector2(collapsed_width, row_height)
		)
		row.add_child(cell)
	return row


static func draw_canvas(canvas: CanvasItem, badges: Array, origin: Vector2, max_width: float = 180.0, glyph_size: int = 14) -> Rect2:
	var control := canvas as Control
	if control == null:
		return Rect2(origin, Vector2.ZERO)
	var x := origin.x
	var y := origin.y
	var row_height := maxf(CANVAS_BADGE_HEIGHT, float(glyph_size) + 6.0)
	var drawn_width := 0.0
	for badge_value in badges:
		if typeof(badge_value) != TYPE_DICTIONARY:
			continue
		var badge: Dictionary = badge_value
		var glyph_id := str(badge.get("glyph_id", "")).strip_edges()
		if glyph_id.is_empty():
			continue
		var badge_width := float(glyph_size) + 10.0
		if drawn_width > 0.0 and drawn_width + badge_width > max_width:
			break
		var accent := _badge_color(badge)
		var badge_rect := Rect2(Vector2(x, y), Vector2(badge_width, row_height))
		canvas.draw_rect(badge_rect, Color(0.0, 0.0, 0.0, 0.76))
		canvas.draw_rect(badge_rect, Color(accent.r, accent.g, accent.b, 0.22))
		canvas.draw_rect(badge_rect, Color(accent.r, accent.g, accent.b, 0.88), false, 1.0)
		var icon_rect := Rect2(Vector2(x + 3.0, y + (row_height - float(glyph_size)) * 0.5), Vector2(glyph_size, glyph_size))
		var texture := texture_for_badge(badge, glyph_size, false)
		if texture != null:
			canvas.draw_texture_rect(texture, icon_rect, false)
		else:
			var glyph := AttributeBadgesScript.glyph_definition(glyph_id)
			var sprite: Dictionary = glyph.get("sprite", {}) if typeof(glyph.get("sprite", {})) == TYPE_DICTIONARY else {}
			IconSpriteRendererScript.draw_canvas(canvas, sprite, icon_rect, accent)
		x += badge_width + 4.0
		drawn_width += badge_width + 4.0
	return Rect2(origin, Vector2(drawn_width, row_height))


static func canvas_hit_entries(badges: Array, origin: Vector2, max_width: float = 180.0, glyph_size: int = 14) -> Array:
	var entries: Array = []
	var x := origin.x
	var y := origin.y
	var row_height := maxf(CANVAS_BADGE_HEIGHT, float(glyph_size) + 6.0)
	var drawn_width := 0.0
	for badge_value in badges:
		if typeof(badge_value) != TYPE_DICTIONARY:
			continue
		var badge: Dictionary = badge_value
		var glyph_id := str(badge.get("glyph_id", "")).strip_edges()
		if glyph_id.is_empty():
			continue
		var badge_width := float(glyph_size) + 10.0
		if drawn_width > 0.0 and drawn_width + badge_width > max_width:
			break
		entries.append({
			"rect": Rect2(Vector2(x, y), Vector2(badge_width, row_height)),
			"tooltip": _tooltip_text(badge),
		})
		x += badge_width + 4.0
		drawn_width += badge_width + 4.0
	return entries


static func warm_cache(badges: Array, glyph_size: int = DEFAULT_GLYPH_SIZE) -> void:
	for badge_value in badges:
		if typeof(badge_value) == TYPE_DICTIONARY:
			texture_for_badge(badge_value as Dictionary, glyph_size, false)


static func warm_all_glyphs(glyph_size: int = DEFAULT_GLYPH_SIZE) -> void:
	for glyph_id_value in AttributeBadgesScript.glyph_ids():
		var glyph_id := str(glyph_id_value)
		for polarity in ["class", "neutral", "good", "bad"]:
			texture_for_badge({"glyph_id": glyph_id, "polarity": polarity}, glyph_size, false)


static func texture_cache_size() -> int:
	return _texture_cache.size()


static func texture_for_badge(badge: Dictionary, glyph_size: int = DEFAULT_GLYPH_SIZE, include_frame: bool = false) -> Texture2D:
	var glyph_id := str(badge.get("glyph_id", "")).strip_edges()
	if glyph_id.is_empty():
		return null
	var polarity := str(badge.get("polarity", "")).strip_edges().to_lower()
	var cache_key := "%s|%d|%s|%s" % [glyph_id, glyph_size, polarity, "frame" if include_frame else "plain"]
	if _texture_cache.has(cache_key):
		return _texture_cache.get(cache_key, null) as Texture2D
	var glyph := AttributeBadgesScript.glyph_definition(glyph_id)
	if glyph.is_empty():
		_texture_cache[cache_key] = null
		return null
	var sprite: Dictionary = glyph.get("sprite", {}) if typeof(glyph.get("sprite", {})) == TYPE_DICTIONARY else {}
	if sprite.is_empty():
		_texture_cache[cache_key] = null
		return null
	var texture := IconSpriteRendererScript.texture(sprite, glyph_size, _badge_color(badge), include_frame)
	if _texture_cache.size() > MAX_TEXTURE_CACHE:
		_texture_cache.clear()
	_texture_cache[cache_key] = texture
	return texture


static func _badge_color(badge: Dictionary) -> Color:
	var token := AttributeBadgesScript.palette_token_for_badge(badge)
	return VisualStyleScript.color(token, VisualStyleScript.SOFT)


static func _cell_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
	style.border_color = VisualStyleScript.accessible_color(accent)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 3
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


static func _tooltip_text(badge: Dictionary) -> String:
	var tooltip := str(badge.get("tooltip", "")).strip_edges()
	var value_text := str(badge.get("value_text", "")).strip_edges()
	if not tooltip.is_empty() and not value_text.is_empty() and tooltip.find(value_text) < 0:
		return "%s: %s" % [tooltip, value_text]
	if not tooltip.is_empty():
		return tooltip
	var glyph_id := str(badge.get("glyph_id", "")).strip_edges()
	var glyph := AttributeBadgesScript.glyph_definition(glyph_id)
	var label := str(glyph.get("label", glyph_id)).strip_edges()
	if not value_text.is_empty():
		return "%s: %s" % [label, value_text]
	return str(glyph.get("description", label))
