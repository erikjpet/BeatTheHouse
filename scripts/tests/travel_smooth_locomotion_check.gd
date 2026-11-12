extends SceneTree

# Synthetic visual fixtures only. Legal settled routes are covered independently
# by destination_travel_integration_check, not inferred from these four methods.
const Timeline := preload("res://scripts/ui/travel_arrival_timeline.gd")
const Catalog := preload("res://scripts/ui/travel_presentation_catalog.gd")
const Overlay := preload("res://scripts/ui/travel_cinematic_overlay.gd")
const Avatar := preload("res://scripts/ui/character_avatar_view.gd")
const Vehicle := preload("res://scripts/ui/travel_vehicle_view.gd")
const Appearance := preload("res://scripts/ui/character_appearance_snapshot.gd")
const MODES := ["walk", "bus", "taxi", "night_cab"]
var checks := 0
var failures: Array[String] = []
var metrics: Dictionary = {}
var captures: Array[String] = []
var evidence := ""

class PaintProbe:
	extends RefCounted
	var commands: Array = []
	var top := INF
	var bottom := -INF
	var left := INF
	var right := -INF
	func _point(point: Vector2, pad: float = 0.0) -> void:
		top = minf(top, point.y - pad)
		bottom = maxf(bottom, point.y + pad)
		left = minf(left, point.x - pad)
		right = maxf(right, point.x + pad)
	func draw_rect(rect: Rect2, color: Color, filled: bool = true, width: float = -1.0) -> void:
		commands.append(["rect", rect, color, filled, width])
		_point(rect.position)
		_point(rect.end)
	func draw_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0) -> void:
		commands.append(["line", from, to, color, width])
		_point(from, maxf(0.0, width) * 0.5)
		_point(to, maxf(0.0, width) * 0.5)
	func surface_label(label: String, pos: Vector2, font_size: int, color: Color) -> void:
		commands.append(["label", label, pos, font_size, color])

func _initialize() -> void:
	_run.call_deferred()

func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _receipt(destination: String, mode: String) -> Dictionary:
	return {"presentation_key":Catalog.STANDARD_KEY, "journey_id":"smooth-visual-only",
		"travel_method_kind":mode, "effective_destination_archetype_id":destination,
		"destination_label":"Synthetic visual fixture", "receipt_text":"Visual only; not a legal-route proof"}

