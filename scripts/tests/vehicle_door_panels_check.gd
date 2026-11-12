extends SceneTree

const Vehicle := preload("res://scripts/ui/travel_vehicle_view.gd")
const BUS_DATA := "res://data/art/travel_back_alley_bar.json"
const STANDARD_DATA := "res://data/art/travel_standard_vehicles.json"
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)


func _rect(value: Array) -> Rect2:
	return Rect2(value[0], value[1], value[2], value[3])


func _run() -> void:
	var bus: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUS_DATA))
	var standard: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STANDARD_DATA))
	var contracts: Dictionary = standard["vehicles"]
	contracts["bus"] = {"texture": "res://assets/art/travel/back_alley_bar/bus_arrival.png",
		"source_px": bus["bus_source_px"], "door_rect_uv": bus["bus_door_rect_uv"],
		"wheels": bus["bus_wheels"], "door_animation": bus["bus_door_animation"]}
	for mode in ["bus", "taxi", "night_cab"]:
		var data: Dictionary = contracts[mode]
		var frozen := var_to_bytes(data)
		var texture := load(data["texture"]) as Texture2D
		var source := _rect(data["source_px"])
		var target := Rect2(25.0, 35.0, 900.0, 900.0 * source.size.y / source.size.x)
		var vehicle := Vehicle.new()
		vehicle.size = Vector2(950, 430)
		root.add_child(vehicle)
		vehicle.configure(texture, source, _rect(data["door_rect_uv"]), data["wheels"], data["door_animation"])
		_expect(vehicle.is_configured(), mode + " measured contract configures")
		vehicle.set_frame(target, 0.73, 0.0, 0.0, true)
		var closed := vehicle.draw_snapshot()
		_expect(not closed["door_active"], mode + " closed door uses original untouched body texture")
		_expect(closed["door_kind"] == ("bus_fold" if mode == "bus" else "hinged"), mode + " uses its measured door kind")
		_expect(closed["door_panels"].size() == (2 if mode == "bus" else 1), mode + " correct textured leaf count")
		_expect(closed["door_aperture"].size() > 4 if mode != "bus" else closed["door_step"].size() == 4, mode + " shaped cabin aperture or bus step")
		for opening in [0.25, 0.5, 1.0, 0.5, 0.0]:
			vehicle.set_frame(target, 0.73, 0.0, opening, true)
			var state := vehicle.draw_snapshot()
			_expect(state["wheels"] == closed["wheels"], mode + " door never moves parked wheels " + str(opening))
			_expect(state["body_rect"] == closed["body_rect"], mode + " door never moves parked body")
			for index in range(state["door_panels"].size()):
				var panel: Dictionary = state["door_panels"][index]
				var original: Dictionary = closed["door_panels"][index]
				_expect(panel["uvs"] == original["uvs"], mode + " hinges the same measured PNG pixels")
				_expect(panel["hinge"] == original["hinge"], mode + " hinge axis stays attached to body")
				_expect(panel["points"] != original["points"] if opening > 0.0 else panel["points"] == original["points"], mode + " actual draw geometry opens and closes")
				for uv in panel["uvs"]:
					_expect(uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0, mode + " source texture UV in bounds")
		vehicle.set_frame(target, 0.73, 0.0, 0.5, true)
		var half := var_to_bytes(vehicle.draw_snapshot())
		await process_frame
		await process_frame
		_expect(var_to_bytes(vehicle.draw_snapshot()) == half, mode + " no wall-clock animation")
		vehicle.set_frame(target, 0.73, 1000.0, 0.5, true)
		var bobbed := vehicle.draw_snapshot()
		_expect(bobbed["wheels"] == closed["wheels"], mode + " body suspension keeps wheels planted")
		_expect(bobbed["door_panels"][0]["hinge"][0].y > closed["door_panels"][0]["hinge"][0].y, mode + " door hinge follows restrained suspension")
		_expect(vehicle.clip_contents, mode + " retains stage clipping")
		seed(7158)
		var expected_random := randi()
		seed(7158)
		vehicle.set_frame(target, 0.73, 0.0, 0.5, true)
		_expect(randi() == expected_random, mode + " door consumes no gameplay RNG")
		_expect(var_to_bytes(data) == frozen, mode + " contract stays detached and immutable")
		if "--visual-proof" in OS.get_cmdline_user_args():
			await _render_checks(mode, data, texture, source, target)
		vehicle.configure(texture, source, _rect(data["door_rect_uv"]), data["wheels"])
		vehicle.set_frame(target, 0.0, 0.0, 1.0, true)
		_expect(vehicle.draw_snapshot()["door_kind"] == "texture_hinge_fallback", mode + " old four-argument API uses textured fallback")
		for invalid in [{"kind":"hinged"}, {"kind":"unknown"}]:
			vehicle.configure(texture, source, _rect(data["door_rect_uv"]), data["wheels"], invalid)
			vehicle.set_frame(target, 0.0, 0.0, 1.0, true)
			_expect(vehicle.draw_snapshot()["door_kind"] == "texture_hinge_fallback", mode + " malformed animation safely falls back")
		vehicle.free()
	print(JSON.stringify({"suite":"vehicle_door_panels", "checks": checks, "passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _render_checks(mode: String, data: Dictionary, texture: Texture2D, source: Rect2, target: Rect2) -> void:
	var evidence := OS.get_environment("BTH_QA_EVIDENCE_DIR")
	_expect(evidence.replace("\\", "/").begins_with("E:/CodexQA/BTH/runs/"), "rendered proof requires admitted E drive evidence")
	if not evidence.replace("\\", "/").begins_with("E:/CodexQA/BTH/runs/"):
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(950, 430)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(950, 430)
	background.color = Color("#393349")
	viewport.add_child(background)
	var vehicle := Vehicle.new()
	vehicle.size = background.size
	viewport.add_child(vehicle)
	vehicle.configure(texture, source, _rect(data["door_rect_uv"]), data["wheels"], data["door_animation"])
	var images: Array[Image] = []
	var plans: Array[Dictionary] = []
	var names := ["closed", "half", "open", "closing", "closed-again"]
	var openings := [0.0, 0.5, 1.0, 0.5, 0.0]
	for index in range(openings.size()):
		vehicle.set_frame(target, 0.73, 0.0, openings[index], true)
		var frame := await _capture(viewport)
		_expect(not frame.is_empty(), mode + " rendered framebuffer readable")
		if frame.is_empty():
			viewport.free()
			return
		images.append(frame)
		plans.append(vehicle.draw_snapshot())
		_expect(frame.save_png(evidence.path_join(mode + "-door-" + names[index] + ".png")) == OK, mode + " saves " + names[index] + " proof")
	_expect(images[0].get_data() == images[4].get_data(), mode + " actual closed pixels restore exactly")
	_expect(images[1].get_data() == images[3].get_data(), mode + " actual closing reverses opening exactly")
	_expect(_changed(images[0], images[1], target) > 100, mode + " half opening visibly changes pixels")
	_expect(_changed(images[1], images[2], target) > 100, mode + " half and fully open visibly differ")
	for index in range(2):
		var wheel: Dictionary = plans[0]["wheels"][index]
		var region := Rect2(wheel["center"] - wheel["radius"], wheel["radius"] * 2.0)
		_expect(_changed(images[0], images[2], region) == 0, mode + " actual parked wheel pixels stay identical " + str(index))
	var samples: Array = [Vector2(1510, 420), Vector2(1590, 420)] if mode == "bus" else ([Vector2(700, 310), Vector2(850, 520)] if mode == "taxi" else [Vector2(700, 330), Vector2(700, 485)])
	var native := Vector2(texture.get_width(), texture.get_height())
	for sample_index in range(samples.size()):
		var panel_index := sample_index if mode == "bus" else 0
		for state_index in [1, 2]:
			var panel: Dictionary = plans[state_index]["door_panels"][panel_index]
			var position := _project_uv(samples[sample_index] / native, panel)
			_expect(position.x >= 0.0, mode + " source sample lands in actual draw polygon")
			if position.x < 0.0:
				continue
			var expected := texture.get_image().get_pixelv(Vector2i(samples[sample_index])) * Color(panel["tint"])
			var observed := images[state_index].get_pixelv(Vector2i(position.round()))
			_expect(absf(expected.r - observed.r) < 0.13 and absf(expected.g - observed.g) < 0.13 and absf(expected.b - observed.b) < 0.13, mode + " rendered panel retains original window/body colors %d/%d" % [sample_index, state_index])
	var aperture: PackedVector2Array = plans[2]["door_aperture"]
	var interior_count := 0
	var interior: Color = plans[2]["door_interior_color"]
	for y in range(int(target.position.y), int(target.end.y)):
		for x in range(int(target.position.x), int(target.end.x)):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), aperture):
				var pixel := images[2].get_pixel(x, y)
				if absf(pixel.r - interior.r) < 0.01 and absf(pixel.g - interior.g) < 0.01 and absf(pixel.b - interior.b) < 0.01:
					interior_count += 1
	_expect(interior_count > 120, mode + " actual open door exposes dark shaped cabin")
	viewport.free()


func _project_uv(uv: Vector2, panel: Dictionary) -> Vector2:
	var uvs: PackedVector2Array = panel["uvs"]
	var points: PackedVector2Array = panel["points"]
	var triangles := Geometry2D.triangulate_polygon(uvs)
	for index in range(0, triangles.size(), 3):
		var a := triangles[index]
		var b := triangles[index + 1]
		var c := triangles[index + 2]
		if Geometry2D.is_point_in_polygon(uv, PackedVector2Array([uvs[a], uvs[b], uvs[c]])):
			var inverse := Transform2D(uvs[b] - uvs[a], uvs[c] - uvs[a], uvs[a]).affine_inverse()
			var weights := inverse * uv
			return points[a] + (points[b] - points[a]) * weights.x + (points[c] - points[a]) * weights.y
	return Vector2(-1, -1)


func _capture(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _changed(before: Image, after: Image, region: Rect2) -> int:
	var count := 0
	var bounded := region.intersection(Rect2(Vector2.ZERO, before.get_size()))
	for y in range(int(bounded.position.y), int(bounded.end.y)):
		for x in range(int(bounded.position.x), int(bounded.end.x)):
			if before.get_pixel(x, y) != after.get_pixel(x, y):
				count += 1
	return count
