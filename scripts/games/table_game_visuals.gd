class_name TableGameVisuals
extends RefCounted

const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const C_DARK := VisualStyleScript.DARK
const C_DARK_2 := VisualStyleScript.DARK_2
const C_PINK := VisualStyleScript.PINK
const C_PINK_2 := VisualStyleScript.PINK_2
const C_CYAN := VisualStyleScript.CYAN
const C_TEAL := VisualStyleScript.TEAL
const C_YELLOW := VisualStyleScript.YELLOW
const C_ORANGE := VisualStyleScript.ORANGE
const C_WHITE := VisualStyleScript.WHITE
const C_SOFT := VisualStyleScript.SOFT

const TABLE_ROUND_WARNING_MSEC := 5000
const CONSOLE_Y := 342.0
const TABLE_BOTTOM := 334.0
const DEFAULT_PATRON_POSITIONS := [
	Vector2(128, 176),
	Vector2(272, 130),
	Vector2(628, 130),
	Vector2(772, 176),
]


static func draw_room(surface, state: Dictionary, title: String, info: String = "") -> void:
	var clock := _surface_clock(surface)
	var board_size: Vector2 = surface.surface_board_size()
	surface.draw_rect(Rect2(Vector2.ZERO, board_size), Color("#05060a"))
	surface.draw_rect(Rect2(0, 0, board_size.x, 82), Color("#101427"))
	surface.draw_rect(Rect2(0, 82, board_size.x, CONSOLE_Y - 82.0), Color("#070810"))
	surface.draw_rect(Rect2(0, CONSOLE_Y, board_size.x, maxf(0.0, board_size.y - CONSOLE_Y)), Color("#07070d"))
	surface.draw_rect(Rect2(0, 78, board_size.x, 3), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.62))
	surface.draw_rect(Rect2(0, CONSOLE_Y - 3.0, board_size.x, 3), Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.42))
	_draw_surface_light_cone(surface, Vector2(176, 78), Vector2(190, 238), C_CYAN, 0.065)
	_draw_surface_light_cone(surface, Vector2(724, 78), Vector2(188, 238), C_PINK, 0.070)
	_draw_surface_scan_bands(surface, 0, int(board_size.x), 0, 146, C_CYAN, 0.040, 1.6)
	_draw_neon_panel(surface, Rect2(24, 14, 286, 58), C_CYAN, 0.16 + absf(sin(clock * 2.1)) * 0.04)
	_draw_neon_panel(surface, Rect2(332, 18, 236, 48), C_PINK, 0.12 + absf(sin(clock * 1.7)) * 0.04)
	_draw_security_mirror(surface, Rect2(606, 16, 68, 50), C_PINK)
	_draw_watch_camera_surface(surface, Vector2(584, 42), C_PINK)
	surface.surface_title(title.to_upper().left(18), Vector2(36, 42), C_CYAN)
	if not info.is_empty():
		surface.surface_label(info.left(42), Vector2(42, 62), 10, C_SOFT)
	if not str(state.get("room_note", "")).is_empty():
		surface.surface_label(str(state.get("room_note", "")).left(28), Vector2(344, 48), 12, C_SOFT)


