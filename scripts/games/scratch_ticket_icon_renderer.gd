class_name ScratchTicketIconRenderer
extends RefCounted

const RegionModelScript := preload("res://scripts/games/scratch_ticket_region_model.gd")
const PlayingCardRendererScript := preload("res://scripts/games/playing_card_renderer.gd")
const SYMBOLS := {
	"twofer": preload("res://assets/art/scratch_tickets/reveal_symbols/pro_twofer.png"),
	"clover": preload("res://assets/art/scratch_tickets/reveal_symbols/pro_clover.png"),
	"bell": preload("res://assets/art/scratch_tickets/reveal_symbols/pro_bell.png"),
	"star": preload("res://assets/art/scratch_tickets/reveal_symbols/pro_star.png"),
	"tic_circle": preload("res://assets/art/scratch_tickets/reveal_symbols/pro_tic_circle.png"),
	"tic_star": preload("res://assets/art/scratch_tickets/reveal_symbols/pro_tic_star.png"),
	"tic_diamond": preload("res://assets/art/scratch_tickets/reveal_symbols/pro_tic_diamond.png"),
	"tic_miss": preload("res://assets/art/scratch_tickets/reveal_symbols/pro_tic_miss.png"),
	"lucky_seven": preload("res://assets/art/scratch_tickets/reveal_symbols/lucky_seven.png"),
	"number_coin": preload("res://assets/art/scratch_tickets/reveal_symbols/number_coin.png"),
	"bingo_ball": preload("res://assets/art/scratch_tickets/reveal_symbols/bingo_ball.png"),
	"multiplier_coin": preload("res://assets/art/scratch_tickets/reveal_symbols/multiplier_coin.png"),
	"gold_bar": preload("res://assets/art/scratch_tickets/reveal_symbols/gold_bar.png"),
	"brass_bar": preload("res://assets/art/scratch_tickets/reveal_symbols/brass_bar.png"),
	"vault_open": preload("res://assets/art/scratch_tickets/reveal_symbols/vault_open.png"),
	"vault_sealed": preload("res://assets/art/scratch_tickets/reveal_symbols/vault_sealed.png"),
	"wild_card": preload("res://assets/art/scratch_tickets/reveal_symbols/wild_card.png"),
}


const SYMBOL_INSET := 0.92


static func draw(surface, ticket: Dictionary, art_frame: Rect2) -> void:
	if ticket.is_empty():
		return
	var face: Dictionary = ticket.get("face", {}) if typeof(ticket.get("face", {})) == TYPE_DICTIONARY else {}
	var palette: Dictionary = face.get("palette", {}) if typeof(face.get("palette", {})) == TYPE_DICTIONARY else {}
	var ink := Color(str(palette.get("ink", "#2b1d31")))
	var accent := Color(str(palette.get("accent", "#e83f68")))
	var trim := Color(str(palette.get("trim", "#f5c843")))
	var spots: Array = ticket.get("spots", []) if typeof(ticket.get("spots", [])) == TYPE_ARRAY else []
	var regions: Array = ticket.get("scratch_regions", []) if typeof(ticket.get("scratch_regions", [])) == TYPE_ARRAY else []
	for region_value in regions:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		var spot_index := int(region.get("spot_index", -1))
		if spot_index < 0 or spot_index >= spots.size() or typeof(spots[spot_index]) != TYPE_DICTIONARY:
			continue
		var spot: Dictionary = (spots[spot_index] as Dictionary).duplicate(false)
		spot["content_split"] = region.get("content_split", [])
		var rect := RegionModelScript.rect_for(region, art_frame)
		_paint_result_icon(surface, str(ticket.get("type_id", "")), spot, rect, ink, accent, trim)
	if bool(ticket.get("result_ready", false)):
		_paint_validation_result(surface, ticket, art_frame, ink, accent, trim)


