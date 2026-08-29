extends SceneTree

# Windowed proof capture for the dialogue-guided first run. The mechanics are
# exercised by tutorial_seed_audit.gd; this tool stages those proven states in
# the production Main scene so TalkDock, coach focus, and room/game art are
# captured at readable scale.

const MainScene := preload("res://scenes/main.tscn")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const GameModuleScript := preload("res://scripts/core/game_module.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const BlackjackAuthorityTestDriverScript := preload("res://scripts/tests/foundation/blackjack_authority_test_driver.gd")

var app: Control
var out_dir := "res://.tmp/tutorial_rework/captures"
var capture_size := Vector2i(1280, 720)
var layout_failure_count := 0


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		elif argument.begins_with("--size="):
			var dimensions := argument.trim_prefix("--size=").to_lower().split("x", false, 1)
			if dimensions.size() == 2:
				capture_size = Vector2i(maxi(320, int(dimensions[0])), maxi(240, int(dimensions[1])))
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var layout_file := FileAccess.open("%s/layout_records.jsonl" % ProjectSettings.globalize_path(out_dir), FileAccess.WRITE)
	if layout_file != null:
		layout_file.store_string("")
	OS.set_environment("BTH_META_COLLECTION_PATH", "%s/tutorial_capture_meta.json" % ProjectSettings.globalize_path(out_dir))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(capture_size)
	root.content_scale_size = capture_size
	app = MainScene.instantiate()
	root.add_child(app)
	await _settle(10)
	app.call("start_tutorial_run")
	await _settle(14)
	await _save_shot("01_dialogue_highlight_apartment_pal")
	if not await _save_stability_record():
		quit(1)
		return
	app.call("focus_interactable_object", "item:xray_glasses")
	app.call("_sync_coach_environment_anchor_geometry")
	await _settle(4)
	await _save_shot("01b_xray_focus_opposite_dock")

	var run_state: RunState = app.get("run_state")
	if not run_state.inventory.has("xray_glasses"):
		run_state.add_item("xray_glasses")
	_clear_guide_state()
	app.call("open_run_inventory")
	await _settle(8)
	await _save_shot("02_apartment_xray_inventory")
	app.call("close_run_inventory")
	await _settle(4)
	_clear_guide_state()
	app.call("open_world_map")
	await _settle(8)
	await _save_shot("03_first_map_corner_store_only")
	app.call("close_world_map")

	_stage_environment("corner_store")
	_stage_guide_lesson("tutorial_inspect_coffee")
	await _settle(8)
	await _save_shot("03a_corner_shelf_both_items_highlighted")
	_clear_guide_state()
	var environment_canvas: Control = app.get("environment_canvas")
	if environment_canvas != null:
		environment_canvas.call("set_selected_object", "item:instant_coffee", true)
	await _settle(8)
	await _save_shot("03b_first_click_item_focus_addition_count")
	_clear_guide_state()
	app.call("start_dialogue", "family_phone_exchange", {"event_id": "capture:family_phone", "source": "tutorial_capture"})
	await _settle(8)
	await _save_shot("03c_family_phone_turn_taking")
	_clear_guide_state()
	_resolve_event("call_brother_in_law", "make_call")
	_resolve_event("family_loan", "accept")
	_stage_guide_lesson("tutorial_family_debt")
	await _settle(8)
	await _save_shot("04_corner_family_loan_real_debt")
	_clear_guide_state()
	_resolve_event("parking_lot_tip", "follow_tip")
	# Direct fixture resolution can leave the production consequence card open;
	# dismiss it exactly as the player would before selecting a map destination.
	app.call("_hide_event_choice_popup")
	app.call("open_world_map")
	# Keep the route-choice proof focused on the actual decision contract rather
	# than an unselected map. Selection is presentation-only; travel remains a
	# separate confirmation so this capture cannot advance the tutorial. Resolve
	# the target from the live choices because route identities may be generated
	# world-node instances or direct environment archetype ids.
	var route_target_id := ""
	var route_choices: Array = app.call("_travel_choice_view_list") as Array
	for route_choice_value in route_choices:
		if typeof(route_choice_value) != TYPE_DICTIONARY:
			continue
		var route_choice: Dictionary = route_choice_value
		var candidate_id := str(route_choice.get("target_id", route_choice.get("id", ""))).strip_edges()
		if candidate_id.is_empty():
			continue
		if route_target_id.is_empty() or str(route_choice.get("archetype_id", "")) == "gas_station_casino":
			route_target_id = candidate_id
	if route_target_id.is_empty() or not bool(app.call("select_world_map_node", route_target_id)):
		push_error("Tutorial capture could not select a live route decision frame.")
		quit(1)
		return
	_stage_guide_lesson("tutorial_route_choice")
	await _settle(8)
	await _save_shot("05_parking_tip_opens_path_a_and_b")
	app.call("close_world_map")

	_clear_guide_state()
	_stage_environment("gas_station_casino")
	if not run_state.inventory.has("xray_glasses"):
		run_state.add_item("xray_glasses")
	app.call("enter_game", "pull_tabs", "pull_tabs")
	await _settle(10)
	print("TUTORIAL_CAPTURE_SCREEN pull_tabs=%s" % str(app.get("current_screen")))
	_stage_guide_lesson("tutorial_gas_xray_buy")
	await _settle(8)
	await _save_shot("06_path_a_xray_winner_near_bottom")
	var redeemed_payout := _play_and_redeem_pull_tab()
	app.call("back_to_environment")
	_clear_guide_state()
	_stage_guide_lesson("tutorial_gas_redeem")
	await _settle(8)
	await _save_shot("07_path_a_clerk_payout_%d" % redeemed_payout)

	_clear_guide_state()
	_stage_environment("small_underground_casino")
	_stage_guide_lesson("tutorial_drink_intro")
	await _settle(8)
	await _save_shot("07a_underground_drink_intro")
	_clear_guide_state()
	app.call("enter_game", "blackjack", "blackjack")
	await _settle(8)
	print("TUTORIAL_CAPTURE_SCREEN blackjack=%s" % str(app.get("current_screen")))
	_clear_guide_state()
	await _settle(8)
	await _save_shot("07b_path_b_predeal_patrons_and_dealer")
	var raised_state := _stage_blackjack_raised_bet_surface()
	_stage_guide_lesson("tutorial_blackjack_raise")
	await _settle(8)
	await _save_shot("08_path_b_raised_bet_chips")
	_stage_blackjack_lookaway_surface(raised_state)
	_stage_guide_lesson("tutorial_blackjack_peek")
	await _settle(8)
	await _save_shot("09_path_b_real_lookaway_peek")
	_stage_blackjack_count_surface()
	_stage_guide_lesson("tutorial_blackjack_count_all")
	await _settle(8)
	await _save_shot("10_path_b_all_count_bubbles")
	_stage_blackjack_count_miss_surface()
	_stage_guide_lesson("tutorial_heat_warning")
	await _settle(8)
	await _save_shot("11_path_b_count_miss_heat_warning")

	app.call("back_to_environment")
	_clear_guide_state()
	_stage_guide_lesson("tutorial_accept_invitation")
	await _settle(8)
	await _save_shot("12_high_roller_invitation_accept")

	_clear_guide_state()
	_stage_environment("grand_casino")
	_stage_guide_lesson("tutorial_host_entry")
	await _settle(8)
	await _save_shot("13_grand_host_vivienne_reward_system")

	_clear_guide_state()
	_stage_guide_lesson("tutorial_rourke_intro")
	await _settle(8)
	await _save_shot("14_rourke_clean_play_intro")

	_clear_guide_state()
	_stage_guide_lesson("tutorial_take_comp")
	await _settle(8)
	await _save_shot("15_forced_free_comp")

	_clear_guide_state()
	var library: ContentLibrary = app.get("library")
	var generator := RunGeneratorScript.new(library)
	if not generator.enter_grand_casino_room(run_state, RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID):
		push_error("Tutorial capture could not enter the generated Grand Casino Cage.")
		quit(1)
		return
	var chip_purchase := run_state.buy_grand_casino_chips(10)
	print("TUTORIAL_CAPTURE_CAGE chips=%s stock=%d" % [JSON.stringify(chip_purchase), _cage_stock_count(run_state)])
	app.call("_reset_game_surface_runtime_state")
	app.call("clear_interaction_focus")
	app.call("_refresh")
	app.call("start_dialogue", "linda_cage_services", {"event_id": "capture:linda_tutorial", "source": "tutorial_capture", "start_node": "main"})
	await _settle(8)
	await _save_shot("16_linda_extended_chips_shop_debt")

	_clear_guide_state()
	run_state.grand_casino_chips = maxi(10, run_state.grand_casino_chips)
	_stage_environment("grand_casino")
	GameModuleScript.apply_result(run_state, {
		"ok": true,
		"type": "game_action",
		"action_id": "stand",
		"action_kind": "legal",
		"game_id": "blackjack",
		"environment_id": str(run_state.current_environment.get("id", "")),
		"stake": 1,
		"bankroll_delta": -1,
		"suspicion_delta": 0,
		"deltas": {"bankroll_delta": -1, "suspicion_delta": 0},
		"state": GameModule.RESULT_CONTINUE,
	}, run_state.create_rng("capture_bronze"))
	_stage_environment("grand_casino_cage")
	var bronze_claim := run_state.claim_grand_casino_players_card_tier()
	print("TUTORIAL_CAPTURE_BRONZE %s" % JSON.stringify(bronze_claim))
	app.call("start_dialogue", "tutorial_linda_bronze_finish", {"event_id": "capture:bronze_finish", "source": "tutorial_capture"})
	await _settle(8)
	await _save_shot("17_bronze_award_golden_card_goal")

	app.call("return_to_main_menu")
	await _settle(5)
	app.call("start_foundation_run", "NORMAL-HOST-CAPTURE", {})
	await _settle(8)
	_stage_environment("grand_casino")
	app.call("_queue_normal_grand_host_greeting", {"id": "normal_previous_room", "archetype_id": "bar"})
	await _settle(8)
	await _save_shot("18_normal_run_host_greeting")
	print("TUTORIAL_GUIDED_CAPTURE_DONE -> %s" % ProjectSettings.globalize_path(out_dir))
	quit(1 if layout_failure_count > 0 else 0)


func _stage_environment(archetype_id: String) -> bool:
	var library: ContentLibrary = app.get("library")
	var run_state: RunState = app.get("run_state")
	if library == null or run_state == null:
		return false
	var archetype := library.environment_archetype_for_challenge(library.environment_archetype(archetype_id), run_state.challenge_config)
	if archetype.is_empty():
		push_error("Tutorial capture archetype missing: %s" % archetype_id)
		return false
	var rng := run_state.create_rng("tutorial_capture:%s" % archetype_id)
	var environment := EnvironmentInstance.from_archetype(archetype, 1, rng, library, run_state.challenge_config)
	var data := environment.to_dict()
	data["world_node_id"] = archetype_id
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data)
	run_state.save_rng(rng)
	run_state.set_environment(data)
	app.call("_reset_game_surface_runtime_state")
	app.call("clear_interaction_focus")
	app.call("_refresh")
	return true


