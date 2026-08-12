extends SceneTree

# End-to-end regression for the slot reel -> pinball jackpot handoff. This uses
# the production FoundationMain, GameSurfaceCanvas, realtime refresh, drawing,
# hit testing, and action routing instead of inspecting a renderer dictionary.

const MainScene := preload("res://scenes/main.tscn")
const SlotState := preload("res://scripts/games/slots/slot_machine_state.gd")
const SlotResolver := preload("res://scripts/games/slots/slot_resolver.gd")
const SlotMachineGenerator := preload("res://scripts/games/slots/slot_machine_generator.gd")

const CAPTURE_SIZE := Vector2i(1280, 720)
const OUTPUT_DIR := "res://review_artifacts/pinball_jackpot_gameplay"
const SAVE_SLOT := "slot_pinball_gameplay_probe"

var app: Control
var failures: Array[String] = []
var trigger_spin_attempts := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.max_fps = 60
	root.size = CAPTURE_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	app = MainScene.instantiate()
	app.set("show_game_library_launcher", true)
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", SAVE_SLOT)
	root.add_child(app)
	await _settle(6)
	app.call("start_game_test_session", "slot")
	await _settle(8)

	var run_state: RunState = app.get("run_state")
	var environment: Dictionary = run_state.current_environment
	var slot_game: GameModule = app.get("current_game")
	var machine: Dictionary = slot_game.call("_read_machine", environment)
	if machine.is_empty():
		_fail("The production game-test route did not create the slot machine.")
		_finish()
		return
	var definition: Dictionary = (app.get("library") as ContentLibrary).game("slot")
	var generator = SlotMachineGenerator.new()
	machine = generator.build_machine_from_ids(definition, {
		"format_id": "video_feature",
		"type_id": "pinball",
		"math_variant_id": "standard",
		"bonus_variant_id": "jackpot_chase",
		"cabinet_variant_id": "blacklight",
	}, run_state.create_rng("gameplay_probe_machine"))
	var resolver = SlotResolver.new()
	var trigger_rng := run_state.create_rng("gameplay_probe_real_jackpot")
	for attempt in range(1, 2001):
		var resolved: Dictionary = resolver.resolve_spin(
			machine,
			"spin",
			SlotState.selected_bet(machine),
			trigger_rng,
			definition,
			environment,
			true,
			false,
			run_state,
			{},
			{},
			true
		)
		machine = resolved.get("machine", machine) as Dictionary
		var active: Dictionary = machine.get("active_bonus", {}) if typeof(machine.get("active_bonus", {})) == TYPE_DICTIONARY else {}
		if str(active.get("family", "")) == "pinball" and bool(active.get("active", false)) and not bool(active.get("complete", false)):
			trigger_spin_attempts = attempt
			break
	if trigger_spin_attempts <= 0:
		_fail("A real pinball jackpot did not trigger within 2,000 resolved production spins.")
		_finish()
		return
	machine["slot_pending_feature_alert"] = true
	machine["slot_pending_feature_alert_msec"] = int(app.call("_environment_simulation_time_msec"))
	slot_game.call("_write_owned_machine", environment, machine)
	app.call("_refresh_after_embedded_game_action")
	await _settle(3)
	_print_stage("trigger")
	var trigger_canvas: GameSurfaceCanvas = app.get("game_surface_canvas")
	var trigger_state := trigger_canvas.realtime_surface_state()
	if not bool(trigger_state.get("slot_bonus_trigger_reveal_pending", false)) or bool(trigger_state.get("slot_active_bonus_active", true)):
		_fail("The real jackpot skipped its triggering reels before the authored reveal beat.")
	await _capture("01_trigger_reels.png")

	# Cross the authored reveal beat through the normal realtime refresh loop.
	var reveal_wait_frames := 0
	while reveal_wait_frames < 300 and not bool(trigger_canvas.realtime_surface_state().get("slot_active_bonus_active", false)):
		reveal_wait_frames += 1
		await process_frame
	_print_stage("takeover")
	await _capture("02_pinball_launch.png")

	var canvas: GameSurfaceCanvas = app.get("game_surface_canvas")
	var launch_position := canvas.local_position_for_surface_action("slot_bonus_launch", 0)
	var launch_rect := canvas.global_rect_for_surface_action("slot_bonus_launch", 0)
	var canvas_rect := canvas.get_global_rect()
	var board_rect := canvas.board_rect()
	var takeover_state := canvas.realtime_surface_state()
	if not bool(takeover_state.get("slot_active_bonus_active", false)):
		_fail("The live canvas never entered the pinball takeover.")
	if launch_position.x < 0.0 or launch_position.y < 0.0 or not launch_rect.has_area():
		_fail("The live canvas did not build a clickable Launch hit region.")
	if not Rect2(Vector2.ZERO, canvas.size).has_point(launch_position):
		_fail("The Launch hit region was outside the visible game canvas: %s." % str(launch_position))
	var expected_board_size := Vector2(960.0, 540.0) * minf(canvas.size.x / 960.0, canvas.size.y / 540.0)
	if board_rect.size.distance_to(expected_board_size) > 1.0:
		_fail("The pinball board collapsed toward the top-left instead of filling the game canvas: canvas=%s board=%s." % [str(canvas.size), str(board_rect)])
	var round_trip := RunState.new()
	round_trip.from_dict(run_state.to_dict())
	var restored_machine := SlotState.peek_machine(round_trip.current_environment, "slot")
	if not bool(restored_machine.get("slot_bonus_trigger_revealed", false)):
		_fail("The committed pinball reveal was lost across a run-state save/load round trip.")

	var before := SlotState.read_machine(environment, "slot")
	var before_active: Dictionary = before.get("active_bonus", {}) if typeof(before.get("active_bonus", {})) == TYPE_DICTIONARY else {}
	if launch_position.x >= 0.0 and launch_position.y >= 0.0:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = launch_position
		canvas.call("_gui_input", click)
		await _settle(5)
	var after := SlotState.read_machine(environment, "slot")
	var after_active: Dictionary = after.get("active_bonus", {}) if typeof(after.get("active_bonus", {})) == TYPE_DICTIONARY else {}
	if bool(before_active.get("launch_in_progress", false)):
		_fail("The pre-click pinball fixture was already in play.")
	if not bool(after_active.get("launch_in_progress", false)) and int(after_active.get("launched_ball_count", 0)) <= 0:
		_fail("Clicking the visible Launch control did not launch a pinball through the production action route.")
	await _capture("03_pinball_in_play.png")

	var report := {
		"passed": failures.is_empty(),
		"failures": failures,
		"real_jackpot_spin_attempts": trigger_spin_attempts,
		"reveal_wait_frames": reveal_wait_frames,
		"canvas_rect": _rect_payload(canvas_rect),
		"canvas_size": _vector_payload(canvas.size),
		"board_rect": _rect_payload(board_rect),
		"launch_local_position": _vector_payload(launch_position),
		"launch_global_rect": _rect_payload(launch_rect),
		"takeover_active": bool(takeover_state.get("slot_active_bonus_active", false)),
		"launch_in_progress_after_click": bool(after_active.get("launch_in_progress", false)),
		"launched_ball_count_after_click": int(after_active.get("launched_ball_count", 0)),
	}
	print("PINBALL_GAMEPLAY_PROBE %s" % JSON.stringify(report))
	_finish()


func _capture(file_name: String) -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		return
	var viewport_texture := root.get_viewport().get_texture()
	if viewport_texture == null:
		return
	var image := viewport_texture.get_image()
	if image == null:
		return
	if image.get_size() != CAPTURE_SIZE:
		image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_NEAREST)
	var error := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	if error != OK:
		_fail("Could not save %s (error %d)." % [file_name, error])


func _settle(frame_count: int) -> void:
	for _index in range(frame_count):
		await process_frame


func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)


func _print_stage(label: String) -> void:
	var canvas: GameSurfaceCanvas = app.get("game_surface_canvas")
	var runtime := canvas.surface_runtime_status()
	var rendered := canvas.realtime_surface_state()
	var run_state: RunState = app.get("run_state")
	var machine := SlotState.peek_machine(run_state.current_environment, "slot")
	print("PINBALL_GAMEPLAY_STAGE %s" % JSON.stringify({
		"label": label,
		"screen": str(app.get("current_screen")),
		"paused": bool(app.call("_simulation_progression_paused")),
		"refresh_enabled": canvas.surface_realtime_state_refresh_enabled(),
		"runtime_animations": runtime.get("surface_animations", {}),
		"rendered_animation_id": str(rendered.get("slot_animation_id", "")),
		"rendered_trigger_pending": bool(rendered.get("slot_bonus_trigger_reveal_pending", false)),
		"rendered_bonus_active": bool(rendered.get("slot_active_bonus_active", false)),
		"machine_trigger_revealed": bool(machine.get("slot_bonus_trigger_revealed", false)),
		"machine_active_family": str((machine.get("active_bonus", {}) as Dictionary).get("family", "")) if typeof(machine.get("active_bonus", {})) == TYPE_DICTIONARY else "",
		"environment_time_msec": int(app.call("_environment_simulation_time_msec")),
	}))


func _finish() -> void:
	quit(0 if failures.is_empty() else 1)


func _vector_payload(value: Vector2) -> Dictionary:
	return {"x": snappedf(value.x, 0.01), "y": snappedf(value.y, 0.01)}


func _rect_payload(value: Rect2) -> Dictionary:
	return {
		"x": snappedf(value.position.x, 0.01),
		"y": snappedf(value.position.y, 0.01),
		"w": snappedf(value.size.x, 0.01),
		"h": snappedf(value.size.y, 0.01),
	}