static func draw_table(surface) -> void:
	var clock := _surface_clock(surface)
	var rail_points := [
		Vector2(46, 142), Vector2(156, 92), Vector2(334, 76), Vector2(566, 76),
		Vector2(744, 92), Vector2(854, 142), Vector2(822, TABLE_BOTTOM), Vector2(78, TABLE_BOTTOM),
	]
	surface.draw_polygon(rail_points, [Color("#170d17")])
	surface.draw_polygon([
		Vector2(58, 148), Vector2(170, 102), Vector2(342, 86), Vector2(558, 86),
		Vector2(730, 102), Vector2(842, 148), Vector2(808, TABLE_BOTTOM - 12.0), Vector2(92, TABLE_BOTTOM - 12.0),
	], [Color("#3a1830")])
	var felt_points := [
		Vector2(84, 154), Vector2(190, 116), Vector2(358, 102), Vector2(542, 102),
		Vector2(710, 116), Vector2(816, 154), Vector2(766, 314), Vector2(134, 314),
	]
	surface.draw_polygon(felt_points, [Color("#0a5a48")])
	surface.draw_polygon([
		Vector2(126, 166), Vector2(226, 136), Vector2(372, 120), Vector2(528, 120),
		Vector2(674, 136), Vector2(774, 166), Vector2(736, 292), Vector2(164, 292),
	], [Color("#063f35")])
	for i in range(7):
		var y := 134 + i * 20
		surface.draw_line(Vector2(144 + i * 5, y), Vector2(756 - i * 5, y + 3), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.035), 1)
	surface.draw_rect(Rect2(116, 316, 672, 5), Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.30))
	surface.draw_rect(Rect2(140, 308, 620, 2), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.16 + absf(sin(clock * 2.4)) * 0.08))


static func draw_dealer_station(surface, state: Dictionary, label_override: String = "") -> void:
	var focus := dealer_focus_for_state(state)
	var profile := _copy_dict(state.get("dealer_profile", {}))
	var looking_away := bool(focus.get("lookaway_active", false))
	var peek_window := bool(focus.get("peek_window_open", looking_away))
	var blink := bool(focus.get("blink", false))
	var eye_offset := float(focus.get("eye_offset", 0.0))
	var idle := _surface_clock(surface) + float(int(profile.get("blink_offset", 0))) / 1000.0
	var attention_color := C_PINK if int(focus.get("peek_danger", 0)) >= 70 else C_YELLOW if int(focus.get("peek_danger", 0)) >= 42 else C_TEAL
	surface.draw_rect(Rect2(352, 54, 196, 104), Color("#0b0d16"))
	surface.draw_rect(Rect2(352, 54, 196, 104), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.18), false, 1)
	_draw_dealer_gaze(surface, focus, Vector2(450, 91))
	_draw_table_character(surface, {
		"name": str(state.get("dealer_name", profile.get("name", "Dealer"))),
		"skin": Color("#d8b18a"),
		"hair": Color("#2a1a25"),
		"jacket": Color("#1b2230"),
		"accent": attention_color,
		"role": "dealer",
		"pose": "lookaway" if peek_window else "watching",
		"eye_offset": eye_offset,
		"blink": blink,
		"holding_card": bool(state.get("dealer_holding_card", false)),
		"uniform_accent": str(profile.get("uniform_accent", "")),
	}, Vector2(450, 156), 1.06, idle)
	var meter := clampi(int(focus.get("attention_meter", 0)), 0, 100)
	_draw_status_meter(surface, Rect2(566, 92, 118, 9), meter, "dealer %s" % str(focus.get("status", "watching")), C_PINK if meter >= 70 else C_YELLOW if meter >= 42 else C_TEAL)
	_draw_status_meter(surface, Rect2(566, 116, 118, 6), int(focus.get("peek_danger", 0)), str(focus.get("gaze_phase", "read")).left(20), attention_color)
	if peek_window:
		_draw_neon_panel(surface, Rect2(566, 130, 122, 22), C_TEAL, 0.28)
		var peek_label := "PEEK %.1fs" % (float(int(focus.get("lookaway_remaining_msec", 0))) / 1000.0) if looking_away else "READ WINDOW"
		surface.surface_label_centered(peek_label, Rect2(570, 134, 114, 14), 11, C_TEAL)
	else:
		var label := label_override if not label_override.is_empty() else str(focus.get("body_language", focus.get("tell", "")))
		surface.surface_label(label.left(26), Vector2(566, 142), 9, C_SOFT)


