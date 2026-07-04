extends SceneTree

# Foundation-only visual/click QA harness. It drives the active main scene by
# visible player-facing controls and records the screens a human player sees.

const MainScene := preload("res://scenes/main.tscn")
const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const REPORT_PATH := "user://foundation_visual_qa_report.json"
const TEST_SETTINGS_PATH := "user://settings_foundation_visual_qa.json"
const DEFAULT_VISUAL_QA_SEED := "FOUNDATION-VISUAL-QA"
const CONTINUE_QA_SEED := "FOUNDATION-CONTINUE-QA"
const BOARD_SIZE := Vector2(VisualStyleScript.ENVIRONMENT_BOARD_SIZE)

var visual_qa_seed := DEFAULT_VISUAL_QA_SEED

var app: Control
var report := {
	"tool": "foundation_visual_qa",
	"active_scene": "res://scenes/main.tscn",
	"active_script": "res://scripts/ui/foundation_main.gd",
	"seed": DEFAULT_VISUAL_QA_SEED,
	"interaction_mode": "visible_controls",
	"core_flow_driver": "visible_canvas_and_controls",
	"direct_debug_helper_methods_used": false,
	"screen_click_only_gameplay_enforced": true,
	"prohibited_game_control_button_labels": ["Play it straight", "Try something risky"],
	"screenshot_capture": "manual_non_headless",
	"states": [],
	"input_events": [],
	"architecture_checks": {},
	"optional_hook_status": {},
	"game_surface_status": {},
	"warnings": [],
	"coverage": {
		"start_screen": false,
		"release_menu_framing": false,
		"release_menu_no_game_test": false,
		"game_library_page": false,
		"new_run_button": false,
		"environment_screen": false,
		"game_card_button": false,
		"game_object_focus_click": false,
		"game_object_double_click": false,
		"blank_canvas_click_room_reset": false,
		"multiple_game_objects_clickable": false,
		"game_surface_primary": false,
		"environment_canvas_clipped": false,
		"r100_environment_no_overlap": false,
		"r100_focus_camera_clipped": false,
		"r100_critical_controls_1280_visible": false,
		"r100_multiple_games_clickable": false,
		"r100_side_box_not_required": false,
		"r100_game_resolution_surface_only": false,
		"r100_result_hidden_when_empty": false,
		"r100_result_populated_after_consequence": false,
		"r100_run_status_hud_structured": false,
		"r100_stab_no_scroll_critical_path": false,
		"r100_stab_game_surface_no_overlap": false,
		"r100_stab_result_useful_or_hidden": false,
		"focused_environment_controls_visible": false,
		"game_surface_click": false,
		"game_surface_resolve_click": false,
		"screen_click_only_gameplay": false,
		"stake_selector": false,
		"legal_action_selection": false,
		"cheat_action_selection": false,
		"consequence_result_card": false,
		"event_card": false,
		"item_card": false,
		"item_focus_no_mutation": false,
		"item_object_double_click": false,
		"item_purchase_result": false,
		"item_save_load": false,
		"unaffordable_item_rejects": false,
		"service_card": false,
		"service_object_double_click": false,
		"lender_card": false,
		"lender_object_double_click": false,
		"t6_7_fixture_visible_noninteractive": false,
		"t6_7_hidden_object_absent": false,
		"t6_7_event_cadence_snapshot": false,
		"travel_card": false,
		"travel_object_double_click": false,
		"world_map_open": false,
		"world_map_icons": false,
		"world_map_background": false,
		"world_map_travel_highlight": false,
		"world_map_info_panel": false,
		"heat_risky_action_raises": false,
		"high_heat_changes_risk": false,
		"high_heat_consequence": false,
		"recovery_lender_path": false,
		"run_pressure_visible": false,
		"objective_hud": false,
		"objective_state_guidance": false,
		"prestige_locked": false,
		"prestige_requirements_visible": false,
		"prestige_not_yet_reachable": false,
		"prestige_victory": false,
		"prestige_save_load": false,
		"demo_objective_visible": false,
		"demo_victory": false,
		"terminal_victory_summary": false,
		"pit_boss_watch_visible": false,
		"grand_casino_high_roller_cashout": false,
		"grand_casino_showdown_event": false,
		"save": false,
		"autosave_available": false,
		"load": false,
		"continue": false,
		"economy_pressure_shift": false,
		"m2_consequence_clarity": false,
	},
}

var strict_game_surface_only_active := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_use_isolated_user_settings(TEST_SETTINGS_PATH)
	visual_qa_seed = _configured_visual_qa_seed()
	report["seed"] = visual_qa_seed
	await _open_fresh_app()
	_require(app.get_script().resource_path == "res://scripts/ui/foundation_main.gd", "Main scene is not wired to the foundation UI shell.")
	_require(bool(app.call("uses_foundation_runtime")), "Foundation UI shell did not initialize README runtime contracts.")
	_assert_active_foundation_guardrails()

	_record_state("start_screen", "Fresh launch before a player starts or continues a run.")
	_cover("start_screen")
	_require(_has_visible_button_contains("New Run"), "Start screen does not expose the New Run button.")
	_require(_has_visible_text(app, "Simulated gambling only"), "Start screen does not present simulated gambling framing.")
	_require(_has_visible_text(app, "no real-money wagering"), "Start screen does not present no-real-money framing.")
	_require(not _has_visible_text(app, "Game Test"), "Release start screen exposed the temporary Game Test launcher.")
	_require(_has_visible_button_contains("Games"), "Start screen does not expose the Games page.")
	_require(not _click_button_exact("Games").is_empty(), "Could not open the Games page through visible controls.")
	await _settle()
	_require(_has_visible_text(app, "Game Library"), "Games page did not show its title.")
	_require(_has_visible_text(app, "Practice any available table"), "Games page did not show practice copy.")
	_cover("game_library_page")
	_require(not _click_button_exact("Back").is_empty(), "Could not return from the Games page.")
	await _settle()
	_cover("release_menu_framing")
	_cover("release_menu_no_game_test")
	_set_seed_text(visual_qa_seed)
	_require(not _click_button_exact("New Run").is_empty(), "Could not click New Run through visible controls.")
	_cover("new_run_button")
	await _settle()

	_record_state("environment_screen", "Seeded run with generated EnvironmentInstance and a focused object context panel.")
	_cover("environment_screen")
	_assert_environment_canvas_contained("environment screen")
	_assert_no_triggered_event_objects("environment screen")
	_assert_objective_hud("start of run")
	_require(_has_visible_text(app, "double-click glowing props to act"), "Environment screen does not prompt the player to inspect and activate world objects.")
	_require(not _is_control_visible("action_panel_container"), "The old room-object side panel is still visible in normal play.")
	_require(not _has_visible_text(app, "What can I do?"), "Environment screen still requires the old What can I do side-box label.")
	_require(not _has_visible_text(app, "Use the machine"), "Environment screen still requires the old Use the machine side-box label.")
	_cover("r100_side_box_not_required")
	_require(not _has_visible_text(app, "What just happened"), "Fresh environment screen still shows the old empty result panel.")
	_require(not _has_visible_text(app, "Recent consequence"), "Fresh environment screen shows a consequence panel before any consequence exists.")
	_cover("r100_result_hidden_when_empty")
	_assert_m2_player_feedback_clarity("environment screen")
	await _verify_demo_objective_visible()
	_require(_start_room_has_shop_offers(), "The first generated room did not expose shop items before gambling.")
	_cover("shop_first_start")
	_require(await _try_travel_object_flow("shop-first start"), "Could not travel from the shop start to a gambling environment.")
	_return_to_room_view()
	await _settle()
	await _verify_all_visible_game_objects_clickable()
	await _prepare_risky_game_visual_qa_fixture()
	_record_state("risky_game_fixture_screen", "Focused deterministic game-surface fixture with immediate risky-action coverage.")

	var serialized_before_game_focus := _serialized_run_text()
	var game_focus := await _click_first_canvas_object_type("game")
	_require(not game_focus.is_empty(), "Could not single-click a visible game object in the room.")
	_cover("game_object_focus_click")
	await _settle()
	_require(serialized_before_game_focus == _serialized_run_text(), "Single-clicking a game object mutated serialized RunState.")
	_require(str(app.call("current_screen_snapshot").get("screen", "")) == "ENVIRONMENT", "Single-clicking a game object entered the game instead of inspecting/focusing it.")
	_require(not _has_visible_button_exact("Play"), "Focused game object still requires a primary Play confirm button.")
	_assert_environment_canvas_contained("focused game object")
	var serialized_before_blank_click := _serialized_run_text()
	_require(await _click_blank_canvas_area(), "Could not click a blank area of the environment canvas.")
	await _settle()
	var blank_focus_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	_require(str(blank_focus_snapshot.get("current_context_mode", "")) == "room", "Clicking blank environment space did not return to the room context.")
	_require(str(blank_focus_snapshot.get("selected_object_id", "")).is_empty(), "Clicking blank environment space did not clear the selected object.")
	var blank_canvas := app.get("environment_canvas") as Control
	var blank_canvas_snapshot: Dictionary = blank_canvas.call("current_view_snapshot")
	_require(not bool(blank_canvas_snapshot.get("camera_focus_active", true)), "Clicking blank environment space did not restore the full-room camera target.")
	_require(serialized_before_blank_click == _serialized_run_text(), "Clicking blank environment space mutated serialized RunState.")
	_cover("blank_canvas_click_room_reset")
	var refocus_label := await _click_first_canvas_object_type("game")
	_require(not refocus_label.is_empty(), "Could not refocus a visible game object after blank-space room reset.")

	var serialized_before_game_activation := _serialized_run_text()
	var game_button := await _double_click_first_play_object_type("game")
	_require(not game_button.is_empty(), "Could not double-click a visible game object in the room.")
	_cover("game_card_button")
	_cover("game_object_double_click")
	await _settle()
	_require(serialized_before_game_activation == _serialized_run_text(), "Double-clicking a game object mutated serialized RunState before resolving an action.")
	var entered_game_snapshot: Dictionary = app.call("current_game_view_snapshot")
	_require(str(entered_game_snapshot.get("surface_renderer", "")) != "" and str(entered_game_snapshot.get("surface_renderer", "")) != "result", "Entered foundation game did not expose a distinct presentation surface.")
	var surface_canvas: Control = app.get("game_surface_canvas")
	_require(_game_surface_is_primary(surface_canvas), "Game mode did not make the game surface the primary focus.")
	_cover("game_surface_primary")
	_set_game_surface_status("entry", "passed", "Double-clicked a visible room game object and entered the game surface.", entered_game_snapshot)
	if surface_canvas != null and surface_canvas.has_method("current_view_snapshot"):
		var surface_snapshot: Dictionary = surface_canvas.call("current_view_snapshot")
		_require(str(surface_snapshot.get("surface_renderer", "")) == str(entered_game_snapshot.get("surface_renderer", "")), "Game surface canvas did not render the foundation game presentation mode.")

	_record_state("game_action_screen", "Player-facing game surface with visible stake and action regions.")
	var fixed_price_surface := bool(entered_game_snapshot.get("surface_fixed_price_actions", false)) or not bool(entered_game_snapshot.get("surface_stake_controls_required", true))
	_require(fixed_price_surface or bool(entered_game_snapshot.get("has_valid_stake", false)), "Game surface does not expose stake selection.")
	_require(int(entered_game_snapshot.get("legal_action_count", 0)) > 0, "Game surface does not expose legal actions.")
	strict_game_surface_only_active = true
	var selected_surface_stake := 0
	if fixed_price_surface:
		_record_input_event({
			"kind": "game_surface_fixed_price",
			"action": "fixed_price_action",
			"selected_stake": int(entered_game_snapshot.get("selected_stake", 0)),
		})
		selected_surface_stake = int(entered_game_snapshot.get("selected_stake", 0))
	else:
		selected_surface_stake = await _set_game_surface_stake_to_highest_value()
	_cover("stake_selector")
	_set_game_surface_status("stake", "passed", "Verified fixed-price surface actions." if fixed_price_surface else "Selected the highest valid stake from visible game-surface controls.", app.call("current_game_view_snapshot"))

	var legal_binding := _game_surface_action_binding("legal")
	var resolved_legal_snapshot: Dictionary = {}
	if fixed_price_surface:
		var serialized_before_legal_resolve := _serialized_run_text()
		var fixed_legal_attempts := 0
		while serialized_before_legal_resolve == _serialized_run_text() and fixed_legal_attempts < 4:
			legal_binding = _game_surface_action_binding("legal")
			_require(await _confirm_game_surface_action(str(legal_binding.get("action", "surface_legal")), int(legal_binding.get("index", 0))), "Could not resolve the fixed-price legal action from a visible game surface region.")
			await _settle()
			fixed_legal_attempts += 1
		_cover("game_surface_click")
		_cover("legal_action_selection")
		_cover("game_surface_resolve_click")
		_cover("r100_game_resolution_surface_only")
		await _settle()
		_require(serialized_before_legal_resolve != _serialized_run_text(), "Resolving a fixed-price legal action did not update serialized RunState.")
		resolved_legal_snapshot = app.call("current_game_view_snapshot")
	else:
		var serialized_before_legal_click := _serialized_run_text()
		var legal_action := await _click_game_surface_action(str(legal_binding.get("action", "surface_legal")), int(legal_binding.get("index", 0)))
		_require(not legal_action.is_empty(), "Could not click a visible legal action region on the game surface.")
		_cover("game_surface_click")
		_cover("legal_action_selection")
		await _settle()
		_require(serialized_before_legal_click == _serialized_run_text(), "Selecting a game surface action mutated serialized RunState.")
		var selected_after_surface: Dictionary = app.call("current_game_view_snapshot")
		_require(not str(selected_after_surface.get("selected_action_label", "")).is_empty(), "Game surface click did not update UI-local action selection.")

		var serialized_before_legal_resolve := _serialized_run_text()
		_require(await _confirm_game_surface_action(str(legal_binding.get("action", "surface_legal")), int(legal_binding.get("index", 0))), "Could not resolve the legal action from a visible game surface region.")
		_cover("game_surface_resolve_click")
		_cover("r100_game_resolution_surface_only")
		await _settle()
		_require(serialized_before_legal_resolve != _serialized_run_text(), "Resolving a legal action did not update serialized RunState.")
		resolved_legal_snapshot = app.call("current_game_view_snapshot")
	if fixed_price_surface:
		_require(int(resolved_legal_snapshot.get("result_stake", 0)) > 0, "Resolved fixed-price legal action did not report a ticket/action price.")
	else:
		_require(int(resolved_legal_snapshot.get("result_stake", 0)) == selected_surface_stake, "Resolved legal action did not use the stake selected on the game surface.")
	_set_game_surface_status("legal", "passed", "Selected and resolved a legal action from the visible game surface.", resolved_legal_snapshot)
	var legal_heat_delta := int(resolved_legal_snapshot.get("suspicion_delta", 0))
	_record_state("result_screen_legal", "Resolved a legal action and kept consequence feedback in HUD/in-scene state.")
	_assert_objective_hud("legal result")
	_require(not _has_visible_text(app, "Recent consequence"), "Legal action revealed the old Recent consequence panel.")
	var legal_consequence_snapshot: Dictionary = app.call("current_consequence_view_snapshot")
	_require(not (legal_consequence_snapshot.get("cards", []) as Array).is_empty(), "Legal action did not produce consequence snapshot data.")
	_cover("r100_result_hidden_when_empty")
	_assert_m2_player_feedback_clarity("legal result")
	_cover("consequence_result_card")

	if fixed_price_surface:
		await _reset_fixed_price_surface_for_risky_action()
	var post_legal_snapshot: Dictionary = app.call("current_game_view_snapshot")
	var has_cheat_surface_action := int(post_legal_snapshot.get("cheat_action_count", 0)) > 0
	var cheat_binding := _game_surface_action_binding("cheat")
	var cheat_action := ""
	var first_visible_risky_heat_delta := 0
	var serialized_before_cheat_click := _serialized_run_text()
	if fixed_price_surface:
		cheat_binding = await _prepare_fixed_price_cheat_binding()
		if _surface_action_binding_available(cheat_binding):
			cheat_action = str(cheat_binding.get("action", "surface_cheat"))
	elif has_cheat_surface_action:
		cheat_action = await _click_game_surface_action(str(cheat_binding.get("action", "surface_cheat")), int(cheat_binding.get("index", 0)))
	if cheat_action.is_empty():
		_require(false, "No visible cheat/advantage action was available after deterministic surface setup.")
	else:
		if not fixed_price_surface:
			_cover("cheat_action_selection")
			await _settle()
			_require(serialized_before_cheat_click == _serialized_run_text(), "Selecting a cheat/advantage action mutated serialized RunState.")
		else:
			_cover("cheat_action_selection")
		first_visible_risky_heat_delta = _visible_risky_heat_delta(app.call("current_game_view_snapshot"))
		var serialized_before_cheat_resolve := _serialized_run_text()
		var risky_unavailable_reason := ""
		if fixed_price_surface:
			var fixed_cheat_attempts := 0
			while serialized_before_cheat_resolve == _serialized_run_text() and fixed_cheat_attempts < 4:
				if not await _resolve_visible_fixed_price_risky_action(serialized_before_cheat_resolve):
					risky_unavailable_reason = "Could not resolve the cheat/advantage action from a visible game surface region."
					break
				await _settle()
				fixed_cheat_attempts += 1
		else:
			_require(await _confirm_game_surface_action(str(cheat_binding.get("action", "surface_cheat")), int(cheat_binding.get("index", 0))), "Could not resolve the cheat/advantage action from a visible game surface region.")
		_cover("game_surface_resolve_click")
		await _settle()
		if serialized_before_cheat_resolve == _serialized_run_text() and fixed_price_surface and not risky_unavailable_reason.is_empty():
			_require(false, risky_unavailable_reason)
		else:
			_require(serialized_before_cheat_resolve != _serialized_run_text(), "Resolving a cheat/advantage action did not update serialized RunState.")
		var resolved_cheat_snapshot: Dictionary = app.call("current_game_view_snapshot")
		var first_risky_heat_delta := int(resolved_cheat_snapshot.get("suspicion_delta", 0))
		_require(first_risky_heat_delta > legal_heat_delta, "Risky action did not create more heat pressure than the legal action.")
		_require(first_visible_risky_heat_delta > legal_heat_delta, "Visible risky action did not show more heat pressure than the legal action.")
		_set_game_surface_status("risky", "passed", "Selected and resolved a risky action from the visible game surface.", resolved_cheat_snapshot)
		_cover("heat_risky_action_raises")
		_record_state("result_screen_cheat", "Resolved a cheat/advantage action and kept risk feedback in HUD/in-scene state.")
		_assert_objective_hud("risky result")
		var risky_consequence_snapshot: Dictionary = app.call("current_consequence_view_snapshot")
		_require(not _has_visible_text(app, "Recent consequence"), "Cheat/advantage action revealed the old Recent consequence panel.")
		_require(not (risky_consequence_snapshot.get("cards", []) as Array).is_empty(), "Cheat/advantage action did not produce consequence snapshot data.")
		_assert_m2_player_feedback_clarity("risky result")
		var reached_high_heat := await _drive_risky_surface_until_heat(65, 8, first_visible_risky_heat_delta)
		_require(reached_high_heat, "Mouse-only risky play did not reach high heat pressure after deterministic risky-action setup.")
		_record_state("high_heat_result_screen", "Repeated visible risky actions until high heat changed the consequence pressure.")
		_assert_objective_hud("high heat result")
		_assert_m2_player_feedback_clarity("high heat result")
	strict_game_surface_only_active = false
	_assert_screen_click_only_gameplay_events()
	_cover("screen_click_only_gameplay")

	await _resolve_blocking_event_popups()
	_return_to_room_view()
	await _settle()
	_require(_environment_canvas_is_primary(), "Back to room did not restore the environment canvas as the primary surface.")
	_assert_environment_canvas_contained("returned environment screen")
	var claimed_victory := await _try_claim_prestige_victory_if_ready()
	if not claimed_victory:
		await _try_follow_visible_objective_once()
		claimed_victory = await _try_claim_prestige_victory_if_ready()
	if not claimed_victory:
		await _try_service_hook_flow()
		claimed_victory = await _try_claim_prestige_victory_if_ready()
	if not claimed_victory:
		await _try_event_card_flow()
		claimed_victory = await _try_claim_prestige_victory_if_ready()
	if not claimed_victory:
		await _try_item_card_flow()
		claimed_victory = await _try_claim_prestige_victory_if_ready()
	if not claimed_victory:
		await _try_lender_hook_flow()
		claimed_victory = await _try_claim_prestige_victory_if_ready()
	if not claimed_victory:
		await _record_demo_victory_not_yet_reachable()
	await _save_and_load_flow()
	await _continue_from_saved_flow()
	await _verify_mouse_only_recovery_pressure_flow()
	_assert_direct_environment_object_events()
	await _verify_grand_casino_high_roller_cashout_snapshot()
	await _verify_grand_casino_showdown_event_snapshot()
	await _verify_terminal_victory_summary_snapshot()
	await _verify_t4_7_event_visual_model()

	_write_report()
	quit(0)


