class_name SlotRenderer
extends RefCounted

const CatalogScript := preload("res://scripts/games/slots/slot_catalog.gd")
const PinballTableScript := preload("res://scripts/games/slots/slot_pinball_table.gd")
const DESIGN_SIZE := Vector2(960, 540)
const PINBALL_AIM_MIN_DEGREES := -60
const PINBALL_AIM_MAX_DEGREES := 60
const PINBALL_AIM_CHOICES := 13
const PINBALL_START_CHOICES := 11
const PINBALL_POWER_CHOICES := 11

var catalog


func _init() -> void:
	catalog = CatalogScript.new()


func render_signature(surface_state: Dictionary, _definition: Dictionary, time_msec: int = 0, phase_id: String = "") -> Dictionary:
	var skin: Dictionary = _read_dict(surface_state.get("slot_skin", {}))
	var active_bonus: Dictionary = _read_dict(surface_state.get("slot_active_bonus", {}))
	var plan: Dictionary = _read_dict(surface_state.get("slot_animation_plan", {}))
	var mode := phase_id
	if mode.is_empty():
		mode = "feature" if bool(surface_state.get("slot_active_bonus_active", false)) else "spin" if not str(surface_state.get("slot_animation_id", "")).is_empty() else "attract"
	var reel_motion: Array = []
	var reel_phase: Array = []
	var reel_scroll_cells: Array = []
	var reel_blur: Array = []
	var reel_stop_msec: Array = []
	var timeline: Array = _read_array(surface_state.get("slot_reel_timeline", []))
	for entry_value in timeline:
		var entry: Dictionary = _read_dict(entry_value)
		var motion: Dictionary = _reel_motion(entry, time_msec)
		reel_motion.append(motion)
		reel_phase.append(str(motion.get("phase", "settled")))
		reel_scroll_cells.append(float(motion.get("scroll_cells", 0.0)))
		reel_blur.append(float(motion.get("blur", 0.0)))
		reel_stop_msec.append(int(round(float(entry.get("stop_time", 0.0)) * 1000.0)))
	var attract_bucket := posmod(time_msec / 180, 20)
	var feature_hash := "%s:%d:%d:%d" % [
		str(active_bonus.get("mode", "")),
		int(active_bonus.get("step_index", 0)),
		int(active_bonus.get("feature_total", active_bonus.get("pending_award", 0))),
		_array_read_size(active_bonus.get("locks", [])) + _array_read_size(active_bonus.get("history", [])) + int(active_bonus.get("coins_collected", 0)),
	]
	var win_cells: Array = _read_array(surface_state.get("slot_win_cells", []))
	var win_kind := str(surface_state.get("slot_win_kind", "none"))
	var tier := str(surface_state.get("slot_celebration_tier", plan.get("celebration_tier", "none")))
	var result_reveal_ready := _result_reveal_ready(surface_state, time_msec)
	var count_up_active: bool = _count_up_active(plan, time_msec, tier)
	var particle_count: int = _particle_count_for_tier(tier, time_msec, plan)
	var strip_payload: Dictionary = _result_strip_payload(surface_state, time_msec)
	var signature: Dictionary = {
		"cabinet": str(surface_state.get("slot_cabinet_signature", skin.get("cabinet_identity", ""))),
		"identity": str(skin.get("cabinet_identity", "")),
		"topper": str(skin.get("topper_style", "")),
		"material": str(skin.get("material", "")),
		"family": str(surface_state.get("slot_type_id", "")),
		"format": str(surface_state.get("slot_format_id", "")),
		"mode": mode,
		"buffalo_grand_prize": int(surface_state.get("slot_buffalo_grand_prize", 0)),
		"buffalo_grand_prize_advertised": str(surface_state.get("slot_type_id", "")) == "buffalo" and int(surface_state.get("slot_buffalo_grand_prize", 0)) > 0,
		"time_bucket": attract_bucket,
		"reel_motion": reel_motion,
		"reel_phase": reel_phase,
		"reel_scroll_cells": reel_scroll_cells,
		"reel_blur": reel_blur,
		"reel_stop_msec": reel_stop_msec,
		"tease_active": bool(plan.get("tease_active", false)) or str(surface_state.get("slot_classification", "")) == "near_miss",
		"tease_overlay_visible": result_reveal_ready and (bool(plan.get("tease_active", false)) or str(surface_state.get("slot_classification", "")) == "near_miss"),
		"tease_reel": int(plan.get("tease_reel", -1)),
		"gold_tease_active": int(plan.get("tease_coin_count", 0)) > 0,
		"gold_tease_level": int(plan.get("tease_coin_count", 0)),
		"gold_tease_reels": _read_array(plan.get("tease_reels", [])),
		"gold_tease_window_active": bool(surface_state.get("slot_nudge_tease_window_active", false)),
		"buffalo_unintentional_gold_visible": _buffalo_unintentional_gold_visible(surface_state, time_msec, reel_motion),
		"win_cells_highlighted": win_cells.size(),
		"win_line_drawn": win_cells.size() >= 2 and win_kind == "line",
		"win_reason_text": str(surface_state.get("slot_win_reason", "")),
		"celebration_tier": tier,
		"celebration_overlay_visible": result_reveal_ready and tier != "none" and tier != "tease",
		"result_reveal_ready": result_reveal_ready,
		"result_strip_message": str(strip_payload.get("message", "")),
		"result_strip_amount_text": str(strip_payload.get("amount_text", "")),
		"reel_text_overlay_visible": false,
		"count_up_active": count_up_active,
		"particle_count": particle_count,
		"shake_active": _shake_active(tier, time_msec, plan),
		"color_cycle_active": _color_cycle_active(tier, time_msec, plan),
		"color_cycle_phase": _color_cycle_phase(tier, time_msec, plan),
		"color_cycle_hue": _color_cycle_hue(tier, time_msec, plan),
		"border_color_phase": _color_cycle_phase(tier, time_msec, plan),
		"feature": feature_hash,
		"reel_rect": JSON.stringify(skin.get("reel_window", {})),
		"playfield_rect": JSON.stringify(skin.get("playfield_rect", {})),
		"pinball_takeover_active": _pinball_takeover_active(surface_state),
		"reels_suppressed": _pinball_takeover_active(surface_state),
		"status_panel_suppressed": _pinball_takeover_active(surface_state),
		"result_strip_suppressed": _pinball_takeover_active(surface_state),
		"default_controls_suppressed": _pinball_takeover_active(surface_state),
		"pinball_takeover_rect": JSON.stringify(_rect_payload(_pinball_takeover_rect())),
	}
	var pinball_manifest: Dictionary = _pinball_feature_manifest(surface_state, time_msec, mode)
	for key_value in pinball_manifest.keys():
		signature[key_value] = pinball_manifest[key_value]
	var buffalo_manifest: Dictionary = _buffalo_feature_manifest(surface_state, time_msec, mode)
	for key_value in buffalo_manifest.keys():
		signature[key_value] = buffalo_manifest[key_value]
	var buffalo_board_manifest: Dictionary = _buffalo_main_board_manifest(surface_state, time_msec)
	for key_value in buffalo_board_manifest.keys():
		signature[key_value] = buffalo_board_manifest[key_value]
	return signature


func draw(surface, surface_state: Dictionary, definition: Dictionary) -> bool:
	if str(surface_state.get("surface_renderer", "")) != "slot_machine":
		return false
	surface.surface_begin_design_space_inset(DESIGN_SIZE, Vector2.ZERO)
	var skin: Dictionary = _copy_dict(surface_state.get("slot_skin", {}))
	var palette: Dictionary = _copy_dict(skin.get("palette", {}))
	var primary := Color(str(palette.get("primary", "#24112f")))
	var secondary := Color(str(palette.get("secondary", "#090b13")))
	var accent := Color(str(palette.get("accent", "#ff4fb3")))
	var light := Color(str(palette.get("light", "#35e0ff")))
	var trim := Color(str(palette.get("trim", "#f7c845")))
	var glass := Color(str(palette.get("glass", "#9bd5ff")))
	var shadow := Color(str(palette.get("shadow", "#020308")))
	var elapsed_msec := int(round(surface.surface_elapsed("slot_spin") * 1000.0))
	if elapsed_msec <= 0 or elapsed_msec > 900000:
		elapsed_msec = int(surface_state.get("slot_visual_time_msec", 0))
	var feature_elapsed_msec := int(round(surface.surface_elapsed("slot_feature") * 1000.0))
	if feature_elapsed_msec <= 0 or feature_elapsed_msec > 900000:
		feature_elapsed_msec = int(surface_state.get("slot_visual_time_msec", 0))
	var signature: Dictionary = render_signature(surface_state, definition, elapsed_msec)
	var pinball_takeover := _pinball_takeover_active(surface_state)
	surface.draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), shadow)
	_draw_floor(surface, secondary, trim, int(signature.get("time_bucket", 0)))
	_draw_cabinet(surface, skin, primary, secondary, accent, light, trim, glass, int(signature.get("time_bucket", 0)))
	_draw_topper(surface, surface_state, skin, accent, light, trim, int(signature.get("time_bucket", 0)))
	if pinball_takeover:
		_draw_pinball_takeover(surface, surface_state, skin, accent, light, trim, int(signature.get("time_bucket", 0)), feature_elapsed_msec)
		_draw_pinball_takeover_controls(surface, surface_state, accent, light, trim)
		_draw_back_control(surface, accent, light)
		return true
	else:
		_draw_reels(surface, surface_state, definition, skin, accent, light, glass, signature, elapsed_msec)
		_draw_feature_area(surface, surface_state, definition, skin, accent, light, trim, glass, int(signature.get("time_bucket", 0)), feature_elapsed_msec, elapsed_msec)
	_draw_status_panel(surface, surface_state, skin, accent, light, trim)
	_draw_result_strip(surface, surface_state, skin, accent, light, elapsed_msec)
	_draw_celebration_overlay(surface, surface_state, skin, signature, accent, light, trim)
	_draw_controls(surface, surface_state, skin, accent, light, trim)
	_draw_back_control(surface, accent, light)
	return true


func _reel_motion(entry: Dictionary, time_msec: int) -> Dictionary:
	var t := float(maxi(0, time_msec)) / 1000.0
	var reel_index := int(entry.get("reel", 0))
	var spin_up_end := maxf(0.01, float(entry.get("spin_up_end", 0.16)))
	var decel_start := maxf(spin_up_end, float(entry.get("decel_start", spin_up_end + 0.2)))
	var stop_time := maxf(decel_start + 0.01, float(entry.get("stop_time", decel_start + 0.3)))
	var settle_end := maxf(stop_time + 0.01, float(entry.get("settle_end", stop_time + 0.2)))
	var tease := bool(entry.get("tease", false))
	var rate := 15.0 + float(reel_index % 2) * 2.0
	var phase := "settled"
	var scroll_cells := 0.0
	var blur := 0.0
	var bounce := 0.0
	if t < spin_up_end:
		var progress := clampf(t / spin_up_end, 0.0, 1.0)
		phase = "spin_up"
		scroll_cells = (2.0 + rate * t) * progress * progress
		blur = 0.18 + 0.52 * progress
	elif t < decel_start:
		phase = "spin"
		scroll_cells = rate * t + float(reel_index) * 1.65
		blur = 0.74
	elif t < stop_time:
		var decel_progress := clampf((t - decel_start) / maxf(0.01, stop_time - decel_start), 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - decel_progress, 3.0)
		var remaining := (1.0 - eased) * (6.0 + float(reel_index) * 0.55)
		if tease:
			phase = "tease_slow_roll"
			scroll_cells = remaining * 0.38 + 0.78 + sin(decel_progress * TAU * 1.5) * 0.10
			blur = 0.28
		else:
			phase = "decel"
			scroll_cells = remaining
			blur = 0.46 * (1.0 - decel_progress)
	elif t < settle_end:
		var settle_progress := clampf((t - stop_time) / maxf(0.01, settle_end - stop_time), 0.0, 1.0)
		phase = "settle"
		bounce = sin(settle_progress * PI) * (1.0 - settle_progress) * 0.24
		scroll_cells = -bounce
		blur = 0.05
	return {
		"reel": reel_index,
		"phase": phase,
		"scroll_cells": scroll_cells,
		"blur": blur,
		"bounce": bounce,
		"tease": tease,
	}


func _count_up_active(plan: Dictionary, time_msec: int, tier: String) -> bool:
	if tier == "none" or tier == "tease":
		return false
	var start_msec := int(plan.get("count_up_start_msec", 0))
	var end_msec := int(plan.get("count_up_end_msec", 0))
	return time_msec >= start_msec and time_msec <= end_msec and end_msec > start_msec


func _particle_count_for_tier(tier: String, time_msec: int, plan: Dictionary) -> int:
	if tier == "none" or tier == "tease":
		return 0
	var start_msec := int(plan.get("celebration_start_msec", 0))
	var duration_msec := maxi(1, int(plan.get("celebration_duration_msec", 0)))
	if time_msec < start_msec or time_msec > start_msec + duration_msec:
		return 0
	match tier:
		"jackpot":
			return 96
		"mega":
			return 64
		"big":
			return 42
		"feature":
			return 28
		"line":
			return 18
		_:
			return 0


func _shake_active(tier: String, time_msec: int, plan: Dictionary) -> bool:
	if tier != "big" and tier != "mega" and tier != "jackpot":
		return false
	var start_msec := int(plan.get("celebration_start_msec", 0))
	var duration_msec := maxi(1, int(plan.get("celebration_duration_msec", 0)))
	return time_msec >= start_msec and time_msec <= start_msec + duration_msec


func _shake_offset(tier: String, time_msec: int, plan: Dictionary) -> Vector2:
	if not _shake_active(tier, time_msec, plan):
		return Vector2.ZERO
	var start_msec := int(plan.get("celebration_start_msec", 0))
	var duration_msec := maxi(1, int(plan.get("celebration_duration_msec", 0)))
	var progress := clampf(float(time_msec - start_msec) / float(duration_msec), 0.0, 1.0)
	var amplitude := 4.0
	match tier:
		"jackpot":
			amplitude = 9.0
		"mega":
			amplitude = 6.5
		"big":
			amplitude = 4.5
	var eased := amplitude * (1.0 - (progress * progress * 0.72))
	var t := float(time_msec - start_msec)
	return Vector2(sin(t * 0.071) * eased, cos(t * 0.053) * eased * 0.68)


# Big-win and jackpot celebrations cycle their border colour for the full count-up so
# the high-tier moment reads as a sustained, animated flourish (build spec section 9.4).
# The phase is derived only from time, never RNG, so the manifest stays inspectable and
# the render call advances no game state.
const CELEBRATION_COLOR_CYCLE_MSEC := 640


func _color_cycle_active(tier: String, time_msec: int, plan: Dictionary) -> bool:
	if tier != "big" and tier != "mega" and tier != "jackpot":
		return false
	var start_msec := int(plan.get("celebration_start_msec", 0))
	var duration_msec := maxi(1, int(plan.get("celebration_duration_msec", 0)))
	return time_msec >= start_msec and time_msec <= start_msec + duration_msec


func _color_cycle_phase(tier: String, time_msec: int, plan: Dictionary) -> float:
	if not _color_cycle_active(tier, time_msec, plan):
		return -1.0
	return fposmod(float(time_msec) / float(CELEBRATION_COLOR_CYCLE_MSEC), 1.0)


func _color_cycle_hue(tier: String, time_msec: int, plan: Dictionary) -> float:
	var phase := _color_cycle_phase(tier, time_msec, plan)
	if phase < 0.0:
		return -1.0
	var base := 0.12
	match tier:
		"jackpot":
			base = 0.10
		"mega":
			base = 0.56
		"big":
			base = 0.91
	return fposmod(base + phase * 0.22, 1.0)


func _draw_floor(surface, secondary: Color, trim: Color, bucket: int) -> void:
	surface.draw_rect(Rect2(0, 0, 960, 540), Color(secondary.r, secondary.g, secondary.b, 0.94))
	for i in range(12):
		var y := 468.0 + float(i) * 9.0
		var alpha := 0.05 + 0.02 * float((bucket + i) % 4)
		surface.draw_line(Vector2(0, y), Vector2(960, y + 24), Color(trim.r, trim.g, trim.b, alpha), 1)


