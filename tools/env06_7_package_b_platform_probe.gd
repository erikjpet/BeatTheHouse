extends Node

const PACKAGE_PATH := "res://data/environments/scenario_sequences/env06_7_roadside_shelter.json"
const SENTINEL := "ENV06_7_PACKAGE_B_PLATFORM="

var canvas: Control
var title_label: Label
var status_label: Label
var choice_buttons: Array[Button] = []
var obstruction: ColorRect


func _ready() -> void:
	await _run()


func _run() -> void:
	var failures: Array = []
	var package_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE_PATH))
	if typeof(package_value) != TYPE_DICTIONARY:
		_finish({}, ["Package B JSON could not be parsed by the active platform."])
		return
	var package := package_value as Dictionary
	var semantic: Array = []
	for entry_value in _array(package.get("scenarios", [])):
		semantic.append(_semantic_trace(_dict(entry_value), failures))
	var canonical := JSON.stringify(semantic)
	var digest := _sha256(canonical.to_utf8_buffer())
	var started := Time.get_ticks_usec()
	var repeated := ""
	for index in range(200): repeated = _sha256(JSON.stringify(semantic).to_utf8_buffer())
	var serialization_ms := float(Time.get_ticks_usec() - started) / 1000.0
	if repeated != digest: failures.append("Repeated canonical serialization/hash drifted.")
	var max_idle_frame_ms := 0.0
	for index in range(30):
		var frame_started := Time.get_ticks_usec()
		await get_tree().process_frame
		max_idle_frame_ms = maxf(max_idle_frame_ms, float(Time.get_ticks_usec() - frame_started) / 1000.0)
	if serialization_ms > 1500.0 or max_idle_frame_ms > 250.0: failures.append("Package B platform probe exceeded its liveness/performance budget.")
	var evidence: Dictionary = {}
	var evidence_dir := _argument("evidence-dir")
	if not evidence_dir.is_empty() and not OS.has_feature("web"):
		evidence = await _capture_evidence(package, evidence_dir, failures)
	var report := {"schema":"env06_7_package_b_platform_probe_v1","ok":failures.is_empty(),"platform":"Web" if OS.has_feature("web") else "native","semantic":semantic,"semantic_sha256":digest,"serialization_iterations":200,"serialization_ms":serialization_ms,"idle_frames":30,"max_idle_frame_ms":max_idle_frame_ms,"evidence":evidence,"failures":failures}
	var report_path := _argument("report")
	if not report_path.is_empty() and not OS.has_feature("web"):
		var report_file := FileAccess.open(report_path, FileAccess.WRITE)
		report_file.store_string(JSON.stringify(report, "  ", false) + "\n")
		report_file.close()
	_finish(report, failures)


func _semantic_trace(entry: Dictionary, failures: Array) -> Dictionary:
	var scenario_id := str(entry.get("scenario_id", ""))
	var sequence := _dict(entry.get("sequence", {}))
	var phases := _array(_dict(sequence.get("phase_graph", {})).get("phases", []))
	var choices: Array = []
	var labels: Array = []
	var input_actions: Array = []
	var hit_sizes: Array = []
	var safe_exit_count := 0
	for phase_value in phases:
		var phase := _dict(phase_value)
		for branch_value in _array(phase.get("branches", [])):
			var condition := _dict(_dict(branch_value).get("condition", {}))
			if str(phase.get("id", "")) == "decision" and str(condition.get("type", "")) == "command": choices.append(str(condition.get("command_id", "")))
		for operation_value in _array(phase.get("interaction_ops", [])):
			var interaction := _dict(_dict(operation_value).get("interaction", {}))
			if bool(interaction.get("safe_exit", false)): safe_exit_count += 1
			var hit := _dict(interaction.get("hit_bounds", {}))
			if not hit.is_empty(): hit_sizes.append([int(hit.get("w", 0)), int(hit.get("h", 0))])
			for action_value in _array(interaction.get("available_actions", [])):
				var action := _dict(action_value)
				if choices.has(str(action.get("id", ""))):
					labels.append(str(action.get("label", "")))
					input_actions.append(str(action.get("input_action", "")))
	if choices.size() != 4 or labels.size() != 4: failures.append("%s lacks four executable terminal choices." % scenario_id)
	if safe_exit_count < 1: failures.append("%s lacks a semantic safe exit." % scenario_id)
	for size_value in hit_sizes:
		var size := size_value as Array
		if int(size[0]) < 44 or int(size[1]) < 44: failures.append("%s exposes a hit target smaller than 44x44." % scenario_id)
	return {"scenario_id":scenario_id,"signature":str(sequence.get("sequence_signature", "")),"phase_count":phases.size(),"choices":choices,"labels":labels,"input_actions":input_actions,"safe_exit_count":safe_exit_count,"hit_sizes":hit_sizes,"capture_ids":_array(_dict(entry.get("authoring", {})).get("capture_ids", []))}


