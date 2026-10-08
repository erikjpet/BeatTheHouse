class_name ScratchTicketMachineRenderer
extends RefCounted

# Draws the vending cabinet, stock glass, console, motorized shelf, timed ticket
# transfer, output tray, lighting, and discard basket from surface state.

const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const C_WHITE := VisualStyleScript.WHITE
const C_SOFT := VisualStyleScript.SOFT
const C_YELLOW := VisualStyleScript.YELLOW
const C_PINK := VisualStyleScript.PINK
const C_TEAL := VisualStyleScript.TEAL
const DISPENSE_CHANNEL := "scratch_ticket_dispense"
const COLLECT_TRAY_ACTION := "scratch_collect_tray"
const DISPENSE_DURATION_MSEC := 1500


static func draw(surface, state: Dictionary, machine_rect: Rect2) -> void:
	var pulse := 0.58 + absf(sin(float(surface.surface_flicker()) * 2.3)) * 0.34
	var shadow := Rect2(machine_rect.position + Vector2(9, 8), machine_rect.size)
	surface.draw_rect(shadow, Color(0.0, 0.0, 0.0, 0.48))
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
	surface.draw_polygon(cabinet, [Color("#10233b")])
	surface.draw_rect(machine_rect.grow(-5), Color("#234f72"), false, 2)
	_draw_light_rails(surface, machine_rect, pulse)
	_draw_marquee(surface, _marquee_rect(machine_rect), pulse)

	var stock: Array = state.get("scratch_stock", []) if typeof(state.get("scratch_stock", [])) == TYPE_ARRAY else []
	var glass := _stock_glass_rect(machine_rect)
	_draw_stock_gallery(surface, stock, glass)
	_draw_touch_console(surface, state, _console_rect(machine_rect), pulse)
	_draw_delivery_mechanism(surface, state, machine_rect, glass)
	_draw_output_tray(surface, state, output_tray_rect(machine_rect), pulse)

	var basket := waste_basket_rect(machine_rect)
	var basket_enabled := not (state.get("scratch_ticket", {}) as Dictionary).is_empty() if typeof(state.get("scratch_ticket", {})) == TYPE_DICTIONARY else false
	var basket_drop_target := basket_enabled and bool(state.get("scratch_trash_armed", false)) and waste_basket_drop_rect(machine_rect).has_point(state.get("scratch_last_pointer", Vector2.ZERO))
	_paint_waste_basket(surface, basket, basket_enabled, basket_drop_target)
	var collection := Rect2(machine_rect.position + Vector2(20, 394), Vector2(174, 11))
	var complete := bool(state.get("scratch_collection_complete", false))
	surface.surface_label_centered(str(state.get("scratch_collection_status", "0/6 PRINTS FOUND")), collection, 6, C_YELLOW if not complete else Color("#fff3a0"))


static func _draw_light_rails(surface, machine_rect: Rect2, pulse: float) -> void:
	var left := Rect2(machine_rect.position + Vector2(5, 58), Vector2(4, machine_rect.size.y - 77))
	var right := Rect2(machine_rect.position + Vector2(machine_rect.size.x - 9, 58), Vector2(4, machine_rect.size.y - 77))
	for rail in [left, right]:
		surface.draw_rect(rail.grow(2), Color("#071019"))
		surface.draw_rect(rail, Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.48 + pulse * 0.36))
	for dot in range(7):
		var y := machine_rect.position.y + 76.0 + float(dot) * 42.0
		var color := C_YELLOW if dot % 2 == 0 else C_PINK
		surface.draw_circle(Vector2(machine_rect.position.x + 7, y), 1.7, Color(color.r, color.g, color.b, 0.50 + pulse * 0.40))
		surface.draw_circle(Vector2(machine_rect.end.x - 7, y), 1.7, Color(color.r, color.g, color.b, 0.50 + pulse * 0.40))