static func draw_table_patrons(surface, state: Dictionary, positions: Array = []) -> void:
	var patrons := _dictionary_array(state.get("patrons", []))
	var seat_positions := positions if not positions.is_empty() else DEFAULT_PATRON_POSITIONS
	for i in range(patrons.size()):
		var patron: Dictionary = patrons[i]
		var base_pos: Vector2 = seat_positions[clampi(i, 0, seat_positions.size() - 1)]
		var phase := fmod((_surface_clock(surface) + float(int(patron.get("animation_offset", 0))) / 1000.0) / 2.2, 1.0)
		var bob := sin(phase * PI * 2.0) * (2.0 if bool(patron.get("watching_player", false)) else 1.0)
		var lean := float(patron.get("lean", 0.0))
		var pos := base_pos + Vector2(lean, bob)
		var watching := bool(patron.get("watching_player", false))
		var covered := bool(patron.get("covered", false))
		var risk := int(patron.get("active_snitch_risk", patron.get("snitch_risk", 0)))
		var threshold := int(patron.get("snitch_threshold", 30))
		var tell_active := bool(patron.get("tell_active", false)) or (watching and (risk >= threshold or (phase > 0.58 and phase < 0.82)))
		var accent := C_PINK if watching else C_TEAL if covered else C_SOFT
		var character_clock := _surface_clock(surface) + float(int(patron.get("animation_offset", 0))) / 1000.0
		_draw_table_character(surface, {
			"name": str(patron.get("name", "Seat")),
			"skin": Color("#c49371"),
			"hair": _patron_hair_color(patron),
			"jacket": _patron_jacket_color(patron),
			"accent": accent,
			"role": "patron",
			"pose": "covered" if covered else "snitch" if watching else "idle",
			"eye_offset": -2.0 if covered else 2.0 if watching else 0.0,
			"blink": phase > 0.92,
			"holding_card": false,
			"silhouette": str(patron.get("silhouette", "coat")),
		}, pos + Vector2(0, 52), 0.86, character_clock)
		if tell_active:
			_draw_neon_panel(surface, Rect2(pos.x - 36, pos.y - 46, 72, 20), accent, 0.22)
			surface.surface_label(str(patron.get("tell", "watching")).left(11), pos + Vector2(-30, -32), 8, accent)
			surface.draw_line(pos + Vector2(0, -24), Vector2(450, 284), Color(accent.r, accent.g, accent.b, 0.18), 1.0)
		var risk_width := clampf(float(risk) / 60.0, 0.0, 1.0) * 46.0
		surface.draw_rect(Rect2(pos.x - 28, pos.y + 61, 56, 5), Color("#070810"))
		surface.draw_rect(Rect2(pos.x - 28, pos.y + 61, risk_width, 5), accent)
		surface.surface_label(str(patron.get("behavior", ("%d" % risk) if watching else str(patron.get("mood", "")).left(7))).left(12), pos + Vector2(-30, 78), 9, accent)
		_draw_patron_chip_stack(surface, pos + Vector2(30, 42), clampi(int(patron.get("chip_stack", 0)) / 20, 1, 4), accent)
		draw_patron_wager_badge(surface, state, patron, pos, i)


