extends SceneTree

const Timeline = preload("res://scripts/ui/travel_arrival_timeline.gd")
const EPSILON := 0.00001
const MODES := ["bus", "walk", "taxi", "night_cab"]
const VEHICLE_MODES := ["bus", "taxi", "night_cab"]
const GENERIC_KEYS := [
	"mode", "beat", "phase", "seconds", "camera_x_uv", "background_camera_x_uv",
	"foreground_camera_x_uv", "vehicle_visible", "vehicle_left_uv", "vehicle_width_uv",
	"vehicle_road_y_uv", "vehicle_door_open", "vehicle_door_center_uv",
	"vehicle_step_y_uv", "vehicle_wheel_radius_uv", "vehicle_wheel_angle", "vehicle_body_bob",
	"vehicle_speed_uv", "vehicle_moving", "destination_anchor_uv", "destination_inside_uv", "entrance_kind",
	"entry_progress", "player_in_entrance", "arrival_progress", "player_approach_start_seconds", "player_facing_away",
	"destination_door_open", "player_visible", "player_position_uv", "player_curb_uv", "player_alpha",
	"player_scale", "player_motion_seconds", "player_animation_seconds", "player_walk_phase", "player_moving", "walk_frame",
]

var _checks: Array[String] = []
var _failures: Array[String] = []


func _initialize() -> void:
	_check_api_and_compatibility()
	_check_shared_clock_for_every_mode()
	_check_vehicle_schedule()
	_check_continuous_walk()
	_check_profiles_and_open_arrivals()
	_check_uniform_actor_scale()
	_check_profile_camera_rates()
	_check_approach_waypoint()
	_check_arrival_progress()
	_check_purity_and_boundaries()
	print("STANDARD_TRAVEL_TIMELINE_CHECK " + JSON.stringify({
		"passed": _failures.is_empty(),
		"check_count": _checks.size(),
		"checks": _checks,
		"failures": _failures,
		"coverage": "Pure bus, walk, taxi and night cab choreography; generic rendering contract, millisecond camera continuity, vehicle physics, profiles, open arrivals and deterministic paused player clocks. No visual or RunState execution.",
	}))
	quit(0 if _failures.is_empty() else 1)


func _check_api_and_compatibility() -> void:
	for mode in MODES:
		var state: Dictionary = Timeline.sample(0.0, mode)
		_expect(state.has_all(GENERIC_KEYS) and state["mode"] == mode, mode + "_has_complete_generic_contract")
		_expect(is_equal_approx(float(state["vehicle_road_y_uv"]), 0.95), mode + "_uses_integrated_road_inside_main_scene")
	_expect(Timeline.sample(4.7) == Timeline.sample(4.7, "bus", {}), "one_argument_bus_api_matches_explicit_defaults")
	_expect(Timeline.sample(4.7, "unsupported") == Timeline.sample(4.7), "unknown_modes_fall_back_to_bus")
	var aliases_match := true
	for step in range(1001):
		var state: Dictionary = Timeline.sample(float(step) / 100.0)
		for suffix in ["left_uv", "visible", "door_open", "wheel_angle", "body_bob", "speed_uv", "moving"]:
			aliases_match = aliases_match and state["vehicle_" + suffix] == state["bus_" + suffix]
		aliases_match = aliases_match and state["bar_door_open"] == state["destination_door_open"]
		aliases_match = aliases_match and int(state["walk_frame"]) == int(floor(float(state["player_animation_seconds"]) * 7.0)) % 4
	_expect(aliases_match, "bus_legacy_fields_and_walk_frames_match_generic_model")
	for mode in ["taxi", "night_cab"]:
		var state: Dictionary = Timeline.sample(1.80, mode)
		_expect(is_equal_approx(float(state["vehicle_width_uv"]), 0.32) and is_equal_approx(float(state["vehicle_left_uv"]), 0.37), mode + "_default_car_geometry")
		_expect(is_equal_approx(float(state["vehicle_wheel_radius_uv"]), 0.027) and is_equal_approx(float(state["vehicle_door_center_uv"]), 0.48), mode + "_default_wheel_and_door_geometry")
		_expect(Vector2(state["player_position_uv"]).is_equal_approx(Vector2(0.37 + 0.32 * 0.48, 0.90)), mode + "_exit_origin_matches_source_art_door")
		_expect(Vector2(Timeline.sample(2.50, mode)["player_position_uv"]).is_equal_approx(Vector2(0.56, 0.95)), mode + "_default_player_curb_is_0_56_0_95")
		_expect(not state["bus_visible"] and not state["bus_moving"], mode + "_does_not_fabricate_legacy_bus")


