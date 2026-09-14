extends SceneTree

# Exercises the same environment-machine and popup-button input route used by
# the player. Direct calls to enter_game/activate_interactable_object are not a
# sufficient regression for this bug because they bypass PixelSceneCanvas hit
# testing and the selected-object action card.

const MainScene := preload("res://scenes/main.tscn")
const SlotMachineStateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const SAVE_SLOT := "slot_environment_entry_probe"
const PLAYER_SAVE_SLOT := "foundation_ui_autosave"
const SLOT_ARCHETYPES := [
	"bar",
	"gas_station_casino",
	"kitty_cat_lounge",
	"beach",
	"pawn_shop",
	RunState.GRAND_CASINO_ARCHETYPE_ID,
]

var app: Control
var failures: Array[String] = []
var reports: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.set("show_game_library_launcher", true)
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", PLAYER_SAVE_SLOT)
	root.add_child(app)
	await _settle(8)
	if OS.get_cmdline_user_args().has("--focused-multi"):
		_install_environment_fixture(RunState.GRAND_CASINO_ARCHETYPE_ID, "SLOT-HOST-MULTI")
		await _settle(12)
		var multi_slot_ids := _slot_object_ids()
		if multi_slot_ids.size() < 2:
			_fail("Grand Casino production fixture exposed fewer than two independently selectable Slot cabinets.")
		for slot_id in multi_slot_ids:
			reports.append(await _exercise_visible_entry("grand_casino", slot_id))
			app.call("back_to_environment")
			await _settle(8)
		_finish()
		return
	if OS.get_cmdline_user_args().has("--focused-play"):
		for seed_text in ["SLOT-HOST-PLAY-A", "SLOT-HOST-PLAY-B"]:
			_install_environment_fixture("bar", seed_text)
			await _settle(10)
			var slot_ids := _slot_object_ids()
			if slot_ids.is_empty():
				_fail("%s production-host room exposed no slot-machine object." % seed_text)
				continue
			reports.append(await _exercise_visible_entry(seed_text, slot_ids[0]))
			app.call("back_to_environment")
			await _settle(6)
		_finish()
		return

	# Read the player's current Continue state, but switch all subsequent writes
	# to an isolated probe slot before exercising any interaction.
	app.call("load_foundation_run")
	app.set("autosave_slot_id", SAVE_SLOT)
	await _settle(10)
	var continue_slot_ids := _slot_object_ids()
	for slot_id in continue_slot_ids:
		reports.append(await _exercise_visible_entry("continue", slot_id))
		app.call("back_to_environment")
		await _settle(8)

	reports.append(await _exercise_game_library_entry())

	_install_environment_fixture("bar")
	await _settle(8)
	reports.append(await _exercise_single_gate_entry())

	for archetype_id in SLOT_ARCHETYPES:
		_install_environment_fixture(archetype_id)
		await _settle(12)
		var fixture_slot_ids := _slot_object_ids()
		if fixture_slot_ids.is_empty():
			_fail("The production %s fixture did not expose a slot-machine object." % archetype_id)
			continue
		for slot_id in fixture_slot_ids:
			reports.append(await _exercise_visible_entry(archetype_id, slot_id))
			app.call("back_to_environment")
			await _settle(8)

	_finish()


func _finish() -> void:
	print("SLOT_ENVIRONMENT_ENTRY_PROBE %s" % JSON.stringify({
		"passed": failures.is_empty(),
		"failures": failures,
		"reports": reports,
	}))
	quit(0 if failures.is_empty() else 1)


func _exercise_game_library_entry() -> Dictionary:
	app.call("return_to_main_menu")
	await _settle(8)
	app.call("open_game_test_menu")
	await _settle(8)
	var menu: Control = app.get("game_test_menu")
	var blackjack_button := _button_with_text(menu, "Blackjack")
	if blackjack_button == null:
		_fail("The Game Library did not expose its Blackjack control fixture.")
		return {"label": "game_library", "entered": false}
	var blackjack_rect := blackjack_button.get_global_rect()
	_move_viewport_global(blackjack_rect.get_center())
	await _settle(2)
	_click_viewport_global(blackjack_rect.get_center())
	await _settle(12)
	var first_game: GameModule = app.get("current_game")
	var control_entered := str(app.get("current_screen")) == "GAME" and first_game != null and first_game.get_id() == "blackjack"
	app.call("return_to_main_menu")
	await _settle(8)
	app.call("open_game_test_menu")
	await _settle(8)
	menu = app.get("game_test_menu")
	var slot_button := _button_with_text(menu, "Slot")
	if slot_button == null:
		_fail("The Game Library did not expose its Slot button.")
		return {"label": "game_library", "entered": false}
	var rect := slot_button.get_global_rect()
	_move_viewport_global(rect.get_center())
	await _settle(2)
	var hovered := _hovered_control_payload()
	_click_viewport_global(rect.get_center())
	await _settle(12)
	var game: GameModule = app.get("current_game")
	var entered := str(app.get("current_screen")) == "GAME" and game != null and game.get_id() == "slot"
	if not entered:
		_fail("The Game Library Slot button did not open the slot surface.")
	return {
		"label": "game_library",
		"control_game_entered": control_entered,
		"button_rect": _rect_payload(rect),
		"hovered_control": hovered,
		"screen": str(app.get("current_screen")),
		"entered": entered,
	}


