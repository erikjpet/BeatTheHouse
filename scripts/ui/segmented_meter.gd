class_name SegmentedMeter
extends Control

const SEGMENT_COUNT := 10
const VALUE_MIN := 0.0
const VALUE_MAX := 100.0
const TICK_VALUES := [35.0, 70.0]

var meter_value := VALUE_MIN
var pending_value := VALUE_MIN
var meter_kind := "heat"


func _ready() -> void:
	custom_minimum_size = VisualStyle.HUD_METER_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(kind: String, value: float, pending: float = VALUE_MIN) -> void:
	meter_kind = kind
	meter_value = clampf(value, VALUE_MIN, VALUE_MAX)
	pending_value = clampf(pending, VALUE_MIN, VALUE_MAX - meter_value)
	queue_redraw()


func current_snapshot() -> Dictionary:
	return {
		"kind": meter_kind,
		"value": meter_value,
		"pending": pending_value,
		"segments": SEGMENT_COUNT,
		"ticks": TICK_VALUES.duplicate(),
		"band": _band_name(meter_value),
		"ghost_visible": pending_value > VALUE_MIN,
	}


func _draw() -> void:
	var gap := float(VisualStyle.SPACE_1)
	var segment_width := (size.x - gap * float(SEGMENT_COUNT - 1)) / float(SEGMENT_COUNT)
	var filled_segments := int(ceil(meter_value / VALUE_MAX * float(SEGMENT_COUNT)))
	var pending_segments := int(ceil((meter_value + pending_value) / VALUE_MAX * float(SEGMENT_COUNT)))
	for index in range(SEGMENT_COUNT):
		var rect := Rect2(
			Vector2(float(index) * (segment_width + gap), 0.0),
			Vector2(segment_width, size.y)
		)
		var color := VisualStyle.role("disabled")
		if index < filled_segments:
			color = _band_color(float(index + 1) / float(SEGMENT_COUNT) * VALUE_MAX)
		elif index < pending_segments:
			color = Color(VisualStyle.role("warning"), 0.42)
		draw_rect(rect, color, true)
		draw_rect(rect, VisualStyle.role("surface_base"), false, VisualStyle.BORDER_HAIRLINE)
	for tick_value in TICK_VALUES:
		var x := size.x * float(tick_value) / VALUE_MAX
		draw_line(
			Vector2(x, 0.0),
			Vector2(x, size.y),
			VisualStyle.role("text_primary"),
			VisualStyle.BORDER_HAIRLINE
		)


func _band_name(value: float) -> String:
	if value >= TICK_VALUES[1]:
		return "danger"
	if value >= TICK_VALUES[0]:
		return "warning"
	return "safe"


func _band_color(value: float) -> Color:
	match _band_name(value):
		"danger":
			return VisualStyle.role("danger")
		"warning":
			return VisualStyle.role("warning")
		_:
			return VisualStyle.role("success")