static func draw_patron_wager_badge(surface, state: Dictionary, patron: Dictionary, pos: Vector2, index: int) -> void:
	var wager := _copy_dict(patron.get("visible_bet", patron.get("wager", {})))
	if wager.is_empty():
		return
	var action := str(state.get("patron_wager_action", ""))
	var rapport := clampi(int(patron.get("rapport", 50)), 0, 100)
	var rapport_color := C_TEAL if rapport >= 58 else C_PINK if rapport <= 42 else C_YELLOW
	var chip_color := _chip_color_name(str(patron.get("chip_color", "cyan")))
	var rect := Rect2(pos.x - 40.0, pos.y + 88.0, 80.0, 38.0)
	var board_size: Vector2 = surface.surface_board_size() if surface != null and surface.has_method("surface_board_size") else Vector2(900, 430)
	if rect.position.x < 4.0:
		rect.position.x = 4.0
	if rect.end.x > board_size.x - 4.0:
		rect.position.x = board_size.x - rect.size.x - 4.0
	if rect.end.y + 16.0 > board_size.y:
		rect.position.y = board_size.y - rect.size.y - 16.0
	_draw_neon_panel(surface, rect, rapport_color, 0.16)
	surface.surface_label("THEM", rect.position + Vector2(5, 11), 7, Color(C_SOFT.r, C_SOFT.g, C_SOFT.b, 0.72))
	surface.surface_label(str(wager.get("label", "bet")).to_upper().left(11), rect.position + Vector2(28, 12), 8, C_WHITE)
	_draw_mini_chip(surface, rect.position + Vector2(14, 25), chip_color, int(wager.get("stake", patron.get("chip_stack", 0))))
	surface.surface_label("$%d" % int(wager.get("stake", 0)), rect.position + Vector2(26, 29), 8, C_YELLOW)
	var meter := Rect2(rect.position + Vector2(5, 32), Vector2(70, 3))
	surface.draw_rect(meter, Color("#070810"))
	surface.draw_rect(Rect2(meter.position, Vector2(meter.size.x * float(rapport) / 100.0, meter.size.y)), rapport_color)
	if not action.is_empty():
		var with_rect := Rect2(rect.position + Vector2(5, 40), Vector2(33, 12))
		var fade_rect := Rect2(rect.position + Vector2(42, 40), Vector2(33, 12))
		surface.draw_rect(with_rect, Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.16))
		surface.draw_rect(fade_rect, Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.16))
		surface.draw_rect(with_rect, C_TEAL, false, 1)
		surface.draw_rect(fade_rect, C_PINK, false, 1)
		surface.surface_label_centered("WITH", with_rect, 7, C_TEAL)
		surface.surface_label_centered("FADE", fade_rect, 7, C_PINK)
		surface.surface_add_hit(with_rect, action, index)
		surface.surface_add_hit(fade_rect, action, index + 100)


static func draw_round_timer_panel(surface, timer_value: Variant, rect: Rect2, accent: Color = C_YELLOW) -> void:
	if typeof(timer_value) != TYPE_DICTIONARY:
		return
	var timer: Dictionary = timer_value as Dictionary
	if timer.is_empty() or not bool(timer.get("active", false)):
		return
	var remaining_msec := maxi(0, int(timer.get("remaining_msec", 0)))
	var progress := clampf(float(timer.get("progress", 0.0)), 0.0, 1.0)
	var started_msec := maxi(0, int(timer.get("started_msec", 0)))
	var duration_msec := maxi(0, int(timer.get("duration_msec", 0)))
	if started_msec > 0 and duration_msec > 0:
		var elapsed_msec := maxi(0, Time.get_ticks_msec() - started_msec)
		remaining_msec = maxi(0, duration_msec - elapsed_msec)
		progress = clampf(float(elapsed_msec) / float(duration_msec), 0.0, 1.0)
	var warning := bool(timer.get("warning", false)) or (started_msec > 0 and remaining_msec <= TABLE_ROUND_WARNING_MSEC)
	var color := C_PINK if warning else accent
	_draw_neon_panel(surface, rect, color, 0.16 if warning else 0.11)
	var label := str(timer.get("label", "Next round")).to_upper().left(20)
	var seconds := maxi(0, int(ceil(float(remaining_msec) / 1000.0)))
	surface.surface_label(label, rect.position + Vector2(8, 13), 8, C_SOFT)
	surface.surface_label("%02ds" % seconds, rect.position + Vector2(rect.size.x - 44.0, 15), 14, color)
	var bar_rect := Rect2(rect.position + Vector2(8, rect.size.y - 12.0), Vector2(maxf(1.0, rect.size.x - 16.0), 4.0))
	surface.draw_rect(bar_rect, Color("#070810"))
	surface.draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * progress, bar_rect.size.y)), color)


