class_name CrapsRoomProp
extends RefCounted

const KitScript := preload("res://scripts/ui/game_props/game_prop_kit.gd")
const EMPTY_STATE: Dictionary = {}
const C_FELT := Color("#147653")
const C_FELT_DARK := Color("#0b3c2f")
const C_RAIL := Color("#47251a")
const C_GOLD := Color("#e8bd54")
const C_CHALK := Color("#e4dcc8")
const C_PAVEMENT := Color("#272b2d")
const C_RED := Color("#d04455")
const C_CYAN := Color("#57d8de")


static func draw(canvas: CanvasItem, rect: Rect2, object_data: Dictionary, accent: Color, selected: bool, disabled: bool, flicker: float) -> void:
	var safe := Rect2(rect.position + Vector2(rect.size.x * 0.03, rect.size.y * 0.09), Vector2(rect.size.x * 0.94, rect.size.y * 0.82))
	var visual: Dictionary = object_data.get("visual_state", EMPTY_STATE) if typeof(object_data.get("visual_state", EMPTY_STATE)) == TYPE_DICTIONARY else EMPTY_STATE
	var variant: String = visual.get("variant", "casino")
	var street := variant == "street_craps"
	var phase_value := KitScript.phase(object_data)
	var pulse := KitScript.pulse(flicker, phase_value, selected)
	KitScript.draw_base_shadow(canvas, safe, accent)
	if safe.size.x < 64.0 or safe.size.y < 38.0:
		_draw_small(canvas, safe, street)
		KitScript.draw_state(canvas, safe, selected, disabled)
		return
	if street:
		_draw_street(canvas, safe, visual, pulse)
	else:
		_draw_casino(canvas, safe, visual, pulse, bool(object_data.get("hide_prop_text", false)))
	KitScript.draw_state(canvas, safe, selected, disabled)


static func draw_low_detail(canvas: CanvasItem, rect: Rect2, object_data: Dictionary, accent: Color, disabled: bool, flicker: float) -> void:
	var safe := rect.grow(-3.0)
	var visual: Dictionary = object_data.get("visual_state", EMPTY_STATE) if typeof(object_data.get("visual_state", EMPTY_STATE)) == TYPE_DICTIONARY else EMPTY_STATE
	var variant: String = visual.get("variant", "casino")
	var street := variant == "street_craps"
	KitScript.draw_base_shadow(canvas, safe, accent)
	_draw_small(canvas, safe, street)
	if disabled:
		KitScript.draw_state(canvas, safe, false, true)