static func _paint_validation_result(surface, ticket: Dictionary, art_frame: Rect2, ink: Color, accent: Color, trim: Color) -> void:
	var payout := maxi(0, int(ticket.get("payout", 0)))
	var won := payout > 0
	var stamp := Rect2(
		art_frame.position + Vector2(art_frame.size.x * 0.31, art_frame.size.y * 0.902),
		Vector2(art_frame.size.x * 0.38, art_frame.size.y * 0.068)
	)
	var dark_base := ink if ink.get_luminance() < 0.48 else accent.darkened(0.56)
	var fill := dark_base if won else dark_base.darkened(0.18)
	var border := trim if won else accent.lightened(0.25)
	surface.draw_rect(stamp, Color(fill.r, fill.g, fill.b, 0.96))
	surface.draw_rect(stamp, border, false, 2)
	surface.draw_rect(stamp.grow(-3.0), Color(border.r, border.g, border.b, 0.48), false, 1)
	var text := "WIN  $%d" % payout if won else "NOT A WINNER"
	surface.surface_label_centered(text, stamp.grow(-4.0), clampi(int(stamp.size.y * 0.48), 7, 12), Color("#fff8df"))


static func _paint_result_icon(surface, type_id: String, spot: Dictionary, rect: Rect2, ink: Color, accent: Color, trim: Color) -> void:
	match type_id:
		"two_fer":
			_paint_two_fer_symbol(surface, str(spot.get("symbol", "")), rect, ink, accent, trim)
		"lucky_7s":
			_paint_lucky_number(surface, spot, rect, ink, accent, trim)
		"tic_tac_gold":
			_paint_tic_mark(surface, spot, rect, ink, accent, trim)
		"crossword_corner":
			_paint_letter(surface, spot, rect, ink, accent)
		"bonus_bingo":
			_paint_bingo_number(surface, spot, rect, ink, accent, trim)
		"high_roller_holdem":
			_paint_holdem_icon(surface, spot, rect, ink, accent, trim)
		"golden_vault":
			_paint_vault_icon(surface, spot, rect, ink, accent, trim)


static func _paint_two_fer_symbol(surface, symbol: String, rect: Rect2, _ink: Color, _accent: Color, _trim: Color) -> void:
	var texture_id := "clover" if symbol == "CLOVER" else "bell" if symbol == "BELL" else "star" if symbol == "STAR" else "twofer"
	_paint_symbol_texture(surface, texture_id, rect)


static func _paint_lucky_number(surface, spot: Dictionary, rect: Rect2, ink: Color, accent: Color, _trim: Color) -> void:
	var number := int(spot.get("number", 0))
	var seven := number == 7
	var role := str(spot.get("role", ""))
	var color := Color("#fff4a0") if role == "winning_number" else ink
	_paint_symbol_texture(surface, "lucky_seven" if seven else "number_coin", rect)
	var number_rect := _content_rect(rect, spot, "number")
	if not seven:
		surface.surface_label_centered(str(number), number_rect, clampi(int(rect.size.y * 0.52), 10, 24), color)
	if spot.has("prize") and str(spot.get("role", "")) != "winning_number":
		var prize := int(spot.get("prize", 0))
		surface.surface_label_centered("$%d" % prize if prize > 0 else "NO PRIZE", _content_rect(rect, spot, "prize"), clampi(int(rect.size.y * 0.16), 5, 8), accent if prize > 0 else ink)


static func _paint_tic_mark(surface, spot: Dictionary, rect: Rect2, ink: Color, _accent: Color, _trim: Color) -> void:
	var mark := str(spot.get("mark", "MISS"))
	if mark == "WIN":
		var texture_ids := ["tic_circle", "tic_star", "tic_diamond"]
		_paint_symbol_texture(surface, str(texture_ids[posmod(int(spot.get("variant", 0)), 3)]), rect)
		surface.surface_label_centered("WIN", rect, clampi(int(rect.size.y * 0.24), 6, 11), Color("#fff8d6"))
	elif mark == "GOLD":
		_paint_symbol_texture(surface, "tic_star", rect)
		surface.surface_label_centered("GOLD", rect, clampi(int(rect.size.y * 0.20), 6, 10), Color("#fff8d6"))
	else:
		_paint_symbol_texture(surface, "tic_miss", rect)
		surface.surface_label_centered("MISS" if mark == "MISS" else "DUST", Rect2(rect.position + Vector2(0, rect.size.y * 0.74), Vector2(rect.size.x, rect.size.y * 0.20)), 6, ink)


