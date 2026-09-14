extends SceneTree

# Interactive, production-input playtest bridge. Commands arrive as numbered
# files; every command is answered with a screenshot and player-observable JSON.

const MainScene := preload("res://scenes/main.tscn")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")

var app: Control
var session_name := "session"
var session_dir := ""
var next_command := 1
var shutting_down := false


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--session="):
			session_name = argument.trim_prefix("--session=").strip_edges()
		elif argument.begins_with("--session-dir="):
			session_dir = argument.trim_prefix("--session-dir=").strip_edges()
	call_deferred("_boot")


func _boot() -> void:
	if session_dir.is_empty():
		push_error("agent_playtest_session requires --session-dir=<absolute path>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(session_dir)
	_ensure_isolated_persistence_directories()
	next_command = _discover_next_command_number()
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate() as Control
	if app == null:
		push_error("Could not instantiate res://scenes/main.tscn.")
		quit(2)
		return
	root.add_child(app)
	await _wait_frames(8)
	_write_json(_path("ready.json"), {
		"ready": true,
		"session": session_name,
		"pid": OS.get_process_id(),
		"viewport": {"width": root.size.x, "height": root.size.y},
		"persistence": {
			"distribution_root": OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT"),
			"settings": OS.get_environment("BTH_USER_SETTINGS_PATH"),
			"profile_inventory": OS.get_environment("BTH_PROFILE_INVENTORY_PATH"),
			"meta_collection": OS.get_environment("BTH_META_COLLECTION_PATH"),
		},
	})
	while not shutting_down:
		await _poll_once()
		await create_timer(0.05).timeout


func _ensure_isolated_persistence_directories() -> void:
	for environment_name in [
		"BTH_DISTRIBUTION_DATA_ROOT",
		"BTH_USER_SETTINGS_PATH",
		"BTH_PROFILE_INVENTORY_PATH",
		"BTH_META_COLLECTION_PATH",
	]:
		var configured_path := OS.get_environment(environment_name).strip_edges()
		if not configured_path.begins_with("user://"):
			continue
		var directory_path := configured_path if environment_name == "BTH_DISTRIBUTION_DATA_ROOT" else configured_path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory_path))


func _poll_once() -> void:
	var command_path := _path("%04d.command.txt" % next_command)
	if not FileAccess.file_exists(command_path):
		return
	var file := FileAccess.open(command_path, FileAccess.READ)
	var raw := file.get_as_text().strip_edges() if file != null else ""
	if file != null:
		file.close()
	var result := await _execute_command(raw, next_command)
	_write_json(_path("%04d.result.json" % next_command), result)
	next_command += 1
	if bool(result.get("quit", false)):
		shutting_down = true
		await process_frame
		quit(0)


func _execute_command(raw: String, command_number: int) -> Dictionary:
	var accepted := false
	var reason := ""
	var detail: Dictionary = {}
	var should_quit := false
	if raw.is_empty():
		reason = "empty command"
	else:
		var verb := raw.get_slice(" ", 0).to_lower()
		var argument := raw.substr(verb.length()).strip_edges()
		match verb:
			"look":
				accepted = true
			"click_button":
				var clicked := await _click_button(argument)
				accepted = bool(clicked.get("ok", false))
				reason = str(clicked.get("reason", ""))
				detail = clicked
			"click_object":
				var double_click := argument.ends_with(" double")
				var semantic_id := argument.trim_suffix(" double").strip_edges()
				var clicked := await _click_object(semantic_id, double_click)
				accepted = bool(clicked.get("ok", false))
				reason = str(clicked.get("reason", ""))
				detail = clicked
			"click_action":
				var clicked := await _click_action(argument)
				accepted = bool(clicked.get("ok", false))
				reason = str(clicked.get("reason", ""))
				detail = clicked
			"click_xy":
				var clicked := await _click_xy(argument)
				accepted = bool(clicked.get("ok", false))
				reason = str(clicked.get("reason", ""))
				detail = clicked
			"key":
				var keyed := await _push_key(argument)
				accepted = bool(keyed.get("ok", false))
				reason = str(keyed.get("reason", ""))
				detail = keyed
			"type":
				var typed := await _type_text(argument)
				accepted = bool(typed.get("ok", false))
				reason = str(typed.get("reason", ""))
				detail = typed
			"wait":
				var frames := int(argument)
				if frames < 0 or frames > 3600:
					reason = "frames must be between 0 and 3600"
				else:
					await _wait_frames(frames)
					accepted = true
					detail = {"frames": frames}
			"quit":
				accepted = true
				should_quit = true
			_:
				reason = "unknown command: %s" % verb
	await _wait_frames(4)
	var look := await _capture_look(command_number)
	return _json_safe({
		"session": session_name,
		"command_number": command_number,
		"command": raw,
		"accepted": accepted,
		"reason": reason,
		"detail": detail,
		"look": look,
		"quit": should_quit,
	})