static func _draw_casino(canvas: CanvasItem, safe: Rect2, visual: Dictionary, pulse: float, hide_text: bool) -> void:
	var table := Rect2(safe.position + Vector2(safe.size.x * 0.04, safe.size.y * 0.15), Vector2(safe.size.x * 0.92, safe.size.y * 0.66))
	var radius := table.size.y * 0.34
	canvas.draw_rect(Rect2(table.position + Vector2(radius, 0.0), Vector2(table.size.x - radius * 2.0, table.size.y)), C_RAIL)
	canvas.draw_circle(table.position + Vector2(radius, table.size.y * 0.50), radius, C_RAIL)
	canvas.draw_circle(Vector2(table.end.x - radius, table.position.y + table.size.y * 0.50), radius, C_RAIL)
	var felt := table.grow(-5.0)
	var felt_radius := felt.size.y * 0.33
	canvas.draw_rect(Rect2(felt.position + Vector2(felt_radius, 0.0), Vector2(felt.size.x - felt_radius * 2.0, felt.size.y)), C_FELT)
	canvas.draw_circle(felt.position + Vector2(felt_radius, felt.size.y * 0.50), felt_radius, C_FELT)
	canvas.draw_circle(Vector2(felt.end.x - felt_radius, felt.position.y + felt.size.y * 0.50), felt_radius, C_FELT)
	canvas.draw_rect(felt, Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.30 + pulse * 0.18), false, 1.0)
	var grid := Rect2(felt.position + Vector2(felt.size.x * 0.19, felt.size.y * 0.12), Vector2(felt.size.x * 0.62, felt.size.y * 0.70))
	canvas.draw_rect(Rect2(grid.position, Vector2(grid.size.x, grid.size.y * 0.18)), Color("#0a4937"))
	canvas.draw_rect(Rect2(grid.position + Vector2(0.0, grid.size.y * 0.24), Vector2(grid.size.x, grid.size.y * 0.25)), Color("#126a4b"), false, 1.0)
	canvas.draw_rect(Rect2(grid.position + Vector2(0.0, grid.size.y * 0.55), Vector2(grid.size.x, grid.size.y * 0.22)), Color("#126a4b"), false, 1.0)
	for index in range(6):
		var x := grid.position.x + grid.size.x * (0.08 + float(index) * 0.17)
		canvas.draw_line(Vector2(x, grid.position.y + grid.size.y * 0.24), Vector2(x, grid.end.y), C_GOLD, 1.0)
	for index in range(4):
		canvas.draw_circle(felt.position + Vector2(felt.size.x * 0.08, felt.size.y * (0.27 + float(index) * 0.14)), 2.0, Color("#f1e7cc") if index % 2 == 0 else C_RED)
	var point_x := grid.position.x + grid.size.x * (0.15 + float(int(visual.get("point", 0)) % 6) * 0.14)
	canvas.draw_circle(Vector2(point_x, grid.position.y + 2.0), 3.2, Color("#f2efe4") if int(visual.get("point", 0)) == 0 else C_RED)
	var die_size := Vector2(maxf(7.0, felt.size.y * 0.20), maxf(7.0, felt.size.y * 0.20))
	KitScript.draw_die(canvas, Rect2(felt.get_center() + Vector2(-die_size.x * 0.72, -die_size.y * 0.15), die_size), int(visual.get("last_die_a", 3)))
	KitScript.draw_die(canvas, Rect2(felt.get_center() + Vector2(die_size.x * 0.05, die_size.y * 0.10), die_size), int(visual.get("last_die_b", 4)))
	canvas.draw_line(table.position + Vector2(table.size.x * 0.73, -safe.size.y * 0.08), table.position + Vector2(table.size.x * 0.48, table.size.y * 0.54), C_CHALK, 2.0)
	canvas.draw_circle(table.position + Vector2(table.size.x * 0.73, -safe.size.y * 0.08), 2.0, C_GOLD)
	if not hide_text:
		var font: Font = canvas.get_theme_default_font()
		canvas.draw_string(font, grid.position + Vector2(1.0, grid.size.y * 0.16), "PASS  COME  FIELD", HORIZONTAL_ALIGNMENT_CENTER, grid.size.x - 2.0, 6, C_GOLD)