func _check_shared_clock_for_every_mode() -> void:
	for mode in MODES:
		var previous: Dictionary = Timeline.sample(0.0, mode)
		var cameras_advance := true
		var shared_curve := true
		var rate_preserved := true
		var no_overscan := true
		for step in range(1, 8001):
			var seconds := float(step) / 1000.0
			var state: Dictionary = Timeline.sample(seconds, mode)
			var main: float = state["camera_x_uv"]
			var far: float = state["background_camera_x_uv"]
			var main_delta := main - float(previous["camera_x_uv"])
			var far_delta := far - float(previous["background_camera_x_uv"])
			cameras_advance = cameras_advance and main_delta > 0.0 and far_delta > 0.0
			rate_preserved = rate_preserved and absf(far_delta - main_delta * 0.35) < 0.0000001 and absf(far - main * 0.35) < EPSILON
			var approach := 1.0 - pow(1.0 - minf(seconds / 1.45, 1.0), 3.0)
			shared_curve = shared_curve and absf(main - (0.0576 * approach + 0.1224 * seconds / 8.0)) < EPSILON and main == float(state["foreground_camera_x_uv"])
			no_overscan = no_overscan and main + 0.80 < 1.0 and far + 0.80 < 1.0
			previous = state
		_expect(no_overscan, mode + "_both_layers_stay_within_close_source_overscan")
		_expect(cameras_advance, mode + "_both_layers_advance_every_millisecond_including_all_pauses")
		_expect(rate_preserved, mode + "_backdrop_keeps_exact_0_35_main_camera_rate")
		_expect(shared_curve, mode + "_main_camera_matches_continuous_close_view_curve")
		_expect(is_equal_approx(float(previous["camera_x_uv"]), 0.18) and is_equal_approx(float(previous["background_camera_x_uv"]), 0.063), mode + "_cameras_end_at_expected_8_second_offsets")


func _check_vehicle_schedule() -> void:
	var beats := ["approach", "stop", "dropoff", "departure", "walk", "open_door", "enter", "close_door", "arrival"]
	for mode in VEHICLE_MODES:
		var walk_start := _expected_approach_start(mode)
		var boundaries := [0.0, 1.45, 1.80, 2.75, walk_start, 6.15, 6.65, 7.25, 7.90]
		var ordered_beats := true
		for index in range(boundaries.size()):
			ordered_beats = ordered_beats and Timeline.sample(boundaries[index], mode)["beat"] == beats[index]
			if index > 0:
				ordered_beats = ordered_beats and Timeline.sample(boundaries[index] - EPSILON, mode)["beat"] == beats[index - 1]
		_expect(ordered_beats, mode + "_shares_vehicle_walk_open_enter_close_arrival_schedule")
		var start: Dictionary = Timeline.sample(0.0, mode)
		var stopped: Dictionary = Timeline.sample(1.45, mode)
		var radius: float = stopped["vehicle_wheel_radius_uv"]
		var physical_wheels := true
		var stationary_stop := true
		var closed_during_motion := true
		var suspension_bounded := true
		var departure_accelerates := true
		var waiting_clock_pauses := true
		var last_speed := -1.0
		for step in range(1001):
			var seconds := float(step) / 100.0
			var state: Dictionary = Timeline.sample(seconds, mode)
			physical_wheels = physical_wheels and absf(float(state["vehicle_wheel_angle"]) * radius - (float(state["vehicle_left_uv"]) - float(start["vehicle_left_uv"]))) < EPSILON
			suspension_bounded = suspension_bounded and absf(float(state["vehicle_body_bob"])) <= 1.15
			if seconds >= 1.45 and seconds <= 2.75:
				stationary_stop = stationary_stop and state["vehicle_left_uv"] == stopped["vehicle_left_uv"] and state["vehicle_wheel_angle"] == stopped["vehicle_wheel_angle"] and float(state["vehicle_body_bob"]) == 0.0 and float(state["vehicle_speed_uv"]) == 0.0
			if state["vehicle_moving"]:
				closed_during_motion = closed_during_motion and is_zero_approx(float(state["vehicle_door_open"]))
			if seconds >= 2.50 and seconds < walk_start:
				waiting_clock_pauses = waiting_clock_pauses and state["player_motion_seconds"] == Timeline.sample(2.50, mode)["player_motion_seconds"] and not state["player_moving"]
			if seconds > 2.75 and seconds < 4.45:
				departure_accelerates = departure_accelerates and float(state["vehicle_speed_uv"]) > last_speed
				last_speed = state["vehicle_speed_uv"]
		_expect(physical_wheels, mode + "_wheels_use_distance_divided_by_physical_radius")
		_expect(stationary_stop and closed_during_motion, mode + "_vehicle_is_parked_while_open_and_closed_while_driving")
		_expect(suspension_bounded, mode + "_suspension_never_exceeds_0_45_pixels")
		_expect(departure_accelerates and is_equal_approx(Timeline.WALK_SECONDS - Timeline.BUS_DEPARTURE_SECONDS, 1.70), mode + "_departure_accelerates_over_full_1_7_seconds")
		_expect(waiting_clock_pauses, mode + "_player_clock_pauses_until_departing_rear_clears_curb")
		var crossing: Dictionary = Timeline.sample(walk_start, mode)
		var curb: Vector2 = crossing["player_curb_uv"]
		_expect(is_equal_approx(float(crossing["player_approach_start_seconds"]), walk_start) and is_equal_approx(float(crossing["vehicle_left_uv"]), curb.x + 0.02) and not Timeline.sample(walk_start - EPSILON, mode)["player_moving"] and crossing["player_moving"], mode + "_pedestrian_starts_at_independently_calculated_rear_clearance_instant")
		_expect(walk_start < 4.45 and crossing["vehicle_visible"] and crossing["vehicle_moving"], mode + "_pedestrian_starts_before_vehicle_finishes_departing")
		var stays_clear := true
		for step in range(101):
			var state: Dictionary = Timeline.sample(lerpf(walk_start, 4.45, float(step) / 100.0), mode)
			stays_clear = stays_clear and float(state["vehicle_left_uv"]) >= Vector2(state["player_position_uv"]).x + 0.02 - EPSILON
		_expect(stays_clear, mode + "_vehicle_rear_stays_clear_during_overlapping_pedestrian_approach")
		var leaving: Dictionary = Timeline.sample(4.45 - EPSILON, mode)
		_expect(leaving["vehicle_visible"] and float(leaving["vehicle_left_uv"]) - float(leaving["camera_x_uv"]) > 0.80 and not Timeline.sample(4.45, mode)["vehicle_visible"], mode + "_vehicle_exits_screen_before_visibility_turns_off")
		_expect(is_equal_approx(float(Timeline.sample(1.80, mode)["vehicle_door_open"]), 1.0) and is_equal_approx(float(Timeline.sample(2.50, mode)["vehicle_door_open"]), 1.0) and is_zero_approx(float(Timeline.sample(2.75, mode)["vehicle_door_open"])), mode + "_door_stays_open_for_dropoff_and_closes_before_departure")


