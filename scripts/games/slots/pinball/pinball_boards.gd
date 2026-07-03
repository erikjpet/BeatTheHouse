class_name PinballBoards
extends RefCounted

# Board content for the rebuilt pinball slot feature. Phase 1 exposes Board A
# only; later phases add Lock & Cascade and Jackpot Works here.


static func bumper_alley() -> Dictionary:
	var pegs: Array = []
	_add_peg_pyramid(pegs, "alley_peg", 6, 5, 8, 0.18, 0.098, 0.18, 0.82, 1, 0.013)
	return {
		"id": "bumper_alley",
		"mode": "em_bumper_drop",
		"title": "Bumper Alley",
		"summary": "Fast EM-style peg pyramid with twin pop bumpers, slingshots, a skill saucer, and pocket-row returns.",
		"gravity": 6.20,
		"ball_radius": 0.013,
		"peg_restitution": 0.56,
		"wall_restitution": 0.40,
		"linear_damping": 0.996,
		"max_speed": 10.0,
		"max_ticks": 660,
		"max_balls": 12,
		"active_ball_cap": 8,
		"event_ring_size": 512,
		"max_events_per_tick": 12,
		"tilt_threshold": 1.0,
		"tilt_decay_per_tick": 0.006,
		"tilt_per_nudge": 0.34,
		"launch_position": Vector2(0.50, 0.075),
		"launch_min_speed": 0.85,
		"launch_max_speed": 2.35,
		"launch_spread": 0.035,
		"skill_power": 0.82,
		"skill_width": 0.03,
		"pegs": pegs,
		"bumpers": [
			_circle("left_pop", Vector2(0.32, 0.51), 0.046, 5, {"kick": Vector2(1.05, -2.05), "restitution": 0.76, "cooldown_ticks": 7}),
			_circle("right_pop", Vector2(0.68, 0.51), 0.046, 5, {"kick": Vector2(-1.05, -2.05), "restitution": 0.76, "cooldown_ticks": 7}),
		],
		"sensors": [
			_sensor("skill_saucer", "skill", Vector2(0.84, 0.225), 0.056, 18, {"kick": Vector2(-0.80, 1.10), "cooldown_ticks": 24, "label": "SKILL"}),
			_sensor("left_sling", "slingshot", Vector2(0.24, 0.74), 0.056, 4, {"kick": Vector2(1.70, -1.55), "cooldown_ticks": 10, "label": "SLING"}),
			_sensor("right_sling", "slingshot", Vector2(0.76, 0.74), 0.056, 4, {"kick": Vector2(-1.70, -1.55), "cooldown_ticks": 10, "label": "SLING"}),
			_sensor("return_launcher", "launcher", Vector2(0.50, 0.805), 0.054, 6, {"kick": Vector2(0.25, -2.35), "cooldown_ticks": 18, "label": "UP"}),
			_sensor("double_left", "gate", Vector2(0.36, 0.645), 0.044, 3, {"cooldown_ticks": 24, "label": "2X"}),
			_sensor("double_right", "gate", Vector2(0.64, 0.645), 0.044, 3, {"cooldown_ticks": 24, "label": "2X"}),
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


static func lock_cascade() -> Dictionary:
	var pegs: Array = []
	_add_peg_pyramid(pegs, "cascade_peg", 7, 6, 10, 0.145, 0.088, 0.13, 0.87, 1, 0.0125)
	return {
		"id": "lock_cascade",
		"mode": "lane_multiball",
		"title": "Lock & Cascade",
		"summary": "Dense modern board with two lock gates, a splitter, multiplier gate, portal re-entry, and jackpot cup.",
		"gravity": 6.45,
		"ball_radius": 0.013,
		"peg_restitution": 0.60,
		"wall_restitution": 0.44,
		"linear_damping": 0.996,
		"max_speed": 10.4,
		"max_ticks": 760,
		"max_balls": 12,
		"active_ball_cap": 8,
		"event_ring_size": 640,
		"max_events_per_tick": 14,
		"tilt_threshold": 1.05,
		"tilt_decay_per_tick": 0.006,
		"tilt_per_nudge": 0.34,
		"launch_position": Vector2(0.50, 0.075),
		"launch_min_speed": 0.90,
		"launch_max_speed": 2.55,
		"launch_spread": 0.040,
		"skill_power": 0.72,
		"skill_width": 0.035,
		"pegs": pegs,
		"bumpers": [
			_circle("left_pop", Vector2(0.31, 0.43), 0.045, 5, {"kick": Vector2(1.15, -1.95), "restitution": 0.78, "cooldown_ticks": 7}),
			_circle("top_pop", Vector2(0.50, 0.36), 0.046, 6, {"kick": Vector2(0.0, -2.20), "restitution": 0.82, "cooldown_ticks": 7}),
			_circle("right_pop", Vector2(0.69, 0.43), 0.045, 5, {"kick": Vector2(-1.15, -1.95), "restitution": 0.78, "cooldown_ticks": 7}),
		],
		"sensors": [
			_sensor("left_lock", "launcher", Vector2(0.22, 0.59), 0.062, 10, {"kick": Vector2(0.95, -2.05), "cooldown_ticks": 18, "label": "LOCK"}),
			_sensor("right_lock", "launcher", Vector2(0.78, 0.59), 0.062, 10, {"kick": Vector2(-0.95, -2.05), "cooldown_ticks": 18, "label": "LOCK"}),
			_sensor("splitter", "skill", Vector2(0.50, 0.245), 0.058, 14, {"kick": Vector2(0.0, 1.30), "cooldown_ticks": 18, "label": "SPLIT"}),
			_sensor("multiplier_gate", "gate", Vector2(0.50, 0.705), 0.052, 6, {"kick": Vector2(0.0, -1.25), "cooldown_ticks": 20, "label": "GATE"}),
			_sensor("portal_return", "launcher", Vector2(0.86, 0.785), 0.052, 8, {"kick": Vector2(-1.25, -2.50), "cooldown_ticks": 24, "label": "PORT"}),
			_sensor("left_sling", "slingshot", Vector2(0.25, 0.78), 0.056, 4, {"kick": Vector2(1.70, -1.45), "cooldown_ticks": 10, "label": "SLING"}),
			_sensor("right_sling", "slingshot", Vector2(0.75, 0.78), 0.056, 4, {"kick": Vector2(-1.70, -1.45), "cooldown_ticks": 10, "label": "SLING"}),
		],
		"rects": [
			_rect("left_outlane", "drain", Rect2(Vector2(0.00, 0.915), Vector2(0.070, 0.110)), 0),
			_rect("left_pocket", "pocket", Rect2(Vector2(0.070, 0.925), Vector2(0.180, 0.090)), 14),
			_rect("left_mid_pocket", "pocket", Rect2(Vector2(0.250, 0.925), Vector2(0.180, 0.090)), 20),
			_rect("jackpot_cup", "pocket", Rect2(Vector2(0.430, 0.925), Vector2(0.140, 0.090)), 28),
			_rect("right_mid_pocket", "pocket", Rect2(Vector2(0.570, 0.925), Vector2(0.180, 0.090)), 20),
			_rect("right_pocket", "pocket", Rect2(Vector2(0.750, 0.925), Vector2(0.180, 0.090)), 14),
			_rect("right_outlane", "drain", Rect2(Vector2(0.930, 0.915), Vector2(0.070, 0.110)), 0),
		],
		"flippers": [
			{"id": "left_flipper", "side": -1, "position": Vector2(0.15, 0.850), "radius": 0.098, "kick": Vector2(1.55, -3.35)},
			{"id": "right_flipper", "side": 1, "position": Vector2(0.85, 0.850), "radius": 0.098, "kick": Vector2(-1.55, -3.35)},
		],
		"sequences": ["locks_multiball", "cascade", "jackpot", "portal_combo"],
	}


static func jackpot_works() -> Dictionary:
	var pegs: Array = []
	_add_peg_pyramid(pegs, "works_peg", 8, 7, 11, 0.130, 0.078, 0.12, 0.88, 1, 0.012)
	return {
		"id": "jackpot_works",
		"mode": "video_feature",
		"title": "Jackpot Works",
		"summary": "High-volatility lab board with A-B-C target bank, launchers, spinner lane, super lane, and risk cup.",
		"gravity": 6.80,
		"ball_radius": 0.013,
		"peg_restitution": 0.58,
		"wall_restitution": 0.46,
		"linear_damping": 0.996,
		"max_speed": 10.8,
		"max_ticks": 840,
		"max_balls": 12,
		"active_ball_cap": 8,
		"event_ring_size": 768,
		"max_events_per_tick": 16,
		"tilt_threshold": 1.0,
		"tilt_decay_per_tick": 0.005,
		"tilt_per_nudge": 0.35,
		"launch_position": Vector2(0.76, 0.075),
		"launch_min_speed": 0.95,
		"launch_max_speed": 2.75,
		"launch_spread": 0.045,
		"skill_power": 0.86,
		"skill_width": 0.028,
		"pegs": pegs,
		"bumpers": [
			_circle("alpha_pop", Vector2(0.30, 0.39), 0.043, 5, {"kick": Vector2(1.20, -1.85), "restitution": 0.78, "cooldown_ticks": 7}),
			_circle("beta_pop", Vector2(0.48, 0.32), 0.044, 6, {"kick": Vector2(0.35, -2.20), "restitution": 0.82, "cooldown_ticks": 7}),
			_circle("gamma_pop", Vector2(0.66, 0.39), 0.043, 5, {"kick": Vector2(-1.20, -1.85), "restitution": 0.78, "cooldown_ticks": 7}),
			_circle("risk_pop", Vector2(0.78, 0.235), 0.040, 8, {"kick": Vector2(-0.95, 1.45), "restitution": 0.82, "cooldown_ticks": 10}),
		],
		"sensors": [
			_sensor("target_a", "target", Vector2(0.40, 0.505), 0.052, 10, {"kick": Vector2(-0.45, 1.05), "cooldown_ticks": 16, "label": "A"}),
			_sensor("target_b", "target", Vector2(0.50, 0.535), 0.052, 10, {"kick": Vector2(0.0, 1.10), "cooldown_ticks": 16, "label": "B"}),
			_sensor("target_c", "target", Vector2(0.60, 0.505), 0.052, 10, {"kick": Vector2(0.45, 1.05), "cooldown_ticks": 16, "label": "C"}),
			_sensor("left_launcher", "launcher", Vector2(0.20, 0.735), 0.062, 12, {"kick": Vector2(1.10, -2.45), "cooldown_ticks": 20, "label": "LOCK"}),
			_sensor("right_launcher", "launcher", Vector2(0.80, 0.735), 0.062, 12, {"kick": Vector2(-1.10, -2.45), "cooldown_ticks": 20, "label": "LOCK"}),
			_sensor("spinner_lane", "gate", Vector2(0.16, 0.470), 0.044, 4, {"kick": Vector2(0.75, 0.55), "cooldown_ticks": 8, "label": "SPIN"}),
			_sensor("super_lane", "jackpot", Vector2(0.68, 0.635), 0.052, 4, {"kick": Vector2(-0.50, -2.25), "cooldown_ticks": 24, "label": "JACK"}),
		],
		"rects": [
			_rect("left_outlane", "drain", Rect2(Vector2(0.00, 0.915), Vector2(0.070, 0.110)), 0),
			_rect("left_pocket", "pocket", Rect2(Vector2(0.070, 0.925), Vector2(0.180, 0.090)), 12),
			_rect("left_mid_pocket", "pocket", Rect2(Vector2(0.250, 0.925), Vector2(0.180, 0.090)), 18),
			_rect("center_pocket", "jackpot", Rect2(Vector2(0.430, 0.925), Vector2(0.140, 0.090)), 8, {"label": "JACK"}),
			_rect("right_mid_pocket", "pocket", Rect2(Vector2(0.570, 0.925), Vector2(0.180, 0.090)), 18),
			_rect("risk_cup", "super_jackpot", Rect2(Vector2(0.750, 0.890), Vector2(0.180, 0.125)), 24, {"label": "SUPER"}),
			_rect("right_outlane", "drain", Rect2(Vector2(0.930, 0.915), Vector2(0.070, 0.110)), 0),
		],
		"flippers": [
			{"id": "left_flipper", "side": -1, "position": Vector2(0.15, 0.850), "radius": 0.100, "kick": Vector2(1.65, -3.45)},
			{"id": "right_flipper", "side": 1, "position": Vector2(0.85, 0.850), "radius": 0.100, "kick": Vector2(-1.65, -3.45)},
		],
		"sequences": ["qualify_super", "super_jackpot", "video_multiball", "jackpot_works"],
	}


static func by_id(board_id: String) -> Dictionary:
	match board_id:
		"bumper_alley", "em_bumper_drop", "":
			return bumper_alley()
		"lock_cascade", "lane_multiball":
			return lock_cascade()
		"jackpot_works", "video_feature":
			return jackpot_works()
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