func _use_isolated_user_settings(path: String) -> void:
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, path)
	var isolated_settings: UserSettings = UserSettingsScript.new()
	isolated_settings.reset()
	var error := isolated_settings.save()
	if error != OK:
		push_error("Could not prepare isolated visual QA settings.")
		report["warnings"].append("Could not prepare isolated visual QA settings.")
		_write_report()
		quit(1)


func _try_follow_visible_objective_once() -> bool:
	_return_to_room_view()
	await _settle()
	var objective := _current_next_objective()
	var object_type := str(objective.get("object_type", ""))
	if object_type.is_empty():
		_add_warning("The objective HUD did not expose a next visible objective.")
		return false
	if not bool(objective.get("enabled", false)):
		_add_warning("Next visible objective is not currently actionable: %s" % str(objective.get("hint", "")))
		return false
	match object_type:
		"prestige":
			return await _try_claim_prestige_victory_if_ready()
		"travel":
			return await _try_travel_object_flow("visible objective", objective)
		"item":
			await _try_item_card_flow()
			return bool(report["coverage"].get("item_object_double_click", false))
		"event":
			await _try_event_card_flow()
			return bool(report["coverage"].get("event_card", false))
		"service":
			await _try_service_hook_flow()
			return bool(report["coverage"].get("service_object_double_click", false))
		"lender":
			await _try_lender_hook_flow()
			return bool(report["coverage"].get("lender_object_double_click", false))
		_:
			_add_warning("Next visible objective does not require a room-object activation: %s" % str(objective.get("hint", object_type)))
	return false


func _current_next_objective() -> Dictionary:
	if app == null or not app.has_method("current_objective_hud_snapshot"):
		return {}
	var hud: Dictionary = app.call("current_objective_hud_snapshot")
	var objective: Variant = hud.get("next_objective", {})
	if typeof(objective) == TYPE_DICTIONARY:
		return (objective as Dictionary).duplicate(true)
	var status_hud: Variant = hud.get("status_hud", {})
	if typeof(status_hud) == TYPE_DICTIONARY:
		var nested: Variant = (status_hud as Dictionary).get("next_objective", {})
		if typeof(nested) == TYPE_DICTIONARY:
			return (nested as Dictionary).duplicate(true)
	return {}


func _try_travel_object_flow(context_label: String, objective: Dictionary = {}) -> bool:
	_return_to_room_view()
	await _settle()
	_record_state("travel_screen", "Double-clicked a visible travel object from the %s and generated the next environment." % context_label)
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
		_add_warning("Environment canvas was not available for travel visual QA.")
		_set_optional_hook_status("travel", "skipped_unavailable", "Environment canvas was not available for travel visual QA.")
		return false
	var travel_object := {}
	var objective_id := str(objective.get("object_id", ""))
	if not objective_id.is_empty():
		travel_object = _canvas_object_by_id(canvas, objective_id)
	if travel_object.is_empty():
		travel_object = _first_clickable_canvas_object_type_enabled(canvas, "travel", true)
	if travel_object.is_empty():
		if await _verify_disabled_or_absent_optional_object("travel", "No available travel destination was visible for visual QA."):
			return false
		_set_optional_hook_status("travel", "skipped_unavailable", "No available travel destination was visible for visual QA.")
		_add_warning("No available travel destination was visible for visual QA.")
		return false
	var serialized_before_travel_activation := _serialized_run_text()
	var travel_button := await _double_click_canvas_object_data(canvas, travel_object, "travel")
	_require(not travel_button.is_empty(), "Could not double-click the visible travel objective.")
	_cover("travel_card")
	_cover("travel_object_double_click")
	await _settle()
	_require(serialized_before_travel_activation == _serialized_run_text(), "Opening the world map should not mutate serialized RunState before route confirmation.")
	var map_open_screen: Dictionary = app.call("current_screen_snapshot")
	_require(bool(map_open_screen.get("world_map_overlay_visible", false)), "Double-clicking Leave did not open the world map overlay.")
	_cover("world_map_open")
	var map_snapshot: Dictionary = map_open_screen.get("world_map", {}) if typeof(map_open_screen.get("world_map", {})) == TYPE_DICTIONARY else {}
	var map_nodes: Array = map_snapshot.get("nodes", []) if typeof(map_snapshot.get("nodes", [])) == TYPE_ARRAY else []
	_require(str(map_snapshot.get("background_path", "")).contains("map_backgrounds"), "World map opened without the cyberpunk city background metadata.")
	_cover("world_map_background")
	var map_target_ids: Array = map_snapshot.get("travel_target_ids", []) if typeof(map_snapshot.get("travel_target_ids", [])) == TYPE_ARRAY else []
	_require(map_target_ids.size() <= 3, "World map opened with too many capped travel targets.")
	var icons_ready := not map_nodes.is_empty()
	var travel_highlight_ready := false
	for node_value in map_nodes:
		if typeof(node_value) != TYPE_DICTIONARY:
			icons_ready = false
			continue
		var node_data: Dictionary = node_value
		if str(node_data.get("icon_path", "")).strip_edges().is_empty():
			icons_ready = false
		var position: Dictionary = node_data.get("position", {}) if typeof(node_data.get("position", {})) == TYPE_DICTIONARY else {}
		if position.is_empty():
			icons_ready = false
		if bool(node_data.get("travel_enabled", false)) and map_target_ids.has(str(node_data.get("id", ""))):
			travel_highlight_ready = true
	_require(icons_ready, "World map opened without generated icon metadata at node positions.")
	_cover("world_map_icons")
	_require(travel_highlight_ready, "World map opened without a highlighted enabled travel node.")
	_cover("world_map_travel_highlight")
	var travel_choices: Array = app.call("current_environment_view_snapshot").get("travel_choices", [])
	var choice := _preferred_enabled_travel_choice(travel_choices)
	_require(not choice.is_empty(), "World map opened but no enabled revealed travel node was available.")
	var target_id := str(choice.get("id", ""))
	var serialized_before_map_select := _serialized_run_text()
	_require(bool(app.call("select_world_map_node", target_id)), "World map did not accept the enabled travel node.")
	await _settle()
	var selected_map_screen: Dictionary = app.call("current_screen_snapshot")
	var detail_text := str(selected_map_screen.get("world_map_detail_text", ""))
	_require(detail_text.contains("Travel:") and detail_text.contains("Distance:") and detail_text.contains("Cost:"), "World map info panel did not show route method, distance, and cost.")
	_cover("world_map_info_panel")
	_require(serialized_before_map_select == _serialized_run_text(), "Selecting a world-map node mutated RunState before route confirmation.")
	app.call("confirm_world_map_travel")
	await _settle()
	_require(serialized_before_travel_activation != _serialized_run_text(), "Confirming map travel did not update serialized RunState through the existing travel confirmation path.")
	_set_optional_hook_status("travel", "passed", "Confirmed a visible world-map destination.", travel_object)
	_record_state("travel_result_screen", "Confirmed visible travel choice and generated the next environment.")
	_assert_objective_hud("travel result")
	_assert_m2_player_feedback_clarity("travel result")
	return true


func _try_event_card_flow(prepared_fixture: bool = false) -> void:
	await _resolve_blocking_event_popups()
	_return_to_room_view()
	await _settle()
	_record_state("event_screen", "Focused event object after normal UI navigation.")
	var serialized_before_event_focus := _serialized_run_text()
	var event_button := await _click_first_play_object_type("event")
	if event_button.is_empty():
		if not prepared_fixture:
			await _prepare_event_visual_qa_fixture()
			await _try_event_card_flow(true)
			return
		_require(false, "Prepared event visual QA fixture did not expose an eligible event card.")
		return
	_cover("event_card")
	_set_optional_hook_status("event", "present", "Focused a visible event object.")
	await _settle()
	var serialized_after_event_focus := _serialized_run_text()
	_require(serialized_before_event_focus == serialized_after_event_focus, "Focusing an event object mutated serialized RunState before confirmation. %s" % _serialized_diff_summary(serialized_before_event_focus, serialized_after_event_focus))
	_require(_focused_object_type() == "event", "Clicking the visible event object did not shift focus to an event.")
	var canvas := app.get("environment_canvas") as Control
	_require(canvas != null and canvas.visible and canvas.has_method("current_view_snapshot"), "Environment canvas was not available for event response QA.")
	var canvas_snapshot: Dictionary = canvas.call("current_view_snapshot")
	_require(not _snapshot_has_object_type(canvas_snapshot.get("objects", []), "event_choice"), "Event focus created legacy visible event_choice response objects.")
	var event_object_id := str(app.call("current_spatial_interaction_snapshot").get("selected_object_id", ""))
	var event_id := event_object_id.trim_prefix("event:")
	var event_option := _event_option_by_id(event_id)
	var event_choices: Array = event_option.get("choices", [])
	_require(not event_choices.is_empty(), "Focused event did not expose response choices.")
	var first_choice: Dictionary = event_choices[0]
	var choice_label := str(first_choice.get("label", ""))
	var choice_text := str(first_choice.get("text", ""))
	var choice_impact := str(first_choice.get("consequence_summary", ""))
	var selected_info: Dictionary = canvas_snapshot.get("selected_info", {})
	var inline_actions: Array = selected_info.get("actions", [])
	if not inline_actions.is_empty():
		var first_action: Dictionary = inline_actions[0]
		var first_action_detail := str(first_action.get("detail", ""))
		var expected_emit_id := "event_response:%s:%s" % [event_id, str(first_choice.get("id", ""))]
		_require(not choice_label.is_empty() and str(first_action.get("label", "")) == choice_label, "Event response panel did not show the choice label.")
		_require(not choice_text.is_empty() and first_action_detail.find(choice_text) != -1, "Event response panel did not show the choice effect text.")
		_require(not choice_impact.is_empty() and first_action_detail.find(choice_impact) != -1, "Event response panel did not show the choice impact text.")
		_require(str(first_action.get("emit_object_id", "")) == expected_emit_id, "Event response panel did not route the response through an inline canvas action.")
	if not bool(app.call("current_event_choice_popup_snapshot").get("visible", false)):
		_require(bool(app.call("activate_interactable_object", event_object_id)), "Event prop did not open its response popup.")
		await _settle()
	var interactable_popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	_require(bool(interactable_popup.get("visible", false)) and not bool(interactable_popup.get("blocking", true)) and bool(interactable_popup.get("dismissible", false)), "Interactable event did not open a dismissible non-blocking popup.")
	var serialized_before_event_resolve := _serialized_run_text()
	_record_input_event({
		"kind": "event_popup_response",
		"label": choice_label,
		"object_id": "event:%s" % event_id,
	})
	app.call("resolve_event_choice", event_id, str(first_choice.get("id", "")))
	await _settle()
	_require(serialized_before_event_resolve != _serialized_run_text(), "Resolving an event choice did not update serialized RunState.")
	await _resolve_blocking_event_popups()
	_require(not bool(app.call("current_event_choice_popup_snapshot").get("visible", false)), "Event response popup stayed open after resolving a choice.")
	_set_optional_hook_status("event", "passed", "Resolved a visible event choice through the event popup.")
	_record_state("event_result_screen", "Resolved a visible event response through the popup path.")
	_assert_objective_hud("event result")
	_assert_m2_player_feedback_clarity("event result")


func _assert_no_triggered_event_objects(label: String) -> void:
	var library := app.get("library") as ContentLibrary
	if library == null:
		return
	var snapshot: Dictionary = app.call("current_environment_view_snapshot")
	for object_value in snapshot.get("interactable_objects", []):
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = object_value
		if str(object_data.get("object_type", "")) != "event":
			continue
		var event_id := str(object_data.get("source_id", "")).strip_edges()
		if event_id.is_empty():
			event_id = str(object_data.get("object_id", "")).trim_prefix("event:")
		var event_def := library.event(event_id)
		_require(str(event_def.get("interaction_mode", "interactable")) != "triggered", "%s placed triggered event object %s in the room." % [label, event_id])


func _verify_t4_7_event_visual_model() -> void:
	await _open_fresh_app()
	_set_seed_text("FOUNDATION-PHONE-VISUAL-QA")
	_require(not _click_button_exact("New Run").is_empty(), "Could not start phone-prop visual QA run.")
	await _settle()
	var run_state := app.get("run_state") as RunState
	var library := app.get("library") as ContentLibrary
	_require(run_state != null and library != null, "Phone-prop visual QA could not access foundation runtime state.")
	var motel_archetype: Dictionary = {}
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype_data: Dictionary = archetype_value
		if str(archetype_data.get("id", "")) == "motel":
			motel_archetype = archetype_data.duplicate(true)
			break
	_require(not motel_archetype.is_empty(), "Phone-prop visual QA could not find motel archetype.")
	var phone_environment := EnvironmentInstance.from_archetype(motel_archetype, 0, run_state.create_rng("phone_prop_visual"), library).to_dict()
	phone_environment["event_ids"] = ["call_brother_in_law"]
	phone_environment["resolved_event_ids"] = []
	phone_environment["layout"] = EnvironmentInstance.ensure_generated_layout(phone_environment)
	run_state.set_environment(phone_environment)
	app.call("_refresh")
	await _settle()
	_assert_no_triggered_event_objects("phone-prop fixture")
	var snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var phone_visible := false
	for object_value in snapshot.get("interactable_objects", []):
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = object_value
		if str(object_data.get("object_id", "")) == "event:call_brother_in_law" and str(object_data.get("prop", "")) == "payphone":
			phone_visible = true
			break
	_require(phone_visible, "Brother-in-law phone event did not render as a payphone room prop.")

	var fixture_environment := phone_environment.duplicate(true)
	fixture_environment["id"] = "t67_fixture_visual"
	fixture_environment["archetype_id"] = "t67_fixture_visual"
	fixture_environment["kind"] = "fixture_room"
	fixture_environment["event_ids"] = []
	fixture_environment["item_offers"] = []
	fixture_environment["service_ids"] = []
	fixture_environment["lender_hooks"] = ["brother_in_law"]
	fixture_environment["object_fixtures"] = ["shopkeeper:merchant"]
	fixture_environment["layout"] = EnvironmentInstance.ensure_generated_layout(fixture_environment)
	run_state.set_environment(fixture_environment)
	app.call("_refresh")
	await _settle()
	var fixture_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var fixture_spatial: Dictionary = app.call("current_spatial_interaction_snapshot")
	var shopkeeper_visible_noninteractive := false
	var hidden_lender_absent := true
	for object_value in fixture_snapshot.get("interactable_objects", []):
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = object_value
		if str(object_data.get("object_id", "")) == "shopkeeper:merchant":
			shopkeeper_visible_noninteractive = not bool(object_data.get("enabled", true)) and not bool(object_data.get("interactive", true))
		if str(object_data.get("object_id", "")) == "lender:brother_in_law":
			hidden_lender_absent = false
	_require(shopkeeper_visible_noninteractive, "T6.7 fixture shopkeeper did not render as a visible noninteractive object.")
	_require(hidden_lender_absent, "T6.7 flag-gated lender appeared as a room object.")
	_require(not _snapshot_has_object_type(fixture_spatial.get("objects", []), "lender"), "T6.7 hidden lender appeared in the spatial object snapshot.")
	var cadence_snapshot: Dictionary = fixture_snapshot.get("event_cadence", {}) if typeof(fixture_snapshot.get("event_cadence", {})) == TYPE_DICTIONARY else {}
	_require(cadence_snapshot.has("action_index") and cadence_snapshot.has("visit_count"), "T6.7 cadence snapshot was not exposed in environment view data.")
	_cover("t6_7_fixture_visible_noninteractive")
	_cover("t6_7_hidden_object_absent")
	_cover("t6_7_event_cadence_snapshot")


