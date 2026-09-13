class_name ScratchTicketRoomProp
extends RefCounted

const Kit := preload("res://scripts/ui/game_props/game_prop_kit.gd")
const EMPTY_STATE: Dictionary = {}
const EMPTY_ROWS: Array = []
const C_RED := Color("#d62e48")
const C_GOLD := Color("#e4b84e")
const C_GLASS := Color("#86aabd")
const C_GREEN := Color("#58dfa1")
const C_PINK := Color("#f15a78")
const C_SOFT := Color("#aeb4bc")


static func draw(canvas: CanvasItem, rect: Rect2, object_data: Dictionary, accent: Color, selected: bool, disabled: bool, flicker: float) -> void:
	var safe := Rect2(rect.position + Vector2(rect.size.x * 0.05, rect.size.y * 0.02), Vector2(rect.size.x * 0.90, rect.size.y * 0.94))
	var visual: Dictionary = object_data.get("visual_state", EMPTY_STATE) if typeof(object_data.get("visual_state", EMPTY_STATE)) == TYPE_DICTIONARY else EMPTY_STATE
	var rows: Array = visual.get("stock_rows", EMPTY_ROWS) if typeof(visual.get("stock_rows", EMPTY_ROWS)) == TYPE_ARRAY else EMPTY_ROWS
	var phase_value := Kit.phase(object_data)
	var pulse := Kit.pulse(flicker, phase_value, selected)
	Kit.draw_base_shadow(canvas, safe, accent)
	if safe.size.x < 58.0 or safe.size.y < 42.0:
		_draw_small(canvas, safe, rows)
		Kit.draw_state(canvas, safe, selected, disabled)
		return
	var cabinet := Rect2(safe.position + Vector2(safe.size.x * 0.11, safe.size.y * 0.09), Vector2(safe.size.x * 0.69, safe.size.y * 0.80))
	var basket := Rect2(safe.position + Vector2(safe.size.x * 0.78, safe.size.y * 0.58), Vector2(safe.size.x * 0.16, safe.size.y * 0.28))
	canvas.draw_rect(Rect2(cabinet.position + Vector2(-safe.size.x * 0.04, safe.size.y * 0.07), Vector2(safe.size.x * 0.045, cabinet.size.y * 0.76)), Color(C_RED.r, C_RED.g, C_RED.b, 0.30 + pulse * 0.25))
	canvas.draw_rect(cabinet, Color("#591423"))
	canvas.draw_rect(cabinet, Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.34 + pulse * 0.24), false, 2.0)
	var marquee := Rect2(cabinet.position + Vector2(cabinet.size.x * 0.07, -safe.size.y * 0.07), Vector2(cabinet.size.x * 0.86, safe.size.y * 0.16))
	canvas.draw_rect(marquee, C_RED)
	canvas.draw_rect(marquee, Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.56 + pulse * 0.28), false, 2.0)
	for index in range(6):
		canvas.draw_circle(marquee.position + Vector2(marquee.size.x * (0.08 + float(index) * 0.17), 1.0), 1.2 + pulse * 0.8, C_GOLD)
	if not bool(object_data.get("hide_prop_text", false)):
		canvas.draw_string(canvas.get_theme_default_font(), marquee.position + Vector2(2.0, marquee.size.y * 0.70), "LUCKY TIX", HORIZONTAL_ALIGNMENT_CENTER, marquee.size.x - 4.0, 7, Color("#fff4da"))
	var glass := Rect2(cabinet.position + Vector2(cabinet.size.x * 0.09, cabinet.size.y * 0.16), Vector2(cabinet.size.x * 0.82, cabinet.size.y * 0.48))
	canvas.draw_rect(glass, Color("#070a10"))
	canvas.draw_rect(glass, Color(C_GLASS.r, C_GLASS.g, C_GLASS.b, 0.18))
	canvas.draw_rect(glass, C_GLASS, false, 1.0)
	var visible_rows := mini(4, rows.size())
	for index in range(visible_rows):
		var row_value: Variant = rows[index]
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_value
		var ticket_width := (glass.size.x - 7.0) * 0.50
		var ticket_height := (glass.size.y - 7.0) * 0.50
		var row_rect := Rect2(glass.position + Vector2(2.0 + float(index % 2) * (ticket_width + 3.0), 2.0 + float(index / 2) * (ticket_height + 3.0)), Vector2(ticket_width, ticket_height))
		var remaining := int(row.get("remaining", 0))
		var paper: Color = row.get("paper_color", Color("#fff1ba"))
		var ticket_accent: Color = row.get("accent_color", C_PINK)
		canvas.draw_rect(row_rect, paper.darkened(0.58) if remaining <= 0 else paper)
		canvas.draw_rect(Rect2(row_rect.position, Vector2(row_rect.size.x, maxf(2.0, row_rect.size.y * 0.25))), Color(ticket_accent.r, ticket_accent.g, ticket_accent.b, 0.38 if remaining <= 0 else 1.0))
		for mark in range(3):
			canvas.draw_circle(row_rect.position + Vector2(row_rect.size.x * (0.28 + float(mark) * 0.23), row_rect.size.y * 0.61), maxf(1.1, row_rect.size.y * 0.11), Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.35 if remaining <= 0 else 0.92))
		canvas.draw_rect(Rect2(row_rect.position + Vector2(row_rect.size.x * 0.12, row_rect.size.y * 0.82), Vector2(row_rect.size.x * 0.76, 1.0)), C_GREEN if remaining > 0 else C_PINK)
	for index in range(visible_rows, 4):
		var ticket_width := (glass.size.x - 7.0) * 0.50
		var ticket_height := (glass.size.y - 7.0) * 0.50
		canvas.draw_rect(Rect2(glass.position + Vector2(2.0 + float(index % 2) * (ticket_width + 3.0), 2.0 + float(index / 2) * (ticket_height + 3.0)), Vector2(ticket_width, ticket_height)), Color("#171a21"))
	var payment := Rect2(cabinet.position + Vector2(cabinet.size.x * 0.10, cabinet.size.y * 0.69), Vector2(cabinet.size.x * 0.26, cabinet.size.y * 0.10))
	canvas.draw_rect(payment, Color("#231018"))
	canvas.draw_rect(payment, C_PINK, false, 1.0)
	canvas.draw_circle(payment.position + Vector2(payment.size.x * 0.22, payment.size.y * 0.50), maxf(1.2, payment.size.y * 0.18), C_GOLD)
	var display := Rect2(cabinet.position + Vector2(cabinet.size.x * 0.42, cabinet.size.y * 0.69), Vector2(cabinet.size.x * 0.47, cabinet.size.y * 0.10))
	canvas.draw_rect(display, Color("#092419"))
	canvas.draw_rect(display, C_GREEN if int(visual.get("stock_total", 0)) > 0 else C_PINK, false, 1.0)
	var chute := Rect2(cabinet.position + Vector2(cabinet.size.x * 0.17, cabinet.size.y * 0.84), Vector2(cabinet.size.x * 0.66, cabinet.size.y * 0.08))
	canvas.draw_rect(chute, Color("#020304"))
	canvas.draw_rect(chute, C_GOLD, false, 1.0)
	_draw_dispensed_ticket(canvas, Rect2(chute.position + Vector2(chute.size.x * 0.26, 1.0), Vector2(chute.size.x * 0.48, safe.size.y * 0.17)))
	_draw_basket(canvas, basket)
	var coin := safe.position + Vector2(safe.size.x * 0.87, safe.size.y * 0.46)
	canvas.draw_circle(coin, maxf(2.2, safe.size.x * 0.025), C_GOLD)
	canvas.draw_line(coin - Vector2(1.5, 0.0), coin + Vector2(1.5, 0.0), Color("#7e5420"), 1.0)
	Kit.draw_state(canvas, safe, selected, disabled)


