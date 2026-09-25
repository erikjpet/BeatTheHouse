extends SceneTree

# Interactive, production-input playtest bridge. Commands arrive as numbered
# files; every command is answered with a screenshot and player-observable JSON.

const MainScene := preload("res://scenes/main.tscn")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const PublicObservation := preload("res://tools/agent_playtest_public_observation.gd")
const REPLAY_PAUSE_OWNER := "agent_replay"
const SHUTDOWN_DRAIN_FRAMES := 12

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
		if shutting_down:
			break
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
	if file == null:
		return
	var raw := file.get_as_text().strip_edges()
	file.close()
	var result := await _execute_command(raw, next_command)
	_write_json(_path("%04d.result.json" % next_command), result)
	next_command += 1
	if bool(result.get("quit", false)):
		shutting_down = true
		# Publish the accepted quit result above, then tear down the production
		# host while the SceneTree is still alive. This lets FoundationMain run
		# its normal _exit_tree cleanup and gives queued/native zero-reference
		# notifications a bounded drain before engine leak diagnostics execute.
		if is_instance_valid(app):
			app.queue_free()
			app = null
		for _frame in range(SHUTDOWN_DRAIN_FRAMES):
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
			"click_blank_room":
				var clicked := await _click_blank_room()
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
					# This isolated process can retain the production focus-out owner
					# because its window is intentionally unattended. Suspend the exact
					# application-lifecycle owners seen at the command boundary so a
					# normal wait advances presentation clocks, then restore all of them.
					# Modal pause owners remain inside FoundationMain and are untouched.
					var suspended_pause_owners: Array[String] = []
					for owner_value in _array(pause_before.get("pause_owners", [])):
						var owner := str(owner_value).strip_edges()
						if owner.is_empty() or suspended_pause_owners.has(owner):
							continue
						suspended_pause_owners.append(owner)
						app.call("set_application_pause_owner", owner, false)
					await process_frame
					await _wait_frames(frames)
					for owner in suspended_pause_owners:
						app.call("set_application_pause_owner", owner, true)
					await process_frame
					var pause_after_wait := _replay_pause_snapshot()
					accepted = _replay_pause_is_valid(pause_after_wait)
					var restored_pause_owners := _array(pause_after_wait.get("pause_owners", []))
					for owner in suspended_pause_owners:
						accepted = accepted and restored_pause_owners.has(owner)
					if not accepted:
						reason = "deterministic replay pause ownership was not restored after wait"
					detail = {
						"frames": frames,
						"pause_restored": accepted,
						"suspended_pause_owners": suspended_pause_owners,
					}
			"quit":
				accepted = true
				should_quit = true
			_:
				reason = "unknown command: %s" % verb
	await _wait_frames(4)
	# Quit still publishes its final authenticated public observation, but it does
	# not need another framebuffer copy. Skipping that redundant PNG prevents a
	# long replay's save/relaunch boundary from exhausting image-encode memory.
	var look := await _capture_look(command_number, not should_quit)
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
	var click_position: Vector2 = data.get("click_position", button.get_global_rect().get_center())
	var input_route := _button_input_route(data, button, click_position)
	var input_viewport := input_route.get("viewport") as Viewport
	var input_position_value: Variant = input_route.get("position")
	if input_viewport == null or typeof(input_position_value) != TYPE_VECTOR2:
		return {"ok": false, "reason": "button input viewport became missing, changed, or ambiguous before click"}
	var input_position: Vector2 = input_position_value
	var clicked_id := str(data.get("id", ""))
	var clicked_text := button.text
	await _push_mouse_click_in_viewport(input_viewport, input_position, false)
	return {"ok": true, "id": clicked_id, "text": clicked_text}