func _exercise_single_gate_entry() -> Dictionary:
	var coach: CoachOverlay = app.get("coach_overlay")
	var popup: Control = app.get("event_choice_popup_overlay")
	coach.set("active_lesson", {
		"id": "slot_entry_single_gate_probe",
		"completion": {"type": "anchored_action", "action_id": "game:slot"},
	})
	coach.set("visible", true)
	coach.lesson_completed.connect(func(_lesson_id: String) -> void: popup.visible = true, CONNECT_ONE_SHOT)
	var entered := bool(app.call("activate_interactable_object", "game:slot"))
	await _settle(4)
	var game: GameModule = app.get("current_game")
	var opened := entered and str(app.get("current_screen")) == "GAME" and game != null and game.get_id() == "slot"
	if not opened:
		_fail("A modal refresh at the slot action boundary consumed the machine-entry click.")
	var popup_was_visible := popup.visible
	popup.visible = false
	coach.call("suspend")
	return {
		"label": "single_input_gate",
		"boundary_modal_refreshed": popup_was_visible,
		"entered": opened,
	}


func _button_with_text(node: Node, wanted_text: String) -> Button:
	if node == null:
		return null
	if node is Button and (node as Button).text == wanted_text:
		return node as Button
	for child in node.get_children():
		var found := _button_with_text(child, wanted_text)
		if found != null:
			return found
	return null


func _install_environment_fixture(archetype_id: String, seed_text: String = "") -> void:
	var effective_seed := seed_text if not seed_text.is_empty() else "SLOT-ENVIRONMENT-ENTRY-PROBE-%s" % archetype_id.to_upper()
	app.call("start_foundation_run", effective_seed)
	app.set("autosave_slot_id", SAVE_SLOT)
	var run_state: RunState = app.get("run_state")
	run_state.bankroll = 10000
	var library: ContentLibrary = app.get("library")
	var archetype := library.environment_archetype(archetype_id)
	var room := archetype.duplicate(true)
	room["id"] = "slot_environment_entry_probe_%s" % archetype_id
	room["archetype_id"] = archetype_id
	room["display_name"] = str(archetype.get("display_name", archetype_id.capitalize()))
	room["game_ids"] = (archetype.get("game_pool", ["slot"]) as Array).duplicate()
	room["event_ids"] = []
	room["resolved_event_ids"] = []
	room["item_offers"] = []
	room["service_ids"] = []
	room["lender_hooks"] = []
	room["travel_hooks"] = (archetype.get("travel_hooks", []) as Array).duplicate()
	room["next_archetypes"] = ["bar"]
	room["game_states"] = {}
	room["layout"] = EnvironmentInstance.ensure_generated_layout(room)
	var slot_game: GameModule = app.call("_game_module_for_id", "slot")
	var fixture_count := maxi(1, int(((room.get("layout", {}) as Dictionary).get("game_fixture_counts", {}) as Dictionary).get("slot", 1)))
	var fixture_states: Dictionary = slot_game.generate_environment_fixture_states(
		run_state,
		room,
		run_state.create_rng("slot_environment_entry_probe_states:%s" % archetype_id),
		fixture_count
	)
	if not fixture_states.is_empty():
		room["game_states"] = fixture_states
	run_state.set_environment(room)
	app.set("current_game", null)
	app.call("_refresh_run_action_service")
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("clear_interaction_focus")
	app.call("_refresh")


func _slot_object_ids() -> Array[String]:
	var result: Array[String] = []
	for value in app.call("_interactable_object_view_list"):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = value
		if str(object_data.get("object_type", "")) == "game" and str(object_data.get("source_id", "")) == "slot":
			result.append(str(object_data.get("object_id", "")))
	return result