static func _draw_marquee(surface, rect: Rect2, pulse: float) -> void:
	surface.draw_rect(rect, Color("#071019"))
	surface.draw_rect(rect.grow(-3), Color("#d82958"))
	surface.draw_rect(Rect2(rect.position + Vector2(5, 5), Vector2(rect.size.x - 10, 11)), Color("#ffdf59"))
	for bulb in range(16):
		var x := rect.position.x + 8.0 + float(bulb) * (rect.size.x - 16.0) / 15.0
		surface.draw_circle(Vector2(x, rect.end.y - 5), 2.1, Color(1.0, 0.83, 0.28, 0.58 + pulse * 0.40))
	surface.surface_label_centered("LUCKY ROAD", Rect2(rect.position + Vector2(6, 16), Vector2(rect.size.x - 12, 20)), 18, C_WHITE)
	surface.surface_label_centered("INSTANT PLAY  •  CARD KIOSK", Rect2(rect.position + Vector2(6, 36), Vector2(rect.size.x - 12, 11)), 7, Color("#b9f7ff"))


static func _draw_stock_gallery(surface, stock: Array, glass: Rect2) -> void:
	surface.draw_rect(glass.grow(4), Color("#c7d6df"))
	surface.draw_rect(glass.grow(2), Color("#14283a"))
	surface.draw_rect(glass, Color("#05090f"))
	var row_height := (glass.size.y - 8.0) / float(maxi(1, stock.size()))
	for index in range(stock.size()):
		if typeof(stock[index]) != TYPE_DICTIONARY:
			continue
		var row := Rect2(glass.position + Vector2(4, 4 + float(index) * row_height), Vector2(glass.size.x - 8, row_height - 2))
		_paint_stock_row(surface, stock[index], row, index, int((stock[index] as Dictionary).get("source_stock_index", index)))
	# Tempered-glass reflection and the little anti-tamper seal make the cabinet
	# read as a real merchandise machine instead of a flat menu.
	surface.draw_polygon([
		glass.position + Vector2(5, 2),
		glass.position + Vector2(24, 2),
		glass.position + Vector2(88, glass.size.y - 2),
		glass.position + Vector2(66, glass.size.y - 2),
	], [Color(0.72, 0.94, 1.0, 0.075)])
	var seal := Rect2(glass.end - Vector2(31, 13), Vector2(27, 9))
	surface.draw_rect(seal, Color("#e8f2f4"))
	surface.surface_label_centered("SEALED", seal, 5, Color("#243746"))


static func _draw_touch_console(surface, state: Dictionary, rect: Rect2, pulse: float) -> void:
	surface.draw_rect(rect, Color("#071019"))
	surface.draw_rect(rect, Color("#8db7cb"), false, 2)
	var screen := Rect2(rect.position + Vector2(6, 7), Vector2(rect.size.x - 12, 72))
	surface.draw_rect(screen, Color("#041c25"))
	surface.draw_rect(screen, Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.55 + pulse * 0.30), false, 2)
	var tray_count := int(state.get("scratch_tray_count", 0))
	var dispensing := bool(surface.surface_animation_active(DISPENSE_CHANNEL))
	var status := "LIFTING" if dispensing else "COLLECT" if tray_count > 0 else "SELECT"
	var status_color := C_YELLOW if dispensing or tray_count > 0 else Color("#69efb3")
	surface.surface_label_centered("CARD VAULT", Rect2(screen.position + Vector2(2, 7), Vector2(screen.size.x - 4, 9)), 6, Color("#b9f7ff"))
	surface.surface_label_centered(status, Rect2(screen.position + Vector2(2, 23), Vector2(screen.size.x - 4, 17)), 10, status_color)
	surface.surface_label_centered("%d TIX" % int(state.get("scratch_stock_available", 0)), Rect2(screen.position + Vector2(2, 48), Vector2(screen.size.x - 4, 10)), 6, C_SOFT)
	# Trading-card vending machines devote a lot of face space to a bright pack
	# preview. This generic foil pack keeps that energetic kiosk character.
	var pack := Rect2(rect.position + Vector2(13, 87), Vector2(rect.size.x - 26, 52))
	surface.draw_rect(Rect2(pack.position + Vector2(3, 3), pack.size), Color(0.0, 0.0, 0.0, 0.45))
	surface.draw_rect(pack, Color("#173e69"))
	surface.draw_rect(pack, C_YELLOW, false, 2)
	surface.draw_circle(pack.get_center(), 12, Color("#ee315d"))
	surface.draw_circle(pack.get_center(), 6, Color("#fff3c0"))
	surface.draw_line(Vector2(pack.position.x + 4, pack.get_center().y), Vector2(pack.end.x - 4, pack.get_center().y), Color("#fff3c0"), 2)
	surface.surface_label_centered("BONUS ART", Rect2(pack.position + Vector2(1, 37), Vector2(pack.size.x - 2, 9)), 5, C_WHITE)
	var tap := Rect2(rect.position + Vector2(8, 148), Vector2(rect.size.x - 16, 30))
	surface.draw_rect(tap, Color("#102b36"))
	surface.draw_rect(tap, Color("#72dbe6"), false, 1)
	surface.surface_label_centered("TAP", Rect2(tap.position + Vector2(1, 3), Vector2(tap.size.x - 2, 9)), 6, C_WHITE)
	for arc in range(3):
		surface.draw_arc(tap.get_center() + Vector2(0, 5), 3.0 + float(arc) * 3.0, PI, TAU, 8, Color("#72dbe6"), 1)
	var keypad_origin := rect.position + Vector2(9, 186)
	for key in range(9):
		var key_rect := Rect2(keypad_origin + Vector2(float(key % 3) * 15.0, float(key / 3) * 14.0), Vector2(11, 10))
		surface.draw_rect(key_rect, Color("#293842"))
		surface.draw_rect(key_rect, Color("#6f8794"), false, 1)
	var receipt := Rect2(rect.position + Vector2(12, rect.size.y - 20), Vector2(rect.size.x - 24, 7))
	surface.draw_rect(receipt, Color("#020304"))
	surface.surface_label_centered("RECEIPT", Rect2(receipt.position + Vector2(0, 8), Vector2(receipt.size.x, 8)), 5, C_SOFT)


