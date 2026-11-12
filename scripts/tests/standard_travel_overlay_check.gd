extends SceneTree

const Overlay := preload("res://scripts/ui/travel_cinematic_overlay.gd")
const Catalog := preload("res://scripts/ui/travel_presentation_catalog.gd")
const Appearance := preload("res://scripts/ui/character_appearance_snapshot.gd")
const MODES := ["walk", "bus", "taxi", "night_cab"]
var failures: Array[String] = []
var checks := 0
var completions := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)


func _receipt(mode: String, destination: String = "motel") -> Dictionary:
	return {"schema_version":2, "journey_id":"standard_overlay_" + mode,
		"presentation_key":"standard_travel_typical_v1", "receipt_text":"Already committed travel.",
		"travel_method_kind":mode, "travel_method_label":mode, "base_minutes":24,
		"quoted_departure_fare":3, "departed_game_clock_minutes":720,
		"origin_archetype_id":"apartment", "effective_destination_archetype_id":destination,
		"origin_label":"Player's Apartment", "destination_label":"Actual Arrival",
		"route_risk":{"triggered":false}}


func _run() -> void:
	for invalid in [null, [], {}, {"texture":"res://missing.png"}, {"texture":"external.png"}]:
		_expect(Catalog.validated_vehicle_contract(invalid).is_empty(), "invalid vehicle contract rejected")
	var good_contract: Dictionary = Catalog.profile(_receipt("taxi"))["vehicle"]
	for field in ["reference_size", "source_px", "door_rect_uv", "wheels"]:
		var malformed := good_contract.duplicate(true)
		malformed[field] = "malformed"
		_expect(Catalog.validated_vehicle_contract(malformed).is_empty(), "malformed " + field + " rejected")
	var non_finite := good_contract.duplicate(true)
	non_finite["source_px"][2] = INF
	_expect(Catalog.validated_vehicle_contract(non_finite).is_empty(), "non-finite source rejected")
	var oversize := good_contract.duplicate(true)
	oversize["wheels"][0]["radius_uv"] = [1.0, 1.0]
	_expect(Catalog.validated_vehicle_contract(oversize).is_empty(), "out-of-bounds wheels rejected")
	var detached := Catalog.validated_vehicle_contract(good_contract)
	detached["door_rect_uv"][0] = 0.0
	_expect(good_contract["door_rect_uv"][0] != 0.0, "contract normalization detaches data")
	var house_contract := Catalog.exterior_contract("house")
	_expect(not house_contract.is_empty() and house_contract.get("approach_waypoint_uv") is Array, "House exterior carries authored driveway waypoint")
	var house_frozen := var_to_bytes(house_contract)
	for mode in MODES:
		var house_profile: Dictionary = Catalog.profile(_receipt(mode, "house"))
		_expect(house_profile["supported"] and house_profile["motion"].get("approach_waypoint_uv") is Vector2 and Vector2(house_profile["motion"]["approach_waypoint_uv"]).is_equal_approx(Vector2(float(house_contract["approach_waypoint_uv"][0]), float(house_contract["approach_waypoint_uv"][1]))), mode + " catalog passes validated House waypoint into timeline motion")
	for invalid in [null, "malformed", Vector2(0.7, 0.9), [], [0.7], [0.7, 0.9, 0.1], ["0.7", 0.9], [true, 0.9], [NAN, 0.9], [0.7, INF], [-0.1, 0.9], [1.1, 0.9], [0.7, -0.1], [0.7, 1.1]]:
		var malformed := house_contract.duplicate(true)
		malformed["approach_waypoint_uv"] = invalid
		var frozen_malformed := var_to_bytes(malformed)
		_expect(Catalog.validated_exterior_contract(malformed).is_empty() and var_to_bytes(malformed) == frozen_malformed, "malformed or out-of-bounds exterior waypoint fails closed without mutation: " + str(invalid))
	var no_waypoint := house_contract.duplicate(true)
	no_waypoint.erase("approach_waypoint_uv")
	_expect(not Catalog.validated_exterior_contract(no_waypoint).is_empty(), "exterior waypoint stays optional for direct approaches")
	var validated_house := Catalog.validated_exterior_contract(house_contract)
	validated_house["approach_waypoint_uv"][0] = 0.0
	_expect(var_to_bytes(house_contract) == house_frozen, "exterior waypoint validation detaches nested authored coordinates")
	var overlay := Overlay.new()
	root.add_child(overlay)
	_check_shader_contract(overlay)
	if "--gpu-alpha-check" in OS.get_cmdline_user_args(): await _check_shader_pixels(overlay)
	overlay.completed.connect(func(_id: String) -> void: completions += 1)
	var appearance := Appearance.from_character({"id":"explicit_created_model",
		"model":{"skin_color":"#785240", "hair_color":"#201831", "jacket_color":"#315177",
		"accent_color":"#21d7c5", "silhouette":"cap", "scale":1.12}},
		[{"id":"cheap_sunglasses", "environment_prop":"sunglasses"}])
	var appearance_bytes := var_to_bytes(appearance)
	_check_near_ground_staging(overlay, appearance)
	var shared_ids: Array = []
	for name in ["_title", "_details", "_caption", "_summary_scroll", "_skip", "_continue", "_avatar_view", "_vehicle_view", "_avatar_clip", "_entrance_back", "_entrance_front"]:
		shared_ids.append(overlay.get(name).get_instance_id())
	var child_count := overlay.get_child_count()
	for mode in MODES:
		var receipt := _receipt(mode)
		var frozen := var_to_bytes(receipt)
		overlay.present(receipt, false, false, 1.0, false, appearance)
		var view: Dictionary = overlay.snapshot()
		_expect(view["mode"] == mode and not view["static"] and view["has_art"], mode + " uses own moving presentation")
		_expect(view["title"] == "PLAYER'S APARTMENT  /  ACTUAL ARRIVAL" and view["destination_label"] == "Actual Arrival", mode + " freezes real venue names")
		_expect(view["duration_seconds"] == 8.0 and view["entrance_kind"] == "door", mode + " common duration/doorway contract")
		_expect(view["appearance"] == appearance and overlay.get_child_count() == child_count, mode + " preserves appearance and common nodes")
		var index := 0
		for name in ["_title", "_details", "_caption", "_summary_scroll", "_skip", "_continue", "_avatar_view", "_vehicle_view", "_avatar_clip", "_entrance_back", "_entrance_front"]:
			_expect(overlay.get(name).get_instance_id() == shared_ids[index], mode + " reuses " + name)
			index += 1
		var scene_profile: Dictionary = Catalog.profile(receipt)
		_expect(view["exterior_id"] == "motel" and view["background_path"] == scene_profile["background_path"], mode + " uses destination-specific motel exterior")
		_check_layered_windows(overlay, scene_profile, mode)
		var stopped: Dictionary = overlay.choreography_snapshot(2.15)
		_expect(stopped["vehicle_visible"] == (mode != "walk"), mode + " mode-correct vehicle visibility")
		_expect(stopped["player_visible"], mode + " visible canonical traveler")
		var walking: Dictionary = overlay.choreography_snapshot(5.35)
		_expect(walking["player_moving"] and not walking["vehicle_visible"], mode + " pedestrian approach after departure")
		seed(3421)
		var expected_random := randi()
		seed(3421)
		overlay.advance_presentation(2.15)
		if mode != "walk":
			var vehicle_plan: Dictionary = overlay.get("_vehicle_view").draw_snapshot()
			_expect(vehicle_plan.get("door_kind") == ("bus_fold" if mode == "bus" else "hinged") and vehicle_plan.get("door_panels", []).size() == (2 if mode == "bus" else 1) and vehicle_plan.get("door_active", false), mode + " opens actual mode-specific textured vehicle door")
		overlay.advance_presentation(6.95 - overlay.elapsed)
		_expect(randi() == expected_random, mode + " presentation does not consume global RNG")
		var entered: Dictionary = overlay.snapshot()
		var entry_state: Dictionary = entered["choreography"]
		var front_plan: Dictionary = entered["entrance_front"]
		var avatar: Control = overlay.get("_avatar_view")
		var clip: Control = overlay.get("_avatar_clip")
		var portal: Rect2 = front_plan.get("portal_rect", Rect2())
		_expect(entry_state["destination_door_open"] == 1.0 and entry_state["player_visible"] and entry_state["player_alpha"] == 1.0 and entered["entry_progress"] > 0.0 and entered["entry_progress"] < 1.0, mode + " visible traveler physically crosses open destination threshold")
		_expect(avatar.visible and avatar.modulate.a == 1.0 and entered["avatar_pose"]["pose"] == "walk_away" and clip.clip_contents and portal.has_area() and clip.size.is_equal_approx(portal.size), mode + " actual avatar enters clipped architectural aperture")
		_expect(front_plan.get("player_inside", false) and front_plan.get("front_layer", false) and not front_plan.get("panels", []).is_empty() and not front_plan.get("frame_strips", []).is_empty(), mode + " actual textured door and jamb render in front of entering traveler")
		overlay.advance_presentation(7.575 - overlay.elapsed)
		var closing: Dictionary = overlay.snapshot()
		_expect(closing["choreography"]["player_visible"] and avatar.visible and avatar.modulate.a == 1.0 and closing["entrance_front"]["opening"] > 0.0 and closing["entrance_front"]["opening"] < 1.0, mode + " closing leaf covers traveler without fading")
		overlay.advance_presentation(7.90 - overlay.elapsed)
		var closed: Dictionary = overlay.snapshot()
		_expect(not avatar.visible and not closed["choreography"]["player_visible"] and closed["entrance_front"]["opening"] == 0.0 and not closed["entrance_front"]["panels"].is_empty(), mode + " traveler retires only behind fully restored destination door")
		overlay.skip_to_receipt()
		_expect(overlay.snapshot()["receipt_text"] == receipt["receipt_text"] and not overlay.snapshot()["narration_visible"] and overlay.snapshot()["caption"].is_empty() and is_equal_approx(float(overlay.snapshot()["arrival_progress"]), 1.0), mode + " preserves committed summary and completed progress without narration")
		overlay.acknowledge()
		for seconds in [0.0, 0.7, 1.6, 2.15, 3.60, 5.15, 6.15, 6.4, 6.95, 7.575, 7.95, 8.0]:
			var before := completions
			overlay.present(receipt)
			overlay.advance_presentation(seconds)
			overlay.skip_to_receipt()
			overlay.skip_to_receipt()
			_expect(overlay.phase == "receipt" and overlay.active, mode + " immediate skip at " + str(seconds))
			overlay.acknowledge()
			overlay.acknowledge()
			_expect(completions == before + 1 and not overlay.active, mode + " exactly-once acknowledgment")
		overlay.present(receipt, true)
		_expect(overlay.phase == "receipt" and overlay.snapshot()["static"], mode + " reduced motion")
		overlay.present(receipt, false, false, 1.0, true)
		_expect(overlay.phase == "receipt", mode + " pending receipt reload never replays scene")
		var incident := receipt.duplicate(true)
		incident["route_risk"]["triggered"] = true
		overlay.present(incident)
		_expect(overlay.phase == "receipt" and overlay.snapshot()["static"], mode + " existing incident is not a routine variant")
		overlay.force_missing_art_for_test = true
		overlay.present(receipt)
		_expect(overlay.phase == "receipt" and not overlay.snapshot()["has_art"], mode + " missing art fallback")
		overlay.force_missing_art_for_test = false
		_expect(var_to_bytes(receipt) == frozen and var_to_bytes(appearance) == appearance_bytes, mode + " detached inputs remain immutable")
	var outdoor_kinds := {"back_alley":"passage", "beach":"open", "delta_queen":"dock"}
	for destination in outdoor_kinds:
		for mode in MODES:
			overlay.present(_receipt(mode, destination))
			overlay.advance_presentation(6.95)
			var away: Dictionary = overlay.snapshot()
			_expect(away["choreography"]["player_facing_away"] and away["choreography"]["player_moving"] and away["avatar_pose"]["pose"] == "walk_away" and away["choreography"]["player_alpha"] == 1.0 and away["choreography"]["player_scale"] < 1.0, mode + " outdoor traveler visibly walks away into setting: " + destination)
			overlay.advance_presentation(7.95 - overlay.elapsed)
			var view: Dictionary = overlay.snapshot()
			_expect(not view["static"] and view["exterior_id"] == destination and view["entrance_kind"] == outdoor_kinds[destination] and view["choreography"]["destination_door_open"] == 0.0 and view["caption"].is_empty() and not view["narration_visible"], mode + " preserves exact open/passage/dock destination kind: " + destination)
			_expect(view["choreography"]["player_visible"] and view["choreography"]["player_alpha"] == 1.0 and is_equal_approx(float(view["choreography"]["player_scale"]), float(Catalog.profile(_receipt(mode, destination))["motion"].get("walkaway_end_scale", 0.58))) and view["avatar_pose"]["pose"] == "away_idle" and overlay.get("_avatar_view").visible and not overlay.get("_entrance_front").visible and view["entrance_front"].is_empty(), mode + " outdoor traveler remains visible without fabricated door: " + destination)
	for destination in ["unknown_future_place", ""]:
		for mode in MODES:
			overlay.present(_receipt(mode, destination))
			var view: Dictionary = overlay.snapshot()
			_expect(view["static"] and overlay.phase == "receipt" and not view["has_art"] and view["background_path"].is_empty(), mode + " missing or unknown exterior goes straight to summary without false bar: " + destination)

	overlay.present(_receipt("night_cab"))
	_expect(not overlay.get("_stage_tint").visible and overlay.snapshot()["mode"] == "night_cab", "daylight night cab keeps canonical mode without forcing night")
	var night_walk := _receipt("walk")
	night_walk["departed_game_clock_minutes"] = 1300
	overlay.present(night_walk)
	_expect(overlay.get("_stage_tint").visible and overlay.snapshot()["mode"] == "walk", "departure-time tint independent of mode")
	overlay.cancel()
	overlay.free()
	print(JSON.stringify({"suite":"standard_travel_overlay", "checks":checks, "passed":failures.is_empty(), "failures":failures}))
	quit(0 if failures.is_empty() else 1)