func _check_continuous_walk() -> void:
	var previous: Dictionary = Timeline.sample(0.0, "walk")
	var never_stops := true
	var visible_motion := true
	var no_vehicle := true
	var seen_frames: Dictionary = {}
	for step in range(6150):
		var seconds := float(step) / 1000.0
		var state: Dictionary = Timeline.sample(seconds, "walk")
		var position: Vector2 = state["player_position_uv"]
		no_vehicle = no_vehicle and not state["vehicle_visible"] and not state["vehicle_moving"] and float(state["vehicle_wheel_angle"]) == 0.0 and float(state["vehicle_body_bob"]) == 0.0 and float(state["vehicle_door_open"]) == 0.0
		never_stops = never_stops and state["beat"] == "walk" and state["player_moving"] and is_equal_approx(float(state["player_motion_seconds"]), seconds)
		visible_motion = visible_motion and state["player_visible"] and float(state["player_alpha"]) == 1.0 and position.x - float(state["camera_x_uv"]) > 0.0 and position.x - float(state["camera_x_uv"]) < 0.80
		if step > 0:
			visible_motion = visible_motion and position.x > Vector2(previous["player_position_uv"]).x
		seen_frames[state["walk_frame"]] = true
		previous = state
	_expect(never_stops, "walk_has_no_fabricated_stop_and_its_pose_clock_advances_for_entire_transit")
	_expect(visible_motion and seen_frames.size() == 4, "walk_is_visible_and_advances_from_left_to_destination_with_all_four_poses")
	_expect(no_vehicle, "walk_contains_no_vehicle_motion_or_door_animation")
	_expect(Vector2(Timeline.sample(3.30, "walk")["player_position_uv"]).is_equal_approx(Vector2(Timeline.BAR_DOOR_UV.x - 0.12, 0.94)), "walk_reaches_threshold_relative_curb_at_3_3_seconds")
	_expect(Vector2(Timeline.sample(6.15, "walk")["player_position_uv"]).is_equal_approx(Timeline.BAR_DOOR_UV), "walk_reaches_destination_at_6_15_seconds")
	_expect(Timeline.sample(6.15, "walk")["beat"] == "open_door" and Timeline.sample(6.65, "walk")["beat"] == "enter" and Timeline.sample(7.25, "walk")["beat"] == "close_door" and Timeline.sample(7.90, "walk")["beat"] == "arrival", "walk_uses_standard_entry_and_arrival_timing")