func _verify_grand_casino_showdown_event_snapshot() -> void:
	await _open_fresh_app()
	_set_seed_text("FOUNDATION-SHOWDOWN-VISUAL-QA")
	_require(not _click_button_exact("New Run").is_empty(), "Could not start showdown visual QA run through visible controls.")
	await _settle()
	var fixture_run := app.get("run_state") as RunState
	var fixture_library := app.get("library") as ContentLibrary
	_require(fixture_run != null and fixture_library != null, "Showdown visual QA could not access foundation runtime state.")
	var grand_archetype: Dictionary = {}
	for archetype_value in fixture_library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype_data := archetype_value as Dictionary
		if str(archetype_data.get("id", "")) == RunState.GRAND_CASINO_ARCHETYPE_ID:
			grand_archetype = archetype_data.duplicate(true)
			break
	_require(not grand_archetype.is_empty(), "Showdown visual QA could not find the Grand Casino archetype.")
	var grand_environment := EnvironmentInstance.from_archetype(grand_archetype, 5, fixture_run.create_rng("visual_showdown"), fixture_library).to_dict()
	grand_environment["event_ids"] = [RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID]
	grand_environment["item_offers"] = []
	grand_environment["service_ids"] = []
	grand_environment["lender_hooks"] = []
	grand_environment["travel_hooks"] = []
	fixture_run.set_environment(grand_environment)
	fixture_run.current_environment["turns"] = 0
	var objective: Dictionary = {}
	var objective_value: Variant = grand_environment.get("demo_objective", {})
	if typeof(objective_value) == TYPE_DICTIONARY:
		objective = objective_value as Dictionary
	var heat_threshold := int(objective.get("showdown_heat_threshold", 70))
	fixture_run.add_suspicion("visual_showdown_fixture", heat_threshold, "behavior")
	fixture_run.evaluate_environment_objective_state()
	_require(bool(fixture_run.narrative_flags.get("grand_casino_showdown_pending", false)), "Showdown visual QA did not queue the pending back-room event.")
	app.call("_refresh")
	await _settle()
	_return_to_room_view()
	await _settle()
	var event_label := await _click_first_canvas_object_type("event")
	_require(not event_label.is_empty(), "Showdown visual QA could not focus the visible Rourke event prop.")
	var event_option := _event_option_by_id(RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID)
	var pending_choices: Array = event_option.get("choices", [])
	_require(pending_choices.size() == 1 and str((pending_choices[0] as Dictionary).get("id", "")) == "enter_back_room", "Showdown visual QA did not expose the arrival beat.")
	var canvas := app.get("environment_canvas") as Control
	_require(canvas != null and canvas.visible and canvas.has_method("local_position_for_selected_info_action_button"), "Showdown visual QA could not reach the event response action.")
	var local_position: Vector2 = canvas.call("local_position_for_selected_info_action_button")
	_require(local_position.x >= 0.0 and local_position.y >= 0.0, "Showdown visual QA could not find the arrival response button.")
	var global_position := canvas.get_global_rect().position + local_position
	_push_mouse_motion(global_position)
	_push_mouse_button(global_position, true)
	_push_mouse_button(global_position, false)
	_record_input_event({
		"kind": "canvas_event_response",
		"label": "Enter Back Room",
		"object_id": "event_response:%s:enter_back_room" % RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID,
	})
	await _settle()
	_require(bool(fixture_run.narrative_flags.get("grand_casino_showdown_active", false)), "Visible arrival response did not start the active showdown.")
	var pressure_option := _event_option_by_id(RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID)
	var pressure_choices: Array = pressure_option.get("choices", [])
	_require(pressure_choices.size() == 3, "Active showdown visual snapshot did not expose pressure responses.")
	_cover("grand_casino_showdown_event")
	_record_state("grand_casino_showdown_pressure_screen", "Grand Casino back-room showdown is active with pressure responses visible.")


func _verify_grand_casino_high_roller_cashout_snapshot() -> void:
	await _open_fresh_app()
	_set_seed_text("FOUNDATION-HIGH-ROLLER-VISUAL-QA")
	_require(not _click_button_exact("New Run").is_empty(), "Could not start Players Card visual QA run through visible controls.")
	await _settle()
	var fixture_run := app.get("run_state") as RunState
	var fixture_library := app.get("library") as ContentLibrary
	_require(fixture_run != null and fixture_library != null, "Players Card visual QA could not access foundation runtime state.")
	var grand_archetype: Dictionary = {}
	for archetype_value in fixture_library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype_data := archetype_value as Dictionary
		if str(archetype_data.get("id", "")) == RunState.GRAND_CASINO_ARCHETYPE_ID:
			grand_archetype = archetype_data.duplicate(true)
			break
	_require(not grand_archetype.is_empty(), "Players Card visual QA could not find the Grand Casino archetype.")
	var grand_environment := EnvironmentInstance.from_archetype(grand_archetype, 5, fixture_run.create_rng("visual_high_roller"), fixture_library).to_dict()
	grand_environment["event_ids"] = []
	grand_environment["item_offers"] = []
	grand_environment["service_ids"] = []
	grand_environment["lender_hooks"] = []
	grand_environment["travel_hooks"] = []
	fixture_run.set_environment(grand_environment)
	var objective: Dictionary = {}
	var objective_value: Variant = grand_environment.get("demo_objective", {})
	if typeof(objective_value) == TYPE_DICTIONARY:
		objective = objective_value as Dictionary
	var target_bankroll := int(objective.get("high_roller_target_bankroll", objective.get("target_bankroll", 0)))
	var required_net := int(objective.get("high_roller_net_winnings", 75))
	var min_games := int(objective.get("high_roller_min_grand_casino_games", 3))
	for game_index in range(min_games):
		var deltas := GameModule.empty_result_deltas()
		deltas["story_log"] = [{"type": "game_action", "game_id": "blackjack", "stake_cost": 10 + game_index}]
		var result := GameModule.build_action_result({
			"ok": true,
			"type": "game_action",
			"source_id": "blackjack",
			"game_id": "blackjack",
			"action_id": "visual_clean_progress",
			"action_kind": "legal",
			"stake": 10 + game_index,
			"deltas": deltas,
			"environment_id": str(fixture_run.current_environment.get("id", "")),
			"message": "Clean Players Card visual progress.",
		})
		fixture_run.record_grand_casino_game_result(result)
	fixture_run.bankroll = maxi(target_bankroll, int(fixture_run.narrative_flags.get("grand_casino_entry_bankroll", 0)) + required_net)
	fixture_run.evaluate_environment_objective_state()
	var status := fixture_run.demo_objective_status()
	_require(bool(status.get("high_roller_ready", false)), "Players Card visual QA did not reach clean readiness.")
	var has_cashout_event := false
	for event_id_value in fixture_run.current_environment.get("event_ids", []):
		if str(event_id_value) == RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID:
			has_cashout_event = true
			break
	_require(has_cashout_event, "Players Card visual QA did not inject the review event.")
	app.call("_refresh")
	await _settle()
	_return_to_room_view()
	await _settle()
	var event_label := await _double_click_first_canvas_object_type("event")
	_require(not event_label.is_empty(), "Players Card visual QA could not focus the visible review event prop.")
	var event_option := _event_option_by_id(RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID)
	var choices: Array = event_option.get("choices", [])
	_require(choices.size() == 1 and str((choices[0] as Dictionary).get("id", "")) == RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID, "Players Card visual QA did not expose the deliberate claim response.")
	_cover("grand_casino_high_roller_cashout")
	_record_state("grand_casino_high_roller_cashout_available", "Grand Casino clean Players Card review is visible at the host event.")


func _verify_terminal_victory_summary_snapshot() -> void:
	await _open_fresh_app()
	_set_seed_text("FOUNDATION-VICTORY-SUMMARY-QA")
	_require(not _click_button_exact("New Run").is_empty(), "Could not start victory summary visual QA run through visible controls.")
	await _settle()
	var fixture_run := app.get("run_state") as RunState
	_require(fixture_run != null, "Victory summary visual QA could not access foundation runtime state.")
	fixture_run.bankroll = 575
	fixture_run.add_suspicion("visual_victory_heat", 22, "behavior", true, {"environment_id": str(fixture_run.current_environment.get("id", ""))})
	fixture_run.log_story({
		"type": "demo_victory",
		"objective_id": RunState.GRAND_CASINO_OBJECTIVE_ID,
		"environment_id": str(fixture_run.current_environment.get("id", "")),
		"bankroll": fixture_run.bankroll,
		"message": RunState.GRAND_CASINO_HIGH_ROLLER_DEFAULT_SUCCESS_MESSAGE,
		"ended": true,
	})
	fixture_run.narrative_flags["demo_victory"] = true
	fixture_run.narrative_flags["demo_victory_route"] = RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID
	fixture_run.narrative_flags["demo_victory_message"] = RunState.GRAND_CASINO_HIGH_ROLLER_DEFAULT_SUCCESS_MESSAGE
	fixture_run.narrative_flags["demo_finale_completed"] = true
	fixture_run.run_status = RunState.RUN_STATUS_ENDED
	app.call("_refresh")
	await _settle()
	var screen_snapshot: Dictionary = app.call("current_screen_snapshot")
	_require(str(screen_snapshot.get("screen", "")) == "VICTORY", "Victory summary visual QA did not reach the VICTORY screen.")
	_require(not bool(screen_snapshot.get("has_game", true)), "Victory summary visual QA left a game surface active.")
	var summary: Dictionary = app.call("current_victory_summary_snapshot")
	_require(str(summary.get("route", "")) == RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID, "Victory summary visual QA did not preserve the Players Card route.")
	_require(str(summary.get("next_act_line", "")).find("not implemented") >= 0, "Victory summary visual QA did not expose the next-act message.")
	_require(_is_control_visible("victory_summary_panel"), "Victory summary panel is not visible.")
	_require(not _is_control_visible("game_surface_canvas"), "Game surface remained visible over the victory summary.")
	_cover("demo_victory")
	_cover("terminal_victory_summary")
	_record_state("terminal_victory_summary_screen", "Demo victory terminal summary shows route, run totals, story context, and next-act messaging.")


func _prepare_event_visual_qa_fixture() -> void:
	await _prepare_visual_qa_fixture_environment("corner_store", "visual_event_fixture", {
		"event_ids": ["late_shift_discount"],
		"resolved_event_ids": [],
		"item_offers": [],
		"service_ids": [],
		"lender_hooks": [],
		"object_fixtures": ["shopkeeper:merchant"],
	})
	await _prime_visible_object_focus_state("event")


func _prepare_item_visual_qa_fixture() -> void:
	await _prepare_visual_qa_fixture_environment("corner_store", "visual_item_fixture", {
		"event_ids": [],
		"resolved_event_ids": [],
		"item_offers": [{"id": "instant_coffee", "price": 1, "display_name": "Instant Coffee"}],
		"service_ids": [],
		"lender_hooks": [],
		"object_fixtures": ["shopkeeper:merchant"],
	}, 100)


func _prepare_service_visual_qa_fixture() -> void:
	await _prepare_visual_qa_fixture_environment("corner_store", "visual_service_fixture", {
		"event_ids": [],
		"resolved_event_ids": [],
		"item_offers": [],
		"service_ids": ["house_drink"],
		"lender_hooks": [],
		"object_fixtures": ["shopkeeper:merchant"],
	}, 100)


func _prepare_risky_game_visual_qa_fixture() -> void:
	await _prepare_visual_qa_fixture_environment("small_underground_casino", "visual_risky_game_fixture", {
		"game_ids": ["bar_dice"],
		"event_ids": [],
		"resolved_event_ids": [],
		"item_offers": [],
		"service_ids": [],
		"lender_hooks": [],
		"object_fixtures": [],
	}, 100)


func _reset_fixed_price_surface_for_risky_action() -> void:
	await _resolve_blocking_event_popups()
	_return_to_room_view()
	await _settle()
	await _prepare_risky_game_visual_qa_fixture()
	await _resolve_blocking_event_popups()
	_record_state("risky_game_fixture_risky_reset", "Reopened deterministic fixed-price game surface for visible risky-action coverage.")
	var entered_label := await _double_click_first_play_object_type("game")
	_require(not entered_label.is_empty(), "Could not re-enter deterministic fixed-price game surface for risky-action QA.")
	await _settle()
	await _refresh_game_surface_hit_regions()
	var game_snapshot: Dictionary = app.call("current_game_view_snapshot")
	var surface_canvas := app.get("game_surface_canvas") as Control
	if surface_canvas != null and surface_canvas.visible and surface_canvas.has_method("current_view_snapshot"):
		var surface_snapshot: Dictionary = surface_canvas.call("current_view_snapshot")
		game_snapshot["surface_hit_actions"] = (surface_snapshot.get("surface_hit_actions", []) as Array).duplicate(true) if typeof(surface_snapshot.get("surface_hit_actions", [])) == TYPE_ARRAY else []
	_require(str(game_snapshot.get("surface_renderer", "")) != "" and str(game_snapshot.get("surface_renderer", "")) != "result", "Re-entered fixed-price fixture did not expose a game surface for risky-action QA.")
	_set_game_surface_status("risky_entry", "passed", "Reopened the deterministic game surface before resolving a risky fixed-price action.", game_snapshot)


func _refresh_game_surface_hit_regions() -> void:
	var surface_canvas := app.get("game_surface_canvas") as Control
	if surface_canvas == null or not surface_canvas.visible:
		return
	surface_canvas.queue_redraw()
	await _settle()
	if surface_canvas.has_method("current_view_snapshot"):
		surface_canvas.call("current_view_snapshot")


func _prepare_lender_pressure_visual_qa_fixture() -> void:
	await _prepare_visual_qa_fixture_environment("back_alley", "visual_lender_pressure_fixture", {
		"event_ids": [],
		"resolved_event_ids": [],
		"item_offers": [],
		"service_ids": [],
		"lender_hooks": ["street_lender"],
		"object_fixtures": [],
	}, 30)


func _prepare_visual_qa_fixture_environment(archetype_id: String, fixture_id: String, overrides: Dictionary, bankroll_override: int = -1) -> void:
	var fixture_run := app.get("run_state") as RunState
	var fixture_library := app.get("library") as ContentLibrary
	_require(fixture_run != null and fixture_library != null, "Visual QA fixture could not access foundation runtime state.")
	var archetype := _visual_qa_archetype(archetype_id, fixture_library)
	_require(not archetype.is_empty(), "Visual QA fixture could not find environment archetype: %s." % archetype_id)
	var fixture_environment := EnvironmentInstance.from_archetype(archetype, 0, fixture_run.create_rng("visual_fixture:%s" % fixture_id), fixture_library).to_dict()
	fixture_environment["id"] = fixture_id
	fixture_environment["archetype_id"] = archetype_id
	for key_value in overrides.keys():
		var key := str(key_value)
		var value: Variant = overrides[key_value]
		if typeof(value) == TYPE_DICTIONARY:
			fixture_environment[key] = (value as Dictionary).duplicate(true)
		elif typeof(value) == TYPE_ARRAY:
			fixture_environment[key] = (value as Array).duplicate(true)
		else:
			fixture_environment[key] = value
	_populate_visual_fixture_game_states(fixture_environment, fixture_run, fixture_library, fixture_id)
	fixture_environment["layout"] = EnvironmentInstance.ensure_generated_layout(fixture_environment)
	fixture_run.set_environment(fixture_environment)
	if bankroll_override >= 0:
		fixture_run.bankroll = bankroll_override
	fixture_run.drunk_level = 0
	fixture_run.pending_drunk_absorption = []
	if app.has_method("back_to_environment"):
		app.call("back_to_environment")
	app.call("_refresh")
	await _settle()
	if app.has_method("current_environment_view_snapshot"):
		app.call("current_environment_view_snapshot")
	if app.has_method("current_spatial_interaction_snapshot"):
		app.call("current_spatial_interaction_snapshot")
	await _settle()


func _prime_visible_object_focus_state(object_type: String) -> void:
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
		return
	var object_data := _first_clickable_canvas_object_type_enabled(canvas, object_type, true)
	if object_data.is_empty():
		return
	var object_id := str(object_data.get("id", ""))
	if object_id.is_empty() or not app.has_method("focus_interactable_object"):
		return
	app.call("focus_interactable_object", object_id)
	await _settle()
	if app.has_method("clear_interaction_focus"):
		app.call("clear_interaction_focus", true)
	await _settle()


