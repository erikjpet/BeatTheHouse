extends SceneTree

# Independent acceptance checks for the eight-second review. Synthetic visual
# profiles are intentionally separate from the legal-route integration matrix.
const Timeline := preload("res://scripts/ui/travel_arrival_timeline.gd")
const Catalog := preload("res://scripts/ui/travel_presentation_catalog.gd")
const Overlay := preload("res://scripts/ui/travel_cinematic_overlay.gd")
const Avatar := preload("res://scripts/ui/character_avatar_view.gd")
const Appearance := preload("res://scripts/ui/character_appearance_snapshot.gd")
const MODES := ["walk", "bus", "taxi", "night_cab"]
const EPSILON := 0.00001
var checks := 0
var failures: Array[String] = []

class PaintBounds:
	extends RefCounted
	var top := INF
	func draw_rect(rect: Rect2, _color: Color, _filled: bool = true, _width: float = -1.0) -> void:
		top = minf(top, rect.position.y)
	func draw_line(from: Vector2, to: Vector2, _color: Color, width: float = -1.0) -> void:
		top = minf(top, minf(from.y, to.y) - maxf(width, 0.0) * 0.5)
	func surface_label(_label: String, _pos: Vector2, _font_size: int, _color: Color) -> void:
		pass

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _run() -> void:
	_expect(Timeline.DURATION_SECONDS == 8.0, "production duration is exactly eight seconds")
	_check_suspension()
	_check_cadence()
	_check_direction()
	var pure_only := "--pure-only" in OS.get_cmdline_user_args()
	if not pure_only: _check_grounded_entry()
	print("TRAVEL_EIGHT_SECOND_REFINEMENT_CHECK " + JSON.stringify({"suite":"travel_eight_second_refinement", "checks":checks, "passed":failures.is_empty(), "failures":failures, "visual_preview_only":true, "pure_only":pure_only}))
	quit(0 if failures.is_empty() else 1)

func _check_suspension() -> void:
	for mode in ["bus", "taxi", "night_cab"]:
		var small := {"vehicle_wheel_radius_uv":0.012}
		var large := {"vehicle_wheel_radius_uv":0.060}
		var radius_independent := true
		var physical_wheels := true
		var bounded := true
		var stop_zero := true
		var motion_visible := false
		var deterministic := true
		var states: Array[Dictionary] = []
		seed(678912)
		var expected_random := randi()
		seed(678912)
		for step in range(8001):
			var seconds := float(step) / 1000.0
			var a: Dictionary = Timeline.sample(seconds, mode, small)
			var b: Dictionary = Timeline.sample(seconds, mode, large)
			states.append(a)
			var bob := float(a["vehicle_body_bob"])
			radius_independent = radius_independent and bob == float(b["vehicle_body_bob"])
			physical_wheels = physical_wheels and is_equal_approx(float(a["vehicle_wheel_angle"]) * 0.012, float(b["vehicle_wheel_angle"]) * 0.060)
			bounded = bounded and absf(bob) <= 1.15
			if not a["vehicle_moving"]: stop_zero = stop_zero and bob == 0.0
			else: motion_visible = motion_visible or absf(bob) > 0.05
		for step in range(8000, -1, -1):
			deterministic = deterministic and Timeline.sample(float(step) / 1000.0, mode, small) == states[step]
		_expect(radius_independent and physical_wheels, mode + " suspension is independent of wheel radius while wheels keep physical rotation")
		_expect(bounded and motion_visible, mode + " gentle suspension moves but stays below 1.15 design pixels")
		_expect(stop_zero, mode + " suspension is exactly zero throughout stop and after departure")
		_expect(deterministic and randi() == expected_random, mode + " suspension is repeatable in reverse call order without global RNG")
		# A full wheel revolution must not recreate a phase-locked suspension
		# waveform. Compare the signal after removing its smooth travel envelope.
		var normalized: Array[float] = []
		var start: Dictionary = Timeline.sample(0.0, mode, small)
		var stop: Dictionary = Timeline.sample(Timeline.BUS_STOP_SECONDS, mode, small)
		var distance := float(stop["vehicle_left_uv"]) - float(start["vehicle_left_uv"])
		for turn in range(4):
			var fraction := (0.030 + turn * TAU * 0.012) / distance
			var seconds := Timeline.BUS_STOP_SECONDS * (1.0 - pow(1.0 - fraction, 1.0 / 3.0))
			var state: Dictionary = Timeline.sample(seconds, mode, small)
			var envelope := sin(PI * fraction) * minf(float(state["vehicle_speed_uv"]) / 0.35, 1.0)
			normalized.append(float(state["vehicle_body_bob"]) / maxf(envelope, EPSILON))
		_expect(normalized.max() - normalized.min() > 0.01, mode + " suspension does not repeat once per wheel revolution")