func _scroll_surface(argument: String) -> Dictionary:
	var parts := argument.split(" ", false)
	if parts.size() != 2:
		return {"ok": false, "reason": "scroll_surface requires one public surface id and up/down direction"}
	var surface_id := str(parts[0]).strip_edges()
	var direction := str(parts[1]).strip_edges().to_lower()
	if surface_id not in ["run_menu", "room_actions"]:
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
		var render_valid_value: Variant = event_popup.get("render_valid", false)
		if typeof(render_valid_value) != TYPE_BOOL or not bool(render_valid_value):
			return {"ok": false, "reason": "visible event choices are not fully authenticated and rendered"}
		var choices := _array(event_popup.get("choices", []))
		var matches: Array[Dictionary] = []
		for index in range(choices.size()):
			var candidate := _dict(choices[index])
			if str(candidate.get("id", "")) == cleaned:
				matches.append(candidate)
		if matches.size() != 1:
			return {"ok": false, "reason": "visible event choice not found: %s" % cleaned}
		var choice := matches[0]
		var choice_enabled_value: Variant = choice.get("enabled", false)
		if typeof(choice_enabled_value) != TYPE_BOOL or not bool(choice_enabled_value):
			return {"ok": false, "reason": "visible event choice is disabled: %s" % cleaned}
		var live_popup := _public_rendered_event_popup({})
		if not bool(live_popup.get("render_valid", false)) \
				or str(live_popup.get("event_id", "")) != str(event_popup.get("event_id", "")) \
				or str(live_popup.get("title", "")) != str(event_popup.get("title", "")) \
				or str(live_popup.get("summary", "")) != str(event_popup.get("summary", "")) \
				or JSON.stringify(live_popup.get("choices", [])) != JSON.stringify(choices):
			return {"ok": false, "reason": "visible event choices changed before click"}
		var choice_list := app.get("event_choice_popup_choices_list") as Control
		var matched_cards: Array[Control] = []
		for child in choice_list.get_children():
			var card := child as Control
			if card != null and str(card.get_meta("event_id", "")) == str(event_popup.get("event_id", "")) \
					and str(card.get_meta("choice_id", "")) == cleaned:
				matched_cards.append(card)
		if matched_cards.size() != 1:
			return {"ok": false, "reason": "event choice has no unique live semantic card: %s" % cleaned}
		var live_choice := _rendered_event_choice_card_snapshot(matched_cards[0])
		var live_choice_enabled_value: Variant = live_choice.get("enabled", false)
		if live_choice.is_empty() or str(live_choice.get("label", "")) != str(choice.get("label", "")) \
				or str(live_choice.get("text", "")) != str(choice.get("text", "")) \
				or typeof(live_choice_enabled_value) != TYPE_BOOL or not bool(live_choice_enabled_value):
			return {"ok": false, "reason": "event choice changed or clipped before click: %s" % cleaned}
		var buttons: Array[Button] = []
		_collect_descendant_buttons(matched_cards[0], buttons)
		if buttons.size() != 1 or buttons[0].disabled \
				or str(buttons[0].get_meta("event_id", "")) != str(event_popup.get("event_id", "")) \
				or str(buttons[0].get_meta("choice_id", "")) != cleaned \
				or not _button_text_is_fully_rendered(buttons[0]):
			return {"ok": false, "reason": "event choice button is no longer exact, visible, and enabled: %s" % cleaned}
		var button := buttons[0]
		var visible_rect := _clipped_control_rect(button)
		if not visible_rect.has_area():
			return {"ok": false, "reason": "event choice has no visible hit area: %s" % cleaned}
		await _push_mouse_click(visible_rect.get_center(), false)
		return {"ok": true, "choice_id": cleaned, "choice_index": _array(live_popup.get("choice_ids", [])).find(cleaned), "surface": "event_popup"}
	var talk := _dict(public_observation.get("talk", {}))
	if bool(talk.get("visible", false)):
		var talk_dock := app.get("talk_dock") as Control
		var live_choices := _rendered_talk_choice_snapshots(talk_dock)
		var matches: Array[Dictionary] = []
		for choice_value in live_choices:
			var candidate := choice_value as Dictionary
			if str(candidate.get("event_id", "")) == str(talk.get("event_id", "")) \
					and str(candidate.get("id", "")) == cleaned:
				matches.append(candidate)
		if matches.size() != 1:
			return {"ok": false, "reason": "visible talk choice not found: %s" % cleaned}
		var choice := matches[0]
		var talk_choice_enabled_value: Variant = choice.get("enabled", false)
		if typeof(talk_choice_enabled_value) != TYPE_BOOL or not bool(talk_choice_enabled_value):
			return {"ok": false, "reason": "visible talk choice is disabled: %s" % cleaned}
		var choice_list := talk_dock.get("choice_list") as Control if talk_dock != null else null
		var buttons: Array[Button] = []
		_collect_descendant_buttons(choice_list, buttons)
		var matched_buttons: Array[Button] = []
		for candidate in buttons:
			if str(candidate.get_meta("event_id", "")) == str(talk.get("event_id", "")) \
					and str(candidate.get_meta("choice_id", "")) == cleaned:
				matched_buttons.append(candidate)
		if matched_buttons.size() != 1:
			return {"ok": false, "reason": "talk choice has no unique live semantic button: %s" % cleaned}
		var button := matched_buttons[0]
		if button.disabled or button.text.strip_edges() != str(choice.get("label", "")) \
				or not _button_text_is_fully_rendered(button):
			return {"ok": false, "reason": "visible talk choice changed, clipped, or disabled: %s" % cleaned}
		var visible_rect := _clipped_control_rect(button)
		if not visible_rect.has_area():
			return {"ok": false, "reason": "talk choice has no visible hit area: %s" % cleaned}
		await _push_mouse_click(visible_rect.get_center(), false)
		return {"ok": true, "choice_id": cleaned, "choice_index": live_choices.find(choice), "surface": "talk"}
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