func _draw_cabinet(surface, skin: Dictionary, primary: Color, secondary: Color, accent: Color, light: Color, trim: Color, glass: Color, bucket: int) -> void:
	var body := _rect_from_dict(_copy_dict(skin.get("silhouette", {"x": 26, "y": 16, "w": 908, "h": 500})))
	surface.draw_rect(body.grow(10), Color(0.0, 0.0, 0.0, 0.52))
	surface.draw_rect(body, primary)
	surface.draw_rect(body.grow(-8), secondary)
	var lean := float(_copy_dict(skin.get("silhouette", {})).get("lean", 0.0))
	if absf(lean) > 0.1:
		surface.draw_rect(body.grow(-18), Color(primary.r, primary.g, primary.b, 0.18), false, 4)
	for i in range(18):
		var x := body.position.x + 18.0 + float(i) * (body.size.x - 36.0) / 17.0
		var chase := 0.18 + (0.18 if posmod(bucket + i, 6) == 0 else 0.0)
		surface.draw_circle(Vector2(x, body.position.y + 14), 5.0, Color(light.r, light.g, light.b, chase))
		surface.draw_circle(Vector2(x, body.position.y + body.size.y - 12), 4.5, Color(accent.r, accent.g, accent.b, chase))
	var left_leg := Rect2(body.position.x + 72, body.end.y - 4, 26, 28)
	var right_leg := Rect2(body.end.x - 98, body.end.y - 4, 26, 28)
	surface.draw_rect(left_leg, Color(trim.r, trim.g, trim.b, 0.55))
	surface.draw_rect(right_leg, Color(trim.r, trim.g, trim.b, 0.55))
	var tray := Rect2(body.position.x + body.size.x * 0.5 - 96, body.end.y - 20, 192, 14)
	surface.draw_rect(tray, Color(0.0, 0.0, 0.0, 0.42))
	surface.draw_rect(tray, Color(glass.r, glass.g, glass.b, 0.14), false, 1)


func _draw_topper(surface, state: Dictionary, skin: Dictionary, accent: Color, light: Color, trim: Color, bucket: int) -> void:
	var rect := _rect_from_dict(skin.get("topper_rect", {}))
	var style := str(skin.get("topper_style", ""))
	surface.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.46))
	surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.24), false, 2)
	if style == "brass_buffalo_head":
		var center := rect.position + rect.size * 0.5
		var reaction: String = _buffalo_topper_reaction(state)
		var head_drop := 8.0 if reaction == "snort" else 3.0 + float(bucket % 4)
		surface.draw_circle(center + Vector2(0, head_drop), rect.size.y * 0.28, trim)
		surface.draw_circle(center + Vector2(-36, head_drop - 4), 13, accent)
		surface.draw_circle(center + Vector2(36, head_drop - 4), 13, accent)
		surface.draw_line(center + Vector2(-18, head_drop + 8), center + Vector2(-46, head_drop + 18), Color("#f8fafc"), 3)
		surface.draw_line(center + Vector2(18, head_drop + 8), center + Vector2(46, head_drop + 18), Color("#f8fafc"), 3)
		if reaction == "snort":
			for puff in range(4):
				var puff_center := center + Vector2(-18 + float(puff) * 12.0, -4 - float((bucket + puff) % 5) * 2.0)
				surface.draw_circle(puff_center, 4.0 + float(puff % 2), Color(0.9, 0.9, 0.82, 0.24))
	elif style == "jackpot_ladder_wheel":
		var center := rect.position + Vector2(rect.size.x - 94, rect.size.y * 0.5)
		for i in range(10):
			var angle := float(i) * TAU / 10.0 + float(bucket) * 0.08
			surface.draw_line(center, center + Vector2(cos(angle), sin(angle)) * 28.0, light, 2)
		surface.draw_circle(center, 32, Color(trim.r, trim.g, trim.b, 0.20), false, 2)
		_draw_buffalo_ladder(surface, Rect2(rect.position + Vector2(14, 8), Vector2(300, rect.size.y - 16)), _copy_dict(_copy_dict(state.get("slot_active_bonus", {})).get("jackpot_ladder", {})), accent, light, trim, bucket)
	elif style == "day_dusk_backbox":
		var phase_alpha := _buffalo_sunset_shift(state, bucket)
		surface.draw_rect(rect.grow(-6), Color("#ef6a24").lerp(Color("#1f153d"), phase_alpha))
		for herd in range(7):
			var x := rect.position.x + fposmod(float(bucket * 9 + herd * 83), rect.size.x)
			var y := rect.position.y + rect.size.y * (0.50 + 0.12 * float(herd % 2))
			_draw_buffalo_silhouette(surface, Vector2(x, y), 0.55, Color(0.0, 0.0, 0.0, 0.28 + phase_alpha * 0.20))
	elif style == "rgb_lcd_crown":
		for i in range(9):
			var x := rect.position.x + 18.0 + float(i) * 92.0
			var alpha := 0.12 + 0.18 * float(posmod(bucket + i, 5) == 0)
			surface.draw_rect(Rect2(x, rect.position.y + 8, 44, rect.size.y - 16), Color(light.r, accent.g, accent.b, alpha))
	elif style == "orange_dmd":
		for x in range(18):
			for y in range(3):
				var lit := posmod(bucket + x + y, 5) == 0
				surface.draw_circle(rect.position + Vector2(18 + x * 8, 16 + y * 10), 2.0, Color(trim.r, trim.g, trim.b, 0.72 if lit else 0.18))
	else:
		for i in range(12):
			var alpha := 0.20 + 0.18 * float(posmod(bucket + i, 4) == 0)
			surface.draw_circle(rect.position + Vector2(24 + i * (rect.size.x - 48.0) / 11.0, rect.size.y * 0.5), 5.0, Color(light.r, light.g, light.b, alpha))
	var grand_prize := int(state.get("slot_buffalo_grand_prize", 0))
	if str(state.get("slot_type_id", "")) == "buffalo" and grand_prize > 0:
		var grand_rect := Rect2(rect.position + Vector2(rect.size.x * 0.34, 5), Vector2(rect.size.x * 0.32, 28))
		surface.draw_rect(grand_rect, Color(trim.r, trim.g, trim.b, 0.70))
		surface.draw_rect(grand_rect, Color(light.r, light.g, light.b, 0.56), false, 2)
		surface.surface_label_centered("GRAND $%d" % grand_prize, grand_rect.grow(-3), 13, Color("#130907"))
	surface.surface_label(str(skin.get("cabinet_title", "")).to_upper(), rect.position + Vector2(18, rect.size.y * 0.62), 20, light)
	surface.surface_label(str(skin.get("feature_name", "")).to_upper().left(24), rect.position + Vector2(rect.size.x - 300, rect.size.y * 0.62), 14, trim)


func _draw_reels(surface, state: Dictionary, definition: Dictionary, skin: Dictionary, accent: Color, light: Color, glass: Color, signature: Dictionary, time_msec: int) -> void:
	var rect := _rect_from_dict(skin.get("reel_window", {}))
	var grid: Array = _copy_array(state.get("slot_grid", []))
	var strips: Array = _copy_array(state.get("slot_reel_strips", []))
	var stops: Array = _copy_array(state.get("slot_reel_stops", []))
	var reel_count := maxi(1, int(state.get("slot_reel_count", 3)))
	var row_count := maxi(1, int(state.get("slot_row_count", 1)))
	surface.draw_rect(rect.grow(12), Color(0.0, 0.0, 0.0, 0.52))
	surface.draw_rect(rect, Color("#05070f"))
	surface.draw_rect(rect, Color(glass.r, glass.g, glass.b, 0.35), false, 2)
	var gap := 6.0
	var cell_w := (rect.size.x - gap * float(reel_count + 1)) / float(reel_count)
	var cell_h := (rect.size.y - gap * float(row_count + 1)) / float(row_count)
	var family := str(state.get("slot_type_id", "pinball"))
	var motions: Array = _copy_array(signature.get("reel_motion", []))
	var win_cells: Array = _copy_array(state.get("slot_win_cells", []))
	var win_lookup: Dictionary = _win_cell_lookup(win_cells)
	var show_wins := win_cells.size() > 0 and _all_reels_landed(motions) and _result_reveal_ready(state, time_msec)
	var win_centers: Dictionary = {}
	for reel_index in range(reel_count):
		var motion: Dictionary = _copy_dict(motions[reel_index]) if reel_index < motions.size() else {"phase": "settled", "scroll_cells": 0.0, "blur": 0.0}
		var phase := str(motion.get("phase", "settled"))
		var scroll_cells := float(motion.get("scroll_cells", 0.0))
		var blur := float(motion.get("blur", 0.0))
		var fractional: float = scroll_cells - floor(scroll_cells)
		var whole_offset := int(floor(scroll_cells))
		if phase == "settled":
			fractional = 0.0
			whole_offset = 0
		var reel_x := rect.position.x + gap + float(reel_index) * (cell_w + gap)
		if bool(motion.get("tease", false)) and phase == "tease_slow_roll":
			var reel_glow := Rect2(reel_x - 4, rect.position.y + 4, cell_w + 8, rect.size.y - 8)
			surface.draw_rect(reel_glow, Color(accent.r, accent.g, accent.b, 0.26), false, 4)
		for visual_row in range(-1, row_count + 2):
			var y: float = rect.position.y + gap + (float(visual_row) - fractional) * (cell_h + gap)
			var cell := Rect2(Vector2(reel_x, y), Vector2(cell_w, cell_h))
			var visible_cell: Rect2 = _rect_intersection(cell, rect)
			if visible_cell.size.x <= 0.0 or visible_cell.size.y <= 0.0:
				continue
			var landing_slot := phase == "decel" or phase == "tease_slow_roll" or phase == "settle" or phase == "settled"
			var source_row := visual_row + whole_offset
			var symbol := _visible_symbol(strips, stops, grid, reel_index, source_row, row_count, landing_slot)
			symbol = _buffalo_display_symbol(family, symbol, grid, reel_index, source_row, landing_slot, time_msec)
			_draw_symbol(surface, definition, family, symbol, visible_cell, blur > 0.12)
			if family == "buffalo" and symbol == "GOLD_TOKEN" and (bool(motion.get("tease", false)) or bool(signature.get("gold_tease_active", false))):
				var coin_pulse := 0.48 + 0.24 * sin(float(time_msec) * 0.018 + float(reel_index))
				surface.draw_rect(_rect_intersection(visible_cell.grow(5), rect), Color("#ffd35a", coin_pulse), false, 4)
				surface.draw_rect(_rect_intersection(visible_cell.grow(11), rect), Color(accent.r, accent.g, accent.b, 0.24), false, 2)
			if blur > 0.38:
				surface.draw_rect(_rect_intersection(visible_cell.grow(-4), rect), Color(light.r, light.g, light.b, minf(0.18, blur * 0.22)))
			var settled_slot := phase == "settle" or phase == "settled"
			if visual_row >= 0 and visual_row < row_count and settled_slot:
				var key := _cell_key(reel_index, visual_row)
				win_centers[key] = visible_cell.position + visible_cell.size * 0.5
				if show_wins:
					if bool(win_lookup.get(key, false)):
						var pulse := 0.45 + 0.20 * sin(float(time_msec) * 0.010)
						surface.draw_rect(_rect_intersection(visible_cell.grow(4), rect), Color(light.r, light.g, light.b, pulse), false, 3)
						surface.draw_rect(_rect_intersection(visible_cell.grow(8), rect), Color(accent.r, accent.g, accent.b, 0.22), false, 2)
					else:
						surface.draw_rect(visible_cell, Color(0.0, 0.0, 0.0, 0.36))
	surface.draw_line(rect.position + Vector2(12, 10), rect.position + Vector2(rect.size.x - 16, 0), Color(1.0, 1.0, 1.0, 0.24), 3)
	if bool(signature.get("win_line_drawn", false)) and show_wins:
		var points: Array = []
		for cell_value in win_cells:
			var win_cell: Dictionary = _copy_dict(cell_value)
			var center_key := _cell_key(int(win_cell.get("reel", 0)), int(win_cell.get("row", 0)))
			if win_centers.has(center_key):
				points.append(win_centers[center_key])
		for point_index in range(maxi(0, points.size() - 1)):
			surface.draw_line(points[point_index], points[point_index + 1], Color(light.r, light.g, light.b, 0.92), 4)
			surface.draw_line(points[point_index], points[point_index + 1], Color(accent.r, accent.g, accent.b, 0.48), 8)
	_draw_buffalo_main_board_overlay(surface, state, definition, rect, reel_count, row_count, gap, cell_w, cell_h, time_msec, accent, light, glass)
	if bool(signature.get("tease_overlay_visible", false)):
		surface.draw_rect(rect.grow(15), Color(accent.r, accent.g, accent.b, 0.44), false, 4)


func _buffalo_main_board_manifest(surface_state: Dictionary, time_msec: int) -> Dictionary:
	var active: Dictionary = _read_dict(surface_state.get("slot_active_bonus", {}))
	if str(active.get("family", surface_state.get("slot_type_id", ""))) != "buffalo":
		return {}
	if active.is_empty() or not bool(surface_state.get("slot_active_bonus_active", false)):
		return {}
	var payload: Dictionary = _buffalo_main_board_payload(surface_state, time_msec)
	var scene: Dictionary = _read_dict(surface_state.get("slot_feature_scene", {}))
	var music: Dictionary = _read_dict(scene.get("feature_music", {}))
	return {
		"buffalo_feature_music_id": str(music.get("cue_id", "")),
		"buffalo_main_board_coin_value_count": int(payload.get("value_count", 0)),
		"buffalo_main_board_coin_values_visible": int(payload.get("value_count", 0)) > 0,
		"buffalo_main_board_cell_capacity": int(payload.get("cell_capacity", 0)),
		"buffalo_main_board_unlocked_cell_count": int(payload.get("unlocked_cell_count", 0)),
		"buffalo_main_board_visible_lock_count": int(payload.get("visible_lock_count", 0)),
		"buffalo_main_board_pending_lock_count": int(payload.get("pending_lock_count", 0)),
		"buffalo_main_board_recent_lock_count": int(payload.get("recent_lock_count", 0)),
		"buffalo_coin_bump_active": bool(payload.get("bump_active", false)),
		"buffalo_unlocked_spin_active": bool(payload.get("unlocked_spin_active", false)),
	}


func _draw_buffalo_main_board_overlay(surface, state: Dictionary, definition: Dictionary, reel_rect: Rect2, reel_count: int, row_count: int, gap: float, cell_w: float, cell_h: float, time_msec: int, accent: Color, light: Color, glass: Color) -> void:
	var active: Dictionary = _copy_dict(state.get("slot_active_bonus", {}))
	if str(active.get("family", state.get("slot_type_id", ""))) != "buffalo":
		return
	if active.is_empty() or not bool(state.get("slot_active_bonus_active", false)):
		return
	var payload: Dictionary = _buffalo_main_board_payload(state, time_msec)
	var coins: Array = _copy_array(payload.get("coins", []))
	var coin_lookup: Dictionary = {}
	for coin_value in coins:
		var coin: Dictionary = _copy_dict(coin_value)
		coin_lookup[_cell_key(int(coin.get("reel", -1)), int(coin.get("row", -1)))] = true
	if bool(payload.get("unlocked_spin_active", false)):
		for reel_index in range(reel_count):
			for row_index in range(row_count):
				var key := _cell_key(reel_index, row_index)
				if bool(coin_lookup.get(key, false)):
					continue
				var cell_rect := _main_reel_cell_rect(reel_rect, reel_index, row_index, gap, cell_w, cell_h)
				var spin_symbol := _buffalo_feature_spin_symbol(reel_index, row_index, time_msec)
				_draw_symbol(surface, definition, "buffalo", spin_symbol, cell_rect.grow(-5), true)
				var shimmer := 0.10 + 0.06 * sin(float(time_msec + reel_index * 91 + row_index * 37) * 0.014)
				surface.draw_rect(cell_rect.grow(-3), Color(light.r, light.g, light.b, shimmer))
				var sweep_y := cell_rect.position.y + fposmod(float(time_msec) * 0.11 + float(reel_index * 17 + row_index * 9), maxf(1.0, cell_rect.size.y))
				surface.draw_line(Vector2(cell_rect.position.x + 6, sweep_y), Vector2(cell_rect.end.x - 6, sweep_y - 10), Color(glass.r, glass.g, glass.b, 0.28), 2)
	for coin_value in coins:
		var coin: Dictionary = _copy_dict(coin_value)
		var reel := int(coin.get("reel", -1))
		var row := int(coin.get("row", -1))
		if reel < 0 or reel >= reel_count or row < 0 or row >= row_count:
			continue
		var cell_rect := _main_reel_cell_rect(reel_rect, reel, row, gap, cell_w, cell_h)
		var revealed := bool(coin.get("revealed", true))
		var slam := bool(coin.get("recent", false)) or bool(coin.get("just_revealed", false))
		_draw_buffalo_coin_cell(surface, cell_rect.grow(-2), coin, true, slam, accent, light, Color("#f5bd35"), revealed)


