extends SceneTree

const Timeline = preload("res://scripts/ui/travel_arrival_timeline.gd")
const EPSILON := 0.00001
const PHASES := ["bus_approach", "bus_stop", "dropoff", "bus_departure", "approach_door", "destination_open", "enter_bar", "destination_close", "arrival"]
const SOURCE_WIDTH_UV := 0.80

var _checks: Array[String] = []
var _failures: Array[String] = []


func _initialize() -> void:
	_check_contract_and_clamping()
	_check_phase_order_and_continuity()
	_check_shared_camera_contract()
	_check_bus_and_dropoff()
	_check_driving_animation()
	_check_walk_and_entry()
	_check_finite_deterministic_samples()
	print("TRAVEL_ARRIVAL_TIMELINE_CHECK " + JSON.stringify({
		"passed": _failures.is_empty(),
		"check_count": _checks.size(),
		"checks": _checks,
		"failures": _failures,
		"coverage": "Pure normalized timeline, simultaneous fixed-rate layer motion and distance-driven bus animation; actual overlay draws are checked separately.",
	}))
	quit(0 if _failures.is_empty() else 1)


func _check_contract_and_clamping() -> void:
	_expect(is_equal_approx(Timeline.DURATION_SECONDS, 8.0), "duration_is_8_seconds")
	_expect(is_equal_approx(float(Timeline.sample(8.0)["camera_x_uv"]), 0.18), "main_camera_end_is_0_18")
	_expect(is_equal_approx(float(Timeline.sample(8.0)["background_camera_x_uv"]), 0.063), "distant_camera_moves_at_0_35_main_rate")
	_expect(is_equal_approx(Timeline.BUS_STOP_LEFT_UV, 0.28), "bus_stop_left_is_0_28")
	_expect(is_equal_approx(Timeline.BUS_WIDTH_UV, 0.42), "bus_width_is_0_42")
	_expect(is_equal_approx(Timeline.BUS_ROAD_Y_UV, 0.95), "vehicle_baseline_is_inside_main_scene_0_95")
	_expect(Timeline.BAR_DOOR_UV.is_equal_approx(Vector2(0.758, 0.765)), "door_uses_art_coordinate")
	_expect(is_equal_approx(Timeline.BUS_WHEEL_RADIUS_UV, 0.42 * 86.0 / 1749.0), "wheel_radius_uses_actual_sprite_geometry")
	for seconds in [-1000000.0, -1.0, -EPSILON, -INF]:
		_expect(Timeline.sample(seconds) == Timeline.sample(0.0), "negative_time_clamped_%s" % seconds)
	for seconds in [8.0 + EPSILON, 13.0, 1000000.0, INF]:
		_expect(Timeline.sample(seconds) == Timeline.sample(8.0), "late_time_clamped_%s" % seconds)
	_expect(Timeline.sample(NAN) == Timeline.sample(0.0), "nan_time_resolves_to_finite_start")
	var original: Dictionary = Timeline.sample(4.7)
	var exposed: Dictionary = Timeline.sample(4.7)
	exposed["camera_x_uv"] = 999.0
	exposed["player_position_uv"] = Vector2(-999.0, -999.0)
	exposed["bus_wheel_angle"] = -999.0
	exposed["unexpected"] = true
	_expect(Timeline.sample(4.7) == original, "returned_dictionary_is_detached")