func _check_direction() -> void:
	for mode in MODES:
		var curb := Vector2(0.60, 0.94)
		var waypoint := Vector2(0.70, 0.94)
		var threshold := Vector2(0.70, 0.78)
		var profile := {"player_curb_uv":curb, "approach_waypoint_uv":waypoint, "destination_anchor_uv":threshold, "destination_inside_uv":Vector2(0.70, 0.72), "entrance_kind":"door"}
		var start := float(Timeline.sample(0.0, mode, profile)["player_approach_start_seconds"])
		var span := Timeline.DOOR_REACH_SECONDS - start
		var corner := curb.distance_to(waypoint) / (curb.distance_to(waypoint) + waypoint.distance_to(threshold))
		var sideways: Dictionary = Timeline.sample(start + span * corner * 0.5, mode, profile)
		var upward: Dictionary = Timeline.sample(start + span * (corner + (1.0 - corner) * 0.5), mode, profile)
		_expect(not sideways["player_facing_away"] and sideways["player_moving"], mode + " sideways driveway segment keeps forward-facing actor")
		_expect(upward["player_facing_away"] and upward["player_moving"], mode + " upward driveway segment turns actor back toward camera")
		_expect(Timeline.sample(lerpf(Timeline.ENTER_SECONDS, Timeline.ENTRY_INSIDE_SECONDS, 0.5), mode, profile)["player_facing_away"], mode + " walking depthward through an indoor door is back-facing")
		if mode == "walk":
			_expect(not Timeline.sample(start * 0.5, mode, profile)["player_facing_away"], "sideways walking transit stays forward-facing")
		else:
			_expect(not Timeline.sample(lerpf(Timeline.DROPOFF_SECONDS, Timeline.DOOR_CLOSE_SECONDS, 0.5), mode, profile)["player_facing_away"], mode + " stepping down from vehicle stays forward-facing")
		for kind in ["open", "passage", "dock"]:
			profile["entrance_kind"] = kind
			var seconds := lerpf(Timeline.DOOR_REACH_SECONDS, Timeline.DESTINATION_CLOSE_SECONDS, 0.5)
			profile["destination_inside_uv"] = threshold + Vector2(0.10, 0.0)
			_expect(not Timeline.sample(seconds, mode, profile)["player_facing_away"], mode + " " + kind + " sideways departure stays forward-facing")
			profile["destination_inside_uv"] = threshold + Vector2(0.0, -0.10)
			_expect(Timeline.sample(seconds, mode, profile)["player_facing_away"], mode + " " + kind + " depthward departure turns back-facing")

func _check_cadence() -> void:
	_expect(Timeline.WALK_CADENCE_SCALE == 1.10, "gait increases by a comfortable ten percent, not the full time compression")
	for mode in MODES:
		var exact_clock := true
		var paused := true
		var previous: Dictionary = Timeline.sample(0.0, mode)
		for step in range(1, 8001):
			var state: Dictionary = Timeline.sample(float(step) / 1000.0, mode)
			exact_clock = exact_clock and is_equal_approx(float(state["player_animation_seconds"]), float(state["player_walk_phase"]) / 8.0)
			if not state["player_moving"] and not previous["player_moving"]:
				paused = paused and state["player_animation_seconds"] == previous["player_animation_seconds"]
			previous = state
		_expect(exact_clock and paused, mode + " bounded variable gait follows only actual walking and pauses during waits")

