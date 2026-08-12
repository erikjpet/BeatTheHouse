class_name SegmentedMeter
extends Control

const SEGMENT_COUNT := 10
const VALUE_MIN := 0.0
const VALUE_MAX := 100.0
const TICK_VALUES := [35.0, 70.0]

var meter_value := VALUE_MIN
var pending_value := VALUE_MIN
var meter_kind := "heat"
var feedback_pulse_strength := 0.0
var feedback_pulse_amount := 0


func _ready() -> void:
	custom_minimum_size = VisualStyle.HUD_METER_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(kind: String, value: float, pending: float = VALUE_MIN) -> void:
	var next_value := clampf(value, VALUE_MIN, VALUE_MAX)
	var next_pending := clampf(pending, VALUE_MIN, VALUE_MAX - next_value)
	if meter_kind == kind and is_equal_approx(meter_value, next_value) and is_equal_approx(pending_value, next_pending):
		return
	meter_kind = kind
	meter_value = next_value
	pending_value = next_pending
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
		"feedback_pulse_strength": feedback_pulse_strength,
		"feedback_pulse_amount": feedback_pulse_amount,
	}


func set_feedback_pulse(amount: int, strength: float) -> void:
	var next_amount := maxi(0, amount)
	var next_strength := clampf(strength, 0.0, 1.0)
	if feedback_pulse_amount == next_amount and is_equal_approx(feedback_pulse_strength, next_strength):
		return
	feedback_pulse_amount = next_amount
	feedback_pulse_strength = next_strength
	queue_redraw()


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
	if meter_kind == "heat" and feedback_pulse_strength > 0.0:
		var intensity := pow(clampf(float(maxi(1, feedback_pulse_amount) - 1) / 19.0, 0.0, 1.0), 0.62)
		var pulse_color := Color("#ffb14a").lerp(Color("#ffe082"), 0.28)
		var alpha := lerpf(0.48, 0.90, intensity) * feedback_pulse_strength
		draw_rect(Rect2(Vector2.ZERO, size), Color(pulse_color.r, pulse_color.g, pulse_color.b, alpha), false, 2.0)


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