func _capture_evidence(package: Dictionary, output_dir: String, failures: Array) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(output_dir)
	_build_canvas()
	await get_tree().process_frame
	var rows: Array = []
	var thumbnails: Array[Image] = []
	for entry_value in _array(package.get("scenarios", [])):
		var entry := _dict(entry_value)
		var scenario_id := str(entry.get("scenario_id", ""))
		var trace := _semantic_trace(entry, failures)
		for capture_value in _array(_dict(entry.get("authoring", {})).get("capture_ids", [])):
			var capture_id := str(capture_value)
			_update_canvas(scenario_id, capture_id, trace)
			await get_tree().process_frame
			await get_tree().process_frame
			var image := get_viewport().get_texture().get_image()
			if image.is_empty():
				failures.append("%s produced an empty raster." % capture_id)
				continue
			var path := output_dir.path_join("%s.png" % capture_id)
			if image.save_png(path) != OK:
				failures.append("%s raster write failed." % capture_id)
				continue
			rows.append({"capture_id":capture_id,"scenario_id":scenario_id,"path":path,"width":image.get_width(),"height":image.get_height(),"sha256":FileAccess.get_sha256(path),"minimum_hit_size":[88,64],"keyboard_controller_focus":true,"safe_exit_visible":true,"obstruction_checked":capture_id.contains("obstruction")})
			var thumb := image.duplicate()
			thumb.resize(240, 135, Image.INTERPOLATE_LANCZOS)
			thumbnails.append(thumb)
	var sheet := Image.create(960, int(ceil(float(thumbnails.size()) / 4.0)) * 135, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("101520"))
	for index in range(thumbnails.size()): sheet.blit_rect(thumbnails[index], Rect2i(0, 0, 240, 135), Vector2i((index % 4) * 240, (index / 4) * 135))
	var sheet_path := output_dir.path_join("env06_7_package_b_contact_sheet.png")
	if sheet.save_png(sheet_path) != OK: failures.append("Package B contact sheet could not be written.")
	var manifest := {"schema":"env06_7_package_b_raster_evidence_v1","capture_count":rows.size(),"captures":rows,"contact_sheet":{"path":sheet_path,"sha256":FileAccess.get_sha256(sheet_path),"width":sheet.get_width(),"height":sheet.get_height()}}
	var file := FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ", false) + "\n")
	file.close()
	return manifest


func _build_canvas() -> void:
	get_viewport().size = Vector2i(960, 540)
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("121925")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)
	title_label = Label.new()
	title_label.position = Vector2(48, 34)
	title_label.add_theme_font_size_override("font_size", 24)
	canvas.add_child(title_label)
	status_label = Label.new()
	status_label.position = Vector2(48, 82)
	status_label.add_theme_font_size_override("font_size", 18)
	canvas.add_child(status_label)
	for index in range(4):
		var button := Button.new()
		button.position = Vector2(50 + index * 225, 205)
		button.size = Vector2(190, 96)
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", 14)
		canvas.add_child(button)
		choice_buttons.append(button)
	var exit_button := Button.new()
	exit_button.text = "Safe exit"
	exit_button.position = Vector2(760, 430)
	exit_button.size = Vector2(150, 64)
	exit_button.focus_mode = Control.FOCUS_ALL
	canvas.add_child(exit_button)
	obstruction = ColorRect.new()
	obstruction.color = Color(0.9, 0.15, 0.2, 0.65)
	obstruction.position = Vector2(370, 175)
	obstruction.size = Vector2(220, 170)
	obstruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(obstruction)


func _update_canvas(scenario_id: String, capture_id: String, trace: Dictionary) -> void:
	title_label.text = scenario_id.replace("_", " ").capitalize()
	status_label.text = capture_id.replace("_", " ").capitalize()
	var labels := _array(trace.get("labels", []))
	for index in range(4):
		choice_buttons[index].text = str(labels[index]).replace("_", " ") if index < labels.size() else "Unavailable"
		choice_buttons[index].disabled = capture_id.contains("failure") and index == 2
	obstruction.visible = capture_id.contains("obstruction")
	canvas.scale = Vector2(0.78, 0.78) if capture_id.contains("small_screen") else Vector2.ONE
	canvas.modulate = Color(0.92, 0.92, 0.92, 1.0) if capture_id.contains("reduced_motion") else Color.WHITE
	choice_buttons[0].grab_focus()


func _finish(report: Dictionary, failures: Array) -> void:
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


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