func _click_blank_room() -> Dictionary:
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not _control_is_fully_rendered(canvas) \
			or not canvas.has_method("object_id_at_local_position"):
		return {"ok": false, "reason": "room canvas does not expose a fully rendered blank-click surface"}
	var local_position := _blank_room_position(canvas)
	if not _inside_control(canvas, local_position):
		return {"ok": false, "reason": "room canvas contains no public blank click position"}
	var global_position := canvas.get_global_transform_with_canvas() * local_position
	await _push_mouse_click(global_position, false)
	return {
		"ok": true,
		"local_position": local_position,
		"global_position": global_position,
	}


func _blank_room_position(canvas: Control) -> Vector2:
	var candidates := [
		Vector2(8.0, 8.0),
		Vector2(canvas.size.x - 8.0, 8.0),
		Vector2(8.0, canvas.size.y - 8.0),
		Vector2(canvas.size.x - 8.0, canvas.size.y - 8.0),
		Vector2(canvas.size.x * 0.5, 8.0),
		Vector2(canvas.size.x * 0.5, canvas.size.y - 8.0),
	]
	for candidate_value in candidates:
		var candidate: Vector2 = candidate_value
		if _room_position_is_blank(canvas, candidate):
			return candidate
	for row in range(1, 6):
		for column in range(1, 8):
			var candidate := Vector2(
				canvas.size.x * float(column) / 8.0,
				canvas.size.y * float(row) / 6.0
			)
			if _room_position_is_blank(canvas, candidate):
				return candidate
	return Vector2(-1.0, -1.0)


func _room_position_is_blank(canvas: Control, local_position: Vector2) -> bool:
	return _inside_control(canvas, local_position) \
		and str(canvas.call("object_id_at_local_position", local_position)).is_empty()


func _click_action(argument: String) -> Dictionary:
	var parts := argument.split(" ", false)
	if parts.is_empty():
		return {"ok": false, "reason": "game action is required"}
	if str(parts[0]) == "room":
		return await _click_room_action(parts)
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
	return {"ok": false, "reason": "no visible game or selected-room action: %s %d" % [action, index]}


func _click_room_action(parts: PackedStringArray) -> Dictionary:
	if parts.size() != 5 or not str(parts[1]).is_valid_int():
		return {"ok": false, "reason": "usage: click_action room <index> <object-base64> <identity-key> <identity-base64>"}
	var action_index := int(parts[1])
	var selected_object_id := Marshalls.base64_to_raw(str(parts[2])).get_string_from_utf8().strip_edges()
	var identity_key := str(parts[3])
	var identity_value := Marshalls.base64_to_raw(str(parts[4])).get_string_from_utf8().strip_edges()
	if action_index < 0 or selected_object_id.is_empty() or identity_value.is_empty() \
			or identity_key not in ["id", "action", "action_id", "emit_object_id", "label"]:
		return {"ok": false, "reason": "room action command identity is malformed"}
	var room := app.get("environment_canvas") as Control
	if room == null or not _control_is_fully_rendered(room) \
			or not room.has_method("local_position_for_selected_info_action_button"):
		return {"ok": false, "reason": "room action surface is not fully rendered"}
	var actions := _room_selected_actions(room)
	var identity_matches: Array[Dictionary] = []
	for value in actions:
		var data := value as Dictionary
		if str(data.get("selected_object_id", "")) == selected_object_id \
				and str(data.get(identity_key, "")) == identity_value:
			identity_matches.append(data)
	if identity_matches.size() != 1:
		return {"ok": false, "reason": "room action identity is missing or ambiguous on the live selected object"}
	var data := identity_matches[0]
	var live_index_value: Variant = data.get("index", null)
	var enabled_value: Variant = data.get("enabled", null)
	var rendered_value: Variant = data.get("rendered", null)
	var rect_value: Variant = data.get("rect", null)
	if typeof(live_index_value) != TYPE_INT or int(live_index_value) != action_index:
		return {"ok": false, "reason": "room action order changed before click"}
	if typeof(enabled_value) != TYPE_BOOL or not bool(enabled_value):
		return {"ok": false, "reason": "room action is disabled or has no exact enabled witness"}
	if typeof(rendered_value) != TYPE_BOOL or not bool(rendered_value) \
			or typeof(rect_value) != TYPE_RECT2 or not (rect_value as Rect2).has_area():
		return {"ok": false, "reason": "room action is clipped or has no exact rendered hit rectangle"}
	var live_rect := rect_value as Rect2
	var local: Vector2 = room.call("local_position_for_selected_info_action_button", action_index)
	var live_center: Vector2 = room.get_global_transform_with_canvas() * local
	if not _inside_control(room, local) or live_center.distance_to(live_rect.get_center()) > 0.75:
		return {"ok": false, "reason": "room action hit target changed before click"}
	await _push_mouse_click(live_rect.get_center(), false)
	return {
		"ok": true,
		"action": identity_value,
		"identity_key": identity_key,
		"index": action_index,
		"selected_object_id": selected_object_id,
		"surface": "room",
	}


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
	await _push_mouse_click_in_viewport(app.get_viewport(), position, double_click)