static func draw_low_detail(canvas: CanvasItem, rect: Rect2, object_data: Dictionary, accent: Color, disabled: bool, flicker: float) -> void:
	var safe := rect.grow(-3.0)
	var visual: Dictionary = object_data.get("visual_state", EMPTY_STATE) if typeof(object_data.get("visual_state", EMPTY_STATE)) == TYPE_DICTIONARY else EMPTY_STATE
	var rows: Array = visual.get("stock_rows", EMPTY_ROWS) if typeof(visual.get("stock_rows", EMPTY_ROWS)) == TYPE_ARRAY else EMPTY_ROWS
	Kit.draw_base_shadow(canvas, safe, accent)
	_draw_small(canvas, safe, rows)
	if disabled:
		Kit.draw_state(canvas, safe, false, true)


static func _draw_basket(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(2.0, rect.size.y * 0.20), Vector2(rect.size.x - 4.0, rect.size.y * 0.72)), Color("#48505a"))
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, maxf(2.0, rect.size.y * 0.18))), C_SOFT)
	for index in range(3):
		var x := rect.position.x + rect.size.x * (0.28 + float(index) * 0.22)
		canvas.draw_line(Vector2(x, rect.position.y + rect.size.y * 0.28), Vector2(x - 1.0, rect.end.y - 2.0), Color("#20262c"), 1.0)


