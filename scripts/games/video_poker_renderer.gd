class_name VideoPokerRenderer
extends RefCounted

const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const PlayingCardRendererScript := preload("res://scripts/games/playing_card_renderer.gd")

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
	if ["double_up", "double_result"].has(str(state.get("phase", "idle"))):
		_draw_double_up(surface, state, palette)
	else:
		_draw_hands(surface, state, palette)
	_draw_controls(surface, state, palette)
	_draw_holdout(surface, state, palette)
	_draw_machine_ritual_layer(surface, state, palette)
	surface.surface_end_design_space()
	return true


func _draw_machine_ritual_layer(surface, state: Dictionary, palette: Dictionary) -> void:
	var projection_value: Variant = state.get("ritual_projection", {})
	if typeof(projection_value) != TYPE_DICTIONARY:
		return
	var projection: Dictionary = projection_value
	if projection.is_empty():
		return
	var primary: Color = palette["primary"]
	var trim: Color = palette["trim"]
	var scene_objects: Dictionary = projection.get("scene_objects", {}) if typeof(projection.get("scene_objects", {})) == TYPE_DICTIONARY else {}
	var tower_object: Dictionary = scene_objects.get("cabinet_tower_light", {}) if typeof(scene_objects.get("cabinet_tower_light", {})) == TYPE_DICTIONARY else {}
	var tower_state := str(tower_object.get("visual_state", "off"))
	var tower_color := C_ORANGE if tower_state in ["handpay", "security"] else C_YELLOW if tower_state == "service" else Color("#334057")
	var tower := Rect2(872, 18, 54, 48)
	surface.draw_rect(tower, Color("#02050b"))
	surface.draw_rect(tower, trim.darkened(0.25), false, 2)
	surface.draw_circle(tower.position + Vector2(27, 14), 10, tower_color)
	surface.surface_label_centered(tower_state.to_upper(), Rect2(tower.position + Vector2(2, 27), Vector2(50, 17)), 7, tower_color)
	var validator := Rect2(920, 470, 22, 42)
	surface.draw_rect(validator, Color("#02040a"))
	var money_path: Dictionary = scene_objects.get("cabinet_money_path", {}) if typeof(scene_objects.get("cabinet_money_path", {})) == TYPE_DICTIONARY else {}
	surface.draw_rect(validator, primary if str(money_path.get("functional_state", "locked")) == "enabled" else Color("#6f2634"), false, 2)
	surface.draw_line(validator.position + Vector2(5, 13), validator.position + Vector2(17, 13), C_WHITE, 2)
	var actors: Dictionary = projection.get("actors", {}) if typeof(projection.get("actors", {})) == TYPE_DICTIONARY else {}
	var neighbours: Dictionary = actors.get("neighbour_seats", {}) if typeof(actors.get("neighbour_seats", {})) == TYPE_DICTIONARY else {}
	if bool(neighbours.get("visible", false)):
		for x in [18.0, 942.0]:
			surface.draw_circle(Vector2(x, 286), 12, Color(0.10, 0.13, 0.18, 0.94))
			surface.draw_rect(Rect2(x - 11, 298, 22, 46), Color(0.06, 0.08, 0.12, 0.90))
	var attendant: Dictionary = actors.get("attendant_primary", {}) if typeof(actors.get("attendant_primary", {})) == TYPE_DICTIONARY else {}
	if bool(attendant.get("visible", false)):
		surface.draw_circle(Vector2(846, 188), 14, Color("#d8b287"))
		surface.draw_rect(Rect2(832, 202, 28, 64), Color("#26344d"))
		surface.surface_label("ATTENDANT", Vector2(796, 280), 8, tower_color)
	var stage := str(projection.get("result_stage", "idle"))
	if stage != "idle":
		var stage_rect := Rect2(708, 438, 204, 22)
		surface.draw_rect(stage_rect, Color("#02050b"))
		surface.draw_rect(stage_rect, primary, false, 1)
		var stage_text := "REPLACING UNHELD CARDS" if stage == "card_replacements" else "READ: %s" % str(projection.get("paytable_line", "NO PAY")).to_upper()
		surface.surface_label_centered(stage_text.left(30), stage_rect.grow(-3), 8, C_WHITE)


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
	if phase == "hold" and bool(state.get("poker_hat_strategy_active", false)):
		surface.draw_rect(strip, Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.22))
		surface.draw_rect(strip, C_TEAL, false, 2)
		surface.surface_label_centered("FRED'S PICK  •  %s" % str(state.get("recommended_hold_text", "DRAW ALL FIVE")), strip.grow(-3), 10, C_TEAL)
		return
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
	var recommended_holds: Array = state.get("recommended_holds", [])
	var poker_hat_active := bool(state.get("poker_hat_strategy_active", false))
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
		var recommended := phase == "hold" and poker_hat_active and recommended_holds.has(card_index)
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
			if poker_hat_active:
				var matches_advice := held == recommended
				var advice_label := ("RIGHT" if held else "DRAW") if matches_advice else ("HOLD" if recommended else "DROP")
				var advice_color := C_TEAL if matches_advice else C_AMBER
				surface.draw_rect(rect.grow(2), advice_color, false, 3)
				surface.draw_rect(badge, advice_color)
				surface.surface_label_centered(advice_label, badge.grow(-2), 8, C_WHITE)
			else:
				surface.draw_rect(badge, C_TEAL if held else Color(0.02, 0.05, 0.10, 0.88))
				surface.surface_label_centered("HELD" if held else "TAP", badge.grow(-2), 8, C_WHITE if held else C_CYAN)
			surface.surface_add_exact_hit(rect, "video_poker_hold", card_index)


