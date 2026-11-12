extends "res://scripts/tests/travel_entrance_view_check.gd"

# Synthetic presentation fixtures only: these screenshots do not certify legal routes.
const Catalog := preload("res://scripts/ui/travel_presentation_catalog.gd")
const Overlay := preload("res://scripts/ui/travel_cinematic_overlay.gd")
const INDOORS := ["corner_store", "motel", "bar", "gas_station_casino", "small_underground_casino", "jazz_club", "kitty_cat_lounge", "pawn_shop", "grand_casino", "motel_room", "apartment", "house"]
var destination_evidence: Array = []

class MissingInteriorOverlay extends Overlay:
	var blocked_path := ""
	func _load_art(path: String) -> Texture2D:
		return null if path == blocked_path else super._load_art(path)

func _receipt(destination: String) -> Dictionary:
	return {"schema_version":1, "journey_id":"synthetic_interior_" + destination,
		"presentation_key":Catalog.STANDARD_KEY, "travel_method_kind":"walk",
		"effective_destination_archetype_id":destination, "origin_label":"Synthetic visual fixture",
		"destination_label":destination.replace("_", " ").capitalize(),
		"receipt_text":"Synthetic visual-only preview. Not a legal-route proof."}

func _run() -> void:
	var paths: Dictionary = {}
	var hashes: Dictionary = {}
	var rendered := "--pure-only" not in OS.get_cmdline_user_args()
	if rendered: _expect(DisplayServer.get_name() != "headless", "real renderer required for pixel certification")
	for destination in Catalog.EXTERIOR_IDS:
		var profile: Dictionary = Catalog.profile(_receipt(destination))
		var path := str(profile.get("doorway_path", ""))
		if destination not in INDOORS:
			_expect(path.is_empty(), destination + " outdoor arrival has no invented interior")
			continue
		_expect(not path.is_empty() and path == str(profile["exterior"].get("doorway_texture", "")), destination + " maps its authored interior")
		_expect(not paths.has(path), destination + " unique interior path")
		paths[path] = true
		if path.is_empty() or not FileAccess.file_exists(path):
			_expect(false, destination + " interior PNG exists")
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_expect(image != null and not image.is_empty(), destination + " interior decodes")
		if image == null or image.is_empty(): continue
		var hash_value := FileAccess.get_sha256(path)
		_expect(not hashes.has(hash_value), destination + " distinct interior PNG bytes")
		hashes[hash_value] = true
		var overlay := Overlay.new()
		root.add_child(overlay)
		overlay.present(_receipt(destination))
		overlay.set_process(false)
		_expect(bool(overlay.snapshot().get("doorway_has_art", false)) and not bool(overlay.snapshot()["static"]), destination + " actual overlay loads interior")
		overlay.free()
		var missing := MissingInteriorOverlay.new()
		missing.blocked_path = path
		root.add_child(missing)
		missing.present(_receipt(destination))
		_expect(missing.phase == "receipt" and bool(missing.snapshot()["static"]), destination + " missing interior fails to static receipt")
		missing.free()
		if rendered and DisplayServer.get_name() != "headless":
			await _render_interior(destination, profile, ImageTexture.create_from_image(image))
	_expect(paths.size() == 12 and hashes.size() == 12, "all twelve indoor destinations have separate interior PNGs")
	var report := {"suite":"travel_doorway_interior", "checks":checks, "passed":failures.is_empty(),
		"failures":failures, "rendered":rendered, "scope":"synthetic visual-only fixtures, not legal route proof",
		"destinations":destination_evidence, "captures":captures}
	var evidence := OS.get_environment("BTH_QA_EVIDENCE_DIR")
	if not evidence.is_empty():
		var file := FileAccess.open(evidence.path_join("travel_doorway_interior_report.json"), FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _render_interior(destination: String, profile: Dictionary, interior: Texture2D) -> void:
	var contract: Dictionary = profile["exterior"]
	var image := Image.load_from_file(ProjectSettings.globalize_path(contract["texture"]))
	var texture := ImageTexture.create_from_image(image)
	var window := Rect2(0.18, float(profile["source_top_y_uv"]), float(profile["source_width_uv"]), float(profile["view_height_uv"]))
	var scene := _render_scene(texture, contract, Vector2(1152,500), window)
	var back = scene["back"]
	var front = scene["front"]
	back.configure(texture, contract, false, interior)
	front.configure(texture, contract, true, interior)
	back.set_frame(window, 0.0, false, false)
	front.set_frame(window, 0.0, false, false)
	var baseline: Image = await _capture(scene["viewport"])
	back.set_frame(window, 0.0, false, true)
	front.set_frame(window, 0.0, false, true)
	var closed: Image = await _capture(scene["viewport"])
	_expect(_images_equal(baseline, closed), destination + " closed door remains byte-identical")
	back.set_frame(window, 1.0, false, true)
	front.set_frame(window, 1.0, false, true)
	var opened: Image = await _capture(scene["viewport"])
	_save_capture(opened, "synthetic_doorway_" + destination + "_open")
	var polygon: PackedVector2Array = back.draw_snapshot()["aperture"]
	var outside_changes := 0
	var colored_changes := 0
	var colors: Dictionary = {}
	for y in opened.get_height():
		for x in opened.get_width():
			var point := Vector2(x + 0.5, y + 0.5) - Vector2(16,16)
			var color := opened.get_pixel(x,y)
			var changed := not _same_pixel(color, baseline.get_pixel(x,y))
			var inside := Geometry2D.is_point_in_polygon(point, polygon)
			if changed and not inside and _edge_distance(point, polygon) > 1.1: outside_changes += 1
			if changed and inside and _edge_distance(point, polygon) > 2.0:
				colors[color.to_html(false)] = true
				if maxf(color.r,maxf(color.g,color.b)) - minf(color.r,minf(color.g,color.b)) > 0.08: colored_changes += 1
	_expect(outside_changes == 0, destination + " opening never spills beyond measured aperture")
	_expect(colored_changes > 50 and colors.size() > 30, destination + " actual open doorway shows varied colored texture, not a gray fill")
	# Compare the actual center of the uncovered interior against an independent
	# bottom-aligned cover-crop, excluding the projected original door leaves.
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon: bounds = bounds.expand(point)
	var source_size := Vector2(interior.get_width(), interior.get_height())
	var scale_value := maxf(bounds.size.x / source_size.x, bounds.size.y / source_size.y)
	var drawn_size := source_size * scale_value
	var origin := Vector2(bounds.get_center().x - drawn_size.x * 0.5, bounds.end.y - drawn_size.y)
	var verified := 0
	var mismatched := 0
	for y in range(int(bounds.position.y) + 3, int(bounds.end.y) - 3, 5):
		for x in range(int(bounds.position.x) + 3, int(bounds.end.x) - 3, 5):
			var point := Vector2(x + 0.5,y + 0.5)
			if not Geometry2D.is_point_in_polygon(point, polygon) or _edge_distance(point, polygon) < 2.0: continue
			var leaf := false
			for panel in back.draw_snapshot()["panels"]:
				for fragment in panel["fragments"]:
					if Geometry2D.is_point_in_polygon(point, fragment["points"]) or _edge_distance(point, fragment["points"]) < 2.0: leaf = true
			if leaf: continue
			var native := (point - origin) / scale_value
			var fraction := native - native.floor()
			# GPU affine interpolation may round either way exactly on a texel
			# edge. Certify only unambiguous source-pixel centers, as the leaf suite does.
			if fraction.x < 0.03 or fraction.x > 0.97 or fraction.y < 0.03 or fraction.y > 0.97: continue
			var source := native.floor()
			var pixel := Vector2i(point.floor()) + Vector2i(16,16)
			if not Rect2i(Vector2i.ZERO, opened.get_size()).has_point(pixel): continue
			verified += 1
			if not _same_pixel(opened.get_pixelv(pixel), interior.get_image().get_pixelv(Vector2i(source))): mismatched += 1
	_expect(verified > 20 and mismatched == 0, destination + " real interior pixels match independent bottom-aligned cover crop (%d/%d mismatch)" % [mismatched,verified])
	destination_evidence.append({"destination":destination, "path":profile["doorway_path"], "outside_changes":outside_changes,
		"colored_changes":colored_changes, "distinct_colors":colors.size(), "verified_source_samples":verified, "source_mismatches":mismatched})
	scene["viewport"].free()