static func _draw_delivery_mechanism(surface, state: Dictionary, machine_rect: Rect2, glass: Rect2) -> void:
	var bay := _mechanism_bay_rect(machine_rect)
	surface.draw_rect(bay, Color("#071019"))
	surface.draw_rect(bay, Color("#6f8794"), false, 2)
	var rail_x := glass.end.x - 11.0
	surface.draw_line(Vector2(rail_x, glass.position.y + 6), Vector2(rail_x, bay.end.y - 4), Color("#748a98"), 3)
	surface.draw_line(Vector2(rail_x + 5, glass.position.y + 6), Vector2(rail_x + 5, bay.end.y - 4), Color("#263743"), 2)
	for notch in range(12):
		var y := glass.position.y + 9.0 + float(notch) * 21.0
		surface.draw_line(Vector2(rail_x - 2, y), Vector2(rail_x + 8, y), Color("#9fb2bd"), 1)
	if not bool(surface.surface_animation_active(DISPENSE_CHANNEL)):
		var parked := Rect2(Vector2(glass.position.x + 5, bay.position.y + 3), Vector2(glass.size.x - 17, 7))
		surface.draw_rect(parked, Color("#9ba8ae"))
		surface.draw_rect(parked, Color("#d9e2e5"), false, 1)
		return
	var elapsed_msec := int(surface.surface_elapsed(DISPENSE_CHANNEL) * 1000.0)
	var event := _active_dispense_event(state, elapsed_msec)
	if event.is_empty():
		return
	var local_msec := elapsed_msec - int(event.get("start_msec", 0))
	var slot := clampi(int(event.get("slot", 0)), 0, 6)
	var row_height := (glass.size.y - 8.0) / 7.0
	var pickup_y := glass.position.y + 4.0 + (float(slot) + 0.5) * row_height
	var parked_y := bay.position.y + 4.0
	var lift_arrive := maxi(1, int(event.get("lift_arrive_msec", 470)))
	var pickup_end := maxi(lift_arrive + 1, int(event.get("pickup_msec", 650)))
	var lower_start := maxi(pickup_end + 1, int(event.get("lower_start_msec", 720)))
	var tray_land := maxi(lower_start + 1, int(event.get("tray_land_msec", 1360)))
	var shelf_y := parked_y
	if local_msec < lift_arrive:
		shelf_y = lerpf(parked_y, pickup_y, _ease_in_out_cubic(float(local_msec) / float(lift_arrive)))
	elif local_msec < lower_start:
		shelf_y = pickup_y
	elif local_msec < tray_land:
		shelf_y = lerpf(pickup_y, parked_y, _ease_in_out_cubic(float(local_msec - lower_start) / float(tray_land - lower_start)))
	var shelf_extension := 0.62
	if local_msec >= lift_arrive and local_msec < pickup_end:
		shelf_extension = lerpf(0.62, 1.0, clampf(float(local_msec - lift_arrive) / float(pickup_end - lift_arrive), 0.0, 1.0))
	elif local_msec >= pickup_end:
		shelf_extension = 1.0
	var shelf_width := (glass.size.x - 17.0) * shelf_extension
	var shelf := Rect2(Vector2(glass.end.x - 11.0 - shelf_width, shelf_y - 3.0), Vector2(shelf_width, 8))
	surface.draw_rect(shelf.grow(3), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.14))
	surface.draw_rect(shelf, Color("#aebbc1"))
	surface.draw_rect(shelf, Color("#edf5f7"), false, 1)
	surface.draw_circle(Vector2(rail_x + 2, shelf_y + 1), 5, Color("#f1bd48"))
	var ticket: Dictionary = event.get("ticket", {}) if typeof(event.get("ticket", {})) == TYPE_DICTIONARY else {}
	if local_msec >= lift_arrive and not ticket.is_empty():
		var ticket_size := Vector2(62, 19)
		var ticket_pos := Vector2(shelf.position.x + 8, shelf.position.y - ticket_size.y + 2)
		if local_msec >= tray_land:
			var drop_t := clampf(float(local_msec - tray_land) / float(maxi(1, DISPENSE_DURATION_MSEC - tray_land)), 0.0, 1.0)
			ticket_pos = ticket_pos.lerp(output_tray_rect(machine_rect).position + Vector2(44, 8), _ease_out_cubic(drop_t))
		_paint_tray_ticket(surface, ticket, Rect2(ticket_pos, ticket_size), 1.0)