func _stage_guide_lesson(lesson_id: String) -> void:
	_clear_guide_state()
	var library: ContentLibrary = app.get("library")
	var coach: CoachOverlay = app.get("coach_overlay")
	var lesson := library.tutorial_lesson(lesson_id)
	if lesson.is_empty():
		push_error("Tutorial capture lesson missing: %s" % lesson_id)
		return
	lesson["trigger"] = {"state_predicates": []}
	coach.set_lessons([lesson])
	coach.begin_tutorial_run({})
	coach.evaluate_at_boundary(app.call("_coach_context_snapshot"))
	app.call("_refresh_talk_dock")
	var run_state: RunState = app.get("run_state")
	print("TUTORIAL_CAPTURE_DIALOGUE lesson=%s queued=%s" % [lesson_id, str(run_state.next_pending_talk_event().get("event_id", ""))])


func _clear_guide_state() -> void:
	var run_state: RunState = app.get("run_state")
	if run_state != null:
		while run_state.pending_talk_event_count() > 0:
			var entry := run_state.next_pending_talk_event()
			run_state.complete_talk_event_resolution(str(entry.get("event_id", "")))
	var talk_dock: TalkDock = app.get("talk_dock")
	if talk_dock != null:
		talk_dock.clear_entry()
	var coach: CoachOverlay = app.get("coach_overlay")
	if coach != null:
		coach.set_lessons([])
		coach.suspend()
	app.call("_refresh_talk_dock")
	app.call("_refresh_modal_contract_owner")
	app.call("_refresh")