func _push_mouse_click_in_viewport(viewport: Viewport, position: Vector2, double_click: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	viewport.push_input(motion, true)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.double_click = double_click
	press.position = position
	press.global_position = position
	viewport.push_input(press, true)
	await process_frame
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.button_mask = 0
	viewport.push_input(release, true)
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


func _capture_look(command_number: int, capture_png: bool = true) -> Dictionary:
	var image_path := ""
	var image_error := OK
	if capture_png:
		await RenderingServer.frame_post_draw
		image_path = _path("%04d.png" % command_number)
		var image := root.get_texture().get_image()
		image_error = image.save_png(image_path)
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
	snapshot["consequence"] = _public_rendered_consequence()
	snapshot["event_popup"] = _public_rendered_event_popup(_dict(snapshot.get("event_popup", {})))
	snapshot["talk"] = _public_rendered_talk(_dict(snapshot.get("talk", {})))
	var status_hud := _public_rendered_status_hud(_dict(snapshot.get("status_hud", {})))
	status_hud["debt_indicator"] = _public_debt_indicator()
	snapshot["status_hud"] = status_hud
	snapshot["feedback"] = _public_rendered_feedback()
	return PublicObservation.sanitize(snapshot)


func _control_is_rendered(control: Control) -> bool:
	return control != null and control.visible and control.is_visible_in_tree() \
		and _clipped_control_rect(control).has_area()


func _control_is_fully_rendered(control: Control) -> bool:
	return _control_is_rendered(control) \
		and _rect_encloses_with_tolerance(_clipped_control_rect(control), control.get_global_rect())


func _label_text_is_fully_rendered(label: Label) -> bool:
	if not _control_is_fully_rendered(label):
		return false
	if label.get_line_count() > label.get_visible_line_count():
		return false
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return true
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	if font == null or font_size <= 0:
		return false
	var text_size := font.get_multiline_string_size(
		label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	)
	return text_size.x <= label.size.x + 0.75 and text_size.y <= label.size.y + 0.75


func _button_text_is_fully_rendered(button: Button) -> bool:
	if not _control_is_fully_rendered(button):
		return false
	var font := button.get_theme_font("font")
	var font_size := button.get_theme_font_size("font_size")
	var style := button.get_theme_stylebox("normal")
	if font == null or font_size <= 0 or style == null:
		return false
	var available := Vector2(
		button.size.x - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT),
		button.size.y - style.get_margin(SIDE_TOP) - style.get_margin(SIDE_BOTTOM)
	)
	if available.x <= 0.0 or available.y <= 0.0:
		return false
	var wrap_width := available.x if button.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0
	var text_size := font.get_multiline_string_size(
		button.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		wrap_width,
		font_size
	)
	return text_size.x <= available.x + 0.75 and text_size.y <= available.y + 0.75


func _public_rendered_consequence() -> Dictionary:
	var panel := app.get("consequence_panel") as Control
	return {"rendered": _control_is_fully_rendered(panel), "rendered_lines": []}


func _public_status_indicator(status_id: String) -> Dictionary:
	var structured_hud := app.get("structured_hud") as Control
	if not _control_is_fully_rendered(structured_hud):
		return {"rendered": false, "present": false}
	var status_tray := structured_hud.get("status_tray") as Control
	if not _control_is_fully_rendered(status_tray):
		return {"rendered": false, "present": false}
	var matches: Array[Control] = []
	for child in status_tray.get_children():
		var control := child as Control
		if control == null or not _control_is_fully_rendered(control):
			return {"rendered": false, "present": false}
		if str(control.get_meta("status_id", "")) == status_id:
			matches.append(control)
	if matches.is_empty():
		return {"rendered": true, "present": false}
	if matches.size() != 1:
		return {"rendered": false, "present": false}
	var tooltip := matches[0].tooltip_text.strip_edges()
	if tooltip.is_empty():
		return {"rendered": false, "present": false}
	return {"rendered": true, "present": true, "tooltip": tooltip}