func _buffalo_main_board_payload(state: Dictionary, time_msec: int) -> Dictionary:
	var active: Dictionary = _read_dict(state.get("slot_active_bonus", {}))
	var mode := str(active.get("mode", ""))
	var reel_count := maxi(1, int(active.get("reel_count", state.get("slot_reel_count", 3))))
	var row_count := maxi(1, int(active.get("row_count", state.get("slot_row_count", 1))))
	var coins: Array = []
	var recent_lookup: Dictionary = {}
	var pending_lock_count := 0
	var recent_lock_count := 0
	if mode == "hold_and_spin":
		for lock_value in _read_array(active.get("last_lock_events", [])):
			var lock_recent: Dictionary = _read_dict(lock_value)
			var recent_cell: Dictionary = _buffalo_lock_cell(lock_recent, row_count)
			recent_lookup[_cell_key(int(recent_cell.get("reel", -1)), int(recent_cell.get("row", -1)))] = true
		for lock_value in _read_array(active.get("locks", [])):
			var lock: Dictionary = _read_dict(lock_value)
			var lock_cell: Dictionary = _buffalo_lock_cell(lock, row_count)
			var reel := int(lock_cell.get("reel", -1))
			var row := int(lock_cell.get("row", -1))
			if reel < 0 or reel >= reel_count or row < 0 or row >= row_count:
				continue
			if not _buffalo_lock_revealed(lock, time_msec):
				pending_lock_count += 1
				continue
			var lock_payload := lock.duplicate(true)
			lock_payload["reel"] = reel
			lock_payload["row"] = row
			lock_payload["symbol"] = str(lock_payload.get("symbol", "GOLD_TOKEN"))
			lock_payload["revealed"] = true
			lock_payload["just_revealed"] = _buffalo_lock_just_revealed(lock, time_msec)
			lock_payload["recent"] = bool(recent_lookup.get(_cell_key(reel, row), false))
			if bool(lock_payload.get("recent", false)) or bool(lock_payload.get("just_revealed", false)):
				recent_lock_count += 1
			coins.append(lock_payload)
	else:
		for coin_value in _read_array(active.get("last_collected_coins", [])):
			var recent_coin: Dictionary = _read_dict(coin_value)
			recent_lookup[_cell_key(int(recent_coin.get("reel", -1)), int(recent_coin.get("row", -1)))] = true
		var reveal_lookup: Dictionary = _buffalo_coin_reveal_lookup(active, time_msec)
		var coin_source: Array = _read_array(active.get("collected_coins", []))
		if coin_source.is_empty() and not reveal_lookup.is_empty():
			for reveal_key in reveal_lookup.keys():
				coin_source.append(_read_dict(reveal_lookup.get(reveal_key, {})))
		for coin_value in coin_source:
			var coin: Dictionary = _read_dict(coin_value)
			var reel := int(coin.get("reel", -1))
			var row := int(coin.get("row", -1))
			if reel < 0 or reel >= reel_count or row < 0 or row >= row_count:
				continue
			var key := _cell_key(reel, row)
			var reveal: Dictionary = _read_dict(reveal_lookup.get(key, {}))
			if not reveal.is_empty():
				coin = reveal
			coin["symbol"] = "GOLD_TOKEN"
			coin["recent"] = bool(recent_lookup.get(key, false))
			coins.append(coin)
	var value_count := 0
	var bump_active := false
	for coin_value in coins:
		var coin: Dictionary = _read_dict(coin_value)
		if int(coin.get("value", 0)) > 0 and bool(coin.get("revealed", true)):
			value_count += 1
		if bool(coin.get("recent", false)) or bool(coin.get("just_revealed", false)):
			bump_active = true
	var mode_has_respin := mode == "hold_and_spin" or mode == "free_games"
	var cell_capacity := reel_count * row_count
	var unlocked_cell_count := maxi(0, cell_capacity - coins.size())
	var unlocked_spin_active := mode_has_respin and _buffalo_stampede_phase(time_msec, active) != "celebration" and unlocked_cell_count > 0
	return {
		"coins": coins,
		"value_count": value_count,
		"cell_capacity": cell_capacity,
		"unlocked_cell_count": unlocked_cell_count,
		"visible_lock_count": coins.size(),
		"pending_lock_count": pending_lock_count,
		"recent_lock_count": recent_lock_count,
		"bump_active": bump_active,
		"unlocked_spin_active": unlocked_spin_active,
	}


func _buffalo_feature_spin_symbol(reel_index: int, row_index: int, time_msec: int) -> String:
	var cycle: Array = ["BUFFALO", "EAGLE", "WOLF", "HORSE", "ELK", "SUNSET", "A", "K", "Q", "J", "10"]
	var strip_offset := reel_index * 3 + row_index
	var step := posmod((time_msec / 72) + strip_offset, cycle.size())
	return str(cycle[step])


func _buffalo_display_symbol(family: String, symbol: String, grid: Array, reel_index: int, row_index: int, landing_slot: bool, time_msec: int) -> String:
	if family != "buffalo" or symbol != "GOLD_TOKEN":
		return symbol
	if _buffalo_gold_symbol_is_intentional(grid, reel_index, row_index, landing_slot):
		return symbol
	return _buffalo_feature_spin_symbol(reel_index, row_index, time_msec)


func _buffalo_gold_symbol_is_intentional(grid: Array, reel_index: int, row_index: int, landing_slot: bool) -> bool:
	if not landing_slot:
		return false
	if reel_index < 0 or reel_index >= grid.size() or typeof(grid[reel_index]) != TYPE_ARRAY:
		return false
	var column: Array = grid[reel_index] as Array
	if row_index < 0 or row_index >= column.size():
		return false
	return str(column[row_index]) == "GOLD_TOKEN"


func _buffalo_unintentional_gold_visible(surface_state: Dictionary, time_msec: int, motions: Array) -> bool:
	if str(surface_state.get("slot_type_id", "")) != "buffalo":
		return false
	var grid: Array = _read_array(surface_state.get("slot_grid", []))
	var strips: Array = _read_array(surface_state.get("slot_reel_strips", []))
	var stops: Array = _read_array(surface_state.get("slot_reel_stops", []))
	var reel_count := maxi(1, int(surface_state.get("slot_reel_count", 3)))
	var row_count := maxi(1, int(surface_state.get("slot_row_count", 1)))
	for reel_index in range(reel_count):
		var motion: Dictionary = _read_dict(motions[reel_index]) if reel_index < motions.size() else {"phase": "settled", "scroll_cells": 0.0}
		var phase := str(motion.get("phase", "settled"))
		var scroll_cells := float(motion.get("scroll_cells", 0.0))
		var whole_offset := int(floor(scroll_cells))
		if phase == "settled":
			whole_offset = 0
		var landing_slot := phase == "decel" or phase == "tease_slow_roll" or phase == "settle" or phase == "settled"
		for visual_row in range(-1, row_count + 2):
			var source_row := visual_row + whole_offset
			var raw_symbol := _visible_symbol(strips, stops, grid, reel_index, source_row, row_count, landing_slot)
			var display_symbol := _buffalo_display_symbol("buffalo", raw_symbol, grid, reel_index, source_row, landing_slot, time_msec)
			if display_symbol == "GOLD_TOKEN" and not _buffalo_gold_symbol_is_intentional(grid, reel_index, source_row, landing_slot):
				return true
	return false


func _buffalo_lock_cell(lock: Dictionary, row_count: int) -> Dictionary:
	if lock.has("reel") and lock.has("row"):
		return {"reel": int(lock.get("reel", -1)), "row": int(lock.get("row", -1))}
	var cell := maxi(0, int(lock.get("cell", 0)))
	var safe_rows := maxi(1, row_count)
	return {"reel": int(cell / safe_rows), "row": cell % safe_rows}


func _buffalo_lock_revealed(lock: Dictionary, time_msec: int) -> bool:
	return time_msec >= int(lock.get("reveal_start_msec", 0))


func _buffalo_lock_just_revealed(lock: Dictionary, time_msec: int) -> bool:
	var start_msec := int(lock.get("reveal_start_msec", 0))
	if start_msec <= 0:
		return false
	var duration_msec := maxi(1, int(lock.get("reveal_duration_msec", 360)))
	return time_msec >= start_msec and time_msec <= start_msec + duration_msec


func _main_reel_cell_rect(rect: Rect2, reel: int, row: int, gap: float, cell_w: float, cell_h: float) -> Rect2:
	var x := rect.position.x + gap + float(reel) * (cell_w + gap)
	var y := rect.position.y + gap + float(row) * (cell_h + gap)
	return Rect2(Vector2(x, y), Vector2(cell_w, cell_h))


func _draw_symbol(surface, definition: Dictionary, family: String, symbol: String, rect: Rect2, blurred: bool) -> void:
	var meta: Dictionary = catalog.symbol_metadata(definition, family, symbol)
	var colors: Array = _copy_array(meta.get("colors", []))
	var primary := Color(str(colors[0] if colors.size() > 0 else "#1b2230"))
	var secondary := Color(str(colors[1] if colors.size() > 1 else "#3f5269"))
	var glow := Color(str(colors[2] if colors.size() > 2 else colors[0] if colors.size() > 0 else "#6d88a8"))
	var alpha := 0.18 if blurred else 0.26
	surface.draw_rect(rect, Color(primary.r, primary.g, primary.b, alpha))
	surface.draw_rect(rect, Color(glow.r, glow.g, glow.b, 0.38), false, 1)
	var center := rect.position + rect.size * 0.5
	var radius := minf(rect.size.x, rect.size.y) * 0.30
	match str(meta.get("shape", "")):
		"coin", "chrome_ball", "steel_ball":
			surface.draw_circle(center, radius, primary)
			surface.draw_circle(center + Vector2(-radius * 0.35, -radius * 0.35), radius * 0.36, Color(1.0, 1.0, 1.0, 0.45))
		"buffalo_head", "animal_badge":
			surface.draw_circle(center, radius, primary)
			surface.draw_circle(center + Vector2(-radius * 0.60, -radius * 0.20), radius * 0.26, secondary)
			surface.draw_circle(center + Vector2(radius * 0.60, -radius * 0.20), radius * 0.26, secondary)
		"sunset":
			surface.draw_circle(center, radius, primary)
			surface.draw_rect(Rect2(center.x - radius, center.y, radius * 2.0, radius * 0.42), secondary)
		"cash_tile", "bar", "multiplier", "double_seven":
			surface.draw_rect(rect.grow(-6), primary)
			surface.draw_rect(rect.grow(-9), secondary, false, 2)
		"fruit":
			surface.draw_circle(center + Vector2(-radius * 0.25, radius * 0.12), radius * 0.62, primary)
			surface.draw_circle(center + Vector2(radius * 0.25, radius * 0.15), radius * 0.62, primary)
			surface.draw_line(center + Vector2(0, -radius), center + Vector2(radius * 0.45, -radius * 1.28), secondary, 2)
		"spinner":
			surface.draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), primary, 4)
			surface.draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), secondary, 4)
			surface.draw_circle(center, radius * 0.22, glow)
		"bumper":
			surface.draw_circle(center, radius, secondary)
			surface.draw_circle(center, radius * 0.70, primary)
		"seven", "card":
			surface.draw_rect(rect.grow(-7), secondary)
		_:
			surface.draw_rect(rect.grow(-5), primary)
	var label := _symbol_label(symbol)
	surface.surface_label_centered(label, rect.grow(-3), int(clampf(rect.size.y * 0.30, 8.0, 20.0)), Color("#f8fafc"))


func _visible_symbol(strips: Array, stops: Array, grid: Array, reel_index: int, row_index: int, row_count: int, landing_slot: bool) -> String:
	if landing_slot and row_index >= 0 and row_index < row_count:
		if reel_index >= 0 and reel_index < grid.size() and typeof(grid[reel_index]) == TYPE_ARRAY:
			var column: Array = grid[reel_index] as Array
			if row_index < column.size():
				return str(column[row_index])
	var strip: Array = _strip_for_reel(strips, reel_index)
	if strip.is_empty():
		return "BLANK"
	var stop := int(stops[reel_index]) if reel_index >= 0 and reel_index < stops.size() else 0
	return str(strip[posmod(stop + row_index, strip.size())])


func _strip_for_reel(strips: Array, reel_index: int) -> Array:
	if reel_index >= 0 and reel_index < strips.size() and typeof(strips[reel_index]) == TYPE_ARRAY:
		return (strips[reel_index] as Array).duplicate(true)
	return ["BLANK"]


func _win_cell_lookup(cells: Array) -> Dictionary:
	var result: Dictionary = {}
	for cell_value in cells:
		var cell: Dictionary = _copy_dict(cell_value)
		result[_cell_key(int(cell.get("reel", 0)), int(cell.get("row", 0)))] = true
	return result


func _cell_key(reel_index: int, row_index: int) -> String:
	return "%d:%d" % [reel_index, row_index]


func _all_reels_landed(motions: Array) -> bool:
	if motions.is_empty():
		return false
	for motion_value in motions:
		var motion: Dictionary = _copy_dict(motion_value)
		var phase := str(motion.get("phase", "settled"))
		if phase != "settle" and phase != "settled":
			return false
	return true


func _draw_feature_area(surface, state: Dictionary, definition: Dictionary, skin: Dictionary, accent: Color, light: Color, trim: Color, glass: Color, bucket: int, feature_msec: int, spin_msec: int) -> void:
	var rect := _rect_from_dict(skin.get("playfield_rect", skin.get("feature_panel", {})))
	var active: Dictionary = _copy_dict(state.get("slot_active_bonus", {}))
	surface.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.34))
	surface.draw_rect(rect, Color(glass.r, glass.g, glass.b, 0.18), false, 1)
	var family := str(active.get("family", state.get("slot_type_id", "pinball"))) if bool(active.get("active", false)) else str(state.get("slot_type_id", "pinball"))
	if family == "pinball":
		_draw_pinball_playfield(surface, rect, state, active, accent, light, trim, bucket, feature_msec)
	else:
		_draw_buffalo_feature(surface, rect, state, definition, active, accent, light, trim, bucket, feature_msec, spin_msec)


func _pinball_takeover_active(state: Dictionary) -> bool:
	var active: Dictionary = _read_dict(state.get("slot_active_bonus", {}))
	if active.is_empty() or not bool(active.get("active", false)):
		return false
	return str(active.get("family", state.get("slot_type_id", ""))) == "pinball"


func _pinball_takeover_rect() -> Rect2:
	return Rect2(Vector2.ZERO, DESIGN_SIZE)


func _draw_pinball_takeover(surface, state: Dictionary, _skin: Dictionary, accent: Color, light: Color, trim: Color, bucket: int, feature_msec: int) -> void:
	var active: Dictionary = _copy_dict(state.get("slot_active_bonus", {}))
	var rect := _pinball_takeover_rect()
	surface.draw_rect(rect, Color("#04080f"))
	_draw_pinball_playfield(surface, rect, state, active, accent, light, trim, bucket, feature_msec)


func _draw_pinball_takeover_controls(surface, state: Dictionary, accent: Color, light: Color, trim: Color) -> void:
	var active: Dictionary = _copy_dict(state.get("slot_active_bonus", {}))
	var panel := Rect2(60, 444, 840, 82)
	surface.draw_rect(panel, Color(0.0, 0.0, 0.0, 0.56))
	surface.draw_rect(panel, Color(light.r, light.g, light.b, 0.20), false, 1)
	var launch_live := bool(active.get("launch_in_progress", false))
	if launch_live:
		var button_y := panel.position.y + 14
		_draw_button(surface, Rect2(panel.position.x + 32, button_y, 150, 50), "LEFT FLIP", "slot_bonus_left", 0, accent)
		_draw_button(surface, Rect2(panel.position.x + 214, button_y, 150, 50), "RIGHT FLIP", "slot_bonus_right", 0, accent)
		_draw_button(surface, Rect2(panel.position.x + 396, button_y, 128, 50), "NUDGE", "slot_bonus_tilt", 0, trim)
		_draw_button(surface, Rect2(panel.position.x + 556, button_y, 132, 50), "IN PLAY", "slot_bonus_launch", 0, light)
		_draw_pinball_power_meter(surface, Rect2(panel.position.x + 718, panel.position.y + 13, 92, 52), active, light, trim)
	else:
		_draw_pinball_choice_strip(surface, Rect2(panel.position.x + 18, panel.position.y + 12, 238, 34), "START", "slot_bonus_start_", PINBALL_START_CHOICES, _pinball_start_choice_index(active), trim)
		_draw_pinball_choice_strip(surface, Rect2(panel.position.x + 276, panel.position.y + 12, 238, 34), "AIM", "slot_bonus_aim_", PINBALL_AIM_CHOICES, _pinball_aim_choice_index(active), accent)
		_draw_pinball_choice_strip(surface, Rect2(panel.position.x + 534, panel.position.y + 12, 150, 34), "POWER", "slot_bonus_power_", PINBALL_POWER_CHOICES, _pinball_power_choice_index(active), light)
		_draw_button(surface, Rect2(panel.position.x + 708, panel.position.y + 12, 114, 54), "LAUNCH", "slot_bonus_launch", 0, light)
	var remaining := maxi(0, int(active.get("balls_remaining", active.get("remaining_steps", 0))))
	var live := maxi(0, int(active.get("active_ball_count", 1 if bool(active.get("launch_in_progress", false)) else 0)))
	var angle := int(active.get("launch_angle_degrees", 0))
	var angle_label := str(angle)
	if angle > 0:
		angle_label = "+%d" % angle
	surface.surface_label_centered("BALLS %d  LIVE %d  ANGLE %s  PWR %d" % [remaining, live, angle_label, int(active.get("launch_power", 70))], Rect2(panel.position + Vector2(22, 53), Vector2(654, 18)), 10, light)