func _click_button(target: String) -> Dictionary:
	if target.is_empty():
		return {"ok": false, "reason": "button text or id is required"}
	var buttons := _visible_buttons()
	var id_matches: Array = []
	var text_matches: Array = []
	for entry_value in buttons:
		var entry := entry_value as Dictionary
		if str(entry.get("id", "")) == target:
			id_matches.append(entry)
		if str(entry.get("text", "")) == target:
			text_matches.append(entry)
	var matches := id_matches if not id_matches.is_empty() else text_matches
	if matches.is_empty():
		return {"ok": false, "reason": "visible enabled button not found: %s" % target}
	if matches.size() > 1:
		var ids: Array[String] = []
		for match_value in matches:
			ids.append(str((match_value as Dictionary).get("id", "")))
		return {"ok": false, "reason": "ambiguous button text; use one of these ids: %s" % ", ".join(ids)}
	var data := matches[0] as Dictionary
	var button := data.get("node") as Button
	if button == null or not button.is_visible_in_tree() or button.disabled:
		return {"ok": false, "reason": "button became hidden or disabled before click"}
	var clicked_id := str(data.get("id", ""))
	var clicked_text := button.text
	var click_position: Vector2 = data.get("click_position", button.get_global_rect().get_center())
	await _push_mouse_click(click_position, false)
	return {"ok": true, "id": clicked_id, "text": clicked_text}


func _click_object(semantic_id: String, double_click: bool) -> Dictionary:
	var canvas := app.get("environment_canvas") as Control
	var failures: Array = []
	var routed := Fidelity.push_exact_canvas_mouse_click(
		app.get_viewport(), canvas, semantic_id, failures,
		"agent playtest %s command" % session_name, double_click
	)
	if not bool(routed.get("ok", false)):
		return {"ok": false, "reason": "; ".join(failures)}
	return {
		"ok": true,
		"semantic_id": semantic_id,
		"double": double_click,
		"global_hit_position": routed.get("global_hit_position", Vector2.ZERO),
	}