static func _draw_output_tray(surface, state: Dictionary, rect: Rect2, pulse: float) -> void:
	surface.draw_rect(rect.grow(3), Color("#020305"))
	surface.draw_rect(rect, Color("#101820"))
	surface.draw_rect(Rect2(rect.position + Vector2(5, 7), Vector2(rect.size.x - 10, rect.size.y - 12)), Color("#020407"))
	surface.draw_line(rect.position + Vector2(7, 7), rect.end - Vector2(7, rect.size.y - 7), Color("#6f8794"), 2)
	var tray: Array = state.get("scratch_tray_stack", []) if typeof(state.get("scratch_tray_stack", [])) == TYPE_ARRAY else []
	var hidden := _hidden_dispensing_ids(surface, state)
	var visible: Array = []
	for ticket_value in tray:
		if typeof(ticket_value) == TYPE_DICTIONARY and not hidden.has(str((ticket_value as Dictionary).get("id", ""))):
			visible.append(ticket_value)
	var shown := mini(4, visible.size())
	for index in range(shown):
		var ticket: Dictionary = visible[visible.size() - shown + index]
		var ticket_rect := Rect2(rect.position + Vector2(13.0 + float(index) * 5.0, 9.0 - float(index) * 2.0), Vector2(92, 22))
		_paint_tray_ticket(surface, ticket, ticket_rect, 0.96)
	var total := int(state.get("scratch_tray_count", tray.size()))
	var dispensing := bool(surface.surface_animation_active(DISPENSE_CHANNEL))
	var label := "LIFT IN MOTION" if dispensing else "CLICK TO COLLECT  •  %d" % total if total > 0 else "DELIVERY TRAY"
	var color := C_YELLOW if dispensing or total > 0 else C_SOFT
	surface.surface_label_centered(label, Rect2(rect.position + Vector2(4, rect.size.y - 14), Vector2(rect.size.x - 8, 10)), 6, color)
	if total > 0 and not dispensing:
		surface.draw_rect(rect.grow(2), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.35 + pulse * 0.30), false, 2)
		surface.surface_add_invisible_hit(rect.grow(3), COLLECT_TRAY_ACTION, 0)


