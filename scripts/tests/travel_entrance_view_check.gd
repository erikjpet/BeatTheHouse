extends SceneTree

const Entrance := preload("res://scripts/ui/travel_entrance_view.gd")
const FULL := Rect2(0.0, 0.0, 1.0, 1.0)
const ACTOR_COLOR := Color("#fa03e7")
var checks := 0
var failures: Array[String] = []
var captures: Array[String] = []

class SourceBackground extends Control:
	var source: Texture2D
	var window := Rect2(0.0, 0.0, 1.0, 1.0)
	func _draw() -> void:
		var native := Vector2(source.get_width(), source.get_height())
		draw_texture_rect_region(source, Rect2(Vector2.ZERO, size), Rect2(window.position * native, window.size * native))


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var texture := _synthetic_texture()
	_test_plans(texture)
	_test_validation(texture)
	if "--pure-only" not in OS.get_cmdline_user_args():
		if DisplayServer.get_name() == "headless":
			_expect(false, "render suite needs a real renderer; headless cannot certify pixels")
		else:
			await _test_rendered(texture, _contract(), "synthetic_hinged", Vector2(128.0, 128.0), FULL)
			var double := _contract()
			double["door_kind"] = "double_hinged"
			await _test_rendered(texture, double, "synthetic_double", Vector2(128.0, 128.0), FULL)
			await _test_rendered(texture, _contract(), "synthetic_crop", Vector2(128.0, 128.0), Rect2(0.35, 0.35, 0.5, 0.5))
			await _test_store()
	var report := {"suite": "travel_entrance_view", "passed": failures.is_empty(), "checks": checks,
		"failures": failures, "rendered": "--pure-only" not in OS.get_cmdline_user_args(), "captures": captures}
	var evidence := OS.get_environment("BTH_QA_EVIDENCE_DIR")
	if not evidence.is_empty():
		var file := FileAccess.open(evidence.path_join("travel_entrance_view_report.json"), FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)


func _contract() -> Dictionary:
	# Deliberately stepped, with two upper corners inside its rectangular clip.
	return {"texture": "res://synthetic-exterior.png", "reference_size": [128, 128],
		"arrival_kind": "door", "door_kind": "hinged", "hinge_side": "left",
		"door_polygon_uv": [[0.25,0.375],[0.375,0.375],[0.375,0.25],[0.625,0.25],
			[0.625,0.375],[0.75,0.375],[0.75,0.875],[0.25,0.875]],
		"threshold_uv": [0.5,0.875], "inside_uv": [0.5,0.7], "road_y_uv": 0.95}


func _synthetic_texture() -> Texture2D:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			# Distinct paint, inset glass, handle and every-pixel source variation.
			var color := Color8(30 + x, 45 + y, 25 + (x + y) % 160)
			if x >= 46 and x < 78 and y >= 46 and y < 74: color = Color8(16, 173 + y % 40, 219)
			if x >= 79 and x < 84 and y >= 78 and y < 91: color = Color8(244, 191, 63)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _test_plans(texture: Texture2D) -> void:
	for kind in ["hinged", "double_hinged"]:
		for hinge in ["left", "right"]:
			var contract := _contract()
			contract["door_kind"] = kind
			contract["hinge_side"] = hinge
			var back := Entrance.new()
			var front := Entrance.new()
			back.size = Vector2(320, 180)
			front.size = back.size
			back.configure(texture, contract)
			front.configure(texture, contract, true)
			_expect(back.is_configured() and front.is_configured(), "valid " + kind + "/" + hinge)
			_expect(back.clip_contents and front.clip_contents, "stage clips both layers")
			_expect(back.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "nearest source pixels")
			for window in [FULL, Rect2(0.2, 0.1, 0.65, 0.8)]:
				for amount in [0.0, 0.25, 0.5, 1.0, 0.5, 0.0]:
					for inside in [false, true]:
						back.set_frame(window, amount, inside, true)
						front.set_frame(window, amount, inside, true)
						var b: Dictionary = back.draw_snapshot()
						var f: Dictionary = front.draw_snapshot()
						_expect(b["draw_interior"] == (inside or amount > 0.0) and not f["draw_interior"], "only back owns interior")
						_expect(b["panels"].is_empty() if inside or amount == 0.0 else not b["panels"].is_empty(), "back leaf ownership")
						_expect(not f["panels"].is_empty() if inside else f["panels"].is_empty(), "front leaf ownership")
						_expect(not f["frame_strips"].is_empty() if inside else f["frame_strips"].is_empty(), "front frame ownership")
						_expect(b["frame_strips"].is_empty(), "back never covers an outside actor with frame")
						_expect(back.portal_rect() == front.portal_rect(), "shared local portal clip")
						_expect(b["aperture"][0].is_equal_approx((Vector2(0.25,0.375) - window.position) / window.size * back.size), "full PNG crop mapping")
						for plan in [b, f]: _check_plan_geometry(plan)
				# Identical input after interruption/rewind must restore the same plan.
				back.set_frame(window, 0.5, false, true)
				var old: Dictionary = back.draw_snapshot()
				back.set_frame(window, 1.0, true, false)
				_expect(back.draw_snapshot().is_empty() and not back.visible, "hidden clears stale plan")
				back.set_frame(window, 0.5, false, true)
				_expect(back.draw_snapshot() == old, "reversible deterministic plan")
			back.free()
			front.free()


