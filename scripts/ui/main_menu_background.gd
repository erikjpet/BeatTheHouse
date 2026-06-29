class_name MainMenuBackground
extends Control

# Animated rainy neon street for the main menu.

var time_seconds := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	time_seconds += delta
	queue_redraw()


func _draw() -> void:
	var size := get_rect().size
	if size.x <= 1.0 or size.y <= 1.0:
		return
	_draw_sky(size)
	_draw_city(size)
	_draw_street(size)
	_draw_cars(size)
	_draw_people(size)
	_draw_rain(size)
	_draw_vignette(size)


func _draw_sky(size: Vector2) -> void:
	var bands := 18
	for i in range(bands):
		var ratio := float(i) / float(max(1, bands - 1))
		var color := Color("#060712").lerp(Color("#14102e"), ratio)
		draw_rect(Rect2(0, ratio * size.y * 0.68, size.x, size.y / bands + 2.0), color)
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.0, 0.0, 0.0, 0.12))


func _draw_city(size: Vector2) -> void:
	var ground_y := size.y * 0.62
	for i in range(14):
		var width := 70.0 + float((i * 23) % 80)
		var height := 120.0 + float((i * 47) % 210)
		var x := fmod(float(i) * 118.0 - 40.0, size.x + 160.0) - 80.0
		var rect := Rect2(x, ground_y - height, width, height)
		draw_rect(rect, Color("#090a18"))
		var edge := Color("#1c2550") if i % 2 == 0 else Color("#2a1446")
		draw_rect(Rect2(rect.position, Vector2(2, rect.size.y)), edge)
		draw_rect(Rect2(rect.position + Vector2(rect.size.x - 2.0, 0), Vector2(2, rect.size.y)), edge)
		_draw_windows(rect, i)
	_draw_neon_sign(Vector2(size.x * 0.13, ground_y - 150.0), "OPEN", Color("#00f5ff"))
	_draw_neon_sign(Vector2(size.x * 0.78, ground_y - 185.0), "24 HR", Color("#ff2d78"))


func _draw_windows(rect: Rect2, index: int) -> void:
	var cols: int = max(1, int(rect.size.x / 18.0))
	var rows: int = max(1, int(rect.size.y / 22.0))
	for y in range(rows):
		for x in range(cols):
			if ((x * 7 + y * 11 + index) % 5) == 0:
				continue
			var wx := rect.position.x + 9.0 + float(x) * 18.0
			var wy := rect.position.y + 12.0 + float(y) * 22.0
			var color := Color("#00f5ff") if (x + y + index) % 3 == 0 else Color("#ffe45c")
			draw_rect(Rect2(wx, wy, 6.0, 10.0), _alpha(color, 0.48))


func _draw_neon_sign(pos: Vector2, text: String, color: Color) -> void:
	draw_rect(Rect2(pos - Vector2(10, 8), Vector2(84, 34)), Color("#080914"))
	draw_rect(Rect2(pos - Vector2(10, 8), Vector2(84, 34)), _alpha(color, 0.28), false, 2.0)
	draw_string(ThemeDB.fallback_font, pos + Vector2(2, 15), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)


func _draw_street(size: Vector2) -> void:
	var horizon := size.y * 0.62
	draw_polygon([
		Vector2(0, horizon),
		Vector2(size.x, horizon),
		Vector2(size.x, size.y),
		Vector2(0, size.y),
	], [Color("#080814"), Color("#080814"), Color("#05050b"), Color("#05050b")])
	for i in range(18):
		var y := horizon + float(i) * ((size.y - horizon) / 18.0)
		var alpha := 0.15 + float(i) * 0.012
		draw_line(Vector2(0, y), Vector2(size.x, y + 12.0), Color("#00f5ff", alpha), 1.0)
	for i in range(8):
		var y2 := horizon + 32.0 + float(i) * 34.0
		draw_rect(Rect2(size.x * 0.47, y2, size.x * 0.06, 4.0), Color("#ffe45c", 0.34))
	_draw_reflection(Vector2(size.x * 0.15, horizon + 62.0), Color("#ff2d78"))
	_draw_reflection(Vector2(size.x * 0.78, horizon + 76.0), Color("#00f5ff"))