func _check_shader_contract(overlay: Control) -> void:
	var main_material: ShaderMaterial = overlay.get("_cutout_material")
	var vehicle_material: ShaderMaterial = overlay.get("_vehicle_material")
	_expect(main_material.shader.resource_path == "res://scripts/ui/travel_scene_cutout.gdshader" and vehicle_material.shader == main_material.shader, "main, door and vehicle share the reviewed cutout shader")
	_expect(is_equal_approx(float(main_material.get_shader_parameter("solid_alpha_threshold")), 0.80), "painted facade threshold is 0.80")
	for name in ["_main_scene_view", "_entrance_back", "_entrance_front"]:
		_expect(overlay.get(name).material == main_material, name + " uses the facade opacity contract")
	_expect(overlay.get("_vehicle_view").material == vehicle_material and overlay.get("_main_scene_view").get_index() < overlay.get("_vehicle_view").get_index(), "detailed vehicle draws over the integrated main scene with its own opacity contract")


func _check_shader_pixels(overlay: Control) -> void:
	_expect(DisplayServer.get_name() != "headless", "shader pixel proof runs on the actual graphical renderer")
	if DisplayServer.get_name() == "headless": return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(160, 40)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(160, 40)
	background.color = Color(0.05, 0.15, 0.85, 1.0)
	viewport.add_child(background)
	var pixels := Image.create(8, 1, false, Image.FORMAT_RGBA8)
	var alphas := [0, 1, 2, 3, 200, 220, 249, 255]
	for index in range(alphas.size()): pixels.set_pixel(index, 0, Color(0.8, 0.2, 0.1, float(alphas[index]) / 255.0))
	var texture := ImageTexture.create_from_image(pixels)
	var painted := TextureRect.new()
	painted.texture = texture
	painted.size = Vector2(160, 40)
	painted.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	painted.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	viewport.add_child(painted)
	for field in ["_cutout_material", "_vehicle_material"]:
		painted.material = overlay.get(field)
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered := viewport.get_texture().get_image()
		var empty := rendered.get_pixel(10, 20)
		var solid := rendered.get_pixel(150, 20)
		_expect(_color_distance(empty, background.color) < 0.02 and _color_distance(solid, Color(0.8, 0.2, 0.1, 1.0)) < 0.02, field + " preserves backdrop and opaque texture RGB without extra tint multiplication")
		_expect(_color_distance(rendered.get_pixel(30, 20), empty) < 0.01 and _color_distance(rendered.get_pixel(50, 20), empty) < 0.01, field + " removes only near-zero alpha spill")
		_expect(_color_distance(rendered.get_pixel(130, 20), solid) < 0.01, field + " promotes alpha249 painted pixels to truly opaque")
		var mid := rendered.get_pixel(110, 20)
		_expect(_color_distance(mid, solid) < 0.01 if field == "_cutout_material" else _color_distance(mid, solid) > 0.03, field + " uses its distinct 0.80 facade or 0.95 vehicle threshold")
		var edge := rendered.get_pixel(90, 20)
		_expect(_color_distance(edge, empty) > 0.05 and _color_distance(edge, solid) > 0.05, field + " preserves intentional partial-alpha antialiased edges")
	viewport.free()


