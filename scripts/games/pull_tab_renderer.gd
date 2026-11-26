extends RefCounted

# Draws the cabinet and builds its hit regions from the public surface snapshot.

const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")
const MachineSpecScript := preload("res://scripts/games/pull_tab_machine_spec.gd")
const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const C_DARK := VisualStyleScript.DARK
const C_PINK := VisualStyleScript.PINK
const C_PINK_2 := VisualStyleScript.PINK_2
const C_CYAN := VisualStyleScript.CYAN
const C_TEAL := VisualStyleScript.TEAL
const C_YELLOW := VisualStyleScript.YELLOW
const C_AMBER := VisualStyleScript.AMBER
const C_WHITE := VisualStyleScript.WHITE
const C_SOFT := VisualStyleScript.SOFT
const SURFACE_DESIGN_SIZE := Vector2(VisualStyleScript.GAME_BOARD_SIZE)
const PULL_TAB_REVEAL_ROW_DURATION_MSEC := 260
const PULL_TAB_REVEAL_STAGGER_MSEC := 310
const PULL_TAB_STACK_HEADER_BUTTON_WIDTHS := [18.0, 18.0, 34.0, 50.0]
const PULL_TAB_STACK_HEADER_BUTTON_GAP := 2.0
const PULL_TAB_STACK_HEADER_RIGHT_MARGIN := 8.0
const PULL_TAB_STACK_HEADER_LEAVE_LEFT_X := 776.0
const PULL_TAB_STACK_HEADER_LEAVE_GAP := 16.0
const PULL_TAB_DISPENSE_CHANNEL := MachineSpecScript.PULL_TAB_DISPENSE_CHANNEL
const PULL_TAB_DISPENSE_EVENT_DURATION_MSEC := MachineSpecScript.PULL_TAB_DISPENSE_EVENT_DURATION_MSEC
const PULL_TAB_REVEAL_CHANNEL := MachineSpecScript.PULL_TAB_REVEAL_CHANNEL
const PULL_TAB_REVEAL_TOTAL_MSEC := MachineSpecScript.PULL_TAB_REVEAL_TOTAL_MSEC
const PULL_TAB_FILE_CHANNEL := MachineSpecScript.PULL_TAB_FILE_CHANNEL
const PULL_TAB_COLLECT_TRAY_ACTION := MachineSpecScript.PULL_TAB_COLLECT_TRAY_ACTION
const PULL_TAB_FILE_TICKET_ACTION := MachineSpecScript.PULL_TAB_FILE_TICKET_ACTION
const PULL_TAB_AUTO_OPEN_ACTION := MachineSpecScript.PULL_TAB_AUTO_OPEN_ACTION
const DEFAULT_DEAL_COUNT := MachineSpecScript.DEFAULT_DEAL_COUNT
const PULL_TAB_DISPENSE_DROP_START_MSEC := MachineSpecScript.PULL_TAB_DISPENSE_DROP_START_MSEC
const PULL_TAB_DISPENSE_DROP_DURATION_MSEC := MachineSpecScript.PULL_TAB_DISPENSE_DROP_DURATION_MSEC
const PULL_TAB_MACHINE_COLUMN_COUNT := MachineSpecScript.PULL_TAB_MACHINE_COLUMN_COUNT


static func draw(surface, surface_state: Dictionary) -> bool:
	if str(surface_state.get("surface_renderer", "")) != "pull_tab_machine":
		return false
	surface.surface_begin_design_space(SURFACE_DESIGN_SIZE)
	var deals := _dictionary_view_array(surface_state.get("pull_tab_deals", []))
	var stack := _dictionary_view_array(surface_state.get("pull_tab_stack", []))
	var tray_stack := _dictionary_view_array(surface_state.get("pull_tab_tray_stack", []))
	var winner_pile := _dictionary_view_array(surface_state.get("pull_tab_winner_pile", []))
	var loser_pile := _dictionary_view_array(surface_state.get("pull_tab_loser_pile", []))
	var cabinet := Rect2(20, 8, 390, 414)
	var stack_panel := Rect2(430, 18, 448, 394)
	_draw_pull_tab_cabinet(surface, cabinet, deals, tray_stack, surface_state)
	_draw_pull_tab_stack_panel(surface, stack_panel, surface_state, stack, winner_pile, loser_pile)
	if bool(surface.surface_animation_active(PULL_TAB_DISPENSE_CHANNEL)):
		_draw_pull_tab_dispense_animation(surface, surface_state, cabinet)
	return true


static func _draw_pull_tab_cabinet(surface, cabinet: Rect2, deals: Array, tray_stack: Array, surface_state: Dictionary) -> void:
	var clock := float(surface.surface_flicker())
	var side := [
		cabinet.position + Vector2(54, 0),
		cabinet.position + Vector2(cabinet.size.x, 18),
		cabinet.position + Vector2(cabinet.size.x, cabinet.size.y),
		cabinet.position + Vector2(0, cabinet.size.y - 4),
		cabinet.position + Vector2(0, 58),
	]
	surface.draw_polygon(side, [Color("#08090c")])
	surface.draw_polygon([
		cabinet.position + Vector2(54, 0),
		cabinet.position + Vector2(cabinet.size.x, 18),
		cabinet.position + Vector2(cabinet.size.x - 22, 70),
		cabinet.position + Vector2(24, 54),
	], [Color("#1d222b")])
	surface.draw_rect(Rect2(cabinet.position + Vector2(0, 58), Vector2(cabinet.size.x - 22, cabinet.size.y - 60)), Color("#11141a"))
	surface.draw_rect(Rect2(cabinet.position + Vector2(10, 66), Vector2(cabinet.size.x - 42, cabinet.size.y - 76)), Color("#1b2028"))
	surface.draw_rect(Rect2(cabinet.position + Vector2(0, 58), Vector2(cabinet.size.x - 22, cabinet.size.y - 60)), Color("#3a404b"), false, 3)
	_draw_pull_tab_master_marquee(surface, Rect2(cabinet.position + Vector2(74, 16), Vector2(236, 44)))
	var window := Rect2(cabinet.position + Vector2(30, 82), Vector2(242, 166))
	_draw_pull_tab_window_stacks(surface, window, deals, surface_state)
	var control_panel := Rect2(cabinet.position + Vector2(282, 82), Vector2(76, 166))
	_draw_pull_tab_control_panel(surface, control_panel, deals, surface_state)
	var button_rail := Rect2(cabinet.position + Vector2(18, 254), Vector2(340, 42))
	surface.draw_rect(button_rail, Color("#0c0e12"))
	surface.draw_rect(button_rail, Color("#353a43"), false, 2)
	for index in range(PULL_TAB_MACHINE_COLUMN_COUNT):
		var deal := (deals[index] as Dictionary) if index < deals.size() else {}
		var button_rect := Rect2(button_rail.position + Vector2(14 + index * 56, 7), Vector2(44, 26))
		_draw_pull_tab_column_button(surface, deal, index, button_rect)
	var master_rect := Rect2(button_rail.position + Vector2(264, 6), Vector2(58, 28))
	_draw_pull_tab_master_button(surface, deals, master_rect)
	var tray := Rect2(cabinet.position + Vector2(24, 304), Vector2(300, 82))
	_draw_pull_tab_machine_tray(surface, tray, tray_stack, surface_state)
	var lower_cut := Rect2(cabinet.position + Vector2(24, 392), Vector2(300, 50))
	surface.draw_rect(lower_cut, Color("#151922"))
	surface.draw_rect(lower_cut, Color("#353a43"), false, 2)
	surface.draw_circle(cabinet.position + Vector2(198, 408), 3.0 + absf(sin(clock * 2.0)) * 0.7, Color("#da355a"))


static func _draw_pull_tab_master_marquee(surface, rect: Rect2) -> void:
	var points := [
		rect.position + Vector2(0, 7),
		rect.position + Vector2(rect.size.x - 12, 0),
		rect.end - Vector2(0, 8),
		rect.position + Vector2(12, rect.size.y),
	]
	surface.draw_polygon(points, [Color("#f6f2e8")])
	for i in range(points.size()):
		surface.draw_line(points[i], points[(i + 1) % points.size()], Color("#2b3038"), 2)
	surface.surface_label("THE", rect.position + Vector2(-30, 18), 13, C_PINK)
	surface.surface_label("MASTER", rect.position + Vector2(44, 31), 27, C_PINK)
	surface.surface_label("4", rect.end + Vector2(8, -16), 20, C_PINK)