static func _active_dispense_event(state: Dictionary, elapsed_msec: int) -> Dictionary:
	var events: Array = state.get("scratch_dispense_events", []) if typeof(state.get("scratch_dispense_events", [])) == TYPE_ARRAY else []
	for event_value in events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var local := elapsed_msec - int(event.get("start_msec", 0))
		if local >= 0 and local < int(event.get("duration_msec", DISPENSE_DURATION_MSEC)):
			return event
	return {}


static func _hidden_dispensing_ids(surface, state: Dictionary) -> Dictionary:
	var hidden := {}
	if not bool(surface.surface_animation_active(DISPENSE_CHANNEL)):
		return hidden
	var elapsed_msec := int(surface.surface_elapsed(DISPENSE_CHANNEL) * 1000.0)
	var events: Array = state.get("scratch_dispense_events", []) if typeof(state.get("scratch_dispense_events", [])) == TYPE_ARRAY else []
	for event_value in events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var local := elapsed_msec - int(event.get("start_msec", 0))
		if local < int(event.get("tray_land_msec", 1360)):
			hidden[str(event.get("ticket_id", ""))] = true
	return hidden


static func _paint_stock_row(surface, slot: Dictionary, rect: Rect2, display_index: int, action_index: int) -> void:
	var palette: Dictionary = slot.get("palette", {}) if typeof(slot.get("palette", {})) == TYPE_DICTIONARY else {}
	var paper := Color(str(palette.get("paper", "#fff2c7")))
	var ink := Color(str(palette.get("ink", "#35152e")))
	var accent := Color(str(palette.get("accent", "#ef3156")))
	var trim := Color(str(palette.get("trim", "#f5c843")))
	var remaining := int(slot.get("remaining", 0))
	var sold_out := remaining <= 0
	var hovered := bool(surface.surface_region_hovered("scratch_buy", action_index))
	surface.draw_rect(rect, Color("#112233") if not hovered else Color("#19394d"))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.56 if hovered else 0.28), false, 1)
	var ticket := Rect2(rect.position + Vector2(3, 3), Vector2(35, rect.size.y - 6))
	surface.draw_rect(Rect2(ticket.position + Vector2(2, 2), ticket.size), Color(0.0, 0.0, 0.0, 0.46))
	surface.draw_rect(ticket, Color(paper.r * (0.38 if sold_out else 1.0), paper.g * (0.38 if sold_out else 1.0), paper.b * (0.38 if sold_out else 1.0)))
	surface.draw_rect(Rect2(ticket.position, Vector2(ticket.size.x, maxf(6.0, ticket.size.y * 0.30))), Color(accent.r, accent.g, accent.b, 0.36 if sold_out else 1.0))
	for mark in range(3):
		surface.draw_circle(ticket.position + Vector2(8 + mark * 9, ticket.size.y * 0.70), 1.8, Color(trim.r, trim.g, trim.b, 0.30 if sold_out else 0.84))
	surface.surface_label(_stock_label(slot), rect.position + Vector2(43, 11), 6, C_SOFT)
	surface.surface_label("OUT" if sold_out else "$%d  %d LEFT" % [int(slot.get("price", 1)), remaining], rect.position + Vector2(43, 22), 6, C_PINK if sold_out else C_WHITE)
	var select := Rect2(rect.end - Vector2(22, rect.size.y - 4), Vector2(18, rect.size.y - 8))
	surface.draw_rect(select, Color("#43131b") if sold_out else Color("#126544"))
	surface.draw_rect(select, C_PINK if sold_out else Color("#62e3a2"), false, 1 if not hovered else 2)
	surface.surface_label_centered(str(display_index + 1), select, 8, C_WHITE)
	if not sold_out:
		surface.surface_add_hit(rect, "scratch_buy", action_index)
		for quantity in range(2, mini(3, remaining) + 1):
			var quantity_rect := Rect2(rect.position + Vector2(rect.size.x - 46.0 - float(quantity - 2) * 23.0, rect.size.y - 9.0), Vector2(20, 8))
			surface.draw_rect(quantity_rect, Color("#1d4734"))
			surface.draw_rect(quantity_rect, Color("#62e3a2"), false, 1)
			surface.surface_label_centered("x%d" % quantity, quantity_rect, 5, C_WHITE)
			surface.surface_add_hit(quantity_rect, "scratch_buy", action_index + (quantity - 1) * 100)