static func dealer_focus_for_state(state: Dictionary) -> Dictionary:
	var runtime := _copy_dict(state.get("dealer_focus_runtime", {}))
	var profile := _copy_dict(state.get("dealer_profile", {}))
	var base_attention := int(profile.get("attention_base", 24))
	var heat := int(state.get("suspicion_level", 0))
	var started := int(runtime.get("dealer_lookaway_started_msec", 0))
	var duration := int(runtime.get("dealer_lookaway_duration_msec", 0))
	var now := Time.get_ticks_msec()
	var active := started > 0 and duration > 0 and now <= started + duration
	var remaining := maxi(0, started + duration - now) if active else 0
	var cycle_msec := maxi(900, int(320000 / maxi(45, int(profile.get("gaze_speed", 95)))))
	var phase := float((now + int(profile.get("blink_offset", 0))) % cycle_msec) / float(cycle_msec)
	var sweep := sin(phase * PI * 2.0)
	var scan_attention := int((0.5 + 0.5 * sweep) * 18.0)
	var table_pressure := int(state.get("dealer_attention_pressure", 0))
	var attention := clampi(base_attention + int(float(heat) * 0.35) + scan_attention + table_pressure, 0, 100)
	if active:
		attention = clampi(attention - 44 - int(runtime.get("dealer_distraction_cover", 0)), 0, 100)
	var blink := phase > 0.94 and phase < 0.985
	var watching_player := not active and phase >= 0.18 and phase <= 0.46
	var read_window := active or (attention < 58 and phase > 0.54 and phase < 0.70)
	var peek_danger := clampi(attention + (0 if active else int(abs(sweep) * 16.0)) + int(int(state.get("snitch_pressure", 0)) / 4.0), 0, 100)
	var peek_window_open := active or (read_window and not watching_player and peek_danger <= 62)
	var read_style := str(profile.get("read_style", "slow sweep"))
	var gaze_phase := "looking away" if active else "blink" if blink else "watching you" if watching_player else "read window" if peek_window_open else "open read" if read_window else read_style
	var body_language := "shoulder turned" if active else "eyes on your chips" if watching_player else "checks payout tray" if peek_window_open or phase > 0.70 else str(profile.get("tell", "tracks the felt"))
	return {
		"lookaway_active": active,
		"lookaway_remaining_msec": remaining,
		"attention_meter": attention,
		"status": "looking away" if active else "locked on" if attention >= 70 else "watching",
		"tell": str(profile.get("tell", "watches hands more than faces")),
		"gaze_phase": gaze_phase,
		"body_language": body_language,
		"read_window": read_window,
		"watching_player": watching_player,
		"peek_window_open": peek_window_open,
		"scan_phase": phase,
		"peek_danger": peek_danger,
		"eye_offset": -0.65 if active else sweep,
		"blink": blink,
	}


static func _draw_dealer_gaze(surface, focus: Dictionary, eye_origin: Vector2) -> void:
	if bool(focus.get("peek_window_open", bool(focus.get("lookaway_active", false)))):
		surface.draw_line(eye_origin + Vector2(-6, 0), eye_origin + Vector2(-70, 22), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.34), 2.0)
		return
	var danger := clampi(int(focus.get("peek_danger", 0)), 0, 100)
	var alpha := 0.06 + float(danger) / 100.0 * 0.14
	var target := Vector2(450 + float(focus.get("eye_offset", 0.0)) * 9.0, 292)
	var color := C_PINK if danger >= 70 else C_YELLOW if danger >= 42 else C_TEAL
	surface.draw_polygon([
		eye_origin + Vector2(-12, 3),
		eye_origin + Vector2(12, 3),
		target + Vector2(88, 0),
		target + Vector2(-88, 0),
	], [Color(color.r, color.g, color.b, alpha)])


