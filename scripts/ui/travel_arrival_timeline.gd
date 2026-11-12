extends RefCounted

# Pure presentation choreography in normalized street-art coordinates. No run
# state, wall clock, outcome resolution or RNG is available to this model.
const DURATION_SECONDS := 8.0
const CAMERA_END_UV := 0.18
const BACKGROUND_CAMERA_RATE := 0.35
const FOREGROUND_CAMERA_RATE := 1.0
const BUS_START_LEFT_UV := -0.50
const BUS_STOP_LEFT_UV := 0.28
const BUS_WIDTH_UV := 0.42
const BUS_ROAD_Y_UV := 0.95
const BUS_DEPARTURE_DISTANCE_UV := 0.82
const BUS_WHEEL_RADIUS_UV := BUS_WIDTH_UV * 86.0 / 1749.0
const BUS_BODY_BOB_MAX_PIXELS := 1.15
const WALK_CADENCE_SCALE := 1.10
const WALK_BLEND_IN_SECONDS := 0.18
const WALK_BLEND_OUT_SECONDS := 0.20
const WALK_TRANSIT_SECONDS := 3.30
const BAR_DOOR_UV := Vector2(0.758, 0.765)
const PLAYER_START_UV := Vector2(0.6508, 0.90)
const PLAYER_CURB_UV := Vector2(0.67, 0.95)
const BUS_STOP_SECONDS := 1.45
const DROPOFF_SECONDS := 1.80
const DOOR_CLOSE_SECONDS := 2.50
const BUS_DEPARTURE_SECONDS := 2.75
const WALK_SECONDS := 4.45
const DOOR_REACH_SECONDS := 6.15
const ENTER_SECONDS := 6.65
const ENTRY_INSIDE_SECONDS := 7.25
const DESTINATION_CLOSE_SECONDS := 7.90
const ARRIVAL_SECONDS := DESTINATION_CLOSE_SECONDS
const CAR_WIDTH_UV := 0.32
const CAR_STOP_LEFT_UV := 0.37
const CAR_DOOR_CENTER_UV := 0.48
const CAR_WHEEL_RADIUS_UV := 0.027
const CAR_STEP_Y_UV := 0.90
const CAR_PLAYER_CURB_UV := Vector2(0.56, 0.95)
const WALK_START_UV := Vector2(0.06, 0.94)
const WALK_APPROACH_OFFSET_UV := Vector2(0.088, 0.0)
const MODES := ["bus", "walk", "taxi", "night_cab"]