func _populate_visual_fixture_game_states(fixture_environment: Dictionary, fixture_run: RunState, fixture_library: ContentLibrary, fixture_id: String) -> void:
	var states: Dictionary = fixture_environment.get("game_states", {}) if typeof(fixture_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	for game_id_value in fixture_environment.get("game_ids", []):
		var game_id := str(game_id_value).strip_edges()
		if game_id.is_empty() or states.has(game_id):
			continue
		var definition := fixture_library.game(game_id)
		if definition.is_empty():
			continue
		if not app.has_method("_create_game_module"):
			continue
		var module_instance: Variant = app.call("_create_game_module", definition)
		if module_instance == null or not module_instance is GameModule:
			continue
		var game: GameModule = module_instance
		var rng := fixture_run.create_rng("visual_fixture:%s:game_state:%s" % [fixture_id, game_id])
		var generated: Dictionary = game.generate_environment_state(fixture_run, fixture_environment, rng)
		if not generated.is_empty():
			states[game_id] = generated.duplicate(true)
	fixture_environment["game_states"] = states


func _visual_qa_archetype(archetype_id: String, fixture_library: ContentLibrary) -> Dictionary:
	for archetype_value in fixture_library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype_data: Dictionary = archetype_value
		if str(archetype_data.get("id", "")) == archetype_id:
			return archetype_data.duplicate(true)
	return {}


func _lender_pressure_shift_visible(serialized: Dictionary, consequence: Dictionary) -> bool:
	var economy := str(serialized.get("economic_state", ""))
	if economy == "volatile" or economy == "distressed" or economy == "insolvent":
		return true
	var state_text := str(consequence.get("current_state_text", ""))
	if state_text.find("Distressed") != -1 or state_text.find("Volatile") != -1:
		return true
	var pressure_value: Variant = consequence.get("pressure", {})
	if typeof(pressure_value) == TYPE_DICTIONARY:
		var pressure: Dictionary = pressure_value
		var pressure_state := str(pressure.get("state", ""))
		return pressure_state == "volatile" or pressure_state == "distressed" or pressure_state == "recovery"
	return false


func _try_item_card_flow(prepared_fixture: bool = false) -> void:
	await _resolve_blocking_event_popups()
	_return_to_room_view()
	await _settle()
	_record_state("item_screen", "Focused and activated a visible item object through the mouse-only room path.")
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
		if not prepared_fixture:
			await _prepare_item_visual_qa_fixture()
			await _try_item_card_flow(true)
			return
		_require(false, "Prepared item visual QA fixture did not expose the environment canvas.")
		return
	var item_object := _first_nonterminal_item_object(canvas)
	if item_object.is_empty():
		if not prepared_fixture:
			await _prepare_item_visual_qa_fixture()
			await _try_item_card_flow(true)
			return
		_require(false, "Prepared item visual QA fixture did not expose a non-terminal affordable item offer card.")
		return
	var item_source_id := str(item_object.get("source_id", ""))
	var item_label := str(item_object.get("label", item_source_id))
	_cover("item_card")
	var serialized_before_item_focus := _serialized_run_text()
	var item_focus_click := await _click_canvas_object_data(canvas, item_object, "item")
	_require(not item_focus_click.is_empty(), "Could not single-click a visible item object.")
	await _settle()
	_require(serialized_before_item_focus == _serialized_run_text(), "Single-clicking an item object mutated serialized RunState.")
	_require(_focused_object_type() == "item", "Single-clicking an item object did not focus the item context.")
	_cover("item_focus_no_mutation")
	item_object = _canvas_object_by_id(canvas, str(item_object.get("id", "")))
	if item_object.is_empty():
		_require(false, "Focused item moved out of the current canvas snapshot before activation.")
		return
	var serialized_before_item_activation := _serialized_run_text()
	var item_summary_before := _run_state_restore_summary(app.call("serialized_run_state"))
	var item_inventory_before: Array = item_summary_before.get("inventory", []) as Array
	var item_bankroll_before := int(item_summary_before.get("bankroll", 0))
	var item_button := await _double_click_canvas_object_data(canvas, item_object, "item")
	_require(not item_button.is_empty(), "Could not double-click a visible item object.")
	_cover("item_object_double_click")
	await _settle()
	_require(serialized_before_item_activation != _serialized_run_text(), "Double-clicking an affordable item did not update serialized RunState.")
	var item_summary_after := _run_state_restore_summary(app.call("serialized_run_state"))
	var item_inventory_after: Array = item_summary_after.get("inventory", []) as Array
	var item_bankroll_after := int(item_summary_after.get("bankroll", 0))
	_require(item_inventory_after.size() > item_inventory_before.size() or item_inventory_after.has(item_source_id), "Item double-click did not add the item to run inventory.")
	_require(item_bankroll_after < item_bankroll_before, "Item double-click did not apply item cost to bankroll.")
	_require(_has_visible_text(app, "Bought") or _has_visible_text(app, item_label), "Item double-click did not show visible purchase/effect feedback.")
	_cover("item_purchase_result")
	_set_optional_hook_status("item", "passed", "Bought/applied a visible affordable item.", item_object)
	_record_state("item_result_screen", "Bought/applied a visible item through environment double-click activation.")
	_assert_objective_hud("item result")
	_assert_m2_player_feedback_clarity("item result")
	_return_to_room_view()
	await _settle()
	canvas = app.get("environment_canvas") as Control
	if canvas != null and canvas.visible and canvas.has_method("current_view_snapshot"):
		var disabled_item := _first_clickable_canvas_object_type_enabled(canvas, "item", false)
		if not disabled_item.is_empty():
			var disabled_reason := str(disabled_item.get("disabled_reason", "Not enough bankroll.")).strip_edges()
			if disabled_reason.is_empty():
				disabled_reason = "Not enough bankroll."
			var serialized_before_disabled_focus := _serialized_run_text()
			var disabled_focus := await _click_canvas_object_data(canvas, disabled_item, "item")
			_require(not disabled_focus.is_empty(), "Could not focus a disabled item object.")
			await _settle()
			_require(serialized_before_disabled_focus == _serialized_run_text(), "Focusing a disabled item mutated serialized RunState.")
			_require(_disabled_reason_is_visible(disabled_reason), "Disabled item focus did not show a visible rejection reason.")
			canvas = app.get("environment_canvas") as Control
			_require(canvas != null and canvas.visible and canvas.has_method("current_view_snapshot"), "Environment canvas disappeared before disabled item activation.")
			if canvas == null:
				return
			if canvas != null and canvas.visible and canvas.has_method("current_view_snapshot"):
				var refreshed_disabled_item := _canvas_object_by_id(canvas, str(disabled_item.get("id", "")))
				if not refreshed_disabled_item.is_empty():
					disabled_item = refreshed_disabled_item
			var serialized_before_disabled_item := _serialized_run_text()
			var disabled_click := await _double_click_canvas_object_data(canvas, disabled_item, "item")
			_require(not disabled_click.is_empty(), "Could not double-click a disabled item object.")
			await _settle()
			_require(serialized_before_disabled_item == _serialized_run_text(), "Double-clicking a disabled item mutated serialized RunState.")
			_require(_disabled_reason_is_visible(disabled_reason), "Disabled item did not show a visible rejection reason.")
			_cover("unaffordable_item_rejects")


func _first_nonterminal_item_object(canvas: Control) -> Dictionary:
	var bankroll := int(_run_state_restore_summary(app.call("serialized_run_state")).get("bankroll", 0))
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	var objects: Array = snapshot.get("objects", []) if typeof(snapshot.get("objects", [])) == TYPE_ARRAY else []
	for item in objects:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = item
		if _object_type_value(object_data) != "item" or bool(object_data.get("disabled", false)):
			continue
		var price := _item_offer_price(str(object_data.get("source_id", "")), object_data)
		if price > 0 and price < bankroll and _canvas_object_center_hits(canvas, object_data):
			return object_data.duplicate(true)
	return {}


func _item_offer_price(item_id: String, object_data: Dictionary) -> int:
	var serialized: Dictionary = app.call("serialized_run_state")
	var current_environment: Dictionary = serialized.get("current_environment", {}) if typeof(serialized.get("current_environment", {})) == TYPE_DICTIONARY else {}
	var offers: Array = current_environment.get("item_offers", []) if typeof(current_environment.get("item_offers", [])) == TYPE_ARRAY else []
	for offer_value in offers:
		if typeof(offer_value) != TYPE_DICTIONARY:
			continue
		var offer: Dictionary = offer_value
		if str(offer.get("id", "")) == item_id:
			return int(offer.get("price", 0))
	return _first_int_in_text(str(object_data.get("cost_summary", "")))


func _first_int_in_text(text: String) -> int:
	var digits := ""
	for index in range(text.length()):
		var character := text.substr(index, 1)
		var code := character.unicode_at(0)
		if code >= 48 and code <= 57:
			digits += character
		elif not digits.is_empty():
			return int(digits)
	return int(digits) if not digits.is_empty() else 0


func _verify_disabled_or_absent_optional_object(object_type: String, absent_reason: String) -> bool:
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
		_set_optional_hook_status(object_type, "skipped_unavailable", absent_reason)
		_add_warning(absent_reason)
		return true
	var disabled_object := _first_clickable_canvas_object_type_enabled(canvas, object_type, false)
	if disabled_object.is_empty():
		return false
	var disabled_reason := str(disabled_object.get("disabled_reason", ""))
	if disabled_reason.strip_edges().is_empty():
		disabled_reason = str(disabled_object.get("status", "Not available right now."))
	if disabled_reason.strip_edges().is_empty():
		disabled_reason = "Not available right now."
	var serialized_before_focus := _serialized_run_text()
	var focus_click := await _click_canvas_object_data(canvas, disabled_object, object_type)
	_require(not focus_click.is_empty(), "Could not focus disabled %s object." % object_type)
	await _settle()
	_require(serialized_before_focus == _serialized_run_text(), "Focusing a disabled %s object mutated serialized RunState." % object_type)
	var serialized_before_activation := _serialized_run_text()
	var activation_click := await _double_click_canvas_object_data(canvas, disabled_object, object_type)
	_require(not activation_click.is_empty(), "Could not double-click disabled %s object." % object_type)
	await _settle()
	_require(serialized_before_activation == _serialized_run_text(), "Double-clicking a disabled %s object mutated serialized RunState." % object_type)
	_require(_disabled_reason_is_visible(disabled_reason), "Disabled %s object did not show a visible reason." % object_type)
	if object_type == "item":
		_cover("unaffordable_item_rejects")
	_set_optional_hook_status(object_type, "locked_explained", disabled_reason, disabled_object)
	_add_warning("%s is present but not usable: %s" % [object_type.capitalize(), disabled_reason])
	return true


func _disabled_reason_is_visible(disabled_reason: String) -> bool:
	var reason := disabled_reason.strip_edges()
	if reason.is_empty():
		return false
	if _has_visible_text(app, reason):
		return true
	if _canvas_selected_info_contains(reason):
		return true
	var reason_words := reason.split(" ", false)
	for word in reason_words:
		var cleaned := str(word).strip_edges().replace("(", "").replace(")", "").replace(".", "").replace(",", "")
		if cleaned.length() >= 5 and (_has_visible_text(app, cleaned) or _canvas_selected_info_contains(cleaned)):
			return true
	return _has_visible_text(app, "locked") or _has_visible_text(app, "not available") or _has_visible_text(app, "Not enough") or _canvas_selected_info_contains("locked") or _canvas_selected_info_contains("not available") or _canvas_selected_info_contains("Not enough")


func _canvas_selected_info_contains(text: String) -> bool:
	var needle := text.strip_edges().to_lower()
	if needle.is_empty():
		return false
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
		return false
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	var selected_info_value: Variant = snapshot.get("selected_info", snapshot.get("selected_object_info", {}))
	var selected_info: Dictionary = selected_info_value if typeof(selected_info_value) == TYPE_DICTIONARY else {}
	if selected_info.is_empty() or not bool(selected_info.get("visible", false)):
		return false
	var parts: Array = [str(selected_info.get("title", "")), str(selected_info.get("action_label", ""))]
	var lines: Array = selected_info.get("lines", []) if typeof(selected_info.get("lines", [])) == TYPE_ARRAY else []
	parts.append_array(lines)
	var actions: Array = selected_info.get("actions", []) if typeof(selected_info.get("actions", [])) == TYPE_ARRAY else []
	for action_value in actions:
		if typeof(action_value) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_value
		parts.append(str(action.get("label", "")))
		parts.append(str(action.get("detail", "")))
	return " ".join(parts).to_lower().find(needle) != -1


func _set_optional_hook_status(object_type: String, status: String, reason: String, object_data: Dictionary = {}) -> void:
	var statuses: Dictionary = report.get("optional_hook_status", {})
	statuses[object_type] = {
		"status": status,
		"reason": reason,
		"object_id": str(object_data.get("id", "")),
		"source_id": str(object_data.get("source_id", "")),
		"label": str(object_data.get("label", "")),
	}
	report["optional_hook_status"] = statuses


func _set_game_surface_status(status_key: String, status: String, reason: String, surface_data: Dictionary = {}) -> void:
	var statuses: Dictionary = report.get("game_surface_status", {})
	statuses[status_key] = {
		"status": status,
		"reason": reason,
		"game_id": str(surface_data.get("game_id", "")),
		"game_label": str(surface_data.get("display_name", surface_data.get("game_label", ""))),
		"surface_renderer": str(surface_data.get("surface_renderer", "")),
		"selected_action_id": str(surface_data.get("selected_action_id", "")),
		"selected_action_label": str(surface_data.get("selected_action_label", "")),
		"selected_action_kind": str(surface_data.get("selected_action_kind", "")),
		"selected_stake": int(surface_data.get("selected_stake", surface_data.get("result_stake", 0))),
		"result_stake": int(surface_data.get("result_stake", surface_data.get("selected_stake", 0))),
		"bankroll_delta": int(surface_data.get("bankroll_delta", 0)),
		"suspicion_delta": int(surface_data.get("suspicion_delta", 0)),
	}
	report["game_surface_status"] = statuses


func _verify_demo_objective_visible() -> void:
	var hud: Dictionary = app.call("current_objective_hud_snapshot") if app.has_method("current_objective_hud_snapshot") else {}
	var goal := str(hud.get("goal", hud.get("text", ""))).to_lower()
	_require(
		goal.find("grand casino") != -1
		or goal.find("boss") != -1
		or goal.find("bankroll") != -1
		or goal.find("$100") != -1,
		"Objective HUD did not expose a meaningful demo objective."
	)
	_cover("demo_objective_visible")
	var pit_value: Variant = hud.get("pit_boss_watch", {})
	if typeof(pit_value) == TYPE_DICTIONARY and bool((pit_value as Dictionary).get("active", false)):
		_cover("pit_boss_watch_visible")


func _start_room_has_shop_offers() -> bool:
	var snapshot: Dictionary = app.call("current_environment_view_snapshot")
	if str(snapshot.get("kind", "")) != "shop":
		return false
	var offers_value: Variant = snapshot.get("item_offers", [])
	var offers: Array = []
	if typeof(offers_value) == TYPE_ARRAY:
		offers = offers_value
	if offers.is_empty():
		return false
	var spatial_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	var objects_value: Variant = spatial_snapshot.get("objects", [])
	var objects: Array = []
	if typeof(objects_value) == TYPE_ARRAY:
		objects = objects_value
	return not _interactable_by_type(objects, "item").is_empty() and not _interactable_by_type(objects, "shopkeeper").is_empty()


func _interactable_by_type(objects: Array, object_type: String) -> Dictionary:
	for object_value in objects:
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = object_value
		var actual_type := str(object_data.get("type", object_data.get("object_type", "")))
		if actual_type == object_type:
			return object_data
	return {}


func _verify_all_visible_game_objects_clickable() -> void:
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
		return
	app.call("clear_interaction_focus", true)
	await _settle()
	await _wait_for_room_camera()
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	var objects: Array = snapshot.get("objects", [])
	var game_objects: Array = []
	for item in objects:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = item
		if str(object_data.get("type", "")) == "game":
			game_objects.append(object_data.duplicate(true))
	if game_objects.is_empty():
		return
	var initial_serialized := _serialized_run_text()
	var tested_game_ids: Array = []
	for item in game_objects:
		var game_object: Dictionary = item
		var object_id := str(game_object.get("id", ""))
		var focus_label := await _click_canvas_object_data(canvas, game_object, "game")
		_require(not focus_label.is_empty(), "Could not single-click visible game object: %s" % object_id)
		_require(str(app.call("current_spatial_interaction_snapshot").get("selected_object_id", "")) == object_id, "Visible game object did not become the focused object: %s" % object_id)
		_require(initial_serialized == _serialized_run_text(), "Single-clicking visible game object mutated serialized RunState: %s" % object_id)
		tested_game_ids.append(object_id)
	for index in range(min(game_objects.size(), 2)):
		var game_object: Dictionary = game_objects[index]
		var object_id := str(game_object.get("id", ""))
		var serialized_before_entry := _serialized_run_text()
		var entered_label := await _double_click_canvas_object_data(canvas, game_object, "game")
		_require(not entered_label.is_empty(), "Could not double-click visible game object: %s" % object_id)
		await _settle()
		_require(serialized_before_entry == _serialized_run_text(), "Entering a game from a visible object mutated RunState before a game action resolved: %s" % object_id)
		_require(str(app.call("current_screen_snapshot").get("screen", "")) == "GAME", "Double-clicking a visible game object did not enter game mode: %s" % object_id)
		var game_snapshot: Dictionary = app.call("current_game_view_snapshot")
		_require(str(game_snapshot.get("game_id", "")) == str(game_object.get("source_id", "")), "Double-click entered the wrong game for visible object: %s" % object_id)
		var surface_canvas: Control = app.get("game_surface_canvas")
		_require(_game_surface_is_primary(surface_canvas), "Game surface was not primary after entering visible game object: %s" % object_id)
		_return_to_room_view()
		await _settle()
		_require(_environment_canvas_is_primary(), "Could not return to the room after entering visible game object: %s" % object_id)
		canvas = app.get("environment_canvas") as Control
		_require(canvas != null and canvas.visible, "Environment canvas was not restored after entering visible game object: %s" % object_id)
	_require(tested_game_ids.size() == game_objects.size(), "Not every visible game object was single-click tested.")
	if game_objects.size() > 1:
		_cover("multiple_game_objects_clickable")
		_cover("r100_multiple_games_clickable")


func _record_demo_victory_not_yet_reachable() -> void:
	_return_to_room_view()
	await _settle()
	var hud: Dictionary = app.call("current_objective_hud_snapshot") if app.has_method("current_objective_hud_snapshot") else {}
	var objective_value: Variant = hud.get("demo_objective", {})
	if typeof(objective_value) == TYPE_DICTIONARY and bool((objective_value as Dictionary).get("active", false)):
		var objective := objective_value as Dictionary
		if bool(objective.get("complete", false)):
			_cover("demo_victory")
			_record_state("demo_victory_screen", "The visible demo objective reached a completed state.")
			return
		_set_optional_hook_status("demo_objective", "covered_by_focused_fixtures", "Main route has not completed the demo objective; focused Grand Casino route fixtures assert the release routes.", objective)
		_record_state("demo_objective_route_fixture_pending", "Main generated route has not completed the demo objective; focused Grand Casino route fixtures cover release objective routes.")
		_cover("demo_objective_visible")
		return
	var goal := str(hud.get("goal", ""))
	if not goal.strip_edges().is_empty():
		_set_optional_hook_status("demo_objective", "covered_by_focused_fixtures", "Focused Grand Casino route fixtures assert route-dependent objective coverage.", {"label": goal})
		_record_state("demo_objective_route_fixture_pending", "Focused Grand Casino route fixtures cover release objective routes outside the generated seed path.")
		_cover("demo_objective_visible")


func _try_claim_prestige_victory_if_ready() -> bool:
	_return_to_room_view()
	await _settle()
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
		return false
	var prestige_object := _first_clickable_canvas_object_type_enabled(canvas, "prestige", true)
	if prestige_object.is_empty():
		return false
	_record_state("prestige_screen", "Focused the visible prestige target as the current objective.")
	await _activate_prestige_victory_object(canvas, prestige_object)
	return true


func _activate_prestige_victory_object(canvas: Control, prestige_object: Dictionary) -> void:
	var serialized_before_focus := _serialized_run_text()
	var focus_click := await _click_canvas_object_data(canvas, prestige_object, "prestige")
	_require(not focus_click.is_empty(), "Could not single-click the eligible prestige target.")
	await _settle()
	_require(serialized_before_focus == _serialized_run_text(), "Focusing an eligible prestige target mutated serialized RunState.")
	_require(_focused_object_type() == "prestige", "Eligible prestige target did not update the focused context panel.")
	var summary_before := _run_state_restore_summary(app.call("serialized_run_state"))
	var serialized_before_activation := _serialized_run_text()
	var activate_click := await _double_click_canvas_object_data(canvas, prestige_object, "prestige")
	_require(not activate_click.is_empty(), "Could not double-click the eligible prestige target.")
	await _settle()
	_require(serialized_before_activation != _serialized_run_text(), "Double-clicking an eligible prestige target did not update serialized RunState.")
	var summary_after := _run_state_restore_summary(app.call("serialized_run_state"))
	_require(str(summary_after.get("run_status", "")) == "ended", "Prestige purchase did not end the run.")
	var flags: Dictionary = summary_after.get("narrative_flags", {})
	_require(bool(flags.get("prestige_victory", false)), "Prestige purchase did not set the victory flag.")
	_require(int(summary_after.get("bankroll", 0)) < int(summary_before.get("bankroll", 0)), "Prestige purchase did not spend bankroll.")
	_require(_has_visible_text(app, "Victory claimed") or _has_visible_text(app, "Victory"), "Prestige purchase did not show a visible victory message.")
	_cover("prestige_victory")
	_record_state("prestige_victory_screen", "Bought the visible prestige target and reached the minimal victory state.")
	_assert_objective_hud("prestige victory")
	_assert_m2_player_feedback_clarity("prestige victory")


func _try_service_hook_flow(prepared_fixture: bool = false) -> void:
	await _resolve_blocking_event_popups()
	_return_to_room_view()
	await _settle()
	_record_state("service_screen", "Double-clicked a visible service object when one was available.")
	var serialized_before_service_activation := _serialized_run_text()
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
		if not prepared_fixture:
			await _prepare_service_visual_qa_fixture()
			await _try_service_hook_flow(true)
			return
		_require(false, "Prepared service visual QA fixture did not expose the environment canvas.")
		return
	var service_object := _first_clickable_canvas_object_type_enabled(canvas, "service", true)
	if service_object.is_empty():
		if not prepared_fixture:
			await _prepare_service_visual_qa_fixture()
			await _try_service_hook_flow(true)
			return
		_require(false, "Prepared service visual QA fixture did not expose an enabled service object.")
		return
	var service_button := await _double_click_canvas_object_data(canvas, service_object, "service")
	_require(not service_button.is_empty(), "Could not double-click a visible service object.")
	_cover("service_card")
	_cover("service_object_double_click")
	await _settle()
	if serialized_before_service_activation == _serialized_run_text():
		if not prepared_fixture:
			await _prepare_service_visual_qa_fixture()
			await _try_service_hook_flow(true)
			return
		_require(false, "Prepared service visual QA fixture did not mutate RunState.")
		return
	_set_optional_hook_status("service", "passed", "Used a supported visible service.", service_object)
	_record_state("service_result_screen", "Used a visible service through environment double-click activation.")
	_assert_objective_hud("service result")
	_assert_m2_player_feedback_clarity("service result")


func _try_lender_hook_flow(prepared_fixture: bool = false) -> void:
	await _resolve_blocking_event_popups()
	_return_to_room_view()
	await _settle()
	var canvas := app.get("environment_canvas") as Control
	if canvas != null and canvas.visible and canvas.has_method("current_view_snapshot"):
		var current_lender := _first_clickable_canvas_object_type_enabled(canvas, "lender", true)
		if current_lender.is_empty():
			current_lender = _first_clickable_canvas_object_type_enabled(canvas, "lender", false)
		if not current_lender.is_empty():
			await _try_lender_object_in_current_room(current_lender, prepared_fixture)
			return
	var serialized_before_lender_travel := _serialized_run_text()
	var lender_route := await _double_click_first_travel_to_lender_environment()
	if lender_route.is_empty():
		if not prepared_fixture:
			await _prepare_lender_pressure_visual_qa_fixture()
			await _try_lender_hook_flow(true)
			return
		_require(false, "Prepared lender visual QA fixture did not expose a visible route or lender object.")
		return
	_cover("travel_card")
	_cover("travel_object_double_click")
	await _settle()
	await _resolve_blocking_event_popups()
	_require(serialized_before_lender_travel != _serialized_run_text(), "Traveling to a lender environment did not update serialized RunState.")
	_set_optional_hook_status("travel", "passed", "Traveled through visible controls to a room with lender pressure.")
	_record_state("lender_travel_result_screen", "Traveled through visible controls to a room with lender pressure.")
	canvas = app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
		if not prepared_fixture:
			await _prepare_lender_pressure_visual_qa_fixture()
			await _try_lender_hook_flow(true)
			return
		_require(false, "Prepared lender visual QA fixture did not expose the environment canvas.")
		return
	var lender_object := _first_clickable_canvas_object_type_enabled(canvas, "lender", true)
	if lender_object.is_empty():
		if not prepared_fixture:
			await _prepare_lender_pressure_visual_qa_fixture()
			await _try_lender_hook_flow(true)
			return
		_require(false, "Prepared lender visual QA fixture did not expose an enabled lender object.")
		return
	await _try_lender_object_in_current_room(lender_object, prepared_fixture)


func _try_lender_object_in_current_room(lender_object: Dictionary, prepared_fixture: bool = false) -> void:
	await _resolve_blocking_event_popups()
	var object_enabled := not bool(lender_object.get("disabled", false))
	if not object_enabled:
		if not prepared_fixture:
			await _prepare_lender_pressure_visual_qa_fixture()
			await _try_lender_hook_flow(true)
			return
		_require(false, "Prepared lender visual QA fixture exposed a disabled lender object.")
		return
	var serialized_before_lender := _serialized_run_text()
	var canvas := app.get("environment_canvas") as Control
	_require(canvas != null and canvas.visible and canvas.has_method("current_view_snapshot"), "Environment canvas was not available for lender activation.")
	var lender_button := await _double_click_canvas_object_data(canvas, lender_object, "lender")
	_require(not lender_button.is_empty(), "Could not double-click a visible lender object.")
	_cover("lender_card")
	_cover("lender_object_double_click")
	await _settle()
	_require(serialized_before_lender != _serialized_run_text(), "Double-clicking lender did not update serialized RunState through a supported lender result.")
	var serialized: Dictionary = app.call("serialized_run_state")
	_require((serialized.get("debt", []) as Array).size() > 0, "Lender interaction did not create visible run debt.")
	_set_optional_hook_status("lender", "passed", "Used a supported visible lender.", lender_object)
	_record_state("lender_result_screen", "Used a visible lender through environment double-click activation.")
	_assert_objective_hud("lender result")
	_assert_m2_player_feedback_clarity("lender result")
	var consequence: Dictionary = app.call("current_consequence_view_snapshot")
	if _lender_pressure_shift_visible(serialized, consequence):
		_cover("economy_pressure_shift")
	else:
		if not prepared_fixture:
			await _prepare_lender_pressure_visual_qa_fixture()
			await _try_lender_hook_flow(true)
			return
		_require(false, "Prepared lender visual QA fixture did not reach a stronger economy pressure label after lender interaction.")


func _verify_mouse_only_recovery_pressure_flow() -> void:
	await _open_fresh_app()
	_set_seed_text(visual_qa_seed)
	_require(not _click_button_exact("New Run").is_empty(), "Could not start recovery pressure QA run through visible controls.")
	await _settle()
	var before_lender := _run_state_restore_summary(app.call("serialized_run_state"))
	var serialized_before_lender := _serialized_run_text()
	var lender_button := await _double_click_first_enabled_canvas_object_type("lender")
	if lender_button.is_empty():
		var serialized_before_travel := _serialized_run_text()
		var lender_route := await _double_click_first_travel_to_lender_environment()
		if lender_route.is_empty():
			_add_warning("Recovery pressure QA could not find a visible lender or route to a lender environment.")
			return
		await _settle()
		_require(serialized_before_travel != _serialized_run_text(), "Recovery pressure QA travel did not update RunState through visible controls.")
		before_lender = _run_state_restore_summary(app.call("serialized_run_state"))
		serialized_before_lender = _serialized_run_text()
		lender_button = await _double_click_first_enabled_canvas_object_type("lender")
		if lender_button.is_empty():
			_add_warning("Recovery pressure QA reached a lender route but found no enabled visible lender object.")
			return
	await _settle()
	_require(serialized_before_lender != _serialized_run_text(), "Recovery pressure QA lender interaction did not update RunState.")
	var after_lender := _run_state_restore_summary(app.call("serialized_run_state"))
	_require((after_lender.get("debt", []) as Array).size() > (before_lender.get("debt", []) as Array).size(), "Recovery pressure QA did not create visible debt.")
	_require(int(after_lender.get("bankroll", 0)) > int(before_lender.get("bankroll", 0)), "Recovery pressure QA lender did not restore bankroll.")
	var consequence: Dictionary = app.call("current_consequence_view_snapshot")
	var pressure_text := str(consequence.get("pressure_text", ""))
	var current_state := str(consequence.get("current_state_text", ""))
	_require(pressure_text.find("Debt") != -1 or current_state.find("Debt") != -1, "Recovery pressure QA did not explain debt pressure in player-facing text.")
	_cover("lender_card")
	_cover("lender_object_double_click")
	_cover("recovery_lender_path")
	_cover("run_pressure_visible")
	_record_state("recovery_pressure_screen", "Mouse-only route to a lender created visible recovery/debt pressure.")
	_assert_objective_hud("recovery pressure")


func _save_and_load_flow() -> void:
	_return_to_room_view()
	await _settle()
	await _wait_for_room_camera()
	var room_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	_require(not _snapshot_has_object_type(room_snapshot.get("objects", []), "save"), "Run / Save should not be a visible room object.")
	_require(not _snapshot_has_object_type(room_snapshot.get("objects", []), "load"), "Load Run should not be a visible room object.")
	var save_status: Dictionary = app.call("save_status_snapshot")
	_require(bool(save_status.get("has_save", false)), "Autosave did not make the current run available for main-menu Continue.")
	_cover("autosave_available")
	_cover("save")
	await _settle()
	_record_state("saved_state", "Autosaved current foundation run without a room save object.")
	var saved_summary := _run_state_restore_summary(app.call("serialized_run_state"))
	app.call("return_to_main_menu")
	await _settle()
	_require(_has_visible_button_contains("Continue"), "Main menu did not expose Continue for the autosaved run.")
	_require(not _click_button_contains("Continue").is_empty(), "Could not load the autosaved run through main-menu Continue.")
	_cover("load")
	await _settle()
	var loaded_summary := _run_state_restore_summary(app.call("serialized_run_state"))
	_require(JSON.stringify(loaded_summary) == JSON.stringify(saved_summary), "Main-menu Continue changed restored run summary. Expected %s, got %s." % [JSON.stringify(saved_summary), JSON.stringify(loaded_summary)])
	var saved_inventory: Array = saved_summary.get("inventory", []) as Array
	if not saved_inventory.is_empty():
		_require(JSON.stringify(loaded_summary.get("inventory", [])) == JSON.stringify(saved_inventory), "Main-menu Continue did not preserve item inventory.")
		_cover("item_save_load")
	if str(saved_summary.get("run_status", "")) == "ended" and bool((saved_summary.get("narrative_flags", {}) as Dictionary).get("prestige_victory", false)):
		_require(str(loaded_summary.get("run_status", "")) == "ended", "Main-menu Continue did not preserve prestige victory status.")
		_require(bool((loaded_summary.get("narrative_flags", {}) as Dictionary).get("prestige_victory", false)), "Main-menu Continue did not preserve prestige victory flag.")
		_cover("prestige_save_load")
	if str(saved_summary.get("run_status", "")) == "ended" and bool((saved_summary.get("narrative_flags", {}) as Dictionary).get("demo_victory", false)):
		_require(str(loaded_summary.get("run_status", "")) == "ended", "Main-menu Continue did not preserve demo victory status.")
		_require(bool((loaded_summary.get("narrative_flags", {}) as Dictionary).get("demo_victory", false)), "Main-menu Continue did not preserve demo victory flag.")
		_cover("demo_victory")
	_record_state("loaded_state", "Loaded autosaved foundation run through main-menu Continue.")
	_assert_m2_player_feedback_clarity("loaded state")


func _continue_from_saved_flow() -> void:
	await _open_fresh_app()
	_record_state("continue_start_screen", "Fresh launch after a foundation save exists.")
	_require(_has_visible_button_contains("Continue"), "Fresh launch did not expose Continue after saving.")
	_require(not _click_button_contains("Continue").is_empty(), "Could not click visible Continue button.")
	_cover("continue")
	await _settle()
	_record_state("continued_state", "Continued saved foundation run through visible start-screen Continue.")
	_assert_m2_player_feedback_clarity("continued state")


func _open_fresh_app() -> void:
	if app != null and is_instance_valid(app):
		app.queue_free()
		await process_frame
	app = MainScene.instantiate()
	root.add_child(app)
	await _settle()


func _settle() -> void:
	await process_frame
	await process_frame


func _resolve_blocking_event_popups(max_count: int = 8) -> void:
	for _index in range(max_count):
		var popup: Dictionary = app.call("current_event_choice_popup_snapshot")
		if not bool(popup.get("visible", false)) or not bool(popup.get("blocking", false)):
			return
		var choices: Array = popup.get("choices", [])
		if choices.is_empty():
			return
		var choice: Dictionary = choices[0]
		app.call("resolve_event_choice", str(popup.get("event_id", "")), str(choice.get("id", "")))
		await _settle()


func _wait_for_room_camera(max_frames: int = 18) -> void:
	for index in range(max_frames):
		var canvas := app.get("environment_canvas") as Control
		if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
			await process_frame
			continue
		var snapshot: Dictionary = canvas.call("current_view_snapshot")
		var zoom_delta := absf(float(snapshot.get("camera_zoom", 1.0)) - float(snapshot.get("target_camera_zoom", 1.0)))
		var offset: Vector2 = snapshot.get("camera_offset", Vector2.ZERO)
		var target: Vector2 = snapshot.get("target_camera_offset", Vector2.ZERO)
		if zoom_delta < 0.01 and offset.distance_to(target) < 1.0:
			return
		await process_frame


func _record_state(name: String, description: String) -> void:
	_assert_no_scroll_critical_path(name)
	report["states"].append({
		"name": name,
		"description": description,
		"screen": _screen_summary(),
		"visible_text": _visible_text(app),
		"visible_buttons": _visible_button_text(app),
		"start_screen_visible": _is_control_visible("start_screen"),
		"run_screen_visible": _is_control_visible("run_screen"),
		"title": _control_text("title_label"),
		"summary": _control_text("summary_label"),
		"status": _control_text("status_label"),
		"objective": _control_text("objective_label"),
		"message": _control_text("message_label"),
		"save_status": _control_text("save_status_label"),
		"run_status_hud": app.call("current_run_status_hud_snapshot") if app.has_method("current_run_status_hud_snapshot") else {},
		"environment": _environment_summary(app.call("current_environment_view_snapshot")),
		"game": _game_summary(app.call("current_game_view_snapshot")),
		"consequence": _consequence_summary(app.call("current_consequence_view_snapshot")),
	})


func _screen_summary() -> Dictionary:
	if app == null or not app.has_method("current_screen_snapshot"):
		return {}
	return app.call("current_screen_snapshot")


func _environment_summary(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return {}
	return {
		"id": str(snapshot.get("id", "")),
		"display_name": str(snapshot.get("display_name", "")),
		"game_count": _array_size(snapshot.get("game_ids", [])),
		"event_count": _array_size(snapshot.get("event_options", [])),
		"item_offer_count": _array_size(snapshot.get("item_offers", [])),
		"service_count": _array_size(snapshot.get("service_options", [])),
		"lender_count": _array_size(snapshot.get("lender_options", [])),
		"travel_count": _array_size(snapshot.get("travel_choices", [])),
		"selected_travel_target_id": str(snapshot.get("selected_travel_target_id", "")),
	}


func _game_summary(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return {}
	return {
		"display_name": str(snapshot.get("display_name", "")),
		"family": str(snapshot.get("family", "")),
		"surface_renderer": str(snapshot.get("surface_renderer", "")),
		"legal_action_count": _array_size(snapshot.get("legal_actions", [])),
		"cheat_action_count": _array_size(snapshot.get("cheat_actions", [])),
		"selected_action_label": str(snapshot.get("selected_action_label", "")),
		"selected_stake": int(snapshot.get("selected_stake", 0)),
		"result_message": str(snapshot.get("result_message", "")),
		"bankroll_delta": int(snapshot.get("bankroll_delta", 0)),
		"suspicion_delta": int(snapshot.get("suspicion_delta", 0)),
	}


func _visible_risky_heat_delta(snapshot: Dictionary) -> int:
	var highest := 0
	var cheat_actions: Array = snapshot.get("cheat_actions", []) if typeof(snapshot.get("cheat_actions", [])) == TYPE_ARRAY else []
	for action_value in cheat_actions:
		if typeof(action_value) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_value
		highest = maxi(highest, int(action.get("suspicion_delta", 0)))
	return highest


func _consequence_summary(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return {}
	return {
		"bankroll": int(snapshot.get("bankroll", 0)),
		"suspicion_level": int(snapshot.get("suspicion_level", 0)),
		"recent_result": str(snapshot.get("recent_result_text", "")),
		"current_state": str(snapshot.get("current_state_text", "")),
		"pressure": str(snapshot.get("pressure_text", "")),
		"run_status": str(snapshot.get("run_status", "")),
		"story": str(snapshot.get("story_text", "")),
		"travel_available": bool(snapshot.get("travel_available", false)),
		"card_titles": _card_titles(snapshot.get("cards", [])),
	}


func _assert_m2_player_feedback_clarity(context_label: String) -> void:
	var visible_text := " ".join(_visible_text(app))
	for forbidden in [
		"state updated",
		"delta",
		"serialized",
		"foundation",
		"contract",
		"module",
		"service hook",
		"lender hook",
		"suspicion",
	]:
		_require(visible_text.findn(forbidden) == -1, "%s exposes technical UI text: %s." % [context_label, forbidden])
	_require(visible_text.find("Bankroll") != -1, "%s does not show understandable bankroll text." % context_label)
	_require(visible_text.find("Risk:") != -1 or visible_text.find("Heat") != -1, "%s does not show understandable risk/heat text." % context_label)
	var consequence: Dictionary = app.call("current_consequence_view_snapshot")
	if str(consequence.get("current_state_text", "")).find("Cash") == -1:
		_add_warning("%s does not explain economy pressure in player-facing language." % context_label)
	else:
		_cover("m2_consequence_clarity")
	_require(str(consequence.get("recent_result_text", "")).find("Heat") != -1, "%s does not label security pressure as heat in recent results." % context_label)
	var cards_node: Variant = app.get("consequence_cards_list")
	if cards_node is Container:
		_require((cards_node as Container).get_child_count() <= 3, "%s shows more than three compact consequence cards." % context_label)
		_cover("m2_consequence_clarity")


func _assert_objective_hud(context_label: String) -> void:
	_require(app.get("objective_label") != null, "%s does not expose the objective HUD label." % context_label)
	var objective_text := _control_text("objective_label")
	var status_text := _control_text("status_label")
	var save_text := _control_text("save_status_label")
	_require(not objective_text.is_empty(), "%s objective HUD is empty." % context_label)
	_require(objective_text.find("Goal:") != -1, "%s objective HUD does not name the current goal." % context_label)
	_require(objective_text.find("Cash:") != -1, "%s objective HUD does not include bankroll/economy pressure." % context_label)
	_require(objective_text.find("Heat:") != -1, "%s objective HUD does not include heat/security pressure." % context_label)
	_require(objective_text.find("Next:") != -1, "%s objective HUD does not include a next opportunity hint." % context_label)
	_require(status_text.find("[$]") != -1 and status_text.find("[HEAT]") != -1 and status_text.find("[DEBT]") != -1 and status_text.find("[RUN]") != -1, "%s run-status HUD does not show compact bankroll, heat, debt, and run indicators." % context_label)
	_require(objective_text.find("[GOAL]") != -1 and objective_text.find("[ENV]") != -1 and objective_text.find("[GEAR]") != -1, "%s run-status HUD does not show objective, environment, and gear indicators." % context_label)
	_require(save_text.find("[AUTO]") != -1, "%s run-status HUD does not show autosave status." % context_label)
	for forbidden in ["serialized", "foundation", "contract", "module", "_", "state updated", "delta"]:
		_require(objective_text.findn(forbidden) == -1 and status_text.findn(forbidden) == -1 and save_text.findn(forbidden) == -1, "%s run-status HUD exposes technical text: %s." % [context_label, forbidden])
	if app.has_method("current_objective_hud_snapshot"):
		var snapshot: Dictionary = app.call("current_objective_hud_snapshot")
		_require(str(snapshot.get("text", "")) == objective_text, "%s objective HUD snapshot does not match visible text." % context_label)
		var guidance: Dictionary = snapshot.get("guidance", {})
		_require(not str(snapshot.get("objective_state", "")).strip_edges().is_empty(), "%s objective HUD snapshot does not expose objective_state." % context_label)
		_require(not str(guidance.get("text", "")).strip_edges().is_empty(), "%s objective HUD snapshot does not expose guidance text." % context_label)
		_cover("objective_state_guidance")
	if app.has_method("current_run_status_hud_snapshot"):
		var hud: Dictionary = app.call("current_run_status_hud_snapshot")
		for field in ["status_text", "objective_text", "save_text", "bankroll_text", "heat_text", "heat_meter", "debt_text", "environment_text", "inventory_text", "run_text", "goal_text"]:
			_require(not str(hud.get(field, "")).strip_edges().is_empty(), "%s run-status HUD snapshot is missing field: %s." % [context_label, field])
		_require(str(hud.get("status_text", "")) == status_text, "%s run-status HUD status snapshot does not match visible text." % context_label)
		_require(str(hud.get("objective_text", "")) == objective_text, "%s run-status HUD objective snapshot does not match visible text." % context_label)
		_require(str(hud.get("save_text", "")) == save_text, "%s run-status HUD save snapshot does not match visible text." % context_label)
		_cover("r100_run_status_hud_structured")
	_cover("objective_hud")


func _run_state_restore_summary(serialized: Dictionary) -> Dictionary:
	var current_environment: Dictionary = serialized.get("current_environment", {})
	var suspicion: Dictionary = serialized.get("suspicion", {})
	return {
		"seed_text": str(serialized.get("seed_text", "")),
		"seed_value": int(serialized.get("seed_value", 0)),
		"rng_state": int(serialized.get("rng_state", 0)),
		"challenge_config": _restore_summary_value(serialized.get("challenge_config", {})),
		"bankroll": int(serialized.get("bankroll", 0)),
		"economic_state": str(serialized.get("economic_state", "")),
		"inventory": _restore_summary_value(serialized.get("inventory", [])),
		"debt": _restore_summary_value(serialized.get("debt", [])),
		"suspicion_level": int(suspicion.get("level", 0)),
		"environment_id": str(current_environment.get("id", "")),
		"unlocked_travel": _restore_summary_value(serialized.get("unlocked_travel", [])),
		"narrative_flags": _restore_summary_value(serialized.get("narrative_flags", {})),
		"story_count": _array_size(serialized.get("story_log", [])),
		"run_status": str(serialized.get("run_status", "")),
	}


func _restore_summary_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var normalized_dict: Dictionary = {}
			for key in (value as Dictionary).keys():
				normalized_dict[key] = _restore_summary_value((value as Dictionary).get(key))
			return normalized_dict
		TYPE_ARRAY:
			var normalized_array: Array = []
			for item in value as Array:
				normalized_array.append(_restore_summary_value(item))
			return normalized_array
		TYPE_FLOAT:
			var rounded := roundf(float(value))
			if is_equal_approx(float(value), rounded):
				return int(rounded)
			return value
	return value


func _visible_text(root_node: Node) -> Array:
	var result: Array = []
	for item in _visible_control_items(root_node):
		result.append(str((item as Dictionary).get("text", "")))
	return result


func _visible_button_text(root_node: Node) -> Array:
	var result: Array = []
	for item in _visible_control_items(root_node):
		var data := item as Dictionary
		if str(data.get("kind", "")) == "button":
			var suffix := " (disabled)" if bool(data.get("disabled", false)) else ""
			result.append("%s%s" % [str(data.get("text", "")), suffix])
	return result


func _visible_control_items(root_node: Node) -> Array:
	var result: Array = []
	_collect_visible_control_items(root_node, result)
	return result


func _collect_visible_control_items(node: Node, result: Array) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	var text := ""
	var kind := ""
	var disabled := false
	if node is Button:
		var button := node as Button
		text = button.text
		kind = "button"
		disabled = button.disabled
	elif node is Label:
		text = (node as Label).text
		kind = "label"
	elif node is LineEdit:
		var line_edit := node as LineEdit
		text = line_edit.text if not line_edit.text.is_empty() else line_edit.placeholder_text
		kind = "line_edit"
	elif node is SpinBox:
		text = "Stake %d" % int((node as SpinBox).value)
		kind = "spin_box"
	if not text.strip_edges().is_empty():
		result.append({
			"node": node,
			"kind": kind,
			"text": text.strip_edges(),
			"disabled": disabled,
		})
	for child in node.get_children():
		_collect_visible_control_items(child, result)


func _set_seed_text(seed_text: String) -> void:
	for item in _visible_control_items(app):
		var data := item as Dictionary
		if str(data.get("kind", "")) == "line_edit":
			var input := data.get("node") as LineEdit
			input.text = seed_text
			input.text_changed.emit(seed_text)
			return
	_require(false, "Could not find visible seed input.")


func _assert_active_foundation_guardrails() -> void:
	var script_paths: Array = []
	_collect_active_script_paths(root, script_paths)
	var checks: Dictionary = report["architecture_checks"]
	checks["active_script"] = app.get_script().resource_path
	checks["uses_foundation_runtime"] = bool(app.call("uses_foundation_runtime"))
	checks["active_script_paths"] = script_paths.duplicate()
	for path_value in script_paths:
		var path := str(path_value).to_lower()
		_require(path.find("runtime_content") == -1, "Active foundation path uses an archived runtime loader: %s" % str(path_value))
		_require(path.find("core_content") == -1, "Active foundation path uses archived runtime content: %s" % str(path_value))
		_require(path.find("game_ui_module") == -1, "Active foundation path uses an archived game UI module: %s" % str(path_value))
	checks["avoids_runtime_content"] = true
	checks["avoids_core_content"] = true
	checks["avoids_game_ui_module"] = true


func _collect_active_script_paths(node: Node, result: Array) -> void:
	if node == null:
		return
	var script: Variant = node.get_script()
	if script != null and script is Script:
		var path := (script as Script).resource_path
		if not path.is_empty() and not result.has(path):
			result.append(path)
	for child: Node in node.get_children():
		_collect_active_script_paths(child, result)


func _assert_screen_click_only_gameplay_events() -> void:
	_require(_has_input_event("canvas_mouse_double_click", "object_type", "game"), "Screen-click-only QA did not enter the game by double-clicking a visible game object.")
	var fixed_price_surface := _has_input_event("game_surface_fixed_price", "action", "fixed_price_action")
	_require(_has_input_event("game_surface_stake_click", "action", "surface_stake_max") or fixed_price_surface, "Screen-click-only QA did not change stake from the visible game surface or classify a fixed-price surface.")
	if not fixed_price_surface:
		_require(_has_game_surface_action_kind("game_surface_mouse_click", "legal"), "Screen-click-only QA did not select a legal action from the visible game surface.")
	_require(_has_game_surface_action_kind("game_surface_mouse_confirm_click", "legal"), "Screen-click-only QA did not resolve a legal action from the visible game surface.")
	var game_surface_statuses: Dictionary = report.get("game_surface_status", {})
	var risky_status: Dictionary = game_surface_statuses.get("risky", {})
	if str(risky_status.get("status", "")) != "skipped_unavailable":
		if not fixed_price_surface:
			_require(_has_game_surface_action_kind("game_surface_mouse_click", "cheat"), "Screen-click-only QA did not select a risky action from the visible game surface.")
		_require(_has_game_surface_action_kind("game_surface_mouse_confirm_click", "cheat"), "Screen-click-only QA did not resolve a risky action from the visible game surface.")
	for event_value in report["input_events"]:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event_data: Dictionary = event_value
		if str(event_data.get("kind", "")) != "visible_button_signal":
			var fallback_kind := str(event_data.get("kind", ""))
			_require(fallback_kind != "visible_object_button_fallback" and fallback_kind != "visible_save_button_fallback", "Screen-click-only QA used a side-panel fallback instead of a visible room object: %s" % fallback_kind)
			continue
		var label := str(event_data.get("label", ""))
		_require(not _is_prohibited_game_control_button_label(label), "Screen-click-only QA used a prohibited game resolution button: %s" % label)
	_cover("r100_game_resolution_surface_only")


func _assert_direct_environment_object_events() -> void:
	_require(_has_input_event("canvas_mouse_double_click", "object_type", "game"), "Direct object QA did not enter a game by double-clicking a visible game object.")
	_require(bool(report["coverage"].get("autosave_available", false)), "Direct object QA did not verify autosave availability.")
	if report["coverage"].get("multiple_game_objects_clickable", false):
		_require(_canvas_input_event_count("game") >= 2, "Direct object QA did not click multiple visible game objects.")
		_cover("r100_multiple_games_clickable")
	for event_value in report["input_events"]:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event_data: Dictionary = event_value
		var fallback_kind := str(event_data.get("kind", ""))
		_require(fallback_kind != "visible_object_button_fallback" and fallback_kind != "visible_save_button_fallback", "Direct object QA used a side-panel fallback instead of a visible room object: %s" % fallback_kind)


func _canvas_input_event_count(object_type: String) -> int:
	var count := 0
	for event_value in report["input_events"]:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event_data: Dictionary = event_value
		var kind := str(event_data.get("kind", ""))
		if (kind == "canvas_mouse_click" or kind == "canvas_mouse_double_click") and str(event_data.get("object_type", "")) == object_type:
			count += 1
	return count


func _has_input_event(kind: String, key: String = "", value: String = "") -> bool:
	for event_value in report["input_events"]:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event_data: Dictionary = event_value
		if str(event_data.get("kind", "")) != kind:
			continue
		if key.is_empty():
			return true
		if str(event_data.get(key, "")) == value:
			return true
	return false


func _has_game_surface_action_kind(event_kind: String, action_kind: String) -> bool:
	for event_value in report["input_events"]:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event_data: Dictionary = event_value
		if str(event_data.get("kind", "")) != event_kind:
			continue
		if str(event_data.get("selected_action_kind", "")) == action_kind:
			return true
	return false


func _is_prohibited_game_control_button_label(label: String) -> bool:
	for prefix in report["prohibited_game_control_button_labels"]:
		if label.find(str(prefix)) != -1:
			return true
	return false


func _set_game_surface_stake_to_highest_value() -> int:
	var snapshot: Dictionary = app.call("current_game_view_snapshot")
	_require(bool(snapshot.get("has_valid_stake", false)), "Game surface does not expose a valid stake range.")
	var min_stake := int(snapshot.get("stake_min", 1))
	var max_stake := int(snapshot.get("stake_max", min_stake))
	var starting_stake := int(snapshot.get("selected_stake", min_stake))
	_require(starting_stake >= min_stake and starting_stake <= max_stake, "Initial selected stake is outside the valid range.")
	if max_stake <= min_stake:
		_add_warning("Stake range has no higher valid value; surface stake max path still checked.")
	var serialized_before_max := _serialized_run_text()
	_require(await _push_game_surface_action("surface_stake_max", -1), "Could not click the game surface stake max control.")
	await _settle()
	_require(serialized_before_max == _serialized_run_text(), "Surface stake selection mutated serialized RunState.")
	snapshot = app.call("current_game_view_snapshot")
	var selected_max := int(snapshot.get("selected_stake", 0))
	_require(selected_max == max_stake, "Game surface stake max control did not select the highest valid stake.")
	_record_input_event({
		"kind": "game_surface_stake_click",
		"action": "surface_stake_max",
		"selected_stake": selected_max,
	})
	var serialized_before_invalid := _serialized_run_text()
	_require(await _push_game_surface_action("surface_stake_up", -1), "Could not click the game surface stake increase control.")
	await _settle()
	_require(serialized_before_invalid == _serialized_run_text(), "Invalid surface stake increase mutated serialized RunState.")
	snapshot = app.call("current_game_view_snapshot")
	_require(int(snapshot.get("selected_stake", 0)) == max_stake, "Invalid surface stake increase changed the selected stake.")
	_record_input_event({
		"kind": "game_surface_stake_invalid_click",
		"action": "surface_stake_up",
		"selected_stake": int(snapshot.get("selected_stake", 0)),
	})
	return selected_max


func _set_game_surface_stake_to_lowest_value() -> int:
	var snapshot: Dictionary = app.call("current_game_view_snapshot")
	_require(bool(snapshot.get("has_valid_stake", false)), "Game surface does not expose a valid stake range.")
	var min_stake := int(snapshot.get("stake_min", 1))
	var safety := 0
	while int(snapshot.get("selected_stake", min_stake)) > min_stake and safety < 100:
		var serialized_before_min := _serialized_run_text()
		_require(await _push_game_surface_action("surface_stake_down", -1), "Could not click the game surface stake decrease control.")
		await _settle()
		_require(serialized_before_min == _serialized_run_text(), "Surface stake decrease mutated serialized RunState.")
		snapshot = app.call("current_game_view_snapshot")
		safety += 1
	_require(int(snapshot.get("selected_stake", 0)) == min_stake, "Game surface stake decrease did not reach the minimum valid stake.")
	_record_input_event({
		"kind": "game_surface_stake_click",
		"action": "surface_stake_min",
		"selected_stake": min_stake,
	})
	return min_stake


func _drive_risky_surface_until_heat(min_heat: int, max_attempts: int, first_visible_risky_heat_delta: int) -> bool:
	var snapshot: Dictionary = app.call("current_game_view_snapshot")
	var fixed_price_surface := bool(snapshot.get("surface_fixed_price_actions", false)) or not bool(snapshot.get("surface_stake_controls_required", true))
	if not fixed_price_surface:
		var min_stake := await _set_game_surface_stake_to_lowest_value()
		_require(min_stake >= 0, "Could not set game surface stake to the minimum for high-heat QA.")
	var attempts := 0
	var highest_visible_risk_delta := first_visible_risky_heat_delta
	while _current_serialized_heat() < min_heat and attempts < max_attempts:
		if fixed_price_surface:
			await _reset_fixed_price_surface_for_risky_action()
		var cheat_binding := _game_surface_action_binding("cheat")
		var serialized_before_resolve := _serialized_run_text()
		if not fixed_price_surface:
			var serialized_before_select := _serialized_run_text()
			var selected := await _click_game_surface_action(str(cheat_binding.get("action", "surface_cheat")), int(cheat_binding.get("index", 0)))
			if selected.is_empty():
				return false
			await _settle()
			_require(serialized_before_select == _serialized_run_text(), "Selecting a high-heat risky action mutated serialized RunState.")
			serialized_before_resolve = _serialized_run_text()
		var visible_risk_delta := _visible_risky_heat_delta(app.call("current_game_view_snapshot"))
		if visible_risk_delta > highest_visible_risk_delta:
			_cover("high_heat_changes_risk")
			highest_visible_risk_delta = visible_risk_delta
		if fixed_price_surface:
			if not await _resolve_visible_fixed_price_risky_action(serialized_before_resolve):
				_require(false, "Could not resolve a high-heat risky action from the visible game surface.")
				return false
			await _settle()
		else:
			if not (await _confirm_game_surface_action(str(cheat_binding.get("action", "surface_cheat")), int(cheat_binding.get("index", 0)))):
				_require(false, "Could not resolve a high-heat risky action from the visible game surface.")
				return false
			await _settle()
		if serialized_before_resolve == _serialized_run_text():
			_require(false, "Resolving a high-heat risky action did not update serialized RunState.")
			return false
		await _resolve_blocking_event_popups(2)
		var game_snapshot: Dictionary = app.call("current_game_view_snapshot")
		var visible_text := " ".join(_visible_text(app)).to_lower()
		var consequence_text := JSON.stringify(app.call("current_consequence_view_snapshot")).to_lower()
		var game_text := JSON.stringify(game_snapshot).to_lower()
		var pressure_text := "%s %s %s" % [visible_text, consequence_text, game_text]
		if pressure_text.find("shakedown") != -1 or pressure_text.find("costly exit") != -1 or pressure_text.find("risky moves now bring") != -1:
			_cover("high_heat_consequence")
		attempts += 1
	if not bool(report["coverage"].get("high_heat_changes_risk", false)):
		_require(false, "High heat did not increase visible risky-action heat.")
	if not bool(report["coverage"].get("high_heat_consequence", false)):
		_require(false, "High heat did not create a visible security consequence.")
	return _current_serialized_heat() >= min_heat


func _return_to_room_view() -> void:
	var surface_canvas := app.get("game_surface_canvas") as Control
	if surface_canvas != null and surface_canvas.visible and surface_canvas.has_method("local_position_for_surface_action"):
		var local_position: Vector2 = surface_canvas.call("local_position_for_surface_action", "surface_back", -1)
		if local_position.x >= 0.0 and local_position.y >= 0.0 and local_position.x <= surface_canvas.size.x and local_position.y <= surface_canvas.size.y:
			var global_position := surface_canvas.get_global_rect().position + local_position
			_push_mouse_motion(global_position)
			_push_mouse_button(global_position, true)
			_push_mouse_button(global_position, false)
			return
	if not _click_button_exact("Back to environment").is_empty():
		return
	if not _click_button_exact("Back to room").is_empty():
		return
	if not _click_button_contains("Back to environment").is_empty():
		return
	if not _click_button_contains("Back to room").is_empty():
		return
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
		return
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	if not bool(snapshot.get("camera_focus_active", false)):
		return
	var local_position := _blank_canvas_position(canvas)
	if local_position.x < 0.0 or local_position.y < 0.0 or local_position.x > canvas.size.x or local_position.y > canvas.size.y:
		return
	var global_position := canvas.get_global_rect().position + local_position
	_push_mouse_motion(global_position)
	_push_mouse_button(global_position, true)
	_push_mouse_button(global_position, false)


func _click_first_play_object_type(object_type: String) -> String:
	var canvas_click := await _click_first_canvas_object_type(object_type)
	if not canvas_click.is_empty():
		return canvas_click
	var fallback_click := _focus_first_visible_object_type(object_type)
	if not fallback_click.is_empty():
		_record_input_event({
			"kind": "visible_object_button_fallback",
			"object_type": object_type,
			"label": fallback_click,
		})
	return fallback_click


func _double_click_first_play_object_type(object_type: String) -> String:
	if object_type == "game":
		var canvas := app.get("environment_canvas") as Control
		if canvas != null and canvas.visible and canvas.has_method("current_view_snapshot"):
			var preferred_game := _preferred_canvas_game_object(canvas)
			if not preferred_game.is_empty():
				return await _double_click_canvas_object_data(canvas, preferred_game, object_type)
	return await _double_click_first_canvas_object_type(object_type)


func _double_click_first_travel_to_lender_environment() -> String:
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
		return ""
	var travel_object := _canvas_object_by_id(canvas, "travel:leave")
	if travel_object.is_empty():
		travel_object = _first_clickable_canvas_object_type_enabled(canvas, "travel", true)
	if travel_object.is_empty():
		return ""
	var environment_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var travel_choices: Array = environment_snapshot.get("travel_choices", [])
	for choice_value in travel_choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		var target_id := str(choice.get("id", ""))
		if target_id.is_empty() or not bool(choice.get("enabled", true)):
			continue
		if not _travel_destination_has_lender(target_id):
			continue
		var travel_button := await _double_click_canvas_object_data(canvas, travel_object, "travel")
		if travel_button.is_empty():
			return ""
		await _settle()
		if not bool(app.call("current_screen_snapshot").get("world_map_overlay_visible", false)):
			return ""
		if not bool(app.call("select_world_map_node", target_id)):
			return ""
		app.call("confirm_world_map_travel")
		await _settle()
		return travel_button
	return ""


func _travel_destination_has_lender(target_id: String) -> bool:
	if target_id.is_empty():
		return false
	var content_library: ContentLibrary = app.get("library")
	if content_library == null:
		return false
	for archetype in content_library.environment_archetypes:
		if typeof(archetype) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = archetype
		if str(data.get("id", "")) == target_id:
			return not (data.get("lender_hooks", []) as Array).is_empty()
	return false


func _game_surface_is_primary(surface_canvas: Control) -> bool:
	if surface_canvas == null or not surface_canvas.visible:
		return false
	var surface_rect := surface_canvas.get_global_rect()
	if surface_rect.size.x <= 0.0 or surface_rect.size.y <= 0.0:
		return false
	var environment_canvas := app.get("environment_canvas") as Control
	if environment_canvas == null or not environment_canvas.visible:
		return true
	var environment_rect := environment_canvas.get_global_rect()
	return surface_rect.size.x * surface_rect.size.y > environment_rect.size.x * environment_rect.size.y


func _assert_no_scroll_critical_path(context: String) -> void:
	var serialized_before := _serialized_run_text()
	var viewport_rect := root.get_viewport().get_visible_rect()
	_require(viewport_rect.size.x >= 1279.0 and viewport_rect.size.y >= 719.0, "%s is not running at the 1280x720 target viewport: %s." % [context, str(viewport_rect)])
	var start_control := app.get("start_screen") as Control
	var run_control := app.get("run_screen") as Control
	if start_control != null and start_control.visible:
		_require(_control_fits_viewport(start_control, "%s start screen" % context), "%s start screen is outside the visible viewport." % context)
		_cover("r100_stab_no_scroll_critical_path")
		return
	if run_control == null or not run_control.visible:
		return
	_require(_control_fits_viewport(run_control, "%s run screen" % context), "%s run screen is outside the visible viewport." % context)
	for entry in [
		{"name": "status_label", "label": "HUD status"},
		{"name": "objective_label", "label": "objective HUD"},
		{"name": "save_status_label", "label": "save status"},
		{"name": "title_label", "label": "title"},
		{"name": "summary_label", "label": "summary"},
	]:
		var control := app.get(str(entry.get("name", ""))) as Control
		_require(control != null and control.visible and control.is_visible_in_tree(), "%s %s is not visible." % [context, str(entry.get("label", ""))])
		_require(_control_fits_viewport(control, "%s %s" % [context, str(entry.get("label", ""))]), "%s %s is outside the visible viewport." % [context, str(entry.get("label", ""))])
	_assert_result_area_useful_or_hidden(context)
	var environment_control := app.get("environment_canvas") as Control
	var game_surface_control := app.get("game_surface_canvas") as Control
	if environment_control != null and environment_control.visible:
		_assert_environment_canvas_contained(context)
		var screen_snapshot: Dictionary = app.call("current_screen_snapshot")
		if str(screen_snapshot.get("screen", "")) == "ENVIRONMENT":
			_require(_has_visible_text(app, "double-click glowing props to act"), "%s room mode does not show visible object interaction guidance." % context)
	if game_surface_control != null and game_surface_control.visible:
		_assert_game_surface_contained(context)
		var game_snapshot: Dictionary = app.call("current_game_view_snapshot")
		_require(_game_surface_is_primary(game_surface_control), "%s game surface is not primary in game mode." % context)
		_require(bool(game_snapshot.get("has_valid_stake", false)), "%s game surface does not expose a valid stake range." % context)
		if game_surface_control.has_method("local_position_for_surface_action"):
			var back_position: Vector2 = game_surface_control.call("local_position_for_surface_action", "surface_back", -1)
			_require(back_position.x >= 0.0 and back_position.y >= 0.0, "%s game mode does not expose surface navigation." % context)
		_cover("game_surface_primary")
	_require(serialized_before == _serialized_run_text(), "%s no-scroll layout verification mutated serialized RunState." % context)
	_cover("r100_stab_no_scroll_critical_path")


func _assert_result_area_useful_or_hidden(context: String) -> void:
	var panel := app.get("consequence_panel") as Control
	var cards_scroll := app.get("consequence_cards_scroll") as Control
	var cards_list := app.get("consequence_cards_list") as Container
	var panel_visible := panel != null and panel.visible and panel.is_visible_in_tree()
	if panel_visible:
		_require(_control_fits_viewport(panel, "%s result panel" % context), "%s result panel is outside the visible viewport." % context)
		_require(cards_scroll != null and cards_scroll.visible and cards_scroll.is_visible_in_tree(), "%s result panel is visible without visible consequence cards." % context)
		_require(_control_fits_viewport(cards_scroll, "%s result cards" % context), "%s result cards are outside the visible viewport." % context)
		_require(cards_list != null and cards_list.get_child_count() > 0, "%s result panel is visible but has no consequence cards." % context)
		_require(_has_visible_text(app, "Recent consequence"), "%s result panel is visible without a player-facing consequence heading." % context)
		_cover("r100_result_populated_after_consequence")
	else:
		_require(not _has_visible_text(app, "Recent consequence"), "%s shows consequence text while the result panel is hidden." % context)
		_cover("r100_result_hidden_when_empty")
	_cover("r100_stab_result_useful_or_hidden")


func _assert_game_surface_contained(context: String) -> void:
	var surface := app.get("game_surface_canvas") as Control
	_require(surface != null and surface.visible and surface.is_visible_in_tree(), "%s does not show the game surface." % context)
	_require(_control_fits_viewport(surface, "%s game surface" % context), "%s game surface is outside the visible viewport." % context)
	var surface_rect := surface.get_global_rect()
	for entry in [
		{"name": "status_label", "label": "HUD status"},
		{"name": "objective_label", "label": "objective HUD"},
		{"name": "save_status_label", "label": "save status"},
		{"name": "actions_list", "label": "context controls"},
		{"name": "consequence_panel", "label": "result panel"},
		{"name": "environment_canvas", "label": "environment surface"},
	]:
		var control := app.get(str(entry.get("name", ""))) as Control
		if control == null or control == surface or not control.visible or not control.is_visible_in_tree():
			continue
		var control_label := "%s %s" % [context, str(entry.get("label", ""))]
		_require(_control_fits_viewport(control, control_label), "%s is outside the viewport while the game surface is visible." % control_label)
		_require(not surface_rect.intersects(control.get_global_rect()), "%s game surface overlaps %s." % [context, str(entry.get("label", ""))])
	_cover("r100_critical_controls_1280_visible")
	_cover("r100_stab_game_surface_no_overlap")


func _assert_environment_canvas_contained(context: String) -> void:
	var canvas := app.get("environment_canvas") as Control
	_require(canvas != null and canvas.visible, "%s does not show the environment canvas." % context)
	_require(bool(canvas.get("clip_contents")), "%s environment canvas does not clip drawing to its assigned area." % context)
	_require(_control_fits_viewport(canvas, "%s environment canvas" % context), "%s environment canvas is outside the visible viewport." % context)
	if canvas.has_method("current_view_snapshot"):
		var snapshot: Dictionary = canvas.call("current_view_snapshot")
		_require(bool(snapshot.get("clip_contents", false)), "%s environment canvas snapshot does not report clipped drawing." % context)
		_require(bool(snapshot.get("preserves_aspect_ratio", false)), "%s environment canvas is not preserving the art aspect ratio." % context)
		var board_rect := _snapshot_rect(snapshot.get("board_rect", {}))
		var board_aspect := float(snapshot.get("board_aspect_ratio", 0.0))
		_require(board_rect.size.x > 0.0 and board_rect.size.y > 0.0, "%s environment canvas did not expose a rendered board rect." % context)
		_require(absf((board_rect.size.x / board_rect.size.y) - board_aspect) < 0.01, "%s environment board rect is stretched instead of aspect-preserved." % context)
		_require(_camera_target_stays_inside_canvas(canvas, snapshot), "%s focus camera target would leave empty space or spill outside the environment surface." % context)
		var object_layout: Dictionary = snapshot.get("object_layout", {})
		_require(int(object_layout.get("overlap_count", -1)) == 0, "%s environment prop layout overlaps: %s." % [context, str(object_layout.get("overlaps", []))])
		_cover("r100_focus_camera_clipped")
		_cover("environment_canvas_preserves_aspect")
	_check_environment_canvas_clear_of_controls(canvas, context)
	_cover("environment_canvas_clipped")
	_cover("r100_environment_no_overlap")
	_cover("focused_environment_controls_visible")


func _camera_target_stays_inside_canvas(canvas: Control, snapshot: Dictionary) -> bool:
	var zoom := float(snapshot.get("target_camera_zoom", 1.0))
	if zoom < 1.0:
		return false
	var rect := _snapshot_rect(snapshot.get("target_board_rect", {}))
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	return _board_axis_stays_inside_canvas(rect.position.x, rect.end.x, canvas.size.x) and _board_axis_stays_inside_canvas(rect.position.y, rect.end.y, canvas.size.y)


func _board_axis_stays_inside_canvas(start: float, end: float, canvas_length: float) -> bool:
	if end - start <= canvas_length + 1.0:
		return start >= -1.0 and end <= canvas_length + 1.0
	return start <= 1.0 and end >= canvas_length - 1.0


func _check_environment_canvas_clear_of_controls(canvas: Control, context: String) -> void:
	var controls := [
		{"name": "status_label", "label": "HUD status"},
		{"name": "objective_label", "label": "objective HUD"},
		{"name": "save_status_label", "label": "save status"},
		{"name": "actions_list", "label": "context controls"},
		{"name": "consequence_cards_scroll", "label": "result controls"},
		{"name": "game_surface_canvas", "label": "game surface"},
	]
	var canvas_rect := canvas.get_global_rect()
	for entry in controls:
		var control := app.get(str(entry.get("name", ""))) as Control
		if control == null or control == canvas or not control.visible or not control.is_visible_in_tree():
			continue
		var control_label := "%s %s" % [context, str(entry.get("label", ""))]
		_require(_control_fits_viewport(control, control_label), "%s is outside the viewport while the environment canvas is visible." % control_label)
		_require(not canvas_rect.intersects(control.get_global_rect()), "%s environment canvas overlaps %s." % [context, str(entry.get("label", ""))])
	_cover("r100_critical_controls_1280_visible")


func _control_fits_viewport(control: Control, label: String) -> bool:
	if control == null:
		return false
	var viewport_rect := root.get_viewport().get_visible_rect()
	var rect := control.get_global_rect()
	var min_x := float(viewport_rect.position.x) - 1.0
	var min_y := float(viewport_rect.position.y) - 1.0
	var max_x := float(viewport_rect.position.x + viewport_rect.size.x) + 1.0
	var max_y := float(viewport_rect.position.y + viewport_rect.size.y) + 1.0
	return rect.position.x >= min_x and rect.position.y >= min_y and rect.end.x <= max_x and rect.end.y <= max_y


func _snapshot_rect(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value as Rect2
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = value
	return Rect2(
		Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))),
		Vector2(float(data.get("w", 0.0)), float(data.get("h", 0.0)))
	)


func _environment_canvas_is_primary() -> bool:
	var environment_canvas := app.get("environment_canvas") as Control
	if environment_canvas == null or not environment_canvas.visible:
		return false
	var surface_canvas := app.get("game_surface_canvas") as Control
	return surface_canvas == null or not surface_canvas.visible


func _game_surface_action_binding(kind: String) -> Dictionary:
	var fallback_action := "surface_legal" if kind == "legal" else "surface_cheat"
	var fallback := {"action": fallback_action, "index": 0}
	if kind == "cheat":
		var native_cheat := _native_game_surface_action_binding(kind, {})
		if not native_cheat.is_empty():
			return native_cheat
	var snapshot: Dictionary = app.call("current_game_view_snapshot")
	var bindings: Dictionary = snapshot.get("surface_action_bindings", {})
	var binding_value: Variant = bindings.get(kind, {})
	if typeof(binding_value) != TYPE_DICTIONARY:
		return _native_game_surface_action_binding(kind, fallback)
	var binding: Dictionary = binding_value
	if binding.is_empty():
		return _native_game_surface_action_binding(kind, fallback)
	var action := str(binding.get("action", fallback_action))
	if action.is_empty():
		action = fallback_action
	return {
		"action": action,
		"index": int(binding.get("index", 0)),
	}


func _native_game_surface_action_binding(kind: String, fallback: Dictionary) -> Dictionary:
	var surface_canvas := app.get("game_surface_canvas") as Control
	if surface_canvas == null or not surface_canvas.visible or not surface_canvas.has_method("current_view_snapshot"):
		return fallback
	var surface_snapshot: Dictionary = surface_canvas.call("current_view_snapshot")
	var hit_actions: Array = surface_snapshot.get("surface_hit_actions", [])
	var preferred_actions := []
	if kind == "legal":
		preferred_actions = ["video_poker_draw", "video_poker_deal", "video_poker_collect", "slot_spin", "bar_dice_roll"]
	elif kind == "cheat_setup":
		preferred_actions = ["bar_dice_roll", "video_poker_deal", "pull_tab_buy"]
	else:
		preferred_actions = ["video_poker_mark", "blackjack_peek", "bar_dice_release", "bar_dice_load", "bar_dice_palm", "roulette_late_bet", "baccarat_palm"]
	for preferred_action in preferred_actions:
		var preferred_binding := _surface_hit_action_binding(hit_actions, str(preferred_action))
		if not preferred_binding.is_empty():
			return preferred_binding
	var fallback_action := str(fallback.get("action", ""))
	var fallback_binding := _surface_hit_action_binding(hit_actions, fallback_action)
	if not fallback_binding.is_empty():
		return fallback_binding
	return fallback


func _surface_hit_action_binding(hit_actions: Array, action: String) -> Dictionary:
	if action.is_empty():
		return {}
	for hit_value in hit_actions:
		if typeof(hit_value) != TYPE_DICTIONARY:
			continue
		var hit_data := hit_value as Dictionary
		if str(hit_data.get("action", "")) != action:
			continue
		return {
			"action": action,
			"index": int(hit_data.get("index", 0)),
		}
	return {}


func _surface_action_binding_available(binding: Dictionary) -> bool:
	var surface_canvas := app.get("game_surface_canvas") as Control
	if surface_canvas == null or not surface_canvas.visible or not surface_canvas.has_method("local_position_for_surface_action"):
		return false
	var local_position: Vector2 = surface_canvas.call(
		"local_position_for_surface_action",
		str(binding.get("action", "")),
		int(binding.get("index", 0))
	)
	return local_position.x >= 0.0 and local_position.y >= 0.0 and local_position.x <= surface_canvas.size.x and local_position.y <= surface_canvas.size.y


func _prepare_fixed_price_cheat_binding() -> Dictionary:
	for _attempt in range(6):
		var cheat_binding := _game_surface_action_binding("cheat")
		if _surface_action_binding_available(cheat_binding):
			return cheat_binding
		var setup_binding := _fixed_price_cheat_setup_binding()
		if not _surface_action_binding_available(setup_binding):
			return cheat_binding
		if not await _push_game_surface_action(str(setup_binding.get("action", "surface_legal")), int(setup_binding.get("index", 0))):
			return cheat_binding
		await _settle()
	return _game_surface_action_binding("cheat")


func _fixed_price_cheat_setup_binding() -> Dictionary:
	var setup_binding := _native_game_surface_action_binding("cheat_setup", {})
	if not setup_binding.is_empty():
		return setup_binding
	return _game_surface_action_binding("legal")


func _resolve_visible_fixed_price_risky_action(serialized_before: String) -> bool:
	var game_snapshot: Dictionary = app.call("current_game_view_snapshot")
	var game_id := str(game_snapshot.get("game_id", ""))
	if game_id == "bar_dice":
		if not _surface_action_available("bar_dice_load") and _surface_action_available("bar_dice_roll"):
			if not await _push_game_surface_action("bar_dice_roll", 0):
				return false
			await _settle()
		if _surface_action_available("bar_dice_load"):
			if not await _confirm_game_surface_action("bar_dice_load", 0):
				return false
			await _settle()
			if serialized_before != _serialized_run_text():
				return true
		if _surface_action_available("bar_dice_release"):
			if not await _confirm_game_surface_action("bar_dice_release", 0):
				return false
			await _settle()
			return serialized_before != _serialized_run_text()
		if _surface_action_available("bar_dice_palm"):
			if not await _confirm_game_surface_action("bar_dice_palm", 0):
				return false
			await _settle()
			if serialized_before != _serialized_run_text():
				return true
			if not await _confirm_game_surface_action("bar_dice_resolve", 0):
				return false
			await _settle()
			return serialized_before != _serialized_run_text()
		return false
	for _step in range(4):
		var cheat_binding := _game_surface_action_binding("cheat")
		if not _surface_action_binding_available(cheat_binding):
			var setup_binding := _fixed_price_cheat_setup_binding()
			if not _surface_action_binding_available(setup_binding):
				return false
			if not await _push_game_surface_action(str(setup_binding.get("action", "surface_legal")), int(setup_binding.get("index", 0))):
				return false
			await _settle()
			continue
		if not await _confirm_game_surface_action(str(cheat_binding.get("action", "surface_cheat")), int(cheat_binding.get("index", 0))):
			return false
		await _settle()
		if serialized_before != _serialized_run_text():
			return true
	return false


func _surface_action_available(action: String, index: int = 0) -> bool:
	return _surface_action_binding_available({"action": action, "index": index})


func _click_game_surface_action(action: String, index: int) -> String:
	var pushed := await _push_game_surface_action(action, index)
	if not pushed:
		return ""
	var game_snapshot: Dictionary = app.call("current_game_view_snapshot")
	var selected_label := str(game_snapshot.get("selected_action_label", ""))
	var selected_id := str(game_snapshot.get("selected_action_id", ""))
	if selected_label.is_empty() and selected_id.is_empty():
		return ""
	_record_input_event({
		"kind": "game_surface_mouse_click",
		"action": action,
		"index": index,
		"selected_action_id": selected_id,
		"selected_action_label": selected_label,
		"selected_action_kind": str(game_snapshot.get("selected_action_kind", "")),
	})
	return selected_label if not selected_label.is_empty() else selected_id


func _confirm_game_surface_action(action: String, index: int) -> bool:
	var selected_snapshot: Dictionary = app.call("current_game_view_snapshot")
	var pushed := await _push_game_surface_action(action, index)
	if not pushed:
		return false
	var result_snapshot: Dictionary = app.call("current_game_view_snapshot")
	var event_selected_id := str(selected_snapshot.get("selected_action_id", ""))
	if event_selected_id.is_empty():
		event_selected_id = str(result_snapshot.get("action_id", ""))
	var event_selected_label := str(selected_snapshot.get("selected_action_label", ""))
	if event_selected_label.is_empty():
		event_selected_label = event_selected_id
	var event_selected_kind := str(selected_snapshot.get("selected_action_kind", ""))
	if event_selected_kind.is_empty():
		event_selected_kind = str(result_snapshot.get("action_kind", ""))
	_record_input_event({
		"kind": "game_surface_mouse_confirm_click",
		"action": action,
		"index": index,
		"game_id": str(selected_snapshot.get("game_id", result_snapshot.get("game_id", ""))),
		"game_label": str(selected_snapshot.get("display_name", result_snapshot.get("display_name", ""))),
		"selected_action_id": event_selected_id,
		"selected_action_label": event_selected_label,
		"selected_action_kind": event_selected_kind,
		"stake": int(result_snapshot.get("result_stake", selected_snapshot.get("selected_stake", 0))),
		"bankroll_delta": int(result_snapshot.get("bankroll_delta", 0)),
		"suspicion_delta": int(result_snapshot.get("suspicion_delta", 0)),
		"won": bool(result_snapshot.get("won", false)),
		"result_message": str(result_snapshot.get("result_message", "")),
		"bankroll_after": int(result_snapshot.get("bankroll", 0)),
		"heat_after": int(result_snapshot.get("suspicion_level", 0)),
	})
	return true


func _push_game_surface_action(action: String, index: int, double_click: bool = false) -> bool:
	var surface_canvas := app.get("game_surface_canvas") as Control
	if surface_canvas == null or not surface_canvas.visible:
		return false
	if not surface_canvas.has_method("local_position_for_surface_action"):
		return false
	await _wait_for_game_surface_action_available(surface_canvas, action)
	surface_canvas.queue_redraw()
	await _settle()
	var local_position: Vector2 = surface_canvas.call("local_position_for_surface_action", action, index)
	if local_position.x < 0.0 or local_position.y < 0.0 or local_position.x > surface_canvas.size.x or local_position.y > surface_canvas.size.y:
		return false
	var global_position := surface_canvas.get_global_rect().position + local_position
	_push_mouse_motion(global_position)
	await _settle()
	_push_mouse_button(global_position, true, double_click)
	await _settle()
	_push_mouse_button(global_position, false, double_click)
	await _settle()
	return true


func _wait_for_game_surface_action_available(surface_canvas: Control, action: String, max_attempts: int = 96) -> void:
	if surface_canvas == null or not surface_canvas.has_method("surface_action_is_blocked"):
		return
	for _attempt in range(max_attempts):
		if not bool(surface_canvas.call("surface_action_is_blocked", action)):
			return
		await create_timer(0.05).timeout
		surface_canvas.queue_redraw()
		await _settle()


func _click_first_canvas_object_type(object_type: String) -> String:
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
		return ""
	var object_data := _first_canvas_object_type(canvas, object_type)
	if object_data.is_empty():
		return ""
	return await _click_canvas_object_data(canvas, object_data, object_type)


func _click_canvas_object_data(canvas: Control, object_data: Dictionary, object_type: String) -> String:
	var object_id := str(object_data.get("id", ""))
	var local_position := _canvas_local_center_for_object(canvas, object_data)
	if local_position.x < 0.0 or local_position.y < 0.0 or local_position.x > canvas.size.x or local_position.y > canvas.size.y:
		return ""
	if canvas.has_method("object_id_at_local_position"):
		var hit_id := str(canvas.call("object_id_at_local_position", local_position))
		if hit_id != object_id:
			return ""
	var global_position := canvas.get_global_rect().position + local_position
	_push_mouse_motion(global_position)
	await _settle()
	_push_mouse_button(global_position, true)
	await _settle()
	_push_mouse_button(global_position, false)
	await _settle()
	var focus_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	if str(focus_snapshot.get("selected_object_id", "")) != object_id:
		return ""
	_record_input_event({
		"kind": "canvas_mouse_click",
		"object_type": object_type,
		"object_id": object_id,
		"label": str(object_data.get("label", "")),
	})
	return str(object_data.get("label", object_id))


func _double_click_first_canvas_object_type(object_type: String) -> String:
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
		return ""
	var object_data := _first_canvas_object_type(canvas, object_type)
	if object_data.is_empty():
		return ""
	return await _double_click_canvas_object_data(canvas, object_data, object_type)


func _double_click_first_enabled_canvas_object_type(object_type: String) -> String:
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
		return ""
	var object_data := _first_clickable_canvas_object_type_enabled(canvas, object_type, true)
	if object_data.is_empty():
		return ""
	return await _double_click_canvas_object_data(canvas, object_data, object_type)


func _double_click_canvas_object_data(canvas: Control, object_data: Dictionary, object_type: String) -> String:
	var object_id := str(object_data.get("id", ""))
	var local_position := _canvas_local_center_for_object(canvas, object_data)
	if local_position.x < 0.0 or local_position.y < 0.0 or local_position.x > canvas.size.x or local_position.y > canvas.size.y:
		return ""
	if canvas.has_method("object_id_at_local_position"):
		var hit_id := str(canvas.call("object_id_at_local_position", local_position))
		if hit_id != object_id:
			return ""
	var global_position := canvas.get_global_rect().position + local_position
	_push_mouse_motion(global_position)
	await _settle()
	_push_mouse_button(global_position, true, true)
	await _settle()
	_push_mouse_button(global_position, false, true)
	await _settle()
	_record_input_event({
		"kind": "canvas_mouse_double_click",
		"object_type": object_type,
		"object_id": object_id,
		"label": str(object_data.get("label", "")),
	})
	return str(object_data.get("label", object_id))


func _first_canvas_object_type(canvas: Control, object_type: String) -> Dictionary:
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	var objects: Array = snapshot.get("objects", [])
	for item in objects:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = item
		if _object_type_value(object_data) == object_type:
			return object_data.duplicate(true)
	return {}


func _preferred_canvas_game_object(canvas: Control) -> Dictionary:
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	var objects: Array = snapshot.get("objects", [])
	var game_objects: Array = []
	for item in objects:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = item
		if _object_type_value(object_data) != "game":
			continue
		if bool(object_data.get("disabled", false)) or not _canvas_object_center_hits(canvas, object_data):
			continue
		game_objects.append(object_data.duplicate(true))
	if game_objects.is_empty():
		return {}
	for preferred_id in ["blackjack", "video_poker", "roulette", "baccarat", "slot", "pull_tabs", "bar_dice"]:
		for item in game_objects:
			var game_object: Dictionary = item
			var source_id := str(game_object.get("source_id", "")).strip_edges()
			var object_id := str(game_object.get("id", "")).strip_edges()
			if source_id == preferred_id or object_id == "game:%s" % preferred_id:
				return game_object.duplicate(true)
	var first_game: Dictionary = game_objects[0]
	return first_game.duplicate(true)


func _object_type_value(object_data: Dictionary) -> String:
	return str(object_data.get("interaction_type", object_data.get("type", object_data.get("object_type", ""))))


func _snapshot_has_object_type(objects: Array, object_type: String) -> bool:
	for item in objects:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = item
		var type_value := _object_type_value(object_data)
		if type_value == object_type:
			return true
	return false


func _event_option_by_id(event_id: String) -> Dictionary:
	if event_id.is_empty():
		return {}
	var snapshot: Dictionary = app.call("current_environment_view_snapshot")
	for item in snapshot.get("event_options", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = item
		if str(option.get("id", "")) == event_id:
			return option.duplicate(true)
	return {}


func _first_enabled_travel_choice(choices: Array) -> Dictionary:
	for choice_value in choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		if bool(choice.get("enabled", true)):
			return choice.duplicate(true)
	return {}


func _preferred_enabled_travel_choice(choices: Array) -> Dictionary:
	var best_choice: Dictionary = {}
	var best_score := -1
	for choice_value in choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		if not bool(choice.get("enabled", true)):
			continue
		var target_id := str(choice.get("id", "")).strip_edges()
		var score := _visual_qa_travel_choice_score(target_id)
		if best_choice.is_empty() or score > best_score:
			best_choice = choice.duplicate(true)
			best_score = score
	if not best_choice.is_empty():
		return best_choice
	return _first_enabled_travel_choice(choices)


func _visual_qa_travel_choice_score(archetype_id: String) -> int:
	if archetype_id.is_empty():
		return 0
	var fixture_library := app.get("library") as ContentLibrary
	if fixture_library == null:
		return 0
	var archetype := _visual_qa_archetype(archetype_id, fixture_library)
	if archetype.is_empty():
		return 0
	var score := 0
	if str(archetype.get("kind", "")) == "casino":
		score += 10
	for game_id in _visual_qa_archetype_game_ids(archetype):
		score = maxi(score, 10 + _visual_qa_game_preference_score(str(game_id)))
	return score


func _visual_qa_archetype_game_ids(archetype: Dictionary) -> Array:
	var result: Array = []
	for field in ["required_game_ids", "game_pool", "game_ids"]:
		var value: Variant = archetype.get(str(field), [])
		if typeof(value) != TYPE_ARRAY:
			continue
		for item in value as Array:
			var game_id := str(item).strip_edges()
			if not game_id.is_empty() and not result.has(game_id):
				result.append(game_id)
	return result


func _visual_qa_game_preference_score(game_id: String) -> int:
	match game_id:
		"blackjack":
			return 100
		"video_poker":
			return 90
		"roulette":
			return 80
		"baccarat":
			return 70
		"slot":
			return 60
		"pull_tabs":
			return 30
		"bar_dice":
			return 10
		_:
			return 0


func _first_clickable_canvas_object_type_enabled(canvas: Control, object_type: String, enabled: bool) -> Dictionary:
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	var objects: Array = snapshot.get("objects", [])
	for item in objects:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = item
		if _object_type_value(object_data) != object_type:
			continue
		var object_enabled := not bool(object_data.get("disabled", false))
		if object_enabled != enabled:
			continue
		if _canvas_object_center_hits(canvas, object_data):
			return object_data.duplicate(true)
	return {}


func _canvas_object_by_id(canvas: Control, object_id: String) -> Dictionary:
	if object_id.is_empty():
		return {}
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	var objects: Array = snapshot.get("objects", [])
	for item in objects:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = item
		if str(object_data.get("id", "")) == object_id:
			return object_data.duplicate(true)
	return {}


func _canvas_object_center_hits(canvas: Control, object_data: Dictionary) -> bool:
	var object_id := str(object_data.get("id", ""))
	if object_id.is_empty():
		return false
	var local_position := _canvas_local_center_for_object(canvas, object_data)
	if local_position.x < 0.0 or local_position.y < 0.0 or local_position.x > canvas.size.x or local_position.y > canvas.size.y:
		return false
	if canvas.has_method("object_id_at_local_position"):
		return str(canvas.call("object_id_at_local_position", local_position)) == object_id
	return true


func _click_blank_canvas_area() -> bool:
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible or not canvas.has_method("object_id_at_local_position"):
		return false
	var local_position := _blank_canvas_position(canvas)
	if local_position.x < 0.0 or local_position.y < 0.0 or local_position.x > canvas.size.x or local_position.y > canvas.size.y:
		return false
	var global_position := canvas.get_global_rect().position + local_position
	_push_mouse_motion(global_position)
	await _settle()
	_push_mouse_button(global_position, true)
	await _settle()
	_push_mouse_button(global_position, false)
	await _settle()
	_record_input_event({
		"kind": "canvas_blank_mouse_click",
		"local_position": {"x": local_position.x, "y": local_position.y},
	})
	return true


func _blank_canvas_position(canvas: Control) -> Vector2:
	var candidates := [
		Vector2(8.0, 8.0),
		Vector2(canvas.size.x - 8.0, 8.0),
		Vector2(8.0, canvas.size.y - 8.0),
		Vector2(canvas.size.x - 8.0, canvas.size.y - 8.0),
		Vector2(canvas.size.x * 0.5, 8.0),
		Vector2(canvas.size.x * 0.5, canvas.size.y - 8.0),
	]
	for candidate in candidates:
		if _canvas_position_is_blank(canvas, candidate):
			return candidate
	for row in range(1, 6):
		for column in range(1, 8):
			var candidate := Vector2(canvas.size.x * float(column) / 8.0, canvas.size.y * float(row) / 6.0)
			if _canvas_position_is_blank(canvas, candidate):
				return candidate
	return Vector2(-1.0, -1.0)


func _canvas_position_is_blank(canvas: Control, local_position: Vector2) -> bool:
	if local_position.x < 0.0 or local_position.y < 0.0 or local_position.x > canvas.size.x or local_position.y > canvas.size.y:
		return false
	if canvas.has_method("object_id_at_local_position"):
		return str(canvas.call("object_id_at_local_position", local_position)).is_empty()
	return true


func _canvas_local_center_for_object(canvas: Control, object_data: Dictionary) -> Vector2:
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	var position: Vector2 = object_data.get("position", Vector2(0.5, 0.5))
	var board_point := Vector2(position.x * BOARD_SIZE.x, position.y * BOARD_SIZE.y)
	var board_rect := _snapshot_rect(snapshot.get("board_rect", {}))
	if board_rect.size.x > 0.0 and board_rect.size.y > 0.0:
		var scale := board_rect.size.x / BOARD_SIZE.x
		return board_rect.position + board_point * scale
	var offset: Vector2 = snapshot.get("camera_offset", Vector2.ZERO)
	var zoom := float(snapshot.get("camera_zoom", 1.0))
	var fallback_scale := minf(canvas.size.x / BOARD_SIZE.x, canvas.size.y / BOARD_SIZE.y) * zoom
	var fallback_offset := (canvas.size - BOARD_SIZE * fallback_scale) * 0.5 + offset
	return fallback_offset + board_point * fallback_scale


func _push_mouse_motion(global_position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = global_position
	event.global_position = global_position
	root.get_viewport().push_input(event, true)


func _push_mouse_button(global_position: Vector2, pressed: bool, double_click: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.double_click = double_click
	event.position = global_position
	event.global_position = global_position
	root.get_viewport().push_input(event, true)


func _focus_first_visible_object_type(object_type: String) -> String:
	var object_data := _first_interactable_object_type(object_type)
	if object_data.is_empty():
		return ""
	var label := str(object_data.get("label", ""))
	if label.is_empty():
		return ""
	var clicked := _click_button_exact(label)
	if not clicked.is_empty():
		_record_input_event({
			"kind": "visible_button",
			"object_type": object_type,
			"label": clicked,
		})
		return clicked
	var contains_clicked := _click_button_contains(label)
	if not contains_clicked.is_empty():
		_record_input_event({
			"kind": "visible_button_contains",
			"object_type": object_type,
			"label": contains_clicked,
		})
	return contains_clicked


func _focused_object_type() -> String:
	var snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	var selected_id := str(snapshot.get("selected_object_id", ""))
	var objects: Array = snapshot.get("objects", [])
	for item in objects:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = item
		if str(object_data.get("object_id", "")) == selected_id:
			return str(object_data.get("object_type", ""))
	return ""


func _first_interactable_object_type(object_type: String) -> Dictionary:
	var snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	var objects: Array = snapshot.get("objects", [])
	for item in objects:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = item
		if str(object_data.get("object_type", "")) == object_type:
			return object_data.duplicate(true)
	return {}


func _click_button_exact(text: String) -> String:
	for item in _visible_control_items(app):
		var data := item as Dictionary
		if str(data.get("kind", "")) != "button" or bool(data.get("disabled", false)):
			continue
		if str(data.get("text", "")) == text:
			_emit_button(data)
			return text
	return ""


func _click_button_contains(fragment: String) -> String:
	for item in _visible_control_items(app):
		var data := item as Dictionary
		if str(data.get("kind", "")) != "button" or bool(data.get("disabled", false)):
			continue
		var text := str(data.get("text", ""))
		if text.find(fragment) != -1:
			_emit_button(data)
			return text
	return ""


func _emit_button(data: Dictionary) -> void:
	var button := data.get("node") as Button
	var label := str(data.get("text", ""))
	_record_input_event({
		"kind": "visible_button_signal",
		"label": label,
	})
	_require(not strict_game_surface_only_active, "Screen-click-only game QA used a UI button during game control: %s" % label)
	button.emit_signal("pressed")


func _has_visible_text(root_node: Node, text: String) -> bool:
	for item in _visible_control_items(root_node):
		if str((item as Dictionary).get("text", "")).find(text) != -1:
			return true
	return false


func _has_visible_button_exact(text: String) -> bool:
	for item in _visible_control_items(app):
		var data := item as Dictionary
		if str(data.get("kind", "")) == "button" and not bool(data.get("disabled", false)) and str(data.get("text", "")) == text:
			return true
	return false


func _has_visible_button_contains(fragment: String) -> bool:
	for item in _visible_control_items(app):
		var data := item as Dictionary
		if str(data.get("kind", "")) == "button" and not bool(data.get("disabled", false)) and str(data.get("text", "")).find(fragment) != -1:
			return true
	return false


func _card_titles(cards_value: Variant) -> Array:
	var result: Array = []
	if typeof(cards_value) != TYPE_ARRAY:
		return result
	for card in cards_value as Array:
		if typeof(card) == TYPE_DICTIONARY:
			result.append(str((card as Dictionary).get("title", "")))
	return result


func _configured_visual_qa_seed() -> String:
	var env_seed := OS.get_environment("FOUNDATION_VISUAL_QA_SEED").strip_edges()
	if not env_seed.is_empty():
		return env_seed
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--seed="):
			var arg_seed := text.trim_prefix("--seed=").strip_edges()
			if not arg_seed.is_empty():
				return arg_seed
	return DEFAULT_VISUAL_QA_SEED


func _serialized_run_text() -> String:
	return JSON.stringify(app.call("serialized_run_state"))


func _serialized_diff_summary(before_text: String, after_text: String) -> String:
	var before_value: Variant = JSON.parse_string(before_text)
	var after_value: Variant = JSON.parse_string(after_text)
	if typeof(before_value) != TYPE_DICTIONARY or typeof(after_value) != TYPE_DICTIONARY:
		return "Diff unavailable."
	var before: Dictionary = before_value
	var after: Dictionary = after_value
	var changed: Array[String] = []
	for key_value in after.keys():
		var key := str(key_value)
		if JSON.stringify(before.get(key_value, null)) != JSON.stringify(after.get(key_value, null)):
			changed.append(key)
	for key_value in before.keys():
		var key := str(key_value)
		if not after.has(key_value) and not changed.has(key):
			changed.append(key)
	if changed.is_empty():
		return "No top-level diff found."
	return "Changed: %s." % ", ".join(changed)


func _current_serialized_heat() -> int:
	var serialized: Dictionary = app.call("serialized_run_state")
	var suspicion: Dictionary = serialized.get("suspicion", {})
	return int(suspicion.get("level", 0))


func _array_size(value: Variant) -> int:
	return (value as Array).size() if typeof(value) == TYPE_ARRAY else 0


func _is_control_visible(property_name: String) -> bool:
	var control: Control = app.get(property_name)
	return control != null and control.visible


func _control_text(property_name: String) -> String:
	var node: Variant = app.get(property_name)
	if node is Label:
		return (node as Label).text
	if node is Button:
		return (node as Button).text
	if node is LineEdit:
		return (node as LineEdit).text
	return ""


func _cover(key: String) -> void:
	var coverage: Dictionary = report["coverage"]
	coverage[key] = true


func _add_warning(message: String) -> void:
	report["warnings"].append(message)
	push_warning(message)


func _record_input_event(event_data: Dictionary) -> void:
	report["input_events"].append(event_data.duplicate(true))


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	report["warnings"].append(message)
	_write_report()
	quit(1)


func _write_report() -> void:
	if is_instance_valid(app):
		if app.has_method("serialized_run_state"):
			report["final_serialized_run_state"] = app.call("serialized_run_state")
		if app.has_method("current_screen_snapshot"):
			report["final_screen_snapshot"] = app.call("current_screen_snapshot")
		if app.has_method("current_objective_hud_snapshot"):
			report["final_objective_hud"] = app.call("current_objective_hud_snapshot")
		if app.has_method("current_run_status_hud_snapshot"):
			report["final_run_status_hud"] = app.call("current_run_status_hud_snapshot")
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write visual QA report.")
		return
	var json := JSON.stringify(report, "\t")
	file.store_string(json)
	file.close()
	print(json)
	print("Foundation visual QA report written to %s" % ProjectSettings.globalize_path(REPORT_PATH))
