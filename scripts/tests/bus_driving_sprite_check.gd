extends SceneTree

const Bus := preload("res://scripts/ui/bus_driving_sprite.gd")
const BUS_PATH := "res://assets/art/travel/back_alley_bar/bus_arrival.png"
const CONTRACT_PATH := "res://data/art/travel_back_alley_bar.json"
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)


func _rect(values: Array) -> Rect2:
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


func _run() -> void:
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	var frozen_contract := var_to_bytes(contract)
	var texture := load(BUS_PATH) as Texture2D
	_expect(texture != null, "actual bus PNG loads")
	if texture == null:
		_finish()
		return
	var source := _rect(contract["bus_source_px"])
	var door := _rect(contract["bus_door_rect_uv"])
	var wheels: Array = contract["bus_wheels"]
	var native := Vector2(texture.get_width(), texture.get_height())
	var reference := Vector2(float(contract["reference_size"][0]), float(contract["reference_size"][1]))
	source = Rect2(source.position * native / reference, source.size * native / reference)
	var bus := Bus.new()
	bus.position = Vector2(70.0, 30.0)
	bus.size = Vector2(700.0, 300.0)
	root.add_child(bus)
	bus.configure(texture, source, door, wheels)
	_expect(bus.is_configured(), "actual source crop and normalized wheel contract valid")
	_expect(bus.clip_contents, "bus layer clips all body wheel and door commands to the stage")
	_expect(bus.mouse_filter == Control.MOUSE_FILTER_IGNORE, "bus layer cannot intercept scene UI")
	_expect(wheels.size() == 2, "both existing bus wheels have anchors")
	var image := texture.get_image()
	for index in range(wheels.size()):
		var entry: Dictionary = wheels[index]
		var center := source.position + source.size * Vector2(float(entry["center_uv"][0]), float(entry["center_uv"][1]))
		var radius := source.size * Vector2(float(entry["radius_uv"][0]), float(entry["radius_uv"][1]))
		_expect(absf(radius.x - radius.y) < 0.01, "wheel source clipping region is circular %d" % index)
		var hub := image.get_pixelv(Vector2i(center.round()))
		_expect(hub.a > 0.99 and hub.b > hub.r and hub.b > hub.g * 1.4, "anchor lands on actual opaque purple hub %d" % index)
		for spoke in range(16):
			var edge := image.get_pixelv(Vector2i((center + Vector2.from_angle(TAU * spoke / 16.0) * radius * 0.98).round()))
			_expect(edge.a > 0.97 and edge.g < 0.35, "wheel disc excludes transparent corners and cyan arch %d/%d" % [index, spoke])
	var target := Rect2(40.0, 115.0, 620.0, 620.0 * source.size.y / source.size.x)
	bus.set_frame(target, 0.0, 0.0, 0.0, true)
	var stopped := bus.draw_snapshot()
	_expect(bus.visible and stopped["wheels"].size() == 2, "visible frame draws body and two wheel texture polygons")
	_expect(stopped["body_rect"].is_equal_approx(target), "settled body exactly matches target")
	for index in range(2):
		var wheel: Dictionary = stopped["wheels"][index]
		_expect(wheel["points"].size() == Bus.WHEEL_SEGMENTS and wheel["uvs"].size() == Bus.WHEEL_SEGMENTS, "wheel draw polygon has matched clipped vertices and texture UVs %d" % index)
		_expect(wheel["lugs"].size() == 3, "subtle asymmetric rotating rim lugs present %d" % index)
		for uv in wheel["uvs"]:
			_expect(uv.x >= 0.0 and uv.y >= 0.0 and uv.x <= 1.0 and uv.y <= 1.0, "texture UV stays inside native image")
	bus.set_frame(target, 0.73, 1.5, 0.0, true)
	var moving := bus.draw_snapshot()
	_expect(not moving["body_rect"].is_equal_approx(stopped["body_rect"]), "moving frame visibly changes suspension height")
	for index in range(2):
		var before: Dictionary = stopped["wheels"][index]
		var after: Dictionary = moving["wheels"][index]
		_expect(before["points"] == after["points"], "wheels stay planted while body bobs %d" % index)
		_expect(before["uvs"] != after["uvs"], "actual tire rim draw UVs rotate instead of flat sprite translation %d" % index)
		_expect(before["lugs"] != after["lugs"], "visible rim highlights rotate with tire pixels %d" % index)
	bus.set_frame(target, 0.73, 0.0, 0.0, true)
	var parked := var_to_bytes(bus.draw_snapshot())
	await process_frame
	await process_frame
	_expect(var_to_bytes(bus.draw_snapshot()) == parked, "stopped frame never advances itself with wall clock")
	for repeat_index in range(8):
		bus.set_frame(target, 0.73, 0.0, 0.0, true)
		_expect(var_to_bytes(bus.draw_snapshot()) == parked, "identical stopped samples stable %d" % repeat_index)
	bus.set_frame(target, 0.73, 1000.0, 2.0, true)
	var limited := bus.draw_snapshot()
	_expect(is_equal_approx(float(limited["body_bob"]), target.size.y * Bus.MAX_BOB_HEIGHT_RATIO), "suspension amplitude is restrained by bus height")
	_expect(is_equal_approx(float(limited["door_open"]), 1.0), "door opening clamps to physical range")
	var body: Rect2 = limited["body_rect"]
	var full_door: Rect2 = limited["door_rect"]
	_expect(full_door.position.is_equal_approx(body.position + body.size * door.position), "door follows sprung body at actual source anchor")
	bus.set_frame(Rect2(-500.0, target.position.y, target.size.x, target.size.y), 1.0, 0.0, 1.0, true)
	_expect(bus.clip_contents and bus.draw_snapshot()["body_rect"].position.x < 0.0, "offstage entrance keeps local geometry and Control clipping")
	bus.set_frame(target, 0.0, 0.0, 0.0, false)
	_expect(not bus.visible and bus.draw_snapshot().is_empty(), "hidden frame clears all draw commands")
	bus.set_frame(Rect2(), 0.0, 0.0, 0.0, true)
	_expect(not bus.visible and bus.draw_snapshot().is_empty(), "empty target safely suppresses drawing")
	bus.set_frame(target, NAN, 0.0, 0.0, true)
	_expect(not bus.visible and bus.draw_snapshot().is_empty(), "nonfinite frame input safely suppresses drawing")
	var synthetic := ImageTexture.create_from_image(Image.create(887, 444, false, Image.FORMAT_RGBA8))
	var new_native := Vector2(synthetic.get_width(), synthetic.get_height())
	var scale := new_native / native
	bus.configure(synthetic, Rect2(source.position * scale, source.size * scale), door, wheels)
	bus.set_frame(target, 0.0, 0.0, 0.0, true)
	var resized := bus.draw_snapshot()
	_expect(bus.is_configured(), "replacement native art size remains supported")
	for index in range(2):
		var before: Dictionary = stopped["wheels"][index]
		var after: Dictionary = resized["wheels"][index]
		_expect(before["points"] == after["points"], "normalized wheel target geometry unaffected by native resolution %d" % index)
		for uv_index in range(Bus.WHEEL_SEGMENTS):
			_expect(before["uvs"][uv_index].is_equal_approx(after["uvs"][uv_index]), "normalized source UV survives native resolution change")
	var bad_wheels := wheels.duplicate(true)
	bad_wheels[0]["center_uv"] = [1.5, 0.5]
	bus.configure(texture, source, door, bad_wheels)
	bus.set_frame(target, 0.0, 0.0, 0.0, true)
	_expect(not bus.is_configured() and not bus.visible, "invalid wheel anchors rejected without stale frame")
	bus.configure(texture, Rect2(-10.0, 0.0, 100.0, 100.0), door, wheels)
	_expect(not bus.is_configured(), "out of image source rectangle rejected")
	bus.configure(null, source, door, wheels)
	_expect(not bus.is_configured(), "missing bus texture rejected")
	seed(64321)
	var expected_random := randi()
	seed(64321)
	bus.configure(texture, source, door, wheels)
	for index in range(20):
		bus.set_frame(target, index * 0.31, sin(index * 0.2), 0.0, true)
	_expect(randi() == expected_random, "presentation consumes no gameplay RNG")
	_expect(var_to_bytes(contract) == frozen_contract, "configuration never mutates art contract")
	var script_source := FileAccess.get_file_as_string("res://scripts/ui/bus_driving_sprite.gd")
	for forbidden in ["RunState", "RandomNumberGenerator", "Time.", "FileAccess", "load(", "func _process", "randf(", "randi("]:
		_expect(not script_source.contains(forbidden), "sprite has no authority time file or RNG dependency: " + forbidden)
	if "--visual-proof" in OS.get_cmdline_user_args():
		await _visual_checks(texture, source, door, wheels)
	bus.free()
	_finish()