func _run() -> void:
	evidence = OS.get_environment("BTH_QA_EVIDENCE_DIR")
	_expect(Timeline.DURATION_SECONDS == 8.0, "approved production sequence remains exactly eight seconds")
	_check_motion()
	_check_delta()
	var rendered := "--pure-only" not in OS.get_cmdline_user_args()
	if rendered:
		_expect(DisplayServer.get_name() != "headless", "actual GPU renderer is required")
		if DisplayServer.get_name() != "headless":
			await _check_avatar_pixels()
			await _check_vehicle_pixels()
	var report := {"suite":"travel_smooth_locomotion", "passed":failures.is_empty(), "checks":checks,
		"failures":failures, "metrics":metrics, "captures":captures, "rendered":rendered,
		"visual_preview_only":true, "legal_route_proof":false}
	if not evidence.is_empty():
		var file := FileAccess.open(evidence.path_join("smooth_locomotion_report.json"), FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _check_delta() -> void:
	var overlay := Overlay.new()
	root.add_child(overlay)
	var results: Array = []
	for mode in MODES:
		var receipt := _receipt("delta_queen", mode)
		var profile: Dictionary = Catalog.profile(receipt)
		var exterior: Dictionary = profile["exterior"]
		var motion: Dictionary = profile["motion"]
		var measured := Rect2(1320.0 / 1774.0, 533.0 / 887.0, 92.0 / 1774.0, 59.0 / 887.0)
		var clearance: Array = exterior.get("boarding_clearance_rect_uv", [0,0,0,0])
		_expect(Rect2(float(clearance[0]),float(clearance[1]),float(clearance[2]),float(clearance[3])).is_equal_approx(measured), "Delta boarding clearance matches measured actual ship opening")
		var expected_end := measured.size.y * 0.82 / float(profile["avatar_height_uv"])
		var near_fraction := (Vector2(motion["destination_anchor_uv"]).y - Vector2(motion["destination_inside_uv"]).y) / (float(exterior["road_y_uv"]) - Vector2(motion["destination_inside_uv"]).y)
		var expected_near := lerpf(expected_end, 1.0, near_fraction)
		_expect(expected_end < 0.58 and expected_end > 0.15 and expected_near > expected_end and expected_near < 1.0, mode + " measured far and near scales replace oversized fixed0.58 arrival")
		var start := float(Timeline.sample(0, mode, motion)["player_approach_start_seconds"])
		var previous_scale := 1.0
		var monotonic := true
		var max_delta := 0.0
		for step in range(8001):
			var state: Dictionary = Timeline.sample(float(step) / 1000.0, mode, motion)
			var scale_value := float(state["player_scale"])
			monotonic = monotonic and scale_value <= previous_scale + 0.000001 and scale_value >= expected_end - 0.000001
			max_delta = maxf(max_delta, absf(scale_value - previous_scale))
			if float(step) / 1000.0 <= start: monotonic = monotonic and is_equal_approx(scale_value, 1.0)
			previous_scale = scale_value
		_expect(monotonic and max_delta < 0.001, mode + " depth reduction is monotonic and gradual in every millisecond sample")
		_expect(is_equal_approx(float(Timeline.sample(6.15, mode, motion)["player_scale"]), expected_near) and is_equal_approx(previous_scale, expected_end), mode + " near and far endpoints match measured ship perspective")
		for boundary in [start, 6.15, 7.90]:
			_expect(absf(float(Timeline.sample(boundary - 0.00001, mode, motion)["player_scale"]) - float(Timeline.sample(boundary + 0.00001, mode, motion)["player_scale"])) < 0.00005, mode + " scale has no boundary pop at " + str(boundary))
		for model_scale in [0.75, 1.0, 1.25]:
			var appearance := Appearance.from_character({"id":"smooth_delta", "model":{"scale":model_scale, "silhouette":"cap"}})
			overlay.present(receipt, false, false, 1.0, false, appearance)
			overlay.set_process(false)
			var avatar: Control = overlay.get("_avatar_view")
			var clip: Control = overlay.get("_avatar_clip")
			var stage: Rect2 = overlay.get("_stage")
			var grounded := true
			for index in range(241):
				var seconds := float(index) / 30.0
				overlay.advance_presentation(seconds - float(overlay.elapsed))
				var state: Dictionary = overlay.choreography_snapshot()
				var foot: Vector2 = state["player_position_uv"]
				var rendered_foot: Vector2 = clip.position + avatar.position + avatar.foot_position()
				var expected_foot := stage.position + Vector2((foot.x - float(state["camera_x_uv"])) / float(profile["source_width_uv"]) * stage.size.x, (foot.y - float(profile["source_top_y_uv"])) / float(profile["view_height_uv"]) * stage.size.y)
				if bool(state["player_visible"]): grounded = grounded and rendered_foot.distance_to(expected_foot) < 0.01
			_expect(grounded, mode + " model" + str(model_scale) + " actual avatar soles remain attached to the authored gangway path")
			var probe := _paint_avatar(avatar)
			var origin: Vector2 = clip.position + avatar.position
			var state: Dictionary = overlay.choreography_snapshot()
			var top_screen := stage.position.y + (measured.position.y - float(profile["source_top_y_uv"])) / float(profile["view_height_uv"]) * stage.size.y
			var left_screen := stage.position.x + (measured.position.x - float(state["camera_x_uv"])) / float(profile["source_width_uv"]) * stage.size.x
			var right_screen := left_screen + measured.size.x / float(profile["source_width_uv"]) * stage.size.x
			var sill_screen := stage.position.y + (measured.end.y - float(profile["source_top_y_uv"])) / float(profile["view_height_uv"]) * stage.size.y
			_expect(origin.y + probe.top >= top_screen + 1.0 and origin.x + probe.left >= left_screen and origin.x + probe.right <= right_screen, mode + " model" + str(model_scale) + " painted head cap arms and legs fit the actual ship opening")
			var painted_sole := maxf(Rect2(probe.commands[3][1]).end.y, Rect2(probe.commands[6][1]).end.y)
			_expect(absf(origin.y + avatar.size.y - sill_screen) < 0.02 and absf(origin.y + painted_sole - sill_screen) < 0.02, mode + " far painted soles stand on actual sill without hovering")
			results.append({"mode":mode,"model_scale":model_scale,"near_scale":expected_near,"far_scale":expected_end,"max_scale_step_1ms":max_delta,"painted_top":origin.y+probe.top,"opening_top":top_screen,"sill":sill_screen})
			overlay.cancel()
	metrics["delta"] = results
	overlay.free()

func _paint_avatar(avatar: Control) -> PaintProbe:
	var probe := PaintProbe.new()
	var pose: Dictionary = avatar.pose_snapshot()
	Avatar.draw_avatar(probe, avatar.snapshot(), avatar.size, str(pose["pose"]), float(pose["clock"]), pose.get("locomotion", {}))
	return probe

func _locomotion(state: Dictionary) -> Dictionary:
	return {"walk_weight":state["player_walk_weight"], "walk_phase":state["player_walk_phase"],
		"walk_amplitude":state["player_walk_amplitude"], "idle_seconds":state["player_idle_seconds"]}

func _paint_state(state: Dictionary, appearance: Dictionary) -> PaintProbe:
	var pose := "walk" if bool(state["player_moving"]) else "idle"
	if bool(state["player_facing_away"]): pose = "walk_away" if bool(state["player_moving"]) else "away_idle"
	var probe := PaintProbe.new()
	Avatar.draw_avatar(probe, appearance, Avatar.DESIGN_SIZE, pose, float(state["player_animation_seconds"]), _locomotion(state))
	return probe

func _geometry_delta(a: PaintProbe, b: PaintProbe) -> float:
	# The first sixteen primitives contain shadow, both legs/soles, torso and
	# both canonical arms/hands, before front/back facial detail diverges.
	var maximum := 0.0
	for index in range(16):
		if a.commands[index][0] != b.commands[index][0]: return INF
		if a.commands[index][0] == "line":
			maximum = maxf(maximum, Vector2(a.commands[index][1]).distance_to(b.commands[index][1]))
			maximum = maxf(maximum, Vector2(a.commands[index][2]).distance_to(b.commands[index][2]))
		elif a.commands[index][0] == "rect":
			maximum = maxf(maximum, Rect2(a.commands[index][1]).position.distance_to(Rect2(b.commands[index][1]).position))
	return maximum

func _check_motion() -> void:
	var results: Array = []
	for destination in ["grand_casino", "back_alley", "delta_queen"]:
		for mode in MODES:
			var profile: Dictionary = Catalog.profile(_receipt(destination,mode))["motion"]
			var states: Array[Dictionary] = []
			var phase_forward := true
			var bounded := true
			var frozen := true
			var repeatable := true
			var minimum_rate := INF
			var maximum_rate := -INF
			var minimum_amplitude := INF
			var maximum_amplitude := -INF
			seed(162803)
			var expected_random := randi()
			seed(162803)
			for index in range(8001):
				var state: Dictionary = Timeline.sample(float(index)/1000.0, mode, profile)
				states.append(state)
				var phase := float(state["player_walk_phase"])
				var amplitude := float(state["player_walk_amplitude"])
				bounded = bounded and float(state["player_walk_weight"]) >= 0.0 and float(state["player_walk_weight"]) <= 1.0 and amplitude >= 0.88 - 0.000001 and amplitude <= 1.0
				bounded = bounded and is_equal_approx(float(state["player_animation_seconds"])*8.0,phase) and is_equal_approx(float(state["player_idle_seconds"]),float(index)/1000.0)
				if index == 0: continue
				var previous: Dictionary = states[index-1]
				var rate := (phase-float(previous["player_walk_phase"]))*1000.0
				phase_forward = phase_forward and rate >= -0.000001
				if bool(state["player_moving"]) and bool(previous["player_moving"]):
					minimum_rate = minf(minimum_rate,rate)
					maximum_rate = maxf(maximum_rate,rate)
					minimum_amplitude = minf(minimum_amplitude,amplitude)
					maximum_amplitude = maxf(maximum_amplitude,amplitude)
				elif not bool(state["player_moving"]) and not bool(previous["player_moving"]): frozen = frozen and absf(rate) < 0.000001
			for index in range(8000,-1,-1): repeatable = repeatable and states[index] == Timeline.sample(float(index)/1000.0,mode,profile)
			var label: String = destination + " " + mode
			_expect(repeatable and randi() == expected_random,label + " whole gait is deterministic in reverse call order without global RNG")
			_expect(phase_forward and frozen,label + " phase always advances while moving and never resets or advances during a stop")
			_expect(bounded and minimum_rate >= 8.8*0.939 and maximum_rate <= 8.8*1.061,label + " gait amplitude and cadence have natural bounded variation")
			_expect(maximum_rate-minimum_rate > 0.1 and maximum_amplitude-minimum_amplitude > 0.025,label + " gait has real variation instead of one rigid repeated sine loop")
			var start := float(states[0]["player_approach_start_seconds"])
			var epsilon_delta := 0.0
			var frame_delta := 0.0
			for model_scale in [0.75,1.0,1.25]:
				var appearance := Appearance.from_character({"model":{"scale":model_scale,"silhouette":"cap"}})
				for boundary in [0.0,1.80,2.50,start,6.15,6.65,7.25,7.90,8.0]:
					var before := _paint_state(Timeline.sample(boundary-0.00001,mode,profile),appearance)
					var after := _paint_state(Timeline.sample(boundary+0.00001,mode,profile),appearance)
					epsilon_delta = maxf(epsilon_delta,_geometry_delta(before,after))
					var previous: PaintProbe = _paint_state(Timeline.sample(boundary-0.25,mode,profile),appearance)
					for frame in range(1,17):
						var current: PaintProbe = _paint_state(Timeline.sample(boundary-0.25+float(frame)/30.0,mode,profile),appearance)
						frame_delta = maxf(frame_delta,_geometry_delta(previous,current))
						previous = current
			_expect(epsilon_delta < 0.02,label + " canonical arm endpoints hips and legs are continuous across every start and stop")
			_expect(frame_delta < 7.5,label + " 30fps start-stop arm leg and hip motion has no one-frame snap")
			results.append({"destination":destination,"mode":mode,"minimum_rate":minimum_rate,"maximum_rate":maximum_rate,"minimum_amplitude":minimum_amplitude,"maximum_amplitude":maximum_amplitude,"boundary_20us_max_point_delta":epsilon_delta,"frame_max_point_delta":frame_delta})
	metrics["locomotion"] = results

func _capture(viewport: SubViewport, name: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image()
	if not evidence.is_empty():
		var path := evidence.path_join(name + ".png")
		_expect(result.save_png(path) == OK, "GPU evidence saved: " + name)
		captures.append(path)
	return result

func _pixel_difference(a: Image, b: Image, first_y: int = 0) -> int:
	var count := 0
	for y in range(first_y,a.get_height()):
		for x in a.get_width():
			if a.get_pixel(x,y) != b.get_pixel(x,y): count += 1
	return count

func _roof_pixel_y(image: Image, target: Rect2) -> int:
	for y in range(maxi(0,int(target.position.y)-5), mini(image.get_height(),int(target.position.y+target.size.y*0.4))):
		for x in range(int(target.position.x+target.size.x*0.25), int(target.position.x+target.size.x*0.75)):
			if image.get_pixel(x,y).a >= 0.80: return y
	return -1

func _check_avatar_pixels() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var avatar := Avatar.new()
	avatar.position = Vector2(72,100)
	avatar.size = Avatar.DESIGN_SIZE
	viewport.add_child(avatar)
	avatar.set_appearance(Appearance.from_character({"model":{"scale":1.25,"silhouette":"cap"}}))
	var results: Array = []
	for mode in MODES:
		var profile: Dictionary = Catalog.profile(_receipt("grand_casino",mode))["motion"]
		var start := float(Timeline.sample(0,mode,profile)["player_approach_start_seconds"])
		for boundary in [2.50,start,6.15,6.65,7.25,7.90]:
			var images: Array[Image] = []
			for offset in [-0.00001,0.00001]:
				var state: Dictionary = Timeline.sample(boundary+offset,mode,profile)
				var pose := "walk" if bool(state["player_moving"]) else "idle"
				if bool(state["player_facing_away"]): pose = "walk_away" if bool(state["player_moving"]) else "away_idle"
				avatar.set_pose(pose,float(state["player_animation_seconds"]),_locomotion(state))
				images.append(await _capture(viewport,"avatar_"+mode+"_"+str(boundary).replace(".","_")+ ("_before" if offset < 0 else "_after")))
			# Exclude the head: an intentional front-to-back turn at approach
			# start changes facial pixels, not the arm/hip/leg continuity contract.
			var changed := _pixel_difference(images[0],images[1],135)
			_expect(changed < 40,mode + " rendered arm hip and leg pixels have no boundary snap at"+str(boundary))
			results.append({"mode":mode,"boundary":boundary,"changed_pixels_across_20us":changed})
	metrics["avatar_pixels"] = results
	viewport.free()

func _check_vehicle_pixels() -> void:
	var results: Array = []
	for mode in ["bus", "taxi", "night_cab"]:
		var overlay := Overlay.new()
		root.add_child(overlay)
		overlay.present(_receipt("delta_queen", mode))
		overlay.set_process(false)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(900, 420)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var view := Vehicle.new()
		viewport.add_child(view)
		view.size = Vector2(900,420)
		view.configure(overlay.get("_vehicle"), overlay.get("_vehicle_source"), overlay.get("_vehicle_door_uv"), overlay.get("_vehicle_wheels"))
		var source: Rect2 = overlay.get("_vehicle_source")
		var width := 691.2 if mode == "bus" else 489.6
		var target := Rect2(40,50,width,width * source.size.y / source.size.x)
		var maximum := -INF
		var minimum := INF
		var peak_time := 0.0
		for index in range(4451):
			var bob := float(Timeline.sample(float(index)/1000.0, mode)["vehicle_body_bob"])
			if absf(bob) > maxf(absf(maximum) if is_finite(maximum) else 0.0, absf(minimum) if is_finite(minimum) else 0.0): peak_time = float(index)/1000.0
			maximum = maxf(maximum,bob)
			minimum = minf(minimum,bob)
		var peak := maximum if absf(maximum) >= absf(minimum) else minimum
		view.set_frame(target, 0.7, 0.0, 0.0, true)
		var parked_plan: Dictionary = view.draw_snapshot()
		var parked: Image = await _capture(viewport, mode + "_suspension_zero")
		# Same conversion as the real1280x720 production overlay's500px stage.
		view.set_frame(target, 0.7, peak * 500.0 / 370.0, 0.0, true)
		var moving_plan: Dictionary = view.draw_snapshot()
		var moving: Image = await _capture(viewport, mode + "_suspension_peak")
		var changed := _pixel_difference(parked,moving)
		var displacement: float = moving_plan["body_rect"].position.y - parked_plan["body_rect"].position.y
		var roof_pixel_displacement := _roof_pixel_y(moving,target) - _roof_pixel_y(parked,target)
		_expect(absf(peak) > 0.50 and absf(peak) < 1.5 and maximum - minimum > 1.0, mode + " suspension is noticeably restored yet less intense than old1.5px maximum")
		_expect(changed > 200 and absf(displacement) >= 1.0 and absi(roof_pixel_displacement) >= 1 and parked_plan["wheels"] == moving_plan["wheels"], mode + " actual GPU body roof shifts at least one pixel while physical wheels stay grounded")
		results.append({"mode":mode,"minimum_logical":minimum,"maximum_logical":maximum,"peak_time":peak_time,"rendered_displacement":displacement,"roof_pixel_displacement":roof_pixel_displacement,"changed_gpu_pixels":changed})
		viewport.free()
		overlay.free()
	metrics["vehicle_pixels"] = results