func _resolve_event(event_id: String, choice_id: String) -> Dictionary:
	var library: ContentLibrary = app.get("library")
	var run_state: RunState = app.get("run_state")
	var event_module := EventModuleScript.new()
	event_module.setup(library.event(event_id), library)
	var result: Dictionary = event_module.resolve(run_state, run_state.current_environment, choice_id)
	app.set("last_hook_result", result)
	app.call("_refresh")
	return result


func _cage_stock_count(run_state: RunState) -> int:
	var shop: Variant = run_state.current_environment.get("cage_gift_shop_state", {})
	if typeof(shop) != TYPE_DICTIONARY:
		return 0
	var stock: Variant = (shop as Dictionary).get("stock", [])
	return (stock as Array).size() if typeof(stock) == TYPE_ARRAY else 0


func _play_and_redeem_pull_tab() -> int:
	var game: GameModule = app.get("current_game")
	var run_state: RunState = app.get("run_state")
	if game == null or run_state == null:
		return 0
	var opening := game.surface_state(run_state, run_state.current_environment, {})
	var item_state: Dictionary = opening.get("pull_tab_item_state", {}) if typeof(opening.get("pull_tab_item_state", {})) == TYPE_DICTIONARY else {}
	var target: Dictionary = item_state.get("xray_target", {}) if typeof(item_state.get("xray_target", {})) == TYPE_DICTIONARY else {}
	var deal_index := int(target.get("deal_index", 0))
	for buy_index in range(int(target.get("tickets_until", 0))):
		var command := game.surface_action_command("pull_tab_buy", deal_index, false, {}, run_state, run_state.current_environment)
		game.resolve_with_context(str(command.get("action_id", "")), int(command.get("set_stake", 1)), run_state, run_state.current_environment, run_state.create_rng("capture_pull_buy_%d" % buy_index), command.get("ui_state", {}))
	var ui_state: Dictionary = game.surface_action_command("pull_tab_collect_tray", 0, false, {}, run_state, run_state.current_environment).get("ui_state", {})
	while int(game.surface_state(run_state, run_state.current_environment, ui_state).get("pull_tab_stack_count", 0)) > 0:
		ui_state = game.surface_action_command("pull_tab_reveal_next", 0, false, ui_state, run_state, run_state.current_environment).get("ui_state", {})
		var file_command := game.surface_action_command("pull_tab_file_ticket", 0, false, ui_state, run_state, run_state.current_environment)
		ui_state = file_command.get("ui_state", {})
		var sort_result := game.resolve_with_context(str(file_command.get("action_id", "")), 0, run_state, run_state.current_environment, run_state.create_rng("capture_pull_sort"), ui_state)
		if not bool(sort_result.get("ok", false)):
			break
	var redeem_command := game.environment_action_command("ticket_redeemer", "redeem_pull_tab_winners", run_state, run_state.current_environment, run_state.create_rng("capture_pull_redeem"))
	var redeem_result: Dictionary = redeem_command.get("result", {}) if typeof(redeem_command.get("result", {})) == TYPE_DICTIONARY else {}
	if bool(redeem_result.get("ok", false)):
		GameModuleScript.apply_result(run_state, redeem_result, run_state.create_rng("capture_pull_apply"))
	app.set("last_hook_result", redeem_result)
	return int(redeem_result.get("pull_tab_redeemed_payout", 0))


func _stage_blackjack_raised_bet_surface() -> Dictionary:
	var game: GameModule = app.get("current_game")
	var run_state: RunState = app.get("run_state")
	if game == null or run_state == null:
		return {}
	BlackjackAuthorityTestDriverScript.pin_protected_peek_settlement_rng(run_state)
	var deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 4}, run_state, run_state.current_environment)
	var state: Dictionary = deal.get("ui_state", {})
	app.set("game_surface_ui_state", state)
	app.call("_refresh")
	return state


func _stage_blackjack_lookaway_surface(hand_state: Dictionary) -> void:
	var game: GameModule = app.get("current_game")
	var run_state: RunState = app.get("run_state")
	if game == null or run_state == null:
		return
	var distraction := BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_distraction", 4, run_state, run_state.current_environment)
	var distracted_state: Dictionary = distraction.get("ui_state", {})
	var peek := BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_peek", 4, run_state, run_state.current_environment, 0, true)
	var peek_result := BlackjackAuthorityTestDriverScript.resolve_surface_command(game, peek, 0, run_state, run_state.current_environment)
	var stand := BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_stand", 4, run_state, run_state.current_environment)
	var stand_result := BlackjackAuthorityTestDriverScript.resolve_surface_command(game, stand, 4, run_state, run_state.current_environment) if bool(stand.get("resolve", false)) else {}
	var stand_table: Dictionary = run_state.current_environment.get("game_states", {}).get("blackjack", {})
	var cleanup := BlackjackAuthorityTestDriverScript.advance_terminal_presentation(game, 4, run_state, run_state.current_environment)
	if not bool(stand_result.get("ok", false)) or bool(stand_result.get("dealer_caught_cheat", false)) or bool(stand_table.get("barred", false)) or not bool(cleanup.get("ok", false)):
		push_error("Tutorial capture protected Peek boundary failed: stand_ok=%s caught=%s barred=%s cleanup_ok=%s" % [str(stand_result.get("ok", false)), str(stand_result.get("dealer_caught_cheat", false)), str(stand_table.get("barred", false)), str(cleanup.get("ok", false))])
	app.set("game_surface_ui_state", peek_result.get("blackjack_surface_ui_state", peek.get("ui_state", {})))
	app.call("_refresh")


func _stage_blackjack_count_surface() -> void:
	var game: GameModule = app.get("current_game")
	var run_state: RunState = app.get("run_state")
	if game == null or run_state == null:
		return
	var deal := BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_deal", 4, run_state, run_state.current_environment)
	var deal_result := BlackjackAuthorityTestDriverScript.resolve_surface_command(game, deal, 4, run_state, run_state.current_environment)
	var count := BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_count", 4, run_state, run_state.current_environment)
	app.set("game_surface_ui_state", count.get("ui_state", deal_result.get("ui_state", {})))
	app.call("_refresh")


func _stage_blackjack_count_miss_surface() -> void:
	_stage_blackjack_count_surface()
	var game: GameModule = app.get("current_game")
	var run_state: RunState = app.get("run_state")
	var ui_state: Dictionary = app.get("game_surface_ui_state")
	if game == null or run_state == null or ui_state.is_empty():
		return
	var challenge: Dictionary = ui_state.get("count_challenge", {}) if typeof(ui_state.get("count_challenge", {})) == TYPE_DICTIONARY else {}
	var icons: Array = challenge.get("icons", []) if typeof(challenge.get("icons", [])) == TYPE_ARRAY else []
	var now := Time.get_ticks_msec()
	for icon_index in range(icons.size()):
		var icon: Dictionary = icons[icon_index]
		icon["spawn_msec"] = now - 10000
		icon["duration_msec"] = 1
		icons[icon_index] = icon
	challenge["icons"] = icons
	ui_state["count_challenge"] = challenge
	var result := BlackjackAuthorityTestDriverScript.resolve(game, "count_cards", 0, run_state, run_state.current_environment, run_state.create_rng("capture_count_miss"), ui_state)
	var final_state: Dictionary = result.get("blackjack_surface_ui_state", ui_state) if typeof(result.get("blackjack_surface_ui_state", ui_state)) == TYPE_DICTIONARY else ui_state
	app.set("game_surface_ui_state", final_state)
	app.set("last_game_result", result)
	app.call("_refresh")


func _save_shot(file_id: String) -> void:
	var talk_dock: TalkDock = app.get("talk_dock")
	if talk_dock != null:
		talk_dock.call("_complete_body_reveal")
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [ProjectSettings.globalize_path(out_dir), file_id]
	var error := image.save_png(path)
	if error != OK:
		push_error("Tutorial capture failed: %s (%d)" % [path, error])
	else:
		print("TUTORIAL_GUIDED_SHOT %s" % path)
	_append_layout_record(file_id)


func _append_layout_record(file_id: String) -> void:
	var talk_dock: TalkDock = app.get("talk_dock")
	var environment_canvas: Control = app.get("environment_canvas")
	if talk_dock == null or environment_canvas == null:
		return
	var dock_snapshot: Dictionary = talk_dock.current_snapshot()
	var occupied_rect: Rect2 = dock_snapshot.get("occupied_rect", Rect2())
	var reserved_rect: Rect2 = dock_snapshot.get("environment_reserved_rect", Rect2())
	var current_screen := str(app.get("current_screen"))
	var focus_composition: Rect2 = dock_snapshot.get("avoid_rect", Rect2())
	if not focus_composition.has_area() and current_screen == "ENVIRONMENT":
		focus_composition = environment_canvas.call("global_rect_for_selected_composition")
	var screen_rect := Rect2(Vector2.ZERO, app.get_viewport_rect().size)
	var overlap_free := not focus_composition.has_area() or not occupied_rect.intersects(focus_composition.grow(10.0))
	var fully_visible := not focus_composition.has_area() or screen_rect.encloses(focus_composition)
	var record := {
		"shot": file_id,
		"screen": current_screen,
		"logical_viewport_size": _vector_record(screen_rect.size),
		"dock_visible": bool(dock_snapshot.get("visible", false)),
		"layout_side": str(dock_snapshot.get("layout_side", "")),
		"layout_vertical": str(dock_snapshot.get("layout_vertical", "")),
		"anchored_bottom": bool(dock_snapshot.get("anchored_bottom", false)),
		"portrait_outer_edge": bool(dock_snapshot.get("portrait_outer_edge", false)),
		"occupied_rect": _rect_record(occupied_rect),
		"reserved_rect": _rect_record(reserved_rect),
		"avoid_rect": _rect_record(dock_snapshot.get("avoid_rect", Rect2())),
		"focus_composition_rect": _rect_record(focus_composition),
		"focus_overlap_free": overlap_free,
		"focus_fully_visible": fully_visible,
	}
	var file := FileAccess.open("%s/layout_records.jsonl" % ProjectSettings.globalize_path(out_dir), FileAccess.READ_WRITE)
	if file != null:
		file.seek_end()
		file.store_line(JSON.stringify(record))
	if bool(record.get("dock_visible", false)) and (str(record.get("layout_vertical", "")) != "bottom" or not bool(record.get("anchored_bottom", false)) or not bool(record.get("portrait_outer_edge", false)) or not overlap_free or not fully_visible):
		layout_failure_count += 1
		push_error("Tutorial capture layout invariant failed: %s" % JSON.stringify(record))