static func _draw_dispensed_ticket(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Color("#fff1ba"))
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, maxf(2.0, rect.size.y * 0.22))), C_PINK)
	canvas.draw_rect(rect, C_GOLD, false, 1.0)
	for index in range(3):
		canvas.draw_circle(rect.position + Vector2(rect.size.x * (0.27 + float(index) * 0.23), rect.size.y * 0.58), maxf(1.2, rect.size.y * 0.10), C_SOFT)
		canvas.draw_circle(rect.position + Vector2(rect.size.x * (0.27 + float(index) * 0.23), rect.size.y * 0.58), maxf(0.5, rect.size.y * 0.04), Color("#68707a"))
	for index in range(4):
		canvas.draw_circle(rect.position + Vector2(rect.size.x * (0.12 + float(index) * 0.25), rect.size.y), 0.9, Color("#fff1ba"))


static func _draw_small(canvas: CanvasItem, safe: Rect2, rows: Array) -> void:
	var cabinet := Rect2(safe.position + Vector2(safe.size.x * 0.16, safe.size.y * 0.12), Vector2(safe.size.x * 0.62, safe.size.y * 0.76))
	canvas.draw_rect(cabinet, Color("#591423"))
	canvas.draw_rect(cabinet, C_GOLD, false, 1.0)
	canvas.draw_rect(Rect2(cabinet.position + Vector2(cabinet.size.x * 0.08, -safe.size.y * 0.07), Vector2(cabinet.size.x * 0.84, safe.size.y * 0.13)), C_RED)
	var glass := Rect2(cabinet.position + Vector2(cabinet.size.x * 0.10, cabinet.size.y * 0.16), Vector2(cabinet.size.x * 0.80, cabinet.size.y * 0.49))
	canvas.draw_rect(glass, Color("#0a0d13"))
	for index in range(4):
		var color := Color("#fff1ba")
		if index < rows.size() and typeof(rows[index]) == TYPE_DICTIONARY:
			color = (rows[index] as Dictionary).get("paper_color", Color("#fff1ba"))
		var ticket := Rect2(glass.position + Vector2(2.0 + float(index % 2) * glass.size.x * 0.48, 2.0 + float(index / 2) * glass.size.y * 0.48), Vector2(glass.size.x * 0.42, glass.size.y * 0.40))
		canvas.draw_rect(ticket, color)
		canvas.draw_circle(ticket.position + Vector2(ticket.size.x * 0.50, ticket.size.y * 0.64), 1.2, C_SOFT)
	var chute := Rect2(cabinet.position + Vector2(cabinet.size.x * 0.20, cabinet.size.y * 0.76), Vector2(cabinet.size.x * 0.60, cabinet.size.y * 0.09))
	canvas.draw_rect(chute, Color("#020304"))
	_draw_dispensed_ticket(canvas, Rect2(chute.position + Vector2(chute.size.x * 0.29, 1.0), Vector2(chute.size.x * 0.42, safe.size.y * 0.15)))
	_draw_basket(canvas, Rect2(safe.position + Vector2(safe.size.x * 0.78, safe.size.y * 0.58), Vector2(safe.size.x * 0.15, safe.size.y * 0.27)))
