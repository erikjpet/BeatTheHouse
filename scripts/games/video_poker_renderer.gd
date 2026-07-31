class_name VideoPokerRenderer
extends RefCounted

const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const CardShoeScript := preload("res://scripts/core/card_shoe.gd")

const DESIGN_SIZE := Vector2(960, 540)
const HEADER := Rect2(18, 14, 924, 58)
const PAYTABLE := Rect2(42, 82, 876, 140)
const PLAYFIELD := Rect2(42, 232, 876, 218)
const CONTROL_DECK := Rect2(30, 462, 900, 62)
const MAX_COIN_COUNT := 5
const HAND_SIZE := 5

const C_DARK := VisualStyleScript.DARK
const C_PINK := VisualStyleScript.PINK
const C_CYAN := VisualStyleScript.CYAN
const C_TEAL := VisualStyleScript.TEAL
const C_YELLOW := VisualStyleScript.YELLOW
const C_AMBER := VisualStyleScript.AMBER
const C_ORANGE := VisualStyleScript.ORANGE
const C_WHITE := VisualStyleScript.WHITE
const C_SOFT := VisualStyleScript.SOFT


func draw(surface, state: Dictionary, _context: Dictionary = {}) -> bool:
	if str(state.get("surface_renderer", "")) != "card_machine":
		return false
	surface.surface_begin_design_space_inset(DESIGN_SIZE, Vector2.ZERO)
	var palette := _palette(state)
	_draw_authored_cabinet(surface, state, palette)
	_draw_paytable(surface, state, palette)
	if str(state.get("phase", "idle")) == "double_up":
		_draw_double_up(surface, state, palette)
	else:
		_draw_hands(surface, state, palette)
	_draw_controls(surface, state, palette)
	_draw_holdout(surface, state, palette)
	surface.surface_end_design_space()
	return true


func _palette(state: Dictionary) -> Dictionary:
	return {
		"primary": Color(str(state.get("cabinet_primary", "#19d6ff"))),
		"secondary": Color(str(state.get("cabinet_secondary", "#ff4fd8"))),
		"body": Color(str(state.get("cabinet_body", "#111a2b"))),
		"glass": Color(str(state.get("cabinet_glass", "#071323"))),
		"button": Color(str(state.get("cabinet_button", "#1ac8ff"))),
		"trim": Color(str(state.get("cabinet_trim", "#f7ef75"))),
	}


func _draw_authored_cabinet(surface, state: Dictionary, palette: Dictionary) -> void:
	var cabinet_id := str(state.get("cabinet_id", "jacks_or_better"))
	var primary: Color = palette["primary"]
	var secondary: Color = palette["secondary"]
	var body: Color = palette["body"]
	var glass: Color = palette["glass"]
	var trim: Color = palette["trim"]
	var pulse := 1.0 if bool(state.get("reduce_motion", false)) else (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 520.0))
	surface.draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color("#02040a"))
	surface.draw_rect(Rect2(8, 6, 944, 528), body.darkened(0.28))
	surface.draw_rect(Rect2(8, 6, 944, 528), trim.darkened(0.25), false, 4)
	surface.draw_rect(Rect2(20, 10, 920, 516), primary, false, 2)
	match cabinet_id:
		"double_deuces":
			_draw_double_deuces_shell(surface, primary, secondary, trim, pulse)
		"triple_double_bonus":
			_draw_triple_bonus_shell(surface, primary, secondary, trim, pulse)
		_:
			_draw_neon_jacks_shell(surface, primary, secondary, trim, pulse)
	surface.draw_rect(HEADER, Color("#050914"))
	surface.draw_rect(HEADER, primary, false, 3)
	surface.draw_rect(HEADER.grow(-6), secondary.darkened(0.62), false, 1)
	surface.draw_rect(PAYTABLE, Color("#050912"))
	surface.draw_rect(PAYTABLE, secondary.darkened(0.08), false, 2)
	surface.draw_rect(PLAYFIELD, glass.darkened(0.45))
	surface.draw_rect(PLAYFIELD, primary, false, 3)
	surface.draw_rect(PLAYFIELD.grow(-5), secondary.darkened(0.35), false, 1)
	surface.draw_rect(CONTROL_DECK, body.lightened(0.05))
	surface.draw_rect(CONTROL_DECK, trim.darkened(0.18), false, 3)
	_draw_marquee(surface, state, palette)