func _check_plan_geometry(plan: Dictionary) -> void:
	var aperture: PackedVector2Array = plan["aperture"]
	for panel in plan["panels"]:
		for fragment in panel["fragments"]:
			_expect(fragment["points"].size() == fragment["uvs"].size(), "textured fragment UV count")
			for index in fragment["points"].size():
				var point: Vector2 = fragment["points"][index]
				var uv: Vector2 = fragment["uvs"][index]
				_expect(point.is_finite() and _on_or_inside(point, aperture), "swing stays in measured aperture")
				_expect(uv.is_finite() and uv.x >= 0.0 and uv.y >= 0.0 and uv.x <= 1.0 and uv.y <= 1.0, "source UV bounded")
	for strip in plan["frame_strips"]:
		var middle := Vector2.ZERO
		for point in strip["points"]: middle += point
		middle /= strip["points"].size()
		_expect(not Geometry2D.is_point_in_polygon(middle, aperture), "frame strips preserve open aperture")


func _test_validation(texture: Texture2D) -> void:
	var bad: Array[Dictionary] = []
	for arrival in ["open", "passage", "dock", "", "invented"]:
		var contract := _contract(); contract["arrival_kind"] = arrival; bad.append(contract)
	for key in ["texture", "reference_size", "door_kind", "hinge_side", "door_polygon_uv", "threshold_uv", "inside_uv", "road_y_uv"]:
		var contract := _contract(); contract.erase(key); bad.append(contract)
	for value in [[], [[0.2,0.2],[0.8,0.8],[0.2,0.8],[0.8,0.2]], [[-0.1,0.2],[0.7,0.2],[0.5,0.8]], [[0.2,NAN],[0.7,0.2],[0.5,0.8]], [[0.2,0.2],[0.7,0.2],[0.7,0.2],[0.5,0.8]], [[0.2,0.2],[0.3,0.3],[0.4,0.4]]]:
		var contract := _contract(); contract["door_polygon_uv"] = value; bad.append(contract)
	for change in [{"reference_size":[1024,1024]}, {"road_y_uv":INF}, {"source_top_y_uv":-0.1}, {"hinge_side":"middle"}, {"door_kind":"glow"}, {"threshold_uv":[0.5,NAN]}, {"inside_uv":[0.5,1.5]}]:
		var contract := _contract(); contract.merge(change, true); bad.append(contract)
	var view := Entrance.new()
	view.size = Vector2(128,128)
	for contract in bad:
		view.configure(texture, _contract()); view.set_frame(FULL, 0.5, true, true)
		view.configure(texture, contract); view.set_frame(FULL, 0.5, true, true)
		_expect(not view.is_configured() and not view.visible and view.draw_snapshot().is_empty(), "malformed contract clears previous renderer")
	view.configure(null, _contract())
	_expect(not view.is_configured(), "missing texture fails closed")
	view.configure(texture, _contract())
	for window in [Rect2(), Rect2(-0.1,0.0,1.0,1.0), Rect2(0.0,0.0,1.1,1.0), Rect2(NAN,0.0,1.0,1.0), Rect2(0.5,0.5,-0.1,0.1)]:
		view.set_frame(window, 0.5, true, true)
		_expect(view.draw_snapshot().is_empty() and not view.visible, "invalid source crop fails closed")
	view.set_frame(FULL, NAN, true, true)
	_expect(view.draw_snapshot().is_empty(), "nonfinite opening fails closed")
	view.size = Vector2.ZERO; view.set_frame(FULL, 0.5, true, true)
	_expect(view.draw_snapshot().is_empty(), "zero stage fails closed")
	view.free()