func _public_debt_indicator() -> Dictionary:
	return _public_status_indicator("debt")


func _public_rendered_status_hud(_source: Dictionary) -> Dictionary:
	var result := {
		"bankroll_rendered": false,
		"chips_rendered": false,
		"heat_rendered": false,
		"save_text_visible": false,
	}
	var structured_hud := app.get("structured_hud") as Control
	if not _control_is_fully_rendered(structured_hud):
		return result
	var wallet_label := structured_hud.get("wallet_value") as Label
	var chips_chip := structured_hud.get("chips_chip") as Control
	var chips_label := structured_hud.get("chips_value") as Label
	var heat_label := structured_hud.get("heat_value") as Label
	if _label_text_is_fully_rendered(wallet_label):
		var wallet_text := wallet_label.text.strip_edges()
		var wallet_pattern := RegEx.new()
		if wallet_pattern.compile("^\\$(0|[1-9][0-9]*)$") == OK:
			var wallet_match := wallet_pattern.search(wallet_text)
			var bankroll_digits := wallet_match.get_string(1) if wallet_match != null else ""
			if not bankroll_digits.is_empty() and bankroll_digits.length() <= 10:
				var bankroll_value := int(bankroll_digits)
				if bankroll_value >= 0 and bankroll_value <= 2147483647:
					result["bankroll"] = bankroll_value
					result["bankroll_rendered"] = true
	if _control_is_fully_rendered(chips_chip) and _label_text_is_fully_rendered(chips_label):
		var chips_text := chips_label.text.strip_edges()
		var chips_pattern := RegEx.new()
		if chips_pattern.compile("^(0|[1-9][0-9]*)$") == OK:
			var chips_match := chips_pattern.search(chips_text)
			var chips_digits := chips_match.get_string(1) if chips_match != null else ""
			if not chips_digits.is_empty() and chips_digits.length() <= 10:
				var chips_value := int(chips_digits)
				if chips_value >= 0 and chips_value <= 2147483647:
					result["chips"] = chips_value
					result["chips_rendered"] = true
	if _label_text_is_fully_rendered(heat_label):
		var heat_text := heat_label.text.strip_edges()
		var heat_pattern := RegEx.new()
		if heat_pattern.compile("^(0|[1-9][0-9]*)$") == OK:
			var heat_match := heat_pattern.search(heat_text)
			var heat_digits := heat_match.get_string(1) if heat_match != null else ""
			if not heat_digits.is_empty() and heat_digits.length() <= 3:
				var heat_value := int(heat_digits)
				if heat_value >= 0 and heat_value <= 100:
					result["heat_level"] = heat_value
					result["heat_rendered"] = true
	var save_indicator := _public_status_indicator("save")
	if bool(save_indicator.get("rendered", false)) and bool(save_indicator.get("present", false)):
		result["save_text"] = str(save_indicator.get("tooltip", ""))
		result["save_text_visible"] = true
	return result


func _rendered_talk_choice_snapshots(talk_dock: Control) -> Array:
	var choice_list := talk_dock.get("choice_list") as Control if talk_dock != null else null
	if not _control_is_fully_rendered(choice_list):
		return []
	var result: Array = []
	var seen_ids: Dictionary = {}
	var event_id := ""
	for response_value in choice_list.get_children():
		var response := response_value as Control
		if not _control_is_fully_rendered(response):
			return []
		var buttons: Array[Button] = []
		_collect_descendant_buttons(response, buttons)
		if buttons.size() != 1 or not _button_text_is_fully_rendered(buttons[0]):
			return []
		var button := buttons[0]
		var button_event_id := str(button.get_meta("event_id", "")).strip_edges()
		var choice_id := str(button.get_meta("choice_id", "")).strip_edges()
		if button_event_id.is_empty() or choice_id.is_empty() or seen_ids.has(choice_id):
			return []
		if event_id.is_empty():
			event_id = button_event_id
		if button_event_id != event_id:
			return []
		seen_ids[choice_id] = true
		result.append({
			"event_id": button_event_id,
			"id": choice_id,
			"label": button.text.strip_edges(),
			"enabled": not button.disabled,
			"rect": _clipped_control_rect(button),
		})
	return result


func _public_rendered_talk(source: Dictionary) -> Dictionary:
	var talk_dock := app.get("talk_dock") as Control
	var panel := talk_dock.get("panel") as Control if talk_dock != null else null
	var body_label := talk_dock.get("body_label") as Label if talk_dock != null else null
	var visible_value: Variant = source.get("visible", false)
	if typeof(visible_value) != TYPE_BOOL or not bool(visible_value) or not _control_is_rendered(panel):
		return {"visible": false, "expanded": false, "render_valid": false, "body_complete": false}
	var expanded_value: Variant = source.get("expanded", false)
	var expanded := typeof(expanded_value) == TYPE_BOOL and bool(expanded_value)
	var result := {
		"visible": true,
		"expanded": expanded,
		"render_valid": false,
		"body_complete": false,
		"typewriter_active": true,
	}
	if not expanded or not _control_is_fully_rendered(panel) or not _label_text_is_fully_rendered(body_label):
		return result
	var choices := _rendered_talk_choice_snapshots(talk_dock)
	if choices.is_empty():
		return result
	var typewriter_value: Variant = source.get("typewriter_active", true)
	var clipped_value: Variant = source.get("body_text_clipped", true)
	if typeof(typewriter_value) != TYPE_BOOL or typeof(clipped_value) != TYPE_BOOL:
		return result
	var choice_ids: Array = []
	for choice_value in choices:
		choice_ids.append(str((choice_value as Dictionary).get("id", "")))
	result["event_id"] = str((choices[0] as Dictionary).get("event_id", ""))
	result["choice_ids"] = choice_ids
	result["render_valid"] = true
	var complete := not bool(typewriter_value) \
		and body_label.visible_characters == -1 \
		and not bool(clipped_value)
	result["body_complete"] = complete
	result["typewriter_active"] = not complete
	if complete:
		result["summary"] = body_label.text.strip_edges()
	else:
		result.erase("summary")
	return result


func _rendered_event_choice_card_snapshot(card: Control) -> Dictionary:
	if not _control_is_fully_rendered(card):
		return {}
	var event_id := str(card.get_meta("event_id", "")).strip_edges()
	var choice_id := str(card.get_meta("choice_id", "")).strip_edges()
	if event_id.is_empty() or choice_id.is_empty() or card.get_child_count() != 1:
		return {}
	var stack := card.get_child(0) as VBoxContainer
	if stack == null or stack.get_child_count() < 3:
		return {}
	var heading := stack.get_child(0) as Label
	var body := stack.get_child(1) as Label
	var buttons: Array[Button] = []
	_collect_descendant_buttons(card, buttons)
	if not _label_text_is_fully_rendered(heading) or not _label_text_is_fully_rendered(body) \
			or buttons.size() != 1 or not _button_text_is_fully_rendered(buttons[0]):
		return {}
	var button := buttons[0]
	if str(button.get_meta("event_id", "")).strip_edges() != event_id \
			or str(button.get_meta("choice_id", "")).strip_edges() != choice_id \
			or button.text.strip_edges() != heading.text.strip_edges():
		return {}
	return {
		"event_id": event_id,
		"id": choice_id,
		"label": heading.text.strip_edges(),
		"text": body.text.strip_edges(),
		"enabled": not button.disabled,
	}


func _public_rendered_event_popup(_source: Dictionary) -> Dictionary:
	var panel := app.get("event_choice_popup_panel") as Control
	if not _control_is_rendered(panel):
		return {"visible": false, "render_valid": false}
	var result := {"visible": true, "render_valid": false, "choices": [], "choice_ids": []}
	if not _control_is_fully_rendered(panel):
		return result
	var title_label := app.get("event_choice_popup_title_label") as Label
	var summary_label := app.get("event_choice_popup_summary_label") as Label
	var choices_list := app.get("event_choice_popup_choices_list") as Control
	if not _label_text_is_fully_rendered(title_label) or not _label_text_is_fully_rendered(summary_label) \
			or not _control_is_fully_rendered(choices_list):
		return result
	result["title"] = title_label.text.strip_edges()
	result["summary"] = summary_label.text.strip_edges()
	var cards: Array[Control] = []
	for child in choices_list.get_children():
		var card := child as Control
		if card == null or not _control_is_fully_rendered(card):
			return result
		cards.append(card)
	if cards.is_empty():
		return result
	var choices: Array = []
	var choice_ids: Array = []
	var popup_event_id := ""
	for card in cards:
		var choice := _rendered_event_choice_card_snapshot(card)
		if choice.is_empty():
			return result
		var event_id := str(choice.get("event_id", ""))
		var choice_id := str(choice.get("id", ""))
		if popup_event_id.is_empty():
			popup_event_id = event_id
		if event_id != popup_event_id or choice_ids.has(choice_id):
			return result
		choice_ids.append(choice_id)
		choices.append({
			"id": choice_id,
			"label": str(choice.get("label", "")),
			"text": str(choice.get("text", "")),
			"enabled": choice.get("enabled", false),
		})
	result["event_id"] = popup_event_id
	result["choice_ids"] = choice_ids
	result["choices"] = choices
	result["render_valid"] = true
	return result