func _draw_neon_jacks_shell(surface, primary: Color, secondary: Color, trim: Color, pulse: float) -> void:
	for index in range(18):
		var x := 30.0 + float(index) * 52.8
		var bulb := primary if index % 2 == 0 else secondary
		surface.draw_circle(Vector2(x, 8), 3.0, Color(bulb.r, bulb.g, bulb.b, 0.58 + 0.42 * pulse))
		surface.draw_circle(Vector2(x, 532), 3.0, bulb.darkened(0.18))
	for index in range(14):
		var x := 54.0 + float((index * 67) % 852)
		var y := 90.0 + float((index * 43) % 338)
		var star := primary if index % 2 == 0 else secondary
		surface.draw_rect(Rect2(x - 5, y, 10, 2), star.darkened(0.55))
		surface.draw_rect(Rect2(x - 1, y - 4, 2, 10), star.darkened(0.62))
	surface.draw_polygon([Vector2(12, 94), Vector2(38, 74), Vector2(38, 450), Vector2(12, 430)], [Color(primary.r, primary.g, primary.b, 0.24)]) # SA2_PER_FRAME_OK: bounded authored cabinet geometry with no state copies.
	surface.draw_polygon([Vector2(948, 94), Vector2(922, 74), Vector2(922, 450), Vector2(948, 430)], [Color(secondary.r, secondary.g, secondary.b, 0.24)]) # SA2_PER_FRAME_OK: bounded authored cabinet geometry with no state copies.
	surface.draw_rect(Rect2(30, 74, 900, 5), trim.darkened(0.2))


func _draw_double_deuces_shell(surface, primary: Color, secondary: Color, trim: Color, pulse: float) -> void:
	for row in range(8):
		var y := 92.0 + float(row) * 48.0
		var trace_alpha := 0.48 + 0.34 * pulse
		surface.draw_line(Vector2(10, y), Vector2(34, y - 18), Color(primary.r, primary.g, primary.b, trace_alpha), 3)
		surface.draw_line(Vector2(926, y - 18), Vector2(950, y), Color(secondary.r, secondary.g, secondary.b, trace_alpha), 3)
	for index in range(7):
		var x := 82.0 + float(index) * 132.0
		surface.surface_label("2", Vector2(x, 444), 34, Color(primary.r, primary.g, primary.b, 0.16))
	surface.draw_polygon([Vector2(12, 72), Vector2(40, 104), Vector2(40, 430), Vector2(12, 464)], [Color(primary.r, primary.g, primary.b, 0.24)]) # SA2_PER_FRAME_OK: bounded authored cabinet geometry with no state copies.
	surface.draw_polygon([Vector2(948, 72), Vector2(920, 104), Vector2(920, 430), Vector2(948, 464)], [Color(secondary.r, secondary.g, secondary.b, 0.24)]) # SA2_PER_FRAME_OK: bounded authored cabinet geometry with no state copies.
	surface.draw_rect(Rect2(388, 4, 184, 8), trim.darkened(0.22))


func _draw_triple_bonus_shell(surface, primary: Color, secondary: Color, trim: Color, pulse: float) -> void:
	for ray in range(12):
		var x := 18.0 + float(ray) * 82.0
		surface.draw_polygon([Vector2(480, 268), Vector2(x, 8), Vector2(x + 44, 8)], [Color(trim.r, trim.g, trim.b, 0.05)]) # SA2_PER_FRAME_OK: twelve fixed decorative rays, no dynamic allocation growth.
	for coin in range(10):
		var x := 28.0 + float((coin * 97) % 904)
		var y := 90.0 + float((coin * 61) % 350)
		surface.draw_circle(Vector2(x, y), 9.0, Color(trim.r, trim.g, trim.b, 0.16 + 0.14 * pulse))
		surface.draw_circle(Vector2(x, y), 5.0, Color(primary.r, primary.g, primary.b, 0.18))
	surface.draw_polygon([
		Vector2(398, 16), Vector2(420, 2), Vector2(444, 18),
		Vector2(480, 0), Vector2(516, 18), Vector2(540, 2),
		Vector2(562, 16), Vector2(550, 34), Vector2(410, 34),
	], [Color(trim.r, trim.g, trim.b, 0.26)]) # SA2_PER_FRAME_OK: fixed nine-point crown silhouette.
	surface.draw_rect(Rect2(32, 74, 896, 5), secondary.darkened(0.30))


