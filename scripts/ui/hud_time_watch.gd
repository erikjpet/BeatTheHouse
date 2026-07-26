class_name HudTimeWatch
extends Control

var _minute_of_day := 0


func _ready() -> void:
	custom_minimum_size = VisualStyle.HUD_WATCH_FACE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_minute_of_day(value: int) -> void:
	var normalized := posmod(value, 1440)
	if normalized == _minute_of_day:
		return
	_minute_of_day = normalized
	queue_redraw()


func current_snapshot() -> Dictionary:
	var minute := _minute_of_day % 60
	var hour := int(floor(float(_minute_of_day) / 60.0)) % 24
	return {
		"minute_of_day": _minute_of_day,
		"hour_24": hour,
		"minute": minute,
		"hour_hand_turn": fposmod((float(hour % 12) + float(minute) / 60.0) / 12.0, 1.0),
		"minute_hand_turn": float(minute) / 60.0,
	}


func _draw() -> void:
	var center := size * 0.5
	var radius := maxf(1.0, minf(size.x, size.y) * 0.5 - VisualStyle.HUD_WATCH_BEZEL_WIDTH)
	draw_circle(center, radius, VisualStyle.role("surface_overlay"))
	draw_arc(center, radius, 0.0, TAU, 32, VisualStyle.role("accent_primary"), VisualStyle.HUD_WATCH_BEZEL_WIDTH, false)
	for tick_index in range(12):
		var tick_angle := TAU * float(tick_index) / 12.0 - PI * 0.5
		var outer := center + Vector2.from_angle(tick_angle) * radius * 0.82
		var inner_scale := 0.64 if tick_index % 3 == 0 else 0.72
		var inner := center + Vector2.from_angle(tick_angle) * radius * inner_scale
		draw_line(inner, outer, VisualStyle.role("text_secondary"), VisualStyle.HUD_WATCH_TICK_WIDTH, false)
	var snapshot := current_snapshot()
	var hour_angle := TAU * float(snapshot.get("hour_hand_turn", 0.0)) - PI * 0.5
	var minute_angle := TAU * float(snapshot.get("minute_hand_turn", 0.0)) - PI * 0.5
	draw_line(center, center + Vector2.from_angle(hour_angle) * radius * 0.46, VisualStyle.role("text_primary"), VisualStyle.HUD_WATCH_HAND_WIDTH, false)
	draw_line(center, center + Vector2.from_angle(minute_angle) * radius * 0.68, VisualStyle.role("focus"), VisualStyle.HUD_WATCH_HAND_WIDTH, false)
	draw_circle(center, VisualStyle.HUD_WATCH_HAND_WIDTH, VisualStyle.role("accent_secondary"))
