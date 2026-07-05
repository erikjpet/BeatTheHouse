extends SceneTree

const REPORT_PREFIX := "BTH_ALLOC_CHURN_REPORT "
const DEFAULT_ITERATIONS := 10000
const DEFAULT_WARMUP_ITERATIONS := 500

var noop_surface := NoopSurface.new()
var bar_dice: RefCounted
var blackjack: RefCounted
var slot_renderer: RefCounted
var game_surface: Control
var action_summary_fixture := {
	"id": "controlled_roll",
	"label": "Controlled roll",
	"win_chance": 42,
	"payout_mult": 3,
	"suspicion_delta": 9,
}
var slot_skin_fixture := {
	"feature_name": "Buffalo Stampede",
	"tease_panel": {"x": 56, "y": 94, "w": 158, "h": 258},
	"feature_panel": {"x": 746, "y": 94, "w": 158, "h": 258},
	"playfield_rect": {"x": 236, "y": 94, "w": 488, "h": 204},
	"result_strip": {"x": 80, "y": 374, "w": 800, "h": 38},
}
var slot_definition_fixture := {
	"slot_buffalo_config": {
		"symbols": [
			{"id": "BUFFALO", "shape": "buffalo_head", "colors": ["#6b3a1e", "#d8b36a", "#ffe48a"]},
			{"id": "EAGLE", "shape": "animal_badge", "colors": ["#172554", "#93c5fd", "#f8fafc"]},
			{"id": "WOLF", "shape": "animal_badge", "colors": ["#1f2937", "#94a3b8", "#e2e8f0"]},
			{"id": "COIN", "shape": "coin", "colors": ["#facc15", "#b45309", "#fff7ad"]},
		]
	}
}
var slot_buffalo_active_fixture := {
	"active": true,
	"family": "buffalo",
	"mode": "free_games",
	"display_mode": "free_games",
	"remaining_steps": 8,
	"retrigger_count": 1,
	"coins_collected": 4,
	"coins_since_retrigger": 2,
	"coin_total": 190,
	"spin_win_total": 60,
	"feature_total": 250,
	"collection_meter": {"cycle": 2, "threshold": 3},
	"collected_coins": [
		{"reel": 0, "row": 0, "value": 20},
		{"reel": 2, "row": 1, "value": 50},
		{"reel": 4, "row": 2, "value": 120},
	],
	"last_collected_coins": [{"reel": 2, "row": 1, "value": 50}],
	"coin_reveals": [],
}
var slot_state_fixture := {
	"bankroll": 1240,
	"suspicion_level": 18,
	"slot_selected_bet": 25,
	"slot_nudge_available": true,
	"slot_nudge_chain_active": true,
	"slot_nudge_chain_collected_count": 2,
	"slot_nudge_chain_coins": [{"value": 15}, {"value": 20}, {"value": 40}],
	"slot_nudge_chain_banked_payout": 75,
	"slot_active_bonus": slot_buffalo_active_fixture,
	"slot_type_id": "buffalo",
	"slot_grid": [
		["BUFFALO", "EAGLE", "WOLF"],
		["COIN", "BUFFALO", "EAGLE"],
		["WOLF", "COIN", "BUFFALO"],
		["EAGLE", "WOLF", "COIN"],
		["BUFFALO", "COIN", "WOLF"],
	],
	"slot_reel_strips": [
		["BUFFALO", "EAGLE", "WOLF", "COIN"],
		["COIN", "BUFFALO", "EAGLE", "WOLF"],
		["WOLF", "COIN", "BUFFALO", "EAGLE"],
		["EAGLE", "WOLF", "COIN", "BUFFALO"],
		["BUFFALO", "COIN", "WOLF", "EAGLE"],
	],
	"slot_reel_stops": [0, 1, 2, 3, 0],
	"slot_reel_count": 5,
	"slot_row_count": 3,
	"slot_reel_timeline": [],
}
var slot_pinball_active_fixture := {
	"active": true,
	"complete": false,
	"family": "pinball",
	"mode": "lane_multiball",
	"feature_total": 420,
	"awarded": 420,
	"balls_remaining": 2,
	"active_ball_count": 2,
	"max_active_count": 2,
	"lane_locks": 2,
	"combo_state": {"route_id": "left_orbit", "label": "Left Orbit", "step": 2, "multiplier": 3},
	"pinball_view": {
		"time": 1.2,
		"balls": [
			{"ball_index": 0, "position": Vector2(0.36, 0.44), "time": 1.2},
			{"ball_index": 1, "position": Vector2(0.62, 0.34), "time": 1.2},
		],
		"lit": {"lit": {"left_orbit": true}, "trajectory": []},
		"layout": {
			"id": "lane_multiball",
			"board_style": "solid_state",
			"archetype": "lane_multiball",
			"board_title": "Lane Multiball",
			"gravity": Vector2(0.0, 3.15),
			"lane_starts": {"left": Vector2(0.20, 0.075), "center": Vector2(0.50, 0.075), "right": Vector2(0.80, 0.075)},
			"lane_directions": {"left": Vector2(-0.22, 1.0), "center": Vector2(0.0, 1.0), "right": Vector2(0.22, 1.0)},
			"elements": [
				{"id": "left_lane", "type": "lane", "shape": "circle", "position": Vector2(0.25, 0.30), "radius": 0.04, "label": "LANE", "light": "left_orbit"},
				{"id": "right_ramp", "type": "ramp", "shape": "circle", "position": Vector2(0.68, 0.28), "radius": 0.04, "label": "RAMP", "route": Vector2(0.20, -0.30)},
				{"id": "center_lock", "type": "pocket", "shape": "slot_rect", "rect": Rect2(0.42, 0.62, 0.18, 0.10), "label": "LOCK"},
				{"id": "bumper_a", "type": "bumper", "shape": "circle", "position": Vector2(0.45, 0.46), "radius": 0.055, "label": "50"},
				{"id": "target_a", "type": "target", "shape": "circle", "position": Vector2(0.58, 0.54), "radius": 0.035, "label": "A"},
			],
		},
	},
}