func _visual_checks(texture: Texture2D, source: Rect2, door: Rect2, wheels: Array) -> void:
	var evidence := OS.get_environment("BTH_QA_EVIDENCE_DIR")
	_expect(evidence.replace("\\", "/").begins_with("E:/CodexQA/BTH/runs/"), "rendered proof requires admitted E drive evidence directory")
	if not evidence.replace("\\", "/").begins_with("E:/CodexQA/BTH/runs/"):
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800, 340)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(800, 340)
	backdrop.color = Color("#221d33")
	viewport.add_child(backdrop)
	var bus := Bus.new()
	bus.position = Vector2(60, 40)
	bus.size = Vector2(680, 240)
	viewport.add_child(bus)
	bus.configure(texture, source, door, wheels)
	var baseline := await _capture(viewport)
	_expect(not baseline.is_empty(), "actual GPU viewport produces readable pixels")
	if baseline.is_empty():
		viewport.free()
		return
	var target := Rect2(-40.0, 45.0, 620.0, 620.0 * source.size.y / source.size.x)
	bus.set_frame(target, 0.0, 0.0, 0.0, true)
	var first := await _capture(viewport)
	bus.set_frame(target, 0.73, 0.0, 0.0, true)
	var rotated := await _capture(viewport)
	var still := await _capture(viewport)
	_expect(rotated.get_data() == still.get_data(), "actual stopped framebuffer is stable without pointer input")
	for index in range(wheels.size()):
		var center_uv := Vector2(float(wheels[index]["center_uv"][0]), float(wheels[index]["center_uv"][1]))
		var radius_uv := Vector2(float(wheels[index]["radius_uv"][0]), float(wheels[index]["radius_uv"][1]))
		var center := bus.position + target.position + target.size * center_uv
		var radius := target.size * radius_uv
		var changed := _changed_pixels(first, rotated, Rect2(center - radius, radius * 2.0))
		_expect(changed > 40, "actual wheel framebuffer visibly rotates %d (%d changed pixels)" % [index, changed])
	_expect(_changed_pixels(first, rotated, Rect2(80, 100, 450, 70)) == 0, "stationary body pixels stay fixed while wheel pixels rotate")
	var outside_changes := 0
	var stage := Rect2(bus.position, bus.size)
	for y in range(viewport.size.y):
		for x in range(viewport.size.x):
			if not stage.has_point(Vector2(x, y)) and baseline.get_pixel(x, y) != first.get_pixel(x, y):
				outside_changes += 1
	_expect(outside_changes == 0, "actual body and wheel framebuffer clips at all stage edges")
	bus.set_frame(target, 0.73, 1.5, 0.0, true)
	var bobbed := await _capture(viewport)
	_expect(_changed_pixels(rotated, bobbed, Rect2(80, 80, 450, 110)) > 100, "actual body suspension moves pixels independently of wheel phase")
	_expect(first.save_png(evidence.path_join("bus-angle-0.png")) == OK, "save rendered stopped frame")
	_expect(rotated.save_png(evidence.path_join("bus-angle-073.png")) == OK, "save rendered rotated wheel frame")
	_expect(bobbed.save_png(evidence.path_join("bus-angle-073-body-bob.png")) == OK, "save rendered suspension frame")
	bus.set_frame(target, 0.73, 0.0, 0.0, false)
	var hidden := await _capture(viewport)
	_expect(hidden.get_data() == baseline.get_data(), "actual hidden framebuffer leaves no stale bus pixels")
	viewport.free()


func _capture(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _changed_pixels(before: Image, after: Image, region: Rect2) -> int:
	var bounded := region.intersection(Rect2(Vector2.ZERO, before.get_size()))
	var count := 0
	for y in range(int(bounded.position.y), int(bounded.end.y)):
		for x in range(int(bounded.position.x), int(bounded.end.x)):
			if before.get_pixel(x, y) != after.get_pixel(x, y):
				count += 1
	return count


func _finish() -> void:
	print(JSON.stringify({"suite": "bus_driving_sprite", "checks": checks, "passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