func _draw_card(surface, card: Dictionary, rect: Rect2, held: bool, winning: bool, face_down: bool = false) -> void:
	if face_down or bool(card.get("hidden", false)):
		PlayingCardRendererScript.draw_card_back(surface, rect)
		return
	PlayingCardRendererScript.draw_card_state(surface, card, rect, held, false, winning)


func _draw_controls(surface, state: Dictionary, palette: Dictionary) -> void:
	var phase := str(state.get("phase", "idle"))
	var primary: Color = palette["button"]
	var secondary: Color = palette["secondary"]
	var trim: Color = palette["trim"]
	var betting := phase == "idle" or phase == "settled"
	var result_hold := phase == "double_result"
	var y := CONTROL_DECK.position.y + 10.0
	_button(surface, Rect2(44, y, 76, 40), "BET -", "video_poker_bet_down", 0, trim, betting)
	_button(surface, Rect2(128, y, 76, 40), "BET +", "video_poker_bet_one", 0, trim, betting)
	_button(surface, Rect2(212, y, 92, 40), "BET MAX", "video_poker_bet_max", 0, C_YELLOW, betting)
	_button(surface, Rect2(312, y, 78, 40), str(state.get("coin_label", "1c")).to_upper(), "video_poker_denom", 0, secondary, betting)
	var primary_label := "DRAW" if phase == "hold" else "DEAL"
	var primary_action := "video_poker_draw" if phase == "hold" else "video_poker_deal"
	_button(surface, Rect2(404, y - 3, 156, 46), primary_label, primary_action, 0, primary, phase != "double_up" and not result_hold)
	var cheat_label := "HOLDOUT"
	var cheat_action := "video_poker_mark"
	var cheat_enabled := phase == "hold"
	if bool(state.get("holdout_ready", false)):
		var holdout_meter: Dictionary = state.get("holdout_meter", {}) if typeof(state.get("holdout_meter", {})) == TYPE_DICTIONARY else {}
		if bool(holdout_meter.get("chain_complete", false)):
			cheat_label = "HOLDOUT LOCKED"
			cheat_enabled = false
		else:
			cheat_label = "HIT THE SWEEP"
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
	var resolved := bool(view.get("resolved", false))
	var outcome := str(view.get("outcome", ""))
	var title := "DOUBLE OR NOTHING  •  PICK A CARD HIGHER THAN THE DEALER"
	var title_color := C_AMBER
	if resolved:
		title = "DOUBLE UP %s  •  RESULT SHOWN FOR 1.5 SECONDS" % outcome.to_upper()
		title_color = C_TEAL if outcome == "win" else (C_AMBER if outcome == "push" else C_ORANGE)
	surface.surface_label_centered(title, Rect2(PLAYFIELD.position + Vector2(12, 12), Vector2(PLAYFIELD.size.x - 24, 24)), 15, title_color)
	var dealer_rect := Rect2(PLAYFIELD.position + Vector2(42, 62), Vector2(102, 142))
	_draw_card(surface, view.get("dealer", {}) if typeof(view.get("dealer", {})) == TYPE_DICTIONARY else {}, dealer_rect, false, false)
	surface.surface_label_centered("DEALER", Rect2(dealer_rect.position + Vector2(0, -20), Vector2(dealer_rect.size.x, 16)), 10, C_SOFT)
	for index in range(4):
		var rect := Rect2(PLAYFIELD.position + Vector2(226 + index * 148, 62), Vector2(102, 142))
		var selected := resolved and index == int(view.get("selected_pick", -1))
		var picks: Array = view.get("picks", []) if typeof(view.get("picks", [])) == TYPE_ARRAY else []
		var shown_card: Dictionary = picks[index] if index < picks.size() and typeof(picks[index]) == TYPE_DICTIONARY else {"hidden": true}
		_draw_card(surface, shown_card if selected else {"hidden": true}, rect, false, selected)
		if selected:
			surface.draw_rect(rect.grow(5), title_color, false, 4)
		else:
			surface.draw_rect(rect.grow(2), Color(primary.r, primary.g, primary.b, 0.20), false, 1)
		if not resolved:
			surface.surface_add_exact_hit(rect, "video_poker_double_pick", index)
		var pick_label := "YOUR PICK" if selected else ("PICK %d" % (index + 1))
		surface.surface_label_centered(pick_label, Rect2(rect.position + Vector2(0, rect.size.y + 4), Vector2(rect.size.x, 16)), 10, title_color if selected else primary)


