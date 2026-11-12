extends "res://scripts/tests/vehicle_door_panels_check.gd"

# Synthetic presentation fixtures only. These are not legal-route proofs.
const Catalog := preload("res://scripts/ui/travel_presentation_catalog.gd")
const Overlay := preload("res://scripts/ui/travel_cinematic_overlay.gd")
var cabin_evidence: Array = []

class MissingCabinOverlay extends Overlay:
	var blocked_path := ""
	var wrong_size := false
	func _load_art(path: String) -> Texture2D:
		if path == blocked_path:
			return ImageTexture.create_from_image(Image.create(7, 11, false, Image.FORMAT_RGBA8)) if wrong_size else null
		return super._load_art(path)

func _receipt(mode: String) -> Dictionary:
	return {"schema_version":1, "journey_id":"synthetic_cabin_" + mode,
		"presentation_key":Catalog.STANDARD_KEY, "travel_method_kind":mode,
		"effective_destination_archetype_id":"bar", "origin_label":"Synthetic visual fixture",
		"destination_label":"Bar", "receipt_text":"Synthetic visual-only preview. Not a legal-route proof."}

func _run() -> void:
	var rendered := "--pure-only" not in OS.get_cmdline_user_args()
	var paths: Dictionary = {}
	var hashes: Dictionary = {}
	if rendered: _expect(DisplayServer.get_name() != "headless", "actual renderer required")
	for mode in ["bus", "taxi", "night_cab"]:
		var data: Dictionary = Catalog.profile(_receipt(mode))["vehicle"]
		var path := str(data.get("interior_texture", ""))
		_expect(not path.is_empty() and not paths.has(path), mode + " distinct cabin texture path")
		paths[path] = true
		if path.is_empty() or not FileAccess.file_exists(path):
			_expect(false, mode + " cabin PNG exists")
			continue
		var hash_value := FileAccess.get_sha256(path)
		_expect(not hashes.has(hash_value), mode + " distinct cabin PNG bytes")
		hashes[hash_value] = true
		var cabin := load(path) as Texture2D
		_expect(cabin != null, mode + " imported cabin loads")
		if cabin == null: continue
		var reference: Array = data.get("interior_reference_size", [])
		_expect(reference.size() == 2 and Vector2(reference[0], reference[1]) == Vector2(cabin.get_width(), cabin.get_height()), mode + " actual native dimensions match metadata")
		var overlay := Overlay.new()
		root.add_child(overlay)
		overlay.present(_receipt(mode))
		overlay.set_process(false)
		_expect(overlay.snapshot()["vehicle_interior_has_art"] and not overlay.snapshot()["static"], mode + " production overlay loads actual cabin")
		_expect(overlay._vehicle_view._interior_texture == cabin, mode + " production vehicle receives same imported cabin")
		var production_material: Material = overlay._vehicle_view.material
		_expect(production_material != null, mode + " actual production shader material exists")
		for mismatch in [false, true]:
			var missing := MissingCabinOverlay.new()
			missing.blocked_path = path
			missing.wrong_size = mismatch
			root.add_child(missing)
			missing.present(_receipt(mode))
			_expect(missing.phase == "receipt" and missing.snapshot()["static"], mode + " missing or wrong-native cabin falls to safe receipt " + str(mismatch))
			missing.free()
		if rendered and DisplayServer.get_name() != "headless":
			await _render_cabin(mode, data, cabin, null, "isolated")
			await _render_cabin(mode, data, cabin, production_material, "production_shader")
		overlay.free()
	var walk := Overlay.new()
	root.add_child(walk)
	walk.present(_receipt("walk"))
	walk.set_process(false)
	_expect(not walk.snapshot()["vehicle_interior_has_art"] and walk.snapshot()["vehicle_interior_path"] == "", "walking loads no vehicle cabin")
	_expect(walk._vehicle_view.draw_snapshot().is_empty(), "walking draws no vehicle cabin")
	walk.free()
	_expect(paths.size() == 3 and hashes.size() == 3, "three distinct authored cabins")
	var report := {"suite":"vehicle_cabin_interior", "checks":checks, "passed":failures.is_empty(), "failures":failures,
		"rendered":rendered, "scope":"synthetic visual-only fixtures, not legal route proof", "cabins":cabin_evidence}
	var evidence := OS.get_environment("BTH_QA_EVIDENCE_DIR")
	if not evidence.is_empty():
		var file := FileAccess.open(evidence.path_join("vehicle_cabin_interior_report.json"), FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _render_cabin(mode: String, data: Dictionary, cabin: Texture2D, shader_material: Material, variant: String) -> void:
	var label := mode + " " + variant
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1100, 530)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(viewport.size)
	background.color = Color("#393349")
	viewport.add_child(background)
	var caption := Label.new()
	caption.position = Vector2(20, 480)
	caption.text = mode + " cabin opening | SYNTHETIC VISUAL ONLY | Not legal-route proof"
	viewport.add_child(caption)
	var vehicle := Vehicle.new()
	vehicle.size = Vector2(viewport.size)
	vehicle.material = shader_material
	viewport.add_child(vehicle)
	var texture := load(data["texture"]) as Texture2D
	var source := _rect(data["source_px"])
	var target := Rect2(30, 55, 1000, 1000 * source.size.y / source.size.x)
	var door := _rect(data["door_rect_uv"])
	vehicle.configure(texture, source, door, data["wheels"], data["door_animation"])
	vehicle.set_frame(target, 0.73, 0.0, 0.0, true)
	var closed_without := await _capture(viewport)
	vehicle.set_frame(target, 0.73, 0.0, 1.0, true)
	var open_without := await _capture(viewport)
	var legacy := vehicle.draw_snapshot()
	vehicle.configure(texture, source, door, data["wheels"], data["door_animation"], cabin)
	vehicle.set_frame(target, 0.73, 0.0, 0.0, true)
	var closed_with := await _capture(viewport)
	_expect(closed_with.get_data() == closed_without.get_data(), label + " closed vehicle remains pixel-identical")
	vehicle.set_frame(target, 0.73, 0.0, 1.0, true)
	var opened := await _capture(viewport)
	var plan := vehicle.draw_snapshot()
	_expect(plan["door_panels"] == legacy["door_panels"] and plan["wheels"] == legacy["wheels"], label + " cabin preserves hinges, textured panels and wheels")
	_expect(plan["door_interior_texture_path"] == cabin.resource_path, label + " actual draw references imported cabin")
	var polygon: PackedVector2Array = plan["door_aperture"]
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon: bounds = bounds.expand(point)
	# Independent aspect-cover transform from measured aperture and native PNG.
	var native_size := Vector2(cabin.get_width(), cabin.get_height())
	var scale_value := maxf(bounds.size.x / native_size.x, bounds.size.y / native_size.y)
	var draw_size := native_size * scale_value
	var origin := Vector2(bounds.get_center().x - draw_size.x * 0.5, bounds.end.y - draw_size.y)
	var source_image := cabin.get_image()
	var outside_changes := 0
	var colored_changes := 0
	var colors: Dictionary = {}
	var verified := 0
	var mismatched := 0
	var step_verified := 0
	var step_mismatched := 0
	for y in opened.get_height():
		for x in opened.get_width():
			var point := Vector2(x + 0.5, y + 0.5)
			var pixel := opened.get_pixel(x, y)
			var changed := not _same_pixel(pixel, open_without.get_pixel(x, y))
			var inside := Geometry2D.is_point_in_polygon(point, polygon)
			if changed and not inside and _edge_distance(point, polygon) > 1.1: outside_changes += 1
			if not inside or _edge_distance(point, polygon) < 1.5: continue
			var occluded := false
			for panel in plan["door_panels"]:
				if Geometry2D.is_point_in_polygon(point, panel["points"]) or _edge_distance(point, panel["points"]) < 2.0: occluded = true
			if occluded: continue
			if changed:
				colors[pixel.to_html(false)] = true
				if maxf(pixel.r, maxf(pixel.g, pixel.b)) - minf(pixel.r, minf(pixel.g, pixel.b)) > 0.08: colored_changes += 1
			var native := (point - origin) / scale_value
			var fraction := native - native.floor()
			if fraction.x < 0.03 or fraction.x > 0.97 or fraction.y < 0.03 or fraction.y > 0.97: continue
			var expected := source_image.get_pixelv(Vector2i(native.floor()))
			var match_pixel := _same_pixel(pixel, expected)
			verified += 1
			if not match_pixel: mismatched += 1
			if Geometry2D.is_point_in_polygon(point, plan["door_step"]):
				step_verified += 1
				if not match_pixel: step_mismatched += 1
	_expect(outside_changes == 0, label + " cabin pixels never spill outside measured aperture")
	_expect(colored_changes > 50 and colors.size() > 30, label + " varied RGB cabin pixels replace gray fill")
	_expect(verified > 40 and mismatched == 0, label + " independent source RGB samples match %d/%d" % [mismatched, verified])
	_expect(step_verified > 5 and step_mismatched == 0, label + " textured floor/step source samples match %d/%d" % [step_mismatched, step_verified])
	vehicle.set_frame(target, 0.73, 0.45, 1.0, true)
	var bobbed := vehicle.draw_snapshot()
	_expect(bobbed["wheels"] == plan["wheels"], label + " suspension keeps wheels planted")
	_expect(is_equal_approx(bobbed["door_aperture"][0].y - polygon[0].y, 0.45), label + " cabin follows body suspension")
	vehicle.set_frame(target, 0.73, 0.0, 0.0, true)
	var reclosed := await _capture(viewport)
	_expect(reclosed.get_data() == closed_without.get_data(), label + " reclosed frame restores exact original pixels")
	vehicle.configure(texture, source, door, data["wheels"])
	vehicle.set_frame(target, 0.73, 0.0, 1.0, true)
	_expect(vehicle.is_configured() and vehicle.draw_snapshot()["door_kind"] == "texture_hinge_fallback", label + " four-argument API still works")
	var evidence := OS.get_environment("BTH_QA_EVIDENCE_DIR")
	_expect(evidence.replace("\\", "/").begins_with("E:/CodexQA/BTH/runs/"), "admitted E drive evidence path")
	_expect(opened.save_png(evidence.path_join("synthetic_cabin_" + mode + "_" + variant + "_open.png")) == OK, label + " saves opening proof")
	cabin_evidence.append({"mode":mode, "variant":variant, "native_size":[cabin.get_width(),cabin.get_height()], "path":cabin.resource_path,
		"outside_changes":outside_changes, "colored_changes":colored_changes, "distinct_colors":colors.size(),
		"verified_source_samples":verified, "source_mismatches":mismatched, "step_source_samples":step_verified, "step_mismatches":step_mismatched})
	viewport.free()

func _same_pixel(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.009 and absf(a.g - b.g) < 0.009 and absf(a.b - b.b) < 0.009 and absf(a.a - b.a) < 0.009

func _edge_distance(point: Vector2, polygon: PackedVector2Array) -> float:
	var distance := INF
	for index in polygon.size():
		distance = minf(distance, point.distance_to(Geometry2D.get_closest_point_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()])))
	return distance