func _draw_pinball_choice_strip(surface, rect: Rect2, title: String, action_prefix: String, choice_count: int, selected_index: int, color: Color) -> void:
	var safe_count := maxi(2, choice_count)
	surface.surface_label(title, rect.position + Vector2(0, 9), 9, color)
	var strip := Rect2(rect.position + Vector2(0, 12), Vector2(rect.size.x, rect.size.y - 12))
	surface.draw_rect(strip, Color(0.0, 0.0, 0.0, 0.36))
	surface.draw_rect(strip, Color(color.r, color.g, color.b, 0.22), false, 1)
	var gap := 2.0
	var cell_w := (strip.size.x - gap * float(safe_count - 1)) / float(safe_count)
	for index in range(safe_count):
		var cell := Rect2(strip.position + Vector2(float(index) * (cell_w + gap), 0), Vector2(cell_w, strip.size.y))
		var selected := index == clampi(selected_index, 0, safe_count - 1)
		var hovered := bool(surface.surface_region_hovered("%s%02d" % [action_prefix, index], index))
		var alpha := 0.48 if selected else 0.30 if hovered else 0.12
		surface.draw_rect(cell, Color(color.r, color.g, color.b, alpha))
		surface.draw_rect(cell, Color("#f8fafc") if hovered or selected else Color(color.r, color.g, color.b, 0.46), false, 1)
		if selected:
			surface.draw_line(Vector2(cell.position.x + cell.size.x * 0.5, cell.position.y - 2), Vector2(cell.position.x + cell.size.x * 0.5, cell.end.y + 2), Color("#f8fafc"), 2)
		surface.surface_add_hit(cell, "%s%02d" % [action_prefix, index], index)


func _pinball_aim_choice_index(active: Dictionary) -> int:
	var angle := clampi(int(active.get("launch_angle_degrees", 0)), PINBALL_AIM_MIN_DEGREES, PINBALL_AIM_MAX_DEGREES)
	var ratio := clampf(float(angle - PINBALL_AIM_MIN_DEGREES) / float(PINBALL_AIM_MAX_DEGREES - PINBALL_AIM_MIN_DEGREES), 0.0, 1.0)
	return clampi(int(round(ratio * float(PINBALL_AIM_CHOICES - 1))), 0, PINBALL_AIM_CHOICES - 1)


func _pinball_start_choice_index(active: Dictionary) -> int:
	var mode := str(active.get("mode", "em_bumper_drop"))
	var start := _pinball_launch_start(active, _pinball_layout_from_active(active), str(active.get("selected_lane", "center")))
	var min_x := 0.16
	var max_x := 0.84
	if mode == "lane_multiball":
		min_x = 0.14
		max_x = 0.86
	elif mode == "video_feature":
		min_x = 0.54
		max_x = 0.94
	var ratio := clampf((start.x - min_x) / maxf(0.001, max_x - min_x), 0.0, 1.0)
	return clampi(int(round(ratio * float(PINBALL_START_CHOICES - 1))), 0, PINBALL_START_CHOICES - 1)


func _pinball_power_choice_index(active: Dictionary) -> int:
	var power := clampi(int(active.get("launch_power", 70)), 20, 100)
	var ratio := clampf(float(power - 20) / 80.0, 0.0, 1.0)
	return clampi(int(round(ratio * float(PINBALL_POWER_CHOICES - 1))), 0, PINBALL_POWER_CHOICES - 1)


func _draw_pinball_playfield(surface, rect: Rect2, state: Dictionary, active: Dictionary, accent: Color, light: Color, trim: Color, bucket: int, feature_msec: int) -> void:
	var layout: Dictionary = _pinball_layout_from_active(active)
	var play_rect: Rect2 = _pinball_camera_rect(rect.grow(-8), feature_msec)
	var playback_sec: float = _pinball_playback_time(feature_msec)
	var events: Array = _pinball_events(active)
	var recent_ids: Dictionary = _pinball_recent_event_ids(events, playback_sec, 0.24)
	var trajectory: Array = _pinball_trajectory(active)
	var positions: Array = _pinball_live_positions(active)
	if positions.is_empty():
		positions = _pinball_positions_at_time(trajectory, feature_msec)
	if positions.size() <= 1 and int(active.get("max_active_count", 0)) > 1:
		positions = _pinball_multiball_fallback_positions(feature_msec)
	var lit_state: Dictionary = _pinball_lit_state(active)
	if positions.is_empty():
		var physics: Dictionary = _copy_dict(active.get("physics", {}))
		positions.append({"ball_index": 0, "position": Vector2(clampf(float(physics.get("ball_x", 0.5)), 0.0, 1.0), clampf(float(physics.get("ball_y", 0.5)), 0.0, 1.0))})
	surface.draw_rect(play_rect, Color("#08101a"))
	surface.draw_rect(play_rect, Color(light.r, light.g, light.b, 0.18), false, 2)
	var identity := str(_copy_dict(state.get("slot_skin", {})).get("cabinet_identity", ""))
	_draw_pinball_backglass(surface, play_rect, active, identity, accent, light, trim, bucket)
	var inner: Rect2 = play_rect.grow(-14)
	var elements: Array = []
	var elements_value: Variant = layout.get("elements", [])
	if typeof(elements_value) == TYPE_ARRAY:
		elements = elements_value as Array
	for element_value in elements:
		if typeof(element_value) != TYPE_DICTIONARY:
			continue
		var element: Dictionary = element_value
		_draw_pinball_element(surface, inner, element, active, lit_state, recent_ids, accent, light, trim, bucket, playback_sec)
	_draw_pinball_launch_guideline(surface, inner, active, layout, light, trim, feature_msec)
	for position_value in positions:
		if typeof(position_value) != TYPE_DICTIONARY:
			continue
		var position_entry: Dictionary = position_value
		var ball_index := int(position_entry.get("ball_index", 0))
		_draw_pinball_ball_trail(surface, inner, trajectory, ball_index, playback_sec, light)
	for position_value in positions:
		if typeof(position_value) != TYPE_DICTIONARY:
			continue
		var position_entry: Dictionary = position_value
		var p: Vector2 = _pinball_point(inner, position_entry.get("position", Vector2(0.5, 0.5)))
		var radius := maxf(4.5, minf(inner.size.x, inner.size.y) * 0.020)
		surface.draw_circle(p + Vector2(2, 3), radius + 1.5, Color(0.0, 0.0, 0.0, 0.34))
		surface.draw_circle(p, radius, Color("#e9edf5"))
		surface.draw_circle(p + Vector2(-radius * 0.36, -radius * 0.34), radius * 0.34, Color(1.0, 1.0, 1.0, 0.70))
		surface.draw_circle(p + Vector2(radius * 0.28, radius * 0.30), radius * 0.24, Color(0.35, 0.42, 0.50, 0.36))
	var unlaunched_count := maxi(0, int(active.get("balls_remaining", 0)))
	surface.surface_label("LEFT %d  LIVE %d" % [unlaunched_count, positions.size()], play_rect.position + Vector2(12, play_rect.size.y - 10), 11, light)
	_draw_pinball_callout(surface, play_rect, active, events, playback_sec, identity, accent, light, trim)


func _pinball_feature_manifest(surface_state: Dictionary, time_msec: int, mode: String) -> Dictionary:
	var active: Dictionary = _read_dict(surface_state.get("slot_active_bonus", {}))
	var family := str(active.get("family", surface_state.get("slot_type_id", "")))
	if family != "pinball":
		return {}
	if active.is_empty() or (mode != "feature" and not bool(surface_state.get("slot_active_bonus_active", false))):
		return {}
	var layout: Dictionary = _pinball_layout_from_active(active)
	var counts: Dictionary = _pinball_geometry_counts(layout)
	var scene: Dictionary = _read_dict(surface_state.get("slot_feature_scene", {}))
	var music: Dictionary = _read_dict(scene.get("feature_music", {}))
	var meter: Dictionary = _read_dict(active.get("pinball_launch_meter", {}))
	if meter.is_empty():
		meter = _read_dict(scene.get("launch_meter", {}))
	var lane := str(active.get("selected_lane", "center"))
	var launch_start: Vector2 = _pinball_launch_start(active, layout, lane)
	var positions: Array = _pinball_positions_at_time(_pinball_trajectory(active), time_msec)
	if positions.is_empty():
		positions = _pinball_live_positions(active)
	if positions.size() <= 1 and int(active.get("max_active_count", 0)) > 1:
		positions = _pinball_multiball_fallback_positions(time_msec)
	var manifest: Dictionary = {
		"ball_count": positions.size(),
		"bumper_count": int(counts.get("bumper", 0)),
		"ramp_count": int(counts.get("ramp", 0)) + int(counts.get("orbit", 0)),
		"lit_inserts": _pinball_lit_insert_count(active),
		"dmd_active": true,
		"transition_phase": _pinball_transition_phase(time_msec),
		"pinball_layout": str(layout.get("id", active.get("mode", ""))),
		"pinball_ball_positions": _pinball_position_payloads(positions),
		"pinball_event_flash_count": _pinball_recent_event_ids(_pinball_events(active), _pinball_playback_time(time_msec), 0.24).size(),
		"pinball_feature_music_id": str(music.get("cue_id", "")),
		"pinball_guideline_active": _pinball_guideline_active(active),
		"pinball_aim_lane": lane,
		"pinball_launch_power": int(active.get("launch_power", 0)),
		"pinball_sampled_power": int(meter.get("sampled_power", active.get("launch_power", 0))),
		"pinball_power_rating": str(meter.get("rating", "")),
		"pinball_power_meter_controlled": bool(meter.get("controlled", false)),
		"pinball_launch_angle_degrees": int(active.get("launch_angle_degrees", 0)),
		"pinball_launch_start_x": snappedf(launch_start.x, 0.001),
		"pinball_launch_start_y": snappedf(launch_start.y, 0.001),
		"pinball_aim_choice_index": _pinball_aim_choice_index(active),
		"pinball_aim_choice_count": PINBALL_AIM_CHOICES,
		"pinball_start_choice_index": _pinball_start_choice_index(active),
		"pinball_start_choice_count": PINBALL_START_CHOICES,
		"pinball_power_choice_index": _pinball_power_choice_index(active),
		"pinball_power_choice_count": PINBALL_POWER_CHOICES,
		"pinball_physics_tick_budget": int(active.get("physics_tick_budget", 0)),
		"pinball_last_physics_real_msec": int(active.get("last_physics_real_msec", 0)),
		"pinball_playback_speed": _pinball_playback_speed(),
		"pinball_gravity_y": snappedf(_vector2_from_payload(layout.get("gravity", Vector2.ZERO), Vector2.ZERO).y, 0.001),
	}
	return manifest


func _pinball_layout_from_active(active: Dictionary) -> Dictionary:
	var session: Dictionary = {}
	var session_value: Variant = active.get("pinball_session", {})
	if typeof(session_value) == TYPE_DICTIONARY:
		session = session_value
	var layout: Dictionary = {}
	var layout_value: Variant = session.get("layout", {})
	if typeof(layout_value) == TYPE_DICTIONARY:
		layout = layout_value
	if not layout.is_empty():
		return layout
	var layout_id := str(session.get("layout_id", ""))
	if layout_id.is_empty():
		layout_id = _pinball_layout_id(str(active.get("mode", "")))
	var table: SlotPinballTable = PinballTableScript.new()
	return table.new_table(layout_id)


func _pinball_layout_id(mode: String) -> String:
	match mode:
		"lane_multiball":
			return "lane_multiball"
		"video_feature", "full_table":
			return "video_feature"
		_:
			return "em_bumper_drop"


func _pinball_geometry_counts(layout: Dictionary) -> Dictionary:
	var counts: Dictionary = {
		"bumper": 0,
		"ramp": 0,
		"orbit": 0,
		"lane": 0,
		"pocket": 0,
		"slingshot": 0,
		"flipper": 0,
	}
	for element_value in _read_array(layout.get("elements", [])):
		var element: Dictionary = _read_dict(element_value)
		var element_type := str(element.get("type", ""))
		counts[element_type] = int(counts.get(element_type, 0)) + 1
	return counts


func _pinball_lit_insert_count(active: Dictionary) -> int:
	var total := 0
	var lit_state: Dictionary = _pinball_lit_state(active)
	var lit: Dictionary = {}
	var lit_value: Variant = lit_state.get("lit", {})
	if typeof(lit_value) == TYPE_DICTIONARY:
		lit = lit_value
	for key_value in lit.keys():
		if bool(lit.get(key_value, false)):
			total += 1
	var targets: Dictionary = {}
	var targets_value: Variant = lit_state.get("targets", {})
	if typeof(targets_value) == TYPE_DICTIONARY:
		targets = targets_value
	for target_key in targets.keys():
		if bool(targets.get(target_key, false)):
			total += 1
	if bool(lit_state.get("video_super_jackpot_lit", false)):
		total += 1
	if bool(lit_state.get("video_multiball_ready", false)):
		total += 1
	total += maxi(0, int(lit_state.get("lane_locks", 0)))
	return total


func _pinball_lit_state(active: Dictionary) -> Dictionary:
	var session: Dictionary = {}
	var session_value: Variant = active.get("pinball_session", {})
	if typeof(session_value) == TYPE_DICTIONARY:
		session = session_value
	var lit: Dictionary = {}
	var lit_value: Variant = session.get("lit", {})
	if typeof(lit_value) == TYPE_DICTIONARY:
		lit = lit_value
	var targets: Dictionary = {}
	var targets_value: Variant = active.get("video_targets", {})
	if typeof(targets_value) == TYPE_DICTIONARY:
		targets = targets_value
	return {
		"lit": lit,
		"targets": targets,
		"video_super_jackpot_lit": bool(active.get("video_super_jackpot_lit", false)),
		"video_multiball_ready": bool(active.get("video_multiball_ready", false)),
		"lane_locks": int(active.get("lane_locks", 0)),
	}


func _pinball_transition_phase(time_msec: int) -> String:
	if time_msec < 520:
		return "push_in"
	return "playback"