static func _draw_pull_tab_window_stacks(surface, rect: Rect2, deals: Array, surface_state: Dictionary) -> void:
	surface.draw_rect(rect.grow(6), Color("#050608"))
	surface.draw_rect(rect, Color("#090b10"))
	surface.draw_rect(rect, Color("#d5e2e8"), false, 2)
	surface.draw_rect(Rect2(rect.position + Vector2(6, 6), rect.size - Vector2(12, 12)), Color("#10131a"))
	for index in range(PULL_TAB_MACHINE_COLUMN_COUNT):
		var deal := (deals[index] as Dictionary) if index < deals.size() else {}
		var column_rect := Rect2(rect.position + Vector2(18 + index * 52, 16), Vector2(38, rect.size.y - 32))
		_draw_pull_tab_column_stack(surface, column_rect, deal, index, surface_state)
	var glare_alpha := 0.10 + absf(sin(float(surface.surface_flicker()) * 1.7)) * 0.04
	surface.draw_polygon([
		rect.position + Vector2(12, 6),
		rect.position + Vector2(rect.size.x * 0.40, 6),
		rect.position + Vector2(rect.size.x * 0.24, rect.size.y - 8),
		rect.position + Vector2(4, rect.size.y - 8),
	], [Color(1.0, 1.0, 1.0, glare_alpha)])


static func _draw_pull_tab_column_stack(surface, rect: Rect2, deal: Dictionary, index: int, surface_state: Dictionary) -> void:
	var palette: Dictionary = deal.get("palette", {})
	var paper := Color(str(palette.get("paper", "#fff0d8")))
	var accent := Color(str(palette.get("accent", "#ff4fb3")))
	var count := maxi(1, int(deal.get("ticket_count", DEFAULT_DEAL_COUNT)))
	var remaining := clampi(int(deal.get("remaining", count)), 0, count)
	var ratio := clampf(float(remaining) / float(count), 0.0, 1.0)
	var min_height := 18.0 if remaining > 0 else 0.0
	var stack_height := maxf(min_height, rect.size.y * ratio)
	var stack_rect := Rect2(Vector2(rect.position.x, rect.end.y - stack_height), Vector2(rect.size.x, stack_height))
	surface.draw_rect(rect, Color("#06080d"))
	surface.draw_rect(rect, Color("#2e3440"), false, 1)
	if remaining <= 0:
		surface.draw_line(rect.position + Vector2(6, rect.size.y * 0.5), rect.end - Vector2(6, rect.size.y * 0.5), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.60), 2)
		surface.surface_label("OUT", rect.position + Vector2(8, rect.size.y - 6), 7, C_PINK)
		return
	for row in range(0, int(stack_height), 7):
		var y := stack_rect.end.y - float(row)
		var shade := 0.86 - float((row / 7 + index) % 3) * 0.045
		surface.draw_rect(Rect2(stack_rect.position.x + 5, y - 4, stack_rect.size.x - 10, 4), Color(paper.r * shade, paper.g * shade, paper.b * shade, 0.95))
		surface.draw_rect(Rect2(stack_rect.position.x + 8, y - 3, stack_rect.size.x - 16, 1), Color(accent.r, accent.g, accent.b, 0.38))
	var top := Rect2(stack_rect.position + Vector2(4, -2), Vector2(stack_rect.size.x - 8, 10))
	surface.draw_rect(top, paper)
	surface.draw_rect(top, accent, false, 1)
	var glimmer: Dictionary = surface_state.get("pull_tab_glimmer", {}) if typeof(surface_state.get("pull_tab_glimmer", {})) == TYPE_DICTIONARY else {}
	if bool(glimmer.get("visible", false)) and int(glimmer.get("deal_index", -1)) == index:
		var glimmer_offset := clampi(int(glimmer.get("offset", -1)), 0, maxi(0, remaining - 1))
		var glimmer_rect := _pull_tab_stack_glow_rect(stack_rect, remaining, glimmer_offset)
		var reduced_motion := bool(surface_state.get("reduce_motion", false))
		var glimmer_strength := 0.78 if reduced_motion else 0.55 + absf(sin(float(surface.surface_flicker()) * 4.7 + float(index))) * 0.30
		surface.draw_rect(glimmer_rect.grow(3.0), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.18 * glimmer_strength))
		surface.draw_rect(glimmer_rect, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.82 * glimmer_strength), false, 2)
	var xray_target := deal.get("xray_target", {}) as Dictionary if typeof(deal.get("xray_target", {})) == TYPE_DICTIONARY else {}
	if not xray_target.is_empty():
		var offset := clampi(int(xray_target.get("offset", 0)), 0, maxi(0, remaining - 1))
		var glow := 0.55 + absf(sin(float(surface.surface_flicker()) * 4.7 + float(index))) * 0.30
		var glow_rect := _pull_tab_stack_glow_rect(stack_rect, remaining, offset)
		surface.draw_rect(glow_rect.grow(3.0), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.15 * glow))
		surface.draw_rect(glow_rect, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.72 * glow), false, 2)
		surface.surface_label("$%d" % int(xray_target.get("payout", 0)), glow_rect.position + Vector2(4, 8), 7, C_YELLOW)
	if bool(surface.surface_animation_active(PULL_TAB_DISPENSE_CHANNEL)) and bool(_dispense_column_active(surface_state, index)):
		surface.draw_rect(rect.grow(2), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.22), false, 2)
	var tension_state := str(deal.get("tension_state", "stocked"))
	if tension_state == "last_tickets":
		var label_rect := Rect2(rect.position + Vector2(-3, 2), Vector2(rect.size.x + 6, 11))
		surface.draw_rect(label_rect, Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.76))
		surface.surface_label_centered("LAST", label_rect.grow(-1.0), 6, C_WHITE)
	elif tension_state == "thin":
		var thin_rect := Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4, 8))
		surface.draw_rect(thin_rect, Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.42))


static func _pull_tab_stack_glow_rect(stack_rect: Rect2, remaining: int, offset: int) -> Rect2:
	var depth_ratio := clampf((float(offset) + 0.5) / float(maxi(1, remaining)), 0.0, 1.0)
	var target_y := stack_rect.end.y - stack_rect.size.y * depth_ratio
	return Rect2(Vector2(stack_rect.position.x + 1, target_y - 5.0), Vector2(stack_rect.size.x - 2.0, 10.0))


static func _draw_pull_tab_control_panel(surface, rect: Rect2, deals: Array, surface_state: Dictionary) -> void:
	surface.draw_rect(rect, Color("#ece9dd"))
	surface.draw_rect(rect, Color("#2b3038"), false, 2)
	surface.draw_circle(rect.position + Vector2(rect.size.x * 0.5, 14), 5, Color("#1b2028"))
	surface.draw_rect(Rect2(rect.position + Vector2(12, 28), Vector2(rect.size.x - 24, 12)), Color("#33c85a"))
	var tutorial_target := {}
	for deal_value in deals:
		if typeof(deal_value) != TYPE_DICTIONARY:
			continue
		var deal_target: Dictionary = (deal_value as Dictionary).get("xray_target", {}) if typeof((deal_value as Dictionary).get("xray_target", {})) == TYPE_DICTIONARY else {}
		if not deal_target.is_empty():
			tutorial_target = deal_target
			break
	if tutorial_target.is_empty():
		surface.surface_label("PLAY", rect.position + Vector2(19, 64), 12, C_PINK)
		surface.surface_label("THE", rect.position + Vector2(25, 82), 13, C_PINK)
		surface.surface_label("MASTER", rect.position + Vector2(8, 104), 17, C_PINK)
	else:
		surface.surface_label_centered("XRAY TARGET", Rect2(rect.position + Vector2(4, 48), Vector2(rect.size.x - 8, 14)), 7, C_PINK)
		surface.surface_label_centered("%d TICKETS" % int(tutorial_target.get("tickets_until", 0)), Rect2(rect.position + Vector2(4, 68), Vector2(rect.size.x - 8, 16)), 8, C_YELLOW)
		surface.surface_label_centered("TOTAL $%d" % int(tutorial_target.get("total_cost", 0)), Rect2(rect.position + Vector2(4, 91), Vector2(rect.size.x - 8, 16)), 8, C_YELLOW)
	var scan_rect := Rect2(rect.position + Vector2(10, 124), Vector2(rect.size.x - 20, 30))
	var item_state: Dictionary = surface_state.get("pull_tab_item_state", {})
	var detector_available := bool(item_state.get("tab_detector_available", false))
	var active := bool(item_state.get("tab_detector_active", false))
	var armed := bool(surface.surface_native_action_selected("pull_tab_detector_scan"))
	var hovered := bool(surface.surface_region_hovered("pull_tab_detector_scan", 0))
	var scan_color := C_TEAL if active else C_YELLOW if armed else C_PINK
	surface.draw_rect(scan_rect, Color(scan_color.r, scan_color.g, scan_color.b, 0.28 if active or armed or hovered else 0.12))
	surface.draw_rect(scan_rect, C_WHITE if hovered else scan_color, false, 2 if hovered or active or armed else 1)
	var scan_label := "SCAN" if detector_available else "CONFIRM" if armed else "PEEK"
	surface.surface_label_centered(scan_label, Rect2(scan_rect.position + Vector2(2, 7), Vector2(scan_rect.size.x - 4, 16)), 9, scan_color)
	surface.surface_add_hit(scan_rect, "pull_tab_detector_scan", 0)


static func _draw_pull_tab_column_button(surface, deal: Dictionary, index: int, rect: Rect2) -> void:
	var enabled := bool(deal.get("enabled", false))
	var palette: Dictionary = deal.get("palette", {})
	var accent := Color(str(palette.get("accent", "#ff4fb3")))
	var hovered := bool(surface.surface_region_hovered("pull_tab_buy", index))
	var price := maxi(1, int(deal.get("price", 1)))
	var base := Color("#e8e3d2") if enabled else Color("#454850")
	if hovered and enabled:
		base = Color("#fff5c8")
	surface.draw_rect(rect, Color(0, 0, 0, 0.36))
	surface.draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), base)
	surface.draw_rect(rect, accent if enabled else Color("#2f3136"), false, 2 if hovered else 1)
	surface.draw_rect(Rect2(rect.position + Vector2(4, rect.size.y - 12), Vector2(rect.size.x - 8, 8)), Color(0.0, 0.0, 0.0, 0.12 if enabled else 0.20))
	if bool(deal.get("tab_detector_highlight", false)):
		var pulse := 0.62 + absf(sin(Time.get_ticks_msec() / 160.0 + float(index))) * 0.36
		surface.draw_rect(rect.grow(4.0), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.16 * pulse))
		surface.draw_rect(rect.grow(3.0), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.88 * pulse), false, 2)
	var text_color := Color("#171217") if enabled else C_SOFT
	surface.surface_label_centered("%d" % (index + 1), Rect2(rect.position + Vector2(3, 2), Vector2(rect.size.x - 6, 10)), 8, text_color)
	surface.surface_label_centered("$%d" % price, Rect2(rect.position + Vector2(3, rect.size.y - 13), Vector2(rect.size.x - 6, 10)), 8, text_color)
	var tension_state := str(deal.get("tension_state", "stocked"))
	if tension_state == "last_tickets":
		surface.surface_label_centered("LOW", Rect2(rect.position + Vector2(3, 11), Vector2(rect.size.x - 6, 8)), 6, C_PINK)
	elif tension_state == "sold_out":
		surface.surface_label_centered("OUT", Rect2(rect.position + Vector2(3, 11), Vector2(rect.size.x - 6, 8)), 6, C_SOFT)
	if enabled:
		surface.surface_add_exact_invisible_hit(rect.grow(5), "pull_tab_buy", index)


static func _draw_pull_tab_master_button(surface, deals: Array, rect: Rect2) -> void:
	var enabled := false
	for deal in deals:
		if typeof(deal) == TYPE_DICTIONARY and bool((deal as Dictionary).get("enabled", false)):
			enabled = true
			break
	var hovered := bool(surface.surface_region_hovered("pull_tab_buy_all", 0))
	var base := Color("#f4f0dc") if enabled else Color("#454850")
	if hovered and enabled:
		base = Color("#fff4b8")
	surface.draw_rect(rect, Color(0, 0, 0, 0.38))
	surface.draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), base)
	surface.draw_rect(rect, C_YELLOW if enabled else Color("#2f3136"), false, 2 if hovered else 1)
	surface.surface_label("ALL 4", rect.position + Vector2(10, 18), 10, Color("#171217") if enabled else C_SOFT)
	if enabled:
		surface.surface_add_invisible_hit(rect.grow(5), "pull_tab_buy_all", 0)


static func _draw_pull_tab_machine_tray(surface, rect: Rect2, tray_stack: Array, surface_state: Dictionary) -> void:
	surface.draw_rect(rect, Color("#050608"))
	surface.draw_rect(Rect2(rect.position + Vector2(10, 14), Vector2(rect.size.x - 20, 40)), Color("#07080c"))
	surface.draw_rect(Rect2(rect.position + Vector2(14, 18), Vector2(rect.size.x - 28, 30)), Color("#111822"))
	surface.draw_rect(rect, Color("#393e48"), false, 2)
	var hidden_ids := _active_dispense_hidden_ticket_ids(surface, surface_state)
	var column_counts := JsonCoerceScript._int_array(surface_state.get("pull_tab_tray_column_counts", []))
	var column_tickets: Array = []
	var hidden_counts: Array = []
	for _column in range(PULL_TAB_MACHINE_COLUMN_COUNT):
		column_tickets.append([])
		hidden_counts.append(0)
	for ticket_value in tray_stack:
		if typeof(ticket_value) != TYPE_DICTIONARY:
			continue
		var ticket: Dictionary = ticket_value
		var deal_index := clampi(int(ticket.get("deal_index", 0)), 0, PULL_TAB_MACHINE_COLUMN_COUNT - 1)
		if hidden_ids.has(str(ticket.get("id", ""))):
			hidden_counts[deal_index] = int(hidden_counts[deal_index]) + 1
			continue
		(column_tickets[deal_index] as Array).append(ticket)
	var visible_total := 0
	for deal_index in range(PULL_TAB_MACHINE_COLUMN_COUNT):
		var pile_rect := _pull_tab_tray_column_pile_rect(rect, deal_index)
		var tickets: Array = column_tickets[deal_index]
		visible_total += tickets.size()
		var total_count := _tray_column_total(column_counts, deal_index, tickets.size()) - int(hidden_counts[deal_index])
		_draw_pull_tab_tray_column_pile(surface, pile_rect, tickets, maxi(total_count, tickets.size()), deal_index)
	if int(surface_state.get("pull_tab_tray_count", tray_stack.size())) <= 0 and visible_total <= 0:
		surface.surface_label("TRAY", rect.position + Vector2(122, 41), 13, C_AMBER)
	else:
		surface.surface_label("COLLECT TRAY", rect.position + Vector2(98, 70), 10, C_YELLOW)
		surface.surface_add_invisible_hit(rect, PULL_TAB_COLLECT_TRAY_ACTION, 0)


static func _pull_tab_tray_column_pile_rect(rect: Rect2, deal_index: int) -> Rect2:
	var column_width := 50.0
	var gap := 6.0
	var start_x := rect.position.x + 8.0
	return Rect2(Vector2(start_x + float(deal_index) * (column_width + gap), rect.position.y + 18.0), Vector2(column_width, 38.0))


static func _tray_column_total(column_counts: Array, deal_index: int, fallback: int) -> int:
	if deal_index >= 0 and deal_index < column_counts.size():
		return maxi(0, int(column_counts[deal_index]))
	return fallback


static func _draw_pull_tab_tray_column_pile(surface, rect: Rect2, tickets: Array, total_count: int, deal_index: int) -> void:
	var accent := Color("#46515d")
	if not tickets.is_empty() and typeof(tickets[tickets.size() - 1]) == TYPE_DICTIONARY:
		var palette: Dictionary = (tickets[tickets.size() - 1] as Dictionary).get("palette", {})
		accent = Color(str(palette.get("accent", "#ff4fb3")))
	surface.draw_rect(rect, Color("#07090d"))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.18), false, 1)
	if total_count <= 0:
		surface.surface_label(str(deal_index + 1), rect.position + Vector2(22, 28), 10, Color("#3c4651"))
		return
	var buried_count := maxi(0, total_count - tickets.size())
	var ticket_size := Vector2(rect.size.x - 8.0, 18.0)
	var bottom_y := rect.position.y + rect.size.y - ticket_size.y - 3.0
	var buried_lift := minf(10.0, float(buried_count) * 1.5)
	if buried_count > 0:
		for shadow_index in range(mini(buried_count, 5)):
			var shadow_rect := Rect2(
				Vector2(rect.position.x + 4.0, bottom_y - float(shadow_index) * 2.0),
				ticket_size
			)
			surface.draw_rect(shadow_rect, Color(1.0, 0.94, 0.80, 0.08))
			surface.draw_rect(shadow_rect, Color(accent.r, accent.g, accent.b, 0.12), false, 1)
	for index in range(tickets.size()):
		if typeof(tickets[index]) != TYPE_DICTIONARY:
			continue
		var ticket: Dictionary = tickets[index]
		var pos := Vector2(rect.position.x + 4.0 + float(index % 2), bottom_y - buried_lift - float(index) * 4.0)
		_draw_pull_tab_tray_ticket(surface, ticket, Rect2(pos, ticket_size), index)


static func _draw_pull_tab_tray_ticket(surface, ticket: Dictionary, rect: Rect2, index: int) -> void:
	var palette: Dictionary = ticket.get("palette", {})
	var paper := Color(str(palette.get("paper", "#fff0d8")))
	var accent := Color(str(palette.get("accent", "#ff4fb3")))
	var y_offset := float(index % 2) * 3.0
	var live_rect := Rect2(rect.position + Vector2(0, y_offset), rect.size)
	surface.draw_rect(live_rect, paper)
	surface.draw_rect(live_rect, accent, false, 1)
	surface.draw_rect(Rect2(live_rect.position + Vector2(6, 7), Vector2(live_rect.size.x - 12, 5)), Color(accent.r, accent.g, accent.b, 0.34))
	surface.surface_label(str(ticket.get("ticket_number", "")).left(5), live_rect.position + Vector2(8, 19), 7, Color("#21131d"))


static func _draw_pull_tab_stack_panel(surface, rect: Rect2, surface_state: Dictionary, stack: Array, winner_pile: Array, loser_pile: Array) -> void:
	surface.draw_rect(rect, Color("#071015"))
	surface.draw_rect(rect, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.22), false, 2)
	var count := int(surface_state.get("pull_tab_stack_count", stack.size()))
	var cursor := int(surface_state.get("pull_tab_stack_cursor", 0))
	var pending_payout := int(surface_state.get("pull_tab_pending_payout", 0))
	var winner_total := maxi(0, int(surface_state.get("pull_tab_winner_count", winner_pile.size())))
	var loser_total := maxi(0, int(surface_state.get("pull_tab_loser_count", loser_pile.size())))
	var active_rect := Rect2(rect.position + Vector2(42, 46), Vector2(310, 172))
	var pile_rect := Rect2(rect.position + Vector2(20, 236), Vector2(rect.size.x - 40, 138))
	var filing_ticket_id := ""
	var filing_pile := ""
	if bool(surface.surface_animation_active(PULL_TAB_FILE_CHANNEL)):
		var filing_ticket_value: Variant = surface_state.get("pull_tab_file_animation_ticket", {})
		var filing_ticket: Dictionary = filing_ticket_value if typeof(filing_ticket_value) == TYPE_DICTIONARY else {}
		filing_ticket_id = str(filing_ticket.get("id", ""))
		filing_pile = str(surface_state.get("pull_tab_file_animation_pile", ""))
		if filing_pile.is_empty() and not filing_ticket_id.is_empty():
			filing_pile = "winner_pile" if int(filing_ticket.get("payout", 0)) > 0 else "loser_pile"
	var winner_excluded_id := filing_ticket_id if filing_pile == "winner_pile" else ""
	var loser_excluded_id := filing_ticket_id if filing_pile == "loser_pile" else ""
	surface.surface_label("TICKET PILE", rect.position + Vector2(14, 22), 18, C_CYAN)
	var visible_ticket_number := 0 if count <= 0 else mini(cursor + 1, count)
	surface.surface_label("%d/%d" % [visible_ticket_number, count], rect.position + Vector2(118, 22), 14, C_SOFT)
	if pending_payout > 0:
		var payout_label := str(surface_state.get("pull_tab_pending_payout_label", "CASH $%d" % pending_payout))
		surface.surface_label(payout_label, rect.position + Vector2(312, 42), 9, C_YELLOW)
	var display_start_index := 0
	if bool(surface.surface_animation_active(PULL_TAB_DISPENSE_CHANNEL)) and not stack.is_empty():
		var arriving: Dictionary = stack[0] as Dictionary
		if str(arriving.get("id", "")) == str(surface.surface_animation_active_id(PULL_TAB_DISPENSE_CHANNEL)):
			display_start_index = 1
	var display_count := maxi(0, stack.size() - display_start_index)
	var active_ticket: Dictionary = stack[display_start_index] as Dictionary if display_count > 0 else {}
	# Keep the navigation strip in the safe span between the variable-width X/X
	# pile counter and the shared native Leave control drawn over this header.
	var header_button_rects := _pull_tab_stack_header_button_rects(rect)
	_draw_pull_tab_nav_button(surface, header_button_rects[0], "<", "pull_tab_prev", count > 1 and cursor > 0)
	_draw_pull_tab_nav_button(surface, header_button_rects[1], ">", "pull_tab_next", count > 1 and cursor < count - 1)
	_draw_pull_tab_nav_button(surface, header_button_rects[2], "OPEN", "pull_tab_next_unopened", count > 0)
	var auto_open_active := bool(surface_state.get("pull_tab_auto_open_active", false))
	_draw_pull_tab_nav_button(surface, header_button_rects[3], "STOP" if auto_open_active else "AUTO OPEN", PULL_TAB_AUTO_OPEN_ACTION, count > 0, auto_open_active)
	if display_count <= 0:
		_draw_pull_tab_empty_pile(surface, Rect2(rect.position + Vector2(38, 56), Vector2(316, 148)), int(surface_state.get("pull_tab_tray_count", 0)))
		_draw_pull_tab_sorted_piles(surface, pile_rect, winner_pile, loser_pile, winner_excluded_id, loser_excluded_id, winner_total, loser_total)
		_draw_pull_tab_file_animation(surface, surface_state, active_rect, pile_rect)
		return
	for view_index in range(mini(display_count - 1, 5), 0, -1):
		var ticket: Dictionary = stack[display_start_index + view_index] as Dictionary
		_draw_pull_tab_mini_ticket(surface, ticket, Rect2(rect.position + Vector2(68 + view_index * 10, 56 + view_index * 5), Vector2(238, 138)), 0.18 + float(view_index) * 0.02)
	var active: Dictionary = active_ticket
	_draw_pull_tab_ticket(surface, active, active_rect, true)
	_draw_pull_tab_sorted_piles(surface, pile_rect, winner_pile, loser_pile, winner_excluded_id, loser_excluded_id, winner_total, loser_total)
	_draw_pull_tab_file_animation(surface, surface_state, active_rect, pile_rect)


static func _pull_tab_stack_header_button_rects(panel_rect: Rect2) -> Array[Rect2]:
	var total_width := PULL_TAB_STACK_HEADER_BUTTON_GAP * float(PULL_TAB_STACK_HEADER_BUTTON_WIDTHS.size() - 1)
	for width_value in PULL_TAB_STACK_HEADER_BUTTON_WIDTHS:
		total_width += float(width_value)
	var safe_right_x := minf(
		panel_rect.end.x - PULL_TAB_STACK_HEADER_RIGHT_MARGIN,
		PULL_TAB_STACK_HEADER_LEAVE_LEFT_X - PULL_TAB_STACK_HEADER_LEAVE_GAP
	)
	var next_x := safe_right_x - total_width
	var rects: Array[Rect2] = []
	for width_value in PULL_TAB_STACK_HEADER_BUTTON_WIDTHS:
		var width := float(width_value)
		rects.append(Rect2(Vector2(next_x, panel_rect.position.y + 8.0), Vector2(width, 24.0)))
		next_x += width + PULL_TAB_STACK_HEADER_BUTTON_GAP
	return rects


static func _draw_pull_tab_nav_button(surface, rect: Rect2, label: String, action: String, enabled: bool, active: bool = false) -> void:
	var base_color := Color("#26351f") if active else Color("#13222a") if enabled else Color("#101317")
	var border_color := C_YELLOW if active else C_CYAN
	surface.draw_rect(rect, base_color)
	surface.draw_rect(rect, Color(border_color.r, border_color.g, border_color.b, 0.74 if active else 0.48 if enabled else 0.14), false, 2)
	var font_size := 8 if label.length() > 6 else 10
	surface.surface_label_centered(label, rect.grow(-2.0), font_size, C_YELLOW if active else C_WHITE if enabled else C_SOFT)
	if enabled:
		surface.surface_add_invisible_hit(rect, action)


static func _draw_pull_tab_empty_pile(surface, rect: Rect2, tray_count: int = 0) -> void:
	surface.draw_rect(rect, Color("#0a0c12"))
	surface.draw_rect(rect, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.18), false, 2)
	for index in range(4):
		var ghost := Rect2(rect.position + Vector2(34 + index * 30, 64 - index * 5), Vector2(126, 58))
		surface.draw_rect(ghost, Color(1.0, 0.94, 0.80, 0.08))
		surface.draw_rect(ghost, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.16), false, 1)
	if tray_count > 0:
		surface.surface_label("COLLECT TRAY", rect.position + Vector2(84, 84), 18, C_YELLOW)
	else:
		surface.surface_label("BUY A ROW", rect.position + Vector2(104, 84), 18, C_SOFT)


static func _draw_pull_tab_mini_ticket(surface, ticket: Dictionary, rect: Rect2, alpha: float) -> void:
	var palette: Dictionary = ticket.get("palette", {})
	var paper := Color(str(palette.get("paper", "#fff0d8")))
	var accent := Color(str(palette.get("accent", "#ff4fb3")))
	surface.draw_rect(rect, Color(paper.r, paper.g, paper.b, alpha))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, alpha + 0.12), false, 2)
	surface.draw_rect(Rect2(rect.position + Vector2(8, 10), Vector2(rect.size.x - 16, 20)), Color(accent.r, accent.g, accent.b, alpha))
	for row_index in range(3):
		surface.draw_rect(Rect2(rect.position + Vector2(18, 46 + row_index * 25), Vector2(rect.size.x - 36, 17)), Color(1.0, 1.0, 1.0, alpha))


static func _draw_pull_tab_dispense_animation(surface, surface_state: Dictionary, cabinet: Rect2) -> void:
	var elapsed_msec := int(surface.surface_elapsed(PULL_TAB_DISPENSE_CHANNEL) * 1000.0)
	var tray_stack := _dictionary_view_array(surface_state.get("pull_tab_tray_stack", []))
	var events := _dictionary_view_array(surface_state.get("pull_tab_dispense_events", []))
	for event_value in events:
		var event: Dictionary = event_value
		var local_msec := elapsed_msec - int(event.get("start_msec", 0))
		if local_msec < 0 or local_msec > PULL_TAB_DISPENSE_EVENT_DURATION_MSEC:
			continue
		var ticket: Dictionary = {}
		var ticket_value: Variant = event.get("ticket", {})
		if typeof(ticket_value) == TYPE_DICTIONARY:
			ticket = ticket_value as Dictionary
		if ticket.is_empty():
			ticket = _pull_tab_find_ticket(tray_stack, str(event.get("ticket_id", "")))
		if ticket.is_empty():
			continue
		var deal_index := clampi(int(event.get("deal_index", 0)), 0, PULL_TAB_MACHINE_COLUMN_COUNT - 1)
		var start := _pull_tab_column_drop_start(cabinet, deal_index)
		var chute := _pull_tab_column_drop_chute(cabinet, deal_index)
		var tray := _pull_tab_column_tray_target(cabinet, deal_index)
		var drop_start := int(event.get("drop_start_msec", PULL_TAB_DISPENSE_DROP_START_MSEC))
		var drop_duration := maxi(1, int(event.get("drop_duration_msec", PULL_TAB_DISPENSE_DROP_DURATION_MSEC)))
		var pos := start
		var alpha := 0.0
		var scale := 0.42
		if local_msec < drop_start:
			var latch_t := clampf(float(local_msec) / float(drop_start), 0.0, 1.0)
			pos = start.lerp(chute, _ease_in_out_cubic(latch_t))
			alpha = 0.22 + latch_t * 0.42
		else:
			var drop_t := clampf(float(local_msec - drop_start) / float(drop_duration), 0.0, 1.0)
			pos = chute.lerp(tray, _ease_out_cubic(drop_t))
			alpha = 0.94
			scale = lerpf(0.46, 0.60, drop_t)
		var ticket_rect := Rect2(pos, Vector2(94, 34) * scale)
		_draw_pull_tab_tray_ticket(surface, ticket, ticket_rect, deal_index)
		var pulse := maxf(0.0, 1.0 - float(local_msec) / float(PULL_TAB_DISPENSE_EVENT_DURATION_MSEC))
		surface.draw_rect(ticket_rect.grow(3), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, alpha * 0.18 * pulse), false, 3)


static func _pull_tab_column_drop_start(cabinet: Rect2, deal_index: int) -> Vector2:
	return cabinet.position + Vector2(50 + deal_index * 52, 222)


static func _pull_tab_column_drop_chute(cabinet: Rect2, deal_index: int) -> Vector2:
	return cabinet.position + Vector2(44 + deal_index * 52, 286)


static func _pull_tab_column_tray_target(cabinet: Rect2, deal_index: int) -> Vector2:
	return cabinet.position + Vector2(36 + deal_index * 56, 326)


static func _dispense_column_active(surface_state: Dictionary, deal_index: int) -> bool:
	var events := _dictionary_view_array(surface_state.get("pull_tab_dispense_events", []))
	if events.is_empty():
		return false
	for event in events:
		if int((event as Dictionary).get("deal_index", -1)) == deal_index:
			return true
	return false


static func _active_dispense_hidden_ticket_ids(surface, surface_state: Dictionary) -> Dictionary:
	var hidden := {}
	if not bool(surface.surface_animation_active(PULL_TAB_DISPENSE_CHANNEL)):
		return hidden
	var elapsed_msec := int(surface.surface_elapsed(PULL_TAB_DISPENSE_CHANNEL) * 1000.0)
	for event_value in _dictionary_view_array(surface_state.get("pull_tab_dispense_events", [])):
		var event: Dictionary = event_value
		var local_msec := elapsed_msec - int(event.get("start_msec", 0))
		var reveal_msec := int(event.get("drop_start_msec", PULL_TAB_DISPENSE_DROP_START_MSEC)) + int(event.get("drop_duration_msec", PULL_TAB_DISPENSE_DROP_DURATION_MSEC))
		if local_msec < reveal_msec:
			hidden[str(event.get("ticket_id", ""))] = true
	return hidden


static func _draw_pull_tab_ticket(surface, ticket: Dictionary, rect: Rect2, interactive: bool = true) -> void:
	var palette: Dictionary = ticket.get("palette", {})
	var paper := Color(str(palette.get("paper", "#fff0d8")))
	var ink := Color(str(palette.get("ink", "#241027")))
	var accent := Color(str(palette.get("accent", "#ff4fb3")))
	var trim := Color(str(palette.get("trim", "#ffd35a")))
	surface.draw_rect(rect, Color("#000000"))
	surface.draw_rect(Rect2(rect.position + Vector2(3, 3), rect.size), Color(0.0, 0.0, 0.0, 0.18))
	surface.draw_rect(rect, paper)
	surface.draw_rect(rect, accent, false, 3)
	var header := Rect2(rect.position + Vector2(8, 8), Vector2(rect.size.x - 16, 30))
	surface.draw_rect(header, trim)
	surface.draw_rect(header, accent, false, 2)
	surface.surface_label(str(ticket.get("display_name", "Pull Tab")).left(17).to_upper(), header.position + Vector2(8, 22), 15, ink)
	surface.surface_label(str(ticket.get("ticket_number", "")).left(7), header.position + Vector2(header.size.x - 58, 22), 10, ink)
	surface.surface_label("FORM %s  SERIAL %s  $%d" % [str(ticket.get("form", "")), str(ticket.get("serial", "")), int(ticket.get("price", 1))], rect.position + Vector2(12, 52), 9, ink)
	var prize_strip_width := 84.0
	_draw_pull_tab_ticket_prize_strip(surface, ticket, Rect2(rect.position + Vector2(rect.size.x - prize_strip_width - 12.0, 61), Vector2(prize_strip_width, 92)))
	var rows := _array_view(ticket.get("rows", []))
	var revealed_count := clampi(int(ticket.get("revealed_count", 0)), 0, rows.size())
	var reveal_animation_id := str(ticket.get("reveal_animation_id", ""))
	var reveal_animating: bool = interactive and not reveal_animation_id.is_empty() and surface.surface_animation_active_id(PULL_TAB_REVEAL_CHANNEL) == reveal_animation_id and surface.surface_animation_active(PULL_TAB_REVEAL_CHANNEL)
	var reveal_elapsed_msec: int = int(surface.surface_elapsed(PULL_TAB_REVEAL_CHANNEL) * 1000.0) if reveal_animating else PULL_TAB_REVEAL_TOTAL_MSEC
	var reveal_rows_complete: bool = not reveal_animating or reveal_elapsed_msec >= (2 * PULL_TAB_REVEAL_STAGGER_MSEC + PULL_TAB_REVEAL_ROW_DURATION_MSEC)
	var row_area_width: float = rect.size.x - prize_strip_width - 34.0
	for row_index in range(3):
		var row_rect := Rect2(rect.position + Vector2(12, 66 + row_index * 31), Vector2(row_area_width, 27))
		var row_progress: float = 1.0
		var row_revealed: bool = row_index < revealed_count
		if reveal_animating:
			var row_start := row_index * PULL_TAB_REVEAL_STAGGER_MSEC
			row_progress = clampf(float(reveal_elapsed_msec - row_start) / float(PULL_TAB_REVEAL_ROW_DURATION_MSEC), 0.0, 1.0)
			row_revealed = row_progress > 0.0
		_draw_pull_tab_row(surface, ticket, row_index, row_rect, row_revealed, row_index == revealed_count, interactive and not bool(ticket.get("fully_revealed", false)), row_progress)
	if bool(ticket.get("fully_revealed", false)) and reveal_rows_complete:
		var payout := int(ticket.get("payout", 0))
		var price := maxi(1, int(ticket.get("price", 1)))
		var banner := Rect2(rect.position + Vector2(12, rect.size.y - 26), Vector2(rect.size.x - 24, 19))
		var banner_color := C_YELLOW if payout > 0 else C_SOFT
		surface.draw_rect(banner, Color(banner_color.r, banner_color.g, banner_color.b, 0.18))
		surface.draw_rect(banner, Color(banner_color.r, banner_color.g, banner_color.b, 0.72), false, 1)
		var text := "PRIZE $%d  COST $%d" % [payout, price] if payout > 0 else "NO PRIZE  COST $%d" % price
		surface.surface_label(text.left(29), banner.position + Vector2(9, 14), 12, banner_color)
		if interactive:
			var hovered := bool(surface.surface_region_hovered(PULL_TAB_FILE_TICKET_ACTION))
			surface.draw_rect(rect.grow(3), Color(banner_color.r, banner_color.g, banner_color.b, 0.16 if hovered else 0.08), false, 3 if hovered else 2)
			surface.surface_draw_ready_badge(rect, "CLICK TO FILE")
			surface.surface_add_exact_invisible_hit(rect, PULL_TAB_FILE_TICKET_ACTION)
	elif interactive and not bool(ticket.get("fully_revealed", false)):
		var hovered_peel := bool(surface.surface_region_hovered("pull_tab_reveal_next"))
		surface.draw_rect(rect.grow(3), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.16 if hovered_peel else 0.08), false, 3 if hovered_peel else 2)
		surface.surface_draw_ready_badge(rect, "PEEL")
		surface.surface_add_exact_invisible_hit(rect, "pull_tab_reveal_next")


static func _draw_pull_tab_ticket_prize_strip(surface, ticket: Dictionary, rect: Rect2) -> void:
	if bool(ticket.get("tarot_converted", false)):
		_draw_pull_tab_tarot_reading_strip(surface, ticket, rect)
		return
	surface.draw_rect(rect, Color("#f7fbff"))
	surface.draw_rect(rect, C_DARK, false, 1)
	surface.surface_label("LEGEND", rect.position + Vector2(6, 9), 7, C_DARK)
	var prize_rows := _dictionary_view_array(ticket.get("prize_rows", []))
	if prize_rows.is_empty():
		surface.surface_label("NO KEY", rect.position + Vector2(9, 47), 8, C_DARK)
		return
	for index in range(mini(6, prize_rows.size())):
		var row: Dictionary = prize_rows[index]
		var row_rect := Rect2(rect.position + Vector2(4, 15 + index * 12), Vector2(rect.size.x - 8, 11))
		_draw_pull_tab_prize_key_row(surface, row, row_rect, false, index + 1)


static func _draw_pull_tab_tarot_reading_strip(surface, ticket: Dictionary, rect: Rect2) -> void:
	surface.draw_rect(rect, Color("#130719"))
	surface.draw_rect(rect, C_YELLOW, false, 1)
	surface.surface_label("NEXT 5", rect.position + Vector2(7, 9), 7, C_YELLOW)
	var reading := _dictionary_view_array(ticket.get("tarot_reading", []))
	if reading.is_empty():
		surface.surface_label("NO READING", rect.position + Vector2(5, 47), 7, C_WHITE)
		return
	for index in range(mini(5, reading.size())):
		var row: Dictionary = reading[index]
		var row_rect := Rect2(rect.position + Vector2(4, 15 + index * 14), Vector2(rect.size.x - 8, 12))
		_draw_pull_tab_prize_key_row(surface, row, row_rect, true, index + 1)
	var burned := int(ticket.get("burned_payout", 0))
	if burned > 0:
		surface.surface_label("BURN $%d" % burned, rect.position + Vector2(6, rect.size.y - 6), 6, C_PINK)


static func _draw_pull_tab_prize_key_row(surface, row: Dictionary, rect: Rect2, tarot: bool, row_number: int) -> void:
	var payout := maxi(0, int(row.get("payout", 0)))
	var is_win := payout > 0
	var fill := Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.18) if is_win else Color(1.0, 1.0, 1.0, 0.08)
	if not tarot:
		fill = Color("#fff7e4") if is_win else Color("#eef2f7")
	surface.draw_rect(rect, fill)
	surface.draw_rect(rect, Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.52) if is_win else Color(C_DARK.r, C_DARK.g, C_DARK.b, 0.26), false, 1)
	var text_color := C_YELLOW if is_win else (C_WHITE if tarot else C_DARK)
	if tarot:
		surface.surface_label("%d" % row_number, rect.position + Vector2(1, rect.size.y - 3), 6, text_color)
	var symbols := JsonCoerceScript._string_array(row.get("symbols", []))
	var symbol_x := rect.position.x + (8.0 if tarot else 2.0)
	for symbol_index in range(3):
		var symbol := str(symbols[symbol_index] if symbol_index < symbols.size() else "MISS")
		var badge := Rect2(Vector2(symbol_x + float(symbol_index) * 9.5, rect.position.y + 2.0), Vector2(8.5, rect.size.y - 4.0))
		_draw_pull_tab_symbol_badge(surface, symbol, badge, is_win, tarot)
	surface.surface_label("$%d" % payout, rect.position + Vector2(rect.size.x - 25.0, rect.size.y - 3.0), 7, text_color)


static func _draw_pull_tab_symbol_badge(surface, symbol: String, rect: Rect2, highlighted: bool, tarot: bool) -> void:
	var color := _pull_tab_symbol_badge_color(symbol)
	var alpha := 0.98 if highlighted else (0.82 if tarot else 0.72)
	surface.draw_rect(rect, Color(color.r, color.g, color.b, alpha))
	surface.draw_rect(rect, Color("#211722"), false, 1)
	var label_color := C_DARK if symbol in ["LEMON", "BELL", "CROWN", "7"] else C_WHITE
	surface.surface_label_centered(_pull_tab_symbol_abbrev(symbol), rect.grow(-0.5), 5, label_color)


static func _pull_tab_symbol_abbrev(symbol: String) -> String:
	match symbol:
		"CHERRY":
			return "CH"
		"LEMON":
			return "LE"
		"BELL":
			return "BE"
		"BAR":
			return "BA"
		"7":
			return "7"
		"CROWN":
			return "CR"
		"MISS":
			return "--"
		_:
			return symbol.left(2).to_upper()


static func _pull_tab_symbol_badge_color(symbol: String) -> Color:
	match symbol:
		"CHERRY":
			return C_PINK
		"LEMON":
			return C_YELLOW
		"BELL":
			return Color("#f6b14f")
		"BAR":
			return C_DARK
		"7":
			return Color("#f8e86a")
		"CROWN":
			return C_YELLOW
		_:
			return Color("#6f7787")


