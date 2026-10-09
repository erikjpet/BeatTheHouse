class_name StreetCrapsCircleProp
extends RefCounted

# Floor-level Street Craps painter. It deliberately has no cabinet, legs, rail,
# or felt body: the playable object is chalk, loose cash, and dice on pavement.

const KitScript := preload("res://scripts/ui/game_props/game_prop_kit.gd")
const EMPTY_STATE: Dictionary = {}
const C_CHALK := Color("#e4dcc8")
const C_CHALK_DIM := Color("#aaa494")
const C_PAVEMENT_LIGHT := Color("#454a4b")
const C_PAVEMENT_DARK := Color("#202426")
const C_CASH := Color("#719269")
const C_CASH_EDGE := Color("#b8c9a7")
const C_SHOE := Color("#11131a")
const C_DENIM := Color("#263c52")
const C_BROWN := Color("#4b3022")
const C_RED := Color("#d04455")


# Draws the full floor circle with live dice, point, and dispersed state.
static func draw(canvas: CanvasItem, rect: Rect2, object_data: Dictionary, accent: Color, selected: bool, disabled: bool, flicker: float) -> void:
	var safe := Rect2(rect.position + Vector2(rect.size.x * 0.03, rect.size.y * 0.06), Vector2(rect.size.x * 0.94, rect.size.y * 0.88))
	var visual: Dictionary = object_data.get("visual_state", EMPTY_STATE) if typeof(object_data.get("visual_state", EMPTY_STATE)) == TYPE_DICTIONARY else EMPTY_STATE
	var phase_value := KitScript.phase(object_data)
	var pulse := KitScript.pulse(flicker, phase_value, selected)
	_draw_pavement_marks(canvas, safe)
	if safe.size.x < 64.0 or safe.size.y < 38.0:
		_draw_small(canvas, safe, visual)
		KitScript.draw_state(canvas, safe, selected, disabled)
		return
	_draw_player_edges(canvas, safe)
	_draw_chalk_game(canvas, safe, visual, accent, pulse)
	KitScript.draw_state(canvas, safe, selected, disabled)


# Draws the cheap ground-level silhouette used by distant Web scenes.
static func draw_low_detail(canvas: CanvasItem, rect: Rect2, object_data: Dictionary, accent: Color, disabled: bool, _flicker: float) -> void:
	var safe := rect.grow(-3.0)
	var visual: Dictionary = object_data.get("visual_state", EMPTY_STATE) if typeof(object_data.get("visual_state", EMPTY_STATE)) == TYPE_DICTIONARY else EMPTY_STATE
	_draw_pavement_marks(canvas, safe)
	_draw_small(canvas, safe, visual)
	if disabled:
		KitScript.draw_state(canvas, safe, false, true)


# Adds cracks without introducing a filled platform beneath the game.
static func _draw_pavement_marks(canvas: CanvasItem, safe: Rect2) -> void:
	var ground_y := safe.position.y + safe.size.y * 0.43
	canvas.draw_line(Vector2(safe.position.x + safe.size.x * 0.04, ground_y), Vector2(safe.end.x - safe.size.x * 0.03, ground_y + safe.size.y * 0.03), Color(C_PAVEMENT_LIGHT.r, C_PAVEMENT_LIGHT.g, C_PAVEMENT_LIGHT.b, 0.46), 1.0)
	canvas.draw_line(Vector2(safe.position.x + safe.size.x * 0.14, ground_y), Vector2(safe.position.x + safe.size.x * 0.08, safe.end.y - safe.size.y * 0.04), Color(C_PAVEMENT_DARK.r, C_PAVEMENT_DARK.g, C_PAVEMENT_DARK.b, 0.72), 1.0)
	canvas.draw_line(Vector2(safe.end.x - safe.size.x * 0.18, ground_y), Vector2(safe.end.x - safe.size.x * 0.10, safe.end.y - safe.size.y * 0.06), Color(C_PAVEMENT_DARK.r, C_PAVEMENT_DARK.g, C_PAVEMENT_DARK.b, 0.72), 1.0)
	canvas.draw_line(Vector2(safe.position.x + safe.size.x * 0.40, ground_y + safe.size.y * 0.04), Vector2(safe.position.x + safe.size.x * 0.34, safe.end.y), Color(C_PAVEMENT_LIGHT.r, C_PAVEMENT_LIGHT.g, C_PAVEMENT_LIGHT.b, 0.34), 1.0)