func _draw_reflection(pos: Vector2, color: Color) -> void:
	for i in range(7):
		draw_rect(Rect2(pos.x - 44.0 + float(i) * 9.0, pos.y + float(i) * 8.0, 80.0 - float(i) * 7.0, 3.0), _alpha(color, 0.12))


func _draw_cars(size: Vector2) -> void:
	var road_y := size.y * 0.75
	var car_a_x := fmod(time_seconds * 125.0, size.x + 180.0) - 140.0
	var car_b_x := size.x - fmod(time_seconds * 88.0 + 220.0, size.x + 220.0)
	_draw_car(Vector2(car_a_x, road_y), Color("#ff2d78"), 1.0, 1.0)
	_draw_car(Vector2(car_b_x, road_y + 72.0), Color("#00f5ff"), 1.18, -1.0)


func _draw_car(pos: Vector2, color: Color, scale: float, direction: float) -> void:
	var body := Rect2(pos, Vector2(118, 26) * scale)
	draw_rect(body, _alpha(color, 0.82))
	draw_rect(Rect2(body.position + Vector2(24, -16) * scale, Vector2(52, 18) * scale), _alpha(color, 0.68))
	draw_circle(body.position + Vector2(24, 28) * scale, 7.0 * scale, Color("#020208"))
	draw_circle(body.position + Vector2(92, 28) * scale, 7.0 * scale, Color("#020208"))
	var lamp_x := body.position.x + (body.size.x if direction > 0.0 else -34.0 * scale)
	draw_polygon([
		Vector2(lamp_x, body.position.y + 8.0 * scale),
		Vector2(lamp_x + 90.0 * direction * scale, body.position.y - 10.0 * scale),
		Vector2(lamp_x + 90.0 * direction * scale, body.position.y + 34.0 * scale),
	], [Color("#ffe45c", 0.24), Color("#ffe45c", 0.0), Color("#ffe45c", 0.0)])


func _draw_people(size: Vector2) -> void:
	var base_y := size.y * 0.64
	for i in range(6):
		var speed := 18.0 + float(i * 7)
		var x := fmod(float(i) * 190.0 + time_seconds * speed, size.x + 80.0) - 40.0
		var y := base_y + float((i * 31) % 110)
		_draw_person(Vector2(x, y), i)


func _draw_person(pos: Vector2, index: int) -> void:
	var coat := Color("#101427") if index % 2 == 0 else Color("#171022")
	draw_circle(pos + Vector2(0, -18), 5.0, Color("#d8e8ea"))
	draw_rect(Rect2(pos + Vector2(-5, -12), Vector2(10, 24)), coat)
	draw_line(pos + Vector2(-4, 12), pos + Vector2(-10, 28), Color("#d8e8ea", 0.75), 2.0)
	draw_line(pos + Vector2(4, 12), pos + Vector2(10, 28), Color("#d8e8ea", 0.75), 2.0)
	draw_arc(pos + Vector2(0, -24), 17.0, PI, TAU, 12, Color("#ff2d78" if index % 2 == 0 else "#00f5ff"), 2.0)
	draw_line(pos + Vector2(0, -24), pos + Vector2(0, 2), Color("#d8e8ea", 0.55), 1.0)


func _draw_rain(size: Vector2) -> void:
	for i in range(170):
		var x := fmod(float(i * 47) + time_seconds * 210.0, size.x + 90.0) - 45.0
		var y := fmod(float(i * 83) + time_seconds * 430.0, size.y + 120.0) - 70.0
		var alpha := 0.18 + float((i * 13) % 30) / 160.0
		draw_line(Vector2(x, y), Vector2(x - 8.0, y + 28.0), Color("#d8e8ea", alpha), 1.0)


func _draw_vignette(size: Vector2) -> void:
	draw_rect(Rect2(0, 0, size.x, 18), Color(0, 0, 0, 0.32))
	draw_rect(Rect2(0, size.y - 40.0, size.x, 40.0), Color(0, 0, 0, 0.38))
	draw_rect(Rect2(0, 0, 24.0, size.y), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(size.x - 24.0, 0, 24.0, size.y), Color(0, 0, 0, 0.22))


func _alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