static func _draw_neon_panel(surface, rect: Rect2, accent: Color, alpha: float = 0.18) -> void:
	surface.draw_rect(rect.grow(4), Color(accent.r, accent.g, accent.b, alpha * 0.22))
	surface.draw_rect(rect, Color(0.01, 0.02, 0.05, 0.72))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, alpha), false, 1)
	surface.draw_rect(Rect2(rect.position + Vector2(4, rect.size.y - 5), Vector2(maxf(0.0, rect.size.x - 8), 2)), Color(accent.r, accent.g, accent.b, alpha * 1.6))


static func _draw_surface_scan_bands(surface, x0: int, x1: int, y0: int, y1: int, color: Color, alpha: float, speed: float) -> void:
	var height := maxi(1, y1 - y0)
	var band_y := y0 + int(fmod(_surface_clock(surface) * speed * 20.0, float(height)))
	surface.draw_rect(Rect2(x0, band_y, x1 - x0, 2), Color(color.r, color.g, color.b, alpha))
	surface.draw_rect(Rect2(x0, y0 + int(fmod(float(band_y - y0 + 19), float(height))), x1 - x0, 1), Color(color.r, color.g, color.b, alpha * 0.55))


static func _draw_surface_light_cone(surface, origin: Vector2, fall: Vector2, color: Color, alpha: float) -> void:
	surface.draw_polygon([
		origin + Vector2(-36, 0),
		origin + Vector2(36, 0),
		origin + Vector2(fall.x, fall.y),
		origin + Vector2(-fall.x, fall.y),
	], [Color(color.r, color.g, color.b, alpha)])


static func _draw_security_mirror(surface, rect: Rect2, accent: Color) -> void:
	surface.draw_rect(rect, Color("#05060a"))
	surface.draw_rect(Rect2(rect.position + Vector2(8, 8), rect.size - Vector2(16, 16)), Color("#111421"))
	surface.draw_rect(Rect2(rect.position + Vector2(16, 15), Vector2(rect.size.x - 32, 3)), Color(accent.r, accent.g, accent.b, 0.42))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.28), false, 1)


static func _draw_watch_camera_surface(surface, pos: Vector2, accent: Color) -> void:
	surface.draw_rect(Rect2(pos + Vector2(-20, -10), Vector2(40, 20)), Color("#05060a"))
	surface.draw_rect(Rect2(pos + Vector2(-8, -5), Vector2(16, 10)), C_DARK_2)
	surface.draw_rect(Rect2(pos + Vector2(-3, -3), Vector2(6, 6)), accent)
	surface.draw_line(pos + Vector2(0, 8), Vector2(492, 190), Color(accent.r, accent.g, accent.b, 0.12), 1)


static func _draw_status_meter(surface, rect: Rect2, value: int, label: String, accent: Color) -> void:
	var clamped := clampi(value, 0, 100)
	surface.draw_rect(rect, Color("#080a12"))
	surface.draw_rect(Rect2(rect.position, Vector2(rect.size.x * float(clamped) / 100.0, rect.size.y)), accent)
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.22), false, 1)
	surface.surface_label(label.left(26), rect.position + Vector2(0, -4), 9, accent)


static func _draw_table_character(surface, style: Dictionary, foot: Vector2, scale_value: float, clock: float) -> void:
	var accent := _style_accent(style)
	var skin: Color = style.get("skin", Color("#c49371")) if typeof(style.get("skin", Color("#c49371"))) == TYPE_COLOR else Color("#c49371")
	var hair: Color = style.get("hair", Color("#171022")) if typeof(style.get("hair", Color("#171022"))) == TYPE_COLOR else Color("#171022")
	var jacket: Color = style.get("jacket", Color("#1d2030")) if typeof(style.get("jacket", Color("#1d2030"))) == TYPE_COLOR else Color("#1d2030")
	var pose := str(style.get("pose", "idle"))
	var sway := sin(clock * 1.8) * 2.0 * scale_value
	var lean := 4.0 * scale_value if pose == "snitch" else -4.0 * scale_value if pose == "covered" or pose == "lookaway" else 0.0
	var pos := foot + Vector2(sway + lean, 0)
	var head := Rect2(pos + Vector2(-12, -78) * scale_value, Vector2(24, 24) * scale_value)
	var body := Rect2(pos + Vector2(-23, -54) * scale_value, Vector2(46, 52) * scale_value)
	surface.draw_rect(Rect2(pos.x - 25 * scale_value, pos.y - 6 * scale_value, 50 * scale_value, 5 * scale_value), Color(0, 0, 0, 0.34))
	surface.draw_rect(body, Color("#05060a"))
	surface.draw_rect(Rect2(body.position + Vector2(4, 5) * scale_value, body.size - Vector2(8, 9) * scale_value), jacket)
	surface.draw_rect(Rect2(pos + Vector2(-18, -56) * scale_value, Vector2(36, 6) * scale_value), accent)
	_draw_character_arm(surface, pos, scale_value, accent, pose, true)
	_draw_character_arm(surface, pos, scale_value, accent, pose, false)
	surface.draw_rect(head, skin)
	surface.draw_rect(Rect2(head.position, Vector2(head.size.x, 8 * scale_value)), hair)
	_draw_character_face(surface, head, scale_value, float(style.get("eye_offset", 0.0)), bool(style.get("blink", false)), pose)
	if str(style.get("silhouette", "")) == "cap":
		surface.draw_rect(Rect2(head.position + Vector2(-3, -3) * scale_value, Vector2(head.size.x + 8 * scale_value, 5 * scale_value)), hair)
	elif str(style.get("silhouette", "")) == "glasses":
		surface.draw_rect(Rect2(head.position + Vector2(4, 10) * scale_value, Vector2(6, 4) * scale_value), Color("#05060a"), false, 1)
		surface.draw_rect(Rect2(head.position + Vector2(14, 10) * scale_value, Vector2(6, 4) * scale_value), Color("#05060a"), false, 1)
	elif str(style.get("silhouette", "")) == "rings":
		surface.draw_rect(Rect2(pos + Vector2(-30, -22) * scale_value, Vector2(6, 4) * scale_value), C_YELLOW)
	if bool(style.get("holding_card", false)):
		_draw_hidden_card(surface, pos + Vector2(-34, -35) * scale_value, 0.28 * scale_value)
	var name := str(style.get("name", ""))
	if not name.is_empty():
		surface.surface_label(name.left(10), pos + Vector2(-26, 10) * scale_value, int(10 * scale_value), accent)


static func _draw_character_arm(surface, pos: Vector2, scale_value: float, accent: Color, pose: String, left: bool) -> void:
	var side := -1.0 if left else 1.0
	var shoulder := pos + Vector2(side * 24, -45) * scale_value
	var hand := pos + Vector2(side * 42, -22) * scale_value
	if pose == "snitch":
		hand = pos + Vector2(side * 34, -58) * scale_value
	elif pose == "covered":
		hand = pos + Vector2(side * 22, -28) * scale_value
	elif pose == "lookaway":
		hand = pos + Vector2(side * 36, -30) * scale_value
	elif pose == "watching" and left:
		hand = pos + Vector2(side * 30, -18) * scale_value
	surface.draw_line(shoulder, hand, Color("#05060a"), maxf(2.0, 6.0 * scale_value))
	surface.draw_line(shoulder, hand, Color(accent.r, accent.g, accent.b, 0.42), maxf(1.0, 2.0 * scale_value))
	surface.draw_rect(Rect2(hand + Vector2(-3, -2) * scale_value, Vector2(6, 6) * scale_value), Color("#c49371"))