# Frames the ring with only feet and trouser legs so it reads as a crowd circle.
static func _draw_player_edges(canvas: CanvasItem, safe: Rect2) -> void:
	var leg_size := Vector2(maxf(4.0, safe.size.x * 0.07), maxf(8.0, safe.size.y * 0.24))
	var shoe_size := Vector2(leg_size.x * 1.35, maxf(3.0, leg_size.y * 0.24))
	var left_leg := Rect2(safe.position + Vector2(safe.size.x * 0.10, safe.size.y * 0.28), leg_size)
	var right_leg := Rect2(safe.position + Vector2(safe.size.x * 0.82, safe.size.y * 0.25), leg_size)
	canvas.draw_rect(left_leg, C_DENIM)
	canvas.draw_rect(Rect2(left_leg.position + Vector2(leg_size.x * 1.18, 1.0), leg_size), C_DENIM.darkened(0.08))
	canvas.draw_rect(Rect2(left_leg.position + Vector2(-1.0, leg_size.y - 1.0), shoe_size), C_SHOE)
	canvas.draw_rect(Rect2(left_leg.position + Vector2(leg_size.x * 1.05, leg_size.y), shoe_size), C_SHOE)
	canvas.draw_rect(right_leg, C_BROWN)
	canvas.draw_rect(Rect2(right_leg.position + Vector2(leg_size.x * 1.18, 0.0), leg_size), C_BROWN.darkened(0.10))
	canvas.draw_rect(Rect2(right_leg.position + Vector2(-shoe_size.x * 0.22, leg_size.y), shoe_size), C_SHOE)
	canvas.draw_rect(Rect2(right_leg.position + Vector2(leg_size.x * 1.00, leg_size.y - 1.0), shoe_size), C_SHOE)


# Paints the chalk layout and current public game state on the pavement.
static func _draw_chalk_game(canvas: CanvasItem, safe: Rect2, visual: Dictionary, accent: Color, pulse: float) -> void:
	var ring := Rect2(safe.position + Vector2(safe.size.x * 0.15, safe.size.y * 0.48), Vector2(safe.size.x * 0.70, safe.size.y * 0.39))
	var ring_points := _ellipse_points(ring, 36)
	canvas.draw_colored_polygon(ring_points, Color(C_CHALK.r, C_CHALK.g, C_CHALK.b, 0.025 + pulse * 0.025))
	var outline := ring_points.duplicate()
	outline.append(ring_points[0])
	canvas.draw_polyline(outline, Color(C_CHALK.r, C_CHALK.g, C_CHALK.b, 0.82), 2.0)
	var inner := Rect2(ring.position + ring.size * Vector2(0.14, 0.20), ring.size * Vector2(0.72, 0.58))
	var inner_points := _ellipse_points(inner, 28)
	inner_points.append(inner_points[0])
	canvas.draw_polyline(inner_points, Color(C_CHALK_DIM.r, C_CHALK_DIM.g, C_CHALK_DIM.b, 0.72), 1.0)
	canvas.draw_line(Vector2(ring.position.x + ring.size.x * 0.24, ring.get_center().y), Vector2(ring.end.x - ring.size.x * 0.24, ring.get_center().y), C_CHALK_DIM, 1.0)
	canvas.draw_line(Vector2(ring.get_center().x, ring.position.y + ring.size.y * 0.16), Vector2(ring.get_center().x, ring.end.y - ring.size.y * 0.14), C_CHALK_DIM, 1.0)

	var die_size_value := clampf(ring.size.y * 0.28, 7.0, 16.0)
	var die_size := Vector2.ONE * die_size_value
	var center := ring.get_center()
	KitScript.draw_die(canvas, Rect2(center + Vector2(-die_size.x * 1.02, -die_size.y * 0.48), die_size), int(visual.get("last_die_a", 2)), Color("#372b23"), Color("#d8c9ab"))
	KitScript.draw_die(canvas, Rect2(center + Vector2(die_size.x * 0.10, die_size.y * 0.06), die_size), int(visual.get("last_die_b", 4)), Color("#372b23"), Color("#d8c9ab"))

	for cash_data in [Vector3(0.19, 0.69, -0.10), Vector3(0.66, 0.72, 0.08), Vector3(0.72, 0.52, -0.05)]:
		var cash_size := Vector2(maxf(8.0, safe.size.x * 0.13), maxf(4.0, safe.size.y * 0.07))
		var cash_position := safe.position + safe.size * Vector2(cash_data.x, cash_data.y)
		var cash := Rect2(cash_position, cash_size)
		canvas.draw_set_transform(cash.get_center(), cash_data.z, Vector2.ONE)
		canvas.draw_rect(Rect2(-cash.size * 0.5, cash.size), C_CASH)
		canvas.draw_rect(Rect2(-cash.size * 0.5, cash.size), C_CASH_EDGE, false, 1.0)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var point := int(visual.get("point", 0))
	var marker_color := Color("#e8e5dc") if point == 0 else accent.lerp(Color("#f3ca52"), 0.45)
	canvas.draw_circle(ring.position + Vector2(ring.size.x * 0.78, ring.size.y * 0.30), clampf(ring.size.y * 0.08, 2.0, 5.0), marker_color)
	if bool(visual.get("dispersed", false)):
		_draw_scattered_footprints(canvas, safe)