func _check_profiles_and_open_arrivals() -> void:
	var anchor := Vector2(0.81, 0.78)
	var profile := {
		"vehicle_width_uv": 0.36,
		"vehicle_stop_left_uv": 0.35,
		"vehicle_door_center_uv": 0.6,
		"vehicle_wheel_radius_uv": 0.031,
		"vehicle_step_y_uv": 0.87,
		"player_curb_uv": Vector2(0.6, 0.9),
		"destination_anchor_uv": anchor,
		"entrance_kind": "open",
	}
	var original_profile: Dictionary = profile.duplicate(true)
	for mode in MODES:
		var dropoff: Dictionary = Timeline.sample(1.80, mode, profile)
		if mode != "walk":
			_expect(is_equal_approx(float(dropoff["vehicle_width_uv"]), 0.36) and is_equal_approx(float(dropoff["vehicle_left_uv"]), 0.35) and is_equal_approx(float(dropoff["vehicle_wheel_radius_uv"]), 0.031), mode + "_profile_controls_vehicle_size_stop_and_wheel_radius")
			_expect(Vector2(dropoff["player_position_uv"]).is_equal_approx(Vector2(0.35 + 0.36 * 0.6, 0.87)), mode + "_profile_exit_is_registered_to_vehicle_door_and_step")
			var start: Dictionary = Timeline.sample(0.0, mode, profile)
			var moving: Dictionary = Timeline.sample(4.7, mode, profile)
			_expect(absf(float(moving["vehicle_wheel_angle"]) * 0.031 - (float(moving["vehicle_left_uv"]) - float(start["vehicle_left_uv"]))) < EPSILON, mode + "_profile_wheels_use_actual_configured_radius")
		_expect(Vector2(Timeline.sample(_expected_approach_start(mode, profile), mode, profile)["player_position_uv"]).is_equal_approx(Vector2(0.6, 0.9)), mode + "_profile_controls_player_curb_anchor")
		for kind in ["open", "passage", "dock"]:
			var outdoor_profile := profile.duplicate(true)
			outdoor_profile["entrance_kind"] = kind
			var beyond := anchor + Vector2(0.04, -0.10)
			outdoor_profile["destination_inside_uv"] = beyond
			var walks_away := true
			var remains_visible := true
			var no_door := true
			var previous_distance := anchor.distance_to(beyond)
			var previous_scale := 1.0
			var previous_clock: float = Timeline.sample(6.15, mode, outdoor_profile)["player_motion_seconds"]
			for step in range(1001):
				var seconds := lerpf(6.15, 7.90, float(step) / 1000.0)
				var state: Dictionary = Timeline.sample(seconds, mode, outdoor_profile)
				var position: Vector2 = state["player_position_uv"]
				walks_away = walks_away and position.distance_to(beyond) <= previous_distance + EPSILON and state["player_facing_away"] and float(state["player_scale"]) <= previous_scale + EPSILON
				if step > 0: walks_away = walks_away and float(state["player_motion_seconds"]) > previous_clock
				remains_visible = remains_visible and state["player_visible"] and state["player_alpha"] == 1.0 and (state["player_moving"] if step < 1000 else not state["player_moving"])
				no_door = no_door and state["bar_door_open"] == 0.0 and state["destination_door_open"] == 0.0 and state["entrance_kind"] == kind and not state["player_in_entrance"]
				previous_distance = position.distance_to(beyond)
				previous_scale = state["player_scale"]
				previous_clock = state["player_motion_seconds"]
			_expect(walks_away and is_zero_approx(previous_distance) and is_equal_approx(previous_scale, 0.58), mode + "_" + kind + "_walks_beyond_threshold_facing_away_and_shrinks_to_0_58")
			_expect(remains_visible and no_door, mode + "_" + kind + "_never_fades_or_fabricates_an_indoor_door")
			for seconds in [7.90, 7.95, 8.0]:
				var arrived: Dictionary = Timeline.sample(seconds, mode, outdoor_profile)
				_expect(arrived["beat"] == "arrival" and arrived["player_visible"] and arrived["player_facing_away"] and Vector2(arrived["player_position_uv"]).is_equal_approx(beyond) and arrived["player_motion_seconds"] == previous_clock and not arrived["player_moving"], mode + "_" + kind + "_holds_visible_distant_arrival_" + str(seconds))
		var indoor_profile := profile.duplicate(true)
		indoor_profile["entrance_kind"] = "door"
		var inside := anchor + Vector2(0.015, -0.065)
		indoor_profile["destination_inside_uv"] = inside
		var reaches_threshold: Dictionary = Timeline.sample(6.15, mode, indoor_profile)
		var begins_entry: Dictionary = Timeline.sample(6.65, mode, indoor_profile)
		var reaches_inside: Dictionary = Timeline.sample(7.25, mode, indoor_profile)
		_expect(Vector2(reaches_threshold["player_position_uv"]).is_equal_approx(anchor) and reaches_threshold["destination_door_open"] == 0.0 and reaches_threshold["player_motion_seconds"] == begins_entry["player_motion_seconds"], mode + "_waits_at_measured_threshold_with_paused_pose_while_door_opens")
		_expect(begins_entry["destination_door_open"] == 1.0 and reaches_inside["destination_door_open"] == 1.0 and Vector2(reaches_inside["player_position_uv"]).is_equal_approx(inside), mode + "_crosses_actual_threshold_only_after_door_is_fully_open")
		var last_position := anchor
		var last_clock: float = begins_entry["player_motion_seconds"]
		var visible_entry := true
		for step in range(1, 101):
			var state: Dictionary = Timeline.sample(lerpf(6.65, 7.25, float(step) / 100.0), mode, indoor_profile)
			var position: Vector2 = state["player_position_uv"]
			visible_entry = visible_entry and position.distance_to(inside) < last_position.distance_to(inside) and state["player_visible"] and state["player_alpha"] == 1.0 and state["destination_door_open"] == 1.0 and float(state["player_motion_seconds"]) > last_clock
			last_position = position
			last_clock = state["player_motion_seconds"]
		_expect(visible_entry, mode + "_entry_walk_advances_visibly_into_interior_without_fading")
		var before_close: Dictionary = Timeline.sample(7.90 - EPSILON, mode, indoor_profile)
		var after_close: Dictionary = Timeline.sample(7.90, mode, indoor_profile)
		_expect(before_close["player_visible"] and not after_close["player_visible"] and after_close["player_alpha"] == 1.0 and after_close["destination_door_open"] == 0.0 and after_close["player_motion_seconds"] == reaches_inside["player_motion_seconds"], mode + "_closed_door_covers_actor_before_visibility_retires")
	_expect(profile == original_profile, "sampling_never_mutates_caller_profile")
	var invalid := {"vehicle_width_uv": NAN, "vehicle_stop_left_uv": INF, "vehicle_door_center_uv": "bad", "vehicle_wheel_radius_uv": 0.0, "destination_anchor_uv": Vector2(NAN, INF)}
	_expect(Timeline.sample(4.7, "taxi", invalid) == Timeline.sample(4.7, "taxi"), "malformed_nonfinite_or_zero_radius_profile_values_use_safe_defaults")
	_expect(Timeline.sample(8.0, "taxi", {"entrance_kind":"invalid"}) == Timeline.sample(8.0, "taxi", {"entrance_kind":"open"}), "unknown_entrance_kind_uses_safe_visible_open_arrival")


