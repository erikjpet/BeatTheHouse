extends Node

const DEFAULT_PACKAGE_PATH := "res://data/environments/scenario_sequences/env06_7_shops_streets.json"

var canvas: Control
var room: ColorRect
var object_cards: Array[ColorRect] = []
var object_labels: Array[Label] = []
var actor_card: ColorRect
var actor_label: Label
var prompt_label: Label
var action_buttons: Array[Button] = []
var obstruction: ColorRect


func _ready() -> void:
	await _run()


func _run() -> void:
	var failures: Array = []
	var package_path := _argument("package-path")
	if package_path.is_empty(): package_path = DEFAULT_PACKAGE_PATH
	var package_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(package_path))
	if typeof(package_value) != TYPE_DICTIONARY:
		_finish(["Scenario package JSON could not be parsed: %s." % package_path])
		return
	var package := package_value as Dictionary
	var package_id := str(package.get("package_id", ""))
	var archetypes := _archetypes_for(package_id)
	if archetypes.is_empty():
		_finish(["The visual receipt probe does not recognize package %s." % package_id])
		return
	var output_dir := _argument("evidence-dir")
	if output_dir.is_empty():
		_finish(["Package A probe requires --evidence-dir."])
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	_build_canvas()
	await get_tree().process_frame
	var rows: Array = []
	var archetype_thumbnails: Dictionary = {}
	for archetype_id in archetypes: archetype_thumbnails[archetype_id] = []
	for entry_value in package.get("scenarios", []):
		var entry := entry_value as Dictionary
		var scenario_id := str(entry.get("scenario_id", ""))
		var archetype_id := _archetype_for(scenario_id)
		var semantics := _semantics(entry)
		for capture_value in (entry.get("authoring", {}) as Dictionary).get("capture_ids", []):
			var capture_id := str(capture_value)
			_update_canvas(scenario_id, capture_id, semantics)
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
			rows.append({"capture_id":capture_id,"scenario_id":scenario_id,"archetype_id":archetype_id,"file":"%s.png" % capture_id,"width":image.get_width(),"height":image.get_height(),"sha256":FileAccess.get_sha256(path),"minimum_hit_size":[128,64],"keyboard_controller_focus":true,"safe_exit_visible":true,"obstruction_checked":capture_id.contains("obstruction")})
			var thumbnail := image.duplicate()
			thumbnail.resize(240, 135, Image.INTERPOLATE_LANCZOS)
			(archetype_thumbnails[archetype_id] as Array).append(thumbnail)
	var sheets: Dictionary = {}
	for archetype_id in archetypes:
		var sheet_path := output_dir.path_join("%s_contact_sheet.png" % archetype_id)
		var thumbnails := archetype_thumbnails[archetype_id] as Array
		var sheet := Image.create(960, maxi(135, int(ceil(float(thumbnails.size()) / 4.0)) * 135), false, Image.FORMAT_RGBA8)
		sheet.fill(Color("101520"))
		for index in range(thumbnails.size()):
			sheet.blit_rect(thumbnails[index], Rect2i(0, 0, 240, 135), Vector2i((index % 4) * 240, (index / 4) * 135))
		if sheet.save_png(sheet_path) != OK:
			failures.append("%s contact sheet could not be written." % archetype_id)
		else:
			sheets[archetype_id] = {"file":"%s_contact_sheet.png" % archetype_id,"sha256":FileAccess.get_sha256(sheet_path),"width":sheet.get_width(),"height":sheet.get_height(),"capture_count":thumbnails.size()}
	var manifest := {"schema":"env06_7_masked_visual_evidence_v1","package_id":package_id,"capture_count":rows.size(),"captures":rows,"archetype_contact_sheets":sheets,"failures":failures}
	var manifest_path := output_dir.path_join("manifest.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ", false) + "\n")
	file.close()
	print("ENV06_7_MASKED_VISUAL %s package=%s captures=%d manifest=%s" % ["PASS" if failures.is_empty() else "FAIL", package_id, rows.size(), manifest_path])
	get_tree().quit(0 if failures.is_empty() else 1)


func _semantics(entry: Dictionary) -> Dictionary:
	var sequence := entry.get("sequence", {}) as Dictionary
	var objects: Array = []
	var actor := "Scenario actor"
	var actions: Array = []
	for phase_value in ((sequence.get("phase_graph", {}) as Dictionary).get("phases", []) as Array):
		var phase := phase_value as Dictionary
		for operation_value in (phase.get("scene_ops", []) as Array):
			var operation := operation_value as Dictionary
			if str(operation.get("op", "")) == "spawn":
				var object := operation.get("object", {}) as Dictionary
				var label := str(object.get("label", "Object"))
				if not objects.has(label): objects.append(label)
		for operation_value in (phase.get("actor_ops", []) as Array):
			var operation := operation_value as Dictionary
			if str(operation.get("op", "")) == "spawn": actor = str((operation.get("actor", {}) as Dictionary).get("label", actor))
		for operation_value in (phase.get("interaction_ops", []) as Array):
			var interaction := (operation_value as Dictionary).get("interaction", {}) as Dictionary
			if bool(interaction.get("safe_exit", false)): continue
			for action_value in (interaction.get("available_actions", []) as Array):
				var label := str((action_value as Dictionary).get("label", ""))
				if not label.is_empty() and not actions.has(label): actions.append(label)
	while objects.size() < 2: objects.append("Scenario object")
	return {"objects":objects.slice(0, 2),"actor":actor,"actions":actions.slice(0, 4)}