func _public_rendered_feedback() -> Dictionary:
	var panel := app.get("environment_result_panel") as Control
	var title_label := app.get("environment_result_title_label") as Label
	var body_label := app.get("environment_result_body_label") as Label
	if not _control_is_fully_rendered(panel) or not _label_text_is_fully_rendered(title_label) \
			or not _label_text_is_fully_rendered(body_label):
		return {"visible": false}
	return {
		"visible": true,
		"title": title_label.text.strip_edges(),
		"text": body_label.text.strip_edges(),
	}


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
				"input_viewport_candidates": [button.get_viewport()],
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
			"input_viewport_candidates": [button.get_viewport()],
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


func _button_input_route(data: Dictionary, button: Button, local_position: Vector2) -> Dictionary:
	var viewport_candidates := _array(data.get("input_viewport_candidates", []))
	if viewport_candidates.size() != 1:
		return {}
	var recorded_viewport := viewport_candidates[0] as Viewport
	var live_viewport := button.get_viewport() if button != null else null
	if recorded_viewport == null or live_viewport == null or recorded_viewport != live_viewport:
		return {}
	var root_viewport := app.get_viewport()
	if recorded_viewport == root_viewport:
		return {"viewport": root_viewport, "position": local_position}
	if str(data.get("surface_id", "")) != "tutorial_skip_dialog":
		return {}
	var dialog := app.get("tutorial_skip_dialog") as ConfirmationDialog
	if dialog == null or not dialog.visible or recorded_viewport != dialog or not dialog.is_embedded():
		return {}
	var role := str(data.get("dialog_role", ""))
	var expected_button: Button = dialog.get_ok_button() if role == "ok" else dialog.get_cancel_button() if role == "cancel" else null
	var expected_id := "tutorial_skip_dialog:%s" % role
	if button != expected_button or str(data.get("id", "")) != expected_id:
		return {}
	var dialog_parent: Node = dialog.get_parent()
	if dialog_parent == null or dialog_parent != app:
		return {}
	var embedder_viewport: Viewport = dialog_parent.get_viewport()
	if embedder_viewport == null or embedder_viewport != root_viewport:
		return {}
	return {
		"viewport": embedder_viewport,
		"position": Vector2(dialog.position) + local_position,
	}


func _visible_vertical_scroll_surface(surface_id: String) -> Dictionary:
	var container: ScrollContainer = null
	if surface_id == "run_menu":
		container = app.get("run_menu_scroll") as ScrollContainer
	elif surface_id == "room_actions":
		var action_list := app.get("room_action_list") as Control
		var candidates: Array[ScrollContainer] = []
		_collect_scroll_containers(action_list, candidates)
		if candidates.size() == 1:
			container = candidates[0]
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


func _collect_scroll_containers(node: Node, result: Array[ScrollContainer]) -> void:
	if node == null or (node is CanvasItem and not (node as CanvasItem).visible):
		return
	if node is ScrollContainer and _control_is_rendered(node as ScrollContainer):
		result.append(node as ScrollContainer)
	for child in node.get_children():
		_collect_scroll_containers(child, result)


func _public_scroll_surfaces() -> Array:
	var result: Array = []
	for surface_id in ["run_menu", "room_actions"]:
		var surface := _visible_vertical_scroll_surface(surface_id)
		if surface.is_empty():
			continue
		result.append({
			"id": str(surface.get("id", "")),
			"axis": str(surface.get("axis", "")),
			"rendered": bool(surface.get("rendered", false)),
			"rect": surface.get("rect", Rect2()),
			"can_scroll_up": bool(surface.get("can_scroll_up", false)),
			"can_scroll_down": bool(surface.get("can_scroll_down", false)),
		})
	return result


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
	var talk_dock := app.get("talk_dock") as Control
	var result := _rendered_talk_choice_snapshots(talk_dock)
	if result.size() != _array(talk.get("choice_ids", [])).size():
		return []
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
	var viewport := control.get_viewport()
	if viewport == null:
		return Rect2()
	var visible_rect := control.get_global_rect().intersection(viewport.get_visible_rect())
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
	if not _control_is_fully_rendered(canvas) or not canvas.has_method("current_view_snapshot") \
			or not canvas.has_method("global_rect_for_object"):
		return []
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	var result: Array = []
	for value in _array(snapshot.get("objects", [])):
		var data := value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
		if data.is_empty() or not bool(data.get("visible", true)):
			continue
		var semantic_id := str(data.get("id", data.get("object_id", ""))).strip_edges()
		var rendered_rect: Rect2 = canvas.call("global_rect_for_object", semantic_id)
		var clipped_rect := rendered_rect.intersection(canvas.get_global_rect())
		var rendered := not semantic_id.is_empty() and rendered_rect.has_area() \
			and _rect_encloses_with_tolerance(clipped_rect, rendered_rect)
		result.append({
			"semantic_id": semantic_id,
			"label": str(data.get("label", "")),
			"object_type": str(data.get("object_type", data.get("type", ""))),
			"enabled": bool(data.get("enabled", true)) and not bool(data.get("disabled", false)) and bool(data.get("interactive", true)),
			"rendered": rendered,
		})
	return result