func _pinball_camera_rect(rect: Rect2, time_msec: int) -> Rect2:
	var progress := clampf(float(maxi(0, time_msec)) / 520.0, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	var inset := lerpf(32.0, 0.0, eased)
	return rect.grow(-inset)


func _pinball_playback_time(time_msec: int) -> float:
	return maxf(0.0, float(time_msec - 520) / 1000.0) * _pinball_playback_speed()


func _pinball_playback_speed() -> float:
	return 1.45


func _pinball_events(active: Dictionary) -> Array:
	var display_events: Array = []
	var display_events_value: Variant = active.get("display_event_log", [])
	if typeof(display_events_value) == TYPE_ARRAY:
		display_events = display_events_value
	if not display_events.is_empty():
		return display_events
	var events: Array = []
	var events_value: Variant = active.get("event_log", [])
	if typeof(events_value) == TYPE_ARRAY:
		events = events_value
	if not events.is_empty():
		return events
	for step_value in _read_array(active.get("history", [])):
		var step: Dictionary = _read_dict(step_value)
		for event_value in _read_array(step.get("event_log", [])):
			events.append(_read_dict(event_value))
	return events


func _pinball_trajectory(active: Dictionary) -> Array:
	var display_trajectory: Array = []
	var display_trajectory_value: Variant = active.get("display_trajectory", [])
	if typeof(display_trajectory_value) == TYPE_ARRAY:
		display_trajectory = display_trajectory_value
	if bool(active.get("active", false)) and not bool(active.get("complete", false)) and not display_trajectory.is_empty():
		var live_trajectory_value: Variant = active.get("trajectory", [])
		if typeof(live_trajectory_value) == TYPE_ARRAY:
			var live_trajectory: Array = live_trajectory_value
			if _pinball_trajectory_time_span(live_trajectory) >= 0.18:
				return live_trajectory
		if _pinball_trajectory_time_span(display_trajectory) >= 0.18:
			return display_trajectory
		return display_trajectory
	var trajectory: Array = []
	var trajectory_value: Variant = active.get("trajectory", [])
	if typeof(trajectory_value) == TYPE_ARRAY:
		trajectory = trajectory_value
	if not trajectory.is_empty():
		return trajectory
	for step_value in _read_array(active.get("history", [])):
		var step: Dictionary = _read_dict(step_value)
		for point_value in _read_array(step.get("trajectory", [])):
			trajectory.append(_read_dict(point_value))
	return trajectory


func _pinball_trajectory_time_span(trajectory: Array) -> float:
	if trajectory.is_empty():
		return 0.0
	var first_time := 0.0
	var last_time := 0.0
	var found := false
	for point_value in trajectory:
		var point: Dictionary = _read_dict(point_value)
		if point.is_empty():
			continue
		var point_time := float(point.get("time", 0.0))
		if not found:
			first_time = point_time
			last_time = point_time
			found = true
		else:
			last_time = point_time
	return maxf(0.0, last_time - first_time)


func _pinball_live_positions(active: Dictionary) -> Array:
	if bool(active.get("visual_replay", false)):
		return []
	var session: Dictionary = _read_dict(active.get("pinball_session", {}))
	if session.is_empty():
		return []
	var balls: Array = _read_array(session.get("balls", []))
	var result: Array = []
	for ball_index in range(balls.size()):
		var ball: Dictionary = _read_dict(balls[ball_index])
		if not bool(ball.get("alive", false)):
			continue
		result.append({
			"ball_index": ball_index,
			"position": _vector2_from_payload(ball.get("position", Vector2(0.5, 0.5)), Vector2(0.5, 0.5)),
			"time": float(session.get("time", 0.0)),
		})
	return result


func _pinball_positions_at_time(trajectory: Array, time_msec: int) -> Array:
	var result: Array = []
	if trajectory.is_empty():
		return result
	var playback_sec: float = _pinball_playback_time(time_msec)
	var duration_sec: float = _pinball_trajectory_time_span(trajectory)
	if duration_sec > 0.035 and playback_sec > duration_sec:
		playback_sec = fposmod(playback_sec, duration_sec)
		if playback_sec < 0.012:
			playback_sec = minf(duration_sec, 0.012)
	var previous_by_ball: Dictionary = {}
	var next_by_ball: Dictionary = {}
	for point_value in trajectory:
		if typeof(point_value) != TYPE_DICTIONARY:
			continue
		var point: Dictionary = point_value
		var point_time := float(point.get("time", 0.0))
		var ball_index := int(point.get("ball_index", 0))
		var ball_key := str(ball_index)
		if point_time <= playback_sec + 0.0001:
			var previous: Dictionary = _read_dict(previous_by_ball.get(ball_key, {}))
			if previous.is_empty() or point_time >= float(previous.get("time", -1.0)):
				previous_by_ball[ball_key] = point
		elif not next_by_ball.has(ball_key):
			next_by_ball[ball_key] = point
	var keys: Dictionary = {}
	for key_value in previous_by_ball.keys():
		keys[key_value] = true
	for key_value in next_by_ball.keys():
		keys[key_value] = true
	if keys.is_empty() and typeof(trajectory[0]) == TYPE_DICTIONARY:
		var first: Dictionary = trajectory[0]
		keys[str(int(first.get("ball_index", 0)))] = true
		next_by_ball[str(int(first.get("ball_index", 0)))] = first
	for key_value in keys.keys():
		var result_key := str(key_value)
		var previous_point: Dictionary = _read_dict(previous_by_ball.get(result_key, {}))
		var next_point: Dictionary = _read_dict(next_by_ball.get(result_key, {}))
		var selected_point: Dictionary = previous_point if not previous_point.is_empty() else next_point
		if selected_point.is_empty():
			continue
		var position: Vector2 = _vector2_from_payload(selected_point.get("position", Vector2(0.5, 0.5)), Vector2(0.5, 0.5))
		if not previous_point.is_empty() and not next_point.is_empty():
			var previous_time := float(previous_point.get("time", 0.0))
			var next_time := float(next_point.get("time", previous_time))
			if next_time > previous_time + 0.0001:
				var ratio := clampf((playback_sec - previous_time) / (next_time - previous_time), 0.0, 1.0)
				var previous_position: Vector2 = _vector2_from_payload(previous_point.get("position", Vector2(0.5, 0.5)), Vector2(0.5, 0.5))
				var next_position: Vector2 = _vector2_from_payload(next_point.get("position", previous_position), previous_position)
				position = previous_position.lerp(next_position, ratio)
		var visual_phase := float(time_msec) * 0.006 + float(int(selected_point.get("ball_index", 0))) * 1.73
		position = Vector2(
			clampf(position.x + sin(visual_phase) * 0.0035, 0.03, 0.97),
			clampf(position.y + cos(visual_phase * 0.81) * 0.0035, 0.03, 0.97)
		)
		result.append({
			"ball_index": int(selected_point.get("ball_index", 0)),
			"position": position,
			"time": playback_sec,
		})
	return result


func _pinball_multiball_fallback_positions(time_msec: int) -> Array:
	var phase := fposmod(float(time_msec - 900) / 1000.0, 1.0)
	var sway := sin(phase * TAU) * 0.035
	return [
		{"ball_index": 0, "position": Vector2(0.48 + sway, 0.78), "time": phase},
		{"ball_index": 1, "position": Vector2(0.40 - sway, 0.72 + absf(sway) * 0.4), "time": phase},
		{"ball_index": 2, "position": Vector2(0.58 + sway * 0.5, 0.72 - absf(sway) * 0.4), "time": phase},
	]


func _pinball_position_payloads(positions: Array) -> Array:
	var payloads: Array = []
	for position_value in positions:
		var entry: Dictionary = _read_dict(position_value)
		var position: Vector2 = _vector2_from_payload(entry.get("position", Vector2(0.5, 0.5)), Vector2(0.5, 0.5))
		payloads.append({
			"ball_index": int(entry.get("ball_index", 0)),
			"x": snappedf(position.x, 0.0001),
			"y": snappedf(position.y, 0.0001),
		})
	return payloads


func _pinball_recent_event_ids(events: Array, playback_sec: float, window_sec: float) -> Dictionary:
	var result: Dictionary = {}
	for event_value in events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var event_time := float(event.get("time", 0.0))
		if event_time > playback_sec + 0.0001:
			break
		if event_time <= playback_sec + 0.0001 and playback_sec - event_time <= window_sec:
			result[str(event.get("element_id", ""))] = true
	return result


func _pinball_latest_event(events: Array, playback_sec: float) -> Dictionary:
	var latest: Dictionary = {}
	var latest_time := -1.0
	for event_value in events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var event_time := float(event.get("time", 0.0))
		if event_time <= playback_sec + 0.0001 and event_time >= latest_time:
			latest = event
			latest_time = event_time
	return latest


func _draw_pinball_backglass(surface, rect: Rect2, active: Dictionary, identity: String, accent: Color, light: Color, trim: Color, bucket: int) -> void:
	var panel := Rect2(rect.position + Vector2(12, 8), Vector2(rect.size.x - 24, 28))
	var mode := str(active.get("mode", "pinball"))
	if identity == "em_bumper_drop":
		surface.draw_rect(panel, Color(trim.r, trim.g, trim.b, 0.10))
		for reel in range(5):
			var reel_rect := Rect2(panel.position + Vector2(12 + reel * 32, 5), Vector2(24, 18))
			surface.draw_rect(reel_rect, Color(0.0, 0.0, 0.0, 0.48))
			surface.draw_rect(reel_rect, Color(trim.r, trim.g, trim.b, 0.40), false, 1)
		surface.surface_label("SCORE %d" % int(active.get("feature_total", active.get("awarded", 0))), panel.position + Vector2(panel.size.x - 150, 20), 12, trim)
	elif identity == "lane_multiball":
		surface.draw_rect(panel, Color("#1d0c04"))
		for x in range(32):
			var lit := posmod(bucket + x, 5) == 0
			surface.draw_circle(panel.position + Vector2(8 + x * 7, 14), 1.8, Color(trim.r, trim.g, trim.b, 0.68 if lit else 0.18))
		surface.surface_label("LOCKS %d  $%d" % [int(active.get("lane_locks", 0)), int(active.get("feature_total", active.get("awarded", 0)))], panel.position + Vector2(254, 20), 12, trim)
	else:
		surface.draw_rect(panel, Color("#07192d"))
		surface.draw_rect(panel, Color(accent.r, light.g, light.b, 0.18), false, 2)
		surface.surface_label("%s  $%d" % [mode.replace("_", " ").to_upper().left(18), int(active.get("feature_total", active.get("awarded", 0)))], panel.position + Vector2(12, 20), 12, light)


func _draw_pinball_element(surface, rect: Rect2, element: Dictionary, active: Dictionary, lit_state: Dictionary, recent_ids: Dictionary, accent: Color, light: Color, trim: Color, bucket: int, playback_sec: float) -> void:
	var element_type := str(element.get("type", "wall"))
	var element_id := str(element.get("id", ""))
	var shape := str(element.get("shape", ""))
	var hit := bool(recent_ids.get(element_id, false))
	var lit := _pinball_element_lit(lit_state, element)
	var flash_alpha := 0.38 if hit else 0.0
	if shape == "segment":
		var a: Vector2 = _pinball_point(rect, element.get("a", Vector2.ZERO))
		var b: Vector2 = _pinball_point(rect, element.get("b", Vector2.ZERO))
		if element_type == "flipper" and hit:
			var direction: Vector2 = b - a
			var kick_angle := -0.22 if a.x < rect.position.x + rect.size.x * 0.5 else 0.22
			b = a + direction.rotated(kick_angle)
		var width := 4.0
		var color := Color("#cbd5e1")
		match element_type:
			"wall", "rail":
				width = 3.0
				color = Color(light.r, light.g, light.b, 0.48)
			"plunger_lane":
				width = 3.0
				color = Color(trim.r, trim.g, trim.b, 0.54)
			"slingshot":
				width = 5.0
				color = Color(accent.r, accent.g, accent.b, 0.78 if not hit else 1.0)
			"flipper":
				width = 6.0
				color = trim if not hit else Color("#f8fafc")
		surface.draw_line(a, b, Color(0.0, 0.0, 0.0, 0.34), width + 3.0)
		surface.draw_line(a, b, color, width)
		if hit:
			surface.draw_line(a, b, Color(light.r, light.g, light.b, 0.38 + flash_alpha), width + 8.0)
		if element_type == "plunger_lane":
			for spring in range(5):
				var y := lerpf(a.y, b.y, float(spring + 1) / 6.0)
				surface.draw_line(Vector2(a.x - 8, y), Vector2(a.x + 8, y + 4), Color(trim.r, trim.g, trim.b, 0.42), 1)
		return
	if shape == "drain_rect":
		var drain: Rect2 = _rect2_from_payload(element.get("rect", Rect2()))
		var drain_rect := Rect2(rect.position + Vector2(drain.position.x * rect.size.x, drain.position.y * rect.size.y), Vector2(drain.size.x * rect.size.x, drain.size.y * rect.size.y))
		surface.draw_rect(drain_rect, Color("#2a0610"))
		surface.draw_rect(drain_rect, Color(accent.r, accent.g, accent.b, 0.45), false, 2)
		return
	var center: Vector2 = _pinball_point(rect, element.get("position", Vector2(0.5, 0.5)))
	var radius := maxf(4.0, float(element.get("radius", 0.04)) * minf(rect.size.x, rect.size.y))
	var base_alpha := 0.22 + (0.20 if lit else 0.0) + flash_alpha
	match element_type:
		"bumper":
			surface.draw_circle(center, radius + 5.0, Color(accent.r, accent.g, accent.b, base_alpha))
			surface.draw_circle(center, radius, Color("#e6edf7"))
			surface.draw_circle(center, radius * 0.58, Color(light.r, light.g, light.b, 0.72))
			surface.surface_label_centered("%d" % int(element.get("award", 0)), Rect2(center - Vector2(radius, radius * 0.62), Vector2(radius * 2.0, radius * 1.24)), 9, Color("#07111d"))
		"slingshot":
			surface.draw_circle(center, radius, Color(accent.r, accent.g, accent.b, 0.42 + flash_alpha))
		"ramp", "orbit":
			var route: Vector2 = _vector2_from_payload(element.get("route", Vector2(0.0, -0.4)), Vector2(0.0, -0.4))
			var end: Vector2 = _pinball_point(rect, _normalized_point(center, rect) + route * 0.32)
			var lane_color := light if element_type == "orbit" else trim
			surface.draw_line(center, end, Color(lane_color.r, lane_color.g, lane_color.b, 0.34 + base_alpha), 5)
			surface.draw_circle(center, radius, Color(lane_color.r, lane_color.g, lane_color.b, 0.22 + base_alpha), false, 3)
			surface.surface_label_centered("LOCK" if bool(element.get("lock", false)) else element_type.to_upper(), Rect2(center - Vector2(radius * 1.8, radius * 0.6), Vector2(radius * 3.6, radius * 1.2)), 8, lane_color)
		"lane":
			surface.draw_circle(center, radius, Color(light.r, light.g, light.b, 0.18 + base_alpha), false, 3)
			surface.draw_circle(center, radius * 0.48, Color(light.r, light.g, light.b, 0.34 + base_alpha))
		"pocket":
			surface.draw_circle(center, radius + 4.0, Color(trim.r, trim.g, trim.b, 0.20 + base_alpha))
			surface.draw_circle(center, radius, Color(0.0, 0.0, 0.0, 0.64))
			surface.draw_circle(center, radius * 0.66, Color(trim.r, trim.g, trim.b, 0.18), false, 2)
		"drop_target":
			var target_rect := Rect2(center - Vector2(radius * 0.58, radius * 0.84), Vector2(radius * 1.16, radius * 1.68))
			surface.draw_rect(target_rect, Color(accent.r, accent.g, accent.b, 0.22 + base_alpha))
			surface.draw_rect(target_rect, Color("#f8fafc") if lit or hit else accent, false, 2)
		"spinner":
			surface.draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), trim, 3)
			surface.draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), light, 3)
			surface.draw_circle(center, radius * 0.26, Color(trim.r, trim.g, trim.b, 0.62 + flash_alpha))
		_:
			surface.draw_circle(center, radius, Color(light.r, light.g, light.b, 0.18 + base_alpha), false, 2)


func _pinball_element_lit(lit_state: Dictionary, element: Dictionary) -> bool:
	var element_id := str(element.get("id", ""))
	var light_key := str(element.get("light", ""))
	var lit: Dictionary = {}
	var lit_value: Variant = lit_state.get("lit", {})
	if typeof(lit_value) == TYPE_DICTIONARY:
		lit = lit_value
	if not light_key.is_empty() and bool(lit.get(light_key, false)):
		return true
	var targets: Dictionary = {}
	var targets_value: Variant = lit_state.get("targets", {})
	if typeof(targets_value) == TYPE_DICTIONARY:
		targets = targets_value
	if bool(targets.get(element_id, false)):
		return true
	if element_id == "center_lock" and bool(lit_state.get("video_super_jackpot_lit", false)):
		return true
	if bool(element.get("lock", false)) and int(lit_state.get("lane_locks", 0)) > 0:
		return true
	return false


func _draw_pinball_ball_trail(surface, rect: Rect2, trajectory: Array, ball_index: int, playback_sec: float, light: Color) -> void:
	var points: Array = []
	for point_value in trajectory:
		if typeof(point_value) != TYPE_DICTIONARY:
			continue
		var point: Dictionary = point_value
		if int(point.get("ball_index", 0)) != ball_index:
			continue
		var point_time := float(point.get("time", 0.0))
		if point_time > playback_sec + 0.0001 or playback_sec - point_time > 0.28:
			continue
		points.append(_pinball_point(rect, point.get("position", Vector2(0.5, 0.5))))
	for index in range(1, points.size()):
		var alpha := 0.08 + 0.20 * float(index) / float(maxi(1, points.size()))
		surface.draw_line(points[index - 1], points[index], Color(light.r, light.g, light.b, alpha), 2)


func _draw_pinball_callout(surface, rect: Rect2, active: Dictionary, events: Array, playback_sec: float, identity: String, accent: Color, light: Color, trim: Color) -> void:
	var latest: Dictionary = _pinball_latest_event(events, playback_sec)
	var panel := Rect2(rect.position + Vector2(18, 42), Vector2(rect.size.x - 36, 28))
	var color := trim if identity == "em_bumper_drop" else light if identity == "lane_multiball" else accent
	surface.draw_rect(panel, Color(0.0, 0.0, 0.0, 0.46))
	surface.draw_rect(panel, Color(color.r, color.g, color.b, 0.22), false, 1)
	var text := "LAUNCH AND WATCH"
	if not latest.is_empty():
		var award := int(latest.get("award", 0))
		text = "%s +$%d" % [str(latest.get("element_type", "hit")).replace("_", " ").to_upper(), award]
	if bool(active.get("video_super_jackpot_lit", false)):
		text = "SUPER JACKPOT LIT"
	surface.surface_label_centered(text.left(34), panel.grow(-3), 12, color)


func _draw_pinball_launch_guideline(surface, rect: Rect2, active: Dictionary, layout: Dictionary, light: Color, trim: Color, time_msec: int) -> void:
	if not _pinball_guideline_active(active):
		return
	var lane := str(active.get("selected_lane", "center"))
	var start_norm: Vector2 = _pinball_launch_start(active, layout, lane)
	_draw_pinball_launch_start_rail(surface, rect, active, layout, trim)
	var direction: Vector2 = _pinball_lane_direction(layout, lane)
	if direction.length_squared() <= 0.000001:
		direction = Vector2(0.0, 1.0)
	var angle_degrees := clampi(int(active.get("launch_angle_degrees", 0)), PINBALL_AIM_MIN_DEGREES, PINBALL_AIM_MAX_DEGREES)
	direction = direction.normalized()
	direction = direction.rotated(deg_to_rad(float(-angle_degrees))).normalized()
	var meter: Dictionary = _read_dict(active.get("pinball_launch_meter", {}))
	var sampled_power := int(meter.get("sampled_power", active.get("launch_power", 70)))
	var power := clampf(float(sampled_power) / 100.0, 0.0, 1.0)
	var speed := lerpf(maxf(0.1, float(layout.get("launch_speed_min", 2.0))), maxf(0.1, float(layout.get("launch_speed_max", 3.5))), power)
	var gravity: Vector2 = _vector2_from_payload(layout.get("gravity", Vector2(0.0, 2.8)), Vector2(0.0, 2.8))
	var position := start_norm
	var velocity := direction * speed
	var points: Array = []
	for step_index in range(9):
		points.append(_pinball_point(rect, position))
		velocity += gravity * 0.075
		position += velocity * 0.075
	var pulse := 0.45 + 0.22 * sin(float(time_msec) * 0.016)
	for point_index in range(1, points.size()):
		var alpha := clampf(0.22 + float(point_index) * 0.055 + pulse * 0.12, 0.0, 0.90)
		surface.draw_line(points[point_index - 1], points[point_index], Color(light.r, light.g, light.b, alpha), 3)
		surface.draw_line(points[point_index - 1], points[point_index], Color(trim.r, trim.g, trim.b, alpha * 0.38), 7)
	var start_point: Vector2 = _pinball_point(rect, start_norm)
	var end_point: Vector2 = points[points.size() - 1]
	surface.draw_circle(start_point, 6.0, Color("#f8fafc"))
	surface.draw_circle(end_point, 9.0 + pulse * 2.5, Color(trim.r, trim.g, trim.b, 0.30), false, 2)
	var angle_label := str(angle_degrees)
	if angle_degrees > 0:
		angle_label = "+%d" % angle_degrees
	surface.surface_label_centered("A%s P%d" % [angle_label, sampled_power], Rect2(start_point + Vector2(-34, 10), Vector2(68, 18)), 10, trim)


func _draw_pinball_launch_start_rail(surface, rect: Rect2, active: Dictionary, _layout: Dictionary, trim: Color) -> void:
	var mode := str(active.get("mode", "em_bumper_drop"))
	var selected_index := _pinball_start_choice_index(active)
	var y_norm := 0.10
	var min_x := 0.16
	var max_x := 0.84
	if mode == "lane_multiball":
		min_x = 0.14
		max_x = 0.86
		y_norm = 0.09
	elif mode == "video_feature":
		min_x = 0.54
		max_x = 0.94
		y_norm = 0.08
	var rail_a := _pinball_point(rect, Vector2(min_x, y_norm))
	var rail_b := _pinball_point(rect, Vector2(max_x, y_norm))
	surface.draw_line(rail_a, rail_b, Color(trim.r, trim.g, trim.b, 0.30), 3)
	for index in range(PINBALL_START_CHOICES):
		var ratio := float(index) / float(PINBALL_START_CHOICES - 1)
		var marker := _pinball_point(rect, Vector2(lerpf(min_x, max_x, ratio), y_norm))
		var radius := 5.0 if index == selected_index else 3.0
		var alpha := 0.82 if index == selected_index else 0.34
		surface.draw_circle(marker, radius, Color(trim.r, trim.g, trim.b, alpha))
		surface.surface_add_hit(Rect2(marker - Vector2(12, 12), Vector2(24, 24)), "slot_bonus_start_%02d" % index, index)


func _draw_pinball_power_meter(surface, rect: Rect2, active: Dictionary, light: Color, trim: Color) -> void:
	var meter: Dictionary = _read_dict(active.get("pinball_launch_meter", {}))
	var value := clampf(float(meter.get("meter", 0.5)), 0.0, 1.0)
	var sampled_power := int(meter.get("sampled_power", active.get("launch_power", 70)))
	var rating := str(meter.get("rating", ""))
	surface.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.42))
	surface.draw_rect(rect, Color(light.r, light.g, light.b, 0.20), false, 1)
	var track := Rect2(rect.position + Vector2(8, 9), Vector2(rect.size.x - 16, 8))
	surface.draw_rect(track, Color(light.r, light.g, light.b, 0.16))
	surface.draw_rect(Rect2(track.position, Vector2(track.size.x * value, track.size.y)), Color(light.r, light.g, light.b, 0.42))
	var sweet_x := track.position.x + track.size.x * 0.82
	surface.draw_rect(Rect2(Vector2(sweet_x - 3, track.position.y - 2), Vector2(6, track.size.y + 4)), Color(trim.r, trim.g, trim.b, 0.42))
	var marker_x := track.position.x + track.size.x * value
	surface.draw_line(Vector2(marker_x, track.position.y - 4), Vector2(marker_x, track.end.y + 4), Color("#f8fafc"), 2)
	surface.surface_label_centered("PWR %d" % sampled_power, Rect2(rect.position + Vector2(4, 20), Vector2(rect.size.x - 8, 13)), 10, light)
	surface.surface_label_centered(rating.to_upper().left(6), Rect2(rect.position + Vector2(4, 32), Vector2(rect.size.x - 8, 10)), 8, trim)


func _pinball_guideline_active(active: Dictionary) -> bool:
	if active.is_empty() or not bool(active.get("active", false)) or bool(active.get("complete", false)):
		return false
	if bool(active.get("launch_in_progress", false)):
		return false
	return int(active.get("balls_remaining", active.get("remaining_steps", 0))) > 0


func _pinball_lane_start(layout: Dictionary, lane: String) -> Vector2:
	var start: Vector2 = _vector2_from_payload(layout.get("plunger_start", Vector2(0.5, 0.12)), Vector2(0.5, 0.12))
	var starts: Dictionary = _read_dict(layout.get("lane_starts", {}))
	if starts.has(lane):
		return _vector2_from_payload(starts.get(lane, start), start)
	start.x = clampf(start.x + _pinball_lane_offset(layout, lane), 0.08, 0.92)
	return start


func _pinball_launch_start(active: Dictionary, layout: Dictionary, lane: String) -> Vector2:
	var fallback := _pinball_lane_start(layout, lane)
	var launch_start: Dictionary = _read_dict(active.get("launch_start", {}))
	if launch_start.is_empty():
		return fallback
	return Vector2(
		clampf(float(launch_start.get("x", fallback.x)), 0.04, 0.96),
		clampf(float(launch_start.get("y", fallback.y)), 0.02, 0.24)
	)


func _pinball_lane_direction(layout: Dictionary, lane: String) -> Vector2:
	var direction: Vector2 = _vector2_from_payload(layout.get("plunger_direction", Vector2(0.0, 1.0)), Vector2(0.0, 1.0))
	var directions: Dictionary = _read_dict(layout.get("lane_directions", {}))
	if directions.has(lane):
		direction = _vector2_from_payload(directions.get(lane, direction), direction)
	return direction


func _pinball_lane_offset(layout: Dictionary, lane: String) -> float:
	var offsets: Dictionary = _read_dict(layout.get("lane_offsets", {}))
	return float(offsets.get(lane, 0.0))


func _pinball_point(rect: Rect2, value: Variant) -> Vector2:
	var p: Vector2 = _vector2_from_payload(value, Vector2(0.5, 0.5))
	return rect.position + Vector2(clampf(p.x, -0.1, 1.1) * rect.size.x, clampf(p.y, -0.1, 1.1) * rect.size.y)


func _normalized_point(point: Vector2, rect: Rect2) -> Vector2:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Vector2(0.5, 0.5)
	return Vector2((point.x - rect.position.x) / rect.size.x, (point.y - rect.position.y) / rect.size.y)


func _vector2_from_payload(value: Variant, fallback: Vector2) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value as Vector2
	if typeof(value) == TYPE_DICTIONARY:
		var dict: Dictionary = value
		return Vector2(float(dict.get("x", fallback.x)), float(dict.get("y", fallback.y)))
	return fallback


func _rect2_from_payload(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value as Rect2
	if typeof(value) == TYPE_DICTIONARY:
		var dict: Dictionary = value
		if dict.has("position") and dict.has("size"):
			return Rect2(_vector2_from_payload(dict.get("position", Vector2.ZERO), Vector2.ZERO), _vector2_from_payload(dict.get("size", Vector2.ZERO), Vector2.ZERO))
		return Rect2(Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0))), Vector2(float(dict.get("w", 0.0)), float(dict.get("h", 0.0))))
	return Rect2()


func _draw_buffalo_feature(surface, rect: Rect2, state: Dictionary, definition: Dictionary, active: Dictionary, accent: Color, light: Color, trim: Color, bucket: int, feature_msec: int, spin_msec: int) -> void:
	var mode := str(active.get("mode", ""))
	var phase := _buffalo_stampede_phase(feature_msec, active)
	var dusk := _buffalo_sunset_shift(state, bucket)
	surface.draw_rect(rect, Color("#301207").lerp(Color("#090816"), dusk))
	surface.draw_rect(rect, Color(trim.r, trim.g, trim.b, 0.20), false, 2)
	_draw_buffalo_stampede(surface, rect, phase, bucket, accent, trim)
	if mode == "hold_and_spin":
		_draw_buffalo_hold_and_spin(surface, rect.grow(-8), active, definition, accent, light, trim, bucket, feature_msec)
	elif mode == "wheel":
		_draw_buffalo_wheel_trophy(surface, rect.grow(-8), active, accent, light, trim, bucket, feature_msec)
	else:
		_draw_buffalo_free_games(surface, rect.grow(-8), state, definition, active, accent, light, trim, bucket, feature_msec, spin_msec)


func _buffalo_feature_manifest(surface_state: Dictionary, time_msec: int, mode: String) -> Dictionary:
	var active: Dictionary = _read_dict(surface_state.get("slot_active_bonus", {}))
	var family := str(active.get("family", surface_state.get("slot_type_id", "")))
	if family != "buffalo":
		return {}
	if active.is_empty() or (mode != "feature" and not bool(surface_state.get("slot_active_bonus_active", false))):
		return {}
	var locks: Array = _read_array(active.get("locks", []))
	var meter: Dictionary = _buffalo_fill_meter(active)
	var locked_cells := int(meter.get("locked", locks.size()))
	var fill_ratio := clampf(float(meter.get("ratio", 0.0)), 0.0, 1.0)
	var ladder: Dictionary = _read_dict(active.get("jackpot_ladder", {}))
	var board_payload: Dictionary = _buffalo_main_board_payload(surface_state, time_msec)
	return {
		"ladder_visible": _buffalo_ladder_visible(active),
		"locked_cells": locked_cells,
		"fill_meter": fill_ratio,
		"trophy_pick_active": bool(active.get("trophy_pick_active", false)) or _array_read_size(active.get("trophy_reveals", [])) > 0,
		"stampede_phase": _buffalo_stampede_phase(time_msec, active),
		"topper_reaction": _buffalo_topper_reaction(surface_state),
		"buffalo_coin_meter": _buffalo_collection_ratio(active),
		"buffalo_coin_count": int(active.get("coins_collected", 0)),
		"buffalo_coin_total": int(active.get("coin_total", 0)),
		"buffalo_new_coin_count": _array_read_size(active.get("last_collected_coins", [])),
		"buffalo_retrigger_grant": int(active.get("last_retrigger_grant", 0)),
		"buffalo_coin_collect_total": int(active.get("coin_collect_total", 0)),
		"buffalo_coin_reveal_count": _array_read_size(active.get("coin_reveals", [])),
		"buffalo_coin_reveal_total": int(active.get("coin_reveal_total", active.get("coin_collect_total", 0))),
		"buffalo_ladder_tiers": _array_read_size(ladder.get("tiers", [])),
		"buffalo_trophy_reveals": _array_read_size(active.get("trophy_reveals", [])),
		"buffalo_main_board_visible_lock_count": int(board_payload.get("visible_lock_count", 0)),
		"buffalo_main_board_pending_lock_count": int(board_payload.get("pending_lock_count", 0)),
		"buffalo_main_board_recent_lock_count": int(board_payload.get("recent_lock_count", 0)),
	}


func _draw_buffalo_stampede(surface, rect: Rect2, phase: String, bucket: int, accent: Color, trim: Color) -> void:
	var dust_alpha := 0.10
	if phase == "transition":
		dust_alpha = 0.28
	elif phase == "celebration":
		dust_alpha = 0.34
	for dust in range(12):
		var dust_x := rect.position.x + fposmod(float(bucket * 11 + dust * 29), rect.size.x)
		var dust_y := rect.position.y + rect.size.y * (0.64 + 0.06 * float(dust % 3))
		surface.draw_circle(Vector2(dust_x, dust_y), 4.0 + float(dust % 4), Color(trim.r, trim.g, trim.b, dust_alpha))
	for herd in range(6):
		var x := rect.position.x + fposmod(float(bucket * 8 + herd * 47), rect.size.x + 80.0) - 40.0
		var y := rect.position.y + rect.size.y * (0.54 + 0.08 * float(herd % 2))
		_draw_buffalo_silhouette(surface, Vector2(x, y), 0.42 + float(herd % 3) * 0.08, Color(0.0, 0.0, 0.0, 0.32))
	if phase == "transition":
		surface.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.16))


func _draw_buffalo_free_games(surface, rect: Rect2, state: Dictionary, definition: Dictionary, active: Dictionary, accent: Color, light: Color, trim: Color, bucket: int, feature_msec: int, spin_msec: int) -> void:
	var header_rect := Rect2(rect.position + Vector2(8, 8), Vector2(rect.size.x - 16, 28))
	surface.draw_rect(header_rect, Color(trim.r, trim.g, trim.b, 0.16))
	surface.draw_rect(header_rect, Color(light.r, light.g, light.b, 0.22), false, 1)
	surface.surface_label("FREE %d  RETRIG %d" % [int(active.get("remaining_steps", 0)), int(active.get("retrigger_count", 0))], header_rect.position + Vector2(8, 19), 12, light)
	var coin_header := "COINS HELD %d" % int(active.get("coins_collected", 0))
	if str(active.get("feature_phase", "")) == "coin_collect" or _copy_array(active.get("coin_reveals", [])).size() > 0:
		coin_header = "REVEAL $%d" % int(active.get("coin_reveal_total", active.get("coin_collect_total", 0)))
	surface.surface_label("$%d + %s" % [int(active.get("spin_win_total", active.get("feature_total", 0))), coin_header], header_rect.position + Vector2(header_rect.size.x - 210, 19), 12, trim)
	var grid_rect := Rect2(rect.position + Vector2(8, 42), Vector2(rect.size.x - 16, rect.size.y - 92))
	_draw_buffalo_free_games_reel_grid(surface, grid_rect, state, definition, active, accent, light, trim, spin_msec, feature_msec)
	var meter: Dictionary = _copy_dict(active.get("collection_meter", {}))
	var cycle := maxi(0, int(meter.get("cycle", active.get("coins_since_retrigger", 0))))
	var threshold := maxi(1, int(meter.get("threshold", 3)))
	var meter_rect := Rect2(rect.position + Vector2(10, rect.size.y - 34), Vector2(rect.size.x - 20, 14))
	_draw_buffalo_meter(surface, meter_rect, _buffalo_collection_ratio(active), trim, light, "COINS %d/%d  HELD %d  $%d" % [cycle, threshold, int(active.get("coins_collected", 0)), int(active.get("coin_total", 0))])
	if int(active.get("last_retrigger_grant", 0)) > 0:
		surface.surface_label_centered("+%d FREE GAMES" % int(active.get("last_retrigger_grant", 0)), Rect2(rect.position + Vector2(rect.size.x * 0.24, rect.size.y - 64), Vector2(rect.size.x * 0.52, 24)), 18, accent)
	if bool(active.get("coin_collect_awarded", false)) or str(active.get("feature_phase", "")) == "coin_collect":
		var pulse := 0.35 + 0.16 * sin(float(feature_msec) * 0.010)
		var collect_rect := Rect2(rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.38), Vector2(rect.size.x * 0.64, 46))
		surface.draw_rect(collect_rect, Color(trim.r, trim.g, trim.b, pulse))
		surface.draw_rect(collect_rect, Color(light.r, light.g, light.b, 0.80), false, 2)
		var revealed_total := _buffalo_revealed_coin_total(active, feature_msec)
		surface.surface_label_centered("COIN PRIZES +$%d / $%d" % [revealed_total, int(active.get("coin_reveal_total", active.get("coin_collect_total", 0)))], collect_rect.grow(-4), 20, Color("#130907"))


