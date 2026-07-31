class_name ScratchTicketMachineRenderer
extends RefCounted

const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const C_DARK := VisualStyleScript.DARK
const C_WHITE := VisualStyleScript.WHITE
const C_SOFT := VisualStyleScript.SOFT
const C_YELLOW := VisualStyleScript.YELLOW
const C_PINK := VisualStyleScript.PINK
const C_TEAL := VisualStyleScript.TEAL


static func draw(surface, state: Dictionary, machine_rect: Rect2) -> void:
	var shadow := Rect2(machine_rect.position + Vector2(9, 8), machine_rect.size)
	surface.draw_rect(shadow, Color(0.0, 0.0, 0.0, 0.46))
	var cabinet := PackedVector2Array([
		machine_rect.position + Vector2(9, 0),
		machine_rect.position + Vector2(machine_rect.size.x - 10, 0),
		machine_rect.position + Vector2(machine_rect.size.x, 12),
		machine_rect.end - Vector2(0, 13),
		machine_rect.end - Vector2(12, 0),
		machine_rect.position + Vector2(11, machine_rect.size.y),
		machine_rect.position + Vector2(0, machine_rect.size.y - 14),
		machine_rect.position + Vector2(0, 14),
	])
	surface.draw_polygon(cabinet, [Color("#5b1625")])
	var inner := machine_rect.grow(-6)
	surface.draw_rect(inner, Color("#751b2b"), false, 2)
	var marquee := Rect2(machine_rect.position + Vector2(10, 9), Vector2(machine_rect.size.x - 20, 59))
	surface.draw_rect(marquee, Color("#b82438"))
	surface.draw_rect(marquee.grow(-4), Color("#e6374c"))
	for bulb in range(18):
		var x := marquee.position.x + 8 + float(bulb) * (marquee.size.x - 16) / 17.0
		surface.draw_circle(Vector2(x, marquee.position.y + 6), 2.4, C_YELLOW)
		surface.draw_circle(Vector2(x, marquee.end.y - 6), 2.4, C_YELLOW)
	surface.surface_label_centered("LUCKY ROAD", Rect2(marquee.position + Vector2(8, 9), Vector2(marquee.size.x - 16, 25)), 20, C_WHITE)
	surface.surface_label_centered("INSTANT TICKETS  /  SEVEN GAMES", Rect2(marquee.position + Vector2(8, 35), Vector2(marquee.size.x - 16, 13)), 8, C_YELLOW)
	var glass := Rect2(machine_rect.position + Vector2(15, 76), Vector2(machine_rect.size.x - 30, 238))
	surface.draw_rect(glass, Color("#080b12"))
	surface.draw_rect(glass.grow(3), Color("#d6a14a"), false, 3)
	surface.draw_rect(glass, Color("#87a5b7"), false, 2)
	var stock: Array = state.get("scratch_stock", []) if typeof(state.get("scratch_stock", [])) == TYPE_ARRAY else []
	var row_height := (glass.size.y - 10.0) / float(maxi(1, stock.size()))
	for index in range(stock.size()):
		if typeof(stock[index]) != TYPE_DICTIONARY:
			continue
		var row := Rect2(glass.position + Vector2(5, 5 + float(index) * row_height), Vector2(glass.size.x - 10, row_height - 3))
		_paint_stock_row(surface, stock[index], row, index)
	surface.draw_polygon([
		glass.position + Vector2(7, 3),
		glass.position + Vector2(30, 3),
		glass.position + Vector2(116, glass.size.y - 3),
		glass.position + Vector2(89, glass.size.y - 3),
	], [Color(0.70, 0.91, 1.0, 0.07)])
	var payment := Rect2(machine_rect.position + Vector2(16, 324), Vector2(76, 32))
	surface.draw_rect(payment, Color("#241018"))
	surface.draw_rect(payment, Color("#f15a6e"), false, 2)
	surface.surface_label("CASH / CARD", payment.position + Vector2(7, 13), 7, C_SOFT)
	surface.draw_rect(Rect2(payment.end - Vector2(20, 23), Vector2(10, 16)), Color("#040507"))
	var display := Rect2(machine_rect.position + Vector2(100, 324), Vector2(91, 32))
	surface.draw_rect(display, Color("#092419"))
	surface.draw_rect(display, Color("#4ddd9a"), false, 2)
	var any_stock := false
	for slot_value in stock:
		if typeof(slot_value) == TYPE_DICTIONARY and int((slot_value as Dictionary).get("remaining", 0)) > 0:
			any_stock = true
			break
	surface.surface_label_centered("MAKE A PICK" if any_stock else "SOLD OUT", display, 8, Color("#66f0ad") if any_stock else C_PINK)
	var chute := Rect2(machine_rect.position + Vector2(22, 365), Vector2(164, 29))
	surface.draw_rect(chute, Color("#1d070d"))
	surface.draw_rect(chute, Color("#f2a74d"), false, 2)
	surface.draw_rect(chute.grow(-6), Color("#020304"))
	surface.surface_label_centered("TICKET DELIVERY", chute, 7, C_SOFT)
	var basket := waste_basket_rect(machine_rect)
	var basket_enabled := not (state.get("scratch_ticket", {}) as Dictionary).is_empty() if typeof(state.get("scratch_ticket", {})) == TYPE_DICTIONARY else false
	var basket_drop_target := basket_enabled and bool(state.get("scratch_drag_active", false)) and basket.grow(12.0).has_point(state.get("scratch_last_pointer", Vector2.ZERO))
	_paint_waste_basket(surface, basket, basket_enabled, basket_drop_target)
	if typeof(state.get("scratch_ticket", {})) == TYPE_DICTIONARY and not (state.get("scratch_ticket", {}) as Dictionary).is_empty():
		surface.surface_add_hit(basket, "scratch_discard", 0)
	var collection := Rect2(machine_rect.position + Vector2(24, 397), Vector2(162, 10))
	var complete := bool(state.get("scratch_collection_complete", false))
	surface.surface_label_centered(str(state.get("scratch_collection_status", "0/7 PRINTS FOUND")), collection, 6, C_YELLOW if not complete else Color("#fff3a0"))


