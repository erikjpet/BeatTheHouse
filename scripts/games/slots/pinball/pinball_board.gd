class_name PinballBoard
extends RefCounted

const SENSOR_SKILL := 1
const SENSOR_SLINGSHOT := 2
const SENSOR_LAUNCHER := 3
const SENSOR_MULTIPLIER := 4

const RECT_DRAIN := 1
const RECT_POCKET := 2


func compile(layout: Dictionary, modifiers: Dictionary = {}) -> Dictionary:
	var peg_positions := PackedVector2Array()
	var peg_radii := PackedFloat32Array()
	var peg_awards := PackedInt32Array()
	var peg_restitution := PackedFloat32Array()
	var peg_bias := PackedFloat32Array()
	for peg_value in _array(layout.get("pegs", [])):
		var peg := _dict(peg_value)
		peg_positions.append(_vector2(peg.get("position", Vector2.ZERO), Vector2.ZERO))
		peg_radii.append(maxf(0.001, float(peg.get("radius", 0.013))))
		peg_awards.append(maxi(0, int(peg.get("award", 0))))
		var rest := float(peg.get("restitution", layout.get("peg_restitution", 0.56)))
		if bool(modifiers.get("rubber_pegs", false)):
			rest *= 1.15
		peg_restitution.append(clampf(rest, 0.05, 0.95))
		peg_bias.append(float(peg.get("bias", 0.0)))

	var bumper_positions := PackedVector2Array()
	var bumper_radii := PackedFloat32Array()
	var bumper_awards := PackedInt32Array()
	var bumper_restitution := PackedFloat32Array()
	var bumper_kicks := PackedVector2Array()
	var bumper_cooldowns := PackedInt32Array()
	for bumper_value in _array(layout.get("bumpers", [])):
		var bumper := _dict(bumper_value)
		bumper_positions.append(_vector2(bumper.get("position", Vector2.ZERO), Vector2.ZERO))
		bumper_radii.append(maxf(0.001, float(bumper.get("radius", 0.045))))
		bumper_awards.append(maxi(0, int(bumper.get("award", 0))))
		bumper_restitution.append(clampf(float(bumper.get("restitution", 0.78)), 0.05, 1.20))
		bumper_kicks.append(_vector2(bumper.get("kick", Vector2(0.0, -2.35)), Vector2(0.0, -2.35)))
		bumper_cooldowns.append(maxi(1, int(bumper.get("cooldown_ticks", 8))))

	var sensor_positions := PackedVector2Array()
	var sensor_radii := PackedFloat32Array()
	var sensor_types := PackedInt32Array()
	var sensor_awards := PackedInt32Array()
	var sensor_kicks := PackedVector2Array()
	var sensor_cooldowns := PackedInt32Array()
	for sensor_value in _array(layout.get("sensors", [])):
		var sensor := _dict(sensor_value)
		sensor_positions.append(_vector2(sensor.get("position", Vector2.ZERO), Vector2.ZERO))
		sensor_radii.append(maxf(0.001, float(sensor.get("radius", 0.040))))
		sensor_types.append(_sensor_type_id(str(sensor.get("type", ""))))
		sensor_awards.append(maxi(0, int(sensor.get("award", 0))))
		sensor_kicks.append(_vector2(sensor.get("kick", Vector2.ZERO), Vector2.ZERO))
		sensor_cooldowns.append(maxi(1, int(sensor.get("cooldown_ticks", 12))))

	var rect_positions := PackedVector2Array()
	var rect_sizes := PackedVector2Array()
	var rect_types := PackedInt32Array()
	var rect_awards := PackedInt32Array()
	for rect_value in _array(layout.get("rects", [])):
		var rect_element := _dict(rect_value)
		var rect := _rect2(rect_element.get("rect", Rect2()))
		var rect_id := str(rect_element.get("id", ""))
		if _magnet_cup_rect(rect_id):
			rect = _expanded_board_rect(rect, clampi(int(modifiers.get("magnet_cup_radius_percent", 0)), 0, 100))
		rect_positions.append(rect.position)
		rect_sizes.append(rect.size)
		rect_types.append(_rect_type_id(str(rect_element.get("type", ""))))
		rect_awards.append(maxi(0, int(rect_element.get("award", 0))))

	var flipper_positions := PackedVector2Array()
	var flipper_radii := PackedFloat32Array()
	var flipper_sides := PackedInt32Array()
	var flipper_kicks := PackedVector2Array()
	for flipper_value in _array(layout.get("flippers", [])):
		var flipper := _dict(flipper_value)
		flipper_positions.append(_vector2(flipper.get("position", Vector2.ZERO), Vector2.ZERO))
		flipper_radii.append(maxf(0.001, float(flipper.get("radius", 0.095))))
		flipper_sides.append(clampi(int(flipper.get("side", 0)), -1, 1))
		flipper_kicks.append(_vector2(flipper.get("kick", Vector2.ZERO), Vector2.ZERO))

	var sequence_names := PackedStringArray()
	for sequence_value in _array(layout.get("sequences", [])):
		sequence_names.append(str(sequence_value))

	return {
		"id": str(layout.get("id", "")),
		"mode": str(layout.get("mode", "")),
		"title": str(layout.get("title", "")),
		"summary": str(layout.get("summary", "")),
		"gravity": float(layout.get("gravity", 3.15)),
		"ball_radius": float(layout.get("ball_radius", 0.013)),
		"wall_restitution": float(layout.get("wall_restitution", 0.40)),
		"linear_damping": float(layout.get("linear_damping", 0.999)),
		"max_speed": float(layout.get("max_speed", 9.0)),
		"max_ticks": maxi(1, int(layout.get("max_ticks", 960))),
		"max_balls": maxi(1, int(layout.get("max_balls", 12))),
		"active_ball_cap": maxi(1, int(layout.get("active_ball_cap", 8))),
		"event_ring_size": maxi(32, int(layout.get("event_ring_size", 512))),
		"max_events_per_tick": maxi(1, int(layout.get("max_events_per_tick", 12))),
		"tilt_threshold": float(layout.get("tilt_threshold", 1.0)),
		"tilt_decay_per_tick": float(layout.get("tilt_decay_per_tick", 0.006)),
		"tilt_per_nudge": float(layout.get("tilt_per_nudge", 0.34)) * maxf(0.10, 1.0 - float(clampi(int(modifiers.get("tilt_dampener_percent", 0)), 0, 90)) / 100.0),
		"launch_position": _vector2(layout.get("launch_position", Vector2(0.5, 0.075)), Vector2(0.5, 0.075)),
		"launch_min_speed": float(layout.get("launch_min_speed", 0.55)),
		"launch_max_speed": float(layout.get("launch_max_speed", 1.85)),
		"launch_spread": float(layout.get("launch_spread", 0.035)),
		"skill_power": float(layout.get("skill_power", 0.82)),
		"skill_width": float(layout.get("skill_width", 0.03)),
		"peg_positions": peg_positions,
		"peg_radii": peg_radii,
		"peg_awards": peg_awards,
		"peg_restitution": peg_restitution,
		"peg_bias": peg_bias,
		"bumper_positions": bumper_positions,
		"bumper_radii": bumper_radii,
		"bumper_awards": bumper_awards,
		"bumper_restitution": bumper_restitution,
		"bumper_kicks": bumper_kicks,
		"bumper_cooldowns": bumper_cooldowns,
		"sensor_positions": sensor_positions,
		"sensor_radii": sensor_radii,
		"sensor_types": sensor_types,
		"sensor_awards": sensor_awards,
		"sensor_kicks": sensor_kicks,
		"sensor_cooldowns": sensor_cooldowns,
		"rect_positions": rect_positions,
		"rect_sizes": rect_sizes,
		"rect_types": rect_types,
		"rect_awards": rect_awards,
		"flipper_positions": flipper_positions,
		"flipper_radii": flipper_radii,
		"flipper_sides": flipper_sides,
		"flipper_kicks": flipper_kicks,
		"sequence_names": sequence_names,
		"bumper_battery_hits": maxi(0, int(modifiers.get("bumper_battery_hits", 0))),
		"bumper_battery_award_percent": maxi(0, int(modifiers.get("bumper_battery_award_percent", 0))),
		"bumper_battery_kick_percent": maxi(0, int(modifiers.get("bumper_battery_kick_percent", 100))),
		"return_spring_uses": maxi(0, int(modifiers.get("return_spring_uses", 0))),
		"return_spring_impulse": maxi(0, int(modifiers.get("return_spring_impulse", 0))),
		"peg_count": peg_positions.size(),
		"bumper_count": bumper_positions.size(),
		"sensor_count": sensor_positions.size(),
		"rect_count": rect_positions.size(),
		"flipper_count": flipper_positions.size(),
	}


