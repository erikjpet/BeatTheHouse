class_name BarDiceRoomProp
extends RefCounted

const KitScript := preload("res://scripts/ui/game_props/game_prop_kit.gd")
const EMPTY_STATE: Dictionary = {}
const C_WOOD := Color("#3a2619")
const C_WOOD_DARK := Color("#25131a")
const C_LEATHER := Color("#24172f")
const C_PINK := Color("#e64a78")
const C_CYAN := Color("#58d4dd")
const C_AMBER := Color("#e6ad55")
const C_GREEN := Color("#70936b")
const C_GLASS := Color("#9ed6df")


static func draw(canvas: CanvasItem, rect: Rect2, object_data: Dictionary, accent: Color, selected: bool, disabled: bool, flicker: float) -> void:
	var safe := Rect2(rect.position + Vector2(rect.size.x * 0.03, rect.size.y * 0.07), Vector2(rect.size.x * 0.94, rect.size.y * 0.84))
	var visual: Dictionary = object_data.get("visual_state", EMPTY_STATE) if typeof(object_data.get("visual_state", EMPTY_STATE)) == TYPE_DICTIONARY else EMPTY_STATE
	var phase_value := KitScript.phase(object_data)
	var pulse := KitScript.pulse(flicker, phase_value, selected)
	KitScript.draw_base_shadow(canvas, safe, accent)
	if safe.size.x < 64.0 or safe.size.y < 38.0:
		_draw_small(canvas, safe)
		KitScript.draw_state(canvas, safe, selected, disabled)
		return
	var bar := Rect2(safe.position + Vector2(0.0, safe.size.y * 0.18), Vector2(safe.size.x, safe.size.y * 0.66))
	canvas.draw_rect(bar, C_WOOD_DARK)
	canvas.draw_rect(bar.grow(-3.0), C_WOOD)
	for index in range(5):
		var y := bar.position.y + bar.size.y * (0.14 + float(index) * 0.17)
		canvas.draw_line(Vector2(bar.position.x + 4.0, y), Vector2(bar.end.x - 4.0, y + 2.0), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.10), 1.0)
	canvas.draw_rect(bar, Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.26 + pulse * 0.18), false, 2.0)
	var mat := Rect2(bar.position + Vector2(bar.size.x * 0.20, bar.size.y * 0.18), Vector2(bar.size.x * 0.58, bar.size.y * 0.58))
	canvas.draw_rect(mat, Color("#17292b"))
	canvas.draw_rect(mat, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.20 + pulse * 0.14), false, 1.0)
	var cup := Rect2(bar.position + Vector2(bar.size.x * 0.07, bar.size.y * 0.12), Vector2(bar.size.x * 0.16, bar.size.y * 0.50))
	canvas.draw_rect(Rect2(cup.position + Vector2(cup.size.x * 0.12, cup.size.y * 0.08), Vector2(cup.size.x * 0.76, cup.size.y * 0.84)), C_LEATHER)
	canvas.draw_rect(Rect2(cup.position, Vector2(cup.size.x, cup.size.y * 0.18)), Color("#402552"))
	canvas.draw_rect(Rect2(cup.position + Vector2(cup.size.x * 0.08, cup.size.y * 0.78), Vector2(cup.size.x * 0.84, cup.size.y * 0.14)), Color("#120d18"))
	canvas.draw_rect(cup, Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.34 + pulse * 0.20), false, 1.0)
	var die_size := Vector2(maxf(7.0, mat.size.y * 0.24), maxf(7.0, mat.size.y * 0.24))
	var start := mat.position + Vector2(mat.size.x * 0.07, mat.size.y * 0.32)
	KitScript.draw_die(canvas, Rect2(start, die_size), _die_value(visual, 0, 6))
	KitScript.draw_die(canvas, Rect2(start + Vector2(die_size.x * 1.12, -die_size.y * 0.18), die_size), _die_value(visual, 1, 5))
	KitScript.draw_die(canvas, Rect2(start + Vector2(die_size.x * 2.24, die_size.y * 0.08), die_size), _die_value(visual, 2, 4))
	KitScript.draw_die(canvas, Rect2(start + Vector2(die_size.x * 3.36, -die_size.y * 0.12), die_size), _die_value(visual, 3, 3))
	KitScript.draw_die(canvas, Rect2(start + Vector2(die_size.x * 4.48, die_size.y * 0.12), die_size), _die_value(visual, 4, 2))
	var cash := Rect2(bar.position + Vector2(bar.size.x * 0.74, bar.size.y * 0.68), Vector2(bar.size.x * 0.17, bar.size.y * 0.13))
	canvas.draw_rect(Rect2(cash.position + Vector2(-2.0, -2.0), cash.size), C_GREEN.darkened(0.18))
	canvas.draw_rect(cash, C_GREEN)
	canvas.draw_rect(cash, Color("#bad1a9"), false, 1.0)
	var coaster_center := bar.position + Vector2(bar.size.x * 0.89, bar.size.y * 0.32)
	canvas.draw_circle(coaster_center, bar.size.y * 0.15, Color("#7c2948"))
	canvas.draw_circle(coaster_center, bar.size.y * 0.11, Color("#27131f"))
	var glass := Rect2(coaster_center - Vector2(bar.size.x * 0.035, bar.size.y * 0.23), Vector2(bar.size.x * 0.07, bar.size.y * 0.23))
	canvas.draw_rect(glass, Color(C_GLASS.r, C_GLASS.g, C_GLASS.b, 0.30))
	canvas.draw_rect(Rect2(glass.position + Vector2(1.0, glass.size.y * 0.48), Vector2(glass.size.x - 2.0, glass.size.y * 0.46)), Color("#a85d32"))
	canvas.draw_rect(glass, C_GLASS, false, 1.0)
	var napkin := Rect2(bar.position + Vector2(bar.size.x * 0.04, bar.size.y * 0.72), Vector2(bar.size.x * 0.19, bar.size.y * 0.12))
	canvas.draw_rect(napkin, Color("#e3dcc8"))
	canvas.draw_line(napkin.position + Vector2(2.0, napkin.size.y * 0.55), napkin.end - Vector2(2.0, napkin.size.y * 0.45), C_PINK, 1.0)
	if not bool(object_data.get("hide_prop_text", false)):
		canvas.draw_string(canvas.get_theme_default_font(), mat.position + Vector2(1.0, mat.size.y * 0.18), "SHIP  CAPTAIN  CREW", HORIZONTAL_ALIGNMENT_CENTER, mat.size.x - 2.0, 6, C_AMBER)
	KitScript.draw_state(canvas, safe, selected, disabled)


