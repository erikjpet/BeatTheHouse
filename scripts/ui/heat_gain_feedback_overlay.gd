class_name HeatGainFeedbackOverlay
extends Control

# A short, non-bloody consequence pulse layered above the run UI. Persistent
# Heat pressure remains the red/blue police-light treatment in the canvases.

const HeatFeedbackVisualsScript := preload("res://scripts/ui/heat_feedback_visuals.gd")

const ALERT_RED := Color("#ff2d35")
const ALERT_RED_INNER := Color("#ff5b50")
const COOL_ACCENT := Color("#38a8ff")

var _elapsed_sec := HeatFeedbackVisualsScript.GAIN_DURATION_SEC
var _applied_amount := 0
var _intensity := 0.0
var _reduce_motion := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	set_process(false)


func set_reduce_motion(enabled: bool) -> void:
	_reduce_motion = enabled
	visible = not enabled and _elapsed_sec < HeatFeedbackVisualsScript.GAIN_DURATION_SEC
	queue_redraw()


func trigger(applied_amount: int) -> void:
	if applied_amount <= 0:
		return
	# Consecutive gains during the same half-second response read as one event,
	# avoiding rapid flashes while retaining the full applied amount.
	_applied_amount = mini(100, _applied_amount + applied_amount) if _elapsed_sec < HeatFeedbackVisualsScript.GAIN_DURATION_SEC else mini(100, applied_amount)
	_intensity = HeatFeedbackVisualsScript.heat_gain_intensity(_applied_amount)
	_elapsed_sec = 0.0
	visible = not _reduce_motion
	set_process(true)
	queue_redraw()


func cancel() -> void:
	_elapsed_sec = HeatFeedbackVisualsScript.GAIN_DURATION_SEC
	_applied_amount = 0
	_intensity = 0.0
	visible = false
	set_process(false)
	queue_redraw()


func debug_snapshot() -> Dictionary:
	return {
		"active": _elapsed_sec < HeatFeedbackVisualsScript.GAIN_DURATION_SEC,
		"visible": visible,
		"amount": _applied_amount,
		"intensity": _intensity,
		"elapsed_sec": _elapsed_sec,
		"duration_sec": HeatFeedbackVisualsScript.GAIN_DURATION_SEC,
		"reduce_motion": _reduce_motion,
		"peak_alpha": _peak_alpha(),
		"edge_fraction": _edge_fraction(),
		"edge_color_hex": ALERT_RED.to_html(false),
	}


func _process(delta: float) -> void:
	_elapsed_sec += maxf(0.0, delta)
	if _elapsed_sec >= HeatFeedbackVisualsScript.GAIN_DURATION_SEC:
		cancel()
		return
	queue_redraw()


func _draw() -> void:
	if _elapsed_sec >= HeatFeedbackVisualsScript.GAIN_DURATION_SEC or _reduce_motion or size.x <= 0.0 or size.y <= 0.0:
		return
	var strength := _pulse_strength()
	var peak_alpha := _peak_alpha()
	var edge_extent := minf(size.x, size.y) * _edge_fraction()
	var band_count := 12
	var band_size := maxf(2.0, edge_extent / float(band_count))
	for index in range(band_count):
		var falloff := pow(1.0 - float(index) / float(band_count), 1.7)
		var alpha := peak_alpha * strength * falloff
		var offset := float(index) * band_size
		var color := ALERT_RED.lerp(ALERT_RED_INNER, float(index) / float(band_count) * 0.28)
		draw_rect(Rect2(offset, offset, size.x - offset * 2.0, band_size), Color(color.r, color.g, color.b, alpha))
		draw_rect(Rect2(offset, size.y - offset - band_size, size.x - offset * 2.0, band_size), Color(color.r, color.g, color.b, alpha * 0.86))
		draw_rect(Rect2(offset, offset + band_size, band_size, maxf(0.0, size.y - (offset + band_size) * 2.0)), Color(color.r, color.g, color.b, alpha * 0.94))
		draw_rect(Rect2(size.x - offset - band_size, offset + band_size, band_size, maxf(0.0, size.y - (offset + band_size) * 2.0)), Color(color.r, color.g, color.b, alpha * 0.94))
	# A small cool corner accent visually ties the momentary warning to the
	# persistent police-light pressure without turning the screen into a red wash.
	var corner_alpha := peak_alpha * strength * 0.48
	var corner_length := minf(size.x, size.y) * (0.055 + _intensity * 0.025)
	draw_rect(Rect2(0, 0, corner_length, 3), Color(COOL_ACCENT.r, COOL_ACCENT.g, COOL_ACCENT.b, corner_alpha))
	draw_rect(Rect2(size.x - corner_length, size.y - 3, corner_length, 3), Color(COOL_ACCENT.r, COOL_ACCENT.g, COOL_ACCENT.b, corner_alpha))


func _pulse_strength() -> float:
	return HeatFeedbackVisualsScript.heat_gain_pulse_strength(_elapsed_sec)


func _peak_alpha() -> float:
	return lerpf(0.220, 0.340, _intensity)


func _edge_fraction() -> float:
	return lerpf(0.160, 0.220, _intensity)