func _check_phase_order_and_continuity() -> void:
	var boundaries := [0.0, 1.45, 1.80, 2.75, _approach_start(), 6.15, 6.65, 7.25, 7.90]
	for index in range(boundaries.size()):
		var seconds: float = boundaries[index]
		_expect(Timeline.sample(seconds)["phase"] == PHASES[index], "phase_begins_%s" % PHASES[index])
		if index > 0:
			_expect(Timeline.sample(seconds - EPSILON)["phase"] == PHASES[index - 1], "previous_phase_ends_before_%s" % PHASES[index])
	var phase_ordered := true
	var previous_phase := -1
	for step in range(1001):
		var index: int = PHASES.find(Timeline.sample(float(step) / 100.0)["phase"])
		phase_ordered = phase_ordered and index >= previous_phase and index >= 0
		previous_phase = index
	_expect(phase_ordered and previous_phase == PHASES.size() - 1, "dense_samples_visit_phases_in_order")
	var continuous := true
	for seconds in [1.45, 1.80, 2.50, 2.75, _approach_start(), 4.45, 6.15, 6.65, 7.25, 7.90, 8.0]:
		var before: Dictionary = Timeline.sample(seconds - EPSILON)
		var after: Dictionary = Timeline.sample(seconds + EPSILON)
		for key in ["camera_x_uv", "background_camera_x_uv", "foreground_camera_x_uv", "bus_left_uv", "bus_wheel_angle", "bus_body_bob", "bus_door_open", "player_alpha", "player_scale", "player_motion_seconds", "player_walk_phase", "bar_door_open", "arrival_progress"]:
			continuous = continuous and absf(float(before[key]) - float(after[key])) < 0.001
		continuous = continuous and Vector2(before["player_position_uv"]).distance_to(after["player_position_uv"]) < 0.001
	_expect(continuous, "spatial_animation_and_door_values_continuous_at_boundaries")


func _check_shared_camera_contract() -> void:
	var start: Dictionary = Timeline.sample(0.0)
	_expect(is_zero_approx(float(start["camera_x_uv"])) and is_zero_approx(float(start["background_camera_x_uv"])), "both_cameras_start_at_origin")
	var both_advancing := true
	var rates_shared := true
	var no_overscan_clamp := true
	var aliases := true
	var expected_master := true
	var previous: Dictionary = start
	for step in range(1, 8001):
		var seconds := float(step) / 1000.0
		var state: Dictionary = Timeline.sample(seconds)
		var main: float = state["camera_x_uv"]
		var far: float = state["background_camera_x_uv"]
		var main_delta := main - float(previous["camera_x_uv"])
		var far_delta := far - float(previous["background_camera_x_uv"])
		both_advancing = both_advancing and main_delta > 0.0 and far_delta > 0.0
		rates_shared = rates_shared and absf(far_delta - 0.35 * main_delta) < 0.0000001 and absf(far - 0.35 * main) < EPSILON
		no_overscan_clamp = no_overscan_clamp and main + SOURCE_WIDTH_UV < 1.0 and far + SOURCE_WIDTH_UV < 1.0
		aliases = aliases and float(state["foreground_camera_x_uv"]) == main
		var approach := 1.0 - pow(1.0 - minf(seconds / 1.45, 1.0), 3.0)
		expected_master = expected_master and absf(main - (0.0576 * approach + 0.1224 * seconds / 8.0)) < EPSILON
		previous = state
	_expect(both_advancing, "main_and_distant_layers_advance_in_every_millisecond_including_pauses")
	_expect(rates_shared, "distant_backdrop_keeps_fixed_0_35_rate_of_main_scene")
	_expect(no_overscan_clamp, "both_layers_stay_inside_source_without_independent_clamps")
	_expect(aliases, "legacy_foreground_alias_is_main_scene_camera")
	_expect(expected_master, "main_camera_matches_continuous_0_18_master_curve")
	_expect(is_equal_approx(float(previous["camera_x_uv"]), 0.18) and is_equal_approx(float(previous["background_camera_x_uv"]), 0.063), "cameras_end_at_reviewed_main_and_backdrop_offsets")
	_expect(float(Timeline.sample(8.0)["camera_x_uv"]) > float(Timeline.sample(7.90)["camera_x_uv"]), "main_camera_drift_continues_through_arrival_hold")


