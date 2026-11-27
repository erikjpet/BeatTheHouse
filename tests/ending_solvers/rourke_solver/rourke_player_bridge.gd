extends "res://tests/ending_solvers/ending_solver/visible_input.gd"

# The guarded solver uses the GUI input routines from the playtest bridge.
# Only the rendered observation below reaches the policy.
const GAME_FIELDS := [
	"game_id", "display_name", "phase", "selected_stake", "stake_min", "stake_max",
	"has_recent_outcome", "outcome_message", "round_complete", "active_hand_index",
	"can_deal", "can_hit", "can_stand", "can_double", "can_split", "can_surrender",
	"settle_available", "peek_available", "peek_window_open", "dealer_hole_visible",
	"dealer_up_card", "dealer_cards", "player_hands", "blackjack_total", "blackjack_soft",
	"boss_duel_active", "boss_player_stack", "boss_rourke_stack", "boss_hand_number",
	"boss_hand_limit", "boss_callout_used", "table_rules_text", "wager_currency",
	"main_wager_cost", "total_wager_cost",
]


func start_game() -> void:
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate() as Control
	root.add_child(app)
	await _wait_frames(8)


func observe() -> Dictionary:
	var observation := _public_observation()
	var screen := _dict(observation.get("screen", {}))
	var overlay := _dict(screen.get("overlay_state", {}))
	var screen_id := str(screen.get("screen", ""))
	var room := app.get("environment_canvas") as Control
	var game_canvas := app.get("game_surface_canvas") as Control
	var popup := bool(_dict(observation.get("event_popup", {})).get("visible", false))
	var talk_visible := bool(_dict(observation.get("talk", {})).get("visible", false))
	var map_visible := bool(screen.get("world_map_overlay_visible", false))
	var room_visible := _control_is_rendered(room) and not map_visible
	var game_visible := screen_id == "GAME" and _control_is_rendered(game_canvas) \
		and not (popup or talk_visible or map_visible) \
		and not bool(overlay.get("settings_visible", false)) \
		and not bool(overlay.get("run_inventory_visible", false)) \
		and not bool(overlay.get("run_menu_visible", false)) \
		and not bool(overlay.get("run_journal_visible", false))
	var raw_game := _dict(observation.get("game", {}))
	var game_actions := _game_surface_actions(game_canvas, raw_game) if game_visible else []
	observation["game"] = _visible_game(raw_game, game_actions) if game_visible else {}
	observation.erase("game_canvas")
	var spatial := _dict(observation.get("spatial", {}))
	spatial.erase("objects")
	var room_snapshot := _dict(observation.get("room_canvas", {}))
	room_snapshot.erase("objects")
	room_snapshot.erase("selected_info")
	if not room_visible:
		observation["room_canvas"] = {}
	var inventory := _dict(observation.get("inventory", {}))
	if not bool(inventory.get("visible", false)):
		observation["inventory"] = {}
	if not bool(_dict(observation.get("message", {})).get("visible", false)):
		observation["message"] = {}
	var buttons := _public_buttons().filter(func(row: Dictionary) -> bool: return row.get("fully_visible", false))
	if map_visible:
		_visible_map(screen, buttons)
	if bool(screen.get("run_menu_visible", false)):
		_visible_menu_seed(screen, _dict(observation.get("environment", {})))
	var coach := app.get("coach_overlay") as Control
	observation["coach"] = _visible_coach(coach)
	observation["clickable"] = {
		"buttons": buttons,
		"scroll_surfaces": _public_scroll_surfaces(),
		"text_fields": _visible_text_fields(),
		"talk_choices": _public_talk_choices(observation),
		"canvas_objects": _canvas_objects(room).filter(func(row: Dictionary) -> bool: return row.get("rendered", false)) if room_visible else [],
		"room_actions": _room_selected_actions(room).filter(func(row: Dictionary) -> bool: return row.get("rendered", false)) if room_visible else [],
		"game_surface_actions": game_actions,
	}
	return _json_safe(observation)


func _visible_menu_seed(screen: Dictionary, environment: Dictionary) -> void:
	var menu := _dict(screen.get("run_menu", {}))
	var label := app.get("run_menu_status_label") as Label
	if not _label_text_is_fully_rendered(label):
		menu.erase("status_text")
		return
	var first_line := label.text.get_slice("\n", 0)
	var venue := str(environment.get("display_name", "Current venue"))
	var delimiter := first_line.rfind(" | %s | Bankroll " % venue)
	if first_line.begins_with("Seed ") and delimiter > 5:
		menu["seed"] = first_line.substr(5, delimiter - 5)