func _test_rendered(texture: Texture2D, contract: Dictionary, label: String, stage_size: Vector2, window: Rect2) -> void:
	var scene := _render_scene(texture, contract, stage_size, window)
	var back = scene["back"]
	var front = scene["front"]
	_expect(back.is_configured() and front.is_configured(), label + " actual texture configures")
	if not back.is_configured():
		scene["viewport"].free()
		return
	back.set_frame(window, 0.0, false, false)
	front.set_frame(window, 0.0, false, false)
	var baseline: Image = await _capture(scene["viewport"])
	_expect(baseline != null and not baseline.is_empty(), label + " real renderer supplies pixels")
	if baseline == null or baseline.is_empty():
		scene["viewport"].free()
		return
	var area := Rect2(Vector2(16,16), stage_size)
	var sampled: Dictionary = {}
	for state in [{"name":"closed", "open":0.0, "inside":false}, {"name":"half", "open":0.5, "inside":false},
		{"name":"open", "open":1.0, "inside":false}, {"name":"inside_open", "open":1.0, "inside":true},
		{"name":"closing", "open":0.5, "inside":true}, {"name":"closed_inside", "open":0.0, "inside":true},
		{"name":"reopened", "open":0.5, "inside":false}]:
		back.set_frame(window, state["open"], state["inside"], true)
		front.set_frame(window, state["open"], state["inside"], true)
		var portal: Rect2 = back.portal_rect()
		scene["actor_clip"].position = portal.position
		scene["actor_clip"].size = portal.size
		scene["actor"].size = portal.size
		scene["actor_clip"].visible = state["inside"]
		var rendered: Image = await _capture(scene["viewport"])
		_save_capture(rendered, label + "_" + state["name"])
		sampled[state["name"]] = rendered
		var polygon: PackedVector2Array = back.draw_snapshot()["aperture"]
		var changed_inside := 0
		var actor_inside := 0
		var outside_changes := 0
		var outside_stage_changes := 0
		var outside_actor_pixels := 0
		var total_changes := 0
		for y in rendered.get_height():
			for x in rendered.get_width():
				var center := Vector2(x + 0.5,y + 0.5)
				var pixel := rendered.get_pixel(x,y)
				var changed := not _same_pixel(pixel, baseline.get_pixel(x,y))
				var in_aperture := Geometry2D.is_point_in_polygon(center - area.position, polygon)
				var actor := _same_pixel(pixel, ACTOR_COLOR)
				if changed: total_changes += 1
				if changed and in_aperture: changed_inside += 1
				if actor and in_aperture: actor_inside += 1
				if changed and not area.has_point(center): outside_stage_changes += 1
				# Raster boundary pixels may be assigned to either neighboring face.
				if not in_aperture and _edge_distance(center - area.position, polygon) > 1.1:
					if changed: outside_changes += 1
					if actor: outside_actor_pixels += 1
		_expect(outside_stage_changes == 0, label + "/" + state["name"] + " no stage spill")
		_expect(outside_changes == 0 and outside_actor_pixels == 0, label + "/" + state["name"] + " source wall preserved; actor clipped to shape")
		if state["open"] == 0.0:
			_expect(total_changes == 0, label + "/" + state["name"] + " restores exact original facade pixels, changes=" + str(total_changes))
			_expect(actor_inside == 0, label + "/" + state["name"] + " closed original door occludes inside actor")
		else:
			_expect(changed_inside > 10, label + "/" + state["name"] + " aperture actually opens")
			if state["inside"]: _expect(actor_inside > 10, label + "/" + state["name"] + " actor visible through open leaf")
			var owner: Dictionary = front.draw_snapshot() if state["inside"] else back.draw_snapshot()
			_verify_textured_pixels(rendered, texture.get_image(), owner, area.position, label + "/" + state["name"])
	_expect(_images_equal(sampled["half"], sampled["reopened"]), label + " reopen is pixel reversible")
	scene["viewport"].free()