func _draw_marquee(surface, state: Dictionary, palette: Dictionary) -> void:
	var primary: Color = palette["primary"]
	var secondary: Color = palette["secondary"]
	var trim: Color = palette["trim"]
	var title := str(state.get("machine_name", "VIDEO POKER")).to_upper()
	var hand_count := maxi(1, int(state.get("hand_count", 1)))
	surface.surface_label(title.left(28), Vector2(40, 49), 30, trim)
	surface.surface_label("%s  •  %d PLAY" % [
		str(state.get("variant_label", "Jacks or Better")).to_upper().left(24),
		hand_count,
	], Vector2(438, 45), 15, secondary)
	var denom_rect := Rect2(714, 25, 78, 32)
	surface.draw_rect(denom_rect, Color("#02050b"))
	surface.draw_rect(denom_rect, primary, false, 2)
	surface.surface_label_centered(str(state.get("coin_label", "1c")).to_upper(), denom_rect.grow(-4), 15, C_WHITE)


func _draw_paytable(surface, state: Dictionary, palette: Dictionary) -> void:
	var rows: Array = state.get("paytable_rows", [])
	var active_coin := clampi(int(state.get("coin_count", 1)), 1, MAX_COIN_COUNT)
	var win_keys: Array = state.get("winning_pay_keys", [])
	var primary: Color = palette["primary"]
	var secondary: Color = palette["secondary"]
	var trim: Color = palette["trim"]
	var label_w := 244.0
	var col_w := (PAYTABLE.size.x - label_w - 12.0) / 5.0
	var title_h := 20.0
	var row_h := (PAYTABLE.size.y - title_h - 8.0) / float(maxi(1, rows.size()))
	var row_font := 7 if row_h < 9.5 else 8
	surface.surface_label("PAY TABLE", PAYTABLE.position + Vector2(10, 15), 12, trim)
	for coin in range(1, 6):
		var col_rect := Rect2(PAYTABLE.position.x + label_w + float(coin - 1) * col_w, PAYTABLE.position.y + 3, col_w - 2, PAYTABLE.size.y - 6)
		if coin == active_coin:
			surface.draw_rect(col_rect, Color(primary.r, primary.g, primary.b, 0.17))
			surface.draw_rect(col_rect, primary, false, 2)
			surface.surface_label_centered("%d COIN" % coin, Rect2(col_rect.position, Vector2(col_rect.size.x, title_h)), 9, C_YELLOW)
		else:
			surface.surface_label_centered(str(coin), Rect2(col_rect.position, Vector2(col_rect.size.x, title_h)), 9, C_SOFT)
	for row_index in range(rows.size()):
		var row: Dictionary = rows[row_index] if typeof(rows[row_index]) == TYPE_DICTIONARY else {}
		var row_key := str(row.get("key", ""))
		var y := PAYTABLE.position.y + title_h + 2.0 + float(row_index) * row_h
		var row_rect := Rect2(PAYTABLE.position.x + 6, y, PAYTABLE.size.x - 12, row_h)
		var winning := win_keys.has(row_key)
		if winning:
			var flash_alpha := 0.28
			if not bool(state.get("reduce_motion", false)):
				flash_alpha = 0.25 + 0.15 * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 105.0))
			surface.draw_rect(row_rect, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, flash_alpha))
			surface.draw_rect(row_rect, C_YELLOW, false, 2)
		elif row_index % 2 == 0:
			surface.draw_rect(row_rect, Color(primary.r, primary.g, primary.b, 0.045))
		surface.surface_label(str(row.get("label", "")).to_upper().left(28), Vector2(row_rect.position.x + 5, row_rect.position.y + row_h - 1), row_font, C_YELLOW if winning else C_SOFT)
		for coin in range(1, 6):
			var value := int(row.get("max_mult", row.get("mult", 0))) * coin if coin == 5 and row.has("max_mult") else int(row.get("mult", 0)) * coin
			var cell := Rect2(PAYTABLE.position.x + label_w + float(coin - 1) * col_w, y, col_w - 2, row_h)
			surface.surface_label_centered(str(value), cell, row_font, C_YELLOW if winning or coin == active_coin else secondary.lightened(0.24))