func _check_bus_and_dropoff() -> void:
	_expect(not Timeline.sample(1.80 - EPSILON)["player_visible"], "player_hidden_before_dropoff")
	_expect(Timeline.sample(1.80)["player_visible"] and is_equal_approx(float(Timeline.sample(1.80)["player_alpha"]), 1.0), "player_exits_open_vehicle_door_without_alpha_fade")
	var bus_stopped := true
	var door_open_while_exiting := true
	var player_on_bus_front := true
	for step in range(131):
		var state: Dictionary = Timeline.sample(1.45 + float(step) / 100.0)
		bus_stopped = bus_stopped and state["bus_visible"] and is_equal_approx(float(state["bus_left_uv"]), Timeline.BUS_STOP_LEFT_UV)
	for step in range(71):
		var state: Dictionary = Timeline.sample(1.80 + float(step) / 100.0)
		door_open_while_exiting = door_open_while_exiting and is_equal_approx(float(state["bus_door_open"]), 1.0)
		var player: Vector2 = state["player_position_uv"]
		var bus_front_fraction: float = (player.x - float(state["bus_left_uv"])) / Timeline.BUS_WIDTH_UV
		player_on_bus_front = player_on_bus_front and bus_front_fraction >= 0.75 and bus_front_fraction <= 0.95
	_expect(bus_stopped, "bus_stationary_for_stop_open_dropoff_and_door_close")
	_expect(door_open_while_exiting, "bus_door_stays_fully_open_during_exit_motion")
	_expect(player_on_bus_front, "player_exits_at_front_door_inside_bus_footprint")
	var start: Vector2 = Timeline.sample(1.80)["player_position_uv"]
	var curb: Vector2 = Timeline.sample(2.50)["player_position_uv"]
	var bus_door_center_x := Timeline.BUS_STOP_LEFT_UV + Timeline.BUS_WIDTH_UV * 0.8828
	_expect(absf(start.x - bus_door_center_x) <= 0.00005, "exit_start_matches_generated_bus_door_center")
	_expect(is_equal_approx(start.y, 0.90), "exit_start_matches_bus_step_height")
	_expect(curb.is_equal_approx(Vector2(0.67, 0.95)) and start.distance_to(curb) > 0.01, "dropoff_moves_player_from_bus_step_to_curb")
	_expect(is_equal_approx(float(Timeline.sample(1.94)["player_alpha"]), 1.0), "player_stays_opaque_during_exit")
	_expect(is_zero_approx(float(Timeline.sample(2.75)["bus_door_open"])), "bus_door_closed_before_departure")
	var departing_forward := true
	var player_waits_at_curb := true
	var no_bus_teleport := true
	var previous_left := Timeline.BUS_STOP_LEFT_UV
	for step in range(171):
		var state: Dictionary = Timeline.sample(2.75 + float(step) / 100.0)
		var left: float = state["bus_left_uv"]
		departing_forward = departing_forward and left + EPSILON >= previous_left
		no_bus_teleport = no_bus_teleport and left - previous_left <= 2.0 * 0.82 / (4.45 - 2.75) * 0.01 + EPSILON
		if float(state["seconds"]) <= _approach_start():
			player_waits_at_curb = player_waits_at_curb and Vector2(state["player_position_uv"]).is_equal_approx(curb) and state["player_visible"] and is_equal_approx(float(state["player_alpha"]), 1.0)
		previous_left = left
	_expect(departing_forward and is_equal_approx(previous_left, 1.10), "departing_bus_moves_forward_to_world_left_1_10")
	_expect(no_bus_teleport, "departure_has_no_position_snap_in_dense_samples")
	_expect(player_waits_at_curb, "player_waits_at_curb_until_bus_rear_clears_safe_crossing")
	_expect(is_equal_approx(Timeline.WALK_SECONDS - Timeline.BUS_DEPARTURE_SECONDS, 1.70), "departure_lasts_exactly_one_point_seven_seconds")
	_expect(is_equal_approx(float(Timeline.sample(3.60)["bus_left_uv"]), Timeline.BUS_STOP_LEFT_UV + 0.82 * 0.25), "departure_eases_in_and_travels_only_quarter_distance_by_midpoint")
	_expect(Timeline.sample(4.45 - EPSILON)["bus_visible"] and not Timeline.sample(4.45)["bus_visible"] and Timeline.sample(4.45)["phase"] == "approach_door", "bus_is_invisible_at_departure_end_4_45")
	var final_bus: Dictionary = Timeline.sample(4.45 - EPSILON)
	_expect(float(final_bus["bus_left_uv"]) - float(final_bus["camera_x_uv"]) > SOURCE_WIDTH_UV, "bus_is_physically_offscreen_before_visibility_turns_off")
	var parked_start: Dictionary = Timeline.sample(1.80)
	var parked_end: Dictionary = Timeline.sample(2.50)
	var first_gap := (start.x - float(parked_start["camera_x_uv"])) - (float(parked_start["bus_left_uv"]) - float(parked_start["camera_x_uv"]))
	var last_gap := (curb.x - float(parked_end["camera_x_uv"])) - (float(parked_end["bus_left_uv"]) - float(parked_end["camera_x_uv"]))
	_expect(is_equal_approx(last_gap - first_gap, curb.x - start.x), "shared_background_anchor_keeps_actor_bus_geometry_valid_during_drift")