static func sample(seconds: float, mode: String = "bus", profile: Dictionary = {}) -> Dictionary:
	var t := clampf(seconds, 0.0, DURATION_SECONDS) if not is_nan(seconds) else 0.0
	var resolved_mode := mode if mode in MODES else "bus"
	var geometry := _vehicle_geometry(resolved_mode, profile)
	var destination := _profile_vector2(profile, "destination_anchor_uv", BAR_DOOR_UV)
	var inside := _profile_vector2(profile, "destination_inside_uv", destination + Vector2(0.0, -0.055))
	var entrance_kind := str(profile.get("entrance_kind", "door"))
	if entrance_kind not in ["door", "open", "passage", "dock"]: entrance_kind = "open"
	var has_door := entrance_kind == "door"
	var on_foot := resolved_mode == "walk"
	var start_left: float = geometry["start_left_uv"]
	var stop_left: float = geometry["stop_left_uv"]
	var departure_distance: float = geometry["departure_distance_uv"]
	var road: float = geometry["road_y_uv"]
	var approach_time := _range(t, 0.0, BUS_STOP_SECONDS)
	var approach := _ease_out(approach_time)
	var departure_time := _range(t, BUS_DEPARTURE_SECONDS, WALK_SECONDS)
	var departing := departure_time * departure_time
	var dropoff := _smooth(_range(t, DROPOFF_SECONDS, DOOR_CLOSE_SECONDS))
	var curb: Vector2 = geometry["player_curb_uv"]
	var walk_start := WALK_TRANSIT_SECONDS if on_foot else BUS_DEPARTURE_SECONDS + sqrt(clampf((curb.x + 0.02 - stop_left) / departure_distance, 0.0, 1.0)) * (WALK_SECONDS - BUS_DEPARTURE_SECONDS)
	var walking := _range(t, walk_start, DOOR_REACH_SECONDS)
	var entering := _smooth(_range(t, ENTER_SECONDS, ENTRY_INSIDE_SECONDS)) if has_door else _smooth(_range(t, DOOR_REACH_SECONDS, DESTINATION_CLOSE_SECONDS))
	# A single advancing camera owns both layers, including all door pauses.
	# Wider destination crops receive a smaller positive distance, never a clamp.
	var camera_end := clampf(_profile_number(profile, "camera_end_uv", CAMERA_END_UV), 0.001, 0.25)
	var camera_approach := minf(0.07, camera_end * 0.32)
	var camera := camera_approach * approach + (camera_end - camera_approach) * t / DURATION_SECONDS
	var vehicle_distance := (stop_left - start_left) * approach + departure_distance * departing
	var vehicle_speed := 0.0
	var suspension_envelope := 0.0
	if t < BUS_STOP_SECONDS:
		vehicle_speed = (stop_left - start_left) * 3.0 * pow(1.0 - approach_time, 2.0) / BUS_STOP_SECONDS
		suspension_envelope = sin(PI * approach)
	elif t > BUS_DEPARTURE_SECONDS and t < WALK_SECONDS:
		vehicle_speed = 2.0 * departure_distance * departure_time / (WALK_SECONDS - BUS_DEPARTURE_SECONDS)
		suspension_envelope = sin(PI * departing)
	var wheel_angle := vehicle_distance / float(geometry["wheel_radius_uv"])
	# Restrained road suspension uses an irregular deterministic time signal,
	# not wheel phase or randomness. Changing wheel size cannot speed its bounce.
	var road_motion := 0.68 * sin(t * 4.7 + 0.16) + 0.22 * sin(t * 7.9 - 0.80) + 0.10 * sin(t * 11.3 + 0.45)
	var body_bob := BUS_BODY_BOB_MAX_PIXELS * road_motion * suspension_envelope
	var player_start: Vector2 = geometry["player_start_uv"]
	var player := player_start.lerp(curb, dropoff)
	if on_foot:
		curb = _profile_vector2(profile, "player_curb_uv", Vector2(destination.x - 0.12, 0.94))
		player = Vector2(WALK_START_UV.x, curb.y).lerp(curb, _range(t, 0.0, walk_start))
		player.y = curb.y
	if t >= walk_start: player = _approach_position(curb, destination, walking, profile)
	if (has_door and t >= ENTER_SECONDS) or (not has_door and t >= DOOR_REACH_SECONDS): player = destination.lerp(inside, entering)
	var transit_clock := minf(t, walk_start) if on_foot else clampf(t - DROPOFF_SECONDS, 0.0, DOOR_CLOSE_SECONDS - DROPOFF_SECONDS)
	var approach_clock := clampf(t - walk_start, 0.0, DOOR_REACH_SECONDS - walk_start)
	var entry_clock := clampf(t - ENTER_SECONDS, 0.0, ENTRY_INSIDE_SECONDS - ENTER_SECONDS) if has_door else clampf(t - DOOR_REACH_SECONDS, 0.0, DESTINATION_CLOSE_SECONDS - DOOR_REACH_SECONDS)
	var player_motion_seconds := transit_clock + approach_clock + entry_clock
	# Integrating a bounded cadence signal keeps the phase continuous instead
	# of restarting a short loop at each beat, turn or door pause. Its rate is
	# always within 6% of the original slightly quicker travel cadence.
	var cadence_seconds := player_motion_seconds + 0.035 / 1.73 * (1.0 - cos(player_motion_seconds * 1.73)) + 0.025 / 0.83 * (sin(player_motion_seconds * 0.83 + 0.6) - sin(0.6))
	var player_animation_seconds := cadence_seconds * WALK_CADENCE_SCALE
	var walk_amplitude := 0.94 + 0.04 * sin(player_motion_seconds * 1.13 + 0.4) + 0.02 * sin(player_motion_seconds * 2.37 + 1.2)
	# Adjacent movement beats share one envelope. Only a physical stop brings
	# the limbs gently to rest; semantic pose switches do not snap the arms.
	var approach_end := DOOR_REACH_SECONDS if has_door else DESTINATION_CLOSE_SECONDS
	var walk_weight := _walk_envelope(t, 0.0 if on_foot else walk_start, approach_end)
	if not on_foot:
		walk_weight = maxf(walk_weight, _walk_envelope(t, DROPOFF_SECONDS, DOOR_CLOSE_SECONDS))
	if has_door:
		walk_weight = maxf(walk_weight, _walk_envelope(t, ENTER_SECONDS, ENTRY_INSIDE_SECONDS))
	var player_moving := (on_foot and t < walk_start) or (not on_foot and t >= DROPOFF_SECONDS and t < DOOR_CLOSE_SECONDS) or (t >= walk_start and t < DOOR_REACH_SECONDS) or (has_door and t >= ENTER_SECONDS and t < ENTRY_INSIDE_SECONDS) or (not has_door and t >= DOOR_REACH_SECONDS and t < DESTINATION_CLOSE_SECONDS)
	var facing_away := false
	if t >= walk_start:
		var direction := _approach_direction(curb, destination, walking, profile)
		if (has_door and t >= ENTER_SECONDS) or (not has_door and t >= DOOR_REACH_SECONDS):
			direction = inside - destination
		# Genuine movement into scene depth faces back. Sideways transit and
		# stepping out toward the camera retain the canonical front-facing view.
		facing_away = direction.y < -0.001
	var beat := "walk" if on_foot else "approach"
	if t >= DESTINATION_CLOSE_SECONDS: beat = "arrival"
	elif has_door and t >= ENTRY_INSIDE_SECONDS: beat = "close_door"
	elif has_door and t >= ENTER_SECONDS: beat = "enter"
	elif t >= DOOR_REACH_SECONDS: beat = "open_door" if has_door else "walk_away"
	elif t >= walk_start: beat = "walk"
	elif not on_foot and t >= BUS_DEPARTURE_SECONDS: beat = "departure"
	elif not on_foot and t >= DROPOFF_SECONDS: beat = "dropoff"
	elif not on_foot and t >= BUS_STOP_SECONDS: beat = "stop"
	var phase := resolved_mode + "_approach"
	match beat:
		"arrival": phase = "arrival"
		"close_door": phase = "destination_close"
		"enter": phase = "enter_bar" if resolved_mode == "bus" else "enter_destination"
		"open_door": phase = "destination_open"
		"walk": phase = "walk_transit" if on_foot and t < walk_start else "approach_door"
		"walk_away": phase = "walk_away"
		"departure": phase = resolved_mode + "_departure"
		"dropoff": phase = "dropoff"
		"stop": phase = resolved_mode + "_stop"
	var vehicle_door := _smooth(_range(t, BUS_STOP_SECONDS, DROPOFF_SECONDS)) * (1.0 - _smooth(_range(t, DOOR_CLOSE_SECONDS, BUS_DEPARTURE_SECONDS)))
	var destination_door := _smooth(_range(t, DOOR_REACH_SECONDS, ENTER_SECONDS)) * (1.0 - _smooth(_range(t, ENTRY_INSIDE_SECONDS, DESTINATION_CLOSE_SECONDS))) if has_door else 0.0
	var first_length := Vector2(WALK_START_UV.x, curb.y).distance_to(curb) if on_foot else player_start.distance_to(curb)
	var middle_length := _approach_length(curb, destination, profile)
	var last_length := destination.distance_to(inside)
	var transport_length := 0.0 if on_foot else stop_left - start_left
	var total_length := maxf(transport_length + first_length + middle_length + last_length, 0.000001)
	var first_progress := _range(t, 0.0, walk_start) if on_foot else dropoff
	var travelled := transport_length * approach + first_length * first_progress + middle_length * walking + last_length * entering
	var progress := clampf(travelled / total_length, 0.0, 1.0)
	if has_door: progress = progress * 0.98 + 0.02 * _smooth(_range(t, ENTRY_INSIDE_SECONDS, DESTINATION_CLOSE_SECONDS))
	# The actor never grows while exiting or approaching. Only the explicit
	# outdoor walk-away recedes into depth; a door occludes normal-size entry.
	var entry_scale := 1.0
	if not has_door:
		var end_scale := clampf(_profile_number(profile, "walkaway_end_scale", 0.58, true), 0.05, 1.0)
		var start_scale := 1.0
		if bool(profile.get("walkaway_scale_during_approach", false)):
			start_scale = clampf(_profile_number(profile, "walkaway_start_scale", 1.0, true), end_scale, 1.0)
			# Authored depth follows the actual ground plane, including an optional
			# path bend, without changing foot positions or the approach schedule.
			var depth_progress := walking
			if curb.y > destination.y + 0.000001:
				depth_progress = clampf((curb.y - _approach_position(curb, destination, walking, profile).y) / (curb.y - destination.y), 0.0, 1.0)
			entry_scale = lerpf(1.0, start_scale, depth_progress)
		if t >= DOOR_REACH_SECONDS:
			entry_scale = lerpf(start_scale, end_scale, entering)
	var state := {
		"mode": resolved_mode, "beat": beat, "phase": phase, "seconds": t,
		"camera_x_uv": camera, "background_camera_x_uv": camera * BACKGROUND_CAMERA_RATE,
		"foreground_camera_x_uv": camera * FOREGROUND_CAMERA_RATE,
		"vehicle_left_uv": start_left + vehicle_distance if not on_foot else 0.0,
		"vehicle_width_uv": geometry["width_uv"] if not on_foot else 0.0,
		"vehicle_road_y_uv": road, "vehicle_visible": not on_foot and t < WALK_SECONDS,
		"vehicle_door_open": vehicle_door if not on_foot else 0.0,
		"vehicle_door_center_uv": geometry["door_center_uv"], "vehicle_step_y_uv": player_start.y,
		"vehicle_wheel_radius_uv": geometry["wheel_radius_uv"],
		"vehicle_wheel_angle": wheel_angle if not on_foot else 0.0,
		"vehicle_body_bob": body_bob if not on_foot else 0.0,
		"vehicle_speed_uv": vehicle_speed if not on_foot else 0.0,
		"vehicle_moving": not on_foot and vehicle_speed > 0.0,
		"destination_anchor_uv": destination, "destination_inside_uv": inside,
		"entrance_kind": entrance_kind, "destination_door_open": destination_door,
		"arrival_progress": progress, "player_approach_start_seconds": walk_start,
		"entry_progress": entering, "player_facing_away": facing_away, "player_in_entrance": has_door and t >= ENTER_SECONDS,
		"player_visible": (on_foot or t >= DROPOFF_SECONDS) and (not has_door or t < DESTINATION_CLOSE_SECONDS),
		"player_position_uv": player, "player_curb_uv": curb,
		# Entry is never an alpha disappearance. The actual closing leaf covers
		# the actor, then visibility retires only after the door is closed.
		"player_alpha": 1.0,
		"player_scale": entry_scale, "player_motion_seconds": player_motion_seconds,
		"player_animation_seconds": player_animation_seconds,
		"player_walk_weight": walk_weight, "player_walk_amplitude": walk_amplitude,
		"player_idle_seconds": t,
		"player_walk_phase": player_animation_seconds * 8.0, "player_moving": player_moving,
		"walk_frame": int(floor(player_animation_seconds * 7.0)) % 4, "bar_door_open": destination_door,
	}
	for suffix in ["left_uv", "door_open", "wheel_angle", "body_bob", "speed_uv"]: state["bus_" + suffix] = state["vehicle_" + suffix]
	state["bus_visible"] = resolved_mode == "bus" and state["vehicle_visible"]
	state["bus_moving"] = resolved_mode == "bus" and state["vehicle_moving"]
	return state


