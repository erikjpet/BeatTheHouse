class_name CoinPusherRoomProp
extends RefCounted

const KitScript := preload("res://scripts/ui/game_props/game_prop_kit.gd")
const EMPTY_STATE: Dictionary = {}
const C_CYAN := Color("#58ead9")
const C_PINK := Color("#ff6588")
const C_YELLOW := Color("#f2cb55")
const C_WHITE := Color("#fff0c2")


static func draw(canvas: CanvasItem, rect: Rect2, object_data: Dictionary, accent: Color, selected: bool, disabled: bool, flicker: float) -> void:
	var safe := Rect2(rect.position + Vector2(rect.size.x * 0.06, rect.size.y * 0.06), Vector2(rect.size.x * 0.88, rect.size.y * 0.90))
	var visual: Dictionary = object_data.get("visual_state", EMPTY_STATE) if typeof(object_data.get("visual_state", EMPTY_STATE)) == TYPE_DICTIONARY else EMPTY_STATE
	var identity: String = visual.get("identity", "quarter_falls")
	var body_color: Color = visual.get("body_color", Color("#6f2028"))
	var side_color: Color = visual.get("side_color", Color("#3c111b"))
	var trim_color: Color = visual.get("trim_color", C_YELLOW)
	var light_color: Color = visual.get("light_color", C_WHITE)
	var glass_color: Color = visual.get("glass_color", Color("#82c9d8"))
	var deck_color: Color = visual.get("deck_color", Color("#173b42"))
	var platform_color: Color = visual.get("platform_color", Color("#d49c42"))
	var backglass_color: Color = visual.get("backglass_color", Color("#46131c"))
	var topper_style: String = visual.get("topper_style", "crown_lights")
	var backglass_style: String = visual.get("backglass_style", "prize_showcase")
	var phase_value := KitScript.phase(object_data)
	var pulse := KitScript.pulse(flicker, phase_value, selected)
	KitScript.draw_base_shadow(canvas, safe, accent)
	if safe.size.x < 58.0 or safe.size.y < 42.0:
		_draw_small(canvas, safe, identity, body_color, trim_color, glass_color)
		KitScript.draw_state(canvas, safe, selected, disabled)
		return
	var body := Rect2(safe.position + Vector2(safe.size.x * 0.12, safe.size.y * 0.20), Vector2(safe.size.x * 0.76, safe.size.y * 0.69))
	if identity == "jackpot_ridge":
		body = Rect2(safe.position + Vector2(safe.size.x * 0.08, safe.size.y * 0.19), Vector2(safe.size.x * 0.84, safe.size.y * 0.70))
	elif identity == "vault_drop":
		body = Rect2(safe.position + Vector2(safe.size.x * 0.15, safe.size.y * 0.17), Vector2(safe.size.x * 0.70, safe.size.y * 0.72))
	canvas.draw_rect(Rect2(body.position + Vector2(-safe.size.x * 0.035, 3.0), Vector2(safe.size.x * 0.05, body.size.y - 6.0)), side_color)
	canvas.draw_rect(Rect2(body.position + Vector2(body.size.x - safe.size.x * 0.015, 3.0), Vector2(safe.size.x * 0.05, body.size.y - 6.0)), side_color)
	canvas.draw_rect(body, body_color)
	canvas.draw_rect(body, Color(trim_color.r, trim_color.g, trim_color.b, 0.30 + pulse * 0.32), false, 2.0)
	_draw_topper(canvas, safe, identity, topper_style, trim_color, light_color, pulse)
	var backglass := Rect2(body.position + Vector2(body.size.x * 0.10, body.size.y * 0.08), Vector2(body.size.x * 0.80, body.size.y * 0.22))
	canvas.draw_rect(backglass, backglass_color)
	canvas.draw_rect(backglass, Color(light_color.r, light_color.g, light_color.b, 0.30 + pulse * 0.22), false, 1.0)
	_draw_backglass(canvas, backglass, identity, backglass_style, trim_color, light_color, int(visual.get("feature_count", 0)), pulse)
	var glass := Rect2(body.position + Vector2(body.size.x * 0.08, body.size.y * 0.34), Vector2(body.size.x * 0.84, body.size.y * 0.38))
	canvas.draw_rect(glass, Color("#050a0d"))
	canvas.draw_rect(glass, Color(glass_color.r, glass_color.g, glass_color.b, 0.20))
	canvas.draw_rect(glass, Color(glass_color.r, glass_color.g, glass_color.b, 0.72), false, 1.0)
	_draw_playfield(canvas, glass, identity, deck_color, platform_color, trim_color, light_color, int(visual.get("pile_count", 18)), int(visual.get("feature_count", 0)))
	var controls := Rect2(body.position + Vector2(body.size.x * 0.08, body.size.y * 0.75), Vector2(body.size.x * 0.84, body.size.y * 0.08))
	canvas.draw_rect(controls, deck_color.darkened(0.28))
	canvas.draw_circle(controls.position + Vector2(controls.size.x * 0.20, controls.size.y * 0.50), maxf(1.5, controls.size.y * 0.22), C_PINK)
	canvas.draw_circle(controls.position + Vector2(controls.size.x * 0.80, controls.size.y * 0.50), maxf(1.5, controls.size.y * 0.22), light_color)
	var tray := Rect2(body.position + Vector2(body.size.x * 0.20, body.size.y * 0.85), Vector2(body.size.x * 0.60, body.size.y * 0.09))
	canvas.draw_rect(tray, Color("#030407"))
	canvas.draw_rect(tray, trim_color, false, 1.0)
	for index in range(mini(5, int(visual.get("tray_count", 0)))):
		canvas.draw_circle(tray.position + Vector2(5.0 + float(index) * maxf(4.0, tray.size.x * 0.15), tray.size.y * 0.55), 1.5, C_YELLOW)
	if not bool(object_data.get("hide_prop_text", false)):
		var font: Font = canvas.get_theme_default_font()
		var marquee: String = visual.get("marquee", "QUARTER FALLS")
		canvas.draw_string(font, safe.position + Vector2(2.0, safe.size.y * 0.16), marquee, HORIZONTAL_ALIGNMENT_CENTER, safe.size.x - 4.0, 7, light_color)
	KitScript.draw_state(canvas, safe, selected, disabled)