func _draw_holdout(surface, state: Dictionary, palette: Dictionary) -> void:
	if not bool(state.get("holdout_ready", false)):
		return
	var meter: Dictionary = state.get("holdout_meter", {})
	if bool(meter.get("chain_complete", false)):
		var locked := Rect2(PLAYFIELD.position + Vector2(166, 42), Vector2(PLAYFIELD.size.x - 332, 38))
		surface.draw_rect(locked, Color(0.01, 0.05, 0.04, 0.94))
		surface.draw_rect(locked, C_TEAL, false, 3)
		surface.surface_label_centered("HOLDOUT LOCKED  •  PRESS DRAW TO RESOLVE", locked.grow(-5), 13, C_TEAL)
		return
	var overlay := Rect2(PLAYFIELD.position + Vector2(118, 48), Vector2(PLAYFIELD.size.x - 236, 142))
	surface.draw_rect(overlay, Color(0.01, 0.01, 0.03, 0.94))
	surface.draw_rect(overlay, C_YELLOW, false, 4)
	var beat_index := clampi(int(meter.get("beat_index", 0)), 0, maxi(0, int(meter.get("beat_count", 1)) - 1))
	var beat_count := maxi(1, int(meter.get("beat_count", 1)))
	var title := "%s  •  STAGE %d/%d: %s" % [
		str(state.get("cabinet_cheat_name", "HOLDOUT")).to_upper(),
		beat_index + 1,
		beat_count,
		str(meter.get("beat_label", "LINE UP")).to_upper(),
	]
	surface.surface_label_centered(title, Rect2(overlay.position + Vector2(10, 10), Vector2(overlay.size.x - 20, 24)), 17, C_YELLOW)
	var target_slot := clampi(int(meter.get("target_slot", 0)), 0, HAND_SIZE - 1)
	var instructions := "Stop the moving bar inside the yellow zone."
	if str(meter.get("beat_kind", "timing")) == "target":
		instructions = "Stop the sweep to commit highlighted card %d." % (target_slot + 1)
	if bool(state.get("reduce_motion", false)):
		instructions = "Reduced motion: one generous press commits the card during DRAW."
	surface.surface_label_centered(instructions, Rect2(overlay.position + Vector2(12, 40), Vector2(overlay.size.x - 24, 20)), 10, C_SOFT)
	var track := Rect2(overlay.position + Vector2(34, 78), Vector2(overlay.size.x - 68, 18))
	surface.draw_rect(track, Color("#111827"))
	surface.draw_rect(track, palette["primary"], false, 2)
	var target := clampf(float(meter.get("target", 0.58)), 0.0, 1.0)
	var good_window := clampf(float(meter.get("good_window", 0.20)), 0.02, 0.48)
	var perfect_window := clampf(float(meter.get("perfect_window", 0.08)), 0.01, good_window)
	var good_left := clampf(target - good_window, 0.0, 1.0)
	var good_right := clampf(target + good_window, 0.0, 1.0)
	var perfect_left := clampf(target - perfect_window, 0.0, 1.0)
	var perfect_right := clampf(target + perfect_window, 0.0, 1.0)
	surface.draw_rect(Rect2(track.position.x + track.size.x * good_left, track.position.y + 2, track.size.x * (good_right - good_left), track.size.y - 4), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.28))
	surface.draw_rect(Rect2(track.position.x + track.size.x * perfect_left, track.position.y, track.size.x * (perfect_right - perfect_left), track.size.y), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.72))
	var sweep := clampf(float(meter.get("progress", 0.0)), 0.0, 1.0)
	var sweep_x := track.position.x + track.size.x * sweep
	surface.draw_rect(Rect2(sweep_x - 4, track.position.y - 10, 8, track.size.y + 20), C_WHITE)
	surface.draw_rect(Rect2(sweep_x - 7, track.position.y - 6, 14, track.size.y + 12), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.35), false, 2)
	var prompt := Rect2(overlay.position + Vector2(overlay.size.x * 0.5 - 92, 106), Vector2(184, 26))
	surface.draw_rect(prompt, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.22))
	surface.draw_rect(prompt, C_YELLOW, false, 2)
	var prompt_label := "STOP SWEEP"
	var prompt_index := 0
	if str(meter.get("beat_kind", "timing")) == "target":
		prompt_label = "COMMIT CARD %d" % (target_slot + 1)
		prompt_index = target_slot
	surface.surface_label_centered(prompt_label, prompt.grow(-3), 12, C_YELLOW)
	surface.surface_add_exact_hit(prompt, "video_poker_palm", prompt_index)