func _check_grounded_entry() -> void:
	var overlay := Overlay.new()
	root.add_child(overlay)
	var indoor_count := 0
	for destination in Catalog.EXTERIOR_IDS:
		var exterior: Dictionary = Catalog.exterior_contract(destination)
		if exterior.get("arrival_kind") != "door": continue
		indoor_count += 1
		var top := 1.0
		var sill := 0.0
		for point in exterior["door_polygon_uv"]:
			top = minf(top, float(point[1]))
			sill = maxf(sill, float(point[1]))
		for mode in MODES:
			var receipt := {"presentation_key":Catalog.STANDARD_KEY, "journey_id":"grounded-preview", "travel_method_kind":mode, "effective_destination_archetype_id":destination, "destination_label":"Visual preview", "receipt_text":"Visual preview only"}
			var scene: Dictionary = Catalog.profile(receipt)
			var threshold: Vector2 = scene["motion"]["destination_anchor_uv"]
			_expect(threshold.y >= sill and threshold.y - sill <= 0.015, str(destination) + " threshold has only the measured shallow doorstep rise")
			for model_scale in [0.75, 1.0, 1.25]:
				var appearance := Appearance.from_character({"id":"grounded_preview", "model":{"scale":model_scale, "silhouette":"cap"}})
				overlay.present(receipt, false, false, 1.0, false, appearance)
				var avatar: Control = overlay.get("_avatar_view")
				var clip: Control = overlay.get("_avatar_clip")
				var stage: Rect2 = overlay.get("_stage")
				var initial_height := 0.0
				var grounded := true
				var head_fits := true
				var fixed_height := true
				for index in range(61):
					var seconds := lerpf(Timeline.DOOR_REACH_SECONDS, Timeline.DESTINATION_CLOSE_SECONDS - 0.001, float(index) / 60.0)
					overlay.advance_presentation(seconds - float(overlay.elapsed))
					var state: Dictionary = overlay.choreography_snapshot()
					var foot: Vector2 = state["player_position_uv"]
					var actual_foot: Vector2 = clip.position + avatar.position + avatar.foot_position()
					var sill_screen := stage.position.y + (sill - float(scene["source_top_y_uv"])) * stage.size.y / float(scene["view_height_uv"])
					var top_screen := stage.position.y + (top - float(scene["source_top_y_uv"])) * stage.size.y / float(scene["view_height_uv"])
					var progress := float(state["entry_progress"])
					var expected_y := lerpf(threshold.y, sill, progress)
					var expected_screen_y := stage.position.y + (expected_y - float(scene["source_top_y_uv"])) * stage.size.y / float(scene["view_height_uv"])
					grounded = grounded and absf(foot.y - expected_y) <= 0.00001 and absf(actual_foot.y - expected_screen_y) <= 0.02 and actual_foot.y >= sill_screen - 0.02
					var probe := PaintBounds.new()
					var pose: Dictionary = avatar.pose_snapshot()
					Avatar.draw_avatar(probe, avatar.snapshot(), avatar.size, str(pose["pose"]), float(pose["clock"]), pose.get("locomotion", {}))
					var painted_top := clip.position.y + avatar.position.y + probe.top
					head_fits = head_fits and painted_top >= top_screen + (sill_screen - top_screen) * 0.02
					if index == 0: initial_height = avatar.size.y
					fixed_height = fixed_height and is_equal_approx(avatar.size.y, initial_height) and is_equal_approx(float(state["player_scale"]), 1.0)
				var label: String = str(destination) + " " + mode + " model scale " + str(model_scale)
				_expect(grounded, label + " feet follow measured doorstep to actual sill without rising into door")
				_expect(head_fits, label + " actual painted head and cap fit inside door opening with margin")
				_expect(fixed_height, label + " no entry height pop or scale change")
				overlay.cancel()
	_expect(indoor_count == 12, "all twelve indoor destination entrances are covered")
	overlay.free()