static func _walk_envelope(seconds: float, start: float, stop: float) -> float:
	# The final outdoor arrival has only 0.10s left before the static receipt.
	# Finish its followthrough inside that beat rather than freezing mid-stride.
	var settle_end := minf(stop + WALK_BLEND_OUT_SECONDS, DURATION_SECONDS)
	return _smooth(_range(seconds, start, start + WALK_BLEND_IN_SECONDS)) * (1.0 - _smooth(_range(seconds, stop, settle_end)))


static func _approach_length(start: Vector2, destination: Vector2, profile: Dictionary) -> float:
	var waypoint := _profile_vector2(profile, "approach_waypoint_uv", destination)
	return start.distance_to(waypoint) + waypoint.distance_to(destination)


static func _approach_position(start: Vector2, destination: Vector2, progress: float, profile: Dictionary) -> Vector2:
	# Optional authored path bend follows a garden path or courtyard approach.
	# Arc-length timing keeps walking speed continuous across both segments.
	var waypoint := _profile_vector2(profile, "approach_waypoint_uv", destination)
	var first := start.distance_to(waypoint)
	var second := waypoint.distance_to(destination)
	var distance := (first + second) * progress
	if distance < first and first > 0.000001:
		return start.lerp(waypoint, distance / first)
	return waypoint.lerp(destination, clampf((distance - first) / maxf(second, 0.000001), 0.0, 1.0))


