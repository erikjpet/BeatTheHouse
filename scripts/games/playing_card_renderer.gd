class_name PlayingCardRenderer
extends RefCounted

const CardShoeScript := preload("res://scripts/core/card_shoe.gd")
const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const C_DARK := VisualStyleScript.DARK
const C_SOFT := VisualStyleScript.SOFT
const C_PINK := VisualStyleScript.PINK
const C_TEAL := VisualStyleScript.TEAL
const C_AMBER := VisualStyleScript.AMBER
const CARD_FACE := Color("#fffaf0")
const CARD_BACK := Color("#6f2f83")
const CARD_BACK_INNER := Color("#39205f")


static func draw_card(surface, card_value: Variant, rect: Rect2, options: Dictionary = {}) -> void:
	var card: Dictionary = card_value if typeof(card_value) == TYPE_DICTIONARY else {}
	if bool(card.get("hidden", false)):
		draw_card_back(surface, rect)
		return
	var scoring := bool(options.get("scoring", false))
	var suggested := bool(options.get("suggested", false))
	var held := bool(options.get("held", false))
	if scoring:
		surface.draw_rect(rect.grow(5.0), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.30))
	surface.draw_rect(rect, Color("#ddd6c8"))
	surface.draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), CARD_FACE)
	surface.draw_rect(rect, Color("#251b2a"), false, maxf(1.0, rect.size.y * 0.025))
	if suggested:
		surface.draw_rect(rect.grow(3.0), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.70), false, 2)
	if held or scoring:
		surface.draw_rect(rect.grow(4.0), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.78), false, 3)
	var rank := int(card.get("rank", 2))
	var suit := int(card.get("suit", 0))
	var color := C_PINK if suit == 1 or suit == 3 else C_DARK
	var rank_size := clampi(int(rect.size.y * 0.30), 8, 28)
	var suit_scale := clampf(rect.size.y / 60.0, 0.34, 1.15)
	if bool(card.get("joker", false)) or rank == 0:
		surface.surface_label("JOKER", rect.position + Vector2(4, rect.size.y * 0.39), clampi(rank_size - 1, 7, 14), C_PINK)
		surface.draw_circle(rect.position + rect.size * 0.64, 5.0 * suit_scale, Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.64))
		return
	surface.surface_label(CardShoeScript.rank_label(rank), rect.position + Vector2(maxf(3.0, rect.size.x * 0.10), rank_size + 3), rank_size, color)
	draw_suit(surface, rect.position + Vector2(rect.size.x * 0.57, rect.size.y * 0.65), suit, color, suit_scale)
	if rect.size.y >= 48.0:
		draw_suit(surface, rect.position + Vector2(rect.size.x * 0.77, rect.size.y * 0.84), suit, Color(color.r, color.g, color.b, 0.45), suit_scale * 0.46)


static func draw_card_back(surface, rect: Rect2) -> void:
	surface.draw_rect(rect, C_SOFT)
	surface.draw_rect(Rect2(rect.position + Vector2(3, 3), rect.size - Vector2(6, 6)), CARD_BACK)
	surface.draw_rect(Rect2(rect.position + Vector2(8, 8), rect.size - Vector2(16, 16)), CARD_BACK_INNER)
	var center := rect.get_center()
	var radius := maxf(2.0, minf(rect.size.x, rect.size.y) * 0.12)
	surface.draw_polygon([
		center + Vector2(0, -radius),
		center + Vector2(radius, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius, 0),
	], [Color("#e5c55a")])


static func draw_suit(surface, pos: Vector2, suit: int, color: Color, scale: float = 1.0) -> void:
	match suit:
		0:
			surface.draw_polygon([pos + Vector2(0, -12) * scale, pos + Vector2(12, 4) * scale, pos + Vector2(-12, 4) * scale], [color])
			surface.draw_rect(Rect2(pos.x - 3 * scale, pos.y + 2 * scale, 6 * scale, 10 * scale), color)
		1:
			surface.draw_circle(pos + Vector2(-6, -4) * scale, 7 * scale, color)
			surface.draw_circle(pos + Vector2(6, -4) * scale, 7 * scale, color)
			surface.draw_polygon([pos + Vector2(-14, 0) * scale, pos + Vector2(14, 0) * scale, pos + Vector2(0, 14) * scale], [color])
		2:
			surface.draw_circle(pos + Vector2(-7, 0) * scale, 7 * scale, color)
			surface.draw_circle(pos + Vector2(7, 0) * scale, 7 * scale, color)
			surface.draw_circle(pos + Vector2(0, -8) * scale, 7 * scale, color)
			surface.draw_rect(Rect2(pos.x - 3 * scale, pos.y + 2 * scale, 6 * scale, 12 * scale), color)
		_:
			surface.draw_polygon([pos + Vector2(0, -13) * scale, pos + Vector2(11, 0) * scale, pos + Vector2(0, 13) * scale, pos + Vector2(-11, 0) * scale], [color])


static func card_from_code(code: String) -> Dictionary:
	var normalized := code.strip_edges().to_upper()
	if normalized == "WILD":
		return {"rank": 0, "suit": 0, "joker": true}
	if normalized.length() < 2:
		return {"rank": 2, "suit": 0}
	var suit_character := normalized.right(1)
	var rank_text := normalized.left(normalized.length() - 1)
	var rank := 14 if rank_text == "A" else 13 if rank_text == "K" else 12 if rank_text == "Q" else 11 if rank_text == "J" else int(rank_text)
	var suit := 0
	match suit_character:
		"H":
			suit = 1
		"C":
			suit = 2
		"D":
			suit = 3
	return {"rank": rank, "suit": suit}