func _visible_map(screen: Dictionary, buttons: Array) -> void:
	var map := _dict(screen.get("world_map", {}))
	var selected := str(map.get("selected_node_id", ""))
	var detail_visible := bool(screen.get("world_map_detail_popup_visible", false))
	var live_markers := {}
	for button in buttons:
		var button_name := str(button.get("id", "")).get_file()
		if button_name.begins_with("WorldMapNode_"):
			live_markers[button_name.trim_prefix("WorldMapNode_")] = true
	var nodes: Array = []
	for value in _array(map.get("nodes", [])):
		var node := _dict(value)
		var node_id := str(node.get("id", ""))
		if not live_markers.has(node_id):
			continue
		var marker := {}
		for key in ["id", "archetype_id", "display_name", "label", "kind", "state", "current", "selected"]:
			if node.has(key):
				marker[key] = node[key]
		if detail_visible and node_id == selected:
			marker["travel_enabled"] = bool(screen.get("world_map_confirm_enabled", false))
			for key in ["cost", "travel_disabled_reason", "open_status_text"]:
				if node.has(key):
					marker[key] = node[key]
		nodes.append(marker)
	map["nodes"] = nodes
	map.erase("edges")
	if not detail_visible:
		screen.erase("world_map_detail_text")


func _visible_game(source: Dictionary, game_actions: Array) -> Dictionary:
	var result := {}
	for key in GAME_FIELDS:
		if source.has(key):
			result[key] = source[key]
	var can_read_hand := game_actions.any(func(action: Dictionary) -> bool:
		return bool(action.get("enabled", false)) and str(action.get("action", "")) in [
			"blackjack_hit", "blackjack_stand", "blackjack_settle", "blackjack_boss_callout",
		]
	)
	if str(result.get("game_id", "")) == "blackjack" and not can_read_hand:
		for key in ["dealer_up_card", "dealer_cards", "player_hands", "blackjack_total", "blackjack_soft"]:
			result.erase(key)
	if bool(result.get("boss_duel_active", false)):
		# The ritual HUD renders the first 42 characters of the authored tell.
		result["boss_tell"] = str(source.get("boss_tell", "")).left(42)
		var callouts := _array(source.get("boss_callouts", []))
		var rendered_callouts: Array = []
		for action in game_actions:
			if str(action.get("action", "")) == "blackjack_boss_callout":
				var index := int(action.get("index", -1))
				if index >= 0 and index < callouts.size():
					var callout := _dict(callouts[index]).duplicate()
					callout["index"] = index
					callout["label"] = str(callout.get("label", "CALL")).to_upper().left(16)
					rendered_callouts.append(callout)
		result["boss_callouts"] = rendered_callouts
	return result


func _visible_coach(coach: Control) -> Dictionary:
	if not _control_is_rendered(coach) or not coach.has_method("current_snapshot"):
		return {}
	var source := _dict(coach.call("current_snapshot"))
	if not bool(source.get("visible", false)):
		return {}
	var result := {"visible": true}
	for key in ["copy", "anchor_id", "anchor_rect", "bubble_rect", "dismiss_label", "dismissible"]:
		if source.has(key):
			result[key] = source[key]
	return result


func send(command: String) -> Dictionary:
	var verb := command.get_slice(" ", 0)
	var argument := command.substr(verb.length()).strip_edges()
	var result: Dictionary
	match verb:
		"wait":
			if not argument.is_valid_int() or int(argument) < 1 or int(argument) > 3600:
				return {"ok": false, "reason": "wait requires 1 to 3600 frames"}
			await _wait_frames(int(argument))
			return {"ok": true}
		"click_button":
			result = await _click_button(argument)
		"click_object":
			result = await _click_object(argument.trim_suffix(" double"), argument.ends_with(" double"))
		"click_blank_room":
			result = await _click_blank_room()
		"click_action":
			result = await _click_action(argument)
		"click_map":
			result = await _click_map_node(argument)
		"click_choice":
			result = await _click_choice(argument)
		"set_field":
			result = await _set_field(argument)
		"scroll_surface":
			result = await _scroll_surface(argument)
		"key":
			result = await _push_key(argument)
		_:
			return {"ok": false, "reason": "unknown player input: %s" % verb}
	await _wait_frames(POST_INPUT_SETTLE_FRAMES)
	return {"ok": bool(result.get("ok", false)), "reason": str(result.get("reason", ""))}
