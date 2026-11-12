extends SceneTree

# Layered capture: one authored facade/road plus an independent distant backdrop.

# VISUAL PREVIEW ONLY. This harness renders the production Overlay, Catalog,
# Timeline, vehicle doors, entrance and canonical avatar. It never invokes a
# travel route or creates a committed journey. A generated Environment Library
# practice room supplies its real current display name and player appearance.
# Fixed-FPS graphical playback advances the production node naturally at 30fps.
# Movie Maker is optional; rendered PNGs and frame receipts are always captured.
# --destination=<canonical id> captures that destination's four method previews.
# --mode=<canonical method> optionally selects a single smoke-preview case.
# --review-destinations=<comma-separated ids> changes the numbered review set.
# --review-modes=<comma-separated modes> controls review order, not legal routes.
# Omitting both preserves the complete 15-destination, 60-case catalog ordering.
const Overlay := preload("res://scripts/ui/travel_cinematic_overlay.gd")
const Catalog := preload("res://scripts/ui/travel_presentation_catalog.gd")
const Timeline := preload("res://scripts/ui/travel_arrival_timeline.gd")
const Appearance := preload("res://scripts/ui/character_appearance_snapshot.gd")
const Library := preload("res://scripts/core/content_library.gd")
const Generator := preload("res://scripts/core/run_generator.gd")
const World := preload("res://scripts/core/world_map.gd")
const Run := preload("res://scripts/core/run_state.gd")
const FPS := 30
const ARRIVAL_HOLD_SECONDS := 1.0
const SAMPLE_FRAMES := [2, 20, 52, 60, 75, 80, 100, 110, 145, 176, 179, 182, 184, 186, 190, 196, 198, 200, 202, 207, 225, 235, 255]
var failures: Array[String] = []
var checks := 0
var completed := 0
var overlay: Control
var report: Dictionary = {}
var evidence := ""


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func _run() -> void:
	evidence = OS.get_environment("BTH_QA_EVIDENCE_DIR")
	_expect(evidence.replace("\\", "/").begins_with("E:/CodexQA/BTH/"), "preview outputs use admitted E: evidence")
	# Reserved --write-movie is stripped from script argv by Godot. The guard
	# command, Movie Maker engine log and movie output independently prove it.
	_expect(DisplayServer.get_name() != "headless", "preview requires the real graphical renderer")
	var destination := ""
	var requested_mode := ""
	var review_destinations: Array = Catalog.EXTERIOR_IDS.duplicate()
	var review_modes: Array = Catalog.MODES.duplicate()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--destination="): destination = argument.trim_prefix("--destination=")
		if argument.begins_with("--mode="): requested_mode = argument.trim_prefix("--mode=")
		if argument.begins_with("--review-destinations="): review_destinations = Array(argument.trim_prefix("--review-destinations=").split(",", false))
		if argument.begins_with("--review-modes="): review_modes = Array(argument.trim_prefix("--review-modes=").split(",", false))
	_expect(destination in Catalog.EXTERIOR_IDS, "preview destination is an actual canonical exterior")
	_expect(requested_mode.is_empty() or requested_mode in Catalog.MODES, "preview method is canonical")
	_expect(not review_destinations.is_empty() and destination in review_destinations, "captured destination belongs to the selected review set")
	_expect(not review_modes.is_empty() and (requested_mode.is_empty() or requested_mode in review_modes), "captured mode belongs to the selected review order")
	var seen_destinations: Dictionary = {}
	for id in review_destinations:
		_expect(id in Catalog.EXTERIOR_IDS and not seen_destinations.has(id), "review destinations are canonical and unique")
		seen_destinations[id] = true
	var seen_modes: Dictionary = {}
	for id in review_modes:
		_expect(id in Catalog.MODES and not seen_modes.has(id), "review methods are canonical and unique")
		seen_modes[id] = true
	var review_case_count := review_destinations.size() * review_modes.size()
	_expect(is_equal_approx(float(Timeline.DURATION_SECONDS), 8.0), "preview captures the approved eight-second production sequence")
	if not failures.is_empty():
		_finish()
		return
	var library := Library.new()
	library.load()
	_expect(library.validation_errors.is_empty(), "production content library validates")
	var practice := Run.new()
	var generation_seed := "ENVIRONMENT-PRACTICE-v1:TRAVEL-CATALOG-PREVIEW:" + destination
	practice.start_new(generation_seed, Run.custom_challenge("environment_practice", generation_seed, {"environment_practice":true}))
	var request := {"archetype_id":destination, "scenario_id":"__none", "generation_key":"travel-catalog-preview:" + destination}
	if destination == "small_underground_casino": request["layer_id"] = "club"
	var generated: Dictionary = Generator.new(library).environment_test_result(practice, request)
	_expect(bool(generated.get("ok", false)), "production Environment Library practice generation supplies the destination name")
	var destination_label := str(practice.current_environment.get("display_name", ""))
	_expect(not destination_label.is_empty(), "preview displays the actual generated destination name")
	if not failures.is_empty():
		_finish()
		return
	var appearance := Appearance.normalized(Appearance.from_run(practice, library))
	var immutable_practice := JSON.stringify(practice.to_dict())
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	overlay = Overlay.new()
	root.add_child(overlay)
	overlay.completed.connect(func(_id: String): completed += 1)
	for _warmup in range(15): await process_frame
	var cases: Array = []
	var case_frames := int(round((float(Timeline.DURATION_SECONDS) + ARRIVAL_HOLD_SECONDS) * FPS))
	var modes: Array = review_modes if requested_mode.is_empty() else [requested_mode]
	for mode_value in modes:
		var mode := str(mode_value)
		var case_number := review_destinations.find(destination) * review_modes.size() + review_modes.find(mode) + 1
		var method_label := World.travel_method_label(mode)
		# Detached presentation metadata deliberately omits fare, game minutes,
		# route availability and any commit. Only the Catalog selection is real.
		var presentation := {"presentation_key":Catalog.STANDARD_KEY, "journey_id":"visual-preview-%02d" % case_number,
			"travel_method_kind":mode, "travel_method_label":method_label, "origin_label":"Visual preview",
			"effective_destination_archetype_id":destination, "destination_label":destination_label,
			"receipt_text":"Visual preview only. No route, fare, game time or availability is implied."}
		var movie_start := Engine.get_frames_drawn()
		var before_completion := completed
		overlay.present(presentation, false, false, 1.0, false, appearance)
		# These are the production controls. Replace only preview identification,
		# never any scene geometry, renderer, pose, animation clock or draw path.
		overlay.get("_title").text = "%02d / %02d   %s" % [case_number, review_case_count, destination_label.to_upper()]
		overlay.get("_details").text = "VISUAL PREVIEW ONLY   |   " + method_label + "   |   No gameplay route or fare implied"
		overlay.get("_continue").text = "Next visual preview"
		var initial: Dictionary = overlay.snapshot()
		_expect(bool(initial.get("has_art", false)) and not bool(initial.get("static", true)), "preview uses loaded production art and natural animation")
		_expect(initial.get("exterior_id") == destination and initial.get("mode") == mode and initial.get("destination_label") == destination_label, "exact destination and method select the production scene")
		_expect(initial.get("appearance") == appearance, "preview uses the canonical game player appearance")
		_expect(initial.get("stage_rect") == Rect2(64, 116, 1152, 500) and not bool(initial.get("narration_visible", true)), "full-size production stage has no narration caption")
		_expect(not presentation.has("base_minutes") and not presentation.has("quoted_departure_fare") and not presentation.has("commit_status"), "preview metadata cannot be mistaken for a settled journey")
		if mode != "walk":
			var scene: Dictionary = Catalog.profile(presentation)
			var road := float(scene["exterior"]["road_y_uv"])
			var step: Dictionary = overlay.choreography_snapshot(1.80)
			var curb: Dictionary = overlay.choreography_snapshot(2.60)
			var foot: Vector2 = curb.get("player_position_uv", Vector2.ZERO)
			var door_x := float(curb.get("vehicle_left_uv", 0)) + float(curb.get("vehicle_width_uv", 0)) * float(curb.get("vehicle_door_center_uv", 0))
			_expect(road < 1.0 and is_equal_approx(foot.y, road) and is_equal_approx(foot.y, float(curb.get("vehicle_road_y_uv", 0))), "preview player is grounded on the venue's integrated road at the near wheel baseline")
			_expect(is_equal_approx(foot.x, door_x + 0.04), "preview dropoff stays aligned to the actual vehicle door")
			_expect(float(step.get("player_position_uv", Vector2.ZERO).y) < foot.y and is_equal_approx(float(step.get("player_scale", 0)), 1.0) and is_equal_approx(float(curb.get("player_scale", 0)), 1.0), "preview steps down toward the viewer without changing adult height")
		if not failures.is_empty(): break
		seed(97531)
		var next_random := randi()
		seed(97531)
		var samples: Array = []
		var previous_elapsed := 0.0
		for frame in range(case_frames):
			await process_frame
			_expect(float(overlay.get("elapsed")) >= previous_elapsed, "production preview time advances monotonically")
			_expect(absf(float(overlay.get("elapsed")) - minf(float(Timeline.DURATION_SECONDS), float(frame + 1) / FPS)) <= 1.1 / FPS, "natural30fps playback cannot skip or jump the production animation")
			previous_elapsed = float(overlay.get("elapsed"))
			if frame in SAMPLE_FRAMES:
				await RenderingServer.frame_post_draw
				var snapshot: Dictionary = overlay.snapshot()
				var path := evidence.path_join("preview_%02d_%s_%s_f%03d.png" % [case_number, destination, mode, frame])
				_expect(root.get_texture().get_image().save_png(path) == OK, "native rendered preview frame is saved")
				samples.append({"case_frame":frame, "drawn_frame":Engine.get_frames_drawn(), "path":path, "snapshot":snapshot})
		_expect(randi() == next_random, "production preview consumes no global RNG")
		_expect(JSON.stringify(practice.to_dict()) == immutable_practice, "visual preview leaves its practice state unchanged")
		_expect(not overlay.get("active") and is_equal_approx(float(overlay.get("elapsed")), float(Timeline.DURATION_SECONDS)), "natural fixed-FPS graphical playback completes automatically")
		overlay.acknowledge()
		overlay.acknowledge()
		_expect(completed == before_completion + 1, "preview acknowledgment completes once")
		cases.append({"case_number":case_number, "destination":destination, "destination_label":destination_label,
			"mode":mode, "method_label":method_label, "visual_preview_only":true,
			"movie_start_frame":movie_start, "movie_end_frame":Engine.get_frames_drawn(), "frame_count":case_frames,
			"duration_seconds":float(case_frames) / FPS, "production_duration_seconds":Timeline.DURATION_SECONDS,
			"initial_snapshot":initial, "samples":samples})
		if not failures.is_empty(): break
	report = {"suite":"travel_catalog_visual_preview", "destination":destination, "destination_label":destination_label,
		"review_destinations":review_destinations, "review_modes":review_modes, "review_case_count":review_case_count,
		"visual_preview_only":true, "gameplay_routes_submitted":0, "committed_journeys":0,
		"display_name_source":"RunGenerator.environment_test_result / current_environment.display_name",
		"generation_seed":generation_seed, "appearance":appearance, "fps":FPS, "width":1280, "height":720,
		"case_frames":case_frames, "cases":cases}
	_finish()


func _finish() -> void:
	report["checks"] = checks
	report["passed"] = failures.is_empty()
	report["failures"] = failures
	if evidence.replace("\\", "/").begins_with("E:/CodexQA/BTH/"):
		var file := FileAccess.open(evidence.path_join("preview_manifest.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	print(JSON.stringify(report))
	if is_instance_valid(overlay): overlay.free()
	quit(0 if failures.is_empty() else 1)
