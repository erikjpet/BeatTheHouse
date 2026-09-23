extends SceneTree

# Interactive, production-input playtest bridge. Commands arrive as numbered
# files; every command is answered with a screenshot and player-observable JSON.

const MainScene := preload("res://scenes/main.tscn")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const PublicObservation := preload("res://tools/agent_playtest_public_observation.gd")
const REPLAY_PAUSE_OWNER := "agent_replay"

var app: Control
var session_name := "session"
var session_dir := ""
var next_command := 1
var shutting_down := false
var committed_start_seed_text := ""


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
	if not app.has_method("set_application_pause_owner") or not app.has_method("application_lifecycle_snapshot"):
		push_error("Production host does not expose replay pause ownership.")
		quit(2)
		return
	app.call("set_application_pause_owner", REPLAY_PAUSE_OWNER, true)
	await process_frame
	var ready_pause := _replay_pause_snapshot()
	if not _replay_pause_is_valid(ready_pause):
		push_error("Could not acquire deterministic replay pause ownership: %s" % JSON.stringify(ready_pause))
		quit(2)
		return
	_write_json(_path("ready.json"), {
		"ready": true,
		"session": session_name,
		"pid": OS.get_process_id(),
		"viewport": {"width": root.size.x, "height": root.size.y},
		"replay_pause": ready_pause,
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
	var before_observable := _public_observation()
	var pause_before := _replay_pause_snapshot()
	var accepted := false
	var reason := ""
	var detail: Dictionary = {}
	var should_quit := false
	if not _replay_pause_is_valid(pause_before):
		reason = "deterministic replay pause ownership was lost before command"
	elif raw.is_empty():
		reason = "empty command"
	else:
		var verb := raw.get_slice(" ", 0).to_lower()
		var argument := raw.substr(verb.length()).strip_edges()
		match verb:
			"look":
				accepted = true
			"focus_field":
				var focused := await _focus_field(argument)
				accepted = bool(focused.get("ok", false))
				reason = str(focused.get("reason", ""))
				detail = focused
			"set_field":
				var set_result := await _set_field(argument)
				accepted = bool(set_result.get("ok", false))
				reason = str(set_result.get("reason", ""))
				detail = set_result
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
			"click_map":
				var clicked := await _click_map_node(argument)
				accepted = bool(clicked.get("ok", false))
				reason = str(clicked.get("reason", ""))
				detail = clicked
			"click_choice":
				var clicked := await _click_choice(argument)
				accepted = bool(clicked.get("ok", false))
				reason = str(clicked.get("reason", ""))
				detail = clicked
			"scroll_surface":
				var scrolled := await _scroll_surface(argument)
				accepted = bool(scrolled.get("ok", false))
				reason = str(scrolled.get("reason", ""))
				detail = scrolled
			"click_inventory":
				var clicked := await _click_inventory_item(argument)
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
	var transition := PublicObservation.transition_summary(
		before_observable,
		_dict(look.get("observable", {})),
		raw,
		accepted
	)
	return _json_safe({
		"session": session_name,
		"command_number": command_number,
		"command": raw,
		"accepted": accepted,
		"reason": reason,
		"detail": detail,
		"look": look,
		"replay_pause_before": pause_before,
		"trace": transition,
		"quit": should_quit,
	})


func _focus_field(target: String) -> Dictionary:
	var cleaned := target.strip_edges()
	if cleaned.is_empty():
		return {"ok": false, "reason": "field alias or id is required"}
	var matches: Array = []
	for entry_value in _visible_text_field_nodes():
		var entry := entry_value as Dictionary
		var field := entry.get("node") as Control
		if field == null:
			continue
		var aliases: Array[String] = [
			str(entry.get("id", "")),
			str(field.name),
			str(entry.get("placeholder", "")),
		]
		if field == app.get("seed_input"):
			aliases.append("seed")
		if field == app.get("game_test_seed_input"):
			aliases.append("practice_seed")
		if aliases.has(cleaned):
			matches.append(entry)
	if matches.is_empty():
		return {"ok": false, "reason": "visible editable field not found: %s" % cleaned}
	if matches.size() > 1:
		var ids: Array[String] = []
		for match_value in matches:
			ids.append(str((match_value as Dictionary).get("id", "")))
		return {"ok": false, "reason": "ambiguous field alias; use one of these ids: %s" % ", ".join(ids)}
	var data := matches[0] as Dictionary
	var field := data.get("node") as Control
	var visible_rect: Rect2 = data.get("rect", Rect2())
	if field == null or not field.is_visible_in_tree() or not visible_rect.has_area():
		return {"ok": false, "reason": "field became hidden before focus"}
	await _push_mouse_click(visible_rect.get_center(), false)
	await process_frame
	if root.gui_get_focus_owner() != field:
		return {"ok": false, "reason": "field did not receive focus: %s" % str(data.get("id", ""))}
	return {"ok": true, "field": cleaned, "id": str(data.get("id", ""))}


func _set_field(argument: String) -> Dictionary:
	var separator := argument.find(" ")
	if separator <= 0:
		return {"ok": false, "reason": "usage: set_field <alias-or-id> <value>"}
	var target := argument.substr(0, separator).strip_edges()
	var value := argument.substr(separator + 1)
	var focused := await _focus_field(target)
	if not bool(focused.get("ok", false)):
		return focused
	var selected := await _push_key("ctrl+a")
	if not bool(selected.get("ok", false)):
		return selected
	var typed := await _type_text(value)
	if not bool(typed.get("ok", false)):
		return typed
	var field := root.gui_get_focus_owner()
	var visible_value := ""
	if field is LineEdit:
		visible_value = (field as LineEdit).text
	elif field is TextEdit:
		visible_value = (field as TextEdit).text
	if visible_value != value:
		return {"ok": false, "reason": "field text did not match the requested value", "field": target}
	if field == app.get("seed_input"):
		committed_start_seed_text = value
	return {
		"ok": true,
		"field": target,
		"id": str(focused.get("id", "")),
		"characters": value.length(),
	}


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
	if button == null or not button.is_visible_in_tree() or button.disabled \
			or not bool(data.get("fully_visible", false)):
		return {"ok": false, "reason": "button became hidden, clipped, or disabled before click"}
	var clicked_id := str(data.get("id", ""))
	var clicked_text := button.text
	var click_position: Vector2 = data.get("click_position", button.get_global_rect().get_center())
	await _push_mouse_click(click_position, false)
	return {"ok": true, "id": clicked_id, "text": clicked_text}


func _scroll_surface(argument: String) -> Dictionary:
	var parts := argument.split(" ", false)
	if parts.size() != 2:
		return {"ok": false, "reason": "scroll_surface requires one public surface id and up/down direction"}
	var surface_id := str(parts[0]).strip_edges()
	var direction := str(parts[1]).strip_edges().to_lower()
	if surface_id != "run_menu":
		return {"ok": false, "reason": "unsupported public scroll surface: %s" % surface_id}
	if direction not in ["up", "down"]:
		return {"ok": false, "reason": "scroll_surface direction must be up or down"}
	var surface := _visible_vertical_scroll_surface(surface_id)
	if surface.is_empty():
		return {"ok": false, "reason": "public scroll surface is not visibly scrollable: %s" % surface_id}
	var capability := "can_scroll_%s" % direction
	if not bool(surface.get(capability, false)):
		return {"ok": false, "reason": "public scroll surface cannot scroll %s: %s" % [direction, surface_id]}
	var container := surface.get("node") as ScrollContainer
	if container == null:
		return {"ok": false, "reason": "public scroll surface lost its live container: %s" % surface_id}
	var visible_rect: Rect2 = surface.get("rect", Rect2())
	if not visible_rect.has_area():
		return {"ok": false, "reason": "public scroll surface lost its visible hit area: %s" % surface_id}
	var before := container.scroll_vertical
	var button_index := MOUSE_BUTTON_WHEEL_UP if direction == "up" else MOUSE_BUTTON_WHEEL_DOWN
	await _push_mouse_wheel(visible_rect.get_center(), button_index)
	await process_frame
	var after := container.scroll_vertical
	if (direction == "down" and after <= before) or (direction == "up" and after >= before):
		return {"ok": false, "reason": "visible mouse-wheel input did not move public scroll surface %s %s" % [surface_id, direction]}
	return {"ok": true, "surface_id": surface_id, "direction": direction, "moved": true}


func _click_map_node(node_id: String) -> Dictionary:
	var cleaned := node_id.strip_edges()
	if cleaned.is_empty():
		return {"ok": false, "reason": "world-map node id is required"}
	var expected_name := "WorldMapNode_%s" % cleaned
	var matches: Array[Button] = []
	_collect_named_buttons(app, expected_name, matches)
	if matches.is_empty():
		return {"ok": false, "reason": "visible world-map node not found: %s" % cleaned}
	if matches.size() > 1:
		return {"ok": false, "reason": "ambiguous visible world-map node: %s" % cleaned}
	var button := matches[0]
	if button.disabled:
		return {"ok": false, "reason": "world-map node is disabled: %s" % cleaned}
	var visible_rect := _clipped_control_rect(button)
	if not visible_rect.has_area():
		return {"ok": false, "reason": "world-map node has no visible hit area: %s" % cleaned}
	await _push_mouse_click(visible_rect.get_center(), false)
	return {"ok": true, "node_id": cleaned, "id": str(button.get_path())}


func _collect_named_buttons(node: Node, expected_name: String, result: Array[Button]) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is Button:
		var button := node as Button
		if str(button.name) == expected_name and button.is_visible_in_tree():
			result.append(button)
	for child in node.get_children():
		_collect_named_buttons(child, expected_name, result)


func _click_choice(choice_id: String) -> Dictionary:
	var cleaned := choice_id.strip_edges()
	if cleaned.is_empty():
		return {"ok": false, "reason": "choice id is required"}
	var public_observation := _public_observation()
	var event_popup := _dict(public_observation.get("event_popup", {}))
	if bool(event_popup.get("visible", false)):
		var choices := _array(event_popup.get("choices", []))
		var choice_index := -1
		var choice: Dictionary = {}
		for index in range(choices.size()):
			var candidate := _dict(choices[index])
			if str(candidate.get("id", "")) == cleaned:
				choice_index = index
				choice = candidate
				break
		if choice_index < 0:
			return {"ok": false, "reason": "visible event choice not found: %s" % cleaned}
		if bool(choice.get("disabled", false)) or not bool(choice.get("enabled", true)):
			return {"ok": false, "reason": "visible event choice is disabled: %s" % cleaned}
		var choice_list := app.get("event_choice_popup_choices_list") as Node
		var buttons: Array[Button] = []
		_collect_descendant_buttons(choice_list, buttons)
		if choice_index >= buttons.size():
			return {"ok": false, "reason": "event choice has no corresponding visible button: %s" % cleaned}
		var button := buttons[choice_index]
		if button.disabled:
			return {"ok": false, "reason": "event choice button is disabled: %s" % cleaned}
		var visible_rect := _clipped_control_rect(button)
		if not visible_rect.has_area():
			return {"ok": false, "reason": "event choice has no visible hit area: %s" % cleaned}
		await _push_mouse_click(visible_rect.get_center(), false)
		return {"ok": true, "choice_id": cleaned, "choice_index": choice_index, "surface": "event_popup"}
	var talk := _dict(public_observation.get("talk", {}))
	if bool(talk.get("visible", false)):
		var choice_ids := _array(talk.get("choice_ids", []))
		var choice_index := choice_ids.find(cleaned)
		if choice_index < 0:
			return {"ok": false, "reason": "visible talk choice not found: %s" % cleaned}
		var talk_dock := app.get("talk_dock") as Control
		var choice_list := talk_dock.get("choice_list") as Node if talk_dock != null else null
		var buttons: Array[Button] = []
		_collect_descendant_buttons(choice_list, buttons)
		if choice_index >= buttons.size():
			return {"ok": false, "reason": "talk choice has no corresponding visible button: %s" % cleaned}
		var button := buttons[choice_index]
		if button.disabled:
			return {"ok": false, "reason": "visible talk choice is disabled: %s" % cleaned}
		var visible_rect := _clipped_control_rect(button)
		if not visible_rect.has_area():
			return {"ok": false, "reason": "talk choice has no visible hit area: %s" % cleaned}
		await _push_mouse_click(visible_rect.get_center(), false)
		return {"ok": true, "choice_id": cleaned, "choice_index": choice_index, "surface": "talk"}
	return {"ok": false, "reason": "no visible event or talk choice surface"}


func _collect_descendant_buttons(node: Node, result: Array[Button]) -> void:
	if node == null:
		return
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is Button and (node as Button).is_visible_in_tree():
		result.append(node as Button)
	for child in node.get_children():
		_collect_descendant_buttons(child, result)


func _click_inventory_item(argument: String) -> Dictionary:
	var parts := argument.split(" ", false)
	if parts.is_empty():
		return {"ok": false, "reason": "usage: click_inventory <item-id> [storage-source]"}
	var item_id := str(parts[0]).strip_edges()
	var requested_source := str(parts[1]).strip_edges() if parts.size() > 1 else ""
	var public_observation := _public_observation()
	var inventory := _dict(public_observation.get("inventory", {}))
	if not bool(inventory.get("visible", false)):
		return {"ok": false, "reason": "run inventory is not visible"}
	var matches: Array = []
	for item_value in _array(inventory.get("items", [])):
		var item := _dict(item_value)
		var source := str(item.get("storage_source", item.get("source", "carried"))).strip_edges()
		if str(item.get("id", item.get("item_id", ""))) != item_id:
			continue
		if not requested_source.is_empty() and source != requested_source:
			continue
		matches.append(item)
	if matches.is_empty():
		return {"ok": false, "reason": "visible inventory item not found: %s" % item_id}
	if matches.size() > 1:
		return {"ok": false, "reason": "inventory item is ambiguous; provide its storage source: %s" % item_id}
	var item := matches[0] as Dictionary
	var selection_key := str(item.get("selection_key", "")).strip_edges()
	if selection_key.is_empty():
		return {"ok": false, "reason": "inventory item has no public selection key: %s" % item_id}
	var inventory_screen := app.get("run_inventory_screen") as Control
	if inventory_screen == null or not inventory_screen.is_visible_in_tree() or not inventory_screen.has_method("layout_rects"):
		return {"ok": false, "reason": "run inventory surface is unavailable"}
	var layout := _dict(inventory_screen.call("layout_rects"))
	var spatial := _dict(layout.get("spatial", {}))
	for slot_value in _array(spatial.get("slots", [])):
		var slot := _dict(slot_value)
		if str(slot.get("selection_key", "")) != selection_key:
			continue
		var rect: Rect2 = slot.get("rect", Rect2()) if typeof(slot.get("rect", Rect2())) == TYPE_RECT2 else Rect2()
		var visible_rect := rect.intersection(Rect2(Vector2.ZERO, Vector2(root.size)))
		if not bool(slot.get("occupied", false)) or not visible_rect.has_area():
			return {"ok": false, "reason": "inventory item is not on the visible container page: %s" % item_id}
		await _push_mouse_click(visible_rect.get_center(), false)
		return {
			"ok": true,
			"item_id": item_id,
			"storage_source": str(item.get("storage_source", item.get("source", "carried"))),
			"selection_key": selection_key,
		}
	return {"ok": false, "reason": "inventory item is not on the visible container page: %s" % item_id}


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
		var public_observation := _public_observation()
		var public_game := _dict(public_observation.get("game", {}))
		var available := false
		for value in _game_surface_actions(surface, public_game):
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


func _push_mouse_wheel(position: Vector2, button_index: int) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	app.get_viewport().push_input(motion, true)
	await process_frame
	var wheel := InputEventMouseButton.new()
	wheel.button_index = button_index
	wheel.pressed = true
	wheel.factor = 1.0
	wheel.position = position
	wheel.global_position = position
	app.get_viewport().push_input(wheel, true)
	await process_frame
	var release := wheel.duplicate() as InputEventMouseButton
	release.pressed = false
	app.get_viewport().push_input(release, true)
	await process_frame


func _capture_look(command_number: int) -> Dictionary:
	await RenderingServer.frame_post_draw
	var image_path := _path("%04d.png" % command_number)
	var image := root.get_texture().get_image()
	var image_error := image.save_png(image_path)
	var observable := _public_observation()
	var room_canvas := app.get("environment_canvas") as Control
	var game_canvas := app.get("game_surface_canvas") as Control
	var coach := app.get("coach_overlay") as Control
	var coach_snapshot: Dictionary = coach.call("current_snapshot") if coach != null and coach.has_method("current_snapshot") else {}
	if room_canvas != null and room_canvas.has_method("global_rect_for_object"):
		var coach_anchor_id := str(coach_snapshot.get("anchor_id", "")).strip_edges()
		if not coach_anchor_id.is_empty():
			coach_snapshot["live_room_anchor_rect"] = room_canvas.call("global_rect_for_object", coach_anchor_id)
	return {
		"png": image_path,
		"png_error": error_string(image_error) if image_error != OK else "",
		"observable": observable,
		"replay_pause": _replay_pause_snapshot(),
		"coach": _public_coach_snapshot(coach_snapshot),
		"clickable": {
			"buttons": _public_buttons(),
			"scroll_surfaces": _public_scroll_surfaces(),
			"text_fields": _visible_text_fields(),
			"talk_choices": _public_talk_choices(observable),
			"canvas_objects": _canvas_objects(room_canvas),
			"room_actions": _room_selected_actions(room_canvas),
			"game_surface_actions": _game_surface_actions(game_canvas, _dict(observable.get("game", {}))),
		},
	}


func _public_observation() -> Dictionary:
	var snapshot := Fidelity.observable_host_snapshot(app)
	var screen := _dict(snapshot.get("screen", {})).duplicate(true)
	var screen_id := str(screen.get("screen", ""))
	var start_menu := _dict(screen.get("start_menu", {})).duplicate(true)
	var seed_field := app.get("seed_input") as LineEdit
	var seed_field_visible := screen_id == "START" and _control_is_rendered(seed_field)
	start_menu["visible"] = screen_id == "START" and _control_is_rendered(app.get("main_menu_panel") as Control)
	start_menu["primary_action_visible"] = screen_id == "START" and _control_is_rendered(app.get("new_run_button") as Control)
	start_menu["release_version_visible"] = screen_id == "START" and _control_is_rendered(app.get("release_version_label") as Control)
	start_menu["seed_field_visible"] = seed_field_visible
	start_menu["seed_text_committed"] = seed_field_visible \
		and not committed_start_seed_text.is_empty() \
		and seed_field != null \
		and seed_field.text == committed_start_seed_text
	start_menu["content_group_config_visible"] = screen_id == "START" \
		and _control_is_rendered(app.get("content_group_panel") as Control)
	start_menu["challenge_config_visible"] = screen_id == "START" \
		and _control_is_rendered(app.get("challenge_panel") as Control)
	start_menu["run_config_visible"] = screen_id == "START" \
		and _control_is_rendered(app.get("run_config_panel") as Control)
	screen["start_menu"] = start_menu
	var run_report := app.get("run_report_screen") as Control
	screen["run_report_visible"] = screen_id in ["VICTORY", "FAILURE"] \
		and _control_is_rendered(run_report)
	snapshot["screen"] = screen
	var status_hud := _dict(snapshot.get("status_hud", {})).duplicate(true)
	status_hud["save_text_visible"] = _hud_status_tooltip_is_rendered(str(status_hud.get("save_text", "")))
	snapshot["status_hud"] = status_hud
	return PublicObservation.sanitize(snapshot)


func _control_is_rendered(control: Control) -> bool:
	return control != null and control.visible and control.is_visible_in_tree() \
		and _clipped_control_rect(control).has_area()


func _hud_status_tooltip_is_rendered(expected_text: String) -> bool:
	if expected_text.is_empty():
		return false
	var structured_hud := app.get("structured_hud") as Control
	var status_tray := structured_hud.get("status_tray") as Control if structured_hud != null else null
	if not _control_is_rendered(status_tray):
		return false
	for child in status_tray.get_children():
		var control := child as Control
		if _control_is_rendered(control) and control.tooltip_text == expected_text:
			return true
	return false


func _replay_pause_snapshot() -> Dictionary:
	if app == null or not app.has_method("application_lifecycle_snapshot"):
		return {}
	return _dict(app.call("application_lifecycle_snapshot")).duplicate(true)


func _replay_pause_is_valid(snapshot: Dictionary) -> bool:
	var owners := _array(snapshot.get("pause_owners", []))
	return owners.has(REPLAY_PAUSE_OWNER) \
		and bool(snapshot.get("application_paused", false)) \
		and bool(snapshot.get("simulation_paused", false)) \
		and bool(snapshot.get("environment_canvas_paused", false)) \
		and bool(snapshot.get("game_canvas_paused", false))


func _visible_buttons() -> Array:
	var result: Array = []
	_collect_buttons(app, result)
	_append_tutorial_confirmation_buttons(result)
	return result


func _collect_buttons(node: Node, result: Array) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is Button:
		var button := node as Button
		var full_rect := button.get_global_rect()
		var visible_rect := _clipped_control_rect(button)
		if button.is_visible_in_tree() and not button.disabled and visible_rect.has_area():
			result.append({
				"node": button,
				"id": str(button.get_path()),
				"text": button.text.strip_edges(),
				"rect": visible_rect,
				"fully_visible": _rect_encloses_with_tolerance(visible_rect, full_rect),
				"click_position": visible_rect.get_center(),
			})
	for child in node.get_children():
		_collect_buttons(child, result)


func _append_tutorial_confirmation_buttons(result: Array) -> void:
	var dialog := app.get("tutorial_skip_dialog") as ConfirmationDialog
	if dialog == null or not dialog.visible or dialog.size.x <= 0 or dialog.size.y <= 0:
		return
	var controls: Array[Dictionary] = [
		{"button": dialog.get_ok_button(), "id": "tutorial_skip_dialog:ok", "role": "ok"},
		{"button": dialog.get_cancel_button(), "id": "tutorial_skip_dialog:cancel", "role": "cancel"},
	]
	for control_data in controls:
		var button := control_data.get("button") as Button
		if button == null or button.disabled or not button.is_visible_in_tree():
			continue
		var full_rect := button.get_global_rect()
		var visible_rect := _clipped_control_rect(button)
		if not visible_rect.has_area():
			continue
		result.append({
			"node": button,
			"id": str(control_data.get("id", "")),
			"text": button.text.strip_edges(),
			"rect": visible_rect,
			"fully_visible": _rect_encloses_with_tolerance(visible_rect, full_rect),
			"click_position": visible_rect.get_center(),
			"surface_id": "tutorial_skip_dialog",
			"dialog_role": str(control_data.get("role", "")),
			"dialog_rendered": true,
		})


func _public_buttons() -> Array:
	var result: Array = []
	for entry_value in _visible_buttons():
		var entry := entry_value as Dictionary
		var public_entry := {
			"id": entry.get("id", ""),
			"text": entry.get("text", ""),
			"enabled": true,
			"rect": entry.get("rect", Rect2()),
			"fully_visible": bool(entry.get("fully_visible", false)),
		}
		for key in ["surface_id", "dialog_role", "dialog_rendered"]:
			if entry.has(key):
				public_entry[key] = entry.get(key)
		result.append(public_entry)
	return result


func _visible_vertical_scroll_surface(surface_id: String) -> Dictionary:
	var container: ScrollContainer = null
	if surface_id == "run_menu":
		container = app.get("run_menu_scroll") as ScrollContainer
	if not _control_is_rendered(container):
		return {}
	var bar := container.get_v_scroll_bar()
	if bar == null:
		return {}
	var maximum := maxi(0, int(ceil(bar.max_value - bar.page)))
	if maximum <= 0:
		return {}
	var current := clampi(container.scroll_vertical, 0, maximum)
	return {
		"node": container,
		"id": surface_id,
		"axis": "vertical",
		"rendered": true,
		"rect": _clipped_control_rect(container),
		"can_scroll_up": current > 0,
		"can_scroll_down": current < maximum,
	}


func _public_scroll_surfaces() -> Array:
	var surface := _visible_vertical_scroll_surface("run_menu")
	if surface.is_empty():
		return []
	return [{
		"id": str(surface.get("id", "")),
		"axis": str(surface.get("axis", "")),
		"rendered": bool(surface.get("rendered", false)),
		"rect": surface.get("rect", Rect2()),
		"can_scroll_up": bool(surface.get("can_scroll_up", false)),
		"can_scroll_down": bool(surface.get("can_scroll_down", false)),
	}]


func _visible_text_fields() -> Array:
	var result: Array = []
	for entry_value in _visible_text_field_nodes():
		var entry := entry_value as Dictionary
		result.append({
			"id": str(entry.get("id", "")),
			"text": str(entry.get("text", "")),
			"placeholder": str(entry.get("placeholder", "")),
			"rect": entry.get("rect", Rect2()),
			"focused": bool(entry.get("focused", false)),
		})
	return result


func _public_talk_choices(public_observation: Dictionary) -> Array:
	var talk := _dict(public_observation.get("talk", {}))
	if not bool(talk.get("visible", false)):
		return []
	var choice_ids := _array(talk.get("choice_ids", []))
	var talk_dock := app.get("talk_dock") as Control
	var choice_list := talk_dock.get("choice_list") as Node if talk_dock != null else null
	var buttons: Array[Button] = []
	_collect_descendant_buttons(choice_list, buttons)
	var result: Array = []
	for index in range(choice_ids.size()):
		var choice_id := str(choice_ids[index]).strip_edges()
		if choice_id.is_empty():
			continue
		var button: Button = buttons[index] if index < buttons.size() else null
		var visible_rect := _clipped_control_rect(button) if button != null else Rect2()
		result.append({
			"id": choice_id,
			"label": button.text.strip_edges() if button != null else "",
			"enabled": button != null and not button.disabled and visible_rect.has_area(),
			"rect": visible_rect,
		})
	return result


func _visible_text_field_nodes() -> Array:
	var result: Array = []
	_collect_text_field_nodes(app, result)
	return result


func _collect_text_field_nodes(node: Node, result: Array) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is LineEdit:
		var field := node as LineEdit
		var visible_rect := _clipped_control_rect(field)
		if field.is_visible_in_tree() and field.editable and visible_rect.has_area():
			result.append({"node": field, "id": str(field.get_path()), "text": field.text, "placeholder": field.placeholder_text, "rect": visible_rect, "focused": field.has_focus()})
	elif node is TextEdit:
		var field := node as TextEdit
		var visible_rect := _clipped_control_rect(field)
		if field.is_visible_in_tree() and field.editable and visible_rect.has_area():
			result.append({"node": field, "id": str(field.get_path()), "text": field.text, "placeholder": field.placeholder_text, "rect": visible_rect, "focused": field.has_focus()})
	for child in node.get_children():
		_collect_text_field_nodes(child, result)


func _public_coach_snapshot(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in [
		"visible", "lesson_id", "voice", "eyebrow", "copy", "anchor_kind", "anchor_id",
		"anchor_found", "completion_type", "delivery", "dialogue_id", "dialogue_node",
		"dismissible", "dismiss_action_id", "dismiss_label", "gating", "highlight_emphasis",
		"reduce_motion", "small_screen", "minimum_control_height",
	]:
		if not source.has(key):
			continue
		var value: Variant = source.get(key)
		if typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]:
			result[key] = str(value) if typeof(value) == TYPE_STRING_NAME else value
	for key in ["allowed_action_ids", "suggested_action_ids"]:
		var values: Array = []
		for value in _array(source.get(key, [])):
			var text := str(value).strip_edges()
			if not text.is_empty():
				values.append(text)
		result[key] = values
	for key in ["anchor_rect", "bubble_rect", "viewport_rect", "live_room_anchor_rect"]:
		if source.has(key):
			result[key] = source.get(key)
	var additional_rects: Array = []
	for rect_value in _array(source.get("additional_anchor_rects", [])):
		if typeof(rect_value) in [TYPE_RECT2, TYPE_DICTIONARY]:
			additional_rects.append(rect_value)
	result["additional_anchor_rects"] = additional_rects
	return result


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


func _rect_encloses_with_tolerance(outer: Rect2, inner: Rect2, tolerance: float = 0.75) -> bool:
	return outer.has_area() and inner.has_area() \
		and outer.position.x <= inner.position.x + tolerance \
		and outer.position.y <= inner.position.y + tolerance \
		and outer.end.x >= inner.end.x - tolerance \
		and outer.end.y >= inner.end.y - tolerance


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
		result.append({
			"id": str(action.get("id", "")),
			"action": str(action.get("action", "")),
			"action_id": str(action.get("action_id", "")),
			"emit_object_id": str(action.get("emit_object_id", "")),
			"label": str(action.get("label", "")),
			"text": str(action.get("text", "")),
			"summary": str(action.get("summary", "")),
			"disabled_reason": str(action.get("disabled_reason", "")),
			"index": index,
			"enabled": bool(action.get("enabled", true)) and not bool(action.get("disabled", false)),
		})
	return result


func _game_surface_actions(canvas: Control, public_game: Dictionary = {}) -> Array:
	if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
		return []
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	var result: Array = []
	for value in _array(snapshot.get("surface_hit_actions", [])):
		var action := value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
		if action.is_empty():
			continue
		var action_id := str(action.get("action", ""))
		# Blackjack keeps an intentionally invisible Deal hit region while a hand
		# is active so keyboard/controller focus can retain its stable binding.
		# That compatibility region is not a rendered player control and must never
		# become an agent action. Admit Deal only when the public game projection
		# says the visible DEAL control is currently available.
		if str(public_game.get("game_id", "")) == "blackjack" \
				and action_id == "blackjack_deal" \
				and not bool(public_game.get("can_deal", false)):
			continue
		result.append({
			"action": action_id,
			"index": int(action.get("index", 0)),
			"rect": action.get("rect", Rect2()),
			"enabled": not (canvas.has_method("surface_action_is_blocked") and bool(canvas.call("surface_action_is_blocked", str(action.get("action", ""))))),
		})
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


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