func _check_profile_camera_rates() -> void:
	for camera_end in [0.01, 0.04, 0.10, 0.18, 0.22]:
		var profile := {"camera_end_uv":camera_end}
		var source_width := 1.0 - float(camera_end) - 0.01
		var previous: Dictionary = Timeline.sample(0.0, "walk", profile)
		var advances := true
		var exact_curve := true
		var inside_source := true
		for step in range(1, 8001):
			var seconds := float(step) / 1000.0
			var state: Dictionary = Timeline.sample(seconds, "walk", profile)
			var main: float = state["camera_x_uv"]
			var far: float = state["background_camera_x_uv"]
			advances = advances and main > float(previous["camera_x_uv"]) and far > float(previous["background_camera_x_uv"])
			var approach := 1.0 - pow(1.0 - minf(seconds / 1.45, 1.0), 3.0)
			var initial := minf(0.07, float(camera_end) * 0.32)
			exact_curve = exact_curve and absf(main - (initial * approach + (float(camera_end) - initial) * seconds / 8.0)) < EPSILON and absf(far - main * 0.35) < EPSILON
			inside_source = inside_source and main + source_width < 1.0 and far + source_width < 1.0
			previous = state
		_expect(advances and exact_curve and inside_source and is_equal_approx(float(previous["camera_x_uv"]), float(camera_end)), "profile_camera_%s_preserves_shared_main_and_far_motion" % camera_end)


func _check_approach_waypoint() -> void:
	# The authored House bend follows its driveway before turning toward the
	# threshold. Timeline unit coverage keeps this fixture independent of art IO.
	var threshold := Vector2(0.75253664, 0.88500564)
	var curb := Vector2(threshold.x - 0.12, 0.94363021)
	var waypoint := Vector2(0.70, 0.94363021)
	var profile := {"player_curb_uv":curb, "destination_anchor_uv":threshold, "approach_waypoint_uv":waypoint}
	var frozen := var_to_bytes(profile)
	var direct := profile.duplicate(true)
	direct.erase("approach_waypoint_uv")
	var first_length := curb.distance_to(waypoint)
	var second_length := waypoint.distance_to(threshold)
	var total_length := first_length + second_length
	for mode in MODES:
		var walk_start := _expected_approach_start(mode, profile)
		var duration := 6.15 - walk_start
		var turn_time := walk_start + duration * first_length / total_length
		var expected_speed := total_length / duration
		var at_turn: Dictionary = Timeline.sample(turn_time, mode, profile)
		_expect(Vector2(at_turn["player_position_uv"]).is_equal_approx(waypoint) and at_turn["player_moving"] and at_turn["beat"] == "walk", mode + "_authored_waypoint_reached_at_its_normalized_arc_length_time")
		var before_turn: Vector2 = Timeline.sample(turn_time - 0.01, mode, profile)["player_position_uv"]
		var after_turn: Vector2 = Timeline.sample(turn_time + 0.01, mode, profile)["player_position_uv"]
		_expect(absf(before_turn.distance_to(waypoint) / 0.01 - expected_speed) < EPSILON and absf(after_turn.distance_to(waypoint) / 0.01 - expected_speed) < EPSILON, mode + "_walking_speed_matches_on_both_sides_of_waypoint")
		var just_before: Vector2 = Timeline.sample(turn_time - EPSILON, mode, profile)["player_position_uv"]
		var just_after: Vector2 = Timeline.sample(turn_time + EPSILON, mode, profile)["player_position_uv"]
		_expect(just_before.distance_to(waypoint) < EPSILON and just_after.distance_to(waypoint) < EPSILON, mode + "_waypoint_join_has_no_position_jump")
		var follows_segments := true
		var constant_speed := true
		var visible_movement := true
		var snapshots: Array[Dictionary] = []
		var previous_position := curb
		var previous_seconds := walk_start
		seed(45291)
		var expected_random := randi()
		seed(45291)
		for step in range(1001):
			var progress := float(step) / 1000.0
			var seconds := walk_start + duration * progress
			var state: Dictionary = Timeline.sample(seconds, mode, profile)
			var position: Vector2 = state["player_position_uv"]
			var first_segment := seconds <= turn_time
			var segment_start := curb if first_segment else waypoint
			var segment_end := waypoint if first_segment else threshold
			var arc_distance := curb.distance_to(position) if first_segment else first_length + waypoint.distance_to(position)
			follows_segments = follows_segments and position.is_finite() and Geometry2D.get_closest_point_to_segment(position, segment_start, segment_end).distance_to(position) < EPSILON and absf(arc_distance - total_length * progress) < EPSILON
			# A single chord crossing the corner is shorter than the two-segment
			# path, so compare displacement only within each straight segment.
			if step > 0 and not (previous_seconds < turn_time and seconds > turn_time):
				constant_speed = constant_speed and absf(position.distance_to(previous_position) - expected_speed * (seconds - previous_seconds)) < EPSILON * 0.02
			visible_movement = visible_movement and state["player_visible"] and state["player_alpha"] == 1.0 and (state["player_moving"] if step < 1000 else not state["player_moving"])
			snapshots.append(state.duplicate(true))
			previous_position = position
			previous_seconds = seconds
		var deterministic := true
		for step in range(1000, -1, -1):
			deterministic = deterministic and Timeline.sample(walk_start + duration * (float(step) / 1000.0), mode, profile) == snapshots[step]
		_expect(follows_segments and constant_speed, mode + "_dense_waypoint_path_stays_on_authored_segments_at_constant_arc_speed")
		_expect(visible_movement, mode + "_waypoint_turn_never_hides_or_pauses_traveler")
		var detached: Dictionary = Timeline.sample(walk_start + duration * 0.5, mode, profile)
		detached["player_position_uv"] = Vector2(-999.0, -999.0)
		var detached_output: bool = Timeline.sample(walk_start + duration * 0.5, mode, profile) == snapshots[500]
		_expect(deterministic and detached_output and randi() == expected_random and var_to_bytes(profile) == frozen, mode + "_waypoint_sampling_is_pure_detached_deterministic_and_rng_free")
		var end: Dictionary = Timeline.sample(Timeline.DOOR_REACH_SECONDS, mode, profile)
		_expect(Vector2(end["player_position_uv"]).is_equal_approx(threshold) and end["destination_anchor_uv"] == threshold and end["beat"] == "open_door" and end["destination_door_open"] == 0.0, mode + "_waypoint_preserves_exact_final_threshold_and_door_timing")
		var later_unchanged := true
		for seconds in [7.10, 6.65, 6.95, 7.25, 7.90, 8.0]:
			var with_bend: Dictionary = Timeline.sample(seconds, mode, profile)
			var straight: Dictionary = Timeline.sample(seconds, mode, direct)
			# Path-length progress legitimately changes with the longer bend.
			with_bend.erase("arrival_progress")
			straight.erase("arrival_progress")
			later_unchanged = later_unchanged and with_bend == straight
		_expect(later_unchanged, mode + "_waypoint_does_not_change_entry_closure_or_arrival")
		for invalid in [null, "malformed", 0.7, [], [0.70, 0.94363021], {}, Vector2(NAN, 0.9), Vector2(0.7, INF)]:
			var malformed := direct.duplicate(true)
			malformed["approach_waypoint_uv"] = invalid
			var malformed_frozen := var_to_bytes(malformed)
			var safe_fallback := true
			for seconds in [4.8, 5.15, 5.8, turn_time, 6.15, 6.95, 8.0]:
				safe_fallback = safe_fallback and Timeline.sample(seconds, mode, malformed) == Timeline.sample(seconds, mode, direct)
			_expect(safe_fallback and var_to_bytes(malformed) == malformed_frozen, mode + "_invalid_waypoint_uses_immutable_direct_approach_" + str(invalid))
		for endpoint in [curb, threshold]:
			var degenerate := direct.duplicate(true)
			degenerate["approach_waypoint_uv"] = endpoint
			var direct_path := true
			for seconds in [4.8, 5.15, 5.8, 6.15]:
				direct_path = direct_path and Vector2(Timeline.sample(seconds, mode, degenerate)["player_position_uv"]).is_equal_approx(Timeline.sample(seconds, mode, direct)["player_position_uv"])
			_expect(direct_path, mode + "_zero_length_waypoint_segment_preserves_direct_path_" + str(endpoint))
		var stationary := {"player_curb_uv":threshold, "destination_anchor_uv":threshold, "approach_waypoint_uv":threshold}
		_expect(Vector2(Timeline.sample(5.8, mode, stationary)["player_position_uv"]).is_equal_approx(threshold), mode + "_zero_length_entire_approach_remains_finite")


