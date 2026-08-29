extends Node

const PACKAGE_PATH := "res://data/environments/scenario_sequences/env06_7_queen_public.json"
const SENTINEL := "ENV06_7_PACKAGE_E_PLATFORM="

var canvas: Control
var title_label: Label
var status_label: Label
var route_buttons: Array[Button] = []
var obstruction: ColorRect

func _ready() -> void:
	await _run()

func _run() -> void:
	var failures: Array = []
	var package_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE_PATH))
	if typeof(package_value) != TYPE_DICTIONARY:
		_finish({}, ["Package E JSON could not be parsed by the active platform."])
		return
	var package := package_value as Dictionary
	var semantic: Array = []
	for entry_value in _array(package.get("scenarios", [])):
		semantic.append(_semantic_trace(_dict(entry_value), failures))
	var canonical := JSON.stringify(semantic)
	var digest := _sha256(canonical.to_utf8_buffer())
	var benchmark_started := Time.get_ticks_usec()
	var repeated := ""
	for index in range(200): repeated = _sha256(JSON.stringify(semantic).to_utf8_buffer())
	var benchmark_ms := float(Time.get_ticks_usec() - benchmark_started) / 1000.0
	if repeated != digest: failures.append("Repeated canonical serialization/hash drifted.")
	var frame_rows: Array = []
	for index in range(30):
		var frame_started := Time.get_ticks_usec()
		await get_tree().process_frame
		frame_rows.append(float(Time.get_ticks_usec() - frame_started) / 1000.0)
	var max_idle_frame_ms := 0.0
	for value in frame_rows: max_idle_frame_ms = maxf(max_idle_frame_ms, float(value))
	if benchmark_ms > 1500.0 or max_idle_frame_ms > 250.0: failures.append("Package E platform probe exceeded its bounded idle/performance budget.")
	var evidence_dir := _argument("evidence-dir")
	var evidence_manifest: Dictionary = {}
	if not evidence_dir.is_empty() and not OS.has_feature("web"):
		evidence_manifest = await _capture_evidence(package, evidence_dir, failures)
	var report := {
		"schema":"env06_7_package_e_platform_probe_v1",
		"ok":failures.is_empty(),
		"platform":"Web" if OS.has_feature("web") else "native",
		"semantic":semantic,
		"semantic_sha256":digest,
		"serialization_iterations":200,
		"serialization_ms":benchmark_ms,
		"idle_frames":frame_rows.size(),
		"max_idle_frame_ms":max_idle_frame_ms,
		"evidence":evidence_manifest,
		"failures":failures,
	}
	_finish(report, failures)

func _semantic_trace(entry: Dictionary, failures: Array) -> Dictionary:
	var sid := str(entry.get("scenario_id", ""))
	var sequence := _dict(entry.get("sequence", {}))
	var evidence := _dict(_dict(entry.get("authoring", {})).get("seed_evidence", {}))
	var decision_phase := str(evidence.get("identity_decision_phase", ""))
	var choices := _array(evidence.get("identity_decision_verbs", []))
	var targets: Array = []
	var zones: Array = []
	var inputs: Array = []
	for phase_value in _array(_dict(sequence.get("phase_graph", {})).get("phases", [])):
		var phase := _dict(phase_value)
		if str(phase.get("id", "")) != decision_phase: continue
		var scene_by_id: Dictionary = {}
		for operation_value in _array(phase.get("scene_ops", [])):
			var operation := _dict(operation_value)
			scene_by_id[str(operation.get("stable_object_id", ""))] = _dict(operation.get("object", {}))
		for operation_value in _array(phase.get("interaction_ops", [])):
			var operation := _dict(operation_value)
			if str(operation.get("op", "")) != "add": continue
			var interaction := _dict(operation.get("interaction", {}))
			for action_value in _array(interaction.get("available_actions", [])):
				var action := _dict(action_value)
				if not choices.has(str(action.get("id", ""))): continue
				var target := str(interaction.get("stable_object_id", ""))
				targets.append(target)
				zones.append(str(_dict(scene_by_id.get(target, {})).get("zone_id", "")))
				inputs.append(str(action.get("input_action", "")))
	if targets.size() != 3 or _unique_count(targets) != 3 or _unique_count(zones) != 3 or _unique_count(inputs) != 3:
		failures.append("%s platform trace lacks three distinct target/zone/input routes." % sid)
	return {"scenario_id":sid,"signature":str(sequence.get("sequence_signature", "")),"decision_phase":decision_phase,"choices":choices,"targets":targets,"zones":zones,"inputs":inputs,"capture_ids":_array(_dict(entry.get("authoring", {})).get("capture_ids", []))}

