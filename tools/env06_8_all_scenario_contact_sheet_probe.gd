extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const SequenceCatalogScript := preload("res://scripts/core/scenario_sequence_catalog.gd")
const ReadabilityContractScript := preload("res://scripts/tests/foundation/env06_8_environment_readability_contract.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")

const CELL_SIZE := Vector2i(320, 180)
const MASTER_COLUMNS := 5

var _canvas: Control


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := _argument("evidence-dir")
	if output_dir.is_empty():
		output_dir = "res://.tmp/env06_8_contact_sheets"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	root.size = Vector2i(960, 540)
	_canvas = PixelSceneCanvasScript.new()
	_canvas.position = Vector2(30.0, 55.0)
	_canvas.size = Vector2(900.0, 430.0)
	root.add_child(_canvas)
	await process_frame

	var library := ContentLibraryScript.new()
	library.load()
	var definitions: Array = []
	for pool_value in library.environment_scenarios.values():
		for definition_value in _array(pool_value):
			var definition := SequenceCatalogScript.apply_overlay(_dict(definition_value), library.scenario_sequence_catalog)
			if not _dict(definition.get("sequence", {})).is_empty():
				definitions.append(definition)
	definitions.sort_custom(func(a: Variant, b: Variant) -> bool: return str(_dict(a).get("id", "")) < str(_dict(b).get("id", "")))
	var failures: Array = []
	var scenario_rows: Array = []
	var master_thumbnails: Array[Image] = []
	for definition_value in definitions:
		var definition := _dict(definition_value)
		var scenario_id := str(definition.get("id", ""))
		var archetype_id := str(definition.get("archetype_id", ""))
		var host := ReadabilityContractScript._production_host_semantics(library, definition, failures)
		var observer := ReadabilityContractScript._reachable_presentation_observer(definition, host, false, failures)
		var snapshots := _representative_snapshots(_array(observer.get("snapshots", [])))
		print("ENV06_8_CONTACT_SCENARIO %s reachable=%d captures=%d" % [scenario_id, int(observer.get("reachable_state_count", 0)), snapshots.size()])
		var state_rows: Array = []
		var thumbnails: Array[Image] = []
		for snapshot_value in snapshots:
			var snapshot := _dict(snapshot_value)
			var records: Array = []
			var icon_keys: Array = []
			for row_value in _array(snapshot.get("rows", [])):
				var row := _dict(row_value)
				var icon_key := str(row.get("icon", ""))
				icon_keys.append(icon_key)
				records.append({
					"object_id": str(row.get("id", "")),
					"object_type": str(row.get("object_type", "scenario_scene_object")),
					"visual_type": str(row.get("visual_type", "scenario_object")),
					"label": "",
					"short_description": str(row.get("description", "")),
					"icon_key": icon_key,
					"interactive": true,
					"enabled": true,
					"visible": true,
					"scenario_presentation_read_only": bool(row.get("read_only", false)),
					"normalized_rect": _dict(row.get("normalized_rect", {})),
					"small_screen_rect": _dict(row.get("small_screen_rect", {})),
					"scenario_layout_resolved": true,
					"scenario_z_order": records.size(),
					"semantic_state": str(row.get("state", "")),
				})
			_canvas.render_environment_snapshot({
				"archetype_id": archetype_id,
				"display_name": "",
				"interactable_objects": records,
				"reduce_motion": true,
				"small_screen_mode": false,
			})
			await process_frame
			await process_frame
			var viewport_texture := root.get_texture()
			if viewport_texture == null:
				failures.append("env06_8 raster capture requires a rendering display driver; the active driver returned no viewport texture.")
				break
			var image := viewport_texture.get_image()
			if image == null or image.is_empty():
				failures.append("env06_8 %s produced an empty unlabeled state raster." % scenario_id)
				continue
			var thumbnail := image.duplicate()
			thumbnail.resize(CELL_SIZE.x, CELL_SIZE.y, Image.INTERPOLATE_LANCZOS)
			thumbnails.append(thumbnail)
			state_rows.append({
				"phase_id": str(snapshot.get("phase_id", "")),
				"status": str(snapshot.get("status", "")),
				"outcomes": _array(snapshot.get("outcomes", [])),
				"object_count": records.size(),
				"icon_keys": icon_keys,
				"description_set_sha256": JSON.stringify(snapshot.get("rows", [])).sha256_text(),
			})
		var sheet_path := output_dir.path_join("%s_unlabeled_contact_sheet.png" % scenario_id)
		var sheet := _contact_sheet(thumbnails, 4)
		if sheet.is_empty() or sheet.save_png(sheet_path) != OK:
			failures.append("env06_8 %s unlabeled contact sheet could not be written." % scenario_id)
			continue
		var master := sheet.duplicate()
		master.resize(CELL_SIZE.x, CELL_SIZE.y, Image.INTERPOLATE_LANCZOS)
		master_thumbnails.append(master)
		scenario_rows.append({
			"scenario_id": scenario_id,
			"archetype_id": archetype_id,
			"file": sheet_path.get_file(),
			"sha256": FileAccess.get_sha256(sheet_path),
			"reachable_state_count": int(observer.get("reachable_state_count", 0)),
			"state_count": state_rows.size(),
			"states": state_rows,
			"unlabeled": true,
		})
	var master_path := output_dir.path_join("env06_8_all_55_unlabeled_contact_sheet.png")
	var master_sheet := _contact_sheet(master_thumbnails, MASTER_COLUMNS)
	if master_sheet.is_empty() or master_sheet.save_png(master_path) != OK:
		failures.append("env06_8 all-scenario unlabeled contact sheet could not be written.")
	var manifest := {
		"schema": "env06_8_all_scenario_contact_sheets_v1",
		"scenario_count": scenario_rows.size(),
		"expected_scenario_count": 55,
		"unlabeled": true,
		"scenarios": scenario_rows,
		"master_file": master_path.get_file(),
		"master_sha256": FileAccess.get_sha256(master_path) if FileAccess.file_exists(master_path) else "",
		"failures": failures,
	}
	if scenario_rows.size() != 55:
		failures.append("env06_8 contact-sheet runner expected 55 scenarios, rendered %d." % scenario_rows.size())
		manifest["failures"] = failures
	var manifest_path := output_dir.path_join("manifest.json")
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		failures.append("env06_8 contact-sheet manifest could not be written.")
	else:
		manifest_file.store_string(JSON.stringify(manifest, "  ", false) + "\n")
		manifest_file.close()
	print("ENV06_8_CONTACT_SHEETS_%s scenarios=%d master=%s manifest=%s" % ["PASS" if failures.is_empty() else "FAIL", scenario_rows.size(), master_path, manifest_path])
	for failure_value in failures:
		printerr("ENV06_8_CONTACT_SHEETS_FAIL %s" % str(failure_value))
	quit(0 if failures.is_empty() else 1)


func _contact_sheet(images: Array, columns: int) -> Image:
	if images.is_empty():
		return Image.new()
	var rows := int(ceil(float(images.size()) / float(columns)))
	var sheet := Image.create(CELL_SIZE.x * columns, CELL_SIZE.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("101520"))
	for index in range(images.size()):
		var source := images[index] as Image
		sheet.blit_rect(source, Rect2i(Vector2i.ZERO, CELL_SIZE), Vector2i((index % columns) * CELL_SIZE.x, int(index / columns) * CELL_SIZE.y))
	return sheet


func _representative_snapshots(snapshots: Array) -> Array:
	var representatives: Array = []
	var seen: Dictionary = {}
	for snapshot_value in snapshots:
		var snapshot := _dict(snapshot_value)
		var key := "%s|%s|%s" % [str(snapshot.get("phase_id", "")), str(snapshot.get("status", "")), JSON.stringify(snapshot.get("outcomes", []))]
		if seen.has(key):
			continue
		seen[key] = true
		representatives.append(snapshot)
	return representatives


func _argument(name: String) -> String:
	var prefix := "--%s=" % name
	for argument_value in OS.get_cmdline_user_args():
		var argument := str(argument_value)
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