func _check_uniform_actor_scale() -> void:
	# Stepping down changes foot position, never the canonical adult's height.
	# Only an outdoor walk-away intentionally recedes into the distance.
	var profile := {"vehicle_width_uv":0.4, "vehicle_stop_left_uv":0.3,
		"vehicle_door_center_uv":0.65, "vehicle_step_y_uv":0.86,
		"player_curb_uv":Vector2(0.6, 0.94), "destination_anchor_uv":Vector2(0.8, 0.78),
		"destination_inside_uv":Vector2(0.8, 0.71)}
	for mode in MODES:
		for kind in ["door", "open", "passage", "dock"]:
			var motion := profile.duplicate(true)
			motion["entrance_kind"] = kind
			var frozen := var_to_bytes(motion)
			var walk_start := _expected_approach_start(mode, motion)
			var follows_scale := true
			var descends_on_exit := true
			var same_height_on_approach := true
			var last_y := 0.86
			for step in range(10001):
				var seconds := float(step) / 1000.0
				var state: Dictionary = Timeline.sample(seconds, mode, motion)
				var exit_fraction := _smooth_fraction(_unit_interval(seconds, 1.80, 2.50))
				var entry_fraction := _smooth_fraction(_unit_interval(seconds, 6.65 if kind == "door" else 6.15, 7.25 if kind == "door" else 7.90))
				var expected := 1.0 if kind == "door" else 1.0 - 0.42 * entry_fraction
				var scale: float = state["player_scale"]
				follows_scale = follows_scale and is_finite(scale) and absf(scale - expected) < EPSILON and scale >= 0.58 - EPSILON and scale <= 1.0
				if mode != "walk" and seconds >= 1.80 and seconds <= 2.50:
					var foot: Vector2 = state["player_position_uv"]
					descends_on_exit = descends_on_exit and foot.y >= last_y - EPSILON and absf(foot.y - (0.86 + 0.08 * exit_fraction)) < EPSILON and is_equal_approx(scale, 1.0)
					last_y = foot.y
				if mode != "walk" and seconds > walk_start and seconds <= 6.15:
					same_height_on_approach = same_height_on_approach and is_equal_approx(scale, 1.0)
			_expect(follows_scale, mode + "_" + kind + "_dense_scale_is_constant_except_authored_outdoor_walkaway")
			if mode != "walk":
				_expect(descends_on_exit and is_equal_approx(last_y, 0.94), mode + "_" + kind + "_feet_step_down_to_authored_road_without_actor_growth")
				_expect(same_height_on_approach, mode + "_" + kind + "_approach_keeps_the_same_actor_height")
				_expect(is_equal_approx(float(Timeline.sample(1.80, mode, motion)["player_scale"]), 1.0) and is_equal_approx(float(Timeline.sample(2.50, mode, motion)["player_scale"]), 1.0) and is_equal_approx(float(Timeline.sample(walk_start, mode, motion)["player_scale"]), 1.0) and is_equal_approx(float(Timeline.sample(6.15, mode, motion)["player_scale"]), 1.0), mode + "_" + kind + "_exit_lane_and_threshold_have_identical_scale")
			else:
				_expect(Timeline.sample(0.0, mode, motion)["player_scale"] == 1.0 and Timeline.sample(3.30, mode, motion)["player_scale"] == 1.0 and Timeline.sample(6.15, mode, motion)["player_scale"] == 1.0, "walk_" + kind + "_never_inherits_vehicle_perspective_growth")
			var continuous := true
			for boundary in [1.80, 2.50, walk_start, 6.15, 6.65, 7.25, 7.90]:
				var before: Dictionary = Timeline.sample(boundary - EPSILON, mode, motion)
				var after: Dictionary = Timeline.sample(boundary + EPSILON, mode, motion)
				continuous = continuous and absf(float(before["player_scale"]) - float(after["player_scale"])) < 0.0001 and Vector2(before["player_position_uv"]).distance_to(after["player_position_uv"]) < 0.0001
			_expect(continuous and var_to_bytes(motion) == frozen, mode + "_" + kind + "_scale_boundaries_are_continuous_and_profile_immutable")