func _click_action(argument: String) -> Dictionary:
	var parts := argument.split(" ", false)
	if parts.is_empty():
		return {"ok": false, "reason": "game action is required"}
	var action := argument.strip_edges()
	var index := 0
	var has_index := parts.size() > 1 and str(parts[parts.size() - 1]).is_valid_int()
	if has_index:
		var index_text := str(parts[parts.size() - 1])
		index = int(index_text)
		action = action.trim_suffix(" %s" % index_text).strip_edges()
	var surface := app.get("game_surface_canvas") as Control
	if surface != null and surface.visible and surface.has_method("local_position_for_surface_action"):
		var available := false
		for value in _game_surface_actions(surface):
			var hit := value as Dictionary
			if str(hit.get("action", "")) == action and (not has_index or int(hit.get("index", 0)) == index):
				available = bool(hit.get("enabled", true))
				index = int(hit.get("index", 0))
				break
		if not available:
			return {"ok": false, "reason": "game-surface action not found or disabled: %s %d" % [action, index]}
		if surface.has_method("surface_action_is_blocked") and bool(surface.call("surface_action_is_blocked", action)):
			return {"ok": false, "reason": "game-surface action is currently blocked by animation: %s" % action}
		var local: Vector2 = surface.call("local_position_for_surface_action", action, index)
		if not _inside_control(surface, local):
			return {"ok": false, "reason": "game-surface action has no hittable visible position"}
		await _push_mouse_click(surface.get_global_rect().position + local, false)
		return {"ok": true, "action": action, "index": index, "surface": "game"}
	var room := app.get("environment_canvas") as Control
	if room != null and room.visible and room.has_method("local_position_for_selected_info_action_button"):
		var actions := _room_selected_actions(room)
		for action_index in range(actions.size()):
			var data := actions[action_index] as Dictionary
			if not _room_action_matches(data, action, index, action_index):
				continue
			if bool(data.get("disabled", false)) or not bool(data.get("enabled", true)):
				return {"ok": false, "reason": "room action is disabled: %s" % action}
			var local: Vector2 = room.call("local_position_for_selected_info_action_button", action_index)
			if not _inside_control(room, local):
				return {"ok": false, "reason": "room action has no hittable visible position"}
			await _push_mouse_click(room.get_global_rect().position + local, false)
			return {"ok": true, "action": action, "index": action_index, "surface": "room"}
	return {"ok": false, "reason": "no visible game or selected-room action: %s %d" % [action, index]}


func _room_action_matches(data: Dictionary, requested: String, requested_index: int, actual_index: int) -> bool:
	if requested.is_valid_int() and int(requested) == actual_index:
		return true
	if requested_index != actual_index and requested == "index":
		return false
	for key in ["id", "action", "action_id", "emit_object_id", "label"]:
		if str(data.get(key, "")) == requested:
			return true
	return false


func _click_xy(argument: String) -> Dictionary:
	var parts := argument.split(" ", false)
	if parts.size() < 2 or not str(parts[0]).is_valid_float() or not str(parts[1]).is_valid_float():
		return {"ok": false, "reason": "usage: click_xy <x> <y> [double]"}
	var point := Vector2(float(parts[0]), float(parts[1]))
	if point.x < 0.0 or point.y < 0.0 or point.x > root.size.x or point.y > root.size.y:
		return {"ok": false, "reason": "coordinates are outside the 1280x720 viewport"}
	var double_click := parts.size() > 2 and str(parts[2]).to_lower() == "double"
	await _push_mouse_click(point, double_click)
	return {"ok": true, "position": point, "double": double_click}


func _push_key(key_name: String) -> Dictionary:
	var cleaned := key_name.strip_edges()
	if cleaned.is_empty():
		return {"ok": false, "reason": "key name is required"}
	var pieces := cleaned.split("+", false)
	var base_name := str(pieces[pieces.size() - 1]).strip_edges()
	var ctrl := false
	var alt := false
	var shift := false
	for piece_index in range(pieces.size() - 1):
		var modifier := str(pieces[piece_index]).strip_edges().to_lower()
		ctrl = ctrl or modifier in ["ctrl", "control"]
		alt = alt or modifier == "alt"
		shift = shift or modifier == "shift"
	var keycode := OS.find_keycode_from_string(base_name)
	if keycode == KEY_NONE and base_name.length() == 1:
		keycode = base_name.to_upper().unicode_at(0)
	if keycode == KEY_NONE:
		return {"ok": false, "reason": "unknown key name: %s" % cleaned}
	var press := InputEventKey.new()
	press.pressed = true
	press.keycode = keycode
	press.ctrl_pressed = ctrl
	press.alt_pressed = alt
	press.shift_pressed = shift
	if base_name.length() == 1 and not ctrl and not alt:
		press.unicode = base_name.unicode_at(0)
	app.get_viewport().push_input(press, true)
	await process_frame
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	app.get_viewport().push_input(release, true)
	await process_frame
	return {"ok": true, "key": cleaned}