func _draw_buffalo_free_games_reel_grid(surface, rect: Rect2, state: Dictionary, definition: Dictionary, active: Dictionary, accent: Color, light: Color, trim: Color, time_msec: int, feature_msec: int) -> void:
	var grid: Array = _copy_array(state.get("slot_grid", []))
	var strips: Array = _copy_array(state.get("slot_reel_strips", []))
	var stops: Array = _copy_array(state.get("slot_reel_stops", []))
	var reel_count := maxi(1, int(state.get("slot_reel_count", maxi(1, grid.size()))))
	var row_count := maxi(1, int(state.get("slot_row_count", 3)))
	var timeline: Array = _copy_array(state.get("slot_reel_timeline", []))
	var motions: Array = []
	for reel_index in range(reel_count):
		var motion: Dictionary = {"phase": "settled", "scroll_cells": 0.0, "blur": 0.0}
		if reel_index < timeline.size():
			motion = _reel_motion(_copy_dict(timeline[reel_index]), time_msec)
		motions.append(motion)
	surface.draw_rect(rect, Color("#130907"))
	surface.draw_rect(rect, Color(trim.r, trim.g, trim.b, 0.26), false, 2)
	var gap := 4.0
	var cell_w := (rect.size.x - gap * float(reel_count + 1)) / float(reel_count)
	var cell_h := (rect.size.y - gap * float(row_count + 1)) / float(row_count)
	for reel_index in range(reel_count):
		var motion: Dictionary = _copy_dict(motions[reel_index])
		var phase := str(motion.get("phase", "settled"))
		var scroll_cells := float(motion.get("scroll_cells", 0.0))
		var blur := float(motion.get("blur", 0.0))
		var fractional: float = scroll_cells - floor(scroll_cells)
		var whole_offset := int(floor(scroll_cells))
		if phase == "settled":
			fractional = 0.0
			whole_offset = 0
		for visual_row in range(-1, row_count + 2):
			var cell := _buffalo_free_game_cell_rect(rect, reel_index, visual_row, reel_count, row_count, gap, cell_w, cell_h)
			cell.position.y -= fractional * (cell_h + gap)
			var visible_cell := _rect_intersection(cell, rect)
			if visible_cell.size.x <= 0.0 or visible_cell.size.y <= 0.0:
				continue
			var landing_slot := phase == "decel" or phase == "tease_slow_roll" or phase == "settle" or phase == "settled"
			var symbol := _visible_symbol(strips, stops, grid, reel_index, visual_row + whole_offset, row_count, landing_slot)
			_draw_symbol(surface, definition, "buffalo", symbol, visible_cell, blur > 0.12)
			if blur > 0.38:
				surface.draw_rect(_rect_intersection(visible_cell.grow(-4), rect), Color(light.r, light.g, light.b, minf(0.18, blur * 0.22)))
	var recent := _buffalo_coin_lookup(_copy_array(active.get("last_collected_coins", [])))
	var coins := _buffalo_coin_lookup(_copy_array(active.get("collected_coins", [])))
	var reveal_lookup := _buffalo_coin_reveal_lookup(active, feature_msec)
	for key_value in coins.keys():
		var key := str(key_value)
		var coin: Dictionary = _copy_dict(coins.get(key_value, {}))
		var reel := int(coin.get("reel", 0))
		var row := int(coin.get("row", 0))
		if reel < 0 or reel >= reel_count or row < 0 or row >= row_count:
			continue
		var cell_rect := _buffalo_free_game_cell_rect(rect, reel, row, reel_count, row_count, gap, cell_w, cell_h)
		var reveal: Dictionary = _copy_dict(reveal_lookup.get(key, {}))
		var revealed := reveal.is_empty() or bool(reveal.get("revealed", false))
		if not reveal.is_empty():
			coin = reveal
		var slam: bool = recent.has(key) or (not reveal.is_empty() and reveal.get("just_revealed", false) == true)
		_draw_buffalo_coin_cell(surface, cell_rect, coin, true, slam, accent, light, trim, revealed)


func _buffalo_free_game_cell_rect(rect: Rect2, reel: int, row: int, reel_count: int, row_count: int, gap: float, cell_w: float, cell_h: float) -> Rect2:
	var x := rect.position.x + gap + float(reel) * (cell_w + gap)
	var y := rect.position.y + gap + float(row) * (cell_h + gap)
	return Rect2(Vector2(x, y), Vector2(cell_w, cell_h))


func _buffalo_coin_lookup(coins: Array) -> Dictionary:
	var result: Dictionary = {}
	for coin_value in coins:
		var coin: Dictionary = _copy_dict(coin_value)
		result[_cell_key(int(coin.get("reel", 0)), int(coin.get("row", 0)))] = coin
	return result


func _buffalo_coin_reveal_lookup(active: Dictionary, feature_msec: int) -> Dictionary:
	var result: Dictionary = {}
	for reveal_value in _copy_array(active.get("coin_reveals", [])):
		var reveal: Dictionary = _copy_dict(reveal_value)
		var key := _cell_key(int(reveal.get("reel", 0)), int(reveal.get("row", 0)))
		var start_msec := int(reveal.get("reveal_start_msec", 0))
		var duration_msec := maxi(1, int(reveal.get("reveal_duration_msec", 320)))
		reveal["revealed"] = feature_msec >= start_msec
		reveal["just_revealed"] = feature_msec >= start_msec and feature_msec <= start_msec + duration_msec
		result[key] = reveal
	return result


func _buffalo_revealed_coin_total(active: Dictionary, feature_msec: int) -> int:
	var total := 0
	for reveal_value in _copy_array(active.get("coin_reveals", [])):
		var reveal: Dictionary = _copy_dict(reveal_value)
		if feature_msec >= int(reveal.get("reveal_start_msec", 0)):
			total += maxi(0, int(reveal.get("value", 0)))
	return total


func _draw_buffalo_coin_cell(surface, cell_rect: Rect2, coin: Dictionary, has_coin: bool, slam: bool, accent: Color, light: Color, trim: Color, revealed: bool = true) -> void:
	surface.draw_rect(cell_rect, Color(trim.r, trim.g, trim.b, 0.12 if not has_coin else 0.44 + (0.18 if slam else 0.0)))
	surface.draw_rect(cell_rect, Color(light.r, light.g, light.b, 0.32 if has_coin else 0.12), false, 1)
	if not has_coin:
		return
	var center := cell_rect.position + cell_rect.size * 0.5
	var radius := minf(cell_rect.size.x, cell_rect.size.y) * (0.30 if not slam else 0.38)
	if slam:
		surface.draw_rect(cell_rect.grow(5), Color(accent.r, accent.g, accent.b, 0.34), false, 3)
		surface.draw_rect(cell_rect.grow(9), Color(light.r, light.g, light.b, 0.20), false, 2)
	surface.draw_circle(center, radius, trim)
	surface.draw_circle(center + Vector2(-radius * 0.30, -radius * 0.30), radius * 0.36, Color(1.0, 1.0, 1.0, 0.48))
	surface.draw_circle(center, radius * 0.74, Color("#f8c94a"), false, 2)
	var label := "$%d" % int(coin.get("value", 0)) if revealed else "?"
	var label_size := int(clampf(cell_rect.size.y * 0.22, 8.0, 18.0))
	surface.surface_label_centered(label, cell_rect.grow(-2), label_size, Color("#130907"))
	if slam:
		surface.draw_circle(center, minf(cell_rect.size.x, cell_rect.size.y) * 0.58, Color(accent.r, accent.g, accent.b, 0.28), false, 2)


func _draw_buffalo_hold_and_spin(surface, rect: Rect2, active: Dictionary, definition: Dictionary, accent: Color, light: Color, trim: Color, bucket: int, feature_msec: int) -> void:
	var max_cells := maxi(1, int(active.get("max_cells", 15)))
	var cols := maxi(1, int(active.get("reel_count", 6 if max_cells >= 30 else 5)))
	var rows := maxi(1, int(active.get("row_count", ceil(float(max_cells) / float(cols)))))
	var grid_rect := Rect2(rect.position + Vector2(8, 34), Vector2(rect.size.x - 16, rect.size.y - 76))
	var cell_w := grid_rect.size.x / float(cols)
	var cell_h := grid_rect.size.y / float(rows)
	var locks: Array = _copy_array(active.get("locks", []))
	var recent: Dictionary = {}
	for lock_value in _copy_array(active.get("last_lock_events", [])):
		var recent_lock: Dictionary = _copy_dict(lock_value)
		var recent_cell: Dictionary = _buffalo_lock_cell(recent_lock, rows)
		recent[int(recent_cell.get("reel", -1)) * rows + int(recent_cell.get("row", -1))] = true
	var locked: Dictionary = {}
	for lock_value in locks:
		var lock: Dictionary = _copy_dict(lock_value)
		var lock_cell: Dictionary = _buffalo_lock_cell(lock, rows)
		locked[int(lock_cell.get("reel", -1)) * rows + int(lock_cell.get("row", -1))] = lock
	for cell in range(max_cells):
		var x := cell / rows
		var y := cell % rows
		var cell_rect := Rect2(grid_rect.position + Vector2(float(x) * cell_w + 2.0, float(y) * cell_h + 2.0), Vector2(cell_w - 4.0, cell_h - 4.0))
		var lock: Dictionary = _copy_dict(locked.get(cell, {}))
		var has_lock := locked.has(cell) and _buffalo_lock_revealed(lock, feature_msec)
		var slam := has_lock and (recent.has(cell) or _buffalo_lock_just_revealed(lock, feature_msec))
		if not has_lock:
			surface.draw_rect(cell_rect, Color(trim.r, trim.g, trim.b, 0.10))
			_draw_symbol(surface, definition, "buffalo", _buffalo_feature_spin_symbol(x, y, feature_msec), cell_rect.grow(-4), true)
			var shimmer := 0.08 + 0.05 * sin(float(feature_msec + x * 89 + y * 41) * 0.014)
			surface.draw_rect(cell_rect.grow(-2), Color(light.r, light.g, light.b, shimmer), false, 1)
			continue
		_draw_buffalo_coin_cell(surface, cell_rect, lock, true, slam, accent, light, trim)
	_draw_buffalo_meter(surface, Rect2(rect.position + Vector2(10, rect.size.y - 28), Vector2(rect.size.x - 20, 13)), clampf(float(locks.size()) / float(max_cells), 0.0, 1.0), trim, light, "FILL %d/%d" % [locks.size(), max_cells])
	_draw_buffalo_ladder(surface, Rect2(rect.position + Vector2(8, 8), Vector2(rect.size.x - 16, 20)), _copy_dict(active.get("jackpot_ladder", {})), accent, light, trim, bucket)
	surface.surface_label("RESPINS %d" % int(active.get("respins_remaining", active.get("remaining_steps", 0))), rect.position + Vector2(10, rect.size.y - 42), 10, light)


func _draw_buffalo_wheel_trophy(surface, rect: Rect2, active: Dictionary, accent: Color, light: Color, trim: Color, bucket: int, feature_msec: int) -> void:
	var center := rect.position + rect.size * 0.5 + Vector2(0, -12)
	var radius := minf(rect.size.x, rect.size.y) * 0.34
	var decel := clampf(float(feature_msec) / 1600.0, 0.0, 1.0)
	var wheel_angle := deg_to_rad(float(active.get("wheel_angle", 0)) + (1.0 - pow(decel, 3.0)) * 540.0 + float(bucket) * 3.0)
	for slice in range(12):
		var angle := wheel_angle + float(slice) * TAU / 12.0
		var color := light if slice % 3 == 0 else trim if slice % 3 == 1 else accent
		surface.draw_line(center, center + Vector2(cos(angle), sin(angle)) * radius, Color(color.r, color.g, color.b, 0.70), 4)
	surface.draw_circle(center, radius, Color(accent.r, accent.g, accent.b, 0.18), false, 3)
	surface.draw_circle(center, radius * 0.18, trim)
	var pointer := center + Vector2(0, -radius - 8)
	surface.draw_polygon([pointer, pointer + Vector2(-8, -16), pointer + Vector2(8, -16)], [Color("#f8fafc")])
	var trophies: Array = _copy_array(active.get("trophy_choices", active.get("choices", [])))
	var reveals: Array = _copy_array(active.get("trophy_reveals", []))
	for index in range(mini(3, trophies.size())):
		var trophy: Dictionary = _copy_dict(trophies[index])
		var card_rect := Rect2(rect.position + Vector2(8 + index * (rect.size.x - 16) / 3.0, rect.size.y - 58), Vector2((rect.size.x - 22) / 3.0, 44))
		var revealed := false
		for reveal_value in reveals:
			var reveal: Dictionary = _copy_dict(reveal_value)
			if int(reveal.get("index", -1)) == index:
				trophy = reveal
				revealed = true
		surface.draw_rect(card_rect, Color(trim.r, trim.g, trim.b, 0.24 if not revealed else 0.52))
		surface.draw_rect(card_rect, Color(light.r, light.g, light.b, 0.32), false, 2)
		var label := "TROPHY"
		if revealed:
			label = str(trophy.get("label", trophy.get("route", ""))).to_upper().left(9)
		surface.surface_label_centered(label, card_rect.grow(-3), 9, Color("#f8fafc"))
	_draw_buffalo_ladder(surface, Rect2(rect.position + Vector2(8, 8), Vector2(rect.size.x - 16, 22)), _copy_dict(active.get("jackpot_ladder", {})), accent, light, trim, bucket)


func _draw_buffalo_meter(surface, rect: Rect2, ratio: float, color: Color, light: Color, label: String) -> void:
	var safe_ratio := clampf(ratio, 0.0, 1.0)
	surface.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.46))
	surface.draw_rect(Rect2(rect.position, Vector2(rect.size.x * safe_ratio, rect.size.y)), Color(color.r, color.g, color.b, 0.74))
	surface.draw_rect(rect, Color(light.r, light.g, light.b, 0.32), false, 1)
	surface.surface_label_centered(label.left(22), rect.grow(-1), 8, Color("#f8fafc"))


func _draw_buffalo_ladder(surface, rect: Rect2, ladder: Dictionary, accent: Color, light: Color, trim: Color, bucket: int) -> void:
	var tiers: Array = _copy_array(ladder.get("tiers", []))
	if tiers.is_empty():
		tiers = [
			{"id": "mini", "eligible": true, "lit": false},
			{"id": "minor", "eligible": true, "lit": false},
			{"id": "major", "eligible": false, "lit": false},
			{"id": "grand", "eligible": false, "lit": false},
		]
	var cell_w := rect.size.x / float(maxi(1, tiers.size()))
	for index in range(tiers.size()):
		var tier: Dictionary = _copy_dict(tiers[index])
		var tier_rect := Rect2(rect.position + Vector2(float(index) * cell_w + 1.0, 1.0), Vector2(cell_w - 2.0, rect.size.y - 2.0))
		var lit := bool(tier.get("lit", false))
		var eligible := bool(tier.get("eligible", false))
		var color := trim if str(tier.get("id", "")) == "grand" else light if eligible else accent
		var alpha := 0.54 if lit else 0.28 if eligible else 0.10
		if lit:
			alpha += 0.12 * float(bucket % 2)
		surface.draw_rect(tier_rect, Color(color.r, color.g, color.b, alpha))
		surface.draw_rect(tier_rect, Color("#f8fafc") if lit else color, false, 1)
		surface.surface_label_centered(str(tier.get("id", "")).to_upper().left(5), tier_rect.grow(-1), 8, Color("#130907") if lit else Color("#f8fafc"))


func _buffalo_stampede_phase(time_msec: int, active: Dictionary) -> String:
	if bool(active.get("complete", false)) or str(active.get("feature_phase", "")) == "celebration":
		return "celebration"
	if time_msec < 900:
		return "transition"
	return "play"


func _buffalo_fill_meter(active: Dictionary) -> Dictionary:
	var meter: Dictionary = _copy_dict(active.get("fill_meter", {}))
	if not meter.is_empty():
		return meter
	var locks: Array = _copy_array(active.get("locks", []))
	var max_cells := maxi(1, int(active.get("max_cells", maxi(1, locks.size()))))
	return {
		"locked": locks.size(),
		"max": max_cells,
		"ratio": float(locks.size()) / float(max_cells),
	}


func _buffalo_ladder_visible(active: Dictionary) -> bool:
	if str(active.get("mode", "")) == "hold_and_spin" or str(active.get("mode", "")) == "wheel":
		return true
	var ladder: Dictionary = _copy_dict(active.get("jackpot_ladder", {}))
	return bool(ladder.get("visible", false))


func _buffalo_collection_ratio(active: Dictionary) -> float:
	var meter: Dictionary = _copy_dict(active.get("collection_meter", {}))
	var value := maxi(0, int(meter.get("cycle", meter.get("value", active.get("coins_since_retrigger", 0)))))
	var threshold := maxi(1, int(meter.get("threshold", 3)))
	return clampf(float(value) / float(threshold), 0.0, 1.0)


func _buffalo_topper_reaction(state: Dictionary) -> String:
	if str(state.get("slot_type_id", "")) != "buffalo":
		return "idle"
	var active: Dictionary = _copy_dict(state.get("slot_active_bonus", {}))
	if bool(active.get("active", false)) and int(active.get("feature_total", 0)) > 0:
		return "snort"
	var tier := str(state.get("slot_celebration_tier", "none"))
	if tier == "big" or tier == "mega" or tier == "jackpot" or int(state.get("slot_payout", 0)) > 0:
		return "snort"
	return "idle"