func _expected_approach_start(mode: String, profile: Dictionary = {}) -> float:
	if mode == "walk": return 3.30
	var curb: Vector2 = profile.get("player_curb_uv", Vector2(0.67, 0.95) if mode == "bus" else Vector2(0.56, 0.95))
	var stop := float(profile.get("vehicle_stop_left_uv", 0.28 if mode == "bus" else 0.37))
	var width := float(profile.get("vehicle_width_uv", 0.42 if mode == "bus" else 0.32))
	var door := float(profile.get("vehicle_door_center_uv", 0.8828 if mode == "bus" else 0.48))
	var distance := 0.82 if mode == "bus" and stop == 0.28 and width == 0.42 and door == 0.8828 else maxf(1.10 - stop, 0.1)
	# Independently invert quadratic rear travel from its parked left edge.
	return 2.75 + sqrt(clampf((curb.x + 0.02 - stop) / distance, 0.0, 1.0)) * (4.45 - 2.75)


func _unit_interval(seconds: float, begin: float, end: float) -> float:
	return clampf((seconds - begin) / (end - begin), 0.0, 1.0)


func _smooth_fraction(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)


func _check_arrival_progress() -> void:
	var curb := Vector2(0.61, 1.04)
	var threshold := Vector2(0.80, 0.78)
	var waypoint := Vector2(0.71, 0.99)
	var inside := Vector2(0.80, 0.70)
	var profile := {"vehicle_width_uv":0.36, "vehicle_stop_left_uv":0.33,
		"vehicle_door_center_uv":0.6, "vehicle_step_y_uv":1.12,
		"player_curb_uv":curb, "destination_anchor_uv":threshold,
		"destination_inside_uv":inside, "approach_waypoint_uv":waypoint}
	for mode in MODES:
		var walk_start := _expected_approach_start(mode, profile)
		if mode != "walk":
			var start: Dictionary = Timeline.sample(walk_start, mode, profile)
			_expect(is_equal_approx(float(start["vehicle_left_uv"]), curb.x + 0.02) and start["player_moving"] and not Timeline.sample(walk_start - EPSILON, mode, profile)["player_moving"] and walk_start < 4.45, mode + "_custom_profile_uses_its_own_rear_clearance_not_default_timing")
		var first_origin := Vector2(0.06, curb.y) if mode == "walk" else Vector2(0.33 + 0.36 * 0.6, 1.12)
		var first_distance := first_origin.distance_to(curb)
		var approach_distance := curb.distance_to(waypoint) + waypoint.distance_to(threshold)
		var inside_distance := threshold.distance_to(inside)
		var transport_distance := 0.0 if mode == "walk" else 0.33 - (-0.36 - 0.08)
		var whole_distance := transport_distance + first_distance + approach_distance + inside_distance
		for kind in ["door", "open", "passage", "dock"]:
			var motion := profile.duplicate(true)
			motion["entrance_kind"] = kind
			var previous := -EPSILON
			var monotone := true
			var distance_based := true
			var completion_gated := true
			for step in range(1001):
				var seconds := float(step) / 100.0
				var state: Dictionary = Timeline.sample(seconds, mode, motion)
				var first_fraction := _unit_interval(seconds, 0.0, 3.30) if mode == "walk" else _smooth_fraction(_unit_interval(seconds, 1.80, 2.50))
				var approach_fraction := _unit_interval(seconds, walk_start, 6.15)
				var final_fraction := _smooth_fraction(_unit_interval(seconds, 6.65, 7.25)) if kind == "door" else _smooth_fraction(_unit_interval(seconds, 6.15, 7.90))
				var vehicle_approach := 1.0 - pow(1.0 - _unit_interval(seconds, 0.0, 1.45), 3.0)
				var expected := (transport_distance * vehicle_approach + first_distance * first_fraction + approach_distance * approach_fraction + inside_distance * final_fraction) / whole_distance
				if kind == "door": expected = expected * 0.98 + 0.02 * _smooth_fraction(_unit_interval(seconds, 7.25, 7.90))
				var progress: float = state["arrival_progress"]
				monotone = monotone and is_finite(progress) and progress >= 0.0 and progress <= 1.0 and progress >= previous
				distance_based = distance_based and absf(progress - expected) < EPSILON
				completion_gated = completion_gated and (progress < 1.0 if seconds < 7.90 else is_equal_approx(progress, 1.0))
				previous = progress
			_expect(monotone and distance_based, mode + "_" + kind + "_progress_monotonically_tracks_actual_authored_path_distance_not_elapsed_time")
			_expect(completion_gated, mode + "_" + kind + "_progress_reaches_one_only_after_complete_arrival_then_holds")
			_expect(not is_equal_approx(float(Timeline.sample(3.5, mode, motion)["arrival_progress"]), 0.35), mode + "_" + kind + "_progress_is_not_a_linear_eight_second_timer")
			if mode != "walk":
				_expect(float(Timeline.sample(1.0, mode, motion)["arrival_progress"]) > 0.0 and Timeline.sample(1.45, mode, motion)["arrival_progress"] == Timeline.sample(1.80, mode, motion)["arrival_progress"], mode + "_" + kind + "_progress_tracks_vehicle_approach_then_pauses_during_vehicle_door_opening")
				_expect(Timeline.sample(2.50, mode, motion)["arrival_progress"] == Timeline.sample(walk_start, mode, motion)["arrival_progress"], mode + "_" + kind + "_progress_pauses_while_waiting_for_vehicle_clearance")
			if kind == "door":
				_expect(Timeline.sample(6.15, mode, motion)["arrival_progress"] == Timeline.sample(6.65, mode, motion)["arrival_progress"], mode + "_door_progress_pauses_during_door_opening")
				var entered: Dictionary = Timeline.sample(7.25, mode, motion)
				var closing: Dictionary = Timeline.sample(7.575, mode, motion)
				var before_closed: Dictionary = Timeline.sample(7.90 - EPSILON, mode, motion)
				_expect(is_equal_approx(float(entered["arrival_progress"]), 0.98) and float(closing["arrival_progress"]) > float(entered["arrival_progress"]) and float(before_closed["arrival_progress"]) < 1.0 and closing["destination_door_open"] > 0.0, mode + "_last_two_percent_advances_with_closing_leaf_not_paused_player")