func _color_distance(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


func _check_layered_windows(overlay: Control, profile: Dictionary, label: String) -> void:
	var reference: Array = profile["exterior"]["reference_size"]
	var view_height := 0.80 * float(reference[0]) / float(reference[1]) * 500.0 / 1152.0
	var top := 1.0 - view_height
	_expect(is_equal_approx(float(profile["source_width_uv"]), 0.80) and is_equal_approx(float(profile["view_height_uv"]), view_height) and is_equal_approx(float(profile["source_top_y_uv"]), top) and is_equal_approx(float(profile["view_bottom_uv"]), 1.0), label + " uses the same close crop with its bottom inside the PNG")
	_expect(profile.get("backdrop_path", "") != profile["main_scene_path"] and not str(profile.get("backdrop_path", "")).is_empty(), label + " has a separate distant backdrop")
	_expect(not profile.has("ground_path") and not profile.has("foreground_band_top_uv"), label + " has no generic ground atlas or foreground band")
	var stage: Rect2 = overlay.get("_stage")
	var design_scale := overlay.size / Vector2(1280.0, 720.0)
	_expect(stage.is_equal_approx(Rect2(Vector2(64, 116) * design_scale, Vector2(1152, 500) * design_scale)), label + " uses the production tall stage")
	_expect(not overlay.snapshot()["narration_visible"] and overlay.snapshot()["caption"].is_empty(), label + " no narration covers the scene")
	var previous_main := -1.0
	var previous_far := -1.0
	var previous_progress := -1.0
	for sample_index in range(81):
		var seconds := sample_index * 0.1
		var windows: Dictionary = overlay.layer_window_snapshot(seconds)
		var main: Rect2 = windows["main"]
		var far: Rect2 = windows["backdrop"]
		_expect(main.position.x > previous_main and far.position.x > previous_far and is_equal_approx(far.position.x, main.position.x * 0.35), label + " both layers continuously move with genuine distant parallax " + str(sample_index))
		_expect(Rect2(Vector2.ZERO, Vector2.ONE).encloses(main) and Rect2(Vector2.ZERO, Vector2.ONE).encloses(far), label + " neither layer samples outside its own PNG " + str(sample_index))
		_expect(is_equal_approx(main.size.x, 0.80) and is_equal_approx(main.size.y, view_height) and is_equal_approx(main.position.y, top), label + " main crop includes integrated facade and road " + str(sample_index))
		var pose: Dictionary = overlay.choreography_snapshot(seconds)
		var approach := 1.0 - pow(1.0 - minf(seconds / 1.45, 1.0), 3.0)
		var expected_main := 0.18 * 0.32 * approach + 0.18 * 0.68 * seconds / 8.0
		_expect(is_equal_approx(main.position.x, expected_main) and is_equal_approx(float(pose["camera_x_uv"]), main.position.x), label + " actors and architecture use one main camera " + str(sample_index))
		var progress: float = pose["arrival_progress"]
		_expect(progress >= previous_progress and progress >= 0.0 and progress <= 1.0, label + " actual arrival progress remains bounded and monotonic " + str(sample_index))
		previous_main = main.position.x
		previous_far = far.position.x
		previous_progress = progress


func _check_near_ground_staging(overlay: Control, appearance: Dictionary) -> void:
	for destination in Catalog.EXTERIOR_IDS:
		var frozen_crop := Rect2()
		var exterior_art: Dictionary = Catalog.exterior_contract(destination)
		var main_image := Image.load_from_file(str(exterior_art.get("texture", "")))
		var far_image := Image.load_from_file(str(exterior_art.get("backdrop_texture", "")))
		_expect(main_image != null and not main_image.is_empty() and main_image.detect_alpha() != Image.ALPHA_NONE, str(destination) + " main PNG retains actual alpha cutouts")
		_expect(far_image != null and not far_image.is_empty() and far_image.detect_alpha() == Image.ALPHA_NONE, str(destination) + " backdrop is an independent opaque image")
		if main_image != null and not main_image.is_empty():
			var transparent_sky := false
			var solid_road := true
			for x in range(0, main_image.get_width(), 31):
				for y in range(0, int(main_image.get_height() * 0.5), 31):
					transparent_sky = transparent_sky or main_image.get_pixel(x, y).a < 0.01
				for y in range(int(main_image.get_height() * 0.97), main_image.get_height(), 7):
					solid_road = solid_road and main_image.get_pixel(x, y).a >= 0.80
			_expect(transparent_sky and solid_road, str(destination) + " main scene has transparent upper background and integrated solid road")
		for mode in MODES:
			var receipt := _receipt(mode, destination)
			var profile: Dictionary = Catalog.profile(receipt)
			var exterior: Dictionary = profile["exterior"]
			var expected_scene_scale := 1.0
			var expected_avatar_height := 0.20
			if exterior["arrival_kind"] == "door":
				var top := 1.0
				var bottom := 0.0
				for point in exterior["door_polygon_uv"]:
					top = minf(top, float(point[1]))
					bottom = maxf(bottom, float(point[1]))
				expected_scene_scale = clampf((bottom - top) / 0.25, 1.0, 1.4)
				expected_avatar_height = minf(0.20 * expected_scene_scale, (bottom - top) * 0.82)
			var label: String = mode + " " + str(destination)
			_expect(is_equal_approx(float(profile["actor_scene_scale"]), expected_scene_scale) and is_equal_approx(float(profile["avatar_height_uv"]), expected_avatar_height), label + " restores the canonical adult screen height")
			overlay.present(receipt, false, false, 1.0, false, appearance)
			_check_layered_windows(overlay, profile, label)
			var crop: Rect2 = overlay.layer_window_snapshot(0.0)["main"]
			if mode == "walk": frozen_crop = crop
			_expect(crop.is_equal_approx(frozen_crop), label + " shares exactly the walking mode's architecture crop")
			var motion: Dictionary = profile["motion"]
			var curb: Vector2 = motion["player_curb_uv"]
			var road := float(exterior["road_y_uv"])
			_expect(road < 1.0 and is_equal_approx(curb.y, road), label + " feet use venue-specific integrated road pixels")
			if mode == "walk": continue
			var expected_width := (0.48 if mode == "bus" else 0.34) * expected_scene_scale
			var exit: Dictionary = overlay.choreography_snapshot(1.80)
			var lane: Dictionary = overlay.choreography_snapshot(2.50)
			_expect(is_equal_approx(float(motion["vehicle_width_uv"]), expected_width) and is_equal_approx(float(exit["vehicle_width_uv"]), expected_width), label + " restores the larger detailed vehicle scale")
			_expect(is_equal_approx(curb.y, float(exit["vehicle_road_y_uv"])), label + " near-side feet share the wheel baseline")
			var start: Vector2 = exit["player_position_uv"]
			_expect(start.y < curb.y and is_equal_approx(start.y, float(motion["vehicle_step_y_uv"])) and is_equal_approx(start.x, float(motion["vehicle_stop_left_uv"]) + expected_width * float(motion["vehicle_door_center_uv"])), label + " starts at the actual measured vehicle door")
			_expect(Vector2(lane["player_position_uv"]).is_equal_approx(curb), label + " reaches authored near-lane footing")
			var descends := true
			var previous_y := start.y
			for index in range(71):
				var state: Dictionary = overlay.choreography_snapshot(1.80 + float(index) / 100.0)
				var foot: Vector2 = state["player_position_uv"]
				descends = descends and foot.y >= previous_y - 0.00001 and foot.y <= curb.y + 0.00001 and state["player_visible"] and state["player_alpha"] == 1.0 and is_equal_approx(float(state["player_scale"]), 1.0)
				previous_y = foot.y
			_expect(descends, label + " steps down without fade, size growth or a pasted foreground")
			var stage: Rect2 = overlay.get("_stage")
			var avatar: Control = overlay.get("_avatar_view")
			var clip: Control = overlay.get("_avatar_clip")
			var height_at_exit := 0.0
			for seconds in [1.80, 2.15, 2.50, 6.15]:
				overlay.advance_presentation(seconds - overlay.elapsed)
				var state: Dictionary = overlay.snapshot()["choreography"]
				var foot: Vector2 = state["player_position_uv"]
				var expected_foot := stage.position + Vector2((foot.x - float(state["camera_x_uv"])) / 0.80 * stage.size.x, (foot.y - float(profile["source_top_y_uv"])) / float(profile["view_height_uv"]) * stage.size.y)
				var rendered_foot := clip.position + avatar.position + Vector2(avatar.size.x * 0.5, avatar.size.y)
				_expect(rendered_foot.is_equal_approx(expected_foot) and rendered_foot.y <= stage.end.y and avatar.visible and avatar.modulate.a == 1.0, label + " actual avatar foot tracks the common main camera at " + str(seconds))
				if seconds == 1.80: height_at_exit = avatar.size.y
				var expected_scale := float(motion.get("walkaway_start_scale", 1.0)) if seconds == 6.15 and bool(motion.get("walkaway_scale_during_approach", false)) else 1.0
				_expect(is_equal_approx(avatar.size.y, height_at_exit * expected_scale), label + " rendered canonical actor height follows its authored perspective at " + str(seconds))
			_expect(overlay.snapshot()["appearance"] == appearance, label + " staging never changes frozen character identity")