func _check_driving_animation() -> void:
	var wheel_monotonic := true
	var wheel_uses_distance := true
	var stopped_animation := true
	var bob_bounded := true
	var bob_moves := false
	var door_closed_when_moving := true
	var previous_angle := -EPSILON
	var stop_angle: float = Timeline.sample(1.45)["bus_wheel_angle"]
	for step in range(1001):
		var seconds := float(step) / 100.0
		var state: Dictionary = Timeline.sample(seconds)
		var angle: float = state["bus_wheel_angle"]
		var bob: float = state["bus_body_bob"]
		wheel_monotonic = wheel_monotonic and angle + EPSILON >= previous_angle
		wheel_uses_distance = wheel_uses_distance and absf(angle * Timeline.BUS_WHEEL_RADIUS_UV - (float(state["bus_left_uv"]) - Timeline.BUS_START_LEFT_UV)) < EPSILON
		bob_bounded = bob_bounded and absf(bob) <= 1.15
		if seconds >= 1.45 and seconds <= 2.75:
			stopped_animation = stopped_animation and is_equal_approx(angle, stop_angle) and bob == 0.0 and float(state["bus_speed_uv"]) == 0.0 and not state["bus_moving"]
		if state["bus_moving"]:
			bob_moves = bob_moves or absf(bob) > 0.1
			door_closed_when_moving = door_closed_when_moving and is_zero_approx(float(state["bus_door_open"]))
		previous_angle = angle
	_expect(wheel_monotonic, "wheels_rotate_monotonically_with_forward_travel")
	_expect(wheel_uses_distance, "wheel_angle_is_actual_driven_world_distance_divided_by_radius")
	_expect(stopped_animation, "wheels_speed_and_body_bob_remain_stationary_for_entire_stop")
	_expect(bob_bounded and bob_moves, "body_bob_is_animated_but_never_exceeds_1_15_design_pixels")
	_expect(door_closed_when_moving, "bus_door_remains_closed_during_all_driving_motion")
	var accelerating := true
	var derivative_matches := true
	var previous_speed := 0.0
	for step in range(1, 170):
		var seconds := 2.75 + float(step) / 100.0
		var state: Dictionary = Timeline.sample(seconds)
		var speed: float = state["bus_speed_uv"]
		accelerating = accelerating and speed > previous_speed
		var numerical_speed := (float(Timeline.sample(seconds + EPSILON)["bus_left_uv"]) - float(Timeline.sample(seconds - EPSILON)["bus_left_uv"])) / (2.0 * EPSILON)
		derivative_matches = derivative_matches and absf(speed - numerical_speed) < EPSILON
		previous_speed = speed
	_expect(accelerating, "departure_accelerates_smoothly_instead_of_snapping_to_full_speed")
	_expect(derivative_matches, "reported_bus_speed_matches_derivative_of_actual_position")
	var settled: Dictionary = Timeline.sample(4.45)
	var finished: Dictionary = Timeline.sample(8.0)
	_expect(settled["bus_wheel_angle"] == finished["bus_wheel_angle"] and float(finished["bus_body_bob"]) == 0.0, "hidden_bus_animation_holds_after_departure")