func _draw_hands(surface, state: Dictionary, palette: Dictionary) -> void:
	var phase := str(state.get("phase", "idle"))
	var hand_count := maxi(1, int(state.get("hand_count", 1)))
	var display_hands: Array = state.get("display_hands", [])
	var hand_results: Array = state.get("hand_results", [])
	var holds: Array = state.get("holds", [])
	var drawn_indices: Array = state.get("drawn_indices", [])
	var layouts := _hand_layouts(hand_count)
	var flip_active := bool(surface.surface_animation_active("video_poker_flip"))
	var flip_progress := float(surface.surface_animation_progress("video_poker_flip"))
	_draw_guidance(surface, state, palette)
	for hand_index in range(layouts.size()):
		var panel: Rect2 = layouts[hand_index]
		var cards: Array = display_hands[hand_index] if hand_index < display_hands.size() and typeof(display_hands[hand_index]) == TYPE_ARRAY else []
		var result: Dictionary = hand_results[hand_index] if hand_index < hand_results.size() and typeof(hand_results[hand_index]) == TYPE_DICTIONARY else {}
		_draw_hand_panel(surface, state, palette, panel, cards, result, holds, drawn_indices, hand_index, hand_count, phase, flip_active, flip_progress)


func _draw_guidance(surface, state: Dictionary, palette: Dictionary) -> void:
	var phase := str(state.get("phase", "idle"))
	var primary: Color = palette["primary"]
	var strip := Rect2(PLAYFIELD.position + Vector2(8, 7), Vector2(PLAYFIELD.size.x - 16, 24))
	if phase == "settled":
		var result_detail := str(state.get("result_detail", state.get("outcome_headline", ""))).strip_edges()
		surface.draw_rect(strip, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.20))
		surface.draw_rect(strip, C_YELLOW, false, 2)
		surface.surface_label_centered(result_detail.left(128), strip.grow(-3), 9, C_YELLOW)
		return
	var steps := ["1  SET BET", "2  DEAL", "3  TAP CARDS TO HOLD", "4  DRAW", "5  AUTO PAY"]
	var active := 1
	if phase == "hold":
		active = 2
	var step_w := strip.size.x / float(steps.size())
	for index in range(steps.size()):
		var rect := Rect2(strip.position.x + float(index) * step_w, strip.position.y, step_w - 3, strip.size.y)
		if index == active:
			surface.draw_rect(rect, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.20))
			surface.draw_rect(rect, C_YELLOW, false, 2)
			surface.surface_label_centered(steps[index], rect.grow(-3), 9, C_YELLOW)
		else:
			surface.surface_label_centered(steps[index], rect.grow(-3), 8, Color(primary.r, primary.g, primary.b, 0.58))


func _hand_layouts(hand_count: int) -> Array:
	var area := Rect2(PLAYFIELD.position + Vector2(12, 38), Vector2(PLAYFIELD.size.x - 24, PLAYFIELD.size.y - 48))
	if hand_count <= 1:
		return [area]
	if hand_count == 2:
		var gap := 12.0
		var width := (area.size.x - gap) * 0.5
		return [
			Rect2(area.position, Vector2(width, area.size.y)),
			Rect2(area.position + Vector2(width + gap, 0), Vector2(width, area.size.y)),
		]
	var gap_x := 12.0
	var gap_y := 8.0
	var width := (area.size.x - gap_x) * 0.5
	var height := (area.size.y - gap_y) * 0.5
	return [
		Rect2(area.position, Vector2(width, height)),
		Rect2(area.position + Vector2(width + gap_x, 0), Vector2(width, height)),
		Rect2(Vector2(area.position.x + (area.size.x - width) * 0.5, area.position.y + height + gap_y), Vector2(width, height)),
	]