func _exercise_visible_entry(label: String, object_id: String) -> Dictionary:
	var canvas: PixelSceneCanvas = app.get("environment_canvas")
	if canvas == null:
		_fail("%s route has no environment canvas." % label)
		return {"label": label, "object_id": object_id, "entered": false}
	# A successful spin may legitimately schedule an unrelated room event. Clear
	# that modal between cabinet cases so it cannot intercept the next machine's
	# physical click; event presentation has its own focused acceptance probe.
	if bool(app.call("current_event_choice_popup_snapshot").get("visible", false)):
		app.call("_hide_event_choice_popup")
	if app.get("current_game") != null:
		app.call("back_to_environment")
		await _settle(8)
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("clear_interaction_focus")
	app.call("_refresh")
	await _settle(8)

	var object_rect := canvas.global_rect_for_object(object_id)
	if not object_rect.has_area():
		_fail("%s slot machine has no live hit rectangle." % label)
		return {"label": label, "object_id": object_id, "entered": false}
	var rendered_object := _canvas_object(canvas, object_id)
	var room_prop := str(rendered_object.get("prop", ""))
	if room_prop != "machine":
		_fail("%s slot object rendered as %s instead of a machine." % [label, room_prop if not room_prop.is_empty() else "<empty>"])
	_move_viewport_global(object_rect.get_center())
	await _settle(2)
	var hovered_before_click := _hovered_control_payload()
	_click_viewport_global(object_rect.get_center())
	await _settle(12)
	var action_rect := canvas.global_rect_for_selected_object_action(object_id)
	if not action_rect.has_area():
		var run_state: RunState = app.get("run_state")
		_fail("%s slot selection did not expose a live Enter button." % label)
		return {
			"label": label,
			"object_id": object_id,
			"object_rect": _rect_payload(object_rect),
			"canvas_pick": canvas.object_id_at_local_position(object_rect.get_center() - canvas.get_global_rect().position),
			"hovered_control": hovered_before_click,
			"run_status": run_state.run_status if run_state != null else "",
			"run_terminal": run_state.is_terminal() if run_state != null else false,
			"current_screen": str(app.get("current_screen")),
			"environment_canvas_visible": canvas.visible,
			"run_report_visible": (app.get("run_report_screen") as Control).visible,
			"selected": str(app.get("selected_object_id")),
			"entered": false,
		}
	_click_viewport_global(action_rect.get_center())
	await _settle(12)
	var entered := str(app.get("current_screen")) == "GAME" and app.get("current_game") != null and (app.get("current_game") as GameModule).get_id() == "slot"
	if not entered:
		_fail("%s visible slot Enter button did not open the slot surface (screen=%s game=%s)." % [label, str(app.get("current_screen")), str(app.get("current_game"))])
	var play_report := await _exercise_one_click_spin(label) if entered else {}
	return {
		"label": label,
		"object_id": object_id,
		"object_rect": _rect_payload(object_rect),
		"action_rect": _rect_payload(action_rect),
		"selected": str(app.get("selected_object_id")),
		"screen": str(app.get("current_screen")),
		"game_state_key": str(app.get("current_game_state_key")),
		"entered": entered,
		"room_prop": room_prop,
		"play": play_report,
	}


