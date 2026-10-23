extends SceneTree

const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")
const BlackjackGameScript := preload("res://scripts/games/blackjack.gd")
const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var environment_canvas: Control = PixelSceneCanvasScript.new()
	environment_canvas.size = Vector2(VisualStyleScript.ENVIRONMENT_BOARD_SIZE)
	root.add_child(environment_canvas)
	await process_frame
	environment_canvas.process_mode = Node.PROCESS_MODE_DISABLED
	environment_canvas.set_process(false)
	environment_canvas.call("render_environment_snapshot", {
		"id": "animation_liveness_environment",
		"display_name": "Animation Liveness Environment",
		"reduce_motion": false,
		"interactable_objects": [],
	})
	environment_canvas.call("set_developer_slot_placement_mode", true)
	environment_canvas.call("reset_performance_counters")
	var environment_start: Dictionary = environment_canvas.call("current_view_snapshot")
	for _frame_index in range(24):
		await process_frame
	var environment_end: Dictionary = environment_canvas.call("current_view_snapshot")
	if environment_canvas.process_mode != Node.PROCESS_MODE_PAUSABLE \
			or not environment_canvas.is_processing() \
			or not bool(environment_end.get("scene_idle_animation_active", false)) \
			or float(environment_end.get("scene_animation_time", 0.0)) <= float(environment_start.get("scene_animation_time", 0.0)) \
			or int(environment_end.get("scene_idle_animation_redraw_count", 0)) <= int(environment_start.get("scene_idle_animation_redraw_count", 0)):
		push_error("Environment animation stopped without pointer input while slot placement was active.")
		quit(1)
		return

	var game_canvas: Control = GameSurfaceCanvasScript.new()
	game_canvas.size = Vector2(VisualStyleScript.GAME_BOARD_SIZE)
	root.add_child(game_canvas)
	await process_frame
	var blackjack = BlackjackGameScript.new()
	game_canvas.call("set_game_module", blackjack)
	game_canvas.process_mode = Node.PROCESS_MODE_DISABLED
	game_canvas.set_process(false)
	game_canvas.call("render_game_snapshot", {
		"game_id": "animation_liveness_game",
		"surface_renderer": "blackjack",
		"surface_renderer_opaque": true,
		"surface_animates_idle": true,
		"surface_native_low_detail_idle": true,
		"surface_native_idle_animation_fps": 15.0,
		"phase": "betting",
		"between_hands": true,
		"dealer_name": "Liveness Dealer",
		"dealer_profile": {"blink_offset": 0},
		"patrons": [{"name": "Liveness Patron", "animation_offset": 320, "watching_player": false}],
		"reduce_motion": false,
	})
	game_canvas.call("reset_performance_counters")
	var game_start: Dictionary = game_canvas.call("current_view_snapshot")
	var cast_start: Dictionary = game_canvas.call("debug_surface_motion_sample")
	for _frame_index in range(24):
		await process_frame
	var game_end: Dictionary = game_canvas.call("current_view_snapshot")
	var cast_end: Dictionary = game_canvas.call("debug_surface_motion_sample")
	if game_canvas.process_mode != Node.PROCESS_MODE_PAUSABLE \
			or not game_canvas.is_processing() \
			or not bool(game_end.get("surface_animation_liveness_active", false)) \
			or int(game_end.get("surface_animation_redraw_count", 0)) <= int(game_start.get("surface_animation_redraw_count", 0)):
		push_error("Game-surface animation stopped without pointer input.")
		quit(1)
		return
	if not bool(game_canvas.call("surface_low_detail_idle")):
		push_error("Blackjack between-hand liveness no longer preserves its measured low-detail redraw cadence.")
		quit(1)
		return
	if not is_equal_approx(float(game_canvas.call("surface_idle_animation_fps")), 15.0):
		push_error("Blackjack between-hand liveness no longer uses its 15 FPS native idle cadence.")
		quit(1)
		return
	if not bool(cast_start.get("between_hand_cast_active", false)) \
			or JSON.stringify(cast_start.get("dealer_motion", [])) == JSON.stringify(cast_end.get("dealer_motion", [])) \
			or JSON.stringify(cast_start.get("patron_motion", [])) == JSON.stringify(cast_end.get("patron_motion", [])):
		push_error("Blackjack dealer or patron motion did not advance autonomously between hands.")
		quit(1)
		return

	print("Animation liveness without pointer input: PASS")
	quit(0)