func _draw_hand_panel(surface, state: Dictionary, palette: Dictionary, panel: Rect2, cards: Array, result: Dictionary, holds: Array, drawn_indices: Array, hand_index: int, hand_count: int, phase: String, flip_active: bool, flip_progress: float) -> void:
	var primary: Color = palette["primary"]
	var secondary: Color = palette["secondary"]
	var winning := int(result.get("total", 0)) > 0
	surface.draw_rect(panel, Color("#020611"))
	surface.draw_rect(panel, C_YELLOW if winning else (primary if hand_index == 0 else secondary), false, 2)
	var label := "HAND %d" % (hand_index + 1)
	if phase == "settled":
		label = "%s  •  %s  •  PAY %d" % [label, str(result.get("pay_label", "NO PAY")).to_upper().left(18), int(result.get("total", 0))]
	surface.surface_label(label, panel.position + Vector2(8, 14), 9, C_YELLOW if winning else C_CYAN)
	var label_h := 18.0
	var gap := 7.0 if panel.size.x > 600 else 4.0
	var max_h := panel.size.y - label_h - 12.0
	var max_w := (panel.size.x - 16.0 - gap * 4.0) / 5.0
	var card_h := minf(max_h, max_w / 0.70)
	var card_w := card_h * 0.70
	var row_w := card_w * 5.0 + gap * 4.0
	var start := Vector2(panel.position.x + (panel.size.x - row_w) * 0.5, panel.position.y + label_h + (max_h - card_h) * 0.5 + 3.0)
	for card_index in range(5):
		var rect := Rect2(start + Vector2(float(card_index) * (card_w + gap), 0), Vector2(card_w, card_h))
		var card: Dictionary = cards[card_index] if card_index < cards.size() and typeof(cards[card_index]) == TYPE_DICTIONARY else {"hidden": true}
		var held := phase == "hold" and holds.has(card_index)
		var sequence_index := hand_index * HAND_SIZE + card_index
		var sequence_count := maxi(1, hand_count * HAND_SIZE)
		var reveal_threshold := float(sequence_index + 1) / float(sequence_count)
		var face_down := false
		if flip_active:
			if phase == "hold":
				reveal_threshold = float(card_index + 1) / float(HAND_SIZE)
				face_down = flip_progress < reveal_threshold
			elif drawn_indices.has(card_index):
				face_down = flip_progress < reveal_threshold
		_draw_card(surface, card, rect, held, winning, face_down)
		if phase == "hold":
			var badge := Rect2(rect.position + Vector2(0, rect.size.y - 16), Vector2(rect.size.x, 16))
			surface.draw_rect(badge, C_TEAL if held else Color(0.02, 0.05, 0.10, 0.88))
			surface.surface_label_centered("HELD" if held else "TAP", badge.grow(-2), 8, C_WHITE if held else C_CYAN)
			surface.surface_add_exact_hit(rect, "video_poker_hold", card_index)


func _draw_card(surface, card: Dictionary, rect: Rect2, held: bool, winning: bool, face_down: bool = false) -> void:
	if face_down or bool(card.get("hidden", false)):
		surface.draw_rect(rect, C_SOFT)
		surface.draw_rect(rect.grow(-4), Color("#341963"))
		for stripe in range(4):
			surface.draw_line(rect.position + Vector2(8, 12 + stripe * 12), rect.position + Vector2(rect.size.x - 8, 5 + stripe * 12), C_PINK.darkened(0.28), 2)
		return
	surface.draw_rect(rect.grow(3), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.34) if winning else Color(0, 0, 0, 0.50))
	surface.draw_rect(rect, Color("#fff9e8"))
	surface.draw_rect(rect.grow(-3), Color("#f7f2df"), false, 1)
	if held:
		surface.draw_rect(rect.grow(3), C_TEAL, false, 3)
	var rank := int(card.get("rank", 2))
	var suit := int(card.get("suit", 0))
	var ink := C_PINK if suit == 1 or suit == 3 else C_DARK
	var rank_size := clampi(int(rect.size.y * 0.27), 12, 30)
	surface.surface_label(CardShoeScript.rank_label(rank), rect.position + Vector2(6, rank_size + 3), rank_size, ink)
	_draw_suit(surface, rect.position + rect.size * Vector2(0.58, 0.62), suit, ink, clampf(rect.size.y / 82.0, 0.48, 1.35))


