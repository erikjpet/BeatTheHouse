extends SceneTree
const PackScript := preload("res://scripts/ui/environment_art_pack.gd")
const RendererScript := preload("res://scripts/ui/environment_art_renderer.gd")
var checks := 0
var failures: Array[String] = []
var renderer: RendererScript
var out_dir := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	call_deferred("_run")


func _run() -> void:
	var frames := _entry(PackScript.AnimationKind.FRAMES, Rect2(10, 10, 1, 1), Color.RED)
	var strip := Image.create(8, 2, false, Image.FORMAT_RGBA8)
	var colors := [Color.RED, Color.GREEN, Color.BLUE, Color.WHITE]
	for index in range(4):
		strip.fill_rect(Rect2i(index * 2, 0, 2, 2), colors[index])
	frames.texture = ImageTexture.create_from_image(strip)
	frames.frame_count = 4
	frames.fps = 4
	frames.frame_regions.clear()
	for index in range(4):
		frames.frame_regions.append(Rect2(index * 2, 0, 2, 2))
	_check(frames.frame_at(0.0, false) == 0 and frames.frame_at(0.25, false) == 1 and frames.frame_at(1.0, false) == 0, "Loop frames use clock and fps.")
	frames.phase = 0.25
	_check(frames.frame_at(0.0, false) == 1, "Phase adds seconds to the clock.")
	frames.phase = 0.0
	frames.loop_mode = PackScript.LoopMode.PINGPONG
	for index in range(7):
		_check(frames.frame_at(index * 0.25, false) == [0, 1, 2, 3, 2, 1, 0][index], "Pingpong reverses without duplicating endpoints.")
	_check(frames.frame_at(-0.25, false) == 1, "Negative clock wraps safely.")
	frames.loop_mode = PackScript.LoopMode.ONCE_HOLD
	_check(frames.frame_at(20.0, false) == 3 and frames.frame_at(-1.0, false) == 0, "Once-hold clamps both ends.")
	frames.still_frame = 2
	_check(frames.frame_at(0.0, true) == 2 and frames.frame_at(99.0, true) == 2, "Reduce Motion selects the explicit still frame.")
	frames.loop_mode = PackScript.LoopMode.LOOP
	await _configure([frames])
	var image := await _image(0.25)
	_check(_color(image, 10, 10, Color.GREEN), "Frame strip source regions render the selected frame.")
	var pulse := _entry(PackScript.AnimationKind.PULSE, Rect2(20, 10, 2, 2), Color.WHITE)
	pulse.min_opacity = 0.2
	pulse.max_opacity = 0.8
	pulse.period = 4.0
	pulse.opacity = 0.5
	_check(is_equal_approx(pulse.pulse_at(0.0, false), 0.25) and is_equal_approx(pulse.pulse_at(1.0, false), 0.4) and is_equal_approx(pulse.pulse_at(3.0, false), 0.1), "Pulse sine and common opacity have exact fixed-time values.")
	await _configure([pulse])
	image = await _image(1.0)
	_check(_color(image, 20, 10, Color(0.4, 0.4, 0.4)), "Pulse opacity is applied in the actual draw.")
	var mover := _entry(PackScript.AnimationKind.MOVER, Rect2(10, 10, 2, 2), Color.RED)
	mover.size = Vector2(2, 2)
	mover.from_point = Vector2(10, 10)
	mover.to_point = Vector2(20, 10)
	mover.duration = 2.0
	mover.gap = 1.0
	mover.has_clip = true
	mover.clip = Rect2(11, 10, 2, 2)
	_check(mover.mover_at(1.0, false) == Vector2(15, 10) and mover.mover_at(3.0, false) == Vector2(10, 10), "Mover interpolates and repeats after the gap.")
	_check(not mover.mover_visible_at(2.5, false) and mover.mover_visible_at(3.0, false), "Gap hides the passing texture.")
	await _configure([mover])
	image = await _image(0.0)
	_check(_color(image, 10, 10, Color.BLACK) and _color(image, 11, 10, Color.RED) and _color(image, 12, 10, Color.BLACK), "Mover clipping trims destination and matching source exactly.")
	image = await _image(2.5)
	_check(_color(image, 11, 10, Color.BLACK), "Mover gap produces no pixels.")
	var scroll := _entry(PackScript.AnimationKind.SCROLL, Rect2(30, 10, 4, 2), Color.RED)
	var tile := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	tile.fill(Color.RED)
	tile.fill_rect(Rect2i(4, 0, 4, 4), Color.BLUE)
	scroll.texture = ImageTexture.create_from_image(tile)
	scroll.speed = Vector2(1, 0)
	_check(scroll.scroll_at(1.0, false) == Vector2(1, 0) and scroll.scroll_at(5.0, false) == Vector2(1, 0), "Scroll wraps at its full rectangle size.")
	await _configure([scroll])
	image = await _image(1.0)
	_check(_color(image, 29, 10, Color.BLACK) and _color(image, 30, 10, Color.BLUE) and _color(image, 31, 10, Color.RED) and _color(image, 33, 10, Color.BLUE) and _color(image, 34, 10, Color.BLACK), "Scroll tiles and clips at both edges.")
	scroll.speed = Vector2(-1, -1)
	_check(scroll.scroll_at(1.0, false) == Vector2(3, 1), "Negative scroll speed wraps in both axes.")
	var sweep := _entry(PackScript.AnimationKind.SWEEP, Rect2(0, 0, 2, 2), Color.WHITE)
	sweep.origin = Vector2(40, 10)
	sweep.from_point = Vector2(45, 10)
	sweep.to_point = Vector2(40, 15)
	sweep.period = 4.0
	sweep.beam_thickness = 2.0
	_check(sweep.sweep_at(0.0, false).is_equal_approx(Vector2(45, 10)) and sweep.sweep_at(2.0, false).is_equal_approx(Vector2(40, 15)) and sweep.sweep_at(4.0, false).is_equal_approx(Vector2(45, 10)), "Sweep completes the outward and return swing in one period.")
	await _configure([sweep])
	image = await _image(0.0)
	_check(_color(image, 42, 10, Color.WHITE) and _color(image, 40, 13, Color.BLACK), "Sweep starts at its first endpoint.")
	image = await _image(2.0)
	_check(_color(image, 40, 13, Color.WHITE) and _color(image, 43, 10, Color.BLACK), "Sweep rotates the stretched beam to its second endpoint.")
	var mix := _entry(PackScript.AnimationKind.FRAMES, Rect2(50, 10, 4, 4), Color(0.4, 0, 0))
	var add := _entry(PackScript.AnimationKind.FRAMES, Rect2(50, 10, 4, 4), Color(0, 0.4, 0))
	add.additive = true
	await _configure([mix, add])
	image = await _image(0.0)
	_check(_color(image, 51, 11, Color(0.4, 0.4, 0)), "Add blends against the preceding background/entry.")
	await _configure([add, mix])
	image = await _image(0.0)
	_check(_color(image, 51, 11, Color(0.4, 0, 0)), "Mixed blend modes preserve exact manifest order.")
	mix.still_hidden = true
	await _configure([mix])
	image = await _image(9.0, true)
	_check(_color(image, 51, 11, Color.BLACK), "Still hide suppresses the entry only in Reduce Motion.")
	mix.still_hidden = false
	mix.web_low_detail = false
	image = await _image(9.0, false, true)
	_check(_color(image, 51, 11, Color.BLACK), "Existing Web low-detail switch skips opted-out entries.")
	await _configure([frames, pulse, mover, scroll, sweep])
	var first := await _image(0.0, true)
	var second := await _image(99.0, true)
	_check(first.get_data() == second.get_data(), "Every type renders pixel-identically at two clocks with Reduce Motion.")
	if not out_dir.is_empty():
		first.save_png(out_dir.path_join("reduce_motion_first.png"))
		second.save_png(out_dir.path_join("reduce_motion_later.png"))
		(await _image(1.0)).save_png(out_dir.path_join("all_five_types.png"))
	renderer.free()
	for failure in failures:
		push_error(failure)
	print("ENVART_ANIMATION_CONTRACT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _configure(values: Array) -> void:
	if renderer != null:
		renderer.free()
	var pack := PackScript.new()
	pack.background = _texture(1800, 860, Color.BLACK)
	for entry in values:
		pack.animations.append(entry)
	renderer = RendererScript.new()
	root.add_child(renderer)
	renderer.configure(pack)
	await process_frame


func _image(clock: float, reduced: bool = false, low: bool = false) -> Image:
	renderer.present(clock, reduced, low)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return renderer.viewport.get_texture().get_image()


func _entry(kind: int, rect: Rect2, color: Color) -> PackScript.AnimationEntry:
	var entry := PackScript.AnimationEntry.new()
	entry.kind = kind
	entry.rect = rect
	entry.texture = _texture(int(rect.size.x * 2), int(rect.size.y * 2), color)
	entry.frame_regions.append(Rect2(Vector2.ZERO, entry.texture.get_size()))
	return entry


func _texture(width: int, height: int, color: Color) -> Texture2D:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _color(image: Image, x: int, y: int, expected: Color) -> bool:
	var actual := image.get_pixel(x * 2, y * 2)
	return absf(actual.r - expected.r) < 0.015 and absf(actual.g - expected.g) < 0.015 and absf(actual.b - expected.b) < 0.015


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
