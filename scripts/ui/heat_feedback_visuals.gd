class_name HeatFeedbackVisuals
extends RefCounted

# Shared presentation math for the persistent police-light Heat pressure. Both
# environment and game canvases call this renderer so their intensity, timing,
# and thresholds cannot drift apart.

const POLICE_RED := Color("#ff173d")
const POLICE_BLUE := Color("#1f64ff")
const GAIN_DURATION_SEC := 0.50
const GAIN_ATTACK_SEC := 0.055
const GAIN_HOLD_SEC := 0.070


static func police_pressure_profile(level_value: int, elapsed_sec: float) -> Dictionary:
	var level := clampi(level_value, 0, 100)
	if level <= 0:
		return {"visible": false, "level": 0}
	var elapsed := maxf(0.0, elapsed_sec)
	var cycle := fposmod(elapsed * 4.2, 2.0)
	var red_active := cycle < 1.0
	var strobe := 0.58 + 0.42 * absf(sin(elapsed * 18.0))
	var red_phase := strobe if red_active else 0.06
	var blue_phase := strobe if not red_active else 0.06
	var subtle := clampf(float(level) / 50.0, 0.0, 1.0)
	var high := clampf(float(level - 50) / 50.0, 0.0, 1.0)
	return {
		"visible": true,
		"level": level,
		"red_active": red_active,
		"red_phase": red_phase,
		"blue_phase": blue_phase,
		"subtle": subtle,
		"high": high,
		"low_alpha": 0.010 + subtle * 0.035,
		"base_alpha": 0.040 + high * 0.135,
	}


static func draw_police_pressure(canvas: CanvasItem, board_size: Vector2, level: int, elapsed_sec: float) -> void:
	var profile := police_pressure_profile(level, elapsed_sec)
	if not bool(profile.get("visible", false)):
		return
	var safe_board := Vector2(maxf(1.0, board_size.x), maxf(1.0, board_size.y))
	var red_phase := float(profile.get("red_phase", 0.0))
	var blue_phase := float(profile.get("blue_phase", 0.0))
	if level < 50:
		var alpha := float(profile.get("low_alpha", 0.0))
		_draw_side_band(canvas, safe_board, POLICE_BLUE, alpha * blue_phase, true)
		if level >= 25:
			_draw_side_band(canvas, safe_board, POLICE_RED, alpha * 0.85 * red_phase, false)
		return
	var high := float(profile.get("high", 0.0))
	var base_alpha := float(profile.get("base_alpha", 0.0))
	var red_active := bool(profile.get("red_active", false))
	var active_color := POLICE_RED if red_active else POLICE_BLUE
	var inactive_color := POLICE_BLUE if red_active else POLICE_RED
	var active_phase := red_phase if red_active else blue_phase
	var inactive_phase := blue_phase if red_active else red_phase
	canvas.draw_rect(Rect2(Vector2.ZERO, safe_board), Color(active_color.r, active_color.g, active_color.b, 0.020 + high * 0.055 * active_phase))
	_draw_side_band(canvas, safe_board, POLICE_RED, base_alpha * red_phase, false)
	_draw_side_band(canvas, safe_board, POLICE_BLUE, base_alpha * blue_phase, true)
	var top_alpha := base_alpha * (0.55 + active_phase * 0.32)
	canvas.draw_rect(Rect2(0, 0, safe_board.x, 10), Color(active_color.r, active_color.g, active_color.b, top_alpha * active_phase))
	canvas.draw_rect(Rect2(0, 10, safe_board.x, 8), Color(inactive_color.r, inactive_color.g, inactive_color.b, top_alpha * inactive_phase * 0.35))
	canvas.draw_rect(Rect2(0, safe_board.y - 12, safe_board.x, 12), Color(active_color.r, active_color.g, active_color.b, top_alpha * active_phase * 0.55))
	var sweep_x := fposmod(maxf(0.0, elapsed_sec) * (180.0 + high * 120.0), safe_board.x + 220.0) - 110.0
	canvas.draw_rect(Rect2(sweep_x, 0, 72 + high * 54, safe_board.y), Color(active_color.r, active_color.g, active_color.b, base_alpha * 0.28 * active_phase))


static func heat_gain_intensity(applied_amount: int) -> float:
	if applied_amount <= 0:
		return 0.0
	return pow(clampf(float(applied_amount - 1) / 19.0, 0.0, 1.0), 0.62)


static func heat_gain_pulse_strength(elapsed_sec: float) -> float:
	var elapsed := clampf(elapsed_sec, 0.0, GAIN_DURATION_SEC)
	if elapsed <= GAIN_ATTACK_SEC:
		return clampf(elapsed / GAIN_ATTACK_SEC, 0.0, 1.0)
	if elapsed <= GAIN_ATTACK_SEC + GAIN_HOLD_SEC:
		return 1.0
	var fade_duration := GAIN_DURATION_SEC - GAIN_ATTACK_SEC - GAIN_HOLD_SEC
	var fade_progress := clampf((elapsed - GAIN_ATTACK_SEC - GAIN_HOLD_SEC) / fade_duration, 0.0, 1.0)
	return pow(1.0 - fade_progress, 1.45)


static func _draw_side_band(canvas: CanvasItem, board_size: Vector2, color: Color, alpha: float, left_side: bool) -> void:
	for index in range(5):
		var width := 18.0 + float(index) * 12.0
		var band_alpha := alpha * (1.0 - float(index) * 0.16)
		var x := 0.0 if left_side else board_size.x - width
		canvas.draw_rect(Rect2(x, 0, width, board_size.y), Color(color.r, color.g, color.b, maxf(0.0, band_alpha)))