static func _approach_direction(start: Vector2, destination: Vector2, progress: float, profile: Dictionary) -> Vector2:
	var waypoint := _profile_vector2(profile, "approach_waypoint_uv", destination)
	var first := start.distance_to(waypoint)
	var second := waypoint.distance_to(destination)
	if first > 0.000001 and progress * (first + second) < first:
		return waypoint - start
	return destination - waypoint if second > 0.000001 else waypoint - start


static func _vehicle_geometry(mode: String, profile: Dictionary) -> Dictionary:
	var is_bus := mode == "bus"
	var width := clampf(_profile_number(profile, "vehicle_width_uv", BUS_WIDTH_UV if is_bus else CAR_WIDTH_UV, true), 0.1, 0.8)
	var stop_left := clampf(_profile_number(profile, "vehicle_stop_left_uv", BUS_STOP_LEFT_UV if is_bus else CAR_STOP_LEFT_UV), -0.1, 0.8)
	var road := clampf(_profile_number(profile, "vehicle_road_y_uv", BUS_ROAD_Y_UV), 0.1, 1.0)
	# Door center is normalized within the source vehicle art, not the street.
	var door_center := clampf(_profile_number(profile, "vehicle_door_center_uv", 0.8828 if is_bus else CAR_DOOR_CENTER_UV), 0.0, 1.0)
	var radius := clampf(_profile_number(profile, "vehicle_wheel_radius_uv", BUS_WHEEL_RADIUS_UV if is_bus else CAR_WHEEL_RADIUS_UV, true), 0.001, 0.2)
	var step_y := _profile_number(profile, "vehicle_step_y_uv", PLAYER_START_UV.y if is_bus else CAR_STEP_Y_UV)
	var start_left := -width - 0.08
	var departure_distance := maxf(1.10 - stop_left, 0.1)
	var player_start := Vector2(stop_left + width * door_center, step_y)
	var player_curb := _profile_vector2(profile, "player_curb_uv", PLAYER_CURB_UV if is_bus else CAR_PLAYER_CURB_UV)
	if is_bus and width == BUS_WIDTH_UV and stop_left == BUS_STOP_LEFT_UV and door_center == 0.8828:
		# Preserve the approved bus's exact values, including art rounding.
		start_left = BUS_START_LEFT_UV
		departure_distance = BUS_DEPARTURE_DISTANCE_UV
		player_start = Vector2(PLAYER_START_UV.x, step_y)
	return {
		"width_uv": width,
		"road_y_uv": road,
		"stop_left_uv": stop_left,
		"start_left_uv": start_left,
		"departure_distance_uv": departure_distance,
		"door_center_uv": door_center,
		"wheel_radius_uv": radius,
		"player_start_uv": player_start,
		"player_curb_uv": player_curb,
	}


static func _profile_number(profile: Dictionary, key: String, fallback: float, positive: bool = false) -> float:
	var value: Variant = profile.get(key, fallback)
	if not (value is float or value is int):
		return fallback
	var number := float(value)
	if not is_finite(number) or (positive and number <= 0.0):
		return fallback
	return number


static func _profile_vector2(profile: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var anchor: Variant = profile.get(key, fallback)
	if anchor is Vector2 and is_finite(anchor.x) and is_finite(anchor.y):
		return anchor
	return fallback


static func _range(value: float, start: float, end: float) -> float:
	return clampf((value - start) / (end - start), 0.0, 1.0)


static func _smooth(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)


static func _ease_out(value: float) -> float:
	return 1.0 - pow(1.0 - value, 3.0)