func _exercise_one_click_spin(label: String) -> Dictionary:
	var surface: GameSurfaceCanvas = app.get("game_surface_canvas")
	if surface == null or not surface.visible:
		_fail("%s entered Slot without a visible game surface." % label)
		return {"resolved": false}
	var run_state: RunState = app.get("run_state")
	var state_key := str(app.get("current_game_state_key"))
	var before_machine: Dictionary = SlotMachineStateScript.peek_machine(run_state.current_environment, state_key)
	var before_spins := int(before_machine.get("spin_count", 0))
	var surface_snapshot_before: Dictionary = surface.current_view_snapshot()
	var view_state_before: Dictionary = surface_snapshot_before.get("state", {}) if typeof(surface_snapshot_before.get("state", {})) == TYPE_DICTIONARY else {}
	var bet_options: Array = view_state_before.get("slot_bet_options", []) if typeof(view_state_before.get("slot_bet_options", [])) == TYPE_ARRAY else []
	var target_bet_index := mini(2, bet_options.size() - 1)
	var selected_bet_before := str(view_state_before.get("slot_selected_bet_id", ""))
	var selected_bet_after := selected_bet_before
	var bet_rect := Rect2()
	var bet_emitted_actions: Array = []
	if target_bet_index >= 0:
		bet_rect = surface.global_rect_for_surface_action("slot_bet", target_bet_index)
		if not bet_rect.has_area():
			_fail("%s Slot surface rendered no live bet-%d hit rectangle." % [label, target_bet_index])
		else:
			surface.surface_action.connect(func(action: String, index: int, confirm_requested: bool) -> void:
				bet_emitted_actions.append({"action": action, "index": index, "confirm_requested": confirm_requested})
			, CONNECT_ONE_SHOT)
			_move_viewport_global(bet_rect.get_center())
			await _settle(2)
			_click_viewport_global(bet_rect.get_center())
			await _settle(8)
			var after_bet_machine: Dictionary = SlotMachineStateScript.peek_machine(run_state.current_environment, state_key)
			selected_bet_after = str((after_bet_machine.get("bet_ladder", {}) as Dictionary).get("selected_id", ""))
			var expected_bet_id := str((bet_options[target_bet_index] as Dictionary).get("id", ""))
			if selected_bet_after != expected_bet_id:
				_fail("%s physical bet-%d click selected %s instead of %s." % [label, target_bet_index, selected_bet_after, expected_bet_id])
			if bet_emitted_actions.size() != 1 or str((bet_emitted_actions[0] as Dictionary).get("action", "")) != "slot_bet" or int((bet_emitted_actions[0] as Dictionary).get("index", -1)) != target_bet_index:
				_fail("%s physical bet-%d click did not emit exactly one matching slot_bet action." % [label, target_bet_index])
	var spin_rect := surface.global_rect_for_surface_action("slot_spin")
	if not spin_rect.has_area():
		_fail("%s Slot surface rendered no live Spin hit rectangle." % label)
		return {"resolved": false, "before_spins": before_spins}
	_move_viewport_global(spin_rect.get_center())
	await _settle(2)
	var hovered_control := _hovered_control_payload()
	var hovered_surface_action := str(surface.get("hovered_surface_action"))
	var emitted_actions: Array = []
	surface.surface_action.connect(func(action: String, index: int, confirm_requested: bool) -> void:
		emitted_actions.append({"action": action, "index": index, "confirm_requested": confirm_requested})
	, CONNECT_ONE_SHOT)
	var guard_visits_before := int(app.get("input_route_guard_visit_count"))
	var deferred_blocks_before := int(app.get("deferred_embedded_refresh_blocked_surface_input_count"))
	_click_viewport_global(spin_rect.get_center())
	await _settle(10)
	var after_machine: Dictionary = SlotMachineStateScript.peek_machine(run_state.current_environment, state_key)
	var after_spins := int(after_machine.get("spin_count", 0))
	var surface_snapshot: Dictionary = surface.current_view_snapshot()
	var view_state: Dictionary = surface_snapshot.get("state", {}) if typeof(surface_snapshot.get("state", {})) == TYPE_DICTIONARY else {}
	var ledger: Dictionary = app.call("_sealed_action_host_ledger", run_state, false)
	var pending_cleared := (ledger.get("pending_delivery", {}) as Dictionary).is_empty()
	var last_result: Dictionary = app.get("last_game_result")
	var table_binding := str(last_result.get("blackjack_host_apply_receipt", {}).get("table_binding", ""))
	var resolved := after_spins == before_spins + 1
	if not resolved:
		_fail("%s one physical Spin click changed spin_count from %d to %d; expected exactly one resolved spin." % [label, before_spins, after_spins])
	if str(surface_snapshot.get("surface_renderer", "")) != "slot_machine":
		_fail("%s Slot surface did not use the slot_machine renderer." % label)
	if not (view_state.get("slot_grid", []) as Array).size() > 0:
		_fail("%s resolved Slot surface exposed no reel grid." % label)
	if emitted_actions.size() != 1 or str((emitted_actions[0] as Dictionary).get("action", "")) != "slot_spin":
		_fail("%s physical Spin click did not emit exactly one slot_spin surface action." % label)
	if hovered_surface_action != "slot_spin":
		_fail("%s visible Spin button did not own its exact hover target." % label)
	if int(app.get("deferred_embedded_refresh_blocked_surface_input_count")) != deferred_blocks_before:
		_fail("%s Spin click was intercepted by a deferred surface refresh." % label)
	if not pending_cleared:
		_fail("%s resolved Spin left a sealed action pending." % label)
	if state_key != "slot" and not table_binding.ends_with(":%s" % state_key):
		_fail("%s cabinet %s did not receive a fixture-specific sealed binding (%s)." % [label, state_key, table_binding])
	var causal_context_rejected := true
	if label == "SLOT-HOST-PLAY-A":
		await _settle_until_surface_idle(surface)
		causal_context_rejected = _exercise_causal_context_rejection()
	if not causal_context_rejected:
		_fail("%s sealed Slot delivery did not reject a changed gameplay context." % label)
	return {
		"resolved": resolved,
		"before_spins": before_spins,
		"after_spins": after_spins,
		"selected_bet_before": selected_bet_before,
		"selected_bet_after": selected_bet_after,
		"bet_rect": _rect_payload(bet_rect),
		"bet_emitted_actions": bet_emitted_actions,
		"spin_rect": _rect_payload(spin_rect),
		"hovered_control_name": str(hovered_control.get("name", "")),
		"hovered_surface_action": hovered_surface_action,
		"emitted_actions": emitted_actions,
		"guard_visit_delta": int(app.get("input_route_guard_visit_count")) - guard_visits_before,
		"deferred_block_delta": int(app.get("deferred_embedded_refresh_blocked_surface_input_count")) - deferred_blocks_before,
		"pending_cleared": pending_cleared,
		"causal_context_rejected": causal_context_rejected,
		"surface_renderer": str(surface_snapshot.get("surface_renderer", "")),
		"grid_columns": (view_state.get("slot_grid", []) as Array).size(),
		"outcome_message": str(surface_snapshot.get("outcome_message", "")),
		"last_game_result": {
			"ok": bool(last_result.get("ok", false)),
			"error_code": str(last_result.get("error_code", "")),
			"message": str(last_result.get("message", "")),
			"request_key": str(last_result.get("blackjack_host_request_key", last_result.get("request_key", ""))),
			"table_binding": table_binding,
		},
	}


