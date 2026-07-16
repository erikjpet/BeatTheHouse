class_name RunReportTimelineCanvas
extends Control

signal seek_requested(progress: float)

const BAND_COLORS := [
	Color("#245b78"), Color("#70406f"), Color("#6b5524"),
	Color("#28614f"), Color("#573f7d"), Color("#75402e"),
]

var heat_samples: Array = []
var environment_bands: Array = []
var heat_points := PackedVector2Array()
var replay_progress := 0.0
var dragging := false


func set_timeline(timeline: Dictionary) -> void:
	heat_samples = timeline.get("heat_samples", [])
	environment_bands = timeline.get("environment_bands", [])
	replay_progress = 0.0
	_rebuild_heat_points()
	queue_redraw()


func set_replay_progress(progress: float) -> void:
	var next := clampf(progress, 0.0, 1.0)
	if is_equal_approx(next, replay_progress):
		return
	replay_progress = next
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		_seek_from_x(event.position.x)
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		_seek_from_x(event.position.x)
		accept_event()


func _seek_from_x(local_x: float) -> void:
	var graph := _graph_rect()
	seek_requested.emit(clampf((local_x - graph.position.x) / maxf(1.0, graph.size.x), 0.0, 1.0))


func _draw() -> void:
	var graph := _graph_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color("#080b18"))
	draw_line(Vector2(graph.position.x, graph.position.y), Vector2(graph.end.x, graph.position.y), Color("#ff6eb4", 0.72), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(graph.position.x + 3.0, graph.position.y + 11.0), "CAPTURE 100", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#ff9bc7"))
	if heat_points.size() >= 2:
		draw_polyline(heat_points, Color("#ffb32d"), 3.0, true)
	var band_rect := Rect2(graph.position.x, graph.end.y + 4.0, graph.size.x, maxf(12.0, size.y - graph.end.y - 7.0))
	for value in environment_bands:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var band: Dictionary = value
		var start := clampf(float(band.get("start_progress", 0.0)), 0.0, 1.0)
		var finish := clampf(float(band.get("end_progress", start)), start, 1.0)
		var rect := Rect2(band_rect.position + Vector2(start * band_rect.size.x, 0.0), Vector2(maxf(2.0, (finish - start) * band_rect.size.x), band_rect.size.y))
		var color: Color = BAND_COLORS[int(band.get("color_index", 0)) % BAND_COLORS.size()]
		draw_rect(rect, color)
		if rect.size.x >= 70.0:
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(3.0, rect.size.y - 3.0), str(band.get("label", "Venue")).left(16), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 6.0, 9, Color("#d8e8ea"))
	var cursor_x := graph.position.x + replay_progress * graph.size.x
	draw_line(Vector2(cursor_x, graph.position.y), Vector2(cursor_x, band_rect.end.y), Color("#00f5ff"), 2.0)
	draw_circle(Vector2(cursor_x, graph.position.y + 4.0), 4.0, Color("#00f5ff"))
	draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), Color("#2ee9ff", 0.28), false, 1.0)


func _graph_rect() -> Rect2:
	return Rect2(Vector2(8.0, 5.0), Vector2(maxf(1.0, size.x - 16.0), maxf(24.0, size.y - 31.0)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_rebuild_heat_points()
		queue_redraw()


func _rebuild_heat_points() -> void:
	heat_points = PackedVector2Array()
	var graph := _graph_rect()
	for value in heat_samples:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var sample: Dictionary = value
		heat_points.append(Vector2(
			graph.position.x + clampf(float(sample.get("progress", 0.0)), 0.0, 1.0) * graph.size.x,
			graph.end.y - clampf(float(sample.get("heat_value", 0)) / 100.0, 0.0, 1.0) * graph.size.y
		))
	if heat_points.size() == 1:
		heat_points.append(Vector2(graph.end.x, heat_points[0].y))