func _approach_start() -> float:
	var curb := Vector2(0.67, 0.95)
	return 2.75 + sqrt((curb.x + 0.02 - 0.28) / 0.82) * (4.45 - 2.75)


func _check_walk_and_entry() -> void:
	var start := _approach_start()
	var before_crossing: Dictionary = Timeline.sample(start - EPSILON)
	var crossing: Dictionary = Timeline.sample(start)
	_expect(not before_crossing["player_moving"] and crossing["player_moving"] and is_equal_approx(float(crossing["bus_left_uv"]), Vector2(crossing["player_curb_uv"]).x + 0.02), "player_starts_exactly_when_departing_bus_rear_clears_curb_plus_margin")
	_expect(start < 4.45 and crossing["bus_visible"] and crossing["bus_moving"], "player_approach_overlaps_clear_bus_departure_without_waiting_offscreen")
	var approaches_door := true
	var player_visible := true
	var bus_clear := true
	var pose_clock_advances := true
	var previous_position: Vector2 = crossing["player_position_uv"]
	var previous_distance := previous_position.distance_to(Timeline.BAR_DOOR_UV)
	var previous_pose_clock := -1.0
	var seen_walk_frames: Dictionary = {}
	for step in range(1001):
		var seconds := lerpf(start, 6.15, float(step) / 1000.0)
		var state: Dictionary = Timeline.sample(seconds)
		var position: Vector2 = state["player_position_uv"]
		var distance := position.distance_to(Timeline.BAR_DOOR_UV)
		approaches_door = approaches_door and distance <= previous_distance + EPSILON and position.x + EPSILON >= previous_position.x and position.y <= previous_position.y + EPSILON
		player_visible = player_visible and state["player_visible"] and state["player_alpha"] == 1.0
		bus_clear = bus_clear and (not state["bus_visible"] or float(state["bus_left_uv"]) >= position.x + 0.02 - EPSILON)
		pose_clock_advances = pose_clock_advances and float(state["player_motion_seconds"]) > previous_pose_clock
		if seconds < 6.15: seen_walk_frames[state["walk_frame"]] = true
		previous_position = position
		previous_distance = distance
		previous_pose_clock = state["player_motion_seconds"]
	_expect(approaches_door and is_zero_approx(previous_distance), "player_monotonically_approaches_exact_bar_door")
	_expect(player_visible, "player_remains_visible_through_walk_to_door")
	_expect(bus_clear, "departing_bus_rear_stays_safely_ahead_of_walking_player")
	_expect(pose_clock_advances and seen_walk_frames.size() == 4, "continuous_walk_clock_advances_and_debug_frames_cover_all_four_poses")
	_expect(Timeline.sample(2.50)["player_motion_seconds"] == crossing["player_motion_seconds"], "player_pose_clock_pauses_until_safe_crossing")
	var threshold_wait := true
	var opens_at_threshold := true
	var previous_door := -EPSILON
	for step in range(101):
		var state: Dictionary = Timeline.sample(lerpf(6.15, 6.65, float(step) / 100.0))
		threshold_wait = threshold_wait and Vector2(state["player_position_uv"]).is_equal_approx(Timeline.BAR_DOOR_UV) and state["player_visible"] and state["player_alpha"] == 1.0 and state["player_motion_seconds"] == previous_pose_clock
		opens_at_threshold = opens_at_threshold and float(state["destination_door_open"]) + EPSILON >= previous_door
		previous_door = state["destination_door_open"]
	_expect(threshold_wait, "player_waits_visibly_at_actual_threshold_while_door_opens")
	_expect(opens_at_threshold and is_zero_approx(float(Timeline.sample(6.15)["destination_door_open"])) and is_equal_approx(previous_door, 1.0), "destination_door_opens_fully_before_threshold_crossing")
	var entry_moves_inside := true
	var entry_stays_visible := true
	var entry_clock_advances := true
	var inside: Vector2 = Timeline.sample(7.25)["destination_inside_uv"]
	previous_distance = Timeline.BAR_DOOR_UV.distance_to(inside)
	for step in range(101):
		var state: Dictionary = Timeline.sample(lerpf(6.65, 7.25, float(step) / 100.0))
		var distance := Vector2(state["player_position_uv"]).distance_to(inside)
		entry_moves_inside = entry_moves_inside and distance <= previous_distance + EPSILON and state["player_in_entrance"] and not state["bus_visible"]
		entry_stays_visible = entry_stays_visible and state["player_visible"] and state["player_alpha"] == 1.0 and is_equal_approx(float(state["destination_door_open"]), 1.0)
		if step > 0: entry_clock_advances = entry_clock_advances and float(state["player_motion_seconds"]) > previous_pose_clock
		previous_pose_clock = state["player_motion_seconds"]
		previous_distance = distance
	_expect(entry_moves_inside and is_zero_approx(previous_distance) and inside.distance_to(Timeline.BAR_DOOR_UV) > 0.05, "player_physically_crosses_threshold_to_interior_anchor")
	_expect(entry_stays_visible and entry_clock_advances, "entry_is_visible_walking_through_fully_open_door_not_alpha_fade")
	var door_covers_actor := true
	previous_door = 1.0
	for step in range(101):
		var state: Dictionary = Timeline.sample(lerpf(7.25, 7.90, float(step) / 100.0))
		door_covers_actor = door_covers_actor and Vector2(state["player_position_uv"]).is_equal_approx(inside) and state["player_alpha"] == 1.0 and state["player_motion_seconds"] == previous_pose_clock and not state["player_moving"]
		door_covers_actor = door_covers_actor and float(state["destination_door_open"]) <= previous_door + EPSILON and (state["player_visible"] if step < 100 else not state["player_visible"])
		previous_door = state["destination_door_open"]
	_expect(door_covers_actor and is_zero_approx(previous_door), "actor_retires_only_after_closing_door_fully_covers_interior")
	for seconds in [7.90, 8.0]:
		var state: Dictionary = Timeline.sample(seconds)
		_expect(state["phase"] == "arrival" and not state["player_visible"] and state["player_alpha"] == 1.0 and Vector2(state["player_position_uv"]).is_equal_approx(inside), "arrival_holds_player_inside_closed_door_%s" % seconds)