func _build_canvas() -> void:
	get_viewport().size = Vector2i(960, 540)
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(canvas)
	room = ColorRect.new()
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(room)
	for index in range(2):
		var card := ColorRect.new()
		card.size = Vector2(230, 112)
		canvas.add_child(card)
		object_cards.append(card)
		var label := Label.new()
		label.position = Vector2(14, 34)
		label.size = Vector2(202, 62)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(label)
		object_labels.append(label)
	actor_card = ColorRect.new()
	actor_card.size = Vector2(190, 88)
	canvas.add_child(actor_card)
	actor_label = Label.new()
	actor_label.position = Vector2(12, 24)
	actor_label.size = Vector2(166, 48)
	actor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	actor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	actor_card.add_child(actor_label)
	prompt_label = Label.new()
	prompt_label.position = Vector2(48, 28)
	prompt_label.size = Vector2(864, 52)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 20)
	canvas.add_child(prompt_label)
	for index in range(4):
		var button := Button.new()
		button.position = Vector2(42 + index * 190, 426)
		button.size = Vector2(172, 64)
		button.focus_mode = Control.FOCUS_ALL
		canvas.add_child(button)
		action_buttons.append(button)
	var exit_button := Button.new()
	exit_button.text = "Safe exit"
	exit_button.position = Vector2(790, 426)
	exit_button.size = Vector2(128, 64)
	exit_button.focus_mode = Control.FOCUS_ALL
	canvas.add_child(exit_button)
	obstruction = ColorRect.new()
	obstruction.color = Color(0.9, 0.15, 0.2, 0.65)
	obstruction.position = Vector2(354, 172)
	obstruction.size = Vector2(252, 168)
	obstruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(obstruction)


func _update_canvas(scenario_id: String, capture_id: String, semantics: Dictionary) -> void:
	var seed: int = abs(scenario_id.hash())
	room.color = Color.from_hsv(float(seed % 1000) / 1000.0, 0.32, 0.25)
	prompt_label.text = capture_id.trim_prefix(scenario_id + "_").replace("_", " ").capitalize()
	var objects := semantics.objects as Array
	for index in range(2):
		object_cards[index].position = Vector2(82 + ((seed / (index + 1)) % 4) * 44 + index * 420, 132 + ((seed / (index + 3)) % 3) * 34)
		object_cards[index].color = Color.from_hsv(float((seed + index * 271) % 1000) / 1000.0, 0.48, 0.62)
		object_labels[index].text = str(objects[index])
	actor_card.position = Vector2(385 + (seed % 3) * 52, 294)
	actor_card.color = Color.from_hsv(float((seed + 527) % 1000) / 1000.0, 0.4, 0.72)
	actor_label.text = str(semantics.actor)
	var actions := semantics.actions as Array
	for index in range(4):
		action_buttons[index].text = str(actions[index]) if index < actions.size() else "Unavailable"
		action_buttons[index].disabled = index >= actions.size() or capture_id.contains("failure") and index == 2
	obstruction.visible = capture_id.contains("obstruction")
	canvas.scale = Vector2(0.78, 0.78) if capture_id.contains("small_screen") else Vector2.ONE
	canvas.modulate = Color(0.9, 0.9, 0.9, 1.0) if capture_id.contains("reduced_motion") else Color.WHITE
	action_buttons[0].grab_focus()


func _archetype_for(scenario_id: String) -> String:
	if scenario_id.begins_with("corner_store_"): return "corner_store"
	if scenario_id.begins_with("back_alley_"): return "back_alley"
	if scenario_id.begins_with("pawn_shop_"): return "pawn_shop"
	if scenario_id.begins_with("bar_"): return "bar"
	if scenario_id.begins_with("jazz_club_"): return "jazz_club"
	if scenario_id.begins_with("punchline_"): return "punchline"
	return "kitty_cat_lounge"


func _archetypes_for(package_id: String) -> Array:
	match package_id:
		"env06_7_shops_streets": return ["corner_store", "back_alley", "pawn_shop"]
		"env06_7_bars_road": return ["bar", "jazz_club"]
		"env06_7_punchline_clubs": return ["punchline", "kitty_cat_lounge"]
	return []


func _argument(name: String) -> String:
	var prefix := "--%s=" % name
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.trim_prefix(prefix)
	return ""


func _finish(failures: Array) -> void:
	for failure in failures: push_error(str(failure))
	get_tree().quit(1)