func _save_stability_record() -> bool:
	await _settle(30)
	var talk_dock: TalkDock = app.get("talk_dock")
	var environment_canvas: Control = app.get("environment_canvas")
	if talk_dock == null or environment_canvas == null:
		push_error("Tutorial capture could not record talk dock stability.")
		return false
	var dock_before: Dictionary = talk_dock.current_snapshot()
	var camera_before: Dictionary = environment_canvas.call("current_view_snapshot")
	await _settle(180)
	var dock_after: Dictionary = talk_dock.current_snapshot()
	var camera_after: Dictionary = environment_canvas.call("current_view_snapshot")
	var stable := int(dock_before.get("layout_side_change_count", -1)) == int(dock_after.get("layout_side_change_count", -2)) \
		and int(dock_before.get("layout_position_change_count", -1)) == int(dock_after.get("layout_position_change_count", -2)) \
		and int(camera_before.get("camera_target_refresh_count", -1)) == int(camera_after.get("camera_target_refresh_count", -2)) \
		and (camera_before.get("camera_offset", Vector2.INF) as Vector2).is_equal_approx(camera_after.get("camera_offset", Vector2.ZERO) as Vector2)
	var logical_viewport_size := app.get_viewport_rect().size
	var record := {
		"capture_size_requested": [capture_size.x, capture_size.y],
		"logical_viewport_size": _vector_record(logical_viewport_size),
		"idle_frames": 180,
		"stable": stable,
		"layout_side": str(dock_after.get("layout_side", "")),
		"layout_side_change_count_before": int(dock_before.get("layout_side_change_count", -1)),
		"layout_side_change_count_after": int(dock_after.get("layout_side_change_count", -1)),
		"layout_position_change_count_before": int(dock_before.get("layout_position_change_count", -1)),
		"layout_position_change_count_after": int(dock_after.get("layout_position_change_count", -1)),
		"camera_target_refresh_count_before": int(camera_before.get("camera_target_refresh_count", -1)),
		"camera_target_refresh_count_after": int(camera_after.get("camera_target_refresh_count", -1)),
		"camera_offset_before": _vector_record(camera_before.get("camera_offset", Vector2.ZERO)),
		"camera_offset_after": _vector_record(camera_after.get("camera_offset", Vector2.ZERO)),
		"occupied_rect_before": _rect_record(dock_before.get("occupied_rect", Rect2())),
		"occupied_rect_after": _rect_record(dock_after.get("occupied_rect", Rect2())),
	}
	var path := "%s/stability_%dx%d.json" % [ProjectSettings.globalize_path(out_dir), capture_size.x, capture_size.y]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Tutorial capture could not write stability record: %s" % path)
		return false
	file.store_string(JSON.stringify(record, "\t") + "\n")
	print("TUTORIAL_GUIDED_STABILITY %s stable=%s" % [path, str(stable)])
	if not stable:
		push_error("Tutorial capture detected idle talk-dock or camera churn: %s" % JSON.stringify(record))
	return stable


func _vector_record(value: Variant) -> Array:
	var vector: Vector2 = value if value is Vector2 else Vector2.ZERO
	return [vector.x, vector.y]


func _rect_record(value: Variant) -> Dictionary:
	var rect: Rect2 = value if value is Rect2 else Rect2()
	return {
		"position": _vector_record(rect.position),
		"size": _vector_record(rect.size),
	}


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame
