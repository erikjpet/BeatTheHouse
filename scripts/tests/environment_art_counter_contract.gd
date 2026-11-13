extends SceneTree
const PackScript := preload("res://scripts/ui/environment_art_pack.gd")
const CanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
var checks := 0
var failures: Array[String] = []
var out_dir := ""


class OrderCanvas:
	extends CanvasScript
	var calls: Array[String] = []
	var front := {"foreground_art_id": "gas_station_staff_window", "x0": 532, "x1": 636, "top_y": 80, "front_y": 88}
	var first_result := false
	var replay_result := false
	var replay_enabled := false

	func _draw() -> void:
		calls.clear()
		super._draw()

	func _draw_environment_art_animations(pack: EnvironmentArtPack) -> void:
		calls.append("background_animation")
		super._draw_environment_art_animations(pack)

	func _draw_authored_counter_foregrounds() -> void:
		calls.append("counters")
		first_result = _draw_counter_foreground_art(front)

	func _draw_scenario_palette() -> void:
		calls.append("scenario")
		draw_rect(Rect2(0, 0, 900, 430), Color(0, 0, 1, 0.12))

	func _draw_scene_objects() -> void:
		calls.append("person")
		draw_rect(Rect2(538, 74, 4, 22), Color.MAGENTA)
		calls.append("replay")
		if replay_enabled:
			replay_result = _draw_counter_foreground_art(front)


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	call_deferred("_run")


func _run() -> void:
	var pack := PackScript.new()
	pack.environment_id = "gas_station_casino"
	pack.background = _texture(1800, 860, Color.BLACK)
	var animation := PackScript.AnimationEntry.new()
	animation.kind = PackScript.AnimationKind.FRAMES
	animation.texture = _texture(208, 32, Color.RED)
	animation.rect = Rect2(532, 80, 104, 16)
	animation.frame_regions.append(Rect2(0, 0, 208, 32))
	pack.animations.append(animation)
	var counter := PackScript.CounterEntry.new()
	counter.rect = Rect2(531, 78, 108, 14)
	counter.texture = _texture(216, 28, Color.GREEN)
	pack.counters["gas_station_staff_window"] = counter
	PackScript._cache["gas_station_casino"] = pack
	var viewport := SubViewport.new()
	viewport.size = Vector2i(900, 430)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := OrderCanvas.new()
	canvas.size = Vector2(900, 430)
	viewport.add_child(canvas)
	canvas.render_environment_snapshot({"archetype_id": "gas_station_casino", "interactable_objects": [], "reduce_motion": true})
	var original_front: Dictionary = canvas.front.duplicate(true)
	var image := await _image(viewport)
	_check(canvas.calls == ["background_animation", "counters", "scenario", "person", "replay"], "Production draw sequence keeps animation below counter, scenario and person/replay.")
	_check(_color(image, 535, 81, Color(0, 0.88, 0.12)), "The initial counter pass is above animation and below the scenario tint.")
	_check(_color(image, 535, 94, Color(0.88, 0, 0.12)), "Scenario tint covers the animation beyond the counter.")
	_check(_color(image, 531, 79, Color(0, 0.88, 0.12)), "Bleed extends outside the contact rectangle.")
	_check(canvas.front == original_front, "Texture bleed never mutates counter contact geometry.")
	if not out_dir.is_empty():
		image.save_png(out_dir.path_join("first_pass_scenario_tint.png"))
	canvas.replay_enabled = true
	canvas.queue_redraw()
	image = await _image(viewport)
	_check(canvas.first_result and canvas.replay_result, "Both calls report the same pack counter source as handled.")
	_check(_color(image, 540, 76, Color.MAGENTA), "The part of the person above the counter remains visible.")
	_check(_color(image, 540, 84, Color.GREEN), "The replay covers the lower body with the exact same texture.")
	if not out_dir.is_empty():
		image.save_png(out_dir.path_join("pack_counter_and_replay.png"))
	pack.counters.clear()
	canvas.queue_redraw()
	image = await _image(viewport)
	_check(_color(image, 540, 84, Color("#493116")), "Missing counter entry retains the exact code-drawn replay even in a packed room.")
	_check(_color(image, 531, 79, Color(0, 0, 0.12)), "Missing entry removes only texture bleed, without inventing geometry.")
	if not out_dir.is_empty():
		image.save_png(out_dir.path_join("code_counter_and_replay.png"))
	canvas.use_external_background = true
	canvas.background_texture = pack.background
	pack.counters["gas_station_staff_window"] = counter
	canvas.queue_redraw()
	image = await _image(viewport)
	_check(_color(image, 540, 84, Color("#493116")), "Legacy external background retains the code counter source.")
	viewport.free()
	PackScript.invalidate()
	for failure in failures:
		push_error(failure)
	print("ENVART_COUNTER_CONTRACT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _image(viewport: SubViewport) -> Image:
	for index in range(6):
		await process_frame
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _texture(width: int, height: int, color: Color) -> Texture2D:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _color(image: Image, x: int, y: int, expected: Color) -> bool:
	var actual := image.get_pixel(x, y)
	return absf(actual.r - expected.r) < 0.015 and absf(actual.g - expected.g) < 0.015 and absf(actual.b - expected.b) < 0.015


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