func _capture_evidence(package: Dictionary, output_dir: String, failures: Array) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(output_dir)
	_build_canvas()
	await get_tree().process_frame
	var rows: Array = []
	var thumbnails: Array[Image] = []
	for entry_value in _array(package.get("scenarios", [])):
		var entry := _dict(entry_value)
		var sid := str(entry.get("scenario_id", ""))
		var trace := _semantic_trace(entry, failures)
		var captures := _array(_dict(entry.get("authoring", {})).get("capture_ids", []))
		for capture_index in range(captures.size()):
			var capture_id := str(captures[capture_index])
			_update_canvas(sid, capture_id, trace, capture_index)
			await get_tree().process_frame
			await get_tree().process_frame
			var image := get_viewport().get_texture().get_image()
			if image.is_empty():
				failures.append("%s produced an empty raster." % capture_id)
				continue
			var path := output_dir.path_join("%s.png" % capture_id)
			var error := image.save_png(path)
			if error != OK:
				failures.append("%s raster write failed with %d." % [capture_id,error])
				continue
			rows.append({"capture_id":capture_id,"scenario_id":sid,"path":path,"width":image.get_width(),"height":image.get_height(),"sha256":FileAccess.get_sha256(path),"route_targets":trace.targets,"zones":trace.zones,"minimum_hit_size":Vector2(88,64),"obstruction_checked":capture_id.ends_with("_obstruction")})
			var thumb := image.duplicate()
			thumb.resize(240,135,Image.INTERPOLATE_LANCZOS)
			thumbnails.append(thumb)
	var sheet := Image.create(960, int(ceil(float(thumbnails.size()) / 4.0)) * 135, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("101520"))
	for index in range(thumbnails.size()): sheet.blit_rect(thumbnails[index],Rect2i(0,0,240,135),Vector2i((index % 4) * 240,(index / 4) * 135))
	var sheet_path := output_dir.path_join("env06_7_package_e_contact_sheet.png")
	if sheet.save_png(sheet_path) != OK: failures.append("Package E contact sheet could not be written.")
	var manifest := {"schema":"env06_7_package_e_raster_evidence_v1","capture_count":rows.size(),"captures":rows,"contact_sheet":{"path":sheet_path,"sha256":FileAccess.get_sha256(sheet_path),"width":sheet.get_width(),"height":sheet.get_height()}}
	var manifest_path := output_dir.path_join("manifest.json")
	var file := FileAccess.open(manifest_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"  ",false)+"\n")
	file.close()
	manifest["manifest_path"] = manifest_path
	return manifest

func _build_canvas() -> void:
	get_viewport().size = Vector2i(960,540)
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("121925")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)
	title_label = Label.new()
	title_label.position = Vector2(48,34)
	title_label.add_theme_font_size_override("font_size",24)
	canvas.add_child(title_label)
	status_label = Label.new()
	status_label.position = Vector2(48,82)
	status_label.add_theme_font_size_override("font_size",18)
	canvas.add_child(status_label)
	for index in range(3):
		var button := Button.new()
		button.position = Vector2(90 + index * 290,205)
		button.size = Vector2(230,96)
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size",16)
		canvas.add_child(button)
		route_buttons.append(button)
	var exit_button := Button.new()
	exit_button.text = "Safe exit"
	exit_button.position = Vector2(760,430)
	exit_button.size = Vector2(150,64)
	exit_button.focus_mode = Control.FOCUS_ALL
	canvas.add_child(exit_button)
	obstruction = ColorRect.new()
	obstruction.color = Color(0.9,0.15,0.2,0.65)
	obstruction.position = Vector2(370,175)
	obstruction.size = Vector2(220,170)
	obstruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(obstruction)

func _update_canvas(sid: String, capture_id: String, trace: Dictionary, capture_index: int) -> void:
	title_label.text = sid.replace("_"," ").capitalize()
	status_label.text = capture_id.replace("_"," ").capitalize()
	for index in range(3):
		var choices := _array(trace.get("choices", []))
		var zones := _array(trace.get("zones", []))
		route_buttons[index].text = "%s\nZone: %s" % [str(choices[index]).replace("_"," ").capitalize(),str(zones[index])]
		route_buttons[index].disabled = capture_id.ends_with("_failure") and index == 2
		route_buttons[index].modulate = Color(0.75 + 0.08 * index,0.86 - 0.07 * index,1.0,1.0)
	obstruction.visible = capture_id.ends_with("_obstruction")
	canvas.scale = Vector2(0.78,0.78) if capture_id.ends_with("_small_screen") else Vector2.ONE
	canvas.modulate = Color(0.92,0.92,0.92,1.0) if capture_id.ends_with("_reduced_motion") else Color.WHITE
	if capture_index == 0: route_buttons[0].grab_focus()

func _finish(report: Dictionary, failures: Array) -> void:
	if report.is_empty(): report = {"schema":"env06_7_package_e_platform_probe_v1","ok":false,"platform":"Web" if OS.has_feature("web") else "native","semantic":[],"semantic_sha256":"","failures":failures}
	print(SENTINEL + JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)

func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _argument(name: String) -> String:
	var prefix := "--%s=" % name
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.trim_prefix(prefix)
	return ""

func _unique_count(values: Array) -> int:
	var result: Dictionary = {}
	for value in values: result[str(value)] = true
	return result.size()

func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []

func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