static func _paint_tray_ticket(surface, ticket: Dictionary, rect: Rect2, alpha: float) -> void:
	var face: Dictionary = ticket.get("face", {}) if typeof(ticket.get("face", {})) == TYPE_DICTIONARY else {}
	var palette: Dictionary = face.get("palette", ticket.get("palette", {})) if typeof(face.get("palette", ticket.get("palette", {}))) == TYPE_DICTIONARY else {}
	var paper := Color(str(palette.get("paper", "#fff2c7")))
	var accent := Color(str(palette.get("accent", "#ef3156")))
	surface.draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size), Color(0.0, 0.0, 0.0, 0.30 * alpha))
	surface.draw_rect(rect, Color(paper.r, paper.g, paper.b, alpha))
	surface.draw_rect(Rect2(rect.position, Vector2(rect.size.x, maxf(5.0, rect.size.y * 0.28))), Color(accent.r, accent.g, accent.b, alpha))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, alpha), false, 1)
	surface.surface_label(str(ticket.get("display_name", "TICKET")).to_upper().left(13), rect.position + Vector2(5, rect.size.y - 5), 5, Color("#251722"))


static func output_tray_rect(machine_rect: Rect2) -> Rect2:
	return Rect2(machine_rect.position + Vector2(18, 352), Vector2(176, 39))


static func waste_basket_rect(machine_rect: Rect2) -> Rect2:
	return Rect2(machine_rect.position + Vector2(205, 319), Vector2(57, 72))


static func waste_basket_drop_rect(machine_rect: Rect2) -> Rect2:
	var basket := waste_basket_rect(machine_rect)
	return Rect2(basket.position + Vector2(7, 9), Vector2(basket.size.x - 14, basket.size.y - 18))


static func _marquee_rect(machine_rect: Rect2) -> Rect2:
	return Rect2(machine_rect.position + Vector2(11, 7), Vector2(machine_rect.size.x - 22, 51))


static func _stock_glass_rect(machine_rect: Rect2) -> Rect2:
	return Rect2(machine_rect.position + Vector2(14, 66), Vector2(184, 238))


static func _console_rect(machine_rect: Rect2) -> Rect2:
	return Rect2(machine_rect.position + Vector2(205, 66), Vector2(57, 238))


static func _mechanism_bay_rect(machine_rect: Rect2) -> Rect2:
	return Rect2(machine_rect.position + Vector2(14, 309), Vector2(184, 39))


static func _stock_label(slot: Dictionary) -> String:
	match str(slot.get("type_id", "")):
		"crossword_corner": return "CROSSWORD"
		"high_roller_holdem": return "HIGH ROLLER"
		"golden_vault": return "GOLD VAULT"
	return str(slot.get("display_name", "TICKET")).to_upper().left(13)


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
		var x := rect.position.x + 15 + bar * 9
		surface.draw_line(Vector2(x, rect.position.y + 22), Vector2(x - 2, rect.end.y - 11), dark, 2)
	surface.draw_rect(Rect2(rect.position + Vector2(4, 12), Vector2(rect.size.x - 8, 7)), Color("#d8dde1") if enabled else metal)
	surface.draw_rect(Rect2(rect.position + Vector2(16, 5), Vector2(rect.size.x - 32, 8)), dark, false, 3)
	surface.surface_label_centered("RELEASE" if drop_target else "DRAG HERE", Rect2(rect.position + Vector2(-3, rect.size.y - 14), Vector2(rect.size.x + 6, 12)), 6, Color("#fff3c0") if enabled else C_SOFT)


static func _ease_in_out_cubic(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) * 0.5


static func _ease_out_cubic(value: float) -> float:
	var inverse := 1.0 - clampf(value, 0.0, 1.0)
	return 1.0 - inverse * inverse * inverse