func _draw_suit(surface, pos: Vector2, suit: int, color: Color, scale: float) -> void:
	match suit:
		0:
			surface.draw_polygon([pos + Vector2(0, -11) * scale, pos + Vector2(10, 3) * scale, pos + Vector2(-10, 3) * scale], [color]) # SA2_PER_FRAME_OK: fixed three-point suit glyph.
			surface.draw_rect(Rect2(pos + Vector2(-2, 2) * scale, Vector2(4, 10) * scale), color)
		1:
			surface.draw_circle(pos + Vector2(-5, -3) * scale, 6 * scale, color)
			surface.draw_circle(pos + Vector2(5, -3) * scale, 6 * scale, color)
			surface.draw_polygon([pos + Vector2(-11, 0) * scale, pos + Vector2(11, 0) * scale, pos + Vector2(0, 12) * scale], [color]) # SA2_PER_FRAME_OK: fixed three-point suit glyph.
		2:
			surface.draw_circle(pos + Vector2(-6, 0) * scale, 6 * scale, color)
			surface.draw_circle(pos + Vector2(6, 0) * scale, 6 * scale, color)
			surface.draw_circle(pos + Vector2(0, -7) * scale, 6 * scale, color)
			surface.draw_rect(Rect2(pos + Vector2(-2, 2) * scale, Vector2(4, 10) * scale), color)
		_:
			surface.draw_polygon([pos + Vector2(0, -11) * scale, pos + Vector2(9, 0) * scale, pos + Vector2(0, 11) * scale, pos + Vector2(-9, 0) * scale], [color]) # SA2_PER_FRAME_OK: fixed four-point suit glyph.


func _draw_controls(surface, state: Dictionary, palette: Dictionary) -> void:
	var phase := str(state.get("phase", "idle"))
	var primary: Color = palette["button"]
	var secondary: Color = palette["secondary"]
	var trim: Color = palette["trim"]
	var betting := phase == "idle" or phase == "settled"
	var y := CONTROL_DECK.position.y + 10.0
	_button(surface, Rect2(44, y, 76, 40), "BET -", "video_poker_bet_down", 0, trim, betting)
	_button(surface, Rect2(128, y, 76, 40), "BET +", "video_poker_bet_one", 0, trim, betting)
	_button(surface, Rect2(212, y, 92, 40), "BET MAX", "video_poker_bet_max", 0, C_YELLOW, betting)
	_button(surface, Rect2(312, y, 78, 40), str(state.get("coin_label", "1c")).to_upper(), "video_poker_denom", 0, secondary, betting)
	var primary_label := "DRAW" if phase == "hold" else "DEAL"
	var primary_action := "video_poker_draw" if phase == "hold" else "video_poker_deal"
	_button(surface, Rect2(404, y - 3, 156, 46), primary_label, primary_action, 0, primary, phase != "double_up")
	var cheat_label := "HOLDOUT"
	var cheat_action := "video_poker_mark"
	var cheat_enabled := phase == "hold"
	if bool(state.get("holdout_ready", false)):
		cheat_label = "PALM NOW"
		cheat_action = "video_poker_palm"
	if phase == "settled" and bool(state.get("double_up_available", false)):
		cheat_label = "DOUBLE UP"
		cheat_action = "video_poker_double"
		cheat_enabled = true
	_button(surface, Rect2(572, y, 120, 40), cheat_label, cheat_action, 0, secondary, cheat_enabled)
	var wager := int(state.get("bet_credits", 0))
	var coins := int(state.get("coin_count", 1))
	var meters := Rect2(704, y, 212, 40)
	surface.draw_rect(meters, Color("#02050b"))
	surface.draw_rect(meters, trim.darkened(0.25), false, 2)
	surface.surface_label("CRED %d    WIN %d" % [int(state.get("credits", 0)), int(state.get("win_credits", 0))], Vector2(meters.position.x + 8, meters.position.y + 15), 9, C_YELLOW)
	surface.surface_label("BET %d (%d COIN/HAND)" % [wager, coins], Vector2(meters.position.x + 8, meters.position.y + 31), 9, C_CYAN)