class NoopSurface:
	extends RefCounted

	var hit_count := 0
	var label_count := 0

	func draw_circle(_position: Vector2, _radius: float, _color: Color, _filled: bool = true, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass

	func draw_polygon(_points: Array, _colors: Array, _uvs: Array = [], _texture: Texture2D = null) -> void:
		pass

	func draw_line(_from: Vector2, _to: Vector2, _color: Color, _width: float = 1.0, _antialiased: bool = false) -> void:
		pass

	func draw_rect(_rect: Rect2, _color: Color, _filled: bool = true, _width: float = -1.0) -> void:
		pass

	func draw_texture_rect(_texture: Texture2D, _rect: Rect2, _tile: bool, _modulate: Color = Color.WHITE, _transpose: bool = false) -> void:
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

	func surface_region_hovered(_action: String, _index: int = 0) -> bool:
		return false


func _init() -> void:
	bar_dice = _load_script_instance("res://scripts/games/bar_dice.gd") as RefCounted
	blackjack = _load_script_instance("res://scripts/games/blackjack.gd") as RefCounted
	slot_renderer = _load_script_instance("res://scripts/games/slots/slot_renderer.gd") as RefCounted
	game_surface = _load_script_instance("res://scripts/ui/game_surface_canvas.gd") as Control
	if bar_dice == null or blackjack == null or slot_renderer == null or game_surface == null:
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
			_measure_case("slot_status_panel", iterations, warmup_iterations, Callable(self, "_bench_slot_status_panel")),
			_measure_case("slot_buffalo_free_games", iterations, warmup_iterations, Callable(self, "_bench_slot_buffalo_free_games")),
			_measure_case("slot_pinball_backglass", iterations, warmup_iterations, Callable(self, "_bench_slot_pinball_backglass")),
			_measure_case("slot_pinball_playfield", iterations, warmup_iterations, Callable(self, "_bench_slot_pinball_playfield")),
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


func _bench_slot_status_panel(index: int) -> void:
	slot_state_fixture["bankroll"] = 1240 + (index % 4) * 5
	slot_state_fixture["suspicion_level"] = 18 + (index % 3)
	slot_buffalo_active_fixture["feature_total"] = 250 + (index % 5) * 10
	slot_renderer.call("_draw_status_panel", noop_surface, slot_state_fixture, slot_skin_fixture, Color("#ff4fb3"), Color("#35e0ff"), Color("#f7c845"))


func _bench_slot_buffalo_free_games(index: int) -> void:
	slot_buffalo_active_fixture["remaining_steps"] = 8 - (index % 3)
	slot_buffalo_active_fixture["feature_total"] = 250 + (index % 5) * 10
	slot_renderer.call("_draw_buffalo_free_games", noop_surface, Rect2(220, 90, 520, 280), slot_state_fixture, slot_definition_fixture, slot_buffalo_active_fixture, Color("#ff4fb3"), Color("#35e0ff"), Color("#f7c845"), index % 20, 1000 + (index % 300), 1200 + (index % 400))


func _bench_slot_pinball_backglass(index: int) -> void:
	slot_pinball_active_fixture["feature_total"] = 420 + (index % 4) * 25
	slot_renderer.call("_draw_pinball_backglass", noop_surface, Rect2(220, 90, 520, 280), slot_pinball_active_fixture, "lane_multiball", Color("#ff4fb3"), Color("#35e0ff"), Color("#f7c845"), index % 20)


func _bench_slot_pinball_playfield(index: int) -> void:
	slot_pinball_active_fixture["feature_total"] = 420 + (index % 4) * 25
	slot_renderer.call("_draw_pinball_playfield", noop_surface, Rect2(220, 90, 520, 280), {"slot_skin": {"cabinet_identity": "lane_multiball"}}, slot_pinball_active_fixture, Color("#ff4fb3"), Color("#35e0ff"), Color("#f7c845"), index % 20, 1000 + (index % 400))


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