static func draw_low_detail(canvas: CanvasItem, rect: Rect2, object_data: Dictionary, accent: Color, disabled: bool, flicker: float) -> void:
	var safe := rect.grow(-3.0)
	KitScript.draw_base_shadow(canvas, safe, accent)
	_draw_small(canvas, safe)
	if disabled:
		KitScript.draw_state(canvas, safe, false, true)


static func _die_value(visual: Dictionary, index: int, fallback: int) -> int:
	match index:
		0: return clampi(int(visual.get("die_0", fallback)), 1, 6)
		1: return clampi(int(visual.get("die_1", fallback)), 1, 6)
		2: return clampi(int(visual.get("die_2", fallback)), 1, 6)
		3: return clampi(int(visual.get("die_3", fallback)), 1, 6)
		4: return clampi(int(visual.get("die_4", fallback)), 1, 6)
	return fallback


static func _draw_small(canvas: CanvasItem, safe: Rect2) -> void:
	var bar := Rect2(safe.position + Vector2(safe.size.x * 0.03, safe.size.y * 0.22), Vector2(safe.size.x * 0.94, safe.size.y * 0.58))
	canvas.draw_rect(bar, C_WOOD_DARK)
	canvas.draw_rect(bar.grow(-3.0), C_WOOD)
	var cup := Rect2(bar.position + Vector2(bar.size.x * 0.08, bar.size.y * 0.08), Vector2(bar.size.x * 0.16, bar.size.y * 0.62))
	canvas.draw_rect(cup, C_LEATHER)
	canvas.draw_rect(Rect2(cup.position, Vector2(cup.size.x, maxf(2.0, cup.size.y * 0.18))), C_PINK)
	var mat := Rect2(bar.position + Vector2(bar.size.x * 0.28, bar.size.y * 0.12), Vector2(bar.size.x * 0.54, bar.size.y * 0.65))
	canvas.draw_rect(mat, Color("#17292b"))
	for index in range(5):
		var die := Rect2(mat.position + Vector2(2.0 + float(index) * mat.size.x * 0.19, mat.size.y * (0.26 + float(index % 2) * 0.20)), Vector2(maxf(6.0, mat.size.x * 0.15), maxf(6.0, mat.size.x * 0.15)))
		KitScript.draw_die(canvas, die, 6 - index)
	canvas.draw_rect(Rect2(bar.position + Vector2(bar.size.x * 0.80, bar.size.y * 0.70), Vector2(bar.size.x * 0.14, bar.size.y * 0.12)), C_GREEN)