static func waste_basket_rect(machine_rect: Rect2) -> Rect2:
	return Rect2(machine_rect.position + Vector2(201, 324), Vector2(59, 70))


static func _paint_stock_row(surface, slot: Dictionary, rect: Rect2, index: int) -> void:
	var palette: Dictionary = slot.get("palette", {}) if typeof(slot.get("palette", {})) == TYPE_DICTIONARY else {}
	var paper := Color(str(palette.get("paper", "#fff2c7")))
	var ink := Color(str(palette.get("ink", "#35152e")))
	var accent := Color(str(palette.get("accent", "#ef3156")))
	var trim := Color(str(palette.get("trim", "#f5c843")))
	var remaining := int(slot.get("remaining", 0))
	var sold_out := remaining <= 0
	surface.draw_rect(rect, Color("#121823"))
	surface.draw_rect(rect, Color("#4b5b69"), false, 1)
	var ticket := Rect2(rect.position + Vector2(4, 3), Vector2(55, rect.size.y - 6))
	surface.draw_rect(Rect2(ticket.position + Vector2(2, 2), ticket.size), Color(0.0, 0.0, 0.0, 0.46))
	surface.draw_rect(ticket, Color(paper.r * (0.40 if sold_out else 1.0), paper.g * (0.40 if sold_out else 1.0), paper.b * (0.40 if sold_out else 1.0)))
	surface.draw_rect(Rect2(ticket.position, Vector2(ticket.size.x, maxf(7.0, ticket.size.y * 0.30))), Color(accent.r, accent.g, accent.b, 0.38 if sold_out else 1.0))
	for mark in range(5):
		surface.draw_circle(ticket.position + Vector2(8 + mark * 10, ticket.size.y * 0.68), 2.2, Color(trim.r, trim.g, trim.b, 0.32 if sold_out else 0.82))
	surface.surface_label(_stock_label(slot), rect.position + Vector2(65, 12), 7, C_SOFT)
	surface.surface_label("SOLD OUT" if sold_out else "$%d  /  %d LEFT" % [int(slot.get("price", 1)), remaining], rect.position + Vector2(65, 25), 7, C_PINK if sold_out else C_WHITE)
	var select := Rect2(rect.end - Vector2(26, rect.size.y - 4), Vector2(22, rect.size.y - 8))
	surface.draw_rect(select, Color("#43131b") if sold_out else Color("#126544"))
	surface.draw_rect(select, C_PINK if sold_out else Color("#62e3a2"), false, 2)
	surface.surface_label_centered(str(index + 1), select, 9, C_WHITE)
	if not sold_out:
		surface.surface_add_hit(rect, "scratch_buy", index)
		surface.surface_add_hit(select, "scratch_buy", index)
		for quantity in range(2, mini(3, remaining) + 1):
			var quantity_rect := Rect2(select.position - Vector2(float(quantity - 1) * 23.0, -select.size.y + 10), Vector2(20, 9))
			surface.draw_rect(quantity_rect, Color("#1d4734"))
			surface.draw_rect(quantity_rect, Color("#62e3a2"), false, 1)
			surface.surface_label_centered("x%d" % quantity, quantity_rect, 5, C_WHITE)
			surface.surface_add_hit(quantity_rect, "scratch_buy", index + (quantity - 1) * 100)


static func _stock_label(slot: Dictionary) -> String:
	match str(slot.get("type_id", "")):
		"crossword_corner": return "CROSSWORD"
		"high_roller_holdem": return "HIGH ROLLER"
		"golden_vault": return "GOLDEN VAULT"
	return str(slot.get("display_name", "TICKET")).to_upper().left(16)


static func _paint_waste_basket(surface, rect: Rect2, enabled: bool, drop_target: bool) -> void:
	var metal := Color("#f5cf65") if drop_target else Color("#9ca5ad") if enabled else Color("#4f555b")
	var dark := Color("#20262c")
	if drop_target:
		surface.draw_rect(rect.grow(5.0), Color(0.96, 0.79, 0.32, 0.22))
		surface.draw_rect(rect.grow(3.0), Color("#ffe481"), false, 3)
	surface.draw_rect(Rect2(rect.position + Vector2(4, 13), Vector2(rect.size.x - 8, rect.size.y - 18)), dark)
	surface.draw_polygon([
		rect.position + Vector2(8, 18),
		rect.end - Vector2(8, rect.size.y - 18),
		rect.end - Vector2(14, 7),
		rect.position + Vector2(14, rect.size.y - 7),
	], [metal])
	for bar in range(4):
		var x := rect.position.x + 16 + bar * 9
		surface.draw_line(Vector2(x, rect.position.y + 22), Vector2(x - 2, rect.end.y - 11), dark, 2)
	surface.draw_rect(Rect2(rect.position + Vector2(4, 12), Vector2(rect.size.x - 8, 7)), Color("#d8dde1") if enabled else metal)
	surface.draw_rect(Rect2(rect.position + Vector2(17, 5), Vector2(rect.size.x - 34, 8)), dark, false, 3)
	surface.surface_label_centered("DROP" if drop_target else "TRASH", Rect2(rect.position + Vector2(0, rect.size.y - 14), Vector2(rect.size.x, 12)), 7, Color("#fff3c0") if enabled else C_SOFT)