static func draw_low_detail(canvas: CanvasItem, rect: Rect2, object_data: Dictionary, accent: Color, disabled: bool, flicker: float) -> void:
	var safe := rect.grow(-3.0)
	var visual: Dictionary = object_data.get("visual_state", EMPTY_STATE) if typeof(object_data.get("visual_state", EMPTY_STATE)) == TYPE_DICTIONARY else EMPTY_STATE
	var identity: String = visual.get("identity", "quarter_falls")
	var body_color: Color = visual.get("body_color", Color("#6f2028"))
	var trim_color: Color = visual.get("trim_color", C_YELLOW)
	var glass_color: Color = visual.get("glass_color", C_CYAN)
	KitScript.draw_base_shadow(canvas, safe, accent)
	_draw_small(canvas, safe, identity, body_color, trim_color, glass_color)
	if disabled:
		KitScript.draw_state(canvas, safe, false, true)


static func _draw_topper(canvas: CanvasItem, safe: Rect2, identity: String, style: String, trim: Color, light: Color, pulse: float) -> void:
	var center_x := safe.get_center().x
	if style == "peak" or identity == "jackpot_ridge":
		canvas.draw_line(Vector2(safe.position.x + safe.size.x * 0.18, safe.position.y + safe.size.y * 0.18), Vector2(center_x, safe.position.y), trim, 5.0)
		canvas.draw_line(Vector2(center_x, safe.position.y), Vector2(safe.end.x - safe.size.x * 0.18, safe.position.y + safe.size.y * 0.18), trim, 5.0)
		for index in range(5):
			canvas.draw_circle(safe.position + Vector2(safe.size.x * (0.30 + float(index) * 0.10), safe.size.y * (0.12 - absf(2.0 - float(index)) * 0.025)), 1.4 + pulse, light)
	elif style == "dial" or identity == "vault_drop":
		canvas.draw_circle(Vector2(center_x, safe.position.y + safe.size.y * 0.09), safe.size.y * 0.095, trim)
		canvas.draw_circle(Vector2(center_x, safe.position.y + safe.size.y * 0.09), safe.size.y * 0.060, Color("#17343b"))
		canvas.draw_line(Vector2(center_x, safe.position.y + safe.size.y * 0.09), Vector2(center_x + safe.size.x * 0.04, safe.position.y + safe.size.y * 0.045), light, 2.0)
	else:
		canvas.draw_rect(Rect2(safe.position + Vector2(safe.size.x * 0.18, safe.size.y * 0.05), Vector2(safe.size.x * 0.64, safe.size.y * 0.12)), Color("#54151f"))
		canvas.draw_rect(Rect2(safe.position + Vector2(safe.size.x * 0.34, safe.size.y * 0.01), Vector2(safe.size.x * 0.32, safe.size.y * 0.06)), trim)
		for index in range(5):
			canvas.draw_circle(safe.position + Vector2(safe.size.x * (0.26 + float(index) * 0.12), safe.size.y * 0.06), 1.3 + pulse, light)