func _room_selected_actions(canvas: Control) -> Array:
	if canvas == null or not _control_is_fully_rendered(canvas) \
			or not canvas.has_method("current_view_snapshot") \
			or not canvas.has_method("local_position_for_selected_info_action_button"):
		return []
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	var selected := _dict(snapshot.get("selected_info", {}))
	var selected_visible_value: Variant = selected.get("visible", false)
	var selected_object_id := str(selected.get("object_id", "")).strip_edges()
	if typeof(selected_visible_value) != TYPE_BOOL or not bool(selected_visible_value) or selected_object_id.is_empty():
		return []
	var board_scale_value: Variant = snapshot.get("board_scale", null)
	if typeof(board_scale_value) not in [TYPE_INT, TYPE_FLOAT] or float(board_scale_value) <= 0.0:
		return []
	var board_scale := float(board_scale_value)
	var result: Array = []
	var actions := _array(selected.get("actions", []))
	for index in range(actions.size()):
		var action := actions[index] as Dictionary if typeof(actions[index]) == TYPE_DICTIONARY else {}
		if action.is_empty():
			continue
		var enabled_value: Variant = action.get("enabled", false)
		var board_rect := _snapshot_rect(action.get("button_rect", {}))
		var local_center: Vector2 = canvas.call("local_position_for_selected_info_action_button", index)
		var local_size := board_rect.size * board_scale
		var global_start: Vector2 = canvas.get_global_transform_with_canvas() * (local_center - local_size * 0.5)
		var global_end: Vector2 = canvas.get_global_transform_with_canvas() * (local_center + local_size * 0.5)
		var global_rect := Rect2(
			Vector2(minf(global_start.x, global_end.x), minf(global_start.y, global_end.y)),
			Vector2(absf(global_end.x - global_start.x), absf(global_end.y - global_start.y))
		)
		var clipped_rect := global_rect.intersection(_clipped_control_rect(canvas))
		var rendered := board_rect.has_area() and local_size.x > 0.0 and local_size.y > 0.0 \
			and _inside_control(canvas, local_center) \
			and _rect_encloses_with_tolerance(clipped_rect, global_rect) \
			and _room_action_label_is_fully_rendered(action, board_rect)
		result.append({
			"id": str(action.get("id", "")),
			"action": str(action.get("action", "")),
			"action_id": str(action.get("action_id", "")),
			"emit_object_id": str(action.get("emit_object_id", "")),
			"label": str(action.get("label", "")),
			"disabled_reason": str(action.get("disabled_reason", "")),
			"index": index,
			"enabled": typeof(enabled_value) == TYPE_BOOL and bool(enabled_value),
			"selected_object_id": selected_object_id,
			"rendered": rendered,
			"rect": global_rect if rendered else Rect2(),
		})
	return result


func _room_action_label_is_fully_rendered(action: Dictionary, board_rect: Rect2) -> bool:
	var label := str(action.get("label", "")).strip_edges()
	var inline_value: Variant = action.get("inline", null)
	if label.is_empty() or not board_rect.has_area() or typeof(inline_value) != TYPE_BOOL:
		return false
	var font := ThemeDB.fallback_font
	if font == null:
		return false
	var font_size := 11 if bool(inline_value) else 9
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	return text_size.x <= board_rect.size.x - 8.0 + 0.75 \
		and text_size.y <= board_rect.size.y + 0.75


func _snapshot_rect(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value as Rect2
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data := value as Dictionary
	for key in ["x", "y", "w", "h"]:
		if not data.has(key) or typeof(data.get(key)) not in [TYPE_INT, TYPE_FLOAT]:
			return Rect2()
	return Rect2(
		Vector2(float(data.get("x")), float(data.get("y"))),
		Vector2(float(data.get("w")), float(data.get("h")))
	)


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