func _verify_textured_pixels(rendered: Image, source: Image, plan: Dictionary, offset: Vector2, label: String) -> void:
	var tested := 0
	for panel in plan["panels"]:
		for fragment in panel["fragments"]:
			var points: PackedVector2Array = fragment["points"]
			var uvs: PackedVector2Array = fragment["uvs"]
			var middle := Vector2.ZERO
			for point in points: middle += point
			middle /= points.size()
			var pixel := Vector2i((middle + offset).floor())
			var local := Vector2(pixel) + Vector2(0.5,0.5) - offset
			if not Rect2(Vector2.ZERO, plan["stage_rect"].size).has_point(local) or _edge_distance(local, points) < 1.1: continue
			# Independently invert the actual drawn fragment's affine transform.
			# Verify that window/handle/paint pixels come from the original PNG,
			# rather than merely proving that a differently colored opening exists.
			var indices := Geometry2D.triangulate_polygon(points)
			if indices.size() < 3: continue
			var a := indices[0]; var b := indices[1]; var c := indices[2]
			var edge_b := points[b] - points[a]
			var edge_c := points[c] - points[a]
			var delta := local - points[a]
			var determinant := edge_b.cross(edge_c)
			if absf(determinant) < 0.001: continue
			var weight_b := delta.cross(edge_c) / determinant
			var weight_c := edge_b.cross(delta) / determinant
			var uv := uvs[a] + (uvs[b] - uvs[a]) * weight_b + (uvs[c] - uvs[a]) * weight_c
			var native := uv * Vector2(source.get_size())
			var fraction := native - native.floor()
			if fraction.x < 0.03 or fraction.x > 0.97 or fraction.y < 0.03 or fraction.y > 0.97: continue
			var sample := Vector2i(native.floor()).clamp(Vector2i.ZERO, source.get_size() - Vector2i.ONE)
			_expect(_same_pixel(rendered.get_pixelv(pixel), source.get_pixelv(sample)), label + " transformed leaf samples original full-PNG pixels")
			tested += 1
	# Very narrow, almost edge-on leaves may have no safe interior sample.
	if plan["opening"] == 0.5:
		_expect(tested > 0, label + " has verified textured leaf samples")


func _render_scene(texture: Texture2D, contract: Dictionary, stage_size: Vector2, window: Rect2) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(stage_size + Vector2(32,32))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var outside := ColorRect.new()
	outside.color = Color("#283840")
	outside.size = Vector2(viewport.size)
	viewport.add_child(outside)
	var stage := Control.new()
	stage.position = Vector2(16,16)
	stage.size = stage_size
	stage.clip_contents = true
	viewport.add_child(stage)
	var background := SourceBackground.new()
	background.source = texture
	background.window = window
	background.size = stage_size
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage.add_child(background)
	var back := Entrance.new()
	back.size = stage_size
	back.configure(texture, contract)
	stage.add_child(back)
	var actor_clip := Control.new()
	actor_clip.clip_contents = true
	actor_clip.visible = false
	stage.add_child(actor_clip)
	var actor := ColorRect.new()
	actor.color = ACTOR_COLOR
	actor_clip.add_child(actor)
	var front := Entrance.new()
	front.size = stage_size
	front.configure(texture, contract, true)
	stage.add_child(front)
	return {"viewport":viewport, "back":back, "front":front, "actor":actor, "actor_clip":actor_clip}


func _test_store() -> void:
	var path := "res://data/art/travel_exteriors_urban.json"
	_expect(FileAccess.file_exists(path), "actual store contract exists")
	if not FileAccess.file_exists(path): return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: _expect(false, "store JSON readable"); return
	var contract: Dictionary = data.get("exteriors", {}).get("corner_store", {})
	_expect(not contract.is_empty(), "actual store has exterior contract")
	if contract.is_empty(): return
	var image := Image.load_from_file(ProjectSettings.globalize_path(contract["texture"]))
	_expect(image != null and not image.is_empty(), "actual store PNG readable without imported substitute")
	if image == null or image.is_empty(): return
	await _test_rendered(ImageTexture.create_from_image(image), contract, "actual_corner_store", Vector2(640,320), FULL)


func _capture(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _save_capture(image: Image, name: String) -> void:
	var evidence := OS.get_environment("BTH_QA_EVIDENCE_DIR")
	if evidence.is_empty(): _expect(false, "capture requires guarded evidence directory"); return
	var path := evidence.path_join(name + ".png")
	_expect(image.save_png(path) == OK, "save actual " + name + " render")
	captures.append(path)


func _same_pixel(a: Color, b: Color) -> bool:
	return absf(a.r-b.r) < 0.006 and absf(a.g-b.g) < 0.006 and absf(a.b-b.b) < 0.006 and absf(a.a-b.a) < 0.006


func _images_equal(a: Image, b: Image) -> bool:
	return a.get_size() == b.get_size() and a.get_data() == b.get_data()


func _edge_distance(point: Vector2, polygon: PackedVector2Array) -> float:
	var distance := INF
	for index in polygon.size():
		distance = minf(distance, point.distance_to(Geometry2D.get_closest_point_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()])))
	return distance


func _on_or_inside(point: Vector2, polygon: PackedVector2Array) -> bool:
	return Geometry2D.is_point_in_polygon(point, polygon) or _edge_distance(point, polygon) < 0.001


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