func _check_finite_deterministic_samples() -> void:
	var finite := true
	var bounded := true
	var deterministic := true
	seed(95621)
	var expected_random := randi()
	seed(95621)
	var snapshots: Array[Dictionary] = []
	for step in range(1041):
		var seconds := float(step - 20) / 100.0
		var state: Dictionary = Timeline.sample(seconds)
		snapshots.append(state.duplicate(true))
		for key in state:
			var value: Variant = state[key]
			if value is float:
				finite = finite and is_finite(float(value))
			elif value is Vector2:
				finite = finite and is_finite(value.x) and is_finite(value.y)
		for key in ["bus_door_open", "player_alpha", "bar_door_open"]:
			bounded = bounded and float(state[key]) >= 0.0 and float(state[key]) <= 1.0
		bounded = bounded and is_equal_approx(float(state["player_scale"]), 1.0)
		bounded = bounded and state["walk_frame"] is int and int(state["walk_frame"]) >= 0 and int(state["walk_frame"]) <= 3
	for step in range(1040, -1, -1):
		deterministic = deterministic and Timeline.sample(float(step - 20) / 100.0) == snapshots[step]
	_expect(randi() == expected_random, "pure_timeline_never_consumes_global_rng")
	_expect(finite, "all_sampled_numeric_and_vector_values_are_finite")
	_expect(bounded, "alpha_doors_scale_and_walk_frames_remain_bounded")
	_expect(deterministic, "samples_are_pure_deterministic_and_independent_of_call_order")


func _expect(ok: bool, label: String) -> void:
	_checks.append(label)
	if not ok:
		_failures.append(label)