func _button(surface, rect: Rect2, label: String, action: String, index: int, accent: Color, enabled: bool) -> void:
	var hovered := enabled and bool(surface.surface_region_hovered(action, index))
	var fill := Color(accent.r, accent.g, accent.b, 0.30 if hovered else (0.18 if enabled else 0.05))
	surface.draw_rect(rect, Color("#02040a"))
	surface.draw_rect(rect.grow(-3), fill)
	surface.draw_rect(rect, C_WHITE if hovered else (accent if enabled else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.25)), false, 2)
	surface.surface_label_centered(label, rect.grow(-5), 12, accent if enabled else Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.35))
	if enabled:
		surface.surface_add_exact_hit(rect, action, index)


func _draw_double_up(surface, state: Dictionary, palette: Dictionary) -> void:
	var view: Dictionary = state.get("double_up_view", {})
	var primary: Color = palette["primary"]
	surface.surface_label_centered("DOUBLE OR NOTHING  •  PICK A CARD HIGHER THAN THE DEALER", Rect2(PLAYFIELD.position + Vector2(12, 12), Vector2(PLAYFIELD.size.x - 24, 24)), 15, C_AMBER)
	var dealer_rect := Rect2(PLAYFIELD.position + Vector2(42, 62), Vector2(102, 142))
	_draw_card(surface, view.get("dealer", {}) if typeof(view.get("dealer", {})) == TYPE_DICTIONARY else {}, dealer_rect, false, false)
	surface.surface_label_centered("DEALER", Rect2(dealer_rect.position + Vector2(0, -20), Vector2(dealer_rect.size.x, 16)), 10, C_SOFT)
	for index in range(4):
		var rect := Rect2(PLAYFIELD.position + Vector2(226 + index * 148, 62), Vector2(102, 142))
		_draw_card(surface, {"hidden": true}, rect, false, false)
		surface.surface_add_exact_hit(rect, "video_poker_double_pick", index)
		surface.surface_label_centered("PICK %d" % (index + 1), Rect2(rect.position + Vector2(0, rect.size.y + 4), Vector2(rect.size.x, 16)), 10, primary)


func _draw_holdout(surface, state: Dictionary, palette: Dictionary) -> void:
	if not bool(state.get("holdout_ready", false)):
		return
	var meter: Dictionary = state.get("holdout_meter", {})
	var overlay := Rect2(PLAYFIELD.position + Vector2(118, 48), Vector2(PLAYFIELD.size.x - 236, 142))
	surface.draw_rect(overlay, Color(0.01, 0.01, 0.03, 0.94))
	surface.draw_rect(overlay, C_YELLOW, false, 4)
	var title := "%s  •  DRAW HOLDOUT" % str(state.get("cabinet_cheat_name", "HOLDOUT")).to_upper()
	surface.surface_label_centered(title, Rect2(overlay.position + Vector2(10, 10), Vector2(overlay.size.x - 20, 24)), 17, C_YELLOW)
	var instructions := "Time the sweep, then commit the highlighted card. The swap resolves during DRAW."
	if bool(state.get("reduce_motion", false)):
		instructions = "Reduced motion: one generous press commits the card during DRAW."
	surface.surface_label_centered(instructions, Rect2(overlay.position + Vector2(12, 40), Vector2(overlay.size.x - 24, 20)), 10, C_SOFT)
	var track := Rect2(overlay.position + Vector2(34, 78), Vector2(overlay.size.x - 68, 18))
	surface.draw_rect(track, Color("#111827"))
	surface.draw_rect(track, palette["primary"], false, 2)
	var target := clampf(float(meter.get("target", 0.58)), 0.0, 1.0)
	surface.draw_rect(Rect2(track.position.x + track.size.x * target - 3, track.position.y - 8, 6, track.size.y + 16), C_YELLOW)
	var prompt := Rect2(overlay.position + Vector2(overlay.size.x * 0.5 - 92, 106), Vector2(184, 26))
	surface.draw_rect(prompt, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.22))
	surface.draw_rect(prompt, C_YELLOW, false, 2)
	surface.surface_label_centered("PALM THE CARD", prompt.grow(-3), 12, C_YELLOW)
	surface.surface_add_exact_hit(prompt, "video_poker_palm", int(meter.get("target_slot", 0)))