static func _draw_pull_tab_row(surface, ticket: Dictionary, row_index: int, row_rect: Rect2, revealed: bool, next_to_open: bool, interactive: bool = true, reveal_progress: float = 1.0) -> void:
	surface.draw_rect(row_rect, Color("#f8f1de"))
	surface.draw_rect(row_rect, C_DARK, false, 1)
	var rows := _array_view(ticket.get("rows", []))
	var symbols := JsonCoerceScript._string_array(rows[row_index] if row_index < rows.size() else [])
	var flap := Rect2(row_rect.position + Vector2(0, 1), Vector2(45, row_rect.size.y - 2))
	var window_start := row_rect.position + Vector2(52, 4)
	var progress := clampf(reveal_progress, 0.0, 1.0)
	if revealed:
		var fold := lerpf(39.0, 11.0, progress)
		var lift := sin(progress * PI) * 5.0
		surface.draw_polygon([
			flap.position + Vector2(1, 1),
			flap.position + Vector2(fold, -5 - lift),
			flap.position + Vector2(fold + 4, flap.size.y + 2 + lift * 0.35),
			flap.position + Vector2(5, flap.size.y - 2),
		], [Color("#e7d4bc")])
		surface.draw_line(flap.position + Vector2(fold + 5, 2), flap.position + Vector2(fold + 5, flap.size.y - 2), Color("#8a7465"), 1)
		if progress < 1.0:
			surface.draw_rect(row_rect.grow(2), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.18 * (1.0 - progress)), false, 2)
	else:
		surface.draw_rect(flap, Color("#e6d0b4"))
		surface.draw_rect(flap, Color("#8a7465"), false, 1)
		for notch in range(3):
			surface.draw_line(flap.position + Vector2(5 + notch * 12, 4), flap.position + Vector2(5 + notch * 12, flap.size.y - 4), Color("#b7a48f"), 1)
		surface.surface_label("PULL", flap.position + Vector2(7, 18), 8, C_DARK)
	for symbol_index in range(3):
		var window_rect := Rect2(window_start + Vector2(symbol_index * 45, 0), Vector2(37, row_rect.size.y - 8))
		if revealed:
			surface.draw_rect(window_rect, C_DARK)
			_draw_pull_tab_symbol(surface, str(symbols[symbol_index] if symbol_index < symbols.size() else "?"), window_rect)
		else:
			surface.draw_rect(window_rect, Color("#fffaf0"))
			surface.draw_rect(window_rect, Color("#c8b495"), false, 1)
			surface.draw_line(window_rect.position + Vector2(4, 4), window_rect.end - Vector2(4, 4), Color("#d8c4a8"), 1)
			surface.draw_line(window_rect.position + Vector2(4, window_rect.size.y - 4), window_rect.position + Vector2(window_rect.size.x - 4, 4), Color("#d8c4a8"), 1)
	if next_to_open and interactive:
		surface.draw_rect(row_rect.grow(2), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.22), false, 2)
		surface.surface_add_exact_invisible_hit(row_rect, "pull_tab_reveal_next", row_index)


static func _draw_pull_tab_sorted_piles(surface, rect: Rect2, winner_pile: Array, loser_pile: Array, winner_excluded_id: String = "", loser_excluded_id: String = "", winner_total: int = -1, loser_total: int = -1) -> void:
	var gap := 8.0
	var pile_width := (rect.size.x - gap) * 0.5
	_draw_pull_tab_ordered_winner_pile(surface, Rect2(rect.position, Vector2(pile_width, rect.size.y)), winner_pile, winner_excluded_id, not winner_excluded_id.is_empty(), winner_total)
	_draw_pull_tab_messy_loser_pile(surface, Rect2(rect.position + Vector2(pile_width + gap, 0), Vector2(pile_width, rect.size.y)), loser_pile, loser_excluded_id, not loser_excluded_id.is_empty(), loser_total)


static func _draw_pull_tab_ordered_winner_pile(surface, rect: Rect2, ripped_tabs: Array, excluded_ticket_id: String = "", excluded_ticket_present: bool = false, total_count: int = -1) -> void:
	var accent := C_TEAL
	surface.draw_rect(rect, Color("#05080b"))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.22), false, 1)
	var filtered_count := _pile_filtered_count(ripped_tabs, excluded_ticket_id, excluded_ticket_present)
	if total_count >= 0:
		filtered_count = maxi(0, total_count - (1 if excluded_ticket_present else 0))
	surface.surface_label("WINNERS x%d" % filtered_count, rect.position + Vector2(7, 13), 9, accent)
	if filtered_count <= 0:
		_draw_pull_tab_empty_stack_ghost(surface, rect, accent)
		return
	var visible_count := mini(filtered_count, 7)
	var ticket_size := Vector2(rect.size.x - 34, 28)
	var bottom_y := rect.position.y + rect.size.y - ticket_size.y - 8.0
	var source_start_index := _pile_visible_source_start(ripped_tabs, visible_count, excluded_ticket_id)
	var draw_index := 0
	var buried_lift := 0.0
	var shadows_drawn := false
	for source_index in range(source_start_index, ripped_tabs.size()):
		var ticket_value: Variant = ripped_tabs[source_index]
		if _pile_ticket_excluded(ticket_value, excluded_ticket_id):
			continue
		var ticket: Dictionary = ticket_value as Dictionary
		if not shadows_drawn:
			var buried_count := maxi(0, _pile_depth_index(ticket, 0))
			buried_lift = minf(10.0, float(buried_count) * 1.2)
			if buried_count > 0:
				for shadow_index in range(mini(buried_count, 5)):
					var shadow_rect := Rect2(rect.position + Vector2(16 + shadow_index, rect.size.y - 36 - shadow_index * 2), ticket_size)
					surface.draw_rect(shadow_rect, Color(1.0, 0.94, 0.80, 0.06))
					surface.draw_rect(shadow_rect, Color(accent.r, accent.g, accent.b, 0.12), false, 1)
			shadows_drawn = true
		var offset := Vector2(16 + mini(draw_index, 4) * 2, bottom_y - rect.position.y - buried_lift - float(draw_index) * 8.0)
		var ticket_rect := Rect2(rect.position + offset, ticket_size)
		_draw_pull_tab_pile_ticket(surface, ticket, ticket_rect, draw_index, true)
		draw_index += 1


static func _draw_pull_tab_messy_loser_pile(surface, rect: Rect2, ripped_tabs: Array, excluded_ticket_id: String = "", excluded_ticket_present: bool = false, total_count: int = -1) -> void:
	var accent := C_AMBER
	surface.draw_rect(rect, Color("#080607"))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.24), false, 1)
	surface.surface_label("LOSERS", rect.position + Vector2(7, 13), 9, accent)
	var filtered_count := _pile_filtered_count(ripped_tabs, excluded_ticket_id, excluded_ticket_present)
	if total_count >= 0:
		filtered_count = maxi(0, total_count - (1 if excluded_ticket_present else 0))
	surface.surface_label(str(filtered_count), rect.position + Vector2(rect.size.x - 18, 13), 9, accent)
	if filtered_count <= 0:
		_draw_pull_tab_empty_stack_ghost(surface, rect, accent)
		return
	var visible_count := mini(filtered_count, 10)
	var bottom_y := rect.position.y + rect.size.y - 31.0
	var source_start_index := _pile_visible_source_start(ripped_tabs, visible_count, excluded_ticket_id)
	var draw_index := 0
	var buried_lift := 0.0
	var shadows_drawn := false
	for source_index in range(source_start_index, ripped_tabs.size()):
		var ticket_value: Variant = ripped_tabs[source_index]
		if _pile_ticket_excluded(ticket_value, excluded_ticket_id):
			continue
		var ticket: Dictionary = ticket_value as Dictionary
		if not shadows_drawn:
			var buried_count := maxi(0, _pile_depth_index(ticket, 0))
			buried_lift = minf(12.0, float(buried_count) * 1.1)
			if buried_count > 0:
				for shadow_index in range(mini(buried_count, 6)):
					var shadow_rect := Rect2(rect.position + Vector2(18 + shadow_index * 2, rect.size.y - 35 - shadow_index * 2), Vector2(rect.size.x - 38, 24))
					surface.draw_rect(shadow_rect, Color(1.0, 0.94, 0.80, 0.05))
					surface.draw_rect(shadow_rect, Color(accent.r, accent.g, accent.b, 0.10), false, 1)
			shadows_drawn = true
		var age_index := _pile_depth_index(ticket, draw_index)
		var jitter := Vector2(float((age_index * 17) % 13) - 6.0, float((age_index * 11) % 9) - 4.0)
		var pos := Vector2(rect.position.x + 22.0 + float((age_index % 3) * 4), bottom_y - buried_lift - float(draw_index) * 7.0) + jitter
		var size := Vector2(rect.size.x - 46.0 + float((age_index * 7) % 8), 23 + float((age_index * 5) % 5))
		_draw_pull_tab_pile_ticket(surface, ticket, Rect2(pos, size), draw_index, false)
		draw_index += 1