static func _draw_backglass(canvas: CanvasItem, rect: Rect2, identity: String, style: String, trim: Color, light: Color, feature_count: int, pulse: float) -> void:
	if style == "value_lamps" or identity == "jackpot_ridge":
		for index in range(5):
			var lamp := rect.position + Vector2(rect.size.x * (0.12 + float(index) * 0.19), rect.size.y * 0.52)
			canvas.draw_circle(lamp, maxf(1.2, rect.size.y * 0.16), trim if index <= feature_count % 5 else Color(trim.r, trim.g, trim.b, 0.22))
	elif style == "dual_value_dial" or identity == "vault_drop":
		canvas.draw_circle(rect.position + Vector2(rect.size.x * 0.32, rect.size.y * 0.50), rect.size.y * 0.31, trim)
		canvas.draw_circle(rect.position + Vector2(rect.size.x * 0.32, rect.size.y * 0.50), rect.size.y * 0.21, Color("#17343b"))
		canvas.draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.58, rect.size.y * 0.25), Vector2(rect.size.x * 0.27, rect.size.y * 0.50)), Color(light.r, light.g, light.b, 0.18 + pulse * 0.20))
		canvas.draw_line(rect.position + Vector2(rect.size.x * 0.60, rect.size.y * 0.50), rect.position + Vector2(rect.size.x * 0.83, rect.size.y * 0.50), light, 1.0)
	else:
		# A loose cascade of quarters reads as a coin-pusher marque, not a row of reels.
		for index in range(5):
			var coin := rect.position + Vector2(rect.size.x * (0.14 + float(index) * 0.18), rect.size.y * (0.34 + float(index % 2) * 0.28))
			canvas.draw_circle(coin, maxf(1.4, rect.size.y * 0.16), trim)
			canvas.draw_circle(coin, maxf(0.7, rect.size.y * 0.08), light if index < maxi(1, feature_count) else Color(light.r, light.g, light.b, 0.38))
		canvas.draw_line(rect.position + Vector2(rect.size.x * 0.50, 1.0), rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.82), Color(light.r, light.g, light.b, 0.45), 1.0)
		canvas.draw_line(rect.position + Vector2(rect.size.x * 0.44, rect.size.y * 0.65), rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.82), trim, 1.0)
		canvas.draw_line(rect.position + Vector2(rect.size.x * 0.56, rect.size.y * 0.65), rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.82), trim, 1.0)