func _type_text(value: String) -> Dictionary:
	var focus := root.gui_get_focus_owner()
	if focus == null or not (focus is LineEdit or focus is TextEdit):
		return {"ok": false, "reason": "focused control is not a text field"}
	for character in value:
		var event := InputEventKey.new()
		event.pressed = true
		event.unicode = character.unicode_at(0)
		app.get_viewport().push_input(event, true)
		await process_frame
		var release := event.duplicate() as InputEventKey
		release.pressed = false
		app.get_viewport().push_input(release, true)
	return {"ok": true, "characters": value.length(), "focused_id": str(focus.get_path())}


func _push_mouse_click(position: Vector2, double_click: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	app.get_viewport().push_input(motion, true)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.double_click = double_click
	press.position = position
	press.global_position = position
	app.get_viewport().push_input(press, true)
	await process_frame
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.button_mask = 0
	app.get_viewport().push_input(release, true)
	await process_frame


func _capture_look(command_number: int) -> Dictionary:
	await RenderingServer.frame_post_draw
	var image_path := _path("%04d.png" % command_number)
	var image := root.get_texture().get_image()
	var image_error := image.save_png(image_path)
	var observable := Fidelity.observable_host_snapshot(app)
	var room_canvas := app.get("environment_canvas") as Control
	var game_canvas := app.get("game_surface_canvas") as Control
	return {
		"png": image_path,
		"png_error": error_string(image_error) if image_error != OK else "",
		"observable": observable,
		"clickable": {
			"buttons": _public_buttons(),
			"text_fields": _visible_text_fields(),
			"canvas_objects": _canvas_objects(room_canvas),
			"room_actions": _room_selected_actions(room_canvas),
			"game_surface_actions": _game_surface_actions(game_canvas),
		},
	}


func _visible_buttons() -> Array:
	var result: Array = []
	_collect_buttons(app, result)
	return result


func _collect_buttons(node: Node, result: Array) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is Button:
		var button := node as Button
		var visible_rect := _clipped_control_rect(button)
		if button.is_visible_in_tree() and not button.disabled and visible_rect.has_area():
			result.append({
				"node": button,
				"id": str(button.get_path()),
				"text": button.text.strip_edges(),
				"rect": visible_rect,
				"click_position": visible_rect.get_center(),
			})
	for child in node.get_children():
		_collect_buttons(child, result)


func _public_buttons() -> Array:
	var result: Array = []
	for entry_value in _visible_buttons():
		var entry := entry_value as Dictionary
		result.append({
			"id": entry.get("id", ""),
			"text": entry.get("text", ""),
			"enabled": true,
			"rect": entry.get("rect", Rect2()),
		})
	return result


func _visible_text_fields() -> Array:
	var result: Array = []
	_collect_text_fields(app, result)
	return result


func _collect_text_fields(node: Node, result: Array) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is LineEdit:
		var field := node as LineEdit
		var visible_rect := _clipped_control_rect(field)
		if field.is_visible_in_tree() and field.editable and visible_rect.has_area():
			result.append({"id": str(field.get_path()), "text": field.text, "placeholder": field.placeholder_text, "rect": visible_rect, "focused": field.has_focus()})
	elif node is TextEdit:
		var field := node as TextEdit
		var visible_rect := _clipped_control_rect(field)
		if field.is_visible_in_tree() and field.editable and visible_rect.has_area():
			result.append({"id": str(field.get_path()), "rect": visible_rect, "focused": field.has_focus()})
	for child in node.get_children():
		_collect_text_fields(child, result)


func _clipped_control_rect(control: Control) -> Rect2:
	if control == null or not control.is_visible_in_tree():
		return Rect2()
	var visible_rect := control.get_global_rect().intersection(Rect2(Vector2.ZERO, Vector2(root.size)))
	var ancestor := control.get_parent()
	while ancestor != null and visible_rect.has_area():
		if ancestor is Control and (ancestor as Control).clip_contents:
			visible_rect = visible_rect.intersection((ancestor as Control).get_global_rect())
		ancestor = ancestor.get_parent()
	return visible_rect


func _canvas_objects(canvas: Control) -> Array:
	if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
		return []
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	var result: Array = []
	for value in _array(snapshot.get("objects", [])):
		var data := value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
		if data.is_empty() or not bool(data.get("visible", true)):
			continue
		result.append({
			"semantic_id": str(data.get("id", data.get("object_id", ""))),
			"label": str(data.get("label", "")),
			"object_type": str(data.get("object_type", data.get("type", ""))),
			"enabled": bool(data.get("enabled", true)) and not bool(data.get("disabled", false)) and bool(data.get("interactive", true)),
		})
	return result


func _room_selected_actions(canvas: Control) -> Array:
	if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
		return []
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	var selected := snapshot.get("selected_info", {}) as Dictionary if typeof(snapshot.get("selected_info", {})) == TYPE_DICTIONARY else {}
	var result: Array = []
	var actions := _array(selected.get("actions", []))
	for index in range(actions.size()):
		var action := actions[index] as Dictionary if typeof(actions[index]) == TYPE_DICTIONARY else {}
		if action.is_empty():
			continue
		var copy := action.duplicate(true)
		copy["index"] = index
		copy["enabled"] = bool(action.get("enabled", true)) and not bool(action.get("disabled", false))
		result.append(copy)
	return result


func _game_surface_actions(canvas: Control) -> Array:
	if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
		return []
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	var result: Array = []
	for value in _array(snapshot.get("surface_hit_actions", [])):
		var action := value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
		if action.is_empty():
			continue
		var copy := action.duplicate(true)
		copy["enabled"] = not (canvas.has_method("surface_action_is_blocked") and bool(canvas.call("surface_action_is_blocked", str(action.get("action", "")))))
		result.append(copy)
	return result


func _inside_control(control: Control, local: Vector2) -> bool:
	return local.x >= 0.0 and local.y >= 0.0 and local.x <= control.size.x and local.y <= control.size.y


func _wait_frames(frames: int) -> void:
	for _frame in range(frames):
		await process_frame


func _path(file_name: String) -> String:
	return session_dir.path_join(file_name)


func _discover_next_command_number() -> int:
	var highest := 0
	for file_name in DirAccess.get_files_at(session_dir):
		if not file_name.ends_with(".result.json"):
			continue
		var stem := file_name.get_slice(".", 0)
		if stem.is_valid_int():
			highest = maxi(highest, int(stem))
	return highest + 1


func _write_json(path: String, payload: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s." % path)
		return
	file.store_string(JSON.stringify(_json_safe(payload), "\t"))
	file.close()


func _json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var result := {}
			for key in (value as Dictionary).keys():
				result[str(key)] = _json_safe((value as Dictionary).get(key))
			return result
		TYPE_ARRAY:
			var result: Array = []
			for item in value as Array:
				result.append(_json_safe(item))
			return result
		TYPE_VECTOR2:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR2I:
			return {"x": value.x, "y": value.y}
		TYPE_RECT2:
			return {"x": value.position.x, "y": value.position.y, "w": value.size.x, "h": value.size.y}
		TYPE_RECT2I:
			return {"x": value.position.x, "y": value.position.y, "w": value.size.x, "h": value.size.y}
		TYPE_COLOR:
			return value.to_html(true)
		TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY:
			var result: Array = []
			for item in value:
				result.append(_json_safe(item))
			return result
		TYPE_OBJECT:
			return str(value)
		_:
			return value


func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []
