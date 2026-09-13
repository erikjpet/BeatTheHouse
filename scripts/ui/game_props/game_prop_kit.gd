class_name GamePropKit
extends RefCounted

const C_WHITE := Color("#f7f1df")
const C_SOFT := Color("#9aa1ad")
const C_SHADOW := Color("#05060a")
const C_YELLOW := Color("#f3ca52")


static func phase(object_data: Dictionary) -> float:
	var identity: Variant = object_data.get("object_id", object_data.get("id", object_data.get("source_id", 0)))
	return float(absi(hash(identity)) % 1000) / 1000.0


static func pulse(clock: float, phase_value: float, selected: bool) -> float:
	return 0.34 + absf(sin(clock * (3.2 if selected else 1.65) + phase_value * TAU)) * (0.30 if selected else 0.13)


static func draw_base_shadow(canvas: CanvasItem, safe: Rect2, color: Color) -> void:
	canvas.draw_rect(Rect2(safe.position + Vector2(safe.size.x * 0.14, safe.size.y * 0.92), Vector2(safe.size.x * 0.72, maxf(2.0, safe.size.y * 0.045))), Color(color.r, color.g, color.b, 0.24))


static func draw_state(canvas: CanvasItem, safe: Rect2, selected: bool, disabled: bool) -> void:
	if selected:
		canvas.draw_rect(safe.grow(1.0), Color(1.0, 1.0, 1.0, 0.78), false, 2.0)
	if disabled:
		canvas.draw_rect(safe, Color(0.0, 0.0, 0.0, 0.50))
		canvas.draw_line(safe.position + Vector2(safe.size.x * 0.10, safe.size.y * 0.18), safe.position + Vector2(safe.size.x * 0.90, safe.size.y * 0.80), C_SOFT, 3.0)


static func draw_die(canvas: CanvasItem, rect: Rect2, value: int, pip_color: Color = C_SHADOW, face_color: Color = C_WHITE) -> void:
	canvas.draw_rect(rect, face_color)
	canvas.draw_rect(rect, Color("#424653"), false, 1.0)
	var radius := clampf(minf(rect.size.x, rect.size.y) * 0.10, 1.0, 2.2)
	match clampi(value, 1, 6):
		1:
			canvas.draw_circle(rect.get_center(), radius, pip_color)
		2:
			_draw_pip(canvas, rect, 0.28, 0.28, radius, pip_color)
			_draw_pip(canvas, rect, 0.72, 0.72, radius, pip_color)
		3:
			_draw_pip(canvas, rect, 0.28, 0.28, radius, pip_color)
			canvas.draw_circle(rect.get_center(), radius, pip_color)
			_draw_pip(canvas, rect, 0.72, 0.72, radius, pip_color)
		4:
			_draw_pip(canvas, rect, 0.28, 0.28, radius, pip_color)
			_draw_pip(canvas, rect, 0.72, 0.28, radius, pip_color)
			_draw_pip(canvas, rect, 0.28, 0.72, radius, pip_color)
			_draw_pip(canvas, rect, 0.72, 0.72, radius, pip_color)
		5:
			_draw_pip(canvas, rect, 0.28, 0.28, radius, pip_color)
			_draw_pip(canvas, rect, 0.72, 0.28, radius, pip_color)
			canvas.draw_circle(rect.get_center(), radius, pip_color)
			_draw_pip(canvas, rect, 0.28, 0.72, radius, pip_color)
			_draw_pip(canvas, rect, 0.72, 0.72, radius, pip_color)
		6:
			_draw_pip(canvas, rect, 0.28, 0.24, radius, pip_color)
			_draw_pip(canvas, rect, 0.72, 0.24, radius, pip_color)
			_draw_pip(canvas, rect, 0.28, 0.50, radius, pip_color)
			_draw_pip(canvas, rect, 0.72, 0.50, radius, pip_color)
			_draw_pip(canvas, rect, 0.28, 0.76, radius, pip_color)
			_draw_pip(canvas, rect, 0.72, 0.76, radius, pip_color)


static func _draw_pip(canvas: CanvasItem, rect: Rect2, x_ratio: float, y_ratio: float, radius: float, color: Color) -> void:
	canvas.draw_circle(rect.position + rect.size * Vector2(x_ratio, y_ratio), radius, color)