func _check_purity_and_boundaries() -> void:
	for mode in MODES:
		_expect(Timeline.sample(-INF, mode) == Timeline.sample(0.0, mode) and Timeline.sample(NAN, mode) == Timeline.sample(0.0, mode), mode + "_negative_and_nan_clocks_resolve_to_start")
		_expect(Timeline.sample(INF, mode) == Timeline.sample(8.0, mode) and Timeline.sample(13.0, mode) == Timeline.sample(8.0, mode), mode + "_late_clocks_resolve_to_arrival_endpoint")
		var continuity := true
		for seconds in [1.45, 1.80, 2.50, 2.75, _expected_approach_start(mode), 4.45, 6.15, 6.65, 7.25, 7.90, 8.0]:
			var before: Dictionary = Timeline.sample(seconds - EPSILON, mode)
			var after: Dictionary = Timeline.sample(seconds + EPSILON, mode)
			for key in ["background_camera_x_uv", "foreground_camera_x_uv", "vehicle_left_uv", "vehicle_wheel_angle", "vehicle_body_bob", "vehicle_door_open", "player_alpha", "player_scale", "player_motion_seconds", "player_animation_seconds", "player_walk_phase", "destination_door_open", "arrival_progress"]:
				continuity = continuity and absf(float(after[key]) - float(before[key])) < 0.001
			continuity = continuity and Vector2(before["player_position_uv"]).distance_to(after["player_position_uv"]) < 0.001
		_expect(continuity, mode + "_position_wheels_camera_doors_and_pose_clock_are_continuous_at_all_boundaries")
		seed(78192)
		var expected_random := randi()
		seed(78192)
		var snapshots: Array[Dictionary] = []
		var finite := true
		var deterministic := true
		for step in range(1001):
			var state: Dictionary = Timeline.sample(float(step) / 100.0, mode)
			snapshots.append(state.duplicate(true))
			for key in state:
				var value: Variant = state[key]
				if value is float:
					finite = finite and is_finite(value)
				elif value is Vector2:
					finite = finite and is_finite(value.x) and is_finite(value.y)
		for step in range(1000, -1, -1):
			deterministic = deterministic and Timeline.sample(float(step) / 100.0, mode) == snapshots[step]
		_expect(randi() == expected_random, mode + "_timeline_does_not_consume_global_rng")
		_expect(finite and deterministic, mode + "_all_numeric_outputs_are_finite_and_call_order_independent")
		var detached: Dictionary = Timeline.sample(4.7, mode)
		detached["player_position_uv"] = Vector2(-999.0, -999.0)
		detached["destination_anchor_uv"] = Vector2(-999.0, -999.0)
		_expect(Timeline.sample(4.7, mode) == snapshots[470], mode + "_returned_state_is_detached")


func _expect(ok: bool, label: String) -> void:
	_checks.append(label)
	if not ok:
		_failures.append(label)
