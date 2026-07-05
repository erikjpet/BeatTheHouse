extends SceneTree

const REPORT_PREFIX := "BTH_ALLOC_CHURN_REPORT "
const DEFAULT_ITERATIONS := 10000
const DEFAULT_WARMUP_ITERATIONS := 500

var noop_surface := NoopSurface.new()
var bar_dice: RefCounted
var blackjack: RefCounted
var game_surface: Control
var action_summary_fixture := {
	"id": "controlled_roll",
	"label": "Controlled roll",
	"win_chance": 42,
	"payout_mult": 3,
	"suspicion_delta": 9,
}


class NoopSurface:
	extends RefCounted

	var hit_count := 0
	var label_count := 0

	func draw_circle(_position: Vector2, _radius: float, _color: Color) -> void:
		pass

	func draw_polygon(_points: Array, _colors: Array, _uvs: Array = [], _texture: Texture2D = null) -> void:
		pass

	func draw_line(_from: Vector2, _to: Vector2, _color: Color, _width: float = 1.0, _antialiased: bool = false) -> void:
		pass

	func draw_rect(_rect: Rect2, _color: Color, _filled: bool = true, _width: float = -1.0) -> void:
		pass

	func surface_label(_text: String, _pos: Vector2, _font_size: int, _color: Color) -> void:
		label_count += 1

	func surface_label_centered(_text: String, _rect: Rect2, _font_size: int, _color: Color) -> void:
		label_count += 1

	func surface_label_centered_plain(_text: String, _rect: Rect2, _font_size: int, _color: Color) -> void:
		label_count += 1

	func surface_title(_text: String, _pos: Vector2, _color: Color) -> void:
		label_count += 1

	func surface_add_hit(_rect: Rect2, _action: String, _index: int = 0) -> void:
		hit_count += 1


func _init() -> void:
	bar_dice = _load_script_instance("res://scripts/games/bar_dice.gd") as RefCounted
	blackjack = _load_script_instance("res://scripts/games/blackjack.gd") as RefCounted
	game_surface = _load_script_instance("res://scripts/ui/game_surface_canvas.gd") as Control
	if bar_dice == null or blackjack == null or game_surface == null:
		push_error("Allocation churn probe could not load target scripts.")
		quit(1)
		return
	var iterations := maxi(1, _env_int("BTH_ALLOC_PROBE_ITERS", DEFAULT_ITERATIONS))
	var warmup_iterations := maxi(0, _env_int("BTH_ALLOC_PROBE_WARMUP", DEFAULT_WARMUP_ITERATIONS))
	var report := {
		"tool": "allocation_churn_probe",
		"schema_version": 1,
		"iterations": iterations,
		"warmup_iterations": warmup_iterations,
		"cases": [
			_measure_case("bar_dice_draw_pips", iterations, warmup_iterations, Callable(self, "_bench_bar_dice_draw_pips")),
			_measure_case("blackjack_draw_table_static_geometry", iterations, warmup_iterations, Callable(self, "_bench_blackjack_draw_table")),
			_measure_case("game_surface_action_summary", iterations, warmup_iterations, Callable(self, "_bench_game_surface_action_summary")),
		],
	}
	print(REPORT_PREFIX + JSON.stringify(report))
	if is_instance_valid(game_surface):
		game_surface.free()
	quit(0)


func _measure_case(case_name: String, iterations: int, warmup_iterations: int, body: Callable) -> Dictionary:
	for index in range(warmup_iterations):
		body.call(index)
	var memory_before := _current_memory_bytes()
	var object_before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var started_usec := Time.get_ticks_usec()
	for index in range(iterations):
		body.call(index)
	var elapsed_usec := maxi(0, Time.get_ticks_usec() - started_usec)
	var memory_after := _current_memory_bytes()
	var object_after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	return {
		"name": case_name,
		"elapsed_ms": float(elapsed_usec) / 1000.0,
		"avg_usec": float(elapsed_usec) / float(iterations),
		"static_memory_delta_bytes": memory_after - memory_before,
		"object_count_delta": object_after - object_before,
	}


func _bench_bar_dice_draw_pips(index: int) -> void:
	bar_dice.call("_draw_pips", noop_surface, Rect2(0, 0, 44, 44), index % 6 + 1)


func _bench_blackjack_draw_table(index: int) -> void:
	blackjack.call("_draw_blackjack_table", noop_surface, {"active_hand_index": index % 4})


func _bench_game_surface_action_summary(_index: int) -> void:
	game_surface.call("_surface_action_summary", action_summary_fixture, "cheat")


func _current_memory_bytes() -> int:
	return int(Performance.get_monitor(Performance.MEMORY_STATIC))


func _load_script_instance(path: String) -> Object:
	var script := load(path)
	if script == null:
		push_error("Allocation churn probe failed to load %s." % path)
		return null
	return script.new()


func _env_int(key: String, fallback: int) -> int:
	var raw := OS.get_environment(key).strip_edges()
	if raw.is_valid_int():
		return int(raw)
	return fallback
