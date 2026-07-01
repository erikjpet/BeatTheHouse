class_name PinballBoards
extends RefCounted

# Board content for the rebuilt pinball slot feature. Phase 1 exposes Board A
# only; later phases add Lock & Cascade and Jackpot Works here.


static func bumper_alley() -> Dictionary:
	var pegs: Array = []
	_add_peg_pyramid(pegs, "alley_peg", 7, 5, 9, 0.18, 0.088, 0.18, 0.82, 1, 0.013)
	return {
		"id": "bumper_alley",
		"mode": "em_bumper_drop",
		"title": "Bumper Alley",
		"summary": "Fast EM-style peg pyramid with twin pop bumpers, slingshots, a skill saucer, and pocket-row returns.",
		"gravity": 3.15,
		"ball_radius": 0.013,
		"peg_restitution": 0.56,
		"wall_restitution": 0.40,
		"linear_damping": 0.999,
		"max_speed": 9.0,
		"max_ticks": 960,
		"max_balls": 12,
		"active_ball_cap": 8,
		"event_ring_size": 512,
		"max_events_per_tick": 12,
		"tilt_threshold": 1.0,
		"tilt_decay_per_tick": 0.006,
		"tilt_per_nudge": 0.34,
		"launch_position": Vector2(0.50, 0.075),
		"launch_min_speed": 0.55,
		"launch_max_speed": 1.85,
		"launch_spread": 0.035,
		"skill_power": 0.82,
		"skill_width": 0.03,
		"pegs": pegs,
		"bumpers": [
			_circle("left_pop", Vector2(0.32, 0.51), 0.046, 5, {"kick": Vector2(1.05, -2.35), "restitution": 0.78, "cooldown_ticks": 7}),
			_circle("right_pop", Vector2(0.68, 0.51), 0.046, 5, {"kick": Vector2(-1.05, -2.35), "restitution": 0.78, "cooldown_ticks": 7}),
		],
		"sensors": [
			_sensor("skill_saucer", "skill", Vector2(0.84, 0.225), 0.050, 24, {"kick": Vector2(-0.80, 1.25), "cooldown_ticks": 24}),
			_sensor("left_sling", "slingshot", Vector2(0.24, 0.74), 0.052, 4, {"kick": Vector2(1.80, -2.10), "cooldown_ticks": 10}),
			_sensor("right_sling", "slingshot", Vector2(0.76, 0.74), 0.052, 4, {"kick": Vector2(-1.80, -2.10), "cooldown_ticks": 10}),
			_sensor("return_launcher", "launcher", Vector2(0.50, 0.805), 0.048, 6, {"kick": Vector2(0.25, -2.85), "cooldown_ticks": 18}),
			_sensor("double_left", "multiplier", Vector2(0.36, 0.645), 0.040, 3, {"cooldown_ticks": 24}),
			_sensor("double_right", "multiplier", Vector2(0.64, 0.645), 0.040, 3, {"cooldown_ticks": 24}),
		],
		"rects": [
			_rect("left_outlane", "drain", Rect2(Vector2(0.00, 0.915), Vector2(0.075, 0.110)), 0),
			_rect("left_pocket", "pocket", Rect2(Vector2(0.075, 0.925), Vector2(0.185, 0.090)), 10),
			_rect("left_mid_pocket", "pocket", Rect2(Vector2(0.260, 0.925), Vector2(0.185, 0.090)), 16),
			_rect("safe_pocket", "pocket", Rect2(Vector2(0.445, 0.925), Vector2(0.110, 0.090)), 24),
			_rect("right_mid_pocket", "pocket", Rect2(Vector2(0.555, 0.925), Vector2(0.185, 0.090)), 16),
			_rect("right_pocket", "pocket", Rect2(Vector2(0.740, 0.925), Vector2(0.185, 0.090)), 10),
			_rect("right_outlane", "drain", Rect2(Vector2(0.925, 0.915), Vector2(0.075, 0.110)), 0),
		],
		"flippers": [
			{"id": "left_flipper", "side": -1, "position": Vector2(0.14, 0.845), "radius": 0.095, "kick": Vector2(1.45, -3.25)},
			{"id": "right_flipper", "side": 1, "position": Vector2(0.86, 0.845), "radius": 0.095, "kick": Vector2(-1.45, -3.25)},
		],
		"sequences": ["skill_shot", "bumper_streak", "alley_loop"],
	}


static func by_id(board_id: String) -> Dictionary:
	match board_id:
		"bumper_alley", "em_bumper_drop", "":
			return bumper_alley()
		_:
			return bumper_alley()


static func _add_peg_pyramid(elements: Array, prefix: String, rows: int, min_columns: int, max_columns: int, y_start: float, y_step: float, x_min: float, x_max: float, award: int, radius: float) -> void:
	for row in range(maxi(1, rows)):
		var columns := clampi(min_columns + row, min_columns, max_columns)
		var row_width := x_max - x_min
		var inset := 0.0 if row % 2 == 0 else row_width / float(maxi(2, columns)) * 0.5
		for column in range(columns):
			var ratio := float(column) / float(maxi(1, columns - 1))
			var x := lerpf(x_min + inset, x_max - inset, ratio)
			var y := y_start + float(row) * y_step
			var id := "%s_%02d_%02d" % [prefix, row, column]
			elements.append({
				"id": id,
				"position": Vector2(x, y),
				"radius": radius,
				"award": award,
				"bias": _hash_signed(id) * 0.030,
				"restitution": 0.56,
			})


static func _circle(id: String, position: Vector2, radius: float, award: int, extras: Dictionary = {}) -> Dictionary:
	var element := {
		"id": id,
		"position": position,
		"radius": radius,
		"award": award,
	}
	for key_value in extras.keys():
		element[str(key_value)] = extras[key_value]
	return element


static func _sensor(id: String, sensor_type: String, position: Vector2, radius: float, award: int, extras: Dictionary = {}) -> Dictionary:
	var element := _circle(id, position, radius, award, extras)
	element["type"] = sensor_type
	return element


static func _rect(id: String, rect_type: String, rect: Rect2, award: int, extras: Dictionary = {}) -> Dictionary:
	var element := {
		"id": id,
		"type": rect_type,
		"rect": rect,
		"award": award,
	}
	for key_value in extras.keys():
		element[str(key_value)] = extras[key_value]
	return element


static func _hash_signed(key: String) -> float:
	var hash := 0
	for index in range(key.length()):
		hash = posmod(hash * 31 + key.unicode_at(index), 9973)
	return -1.0 if hash % 2 == 0 else 1.0