static func _draw_playfield(canvas: CanvasItem, glass: Rect2, identity: String, deck: Color, platform: Color, trim: Color, light: Color, pile_count: int, feature_count: int) -> void:
	var board := Rect2(glass.position + Vector2(3.0, 2.0), Vector2(glass.size.x - 6.0, glass.size.y * 0.36))
	canvas.draw_rect(board, deck)
	if identity == "jackpot_ridge":
		for index in range(3):
			var x := board.position.x + board.size.x * (0.24 + float(index) * 0.26)
			canvas.draw_circle(Vector2(x, board.position.y + 2.0), 2.0, trim)
			canvas.draw_line(Vector2(x, board.position.y + 3.0), Vector2(x, board.end.y), Color(light.r, light.g, light.b, 0.28), 1.0)
		for row in range(2):
			for column in range(5):
				canvas.draw_circle(board.position + Vector2(board.size.x * (0.14 + float(column) * 0.18), board.size.y * (0.48 + float(row) * 0.32)), 1.0, light)
	elif identity == "vault_drop":
		for column in range(4):
			var cell := Rect2(board.position + Vector2(2.0 + float(column) * board.size.x * 0.245, 2.0), Vector2(board.size.x * 0.20, board.size.y - 4.0))
			canvas.draw_rect(cell, Color("#13262c"))
			canvas.draw_rect(cell, C_CYAN if column < feature_count % 5 else Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.25), false, 1.0)
	else:
		# The coin chute and flared guide rails make the mechanism legible at room scale.
		canvas.draw_rect(Rect2(board.position + Vector2(board.size.x * 0.44, 0.0), Vector2(board.size.x * 0.12, board.size.y * 0.44)), Color("#080b0e"))
		canvas.draw_circle(board.position + Vector2(board.size.x * 0.50, board.size.y * 0.28), maxf(1.5, board.size.y * 0.18), C_YELLOW)
		canvas.draw_line(board.position + Vector2(board.size.x * 0.12, 2.0), board.position + Vector2(board.size.x * 0.30, board.size.y - 1.0), light, 1.0)
		canvas.draw_line(board.position + Vector2(board.size.x * 0.88, 2.0), board.position + Vector2(board.size.x * 0.70, board.size.y - 1.0), light, 1.0)
	var shelf := Rect2(glass.position + Vector2(3.0, glass.size.y * 0.53), Vector2(glass.size.x - 6.0, glass.size.y * 0.19))
	if identity == "quarter_falls":
		# An oversized moving shelf with a dense, stepped pile is the game's dominant read.
		shelf = Rect2(glass.position + Vector2(3.0, glass.size.y * 0.43), Vector2(glass.size.x - 6.0, glass.size.y * 0.30))
	canvas.draw_rect(shelf, platform)
	canvas.draw_rect(Rect2(shelf.position + Vector2(0.0, shelf.size.y * 0.54), Vector2(shelf.size.x, shelf.size.y * 0.34)), platform.darkened(0.28))
	canvas.draw_rect(Rect2(shelf.position + Vector2(shelf.size.x * 0.08, shelf.size.y * 0.06), Vector2(shelf.size.x * 0.84, shelf.size.y * 0.24)), Color(light.r, light.g, light.b, 0.18))
	canvas.draw_line(shelf.position + Vector2(shelf.size.x * 0.08, shelf.size.y * 0.32), shelf.position + Vector2(shelf.size.x * 0.92, shelf.size.y * 0.32), trim, 2.0)
	var coin_count := clampi(pile_count / 6, 8, 16) if identity == "quarter_falls" else clampi(pile_count / 8, 6, 14)
	for index in range(coin_count):
		var columns := 8 if identity == "quarter_falls" else 7
		var coin_x := shelf.position.x + 4.0 + float(index % columns) * maxf(4.0, (shelf.size.x - 8.0) / float(columns))
		var coin_y := shelf.position.y + shelf.size.y * 0.62 - float(index / columns) * maxf(2.0, shelf.size.y * 0.24)
		canvas.draw_circle(Vector2(coin_x, coin_y), 2.0 if identity == "quarter_falls" else 1.7, C_YELLOW)
		canvas.draw_circle(Vector2(coin_x, coin_y), 0.8, Color("#fff1a0"))
	for index in range(mini(3, feature_count)):
		var marker_color := C_PINK if identity == "quarter_falls" else Color("#a77cff") if identity == "jackpot_ridge" else C_CYAN
		canvas.draw_rect(Rect2(shelf.position + Vector2(shelf.size.x * (0.27 + float(index) * 0.23), -2.0 - float(index % 2)), Vector2(4.0, 4.0)), marker_color)
	canvas.draw_line(Vector2(shelf.position.x + 2.0, shelf.end.y + glass.size.y * 0.10), Vector2(shelf.end.x - 2.0, shelf.end.y + glass.size.y * 0.10), trim, 2.0)
	if identity == "quarter_falls":
		for index in range(4):
			canvas.draw_circle(Vector2(shelf.position.x + shelf.size.x * (0.34 + float(index) * 0.11), shelf.end.y + glass.size.y * (0.04 + float(index % 2) * 0.10)), 1.7, C_YELLOW)