static func _draw_character_face(surface, head: Rect2, scale_value: float, eye_offset: float, blink: bool, pose: String) -> void:
	var eye_y := head.position.y + 12 * scale_value
	var left_eye := head.position + Vector2(6 + eye_offset, 12) * scale_value
	var right_eye := head.position + Vector2(16 + eye_offset, 12) * scale_value
	if blink:
		surface.draw_rect(Rect2(left_eye, Vector2(5, 1) * scale_value), Color("#05060a"))
		surface.draw_rect(Rect2(right_eye, Vector2(5, 1) * scale_value), Color("#05060a"))
	else:
		surface.draw_rect(Rect2(left_eye, Vector2(4, 3) * scale_value), Color("#05060a"))
		surface.draw_rect(Rect2(right_eye, Vector2(4, 3) * scale_value), Color("#05060a"))
	var mouth_color := C_PINK if pose == "snitch" else Color("#3a1830")
	surface.draw_rect(Rect2(head.position.x + 8 * scale_value, eye_y + 8 * scale_value, 8 * scale_value, 2 * scale_value), mouth_color)


static func _draw_hidden_card(surface, pos: Vector2, scale: float) -> void:
	var size := Vector2(42, 60) * scale
	surface.draw_rect(Rect2(pos, size), C_SOFT)
	surface.draw_rect(Rect2(pos + Vector2(3, 3) * scale, size - Vector2(6, 6) * scale), C_PINK)
	surface.draw_rect(Rect2(pos + Vector2(9, 9) * scale, size - Vector2(18, 18) * scale), Color("#563be0"))


static func _draw_patron_chip_stack(surface, pos: Vector2, count: int, accent: Color) -> void:
	for i in range(clampi(count, 1, 4)):
		var center := pos + Vector2(0, -float(i) * 2.4)
		surface.draw_circle(center, 5.2, Color(accent.r, accent.g, accent.b, 0.30))
		surface.draw_circle(center, 4.0, C_CYAN if i % 2 == 0 else C_YELLOW)
		surface.draw_circle(center, 2.0, Color("#f8f4dc"))


static func _draw_mini_chip(surface, center: Vector2, color: Color, value: int = 0) -> void:
	surface.draw_circle(center, 6.0, Color(color.r, color.g, color.b, 0.38))
	surface.draw_circle(center, 4.8, color)
	surface.draw_circle(center, 2.4, Color("#f8f4dc"))
	if value > 0:
		surface.surface_label_centered("%d" % mini(99, value), Rect2(center - Vector2(5, 3), Vector2(10, 6)), 5, C_DARK)


static func _chip_color_name(name: String) -> Color:
	match name:
		"pink":
			return C_PINK
		"yellow":
			return C_YELLOW
		"teal":
			return C_TEAL
		"orange":
			return C_ORANGE
		"blue", "cyan":
			return C_CYAN
		_:
			return C_SOFT


static func _patron_hair_color(patron: Dictionary) -> Color:
	match str(patron.get("silhouette", "coat")):
		"cap":
			return Color("#2d1a28")
		"rings":
			return Color("#513315")
		"glasses":
			return Color("#08090e")
		_:
			return Color("#2b1630")


static func _patron_jacket_color(patron: Dictionary) -> Color:
	match str(patron.get("seat_style", "open")):
		"vest":
			return Color("#262033")
		"jacket":
			return Color("#27333b")
		_:
			return Color("#1d2030")


static func _style_accent(style: Dictionary) -> Color:
	var accent_value: Variant = style.get("accent", C_CYAN)
	if typeof(accent_value) == TYPE_COLOR:
		return accent_value
	if typeof(accent_value) == TYPE_DICTIONARY:
		accent_value = str((accent_value as Dictionary).get("name", "cyan"))
	match str(accent_value):
		"pink":
			return C_PINK
		"teal":
			return C_TEAL
		"yellow":
			return C_YELLOW
		"orange":
			return C_ORANGE
		_:
			return C_CYAN


static func _surface_clock(surface) -> float:
	return float(surface.surface_flicker()) if surface != null and surface.has_method("surface_flicker") else float(Time.get_ticks_msec()) / 1000.0


static func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


static func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