static func _pile_filtered_count(tickets: Array, excluded_ticket_id: String, excluded_ticket_present: bool = false) -> int:
	if excluded_ticket_id.is_empty():
		return tickets.size()
	if excluded_ticket_present:
		return maxi(0, tickets.size() - 1)
	var count := 0
	for ticket_value in tickets:
		if _pile_ticket_excluded(ticket_value, excluded_ticket_id):
			continue
		count += 1
	return count


static func _pile_visible_source_start(tickets: Array, visible_count: int, excluded_ticket_id: String) -> int:
	if tickets.is_empty() or visible_count <= 0:
		return 0
	if excluded_ticket_id.is_empty():
		return maxi(0, tickets.size() - visible_count)
	var seen := 0
	var source_start_index := tickets.size()
	for source_index in range(tickets.size() - 1, -1, -1):
		var ticket_value: Variant = tickets[source_index]
		if _pile_ticket_excluded(ticket_value, excluded_ticket_id):
			continue
		source_start_index = source_index
		seen += 1
		if seen >= visible_count:
			break
	if source_start_index >= tickets.size():
		return 0
	return source_start_index


static func _pile_ticket_excluded(ticket_value: Variant, excluded_ticket_id: String) -> bool:
	if typeof(ticket_value) != TYPE_DICTIONARY:
		return true
	return not excluded_ticket_id.is_empty() and str((ticket_value as Dictionary).get("id", "")) == excluded_ticket_id


static func _pile_depth_index(ticket_value: Variant, fallback: int) -> int:
	if typeof(ticket_value) != TYPE_DICTIONARY:
		return fallback
	return maxi(0, int((ticket_value as Dictionary).get("pile_depth_index", fallback)))


static func _draw_pull_tab_empty_stack_ghost(surface, rect: Rect2, accent: Color) -> void:
	for index in range(4):
		var ghost := Rect2(rect.position + Vector2(18 + index * 3, 40 + index * 10), Vector2(rect.size.x - 40, 24))
		surface.draw_rect(ghost, Color(1.0, 0.94, 0.80, 0.06))
		surface.draw_rect(ghost, Color(accent.r, accent.g, accent.b, 0.14), false, 1)


static func _draw_pull_tab_pile_ticket(surface, ticket: Dictionary, rect: Rect2, index: int, ordered: bool) -> void:
	var palette: Dictionary = ticket.get("palette", {})
	var paper := Color(str(palette.get("paper", "#fff0d8")))
	var accent := Color(str(palette.get("accent", "#ff4fb3")))
	var ink := Color(str(palette.get("ink", "#241027")))
	if ordered:
		surface.draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0.0, 0.0, 0.0, 0.22))
		surface.draw_rect(rect, paper)
		surface.draw_rect(rect, accent, false, 1)
	else:
		surface.draw_polygon([
			rect.position + Vector2(0, 2 + index % 3),
			rect.position + Vector2(rect.size.x * 0.28, 0),
			rect.position + Vector2(rect.size.x * 0.72, 2 + index % 4),
			rect.position + Vector2(rect.size.x, 1 + index % 2),
			rect.position + Vector2(rect.size.x - 3, rect.size.y),
			rect.position + Vector2(4, rect.size.y - 1),
		], [paper])
		surface.draw_line(rect.position + Vector2(2, 3), rect.position + Vector2(rect.size.x - 4, rect.size.y - 2), Color(0.0, 0.0, 0.0, 0.10), 1)
	surface.draw_rect(Rect2(rect.position + Vector2(5, 5), Vector2(rect.size.x - 10, 5)), accent)
	surface.surface_label(str(ticket.get("ticket_number", "")).left(6), rect.position + Vector2(6, rect.size.y - 5), 7, ink)
	if int(ticket.get("payout", 0)) > 0:
		surface.surface_label("$%d" % int(ticket.get("payout", 0)), rect.position + Vector2(rect.size.x - 26, rect.size.y - 5), 7, C_DARK)


static func _draw_pull_tab_file_animation(surface, surface_state: Dictionary, source_rect: Rect2, piles_rect: Rect2) -> void:
	if not bool(surface.surface_animation_active(PULL_TAB_FILE_CHANNEL)):
		return
	var ticket := surface_state.get("pull_tab_file_animation_ticket", {}) as Dictionary if typeof(surface_state.get("pull_tab_file_animation_ticket", {})) == TYPE_DICTIONARY else {}
	if ticket.is_empty():
		return
	var pile_name := str(surface_state.get("pull_tab_file_animation_pile", "loser_pile"))
	var progress := _ease_in_out_cubic(surface.surface_animation_progress(PULL_TAB_FILE_CHANNEL))
	var gap := 8.0
	var pile_width := (piles_rect.size.x - gap) * 0.5
	var target_rect := Rect2(piles_rect.position + Vector2(22, 70), Vector2(102, 34))
	if pile_name == "loser_pile":
		target_rect = Rect2(piles_rect.position + Vector2(pile_width + gap + 28, 82), Vector2(86, 30))
	var pos := source_rect.position.lerp(target_rect.position, progress)
	var size := source_rect.size.lerp(target_rect.size, progress)
	var flying := Rect2(pos, size)
	var alpha := 1.0 - maxf(0.0, progress - 0.82) / 0.18
	surface.draw_rect(flying.grow(5), Color(0.0, 0.0, 0.0, 0.22 * alpha))
	_draw_pull_tab_mini_ticket(surface, ticket, flying, 0.92 * alpha)
	surface.draw_rect(flying.grow(3), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.24 * (1.0 - progress)), false, 3)


static func _draw_pull_tab_symbol(surface, symbol: String, rect: Rect2) -> void:
	var center := rect.position + rect.size * 0.5
	match symbol:
		"CHERRY":
			surface.draw_line(center + Vector2(0, -7), center + Vector2(-4, -2), C_TEAL, 1)
			surface.draw_circle(center + Vector2(-4, 2), maxf(2.0, rect.size.x * 0.18), C_PINK)
			surface.draw_circle(center + Vector2(4, 3), maxf(2.0, rect.size.x * 0.18), C_PINK_2)
		"LEMON":
			surface.draw_circle(center, maxf(3.0, rect.size.x * 0.28), C_YELLOW)
			surface.draw_line(center + Vector2(-6, 0), center + Vector2(6, 0), C_AMBER, 2)
		"BELL":
			surface.draw_polygon([
				center + Vector2(-8, 7),
				center + Vector2(8, 7),
				center + Vector2(5, -4),
				center + Vector2(-5, -4),
			], [C_YELLOW])
			surface.draw_circle(center + Vector2(0, 8), 2, Color("#ff9f43"))
		"BAR":
			var bar_rect := Rect2(center + Vector2(-13, -6), Vector2(26, 12))
			surface.draw_rect(bar_rect, C_DARK)
			surface.surface_label_centered("BAR", bar_rect.grow(-1.0), int(clampf(rect.size.y * 0.46, 6.0, 8.0)), C_WHITE)
		"7":
			surface.surface_label("7", center + Vector2(-5, rect.size.y * 0.32), int(clampf(rect.size.y * 0.80, 7.0, 16.0)), C_YELLOW)
		"CROWN":
			var crown := [
				center + Vector2(-9, 7),
				center + Vector2(-7, -5),
				center + Vector2(-3, 1),
				center + Vector2(0, -8),
				center + Vector2(3, 1),
				center + Vector2(7, -5),
				center + Vector2(9, 7),
			]
			surface.draw_polygon(crown, [C_YELLOW])
			surface.draw_line(center + Vector2(-8, 7), center + Vector2(8, 7), C_AMBER, 2)
		_:
			surface.surface_label(symbol.left(3), rect.position + Vector2(5, rect.size.y * 0.68), 8, C_WHITE)


static func _pull_tab_find_ticket(stack: Array, ticket_id: String) -> Dictionary:
	for value in stack:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var ticket: Dictionary = value
		if str(ticket.get("id", "")) == ticket_id:
			return ticket
	return {}


static func _ease_out_cubic(t: float) -> float:
	var clamped := clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped, 3.0)


static func _ease_in_out_cubic(t: float) -> float:
	var clamped := clampf(t, 0.0, 1.0)
	if clamped < 0.5:
		return 4.0 * clamped * clamped * clamped
	return 1.0 - pow(-2.0 * clamped + 2.0, 3.0) / 2.0


static func _dictionary_view_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append(entry as Dictionary)
	return result


static func _array_view(value: Variant) -> Array:
	return value as Array if value is Array else []