func _canvas_object(canvas: PixelSceneCanvas, object_id: String) -> Dictionary:
	var snapshot: Dictionary = canvas.current_view_snapshot()
	var objects: Array = snapshot.get("objects", []) if typeof(snapshot.get("objects", [])) == TYPE_ARRAY else []
	for object_value in objects:
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = object_value
		if str(object_data.get("id", object_data.get("object_id", ""))) == object_id:
			return object_data
	return {}


func _exercise_causal_context_rejection() -> bool:
	var command: Dictionary = app.call("_sealed_action_host_surface_intent", "slot_spin", 0, false)
	var delivery: Dictionary = command.get("_sealed_action_host_delivery", {}) if typeof(command.get("_sealed_action_host_delivery", {})) == TYPE_DICTIONARY else {}
	if delivery.is_empty():
		return false
	var live_run_state: RunState = app.get("run_state")
	live_run_state.baseline_luck += 1
	var prepared: Dictionary = app.call(
		"_sealed_action_host_prepare_delivery",
		str(command.get("action_id", "")),
		int(command.get("set_stake", 0)),
		delivery
	)
	return not bool(prepared.get("ok", false)) and str(prepared.get("error_code", "")) == "receipt_content_conflict"


func _settle_until_surface_idle(surface: GameSurfaceCanvas) -> void:
	for _frame_index in range(360):
		if not surface.surface_transition_animation_active():
			return
		await process_frame


func _click_viewport_global(global_position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = global_position
	press.global_position = global_position
	Input.parse_input_event(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = global_position
	release.global_position = global_position
	Input.parse_input_event(release)


func _move_viewport_global(global_position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = global_position
	motion.global_position = global_position
	Input.parse_input_event(motion)


func _hovered_control_payload() -> Dictionary:
	var hovered := root.gui_get_hovered_control()
	if hovered == null:
		return {}
	var children: Array[Dictionary] = []
	for child in hovered.get_children():
		if child is Control:
			children.append({
				"name": child.name,
				"class": child.get_class(),
				"text": str(child.get("text")) if child is Button or child is Label else "",
				"visible": child.visible,
				"rect": _rect_payload(child.get_global_rect()),
			})
	var ancestors: Array[Dictionary] = []
	var ancestor := hovered.get_parent()
	while ancestor != null and ancestors.size() < 7:
		if ancestor is Control:
			ancestors.append({
				"name": ancestor.name,
				"class": ancestor.get_class(),
				"visible": ancestor.visible,
				"mouse_filter": int(ancestor.mouse_filter),
				"rect": _rect_payload(ancestor.get_global_rect()),
			})
		ancestor = ancestor.get_parent()
	return {
		"name": hovered.name,
		"class": hovered.get_class(),
		"path": str(hovered.get_path()),
		"mouse_filter": int(hovered.mouse_filter),
		"rect": _rect_payload(hovered.get_global_rect()),
		"children": children,
		"ancestors": ancestors,
	}


func _settle(frame_count: int) -> void:
	for _index in range(frame_count):
		await process_frame


func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)


func _rect_payload(rect: Rect2) -> Dictionary:
	return {
		"x": snappedf(rect.position.x, 0.01),
		"y": snappedf(rect.position.y, 0.01),
		"w": snappedf(rect.size.x, 0.01),
		"h": snappedf(rect.size.y, 0.01),
	}