static func _draw_street(canvas: CanvasItem, safe: Rect2, visual: Dictionary, pulse: float) -> void:
	var pavement := Rect2(safe.position + Vector2(safe.size.x * 0.03, safe.size.y * 0.11), Vector2(safe.size.x * 0.94, safe.size.y * 0.72))
	canvas.draw_rect(pavement, C_PAVEMENT)
	canvas.draw_rect(pavement, Color(C_CHALK.r, C_CHALK.g, C_CHALK.b, 0.26 + pulse * 0.10), false, 1.0)
	for row in range(3):
		canvas.draw_line(pavement.position + Vector2(0.0, pavement.size.y * (0.24 + float(row) * 0.27)), pavement.position + Vector2(pavement.size.x, pavement.size.y * (0.20 + float(row) * 0.27)), Color("#454a4b"), 1.0)
	for column in range(4):
		canvas.draw_line(pavement.position + Vector2(pavement.size.x * (0.17 + float(column) * 0.23), 0.0), pavement.position + Vector2(pavement.size.x * (0.14 + float(column) * 0.23), pavement.size.y), Color("#3b4041"), 1.0)
	var ring_center := pavement.position + Vector2(pavement.size.x * 0.48, pavement.size.y * 0.50)
	canvas.draw_circle(ring_center, pavement.size.y * 0.36, Color(C_CHALK.r, C_CHALK.g, C_CHALK.b, 0.08))
	canvas.draw_arc(ring_center, pavement.size.y * 0.36, 0.0, TAU, 32, C_CHALK, 2.0)
	canvas.draw_arc(ring_center, pavement.size.y * 0.22, 0.18, PI + 0.4, 20, C_CHALK, 1.0)
	canvas.draw_line(ring_center + Vector2(-pavement.size.x * 0.18, 0.0), ring_center + Vector2(pavement.size.x * 0.18, 0.0), C_CHALK, 1.0)
	canvas.draw_line(ring_center + Vector2(0.0, -pavement.size.y * 0.25), ring_center + Vector2(0.0, pavement.size.y * 0.25), C_CHALK, 1.0)
	var die_size := Vector2(maxf(8.0, pavement.size.y * 0.21), maxf(8.0, pavement.size.y * 0.21))
	KitScript.draw_die(canvas, Rect2(ring_center + Vector2(-die_size.x * 0.90, -die_size.y * 0.38), die_size), int(visual.get("last_die_a", 2)), Color("#3c332a"), Color("#d8c9ab"))
	KitScript.draw_die(canvas, Rect2(ring_center + Vector2(die_size.x * 0.05, die_size.y * 0.12), die_size), int(visual.get("last_die_b", 4)), Color("#3c332a"), Color("#d8c9ab"))
	for index in range(3):
		var cash := Rect2(pavement.position + Vector2(pavement.size.x * (0.10 + float(index) * 0.34), pavement.size.y * (0.73 + float(index % 2) * 0.08)), Vector2(pavement.size.x * 0.17, pavement.size.y * 0.12))
		canvas.draw_rect(cash, Color("#719269"))
		canvas.draw_rect(cash, Color("#b8c9a7"), false, 1.0)
	if bool(visual.get("dispersed", false)):
		canvas.draw_line(pavement.position + Vector2(4.0, 4.0), pavement.end - Vector2(4.0, 4.0), C_RED, 3.0)


static func _draw_small(canvas: CanvasItem, safe: Rect2, street: bool) -> void:
	if street:
		var pavement := Rect2(safe.position + Vector2(safe.size.x * 0.08, safe.size.y * 0.18), Vector2(safe.size.x * 0.84, safe.size.y * 0.62))
		canvas.draw_rect(pavement, C_PAVEMENT)
		canvas.draw_arc(pavement.get_center(), pavement.size.y * 0.34, 0.0, TAU, 24, C_CHALK, 2.0)
		KitScript.draw_die(canvas, Rect2(pavement.get_center() - Vector2(9.0, 5.0), Vector2(8.0, 8.0)), 3, Color("#3c332a"), Color("#d8c9ab"))
		KitScript.draw_die(canvas, Rect2(pavement.get_center() + Vector2(2.0, 1.0), Vector2(8.0, 8.0)), 4, Color("#3c332a"), Color("#d8c9ab"))
		canvas.draw_rect(Rect2(pavement.position + Vector2(4.0, pavement.size.y * 0.72), Vector2(11.0, 5.0)), Color("#719269"))
	else:
		var table := Rect2(safe.position + Vector2(safe.size.x * 0.06, safe.size.y * 0.24), Vector2(safe.size.x * 0.88, safe.size.y * 0.52))
		canvas.draw_rect(table, C_RAIL)
		canvas.draw_circle(table.position + Vector2(table.size.y * 0.30, table.size.y * 0.50), table.size.y * 0.30, C_RAIL)
		canvas.draw_circle(Vector2(table.end.x - table.size.y * 0.30, table.position.y + table.size.y * 0.50), table.size.y * 0.30, C_RAIL)
		var felt := table.grow(-4.0)
		canvas.draw_rect(felt, C_FELT)
		for index in range(5):
			canvas.draw_line(felt.position + Vector2(felt.size.x * (0.18 + float(index) * 0.16), 2.0), felt.position + Vector2(felt.size.x * (0.18 + float(index) * 0.16), felt.size.y - 2.0), C_GOLD, 1.0)
		KitScript.draw_die(canvas, Rect2(felt.get_center() - Vector2(8.0, 5.0), Vector2(8.0, 8.0)), 3)
		KitScript.draw_die(canvas, Rect2(felt.get_center() + Vector2(2.0, 1.0), Vector2(8.0, 8.0)), 4)