func _buffalo_sunset_shift(state: Dictionary, bucket: int) -> float:
	var active: Dictionary = _copy_dict(state.get("slot_active_bonus", {}))
	var feature_ratio := 0.0
	if bool(active.get("active", false)):
		var total_steps := maxi(1, int(active.get("total_steps", active.get("remaining_steps", 1))))
		feature_ratio = clampf(float(int(active.get("step_index", 0))) / float(total_steps), 0.0, 1.0)
	return clampf(feature_ratio + float(bucket % 10) * 0.015, 0.0, 1.0)


func _draw_buffalo_silhouette(surface, center: Vector2, scale: float, color: Color) -> void:
	var body := Rect2(center + Vector2(-22.0, -9.0) * scale, Vector2(44.0, 18.0) * scale)
	surface.draw_rect(body, color)
	surface.draw_circle(center + Vector2(18.0, -4.0) * scale, 9.0 * scale, color)
	surface.draw_circle(center + Vector2(-18.0, -5.0) * scale, 6.0 * scale, color)
	surface.draw_line(center + Vector2(23.0, -9.0) * scale, center + Vector2(34.0, -16.0) * scale, color, maxf(1.0, 3.0 * scale))
	surface.draw_line(center + Vector2(23.0, -1.0) * scale, center + Vector2(34.0, 6.0) * scale, color, maxf(1.0, 3.0 * scale))
	for leg in range(4):
		var lx := -15.0 + float(leg) * 10.0
		surface.draw_line(center + Vector2(lx, 7.0) * scale, center + Vector2(lx - 3.0, 18.0) * scale, color, maxf(1.0, 2.0 * scale))


func _draw_status_panel(surface, state: Dictionary, skin: Dictionary, accent: Color, light: Color, trim: Color) -> void:
	var left := _rect_from_dict(skin.get("tease_panel", {}))
	var right := _rect_from_dict(skin.get("feature_panel", {}))
	_draw_panel(surface, left, "CREDITS", accent)
	surface.surface_label("$%d" % int(state.get("bankroll", 0)), left.position + Vector2(14, 52), 18, light)
	surface.surface_label("HEAT %d" % int(state.get("suspicion_level", 0)), left.position + Vector2(14, 80), 13, accent)
	surface.surface_label("BET $%d" % int(state.get("slot_selected_bet", 10)), left.position + Vector2(14, 106), 13, trim)
	if bool(state.get("slot_nudge_available", false)):
		var nudge_label := "NUDGE WINDOW" if bool(state.get("slot_nudge_tease_window_active", false)) else "NUDGE"
		surface.surface_label(nudge_label, left.position + Vector2(14, 134), 13, Color("#ff3f75"))
		var hint := str(state.get("slot_nudge_tease_outcome_hint", ""))
		if not hint.is_empty():
			surface.surface_label(hint.to_upper().left(16), left.position + Vector2(14, 154), 10, trim)
	_draw_panel(surface, right, "FEATURE", light)
	var active: Dictionary = _copy_dict(state.get("slot_active_bonus", {}))
	if bool(active.get("active", false)) and not bool(active.get("complete", false)):
		surface.surface_label(str(active.get("display_mode", active.get("mode", "bonus"))).replace("_", " ").to_upper().left(18), right.position + Vector2(14, 50), 12, light)
		surface.surface_label("$%d" % int(active.get("feature_total", active.get("pending_award", 0))), right.position + Vector2(14, 78), 18, trim)
		surface.surface_label("LEFT %d" % int(active.get("remaining_steps", 0)), right.position + Vector2(14, 106), 13, accent)
	else:
		surface.surface_label(str(skin.get("feature_name", "")).to_upper().left(18), right.position + Vector2(14, 50), 12, trim)
		surface.surface_label("READY", right.position + Vector2(14, 78), 16, light)


func _draw_panel(surface, rect: Rect2, title: String, color: Color) -> void:
	surface.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.34))
	surface.draw_rect(rect, Color(color.r, color.g, color.b, 0.24), false, 1)
	surface.surface_label(title, rect.position + Vector2(12, 22), 13, color)


func _draw_result_strip(surface, state: Dictionary, skin: Dictionary, accent: Color, light: Color, time_msec: int) -> void:
	var rect := _rect_from_dict(skin.get("result_strip", {}))
	surface.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.55))
	surface.draw_rect(rect, Color(light.r, light.g, light.b, 0.28), false, 1)
	var payload := _result_strip_payload(state, time_msec)
	var message := str(payload.get("message", "Pick a bet and spin."))
	var net := int(payload.get("net", 0))
	surface.surface_label(message.left(74), rect.position + Vector2(14, 28), 15, Color("#f8fafc"))
	surface.surface_label(str(payload.get("amount_text", "$0 / +0")), rect.position + Vector2(rect.size.x - 150, 28), 15, accent if net < 0 else light)


func _result_strip_payload(state: Dictionary, time_msec: int) -> Dictionary:
	var reveal_ready := _result_reveal_ready(state, time_msec)
	var message := str(state.get("result_message", "Pick a bet and spin."))
	var payout := int(state.get("slot_payout", 0))
	var net := int(state.get("slot_net", 0))
	if not reveal_ready:
		message = str(state.get("slot_previous_result_message", "Pick a bet and spin."))
		payout = int(state.get("slot_previous_payout", 0))
		net = int(state.get("slot_previous_net", 0))
	else:
		var reason := str(state.get("slot_win_reason", ""))
		if not reason.is_empty():
			if payout > 0:
				message = "WIN $%d - %s" % [payout, reason]
			else:
				message = reason
	return {
		"message": message,
		"payout": payout,
		"net": net,
		"amount_text": "$%d / %+d" % [payout, net],
		"reveal_ready": reveal_ready,
	}


func _result_reveal_ready(state: Dictionary, time_msec: int) -> bool:
	if str(state.get("slot_animation_id", "")).is_empty():
		return true
	var timeline: Array = _copy_array(state.get("slot_reel_timeline", []))
	if timeline.is_empty():
		return true
	var last_settle_sec := 0.0
	for entry_value in timeline:
		var entry: Dictionary = _copy_dict(entry_value)
		last_settle_sec = maxf(last_settle_sec, float(entry.get("settle_end", entry.get("stop_time", 0.0))))
	var reveal_msec := int(ceil(last_settle_sec * 1000.0)) + 180
	return time_msec >= reveal_msec


func _draw_celebration_overlay(surface, state: Dictionary, skin: Dictionary, signature: Dictionary, accent: Color, light: Color, trim: Color) -> void:
	var tier := str(signature.get("celebration_tier", "none"))
	if tier == "none" or tier == "tease":
		return
	if not bool(signature.get("celebration_overlay_visible", false)):
		return
	var particle_count := maxi(0, int(signature.get("particle_count", 0)))
	var rect := _rect_from_dict(skin.get("reel_window", {})).grow(18)
	var center := rect.position + rect.size * 0.5
	var plan: Dictionary = _copy_dict(state.get("slot_animation_plan", {}))
	var visual_time := int(state.get("slot_visual_time_msec", 0))
	var shake := _shake_offset(tier, visual_time, plan)
	var tier_color := trim if tier == "jackpot" else light if tier == "mega" else accent
	# Color-cycling celebration border for high tiers (build spec section 9.4): the
	# manifest publishes border_color_phase; cycle the border/banner ring hue from it so
	# BIG WIN / JACKPOT moments animate their frame instead of sitting on a static accent.
	var border_color := tier_color
	if bool(signature.get("color_cycle_active", false)):
		var hue := float(signature.get("color_cycle_hue", 0.0))
		border_color = Color.from_hsv(fposmod(maxf(hue, 0.0), 1.0), 0.74, 1.0)
	for ray in range(18 if tier == "jackpot" else 12):
		var angle := float(ray) * TAU / float(18 if tier == "jackpot" else 12) + float(int(signature.get("time_bucket", 0))) * 0.05
		var length := rect.size.x * (0.32 + 0.02 * float(ray % 4))
		surface.draw_line(center + shake, center + shake + Vector2(cos(angle), sin(angle)) * length, Color(border_color.r, border_color.g, border_color.b, 0.24), 3)
	for i in range(particle_count):
		var px := rect.position.x + fposmod(float(i * 37 + int(signature.get("time_bucket", 0)) * 11), rect.size.x)
		var py := rect.position.y + fposmod(float(i * 19 + int(signature.get("time_bucket", 0)) * 7), rect.size.y)
		var radius := 2.0 + float(i % 4)
		surface.draw_circle(Vector2(px, py) + shake, radius, Color(border_color.r, border_color.g, border_color.b, 0.30))
	var border := _rect_from_dict(skin.get("silhouette", {"x": 26, "y": 16, "w": 908, "h": 500})).grow(4)
	surface.draw_rect(border, Color(border_color.r, border_color.g, border_color.b, 0.35), false, 4)


func _draw_controls(surface, state: Dictionary, skin: Dictionary, accent: Color, light: Color, trim: Color) -> void:
	var rect := _rect_from_dict(skin.get("controls", {}))
	surface.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.35))
	var active_bonus := bool(state.get("slot_active_bonus_active", false))
	if active_bonus:
		var active: Dictionary = _copy_dict(state.get("slot_active_bonus", {}))
		var family := str(active.get("family", state.get("slot_type_id", "pinball")))
		var mode := str(active.get("mode", ""))
		if family == "buffalo":
			if mode == "wheel":
				_draw_button(surface, Rect2(rect.position.x + 28, rect.position.y + 18, 132, 42), "LEFT", "slot_bonus_left", 0, accent)
				_draw_button(surface, Rect2(rect.position.x + 190, rect.position.y + 10, 220, 56), "PICK", "slot_bonus_launch", 0, light)
				_draw_button(surface, Rect2(rect.position.x + 438, rect.position.y + 18, 132, 42), "RIGHT", "slot_bonus_right", 0, accent)
			elif mode == "hold_and_spin":
				_draw_button(surface, Rect2(rect.position.x + 220, rect.position.y + 10, 220, 56), "RESPIN", "slot_bonus_launch", 0, light)
			else:
				_draw_button(surface, Rect2(rect.position.x + 220, rect.position.y + 10, 220, 56), "FREE SPIN", "slot_bonus_launch", 0, light)
			return
		_draw_button(surface, Rect2(rect.position.x + 28, rect.position.y + 18, 132, 42), "LEFT", "slot_bonus_left", 0, accent)
		_draw_button(surface, Rect2(rect.position.x + 190, rect.position.y + 10, 220, 56), "LAUNCH", "slot_bonus_launch", 0, light)
		_draw_button(surface, Rect2(rect.position.x + 438, rect.position.y + 18, 132, 42), "RIGHT", "slot_bonus_right", 0, accent)
		_draw_button(surface, Rect2(rect.position.x + 600, rect.position.y + 18, 132, 42), "TILT", "slot_bonus_tilt", 0, trim)
		return
	var options: Array = _copy_array(state.get("slot_bet_options", []))
	var selected_id := str(state.get("slot_selected_bet_id", "bet_2"))
	var control_layout: Dictionary = _slot_control_layout(rect, options.size(), bool(state.get("slot_nudge_available", false)))
	var bet_rects: Array = _copy_array(control_layout.get("bet_rects", []))
	for index in range(options.size()):
		var option: Dictionary = options[index]
		if index >= bet_rects.size():
			continue
		var bet_rect: Rect2 = bet_rects[index]
		var selected := selected_id == str(option.get("id", ""))
		_draw_button(surface, bet_rect, "$%d" % int(option.get("total_credits", 0)), "slot_bet", index, light if selected else trim, selected)
	_draw_button(surface, control_layout.get("spin_rect", Rect2()), "SPIN", "slot_spin", 0, light)
	if bool(state.get("slot_nudge_available", false)):
		_draw_button(surface, control_layout.get("nudge_rect", Rect2()), "NUDGE!", "slot_nudge", 0, accent)
	_draw_button(surface, control_layout.get("auto_rect", Rect2()), "AUTO" if not bool(state.get("slot_autoplay_active", false)) else "AUTO ON", "slot_auto_toggle", 0, trim, bool(state.get("slot_autoplay_active", false)))


func _slot_control_layout(rect: Rect2, bet_count: int, show_nudge: bool) -> Dictionary:
	var margin := 16.0
	var bet_gap := 6.0
	var action_gap := 12.0
	var auto_w := 92.0
	var nudge_w := 96.0
	var spin_w := 150.0 if show_nudge else 170.0
	var action_h := minf(52.0, maxf(42.0, rect.size.y - 24.0))
	var action_y := rect.position.y + (rect.size.y - action_h) * 0.5
	var right_edge := rect.position.x + rect.size.x - margin
	var auto_rect := Rect2(Vector2(right_edge - auto_w, action_y + 3.0), Vector2(auto_w, action_h - 6.0))
	var nudge_rect := Rect2()
	var spin_right := auto_rect.position.x - action_gap
	if show_nudge:
		nudge_rect = Rect2(Vector2(spin_right - nudge_w, action_y + 3.0), Vector2(nudge_w, action_h - 6.0))
		spin_right = nudge_rect.position.x - action_gap
	var spin_rect := Rect2(Vector2(spin_right - spin_w, action_y), Vector2(spin_w, action_h))
	var bet_rects: Array = []
	var safe_count := maxi(0, bet_count)
	if safe_count > 0:
		var bet_left := rect.position.x + margin
		var bet_right := spin_rect.position.x - action_gap
		var available := maxf(44.0 * float(safe_count), bet_right - bet_left)
		var bet_w := clampf((available - bet_gap * float(maxi(0, safe_count - 1))) / float(safe_count), 44.0, 60.0)
		var bet_h := minf(38.0, maxf(32.0, rect.size.y - 30.0))
		var bet_y := rect.position.y + (rect.size.y - bet_h) * 0.5
		for index in range(safe_count):
			bet_rects.append(Rect2(Vector2(bet_left + float(index) * (bet_w + bet_gap), bet_y), Vector2(bet_w, bet_h)))
	return {
		"bet_rects": bet_rects,
		"spin_rect": spin_rect,
		"nudge_rect": nudge_rect,
		"auto_rect": auto_rect,
	}


func _draw_button(surface, rect: Rect2, label: String, action: String, index: int, color: Color, selected: bool = false) -> void:
	var hovered := bool(surface.surface_region_hovered(action, index))
	var fill_alpha := 0.30 if selected else 0.22 if hovered else 0.12
	surface.draw_rect(rect, Color(color.r, color.g, color.b, fill_alpha))
	surface.draw_rect(rect, Color("#f8fafc") if hovered else color, false, 2 if hovered or selected else 1)
	surface.surface_label_centered(label, rect.grow(-4), 15, Color("#f8fafc") if hovered else color)
	surface.surface_add_hit(rect, action, index)


func _draw_back_control(surface, accent: Color, light: Color) -> void:
	var rect := Rect2(806, 24, 92, 34)
	var hovered := bool(surface.surface_region_hovered("surface_back"))
	var color := light if hovered else accent
	surface.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.46))
	surface.draw_rect(rect, Color(color.r, color.g, color.b, 0.22 if hovered else 0.12))
	surface.draw_rect(rect, Color("#f8fafc") if hovered else color, false, 2 if hovered else 1)
	surface.surface_label_centered("LEAVE", rect.grow(-4), 13, Color("#f8fafc") if hovered else color)
	surface.surface_add_hit(rect, "surface_back")


func _symbol_label(symbol: String) -> String:
	if symbol == "GOLD_TOKEN":
		return "G"
	if symbol == "DOUBLE_7":
		return "D7"
	if symbol == "SUNSET_2X":
		return "2X"
	if symbol == "SUNSET_3X":
		return "3X"
	if symbol.length() > 4:
		return symbol.left(2)
	return symbol


func _rect_from_dict(value: Variant) -> Rect2:
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var dict: Dictionary = value
	return Rect2(Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0))), Vector2(float(dict.get("w", 0.0)), float(dict.get("h", 0.0))))


func _rect_payload(rect: Rect2) -> Dictionary:
	return {
		"x": snappedf(rect.position.x, 0.001),
		"y": snappedf(rect.position.y, 0.001),
		"w": snappedf(rect.size.x, 0.001),
		"h": snappedf(rect.size.y, 0.001),
	}


func _rect_intersection(a: Rect2, b: Rect2) -> Rect2:
	var left: float = maxf(a.position.x, b.position.x)
	var top: float = maxf(a.position.y, b.position.y)
	var right: float = minf(a.end.x, b.end.x)
	var bottom: float = minf(a.end.y, b.end.y)
	if right <= left or bottom <= top:
		return Rect2(Vector2(left, top), Vector2.ZERO)
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _read_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return value


func _read_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value


func _array_read_size(value: Variant) -> int:
	if typeof(value) != TYPE_ARRAY:
		return 0
	return (value as Array).size()