static func _paint_letter(surface, spot: Dictionary, rect: Rect2, ink: Color, accent: Color) -> void:
	var letter := str(spot.get("letter", "?")).left(1)
	var matched := bool(spot.get("matched", false)) or bool(spot.get("complete", false))
	surface.surface_label_centered(letter, rect, clampi(int(rect.size.y * 0.74), 6, 17), accent if matched else ink)
	if bool(spot.get("complete", false)):
		surface.draw_rect(rect.grow(-1.0), Color(accent.r, accent.g, accent.b, 0.58), false, 1)


static func _paint_bingo_number(surface, spot: Dictionary, rect: Rect2, ink: Color, accent: Color, trim: Color) -> void:
	var number := int(spot.get("number", 0))
	var role := str(spot.get("role", ""))
	var daubed := bool(spot.get("daubed", false)) or number == 0
	if role == "caller":
		_paint_symbol_texture(surface, "bingo_ball", rect)
	elif daubed:
		surface.draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.44, Color(accent.r, accent.g, accent.b, 0.72))
	surface.surface_label_centered("FREE" if number == 0 else str(number), rect, clampi(int(rect.size.y * (0.42 if number == 0 else 0.62)), 5, 12), Color("#fffbe9") if daubed else ink)


static func _paint_holdem_icon(surface, spot: Dictionary, rect: Rect2, ink: Color, _accent: Color, _trim: Color) -> void:
	if str(spot.get("role", "")) == "wild":
		var wild := str(spot.get("card", "")) == "WILD"
		if wild:
			_paint_symbol_texture(surface, "wild_card", rect)
		else:
			surface.surface_label_centered("NO WILD", rect, clampi(int(rect.size.y * 0.52), 7, 14), ink)
		return
	var card := PlayingCardRendererScript.card_from_code(str(spot.get("card", "2S")))
	PlayingCardRendererScript.draw_card(surface, card, rect)


static func _paint_vault_icon(surface, spot: Dictionary, rect: Rect2, ink: Color, _accent: Color, trim: Color) -> void:
	match str(spot.get("role", "")):
		"multiplier":
			_paint_symbol_texture(surface, "multiplier_coin", rect)
			surface.surface_label_centered("%dx" % int(spot.get("multiplier", 2)), rect, clampi(int(rect.size.y * 0.58), 8, 18), ink)
		"ladder":
			var match_win := bool(spot.get("match", false))
			var base := int(spot.get("base_prize", 0))
			var left := "$%d" % base
			var right := "$%d" % base if match_win else "$%d" % (base + int(spot.get("rung", 1)) * 7 + 3)
			surface.surface_label_centered("%s  %s  %s" % [left, "=" if match_win else "!=", right], rect, clampi(int(rect.size.y * 0.45), 6, 10), trim if match_win else ink)
		"gold_bar":
			var gold := bool(spot.get("win_all", false))
			_paint_symbol_texture(surface, "gold_bar" if gold else "brass_bar", rect)
		_:
			var open := str(spot.get("symbol", "")) == "OPEN"
			_paint_symbol_texture(surface, "vault_open" if open else "vault_sealed", rect)


static func _paint_symbol_texture(surface, texture_id: String, rect: Rect2) -> void:
	var texture: Texture2D = SYMBOLS.get(texture_id)
	if texture == null:
		return
	# One conservative inset keeps every reveal inside its measured printed well.
	var source := texture.get_size()
	var scale := minf(rect.size.x / source.x, rect.size.y / source.y) * SYMBOL_INSET
	var fitted := source * scale
	surface.draw_texture_rect(texture, Rect2(rect.get_center() - fitted * 0.5, fitted), false)


static func _content_rect(rect: Rect2, spot: Dictionary, portion: String) -> Rect2:
	var split: Array = spot.get("content_split", []) if typeof(spot.get("content_split", [])) == TYPE_ARRAY else []
	if split.size() < 4:
		return rect
	var top_height := clampf(float(split[3]), 0.05, 0.95)
	if portion == "number":
		return Rect2(rect.position, Vector2(rect.size.x, rect.size.y * top_height))
	return Rect2(rect.position + Vector2(0, rect.size.y * top_height), Vector2(rect.size.x, rect.size.y * (1.0 - top_height)))