static func _sensor_type_id(sensor_type: String) -> int:
	match sensor_type:
		"skill":
			return SENSOR_SKILL
		"slingshot":
			return SENSOR_SLINGSHOT
		"launcher":
			return SENSOR_LAUNCHER
		"multiplier":
			return SENSOR_MULTIPLIER
		_:
			return 0


static func _rect_type_id(rect_type: String) -> int:
	match rect_type:
		"drain":
			return RECT_DRAIN
		"pocket":
			return RECT_POCKET
		_:
			return 0


static func _array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return value as Array


static func _dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value as Dictionary


static func _vector2(value: Variant, fallback: Vector2) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value as Vector2
	if typeof(value) == TYPE_DICTIONARY:
		var dict := value as Dictionary
		return Vector2(float(dict.get("x", fallback.x)), float(dict.get("y", fallback.y)))
	if typeof(value) == TYPE_ARRAY:
		var array := value as Array
		if array.size() >= 2:
			return Vector2(float(array[0]), float(array[1]))
	return fallback


static func _rect2(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value as Rect2
	if typeof(value) == TYPE_DICTIONARY:
		var dict := value as Dictionary
		if dict.has("position") and dict.has("size"):
			return Rect2(_vector2(dict.get("position", Vector2.ZERO), Vector2.ZERO), _vector2(dict.get("size", Vector2.ZERO), Vector2.ZERO))
		return Rect2(Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0))), Vector2(float(dict.get("w", 0.0)), float(dict.get("h", 0.0))))
	return Rect2()


static func _magnet_cup_rect(rect_id: String) -> bool:
	return rect_id.find("jackpot") >= 0 or rect_id.find("risk") >= 0


static func _expanded_board_rect(rect: Rect2, percent: int) -> Rect2:
	if percent <= 0:
		return rect
	var grow := clampf(float(percent) / 100.0 * 0.020, 0.0, 0.080)
	var min_point := Vector2(maxf(0.0, rect.position.x - grow), maxf(0.0, rect.position.y - grow))
	var max_point := Vector2(minf(1.0, rect.end.x + grow), minf(1.030, rect.end.y + grow))
	return Rect2(min_point, max_point - min_point)