static func _draw_small(canvas: CanvasItem, safe: Rect2, identity: String, body: Color, trim: Color, glass: Color) -> void:
	var cabinet := Rect2(safe.position + Vector2(safe.size.x * 0.20, safe.size.y * 0.20), Vector2(safe.size.x * 0.60, safe.size.y * 0.68))
	canvas.draw_rect(cabinet, body)
	canvas.draw_rect(cabinet, trim, false, 1.0)
	if identity == "jackpot_ridge":
		canvas.draw_line(cabinet.position + Vector2(0.0, 1.0), Vector2(safe.get_center().x, safe.position.y), trim, 3.0)
		canvas.draw_line(Vector2(safe.get_center().x, safe.position.y), cabinet.position + Vector2(cabinet.size.x, 1.0), trim, 3.0)
	elif identity == "vault_drop":
		canvas.draw_circle(Vector2(safe.get_center().x, cabinet.position.y), safe.size.y * 0.10, trim)
	else:
		canvas.draw_rect(Rect2(cabinet.position + Vector2(cabinet.size.x * 0.18, -safe.size.y * 0.10), Vector2(cabinet.size.x * 0.64, safe.size.y * 0.12)), trim)
	var window := Rect2(cabinet.position + Vector2(cabinet.size.x * 0.12, cabinet.size.y * 0.20), Vector2(cabinet.size.x * 0.76, cabinet.size.y * 0.45))
	canvas.draw_rect(window, Color(glass.r, glass.g, glass.b, 0.28))
	canvas.draw_rect(window, glass, false, 1.0)
	canvas.draw_rect(Rect2(window.position + Vector2(2.0, window.size.y * 0.43), Vector2(window.size.x - 4.0, window.size.y * 0.22)), Color(trim.r, trim.g, trim.b, 0.34))
	canvas.draw_line(window.position + Vector2(2.0, window.size.y * 0.65), window.position + Vector2(window.size.x - 2.0, window.size.y * 0.65), trim, 2.0)
	for index in range(5):
		canvas.draw_circle(window.position + Vector2(4.0 + float(index) * maxf(3.0, window.size.x * 0.18), window.size.y * (0.58 - float(index % 2) * 0.15)), 1.5, C_YELLOW)
	canvas.draw_rect(Rect2(cabinet.position + Vector2(cabinet.size.x * 0.24, cabinet.size.y * 0.76), Vector2(cabinet.size.x * 0.52, cabinet.size.y * 0.11)), Color("#030407"))