# Marks the direction of flight after a sweep disperses the circle.
static func _draw_scattered_footprints(canvas: CanvasItem, safe: Rect2) -> void:
	for index in range(3):
		var step := Rect2(safe.position + Vector2(safe.size.x * (0.34 + float(index) * 0.14), safe.size.y * (0.30 - float(index % 2) * 0.08)), Vector2(maxf(3.0, safe.size.x * 0.035), maxf(5.0, safe.size.y * 0.08)))
		canvas.draw_rect(step, Color(C_RED.r, C_RED.g, C_RED.b, 0.52))


# Keeps the chalk oval and loose dice readable in very small slots.
static func _draw_small(canvas: CanvasItem, safe: Rect2, visual: Dictionary) -> void:
	var ring := Rect2(safe.position + Vector2(safe.size.x * 0.12, safe.size.y * 0.42), Vector2(safe.size.x * 0.76, safe.size.y * 0.42))
	var points := _ellipse_points(ring, 24)
	points.append(points[0])
	canvas.draw_polyline(points, C_CHALK, 2.0)
	var die_size := Vector2.ONE * clampf(ring.size.y * 0.30, 6.0, 10.0)
	KitScript.draw_die(canvas, Rect2(ring.get_center() - Vector2(die_size.x * 0.95, die_size.y * 0.44), die_size), int(visual.get("last_die_a", 3)), Color("#372b23"), Color("#d8c9ab"))
	KitScript.draw_die(canvas, Rect2(ring.get_center() + Vector2(die_size.x * 0.06, 0.0), die_size), int(visual.get("last_die_b", 4)), Color("#372b23"), Color("#d8c9ab"))
	canvas.draw_rect(Rect2(ring.position + Vector2(ring.size.x * 0.08, ring.size.y * 0.63), Vector2(maxf(6.0, ring.size.x * 0.16), maxf(3.0, ring.size.y * 0.12))), C_CASH)


# Builds the pixel-friendly flattened rings used by the ground layout.
static func _ellipse_points(rect: Rect2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(maxi(8, segments)):
		var angle := TAU * float(index) / float(maxi(8, segments))
		points.append(rect.get_center() + Vector2(cos(angle) * rect.size.x * 0.5, sin(angle) * rect.size.y * 0.5))
	return points
